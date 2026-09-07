extends RefCounted
class_name HubSurface
## WHERE THE GROUND IS, and the ONE place that answer is written.
##
## =====================================================================
## A QUERY, NOT A RULE
##
## HubRegion answers "can he STAND here" (a shape, in xz). HubSurface
## answers "at what HEIGHT", and nothing else: it refuses no tap, clamps
## nothing, moves nothing. That is the HubWater patron, and it is what
## lets every writer of a ground y call ONE function instead of each
## keeping its own idea of where the floor is.
##
## ⚠️ WITH NO DOMAIN REGISTERED, height_at IS 0.0 EVERYWHERE and this
## whole class is an arithmetic no-op. CH37 (lot 1 SURFACE) ships exactly
## that: the accessor is published and every writer of a ground y is
## wired to it, but the game registers NO domain. Only probes do. The
## relief itself is lot 2 -- and the proof that lot 1 changed nothing is
## that the hub is byte-identical with it merged.
##
## =====================================================================
## ONE SPELLING OF A GROUND POINT
##
## `ground(flat)` -- NOT `height_at` composed with a hand-written
## `Vector3(x, h, z)` at each site. This repo has paid for the other way
## round more than once (a doorstep that did not scale with its cabin,
## two LAKE_WATER_RADIUS for two different bodies): a fact is published
## once and read, never retyped. Every site in KeepyHopper, HubCamera,
## HubWorld and CozyScatter that used to write `Vector3(p.x, 0.0, p.z)`
## calls `ground(p)`.
##
## =====================================================================
## THE SAMPLE READS THE MESH THAT WILL BE DRAWN
##
## A domain owns a GRID, not a formula. The mesh lot 2 builds is built
## FROM that grid with a FIXED triangulation diagonal, and `height_at`
## does the barycentric on the SAME triangulation -- so the feet land
## exactly on the triangle the player sees. An analytic function only
## ever FILLS a grid; it is never consulted at query time. That is the
## "fixture that diverges from the real thing" failure closed in advance.
##
## The grid is PackedFloat32Array, never float64: the mesh is float32,
## and two precisions are two surfaces (the rotation.y float32 trap of
## CH30 cost a whole lot to find). register_domain REFUSES any other
## packed type rather than converting one silently.
##
## =====================================================================
## FRONTIERS, AND WHY THERE IS NO BLEND TO WRITE
##
##   * domain / domain -- FORBIDDEN by contract. Overlapping AABBs are
##     refused at registration, so no point is ever inside two domains
##     and there is nothing to blend.
##   * domain / h = 0 -- CONTINUOUS C0: the height is EXACTLY 0 on the
##     whole perimeter of the AABB, checked at registration on a 0.5 u
##     walk of that perimeter. A STEP is refused, and that is not
##     fussiness: the 0.45 u hop cannot tell a step from a slope, and a
##     cliff with no state of its own is a buried player. The day a step
##     is actually wanted it is a LEVEL TRANSITION -- scripts/nav's job,
##     not this accessor's.
##   * a CozyPalette band may not cross a domain. Measured on the CH35-C
##     test render: with an unlit ground there is no shading on a slope,
##     so a colour boundary running across a hillside is the ONLY line on
##     it, and a bicolour slope reads as two terraces. The band constants
##     are READ from CozyPalette here, never retyped.
##
## normal_at is deliberately absent: the hop is an arc drawn on a base
## LINE (KeepyHopper._apply_hop), so nothing in the hub needs a surface
## normal yet. It arrives with the lot that tilts a body, or not at all.

## Half-widths, in world units, used to keep a domain clear of a palette
## band. Read off CozyPalette rather than retyped -- the shader wobbles
## each frontier inside its own width, so the width IS the exclusion.
const PERIMETER_STEP: float = 0.5
## How flat "flat" has to be on the perimeter for the C0 raccord to hold.
const PERIMETER_TOL: float = 1.0e-4
## Ray march: step, refinement iterations, and how far a ray is followed
## before it is called a miss.
const RAY_STEP: float = 0.25
const RAY_BISECT_ITERS: int = 6
const RAY_MAX_T: float = 200.0

## THE TABLE, and it is a table from the first entry -- the diving board
## shipped a singleton and undoing that cost its own lot.
##
## Each entry: {"name": StringName, "aabb": Rect2 (x, z), "origin":
## Vector2 (the (x, z) of grid node [0, 0]), "pitch": float, "cols": int,
## "rows": int, "grid": PackedFloat32Array of rows * cols}.
static var _domains: Array[Dictionary] = []

## The height of the walkable surface at (x, z). EXACTLY 0.0 outside every
## domain, by contract -- that is what makes the hub with no domain a
## no-op rather than an approximation of one.
static func height_at(flat: Vector3) -> float:
	if _domains.is_empty():
		return 0.0
	var i: int = domain_at(flat)
	if i < 0:
		return 0.0
	return _sample(_domains[i], flat.x, flat.z)

## Index into domains(), or -1 for the base plane. Strict containment, no
## blend: a point is in one domain or in none.
static func domain_at(flat: Vector3) -> int:
	for i in _domains.size():
		var box: Rect2 = _domains[i]["aabb"]
		if flat.x >= box.position.x and flat.x <= box.position.x + box.size.x \
				and flat.z >= box.position.y and flat.z <= box.position.y + box.size.y:
			return i
	return -1

## THE GROUND POINT. The single spelling every writer of a ground y uses.
static func ground(flat: Vector3) -> Vector3:
	return Vector3(flat.x, height_at(flat), flat.z)

## Where a ray meets the ground, or null when it never does.
##
## ⚠️ WITH NO DOMAIN this returns EXACTLY what Plane(Vector3.UP, 0.0)
## .intersects_ray returns -- the same call, not an approximation of it.
## That identity is what lets HubTapInput swap one for the other with a
## byte-identical hub, and SurfaceProbe phase B checks it on 20 rays.
static func intersect_ray(origin: Vector3, dir: Vector3) -> Variant:
	if _domains.is_empty():
		return Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	var d: Vector3 = dir.normalized()
	if d.length_squared() < 0.5:
		return null
	# Already at or under the surface: the hit is where we stand. Written
	# down rather than relied on -- a caller behind the ground would
	# otherwise march away from it and report a miss.
	if origin.y <= _height_xz(origin.x, origin.z):
		return origin
	var t: float = 0.0
	var prev: float = 0.0
	while t < RAY_MAX_T:
		prev = t
		t = minf(t + RAY_STEP, RAY_MAX_T)
		var p: Vector3 = origin + d * t
		if p.y <= _height_xz(p.x, p.z):
			var lo: float = prev
			var hi: float = t
			for _k in RAY_BISECT_ITERS:
				var mid: float = (lo + hi) * 0.5
				var q: Vector3 = origin + d * mid
				if q.y <= _height_xz(q.x, q.z):
					hi = mid
				else:
					lo = mid
			return origin + d * ((lo + hi) * 0.5)
		if t >= RAY_MAX_T:
			break
	return null

## Registers a domain, or REFUSES it and says why. Returns its index, or
## -1. Every refusal is a push_error: a domain that silently failed to
## register would read, in game, as a mountain that is simply not there.
static func register_domain(spec: Dictionary) -> int:
	var name_of: StringName = spec.get("name", &"")
	if name_of == &"":
		push_error("HubSurface: a domain needs a name.")
		return -1
	var pitch: float = float(spec.get("pitch", 0.0))
	var cols: int = int(spec.get("cols", 0))
	var rows: int = int(spec.get("rows", 0))
	if pitch <= 0.0 or cols < 2 or rows < 2:
		push_error("HubSurface: domain %s has a degenerate grid (pitch %.4f, %dx%d)."
			% [name_of, pitch, cols, rows])
		return -1
	# FLOAT32, and checked rather than converted. Two precisions are two
	# surfaces; a silent cast would make the query disagree with the mesh.
	var grid_any: Variant = spec.get("grid", null)
	if typeof(grid_any) != TYPE_PACKED_FLOAT32_ARRAY:
		push_error("HubSurface: domain %s grid must be PackedFloat32Array (got type %d)."
			% [name_of, typeof(grid_any)])
		return -1
	var grid: PackedFloat32Array = grid_any
	if grid.size() != cols * rows:
		push_error("HubSurface: domain %s grid has %d cells for a %dx%d lattice."
			% [name_of, grid.size(), cols, rows])
		return -1
	var origin: Vector2 = spec.get("origin", Vector2.ZERO)
	var box := Rect2(origin, Vector2(float(cols - 1) * pitch, float(rows - 1) * pitch))
	var candidate := {
		"name": name_of, "aabb": box, "origin": origin,
		"pitch": pitch, "cols": cols, "rows": rows, "grid": grid,
	}
	for d in _domains:
		var other: Rect2 = d["aabb"]
		if box.intersects(other, true):
			push_error("HubSurface: domain %s overlaps %s -- domain/domain frontiers are forbidden."
				% [name_of, d["name"]])
			return -1
	var band: String = _band_crossed(box)
	if band != "":
		push_error("HubSurface: domain %s crosses the %s palette band -- a colour line on an unlit slope reads as a terrace."
			% [name_of, band])
		return -1
	var worst: float = _perimeter_worst(candidate)
	if worst >= PERIMETER_TOL:
		push_error("HubSurface: domain %s breaks the C0 raccord -- |h| = %.6f on its perimeter (tolerance %.6f)."
			% [name_of, worst, PERIMETER_TOL])
		return -1
	_domains.append(candidate)
	return _domains.size() - 1

## The registered domains, read-only in intent (probes and lot 2's mesh
## builder read them; nothing else has business here).
static func domains() -> Array[Dictionary]:
	return _domains

## Back to a flat hub. Probes call this between phases; the game never
## does.
static func clear_domains() -> void:
	_domains.clear()

## =====================================================================
## INTERNALS

static func _height_xz(x: float, z: float) -> float:
	return height_at(Vector3(x, 0.0, z))

## Barycentric on the FIXED triangulation: cell corners a(0,0) b(1,0)
## c(0,1) d(1,1), split on the b-c diagonal into (a, b, c) and (b, d, c).
## The mesh lot 2 builds carries the same split, which is the whole point
## -- the query and the drawn triangle are one surface, not two.
static func _sample(d: Dictionary, x: float, z: float) -> float:
	var pitch: float = d["pitch"]
	var origin: Vector2 = d["origin"]
	var cols: int = d["cols"]
	var rows: int = d["rows"]
	var grid: PackedFloat32Array = d["grid"]
	var fx: float = (x - origin.x) / pitch
	var fz: float = (z - origin.y) / pitch
	var c: int = clampi(int(floorf(fx)), 0, cols - 2)
	var r: int = clampi(int(floorf(fz)), 0, rows - 2)
	var u: float = clampf(fx - float(c), 0.0, 1.0)
	var v: float = clampf(fz - float(r), 0.0, 1.0)
	var ha: float = grid[r * cols + c]
	var hb: float = grid[r * cols + c + 1]
	var hc: float = grid[(r + 1) * cols + c]
	var hd: float = grid[(r + 1) * cols + c + 1]
	if u + v <= 1.0:
		return ha + u * (hb - ha) + v * (hc - ha)
	return hd + (1.0 - u) * (hc - hd) + (1.0 - v) * (hb - hd)

## Largest |h| found walking the AABB perimeter at PERIMETER_STEP, corners
## included. The C0 gate.
static func _perimeter_worst(d: Dictionary) -> float:
	var box: Rect2 = d["aabb"]
	var x0: float = box.position.x
	var z0: float = box.position.y
	var x1: float = x0 + box.size.x
	var z1: float = z0 + box.size.y
	var worst: float = 0.0
	var n_x: int = int(ceilf(box.size.x / PERIMETER_STEP))
	for i in n_x + 1:
		var x: float = minf(x0 + float(i) * PERIMETER_STEP, x1)
		worst = maxf(worst, absf(_sample(d, x, z0)))
		worst = maxf(worst, absf(_sample(d, x, z1)))
	var n_z: int = int(ceilf(box.size.y / PERIMETER_STEP))
	for i in n_z + 1:
		var z: float = minf(z0 + float(i) * PERIMETER_STEP, z1)
		worst = maxf(worst, absf(_sample(d, x0, z)))
		worst = maxf(worst, absf(_sample(d, x1, z)))
	return worst

## Which CozyPalette band `box` runs into, or "" for none. The bands are
## READ off CozyPalette (their z and their own half-width, inside which
## the shader wobbles the frontier), never retyped here.
static func _band_crossed(box: Rect2) -> String:
	var z0: float = box.position.y
	var z1: float = z0 + box.size.y
	var strips := {
		"autumn": [CozyPalette.AUTUMN_EDGE_Z, CozyPalette.AUTUMN_EDGE_W],
		"moor": [CozyPalette.MOOR_EDGE_Z, CozyPalette.MOOR_EDGE_W],
		"circuit": [CozyPalette.CIRCUIT_EDGE_Z, CozyPalette.CIRCUIT_EDGE_W],
	}
	for key in strips:
		var edge: float = strips[key][0]
		var half: float = strips[key][1]
		if z1 >= edge - half and z0 <= edge + half:
			return key
	var cove: Vector4 = CozyPalette.COVE_RECT
	if _rect_hits(box, cove, CozyPalette.COVE_EDGE_W):
		return "cove"
	for i in CozyPalette.LAVENDER_FIELDS.size():
		if _rect_hits(box, CozyPalette.LAVENDER_FIELDS[i], 0.0):
			return "lavender field %d" % i
	return ""

## `v` is (x0, z0, x1, z1) as CozyPalette writes its rectangles, grown by
## `pad` on every side.
static func _rect_hits(box: Rect2, v: Vector4, pad: float) -> bool:
	var other := Rect2(
		Vector2(minf(v.x, v.z) - pad, minf(v.y, v.w) - pad),
		Vector2(absf(v.z - v.x) + pad * 2.0, absf(v.w - v.y) + pad * 2.0))
	return box.intersects(other, true)
