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
##            but sways between its lane and an adjacent one for a short
##            real-time window right after it spawns, then LOCKS onto its
##            final lane (see ENEMY_SETTLE_DURATION_S) well before the
##            player can possibly reach it -- collision is only ever
##            tested against that settled position, never a mid-sway one,
##            so it stays fully deterministic and testable.

enum Type { DODGE, JUMP, ENEMY }

# How long (real seconds) an ENEMY obstacle keeps swaying before locking
# onto its final lane. Segments spawn/recycle SEGMENT_COUNT *
# SEGMENT_LENGTH behind the player (TrackManager) -- even at
# GameState.MAX_SPEED that's several seconds of travel before the player
# can reach a freshly (re)spawned obstacle, so this settle window always
# finishes with a comfortable margin before contact is even possible.
const ENEMY_SETTLE_DURATION_S: float = 1.4
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
	if _enemy_elapsed >= ENEMY_SETTLE_DURATION_S:
		_enemy_settling = false
		position.x = _enemy_lane_x
		return

	# Blend a full-amplitude sine sway (at t=0) toward the fixed final
	# lane (at t=1) so the motion eases into place instead of cutting off
	# mid-swing on the final frame.
	var settle_t := _enemy_elapsed / ENEMY_SETTLE_DURATION_S
	var wave := 0.5 + 0.5 * sin(_enemy_elapsed * TAU * ENEMY_OSCILLATION_HZ)
	var wave_x: float = lerp(_enemy_lane_x, _enemy_alt_lane_x, wave)
	position.x = lerp(wave_x, _enemy_lane_x, settle_t)

## Whether this obstacle Type can never be jumped over -- i.e. whether a
## Gland must never share its lane/row (see TrackSegment.populate). Only
## JUMP is timing-clearable; DODGE and ENEMY both require a full lane
## switch, same as each other.
static func blocks_jump(type: Type) -> bool:
	return type != Type.JUMP

func _on_body_entered(body: Node3D) -> void:
	if body is Keepy:
		body.die()
