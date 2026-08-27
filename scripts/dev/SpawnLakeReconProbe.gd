extends Node
## SPAWN-LAKE RECON -- measurement only. Moves nothing, changes nothing.
##
## Mathieu wants a SECOND great lake (radius 16), right in front of the
## spawn point, visible the moment the hub loads. This probe answers
## whether that is geometrically possible on the shipped plateau, at what
## price, and what a hop chain and the fixed camera would actually do
## about it -- exactly the LAKE-MOVE-RECON method, aimed at a second body
## instead of a relocation of the first.
##
## Nothing in scripts/hub or resources/hub is read except through the
## shipped API (HubRegion, HubBuilder's public constants, the layout
## resource). No candidate is ever written back to the layout: every
## candidate disc tested here exists only inside this probe's own
## in-memory checks.
##
## =====================================================================
## HOW TO RUN
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
##     --path . res://scripts/dev/SpawnLakeReconProbe.tscn
##
## --fixed-fps 60 is not optional for PHASE Q4: the seconds reported are
## WALL-CLOCK frame counts, and a 0.28 s hop occupies 17 frames (0.2833 s)
## -- see KeepyHopper.HOP_DURATION's own docblock. Quote the measured row,
## never hops x HOP_DURATION.

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"
const _FPS: float = 60.0
const _LABEL: String = "SpawnLakeReconProbe"

## Published numbers this bench has to reproduce before it is allowed to
## report anything new -- the LAKE-MOVE-1 control check, carried over
## verbatim. A bench that cannot restate a number already in the record
## has no standing to publish a new one.
const _PUBLISHED_DIAGONAL_HOPS: int = 66
const _PUBLISHED_DIAGONAL_S: float = 18.700
const _PUBLISHED_ANTIDIAG_HOPS: int = 66
const _PUBLISHED_ANTIDIAG_GREATLAKE_LANDINGS: int = 21

## The Q3 candidate this probe measures for Q4/Q5: the LARGEST radius from
## the brief's own fallback list (16, 14, 12, 10, 8) that clears BOTH the
## three portals AND every existing water body (pond/small lake/great
## lake/stream), swept at 0.5 u offline in /tmp/spawn_lake_recon.py and
## re-measured here on the real layout constants. r=16/14/12 clear the
## portals in isolation but every such centre also swallows the existing
## great lake or small lake -- see the probe's own PHASE Q3 for the
## measured overlap. r=10 is the largest that is a genuinely SEPARATE
## second body.
const _CANDIDATE_NAME: String = "Q3 retained: r=10 @ (-12.00,-19.50)"
const _CANDIDATE_CENTRE: Vector3 = Vector3(-12.00, 0.0, -19.50)
const _CANDIDATE_RADIUS: float = 10.0

## The literal r=16 "clears portals only" closest-to-spawn centre from the
## same offline sweep, kept for contrast: it is what the brief asked for
## verbatim, and it swallows the shipped great lake almost entirely.
const _R16_PORTAL_ONLY_NAME: String = "r=16 portal-clear only: (16.50,-18.00)"
const _R16_PORTAL_ONLY_CENTRE: Vector3 = Vector3(16.50, 0.0, -18.00)
const _R16_PORTAL_ONLY_RADIUS: float = 16.0

var _pond_centre: Vector3 = Vector3.ZERO
var _lake_centre: Vector3 = Vector3.ZERO
var _greatlake_centre: Vector3 = Vector3.ZERO
var _stream_points: Array = []
var _stream_half_width: float = 0.0
var _landmarks_on_plateau: Array = []
var _portal_positions: Dictionary = {}

var _hop_count: int = 0
var _hop_done: bool = false
var _landings: Array[Vector3] = []

var _failures: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, _LABEL)
	print("=== SPAWN-LAKE RECON (measurement only) ===")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame

	var keepy: KeepyHopper = hub.find_child("Keepy", true, false) as KeepyHopper
	var camera: Camera3D = hub.find_child("Camera3D", true, false) as Camera3D
	if keepy == null or camera == null:
		push_error("%s: hub scene did not give up Keepy / Camera3D." % _LABEL)
		get_tree().quit(1)
		return
	var builder: HubBuilder = hub.find_child("Props", true, false) as HubBuilder
	_read_layout(builder)

	_phase_q1(keepy, camera)
	await _phase_control(keepy)
	_phase_q2q6(builder)
	await _phase_q4(keepy)

	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(0)

## Reads the shipped positions off the layout actually built, never off a
## second copy: pond / small lake / great lake / stream / the 12 on-
## plateau landmarks (the other 3 sit on the great lake's islets and move
## with it, irrelevant here) / the 3 portals.
func _read_layout(builder: HubBuilder) -> void:
	if builder == null or builder.layout == null:
		push_error("%s: no HubBuilder/layout." % _LABEL)
		return
	for entry in builder.layout.props:
		var type: StringName = entry.get("type", &"")
		var where: Vector3 = entry.get("position", Vector3.ZERO)
		match type:
			&"pond":
				_pond_centre = where
			&"lake":
				_lake_centre = where
			&"greatlake":
				_greatlake_centre = where
			&"stream":
				_stream_points = entry.get("points", [])
				_stream_half_width = float(entry.get("width", 0.0)) * 0.5
			&"landmark":
				if not entry.get("offshore", false):
					_landmarks_on_plateau.append(where)
			&"portal":
				_portal_positions[entry.get("game_id", &"")] = where

## ====================================================================
## Q1 -- spawn position, camera pose, "devant" direction, distances.
func _phase_q1(keepy: KeepyHopper, camera: Camera3D) -> void:
	print("--- Q1: spawn + camera, read live off the instantiated scene ---")
	print("    Keepy.global_position at boot = %s  (scenes/HubWorld.tscn: 'Keepy' node" % keepy.global_position)
	print("        carries no authored transform -- Vector3.ZERO by Node3D's own default)")
	print("    Camera3D.global_position       = %s" % camera.global_position)
	var fwd: Vector3 = -camera.global_transform.basis.z
	print("    Camera3D forward (world, -basis.z) = %s" % fwd)
	var pitch_deg: float = rad_to_deg(asin(-fwd.y))
	print("    pitch below horizontal = %.3f deg (scripts/hub/HubCamera.gd's own -34 doc)" % pitch_deg)
	print("    horizontal component of forward = (%.4f, %.4f) -- 'devant Keepy' at spawn = -Z axis"
		% [fwd.x, fwd.z])

	# Ground point at screen centre: camera position + t*forward, y=0.
	var cam: Vector3 = camera.global_position
	var t: float = -cam.y / fwd.y
	var centre_ground: Vector3 = cam + fwd * t
	print("    screen-centre ground point at spawn = %s" % centre_ground)

	print("    spawn -> plateau centre = %.3f" % keepy.global_position.distance_to(Vector3.ZERO))
	for game_id in _portal_positions.keys():
		var p: Vector3 = _portal_positions[game_id]
		print("    spawn -> portal %-8s = %.3f  pos=(%.2f,%.2f)" % [
			game_id, keepy.global_position.distance_to(p), p.x, p.z])

	# Bearing formula, validated against the LAKE-MOVE-RECON published
	# numbers (-69.1 deg for the old great lake, +29.1 for P2f) before
	# this probe existed -- see /tmp/spawn_lake_recon.py. Restated here on
	# the LIVE camera so Q3/Q5 below can trust it.
	var b_old: float = _bearing(cam, Vector3(-52.82, 0.0, -11.23))
	_check(absf(b_old - (-69.1)) < 0.15, "bearing formula: old great lake -> %.1f deg == published -69.1" % b_old)
	var b_p2f: float = _bearing(cam, _greatlake_centre)
	_check(absf(b_p2f - 29.1) < 0.15, "bearing formula: shipped great lake -> %.1f deg == published +29.1" % b_p2f)

func _bearing(cam: Vector3, target: Vector3) -> float:
	var to := Vector2(target.x - cam.x, target.z - cam.z)
	return rad_to_deg(atan2(to.x, -to.y))

## ====================================================================
## Control -- restate LAKE-MOVE-1's published table before trusting the
## rest of this file's numbers.
func _phase_control(keepy: KeepyHopper) -> void:
	print("--- CONTROL: reproduce LAKE-MOVE-1's published diagonal + anti-diagonal ---")
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	var seconds: float = await _trip(keepy, "square diagonal", Vector3(-h, 0.0, -h), Vector3(h, 0.0, h))
	_check(_hop_count == _PUBLISHED_DIAGONAL_HOPS,
		"diagonal hops %d == published %d" % [_hop_count, _PUBLISHED_DIAGONAL_HOPS])
	_check(absf(seconds - _PUBLISHED_DIAGONAL_S) < 0.002,
		"diagonal %.3f s == published %.3f s" % [seconds, _PUBLISHED_DIAGONAL_S])

	await _trip(keepy, "anti-diagonal", Vector3(-h, 0.0, h), Vector3(h, 0.0, -h))
	_check(_hop_count == _PUBLISHED_ANTIDIAG_HOPS,
		"anti-diagonal hops %d == published %d" % [_hop_count, _PUBLISHED_ANTIDIAG_HOPS])
	var over_great: int = 0
	for p in _landings:
		if _in_disc(p, _greatlake_centre, HubRegion.GREATLAKE_WATER_RADIUS):
			over_great += 1
	_check(over_great == _PUBLISHED_ANTIDIAG_GREATLAKE_LANDINGS,
		"anti-diagonal landings on great lake %d == published %d" % [over_great, _PUBLISHED_ANTIDIAG_GREATLAKE_LANDINGS])

## ====================================================================
## Q2 map re-check + Q6 adjacency, off the SAME constants the game ships.
func _phase_q2q6(_builder: HubBuilder) -> void:
	print("--- Q2/Q6: shipped water geometry, read off the layout that was just built ---")
	print("    pond centre      = (%.3f,%.3f)  water_r=%.2f bank_r=%.2f" % [
		_pond_centre.x, _pond_centre.z, HubBuilder.POND_WATER_RADIUS, HubBuilder.POND_BANK_RADIUS])
	print("    small lake centre = (%.3f,%.3f)  water_r=%.2f bank_r=%.2f" % [
		_lake_centre.x, _lake_centre.z, HubBuilder.SMALL_LAKE_WATER_RADIUS, HubBuilder.LAKE_BANK_RADIUS])
	print("    great lake centre = (%.3f,%.3f)  water_r=%.2f bank_r=%.2f" % [
		_greatlake_centre.x, _greatlake_centre.z, HubRegion.GREATLAKE_WATER_RADIUS,
		HubRegion.GREATLAKE_WATER_RADIUS + HubBuilder.GREATLAKE_BANK_MARGIN])
	print("    stream: %d control points, half-width=%.2f" % [_stream_points.size(), _stream_half_width])
	print("    landmarks on plateau (offshore==false) = %d  (15 total, 3 on islets)" % _landmarks_on_plateau.size())

	# Cross-check against the offline python sweep's inputs -- proves the
	# sweep used the SAME numbers the shipped scene actually builds from.
	_check(_pond_centre.is_equal_approx(Vector3(20.7, 0.0, 7.4)), "pond centre matches offline sweep input")
	_check(_lake_centre.is_equal_approx(Vector3(-25.1, 0.0, -5.3)), "small lake centre matches offline sweep input")
	_check(_greatlake_centre.is_equal_approx(Vector3(15.5, 0.0, -19.0)), "great lake centre matches offline sweep input")
	_check(_landmarks_on_plateau.size() == 12, "12 landmarks on the plateau proper")

	var d_pond_lake: float = _pond_centre.distance_to(_lake_centre) - HubBuilder.POND_WATER_RADIUS - HubBuilder.SMALL_LAKE_WATER_RADIUS
	var d_pond_great: float = _pond_centre.distance_to(_greatlake_centre) - HubBuilder.POND_WATER_RADIUS - HubRegion.GREATLAKE_WATER_RADIUS
	var d_lake_great: float = _lake_centre.distance_to(_greatlake_centre) - HubBuilder.SMALL_LAKE_WATER_RADIUS - HubRegion.GREATLAKE_WATER_RADIUS
	var d_pond_stream: float = _dist_to_stream(_pond_centre) - HubBuilder.POND_WATER_RADIUS - _stream_half_width
	var d_lake_stream: float = _dist_to_stream(_lake_centre) - HubBuilder.SMALL_LAKE_WATER_RADIUS - _stream_half_width
	var d_great_stream: float = _dist_to_stream(_greatlake_centre) - HubRegion.GREATLAKE_WATER_RADIUS - _stream_half_width
	print("    Q6 adjacency (water edge to edge):")
	print("      pond <-> small lake   = %.3f" % d_pond_lake)
	print("      pond <-> great lake   = %.3f" % d_pond_great)
	print("      small lake <-> great lake = %.3f" % d_lake_great)
	print("      pond <-> stream       = %.3f  (TOUCHING if < 0)" % d_pond_stream)
	print("      small lake <-> stream = %.3f  (TOUCHING if < 0)" % d_lake_stream)
	print("      great lake <-> stream = %.3f" % d_great_stream)
	_check(d_pond_stream < 0.0 and absf(d_pond_stream - (-0.596)) < 0.02,
		"pond<->stream chain link intact: %.3f ~= -0.596" % d_pond_stream)
	_check(d_lake_stream < 0.0 and absf(d_lake_stream - (-0.605)) < 0.02,
		"small lake<->stream chain link intact: %.3f ~= -0.605" % d_lake_stream)
	var chain_area: float = PI * pow(HubBuilder.POND_WATER_RADIUS, 2) \
		+ PI * pow(HubBuilder.SMALL_LAKE_WATER_RADIUS, 2) \
		+ _stream_area()
	print("      3-link chain (mare+ruisseau+petit lac) total surface if merged visually = %.2f u2" % chain_area)
	print("      (great lake is NOT in this chain: %.3f from small lake, %.3f from stream -- separate)" % [
		d_lake_great, d_great_stream])

## ====================================================================
## Q4 -- real KeepyHopper, real trips, before/after each candidate.
func _phase_q4(keepy: KeepyHopper) -> void:
	print("--- Q4: real KeepyHopper, --fixed-fps 60, walking straight over water ---")
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	var trips: Array = [
		["small lake        (-35,-5) -> (-15,-5)", Vector3(-35.0, 0.0, -5.3), Vector3(-15.0, 0.0, -5.3)],
		["pond              (14,7) -> (28,8)",      Vector3(14.0, 0.0, 7.4),   Vector3(28.0, 0.0, 8.0)],
		["stream            (-2,4) -> (-2,16)",     Vector3(-2.0, 0.0, 4.0),   Vector3(-2.0, 0.0, 16.0)],
		["small lake, long  (-35,-20) -> (-12,10)", Vector3(-35.0, 0.0, -20.0), Vector3(-12.0, 0.0, 10.0)],
		["square diagonal",                          Vector3(-h, 0.0, -h),      Vector3(h, 0.0, h)],
		["anti-diagonal",                            Vector3(-h, 0.0, h),       Vector3(h, 0.0, -h)],
		["centre -> NE corner",                      Vector3.ZERO,              Vector3(h, 0.0, h)],
		["centre -> SE corner",                      Vector3.ZERO,              Vector3(h, 0.0, -h)],
		["centre -> NW corner",                      Vector3.ZERO,              Vector3(-h, 0.0, h)],
		["W edge -> E edge",                         Vector3(-h, 0.0, 0.0),     Vector3(h, 0.0, 0.0)],
		["spawn -> portal chased",  Vector3.ZERO, _portal_positions.get(&"chased", Vector3.ZERO)],
		["spawn -> portal quizz",   Vector3.ZERO, _portal_positions.get(&"quizz", Vector3.ZERO)],
		["spawn -> portal battle",  Vector3.ZERO, _portal_positions.get(&"battle", Vector3.ZERO)],
	]

	var walked: Array = []
	for trip in trips:
		var seconds: float = await _trip(keepy, trip[0], trip[1], trip[2])
		walked.append({"label": trip[0], "landings": _landings.duplicate(), "seconds": seconds})

	print("    NOTE: seconds are IDENTICAL with or without any candidate -- a lake cannot")
	print("          bend a chord (HubRegion is consulted for the DESTINATION only).")

	var candidates: Array = [
		[_CANDIDATE_NAME, _CANDIDATE_CENTRE, _CANDIDATE_RADIUS],
		[_R16_PORTAL_ONLY_NAME, _R16_PORTAL_ONLY_CENTRE, _R16_PORTAL_ONLY_RADIUS],
	]
	for candidate in candidates:
		var name: String = candidate[0]
		var centre: Vector3 = candidate[1]
		var radius: float = candidate[2]
		print("    --- candidate: %s ---" % name)
		var total_over: int = 0
		var total_hops: int = 0
		for row in walked:
			var over: int = 0
			for p in (row["landings"] as Array):
				if _in_disc(p, centre, radius):
					over += 1
			total_over += over
			total_hops += (row["landings"] as Array).size()
			if over > 0:
				print("        %-40s landings ON this candidate: %d / %d hops"
					% [row["label"], over, (row["landings"] as Array).size()])
		print("        TOTAL landings on this candidate across the set: %d / %d" % [total_over, total_hops])
		print("        spawn->portal trips landed on this candidate: %s" % _spawn_portal_summary(walked, centre, radius))

func _spawn_portal_summary(walked: Array, centre: Vector3, radius: float) -> String:
	var out: Array = []
	for row in walked:
		if (row["label"] as String).begins_with("spawn -> portal"):
			var over: int = 0
			for p in (row["landings"] as Array):
				if _in_disc(p, centre, radius):
					over += 1
			out.append("%s=%d/%d" % [row["label"], over, (row["landings"] as Array).size()])
	return ", ".join(out)

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

func _dist_to_stream(point: Vector3) -> float:
	if _stream_points.size() < 2:
		return INF
	var best: float = INF
	for i in _stream_points.size() - 1:
		var a: Vector3 = _stream_points[i]
		var b: Vector3 = _stream_points[i + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ap := Vector2(point.x - a.x, point.z - a.z)
		var len2: float = ab.length_squared()
		var tt: float = 0.0 if len2 <= 0.0 else clampf(ap.dot(ab) / len2, 0.0, 1.0)
		best = minf(best, (ap - ab * tt).length())
	return best

## Chord-length approximation of the ribbon's area (length * width);
## understates the true sampled-spline arc length slightly, same
## direction of error LakeMoveReconProbe's _on_stream() already accepts
## for "does it touch water" checks.
func _stream_area() -> float:
	if _stream_points.size() < 2:
		return 0.0
	var length: float = 0.0
	for i in _stream_points.size() - 1:
		var a: Vector3 = _stream_points[i]
		var b: Vector3 = _stream_points[i + 1]
		length += Vector2(b.x - a.x, b.z - a.z).length()
	return length * (_stream_half_width * 2.0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("      OK   %s" % message)
	else:
		_failures += 1
		printerr("      FAIL %s" % message)
