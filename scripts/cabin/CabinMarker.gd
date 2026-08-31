extends Node3D
class_name CabinMarker
## The "you can tap here" marker for the cabin interior.

## =====================================================================
## THE HUB'S PORTAL PATTERN, REUSED IN SHAPE AND BEHAVIOUR
##
## The brief asked for the existing pattern to be RECOGNISED before a new
## one was invented. It exists and it is HubPortal.tscn: a dark PAD, a
## bright RING around it, a billboard LABEL above, and the ring pulsing in
## SCALE when the walker comes near (PULSE_SCALE 1.14 over PULSE_S 0.55,
## with hysteresis so a body standing on the edge does not strobe it).
##
## All of that is kept, deliberately: it is what a Keepy player has already
## been taught a tappable spot looks like, and the cabin is reached from
## the plateau where they just learned it.
##
## =====================================================================
## ⚠️ AND IT NOW DRAWS IN TWO PLACES, WHICH IS WHY THE INK IS A
## PARAMETER RATHER THAN A CONSTANT
##
## The device report that opened this batch was that from OUTSIDE, on the
## plateau, NOTHING says where to tap to go in. The previous lot marked the
## ladder, the bed and the door INSIDE the cabin and never marked the way
## IN -- so a player who had learned what a tappable spot looks like on the
## plateau arrived at the tree-house and found the one door in the game
## that carries no mark at all.
##
## This file is what answers that, unchanged in SHAPE: the hub's doorstep
## gets the same pad, the same ring, the same label and the same pulse.
## Reinventing a second marker for it would have been two components to
## keep in step, and the brief was explicit that the existing one is to be
## reused.
##
## What does NOT carry across is the INK and the LIFTS. `setup()` therefore
## takes a `Surface`, and every colour and every height in here is stated
## per surface. The enum names the BACKGROUND rather than the colour,
## deliberately: what a mark has to be depends on what it is drawn ON, and
## constants called "cream" and "amber" would have hidden that.
##
## ⚠️ AND THE PLATEAU'S INK IS NOT A NEW ONE -- it is the three portals',
## verbatim. Which is a decision about IDENTITY and not about contrast:
## measured on a real render, this file's cream would have scored HIGHER
## on the lawn than the amber it is drawn in. See the HUB block below for
## the numbers and for why they lose the argument anyway.

## =====================================================================
## ⚠️ AND ITS COLOURS ARE NOT, BECAUSE THEY MEASURE WRONG IN HERE
##
## This is the one place the pattern is knowingly departed from, and it is
## departed from on a MEASUREMENT rather than on taste.
##
## The cabin's floor was sampled off a real render of this scene -- 121
## points across the walkable square, through the shipped camera -- and it
## comes back rgb(0.7138, 0.4829, 0.3730), a light warm brown. The hub's
## grass is rgb(0.2, 0.4, 0.15). They are not the same background and the
## same ink does not work on both:
##
##   colour                        vs CABIN FLOOR   vs HUB GRASS
##   hub portal ring, amber              2.03:1        3.96:1
##   hub portal pad, dark green          3.00:1        1.54:1
##
## The hub's amber ring is a 3.96:1 mark out there and a 2.03:1 one in
## here -- under this project's own 3.0:1 floor. Reusing it verbatim would
## have shipped a marker that is nearly invisible on wood, which is exactly
## the complaint this batch exists to answer. The two colours very nearly
## swap roles between the two backgrounds.
##
## So the SHAPE is inherited and the INK is re-derived. The RING carries the
## contrast, alone and deliberately:
##
##   ring, cream   rgb(1.00, 0.96, 0.88) opaque   3.23:1 vs the floor
##
## =====================================================================
## ⚠️ AND THE PAD IS A POOL OF LIGHT, NOT A DARK DISC -- CAUGHT ON A
## RENDER THAT THE CONTRAST NUMBER HAD ALREADY PASSED
##
## The first version copied the hub's arrangement exactly: a near-black pad
## rgb(0.10, 0.07, 0.05) inside the bright ring, measuring a comfortable
## 5.29:1 against the floor. The ratio was right and the READING was
## wrong -- on light wood a near-black disc does not read as a landing
## pad, it reads as a HOLE PUNCHED IN THE FLOOR. On the hub's dark grass
## the same disc reads as shadow, which is why the pattern works out there
## and not in here.
##
## No contrast figure could have caught that: it is high contrast, and the
## defect is WHICH THING the eye decides it is looking at. It took looking
## at the render.
##
## So the pad is now the ring's own cream at alpha 0.28 -- a soft pool of
## light lying ON the boards rather than a void cut through them:
##
##   pad, cream @ 0.28  blends to rgb(0.794, 0.617, 0.515)
##                      1.45:1 vs the floor, 2.23:1 vs the ring
##
## ⚠️ AND THAT 1.45:1 IS STATED RATHER THAN HIDDEN. The pad does NOT clear
## 3.0:1 and is not asked to: it fills the shape so the marker reads as a
## PLACE rather than an outline, and the ring around it is what has to be
## seen. Anything that relies on the pad alone being legible is relying on
## the wrong half.
## WHICH BACKGROUND THIS MARKER IS BEING DRAWN ON.
##
## Not "which colour scheme": the two entries below are the SAME marker
## measured against two different floors, and the measurement is the whole
## reason there are two.
enum Surface { CABIN_FLOOR, HUB_GRASS }

## THE CABIN'S FLOOR -- cream ring, cream pool. Derived above.
const CABIN_RING_COLOR := Color(1.00, 0.96, 0.88)
const CABIN_PAD_COLOR := Color(1.00, 0.96, 0.88, 0.28)
const CABIN_LABEL_COLOR := Color(1.00, 0.97, 0.90)
const CABIN_LABEL_OUTLINE := Color(0.10, 0.07, 0.05)

## =====================================================================
## THE PLATEAU'S GRASS -- AND THE INK IS THE PORTALS' OWN, CHOSEN ON
## IDENTITY AND *NOT* ON CONTRAST
##
## ⚠️ THE OBVIOUS ARGUMENT FOR IT IS WRONG, AND MEASURING KILLED IT. The
## table at the top of this file compares the hub's amber against the
## CABIN floor and the plateau's grass, and it is easy to read that as
## "the two colours swap roles". They do not: it never measured the cream
## against the grass, and when that measurement is actually taken the
## cream WINS.
##
## Sampled off a real render of the shipped plateau, at the cabin's own
## doorstep, through the shipped camera -- 96 points on the torus body and
## 96 on the lawn 2.6 to 4.0 units clear of it:
##
##   ground, rendered   rgb(0.326, 0.376, 0.192)   Lrel 0.104
##   amber ring         rgb(0.852, 0.664, 0.268)   Lrel 0.437   3.16:1
##   cream ring         rgb(0.896, 0.861, 0.787)   Lrel 0.717   4.76:1
##
## Both clear this project's 3.0:1 floor and the CREAM CLEARS IT BY MORE.
## Contrast does not decide this one.
##
## ⚠️ WHAT DOES DECIDE IT: Chased, Quizz and Battle already stand on this
## plateau wearing exactly these colours. A door marked in a DIFFERENT ink
## would read as a different KIND of thing -- and it is not one. It is the
## fourth place out here where a tap takes you somewhere else, and the
## player has already been taught three times what that looks like.
## Matching them is what makes it legible without being explained; a
## brighter ring that says "not one of those" would be worse at the job
## while measuring better.
##
## ⚠️ AND NOTE WHAT THE FOG COSTS, because it is the number a future
## reader will be surprised by: the header's 3.96:1 for this same amber is
## an ALBEDO figure. The cabin stands at z = +34 and the plateau fogs
## exponentially toward a near-black green, so what actually reaches the
## screen out there is 3.16:1. It still clears the floor. It has 0.16 of
## room, and any future prop marked further out has less.
##
## These five values are HubPortal.tscn's, verbatim, and CabinProbe reads
## that scene and asserts they still agree. Two copies of one ink is
## exactly how a door slowly stops matching the doors beside it.
##
## ⚠️ THE PAD IS THE PORTALS' TOO, AND IT DOES NOT CLEAR 3.0:1 -- measured
## 1.48:1 against the same lawn, which reproduces the header's 1.54 albedo
## figure. That is stated rather than hidden, and it is the same division
## of labour the cabin's own pad is built on: the pad fills the shape so
## the mark reads as a PLACE, and the RING is what has to be seen.
const HUB_RING_COLOR := Color(0.95, 0.74, 0.30)
const HUB_PAD_COLOR := Color(0.13, 0.28, 0.12)
const HUB_LABEL_COLOR := Color(1.00, 0.92, 0.76)
const HUB_LABEL_OUTLINE := Color(0.06, 0.09, 0.04)

## Colour the ring flashes to when the marker is actually tapped. See
## flash(). Shared: a flash is a brightness pop towards white, and white is
## brighter than both rings.
const FLASH_COLOR := Color(1.00, 1.00, 1.00)

## =====================================================================
## HOW HIGH IT FLOATS, AND WHY IT IS NOT ZERO
##
## The drawn floor is not the walking plane -- it is a backdrop the plane
## was measured off, and it is bumpy. Sampled on a 15x15 grid over the
## ground floor's walkable square, the drawn surface runs from 0.106 world
## units BELOW the plane to 0.185 ABOVE it. A pad laid flat on the plane
## would therefore be buried wherever the boards rise.
##
## PAD_LIFT clears that worst case with a little to spare. The cost is that
## on the low spots the marker floats by up to ~0.3 -- which at this
## camera's -22 degree pitch reads as a mark lying on the floor, where a
## pad half-sunk into it reads as a bug.
const CABIN_PAD_LIFT: float = 0.20
const CABIN_RING_LIFT: float = 0.23

## ⚠️ AND ON THE PLATEAU THEY ARE THE PORTALS' MUCH SMALLER NUMBERS,
## because the reason the cabin's are big DOES NOT EXIST OUT THERE.
##
## In here the lift clears a DRAWN floor that wanders +-0.19 world units
## around the walking plane. The plateau's ground is a flat PlaneMesh at
## y = 0 with nothing to clear, so HubPortal lifts its pad 0.03 and its
## ring 0.09 and that is all it needs. Carrying the cabin's 0.20/0.23 out
## there would float the mark a fifth of a metre off the lawn -- the
## "hovering" reading the cabin pays for a reason it has and the hub
## does not.
const HUB_PAD_LIFT: float = 0.03
const HUB_RING_LIFT: float = 0.09

## =====================================================================
## HOW BIG THE LABEL IS DRAWN, PER SURFACE
##
## Label3D's world size is font_size x pixel_size, so both have to be
## stated together or one of them silently rides on Godot's default.
##
## The plateau's pair is HubPortal.tscn's own (64 x 0.006 = 0.384 world
## units per em) for the reason its colours are: the cabin's sign has to
## be the size of the three signs standing beside it, not a fourth size.
## The cabin's own pair is what the interior lot measured against a room
## eleven times the model's size.
const CABIN_LABEL_FONT_SIZE: int = 32
const CABIN_LABEL_PIXEL_SIZE: float = 0.0032
const CABIN_LABEL_HEIGHT: float = 0.75
const HUB_LABEL_FONT_SIZE: int = 64
const HUB_LABEL_PIXEL_SIZE: float = 0.006
const HUB_LABEL_HEIGHT: float = 1.46
const CABIN_LABEL_OUTLINE_SIZE: int = 16
const HUB_LABEL_OUTLINE_SIZE: int = 14

## Pulse, copied from HubPortal so the two screens agree about what a
## live tappable spot looks like.
const PULSE_SCALE: float = 1.14
const PULSE_S: float = 0.55

## The tap confirmation. Short on purpose: it answers "I got that", it is
## not an animation to watch.
const FLASH_S: float = 0.26
const FLASH_SCALE: float = 1.30

var _ring: MeshInstance3D = null
var _pad: MeshInstance3D = null
var _label: Label3D = null
var _ring_mat: StandardMaterial3D = null
## The ring's OWN colour, whichever surface it was built for. Held rather
## than read back off a constant so flash() cannot quietly return a cabin
## ring to a plateau cream, or the other way round.
var _ring_color: Color = CABIN_RING_COLOR
var _base_scale: Vector3 = Vector3.ONE
var _pulse: Tween = null
var _flash: Tween = null
var _near: bool = false

## Builds the marker. `radius` is the hotspot's OWN tap radius, passed in
## rather than restated: the ring a player aims at and the circle the code
## tests are then one number, and a marker can never quietly be drawn
## smaller than the thing it marks.
##
## `surface` picks the ink and the lifts. It DEFAULTS to the cabin's, so
## every existing caller in the interior is unchanged -- a default that
## exists because this class was the cabin's first and the plateau came
## second, and not because one of the two is the "normal" one.
##
## `label_offset` moves the SIGN ALONE, added to its own local position
## after the height above is picked. It touches neither `_pad` nor `_ring`
## -- both stay exactly on this node's own origin, which is the hotspot's
## real point, because the invariant two paragraphs up ("a marker can
## never quietly be drawn smaller than the thing it marks") is about the
## RING, not the sign floating over it. Defaults to zero, so every
## existing caller keeps drawing its label dead-centre above its own
## circle, unchanged.
func setup(radius: float, text: String,
		surface: Surface = Surface.CABIN_FLOOR,
		label_offset: Vector3 = Vector3.ZERO) -> void:
	var inner: float = maxf(radius * 0.74, 0.01)
	var hub: bool = surface == Surface.HUB_GRASS
	var pad_color: Color = HUB_PAD_COLOR if hub else CABIN_PAD_COLOR
	var pad_lift: float = HUB_PAD_LIFT if hub else CABIN_PAD_LIFT
	var ring_lift: float = HUB_RING_LIFT if hub else CABIN_RING_LIFT
	_ring_color = HUB_RING_COLOR if hub else CABIN_RING_COLOR

	_pad = MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = inner
	pad_mesh.bottom_radius = inner
	pad_mesh.height = 0.05
	# Stated, never defaulted: a primitive left at Godot's default
	# tessellation is a trap this project has measured five times.
	pad_mesh.radial_segments = 20
	pad_mesh.rings = 1
	_pad.mesh = pad_mesh
	_pad.position = Vector3(0.0, pad_lift, 0.0)
	_pad.material_override = _unshaded(pad_color)
	add_child(_pad)

	_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = inner
	ring_mesh.outer_radius = radius
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 8
	_ring.mesh = ring_mesh
	_ring.position = Vector3(0.0, ring_lift, 0.0)
	_ring_mat = _unshaded(_ring_color)
	_ring.material_override = _ring_mat
	add_child(_ring)
	_base_scale = _ring.scale

	if text != "":
		_label = Label3D.new()
		_label.text = text
		_label.position = Vector3(0.0, ring_lift
				+ (HUB_LABEL_HEIGHT if hub else CABIN_LABEL_HEIGHT), 0.0) \
				+ label_offset
		# STATED, both halves. Label3D's world size is font_size x
		# pixel_size, so leaving font_size at the engine default would put
		# half of that number outside this file -- and the interior's sign
		# was tuned against whatever that default happened to be.
		_label.font_size = HUB_LABEL_FONT_SIZE if hub else CABIN_LABEL_FONT_SIZE
		_label.pixel_size = HUB_LABEL_PIXEL_SIZE if hub else CABIN_LABEL_PIXEL_SIZE
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.shaded = false
		_label.double_sided = true
		# Drawn over the room rather than into it: the cabin is a dense
		# backdrop and a label that z-fights a beam is a label nobody reads.
		_label.no_depth_test = true
		_label.modulate = HUB_LABEL_COLOR if hub else CABIN_LABEL_COLOR
		_label.outline_modulate = HUB_LABEL_OUTLINE if hub else CABIN_LABEL_OUTLINE
		_label.outline_size = HUB_LABEL_OUTLINE_SIZE if hub else CABIN_LABEL_OUTLINE_SIZE
		add_child(_label)

func _unshaded(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	# UNSHADED, like every other surface this project draws: the scene has
	# no directional light, so a lit marker would not be the colour the
	# contrast above was measured on.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	if col.a < 1.0:
		# ⚠️ ASKED FOR, NEVER ASSUMED. albedo_color's alpha channel is
		# ignored outright while transparency stays DISABLED -- the pad
		# would draw as flat opaque cream, with no error to say so. The
		# same trap the cabin's own water discs are built around.
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# BACK-face culled, and that is the waterline shader's scar: a closed
	# body drawn with cull_disabled and no depth write repaints its far
	# side over its near one in index order, which looks right from some
	# angles and wrong from others. A torus is a closed body.
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat

## Near/far, driven by the walker's position. Hysteresis lives in the
## caller for HubPortal's reason -- a body standing exactly on the
## threshold must not strobe the marker.
func set_near(value: bool) -> void:
	if value == _near:
		return
	_near = value
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	if not _near:
		_pulse = create_tween()
		_pulse.tween_property(_ring, "scale", _base_scale, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_ring, "scale", _base_scale * PULSE_SCALE, PULSE_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_ring, "scale", _base_scale, PULSE_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## THE TAP CONFIRMATION.
##
## ⚠️ THIS IS THE HALF OF THE PATTERN THE HUB DOES NOT HAVE, and it is
## added because the device complaint was not only "I cannot see where to
## tap" but "nothing tells me a tap did anything". The portal's pulse says
## "this is live"; it says nothing about the tap that just happened, and on
## the plateau the walk itself is the answer. In here a tap on the door or
## the bed may start a walk of one hop or none at all, so the tap needs its
## own reply.
##
## A scale pop plus a brightness pop, on ONE tween over a normalised 0..1
## so the two cannot drift apart -- the hub's own rule for its arcs. It
## runs on top of the pulse rather than replacing it: killing the pulse
## here would leave a tapped marker looking dead until the walker moved.
func flash() -> void:
	if _ring == null or _ring_mat == null:
		return
	if _flash and _flash.is_valid():
		_flash.kill()
	_flash = create_tween()
	_flash.tween_method(_apply_flash, 0.0, 1.0, FLASH_S)

func _apply_flash(t: float) -> void:
	# 4t(1-t) is exactly 0 at both ends and 1 at the middle, so the flash
	# cannot leave the ring stuck bright on a rounding error -- the same
	# arc the walker's hop is drawn with, for the same reason.
	var k: float = 4.0 * t * (1.0 - t)
	_ring_mat.albedo_color = _ring_color.lerp(FLASH_COLOR, k)
	if not _near:
		_ring.scale = _base_scale.lerp(_base_scale * FLASH_SCALE, k)
