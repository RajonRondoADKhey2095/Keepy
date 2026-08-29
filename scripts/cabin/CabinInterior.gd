extends Control
class_name CabinInterior
## Inside the tree-house: two walkable levels, one ladder, and the .glb as
## a fixed backdrop.
##
## =====================================================================
## THE BRIEF'S PREMISE WAS WRONG, AND MEASURING IT IS WHAT MADE THIS LOT
## POSSIBLE
##
## It said the furnished interior is "une TEXTURE PEINTE sur la coque, pas
## une geometrie creuse", and that therefore "AUCUNE mesure de vertex ne
## peut donner ou est le sol reel -- ca n'existe pas comme donnee".
##
## It does exist as data. keepy_cabin_decor.glb is one mesh of 12 990
## vertices / 7 262 triangles, and it is genuinely HOLLOWED OUT: a depth
## map looking along -Z finds the middle band of the front face sitting at
## z = -0.20 model units while the shell around it sits at +0.18, a recess
## about 0.4 model units deep. Casting rays down INSIDE that recess finds
## a flat floor at model y = -0.5305 that is consistent to three decimals
## across the whole room (-0.532, -0.529, -0.528, -0.530, -0.529...), a
## slab whose top is at -0.115, and a ceiling at +0.106.
##
## So the floors below are MEASURED off the mesh, not eyeballed against a
## reference render, and the render was used to CONFIRM them rather than to
## find them. They were right the first time -- see the batch report.
##
## =====================================================================
## ⚠️ BUT THE LEVELS ARE STILL INVISIBLE PLANES, AND THE MESH IS STILL A
## BACKDROP
##
## Which is the brief's design, arrived at from the other end. The measured
## surfaces are not COLLISION -- nothing in this project has any -- and
## they are not flat everywhere. An exhaustive search over every height in
## the model for the largest axis-aligned square whose surface stays within
## +-0.18 world units of one plane finds:
##
##   y ~ 1.75-2.00   half_extent 1.00   <- the ground floor
##   y ~ 10.50       half_extent 0.60   <- branch tops, up in the canopy
##   y ~ 11.00       half_extent 0.40   <- canopy again
##
## and NOTHING else above 0.4. On the loft the largest strictly-flat patch
## is 0.5 x 0.5 world units, against a Keepy who is 1.32 wide and 2.04
## deep. Read as collision, this asset has one floor and no mezzanine.
##
## Read as a BACKDROP -- which is what it is -- the loft is a drawn wooden
## deck spanning the back of the room, and an invisible plane at its
## dominant height puts Keepy on it. Where the drawing has a shelf or a bed
## a few centimetres off that plane, he passes over it exactly as he passes
## through a tree on the plateau, which is this project's settled rule:
## nothing out there blocks an approach either.
##
## =====================================================================
## ⚠️ THE CAMERA IS FIXED, AND LevelCamera IS DELIBERATELY NOT USED
##
## Three reasons, in the order that decides it. Only the first is taste.
##
## 1. A diorama is meant to be seen whole. Both storeys are in frame at
##    once, which is how the model was drawn and how the reference render
##    reads.
##
## 2. THE CAVITY OPENS ON ONE SIDE ONLY. Rendered on four axes: from +Z the
##    trunk is hollowed and furnished, from -Z it is a closed trunk with no
##    opening at all. A camera that follows the walker in XZ can be carried
##    round to where there is nothing to see.
##
## 3. ⚠️ AND THE DECIDING ONE, MEASURED: LevelCamera's occlusion test
##    cannot work on this asset. It fades any node in the `level_occluder`
##    group whose WORLD AABB the camera-to-walker segment crosses. The
##    cabin is ONE mesh, so its AABB is the whole building -- at this scale
##    x[-10.43, 10.40] y[0, 17.49] z[-8.42, 8.59] -- and the walker stands
##    INSIDE it on both levels. A segment that ENDS inside a box always
##    intersects that box, so the test would report "blocking" on every
##    frame from every camera position, and the entire cabin would sit at
##    alpha 0.25 for the whole visit.
##
##    That is why nothing here joins `level_occluder`. It is not an
##    oversight and it must not be "fixed" by adding the cabin to the
##    group: the group is for geometry that can stand BETWEEN the camera
##    and the walker, and a room the walker is inside cannot.
##
## LevelCamera itself is NOT modified. LevelController only asks for a
## Camera3D, and a plain one satisfies it.
##
## =====================================================================
## WHY NAVIGATION IS FREE XZ AND NOT CONSTRAINED TO AN AXIS
##
## The brief asked for that decision to be taken out loud. It offered a
## corridor -- movement along the visible width only -- on the grounds that
## the painted Z depth "ne correspond a aucune vraie profondeur 3D".
##
## It does. The ground floor's measured footprint at this scale is about
## 3.5 wide by 5.5 deep, which is depth Keepy can actually use, so the
## ground level is a free XZ square and needs no special case.
##
## The LOFT is the constrained one, and it is constrained by MEASUREMENT
## rather than by rule: its deck is about 3.6 wide and 2.0 deep, so the
## largest square that fits is what makes it feel like a gallery you walk
## ALONG. That falls out of half_extent; no second navigation mode exists.

const CABIN := preload("res://assets/models/keepy_cabin_decor.glb")
const KEEPY := preload("res://assets/models/keepy_squirrel_hero.glb")
const HUB_SCENE := "res://scenes/HubWorld.tscn"

## Scale the .glb is drawn at INSIDE this scene.
##
## NOT the plateau's 7.0, and the difference is the one number this scene
## is free to choose: out there the cabin is a landmark among trees, in
## here it is the room. Chosen by rendering 7 / 11 / 14 / 18 side by side
## with Keepy standing on the measured floor in each:
##
##   7   the whole tree fits the frame -- canopy, mound, lawn. You are
##       looking AT a tree-house, not standing in one, and the room is a
##       small part of the picture.
##   11  the room fills the frame, both storeys read, the round window and
##       the fireplace are legible.  <- this one
##   14  closer, and the loft starts to crop at the top.
##   18  too close: the loft and the window are gone.
##
## Everything below scales with it, so this constant is the only thing to
## change if that judgement is revisited on a device.
const CABIN_SCALE: float = 11.0

## Lifts the model so its lowest point sits at y = 0, exactly as
## HubBuilder.CABIN_MODEL_OFFSET does on the plateau. Measured off the
## shipped .glb's POSITION accessor (min.y = -0.800420) rather than assumed
## from the model being centred -- the origin of a .glb is wherever its
## author left it.
const CABIN_MODEL_OFFSET_Y: float = 0.800420

## =====================================================================
## THE TWO FLOORS, IN MODEL UNITS
##
## Stated in the model's OWN space and multiplied by CABIN_SCALE below, so
## that changing the scale moves the floors with the drawing instead of
## leaving them behind. A world-space literal here would be a second,
## silent copy of the scale.

## The ground floor. The flattest thing in the model: 117 sampled cells
## agreed to a standard deviation of 0.0175 model units (0.12 world at this
## scale), which is well under the 0.6 arc of a single hop.
const FLOOR_MODEL_Y: float = -0.5305

## The loft deck's top face, measured the same way (-0.112 / -0.115 / -0.139
## across the columns that have one).
const LOFT_MODEL_Y: float = -0.1150

## =====================================================================
## THE TWO WALKABLE SQUARES, IN WORLD UNITS AT CABIN_SCALE
##
## Sized off the measured extent of each drawn surface, then confirmed on a
## render with Keepy standing at the centre and at the corners of each.

const FLOOR_CENTRE := Vector2(0.60, 0.00)
const FLOOR_HALF_EXTENT: float = 1.70

const LOFT_CENTRE := Vector2(-0.70, -1.32)
const LOFT_HALF_EXTENT: float = 1.10

## The ladder, as the layout of the drawing has it: up the right-hand side
## of the room, past the fireplace, onto the right end of the loft.
const LADDER_FOOT := Vector2(2.05, -1.45)
const LADDER_TOP := Vector2(0.25, -1.30)
## How close an AIM has to land to mean the ladder. World units, like every
## other prop radius in this project, so the target does not shrink with
## distance the way a pixel one would.
const LADDER_TAP_RADIUS: float = 1.10

## Where Keepy starts a visit: just inside the door, at the front of the
## ground floor, facing into the room.
const ENTRY_SPOT := Vector2(0.60, 1.35)

## =====================================================================
## THE TAPPABLE SPOTS THAT ARE NOT THE LADDER
##
## The door is the SAME point Keepy arrives on, deliberately: he walks in
## there and he walks out from there, and two constants for one doorway is
## how the way in and the way out end up in different places.
const DOOR_SPOT := ENTRY_SPOT
## Smaller than the ladder's 1.10. The door stands only 0.35 world units
## inside the floor's +Z edge, so a generous circle here would be mostly
## hanging over ground that does not exist -- see LevelHotspot's header for
## why that is harmless on the AIM and would have been a funnel on a
## clamped point.
const DOOR_TAP_RADIUS: float = 0.85

## The bed, on the loft.
##
## ⚠️ SMALL, AND THE SIZE IS FORCED RATHER THAN CHOSEN. The loft's walkable
## square is only 1.10 half-extent and the ladder's top already sits inside
## it, so the bed's circle has to fit in what is left without touching the
## ladder's. The probe asserts that gap rather than trusting this comment:
## the two are 1.920 apart against radii that sum to 1.800.
const BED_SPOT := Vector2(-1.67, -1.32)
const BED_TAP_RADIUS: float = 0.70

## =====================================================================
## THE BED'S OWN DRAWN SURFACE, AND WHY IT IS NOT THE LOFT PLANE
##
## ⚠️ THE FIRST THING MEASURING FOUND IS THAT THE LOFT *IS* THE BED. The
## mezzanine's drawn top face and the teal duvet painted across it are the
## same surface -- ray-casting down the model over the loft's walkable
## square finds one plateau at 7.52-7.59 world units and no separate
## mattress anywhere inside it. So "lay him on the bed" and "lay him on
## the mezzanine floor" would have been the same instruction over most of
## that square, and the brief's warning against the second could not be
## obeyed by finding a higher one: there ISN'T a higher one you can stand
## on.
##
## What there IS, and what this constant is: right under the marker the
## drawn bedding DIPS. Sampling the model beneath the marker's own centre
## -- a 0.25-radius disc, about the width his body presents to the bed --
## the drawn surface runs 6.91 to 7.60 with a median of 7.3686, which is
## 0.1710 BELOW the walking plane. That hollow is the gap between the
## bed's front rail and the duvet behind it.
##
## So lying at the plane leaves him resting on bedding that is not under
## him. Lying at the MEDIAN of what IS under him puts him in it.
##
## ⚠️ AND THE RENDER PICKED THE SAME NUMBER INDEPENDENTLY. Six candidate
## depths were rendered through the shipped camera (0.00 / 0.12 / 0.18 /
## 0.25 below the plane, at three yaws); 0.18 read best -- 0.25 put the
## bed's front rail across his chin, 0.00 left him sitting on top of the
## frame. The measurement says 0.1710. Two roads, one centimetre apart.
##
## Stated in MODEL units and multiplied by CABIN_SCALE through _world_y(),
## exactly as the two floors are: a world literal here would be a second
## silent copy of the scale.
const BED_MODEL_Y: float = -0.13055

## =====================================================================
## THE LYING POSE ITSELF
##
## ⚠️ HE IS ROLLED ONTO HIS SIDE, NOT TIPPED ONTO HIS BACK, AND THAT IS
## FORCED BY THE MESH RATHER THAN CHOSEN. Keepy is modelled SITTING with
## a tail that curls up behind him: measured off the shipped .glb his
## nose-to-tail depth is 2.0371 world units against a height of 1.3501 and
## a width of 1.3198. Tipping him back 90 degrees about X swaps his DEPTH
## into the vertical -- so a two-metre axis stands up out of a bed whose
## drawn bedding is a fifth of that. It was rendered rather than argued:
## the result is a tail sticking out of the duvet with the body buried
## under it, and nothing that reads as a squirrel.
##
## Rolling about his own forward axis swaps his WIDTH into the vertical
## instead -- 1.32, half of it below the origin -- and leaves the long
## axis lying along the bed where it belongs. He ends up on his side,
## facing the room, tail curled over him.
##
## ⚠️ NO ANIMATION, AND NONE IS POSSIBLE. The .glb carries one node, one
## mesh, no skin and no animation -- the same finding the owl batch
## published for the same family of assets. Every pose in this project is
## a transform on the whole body, and this is one more.
const REST_ROLL_DEGREES: float = 90.0

## Which way he faces while he lies there.
##
## The bed's long axis runs along world X with the pillow at -X: read off
## a render with world-space markers dropped on it, not guessed from the
## layout. A roll of +90 already lays his head toward -X with the walker
## unturned, so this yaw is not what points him at the pillow -- it is a
## three-quarter turn towards the camera, so the face and the tail both
## read instead of a flat profile. Rendered at 0 / 5 / 20 / 35; 20 is
## where he stops looking like a decal and starts looking curled up.
const REST_YAW_DEGREES: float = 20.0

## Lowest point of the shipped Keepy .glb along its OWN X, read off the
## POSITION accessor like KEEPY_MODEL_MIN_Y beside it: -0.616405 against
## max.x = +0.612863, so he is not centred there either.
##
## It is X and not Y because the roll above puts his X axis vertical. The
## lift while lying is therefore this number, not the standing one, and
## using the standing one would bury his flank by the difference.
const KEEPY_MODEL_MIN_X: float = -0.616405

## How close a LANDING has to be to the door to actually leave. Compared in
## XZ, like LevelWalker's own ENTRY_REACH and for its reason: the arrival
## is on the floor by construction, so height cannot disagree.
const DOOR_REACH: float = 0.9

## And the same for the bed. The door's number, not a new one: both answer
## the same question -- "did the walk that was meant as `use this` actually
## get there" -- and ARRIVE_EPSILON, which is what a hop chain is allowed
## to stop short by, is the same 0.45 for both.
const BED_REACH: float = 0.9

## Ring pulses when the walker is inside this many times a marker's radius,
## and stops at the release. Two numbers and not one, straight out of
## HubPortal: a body standing exactly on one threshold would otherwise
## strobe the marker on and off every frame.
const NEAR_FACTOR: float = 2.2
const NEAR_RELEASE: float = 2.6

## =====================================================================
## KEEPY'S OWN ART CORRECTIONS
##
## ⚠️ THE LIFT IS DERIVED, THE SIZE IS COPIED, AND THAT SPLIT IS THE WHOLE
## POINT -- getting it wrong sank him by 0.9166 world units, 67.9% of his
## own height, so that only his head showed above the floor.
##
## KEEPY_SCALE is COPIED from the shipped hub node so he is drawn indoors
## at exactly the size he is drawn outdoors. That part of the old comment
## was right and is kept.
##
## The LIFT is NOT an art correction and must not be copied from there.
## LevelWalker's contract is that its origin is the FEET: it sets
## global_position.y to the level's floor and _apply_hop draws the arc on
## that same line. So the body has to be raised by exactly the depth the
## model hangs below its own origin, scaled -- which is what the line in
## _place_walker() computes.
##
## WHAT THE SHIPPED CODE DID INSTEAD, and why it looked plausible: the hub
## states that lift as TWO authored numbers that only mean anything
## together -- the Body slot sits at y = 0.9 in HubWorld.tscn and
## ModelSlot then places the model at model_offset = -0.2246 inside it,
## for a total of 0.6754. This file copied the SECOND of those two terms
## on its own, and multiplied it by the scale on top -- and ModelSlot does
## not scale it (it assigns model_offset straight to the child's
## position). So the body sat at -0.2246 * 1.07368 = -0.2411 instead of
## +0.6754: the 0.9 dropped, and a term the hub never scales scaled.
##
## Deriving it closes both at once and cannot drift with either number.
## Cross-checked THREE ways rather than argued:
##   * the hub, feet at y = -0.000020 with its two authored terms;
##   * scenes/dev/LevelNavTest.tscn, whose capsule is height 1.3 at local
##     y = 0.65 -- bottom exactly on the walker's origin, same contract;
##   * this constant, which reproduces the hub's 0.6754 to 4.5e-5.
const KEEPY_SCALE: float = 1.07368

## Lowest point of the shipped Keepy .glb, in ITS OWN model units, read off
## the POSITION accessor of assets/models/keepy_squirrel_hero.glb rather
## than assumed from the model being centred. It is not: min.y = -0.629070
## against max.y = +0.628346.
const KEEPY_MODEL_MIN_Y: float = -0.629070

@onready var _controller: LevelController = $LevelController
@onready var _walker: LevelWalker = $WorldViewport/SubViewport/World/Walker
@onready var _props: Node3D = $WorldViewport/SubViewport/World/Props
@onready var _exit_button: Button = $ExitButton

## The door hotspot, held so the exit can withdraw it. The bed's is not
## held: nothing withdraws it yet, and a field kept "for later" is a field
## nobody maintains.
var _door: LevelHotspot = null

## THE BED, held for the same reason the door is: the rest state has to
## withdraw it. The comment above used to say the bed's was NOT held
## because nothing withdrew it yet -- something does now.
var _bed: LevelHotspot = null

## THE HELD EXIT INTENT, and it is LevelWalker's `_pending` in miniature --
## including the lesson that one cost.
##
## ⚠️ IT MUST SURVIVE A PASS-THROUGH LANDING. The owl batch shipped a
## version of that walker intent which cleared on the FIRST landing
## whatever it was, so any walk longer than one hop ended with Keepy
## standing next to the thing having never used it -- and the probe was
## green until a control tap pushed the walk out to two hops. A tap on the
## door from across the room is exactly such a walk, so this is released
## on a landing AT the door, on a plain tap somewhere else, or never.
var _exit_pending: bool = false

## Set once the scene change has been asked for. change_scene_to_file() is
## deferred to the end of the frame, so without this a second tap in the
## same frame asks twice.
var _leaving: bool = false

## =====================================================================
## THE HELD REST INTENT, AND THE STATE IT ARMS
##
## `_rest_pending` is `_exit_pending` in every respect including the one
## that matters: IT SURVIVES A PASS-THROUGH LANDING. A tap on the bed from
## the top of the ladder is a walk of more than one hop, and an intent
## that cleared on the first landing whatever it was would leave Keepy
## standing beside the bed having never got into it -- the owl batch's
## measured bug, restated here because this is the third thing to copy it.
##
## `_resting` is a state and not a tween: nothing animates, nothing has to
## be put back at a deadline, and the only way out is a tap.
var _rest_pending: bool = false
var _resting: bool = false

## One marker per tappable thing, kept so the ladder's can follow Keepy
## between storeys and the others can hide when he is not on their level.
var _ladder_marker: CabinMarker = null
var _door_marker: CabinMarker = null
var _bed_marker: CabinMarker = null

func _ready() -> void:
	# ⚠️ MOUSE_FILTER_IGNORE, and it is load-bearing. _unhandled_input runs
	# AFTER GUI picking, so a full-screen Control left at Control's DEFAULT
	# MOUSE_FILTER_STOP consumes every tap and calls set_input_as_handled()
	# -- no error, no warning, a screen that ignores taps. HubWorld shipped
	# exactly that and it cost a batch to find. The button below is still
	# picked normally: only the ROOT is taken out of the way.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SafeArea.fill_screen()

	_exit_button.pressed.connect(_on_exit_pressed)

	_controller.levels = [
		LevelDefinition.make(&"cabin_floor", _world_y(FLOOR_MODEL_Y),
				FLOOR_HALF_EXTENT, FLOOR_CENTRE.x, FLOOR_CENTRE.y),
		LevelDefinition.make(&"cabin_loft", _world_y(LOFT_MODEL_Y),
				LOFT_HALF_EXTENT, LOFT_CENTRE.x, LOFT_CENTRE.y),
	]
	# Both ends built FROM the level definitions, so the height a player
	# arrives at and the height that level's floor is at are one fact
	# rather than two literals free to drift. Straight out of
	# LevelNavTestWorld, and for its reason.
	var floor_level: LevelDefinition = _controller.levels[0]
	var loft_level: LevelDefinition = _controller.levels[1]
	_controller.links = [
		LevelTransition.make(0, 1,
			Vector3(LADDER_FOOT.x, floor_level.plane_y, LADDER_FOOT.y),
			Vector3(LADDER_TOP.x, loft_level.plane_y, LADDER_TOP.y),
			LADDER_TAP_RADIUS),
	]
	# THE DOOR AND THE BED, as hotspots on the ground floor and the loft.
	# Built FROM the level definitions for the reason the link's ends are:
	# a hand-written height here would be a second opinion about where a
	# floor is.
	_door = LevelHotspot.make(0,
			Vector3(DOOR_SPOT.x, floor_level.plane_y, DOOR_SPOT.y),
			DOOR_TAP_RADIUS, &"door", "Sortir")
	_bed = LevelHotspot.make(1,
			Vector3(BED_SPOT.x, loft_level.plane_y, BED_SPOT.y),
			BED_TAP_RADIUS, &"bed", "Lit")
	_controller.hotspots = [_door, _bed]

	_controller.tapped_ground.connect(_on_tapped_ground)
	_controller.tapped_transition.connect(_on_tapped_transition)
	_controller.tapped_hotspot.connect(_on_tapped_hotspot)
	_controller.level_changed.connect(_on_level_changed)

	_build_backdrop()
	_place_walker()
	_build_markers()
	# The walker moves the markers' near/far state, and its landings are
	# where a held exit intent is honoured.
	_walker.hop_landed.connect(_on_hop_landed)
	_walker.became_idle.connect(_refresh_proximity)
	_on_level_changed(_controller.current_index())

## Model space to world space. ONE conversion, used by both floors and by
## nothing else, so the scale and the lift cannot be applied twice to one
## of them and once to the other.
func _world_y(model_y: float) -> float:
	return (model_y + CABIN_MODEL_OFFSET_Y) * CABIN_SCALE

## The .glb, once, as scenery. Never moved, never rotated, never scaled
## again after this: everything else in the scene is positioned against it,
## so it is the fixed thing.
func _build_backdrop() -> void:
	var model := CABIN.instantiate() as Node3D
	if model == null:
		push_error("CabinInterior: the cabin .glb did not instantiate to a Node3D.")
		return
	# The lift is applied to the CHILD in model units and the scale to the
	# holder, which is exactly how HubBuilder builds the same asset on the
	# plateau. Doing it the other way round would multiply the lift by the
	# scale twice.
	model.position = Vector3(0.0, CABIN_MODEL_OFFSET_Y, 0.0)
	var holder := Node3D.new()
	holder.name = "Cabin"
	holder.add_child(model)
	holder.scale = Vector3.ONE * CABIN_SCALE
	_props.add_child(holder)

## Keepy's body, hung on the walker.
##
## Instantiated DIRECTLY and not through a ModelSlot, on the owl's and the
## cabin prop's own terms: a slot exists to hold a PLACEHOLDER that a real
## model later replaces, and this is either Keepy or nothing.
##
## His SIZE is copied from the shipped hub node so he is drawn here exactly
## as he is drawn out there. His LIFT is derived from the mesh instead of
## copied -- see the KEEPY_SCALE block for the 0.9166 that cost.
func _place_walker() -> void:
	var body := KEEPY.instantiate() as Node3D
	if body == null:
		push_error("CabinInterior: the Keepy .glb did not instantiate to a Node3D.")
	else:
		body.name = "Body"
		body.scale = Vector3.ONE * KEEPY_SCALE
		# Raise him by exactly the depth he hangs below his own origin, so
		# his lowest vertex lands ON the walker's origin -- which IS the
		# floor. One multiplication, no authored offset to drift.
		body.position = Vector3(0.0, -KEEPY_MODEL_MIN_Y * KEEPY_SCALE, 0.0)
		_walker.add_child(body)
	var floor_level: LevelDefinition = _controller.levels[0]
	_walker.global_position = Vector3(ENTRY_SPOT.x, floor_level.plane_y, ENTRY_SPOT.y)

## =====================================================================
## THE MARKERS
##
## One per tappable thing, each built from the hotspot or link it marks so
## the ring a player aims at and the circle the code tests are the same
## number. See CabinMarker for why the hub's colours are not reused.
func _build_markers() -> void:
	var floor_level: LevelDefinition = _controller.levels[0]
	_ladder_marker = _add_marker(_controller.links[0].tap_radius, "Mezzanine")
	_door_marker = _add_marker(DOOR_TAP_RADIUS, "Sortir")
	_door_marker.position = Vector3(DOOR_SPOT.x, floor_level.plane_y, DOOR_SPOT.y)
	_bed_marker = _add_marker(BED_TAP_RADIUS, "Lit")
	var loft_level: LevelDefinition = _controller.levels[1]
	_bed_marker.position = Vector3(BED_SPOT.x, loft_level.plane_y, BED_SPOT.y)

func _add_marker(radius: float, text: String) -> CabinMarker:
	var marker := CabinMarker.new()
	marker.setup(radius, text)
	_props.add_child(marker)
	return marker

## Markers follow the storey Keepy is on.
##
## ⚠️ THE LADDER'S MARKER MOVES, and that is the honest thing rather than
## the cheap one. The link has an entry on EACH level, and only the one on
## the level Keepy is standing on answers a tap -- accepts_tap() measures
## against entry_for(current). Drawing both ends at once would put a ring
## on the loft that does nothing while he is downstairs, which is a marker
## that lies about being tappable. So there is one ring and it is always at
## the end that works.
##
## The door and the bed simply hide off their own level, for the same
## reason: a tappable-looking thing that is not tappable is worse than no
## mark at all.
func _on_level_changed(index: int) -> void:
	var level: LevelDefinition = _controller.level_at(index)
	if level == null:
		return
	var link: LevelTransition = _controller.links[0]
	if _ladder_marker != null:
		_ladder_marker.position = link.entry_for(index)
		_ladder_marker.visible = link.serves(index)
	if _door_marker != null:
		_door_marker.visible = _door != null and _door.serves(index)
	if _bed_marker != null:
		_bed_marker.visible = _bed != null and _bed.serves(index)
	_refresh_proximity()

## Pulses whatever Keepy is standing near, with HubPortal's hysteresis.
func _refresh_proximity() -> void:
	var here := _walker.global_position
	_pulse_if_near(_ladder_marker, _controller.links[0].tap_radius, here)
	_pulse_if_near(_door_marker, DOOR_TAP_RADIUS, here)
	_pulse_if_near(_bed_marker, BED_TAP_RADIUS, here)

func _pulse_if_near(marker: CabinMarker, radius: float, here: Vector3) -> void:
	if marker == null or not marker.visible:
		return
	var a := Vector3(marker.position.x, 0.0, marker.position.z)
	var b := Vector3(here.x, 0.0, here.z)
	var d := a.distance_to(b)
	# Two thresholds, never one -- see NEAR_FACTOR.
	if d <= radius * NEAR_FACTOR:
		marker.set_near(true)
	elif d >= radius * NEAR_RELEASE:
		marker.set_near(false)

func _on_tapped_ground(destination: Vector3) -> void:
	# ⚠️ A TAP WHILE HE IS LYING DOWN IS THE WAY UP, AND IT ARRIVES HERE
	# BECAUSE THE BED WITHDREW -- which is the boat's shape and the whole
	# reason the withdrawal was chosen over the ladder's. `_enter_rest`
	# holds the bed and the ladder busy, so neither answers; the tap falls
	# THROUGH to this path, and this is where it becomes "get up".
	#
	# It returns rather than walking. He asked to stop lying down; sending
	# him off across the loft in the same gesture would be two answers to
	# one tap.
	if _resting:
		_wake()
		return
	# A plain destination tap CANCELS a held exit intent -- the player
	# asked for somewhere else, and honouring the old intent on arrival
	# would be the screen acting on a decision he has already replaced.
	# LevelWalker.hop_to() does exactly this to its own link intent.
	_exit_pending = false
	_rest_pending = false
	_walker.hop_to(destination)

func _on_tapped_transition(link: LevelTransition, _destination: Vector3) -> void:
	_exit_pending = false
	_rest_pending = false
	if _ladder_marker != null:
		_ladder_marker.flash()
	_walker.request_transition(link)

## A tap on something that is not a level change.
##
## The door is the LADDER'S shape and not the button's: he WALKS there and
## leaves on arrival. Measured rather than assumed to be the house style --
## the hub's own ladder does not fire at tap time either; _on_tapped_ladder
## arms an intent and calls hop_to(), and the landing is what climbs.
func _on_tapped_hotspot(hotspot: LevelHotspot, destination: Vector3) -> void:
	match hotspot.kind:
		&"door":
			if _door_marker != null:
				_door_marker.flash()
			_walker.hop_to(destination)
			# Armed AFTER hop_to(). That call clears the WALKER's own link
			# intent, and arming before it would read as though the two
			# were the same field -- they are not, and only one of them is
			# cleared there.
			_exit_pending = true
		&"bed":
			if _bed_marker != null:
				_bed_marker.flash()
			# THE LADDER'S SHAPE, exactly as the door has it: he WALKS
			# there and lies down on arrival. Not because a rule says so
			# but because it is what every other reachable thing in this
			# project already does -- the hub's boat, its ladder, its
			# perch, its doorstep, and this scene's own door all arm an
			# intent and let the landing act.
			_exit_pending = false
			_walker.hop_to(destination)
			# Armed AFTER hop_to(), for the reason the door's is: that call
			# clears the WALKER's own link intent, and arming first would
			# read as though the two were one field.
			_rest_pending = true
			# ⚠️ ALREADY STANDING ON IT: nothing to walk, so lie down on
			# the spot. _advance() finishes a zero-length walk by emitting
			# became_idle and NOT hop_landed, so a landing-only path would
			# simply never fire here -- the hub's _on_tapped_cabin carries
			# the same line for the same reason.
			_try_rest()
		_:
			_exit_pending = false
			_rest_pending = false
			_walker.hop_to(destination)

## Every landing: proximity, and the held exit intent.
func _on_hop_landed(position: Vector3) -> void:
	_refresh_proximity()
	# The rest intent is honoured BEFORE the exit intent for no reason
	# beyond needing an order: the two cannot be armed at once, because
	# arming either clears the other.
	if _rest_pending and _try_rest():
		return
	if not _exit_pending or _leaving:
		return
	var flat_here := Vector2(position.x, position.z)
	if flat_here.distance_to(DOOR_SPOT) > DOOR_REACH:
		# NOT there yet. The intent is KEPT -- this is the pass-through
		# landing that LevelWalker's own `_pending` exists to survive.
		return
	_exit_pending = false
	_leave_to_hub()

## =====================================================================
## LYING DOWN, AND GETTING UP
##
## ⚠️ THE WITHDRAWAL IS THE BOAT'S AND THE LADDER'S IS BANNED, which is
## LevelHotspot's own header repeated on the second thing to obey it. The
## bed AND the ladder are both held busy for the whole of the rest, so
## neither answers a tap -- and the tap therefore falls THROUGH to the
## ground path, where it becomes "get up". One tap, one signal, in both
## directions.
##
## The LADDER is held too, and that is not tidiness: it is the only other
## thing on the loft that answers a tap, and a crossing started while he
## is lying down would drive the body from LevelWalker while this file
## thinks it owns it. Held, it simply has nothing to do.
##
## THE DOOR is NOT held, and does not need to be: it lives on level 0 and
## accepts_tap() refuses from anywhere else. Holding it would be a second
## opinion about a refusal that already exists.

## Lies him down if he has actually reached the bed. Returns whether it
## did, so the caller knows the landing is spent.
func _try_rest() -> bool:
	if _resting or _leaving or _bed == null:
		return false
	var here := _walker.global_position
	var flat := Vector2(here.x, here.z)
	if flat.distance_to(BED_SPOT) > BED_REACH:
		# NOT there yet. The intent is KEPT -- the pass-through landing the
		# owl batch's bug was made of.
		return false
	_rest_pending = false
	_enter_rest()
	return true

func _enter_rest() -> void:
	var body := _walker.get_node_or_null("Body") as Node3D
	if body == null:
		# Nothing to lay down. Refusing loudly beats a state with no body
		# in it, which would swallow every later tap as "get up".
		push_error("CabinInterior: cannot rest -- the walker has no Body.")
		return
	_resting = true
	_bed.set_busy(true)
	_controller.links[0].set_busy(true)
	# The marker stops breathing: it is not tappable while he is in it, and
	# a ring pulsing over a thing that refuses is a ring that lies.
	if _bed_marker != null:
		_bed_marker.set_near(false)
	# XZ is UNTOUCHED -- he lies exactly where he stood, so there is no
	# teleport to see. Only the height moves, onto the bedding that is
	# actually under him.
	_walker.global_position = Vector3(BED_SPOT.x, _world_y(BED_MODEL_Y), BED_SPOT.y)
	_walker.rotation_degrees = Vector3(0.0, REST_YAW_DEGREES, 0.0)
	body.rotation_degrees = Vector3(0.0, 0.0, REST_ROLL_DEGREES)
	# ⚠️ THE LIFT COMES OFF HIS X EXTENT, NOT HIS Y. The roll puts his
	# model X axis vertical, so the depth he hangs below his own origin is
	# now KEEPY_MODEL_MIN_X. Reusing the standing lift here would bury his
	# flank by the difference between the two -- the same class of mistake
	# that sank him 0.9166 into the floor, one axis over.
	body.position = Vector3(0.0, -KEEPY_MODEL_MIN_X * KEEPY_SCALE, 0.0)

## Gets him up. Everything is DERIVED rather than restored from a snapshot
## taken on the way in: a saved transform is a copy that goes stale the
## first time anything else moves him, and every value below already has
## exactly one owner.
##
## His YAW is deliberately left where the pose put it. He stands up facing
## the way he lay, which is what a body does; the next hop faces him again
## through LevelWalker._face().
func _wake() -> void:
	if not _resting:
		return
	_resting = false
	var body := _walker.get_node_or_null("Body") as Node3D
	if body != null:
		body.rotation_degrees = Vector3.ZERO
		body.position = Vector3(0.0, -KEEPY_MODEL_MIN_Y * KEEPY_SCALE, 0.0)
	var loft_level: LevelDefinition = _controller.levels[1]
	_walker.global_position = Vector3(BED_SPOT.x, loft_level.plane_y, BED_SPOT.y)
	if _bed != null:
		_bed.set_busy(false)
	_controller.links[0].set_busy(false)
	_refresh_proximity()

## Back out onto the plateau.
##
## ⚠️ NOTHING ABOUT THE DOORSTEP IS COMPUTED HERE, and that is the point.
## The hub derives the doorstep from the cabin's own position, scale and
## rotation, and it recorded it with HubSpawn on the way IN -- so this
## scene never has to know where on the plateau it stands. A second copy of
## that arithmetic in here is exactly how a door ends up on the wrong side
## of a building somebody turned in the layout.
##
## It also means this file has NO dependency on the plateau at all beyond
## the scene path: no HubBuilder, no HubRegion, no layout resource.
func _on_exit_pressed() -> void:
	_leave_to_hub()

## THE ONE WAY OUT, whichever of the two things asked for it.
##
## The button and the door share it rather than each calling
## change_scene_to_file(), so "what leaving means" is one fact. The
## withdrawal is the boat's: the door stops accepting taps the moment
## leaving starts, so a second tap falls THROUGH to the ground path
## instead of asking for a scene change that is already queued.
func _leave_to_hub() -> void:
	if _leaving:
		return
	_leaving = true
	if _door != null:
		_door.set_busy(true)
	get_tree().change_scene_to_file(HUB_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	# Release only, and both paths, for HubTapInput's measured reasons:
	# acting on the press would fire while a finger is still moving, and a
	# desktop click produces no touch event at all.
	var touch := event as InputEventScreenTouch
	if touch:
		if not touch.pressed:
			_controller.dispatch(touch.position)
			get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		_controller.dispatch(click.position)
		get_viewport().set_input_as_handled()
