extends Node3D
class_name CabinDodo
## The "asleep" overlay shown while Keepy is resting in the bed: two closed
## eyes and a cloud-shaped thought bubble with "Zzz" inside, both drawn in
## code exactly as CabinHearts draws its heart -- no new asset, no shader, no
## particle system, unshaded billboards like every other draw node this
## scene already makes indoors.
##
## Built ONCE in setup() and only ever shown or hidden. CabinInterior calls
## show_asleep()/hide_asleep() from the two functions that already own the
## rest state -- _enter_rest() and _wake() -- so this file adds no state of
## its own and no new FSM: the bed's existing `_resting` boolean is the only
## state this overlay answers to.
##
## ⚠️ RECON, 2 September 2026: the first shipped version of this overlay
## (commit b026dac) was invisible on device (Safari iPhone) even though the
## trigger fires correctly -- confirmed by code trace (`_enter_rest()` is
## the only path that sets `_resting = true` and it unconditionally calls
## `show_asleep()` right after positioning the body) and by elimination
## (`_ready()` completes fully on that path, since the bed's OWN hotspot
## label already renders correctly, and it is built later in the same
## `_ready()` sequence than `_dodo`). The deployed build was independently
## confirmed fresh (CACHE_VERSION epoch inside the merge's CI window,
## `index.js` etag byte-identical to this project's permanent baseline
## fingerprint, both reads genuine MISS/age:0). A camera-frustum projection
## of the overlay's own world position (BED_SPOT + EYES_OFFSET/ZZZ_OFFSET,
## against CabinInterior.tscn's fixed Camera3D transform) also lands
## comfortably inside the visible frustum, not clipped, not behind. That
## rules out the trigger, the build and the framing -- leaving exactly the
## one thing the previous lot's own doc admitted was never rendered or
## calibrated: size and contrast. At the measured camera distance the old
## "Zzz" Label3D subtended roughly 12px of screen height, and the closed-eye
## ink (the same dark tone as every outline in this scene) had no guaranteed
## contrast against Keepy's own fur. Both are exactly the silent failure
## mode CLAUDE.md already documents for this project: "un noeud mal
## positionne ou a echelle quasi nulle ne leve aucune erreur mais reste
## invisible." Fixed below by giving both a light halo/background that reads
## regardless of what is drawn under it, and by sizing the bubble to a
## fraction of Keepy's own body height rather than to a guess.
const EYES_COLOR := Color(0.10, 0.07, 0.05)

## The bubble's own fill and outline. The same pair CabinMarker's label
## already uses for its light-text/dark-outline pair, inverted here into a
## light fill with a dark outline -- a cloud is drawn as a shape, not text,
## so the roles swap.
const CLOUD_FILL_COLOR := Color(1.00, 0.97, 0.90)
const CLOUD_OUTLINE_COLOR := Color(0.10, 0.07, 0.05)
const ZZZ_COLOR := Color(0.10, 0.07, 0.05)
const ZZZ_OUTLINE := Color(1.00, 0.97, 0.90)

## Placed relative to the resting body's own origin (the point
## CabinInterior's _enter_rest() already sets _walker.global_position to),
## in world units at this scene's CABIN_SCALE. Both sit inside the ~1.32
## world-unit vertical span the resting body itself occupies (see
## _enter_rest()'s own KEEPY_MODEL_MIN_X comment), the eyes lower against the
## curled body and the bubble rising clear of it.
const EYES_OFFSET := Vector3(0.0, 0.78, 0.0)
const CLOUD_OFFSET := Vector3(0.22, 1.22, 0.0)
## Where "Zzz" sits relative to the bubble's own origin -- the bubble's
## lobes are drawn top-heavy in its texture (see _cloud_texture()), so the
## text is nudged up from the sprite's centre to land inside them.
const ZZZ_LOCAL_OFFSET := Vector3(0.0, 0.06, 0.0)

## ⚠️ RECON, second pass (2 September 2026): the first fix above (halo,
## still stated here below for the record before its own correction) shipped
## with EYES_SIZE unchanged at the old 0.30 and the halo alpha at 0.85 --
## device report: "meme visage qu'avant ce lot", i.e. no perceptible change.
## A standalone render of the exact same pixel algorithm (Python, this
## file's arc/halo maths copied verbatim, composited over both a warm-fur
## swatch and the cabin's dark ambient colour) confirmed the SHAPE read
## fine at 64x64 -- the defect was that the halo was see-through (0.85
## alpha, so it partly took on whatever colour was under it) and, more
## importantly, that EYES_SIZE never grew: the whole sprite was still the
## same ~29px-wide footprint that had already read as "the same face" once.
## The cloud fix worked because it changed BOTH axes at once (opaque fill
## AND a several-times-larger world size); this one only changed contrast.
## Fixed the same way as the cloud below: an OPAQUE fill-plus-outline eye
## shape (CLOUD_FILL_COLOR/CLOUD_OUTLINE_COLOR, reused rather than a third
## colour pair invented) instead of a translucent halo, and EYES_SIZE raised
## to a size proportioned the same way CLOUD_WORLD_WIDTH is -- verified
## again with the same standalone render before touching the .gd.
const EYES_SIZE: float = 0.42
## The eye shape itself: a filled ellipse (semi-axes in texture pixels, on
## the 64x64 canvas below) with an outline band, the same signed-distance
## fill/outline split _cloud_texture() uses on its circles.
const EYES_RX: float = 15.0
const EYES_RY: float = 11.0
const EYES_OUTLINE_WIDTH: float = 0.16

## The bubble texture is drawn top-heavy (lobes near the top, a tapering
## tail trailing down-left toward Keepy's head), 96x88 so the tail has room
## without the lobes losing width. Sized to a third of Keepy's own ~1.32
## world-unit height -- big enough to read from the fixed dollhouse camera,
## the scale CabinMarker's own ring already proves reads correctly at this
## distance.
const CLOUD_TEX_W: int = 96
const CLOUD_TEX_H: int = 88
const CLOUD_WORLD_WIDTH: float = 0.62
const CLOUD_OUTLINE_WIDTH: float = 2.4

## Sized off CabinMarker's own cabin-floor label pair rather than a new
## guess, one notch smaller: this sign is read up close, over the sleeper's
## own body, not across the room like a hotspot's.
const ZZZ_FONT_SIZE: int = 40
const ZZZ_PIXEL_SIZE: float = 0.0032
const ZZZ_OUTLINE_SIZE: int = 10

## The drift: how far the bubble rises over one cycle, and how long the
## cycle takes. Small and slow -- this is ambient, not an effect to watch.
const ZZZ_DRIFT: float = 0.12
const ZZZ_DRIFT_S: float = 1.6

## The shared textures, built on first use and then never again -- CabinHearts'
## own rule for its heart, so a second sleeping prop later in this project
## costs no second draw.
static var _eyes_tex: ImageTexture = null
static var _cloud_tex: ImageTexture = null

var _eyes: Sprite3D = null
var _cloud: Sprite3D = null
var _zzz: Label3D = null
var _drift: Tween = null

func setup() -> void:
	_eyes = Sprite3D.new()
	_eyes.texture = _eyes_texture()
	_eyes.pixel_size = EYES_SIZE / 64.0
	_eyes.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_eyes.shaded = false
	_eyes.double_sided = true
	_eyes.transparent = true
	_eyes.no_depth_test = true
	_eyes.position = EYES_OFFSET
	_eyes.visible = false
	add_child(_eyes)

	_cloud = Sprite3D.new()
	_cloud.texture = _cloud_texture()
	_cloud.pixel_size = CLOUD_WORLD_WIDTH / float(CLOUD_TEX_W)
	_cloud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cloud.shaded = false
	_cloud.double_sided = true
	_cloud.transparent = true
	_cloud.no_depth_test = true
	_cloud.position = CLOUD_OFFSET
	_cloud.visible = false
	add_child(_cloud)

	_zzz = Label3D.new()
	_zzz.text = "Zzz"
	_zzz.font_size = ZZZ_FONT_SIZE
	_zzz.pixel_size = ZZZ_PIXEL_SIZE
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.shaded = false
	_zzz.double_sided = true
	# Drawn over the room rather than into it, CabinMarker's own reason: the
	# cabin backdrop is dense and a label that z-fights the drawn bedding is
	# a label nobody reads.
	_zzz.no_depth_test = true
	_zzz.modulate = ZZZ_COLOR
	_zzz.outline_modulate = ZZZ_OUTLINE
	_zzz.outline_size = ZZZ_OUTLINE_SIZE
	_zzz.position = CLOUD_OFFSET + ZZZ_LOCAL_OFFSET
	_zzz.visible = false
	add_child(_zzz)

## Drawn like the bubble below: an OPAQUE eyelid shape (fill plus outline,
## same signed-distance split as _cloud_texture()'s circles, here on an
## ellipse) with the closed-lid crease drawn in ink on top. There is no
## separate eye node on Keepy's own .glb to close instead: it is one mesh,
## no skin, no animation, the same finding the cabin and owl batches already
## published for this family of assets, so nothing on the model itself can
## be swapped or masked -- and, per this file's header, the fill has to be
## opaque and the whole sprite sized like the bubble is, not translucent and
## left at its old footprint, or it reads as no change at all.
static func _eyes_texture() -> ImageTexture:
	if _eyes_tex != null:
		return _eyes_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for eye in 2:
		var cx: float = 20.0 if eye == 0 else 44.0
		var cy := 34.0
		for px in size:
			var dx: float = float(px) - cx
			if absf(dx) > EYES_RX + 1.0:
				continue
			for py in size:
				var dy: float = float(py) - cy
				var q: float = sqrt((dx * dx) / (EYES_RX * EYES_RX) + (dy * dy) / (EYES_RY * EYES_RY))
				if q <= 1.0:
					if q > 1.0 - EYES_OUTLINE_WIDTH:
						img.set_pixel(px, py, CLOUD_OUTLINE_COLOR)
					else:
						img.set_pixel(px, py, CLOUD_FILL_COLOR)
	for eye in 2:
		var cx: float = 20.0 if eye == 0 else 44.0
		var cy := 34.0
		for px in size:
			var dx: float = float(px) - cx
			if absf(dx) > EYES_RX - 2.0:
				continue
			# A shallow downward arc, thickened by a few pixels so it reads
			# as a closed lid rather than a hairline.
			var y := cy + dx * dx * 0.045
			for t in 4:
				var py := int(round(y)) + t
				if py >= 0 and py < size:
					img.set_pixel(px, py, EYES_COLOR)
	_eyes_tex = ImageTexture.create_from_image(img)
	return _eyes_tex

## The thought bubble: a lumpy cloud (a union of overlapping circles, not a
## single ellipse, so it reads as a cloud and not a coin) with a light fill
## and a dark outline, and a trail of shrinking circles running down-left
## toward Keepy's head -- the classic thought-bubble connector. Drawn as a
## signed distance to the nearest circle, CabinHearts' own reason for
## everything in this project being code rather than a shipped image: no
## file to commit, no second copy of the shape to keep in step with this
## one.
static func _cloud_texture() -> ImageTexture:
	if _cloud_tex != null:
		return _cloud_tex
	var w := CLOUD_TEX_W
	var h := CLOUD_TEX_H
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	# The cloud body: five overlapping lobes across the top of the canvas.
	var circles: Array[Vector3] = [
		Vector3(28.0, 32.0, 15.0),
		Vector3(46.0, 22.0, 19.0),
		Vector3(66.0, 28.0, 16.0),
		Vector3(56.0, 44.0, 15.0),
		Vector3(36.0, 46.0, 13.0),
		# The connector trail, shrinking toward the sleeper.
		Vector3(24.0, 64.0, 9.0),
		Vector3(16.0, 74.0, 6.0),
		Vector3(10.0, 82.0, 3.0),
	]
	for py in h:
		for px in w:
			var best := INF
			for c in circles:
				var d: float = Vector2(float(px) - c.x, float(py) - c.y).length() - c.z
				if d < best:
					best = d
			if best <= 0.0:
				if best > -CLOUD_OUTLINE_WIDTH:
					img.set_pixel(px, py, CLOUD_OUTLINE_COLOR)
				else:
					img.set_pixel(px, py, CLOUD_FILL_COLOR)
	_cloud_tex = ImageTexture.create_from_image(img)
	return _cloud_tex

## Shown the moment Keepy lies down. `at` is the WORLD point CabinInterior
## already placed him at -- this node does not know where the bed is, the
## same division CabinHearts already draws between "where" and "what".
func show_asleep(at: Vector3) -> void:
	global_position = at
	_eyes.visible = true
	_cloud.visible = true
	_zzz.visible = true
	if _drift != null and _drift.is_valid():
		_drift.kill()
	_drift = create_tween().set_loops()
	_drift.set_parallel(true)
	_drift.tween_property(_cloud, "position:y", CLOUD_OFFSET.y + ZZZ_DRIFT, ZZZ_DRIFT_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_drift.tween_property(_zzz, "position:y",
			CLOUD_OFFSET.y + ZZZ_LOCAL_OFFSET.y + ZZZ_DRIFT, ZZZ_DRIFT_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_drift.chain().set_parallel(true)
	_drift.tween_property(_cloud, "position:y", CLOUD_OFFSET.y, ZZZ_DRIFT_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_drift.tween_property(_zzz, "position:y", CLOUD_OFFSET.y + ZZZ_LOCAL_OFFSET.y, ZZZ_DRIFT_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Hidden the instant Keepy gets up -- no fade-out, the bed's and the
## magpie's own markers' rule: a thing that stops being true stops being
## drawn on the same frame, it does not linger to be watched leaving.
func hide_asleep() -> void:
	if _drift != null and _drift.is_valid():
		_drift.kill()
	_cloud.position = CLOUD_OFFSET
	_zzz.position = CLOUD_OFFSET + ZZZ_LOCAL_OFFSET
	_eyes.visible = false
	_cloud.visible = false
	_zzz.visible = false
