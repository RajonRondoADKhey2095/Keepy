extends Area3D
class_name Noisette
## A collectible hazelnut worth +1 score.
##
## Pooled by TrackSegment: picking one up hides it and disables its
## collision instead of freeing the node. TrackSegment.populate()
## resets `collected` and reactivates the slot on the next recycle.

var collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if collected:
		return
	if body is Keepy:
		collected = true
		visible = false
		monitoring = false
		GameState.add_noisette()
