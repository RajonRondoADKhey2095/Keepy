extends Node3D
class_name KartTrack
## The circuit: a closed ribbon, and the ONE place its shape is defined.
##
## Carte-blanche V7. Built from a closed Catmull-Rom through WAYPOINTS,
## exactly the way CozyScatter builds the roads (same spline, same ribbon
## extrusion, same winding -- a ribbon wound the other way disappears
## under cull_back without an error, and this file draws five of them).
##
## What it PUBLISHES, for anyone racing on it:
##
##   ideal_line()     the spine samples, closed -- the lot-2 followers'
##                    input, and the probe's;
##   progress_at(p)   where along the lap a point is: the abscissa s in
##                    [0, length()), the signed lateral offset (negative
##                    = left of travel) and the tangent there;
##   on_track(p)      the surface verdict KartBody drives on;
##   start_pose(i)    the grid: slot i behind the line, alternating sides;
##   fence()          the rectangle a kart is kept inside.
##
## The shape was drawn and measured BEFORE any of this was written (journal
## V7): 230.7 u long, minimum centreline radius 3.40 u at the omega's
## tightest point, x in [-41.1, 40.6], z in [-190.1, -141.6], all inside
## HubRegion's circuit rectangle with 5 u to spare on every side.

## ⚠️ CH31 -- "circuit_1" -> "circuit_1b", and the SHAPE did not change.
## The persistent best lap is keyed on this string (WorldSave.kart_best_ms,
## a dictionary per track), so bumping it starts a fresh record instead of
## leaving a 13 u/s time standing next to 15 u/s ones -- CH31 raised
## KartBody.MAX_SPEED and a record set under the old pace is not comparable
## with one set under the new. Nothing is invalidated: the old key stays in
## the save, untouched, and an older build reading it is unaffected. The
## suffix rather than a new number because it is the same circuit, driven
## faster (the "circuit_1b" pattern proposed in the CH31 brief).
const TRACK_ID: String = "circuit_1b"
const WAYPOINTS: Array[Vector3] = [
	Vector3(-12.0, 0.0, -142.0), Vector3(4.0, 0.0, -142.0), Vector3(26.0, 0.0, -142.0),
	Vector3(35.0, 0.0, -147.0), Vector3(40.0, 0.0, -157.0), Vector3(40.0, 0.0, -172.0),
	Vector3(35.0, 0.0, -184.0), Vector3(24.0, 0.0, -190.0), Vector3(12.0, 0.0, -187.0),
	Vector3(3.0, 0.0, -182.0), Vector3(-7.0, 0.0, -181.0), Vector3(-17.0, 0.0, -187.0),
	Vector3(-28.0, 0.0, -190.0), Vector3(-38.0, 0.0, -185.0), Vector3(-41.0, 0.0, -176.0),
	Vector3(-36.0, 0.0, -169.0), Vector3(-27.0, 0.0, -167.0), Vector3(-20.0, 0.0, -161.0),
	Vector3(-22.0, 0.0, -152.0), Vector3(-19.0, 0.0, -145.0),
]
const PER_SPAN: int = 10
## V8 (lot 2, P3): 3.5 -> 5.0. Four karts abreast on the grid (GRID_LANES)
## and room to pass without a corridor. The CENTRELINE is untouched, so
## a lap time stays a lap on the same 230.7 u -- but a wider ribbon lets
## a driver cut wider, so the persistent best is "comparable, not
## identical" (journal V8). The outermost sample (x = -41.1) now carries
## its kerb to x = -47.1: inside HubRegion's rectangle (-50) and inside
## the fence (FENCE_INSET below was loosened for it).
const HALF_WIDTH: float = 5.0
## Beyond the edge line, still "on track" -- the kerbs and a hand.
const ON_TRACK_MARGIN: float = 0.6
const EDGE_LINE: float = 0.22
const KERB_WIDTH: float = 0.75
## A kerb is laid where the centreline bends harder than this (1/u).
const KERB_CURVATURE: float = 1.0 / 16.0
const ARROW_EVERY: float = 24.0
const Y_RIBBON: float = 0.032
const Y_MARKS: float = 0.040
const Y_TOP: float = 0.046
## Where the start line sits on the spine (the first waypoint is the
## start of the straight; the line is a little further along it).
const START_S: float = 10.0
## How far the fence sits inside HubRegion's rectangle. V8: 2.5 -> 1.5,
## so the widened ribbon's outer kerb (x = -47.1 at the omega) keeps a
## hand between itself and the fence (-48.5).
const FENCE_INSET: float = 1.5
## V8: the grid, four abreast. Lateral offsets (u, right of travel
## positive) per slot, and the stagger per slot along the lap (a hint of
## echelon so "who is ahead" reads at the lights, not a real handicap:
## 0.6 u is a tenth of a kart length).
const GRID_LANES: Array[float] = [-3.6, -1.2, 1.2, 3.6]
const GRID_STAGGER: float = 0.6
const GRID_AHEAD_OF_LINE: float = 5.0

var _spine: Array[Vector3] = []
var _tangent: Array[Vector3] = []
var _cum: PackedFloat64Array = PackedFloat64Array()
var _length: float = 0.0
var _start_index: int = 0

func _ready() -> void:
	_build_spine()
	_build_meshes()

func length() -> float:
	return _length

## The closed centreline, one sample per ~1.15 u. A COPY: readers must not
## be able to bend the track.
func ideal_line() -> Array[Vector3]:
	return _spine.duplicate()

func fence() -> Rect2:
	return Rect2(
		HubRegion.CIRCUIT_MIN.x + FENCE_INSET, HubRegion.CIRCUIT_MIN.y + FENCE_INSET,
		HubRegion.CIRCUIT_MAX.x - HubRegion.CIRCUIT_MIN.x - 2.0 * FENCE_INSET,
		HubRegion.CIRCUIT_MAX.y - HubRegion.CIRCUIT_MIN.y - 2.0 * FENCE_INSET)

## The point of the spine at abscissa `s` (wrapped), and its tangent.
func point_at(s: float) -> Vector3:
	var i: int = _segment_at(s)
	var s0: float = _cum[i]
	var seg: float = _cum[i + 1] - s0
	var t: float = 0.0 if seg <= 0.0 else clampf((fposmod(s, _length) - s0) / seg, 0.0, 1.0)
	return _spine[i].lerp(_spine[(i + 1) % _spine.size()], t)

func tangent_at(s: float) -> Vector3:
	return _tangent[_segment_at(s)]

## ---- V8 (lot 2): what a racing driver reads, published once -------------
## The AI's speed profile is built from the spine's curvature per sample.
## These accessors expose the sample space (index <-> spine abscissa) and
## the curvature the kerbs already use, so KartAiDriver never re-derives a
## geometry this file owns (CLAUDE.md: a fact is published once).

func sample_count() -> int:
	return _spine.size()

## Spine abscissa (point_at space) of sample `i`.
func sample_s(i: int) -> float:
	return _cum[posmod(i, _spine.size())]

## Unsigned curvature (1/u) at sample `i` -- the kerb test's own number.
func curvature(i: int) -> float:
	return _curvature(i)

## Signed curvature at sample `i`: positive where the track bends RIGHT
## of travel (yaw decreasing), negative where it bends left. The sign is
## the cross product of the incoming and outgoing tangents, on the plane.
func signed_curvature(i: int) -> float:
	var n: int = _spine.size()
	var t0: Vector3 = _tangent[posmod(i - 1, n)]
	var t1: Vector3 = _tangent[posmod(i, n)]
	var cross: float = t0.x * t1.z - t0.z * t1.x
	return _curvature(i) * (1.0 if cross > 0.0 else -1.0)

## The axis progress_at()'s `lateral` is measured on: "(tan.z, 0,
## -tan.x)", the +x side of a body facing +z. ⚠️ V7 called this the RIGHT
## of travel; a V8 grid capture (slot 0 at lane -3.6 drawn on the RIGHT
## kerb, chase camera behind the kart) shows it is the driver's LEFT
## under this camera. The number is unchanged everywhere -- only the
## word was wrong -- and every reader that needs a real side (the AI's
## corner bias) is gated on the measured convention, not on this text.
func side_at(s: float) -> Vector3:
	var tan: Vector3 = tangent_at(s)
	return Vector3(tan.z, 0.0, -tan.x)

func _segment_at(s: float) -> int:
	var w: float = fposmod(s, _length)
	var lo: int = 0
	var hi: int = _spine.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if _cum[mid] <= w:
			lo = mid
		else:
			hi = mid - 1
	return lo

## {s, lateral, tangent, index} for the nearest point of the spine to `p`.
## `hint` is the segment index of the previous frame's answer: the search
## is then local (a kart moves a fraction of a segment per frame), and a
## full search only happens with no hint. The abscissa is measured from
## the START LINE, so s = 0 is the line and the lap wraps there.
func progress_at(p: Vector3, hint: int = -1) -> Dictionary:
	var flat := Vector3(p.x, 0.0, p.z)
	var n: int = _spine.size()
	var best_i: int = -1
	var best_d: float = INF
	var best_q: Vector3 = Vector3.ZERO
	var range_lo: int = 0
	var range_hi: int = n
	if hint >= 0:
		range_lo = hint - 12
		range_hi = hint + 13
	for k in range(range_lo, range_hi):
		var i: int = posmod(k, n)
		var a: Vector3 = _spine[i]
		var b: Vector3 = _spine[(i + 1) % n]
		var q: Vector3 = Geometry3D.get_closest_point_to_segment(flat, a, b)
		var d: float = q.distance_squared_to(flat)
		if d < best_d:
			best_d = d
			best_i = i
			best_q = q
	var a2: Vector3 = _spine[best_i]
	var along: float = a2.distance_to(best_q)
	var s: float = fposmod(_cum[best_i] + along - _cum[_start_index], _length)
	var tan: Vector3 = _tangent[best_i]
	var side := Vector3(tan.z, 0.0, -tan.x)
	var lateral: float = (flat - best_q).dot(side)
	return {"s": s, "lateral": lateral, "tangent": tan, "index": best_i, "distance": sqrt(best_d)}

func on_track(p: Vector3, hint: int = -1) -> bool:
	return absf(float(progress_at(p, hint)["lateral"])) <= HALF_WIDTH + ON_TRACK_MARGIN

## Grid slot `index`: GRID_AHEAD_OF_LINE u short of the line, four
## abreast on GRID_LANES (a fifth kart would start a second row), each
## slot GRID_STAGGER further back than the previous one.
func start_pose(index: int) -> Dictionary:
	var n: int = GRID_LANES.size()
	var row: int = index / n
	var s: float = _cum[_start_index] - GRID_AHEAD_OF_LINE - GRID_STAGGER * float(index) - 4.0 * float(row)
	var tan: Vector3 = tangent_at(s)
	var side := Vector3(tan.z, 0.0, -tan.x)
	var lane: float = GRID_LANES[index % n]
	var at: Vector3 = point_at(s) + side * lane
	return {"position": Vector3(at.x, 0.0, at.z), "yaw": atan2(tan.x, tan.z)}

## The spine abscissa of the start line: progress_at() measures from the
## line, point_at() from the spine's first sample; this is the offset
## between the two, published so no reader re-derives it.
func start_line_offset() -> float:
	return _cum[_start_index]

## The start line's centre and tangent (the gantry stands here).
func start_line() -> Dictionary:
	var s: float = _cum[_start_index]
	return {"position": point_at(s), "tangent": tangent_at(s)}

## The ground the scatter must leave alone: the ribbon plus a verge.
func blocks(p: Vector3, own_radius: float) -> bool:
	return absf(float(progress_at(p)["lateral"])) <= HALF_WIDTH + KERB_WIDTH + 1.0 + own_radius

## ---- spine ---------------------------------------------------------------

func _build_spine() -> void:
	_spine.clear()
	_tangent.clear()
	var n: int = WAYPOINTS.size()
	for i in n:
		var p0: Vector3 = WAYPOINTS[posmod(i - 1, n)]
		var p1: Vector3 = WAYPOINTS[i]
		var p2: Vector3 = WAYPOINTS[(i + 1) % n]
		var p3: Vector3 = WAYPOINTS[(i + 2) % n]
		for k in PER_SPAN:
			var t := float(k) / PER_SPAN
			var t2 := t * t
			var t3 := t2 * t
			var q: Vector3 = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			_spine.append(Vector3(q.x, 0.0, q.z))
	var count: int = _spine.size()
	_cum.resize(count + 1)
	_cum[0] = 0.0
	for i in count:
		var a: Vector3 = _spine[i]
		var b: Vector3 = _spine[(i + 1) % count]
		_cum[i + 1] = _cum[i] + a.distance_to(b)
		_tangent.append((b - a).normalized())
	_length = _cum[count]
	# The start line is the sample nearest START_S along the spine from
	# the first waypoint.
	_start_index = 0
	for i in count:
		if _cum[i] <= START_S:
			_start_index = i

## ---- meshes --------------------------------------------------------------

## Per-sample edge points, shared by neighbouring quads (the hatching fix
## CozyScatter documents), at `offset` from the centreline (positive =
## right of travel) and `y`.
func _edge(i: int, offset: float, y: float) -> Vector3:
	var n: int = _spine.size()
	var prev: Vector3 = _spine[posmod(i - 1, n)]
	var next: Vector3 = _spine[(i + 1) % n]
	var tan: Vector3 = (next - prev).normalized()
	var side := Vector3(tan.z, 0.0, -tan.x)
	var c: Vector3 = _spine[i]
	return Vector3(c.x + side.x * offset, y, c.z + side.z * offset)

## A quad between samples i and i+1 spanning [a, b] across the ribbon,
## with the winding CozyScatter._extrude_path uses (front face up).
func _quad(st: SurfaceTool, i: int, a: float, b: float, y: float) -> void:
	var n: int = _spine.size()
	var j: int = (i + 1) % n
	# left = the smaller offset (toward -side), right = the larger.
	var l0 := _edge(i, a, y)
	var r0 := _edge(i, b, y)
	var l1 := _edge(j, a, y)
	var r1 := _edge(j, b, y)
	# CozyScatter's left is c + n*w with n = (-tan.z, 0, tan.x), i.e. the
	# LEFT of travel; its order (left, right, left1, right1, left1, right)
	# is reproduced with the same sides.
	for v in [l0, r0, l1, r1, l1, r0]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)

func _curvature(i: int) -> float:
	var n: int = _spine.size()
	var a: Vector3 = _spine[posmod(i - 1, n)]
	var b: Vector3 = _spine[i]
	var c: Vector3 = _spine[(i + 1) % n]
	var ab: float = a.distance_to(b)
	var bc: float = b.distance_to(c)
	var ca: float = c.distance_to(a)
	var s: float = (ab + bc + ca) * 0.5
	var area2: float = maxf(s * (s - ab) * (s - bc) * (s - ca), 0.0)
	var area: float = sqrt(area2)
	if area < 0.0001:
		return 0.0
	return 4.0 * area / (ab * bc * ca)

func _commit(st: SurfaceTool, name_: String, colour: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = st.commit()
	node.material_override = CozyPalette.decor_material_tinted(colour)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 96 % hazed at 150 u (CozyPalette.HAZE_DENSITY): nothing of this is
	# seen from the plateau, and the whole zone is culled by distance like
	# the moor's scatter (CozyScatter._flush).
	node.visibility_range_end = 125.0
	node.visibility_range_end_margin = 5.0
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(node)

func _build_meshes() -> void:
	var n: int = _spine.size()
	var ribbon := SurfaceTool.new()
	ribbon.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red := SurfaceTool.new()
	red.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := SurfaceTool.new()
	white.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cream := SurfaceTool.new()
	cream.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kerb_count := 0
	for i in n:
		_quad(ribbon, i, -HALF_WIDTH - EDGE_LINE, HALF_WIDTH + EDGE_LINE, Y_RIBBON)
		_quad(edge, i, -HALF_WIDTH - EDGE_LINE, -HALF_WIDTH, Y_MARKS)
		_quad(edge, i, HALF_WIDTH, HALF_WIDTH + EDGE_LINE, Y_MARKS)
		# Kerbs on both edges through the bends, alternating red / white
		# every sample (~1.15 u), the way a real kerb is painted.
		if _curvature(i) > KERB_CURVATURE:
			kerb_count += 1
			var st: SurfaceTool = red if i % 2 == 0 else white
			_quad(st, i, -HALF_WIDTH - EDGE_LINE - KERB_WIDTH, -HALF_WIDTH - EDGE_LINE, Y_MARKS)
			_quad(st, i, HALF_WIDTH + EDGE_LINE, HALF_WIDTH + EDGE_LINE + KERB_WIDTH, Y_MARKS)
	# The start line: a checkered band two samples long, 6 cells across,
	# and the direction arrows every ARROW_EVERY u.
	var cells := 6
	var cell_w: float = 2.0 * HALF_WIDTH / cells
	for k in 2:
		var i: int = (_start_index + k) % n
		for c in cells:
			if (c + k) % 2 == 0:
				_quad(cream, i, -HALF_WIDTH + c * cell_w, -HALF_WIDTH + (c + 1) * cell_w, Y_TOP)
	var s: float = ARROW_EVERY * 0.5
	while s < _length - ARROW_EVERY * 0.5:
		var seg: int = posmod(_segment_at(_cum[_start_index] + s), n)
		_arrow(cream, seg)
		s += ARROW_EVERY
	_commit(ribbon, "Ribbon", CozyPalette.TRACK)
	_commit(edge, "EdgeLines", CozyPalette.TRACK_EDGE)
	_commit(red, "KerbRed", CozyPalette.KERB_RED)
	_commit(white, "KerbWhite", CozyPalette.KERB_WHITE)
	_commit(cream, "Marks", CozyPalette.TRACK_EDGE)
	print("KartTrack: %d samples, %.1f u, %d kerb samples, start at sample %d" % [n, _length, kerb_count, _start_index])

## A chevron on the surface at sample `i`, pointing along travel: two
## bars meeting at the tip, each a thin quad, wound like everything else
## (front face up).
func _arrow(st: SurfaceTool, i: int) -> void:
	var c: Vector3 = _spine[i]
	var tan: Vector3 = _tangent[i]
	var side := Vector3(tan.z, 0.0, -tan.x)
	var tip: Vector3 = c + tan * 1.6
	var back_l: Vector3 = c - side * 1.4
	var back_r: Vector3 = c + side * 1.4
	var bar: float = 0.5
	for pair in [[back_l, tip], [back_r, tip]]:
		var a: Vector3 = pair[0]
		var b: Vector3 = pair[1]
		var d: Vector3 = (b - a).normalized()
		var nrm := Vector3(d.z, 0.0, -d.x) * (bar * 0.5)
		var v0 := Vector3(a.x - nrm.x, Y_TOP, a.z - nrm.z)
		var v1 := Vector3(a.x + nrm.x, Y_TOP, a.z + nrm.z)
		var v2 := Vector3(b.x - nrm.x, Y_TOP, b.z - nrm.z)
		var v3 := Vector3(b.x + nrm.x, Y_TOP, b.z + nrm.z)
		# (left, right, left1, right1, left1, right) with left = -side.
		for v in [v0, v1, v2, v3, v2, v1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
