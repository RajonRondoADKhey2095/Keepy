extends RefCounted
class_name KartLineInput
## A TEST DRIVER: writes a KartInput by chasing a point ahead on the
## track's ideal line (pure pursuit). Lives under scripts/dev -- excluded
## from the export -- because carte-blanche V7 ships NO opponent; it
## exists so KartProbe can drive a real lap through the real physics and
## gate the chrono. It is also, verbatim, what a lot-2 follower starts
## from: move this file under scripts/hub/kart and give it a kart.

const LOOKAHEAD: float = 6.5
const FAR_LOOKAHEAD: float = 14.0
const STEER_GAIN: float = 1.0 / 0.55
const SLOW_TURN_RAD: float = 0.55
const SLOW_THROTTLE: float = 0.62

var _track: KartTrack = null
var _hint: int = -1

func setup(track: KartTrack) -> void:
	_track = track
	_hint = -1

func drive(kart: KartBody, input: KartInput) -> void:
	if _track == null:
		return
	var progress: Dictionary = _track.progress_at(kart.global_position, _hint)
	_hint = int(progress["index"])
	var s: float = float(progress["s"])
	var target: Vector3 = _track.point_at(_track_s(s + LOOKAHEAD))
	var far: Vector3 = _track.point_at(_track_s(s + FAR_LOOKAHEAD))
	var to: Vector3 = target - kart.global_position
	var want_yaw: float = atan2(to.x, to.z)
	var delta: float = wrapf(want_yaw - kart.rotation.y, -PI, PI)
	# steer > 0 turns RIGHT, i.e. yaw DECREASES (KartBody.drive).
	input.steer = clampf(-delta * STEER_GAIN, -1.0, 1.0)
	var to_far: Vector3 = far - kart.global_position
	var far_delta: float = absf(wrapf(atan2(to_far.x, to_far.z) - kart.rotation.y, -PI, PI))
	input.throttle = SLOW_THROTTLE if far_delta > SLOW_TURN_RAD else 1.0
	input.brake = false

## progress_at's s is measured from the start line; point_at's from the
## spine's first sample. Convert.
func _track_s(s_from_line: float) -> float:
	return _track.start_line_offset() + s_from_line
