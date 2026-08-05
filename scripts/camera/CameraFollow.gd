extends Camera3D
class_name CameraFollow
## Smooth camera follow behind Keepy.
##
## Deliberately not parented rigidly to the player: lerping position
## each frame instead of matching the player transform 1:1 means lane
## changes and jumps read as eased camera motion rather than a camera
## glued to a jittering rig.

@export var target: Node3D
@export var offset: Vector3 = Vector3(0.0, 4.2, 7.0)
@export var look_ahead: Vector3 = Vector3(0.0, 1.0, -4.0)
@export var follow_speed: float = 6.0

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired_position := target.position + offset
	position = position.lerp(desired_position, 1.0 - exp(-follow_speed * delta))
	look_at(target.position + look_ahead, Vector3.UP)
