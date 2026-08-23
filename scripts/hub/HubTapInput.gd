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
## is where a lot of the looking-at happens. Neither emulation flag is set
## either way, so exactly one of the two events arrives per gesture and
## there is no double-fire to guard against.

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
const PLATEAU_HALF_EXTENT: float = 11.0

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
