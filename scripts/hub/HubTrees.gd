extends Node3D
class_name HubTrees
## Carte-blanche v4 -- the CLIMBABLE trees ("arbres-perchoirs"): one
## Blender family (docs/carte_blanche/blender/climbtree.py), a handful of
## sites measured for clearance and for the camera (V4SiteProbe), one tap
## channel, and the carrier side of KeepyHopper's ON_TREE ride.
##
## Carte-blanche v5 -- CLIMBING IS GENERAL. Every decorative tree the
## player can walk to (the layout's plateau trees, the hollow's autumn
## trees, the moor's olives) is climbable too, WITHOUT leaving its
## MultiMesh: HubBuilder.cozy_trees() and CozyScatter.climb_trees()
## publish each instance (world transform, GLB, batch node and slot), and
## this node keeps one empty Node3D per tree as its CARRIER -- rotation
## and translation only, never scale, so every Keepy-sized constant in
## KeepyHopper (grip gap, sway, foot gap) stays Keepy-sized on a tree at
## scale 0.5 or 1.5. The geometry Keepy climbs by is MEASURED ONCE PER GLB
## off its imported vertices (measure_kind) and multiplied by the
## instance's scale into the spec: trunk height and taper, the trunk's
## lean, the crown's top ON THE AXIS (the seat: he sits on the dome, so a
## full canopy never buries him), the crown's radius (the tap). The shake
## writes the carrier's tilt back into the instance's transform -- one
## set_instance_transform per frame, no reallocation (instance_count is
## never touched), zero extra draw calls.
##
## Which trees qualify is decided HERE, from measurement, never from a
## hand list: no conifer / cypress / far blob (no crown to sit on), seat
## between SEAT_MIN_Y and SEAT_MAX_Y (the camera never rises: above 6.96 u
## at his aplomb nothing is in frame, and his head is 1.7 u over the
## seat), and a foot point the world accepts (HubWorld's `foot_ok`: in
## the region, dry, off every portal disc and prop footprint), on the +x
## flank first (a profile from this camera) and the -x flank second.
##
## THE TREE IS THE CARRIER. Everything Keepy does up there is written in
## this node's local space and read back through `to_global()`, so the
## shake -- a damped wobble of the whole tree about its foot -- carries him
## with it for free. `_process` writes the wobble FIRST and calls
## `follow_tree()` right after, in the same call: carrier-then-carried.
##
## WITHDRAWAL ON THE BOAT'S TERMS: `tree_hit()` answers -1 for the tree
## he is on, so a tap on it while he is up there falls through to the
## ground path, which HubWorld intercepts BY STATE (shake if it is the
## same tree, descend otherwise). Every other tree keeps answering, so a
## tap on a second tree from the seat of the first means "come down and
## go climb that one" -- one tap, the whole thing, like every prop here.
##
## Every fact is authored ONCE: perchoir sites in TREES, the perchoir
## family's geometry in the contract constants (copied from climbtree.py's
## STATS and RE-MEASURED against the imported mesh at build -- a drift
## pushes an error), every other tree's geometry measured off its mesh.

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

## v5: the general climb's gates, all in WORLD units.
## Below SEAT_MIN_Y he would sit on a bush; above SEAT_MAX_Y his head
## (1.7 u over the seat, v4's measurement) leaves the frame: the camera is
## a constant offset from his GROUND point, so the top ray crosses his
## aplomb at y = 7.6 - 8.9 * tan(40.5 deg - 36.4 deg) = 6.96 u.
const SEAT_MIN_Y: float = 2.0
const SEAT_MAX_Y: float = 4.85
## Kinds with no crown to sit on.
const UNCLIMBABLE_KINDS: Array[String] = ["conifer", "cypress", "far"]
## The tap disc on the ground around a decor trunk: the trunk plus a hand.
## Small on purpose -- paths run past these trees, and a wide disc would
## turn "walk down the path" into "climb". The CROWN is what the player
## taps, and it is answered by the ray test (tree_hit).
const DECOR_TAP_MARGIN: float = 0.55
## v5: the ascent's rhythm is per unit of trunk, so a 1.2 u trunk is two
## pulls and a 3 u trunk five -- KeepyHopper's TREE_CLIMB_S / TREE_PULLS
## are the perchoir's 2.78 u of climbed trunk.
const PERCH_CLIMBED_LENGTH: float = 2.78

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
## and a spent one are told apart with no UI. Perchoirs: children of the
## tree node, so they wobble with it. Decor trees (v5): ONE MultiMesh per
## (kind, 28 u cell) so the plateau's fifty trees cost a handful of draw
## calls, hidden slots parked underground at scale 0.001, the shaken
## tree's slots rewritten each frame of its wobble. Refreshed from
## WorldSave on a slow clock (the recharge is wall-clock, lazy) and right
## after a shake.
var _hanging: Array = []
var _stock_clock: float = 0.0
const HANG_RING_R: float = 1.22
const HANG_Y: float = 2.62
const HANG_REFRESH_S: float = 2.0
const HANG_SCALE: float = 0.9
const NUT_CELL: float = 42.0
var _bird_t: float = 0.0
var _bird_scale: float = 0.0

## One entry per climbable tree, perchoirs first (index-aligned with
## TREES), decor trees after. Keys: "at" (ground, world), "glb", "perch"
## (bool), "kind" (measure_kind of its GLB), "scale", "yaw", "face"
## (local unit xz), "multi" / "slot" (decor: the MultiMeshInstance3D and
## the instance it draws), "nuts" (decor: [batch key, first instance]).
var _sites: Array = []
var _nodes: Array[Node3D] = []
var _faces: Array[Vector3] = []
var _occupied: int = -1
var _keepy: KeepyHopper = null
var _weather: Node = null
var _shake_t: Array[float] = []
var _shake_axis: Array[Vector3] = []
var _shake_strength: Array[float] = []
var _kinds: Dictionary = {}
var _nut_batches: Dictionary = {}
var _nut_meshes: Dictionary = {}
var _decor_count: int = 0
var _excluded: Array = []

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
		node.scale = Vector3.ONE * HANG_SCALE
		tree.add_child(node)
		slots.append(node)
	_hanging.append(slots)
	refresh_stock(index)

## Shows as many hanging nuts as the tree holds right now.
func refresh_stock(index: int) -> void:
	var stock: int = WorldSave.tree_stock(tree_id(index))
	if _sites[index]["perch"]:
		var slots: Array = _hanging[index]
		for k in slots.size():
			slots[k].visible = k < stock
	else:
		_write_decor_nuts(index, stock)

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
	var seat_y: float = seat_height(_occupied) if _occupied >= 0 else SEAT_Y
	for i in _birds.size():
		var bird: Node3D = _birds[i]
		bird.visible = true
		var phase: float = _bird_t * BIRD_ORBIT_RATE + TAU * float(i) / float(_birds.size())
		var r: float = BIRD_ORBIT_R * (1.0 + 0.12 * sin(phase * 0.7 + float(i)))
		var pos := centre + Vector3(cos(phase) * r, seat_y + BIRD_ORBIT_Y + 0.28 * sin(phase * 1.9 + float(i) * 2.1), sin(phase) * r)
		bird.global_position = pos
		# Facing the tangent of the circle (counter-clockwise seen from above).
		var tangent := Vector3(-sin(phase), 0.0, cos(phase))
		bird.rotation.y = atan2(tangent.x, tangent.z)
		var s: float = _bird_scale * 1.4 * (0.85 + 0.15 * float(i % 2))
		bird.scale = Vector3.ONE * s
		var flap: float = deg_to_rad(38.0) * sin(_bird_t * TAU * BIRD_FLAP_HZ + float(i) * 1.3)
		bird.get_node("WingL").rotation.z = -flap
		bird.get_node("WingR").rotation.z = flap

## `foot_ok` is HubWorld's `Callable(foot: Vector3, at: Vector3) -> String`:
## empty for a foot point the world accepts, else the reason it does not.
## `published` is every decor tree instance the builder and the scatter
## publish (their own lists, concatenated by the caller).
func setup(keepy: KeepyHopper, weather: Node, published: Array = [], foot_ok: Callable = Callable()) -> void:
	_keepy = keepy
	_weather = weather
	if not published.is_empty():
		_adopt(published, foot_ok)

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
	var face: Vector3 = Vector3(1, 0, 0).rotated(Vector3.UP, -yaw)
	_faces.append(face)
	_shake_t.append(-1.0)
	_shake_strength.append(1.0)
	_shake_axis.append(Vector3.RIGHT)
	# The perchoir's kind, from its contract (re-measured below).
	var kind := {"trunk_h": TRUNK_H, "r_base": TRUNK_R_BASE, "r_top": TRUNK_R_TOP, "lean": Vector2.ZERO,
		"seat_y": SEAT_Y, "top": RING_TOP, "crown_r": RING_R, "crown_lo": RING_TOP - 1.3}
	_sites.append({"at": spec["at"], "glb": spec["glb"], "perch": true, "kind": kind, "scale": 1.0, "yaw": yaw, "face": face})
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

## ---- v5: the decor trees --------------------------------------------

## Geometry of one GLB kind, in the mesh's own units, off its vertices.
## The crown is every vertex farther than 0.5 from the axis and higher
## than 0.6 (no trunk of these families is that wide; every crown is);
## its lowest vertex is where the trunk ends. The trunk is read in four
## bands of the lower 70 % of that height, each band's ring centre and
## radius, then fitted: radius linear in y (the families taper
## linearly), centre quadratic in y (trunk_bm bends as t^2). The seat is
## the crown's highest vertex within 0.35 of the axis -- the top of the
## dome he sits on, never a satellite lobe.
static func measure_kind(mesh: Mesh) -> Dictionary:
	var verts := PackedVector3Array()
	for s in mesh.get_surface_count():
		verts.append_array(mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX])
	var top: float = -INF
	var crown_r: float = 0.0
	var trunk_h: float = INF
	for v in verts:
		top = maxf(top, v.y)
		var r: float = Vector2(v.x, v.z).length()
		crown_r = maxf(crown_r, r)
		if r > 0.5 and v.y > 0.6:
			trunk_h = minf(trunk_h, v.y)
	if trunk_h == INF:
		trunk_h = top * 0.5
	var seat_y: float = -INF
	for v in verts:
		if Vector2(v.x, v.z).length() < 0.35:
			seat_y = maxf(seat_y, v.y)
	# Bands.
	var bands: int = 4
	var ys: Array[float] = []
	var rs: Array[float] = []
	var cs: Array[Vector2] = []
	for b in bands:
		var y0: float = trunk_h * (0.15 + 0.55 * float(b) / float(bands))
		var y1: float = trunk_h * (0.15 + 0.55 * float(b + 1) / float(bands))
		var centre := Vector2.ZERO
		var n: int = 0
		for v in verts:
			if v.y >= y0 and v.y < y1 and Vector2(v.x, v.z).length() < 0.5:
				centre += Vector2(v.x, v.z)
				n += 1
		if n == 0:
			continue
		centre /= float(n)
		var r: float = 0.0
		for v in verts:
			if v.y >= y0 and v.y < y1 and Vector2(v.x, v.z).length() < 0.5:
				r = maxf(r, (Vector2(v.x, v.z) - centre).length())
		ys.append((y0 + y1) * 0.5)
		rs.append(r)
		cs.append(centre)
	var r_base: float = 0.25
	var r_top: float = 0.18
	var lean := Vector2.ZERO
	if ys.size() >= 2:
		# Least squares r = a + b y.
		var n: float = float(ys.size())
		var sy: float = 0.0; var sr: float = 0.0; var syy: float = 0.0; var syr: float = 0.0
		for i in ys.size():
			sy += ys[i]; sr += rs[i]; syy += ys[i] * ys[i]; syr += ys[i] * rs[i]
		var den: float = n * syy - sy * sy
		var b: float = (n * syr - sy * sr) / den if absf(den) > 1e-6 else 0.0
		var a: float = (sr - b * sy) / n
		r_base = maxf(a, 0.05)
		r_top = maxf(a + b * trunk_h, 0.05)
		# Lean: c(y) = L (y / trunk_h)^2.
		var num := Vector2.ZERO
		var den2: float = 0.0
		for i in ys.size():
			var t: float = ys[i] / trunk_h
			num += cs[i] * (t * t)
			den2 += t * t * t * t
		if den2 > 1e-6:
			lean = num / den2
	elif ys.size() == 1:
		r_base = rs[0]
		r_top = rs[0]
	return {"trunk_h": trunk_h, "r_base": r_base, "r_top": r_top, "lean": lean, "seat_y": seat_y,
		"top": top, "crown_r": crown_r, "crown_lo": trunk_h}

func _kind_of(glb: String) -> Dictionary:
	if not _kinds.has(glb):
		var mesh: Mesh = CozyPalette.glb_mesh(CozyPalette.decor_path(glb))
		_kinds[glb] = measure_kind(mesh) if mesh != null else {}
	return _kinds[glb]

static func _unclimbable_kind(glb: String) -> bool:
	for word in UNCLIMBABLE_KINDS:
		if glb.contains(word):
			return true
	return false

## Files every published decor tree that passes the gates as a site of
## its own, with an empty carrier node; builds the hanging-nut batches.
func _adopt(published: Array, foot_ok: Callable) -> void:
	for t in published:
		var glb: String = t["glb"]
		var at: Vector3 = t["at"]
		if _unclimbable_kind(glb):
			_excluded.append({"at": at, "glb": glb, "why": "kind"})
			continue
		var kind: Dictionary = _kind_of(glb)
		if kind.is_empty():
			_excluded.append({"at": at, "glb": glb, "why": "no mesh"})
			continue
		var xform: Transform3D = t["xform"]
		var s: float = xform.basis.get_scale().x
		var seat_w: float = float(kind["seat_y"]) * s
		if seat_w < SEAT_MIN_Y or seat_w > SEAT_MAX_Y:
			_excluded.append({"at": at, "glb": glb, "why": "seat %.2f" % seat_w})
			continue
		var yaw: float = xform.basis.get_euler().y
		var face_world := Vector3.ZERO
		var why: String = "no foot"
		for candidate in [Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
			var foot: Vector3 = at + candidate * (float(kind["r_base"]) * s * 1.35 + FOOT_GAP)
			why = String(foot_ok.call(foot, at)) if foot_ok.is_valid() else ""
			if why == "":
				face_world = candidate
				break
		if face_world == Vector3.ZERO:
			_excluded.append({"at": at, "glb": glb, "why": "foot: " + why})
			continue
		var node := Node3D.new()
		node.name = "Carrier%d" % _sites.size()
		node.transform = Transform3D(Basis(Vector3.UP, yaw), at)
		add_child(node)
		_nodes.append(node)
		var face: Vector3 = face_world.rotated(Vector3.UP, -yaw)
		_faces.append(face)
		_shake_t.append(-1.0)
		_shake_strength.append(1.0)
		_shake_axis.append(Vector3.RIGHT)
		_hanging.append([])
		_sites.append({"at": at, "glb": glb, "perch": false, "kind": kind, "scale": s, "yaw": yaw, "face": face,
			"multi": t.get("node", null), "slot": int(t["index"]), "xform": xform})
		_decor_count += 1
	_build_decor_nuts()

func decor_count() -> int:
	return _decor_count

func excluded() -> Array:
	return _excluded

## ---- v5: the batched hanging nuts -------------------------------------

func _nut_cell(at: Vector3) -> String:
	return "%d_%d" % [int(floor(at.x / NUT_CELL)), int(floor(at.z / NUT_CELL))]

## Where slot `k` of decor tree `index` hangs, in the CARRIER's local
## space (world units, no scale): under the crown's rim, a little inside
## the leaves. The main blob's radius is read off the crown's height
## (top - trunk_h = 1.64 R for the round families' 0.82 squash) rather
## than off crown_r, which the satellite lobes inflate.
func _hang_local(index: int, k: int) -> Transform3D:
	var site: Dictionary = _sites[index]
	var kind: Dictionary = site["kind"]
	var s: float = site["scale"]
	var r_main: float = (float(kind["top"]) - float(kind["trunk_h"])) / 1.64
	var ring: float = r_main * 0.72 * s
	var y: float = (float(kind["trunk_h"]) + 0.25 * r_main) * s - 0.12
	var a: float = TAU * (float(k) + 0.5 + 0.37 * float(index)) / float(WorldSave.TREE_CAPACITY)
	var basis := Basis.from_euler(Vector3(PI, a, 0.0)).scaled(Vector3.ONE * HANG_SCALE)
	return Transform3D(basis, Vector3(cos(a) * ring, y + 0.08 * float(k % 2), sin(a) * ring))

func _build_decor_nuts() -> void:
	_nut_meshes[&"acorn"] = CozyPalette.glb_mesh(CozyPalette.decor_path("acorn_0"))
	_nut_meshes[&"hazelnut"] = CozyPalette.glb_mesh(CozyPalette.decor_path("hazelnut_0"))
	# Count slots per (kind, cell) first: instance_count is written ONCE.
	var counts: Dictionary = {}
	for i in _sites.size():
		if _sites[i]["perch"]:
			continue
		var cell: String = _nut_cell(_sites[i]["at"])
		var keys: Array = []
		for k in WorldSave.TREE_CAPACITY:
			var key: String = "%s|%s" % [nut_kind(i, k), cell]
			counts[key] = int(counts.get(key, 0)) + 1
			keys.append([key, counts[key] - 1])
		_sites[i]["nuts"] = keys
	for key in counts:
		var kind := StringName(key.split("|")[0])
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _nut_meshes[kind]
		multi.instance_count = int(counts[key])
		var node := MultiMeshInstance3D.new()
		node.name = "Nuts_" + key.replace("|", "_")
		node.multimesh = multi
		node.material_override = CozyPalette.decor_material()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_nut_batches[key] = {"node": node, "aabb": AABB(), "n": 0}
	for i in _sites.size():
		if not _sites[i]["perch"]:
			# The batch's AABB is the union of every crown it serves, grown
			# by the wobble; written once, conservative, never trusted to
			# the engine's derivation (a stale one blanks the batch).
			var site: Dictionary = _sites[i]
			var kind: Dictionary = site["kind"]
			var s: float = site["scale"]
			var at: Vector3 = site["at"]
			var box := AABB(at - Vector3(kind["crown_r"] * s, 0.0, kind["crown_r"] * s), Vector3(2.0 * kind["crown_r"] * s, kind["top"] * s + 0.6, 2.0 * kind["crown_r"] * s))
			for entry in site["nuts"]:
				var batch: Dictionary = _nut_batches[entry[0]]
				batch["aabb"] = box if batch["n"] == 0 else (batch["aabb"] as AABB).merge(box)
				batch["n"] += 1
			refresh_stock(i)
	for key in _nut_batches:
		var batch: Dictionary = _nut_batches[key]
		(batch["node"] as MultiMeshInstance3D).multimesh.custom_aabb = (batch["aabb"] as AABB).grow(0.5)

## Writes the three slots of decor tree `index` for `stock` nuts, on the
## carrier's CURRENT transform (so a wobbling tree's nuts wobble).
func _write_decor_nuts(index: int, stock: int) -> void:
	var site: Dictionary = _sites[index]
	if not site.has("nuts"):
		return
	var carrier: Transform3D = _nodes[index].global_transform
	var at: Vector3 = site["at"]
	for k in WorldSave.TREE_CAPACITY:
		var entry: Array = site["nuts"][k]
		var multi: MultiMesh = (_nut_batches[entry[0]]["node"] as MultiMeshInstance3D).multimesh
		if k < stock:
			multi.set_instance_transform(entry[1], carrier * _hang_local(index, k))
		else:
			multi.set_instance_transform(entry[1], Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3(at.x, -3.0, at.z)))

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
	return _sites[index]["at"]

func is_perch(index: int) -> bool:
	return _sites[index]["perch"]

## The seat's height above the ground, in world units.
func seat_height(index: int) -> float:
	return float(_sites[index]["kind"]["seat_y"]) * float(_sites[index]["scale"])

## Stable identity for the save: the site, snapped. Moving a site in
## TREES (or a tree in the layout) makes a new (full) tree, which is what
## a layout edit should do.
func tree_id(index: int) -> String:
	var at: Vector3 = _sites[index]["at"]
	return "%.1f_%.1f" % [at.x, at.z]

## The contract KeepyHopper climbs by, in this tree's carrier space (world
## units: the carrier has no scale). Perchoirs read their constants;
## decor trees their measured kind times their scale, plus the rhythm:
## pulls and durations scale with the trunk actually climbed, and the top
## hop is a spring THROUGH the leaves onto the dome, longer for a taller
## crown.
func climb_spec(index: int) -> Dictionary:
	var site: Dictionary = _sites[index]
	if site["perch"]:
		return {
			"trunk_h": TRUNK_H, "r_base": TRUNK_R_BASE, "r_top": TRUNK_R_TOP,
			"seat": Vector3(0.0, SEAT_Y, 0.0), "face": _faces[index], "foot_gap": FOOT_GAP,
		}
	var kind: Dictionary = site["kind"]
	var s: float = site["scale"]
	var trunk_h: float = float(kind["trunk_h"]) * s
	var seat_y: float = float(kind["seat_y"]) * s
	# The crown as the ellipsoid he scrambles up: bottom pole at trunk_h
	# (by measure_kind's definition), apex at the seat, horizontal
	# semi-axis from the families' 0.82 squash. He climbs its EAST
	# meridian in profile -- from this camera that flank is never behind
	# the leaves (the ray to the camera leaves the ellipsoid at once) --
	# up to CROWN_STOP of the way to the apex, then springs onto the top.
	var b: float = maxf((seat_y - trunk_h) * 0.5, 0.05)
	var crown := {"cy": trunk_h + b, "a": b / 0.82, "b": b}
	var top_y: float = crown["cy"] + b * CROWN_STOP
	var climbed: float = maxf(top_y - 0.34, 0.3)
	var ratio: float = climbed / PERCH_CLIMBED_LENGTH
	var lean: Vector2 = kind["lean"]
	return {
		"trunk_h": trunk_h, "r_base": float(kind["r_base"]) * s, "r_top": float(kind["r_top"]) * s,
		"lean": Vector3(lean.x, 0.0, lean.y) * s, "crown": crown, "top_y": top_y,
		"seat": Vector3(0.0, seat_y, 0.0), "face": _faces[index], "foot_gap": FOOT_GAP,
		"pulls": maxi(2, int(round(5.0 * ratio))), "climb_s": maxf(0.6, 1.6 * ratio), "descend_s": maxf(0.5, 1.3 * ratio),
		"through_leaves": true,
	}

## How far up the crown (as a fraction of its vertical semi-axis above
## the centre) the last grip is: 0.85 is latitude 58 deg, where the flank
## is still a flank (r = 0.53 a) and the spring to the apex is short.
const CROWN_STOP: float = 0.85

## Where the nuts leave this tree, in the carrier's space: [ring radius,
## height]. Perchoirs: HubNuts' own constants (the wreath). Decor: the
## crown's underside rim, where they hang.
func drop_geometry(index: int) -> Array:
	var site: Dictionary = _sites[index]
	if site["perch"]:
		return [HubNuts.DROP_RING_R, HubNuts.DROP_Y]
	var kind: Dictionary = site["kind"]
	var s: float = site["scale"]
	var r_main: float = (float(kind["top"]) - float(kind["trunk_h"])) / 1.64
	return [r_main * 0.8 * s, (float(kind["trunk_h"]) + 0.3 * r_main) * s]

func foot_point(index: int) -> Vector3:
	if _keepy == null:
		return position_of(index)
	return _keepy.tree_foot_point(_nodes[index], climb_spec(index))

## The ground disc a tap on `aim` must land in to mean tree `i`.
func _tap_radius(i: int) -> float:
	var site: Dictionary = _sites[i]
	if site["perch"]:
		return TAP_RADIUS
	return float(site["kind"]["r_base"]) * float(site["scale"]) + DECOR_TAP_MARGIN

## Which tree a tap on `aim` (world, ground) means; -1 for none. The tree
## he is on withdraws (the boat's rule), every other one answers.
func accepts_tap(aim: Vector3) -> int:
	var best: int = -1
	var best_d: float = INF
	for i in _sites.size():
		if i == _occupied:
			continue
		var at: Vector3 = _sites[i]["at"]
		var d: float = Vector2(aim.x - at.x, aim.z - at.z).length()
		if d <= _tap_radius(i) and d < best_d:
			best_d = d
			best = i
	return best

## v5: which tree the FINGER pointed at -- the ground disc as above, OR
## the camera ray through the crown (a sphere: the canopy the player
## sees) or along the trunk (a capsule). A crown at 3 u projects onto the
## ground plane 3.5 u SOUTH of its trunk, so a disc alone made tapping
## what one sees miss. Nearest hit along the ray wins; `include_occupied`
## lets HubTapInput route a tap on the occupied tree to the ground path
## with the tree's own foot as the point (the shake).
func tree_hit(aim: Vector3, origin: Vector3, dir: Vector3, include_occupied: bool = false) -> int:
	var best: int = -1
	var best_t: float = INF
	for i in _sites.size():
		if i == _occupied and not include_occupied:
			continue
		var site: Dictionary = _sites[i]
		var at: Vector3 = site["at"]
		var kind: Dictionary = site["kind"]
		var s: float = site["scale"]
		var t: float = INF
		# Ground disc: scored by its distance along the ray to the ground.
		if Vector2(aim.x - at.x, aim.z - at.z).length() <= _tap_radius(i):
			t = (aim - origin).length() + 0.001
		# Crown sphere.
		var lo: float = float(kind["crown_lo"]) * s
		var top: float = float(kind["top"]) * s
		var radius: float = maxf(float(kind["crown_r"]) * s * 0.92, (top - lo) * 0.5)
		var centre := at + Vector3(0.0, (lo + top) * 0.5, 0.0)
		var ts: float = _ray_sphere(origin, dir, centre, radius)
		if ts >= 0.0:
			t = minf(t, ts)
		# Trunk capsule.
		var tt: float = _ray_segment(origin, dir, at, at + Vector3(0.0, lo, 0.0), float(kind["r_base"]) * s + 0.25)
		if tt >= 0.0:
			t = minf(t, tt)
		if t < best_t:
			best_t = t
			best = i
	return best

static func _ray_sphere(origin: Vector3, dir: Vector3, centre: Vector3, radius: float) -> float:
	var oc: Vector3 = origin - centre
	var b: float = oc.dot(dir)
	var c: float = oc.dot(oc) - radius * radius
	var disc: float = b * b - c
	if disc < 0.0:
		return -1.0
	var t: float = -b - sqrt(disc)
	return t if t >= 0.0 else -1.0

## Distance along the ray to the nearest point within `radius` of the
## segment a-b (a capsule), -1 for a miss. Closest points of a ray and a
## segment: minimise |w + d t - u s|^2 (w = origin - a), which gives
## t = ud s - dw and s = (uw - ud dw) / (uu - ud^2), s clamped to the
## segment, t clamped to the ray.
static func _ray_segment(origin: Vector3, dir: Vector3, a: Vector3, b: Vector3, radius: float) -> float:
	var u: Vector3 = b - a
	var w: Vector3 = origin - a
	var uu: float = u.dot(u)
	var ud: float = u.dot(dir)
	var uw: float = u.dot(w)
	var dw: float = dir.dot(w)
	var den: float = uu - ud * ud
	var s: float = 0.0
	if absf(den) > 1e-6:
		s = clampf((uw - ud * dw) / den, 0.0, 1.0)
	var t: float = ud * s - dw
	if t < 0.0:
		return -1.0
	var closest_on_ray: Vector3 = origin + dir * t
	var closest_on_seg: Vector3 = a + u * s
	return t if closest_on_ray.distance_to(closest_on_seg) <= radius else -1.0

## Is `aim` on the tree he is currently on (the seat's "same tree" test)?
func is_on_occupied(aim: Vector3) -> bool:
	if _occupied < 0:
		return false
	var at: Vector3 = _sites[_occupied]["at"]
	return Vector2(aim.x - at.x, aim.z - at.z).length() <= maxf(_tap_radius(_occupied), 1.2)

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
func shake(index: int, strength: float = 1.0) -> void:
	if index < 0 or index >= _nodes.size():
		return
	_shake_t[index] = 0.0
	_shake_strength[index] = strength
	var f: Vector3 = _nodes[index].global_transform.basis * _faces[index]
	_shake_axis[index] = Vector3(f.z, 0.0, -f.x).normalized()
	if index == _occupied and _keepy != null:
		_keepy.bounce_on_tree()

## v5: the leaves rustle as he springs through them -- the same wobble,
## small, without the seat's bounce (he is in the air). Not started over
## a shake already running.
func rustle(index: int) -> void:
	if index < 0 or index >= _nodes.size() or _shake_t[index] >= 0.0:
		return
	_shake_t[index] = 0.0
	_shake_strength[index] = 0.35
	var f: Vector3 = _nodes[index].global_transform.basis * _faces[index]
	_shake_axis[index] = Vector3(f.z, 0.0, -f.x).normalized()

func is_shaking(index: int) -> bool:
	return index >= 0 and index < _shake_t.size() and _shake_t[index] >= 0.0

## The wobble's current tilt (0 when still), for the nuts' release timing.
func shake_phase(index: int) -> float:
	if not is_shaking(index):
		return 0.0
	return clampf(_shake_t[index] / SHAKE_S, 0.0, 1.0)

## Writes the carrier's tilt back into the drawn instance (decor trees)
## and moves its hanging nuts with it.
func _write_instance(index: int) -> void:
	var site: Dictionary = _sites[index]
	if site["perch"]:
		return
	var multi: MultiMeshInstance3D = site.get("multi", null)
	if multi == null or multi.multimesh == null:
		return
	var node: Node3D = _nodes[index]
	var s: float = site["scale"]
	multi.multimesh.set_instance_transform(int(site["slot"]), Transform3D(node.transform.basis.scaled(Vector3.ONE * s), node.transform.origin))
	_write_decor_nuts(index, WorldSave.tree_stock(tree_id(index)))

func _process(delta: float) -> void:
	for i in _nodes.size():
		if _shake_t[i] >= 0.0:
			_shake_t[i] += delta
			var u: float = _shake_t[i] / SHAKE_S
			var node: Node3D = _nodes[i]
			var yaw: float = _sites[i]["yaw"]
			if u >= 1.0:
				_shake_t[i] = -1.0
				node.rotation = Vector3(0.0, yaw, 0.0)
				_write_instance(i)
				shake_finished.emit(i)
			else:
				var tilt: float = deg_to_rad(SHAKE_TILT_DEG) * _shake_strength[i] * sin(u * TAU * SHAKE_HZ * SHAKE_S) * pow(1.0 - u, 1.4)
				var basis := Basis(Vector3.UP, yaw).rotated(_shake_axis[i], tilt)
				node.transform.basis = basis
				_write_instance(i)
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
## a frame is a millimetre here. Decor trees (v5) are drawn with the
## layout's wind (0.05 over 3.2 u for the plateau, the scatter's own for
## the rest): the same amount, read at the seat's height.
func seat_sway(index: int) -> Vector3:
	var node: Node3D = _nodes[index]
	var look: Dictionary = _weather.call("current_look") if _weather != null and _weather.has_method("current_look") else {}
	var wind_scale: float = float(look.get("wind", 1.0))
	var lean: Vector2 = look.get("lean", Vector2.ZERO)
	var seat_y: float = seat_height(index)
	var w: float = clampf(seat_y / WIND_HEIGHT, 0.0, 1.0)
	w *= w
	var wp: Vector3 = node.global_position
	var phase: float = wp.x * 0.35 + wp.z * 0.27
	var t: float = float(Time.get_ticks_msec()) * 0.001
	var sway: float = sin(t * 1.1 * TAU * 0.5 + phase) * 0.7 + sin(t * 1.1 * TAU * 1.3 + phase * 2.1) * 0.3
	var xz := Vector2(sway, sway * 0.6) * (WIND_AMOUNT * wind_scale * w)
	xz += lean * (w * minf(WIND_AMOUNT * 6.0, 1.0))
	return Vector3(xz.x, 0.0, xz.y)
