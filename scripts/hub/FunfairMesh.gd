extends RefCounted
class_name FunfairMesh
## CH71 -- THE FUNFAIR'S GEOMETRY BUILDER: boxes, tubes and swept rails,
## with the winding decided in ONE place.
##
## The shape is SkateparkMesh's (an instance with scratch arrays, `_tri`
## deciding the index order from a `facing` vector), rewritten for wood
## and steel rather than concrete. A second copy rather than a call into
## SkateparkMesh's underscored helpers: that file's contract is "the
## concrete alone in surface 0, decor in surface 1" and SkatePhysicsProbe
## gates it; the funfair has no such split (its solids are hand-written
## box colliders, D5, published beside the drawn boxes), so borrowing the
## builder would have meant borrowing a contract it does not honour.
##
## ⚠️ WINDING. Godot takes the CLOCKWISE face, seen from the viewer, as
## the FRONT face (CLAUDE.md, CH39). Every triangle here goes through
## `_tri(a, b, c, facing)`, which flips the order when the right-hand
## normal points TOWARD the side the face must be seen from. The decor
## shader is cull_disabled, so a wrong winding would not vanish -- it
## would be SHADED wrong (the toon shader reads NORMAL), which is worse
## because it is plausible. FunfairProbe PHASE C renders the built meshes
## under cull_back and cull_disabled and requires the same pixel count.
##
## Colours are VERTEX colours: CozyPalette.decor_material() reads COLOR,
## and nothing in this hub is lit (CLAUDE.md: "tout asset est unlit").

var _v: PackedVector3Array = PackedVector3Array()
var _n: PackedVector3Array = PackedVector3Array()
var _c: PackedColorArray = PackedColorArray()
var _i: PackedInt32Array = PackedInt32Array()

## Convex pieces this builder has laid down that are SOLID: each entry is
## {"centre": Vector3, "size": Vector3} of an axis-aligned box, in the
## same local frame as the vertices. HubFunfair turns each into a
## BoxShape3D. A box is convex by construction, which is what D5 asks.
var solids: Array = []

## Six sides on a tube: the smallest count whose silhouette is not a bar
## (SkateparkMesh.COPING_SIDES's reasoning), and the rails are 12 cm.
const TUBE_SIDES: int = 6

func _vertex(p: Vector3, normal: Vector3, colour: Color) -> int:
	_v.append(p)
	_n.append(normal.normalized())
	_c.append(colour)
	return _v.size() - 1

## THE ONLY PLACE AN INDEX ORDER IS DECIDED. `facing` is the direction
## the face must be visible FROM.
func _tri(a: int, b: int, c: int, facing: Vector3) -> void:
	var cross := (_v[b] - _v[a]).cross(_v[c] - _v[a])
	if cross.dot(facing) > 0.0:
		var swap := b
		b = c
		c = swap
	_i.append(a)
	_i.append(b)
	_i.append(c)

func _quad(a: int, b: int, c: int, d: int, facing: Vector3) -> void:
	_tri(a, b, c, facing)
	_tri(a, c, d, facing)

func mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_INDEX] = _i
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

## Triangles laid down so far. COUNTED, never predicted: HubFunfair
## publishes the sum and FunfairProbe reads it back off the built meshes.
func triangle_count() -> int:
	return _i.size() / 3

## An axis-aligned box. Each face has its own four vertices so its normal
## and its colour are its own (a shared corner would average a top into a
## side, and the decor shader reads the normal per fragment). `solid`
## registers it as a collision piece.
func box(centre: Vector3, size: Vector3, colour: Color, top: Color, solid: bool = false) -> void:
	var h := size * 0.5
	var corner := {}
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corner[Vector3(sx, sy, sz)] = centre + Vector3(sx * h.x, sy * h.y, sz * h.z)
	var faces := [
		[Vector3.UP, [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)], top],
		[Vector3.DOWN, [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)], colour.darkened(0.35)],
		[Vector3.FORWARD, [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1)], colour],
		[Vector3.BACK, [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)], colour],
		[Vector3.LEFT, [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)], colour],
		[Vector3.RIGHT, [Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)], colour],
	]
	for face in faces:
		var normal: Vector3 = face[0]
		var ring: Array = face[1]
		var col: Color = face[2]
		var idx: Array[int] = []
		for key in ring:
			idx.append(_vertex(corner[key], normal, col))
		_quad(idx[0], idx[1], idx[2], idx[3], normal)
	if solid:
		solids.append({"centre": centre, "size": size})

## A box between two points: a strut of square section `thick`, its long
## axis from `a` to `b`. Built in the strut's own frame and written out
## transformed, so a diagonal brace is one call. Never solid: the
## lattice braces of the tower are decor, the legs are the solids.
func strut(a: Vector3, b: Vector3, thick: float, colour: Color) -> void:
	var axis: Vector3 = (b - a).normalized()
	var ref: Vector3 = Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u: Vector3 = axis.cross(ref).normalized()
	var w: Vector3 = axis.cross(u).normalized()
	var ht := thick * 0.5
	# Four long faces and two caps, each with its own vertices.
	var sides := [[u, w], [w, -u], [-u, -w], [-w, u]]
	for s in sides:
		var n: Vector3 = s[0]
		var t: Vector3 = s[1]
		var p0: Vector3 = a + n * ht + t * ht
		var p1: Vector3 = b + n * ht + t * ht
		var p2: Vector3 = b + n * ht - t * ht
		var p3: Vector3 = a + n * ht - t * ht
		var i0 := _vertex(p0, n, colour)
		var i1 := _vertex(p1, n, colour)
		var i2 := _vertex(p2, n, colour)
		var i3 := _vertex(p3, n, colour)
		_quad(i0, i1, i2, i3, n)
	for end in [[a, -axis], [b, axis]]:
		var centre: Vector3 = end[0]
		var facing: Vector3 = end[1]
		var q0 := _vertex(centre + (u + w) * ht, facing, colour)
		var q1 := _vertex(centre + (u - w) * ht, facing, colour)
		var q2 := _vertex(centre + (-u - w) * ht, facing, colour)
		var q3 := _vertex(centre + (-u + w) * ht, facing, colour)
		_quad(q0, q1, q2, q3, facing)

## A closed swept tube along a polyline of (point, right, up) frames: the
## rails. `frames` is an Array of Transform3D whose origin is the tube's
## centre and whose basis columns are (right, up, forward) at that
## sample; the last frame joins the first (a loop). Six sides.
func swept_tube(frames: Array, radius: float, colour: Color) -> void:
	var count: int = frames.size()
	if count < 2:
		return
	for k in TUBE_SIDES:
		var t0: float = float(k) / float(TUBE_SIDES) * TAU
		var t1: float = float(k + 1) / float(TUBE_SIDES) * TAU
		for s in count:
			var fa: Transform3D = frames[s]
			var fb: Transform3D = frames[(s + 1) % count]
			var na: Vector3 = fa.basis.x * cos(t0) + fa.basis.y * sin(t0)
			var nb: Vector3 = fb.basis.x * cos(t0) + fb.basis.y * sin(t0)
			var ma: Vector3 = fa.basis.x * cos(t1) + fa.basis.y * sin(t1)
			var mb: Vector3 = fb.basis.x * cos(t1) + fb.basis.y * sin(t1)
			var facing: Vector3 = (na + ma).normalized()
			var i0 := _vertex(fa.origin + na * radius, na, colour)
			var i1 := _vertex(fb.origin + nb * radius, nb, colour)
			var i2 := _vertex(fb.origin + mb * radius, mb, colour)
			var i3 := _vertex(fa.origin + ma * radius, ma, colour)
			_quad(i0, i1, i2, i3, facing)

## A flat quad given its four corners in ring order, seen from `facing`.
func flat_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, facing: Vector3, colour: Color) -> void:
	var i0 := _vertex(a, facing, colour)
	var i1 := _vertex(b, facing, colour)
	var i2 := _vertex(c, facing, colour)
	var i3 := _vertex(d, facing, colour)
	_quad(i0, i1, i2, i3, facing)
