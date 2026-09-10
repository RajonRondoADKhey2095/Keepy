extends Node
## CH58 / CH64 -- THERE IS ALWAYS A WAY OFF THE BOARD.
##
## =====================================================================
## WHAT THIS PROBE EXISTS TO GATE
##
## CH57 shipped a board Mathieu could climb onto and then never leave: on
## device, every tap made while riding did nothing at all. CH58 found the
## branch order in HubWorld and wrote this bench to hold the ROUTING axis
## -- every tap delivered through the real signal on the real node, and
## what is asserted is what the WORLD did about it. CLAUDE.md names the
## defect: the PATRON ECHELLE, a player sealed inside a prop that eats
## every one of his taps.
##
## CH64 changed what the way off IS, not whether there must be one. The
## TAP scheme (a tap on his own body at rest) went with the toggles; the
## board is piloted by a held finger and its exit is a SHORT TAP AT REST,
## anywhere, read by SkateTouchInput and gated by HubTransport on the
## board being still at the PRESS. So this bench now asks the CH58
## question of the CH64 exit, in the same four places the brief named
## then (open ground, rolling, jammed against a module, up on a module),
## and adds the one CH64 introduces: mid-AIR.
##
## Every gesture below reaches the writer as the engine delivers it (an
## InputEventScreenTouch pressed then released -- SkateBench.tap), and
## PHASE X goes one link further, through `Input.parse_input_event`, so
## both listeners get their real chance in the tree's own order.
##
## =====================================================================
## AND IT RUNS HEADLESS -- except PHASE X, which cannot
##
## Nothing here reads a pixel or unprojects a screen point except PHASE X,
## which needs a real container rect to prove a screen tap is SHUNTED
## while riding (HubTapInput returns before projecting in headless and the
## shunt would pass by never running). It says so and reports rather than
## passing quietly.

const BUDGET_S: float = 900.0
const OPEN_GROUND: Vector3 = Vector3(12.0, 0.0, 52.0)
const NEUTRAL: Vector3 = Vector3(12.0, 0.0, 52.0)
const AIM_AWAY: Vector3 = Vector3(12.0, 0.0, 44.0)
const PUBLISHED_DIAGONAL_HOPS: int = 66
const PUBLISHED_DIAGONAL_S: float = 18.700
const CROSSING_BUDGET_S: float = 22.0

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _transport: HubTransport = null
var _park: HubSkatepark = null
var _tap: HubTapInput = null
var _camera: Camera3D = null
var _bench: SkateBench = null
var _ground_taps: int = 0
var _exit_taps: int = 0
var _hops: int = 0

func _on_landed(_p: Vector3) -> void:
	_hops += 1

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE DISMOUNT PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_dismount_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _run() -> void:
	print("=== SKATE DISMOUNT PROBE -- CH58 / CH64 ===")
	print("driver: %s" % DisplayServer.get_name())
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	for _i in 24:
		await get_tree().process_frame
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	_park = _hub.find_child("Skatepark", true, false) as HubSkatepark
	_tap = _hub.find_child("TapInput", true, false) as HubTapInput
	_camera = _hub.find_child("Camera3D", true, false) as Camera3D
	if _keepy == null or _transport == null or _park == null or _tap == null or _camera == null:
		push_error("SkateDismountProbe: hub is missing Keepy / Transport / Skatepark / TapInput / Camera3D.")
		get_tree().quit(1)
		return
	_bench = SkateBench.new()
	_bench.name = "Bench"
	add_child(_bench)
	_bench.setup(_transport, _camera)
	_tap.tapped_ground.connect(func(_p: Vector3) -> void: _ground_taps += 1)
	_transport.board_touch().tapped.connect(func() -> void: _exit_taps += 1)
	await _phase_instrument()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every result below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_state()
	await _phase_steer()
	await _phase_dismount()
	await _phase_anywhere()
	await _phase_air()
	await _phase_screen()
	await _phase_traversal()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE I -- THE INSTRUMENT, POSITIVE FIRST
#
# CLAUDE.md's blind check, and it is not optional here. Every assertion
# below is of the form "the tap DID something", whose negation -- nothing
# happened -- is exactly what a bench wired to nothing also reports. So
# the bench is first shown answering YES on foot, where the shipped game
# has always worked.

func _phase_instrument() -> void:
	print("-- PHASE I: the bench can SEE a tap take effect (on foot, where it always worked) --")
	_keepy.dismount_vehicle()
	await _idle_hopper()
	_keepy.global_position = HubSurface.ground(OPEN_GROUND)
	await _settle(6)
	_check(not _keepy.is_hopping(), "INSTRUMENT: he stands still on open ground")
	_tap.tapped_ground.emit(HubRegion.clamp_to(AIM_AWAY))
	await _settle(4)
	_check(_keepy.is_hopping(), "INSTRUMENT: a real tapped_ground on foot starts a walk")
	await _idle_hopper()

# =====================================================================
# PHASE S -- THE PREMISE

func _phase_state() -> void:
	print("-- PHASE S: the premise -- a board ride IS an ON_CARRIER ride, and the writer is armed --")
	await _park_board(OPEN_GROUND)
	var mounted: bool = _transport.mount_board()
	await _settle(6)
	_check(mounted, "mount_board() took him aboard")
	_check(_transport.is_riding_board(), "the transport says he is riding the board")
	_check(_keepy.is_on_carrier(),
		"and the HOPPER is in ON_CARRIER -- the same state the balloon drops taps from")
	_check(_transport.board_touch().enabled, "and the finger writer is ARMED by the mount alone (CH64: no scheme to select)")

# =====================================================================
# PHASE R -- A HELD FINGER STEERS

func _phase_steer() -> void:
	print("-- PHASE R: a held finger away from him STEERS the board --")
	await _remount(OPEN_GROUND)
	var body := _transport.board_body()
	_check(body != null, "INSTRUMENT: the board is a physics body")
	_check(not body.driving(), "INSTRUMENT: nobody commands it yet (else the check below is free)")
	var before: Vector3 = body.flat_position()
	_bench.aim(HubRegion.clamp_to(AIM_AWAY))
	await _settle(4)
	_check(body.driving(), "the finger reached the board: it is being pushed")
	_check(_transport.is_riding_board(), "and it steered rather than ejecting him at speed")
	await _settle(30)
	var moved: float = body.flat_position().distance_to(before)
	print("     rolled %.3f u in 34 ticks" % moved)
	_check(moved > 0.05, "and the board actually rolled (%.3f u)" % moved)
	_bench.release()

# =====================================================================
# PHASE D -- A SHORT TAP AT REST PUTS HIM DOWN

func _phase_dismount() -> void:
	print("-- PHASE D: a short tap, at rest, PUTS HIM DOWN --")
	await _remount(OPEN_GROUND)
	var body := _transport.board_body()
	_check(body.at_rest(), "INSTRUMENT: the board is at rest under him")
	var here: Vector3 = _flat(_keepy.global_position)
	var off: bool = await _tap_exit()
	_check(off, "a short tap dismounted him")
	_check(not _transport.is_riding_board(), "the transport no longer holds him")
	_check(not _keepy.is_on_carrier(), "and the hopper is out of ON_CARRIER")
	_check(not _transport.board_touch().enabled, "and the writer is disarmed with the ride")
	print("     stepped off %.3f u from where the board stands" % _flat(_keepy.global_position).distance_to(here))
	# The routing is HANDED BACK -- the half of the bug that is not the
	# dismount itself. A dismount that left the world thinking he was
	# aboard would swallow the very next tap in the same way.
	await _idle_hopper()
	_tap.tapped_ground.emit(HubRegion.clamp_to(AIM_AWAY))
	await _settle(4)
	_check(_keepy.is_hopping(), "and the NEXT tap is an ordinary walk again")
	await _idle_hopper()

# =====================================================================
# PHASE A -- WHEREVER THE BOARD IS

func _phase_anywhere() -> void:
	print("-- PHASE A: the exit works WHEREVER the board stands --")
	# (1) parked, untouched, nowhere near a module
	await _remount(OPEN_GROUND)
	_check(await _tap_exit(), "(1) open ground, standing still -- he gets off")
	# (2) rolling. A tap mid-roll is a few ticks of push and NOT an exit
	# (CH58's rule, kept: a brush of the glass at 10 u/s must not eject
	# him); the guarantee is that a rider is never more than one further
	# tap from the ground once the board has stopped.
	await _remount(OPEN_GROUND)
	var body := _transport.board_body()
	body.velocity = Vector3(0.0, 0.0, -HubTransport.SKATE_CRUISE)
	await _settle(2)
	_check(body.speed() > body.rest_speed() * 4.0, "(2) INSTRUMENT: it is genuinely rolling (%.3f u/s)" % body.speed())
	var exits_before: int = _exit_taps
	var ejected: bool = await _tap_exit()
	_check(_exit_taps > exits_before, "(2) INSTRUMENT: the gesture was read as an exit tap")
	_check(not ejected, "(2) a tap MID-ROLL does not eject him at speed")
	_check(_transport.is_riding_board(), "(2) and he is still aboard")
	var freed: bool = false
	for _i in 60:
		await _settle(12)
		if _transport.board_at_rest():
			freed = await _tap_exit()
			break
	_check(freed, "(2) and once it has come to rest the next tap puts him down")
	# (3) pressed into the funbox's vertical east face under a held
	# finger. CH42's stall: a body that cannot move. The finger lifts (a
	# player's does; the bench's guard does the same), and the tap that
	# follows must get him off.
	await _remount(_side_of_funbox())
	_bench.aim(HubRegion.clamp_to(_flat(_park.module_centre(0))))
	for _i in 150:
		await get_tree().physics_frame
		if _bench.stalled_out():
			break
	_bench.release()
	await _settle(6)
	print("     (3) into the east face: at_rest=%s supported=%s bench stalled=%s"
		% [_transport.board_at_rest(), _transport.board_body().supported(), _bench.stalled_out()])
	_check(_transport.board_at_rest(), "(3) INSTRUMENT: jammed against the face it is at rest, so a tap is readable as an exit")
	_check(await _tap_exit(), "(3) jammed against the funbox -- he still gets off")
	# (4) standing ON the funbox deck. Placed there (SkateTrickProbe PHASE
	# A proves a board placed on the deck rests on it): what the brief
	# asks is that the exit works UP THERE, not how it got up there -- a
	# finger has no brake, so a ride onto a 1.8 u deck cannot be made to
	# stop on it by a bench any more than by a player.
	var deck: Dictionary = await _stand_on_deck()
	print("     (4) on the deck: y %.3f (deck top %.3f)  supported=%s  on_module=%s  at_rest=%s"
		% [float(deck["y"]), float(deck["deck_h"]), deck["supported"], deck["on_module"], deck["at_rest"]])
	if not bool(deck["on_deck"]):
		_check(false, "(4) INSTRUMENT: the board should be resting on the module")
		return
	_check(await _tap_exit(), "(4) up on the funbox deck -- he still gets off")

# =====================================================================
# PHASE F -- MID-AIR: THE ONE PLACE CH64 ADDS
#
# A finger in the air is a trick pad, and a short tap in the air is by
# construction not at rest: it must NOT eject a rider at the top of a
# quarterpipe, and it must not be swallowed either -- it is a few ticks of
# throttle, and the exit is one tap away once the board has landed and
# stopped. The positive is shown first: the board really flew.

func _phase_air() -> void:
	print("-- PHASE F: a tap in mid-air is not an exit; the exit is one tap away after the landing --")
	await _remount(OPEN_GROUND)
	var body := _transport.board_body()
	body.velocity = Vector3(0.0, 6.0, -4.0)
	var armed: bool = false
	for _i in 20:
		await get_tree().physics_frame
		if body.in_air():
			armed = true
			break
	_check(armed, "F INSTRUMENT: the board is in an armed air")
	var exits_before: int = _exit_taps
	var ejected: bool = await _tap_exit()
	_check(_exit_taps > exits_before, "F INSTRUMENT: the gesture was read")
	_check(not ejected and _transport.is_riding_board(), "F a tap in mid-air does NOT put him down")
	var landed: bool = false
	for _i in 60:
		await _settle(12)
		if _transport.board_at_rest():
			landed = true
			break
	_check(landed, "F INSTRUMENT: the board landed and came to rest")
	_check(await _tap_exit(), "F and the next tap at rest puts him down -- never more than one tap from the ground")

# =====================================================================
# PHASE X -- FROM A REAL SCREEN POINT, THROUGH THE REAL ROUTER
#
# Everything above enters at the writer. This phase starts where the
# finger does -- a container pixel, through `Input.parse_input_event`,
# with BOTH listeners live -- and proves the ROUTING half: while riding,
# HubTapInput must SHUNT the point (one finger, one meaning) and the
# writer must read it; on foot the shipped route must have it back.

func _phase_screen() -> void:
	print("-- PHASE X: from a real SCREEN POINT, through the real router --")
	if DisplayServer.get_name() == "headless" or not _screen_is_real():
		print("     SKIPPED: the dummy driver dispatches no input and projects nothing, so this")
		print("     phase would pass by never running. Run under xvfb-run --rendering-driver opengl3 to sign it.")
		return
	await _remount(OPEN_GROUND)
	await _settle_camera()
	var rect: Rect2 = _tap.container.get_global_rect()
	var at: Vector2 = rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.55)
	var ground_before: int = _ground_taps
	var exits_before: int = _exit_taps
	Input.parse_input_event(_press(at))
	await _settle(2)
	Input.parse_input_event(_release(at))
	await _settle(10)
	_check(_ground_taps == ground_before, "X while riding, a screen tap does NOT reach tapped_ground (shunted)")
	_check(_exit_taps > exits_before, "X and the writer read it as the exit gesture")
	_check(not _transport.is_riding_board(), "X and, at rest, it put him down")
	await _idle_hopper()
	await _settle_camera()
	ground_before = _ground_taps
	Input.parse_input_event(_press(at))
	await _settle(2)
	Input.parse_input_event(_release(at))
	await _settle(8)
	_check(_ground_taps > ground_before, "X on foot the same screen tap reaches tapped_ground again (x%d)" % (_ground_taps - ground_before))
	await _idle_hopper()

# =====================================================================
# PHASE T -- THE CEILING, RE-WALKED

func _phase_traversal() -> void:
	print("-- PHASE T: the published diagonal, re-walked with the physics world live --")
	if _transport.is_riding_board():
		_transport.leave_board()
		await _settle(30)
	_keepy.dismount_vehicle()
	await _idle_hopper()
	await _settle(10)
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	_keepy.global_position = HubSurface.ground(Vector3(-h, 0.0, -h))
	await _settle(6)
	# A member and a method, never a lambda: CLAUDE.md, a lambda captures
	# a local BY VALUE and the count stays at zero (this probe paid it).
	_hops = 0
	_keepy.hop_landed.connect(_on_landed)
	var frames: int = 0
	_keepy.hop_to(Vector3(h, 0.0, h))
	while _keepy.is_hopping() and frames < 3000:
		await get_tree().physics_frame
		frames += 1
	_keepy.hop_landed.disconnect(_on_landed)
	var seconds: float = float(frames) / 60.0
	print("     diagonal: %d hops in %d frames (%.3f s); published %d hops / %.3f s"
		% [_hops, frames, seconds, PUBLISHED_DIAGONAL_HOPS, PUBLISHED_DIAGONAL_S])
	_check(_hops == PUBLISHED_DIAGONAL_HOPS and absf(seconds - PUBLISHED_DIAGONAL_S) < 0.02,
		"T the published diagonal is reproduced to the frame")
	_check(seconds <= CROSSING_BUDGET_S, "T and it stays under the %.0f s ceiling" % CROSSING_BUDGET_S)

# =====================================================================
# HELPERS

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)

func _settle(ticks: int) -> void:
	for _i in ticks:
		await get_tree().physics_frame

func _idle_hopper() -> void:
	for _i in 900:
		if not _keepy.is_hopping():
			return
		await get_tree().physics_frame

func _screen_is_real() -> bool:
	if _tap.container == null or _tap.viewport == null:
		return false
	var rect: Rect2 = _tap.container.get_global_rect()
	return rect.size.x > 0.0 and rect.size.y > 0.0 and _tap.viewport.size.x > 0

func _settle_camera() -> void:
	var last: Transform3D = _camera.global_transform
	var stable: int = 0
	for _i in 480:
		await get_tree().physics_frame
		var now: Transform3D = _camera.global_transform
		var blend: float = _camera.call("drive_blend") if _camera.has_method("drive_blend") else 0.0
		if (blend < 0.001 or blend > 0.999) and now.origin.distance_to(last.origin) < 0.0005 \
				and (now.basis.z - last.basis.z).length() < 0.0002:
			stable += 1
			if stable >= 8:
				return
		else:
			stable = 0
		last = now

## Puts the board down flat at `flat`, nobody on it, no command and no
## velocity carried over. The dismount happens at NEUTRAL, never where the
## ride ended: a step-off landing is offered to every hotspot HubWorld
## holds (SkatePhysicsProbe's measured seesaw defect).
func _park_board(flat: Vector3) -> void:
	var body := _transport.board_body()
	_bench.release()
	if _transport.is_riding_board():
		body.stop()
		body.global_position = HubSurface.ground(NEUTRAL)
		_keepy.call("follow_carrier")
		await get_tree().physics_frame
		_transport.leave_board()
		await _settle(20)
	_keepy.dismount_vehicle()
	await _idle_hopper()
	body.stop()
	body.global_position = HubSurface.ground(_flat(flat))
	body.rotation.y = 0.0
	_keepy.global_position = HubSurface.ground(_flat(flat))
	await _settle(6)

func _remount(flat: Vector3) -> void:
	await _park_board(flat)
	if not _transport.mount_board():
		_check(false, "INSTRUMENT: mount_board() refused at %s" % str(flat))
	await _settle(6)

## The exit gesture through the writer: a press and a release with no
## slide. Returns true if he is off the board afterwards.
func _tap_exit() -> bool:
	_bench.tap()
	await _settle(10)
	return not _transport.is_riding_board()

func _side_of_funbox() -> Vector3:
	var half_x: float = float(HubSkatepark.MODULES[0]["size"].x) * 0.5
	var box: Vector3 = _park.module_centre(0)
	return Vector3(box.x + half_x + 3.0, 0.0, box.z)

## Puts the board and the rider on the funbox deck and lets them settle.
func _stand_on_deck() -> Dictionary:
	var centre: Vector3 = _park.module_centre(0)
	var deck_h: float = float(HubSkatepark.MODULES[0]["size"].y)
	await _park_board(centre)
	var body := _transport.board_body()
	body.global_position = Vector3(centre.x, deck_h + 0.02, centre.z)
	_keepy.global_position = body.global_position + Vector3(0.0, SkateparkMesh.DECK_TOP, 0.0)
	await _settle(6)
	if not _transport.mount_board():
		_check(false, "(4) INSTRUMENT: mount_board() refused on the deck")
	await _settle(30)
	return {"y": body.global_position.y, "deck_h": deck_h, "supported": body.supported(),
		"on_module": body.on_module(), "at_rest": body.at_rest(),
		"on_deck": body.on_module() and body.global_position.y > deck_h - 0.05 and body.at_rest()}

## (Kept for a bench that wants the ride itself.) Rides up the funbox
## ramp toward its deck under a short push and a coast.
func _ride_onto_deck() -> Dictionary:
	var node := _park.module_node(0)
	var centre: Vector3 = _park.module_centre(0)
	var d: Vector3 = node.global_transform.basis * Vector3(0.0, 0.0, 1.0)
	var dir := Vector3(d.x, 0.0, d.z).normalized()
	var deck_h: float = float(HubSkatepark.MODULES[0]["size"].y)
	await _remount(centre + dir * 6.5)
	var body := _transport.board_body()
	body.rotation.y = atan2(-dir.x, -dir.z)
	# A short push toward the deck, then a lift: the coast carries it up
	# the ramp and it stops on top (a held finger would carry it over).
	_bench.hold(-dir)
	for _i in 22:
		await get_tree().physics_frame
	_bench.release()
	var on_deck: bool = false
	for _i in 60:
		await _settle(6)
		var local: Vector3 = node.global_transform.affine_inverse() * body.global_position
		var half_z: float = float(HubSkatepark.MODULES[0]["size"].z) * 0.5
		if _transport.board_at_rest():
			on_deck = body.global_position.y > deck_h - 0.05 and absf(local.z) < half_z
			break
	return {"y": body.global_position.y, "deck_h": deck_h, "supported": body.supported(), "on_deck": on_deck}

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
