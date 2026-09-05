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
##
## ⚠️ RECON, third pass (2 September 2026) -- AND THE CAUSE, AT LAST. The
## two passes above were both about how the eyes were DRAWN. Neither was
## the fault. The fault is that they were drawn in the wrong PLACE, and
## have been since the first commit: `EYES_OFFSET` was a CONSTANT WORLD
## OFFSET, Vector3(0, 0.78, 0), added to the walker's origin. That can only
## be right for one pose. The resting pose is not it -- CabinInterior's
## _enter_rest() rolls the body 90 degrees about its own Z, yaws the walker
## 20, and swaps the standing lift for KEEPY_MODEL_MIN_X, so his head
## swings toward -x and drops. The eyes were being drawn in mid-air beside
## him. Everything the two passes above measured about contrast and size
## was measured on a sprite nobody could have seen anywhere near his face.
##
## Nothing about the RENDERING was ever wrong, and that is worth stating
## because it is what two passes of work went into: no_depth_test and
## transparent are set below and were set before, so neither occlusion, nor
## draw order, nor alpha was ever in play.
##
## Fixed by deleting the offset outright. CabinInterior now MEASURES where
## the eyes are -- see its KEEPY_MODEL_EYE_LEFT block -- and hands this
## node finished world transforms, one per eye, built through the same
## `body.global_transform` the engine draws with. This file no longer has
## an opinion about where a face is, which is the same division it already
## drew for the bubble: "this node does not know where the bed is".
##
## And ONE LID PER EYE, not one sprite carrying two. A single two-eyed
## sprite is billboarded upright, so on a body rolled 90 degrees its two
## eyes stay side by side while his are stacked -- it could not have been
## made to fit at any offset. Two independent lids have no such pose to be
## wrong about.
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
## in world units at this scene's CABIN_SCALE. The bubble rises clear of
## the body -- these two numbers are the ones device validation signed off,
## and they are untouched by this pass.
const CLOUD_OFFSET := Vector3(0.22, 1.22, 0.0)
## Where "Zzz" sits relative to the bubble's own origin -- the bubble's
## lobes are drawn top-heavy in its texture (see _cloud_texture()), so the
## text is nudged up from the sprite's centre to land inside them.
const ZZZ_LOCAL_OFFSET := Vector3(0.0, 0.06, 0.0)

## =====================================================================
## THE CLOSED LID
##
## Its SIZE and its PLACE both come from the caller: CabinInterior measured
## the eyes and hands over one world Transform3D per lid, already scaled to
## the lid's diameter. Nothing here restates either, which is the whole
## point of the third recon above.
##
## The canvas is square and the quad is ONE WORLD UNIT across (pixel_size
## = 1/LID_TEX_SIZE), so the transform's own scale is the only size there
## is.
const LID_TEX_SIZE: int = 64

## The lid is painted the fur that surrounds the eye -- CabinInterior's
## KEEPY_EYE_FUR_COLOR, measured off the ring of texels between the ink and
## the brow. A closed eyelid IS that fur; picking any other colour would be
## painting a patch over a face rather than closing an eye.
##
## ⚠️ IT IS OPAQUE ONLY WHERE THE INK IS. `show_asleep` is told the ratio
## of the measured ink radius to the lid radius (0.100 / 0.125 = 0.80): out
## to that fraction the lid is solid, because that is exactly the disc the
## eye occupies; past it the alpha ramps to zero across the measured clean
## ring, so the lid has no rim to see. Both numbers are measurements, and
## the feather cannot eat into the ink because it starts where the ink
## stops.

## The lash line: a shallow arc across the closed lid, drawn in the same
## ink tone as every other outline this scene makes. Its half-width is the
## ink disc itself, so it spans the eye and stops; its depth and thickness
## are stated as fractions of that same radius rather than in pixels, so
## the drawing survives any change to LID_TEX_SIZE.
const LID_CREASE_SAG: float = 0.30
const LID_CREASE_THICKNESS: float = 0.20

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
static var _lid_tex: ImageTexture = null
static var _cloud_tex: ImageTexture = null

## ONE PER EYE, and an Array from the first commit rather than a pair of
## fields: this project has already paid once for a prop that was drawn as
## a table and wired as a singleton. The pool is sized by what the caller
## hands over, so a model with a different number of eyes needs no edit
## here.
var _lids: Array[Sprite3D] = []
var _cloud: Sprite3D = null
var _zzz: Label3D = null
var _drift: Tween = null

func setup() -> void:
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

## ONE closed eye, centred, on a square canvas whose disc fills it.
##
## There is no eye node on Keepy's own .glb to close instead -- one node,
## one mesh, no skin, no animation, the same finding the cabin and owl
## batches already published for this family of assets -- so an eye is
## closed by painting over it, and the paint is the fur that was around it.
##
## `opaque_fraction` is the measured ink radius over the lid radius. Inside
## it the lid is solid; outside it the alpha ramps away over the measured
## ring of clean fur, so nothing draws a circle on his face.
static func _lid_texture(fur: Color, opaque_fraction: float) -> ImageTexture:
	if _lid_tex != null:
		return _lid_tex
	var size := LID_TEX_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var centre := float(size) * 0.5
	# One texel of margin so the disc never touches the canvas edge, where
	# a clamped sampler would smear it.
	var radius := centre - 1.0
	var ink := radius * opaque_fraction
	for py in size:
		for px in size:
			var dx := float(px) + 0.5 - centre
			var dy := float(py) + 0.5 - centre
			var d := sqrt(dx * dx + dy * dy)
			if d > radius:
				continue
			var alpha := 1.0
			if d > ink:
				alpha = 1.0 - (d - ink) / maxf(radius - ink, 0.001)
			img.set_pixel(px, py, Color(fur.r, fur.g, fur.b, clampf(alpha, 0.0, 1.0)))
	# The lash line, last so it sits on the fur: a shallow downward arc
	# spanning the ink disc, thickened so it is not a hairline at the size
	# a dollhouse camera draws a squirrel's eye.
	var half := ink
	var thick := maxf(1.0, ink * LID_CREASE_THICKNESS)
	var px_i := int(ceil(centre - half))
	while float(px_i) < centre + half:
		var dx2 := float(px_i) + 0.5 - centre
		var t := dx2 / maxf(half, 0.001)
		var y := centre + ink * LID_CREASE_SAG * (t * t) - ink * LID_CREASE_SAG * 0.5
		var yi := int(round(y))
		for k in int(ceil(thick)):
			var py_i := yi + k
			if px_i >= 0 and px_i < size and py_i >= 0 and py_i < size:
				var under := img.get_pixel(px_i, py_i)
				if under.a > 0.0:
					img.set_pixel(px_i, py_i, Color(EYES_COLOR.r, EYES_COLOR.g, EYES_COLOR.b, under.a))
		px_i += 1
	_lid_tex = ImageTexture.create_from_image(img)
	return _lid_tex

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

## Shown the moment Keepy lies down.
##
## `at` is the WORLD point CabinInterior already placed him at -- the same
## division CabinHearts draws between "where" and "what" -- and it still
## carries the bubble alone, exactly as it did when the bubble was signed
## off on device.
##
## `lids` are finished WORLD transforms, one per eye, measured and composed
## by CabinInterior._lid_transforms(). This node does not know where a face
## is any more than it knows where the bed is. An empty array means that
## function refused loudly; the bubble still shows, because a missing lid
## is not a reason to take away the one part of this overlay that works.
func show_asleep(at: Vector3, lids: Array[Transform3D], opaque_fraction: float) -> void:
	global_position = at
	_fit_lids(lids.size(), opaque_fraction)
	for i in _lids.size():
		var lid := _lids[i]
		lid.global_transform = lids[i]
		lid.visible = true
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

## Grows the lid pool to whatever the caller has eyes for, once, and never
## shrinks it: a Sprite3D that is merely hidden costs nothing, and a pool
## that is rebuilt every rest is a pool that allocates every rest.
##
## ⚠️ THE LIDS ARE NOT BILLBOARDED, and that is deliberate. Their transform
## already points them at the camera AND rolls them with the body; a
## billboard flag would throw the roll away and keep a sleeping squirrel's
## lash lines horizontal while he lies on his side.
func _fit_lids(count: int, opaque_fraction: float) -> void:
	while _lids.size() < count:
		var lid := Sprite3D.new()
		lid.texture = _lid_texture(CabinInterior.KEEPY_EYE_FUR_COLOR, opaque_fraction)
		# One world unit across, so the caller's transform carries the size.
		lid.pixel_size = 1.0 / float(LID_TEX_SIZE)
		lid.shaded = false
		lid.double_sided = true
		lid.transparent = true
		# Drawn over the room rather than into it, for the bubble's own
		# reason below: the cabin backdrop is dense and a lid that z-fights
		# the drawn bedding is a lid that flickers.
		lid.no_depth_test = true
		lid.visible = false
		add_child(lid)
		_lids.append(lid)

## Hidden the instant Keepy gets up -- no fade-out, the bed's and the
## magpie's own markers' rule: a thing that stops being true stops being
## drawn on the same frame, it does not linger to be watched leaving.
func hide_asleep() -> void:
	if _drift != null and _drift.is_valid():
		_drift.kill()
	_cloud.position = CLOUD_OFFSET
	_zzz.position = CLOUD_OFFSET + ZZZ_LOCAL_OFFSET
	for lid in _lids:
		lid.visible = false
	_cloud.visible = false
	_zzz.visible = false
