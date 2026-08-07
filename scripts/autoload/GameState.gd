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
## Fires the first frame the pursuer's lead drops under
## PURSUER_VISIBLE_LEAD_S -- i.e. the moment it stops being an abstract
## number and becomes a thing on screen. The single strongest tension beat
## the run has, so it gets its own signal rather than leaving every
## listener to diff the lead itself.
signal pursuer_became_visible()
## Fires when the lead climbs back OVER the threshold -- the pursuer is
## driven off. Paired with the above so a listener never has to poll.
signal pursuer_lost_sight()
## Fires the frame the lead hits zero, immediately before end_run.
signal pursuer_caught()
## Fires once per CREDITED non-fatal contact (see register_strike) -- never on
## one swallowed by the invulnerability window, so a listener can treat it as
## "a strike just happened" without re-deriving that test. Carries the
## obstacle type as a plain int (see register_strike's own doc for why it is
## not typed as Obstacle.Type here) and the strike count AFTER this one.
signal strike_taken(source_type: int, strikes_used: int)
## Fires when a strike is given back -- by time or by combo, the two paths
## being distinguished by the argument rather than by two signals, since every
## listener so far draws them identically.
signal strike_cleared(strikes_used: int, by_combo: bool)

enum State { TITLE, PLAYING, GAME_OVER }

## Why the run ended. Set immediately before end_run() and read by
## GameOverScreen so being caught from behind does not present as the same
## event as running into something in front. Nothing about SCORING or the
## leaderboard payload varies with this -- see end_run().
##
## PURSUER now covers BOTH ways of being caught from behind, and that is the
## point rather than a shortcut: the lead draining to zero, and the second
## non-fatal contact (see register_strike). They are the same event told two
## ways -- the pursuer closes because you stumbled, or because you coasted --
## and a player who is told "rattrape" in both cases learns one rule instead
## of two. COLLISION stays what it always was: running headfirst into
## something that kills on contact (see Obstacle.is_fatal).
enum DeathCause { COLLISION, PURSUER }

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
# PURSUER -- a threat that follows the player from BEHIND, whose distance
# is a function of how the player has been playing rather than of where
# the track happened to put an obstacle.
#
# THE ARCHITECTURAL DECISION, and the reason this block is a set of plain
# floats rather than a node: the pursuer's distance is stored as an
# ABSTRACT LEAD, never as a 3D position, for as long as it is not on
# screen. Two reasons, both structural rather than stylistic:
#
#   1. THE WORLD HAS NO BEHIND. This game is world-toward-player: Keepy is
#      pinned at Z=0 forever and TrackManager scrolls segments past him
#      (see TrackManager._physics_process). Everything that exists is laid
#      out AHEAD and moves back; there is no pooling, no recycling and no
#      spawn logic for anything at positive Z, and a segment that reaches
#      RECYCLE_Z is destroyed rather than tracked. A permanently-simulated
#      3D pursuer would need all of that built for it alone.
#   2. IT WOULD BE SIMULATION NOBODY LOOKS AT. Below the visibility
#      threshold the pursuer is off screen by construction, so a real node
#      would be a transform, a physics tick and a draw call spent on
#      something that cannot be seen, every frame of every run, purely to
#      hold a number this file can hold in one float.
#
# So the lead lives here and evolves by game rules alone. A real node is
# instantiated (pooled, one instance, see Pursuer.gd) ONLY once the lead
# drops under PURSUER_VISIBLE_LEAD_S, and it is positioned FROM this
# number rather than the other way round. The number is the truth; the
# node is a view of it.
#
# UNIT: SECONDS OF LEAD, never metres, and this is what makes the threat
# behave the same at every palier. The world-space gap is
# `lead * current_speed`, so the pursuer's closing speed in m/s is
# proportional to the world speed -- exactly the CHARGER's own
# closing-speed contract (see Obstacle.CHARGER_SPEED_FACTOR), reached from
# the other direction. Stored in metres instead, the same lead would buy
# less and less time as the speed table climbs, and the threat would
# quietly become unsurvivable at the cap without any constant here
# changing.
# =====================================================================

## Lead the player starts a run with, and the ceiling it can be built back
## up to. The ceiling matters: without it a long stretch of good play would
## bank an arbitrarily large buffer and the pursuer would stop being a
## threat for the rest of the run -- the reward for risk has to be staying
## ahead, not earning permanent immunity.
const PURSUER_START_LEAD_S: float = 12.0
const PURSUER_MAX_LEAD_S: float = 15.0

## Lead below which the pursuer becomes a real, visible object (see
## Pursuer.gd). Deliberately well under the starting lead so that seeing it
## at all is already an event, not the default state of a run -- and, since
## PURSUER_GRACE_S holds the lead flat at PURSUER_START_LEAD_S for the
## first 5s of every run, this must also stay STRICTLY BELOW
## PURSUER_START_LEAD_S (12.0): a threshold at or above it would make the
## pursuer visible from the opening seconds of literally every run, before
## any skill differentiation has even happened.
##
## WAS 5.0. Raised after a retour joueur ("je ne vois pas la valeur
## ajoutee") traced to PursuerAudit.gd never having measured a mid-skill
## player at all -- only the SAFE and RISKY extremes it already had. Its
## new INTERMEDIATE phase (see that file) showed the gap directly: at 5.0
## a mid-skill bot's minimum lead over a 300s sample never dropped below
## ~9.95s, so it saw the pursuer 0.0% of the time -- the mechanic existed
## and was simply never met by anyone playing at a normal level.
##
## Raising this alone tops out well short of the target band even at the
## structural ceiling (11.9, just under PURSUER_START_LEAD_S: measured
## 5.2%) -- see PURSUER_CLOSE_RATE below for the second lever this needed.
## At 10.0 (paired with that change), the INTERMEDIATE bot measures
## visible 17.6% of the time, RISKY stays at 0.4% (still rare, as
## designed), and SAFE still gets caught -- see PursuerAudit.gd's
## INTERMEDIATE_VISIBLE_FRAC_MIN/MAX for the target band this is tuned
## against and its pass criterion that enforces it going forward.
const PURSUER_VISIBLE_LEAD_S: float = 10.0

## Lead lost per second when the player is doing nothing risky --
## dimensionless (seconds of lead per second of running). At the ORIGINAL
## 0.20, a player who takes NO risk at all was caught after
## PURSUER_START_LEAD_S / 0.20 = 60s, the hard floor this system
## guarantees (scripts/dev/PursuerAudit.gd's HOSTILE phase measures it
## rather than assuming it).
##
## WAS 0.20. Raised alongside PURSUER_VISIBLE_LEAD_S -- see that constant's
## doc for the full reasoning (retour joueur -> PursuerAudit.gd's new
## INTERMEDIATE phase -> the visibility threshold alone could not reach
## the target band while staying under PURSUER_START_LEAD_S, so this is
## the second lever the task explicitly allows once the first is not
## enough). At 0.20 a mid-skill player's risk-event income
## (~13.5/min * PURSUER_RISK_REWARD_S = 0.34 lead-s/s) so comfortably
## outpaced the drain that their lead pinned itself against
## PURSUER_MAX_LEAD_S almost permanently, which is what made the
## visibility threshold powerless on its own: there was no meaningful
## variance below the ceiling for any threshold to catch. At 0.25 the same
## income (0.34/s) still outpaces the drain (net +0.09 lead-s/s, so the
## lead still recovers and RISKY still never gets caught), but leaves
## enough headroom that ordinary bad luck now dips a mid-skill run's lead
## into visible range with the measured 17.6% frequency instead of ~0%.
## The HOSTILE floor drops from 65.0s to 12.0/0.25 + 5.0 = 53.0s with this
## change -- comfortably clear of the >=30s minimum the audit still
## enforces (TrackManager's calm windows top out around 2-3s).
const PURSUER_CLOSE_RATE: float = 0.25

## Lead regained per credited risk event -- ANY of the four kinds, reusing
## GameState.register_risk_event's existing detection wholesale rather than
## adding a second notion of "the player did something brave".
##
## Sized against the rates ComboAudit actually measured: safe play banks
## ~1.6 events/min (0.027/s, worth 0.04 lead-s/s, well under the drain
## whether at its original 0.20 or the current PURSUER_CLOSE_RATE -- still
## caught either way), risky play banks ~16.7 events/min (0.28/s, worth
## 0.42 lead-s/s, comfortably above the drain at either value -- pegged at
## the ceiling and never caught). That gap IS the mechanic; see
## PURSUER_CLOSE_RATE's own doc for why the visibility-tuning batch raised
## the drain rather than this constant -- the gap itself did not need to
## change, only how much headroom the middle of it leaves below the
## ceiling.
const PURSUER_RISK_REWARD_S: float = 1.5

## Run time before the pursuer starts closing at all.
##
## Not politeness -- a fairness requirement. TrackManager keeps its first
## SAFE_START_SEGMENTS rows obstacle-free, so for the opening seconds of a
## run there is nothing to jump, nothing to graze and nothing to dodge
## late: NO risk event is physically available. Draining the lead across a
## window where the player cannot possibly refill it would be charging them
## for the game's own ramp-up.
const PURSUER_GRACE_S: float = 5.0

# =====================================================================
# STRIKES -- the death model itself, and the reason this block exists at
# all. Retour joueur: the pursuer "n'a aucun lien causal visible avec ce
# que fait le joueur -- plus du bruit parasite qu'autre chose".
#
# THE DIAGNOSIS, and it is structural rather than a matter of tuning. Up to
# here the pursuer closed by the ABSENCE of something: no risk event for a
# while, so the lead drains. An absence has no instant, no sound and no
# frame the player can point at, so the thing behind them moved for reasons
# they could not perceive. Temple Run's monkeys are legible for exactly the
# opposite reason -- they gain ground because you JUST hit something, right
# then, visibly. The event is what makes the threat readable, not the rate.
#
# So this block gives the pursuer an EVENT to react to, and in doing so
# moves where death comes from:
#
#   BEFORE: every hazard killed on contact. The pursuer was a parallel
#           timer that a sufficiently active player never met.
#   AFTER:  the two STATIC hazards (DODGE, JUMP -- things that simply sit
#           there) no longer kill. They cost you ground, loudly. The
#           pursuer is what finally kills you, either by draining the lead
#           or by taking the second stumble. The four ACTIVE hazards
#           (CHARGER, STOMPER, ENEMY, AIR_ENEMY -- things that move, track
#           and commit) still kill outright, because a hazard that hunted
#           you and won has already told its own story.
#
# See Obstacle.is_fatal for that split as code. It is a classification, not
# a behaviour change: nothing about how any of the six hazards moves,
# telegraphs or is spaced is touched by this block.
# =====================================================================

## How many non-fatal contacts a run survives. The SECOND one is the catch
## -- not a third strike then a catch, which would need a third state the
## HUD has to teach. Two means the indicator has exactly two readings
## ("clear" and "one more and you are done"), and the second one is
## unambiguous the first time a player sees it.
const STRIKE_CAPACITY: int = 2

## Fraction of the run's speed the player keeps during a stumble -- the
## penalty itself. THE PURSUER DOES NOT SLOW DOWN WITH THEM, which is the
## whole mechanic: the gap is closed by the DIFFERENCE, so a stumble is
## paid for in ground lost rather than in an abstract number ticking down.
## See _update_pursuer, where the deficit (1.0 - player_speed_factor) is
## added to the drain as a plain physical consequence rather than as a
## second, separately-tuned punishment.
##
## 0.55 is deep enough to be unmistakable from the cockpit (the track
## visibly lurches) without being a stop -- a full halt would make the
## following hazard's reaction window meaningless, since everything ahead
## would hang in place and then rush back at the player on recovery.
const STRIKE_SLOWDOWN_FACTOR: float = 0.55

## The stumble's two halves, in seconds: flat at STRIKE_SLOWDOWN_FACTOR for
## the HOLD, then a linear climb back to full speed over the RECOVER. Split
## in two rather than one eased curve because they mean different things --
## the hold is the punishment, the recover is the player getting back on
## their feet -- and a designer re-tuning "how hard" should not have to
## also re-tune "how long it takes to shake off".
##
## Together they cost (1 - 0.55) * 0.7 + (1 - 0.775) * 0.8 ~= 0.5s of lead
## through the deficit alone, on top of the cap below.
const STRIKE_SLOWDOWN_HOLD_S: float = 0.7
const STRIKE_SLOWDOWN_RECOVER_S: float = 0.8

## Lead the pursuer is pulled to on any strike, if it was not already
## closer -- a CEILING applied to the lead, never a subtraction.
##
## THIS IS WHAT MAKES THE PENALTY VISIBLE, and it has to exist as its own
## rule: the deficit above costs about half a second of lead, which from a
## full 15s buffer would leave the pursuer exactly as invisible as it was
## before the player got hit. The brief asks for the pursuer to be on
## screen DURING a penalty "quel que soit son etat precedent", and only a
## clamp can promise that regardless of the lead it starts from.
##
## STRICTLY BELOW PURSUER_VISIBLE_LEAD_S (10.0), and that inequality is the
## guarantee -- not the specific value.
##
## 4.0 rather than the 7.0 this batch first tried, and the difference is the
## whole mid-skill half of the design. MEASURED (scripts/dev/StrikeAudit.gd):
## at 7.0 a stumble left ~28s of runway before the drain alone could finish
## the job, which a mid-skill player's risk income comfortably out-earns, so
## the ONLY way that profile could ever be caught was to stumble twice inside
## TIME_TO_CLEAR_STRIKE_S -- rare enough that the probe measured 0 captures
## against 9 deaths by fatal hazard, i.e. the redesign had not actually moved
## where death comes from for the one profile it was written for.
##
## At 4.0 a stumble takes most of the buffer, which is what the Temple Run
## reference this whole block is built on actually does: you clip something,
## the thing behind you is ON you, and the next twenty seconds decide it. The
## lead is still fully recoverable -- three risk events buy it back
## (PURSUER_RISK_REWARD_S) -- so this is a debt, not a sentence.
##
## A ceiling and not a subtraction so that two stumbles in a row cannot
## stack into an instant catch: the second one is the catch already, by
## STRIKE_CAPACITY, and it should be the strike count that kills rather
## than an arithmetic coincidence nobody can see coming.
const STRIKE_PURSUER_LEAD_CAP_S: float = 4.0

## Contacts inside this window of the last credited one are ignored --
## see register_strike.
##
## Sized against the track, not chosen: TrackManager.MIN_OBSTACLE_GAP_S
## keeps ~0.80s of reaction time between two hazards, so anything shorter
## than that would let an ordinary back-to-back pair take both strikes and
## end the run in one beat the player never had a frame to answer. 1.2s
## covers that gap with margin (and the stumble slows the world down, which
## stretches the real gap further still), while staying far short of the
## 10s recovery below -- it is a "that was one hit" filter, not a free ride.
const STRIKE_INVULNERABLE_S: float = 1.2

## Seconds of clean play (no new contact) that give one strike back.
##
## STARTED AT 10.0, the genre's own reference point (Temple Run recovers
## fully in ~8-10s of clean running), then MEASURED rather than kept on
## faith -- see scripts/dev/StrikeAudit.gd.
##
## RAISED TO 14.0, and by the measurement rather than by taste. At 10.0 this
## path did not merely dominate the combo one below, it made it unreachable:
## across all three profiles the probe recorded 5 strikes given back by time
## and 1 by combo, because a mid-skill player banks a risk event every ~5s,
## so a chain long enough to matter takes longer to build than 10s of simply
## not being hit. A recovery the player can WORK for has to be able to beat
## the one they get for free, or it is decoration. 14.0 leaves the passive
## path clearly present (it is still the one a cautious player lives on) while
## putting it behind the active one for anyone holding a chain.
const TIME_TO_CLEAR_STRIKE_S: float = 14.0

## Combo length that gives one strike back immediately -- reusing the
## EXISTING risk/combo chain (see register_risk_event) rather than counting
## anything new, so "play well and you get your footing back" is measured
## by the same events the rest of the game already rewards.
##
## Granted every time the chain reaches an exact multiple of this, so a long
## chain keeps paying rather than paying once -- and bounded anyway by there
## only ever being at most STRIKE_CAPACITY - 1 strikes outstanding.
##
## STARTED AT 5 and LOWERED TO 3 -- again by measurement (see
## TIME_TO_CLEAR_STRIKE_S for the numbers: at 5, one single strike in a whole
## audit was ever given back this way). But 3 is not simply "5 minus enough
## to make it fire": it is COMBO_TIER_SIZE, so this path now lands exactly on
## the tier boundaries the combo system already teaches. Reaching x2 is what
## gives your footing back, reaching x3 gives it back again -- one rule the
## player has already learned, rather than a second threshold to track
## alongside the multiplier's.
const COMBO_TO_CLEAR_STRIKE: int = COMBO_TIER_SIZE

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

## Seconds of lead the player currently holds over the pursuer -- see the
## PURSUER block above for why this is a lead in SECONDS and not a position
## in metres. Clamped to [0, PURSUER_MAX_LEAD_S] at all times: it never goes
## negative (zero IS the catch, handled the frame it is reached) and never
## exceeds the ceiling.
var pursuer_lead_s: float = PURSUER_START_LEAD_S
## Whether the pursuer is currently close enough to be a real object on
## screen. Derived from pursuer_lead_s, but stored so the crossing can be
## detected exactly once (see _update_pursuer) rather than recomputed by
## every listener.
var pursuer_visible: bool = false
## Why the current run ended -- only meaningful once state == GAME_OVER.
var death_cause: DeathCause = DeathCause.COLLISION

## Non-fatal contacts taken so far this run, in [0, STRIKE_CAPACITY). Never
## reaches STRIKE_CAPACITY as a resting value: the strike that would take it
## there ends the run on the same frame (see register_strike), so every value
## this can be observed at is a state the player is still playing in.
var strikes_used: int = 0

## Fraction of the run's speed the player is currently making good, 1.0
## normally and STRIKE_SLOWDOWN_FACTOR during a stumble. THE ONE PLACE the
## penalty exists -- everything else about it (the ground lost to the
## pursuer, the score not accrued, the world visibly lurching) is a
## consequence of this number rather than a separate effect that has to be
## kept in step with it.
##
## Read through scroll_speed(); no caller multiplies by it directly.
var player_speed_factor: float = 1.0

## Elapsed seconds inside the current stumble, or < 0.0 when there is none --
## the same "-1.0 means idle" convention as the HUD's and the jump marker's
## own pop timers.
var _strike_slow_t: float = -1.0
## Run time before which a contact is swallowed (see STRIKE_INVULNERABLE_S).
var _strike_invulnerable_until_s: float = -1.0
## Run time the recovery clock is measured from: the last credited strike, or
## the last strike given back. Meaningless while strikes_used == 0.
var _strike_clean_since_s: float = 0.0

## Lifetime counters for the run, read by scripts/dev/StrikeAudit.gd to
## report how the death model actually behaves per skill profile. The game
## itself does not read them -- same arrangement as risk_event_counts.
var strikes_taken_total: int = 0
var strikes_cleared_by_time: int = 0
var strikes_cleared_by_combo: int = 0

## DEV-ONLY ESCAPE HATCH. Always true in a real run; nothing in the shipped
## game ever writes it (the only writers live under scripts/dev/, which the
## web export excludes).
##
## It exists because the pursuer is a PARALLEL system, and the probes that
## predate it are not measuring it. AntiFrustrationAudit and
## RushFrustrationAudit both run a lane-roaming bot with collision NEUTERED
## specifically so one continuous run can cover their whole simulated window
## without restart churn -- their subject is ground-obstacle spacing, and
## whether Keepy would have survived is irrelevant to it.
##
## The pursuer breaks that assumption outright, and not subtly: it kills a
## bot that cannot die by collision, at which point GameState leaves
## PLAYING, both probes early-return on every subsequent frame, and neither
## ever reaches its own completion check. MEASURED BEFORE WRITING THIS, not
## predicted -- the first AntiFrustrationAudit run after the pursuer went in
## printed its header and then hung indefinitely, where the same seed had
## finished in about ninety seconds an hour earlier.
##
## Switching it off in those two probes is also precisely what keeps their
## numbers comparable to the pre-pursuer baseline: they go on measuring
## exactly what they were written to measure. PursuerAudit leaves it on.
var pursuer_enabled: bool = true

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
	pursuer_lead_s = PURSUER_START_LEAD_S
	pursuer_visible = false
	death_cause = DeathCause.COLLISION
	strikes_used = 0
	player_speed_factor = 1.0
	_strike_slow_t = -1.0
	_strike_invulnerable_until_s = -1.0
	_strike_clean_since_s = 0.0
	strikes_taken_total = 0
	strikes_cleared_by_time = 0
	strikes_cleared_by_combo = 0
	state = State.PLAYING
	state_changed.emit(state)
	score_changed.emit(score)
	counts_changed.emit(nut_count, gland_count)
	combo_changed.emit(combo_count, combo_multiplier)

## `cause` defaults to COLLISION so the pre-existing caller (Keepy.die(),
## untouched by this batch) keeps its exact previous behaviour without
## having to know this enum exists.
##
## NOTHING SCORE-RELATED BRANCHES ON IT. The score, the four sub-counters,
## nut_count/gland_count and therefore the entire leaderboard payload are
## identical whichever way the run ended -- being caught from behind is a
## different EVENT, not a different kind of run. GameOverScreen reads the
## cause purely to say the right thing.
func end_run(cause: DeathCause = DeathCause.COLLISION) -> void:
	death_cause = cause
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
	# BEFORE _update_pursuer, and that order is load-bearing: the pursuer's
	# drain reads player_speed_factor, which this call is what sets. The other
	# way round, every stumble's first frame would be charged at the previous
	# frame's speed and its last frame charged after recovery -- a small error,
	# but one that would make the penalty's cost depend on frame timing.
	_update_strikes(delta)
	_update_pursuer(delta)

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

## THE SPEED THE WORLD ACTUALLY MOVES AT right now: the run's nominal speed
## scaled by whatever the player is currently making good (see
## player_speed_factor / STRIKE_SLOWDOWN_FACTOR).
##
## `current_speed` and this are two different questions, and they stopped
## being the same number the moment a stumble could slow the player without
## slowing the run -- exactly the split Obstacle.own_speed_factor /
## closing_speed() already drew from the other direction, and named for the
## same reason: an implied assumption that turned out to be a property of the
## content rather than of the game.
##
## WHICH ONE A CALLER WANTS:
##   scroll_speed()    -- anything happening NOW. How far the track moves this
##                        frame, how much distance is banked for it, and how
##                        long until a given obstacle reaches the player
##                        (Obstacle.closing_speed). During a stumble the world
##                        genuinely arrives more slowly, so every reaction
##                        window computed from this stays honest instead of
##                        promising time the player does not have.
##   current_speed     -- the run's own pace, independent of stumbles: the
##                        speed table, the palier the player is in.
##   lookahead_speed() -- anything being LAID OUT for later (TrackManager's
##                        spacing rules). A stumble is over in ~1.5s, long
##                        before a row spawned during it is reached, so
##                        spacing must keep using the run's nominal pace --
##                        spacing a row for 0.55x speed would leave it
##                        absurdly tight by the time the player got there.
##
## At player_speed_factor == 1.0 this returns current_speed exactly (a
## multiplication by 1.0 is exact), so nothing outside a stumble changes.
func scroll_speed() -> float:
	return current_speed * player_speed_factor

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
	# Buying back ground on the pursuer, from the SAME event that feeds the
	# combo -- one detection, two consumers. Every risk kind is worth the
	# same here on purpose: the combo already grades them by how often each
	# is reachable, and grading them twice would make the cheapest kind
	# doubly dominant.
	#
	# Gated on the same flag as the drain: a probe that switched the pursuer
	# off must see the lead frozen, not drifting upward every time its bot
	# happens to graze something.
	if pursuer_enabled:
		pursuer_lead_s = minf(PURSUER_MAX_LEAD_S, pursuer_lead_s + PURSUER_RISK_REWARD_S)
		_refresh_pursuer_visibility()
	combo_count += 1
	combo_expires_at_s = run_time_s + COMBO_TIMEOUT_S
	# The ACTIVE half of strike recovery (see COMBO_TO_CLEAR_STRIKE): a chain
	# long enough buys back the footing a stumble cost. Read off the chain
	# that already exists rather than counting anything new, and placed here
	# -- inside the one door every risk event comes through -- so it can never
	# disagree with the combo about how long the chain is.
	#
	# A strike deliberately does NOT break the chain, which is what makes this
	# reachable at all: a player who has just stumbled is exactly the one who
	# needs a way back, and resetting their combo on the hit would put the
	# only active recovery path behind five more events starting from zero.
	if strikes_used > 0 and combo_count % COMBO_TO_CLEAR_STRIKE == 0:
		_clear_one_strike(true)
	var previous_multiplier := combo_multiplier
	combo_multiplier = _multiplier_for(combo_count)
	risk_event.emit(kind)
	combo_changed.emit(combo_count, combo_multiplier)
	if combo_multiplier > previous_multiplier:
		combo_tier_up.emit(combo_multiplier)

## THE one entry point for "the player just hit something that does not
## kill" -- called by Obstacle._on_body_entered for the two STATIC hazard
## types and by nothing else, exactly the way register_risk_event is the one
## door for the opposite kind of event.
##
## `source_type` is a plain int carrying an Obstacle.Type, deliberately NOT
## typed as one: this file is an autoload, loaded before any scene script,
## and the codebase already refuses to let it take a compile-time dependency
## on a plain scene script's contents (see MAX_LOOKAHEAD_S restating
## TrackManager's layout as a literal for the same reason). Nothing here
## branches on the value -- it is passed straight through to the
## strike_taken signal, where only scripts/dev/StrikeAudit.gd reads it, to
## report WHICH hazard type each profile actually stumbles into.
##
## Returns whether the contact was credited, so a caller can tell "ignored,
## still inside the invulnerability window" from "counted". Nothing in the
## shipped game uses the return value today; the probe does.
func register_strike(source_type: int) -> bool:
	if state != State.PLAYING:
		return false
	if run_time_s < _strike_invulnerable_until_s:
		return false # see STRIKE_INVULNERABLE_S -- one bad row is one strike
	strikes_used += 1
	strikes_taken_total += 1
	_strike_invulnerable_until_s = run_time_s + STRIKE_INVULNERABLE_S
	_strike_clean_since_s = run_time_s
	# Emitted BEFORE the capture branch below, so the flash and the shake are
	# armed on the frame of the hit whichever strike it was -- the last one
	# should not be the only one that lands silently.
	strike_taken.emit(source_type, strikes_used)
	if strikes_used >= STRIKE_CAPACITY:
		# Caught. Same signal and same DeathCause as the lead reaching zero
		# (see the DeathCause doc): stumbling twice IS being run down, and
		# telling it as a second kind of death would teach a second rule for
		# no gain. No stumble is armed -- there is nothing left to recover
		# from.
		pursuer_caught.emit()
		end_run(DeathCause.PURSUER)
		return true
	_strike_slow_t = 0.0
	player_speed_factor = STRIKE_SLOWDOWN_FACTOR
	# Gated on the same flag as the drain and the reward, for the same reason:
	# a probe that switched the pursuer off must see the lead frozen, not
	# yanked down every time its bot clips something.
	if pursuer_enabled:
		pursuer_lead_s = minf(pursuer_lead_s, STRIKE_PURSUER_LEAD_CAP_S)
		_refresh_pursuer_visibility()
	return true

## The stumble's own clock, plus the recovery-by-time rule. Driven from
## advance_time() like everything else here, so a headless probe stepping the
## run at a fixed delta sees exactly the timing a real run does.
##
## DELIBERATELY NOT a second timer per strike: with STRIKE_CAPACITY == 2
## there is at most ONE strike outstanding at any time (the second ends the
## run), so a single "clean since" instant describes the whole state. The
## loop below is still written to give back one strike at a time rather than
## all of them, so raising the capacity later changes one constant and not
## this rule.
func _update_strikes(delta: float) -> void:
	if _strike_slow_t >= 0.0:
		_strike_slow_t += delta
		if _strike_slow_t >= STRIKE_SLOWDOWN_HOLD_S + STRIKE_SLOWDOWN_RECOVER_S:
			_strike_slow_t = -1.0
			player_speed_factor = 1.0
		elif _strike_slow_t <= STRIKE_SLOWDOWN_HOLD_S:
			player_speed_factor = STRIKE_SLOWDOWN_FACTOR
		else:
			var t := (_strike_slow_t - STRIKE_SLOWDOWN_HOLD_S) / STRIKE_SLOWDOWN_RECOVER_S
			player_speed_factor = lerpf(STRIKE_SLOWDOWN_FACTOR, 1.0, clampf(t, 0.0, 1.0))
	if strikes_used <= 0:
		return
	if run_time_s - _strike_clean_since_s < TIME_TO_CLEAR_STRIKE_S:
		return
	_clear_one_strike(false)

## Gives one strike back. `by_combo` only selects which counter is credited
## and what the signal reports -- the effect on the run is identical either
## way, which is the point: the player has two ways to earn the same thing,
## one passive and one active.
func _clear_one_strike(by_combo: bool) -> void:
	strikes_used -= 1
	# Re-armed on every clear, not only on a strike, so each strike costs a
	# full TIME_TO_CLEAR_STRIKE_S of clean play rather than several draining
	# off the same one.
	_strike_clean_since_s = run_time_s
	if by_combo:
		strikes_cleared_by_combo += 1
	else:
		strikes_cleared_by_time += 1
	strike_cleared.emit(strikes_used, by_combo)

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

## THE pursuer rule, run once per frame from advance_time().
##
## Drains the lead while the player is not taking risks, and ends the run
## the moment it reaches zero. It does NOT reward here -- the reward is
## applied event-driven inside register_risk_event(), because that is
## where the game already decides what counts as a risk, and having two
## places that answer that question is how they end up disagreeing.
func _update_pursuer(delta: float) -> void:
	if not pursuer_enabled:
		return # dev probes only -- see the var's own doc
	# TWO independent reasons the gap can close, summed into one drain:
	#
	#   the BASELINE (PURSUER_CLOSE_RATE), charged only once the grace window
	#     is over -- see PURSUER_GRACE_S, no risk is available before then;
	#   the DEFICIT, charged whenever the player is making good less than the
	#     run's full speed. It is not a tuned punishment at all, it is
	#     arithmetic: the pursuer keeps the world's speed, the player keeps
	#     player_speed_factor of it, so the gap shrinks at exactly the
	#     difference. In seconds of lead that difference is (1 - factor) per
	#     second, with no reference to the speed table -- which is what keeps
	#     a stumble worth the same at 12 m/s and at the 26 m/s cap.
	#
	# At factor 1.0 the deficit is exactly 0.0 and this reduces, term for
	# term, to the arithmetic that shipped before strikes existed -- including
	# the "no drain at all during grace" early-out, which is now the drain
	# summing to zero instead of a separate return.
	var drain := (PURSUER_CLOSE_RATE if run_time_s >= PURSUER_GRACE_S else 0.0) \
		+ (1.0 - player_speed_factor)
	if drain <= 0.0:
		return
	pursuer_lead_s = maxf(0.0, pursuer_lead_s - drain * delta)
	_refresh_pursuer_visibility()
	if pursuer_lead_s > 0.0:
		return
	# Caught. Signal first, then end the run -- a listener reacting to
	# pursuer_caught wants to do so while the state is still PLAYING.
	pursuer_caught.emit()
	end_run(DeathCause.PURSUER)

## Edge-detects the visibility crossing so the two signals fire exactly
## once per transition rather than every frame the lead sits on the far
## side of the threshold.
func _refresh_pursuer_visibility() -> void:
	var should_be_visible := pursuer_lead_s <= PURSUER_VISIBLE_LEAD_S
	if should_be_visible == pursuer_visible:
		return
	pursuer_visible = should_be_visible
	if pursuer_visible:
		pursuer_became_visible.emit()
	else:
		pursuer_lost_sight.emit()

## How close the pursuer is, normalised: 0.0 = at the maximum lead and
## irrelevant, 1.0 = touching the player. The form every display surface
## wants (see HUD.gd), so the mapping lives here once instead of in each of
## them.
func pursuer_proximity() -> float:
	return clampf(1.0 - pursuer_lead_s / PURSUER_MAX_LEAD_S, 0.0, 1.0)

## The pursuer's world-space gap behind the player, in metres -- the lead
## converted through the CURRENT world speed. This is the one place that
## conversion happens, and it is what makes the pursuer's approach speed
## proportional to the world's (see the PURSUER block header).
##
## Only meaningful while the pursuer is visible; Pursuer.gd is the only
## caller, and only then.
func pursuer_gap_m() -> float:
	return pursuer_lead_s * current_speed

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
