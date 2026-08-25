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

var camera: Camera3D = null
var container: SubViewportContainer = null
var viewport: SubViewport = null

## Half-extent of the walkable plateau, in world units. Taps outside are
## clamped to the edge rather than ignored: a tap near the horizon is a
## player asking to go as far as they can, and refusing it silently reads
## as the screen being broken.
##
## Widened 11 -> 15 for the landmark batch, then 15 -> 25 for the outer
## ring. This is the ONLY place the limit is written: HubBuilder reads it
## for its out-of-bounds warning rather than carrying a second copy, so
## widening here widens both at once. Camera OFFSET, fov, pitch and
## HOP_DISTANCE are deliberately NOT touched with it -- the camera follows
## Keepy, so a bigger plateau costs nothing in framing, and the fog closes
## the horizon long before the 600x600 ground plane runs out (measured at
## 25: the furthest ground point any frame corner can reach is |axis| 59.8
## against the plane's +-300).
##
## WHAT A CROSSING COSTS AT 25, measured on the shipped hopper at a fixed
## 60fps rather than derived: 25 units is 17 chained hops = 5.95s, and the
## chain is automatic -- KeepyHopper._on_hop_finished calls _advance(), so
## ONE tap buys the whole journey. Aimed FORWARD (-Z) the far edge is
## inside the frustum, so it really is one tap; aimed SIDEWAYS it is 6,
## because the camera keeps only a 45-degree HORIZONTAL fov and a single
## tap can never reach more than 4.82 units to the side. That asymmetry is
## the real cost of widening, not the hop count.
const PLATEAU_HALF_EXTENT: float = 25.0

func _ready() -> void:
	camera = get_node_or_null(camera_path) as Camera3D
	container = get_node_or_null(container_path) as SubViewportContainer
	viewport = get_node_or_null(viewport_path) as SubViewport
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
	point.x = clampf(point.x, -PLATEAU_HALF_EXTENT, PLATEAU_HALF_EXTENT)
	point.z = clampf(point.z, -PLATEAU_HALF_EXTENT, PLATEAU_HALF_EXTENT)
	tapped_ground.emit(Vector3(point.x, 0.0, point.z))
