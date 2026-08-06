extends Area3D
class_name Obstacle
## A hazard on one lane. Colliding with Keepy ends the run.
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
## there is what kills you, see Obstacle.blocks_jump). Clearing a
## jumpable hazard by jumping over it on its exact lane also triggers a
## small score bonus + a marker "pop" -- see _check_jump_dodge below and
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

enum Type { DODGE, JUMP, ENEMY, AIR_ENEMY, CHARGER }

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
# their own post-invert colour can only be pinned down by rendering and
# measuring, never predicted from the albedo alone -- see
# scripts/dev/DarkPaletteAudit.gd). Cyan specifically because it sits far
# from every existing gameplay hue (DODGE red, JUMP brown, ENEMY purple,
# AIR_ENEMY green, Noisette/Gland gold) -- it never reads as "part of the
# hazard" or "a collectible", only as its own distinct UI-like signal.
# Measured per-palette result: see GameState.gd's DARK_TINT_AMOUNT
# comment and the commit message for the numbers.

## How long the marker's "cleared!" pop lasts -- brief and snappy, a
## flinch-reaction-scale acknowledgement (same design register as
## PERCEPTION_REACTION_S above), not a lingering celebration that would
## still be playing by the time the NEXT hazard needs the player's
## attention.
const MARKER_POP_DURATION_S: float = 0.35
## Peak scale multiplier of the pop, reached at the MIDPOINT of
## MARKER_POP_DURATION_S then eased back to 1.0 -- see _update_marker_pop.
const MARKER_POP_PEAK_SCALE: float = 1.9

@onready var _dodge_mesh: MeshInstance3D = $DodgeMesh
@onready var _dodge_shape: CollisionShape3D = $DodgeShape
@onready var _jump_mesh: MeshInstance3D = $JumpMesh
@onready var _jump_shape: CollisionShape3D = $JumpShape
@onready var _enemy_mesh: MeshInstance3D = $EnemyMesh
@onready var _enemy_shape: CollisionShape3D = $EnemyShape
@onready var _air_enemy_mesh: MeshInstance3D = $AirEnemyMesh
@onready var _air_enemy_shape: CollisionShape3D = $AirEnemyShape
@onready var _charger_mesh: MeshInstance3D = $ChargerMesh
@onready var _charger_shape: CollisionShape3D = $ChargerShape
@onready var _charger_trail: Node3D = $ChargerTrail
@onready var _jump_marker_mesh: MeshInstance3D = $JumpMarkerMesh

## Fired the instant a successful jump-dodge is detected (see
## _check_jump_dodge) -- purely informational, nothing in this codebase
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
## _check_jump_dodge. A crossing from negative to >=0 is the exact same
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
	var shared_material := _enemy_mesh.get_surface_override_material(0) as StandardMaterial3D
	if shared_material:
		_enemy_material = shared_material.duplicate()
		_enemy_mesh.set_surface_override_material(0, _enemy_material)
		_enemy_base_albedo = _enemy_material.albedo_color
		_enemy_base_emission = _enemy_material.emission
		_enemy_base_emission_energy = _enemy_material.emission_energy_multiplier

	var shared_air_material := _air_enemy_mesh.get_surface_override_material(0) as StandardMaterial3D
	if shared_air_material:
		_air_enemy_material = shared_air_material.duplicate()
		_air_enemy_mesh.set_surface_override_material(0, _air_enemy_material)
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

	# JumpMarkerMesh -- permanent "you can jump this" signal (chantier 2,
	# playtest-fixes batch), independent of the alarm-tint timeline below
	# and visible from the moment the obstacle spawns, never just once
	# danger is imminent (see the class doc for why that distinction is
	# the whole point). JUMP and ENEMY show it immediately and keep it on
	# for their entire lifetime (both are ALWAYS jumpable, unlike ENEMY's
	# separate alarm ramp which is a proximity cue, not a jumpability
	# cue). AIR_ENEMY starts hidden -- it is NOT jumpable while still
	# airborne (Obstacle.blocks_jump) -- and is turned on dynamically by
	# _process_air_enemy() the instant it lands. DODGE never shows it.
	_jump_marker_mesh.visible = is_jump or is_enemy
	_jump_marker_mesh.scale = Vector3.ONE
	_marker_pop_t = -1.0
	_prev_pass_z = global_position.z

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return

	# Both run for EVERY type (DODGE/JUMP included, neither of which
	# reaches the ENEMY-only sway code below) -- a jump-dodge can happen
	# on any jumpable type, and a pop that started on a previous frame
	# must keep animating regardless of which per-type branch this frame
	# takes.
	_check_jump_dodge()
	_update_marker_pop(delta)

	if obstacle_type == Type.CHARGER:
		_process_charger(delta)
		return
	if obstacle_type == Type.AIR_ENEMY:
		_process_air_enemy()
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
func _safe_redirect_lane(unsafe_lane: int, time_to_contact: float, track_manager: Node, exclude: Node3D = null) -> int:
	for lane in 3:
		if lane == unsafe_lane:
			continue
		if not track_manager.lane_has_conflicting_jump_hazard(lane, time_to_contact, exclude):
			return lane
	return (unsafe_lane + 1) % 3

func _current_player_lane() -> int:
	var player := _current_player_ref()
	if player == null:
		return -1
	return player.lane_index

## Lazily-cached lookup of the single Keepy instance, shared by
## _current_player_lane() (lane only) and _check_jump_dodge() (which also
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
func closing_speed() -> float:
	return GameState.current_speed * (1.0 + own_speed_factor)

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
## time_to_contact_s() / _check_jump_dodge the moment it came back into
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
	position.z += GameState.current_speed * own_speed_factor * delta
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

## Whether jumping on this obstacle's lane is unsafe -- i.e. whether a
## Gland must never share its lane/row (see TrackSegment.populate).
## JUMP is safe (in fact REQUIRED) to jump into, and ENEMY now is too
## (see the Type.ENEMY doc -- its hitbox is jumpable exactly like JUMP's,
## so a Gland sharing its lane/row is the same "jump clears the hazard
## and grabs the bonus" combo already supported for JUMP). DODGE is
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

## Detects the exact moment a JUMP-DODGE happens -- not "the player
## jumped", but specifically "the player jumped OVER THIS obstacle,
## on ITS lane, at the instant it would otherwise have hit them"
## (playtest: "meme quand je le fais je ne sens rien" -- clearing a
## hazard on purpose needs to feel different from an idle jump on an
## empty lane). Collision itself is tested by Godot's own Area3D
## body_entered (_on_body_entered) at this exact same Z=0 crossing (see
## time_to_contact_s's own doc) -- this function does not duplicate that
## test, it only asks "given no collision happened, was this obstacle
## even relevant to the player right now".
##
## `_prev_pass_z` tracks THIS instance's own global Z frame to frame
## (reset in configure(), see that var's own doc) so the crossing is
## detected exactly once per spawn, not once per frame it happens to sit
## past Z=0 (which would otherwise fire every remaining frame the pooled,
## still-visible-for-one-more-tick instance sits behind the player).
func _check_jump_dodge() -> void:
	if not visible:
		return
	var z := global_position.z
	var crossed := _prev_pass_z < 0.0 and z >= 0.0
	_prev_pass_z = z
	if not crossed or blocks_jump(obstacle_type):
		return
	if obstacle_type == Type.AIR_ENEMY and not air_enemy_landed:
		return # unreachable given blocks_jump already excludes this, kept explicit for clarity
	var player := _current_player_ref()
	if player == null:
		return
	if not is_equal_approx(position.x, TrackSegment.LANE_X[player.lane_index]):
		return # different lane -- this obstacle was never the one the player had to deal with
	if player.is_on_floor():
		return # grounded at the crossing instant: either it just walked into a collision (handled elsewhere) or this type never required a jump to begin with
	jump_dodged.emit()
	_trigger_jump_dodge_feedback()

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

func _on_body_entered(body: Node3D) -> void:
	if body is Keepy:
		body.die()
