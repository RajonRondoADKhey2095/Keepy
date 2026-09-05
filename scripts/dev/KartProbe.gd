extends Node
## Carte-blanche V7 -- the karting contracts on the LIVE HubWorld.tscn,
## transforms only (headless, --fixed-fps 60).
##
## Bounded by ProbeWatchdog from the first statement. Every equality was
## made to FAIL first (red-before-green, journal V7); the blind checks are
## written into the phases (a thing is shown to MOVE before "it did not
## move" is believed).
##
## Exit 0 = every assertion held; 1 = at least one failed;
## ProbeWatchdog.EXIT_TIMEOUT = inconclusive.
##
## Args after `--`: --only=region|track|physics|mode|lap|race|all

var _hub: Node = null
var _keepy: KeepyHopper = null
var _karting: HubKarting = null
var _camera: HubCamera = null
var _hud: KartHud = null
var _tap: HubTapInput = null
var _failures: int = 0
var _checks: int = 0
var _only: String = "all"

func _ready() -> void:
	ProbeWatchdog.arm(self, "KART", 600.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
	WorldSave.SAVE_PATH_OVERRIDE = "user://kart_probe.json"
	WorldSave.reset()
	var packed: PackedScene = load("res://scenes/HubWorld.tscn")
	_hub = packed.instantiate()
	add_child(_hub)
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
	_karting = _hub.get_node("WorldViewport/SubViewport/World/Karting")
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	_hud = _hub.get_node("KartHud")
	_tap = _hub.get_node("TapInput")
	_run()

func _run() -> void:
	await _frames(3)
	if _only == "all" or _only == "region":
		await _phase_region()
	if _only == "all" or _only == "track":
		await _phase_track()
	if _only == "all" or _only == "physics":
		await _phase_physics()
	if _only == "all" or _only == "mode":
		await _phase_mode()
	if _only == "all" or _only == "lap":
		await _phase_lap()
	if _only == "all" or _only == "race":
		await _phase_race()
	print("")
	print("KART PROBE: %d checks, %d failures -> %s" % [_checks, _failures, "PASS" if _failures == 0 else "FAIL"])
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

## ---- PHASE REGION ---------------------------------------------------------

func _phase_region() -> void:
	print("\nPHASE REGION")
	var inside := Vector3(0.0, 0.0, -165.0)
	var corridor := Vector3(-8.0, 0.0, -130.0)
	var moor := Vector3(0.0, 0.0, -100.0)
	_check("circuit centre is zone 3", HubRegion.zone_of(inside) == 3)
	_check("circuit corridor is zone 3", HubRegion.zone_of(corridor) == 3)
	_check("moor is still zone 2", HubRegion.zone_of(moor) == 2)
	_check("circuit centre is region", HubRegion.contains(inside))
	_check("corridor is region", HubRegion.contains(corridor))
	# Blind: the hedge band between the moor and the circuit is NOT region
	# except at the corridor.
	_check("hedge east of the corridor is not region", not HubRegion.contains(Vector3(10.0, 0.0, -130.0)))
	var far := Vector3(0.0, 0.0, -400.0)
	var clamped: Vector3 = HubRegion.clamp_to(far)
	_check("a tap past the circuit clamps onto its far edge", HubRegion.contains(clamped) and absf(clamped.z - HubRegion.CIRCUIT_MIN.y) < 0.01, str(clamped))
	var gates: Array = _hub._gates_between(2, 3)
	_check("moor -> circuit is one gate, the circuit gate", gates.size() == 1 and gates[0] == _hub.CIRCUIT_GATE)
	var back: Array = _hub._gates_between(3, 0)
	_check("circuit -> plateau is three gates in reverse", back.size() == 3 and back[0] == _hub.CIRCUIT_GATE and back[2] == _hub.CORRIDOR_GATE)
	# A real walk: from the moor, a tap in the circuit goes to the gate
	# first (the corridor), then on.
	_put_keepy(Vector3(-2.0, 0.0, -108.0))
	await _frames(2)
	_hub._on_tapped_ground(inside)
	await _frames(2)
	_check("cross-zone walk aims at the circuit gate first", _hub._via_expect == _hub.CIRCUIT_GATE, str(_hub._via_expect))
	# Let it walk through: at 5.4 u/s the gate is ~22 u away.
	var reached_gate := false
	for i in 900:
		await get_tree().process_frame
		if _flat(_keepy.global_position).distance_to(_hub.CIRCUIT_GATE) < 2.0:
			reached_gate = true
		if not _keepy.is_hopping() and _hub._via_expect == Vector3.INF:
			break
	_check("the walk passed the gate", reached_gate)
	_check("and ended in the circuit", HubRegion.zone_of(_keepy.global_position) == 3 and _flat(_keepy.global_position).distance_to(inside) < 1.0, str(_keepy.global_position))

## ---- PHASE TRACK ----------------------------------------------------------

func _phase_track() -> void:
	print("\nPHASE TRACK")
	var track: KartTrack = _karting.track
	var line: Array[Vector3] = track.ideal_line()
	_check("spine has samples", line.size() >= 100, str(line.size()))
	_check("spine is closed (last sample near first)", line[line.size() - 1].distance_to(line[0]) < 3.0)
	_check("length is the plotted 230.7 u", absf(track.length() - 230.7) < 1.5, "%.2f" % track.length())
	var fence: Rect2 = track.fence()
	var all_in := true
	for p in line:
		if p.x < fence.position.x + KartTrack.HALF_WIDTH or p.x > fence.end.x - KartTrack.HALF_WIDTH or p.z < fence.position.y + KartTrack.HALF_WIDTH or p.z > fence.end.y - KartTrack.HALF_WIDTH:
			all_in = false
	_check("the whole ribbon is inside the fence", all_in)
	# Winding, read from the MESH and not from the code that wrote it.
	# Godot takes CLOCKWISE-seen-from-the-front as the front face, so a
	# ribbon whose front is UP has a right-hand-rule normal pointing DOWN
	# (CLAUDE.md: the stream ribbon that vanished had (0, +1, 0)). The
	# first version of this check asserted the opposite sign and went red
	# on a ribbon the capture showed drawn -- the assertion was wrong, the
	# geometry was right, and this comment is the receipt.
	var ribbon: MeshInstance3D = track.get_node("Ribbon")
	var faces: PackedVector3Array = ribbon.mesh.get_faces()
	var nrm: Vector3 = (faces[1] - faces[0]).cross(faces[2] - faces[0])
	_check("ribbon's first triangle is wound clockwise from above (RH normal down)", nrm.y < 0.0, str(nrm))
	var marks: MeshInstance3D = track.get_node("Marks")
	var mfaces: PackedVector3Array = marks.mesh.get_faces()
	var mnrm: Vector3 = (mfaces[1] - mfaces[0]).cross(mfaces[2] - mfaces[0])
	_check("marks' first triangle is wound clockwise from above", mnrm.y < 0.0, str(mnrm))
	var scatter_paths: MeshInstance3D = _hub.get_node("WorldViewport/SubViewport/World/CozyScatter/Paths")
	var pfaces: PackedVector3Array = scatter_paths.mesh.get_faces()
	var pnrm: Vector3 = (pfaces[1] - pfaces[0]).cross(pfaces[2] - pfaces[0])
	_check("(control) the shipped dirt paths carry the same sign", pnrm.y < 0.0, str(pnrm))
	_check("kerbs exist", (track.get_node("KerbRed") as MeshInstance3D).mesh.get_faces().size() > 0)
	# progress_at round-trips point_at, and is measured from the line.
	var worst := 0.0
	var s := 0.0
	while s < track.length():
		var p: Vector3 = track.point_at(track.start_line_offset() + s)
		var got: float = float(track.progress_at(p)["s"])
		var err: float = minf(absf(got - s), track.length() - absf(got - s))
		worst = maxf(worst, err)
		s += 5.0
	_check("progress_at round-trips point_at (worst error < 0.05 u)", worst < 0.05, "%.4f" % worst)
	var start: Dictionary = track.start_line()
	_check("progress at the start line is 0", float(track.progress_at(start["position"])["s"]) < 0.01 or float(track.progress_at(start["position"])["s"]) > track.length() - 0.01)
	# Blind for on_track: the centreline IS on track, 6 u off it is NOT.
	var mid: Vector3 = track.point_at(60.0)
	var tan: Vector3 = track.tangent_at(60.0)
	var side := Vector3(tan.z, 0.0, -tan.x)
	_check("centreline is on track", track.on_track(mid))
	_check("3 u right of it is on track", track.on_track(mid + side * 3.0))
	_check("6 u right of it is NOT on track", not track.on_track(mid + side * 6.0))
	_check("lateral sign: right of travel is positive", float(track.progress_at(mid + side * 2.0)["lateral"]) > 1.9)
	var g0: Dictionary = track.start_pose(0)
	var g1: Dictionary = track.start_pose(1)
	_check("grid slot 0 is on track, short of the line", track.on_track(g0["position"]) and float(track.progress_at(g0["position"])["s"]) > track.length() - 8.0)
	_check("grid slot 1 is on track, the other lane, further back", track.on_track(g1["position"]) and (g1["position"] as Vector3).distance_to(g0["position"]) > 3.5)
	# Hinted search agrees with the full search along the whole lap.
	var hint := -1
	var disagree := 0
	s = 0.0
	while s < track.length():
		var p: Vector3 = track.point_at(track.start_line_offset() + s) + side * 0.5
		var full: Dictionary = track.progress_at(p)
		var quick: Dictionary = track.progress_at(p, hint)
		hint = int(quick["index"])
		if absf(float(full["s"]) - float(quick["s"])) > 0.01:
			disagree += 1
		s += 1.0
	_check("hinted progress agrees with the full search", disagree == 0, str(disagree))

## ---- PHASE PHYSICS --------------------------------------------------------

func _phase_physics() -> void:
	print("\nPHASE PHYSICS")
	var kart := KartBody.new()
	add_child(kart)
	var input := KartInput.new()
	var fence := Rect2(-100.0, -100.0, 200.0, 200.0)
	var dt: float = 1.0 / 60.0
	kart.place(Vector3.ZERO, 0.0)
	# Accelerate 4 s straight.
	input.set_all(0.0, 1.0, false)
	for i in 240:
		kart.drive(dt, input, true, fence)
	_check("full throttle reaches 90 % of MAX_SPEED in 4 s", kart.speed() >= 0.9 * KartBody.MAX_SPEED, "%.2f" % kart.speed())
	_check("and never exceeds it", kart.speed() <= KartBody.MAX_SPEED + 0.01)
	_check("it went along +z (yaw 0 = +z)", kart.global_position.z > 20.0 and absf(kart.global_position.x) < 0.01, str(kart.global_position))
	# Blind: no steer, yaw unchanged.
	_check("yaw unchanged without steer", absf(kart.rotation.y) < 0.0001)
	var yaw0: float = kart.rotation.y
	input.set_all(1.0, 1.0, false)
	for i in 30:
		kart.drive(dt, input, true, fence)
	_check("steer right decreases yaw", kart.rotation.y < yaw0 - 0.3, "%.3f" % (kart.rotation.y - yaw0))
	var lat: float = kart.velocity.dot(kart.right())
	_check("turning at speed leaves a lateral slide (grip is not infinite)", absf(lat) > 0.2, "%.3f" % lat)
	var v_turn: float = kart.speed()
	input.set_all(0.0, 1.0, false)
	for i in 60:
		kart.drive(dt, input, true, fence)
	_check("the slide dies in a second on the track", absf(kart.velocity.dot(kart.right())) < 0.05)
	_check("a corner costs speed (projection into the new heading, plus scrub)", v_turn < KartBody.MAX_SPEED - 0.05, "%.2f" % v_turn)
	# Brake.
	input.set_all(0.0, 1.0, true)
	for i in 120:
		kart.drive(dt, input, true, fence)
	_check("brake stops it within 2 s (then reverses)", kart.speed() <= 0.0, "%.2f" % kart.speed())
	_check("reverse is capped", kart.speed() >= -KartBody.REVERSE_SPEED - 0.01)
	# Off track: the cap drops.
	input.set_all(0.0, 1.0, false)
	for i in 300:
		kart.drive(dt, input, false, fence)
	_check("off the track the speed settles at the grass cap", kart.speed() <= KartBody.MAX_SPEED_OFF_TRACK + 0.05 and kart.speed() > KartBody.MAX_SPEED_OFF_TRACK - 0.5, "%.2f" % kart.speed())
	# Re-placed first: five seconds at full speed from wherever the grass
	# left it would reach the fence, and a bounce is not a recovery.
	var v_grass: float = kart.speed()
	kart.place(Vector3.ZERO, 0.0)
	kart.velocity = kart.forward() * v_grass
	for i in 300:
		kart.drive(dt, input, true, fence)
	_check("back on the track it recovers", kart.speed() > 0.9 * KartBody.MAX_SPEED, "%.2f" % kart.speed())
	# Fence: aim at the far edge, keep going.
	kart.place(Vector3(90.0, 0.0, 0.0), PI * 0.5)
	for i in 240:
		kart.drive(dt, input, true, fence)
	_check("the soft fence keeps the kart inside", kart.global_position.x <= fence.end.x + 0.001, "%.2f" % kart.global_position.x)
	_check("and the kart is not stuck to it", kart.global_position.x < fence.end.x - 0.5 or kart.speed() < 1.0)
	kart.queue_free()

## ---- PHASE MODE -----------------------------------------------------------

func _phase_mode() -> void:
	print("\nPHASE MODE")
	var kart: KartBody = _karting.player_kart()
	var park: Vector3 = _flat(kart.global_position)
	_check("kart parked on the grid, in the circuit", HubRegion.zone_of(park) == 3 and _karting.track.on_track(park))
	_check("kart is tappable (aim on it)", _karting.accepts_tap(park + Vector3(0.5, 0.0, 0.5)))
	_check("kart is not tappable 6 u away", not _karting.accepts_tap(park + Vector3(6.0, 0.0, 0.0)))
	_check("not driving before the tap", not _karting.is_driving() and not _karting.touch.enabled and not _hud.visible and not _camera.is_driving())
	var hub_basis: Basis = _camera.global_transform.basis
	var hub_fov: float = _camera.fov
	var hub_far: float = _camera.far
	# Stand 4 u from it, tap it: walk + mount.
	_put_keepy(park + Vector3(0.0, 0.0, 4.0))
	await _frames(2)
	_hub._on_tapped_kart(park)
	var mounted := false
	for i in 300:
		await get_tree().process_frame
		if _karting.is_driving():
			mounted = true
			break
	_check("the tap walked him to the kart and mounted", mounted)
	_check("Keepy is ON_CARRIER", _keepy.is_on_carrier())
	_check("touch writer enabled", _karting.touch.enabled)
	_check("HUD shown", _hud.visible)
	# V8 P0: the chrono panel must sit INSIDE the canvas. The V7 build
	# anchored it CENTER_TOP and wrote a canvas coordinate into `position`
	# (an offset from the anchor), which put it at x = 890..1270 on a 1080
	# canvas -- clipped on device. Red-before-green: with the V7 line
	# restored this check reads end.x = 1270 and fails.
	# The headless window is 1920 x 1920 (CLAUDE.md), so "inside the
	# canvas" is measured against the SHIPPED width: the 1080 px band
	# centred on the canvas middle (SafeArea's EXPAND aspect only ever
	# grows the canvas vertically, so the band is the narrowest canvas a
	# device shows).
	var canvas: Vector2 = _hud.get_viewport_rect().size
	var design_w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var design_h: float = float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	var band_l: float = canvas.x * 0.5 - design_w * 0.5
	var band_r: float = canvas.x * 0.5 + design_w * 0.5
	var panel_rect: Rect2 = _hud._panel.get_global_rect()
	_check("chrono panel inside the shipped 1080 px band", panel_rect.position.x >= band_l and panel_rect.end.x <= band_r, "%s, band [%.0f, %.0f]" % [panel_rect, band_l, band_r])
	_check("chrono panel centred (|centre - width/2| < 2 px)", absf(panel_rect.get_center().x - canvas.x * 0.5) < 2.0, "%.1f" % panel_rect.get_center().x)
	var wrong_rect: Rect2 = _hud._wrong_label.get_global_rect()
	_check("wrong-way label inside the shipped band", wrong_rect.position.x >= band_l and wrong_rect.end.x <= band_r and wrong_rect.position.y >= 0.0 and wrong_rect.end.y <= design_h, str(wrong_rect))
	_check("resource counter hidden while driving", not _hub._world_hud.visible)
	_check("camera in drive mode", _camera.is_driving())
	_check("kart withdrew from the tap", not _karting.accepts_tap(park))
	await _frames(60)
	_check("camera blended fully into the drive pose", _camera.drive_blend() > 0.99, "%.3f" % _camera.drive_blend())
	_check("drive fov applied", absf(_camera.fov - HubCamera.DRIVE_FOV) < 0.01)
	_check("drive far plane applied", _camera.far == HubCamera.DRIVE_FAR)
	_check("the throttle is held for the blend: kart still parked", _flat(kart.global_position).distance_to(park) < 0.05, "%.3f" % _flat(kart.global_position).distance_to(park))
	var cam_drive: Vector3 = _camera.global_position
	var behind: Vector3 = _flat(kart.global_position) - kart.forward() * HubCamera.DRIVE_BACK
	_check("drive camera sits behind the kart", _flat(cam_drive).distance_to(behind) < 0.3, str(_flat(cam_drive).distance_to(behind)))
	_check("and above it", absf(cam_drive.y - HubCamera.DRIVE_UP) < 0.3)
	# V8: the mount opens a COUNTDOWN (mount hold + 3 s of lights); the
	# accelerator engages at GO, not before. Blind: still parked at the
	# end of the old 1.5 s window, moving within a second of GO.
	await _frames(30)
	_check("V8: still parked 1.5 s after the mount (countdown)", _flat(kart.global_position).distance_to(park) < 0.05 and _karting.race_state == HubKarting.Race.COUNTDOWN, "%.3f" % _flat(kart.global_position).distance_to(park))
	_check("V8: lights shown during the countdown", _hud._lights_box.visible)
	for i in 400:
		await get_tree().process_frame
		if _karting.race_state == HubKarting.Race.RUNNING:
			break
	_check("V8: GO within (hold + 3 s) of the mount", _karting.race_state == HubKarting.Race.RUNNING)
	await _frames(60)
	_check("then the accelerator engages on its own", _flat(kart.global_position).distance_to(park) > 0.3, "%.3f" % _flat(kart.global_position).distance_to(park))
	# Drive 2 s with a scripted input and watch Keepy ride.
	var input: KartInput = _karting.touch.input
	input.set_all(0.0, 1.0, false)
	var worst := 0.0
	for i in 120:
		await get_tree().process_frame
		var seat: Vector3 = kart.chassis().to_global(KartBody.SEAT)
		worst = maxf(worst, seat.distance_to(_keepy.global_position))
	_check("the kart moved", _flat(kart.global_position).distance_to(park) > 5.0, "%.2f" % _flat(kart.global_position).distance_to(park))
	_check("Keepy stayed on the seat (worst gap < 0.02)", worst < 0.02, "%.4f" % worst)
	_check("kart yaw is Keepy's yaw", absf(wrapf(deg_to_rad(_keepy.get_node("Yaw").rotation_degrees.y) - kart.rotation.y, -PI, PI)) < 0.02)
	# A ground tap while driving is refused by state: nothing changes.
	var before: Vector3 = _keepy.global_position
	_hub._on_tapped_ground(park + Vector3(10.0, 0.0, 10.0))
	await _frames(2)
	_check("a ground tap while driving does nothing", _keepy.is_on_carrier() and _karting.is_driving())
	_check("and HubTapInput would not even handle it", _tap.karting.is_driving())
	# Exit.
	input.set_all(0.0, 0.0, false)
	_karting.exit_kart()
	await _frames(2)
	_check("exit: not driving", not _karting.is_driving())
	_check("exit: writer disabled, input cleared", not _karting.touch.enabled and input.throttle == 0.0)
	_check("exit: HUD hidden", not _hud.visible)
	_check("exit: resource counter shown again", _hub._world_hud.visible)
	_check("exit: kart stopped", kart.velocity.length() < 0.001)
	_check("exit: Keepy hopping off (HOPPING)", _keepy.is_hopping())
	for i in 120:
		await get_tree().process_frame
		if not _keepy.is_hopping() and not _camera.is_driving():
			break
	_check("exit: Keepy idle beside the kart, on the region", not _keepy.is_hopping() and not _keepy.is_on_carrier() and HubRegion.contains(_keepy.global_position) and _flat(_keepy.global_position).distance_to(_flat(kart.global_position)) < 3.0, str(_keepy.global_position))
	_check("exit: camera left drive mode", not _camera.is_driving())
	_check("exit: camera basis restored byte-identical", _camera.global_transform.basis == hub_basis)
	_check("exit: fov restored", _camera.fov == hub_fov)
	_check("exit: far plane restored", _camera.far == hub_far)
	_check("exit: kart tappable again", _karting.accepts_tap(_flat(kart.global_position)))
	# The world is his again: a ground tap walks.
	_hub._on_tapped_ground(_flat(_keepy.global_position) + Vector3(3.0, 0.0, 0.0))
	await _frames(2)
	_check("a ground tap after exit walks", _keepy.is_hopping())
	for i in 120:
		await get_tree().process_frame
		if not _keepy.is_hopping():
			break

## ---- PHASE LAP ------------------------------------------------------------

func _phase_lap() -> void:
	print("\nPHASE LAP")
	var kart: KartBody = _karting.player_kart()
	var track: KartTrack = _karting.track
	var lap: KartLap = _karting.player_lap()
	# Park again, mount on the spot.
	var pose: Dictionary = track.start_pose(0)
	kart.place(pose["position"], pose["yaw"])
	_put_keepy(_flat(kart.global_position) + Vector3(0.0, 0.0, 1.0))
	await _frames(2)
	_hub._on_tapped_kart(_flat(kart.global_position))
	for i in 120:
		await get_tree().process_frame
		if _karting.is_driving():
			break
	_check("mounted for the lap", _karting.is_driving())
	_check("no lap yet, not timing", lap.lap_count == 0 and not lap.timing)
	_check("no best saved yet", WorldSave.kart_best_ms(KartTrack.TRACK_ID) == 0)
	var driver := KartAiDriver.new()
	driver.setup(track, "probe")
	# The opponents race too; the timing contract below is the player's.
	# They are parked for the wrong-way section (a bump there would be
	# noise, not a measurement).
	var input: KartInput = _karting.touch.input
	var laps_seen: Array = []
	lap.on_lap = func(ms: int): laps_seen.append(ms); _karting._on_lap(0, ms)
	var frames := 0
	var timing_started_at := -1
	var checkpoints_max := 0
	var hold_frames: int = int(ceil((HubKarting.MOUNT_HOLD_S + HubKarting.COUNTDOWN_S) * 60.0))
	while frames < 60 * 90 + hold_frames and laps_seen.size() < 2:
		driver.drive(kart, input)
		await get_tree().process_frame
		frames += 1
		checkpoints_max = maxi(checkpoints_max, lap.next_checkpoint())
		if lap.timing and timing_started_at < 0:
			timing_started_at = frames
	_check("timing started at the first crossing (within countdown + 4 s)", timing_started_at > 0 and timing_started_at < hold_frames + 240, str(timing_started_at))
	_check("two laps driven by the line follower in 90 s", laps_seen.size() == 2, str(laps_seen))
	if laps_seen.size() >= 1:
		var ms: int = laps_seen[0]
		_check("first lap between 15 and 60 s", ms > 15000 and ms < 60000, str(ms))
		_check("best lap saved", WorldSave.kart_best_ms(KartTrack.TRACK_ID) == mini(laps_seen[0], laps_seen[1]) if laps_seen.size() == 2 else WorldSave.kart_best_ms(KartTrack.TRACK_ID) == ms, str(WorldSave.kart_best_ms(KartTrack.TRACK_ID)))
		_check("lap stat noted", WorldSave.stats()["kart_laps"] == laps_seen.size())
		_check("HUD reads the best", _hud._best_label.text.contains(KartLap.format_ms(WorldSave.kart_best_ms(KartTrack.TRACK_ID))), _hud._best_label.text)
	_check("all three checkpoints were passed", checkpoints_max == KartLap.CHECKPOINTS)
	_check("the follower kept the kart on the track at the end", track.on_track(kart.global_position))
	# Persistence: flush, reload from the file, same best.
	var best: int = WorldSave.kart_best_ms(KartTrack.TRACK_ID)
	WorldSave.save_now()
	WorldSave._data = WorldSave._defaults()
	_check("(blind) in-memory best cleared", WorldSave.kart_best_ms(KartTrack.TRACK_ID) == 0)
	WorldSave._load()
	_check("best survives a reload from user://", WorldSave.kart_best_ms(KartTrack.TRACK_ID) == best and best > 0, str(WorldSave.kart_best_ms(KartTrack.TRACK_ID)))
	# A slower lap does not replace the best.
	_check("a slower lap is refused", not WorldSave.kart_offer_lap(KartTrack.TRACK_ID, best + 1000) and WorldSave.kart_best_ms(KartTrack.TRACK_ID) == best)
	_check("a faster lap is taken", WorldSave.kart_offer_lap(KartTrack.TRACK_ID, best - 1000) and WorldSave.kart_best_ms(KartTrack.TRACK_ID) == best - 1000)
	# Wrong way: turn the kart round on the straight and drive.
	input.set_all(0.0, 0.0, false)
	for i in _karting.racers.size():
		if not _karting.racers[i]["player"]:
			_karting.racers[i]["active"] = false
	var s_line: float = track.start_line_offset()
	var back_tan: Vector3 = -track.tangent_at(s_line + 6.0)
	kart.place(track.point_at(s_line + 6.0), atan2(back_tan.x, back_tan.z))
	lap.reset()
	input.set_all(0.0, 1.0, false)
	for i in 180:
		await get_tree().process_frame
	_check("wrong way flagged after driving backwards 3 s", lap.wrong_way)
	_check("HUD shows the wrong-way cue", _hud._wrong_label.visible)
	_check("a backwards crossing gave no lap", lap.lap_count == 0)
	# Forward over the line with NO checkpoints: timing starts, no lap.
	var fwd_tan: Vector3 = track.tangent_at(s_line - 6.0)
	kart.place(track.point_at(s_line - 6.0), atan2(fwd_tan.x, fwd_tan.z))
	lap.reset()
	for i in 120:
		await get_tree().process_frame
	_check("a forward crossing without checkpoints starts the clock", lap.timing)
	_check("wrong-way cleared when driving forward", not lap.wrong_way)
	# ⚠️ The FIRST crossing can never count (timing was off), so it proves
	# nothing about the checkpoint gate -- the red pass caught exactly
	# that: with the gate neutralised this phase stayed green. The real
	# test is a SECOND forward crossing, clock running, no checkpoint
	# passed: teleported back short of the line (which the lap reads as a
	# backwards crossing and forfeits the -- already empty -- checkpoints)
	# and driven over it again.
	kart.place(track.point_at(s_line - 6.0), atan2(fwd_tan.x, fwd_tan.z))
	var count_before: int = lap.lap_count
	for i in 120:
		await get_tree().process_frame
	_check("a second forward crossing with the clock running, no checkpoints: counts no lap", lap.lap_count == count_before and lap.timing)
	input.set_all(0.0, 0.0, false)
	_karting.exit_kart()
	for i in 90:
		await get_tree().process_frame
	_check("exited cleanly after the laps", not _karting.is_driving() and not _keepy.is_on_carrier() and not _keepy.is_hopping())

## ---- PHASE RACE (V8) ------------------------------------------------------

func _phase_race() -> void:
	print("\nPHASE RACE")
	var track: KartTrack = _karting.track
	var kart: KartBody = _karting.player_kart()
	var lap: KartLap = _karting.player_lap()
	# The grid.
	_check("four racers: the player and three opponents", _karting.racers.size() == 4 and _karting.opponent_count() == 3, str(_karting.racers.size()))
	var profiles: Array = []
	var colours: Array = []
	var riders_ok: bool = true
	for r in _karting.racers:
		colours.append((r["kart"] as KartBody).body_colour)
		if r["player"]:
			continue
		var driver: KartAiDriver = r["driver"]
		profiles.append(driver.profile_id if driver != null else "")
		var rider: HubCritter = r["rider"]
		if rider == null or rider.model() == null or rider.get_parent() != (r["kart"] as KartBody).chassis() or rider.position != KartBody.SEAT:
			riders_ok = false
	_check("three distinct driver profiles (cat / beaver / boar)", profiles.size() == 3 and profiles.has("cat") and profiles.has("beaver") and profiles.has("boar"), str(profiles))
	_check("four distinct kart colours", colours[0] != colours[1] and colours[0] != colours[2] and colours[0] != colours[3] and colours[1] != colours[2] and colours[1] != colours[3] and colours[2] != colours[3])
	_check("each opponent has a rider on the seat, in the chassis", riders_ok)
	var cat_driver: KartAiDriver = null
	var boar_driver: KartAiDriver = null
	for r in _karting.racers:
		if r["driver"] != null and (r["driver"] as KartAiDriver).profile_id == "cat":
			cat_driver = r["driver"]
		if r["driver"] != null and (r["driver"] as KartAiDriver).profile_id == "boar":
			boar_driver = r["driver"]
	# The profiles differ where it counts: at the omega (tightest bend)
	# the cat's v_max is above the boar's; on the straight the boar's is
	# above the cat's.
	var tight: int = 0
	var straight: int = 0
	for i in track.sample_count():
		if track.curvature(i) > track.curvature(tight):
			tight = i
		if track.curvature(i) < track.curvature(straight):
			straight = i
	_check("cat faster than the boar at the tightest bend", cat_driver.vmax_at(tight) > boar_driver.vmax_at(tight), "%.2f vs %.2f" % [cat_driver.vmax_at(tight), boar_driver.vmax_at(tight)])
	_check("boar faster than the cat on the straight", boar_driver.vmax_at(straight) > cat_driver.vmax_at(straight), "%.2f vs %.2f" % [boar_driver.vmax_at(straight), cat_driver.vmax_at(straight)])
	_check("the profile brakes before the bend: v_max is lower 3 samples before the omega than 12 before", cat_driver.vmax_at(tight - 3) < cat_driver.vmax_at(tight - 12), "%.2f < %.2f" % [cat_driver.vmax_at(tight - 3), cat_driver.vmax_at(tight - 12)])
	# Collisions, blind: overlap two karts by hand, one frame of _collide.
	var a: KartBody = _karting.racers[1]["kart"]
	var b: KartBody = _karting.racers[2]["kart"]
	var a_pose: Vector3 = a.global_position
	var b_pose: Vector3 = b.global_position
	_karting.racers[1]["active"] = true
	_karting.racers[2]["active"] = true
	a.global_position = Vector3(0.0, 0.0, -150.0)
	b.global_position = Vector3(0.5, 0.0, -150.0)
	a.velocity = Vector3(4.0, 0.0, 0.0)
	b.velocity = Vector3(-2.0, 0.0, 0.0)
	_karting._collide()
	var d: float = _flat(a.global_position).distance_to(_flat(b.global_position))
	_check("(blind) overlapping karts are pushed apart to 2 R", absf(d - 2.0 * HubKarting.KART_RADIUS) < 0.01, "%.3f" % d)
	_check("the closing speed is exchanged softly (a slower than before, b pushed right)", a.velocity.x < 4.0 and b.velocity.x > -2.0, "%s %s" % [a.velocity, b.velocity])
	_check("both chassis jolted", a._bump > 0.0 and b._bump > 0.0)
	a.place(a_pose, a.rotation.y)
	b.place(b_pose, b.rotation.y)
	_karting.racers[1]["active"] = false
	_karting.racers[2]["active"] = false
	var far_a: Vector3 = a.global_position
	_karting._collide()
	_check("(blind) parked karts on their slots do not touch", a.global_position == far_a)
	# Rubber band, on the published numbers alone.
	_karting.rubber_band_enabled = true
	var pi: int = _karting.player_index()
	_karting.race_state = HubKarting.Race.RUNNING
	# Progress counts line crossings: both laps reset so only `s` speaks.
	(_karting.racers[pi]["lap"] as KartLap).reset()
	(_karting.racers[1]["lap"] as KartLap).reset()
	_karting.racers[pi]["s"] = 50.0
	_karting.racers[1]["s"] = 50.0 + HubKarting.RUBBER_DEAD - 1.0
	_check("rubber band inert inside the dead band", _karting.rubber_band_for(1) == 1.0, str(_karting.rubber_band_for(1)))
	_karting.racers[1]["s"] = 50.0 + HubKarting.RUBBER_DEAD + HubKarting.RUBBER_SPAN + 10.0
	_check("an opponent far ahead is leashed to RUBBER_MIN", absf(_karting.rubber_band_for(1) - HubKarting.RUBBER_MIN) < 0.001, str(_karting.rubber_band_for(1)))
	_karting.racers[1]["s"] = 50.0 - HubKarting.RUBBER_DEAD - HubKarting.RUBBER_SPAN - 10.0
	_check("an opponent far behind is let go to RUBBER_MAX", absf(_karting.rubber_band_for(1) - HubKarting.RUBBER_MAX) < 0.001, str(_karting.rubber_band_for(1)))
	_karting.racers[1]["s"] = 0.0
	_karting.racers[pi]["s"] = 0.0
	_karting.race_state = HubKarting.Race.IDLE
	# A whole race. Mount on the spot; the probe driver drives the player.
	_put_keepy(_flat(kart.global_position) + Vector3(0.0, 0.0, 1.0))
	await _frames(2)
	_hub._on_tapped_kart(_flat(kart.global_position))
	for i in 120:
		await get_tree().process_frame
		if _karting.is_driving():
			break
	_check("mounted for the race", _karting.is_driving() and _karting.race_state == HubKarting.Race.COUNTDOWN)
	var grid_ok: bool = true
	var parked: Array = []
	for i in _karting.racers.size():
		var r: Dictionary = _karting.racers[i]
		var pose: Dictionary = track.start_pose(i)
		parked.append(_flat((r["kart"] as KartBody).global_position))
		if _flat((r["kart"] as KartBody).global_position).distance_to(pose["position"]) > 0.05 or not r["active"]:
			grid_ok = false
	_check("all four on their grid slots and active", grid_ok)
	await _frames(int((HubKarting.MOUNT_HOLD_S + HubKarting.COUNTDOWN_S) * 60.0) - 20)
	var held: bool = true
	for i in _karting.racers.size():
		if _flat((_karting.racers[i]["kart"] as KartBody).global_position).distance_to(parked[i]) > 0.05:
			held = false
	_check("(blind) every kart held on the grid through the countdown", held and _karting.race_state == HubKarting.Race.COUNTDOWN)
	_check("HUD: position label reads x / 4", _hud._position_label.visible and _hud._position_label.text.ends_with("/ 4"), _hud._position_label.text)
	_check("HUD: four standings rows", _hud._standings_rows.size() == 4 and _hud._standings_box.visible)
	for i in 100:
		await get_tree().process_frame
		if _karting.race_state == HubKarting.Race.RUNNING:
			break
	_check("GO", _karting.race_state == HubKarting.Race.RUNNING)
	var driver := KartAiDriver.new()
	driver.setup(track, "probe")
	var input: KartInput = _karting.touch.input
	for i in 120:
		driver.drive(kart, input)
		await get_tree().process_frame
	var moved_all: bool = true
	for i in _karting.racers.size():
		if _flat((_karting.racers[i]["kart"] as KartBody).global_position).distance_to(parked[i]) < 1.0:
			moved_all = false
	_check("two seconds after GO all four karts have left the grid", moved_all)
	var order: Array[int] = _karting.standings()
	_check("standings are consistent with progress", _karting.progress_of(order[0]) >= _karting.progress_of(order[1]) and _karting.progress_of(order[1]) >= _karting.progress_of(order[2]) and _karting.progress_of(order[2]) >= _karting.progress_of(order[3]))
	var frames := 0
	var finished := false
	var min_gap := INF
	while frames < 60 * 130:
		driver.drive(kart, input)
		await get_tree().process_frame
		frames += 1
		for i in 4:
			for j in range(i + 1, 4):
				min_gap = minf(min_gap, _flat((_karting.racers[i]["kart"] as KartBody).global_position).distance_to(_flat((_karting.racers[j]["kart"] as KartBody).global_position)))
		if int(_karting.racers[pi]["finish_ms"]) >= 0:
			finished = true
			break
	_check("the player finished three laps within 130 s", finished, "%d frames" % frames)
	_check("race FINISHED for the player", _karting.race_state == HubKarting.Race.FINISHED)
	_check("no two karts ever interpenetrated below 2 R - 0.15", min_gap >= 2.0 * HubKarting.KART_RADIUS - 0.15, "%.3f" % min_gap)
	var rows: Array = _karting.results()
	_check("results: four rows, ranks 1..4", rows.size() == 4 and int(rows[0]["rank"]) == 1 and int(rows[3]["rank"]) == 4)
	var my_rank: int = _karting.rank_of(pi)
	_check("results panel shown", _hud.results_visible())
	var last: Dictionary = WorldSave.kart_last_result()
	_check("result recorded in WorldSave (rank, 4 racers, total > 0)", int(last.get("rank", 0)) == my_rank and int(last.get("racers", 0)) == 4 and int(last.get("total_ms", 0)) > 0, str(last))
	_check("kart_races stat noted", WorldSave.stats().get("kart_races", 0) == 1)
	_check("player's lap count is LAPS", lap.lap_count >= HubKarting.LAPS)
	var ai_lapped: bool = true
	var ai_best: Array = []
	for r in _karting.racers:
		if r["player"]:
			continue
		var l: KartLap = r["lap"]
		ai_best.append(l.best_lap_ms)
		if l.lap_count < 1 or l.best_lap_ms < 15000 or l.best_lap_ms > 60000:
			ai_lapped = false
	_check("each opponent lapped the real track (best lap 15..60 s)", ai_lapped, str(ai_best))
	print("  race: player rank %d, total %d ms, AI best laps %s, faults %s" % [my_rank, int(_karting.racers[pi]["finish_ms"]), str(ai_best), str([(_karting.racers[1]["driver"] as KartAiDriver).faults_total, (_karting.racers[2]["driver"] as KartAiDriver).faults_total, (_karting.racers[3]["driver"] as KartAiDriver).faults_total])])
	# Persistence of the result.
	WorldSave.save_now()
	WorldSave._data = WorldSave._defaults()
	WorldSave._load()
	_check("result survives a reload", int(WorldSave.kart_last_result().get("rank", 0)) == my_rank)
	# Exit: the opponents go back to the grid, the race is IDLE.
	input.set_all(0.0, 0.0, false)
	_karting.exit_kart()
	for i in 90:
		await get_tree().process_frame
	_check("exit: race IDLE", _karting.race_state == HubKarting.Race.IDLE and not _karting.is_driving())
	var regridded: bool = true
	for i in _karting.racers.size():
		var r: Dictionary = _karting.racers[i]
		if r["player"]:
			continue
		if _flat((r["kart"] as KartBody).global_position).distance_to(track.start_pose(i)["position"]) > 0.05 or r["active"] or (r["kart"] as KartBody).velocity.length() > 0.001:
			regridded = false
	_check("exit: opponents parked on the grid, inactive", regridded)
	_check("exit: results panel hidden", not _hud.results_visible())
	_check("exit: Keepy off the kart", not _keepy.is_on_carrier() and not _keepy.is_hopping())
