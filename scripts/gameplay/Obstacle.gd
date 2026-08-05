extends Area3D
class_name Obstacle
## A hazard on one lane. Colliding with Keepy ends the run.
## Pooled by TrackSegment: this node is created once and only ever
## shown/hidden and repositioned, never freed during gameplay.
##
## Three visual/collision variants, all always present as children so
## configure() only ever toggles visibility/disabled -- no swapping of
## Mesh resources at runtime, keeping each variant a plain child node
## that can later be replaced with a Meshy .glb independently (see
## README "Adding Meshy assets later").
##   DODGE -- full lane height, taller than Keepy's max jump arc: must
##            be avoided by switching lanes.
##   JUMP  -- a low log: too tall to run through, but short enough that
##            a well-timed jump clears it (see Keepy.gd JUMP_VELOCITY /
##            GRAVITY for the clearance math).
##   ENEMY -- same full lane-blocking height as DODGE (no jump possible),
##            but sways between its lane and an adjacent one while the
##            player approaches, then LOCKS onto its final lane a fixed
##            TIME BEFORE CONTACT (see ENEMY_REACTION_WINDOW_S) rather
##            than a fixed time after spawning -- collision is only ever
##            tested against that settled position, never a mid-sway one,
##            so it stays fully deterministic and testable.

enum Type { DODGE, JUMP, ENEMY }

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

@onready var _dodge_mesh: MeshInstance3D = $DodgeMesh
@onready var _dodge_shape: CollisionShape3D = $DodgeShape
@onready var _jump_mesh: MeshInstance3D = $JumpMesh
@onready var _jump_shape: CollisionShape3D = $JumpShape
@onready var _enemy_mesh: MeshInstance3D = $EnemyMesh
@onready var _enemy_shape: CollisionShape3D = $EnemyShape

var obstacle_type: Type = Type.DODGE

var _enemy_settling: bool = false
var _enemy_phase: float = 0.0 # accumulated sway phase, radians -- see _physics_process
var _enemy_lane_x: float = 0.0
var _enemy_alt_lane_x: float = 0.0

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

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var shared_material := _enemy_mesh.get_surface_override_material(0) as StandardMaterial3D
	if shared_material:
		_enemy_material = shared_material.duplicate()
		_enemy_mesh.set_surface_override_material(0, _enemy_material)
		_enemy_base_albedo = _enemy_material.albedo_color
		_enemy_base_emission = _enemy_material.emission
		_enemy_base_emission_energy = _enemy_material.emission_energy_multiplier

## Switches which variant's mesh/collision shape is active. Called by
## TrackSegment.populate() every time this pooled obstacle is (re)spawned.
## lane_x/alt_lane_x are only meaningful for Type.ENEMY: lane_x is the
## final (settled) lane -- the same lane TrackSegment already reserves to
## keep noisettes/glands off it -- and alt_lane_x is the adjacent lane it
## sways from/to before locking. Both are ignored for DODGE/JUMP.
func configure(type: Type, lane_x: float = 0.0, alt_lane_x: float = 0.0) -> void:
	obstacle_type = type
	var is_dodge := type == Type.DODGE
	var is_enemy := type == Type.ENEMY
	_dodge_mesh.visible = is_dodge
	_dodge_shape.disabled = not is_dodge
	_jump_mesh.visible = not is_dodge and not is_enemy
	_jump_shape.disabled = is_dodge or is_enemy
	_enemy_mesh.visible = is_enemy
	_enemy_shape.disabled = not is_enemy

	_enemy_settling = is_enemy
	_enemy_phase = 0.0
	_enemy_lane_x = lane_x
	_enemy_alt_lane_x = alt_lane_x
	if is_enemy:
		position.x = _enemy_lane_x
		_apply_enemy_alarm(0.0) # reset tint -- this instance may be a pooled reuse

func _physics_process(delta: float) -> void:
	if not _enemy_settling:
		return
	if GameState.state != GameState.State.PLAYING:
		return

	# Keepy sits fixed at Z=0 (see Keepy.gd / TrackManager.gd -- the WORLD
	# moves toward the static player), so global_position.z IS the
	# remaining distance to contact: negative while still ahead, 0 at
	# contact. Dividing by the CURRENT speed (not a fixed distance) turns
	# that into a time-before-contact that self-adjusts as the run's
	# speed ramps up -- see ENEMY_REACTION_WINDOW_S above.
	var distance_to_contact := -global_position.z
	var time_to_contact := distance_to_contact / GameState.current_speed

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
		# Blend the full-amplitude sway toward the fixed final lane so the
		# motion eases into place instead of cutting off mid-swing right
		# at the hard lock threshold.
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

## Lerps the (per-instance, see _ready) EnemyMesh material from its base
## colors toward ENEMY_ALARM_ALBEDO/_EMISSION/_EMISSION_ENERGY. t=0 is the
## resting color (Obstacle.tscn's default purple), t=1 is fully alarmed.
func _apply_enemy_alarm(t: float) -> void:
	if not _enemy_material:
		return
	_enemy_material.albedo_color = _enemy_base_albedo.lerp(ENEMY_ALARM_ALBEDO, t)
	_enemy_material.emission = _enemy_base_emission.lerp(ENEMY_ALARM_EMISSION, t)
	_enemy_material.emission_energy_multiplier = lerpf(_enemy_base_emission_energy, ENEMY_ALARM_EMISSION_ENERGY, t)

## Whether this obstacle Type can never be jumped over -- i.e. whether a
## Gland must never share its lane/row (see TrackSegment.populate). Only
## JUMP is timing-clearable; DODGE and ENEMY both require a full lane
## switch, same as each other.
static func blocks_jump(type: Type) -> bool:
	return type != Type.JUMP

func _on_body_entered(body: Node3D) -> void:
	if body is Keepy:
		body.die()
