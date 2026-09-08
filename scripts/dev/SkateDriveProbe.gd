extends Node
## CH54 -- THE SKATEBOARD'S RIDE, measured through the REAL tap channel.
##
## =====================================================================
## WHY THIS RUNS UNDER xvfb + opengl3 AND NEVER --headless
##
## The question this probe exists to answer ("does he MOVE on the board,
## and how") is a question about transforms, and CLAUDE.md would send a
## transforms-only probe to --headless. It runs under xvfb anyway, and not
## as a shortcut: every tap below goes through HubTapInput._handle_point,
## i.e. a SCREEN point unprojected on the delivered camera. In headless
## the container rect is 0x0, _handle_point returns before projecting
## anything, and every "he moved" check passes by never running -- the
## third of the four things CLAUDE.md lists the dummy driver breaking.
## PHASE I asserts the rect is real before anything is measured.
##
## =====================================================================
## THE DIAGNOSIS (PHASE D) -- H1 or H2, by measurement
##
## Mathieu, on device: "Keepy est sur le skate mais il ne le conduit pas".
## Two hypotheses, two very different fixes:
##   H1 -- he does not move at all on the board (a wiring defect);
##   H2 -- he moves, but with nothing that reads as riding (game feel).
## PHASE D mounts the board THROUGH THE TAP CHANNEL (tap the board, walk,
## climb on -- the shipped path, not a direct mount_vehicle call), taps
## the ground 12 u south through the same channel, and records the body's
## position every frame. The same tap is then made ON FOOT from the same
## station. The two traces are printed side by side; the verdict is a
## displacement, not a reading of code.
##
## Measured on the CH53 board (run 1, before any change): 16.0 u at a
## constant 7.94 u/s from frame 1 to a dead stop, six arcs 1.30 u high.
## H2. The phases below gate what CH54 did about it.
##
## =====================================================================
## THE PROFILE (PHASE P), THE TURN (PHASE T), THE PROXY (PHASE S)
##
## P reads the SAME trace D recorded and gates the ride against the
## numbers HubTransport publishes: it starts slow, reaches cruise, cruises
## at SKATE_CRUISE, eases out, never arcs, and its speed is continuous at
## every segment boundary (a step there is a stutter at 60 fps).
## T gates the push-off: a re-tap straight ahead keeps the pace, a re-tap
## behind costs the run-up.
## S gates the landing proxy under a roll that lands every 1.6 u: a
## landing IN PASSING through a module's disc scores nothing and breaks
## nothing; the landing that ENDS a roll on a module scores; and a chain
## survives the grass segments between two modules. Blind check first:
## the pass-through roll must actually have landed inside a disc, or
## "it did not score" is passing for free.

const BUDGET_S: float = 600.0
const VP_SIZE: Vector2i = Vector2i(1080, 1920)
const SETTLE: int = 3
const FPS: float = 60.0
## Where the rider stands to tap the board: 4 u south of SKATE_PARK, so
## the board is in frame (z below the camera's own) and inside the walk.
const STATION: Vector3 = Vector3(3.0, 0.0, 56.0)
## The ride's target: 12 u south along the park's axis, on open lobe.
const RIDE_TO: Vector3 = Vector3(3.0, 0.0, 44.0)
const TRACE_FRAMES: int = 420

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _camera: Camera3D = null
var _sub: SubViewport = null
var _tap: HubTapInput = null
var _transport: HubTransport = null
var _park: HubSkatepark = null
var _saw: Array[StringName] = []
var _landings: int = 0
var _landing_points: Array = []
var _board_summary: Dictionary = {}
var _scores: Array = []
var _broken: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE DRIVE PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_drive_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as KeepyHopper
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport
	_tap = _hub.get_node("TapInput") as HubTapInput
	_transport = _hub.get_node("WorldViewport/SubViewport/World/Transport") as HubTransport
	_park = _hub.get_node("WorldViewport/SubViewport/World/Skatepark") as HubSkatepark

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	_sub.size = VP_SIZE
	_run()

func _run() -> void:
	print("=== SKATE DRIVE PROBE -- CH54 ===")
	if _keepy == null or _tap == null or _transport == null or _park == null:
		push_error("SkateDriveProbe: hub scene is missing Keepy / TapInput / Transport / Skatepark.")
		get_tree().quit(1)
		return
	_keepy.hop_landed.connect(func(p: Vector3) -> void:
		_landings += 1
		_landing_points.append(p))
	_park.trick_scored.connect(func(module: int, trick: StringName, points: int, chain: int) -> void:
		_scores.append({"module": module, "trick": trick, "points": points, "chain": chain}))
	_park.chain_broken.connect(func() -> void: _broken += 1)
	await _phase_instrument()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every number below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_diagnosis()
	await _phase_profile()
	await _phase_turn()
	await _phase_scoring()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# HELPERS

func _station(flat: Vector3) -> void:
	_keepy.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	if _camera.has_method("snap_to_target"):
		_camera.call("snap_to_target")
	for _i in SETTLE:
		await get_tree().process_frame

## World point -> screen point in the container's space, inverting what
## _handle_point does on the way in (CabinProbe's helper, verbatim).
func _to_screen(world: Vector3) -> Vector2:
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	var local: Vector2 = _camera.unproject_position(world)
	local.x *= rect.size.x / float(_sub.size.x)
	local.y *= rect.size.y / float(_sub.size.y)
	return local + rect.position

func _tap_world(world: Vector3) -> void:
	_tap._handle_point(_to_screen(world))

func _settle(cap: int = 900) -> int:
	var frames: int = 0
	await get_tree().process_frame
	frames += 1
	while _keepy.is_hopping() and frames < cap:
		await get_tree().process_frame
		frames += 1
	return frames

func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

## Taps `to` through the real channel and records the body every frame
## until it comes to rest (or the cap). Returns the trace as an Array of
## [frame, x, y, z].
func _ride_trace(to: Vector3) -> Array:
	var trace: Array = []
	_landings = 0
	_landing_points.clear()
	var p0 := _keepy.global_position
	trace.append([0, p0.x, p0.y, p0.z])
	_tap_world(to)
	var rest: int = 0
	for f in range(1, TRACE_FRAMES + 1):
		await get_tree().process_frame
		var p := _keepy.global_position
		trace.append([f, p.x, p.y, p.z])
		# At rest: not hopping for 6 consecutive frames after having moved.
		if not _keepy.is_hopping() and f > 6:
			rest += 1
			if rest >= 6:
				break
		else:
			rest = 0
	return trace

## Summarises a trace: displacement, first moving frame, time to rest,
## peak XZ speed, peak height above the ground line, and the speed
## profile at every 6th frame.
func _summarise(label: String, trace: Array) -> Dictionary:
	var first := Vector3(trace[0][1], trace[0][2], trace[0][3])
	var last := Vector3(trace[-1][1], trace[-1][2], trace[-1][3])
	var moved: float = _flat(first).distance_to(_flat(last))
	var first_move: int = -1
	var peak_v: float = 0.0
	var peak_h: float = -1e9
	var last_move: int = 0
	var speeds: Array = []
	for i in range(1, trace.size()):
		var a := Vector3(trace[i - 1][1], trace[i - 1][2], trace[i - 1][3])
		var b := Vector3(trace[i][1], trace[i][2], trace[i][3])
		var v: float = _flat(a).distance_to(_flat(b)) * FPS
		speeds.append(v)
		if v > 0.05:
			if first_move < 0:
				first_move = int(trace[i][0])
			last_move = int(trace[i][0])
		peak_v = maxf(peak_v, v)
		peak_h = maxf(peak_h, b.y - HubSurface.height_at(b))
	print("     %s" % label)
	print("       displacement %.3f u   first moving frame %d   last moving frame %d (%.3f s)   landings %d"
		% [moved, first_move, last_move, float(last_move) / FPS, _landings])
	print("       peak XZ speed %.3f u/s   peak height above ground %.3f u   frames traced %d"
		% [peak_v, peak_h, trace.size() - 1])
	var line: String = "       speed profile (u/s, every 6th frame):"
	for i in range(0, speeds.size(), 6):
		line += " %.1f" % speeds[i]
	print(line)
	return {"moved": moved, "first_move": first_move, "last_move": last_move,
		"peak_v": peak_v, "peak_h": peak_h, "speeds": speeds}

# =====================================================================
# PHASE I -- THE INSTRUMENT SEES.

func _phase_instrument() -> void:
	print("-- PHASE I: the instrument sees what it measures --")
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0,
		"I1 the container has a real rect %s (xvfb, not --headless)" % rect)
	if rect.size.x <= 0.0:
		return
	await _station(STATION)
	var board: Vector3 = _transport.board_position()
	var sp := _to_screen(board)
	_check(rect.has_point(sp), "I2 the board at %s projects INSIDE the container (%s)" % [board, sp])
	# The tap channel: a tap on the board must become tapped_vehicle, a
	# tap on open ground must become tapped_ground. Spied with the hub's
	# own handlers still connected, so the walk really starts.
	_tap.tapped_vehicle.connect(func(_p: Vector3) -> void: _saw.append(&"vehicle"))
	_tap.tapped_ground.connect(func(_p: Vector3) -> void: _saw.append(&"ground"))
	_saw.clear()
	_tap_world(RIDE_TO)
	_check(_saw == [&"ground"], "I3 a tap on open lobe ground is tapped_ground (%s)" % str(_saw))
	await _settle()
	await _station(STATION)
	print("")

# =====================================================================
# PHASE D -- H1 OR H2.

func _phase_diagnosis() -> void:
	print("-- PHASE D: H1 (does not move) or H2 (moves, no ride) -- by trace --")
	_keepy.dismount_vehicle()
	await _station(STATION)
	# 1. Tap the board through the channel; the hub walks him there and
	#    mounts on the landing (HubWorld._try_mount_ball, the shipped path).
	_saw.clear()
	_tap_world(_transport.board_position())
	_check(_saw == [&"vehicle"], "D1 a tap on the parked board is tapped_vehicle (%s)" % str(_saw))
	var walk_frames: int = await _settle()
	# One more frame: the mount happens on the landing, before _advance.
	await get_tree().process_frame
	_check(_keepy.is_on_vehicle() and _keepy.vehicle_node() == _transport.board_node(),
		"D2 after the walk (%d frames) he is ON THE BOARD, through the tap channel" % walk_frames)
	var here := _keepy.global_position
	print("     standing at (%.2f, %.2f, %.2f), board at %s, lift %.2f"
		% [here.x, here.y, here.z, _transport.board_position(), HubTransport.SKATE_LIFT])
	_check(_flat(here).distance_to(_flat(_transport.board_position())) <= HubTransport.SKATE_TAP_RADIUS,
		"D3 and he stands within the board's tap radius")

	# 2. Tap 12 u south, on the board. Record.
	_saw.clear()
	var on_board: Array = await _ride_trace(RIDE_TO)
	_check(_saw == [&"ground"], "D4 the ride tap is tapped_ground while mounted (%s)" % str(_saw))
	var b := _summarise("ON THE BOARD, tap %s:" % RIDE_TO, on_board)
	_board_summary = b
	_check(_keepy.is_on_vehicle(), "D5 he is still on the board after the ride")

	# 3. The same tap ON FOOT, from the same station.
	_keepy.dismount_vehicle()
	await _station(STATION)
	# Park the board away so the on-foot tap cannot mean it.
	var foot: Array = await _ride_trace(RIDE_TO)
	var w := _summarise("ON FOOT, same tap:", foot)

	# 4. The verdict.
	var expected: float = _flat(STATION).distance_to(_flat(RIDE_TO))
	print("")
	if b["moved"] < 0.5:
		print("     VERDICT: H1 -- on the board he did NOT move (%.3f u of %.1f asked)." % [b["moved"], expected])
	else:
		print("     VERDICT: H2 -- on the board he MOVES (%.3f u of %.1f asked): peak %.2f u/s vs %.2f on foot, peak height %.2f u vs %.2f."
			% [b["moved"], expected, b["peak_v"], w["peak_v"], b["peak_h"], w["peak_h"]])
	_check(b["moved"] > 0.5 or true, "D6 (recorded, not gated) board displacement %.3f u" % b["moved"])
	_check(w["moved"] > expected - 1.0, "D7 CONTROL: on foot he covers the distance (%.3f of %.1f u)" % [w["moved"], expected])
	print("")

# =====================================================================
# HELPERS FOR P / T / S

## Dismounts, stands him at `flat`, snaps the camera, and mounts the board
## with the numbers HubTransport publishes -- the mount HubWorld makes,
## through the same constants, not a copy of them.
func _station_on_board(flat: Vector3) -> void:
	_keepy.dismount_vehicle()
	await _station(flat)
	var ok: bool = _keepy.mount_vehicle(_transport.board_node(), HubTransport.SKATE_LIFT,
		HubTransport.SKATE_GLIDE_STEP, HubTransport.SKATE_GLIDE_S,
		HubTransport.SKATE_ACCEL_U, HubTransport.SKATE_BRAKE_U)
	if not ok:
		push_error("SkateDriveProbe: mount_vehicle refused at %s" % flat)
	for _i in SETTLE:
		await get_tree().process_frame

## Speed averaged over a window of `w` frames starting at index i.
func _window_speed(speeds: Array, i: int, w: int) -> float:
	var sum: float = 0.0
	var n: int = 0
	for k in range(i, mini(i + w, speeds.size())):
		sum += float(speeds[k])
		n += 1
	return sum / float(maxi(n, 1))

# =====================================================================
# PHASE P -- THE PROFILE, gated on D's board trace.

func _phase_profile() -> void:
	print("-- PHASE P: the ride is a PROFILE -- run-up, cruise, run-out, flat, continuous --")
	var cruise: float = HubTransport.SKATE_CRUISE
	var speeds: Array = _board_summary["speeds"]
	var peak: float = float(_board_summary["peak_v"])
	print("     published: cruise %.2f u/s, segment %.2f u (%.4f s), run-up %.1f u, run-out %.1f u, floor %.2f"
		% [cruise, HubTransport.SKATE_GLIDE_STEP, HubTransport.SKATE_GLIDE_S,
			HubTransport.SKATE_ACCEL_U, HubTransport.SKATE_BRAKE_U, KeepyHopper.GLIDE_PACE_FLOOR])
	_check(absf(peak - cruise) < 0.05,
		"P1 the peak speed IS the published cruise (%.3f vs %.2f u/s)" % [peak, cruise])
	# Run-up: the first frames roll at the floor, not at cruise.
	var first: float = _window_speed(speeds, 0, 3)
	_check(first < 0.5 * cruise and first > 0.1 * cruise,
		"P2 it LEAVES SLOW: first 3 frames average %.2f u/s (want between 10 %% and 50 %% of cruise)" % first)
	# ... and reaches cruise within the run-up plus one segment: from rest
	# the first two segments take ~0.59 s (see HubTransport), so 48
	# frames is generous and 90 would be a ride that never gets going.
	var reached: int = -1
	for i in speeds.size():
		if float(speeds[i]) >= 0.95 * cruise:
			reached = i + 1
			break
	_check(reached > 12 and reached <= 48,
		"P3 it reaches 95 %% of cruise at frame %d (want after 12, by 48)" % reached)
	# Run-out: the last moving frames are slow again.
	var last_move: int = int(_board_summary["last_move"])
	var tail: float = _window_speed(speeds, last_move - 3, 3)
	_check(tail < 0.5 * cruise and tail > 0.1 * cruise,
		"P4 it EASES OUT: last 3 moving frames average %.2f u/s (want between 10 %% and 50 %% of cruise)" % tail)
	# Flat: no arc. Peak height above the ground line is the deck only.
	var peak_h: float = float(_board_summary["peak_h"])
	_check(absf(peak_h - HubTransport.SKATE_LIFT) < 0.01,
		"P5 it ROLLS, it does not bounce: peak height %.3f u == deck %.3f u" % [peak_h, HubTransport.SKATE_LIFT])
	# Continuous, FRAME TO FRAME. The first version of this gate compared
	# 3-frame windows and its own red pass proved it blind: a 3.3 u/s
	# step at a segment boundary reads as 1.1 per window shift and passed
	# under a 2.5 cap. Per frame, the shipped ramps climb by at most
	# ~0.3 u/s a frame (3.5 -> 6.75 over 19 frames, 6.75 -> 10 over 12); a
	# pace STEP between segments (no _glide_progress) is 3.3 in one frame
	# and a short tween-end frame (no carry) is 4.0. The cap is a tenth
	# of cruise. The very first frame (rest -> floor) and the stop frame
	# are the profile's ends, not its continuity, and are left out.
	var worst_jump: float = 0.0
	var worst_at: int = -1
	for i in range(1, last_move - 1):
		var jump: float = absf(float(speeds[i]) - float(speeds[i - 1]))
		if jump > worst_jump:
			worst_jump = jump
			worst_at = i + 1
	_check(worst_jump < 0.1 * cruise,
		"P6 the speed is CONTINUOUS: worst frame-to-frame jump %.2f u/s at frame %d (cap %.2f)"
			% [worst_jump, worst_at, 0.1 * cruise])
	# Continuous at the FRAME, on the cruise plateau: a frame whose two
	# NEIGHBOURS are at cruise must itself be at cruise. The first version
	# defined the plateau by a window that CONTAINED the frame under test,
	# so a 6.0 among 10.0s pulled its own window under the bar and was
	# never tested -- its red pass (carry removed) came back green. A
	# tween that ends mid-frame snaps to its end and leaves exactly one
	# such frame per segment; that is what the carry exists to remove.
	var plateau: int = 0
	var short_frames: int = 0
	var worst_frame: float = cruise
	for i in range(1, speeds.size() - 1):
		if float(speeds[i - 1]) >= 0.95 * cruise and float(speeds[i + 1]) >= 0.95 * cruise:
			plateau += 1
			if float(speeds[i]) < 0.95 * cruise:
				short_frames += 1
			worst_frame = minf(worst_frame, float(speeds[i]))
	_check(plateau >= 20 and short_frames == 0,
		"P7 on the cruise plateau (%d frames) NO frame falls short (%d short, worst %.2f u/s)"
			% [plateau, short_frames, worst_frame])
	# And it is a different ride from the walk, said in seconds.
	var seconds: float = float(last_move) / FPS
	print("     16 u from the park to %s: %.3f s on the board (CH53 bounce measured 2.100 s; walk 2.467 s for 12 u)"
		% [RIDE_TO, seconds])
	print("")

# =====================================================================
# PHASE T -- THE PUSH-OFF: straight ahead keeps the pace, a reversal costs it.

func _phase_turn() -> void:
	print("-- PHASE T: a re-tap ahead keeps the pace; a re-tap behind costs the run-up --")
	# Control: roll south, and at cruise re-tap further SOUTH.
	await _station_on_board(Vector3(3.0, 0.0, 60.0))
	_tap_world(Vector3(3.0, 0.0, 48.0))
	for _i in 40:
		await get_tree().process_frame
	var pace_at_cruise: float = _keepy.glide_pace()
	_check(absf(pace_at_cruise - 1.0) < 0.001, "T0 at frame 40 the segment pace is cruise (%.3f)" % pace_at_cruise)
	_tap_world(Vector3(3.0, 0.0, 42.0))
	var n0: int = _landings
	var guard: int = 0
	while _landings < n0 + 1 and guard < 120:
		await get_tree().process_frame
		guard += 1
	await get_tree().process_frame
	var ahead: float = _keepy.glide_pace()
	_check(absf(ahead - 1.0) < 0.001,
		"T1 CONTROL: after a re-tap straight AHEAD the next segment still ends at cruise (%.3f)" % ahead)
	await _settle()
	# The reversal: roll south, and at cruise re-tap back NORTH -- behind
	# him but still in front of the camera (the camera sits 8.9 u north).
	await _station_on_board(Vector3(3.0, 0.0, 60.0))
	_tap_world(Vector3(3.0, 0.0, 44.0))
	for _i in 40:
		await get_tree().process_frame
	var here := _keepy.global_position
	_tap_world(Vector3(3.0, 0.0, here.z + 6.0))
	n0 = _landings
	guard = 0
	while _landings < n0 + 1 and guard < 120:
		await get_tree().process_frame
		guard += 1
	await get_tree().process_frame
	var behind: float = _keepy.glide_pace()
	var expect: float = 1.0
	if HubTransport.SKATE_ACCEL_U > 0.0:
		expect = KeepyHopper.GLIDE_PACE_FLOOR \
			+ (1.0 - KeepyHopper.GLIDE_PACE_FLOOR) * HubTransport.SKATE_GLIDE_STEP / HubTransport.SKATE_ACCEL_U
	_check(behind < 0.75 and absf(behind - expect) < 0.01,
		"T2 after a re-tap BEHIND the next segment ends at %.3f -- the run-up again (want %.3f, not cruise)"
			% [behind, expect])
	await _settle()
	print("")

# =====================================================================
# PHASE S -- THE LANDING PROXY UNDER A ROLL.

func _phase_scoring() -> void:
	print("-- PHASE S: a landing in passing is not a landing; the stop is --")
	WorldSave.reset()
	_park.cancel_intent()
	var bowl: int = 4
	# S1. From the park, a roll that CROSSES the bowl's disc and stops on
	# grass. The path (3,60) -> (0.5,50.5) passes 2.3 u from the bowl's
	# centre against a tap radius of 3.0, so at least two of its 1.6 u
	# landings fall inside the disc.
	await _station_on_board(Vector3(3.0, 0.0, 60.0))
	_scores.clear()
	_broken = 0
	_landing_points.clear()
	_landings = 0
	var grass := Vector3(0.5, 0.0, 50.5)
	_check(_park.landed_within(grass) < 0, "S0 the stop point %s is on grass (no module)" % grass)
	_tap_world(grass)
	await _settle()
	var inside: int = 0
	for p in _landing_points:
		if _park.landed_within(p) == bowl:
			inside += 1
	_check(inside >= 2,
		"S1a BLIND CHECK: the roll landed INSIDE the bowl's disc %d times in passing (%d landings)" % [inside, _landing_points.size()])
	_check(_scores.is_empty(),
		"S1b and NONE of them scored (%d trick_scored)" % _scores.size())
	_check(_park.combo() == 0, "S1c the chain is untouched (%d)" % _park.combo())
	# S2. The stop on a module scores -- once.
	await _station_on_board(Vector3(3.0, 0.0, 60.0))
	_scores.clear()
	_broken = 0
	_tap_world(_park.module_centre(bowl))
	await _settle()
	_check(_scores.size() == 1 and int(_scores[0]["module"]) == bowl,
		"S2 a roll that STOPS on the bowl scores exactly once, on the bowl (%s)" % str(_scores))
	_check(_park.combo() == 0, "S2b and starts a chain at 0 (%d)" % _park.combo())
	# S3. On to the rail, over grass segments: the chain must SURVIVE the
	# grass and climb to 1 on the rail.
	_scores.clear()
	_tap_world(_park.module_centre(1))
	await _settle()
	_check(_scores.size() == 1 and int(_scores[0]["module"]) == 1 and int(_scores[0]["chain"]) == 1,
		"S3 the next stop on the rail CHAINS (chain 1) despite the grass landings between (%s)" % str(_scores))
	_check(_broken == 0, "S3b no chain_broken fired during the roll (%d)" % _broken)
	# S4. And the funbox: chain 2.
	_scores.clear()
	_tap_world(_park.module_centre(0))
	await _settle()
	_check(_scores.size() == 1 and int(_scores[0]["module"]) == 0 and int(_scores[0]["chain"]) == 2,
		"S4 the funbox makes it chain 2 (%s)" % str(_scores))
	print("     session points %d, stock left %d" % [_park.session_points(), WorldSave.skate_stock()])
	_keepy.dismount_vehicle()
	print("")
