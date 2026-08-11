extends Area3D
class_name Obstacle
## A hazard on one lane. Colliding with Keepy ends the run if it is a
## CHARGER, and costs half a strike otherwise -- see is_fatal below for the
## split and GameState's STRIKES block for what a strike buys.
## Pooled by TrackSegment: this node is created once and only ever
## shown/hidden and repositioned, never freed during gameplay.
##
## Four visual/collision variants, all always present as children so
## configure() only ever toggles visibility/disabled -- no swapping of
## Mesh resources at runtime, keeping each variant a plain child node
## that can later be replaced with a Meshy .glb independently (see
## README "Adding Meshy assets later").
##   DODGE     -- full lane height, taller than Keepy's max jump arc:
##                must be avoided by switching lanes. The ONE variant
##                that stays deliberately unjumpable -- see ENEMY below
##                for why that distinction matters and how it stays
##                visually legible.
##   JUMP      -- a low log: too tall to run through, but short enough
##                that a well-timed jump clears it (see Keepy.gd
##                JUMPABLE_OBSTACLE_TOP_HEIGHT for the clearance math).
##   ENEMY     -- sways between its lane and an adjacent one while the
##                player approaches (a visible, escalating tell -- see
##                ENEMY_OSCILLATION_HZ_START/_END/ENEMY_ALARM_* below),
##                then LOCKS onto a final lane a fixed TIME BEFORE
##                CONTACT (ENEMY_REACTION_WINDOW_S) rather than a fixed
##                time after spawning. TWO changes from the original
##                design (playtest: "too easy, had to lose on purpose"):
##                  1. the lock lane is no longer an RNG draw settled at
##                     SPAWN time -- it is read from Keepy's ACTUAL
##                     current lane at the LATE moment the lock
##                     resolves (see _resolve_late_lock), so the enemy
##                     can commit to whichever lane the player happens
##                     to be standing on, including the one they never
##                     left. A pre-drawn target was blind to the player
##                     and could not do this.
##                  2. its hitbox is now JUMPABLE (top height =
##                     Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT, the exact same
##                     contract as JUMP -- see CapsuleMesh_Enemy /
##                     CapsuleShape3D_Enemy in Obstacle.tscn), giving a
##                     lane-locked ENEMY a SECOND escape besides
##                     switching lanes: a well-timed jump over it. This
##                     is deliberately NOT extended to DODGE, which stays
##                     full lane height -- see the anti-frustration
##                     exclusion in _resolve_late_lock for why an escape
##                     must always exist, and TrackManager's spawn-time
##                     comments for why DODGE alone is exempt from ever
##                     needing one (it always has the lane-switch escape,
##                     never targets the player, see below).
##                Collision is only ever tested against the settled
##                position (or DODGE's fixed one), never a mid-sway one,
##                so it stays fully deterministic and testable.
##   AIR_ENEMY -- MOBILE (playtest: "too easy" again): starts the
##                approach at the SAME height as the Gland collectible
##                (AIR_ENEMY_Y below, derived from the exact same formula
##                as TrackSegment.GLAND_Y -- never a duplicated literal)
##                on its SPAWN (flight) lane -- ground-level running
##                passes safely underneath, a jump on its CURRENT lane
##                runs straight into it, exactly the original AIR_ENEMY
##                contract -- then DESCENDS over its final approach and
##                LANDS, becoming a jumpable ground hazard (same
##                JUMPABLE_OBSTACLE_TOP_HEIGHT contract as ENEMY) for the
##                remainder of the approach. See _process_air_enemy for
##                the exact schedule and why landing completes a full
##                ENEMY_REACTION_WINDOW_S before contact -- the same
##                reaction budget the ground ENEMY's own hard lock
##                guarantees.
##                MULTI-LANE LANDING (playtest-fixes batch, chantier 3):
##                its LANDING lane is no longer always the same as the
##                lane it spawned/is flying over -- at
##                AIR_ENEMY_DESCENT_LEAD_S before contact (the SAME
##                instant its descent visibly begins) it picks a landing
##                lane the SAME way ground ENEMY's late lock does --
##                targets Keepy's ACTUAL current lane, redirected via the
##                SAME TrackManager.lane_has_conflicting_jump_hazard
##                anti-frustration check and _safe_redirect_lane fallback
##                if that lane is unsafe (see _resolve_air_enemy_landing_lane)
##                -- then LERPS its X from the flight lane to the landing
##                lane over the SAME t as its Y descent, so the lateral
##                drift and the vertical descent read as one continuous,
##                early, smoothly-converging telegraph rather than two
##                separate cues. Both X and Y finish converging at the
##                exact same instant (ENEMY_REACTION_WINDOW_S before
##                contact) -- the landing lane is fully committed no
##                later than ground ENEMY's own hard-lock margin, never
##                later. A DECIDED-ONCE guard (_air_enemy_lane_decided)
##                means the target is read from wherever the player
##                happens to be AT DECISION TIME, then held fixed for the
##                whole convergence -- exactly the same "committed, not
##                continuously re-aimed" contract ENEMY's own late lock
##                uses (see _enemy_late_lock_resolved).
##
## JUMPABLE MARKER (chantier 2, playtest-fixes batch: "je ne comprends
## pas que je peux sauter par-dessus, ca ne se voit pas") -- JUMP and
## ENEMY (once settled or, for a landed AIR_ENEMY, once it lands) carry a
## small always-visible glowing marker (JumpMarkerMesh, Obstacle.tscn)
## floating above the hazard, at the SAME height for all three (see
## JUMP_MARKER_Y_OFFSET). PERMANENT and INDEPENDENT of ENEMY's alarm-tint
## ramp -- it is shown from the moment a hazard becomes jumpable, not
## once danger is imminent, precisely so the player can plan a jump from
## far away instead of reading it only in the last instant. Never shown
## on DODGE (never jumpable) or on an AIR_ENEMY still airborne (jumping
## there is exactly what makes contact, see Obstacle.blocks_jump -- since
## the half-strike rebalance that costs half a strike rather than the run,
## but it is still the wrong move and still the reason no marker invites
## it). Clearing a
## jumpable hazard by jumping over it on its exact lane also triggers a
## small score bonus + a marker "pop" -- see _resolve_risk_event below and
## GameState.JUMP_DODGE_BONUS_VALUE.

##   CHARGER   -- the ONLY hazard with a forward speed of its OWN (see
##                CHARGER_SPEED_FACTOR and the CLOSING SPEED section
##                below): it does not merely wait to be reached, it
##                CLOSES on the player, arriving well over twice as fast
##                as the world scrolls. Straight line down its spawn
##                lane, start to finish -- it never tracks the player and
##                never changes lane, so the read is "which lane is it
##                on, am I on it" and the escape is always a lane switch.
##                Unjumpable, exactly like DODGE and with a hitbox
##                identical to DODGE's, so its fairness contract is a
##                known quantity rather than a newly tuned one.
##                Telegraphed by a dedicated silhouette (a wedge whose
##                nose points at the player, unlike every other variant's
##                symmetrical shape), a colour used nowhere else in the
##                game, and three speed-line bars trailing behind it that
##                nothing else has -- see the TELEGRAPH section below.
##
##   STOMPER   -- the deliberate INVERSE of CHARGER, closing the last open
##                loop of the difficulty plan: a ground hazard that jump
##                alone escapes, and lane switch NEVER does, by
##                construction rather than by tight timing. Same FAMILY as
##                ground ENEMY (a provisional spawn lane, then a late
##                commit at the same ENEMY_REACTION_WINDOW_S threshold ENEMY
##                itself hard-locks at -- see _process_stomper), but where
##                ENEMY's late lock FREEZES onto a single decided lane
##                (leaving a real, if tight, switch escape -- see its own
##                doc), STOMPER's commit NEVER freezes: from the instant it
##                commits it mirrors Keepy's own position.x EXACTLY, every
##                physics frame, for as long as it remains live. Its
##                lateral separation from the player is therefore
##                identically 0.0 for the rest of its approach -- not a
##                narrow timing window that happens to be hard to beat, an
##                actual zero, so no lane switch of any speed can open a
##                gap. Jump remains the escape because its hitbox reuses
##                JUMP's own verified box (Obstacle.tscn StomperShape /
##                BoxShape3D_Jump, same JUMPABLE_OBSTACLE_TOP_HEIGHT
##                contract as JUMP/ENEMY/a landed AIR_ENEMY) -- see
##                blocks_jump/blocks_lane_switch below for the two static
##                predicates that state this pair of facts as code, not
##                just as a comment. See TELEGRAPH-STOMPER further down for
##                its dedicated visual signal.

enum Type { DODGE, JUMP, ENEMY, AIR_ENEMY, CHARGER, STOMPER }

# =====================================================================
# CLOSING SPEED -- see own_speed_factor / closing_speed() further down.
#
# Every hazard shipped so far is carried toward the player by the world
# and by nothing else (TrackManager moves each TrackSegment at
# GameState.current_speed; an obstacle is a child of a segment and never
# touches its own Z). That made "the world's speed" and "the speed this
# thing is arriving at" the same number everywhere, and the whole pacing
# system quietly assumed it: this file converted distance to
# time-before-contact with GameState.current_speed, and TrackManager
# converted reaction-time budgets to row counts with
# GameState.lookahead_speed().
#
# That assumption is not a property of the game, it is a property of the
# hazards that happened to exist. An obstacle with a forward speed of its
# own breaks it by construction -- its real reaction window is set by the
# CLOSING speed (world + its own), not by the world's. So the assumption
# is now written down explicitly, per obstacle, instead of being implied:
# own_speed_factor states it, closing_speed() computes it, and everything
# that turns a distance into a reaction time goes through that one value.
#
# own_speed_factor == 0.0 (every variant in Type except CHARGER)
# reproduces the old arithmetic exactly -- verified by re-running the
# pacing, lane-fill and anti-frustration probes seeded identically
# before and after that change, see its commit message for both sets of
# numbers.
# =====================================================================

# =====================================================================
# CHARGER TUNING -- the whole knob set for the closing hazard, grouped
# here next to the pacing constants above rather than scattered through
# the code that reads them. TrackManager owns the SPAWN-SIDE knobs (how
# often, how early in a run, how much clear timeline it needs) and reads
# CHARGER_SPEED_FACTOR from here to size its spacing; this file owns
# everything about how the thing then behaves and looks.
#
# Playtest that asked for it: "c'est mieux mais toujours facile -- j'ai
# eu un frisson, c'est ca qu'on doit chercher". Diagnosis: nothing in the
# game closes FASTER than the world, so every arrival is paced by the one
# speed the player has already internalised, and stays predictable no
# matter how dense it gets. Tension is a function of closing speed, not
# of density.
# =====================================================================

## The charger's own forward speed, as a MULTIPLE of the world speed
## (see own_speed_factor). Total closing speed is therefore
## world * (1 + this) = 2.35x the world speed -- the world's own
## contribution never goes away, it is added to.
##
## Expressed as a multiple, never as a m/s value, for the same reason
## every reaction window in this file is expressed in seconds: a fixed
## m/s would be a wildly different experience at 12 m/s than at the 26
## m/s cap, and would have to be re-tuned every time the speed table
## moves. As a multiple it stays the same RELATIVE threat at every
## palier, and the reaction window it leaves scales with the ramp
## instead of collapsing at the top of it (measured per palier by
## scripts/dev/ChargerAudit.gd).
const CHARGER_SPEED_FACTOR: float = 1.35

## Global Z past which a charger takes itself out of play. It outruns
## its own TrackSegment by definition, so it reaches the player long
## before that segment recycles and would otherwise sit visible far
## behind the camera for several more seconds -- during which
## TrackManager's lane-occupancy scan would keep counting its lane as
## busy (see _active_lane_occupancy) and thin the track for no reason.
##
## Restated as a literal rather than read from TrackManager.RECYCLE_Z:
## Obstacle.gd cannot take a hard reference on TrackManager without
## re-forming the mutual class dependency documented on
## _track_manager_ref. Same precedent as GameState.MAX_LOOKAHEAD_S
## restating TrackManager's segment layout. If RECYCLE_Z moves, this
## moves with it.
const CHARGER_DESPAWN_Z: float = 12.0

# ---------------------------------------------------------------------
# TELEGRAPH -- the player must be able to name a charger as a charger the
# instant it appears, with no trial and error, and tell it apart from
# both the ordinary hazards AND the cyan jumpable marker. Three
# independent, redundant cues, so no single one has to carry it:
#
#   SHAPE   -- a wedge whose nose points AT the player (PrismMesh_Charger
#              in Obstacle.tscn, rotated so its apex leads). Every other
#              variant is a symmetrical box, capsule or torus with no
#              facing at all; "it is pointed at me" is readable as a
#              silhouette, at distance, with no colour information
#              whatsoever -- which is what makes it survive all six dark
#              palettes by construction rather than by measurement.
#   MOTION  -- three speed-line bars trailing BEHIND it, sliding backward
#              on a loop (_animate_charger_trail). Nothing else in the
#              game has anything attached behind it, so the cue is
#              unambiguous even in peripheral vision.
#   COLOUR  -- hot magenta, UNSHADED. Unshaded for the same reason the
#              jump marker is (see its own note below): its on-screen
#              colour is then the same known value every frame instead of
#              drifting with the light angle, which is what makes its
#              dark-mode contrast verifiable ahead of time rather than
#              only observable. Magenta specifically because every other
#              hue in the game is taken and a NEAR hue would be the whole
#              problem: DODGE dark red, JUMP brown, ENEMY purple,
#              AIR_ENEMY green, marker cyan, Noisette/Gland gold -- and
#              Keepy HERSELF is orange, which is why the obvious "danger
#              orange" is not available here.
#
# The body colour is deliberately CONSTANT (only the trail animates):
# a pulsing body would make "the charger's contrast against the ground"
# a range rather than a number, and there would be no single value for
# scripts/dev/DarkPaletteAudit.gd to certify per palette.
# ---------------------------------------------------------------------

## How fast the trail bars slide backward through their loop, in loops
## per second. Fast enough to read as speed rather than as drifting
## debris; the bars are evenly spaced (Obstacle.tscn) so one loop is one
## bar's worth of travel and the cycle is seamless.
const CHARGER_TRAIL_HZ: float = 3.5

## Local Z spacing between two consecutive trail bars -- must match the
## spacing baked into Obstacle.tscn's ChargerTrail children (-1.6, -2.7,
## -3.8), since the slide loop below wraps on exactly this distance to
## stay seamless.
const CHARGER_TRAIL_SPACING: float = 1.1

# Time for Keepy's lateral lane lerp (Keepy.gd LANE_SWITCH_SPEED) to reach
# ~95% of the way to a new lane -- the point a lane switch reads as "done"
# rather than "still sliding". The lerp is an exponential ease
# (position.x = lerp(x, target, 1 - exp(-LANE_SWITCH_SPEED * delta))), a
# first-order low-pass with time constant 1/LANE_SWITCH_SPEED; reaching
# 95% takes ~3 time constants (ln(0.05) ~= -3.0).
const LANE_SWITCH_TIME_S: float = 3.0 / Keepy.LANE_SWITCH_SPEED

# Extra time budgeted for the player to actually PERCEIVE the now-locked
# final lane and decide/start the swipe or key press, on top of the lane
# switch's own travel time above.
#
# TENSION REDESIGN (was 0.35s): playtesting found the enemy locking
# 0.6s before contact reads as a STATIC obstacle by the time the player
# arrives -- the sway is long since over and there is nothing left to
# react to, defeating the whole point of a moving hazard. Cut down to
# the minimum defensible margin instead of a comfortable one: this is
# NOT a full cold-start perceive+decide+act budget (~200-250ms in human
# factors literature) -- the player has been WATCHING the sway build for
# multiple seconds before this (see ENEMY_OSCILLATION_HZ_START/_END and
# ENEMY_ALARM_RAMP_WINDOW_S below), so they are primed, not reacting to
# a cold cue. 0.1s is closer to a primed flinch-reaction budget than a
# full deliberate one. Re-verified empirically after this change (see
# scripts/tools/verify_reaction_window.gd, run once and deleted) that
# the resulting window is still just barely completable by a lane
# switch started at the exact lock frame, across the whole
# BASE_SPEED..MAX_SPEED ramp -- "juste", not "confortable", by design.
const PERCEPTION_REACTION_S: float = 0.1

# Time-before-contact, in SECONDS, at which an ENEMY obstacle must already
# be locked onto its final lane: perception+decision time plus the time
# Keepy's own lane lerp needs to actually get there. Using seconds --
# converted to a speed-dependent distance every frame in _physics_process
# via GameState.current_speed -- rather than a fixed world-space distance
# is what keeps this reaction window roughly constant in real time across
# the whole GameState.BASE_SPEED..MAX_SPEED ramp; a fixed meters value
# would give a much shorter reaction window at MAX_SPEED than at
# BASE_SPEED (same distance covered in less time as speed climbs).
const ENEMY_REACTION_WINDOW_S: float = LANE_SWITCH_TIME_S + PERCEPTION_REACTION_S

# How much EARLIER than the hard lock above (again in seconds-before-
# contact) the sway starts easing from full amplitude down to the settled
# lane, instead of cutting off abruptly mid-swing. Purely cosmetic --
# ENEMY_REACTION_WINDOW_S itself is already fully locked/static by the
# time this window ends.
const ENEMY_EASE_DURATION_S: float = 0.5

# Sway frequency now RAMPS UP as the enemy closes in, instead of a flat
# constant -- a visible "getting more agitated" tell that builds tension
# BEFORE the hard lock itself, rather than the sway being a uniform blur
# right up until it suddenly freezes. Slow/calm far away (just came into
# view), frantic in the final approach.
const ENEMY_OSCILLATION_HZ_START: float = 1.1 # calm sway, far from contact
const ENEMY_OSCILLATION_HZ_END: float = 3.6 # frantic sway, just before lock
# How many seconds-before-contact (beyond the hard lock point) the
# oscillation frequency ramp spans. Beyond this window (still far away)
# frequency stays pinned at ENEMY_OSCILLATION_HZ_START.
const ENEMY_OSCILLATION_RAMP_WINDOW_S: float = 2.5

# Mesh color/emission also ramps toward a more alarming tint as the enemy
# approaches -- a SEPARATE, longer-range anticipation cue from the
# oscillation ramp above (meant to be legible from further out), and
# distinct from the lock itself: the player should be able to read
# "this is getting dangerous" well before it commits to a lane, not just
# see a binary swaying/frozen state change.
const ENEMY_ALARM_ALBEDO: Color = Color(0.95, 0.08, 0.12, 1)
const ENEMY_ALARM_EMISSION: Color = Color(1.0, 0.12, 0.05, 1)
const ENEMY_ALARM_EMISSION_ENERGY: float = 1.5
const ENEMY_ALARM_RAMP_WINDOW_S: float = 4.5

# =====================================================================
# AIR_ENEMY DESCENT/LANDING -- see the Type.AIR_ENEMY doc above.
# =====================================================================

## Time-before-contact at which the descent visibly begins. Long enough
## (several seconds) that the trajectory is unmistakably readable well
## before the player needs to act on it -- this is the "telegraphed"
## requirement, satisfied by giving the eye a slow, continuous, early cue
## rather than a late snap.
const AIR_ENEMY_DESCENT_LEAD_S: float = 3.5

## Half the Y size of BoxShape3D_AirEnemy in Obstacle.tscn (1.2m tall),
## restated here (not re-read from the resource, which would need an
## instance) so the landed-height math below stays a derivation instead
## of a second guessed literal. If that box's size ever changes, this
## must change with it.
const AIR_ENEMY_BOX_HALF_HEIGHT: float = 0.6

## Where the box's CENTER sits once landed, so its TOP lands exactly on
## Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT -- the same clearance contract as
## ENEMY and JUMP, not a separately-tuned number. (The box's bottom then
## sits below y=0 -- harmless, nothing collides with it from underneath.)
const AIR_ENEMY_LANDED_CENTER_Y: float = Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT - AIR_ENEMY_BOX_HALF_HEIGHT

# =====================================================================
# JUMPABLE MARKER + DODGE REWARD (playtest-fixes batch, chantier 2) --
# playtest: "je ne comprends pas que je peux sauter par-dessus, ca ne se
# voit pas, et meme quand je le fais je ne sens rien". Two DISTINCT
# problems, two DISTINCT fixes below: legibility (can the player tell
# THIS hazard is jumpable, from far away, before any danger cue starts)
# and reward (does clearing one on purpose feel like it mattered).
# =====================================================================

## Local Y offset of JumpMarkerMesh (Obstacle.tscn) ABOVE
## Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT -- floating clear of the hazard
## mesh itself rather than touching it, so it silhouettes as its own
## shape instead of blending into whatever is under it (JUMP's box,
## ENEMY's capsule, or a landed AIR_ENEMY's box, all sharing this same
## top height by construction -- see the const's own doc). ONE offset
## for all three, which is exactly what makes it read as "the same
## symbol" across them rather than a per-type coincidence.
const JUMP_MARKER_Y_OFFSET: float = 0.30

# JumpMarkerMesh's material (Obstacle.tscn, StandardMaterial3D_JumpMarker)
# is UNSHADED (shading_mode=0) and electric cyan (0.15, 0.95, 1.0):
# unshaded so its on-screen colour is the SAME known value every frame
# regardless of DirectionalLight3D angle/ambient -- a lit material's
# colour drifts with lighting, which would make the dark-mode contrast
# this marker exists to guarantee unverifiable ahead of time (every
# OTHER hazard mesh in this file IS lit, and that drift is exactly why
# their own post-grade colour can only be pinned down by rendering and
# measuring, never predicted from the albedo alone -- see
# scripts/dev/DarkPaletteAudit.gd). Cyan specifically because it sits far
# from every existing gameplay hue (DODGE red, JUMP brown, ENEMY purple,
# AIR_ENEMY green, Noisette/Gland gold) -- it never reads as "part of the
# hazard" or "a collectible", only as its own distinct UI-like signal.
# Measured result: see scripts/dev/DarkPaletteAudit.gd's own output --
# it is the probe that measures this marker against the ground in the
# dark phase. (This used to point at GameState.DARK_TINT_AMOUNT, a
# constant the swamp refonte deleted along with the tint pass it drove.)

## How long the marker's "cleared!" pop lasts -- brief and snappy, a
## flinch-reaction-scale acknowledgement (same design register as
## PERCEPTION_REACTION_S above), not a lingering celebration that would
## still be playing by the time the NEXT hazard needs the player's
## attention.
const MARKER_POP_DURATION_S: float = 0.35
## Peak scale multiplier of the pop, reached at the MIDPOINT of
## MARKER_POP_DURATION_S then eased back to 1.0 -- see _update_marker_pop.
const MARKER_POP_PEAK_SCALE: float = 1.9

# =====================================================================
# RISK EVENT TUNING (combo batch) -- the thresholds that decide whether a
# hazard passing the player counts as a RISK the combo system rewards.
# See GameState.RiskEvent for what the four kinds mean and why they exist;
# this block owns only the two NUMBERS the two lateral kinds need.
#
# Playtest that asked for it: "je trouve le jeu globalement trop facile" --
# diagnosed not as "the hazards are too weak" (the CHARGER fixed that:
# "j'ai perdu, bon signe") but as "nothing rewards me for playing close to
# them", so safe play is both viable AND optimal. These thresholds are what
# make the difference between grazing and giving a hazard a wide berth
# MEASURABLE, and therefore rewardable.
#
# EVERYTHING HERE IS DERIVED FROM GEOMETRY ALREADY IN THE GAME, never
# guessed: the lane pitch (TrackSegment.LANE_X, 2.0m apart), the widest
# hazard hitbox (1.2m, i.e. half-width 0.6 -- DodgeShape/ChargerShape/
# AirEnemyShape in Obstacle.tscn) and Keepy's capsule radius (0.5,
# Keepy.tscn). No new collision shape, no new Area3D, no new signal
# plumbing: the closest approach is sampled on the frames the existing
# per-frame passage check already runs.
# =====================================================================

## Lateral centre-to-centre distance below which Keepy's capsule (radius
## 0.5) and the WIDEST hazard hitbox (half-width 0.6) overlap, i.e. the
## distance at which a passage is a COLLISION rather than a graze.
##
## The floor under both LATERAL risk kinds (near-miss and late-dodge):
## a passage whose closest approach was inside this band is not a risk
## taken, it is a hit, and in a real run the player is already dead. It is
## checked explicitly anyway rather than left implicit, for two reasons:
## the dev probes deliberately neuter Keepy's collision layer (see
## AntiFrustrationAudit.gd), so without it a probe bot could walk straight
## THROUGH hazards and bank a combo for it -- which would make every safe-
## versus-risky number this batch reports a lie -- and the narrower hitboxes
## (ENEMY's capsule is radius 0.3) genuinely do let a body pass at a
## distance that clears them but not the widest ones, which should read as
## the same "too close to be a graze" for every type rather than as a
## per-type lottery.
##
## Deliberately NOT applied to JUMP_DODGE: that escape is VERTICAL, so its
## lateral distance is ~0 by definition (you jump over a hazard by being
## directly above it) and this floor would reject the one risk kind the
## game already shipped and already validated.
const RISK_MIN_SURVIVABLE_LATERAL_M: float = 1.1

## Closest lateral approach at or below which a survivable passage counts
## as a graze. Sits between the collision floor above (1.1m) and the full
## lane pitch (2.0m).
##
## WHY THIS CANNOT FIRE BY ACCIDENT: a player who is simply STANDING on a
## lane adjacent to the hazard is 2.0m away, and the lane lerp settles to
## within a millimetre of that in well under a second (Keepy.gd
## LANE_SWITCH_SPEED = 12, i.e. 95% in 0.25s). Being inside this band at
## the closest point of a passage therefore REQUIRES still being visibly
## mid-slide as the hazard goes by, which in turn requires having started
## the escape late on purpose. Playing the game the safe way -- switch as
## soon as you read the lane -- never produces a number under 1.99m.
##
## WHY 1.75 AND NOT THE 1.6 THIS BATCH FIRST USED -- measured, and changed
## because the measurement said so. The band's width in DISTANCE is not the
## quantity that matters; what the player actually controls is WHEN they
## start the escape, and the lane lerp converts one into the other. Going
## from the 1.10m floor to 1.60m takes the lerp ~67ms, so a 0.5m band was a
## ~67ms window on the input -- and the probe bore that out: over 300s of
## deliberately risky play, NEAR_MISS fired ONCE while LATE_DODGE fired 34
## times. A risk kind that rare is not a hard skill, it is dead code. 1.75m
## widens the input window to ~97ms, which is a real skill window
## (comparable to a rhythm game's "good" band) while still requiring the
## escape to begin within ~0.2m of the hazard's own contact window -- a
## quarter of a second later than even an alert cautious player would move.
## See scripts/dev/ComboAudit.gd for the safe-versus-risky rates this is
## tuned against.
const NEAR_MISS_MAX_LATERAL_M: float = 1.75

## Half-width, in metres of Z, of the window within which the closest
## lateral approach is sampled -- and therefore the window the collision
## floor above is judged over.
##
## EXACTLY the depth at which contact is geometrically possible: hazard
## half-depth 0.5 (every hazard hitbox in Obstacle.tscn is 1.0 deep) plus
## Keepy's capsule radius 0.5. That equality is the whole point and not a
## coincidence to be tuned away from. Sampling any WIDER breaks the meaning
## of RISK_MIN_SURVIVABLE_LATERAL_M: at 4m of separation in Z, being 0.8m
## off the hazard's lane is not a collision and never was, so a wider window
## would fold "briefly close while still far ahead" into "hit it" and throw
## away perfectly good grazes. Sampling any NARROWER would start the
## measurement after the closest moment had already passed. At this width,
## "the minimum stayed above the floor" means precisely "no collision
## occurred", which is what the floor is written to assert.
const RISK_PROXIMITY_Z: float = 1.0

## How late a lane change has to be, in seconds before contact, to count as
## a LATE_DODGE. Expressed in seconds and derived from the game's own
## declared reaction budget rather than picked freely: at exactly
## ENEMY_REACTION_WINDOW_S the game GUARANTEES a lane switch started then
## still completes in time (that is what the constant means), so 1.3x it is
## the tightest band that is still reliably survivable -- "you cut it fine",
## not "you got away with something the game never promised".
##
## In seconds, never in metres, for the same reason every other reaction
## window in this file is: a CHARGER closes at 2.35x the world speed, so a
## fixed distance would mean a completely different amount of real reaction
## time for a charger than for everything else, and would drift again on
## every re-tune of the speed table.
const LATE_DODGE_WINDOW_S: float = ENEMY_REACTION_WINDOW_S * 1.3

# =====================================================================
# STOMPER -- see the Type.STOMPER doc above for the full mechanic. This
# block owns only its two TUNING knobs (how fast its pulse ramps); the
# commit THRESHOLD itself is deliberately ENEMY_REACTION_WINDOW_S, reused
# rather than re-invented, so it telegraphs on the same cadence a player
# has already learned from the ground ENEMY.
#
# TELEGRAPH-STOMPER -- three independent, redundant cues, same discipline
# as the CHARGER's own TELEGRAPH section above:
#   SHAPE  -- a squat, wide-based cylinder (StomperMesh, Obstacle.tscn)
#             tapering slightly toward the top -- every other ground
#             hazard is either a tall box (DODGE/JUMP), a capsule (ENEMY)
#             or a forward-pointing wedge (CHARGER); nothing else in the
#             game reads as a wide, planted "landing pad" silhouette.
#   MOTION -- a continuous breathing PULSE (scale, see
#             STOMPER_PULSE_SCALE_AMPLITUDE below) from the moment it
#             spawns, ramping from a calm to a frantic rate as contact
#             nears (same escalating-tension shape as ENEMY's own
#             oscillation ramp) -- and, once committed, the pulse is
#             joined by the hazard visibly gluing itself to the player's
#             own lateral position every frame, which is its own
#             unmistakable "this is now tracking you" tell.
#   COLOUR -- electric ultramarine blue, UNSHADED (same "known constant
#             value per palette" reasoning as the CHARGER and the jump
#             marker -- see their own docs), a hue distinct from every
#             other gameplay colour already in use (DODGE dark red, JUMP
#             brown, ENEMY purple, AIR_ENEMY green, marker cyan, CHARGER
#             magenta, Noisette/Gland gold, Keepy orange).
#
# Colour is deliberately CONSTANT (only the pulse animates) for the exact
# same reason the CHARGER's is: a verifiable, single dark-palette contrast
# number per palette rather than a moving target -- see
# scripts/dev/DarkPaletteAudit.gd.
# =====================================================================

## Pulse frequency range (Hz) the STOMPER's scale breathes at -- calm far
## away, frantic as its commit instant nears. Purely cosmetic, MOTION only
## (see TELEGRAPH-STOMPER above): colour never ramps.
const STOMPER_PULSE_HZ_START: float = 1.4
const STOMPER_PULSE_HZ_END: float = 5.0
## How many seconds-before-commit (i.e. before ENEMY_REACTION_WINDOW_S)
## the pulse-rate ramp spans -- same role as ENEMY_OSCILLATION_RAMP_WINDOW_S.
const STOMPER_PULSE_RAMP_WINDOW_S: float = 2.5
## Peak fractional scale swing of the breathing pulse (1.0 +/- this).
const STOMPER_PULSE_SCALE_AMPLITUDE: float = 0.22

# Every visual below is a ModelSlot (scripts/world/ModelSlot.gd), not a
# plain MeshInstance3D: each is an INDEPENDENT swap point, so a Meshy .glb
# can replace one variant without disturbing the other five. A ModelSlot IS
# a MeshInstance3D, so every `.visible` / `.scale` / `.position` write in
# this file keeps working exactly as before -- see that file's header for
# why the swap point is shaped this way and not as a separate scene.
#
# The COLLISION shapes are deliberately NOT slots and never will be: they
# are gameplay, sized from Hitboxes.gd in _apply_hitboxes() below, and a
# mesh swap has no path to them.
@onready var _dodge_mesh: ModelSlot = $DodgeMesh
@onready var _dodge_shape: CollisionShape3D = $DodgeShape
@onready var _jump_mesh: ModelSlot = $JumpMesh
@onready var _jump_shape: CollisionShape3D = $JumpShape
@onready var _enemy_mesh: ModelSlot = $EnemyMesh
@onready var _enemy_shape: CollisionShape3D = $EnemyShape
@onready var _air_enemy_mesh: ModelSlot = $AirEnemyMesh
@onready var _air_enemy_shape: CollisionShape3D = $AirEnemyShape
@onready var _charger_mesh: ModelSlot = $ChargerMesh
@onready var _charger_shape: CollisionShape3D = $ChargerShape
@onready var _charger_trail: Node3D = $ChargerTrail
@onready var _jump_marker_mesh: ModelSlot = $JumpMarkerMesh
@onready var _stomper_mesh: ModelSlot = $StomperMesh
@onready var _stomper_shape: CollisionShape3D = $StomperShape

## Fired the instant a successful jump-dodge is detected (see
## _resolve_risk_event) -- purely informational, nothing in this codebase
## currently listens to it (the score bonus and marker pop are applied
## directly, not via this signal's own handler), kept for dev-probe
## hooks and any future HUD toast without adding a second detection path.
signal jump_dodged

var obstacle_type: Type = Type.DODGE

var _enemy_settling: bool = false
var _enemy_phase: float = 0.0 # accumulated sway phase, radians -- see _physics_process
var _enemy_lane_x: float = 0.0
var _enemy_alt_lane_x: float = 0.0
## Flips true the instant the late lock target has been decided (see
## _resolve_late_lock) -- guards it to a single decision per spawn rather
## than re-reading the player's lane every frame of the ease window,
## which would let the target keep sliding under the player instead of
## committing.
var _enemy_late_lock_resolved: bool = false

## True once an AIR_ENEMY has completed its descent and is sitting on the
## ground (see _process_air_enemy). Public: TrackManager's cross-obstacle
## safety scan (lane_has_conflicting_jump_hazard) reads it to tell "still
## airborne, jumping here is lethal" apart from "landed, jumping here is
## the intended escape".
var air_enemy_landed: bool = false

## True once THIS spawn has picked its landing lane (see
## _resolve_air_enemy_landing_lane) -- guards the decision to a single
## read of the player's lane per spawn, exactly the same "decide once,
## then hold" contract as _enemy_late_lock_resolved above (see that
## var's own doc for why: re-reading every frame would let the target
## keep sliding under the player instead of committing).
var _air_enemy_lane_decided: bool = false
## World-space X of the lane AIR_ENEMY is flying over BEFORE it starts
## drifting toward its landing lane -- captured from this instance's own
## `position.x` the moment _resolve_air_enemy_landing_lane runs (which is
## also the instant convergence starts, so position.x is still exactly
## the untouched spawn lane at that point). The LERP SOURCE in
## _process_air_enemy; not meaningful before _air_enemy_lane_decided.
var _air_enemy_flight_lane_x: float = 0.0
## World-space X of the CHOSEN landing lane -- the LERP TARGET in
## _process_air_enemy. Not meaningful before _air_enemy_lane_decided.
var _air_enemy_landing_lane_x: float = 0.0

## Global Z read on the PREVIOUS frame this instance was visible -- see
## _check_passage. A crossing from negative to >=0 is the exact same
## instant collision is tested (see time_to_contact_s's own doc: Keepy
## sits fixed at Z=0), so this is the one moment "did the player clear
## this on purpose" can be judged. Reset to the instance's OWN spawn Z at
## the top of configure() so a freshly (re)spawned pooled instance never
## fires a stale crossing left over from its previous life.
var _prev_pass_z: float = 0.0

## Trail-slide phase for the CHARGER variant, in local metres, wrapped to
## [0, CHARGER_TRAIL_SPACING) -- see _animate_charger_trail. Purely
## cosmetic; reset on every (re)configure so a pooled instance never
## resumes a previous life's phase.
var _charger_trail_phase: float = 0.0

## Local Z each ChargerTrail bar sits at in Obstacle.tscn, captured once
## in _ready() rather than recomputed from an assumed spacing -- the
## slide below offsets each bar from its OWN authored position, so the
## scene file stays the single source of truth for the trail's layout.
## Fixed-size, allocated once, never resized in the game loop.
var _charger_trail_base_z: Array[float] = []

## Elapsed time since the marker's "cleared!" pop started, or < 0.0 when
## no pop is playing -- see _update_marker_pop. Purely cosmetic local
## state, reset on every (re)configure so a pooled instance never enters
## a fresh spawn mid-pop from its previous life.
var _marker_pop_t: float = -1.0

## PROVISIONAL spawn-time lane for a STOMPER, in world X -- see
## TrackManager._try_stomper_lane. Only meaningful before _stomper_tracking
## flips true; after that, position.x is overwritten every frame by
## _process_stomper and this value is never read again until the next
## configure().
var _stomper_lane_x: float = 0.0
## True from the instant a STOMPER commits (time_to_contact crosses
## ENEMY_REACTION_WINDOW_S) onward -- see _process_stomper. Once true,
## position.x mirrors the player's own position.x EXACTLY every physics
## frame for the rest of this instance's life; this is the entire
## "lane switch cannot escape it" guarantee, not a comment describing one.
var _stomper_tracking: bool = false
## Accumulated pulse phase, radians -- see STOMPER_PULSE_HZ_START/_END.
## Purely cosmetic; reset on every (re)configure so a pooled instance
## never resumes a previous life's phase.
var _stomper_pulse_phase: float = 0.0

## Closest lateral (X) centre-to-centre distance between this obstacle and
## Keepy observed so far during the CURRENT passage -- sampled only on the
## frames this instance is within RISK_PROXIMITY_Z of the player, and read
## once at the Z=0 crossing to classify the passage (see
## _resolve_risk_event). INF means "nothing sampled yet this passage".
##
## A single float, re-armed to INF at the crossing and in configure(), so a
## pooled instance never judges one passage using the previous one's
## numbers -- exactly the contract _prev_pass_z already follows.
##
## The MINIMUM over the passage, not the value at the crossing instant: a
## graze is "how close did it actually get", and the closest point of a
## passage is not in general the instant the obstacle reaches Z=0 (a player
## still sliding away is nearest slightly BEFORE it, and at the top of the
## speed table the whole overlap lasts only a few physics frames).
var _min_lateral_distance: float = INF

# Cached group lookups, resolved lazily (first use, not _ready) so
# scene-tree construction order between Obstacle/Keepy/TrackManager never
# matters -- see _current_player_lane / _track_manager.
var _player_ref: Keepy = null
## Loosely typed (Node, not TrackManager) deliberately: a hard static
## type dependency here plus TrackManager.gd's own hard type dependency
## on Obstacle (its _active_obstacle_in helper) forms a MUTUAL class
## reference between two class_name scripts, which Godot's resource
## loader cannot resolve (verified empirically -- it fails the whole
## project import with "Parse Error: Busy" on both Obstacle.tscn and
## TrackSegment.tscn, not just a warning). Duck-typed access (calling
## lane_has_conflicting_jump_hazard by name on a plain Node) sidesteps
## the cycle; GDScript resolves the method at the call, not at parse time.
var _track_manager_ref: Node = null

# The EnemyMesh's material, per Obstacle.tscn, is a single shared
# StandardMaterial3D sub-resource -- every pooled Obstacle instance
# (TrackManager keeps several alive across segments) would otherwise
# fight over the SAME material, so the alarm-tint lerp on one enemy
# would bleed into every other enemy on screen. Duplicated once here
# (not per-frame -- no allocation in the game loop) so each instance
# owns its own material to animate independently.
var _enemy_material: StandardMaterial3D
var _enemy_base_albedo: Color
var _enemy_base_emission: Color
var _enemy_base_emission_energy: float

# Same shared-sub-resource problem as _enemy_material above, for
# AirEnemyMesh's material -- duplicated once so the landed-state tint
# (see _apply_air_enemy_tint) animates per-instance.
var _air_enemy_material: StandardMaterial3D
var _air_enemy_base_albedo: Color
var _air_enemy_base_emission: Color
var _air_enemy_base_emission_energy: float

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_hitboxes()
	# ModelSlot.slot_material() resolves BOTH ways a material can reach a
	# surface -- the scene author's surface override AND the mesh-bound one
	# an importer writes. That distinction is not academic: it used to
	# return only the override, so the two ramps below silently became
	# no-ops the moment a .glb replaced either placeholder, and nothing
	# failed. See that function's header for the measurement, and
	# scripts/dev/AlarmRampAudit.gd for the probe that now gates it.
	#
	# TWO LIMITS OF THIS CUE ON AN IMPORTED ASSET, worth knowing before
	# blaming the ramp for looking weaker than it does on the placeholders:
	#
	#   EMISSION IS INERT ON AN UNLIT MATERIAL. Both appliers move albedo
	#   AND emission; the placeholders here are lit with emission_enabled,
	#   so both halves land. Every imported asset in this project is unlit
	#   by house rule (docs/MESHY_SPEC.md §8/§9), and an unshaded material
	#   ignores emission entirely -- the same fact that pushed the
	#   pursuer's closing cue onto its own lit eye nodes (Pursuer.gd). So
	#   on a .glb the telegraph is carried by the ALBEDO alone. That is
	#   still a real cue, and the whole reason the albedo ramp is asserted
	#   rather than the emission one.
	#
	#   THE CAST IS PART OF THE CONTRACT. Godot's glTF importer produces
	#   StandardMaterial3D -- measured on a shipped asset, not assumed -- so
	#   this holds today. An asset that somehow imported as a different
	#   BaseMaterial3D subclass would fail this cast and land back on the
	#   exact silent null this fix removed. It would not go unnoticed now:
	#   AlarmRampAudit reads what the RENDERER uses, so it would go red.
	var shared_material := _enemy_mesh.slot_material() as StandardMaterial3D
	if shared_material:
		_enemy_material = shared_material.duplicate()
		_enemy_mesh.apply_material(_enemy_material)
		_enemy_base_albedo = _enemy_material.albedo_color
		_enemy_base_emission = _enemy_material.emission
		_enemy_base_emission_energy = _enemy_material.emission_energy_multiplier

	var shared_air_material := _air_enemy_mesh.slot_material() as StandardMaterial3D
	if shared_air_material:
		_air_enemy_material = shared_air_material.duplicate()
		_air_enemy_mesh.apply_material(_air_enemy_material)
		_air_enemy_base_albedo = _air_enemy_material.albedo_color
		_air_enemy_base_emission = _air_enemy_material.emission
		_air_enemy_base_emission_energy = _air_enemy_material.emission_energy_multiplier

	# AirEnemyMesh/Shape's local Y starts HERE, from TrackSegment.GLAND_Y,
	# instead of being a second baked position in Obstacle.tscn -- this is
	# the "same constant/derivation as the Gland" requirement: a runtime
	# read of the one real source (Keepy.JUMP_PEAK_HEIGHT +
	# Keepy.CAPSULE_HALF_HEIGHT, see TrackSegment.gd), not a copied
	# literal that could silently drift from it if Keepy's jump physics
	# ever changes. Obstacle root itself always stays at y=0 (see
	# TrackSegment.OBSTACLE_Y) -- only this child's local offset encodes
	# the height, same pattern DodgeMesh/JumpMesh/EnemyMesh already use.
	# _process_air_enemy takes over animating it once a run is PLAYING.
	_air_enemy_mesh.position.y = TrackSegment.GLAND_Y
	_air_enemy_shape.position.y = TrackSegment.GLAND_Y

	# ONE fixed height for JumpMarkerMesh, set once here rather than per
	# configure()/per-type: JUMP, ENEMY (settled) and a LANDED AIR_ENEMY
	# all share the exact same JUMPABLE_OBSTACLE_TOP_HEIGHT contract (see
	# the class doc), so the marker never needs to move vertically --
	# only its VISIBILITY changes, per type in configure() and, for
	# AIR_ENEMY specifically, live in _process_air_enemy() as it lands.
	_jump_marker_mesh.position.y = Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT + JUMP_MARKER_Y_OFFSET
	_jump_marker_mesh.scale = Vector3.ONE

	# Authored trail-bar positions, read once so the slide animation can
	# offset from them instead of assuming a layout -- see
	# _charger_trail_base_z.
	for bar in _charger_trail.get_children():
		_charger_trail_base_z.append((bar as Node3D).position.z)

## Writes every hazard hitbox from Hitboxes.gd onto the real shapes.
##
## The values are byte-identical to the ones Obstacle.tscn already carried,
## so nothing about how this game plays changes today. What changes is that
## the numbers now live somewhere a mesh swap cannot reach -- see
## Hitboxes.gd's header for why the six fairness contracts written against
## these dimensions (Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT's clearance window,
## RISK_MIN_SURVIVABLE_LATERAL_M's "widest hitbox is 1.2m", DODGE standing
## above JUMP_PEAK_HEIGHT) needed that guarantee before the graphics phase
## starts replacing every mesh in this scene.
##
## AIR_ENEMY's vertical offset is NOT set here: it is TrackSegment.GLAND_Y,
## a derived value, applied a few lines below and re-applied on every
## configure() as the hazard descends and lands.
##
## Runs once per pooled instance, from _ready(). The shapes are shared
## sub-resources across the pool, so several instances write the same
## constants over each other -- idempotent by construction, since every one
## of them is writing the same number from the same place.
func _apply_hitboxes() -> void:
	_apply_box(_dodge_shape, Hitboxes.DODGE_SIZE, Hitboxes.DODGE_Y)
	_apply_box(_jump_shape, Hitboxes.JUMP_SIZE, Hitboxes.JUMP_Y)
	_apply_box(_stomper_shape, Hitboxes.STOMPER_SIZE, Hitboxes.STOMPER_Y)
	_apply_box(_charger_shape, Hitboxes.CHARGER_SIZE, Hitboxes.CHARGER_Y)
	# Y deliberately left alone: _ready() sets it from TrackSegment.GLAND_Y
	# immediately after this call, and _process_air_enemy animates it.
	var air_box := _air_enemy_shape.shape as BoxShape3D
	if air_box:
		air_box.size = Hitboxes.AIR_ENEMY_SIZE
	var enemy_capsule := _enemy_shape.shape as CapsuleShape3D
	if enemy_capsule:
		enemy_capsule.radius = Hitboxes.ENEMY_RADIUS
		enemy_capsule.height = Hitboxes.ENEMY_HEIGHT
	_enemy_shape.position.y = Hitboxes.ENEMY_Y

func _apply_box(collision_shape: CollisionShape3D, size: Vector3, offset_y: float) -> void:
	var box := collision_shape.shape as BoxShape3D
	if box:
		box.size = size
	collision_shape.position.y = offset_y

## Switches which variant's mesh/collision shape is active. Called by
## TrackSegment.populate() every time this pooled obstacle is (re)spawned.
## lane_x/alt_lane_x are only meaningful for Type.ENEMY: lane_x is the
## PROVISIONAL spawn-time lane -- where the sway starts, and the row's
## noisette/gland exclusion (TrackSegment.populate) is still keyed off
## this value, since the real final lane cannot be known until the late
## lock resolves -- and alt_lane_x is the adjacent lane it sways from/to
## before locking. Both are ignored for the other types.
func configure(type: Type, lane_x: float = 0.0, alt_lane_x: float = 0.0) -> void:
	obstacle_type = type
	# Cleared FIRST, before any per-type branch below can set it: a pooled
	# instance must never inherit the own speed of whatever it was in a
	# previous life (see own_speed_factor's own doc). Every variant that
	# exists today leaves it at 0.0.
	own_speed_factor = 0.0
	var is_dodge := type == Type.DODGE
	var is_jump := type == Type.JUMP
	var is_enemy := type == Type.ENEMY
	var is_air_enemy := type == Type.AIR_ENEMY
	var is_charger := type == Type.CHARGER
	var is_stomper := type == Type.STOMPER
	_dodge_mesh.visible = is_dodge
	_dodge_shape.disabled = not is_dodge
	_jump_mesh.visible = is_jump
	_jump_shape.disabled = not is_jump
	_enemy_mesh.visible = is_enemy
	_enemy_shape.disabled = not is_enemy
	_air_enemy_mesh.visible = is_air_enemy
	_air_enemy_shape.disabled = not is_air_enemy
	_charger_mesh.visible = is_charger
	_charger_shape.disabled = not is_charger
	_charger_trail.visible = is_charger
	_stomper_mesh.visible = is_stomper
	_stomper_shape.disabled = not is_stomper

	# The ONE place an own speed is ever set -- see own_speed_factor and
	# CHARGER_SPEED_FACTOR. Everything downstream (this instance's
	# time_to_contact_s, TrackManager's spacing, every dev probe) reads it
	# from here rather than special-casing the type again.
	if is_charger:
		own_speed_factor = CHARGER_SPEED_FACTOR
	_charger_trail_phase = 0.0
	_reset_charger_trail()

	_enemy_settling = is_enemy
	_enemy_phase = 0.0
	_enemy_lane_x = lane_x
	_enemy_alt_lane_x = alt_lane_x
	_enemy_late_lock_resolved = false
	if is_enemy:
		position.x = _enemy_lane_x
		_apply_enemy_alarm(0.0) # reset tint -- this instance may be a pooled reuse

	air_enemy_landed = false
	_air_enemy_lane_decided = false
	if is_air_enemy:
		_air_enemy_mesh.position.y = TrackSegment.GLAND_Y
		_air_enemy_shape.position.y = TrackSegment.GLAND_Y
		_apply_air_enemy_tint(0.0) # reset tint -- this instance may be a pooled reuse

	_stomper_lane_x = lane_x
	_stomper_tracking = false
	_stomper_pulse_phase = 0.0
	_stomper_mesh.scale = Vector3.ONE
	if is_stomper:
		position.x = _stomper_lane_x

	# JumpMarkerMesh -- permanent "you can jump this" signal (chantier 2,
	# playtest-fixes batch), independent of the alarm-tint timeline below
	# and visible from the moment the obstacle spawns, never just once
	# danger is imminent (see the class doc for why that distinction is
	# the whole point). JUMP, ENEMY and STOMPER show it immediately and
	# keep it on for their entire lifetime (all three are ALWAYS jumpable,
	# unlike ENEMY's/STOMPER's own separate alarm/pulse ramps which are
	# proximity cues, not jumpability cues). AIR_ENEMY starts hidden -- it
	# is NOT jumpable while still airborne (Obstacle.blocks_jump) -- and is
	# turned on dynamically by _process_air_enemy() the instant it lands.
	# DODGE and CHARGER never show it (neither is ever jumpable).
	_jump_marker_mesh.visible = is_jump or is_enemy or is_stomper
	_jump_marker_mesh.scale = Vector3.ONE
	_marker_pop_t = -1.0
	_prev_pass_z = global_position.z
	_min_lateral_distance = INF

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return

	# Both run for EVERY type (DODGE/JUMP included, neither of which
	# reaches the ENEMY-only sway code below) -- a risk event can happen
	# on any type (a graze or a late dodge applies to the two UNJUMPABLE
	# ones too, which is exactly when a lane switch is the only escape
	# there is), and a pop that started on a previous frame must keep
	# animating regardless of which per-type branch this frame takes.
	_check_passage()
	_update_marker_pop(delta)

	if obstacle_type == Type.CHARGER:
		_process_charger(delta)
		return
	if obstacle_type == Type.AIR_ENEMY:
		_process_air_enemy()
		return
	if obstacle_type == Type.STOMPER:
		_process_stomper(delta)
		return
	if not _enemy_settling:
		return

	var time_to_contact := time_to_contact_s()

	if not _enemy_late_lock_resolved and time_to_contact <= ENEMY_REACTION_WINDOW_S + ENEMY_EASE_DURATION_S:
		_resolve_late_lock(time_to_contact)

	if time_to_contact <= ENEMY_REACTION_WINDOW_S:
		_enemy_settling = false
		position.x = _enemy_lane_x
		_apply_enemy_alarm(1.0) # fully alarmed the instant it commits
		return

	# Oscillation frequency ramps from calm (far away) to frantic (final
	# approach) -- see ENEMY_OSCILLATION_HZ_START/_END above.
	var oscillation_ramp_t := clampf(
		1.0 - (time_to_contact - ENEMY_REACTION_WINDOW_S) / ENEMY_OSCILLATION_RAMP_WINDOW_S,
		0.0, 1.0
	)
	var oscillation_hz := lerpf(ENEMY_OSCILLATION_HZ_START, ENEMY_OSCILLATION_HZ_END, oscillation_ramp_t)
	# Phase is INTEGRATED frame-by-frame (hz * TAU * delta accumulated
	# into _enemy_phase) rather than derived as elapsed_time * hz: with
	# hz now varying over time, elapsed*hz(t) would jump discontinuously
	# every time hz changes. Accumulating the instantaneous frequency
	# each frame is the correct way to get a smooth rising-frequency
	# "chirp" with no phase glitch.
	_enemy_phase += oscillation_hz * TAU * delta

	var wave := 0.5 + 0.5 * sin(_enemy_phase)
	var wave_x: float = lerp(_enemy_lane_x, _enemy_alt_lane_x, wave)

	if time_to_contact <= ENEMY_REACTION_WINDOW_S + ENEMY_EASE_DURATION_S:
		# Blend the full-amplitude sway toward the (possibly just-updated,
		# see _resolve_late_lock) final lane so the motion eases into
		# place instead of cutting off mid-swing right at the hard lock
		# threshold.
		var ease_t := 1.0 - (time_to_contact - ENEMY_REACTION_WINDOW_S) / ENEMY_EASE_DURATION_S
		position.x = lerp(wave_x, _enemy_lane_x, ease_t)
	else:
		position.x = wave_x

	# Alarm tint: a longer-range, purely cosmetic anticipation cue
	# (distinct from the sway/lock mechanics above) -- see
	# ENEMY_ALARM_RAMP_WINDOW_S.
	var alarm_t := clampf(
		1.0 - (time_to_contact - ENEMY_REACTION_WINDOW_S) / ENEMY_ALARM_RAMP_WINDOW_S,
		0.0, 1.0
	)
	_apply_enemy_alarm(alarm_t)

## Called once per spawn, the moment the ease-into-final-lane window
## opens (ENEMY_REACTION_WINDOW_S + ENEMY_EASE_DURATION_S before
## contact) -- late enough that it reads as "the enemy commits to
## wherever you actually are", not a value pre-drawn back at spawn time,
## several seconds and potentially several lane changes earlier.
##
## Targets Keepy's ACTUAL current lane, UNLESS that would trap the
## player: if another live hazard that forces or punishes a jump (a JUMP
## obstacle, or an AIR_ENEMY still airborne -- see
## TrackManager.lane_has_conflicting_jump_hazard) is due on that same
## lane close enough in time to this enemy's own contact, locking there
## would leave jumping lethal AND the enemy itself blocking a lane
## switch's destination is irrelevant here (a switch always targets a
## DIFFERENT lane) -- the actual risk is "jump is the only escape left
## and jump is booby-trapped", so redirect to a lane where it is not.
## This is the anti-frustration guarantee for ground ENEMY specifically;
## see TrackManager._populate_segment for the spawn-time side of the same
## contract (JUMP/AIR_ENEMY never scheduled too close to EACH OTHER),
## and TrackManager.lane_has_conflicting_jump_hazard's own doc for why a
## THIRD, runtime-only check is needed here: this decision is the only
## one of the three obstacle-lane choices that cannot be made at spawn
## time at all, since it depends on where the player actually is.
func _resolve_late_lock(time_to_contact: float) -> void:
	_enemy_late_lock_resolved = true
	var player_lane := _current_player_lane()
	if player_lane == -1:
		return # no player in the tree (headless probe, etc.) -- keep the spawn-drawn lane
	var target_lane := player_lane
	var track_manager := _track_manager()
	if track_manager and track_manager.lane_has_conflicting_jump_hazard(target_lane, time_to_contact):
		target_lane = _safe_redirect_lane(target_lane, time_to_contact, track_manager)
	_enemy_lane_x = TrackSegment.LANE_X[target_lane]

## Picks a lane other than `unsafe_lane` that is not ITSELF flagged by
## the same conflict check. Falls back to simply the next lane over if
## every lane conflicts (see the doc on TrackManager's own check for how
## vanishingly rare that is given the spacing rules already in place) --
## still strictly better than repeating the exact lane the caller was
## specifically told to avoid.
## `exclude`: forwarded to lane_has_conflicting_jump_hazard unchanged --
## see that function's own doc. Ground ENEMY's call site never needed
## this (an ENEMY can never flag itself); AIR_ENEMY's landing-lane
## resolver (chantier 3) passes itself, for the same reason its own
## initial check does.
##
## A lane closed by a temporary track shrink (see GameState's TRACK
## SHRINK section) is never a legal destination, including for the
## last-resort fallback -- which is why that fallback is no longer a bare
## `(unsafe_lane + 1) % 3`: the modulo can land squarely on the closed
## lane, and redirecting a hazard behind the barrier would put it where
## the player provably is not, quietly cancelling the mechanic these two
## hazards are supposed to keep working through. The callers never pass
## a closed lane as `unsafe_lane` in the first place (both target the
## player's own lane, and the player can never be on a closed one), so
## there is always at least one legal answer left.
func _safe_redirect_lane(unsafe_lane: int, time_to_contact: float, track_manager: Node, exclude: Node3D = null) -> int:
	var fallback := -1
	for lane in 3:
		if lane == unsafe_lane or GameState.lane_blocked(lane):
			continue
		if fallback == -1:
			fallback = lane
		if not track_manager.lane_has_conflicting_jump_hazard(lane, time_to_contact, exclude):
			return lane
	# Every open lane conflicts (see the doc on TrackManager's own check
	# for how vanishingly rare that is) -- take any open one that is not
	# the lane we were told to avoid. Only if there is somehow none does
	# this fall back to the caller's own lane, which is still strictly
	# better than committing to a lane behind a barrier.
	return fallback if fallback != -1 else unsafe_lane

func _current_player_lane() -> int:
	var player := _current_player_ref()
	if player == null:
		return -1
	return player.lane_index

## Lazily-cached lookup of the single Keepy instance, shared by
## _current_player_lane() (lane only) and _check_passage() (which also
## needs is_on_floor()) so there is exactly one place that resolves the
## "player" group into a node.
func _current_player_ref() -> Keepy:
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player")
	return _player_ref

func _track_manager() -> Node:
	if _track_manager_ref == null:
		_track_manager_ref = get_tree().get_first_node_in_group("track_manager")
	return _track_manager_ref

## This instance's OWN forward speed, expressed as a MULTIPLE of the
## world speed (0.0 = "carried by the world and nothing else", which is
## every variant shipped so far). See the CLOSING SPEED section header
## for why this exists and what it is allowed to affect.
##
## Reset to 0.0 on every configure() -- a pooled instance must never
## inherit a previous life's own speed.
var own_speed_factor: float = 0.0

## The speed at which THIS obstacle actually closes on the player: the
## world's own speed plus whatever this instance adds on top of it.
##
## The single answer to "how fast is this thing arriving", and the ONLY
## value any distance <-> reaction-time conversion about this obstacle
## may use. GameState.current_speed alone answers a DIFFERENT question --
## how fast the world scrolls -- and the two stopped being the same
## number the moment an obstacle was allowed its own speed. For every
## variant with own_speed_factor == 0.0 this returns exactly
## GameState.current_speed (a multiplication by 1.0 is exact), so
## nothing about the pre-existing hazards changes.
## Built on GameState.scroll_speed(), not current_speed: during a stumble the
## world genuinely arrives more slowly (see GameState's STRIKES block), so a
## time-to-contact computed from the run's nominal speed would promise the
## player less time than they actually have and every late commit keyed off
## it -- ENEMY's lock, STOMPER's, AIR_ENEMY's landing -- would fire early
## against the real approach. At player_speed_factor == 1.0 scroll_speed()
## returns current_speed exactly, so nothing outside a stumble moves.
func closing_speed() -> float:
	return GameState.scroll_speed() * (1.0 + own_speed_factor)

## Public: this instance's own time-before-contact, in seconds. Exposed
## so TrackManager's cross-obstacle safety scan can compare two
## independent Obstacle instances' schedules without duplicating this
## division (see the class doc on Keepy sitting fixed at Z=0).
##
## Divides by closing_speed(), NOT by GameState.current_speed: two
## obstacles with different own speeds are only comparable if each one's
## time-to-contact was computed against its own rate of approach. This is
## the value ENEMY's late lock, AIR_ENEMY's descent schedule,
## TrackManager.lane_has_conflicting_jump_hazard and every dev probe all
## read, so fixing it here fixes all of them at once.
func time_to_contact_s() -> float:
	return -global_position.z / closing_speed()

## The CHARGER's whole per-frame behaviour: close on the player faster
## than the world does, and take itself out of play once past.
##
## This is the ONLY place in the game where a hazard moves itself along
## Z. It moves its LOCAL z (it is a child of a TrackSegment that
## TrackManager is already advancing at GameState.current_speed), so what
## it adds here is exactly its OWN speed and the two compose into
## closing_speed() -- no double counting, and no special case needed
## anywhere in TrackManager's movement loop.
##
## Deliberately NOT run on a pooled-but-hidden instance (unlike the ENEMY
## sway and the AIR_ENEMY descent, which tolerate it): those two only
## animate an offset that populate() overwrites anyway, whereas this one
## integrates position.z, so an invisible charger left running would
## drift arbitrarily far and hand a stale global Z to
## time_to_contact_s() / _check_passage the moment it came back into
## play.
##
## Straight line, one lane, start to finish -- there is intentionally no
## player-tracking here, and none of _resolve_late_lock's machinery. The
## whole read is "which lane is it on", decided at spawn and never
## revised, so the player can commit to a switch the instant they see it
## instead of waiting to find out where it will end up.
func _process_charger(delta: float) -> void:
	if not visible:
		return
	# scroll_speed(), matching TrackManager's own movement line and
	# closing_speed() above: a charger's own speed is stated as a MULTIPLE of
	# the world's, so it has to be a multiple of the speed the world is
	# actually moving at this frame, not of the run's nominal one. Anything
	# else would have a charger accelerate relative to the track every time
	# the player stumbles.
	position.z += GameState.scroll_speed() * own_speed_factor * delta
	if global_position.z > CHARGER_DESPAWN_Z:
		# Behind the camera and past every gameplay decision it could
		# still affect -- see CHARGER_DESPAWN_Z. TrackSegment.populate()
		# resets local Z when this pooled instance is next used, so
		# nothing here has to undo the travel.
		visible = false
		set_deferred("monitoring", false) # deferred: see TrackSegment's class doc
		monitorable = false
		return
	_animate_charger_trail(delta)

## Slides the three speed-line bars backward on a seamless loop -- the
## MOTION half of the telegraph (see the TELEGRAPH section header).
##
## Each bar is offset from its OWN authored position by a shared phase
## wrapped on the bar spacing, so bar N always steps into the position
## bar N-1 just left and the loop has no visible seam. A hand-rolled
## phase driven per physics frame rather than an AnimationPlayer or a
## Tween, for the same reason every other animation in this file is (see
## _update_marker_pop): nothing is created or destroyed as a pooled
## instance is reused over and over.
func _animate_charger_trail(delta: float) -> void:
	_charger_trail_phase = fposmod(
		_charger_trail_phase + CHARGER_TRAIL_HZ * CHARGER_TRAIL_SPACING * delta,
		CHARGER_TRAIL_SPACING
	)
	var bars := _charger_trail.get_children()
	for i in bars.size():
		if i >= _charger_trail_base_z.size():
			break
		(bars[i] as Node3D).position.z = _charger_trail_base_z[i] - _charger_trail_phase

## Puts every trail bar back on its authored Z. Called from configure()
## so a pooled instance never re-enters play mid-slide, which would show
## the bars at an arbitrary offset for the frame before the first
## _animate_charger_trail tick.
func _reset_charger_trail() -> void:
	var bars := _charger_trail.get_children()
	for i in bars.size():
		if i >= _charger_trail_base_z.size():
			break
		(bars[i] as Node3D).position.z = _charger_trail_base_z[i]

## Animates the AIR_ENEMY variant's height across its whole approach --
## see the Type.AIR_ENEMY doc for the schedule this implements. Runs
## every physics frame this instance is configured as AIR_ENEMY,
## regardless of visibility (matches the pre-existing tolerance for the
## ENEMY sway logic doing the same on a pooled-but-inactive instance --
## harmless, and TrackManager's safety scan already filters on
## `visible` before treating an obstacle as live).
func _process_air_enemy() -> void:
	var time_to_contact := time_to_contact_s()

	# Landing lane decision -- see the class doc's MULTI-LANE LANDING
	# section. Fires at the SAME instant the descent below starts
	# (t is still 0.0 this exact frame), so the lateral lerp source
	# (_air_enemy_flight_lane_x, captured from position.x INSIDE the
	# resolver) is still the untouched spawn lane -- no visual pop.
	if not _air_enemy_lane_decided and time_to_contact <= AIR_ENEMY_DESCENT_LEAD_S:
		_resolve_air_enemy_landing_lane(time_to_contact)

	var t: float
	if time_to_contact >= AIR_ENEMY_DESCENT_LEAD_S:
		t = 0.0
	elif time_to_contact <= ENEMY_REACTION_WINDOW_S:
		t = 1.0
	else:
		t = 1.0 - (time_to_contact - ENEMY_REACTION_WINDOW_S) / (AIR_ENEMY_DESCENT_LEAD_S - ENEMY_REACTION_WINDOW_S)
	var center_y := lerpf(TrackSegment.GLAND_Y, AIR_ENEMY_LANDED_CENTER_Y, t)
	_air_enemy_mesh.position.y = center_y
	_air_enemy_shape.position.y = center_y
	# X convergence uses the EXACT SAME t as the Y descent above -- one
	# shared progress value, so the lateral drift and the vertical
	# descent visibly finish together, reading as ONE telegraphed
	# movement ("it's coming down AND heading for your lane") rather than
	# two cues a player has to track independently. Guarded on
	# _air_enemy_lane_decided so position.x is left completely untouched
	# (still whatever TrackSegment.populate() set it to) for every frame
	# before the decision fires -- t is 0.0 there anyway (see above), so
	# this guard is a no-op in practice, but it keeps the source of
	# truth for "has this AIR_ENEMY started drifting yet" in one place
	# rather than relying on t's own value coincidentally being 0.0.
	if _air_enemy_lane_decided:
		position.x = lerpf(_air_enemy_flight_lane_x, _air_enemy_landing_lane_x, t)
	air_enemy_landed = t >= 1.0
	_apply_air_enemy_tint(t)
	# JumpMarkerMesh follows `air_enemy_landed` every frame (not just on
	# the transition) -- cheap idempotent assignment, and it means a
	# pooled instance re-entering this function after a fresh configure()
	# (which always starts it hidden, see configure()) can never get
	# stuck showing a marker for a still-airborne AIR_ENEMY.
	_jump_marker_mesh.visible = air_enemy_landed

## Picks AIR_ENEMY's landing lane -- see the class doc's MULTI-LANE
## LANDING section for the full contract. Mirrors
## Obstacle._resolve_late_lock (ground ENEMY) almost exactly: target
## Keepy's ACTUAL current lane, redirected via the SAME
## TrackManager.lane_has_conflicting_jump_hazard check + _safe_redirect_lane
## fallback if that lane is unsafe (a JUMP or another still-airborne
## AIR_ENEMY due on the same lane close enough in time -- see that
## function's own doc, reused verbatim, not reimplemented). Falls back to
## landing straight down on its own flight lane if no player is in the
## tree (a headless probe with no Keepy, matching _resolve_late_lock's
## own "no player -- keep the spawn-drawn lane" fallback).
func _resolve_air_enemy_landing_lane(time_to_contact: float) -> void:
	_air_enemy_lane_decided = true
	_air_enemy_flight_lane_x = position.x
	var flight_lane := _lane_index_for_x(_air_enemy_flight_lane_x)
	var player_lane := _current_player_lane()
	var target_lane := player_lane if player_lane != -1 else flight_lane
	var track_manager := _track_manager()
	if track_manager and track_manager.lane_has_conflicting_jump_hazard(target_lane, time_to_contact, self):
		target_lane = _safe_redirect_lane(target_lane, time_to_contact, track_manager, self)
	_air_enemy_landing_lane_x = TrackSegment.LANE_X[target_lane]

## Lane index (0/1/2) whose TrackSegment.LANE_X value is closest to `x`.
## Shared by _resolve_air_enemy_landing_lane's no-player fallback; not
## needed by ground ENEMY's own late lock, which always has a lane index
## on hand already (Keepy's own lane_index, or the spawn-drawn
## _enemy_lane_x compared implicitly through TrackSegment.LANE_X at
## configure() time).
func _lane_index_for_x(x: float) -> int:
	var best_index := 0
	var best_dist := INF
	for i in TrackSegment.LANE_X.size():
		var d := absf(x - TrackSegment.LANE_X[i])
		if d < best_dist:
			best_dist = d
			best_index = i
	return best_index

## Lerps the (per-instance, see _ready) AirEnemyMesh material from its
## base colors toward ENEMY_ALARM_ALBEDO/_EMISSION/_EMISSION_ENERGY as it
## descends -- reuses the ground ENEMY's own alarm palette (t=0 resting,
## t=1 fully landed/alarmed) so "grounded and dangerous" reads as the
## same visual language across both hazard types, rather than the player
## having to learn a second color code.
func _apply_air_enemy_tint(t: float) -> void:
	if not _air_enemy_material:
		return
	_air_enemy_material.albedo_color = _air_enemy_base_albedo.lerp(ENEMY_ALARM_ALBEDO, t)
	_air_enemy_material.emission = _air_enemy_base_emission.lerp(ENEMY_ALARM_EMISSION, t)
	_air_enemy_material.emission_energy_multiplier = lerpf(_air_enemy_base_emission_energy, ENEMY_ALARM_EMISSION_ENERGY, t)

## Lerps the (per-instance, see _ready) EnemyMesh material from its base
## colors toward ENEMY_ALARM_ALBEDO/_EMISSION/_EMISSION_ENERGY. t=0 is the
## resting color (Obstacle.tscn's default purple), t=1 is fully alarmed.
func _apply_enemy_alarm(t: float) -> void:
	if not _enemy_material:
		return
	_enemy_material.albedo_color = _enemy_base_albedo.lerp(ENEMY_ALARM_ALBEDO, t)
	_enemy_material.emission = _enemy_base_emission.lerp(ENEMY_ALARM_EMISSION, t)
	_enemy_material.emission_energy_multiplier = lerpf(_enemy_base_emission_energy, ENEMY_ALARM_EMISSION_ENERGY, t)

## The STOMPER's whole per-frame behaviour -- see the Type.STOMPER doc and
## the TELEGRAPH-STOMPER section header for the full contract. Two
## independent jobs:
##   1. COMMIT, once, at the exact same time-before-contact ENEMY's own
##      hard lock uses (ENEMY_REACTION_WINDOW_S) -- then, EVERY frame
##      afterward, overwrite position.x with the player's own position.x
##      verbatim. No lerp, no ease, no "closest lane": a real-valued exact
##      copy, so the lateral gap between this hazard and the player is
##      identically 0.0 for the remainder of its life, not a small number
##      that happens to be hard to beat. This one line IS the entire
##      "lane switch cannot escape a STOMPER" guarantee (blocks_lane_switch
##      below) -- there is no separate check anywhere that also has to be
##      correct for the guarantee to hold, because there is nothing left
##      for a switch to accomplish once this is true: wherever Keepy's
##      lane lerp takes position.x, this line has already put the STOMPER
##      there too, on the very same frame.
##      Before commit it simply sits at its provisional spawn lane
##      (_stomper_lane_x, set in configure()) -- unlike ENEMY there is no
##      sway to animate there, only the pulse below.
##      If no player is in the tree (a headless probe/calibration scene
##      with no Keepy, e.g. DarkPaletteAudit's private scene) tracking
##      never has anything to mirror and this hazard simply stays at its
##      provisional lane -- same "no player -- keep the spawn-drawn lane"
##      fallback ENEMY's own late lock uses.
##   2. PULSE -- a breathing scale animation, ramping from calm to frantic
##      as contact nears (see STOMPER_PULSE_HZ_START/_END), MOTION only,
##      colour never changes (see TELEGRAPH-STOMPER above for why).
func _process_stomper(delta: float) -> void:
	var time_to_contact := time_to_contact_s()

	if not _stomper_tracking and time_to_contact <= ENEMY_REACTION_WINDOW_S:
		_stomper_tracking = true

	if _stomper_tracking:
		var player := _current_player_ref()
		if player != null:
			position.x = player.position.x

	var ramp_t := clampf(1.0 - (time_to_contact - ENEMY_REACTION_WINDOW_S) / STOMPER_PULSE_RAMP_WINDOW_S, 0.0, 1.0)
	var pulse_hz := lerpf(STOMPER_PULSE_HZ_START, STOMPER_PULSE_HZ_END, ramp_t)
	_stomper_pulse_phase += pulse_hz * TAU * delta
	var scale_mult := 1.0 + STOMPER_PULSE_SCALE_AMPLITUDE * (0.5 + 0.5 * sin(_stomper_pulse_phase))
	_stomper_mesh.scale = Vector3.ONE * scale_mult

## Whether jumping on this obstacle's lane is unsafe -- i.e. whether a
## Gland must never share its lane/row (see TrackSegment.populate).
## JUMP is safe (in fact REQUIRED) to jump into, and ENEMY now is too
## (see the Type.ENEMY doc -- its hitbox is jumpable exactly like JUMP's,
## so a Gland sharing its lane/row is the same "jump clears the hazard
## and grabs the bonus" combo already supported for JUMP). STOMPER is
## exactly as safe as JUMP/ENEMY for the same reason (same jumpable
## hitbox contract, see blocks_jump below) -- a Gland at its PROVISIONAL
## lane is cleared by the same jump that clears the hazard, regardless of
## where the hazard's tracking later takes it. DODGE is
## unsafe because it requires a full LANE SWITCH regardless of jump
## state; AIR_ENEMY is unsafe for the OPPOSITE reason while still
## airborne (jumping is exactly what makes contact, see the Type.AIR_ENEMY
## doc) -- a Gland at the SAME row/Z as an AIR_ENEMY would sit at exactly
## its airborne hitbox height (GLAND_Y), so reaching it is reaching the
## hazard.
## CHARGER is unsafe for the same reason as DODGE and by the same means:
## its hitbox is byte-identical to DodgeShape's (BoxShape3D_Charger in
## Obstacle.tscn, 1.2 x 2.0 x 1.0 at y=1.0), i.e. taller than
## Keepy.JUMP_PEAK_HEIGHT, so it cannot be jumped by construction rather
## than by timing. Reusing DODGE's exact hitbox rather than authoring a
## new one is deliberate: the charger's fairness then rests on an
## already-verified clearance contract, and only its APPROACH SPEED is
## new.
static func blocks_jump(type: Type) -> bool:
	return type == Type.DODGE or type == Type.AIR_ENEMY or type == Type.CHARGER

## Whether a lane switch can EVER escape this obstacle -- the STOMPER's own
## contract, and the deliberate INVERSE of blocks_jump above (see the
## Type.STOMPER doc: CHARGER is blocks_jump==true with switch as the only
## escape; STOMPER is the mirror image). True for STOMPER alone, and only
## from the instant it commits (see _process_stomper): from then on its
## position.x is a live, exact copy of the player's own, so no switch of
## any speed ever opens a lateral gap. False for every other type, even
## the ones that force a jump in PRACTICE (JUMP, a settled/locked ENEMY,
## a landed AIR_ENEMY) -- those still have a genuine switch escape
## available (the player is simply not standing on it), which is exactly
## what makes STOMPER different in kind, not just in degree.
static func blocks_lane_switch(type: Type) -> bool:
	return type == Type.STOMPER

## Whether touching this hazard ENDS THE RUN, as opposed to costing the
## player half a strike (see GameState.register_strike and its STRIKES block
## for the other half). The single source of truth for the death model's
## split.
##
## THE CHARGER, AND NOTHING ELSE.
##
## The line used to be "does it act on you", which put four of the six types
## on the fatal side. That distinction is real and reads correctly, but it
## left the pursuer -- the thing this whole death model exists to make the
## killer -- having to win a race against four instant-death hazards before
## it ever got a turn. It usually lost: StrikeAudit measured the mid-skill
## profile dying 32 times to a fatal hazard against 12 captures. See
## GameState's STRIKES block for that argument in full.
##
##   FATAL     -- CHARGER alone. It is the only type with a forward speed of
##                its OWN (see CHARGER_SPEED_FACTOR): it does not wait to be
##                reached, it CLOSES, arriving at over twice the speed of
##                the world, and a lane switch is its only escape by
##                CONSTRUCTION rather than by timing (its hitbox is
##                byte-identical to DODGE's, taller than JUMP_PEAK_HEIGHT).
##                Something that hunts you down and catches you anyway has
##                earned the run outright.
##   NON-FATAL -- the other five, each costing GameState.CONTACT_COST_HALF.
##                DODGE and JUMP sit there and are misread; ENEMY,
##                AIR_ENEMY and STOMPER track, commit and land on you, and
##                are now stumbles too.
##
## WHAT DOWNGRADING THE THREE ACTIVE ONES DOES *NOT* DO, since the previous
## version of this doc argued it would: it does not delete the escapes they
## exist to force. A STOMPER is still escapable ONLY by a jump
## (blocks_lane_switch above is unchanged), an AIR_ENEMY still cannot be
## jumped while airborne, an ENEMY still locks onto the lane you are
## standing in. What changed is the PRICE of failing those escapes, not
## whether they exist -- and the price is still steep, because every contact
## also yanks the pursuer's lead down to STRIKE_PURSUER_LEAD_CAP_S.
##
## Static, and taking the type rather than reading obstacle_type, so a caller
## that only has a type (a dev probe classifying spawns, TrackManager) can ask
## without an instance -- the same shape as blocks_jump/blocks_lane_switch
## directly above, and the reason all three sit together.
##
## Verified directly rather than only through bot outcomes:
## scripts/dev/DeathModelAudit.gd enumerates Type.values() against this
## function, so a SEVENTH type added later cannot arrive unclassified.
static func is_fatal(type: Type) -> bool:
	return type == Type.CHARGER

## THE one per-frame hook that watches this obstacle go past the player,
## and the ONLY place a risk event can originate from a hazard passage.
##
## Two jobs, both hanging off state this function already had to keep:
##   1. SAMPLE the closest lateral approach while the obstacle is within
##      RISK_PROXIMITY_Z of the player (see _min_lateral_distance for why
##      the minimum over the passage, and not the value at the crossing
##      instant, is the honest measure of a graze).
##   2. DETECT the Z=0 crossing -- the exact instant collision is tested
##      (see time_to_contact_s's own doc: Keepy sits fixed at Z=0) and
##      therefore the one moment "what just happened here" can be judged --
##      and hand the passage to _resolve_risk_event.
##
## GREW OUT OF _check_jump_dodge (playtest-fixes batch) rather than being
## added alongside it: the jump-dodge was already detected at exactly this
## crossing, with exactly this pooled-instance bookkeeping, so a second
## detection path watching the same instant would have been two things to
## keep in sync for no gain. The jump-dodge's own contract is unchanged --
## it is now the first branch of _resolve_risk_event, still emits
## `jump_dodged`, still awards GameState.JUMP_DODGE_BONUS_VALUE, still pops
## the marker, and is still verified end to end by
## scripts/dev/JumpDodgeRewardAudit.gd.
##
## Collision itself is tested by Godot's own Area3D body_entered
## (_on_body_entered) -- nothing here duplicates that test, it only asks
## "given no collision ended the run, was this passage a risk taken".
##
## `_prev_pass_z` tracks THIS instance's own global Z frame to frame (reset
## in configure(), see that var's own doc) so the crossing is detected
## exactly once per spawn, not once per frame it happens to sit past Z=0
## (which would otherwise fire every remaining frame the pooled,
## still-visible-for-one-more-tick instance sits behind the player).
func _check_passage() -> void:
	if not visible:
		return
	var z := global_position.z
	var player := _current_player_ref()
	if player != null and absf(z) <= RISK_PROXIMITY_Z:
		# position.x, not LANE_X[lane_index]: the REAL interpolated X. The
		# lane index snaps the instant the input lands, seconds before the
		# body finishes sliding, and it is precisely that slide this whole
		# measurement is about.
		_min_lateral_distance = minf(_min_lateral_distance, absf(player.position.x - position.x))
	var crossed := _prev_pass_z < 0.0 and z >= 0.0
	_prev_pass_z = z
	if not crossed:
		return
	var closest_lateral := _min_lateral_distance
	# Re-armed HERE and not only in configure(): a charger despawns and a
	# segment recycles well after the crossing, so leaving the sample armed
	# would let a stale minimum survive into the next judgement.
	_min_lateral_distance = INF
	if player == null:
		return
	_resolve_risk_event(player, closest_lateral)

## Classifies a completed passage as AT MOST ONE risk event -- see
## GameState.RiskEvent for what the kinds mean.
##
## Ranked, and exclusive by construction: a passage credits the FIRST kind
## it qualifies for and returns. Crediting one passage twice would let a
## single well-timed lane change count as two combo steps, which is exactly
## how a reward system stops meaning anything.
##
## THE ORDER IS "TIGHTEST CLAIM WINS", and it is load-bearing rather than
## cosmetic:
##   JUMP_DODGE first because it is the only VERTICAL escape, so its
##     lateral distance is ~0 by definition (you clear a hazard by being
##     directly above it) and every lateral test below would either reject
##     it or, worse, read it as a collision.
##   NEAR_MISS before LATE_DODGE because the two overlap almost completely
##     -- getting off a lane late is also what leaves you close to it -- and
##     the graze is the STRICTER of the two: it requires still being inside
##     a narrow lateral band as the hazard goes past, where a late dodge
##     only requires having started the escape inside a time window (and so
##     is satisfied by escapes that finish a comfortable ~1.98m clear).
##     Ranked the other way
##     round, LATE_DODGE would swallow essentially every tight escape and
##     NEAR_MISS would be dead code that never fires in a real run (checked,
##     not assumed: that ordering was written first and the probe run that
##     measures per-kind rates is what exposed it).
## What each one therefore means to the player is clean: NEAR_MISS is "you
## were still in the danger zone when it passed", LATE_DODGE is "you got
## clear in time, but only just".
func _resolve_risk_event(player: Keepy, closest_lateral: float) -> void:
	if _is_jump_dodge(player):
		jump_dodged.emit()
		_trigger_jump_dodge_feedback()
		GameState.register_risk_event(GameState.RiskEvent.JUMP_DODGE)
		return
	# Both LATERAL kinds share one floor: a passage that got closer than a
	# body's width is a hit, not a risk taken -- see
	# RISK_MIN_SURVIVABLE_LATERAL_M for why this is checked explicitly
	# rather than left to "the player would be dead anyway".
	if closest_lateral < RISK_MIN_SURVIVABLE_LATERAL_M:
		return
	if closest_lateral <= NEAR_MISS_MAX_LATERAL_M:
		GameState.register_risk_event(GameState.RiskEvent.NEAR_MISS)
		return
	if _is_late_dodge(player):
		GameState.register_risk_event(GameState.RiskEvent.LATE_DODGE)

## The pre-existing jump-dodge test, lifted verbatim out of the old
## _check_jump_dodge (same four conditions, same order, same reasoning) so
## the behaviour this batch inherited stays byte-for-byte the thing that
## was already validated in playtest and is still covered by
## JumpDodgeRewardAudit.gd.
func _is_jump_dodge(player: Keepy) -> bool:
	if blocks_jump(obstacle_type):
		return false
	if obstacle_type == Type.AIR_ENEMY and not air_enemy_landed:
		return false # unreachable given blocks_jump already excludes this, kept explicit for clarity
	if not is_equal_approx(position.x, TrackSegment.LANE_X[player.lane_index]):
		return false # different lane -- this obstacle was never the one the player had to deal with
	if player.is_on_floor():
		return false # grounded at the crossing instant: either it just walked into a collision (handled elsewhere) or this type never required a jump to begin with
	return true

## Whether the player was STANDING ON this obstacle's lane and got off it
## inside LATE_DODGE_WINDOW_S of contact -- the escape a CHARGER forces,
## since a charger cannot be jumped.
##
## Reads Keepy's own previous_lane_index/last_lane_change_s (see their doc
## for why the question cannot be answered from the current lane): by the
## time a hazard reaches Z=0 the player has long since settled on the
## destination lane, so nothing about where they ARE still records when, or
## from where, they left.
##
## Uses _lane_index_for_x rather than comparing X floats: a settled ENEMY
## or a landed AIR_ENEMY arrives at an exact LANE_X, but nearest-lane is
## robust to any future variant that does not, and the helper already
## exists in this file.
func _is_late_dodge(player: Keepy) -> bool:
	if player.previous_lane_index == player.lane_index:
		return false # no lane change on record this run
	if _lane_index_for_x(position.x) != player.previous_lane_index:
		return false # they left SOME lane, but not the one this hazard is on
	return GameState.run_time_s - player.last_lane_change_s <= LATE_DODGE_WINDOW_S

## Score bonus + the marker's visual "pop" -- see
## GameState.JUMP_DODGE_BONUS_VALUE and MARKER_POP_DURATION_S/
## _PEAK_SCALE for the reasoning behind both numbers. Kept as one
## function (rather than splitting score from visuals) since they are
## always triggered by the exact same event and nothing else in this
## file needs them independently.
func _trigger_jump_dodge_feedback() -> void:
	GameState.add_jump_dodge_bonus()
	_marker_pop_t = 0.0

## Animates the marker's scale pulse started by _trigger_jump_dodge_feedback
## -- a simple hand-rolled ease (this file's own established convention,
## see the ENEMY oscillation/alarm-ramp code above: no Tween node, a
## manual t-based interpolation driven every physics frame) rather than a
## Tween, so no node is ever created/destroyed by triggering feedback
## repeatedly across a pooled instance's whole lifetime. Scales UP to
## MARKER_POP_PEAK_SCALE at the pop's midpoint then eases back to 1.0,
## using the SAME triangular envelope shape (linear rise, linear fall)
## the rest of this file favours for its readability rather than a
## smoother but harder-to-reason-about curve.
func _update_marker_pop(delta: float) -> void:
	if _marker_pop_t < 0.0:
		return
	_marker_pop_t += delta
	if _marker_pop_t >= MARKER_POP_DURATION_S:
		_marker_pop_t = -1.0
		_jump_marker_mesh.scale = Vector3.ONE
		return
	var half := MARKER_POP_DURATION_S * 0.5
	var t := _marker_pop_t / half if _marker_pop_t < half else 2.0 - _marker_pop_t / half
	var scale := lerpf(1.0, MARKER_POP_PEAK_SCALE, clampf(t, 0.0, 1.0))
	_jump_marker_mesh.scale = Vector3.ONE * scale

## The ONE place contact is turned into a consequence, and the one place the
## death model's split is applied -- see is_fatal above.
##
## Area3D fires body_entered ONCE per entry, so a single hazard can only ever
## report one contact no matter how many frames the player spends inside it.
## The invulnerability window in GameState.register_strike is therefore not
## guarding against this instance firing repeatedly -- it guards against two
## DIFFERENT hazards, close together, being counted twice for one beat.
##
## Note the ORDER: is_fatal is asked FIRST, so a CHARGER never reaches
## register_strike at all. That is why "fatal" and "costs more" are not two
## points on one scale -- a CHARGER has no strike cost, it has no strike
## interaction whatsoever, and DeathModelAudit asserts exactly that.
func _on_body_entered(body: Node3D) -> void:
	if not (body is Keepy):
		return
	if is_fatal(obstacle_type):
		body.die()
		return
	GameState.register_strike(obstacle_type)
