extends Node
## Autoloaded as "GameState". Single source of truth for the current
## run: score, distance travelled and forward speed. No other script
## keeps its own copy of these values.

signal score_changed(new_score: int)
signal state_changed(new_state: State)

enum State { TITLE, PLAYING, GAME_OVER }

const BASE_SPEED: float = 8.0
const MAX_SPEED: float = 22.0
const SPEED_RAMP_PER_METER: float = 0.02

var state: State = State.TITLE
var distance_travelled: float = 0.0
var current_speed: float = BASE_SPEED

# Score is the sum of two independently tracked counters so that a
# noisette pickup can never be silently overwritten by the next
# distance-based score tick (see add_distance / add_noisette).
var distance_score: int = 0
var noisette_score: int = 0
var score: int = 0

func start_run() -> void:
	distance_travelled = 0.0
	current_speed = BASE_SPEED
	distance_score = 0
	noisette_score = 0
	score = 0
	state = State.PLAYING
	state_changed.emit(state)
	score_changed.emit(score)

func end_run() -> void:
	state = State.GAME_OVER
	state_changed.emit(state)

func add_distance(delta_distance: float) -> void:
	distance_travelled += delta_distance
	current_speed = min(MAX_SPEED, BASE_SPEED + distance_travelled * SPEED_RAMP_PER_METER)
	var new_distance_score := int(distance_travelled)
	if new_distance_score != distance_score:
		distance_score = new_distance_score
		_recompute_score()

func add_noisette() -> void:
	noisette_score += 1
	_recompute_score()

func _recompute_score() -> void:
	score = distance_score + noisette_score
	score_changed.emit(score)
