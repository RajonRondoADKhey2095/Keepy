extends Area3D
class_name Obstacle
## A solid hazard on one lane. Colliding with Keepy ends the run.
## Pooled by TrackSegment: this node is created once and only ever
## shown/hidden and repositioned, never freed during gameplay.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is Keepy:
		body.die()
