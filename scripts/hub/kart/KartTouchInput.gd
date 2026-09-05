extends Node
class_name KartTouchInput
## The PLAYER's writer of a KartInput: a thumb on the screen, or the
## keyboard off-web. The only place the touch scheme lives.
##
## =====================================================================
## THE SCHEME (journal V7, chosen before any of this was written)
##
##   * the accelerator is AUTOMATIC: while driving, throttle is 1;
##   * the FIRST finger down becomes the ANCHOR, wherever it lands. Sliding
##     it left / right of the anchor steers, proportionally, over
##     STEER_SPAN px with a DEAD_ZONE; lifting it straightens the wheels;
##   * a SECOND finger, anywhere, is the BRAKE (reverse once stopped);
##   * the keyboard (arrows / A-D, down / S) does the same off-web, so a
##     probe or the editor can drive without a touchscreen.
##
## Nothing here is a gesture that has to be RECOGNISED: a finger is either
## down or up, and a position is either left or right of where it started.
## That is what makes it reliable under a moving thumb, and it is why the
## exit is a HUD button and not a swipe.
##
## =====================================================================
## WHO SEES THE TOUCH
##
## _unhandled_input, like HubTapInput: GUI controls (the exit button, the
## dev menu) are picked first and swallow their own taps. HubTapInput
## refuses every point while the kart is driven (it asks HubKarting), so
## whichever of the two runs first, a driving touch reaches THIS node and
## a walking tap reaches THAT one -- there is no order between them to
## get wrong. Every event handled here is marked handled.
##
## Godot synthesises a mouse event from every touch (emulate_mouse_from_
## touch is on by default; CLAUDE.md documents the double dispatch it
## causes). Synthesised events carry device DEVICE_ID_EMULATION and are
## ignored here, so a finger is one finger.

const STEER_SPAN: float = 150.0
const DEAD_ZONE: float = 12.0

var input: KartInput = KartInput.new()
var enabled: bool = false:
	set(value):
		enabled = value
		_clear()
## For the HUD's ghost: where the steering finger landed and where it is.
var anchor: Vector2 = Vector2.ZERO
var finger: Vector2 = Vector2.ZERO
var steering_active: bool = false

## Seconds left before the automatic accelerator engages: HubKarting
## holds it for the length of the camera blend so the kart does not leave
## under a camera still swinging into place.
var _hold_s: float = 0.0
var _steer_index: int = -1
var _brake_index: int = -1
var _mouse_down: bool = false

func hold_throttle(seconds: float) -> void:
	_hold_s = maxf(seconds, 0.0)
	input.throttle = 0.0

func _clear() -> void:
	_hold_s = 0.0
	_steer_index = -1
	_brake_index = -1
	_mouse_down = false
	steering_active = false
	input.reset()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			if _steer_index < 0:
				_steer_index = touch.index
				anchor = touch.position
				finger = touch.position
				steering_active = true
				input.steer = 0.0
			elif _brake_index < 0 and touch.index != _steer_index:
				_brake_index = touch.index
				input.brake = true
		else:
			if touch.index == _steer_index:
				_steer_index = -1
				steering_active = false
				input.steer = 0.0
			elif touch.index == _brake_index:
				_brake_index = -1
				input.brake = false
		get_viewport().set_input_as_handled()
		return
	var drag := event as InputEventScreenDrag
	if drag:
		if drag.index == _steer_index:
			finger = drag.position
			input.steer = _steer_from(finger.x - anchor.x)
		get_viewport().set_input_as_handled()
		return
	# Mouse (desktop only -- emulated ones were dropped above): the left
	# button is the finger, the right button is the brake.
	var click := event as InputEventMouseButton
	if click:
		if click.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = click.pressed
			if click.pressed:
				anchor = click.position
				finger = click.position
				steering_active = true
			else:
				steering_active = false
			input.steer = 0.0
			get_viewport().set_input_as_handled()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			input.brake = click.pressed
			get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion and _mouse_down:
		finger = motion.position
		input.steer = _steer_from(finger.x - anchor.x)
		get_viewport().set_input_as_handled()

func _steer_from(dx: float) -> float:
	var mag: float = maxf(absf(dx) - DEAD_ZONE, 0.0)
	return clampf(signf(dx) * mag / (STEER_SPAN - DEAD_ZONE), -1.0, 1.0)

## Keyboard, polled: only when no finger / mouse is steering, so a probe
## and a thumb never fight over the same value.
func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if _hold_s > 0.0:
		_hold_s -= delta
		input.throttle = 0.0
	else:
		input.throttle = 1.0
	if steering_active:
		return
	var axis: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		axis -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		axis += 1.0
	input.steer = axis
	if _brake_index < 0:
		input.brake = Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE)
