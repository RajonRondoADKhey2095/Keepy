extends Node
## LAKE-MOVE RECON -- measurement only. Moves nothing, changes nothing.
##
## Mathieu wants the great lake close enough to see from the plateau. This
## probe answers what that costs, on the SHIPPED hopper and the SHIPPED
## layout, so the decision is taken against numbers rather than against a
## picture of where a disc might go.
##
## =====================================================================
## THE QUESTION THAT DECIDES EVERYTHING: WHAT DOES A HOP CHAIN DO ABOUT
## WATER IN ITS WAY
##
## HubRegion.clamp_to() is asked ONCE, in HubTapInput, about the
## DESTINATION. KeepyHopper._begin_hop then walks a straight chord toward
## it -- `delta.normalized() * step` -- and consults nothing on the way.
## So the region's hole is a rule about where a tap may SEND Keepy, never
## about where he may PASS.
##
## That is read off the code, and PHASE B measures it rather than trusting
## the read: a trip whose chord crosses a shipped water body is walked, and
## every landing is tested against that water.
##
## It also makes PHASE D exact rather than extrapolated. Because no lake
## can bend a path, the hop chain for a trip is IDENTICAL with and without
## a candidate lake -- so testing the real landings against a candidate
## disc measures that candidate, it does not model it.
##
## =====================================================================
## HOW TO RUN
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
##     --path . res://scripts/dev/LakeMoveReconProbe.tscn
##
## --fixed-fps 60 is not optional: the seconds below are WALL-CLOCK frame
## counts, and a 0.28 s hop occupies 17 frames (0.2833 s), so a chain costs
## ~1.19% more than hops x HOP_DURATION. Quote the measured row.

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"
const _FPS: float = 60.0
const _LABEL: String = "LakeMoveReconProbe"

## The published worst case this bench has to restate before it is allowed
## to report anything new. A bench that cannot reproduce a number already
## in the record has no standing.
const _PUBLISHED_DIAGONAL_HOPS: int = 66
const _PUBLISHED_DIAGONAL_S: float = 18.700

## Shipped water geometry, read off HubBuilder rather than restated.
var _pond_centre: Vector3 = Vector3.ZERO
var _lake_centre: Vector3 = Vector3.ZERO
var _stream_points: Array = []
var _stream_half_width: float = 0.0

var _hop_count: int = 0
var _hop_done: bool = false
var _landings: Array[Vector3] = []

var _failures: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, _LABEL)
	print("=== LAKE-MOVE RECON (measurement only) ===")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame

	var keepy: KeepyHopper = hub.find_child("Keepy", true, false) as KeepyHopper
	if keepy == null:
		push_error("%s: no KeepyHopper in the hub scene." % _LABEL)
		get_tree().quit(1)
		return
	var builder: HubBuilder = hub.find_child("Props", true, false) as HubBuilder
	_read_water(builder)

	await _phase_control(keepy)
	await _phase_existing_water(keepy)
	await _phase_candidates(keepy)

	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(0)

## Water geometry, pulled off the layout the game actually builds from.
func _read_water(builder: HubBuilder) -> void:
	if builder == null or builder.layout == null:
		push_error("%s: no HubBuilder/layout." % _LABEL)
		return
	for entry in builder.layout.props:
		var type: StringName = entry.get("type", &"")
		if type == &"pond":
			_pond_centre = entry.get("position", Vector3.ZERO)
		elif type == &"lake":
			_lake_centre = entry.get("position", Vector3.ZERO)
		elif type == &"stream":
			_stream_points = entry.get("points", [])
			_stream_half_width = float(entry.get("width", 0.0)) * 0.5

## ====================================================================
## PHASE CONTROL -- restate a published number before reporting new ones.
func _phase_control(keepy: KeepyHopper) -> void:
	print("--- PHASE CONTROL: reproduce the published square diagonal ---")
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	var seconds: float = await _trip(keepy, "square diagonal",
		Vector3(-h, 0.0, -h), Vector3(h, 0.0, h))
	_check(_hop_count == _PUBLISHED_DIAGONAL_HOPS,
		"diagonal hops %d == published %d" % [_hop_count, _PUBLISHED_DIAGONAL_HOPS])
	_check(absf(seconds - _PUBLISHED_DIAGONAL_S) < 0.002,
		"diagonal %.3f s == published %.3f s" % [seconds, _PUBLISHED_DIAGONAL_S])

## ====================================================================
## PHASE B -- Q1. Does a hop chain walk over water that is already there?
func _phase_existing_water(keepy: KeepyHopper) -> void:
	print("--- PHASE EXISTING WATER (Q1): shipped pond / small lake / stream ---")
	# Trips whose straight chord crosses a shipped body. Endpoints are on
	# dry land and inside the region, so nothing here is a clamped tap --
	# the chord alone is what puts water under the path.
	var trips: Array = [
		["across the SMALL LAKE  (-35,-5) -> (-15,-5)", Vector3(-35.0, 0.0, -5.3), Vector3(-15.0, 0.0, -5.3)],
		["across the POND        (14,7) -> (28,8)",     Vector3(14.0, 0.0, 7.4),   Vector3(28.0, 0.0, 8.0)],
		["across the STREAM      (-2,4) -> (-2,16)",    Vector3(-2.0, 0.0, 4.0),   Vector3(-2.0, 0.0, 16.0)],
		["small lake, long chord (-35,-20) -> (-12,10)", Vector3(-35.0, 0.0, -20.0), Vector3(-12.0, 0.0, 10.0)],
	]
	var any_over: bool = false
	for trip in trips:
		await _trip(keepy, trip[0], trip[1], trip[2])
		var over_pond: int = 0
		var over_lake: int = 0
		var over_stream: int = 0
		for p in _landings:
			if _in_disc(p, _pond_centre, HubBuilder.POND_WATER_RADIUS):
				over_pond += 1
			if _in_disc(p, _lake_centre, HubBuilder.SMALL_LAKE_WATER_RADIUS):
				over_lake += 1
			if _on_stream(p):
				over_stream += 1
		var total: int = over_pond + over_lake + over_stream
		if total > 0:
			any_over = true
		print("        landings ON water: pond %d, small lake %d, stream %d  (of %d)"
			% [over_pond, over_lake, over_stream, _landings.size()])

	# The verdict, stated as an assertion so it cannot quietly change.
	_check(any_over,
		"MEASURED: a hop chain lands ON existing water -- there is NO avoidance")
	print("    VERDICT Q1: Keepy hops straight over ponds, lakes and the stream.")
	print("                HubRegion is consulted for the DESTINATION only.")

## ====================================================================
## PHASE D -- Q4. Cost of each candidate placement, on real hop chains.
func _phase_candidates(keepy: KeepyHopper) -> void:
	print("--- PHASE CANDIDATES (Q4): hops that would land on each candidate ---")
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	# The trip set. Centre <-> the three portals is what a hub is FOR, so
	# it leads; the diagonal is the published worst case; the edge/corner
	# pairs are the long walks a big disc is most likely to sit under.
	var trips: Array = [
		["centre -> portal chased",  Vector3.ZERO,                  Vector3(-5.4, 0.0, -4.6)],
		["centre -> portal quizz",   Vector3.ZERO,                  Vector3(0.0, 0.0, -7.2)],
		["centre -> portal battle",  Vector3.ZERO,                  Vector3(5.4, 0.0, -4.6)],
		["square diagonal",          Vector3(-h, 0.0, -h),          Vector3(h, 0.0, h)],
		["anti-diagonal",            Vector3(-h, 0.0, h),           Vector3(h, 0.0, -h)],
		["centre -> NE corner",      Vector3.ZERO,                  Vector3(h, 0.0, h)],
		["centre -> SE corner",      Vector3.ZERO,                  Vector3(h, 0.0, -h)],
		["centre -> NW corner",      Vector3.ZERO,                  Vector3(-h, 0.0, h)],
		["W edge -> E edge",         Vector3(-h, 0.0, 0.0),         Vector3(h, 0.0, 0.0)],
		["N edge -> S edge",         Vector3(0.0, 0.0, -h),         Vector3(0.0, 0.0, h)],
	]
	# Candidates: name, centre, radius. Chosen by the python sweep on the
	# same layout; re-measured here on the shipped hopper.
	var candidates: Array = [
		["CURRENT  az282 d54 r20", HubRegion.lake_centre(), 20.0],
		["P1  edge-straddle az45 (35,-35) r20", Vector3(35.0, 0.0, -35.0), 20.0],
		["P1' edge-straddle az225 (-35,35) r20", Vector3(-35.0, 0.0, 35.0), 20.0],
		["P2  inside (15,15) r20", Vector3(15.0, 0.0, 15.0), 20.0],
		["P3a inside (-27,27) r8", Vector3(-27.0, 0.0, 27.0), 8.0],
		["P3b inside (24.5,-25) r10", Vector3(24.5, 0.0, -25.0), 10.0],
		["P3c inside (22,19) r12", Vector3(22.0, 0.0, 19.0), 12.0],
	]

	# Walk every trip ONCE and keep its landings: the chain does not depend
	# on any candidate (no avoidance), so one walk serves every column.
	var walked: Array = []
	var worst_s: float = 0.0
	var worst_label: String = ""
	for trip in trips:
		var seconds: float = await _trip(keepy, trip[0], trip[1], trip[2])
		walked.append({"label": trip[0], "landings": _landings.duplicate(), "seconds": seconds})
		if seconds > worst_s:
			worst_s = seconds
			worst_label = trip[0]
	print("    worst trip in the set: %.3f s (%s)" % [worst_s, worst_label])
	print("    NOTE: these seconds are IDENTICAL for every candidate -- a lake")
	print("          cannot bend a chord, so no placement changes any timing.")

	for candidate in candidates:
		var name: String = candidate[0]
		var centre: Vector3 = candidate[1]
		var radius: float = candidate[2]
		var total_over: int = 0
		var total_hops: int = 0
		var worst_trip: String = ""
		var worst_over: int = 0
		for row in walked:
			var over: int = 0
			for p in row["landings"]:
				if _in_disc(p, centre, radius):
					over += 1
			total_over += over
			total_hops += (row["landings"] as Array).size()
			if over > worst_over:
				worst_over = over
				worst_trip = row["label"]
		print("    %-38s landings on water %3d / %3d   worst trip %2d (%s)"
			% [name, total_over, total_hops, worst_over, worst_trip])

## ====================================================================
func _trip(keepy: KeepyHopper, label: String, from: Vector3, to: Vector3) -> float:
	keepy.global_position = Vector3(from.x, 0.0, from.z)
	_hop_count = 0
	_hop_done = false
	_landings.clear()
	keepy.hop_landed.connect(_on_hop_landed)
	keepy.became_idle.connect(_on_hop_idle)
	keepy.hop_to(to)
	var frames: int = 0
	while not _hop_done and frames < 6000:
		await get_tree().process_frame
		frames += 1
	keepy.hop_landed.disconnect(_on_hop_landed)
	keepy.became_idle.disconnect(_on_hop_idle)
	var seconds: float = float(frames) / _FPS
	print("    %-46s hops=%3d frames=%5d  %.3f s%s"
		% [label, _hop_count, frames, seconds, "" if _hop_done else "  ** FRAME CAP **"])
	return seconds

func _on_hop_landed(position: Vector3) -> void:
	_hop_count += 1
	_landings.append(Vector3(position.x, 0.0, position.z))

func _on_hop_idle() -> void:
	_hop_done = true

func _in_disc(point: Vector3, centre: Vector3, radius: float) -> bool:
	return Vector2(point.x - centre.x, point.z - centre.z).length() < radius

## Distance from a landing to the stream's control polyline. The ribbon is
## drawn from a spline through these points and BULGES outside the chords,
## so this UNDERSTATES the ribbon -- which is the safe direction for a
## "does it touch water" test.
func _on_stream(point: Vector3) -> bool:
	if _stream_points.size() < 2 or _stream_half_width <= 0.0:
		return false
	for i in _stream_points.size() - 1:
		var a: Vector3 = _stream_points[i]
		var b: Vector3 = _stream_points[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(point.x - a.x, point.z - a.z)
		var len2: float = ab.length_squared()
		var t: float = 0.0 if len2 <= 0.0 else clampf(ap.dot(ab) / len2, 0.0, 1.0)
		if (ap - ab * t).length() <= _stream_half_width:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if condition:
		print("      OK   %s" % message)
	else:
		_failures += 1
		printerr("      FAIL %s" % message)
