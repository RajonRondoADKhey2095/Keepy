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
## THE MODE, AND WHY IT IS A STATIC HERE
##
## The A/B Mathieu performs is TAP versus DRAG on one build, flipped from
## the in-game menu with no reload -- so the answer has to be readable by
## three files (HubTapInput, to short-circuit; HubTransport, to arm the
## writer; HubWorld, to draw the button) and writable by one. A static on
## the class that DEFINES the mode is the single publication point
## CLAUDE.md's "un fait est publie une fois" asks for.
##
## NOT on DevTools: that file gates what a developer may SEE, and this is
## not a visibility question -- it is a control scheme. It is gated BY
## DevTools.enabled() at the button, which is where the gating belongs.
##
## Defaults FALSE: the shipped tap scheme is what a build behaves like
## until somebody deliberately asks for the other one.
static var _drag_mode: bool = false

static func drag_enabled() -> bool:
	return _drag_mode

## Flips the scheme. The caller is responsible for re-arming whatever was
## armed under the old answer -- HubTransport.sync_board_input() is the
## one call that does it, and HubWorld's button makes it.
static func set_drag_mode(on: bool) -> void:
	_drag_mode = on

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
	heading_px = Vector2.ZERO

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
	steering_active = true
	_dragged = false
	heading_px = Vector2.ZERO
	_down_at_s = float(Time.get_ticks_msec()) / 1000.0
	# ⚠️ THE ORDER MATTERS AND IT IS THE ONLY ORDER THAT WORKS: the listener
	# samples the board's speed on this signal, so it has to run BEFORE the
	# throttle opens. One line apart, and swapping them re-creates exactly
	# the defect the signal exists to avoid.
	pressed.emit()
	throttle = 1.0

func _move(at: Vector2) -> void:
	finger = at
	var offset: Vector2 = finger - anchor
	if offset.length() < SLOP_PX:
		# Back inside the slop: no heading, so the board goes straight on
		# from wherever it is now. The throttle is untouched -- the finger
		# is still down, so the board is still being propelled.
		heading_px = Vector2.ZERO
		return
	_dragged = true
	heading_px = offset

func _end() -> void:
	var held_s: float = float(Time.get_ticks_msec()) / 1000.0 - _down_at_s
	var was_tap: bool = not _dragged and held_s <= TAP_MAX_S
	_index = -1
	steering_active = false
	# ⚠️ THE PROPULSION GOES, THE BOARD DOES NOT. Dropping the throttle
	# stops the push; what the board already has, it keeps, and CH61's
	# coast is what ends the roll. A lift that zeroed the board's velocity
	# would read on device as a handbrake.
	throttle = 0.0
	heading_px = Vector2.ZERO
	_dragged = false
	if was_tap:
		tapped.emit()
