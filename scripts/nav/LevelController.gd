extends Node
class_name LevelController
## Which level Keepy is on, and what a tap means on it.
##
## =====================================================================
## THE CURRENT LEVEL DECIDES **BOTH** THE RAYCAST AND THE CLAMP
##
## Those are two separate uses of one fact, and getting only one of them
## right is a specific, silent failure. Resolving a tap against level A's
## plane and then clamping it with level B's bounds produces a destination
## that is inside the region and at the wrong height -- no error, no
## warning, a body that walks through the floor.
##
## So `current()` is asked once per tap, at the top, and the same level
## answers both halves.
##
## =====================================================================
## AIM VERSUS DESTINATION -- taken from line one, not added later
##
## Lot 1 measured what it costs to conflate them (see
## LevelTransition.accepts_tap for the numbers). The rule:
##
##   aim          where the finger pointed, on the current level's plane,
##                NOT clamped. This is what the player MEANT.
##   destination  aim through the level's clamp_to(). This is the only
##                thing that is ever somewhere to walk to.
##
## EVERY transition test reads `aim`. NOTHING reads a clamped point to
## decide meaning. A tap aimed past a level's edge is a walk to the edge,
## never an order to change level -- even when the link sits ON that edge,
## which is exactly the case the probe gates.
##
## =====================================================================
## ONE TAP, ONE SIGNAL
##
## Copied from HubTapInput deliberately: exactly one of tapped_ground and
## tapped_transition fires per tap. Emitting both and letting the listener
## choose would make every tap ambiguous downstream, and deciding here is
## what makes a transition a priority rather than a competing reading of
## the same event.

## Emitted with the CLAMPED destination on the current level.
signal tapped_ground(destination: Vector3)

## Emitted INSTEAD of tapped_ground when the AIM landed inside a link that
## is currently available. Carries the link and the clamped destination --
## the destination is still useful (it is where he walks to reach the
## entry) but it is not what decided the meaning.
signal tapped_transition(link: LevelTransition, destination: Vector3)

## Emitted INSTEAD of tapped_ground when the AIM landed inside an
## available hotspot -- a door, a bed, something that answers a tap
## without changing level. Carries the clamped destination for the same
## reason tapped_transition does: it is where he WALKS to reach the thing,
## and it is not what decided the meaning.
signal tapped_hotspot(hotspot: LevelHotspot, destination: Vector3)

## Emitted when the current level actually changes, with the new index.
signal level_changed(index: int)

## The three nodes a tap has to be resolved through, as scene-authored
## paths.
##
## NodePath and not a typed node export, MEASURED and not preferred:
## HubTapInput found that a typed node export hand-written into a .tscn
## does NOT resolve at load -- every reference comes back null and every
## tap dies on the guard. An exported NodePath resolves either way.
@export var camera_path: NodePath
@export var container_path: NodePath
@export var viewport_path: NodePath

var camera: Camera3D = null
var container: SubViewportContainer = null
var viewport: SubViewport = null

## Every level, in index order. A LIST from the first commit even though
## the test world has two.
##
## ⚠️ THE DIVING BOARD'S LESSON, PAID IN ADVANCE. Its GEOMETRY was generic
## the day it shipped; the TABLE downstream held exactly one, so a second
## plank was drawable and never climbable -- and undoing that cost its own
## batch. Only the two-level case is EXERCISED here (see the design doc's
## out-of-scope list); a third level is a row, not a mechanism.
var levels: Array[LevelDefinition] = []

## Every link. A list for the same reason.
var links: Array[LevelTransition] = []

## Every hotspot. A list for the diving board's reason as well -- and this
## one is exercised with three from its first commit rather than one.
var hotspots: Array[LevelHotspot] = []

var _current: int = 0

func _ready() -> void:
	camera = get_node_or_null(camera_path) as Camera3D
	container = get_node_or_null(container_path) as SubViewportContainer
	viewport = get_node_or_null(viewport_path) as SubViewport
	if camera == null or container == null or viewport == null:
		push_error("LevelController: camera_path, container_path and viewport_path must all resolve.")

## Index of the level Keepy is on.
func current_index() -> int:
	return _current

## The level Keepy is on, or null when the world is empty.
func current() -> LevelDefinition:
	if _current < 0 or _current >= levels.size():
		return null
	return levels[_current]

func level_at(index: int) -> LevelDefinition:
	if index < 0 or index >= levels.size():
		return null
	return levels[index]

## Moves Keepy's NAVIGATION to another level. Does not move his body --
## that is LevelWalker's job, and the two are ordered by whoever runs a
## crossing so a listener never sees one without the other.
func set_current(index: int) -> void:
	if index < 0 or index >= levels.size():
		push_error("LevelController: level index %d is out of range." % index)
		return
	if index == _current:
		return
	_current = index
	level_changed.emit(index)

## Floor height of the current level. Published because the walker and the
## camera both need it and neither should restate it: two owners of "where
## the ground is" is how a body and a camera end up on different storeys.
func ground_y() -> float:
	var level := current()
	return 0.0 if level == null else level.plane_y

## Resolves a screen point against the CURRENT level.
##
## Returns {"ok": bool, "aim": Vector3, "destination": Vector3}. A caller
## that ignores "ok" and reads "aim" gets Vector3.ZERO, which is a real
## point on the plane -- so the flag is checked, never inferred from the
## value.
func resolve(screen_point: Vector2) -> Dictionary:
	var miss := {"ok": false, "aim": Vector3.ZERO, "destination": Vector3.ZERO}
	if camera == null or container == null or viewport == null:
		return miss
	var level := current()
	if level == null:
		return miss
	var rect := container.get_global_rect()
	if not rect.has_point(screen_point):
		return miss
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return miss
	var local := screen_point - rect.position
	local.x *= float(viewport.size.x) / rect.size.x
	local.y *= float(viewport.size.y) / rect.size.y

	var origin := camera.project_ray_origin(local)
	var direction := camera.project_ray_normal(local)
	# The CURRENT LEVEL'S plane, which is the whole difference from the
	# hub's single hard-coded Plane(UP, 0). A maths plane and not a physics
	# raycast, for HubTapInput's reason: the floor is decorative geometry
	# with no collider, and giving it one purely so a ray could hit it
	# would add physics to a screen that has none.
	var hit: Variant = level.plane().intersects_ray(origin, direction)
	if hit == null:
		# Ray parallel to the floor, or aimed away from it. A higher level
		# has a nearer horizon than a lower one, so this is reached more
		# often the further up Keepy is -- it is a miss, not an error.
		return miss
	var point: Vector3 = hit
	return {
		"ok": true,
		"aim": level.flat(point),
		"destination": level.clamp_to(point),
	}

## Turns a resolved tap into exactly one signal.
##
## Split from resolve() so a probe can measure the aim and the destination
## without a signal firing, and so this ordering lives in one readable
## place rather than inside the input handler.
func dispatch(screen_point: Vector2) -> void:
	var tap := resolve(screen_point)
	if not bool(tap["ok"]):
		return
	var aim: Vector3 = tap["aim"]
	var destination: Vector3 = tap["destination"]
	# THE LINKS WIN, and they are asked on the AIM. is_available() is the
	# boat's withdrawal: a link running a crossing answers false, so the
	# tap falls through to the ground path instead of being swallowed.
	for link in links:
		if link.accepts_tap(aim, _current):
			tapped_transition.emit(link, destination)
			return
	# THEN the hotspots, on the AIM too and with the same withdrawal.
	#
	# ⚠️ AFTER the links, deliberately: a transition is the only thing here
	# that can strand a player on the wrong storey, so where two targets
	# ever overlap the one that moves him between levels has to win. The
	# probe asserts the cabin's three are far enough apart that the
	# question never actually arises -- this ordering is what makes that an
	# assertion about the LAYOUT rather than about the code.
	for spot in hotspots:
		if spot.accepts_tap(aim, _current):
			tapped_hotspot.emit(spot, destination)
			return
	tapped_ground.emit(destination)

## Every link that serves the current level. Published for a probe and for
## a caller drawing markers, so neither restates the membership rule.
func links_here() -> Array[LevelTransition]:
	var out: Array[LevelTransition] = []
	for link in links:
		if link.serves(_current):
			out.append(link)
	return out

## Every hotspot on the current level. Published for the same reason.
func hotspots_here() -> Array[LevelHotspot]:
	var out: Array[LevelHotspot] = []
	for spot in hotspots:
		if spot.serves(_current):
			out.append(spot)
	return out
