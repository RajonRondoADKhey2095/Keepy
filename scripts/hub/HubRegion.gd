extends RefCounted
class_name HubRegion
## The shape of the walkable hub, and the ONE place that shape is defined.
##
## =====================================================================
## WHY A SHAPE AND NOT A SCALAR
##
## Until the lake zone the walkable hub was a square, and one float
## (PLATEAU_HALF_EXTENT) described it completely. The lot D recon measured
## why that float cannot simply grow: at half-extent 40 the worst crossing
## costs 21.533 s and at 41 it costs 22.100 s, over the 22 s the project
## holds itself to. Widening the SQUARE is spent; widening by SHAPE is not,
## because a narrow lobe adds reachable ground without adding anything to
## the corner-to-corner diagonal that sets the worst case.
##
## So the limit stopped being a number and became a region. Every site that
## used to clamp against the float now asks this class instead:
##
##   HubTapInput._handle_point  -> clamp_to()   (a tap becomes a destination)
##   HubBuilder._build          -> contains()   (is this prop walkable to)
##
## Neither recomputes the rule. Two copies of a play-area limit is how they
## drift apart, and that was already the reason the float had exactly one
## owner.
##
## =====================================================================
## THE REGION, AND THE ONE SUBTRACTION IN IT
##
##   ( square(+-PLATEAU_HALF_EXTENT)  OR  shore pad )  AND NOT  lake water
##
## "lake water" became PLURAL with SPAWN-LAKE-1: a second great-lake lobe
## sits at (-12, -19.5) radius 10, in front of the spawn. The subtraction
## is a LOOP over LAKES rather than a second hard-coded disc, so a third
## lobe is a row in that table and nothing else.
##
## The shore pad is a disc centred on the great lake's NEAR BANK. It used
## to be what let the walkable ground follow the shore past the square's
## western edge, back when the lake sat outside the square entirely.
## Since LAKE-MOVE it is INERT and measured so: with the centre at
## (15.5, -19) the near bank is at 8.52 from the plateau centre, so a pad
## of radius 20 around it spans x in [-14.6, 25.4] and z in [-26.6, 13.4]
## -- ENTIRELY inside the square, adding exactly 0 u2 of walkable ground.
## It is kept rather than deleted because it is the generic term of the
## union and costs nothing while contained; a future batch that pushes a
## lake back out through an edge gets the lobe back for free.
##
## The subtraction is what answers "a tap on the lake must not walk Keepy
## into it": the water is a hole in the region, so a tap there is clamped
## to the rim exactly as a tap past the square edge is clamped to the edge.
## With the lake now in the MIDDLE of the square that hole is interior
## rather than edge-adjacent, which _out_of_lake() already handled -- it
## pushes radially and never assumed where the disc sat. MEASURED after
## the move, not inferred: 8 taps on the water from 8 different azimuths,
## 8 resolved onto dry land.
##
## ONLY THE GREAT-LAKE FAMILY IS SUBTRACTED, and that asymmetry is
## deliberate.
## The pond and the small lake have been walkable since they shipped -- the
## boat ride boards from the stream head, which sits ON the pond's water rim
## -- and taking that away is a gameplay change this batch was not asked to
## make and could not validate. If the two ever need to agree, that is its
## own batch with its own device pass.
##
## =====================================================================
## WHAT THE LAKE COSTS, NOW THAT IT IS INSIDE
##
## The LAKE-1 batch measured a lake OUTSIDE the square: it removed 27.6 u2
## of walkable ground and the shore pad handed back 91.6 u2 beyond the
## edge, a lobe following the shore rather than a causeway. Both numbers
## are dead. The lake is inside now, so the pad reaches nothing new and
## the hole is paid for in full:
##
##   water area removed from the square   804.5 u2  (16.42% of 4900)
##   walkable ground added by the pad         0 u2
##
## That 16.42% was the price the recon put on the ONLY placement clearly
## visible from the plateau centre, and it is what Mathieu accepted when
## he picked it. 3 landmarks and 25 scatter props stood inside the new
## water and were RELOCATED, never deleted; 7 more stood in the lobe the
## pad used to reach and were relocated for the same reason.
##
## WHAT IT DOES NOT COST: a single second of crossing. A lake cannot bend
## a chord -- KeepyHopper walks a straight line and consults nothing --
## so the worst crossing is the square's own diagonal, 18.700 s, before
## and after, measured both times rather than argued.
##
## WHAT IT DOES COST, and there is no fix for it in this file: Keepy walks
## OVER the water. That was already true of the pond and the small lake in
## production, and an interior lake simply puts far more of it under the
## usual chords. Fixing it means obstacle avoidance in KeepyHopper, which
## exists nowhere in the repo and is its own project.

## Half-extent of the square part of the region. Moved here from
## HubTapInput when the limit stopped being a scalar: the shape has one
## owner, and this is it.
##
## Widened 11 -> 15 -> 25 -> 35 across the plateau batches. NOT widened
## again here, and deliberately: the lot D recon measured 40 as the last
## square half-extent under the 22 s crossing budget, so a square that grew
## with the lake would spend the whole remaining margin on ground nobody
## asked for.
##
## WHAT A CROSSING COSTS AT 35, measured on the shipped hopper at
## --fixed-fps 60 and the current HOP_DURATION of 0.28. WALL-CLOCK frames,
## not hops x HOP_DURATION: a 0.28 s hop occupies 17 frames (0.2833 s), so
## every trip costs ~1.2% more than the nominal arithmetic predicts. Quote
## the measured row, never the multiplication.
##
##   trip                        hops   frames    seconds
##   centre -> (35,0)              24      408     6.800
##   (-35,-35) -> (35,35)          66     1122    18.700   <- worst case
##
## Re-measured after LAKE-MOVE and unchanged to the frame: the diagonal is
## still the worst walk in the game.
const PLATEAU_HALF_EXTENT: float = 35.0

## The great lake, as a PLAIN CARTESIAN CENTRE.
##
## It used to be an azimuth (282 deg) and a distance (54) because the lake
## sat straight beyond the small lake, off the plateau entirely, and polar
## was the shorter way to say that. The LAKE-MOVE batch moved it INSIDE the
## square to (15.5, -19) -- the only candidate the recon measured as
## clearly visible from the plateau centre -- and polar stopped being the
## shorter way to say anything: the layout states the centre in cartesian,
## so an azimuth here would be a second spelling of it, free to drift by a
## rounding error nobody would see until a bank slab sliced a prop.
##
## The azimuth and the distance are still PUBLISHED below, derived from
## this pair rather than the other way round, because the probe and the
## shore pad both still speak in them.
##
## RADIUS 16 IS THE MAXIMUM, and it is measured, not chosen. The recon
## swept the whole legal box at 0.5 u: at radius 20 and at radius 18 there
## is NO centre anywhere that keeps the disc inside the square while
## clearing the pond, the stream and the three portals. 16 is the largest
## that fits, and its best centre is the one written here.
##
## NAMED "GREATLAKE_WATER_RADIUS", not "LAKE_WATER_RADIUS": that name used
## to collide with `HubBuilder.LAKE_WATER_RADIUS` (the SMALL lake's 8.0) --
## same identifier, two different bodies, two different files, and no
## compiler error to catch a future edit that read the wrong one. A pure
## rename, no value change on either side; matches HubBuilder's own
## GREATLAKE_* prefix for this same body.
const LAKE_CENTRE_X: float = 15.5
const LAKE_CENTRE_Z: float = -19.0
const GREATLAKE_WATER_RADIUS: float = 16.0

## The SECOND great-lake lobe, added by SPAWN-LAKE-1, in front of the spawn.
##
## RADIUS 10 IS THE MAXIMUM, and it is measured rather than chosen. The
## SPAWN-LAKE recon swept the whole half-plane in front of the spawn: at
## radius 16 there are 66 centres that clear the three portals and NOT ONE
## of them also clears the waters already in place; 14 and 12 find nothing
## at all. 10 is the largest radius with a clean centre, and (-12, -19.5)
## is the one of the 142 that sits closest to the spawn.
##
## It is a SEPARATE ENTRY rather than a bigger first lake because the two
## are 1.505 u apart water to water: they are two lobes of what reads as
## one mass, not one disc.
const SPAWN_LAKE_CENTRE_X: float = -12.0
const SPAWN_LAKE_CENTRE_Z: float = -19.5
const SPAWN_LAKE_WATER_RADIUS: float = 10.0

## Radius of the shore pad, centred on the near bank.
##
## INERT SINCE LAKE-MOVE, and left at its measured value rather than
## zeroed. It was sized by sweeping the worst corner-to-lobe crossing on
## the real hopper (12 -> 15.867 s, 16 -> 17.283 s, 20 -> 18.133 s,
## 24 -> 18.983 s, which beat the diagonal and became the worst case), so
## 20 was the largest pad that still left the square diagonal as the hub's
## worst walk. With the lake inside the square the pad no longer reaches
## past any edge -- see the header for the containment arithmetic -- so it
## contributes 0 u2 and 0 s today. Zeroing it would delete a measured
## number to say the same thing; changing it now would change nothing.
const SHORE_PAD_RADIUS: float = 20.0

## The centre, and the two things every other rule here is built from.
## static var and not const because a const initialiser cannot call
## normalized() or atan2() -- writing the results as literals instead would
## be a second copy of the centre, free to drift from the pair above.
static var _lake_centre: Vector3 = Vector3(LAKE_CENTRE_X, 0.0, LAKE_CENTRE_Z)
static var _axis: Vector3 = _lake_centre.normalized()
static var _near_bank: Vector3 = _axis * (_lake_centre.length() - GREATLAKE_WATER_RADIUS)

## Every disc the region subtracts, in the order the layout states them.
##
## ONE TABLE, and the builder reads its radii off it rather than carrying a
## second copy: the walkable hole and the drawn disc have to be the same
## circle, and two numbers describing one circle is exactly how a bank slab
## ends up slicing a prop nobody is warned about. The layout still states
## the CENTRES a second time -- that is what LakeZoneProbe's PHASE REGION
## gates, entry by entry.
static var _lakes: Array[Dictionary] = [
	{"centre": Vector3(LAKE_CENTRE_X, 0.0, LAKE_CENTRE_Z), "radius": GREATLAKE_WATER_RADIUS},
	{"centre": Vector3(SPAWN_LAKE_CENTRE_X, 0.0, SPAWN_LAKE_CENTRE_Z), "radius": SPAWN_LAKE_WATER_RADIUS},
]

## Published for the probe and for anyone reasoning in the hub's usual
## polar convention (0 degrees is -Z, growing toward +X). DERIVED, never a
## second source of truth: change the centre above and these follow.
static var LAKE_CENTRE_DISTANCE: float = _lake_centre.length()
static var LAKE_AZIMUTH_DEG: float = fposmod(
	rad_to_deg(atan2(LAKE_CENTRE_X, -LAKE_CENTRE_Z)), 360.0)

## Unit vector from the plateau centre toward the lake centre.
static func lake_axis() -> Vector3:
	return _axis

## Centre of the great lake, in world units.
static func lake_centre() -> Vector3:
	return _lake_centre

## The point where the lake's near bank crosses the lake axis. Also the
## centre of the shore pad, which is why the pad's walkable half is the
## half AWAY from the water: its centre sits exactly on the waterline.
static func near_bank() -> Vector3:
	return _near_bank

## True when a point is inside the great lake's water. The rim itself is
## NOT water -- a point pushed out to exactly the radius has to count as
## land, or clamp_to() could never produce a valid answer.
static func in_lake_water(point: Vector3) -> bool:
	return _lake_holding(_flat(point)) >= 0

## Every subtracted disc, centre and water radius. Read-only by convention:
## it is the one table, and a caller that mutated it would move the walkable
## hole without moving the drawn one.
static func lakes() -> Array[Dictionary]:
	return _lakes

## Water radius of the lake whose centre is `centre`, or -1.0 when no lake
## sits there. The builder uses it to size a drawn disc from the same number
## the region subtracts, and gets -1.0 -- an error, not a default -- when a
## layout entry names a centre this table does not know.
static func water_radius_at(centre: Vector3) -> float:
	var index := lake_index_at(centre)
	return -1.0 if index < 0 else float(_lakes[index]["radius"])

## Index of the lake whose centre is `centre`, or -1. Exposed because the
## builder keys its per-lake slab heights off the same order.
static func lake_index_at(centre: Vector3) -> int:
	var flat := _flat(centre)
	for index in _lakes.size():
		if flat.distance_to(_lakes[index]["centre"] as Vector3) < 0.001:
			return index
	return -1

## Index of the lake `flat` is inside, or -1. The rim itself is NOT water
## -- see in_lake_water's contract, which this implements.
static func _lake_holding(flat: Vector3) -> int:
	for index in _lakes.size():
		if flat.distance_to(_lakes[index]["centre"] as Vector3) < float(_lakes[index]["radius"]):
			return index
	return -1

## The one membership test. Everything else in this file is built on it.
static func contains(point: Vector3) -> bool:
	var flat := _flat(point)
	if in_lake_water(flat):
		return false
	if absf(flat.x) <= PLATEAU_HALF_EXTENT and absf(flat.z) <= PLATEAU_HALF_EXTENT:
		return true
	return flat.distance_to(_near_bank) <= SHORE_PAD_RADIUS

## The nearest point of the region to `point`, on the ground plane.
##
## A point outside is pulled in rather than dropped, which is the rule the
## square clamp already followed and the reason it is worth keeping: a tap
## near the horizon is a player asking to go as far as they can, and
## refusing it silently reads as the screen being broken. A tap on the lake
## is the same request against a hole in the middle of the region, and gets
## the same answer -- the nearest piece of shore.
##
## Candidates rather than a closed form: the region is a union minus a
## disc, so its nearest point is on one of a handful of features (the
## square's boundary, the pad's boundary, the waterline, or a corner where
## two of those meet). Generating those and taking the closest that
## actually passes contains() is both shorter and harder to get subtly
## wrong than case-splitting the geometry by hand.
static func clamp_to(point: Vector3) -> Vector3:
	var flat := _flat(point)
	if contains(flat):
		return flat

	var candidates: Array[Vector3] = []
	var square := Vector3(
		clampf(flat.x, -PLATEAU_HALF_EXTENT, PLATEAU_HALF_EXTENT), 0.0,
		clampf(flat.z, -PLATEAU_HALF_EXTENT, PLATEAU_HALF_EXTENT))
	var pad := _near_bank + (flat - _near_bank).limit_length(SHORE_PAD_RADIUS)
	candidates.append(square)
	candidates.append(pad)
	for index in _lakes.size():
		candidates.append(_out_of_lake(flat, index))
		candidates.append(_out_of_lake(square, index))
		candidates.append(_out_of_lake(pad, index))

	var best := Vector3.ZERO
	var best_distance := INF
	for candidate in candidates:
		if not contains(candidate):
			continue
		var distance: float = candidate.distance_squared_to(flat)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	# The plateau centre is in the region by construction, so the fallback
	# is a real point and never a null-ish (0,0,0) that happens to look
	# like one. It should be unreachable; it exists so this function can
	# promise a valid destination rather than only usually returning one.
	return best

## `point` pushed radially out of lake `index` to just past its waterline.
## The nudge is what keeps the result on the land side of a strict
## comparison instead of on a float's coin-flip.
##
## Called once per lake by clamp_to rather than once for "the" lake: with
## two lobes, pushing out of the one the point happens to be inside can
## land it inside the other, and only contains() is entitled to decide.
static func _out_of_lake(point: Vector3, index: int) -> Vector3:
	var centre: Vector3 = _lakes[index]["centre"]
	var radius: float = _lakes[index]["radius"]
	var offset := point - centre
	if offset.length() < 0.0001:
		offset = centre.normalized() * -1.0 if centre.length() > 0.0001 else Vector3.FORWARD
	return centre + offset.normalized() * (radius + 0.001)

static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
