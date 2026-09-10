extends Node
## CH63 LOT 2 -- THE CONTINUOUS THROTTLE, AND THE PROOF THAT THE OLD ROUTE
## IS SHUT.
##
## =====================================================================
## ⚠️ WHAT LOT 1 GATED, AND WHY HALF OF IT IS GONE
##
## LOT 1 gated "a held drag writes a heading, a short tap emits a PUSH",
## and the push half was a mis-reading of the brief -- Mathieu wants no
## repeated tapping at all. So every assertion about `pushed` in this file
## is CADUQUE, and they have been rewritten rather than deleted: the
## gesture that survives on the same threshold is the EXIT (a short tap
## gets off), and the propulsion is now the finger's own presence.
##
## The contract this probe gates, in four lines:
##
##   * a finger DOWN holds `throttle` at 1.0, from the press, before any
##     heading exists;
##   * a finger SLID writes a heading that TRACKS it -- including back
##     inside the slop, where the heading returns to zero and the board
##     goes straight on;
##   * a finger LIFTED drops the throttle and leaves the velocity alone;
##   * a short tap that never left the slop is the EXIT, gated on the
##     board being at rest.
##
## ⚠️ THE EXIT IS NOT A LEFTOVER OF THE PUSH -- IT CLOSES A HOLE LOT 1
## SHIPPED. HubTapInput short-circuits every point under the drag scheme,
## and the shipped dismount lives BELOW that short-circuit, so LOT 1 left
## a rider with no way off the board at all: CLAUDE.md's PATRON ECHELLE,
## banned outright. PHASE R gates the exit from both sides.
##
## =====================================================================
## WHAT THIS PROBE GATES, AND WHY EACH HALF IS NEEDED
##
## Two things have to be true, and only one of them is about the new code:
##
##   1. THE CAPTURE WORKS -- a held finger propels the board in the
##      direction the finger actually points, and a tap does not;
##   2. THE OLD ROUTE IS SHUT WHILE IT DOES -- one finger, one meaning.
##      CH57's tap branch in HubWorld._on_tapped_ground is still there and
##      still correct; if it stayed REACHABLE under the drag scheme, a
##      single screen tap would be both a push and a destination, and the
##      A/B Mathieu is being asked to judge would be comparing the tap
##      scheme against the tap scheme PLUS a drag.
##
## ⚠️ (2) IS AN ASSERTION OF ABSENCE, so it is written the only way
## CLAUDE.md allows one to be written: the bench is first shown the tap
## ARRIVING, on the same board, through the same events, with the drag
## scheme OFF (PHASE I). Only then is it shown not arriving with the drag
## scheme on (PHASE R). Without the first half, "nothing happened" and
## "the bench is wired to nothing" are the same reading -- and this repo
## has seventeen faux-verts on file that were exactly that.
##
## =====================================================================
## AND THE MAPPING IS CONFIRMED IN PIXELS, NOT IN ARITHMETIC
##
## PHASE M is the one phase that must RENDER. CLAUDE.md: "un mot de
## convention de cote ne vaut rien sans une capture" -- the hub camera's
## yaw reads 0 in the scene file, and a heading mapping written from that
## reading would be right today and silently mirrored the first time a lot
## yaws the camera. So the mapping is derived from the LIVE camera basis
## in SkateTouchInput.heading_world(), and PHASE M checks the RESULT the
## way a player checks it: drag toward the right of the screen, and watch
## the board's DRAWN position move toward the right of the screen.
##
## It therefore needs a real viewport, and it asserts that it has one
## rather than passing by never running -- CLAUDE.md's dummy-driver rule.
## Run it under `xvfb-run --rendering-driver opengl3`; run it headless and
## PHASE M reddens instead of going quietly green.

const BUDGET_S: float = 900.0

## Where every ride below happens: SkateDismountProbe's own OPEN_GROUND,
## read from that file's published reason rather than re-chosen. Due east
## of the whole skatepark, inside the skate lobe, `HubRegion.clamp_to` is
## the identity on it, and it is clear of the seesaw's landing disc -- a
## walk that ends on a prop leaves a state `mount_carrier` refuses, and
## every "he is aboard" assertion downstream would then pass for free.
const OPEN_GROUND: Vector3 = Vector3(12.0, 0.0, 52.0)

## HubWorld's own self-tap radius, restated so a change to it reddens this
## probe rather than silently moving what the gesture means.
const SELF_TAP_RADIUS: float = 0.9

## How long a held drag is given, in physics frames. 1 s at 60.
##
## ⚠️ MEASURED DOWN FROM 3 s, AND THE LONGER RUN WAS THE DEFECT. At 180
## frames the board covers 16.4 u, and from OPEN_GROUND that reaches the
## skate lobe's own border (centre (0, 35), radius 28): `_fence` refuses
## the step, clears the target and the board slides along the edge, so the
## net displacement stops pointing where the finger did -- cos 0.858
## against a mapping that was correct. The phase was measuring the REGION.
##
## 60 frames covers ~7 u, which is past the SKATE_ACCEL_U = 3.2 u run-up
## (so cruise is still reached and the lead is still gated) and leaves at
## least 2.5 u of lobe in every direction from the station. PHASE D
## asserts the board is still inside the region at the end, so a later lot
## that moves the station or the lobe reddens here instead of quietly
## measuring a wall again.
const DRAG_FRAMES: int = 60

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _transport: HubTransport = null
var _tap: HubTapInput = null
var _touch: SkateTouchInput = null
var _camera: Camera3D = null
## Set by the real HubTapInput signal, so "the old route fired" is read
## off the shipped channel and not inferred from a side effect.
var _ground_taps: int = 0
## Set by the writer's own signal: how many times the EXIT gesture fired.
var _taps: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE INPUT PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_input_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _run() -> void:
	print("=== SKATE INPUT PROBE -- CH63 LOT 2 ===")
	print("driver: %s" % DisplayServer.get_name())
	DevTools.set_physics_override(true)
	SkateTouchInput.set_drag_mode(false)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	for _i in 24:
		await get_tree().process_frame
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	_tap = _hub.find_child("TapInput", true, false) as HubTapInput
	_camera = _hub.find_child("Camera3D", true, false) as Camera3D
	if _keepy == null or _transport == null or _tap == null or _camera == null:
		push_error("SkateInputProbe: hub is missing Keepy / Transport / TapInput / Camera3D.")
		get_tree().quit(1)
		return
	_touch = _transport.board_touch()
	if _touch == null:
		push_error("SkateInputProbe: the transport built no board input writer.")
		get_tree().quit(1)
		return
	_tap.tapped_ground.connect(func(_p: Vector3) -> void: _ground_taps += 1)
	_touch.tapped.connect(func() -> void: _taps += 1)
	await _phase_instrument()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every result below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_capture()
	await _phase_arming()
	await _phase_shunt()
	await _phase_emulated()
	await _phase_drive()
	await _phase_fence()
	await _phase_mapping()
	await _phase_off()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE I -- THE BENCH CAN SEE THE SHIPPED TAP ARRIVE
#
# Positive first, and it is the whole licence for PHASE R. Every event
# below is delivered through `Input.parse_input_event` -- the real engine
# pipeline into the real nodes -- rather than by calling a handler, so
# what is measured is the ROUTING and not one file's arithmetic. That is
# CH58's lesson: CH57's 43 assertions were green over a shipped dead
# input path because its bench called `set_board_target()` directly and
# never once went through the listener a finger goes through.

func _phase_instrument() -> void:
	print("-- PHASE I: with the TAP scheme selected, a screen tap still arrives --")
	_check(not SkateTouchInput.drag_enabled(), "INSTRUMENT: the probe starts on the SHIPPED scheme")
	await _board_at(OPEN_GROUND)
	_check(_transport.is_riding_board(), "INSTRUMENT: he is aboard the physics board")
	_check(not _touch.enabled, "INSTRUMENT: the drag writer is NOT armed under the tap scheme")
	if not _screen_is_real():
		_check(false, "INSTRUMENT: no real viewport -- every screen event below would be dropped")
		return
	await _settle_camera()
	var aim: Vector2 = _screen_ahead()
	_check(_tap.container.get_global_rect().has_point(aim),
		"INSTRUMENT: the aim pixel %s is inside the container" % str(aim.round()))
	var before: int = _ground_taps
	await _screen_tap(aim)
	# ⚠️ ">" AND NOT "== +1". One physical tap produces TWO events on this
	# engine -- the touch and the mouse Godot synthesises from it -- and
	# HubTapInput reads both, so the shipped route fires twice per finger.
	# That is CLAUDE.md's documented double dispatch, it predates this lot
	# by years, and gating it here would make this probe fail on shipped
	# behaviour it is not measuring. What this lot's own writer does about
	# the same pair IS gated, in PHASE R: exactly one push.
	_check(_ground_taps > before,
		"a screen tap while riding reaches HubTapInput.tapped_ground (the shipped route is LIVE, x%d)"
			% (_ground_taps - before))
	_check(_transport.board_has_destination(),
		"and the world turned it into a destination for the board")

# =====================================================================
# PHASE C -- WHAT THE WRITER CAPTURES
#
# The throttle, the heading, and the one threshold that separates a drag
# from the exit tap. Both sides of that threshold are asserted, because a
# threshold checked from one side only is a threshold that can have
# drifted to zero or to infinity without anything reporting it.
#
# ⚠️ AND THE THROTTLE IS ASSERTED ON THE PRESS, BEFORE ANY HEADING EXISTS.
# That ordering IS the contract: a scheme that waited for a heading before
# propelling would make the first millimetre of every gesture dead, and a
# player who presses and holds without sliding -- which is what "go
# straight" looks like -- would get nothing at all. An assertion taken
# after the first drag event could not tell the two apart.

func _phase_capture() -> void:
	print("-- PHASE C: a held finger is a throttle, a slid finger is a heading --")
	_touch.enabled = true
	var at := Vector2(500.0, 900.0)
	_check(is_zero_approx(_touch.throttle), "INSTRUMENT: no finger, no throttle")
	# (1) the press alone
	_touch._unhandled_input(_press(at))
	_check(_touch.throttle >= 1.0,
		"the PRESS alone opens the throttle (%.2f), before any heading" % _touch.throttle)
	_check(not _touch.has_heading(), "and it writes no heading yet")
	# (2) a slide well past the slop
	_touch._unhandled_input(_drag(at + Vector2(120.0, 0.0)))
	_check(_touch.has_heading(), "a 120 px slide writes a heading")
	_check(_touch.heading_px.x > 0.0 and absf(_touch.heading_px.y) < 0.001,
		"and the heading is the finger's own offset (%s)" % str(_touch.heading_px))
	_check(_touch.throttle >= 1.0, "the throttle is still held through the slide")
	# (3) IT TRACKS -- the LOT 1 latch is gone, and this is the assertion
	# that says so. A finger swung to the other side must write the other
	# side, or "la direction suit la position du doigt" is not true.
	_touch._unhandled_input(_drag(at + Vector2(-120.0, 0.0)))
	_check(_touch.heading_px.x < 0.0,
		"swinging the finger the other way writes the OTHER heading (%s) -- it tracks"
			% str(_touch.heading_px))
	# (4) and back inside the slop is "straight on", not "stop"
	_touch._unhandled_input(_drag(at + Vector2(3.0, 2.0)))
	_check(not _touch.has_heading(),
		"a finger back inside the %.0f px slop writes NO heading" % SkateTouchInput.SLOP_PX)
	_check(_touch.throttle >= 1.0,
		"and the throttle is UNTOUCHED by that -- straight on, not stop (%.2f)" % _touch.throttle)
	# (5) the release
	var taps_before: int = _taps
	_touch._unhandled_input(_release(at + Vector2(3.0, 2.0)))
	_check(is_zero_approx(_touch.throttle), "the release closes the throttle")
	_check(not _touch.has_heading(), "and drops the heading with the finger")
	# ⚠️ (5) IS A DRAG THAT ENDED INSIDE THE SLOP, and it is deliberately
	# not an exit: `_dragged` latches for the length of the gesture even
	# though the heading does not. Two different questions, two different
	# memories, and this is the assertion that proves they are separate.
	_check(_taps == taps_before,
		"a gesture that once LEFT the slop is not an exit tap, even if it came back")
	# (6) the exit gesture itself
	taps_before = _taps
	_touch._unhandled_input(_press(at))
	_touch._unhandled_input(_drag(at + Vector2(4.0, 3.0)))
	_check(not _touch.has_heading(), "a 5 px jitter writes NO heading")
	_touch._unhandled_input(_release(at + Vector2(4.0, 3.0)))
	_check(_taps == taps_before + 1, "and releasing it emits exactly ONE exit tap")
	_touch.enabled = _transport.is_riding_board() and SkateTouchInput.drag_enabled()

# =====================================================================
# PHASE A -- ARMING, AND THE ONE CALL THAT DOES IT
#
# The writer must be armed exactly when the scheme is DRAG and a rider is
# aboard, and at no other time -- including the window inside
# `leave_board()`, where an event arriving mid-step-off would otherwise
# plant a destination on a board nobody is riding.

func _phase_arming() -> void:
	print("-- PHASE A: mount / leave / the live toggle all arm the same one flag --")
	_check(_transport.is_riding_board(), "INSTRUMENT: still aboard from PHASE I")
	_check(not _touch.enabled, "tap scheme + riding  -> NOT armed")
	SkateTouchInput.set_drag_mode(true)
	_transport.sync_board_input()
	_check(_touch.enabled, "flipping the scheme MID-RIDE arms it, with no rebuild")
	SkateTouchInput.set_drag_mode(false)
	_transport.sync_board_input()
	_check(not _touch.enabled, "and flipping back disarms it, on the spot")
	SkateTouchInput.set_drag_mode(true)
	_transport.sync_board_input()
	_transport.leave_board()
	await _settle(20)
	_check(not _transport.is_riding_board(), "INSTRUMENT: he stepped off")
	_check(not _touch.enabled, "drag scheme + NOT riding -> NOT armed")
	await _idle_hopper()
	await _board_at(OPEN_GROUND)
	_check(_touch.enabled, "mounting under the drag scheme arms it")

# =====================================================================
# PHASE R -- THE RED PASS, AND IT IS THE POINT OF THIS PROBE
#
# The SAME event that PHASE I proved arrives, delivered on the SAME
# board, through the SAME pipeline, with only the scheme flipped. The
# shipped route must produce NOTHING: no tapped_ground, no destination
# from that route. And the finger must instead have been read by the new
# writer -- an event that reached NEITHER node would satisfy the absence
# half and mean the capture is dead.
#
# ⚠️ AND THE EXIT IS GATED FROM BOTH SIDES HERE, because it is the half of
# this lot that a player is sealed in without. At rest a tap must GET HIM
# OFF; mid-roll the same tap must NOT, or every accidental brush of the
# glass at 10 u/s ejects him. Two runs of one gesture, and the only
# difference between them is the board's speed.

func _phase_shunt() -> void:
	print("-- PHASE R: under DRAG, one finger has ONE meaning -- and there is a way out --")
	if not _screen_is_real():
		_check(false, "INSTRUMENT: no real viewport -- this phase cannot run")
		return
	_check(SkateTouchInput.drag_enabled() and _touch.enabled,
		"INSTRUMENT: drag scheme, armed, aboard")
	_transport.board_body().stop()
	await _settle(2)
	_check(not _transport.board_has_destination(), "INSTRUMENT: the board holds no destination")
	_check(_transport.board_at_rest(), "INSTRUMENT: and it is at rest")
	await _settle_camera()
	var taps_before: int = _ground_taps
	var exits_before: int = _taps
	await _screen_tap(_screen_ahead())
	_check(_ground_taps == taps_before,
		"the shipped tapped_ground route did NOT fire (no double dispatch)")
	_check(not _transport.board_has_destination(),
		"and no destination was planted by anything")
	# EXACTLY one, and this is where the emulated-event guard would earn
	# its place: the same finger that fires the shipped route twice must
	# fire this writer once, or one tap would be worth two gestures.
	_check(_taps == exits_before + 1,
		"the finger was read by the NEW writer instead -- exactly one exit tap (got %d)"
			% (_taps - exits_before))
	_check(not _transport.is_riding_board(),
		"and AT REST that tap got him OFF the board -- the drag scheme has an exit")
	# The other side of the same gesture: mid-roll it must not eject him.
	#
	# ⚠️ THE CAMERA IS SETTLED **BEFORE** THE BOARD IS SET ROLLING, AND THAT
	# ORDERING IS A MEASURED FIX. Settling after costs eight seconds -- a
	# chase camera behind a moving board never stops moving, so the settle
	# runs to its bound -- and in those eight seconds the board COASTS TO A
	# STOP. The phase then tapped a stationary board, was dismounted
	# correctly, and reported "the rest gate does not hold" about a gate
	# that had just worked. The bench had un-rolled its own premise.
	#
	# `_screen_ahead()` needs no settled camera at all: it is a
	# container-relative pixel, and under DRAG the writer swallows it
	# whatever it projects onto.
	await _reset_ride()
	await _settle_camera()
	var body := _transport.board_body()
	body.velocity = Vector3(0.0, 0.0, -HubTransport.SKATE_CRUISE)
	await _settle(2)
	_check(body.speed() > body.rest_speed() * 4.0,
		"INSTRUMENT: the board is genuinely rolling (%.3f u/s)" % body.speed())
	exits_before = _taps
	taps_before = _ground_taps
	await _screen_tap(_screen_ahead())
	_check(_taps > exits_before, "INSTRUMENT: the same gesture was read as an exit tap")
	_check(_transport.is_riding_board(),
		"but MID-ROLL it did NOT eject him -- the rest gate holds")
	_check(_ground_taps == taps_before, "and it reached no ground route either")

# =====================================================================
# PHASE E -- ONE FINGER IS ONE FINGER, THROUGH THE ENGINE
#
# ⚠️ THIS PHASE EXISTS BECAUSE A RED PASS CAME BACK GREEN, and it is
# reported as such rather than dressed up.
#
# SkateTouchInput drops the mouse events Godot synthesises from a touch,
# by their DEVICE_ID_EMULATION device -- KartTouchInput's guard, copied.
# Neutralising it was expected to redden "exactly one push". It did not.
# A traced explanation was written for why, and THAT WAS WRONG TOO: the
# guard was neutralised a second time with this phase in place, and the
# run came back ALL GREEN again.
#
# What IS measured, on this build, by a throwaway listener rather than by
# reading the engine's source: one `parse_input_event(ScreenTouch)`
# arrives as `InputEventMouseButton device=-1` and THEN as
# `InputEventScreenTouch device=0`, and the shipped HubTapInput reads both
# releases -- which is why every screen tap in this probe fires
# `tapped_ground` TWICE. The emulated twin is real and it is FIRST. What
# the guard buys against it is simply not reachable from this bench, so
# this lot does not claim it is gated.
#
# What this phase does gate is worth having on its own: PHASES C, D and M
# all call the writer's handler DIRECTLY, so none of them would notice a
# writer that never receives an engine-delivered drag at all. That is
# CLAUDE.md's "un fixture qui diverge du reel sur un axe ne protege pas de
# cet axe", and the axis is the delivery. Here the whole gesture goes
# through `Input.parse_input_event`.

func _phase_emulated() -> void:
	print("-- PHASE E: a drag delivered through the ENGINE still writes a heading --")
	if not _screen_is_real():
		_check(false, "INSTRUMENT: no real viewport -- this phase cannot run")
		return
	await _reset_ride()
	_check(_touch.enabled, "INSTRUMENT: the writer is armed")
	var at := Vector2(540.0, 1200.0)
	Input.parse_input_event(_press(at))
	await _settle(4)
	_check(_touch.steering_active,
		"an engine-delivered press takes the anchor (and the emulated twin does not steal it)")
	Input.parse_input_event(_drag(at + Vector2(150.0, 0.0)))
	await _settle(4)
	_check(_touch.has_heading(),
		"and an engine-delivered DRAG writes a heading (%s)" % str(_touch.heading_px))
	_check(_touch.heading_px.x > 0.0,
		"pointing the way the finger went, not the way an emulated pointer did")
	_check(_touch.throttle >= 1.0,
		"and the throttle is held through an engine-delivered gesture (%.2f)" % _touch.throttle)
	var exits_before: int = _taps
	Input.parse_input_event(_release(at + Vector2(150.0, 0.0)))
	await _settle(6)
	_check(not _touch.steering_active, "the release ends the gesture")
	_check(is_zero_approx(_touch.throttle), "and closes the throttle")
	_check(_taps == exits_before,
		"and a released DRAG is still not an exit tap, through the engine as well (got %d)"
			% (_taps - exits_before))

# =====================================================================
# PHASE D -- THE THROTTLE DRIVES
#
# A held finger has to move the board, in the direction the finger points,
# at the speed the shipped model gives it -- and a lifted one has to leave
# the elan alone.
#
# ⚠️ THE FINGER GOES **UP THE SCREEN** HERE, AND THAT IS A CONSEQUENCE OF
# THE CHASE CAMERA RATHER THAN A CHOICE OF CONVENIENCE. `heading_world()`
# reads the LIVE camera basis, and the chase basis YAWS with the board:
# hold the finger to the RIGHT and the board turns right, which turns the
# camera right, which moves where "right" points -- a steady circle, and
# exactly what holding a steering input does on every chase-camera vehicle
# in this repo. Up the screen is the one offset that is a FIXED point of
# that loop (camera behind the board, screen-up = the way it is already
# going), so it is the only one against which "it went where the finger
# pointed" is a statement about the mapping instead of a statement about
# the camera. The SIDES are gated in PHASE M, on a parked camera, in
# pixels.
#
# ⚠️ AND THE SECOND HALF IS THE HALF LOT 1 COULD NOT HAVE: a finger held
# INSIDE the slop writes no heading at all, and must STILL propel the
# board. That is the contract's own edge -- "un doigt pose et tenu veut
# dire tout droit" -- and it is the case a scheme that waited for a
# heading before pushing would fail silently.

func _phase_drive() -> void:
	print("-- PHASE D: a HELD finger rolls the board, at cruise, the way it points --")
	await _reset_ride()
	await _settle_camera()
	var body := _transport.board_body()
	var before: Vector3 = body.flat_position()
	var at := Vector2(500.0, 900.0)
	_touch._unhandled_input(_press(at))
	_touch._unhandled_input(_drag(at + Vector2(0.0, -140.0)))
	var want: Vector3 = _touch.heading_world(_camera)
	_check(want != Vector3.ZERO, "INSTRUMENT: the held drag maps to a world heading")
	_check(_touch.throttle >= 1.0, "INSTRUMENT: and the throttle is open")
	var top: float = 0.0
	var throttle_held: bool = true
	for _i in DRAG_FRAMES:
		await get_tree().physics_frame
		top = maxf(top, body.speed())
		if body.throttle() < 1.0:
			throttle_held = false
	var moved: Vector3 = body.flat_position() - before
	print("     travelled %.3f u, top speed %.3f u/s, cruise %.3f"
		% [moved.length(), top, HubTransport.SKATE_CRUISE])
	# THE RUN STAYED IN THE OPEN, and it is asserted rather than assumed:
	# a run that reaches the region border is measuring `_fence`, not the
	# finger. See DRAG_FRAMES for the version of this phase that did.
	_check(HubRegion.contains(body.flat_position()),
		"the run stayed inside the region (so `_fence` never touched it)")
	_check(throttle_held, "the BOARD held full throttle for every tick the finger was down")
	_check(moved.length() > 1.0, "the board actually moved (%.3f u)" % moved.length())
	_check(top >= HubTransport.SKATE_CRUISE * 0.95,
		"and reached cruise (%.3f >= %.3f)" % [top, HubTransport.SKATE_CRUISE * 0.95])
	var cos_err: float = moved.normalized().dot(want)
	_check(cos_err > 0.95,
		"and it went where the finger pointed (cos = %.4f against the mapped heading)" % cos_err)
	_touch._unhandled_input(_release(at + Vector2(0.0, -140.0)))
	# The lift must NOT be a handbrake: the elan CH61 gave the board is
	# the whole reason it exists, and a scheme that killed it on release
	# would be a change to the FEEL, which this lot does not make.
	var at_lift: float = body.speed()
	await _settle(6)
	_check(is_zero_approx(body.throttle()), "the lift closed the board's throttle")
	_check(body.speed() > at_lift * 0.5,
		"and it did NOT stop the board (%.3f -> %.3f u/s)" % [at_lift, body.speed()])
	# ---- the slop half ----------------------------------------------
	await _reset_ride()
	await _settle_camera()
	body = _transport.board_body()
	before = body.flat_position()
	_touch._unhandled_input(_press(at))
	_touch._unhandled_input(_drag(at + Vector2(4.0, 3.0)))
	_check(not _touch.has_heading(), "INSTRUMENT: a finger inside the slop writes no heading")
	var facing := Vector3(sin(body.rotation.y), 0.0, cos(body.rotation.y))
	for _i in DRAG_FRAMES:
		await get_tree().physics_frame
	var slop_moved: Vector3 = body.flat_position() - before
	_check(slop_moved.length() > 1.0,
		"a finger held INSIDE the slop still propels the board (%.3f u)" % slop_moved.length())
	var cos_facing: float = slop_moved.normalized().dot(facing)
	_check(cos_facing > 0.95,
		"and it went STRAIGHT ON, along the board's own facing (cos = %.4f)" % cos_facing)
	_touch._unhandled_input(_release(at + Vector2(4.0, 3.0)))
	await _settle(4)

# =====================================================================
# PHASE F -- THE FENCE TELLS THE ADAPTER, AND IT TELLS IT ON THE TICK
#
# ⚠️ THIS PHASE EXISTS BECAUSE A RED PASS CAME BACK GREEN. CH63 LOT 2 moved
# the destination out of the board and into HubTransport, which left the
# board's region fence with nobody to tell -- so it emits `fenced` and the
# adapter drops its destination on that signal. Neutralising the emit was
# expected to redden something; it reddened NOTHING, on SkatePhysicsProbe
# and on SkateDismountProbe alike.
#
# The reason is not that the wire is pointless: it is that the STALL GUARD
# reaches the same end state thirty ticks later, so a probe that only asks
# "did the destination go away eventually" cannot tell the two apart. What
# separates them is WHEN. So this phase gates the tick.
#
# It drives the fence directly rather than steering a board into the
# border for several seconds: the fence is `drive()`'s own last act, and
# putting the body outside the region and stepping it once is the whole of
# the mechanism. The blind check is the same step taken INSIDE the region,
# which must NOT drop anything -- without it, "the fence dropped it" and
# "one tick always drops it" read alike.

func _phase_fence() -> void:
	print("-- PHASE F: the region fence drops the tap destination ON THE TICK --")
	await _reset_ride()
	SkateTouchInput.set_drag_mode(false)
	_transport.sync_board_input()
	var body := _transport.board_body()
	# BLIND FIRST: a destination, a legal position, one tick -> still held.
	body.stop()
	body.global_position = HubSurface.ground(OPEN_GROUND)
	_transport.set_board_target(HubRegion.clamp_to(OPEN_GROUND + Vector3(6.0, 0.0, 0.0)))
	_check(_transport.board_has_destination(), "INSTRUMENT: the tap planted a destination")
	_check(HubRegion.contains(body.flat_position()), "INSTRUMENT: and the board is inside the region")
	body.drive(1.0 / 60.0)
	_check(_transport.board_has_destination(),
		"BLIND: one tick INSIDE the region does not drop it (so the drop below means something)")
	# NOW the fence. A point far outside every lobe: the fence refuses the
	# step, puts the body back, and says so.
	var outside := Vector3(0.0, 0.0, 900.0)
	_check(not HubRegion.contains(outside), "INSTRUMENT: (0, 900) is outside the region")
	body.global_position = HubSurface.ground(outside)
	body.drive(1.0 / 60.0)
	_check(not _transport.board_has_destination(),
		"the fence dropped the destination on the SAME tick (not 30 ticks later, via the stall guard)")
	body.stop()
	body.global_position = HubSurface.ground(OPEN_GROUND)
	await _settle(4)

# =====================================================================
# PHASE M -- THE MAPPING, IN RENDERED PIXELS
#
# CLAUDE.md, twice: "un mot de convention de cote ne vaut rien sans une
# capture", and (CH39) an object meant to be SEEN is gated on at least one
# PIXEL, never on a transform. The hub camera's yaw reads 0 in the scene
# file and nobody has ever checked that on a screen, so what the finger's
# "right" actually means on the delivered frame is the one thing this lot
# may not take on trust.
#
# ⚠️ TWO EARLIER VERSIONS OF THIS PHASE MEASURED SOMETHING ELSE, and both
# are worth naming because both looked like results.
#
#  1. IT MEASURED THE CAMERA'S LAG. It drove the board and read where the
#     board was DRAWN -- on a camera that FOLLOWS THE RIDER. Board and
#     frame move together, so what was left in the pixels was the
#     smoothing lag (HubCamera.FOLLOW_LAMBDA) plus perspective, and the
#     "down the screen" case came back at cos 0.416 against a mapping
#     that was exactly right. A drawn position is only a measurement if
#     the frame is still. Fixed by leaving the rider ON FOOT for the whole
#     phase, which parks the camera.
#  2. IT MEASURED THE WEATHER. With the frame still, the board's drawn
#     position was recovered as a plain DIFFERENCE against a frame with
#     the board hidden -- and the hub is a living scene. Measured: 11 375
#     sampled pixels differ between two frames with NOTHING touched, the
#     board inks 16 000 to 38 000, and every centroid came back within
#     3 px of the same point (on Keepy, who breathes) rather than on the
#     board. That is CLAUDE.md's own "un delta sous son plancher de bruit
#     n'est pas une mesure", arrived at from the inside.
#
# So this is the MASKED IDENTIFICATION PASS the doctrine prescribes: the
# board is painted a colour nothing else carries, unshaded and with fog
# off, and a pixel belongs to it IFF that exact colour comes back. Pure
# 0/1 channels are chosen on purpose -- they survive any transfer curve
# byte-for-byte, so "exactly" means exactly. The blind check is a control
# frame with the board HIDDEN, which must return ZERO such pixels: without
# it, "the board is over there" and "everything is over there" read alike.
const MARK: Color = Color(1.0, 0.0, 1.0, 1.0)
## The distances the board is offered for each direction, longest first.
##
## ⚠️ IT IS A LADDER AND NOT A NUMBER, BECAUSE THE FRAME IS NARROW. At a
## flat 6 u the phase reported ZERO marked pixels for RIGHT and for LEFT,
## on a mapping that PHASE D had just measured correct to cos 0.9998 --
## the board was simply not in the picture. That is CLAUDE.md's own "un
## prop plante a plus de ~3 u de cote de Keepy au spawn n'est PAS a
## l'ecran", rediscovered from the inside, and it is a property of the
## KEEP_WIDTH frame rather than of anything this lot wrote.
##
## So each direction takes the LONGEST offer whose projected point is
## still inside the frame, and the distance it used is printed beside the
## result. Forward and back get the whole 6 u; sideways gets what the
## frame allows. A direction for which NO offer fits reddens rather than
## quietly shrinking to nothing.
const PLACE_LADDER: Array[float] = [6.0, 4.0, 3.0, 2.2, 1.6]
## How much of the frame edge is refused, as a fraction of each axis: a
## body whose CENTRE is just inside the picture still has most of itself
## outside it.
const FRAME_INSET: float = 0.12

func _phase_mapping() -> void:
	print("-- PHASE M: screen -> world, read in RENDERED PIXELS --")
	if not _screen_is_real():
		_check(false, "INSTRUMENT: dummy driver -- run this under xvfb-run --rendering-driver opengl3")
		return
	# On foot, still, camera parked. Nothing in this phase rides.
	if _transport.is_riding_board():
		_transport.leave_board()
		await _settle(20)
	_keepy.dismount_vehicle()
	await _idle_hopper()
	_keepy.global_position = HubSurface.ground(OPEN_GROUND)
	await _settle(8)
	await _settle_camera()
	var board: Node3D = _transport.board_node()
	var body := _transport.board_body()
	body.stop()
	var mesh: MeshInstance3D = board.find_child("SkateboardMesh", true, false) as MeshInstance3D
	if mesh == null:
		mesh = board as MeshInstance3D
	if mesh == null:
		_check(false, "INSTRUMENT: the board carries no MeshInstance3D to paint")
		return
	var saved: Material = mesh.material_override
	var mark := StandardMaterial3D.new()
	mark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark.albedo_color = MARK
	mark.disable_fog = true
	mesh.material_override = mark
	# THE BLIND CHECK, and it comes first: with the board out of the frame
	# nothing may answer to the mark. An identification pass that cannot
	# come back empty cannot come back full either.
	board.visible = false
	var control: Image = await _frame()
	var stray: int = _marked(control)
	_check(stray == 0,
		"BLIND: with the board hidden, ZERO pixels carry the mark (got %d)" % stray)
	board.visible = true
	var centre := Vector2(float(_tap.viewport.size.x), float(_tap.viewport.size.y)) * 0.5
	for entry in [
		{"push": Vector2(140.0, 0.0), "name": "RIGHT"},
		{"push": Vector2(-140.0, 0.0), "name": "LEFT"},
		{"push": Vector2(0.0, -140.0), "name": "UP"},
		{"push": Vector2(0.0, 140.0), "name": "DOWN"},
	]:
		var offset: Vector2 = entry["push"]
		var at := Vector2(500.0, 900.0)
		_touch.enabled = true
		_touch._unhandled_input(_press(at))
		_touch._unhandled_input(_drag(at + offset))
		var heading: Vector3 = _touch.heading_world(_camera)
		_touch._unhandled_input(_release(at + offset))
		_touch.enabled = false
		if heading == Vector3.ZERO:
			_check(false, "%s: the drag mapped to no heading at all" % entry["name"])
			continue
		var used: float = _fitting_distance(heading)
		if used <= 0.0:
			_check(false, "%s: no offered distance puts the board in the frame at all"
				% entry["name"])
			continue
		board.global_position = HubSurface.ground(
			_flat(_keepy.global_position) + heading * used)
		body.velocity = Vector3.ZERO
		await _settle(2)
		var shot: Image = await _frame()
		var ink: int = _marked(shot)
		var seen: Vector2 = _mark_centroid(shot)
		var drawn: Vector2 = seen - centre
		print("     %-5s finger %s -> heading %s at %.1f u -> ink %d px, centroid %s, off-centre %s"
			% [entry["name"], str(offset), str(heading.snapped(Vector3(0.01, 0.01, 0.01))),
				used, ink, str(seen.round()), str(drawn.round())])
		_check(ink > 0,
			"%s: the board is genuinely DRAWN where it was put (%d marked px)"
				% [entry["name"], ink])
		if ink <= 0:
			continue
		# The side, and only the side. A dot against the finger's own
		# direction rather than a per-axis sign test: this camera is
		# pitched, so a purely forward push also climbs the frame, and an
		# axis-by-axis assertion would be gating the pitch instead.
		var cos_px: float = drawn.normalized().dot(offset.normalized())
		_check(cos_px > 0.7,
			"%s: and it is drawn on the side the finger went (cos = %.3f)"
				% [entry["name"], cos_px])
	mesh.material_override = saved
	board.global_position = HubSurface.ground(OPEN_GROUND)

## The longest offered distance along `heading` whose ground point still
## projects INSIDE the frame, inset from its edges. 0 when none does.
func _fitting_distance(heading: Vector3) -> float:
	var vp := Vector2(float(_tap.viewport.size.x), float(_tap.viewport.size.y))
	var inset: Rect2 = Rect2(vp * FRAME_INSET, vp * (1.0 - 2.0 * FRAME_INSET))
	for d in PLACE_LADDER:
		var at: Vector3 = HubSurface.ground(_flat(_keepy.global_position) + heading * d)
		if _camera.is_position_behind(at):
			continue
		if inset.has_point(_camera.unproject_position(at)):
			return d
	return 0.0

## One rendered frame of the world sub-viewport, as an Image. Waits for
## the draw to have happened -- reading the texture in the same frame it
## was asked for returns the PREVIOUS one.
func _frame() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return _tap.viewport.get_texture().get_image()

## Pixels carrying the identification colour EXACTLY.
##
## Every 4th pixel each way: 16x fewer reads on a 1080x1920 frame, and the
## board is a hundred-odd pixels across at this distance, so nothing it
## draws can slip between samples. The blind check is sampled the same
## way, so the two numbers are comparable -- the only property that counts.
func _marked(img: Image) -> int:
	if img == null:
		return -1
	var n: int = 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).is_equal_approx(MARK):
				n += 1
	return n

## Where those pixels are, in VIEWPORT coordinates.
func _mark_centroid(img: Image) -> Vector2:
	var sum := Vector2.ZERO
	var n: int = 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).is_equal_approx(MARK):
				sum += Vector2(float(x), float(y))
				n += 1
	return sum / maxf(float(n), 1.0)

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

## Whether the board is being commanded at all, by either scheme. Named
## rather than inlined because "it holds a destination" and "it is being
## pushed" are two different questions and this probe asks both.
func body_driving() -> bool:
	var body := _transport.board_body()
	return body != null and body.driving()

# =====================================================================
# PHASE O -- THE SHIPPED SCHEME IS UNTOUCHED
#
# The lot's own claim, gated: with the scheme back on TAP, the board
# behaves exactly as CH57/CH58 left it. This is the phase that would
# redden if the short-circuit in HubTapInput were written on the ride
# alone rather than on the ride AND the scheme.

func _phase_off() -> void:
	print("-- PHASE O: back on TAP, the shipped route is exactly as it was --")
	await _reset_ride()
	SkateTouchInput.set_drag_mode(false)
	_transport.sync_board_input()
	_check(not _touch.enabled, "the writer is disarmed by the flip alone")
	if not _screen_is_real():
		_check(false, "INSTRUMENT: no real viewport -- this phase cannot run")
		return
	await _settle_camera()
	var taps_before: int = _ground_taps
	var exits_before: int = _taps
	await _screen_tap(_screen_ahead())
	_check(_ground_taps > taps_before, "a screen tap reaches tapped_ground again")
	_check(_taps == exits_before, "and the new writer heard nothing at all")
	_check(_transport.board_has_destination(), "and the board took the destination")
	_check(body_driving(), "and the tap adapter is actually pushing it")
	# And the dismount, which is the shipped gesture the drag scheme
	# suppressed in PHASE R -- proving that suppression was the SCHEME's
	# doing and not something this lot broke.
	await _await_rest()
	_check(_transport.board_at_rest(), "INSTRUMENT: the board is at rest")
	await _settle_camera()
	await _screen_tap(_screen_of(_keepy.global_position))
	_check(not _transport.is_riding_board(),
		"and a tap on his own body dismounts him, exactly as CH58 left it")

# =====================================================================
# THE BENCH

## True when the container and viewport are real enough for a screen
## point to project anything at all -- CLAUDE.md's dummy-driver assertion,
## SkateDismountProbe's own wording.
func _screen_is_real() -> bool:
	if _tap.container == null or _tap.viewport == null or _camera == null:
		return false
	var rect: Rect2 = _tap.container.get_global_rect()
	return rect.size.x > 0.0 and rect.size.y > 0.0 and _tap.viewport.size.x > 0

## A world point, as the container pixel a finger would touch to aim at
## it. HubTapInput._handle_point's own mapping, run backwards.
func _screen_of(world: Vector3) -> Vector2:
	var rect: Rect2 = _tap.container.get_global_rect()
	var vp: Vector2 = _camera.unproject_position(world)
	var scale := Vector2(rect.size.x / float(_tap.viewport.size.x),
		rect.size.y / float(_tap.viewport.size.y))
	return rect.position + vp * scale

## ⚠️ A DESTINATION IS PICKED ON THE SCREEN, NEVER NAMED IN THE WORLD, and
## this probe paid for the difference. Its first version aimed at a world
## point 8 u in front of the rider -- SkateDismountProbe's own AIM_AWAY,
## which that probe uses correctly because it emits `tapped_ground`
## directly and never turns it into a pixel. Projected, it lands at
## x = 1138 on a canvas 1080 wide: OFF the container, so `_handle_point`
## returned at its rect test and the instrument read "the shipped route is
## dead" about a route that was perfectly alive.
##
## That is CLAUDE.md's narrow-frame doctrine arriving from the other side
## -- "un prop plante a plus de ~3 u de cote de Keepy au spawn n'est PAS a
## l'ecran" -- and the fix is to stop naming world points at all: a finger
## picks a PIXEL, so the bench picks one too, well inside the frame and
## above centre (which on this fixed camera means ahead of the rider), and
## the world point is whatever that pixel means.
func _screen_ahead() -> Vector2:
	var rect: Rect2 = _tap.container.get_global_rect()
	return rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.35)

## The camera is smoothed (HubCamera.FOLLOW_LAMBDA), so it arrives at a
## teleported rider over several frames. Every screen point below is read
## off it, so a phase that measured before it settled would be aiming at
## where the rider WAS -- which is how the miss above was masked for a
## run. Waits for the pose to stop moving rather than for a frame count.
## ⚠️ CH63 LOT 2 REWROTE THIS, AND THE OLD FORM COST THREE REDS ON CORRECT
## CODE -- worth writing down, because the failure looked exactly like a
## broken tap route.
##
## The board now enters and leaves the CHASE pose, which is a 0.9 s
## SINE-EASED blend of two transforms. A settle written as "return as soon
## as two consecutive frames barely moved" returns during the FIRST frames
## of such a blend, where an ease-in has barely started: PHASE O then aimed
## its pixel through a camera still pointing down the chase axis, the ray
## missed the ground, and `tapped_ground` reported dead on a route that was
## perfectly alive.
##
## So there are three tests now and all three are needed: the blend must
## have REACHED an end (0 or 1 -- not merely be moving slowly), the origin
## must be still, and the BASIS must be still. And stillness is asserted
## over CONSECUTIVE frames rather than one, because one frame of an eased
## curve says nothing about the next.
const SETTLE_STABLE_FRAMES: int = 8

func _settle_camera() -> void:
	var last: Transform3D = _camera.global_transform
	var stable: int = 0
	for _i in 480:
		await get_tree().physics_frame
		var now: Transform3D = _camera.global_transform
		var blend: float = _camera.drive_blend()
		var blended: bool = blend < 0.001 or blend > 0.999
		if blended and now.origin.distance_to(last.origin) < 0.0005 \
				and (now.basis.x - last.basis.x).length() < 0.0002 \
				and (now.basis.z - last.basis.z).length() < 0.0002:
			stable += 1
			if stable >= SETTLE_STABLE_FRAMES:
				return
		else:
			stable = 0
		last = now

## A tap delivered through the ENGINE, not into a handler. Both nodes get
## their real chance at it, in whatever order the tree gives them, which
## is the only way "one finger, one meaning" can be measured at all.
func _screen_tap(at: Vector2) -> void:
	Input.parse_input_event(_press(at))
	await _settle(2)
	Input.parse_input_event(_release(at))
	await _settle(8)

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

## Puts the board and the rider back at OPEN_GROUND, at rest, aboard, with
## the drag scheme armed and no destination held. Every phase that
## measures a roll starts from here, so none of them inherits the last
## one's velocity -- SkateDismountProbe's "hand the world back at rest",
## written as a setup instead of a teardown because a phase cannot know
## which phase ran before it.
func _reset_ride() -> void:
	if _transport.is_riding_board():
		_transport.leave_board()
		await _settle(20)
	_keepy.dismount_vehicle()
	await _idle_hopper()
	SkateTouchInput.set_drag_mode(true)
	await _board_at(OPEN_GROUND)

## Parks the board under Keepy at `where` and mounts him on it.
func _board_at(where: Vector3) -> void:
	var body := _transport.board_body()
	if body == null:
		_check(false, "INSTRUMENT: there is no physics board (was the switch on?)")
		return
	if _transport.is_riding_board():
		_transport.leave_board()
		await _settle(20)
	_keepy.dismount_vehicle()
	await _idle_hopper()
	body.stop()
	body.global_position = HubSurface.ground(where)
	body.velocity = Vector3.ZERO
	_keepy.global_position = HubSurface.ground(where)
	await _settle(6)
	if not _transport.mount_board():
		_check(false, "INSTRUMENT: mount_board() refused at %s" % str(where))
		return
	await _settle(6)
	await _settle_camera()

func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().physics_frame

## Waits for the board to actually stop, rather than for a frame count.
##
## ⚠️ THE FRAME COUNT WAS WRONG AND IT WAS WRONG IN THE DIRECTION THAT
## LOOKS LIKE A DEFECT. Under LOT 1 a push planted a destination 6.4 u
## ahead; covering that at cruise and braking into it takes past 150
## frames, and the 60 this probe first waited left the board still rolling
## -- read as "board_at_rest() is broken" when it was the bench that had
## not waited. LOT 2 has no lead and no push, but a released board still
## COASTS a park span, so the wait is if anything longer. Bounded, so a
## board that genuinely never settles reddens instead of hanging.
func _await_rest() -> void:
	for _i in 600:
		if _transport.board_at_rest():
			return
		await get_tree().physics_frame

## Lets a walk finish. `mount_carrier` refuses from any state but IDLE, so
## a phase that mounts while a hop is still in the air scores a rider who
## never got on -- SkateDismountProbe's measured defect, avoided the same
## way it avoids it.
func _idle_hopper() -> void:
	for _i in 600:
		if not _keepy.is_hopping():
			return
		await get_tree().physics_frame
