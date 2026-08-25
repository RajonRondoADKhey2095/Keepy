extends Node
class_name BoatMooring
## Keeps the hull at whichever end of the stream is nearest the player, and
## answers the one question HubTapInput has to ask before it resolves a
## ground destination: was that tap on the boat?
##
## =====================================================================
## THE MOORING RULE, AND THE GUARD THE RULE ALONE DOES NOT GIVE
##
## The stream runs ~36 u corner to corner across a 70 x 70 plateau, and a
## boat parked at the far end is a boat the player walks past. So it is
## RE-MOORED, never sailed empty: when Keepy is far from BOTH ends, the
## hull is moved to whichever end is nearer, with no animation at all.
##
## The threshold is 12 u from EVERY end, which is the brief's rule and is
## implemented as written. It is NOT, on its own, enough to keep the move
## off screen, and that was measured rather than assumed: the mooring only
## ever flips when the nearer end changes, which happens on the
## perpendicular bisector of the two ends -- and there BOTH ends are ~18 u
## from Keepy. 18 u SIDEWAYS is far outside a 45-degree horizontal fov,
## but 18 u straight AHEAD is inside it, because the camera looks down -Z
## and the far edge of the plateau is in frustum when aimed forward
## (HubTapInput's own docblock says so). A player crossing that bisector
## while looking along the stream would watch a boat teleport.
##
## So the distance rule is ANDed with a frustum test on both the hull's
## current position and the position it would move to. Deferring is
## cheap -- the condition is re-checked every frame and fires the moment
## either end goes off screen -- and the cost of deferring is only that the
## boat is briefly at the far end, which is the state it was already in.
##
## =====================================================================
## WHY THE TAP RADIUS IS IN WORLD UNITS
##
## A pixel radius would mean a different boat-sized target depending on how
## far away the hull happens to be drawn, and the hull is drawn small. The
## radius is measured on the GROUND POINT the tap resolves to, which is the
## same quantity a hop destination is, so "did they mean the boat or the
## ground behind it" is decided in the space both live in.

## Ground radius, in world units, within which a tap means "board" rather
## than "walk there".
##
## 2.5 against a hull 0.78 long: the hull is far smaller than a fingertip
## at this camera distance, so a target the size of the mesh would be a
## target nobody could hit. Generous on purpose, and safe to be: the boat
## sits on the water at the end of a stream, and the ground inside that
## radius is water or bank, not somewhere a player has any other reason to
## aim.
const BOARD_TAP_RADIUS: float = 2.5

## How far Keepy must be from EVERY end before the hull may be re-moored.
const REMOOR_MIN_DISTANCE: float = 12.0

## The camera the frustum guard tests against. NodePath and not a typed
## node export, for the reason HubTapInput.gd spells out at length: a typed
## node export hand-written into a .tscn does NOT resolve at load.
@export var camera_path: NodePath

var _camera: Camera3D = null
var _boat: Node3D = null
var _route: HubStreamRoute = null
var _half_width: float = 0.0

## Set false for the whole of a ride. The hull is being carried then, and
## a mooring that kept re-parking it would fight the rider for the same
## transform.
var _moored: bool = true

func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera3D
	if _camera == null:
		push_error("BoatMooring: camera_path must resolve to a Camera3D; the off-screen guard is disabled without it.")

## Hands over the hull and the stream it belongs to. Called once, by
## HubWorld, after HubBuilder has built both -- this node owns neither and
## builds neither.
func setup(boat: Node3D, route: HubStreamRoute, half_width: float) -> void:
	_boat = boat
	_route = route
	_half_width = maxf(half_width, 0.0)

## True when there is a hull, a stream, and nobody aboard.
func is_available() -> bool:
	return _boat != null and _route != null and _route.is_valid() and _moored

## Where the hull is standing. Vector3.ZERO when there is no hull, which
## only matters to a caller that already checked is_available().
func boat_position() -> Vector3:
	if _boat == null:
		return Vector3.ZERO
	return Vector3(_boat.global_position.x, 0.0, _boat.global_position.z)

## True when `point` is close enough to the moored hull to mean "board".
## False during a ride, so a tap then falls through to the ground path --
## which is what turns it into an eject.
func accepts_boarding_tap(point: Vector3) -> bool:
	if not is_available():
		return false
	return Vector3(point.x, 0.0, point.z).distance_to(boat_position()) <= BOARD_TAP_RADIUS

## Called by HubWorld at the start and end of a ride. On the way back in,
## nothing is re-parked: the ride ended wherever it ended and the hull is
## already there, so the distance rule below decides when it next moves.
func set_riding(riding: bool) -> void:
	_moored = not riding

## Re-parks the hull if the rule allows. Driven by HubWorld rather than by
## this node's own _process so the player position arrives from the one
## place that already reads it every frame.
func update(keepy_position: Vector3) -> void:
	if not is_available():
		return
	var flat := Vector3(keepy_position.x, 0.0, keepy_position.z)
	if _route.distance_to_nearest_end(flat) < REMOOR_MIN_DISTANCE:
		return
	var wanted_s: float = _route.nearest_end_abscissa(flat)
	var wanted: Vector3 = _mooring_pose(wanted_s)
	if boat_position().distance_to(Vector3(wanted.x, 0.0, wanted.z)) < 0.01:
		return
	if _visible(boat_position()) or _visible(wanted):
		# Deferred, not skipped: re-checked next frame, and the whole point
		# is that a teleport is never watched.
		return
	_boat.global_position = wanted
	_boat.rotation_degrees.y = _mooring_yaw(wanted_s)

## Parks the hull at whichever end is nearest, ignoring the distance and
## frustum rules. Used once at start-up: the plateau's first frame should
## already have the boat on the right side, and there is nothing on screen
## yet to see it arrive.
func moor_now(keepy_position: Vector3) -> void:
	if _boat == null or _route == null or not _route.is_valid():
		return
	var s: float = _route.nearest_end_abscissa(Vector3(keepy_position.x, 0.0, keepy_position.z))
	_boat.global_position = _mooring_pose(s)
	_boat.rotation_degrees.y = _mooring_yaw(s)

## Where the hull sits when moored at abscissa `s`: on the water, at the
## end itself. The ends of the ribbon are already inside the pond and the
## lake, so no extra offset is needed to make it read as afloat.
func _mooring_pose(s: float) -> Vector3:
	var where: Vector3 = _route.point_at(s)
	return Vector3(where.x, 0.0, where.z)

## Facing when moored: along the water, pointing INTO the stream. The hull
## is symmetric fore and aft, so this is about the water reading as a
## direction, not about the boat having a bow.
func _mooring_yaw(s: float) -> float:
	var tangent: Vector3 = _route.tangent_at(s)
	if s > _route.length() * 0.5:
		tangent = -tangent
	return rad_to_deg(atan2(tangent.x, tangent.z))

## True when `point` could be on screen. Tested with a margin the size of
## the hull rather than on the bare centre, so a boat half in frame does
## not count as hidden.
func _visible(point: Vector3) -> bool:
	if _camera == null:
		# No camera resolved: the guard cannot be evaluated, and reporting
		# "not visible" would let a teleport happen unchecked. Treat it as
		# visible, so the worst case is a boat that stays where it is.
		return true
	var margin: float = maxf(HubBuilder.BOAT_LENGTH, HubBuilder.BOAT_BEAM)
	var probes: Array[Vector3] = [
		point,
		point + Vector3(margin, 0.0, 0.0),
		point + Vector3(-margin, 0.0, 0.0),
		point + Vector3(0.0, 0.0, margin),
		point + Vector3(0.0, 0.0, -margin),
	]
	for probe in probes:
		if _camera.is_position_in_frustum(probe):
			return true
	return false
