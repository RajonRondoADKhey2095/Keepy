extends Node3D
class_name HubBuilder
## Instantiates everything the plateau is made of, from HubLayout data.
##
## Nothing here decides WHERE anything goes -- that is entirely
## resources/hub/hub_layout.tres. This file only knows how to turn a type
## name into geometry, and it validates rather than trusts: a malformed
## entry is reported and skipped, because a typo in a decor file must
## never be the reason a player cannot reach their games.
##
## Prop meshes are built in code from primitives, deliberately. They are
## placeholders for this batch -- no Meshy credit is spent here -- and a
## primitive authored in code cannot drift from the layout the way a
## per-prop .tscn with its own baked transform would.
##
## Every material is UNSHADED, which is this project's standing rule for
## every surface (docs/MESHY_SPEC.md 8): the scene has no
## DirectionalLight3D, so a lit surface would render at whatever the
## ambient term alone gives it and its colour would stop being the colour
## that was authored.
##
## =====================================================================
## SCATTER PROPS ARE BATCHED, LANDMARKS AND PORTALS ARE NOT (25 aout 2026)
##
## tree / rock / bush / flower used to be a Node3D each with one
## or two MeshInstance3D children, which put the plateau at 259 draw nodes
## against a 260 ceiling -- one spare. They are now accumulated into a
## MultiMeshInstance3D per UNIQUE (mesh, colour) pair, filled in a second
## pass once every entry has been read.
##
## The unit of batching is the (mesh, colour) PAIR and not the semantic
## type, and the two do not line up: a tree contributes to two batches
## (trunk and crown are different meshes), a bush contributes TWO
## INSTANCES to one batch (its two lobes share a single SphereMesh at two
## offsets), and a flower's corolla splits three ways because its three
## tints are three different draws.
##
## Per-instance colour (MultiMesh.use_colors plus
## vertex_color_use_as_albedo) would collapse those three corolla nodes
## into one. It is NOT used: it would make the shipped material differ
## from the one this file used to build, on a batch nobody can look at
## before it is on staging, to save two nodes out of a budget this change
## empties. Three nodes carrying the exact material they carried before is
## the version whose parity can be proven rather than hoped for.
##
## WHAT STAYS AN INDIVIDUAL NODE, and why:
##
##   portal    it is an Area3D with a CollisionShape3D and a Label3D, and
##             HubWorld connects a signal to each one. A MultiMesh has no
##             per-instance node to connect to.
##   landmark  three silhouettes, 3 to 5 meshes each, 8 on the plateau --
##             batching them would trade 31 nodes for ~12 and lose the
##             per-variant readability of the tree.
##   pond      one instance on the plateau. There is nothing to batch,
##             and it is the only ALPHA-BLENDED surface on this screen --
##             together with lake, below.
##   lake       one instance, same reason as pond: nothing to batch. It is
##             built by the same _make_water_body() the pond is, so the two
##             cannot drift apart on the z-fight heights or on the
##             transparency flag that has to be asked for.
##   stream    one instance, and its mesh is a one-off ribbon built for its
##             own trace -- there is no shared mesh for a MultiMesh to
##             repeat. It is the third ALPHA-BLENDED surface here.
##   boat      one instance, and it is MOVED every frame of a ride. A
##             MultiMesh instance can be moved, but the hull also has to be
##             handed to BoatMooring as a node -- and there is exactly one,
##             so there is nothing to batch either way.
##   stump     14 on the plateau at one mesh each. Batching would save 13
##             nodes out of the ~220 this change frees; measured and left
##             individual until the count makes the indirection worth it.
##
## NO COLLISION IS LOST. tree / rock / bush / flower / stump / pond / lake /
## stream / boat have never
## had a CollisionShape3D -- grepped, not assumed -- so nothing on the
## plateau depends on a per-prop physics node. The ground is not a
## collider either: HubTapInput intersects a maths Plane rather than
## raycasting. The only Area3D on this screen belongs to HubPortal, which
## is exactly what this change leaves alone.

## The plateau's contents. Swap this resource and the whole screen
## re-lays-out with no code change -- the point of the split.
@export var layout: HubLayout

## Scene instantiated for every &"portal" entry.
@export var portal_scene: PackedScene

const TRUNK_COLOR: Color = Color(0.20, 0.13, 0.08)
const CROWN_COLOR: Color = Color(0.17, 0.34, 0.13)
const ROCK_COLOR: Color = Color(0.26, 0.27, 0.24)
const BUSH_COLOR: Color = Color(0.21, 0.39, 0.16)

## Flower colours, LOCAL to the hub on purpose. SwampPalette.gd carries the
## identity Chased and the plateau share; these are hub-local decor, read by
## nothing else, and its own header says that kind of colour stays here
## rather than being promoted into the shared resource.
const FLOWER_STEM_COLOR: Color = Color(0.19, 0.35, 0.14)

## Three corolla tints rather than one: a field of a single colour reads as
## a repeated instance, which is exactly what it is. Entries pick one with
## an optional "variant" int; anything out of range falls back to 0 so a
## layout written without the field still builds.
##
## One MultiMesh batch each -- see the header. The batch keys are kept in
## step with this array by _FLOWER_PETAL_KEYS below.
const FLOWER_PETAL_COLORS: Array[Color] = [
	Color(0.93, 0.86, 0.42),
	Color(0.86, 0.52, 0.62),
	Color(0.72, 0.66, 0.88),
]

## Batch key per corolla tint, index-aligned with FLOWER_PETAL_COLORS. A
## fourth tint means a fourth entry in both, and the assert in _ready()
## fails loudly rather than silently drawing every extra tint as tint 0.
const _FLOWER_PETAL_KEYS: Array[StringName] = [
	&"FlowerPetal0",
	&"FlowerPetal1",
	&"FlowerPetal2",
]

## Landmark colours, LOCAL to the hub for the same reason as the flower
## tints above -- decor, not the identity SwampPalette carries.
##
## Deliberately LIGHT. A landmark's top pokes just above the horizon line
## (the camera's -34 deg pitch leaves the top of the frame ~2.4 deg above
## horizontal), so it is read against the sky, and the sky here is the
## near-black swamp green. A dark silhouette against a dark sky is not a
## landmark, it is a hole.
## The pond. Its water is the ONLY alpha-blended surface on the plateau:
## an opaque disc reads as a painted circle, and the point of a pond as a
## destination is that it reads as a hole in the ground rather than a mark
## on it. The bank is opaque and slightly wider, so the water has an edge
## to sit inside instead of ending on bare ground.
##
## Blue-green rather than blue. The ground is swamp green and the sky is
## near-black green: a saturated blue would be the only thing on this
## screen with no relation to anything else on it.
const POND_WATER_COLOR: Color = Color(0.16, 0.30, 0.36, 0.55)
const POND_BANK_COLOR: Color = Color(0.22, 0.21, 0.15)
const POND_WATER_RADIUS: float = 3.2
const POND_BANK_RADIUS: float = 3.62
const POND_SEGMENTS: int = 24

## The lake -- the pond's silhouette at 2.5x, far out in the outer ring as
## a second, bigger destination. LOCAL to the hub for the same reason every
## other decor colour here is: SwampPalette carries the identity Chased and
## the plateau share, not the plateau's own scenery.
##
## A DIFFERENT HUE, not merely a lighter pond. Measured rather than eyeballed:
## the pond's water is hsv(198.0, 0.56, 0.36) -- a dark teal sitting right on
## the cyan edge -- and this is hsv(221.5, 0.63, 0.82), a light blue.
## 23.5 degrees of hue apart, which crosses the teal/blue boundary rather
## than sliding along it, and 0.46 of value on top. Under fog both converge
## on the same near-black swamp green, so leaning on brightness alone would
## have made them indistinguishable exactly where the lake is furthest away
## and most in need of reading as its own thing.
const LAKE_WATER_COLOR: Color = Color(0.30, 0.46, 0.82, 0.55)

## 2.5x the pond on both discs (3.2 -> 8.0, 3.62 -> 9.05), so the rim keeps
## the same proportion rather than becoming a hairline on a much bigger disc.
const LAKE_WATER_RADIUS: float = 8.0
const LAKE_BANK_RADIUS: float = 9.05

## Deliberately NOT the pond's 24, and not 2.5x it either. What matters is
## the ABSOLUTE facet deviation, and that scales with the radius: a circle
## of radius 8.0 drawn with the pond's 24 segments would bulge inward by
## 0.068 units between vertices against the pond's own 0.027 -- visibly
## faceted at this size, on the largest flat surface on the plateau. 40
## segments bring it to 0.0247 (bank 0.0279), i.e. marginally FLATTER per
## facet than the pond despite 2.5x the radius, for 16 extra segments.
## Still a low, explicit tessellation -- the docs/MESHY_SPEC.md 7.2 rule --
## just calibrated to the size instead of inherited from a smaller disc.
const LAKE_SEGMENTS: int = 40

## The stream that runs from the pond to the lake. A THIRD water tint, and
## each pair is told apart on a DIFFERENT axis rather than all three
## sliding along one:
##
##   pond    hsv(198.0, 0.556, 0.36)  dark teal
##   lake    hsv(221.5, 0.634, 0.82)  light blue
##   stream  hsv(190.9, 0.512, 0.86)  bright cyan
##
## stream vs pond  -- 7.1 deg of hue apart, so they are separated by VALUE
##                    (0.86 against 0.36), a half of the scale.
## stream vs lake  -- near-identical value, so they are separated by HUE
##                    (30.6 deg), which crosses the cyan/blue boundary.
##
## Leaning on one axis for both pairs would have made one of them collapse:
## a brighter pond reads as the lake, and a cyan-shifted lake reads as the
## stream. LOCAL to the hub, like every other decor colour here.
const STREAM_WATER_COLOR: Color = Color(0.42, 0.78, 0.86, 0.55)

## 1.2 units across. Half of that -- 0.6 -- is the number the trace was
## routed against: every prop's GROUND footprint clears the water's edge by
## at least 0.39, measured on the shipped layout rather than eyeballed.
const STREAM_WIDTH: float = 1.2

## Above the ground plane (y = 0), above the ponds' banks (top 0.055) and
## above their water (top 0.08), so it is never coplanar with any of them.
## The trace ends exactly on each water body's WATER rim, so the ribbon
## crosses the bank ring from outside and stops where the water starts:
## it covers the rim rather than leaving a gap, and it never overlaps an
## alpha surface with another alpha surface.
const STREAM_SURFACE_Y: float = 0.095

## Samples per control-point span. 8 gives 89 samples over the shipped
## 12-point trace, i.e. 176 triangles for the whole watercourse -- less
## than the lake's two discs cost on their own. Explicit rather than
## inherited, the docs/MESHY_SPEC.md 7.2 rule, and it is what fixes the
## curve's sagitta: doubling it halves the flat-edge deviation.
const STREAM_SAMPLES_PER_SPAN: int = 8

## =====================================================================
## THE BOAT, AND WHY ITS LENGTH IS A CALCULATION AND NOT A TASTE
##
## The hull rides the stream spine, so it has to fit inside the ribbon at
## the TIGHTEST bend the trace takes. Both numbers come from the shipped
## geometry rather than from a guess: StreamGeometryProbe measures the
## spine's minimum radius of curvature at 1.4058 u (sample 48) and the
## ribbon's half-width is the layout's own width / 2 = 0.6 u.
##
## A RIGID hull of length L and beam B, centred on the spine and turned
## along the tangent, has its worst point at an OUTER CORNER. On a circle
## of radius R that corner sits at
##
##     sqrt((R + B/2)^2 + (L/2)^2)
##
## from the circle's centre, so it leaves the spine by that minus R. The
## hull stays on the water while
##
##     sqrt((R + B/2)^2 + (L/2)^2) - R  <=  half-width
##
## At R = 1.4058, half-width 0.6, the shipped BOAT_LENGTH 0.78 and
## BOAT_BEAM 0.86 give 0.4709 u of corner excursion -- 0.1291 u of margin.
## The brief's ceiling of 0.80 x 1.00 would give 0.5415 and only 0.0585,
## which is why neither is taken to its limit. That inequality is asserted
## on the built spine by StreamRideProbe rather than left as a comment:
## re-trace the stream and the margin moves, and it must fail loudly if it
## ever goes negative.
##
## The corner form is CONSERVATIVE for this hull -- the shell is rounded,
## so its real extreme is inside the rectangle the formula bounds. Being
## conservative is the point: a bound that a future, boxier hull would
## still satisfy.
const BOAT_LENGTH: float = 0.78
const BOAT_BEAM: float = 0.86

## Depth of the shell below its rim, and the width of the rim lip.
const BOAT_DEPTH: float = 0.24
const BOAT_RIM: float = 0.09

## Ring/tier counts on the shell. Explicit, low, and calibrated to a hull
## under a metre across -- the same reasoning LAKE_SEGMENTS carries, and
## the same trap (a primitive left at Godot's default tessellation) that
## docs/MESHY_SPEC.md 7.2 caught on the collectibles.
const BOAT_RADIAL_SEGMENTS: int = 16
const BOAT_TIERS: int = 4

## How far the inner shell is set inside the hull, so the dark outer wall
## still reads as a thickness at the rim.
const BOAT_INNER_INSET: float = 0.06

## Height of the RIM above the ground plane.
##
## MEASURED, after the first version was wrong in a way no error reported.
## The shell hangs BOAT_DEPTH below its rim, so at the original 0.16 the
## keel sat at -0.08 -- under the ground plane, which is opaque at y = 0.
## Everything below the waterline was therefore clipped by the ground and
## the boat rendered as a hollow RING with the lake visible straight
## through it. Caught on a render, not in review; the geometry was correct
## the whole time and simply drawn inside the floor.
##
## At 0.30 the keel sat at 0.06, which cleared the floor but left a SECOND
## artifact the same render showed: the stream's own surface is at
## STREAM_SURFACE_Y = 0.095, ABOVE that keel, so the water plane cut
## through the inside of the shell and a sliver of stream was visible in
## the bottom of the boat.
##
## 0.34 puts the keel at 0.10 -- five millimetres over the stream's
## surface and two centimetres over the lake's, so it seats ON the
## waterline with nothing showing through, and the gap is far too small to
## read as hovering at a hull this size.
const BOAT_FLOAT_Y: float = 0.34

## Hull colours, LOCAL to the hub like every other decor colour in this
## file -- SwampPalette carries the identity Chased and the plateau share,
## not a prop tint.
##
## A nutshell, so the outside is bark-dark and close to the trees it came
## from; the rim is the cut edge, and the INSIDE is lighter still.
##
## The inner shell is not decoration. MEASURED on a render: with the hull
## drawn as one double-sided surface, what the camera sees of a bowl at
## this pitch is mostly the INSIDE of the far wall -- so a single dark
## tone made the boat read as a hole in the bank rather than as an object,
## the more so because it moors on the lake's own dark bank ring. Three
## tones, dark outside to light inside, is what turns the same silhouette
## into an open shell.
##
## The hull is also lifted off the trees' bark colour rather than sharing
## it (the way stump does): a stump beside a tree is telling a story, a
## boat lost against a bank is just missing.
const BOAT_HULL_COLOR: Color = Color(0.33, 0.21, 0.12)
const BOAT_INNER_COLOR: Color = Color(0.74, 0.60, 0.40)
const BOAT_RIM_COLOR: Color = Color(0.88, 0.76, 0.55)

## Ground footprint radius per prop type, in LOCAL units (multiplied by the
## entry's uniform scale at read time). Used by the ride's disembark search
## to refuse a bank point that is already occupied.
##
## These are the AT-GROUND radii, deliberately NOT the silhouettes: a tree
## TRUNK is 0.24 while its crown is 0.95, but the crown floats two metres
## up. A trunk in the water is a bug; a crown overhanging it is what a real
## tree beside a stream does. That distinction is the same one the lot G
## routing measured with, so the two agree by construction.
const FOOTPRINT_RADIUS: Dictionary = {
	&"tree": 0.24,
	&"rock": 0.44,
	&"bush": 0.71,
	&"flower": 0.22,
	&"stump": 0.44,
	&"landmark": 1.66,
	&"portal": 1.35,
}

const LANDMARK_SPIRE_TRUNK: Color = Color(0.15, 0.10, 0.06)
const LANDMARK_SPIRE_CROWN: Color = Color(0.38, 0.58, 0.30)
const LANDMARK_CAIRN_STONE: Color = Color(0.44, 0.45, 0.40)
const LANDMARK_CAIRN_CAP: Color = Color(0.56, 0.56, 0.50)
const LANDMARK_SLAB_STONE: Color = Color(0.36, 0.44, 0.32)
const LANDMARK_SLAB_BASE: Color = Color(0.26, 0.30, 0.23)

var _portals: Array[HubPortal] = []

## The one &"boat" node, and the spine of the one &"stream", both kept so
## the ride can be handed the geometry that was actually BUILT rather than
## a second derivation of it. Null / empty when the layout carries neither,
## which is a legal plateau -- the ride simply does not exist there.
var _boat: Node3D = null
var _stream_spine: Array = []
var _stream_half_width: float = 0.0

## Batch key -> {"mesh": Mesh, "colour": Color, "xforms": Array[Transform3D]}.
## Filled while the layout is walked, drained once at the end by
## _flush_batches(); a batch nothing landed in is never created.
var _batches: Dictionary = {}

## Batch keys in first-seen order, so the child order of the MultiMesh
## nodes follows the layout rather than Dictionary iteration order.
var _batch_order: Array[StringName] = []

func _ready() -> void:
	assert(_FLOWER_PETAL_KEYS.size() == FLOWER_PETAL_COLORS.size(),
		"HubBuilder: a corolla tint has no batch key, or the reverse.")
	_build()

## Every portal built, in layout order. HubWorld connects them after the
## build rather than the builder knowing what a portal is wired to.
func portals() -> Array[HubPortal]:
	return _portals

## The hull built for the one &"boat" entry, or null if the layout has
## none. Owned by this node; BoatMooring only moves it.
func boat() -> Node3D:
	return _boat

## The spine of the one &"stream" entry -- the SAMPLED centripetal curve
## this file ribboned, not the layout's control points.
##
## Handed over rather than re-derived on purpose: the drawn curve bulges
## outside the chords of a polyline through the same control points, so a
## rider following the control points would leave the water on every bend.
## One curve in the build, and the ride is on it.
func stream_spine() -> Array:
	return _stream_spine

## Half the width of the one &"stream", as it was built. The ride needs it
## to know where the bank is; it is layout data, so it is reported from
## here rather than re-read from the resource by a second caller.
func stream_half_width() -> float:
	return _stream_half_width

## Every prop's ground footprint, as {"position": Vector3, "radius": float},
## read from the LAYOUT rather than from the built tree -- batched props
## have no node of their own to measure, and a stream/boat has no single
## position at all. Both are skipped: neither is something to land on top
## of, and neither has a meaningful ground radius.
func ground_footprints() -> Array:
	var out: Array = []
	if layout == null:
		return out
	for entry in layout.props:
		var type: StringName = entry.get("type", &"")
		if not FOOTPRINT_RADIUS.has(type):
			continue
		var where: Vector3 = entry.get("position", Vector3.ZERO)
		var uniform: float = entry.get("scale", 1.0)
		out.append({
			"position": Vector3(where.x, 0.0, where.z),
			"radius": float(FOOTPRINT_RADIUS[type]) * uniform,
		})
	return out

func _build() -> void:
	if layout == null:
		push_error("HubBuilder: no layout assigned, plateau will be empty.")
		return
	for index in layout.props.size():
		var entry: Dictionary = layout.props[index]
		var type: StringName = entry.get("type", &"")
		var where: Vector3 = entry.get("position", Vector3.ZERO)
		var rotation_y: float = entry.get("rotation_y", 0.0)
		var uniform: float = entry.get("scale", 1.0)

		# The transform the prop's root node WOULD have had. Composed by
		# hand because a batched instance has no node to read it off --
		# and it is exact rather than approximate because the layout's
		# scale is a UNIFORM float: rotation and uniform scale commute, so
		# there is no ambiguity about which side Node3D applies the scale.
		# Asserted against a real node, not argued: see the batch's probe.
		var placement := Transform3D(
			Basis.from_euler(Vector3(0.0, deg_to_rad(rotation_y), 0.0)).scaled(Vector3.ONE * uniform),
			where)

		var node: Node3D = null
		if not _batch_prop(type, entry, placement):
			match type:
				&"portal":
					node = _make_portal(entry, index)
				&"landmark":
					node = _make_landmark(entry)
				&"stump":
					node = _make_stump()
				&"pond":
					node = _make_pond()
				&"lake":
					node = _make_lake()
				&"stream":
					node = _make_stream(entry)
				&"boat":
					node = _make_boat()
				_:
					push_error("HubBuilder: entry %d has unknown type '%s', skipped." % [index, type])
					continue
			if node == null:
				continue

		# A prop outside the tap clamp is drawn but can never be walked to.
		# Not fatal -- distant scenery is a legitimate thing to want -- so
		# warn and keep it rather than dropping it. The bound is READ from
		# HubTapInput, never copied: two copies of a play-area limit is how
		# they drift apart.
		#
		# This reads the LAYOUT, never the scene tree, which is why
		# batching changed nothing about it. It stays AFTER the type is
		# known good so an unknown type still produces one error and no
		# warning, exactly as before.
		# A stream has NO single position -- its trace is its placement -- so
		# the check walks every control point. Without this branch a stream
		# would fall back to Vector3.ZERO and pass for free: a silent hole in
		# the one guard that catches a prop nobody can walk to.
		var anchors: Array = [where]
		if type == &"stream":
			anchors = _trace_points(entry)
		var bound: float = HubTapInput.PLATEAU_HALF_EXTENT
		for anchor in anchors:
			var point: Vector3 = anchor
			if absf(point.x) > bound or absf(point.z) > bound:
				push_warning("HubBuilder: entry %d ('%s') at %s is outside the +-%.1f plateau; visible but unreachable." % [index, type, point, bound])

		if node != null:
			node.position = where
			node.rotation_degrees = Vector3(0.0, rotation_y, 0.0)
			node.scale = Vector3.ONE * uniform
			add_child(node)
			if type == &"boat":
				if _boat != null:
					push_error("HubBuilder: a second &\"boat\" entry at %d; the ride owns one hull, the extra is drawn but never moored." % index)
				else:
					_boat = node
	_flush_batches()

## Files a scatter prop into its batches. Returns false for a type that
## wants a node of its own, which is the caller's cue to fall through to
## the match.
func _batch_prop(type: StringName, entry: Dictionary, placement: Transform3D) -> bool:
	match type:
		&"tree":
			_instance(&"TreeTrunk", placement.translated_local(Vector3(0.0, 0.75, 0.0)))
			_instance(&"TreeCrown", placement.translated_local(Vector3(0.0, 2.0, 0.0)))
		&"rock":
			_instance(&"Rock", placement.translated_local(Vector3(0.0, 0.28, 0.0)))
		&"bush":
			# Two lobes, ONE mesh: two instances of a single batch.
			_instance(&"Bush", placement.translated_local(Vector3(0.0, 0.3, 0.0)))
			_instance(&"Bush", placement.translated_local(Vector3(0.42, 0.2, 0.18)))
		&"flower":
			_instance(&"FlowerStem", placement.translated_local(Vector3(0.0, 0.21, 0.0)))
			var variant: int = entry.get("variant", 0)
			if variant < 0 or variant >= FLOWER_PETAL_COLORS.size():
				variant = 0
			_instance(_FLOWER_PETAL_KEYS[variant], placement.translated_local(Vector3(0.0, 0.44, 0.0)))
		_:
			return false
	return true

func _instance(key: StringName, xform: Transform3D) -> void:
	if not _batches.has(key):
		var spec: Array = _batch_spec(key)
		var xforms: Array[Transform3D] = []
		_batches[key] = {"mesh": spec[0], "colour": spec[1], "xforms": xforms}
		_batch_order.append(key)
	_batches[key]["xforms"].append(xform)

## The (mesh, colour) pair a batch key stands for. Built once per key, on
## first use -- the whole point of a MultiMesh is that 39 trees share one
## trunk mesh rather than owning 39 copies of it.
##
## Godot's default tessellation on a primitive is far denser than any
## silhouette this size needs -- the same trap docs/MESHY_SPEC.md 7.2
## caught on the collectibles. Set explicitly rather than inherited.
func _batch_spec(key: StringName) -> Array:
	match key:
		&"TreeTrunk":
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.16
			trunk.bottom_radius = 0.24
			trunk.height = 1.5
			trunk.radial_segments = 8
			trunk.rings = 1
			return [trunk, TRUNK_COLOR]
		&"TreeCrown":
			var crown := SphereMesh.new()
			crown.radius = 0.95
			crown.height = 1.7
			crown.radial_segments = 10
			crown.rings = 5
			return [crown, CROWN_COLOR]
		&"Rock":
			var rock := SphereMesh.new()
			rock.radius = 0.6
			rock.height = 0.8
			rock.radial_segments = 8
			rock.rings = 4
			return [rock, ROCK_COLOR]
		&"Bush":
			var bush := SphereMesh.new()
			bush.radius = 0.5
			bush.height = 0.7
			bush.radial_segments = 8
			bush.rings = 4
			return [bush, BUSH_COLOR]
		&"FlowerStem":
			var stem := CylinderMesh.new()
			stem.top_radius = 0.025
			stem.bottom_radius = 0.035
			stem.height = 0.42
			stem.radial_segments = 6
			stem.rings = 1
			return [stem, FLOWER_STEM_COLOR]
		_:
			var tint: int = _FLOWER_PETAL_KEYS.find(key)
			if tint < 0:
				push_error("HubBuilder: no mesh known for batch key '%s'." % key)
				return [SphereMesh.new(), Color.MAGENTA]
			var petal := SphereMesh.new()
			petal.radius = 0.15
			petal.height = 0.14
			petal.radial_segments = 8
			petal.rings = 3
			return [petal, FLOWER_PETAL_COLORS[tint]]

## Turns every filled batch into one MultiMeshInstance3D.
func _flush_batches() -> void:
	for key in _batch_order:
		var batch: Dictionary = _batches[key]
		var xforms: Array = batch["xforms"]
		if xforms.is_empty():
			continue
		var mesh: Mesh = batch["mesh"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = xforms.size()
		var bounds := AABB()
		var local_aabb: AABB = mesh.get_aabb()
		for i in xforms.size():
			var xform: Transform3D = xforms[i]
			multi.set_instance_transform(i, xform)
			var box: AABB = xform * local_aabb
			bounds = box if i == 0 else bounds.merge(box)
		# A MultiMesh derives an AABB of its own, and a wrong or stale one
		# makes the entire batch vanish when the camera turns -- a failure
		# with no error attached to it, on a screen no one can look at
		# before staging. The exact union is cheap to compute right here,
		# so it is written rather than trusted.
		multi.custom_aabb = bounds

		var node := MultiMeshInstance3D.new()
		node.name = String(key)
		node.multimesh = multi
		# material_override rather than a material on the mesh: the mesh is
		# shared by every instance in the batch, and this keeps the colour
		# on the node that draws it, next to the instances it applies to.
		node.material_override = _unshaded(batch["colour"])
		add_child(node)

func _make_portal(entry: Dictionary, index: int) -> Node3D:
	if portal_scene == null:
		push_error("HubBuilder: entry %d is a portal but no portal_scene is assigned." % index)
		return null
	var portal := portal_scene.instantiate() as HubPortal
	if portal == null:
		push_error("HubBuilder: portal_scene does not instantiate to a HubPortal.")
		return null
	portal.game_id = entry.get("game_id", &"")
	var label_node := portal.get_node_or_null("Label") as Label3D
	if label_node:
		label_node.text = entry.get("label", "")
	_portals.append(portal)
	return portal
## A cut trunk. Deliberately ONE mesh in the trees' own bark colour: a
## stump is what a tree leaves behind, so sharing the colour is what makes
## the pair read as a story rather than as two unrelated props. No lighter
## disc on the cut face -- that would be a second material for a surface
## the camera, at -34 degrees and 7.6 units up, sees almost edge-on.
func _make_stump() -> Node3D:
	var root := Node3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.44
	mesh.height = 0.55
	mesh.radial_segments = 8
	mesh.rings = 1
	root.add_child(_mesh_node(mesh, TRUNK_COLOR, Vector3(0.0, 0.275, 0.0)))
	return root

## Standing water, far out in the outer ring, as somewhere to go.
##
## Two flat discs, not one: an opaque bank slightly wider than the water,
## so the alpha surface has a rim to end on. Both are CylinderMesh rather
## than PlaneMesh -- a plane is single-sided, and a viewer who ever sees
## this screen from below the horizon would find the water simply absent.
##
## The heights are what keep it out of a z-fight with the ground. The
## ground is a PlaneMesh at exactly y = 0; the bank's underside sits at
## 0.005 and the water's at 0.02, so neither is ever coplanar with it.
## They are NOT scaled with the radius: a lake-sized slab 0.15 thick would
## show its own edge, which is the one thing a flat water surface must not
## do.
##
## Shared by pond and lake so the two cannot drift apart on either of the
## traps above.
func _make_water_body(water_radius: float, bank_radius: float, segments: int, water_colour: Color) -> Node3D:
	var root := Node3D.new()

	var bank := CylinderMesh.new()
	bank.top_radius = bank_radius
	bank.bottom_radius = bank_radius
	bank.height = 0.05
	bank.radial_segments = segments
	bank.rings = 1
	root.add_child(_mesh_node(bank, POND_BANK_COLOR, Vector3(0.0, 0.03, 0.0)))

	var water := CylinderMesh.new()
	water.top_radius = water_radius
	water.bottom_radius = water_radius
	water.height = 0.06
	water.radial_segments = segments
	water.rings = 1
	var surface := _mesh_node(water, water_colour, Vector3(0.0, 0.05, 0.0))
	var material := surface.get_surface_override_material(0) as StandardMaterial3D
	# Alpha blending, and it has to be asked for: albedo_color's alpha
	# channel is ignored entirely while transparency stays at DISABLED, so
	# the water would render as flat opaque teal with no error to say so.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	root.add_child(surface)
	return root

func _make_pond() -> Node3D:
	return _make_water_body(POND_WATER_RADIUS, POND_BANK_RADIUS, POND_SEGMENTS, POND_WATER_COLOR)

## The lake. Same two discs as the pond, 2.5x across, in a light blue of
## its own -- see LAKE_WATER_COLOR for why a different HUE and not just a
## brighter pond. The bank reuses POND_BANK_COLOR on purpose: a bank is a
## bank, the same reasoning that has a stump share the trees' bark colour.
func _make_lake() -> Node3D:
	return _make_water_body(LAKE_WATER_RADIUS, LAKE_BANK_RADIUS, LAKE_SEGMENTS, LAKE_WATER_COLOR)

## The trace of a &"stream" entry, as plain Vector3s. Empty for anything
## malformed -- validated here rather than trusted, like every other entry.
func _trace_points(entry: Dictionary) -> Array:
	var raw: Variant = entry.get("points", null)
	if raw == null:
		return []
	if not (raw is PackedVector3Array or raw is Array):
		return []
	var out: Array = []
	for value in raw:
		if value is Vector3:
			out.append(value)
	return out

## Running water between two standing ones.
##
## WHY A HAND-BUILT RIBBON AND NOT A CSGPolygon3D ALONG A Path3D. Four
## reasons, in the order they decided it:
##
##   1. There is not ONE CSG node anywhere in this repository -- grepped,
##      not assumed. Every piece of hub decor is a primitive built in code.
##      A stream is not the place to introduce a second paradigm.
##   2. CSG is a runtime solver: a CSGShape3D keeps a brush and re-evaluates
##      it, and it carries a use_collision flag that would have to be
##      explicitly held off against this screen's standing rule that nothing
##      on the plateau has physics. An ArrayMesh is baked once, here, and
##      has no flag that can turn into a collider by default.
##   3. Segment control. CSGPolygon3D's path mode subdivides by an interval,
##      which is an indirect handle on the thing that actually matters --
##      the flat-edge deviation on a curve. STREAM_SAMPLES_PER_SPAN sets it
##      directly, the same way LAKE_SEGMENTS was calibrated to its radius.
##   4. A CSG node is not a MeshInstance3D, so it could not go through
##      _unshaded() -- and this file having exactly one material factory is
##      what keeps every surface on the plateau honest.
##
## ZERO THICKNESS, drawn double-sided. _make_water_body spells out why a
## flat water surface must never show its own edge; a ribbon with no
## thickness cannot, and CULL_DISABLED answers the "a plane is single-sided"
## objection by construction rather than by hoping nobody looks from below.
func _make_stream(entry: Dictionary) -> Node3D:
	var trace: Array = _trace_points(entry)
	if trace.size() < 2:
		push_error("HubBuilder: a stream needs at least 2 trace points, got %d." % trace.size())
		return null
	for key in ["position", "rotation_y", "scale"]:
		if entry.has(key):
			push_warning("HubBuilder: a stream entry carries '%s'; its trace IS its placement, so the field is ignored." % key)

	var width: float = entry.get("width", STREAM_WIDTH)
	if width <= 0.0:
		push_error("HubBuilder: a stream needs a positive width, got %f." % width)
		return null
	var half: float = width * 0.5
	_stream_half_width = half
	var spine: Array = _centripetal(trace, STREAM_SAMPLES_PER_SPAN)
	# Kept so HubStreamRoute can be handed the curve that was BUILT.
	# See stream_spine() for why it is not re-derived from the trace.
	_stream_spine = spine

	var left: Array = []
	var right: Array = []
	for i in spine.size():
		var before: Vector3 = spine[maxi(0, i - 1)]
		var after: Vector3 = spine[mini(spine.size() - 1, i + 1)]
		var tangent := Vector3(after.x - before.x, 0.0, after.z - before.z)
		if tangent.length() < 0.0001:
			tangent = Vector3(0.0, 0.0, 1.0)
		tangent = tangent.normalized()
		# Perpendicular in the ground plane. The ribbon is flat by
		# construction: y comes from the constant, never from the trace, so
		# a control point authored with a stray y cannot tilt the water.
		var side := Vector3(-tangent.z, 0.0, tangent.x) * half
		var middle: Vector3 = spine[i]
		left.append(Vector3(middle.x - side.x, STREAM_SURFACE_Y, middle.z - side.z))
		right.append(Vector3(middle.x + side.x, STREAM_SURFACE_Y, middle.z + side.z))

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in spine.size() - 1:
		for vertex in [left[i], right[i], right[i + 1], left[i], right[i + 1], left[i + 1]]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(vertex)

	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	var material := _unshaded(STREAM_WATER_COLOR)
	# Same trap the ponds hit: albedo_color's alpha is ignored entirely
	# while transparency stays DISABLED, and the stream would render as
	# flat opaque cyan with no error to say so.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.set_surface_override_material(0, material)
	return node

## An open nutshell, floating in the stream.
##
## SYMMETRIC FORE AND AFT, deliberately: the ride is bidirectional (its
## direction comes from where the player tapped, not from the layout), so
## a hull with a bow would be pointing the wrong way half the time and
## would need an orientation this file has no way to know. A shape with no
## front cannot be back to front.
##
## Built with SurfaceTool and NOT a CSG node, for the four reasons
## _make_stream() spells out -- there is not one CSG node in this
## repository, CSG is a runtime solver carrying a use_collision flag this
## screen must not grow, segment control here is direct, and a CSG node
## could not go through _unshaded().
##
## The shell is drawn DOUBLE-SIDED and hollow rather than as a closed
## solid: one surface then reads as a bowl from above and as a hull from
## the side, which is both the cheaper mesh and the shape a walnut half
## actually is. It carries NO collider, like every other prop here -- the
## ride is driven by an abscissa along HubStreamRoute, never by physics.
func _make_boat() -> Node3D:
	var root := Node3D.new()
	var shell := _mesh_node(_boat_shell_mesh(), BOAT_HULL_COLOR, Vector3(0.0, BOAT_FLOAT_Y, 0.0))
	# The shell is an open surface, so its inside faces AWAY from the
	# camera: at the default cull mode the bowl would be an invisible hole
	# with a rim floating over it. Same class of trap as the ponds' alpha
	# flag -- correct-looking geometry, nothing drawn, and no error to say
	# so. The rim is a flat annulus seen from above and needs no such help.
	var shell_material: StandardMaterial3D = shell.get_surface_override_material(0)
	shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(shell)
	# The hollow, drawn as its own slightly smaller shell in the light
	# tone. Inset so the dark outer wall still shows as a thickness at the
	# rim rather than the two surfaces meeting exactly.
	var inner := _mesh_node(_boat_shell_mesh(BOAT_INNER_INSET), BOAT_INNER_COLOR,
		Vector3(0.0, BOAT_FLOAT_Y + 0.005, 0.0))
	var inner_material: StandardMaterial3D = inner.get_surface_override_material(0)
	inner_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(inner)
	root.add_child(_mesh_node(_boat_rim_mesh(), BOAT_RIM_COLOR, Vector3(0.0, BOAT_FLOAT_Y, 0.0)))
	return root

## The hull: the lower half of an ellipsoid, keel at -BOAT_DEPTH, rim at 0.
##
## Parameterised by a quarter turn so the wall is vertical at the rim and
## flat at the keel -- a straight-sided cone would read as a bucket, and a
## hemisphere with the rim's radius would sit too deep for a hull under a
## metre long.
func _boat_shell_mesh(inset: float = 0.0) -> ArrayMesh:
	var half_beam: float = BOAT_BEAM * 0.5 - inset
	var half_length: float = BOAT_LENGTH * 0.5 - inset
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in BOAT_TIERS:
		var phi_a: float = PI * 0.5 * float(tier) / float(BOAT_TIERS)
		var phi_b: float = PI * 0.5 * float(tier + 1) / float(BOAT_TIERS)
		for seg in BOAT_RADIAL_SEGMENTS:
			var th_a: float = TAU * float(seg) / float(BOAT_RADIAL_SEGMENTS)
			var th_b: float = TAU * float(seg + 1) / float(BOAT_RADIAL_SEGMENTS)
			var quad: Array = [
				_boat_shell_point(phi_a, th_a, half_beam, half_length),
				_boat_shell_point(phi_b, th_a, half_beam, half_length),
				_boat_shell_point(phi_b, th_b, half_beam, half_length),
				_boat_shell_point(phi_a, th_a, half_beam, half_length),
				_boat_shell_point(phi_b, th_b, half_beam, half_length),
				_boat_shell_point(phi_a, th_b, half_beam, half_length),
			]
			for vertex in quad:
				tool.set_normal(Vector3.UP)
				tool.add_vertex(vertex)
	var mesh: ArrayMesh = tool.commit()
	return mesh

func _boat_shell_point(phi: float, theta: float, half_beam: float, half_length: float) -> Vector3:
	var r: float = sin(phi)
	return Vector3(
		half_beam * r * sin(theta),
		-BOAT_DEPTH * cos(phi),
		half_length * r * cos(theta))

## The cut edge of the shell: a flat annulus at the rim, in the lighter
## tint. Small, and it is what makes the hollow legible at the size this is
## drawn -- without it the bowl reads as a dark blob.
func _boat_rim_mesh() -> ArrayMesh:
	var inner_beam: float = BOAT_BEAM * 0.5
	var inner_length: float = BOAT_LENGTH * 0.5
	var outer_beam: float = inner_beam + BOAT_RIM
	var outer_length: float = inner_length + BOAT_RIM
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in BOAT_RADIAL_SEGMENTS:
		var th_a: float = TAU * float(seg) / float(BOAT_RADIAL_SEGMENTS)
		var th_b: float = TAU * float(seg + 1) / float(BOAT_RADIAL_SEGMENTS)
		var ia := Vector3(inner_beam * sin(th_a), 0.0, inner_length * cos(th_a))
		var ib := Vector3(inner_beam * sin(th_b), 0.0, inner_length * cos(th_b))
		var oa := Vector3(outer_beam * sin(th_a), 0.0, outer_length * cos(th_a))
		var ob := Vector3(outer_beam * sin(th_b), 0.0, outer_length * cos(th_b))
		for vertex in [ia, oa, ob, ia, ob, ib]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(vertex)
	var mesh: ArrayMesh = tool.commit()
	return mesh

## Centripetal Catmull-Rom (alpha = 0.5) through the control points.
##
## CENTRIPETAL AND NOT UNIFORM, and it is the difference between a stream
## that fits and one that does not. The uniform form overshoots on a tight
## bend, and measured on this plateau that overshoot alone pushed the ribbon
## 0.4 units into props the trace was routed to clear. Centripetal is the
## variant that provably produces no cusp and no self-intersection.
##
## The end tangents are mirrored rather than duplicated, so the curve leaves
## each water body along the direction of its own first span instead of
## flattening against it.
func _centripetal(points: Array, per_span: int) -> Array:
	var padded: Array = []
	padded.append(points[0] * 2.0 - points[1])
	padded.append_array(points)
	padded.append(points[points.size() - 1] * 2.0 - points[points.size() - 2])

	var out: Array = []
	for i in padded.size() - 3:
		var p0: Vector3 = padded[i]
		var p1: Vector3 = padded[i + 1]
		var p2: Vector3 = padded[i + 2]
		var p3: Vector3 = padded[i + 3]
		var t0: float = 0.0
		var t1: float = t0 + sqrt(maxf(p0.distance_to(p1), 0.0001))
		var t2: float = t1 + sqrt(maxf(p1.distance_to(p2), 0.0001))
		var t3: float = t2 + sqrt(maxf(p2.distance_to(p3), 0.0001))
		var last: int = per_span - 1
		if i == padded.size() - 4:
			last = per_span
		for k in last + 1:
			var t: float = t1 + (t2 - t1) * float(k) / float(per_span)
			var a1: Vector3 = p0.lerp(p1, (t - t0) / (t1 - t0))
			var a2: Vector3 = p1.lerp(p2, (t - t1) / (t2 - t1))
			var a3: Vector3 = p2.lerp(p3, (t - t2) / (t3 - t2))
			var b1: Vector3 = a1.lerp(a2, (t - t0) / (t2 - t0))
			var b2: Vector3 = a2.lerp(a3, (t - t1) / (t3 - t1))
			out.append(b1.lerp(b2, (t - t1) / (t2 - t1)))
	return out

## An orientation marker, readable from the far side of the plateau.
##
## ~8.4 units tall against a standard tree's 2.85 -- roughly 3x, which is
## what buys it back over the tree field at 25+ units. Height alone is not
## enough though: a tree scaled up is still tree-shaped and reads as more
## of the same, so each variant is a DIFFERENT SILHOUETTE (a needle, a
## blocky pile, a pair of standing slabs). Telling one landmark from
## another at a glance is what carries orientation; merely having four of
## them does not.
##
## "variant" picks the silhouette, same mechanism as flower -- out of
## range falls back to 0 so a layout written without the field still
## builds.
func _make_landmark(entry: Dictionary) -> Node3D:
	var variant: int = entry.get("variant", 0)
	match variant:
		1:
			return _make_landmark_cairn()
		2:
			return _make_landmark_slabs()
		_:
			return _make_landmark_spire()

## Variant 0 -- a narrow needle. Distinguished at distance by being thin.
func _make_landmark_spire() -> Node3D:
	var root := Node3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.42
	trunk.height = 5.2
	trunk.radial_segments = 8
	trunk.rings = 1
	root.add_child(_mesh_node(trunk, LANDMARK_SPIRE_TRUNK, Vector3(0.0, 2.6, 0.0)))
	# Cones are CylinderMesh with a zero top radius; three stacked ones
	# give the stepped conifer edge a single cone cannot.
	var tiers: Array = [[1.25, 2.4, 5.0], [0.95, 2.1, 6.3], [0.62, 1.8, 7.55]]
	for tier in tiers:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tier[0]
		cone.height = tier[1]
		cone.radial_segments = 8
		cone.rings = 1
		root.add_child(_mesh_node(cone, LANDMARK_SPIRE_CROWN, Vector3(0.0, tier[2], 0.0)))
	return root

## Variant 1 -- a blocky stacked mass. The opposite read to the spire:
## wide, stepped, and grey rather than green.
func _make_landmark_cairn() -> Node3D:
	var root := Node3D.new()
	var blocks: Array = [
		[Vector3(2.60, 1.50, 2.40), 0.75, 0.0, LANDMARK_CAIRN_STONE],
		[Vector3(2.10, 1.70, 1.90), 2.30, 22.0, LANDMARK_CAIRN_STONE],
		[Vector3(1.55, 1.90, 1.45), 4.00, -18.0, LANDMARK_CAIRN_STONE],
		[Vector3(1.05, 1.50, 0.95), 5.60, 35.0, LANDMARK_CAIRN_CAP],
	]
	for block in blocks:
		var box := BoxMesh.new()
		box.size = block[0]
		root.add_child(_mesh_node(box, block[3], Vector3(0.0, block[1], 0.0), Vector3(0.0, block[2], 0.0)))
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.55
	spike.height = 2.2
	spike.radial_segments = 6
	spike.rings = 1
	root.add_child(_mesh_node(spike, LANDMARK_CAIRN_CAP, Vector3(0.0, 7.3, 0.0)))
	return root

## Variant 2 -- two standing slabs of unequal height. Reads as a pair of
## vertical bars, which neither of the other two can be mistaken for.
func _make_landmark_slabs() -> Node3D:
	var root := Node3D.new()
	var rubble := BoxMesh.new()
	rubble.size = Vector3(2.90, 0.70, 1.90)
	root.add_child(_mesh_node(rubble, LANDMARK_SLAB_BASE, Vector3(0.0, 0.35, 0.0), Vector3(0.0, 6.0, 0.0)))
	var tall := BoxMesh.new()
	tall.size = Vector3(1.15, 8.00, 0.60)
	root.add_child(_mesh_node(tall, LANDMARK_SLAB_STONE, Vector3(-0.85, 4.00, 0.10), Vector3(0.0, 12.0, -4.0)))
	var short := BoxMesh.new()
	short.size = Vector3(0.95, 6.60, 0.50)
	root.add_child(_mesh_node(short, LANDMARK_SLAB_STONE, Vector3(0.90, 3.30, -0.15), Vector3(0.0, -18.0, 5.0)))
	return root

func _mesh_node(mesh: Mesh, colour: Color, offset: Vector3, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = offset
	node.rotation_degrees = rotation_deg
	node.set_surface_override_material(0, _unshaded(colour))
	return node

## The one material this file ever makes. UNSHADED is the project's
## standing rule for every surface (see the header), and having a single
## factory is what keeps a batched prop's material identical to the
## individual-node one it replaced.
func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material
