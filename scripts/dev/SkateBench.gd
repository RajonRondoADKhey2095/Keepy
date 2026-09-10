extends Node
class_name SkateBench
## CH64 -- A BENCH THAT DRIVES THE BOARD THE WAY A THUMB DOES.
##
## =====================================================================
## WHY THIS FILE EXISTS
##
## Until CH64 the physics probes rolled the board with
## `HubTransport.set_board_target(point)`: the TAP scheme's destination
## adapter, which turned a point into a heading and a throttle every tick
## and braked into its arrival. CH64 deleted that adapter with the TAP
## scheme -- the finger is the board's only writer now -- and a probe that
## called `SkateBoardBody.hold()` directly instead would be overwritten on
## the next tick by `HubTransport._advance_board`, which releases the board
## whenever the writer holds nothing. There is exactly one way to command
## a ridden board, and it is `SkateTouchInput`.
##
## So the bench holds a finger. A destination becomes, each physics tick,
## the screen offset a thumb would have to hold under the LIVE camera to
## point the board at it -- `SkateTouchInput.screen_offset_for`, the
## published inverse of the writer's own mapping -- delivered to the writer
## as an `InputEventScreenDrag`, exactly the event the engine delivers. It
## is CLAUDE.md's "toute sonde de pilotage passe par le VRAI canal
## d'input" for the physics family, and it is what makes a probe measure
## the board a player rides rather than a body nothing else can command.
##
## ⚠️ WHAT IT CANNOT DO, BY DESIGN: brake. A finger has no brake gesture,
## so a bench destination is REACHED by lifting the finger inside the
## arrival radius and letting CH61's coast do the rest -- the board rolls
## a little past the point, which is what a player's board does too. A
## phase that needs the board to STOP somewhere waits for `at_rest()`.
##
## The stall guard survives here, as a BENCH property: a run that makes no
## progress for STALL_TICKS lifts the finger and says so (`stalled_out()`),
## so a probe that aims into a wall does not hold the throttle open for
## the length of its budget. Nothing in the game does this any more -- a
## player's finger is the guard, and it lifts.
##
## ⚠️ THE DRAG IS DELIVERED RELATIVE TO THE WRITER'S OWN ANCHOR, never to a
## fixed pixel: the writer MOVES its anchor under the finger on a landing
## (SkateTouchInput.set_air), and a bench that kept dragging to an absolute
## point would lose its heading on every air. `_touch.anchor` is read
## each tick.
##
## Runs BEFORE HubTransport in the physics tick (process_physics_priority)
## so the command it writes is the one that tick spends.

const HOLD_PX: float = 140.0
const STALL_TICKS: int = 30
## Where the bench's finger lands. Any pixel: the writer's mapping is
## relative to its anchor, and a bench never projects this point.
const ANCHOR: Vector2 = Vector2(540.0, 1300.0)

var _transport: HubTransport = null
var _camera: Camera3D = null
var _touch: SkateTouchInput = null
var _down: bool = false
var _dest: Vector3 = Vector3.ZERO
var _has_dest: bool = false
var _arrive: float = 0.45
var _best: float = 1e9
var _stalled: int = 0
var _stalled_out: bool = false
## Ticks since the current aim() was issued, and the tick at which the
## progress guard lifted the finger (-1 if it has not). Published so a
## probe can tell "the board stopped" from "the bench let go".
var _ticks: int = 0
var _stalled_at: int = -1
var _heading: Vector3 = Vector3.ZERO
var _holding: bool = false
var _finger: Vector2 = ANCHOR
## A speed the bench feathers the throttle under: above it the finger is
## lifted for a tick, below it pressed again. INF means a held finger.
## A thumb can feather too; what it cannot do is brake, and the phases
## that need a SLOW arrival (a leg the board must be STOPPED by, a wall
## it must be held against) ask for one this way rather than through the
## brake the deleted TAP adapter had.
var _speed_cap: float = INF

func _ready() -> void:
	process_physics_priority = -100

func setup(transport: HubTransport, camera: Camera3D) -> void:
	_transport = transport
	_camera = camera
	_touch = transport.board_touch()

func has_destination() -> bool:
	return _has_dest

func is_holding() -> bool:
	return _holding or _has_dest

func is_down() -> bool:
	return _down

func stalled_out() -> bool:
	return _stalled_out

func stalled_at() -> int:
	return _stalled_at

func ticks() -> int:
	return _ticks

## Roll toward `point` and lift the finger inside `arrive` of it. Commands
## the board ON THE SPOT as well as on every following tick, which is what
## `set_board_target` did and what five probes that ask the board what it
## is doing in the same frame rely on.
func aim(point: Vector3, arrive: float = KeepyHopper.ARRIVE_EPSILON, speed_cap: float = INF) -> void:
	_dest = Vector3(point.x, 0.0, point.z)
	_arrive = arrive
	_speed_cap = speed_cap
	_has_dest = true
	_holding = false
	_stalled = 0
	_stalled_out = false
	_ticks = 0
	_stalled_at = -1
	var body := _transport.board_body() if _transport != null else null
	_best = body.flat_position().distance_to(_dest) if body != null else 1e9
	_press()
	_step()

## Hold a WORLD heading for as long as nobody says otherwise. ZERO means
## "straight on" -- a finger pressed and not slid.
func hold(heading: Vector3) -> void:
	var flat := Vector3(heading.x, 0.0, heading.z)
	_heading = flat.normalized() if flat.length() > 0.0001 else Vector3.ZERO
	_holding = true
	_has_dest = false
	_speed_cap = INF
	_press()
	_step()

func hold_straight() -> void:
	hold(Vector3.ZERO)

## Lifts the finger. The board keeps its elan (CH61).
func release() -> void:
	_has_dest = false
	_holding = false
	if _down and _touch != null:
		_touch._unhandled_input(_release_event(_finger))
	_down = false

## The EXIT gesture: a press and a release with no slide between them.
func tap() -> void:
	release()
	_press()
	release()

func _physics_process(_delta: float) -> void:
	if _has_dest or _holding:
		_step()

func _press() -> void:
	if _down or _touch == null:
		return
	_finger = ANCHOR
	_touch._unhandled_input(_press_event(ANCHOR))
	_down = true

func _step() -> void:
	if _transport == null or _touch == null:
		return
	var body := _transport.board_body()
	if body == null or not _transport.is_riding_board() or not _touch.enabled:
		release()
		return
	var heading: Vector3 = _heading
	if _has_dest:
		_ticks += 1
		var here: Vector3 = body.flat_position()
		var to: Vector3 = _dest - here
		var remaining: float = to.length()
		if remaining <= _arrive:
			release()
			return
		if remaining < _best - SkateBoardBody.REST_STEP:
			_best = remaining
			_stalled = 0
		else:
			_stalled += 1
		if _stalled >= STALL_TICKS:
			_stalled_out = true
			_stalled_at = _ticks
			release()
			return
		heading = to / remaining
		# Feathering: lift above the cap, press again under nine tenths
		# of it. The heading is still written on the tick it presses.
		if body.speed() > _speed_cap:
			if _down:
				_touch._unhandled_input(_release_event(_finger))
				_down = false
			return
		if not _down and body.speed() < _speed_cap * 0.9:
			_press()
	var off: Vector2 = Vector2.ZERO
	if heading != Vector3.ZERO:
		off = SkateTouchInput.screen_offset_for(_camera, heading, HOLD_PX)
	_finger = _touch.anchor + off
	_touch._unhandled_input(_drag_event(_finger))

func _press_event(at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = true
	e.position = at
	return e

func _release_event(at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = false
	e.position = at
	return e

func _drag_event(at: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = at
	return e
