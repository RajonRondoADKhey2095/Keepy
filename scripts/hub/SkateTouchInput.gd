extends Node
class_name SkateTouchInput
## CH63 LOT 2 -- THE BOARD'S OWN INPUT WRITER: a thumb that HOLDS the
## board moving, and steers it while it holds.
##
## =====================================================================
## WHAT LOT 1 GOT WRONG, SAID FIRST AND PLAINLY
##
## LOT 1 shipped "a held drag writes a heading, a short tap PUSHES", and
## the tap-push half was a mis-reading of the brief. Mathieu does not want
## a board that is tapped along: he wants a FINGER HELD DOWN to propel it
## continuously, and a finger lifted to hand the board back to CH61's
## inertia. The `pushed` signal is GONE. What replaces it is not a second
## gesture -- it is the ABSENCE of one: the throttle is simply the state
## of the finger.
##
## ⚠️ AND THAT IS THE KART'S SCHEME, WHICH IS WHY IT IS COPIED AND NOT
## INVENTED. `KartTouchInput` holds `input.throttle = 1.0` for as long as
## it is armed and reads the finger's OFFSET as an axis; nothing in it is
## a gesture that has to be recognised, and it is the one touch scheme in
## this repo that has survived a device. This file is now the same shape,
## with two differences that are properties of a skateboard rather than
## preferences: the offset writes a HEADING (an absolute direction, not a
## steering rate -- a board has no steering column), and the throttle is
## the finger's PRESENCE rather than a permanent 1.0, because a board with
## no finger on it must coast.
##
## =====================================================================
## THE SCHEME, IN FOUR LINES
##
##   * the FIRST finger down becomes the ANCHOR, wherever it lands, and
##     the throttle goes to 1.0 on that same event -- KartTouchInput's
##     pattern for the anchor, and the brief's for the throttle;
##   * sliding that finger away from the anchor writes a HEADING: the
##     direction of the offset, mapped into the world through the LIVE
##     camera basis, tracked CONTINUOUSLY for as long as the finger
##     holds it;
##   * inside the slop there is no heading and the board keeps its own
##     facing -- a finger pressed and held still means "straight on",
##     which is the only thing it can honestly mean;
##   * lifting the finger drops the throttle to zero and the heading with
##     it. It does NOT stop the board: the elan CH61 gave it is the whole
##     point, and a lift that braked would be a handbrake nobody asked
##     for.
##
## ⚠️ THE HEADING NO LONGER LATCHES, AND THAT IS A CONTRACT CHANGE. LOT 1
## froze the heading once the finger had left the slop, so a slide back
## through the anchor kept the old direction -- correct there, because the
## return would otherwise have turned into a push under the player's
## thumb. With no push to protect, a heading that ignored the finger's
## return would be a board that stops obeying, and "la direction suit la
## position du doigt en continu" is the contract. It tracks. What still
## latches is `_dragged`, and it latches for ONE reason only, below.
##
## =====================================================================
## THE ONE GESTURE THAT IS STILL RECOGNISED, AND WHY IT MUST BE
##
## A short tap that never left the slop emits `tapped`, and HubTransport
## reads it as GET OFF.
##
## ⚠️ THIS IS NOT A LEFTOVER OF THE PUSH -- IT CLOSES A HOLE LOT 1 SHIPPED.
## `HubTapInput` short-circuits every point while a DRAG-mode board is
## ridden, which is what gives one finger one meaning; but the shipped
## dismount ("a tap on his own body while the board is at rest") lives
## BELOW that short-circuit, in HubWorld. So under LOT 1's drag scheme
## there was no way off the board at all -- a player sealed inside a prop
## that eats every tap, which is exactly CLAUDE.md's PATRON ECHELLE and
## exactly what it bans. LOT 2 moves the piloted board to the chase
## camera, where "tap your own drawn body" is not even a stable target any
## more, so the exit is the gesture that costs nothing else: a tap.
##
## It is gated on the board being AT REST by its reader, not here -- the
## same rule the shipped tap scheme uses, so a tap made mid-roll steers
## (it holds the throttle for its own short duration) instead of ejecting
## a rider at speed.
##
## ⚠️ ONE NUMBER SEPARATES A TAP FROM A DRAG, AND IT IS THE SAME NUMBER
## BOTH WAYS. Below `SLOP_PX` from the anchor there is no heading and a
## release is a tap; above it there is a heading and a release is not.
## Written once as one constant because "what counts as a drag" and "what
## still counts as a tap" are the same question asked from two sides, and
## two constants would let a gap or an overlap open between them that
## nothing would report. SkateInputProbe gates it from BOTH sides (a 4 px
## jitter is still a tap; a 40 px slide is not).
##
## =====================================================================
## WHO SEES THE TOUCH
##
## `_unhandled_input`, like HubTapInput and KartTouchInput: GUI controls
## are picked first and swallow their own taps. HubTapInput short-circuits
## every point while a DRAG-mode board is ridden (one condition per driven
## thing, the shape the four piloted vehicles now use), so whichever of
## the two nodes runs first, a riding touch reaches THIS node and a
## walking tap reaches THAT one. Every event handled here is marked
## handled.
##
## ⚠️ GODOT SYNTHESISES A MOUSE EVENT FROM EVERY TOUCH, AND IT ARRIVES
## FIRST. Measured on this build rather than assumed: one
## `parse_input_event(InputEventScreenTouch)` reaches a listener as
## `InputEventMouseButton device=-1` and THEN as `InputEventScreenTouch
## device=0` -- `input_devices/pointing/emulate_mouse_from_touch` is true
## and the project sets nothing. So the emulated POINTER is what a naive
## "first finger down becomes the anchor" would anchor on, and the real
## finger would arrive second to a gesture already claimed.
##
## Dropping DEVICE_ID_EMULATION here is KartTouchInput's guard, copied for
## that reason. ⚠️ IT IS NOT GATED, AND THAT IS SAID RATHER THAN IMPLIED:
## LOT 1's red pass removed it and came back ALL GREEN, twice, including
## through the engine. The anchor logic below happens to survive the pair
## in the orders this bench can produce, so what the guard buys is not
## measurable here -- it is kept as the shipped writer's own defence and
## not as a property this lot has proved.

## =====================================================================
## CH64 -- THERE IS NO MODE ANY MORE
##
## CH63 kept a TAP / DRAG static here for Mathieu's in-app A/B. The A/B
## was performed on device and DRAG won: a held finger propels, the
## heading tracks the finger, a lift coasts, a short tap at rest gets
## off. That is now the board's ONLY control scheme, and the static, its
## two accessors and the menu button that flipped it are gone. The writer
## is armed by exactly one fact -- a rider is aboard (HubTransport.
## sync_board_input) -- and HubTapInput shunts every point on that same
## fact alone.

## How far from the anchor a finger must travel before it is a drag, in
## screen pixels. See the block above for why this is one constant and not
## two. 16 px is a little over a millimetre on Mathieu's phone -- large
## enough that a thumb pressing and lifting registers as a tap, small
## enough that a deliberate slide is a heading from its first millimetre.
const SLOP_PX: float = 16.0

## The longest a finger may stay down and still be read as a tap. A finger
## held motionless for a second is not asking to get off -- it is asking
## to go straight on, and ejecting him under it would be the screen
## guessing.
const TAP_MAX_S: float = 0.45

## Emitted on a short tap that never became a drag: the EXIT gesture, and
## the only gesture this file still has to recognise. Carries nothing --
## WHERE the finger landed is deliberately not part of it, because under
## the chase camera there is no fixed pixel that means "him".
signal tapped

## ⚠️ EMITTED ON THE PRESS, AND IT EXISTS FOR ONE MEASURED REASON. The exit
## is gated on the board being AT REST, and reading that at the RELEASE
## reads a board THIS GESTURE HAS ALREADY PUSHED: the throttle opens on the
## press, so by the time a tap ends, two or three ticks of push have put
## the board at ~0.6 u/s against a rest threshold of 0.24 -- and a tap on a
## perfectly stationary board would never once dismount. The gesture cannot
## be its own yardstick. So the reader samples "was it at rest" HERE, on the
## frame the finger lands, before this file has changed anything.
signal pressed

## =====================================================================
## CH64 -- THE TRICK: A CIRCLE, IN THE AIR ONLY, EITHER WAY ROUND
##
## Mathieu's gesture, to the letter: the finger STAYS DOWN (the same
## contact that propels -- no second channel); in the AIR a circle is a
## trick, on the GROUND the same movement is steering and nothing else;
## clockwise and anticlockwise are TWO tricks; circles chained while the
## board is still up repeat the trick.
##
## HOW A CIRCLE IS RECOGNISED, AND WHY BY ITS TURNING AND NOT ITS SHAPE.
## A thumb's circle is not round, not centred on the anchor, not closed.
## What every loop has, whatever its shape, is a TURNING NUMBER: walk
## along the path and add up the signed angle the direction of travel
## turns through, and one loop comes to +-360 deg however lumpy it is.
## A straight drag turns 0; a zigzag turns +-a, -+a and sums to nothing;
## a U-turn is 180; a hook is 270. So the recogniser keeps a polyline of
## the finger's path (a point is kept only once the finger has travelled
## TRICK_SEG_PX from the last kept one, which is what makes a resting or
## trembling thumb write NO segment and therefore no turning) and sums the
## angle between consecutive segments. A trick fires when the sum passes
## TRICK_SWEEP_DEG, and a full turn is SUBTRACTED from it rather than the
## sum being cleared -- so a second loop drawn straight on fires again at
## the same point of its own circle, and a loop and a half fires once.
##
## THE THRESHOLD, ARGUED. 300 deg, not 360: a thumb's loop rarely closes
## exactly and a recogniser that waited for the last 60 deg would miss a
## good share of honest circles. Not lower: 270 is a hook -- a finger
## steering hard round a bend on the way up a ramp draws one -- and a
## trick that fires on a hook is a trick that fires by accident. The gap
## between 270 and 360 is the margin, and 300 sits inside it on the side
## of the player. SkateTrickProbe sweeps it from both sides (a lumpy
## circle with +-4 px of jitter fires; a hook, a half-circle, a zigzag, a
## straight drag do not). If device says the number is wrong, it is a
## commit -- there is no dev knob for it, by design.
##
## THE SENSE. Screen y points DOWN, so `Vector2.angle_to` is POSITIVE for
## a turn that a viewer sees as CLOCKWISE (from "moving right" to "moving
## down"). Positive sweep = clockwise = `trick(true)`. Not a convention
## read off a comment: the probe draws a circle whose points go right,
## then down, then left, and asserts which trick it fires.
##
## THE AIR/GROUND BOUNDARY IS NOT DECIDED HERE. HubTransport tells this
## writer `set_air()` each tick from `SkateBoardBody.in_air()` -- the
## dwelled predicate, see there -- and the polyline only exists while it
## is true. When it goes false (the LANDING) a circle in progress is cut
## on the spot, and if the finger travelled during the air the anchor is
## MOVED UNDER THE FINGER: the offset is zero, the board goes straight on
## from the facing it landed with, and a finger that stopped at three
## o'clock does not put the board into a 90 deg turn on contact. A short
## hop that never armed the air keeps its anchor, so a carve held over a
## bump on the lawn is not cancelled by it.
signal trick(clockwise: bool)

const TRICK_SWEEP_DEG: float = 300.0
const TRICK_SEG_PX: float = 8.0

## =====================================================================
## CH65 -- THE THROTTLE RAMPS, AND THE FINGER IS FILTERED
##
## Two device complaints, one file, and both are answered HERE rather than
## in the physics -- deliberately, because the model CH61 solved from
## CH54's authored distances is the thing this repo has the most measured
## reasons not to move. What was wrong was never the push; it was that the
## push arrived as a STEP and that the heading answered a thumb's every
## tremble.
##
## ⚠️ (a) THE RAMP. `throttle` stepped 0 -> 1 on the press, so the board's
## acceleration went from 0 to the full 17.2165 u/s^2 between two frames:
## an infinite jerk, which is what "la poussee est trop brutale au
## demarrage" is. Measured on the shipped tree (CH65 recon, finger held
## inside the slop from a standstill): +0.2656 u/s on the very first tick,
## 50% of cruise at 0.333 s, 99% at 0.683 s -- a straight line out of a
## standstill with no beginning.
##
## The ramp is a first-order approach at `THROTTLE_LAMBDA`, so the FORCE
## starts at zero and builds. It is written as a lambda and not as a fixed
## time because a lift must fall the same way a press rises, and one
## constant that does both cannot drift apart.
##
## ⚠️ AND THE VALUE IS ANCHORED, NOT TASTED. CH54 authored a run-up
## DISTANCE of 3.2 u (`HubTransport.SKATE_ACCEL_U`) and CH61 solved the
## push from it; a ramp lengthens that run-up, and a ramp long enough to
## move it appreciably would be re-authoring CH54's ride under the name of
## a feel fix. The constant is the largest one whose run-up stays inside
## 10% of the authored 3.2 u, which `SkateInertiaProbe` PHASE L measures
## rather than trusts. What device may still move is the number; what it
## may not move is that the run-up is re-gated when it does.
##
## ⚠️ (b) THE FILTER. The heading is the DIRECTION of the finger's offset,
## so its angular gain is atan(1 / r) -- inversely proportional to how far
## the thumb has travelled, and therefore LARGEST exactly where a thumb
## rests. Measured on the shipped tree, through this writer:
##
##   offset  17 px -> 3.3665 deg per pixel of travel
##   offset 140 px -> 0.4092 deg per pixel
##   a +-3 px tremble at a 20 px offset swings the commanded heading
##   through 17.06 deg, peak to peak; +-6 px through 33.40; +-10 px
##   through 53.13
##
## Three pixels is well under a millimetre on Mathieu's phone. "Il part
## dans tous les sens" is that line. The board's own yaw cap (CH65,
## `SkateBoardBody.YAW_RATE_MAX`) bounds how fast that can be OBEYED; this
## filter stops it being ASKED FOR, and the two are complementary rather
## than alternative -- a cap alone still turns a tremble into a slow,
## committed lean, because the commanded heading it is chasing is wrong.
##
## ⚠️ AND IT FILTERS THE HEADING'S FINGER ONLY, NEVER THE TRICK'S. The
## circle recogniser walks the RAW finger (`_trace` is still fed from
## `_move`), because a filtered path is a shorter path and a shorter path
## turns through the same angle more slowly -- filtering it would silently
## raise the effective TRICK_SWEEP_DEG and start dropping honest circles.
## `SkateTrickProbe` gates that the gesture still fires, from both sides.
const THROTTLE_LAMBDA: float = 9.0
const FINGER_LAMBDA: float = 14.0

## The filtered finger, in screen pixels: what the HEADING is computed
## from. Equal to `finger` while nothing is moving, and lagging it while
## something is.
var _smooth: Vector2 = Vector2.ZERO

## What the throttle is ramping TOWARD: 1.0 while a finger is down.
var _throttle_want: float = 0.0

## For the bench: the filtered finger, published rather than recomputed.
func smooth_finger() -> Vector2:
	return _smooth

## ⚠️ THE WRITER NOW HAS A TICK, AND CH63 LEFT THE DOOR OPEN FOR IT: "a
## later lot that wants a pressure or a ramp writes it here without
## changing a single reader". This is that lot.
##
## ⚠️ IT IS CALLED BY ITS READER, NOT BY THE ENGINE, and that is the whole
## reason it is a method and not a `_physics_process`. This node is a
## CHILD of HubTransport, so the engine would run the parent's tick first
## and the reader would spend every frame on the filter's PREVIOUS output
## -- a one-frame lag that depends on where in the tree somebody put the
## node. `HubTransport._advance_board` calls this first, on the same delta
## it then drives the board with, exactly as it already pushes `set_air()`
## down. Nothing about the answer depends on the tree any more.
##
## Both things it advances are per-TICK quantities: a filter stepped on a
## different clock from its reader is a filter whose output depends on the
## frame rate.
func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	throttle = _approach(throttle, _throttle_want, THROTTLE_LAMBDA, delta)
	if not steering_active:
		return
	_smooth = _smooth.lerp(finger, minf(FINGER_LAMBDA * delta, 1.0))
	_apply_offset()

static func _approach(from: float, to: float, lambda: float, delta: float) -> float:
	return from + (to - from) * minf(lambda * delta, 1.0)

## The one place the offset becomes a heading, so the event path and the
## filter path cannot hold two answers to the same question.
func _apply_offset() -> void:
	var offset: Vector2 = _smooth - anchor
	if offset.length() < SLOP_PX:
		heading_px = Vector2.ZERO
		return
	heading_px = offset

var _air: bool = false
var _path_last: Vector2 = Vector2.ZERO
var _path_dir: Vector2 = Vector2.ZERO
var _sweep: float = 0.0
var _air_travel: float = 0.0

## The signed turning accumulated so far, in degrees, for the bench.
func sweep_deg() -> float:
	return _sweep

func in_air() -> bool:
	return _air

## Told by the reader each tick. Rising edge starts the polyline; falling
## edge cuts it and re-anchors a finger that has travelled.
func set_air(on: bool) -> void:
	if on == _air:
		return
	_air = on
	if on:
		_start_path()
		return
	if steering_active and _air_travel >= TRICK_SEG_PX:
		rebase()
	_sweep = 0.0
	_air_travel = 0.0
	_path_dir = Vector2.ZERO

## Moves the anchor under the finger: no offset, straight on. `_dragged`
## is left as it is -- a landing must not turn a long drag into an exit
## tap when the finger finally lifts.
func rebase() -> void:
	anchor = finger
	# CH65: and the filter with it, or the next tick would immediately
	# write back the heading this call exists to cancel.
	_smooth = finger
	heading_px = Vector2.ZERO

func _start_path() -> void:
	_path_last = finger
	_path_dir = Vector2.ZERO
	_sweep = 0.0
	_air_travel = 0.0

func _trace(at: Vector2) -> void:
	var d: Vector2 = at - _path_last
	var len: float = d.length()
	if len < TRICK_SEG_PX:
		return
	_air_travel += len
	if _path_dir != Vector2.ZERO:
		_sweep += rad_to_deg(_path_dir.angle_to(d))
	_path_dir = d / len
	_path_last = at
	if absf(_sweep) >= TRICK_SWEEP_DEG:
		var clockwise: bool = _sweep > 0.0
		_sweep -= 360.0 if clockwise else -360.0
		trick.emit(clockwise)

var enabled: bool = false:
	set(value):
		enabled = value
		_clear()

## For a HUD ghost, and for the probe: where the finger landed and where
## it is now. Same two fields KartTouchInput publishes, same meaning.
var anchor: Vector2 = Vector2.ZERO
var finger: Vector2 = Vector2.ZERO
var steering_active: bool = false

## ⚠️ THE WHOLE OF THE NEW CONTRACT, IN ONE FLOAT. 1.0 while a finger is
## down, 0.0 the instant it is not. It is a float and not a bool because
## that is the vocabulary `SkateBoardBody.hold()` speaks and the vocabulary
## `KartInput.throttle` already uses, and because a later lot that wants a
## pressure or a ramp writes it here without changing a single reader.
## Today it is binary, and saying so is cheaper than letting a reader
## guess.
var throttle: float = 0.0

## The captured heading, in SCREEN pixels, as an offset from the anchor.
## Zero when no finger is holding one -- and zero again whenever the
## finger comes back inside the slop, which is what "it tracks" means.
## Published raw rather than as a world vector because the mapping into
## the world needs a camera, and a camera is not this node's to hold --
## see `heading_world()`.
var heading_px: Vector2 = Vector2.ZERO

var _index: int = -1
var _mouse_down: bool = false
## Latches for the length of ONE gesture: true once the finger has left
## the slop, and never cleared until the finger lifts. It decides ONLY
## whether the release is a tap. The heading does not consult it.
var _dragged: bool = false
var _down_at_s: float = 0.0

func _clear() -> void:
	_index = -1
	_mouse_down = false
	_dragged = false
	steering_active = false
	throttle = 0.0
	_throttle_want = 0.0
	_smooth = Vector2.ZERO
	heading_px = Vector2.ZERO
	_air = false
	_sweep = 0.0
	_air_travel = 0.0
	_path_dir = Vector2.ZERO

## True while a finger is writing a heading. Distinct from
## `steering_active` (a finger is DOWN, so the throttle is held): a finger
## inside the slop is down, is propelling the board, and is not steering
## it anywhere -- it goes straight on.
func has_heading() -> bool:
	return heading_px != Vector2.ZERO

## =====================================================================
## SCREEN -> WORLD, READ OFF THE LIVE CAMERA AND NEVER WRITTEN DOWN
##
## ⚠️ CLAUDE.md, twice over: "un mot de convention de cote ne vaut rien
## sans une capture", and "une constante de cadrage se RELIT sur la camera
## livree". A constant written from today's reading would be silently
## wrong the first time a lot yaws the camera, with the symptom being a
## board that steers sideways to the thumb.
##
## ⚠️ AND LOT 2 IS THAT LOT. The board now drives the CHASE camera
## (`HubCamera.enter_drive`), which yaws with the board's own heading --
## so "screen right is world +x" is no longer even true at rest, and this
## mapping is the only thing between the thumb and a board that steers
## into the scenery. It was already derived; it is now load-bearing.
##
## The mapping is DERIVED from the camera's own basis every call: screen
## +x is the camera's right, flattened; screen -y (up the screen, away
## from the body) is the camera's forward, flattened. Both are flattened
## to XZ because the board rolls on the ground and a heading with a y in
## it would ask for a hill that is not there.
##
## SkateInputProbe PHASE M confirms the result against RENDERED PIXELS --
## drag right, and the board's drawn position moves right in the frame --
## rather than against this arithmetic, which is the only check that could
## have caught the sign error the doctrine above was written about.
func heading_world(camera: Camera3D) -> Vector3:
	if camera == null or heading_px == Vector2.ZERO:
		return Vector3.ZERO
	var basis := camera.global_transform.basis
	var right := Vector3(basis.x.x, 0.0, basis.x.z)
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z)
	if right.length() < 0.0001 or forward.length() < 0.0001:
		# A camera looking straight down has no flat right or forward. It
		# cannot happen with HubCamera's fixed pitch or with the chase
		# pose's, and it returns nothing rather than a normalised zero the
		# caller would steer on.
		return Vector3.ZERO
	var world: Vector3 = right.normalized() * heading_px.x \
		+ forward.normalized() * (-heading_px.y)
	if world.length() < 0.0001:
		return Vector3.ZERO
	return world.normalized()

## The INVERSE of `heading_world()`, for a bench: the screen offset (of
## length `px`) a finger would have to hold, under `camera`, to write
## `heading`. Pure, static, and the round trip is gated by SkateTrickProbe
## (heading_world(screen_offset_for(h)) == h to 1e-4), so a bench that
## drives the board through this writer -- the only writer there is since
## CH64 -- is steering by the same arithmetic a thumb does and not by a
## second spelling of it. Vector2.ZERO when the camera has no flat basis.
static func screen_offset_for(camera: Camera3D, heading: Vector3, px: float) -> Vector2:
	if camera == null:
		return Vector2.ZERO
	var basis := camera.global_transform.basis
	var right := Vector3(basis.x.x, 0.0, basis.x.z)
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z)
	if right.length() < 0.0001 or forward.length() < 0.0001:
		return Vector2.ZERO
	var flat := Vector3(heading.x, 0.0, heading.z)
	if flat.length() < 0.0001:
		return Vector2.ZERO
	flat = flat.normalized()
	var off := Vector2(flat.dot(right.normalized()), -flat.dot(forward.normalized()))
	if off.length() < 0.0001:
		return Vector2.ZERO
	return off.normalized() * px

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			if _index < 0:
				_begin(touch.index, touch.position)
		elif touch.index == _index:
			_end()
		get_viewport().set_input_as_handled()
		return
	var drag := event as InputEventScreenDrag
	if drag:
		if drag.index == _index:
			_move(drag.position)
		get_viewport().set_input_as_handled()
		return
	# Mouse (desktop and the probe -- emulated ones were dropped above).
	# The left button is the finger, and it writes the same two things.
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			if not _mouse_down:
				_mouse_down = true
				_begin(-2, click.position)
		elif _mouse_down:
			_mouse_down = false
			_end()
		get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion and _mouse_down:
		_move(motion.position)
		get_viewport().set_input_as_handled()

## ⚠️ THE THROTTLE OPENS ON THE PRESS, NOT ON THE FIRST DRAG. A scheme
## that waited for a heading before propelling would make the first
## millimetre of every gesture dead, and a player who presses and holds
## without sliding -- which is what "go straight" looks like -- would get
## nothing at all.
func _begin(index: int, at: Vector2) -> void:
	_index = index
	anchor = at
	finger = at
	# ⚠️ THE FILTER STARTS **ON** THE FINGER, not at zero and not where the
	# last gesture left it. A filter seeded anywhere else would spend its
	# first frames sweeping the screen from that stale point, and the board
	# would answer a heading nobody asked for on the press.
	_smooth = at
	steering_active = true
	_dragged = false
	heading_px = Vector2.ZERO
	_down_at_s = float(Time.get_ticks_msec()) / 1000.0
	if _air:
		_start_path()
	# ⚠️ THE ORDER MATTERS AND IT IS THE ONLY ORDER THAT WORKS: the listener
	# samples the board's speed on this signal, so it has to run BEFORE the
	# throttle opens. One line apart, and swapping them re-creates exactly
	# the defect the signal exists to avoid.
	pressed.emit()
	# ⚠️ CH65: THE **TARGET** OPENS ON THE PRESS, and the throttle ramps to
	# it from whatever it is. The block above is untouched in its reason --
	# the first millimetre of a gesture must not be dead -- and the only
	# change is that full push now arrives over THROTTLE_LAMBDA instead of
	# between two frames.
	_throttle_want = 1.0

func _move(at: Vector2) -> void:
	finger = at
	if _air:
		# ⚠️ THE RAW FINGER, AND ONLY THE RAW ONE. See FINGER_LAMBDA: a
		# filtered path is a shorter path, and the recogniser measures the
		# angle a path turns through per segment of it.
		_trace(at)
	# ⚠️ `_dragged` IS LATCHED ON THE RAW OFFSET, NOT THE FILTERED ONE, and
	# that is the exit gesture's contract rather than an oversight. It
	# decides only whether a release is a tap, and a thumb that has plainly
	# travelled 40 px must not read as a tap because a filter had not
	# caught up when it lifted.
	if (finger - anchor).length() >= SLOP_PX:
		_dragged = true
	# ⚠️ AND THE HEADING IS **NOT** WRITTEN HERE ANY MORE. It is a per-tick
	# quantity now (see `tick()`), so an event only moves the finger and
	# the tick decides what that means. Writing it here as well would step
	# the filter once per EVENT on top of once per FRAME, which makes its
	# time constant a function of how fast the platform coalesces drags --
	# a different filter on a phone from the one this bench measures.
	#
	# The cost is one frame: a bench that delivers a drag and reads the
	# heading in the same breath now reads ZERO, and every probe in this
	# repo that did so has been given its `physics_frame`. That is the
	# contract, not an accident of it: a thumb cannot ask for a heading
	# faster than the board can be told about one.

func _end() -> void:
	var held_s: float = float(Time.get_ticks_msec()) / 1000.0 - _down_at_s
	var was_tap: bool = not _dragged and held_s <= TAP_MAX_S
	_index = -1
	steering_active = false
	# ⚠️ THE PROPULSION GOES, THE BOARD DOES NOT. Dropping the throttle
	# stops the push; what the board already has, it keeps, and CH61's
	# coast is what ends the roll. A lift that zeroed the board's velocity
	# would read on device as a handbrake.
	#
	# ⚠️ CH65: IT GOES **AT ONCE**, not down the ramp. The ramp exists so a
	# push does not arrive as a step; a LIFT that lingered would keep
	# pushing a board the player has let go of, which is the one thing
	# neither the old scheme nor the new one may do. The target and the
	# value are both zeroed, so no tick can put it back.
	_throttle_want = 0.0
	throttle = 0.0
	heading_px = Vector2.ZERO
	_dragged = false
	_sweep = 0.0
	_air_travel = 0.0
	_path_dir = Vector2.ZERO
	if was_tap:
		tapped.emit()
