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
const PERCEPTION_REACTION_S: float = 0.35

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

const ENEMY_OSCILLATION_HZ: float = 2.2 # sway cycles per second while unsettled

@onready var _dodge_mesh: MeshInstance3D = $DodgeMesh
@onready var _dodge_shape: CollisionShape3D = $DodgeShape
@onready var _jump_mesh: MeshInstance3D = $JumpMesh
@onready var _jump_shape: CollisionShape3D = $JumpShape
@onready var _enemy_mesh: MeshInstance3D = $EnemyMesh
@onready var _enemy_shape: CollisionShape3D = $EnemyShape

var obstacle_type: Type = Type.DODGE

var _enemy_settling: bool = false
var _enemy_elapsed: float = 0.0
var _enemy_lane_x: float = 0.0
var _enemy_alt_lane_x: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

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
	_enemy_elapsed = 0.0
	_enemy_lane_x = lane_x
	_enemy_alt_lane_x = alt_lane_x
	if is_enemy:
		position.x = _enemy_lane_x

func _physics_process(delta: float) -> void:
	if not _enemy_settling:
		return
	if GameState.state != GameState.State.PLAYING:
		return

	_enemy_elapsed += delta

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
		return

	var wave := 0.5 + 0.5 * sin(_enemy_elapsed * TAU * ENEMY_OSCILLATION_HZ)
	var wave_x: float = lerp(_enemy_lane_x, _enemy_alt_lane_x, wave)

	if time_to_contact <= ENEMY_REACTION_WINDOW_S + ENEMY_EASE_DURATION_S:
		# Blend the full-amplitude sway toward the fixed final lane so the
		# motion eases into place instead of cutting off mid-swing right
		# at the hard lock threshold.
		var ease_t := 1.0 - (time_to_contact - ENEMY_REACTION_WINDOW_S) / ENEMY_EASE_DURATION_S
		position.x = lerp(wave_x, _enemy_lane_x, ease_t)
	else:
		position.x = wave_x

## Whether this obstacle Type can never be jumped over -- i.e. whether a
## Gland must never share its lane/row (see TrackSegment.populate). Only
## JUMP is timing-clearable; DODGE and ENEMY both require a full lane
## switch, same as each other.
static func blocks_jump(type: Type) -> bool:
	return type != Type.JUMP

func _on_body_entered(body: Node3D) -> void:
	if body is Keepy:
		body.die()
