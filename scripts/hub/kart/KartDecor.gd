extends Node3D
class_name KartDecor
## What makes the circuit a PLACE and not a ribbon on a lawn: the start
## gantry with its checkered banner (the landmark, and the thing the Lande
## sees over its hedge), the flag poles, tyre stacks on the kerbed corners,
## bunting along the straight, the little paddock tent by the corridor.
##
## All primitives with explicit tessellation, all unlit through the decor
## shader, every repeated thing in a MultiMesh (transform_format FIRST,
## custom_aabb written -- CLAUDE.md). Nothing here has a tap channel or a
## collider; the kart's soft fence is the track's, not the decor's.
##
## Colours are the VOIE A register with the circuit's own accent -- red /
## white of the kerbs, a cream banner, sun-yellow and sky-blue bunting --
## so the zone says "fête foraine" from forty metres and not "asphalt".

const TYRE_COLOURS: Array[Color] = [Color(0.93, 0.35, 0.30), Color(0.96, 0.85, 0.30), Color(0.40, 0.72, 0.92), Color(0.96, 0.96, 0.92)]
const POST: Color = Color(0.92, 0.92, 0.88)
const BANNER: Color = Color(0.96, 0.95, 0.90)
const BANNER_DARK: Color = Color(0.22, 0.20, 0.22)
const TENT_A: Color = Color(0.95, 0.42, 0.36)
const TENT_B: Color = Color(0.97, 0.95, 0.88)
const GANTRY_HEIGHT: float = 5.6
const GANTRY_HALF: float = 5.2
const POLE_HEIGHT: float = 6.4

var _footprints: Array = []

func footprints() -> Array:
	return _footprints

func _mat(colour: Color) -> Material:
	return CozyPalette.decor_material_tinted(colour)

func _node(mesh: Mesh, colour: Color, at: Vector3, name_: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh
	node.position = at
	node.material_override = _mat(colour)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 150.0
	node.visibility_range_end_margin = 5.0
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(node)
	return node

func _box(size: Vector3, colour: Color, at: Vector3, name_: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _node(mesh, colour, at, name_)

func _cyl(radius: float, height: float, colour: Color, at: Vector3, segments: int, name_: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 0
	return _node(mesh, colour, at, name_)

func _multi(mesh: Mesh, xforms: Array, colour: Color, name_: String) -> void:
	if xforms.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = xforms.size()
	var bounds := AABB()
	for i in xforms.size():
		multi.set_instance_transform(i, xforms[i])
		var box: AABB = (xforms[i] as Transform3D) * mesh.get_aabb()
		bounds = box if i == 0 else bounds.merge(box)
	multi.custom_aabb = bounds
	var node := MultiMeshInstance3D.new()
	node.name = name_
	node.multimesh = multi
	node.material_override = _mat(colour)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 150.0
	node.visibility_range_end_margin = 5.0
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(node)

func build(track: KartTrack) -> void:
	_gantry(track)
	_tyres(track)
	_bunting(track)
	_paddock(track)

## The start gantry: two posts either side of the line, a beam, and a
## checkered banner hung from it. Faces along the straight so the
## checker is read by a driver AND, being on the north edge of the
## circuit, by a walker coming down the corridor.
func _gantry(track: KartTrack) -> void:
	var line: Dictionary = track.start_line()
	var c: Vector3 = line["position"]
	var tan: Vector3 = line["tangent"]
	var side := Vector3(tan.z, 0.0, -tan.x)
	var yaw: float = atan2(tan.x, tan.z)
	for s in [-1.0, 1.0]:
		var at: Vector3 = c + side * (GANTRY_HALF * s)
		_cyl(0.22, GANTRY_HEIGHT, POST, at + Vector3(0.0, GANTRY_HEIGHT * 0.5, 0.0), 8, "GantryPost")
		_cyl(0.55, 0.30, BANNER_DARK, at + Vector3(0.0, 0.15, 0.0), 10, "GantryFoot")
		_footprints.append({"position": at, "radius": 1.0})
	var beam := _box(Vector3(GANTRY_HALF * 2.0 + 0.6, 0.36, 0.36), POST, c + Vector3(0.0, GANTRY_HEIGHT + 0.1, 0.0), "GantryBeam")
	beam.rotation.y = yaw + PI * 0.5
	# The banner: a checker of 12 x 3 cells hung under the beam, built as
	# one MultiMesh of dark cells over a cream board.
	var board := _box(Vector3(GANTRY_HALF * 2.0, 1.5, 0.08), BANNER, c + Vector3(0.0, GANTRY_HEIGHT - 0.85, 0.0), "GantryBoard")
	board.rotation.y = yaw + PI * 0.5
	var cell := BoxMesh.new()
	var cw: float = GANTRY_HALF * 2.0 / 12.0
	cell.size = Vector3(cw, 0.5, 0.10)
	var cells: Array = []
	for i in 12:
		for j in 3:
			if (i + j) % 2 == 0:
				var local := Vector3(-GANTRY_HALF + cw * (float(i) + 0.5), 0.5 * (float(j) - 1.0), 0.0)
				var basis := Basis.from_euler(Vector3(0.0, yaw + PI * 0.5, 0.0))
				cells.append(Transform3D(basis, board.position + basis * local))
	_multi(cell, cells, BANNER_DARK, "GantryChecker")
	# Two tall poles behind the gantry, pennants at the top -- the
	# silhouette that clears the hedge from the moor.
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.10
	pole.height = POLE_HEIGHT
	pole.radial_segments = 6
	pole.rings = 0
	var pennant := BoxMesh.new()
	pennant.size = Vector3(0.06, 0.55, 1.4)
	var poles: Array = []
	var flags_a: Array = []
	var flags_b: Array = []
	var k := 0
	for s in [-1.0, 1.0]:
		for d in [-1.0, 1.0]:
			var at: Vector3 = c + side * ((GANTRY_HALF + 2.2) * s) + tan * (3.0 * d)
			poles.append(Transform3D(Basis.IDENTITY, at + Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)))
			var fx := Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), at + Vector3(0.0, POLE_HEIGHT - 0.35, 0.0) + tan * 0.72)
			if k % 2 == 0:
				flags_a.append(fx)
			else:
				flags_b.append(fx)
			_footprints.append({"position": at, "radius": 0.6})
			k += 1
	_multi(pole, poles, POST, "Poles")
	_multi(pennant, flags_a, TYRE_COLOURS[1], "PennantsA")
	_multi(pennant, flags_b, TYRE_COLOURS[2], "PennantsB")

## Tyre stacks on the OUTSIDE of every kerbed bend, three high, one
## colour per stack, cycling. The bend's outside is the side the spine
## curves away from, read from the curvature's sign.
func _tyres(track: KartTrack) -> void:
	var spine: Array[Vector3] = track.ideal_line()
	var n: int = spine.size()
	var tyre := TorusMesh.new()
	tyre.inner_radius = 0.22
	tyre.outer_radius = 0.50
	tyre.rings = 10
	tyre.ring_segments = 6
	var stacks: Array = [[], [], [], []]
	var last_i: int = -100
	var colour_i := 0
	for i in n:
		var a: Vector3 = spine[posmod(i - 3, n)]
		var b: Vector3 = spine[i]
		var c: Vector3 = spine[(i + 3) % n]
		var d1: Vector3 = (b - a).normalized()
		var d2: Vector3 = (c - b).normalized()
		var turn: float = d1.x * d2.z - d1.z * d2.x
		if absf(turn) < 0.16 or i - last_i < 6:
			continue
		last_i = i
		# turn > 0: the heading rotates toward +yaw (left); the outside is
		# then the RIGHT of travel.
		var tan: Vector3 = (d1 + d2).normalized()
		var side := Vector3(tan.z, 0.0, -tan.x)
		var outside: Vector3 = side if turn > 0.0 else -side
		var at: Vector3 = b + outside * (KartTrack.HALF_WIDTH + KartTrack.KERB_WIDTH + 1.5)
		for h in 3:
			stacks[colour_i % 4].append(Transform3D(Basis.IDENTITY, at + Vector3(0.0, 0.22 + 0.44 * h, 0.0)))
		_footprints.append({"position": at, "radius": 0.9})
		colour_i += 1
	for k in 4:
		_multi(tyre, stacks[k], TYRE_COLOURS[k], "Tyres_%d" % k)

## Bunting along the straight: short posts on the LEFT of travel (the
## infield side, seen by the camera behind the kart) with a run of small
## triangular flags between them.
func _bunting(track: KartTrack) -> void:
	var post := CylinderMesh.new()
	post.top_radius = 0.06
	post.bottom_radius = 0.08
	post.height = 2.4
	post.radial_segments = 5
	post.rings = 0
	var flag := PrismMesh.new()
	flag.size = Vector3(0.38, 0.42, 0.04)
	var posts: Array = []
	var flags: Array = [[], [], []]
	var s: float = -30.0
	var start_s: float = 0.0
	var k := 0
	while s <= 40.0:
		var p: Vector3 = track.point_at(start_s + s)
		var tan: Vector3 = track.tangent_at(start_s + s)
		var side := Vector3(tan.z, 0.0, -tan.x)
		var at: Vector3 = p - side * (KartTrack.HALF_WIDTH + KartTrack.KERB_WIDTH + 1.2)
		posts.append(Transform3D(Basis.IDENTITY, at + Vector3(0.0, 1.2, 0.0)))
		if s > -30.0:
			var prev: Vector3 = posts[posts.size() - 2].origin - Vector3(0.0, 1.2, 0.0)
			for f in 6:
				var t: float = (float(f) + 0.5) / 6.0
				var q: Vector3 = prev.lerp(at, t)
				var sag: float = 0.22 * sin(t * PI)
				var basis := Basis.from_euler(Vector3(PI, atan2(tan.x, tan.z) + PI * 0.5, 0.0))
				flags[(k + f) % 3].append(Transform3D(basis, q + Vector3(0.0, 2.25 - sag, 0.0)))
		k += 1
		s += 7.0
	_multi(post, posts, POST, "BuntingPosts")
	_multi(flag, flags[0], TYRE_COLOURS[0], "BuntingA")
	_multi(flag, flags[1], TYRE_COLOURS[1], "BuntingB")
	_multi(flag, flags[2], TYRE_COLOURS[2], "BuntingC")

## The paddock: a striped tent between the corridor and the grid, and a
## sign. Where the walker arrives; the kart is parked beside it.
func _paddock(track: KartTrack) -> void:
	var grid: Dictionary = track.start_pose(0)
	var at: Vector3 = grid["position"] as Vector3
	var yaw: float = grid["yaw"]
	var tan := Vector3(sin(yaw), 0.0, cos(yaw))
	var side := Vector3(tan.z, 0.0, -tan.x)
	# North of the grid (toward the corridor, -side is left of travel =
	# north for a +x straight on this layout).
	var tent: Vector3 = at - side * 8.5 - tan * 4.0
	tent = Vector3(tent.x, 0.0, tent.z)
	var roof := PrismMesh.new()
	roof.size = Vector3(4.6, 1.6, 3.6)
	var r := _node(roof, TENT_A, tent + Vector3(0.0, 2.9, 0.0), "TentRoof")
	r.rotation.y = yaw + PI * 0.5
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.5, 1.62, 3.62)
	var stripes: Array = []
	for i in 4:
		var local := Vector3(-1.8 + 1.2 * float(i), 0.0, 0.0)
		var basis := Basis.from_euler(Vector3(0.0, yaw + PI * 0.5, 0.0))
		stripes.append(Transform3D(basis, r.position + basis * local))
	_multi(stripe, stripes, TENT_B, "TentStripes")
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			_cyl(0.07, 2.2, POST, tent + side * (2.0 * dx) + tan * (1.5 * dz) + Vector3(0.0, 1.1, 0.0), 5, "TentPost")
	_box(Vector3(2.2, 0.8, 1.0), Color(0.62, 0.48, 0.36), tent + Vector3(0.0, 0.4, 0.0), "TentTable")
	_footprints.append({"position": tent, "radius": 3.2})
	# The sign: a post with a board reading as an arrow toward the grid.
	var sign_at: Vector3 = tent + tan * 4.5
	_cyl(0.08, 2.0, Color(0.55, 0.42, 0.30), sign_at + Vector3(0.0, 1.0, 0.0), 5, "SignPost")
	var board := _box(Vector3(1.6, 0.5, 0.08), TENT_B, sign_at + Vector3(0.0, 1.9, 0.0), "SignBoard")
	board.rotation.y = yaw + PI * 0.5
	_footprints.append({"position": sign_at, "radius": 0.6})
