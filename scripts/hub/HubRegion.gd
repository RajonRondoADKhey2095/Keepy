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
## THE REGION -- square OR shore pad, NO SUBTRACTION, since 26 aout 2026
##
##   ( square(+-PLATEAU_HALF_EXTENT)  OR  shore pad )
##
## Water is a PLACE, not a hole. Mathieu's explicit decision: Keepy must be
## able to walk into all five water bodies on the plateau -- the pond, the
## small lake, the stream, and both great-lake lobes -- and this file no
## longer excludes any of them. The two great-lake lobes were the only
## family ever subtracted here (see the superseded section below for why
## and how); that subtraction is gone, and this class draws exactly the
## shape it drew before the lake zone ever existed. `docs/WATER_WALK_RECON.md`
## and `docs/WATER_ACCESS_RENDER_RECON.md` are the recon that led here --
## the "arret a la berge" bank-stop line of work both describe is
## ABANDONED, not resumed.
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
## lake back out through an edge gets the lobe back for free. It was never
## part of the water guard and this batch does not touch it.
##
## WHAT STILL LIVES HERE, and why removing the guard did not delete this
## file: `_lakes`, `lakes()`, `lake_index_at()` and `water_radius_at()` are
## HubBuilder's ONLY source for the two great-lake discs' size and draw
## order -- see `HubBuilder._make_greatlake()`. `in_lake_water()` is a
## general "is this point inside the great lake" query with two live
## callers of its own (LakeZoneProbe's wet-landing report, and the future
## submersion-render work `docs/WATER_ACCESS_RENDER_RECON.md` Q1/Q4 names
## it as the foundation for). None of that is the guard; the guard was
## exactly one line in contains() plus the out-of-water candidates it fed
## clamp_to(), and both are gone -- see contains()'s and clamp_to()'s own
## docblocks.
##
## =====================================================================
## SUPERSEDED -- kept for the record, NOT a description of the shipped
## region. The paragraphs below describe the REMOVED subtraction and its
## measured cost while it existed. Nothing in them is true of the file as
## it ships today.
##
## "lake water" became PLURAL with SPAWN-LAKE-1: a second great-lake lobe
## sat at (-12, -19.5) radius 10, in front of the spawn. The subtraction
## was a LOOP over LAKES rather than a second hard-coded disc, so a third
## lobe was a row in that table and nothing else -- which is also why the
## table itself did not need to change to remove the guard.
##
## The subtraction answered "a tap on the lake must not walk Keepy into
## it": the water was a hole in the region, so a tap there was clamped to
## the rim exactly as a tap past the square edge is clamped to the edge.
## With the lake in the MIDDLE of the square that hole was interior rather
## than edge-adjacent, which `_out_of_lake()` (removed with the guard)
## handled by pushing radially rather than assuming where the disc sat.
## MEASURED after LAKE-MOVE, not inferred: 8 taps on the water from 8
## different azimuths, 8 resolved onto dry land -- the inverse of what the
## guard's removal now measures (see LakeZoneProbe's PHASE TAP).
##
## ONLY THE GREAT-LAKE FAMILY WAS SUBTRACTED. The pond and the small lake
## were walkable since they shipped -- the boat ride boards from the
## stream head, which sits ON the pond's water rim -- so the asymmetry
## Mathieu's decision closes was already narrower than "every water body
## blocks Keepy": only the great lake ever did.
##
## WHAT THE LAKE COST WHILE IT WAS SUBTRACTED, measured with the lake
## INSIDE the square (post LAKE-MOVE):
##
##   water area removed from the square   804.5 u2  (16.42% of 4900)
##   walkable ground added by the shore pad   0 u2
##
## That 16.42% was the price the LAKE-MOVE recon put on the ONLY placement
## clearly visible from the plateau centre, and it is what Mathieu accepted
## when he picked it -- before deciding, in this batch, that the water
## should not be subtracted at all. WHAT IT NEVER COST: a single second of
## crossing, guard or no guard -- a lake cannot bend a chord, KeepyHopper
## walks a straight line and consults nothing, so the worst crossing is
## the square's own diagonal, 18.700 s, unchanged by this batch and
## measured rather than argued (see LakeZoneProbe's PHASE CROSSING).
##
## WHAT REMOVING THE GUARD COSTS, and there is no fix for it in this file:
## Keepy walks OVER every water body's surface, the great lake included
## now. That was already true of the pond, the small lake and the stream in
## production; this batch simply stops treating the great lake as an
## exception. Fixing the visual is a real mechanism -- colour grade, a
## scale/squash cue, waterline decals, a clip-plane shader -- none of which
## exists today (`docs/WATER_ACCESS_RENDER_RECON.md` Q3 measured that a Y
## offset alone renders nothing) and none of which this batch adds.

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

## Every great-lake disc, in the order the layout states them. No longer
## SUBTRACTS anything since 26 aout 2026 (see contains()'s docblock) -- this
## is now purely the draw/query table.
##
## ONE TABLE, and the builder reads its radii off it rather than carrying a
## second copy: the drawn disc has to stay the one circle in_lake_water()
## can still answer questions about, and two numbers describing one circle
## is exactly how a bank slab ends up slicing a prop nobody is warned about.
## The layout still states the CENTRES a second time -- that is what
## LakeZoneProbe's PHASE REGION gates, entry by entry.
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

## True when a point is inside the great lake's water. NOT wired into
## contains() any more -- see contains()'s own docblock, 26 aout 2026 -- so
## this is now a general water-membership query rather than the guard's
## implementation. Kept for two live callers: LakeZoneProbe's wet-landing
## report, and the reusable "which body is Keepy in" test that
## docs/WATER_ACCESS_RENDER_RECON.md Q1/Q4 names as the insertion point for
## a future submersion visual (a colour grade or clip shader keyed on depth
## -- that recon found Y-offset alone renders nothing, so any such lot needs
## exactly this membership test plus a real mechanism, not this file). The
## rim itself is still NOT water -- a point pushed to exactly the radius has
## to read as land, or a caller sampling the waterline gets a float coin-flip.
static func in_lake_water(point: Vector3) -> bool:
	return _lake_holding(_flat(point)) >= 0

## Every great-lake disc, centre and water radius, in the order the layout
## states them. Read-only by convention: it is the one table HubBuilder
## draws from and this file is not the walkable region for this family any
## more (see contains()) -- but the DRAWN disc still has to be the one
## in_lake_water() reports on, so a caller that mutated this out from under
## either would desync the water you can see from the water this file can
## still answer questions about.
static func lakes() -> Array[Dictionary]:
	return _lakes

## Water radius of the lake whose centre is `centre`, or -1.0 when no lake
## sits there. The builder uses it to size a drawn disc from the same number
## this table publishes, and gets -1.0 -- an error, not a default -- when a
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
##
## ⚠️ 26 AOUT 2026: THE GREAT-LAKE SUBTRACTION IS REMOVED, Mathieu's
## explicit decision -- Keepy must be able to walk into all five water
## bodies on the plateau, water is a place and not an obstacle, and this was
## the only one of the five that ever stopped him. `docs/WATER_WALK_RECON.md`
## and `docs/WATER_ACCESS_RENDER_RECON.md` are the recon that led here; the
## "arret a la berge" line of work both describe is ABANDONED, not resumed.
## This function is once again exactly what it was before the lake zone
## existed -- a square, unioned with the shore pad -- and no water body
## anywhere on the plateau removes ground from it. See in_lake_water()'s
## docblock for what still reads the great lake's geometry and why.
static func contains(point: Vector3) -> bool:
	var flat := _flat(point)
	if absf(flat.x) <= PLATEAU_HALF_EXTENT and absf(flat.z) <= PLATEAU_HALF_EXTENT:
		return true
	return flat.distance_to(_near_bank) <= SHORE_PAD_RADIUS

## The nearest point of the region to `point`, on the ground plane.
##
## A point outside is pulled in rather than dropped: a tap near the horizon
## is a player asking to go as far as they can, and refusing it silently
## reads as the screen being broken.
##
## ⚠️ NO LONGER PUSHED OUT OF LAKE WATER. Before the guard was removed, a
## tap ON the great lake was a point outside the region (contains() returned
## false for it) and needed a candidate pushed radially to the nearest
## waterline. Since water is no longer excluded from the region, a point
## inside a lake already satisfies contains() at the top of this function --
## both great-lake lobes' AABBs sit entirely inside the square, measured on
## each axis: lobe A spans x [-0.5, 31.5] / z [-35.0, -3.0], lobe B spans
## x [-22.0, -2.0] / z [-29.5, -9.5], and the square admits |axis| <= 35
## (lobe A's z touches the boundary exactly, still inclusive). So a lake
## point NEVER falls through to the candidate search below. The per-lake
## "push off the waterline" candidates this function used to generate are
## gone with it -- they were reachable only through the water exclusion
## this commit removes, so keeping them would have been dead code with
## nothing left to call it.
##
## Candidates rather than a closed form: the region is still a union of a
## square and a disc (the shore pad), so its nearest point is on one of a
## handful of features (the square's boundary, the pad's boundary, or a
## corner where the two meet). Generating those and taking the closest that
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

static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
