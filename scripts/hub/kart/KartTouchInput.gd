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
##   * sliding the SAME anchor finger UP the screen asks for more pace and
##     sliding it DOWN asks to go backwards -- ONE axis, CH43, and the
##     second finger CH42 used for the gear no longer exists. CH81 makes
##     that DOWN half a per-instance LICENCE (`allows_reverse`): the kart
##     refuses it, the four vehicles HubTransport drives keep it;
##   * the keyboard (arrows / A-D, up / W, down / S) does the same off-web,
##     so a probe or the editor can drive without a touchscreen.
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
## BOOST_SPAN px with BOOST_DEAD_ZONE. Diagonal drags (steer + push) work
## naturally since both axes come from one drag event. Keyboard gets the
## matching, unclaimed key: UP / W, alongside the existing LEFT-RIGHT/A-D
## steer and DOWN/S brake -- nothing reassigned.
##
## =====================================================================
## CH43 -- THE DOWN HALF OF THAT SAME AXIS IS THE REVERSE
##
## Mathieu drove CH42's gear on device and refused the gesture: a second
## finger is a thing to LEARN, and nothing else in this game asks for one.
## His decision, and it is not re-argued here -- ONE axis, the one the
## thumb is already on: up is forward, down is backward.
##
## So the vertical offset is now SIGNED. `dy > 0` buys boost exactly as
## V7b/CH31 did, over the same span with the same dead zone; `dy < 0` buys
## `input.reverse` over the MIRROR of that span, so the travel that reaches
## full pace one way reaches full gear the other. Nothing about a KartInput
## changed: the two fields CH42 separated are still two fields, still read
## by the same VehicleDrive branches. What changed is the WRITER, which is
## the whole point -- the physics of the gear (REVERSE_SPEED,
## REVERSE_ACCEL, SledBody.reverse_authority()) is CH42's and is untouched.
##
## ⚠️ WHY IT IS TWO FIELDS AND NOT ONE SIGNED `throttle`. A fused axis was
## the other option the brief allowed, and it was measured against the
## blast radius rather than the elegance: `throttle` is held at 1.0 by this
## file (the automatic cruise) and written 0..1 by KartAiDriver, by
## KartLineInput and by every probe's `set_all` -- a sign on it would reach
## all of them for one gesture's sake. The gesture is a property of a
## THUMB; `throttle` is a contract between three writers and one body.
## Fusing them would put a UX retour inside a shared component, which is
## the shape of defect CLAUDE.md's "un fait est publie une fois" section
## exists to stop.
##
## ⚠️ AND THE GEAR IS NOT THE BRAKE, EVEN THOUGH DOWN FEELS LIKE ONE. The
## guard-rail Mathieu asked for -- a downward slide on a vehicle still
## rolling forward BRAKES and does not slam into reverse -- is not written
## here at all. It is VehicleDrive.REVERSE_ENGAGE_SPEED, where it has been
## since CH42, and this file would be the wrong place for it: an input
## writer cannot see a speed. Naming it there is what CH43 added; the value
## is CH42's 0.3 to the digit and ReverseProbe PHASE THRESHOLD measures it
## off the vehicle rather than reading it back.
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

## ⚠️ CH81 -- WHETHER THE DOWN HALF OF THE AXIS IS A GEAR AT ALL.
##
## Mathieu's retour, device in hand: on the CIRCUIT Keepy must not be able
## to back up. On the quad, the sled, the sand yacht and the sailboat the
## gear stays exactly as CH42/CH43 shipped it. This is a decision about ONE
## vehicle and it is NOT a revision of the scheme -- which is why it is an
## instance value defaulting to TRUE, for precisely the reason `boost_span`
## above is one: this file has TWO instances. HubKarting opts its kart out;
## HubTransport's "YachtTouch" -- the single writer those four vehicles all
## share -- is not configured and therefore keeps the whole axis, as does
## every probe that constructs a bare instance (YachtTraceProbe, CoveProbe,
## ReverseProbe PHASE GESTURE). An instance nobody configures is
## byte-identical to CH43.
##
## ⚠️ IT IS A PROPERTY OF THE WRITER AND NOT OF THE BODY, and that is the
## whole design. VehicleDrive's reverse branch is UNTOUCHED: it still
## serves three vehicles by thumb, and `input.brake` still reverses any
## kart on the grid at a standstill, which is the branch KartAiDriver
## presses. Zeroing KartBody.REVERSE_SPEED instead would have turned the
## gear into a HOLD-AT-ZERO and reached the opponents' brake with it -- a
## new blocking state, which is what the brief forbade.
##
## ⚠️ AND WHAT THE REFUSED GESTURE DOES IS NOTHING, DELIBERATELY. A thumb
## below the anchor buys `boost = 0`, which is what `_fraction(0)` buys at
## the anchor anyway; `throttle` stays at the automatic 1.0. So pulling
## down on the kart costs the push and nothing else -- no brake, no
## freewheel, no new state a player can be stuck in.
##
## ⚠️ WHAT IT COSTS IS MEASURED AND IT IS NOT NOTHING. The gear was the
## only way off a fence: KartPinRecon (throwaway, CH81) drove the kart into
## KartTrack.fence() and held full lock for 10 s with no gear -- nose-on at
## a standstill, 52 of 52 stations never got 4 u away (farthest excursion
## 1.431 u on an edge, 0.424 u in a corner), and from a DRIVEN contact left
## to settle, 3 of 12 states could not steer out, the dead-on one in
## NEITHER direction (0.352 u in 10 s). The cause is CH42's arithmetic
## unchanged -- VehicleDrive gains steering on |v_fwd| and the wall eats
## v_fwd, 0.0128 u/s settled against a STEER_FULL_SPEED of 4.5, so 0.28 %
## of full lock -- and the kart cannot even stop pushing, its accelerator
## being automatic. The remaining way out is the HUD's exit button, which
## ends the race. Reported, not fixed: a steering floor at zero speed is
## turning physics the brief froze.
var allows_reverse: bool = true

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
var _mouse_down: bool = false

func hold_throttle(seconds: float) -> void:
	_hold_s = maxf(seconds, 0.0)
	input.throttle = 0.0

## CH31: the finger has gone; the push bleeds away over `boost_release_s`
## instead of vanishing. A release of 0 reproduces V7b exactly.
##
## ⚠️ CH43 -- THE GEAR IS RELEASED HARD, AND THE ASYMMETRY IS DELIBERATE.
## CH31's decay exists because lifting the thumb on a STRAIGHT is the
## natural gesture and it was killing the boost. Nothing about that is true
## downhill of the anchor: a gear that kept backing the vehicle up for
## 0.45 s after the thumb left is a vehicle reversing into whatever the
## player just lifted their thumb to avoid. Up decays, down stops.
func _release_axis() -> void:
	input.reverse = 0.0
	if boost_release_s <= 0.0:
		input.boost = 0.0
	else:
		_boost_decay = input.boost

func _clear() -> void:
	_hold_s = 0.0
	_boost_decay = 0.0
	_steer_index = -1
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
				input.reverse = 0.0
		else:
			if touch.index == _steer_index:
				_steer_index = -1
				steering_active = false
				input.steer = 0.0
				_release_axis()
		get_viewport().set_input_as_handled()
		return
	var drag := event as InputEventScreenDrag
	if drag:
		if drag.index == _steer_index:
			finger = drag.position
			input.steer = _steer_from(finger.x - anchor.x)
			_apply_axis(anchor.y - finger.y)
		get_viewport().set_input_as_handled()
		return
	# Mouse (desktop only -- emulated ones were dropped above): the left
	# button is the finger, and it drives the same two axes a thumb does.
	# CH43 removed the right button with the second finger it stood in for:
	# a desktop tester who reached for it would be testing a scheme the
	# phone no longer has, which is worse than having no shortcut at all.
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
				input.reverse = 0.0
			else:
				_release_axis()
			get_viewport().set_input_as_handled()
		return
	var motion := event as InputEventMouseMotion
	if motion and _mouse_down:
		finger = motion.position
		input.steer = _steer_from(finger.x - anchor.x)
		_apply_axis(anchor.y - finger.y)
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

## CH43 -- THE ONE AXIS. `dy` is the offset of the finger from its anchor,
## POSITIVE UP the screen, and it writes both halves of the gesture:
##
##   dy > 0   boost  = fraction of the span, reverse = 0   (V7b/CH31, exact)
##   dy < 0   reverse = fraction of the span, boost   = 0   (CH43)
##   dy < 0   reverse = 0                   , boost   = 0   (CH81, no licence)
##
## The same span and the same dead zone serve both directions, so the
## travel that buys full pace one way buys full gear the other -- which is
## what "exactement symetrique du geste d'avancer" means as an arithmetic
## and not as an intention. `_fraction` is the V7b mapping, unchanged, and
## calling it on |dy| is what makes the two halves provably the same shape.
##
## ⚠️ EXCLUSIVE, and it has to be: a thumb cannot ask for both, and letting
## a stale boost survive a downward slide would leave VehicleDrive raising
## its speed cap (`cap *= lerpf(1, boost_speed_ratio, boost)`) for a
## vehicle the player is trying to stop.
func _apply_axis(dy: float) -> void:
	_boost_decay = 0.0
	if dy >= 0.0:
		input.boost = _fraction(dy)
		input.reverse = 0.0
	else:
		input.boost = 0.0
		# CH81: on a writer without the licence the down half is inert.
		# Written as an explicit 0.0 rather than left alone: a KartInput is
		# HELD by contract, so "not writing it" would leave whatever the
		# last event asked for sitting there.
		input.reverse = _fraction(-dy) if allows_reverse else 0.0

## Linear offset -> [0, 1] over the span, past the dead zone. V7b's
## `_boost_from` body to the digit; only its name and its callers changed.
func _fraction(mag_px: float) -> float:
	var mag: float = maxf(mag_px - boost_dead_zone, 0.0)
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
	# CH43: the keyboard was ALREADY one axis -- UP/W and DOWN/S are the two
	# ends of the same row of keys. Only the guard on the second finger's
	# index is gone, because there is no second finger to defer to.
	#
	# CH81: the SAME one licence as the thumb, and it has to be the same
	# one. A keyboard that could still reverse would be a scheme the phone
	# does not have -- and it is the keyboard a probe and the editor drive,
	# so a disagreement between the two would be invisible from device and
	# green on the bench.
	input.reverse = 1.0 if (allows_reverse and (Input.is_key_pressed(KEY_DOWN)
		or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE))) else 0.0
