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
## Fires once per credited RISK EVENT (see RiskEvent / register_risk_event).
## Purely informational -- the combo bookkeeping is applied directly inside
## register_risk_event, never through a handler on this signal, so nothing
## can silently stop working by failing to connect.
signal risk_event(kind: RiskEvent)
## Fires whenever the combo COUNT or MULTIPLIER moves, in either direction
## -- including the collapse to (0, 1) on timeout or death, so a listener
## that only ever reacts to this one signal still ends up in the right
## state. The HUD is driven entirely by it.
signal combo_changed(count: int, multiplier: int)
## Fires ONLY on the frame the multiplier steps UP a tier, in addition to
## combo_changed. A separate signal rather than "diff the multiplier in the
## handler": crossing a tier deserves a visibly stronger reaction than an
## ordinary increment (see HUD.gd), and every listener working that out for
## itself from the previous value is how two surfaces end up disagreeing
## about what counts as a tier-up.
signal combo_tier_up(multiplier: int)
## Fires when a combo the player HAD is lost -- never on a combo that was
## already zero. Distinct from combo_changed(0, 1) carrying the same
## information, for the same reason as above: losing a chain is an event,
## not a value.
signal combo_lost()

enum State { TITLE, PLAYING, GAME_OVER }

# =====================================================================
# RISK EVENTS -- the whole point of the combo system (playtest: "je trouve
# le jeu trop facile", diagnosed as "rien ne m'incite a prendre des
# risques": the player can always change lane early, never jump, and
# survive indefinitely). These are the four things the game is willing to
# call a deliberate risk, and they are all things the codebase could
# ALREADY see happen -- no new collision system, no new detection path:
#
#   JUMP_DODGE -- clearing a jumpable hazard by jumping over it on its own
#                 lane. Detected since the playtest-fixes batch by
#                 Obstacle._check_passage / _is_jump_dodge (which already
#                 scored a small bonus for it); the combo system reuses
#                 that exact detection rather than adding a second one.
#   NEAR_MISS  -- a hazard passed close enough to graze. Derived from the
#                 CLOSEST LATERAL APPROACH measured over the passage,
#                 evaluated at the same Z=0 crossing the jump-dodge check
#                 already computes -- see Obstacle.NEAR_MISS_MAX_LATERAL_M.
#   LATE_DODGE -- the player was standing on a hazard's lane and vacated it
#                 inside the final reaction window (see
#                 Obstacle.LATE_DODGE_WINDOW_S). The escape CHARGER forces,
#                 since a charger cannot be jumped.
#   GLAND      -- collecting the airborne bonus, which is only reachable at
#                 jump apex and therefore an accepted risk by construction
#                 (see TrackSegment.GLAND_Y).
#
# Ordered by nothing in particular -- the enum's only job is to key the
# per-kind counters below. Obstacle.gd decides which ONE of the three
# hazard-passage kinds a given passage was (they are mutually exclusive by
# construction, see _resolve_risk_event).
# =====================================================================

enum RiskEvent { JUMP_DODGE, NEAR_MISS, LATE_DODGE, GLAND }

# =====================================================================
# COMBO / MULTIPLIER TUNING -- the reward half of the risk system above.
# Grouped here with the speed/pacing knobs rather than scattered, same as
# every other tunable in this file.
#
# THE DESIGN PROBLEM, stated plainly: after the CHARGER batch the game can
# finally kill the player ("j'ai perdu avec l'ennemi charger, bon signe"),
# but it still never has to. A player who changes lane early, never jumps
# and never reaches for a gland survives essentially forever, and scores
# almost as well as one who does not -- because the dominant term in the
# score is distance, which is a function of TIME SURVIVED and of nothing
# else. Safe play was not just viable, it was optimal.
#
# So this block does NOT add a threat. It makes the SCORE care how the
# distance was covered: the multiplier below applies to collectibles ONLY
# (see add_noisette/add_gland), so the baseline distance income stays
# exactly what it was and every point of upside now sits behind a risk.
# Playing safe stops being punished and starts being merely boring, which
# is the actual goal -- difficulty the player CHOOSES rather than
# difficulty imposed on them.
# =====================================================================

## Seconds without a risk event after which the combo collapses to zero.
##
## THE CENTRAL KNOB of the whole system, and the reason it creates pressure
## at all: the combo is not lost by making a MISTAKE, it is lost by playing
## it safe for too long. Nothing about dodging an obstacle cleanly resets
## it -- only the absence of risk does. A player sitting on a full x4 has
## to keep finding danger to hold it, which is exactly the behaviour this
## batch exists to provoke.
##
## 5.0s sits in the middle of the 4-6s bracket the design called for, and
## it is not an arbitrary midpoint: TrackManager.MIN_OBSTACLE_GAP_S
## (~0.80s) times the per-row obstacle chance means hazards arrive every
## ~1-2s in normal density, so 5s is comfortably long enough that a chain
## is sustainable through an ordinary stretch of track, and short enough
## that a CALM window (TrackManager.CALM_DURATION_MIN_S..MAX_S, 2-3s at
## 0.45x density) genuinely threatens a chain the player is not working to
## keep alive.
const COMBO_TIMEOUT_S: float = 5.0

## How long BEFORE the timeout the combo counts as "about to be lost" --
## read by the HUD (see HUD.gd) to start the warning pulse.
##
## This is not polish. A reward that vanishes silently teaches nothing: the
## player sees a number they had, then a number they do not, with no moment
## in between where they could have acted. The warning IS the mechanic --
## it is the instant the game asks "are you going to go find some danger,
## or let this go", and it is the only part of the loop that can actually
## push a cautious player toward a hazard they would otherwise avoid.
##
## 1.2s: longer than a full lane-switch escape (Obstacle.LANE_SWITCH_TIME_S
## + a perception budget, ~0.35s) so acting on it is genuinely possible
## rather than a tease, and short enough that it stays a distinct alarm
## instead of describing a quarter of the combo's whole lifetime.
const COMBO_WARNING_S: float = 1.2

## How many risk events each multiplier step costs. Progressive by
## construction: the Nth step needs the same 3 events as the first, so the
## curve is linear in events and the player can count it (3 = x2, 6 = x3,
## 9 = x4) rather than having to feel out an accelerating threshold.
const COMBO_TIER_SIZE: int = 3

## Ceiling on the multiplier. WITHOUT this the score is unbounded in a way
## that has nothing to do with skill: an endless runner's run length is
## open-ended, so any multiplier that keeps climbing eventually makes the
## last minute of a long run worth more than everything before it combined,
## and the leaderboard stops ranking players and starts ranking session
## length. x4 keeps a well-played stretch clearly ahead of a safe one (see
## scripts/dev/ComboAudit.gd for the measured gap) without that.
const COMBO_MAX_MULTIPLIER: int = 4

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
# PALETTE VARIETY (difficulty+variety batch, EXPANDED in the playtest-
# fixes batch) -- see DarkModeEffect.gd / screen_invert.gdshader for how
# DARK_VARIANTS is actually applied. Kept here, next to the timing knobs
# above, because it is state a fresh run must reset and a phase
# transition must update -- the same ownership rule this file already
## follows for dark_phase/dark_intensity.
##
## The LIGHT-phase counterpart (EnvironmentDrift.gd, a continuous hue
## drift of the sky/ground) is REMOVED as of this batch (playtest: "la
## derive continue n'apporte rien") -- the light phase is now a fixed,
## unchanging reference state, so a DARK phase always reads against the
## SAME baseline instead of against whatever the drift happened to be at
## that moment. That is also why DARK_VARIANTS needed to work harder:
## with no light-side variety left to share the "this run looks
## different" job, every bit of per-run/per-phase visual variety in the
## game now lives here.
# =====================================================================

## Candidate tint colours a DARK phase can pick from -- blended on TOP of
## the already-inverted screen (see the shader for why this can never
## make anything less distinguishable, only differently coloured).
##
## EXPANDED from 4 to 6 (playtest: "les teintes sombres se ressemblent
## trop, ca ne se sent pas comme un monde different") and picked as hues
## spread EVENLY around the colour wheel (0/45/130/205/265/320 degrees,
## ~55-80 degrees apart) rather than chosen by eye -- the earlier set's
## crimson/blue pairing in particular sat close enough that two
## consecutive phases could both read as "reddish" or "bluish" instead of
## clearly different worlds. The even spread specifically avoids the
## failure mode of picking two variants that both read as "kind of
## purple-blue": violet (265) and cold blue (205) are a full 60 degrees
## apart, further than blue was from crimson (215 degrees the OTHER way
## round the wheel, i.e. the original 4 were not evenly spread either).
const DARK_VARIANTS: Array[Color] = [
	Color(1.00, 0.12, 0.12), # crimson red    (hue ~0)
	Color(1.00, 0.75, 0.08), # amber / orange (hue ~45)
	Color(0.12, 1.00, 0.28), # toxic green    (hue ~130)
	Color(0.12, 0.62, 1.00), # cold blue      (hue ~205)
	Color(0.48, 0.12, 1.00), # violet         (hue ~265)
	Color(1.00, 0.12, 0.68), # magenta / pink (hue ~320)
]

## How strongly a DARK_VARIANTS tint blends over the inversion -- read by
## DarkModeEffect.gd as `tint_amount`, faded in/out by the shader
## alongside `intensity` (never applied at full strength the instant a
## phase starts).
##
## RAISED from 0.18 to 0.55 (playtest: "le changement de couleur est trop
## timide, on dirait juste un filtre leger, pas un monde different").
## 0.18 was calibrated purely to stay safely under the shader's
## injectivity ceiling (any value < 1.0), never against a measured
## legibility floor -- it was cautious, not tuned.
##
## 0.55 was chosen by actually rendering the game under each of the 6
## DARK_VARIANTS above at full dark intensity and sampling real pixel
## contrast (WCAG relative-luminance ratio) between every hazard/
## collectible and the ground with scripts/dev/DarkPaletteAudit.gd (same
## "sample real rendered pixels, don't hand-compute from hex codes"
## standard as InvertCapture.gd) -- see that probe's own header for the
## method and the commit message for the full per-palette numbers.
## MEASURED, NOT ASSUMED: a full sweep from 0.18 to 0.75 found the worst
## observed contrast barely moves at all (1.00-1.02:1 across the ENTIRE
## range) -- the floor is set by the plain screen-INVERT step these
## objects' raw albedos already produced against the ground colour
## (a pre-existing property of this game's fixed palette, present since
## before this batch), not by the tint amount. Raising the tint therefore
## buys the "different world" feel essentially for free on the
## contrast axis: it does not make the worst pairs measurably worse than
## they already were at 0.18. 0.55 is kept well short of the shader's
## hint_range(0.0, 0.9) ceiling so there is still headroom before the mix
## starts trending toward a flat, unreadable wash of the tint colour.
## The one legibility question that DOES matter for this floor and that
## this constant alone cannot fix -- "can I jump THIS specific hazard" --
## is answered by a dedicated, fully colour-controlled marker
## (Obstacle.gd's JumpMarkerMesh, chantier 2 of the same batch), verified
## separately against a real WCAG AA floor rather than inheriting
## whatever contrast a hazard's pre-existing mesh colour happens to have.
const DARK_TINT_AMOUNT: float = 0.55

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

## Index into DARK_VARIANTS the CURRENT (or most recent) DARK phase uses
## -- read by DarkModeEffect.gd. Re-rolled every time the run transitions
## INTO Dark (never on Dark -> Light), always to a DIFFERENT index than
## last time (see _enter_dark_phase) so two consecutive dark phases in
## the same run are never accidentally identical, and two separate runs
## (fresh randf() seed each time) don't line up either.
var dark_variant_index: int = 0

# Point values for the two collectible types. Gland is worth more than a
# ground Noisette because it's only reachable with correct jump timing
# (see Gland.gd / TrackManager GLAND_CHANCE_PER_ROW) -- the score bump is
# the reward for the extra risk.
#
# RAISED 10x (1 -> 10 and 5 -> 50) BY THE COMBO BATCH, and the ratio
# between them is deliberately untouched, as is every other design
# relationship these numbers encode (see JUMP_DODGE_BONUS_VALUE, scaled by
# the same factor for exactly that reason).
#
# WHY, measured rather than assumed: the combo multiplier applies to
# collectibles and to nothing else (see add_noisette/add_gland for why
# that restriction is correct). At the ORIGINAL values that made the
# multiplier almost purely decorative, because collectibles were about 2%
# of a run's score -- distance pays ~1 point per metre, i.e. 720-1560
# points per minute across the speed table, against roughly 22 points a
# minute of pickups. scripts/dev/ComboAudit.gd measured the consequence
# directly: with a risky bot holding a multiplier 46% of the time and
# earning an effective x1.90 on every pickup, its score at a MATCHED run
# duration beat the safe bot's by 5.0%. A 5% edge does not change how
# anyone plays; the reward existed on paper and nowhere else.
#
# Raising the base values is what gives the multiplier something to
# multiply. It is a change of SCALE, not of format -- score stays a plain
# int, and every consumer (HUD, local best in user://, the Firestore
# `score` integerValue) is unaffected in shape. Scores after this batch are
# NOT comparable with scores from before it, which matters for exactly one
# thing: existing leaderboard entries now sit lower than equivalent new
# runs.
const NOISETTE_VALUE: int = 10
const GLAND_VALUE: int = 50

## Points for successfully jumping OVER a jumpable hazard on its own
## lane (chantier 2, playtest-fixes batch -- see Obstacle.gd
## _resolve_risk_event for the detection and JumpMarkerMesh for the
## permanent "you can jump this" signal this rewards actually acting on).
## Deliberately below GLAND_VALUE: a Gland is a risk the player SEEKS OUT
## (jump timing for a bonus that costs nothing to skip); a dodge is a
## REACTION to a threat the game placed in the player's way, so it should
## read as "nice, that mattered" rather than out-earning the collectible
## the whole jump economy is built around. Kept above a single
## NOISETTE_VALUE so it still registers as more than background score.
##
## Scaled 10x (2 -> 20) alongside NOISETTE_VALUE/GLAND_VALUE by the combo
## batch, purely so the two relationships this constant's own doc asserts
## -- below a Gland, above a Noisette -- keep holding. Leaving it at 2
## while the other two moved would have silently inverted both.
const JUMP_DODGE_BONUS_VALUE: int = 20

# Score is the sum of FOUR independently tracked counters so that a
# collectible pickup (or a jump-dodge bonus) can never be silently
# overwritten by the next distance-based score tick, or by another
# counter's own update (see add_distance / add_noisette / add_gland /
# add_jump_dodge_bonus).
var distance_score: int = 0
var noisette_score: int = 0
var gland_score: int = 0
var jump_dodge_score: int = 0
var score: int = 0

# Raw pickup counts, separate from noisette_score/gland_score above.
# NOT part of the score computation (gland_score already folds
# GLAND_VALUE points into `score` -- these two exist purely so the HUD
# and the leaderboard submission have a "how many of each did I collect"
# number that isn't pre-multiplied by a point value).
var nut_count: int = 0
var gland_count: int = 0

## How many of each RiskEvent kind this run has credited -- index-aligned
## with the RiskEvent enum. Fixed-size, allocated ONCE here and only ever
## indexed/reset element by element, never re-created (nothing in the game
## loop may allocate). Read by scripts/dev/ComboAudit.gd to report the
## per-minute incrementation rate of safe versus risky play; the game
## itself does not read it.
var risk_event_counts: Array[int] = [0, 0, 0, 0]

## Consecutive risk events in the current chain, and the score multiplier
## it currently buys (always >= 1, always <= COMBO_MAX_MULTIPLIER).
## combo_multiplier is DERIVED from combo_count by _multiplier_for() and
## never set independently -- one number is the state, the other is a view
## of it, so the two can never disagree.
var combo_count: int = 0
var combo_multiplier: int = 1
## Run time at which the current chain lapses. Meaningless while
## combo_count == 0. An absolute deadline rather than a countdown that is
## decremented every frame: a deadline is re-armed by one assignment on a
## risk event and cannot drift by accumulated float error over a long run.
var combo_expires_at_s: float = 0.0

func start_run() -> void:
	distance_travelled = 0.0
	run_time_s = 0.0
	current_speed = START_SPEED
	stage_index = 0
	dark_phase = DarkPhase.INACTIVE
	dark_intensity = 0.0
	_dark_phase_started_s = 0.0
	dark_variant_index = randi() % DARK_VARIANTS.size()
	distance_score = 0
	noisette_score = 0
	gland_score = 0
	jump_dodge_score = 0
	score = 0
	nut_count = 0
	gland_count = 0
	# Element-wise, never `risk_event_counts = [0,0,0,0]` -- see the var's
	# own doc: a fresh literal would be a new allocation on every retry.
	for i in risk_event_counts.size():
		risk_event_counts[i] = 0
	combo_count = 0
	combo_multiplier = 1
	combo_expires_at_s = 0.0
	state = State.PLAYING
	state_changed.emit(state)
	score_changed.emit(score)
	counts_changed.emit(nut_count, gland_count)
	combo_changed.emit(combo_count, combo_multiplier)

func end_run() -> void:
	# Dying drops the chain, like any other way of losing it -- but
	# SILENTLY (no combo_lost), because the game over screen is already
	# the feedback for what just happened and a second "you lost your
	# combo" alarm on top of it would be noise, not information.
	combo_count = 0
	combo_multiplier = 1
	combo_expires_at_s = 0.0
	combo_changed.emit(combo_count, combo_multiplier)
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
	_update_combo()

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
##
## WORLD SPEED ONLY, and deliberately so: this is the lead time for
## content that is carried toward the player by the world and by nothing
## else. An element with a forward speed of its own covers the same 140m
## in LESS time, so its real lead time is this divided by (1 + its own
## speed factor) -- see Obstacle.gd's CLOSING SPEED section header. Since
## this constant only ever sizes an UPPER bound (how far ahead a spawn
## decision has to think), the world-speed value stays the correct,
## conservative one for every element: nothing can ever be met later than
## this says.
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
	return STAGE_SPEEDS[lookahead_stage_index()]

## Same look-ahead as lookahead_speed() above, but returning the STAGE
## INDEX rather than the speed it maps to -- for callers (TrackManager's
## progressive lane-fill cap, playtest-fixes-2 batch) that need to reason
## about WHICH palier a row is being laid out for, not just its raw speed
## value. Extracted out of lookahead_speed() rather than duplicated, so
## the two can never drift apart on what "the palier this row is laid out
## for" means.
func lookahead_stage_index() -> int:
	var horizon := run_time_s + MAX_LOOKAHEAD_S
	var idx := stage_index
	while idx + 1 < STAGE_START_S.size() and STAGE_START_S[idx + 1] <= horizon:
		idx += 1
	return idx

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
		_reroll_dark_variant()
	elif run_time_s - _dark_phase_started_s >= DARK_CYCLE_PERIOD_S:
		var entering_dark := dark_phase == DarkPhase.LIGHT
		dark_phase = DarkPhase.LIGHT if dark_phase == DarkPhase.DARK else DarkPhase.DARK
		_dark_phase_started_s += DARK_CYCLE_PERIOD_S
		if entering_dark:
			_reroll_dark_variant()

	var target := 1.0 if dark_phase == DarkPhase.DARK else 0.0
	# move_toward, not an exponential lerp: it reaches the target exactly,
	# in exactly DARK_FADE_DURATION_S. An exponential lerp only asymptotes,
	# so "fully dark" and "fully back to normal" would never be reached --
	# the effect would sit permanently at ~97% and never truly clear.
	dark_intensity = move_toward(dark_intensity, target, delta / DARK_FADE_DURATION_S)

## Picks the NEXT DARK_VARIANTS index, guaranteed different from
## dark_variant_index's current value -- see that var's own doc for why
## (two consecutive dark phases must never look identical). Trivial with
## only 4 variants: draw again on a collision, bounded to a handful of
## tries so this can never loop meaningfully long.
func _reroll_dark_variant() -> void:
	var next := randi() % DARK_VARIANTS.size()
	while next == dark_variant_index and DARK_VARIANTS.size() > 1:
		next = randi() % DARK_VARIANTS.size()
	dark_variant_index = next

func add_distance(delta_distance: float) -> void:
	distance_travelled += delta_distance
	var new_distance_score := int(distance_travelled)
	if new_distance_score != distance_score:
		distance_score = new_distance_score
		_recompute_score()

## THE two places the combo multiplier is actually cashed in, and the only
## two. It applies to COLLECTIBLES ONLY -- deliberately not to
## distance_score (which would make the multiplier a reward for surviving,
## i.e. for the exact safe play this system exists to stop being optimal)
## and not to jump_dodge_score (a jump-dodge is itself a combo INCREMENT;
## multiplying it too would compound the same act twice).
##
## nut_count/gland_count stay RAW counts and are never multiplied -- they
## answer "how many did I pick up", which the HUD and the leaderboard
## submission both need to stay a literal number of objects.
func add_noisette() -> void:
	noisette_score += NOISETTE_VALUE * combo_multiplier
	nut_count += 1
	_recompute_score()
	counts_changed.emit(nut_count, gland_count)

func add_gland() -> void:
	# Scored at the multiplier in force BEFORE this pickup's own combo
	# increment below, so a gland never inflates its own value. The order
	# is the whole reason these two lines are not swapped.
	gland_score += GLAND_VALUE * combo_multiplier
	gland_count += 1
	_recompute_score()
	counts_changed.emit(nut_count, gland_count)
	# A gland sits at jump apex (TrackSegment.GLAND_Y) and cannot be
	# reached without leaving the ground -- an accepted risk by
	# construction, so reaching one IS a risk event. Registered here
	# rather than in Gland.gd so every risk kind enters the system through
	# the same single door (see register_risk_event).
	register_risk_event(RiskEvent.GLAND)

## Called by Obstacle.gd (_trigger_jump_dodge_feedback) the instant a
## jump-dodge is detected. No raw-count sibling the way nut_count/
## gland_count exist for the two collectibles -- nothing currently reads
## "how many hazards did I jump over" (HUD only shows noisette/gland
## counts, see HUD.gd), so no counter is added ahead of an actual need.
func add_jump_dodge_bonus() -> void:
	jump_dodge_score += JUMP_DODGE_BONUS_VALUE
	_recompute_score()

## THE one entry point for "the player just did something risky". Called
## by Obstacle.gd (the three hazard-passage kinds) and by add_gland()
## below; nothing else may call it, so "what counts as a risk" stays
## answerable by reading the RiskEvent enum's doc and those two call sites.
##
## Silently ignores events outside a live run: a hazard can finish crossing
## Z=0 on the same physics frame the run ends, and crediting that would
## show up as a phantom increment on the game over screen.
func register_risk_event(kind: RiskEvent) -> void:
	if state != State.PLAYING:
		return
	risk_event_counts[kind] += 1
	combo_count += 1
	combo_expires_at_s = run_time_s + COMBO_TIMEOUT_S
	var previous_multiplier := combo_multiplier
	combo_multiplier = _multiplier_for(combo_count)
	risk_event.emit(kind)
	combo_changed.emit(combo_count, combo_multiplier)
	if combo_multiplier > previous_multiplier:
		combo_tier_up.emit(combo_multiplier)

## Collapses the chain once COMBO_TIMEOUT_S has elapsed with no risk event.
## Driven from advance_time() -- the same clock everything else in this
## file is derived from -- so a headless probe stepping the run at a fixed
## delta sees exactly the timing a real run does.
func _update_combo() -> void:
	if combo_count == 0:
		return # nothing to lose; also keeps this a single compare on most frames
	if run_time_s < combo_expires_at_s:
		return
	combo_count = 0
	combo_multiplier = 1
	combo_changed.emit(combo_count, combo_multiplier)
	combo_lost.emit()

## Seconds left before the current chain lapses, clamped at 0. Returns 0
## when there is no chain at all, so a caller never has to special-case
## combo_count == 0 before asking (the HUD does not).
func combo_time_left_s() -> float:
	if combo_count == 0:
		return 0.0
	return maxf(0.0, combo_expires_at_s - run_time_s)

## The multiplier a given chain length buys -- one tier per COMBO_TIER_SIZE
## events, floored at 1 and capped at COMBO_MAX_MULTIPLIER. Pure, so the
## whole progression can be read (and re-tuned) as one line.
func _multiplier_for(count: int) -> int:
	return clampi(1 + count / COMBO_TIER_SIZE, 1, COMBO_MAX_MULTIPLIER)

func _recompute_score() -> void:
	score = distance_score + noisette_score + gland_score + jump_dodge_score
	score_changed.emit(score)
