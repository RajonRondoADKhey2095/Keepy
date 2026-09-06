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
##     it left / right of the anchor steers, proportionally, over a span
##     set by the active KartTuning preset, with a dead zone; lifting it
##     straightens the wheels;
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
## V7b -- THE ACCELERATOR (Mathieu's retour 1)
##
## The cruise (automatic throttle = 1) is UNCHANGED, on purpose (CLAUDE.md
## brief: "l'accelerateur ne doit pas rendre le pilotage plus exigeant").
## What was added is a BOOST layered on top, and it reuses the vertical
## half of the SAME steering drag rather than a new touch zone or the
## already-taken second finger (brake): the horizontal offset from the
## anchor was already the only thing read from `finger`, the vertical
## offset was sitting there unused. Pushing the anchor finger UP the
## screen (away from the body, like a lever) commands boost, over
## BOOST_SPAN px with BOOST_DEAD_ZONE; pushing down or not moving does
## nothing -- there is no way to go SLOWER than cruise from this gesture,
## only faster, so it cannot be mistaken for the brake. Diagonal drags
## (steer + push) work naturally since both axes come from one drag event.
## Keyboard gets the matching, unclaimed key: UP / W, alongside the
## existing LEFT-RIGHT/A-D steer and DOWN/S brake -- nothing reassigned.
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

## V7b: the steer span/dead zone/curve are no longer literals here -- they
## come live from the active KartTuning preset (see KartTuning.gd for the
## measured diagnosis). The accelerator's push span is NOT part of that
## preset scale (a separate retour, a separate axis).
##
## =====================================================================
## CH31 -- THE ACCELERATOR EXISTED AND WAS NOT FOUND
##
## Mathieu's retour: "je n'arrive pas a accelerer et je ne sais pas si la
## commande existe". The recon answer is that it DOES exist -- V7b's
## vertical push of the anchor finger, with a HUD hint line and a ghost.
## Three things made it undiscoverable, and all three are defects rather
## than preferences:
##
##  1. THE AFFORDANCE ONLY APPEARED ONCE A FINGER WAS ALREADY DOWN. The
##     ghost is drawn from `_ghost_active`, so a player who has not yet
##     touched the screen is shown nothing at all. Fixed in KartHud: the
##     boost gauge is now drawn for the whole drive, empty, and fills.
##  2. LIFTING THE FINGER KILLED IT. The scheme's own documentation tells
##     the player that lifting straightens the wheels -- which is exactly
##     what one does on a straight, and the straight is exactly where the
##     boost is worth having. So the natural gesture cancelled the
##     mechanic. Fixed by `boost_release_s`: the push DECAYS instead of
##     snapping to zero.
##  3. THE PUSH WAS EXPENSIVE. 150 px of travel on top of a steering drag,
##     with a 24 px dead zone, is a thumb reaching across a phone.
##
## ⚠️ THESE ARE INSTANCE VALUES, NOT CONSTANTS, AND THAT IS LOAD-BEARING.
## The sand yacht is driven by a SECOND KartTouchInput (HubTransport), and
## its sheeting gesture is Mathieu-validated CH30 work the brief freezes.
## Making these per-instance lets the kart change while the yacht keeps
## the exact numbers it shipped with -- the defaults below ARE the shipped
## ones, so an instance nobody configures is byte-identical to V7b.
const BOOST_SPAN: float = 150.0
const BOOST_DEAD_ZONE: float = 24.0
const BOOST_RELEASE_S: float = 0.0
## The kart's own values (CH31). Set by HubKarting on its instance only.
const KART_BOOST_SPAN: float = 105.0
const KART_BOOST_DEAD_ZONE: float = 14.0
const KART_BOOST_RELEASE_S: float = 0.45

var boost_span: float = BOOST_SPAN
var boost_dead_zone: float = BOOST_DEAD_ZONE
## How long the push takes to bleed away after the finger lifts. 0 = the
## V7b behaviour (it dies with the finger).
var boost_release_s: float = BOOST_RELEASE_S

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
## >0 while a lifted push is bleeding away.
var _boost_decay: float = 0.0
var _steer_index: int = -1
var _brake_index: int = -1
var _mouse_down: bool = false

func hold_throttle(seconds: float) -> void:
	_hold_s = maxf(seconds, 0.0)
	input.throttle = 0.0

## CH31: the finger has gone; the push bleeds away over `boost_release_s`
## instead of vanishing. A release of 0 reproduces V7b exactly.
func _release_boost() -> void:
	if boost_release_s <= 0.0:
		input.boost = 0.0
	else:
		_boost_decay = input.boost

func _clear() -> void:
	_hold_s = 0.0
	_boost_decay = 0.0
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
				input.boost = 0.0
			elif _brake_index < 0 and touch.index != _steer_index:
				_brake_index = touch.index
				input.brake = true
		else:
			if touch.index == _steer_index:
				_steer_index = -1
				steering_active = false
				input.steer = 0.0
				_release_boost()
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
			input.boost = _boost_from(anchor.y - finger.y)
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
			if click.pressed:
				input.boost = 0.0
			else:
				_release_boost()
			get_viewport().set_input_as_handled()
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			input.brake = click.pressed
			get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion and _mouse_down:
		finger = motion.position
		input.steer = _steer_from(finger.x - anchor.x)
		input.boost = _boost_from(anchor.y - finger.y)
		get_viewport().set_input_as_handled()

## Linear offset -> [0, 1] fraction of the active preset's span, then
## reshaped by its curve exponent (>1: a small offset buys proportionally
## less steer, full offset still reaches 1.0) -- V7b, see KartTuning.gd.
func _steer_from(dx: float) -> float:
	var span: float = KartTuning.steer_span()
	var dead: float = KartTuning.dead_zone()
	var mag: float = maxf(absf(dx) - dead, 0.0)
	var u: float = clampf(mag / (span - dead), 0.0, 1.0)
	return signf(dx) * pow(u, KartTuning.curve_exp())

## Positive-only: pushing the anchor finger UP the screen (dy > 0) buys
## boost linearly over BOOST_SPAN; pushing down or not moving buys none.
func _boost_from(dy: float) -> float:
	_boost_decay = 0.0
	var mag: float = maxf(dy - boost_dead_zone, 0.0)
	return clampf(mag / maxf(boost_span - boost_dead_zone, 1.0), 0.0, 1.0)

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
	if _boost_decay > 0.0:
		input.boost = maxf(input.boost - delta / maxf(boost_release_s, 0.001), 0.0)
		if input.boost <= 0.0:
			_boost_decay = 0.0
	if steering_active:
		return
	var axis: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		axis -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		axis += 1.0
	input.steer = axis
	input.boost = 1.0 if (Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)) else 0.0
	if _brake_index < 0:
		input.brake = Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE)
