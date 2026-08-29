extends Camera3D
class_name LevelCamera
## Follows the walker at a fixed 3/4 offset, and follows the LEVEL up.
##
## =====================================================================
## THE INTERPOLATED OPTION, AND WHY IT COSTS NOTHING
##
## The design doc weighed a hard cut against an interpolated one. This is
## the interpolated one, and it needed no new machinery: the follow is
## already an exponential lerp, so handing it a higher target is the whole
## implementation. A cut would have needed code to suppress the lerp for
## one frame -- more work, for a jump that reads as a glitch.
##
## =====================================================================
## ⚠️ IT FOLLOWS plane_y, NEVER THE BODY'S OWN Y
##
## HubCamera throws the target's Y away on purpose: a camera re-aimed every
## frame at a target whose height oscillates 0.6 units per hop pitches the
## whole horizon up and down in time with the hops, which is far more
## noticeable than the character is.
##
## That argument is still entirely valid, so this does not simply stop
## discarding Y -- it substitutes the LEVEL'S floor for it. A level is
## stable; an arc is not. The camera therefore rises once per crossing and
## is perfectly still during every hop, which is the behaviour HubCamera
## has today plus the one thing it cannot express.
##
## HubCamera itself is NOT modified: that is a hub file, and this batch
## touches none.

const OFFSET: Vector3 = Vector3(0.0, 7.6, 8.9)
const FOLLOW_LAMBDA: float = 5.0

@export var target_path: NodePath
@export var controller_path: NodePath

var target: Node3D = null
var controller: LevelController = null

func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	controller = get_node_or_null(controller_path) as LevelController
	if target == null:
		push_error("LevelCamera: target_path does not resolve to a Node3D.")
	else:
		global_position = _wanted()

func _process(delta: float) -> void:
	if target == null:
		return
	var weight: float = 1.0 - exp(-FOLLOW_LAMBDA * delta)
	global_position = global_position.lerp(_wanted(), weight)

func _wanted() -> Vector3:
	var floor_y: float = 0.0 if controller == null else controller.ground_y()
	var ground := Vector3(target.global_position.x, floor_y, target.global_position.z)
	return ground + OFFSET
