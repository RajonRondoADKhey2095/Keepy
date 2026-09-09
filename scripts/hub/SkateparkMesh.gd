extends RefCounted
class_name SkateparkMesh
## CH53 -- THE FIVE SKATEPARK MODULES, BUILT BY CODE.
##
## =====================================================================
## WHY PROCEDURAL AND NOT MESHY (Mathieu's call, 8 septembre 2026)
##
## CH51 section 5 planned a Meshy lot for these five objects. That lot was
## dropped for one reason and it is not a technical one: a Meshy asset
## reaches this repo as a 12-27 Mo binary that a session cannot carry, so
## every module would have cost Mathieu a manual upload through the GitHub
## web UI. Five modules, five uploads, and a placeholder that has to be
## kept in step with each of them by hand.
##
## What that costs us in exchange is the ONE thing Meshy is good at:
## organic silhouette. A concrete ramp does not have one. It is a swept
## profile, a box and a dish -- three things that are exactly describable
## in a hundred lines, and describable ONCE rather than measured back off
## an imported mesh.
##
## =====================================================================
## WINDING -- AND WHY NOTHING HERE WRITES AN INDEX ORDER BY HAND
##
## CLAUDE.md, CH39, paid at the cost of a whole invisible hillside:
##
##   "Godot tient les faces HORAIRES pour faces avant" -- so for a
##   surface a player looks DOWN on (a deck, a ground plane), the
##   right-hand cross product (b-a)x(c-a) must come out at -Y, which is
##   the NEGATION of the mathematical convention anyone would write by
##   reflex. MountainProbe asserted the mathematical one on 1 680
##   triangles, was green 1 680 times out of 1 680, and the engine threw
##   the whole ridge away.
##
## So no builder below ever chooses an index order. Every face goes
## through `_tri(a, b, c, facing)` which is handed the direction the face
## must be VISIBLE from and swaps two corners when the cross product does
## not agree. The convention lives in exactly one function, and that
## function is four lines long.
##
## ⚠️ AND THE RULE IS STILL NOT TRUSTED. CH39's other half is that an
## orientation assertion cannot be re-read, it has to be RENDERED:
## `cull_back` against `cull_disabled` on the same frame, and if the two
## do not cover the same pixels the mesh is inside out. SkateparkProbe
## PHASE W does exactly that, on the delivered park, and it has no
## threshold to tune. The decor shader this park is drawn with is
## `cull_disabled`, so a mesh built inside out here would look PERFECT
## today and vanish the day anything gives it a culling material -- which
## is precisely the trap CH39 describes.
##
## =====================================================================
## COLOUR IS BAKED PER VERTEX, ONCE
##
## CLAUDE.md: "la couleur qu'un .glb porte est littéralement celle qui
## s'affiche" and "un tint qui multiplie la couleur de sommet ne peut pas
## recolorer". The same holds for a mesh built here: the concrete greys
## are written into ARRAY_COLOR, and the material's tint stays white. A
## module that wants to read as poured concrete does so because its
## vertices ARE concrete-coloured, not because something downstream
## multiplies it.
##
## =====================================================================
## THE TRIANGLE BUDGET
##
## CH52 concluded 6 000 primitives for the five modules, gated from the
## first commit, and conditioned on the same commit financing them. The
## five below come to a small fraction of that: `TRIANGLES` is published
## by each builder, summed by HubSkatepark, and gated by SkateparkProbe
## against BUDGET_TRIS. The ceiling is not a target -- every triangle
## spent here has to be bought back out of the grass carpet, so the park
## is deliberately built cheap and the ceiling stays where CH52 put it.

## CH52's ceiling for the whole park, carried here so the number lives
## next to the geometry that has to respect it and not only in a probe.
const BUDGET_TRIS: int = 6000

## =====================================================================
## CONCRETE, AND WHY IT IS TWO GREYS AND NOT ONE
##
## MEASURED CONSTRAINT, not taste: CLAUDE.md's palette rule says the hub
## ground renders at L = 0.0799 and that "aucun ton MOYEN ne passe" a
## 3:1 ratio against it -- a mid grey slab on grass separates by HUE and
## SILHOUETTE, which this repo does not gate, and not by luminance.
##
## What DOES gate here is CH35-C's other finding, and it is the one that
## decides these numbers: this project's assets are UNLIT and nothing
## post-processes the frame, so a flat face has NO shading cue at all.
## A single grey would render a quarterpipe as one continuous silhouette
## with no readable transition. The lip band is therefore a SECOND colour
## on the vertices that form the coping, which is the one place a rider
## reads the shape from -- an edge highlight that costs zero geometry
## because it rides on vertices the surface already has.
const CONCRETE: Color = Color(0.62, 0.63, 0.64)
## The deck / flat top: a touch lighter, so a horizontal surface reads
## apart from a vertical one under a shader that gives it no help.
const CONCRETE_DECK: Color = Color(0.70, 0.71, 0.72)
## The coping lip and the rail: near-white, the way a worn steel coping
## actually reads, and the only high-luminance note in the park.
const COPING: Color = Color(0.86, 0.87, 0.88)
## Shadowed undersides and the inside of the bowl below the transition.
const CONCRETE_DARK: Color = Color(0.47, 0.48, 0.50)

## =====================================================================
## THE BUILDER'S SCRATCH STATE
##
## An instance, not statics: two builders running at once on shared
## statics is the "nohup ... &" defect of CLAUDE.md in another costume,
## and an instance costs nothing.

var _v: PackedVector3Array = PackedVector3Array()
var _n: PackedVector3Array = PackedVector3Array()
var _c: PackedColorArray = PackedColorArray()
var _i: PackedInt32Array = PackedInt32Array()

func _vertex(p: Vector3, normal: Vector3, colour: Color) -> int:
	_v.append(p)
	_n.append(normal.normalized())
	_c.append(colour)
	return _v.size() - 1

## THE ONLY PLACE AN INDEX ORDER IS DECIDED. `facing` is the direction the
## face must be visible FROM. Godot's front face is the clockwise one seen
## from the viewer, so the right-hand cross product of a visible face
## points AWAY from the viewer -- see the header. A caller never reasons
## about this; it names the side it wants to see and is done.
func _tri(a: int, b: int, c: int, facing: Vector3) -> void:
	var cross := (_v[b] - _v[a]).cross(_v[c] - _v[a])
	if cross.dot(facing) > 0.0:
		var swap := b
		b = c
		c = swap
	_i.append(a)
	_i.append(b)
	_i.append(c)

## A quad given in ring order (a-b-c-d round the rim), visible from `facing`.
func _quad(a: int, b: int, c: int, d: int, facing: Vector3) -> void:
	_tri(a, b, c, facing)
	_tri(a, c, d, facing)

func _mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_INDEX] = _i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Triangles this builder has laid down. Read by HubSkatepark so the park
## total is COUNTED rather than predicted -- CLAUDE.md: a number that has
## no source in the repo has no value.
func triangle_count() -> int:
	return _i.size() / 3

# =====================================================================
# A BOX. The workhorse: the rail's beam and legs, the funbox's deck.
# `centre` is the box's middle, `size` its full extent.

func _box(centre: Vector3, size: Vector3, colour: Color, top_colour: Color) -> void:
	var h := size * 0.5
	# The eight corners, indexed by sign bits so the faces below can be
	# written as rings without a table of literals to mistype.
	var corner := {}
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corner[Vector3(sx, sy, sz)] = centre + Vector3(sx * h.x, sy * h.y, sz * h.z)
	# Each face is built with its OWN four vertices so its normal and its
	# colour are its own -- a shared corner would average a top into a
	# side, and this shader reads the normal per fragment.
	var faces := [
		[Vector3.UP, [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)], top_colour],
		[Vector3.DOWN, [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)], CONCRETE_DARK],
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

# =====================================================================
# THE QUARTERPIPE
#
# A quarter-circle transition swept across a width: flat and tangent to
# the ground at the bottom, vertical at the lip. `height` is both the
# rise and the transition radius, which is what makes it a QUARTER pipe
# and not an arbitrary curve -- one number, no second spelling.
#
# Local frame: the rider rolls along -Z toward the ramp, the wall rises
# toward +Z, the deck is at the top. Width runs along X.
#
# SEGMENTS is chosen by the facet deviation this repo already gates on
# (CLAUDE.md: "la déviation de facette est ABSOLUE et grandit avec le
# rayon"). At radius 2.0 and 12 segments each step spans 7.5 deg and the
# sagitta is 2.0 * (1 - cos(3.75 deg)) = 0.0043 u -- four millimetres,
# an order of magnitude under the 0.027 the repo already ships on a
# 3.2 u disc.

const QP_SEGMENTS: int = 12

## =====================================================================
## ⚠️ CH60 -- THE PROFILE WAS INVERTED, AND THE MESH CARRIED ITS OWN
## WITNESS AGAINST ITSELF FOR SEVEN LOTS
##
## The line below used to read
##
##     prof.append(Vector2(height - height * cos(a), height * sin(a)))
##
## and `prof.x` is the Z of the vertex while `prof.y` is its Y (see the
## two `_vertex` calls). That spelling puts z = h(1 - cos a) and
## y = h sin a, whose tangent is dy/dz = cot(a): VERTICAL where the rider
## arrives and HORIZONTAL at the lip. The exact transpose of a
## quarterpipe -- a convex hump, not a transition -- and the comment
## above it described the shape it was not building.
##
## ⚠️ AND IT IS NOT AN OPINION ABOUT WHAT THE MODULE SHOULD LOOK LIKE.
## The VERTEX NORMALS in the very next loop were never changed and are
## the corrected profile's normals, exactly: `nz` runs (0, 1, 0) at the
## foot to (0, 0, -1) at the lip, i.e. flat-then-vertical. Measured on
## the delivered mesh before the fix (QpReconProbe, CH60): the stored
## normal disagreed with the TRUE face normal by up to 86.25 deg, and the
## disagreement was an EXACT MIRROR -- the stored normal at facet k was
## the true normal at facet (25 - k). Two readings of one shape, one of
## which had been transposed. The decor shader is a toon shader that
## reads NORMAL (`cozy_decor.gdshader`: ndl = dot(n, sun_dir)), so the
## park has been SHADED as a quarterpipe while being GEOMETRICALLY a
## hump. The fix makes the two agree; it does not choose between them.
##
## Everything else about the module is untouched by it: the endpoints
## (0, 0) and (height, height) are the same, so the AABB, the footprint,
## the side-wall fan apex and the vertical back all stay exactly where
## they were, and the module's triangle count does not move.

## The profile in the ZY plane -- `x` is Z, `y` is Y -- from the foot,
## tangent to the ground, up to the vertical lip. Arc of radius `height`
## centred at (z = 0, y = height).
##
## ⚠️ PUBLISHED, because `quarterpipe_pieces()` reads THIS and never a
## second spelling of it. CLAUDE.md's most expensive recurring defect is
## a fact retyped somewhere else; the collision pieces below are a second
## READING of one authored curve, and this function is what makes that
## true structurally rather than by a comment asking for it.
static func quarterpipe_profile(height: float) -> Array[Vector2]:
	var prof: Array[Vector2] = []
	for s in QP_SEGMENTS + 1:
		var a: float = float(s) / float(QP_SEGMENTS) * (PI * 0.5)
		prof.append(Vector2(height * sin(a), height - height * cos(a)))
	return prof

func quarterpipe(width: float, height: float) -> ArrayMesh:
	var half := width * 0.5
	var prof: Array[Vector2] = quarterpipe_profile(height)
	var norm: Array[Vector2] = []
	for s in QP_SEGMENTS + 1:
		var a: float = float(s) / float(QP_SEGMENTS) * (PI * 0.5)
		# Perpendicular to the tangent (cos a, sin a), pointing up and back
		# toward the rider. Unchanged since CH53 -- see the block above.
		norm.append(Vector2(-sin(a), cos(a)))
	# The riding surface.
	var left: Array[int] = []
	var right: Array[int] = []
	for s in prof.size():
		var col := COPING if s >= prof.size() - 2 else CONCRETE
		var nz := Vector3(0.0, norm[s].y, norm[s].x)
		left.append(_vertex(Vector3(-half, prof[s].y, prof[s].x), nz, col))
		right.append(_vertex(Vector3(half, prof[s].y, prof[s].x), nz, col))
	for s in prof.size() - 1:
		# Visible from where the rider is: -Z and up.
		_quad(left[s], right[s], right[s + 1], left[s + 1], Vector3(0.0, 0.6, -0.8))
	# The two side walls, as a fan from the bottom-back corner. The wall is
	# the profile closed by the vertical back edge and the ground.
	for side in [-1.0, 1.0]:
		var facing := Vector3(side, 0.0, 0.0)
		var x: float = side * half
		var base := _vertex(Vector3(x, 0.0, height), facing, CONCRETE)
		var prev := _vertex(Vector3(x, prof[0].y, prof[0].x), facing, CONCRETE)
		for s in range(1, prof.size()):
			var cur := _vertex(Vector3(x, prof[s].y, prof[s].x), facing, CONCRETE)
			_tri(base, prev, cur, facing)
			prev = cur
	# The vertical back, from the ground to the lip.
	var b0 := _vertex(Vector3(-half, 0.0, height), Vector3.BACK, CONCRETE_DARK)
	var b1 := _vertex(Vector3(half, 0.0, height), Vector3.BACK, CONCRETE_DARK)
	var b2 := _vertex(Vector3(half, height, height), Vector3.BACK, CONCRETE_DARK)
	var b3 := _vertex(Vector3(-half, height, height), Vector3.BACK, CONCRETE_DARK)
	_quad(b0, b1, b2, b3, Vector3.BACK)
	return _mesh()

# =====================================================================
# THE RAIL
#
# A beam on four legs. Nothing curved, nothing swept: the module exists
# so a line of the park is a LINE, and its whole read is the pale
# horizontal streak of the beam against the grass.

## ⚠️ CH60 -- PUBLISHED, because `rail_pieces()` reads these. They were
## three locals until the rail acquired a collider, and a local is exactly
## what a second reader retypes.
const RAIL_BEAM: float = 0.12
const RAIL_LEG: float = 0.09
## How far out along the beam each leg stands, as a fraction of the half
## length.
const RAIL_LEG_SPAN: float = 0.82

func rail(length: float, height: float) -> ArrayMesh:
	_box(Vector3(0.0, height, 0.0), Vector3(RAIL_BEAM, RAIL_BEAM, length), COPING, COPING)
	# TWO legs, one near each end, and not four: the beam is 0.12 across,
	# so a second leg abreast of the first would be a box inside a box --
	# geometry nobody can see and a triangle count nobody can defend.
	for s in [-1.0, 1.0]:
		var z: float = s * length * 0.5 * RAIL_LEG_SPAN
		_box(Vector3(0.0, height * 0.5, z), Vector3(RAIL_LEG, height, RAIL_LEG), CONCRETE_DARK, CONCRETE_DARK)
	return _mesh()

## The eight corners of a box, in the same (centre, size) terms `_box`
## takes. Static and shared by every piece builder below, so "the corners
## of the box the builder drew" has ONE spelling in this file.
static func _box_points(centre: Vector3, size: Vector3) -> PackedVector3Array:
	var h := size * 0.5
	var out := PackedVector3Array()
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				out.append(centre + Vector3(sx * h.x, sy * h.y, sz * h.z))
	return out

## =====================================================================
## CH60 LOT 3a -- THE RAIL'S COLLISION PIECES
##
## The easy half of this lot, and it is easy for a reason worth writing
## down rather than skipping: the rail is THREE BOXES and nothing else,
## so its convex decomposition is not an approximation of anything. Three
## pieces, eight points each, every point a corner the builder above
## actually drew. There is no fidelity question to answer here, which is
## why SkatePhysicsProbe can gate it with the same point-set EQUALITY it
## gates the funbox with -- and why the interesting work of this lot is
## all in the quarterpipe below.
##
## `rail()`'s own signature, argument for argument.
static func rail_pieces(length: float, height: float) -> Array:
	var pieces: Array = []
	pieces.append(_box_points(Vector3(0.0, height, 0.0), Vector3(RAIL_BEAM, RAIL_BEAM, length)))
	for s in [-1.0, 1.0]:
		var z: float = s * length * 0.5 * RAIL_LEG_SPAN
		pieces.append(_box_points(Vector3(0.0, height * 0.5, z), Vector3(RAIL_LEG, height, RAIL_LEG)))
	return pieces

## =====================================================================
## CH60 LOT 3a -- THE QUARTERPIPE'S CONVEX DECOMPOSITION, AND WHY IT IS
## TWELVE PIECES AND NOT FEWER
##
## This is the one module in this lot that is genuinely CONCAVE, and D5
## forbids a trimesh (`backface_collision` is false by default, so a
## trimesh wound the wrong way is a floor you fall through in silence --
## CH39 transposed to collision).
##
## The cross-section, once the profile above is right, is the region
## under a CONVEX increasing curve: bounded below by y = 0 from z = 0 to
## z = height, on the right by the vertical back at z = height, and above
## by the drawn polyline P0..P12. Its vertices are
##
##     B = (z = height, y = 0)      the back-bottom corner
##     P0..P12                      the profile points
##
## and P1..P11 are ALL REFLEX -- eleven of them, because the arc bulges
## away from the interior at every interior vertex.
##
## ⚠️ TWELVE IS NOT A CHOICE, IT IS THE MINIMUM, and the argument is
## short enough to check. A convex decomposition must resolve every
## reflex vertex, and a diagonal resolves at most two. But NO diagonal
## here joins two arc points: the chord between two points on a convex
## curve lies ABOVE that curve, i.e. OUTSIDE the region. So every
## diagonal has one end at B (P0 is no good either -- the region is not
## star-shaped from it: f convex with f(0) = 0 gives f(tz) <= t f(z), the
## wrong way round), each diagonal resolves exactly ONE reflex vertex,
## eleven diagonals are needed, and eleven diagonals cut a polygon into
## twelve pieces. A fan from B is therefore both the simplest and an
## optimal decomposition, and CH56's price list makes the count a
## non-question anyway: a convex PIECE costs at most 0.000018 ms/tick.
##
## ⚠️ AND IT IS EXACT AGAINST THE DRAWN MESH, not against the ideal arc.
## The chords P_s -> P_s+1 lie above the true circle, so a fan from B is
## NOT the quarter-disc -- and that is right, because the mesh is not the
## quarter-disc either: it is faceted on exactly the same twelve chords.
## The collider is the drawn solid, to the last vertex. The proof is not
## this comment: PHASE G asserts the point sets are EQUAL, and PHASE V
## samples the two solids against each other -- the DRAWN triangles by
## ray parity, the collider through the PHYSICS SERVER -- and demands
## they agree on every sample.
##
## `quarterpipe()`'s own signature, argument for argument.
static func quarterpipe_pieces(width: float, height: float) -> Array:
	var half := width * 0.5
	var prof: Array[Vector2] = quarterpipe_profile(height)
	var pieces: Array = []
	for s in QP_SEGMENTS:
		var wedge := PackedVector3Array()
		for sx in [-1.0, 1.0]:
			var x: float = sx * half
			# B, the fan apex -- the same point `quarterpipe()` uses as the
			# apex of its side-wall fan, which is why the union of these
			# pieces has no point the drawn mesh does not carry.
			wedge.append(Vector3(x, 0.0, height))
			wedge.append(Vector3(x, prof[s].y, prof[s].x))
			wedge.append(Vector3(x, prof[s + 1].y, prof[s + 1].x))
		pieces.append(wedge)
	return pieces

# =====================================================================
# THE FUNBOX
#
# A flat deck with a ramp at each end -- the module that makes a CHAIN
# possible, which is the only reason it is in the park at all (CH51
# section 5: "le module qui rend une chaîne possible").

func funbox(width: float, length: float, height: float, ramp: float) -> ArrayMesh:
	var half_w := width * 0.5
	var deck_half := length * 0.5
	_box(Vector3(0.0, height * 0.5, 0.0), Vector3(width, height, length), CONCRETE, CONCRETE_DECK)
	for s in [-1.0, 1.0]:
		var z0: float = s * deck_half
		var z1: float = s * (deck_half + ramp)
		var normal := Vector3(0.0, ramp, s * height).normalized()
		var a := _vertex(Vector3(-half_w, height, z0), normal, CONCRETE_DECK)
		var b := _vertex(Vector3(half_w, height, z0), normal, CONCRETE_DECK)
		var c := _vertex(Vector3(half_w, 0.0, z1), normal, CONCRETE)
		var d := _vertex(Vector3(-half_w, 0.0, z1), normal, CONCRETE)
		_quad(a, b, c, d, normal)
		# The two triangular cheeks of the ramp.
		for side in [-1.0, 1.0]:
			var facing := Vector3(side, 0.0, 0.0)
			var x: float = side * half_w
			var p0 := _vertex(Vector3(x, 0.0, z0), facing, CONCRETE)
			var p1 := _vertex(Vector3(x, height, z0), facing, CONCRETE)
			var p2 := _vertex(Vector3(x, 0.0, z1), facing, CONCRETE)
			_tri(p0, p1, p2, facing)
	return _mesh()

## =====================================================================
## CH57 -- THE FUNBOX'S COLLISION PIECES, WRITTEN BY HAND
##
## D5 (Mathieu, CH55 section 6): convex pieces, never a trimesh. CH56
## section 6 measured that the arbitration does NOT rest on cost -- a
## trimesh bowl and its 32 hulls are separated by less than the bench's
## own noise floor -- and named what it does rest on:
## `ConcavePolygonShape3D.backface_collision` is FALSE by default, so a
## trimesh wound the wrong way is a floor you fall through IN SILENCE.
## That is CH39's invisible hillside transposed to collision, and it is
## not a defect this repo can afford without a local visual debugger.
##
## ⚠️ AND THEY ARE WRITTEN, NOT DECOMPOSED. CH56 section 12.4 is explicit
## that VHACD's output is only priced here and never checked for
## correctness -- it returned TWELVE hulls for these twenty triangles,
## and for a bowl it would return a heap of solids where the drawn mesh
## is an open dish. A funbox is a box between two wedges; a box and a
## triangular prism are the two simplest convex solids there are, so the
## decomposition is EXACT rather than approximate, and it is three pieces
## rather than twelve.
##
## The signature is `funbox()`'s own, argument for argument, because that
## is what makes this a second READING of one authored shape rather than
## a second spelling of it: HubSkatepark passes the identical four
## numbers to both. What proves they agree is not this comment --
## SkatePhysicsProbe PHASE G asserts that the union of the points below
## is exactly the set of distinct vertex positions the DRAWN mesh carries,
## which is a gate against the geometry and not against the formula.
static func funbox_pieces(width: float, length: float, height: float, ramp: float) -> Array:
	var half_w := width * 0.5
	var deck_half := length * 0.5
	var pieces: Array = []
	# The deck box, exactly `_box`'s eight corners for the same centre and
	# the same size the builder above is handed. CH60 routed it through
	# `_box_points` so that "the corners of a box" has one spelling in this
	# file rather than one per piece builder.
	pieces.append(_box_points(Vector3(0.0, height * 0.5, 0.0), Vector3(width, height, length)))
	# The two ramps: the triangular prism whose cross-section is the cheek
	# the builder draws -- (z0, 0), (z0, height), (z1, 0) -- swept across
	# the full width. Six points, and four of them are corners of the deck
	# box above, which is exactly why the union gate below can be an
	# equality and not an inclusion.
	for s in [-1.0, 1.0]:
		var z0: float = s * deck_half
		var z1: float = s * (deck_half + ramp)
		var wedge := PackedVector3Array()
		for sx in [-1.0, 1.0]:
			wedge.append(Vector3(sx * half_w, 0.0, z0))
			wedge.append(Vector3(sx * half_w, height, z0))
			wedge.append(Vector3(sx * half_w, 0.0, z1))
		pieces.append(wedge)
	return pieces

# =====================================================================
# THE BOWL
#
# ⚠️ IT SITS ON THE GRASS, IT IS NOT DUG INTO IT. A real bowl is a hole,
# and a hole in this hub is a MULTI-ALTITUDE feature: CLAUDE.md is
# explicit that the ground is one plane, that HubSurface holds a
# single-valued height grid, and that CH18's multi-altitude migration
# cost thirteen sections. A dish resting on the lawn asks for none of
# that -- the ground stays y = 0 everywhere under it, tap resolution is
# untouched, and the region does not learn a new shape.
#
# What it costs is honesty about the read: this is a portable bowl, the
# kind a park drops on a lawn, not a poured concrete pool. That is the
# module Mathieu's "bol + rampes + rail" asks for at the density he asked
# for, and it is the only version of it that does not drag a chantier
# behind it.
#
# The surface is a dish of revolution: a quarter-circle profile again,
# from the flat centre out to a vertical lip, revolved. The outer skirt
# closes it down to the ground.

const BOWL_AZIMUTH: int = 24
const BOWL_RINGS: int = 5

func bowl(radius: float, depth: float) -> ArrayMesh:
	# The profile, from the centre of the floor out to the lip. `r` is the
	# distance from the axis, `y` the height above the floor.
	var prof: Array[Vector2] = []
	var flat := maxf(radius - depth, 0.15)
	# ⚠️ THE FLOOR IS NOT IN THIS PROFILE, and leaving it out is the whole
	# point. A profile that starts at r = 0 gives a first ring of
	# BOWL_AZIMUTH vertices all at the same point, and the quad loop below
	# then lays 48 ZERO-AREA triangles that cost their full price on the
	# primitive counter this lot is gated on and draw nothing at all --
	# CH39's "submitted is not drawn", manufactured on purpose. The floor
	# is a fan from ONE centre vertex, after the loop.
	for s in BOWL_RINGS + 1:
		var a: float = float(s) / float(BOWL_RINGS) * (PI * 0.5)
		prof.append(Vector2(flat + depth * sin(a), depth * (1.0 - cos(a))))
	var ring: Array = []
	for p in prof.size():
		var row: Array[int] = []
		var col := COPING if p >= prof.size() - 1 else (CONCRETE if p >= 2 else CONCRETE_DARK)
		for k in BOWL_AZIMUTH:
			var t: float = float(k) / float(BOWL_AZIMUTH) * TAU
			var dir := Vector3(cos(t), 0.0, sin(t))
			# Inward-and-up normal: the rider is inside the dish.
			var slope: float = 0.0 if p == 0 else (prof[p].y - prof[p - 1].y)
			var run: float = 1.0 if p == 0 else maxf(prof[p].x - prof[p - 1].x, 0.001)
			var normal := (Vector3.UP * run - dir * slope).normalized()
			row.append(_vertex(dir * prof[p].x + Vector3.UP * prof[p].y, normal, col))
		ring.append(row)
	# The flat floor, as a fan from ONE centre vertex (see the profile note
	# above): BOWL_AZIMUTH triangles instead of a degenerate ring.
	var floor_ring: Array = ring[0]
	var centre := _vertex(Vector3.ZERO, Vector3.UP, CONCRETE_DARK)
	for k in BOWL_AZIMUTH:
		var k2: int = (k + 1) % BOWL_AZIMUTH
		_tri(centre, floor_ring[k], floor_ring[k2], Vector3.UP)
	# The dish itself, seen from inside and above.
	for p in prof.size() - 1:
		var a_row: Array = ring[p]
		var b_row: Array = ring[p + 1]
		for k in BOWL_AZIMUTH:
			var k2: int = (k + 1) % BOWL_AZIMUTH
			var mid := (_v[a_row[k]] + _v[b_row[k2]]) * 0.5
			# Visible from the axis above the dish: from the centre, up.
			var facing := (Vector3(0.0, depth + 1.0, 0.0) - mid).normalized()
			_quad(a_row[k], a_row[k2], b_row[k2], b_row[k], facing)
	# The outer skirt, from the lip down to the ground.
	var skirt: Array[int] = []
	var outer: Array[int] = []
	for k in BOWL_AZIMUTH:
		var t: float = float(k) / float(BOWL_AZIMUTH) * TAU
		var dir := Vector3(cos(t), 0.0, sin(t))
		outer.append(_vertex(dir * prof[prof.size() - 1].x, dir, CONCRETE))
		skirt.append(_vertex(dir * prof[prof.size() - 1].x + Vector3.UP * prof[prof.size() - 1].y, dir, COPING))
	for k in BOWL_AZIMUTH:
		var k2: int = (k + 1) % BOWL_AZIMUTH
		var t: float = (float(k) + 0.5) / float(BOWL_AZIMUTH) * TAU
		var facing := Vector3(cos(t), 0.0, sin(t))
		_quad(outer[k], outer[k2], skirt[k2], skirt[k], facing)
	# No cap is needed at the lip: the dish's last ring and the skirt's top
	# ring are at the SAME radius and the SAME height, so the two surfaces
	# meet on one edge.
	return _mesh()

# =====================================================================
# THE BOARD
#
# The fifth vehicle of family B, and the only piece here that is not
# concrete. It is drawn with the ORDINARY decor material, not the
# concrete one: it is a prop Keepy rides, in the same visual family as
# the hoppity ball, and giving it the flat matte treatment the ramps get
# would make the one moving object in the park read as a paving slab.
#
# `DECK_TOP` is where his feet stand, published so HubTransport does not
# retype it -- CLAUDE.md, and the ball paid for that rule already
# (BALL_LIFT is authored once and republished).

const DECK: Color = Color(0.55, 0.33, 0.22)
const DECK_GRIP: Color = Color(0.20, 0.20, 0.22)
const WHEEL: Color = Color(0.88, 0.84, 0.72)
const DECK_LENGTH: float = 0.92
const DECK_WIDTH: float = 0.26
const DECK_THICK: float = 0.05
const WHEEL_SIZE: float = 0.10
## Top of the deck above the ground: wheels, then the deck on them.
const DECK_TOP: float = WHEEL_SIZE + DECK_THICK

func skateboard() -> ArrayMesh:
	_box(Vector3(0.0, WHEEL_SIZE + DECK_THICK * 0.5, 0.0),
		Vector3(DECK_WIDTH, DECK_THICK, DECK_LENGTH), DECK, DECK_GRIP)
	for s in [-1.0, 1.0]:
		var z: float = s * DECK_LENGTH * 0.32
		_box(Vector3(0.0, WHEEL_SIZE * 0.5, z),
			Vector3(DECK_WIDTH * 0.92, WHEEL_SIZE, WHEEL_SIZE), WHEEL, WHEEL)
	return _mesh()
