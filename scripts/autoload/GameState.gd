extends Node
## Autoloaded as "GameState". Single source of truth for the current
## run: score, distance travelled, elapsed run time and forward speed.
## No other script keeps its own copy of these values.

signal score_changed(new_score: int)
signal state_changed(new_state: State)
## Fires only on a collectible pickup (never on the per-meter distance
## tick that also drives score_changed) -- the HUD counters only need to
## repaint when a count actually moves.
signal counts_changed(nut_count: int, gland_count: int)

enum State { TITLE, PLAYING, GAME_OVER }

# =====================================================================
# SPEED / PACING TUNING KNOBS -- everything needed to re-tune the run's
# rhythm after a playtest lives in this one block. Nothing below
# re-derives pacing from anything outside it.
# =====================================================================

## Wall-clock seconds spent at each speed palier before stepping up to
## the next one. Scales the whole progression uniformly.
const STAGE_DURATION_S: float = 30.0

## Speed of palier 0, i.e. the pace the very first seconds of a run are
## played at. Must stay somewhere a player can read an incoming obstacle
## and react calmly: a track segment is 20m (TrackManager.SEGMENT_LENGTH),
## so 8 m/s gives 2.5s of reaction per segment.
const START_SPEED: float = 8.0

## Speed added by each palier step. Applied as a hard step at the palier
## boundary, never as a curve -- see STAGE_SPEEDS.
const STAGE_SPEED_STEP: float = 2.0

## Palier index at which the run is qualified as "fast", which is also
## when the dark-mode cycle starts AND the length of one dark phase and
## one light phase (see DARK_CYCLE_PERIOD_S).
##
## *** MAIN PACING KNOB. *** At 30s per palier, index 3 puts the first
## dark-mode transition 90 seconds into a run, and makes the cycle swap
## every 90s after that. Raise it to push dark mode later and make it
## rarer, lower it to bring it earlier and make it churn faster. Nothing
## else needs touching to move that milestone.
const FAST_TIER_INDEX: int = 3

## Seconds a dark <-> light transition takes to fade fully in or out.
## Never 0: an instant flip is what made the previous iteration
## unplayable. Short enough to still read as an event, long enough that
## the eye follows it.
const DARK_FADE_DURATION_S: float = 1.5

## Speed per palier, spelled out rather than computed, so the whole
## progression is readable (and hand-tunable) at a glance. Built as
## START_SPEED + n * STAGE_SPEED_STEP; the LAST entry is the cap, held
## for the rest of the run once reached.
##
##   idx  run time window     speed     notes
##   ---  ------------------  --------  ---------------------------------
##    0   0s .. 30s            8 m/s    opening pace, calm
##    1   30s .. 60s          10 m/s
##    2   60s .. 90s          12 m/s
##    3   90s .. 120s         14 m/s    FAST_TIER_INDEX -- dark mode on
##    4   120s .. 150s        16 m/s
##    5   150s .. 180s        18 m/s
##    6   180s .. 210s        20 m/s
##    7   210s .. 240s        22 m/s
##    8   240s and beyond     24 m/s    cap (held for the rest of the run)
const STAGE_SPEEDS: Array[float] = [8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0, 24.0]

# Named aliases kept because other scripts' comments (Obstacle.gd,
# Keepy.gd) reason in terms of "the BASE_SPEED..MAX_SPEED range".
const BASE_SPEED: float = START_SPEED
const MAX_SPEED: float = 24.0 # == last STAGE_SPEEDS entry (const arrays can't be indexed here)

## Run time at which the dark-mode cycle starts, and also the duration of
## each dark phase and each light phase -- i.e. the elapsed time at the
## moment the fast palier is reached, as specced. At the defaults: dark
## from 90s to 180s, light from 180s to 270s, dark again from 270s, and
## so on for the rest of the run.
##
## The cycle is driven by the clock, NOT by current_speed: keying a
## visual state off a speed threshold is what let the previous iteration
## fire 1.35s into a run when the speed curve misbehaved. The trigger is
## now a time the run cannot reach early by any means.
const DARK_CYCLE_PERIOD_S: float = FAST_TIER_INDEX * STAGE_DURATION_S

# =====================================================================

## Dark-mode cycle phase. INACTIVE until the fast palier is reached, then
## only ever alternates DARK <-> LIGHT. An explicit state machine (phase +
## the run time that phase started at) rather than a continuous formula
## on elapsed time, so a transition in flight can never be recomputed
## into a different value by a stray frame.
enum DarkPhase { INACTIVE, DARK, LIGHT }

var state: State = State.TITLE
var distance_travelled: float = 0.0
var run_time_s: float = 0.0
var current_speed: float = START_SPEED
var stage_index: int = 0

var dark_phase: DarkPhase = DarkPhase.INACTIVE
## 0.0 = untouched, 1.0 = fully dark. Read by DarkModeEffect.gd. The fade
## lives here rather than in the visual layer so the effect node stays a
## dumb renderer of a state this file owns end to end.
var dark_intensity: float = 0.0
var _dark_phase_started_s: float = 0.0

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
	run_time_s = 0.0
	current_speed = START_SPEED
	stage_index = 0
	dark_phase = DarkPhase.INACTIVE
	dark_intensity = 0.0
	_dark_phase_started_s = 0.0
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

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	advance_time(delta)

## Advances the run clock and everything derived from it. Public, and
## touching nothing but this node's own state, so a headless test can
## drive a whole run deterministically at a fixed step instead of
## waiting on the real frame clock.
func advance_time(delta: float) -> void:
	run_time_s += delta
	_update_stage()
	_update_dark_cycle(delta)

## Speed is a step function of ELAPSED TIME, never of distance travelled.
##
## It used to be an exponential in distance -- current_speed = MAX -
## (MAX - BASE) * exp(-distance / 22m) -- which self-accelerated: a
## higher speed makes distance accrue faster, which raises the speed
## again. Measured, that collapsed the entire intended ramp into the
## first ~3 seconds of a run (94% of MAX_SPEED at t=2s). Elapsed time
## has no such feedback loop: 30 seconds is 30 seconds at any speed.
func _update_stage() -> void:
	var new_stage := mini(int(run_time_s / STAGE_DURATION_S), STAGE_SPEEDS.size() - 1)
	if new_stage == stage_index:
		return
	stage_index = new_stage
	current_speed = STAGE_SPEEDS[stage_index]

## Dark <-> light alternation, plus the fade between them. Three explicit
## phases; the only transitions are INACTIVE -> DARK (once, at
## DARK_CYCLE_PERIOD_S) and DARK <-> LIGHT (every DARK_CYCLE_PERIOD_S
## after that). It never reverts to INACTIVE within a run.
func _update_dark_cycle(delta: float) -> void:
	if dark_phase == DarkPhase.INACTIVE:
		if run_time_s < DARK_CYCLE_PERIOD_S:
			return
		dark_phase = DarkPhase.DARK
		# Anchored on the constant, not on run_time_s, so phase
		# boundaries can't drift by up to a frame on every swap.
		_dark_phase_started_s = DARK_CYCLE_PERIOD_S
	elif run_time_s - _dark_phase_started_s >= DARK_CYCLE_PERIOD_S:
		dark_phase = DarkPhase.LIGHT if dark_phase == DarkPhase.DARK else DarkPhase.DARK
		_dark_phase_started_s += DARK_CYCLE_PERIOD_S

	var target := 1.0 if dark_phase == DarkPhase.DARK else 0.0
	# move_toward, not an exponential lerp: it reaches the target exactly,
	# in exactly DARK_FADE_DURATION_S. An exponential lerp only asymptotes,
	# so "fully dark" and "fully back to normal" would never be reached --
	# the effect would sit permanently at ~97% and never truly clear.
	dark_intensity = move_toward(dark_intensity, target, delta / DARK_FADE_DURATION_S)

func add_distance(delta_distance: float) -> void:
	distance_travelled += delta_distance
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
