@tool
extends MeshInstance3D
class_name ModelSlot
## THE swap point: the one node type where a Meshy .glb replaces a
## primitive placeholder, and the only thing that has to change to do it.
##
## =====================================================================
## WHAT IT IS
##
## A ModelSlot IS a MeshInstance3D. It keeps carrying the placeholder
## primitive exactly as before -- same node, same name, same local
## transform, same parent, same position in the scene tree. Set its
## `model_scene` to an imported .glb and, at _ready(), it instantiates
## that scene as a child of itself and clears its own `mesh` so the
## placeholder geometry stops drawing. Leave `model_scene` null and this
## file does nothing at all: the node behaves as the plain
## MeshInstance3D it was before, byte for byte.
##
## =====================================================================
## WHY THIS SHAPE, AND NOT ONE OF THE ALTERNATIVES
##
## The obvious options were a dedicated scene per object, a lookup table
## mapping type -> .glb, or an export var on the node itself. The export
## var wins here for one specific structural reason: the gameplay code in
## this project addresses its visuals BY NODE PATH and drives them
## through the MeshInstance3D API. Obstacle.gd alone holds eight such
## references ($DodgeMesh, $EnemyMesh, ...) and does real work through
## them -- toggles `.visible` per variant, animates `.scale` for the
## STOMPER's pulse, moves `.position.y` as an AIR_ENEMY descends, and
## duplicates the surface material to tint one instance without bleeding
## into the pooled others. Pursuer.gd does the same for $Silhouette, and
## PursuerFramingAudit.gd projects that node's AABB to measure screen
## occupancy.
##
## A separate scene or a lookup table would have had to REPLACE those
## nodes, which means every one of those call sites becomes a thing to
## re-point, and each one is a chance to re-point it slightly wrong. By
## staying the same node, this design leaves all of them working
## untouched: `.visible` still hides the model (children inherit it),
## `.scale` still scales it, `.position` still moves it, because the
## model is a CHILD of the node those properties are set on.
##
## The two places where "same node" is not enough are materials and the
## AABB -- a swapped-in model's surfaces are not the slot's own surfaces.
## Those get the two accessors below (`slot_material` / `apply_material`,
## and `visual_aabb`), which resolve to the placeholder when no model is
## installed and to the model's meshes when one is. Three call sites in
## Obstacle.gd, one in Pursuer.gd, one in PursuerFramingAudit.gd; each one
## returns exactly what it returned before in the no-model case.
##
## =====================================================================
## WHAT IT DELIBERATELY DOES NOT DO
##
## IT NEVER TOUCHES A COLLIDER. Not one line below reads or writes a
## CollisionShape3D, and there is no code path by which installing a
## model can. Hitbox dimensions live in Hitboxes.gd and are written onto
## the shapes by each owning script at _ready(); a mesh swap cannot reach
## them. That is the whole guarantee this batch exists to establish, and
## scripts/dev/AssetContractAudit.gd verifies it by measuring every
## collider before and after installing a substitute model rather than by
## trusting this paragraph.
##
## IT NEVER ALLOCATES IN THE GAME LOOP. `_install_model()` runs once, from
## _ready(). Every pooled object in this project (Obstacle, Noisette,
## Gland, TrackSegment, Pursuer) is instantiated once at load and then
## only ever shown/hidden and repositioned -- so a slot inside a pooled
## object installs its model exactly once too, at the same moment the
## pool itself is built, and never again during a run. There is no
## per-frame work here at all: this script has no _process and no
## _physics_process.

## The imported model to draw instead of the placeholder. Null (the
## default, and the state every slot in the project ships in today) means
## "keep the placeholder", so this whole file is inert until an asset
## actually exists.
##
## Expected to be a .glb imported by Godot, which yields a PackedScene
## whose root is a Node3D carrying one or more MeshInstance3D children.
## Anything that instantiates to a Node3D works, which is what lets the
## dev probe install a plain primitive as a substitute (see
## scripts/dev/SubstituteModel.tscn) and prove the mechanism without
## needing a real asset.
@export var model_scene: PackedScene = null:
	set(value):
		model_scene = value
		if is_inside_tree():
			_install_model()

## Uniform scale applied to the installed model, so a .glb authored at a
## different unit scale is corrected HERE rather than by re-exporting it
## or by editing the gameplay scene's own transform.
##
## Applied to the model child, never to the slot itself: the slot's own
## scale is gameplay-driven in at least one place (Obstacle.gd animates
## the STOMPER's pulse through it), so writing an art correction into the
## same property would have the two fight every frame.
@export var model_scale: float = 1.0:
	set(value):
		model_scale = value
		if _model_root:
			_model_root.scale = Vector3.ONE * model_scale

## Euler rotation, in degrees, applied to the installed model. Same
## reasoning as model_scale: a .glb whose author faced it the wrong way
## is corrected here, in the scene, without touching the exporter or the
## gameplay code that decides where the object goes.
##
## The project's orientation contract is MEASURED, not assumed -- see
## docs/MESHY_SPEC.md, and scripts/dev/ChargerShapeProbe.gd, which asserts
## it against the real built mesh.
@export var model_rotation_degrees: Vector3 = Vector3.ZERO:
	set(value):
		model_rotation_degrees = value
		if _model_root:
			_model_root.rotation_degrees = model_rotation_degrees

## The instantiated model's root, or null while the placeholder is in
## use. Held so a re-install can free the previous one (editor use, via
## the setters above) rather than stacking models on top of each other.
var _model_root: Node3D = null

## Every MeshInstance3D actually being drawn by this slot: `[self]` for
## the placeholder, or the model's own mesh instances once one is
## installed. Built once at install time, so the material and AABB
## accessors below never walk the tree at runtime.
var _drawn: Array[MeshInstance3D] = []

func _ready() -> void:
	_install_model()

func _install_model() -> void:
	if _model_root:
		_model_root.queue_free()
		_model_root = null
	_drawn.clear()

	if model_scene == null:
		# Placeholder path. `_drawn` is this node itself, which is what
		# makes every accessor below return exactly what the plain
		# MeshInstance3D API would have returned -- the no-model case is
		# not merely equivalent to the old behaviour, it IS it.
		_drawn.append(self)
		return

	var instance := model_scene.instantiate()
	var root := instance as Node3D
	if root == null:
		# A PackedScene that is not a Node3D cannot be positioned, scaled
		# or drawn in 3D. Fail loudly and keep the placeholder rather than
		# silently rendering nothing -- an object that quietly vanishes is
		# far harder to trace back to its cause than a red line at boot.
		push_error("ModelSlot '%s': model_scene root is not a Node3D, keeping the placeholder." % name)
		instance.free()
		_drawn.append(self)
		return

	_model_root = root
	_model_root.scale = Vector3.ONE * model_scale
	_model_root.rotation_degrees = model_rotation_degrees
	add_child(_model_root)

	# The placeholder's geometry stops drawing, but the NODE stays: its
	# transform, name and API are what the gameplay scripts address, and
	# none of that may move just because the art did.
	mesh = null

	_collect_drawn(_model_root)
	if _drawn.is_empty():
		push_warning("ModelSlot '%s': installed model contains no MeshInstance3D." % name)

func _collect_drawn(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance:
		_drawn.append(mesh_instance)
	for child in node.get_children():
		_collect_drawn(child)

## True when a model has replaced the placeholder. Read by the dev probe
## to state which of the two it measured, so its output can never be
## mistaken for the other one.
func has_model() -> bool:
	return _model_root != null

## The material this slot draws its FIRST surface with, or null if there
## is none.
##
## Exists because Obstacle.gd and Pursuer.gd both duplicate a shared
## material at _ready() so a pooled instance can animate its own tint
## without bleeding into its siblings (see their own comments for why).
## That duplication needs a handle on whatever is actually being drawn,
## which stops being `self` the moment a model is installed.
func slot_material() -> Material:
	if _drawn.is_empty():
		return null
	return _drawn[0].get_surface_override_material(0)

## Applies `material` as the surface-0 override on everything this slot
## draws.
##
## ALL of them, not just the first: a .glb body split into several mesh
## instances must tint as one object, or an alarm ramp would light up a
## squirrel's torso and leave its tail behind.
func apply_material(material: Material) -> void:
	for mesh_instance in _drawn:
		mesh_instance.set_surface_override_material(0, material)

## Bounding box of what this slot actually draws, in the SLOT's own local
## space -- so a caller can keep transforming it by this node's
## `global_transform` exactly as it did when calling `get_aabb()` on a
## plain MeshInstance3D.
##
## With no model installed this returns `get_aabb()` unchanged, which is
## what keeps PursuerFramingAudit's occupancy numbers identical across
## this batch: same method, same value, same measurement.
func visual_aabb() -> AABB:
	if not has_model():
		return get_aabb()
	var result := AABB()
	var seeded := false
	for mesh_instance in _drawn:
		if mesh_instance.mesh == null:
			continue
		# Into SLOT space: a model's mesh instances sit under _model_root,
		# which carries the art-correction scale/rotation, so their own
		# AABBs are not directly comparable to this node's until they are
		# brought through the transform chain between them.
		var local := get_transform_to_slot(mesh_instance) * mesh_instance.mesh.get_aabb()
		if seeded:
			result = result.merge(local)
		else:
			result = local
			seeded = true
	return result

## Transform taking `descendant`'s local space into this slot's local
## space, by walking up the parent chain rather than assuming a depth --
## an imported .glb can nest its meshes arbitrarily deep.
func get_transform_to_slot(descendant: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var node := descendant
	while node != null and node != self:
		result = node.transform * result
		node = node.get_parent() as Node3D
	return result
