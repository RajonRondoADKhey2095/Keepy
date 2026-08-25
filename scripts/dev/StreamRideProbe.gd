extends Node
## Dev-only: the CONTRACTS the rideable stream has to keep.
##
## Unlike StreamGeometryProbe, which measures and asserts nothing, this one
## GATES. Every check below is something a future edit to the trace, the
## hull, the hopper or the layout could break silently:
##
##   the hull fits the tightest bend        -- a wider trace or a longer
##                                             hull puts the boat on the
##                                             grass, and nothing errors
##   ride_speed clears the shortcut floor   -- under it the boat is slower
##                                             than walking, which reads as
##                                             the ride being broken
##   a tap on the boat beats the ground     -- the priority is the whole
##                                             boarding gesture
##   NO PORTAL FIRES DURING A RIDE          -- being carried into a
##                                             sub-game is the worst thing
##                                             this feature can do
##   the mooring follows the player         -- and never in view
##   an eject clears the props              -- landing inside a rock only
##                                             shows up on device
##
## RUN IT UNDER xvfb, NOT --headless. The tap phase drives HubTapInput
## through a real SubViewportContainer rect, and --headless forces the
## DUMMY driver where that rect is 0x0 -- a trap already paid for once on
## this screen (CLAUDE.md, the mouse_filter batch).
##
##   xvfb-run --rendering-driver opengl3 godot4 --path . --fixed-fps 60 \
##     res://scripts/dev/StreamRideProbe.tscn
const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

var _failures: int = 0
var _checks: int = 0

## Portal entries seen during PHASE PORTALS.
##
## A MEMBER and not a local, and that is not style. A GDScript lambda
## captures a LOCAL by VALUE: the first version of this probe counted into
## a local, the counter never moved, and every "0 portals fired" check
## passed for the wrong reason -- a false green in the one phase that
## exists to catch the worst failure this feature has. The trap is already
## written up in CLAUDE.md; it cost this file a run to re-learn.
var _portal_entries: int = 0

## Tap counters, members for the same reason as the one above.
var _tapped_boat: int = 0
var _tapped_ground: int = 0

func _ready() -> void:
	# Armed FIRST, before anything that could itself hang. arm() covers the
	# frame-driven half, deadline() the blocking half -- this probe has
	# both shapes, exactly like StreamGeometryProbe.
	ProbeWatchdog.arm(self, "STREAM RIDE PROBE")
	var dl := ProbeWatchdog.deadline("STREAM RIDE PROBE")

	print("=== STREAM RIDE PROBE ===")
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var builder: HubBuilder = hub.get_node("WorldViewport/SubViewport/World/Props")
	var keepy: KeepyHopper = hub.get_node("WorldViewport/SubViewport/World/Keepy")
	var mooring: BoatMooring = hub.get_node("Mooring")

	var route := HubStreamRoute.new(builder.stream_spine())
	var half_width: float = builder.stream_half_width()

	_phase_hull(route, half_width, builder)
	_phase_speed(keepy, route)
	_phase_tap(mooring)
	await _phase_board(hub, keepy, mooring)
	await _phase_portals(hub, keepy, route, half_width, builder)
	await _phase_eject(keepy, route, half_width, builder)
	_phase_mooring(mooring, route, keepy)
	await _phase_mooring_visibility(hub, mooring, keepy, route)
	_phase_nodes(builder, dl)

	hub.queue_free()
	print("")
	print("--- %d check(s), %d failure(s) ---" % [_checks, _failures])
	print("=== END STREAM RIDE PROBE ===")
	get_tree().quit(1 if _failures > 0 else 0)

## ---------------------------------------------------------------------
## The hull has to fit the tightest bend of the trace it rides.
##
## A rigid hull of length L and beam B centred on a circle of radius R and
## turned along the tangent has its worst point at an OUTER CORNER, at
## sqrt((R + B/2)^2 + (L/2)^2) from the circle's centre. It stays on the
## water while that minus R is under the ribbon's half-width.
##
## Measured on the BUILT spine, never on the layout's control points: the
## drawn curve bends harder than the polyline through the same points, so
## checking the polyline would clear a hull the real water cannot hold.
func _phase_hull(route: HubStreamRoute, half_width: float, builder: HubBuilder) -> void:
	print("--- PHASE HULL: the boat fits the tightest bend ---")
	var spine: Array = builder.stream_spine()
	var radius: float = INF
	var at: int = -1
	for i in range(1, spine.size() - 1):
		var r: float = _circumradius(spine[i - 1], spine[i], spine[i + 1])
		if r < radius:
			radius = r
			at = i
	print("  built spine samples                 : %d" % spine.size())
	print("  minimum radius of curvature         : %.4f u (sample %d)" % [radius, at])
	print("  ribbon half-width                   : %.4f u" % half_width)
	print("  hull BOAT_LENGTH x BOAT_BEAM        : %.3f x %.3f u" % [
		HubBuilder.BOAT_LENGTH, HubBuilder.BOAT_BEAM])

	var excursion: float = sqrt(
		pow(radius + HubBuilder.BOAT_BEAM * 0.5, 2.0)
		+ pow(HubBuilder.BOAT_LENGTH * 0.5, 2.0)) - radius
	print("  worst outer-corner excursion        : %.4f u" % excursion)
	print("  margin against the half-width       : %.4f u" % (half_width - excursion))
	_check(excursion <= half_width,
		"the hull stays inside the ribbon at the tightest bend")
	_check(HubBuilder.BOAT_LENGTH <= 0.80, "BOAT_LENGTH is within its 0.80 ceiling")
	_check(HubBuilder.BOAT_BEAM <= 1.00, "BOAT_BEAM is within its 1.00 ceiling")

	# The hull must float ON the plateau, not inside it. The ground plane
	# is opaque at y = 0, and the first version of this boat hung its keel
	# below that -- the whole shell was clipped by the floor and the boat
	# rendered as a ring you could see the lake through. Nothing errored.
	var keel: float = HubBuilder.BOAT_FLOAT_Y - HubBuilder.BOAT_DEPTH
	print("  keel / rim height                   : %.3f / %.3f u" % [keel, HubBuilder.BOAT_FLOAT_Y])
	print("  stream surface / rider seat         : %.3f / %.3f u" % [
		HubBuilder.STREAM_SURFACE_Y, KeepyHopper.RIDE_SEAT_Y])
	_check(keel > 0.0, "the keel is above the ground plane, so nothing is clipped by the floor")
	_check(keel >= HubBuilder.STREAM_SURFACE_Y,
		"the keel is at or above the stream surface, so no water shows through the hull")
	_check(keel - HubBuilder.STREAM_SURFACE_Y < 0.05,
		"and it is close enough to the waterline not to read as hovering")
	_check(KeepyHopper.RIDE_SEAT_Y > keel and KeepyHopper.RIDE_SEAT_Y < HubBuilder.BOAT_FLOAT_Y,
		"the rider sits between the keel and the rim")
	print("")

## ---------------------------------------------------------------------
## The ride has to be a shortcut, not a scenic detour.
func _phase_speed(keepy: KeepyHopper, route: HubStreamRoute) -> void:
	print("--- PHASE SPEED: the ride beats the hop chain ---")
	var arc: float = route.length()
	var chord: float = route.head().distance_to(route.tail())
	var hops: int = 0
	var remaining: float = chord
	while remaining > KeepyHopper.ARRIVE_EPSILON:
		remaining -= minf(KeepyHopper.HOP_DISTANCE, remaining)
		hops += 1
	# A hop is one Tween over HOP_DURATION and a Tween ends on a FRAME
	# boundary, so a 0.28s hop really occupies 17 frames. The quantised
	# figure is the one a stopwatch sees.
	var frames: int = int(ceil(KeepyHopper.HOP_DURATION * 60.0))
	var hop_time: float = float(hops * frames) / 60.0
	var ride_time: float = arc / keepy.ride_speed
	print("  spine arc length          : %.4f u" % arc)
	print("  straight-line endpoints   : %.4f u  (meander ratio %.4f)" % [chord, arc / chord])
	print("  hop chain                 : %d hops, %.4f s" % [hops, hop_time])
	print("  ride at %.2f u/s          : %.4f s" % [keepy.ride_speed, ride_time])
	print("  measured shortcut floor   : %.4f u/s" % KeepyHopper.RIDE_SPEED_FLOOR)
	print("  floor recomputed here     : %.4f u/s" % (arc / hop_time))
	_check(keepy.ride_speed >= KeepyHopper.RIDE_SPEED_FLOOR,
		"ride_speed clears the documented floor")
	_check(ride_time < hop_time, "the ride arrives before the hop chain does")
	print("")

## ---------------------------------------------------------------------
## A tap on the boat has to beat the ground destination.
func _phase_tap(mooring: BoatMooring) -> void:
	print("--- PHASE TAP: the boat wins over the ground ---")
	_check(mooring.is_available(), "the mooring has a hull and a stream")
	var boat: Vector3 = mooring.boat_position()
	print("  hull moored at : (%.3f, %.3f)" % [boat.x, boat.z])

	# Driven through the real signal path, but at the world-point level:
	# accepts_boarding_tap() is the branch under test, and injecting a
	# screen event would test the projection instead.
	_check(mooring.accepts_boarding_tap(boat), "a tap ON the hull is a boarding tap")
	_check(mooring.accepts_boarding_tap(boat + Vector3(BoatMooring.BOARD_TAP_RADIUS - 0.1, 0.0, 0.0)),
		"a tap just inside the radius is a boarding tap")
	_check(not mooring.accepts_boarding_tap(boat + Vector3(BoatMooring.BOARD_TAP_RADIUS + 0.5, 0.0, 0.0)),
		"a tap outside the radius is NOT a boarding tap")
	_check(not mooring.accepts_boarding_tap(Vector3.ZERO),
		"a tap in the middle of the plateau is NOT a boarding tap")
	print("")

## ---------------------------------------------------------------------
## The whole boarding gesture, end to end, through the REAL tap handler.
##
## PHASE TAP checks the mooring's answer; this checks that the answer is
## actually reached -- HubTapInput's branch, HubWorld's arming, the hop
## chain, and the landing that boards. Driven by projecting the hull back
## to a screen point and feeding it to _handle_point, so the container rect
## and the ray projection are exercised rather than stepped around.
##
## This is why the probe must run under xvfb: --headless forces the DUMMY
## driver, where the container rect is 0x0 and _handle_point returns before
## it projects anything -- a green that means nothing.
func _phase_board(hub: Node, keepy: KeepyHopper, mooring: BoatMooring) -> void:
	print("--- PHASE BOARD: one tap, from screen point to aboard ---")
	var camera: Camera3D = hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	var container: SubViewportContainer = hub.get_node("WorldViewport")
	var viewport: SubViewport = hub.get_node("WorldViewport/SubViewport")
	var tap: HubTapInput = hub.get_node("TapInput")

	# Stand Keepy a few hops short of the hull and let the camera settle,
	# so the hull is really on screen to be aimed at.
	var boat: Vector3 = mooring.boat_position()
	keepy.global_position = boat + Vector3(0.0, 0.0, 4.0)
	for _i in 60:
		await get_tree().process_frame

	var rect: Rect2 = container.get_global_rect()
	var local: Vector2 = camera.unproject_position(boat)
	var screen: Vector2 = rect.position + Vector2(
		local.x * rect.size.x / float(viewport.size.x),
		local.y * rect.size.y / float(viewport.size.y))
	print("  hull at (%.2f, %.2f) projects to screen %s (rect %s)" % [
		boat.x, boat.z, screen, rect.size])
	_check(rect.has_point(screen), "the hull projects inside the viewport rect")

	tap.tapped_boat.connect(_count_boat_tap)
	tap.tapped_ground.connect(_count_ground_tap)

	# The control FIRST, while Keepy is still ashore: open ground well
	# outside the radius must still reach tapped_ground. Run after
	# boarding it would pass for the wrong reason -- the mooring refuses
	# every boarding tap during a ride, so any tap would go to ground.
	var far: Vector3 = boat + Vector3(0.0, 0.0, 8.0)
	var far_local: Vector2 = camera.unproject_position(far)
	var far_screen: Vector2 = rect.position + Vector2(
		far_local.x * rect.size.x / float(viewport.size.x),
		far_local.y * rect.size.y / float(viewport.size.y))
	_check(rect.has_point(far_screen), "the open-ground control point is on screen")
	_check(far.distance_to(boat) > BoatMooring.BOARD_TAP_RADIUS,
		"and it really is outside the boarding radius (%.2f u)" % far.distance_to(boat))
	_tapped_boat = 0
	_tapped_ground = 0
	tap._handle_point(far_screen)
	_check(_tapped_ground == 1 and _tapped_boat == 0,
		"a tap in open ground goes to tapped_ground (boat %d / ground %d)" % [
			_tapped_boat, _tapped_ground])

	_tapped_boat = 0
	_tapped_ground = 0
	tap._handle_point(screen)
	_check(_tapped_boat == 1, "a tap on the hull emits tapped_boat once (%d)" % _tapped_boat)
	_check(_tapped_ground == 0, "and does NOT emit tapped_ground (%d)" % _tapped_ground)

	# One tap. No second one anywhere below: the chain walks itself.
	var boarded: bool = false
	for _i in 600:
		await get_tree().process_frame
		if keepy.is_riding():
			boarded = true
			break
	_check(boarded, "that single tap carried Keepy all the way onto the boat")

	tap.tapped_boat.disconnect(_count_boat_tap)
	tap.tapped_ground.disconnect(_count_ground_tap)
	print("")

## ---------------------------------------------------------------------
## THE ONE THAT MATTERS MOST: no portal may fire while Keepy is aboard.
func _phase_portals(hub: Node, keepy: KeepyHopper, route: HubStreamRoute,
		half_width: float, builder: HubBuilder) -> void:
	print("--- PHASE PORTALS: nothing is entered from the boat ---")
	_portal_entries = 0
	for portal in builder.portals():
		portal.portal_entered.connect(_count_portal_entry)

	keepy.board(route, half_width, route.tail())
	await get_tree().process_frame
	_check(keepy.is_riding(), "board() put Keepy in the RIDING state")

	# The landing handler is called DIRECTLY with a portal's own centre --
	# the harshest form of the question. A ride emits no landings at all,
	# so this can only reach the guard, which is the point: it proves the
	# refusal rather than the absence.
	var portals: Array[HubPortal] = builder.portals()
	for portal in portals:
		hub._on_hop_landed(portal.global_position)
	_check(_portal_entries == 0, "a landing on a portal CENTRE is refused while riding (%d fired)" % _portal_entries)

	# And the tap path: a tap while riding must eject, never route.
	hub._on_tapped_ground(portals[0].global_position)
	await get_tree().process_frame
	_check(_portal_entries == 0, "a tap on a portal while riding does not enter it (%d fired)" % _portal_entries)
	_check(not keepy.is_riding(), "that tap ended the ride (it was an eject)")

	# Detection has to come BACK. Same call, now that the ride is over.
	hub._on_hop_landed(portals[0].global_position)
	_check(_portal_entries == 1, "portal detection resumes once off the boat (%d fired)" % _portal_entries)
	print("")

## ---------------------------------------------------------------------
## Leaving the boat lands clear of the props, with a taller arc.
func _phase_eject(keepy: KeepyHopper, route: HubStreamRoute, half_width: float,
		builder: HubBuilder) -> void:
	print("--- PHASE EJECT: the leap off lands somewhere legal ---")
	_check(KeepyHopper.EJECT_HOP_HEIGHT > KeepyHopper.HOP_HEIGHT,
		"the eject arc is taller than a standard hop (%.2f > %.2f)" % [
			KeepyHopper.EJECT_HOP_HEIGHT, KeepyHopper.HOP_HEIGHT])

	var footprints: Array = builder.ground_footprints()
	print("  prop footprints considered : %d" % footprints.size())
	_check(footprints.size() > 0, "the layout yields ground footprints to clear")

	# Ejected from a spread of points along the whole stream, to both
	# sides. Every landing has to be off the water and clear of every
	# footprint -- a single sample would only prove one bend.
	var worst_clearance: float = INF
	var tested: int = 0
	var on_water: int = 0
	var blocked: int = 0
	for step in 21:
		var s: float = route.length() * float(step) / 20.0
		for side in [1.0, -1.0]:
			var here: Vector3 = route.point_at(s)
			var tangent: Vector3 = route.tangent_at(s)
			var aim: Vector3 = here + Vector3(-tangent.z, 0.0, tangent.x) * (side * 6.0)
			keepy.board(route, half_width, route.tail())
			keepy._ride_s = s
			keepy.leave_ride(aim, footprints)
			var landing: Vector3 = keepy._hop_to
			tested += 1
			if route.distance_to(landing) <= half_width:
				on_water += 1
			var clearance: float = INF
			for entry in footprints:
				var where: Vector3 = entry["position"]
				clearance = minf(clearance, landing.distance_to(where) - float(entry["radius"]))
			worst_clearance = minf(worst_clearance, clearance)
			if clearance <= 0.0:
				blocked += 1
	print("  eject points tested          : %d" % tested)
	print("  landings still on the water  : %d" % on_water)
	print("  landings inside a footprint  : %d" % blocked)
	print("  worst clearance to any prop  : %.4f u" % worst_clearance)
	_check(on_water == 0, "every eject lands off the ribbon")
	_check(blocked == 0, "no eject lands inside a prop footprint")
	print("")

## ---------------------------------------------------------------------
## The mooring follows the player, and never moves in view.
func _phase_mooring(mooring: BoatMooring, route: HubStreamRoute, keepy: KeepyHopper) -> void:
	print("--- PHASE MOORING: the hull is never on the wrong side ---")
	print("  REMOOR_MIN_DISTANCE : %.2f u" % BoatMooring.REMOOR_MIN_DISTANCE)
	print("  BOARD_TAP_RADIUS    : %.2f u" % BoatMooring.BOARD_TAP_RADIUS)

	mooring.moor_now(route.head())
	var at_head: Vector3 = mooring.boat_position()
	_check(at_head.distance_to(route.head()) < 0.01,
		"moor_now parks at the end nearest the player (head)")
	mooring.moor_now(route.tail())
	_check(mooring.boat_position().distance_to(route.tail()) < 0.01,
		"moor_now parks at the end nearest the player (tail)")

	# Close to an end, the rule refuses to move the hull at all.
	mooring.moor_now(route.head())
	var near_head: Vector3 = route.head() + Vector3(1.0, 0.0, 0.0)
	mooring.update(near_head)
	_check(mooring.boat_position().distance_to(route.head()) < 0.01,
		"a player standing at one end never re-moors the hull")
	_check(route.distance_to_nearest_end(near_head) < BoatMooring.REMOOR_MIN_DISTANCE,
		"that player really is inside the re-moor threshold")

	# A player far from BOTH ends, on the tail side: the flip is allowed by
	# the distance rule. Whether it happens on this frame depends on the
	# frustum guard, which is the point of the guard -- so both outcomes
	# are legal and only the distance precondition is asserted.
	var mid: Vector3 = (route.head() + route.tail()) * 0.5
	var toward_tail: Vector3 = mid.lerp(route.tail(), 0.15)
	print("  distance from the test point to the nearest end : %.3f u" % (
		route.distance_to_nearest_end(toward_tail)))
	_check(route.distance_to_nearest_end(toward_tail) >= BoatMooring.REMOOR_MIN_DISTANCE,
		"the flip test point clears the distance rule")
	_check(route.nearest_end_abscissa(toward_tail) > 0.0,
		"and the tail really is its nearer end")
	print("")

## Drives the REAL camera to the flip point and reports whether the guard
## had to defer. Reported, never gated: whether a given plateau geometry
## puts the mooring in frame is a property of the layout, not a contract,
## and asserting either outcome would gate the trace instead of the code.
func _phase_mooring_visibility(hub: Node, mooring: BoatMooring, keepy: KeepyHopper,
		route: HubStreamRoute) -> void:
	print("--- PHASE MOORING VIEW: is a re-moor ever watched? ---")
	var camera: Camera3D = hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	var mid: Vector3 = (route.head() + route.tail()) * 0.5
	for label in ["head side", "tail side"]:
		var probe_at: Vector3 = mid.lerp(
			route.head() if label == "head side" else route.tail(), 0.15)
		# Park the hull at the FAR end so a flip is actually pending, then
		# let the camera settle on the player before asking. HubWorld's own
		# _process calls update() on every one of those frames, so what is
		# read back is the guard's verdict over 90 consecutive frames, not
		# over one.
		mooring.moor_now(route.tail() if label == "head side" else route.head())
		keepy.global_position = probe_at
		for _i in 90:
			await get_tree().process_frame
		var before: Vector3 = mooring.boat_position()
		var wanted: Vector3 = route.point_at(route.nearest_end_abscissa(probe_at))
		var in_frame: bool = camera.is_position_in_frustum(before)
		mooring.update(probe_at)
		var after: Vector3 = mooring.boat_position()
		var pending: bool = before.distance_to(wanted) > 0.01
		var outcome: String = "already there, nothing to move"
		if pending:
			outcome = "MOVED" if before.distance_to(after) > 0.01 else "HELD BACK by the frustum guard"
		print("  %-10s player (%6.2f,%6.2f)  hull (%6.2f,%6.2f) -> wants (%6.2f,%6.2f)" % [
			label, probe_at.x, probe_at.z, before.x, before.z, wanted.x, wanted.z])
		print("             hull in frustum: %-3s   flip pending: %-3s   %s" % [
			"yes" if in_frame else "no", "yes" if pending else "no", outcome])
	print("")

## ---------------------------------------------------------------------
## What the plateau costs to draw.
func _phase_nodes(builder: HubBuilder, dl: ProbeDeadline) -> void:
	print("--- PHASE NODES: the draw budget ---")
	var individual: int = 0
	var batches: int = 0
	var portal_meshes: int = 0
	var stack: Array[Node] = [builder]
	while not stack.is_empty():
		if dl != null and dl.abort_if_exceeded(get_tree()):
			return
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MultiMeshInstance3D:
			batches += 1
		elif node is MeshInstance3D:
			if _inside_portal(node):
				portal_meshes += 1
			else:
				individual += 1
	print("  individual MeshInstance3D (HubBuilder) : %d" % individual)
	print("  MultiMeshInstance3D batches            : %d" % batches)
	print("  draw nodes excluding portals           : %d" % (individual + batches))
	print("  draw nodes including portals           : %d" % (individual + batches + portal_meshes))
	_check(individual + batches <= 260, "the plateau is under the 260 draw-node ceiling")
	print("")

func _count_portal_entry(_game_id: StringName, _label: String) -> void:
	_portal_entries += 1

func _count_boat_tap(_point: Vector3) -> void:
	_tapped_boat += 1

func _count_ground_tap(_point: Vector3) -> void:
	_tapped_ground += 1

func _inside_portal(node: Node) -> bool:
	var walk: Node = node
	while walk != null:
		if walk is HubPortal:
			return true
		walk = walk.get_parent()
	return false

## ---------------------------------------------------------------------
func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("    OK   %s" % label)
	else:
		_failures += 1
		print("    FAIL %s" % label)

## Circumradius of three consecutive points, flat. INF for a straight run.
func _circumradius(a: Vector3, b: Vector3, c: Vector3) -> float:
	var fa := Vector2(a.x, a.z)
	var fb := Vector2(b.x, b.z)
	var fc := Vector2(c.x, c.z)
	var ab: float = fa.distance_to(fb)
	var bc: float = fb.distance_to(fc)
	var ca: float = fc.distance_to(fa)
	var area: float = absf((fb - fa).cross(fc - fa)) * 0.5
	if area < 0.0000001:
		return INF
	return (ab * bc * ca) / (4.0 * area)
