extends Node
class_name SkateTouchInput
## CH63 LOT 1 -- THE BOARD'S OWN INPUT WRITER: a thumb that HOLDS a
## direction, and a tap that PUSHES.
##
## =====================================================================
## WHAT THIS LOT IS, AND WHAT IT DELIBERATELY IS NOT
##
## This file CAPTURES a gesture. It does not drive anything: it writes a
## heading and it emits a push, and an ADAPTER in HubTransport turns those
## two facts into the `set_target()` call the shipped board already
## understands. Nothing in SkateBoardBody.drive() and nothing in CH61's
## inertia model is touched by this lot, on purpose -- the question being
## answered is "does the capture work", not "does the board feel better",
## and answering both in one lot would leave neither measurable.
##
## The camera stays FIXED here too. CLAUDE.md's camera table puts a
## CONTINUOUSLY PILOTED vehicle on the chase camera, and a held drag is
## exactly that -- so the board WILL move to the chase camera. That is
## LOT 2, scoped separately, because a chase camera shows the decor at
## azimuths the fixed frame never has and CLAUDE.md requires a ChaseAudit
## pass for it (CH30 found two real defects in a hub two visual audits had
## already called clean).
##
## =====================================================================
## THE SCHEME
##
##   * the FIRST finger down becomes the ANCHOR, wherever it lands --
##     KartTouchInput's pattern, copied rather than reinvented, because it
##     is the one touch scheme in this repo that has survived a device;
##   * sliding that finger away from the anchor writes a HEADING: the
##     direction of the offset, mapped into the world through the LIVE
##     camera basis, held for as long as the finger holds it;
##   * lifting the finger without having left the anchor's slop is a TAP,
##     and a tap emits `pushed` -- a SEPARATE channel from the heading,
##     which is what makes "relaunch a stopped board" expressible without
##     a second gesture to learn;
##   * lifting after a drag simply stops writing a heading. It does NOT
##     stop the board: the elan CH61 gave it is the whole point, and a
##     lift that braked would be a handbrake nobody asked for.
##
## ⚠️ ONE NUMBER SEPARATES THE TWO GESTURES, AND IT IS THE SAME NUMBER
## BOTH WAYS. Below `SLOP_PX` from the anchor there is no heading and a
## release is a push; above it there is a heading and a release is not a
## push. Written once as one constant because "what counts as a drag" and
## "what still counts as a tap" are the same question asked from two
## sides, and two constants would let a gap or an overlap open between
## them that nothing would report.
##
## ⚠️ AND THIS FILE DOES RECOGNISE A GESTURE, WHICH KartTouchInput
## POINTEDLY DOES NOT. Its header says so in as many words ("nothing here
## is a gesture that has to be RECOGNISED"), and that is a real property
## worth keeping -- but the brief asks for two meanings on one finger, so
## a threshold is not avoidable, only namable. It is named here, it is the
## only one, and SkateInputProbe gates it from BOTH sides (a 4 px jitter
## is still a tap; a 40 px slide is not).
##
## =====================================================================
## WHO SEES THE TOUCH
##
## `_unhandled_input`, like HubTapInput and KartTouchInput: GUI controls
## are picked first and swallow their own taps. HubTapInput short-circuits
## every point while a DRAG-mode board is ridden (one condition per driven
## thing, the shape the three piloted vehicles already use), so whichever
## of the two nodes runs first, a riding touch reaches THIS node and a
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
## SkateInputProbe's red pass removed it and came back ALL GREEN, twice,
## including through the engine (PHASE E). The anchor logic below happens
## to survive the pair in the orders this bench can produce, so what the
## guard buys is not measurable here -- it is kept as the shipped writer's
## own defence and not as a property this lot has proved.

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
## held motionless for a second is not a push -- it is a player thinking,
## and pushing under him would be the screen guessing.
const TAP_MAX_S: float = 0.45

## Emitted on a short tap that never became a drag. The board's "push".
## Carries nothing: WHERE the finger landed is deliberately not part of
## it, because a push is about the board's own heading and not about a
## destination -- that is the whole difference between this lot's scheme
## and the tap scheme it is offered against.
signal pushed

var enabled: bool = false:
	set(value):
		enabled = value
		_clear()

## For a HUD ghost, and for the probe: where the finger landed and where
## it is now. Same two fields KartTouchInput publishes, same meaning.
var anchor: Vector2 = Vector2.ZERO
var finger: Vector2 = Vector2.ZERO
var steering_active: bool = false

## The captured heading, in SCREEN pixels, as an offset from the anchor.
## Zero when no finger is holding one. Published raw rather than as a
## world vector because the mapping into the world needs a camera, and a
## camera is not this node's to hold -- see `heading_world()`.
var heading_px: Vector2 = Vector2.ZERO

var _index: int = -1
var _mouse_down: bool = false
var _dragged: bool = false
var _down_at_s: float = 0.0

func _clear() -> void:
	_index = -1
	_mouse_down = false
	_dragged = false
	steering_active = false
	heading_px = Vector2.ZERO

## True while a finger is writing a heading. Distinct from
## `steering_active` (a finger is DOWN): a finger inside the slop is down
## and is not yet steering anything.
func has_heading() -> bool:
	return heading_px != Vector2.ZERO

## =====================================================================
## SCREEN -> WORLD, READ OFF THE LIVE CAMERA AND NEVER WRITTEN DOWN
##
## ⚠️ CLAUDE.md, twice over: "un mot de convention de cote ne vaut rien
## sans une capture", and "une constante de cadrage se RELIT sur la camera
## livree". The hub camera's yaw is 0 in the scene today, so "screen right
## is world +x" happens to be true -- and a constant written from that
## reading would be silently wrong the first time a lot yaws the camera,
## with the symptom being a board that steers sideways to the thumb.
##
## So the mapping is DERIVED from the camera's own basis every call:
## screen +x is the camera's right, flattened; screen -y (up the screen,
## away from the body) is the camera's forward, flattened. Both are
## flattened to XZ because the board rolls on the ground and a heading
## with a y in it would ask for a hill that is not there.
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
		# cannot happen with HubCamera's fixed pitch, and it returns
		# nothing rather than a normalised zero the caller would steer on.
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

func _begin(index: int, at: Vector2) -> void:
	_index = index
	anchor = at
	finger = at
	steering_active = true
	_dragged = false
	heading_px = Vector2.ZERO
	_down_at_s = float(Time.get_ticks_msec()) / 1000.0

func _move(at: Vector2) -> void:
	finger = at
	var offset: Vector2 = finger - anchor
	if offset.length() < SLOP_PX:
		# Still inside the slop: no heading yet, and a release from here
		# is still a tap. NOT cleared back to a tap once it has left --
		# `_dragged` latches, so a slide that comes back through the
		# anchor does not turn into a push under the player's thumb.
		return
	_dragged = true
	heading_px = offset

func _end() -> void:
	var held_s: float = float(Time.get_ticks_msec()) / 1000.0 - _down_at_s
	var was_tap: bool = not _dragged and held_s <= TAP_MAX_S
	_index = -1
	steering_active = false
	# ⚠️ THE HEADING GOES, THE BOARD DOES NOT. Clearing this stops the
	# adapter re-issuing a destination; what the board already has, it
	# keeps, and CH61's run-out is what ends the roll. A lift that
	# cleared the board's target would zero its velocity (clear_target
	# does, deliberately) and read on device as a handbrake.
	heading_px = Vector2.ZERO
	_dragged = false
	if was_tap:
		pushed.emit()
