extends MeshInstance3D
class_name HubMountain
## THE FIRST REAL DOMAIN -- the west ridge, and nothing else on it.
##
## =====================================================================
## WHAT THIS LOT IS, AND WHAT IT DELIBERATELY IS NOT
##
## CH37 published HubSurface with NO domain registered: the accessor was
## wired everywhere and the hub stayed byte-identical because height_at
## answered 0.0 at every point. This node registers the first domain that
## is not a probe fixture, and it registers ONE THING: a bare walkable
## relief. No scatter, no prop, no water, no critter, no transport -- the
## whole point of shipping it alone is that Mathieu can read a device FPS
## against a KNOWN triangle delta before anything is planted on it.
##
## =====================================================================
## WHERE, AND WHY THERE
##
## Mathieu's direction: "past the trees visible from (-34.6, 35)", an
## in-game overlay reading at the plateau's north-west corner. The camera
## never yaws (HubCamera.OFFSET), so from that station the eye runs down
## -z along the plateau's west flank, and what closes that view is the
## forest wall CozyScatter plants outside the region.
##
## HubRegion.MOUNTAIN_MIN/MAX -- x [-63, -35], z [-12, 18] -- is the
## rectangle that direction admits. Every clearance below was MEASURED on
## the shipped layout and the shipped constants, not assumed:
##
##   layout props            westernmost entry is x = -34.9, and the
##                           domain starts at x = -35: it holds no prop
##   small lake bank         centre (-25.1, -5.3), LAKE_BANK_RADIUS 9.05
##                           -> reaches x = -34.15, clear by 0.85 u
##   spawn-lake lobe         x in [-22, -2]; great lake x in [-0.5, 31.5]
##   autumn palette band     z in [-46, -32] (AUTUMN_EDGE_Z +- _W); the
##                           domain stops at z = -12, clear by 20 u
##   moor / circuit / cove   z <= -79, or x >= 41: nowhere near
##   lavender fields         x in [-32, -8] and [22, 36]: nowhere near
##   zone AABBs              autumn is x in [-33, 33] and the domain is
##                           WEST of it; every other zone is past z = -86
##   north lobe              (0, 35) r 12 and the structure lobe (25.2,
##                           35) r 3 -- both east of x = -12
##   decor hill ring         CozyScatter._hills throws at r in [78, 176]
##                           from the centre; the furthest corner here is
##                           r = 65.5
##
## Its east edge IS the plateau's west edge (x = -35). That is not an
## accident to tidy up later: the perimeter height is exactly 0, so a walk
## crosses x = -35 with no step, and the ridge needs no gate, no corridor
## and no zone number of its own.
##
## FROM MATHIEU'S STATION: the summit sits 32 u down-range and 14.4 u to
## the side, and a frame that never yaws is 0.414 * (D + 8.9) = 16.9 u
## wide there -- inside it. It also stands PAST the wall's near band, so
## the trees he was looking at are between him and the ridge, which is
## the composition the direction asked for.
##
## ⚠️ WHAT IT MOVES THAT THIS LOT DID NOT WRITE: `CozyScatter._forest_wall`
## refuses any candidate with `HubRegion.contains()` true, so making this
## rectangle walkable REMOVES the wall trees that used to stand on it, and
## pushes the rest 2 u (WALL_CLEARANCE) off its rim. No line of CozyScatter
## changed; the region it reads did. West of x = -63 the wall box ends at
## WALL_OUTER = 62, so the ridge's own west crest closes against SKY and
## the far decor hill ring, which is the "crest against a background"
## CH35-C asks for and not a wall of green.
##
## =====================================================================
## THE SHAPE, AND THE FOUR NUMBERS THAT BOUND IT
##
## CH35-C measured what an UNLIT ground can say about a slope: nothing.
## There is no shading on a hillside, so a flank has no cue of its own and
## reads only as a silhouette against something further away. That is why
## this relief is a HILL and not a peak:
##
##   * every walkable slope <= 30 deg. MEASURED on the drawn triangles:
##     27.834 deg worst, at (-53, -3). Nothing on this domain is steeper,
##     so the 45 deg short-flank allowance and the 55 deg cozy_ground
##     ceiling are both moot here -- there is no unwalkable flank at all;
##   * highest point 4.500 u, under the 9 u a foot 30 u away can still
##     see (CH36 FRAME_TOP_AT_APLOMB = 7.968: a taller summit leaves the
##     frame of a camera that never tilts);
##   * the 28 u span is what CAPS that height, and the cap comes from
##     HubRegion's worst-crossing arithmetic, not from taste: a raised
##     cosine of radius R and height A peaks at A*PI/(2R), so R = 14 and
##     30 deg admit A <= 5.15 and 4.5 leaves the margin the probe gates;
##   * the perimeter is 0 EXACTLY -- both bumps have COMPACT SUPPORT that
##     fits inside the AABB, value AND first derivative zero at r = R, so
##     the raccord with the flat hub is C1 and not merely the C0
##     register_domain demands. A gaussian would have needed a windowing
##     term, and that term is itself a slope nobody asked for.
##
## The second bump is small and set 12.04 u away from the first ON PURPOSE:
## two raised cosines that overlap ADD THEIR GRADIENTS, and the versions
## that put a 1.5 u bump inside the big one's flank measured 33.0 deg --
## over the ceiling with both bumps individually well under it. A silhouette
## with two summits was worth one more entry; it was not worth spending the
## slope budget in the overlap.
##
## The two raised-cosine bumps, as (centre x, centre z, radius, height).
## A TABLE FROM THE FIRST ENTRY, on the terms this repo already paid for.
const BUMPS: Array[Vector4] = [
	Vector4(-49.0, 3.0, 14.0, 4.5),
	Vector4(-57.0, 12.0, 6.0, 1.4),
]

## Lattice pitch, in world units. 1.0 rather than anything finer: the
## ground is UNLIT, so a facet has no shading edge to give itself away and
## the only thing pitch buys is silhouette resolution. 28 x 30 u of ridge at
## 1.0 u is 1 680 triangles -- a sixth of the 10 000 this lot is allowed
## to add, with the rest left as headroom rather than spent on facets no
## renderer here can show.
const PITCH: float = 1.0

## The ceiling this lot gates itself on, from its first commit: the bare
## relief may not add more than this to the worst frame measured in the
## sandbox, at any station or azimuth.
const TRIANGLE_BUDGET: int = 10000

const DOMAIN_NAME: StringName = &"west_ridge"

func _ready() -> void:
	if register() < 0:
		return
	mesh = build_mesh()
	set_surface_override_material(0, CozyPalette.ground_material())

## Height of the relief at a flat point, in world units. FILLS THE GRID
## AND NOTHING ELSE -- no query path calls this, by contract: the grid the
## mesh is built from is the one surface, and an analytic second opinion
## is exactly the "fixture that diverges from the real thing" this repo
## closed in advance.
static func height(x: float, z: float) -> float:
	var h: float = 0.0
	for bump in BUMPS:
		var r: float = Vector2(x - bump.x, z - bump.y).length() / bump.z
		if r < 1.0:
			h += bump.w * 0.5 * (1.0 + cos(PI * r))
	return h

## Columns and rows of the lattice, derived from the region's rectangle so
## the AABB is a second reading of HubRegion's numbers and never a third
## spelling of them.
static func columns() -> int:
	return int(roundf((HubRegion.MOUNTAIN_MAX.x - HubRegion.MOUNTAIN_MIN.x) / PITCH)) + 1

static func rows() -> int:
	return int(roundf((HubRegion.MOUNTAIN_MAX.y - HubRegion.MOUNTAIN_MIN.y) / PITCH)) + 1

## The lattice, row-major, PackedFloat32Array because HubSurface refuses
## anything else and because the mesh is float32: two precisions would be
## two surfaces.
static func build_grid() -> PackedFloat32Array:
	var cols: int = columns()
	var n_rows: int = rows()
	var grid := PackedFloat32Array()
	grid.resize(cols * n_rows)
	for r in n_rows:
		var z: float = HubRegion.MOUNTAIN_MIN.y + float(r) * PITCH
		for c in cols:
			var x: float = HubRegion.MOUNTAIN_MIN.x + float(c) * PITCH
			grid[r * cols + c] = height(x, z)
	return grid

## Registers the domain with HubSurface, or returns -1 having said why.
## Idempotent: a second call with the domain already registered is a
## no-op, so a probe that registers by hand and then loads the scene does
## not trip the overlap refusal.
static func register() -> int:
	for i in HubSurface.domains().size():
		if HubSurface.domains()[i]["name"] == DOMAIN_NAME:
			return i
	return HubSurface.register_domain({
		"name": DOMAIN_NAME,
		"origin": HubRegion.MOUNTAIN_MIN,
		"pitch": PITCH,
		"cols": columns(),
		"rows": rows(),
		"grid": build_grid(),
	})

## The drawn surface, built from THE REGISTERED GRID -- never from
## `height` a second time. Reading the grid back out of HubSurface is what
## makes "the feet are on the triangle you see" a fact rather than a
## claim: if the two ever disagreed, they would have to disagree about the
## same array.
static func build_mesh() -> ArrayMesh:
	var index: int = register()
	if index < 0:
		push_error("HubMountain: no domain to draw -- registration was refused.")
		return ArrayMesh.new()
	var domain: Dictionary = HubSurface.domains()[index]
	var grid: PackedFloat32Array = domain["grid"]
	var origin: Vector2 = domain["origin"]
	var pitch: float = domain["pitch"]
	var cols: int = domain["cols"]
	var n_rows: int = domain["rows"]

	var verts := PackedVector3Array()
	verts.resize(cols * n_rows)
	for r in n_rows:
		var z: float = origin.y + float(r) * pitch
		for c in cols:
			verts[r * cols + c] = Vector3(origin.x + float(c) * pitch, grid[r * cols + c], z)

	# (a, c, b) then (b, c, d): the b-c diagonal HubSurface._sample splits
	# on, and the winding whose cross product points at +Y. Both halves are
	# checked by MountainProbe rather than left to this comment.
	var indices := PackedInt32Array()
	indices.resize((cols - 1) * (n_rows - 1) * 6)
	var k: int = 0
	for r in n_rows - 1:
		for c in cols - 1:
			var a: int = r * cols + c
			var b: int = a + 1
			var cc: int = a + cols
			var d: int = cc + 1
			indices[k] = a
			indices[k + 1] = cc
			indices[k + 2] = b
			indices[k + 3] = b
			indices[k + 4] = cc
			indices[k + 5] = d
			k += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

## How many triangles the ridge draws. Published rather than recomputed at
## each reading site -- the budget gate and the report quote the same one.
static func triangle_count() -> int:
	return (columns() - 1) * (rows() - 1) * 2
