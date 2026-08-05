extends Node
## Autoloaded as "GameState". Single source of truth for the current
## run: score, distance travelled and forward speed. No other script
## keeps its own copy of these values.

signal score_changed(new_score: int)
signal state_changed(new_state: State)
## Fires only on a collectible pickup (never on the per-meter distance
## tick that also drives score_changed) -- the HUD counters only need to
## repaint when a count actually moves.
signal counts_changed(nut_count: int, gland_count: int)

enum State { TITLE, PLAYING, GAME_OVER }

# Speed ramp: was a flat linear climb (BASE_SPEED=8.0, MAX_SPEED=22.0,
# +0.02 m/s per meter travelled -- 700m to reach MAX_SPEED, imperceptible
# over a typical run). Replaced with an exponential approach to MAX_SPEED:
# aggressive in the first 30-40m, then flattening out as it nears the cap
# (see add_distance). BASE_SPEED/MAX_SPEED bumped up too so the run is
# faster from the very first frame, not just steeper over time.
const BASE_SPEED: float = 11.0
# MORE AGGRESSIVE PROGRESSION (playtest feedback, was MAX_SPEED=27.0):
# bumped +55% so the run reaches genuinely extreme speed instead of just
# "brisk". BASE_SPEED unchanged -- only the ceiling and how fast the ramp
# climbs toward it change, so the run still opens at the same pace.
const MAX_SPEED: float = 42.0
# Exponential time-constant in meters: at distance == this value, current
# speed has closed ~63% of the gap to MAX_SPEED. Smaller = more aggressive
# early ramp. Was 40.0m; cut to 22.0m (-45%) so the ramp bites noticeably
# sooner. The curve's shape only depends on distance/SPEED_RAMP_TIME_CONSTANT_M,
# so this also pulls DARK_MODE_SPEED_THRESHOLD below earlier in absolute
# distance -- see that constant's comment for the actual numbers.
const SPEED_RAMP_TIME_CONSTANT_M: float = 22.0

# Fraction of MAX_SPEED at which the screen-wide "dark mode" post-process
# (see DarkModeEffect.gd) starts fading in. Picked in the 75-85% range
# asked for -- high enough to be a genuine "you are now running at a
# dangerous speed" milestone, not the default state, but not pinned to
# 99%+ either (the exponential ramp above asymptotes, so a threshold too
# close to MAX_SPEED would take a very long tail to ever cross).
# Fraction-of-max thresholds on this curve are reached at
# distance == SPEED_RAMP_TIME_CONSTANT_M * ln((1 - BASE_SPEED/MAX_SPEED) / (1 - fraction))
# -- with the constants above that puts this threshold at roughly 35m in,
# i.e. right as SAFE_START_SEGMENTS (TrackManager, 40m) ends and the
# first obstacles can appear. That is intentional given "plus tot" was
# the explicit goal for chantier 2 as a whole: the aggressive ramp means
# even the early game is already fast, so the dark-mode milestone follows
# suit rather than being held back to a rarely-reached late-run moment.
const DARK_MODE_SPEED_THRESHOLD: float = MAX_SPEED * 0.82

var state: State = State.TITLE
var distance_travelled: float = 0.0
var current_speed: float = BASE_SPEED

# Point values for the two collectible types. Gland is worth more than a
# ground Noisette because it's only reachable with correct jump timing
# (see Gland.gd / TrackManager GLAND_CHANCE_PER_ROW) -- the score bump is
# the reward for the extra risk.
const NOISETTE_VALUE: int = 1
const GLAND_VALUE: int = 5

# Score is the sum of THREE independently tracked counters so that a
# collectible pickup can never be silently overwritten by the next
# distance-based score tick, or by another collectible type's counter
# (see add_distance / add_noisette / add_gland).
var distance_score: int = 0
var noisette_score: int = 0
var gland_score: int = 0
var score: int = 0

# Raw pickup counts, separate from noisette_score/gland_score above.
# NOT part of the score computation (gland_score already folds
# GLAND_VALUE points into `score` -- these two exist purely so the HUD
# and the leaderboard submission have a "how many of each did I collect"
# number that isn't pre-multiplied by a point value).
var nut_count: int = 0
var gland_count: int = 0

func start_run() -> void:
	distance_travelled = 0.0
	current_speed = BASE_SPEED
	distance_score = 0
	noisette_score = 0
	gland_score = 0
	score = 0
	nut_count = 0
	gland_count = 0
	state = State.PLAYING
	state_changed.emit(state)
	score_changed.emit(score)
	counts_changed.emit(nut_count, gland_count)

func end_run() -> void:
	state = State.GAME_OVER
	state_changed.emit(state)

func add_distance(delta_distance: float) -> void:
	distance_travelled += delta_distance
	current_speed = MAX_SPEED - (MAX_SPEED - BASE_SPEED) * exp(-distance_travelled / SPEED_RAMP_TIME_CONSTANT_M)
	var new_distance_score := int(distance_travelled)
	if new_distance_score != distance_score:
		distance_score = new_distance_score
		_recompute_score()

func add_noisette() -> void:
	noisette_score += NOISETTE_VALUE
	nut_count += 1
	_recompute_score()
	counts_changed.emit(nut_count, gland_count)

func add_gland() -> void:
	gland_score += GLAND_VALUE
	gland_count += 1
	_recompute_score()
	counts_changed.emit(nut_count, gland_count)

func _recompute_score() -> void:
	score = distance_score + noisette_score + gland_score
	score_changed.emit(score)
