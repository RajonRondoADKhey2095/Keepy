extends Node
## CH33 -- the sailboat's contracts on the LIVE HubWorld.tscn, headless.
## Bounded by ProbeWatchdog from the first statement; exceeding it is an
## explicit INCONCLUSIVE, never a silent hang (CLAUDE.md: a probe whose
## script fails to parse traces to a timeout with no output, so this file
## is checked with `--quit-after 2` before any long run, same as every
## other probe in this repo).
##
## Modelled on CoveProbe.gd's PHASE YACHT (the closest existing contract:
## a HubTransport-coordinated driven vehicle, mount/exit through the same
## carrier pattern) with ONE new question CoveProbe never had to ask: the
## sailboat has no hard wall, only a continuous grounding drag, and the
## brief's hard requirement is that grounding is REVERSIBLE -- a boat that
## runs onto the beach must always be able to back off. See PHASE GROUND.
##
## Exit 0 = every assertion held; 1 = at least one failed;
## ProbeWatchdog.EXIT_TIMEOUT = inconclusive (never silently "green").
##
## Args after `--`: --only=moor|mount|drive|ground|exit|all

var _hub: Node = null
var _keepy: KeepyHopper = null
var _transport: HubTransport = null
var _weather: CozyWeather = null
var _camera: HubCamera = null
var _hud: KartHud = null
var _failures: int = 0
var _checks: int = 0
var _only: String = "all"

func _ready() -> void:
	ProbeWatchdog.arm(self, "SAILBOAT", 600.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
	WorldSave.SAVE_PATH_OVERRIDE = "user://sailboat_probe.json"
	WorldSave.reset()
	var packed: PackedScene = load("res://scenes/HubWorld.tscn")
	_hub = packed.instantiate()
	add_child(_hub)
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
	_transport = _hub.get_node("WorldViewport/SubViewport/World/Transport")
	_weather = _hub.get_node("WorldViewport/SubViewport/World/CozyWeather")
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	_hud = _hub.get_node("KartHud")
	_run()

func _run() -> void:
	await _frames(3)
	if _only == "all" or _only == "moor":
		await _phase_moor()
	if _only == "all" or _only == "mount":
		await _phase_mount()
	if _only == "all" or _only == "drive":
		await _phase_drive()
	if _only == "all" or _only == "ground":
		await _phase_ground()
	if _only == "all" or _only == "exit":
		await _phase_exit()
	print("")
	print("SAILBOAT PROBE: %d checks, %d failures -> %s" % [_checks, _failures, "PASS" if _failures == 0 else "FAIL"])
	get_tree().quit(0 if _failures == 0 else 1)

## ---- helpers ------------------------------------------------------------

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s%s" % ["ok" if ok else "FAIL", label, ("  -- " + detail) if detail != "" else ""])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)

func _put_keepy(at: Vector3) -> void:
	_keepy.global_position = _flat(at)
	_camera.snap_to_target()

func _settle(cap: int) -> int:
	var frames := 0
	for i in cap:
		await get_tree().process_frame
		frames += 1
		if not _keepy.is_hopping() and _hub._via_expect == Vector3.INF and not _keepy._has_target:
			break
	return frames

## ---- PHASE MOOR -----------------------------------------------------------
## The boat is where CH33's brief says it must always be at start-up: NO
## persistence read, so this is the same position every time regardless of
## where a previous session left it (there is nothing to leave -- exit
## writes nothing).

func _phase_moor() -> void:
	print("\nPHASE MOOR")
	var moor: Vector3 = HubTransport.SAILBOAT_MOORING
	_check("blind: the sailboat waits at its fixed mooring", _transport.sailboat_position().distance_to(moor) < 0.01, str(_transport.sailboat_position()))
	_check("blind: nobody is driving it", not _transport.is_driving_sailboat() and not _keepy.is_on_carrier())
	_check("the mooring is inside the sea disc (HubRegion, not restated)", HubRegion.in_sea(moor), str(moor))
	_check("the mooring reads as the `sea` body (HubWater)", _hub._water.body_at(moor) == &"sea")
	_check("the mooring accepts a vehicle tap and names the sailboat", _transport.vehicle_at(moor + Vector3(0.5, 0.0, 0.3)) == HubTransport.VEHICLE_SAILBOAT)
	_check("the yacht's own park still names the yacht (three vehicles, no cross-talk)", _transport.vehicle_at(HubTransport.YACHT_PARK) == HubTransport.VEHICLE_YACHT)
	_check("the ball's park still names the ball", _transport.vehicle_at(HubTransport.BALL_PARK) == HubTransport.VEHICLE_BALL)
	# SEA_RADIUS / SEA_CENTRE are read here, never written -- grep proof is
	# in the batch report, this is the runtime half of that proof.
	_check("the sea centre/radius this probe reads match HubRegion's own",
		absf(HubRegion.SEA_RADIUS - 48.0) < 0.001 and HubRegion.SEA_CENTRE.distance_to(Vector3(108.0, 0.0, -110.0)) < 0.001)

## ---- PHASE MOUNT ----------------------------------------------------------

func _phase_mount() -> void:
	print("\nPHASE MOUNT")
	var moor: Vector3 = HubTransport.SAILBOAT_MOORING
	_put_keepy(moor + Vector3(-2.5, 0.0, 1.5))
	_check("blind: the start is walkable (the wading rule)", HubRegion.contains(_keepy.global_position))
	await _frames(2)
	_hub._on_tapped_vehicle(moor)
	await _settle(400)
	await _frames(2)
	_check("the walk put him aboard, driving", _transport.is_driving_sailboat() and _keepy.is_on_carrier())
	_check("he stands on the seat (SailBoat.SEAT_Y)", absf(_keepy.global_position.y - SailBoat.SEAT_Y) < 0.01, "%.3f" % _keepy.global_position.y)
	_check("the writer is on", _transport.touch.enabled)
	_check("the camera chases the sailboat", _camera.is_driving())
	_check("the HUD is up, in vehicle mode", _hud.visible and _hud.vehicle_mode())
	_check("the world HUD stepped aside", not _hub._world_hud.visible)
	_check("the sailboat withdraws from the tap while driven", _transport.vehicle_at(_transport.sailboat_position()) == -1)
	_check("mounting the sailboat refuses the yacht", not _transport.mount_yacht())
	_check("no glide model left on the rider", not _keepy.is_on_vehicle() and not _keepy.is_gliding())

## ---- PHASE DRIVE ----------------------------------------------------------
## Continuous drive (automatic throttle), steering, and marine inertia --
## the "does not stop dead" contract, measured as a coast distance after
## the thumb lifts.

func _phase_drive() -> void:
	print("\nPHASE DRIVE")
	await _frames(int(HubTransport.MOUNT_HOLD_S * 60.0) + 10)
	var start: Vector3 = _transport.sailboat_position()
	var top: float = 0.0
	for i in 240:
		await get_tree().physics_frame
		top = maxf(top, _transport.sailboat().speed())
	var run: float = start.distance_to(_transport.sailboat_position())
	print("    free run: %.2f u in 240 frames, top %.2f u/s" % [run, top])
	_check("it drives with no tap at all", run > 6.0, "%.2f u" % run)
	_check("the rider is carried on the deck every frame", absf(_keepy.global_position.y - SailBoat.SEAT_Y) < 0.01
		and _flat(_keepy.global_position).distance_to(_transport.sailboat_position()) < 0.01)
	# ---- steering, measured AT SPEED (a parked vehicle does not pivot).
	var yaw0: float = _transport.sailboat().rotation.y
	var heel_seen: float = 0.0
	_transport.touch.steering_active = true
	_transport.touch.input.steer = 1.0
	for i in 120:
		await get_tree().physics_frame
		heel_seen = maxf(heel_seen, absf(_transport.sailboat().deck().rotation_degrees.z))
	_transport.touch.input.steer = 0.0
	_transport.touch.steering_active = false
	var turned: float = absf(wrapf(_transport.sailboat().rotation.y - yaw0, -PI, PI))
	_check("a held steer turns it", turned > 0.6, "%.2f rad" % turned)
	_check("it heels into the turn (away from it, the boat pattern)", heel_seen > 1.5, "%.2f deg" % heel_seen)
	# ---- inertia: let go of throttle by braking OFF -- there is no coast
	# switch on this touch scheme (automatic throttle is always 1 while
	# driven), so the contract is read on the BRAKE curve instead: the
	# brief's "ne s'arrete pas net" is checked as "does not stop in one
	# frame", which a snap-to-zero model would fail immediately.
	# In the sea, well off the shore -- (20, -110) was on dry land far from
	# the cove (first run of this phase measured 0.34 u/s there and never
	# reached a real cruise), not a defect this lot's code has to answer for.
	_transport.sailboat().place(Vector3(90.0, 0.0, -110.0), PI / 2.0)
	_keepy.call("follow_carrier")
	for i in 180:
		await get_tree().physics_frame
	var rolling: float = _transport.sailboat().speed()
	_check("(blind) it is rolling before the brake is tried", rolling > 4.0, "%.2f u/s" % rolling)
	var stopped_at: int = -1
	for i in 120:
		# Reasserted every frame: KartTouchInput._physics_process resets
		# `brake` to the keyboard's state (false, headless) whenever no
		# second finger is tracked, so a `true` set once outside this loop
		# is undone before the vehicle ever reads it (CoveProbe's yacht
		# brake test sets it the same way, inside the loop).
		_transport.touch.input.brake = true
		await get_tree().physics_frame
		if stopped_at < 0 and absf(_transport.sailboat().speed()) <= 0.05:
			stopped_at = i
	_transport.touch.input.brake = false
	_check("it does not stop in a single frame (marine inertia, not a snap)", stopped_at < 0 or stopped_at > 5, "%d frames" % stopped_at)
	_check("it does eventually stop or reverse under the brake", stopped_at >= 0 or _transport.sailboat().speed() < 0.0, "%d frames, %.2f u/s" % [stopped_at, _transport.sailboat().speed()])

## ---- PHASE GROUND ----------------------------------------------------------
## The brief's hardest requirement: echouage progressif ET reversible.
## RED-BEFORE-GREEN was run by hand for this phase (see docs/lots/
## CH33_VOILIER.md): with SailBoat.gd's grounding drag commented out, "the
## boat's speed keeps rising past the shoreline" and "reverse brings it
## back to open water" both failed as expected, and the file was restored
## byte-identical (`cmp`) before this version was trusted.

func _phase_ground() -> void:
	print("\nPHASE GROUND")
	var boat: SailBoat = _transport.sailboat()
	# ---- blind: the factor itself answers 0 far offshore and 1 well onto
	# the sand, before anything is asserted about its EFFECT on speed.
	var far_at_sea: Vector3 = HubRegion.SEA_CENTRE
	var well_aground: Vector3 = Vector3(HubRegion.SEA_CENTRE.x - HubRegion.SEA_RADIUS - 5.0, 0.0, HubRegion.SEA_CENTRE.z)
	_check("blind: mid-sea reads as free water (factor 0)", SailBoat.ground_factor_at(far_at_sea) < 0.001, "%.3f" % SailBoat.ground_factor_at(far_at_sea))
	_check("blind: well onto the sand reads as fully aground (factor 1)", SailBoat.ground_factor_at(well_aground) > 0.999, "%.3f" % SailBoat.ground_factor_at(well_aground))
	_check("blind: the factor actually varies between the two", absf(SailBoat.ground_factor_at(far_at_sea) - SailBoat.ground_factor_at(well_aground)) > 0.9)
	# ---- the sailboat, driven straight at the west shore, slows as it
	# approaches instead of holding its open-water pace to the sand.
	# West shore: HubRegion.SEA_CENTRE - (SEA_RADIUS, 0, 0), heading -x.
	var open_water: Vector3 = HubRegion.SEA_CENTRE - Vector3(30.0, 0.0, 0.0)
	boat.place(open_water, -PI / 2.0)
	_keepy.call("follow_carrier")
	var open_top: float = 0.0
	for i in 120:
		await get_tree().physics_frame
		open_top = maxf(open_top, boat.speed())
	_check("(blind) it reaches a real open-water pace first", open_top > 5.0, "%.2f u/s" % open_top)
	var min_speed_near_shore: float = INF
	var reached_ground: bool = false
	for i in 900:
		await get_tree().physics_frame
		if HubRegion.shore_distance(boat.flat_position()) > -2.0:
			min_speed_near_shore = minf(min_speed_near_shore, boat.speed())
		if boat.ground_factor() > 0.98:
			reached_ground = true
			break
	_check("it runs aground (grounding factor reaches its cap)", reached_ground, "factor=%.3f after 900 frames" % boat.ground_factor())
	_check("its speed near the shore is far under the open-water pace (progressive friction)", min_speed_near_shore < open_top * 0.5, "%.2f vs %.2f open" % [min_speed_near_shore, open_top])
	var grounded_at: Vector3 = boat.flat_position()
	var grounded_shore: float = HubRegion.shore_distance(grounded_at)
	print("    grounded at shore_distance %.3f, factor %.3f" % [grounded_shore, boat.ground_factor()])
	# ---- THE REVERSIBILITY CONTRACT: full reverse from the grounded spot
	# must bring the boat back to open water. This is the assertion that
	# was run against the grounding drag neutralised first (see docblock).
	var recovered: bool = false
	var frames_to_recover: int = -1
	for i in 900:
		# Reasserted every frame -- see the brake note in _phase_drive().
		_transport.touch.input.brake = true
		await get_tree().physics_frame
		if HubRegion.shore_distance(boat.flat_position()) <= -SailBoat.GROUND_FREE_MARGIN:
			recovered = true
			frames_to_recover = i
			break
	_transport.touch.input.brake = false
	print("    reverse-off-the-sand: %s after %d frames (shore_distance now %.3f)" % ["recovered" if recovered else "STUCK", frames_to_recover, HubRegion.shore_distance(boat.flat_position())])
	_check("REVERSING FROM AGROUND ALWAYS RETURNS TO OPEN WATER", recovered, "stuck at shore_distance %.3f" % HubRegion.shore_distance(boat.flat_position()))
	_check("the grounding factor relaxed back to free water", boat.ground_factor() < 0.01, "%.3f" % boat.ground_factor())
	# ---- CoveProbe's shape: the yacht's own beaching wall (SandYacht) is
	# untouched by this lot -- a cheap cross-check that CH33 did not leak
	# into CH30's file.
	var cross_check_yacht := SandYacht.new()
	_check("(cross-check) the land yacht's hard wall is still a hard wall, not a drag", not cross_check_yacht.has_method("ground_factor"))
	cross_check_yacht.free()

## ---- PHASE EXIT ------------------------------------------------------------

func _phase_exit() -> void:
	print("\nPHASE EXIT")
	# Away from SAILBOAT_MOORING on purpose: the no-persistence check below
	# needs a `left_at` a fresh session must NOT return to.
	var exit_spot := Vector3(70.0, 0.0, -100.0)
	_transport.sailboat().place(exit_spot, 0.0)
	_keepy.call("follow_carrier")
	await _frames(2)
	var left_at: Vector3 = _transport.sailboat_position()
	_transport.exit_sailboat()
	await _settle(200)
	await _frames(int(HubCamera.DRIVE_BLEND_S * 60.0) + 20)
	_check("the HUD button gives the body back", not _transport.is_driving_sailboat() and not _keepy.is_on_carrier())
	_check("he is on the ground beside it", absf(_keepy.global_position.y) < 0.001
		and _flat(_keepy.global_position).distance_to(left_at) < 4.0, str(_keepy.global_position))
	_check("the landing is in the region", HubRegion.contains(_keepy.global_position))
	_check("the writer, the chase and the HUD all went off together",
		not _transport.touch.enabled and not _camera.is_driving() and not _hud.visible and not _hud.vehicle_mode())
	_check("the world HUD came back", _hub._world_hud.visible)
	_check("the sailboat stays where he stepped off (this session)", _transport.sailboat_position().distance_to(left_at) < 0.01)
	_check("it accepts a tap again", _transport.vehicle_at(left_at) == HubTransport.VEHICLE_SAILBOAT)
	# ---- NO PERSISTENCE: a second HubTransport built fresh (a new session)
	# finds the sailboat back at its mooring, never at `left_at`.
	var t_fresh := HubTransport.new()
	add_child(t_fresh)
	await _frames(1)
	_check("a fresh session finds the sailboat at its fixed mooring, not where it was left",
		t_fresh.sailboat_position().distance_to(HubTransport.SAILBOAT_MOORING) < 0.01
		and t_fresh.sailboat_position().distance_to(left_at) > 5.0, str(t_fresh.sailboat_position()))
	t_fresh.queue_free()
