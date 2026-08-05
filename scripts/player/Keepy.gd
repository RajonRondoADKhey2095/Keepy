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

var lane_index: int = 1
var target_x: float = 0.0

@onready var swipe_detector: SwipeDetector = get_node_or_null("../SwipeDetector")

func _ready() -> void:
	target_x = LANE_X[lane_index]
	position.x = target_x
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
