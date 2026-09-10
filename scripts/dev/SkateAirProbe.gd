extends Node
## CH66 -- ARE THE TRICKS REACHABLE BY A THUMB? The window, measured
## against the gesture, on the real quarterpipes, through the real writer.
##
## =====================================================================
## WHY THIS PROBE EXISTS WHEN SkateTrickProbe IS 54/0
##
## SkateTrickProbe proves the recogniser, the air predicate, the landing
## cut, the flip and the feedback -- each on its own, and each on a
## SYNTHETIC pop (`body.velocity.y = 6.0`, 0.46 s of air) with a circle
## delivered THREE POINTS A TICK (0.2 s for a whole loop). Nothing in it
## asks the one question a player asks: on the ramp the game actually
## ships, at the speed the board actually reaches, is the armed air LONGER
## than the time a thumb needs to draw the circle? CH64 shipped 54 green
## assertions and Mathieu never once saw a trick fire on device. This
## probe measures both sides of that inequality and prints them next to
## each other.
##
## What a headless bench CANNOT sign (CLAUDE.md, CH62): how fast Mathieu's
## thumb really draws a circle. So the gesture side is published as a
## TABLE over thumb speeds, and the gate is written against a stated
## reference thumb whose numbers are in this file, not against a feeling.
##
## Headless: nothing here reads a pixel, a MultiMesh instance, a viewport
## size or a shader. Every launch is driven through SkateTouchInput with
## real InputEvents (SkateBench), never through hold() -- CH58's lesson.

## 1200 and not 600: the run is a few minutes headless and over ten under
## xvfb (llvmpipe paints 1080 x 1920 every frame of every ride), and the
## xvfb run is the one that signs the frame.
const BUDGET_S: float = 1200.0
const NEUTRAL: Vector3 = Vector3(12.0, 0.0, 52.0)
const FINGER: Vector2 = Vector2(540.0, 1300.0)
## How far before the module's centre the run starts, along the ramp's
## own axis (SkatePhysicsProbe RIDES: -9.0 for the big one, -8.0 for the
## small one -- the small one's station at -9.0 leaves the region).
const RUN_UP: Dictionary = {2: 9.0, 3: 8.0}
## The reference thumb the gate is written for. A circle of 40 px radius
## (about 8 mm on a 6.1-inch phone at ~460 px/in -- a small, natural
## thumb loop) drawn at 400 px/s (a brisk but ordinary swipe; a flick is
## 800 and up). Both are published in every line that uses them.
const REF_RADIUS_PX: float = 40.0
const REF_SPEED_PX_S: float = 400.0
## A simple reaction time: the player has to SEE the take-off before the
## thumb starts its loop. 0.2 s is the textbook figure for a visual
## reaction; it is published in every line that spends it.
const REF_REACTION_S: float = 0.20
const THUMB_SPEEDS: Array = [250.0, 400.0, 600.0, 800.0]
const RADII: Array = [30.0, 40.0, 60.0, 80.0]

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _transport: HubTransport = null
var _camera: Camera3D = null
var _touch: SkateTouchInput = null
var _park: HubSkatepark = null
var _bench: SkateBench = null
var _tricks: Array = []
var _took_off: int = 0
var _landed: int = 0
var _verbose: bool = false

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE AIR PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_air_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _run() -> void:
	print("=== SKATE AIR PROBE -- CH66: the window against the gesture ===")
	print("driver: %s" % DisplayServer.get_name())
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	for _i in 24:
		await get_tree().process_frame
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	_camera = _hub.find_child("Camera3D", true, false) as Camera3D
	_park = _hub.find_child("Skatepark", true, false) as HubSkatepark
	if _keepy == null or _transport == null or _camera == null or _park == null:
		push_error("SkateAirProbe: hub is missing Keepy / Transport / Camera3D / Skatepark.")
		get_tree().quit(1)
		return
	_touch = _transport.board_touch()
	_touch.trick.connect(func(cw: bool) -> void: _tricks.append(cw))
	var body := _transport.board_body()
	body.took_off.connect(func() -> void: _took_off += 1)
	body.landed.connect(func() -> void: _landed += 1)
	_bench = SkateBench.new()
	_bench.name = "Bench"
	add_child(_bench)
	_bench.setup(_transport, _camera)
	_phase_pop_geometry()
	var gesture: Dictionary = _phase_gesture_cost()
	_phase_raw_finger()
	var launches: Dictionary = {}
	for index in [2, 3]:
		launches[index] = await _phase_launch(index, 0.0)
	await _phase_first_launch()
	await _phase_off_axis(launches)
	await _phase_end_to_end()
	await _phase_grace()
	_phase_verdict(gesture, launches)
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE P -- THE POP IS A LIP POP: the last facet of every transition in
# the park qualifies, the facet under it does not (see POP_MAX_NORMAL_Y)

func _facet_ny(prof: Array[Vector2], s: int) -> float:
	var a: Vector2 = prof[s]
	var b: Vector2 = prof[s + 1]
	var slope: float = atan2(b.y - a.y, b.x - a.x)
	return cos(slope)

func _phase_pop_geometry() -> void:
	print("-- PHASE P: the pop leaves from a LIP (facet within %.0f deg of vertical: normal.y < %.4f) --"
		% [rad_to_deg(acos(SkateBoardBody.POP_MAX_NORMAL_Y)), SkateBoardBody.POP_MAX_NORMAL_Y])
	for index in [2, 3]:
		var args: Array = HubSkatepark.build_args(HubSkatepark.MODULES[index])
		var prof: Array[Vector2] = SkateparkMesh.quarterpipe_profile(args[1])
		var last: float = _facet_ny(prof, prof.size() - 2)
		var under: float = _facet_ny(prof, prof.size() - 3)
		print("     [%d] quarterpipe %.2f: last facet normal.y %.4f, the one under it %.4f" % [index, args[1], last, under])
		_check(last < SkateBoardBody.POP_MAX_NORMAL_Y and under >= SkateBoardBody.POP_MAX_NORMAL_Y,
			"P[%d] the lip facet pops (%.4f) and the facet under it does not (%.4f)" % [index, last, under])
	var bargs: Array = HubSkatepark.build_args(HubSkatepark.MODULES[4])
	var bprof: Array[Vector2] = SkateparkMesh.bowl_profile(bargs[0], bargs[1])
	var blast: float = _facet_ny(bprof, bprof.size() - 2)
	var bunder: float = _facet_ny(bprof, bprof.size() - 3)
	print("     [4] bowl: last facet normal.y %.4f, the one under it %.4f" % [blast, bunder])
	_check(blast < SkateBoardBody.POP_MAX_NORMAL_Y and bunder >= SkateBoardBody.POP_MAX_NORMAL_Y,
		"P[4] the bowl's lip facet pops (%.4f) and the one under it does not (%.4f)" % [blast, bunder])
	# the funbox never qualifies: its deck is flat and its ramps 30.6 deg
	var fargs: Array = HubSkatepark.build_args(HubSkatepark.MODULES[0])
	var ramp_ny: float = cos(atan2(fargs[2], fargs[3]))
	_check(ramp_ny >= SkateBoardBody.POP_MAX_NORMAL_Y and 1.0 >= SkateBoardBody.POP_MAX_NORMAL_Y,
		"P[0] the funbox ramp (normal.y %.3f) and deck (1.0) never pop" % ramp_ny)

# =====================================================================
# PHASE C -- WHAT THE GESTURE COSTS, IN PIXELS OF TRAVEL, ON THE
# RECOGNISER ITSELF

## Feeds a circle of radius `r` at ONE pixel per event (finer than any
## phone samples, so the answer is the recogniser's own quantisation and
## not the bench's) and returns the travel at which the first trick fired.
func _travel_to_fire(r: float, clockwise: bool = true) -> float:
	_touch.enabled = true
	_touch.set_air(false)
	_tricks.clear()
	var centre: Vector2 = FINGER + Vector2(r, 0.0)
	_touch._unhandled_input(_press(FINGER))
	_touch.set_air(true)
	var steps: int = int(ceil(TAU * r * 2.0))
	var travel: float = 0.0
	var last: Vector2 = FINGER
	for k in range(1, steps + 1):
		var t: float = TAU * float(k) / float(steps) * 2.0 * (1.0 if clockwise else -1.0)
		var p: Vector2 = centre + Vector2(-cos(t), -sin(t)) * r
		travel += p.distance_to(last)
		last = p
		_touch._unhandled_input(_drag(p))
		if not _tricks.is_empty():
			break
	_touch._unhandled_input(_release(last))
	_touch.set_air(false)
	_touch.enabled = false
	return travel if not _tricks.is_empty() else INF

func _phase_gesture_cost() -> Dictionary:
	print("-- PHASE C: the gesture, priced on the recogniser (sweep %.0f deg, segment %.0f px) --"
		% [SkateTouchInput.TRICK_SWEEP_DEG, SkateTouchInput.TRICK_SEG_PX])
	var out: Dictionary = {}
	var header: String = "     radius   travel px  "
	for s in THUMB_SPEEDS:
		header += "  @%4.0f px/s" % float(s)
	print(header)
	for r in RADII:
		var travel: float = _travel_to_fire(float(r))
		out[float(r)] = travel
		var line: String = "     %4.0f px   %7.1f    " % [float(r), travel]
		for s in THUMB_SPEEDS:
			line += "   %6.3f s" % (travel / float(s))
		print(line)
	# The arithmetic the table should reproduce: 300 deg of a circle of
	# radius r is 5.236 r of arc, and the first segment writes no angle.
	var r40: float = float(out[40.0])
	var ideal: float = deg_to_rad(SkateTouchInput.TRICK_SWEEP_DEG) * 40.0 + SkateTouchInput.TRICK_SEG_PX
	_check(r40 < INF, "C INSTRUMENT: a 40 px circle fires at all (travel %.1f px)" % r40)
	_check(absf(r40 - ideal) < 2.5 * SkateTouchInput.TRICK_SEG_PX,
		"C the 40 px circle fires within three segments of the arc arithmetic (%.1f vs %.1f px)" % [r40, ideal])
	var t_ref: float = r40 / REF_SPEED_PX_S
	print("     REFERENCE THUMB: r %.0f px at %.0f px/s needs %.3f s of window, plus %.2f s of reaction = %.3f s"
		% [REF_RADIUS_PX, REF_SPEED_PX_S, t_ref, REF_REACTION_S, t_ref + REF_REACTION_S])
	out["ref_s"] = t_ref
	out["need_s"] = t_ref + REF_REACTION_S
	return out

# =====================================================================
# PHASE F -- THE RECOGNISER READS THE RAW FINGER, NOT THE FILTERED ONE

func _phase_raw_finger() -> void:
	print("-- PHASE F: CH65's filter does not reach the trick (verified, not read off a comment) --")
	_touch.enabled = true
	_touch.set_air(false)
	_tricks.clear()
	_touch._unhandled_input(_press(FINGER))
	_touch.set_air(true)
	# A whole 60 px circle delivered in TWO writer ticks: the filtered
	# finger (FINGER_LAMBDA 14 at 1/60 s) moves ~23 % of the way per tick
	# and cannot possibly have turned through 300 deg.
	var centre: Vector2 = FINGER + Vector2(60.0, 0.0)
	var raw_travel: float = 0.0
	var smooth_travel: float = 0.0
	var last: Vector2 = FINGER
	var last_smooth: Vector2 = _touch.smooth_finger()
	for k in range(1, 37):
		var t: float = TAU * float(k) / 36.0
		var p: Vector2 = centre + Vector2(-cos(t), -sin(t)) * 60.0
		raw_travel += p.distance_to(last)
		last = p
		_touch._unhandled_input(_drag(p))
		if k == 18 or k == 36:
			_touch.tick(1.0 / 60.0)
			smooth_travel += _touch.smooth_finger().distance_to(last_smooth)
			last_smooth = _touch.smooth_finger()
	print("     raw finger travelled %.1f px, the filtered finger %.1f px, tricks fired %d"
		% [raw_travel, smooth_travel, _tricks.size()])
	_check(smooth_travel < raw_travel * 0.5,
		"F INSTRUMENT: the filtered finger really lagged (%.1f px of %.1f)" % [smooth_travel, raw_travel])
	_check(_tricks.size() == 1,
		"F the circle fired anyway: the recogniser walks the RAW finger (%d)" % _tricks.size())
	_touch._unhandled_input(_release(last))
	_touch.set_air(false)
	_touch.enabled = false

# =====================================================================
# PHASE W -- THE WINDOW, ON EACH QUARTERPIPE, AT THE SPEED THE RUN GIVES

func _park_board(flat: Vector3, facing: Vector3) -> void:
	var body := _transport.board_body()
	if _transport.is_riding_board():
		body.stop()
		body.global_position = HubSurface.ground(NEUTRAL)
		_keepy.call("follow_carrier")
		await get_tree().physics_frame
		_transport.leave_board()
		for _i in 20:
			await get_tree().physics_frame
	for _i in 180:
		if not _keepy.is_hopping() and not _keepy.is_on_carrier():
			break
		await get_tree().physics_frame
	_keepy.dismount_vehicle()
	body.stop()
	body.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	body.rotation.y = atan2(facing.x, facing.z)
	_keepy.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	for _i in 6:
		await get_tree().physics_frame

## Returns true when the camera came to rest BEHIND the board.
func _settle_chase() -> bool:
	var last: Transform3D = _camera.global_transform
	var stable: int = 0
	for _i in 480:
		await get_tree().physics_frame
		var now: Transform3D = _camera.global_transform
		# ⚠️ FULLY IN THE CHASE, not "not yet blending": right after a
		# mount the blend is still 0 and the hub camera is perfectly still,
		# and a settle that accepted that returned after eight ticks with
		# the whole 180 deg swing still to come -- measured: the small
		# quarterpipe's straight run reached its lip with the camera at
		# yaw -40 deg and the board 267 px OFF THE LEFT of the canvas.
		var blended: bool = true
		if _camera.has_method("drive_blend"):
			var b: float = _camera.call("drive_blend")
			blended = b > 0.999
		# AND BEHIND THE BOARD: the chase yaw is capped at 110 deg/s, so a
		# board parked the other way from the last run is followed by a
		# camera that is still swinging round for 1.6 s. A launch under a
		# camera 40 deg off is not the launch a settled player makes, and
		# this bench measures the settled one (the device protocol tells
		# Mathieu to ride a loop first for the same reason).
		var body := _transport.board_body()
		var facing := Vector3(sin(body.rotation.y), 0.0, cos(body.rotation.y))
		var forward: Vector3 = -_camera.global_transform.basis.z
		forward.y = 0.0
		var aligned: bool = forward.length() > 0.001 and forward.normalized().dot(facing) > cos(deg_to_rad(3.0))
		if blended and aligned and now.origin.distance_to(last.origin) < 0.0005 \
				and (now.basis.z - last.basis.z).length() < 0.0002:
			stable += 1
			if stable >= 8:
				return true
		else:
			stable = 0
		last = now
	# A board parked at the lobe's rim facing inward cannot be chased
	# from behind: the pose is outside the region and CH64's keep_inside
	# clamps it. The station still measures the WINDOW (physics does not
	# read the camera); the FRAME is signed by PHASE R, the real launch.
	print("     (settle: the camera never came to rest behind the board -- forward.dot(facing) %.3f)" % (-_camera.global_transform.basis.z).dot(Vector3(sin(_transport.board_body().rotation.y), 0.0, cos(_transport.board_body().rotation.y))))
	return false

func _ramp_dir(index: int) -> Vector3:
	var d: Vector3 = _park.module_node(index).global_transform.basis * Vector3(0.0, 0.0, 1.0)
	return Vector3(d.x, 0.0, d.z).normalized()

## One run at the ramp with the finger HELD (the real gesture: a thumb
## down through the whole air), the heading `off_deg` off the ramp's
## axis. Returns the trace as a dictionary of published numbers.
func _launch(index: int, off_deg: float, label: String) -> Dictionary:
	var body := _transport.board_body()
	var dir: Vector3 = _ramp_dir(index)
	var centre: Vector3 = _park.module_centre(index)
	var lip: float = float(HubSkatepark.MODULES[index]["size"].y)
	var from: Vector3 = centre - dir * float(RUN_UP[index])
	var heading: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(off_deg))
	await _park_board(from, dir)
	var mounted: bool = _transport.mount_board()
	var settled: bool = await _settle_chase()
	_took_off = 0
	_landed = 0
	_tricks.clear()
	_bench.hold(heading)
	var t := {"mounted": mounted, "in_region": HubRegion.contains(from), "settled": settled,
		"unsupported": 0, "armed": 0, "peak_y": 0.0, "left_at": -1, "armed_at": -1,
		"landed_at": -1, "v_leave": Vector3.ZERO, "landed_on_module": false,
		"land_pos": Vector3.ZERO, "speed_at_foot": 0.0, "held_max_y": 0.0,
		"took_off": 0, "landed": 0, "first_leave": -1, "armed_best": 0, "window_best": 0,
		"grace_max": 0, "pops": 0, "fenced": 0, "end_in_region": true}
	var was_module: bool = false
	var last_v: Vector3 = Vector3.ZERO
	var done: bool = false
	var armed_run: int = 0
	var window_run: int = 0
	var pops0: int = body.pops()
	var fenced: int = 0
	var on_fenced := func() -> void: fenced += 1
	body.fenced.connect(on_fenced)
	for tick in 420:
		await get_tree().physics_frame
		var y: float = body.global_position.y
		t["peak_y"] = maxf(float(t["peak_y"]), y)
		if _verbose and tick % 15 == 0 and int(t["first_leave"]) < 0:
			print("        run t%03d board yaw %.1f cam yaw %.1f blend %.3f pos (%.2f, %.2f) cam (%.2f, %.2f, %.2f)" % [tick, rad_to_deg(body.rotation.y), rad_to_deg(_camera.global_rotation.y), float(_camera.call("drive_blend")), body.global_position.x, body.global_position.z, _camera.global_position.x, _camera.global_position.y, _camera.global_position.z])
		if body.airborne() and int(t["landed_at"]) < 0:
			var scr: Vector2 = _camera.unproject_position(body.global_position + Vector3(0.0, SkateparkMesh.DECK_TOP, 0.0))
			t["screen_min_y"] = minf(float(t.get("screen_min_y", 1e9)), scr.y)
			t["screen_max_y"] = maxf(float(t.get("screen_max_y", -1e9)), scr.y)
			if _verbose:
				print("        screen t%03d (%.0f, %.0f) cam yaw %.1f deg at (%.2f, %.2f, %.2f)" % [tick, scr.x, scr.y, rad_to_deg(_camera.global_rotation.y), _camera.global_position.x, _camera.global_position.y, _camera.global_position.z])
			if scr.x < float(t.get("screen_min_x", 1e9)):
				t["screen_min_x"] = scr.x
				t["screen_min_x_at"] = "tick %d pos (%.2f, %.2f, %.2f) cam (%.2f, %.2f, %.2f)" % [tick, body.global_position.x, body.global_position.y, body.global_position.z, _camera.global_position.x, _camera.global_position.y, _camera.global_position.z]
			t["screen_max_x"] = maxf(float(t.get("screen_max_x", -1e9)), scr.x)
		armed_run = armed_run + 1 if body.in_air() else 0
		t["armed_best"] = maxi(int(t["armed_best"]), armed_run)
		window_run = window_run + 1 if _touch.path_live() else 0
		t["window_best"] = maxi(int(t["window_best"]), window_run)
		if _touch.path_live() and int(t.get("path_open_at", -1)) < 0:
			t["path_open_at"] = tick
		t["grace_max"] = maxi(int(t["grace_max"]), _touch.grace_ticks())
		if body.on_module():
			t["held_max_y"] = maxf(float(t["held_max_y"]), y)
			if float(t["speed_at_foot"]) == 0.0:
				t["speed_at_foot"] = body.speed()
		var free: bool = body.airborne()
		if free:
			t["unsupported"] = int(t["unsupported"]) + 1
			if int(t["first_leave"]) < 0 and was_module:
				t["first_leave"] = tick
				t["v_leave"] = last_v
		if body.in_air():
			t["armed"] = int(t["armed"]) + 1
			if int(t["armed_at"]) < 0:
				t["armed_at"] = tick
		if int(t["armed_at"]) >= 0 and int(t["landed_at"]) < 0 and not body.in_air():
			t["landed_at"] = tick
			t["landed_on_module"] = body.on_module()
			t["land_pos"] = body.global_position
		if _verbose and (int(t["first_leave"]) >= 0 or (was_module and free)) and (int(t["landed_at"]) < 0 or tick <= int(t["landed_at"]) + 12):
			print("        t%03d y %.3f v (%.2f, %.2f, %.2f) module %s supported %s free %s air_ticks %d in_air %s pos (%.2f, %.2f)"
				% [tick, y, body.velocity.x, body.velocity.y, body.velocity.z, str(body.on_module()),
					str(body.supported()), str(free), body.air_ticks(), str(body.in_air()),
					body.global_position.x, body.global_position.z])
		was_module = body.on_module()
		last_v = body.velocity
		# Stop once it has landed from an armed air and rolled a moment,
		# or once it is plainly not going to fly.
		if int(t["landed_at"]) >= 0 and tick > int(t["landed_at"]) + 30:
			done = true
		if tick > 300 and int(t["armed_at"]) < 0:
			done = true
		if done:
			break
	_bench.release()
	body.fenced.disconnect(on_fenced)
	t["took_off"] = _took_off
	t["landed"] = _landed
	t["lip"] = lip
	t["pops"] = body.pops() - pops0
	t["fenced"] = fenced
	t["end_in_region"] = HubRegion.contains(body.flat_position())
	for _i in 30:
		await get_tree().physics_frame
	var v: Vector3 = t["v_leave"]
	print("     %-34s in region %s  foot speed %.2f  left tick %d v (%.2f, %.2f, %.2f)  armed at %d  landed at %d  unsupported %d ticks  armed %d ticks (longest air %d = %.3f s)  WINDOW %d ticks = %.3f s (grace max %d)  peak y %.3f (lip %.2f, held max %.3f)  pops %d  took_off %d landed %d  fenced %d  landed on module %s at (%.2f, %.2f, %.2f)"
		% [label, str(t["in_region"]), float(t["speed_at_foot"]), int(t["first_leave"]), v.x, v.y, v.z,
			int(t["armed_at"]), int(t["landed_at"]), int(t["unsupported"]), int(t["armed"]),
			int(t["armed_best"]), float(t["armed_best"]) / 60.0, int(t["window_best"]), float(t["window_best"]) / 60.0,
			int(t["grace_max"]), float(t["peak_y"]), lip, float(t["held_max_y"]), int(t["pops"]),
			int(t["took_off"]), int(t["landed"]), int(t["fenced"]), str(t["landed_on_module"]),
			(t["land_pos"] as Vector3).x, (t["land_pos"] as Vector3).y, (t["land_pos"] as Vector3).z])
	return t

func _phase_launch(index: int, off_deg: float) -> Dictionary:
	var kind: String = String(_park.module_kind(index))
	print("-- PHASE W[%d]: the %s %.2f, straight at cruise, finger held --"
		% [index, kind, float(HubSkatepark.MODULES[index]["size"].y)])
	_verbose = true
	var t: Dictionary = await _launch(index, off_deg, "[%d] %s straight" % [index, kind])
	_verbose = false
	_check(bool(t["mounted"]) and bool(t["in_region"]), "W[%d] INSTRUMENT: aboard, station inside the region" % index)
	_check(float(t["speed_at_foot"]) > 8.0,
		"W[%d] INSTRUMENT: the board reached the foot near cruise (%.2f u/s)" % [index, float(t["speed_at_foot"])])
	_check(int(t["took_off"]) >= 1 and int(t["landed"]) >= 1,
		"W[%d] the launch is an ARMED air with a landing (took_off %d, landed %d)" % [index, int(t["took_off"]), int(t["landed"])])
	_check(int(t["pops"]) == 1, "W[%d] the lip gave exactly ONE pop (%d)" % [index, int(t["pops"])])
	# The polyline opens on the FIRST free tick, not on the sixth: the
	# dwell decides whether the air counts, not where the circle starts.
	# One control tick after the body's own edge (HubTransport reads the
	# body, then steps it), which is where `set_air` has always read it.
	_check(int(t.get("path_open_at", -1)) <= int(t["first_leave"]) + 1 and int(t["armed_at"]) > int(t.get("path_open_at", -1)),
		"W[%d] the circle's polyline opened on the first free tick (%d, body edge %d), %d ticks before the air armed (%d)"
			% [index, int(t.get("path_open_at", -1)), int(t["first_leave"]), int(t["armed_at"]) - int(t.get("path_open_at", -1)), int(t["armed_at"])])
	_check(int(t["fenced"]) == 0 and bool(t["end_in_region"]),
		"W[%d] the flight lands and rolls out INSIDE the region (fenced %d)" % [index, int(t["fenced"])])
	# The frame: the board stays in the picture through the whole air.
	# `unproject_position` is a pure calculation (headless half of the
	# rule), and the viewport is asserted real first.
	# ⚠️ THE CANVAS IS THE DEVICE'S ONLY UNDER A REAL DRIVER: `stretch = true`
	# gives the SubViewport the WINDOW's size, which is 1920 x 1920 in
	# headless (CLAUDE.md). The numbers are printed either way; the gate
	# is only signed on a 1080 x 1920 canvas (xvfb).
	var rect: Vector2 = _camera.get_viewport().get_visible_rect().size
	print("     [%d] on screen through the air: x [%.0f, %.0f]  y [%.0f, %.0f] of %s   (min x at %s)"
		% [index, float(t.get("screen_min_x", 0.0)), float(t.get("screen_max_x", 0.0)),
			float(t.get("screen_min_y", 0.0)), float(t.get("screen_max_y", 0.0)), str(rect), str(t.get("screen_min_x_at", "?"))])
	if rect == Vector2(1080.0, 1920.0) and bool(t["settled"]):
		_check(float(t.get("screen_min_y", -1.0)) > 80.0 and float(t.get("screen_max_y", 1e9)) < rect.y - 80.0
				and float(t.get("screen_min_x", -1.0)) > 0.0 and float(t.get("screen_max_x", 1e9)) < rect.x,
			"W[%d] the board never leaves the frame in the air (80 px margin top and bottom)" % index)
	elif not bool(t["settled"]):
		print("     [%d] (frame gate NOT signed at this station: the camera could not settle behind a board parked at the rim -- PHASE R signs the real launch)" % index)
	else:
		print("     [%d] (frame gate NOT signed: canvas %s is the headless one, not 1080 x 1920 -- run under xvfb)" % [index, str(rect)])
	return t

# =====================================================================
# PHASE R -- THE REAL FIRST LAUNCH: mounted where the game parks the
# board, turned round, ridden straight into the small quarterpipe. The
# axis-aligned station above measures the WINDOW; this one measures what
# the first player does, camera and all (CLAUDE.md: the access path).

func _phase_first_launch() -> void:
	print("-- PHASE R: the real first launch -- from SKATE_PARK, pivot south, into the 1.45 --")
	var body := _transport.board_body()
	var dir: Vector3 = _ramp_dir(3)
	# parked as the game parks it: at SKATE_PARK, facing north (yaw 0)
	await _park_board(HubTransport.SKATE_PARK, Vector3(0.0, 0.0, 1.0))
	var mounted: bool = _transport.mount_board()
	await _settle_chase()
	_took_off = 0
	_landed = 0
	_bench.hold(dir)
	var pivot_ticks: int = -1
	var first_free: int = -1
	var armed_best: int = 0
	var armed_run: int = 0
	var landed_at: int = -1
	var peak: float = 0.0
	var smin_x: float = 1e9
	var smax_x: float = -1e9
	var smin_y: float = 1e9
	var smax_y: float = -1e9
	var cam_off_deg: float = 0.0
	var pops0: int = body.pops()
	for tick in 420:
		await get_tree().physics_frame
		if pivot_ticks < 0 and absf(angle_difference(body.rotation.y, atan2(dir.x, dir.z))) < deg_to_rad(5.0):
			pivot_ticks = tick
		peak = maxf(peak, body.global_position.y)
		armed_run = armed_run + 1 if body.in_air() else 0
		armed_best = maxi(armed_best, armed_run)
		if body.airborne() and landed_at < 0:
			if first_free < 0:
				first_free = tick
				var forward: Vector3 = -_camera.global_transform.basis.z
				forward.y = 0.0
				var facing := Vector3(sin(body.rotation.y), 0.0, cos(body.rotation.y))
				cam_off_deg = rad_to_deg(acos(clampf(forward.normalized().dot(facing), -1.0, 1.0)))
			var scr: Vector2 = _camera.unproject_position(body.global_position + Vector3(0.0, SkateparkMesh.DECK_TOP, 0.0))
			smin_x = minf(smin_x, scr.x)
			smax_x = maxf(smax_x, scr.x)
			smin_y = minf(smin_y, scr.y)
			smax_y = maxf(smax_y, scr.y)
		if first_free >= 0 and landed_at < 0 and tick > first_free + 3 and not body.airborne():
			landed_at = tick
		if landed_at >= 0 and tick > landed_at + 30:
			break
	_bench.release()
	var rect: Vector2 = _camera.get_viewport().get_visible_rect().size
	print("     from SKATE_PARK %s: mounted %s, pointed south at tick %d, first free tick %d (%.2f s after the pivot), camera %.1f deg off the board's facing at take-off, armed %d ticks, peak y %.3f, pops %d, landed tick %d"
		% [str(HubTransport.SKATE_PARK), str(mounted), pivot_ticks, first_free, float(first_free - pivot_ticks) / 60.0, cam_off_deg, armed_best, peak, body.pops() - pops0, landed_at])
	print("     on screen through that air: x [%.0f, %.0f]  y [%.0f, %.0f] of %s" % [smin_x, smax_x, smin_y, smax_y, str(rect)])
	_check(mounted and pivot_ticks >= 0 and first_free > pivot_ticks and body.pops() - pops0 == 1,
		"R the first ride from the parking spot reaches the 1.45's lip and pops (%d)" % (body.pops() - pops0))
	_check(armed_best >= 40, "R and that air is at least 40 armed ticks (%d)" % armed_best)
	if rect == Vector2(1080.0, 1920.0):
		_check(smin_x > 0.0 and smax_x < rect.x and smin_y > 80.0 and smax_y < rect.y - 80.0,
			"R the board stays in the frame through the first launch (camera %.1f deg behind at take-off)" % cam_off_deg)
	else:
		print("     (frame not signed on the headless canvas)")
	for _i in 30:
		await get_tree().physics_frame

# =====================================================================
# PHASE O -- CH65's grip and nose-push: does an off-axis approach change
# the launch? Printed beside the straight one; the straight one is the
# reference the verdict uses.

func _phase_off_axis(launches: Dictionary) -> void:
	print("-- PHASE O: the same run 20 deg off the ramp's axis (CH65 grip + nose-push interaction) --")
	for index in [2, 3]:
		var t: Dictionary = await _launch(index, 20.0, "[%d] %s 20 deg off-axis" % [index, String(_park.module_kind(index))])
		var s: Dictionary = launches[index]
		print("     [%d] straight: armed %d ticks, peak %.3f   off-axis: armed %d ticks, peak %.3f"
			% [index, int(s["armed"]), float(s["peak_y"]), int(t["armed"]), float(t["peak_y"])])

# =====================================================================
# PHASE E -- END TO END: the launch, the reference thumb, the trick

## Rides the ramp with the probe's OWN finger (a press, then a held offset
## toward the ramp axis under the live camera), waits `react_s` after the
## first free tick, then draws a circle of radius `r` at `speed` px/s --
## one drag per physics tick, `speed / 60` px each -- from wherever the
## finger is, until the trick fires or `patience` ticks pass. Returns the
## tick the trick fired at, relative to the first free tick (-1 if never),
## and whether it fired in the air or in the grace.
func _ride_and_circle(index: int, r: float, speed: float, react_s: float, clockwise: bool, label: String) -> Dictionary:
	var body := _transport.board_body()
	var dir: Vector3 = _ramp_dir(index)
	var centre: Vector3 = _park.module_centre(index)
	var from: Vector3 = centre - dir * float(RUN_UP[index])
	await _park_board(from, dir)
	var mounted: bool = _transport.mount_board()
	await _settle_chase()
	_tricks.clear()
	var finger: Vector2 = FINGER
	_touch._unhandled_input(_press(finger))
	var first_free: int = -1
	var fired_at: int = -1
	var fired_where: String = "never"
	var circle_from: int = -1
	var step_px: float = speed / 60.0
	var arc: float = 0.0
	var c_centre: Vector2 = Vector2.ZERO
	var landed_at: int = -1
	var win_ticks: int = 0
	var win_best: int = 0
	for tick in 600:
		# before the circle: hold the offset toward the ramp
		if circle_from < 0:
			finger = _touch.anchor + SkateTouchInput.screen_offset_for(_camera, dir, SkateBench.HOLD_PX)
			_touch._unhandled_input(_drag(finger))
		else:
			arc += step_px / r
			finger = c_centre + Vector2(-cos(arc), -sin(arc) * (1.0 if clockwise else -1.0)) * r
			_touch._unhandled_input(_drag(finger))
		await get_tree().physics_frame
		win_ticks = win_ticks + 1 if _touch.path_live() else 0
		win_best = maxi(win_best, win_ticks)
		if first_free < 0 and body.airborne():
			first_free = tick
		if first_free >= 0 and circle_from < 0 and tick - first_free >= int(round(react_s * 60.0)):
			circle_from = tick
			c_centre = finger + Vector2(r, 0.0)
			arc = 0.0
		if first_free >= 0 and landed_at < 0 and tick > first_free + 3 and not body.airborne():
			landed_at = tick
		if fired_at < 0 and not _tricks.is_empty():
			fired_at = tick
			fired_where = "in the air" if body.airborne() else ("in the grace (%d ticks after landing)" % (tick - landed_at))
			break
		if landed_at >= 0 and tick > landed_at + 40:
			break
		if tick > 500:
			break
	_touch._unhandled_input(_release(finger))
	for _i in 20:
		await get_tree().physics_frame
	print("     %-44s mounted %s  first free tick %d  circle from tick %d  landed tick %d  window %d ticks  fired %s (tick %d, %d after the first free tick; tricks %s)"
		% [label, str(mounted), first_free, circle_from, landed_at, win_best, fired_where, fired_at,
			(fired_at - first_free) if fired_at >= 0 else -1, str(_tricks)])
	return {"fired": fired_at >= 0, "where": fired_where, "tricks": _tricks.duplicate(), "window": win_best,
		"first_free": first_free, "landed_at": landed_at}

func _phase_end_to_end() -> void:
	print("-- PHASE E: END TO END -- the real ramp, the real writer, the reference thumb --")
	var hud := _hub.find_child("SkateHud", true, false) as SkateHud
	for index in [2, 3]:
		var kind: String = String(_park.module_kind(index))
		if hud != null:
			hud.visible = false
		var r: Dictionary = await _ride_and_circle(index, REF_RADIUS_PX, REF_SPEED_PX_S, REF_REACTION_S, true,
			"[%d] %s, r %.0f @ %.0f px/s after %.2f s" % [index, kind, REF_RADIUS_PX, REF_SPEED_PX_S, REF_REACTION_S])
		_check(bool(r["fired"]) and (r["tricks"] as Array).size() == 1 and (r["tricks"] as Array)[0] == true,
			"E[%d] the reference thumb's clockwise circle fires exactly one KICKFLIP on the %s (%s)" % [index, kind, str(r["where"])])
		if hud != null:
			_check(hud.visible and hud.trick_text() == String(HubTransport.TRICK_CLOCKWISE).to_upper(),
				"E[%d] and the HUD printed it ('%s')" % [index, hud.trick_text()])
		var r2: Dictionary = await _ride_and_circle(index, REF_RADIUS_PX, REF_SPEED_PX_S, REF_REACTION_S, false,
			"[%d] %s, the same anticlockwise" % [index, kind])
		_check(bool(r2["fired"]) and (r2["tricks"] as Array).size() == 1 and (r2["tricks"] as Array)[0] == false,
			"E[%d] anticlockwise fires exactly one HEELFLIP (%s)" % [index, str(r2["where"])])
	# The NEGATIVE, so the gate above is one that can fail: a big, slow
	# circle (80 px at 250 px/s: 432 px, 1.7 s) does not fit any window
	# this park has, and must not fire.
	var slow: Dictionary = await _ride_and_circle(2, 80.0, 250.0, REF_REACTION_S, true,
		"[2] NEGATIVE: r 80 @ 250 px/s")
	_check(not bool(slow["fired"]),
		"E NEGATIVE: a circle slower than the window does NOT fire (window %d ticks)" % int(slow["window"]))
	await _park_board(NEUTRAL, Vector3(0.0, 0.0, -1.0))

# =====================================================================
# PHASE G -- THE LANDING GRACE, ON A SYNTHETIC POP (exact control of what
# is drawn before contact), and the flip that follows it

## Pops the board on the lawn, draws `deg` of a 40 px circle in the air
## (one point a tick at the reference speed), and lets it land with the
## finger still down at the last point of that arc.
func _pop_and_draw(deg: float) -> Dictionary:
	var body := _transport.board_body()
	await _park_board(NEUTRAL, Vector3(0.0, 0.0, -1.0))
	_transport.mount_board()
	await _settle_chase()
	_tricks.clear()
	_touch._unhandled_input(_press(FINGER))
	_touch._unhandled_input(_drag(FINGER + Vector2(0.0, -140.0)))
	for _i in 10:
		await get_tree().physics_frame
	body.velocity.y = 6.0
	var armed: bool = false
	for _i in 20:
		await get_tree().physics_frame
		if body.in_air():
			armed = true
			break
	var finger: Vector2 = _touch.finger
	var c_centre: Vector2 = finger + Vector2(REF_RADIUS_PX, 0.0)
	var arc: float = 0.0
	var step: float = REF_SPEED_PX_S / 60.0 / REF_RADIUS_PX
	while rad_to_deg(arc) < deg and body.in_air():
		arc += step
		finger = c_centre + Vector2(-cos(arc), -sin(arc)) * REF_RADIUS_PX
		_touch._unhandled_input(_drag(finger))
		await get_tree().physics_frame
	var sweep_before: float = _touch.sweep_deg()
	var facing: float = body.rotation.y
	var landed_at: int = -1
	for t in 120:
		await get_tree().physics_frame
		if not body.in_air():
			landed_at = t
			break
	return {"armed": armed, "sweep": sweep_before, "facing": facing, "landed": landed_at >= 0,
		"finger": finger, "centre": c_centre, "arc": arc}

func _phase_grace() -> void:
	print("-- PHASE G: the landing grace -- a circle under way at contact gets %d ticks, a straight finger does not --" % SkateTouchInput.GRACE_TICKS)
	var body := _transport.board_body()
	var visual := body.find_child("SkateboardMesh", true, false) as Node3D
	# (a) 200 deg drawn in the air: grace runs, heading frozen, the circle
	# closes on the ground, the trick fires, the deck turns visibly.
	var r: Dictionary = await _pop_and_draw(200.0)
	_check(bool(r["armed"]) and bool(r["landed"]), "G INSTRUMENT: popped, armed, landed")
	print("     at contact: sweep %.1f deg, grace %d ticks, heading frozen %s, tricks so far %d"
		% [float(r["sweep"]), _touch.grace_ticks(), str(_touch.heading_frozen()), _tricks.size()])
	_check(_touch.grace_ticks() == SkateTouchInput.GRACE_TICKS and _touch.heading_frozen(),
		"G(a) a landing with %.0f deg drawn opens the grace (%d ticks) and keeps the heading frozen" % [float(r["sweep"]), _touch.grace_ticks()])
	_check(_tricks.is_empty(), "G(a) INSTRUMENT: nothing has fired yet (%d)" % _tricks.size())
	# keep drawing at the reference speed
	var finger: Vector2 = r["finger"]
	var arc: float = float(r["arc"])
	var step: float = REF_SPEED_PX_S / 60.0 / REF_RADIUS_PX
	var fired_tick: int = -1
	var facing0: float = float(r["facing"])
	var turned: float = 0.0
	var z0: float = visual.rotation.z if visual != null else 0.0
	for t in 40:
		arc += step
		finger = (r["centre"] as Vector2) + Vector2(-cos(arc), -sin(arc)) * REF_RADIUS_PX
		_touch._unhandled_input(_drag(finger))
		await get_tree().physics_frame
		turned = maxf(turned, absf(angle_difference(facing0, body.rotation.y)))
		if fired_tick < 0 and not _tricks.is_empty():
			fired_tick = t
			break
	print("     drawing on: fired at grace tick %d, board turned %.4f rad meanwhile, grace left %d, frozen %s, anchor %s finger %s"
		% [fired_tick, turned, _touch.grace_ticks(), str(_touch.heading_frozen()), str(_touch.anchor.round()), str(_touch.finger.round())])
	_check(fired_tick >= 0 and _tricks.size() == 1 and _tricks[0] == true,
		"G(a) the circle closed on the ground within the grace and fired ONE kickflip (tick %d)" % fired_tick)
	_check(turned < 0.0001, "G(a) the board did not turn while the grace ran (%.4f rad)" % turned)
	_check(_touch.grace_ticks() == 0 and not _touch.heading_frozen() and _touch.anchor.is_equal_approx(_touch.finger),
		"G(a) the trick ended the grace: anchor under the finger, heading free again")
	# the flip: started on the ground, it runs at the AIR rate (visible)
	var ticks_to_done: int = -1
	var most: float = 0.0
	for t in 60:
		await get_tree().physics_frame
		if visual != null:
			most = minf(most, visual.rotation.z - z0)
		if ticks_to_done < 0 and not body.flipping():
			ticks_to_done = t + 1
	var slow_ticks: int = int(ceil(60.0 * TAU / SkateBoardBody.FLIP_RATE))
	print("     the flip from the grace: %.3f rad in %d ticks (air rate %d, landing rate %d)"
		% [most, ticks_to_done, slow_ticks, int(ceil(float(slow_ticks) / SkateBoardBody.FLIP_LAND_GAIN))])
	_check(absf(most + TAU) < 0.01 and ticks_to_done >= slow_ticks - 2,
		"G(a) a flip fired on the ground turns a full turn at the AIR rate, not snapped (%d ticks)" % ticks_to_done)
	_touch._unhandled_input(_release(finger))
	for _i in 10:
		await get_tree().physics_frame
	# (b) 60 deg drawn: under the threshold, the landing cuts on the spot.
	r = await _pop_and_draw(60.0)
	print("     at contact: sweep %.1f deg, grace %d, frozen %s, anchor %s finger %s"
		% [float(r["sweep"]), _touch.grace_ticks(), str(_touch.heading_frozen()), str(_touch.anchor.round()), str(_touch.finger.round())])
	_check(bool(r["landed"]) and _touch.grace_ticks() == 0 and not _touch.heading_frozen()
			and _touch.anchor.is_equal_approx(_touch.finger),
		"G(b) a landing with only %.0f deg drawn is cut on contact: no grace, anchor under the finger" % float(r["sweep"]))
	_touch._unhandled_input(_release(_touch.finger))
	for _i in 10:
		await get_tree().physics_frame
	# (c) 200 deg drawn, then the finger STOPS: the grace expires, the
	# anchor moves under the finger, no trick.
	r = await _pop_and_draw(200.0)
	var g0: int = _touch.grace_ticks()
	var facing1: float = body.rotation.y
	for _i in SkateTouchInput.GRACE_TICKS + 2:
		await get_tree().physics_frame
	print("     finger stopped at contact: grace was %d, now %d, tricks %d, frozen %s, anchor==finger %s, turned %.4f"
		% [g0, _touch.grace_ticks(), _tricks.size(), str(_touch.heading_frozen()), str(_touch.anchor.is_equal_approx(_touch.finger)), absf(angle_difference(facing1, body.rotation.y))])
	_check(g0 == SkateTouchInput.GRACE_TICKS and _touch.grace_ticks() == 0 and _tricks.is_empty()
			and not _touch.heading_frozen() and _touch.anchor.is_equal_approx(_touch.finger),
		"G(c) a grace that closes nothing expires: no trick, anchor under the finger, heading free")
	_touch._unhandled_input(_release(_touch.finger))
	for _i in 10:
		await get_tree().physics_frame
	await _park_board(NEUTRAL, Vector3(0.0, 0.0, -1.0))

# =====================================================================
# THE VERDICT

func _phase_verdict(gesture: Dictionary, launches: Dictionary) -> void:
	print("-- VERDICT: the armed window against the reference thumb --")
	var need: float = float(gesture["need_s"])
	for index in [2, 3]:
		var t: Dictionary = launches[index]
		var have: float = float(t["window_best"]) / 60.0
		var armed: float = float(t["armed_best"]) / 60.0
		var verdict: String = "REACHABLE" if have >= need else "UNREACHABLE"
		print("     [%d] %-12s window %.3f s (longest armed air %.3f s)   reference thumb needs %.3f s   -> %s (margin %+.3f s)"
			% [index, String(_park.module_kind(index)), have, armed, need, verdict, have - need])
		# The fastest thumb that fits, once the reaction is spent.
		var usable: float = maxf(have - REF_REACTION_S, 0.001)
		var r40: float = float(gesture[40.0])
		print("     [%d] after %.2f s of reaction, a 40 px circle needs %.0f px/s to fit; an 80 px one %.0f px/s"
			% [index, REF_REACTION_S, r40 / usable, float(gesture[80.0]) / usable])
		_check(have >= need,
			"V[%d] the window on the %s holds the reference thumb (%.3f >= %.3f s)"
				% [index, String(_park.module_kind(index)), have, need])

# =====================================================================
# EVENTS

func _press(at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = true
	e.position = at
	return e

func _release(at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = false
	e.position = at
	return e

func _drag(at: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = at
	return e
