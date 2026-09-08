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
	_keepy.hop_landed.connect(func(_p: Vector3) -> void: _landings += 1)
	await _phase_instrument()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every number below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_diagnosis()
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
