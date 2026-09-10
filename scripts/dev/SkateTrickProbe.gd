extends Node
## CH64 -- THE TRICK: a circle in the air is a flip, the same circle on the
## ground is steering, and the landing hands the finger back to steering
## without a swerve.
##
## =====================================================================
## WHAT IS GATED, IN THE ORDER CLAUDE.md DEMANDS (POSITIVE FIRST)
##
## PHASE G -- the recogniser, on the writer alone. A clockwise circle fires
##   ONE clockwise trick; anticlockwise fires the other; three loops fire
##   three; a lumpy circle (+-4 px jitter) still fires; a straight drag, a
##   zigzag, a half-circle and a 270 deg hook fire NOTHING; a 315 deg loop
##   fires (the threshold sits between the hook and the loop). The SENSE
##   is asserted on a circle whose points start at nine o'clock and go up,
##   then right -- clockwise to a viewer, with screen y pointing down --
##   and never read off a comment. And the
##   same circle with the air OFF is steering: no trick, a heading.
## PHASE A -- the air predicate, on the real body. At rest on the lawn,
##   at rest on the funbox deck (the case CH63 named: `airborne()` can
##   flicker there), a hop too short to arm, a hop long enough, and a
##   real launch off the big quarterpipe: `in_air()` answers exactly when
##   it should, and `took_off` / `landed` fire once each per air.
## PHASE L -- the landing cut. A circle drawn in the air fires a trick,
##   does NOT turn the board (its facing is frozen in an armed air), and
##   on contact the anchor is moved under the finger so the board goes
##   straight on rather than into the turn the finger's resting place
##   would have written. The negative: an unarmed hop keeps steering.
## PHASE F -- the flip is drawn: the deck rolls a full turn, the rider's
##   seat does not move with it, and a landing mid-turn finishes the turn
##   fast rather than leaving the deck crooked.
## PHASE H -- the feedback is WIRED, through the real route: the HUD
##   prints the trick's name and the audio player played the right pop,
##   once per trick, and the two senses print two names.
##
## =====================================================================
## HEADLESS, DELIBERATELY. Not one line here reads a pixel or a screen
## point through unproject: the recogniser is arithmetic on screen
## offsets, the air is the physics server, the HUD is a Label's text and
## the audio a player's counter. CLAUDE.md sends a transforms-only probe
## to --headless, where this one renders its verdict in seconds.

const BUDGET_S: float = 600.0
const OPEN_GROUND: Vector3 = Vector3(12.0, 0.0, 52.0)
const NEUTRAL: Vector3 = Vector3(12.0, 0.0, 52.0)
const FINGER: Vector2 = Vector2(540.0, 1300.0)
const CIRCLE_R: float = 60.0
const CIRCLE_STEPS: int = 36

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _transport: HubTransport = null
var _camera: Camera3D = null
var _touch: SkateTouchInput = null
var _hud: SkateHud = null
var _bench: SkateBench = null
var _tricks: Array = []
var _took_off: int = 0
var _landed: int = 0
var _wrote_heading: bool = false

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE TRICK PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_trick_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _run() -> void:
	print("=== SKATE TRICK PROBE -- CH64 ===")
	print("driver: %s" % DisplayServer.get_name())
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	for _i in 24:
		await get_tree().process_frame
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	_camera = _hub.find_child("Camera3D", true, false) as Camera3D
	_hud = _hub.find_child("SkateHud", true, false) as SkateHud
	if _keepy == null or _transport == null or _camera == null or _hud == null:
		push_error("SkateTrickProbe: hub is missing Keepy / Transport / Camera3D / SkateHud.")
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
	_phase_gesture()
	await _phase_air()
	await _phase_landing()
	await _phase_flip()
	await _phase_feedback()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE G -- THE RECOGNISER

## Feeds a path of finger positions to the writer, pressed at the first
## point and released at the last. Returns the tricks it fired, in order.
func _gesture(points: Array, air: bool) -> Array:
	_touch.enabled = true
	_touch.set_air(false)
	_tricks.clear()
	_touch._unhandled_input(_press(points[0]))
	_touch.set_air(air)
	_wrote_heading = false
	# ⚠️ CH65 -- ONE WRITER TICK PER POINT, BECAUSE THE HEADING IS A
	# PER-TICK QUANTITY NOW. The finger is filtered (`SkateTouchInput.
	# FINGER_LAMBDA`) and an event only MOVES it; the tick turns it into a
	# heading. A gesture delivered with no clock between its points writes
	# no heading at all, which read here as "on the ground it was not
	# steering" -- the opposite of the truth.
	#
	# ⚠️ AND THE TRICK ITSELF IS UNAFFECTED BY THE FILTER, WHICH IS THE
	# WHOLE POINT OF THIS PROBE STILL PASSING: `_trace` walks the RAW
	# finger. A filtered path is a SHORTER path and turns through the same
	# angle over fewer segments, so filtering it would have quietly raised
	# the effective TRICK_SWEEP_DEG and started dropping honest circles.
	# Every threshold assertion above and below this line is the evidence
	# that it did not.
	for k in range(1, points.size()):
		_touch._unhandled_input(_drag(points[k]))
		_touch.tick(1.0 / 60.0)
		if _touch.has_heading():
			_wrote_heading = true
	var fired: Array = _tricks.duplicate()
	var heading: bool = _wrote_heading
	_touch._unhandled_input(_release(points[points.size() - 1]))
	_touch.set_air(false)
	_touch.enabled = false
	return [fired, heading]

## A circle of `loops` turns around FINGER + (radius, 0), starting at
## FINGER (its nine o'clock). `clockwise` in the VIEWER'S sense: from nine
## o'clock a clockwise circle goes UP (screen y down, so y decreases) and
## then RIGHT. Asserted on the points themselves in PHASE G.
func _circle(clockwise: bool, loops: float = 1.0, radius: float = CIRCLE_R, jitter: float = 0.0, seed: int = 1, origin: Vector2 = FINGER) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var centre: Vector2 = origin + Vector2(radius, 0.0)
	var points: Array = []
	var n: int = int(ceil(CIRCLE_STEPS * loops))
	for k in n + 1:
		var t: float = TAU * float(k) / float(CIRCLE_STEPS) * (1.0 if clockwise else -1.0)
		var p: Vector2 = centre + Vector2(-cos(t), -sin(t)) * radius
		if jitter > 0.0:
			p += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		points.append(p)
	return points

func _phase_gesture() -> void:
	print("-- PHASE G: the recogniser, on the writer alone --")
	# The sense, first and by construction: from nine o'clock a clockwise
	# circle goes up (y decreases) and then right, which a viewer reads as
	# clockwise. Printed so the claim can be checked against the
	# arithmetic, not only against the assertion.
	var cw: Array = _circle(true)
	print("     clockwise circle starts %s -> %s -> %s (viewer: from nine o'clock, up, then right)"
		% [str(cw[0].round()), str(cw[9].round()), str(cw[18].round())])
	_check(cw[9].y < cw[0].y and cw[18].x > cw[9].x,
		"INSTRUMENT: the 'clockwise' circle really goes up then right on the screen (y down)")
	var r: Array = _gesture(cw, true)
	_check(r[0].size() == 1 and r[0][0] == true,
		"a CLOCKWISE circle in the air fires exactly ONE trick, and it is the clockwise one (%s)" % str(r[0]))
	r = _gesture(_circle(false), true)
	_check(r[0].size() == 1 and r[0][0] == false,
		"an ANTICLOCKWISE circle fires exactly ONE, the other one (%s)" % str(r[0]))
	r = _gesture(_circle(true, 3.0), true)
	_check(r[0].size() == 3,
		"three chained clockwise loops fire THREE tricks (%d)" % r[0].size())
	r = _gesture(_circle(true, 1.0, CIRCLE_R, 4.0, 7), true)
	_check(r[0].size() == 1,
		"a lumpy circle (+-4 px jitter) still fires exactly one (%d)" % r[0].size())
	r = _gesture(_circle(false, 1.0, 40.0, 4.0, 11), true)
	_check(r[0].size() == 1 and r[0][0] == false,
		"a small lumpy anticlockwise circle (r 40) fires one, the right one (%s)" % str(r[0]))
	# The refusals, each a shape a thumb draws while steering.
	var line: Array = []
	for k in 31:
		line.append(FINGER + Vector2(10.0 * k, -3.0 * k))
	r = _gesture(line, true)
	_check(r[0].size() == 0, "a straight 300 px drag fires nothing (%d)" % r[0].size())
	var zig: Array = [FINGER]
	for k in 12:
		zig.append(FINGER + Vector2(60.0 if k % 2 == 0 else 0.0, 12.0 * k))
	r = _gesture(zig, true)
	_check(r[0].size() == 0, "a zigzag fires nothing (%d)" % r[0].size())
	r = _gesture(_circle(true, 0.5), true)
	_check(r[0].size() == 0, "a half-circle fires nothing (%d)" % r[0].size())
	r = _gesture(_circle(true, 0.75), true)
	_check(r[0].size() == 0, "a 270 deg hook fires nothing (%d) -- a hard turn is not a trick" % r[0].size())
	r = _gesture(_circle(true, 0.875), true)
	_check(r[0].size() == 1,
		"a 315 deg loop DOES fire (%d): the threshold (%.0f) sits between the hook and the closed loop"
			% [r[0].size(), SkateTouchInput.TRICK_SWEEP_DEG])
	r = _gesture(_circle(true, 3.0, 4.0), true)
	_check(r[0].size() == 0,
		"a trembling thumb (r 4 px, under the %.0f px segment) fires nothing over three turns (%d)"
			% [SkateTouchInput.TRICK_SEG_PX, r[0].size()])
	# The ground: the same circle is STEERING.
	r = _gesture(cw, false)
	_check(r[0].size() == 0, "the SAME clockwise circle with the air OFF fires nothing (%d)" % r[0].size())
	_check(r[1], "and on the ground it wrote a heading -- it was steering")
	# The published inverse, round-tripped on the live camera: the bench
	# steers by it, so it had better be the writer's own mapping.
	var worst: float = 1.0
	for k in 8:
		var a: float = TAU * float(k) / 8.0
		var h := Vector3(sin(a), 0.0, cos(a))
		_touch.enabled = true
		_touch._unhandled_input(_press(FINGER))
		_touch._unhandled_input(_drag(FINGER + SkateTouchInput.screen_offset_for(_camera, h, 140.0)))
		# CH65: settle the finger filter before reading the heading. 60
		# ticks is far past it, and no world frame is stepped, so the
		# camera basis the round trip is taken through does not move.
		for _t in 60:
			_touch.tick(1.0 / 60.0)
		var back: Vector3 = _touch.heading_world(_camera)
		_touch._unhandled_input(_release(FINGER))
		_touch.enabled = false
		worst = minf(worst, back.dot(h))
	_check(worst > 0.9999,
		"screen_offset_for is the exact inverse of heading_world (worst cos %.6f over 8 headings)" % worst)

# =====================================================================
# PHASE A -- THE AIR PREDICATE

func _park(flat: Vector3, y: float = -1.0) -> void:
	var body := _transport.board_body()
	if _transport.is_riding_board():
		body.stop()
		body.global_position = HubSurface.ground(NEUTRAL)
		_keepy.call("follow_carrier")
		await get_tree().physics_frame
		_transport.leave_board()
		for _i in 20:
			await get_tree().physics_frame
	_keepy.dismount_vehicle()
	body.stop()
	var at: Vector3 = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	if y >= 0.0:
		at.y = y
	body.global_position = at
	body.rotation.y = 0.0
	_keepy.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	for _i in 6:
		await get_tree().physics_frame

## Steps `ticks` and returns how many of them the body reported in_air,
## the highest air_ticks seen, and whether the body ever said airborne().
func _watch(ticks: int) -> Dictionary:
	var body := _transport.board_body()
	var in_air: int = 0
	var airborne: int = 0
	var peak: int = 0
	for _i in ticks:
		await get_tree().physics_frame
		if body.in_air():
			in_air += 1
		if body.airborne():
			airborne += 1
		peak = maxi(peak, body.air_ticks())
	return {"in_air": in_air, "airborne": airborne, "peak": peak}

func _phase_air() -> void:
	print("-- PHASE A: the air predicate, on the real body --")
	var body := _transport.board_body()
	var park := _hub.find_child("Skatepark", true, false) as HubSkatepark
	# (a) at rest on the lawn
	await _park(OPEN_GROUND)
	_check(_transport.mount_board(), "A INSTRUMENT: the rider is aboard")
	var w: Dictionary = await _watch(30)
	_check(int(w["in_air"]) == 0 and int(w["peak"]) == 0,
		"(a) at rest on the lawn: never in the air (peak air ticks %d)" % int(w["peak"]))
	# (b) at rest on the funbox DECK -- the case CH63 named.
	var box: Vector3 = park.module_centre(0)
	var deck_h: float = float(HubSkatepark.MODULES[0]["size"].y)
	await _park(box, deck_h + 0.02)
	_check(_transport.mount_board(), "(b) INSTRUMENT: aboard on the deck")
	w = await _watch(60)
	print("     on the deck for 60 ticks: y %.3f  supported %s  on_module %s  airborne() true on %d ticks  peak air ticks %d"
		% [body.global_position.y, body.supported(), body.on_module(), int(w["airborne"]), int(w["peak"])])
	_check(body.global_position.y > deck_h - 0.05,
		"(b) INSTRUMENT: the board really sits on the deck (y %.3f)" % body.global_position.y)
	_check(int(w["in_air"]) == 0,
		"(b) at rest on the funbox deck: NEVER in the air (airborne() said yes on %d ticks, air ticks peaked at %d)"
			% [int(w["airborne"]), int(w["peak"])])
	# (c) a hop too short to arm, then one long enough -- the dwell is
	# measured, not trusted.
	await _park(OPEN_GROUND)
	_check(_transport.mount_board(), "(c) INSTRUMENT: aboard on the lawn")
	_took_off = 0
	_landed = 0
	body.velocity = Vector3(0.0, 1.0, 0.0)
	w = await _watch(30)
	print("     a 1.0 u/s pop: peak air ticks %d (dwell %d), took_off %d" % [int(w["peak"]), SkateBoardBody.AIR_ARM_TICKS, _took_off])
	_check(int(w["peak"]) > 0 and int(w["peak"]) < SkateBoardBody.AIR_ARM_TICKS,
		"(c) a 1.0 u/s pop leaves the ground for %d ticks -- fewer than the dwell -- and does not arm" % int(w["peak"]))
	_check(int(w["in_air"]) == 0 and _took_off == 0, "(c) so it is not an air: no took_off")
	body.velocity = Vector3(0.0, 4.0, 0.0)
	w = await _watch(40)
	print("     a 4.0 u/s pop: in_air on %d ticks, took_off %d, landed %d" % [int(w["in_air"]), _took_off, _landed])
	_check(int(w["in_air"]) >= 6 and _took_off == 1 and _landed == 1,
		"(c) BLIND: a 4.0 u/s pop IS an air -- took_off once, landed once, in_air for %d ticks" % int(w["in_air"]))
	# (d) a real launch off the big quarterpipe, aimed past the lip.
	var index: int = 2
	var node := park.module_node(index)
	var d: Vector3 = node.global_transform.basis * Vector3(0.0, 0.0, 1.0)
	var dir := Vector3(d.x, 0.0, d.z).normalized()
	var centre: Vector3 = park.module_centre(index)
	await _park(centre - dir * 9.0)
	_check(_transport.mount_board(), "(d) INSTRUMENT: aboard for the launch")
	body.rotation.y = atan2(dir.x, dir.z)
	_took_off = 0
	_landed = 0
	_bench.aim(HubRegion.clamp_to(centre + dir * 4.0))
	var peak_y: float = 0.0
	var air: int = 0
	for _t in 300:
		await get_tree().physics_frame
		peak_y = maxf(peak_y, body.global_position.y)
		if body.in_air():
			air += 1
	_bench.release()
	print("     launch: peak y %.3f, in_air on %d ticks, took_off %d, landed %d" % [peak_y, air, _took_off, _landed])
	_check(peak_y > 1.0, "(d) INSTRUMENT: the run really flew (peak %.3f u)" % peak_y)
	_check(air >= 12 and _took_off >= 1 and _landed == _took_off,
		"(d) a launch off the quarterpipe is an armed air, and every take-off has its landing")

# =====================================================================
# PHASE L -- THE LANDING CUT

func _phase_landing() -> void:
	print("-- PHASE L: a circle in the air does not turn the board, and the landing hands the finger back --")
	var body := _transport.board_body()
	await _park(OPEN_GROUND)
	_check(_transport.mount_board(), "L INSTRUMENT: aboard")
	_transport.board_touch().enabled = true
	_tricks.clear()
	# A finger held straight ahead, then a launch.
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
	_check(armed, "L INSTRUMENT: the launch armed the air")
	var facing_at_takeoff: float = body.rotation.y
	# The circle, drawn in the air, ending with the finger at THREE
	# O'CLOCK of its own anchor -- the place that would mean "hard right"
	# if the landing read it as a heading.
	# ⚠️ THREE POINTS A TICK: a 6 u/s pop stays up 0.46 s (28 ticks) and a
	# thumb's circle takes about that, so the circle is drawn in 12 ticks.
	# The first version drew one point a tick and LANDED mid-circle -- the
	# cut then did exactly its job and the phase read it as "no trick".
	# A loop and a quarter: one trick (the quarter is under the threshold),
	# and the finger comes to rest at TWELVE o'clock of its anchor -- 85 px
	# up-and-right of it, well past the slop -- which is the resting place
	# a landing must NOT read as a heading. A closed loop would end on the
	# anchor and give the cut nothing to cut.
	# Drawn from where the finger IS (a thumb does not teleport to its
	# anchor to start a circle; the segment such a jump would add is
	# turning the recogniser would honestly count).
	var pts: Array = _circle(true, 1.25, CIRCLE_R, 0.0, 1, _touch.finger)
	for k in range(1, pts.size()):
		_touch._unhandled_input(_drag(pts[k]))
		if k % 3 == 0:
			await get_tree().physics_frame
	var finger_offset: Vector2 = _touch.finger - _touch.anchor
	print("     after the circle, in the air: finger is %s from the anchor, heading_px %s, board facing %.4f (took off at %.4f)"
		% [str(finger_offset.round()), str(_touch.heading_px.round()), body.rotation.y, facing_at_takeoff])
	_check(_tricks.size() == 1 and _tricks[0] == true, "L the circle in the air fired one clockwise trick")
	_check(finger_offset.length() > SkateTouchInput.SLOP_PX * 2.0,
		"L INSTRUMENT: the finger really rests off its anchor (%.0f px) -- so the cut below has something to cut" % finger_offset.length())
	_check(absf(angle_difference(facing_at_takeoff, body.rotation.y)) < 0.0001,
		"L in an armed air the board's facing is FROZEN through the circle (%.4f == %.4f)" % [body.rotation.y, facing_at_takeoff])
	# The landing.
	var landed_at: int = -1
	for t in 120:
		await get_tree().physics_frame
		if not body.in_air():
			landed_at = t
			break
	_check(landed_at >= 0, "L INSTRUMENT: it landed (tick %d)" % landed_at)
	print("     at the landing: anchor %s finger %s heading_px %s facing %.4f"
		% [str(_touch.anchor.round()), str(_touch.finger.round()), str(_touch.heading_px.round()), body.rotation.y])
	_check(_touch.anchor.is_equal_approx(_touch.finger) and _touch.heading_px == Vector2.ZERO,
		"L on contact the anchor is moved UNDER the finger: no offset, straight on")
	for _i in 12:
		await get_tree().physics_frame
	_check(absf(angle_difference(facing_at_takeoff, body.rotation.y)) < 0.0001,
		"L and twelve ticks on, the board still points where it landed (%.4f) -- no turn on contact" % body.rotation.y)
	# CH65: 0.99 and not 1.0 -- the ramp is first-order and asymptotic, and
	# by this point in the flight it has long since arrived. PHASE C of
	# SkateInputProbe is what gates the ramp itself.
	_check(_touch.throttle >= 0.99 and body.driving(),
		"L and the finger, still down, is still propelling it (%.4f)" % _touch.throttle)
	# The negative: an UNARMED hop with the finger held to the side keeps
	# steering through the hop.
	_touch._unhandled_input(_drag(_touch.anchor + Vector2(140.0, 0.0)))
	for _i in 6:
		await get_tree().physics_frame
	var before_hop: float = body.rotation.y
	body.velocity.y = 1.0
	var turned: float = 0.0
	for _i in 10:
		await get_tree().physics_frame
		turned = maxf(turned, absf(angle_difference(before_hop, body.rotation.y)))
	_check(turned > 0.01,
		"L NEGATIVE: over an unarmed hop a finger held to the side still steers (turned %.4f rad)" % turned)
	_touch._unhandled_input(_release(_touch.finger))
	for _i in 4:
		await get_tree().physics_frame

# =====================================================================
# PHASE F -- THE FLIP IS DRAWN

func _phase_flip() -> void:
	print("-- PHASE F: the deck rolls, the rider does not --")
	var body := _transport.board_body()
	await _park(OPEN_GROUND)
	_check(_transport.mount_board(), "F INSTRUMENT: aboard")
	var visual := body.find_child("SkateboardMesh", true, false) as Node3D
	_check(visual != null, "F INSTRUMENT: the drawn deck is a child of the body")
	if visual == null:
		return
	var turns_before: int = body.flip_turns()
	var seat_y: float = _keepy.global_position.y
	var z0: float = visual.rotation.z
	body.flip(true)
	var most: float = 0.0
	var seat_drift: float = 0.0
	var ticks_to_done: int = -1
	for t in 60:
		await get_tree().physics_frame
		most = minf(most, visual.rotation.z - z0)
		seat_drift = maxf(seat_drift, absf(_keepy.global_position.y - seat_y))
		if ticks_to_done < 0 and not body.flipping():
			ticks_to_done = t + 1
	print("     kickflip on the ground: deck reached %.3f rad in %d ticks (a turn is %.3f); seat drifted %.4f u"
		% [most, ticks_to_done, -TAU, seat_drift])
	_check(body.flip_turns() == turns_before + 1, "F flip() queued one turn")
	_check(absf(most + TAU) < 0.01, "F the deck rolled exactly one full turn, clockwise sense negative (%.3f)" % most)
	_check(ticks_to_done > 0 and ticks_to_done <= int(ceil(60.0 / (SkateBoardBody.FLIP_RATE * SkateBoardBody.FLIP_LAND_GAIN / TAU))) + 2,
		"F on the ground the turn finishes at the landing rate (%d ticks)" % ticks_to_done)
	_check(seat_drift < 0.0005, "F the rider's seat never moved with the deck (%.4f u)" % seat_drift)
	# Two in the air: a queued second turn, and a landing mid-turn that
	# finishes fast rather than stopping crooked.
	z0 = visual.rotation.z
	body.velocity.y = 4.5
	for _i in 8:
		await get_tree().physics_frame
	body.flip(false)
	body.flip(false)
	var in_air_rate: float = 0.0
	var last: float = visual.rotation.z
	var landed_flipping: bool = false
	for _t in 90:
		await get_tree().physics_frame
		in_air_rate = maxf(in_air_rate, absf(visual.rotation.z - last) * 60.0)
		last = visual.rotation.z
		if not body.in_air() and body.flipping():
			landed_flipping = true
	var total: float = visual.rotation.z - z0
	print("     two heelflips queued in a 0.7 s air: total roll %.3f rad (want %.3f), peak rate %.1f rad/s, still flipping at landing: %s"
		% [total, 2.0 * TAU, in_air_rate, landed_flipping])
	_check(absf(total - 2.0 * TAU) < 0.01, "F two queued turns roll exactly two turns, the other way (positive)")
	_check(not body.flipping(), "F and the deck is upright again (crooked decks are finished, never left)")

# =====================================================================
# PHASE H -- THE FEEDBACK IS WIRED, THROUGH THE REAL ROUTE

func _phase_feedback() -> void:
	print("-- PHASE H: the trick reaches the HUD and the speaker --")
	var body := _transport.board_body()
	var audio := _transport.board_audio()
	_check(audio != null, "H INSTRUMENT: the board has its audio")
	var count_before: int = _transport.trick_count()
	var pops_before: int = audio.flip_count()
	for sense in [true, false]:
		await _park(OPEN_GROUND)
		_check(_transport.mount_board(), "H INSTRUMENT: aboard")
		_touch._unhandled_input(_press(FINGER))
		_touch._unhandled_input(_drag(FINGER + Vector2(0.0, -140.0)))
		for _i in 6:
			await get_tree().physics_frame
		body.velocity.y = 6.0
		for _i in 20:
			await get_tree().physics_frame
			if body.in_air():
				break
		_hud.visible = false
		var pts: Array = _circle(sense, 1.0, CIRCLE_R, 0.0, 1, _touch.finger)
		for k in range(1, pts.size()):
			_touch._unhandled_input(_drag(pts[k]))
			if k % 3 == 0:
				await get_tree().physics_frame
		var name: String = String(HubTransport.TRICK_CLOCKWISE if sense else HubTransport.TRICK_ANTICLOCKWISE).to_upper()
		print("     %s: HUD '%s' visible=%s, pops %d, last stream %s"
			% [name, _hud.trick_text(), _hud.visible, audio.flip_count() - pops_before, audio.last_flip_stream().get_file()])
		_check(_hud.visible and _hud.trick_text() == name,
			"H the HUD prints %s" % name)
		_check(audio.last_flip_stream() == (SkateAudio.FLIP_KICK_STREAM if sense else SkateAudio.FLIP_HEEL_STREAM),
			"H and the speaker played the %s pop" % ("kick" if sense else "heel"))
		_touch._unhandled_input(_release(_touch.finger))
		for _i in 60:
			await get_tree().physics_frame
	_check(_transport.trick_count() == count_before + 2, "H two tricks were counted by the transport (%d)" % (_transport.trick_count() - count_before))
	_check(audio.flip_count() == pops_before + 2, "H and two pops were played, one each")
	await _park(NEUTRAL)

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
