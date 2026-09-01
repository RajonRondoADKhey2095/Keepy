extends Node3D
class_name CabinHearts
## A short burst of little hearts rising off a point in the room.
##
## Built for the magpie's kiss, written GENERIC because the next affectionate
## thing in this project will want the same burst: nothing in here knows what
## a magpie is, and `burst()` takes a world point and a colour.
##
## =====================================================================
## ⚠️ WHY THIS IS SPRITES AND A TWEEN AND NOT A PARTICLE SYSTEM
##
## The brief asked for CPUParticles2D. That is not available to this screen
## for two separate reasons, and the second one is the one that decided it.
##
## 1. CPUParticles2D is a Node2D. This is a 3D SubViewport: a Node2D cannot
##    be placed above the bird in world space, cannot be occluded by the
##    room, and cannot move with a camera it does not live under. The 3D
##    reading of the same instruction is CPUParticles3D with a billboarded
##    material.
##
## 2. ⚠️ AND THERE IS NO PARTICLE SYSTEM ANYWHERE IN THIS REPOSITORY, which
##    is a decision already taken and written down rather than an omission.
##    HubWorld's water-impact block states it at length: introducing the
##    project's first particle system inside an effect nobody can look at
##    until it reaches staging puts an unproven rendering technology and an
##    unproven effect on the same commit, with no way to tell which of them
##    was at fault. That is not hypothetical here -- this project has
##    already shipped transparency that was green under llvmpipe and broken
##    on Safari iOS at certain azimuths, and cost a device round trip to
##    find.
##
## So the mechanism is the one this screen already uses everywhere: unshaded
## billboarded quads moved by a tween. Decor.gd's hills, CabinMarker's own
## label and the hub's impact ring are all exactly this. It honours what the
## brief actually asked for -- CPU-side, billboarded, cheap on mobile --
## without being the thing the repository decided not to be.
##
## =====================================================================
## THE TEXTURE IS DRAWN IN CODE, NOT SHIPPED
##
## One 64x64 RGBA image, generated once from the implicit heart curve and
## SHARED by every sprite ever spawned. No file to commit, nothing added to
## the .pck, and no second copy of the shape to keep in step with this one --
## the same reason HubBuilder builds every plateau prop out of primitives
## instead of importing them.

## How many rise per burst. Three, and the number is a budget rather than a
## taste: each is one draw node alive for HEART_LIFE_S, so a burst peaks at
## three and is back to zero well before a player can tap again.
const HEART_COUNT: int = 3

## How long one heart lives. Long enough to read as a rise, short enough
## that a second tap starts a fresh burst rather than joining a crowd.
const HEART_LIFE_S: float = 1.05

## Stagger between them, so they leave as a little train instead of as one
## clump. Three at 0.13 spreads the burst over 0.26s of departures against
## a life of 1.05, which keeps all three overlapping.
const HEART_STAGGER_S: float = 0.13

## How far one rises, in world units. Keepy is 1.35 tall, so this clears
## his head from a start at beak height and stops before the loft deck at
## 7.54 -- measured against both rather than picked.
const HEART_RISE: float = 1.15

## Sideways drift over a life. Small: hearts that fan wide read as a spray,
## and this is meant to read as fondness.
const HEART_DRIFT: float = 0.34

## World size of one heart quad at full size.
const HEART_SIZE: float = 0.42

## They grow in and shrink out rather than popping. Fractions of a life.
const HEART_GROW_IN: float = 0.18
const HEART_FADE_FROM: float = 0.55

const HEART_COLOR := Color(1.00, 0.42, 0.55)

## The shared texture, built on first use and then never again.
static var _tex: ImageTexture = null

## =====================================================================
## THE HEART, AS A CURVE
##
## The standard implicit heart, (x^2 + y^2 - 1)^3 - x^2 y^3 <= 0, sampled on
## a 64x64 grid. Drawn rather than shipped for the reason in the header, and
## ANTI-ALIASED by sampling the curve's sign on a 2x2 sub-grid per pixel:
## a hard cutoff on a 64-pixel heart shows its stair-steps at this size, and
## the alternative to smoothing it is shipping a bigger image.
static func _heart_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for py in size:
		for px in size:
			var hits := 0
			for sy in 2:
				for sx in 2:
					# Map the pixel into [-1.35, 1.35] with y up, which is the
					# window the curve fills without touching the border.
					var u := ((float(px) + 0.25 + 0.5 * float(sx)) / float(size) - 0.5) * 2.7
					var v := (0.5 - (float(py) + 0.25 + 0.5 * float(sy)) / float(size)) * 2.7
					# The curve is drawn slightly squat so it reads as a heart
					# rather than as a leaf at this size.
					v = v * 0.92 + 0.18
					var r := u * u + v * v - 1.0
					if r * r * r - u * u * v * v * v <= 0.0:
						hits += 1
			if hits > 0:
				var a := float(hits) / 4.0
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, a))
			else:
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, 0.0))
	_tex = ImageTexture.create_from_image(img)
	return _tex

## Send a burst up from `at`, in world space.
##
## `at` is a WORLD point and this node's own transform is not consulted --
## the caller knows where the bird's beak is and this does not need to.
func burst(at: Vector3, tint: Color = HEART_COLOR) -> void:
	for i in HEART_COUNT:
		_spawn(at, tint, i)

func _spawn(at: Vector3, tint: Color, index: int) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = _heart_texture()
	sprite.pixel_size = HEART_SIZE / 64.0
	# BILLBOARD_ENABLED and not FIXED_Y: this camera is pitched down 22
	# degrees and never moves, so a Y-only billboard would show these
	# edge-on-ish from above. Decor.gd wants FIXED_Y because its hills must
	# stay upright under a camera that yaws; nothing here yaws.
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Unshaded, like every surface in this project: the room has no light,
	# so a lit sprite would render black.
	sprite.shaded = false
	sprite.double_sided = true
	# ⚠️ ALPHA IS ASKED FOR EXPLICITLY. A Sprite3D defaults to
	# ALPHA_CUT_DISABLED with transparency on, which is what is wanted here,
	# but the modulate alpha below is what fades them and it is worth being
	# loud about: this project has already shipped a disc whose alpha was
	# silently ignored because transparency was left at its default.
	sprite.transparent = true
	sprite.no_depth_test = false
	sprite.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	sprite.scale = Vector3.ZERO
	add_child(sprite)

	# Each heart gets its own lane so three do not fly the same line. Signed
	# and spread from the index rather than random: a burst that looks
	# different every time is a burst a probe cannot assert.
	var lane := (float(index) - float(HEART_COUNT - 1) * 0.5) / maxf(1.0, float(HEART_COUNT - 1) * 0.5)
	var delay := float(index) * HEART_STAGGER_S

	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	# ONE tween_method over a normalised 0..1, not three parallel property
	# tweens: rise, drift, scale and fade are all read off the same `t`, so
	# they cannot drift apart from each other. The same shape the hub's
	# impact ring and CabinMarker's flash both use.
	tw.tween_method(
		func(t: float) -> void: _apply(sprite, at, lane, tint, t),
		0.0, 1.0, HEART_LIFE_S)
	# Freed by the tween that owns it, so a burst leaves nothing behind even
	# if the player taps again mid-flight.
	tw.tween_callback(sprite.queue_free)

func _apply(sprite: Sprite3D, at: Vector3, lane: float, tint: Color, t: float) -> void:
	if not is_instance_valid(sprite):
		return
	# Rise eases out: a heart leaves quickly and slows as it goes, which is
	# what buoyancy looks like. Drift is linear, and the two together bend
	# the path outward.
	var rise := (1.0 - pow(1.0 - t, 2.0)) * HEART_RISE
	var drift := lane * HEART_DRIFT * t
	# A little sway, so three hearts on fixed lanes still read as floating
	# rather than as three rails.
	var sway := sin(t * TAU + lane * 2.0) * 0.05
	sprite.global_position = at + Vector3(drift + sway, rise, 0.0)

	# Grows in over the first slice, holds, then fades from FADE_FROM to
	# nothing. Alpha reaches exactly 0 at t = 1 by construction, so a heart
	# cannot be left visible by a rounding error at the end of its tween.
	var grow: float = clampf(t / HEART_GROW_IN, 0.0, 1.0)
	sprite.scale = Vector3.ONE * grow
	var alpha := 1.0
	if t > HEART_FADE_FROM:
		alpha = 1.0 - (t - HEART_FADE_FROM) / (1.0 - HEART_FADE_FROM)
	sprite.modulate = Color(tint.r, tint.g, tint.b, clampf(alpha, 0.0, 1.0))
