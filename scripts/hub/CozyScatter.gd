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
	_paths()
	_portal_beds()
	_scatter_ground_cover()
	_forest_wall()
	_flush()
	_blob_shadows()
	_hills()
	_clouds()
	_butterflies()
	_hero_shadow()

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
	if _on_path(p, own_radius):
		return true
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

## Dirt paths from the spawn to the three portals and to the cabin door:
## the plateau gets a composition, and the player a hint of where to go.
## Flat ribbons just above the ground (below the water banks), sampled
## along a bent curve with wavy edges so they read hand-worn. Ground
## cover is kept off them (see _blocked).
const PATH_HALF: float = 0.85
const PATH_Y: float = 0.03
const PATH_SAMPLES: int = 22
const PATH_STOP: float = 1.6
const PLAZA_RADIUS: float = 2.3
var _path_lines: Array = []

func _paths() -> void:
	var targets: Array[Vector3] = []
	for portal in _builder.portals():
		targets.append((portal as Node3D).global_position)
	for cabin in _builder.cabins():
		targets.append(cabin["door"])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 17
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A worn disc at the spawn the paths leave from. Slightly LOWER than
	# the ribbons so the join never z-fights (measured on capture 11: four
	# coplanar ribbons overlapping at the spawn drew as hatched spikes).
	var plaza_segments := 24
	for i in plaza_segments:
		var a0 := TAU * i / plaza_segments
		var a1 := TAU * (i + 1) / plaza_segments
		var r0 := PLAZA_RADIUS * (1.0 + 0.06 * sin(a0 * 3.0))
		var r1 := PLAZA_RADIUS * (1.0 + 0.06 * sin(a1 * 3.0))
		# Winding matches the ribbons' (front face up): the reverse order
		# drew the disc back-facing, i.e. in the shader's shade band.
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(0.0, PATH_Y - 0.004, 0.0))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a0) * r0, PATH_Y - 0.004, sin(a0) * r0))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a1) * r1, PATH_Y - 0.004, sin(a1) * r1))
	var built := 0
	for target in targets:
		var a := Vector3.ZERO
		var b := Vector3(target.x, 0.0, target.z)
		var dir := (b - a)
		if dir.length() < PATH_STOP + PLAZA_RADIUS + 1.0:
			continue
		var length := dir.length()
		dir = dir / length
		b = b - dir * PATH_STOP
		a = a + dir * (PLAZA_RADIUS - 0.5)
		var side := Vector3(-dir.z, 0.0, dir.x)
		var mid := (a + b) * 0.5 + side * rng.randf_range(-0.10, 0.10) * length
		var samples: Array[Vector3] = []
		for i in PATH_SAMPLES + 1:
			var t := float(i) / PATH_SAMPLES
			var q := a.lerp(mid, t).lerp(mid.lerp(b, t), t)
			samples.append(q)
		_path_lines.append(samples)
		var phase := rng.randf_range(0.0, TAU)
		# Per-SAMPLE edge points, shared by the two quads that meet there.
		# A per-segment normal gave every joint two different edge vertices,
		# so on every bend consecutive quads overlapped as coplanar
		# triangles and z-fought in thin hatch lines (captures 11-14).
		var left: Array[Vector3] = []
		var right: Array[Vector3] = []
		for i in PATH_SAMPLES + 1:
			var prev: Vector3 = samples[max(i - 1, 0)]
			var next: Vector3 = samples[min(i + 1, PATH_SAMPLES)]
			var tan := (next - prev).normalized()
			var n := Vector3(-tan.z, 0.0, tan.x)
			var w := PATH_HALF * (1.0 + 0.14 * sin(i * 0.55 + phase))
			var c: Vector3 = samples[i]
			left.append(Vector3(c.x + n.x * w, PATH_Y, c.z + n.z * w))
			right.append(Vector3(c.x - n.x * w, PATH_Y, c.z - n.z * w))
		for i in PATH_SAMPLES:
			for v in [left[i], right[i], left[i + 1], right[i + 1], left[i + 1], right[i]]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		built += 1
	var mesh := st.commit()
	var node := MeshInstance3D.new()
	node.name = "Paths"
	node.mesh = mesh
	node.material_override = CozyPalette.decor_material_tinted(CozyPalette.PATH)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_stats["paths"] = built

func _on_path(p: Vector3, own_radius: float) -> bool:
	if Vector2(p.x, p.z).length() < PLAZA_RADIUS * 1.1 + own_radius:
		return true
	for line in _path_lines:
		var samples: Array = line
		for i in samples.size() - 1:
			var q := Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0.0, p.z), samples[i], samples[i + 1])
			if Vector2(q.x, q.z).distance_to(Vector2(p.x, p.z)) < PATH_HALF * 1.2 + own_radius:
				return true
	return false

## Flower beds around the three portals: a ring of flowers just outside
## each ring's footprint, one colour per portal.
const BED_RADIUS: float = 2.05
const BED_COUNT: int = 13

func _portal_beds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 19
	var index := 0
	for portal in _builder.portals():
		var c: Vector3 = (portal as Node3D).global_position
		var variant := index % 4
		for k in BED_COUNT:
			var a := TAU * k / BED_COUNT + rng.randf_range(-0.12, 0.12)
			var r := BED_RADIUS + rng.randf_range(-0.15, 0.15)
			var p := Vector3(c.x + cos(a) * r, 0.0, c.z + sin(a) * r)
			if _on_path(p, 0.2) or HubRegion.in_lake_water(p):
				continue
			var s := rng.randf_range(1.5, 1.9)
			var xform := Transform3D(Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)).scaled(Vector3.ONE * s), p)
			_add("bed", "flower_%d" % variant, "portal_%d" % index, xform, 0.02, 0.3)
		index += 1

## Blob shadows under everything that stands: the layout's trees, bushes,
## rocks, stumps and landmarks (read from the layout, the same reading
## ground_footprints() makes) and this file's own wall trees and extra
## bushes / rocks. One MultiMesh of 2-triangle quads, alpha-blended,
## offset a little away from the sun so they read as cast rather than
## painted.
const SHADOW_RADIUS: Dictionary = {
	&"tree": 1.3, &"bush": 1.0, &"rock": 0.9, &"stump": 0.7, &"landmark": 1.8,
}
const SHADOW_Y: float = 0.02
## Mostly UNDER the prop, nudged toward the camera (+z): a disc pushed
## away from the sun lands behind a bush from this camera and is never
## seen (measured on capture 6, where only the trees showed one).
const SHADOW_OFFSET: Vector2 = Vector2(-0.06, 0.12)

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
			"bush": radius = 1.0
			"rock": radius = 0.9
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

## Clouds: a few puffs of squashed spheres high and far, drifting slowly
## in _process. They fill the sliver of sky the camera pitch leaves at
## the top of the frame. Not hazed (see CozyPalette.cloud_material).
const CLOUD_COUNT: int = 9
const CLOUD_DRIFT: float = 0.6
var _cloud_node: MultiMeshInstance3D = null

func _clouds() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = sphere
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 13
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < CLOUD_COUNT * 3 and tries < 400:
		tries += 1
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(150.0, 200.0)
		# LOW: the camera pitch leaves ~2.5 degrees of sky above the
		# horizon, so a cloud has to sit almost on it (y ~ 10-18 at 150+ u)
		# to be in frame at all -- measured, the first pass at y 30-48 was
		# entirely above the frame.
		var centre := Vector3(cos(a) * r, rng.randf_range(9.0, 17.0), sin(a) * r)
		if centre.z > 30.0:
			continue
		# Three lobes per cloud: one wide, two smaller riding on it.
		var w := rng.randf_range(14.0, 24.0)
		xforms.append(Transform3D(Basis().scaled(Vector3(w, w * 0.32, w * 0.55)), centre))
		xforms.append(Transform3D(Basis().scaled(Vector3(w * 0.55, w * 0.30, w * 0.4)), centre + Vector3(w * 0.35, w * 0.12, 0.0)))
		xforms.append(Transform3D(Basis().scaled(Vector3(w * 0.45, w * 0.26, w * 0.38)), centre + Vector3(-w * 0.3, w * 0.10, w * 0.1)))
	multi.instance_count = xforms.size()
	var bounds := AABB()
	for i in xforms.size():
		multi.set_instance_transform(i, xforms[i])
		var box := xforms[i] * sphere.get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
	multi.custom_aabb = bounds.grow(40.0)
	_cloud_node = MultiMeshInstance3D.new()
	_cloud_node.name = "Clouds"
	_cloud_node.multimesh = multi
	_cloud_node.material_override = CozyPalette.cloud_material()
	_cloud_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cloud_node)
	_stats["clouds"] = xforms.size() / 3

## Butterflies: the "small permanent animation" of the brief. One
## MultiMesh per colour, every flap and circuit computed in the vertex
## shader from per-instance custom data (phase, radius, direction, flap
## rate). Centres are drawn near the flowers this file placed, so they
## hover where a player expects them.
const BUTTERFLY_COUNT: int = 21

func _butterflies() -> void:
	var centres: Array[Vector3] = []
	for key in _batch_order:
		var batch: Dictionary = _batches[key]
		if batch["family"] != "flower":
			continue
		for xform in batch["xforms"]:
			centres.append((xform as Transform3D).origin)
	if centres.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 11
	var per_kind: Array = [[], [], []]
	for i in BUTTERFLY_COUNT:
		var c: Vector3 = centres[rng.randi_range(0, centres.size() - 1)]
		var at := Vector3(c.x + rng.randf_range(-1.0, 1.0), rng.randf_range(0.7, 1.4), c.z + rng.randf_range(-1.0, 1.0))
		var custom := Color(rng.randf(), rng.randf_range(0.5, 1.6), rng.randf(), rng.randf())
		per_kind[i % 3].append([at, custom])
	var placed := 0
	for kind in 3:
		var items: Array = per_kind[kind]
		if items.is_empty():
			continue
		var mesh: Mesh = CozyPalette.glb_mesh(CozyPalette.decor_path("butterfly_%d" % kind))
		if mesh == null:
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		# use_colors too: without it COLOR reads black in the shader, and
		# the butterflies drew as dark specks (measured on capture 6).
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = mesh
		multi.instance_count = items.size()
		var bounds := AABB()
		for i in items.size():
			var at: Vector3 = items[i][0]
			var xform := Transform3D(Basis(), at)
			multi.set_instance_transform(i, xform)
			multi.set_instance_color(i, Color.WHITE)
			multi.set_instance_custom_data(i, items[i][1])
			var box := AABB(at - Vector3(2.0, 1.2, 2.0), Vector3(4.0, 2.4, 4.0))
			bounds = box if i == 0 else bounds.merge(box)
		multi.custom_aabb = bounds
		var node := MultiMeshInstance3D.new()
		node.name = "Butterflies%d" % kind
		node.multimesh = multi
		node.material_override = CozyPalette.butterfly_material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		placed += items.size()
	_stats["butterflies"] = placed

## A blob shadow that follows Keepy's ground position. Reads his position
## only -- nothing about him is touched -- and shrinks a little while he is
## in the air, which is what sells the hop.
var _hero: Node3D = null
var _hero_shadow_node: MeshInstance3D = null
const HERO_SHADOW_RADIUS: float = 0.78

func _hero_shadow() -> void:
	_hero = get_parent().get_node_or_null("Keepy") as Node3D
	if _hero == null:
		return
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_hero_shadow_node = MeshInstance3D.new()
	_hero_shadow_node.name = "HeroShadow"
	_hero_shadow_node.mesh = quad
	_hero_shadow_node.material_override = CozyPalette.shadow_material()
	_hero_shadow_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hero_shadow_node)
	set_process(true)

func _process(delta: float) -> void:
	if _cloud_node != null:
		# Whole layer drifts along +x; the AABB was grown to cover it.
		_cloud_node.position.x = fmod(_cloud_node.position.x + CLOUD_DRIFT * delta + 30.0, 60.0) - 30.0
	if _hero == null or _hero_shadow_node == null:
		return
	var p := _hero.global_position
	var lift: float = clampf(p.y, 0.0, 1.5)
	var r: float = HERO_SHADOW_RADIUS * (1.0 - lift * 0.25)
	_hero_shadow_node.global_transform = Transform3D(
		Basis().scaled(Vector3(r * 2.0, 1.0, r * 2.0)),
		Vector3(p.x, SHADOW_Y + 0.005, p.z + 0.18))

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
