extends Node
class_name SkateGroundProbe
## CH50 -- the north ground the skatepark will stand on: the region term,
## the carpet that dresses it, the wall that closes behind it, and what it
## costs to walk.
##
## =====================================================================
## HOW TO RUN IT, AND WHY IT IS NOT HEADLESS
##
##   xvfb-run --auto-servernum -- godot4 --rendering-driver opengl3 \
##     --fixed-fps 60 --path . res://scripts/dev/SkateGroundProbe.tscn
##
## ⚠️ HEADLESS IS A FAUX-VERT HERE, AND IT WAS MEASURED ON THIS FILE
## RATHER THAN INHERITED FROM CLAUDE.md. The first run of this probe was
## headless, on the reasoning that it reads no pixel and no frustum. It
## came back with the carpet phase reporting ZERO instances on the new
## ground -- and its "BLIND: nothing outside the rim" assertion GREEN,
## because zero satisfies that too. The cause is the third item on
## CLAUDE.md's dummy-driver list: reading a MultiMesh instance transform
## back out of the engine returns the IDENTITY. Measured on the shipped
## hub, same tree, same command but the driver:
##
##   --headless                    2743 instances, 2743 at (0, 0, 0)
##   xvfb + --rendering-driver     2743 instances, 2743 real, spanning
##   opengl3                       x [-62.7, 70.7]  z [-209.8, 67.6]
##
## So PHASE COVER and PHASE WALL, which are entirely built on those
## origins, need a real driver -- and PHASE COVER now carries an
## instrument check that FAILS loudly on that identity instead of reading
## a quiet zero.
##
## The cost of the real driver is llvmpipe, which is why the SubViewport
## is shrunk to WALK_VP for the whole run: nothing here samples a pixel,
## so the fragments are pure waste and PHASE CROSSING would otherwise
## take minutes per pair.
##
## ⚠️ --fixed-fps 60 BEFORE the `--`, and it is not cosmetic: PHASE
## CROSSING is the whole point of this file and a bench without that flag
## measures the machine, not the hub. This repo has paid for that at least
## four times.
##
## =====================================================================
## WHAT IT GATES
##
##   BLIND     the OLD region -- the shipped contains() with CH50's term
##             cut out, rewritten BY HAND here rather than switched off in
##             HubRegion -- REFUSES the ground every other phase leans on.
##             A coverage assertion is an assertion of PRESENCE measured
##             against a predicate, and this repo has watched three of
##             those pass green against a mechanism never wired at all. A
##             probe that can turn the shipped region off is a probe that
##             can leave it off, so the old one is retyped instead.
##   A         the disc as a SHAPE: the rim, the interior, the seam onto
##             the square, and the arithmetic that says there is no neck
##             between the CH16 lobe and this one because there are not
##             two lobes.
##   COVER     the new ground is not bald, gated on SPREAD over a grid and
##             not on a total -- a total can be met by piling everything
##             against the square's old edge, which is exactly the shape
##             the bug would have had.
##   WALL      the wall closes BEHIND the new ground, nothing of it stands
##             ON the new ground, nothing of it stands within
##             WALL_CLEARANCE of it, and no distant hill puts its skirt in
##             the skatepark. The first three are the "automatic" refusal
##             the lot claims from HubRegion.contains(); claimed is not
##             measured.
##   CROSSING  the pair this disc creates, the CH38 pair it has to lose
##             to, and the published square diagonal -- all three WALKED
##             on the real hopper in ONE run. The diagonal is the control:
##             a bench that cannot reproduce 18.700 s has no standing to
##             publish a number next to it.
##
## Exit 0 all green, 1 any red, ProbeWatchdog.EXIT_TIMEOUT = INCONCLUSIVE.

const BUDGET_S: float = 900.0

## The SubViewport this probe runs under. Small on purpose: no phase here
## samples a pixel, so every fragment llvmpipe shades is waste, and the
## walk in PHASE CROSSING is the difference between a minute and twenty.
const WALK_VP: Vector2i = Vector2i(96, 160)

## The ceiling the hub holds itself to, read off the same place
## MountainProbe reads it rather than restated a third time.
const CROSSING_CEILING_S: float = 22.0
## The square diagonal already on file, and the slack the bench is allowed
## against it. Same figures MountainProbe controls with.
const DIAGONAL_S: float = 18.700
const DIAGONAL_SLACK_S: float = 1.5

## How the NEW ground is diced for the spread gate. The new ground is the
## half-disc z >= PLATEAU_HALF_EXTENT, 56 u wide and 28 u deep, so 4 x 4
## over its bounding box gives 14 x 7 u cells. Cells whose centre is not
## in the new ground at all are not gated -- they are printed as "--".
const COVER_CELLS: int = 4
## And a floor on the total, so "one tuft per cell" cannot pass for cover.
## The plateau's own rate is ~0.45 pieces per u2 and the new half-disc is
## 1231.5 u2, so a healthy carpet is several hundred. 200 is deliberately
## far under that: this gates BALD, not density.
const COVER_FLOOR: int = 200

## The families _scatter_ground_cover sows over COVER_MIN..COVER_MAX --
## the carpet this lot widened, and the ONLY thing PHASE COVER counts.
##
## ⚠️ NAMED, not recognised. batch_nodes() publishes EVERY batch the
## scatter built, the forest wall included, and the first version of this
## phase counted those too: its "nothing outside the disc" blind check
## came back RED on 13 pieces that were wall trees doing exactly their
## job. A reader that had to tell decor from wall by shape would be wrong
## the day someone adds a family; the producer names its families and this
## list is the same names.
const COVER_FAMILIES: Array[String] = ["grass", "flower", "leaf", "pebble",
	"mushroom", "bush", "rock"]

var _fails: int = 0
var _hub: Node = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _scatter: Node3D = null
## PHASE CROSSING's landing flag. A MEMBER and not a captured local: a
## GDScript lambda captures a local BY VALUE, so a loop waiting on one
## never sees it change.
var _idle: bool = false

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract.
	ProbeWatchdog.arm(self, "SKATE GROUND PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as Node3D
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_scatter = _hub.get_node("WorldViewport/SubViewport/World/CozyScatter") as Node3D

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	_run()

## `stretch = false` FIRST: a stretching container IGNORES an explicit
## size and only warns.
func _force_viewport(size: Vector2i) -> void:
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	(_hub.get_node("WorldViewport/SubViewport") as SubViewport).size = size

func _run() -> void:
	_force_viewport(WALK_VP)
	print("=== SKATE GROUND PROBE -- CH50 ===")
	print("  centre %s  r %.1f  (CH16 lobe r %.1f on the SAME centre)"
		% [HubRegion.skate_lobe_centre(), HubRegion.SKATE_LOBE_RADIUS,
			HubRegion.NORTH_LOBE_RADIUS])
	print("  region reaches z = %.1f   cover to %.1f   wall lip %.1f"
		% [HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS,
			CozyScatter.COVER_MAX.y, CozyScatter.WALL_NEAR_Z])
	_phase_blind()
	_phase_a()
	_phase_cover()
	_phase_wall()
	await _phase_crossing()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

## =====================================================================
## THE OLD REGION, RETYPED
##
## This is HubRegion.contains() as it shipped BEFORE CH50 -- every term,
## in the same order, with the skate lobe's term and nothing else removed.
##
## ⚠️ IT IS RETYPED AND NOT SWITCHED OFF, and that is a deliberate cost.
## A flag in HubRegion that let a probe drop a term would be a flag that
## can be left dropped; the doctrine this file is gating (CLAUDE.md, "une
## structure posee sur un bord deborde", point 6) says so in as many
## words. The price is that this copy can rot -- so PHASE BLIND also
## asserts it is a strict SUBSET of the shipped predicate, sampled over
## the whole published box. A stale copy that admitted something the real
## one refuses would fail that, loudly, instead of quietly weakening every
## blind assertion built on it.
static func _old_contains(point: Vector3) -> bool:
	var flat := Vector3(point.x, 0.0, point.z)
	if HubRegion.in_hole(flat):
		return false
	if _rect(flat, HubRegion.AUTUMN_MIN, HubRegion.AUTUMN_MAX) \
			or _rect(flat, HubRegion.CORRIDOR_MIN, HubRegion.CORRIDOR_MAX):
		return true
	if _rect(flat, HubRegion.MOOR_MIN, HubRegion.MOOR_MAX) \
			or _rect(flat, HubRegion.MOOR_CORRIDOR_MIN, HubRegion.MOOR_CORRIDOR_MAX):
		return true
	if _rect(flat, HubRegion.CIRCUIT_MIN, HubRegion.CIRCUIT_MAX) \
			or _rect(flat, HubRegion.CIRCUIT_CORRIDOR_MIN, HubRegion.CIRCUIT_CORRIDOR_MAX):
		return true
	if _rect(flat, HubRegion.COVE_MIN, HubRegion.COVE_MAX) \
			or _rect(flat, HubRegion.COVE_CORRIDOR_MIN, HubRegion.COVE_CORRIDOR_MAX):
		return true
	if absf(flat.x) <= HubRegion.PLATEAU_HALF_EXTENT and absf(flat.z) <= HubRegion.PLATEAU_HALF_EXTENT:
		return true
	if _rect(flat, HubRegion.MOUNTAIN_MIN, HubRegion.MOUNTAIN_MAX):
		return true
	if flat.distance_to(HubRegion.north_lobe_centre()) <= HubRegion.NORTH_LOBE_RADIUS:
		return true
	for lobe in HubRegion.structure_lobes():
		if flat.distance_to(lobe["centre"] as Vector3) <= float(lobe["radius"]):
			return true
	return flat.distance_to(HubRegion.near_bank()) <= HubRegion.SHORE_PAD_RADIUS

static func _rect(flat: Vector3, lo: Vector2, hi: Vector2) -> bool:
	return flat.x >= lo.x and flat.x <= hi.x and flat.z >= lo.y and flat.z <= hi.y

## The NEW ground this lot creates: inside the skate lobe and north of the
## square's edge, i.e. everything contains() gained. Published as one
## function because four phases below ask the same question.
static func _new_ground(p: Vector3) -> bool:
	var flat := Vector3(p.x, 0.0, p.z)
	return flat.z > HubRegion.PLATEAU_HALF_EXTENT \
		and flat.distance_to(HubRegion.skate_lobe_centre()) <= HubRegion.SKATE_LOBE_RADIUS

## =====================================================================
## PHASE BLIND -- prove the old region SAYS NO here, before believing the
## new one when it says yes.
func _phase_blind() -> void:
	print("-- PHASE BLIND: the pre-CH50 region, retyped, refuses this ground --")
	# 1. The retyped copy is a strict SUBSET of the shipped predicate. This
	#    is what stops it rotting into a copy that quietly admits more than
	#    the real one and makes every assertion below free.
	var swept: int = 0
	var leaked: int = 0
	var gained: int = 0
	var box: Rect2 = HubRegion.walkable_bounds()
	var x: float = box.position.x
	while x <= box.end.x:
		var z: float = box.position.y
		while z <= box.end.y:
			var p := Vector3(x, 0.0, z)
			var now: bool = HubRegion.contains(p)
			var before: bool = _old_contains(p)
			swept += 1
			if before and not now:
				leaked += 1
			if now and not before:
				gained += 1
			z += 1.0
		x += 1.0
	print("     swept %d lattice points over the published box" % swept)
	_check(leaked == 0,
		"the retyped old region admits NOTHING the shipped one refuses (%d leaks)" % leaked)
	_check(gained > 0,
		"and the shipped region gained %d points it did not have (a 0 would mean this lot is a no-op)"
			% gained)

	# 2. THE ONE THAT MATTERS. Every point the coverage and crossing gates
	#    below stand on, run through the OLD predicate: it has to refuse
	#    them. If it did not, those gates would be passing on ground that
	#    already existed and this file would be measuring nothing.
	# ⚠️ "THE OLD REGION REFUSES ALL OF THEM" WAS WRONG, AND THE PROBE SAID
	# SO: 11 of the 67 stations on the half-disc are inside the CH16 r=12
	# lobe, which is ground the old region ALREADY had. The honest
	# assertion is not "it refuses everything" but "it admits EXACTLY the
	# CH16 lobe and the structure lobes, and nothing else" -- which is a
	# statement about the retyped copy that a mistyped radius would break.
	var probes: Array[Vector3] = _new_ground_stations()
	var mismatched: int = 0
	var old_admitted: int = 0
	for p in probes:
		var was_there: bool = p.distance_to(HubRegion.north_lobe_centre()) <= HubRegion.NORTH_LOBE_RADIUS
		for lobe in HubRegion.structure_lobes():
			if p.distance_to(lobe["centre"] as Vector3) <= float(lobe["radius"]):
				was_there = true
		if _old_contains(p):
			old_admitted += 1
		if _old_contains(p) != was_there:
			mismatched += 1
	_check(probes.size() > 0, "there are %d stations on the half-disc to test" % probes.size())
	_check(mismatched == 0,
		"the OLD region admits EXACTLY the %d stations the CH16 lobe covered, and no other (%d mismatches)"
			% [old_admitted, mismatched])
	_check(old_admitted < probes.size(),
		"and it refuses the other %d -- ground that did not exist before this lot"
			% (probes.size() - old_admitted))
	var admitted: int = 0
	for p in probes:
		if HubRegion.contains(p):
			admitted += 1
	_check(admitted == probes.size(),
		"the SHIPPED region admits %d of %d -- the same points, the other answer"
			% [admitted, probes.size()])

	# 3. And the crossing target itself: the far rim of the new disc was
	#    not walkable ground before this lot.
	var tip: Vector3 = _far_rim(Vector3(HubRegion.MOUNTAIN_MIN.x, 0.0, HubRegion.MOUNTAIN_MIN.y))
	_check(not _old_contains(tip),
		"the crossing target %s was OUTSIDE the old region" % _xz(tip))
	print("")

## A lattice of stations spread over the new ground, at 4 u. Built once
## and read by PHASE BLIND and PHASE COVER, so "the new ground" has one
## spelling here too.
static func _new_ground_stations() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var c: Vector3 = HubRegion.skate_lobe_centre()
	var r: float = HubRegion.SKATE_LOBE_RADIUS
	var x: float = c.x - r
	while x <= c.x + r:
		var z: float = HubRegion.PLATEAU_HALF_EXTENT
		while z <= c.z + r:
			var p := Vector3(x, 0.0, z)
			if _new_ground(p):
				out.append(p)
			z += 4.0
		x += 4.0
	return out

## =====================================================================
## PHASE A -- the disc as a shape.
func _phase_a() -> void:
	print("-- PHASE A: the disc, its seam, and why there is no neck --")
	var c: Vector3 = HubRegion.skate_lobe_centre()
	var r: float = HubRegion.SKATE_LOBE_RADIUS

	# The centre is the north lobe's, from the same variable -- not a
	# second spelling of "the middle of the north edge".
	_check(c == HubRegion.north_lobe_centre(),
		"the skate lobe's centre IS the north lobe's (%s)" % _xz(c))
	_check(is_equal_approx(c.z, HubRegion.PLATEAU_HALF_EXTENT) and is_equal_approx(c.x, 0.0),
		"and that centre is ON the north edge, not past it")

	# 36 rim points and 36 points just outside, at every azimuth.
	var rim_in: int = 0
	var out_out: int = 0
	var expected: int = 0
	for k in 36:
		var a: float = TAU * float(k) / 36.0
		var on := c + Vector3(cos(a), 0.0, sin(a)) * (r - 0.01)
		var off := c + Vector3(cos(a), 0.0, sin(a)) * (r + 0.01)
		if HubRegion.contains(on):
			rim_in += 1
		# ⚠️ ONLY THE AZIMUTHS THAT LEAVE INTO OPEN GROUND ARE GATED, and
		# the two that do not are named rather than absorbed by a rounded
		# threshold: at k = 0 and k = 18 the rim point sits exactly on
		# z = 35, so the point 0.01 u beyond it is at |x| = 28.01 and the
		# SQUARE catches it -- correctly, that is the seam. Gating "at
		# least half" would have hidden which two, and a threshold that
		# has to be re-tuned per shape is the kind this repo refuses.
		if off.z <= HubRegion.PLATEAU_HALF_EXTENT:
			continue
		expected += 1
		if not HubRegion.contains(off):
			out_out += 1
	_check(rim_in == 36, "all 36 rim points are inside (%d)" % rim_in)
	_check(expected == 17,
		"17 of the 36 azimuths leave the disc north of the seam (%d)" % expected)
	_check(out_out == expected,
		"and ALL %d of them land outside the region (%d did)" % [expected, out_out])

	# THE SEAM. Every point of the square's north edge under the disc, and
	# the strip just north of it, is walkable -- there is no notch where
	# the disc meets the edge, which is the failure a centre PAST the edge
	# would have had.
	var seam_gaps: int = 0
	var x: float = -HubRegion.PLATEAU_HALF_EXTENT
	while x <= HubRegion.PLATEAU_HALF_EXTENT:
		if not HubRegion.contains(Vector3(x, 0.0, HubRegion.PLATEAU_HALF_EXTENT)):
			seam_gaps += 1
		x += 0.25
	_check(seam_gaps == 0, "the square's whole north edge is walkable (%d gaps)" % seam_gaps)
	var seam_half: float = sqrt(maxf(r * r - pow(c.z - HubRegion.PLATEAU_HALF_EXTENT, 2.0), 0.0))
	print("     the disc meets the north edge over x in [%.1f, %.1f] -- a %.1f u seam"
		% [c.x - seam_half, c.x + seam_half, 2.0 * seam_half])
	_check(2.0 * seam_half >= 40.0,
		"the seam is %.1f u wide -- no bottleneck is even drawable here" % (2.0 * seam_half))

	# NO NECK, and it is arithmetic rather than a sweep: the CH16 lobe is
	# STRICTLY inside this one, so the two are not two discs.
	var gap: float = c.distance_to(HubRegion.north_lobe_centre()) + HubRegion.NORTH_LOBE_RADIUS
	_check(gap <= r,
		"the CH16 r=%.0f lobe is strictly contained (%.1f <= %.1f) -- one lobe, not two"
			% [HubRegion.NORTH_LOBE_RADIUS, gap, r])

	# The zipline's P2 structure lobe is swallowed too -- worth stating,
	# because it means CH21's tower keeps its ground for free.
	for lobe in HubRegion.structure_lobes():
		var lc: Vector3 = lobe["centre"]
		var d: float = c.distance_to(lc) + float(lobe["radius"])
		print("     structure lobe %s reaches %.3f from the skate centre (r %.1f) -- %s"
			% [_xz(lc), d, r, "contained" if d <= r else "still its own ground"])

	# What the lot actually adds, in square units.
	var half_disc: float = PI * r * r * 0.5
	var old_half: float = PI * HubRegion.NORTH_LOBE_RADIUS * HubRegion.NORTH_LOBE_RADIUS * 0.5
	print("     new walkable ground  %.1f u2 - %.1f u2 already there  =  %.1f u2 (+%.2f%% of the 4900 square)"
		% [half_disc, old_half, half_disc - old_half, 100.0 * (half_disc - old_half) / 4900.0])

	# The published box moved, and only on the axis it should have.
	var box: Rect2 = HubRegion.walkable_bounds()
	_check(is_equal_approx(box.end.y, c.z + r),
		"walkable_bounds' north edge is the disc's rim, %.1f (%.1f)" % [c.z + r, box.end.y])
	_check(is_equal_approx(box.size.x, 137.0),
		"and its x span is untouched at %.1f" % box.size.x)
	print("")

## =====================================================================
## PHASE COVER -- the new ground is dressed.
func _phase_cover() -> void:
	print("-- PHASE COVER: the carpet reaches the new ground, and evenly --")
	# The bound is the region's, not a fourth spelling of "35 + 28".
	_check(is_equal_approx(CozyScatter.COVER_MAX.y,
			HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS),
		"COVER_MAX.y %.1f is the region's own north reach %.1f"
			% [CozyScatter.COVER_MAX.y,
				HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS])

	var all: Array = _cover_instances()
	_check(all.size() > 0, "there is ground cover to count at all (%d pieces)" % all.size())

	# ⚠️ THE INSTRUMENT, BEFORE ANYTHING IT MEASURES. Under the dummy
	# driver every one of these origins reads back as the IDENTITY, and
	# the whole phase then counts zero everywhere and calls its absence
	# assertions green. Measured on this hub: 2743 of 2743 at (0, 0, 0)
	# headless, 2743 of 2743 real under opengl3. So the readback proves
	# itself alive before a single count below is believed.
	var real_origins: int = 0
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for e in all:
		var o: Vector3 = e["origin"]
		if o.length() > 0.001:
			real_origins += 1
		lo = Vector3(minf(lo.x, o.x), minf(lo.y, o.y), minf(lo.z, o.z))
		hi = Vector3(maxf(hi.x, o.x), maxf(hi.y, o.y), maxf(hi.z, o.z))
	print("     readback spans x [%.1f, %.1f]  z [%.1f, %.1f]" % [lo.x, hi.x, lo.z, hi.z])
	_check(real_origins == all.size(),
		"INSTRUMENT: %d of %d instance transforms read back non-identity -- run under xvfb + opengl3, never --headless"
			% [real_origins, all.size()])

	# BLIND FIRST, and it is a real absence: nothing is sown past the
	# region's rim, so the counter must read ZERO in the 4 u annulus just
	# outside the disc. An instrument that cannot report zero cannot
	# report N.
	var c: Vector3 = HubRegion.skate_lobe_centre()
	var r: float = HubRegion.SKATE_LOBE_RADIUS
	var outside: int = 0
	var inside_rim: int = 0
	var truly_new: int = 0
	var on_new: int = 0
	var grid: Array[int] = []
	grid.resize(COVER_CELLS * COVER_CELLS)
	grid.fill(0)
	var w: float = 2.0 * r / float(COVER_CELLS)
	var h: float = r / float(COVER_CELLS)
	for e in all:
		var p: Vector3 = e["origin"]
		var flat := Vector3(p.x, 0.0, p.z)
		if not HubRegion.contains(flat):
			outside += 1
		if not _new_ground(flat):
			continue
		on_new += 1
		inside_rim += 1
		if not _old_contains(flat):
			truly_new += 1
		var cx: int = clampi(int((flat.x - (c.x - r)) / w), 0, COVER_CELLS - 1)
		var cz: int = clampi(int((flat.z - HubRegion.PLATEAU_HALF_EXTENT) / h), 0, COVER_CELLS - 1)
		grid[cz * COVER_CELLS + cx] += 1
	# THE BLIND, and it is a PAIR: the same counter has to read a real
	# number somewhere and exactly zero somewhere else. `_sprinkle` drops
	# every candidate contains() refuses, so no piece of carpet may sit
	# outside the region ANYWHERE on the map -- and if the counter were
	# blind (a stale family list, an identity readback) it would read zero
	# for both, which the second half catches.
	_check(inside_rim > 0,
		"BLIND: the counter reads %d pieces INSIDE the disc -- it can see" % inside_rim)
	_check(outside == 0,
		"BLIND: and %d pieces of carpet outside the region, anywhere on the map" % outside)

	# The spread. A cell whose centre is not on the new ground is not
	# gated -- the half-disc does not fill its bounding box.
	var empty: int = 0
	var gated: int = 0
	var line: String = ""
	for cz in COVER_CELLS:
		for cx in COVER_CELLS:
			var centre := Vector3(c.x - r + (float(cx) + 0.5) * w, 0.0,
				HubRegion.PLATEAU_HALF_EXTENT + (float(cz) + 0.5) * h)
			var n: int = grid[cz * COVER_CELLS + cx]
			if not _new_ground(centre):
				line += "    --"
				continue
			gated += 1
			line += "%6d" % n
			if n == 0:
				empty += 1
		line += " |"
	print("     %d x %d cell counts over the new half-disc: %s" % [COVER_CELLS, COVER_CELLS, line])
	print("     %d instances on the new ground (%.4f per u2 over %.1f u2)"
		% [on_new, float(on_new) / (PI * r * r * 0.5), PI * r * r * 0.5])
	_check(gated > 0, "%d cells of the grid are actually on the new ground" % gated)
	_check(on_new >= COVER_FLOOR,
		"the half-disc carries %d pieces (floor %d)" % [on_new, COVER_FLOOR])
	# ⚠️ THE NUMBER THAT IS ACTUALLY THIS LOT'S. `on_new` counts the whole
	# half-disc, and its first 12 u were already the CH16 lobe -- ground
	# the carpet has dressed since CH16. This is the count standing where
	# the OLD region said no, which was necessarily 0 before today.
	_check(truly_new > 0,
		"%d of them stand on ground the OLD region refused (0 before this lot)" % truly_new)
	# And the OLD cover bound: COVER_MAX.y was 47, so `_sprinkle` never
	# threw a candidate north of it. Every piece past 47 is one that could
	# not have existed with the old rectangle -- the red-before-green for
	# the bound itself, measured rather than argued.
	var past_old_bound: int = 0
	for e in all:
		if float(e["origin"].z) > 47.0:
			past_old_bound += 1
	_check(past_old_bound > 0,
		"%d pieces stand north of z = 47, the OLD COVER_MAX.y -- impossible before this lot"
			% past_old_bound)
	_check(empty == 0, "%d of the %d gated cells are EMPTY" % [empty, gated])

	# The RNG stream moved, and that is expected rather than a regression
	# -- printed so a capture diff has a published cause to point at.
	var stats: Dictionary = _scatter.call("stats")
	var totals: String = ""
	for f in COVER_FAMILIES:
		totals += "%s %d  " % [f, int(stats.get(f, -1))]
	print("     scatter totals after the widened rectangle: %s" % totals)
	print("     (every family's count grew with the area, and every draw AFTER")
	print("      the first one moved -- the carpet is redistributed by design)")
	print("")

## =====================================================================
## PHASE WALL -- the wall closes behind, and stands off.
func _phase_wall() -> void:
	print("-- PHASE WALL: the wall follows the ground, and stays off it --")
	_check(is_equal_approx(CozyScatter.WALL_NEAR_Z,
			HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS + 5.0),
		"WALL_NEAR_Z %.1f is the region's reach plus a 5 u lip" % CozyScatter.WALL_NEAR_Z)

	var trees: Array = _wall_instances()
	var hedges: Array = _hedge_instances()
	_check(trees.size() > 0, "there are %d annulus wall trees to check" % trees.size())
	_check(hedges.size() > 0,
		"and %d hedge trees, which are a DIFFERENT pass with a different rule" % hedges.size())
	# The split has to account for every tree of the family, or a cell
	# token this probe does not know would silently drop trees out of the
	# gate below -- the quietest way to pass.
	var family_total: int = _batch_origins(func(_c: String) -> bool: return true).size()
	_check(trees.size() + hedges.size() == family_total,
		"the two passes account for all %d wall-family trees (%d + %d)"
			% [family_total, trees.size(), hedges.size()])

	# 1. It exists north of the NEW ground. Before this lot the box stopped
	#    at 50 and the region at 47; north of 63 there was nothing at all.
	var behind: int = 0
	for p in trees:
		if p.z > HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS:
			behind += 1
	_check(behind > 0,
		"%d wall trees stand north of the new rim -- the horizon is closed behind it" % behind)

	# 2. NOTHING of it stands on walkable ground, and nothing within
	#    WALL_CLEARANCE. This is the "automatic" refusal the lot claims
	#    from HubRegion.contains(); claimed is not measured.
	var inside: int = 0
	var near_new: int = 0
	var map_wide: int = 0
	var sampled_pass: int = 0
	var worst: float = INF
	for p in trees:
		if HubRegion.contains(p):
			inside += 1
		var d: float = _distance_to_region(p)
		if p.z > HubRegion.PLATEAU_HALF_EXTENT:
			worst = minf(worst, d)
		if d >= CozyScatter.WALL_CLEARANCE:
			continue
		map_wide += 1
		# The shipped filter's OWN answer on this tree, recomputed here.
		if not _sampled_near(p, CozyScatter.WALL_CLEARANCE):
			sampled_pass += 1
		if p.z > HubRegion.PLATEAU_HALF_EXTENT:
			near_new += 1
	_check(inside == 0, "%d wall trees stand INSIDE the region" % inside)
	print("     nearest wall tree to the region, north of the square: %.3f u" % worst)

	# ⚠️ THE GATE IS SCOPED TO WHAT THIS LOT MOVED, and the rest is
	# EXPLAINED rather than silenced. Measured map-wide, some wall trees
	# do stand under WALL_CLEARANCE by an exact distance -- and every one
	# of them PASSES the filter the wall actually ships, because
	# `_near_region` is an EIGHT-POINT sample on a circle of that radius,
	# not a distance. A tree 1.9 u off a corner can have all eight probes
	# miss the region. That is a property of the shipped filter, on every
	# edge of every zone, and predates this lot; what this lot owes is
	# that its own new edge is clear.
	_check(map_wide == sampled_pass,
		"every one of the %d annulus trees under WALL_CLEARANCE also passes the shipped 8-point filter (%d) -- the filter SAMPLES, it does not measure"
			% [map_wide, sampled_pass])
	# The hedges, with THEIR rule: off walkable ground, and nothing else.
	var hedge_inside: int = 0
	for p in hedges:
		if HubRegion.contains(p):
			hedge_inside += 1
	_check(hedge_inside == 0,
		"%d hedge trees stand INSIDE the region (a hedge lines an edge; it never stands on it)"
			% hedge_inside)
	_check(near_new == 0,
		"%d wall trees stand closer than %.1f u to the ground north of the square"
			% [near_new, CozyScatter.WALL_CLEARANCE])

	# 3. The distant hills: none may put its skirt on the new ground. The
	#    hills are ellipses, so this is measured on the ellipse and not on
	#    the origin -- an origin 60 u away can still reach in 40.
	var hills := _hub.get_node_or_null("WorldViewport/SubViewport/World/CozyScatter/Hills") as MultiMeshInstance3D
	_check(hills != null and hills.multimesh != null, "the Hills batch exists")
	var intruding: int = 0
	if hills != null and hills.multimesh != null:
		for i in hills.multimesh.instance_count:
			var xf: Transform3D = hills.multimesh.get_instance_transform(i)
			if _ellipse_hits_new_ground(xf):
				intruding += 1
		print("     %d hills, %d of them reaching onto the new ground"
			% [hills.multimesh.instance_count, intruding])
	_check(intruding == 0, "%d distant hills put a skirt on the skatepark ground" % intruding)
	print("")

## Does this hill's footprint ellipse touch the new half-disc. Sampled on
## the ellipse's own perimeter and interior rather than on its AABB: a
## rotated box's AABB is bigger than the body inside it, and this repo has
## paid for reading a silhouette off a transformed AABB before.
static func _ellipse_hits_new_ground(xf: Transform3D) -> bool:
	for k in 48:
		var a: float = TAU * float(k) / 48.0
		for t in [1.0, 0.6, 0.25, 0.0]:
			var local := Vector3(cos(a) * t, 0.0, sin(a) * t)
			var world: Vector3 = xf * local
			if _new_ground(Vector3(world.x, 0.0, world.z)):
				return true
	return false

## CozyScatter._near_region, recomputed here so the probe can say what the
## SHIPPED filter answered rather than what it thinks it should have. Same
## eight azimuths, same radius, same predicate.
static func _sampled_near(p: Vector3, radius: float) -> bool:
	if HubRegion.contains(p):
		return true
	for k in 8:
		var a: float = TAU * float(k) / 8.0
		if HubRegion.contains(p + Vector3(cos(a) * radius, 0.0, sin(a) * radius)):
			return true
	return false

## Distance from a point to the region, by bisection on the segment to its
## clamped image. Cheap and exact enough for a 0.5 u gate.
static func _distance_to_region(p: Vector3) -> float:
	var flat := Vector3(p.x, 0.0, p.z)
	if HubRegion.contains(flat):
		return 0.0
	return flat.distance_to(HubRegion.clamp_to(flat))

## =====================================================================
## PHASE CROSSING -- the three pairs, walked.
func _phase_crossing() -> void:
	print("-- PHASE CROSSING: the new pair, the CH38 witness, the diagonal --")
	# The pair THIS disc creates: the far rim of the disc seen from the
	# mountain's south-west corner, which the sweep in HubRegion's header
	# named as the worst of the eight corners.
	var mtn_sw := Vector3(HubRegion.MOUNTAIN_MIN.x, 0.0, HubRegion.MOUNTAIN_MIN.y)
	var tip: Vector3 = _far_rim(mtn_sw)
	_check(HubRegion.contains(mtn_sw) and HubRegion.contains(tip),
		"both ends of the new pair are walkable (%s -> %s)" % [_xz(mtn_sw), _xz(tip)])
	print("     the new pair spans %.3f u" % Vector2(mtn_sw.x - tip.x, mtn_sw.z - tip.z).length())

	var new_s: float = await _walk(mtn_sw, tip)
	if new_s < 0.0:
		_check(false, "the new pair did not land (INCONCLUSIVE for this phase)")
	else:
		_check(new_s <= CROSSING_CEILING_S,
			"%s -> %s walked in %.3f s, ceiling %.1f"
				% [_xz(mtn_sw), _xz(tip), new_s, CROSSING_CEILING_S])

	# THE WITNESS. CH38's pair is the hub's worst walk and this lot claims
	# not to have taken that title -- so it is walked in the SAME run, on
	# the same bench, under the same load, or the comparison is a comparison
	# of two machines.
	var ch38_from := Vector3(35.0, 0.0, -35.0)
	var ch38_to := Vector3(HubRegion.MOUNTAIN_MIN.x, 0.0, HubRegion.MOUNTAIN_MAX.y)
	var ch38_s: float = await _walk(ch38_from, ch38_to)
	if ch38_s < 0.0:
		_check(false, "the CH38 pair did not land (INCONCLUSIVE for this phase)")
	else:
		_check(ch38_s <= CROSSING_CEILING_S,
			"CH38 witness %s -> %s walked in %.3f s, ceiling %.1f"
				% [_xz(ch38_from), _xz(ch38_to), ch38_s, CROSSING_CEILING_S])

	# THE CONTROL. A bench that cannot reproduce a number already on file
	# has no standing to publish a new one.
	var diag: float = await _walk(Vector3(-35.0, 0.0, -35.0), Vector3(35.0, 0.0, 35.0))
	print("     control: the shipped diagonal walks in %.3f s (%.3f s on file)"
		% [diag, DIAGONAL_S])
	_check(diag > 0.0 and absf(diag - DIAGONAL_S) < DIAGONAL_SLACK_S,
		"the bench reproduces the published diagonal within %.1f s" % DIAGONAL_SLACK_S)

	# And the claim itself: the new pair is SECOND, not first.
	if new_s > 0.0 and ch38_s > 0.0:
		_check(new_s <= ch38_s,
			"the new pair (%.3f s) does NOT beat CH38's (%.3f s) -- the hub's worst walk is unchanged"
				% [new_s, ch38_s])
	print("")

## The point of the skate lobe's rim furthest from `from`, pulled 0.01 u
## inside so a float comparison on the rim cannot decide the phase.
static func _far_rim(from: Vector3) -> Vector3:
	var c: Vector3 = HubRegion.skate_lobe_centre()
	var away: Vector3 = Vector3(c.x - from.x, 0.0, c.z - from.z).normalized()
	return c + away * (HubRegion.SKATE_LOBE_RADIUS - 0.01)

## Walks Keepy from a to b and returns the seconds it took, or -1 if he
## never landed.
func _walk(from: Vector3, to: Vector3) -> float:
	_keepy.global_position = HubSurface.ground(from)
	if _camera.has_method("snap_to_target"):
		_camera.call("snap_to_target")
	await get_tree().physics_frame
	_idle = false
	if not _keepy.became_idle.is_connected(_on_idle):
		_keepy.became_idle.connect(_on_idle)
	_keepy.call("hop_to", HubSurface.ground(to))
	var frames: int = 0
	while not _idle and frames < 4000:
		await get_tree().physics_frame
		frames += 1
	if not _idle:
		return -1.0
	var landed: float = Vector3(_keepy.global_position.x, 0.0, _keepy.global_position.z) \
		.distance_to(Vector3(to.x, 0.0, to.z))
	var seconds: float = float(frames) / 60.0
	print("     walked %.2f u in %d frames (%.3f s), stopped %.3f u from the target"
		% [Vector2(from.x - to.x, from.z - to.z).length(), frames, seconds, landed])
	return seconds

func _on_idle() -> void:
	_idle = true

## Every ground-decor instance the scatter built, read off the batch names
## the scatter PUBLISHES rather than off a list of what is not decor -- a
## list of exclusions is wrong the day someone adds the twelfth node.
func _decor_instances() -> Array:
	var out: Array = []
	for name_of in (_scatter.call("batch_nodes") as Array):
		var mmi := _scatter.get_node_or_null(NodePath(String(name_of))) as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		for i in mmi.multimesh.instance_count:
			out.append({"node": String(mmi.name), "index": i,
				"origin": mmi.multimesh.get_instance_transform(i).origin})
	return out

## Every GROUND-COVER instance, by family name rather than by shape. The
## batch node's name is "<family>_<mesh>_<cell>" (CozyScatter._add builds
## the key and _flush names the node after it), so the family is a prefix
## and never a guess.
func _cover_instances() -> Array:
	var out: Array = []
	for e in _decor_instances():
		var node := String(e["node"])
		for f in COVER_FAMILIES:
			if node.begins_with(f + "_"):
				out.append(e)
				break
	return out

## ⚠️ THE ANNULUS WALL AND THE HEDGES ARE TWO DIFFERENT PASSES WITH TWO
## DIFFERENT RULES, AND THE PROBE FOUND THAT THE HARD WAY.
##
## A first version of this phase swept every `wall_near*` batch and gated
## them all on WALL_CLEARANCE. It came back RED on 42 trees -- and the
## explanation written for it ("the shipped filter samples eight points,
## so a tree can slip under the radius") was WRONG: recomputing that
## filter tree by tree showed 41 of the 42 would have been REJECTED by it.
## Something else had let them through, and it was not a defect.
##
## The four HEDGE passes (`hedge`, `hedge2`, `hedge3`, `hedge4`) do not
## call `_near_region` at all -- they refuse `contains()` and a footprint
## and nothing more, on purpose: a hedge LINES a corridor edge, standing
## off it by two metres is the one thing it must not do. They share the
## `wall_near` FAMILY with the annulus wall, so a sweep by family collects
## both; the batch key's CELL is what tells them apart ("wall_<sector>" for
## the annulus, "hedge*" for a hedge), and the node name ends with it.
##
## This is the doctrine about lists of exclusions, met from the other
## side: the producer names its passes and the reader reads those names.
func _wall_instances() -> Array[Vector3]:
	return _batch_origins(func(cell: String) -> bool: return cell.begins_with("wall_"))

func _hedge_instances() -> Array[Vector3]:
	return _batch_origins(func(cell: String) -> bool: return cell.begins_with("hedge"))

## Origins of every `wall_near`/`wall_far` batch whose CELL token the
## predicate accepts. The node name is "<family>_<mesh>_<cell>", so the
## cell is what follows the family and the mesh -- and because a mesh name
## itself carries underscores, the cell is matched as the node name's
## SUFFIX rather than by splitting on "_".
func _batch_origins(wants: Callable) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for name_of in (_scatter.call("batch_nodes") as Array):
		var text := String(name_of)
		if not (text.begins_with("wall_near_") or text.begins_with("wall_far_")):
			continue
		var cell: String = _cell_token(text)
		if not bool(wants.call(cell)):
			continue
		var mmi := _scatter.get_node_or_null(NodePath(text)) as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		for i in mmi.multimesh.instance_count:
			var o: Vector3 = mmi.multimesh.get_instance_transform(i).origin
			out.append(Vector3(o.x, 0.0, o.z))
	return out

## The cell token of a batch node name. The cells the wall uses are
## "wall_<n>" and "hedge"/"hedge2"/"hedge3"/"hedge4" -- all of them known
## suffixes, so the token is read off the end and never guessed.
static func _cell_token(node_name: String) -> String:
	for hedge in ["hedge4", "hedge3", "hedge2", "hedge"]:
		if node_name.ends_with("_" + hedge):
			return hedge
	var cut: int = node_name.rfind("_wall_")
	return node_name.substr(cut + 1) if cut >= 0 else ""

static func _xz(p: Vector3) -> String:
	return "(%.2f, %.2f)" % [p.x, p.z]
