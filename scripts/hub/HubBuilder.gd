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
const FLOWER_PETAL_COLORS: Array[Color] = [
	Color(0.93, 0.86, 0.42),
	Color(0.86, 0.52, 0.62),
	Color(0.72, 0.66, 0.88),
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

func _ready() -> void:
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
		var node: Node3D = null
		match type:
			&"portal":
				node = _make_portal(entry, index)
			&"tree":
				node = _make_tree()
			&"rock":
				node = _make_rock()
			&"bush":
				node = _make_bush()
			&"flower":
				node = _make_flower(entry)
			&"landmark":
				node = _make_landmark(entry)
			_:
				push_error("HubBuilder: entry %d has unknown type '%s', skipped." % [index, type])
				continue
		if node == null:
			continue
		var where: Vector3 = entry.get("position", Vector3.ZERO)
		# A prop outside the tap clamp is drawn but can never be walked to.
		# Not fatal -- distant scenery is a legitimate thing to want -- so
		# warn and keep it rather than dropping it. The bound is READ from
		# HubTapInput, never copied: two copies of a play-area limit is how
		# they drift apart.
		var bound: float = HubTapInput.PLATEAU_HALF_EXTENT
		if absf(where.x) > bound or absf(where.z) > bound:
			push_warning("HubBuilder: entry %d ('%s') at %s is outside the +-%.1f plateau; visible but unreachable." % [index, type, where, bound])
		node.position = where
		node.rotation_degrees = Vector3(0.0, entry.get("rotation_y", 0.0), 0.0)
		var uniform: float = entry.get("scale", 1.0)
		node.scale = Vector3.ONE * uniform
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

func _make_tree() -> Node3D:
	var root := Node3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = 1.5
	# Godot's default tessellation on a primitive is far denser than any
	# silhouette this size needs -- the same trap docs/MESHY_SPEC.md 7.2
	# caught on the collectibles. Set explicitly rather than inherited.
	trunk_mesh.radial_segments = 8
	trunk_mesh.rings = 1
	root.add_child(_mesh_node(trunk_mesh, TRUNK_COLOR, Vector3(0.0, 0.75, 0.0)))

	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.95
	crown_mesh.height = 1.7
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 5
	root.add_child(_mesh_node(crown_mesh, CROWN_COLOR, Vector3(0.0, 2.0, 0.0)))
	return root

func _make_rock() -> Node3D:
	var root := Node3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 0.8
	mesh.radial_segments = 8
	mesh.rings = 4
	root.add_child(_mesh_node(mesh, ROCK_COLOR, Vector3(0.0, 0.28, 0.0)))
	return root

func _make_bush() -> Node3D:
	var root := Node3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 0.7
	mesh.radial_segments = 8
	mesh.rings = 4
	root.add_child(_mesh_node(mesh, BUSH_COLOR, Vector3(0.0, 0.3, 0.0)))
	root.add_child(_mesh_node(mesh, BUSH_COLOR, Vector3(0.42, 0.2, 0.18)))
	return root

func _make_flower(entry: Dictionary) -> Node3D:
	var root := Node3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.025
	stem_mesh.bottom_radius = 0.035
	stem_mesh.height = 0.42
	stem_mesh.radial_segments = 6
	stem_mesh.rings = 1
	root.add_child(_mesh_node(stem_mesh, FLOWER_STEM_COLOR, Vector3(0.0, 0.21, 0.0)))

	var petal_mesh := SphereMesh.new()
	petal_mesh.radius = 0.15
	petal_mesh.height = 0.14
	petal_mesh.radial_segments = 8
	petal_mesh.rings = 3
	var variant: int = entry.get("variant", 0)
	if variant < 0 or variant >= FLOWER_PETAL_COLORS.size():
		variant = 0
	root.add_child(_mesh_node(petal_mesh, FLOWER_PETAL_COLORS[variant], Vector3(0.0, 0.44, 0.0)))
	return root

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
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	node.set_surface_override_material(0, material)
	return node
