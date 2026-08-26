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
## The shore pad is a disc centred on the great lake's NEAR BANK, which is
## what lets the walkable ground follow the shore past the square's western
## edge. The subtraction is what answers "a tap on the lake must not walk
## Keepy into it": the water is a hole in the region, so a tap there is
## clamped to the rim exactly as a tap past the square edge is clamped to
## the edge.
##
## ONLY THE GREAT LAKE IS SUBTRACTED, and that asymmetry is deliberate.
## The pond and the small lake have been walkable since they shipped -- the
## boat ride boards from the stream head, which sits ON the pond's water rim
## -- and taking that away is a gameplay change this batch was not asked to
## make and could not validate. If the two ever need to agree, that is its
## own batch with its own device pass.
##
## =====================================================================
## MEASURED, NOT ASSUMED: THE PENINSULA HAS NO LENGTH
##
## The brief for this batch described a walkable strip BRIDGING the plateau
## edge to the lake's near shore. There is nothing to bridge, and the two
## fixed numbers are what say so: a lake of radius 20 whose centre is 54
## out has its near bank at 34, while the square's boundary along that same
## azimuth is at 35/|axis.x| = 35.782. The shore starts INSIDE the square.
##
## What that costs, measured on a 0.1-unit grid rather than argued:
##   - the water removes 27.6 u2 of square that used to be walkable
##   - the shore pad adds 91.6 u2 of walkable ground beyond the square
## So the extension is real, but it is a LOBE FOLLOWING THE SHORE, not a
## causeway, and the net gain is smaller than the pad alone suggests.
## Whoever tunes these numbers next should expect that, not rediscover it.

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
##   worst corner -> shore lobe    64     1088    18.133
##
## The lobe stays UNDER the diagonal, which is the property this batch was
## asked to preserve and which SHORE_PAD_RADIUS was sized against: at pad
## radius 24 the lobe reaches 18.983 s and becomes the worst case itself.
const PLATEAU_HALF_EXTENT: float = 35.0

## The great lake, in the azimuth convention every hub batch has used:
## 0 degrees is -Z, growing toward +X. The small lake of the earlier batch
## sits at azimuth 281.9, so 282 puts the great lake straight beyond it,
## on the same side of the plateau.
const LAKE_AZIMUTH_DEG: float = 282.0
const LAKE_CENTRE_DISTANCE: float = 54.0
const LAKE_WATER_RADIUS: float = 20.0

## Radius of the shore pad, centred on the near bank.
##
## SIZED BY MEASUREMENT, not chosen. Swept against the worst corner-to-lobe
## crossing, on the real hopper stepping rule:
##
##   pad   new walkable   worst crossing
##    12       12.8 u2       15.867 s
##    16       38.8 u2       17.283 s
##    20       91.6 u2       18.133 s   <- shipped
##    24      179.6 u2       18.983 s   -- passes 22 s, but BEATS the
##    28      311.9 u2       20.117 s      diagonal and becomes the new
##                                         worst case
##
## 20 is the largest pad that still leaves the square diagonal as the
## hub's worst crossing. Going past it does not break the 22 s budget; it
## breaks the simpler promise that the plateau's own diagonal is the
## longest walk in the game.
const SHORE_PAD_RADIUS: float = 20.0

## Unit vector along the lake axis, and the two points on it the region is
## built from. static var and not const because a const initialiser cannot
## call sin() -- writing the components as literals instead would be a
## second copy of the azimuth, free to drift from the degrees above.
static var _axis: Vector3 = Vector3(
	sin(deg_to_rad(LAKE_AZIMUTH_DEG)), 0.0, -cos(deg_to_rad(LAKE_AZIMUTH_DEG)))
static var _lake_centre: Vector3 = _axis * LAKE_CENTRE_DISTANCE
static var _near_bank: Vector3 = _axis * (LAKE_CENTRE_DISTANCE - LAKE_WATER_RADIUS)

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
	return _flat(point).distance_to(_lake_centre) < LAKE_WATER_RADIUS

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
	candidates.append(_out_of_water(flat))
	candidates.append(_out_of_water(square))
	candidates.append(_out_of_water(pad))

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

## `point` pushed radially out of the lake to just past the waterline. The
## nudge is what keeps the result on the land side of a strict comparison
## instead of on a float's coin-flip.
static func _out_of_water(point: Vector3) -> Vector3:
	var offset := point - _lake_centre
	if offset.length() < 0.0001:
		offset = _axis * -1.0
	return _lake_centre + offset.normalized() * (LAKE_WATER_RADIUS + 0.001)

static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
