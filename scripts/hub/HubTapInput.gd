extends Node
class_name HubTapInput
## Turns a tap on the screen into a point on the plateau.
##
## =====================================================================
## TAP, NOT SWIPE -- AND DELIBERATELY NOT SwipeDetector.gd
##
## scripts/input/SwipeDetector.gd exists and is NOT reused here. It answers
## "which direction did the finger travel", which is Chased's lane-change
## question; this screen's question is "which point did the finger land
## on". Reusing it would mean deriving a destination from a gesture that
## carries no destination, and would put two unrelated semantics on one
## file the moment either needed tuning.
##
## Only the RELEASE half of a touch is acted on. Acting on the press would
## fire while a finger is still down and still moving -- a player who
## touches the screen and drags to look would be sent to wherever their
## finger first met the glass.
##
## =====================================================================
## WHY THE MOUSE PATH EXISTS
##
## project.godot sets no `emulate_touch_from_mouse`, so on a desktop
## browser a click produces InputEventMouseButton and NOTHING else -- a
## touch-only handler leaves the plateau unusable outside a phone, which
## is where a lot of the looking-at happens.
##
## A finger, on the other hand, DOES produce both: emulate_mouse_from_touch
## defaults to true, so one tap arrives as a touch release AND as a
## synthesised mouse release, and _handle_point runs twice. Measured, not
## assumed -- a real touch injected into a real window emitted
## tapped_ground twice. It is harmless because hop_to() is depth-one: the
## second call re-states the same destination.
##
## =====================================================================
## WHY THIS ONLY EVER FIRES IF NO CONTROL EATS THE EVENT FIRST
##
## _unhandled_input runs AFTER GUI picking. Any Control under the finger
## whose mouse_filter is STOP consumes the event and calls
## set_input_as_handled(), and nothing downstream of that ever sees it --
## no error, no warning, just a plateau that ignores taps.
##
## HubWorld.tscn's root Control is full-screen, so at Control's DEFAULT
## MOUSE_FILTER_STOP it swallowed every tap on the plateau. It carries
## mouse_filter = MOUSE_FILTER_IGNORE for exactly that reason; the
## fallback Button and menu are separate Controls and are still picked
## normally, so the change costs nothing they need. Do not "tidy" that
## property away, and give any Control added over the plateau the same
## treatment.

## Emitted with the world point under the finger, on the ground plane.
signal tapped_ground(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the moored boat to mean "board it", with that same ground point.
##
## Exactly one of the two fires per tap. Emitting both and letting the
## listener pick would make every tap ambiguous downstream; deciding here
## is what makes the boat a priority rather than a competing reading of the
## same event.
signal tapped_boat(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## an OWL PERCH to mean "fly with it", on the same world-units terms the
## boat is picked out on. Same one-tap-one-signal rule.
##
## MODELLED ON THE BOAT AND DELIBERATELY NOT ON THE LADDER. The boat asks
## its mooring, which answers false for the whole of a ride, so a tap
## during one falls through to tapped_ground and BECOMES the eject. The
## ladder has no such withdrawal: it emits tapped_ladder whatever Keepy is
## doing, and HubWorld then drops it -- which is fine for a board, whose
## only other meaning would be a dive it already handles by state, and
## would be wrong here, because a tap during a flight has to be able to
## reach the ground path. `owl_available` is that withdrawal, and it is a
## plain flag rather than a second node only because there is no owl-side
## object to ask: HubWorld already knows whether a flight is running.
signal tapped_owl(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## a CABIN DOOR to mean "go inside", on the same world-units terms the boat
## and the owl are picked out on. Same one-tap-one-signal rule.
##
## MODELLED ON THE BOAT, AND THAT IS LOAD-BEARING HERE RATHER THAN A HABIT.
## `cabin_available` is the mooring's withdrawal: HubWorld clears it for
## the whole time Keepy is inside, so a tap then falls through to
## tapped_ground and BECOMES the way back out -- exactly as a tap during a
## sail becomes the eject. Copying the LADDER instead would have been the
## bug: it emits tapped_ladder whatever Keepy is doing and HubWorld drops
## it, which is harmless for a plank whose only other meaning is a dive
## already handled by state, and would be wrong here, because the tap that
## brings him back out has to be able to reach the ground path. A player
## whose taps were being swallowed by a prop he is standing INSIDE would
## have no way out at all.
signal tapped_cabin(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the diving board's LADDER FOOT to mean "climb that", on the same
## world-units terms the boat is picked out on. Same one-tap-one-signal
## rule: a tap is a climb or a destination, never both.
signal tapped_ladder(point: Vector3)

## The three nodes this needs, as scene-authored paths.
##
## NodePath and not a typed node export (`@export var camera: Camera3D`),
## MEASURED and not preferred: a typed node export written by hand into a
## .tscn does NOT resolve at load -- the probe for this batch got null for
## all three and every tap died on the guard below. The editor populates
## that form through machinery a hand-written scene file does not carry.
## An exported NodePath resolves either way, and is still a path the scene
## author owns rather than a `get_node("../../X")` walk baked into code.
@export var camera_path: NodePath
@export var container_path: NodePath
@export var viewport_path: NodePath

## The mooring, asked -- before any destination is resolved -- whether the
## tap was on the boat. Optional: a plateau whose layout carries no boat
## resolves this to null and every tap is a ground tap, exactly as before.
@export var mooring_path: NodePath

var camera: Camera3D = null
var container: SubViewportContainer = null
var viewport: SubViewport = null
var mooring: BoatMooring = null

## THE WALKABLE LIMIT LIVES IN HubRegion, NOT HERE.
##
## This file used to own `const PLATEAU_HALF_EXTENT` and clamp each axis
## against it. That worked while the walkable hub was a square; the lake
## zone made it a union-minus-a-disc, and a per-axis clampf cannot express
## a hole. The constant moved to HubRegion.gd together with the rest of the
## shape, so there is still exactly one owner -- see that file for the
## measured crossing costs and for why the square stopped growing at 35.
##
## What changed for a player: a tap outside is still pulled to the nearest
## reachable point rather than dropped, and a tap ON the great lake is now
## pulled to its shore instead of walking Keepy into the water.

## Every diving board's ladder foot, flat, and how close a tap has to land
## to mean one. Empty until HubWorld hands over the built boards, so a
## layout with no board simply never emits tapped_ladder.
##
## Set from the BUILT boards rather than read from the layout here: the
## plank the player aims at and the foot this radius is measured from have
## to be the same fact.
##
## A LIST, not one point: the plateau carries three ladders now, and a
## single foot could only ever have answered for the first of them --
## tapping either of the others would have fallen through to tapped_ground
## and walked Keepy up to a plank he then could not climb. The radius stays
## a single number because it is a property of the GESTURE, not of any one
## board; the feet are metres apart, so no tap can be inside two.
var ladder_feet: Array[Vector3] = []
var ladder_radius: float = 0.0

## Every owl perch, flat, and how close a tap has to land to mean one.
## Empty until HubWorld hands over the built owls, so a layout with no owl
## simply never emits tapped_owl.
##
## Set from the BUILT owls for the reason the feet are: the prop the player
## aims at and the point this radius is measured from have to be one fact.
##
## `owl_available` is the boat's withdrawal, written above: HubWorld clears
## it for the length of a flight so a tap then falls through to the ground
## path instead of being swallowed here.
var owl_perches: Array[Vector3] = []
var owl_radius: float = 0.0
var owl_available: bool = true

## Every cabin doorstep, flat, and how close a tap has to land to mean one.
## Empty until HubWorld hands over the built cabins, so a layout with no
## cabin simply never emits tapped_cabin.
##
## Set from the BUILT cabins for the reason the perches and the feet are:
## the prop the player aims at and the point this radius is measured from
## have to be one fact.
##
## `cabin_available` is the boat's withdrawal, written above.
var cabin_doors: Array[Vector3] = []
var cabin_radius: float = 0.0
var cabin_available: bool = true

func _ready() -> void:
	camera = get_node_or_null(camera_path) as Camera3D
	container = get_node_or_null(container_path) as SubViewportContainer
	viewport = get_node_or_null(viewport_path) as SubViewport
	mooring = get_node_or_null(mooring_path) as BoatMooring
	if camera == null or container == null or viewport == null:
		push_error("HubTapInput: camera_path, container_path and viewport_path must all resolve.")

func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch:
		if not touch.pressed:
			_handle_point(touch.position)
			get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		_handle_point(click.position)
		get_viewport().set_input_as_handled()

func _handle_point(screen_point: Vector2) -> void:
	if camera == null or container == null or viewport == null:
		return
	var rect := container.get_global_rect()
	if not rect.has_point(screen_point):
		return
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var local := screen_point - rect.position
	local.x *= float(viewport.size.x) / rect.size.x
	local.y *= float(viewport.size.y) / rect.size.y

	var origin := camera.project_ray_origin(local)
	var direction := camera.project_ray_normal(local)
	# A maths plane, not a physics raycast: the ground is a decorative
	# PlaneMesh with no collider, and giving it one purely so a ray could
	# hit it would add a physics body to a screen that has no physics.
	var ground := Plane(Vector3.UP, 0.0)
	var hit: Variant = ground.intersects_ray(origin, direction)
	if hit == null:
		# Camera looking at or above the horizon. Nothing to aim at.
		return
	var point: Vector3 = hit
	# One shape, one owner. The region is a union minus the great lake, so
	# this is a nearest-point projection and not two independent clamps --
	# see HubRegion for why the difference matters and what it costs.
	var destination := HubRegion.clamp_to(point)

	# THE BOAT WINS, and it is asked BEFORE the ground point becomes a
	# destination. The radius is in WORLD units and is measured on this
	# same ground point, so "the boat or the ground behind it" is decided
	# in the space a hop destination already lives in rather than in
	# pixels, where the target would shrink with distance.
	#
	# accepts_boarding_tap() is false for the whole of a ride, so a tap
	# then falls through to tapped_ground -- which is what turns it into
	# an eject. One tap, one signal, either way.
	if mooring != null and mooring.accepts_boarding_tap(destination):
		tapped_boat.emit(destination)
		return
	# THE OWL, asked after the boat and before the ladder, on the same
	# world-unit terms both of them use. The order between the owl and the
	# ladder can never actually decide anything -- the perch is by the
	# spawn and the three ladder feet are out over the water, metres away
	# -- so it is only that the boat came first and the ladder was here
	# before this.
	#
	# Nothing is asked here about whether Keepy is FREE to fly: that is
	# KeepyHopper's business and it refuses from any state but standing
	# still. What IS asked is `owl_available`, which is a different
	# question -- not "may he" but "is this signal still meaningful", the
	# boat's own withdrawal, and the thing that turns a tap during a
	# flight back into an ordinary ground tap.
	if owl_available and owl_radius > 0.0:
		var owl_flat := Vector3(destination.x, 0.0, destination.z)
		for perch in owl_perches:
			if owl_flat.distance_to(perch) <= owl_radius:
				tapped_owl.emit(destination)
				return
	# THE CABIN, asked on the identical world-unit terms and gated on the
	# identical withdrawal. Ordered here only because the owl was here
	# first: the perch is by the spawn and the cabin is out at z = +28, so
	# the order between them can never actually decide anything.
	#
	# As with the owl, nothing is asked here about whether Keepy is FREE to
	# go in -- KeepyHopper refuses that from any state but standing still.
	# What is asked is whether this signal still MEANS anything, which is a
	# different question, and the one that turns a tap made while he is
	# inside back into an ordinary ground tap.
	if cabin_available and cabin_radius > 0.0:
		var cabin_flat := Vector3(destination.x, 0.0, destination.z)
		for door in cabin_doors:
			if cabin_flat.distance_to(door) <= cabin_radius:
				tapped_cabin.emit(destination)
				return
	# THE LADDER, asked after the boat and on the same terms: a world-unit
	# radius on the ground point, so the target does not shrink with
	# distance the way a pixel one would. Ordered after the boat only
	# because the boat came first; the two are metres apart at opposite
	# ends of the plateau, so the order can never actually decide anything.
	#
	# Nothing is asked here about whether Keepy is FREE to climb. That is
	# KeepyHopper's business, and it refuses from any state but standing
	# still -- asking twice is how the two answers start to differ.
	if ladder_radius > 0.0:
		var flat := Vector3(destination.x, 0.0, destination.z)
		for foot in ladder_feet:
			if flat.distance_to(foot) <= ladder_radius:
				tapped_ladder.emit(destination)
				return
	tapped_ground.emit(destination)
