extends Node
## CH54 / CH64 -- THE SKATEBOARD'S RIDE, REACHED THE WAY A PLAYER REACHES IT.
##
## =====================================================================
## WHAT THIS PROBE IS FOR, AND WHAT CH64 CHANGED ABOUT IT
##
## CH54 wrote this bench to answer Mathieu's "il est sur le skate mais il
## ne le conduit pas" by tracing the CH54 glide through the real tap
## channel. CH64 deleted that glide (mount_vehicle's path for the board)
## and the TAP destination scheme with it: the board is a CharacterBody3D
## for every player, mounted through the CARRIER door, and driven by a
## HELD FINGER. So the profile phases (run-up, cruise, run-out of a tapped
## roll) measure a ride that no longer exists and are gone with it.
##
## What this probe still owns -- and it is the one thing CH64's brief
## names as the twentieth near-miss -- is the ACTIVATION PATH: not "does
## the drive model work" (SkateInputProbe, SkatePhysicsProbe) but "can a
## player, with nothing but the screen, GET ON and GO". CH63 LOT 2 was
## green on 82 assertions and Mathieu tested twice and saw nothing,
## because the scheme was behind a toggle nobody had flipped. There is no
## toggle now, and this bench walks the whole path a thumb walks:
##
##   * a screen pixel on the parked board -> `tapped_vehicle` -> the walk
##     -> the mount on the landing (HubWorld._try_mount_ball, the shipped
##     door) -> ON_CARRIER, writer ARMED, chase camera ENTERED;
##   * a finger pressed and held through the ENGINE (`Input.parse_input_
##     event`, both nodes get their chance) -> the board moves at cruise
##     the way the finger points;
##   * the finger lifted -> the board coasts, it is not braked;
##   * a short tap at rest -> he steps off, and the next tap walks.
##
## =====================================================================
## WHY THIS RUNS UNDER xvfb + opengl3 AND NEVER --headless
##
## Every tap below is a SCREEN point unprojected on the delivered camera
## (HubTapInput._handle_point). In headless the container rect is 0x0,
## _handle_point returns before projecting anything, and every "he moved"
## check passes by never running -- the third of the four things CLAUDE.md
## lists the dummy driver breaking. PHASE I asserts the rect is real
## before anything is measured.

const BUDGET_S: float = 600.0
const VP_SIZE: Vector2i = Vector2i(1080, 1920)
const SETTLE: int = 3
const FPS: float = 60.0
## The rider's station: 4 u south of the parked board, well inside the
## lobe, with the board in the frame.
const STATION: Vector3 = Vector3(3.0, 0.0, 64.0)
const HOLD_FRAMES: int = 90

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _camera: HubCamera = null
var _sub: SubViewport = null
var _tap: HubTapInput = null
var _transport: HubTransport = null
var _saw: Array[StringName] = []
var _ground_taps: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE DRIVE PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_drive_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as KeepyHopper
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as HubCamera
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport
	_tap = _hub.get_node("TapInput") as HubTapInput
	_transport = _hub.get_node("WorldViewport/SubViewport/World/Transport") as HubTransport

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
	print("=== SKATE DRIVE PROBE -- CH54 / CH64 (the activation path) ===")
	if _keepy == null or _tap == null or _transport == null or _camera == null:
		push_error("SkateDriveProbe: hub scene is missing Keepy / TapInput / Transport / Camera3D.")
		get_tree().quit(1)
		return
	_tap.tapped_vehicle.connect(func(_p: Vector3) -> void: _saw.append(&"vehicle"))
	_tap.tapped_ground.connect(func(_p: Vector3) -> void:
		_saw.append(&"ground")
		_ground_taps += 1)
	await _phase_instrument()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every number below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_mount()
	await _phase_drive()
	await _phase_exit()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# HELPERS

func _station(flat: Vector3) -> void:
	_keepy.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	_camera.snap_to_target()
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

func _settle_walk(cap: int = 900) -> int:
	var frames: int = 0
	await get_tree().process_frame
	frames += 1
	while _keepy.is_hopping() and frames < cap:
		await get_tree().process_frame
		frames += 1
	return frames

func _settle_camera() -> void:
	var last: Transform3D = _camera.global_transform
	var stable: int = 0
	for _i in 480:
		await get_tree().physics_frame
		var now: Transform3D = _camera.global_transform
		var blend: float = _camera.drive_blend()
		if (blend < 0.001 or blend > 0.999) and now.origin.distance_to(last.origin) < 0.0005 \
				and (now.basis.z - last.basis.z).length() < 0.0002:
			stable += 1
			if stable >= 8:
				return
		else:
			stable = 0
		last = now

func _screen_ahead() -> Vector2:
	var rect: Rect2 = _tap.container.get_global_rect()
	return rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.55)

func _touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = at
	return e

func _drag(at: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = at
	return e

func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

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
	_keepy.dismount_vehicle()
	await _station(STATION)
	var board: Vector3 = _transport.board_position()
	var sp := _to_screen(board)
	_check(rect.has_point(sp), "I2 the parked board at %s projects INSIDE the container (%s)" % [board, sp.round()])
	# The tap channel on foot, where it has always worked: a tap on open
	# ground is tapped_ground and starts a walk.
	_saw.clear()
	_tap_world(STATION + Vector3(0.0, 0.0, -2.0))
	_check(_saw == [&"ground"], "I3 a tap on open lobe ground is tapped_ground (%s)" % str(_saw))
	await get_tree().process_frame
	_check(_keepy.is_hopping(), "I4 and it started a walk (the bench can see a tap take effect)")
	await _settle_walk()
	await _station(STATION)
	print("")

# =====================================================================
# PHASE M -- GETTING ON, FROM A PIXEL

func _phase_mount() -> void:
	print("-- PHASE M: a tap on the parked board puts him on it, through the shipped door --")
	_keepy.dismount_vehicle()
	await _station(STATION)
	_check(not _transport.is_riding_board(), "M0 INSTRUMENT: nobody is riding yet")
	_check(not _transport.board_touch().enabled, "M0 INSTRUMENT: and the writer is not armed")
	_saw.clear()
	_tap_world(_transport.board_position())
	_check(_saw == [&"vehicle"], "M1 a tap on the parked board is tapped_vehicle (%s)" % str(_saw))
	var walk_frames: int = await _settle_walk()
	# One more frame: the mount happens on the landing, before _advance.
	await get_tree().process_frame
	_check(_transport.is_riding_board(),
		"M2 after the walk (%d frames) he is ON THE BOARD -- the carrier door, through the tap channel" % walk_frames)
	_check(_keepy.is_on_carrier(), "M3 and the hopper is ON_CARRIER (the physics board is the only board)")
	_check(_transport.board_touch().enabled, "M4 the mount ARMED the finger writer -- no toggle, no menu")
	_check(_camera.is_driving() and _camera.drive_tuning() != null and not _camera.drive_tuning().is_plain(),
		"M5 and entered the chase camera with the BOARD's calm tuning")
	print("")

# =====================================================================
# PHASE D -- A HELD FINGER, THROUGH THE ENGINE

func _phase_drive() -> void:
	print("-- PHASE D: a finger held through the engine drives the board; a lift coasts it --")
	var body := _transport.board_body()
	_check(body != null and _transport.is_riding_board(), "D0 INSTRUMENT: aboard from PHASE M")
	if body == null:
		return
	await _settle_camera()
	var before: Vector3 = body.flat_position()
	var at: Vector2 = _screen_ahead()
	var taps_before: int = _ground_taps
	Input.parse_input_event(_touch(at, true))
	await get_tree().physics_frame
	await get_tree().physics_frame
	# ⚠️ CH65 -- THE PRESS OPENS A RAMP, NOT A SWITCH. Two frames in, the
	# board carries 0.15 of its push and climbing; full arrives in 29 ticks
	# (`SkateInputProbe` PHASE C measures the ramp itself and gates that it
	# only ever rises). What this phase is for is the ROUTING -- that an
	# engine-delivered press reaches the board at all -- so what it asks is
	# that the throttle has come OFF ZERO, which a dead route never would.
	_check(body.throttle() > 0.0,
		"D1 the press alone opened the board's throttle (%.4f, ramping)" % body.throttle())
	# DOWN the screen: the parked board faces north and the lobe's rim is
	# three units north of it -- a finger held UP ran the first version of
	# this phase straight into the fence (2.8 u, throttle dropped by the
	# fence, read as a dead throttle). A finger held down turns the board
	# south, onto thirty units of open lawn.
	Input.parse_input_event(_drag(at + Vector2(0.0, 140.0)))
	# ⚠️ CH65 -- AND THE FIRST 40 TICKS ARE THE **TURN**, NOT THE RIDE.
	# Down the screen is a REVERSAL under the chase camera, and since CH65
	# the nose is rate-limited and the push waits for it (`SkateBoardBody.
	# align`): the board points itself first and rides after. Measured
	# before this settle existed, on a 90-tick window: 0.004 u travelled
	# and a top speed of 0.080 u/s -- which reads exactly like a dead drive
	# model and was a stopwatch started on the wrong event.
	#
	# The reversal itself is not skipped, it is ASSERTED: the nose has to
	# have come round, or a board that simply refused the finger would slip
	# through this window unnoticed.
	var yaw_before: float = body.rotation.y
	for _s in 40:
		await get_tree().physics_frame
	var came_round: float = absf(rad_to_deg(angle_difference(yaw_before, body.rotation.y)))
	_check(came_round > 120.0,
		"D1b the held finger turned the board round to face it (%.1f deg in 40 ticks)" % came_round)
	var top: float = 0.0
	var held: bool = true
	for _i in HOLD_FRAMES:
		await get_tree().physics_frame
		top = maxf(top, body.speed())
		if body.throttle() < 0.99:
			held = false
	var moved: Vector3 = body.flat_position() - before
	print("     held %d ticks down the screen (south, open lawn): %.3f u, top %.3f u/s (cruise %.2f)" % [HOLD_FRAMES, moved.length(), top, HubTransport.SKATE_CRUISE])
	_check(held, "D2 the throttle stayed open every tick the finger was down")
	_check(moved.length() > 3.0, "D3 the board moved (%.3f u)" % moved.length())
	_check(top >= HubTransport.SKATE_CRUISE * 0.95, "D4 and reached cruise (%.3f)" % top)
	_check(_ground_taps == taps_before,
		"D5 and NOTHING reached the shipped tap route while riding (one finger, one meaning)")
	_check(HubRegion.contains(body.flat_position()), "D6 INSTRUMENT: the run stayed inside the region")
	# The lift: a coast, not a brake.
	var at_lift: float = body.speed()
	Input.parse_input_event(_touch(at + Vector2(0.0, 140.0), false))
	for _i in 6:
		await get_tree().physics_frame
	_check(is_zero_approx(body.throttle()), "D7 the lift closed the throttle")
	_check(body.speed() > at_lift * 0.5, "D8 and did NOT stop the board (%.3f -> %.3f u/s)" % [at_lift, body.speed()])
	# Let it coast to rest for the exit.
	for _i in 600:
		if _transport.board_at_rest():
			break
		await get_tree().physics_frame
	_check(_transport.board_at_rest(), "D9 INSTRUMENT: it coasted to rest (%.3f u/s)" % body.speed())
	print("")

# =====================================================================
# PHASE X -- GETTING OFF, AND THE NEXT TAP WALKS

func _phase_exit() -> void:
	print("-- PHASE X: a short tap at rest steps off; the next tap is a walk --")
	_check(_transport.is_riding_board(), "X0 INSTRUMENT: still aboard")
	await _settle_camera()
	var at: Vector2 = _screen_ahead()
	Input.parse_input_event(_touch(at, true))
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.parse_input_event(_touch(at, false))
	for _i in 10:
		await get_tree().physics_frame
	_check(not _transport.is_riding_board(), "X1 the tap at rest put him down")
	_check(not _keepy.is_on_carrier(), "X2 and the hopper is out of ON_CARRIER")
	_check(not _transport.board_touch().enabled, "X3 and the writer is disarmed")
	await _settle_walk()
	await _settle_camera()
	_check(not _camera.is_driving(), "X4 and the camera is back on the hub pose")
	var taps_before: int = _ground_taps
	_saw.clear()
	await get_tree().process_frame
	Input.parse_input_event(_touch(_screen_ahead(), true))
	await get_tree().physics_frame
	Input.parse_input_event(_touch(_screen_ahead(), false))
	for _i in 6:
		await get_tree().physics_frame
	_check(_ground_taps > taps_before, "X5 the NEXT tap reaches the shipped ground route again (x%d)" % (_ground_taps - taps_before))
	_check(_keepy.is_hopping(), "X6 and it is an ordinary walk")
	await _settle_walk()
	print("")
