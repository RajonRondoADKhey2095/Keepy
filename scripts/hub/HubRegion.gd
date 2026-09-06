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
## THE REGION -- square OR shore pad OR north lobe OR a structure lobe,
## NO SUBTRACTION
##
##   ( square(+-PLATEAU_HALF_EXTENT)  OR  shore pad  OR  north lobe
##     OR any structure lobe )
##
## THE NORTH LOBE (28 aout 2026) is the shape argument above, used for the
## first time on purpose rather than on water. Mathieu's decision, taken on
## the recon that measured it: a disc of radius 12 centred on the MIDDLE OF
## THE NORTH EDGE, (0, +35), unioned in. Only its outer half is new ground
## -- the inner half is already square -- so it is written as a full disc
## because the two spellings are the same region and a disc is the one this
## file already knows how to clamp to.
##
##   new walkable ground   pi * 12^2 / 2  =  226.195 u2   (+4.616% of 4900)
##   worst crossing        UNCHANGED, and that is the whole point
##
## Radius 12 was the most conservative of the four sizes the recon measured.
## +Z rather than any other azimuth because the recon found the outer half
## EMPTY: the layout's largest |z| is 33.895, so nothing at all stands past
## the north edge and the lobe costs no prop a relocation. It sits BEHIND
## the spawn -- HubCamera never yaws, so the player only ever sees what is
## at lower z than Keepy -- which Mathieu accepted when he picked the
## azimuth, on the same terms as the turnstile before it.
##
## =====================================================================
## THE STRUCTURE LOBES (3 septembre 2026) -- the same shape argument, used
## for a POINT rather than for an edge.
##
## The north lobe above answers "the middle of the +Z edge should have more
## room". This table answers a different question: a STRUCTURE the layout
## stands ON an edge puts parts of itself PAST that edge, and the ground
## those parts stand on has to be walkable or the prop is unusable from the
## side it is built on.
##
## The zipline's north tower is the first. MEASURED on the built tree, not
## inferred from the layout:
##
##   P2 tower position          (25.2, 0, 35.0)   EXACTLY on the half-extent
##   P2 stair_foot              (25.037, 0, 36.682)   1.682 u past the edge
##   stringer feet              1.7414 u from P2, deepest z = 36.7226
##   rear legs                  0.7778 u from P2, z = 35.600 / 35.494
##   contains() on all five     FALSE, before this table existed
##
## WHY THE STAIR RUNS THAT WAY, and why it is not a bug to fix at the
## builder: `_build_zipline_tower` runs each tower's stair BEHIND it
## relative to that tower's own `forward` ("toward the other tower"). At
## P1 that points inward; at P2 the same rule points further north. One
## builder, two towers, one facing rule -- the symmetry `_make_zipline()`
## documents as deliberate. Re-orienting the north stair alone would break
## that symmetry AND still leave the rear legs outside, so the region is
## where this is answered.
##
## RADIUS 3.0, and the margin is the point rather than the minimum. The
## furthest thing the tower puts on the ground is 1.7414 u from P2 and the
## published circumscribed footprint is 1.78308 u, so 3.0 leaves 1.2169 u
## of walkable ground beyond the widest part of the prop -- nearly two
## KEEPY_CLEARANCE (0.66) of room to manoeuvre, not a rim that just barely
## admits the stair.
##
## WHAT IT COSTS, measured on the real hopper at --fixed-fps 60 BEFORE the
## table was added (a recon spike, deleted with the batch that acted on it)
## rather than argued from the geometry:
##
##   square diagonal (published)                66 hops   18.700 s
##   far corner -> P2 lobe tip, r = 2.0         63 hops   17.850 s
##   far corner -> P2 lobe tip, r = 3.0         64 hops   18.133 s   <- shipped
##   far corner -> P2 lobe tip, r = 5.0         65 hops   18.417 s
##
## The diagonal is STILL the hub's worst walk at every radius swept, which
## is the same reason the north lobe was affordable: a lobe bolted near an
## EDGE adds no length to a diagonal between CORNERS. Gated, not assumed --
## SeesawProbe's PHASE CROSSING walks the P2 row alongside the diagonal.
##
## THE NEW GROUND IS EMPTY, measured on the shipped layout: sweeping every
## prop footprint and both great-lake discs, NOTHING reaches within 5.0 u
## of P2 except the zipline tower itself, and the existing north lobe's rim
## is 13.200 u away -- the two discs do not touch, so neither can shadow
## the other.
##
## A TABLE AND NOT A SECOND SCALAR, from the first entry. This repo has
## already paid for the other choice: the diving board shipped a generic
## geometry behind a singleton, and a second board was drawn and never
## climbable. A second structure on an edge is a row here and nothing else.
##
## ⚠️ THE CENTRE IS A SECOND SPELLING OF THE LAYOUT'S "far_end", exactly as
## the lake centres are a second spelling of theirs, and it is gated the
## same way rather than trusted: ZiplineStructureProbe's PHASE H checks
## this table against the tower the builder actually stood there.
##
## WHY UNION AND NOT A SEPARATE ZONE: every site that asks this file a
## question keeps asking the same one. contains() and clamp_to() are the
## only two entry points, and neither grew a case for the lobe that the
## square and the pad did not already need -- which is what "option A" was
## chosen for, and is measured by SeesawProbe's PHASE LOBE rather than
## assumed.
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

## The north lobe: a disc unioned onto the middle of the +Z edge.
##
## THE CENTRE IS ON THE EDGE, NOT PAST IT. Half the disc therefore lies
## inside the square and contributes nothing, which is deliberate: a lobe
## whose centre sat outside would either leave a notch where it meets the
## edge or need a second term to fill one, and the union of a square with a
## disc that straddles its boundary has neither problem.
##
## RADIUS 12, the most conservative of the four the recon measured, and the
## reason a lobe is affordable at all where a wider square is not: the
## square's corner-to-corner diagonal is what sets the worst crossing
## (18.700 s at half-extent 35, measured on the shipped hopper), and a lobe
## bolted onto an EDGE adds no length to a diagonal between CORNERS. The
## number is gated rather than argued -- SeesawProbe walks the region's
## worst pair on the real hopper and checks the diagonal is still it.
const NORTH_LOBE_RADIUS: float = 12.0

## Radius of every structure lobe. ONE number for the family rather than a
## per-row float: the rule this table encodes is "a structure standing on
## an edge gets room to be walked around", and that room is a property of
## KEEPY_CLEARANCE and of how wide these props get, not of which prop it
## is. A row that genuinely needed its own radius would be a different
## rule, and would say so by growing a "radius" key here.
##
## 3.0 is measured, not chosen -- see the header for the five as-built
## points it has to cover and the crossing sweep that shows it costs the
## worst case nothing.
const STRUCTURE_LOBE_RADIUS: float = 3.0

## Every structure lobe, in layout order. PLURAL FROM THE FIRST ENTRY, on
## the same terms as `_lakes` and for the reason the diving board taught
## this repo: a singleton that later needs a second entry costs its own
## batch to undo.
##
## Written as a table of centres rather than derived from the layout
## because this file cannot read the layout -- HubBuilder asks contains()
## WHILE it builds. That makes the centre a second spelling, and a second
## spelling is only safe when something gates it: ZiplineStructureProbe's
## PHASE H compares this row to the tower as built, so the two cannot
## drift apart in silence.
static var _structure_lobes: Array[Dictionary] = [
	{"centre": Vector3(25.2, 0.0, 35.0), "radius": STRUCTURE_LOBE_RADIUS},
]

## The centre, and the two things every other rule here is built from.
## static var and not const because a const initialiser cannot call
## normalized() or atan2() -- writing the results as literals instead would
## be a second copy of the centre, free to drift from the pair above.
static var _lake_centre: Vector3 = Vector3(LAKE_CENTRE_X, 0.0, LAKE_CENTRE_Z)
static var _axis: Vector3 = _lake_centre.normalized()
static var _near_bank: Vector3 = _axis * (_lake_centre.length() - GREATLAKE_WATER_RADIUS)

## Centre of the north lobe: the midpoint of the +Z edge, DERIVED from the
## half-extent rather than written as a literal 35. The lobe is defined as
## "on the north edge", so if the square ever moves the lobe has to move
## with it, and a literal is how the two would stop agreeing.
static var _north_lobe: Vector3 = Vector3(0.0, 0.0, PLATEAU_HALF_EXTENT)

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

## Centre of the north lobe, in world units. Published so a probe and a
## layout author can both aim at the lobe without restating where the north
## edge is.
static func north_lobe_centre() -> Vector3:
	return _north_lobe

## Every structure lobe, centre and radius, in layout order. Published so a
## probe can gate each row against the prop it exists for, and so a future
## caller asking "is this point in the room around a structure" reads the
## one table rather than restating a centre.
static func structure_lobes() -> Array[Dictionary]:
	return _structure_lobes

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
## Carte-blanche v2 -- the autumn hollow beyond the great lakes ("le Vallon
## d'automne") and the corridor that joins it to the plateau square, on the
## only strip of land between the spawn lake and the west edge. Same ground
## height as everything else: the region grows, nothing in it changes.
const AUTUMN_MIN: Vector2 = Vector2(-33.0, -78.0)
const AUTUMN_MAX: Vector2 = Vector2(33.0, -42.0)
const CORRIDOR_MIN: Vector2 = Vector2(-33.0, -42.0)
const CORRIDOR_MAX: Vector2 = Vector2(-23.0, -33.0)
## Solid discs a walker must not stand in (the Mother Tree's trunk). A hole
## is checked FIRST in contains(), and clamp_to() offers its rim as a
## candidate, so a tap inside the trunk lands on the nearest bark.
const MOTHER_TREE_AT: Vector3 = Vector3(0.0, 0.0, -62.0)
const MOTHER_TREE_TRUNK_RADIUS: float = 2.7
## Carte-blanche v3 -- the third map beyond the hollow ("la Lande aux
## Moulins"), joined to it by a corridor east of the Mother Tree's axis.
## Same ground height again. The windmill's base is a hole like the trunk.
const MOOR_MIN: Vector2 = Vector2(-38.0, -126.0)
const MOOR_MAX: Vector2 = Vector2(38.0, -86.0)
const MOOR_CORRIDOR_MIN: Vector2 = Vector2(6.0, -86.0)
const MOOR_CORRIDOR_MAX: Vector2 = Vector2(18.0, -78.0)
const WINDMILL_AT: Vector3 = Vector3(14.0, 0.0, -106.0)
const WINDMILL_RADIUS: float = 2.1
## Carte-blanche v7 -- the fourth map, south of the moor: the karting
## circuit ("le Circuit"), joined to the moor by a corridor at the end of
## the moor road, west of the windmill's axis. Same ground height (the
## kart drives on y = 0 like everyone walks on it); the relief is props.
## The rectangle is generous on purpose: the track needs room to be a
## track, and the kart needs run-off to be forgiving (KartTrack's soft
## fence sits INSIDE this rectangle, never on its edge -- see the
## structure-lobe doctrine in CLAUDE.md: a thing centred on a boundary
## sticks out of it).
const CIRCUIT_MIN: Vector2 = Vector2(-50.0, -200.0)
const CIRCUIT_MAX: Vector2 = Vector2(50.0, -134.0)
const CIRCUIT_CORRIDOR_MIN: Vector2 = Vector2(-14.0, -134.0)
const CIRCUIT_CORRIDOR_MAX: Vector2 = Vector2(-2.0, -126.0)
## CH29 (6 septembre 2026) -- the fifth map, EAST of the moor: the cove
## ("la Crique"). The first zone OFF the north-south chain: it hangs off
## the moor's east edge (x = 38) by a corridor at z -100..-92, so a walk
## from anywhere else passes the moor first (HubWorld._gates_between
## routes through zone 2 for it). Same ground height. The rectangle runs
## into the sea on purpose: the water is a PLACE here as everywhere else
## on this plateau (Mathieu's decision of 26 aout 2026), so Keepy can wade
## a dozen units out before the region stops him. The lighthouse base is a
## hole like the trunk and the windmill.
##
## THE SEA IS A DISC, and its centre is a second spelling of what
## HubCove draws -- gated by CoveProbe against the built disc, never
## trusted. Radius 48 centred at (108, -110) puts the waterline at
## x = 60.0 on the cove's mid line and at 64.4 on its north and south
## edges: a shore that curves INTO the land, which is what a cove is.
## MEASURED, not chosen: with the centre 8 u further east the sea was out
## of frame from the dock and the corridor (CoveRecon, unproject on the
## real camera: the frame is ~7 u wide at Keepy's own z and only widens
## ahead), and a beach whose water is never in the picture is a car park.
const COVE_MIN: Vector2 = Vector2(44.0, -130.0)
const COVE_MAX: Vector2 = Vector2(74.0, -90.0)
const COVE_CORRIDOR_MIN: Vector2 = Vector2(38.0, -100.0)
const COVE_CORRIDOR_MAX: Vector2 = Vector2(44.0, -92.0)
const SEA_CENTRE: Vector3 = Vector3(108.0, 0.0, -110.0)
const SEA_RADIUS: float = 48.0
const LIGHTHOUSE_AT: Vector3 = Vector3(56.0, 0.0, -124.0)
const LIGHTHOUSE_RADIUS: float = 1.9
static var _holes: Array[Dictionary] = [
	{"centre": MOTHER_TREE_AT, "radius": MOTHER_TREE_TRUNK_RADIUS},
	{"centre": WINDMILL_AT, "radius": WINDMILL_RADIUS},
	{"centre": LIGHTHOUSE_AT, "radius": LIGHTHOUSE_RADIUS},
]

static func _in_rect(flat: Vector3, lo: Vector2, hi: Vector2) -> bool:
	return flat.x >= lo.x and flat.x <= hi.x and flat.z >= lo.y and flat.z <= hi.y

static func _clamp_rect(flat: Vector3, lo: Vector2, hi: Vector2) -> Vector3:
	return Vector3(clampf(flat.x, lo.x, hi.x), 0.0, clampf(flat.z, lo.y, hi.y))

## True inside the hollow or its corridor (holes included -- this is the
## painted zone, not the walkable one).
static func in_autumn(point: Vector3) -> bool:
	var flat := _flat(point)
	return _in_rect(flat, AUTUMN_MIN, AUTUMN_MAX) or _in_rect(flat, CORRIDOR_MIN, CORRIDOR_MAX)

## True inside the moor or its corridor (painted zone, holes included).
static func in_moor(point: Vector3) -> bool:
	var flat := _flat(point)
	return _in_rect(flat, MOOR_MIN, MOOR_MAX) or _in_rect(flat, MOOR_CORRIDOR_MIN, MOOR_CORRIDOR_MAX)

## True inside the circuit or its corridor (painted zone).
static func in_circuit(point: Vector3) -> bool:
	var flat := _flat(point)
	return _in_rect(flat, CIRCUIT_MIN, CIRCUIT_MAX) or _in_rect(flat, CIRCUIT_CORRIDOR_MIN, CIRCUIT_CORRIDOR_MAX)

## CH29: true inside the cove or its corridor (painted zone, hole included).
static func in_cove(point: Vector3) -> bool:
	var flat := _flat(point)
	return _in_rect(flat, COVE_MIN, COVE_MAX) or _in_rect(flat, COVE_CORRIDOR_MIN, COVE_CORRIDOR_MAX)

## CH29: is this flat point under the sea's disc. The sea is walkable (the
## region includes it up to COVE_MAX.x); this answers "is he wet", the
## question HubWater asks, and "is this sand or water", the one the
## scatter asks. Nothing here refuses a tap.
static func in_sea(point: Vector3) -> bool:
	var flat := _flat(point)
	return flat.distance_to(SEA_CENTRE) < SEA_RADIUS

## Signed distance from the shoreline: positive on the sand (dry side),
## negative under the water. What the castles' "wet sand" test and the
## probe's shoreline gate both read, so the waterline is one number.
static func shore_distance(point: Vector3) -> float:
	return _flat(point).distance_to(SEA_CENTRE) - SEA_RADIUS

## Which zone a point paints as: 0 the plateau, 1 the autumn hollow, 2 the
## moor, 3 the circuit, 4 (CH29) the cove. The corridors belong to the
## zone they lead INTO, so a walk that crosses a corridor changes zone
## once, at the gate. The cove is asked FIRST: its corridor starts at the
## moor's own edge (x = 38), and a point on that shared line must read as
## the corridor it opens into, not as the moor it leaves.
static func zone_of(point: Vector3) -> int:
	if in_cove(point):
		return 4
	if in_circuit(point):
		return 3
	if in_moor(point):
		return 2
	if in_autumn(point):
		return 1
	return 0

static func in_hole(point: Vector3) -> bool:
	var flat := _flat(point)
	for hole in _holes:
		if flat.distance_to(hole["centre"] as Vector3) < float(hole["radius"]):
			return true
	return false

static func contains(point: Vector3) -> bool:
	var flat := _flat(point)
	if in_hole(flat):
		return false
	if _in_rect(flat, AUTUMN_MIN, AUTUMN_MAX) or _in_rect(flat, CORRIDOR_MIN, CORRIDOR_MAX):
		return true
	if _in_rect(flat, MOOR_MIN, MOOR_MAX) or _in_rect(flat, MOOR_CORRIDOR_MIN, MOOR_CORRIDOR_MAX):
		return true
	if _in_rect(flat, CIRCUIT_MIN, CIRCUIT_MAX) or _in_rect(flat, CIRCUIT_CORRIDOR_MIN, CIRCUIT_CORRIDOR_MAX):
		return true
	if _in_rect(flat, COVE_MIN, COVE_MAX) or _in_rect(flat, COVE_CORRIDOR_MIN, COVE_CORRIDOR_MAX):
		return true
	if absf(flat.x) <= PLATEAU_HALF_EXTENT and absf(flat.z) <= PLATEAU_HALF_EXTENT:
		return true
	if flat.distance_to(_north_lobe) <= NORTH_LOBE_RADIUS:
		return true
	# One more disc per structure lobe, and no new KIND of case -- the same
	# property that made the north lobe a union term rather than a zone.
	for lobe in _structure_lobes:
		if flat.distance_to(lobe["centre"] as Vector3) <= float(lobe["radius"]):
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
## Candidates rather than a closed form: the region is a union of a square
## and two discs (the shore pad and the north lobe), so its nearest point
## is on one of a
## handful of features (the square's boundary, either disc's boundary, or
## a corner where two of them meet). Generating those and taking the closest that
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
	# The lobe is one more disc, so it is one more candidate and no new kind
	# of case -- the reason contains() and this function both took the union
	# without growing a branch shaped like "the north lobe".
	var lobe := _north_lobe + (flat - _north_lobe).limit_length(NORTH_LOBE_RADIUS)
	candidates.append(square)
	candidates.append(pad)
	candidates.append(lobe)
	candidates.append(_clamp_rect(flat, AUTUMN_MIN, AUTUMN_MAX))
	candidates.append(_clamp_rect(flat, CORRIDOR_MIN, CORRIDOR_MAX))
	candidates.append(_clamp_rect(flat, MOOR_MIN, MOOR_MAX))
	candidates.append(_clamp_rect(flat, MOOR_CORRIDOR_MIN, MOOR_CORRIDOR_MAX))
	candidates.append(_clamp_rect(flat, CIRCUIT_MIN, CIRCUIT_MAX))
	candidates.append(_clamp_rect(flat, CIRCUIT_CORRIDOR_MIN, CIRCUIT_CORRIDOR_MAX))
	candidates.append(_clamp_rect(flat, COVE_MIN, COVE_MAX))
	candidates.append(_clamp_rect(flat, COVE_CORRIDOR_MIN, COVE_CORRIDOR_MAX))
	for hole in _holes:
		var hc: Vector3 = hole["centre"]
		var away := flat - hc
		if away.length() < 0.001:
			away = Vector3(1.0, 0.0, 0.0)
		candidates.append(hc + away.normalized() * (float(hole["radius"]) + 0.02))
	# Each structure lobe contributes its own nearest-point candidate, so a
	# tap just past the P2 tower resolves onto the ground BESIDE it rather
	# than being dragged back to the square edge 1.7 u away.
	for entry in _structure_lobes:
		var centre: Vector3 = entry["centre"]
		candidates.append(centre + (flat - centre).limit_length(float(entry["radius"])))

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
