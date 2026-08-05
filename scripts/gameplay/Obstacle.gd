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
##                -- ground-level running passes safely underneath, a
##                jump on its lane runs straight into it, exactly the
##                original AIR_ENEMY contract -- then DESCENDS over its
##                final approach and LANDS on its lane, becoming a
##                jumpable ground hazard (same JUMPABLE_OBSTACLE_TOP_HEIGHT
##                contract as ENEMY) for the remainder of the approach.
##                See _process_air_enemy for the exact schedule and why
##                landing completes a full ENEMY_REACTION_WINDOW_S before
##                contact -- the same reaction budget the ground ENEMY's
##                own hard lock guarantees. Its LANE never changes (only
##                its height does) -- it does not hunt the player the way
##                ENEMY does.

enum Type { DODGE, JUMP, ENEMY, AIR_ENEMY }

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

@onready var _dodge_mesh: MeshInstance3D = $DodgeMesh
@onready var _dodge_shape: CollisionShape3D = $DodgeShape
@onready var _jump_mesh: MeshInstance3D = $JumpMesh
@onready var _jump_shape: CollisionShape3D = $JumpShape
@onready var _enemy_mesh: MeshInstance3D = $EnemyMesh
@onready var _enemy_shape: CollisionShape3D = $EnemyShape
@onready var _air_enemy_mesh: MeshInstance3D = $AirEnemyMesh
@onready var _air_enemy_shape: CollisionShape3D = $AirEnemyShape

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
	var is_dodge := type == Type.DODGE
	var is_jump := type == Type.JUMP
	var is_enemy := type == Type.ENEMY
	var is_air_enemy := type == Type.AIR_ENEMY
	_dodge_mesh.visible = is_dodge
	_dodge_shape.disabled = not is_dodge
	_jump_mesh.visible = is_jump
	_jump_shape.disabled = not is_jump
	_enemy_mesh.visible = is_enemy
	_enemy_shape.disabled = not is_enemy
	_air_enemy_mesh.visible = is_air_enemy
	_air_enemy_shape.disabled = not is_air_enemy

	_enemy_settling = is_enemy
	_enemy_phase = 0.0
	_enemy_lane_x = lane_x
	_enemy_alt_lane_x = alt_lane_x
	_enemy_late_lock_resolved = false
	if is_enemy:
		position.x = _enemy_lane_x
		_apply_enemy_alarm(0.0) # reset tint -- this instance may be a pooled reuse

	air_enemy_landed = false
	if is_air_enemy:
		_air_enemy_mesh.position.y = TrackSegment.GLAND_Y
		_air_enemy_shape.position.y = TrackSegment.GLAND_Y
		_apply_air_enemy_tint(0.0) # reset tint -- this instance may be a pooled reuse

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
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
func _safe_redirect_lane(unsafe_lane: int, time_to_contact: float, track_manager: Node) -> int:
	for lane in 3:
		if lane == unsafe_lane:
			continue
		if not track_manager.lane_has_conflicting_jump_hazard(lane, time_to_contact):
			return lane
	return (unsafe_lane + 1) % 3

func _current_player_lane() -> int:
	if _player_ref == null:
		_player_ref = get_tree().get_first_node_in_group("player")
	if _player_ref == null:
		return -1
	return _player_ref.lane_index

func _track_manager() -> Node:
	if _track_manager_ref == null:
		_track_manager_ref = get_tree().get_first_node_in_group("track_manager")
	return _track_manager_ref

## Public: this instance's own time-before-contact, in seconds. Exposed
## so TrackManager's cross-obstacle safety scan can compare two
## independent Obstacle instances' schedules without duplicating this
## division (see the class doc on Keepy sitting fixed at Z=0).
func time_to_contact_s() -> float:
	return -global_position.z / GameState.current_speed

## Animates the AIR_ENEMY variant's height across its whole approach --
## see the Type.AIR_ENEMY doc for the schedule this implements. Runs
## every physics frame this instance is configured as AIR_ENEMY,
## regardless of visibility (matches the pre-existing tolerance for the
## ENEMY sway logic doing the same on a pooled-but-inactive instance --
## harmless, and TrackManager's safety scan already filters on
## `visible` before treating an obstacle as live).
func _process_air_enemy() -> void:
	var time_to_contact := time_to_contact_s()
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
	air_enemy_landed = t >= 1.0
	_apply_air_enemy_tint(t)

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
static func blocks_jump(type: Type) -> bool:
	return type == Type.DODGE or type == Type.AIR_ENEMY

func _on_body_entered(body: Node3D) -> void:
	if body is Keepy:
		body.die()
