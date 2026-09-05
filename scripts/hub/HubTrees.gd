extends Node3D
class_name HubTrees
## Carte-blanche v4 -- the CLIMBABLE trees ("arbres-perchoirs"): one
## Blender family (docs/carte_blanche/blender/climbtree.py), a handful of
## sites measured for clearance and for the camera (V4SiteProbe), one tap
## channel, and the carrier side of KeepyHopper's ON_TREE ride.
##
## THE TREE IS THE CARRIER. Everything Keepy does up there is written in
## this node's local space and read back through `to_global()`, so the
## shake -- a damped wobble of the whole tree about its foot -- carries him
## with it for free. `_process` writes the wobble FIRST and calls
## `follow_tree()` right after, in the same call: carrier-then-carried.
##
## WITHDRAWAL ON THE BOAT'S TERMS: `accepts_tap()` answers -1 for the tree
## he is on, so a tap on it while he is up there falls through to the
## ground path, which HubWorld intercepts BY STATE (shake if it is the
## same tree, descend otherwise). Every other tree keeps answering, so a
## tap on a second tree from the seat of the first means "come down and
## go climb that one" -- one tap, the whole thing, like every prop here.
##
## Every fact is authored ONCE: sites in TREES, the family's geometry in
## the contract constants (copied from climbtree.py's STATS and RE-MEASURED
## against the imported mesh at build -- a drift pushes an error).

## Sites. Measured by V4SiteProbe (clearance against every occupant, the
## scatter's own blockers, and the spawn camera by hand):
##   * (6, 0) and (-7, 0.5): flanking the spawn plaza, one hop out of the
##     first frame on either side (at Keepy's depth the frame is ~7 u wide,
##     v3's measurement; nothing but the portal row fits in it);
##   * (2, 16.5): plateau south, between the turnstile and the cabin path;
##   * (12, -59.5): the hollow, 4.5 u north of the gold balloon's dock --
##     in frame the moment a rider steps off, since the drop faces north;
##   * (2, -100.5): the moor, west of the hamlet, on the road's side.
const TREES: Array = [
	{"at": Vector3(6.0, 0.0, 0.0), "glb": "climbtree_0"},
	{"at": Vector3(-7.0, 0.0, 0.5), "glb": "climbtree_1"},
	{"at": Vector3(2.0, 0.0, 16.5), "glb": "climbtree_2"},
	{"at": Vector3(12.0, 0.0, -59.5), "glb": "climbtree_3"},
	{"at": Vector3(2.0, 0.0, -100.5), "glb": "climbtree_4"},
]

## The family's contract (climbtree.py STATS), local units at scale 1.
const TRUNK_H: float = 3.3
const TRUNK_R_BASE: float = 0.30
const TRUNK_R_TOP: float = 0.21
const SEAT_Y: float = 3.42
const RING_TOP: float = 3.98
const RING_R: float = 1.64
## Tolerance on the imported mesh's height against RING_TOP (the lobes'
## noise is +-0.09 by construction).
const CONTRACT_TOLERANCE: float = 0.16

## Ground the scatter keeps clear, the tap disc, and the foot point's gap
## past the flared base.
const FOOTPRINT: float = 2.0
const TAP_RADIUS: float = 1.9
const FOOT_GAP: float = 0.42
## Wind the wreath sways with: the layout trees' own numbers.
const WIND_AMOUNT: float = 0.05
const WIND_HEIGHT: float = 3.2
## The shake: peak tilt of the whole tree about its foot, cycles, length.
const SHAKE_TILT_DEG: float = 3.6
const SHAKE_HZ: float = 4.2
const SHAKE_S: float = 0.9

## Emitted when a shake's wobble ends (the nuts have fallen by then).
signal shake_finished(index: int)

## The birds: while he sits in the wreath, three small birds come and
## circle the crown -- the "something to see from up there" the brief
## asks for, done without touching the camera. Cheap by construction: two
## triangles per bird, tinted decor material, moved from this node's
## _process only while a tree is occupied.
const BIRD_COUNT: int = 3
const BIRD_ORBIT_R: float = 2.6
const BIRD_ORBIT_Y: float = 1.35
const BIRD_ORBIT_RATE: float = 1.05
const BIRD_FLAP_HZ: float = 4.5
const BIRD_COLOURS: Array = [Color(0.36, 0.55, 0.92), Color(0.95, 0.72, 0.30), Color(0.92, 0.45, 0.50)]
var _birds: Array[Node3D] = []
## The nuts HANGING in each wreath: one per unit of stock, so a full tree
## and a spent one are told apart with no UI. Children of the tree node,
## so they wobble with it. Refreshed from WorldSave on a slow clock (the
## recharge is wall-clock, lazy) and right after a shake.
var _hanging: Array = []
var _stock_clock: float = 0.0
const HANG_RING_R: float = 1.22
const HANG_Y: float = 2.62
const HANG_REFRESH_S: float = 2.0
var _bird_t: float = 0.0
var _bird_scale: float = 0.0

var _nodes: Array[Node3D] = []
var _faces: Array[Vector3] = []
var _occupied: int = -1
var _keepy: KeepyHopper = null
var _weather: Node = null
var _shake_t: Array[float] = []
var _shake_axis: Array[Vector3] = []

func _ready() -> void:
	for i in TREES.size():
		_build(i)
	_build_birds()
	for i in TREES.size():
		_build_hanging(i)

## The kind of nut hanging slot `slot` of tree `index` gives: two acorns
## and a hazelnut per tree, the odd slot rotating with the tree.
func nut_kind(index: int, slot: int) -> StringName:
	return &"hazelnut" if (index + slot) % 3 == 1 else &"acorn"

func _build_hanging(index: int) -> void:
	var slots: Array = []
	var tree: Node3D = _nodes[index]
	for k in WorldSave.TREE_CAPACITY:
		var kind: StringName = nut_kind(index, k)
		var mesh: Mesh = CozyPalette.glb_mesh(CozyPalette.decor_path("hazelnut_0" if kind == &"hazelnut" else "acorn_0"))
		var node := MeshInstance3D.new()
		node.name = "Hang%d" % k
		node.mesh = mesh
		node.material_override = CozyPalette.decor_material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a: float = TAU * (float(k) + 0.5 + 0.37 * float(index)) / float(WorldSave.TREE_CAPACITY)
		node.position = Vector3(cos(a) * HANG_RING_R, HANG_Y + 0.08 * float(k % 2), sin(a) * HANG_RING_R)
		# Hanging: upside down, the cap at the top against the leaves.
		node.rotation = Vector3(PI, a, 0.0)
		node.scale = Vector3.ONE * 0.9
		tree.add_child(node)
		slots.append(node)
	_hanging.append(slots)
	refresh_stock(index)

## Shows as many hanging nuts as the tree holds right now.
func refresh_stock(index: int) -> void:
	var stock: int = WorldSave.tree_stock(tree_id(index))
	var slots: Array = _hanging[index]
	for k in slots.size():
		slots[k].visible = k < stock

## The kinds a shake drops: the topmost `count` hanging slots' kinds.
func kinds_for_shake(index: int, count: int) -> Array:
	var stock: int = WorldSave.tree_stock(tree_id(index))
	var out: Array = []
	for k in range(stock - 1, maxi(stock - 1 - count, -1), -1):
		out.append(nut_kind(index, k))
	return out

func _build_birds() -> void:
	for i in BIRD_COUNT:
		var bird := Node3D.new()
		bird.name = "Bird%d" % i
		var colour: Color = BIRD_COLOURS[i % BIRD_COLOURS.size()]
		for side in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			wing.name = "WingL" if side < 0.0 else "WingR"
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			# A wing is one triangle from the body line out to the tip,
			# wound clockwise seen from above (the repo's face rule).
			var tip := Vector3(0.42 * side, 0.0, -0.05)
			var a := Vector3(0.0, 0.0, 0.12)
			var b := Vector3(0.0, 0.0, -0.14)
			st.set_normal(Vector3.UP)
			if side > 0.0:
				st.add_vertex(a); st.add_vertex(tip); st.add_vertex(b)
			else:
				st.add_vertex(a); st.add_vertex(b); st.add_vertex(tip)
			wing.mesh = st.commit()
			wing.material_override = CozyPalette.decor_material_tinted(colour)
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bird.add_child(wing)
		bird.visible = false
		add_child(bird)
		_birds.append(bird)

func _update_birds(delta: float) -> void:
	var want: float = 1.0 if (_occupied >= 0 and _keepy != null and _keepy.is_seated_on_tree()) else 0.0
	_bird_scale = move_toward(_bird_scale, want, delta * 1.6)
	if _bird_scale <= 0.0:
		for bird in _birds:
			bird.visible = false
		return
	_bird_t += delta
	var centre: Vector3 = _nodes[_occupied].global_position if _occupied >= 0 else Vector3.ZERO
	for i in _birds.size():
		var bird: Node3D = _birds[i]
		bird.visible = true
		var phase: float = _bird_t * BIRD_ORBIT_RATE + TAU * float(i) / float(_birds.size())
		var r: float = BIRD_ORBIT_R * (1.0 + 0.12 * sin(phase * 0.7 + float(i)))
		var pos := centre + Vector3(cos(phase) * r, SEAT_Y + BIRD_ORBIT_Y + 0.28 * sin(phase * 1.9 + float(i) * 2.1), sin(phase) * r)
		bird.global_position = pos
		# Facing the tangent of the circle (counter-clockwise seen from above).
		var tangent := Vector3(-sin(phase), 0.0, cos(phase))
		bird.rotation.y = atan2(tangent.x, tangent.z)
		var s: float = _bird_scale * 1.4 * (0.85 + 0.15 * float(i % 2))
		bird.scale = Vector3.ONE * s
		var flap: float = deg_to_rad(38.0) * sin(_bird_t * TAU * BIRD_FLAP_HZ + float(i) * 1.3)
		bird.get_node("WingL").rotation.z = -flap
		bird.get_node("WingR").rotation.z = flap

func setup(keepy: KeepyHopper, weather: Node) -> void:
	_keepy = keepy
	_weather = weather

## ---- building --------------------------------------------------------

func _build(index: int) -> void:
	var spec: Dictionary = TREES[index]
	var mesh: Mesh = CozyPalette.glb_mesh(CozyPalette.decor_path(spec["glb"]))
	var node := MeshInstance3D.new()
	node.name = "ClimbTree%d" % index
	if mesh == null:
		push_error("HubTrees: %s.glb missing" % spec["glb"])
		mesh = SphereMesh.new()
	node.mesh = mesh
	node.material_override = CozyPalette.decor_material_wind(WIND_AMOUNT, WIND_HEIGHT)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = spec["at"]
	# The face he climbs is the trunk's EAST flank (world +x): from this
	# camera that is a PROFILE -- body against the bark, tail out, head up,
	# the one silhouette that says "climbing". The camera side (+z) was
	# tried first and captured: seen from above and behind, his tail hid
	# the whole body. The family grows two stub branches at random
	# azimuths under the wreath; the tree is yawed so they sit on the
	# opposite flank -- measured on the mesh, not assumed from the seed.
	var stub_az: float = _stub_azimuth(mesh)
	var yaw: float = -PI * 0.5 - stub_az
	node.rotation.y = yaw
	add_child(node)
	_nodes.append(node)
	_faces.append(Vector3(1, 0, 0).rotated(Vector3.UP, -yaw))
	_shake_t.append(-1.0)
	_shake_strength.append(1.0)
	_shake_axis.append(Vector3.RIGHT)
	# Contract check against the mesh actually imported.
	var aabb: AABB = mesh.get_aabb()
	var top: float = aabb.position.y + aabb.size.y
	if absf(top - RING_TOP) > CONTRACT_TOLERANCE:
		push_error("HubTrees: %s stands %.3f high, contract says %.3f (+-%.2f) -- the seat would be off." % [spec["glb"], top, RING_TOP, CONTRACT_TOLERANCE])

## Mean azimuth (about +y, from +z toward +x) of the vertices that stick
## out of the trunk under the wreath -- the stub branches. PI/2 off if
## there is nothing there, which leaves the tree as authored.
func _stub_azimuth(mesh: Mesh) -> float:
	var sum := Vector2.ZERO
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			if v.y < 1.2 or v.y > TRUNK_H - 0.05:
				continue
			var r: float = Vector2(v.x, v.z).length()
			if r > TRUNK_R_BASE + 0.22:
				sum += Vector2(v.x, v.z).normalized()
	if sum.length() < 0.001:
		return PI * 0.5
	return atan2(sum.x, sum.y)

## ---- published facts -------------------------------------------------

static func footprints() -> Array:
	var out: Array = []
	for spec in TREES:
		out.append({"position": spec["at"], "radius": FOOTPRINT})
	return out

func count() -> int:
	return _nodes.size()

func node(index: int) -> Node3D:
	return _nodes[index]

func position_of(index: int) -> Vector3:
	return TREES[index]["at"]

## Stable identity for the save: the site, snapped. Moving a site in
## TREES makes a new (full) tree, which is what a layout edit should do.
func tree_id(index: int) -> String:
	var at: Vector3 = TREES[index]["at"]
	return "%.1f_%.1f" % [at.x, at.z]

## The contract KeepyHopper climbs by, in this tree's local space.
func climb_spec(index: int) -> Dictionary:
	return {
		"trunk_h": TRUNK_H, "r_base": TRUNK_R_BASE, "r_top": TRUNK_R_TOP,
		"seat": Vector3(0.0, SEAT_Y, 0.0), "face": _faces[index], "foot_gap": FOOT_GAP,
	}

func foot_point(index: int) -> Vector3:
	if _keepy == null:
		return position_of(index)
	return _keepy.tree_foot_point(_nodes[index], climb_spec(index))

## Which tree a tap on `aim` (world, ground) means; -1 for none. The tree
## he is on withdraws (the boat's rule), every other one answers.
func accepts_tap(aim: Vector3) -> int:
	var best: int = -1
	var best_d: float = INF
	for i in TREES.size():
		if i == _occupied:
			continue
		var at: Vector3 = TREES[i]["at"]
		var d: float = Vector2(aim.x - at.x, aim.z - at.z).length()
		if d <= TAP_RADIUS and d < best_d:
			best_d = d
			best = i
	return best

## Is `aim` on the tree he is currently on (the seat's "same tree" test)?
func is_on_occupied(aim: Vector3) -> bool:
	if _occupied < 0:
		return false
	var at: Vector3 = TREES[_occupied]["at"]
	return Vector2(aim.x - at.x, aim.z - at.z).length() <= TAP_RADIUS

func occupied() -> int:
	return _occupied

func set_occupied(index: int) -> void:
	_occupied = index

func release() -> void:
	_occupied = -1

## ---- the shake --------------------------------------------------------

## Starts the wobble on tree `index`. The tilt axis is horizontal and
## perpendicular to the climbed face, so from the camera the wreath is
## seen nodding toward and away, the reading with the most pixels.
var _shake_strength: Array[float] = []

func shake(index: int, strength: float = 1.0) -> void:
	if index < 0 or index >= _nodes.size():
		return
	_shake_t[index] = 0.0
	_shake_strength[index] = strength
	var f: Vector3 = _nodes[index].global_transform.basis * _faces[index]
	_shake_axis[index] = Vector3(f.z, 0.0, -f.x).normalized()
	if index == _occupied and _keepy != null:
		_keepy.bounce_on_tree()

func is_shaking(index: int) -> bool:
	return index >= 0 and index < _shake_t.size() and _shake_t[index] >= 0.0

## The wobble's current tilt (0 when still), for the nuts' release timing.
func shake_phase(index: int) -> float:
	if not is_shaking(index):
		return 0.0
	return clampf(_shake_t[index] / SHAKE_S, 0.0, 1.0)

func _process(delta: float) -> void:
	for i in _nodes.size():
		if _shake_t[i] >= 0.0:
			_shake_t[i] += delta
			var u: float = _shake_t[i] / SHAKE_S
			var node: Node3D = _nodes[i]
			var yaw: float = node.rotation.y
			if u >= 1.0:
				_shake_t[i] = -1.0
				node.rotation = Vector3(0.0, yaw, 0.0)
				shake_finished.emit(i)
			else:
				var tilt: float = deg_to_rad(SHAKE_TILT_DEG) * _shake_strength[i] * sin(u * TAU * SHAKE_HZ * SHAKE_S) * pow(1.0 - u, 1.4)
				var basis := Basis(Vector3.UP, yaw).rotated(_shake_axis[i], tilt)
				node.transform.basis = basis
	# Carried AFTER the carrier, in the same call.
	if _occupied >= 0 and _keepy != null:
		_keepy.follow_tree(delta, seat_sway(_occupied))
	_update_birds(delta)
	_stock_clock += delta
	if _stock_clock >= HANG_REFRESH_S:
		_stock_clock = 0.0
		for i in _nodes.size():
			refresh_stock(i)

## The wreath's wind sway at the seat, in the tree's LOCAL space -- the
## same sum the decor shader adds to every vertex (cozy_decor.gdshader),
## so his feet ride the pad instead of hovering over it in a storm. The
## shader's TIME and the engine's ticks start together; a phase drift of
## a frame is a millimetre here.
func seat_sway(index: int) -> Vector3:
	var node: Node3D = _nodes[index]
	var look: Dictionary = _weather.call("current_look") if _weather != null and _weather.has_method("current_look") else {}
	var wind_scale: float = float(look.get("wind", 1.0))
	var lean: Vector2 = look.get("lean", Vector2.ZERO)
	var w: float = clampf(SEAT_Y / WIND_HEIGHT, 0.0, 1.0)
	w *= w
	var wp: Vector3 = node.global_position
	var phase: float = wp.x * 0.35 + wp.z * 0.27
	var t: float = float(Time.get_ticks_msec()) * 0.001
	var sway: float = sin(t * 1.1 * TAU * 0.5 + phase) * 0.7 + sin(t * 1.1 * TAU * 1.3 + phase * 2.1) * 0.3
	var model_scale: float = maxf(node.scale.x, 0.001)
	var xz := Vector2(sway, sway * 0.6) * (WIND_AMOUNT * wind_scale * w / model_scale)
	xz += lean * (w * minf(WIND_AMOUNT * 6.0, 1.0) / model_scale)
	return Vector3(xz.x, 0.0, xz.y)
