extends RefCounted
class_name KartLap
## Laps, checkpoints and lap times for ONE racer -- per racer, never per
## track, so N karts are N of these and the track stays a shared, read-only
## thing.
##
## Carte-blanche V7. Fed the racer's progress along the track (the
## abscissa `s` KartTrack.progress_at publishes) once per physics frame,
## it decides when a lap has REALLY been driven:
##
##   * the start line is crossed FORWARD (s wraps from the last tenth of
##     the lap to the first);
##   * all three checkpoints (25 / 50 / 75 % of the length) were passed IN
##     ORDER since the previous crossing. A kart that turns round on the
##     straight and crosses the line backwards then forwards has passed no
##     checkpoint and gets no lap -- and a backwards crossing clears the
##     checkpoints so the shortcut "reverse over the line, drive forward"
##     is worth nothing either.
##
## Timing starts at the FIRST forward crossing (the kart is parked short
## of the line, so the first pass under the gantry is the flag) -- an
## un-timed out-lap costs nothing and means the chrono never shows a
## number the player did not earn.

const CHECKPOINTS: int = 3
## A crossing is a jump between the two ends of the lap. Tenths rather
## than a razor edge: at 13 u/s and 60 Hz a kart moves 0.22 u per frame,
## so this is 20+ frames of margin on a 230 u lap, and a kart that stops
## ON the line and creeps over it still crosses exactly once.
const WRAP_FRACTION: float = 0.1
## How long a kart may point the wrong way before the HUD says so. Short
## enough to be useful, long enough that a spin does not flash it.
const WRONG_WAY_S: float = 1.2

var lap_count: int = 0
var last_lap_ms: int = 0
var best_lap_ms: int = 0
var timing: bool = false
var lap_time_s: float = 0.0
var wrong_way: bool = false
## Called with (lap_ms) on every completed lap. A Callable rather than a
## signal because this is a RefCounted read by a coordinator, not a node.
var on_lap: Callable = Callable()

var _length: float = 1.0
var _last_s: float = -1.0
var _next_checkpoint: int = 0
var _wrong_way_s: float = 0.0

func setup(track_length: float) -> void:
	_length = maxf(track_length, 1.0)
	reset()

func reset() -> void:
	lap_count = 0
	last_lap_ms = 0
	best_lap_ms = 0
	timing = false
	lap_time_s = 0.0
	wrong_way = false
	_last_s = -1.0
	_next_checkpoint = 0
	_wrong_way_s = 0.0

func next_checkpoint() -> int:
	return _next_checkpoint

## `s` in [0, length); `forward` true when the kart moves along the lap.
func update(s: float, forward: bool, delta: float) -> void:
	if timing:
		lap_time_s += delta
	if _last_s < 0.0:
		_last_s = s
		return
	var lo: float = _length * WRAP_FRACTION
	var hi: float = _length * (1.0 - WRAP_FRACTION)
	if _last_s > hi and s < lo:
		_cross_forward()
	elif _last_s < lo and s > hi:
		# Backwards over the line: every checkpoint is forfeit.
		_next_checkpoint = 0
	# Checkpoints are passed in order, and only forward: the gate is a
	# fraction of the lap the kart has to be PAST, having been short of
	# it on the previous frame.
	if _next_checkpoint < CHECKPOINTS:
		var gate: float = _length * float(_next_checkpoint + 1) / float(CHECKPOINTS + 1)
		if _last_s < gate and s >= gate and s - _last_s < _length * 0.5:
			_next_checkpoint += 1
	_last_s = s
	# Wrong way: held, not instantaneous.
	if forward:
		_wrong_way_s = 0.0
		wrong_way = false
	else:
		_wrong_way_s += delta
		if _wrong_way_s >= WRONG_WAY_S:
			wrong_way = true

func _cross_forward() -> void:
	if timing and _next_checkpoint >= CHECKPOINTS:
		var ms: int = int(round(lap_time_s * 1000.0))
		lap_count += 1
		last_lap_ms = ms
		if best_lap_ms <= 0 or ms < best_lap_ms:
			best_lap_ms = ms
		if on_lap.is_valid():
			on_lap.call(ms)
	# Whether or not that lap counted, a forward crossing is a new lap's
	# start: the clock restarts here, and the checkpoints are armed.
	timing = true
	lap_time_s = 0.0
	_next_checkpoint = 0

static func format_ms(ms: int) -> String:
	if ms <= 0:
		return "--:--.--"
	var total_cs: int = int(ms / 10)
	var minutes: int = int(total_cs / 6000)
	var seconds: int = int((total_cs % 6000) / 100)
	var cs: int = total_cs % 100
	return "%d:%02d.%02d" % [minutes, seconds, cs]
