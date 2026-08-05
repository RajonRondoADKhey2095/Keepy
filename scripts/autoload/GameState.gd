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

## THE SPEED CURVE, as an explicit table of (palier start time, palier
## speed) pairs. Deliberately NOT "a constant duration x a constant
## step" any more -- both the palier LENGTHS and the palier STEPS now
## vary along the run.
##
## Why the old uniform formula (30s per palier, +2 m/s each) was
## replaced: it was calibrated for 5-6 minute runs, whereas a mobile
## endless runner is played in 40-90 second bursts. Under it, a typical
## run ended while still inside palier 0 or 1, i.e. the player never saw
## the game accelerate at all, and the first notable event (dark mode,
## 90s) landed after most runs were already over.
##
## The shape below is logarithmic rather than linear -- DENSE at the
## start (short paliers, big steps, so the escalation is legible within
## the first half-minute) and FLAT at the end (longer paliers, small
## steps, so the top of the curve still has somewhere to go without
## turning unreadable). Spelled out row by row rather than computed, so
## both halves stay hand-tunable at a glance.
##
## HALVED (difficulty+variety batch, playtest: "too easy, had to lose on
## purpose") from the durations originally tuned for 40-90s runs -- the
## SPEEDS are UNCHANGED (same table of steps), only how fast the run
## climbs through them: the cap now lands around 45s instead of 90s.
##
##   idx  run time window    speed      step    palier length
##   ---  -----------------  ---------  ------  -------------
##    0   0s .. 6s           12.0 m/s     --       6s
##    1   6s .. 12s          15.0 m/s   +3.0       6s
##    2   12s .. 18s         18.0 m/s   +3.0       6s
##    3   18s .. 24s         20.5 m/s   +2.5       6s   <- dark mode starts
##    4   24s .. 30s         22.5 m/s   +2.0       6s
##    5   30s .. 37.5s       24.0 m/s   +1.5     7.5s
##    6   37.5s .. 45s       25.0 m/s   +1.0     7.5s
##    7   45s and beyond     26.0 m/s   +1.0      cap, held to the end
##
## The two arrays are INDEX-ALIGNED and must stay the same length:
## STAGE_START_S[i] is the run time at which STAGE_SPEEDS[i] takes over.
## STAGE_START_S must start at 0.0 and be strictly increasing. The last
## STAGE_SPEEDS entry is the cap, held for the rest of the run.
##
## Raising the cap is NOT free: TrackManager spaces obstacles out by the
## time they leave the player (see its MIN_OBSTACLE_GAP_S), so a higher
## cap automatically thins the track rather than making it unreadable.
const STAGE_START_S: Array[float] = [0.0, 6.0, 12.0, 18.0, 24.0, 30.0, 37.5, 45.0]
const STAGE_SPEEDS: Array[float] = [12.0, 15.0, 18.0, 20.5, 22.5, 24.0, 25.0, 26.0]

# Named aliases. START_SPEED/BASE_SPEED == STAGE_SPEEDS[0] and
# MAX_SPEED == the last STAGE_SPEEDS entry, restated as plain literals
# because a const array cannot be indexed in a const initialiser. Kept
# because other scripts' comments (Obstacle.gd, Keepy.gd) reason in
# terms of "the BASE_SPEED..MAX_SPEED range".
const START_SPEED: float = 12.0
const BASE_SPEED: float = START_SPEED
const MAX_SPEED: float = 26.0

## Run time at which the dark-mode cycle FIRST fires. Aligned on the
## start of palier 3 (see STAGE_START_S) so the run's first visual event
## lands on a speed step rather than in the middle of one.
##
## Was 90s, then 36s once paliers were first tuned for 40-90s runs (past
## the end of most runs at 90s -- the majority of players never saw dark
## mode exist at all). HALVED AGAIN to 18s alongside the palier-duration
## halving above (difficulty+variety batch) so it stays anchored on the
## SAME palier boundary (palier 3's new start) instead of drifting to a
## palier it no longer lines up with.
const DARK_FIRST_TRIGGER_S: float = 18.0

## Length of ONE phase: dark for this long, then light for this long,
## then dark again, for the rest of the run.
##
## DELIBERATELY INDEPENDENT of DARK_FIRST_TRIGGER_S. These used to be a
## single constant, which meant "when does dark mode start" and "how
## often does it swap" could not be tuned apart: moving the first
## trigger earlier also made the cycle churn faster, and vice versa.
## They answer different design questions and now have one knob each.
## At the defaults: dark 18-28s, light 28-38s, dark 38-48s, and so on.
##
## HALVED alongside DARK_FIRST_TRIGGER_S so the cycle keeps the SAME
## proportion of the (now twice as fast) run it always had, rather than
## suddenly spanning twice as large a fraction of a run that halved in
## length underneath it.
##
## The cycle is driven by the clock, NOT by current_speed: keying a
## visual state off a speed threshold is what let an earlier iteration
## fire 1.35s into a run when the speed curve misbehaved. The trigger is
## a time the run cannot reach early by any means.
const DARK_CYCLE_PERIOD_S: float = 10.0

## Seconds a dark <-> light transition takes to fade fully in or out.
## Never 0: an instant flip is what made an earlier iteration unplayable.
##
## Was 1.5s, when a phase lasted 90s and the fade was under 2% of it. At
## a 20s phase, 1.5s of fade would be 7.5% of every phase spent in a
## half-applied state, twice per cycle -- the transition would stop
## reading as an event and start reading as the normal look of the game.
## 0.8s stays clearly followable by the eye while leaving the phase
## itself unambiguous.
const DARK_FADE_DURATION_S: float = 0.8

# =====================================================================

## Dark-mode cycle phase. INACTIVE until DARK_FIRST_TRIGGER_S, then only
## ever alternates DARK <-> LIGHT. An explicit state machine (phase +
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
## has no such feedback loop: 12 seconds is 12 seconds at any speed.
##
## Walks FORWARD from the palier already reached rather than rescanning
## the table or dividing by a (no longer existing) uniform palier
## duration: the run clock only moves forward, so this is O(1) in
## practice, and the `while` still handles a caller stepping the clock
## by more than one palier at a time (a headless probe can).
func _update_stage() -> void:
	var new_stage := stage_index
	while new_stage + 1 < STAGE_START_S.size() and run_time_s >= STAGE_START_S[new_stage + 1]:
		new_stage += 1
	if new_stage == stage_index:
		return
	stage_index = new_stage
	current_speed = STAGE_SPEEDS[stage_index]

## Worst-case time between a row being spawned and the player actually
## reaching it: TrackManager (SEGMENT_COUNT=7 segments, SEGMENT_LENGTH=
## 20m each) never spawns a row more than 140m ahead, and lead time is
## largest at the SLOWEST speed a row can ever be spawned at, START_SPEED
## (only true near the very start of a run, before the first palier
## boundary). Restated here as a literal (not a cross-file class-const
## reference to TrackManager) to avoid GameState -- an autoload, loaded
## first -- taking a compile-time dependency on a plain scene script's
## layout; see TrackManager.gd's own comment pointing back at this
## constant so the two never silently drift apart.
const MAX_LOOKAHEAD_S: float = 7.0 * 20.0 / START_SPEED

## The speed that content spawned RIGHT NOW should be laid out for --
## the speed the run will actually be at once the lead time above has
## elapsed, not just the next palier's (the table only ever increases,
## so this is always >= current_speed).
##
## Why a look-ahead is needed at all: a row laid out for the speed at
## spawn time can be RUN THROUGH one OR MORE paliers faster than it was
## spaced for, silently eating the reaction budget it was supposed to
## guarantee. This used to hardcode "look exactly one palier ahead",
## which was safe ONLY as long as every palier was longer than
## MAX_LOOKAHEAD_S (true at 12s/palier, ~11s worst-case lead time) -- no
## longer true once paliers were halved (difficulty+variety batch, see
## STAGE_START_S above): at 6s/palier and the SAME ~11.67s worst-case
## lead time, a row spawned right before a boundary could now be run
## through TWO boundaries, not one, and "+1 stage" would silently
## under-space it. Scanning forward by TIME instead of by a fixed stage
## count is the general fix -- correct regardless of how short a future
## re-tune makes the paliers, not just today's.
func lookahead_speed() -> float:
	var horizon := run_time_s + MAX_LOOKAHEAD_S
	var idx := stage_index
	while idx + 1 < STAGE_START_S.size() and STAGE_START_S[idx + 1] <= horizon:
		idx += 1
	return STAGE_SPEEDS[idx]

## Dark <-> light alternation, plus the fade between them. Three explicit
## phases; the only transitions are INACTIVE -> DARK (once, at
## DARK_FIRST_TRIGGER_S) and DARK <-> LIGHT (every DARK_CYCLE_PERIOD_S
## after that -- a different constant, see both of them above). It never
## reverts to INACTIVE within a run.
func _update_dark_cycle(delta: float) -> void:
	if dark_phase == DarkPhase.INACTIVE:
		if run_time_s < DARK_FIRST_TRIGGER_S:
			return
		dark_phase = DarkPhase.DARK
		# Anchored on the constant, not on run_time_s, so phase
		# boundaries can't drift by up to a frame on every swap.
		_dark_phase_started_s = DARK_FIRST_TRIGGER_S
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
