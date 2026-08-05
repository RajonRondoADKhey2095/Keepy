extends Area3D
class_name Gland
## A high-value bonus collectible sitting above Keepy's normal running
## height, reachable only near the apex of a jump (see TrackSegment.gd
## GLAND_Y, derived from Keepy.JUMP_PEAK_HEIGHT / CAPSULE_HALF_HEIGHT --
## never a guessed height). Missing the jump window simply means the
## Gland goes uncollected; unlike an obstacle, there is no penalty.
##
## Pooled by TrackSegment exactly like Noisette: picking one up hides it
## and disables its collision instead of freeing the node.
## TrackSegment.populate() resets `collected` and reactivates the slot
## on the next recycle.

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
		GameState.add_gland()
