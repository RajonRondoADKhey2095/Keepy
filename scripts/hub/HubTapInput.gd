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
	tapped_ground.emit(destination)
