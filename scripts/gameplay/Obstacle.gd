extends Area3D
class_name Obstacle
## A hazard on one lane. Colliding with Keepy ends the run.
## Pooled by TrackSegment: this node is created once and only ever
## shown/hidden and repositioned, never freed during gameplay.
##
## Two visual/collision variants, both always present as children so
## configure() only ever toggles visibility/disabled -- no swapping of
## Mesh resources at runtime, keeping each variant a plain child node
## that can later be replaced with a Meshy .glb independently (see
## README "Adding Meshy assets later").
##   DODGE -- full lane height, taller than Keepy's max jump arc: must
##            be avoided by switching lanes.
##   JUMP  -- a low log: too tall to run through, but short enough that
##            a well-timed jump clears it (see Keepy.gd JUMP_VELOCITY /
##            GRAVITY for the clearance math).

enum Type { DODGE, JUMP }

@onready var _dodge_mesh: MeshInstance3D = $DodgeMesh
@onready var _dodge_shape: CollisionShape3D = $DodgeShape
@onready var _jump_mesh: MeshInstance3D = $JumpMesh
@onready var _jump_shape: CollisionShape3D = $JumpShape

var obstacle_type: Type = Type.DODGE

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## Switches which variant's mesh/collision shape is active. Called by
## TrackSegment.populate() every time this pooled obstacle is (re)spawned.
func configure(type: Type) -> void:
	obstacle_type = type
	var is_dodge := type == Type.DODGE
	_dodge_mesh.visible = is_dodge
	_dodge_shape.disabled = not is_dodge
	_jump_mesh.visible = not is_dodge
	_jump_shape.disabled = is_dodge

## Whether this obstacle Type can never be jumped over -- i.e. whether a
## Gland must never share its lane/row (see TrackSegment.populate). Only
## JUMP is timing-clearable; any other variant requires a full lane switch.
static func blocks_jump(type: Type) -> bool:
	return type != Type.JUMP

func _on_body_entered(body: Node3D) -> void:
	if body is Keepy:
		body.die()
