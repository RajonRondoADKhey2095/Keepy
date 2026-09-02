extends Node3D
class_name CabinDodo
## The "asleep" overlay shown while Keepy is resting in the bed: two closed
## eyes and a drifting "Zzz", both drawn in code exactly as CabinHearts draws
## its heart -- no new asset, no shader, no particle system, unshaded
## billboards like every other draw node this scene already makes indoors.
##
## Built ONCE in setup() and only ever shown or hidden. CabinInterior calls
## show_asleep()/hide_asleep() from the two functions that already own the
## rest state -- _enter_rest() and _wake() -- so this file adds no state of
## its own and no new FSM: the bed's existing `_resting` boolean is the only
## state this overlay answers to.

## Ink, unshaded like every surface in this project (the room has no light,
## so a lit sprite or label would render black). The eyes reuse CabinMarker's
## own outline ink rather than inventing a third dark tone.
const EYES_COLOR := Color(0.10, 0.07, 0.05)
const ZZZ_COLOR := Color(1.00, 0.97, 0.90)
const ZZZ_OUTLINE := Color(0.10, 0.07, 0.05)

## Placed relative to the resting body's own origin (the point
## CabinInterior's _enter_rest() already sets _walker.global_position to),
## in world units at this scene's CABIN_SCALE. Both sit inside the ~1.32
## world-unit vertical span the resting body itself occupies (see
## _enter_rest()'s own KEEPY_MODEL_MIN_X comment), the eyes lower against the
## curled body and the Zzz rising clear of it.
const EYES_OFFSET := Vector3(0.0, 0.78, 0.0)
const ZZZ_OFFSET := Vector3(0.20, 1.15, 0.0)

const EYES_SIZE: float = 0.30
## Sized off CabinMarker's own cabin-floor label pair rather than a new
## guess, one notch smaller: this sign is read up close, over the sleeper's
## own body, not across the room like a hotspot's.
const ZZZ_FONT_SIZE: int = 40
const ZZZ_PIXEL_SIZE: float = 0.0032
const ZZZ_OUTLINE_SIZE: int = 12

## The drift: how far the "Zzz" rises over one cycle, and how long the cycle
## takes. Small and slow -- this is ambient, not an effect to watch.
const ZZZ_DRIFT: float = 0.12
const ZZZ_DRIFT_S: float = 1.6

## The shared texture, built on first use and then never again -- CabinHearts'
## own rule for its heart, so a second sleeping prop later in this project
## costs no second draw.
static var _eyes_tex: ImageTexture = null

var _eyes: Sprite3D = null
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
	_zzz.position = ZZZ_OFFSET
	_zzz.visible = false
	add_child(_zzz)

## Drawn like CabinHearts' own heart: one small shared texture, two shallow
## downward arcs. Closed eyes read at a glance at this size, where eyelashes
## or a proper lid shape would not -- and there is no separate eye node on
## Keepy's own .glb to close instead: it is one mesh, no skin, no animation,
## the same finding the cabin and owl batches already published for this
## family of assets, so nothing on the model itself can be swapped or
## masked.
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
			if absf(dx) > 11.0:
				continue
			# A shallow downward arc, thickened by a few pixels so it reads
			# as a closed lid rather than a hairline.
			var y := cy + dx * dx * 0.055
			for t in 3:
				var py := int(round(y)) + t
				if py >= 0 and py < size:
					img.set_pixel(px, py, EYES_COLOR)
	_eyes_tex = ImageTexture.create_from_image(img)
	return _eyes_tex

## Shown the moment Keepy lies down. `at` is the WORLD point CabinInterior
## already placed him at -- this node does not know where the bed is, the
## same division CabinHearts already draws between "where" and "what".
func show_asleep(at: Vector3) -> void:
	global_position = at
	_eyes.visible = true
	_zzz.visible = true
	if _drift != null and _drift.is_valid():
		_drift.kill()
	_drift = create_tween().set_loops()
	_drift.tween_property(_zzz, "position:y", ZZZ_OFFSET.y + ZZZ_DRIFT, ZZZ_DRIFT_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_drift.tween_property(_zzz, "position:y", ZZZ_OFFSET.y, ZZZ_DRIFT_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Hidden the instant Keepy gets up -- no fade-out, the bed's and the
## magpie's own markers' rule: a thing that stops being true stops being
## drawn on the same frame, it does not linger to be watched leaving.
func hide_asleep() -> void:
	if _drift != null and _drift.is_valid():
		_drift.kill()
	_zzz.position = ZZZ_OFFSET
	_eyes.visible = false
	_zzz.visible = false
