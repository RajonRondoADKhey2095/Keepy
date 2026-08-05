extends CharacterBody3D
class_name Keepy
## Keepy, the player character.
##
## Stays fixed on the Z axis forever -- see TrackManager.gd for why the
## world moves toward the player instead of the player moving through
## the world (this sidesteps floating point precision loss on a long
## run, since Keepy's transform never drifts far from the origin).

const LANE_X: Array[float] = [-2.0, 0.0, 2.0]
const LANE_SWITCH_SPEED: float = 12.0 # higher = snappier lane lerp
const JUMP_VELOCITY: float = 9.0
const GRAVITY: float = 26.0
# Jump clearance math (kept unchanged, verified against the two Obstacle
# variants in Obstacle.gd -- see comment there for the actual heights):
#   peak height = JUMP_VELOCITY^2 / (2*GRAVITY) = 81/52 ~= 1.56m above the
#   ground -- this is how high Keepy's CAPSULE BOTTOM rises, since
#   `position.y` (this body's origin) sits at the capsule's floor.
#   JUMP obstacle top = 0.7m: Keepy's bottom is above 0.7m for a ~0.51s
#   window centered on the jump's peak, comfortably longer than the
#   obstacle's transit window under Keepy (2.0m of relative travel /
#   current_speed, i.e. <=0.18s even at GameState.BASE_SPEED) -- a
#   reasonably-timed jump clears it with margin.
#   DODGE obstacle top = 2.0m: above the 1.56m peak, so it can never be
#   jumped, only dodged sideways, by construction (not by timing).
# Same peak-height formula, exposed as a named const rather than left as a
# comment-only value, so other scripts (TrackSegment's Gland placement)
# derive their own math from it instead of re-deriving or guessing a
# height. ~1.56m, see comment block above for the full derivation.
const JUMP_PEAK_HEIGHT: float = JUMP_VELOCITY * JUMP_VELOCITY / (2.0 * GRAVITY)
# Matches the CollisionShape3D/MeshInstance3D y-offset baked into
# Keepy.tscn (capsule height 1.6, centered at 0.8 above the body origin).
# Combined with JUMP_PEAK_HEIGHT this gives the height of the CENTER of
# Keepy's capsule at the jump's apex -- see TrackSegment.gd GLAND_Y.
const CAPSULE_HALF_HEIGHT: float = 0.8

# Top height, in world Y, that a well-timed jump clears -- promoted from
# the JUMP obstacle's own baked 0.7m (see the derivation in the comment
# block above: a ~0.51s window centered on the jump's peak, comfortably
# longer than any obstacle's transit window under Keepy) into a single
# named constant so every jumpable GROUND hazard in the game (the JUMP
# log, and since the ground-enemy-jump-dodge/mobile-air-enemy-landing
# work, also Obstacle.Type.ENEMY once settled and a landed AIR_ENEMY)
# reuses the exact same verified number instead of each guessing its own.
# JUMP's own BoxMesh/BoxShape in Obstacle.tscn stay baked at the literal
# 0.7 they were already verified at -- not rewired to read this constant,
# to avoid touching an already-shipped, already-verified hitbox -- but
# both values must always match; this constant IS that value's home.
const JUMPABLE_OBSTACLE_TOP_HEIGHT: float = 0.7

var lane_index: int = 1
var target_x: float = 0.0

@onready var swipe_detector: SwipeDetector = get_node_or_null("../SwipeDetector")

func _ready() -> void:
	target_x = LANE_X[lane_index]
	position.x = target_x
	# Looked up by group rather than a NodePath: Obstacle.gd (ground ENEMY
	# lane targeting, see its _decide_late_lock) needs to read Keepy's
	# current lane at a moment that has nothing to do with either node's
	# position in the scene tree.
	add_to_group("player")
	if swipe_detector:
		swipe_detector.swiped_left.connect(_on_swipe_left)
		swipe_detector.swiped_right.connect(_on_swipe_right)
		swipe_detector.swiped_up.connect(_on_swipe_up)

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return

	_handle_keyboard_input()

	# Lateral lane movement is always interpolated, never a teleport.
	position.x = lerp(position.x, target_x, 1.0 - exp(-LANE_SWITCH_SPEED * delta))

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("ui_jump"):
		velocity.y = JUMP_VELOCITY

	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()

func _handle_keyboard_input() -> void:
	if Input.is_action_just_pressed("ui_left"):
		move_lane(-1)
	elif Input.is_action_just_pressed("ui_right"):
		move_lane(1)

func move_lane(direction: int) -> void:
	lane_index = clampi(lane_index + direction, 0, LANE_X.size() - 1)
	target_x = LANE_X[lane_index]

func reset_lane() -> void:
	lane_index = 1
	target_x = LANE_X[lane_index]
	position.x = target_x

func _on_swipe_left() -> void:
	move_lane(-1)

func _on_swipe_right() -> void:
	move_lane(1)

func _on_swipe_up() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY

func die() -> void:
	if GameState.state == GameState.State.PLAYING:
		GameState.end_run()
