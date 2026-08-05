extends Area3D
class_name CollectibleBase
## Shared behaviour for every pooled pickup collectible (Noisette, Gland):
## the "this is a bonus, not a hazard" motion read (continuous spin + a
## small vertical bob) and the pooled collected/hide-on-pickup lifecycle.
## Kept as a base class so both variants share ONE copy of this animation
## code, and of the unified size constants below, instead of duplicating
## either between two near-identical scripts.
##
## A continuously spinning/bobbing object reads instinctively as
## ramassable; an inert one reads as scenery or a hazard -- see
## Obstacle.gd, which never animates its variants for that same reason
## reversed. This is what makes a collectible legible as "take me" versus
## an obstacle read as "avoid me" at a glance, independent of colour.

# Shared mesh/collision size for every collectible variant -- the ONE
# place Noisette and Gland derive their SphereMesh/SphereShape3D radius
# from in _ready(), instead of each .tscn baking its own magic number
# (previously mismatched: noisette 0.35, gland 0.5).
const MESH_RADIUS: float = 0.3
# Collision stays slightly more generous than the visible mesh so a
# pickup at this smaller size never feels precision-frustrating -- a
# deliberate gameplay margin over the mesh, not a mesh/collider mismatch.
const COLLISION_RADIUS: float = 0.4

const ROTATION_SPEED: float = 2.4 # rad/s, continuous spin around Y
const BOB_AMPLITUDE: float = 0.12 # meters, vertical travel around spawn height
const BOB_HZ: float = 1.1 # bob cycles per second

var collected: bool = false

var _base_position: Vector3 = Vector3.ZERO
var _anim_elapsed: float = 0.0

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_shared_size()

func _apply_shared_size() -> void:
	var mesh := _mesh_instance.mesh
	if mesh is SphereMesh:
		mesh.radius = MESH_RADIUS
		mesh.height = MESH_RADIUS * 2.0
	var shape := _collision_shape.shape
	if shape is SphereShape3D:
		shape.radius = COLLISION_RADIUS

## Called by TrackSegment.populate() instead of setting `.position`
## directly, so the bob animation below has a stable spawn height to bob
## around instead of drifting frame over frame, and so the spin phase
## resets cleanly on every (re)spawn from the pool.
func set_spawn_position(spawn_position: Vector3) -> void:
	_base_position = spawn_position
	position = spawn_position
	_anim_elapsed = 0.0
	rotation.y = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	_anim_elapsed += delta
	rotate_y(ROTATION_SPEED * delta)
	position.y = _base_position.y + sin(_anim_elapsed * TAU * BOB_HZ) * BOB_AMPLITUDE

func _on_body_entered(body: Node3D) -> void:
	if collected:
		return
	if body is Keepy:
		collected = true
		visible = false
		monitoring = false
		_on_collected()

## Overridden by each variant to award its own score value.
func _on_collected() -> void:
	pass
