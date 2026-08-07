extends Camera3D
class_name CameraFollow
## Smooth camera follow behind Keepy.
##
## Deliberately not parented rigidly to the player: lerping position
## each frame instead of matching the player transform 1:1 means lane
## changes and jumps read as eased camera motion rather than a camera
## glued to a jittering rig.
##
## =====================================================================
## STRIKE SHAKE -- the physical half of the non-fatal contact's feedback
## (see GameState's STRIKES block; the screen flash and the strike pips are
## the HUD's halves). The player has to know they were HIT, in the frame it
## happened, before they have had time to read anything -- a slowdown alone
## is a change of rate, and a change of rate is exactly the kind of cue that
## takes a second to notice, which is a second too late here.
##
## APPLIED THROUGH h_offset/v_offset, NEVER by moving `position`, and that is
## the whole reason this is three lines rather than a rig: those two shift
## the projection without touching the transform, so the follow lerp below
## keeps converging on the player from a clean position and the shake cannot
## feed back into it. Writing the shake into `position` would make the next
## frame's lerp start from the shaken spot, so the camera would chase its own
## noise and drift.
##
## Driven by a decaying TRAUMA value, the standard treatment: the offset is
## trauma SQUARED, so the shake falls off fast and hard at first (unmistakably
## an impact) then tails off smoothly instead of stopping dead.
##
## Deterministic sinusoids rather than randf(): two different frequencies on
## the two axes so the motion never reads as a straight line, and a probe
## replaying a seeded run gets the same camera it got last time.

@export var target: Node3D
@export var offset: Vector3 = Vector3(0.0, 4.2, 7.0)
@export var look_ahead: Vector3 = Vector3(0.0, 1.0, -4.0)
@export var follow_speed: float = 6.0

## Peak shake, in the same units h_offset/v_offset use (world units at the
## near plane). Big enough to be unmissable on a phone screen, small enough
## that a hazard the player still has to read never leaves frame.
const SHAKE_AMPLITUDE: float = 0.55
## How fast trauma bleeds off, in trauma per second: 1.0 / this is roughly
## how long a full-strength shake lasts. Kept comfortably shorter than
## GameState.STRIKE_SLOWDOWN_HOLD_S so the shake is over while the slowdown
## is still going -- the impact is an instant, the penalty is a state, and
## the two should not be confused for each other.
const SHAKE_DECAY_PER_S: float = 2.6
## The two axes shake at different rates so the motion is a wobble rather
## than a diagonal slide.
const SHAKE_HZ_X: float = 24.0
const SHAKE_HZ_Y: float = 19.0

var _trauma: float = 0.0
var _shake_t: float = 0.0

func _ready() -> void:
	GameState.strike_taken.connect(_on_strike_taken)

## Full trauma on every strike, including the one that ends the run: the last
## hit is the one that most deserves to be felt.
func _on_strike_taken(_source_type: int, _strikes_used: int) -> void:
	_trauma = 1.0
	_shake_t = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired_position := target.position + offset
	position = position.lerp(desired_position, 1.0 - exp(-follow_speed * delta))
	look_at(target.position + look_ahead, Vector3.UP)
	_update_shake(delta)

func _update_shake(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY_PER_S * delta)
	_shake_t += delta
	var magnitude := SHAKE_AMPLITUDE * _trauma * _trauma
	h_offset = magnitude * sin(_shake_t * TAU * SHAKE_HZ_X)
	v_offset = magnitude * sin(_shake_t * TAU * SHAKE_HZ_Y)
	if _trauma > 0.0:
		return
	# Zeroed explicitly on the last frame rather than left at whatever the
	# sine happened to be: a magnitude of 0 is not guaranteed to land exactly
	# on 0 offset, and a camera permanently a hair off-centre is the kind of
	# thing nobody finds for months.
	h_offset = 0.0
	v_offset = 0.0
