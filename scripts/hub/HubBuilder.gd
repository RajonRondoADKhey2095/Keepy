extends Node3D
class_name HubBuilder
## Instantiates everything the plateau is made of, from HubLayout data.
##
## Nothing here decides WHERE anything goes -- that is entirely
## resources/hub/hub_layout.tres. This file only knows how to turn a type
## name into geometry, and it validates rather than trusts: a malformed
## entry is reported and skipped, because a typo in a decor file must
## never be the reason a player cannot reach their games.
##
## Prop meshes are built in code from primitives, deliberately. They are
## placeholders for this batch -- no Meshy credit is spent here -- and a
## primitive authored in code cannot drift from the layout the way a
## per-prop .tscn with its own baked transform would.
##
## Every material is UNSHADED, which is this project's standing rule for
## every surface (docs/MESHY_SPEC.md 8): the scene has no
## DirectionalLight3D, so a lit surface would render at whatever the
## ambient term alone gives it and its colour would stop being the colour
## that was authored.
##
## =====================================================================
## SCATTER PROPS ARE BATCHED, LANDMARKS AND PORTALS ARE NOT (25 aout 2026)
##
## tree / rock / bush / flower used to be a Node3D each with one
## or two MeshInstance3D children, which put the plateau at 259 draw nodes
## against a 260 ceiling -- one spare. They are now accumulated into a
## MultiMeshInstance3D per UNIQUE (mesh, colour) pair, filled in a second
## pass once every entry has been read.
##
## The unit of batching is the (mesh, colour) PAIR and not the semantic
## type, and the two do not line up: a tree contributes to two batches
## (trunk and crown are different meshes), a bush contributes TWO
## INSTANCES to one batch (its two lobes share a single SphereMesh at two
## offsets), and a flower's corolla splits three ways because its three
## tints are three different draws.
##
## Per-instance colour (MultiMesh.use_colors plus
## vertex_color_use_as_albedo) would collapse those three corolla nodes
## into one. It is NOT used: it would make the shipped material differ
## from the one this file used to build, on a batch nobody can look at
## before it is on staging, to save two nodes out of a budget this change
## empties. Three nodes carrying the exact material they carried before is
## the version whose parity can be proven rather than hoped for.
##
## WHAT STAYS AN INDIVIDUAL NODE, and why:
##
##   portal    it is an Area3D with a CollisionShape3D and a Label3D, and
##             HubWorld connects a signal to each one. A MultiMesh has no
##             per-instance node to connect to.
##   landmark  three silhouettes, 3 to 5 meshes each, 8 on the plateau --
##             batching them would trade 31 nodes for ~12 and lose the
##             per-variant readability of the tree.
##
## NO COLLISION IS LOST. tree / rock / bush / flower have never
## had a CollisionShape3D -- grepped, not assumed -- so nothing on the
## plateau depends on a per-prop physics node. The ground is not a
## collider either: HubTapInput intersects a maths Plane rather than
## raycasting. The only Area3D on this screen belongs to HubPortal, which
## is exactly what this change leaves alone.

## The plateau's contents. Swap this resource and the whole screen
## re-lays-out with no code change -- the point of the split.
@export var layout: HubLayout

## Scene instantiated for every &"portal" entry.
@export var portal_scene: PackedScene

const TRUNK_COLOR: Color = Color(0.20, 0.13, 0.08)
const CROWN_COLOR: Color = Color(0.17, 0.34, 0.13)
const ROCK_COLOR: Color = Color(0.26, 0.27, 0.24)
const BUSH_COLOR: Color = Color(0.21, 0.39, 0.16)

## Flower colours, LOCAL to the hub on purpose. SwampPalette.gd carries the
## identity Chased and the plateau share; these are hub-local decor, read by
## nothing else, and its own header says that kind of colour stays here
## rather than being promoted into the shared resource.
const FLOWER_STEM_COLOR: Color = Color(0.19, 0.35, 0.14)

## Three corolla tints rather than one: a field of a single colour reads as
## a repeated instance, which is exactly what it is. Entries pick one with
## an optional "variant" int; anything out of range falls back to 0 so a
## layout written without the field still builds.
##
## One MultiMesh batch each -- see the header. The batch keys are kept in
## step with this array by _FLOWER_PETAL_KEYS below.
const FLOWER_PETAL_COLORS: Array[Color] = [
	Color(0.93, 0.86, 0.42),
	Color(0.86, 0.52, 0.62),
	Color(0.72, 0.66, 0.88),
]

## Batch key per corolla tint, index-aligned with FLOWER_PETAL_COLORS. A
## fourth tint means a fourth entry in both, and the assert in _ready()
## fails loudly rather than silently drawing every extra tint as tint 0.
const _FLOWER_PETAL_KEYS: Array[StringName] = [
	&"FlowerPetal0",
	&"FlowerPetal1",
	&"FlowerPetal2",
]

## Landmark colours, LOCAL to the hub for the same reason as the flower
## tints above -- decor, not the identity SwampPalette carries.
##
## Deliberately LIGHT. A landmark's top pokes just above the horizon line
## (the camera's -34 deg pitch leaves the top of the frame ~2.4 deg above
## horizontal), so it is read against the sky, and the sky here is the
## near-black swamp green. A dark silhouette against a dark sky is not a
## landmark, it is a hole.
const LANDMARK_SPIRE_TRUNK: Color = Color(0.15, 0.10, 0.06)
const LANDMARK_SPIRE_CROWN: Color = Color(0.38, 0.58, 0.30)
const LANDMARK_CAIRN_STONE: Color = Color(0.44, 0.45, 0.40)
const LANDMARK_CAIRN_CAP: Color = Color(0.56, 0.56, 0.50)
const LANDMARK_SLAB_STONE: Color = Color(0.36, 0.44, 0.32)
const LANDMARK_SLAB_BASE: Color = Color(0.26, 0.30, 0.23)

var _portals: Array[HubPortal] = []

## Batch key -> {"mesh": Mesh, "colour": Color, "xforms": Array[Transform3D]}.
## Filled while the layout is walked, drained once at the end by
## _flush_batches(); a batch nothing landed in is never created.
var _batches: Dictionary = {}

## Batch keys in first-seen order, so the child order of the MultiMesh
## nodes follows the layout rather than Dictionary iteration order.
var _batch_order: Array[StringName] = []

func _ready() -> void:
	assert(_FLOWER_PETAL_KEYS.size() == FLOWER_PETAL_COLORS.size(),
		"HubBuilder: a corolla tint has no batch key, or the reverse.")
	_build()

## Every portal built, in layout order. HubWorld connects them after the
## build rather than the builder knowing what a portal is wired to.
func portals() -> Array[HubPortal]:
	return _portals

func _build() -> void:
	if layout == null:
		push_error("HubBuilder: no layout assigned, plateau will be empty.")
		return
	for index in layout.props.size():
		var entry: Dictionary = layout.props[index]
		var type: StringName = entry.get("type", &"")
		var where: Vector3 = entry.get("position", Vector3.ZERO)
		var rotation_y: float = entry.get("rotation_y", 0.0)
		var uniform: float = entry.get("scale", 1.0)

		# The transform the prop's root node WOULD have had. Composed by
		# hand because a batched instance has no node to read it off --
		# and it is exact rather than approximate because the layout's
		# scale is a UNIFORM float: rotation and uniform scale commute, so
		# there is no ambiguity about which side Node3D applies the scale.
		# Asserted against a real node, not argued: see the batch's probe.
		var placement := Transform3D(
			Basis.from_euler(Vector3(0.0, deg_to_rad(rotation_y), 0.0)).scaled(Vector3.ONE * uniform),
			where)

		var node: Node3D = null
		if not _batch_prop(type, entry, placement):
			match type:
				&"portal":
					node = _make_portal(entry, index)
				&"landmark":
					node = _make_landmark(entry)
				_:
					push_error("HubBuilder: entry %d has unknown type '%s', skipped." % [index, type])
					continue
			if node == null:
				continue

		# A prop outside the tap clamp is drawn but can never be walked to.
		# Not fatal -- distant scenery is a legitimate thing to want -- so
		# warn and keep it rather than dropping it. The bound is READ from
		# HubTapInput, never copied: two copies of a play-area limit is how
		# they drift apart.
		#
		# This reads the LAYOUT, never the scene tree, which is why
		# batching changed nothing about it. It stays AFTER the type is
		# known good so an unknown type still produces one error and no
		# warning, exactly as before.
		var bound: float = HubTapInput.PLATEAU_HALF_EXTENT
		if absf(where.x) > bound or absf(where.z) > bound:
			push_warning("HubBuilder: entry %d ('%s') at %s is outside the +-%.1f plateau; visible but unreachable." % [index, type, where, bound])

		if node != null:
			node.position = where
			node.rotation_degrees = Vector3(0.0, rotation_y, 0.0)
			node.scale = Vector3.ONE * uniform
			add_child(node)
	_flush_batches()

## Files a scatter prop into its batches. Returns false for a type that
## wants a node of its own, which is the caller's cue to fall through to
## the match.
func _batch_prop(type: StringName, entry: Dictionary, placement: Transform3D) -> bool:
	match type:
		&"tree":
			_instance(&"TreeTrunk", placement.translated_local(Vector3(0.0, 0.75, 0.0)))
			_instance(&"TreeCrown", placement.translated_local(Vector3(0.0, 2.0, 0.0)))
		&"rock":
			_instance(&"Rock", placement.translated_local(Vector3(0.0, 0.28, 0.0)))
		&"bush":
			# Two lobes, ONE mesh: two instances of a single batch.
			_instance(&"Bush", placement.translated_local(Vector3(0.0, 0.3, 0.0)))
			_instance(&"Bush", placement.translated_local(Vector3(0.42, 0.2, 0.18)))
		&"flower":
			_instance(&"FlowerStem", placement.translated_local(Vector3(0.0, 0.21, 0.0)))
			var variant: int = entry.get("variant", 0)
			if variant < 0 or variant >= FLOWER_PETAL_COLORS.size():
				variant = 0
			_instance(_FLOWER_PETAL_KEYS[variant], placement.translated_local(Vector3(0.0, 0.44, 0.0)))
		_:
			return false
	return true

func _instance(key: StringName, xform: Transform3D) -> void:
	if not _batches.has(key):
		var spec: Array = _batch_spec(key)
		var xforms: Array[Transform3D] = []
		_batches[key] = {"mesh": spec[0], "colour": spec[1], "xforms": xforms}
		_batch_order.append(key)
	_batches[key]["xforms"].append(xform)

## The (mesh, colour) pair a batch key stands for. Built once per key, on
## first use -- the whole point of a MultiMesh is that 39 trees share one
## trunk mesh rather than owning 39 copies of it.
##
## Godot's default tessellation on a primitive is far denser than any
## silhouette this size needs -- the same trap docs/MESHY_SPEC.md 7.2
## caught on the collectibles. Set explicitly rather than inherited.
func _batch_spec(key: StringName) -> Array:
	match key:
		&"TreeTrunk":
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.16
			trunk.bottom_radius = 0.24
			trunk.height = 1.5
			trunk.radial_segments = 8
			trunk.rings = 1
			return [trunk, TRUNK_COLOR]
		&"TreeCrown":
			var crown := SphereMesh.new()
			crown.radius = 0.95
			crown.height = 1.7
			crown.radial_segments = 10
			crown.rings = 5
			return [crown, CROWN_COLOR]
		&"Rock":
			var rock := SphereMesh.new()
			rock.radius = 0.6
			rock.height = 0.8
			rock.radial_segments = 8
			rock.rings = 4
			return [rock, ROCK_COLOR]
		&"Bush":
			var bush := SphereMesh.new()
			bush.radius = 0.5
			bush.height = 0.7
			bush.radial_segments = 8
			bush.rings = 4
			return [bush, BUSH_COLOR]
		&"FlowerStem":
			var stem := CylinderMesh.new()
			stem.top_radius = 0.025
			stem.bottom_radius = 0.035
			stem.height = 0.42
			stem.radial_segments = 6
			stem.rings = 1
			return [stem, FLOWER_STEM_COLOR]
		_:
			var tint: int = _FLOWER_PETAL_KEYS.find(key)
			if tint < 0:
				push_error("HubBuilder: no mesh known for batch key '%s'." % key)
				return [SphereMesh.new(), Color.MAGENTA]
			var petal := SphereMesh.new()
			petal.radius = 0.15
			petal.height = 0.14
			petal.radial_segments = 8
			petal.rings = 3
			return [petal, FLOWER_PETAL_COLORS[tint]]

## Turns every filled batch into one MultiMeshInstance3D.
func _flush_batches() -> void:
	for key in _batch_order:
		var batch: Dictionary = _batches[key]
		var xforms: Array = batch["xforms"]
		if xforms.is_empty():
			continue
		var mesh: Mesh = batch["mesh"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = xforms.size()
		var bounds := AABB()
		var local_aabb: AABB = mesh.get_aabb()
		for i in xforms.size():
			var xform: Transform3D = xforms[i]
			multi.set_instance_transform(i, xform)
			var box: AABB = xform * local_aabb
			bounds = box if i == 0 else bounds.merge(box)
		# A MultiMesh derives an AABB of its own, and a wrong or stale one
		# makes the entire batch vanish when the camera turns -- a failure
		# with no error attached to it, on a screen no one can look at
		# before staging. The exact union is cheap to compute right here,
		# so it is written rather than trusted.
		multi.custom_aabb = bounds

		var node := MultiMeshInstance3D.new()
		node.name = String(key)
		node.multimesh = multi
		# material_override rather than a material on the mesh: the mesh is
		# shared by every instance in the batch, and this keeps the colour
		# on the node that draws it, next to the instances it applies to.
		node.material_override = _unshaded(batch["colour"])
		add_child(node)

func _make_portal(entry: Dictionary, index: int) -> Node3D:
	if portal_scene == null:
		push_error("HubBuilder: entry %d is a portal but no portal_scene is assigned." % index)
		return null
	var portal := portal_scene.instantiate() as HubPortal
	if portal == null:
		push_error("HubBuilder: portal_scene does not instantiate to a HubPortal.")
		return null
	portal.game_id = entry.get("game_id", &"")
	var label_node := portal.get_node_or_null("Label") as Label3D
	if label_node:
		label_node.text = entry.get("label", "")
	_portals.append(portal)
	return portal
## An orientation marker, readable from the far side of the plateau.
##
## ~8.4 units tall against a standard tree's 2.85 -- roughly 3x, which is
## what buys it back over the tree field at 25+ units. Height alone is not
## enough though: a tree scaled up is still tree-shaped and reads as more
## of the same, so each variant is a DIFFERENT SILHOUETTE (a needle, a
## blocky pile, a pair of standing slabs). Telling one landmark from
## another at a glance is what carries orientation; merely having four of
## them does not.
##
## "variant" picks the silhouette, same mechanism as flower -- out of
## range falls back to 0 so a layout written without the field still
## builds.
func _make_landmark(entry: Dictionary) -> Node3D:
	var variant: int = entry.get("variant", 0)
	match variant:
		1:
			return _make_landmark_cairn()
		2:
			return _make_landmark_slabs()
		_:
			return _make_landmark_spire()

## Variant 0 -- a narrow needle. Distinguished at distance by being thin.
func _make_landmark_spire() -> Node3D:
	var root := Node3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.42
	trunk.height = 5.2
	trunk.radial_segments = 8
	trunk.rings = 1
	root.add_child(_mesh_node(trunk, LANDMARK_SPIRE_TRUNK, Vector3(0.0, 2.6, 0.0)))
	# Cones are CylinderMesh with a zero top radius; three stacked ones
	# give the stepped conifer edge a single cone cannot.
	var tiers: Array = [[1.25, 2.4, 5.0], [0.95, 2.1, 6.3], [0.62, 1.8, 7.55]]
	for tier in tiers:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tier[0]
		cone.height = tier[1]
		cone.radial_segments = 8
		cone.rings = 1
		root.add_child(_mesh_node(cone, LANDMARK_SPIRE_CROWN, Vector3(0.0, tier[2], 0.0)))
	return root

## Variant 1 -- a blocky stacked mass. The opposite read to the spire:
## wide, stepped, and grey rather than green.
func _make_landmark_cairn() -> Node3D:
	var root := Node3D.new()
	var blocks: Array = [
		[Vector3(2.60, 1.50, 2.40), 0.75, 0.0, LANDMARK_CAIRN_STONE],
		[Vector3(2.10, 1.70, 1.90), 2.30, 22.0, LANDMARK_CAIRN_STONE],
		[Vector3(1.55, 1.90, 1.45), 4.00, -18.0, LANDMARK_CAIRN_STONE],
		[Vector3(1.05, 1.50, 0.95), 5.60, 35.0, LANDMARK_CAIRN_CAP],
	]
	for block in blocks:
		var box := BoxMesh.new()
		box.size = block[0]
		root.add_child(_mesh_node(box, block[3], Vector3(0.0, block[1], 0.0), Vector3(0.0, block[2], 0.0)))
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.55
	spike.height = 2.2
	spike.radial_segments = 6
	spike.rings = 1
	root.add_child(_mesh_node(spike, LANDMARK_CAIRN_CAP, Vector3(0.0, 7.3, 0.0)))
	return root

## Variant 2 -- two standing slabs of unequal height. Reads as a pair of
## vertical bars, which neither of the other two can be mistaken for.
func _make_landmark_slabs() -> Node3D:
	var root := Node3D.new()
	var rubble := BoxMesh.new()
	rubble.size = Vector3(2.90, 0.70, 1.90)
	root.add_child(_mesh_node(rubble, LANDMARK_SLAB_BASE, Vector3(0.0, 0.35, 0.0), Vector3(0.0, 6.0, 0.0)))
	var tall := BoxMesh.new()
	tall.size = Vector3(1.15, 8.00, 0.60)
	root.add_child(_mesh_node(tall, LANDMARK_SLAB_STONE, Vector3(-0.85, 4.00, 0.10), Vector3(0.0, 12.0, -4.0)))
	var short := BoxMesh.new()
	short.size = Vector3(0.95, 6.60, 0.50)
	root.add_child(_mesh_node(short, LANDMARK_SLAB_STONE, Vector3(0.90, 3.30, -0.15), Vector3(0.0, -18.0, 5.0)))
	return root

func _mesh_node(mesh: Mesh, colour: Color, offset: Vector3, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = offset
	node.rotation_degrees = rotation_deg
	node.set_surface_override_material(0, _unshaded(colour))
	return node

## The one material this file ever makes. UNSHADED is the project's
## standing rule for every surface (see the header), and having a single
## factory is what keeps a batched prop's material identical to the
## individual-node one it replaced.
func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material
