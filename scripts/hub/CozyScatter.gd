extends Node3D
class_name CozyScatter
## Ground cover and the forest wall, placed BY CODE from a seed, never by
## hand (carte-blanche brief). Sits under World after Props in
## HubWorld.tscn so HubBuilder has built and published its footprints,
## water centres and stream spine before this runs.
##
## Everything here is decoration with no collision and no tap channel: a
## tuft of grass under Keepy's feet is exactly what Animal Crossing does.
## It only avoids what would look wrong -- water surfaces, the props'
## own footprints, and the spawn.
##
## BATCHING. Ground cover is grouped per CELL (CELL u squares) and per
## family so the engine can frustum-cull a whole cell: one MultiMesh of
## every tuft on the plateau would be drawn in full whatever the camera
## sees. One GLB variant per family per cell keeps the node count down;
## the variant changes from cell to cell so the repetition is not visible.

const SEED: int = 20260905
const CELL: float = 28.0
## Plateau bounds to cover with ground cover: the walkable square plus the
## north lobe, i.e. every place Keepy can stand.
const COVER_MIN: Vector2 = Vector2(-37.0, -37.0)
const COVER_MAX: Vector2 = Vector2(37.0, 47.0)
## Forest wall annulus around the square. Inner radius is measured from
## the region: a candidate closer than WALL_CLEARANCE to walkable ground is
## dropped so no canopy hangs over a place Keepy can walk to.
const WALL_OUTER: float = 62.0
const WALL_CLEARANCE: float = 2.0
const WALL_NEAR_BAND: float = 8.0
## Densities, per square unit of eligible ground.
const GRASS_PER_U2: float = 0.34
const FLOWER_PER_U2: float = 0.032
const CLUTTER_PER_U2: float = 0.030
const MUSHROOM_PER_U2: float = 0.006
const EXTRA_BUSH_PER_U2: float = 0.004
const EXTRA_ROCK_PER_U2: float = 0.004
const WALL_NEAR_PER_U2: float = 0.055
const WALL_FAR_PER_U2: float = 0.028
## Keep the spawn readable: nothing taller than grass within this radius.
const SPAWN_CLEAR_RADIUS: float = 2.2
## Margin added to every prop footprint and water disc.
const MARGIN: float = 0.35

var _builder: HubBuilder = null
var _footprints: Array = []
var _water: Array = []
var _spine: Array = []
var _spine_half: float = 0.0
var _rng := RandomNumberGenerator.new()
var _batches: Dictionary = {}
var _batch_order: Array[String] = []
var _stats: Dictionary = {}

func _ready() -> void:
	_builder = get_parent().get_node_or_null("Props") as HubBuilder
	if _builder == null:
		push_error("CozyScatter: no HubBuilder sibling named Props.")
		return
	_rng.seed = SEED
	_footprints = _builder.ground_footprints()
	_collect_water()
	_paint_ground()
	_scatter_ground_cover()
	_forest_wall()
	_flush()
	_blob_shadows()
	_hills()

## Swaps the flat ground material for the cozy ground shader. The Ground
## node is a sibling owned by HubWorld.tscn; only its material changes.
func _paint_ground() -> void:
	var ground := get_parent().get_node_or_null("Ground") as MeshInstance3D
	if ground == null:
		push_error("CozyScatter: no Ground sibling.")
		return
	ground.set_surface_override_material(0, CozyPalette.ground_material())

func _collect_water() -> void:
	_water = []
	var pond := _builder.pond_centre()
	if pond != Vector3.INF:
		_water.append({"centre": Vector3(pond.x, 0.0, pond.z), "radius": HubBuilder.POND_BANK_RADIUS})
	var lake := _builder.small_lake_centre()
	if lake != Vector3.INF:
		_water.append({"centre": Vector3(lake.x, 0.0, lake.z), "radius": HubBuilder.LAKE_BANK_RADIUS})
	for entry in HubRegion.lakes():
		var c: Vector3 = entry["centre"]
		_water.append({"centre": Vector3(c.x, 0.0, c.z), "radius": float(entry["radius"]) + HubBuilder.GREATLAKE_BANK_MARGIN})
	_spine = _builder.stream_spine()
	_spine_half = _builder.stream_half_width()

func _blocked(p: Vector3, own_radius: float) -> bool:
	for w in _water:
		if p.distance_to(w["centre"]) < float(w["radius"]) + own_radius + MARGIN:
			return true
	for f in _footprints:
		if p.distance_to(f["position"]) < float(f["radius"]) + own_radius + MARGIN:
			return true
	if _spine.size() > 1:
		for i in _spine.size() - 1:
			var a: Vector3 = _spine[i]
			var b: Vector3 = _spine[i + 1]
			var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, a.y, p.z), a, b)
			if Vector2(q.x, q.z).distance_to(Vector2(p.x, p.z)) < _spine_half + own_radius + MARGIN + 0.3:
				return true
	return false

func _on_islet(p: Vector3) -> bool:
	for islet in _builder.islets():
		if p.distance_to(islet["centre"]) < float(islet["radius"]) - 0.4:
			return true
	return false

## Families with a handful of pieces are one batch for the whole plateau;
## the numerous ones are split per cell so a cell out of frame costs nothing.
const GLOBAL_FAMILIES: Array[String] = ["bush", "rock", "mushroom"]

func _cell_key(p: Vector3) -> String:
	return "%d_%d" % [floori(p.x / CELL), floori(p.z / CELL)]

func _batch_cell(family: String, p: Vector3) -> String:
	return "all" if family in GLOBAL_FAMILIES else _cell_key(p)

func _cell_variant(p: Vector3, count: int, salt: int) -> int:
	return posmod(hash(_cell_key(p)) + salt, count)

func _scatter_ground_cover() -> void:
	var area := (COVER_MAX.x - COVER_MIN.x) * (COVER_MAX.y - COVER_MIN.y)
	# Grass tufts: allowed under everything but water and the tall props.
	_sprinkle("grass", 3, int(area * GRASS_PER_U2), 0.0, 0.7, 1.15, true, 0.05)
	_sprinkle("flower", 4, int(area * FLOWER_PER_U2), 0.15, 1.3, 1.9, true, 0.03)
	_sprinkle("leaf", 3, int(area * CLUTTER_PER_U2), 0.1, 1.2, 1.8, false, 0.0)
	_sprinkle("pebble", 2, int(area * CLUTTER_PER_U2 * 0.6), 0.12, 1.0, 1.8, false, 0.0)
	_sprinkle("mushroom", 2, int(area * MUSHROOM_PER_U2), 0.2, 1.1, 1.6, false, 0.0)
	_sprinkle("bush", 3, int(area * EXTRA_BUSH_PER_U2), 0.8, 0.7, 1.1, false, 0.0)
	_sprinkle("rock", 4, int(area * EXTRA_ROCK_PER_U2), 0.7, 0.6, 1.1, false, 0.0)

## Drops `count` candidates of `family` over the cover area; each survivor
## joins the batch of its cell. `own_radius` is what the piece reserves
## against props and water; `keep_spawn` also empties the spawn disc.
func _sprinkle(family: String, variants: int, count: int, own_radius: float,
		scale_min: float, scale_max: float, allow_islets: bool, wind: float) -> void:
	var placed := 0
	for i in count:
		var p := Vector3(_rng.randf_range(COVER_MIN.x, COVER_MAX.x), 0.0, _rng.randf_range(COVER_MIN.y, COVER_MAX.y))
		if not HubRegion.contains(p):
			continue
		if HubRegion.in_lake_water(p) and not (allow_islets and _on_islet(p)):
			continue
		if _blocked(p, own_radius):
			continue
		if own_radius > 0.1 and p.length() < SPAWN_CLEAR_RADIUS:
			continue
		var variant := _rng.randi_range(0, variants - 1) if family in GLOBAL_FAMILIES else _cell_variant(p, variants, hash(family))
		var name := "%s_%d" % [family, variant]
		var s := _rng.randf_range(scale_min, scale_max)
		var yaw := _rng.randf_range(0.0, TAU)
		var xform := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3.ONE * s), p)
		_add(family, name, _batch_cell(family, p), xform, wind, 0.45 if family == "grass" else 0.3)
		placed += 1
	_stats[family] = placed

## Trees outside the region: a near band of full-detail round trees where
## the wall meets the plateau, and a far band of the cheap LOD behind it.
## South of z = 50 nothing is placed: the camera sits north of Keepy
## looking south (toward -z), so that side is never in frame.
func _forest_wall() -> void:
	var near_kinds := ["tree_0_round", "tree_1_round", "tree_2_round", "tree_5_round", "tree_3_tall", "tree_4_conifer"]
	var far_kind := "tree_6_far"
	var placed_near := 0
	var placed_far := 0
	var box_area := (2.0 * WALL_OUTER) * (2.0 * WALL_OUTER)
	for i in int(box_area * WALL_FAR_PER_U2):
		var p := Vector3(_rng.randf_range(-WALL_OUTER, WALL_OUTER), 0.0, _rng.randf_range(-WALL_OUTER, 50.0))
		if HubRegion.contains(p) or _near_region(p, WALL_CLEARANCE):
			continue
		if _blocked(p, 1.2):
			continue
		var near := _near_region(p, WALL_NEAR_BAND)
		var s := _rng.randf_range(0.9, 1.35)
		var yaw := _rng.randf_range(0.0, TAU)
		var xform := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3.ONE * s), p)
		if near:
			# Denser near band: every candidate lands, plus extra throws.
			_add("wall_near", _wall_kind(p, near_kinds), _wall_sector(p), xform, 0.04, 3.0)
			placed_near += 1
		else:
			_add("wall_far", far_kind, _wall_sector(p), xform, 0.0, 3.0)
			placed_far += 1
	# Second pass to thicken the near band to WALL_NEAR_PER_U2.
	for i in int(box_area * (WALL_NEAR_PER_U2 - WALL_FAR_PER_U2)):
		var p := Vector3(_rng.randf_range(-WALL_OUTER, WALL_OUTER), 0.0, _rng.randf_range(-WALL_OUTER, 50.0))
		if HubRegion.contains(p) or _near_region(p, WALL_CLEARANCE) or not _near_region(p, WALL_NEAR_BAND):
			continue
		if _blocked(p, 1.2):
			continue
		var s := _rng.randf_range(0.9, 1.35)
		var yaw := _rng.randf_range(0.0, TAU)
		var xform := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3.ONE * s), p)
		_add("wall_near", _wall_kind(p, near_kinds), _wall_sector(p), xform, 0.04, 3.0)
		placed_near += 1
	_stats["wall_near"] = placed_near
	_stats["wall_far"] = placed_far

const WALL_SECTORS: int = 6

func _wall_sector(p: Vector3) -> String:
	return "wall_%d" % posmod(int(floor(atan2(p.z, p.x) / TAU * WALL_SECTORS)), WALL_SECTORS)

## Two GLB kinds per sector (chosen from the sector's hash, then per tree),
## so a sector is two batches rather than six.
func _wall_kind(p: Vector3, kinds: Array) -> String:
	var base: int = posmod(hash(_wall_sector(p)), kinds.size())
	var pick: int = (base + (_rng.randi_range(0, 1) * 3)) % kinds.size()
	return kinds[pick]

## Blob shadows under everything that stands: the layout's trees, bushes,
## rocks, stumps and landmarks (read from the layout, the same reading
## ground_footprints() makes) and this file's own wall trees and extra
## bushes / rocks. One MultiMesh of 2-triangle quads, alpha-blended,
## offset a little away from the sun so they read as cast rather than
## painted.
const SHADOW_RADIUS: Dictionary = {
	&"tree": 1.25, &"bush": 0.80, &"rock": 0.75, &"stump": 0.55, &"landmark": 1.7,
}
const SHADOW_Y: float = 0.02
const SHADOW_OFFSET: Vector2 = Vector2(-0.22, -0.28)

var _shadow_xforms: Array[Transform3D] = []

func _shadow_at(p: Vector3, radius: float) -> void:
	var basis := Basis().scaled(Vector3(radius * 2.0, 1.0, radius * 2.0))
	var origin := Vector3(p.x + SHADOW_OFFSET.x * radius, SHADOW_Y, p.z + SHADOW_OFFSET.y * radius)
	_shadow_xforms.append(Transform3D(basis, origin))

func _blob_shadows() -> void:
	if _builder.layout != null:
		for entry in _builder.layout.props:
			var type: StringName = entry.get("type", &"")
			if not SHADOW_RADIUS.has(type):
				continue
			var where: Vector3 = entry.get("position", Vector3.ZERO)
			# Islet landmarks stand on water: their disc would float on the
			# lake. Landmarks flagged offshore are skipped.
			if entry.get("offshore", false):
				continue
			_shadow_at(Vector3(where.x, 0.0, where.z), float(SHADOW_RADIUS[type]) * float(entry.get("scale", 1.0)))
	for key in _batch_order:
		var batch: Dictionary = _batches[key]
		var family: String = batch["family"]
		var radius := 0.0
		match family:
			"wall_near": radius = 1.25
			"wall_far": radius = 1.25
			"bush": radius = 0.8
			"rock": radius = 0.75
			_: continue
		for xform in batch["xforms"]:
			var t: Transform3D = xform
			_shadow_at(t.origin, radius * t.basis.get_scale().x)
	if _shadow_xforms.is_empty():
		return
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = _shadow_xforms.size()
	var bounds := AABB()
	for i in _shadow_xforms.size():
		multi.set_instance_transform(i, _shadow_xforms[i])
		var box := _shadow_xforms[i] * quad.get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
	multi.custom_aabb = bounds.grow(0.1)
	var node := MultiMeshInstance3D.new()
	node.name = "BlobShadows"
	node.multimesh = multi
	node.material_override = CozyPalette.shadow_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_stats["shadows"] = _shadow_xforms.size()

## Distant rounded hills behind the forest wall: the horizon band at the
## top of the frame reads as a landscape instead of a flat sky colour.
## Squashed spheres, toon-tinted, mostly dissolved by the haze -- what is
## left is a soft silhouette, which is the point. South of z = 50 nothing.
const HILL_COUNT: int = 26
const HILL_COLOR: Color = Color(0.60, 0.80, 0.50)

func _hills() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 14
	sphere.rings = 7
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = sphere
	var xforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	var tries := 0
	while xforms.size() < HILL_COUNT and tries < HILL_COUNT * 20:
		tries += 1
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(78.0, 118.0)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		if p.z > 50.0:
			continue
		var sx := rng.randf_range(22.0, 40.0)
		var sy := rng.randf_range(7.0, 13.0)
		var sz := rng.randf_range(18.0, 34.0)
		var basis := Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3(sx, sy, sz))
		xforms.append(Transform3D(basis, Vector3(p.x, -sy * 0.35, p.z)))
	multi.instance_count = xforms.size()
	var bounds := AABB()
	for i in xforms.size():
		multi.set_instance_transform(i, xforms[i])
		var box := xforms[i] * sphere.get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
	multi.custom_aabb = bounds
	var node := MultiMeshInstance3D.new()
	node.name = "Hills"
	node.multimesh = multi
	node.material_override = CozyPalette.decor_material_tinted(HILL_COLOR)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_stats["hills"] = xforms.size()

## True when any point within `radius` of p is walkable: eight samples on
## the circle plus the centre. Cheap, and conservative enough for a wall.
func _near_region(p: Vector3, radius: float) -> bool:
	if HubRegion.contains(p):
		return true
	for k in 8:
		var a := TAU * k / 8.0
		if HubRegion.contains(p + Vector3(cos(a) * radius, 0.0, sin(a) * radius)):
			return true
	return false

func _add(family: String, mesh_name: String, cell: String, xform: Transform3D, wind: float, wind_height: float) -> void:
	var key := "%s|%s|%s" % [family, mesh_name, cell]
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh_name, "xforms": [], "wind": wind, "wind_height": wind_height, "family": family}
		_batch_order.append(key)
	_batches[key]["xforms"].append(xform)

func _flush() -> void:
	var nodes := 0
	var instances := 0
	for key in _batch_order:
		var batch: Dictionary = _batches[key]
		var xforms: Array = batch["xforms"]
		if xforms.is_empty():
			continue
		var mesh: Mesh = CozyPalette.glb_mesh(CozyPalette.decor_path(batch["mesh"]))
		if mesh == null:
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = mesh
		multi.instance_count = xforms.size()
		var bounds := AABB()
		var local_aabb: AABB = mesh.get_aabb()
		for i in xforms.size():
			var xform: Transform3D = xforms[i]
			multi.set_instance_transform(i, xform)
			multi.set_instance_color(i, CozyPalette.tint(hash(key) + i * 7919, 0.07))
			var box: AABB = xform * local_aabb
			bounds = box if i == 0 else bounds.merge(box)
		# Wind moves vertices past the rest AABB: grow it by the amplitude.
		bounds = bounds.grow(float(batch["wind"]) + 0.05)
		multi.custom_aabb = bounds
		var node := MultiMeshInstance3D.new()
		node.name = key.replace("|", "_")
		node.multimesh = multi
		var wind: float = batch["wind"]
		node.material_override = CozyPalette.decor_material_wind(wind, float(batch["wind_height"])) if wind > 0.0 else CozyPalette.decor_material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		nodes += 1
		instances += xforms.size()
	_stats["batches"] = nodes
	_stats["instances"] = instances
	print("CozyScatter: " + JSON.stringify(_stats))

func stats() -> Dictionary:
	return _stats
