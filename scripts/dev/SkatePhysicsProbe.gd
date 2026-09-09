extends Node
## CH57 LOT 1 -- THE GATE OF THE FIRST REAL COLLIDER THIS HUB HAS.
##
## =====================================================================
## WHAT THIS PROBE HAS TO PROVE, AND WHY EACH THING IS HARD
##
## The lot's stated goal is not a number, it is a sentence: "la planche
## s'appuie sur la geometrie du module au lieu de la traverser ou de
## s'arreter a cote". Three outcomes, and a bench that cannot tell them
## apart proves nothing:
##
##   * it TRAVERSES   -> the collider is absent, wrong, or on a layer
##                       nothing reads. Rides through at y = 0.
##   * it STOPS BESIDE -> the ramp reads as a wall, or the body never
##                       climbs. Never reaches the far side.
##   * it CLIMBS       -> what the lot is for.
##
## So the ride is measured on TWO axes at once -- how high it went AND
## how far it got -- because either one alone confuses two of the three.
## A height gate alone passes for a board that climbed and stalled on
## top; a distance gate alone passes for a board that went straight
## through. CLAUDE.md, CH42: a run is never scored on where it ended.
##
## =====================================================================
## THE CONTROL IS A NEUTRALISATION, AND IT RUNS IN BOTH DIRECTIONS
##
## CLAUDE.md's rouge-avant-vert, done at RUNTIME rather than by editing a
## file: PHASE N takes the collider off the layer the board reads, rolls
## the SAME ride again, and demands that the board now goes THROUGH the
## funbox. Then it puts the layer back and demands the climb returns.
##
## Green / red / green, on one tree, with nothing restored by hand and
## nothing to `cmp` afterwards. A single green would be the CH40 defect
## exactly: "l'objet coute quelque chose" came back green against a bench
## whose hide-list was empty.
##
## =====================================================================
## AND IT RUNS HEADLESS
##
## CH56 section 8 added the third case to CLAUDE.md's driver rule and
## this probe is squarely in it plus the older one: everything below is
## TRANSFORMS, INTEGERS and the PHYSICS SERVER, and not one line reads a
## pixel. Under llvmpipe the hub renders at 120 ms/frame (CH56 PHASE Z
## measured it), so a 900-tick ride would cost two minutes of rasteriser
## for nothing at all.
##
## PHASE B is the single exception and it says so: the engine's own
## primitive and draw-call counters need a real driver, so it gates on
## the SCENE census (transforms, driver-independent) and merely PRINTS
## the engine counters, loudly labelled, when a driver happens to be
## there. Run it under xvfb once if you want those two numbers signed.

## CH60 raised it from 900: the lot went from ONE solid module to FOUR,
## and every one of them is ridden, neutralised and ridden again.
const BUDGET_S: float = 2400.0
const FPS: float = 60.0
## Long enough for the 12 u ride at the board's own pace with the run-up
## and the run-out, and short enough that four of them fit the budget.
const RIDE_TICKS: int = 420
const SETTLE: int = 6

## CLAUDE.md's published control. A bench that cannot restate it has no
## standing to publish a number of its own.
const PUBLISHED_DIAGONAL_HOPS: int = 66
const PUBLISHED_DIAGONAL_S: float = 18.700

## Where the board is stationed for the ride, and where it is aimed. Due
## south along x = 0, which is the funbox's own centre line, so the roll
## crosses the module square on rather than clipping a corner.
const RIDE_FROM: Vector3 = Vector3(0.0, 0.0, 52.0)
const RIDE_TO: Vector3 = Vector3(0.0, 0.0, 40.0)
## The lateral leg: due west along the funbox's own z, which meets the
## deck box's vertical east face and no ramp at all.
## CH61: where the board is carried before its rider is put down. Open
## lawn well east of the park and clear of every other prop's hotspot --
## SkateDismountProbe's OPEN_GROUND, and it is the same station for the
## same reason.
const NEUTRAL_PARK: Vector3 = Vector3(12.0, 0.0, 52.0)
const SIDE_FROM: Vector3 = Vector3(6.0, 0.0, 45.5)
const SIDE_TO: Vector3 = Vector3(-6.0, 0.0, 45.5)

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _park: HubSkatepark = null
var _transport: HubTransport = null
var _hops: int = 0
var _idle: bool = false

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE PHYSICS PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_physics_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _run() -> void:
	print("=== SKATE PHYSICS PROBE -- CH57 LOT 1 ===")
	print("driver: %s" % DisplayServer.get_name())
	# THE SWITCH FIRST, AND BEFORE ANY WORLD EXISTS. DevTools caches its
	# answer on the first call precisely so that a world cannot be built
	# half-believing in colliders, which means every test of the switch
	# has to happen before the hub is instantiated -- afterwards the cache
	# is what would be under test, not the rule.
	_phase_switch()
	if _fails > 0:
		print("=== SWITCH FAILED -- the mode under test is not the mode built. Stopping. ===")
		get_tree().quit(1)
		return
	_phase_constants()
	await _phase_pieces()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every number below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	# ⚠️ THE BUDGET IS READ FIRST, AND IT BUILDS BOTH WORLDS ITSELF.
	# It has to come before a single ride: CH37 measured that this hub is
	# NOT still -- the bear has walked towards the fire since CH25, and two
	# readings of the same tree drift further apart than two trees do. A
	# hub that has been ridden three times and walked across the plateau is
	# not the same PICTURE as a fresh one, at any station.
	await _phase_budget()
	if _hub == null:
		print("=== BUDGET FAILED to build a world. Stopping. ===")
		get_tree().quit(1)
		return
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	_park = _hub.find_child("Skatepark", true, false) as HubSkatepark
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	if _keepy == null or _park == null or _transport == null:
		push_error("SkatePhysicsProbe: hub is missing Keepy / Skatepark / Transport.")
		get_tree().quit(1)
		return
	await _phase_world()
	if _fails > 0:
		print("=== WORLD FAILED -- nothing physical was built. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_volume()
	await _phase_ride()
	await _phase_neutralised()
	await _phase_lateral()
	await _phase_rail()
	await _phase_traversal()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE S -- THE SWITCH
#
# Blind check on the gate itself, POSITIVE FIRST. "Physics is off for a
# player" is an assertion of ABSENCE and CLAUDE.md is explicit that those
# pass for free: shown that the switch can say YES, "it says no by
# default" becomes a result instead of a tautology.

func _phase_switch() -> void:
	print("-- PHASE S: the switch answers, in both directions --")
	DevTools.set_physics_override(true)
	_check(DevTools.physics_enabled(), "forced ON  -> physics_enabled() true")
	DevTools.set_physics_override(false)
	_check(not DevTools.physics_enabled(), "forced OFF -> physics_enabled() false")
	DevTools.set_physics_override(null)
	# Off-web with no `-- --physics` on the command line. This is THE
	# assertion that keeps the other 90 probes measuring CH54's game:
	# DevTools.enabled() is true in here, and a physics gate written on it
	# alone would have silently turned colliders on inside SkateDriveProbe,
	# SkateparkProbe and SkateTraverseProbe.
	var asked: bool = OS.get_cmdline_user_args().has(DevTools.PHYSICS_ARG)
	_check(DevTools.enabled(), "DevTools.enabled() is TRUE here (so the test below is not vacuous)")
	_check(DevTools.physics_enabled() == asked,
		"default off-web follows the command line only (asked=%s, got=%s)"
			% [asked, DevTools.physics_enabled()])
	DevTools.set_physics_override(null)

# =====================================================================
# PHASE C -- THE CONSTANTS, AND THE TWO SPELLINGS THAT ARE GATED RATHER
# THAN TRUSTED

func _phase_constants() -> void:
	print("-- PHASE C: constants and layers --")
	# GRAVITY is deliberately re-declared rather than read across from
	# Chased (see SkateBoardBody). Gated here so the divergence, when it
	# comes, is a DECISION and not a silent drift. Both are printed.
	print("     SkateBoardBody.GRAVITY %.4f   Keepy.GRAVITY %.4f" % [SkateBoardBody.GRAVITY, Keepy.GRAVITY])
	_check(is_equal_approx(SkateBoardBody.GRAVITY, Keepy.GRAVITY),
		"the hub's gravity is Chased's gravity (if this reddens, DECIDE -- do not sync)")
	_check(is_equal_approx(SkateBoardBody.ARRIVE_EPSILON, KeepyHopper.ARRIVE_EPSILON),
		"arrival epsilon is READ off KeepyHopper (%.4f)" % SkateBoardBody.ARRIVE_EPSILON)
	_check(is_equal_approx(SkateBoardBody.PACE_FLOOR, KeepyHopper.GLIDE_PACE_FLOOR),
		"rest pace is READ off KeepyHopper (%.4f)" % SkateBoardBody.PACE_FLOOR)
	# The layers Chased reserved, read off ITS OWN SCENE FILES rather than
	# off a number somebody remembered. CH55 section 4.1 named 1 and 2;
	# this is that claim re-derived from the disk at every run.
	var chased: int = _layers_in("res://scenes/Keepy.tscn") | _layers_in("res://scenes/TrackSegment.tscn")
	var ours: int = (1 << (SkateBoardBody.LAYER_PARK - 1)) | (1 << (SkateBoardBody.LAYER_BOARD - 1))
	print("     Chased occupies layer mask %d ; the hub asks for %d" % [chased, ours])
	_check(chased != 0, "the Chased scenes really do declare layers (else the test below is free)")
	_check((chased & ours) == 0, "the hub's two layers do not touch Chased's -- D3 stays undecided and moot")

## Every `collision_layer` / `collision_mask` integer a scene file
## declares, OR-ed. Text, not instantiation: loading Chased's player here
## would drag a second screen's _ready() into a hub probe.
func _layers_in(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var out: int = 0
	for line in f.get_as_text().split("\n"):
		var s: String = line.strip_edges()
		if s.begins_with("collision_layer") or s.begins_with("collision_mask"):
			out |= int(s.split("=")[-1].strip_edges())
	return out

# =====================================================================
# PHASE G -- THE PIECES AGAINST THE DRAWN MESH
#
# ⚠️ THE GATE IS AN EQUALITY OF POINT SETS, NOT AN INCLUSION, and that is
# what makes it a gate. An inclusion ("every piece corner is a vertex")
# would be satisfied by a single piece, or by none. An equality says the
# collider covers the drawn shape and nothing else.
#
# And it carries its own blind check: the same comparison run against
# pieces built from DIFFERENT arguments must come back DIFFERENT, or
# "the two sets are equal" is passing against a comparison that cannot
# see anything.
#
# ⚠️ CH60: IT RUNS OVER EVERY MODULE, INCLUDING THE ONE WITH NO PIECES.
# CH57 hard-coded MODULES[0]. A per-module loop is what makes "the bowl
# is out of this lot" a MEASURED perimeter -- `pieces_for()` returns
# empty for it and the phase says so -- instead of a sentence in a
# comment that the next lot has to be trusted to have read.
#
# ⚠️ AND AN EQUALITY OF POINT SETS IS NECESSARY, NOT SUFFICIENT. Twelve
# wedges that all happened to be the SAME wedge would carry the same 28
# points. What closes that is PHASE V, which samples the two solids
# against each other; this phase is the cheap gate that has to pass
# before the expensive one is worth running.

## How many pieces each kind must decompose into. Written here rather
## than read off the builder, ON PURPOSE: a count read from the thing
## under test cannot disagree with it. Twelve is the MINIMUM for a
## quarterpipe and the argument is in SkateparkMesh -- if a later lot
## finds a cheaper exact decomposition, this line is where the claim gets
## re-argued rather than silently followed.
const EXPECT_PIECES: Dictionary = {
	&"funbox": 3, &"rail": 3, &"quarterpipe": 12, &"bowl": 0,
}

func _phase_pieces() -> void:
	print("-- PHASE G: the collision pieces are a second READING of each drawn module --")
	var solid: int = 0
	for index in HubSkatepark.MODULES.size():
		var spec: Dictionary = HubSkatepark.MODULES[index]
		var kind: StringName = StringName(spec["kind"])
		var args: Array = HubSkatepark.build_args(spec)
		var builder := SkateparkMesh.new()
		var mesh: ArrayMesh = _mesh_of(builder, kind, args)
		var pieces: Array = HubSkatepark.pieces_for(spec)
		var drawn := _distinct(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		var counts: Array = []
		var union := PackedVector3Array()
		for piece in pieces:
			counts.append(piece.size())
			for point in piece:
				union.append(point)
		print("     [%d] %-12s args %s  %3d tri  pieces %s  union %d  drawn %d"
			% [index, String(kind), str(args), builder.triangle_count(),
				str(counts), _distinct(union).size(), drawn.size()])
		_check(pieces.size() == int(EXPECT_PIECES.get(kind, -1)),
			"G[%d] %s decomposes into %d pieces (got %d)"
				% [index, String(kind), int(EXPECT_PIECES.get(kind, -1)), pieces.size()])
		if pieces.is_empty():
			# The bowl. Its exclusion is the lot's perimeter, and it is
			# asserted rather than described -- see the header.
			_check(kind == HubSkatepark.KIND_BOWL,
				"G[%d] the only module with no pieces is the bowl (CH60 excludes it, lot 3b)" % index)
			continue
		solid += 1
		_check(_same_set(_distinct(union), drawn),
			"G[%d] %s: the union of the pieces IS the set of distinct drawn vertex positions"
				% [index, String(kind)])
	_check(solid == 4, "G: four modules of five carry pieces (got %d)" % solid)
	# CH56 restated 468 park triangles and 20 for the funbox. A bench that
	# cannot restate a number on file has no standing to publish one.
	var fb := SkateparkMesh.new()
	var fb_args: Array = HubSkatepark.build_args(HubSkatepark.MODULES[0])
	fb.funbox(fb_args[0], fb_args[1], fb_args[2], fb_args[3])
	_check(fb.triangle_count() == 20, "G the drawn funbox is 20 triangles (CH56 section 3.1: 20)")
	# =====================================================================
	# THE BLIND CHECK, and CH60 owes TWO of them because it added a second
	# way for the comparison to be blind.
	#
	# (1) move an ARGUMENT: the funbox's ramp 0.10 u longer.
	# (2) move the PROFILE: a quarterpipe built one facet coarser. This is
	#     the one CH57 could not owe, and it is the one that matters here
	#     -- a comparison that could not see a changed curve would sign
	#     any decomposition of any arc.
	var f_args: Array = HubSkatepark.build_args(HubSkatepark.MODULES[0])
	var f_drawn := _distinct(SkateparkMesh.new().funbox(
		f_args[0], f_args[1], f_args[2], f_args[3]).surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	_check(not _same_set(_distinct(_flatten(SkateparkMesh.funbox_pieces(
			f_args[0], f_args[1], f_args[2], f_args[3] + 0.10))), f_drawn),
		"G BLIND CHECK 1: funbox pieces from a ramp 0.10 u longer do NOT match the drawn mesh")
	var q_args: Array = HubSkatepark.build_args(HubSkatepark.MODULES[2])
	var q_drawn := _distinct(SkateparkMesh.new().quarterpipe(
		q_args[0], q_args[1]).surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	_check(_same_set(_distinct(_flatten(SkateparkMesh.quarterpipe_pieces(q_args[0], q_args[1]))), q_drawn),
		"G the quarterpipe's 12 wedges ARE the drawn quarterpipe, point for point")
	_check(not _same_set(_distinct(_flatten(SkateparkMesh.quarterpipe_pieces(
			q_args[0], q_args[1] * 1.02))), q_drawn),
		"G BLIND CHECK 2: wedges from a curve 2%% taller do NOT match the drawn mesh")
	# =====================================================================
	# ⚠️ CH60 -- THE PROFILE ITSELF, GATED, because the bug this lot found
	# was IN it and nothing in the repo was watching.
	#
	# The delivered quarterpipe rose at 86.25 deg where the rider arrives
	# and lay at 3.75 deg at the lip -- the exact transpose of a
	# quarterpipe -- for seven lots. What proves the fix is not the shape
	# looking right: it is that the mesh's OWN VERTEX NORMALS, untouched
	# since CH53, agree with the geometry again. Measured before the fix:
	# 86.25 deg of disagreement, in an exact mirror. After: half a facet,
	# which is what a smooth normal against a flat facet must be.
	for index in [2, 3]:
		var spec: Dictionary = HubSkatepark.MODULES[index]
		var args: Array = HubSkatepark.build_args(spec)
		var prof: Array[Vector2] = SkateparkMesh.quarterpipe_profile(args[1])
		var foot: float = rad_to_deg(atan2(prof[1].y - prof[0].y, prof[1].x - prof[0].x))
		var lip: float = rad_to_deg(atan2(prof[12].y - prof[11].y, prof[12].x - prof[11].x))
		print("     [%d] quarterpipe profile: foot facet %.2f deg, lip facet %.2f deg" % [index, foot, lip])
		_check(foot < 10.0, "G[%d] the ramp is TANGENT TO THE GROUND where the rider arrives (%.2f deg)"
			% [index, foot])
		_check(lip > 80.0, "G[%d] and VERTICAL at the lip (%.2f deg)" % [index, lip])
		_check(lip - foot > 70.0, "G[%d] INSTRUMENT: the two ends really are different (%.2f deg apart)"
			% [index, lip - foot])
		var worst: float = _normal_disagreement(SkateparkMesh.new().quarterpipe(args[0], args[1]))
		print("     [%d] worst stored-normal vs true-face-normal: %.2f deg" % [index, worst])
		_check(worst < 4.0,
			"G[%d] the mesh's own normals agree with its geometry to within half a facet (%.2f deg)"
				% [index, worst])
	await get_tree().process_frame

func _mesh_of(builder: SkateparkMesh, kind: StringName, args: Array) -> ArrayMesh:
	match kind:
		HubSkatepark.KIND_QUARTERPIPE:
			return builder.quarterpipe(args[0], args[1])
		HubSkatepark.KIND_RAIL:
			return builder.rail(args[0], args[1])
		HubSkatepark.KIND_FUNBOX:
			return builder.funbox(args[0], args[1], args[2], args[3])
	return builder.bowl(args[0], args[1])

func _flatten(pieces: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for piece in pieces:
		for p in piece:
			out.append(p)
	return out

## The worst angle between a vertex normal the mesh CARRIES and the true
## normal of a face that vertex belongs to. Godot's front face is the
## clockwise one seen from the viewer, so the right-hand cross product of
## a visible face points AWAY from it -- hence the negation.
func _normal_disagreement(mesh: ArrayMesh) -> float:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var worst: float = -1.0
	for t in range(0, idx.size(), 3):
		var a: Vector3 = verts[idx[t]]
		var b: Vector3 = verts[idx[t + 1]]
		var c: Vector3 = verts[idx[t + 2]]
		var face: Vector3 = (b - a).cross(c - a)
		if face.length() < 1e-9:
			continue
		var outward: Vector3 = -face.normalized()
		for k in 3:
			worst = maxf(worst, rad_to_deg(acos(clampf(outward.dot(norms[idx[t + k]]), -1.0, 1.0))))
	return worst

func _distinct(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in points:
		var seen := false
		for q in out:
			if p.distance_to(q) < 0.0005:
				seen = true
				break
		if not seen:
			out.append(p)
	return out

func _same_set(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	if a.size() != b.size():
		return false
	for p in a:
		var found := false
		for q in b:
			if p.distance_to(q) < 0.0005:
				found = true
				break
		if not found:
			return false
	return true

# =====================================================================
# PHASE W -- THE WORLD, AND THE WITNESS IS THE SERVER
#
# CH56 section 3.3: counting nodes proves a probe built nodes; what has
# to be proved is that the PhysicsServer holds them. Both channels here,
# and the shape query is issued from a physics frame -- a space state
# refused mid-flush answers EMPTY, which is indistinguishable from "the
# world contains nothing", i.e. from the blind check passing.

func _phase_world() -> void:
	print("-- PHASE W: what the physics server actually holds --")
	var body := _transport.board_body()
	_check(body != null, "the board is a SkateBoardBody")
	_check(_park.module_nodes().size() == HubSkatepark.MODULES.size(),
		"all five modules are still drawn (%d)" % _park.module_nodes().size())
	# The registry the park PUBLISHES, against the tree it actually built.
	# Two channels for one fact, which is the only reason to read both.
	var registered: Array = _park.collider_indices()
	print("     the park publishes colliders on modules %s" % str(registered))
	_check(registered == [0, 1, 2, 3],
		"the funbox, the rail and the two quarterpipes carry colliders -- and only they (%s)"
			% str(registered))
	var on_tree: Array = []
	var shapes: int = 0
	for index in _park.module_count():
		var node := _park.module_node(index)
		for child in node.get_children():
			if child is StaticBody3D:
				on_tree.append(index)
				shapes += child.get_child_count()
	_check(on_tree == registered,
		"and the TREE carries exactly the bodies the registry names (%s)" % str(on_tree))
	for index in registered:
		var kind: StringName = _park.module_kind(index)
		var want: int = int(EXPECT_PIECES.get(kind, -1))
		_check(_park.collider_piece_count_at(index) == want,
			"     [%d] %s holds %d shapes (got %d)"
				% [index, String(kind), want, _park.collider_piece_count_at(index)])
	print("     %d convex shapes over %d bodies" % [shapes, registered.size()])
	_check(shapes == 30, "30 convex shapes in the park (3 + 3 + 12 + 12), got %d" % shapes)
	# ⚠️ THE BOWL, ASSERTED ABSENT rather than assumed. CLAUDE.md: an
	# assertion of ABSENCE passes for free, so it stands next to the four
	# positives above which prove the same test CAN find a body.
	_check(_park.collider_body_at(4) == null, "the bowl carries NO body (lot 3b)")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := body.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 400.0
	params.shape = ball
	params.transform = Transform3D(Basis(), _park.module_centre(0))
	params.collide_with_bodies = true
	params.collision_mask = 0xFFFFFFFF
	var hits: Array = space.intersect_shape(params, 64)
	# ⚠️ COUNT THE BODIES THE SERVER HOLDS, not the ones we think we made.
	# A `rid` appears once per SHAPE in the answer, so the bodies are the
	# DISTINCT rids -- counting rows would report 31 and call it 5.
	var rids: Array = []
	for hit in hits:
		var rid: RID = hit["rid"]
		if not rids.has(rid):
			rids.append(rid)
	print("     live space query over the whole hub: %d shape rows, %d distinct bodies"
		% [hits.size(), rids.size()])
	_check(rids.size() == 5,
		"the server holds FIVE bodies: four modules and the board (%d)" % rids.size())

# =====================================================================
# PHASE V -- IS THE COLLIDED SOLID THE DRAWN SOLID?
#
# ⚠️ THIS IS THE PHASE THE LOT EXISTS FOR, and PHASE G cannot replace it.
# An equality of point SETS says the collider is built from the drawn
# corners; it does not say the pieces TILE the shape. Twelve wedges that
# were all the same wedge would carry the identical 28 points and pass
# PHASE G outright -- and would leave eleven twelfths of a ramp as a hole
# a board falls through.
#
# So the two solids are sampled against each other, on a grid over the
# module's own world AABB, and every disagreement is counted:
#
#   * the DRAWN solid, by parity of an UPWARD ray against the module's
#     own triangles (`get_faces()` -- the geometry, never the formula
#     that made it). Up, because every module here is open at y = 0 and
#     closed everywhere a ray going up can leave it.
#   * the COLLIDED solid, through `intersect_point` on the PHYSICS
#     SERVER. Not the piece arrays this probe could recompute: the hulls
#     the engine actually built, epsilons and all. A wedge 0.0124 u thick
#     at its thinnest is exactly the kind of sliver a hull builder can
#     quietly drop, and only the server can be asked whether it did.
#
# ⚠️ AND IT CARRIES THE TWO GUARDS CLAUDE.md MADE COMPULSORY. An
# agreement count is an assertion of EQUALITY, which passes for free
# against an instrument that says "outside" to everything: the phase
# therefore asserts that BOTH classifiers vote both ways on every module,
# and it runs a BLIND CHECK -- the same comparison against a module whose
# body has been taken off the queried layer must produce disagreement on
# every interior sample.

## Samples per axis. 13 x 9 x 13 = 1521 per module, which is enough to
## put several samples inside the THINNEST wedge of the smaller
## quarterpipe (0.0124 u) and cheap enough to run four times.
const VOL_STEPS: Vector3i = Vector3i(13, 9, 13)

func _phase_volume() -> void:
	print("-- PHASE V: the collided solid IS the drawn solid, sampled --")
	for index in _park.collider_indices():
		var r: Dictionary = await _volume_scan(index, 0xFFFFFFFF)
		print("     [%d] %-12s samples %d   in-drawn %d   in-server %d   DISAGREE %d (drawn-only %d, server-only %d)"
			% [index, String(_park.module_kind(index)), int(r["n"]), int(r["a"]), int(r["b"]),
				int(r["dis"]), int(r["a_only"]), int(r["b_only"])])
		# The instrument, both ways, before the verdict.
		_check(int(r["a"]) > 0 and int(r["a"]) < int(r["n"]),
			"     [%d] INSTRUMENT: the DRAWN classifier votes both ways (%d in of %d)"
				% [index, int(r["a"]), int(r["n"])])
		_check(int(r["b"]) > 0 and int(r["b"]) < int(r["n"]),
			"     [%d] INSTRUMENT: the SERVER classifier votes both ways (%d in of %d)"
				% [index, int(r["b"]), int(r["n"])])
		_check(int(r["dis"]) == 0,
			"     [%d] every sample agrees: the collider is the drawn shape, no hole and no phantom"
				% index)
	# =====================================================================
	# THE BLIND CHECK. Take the tallest quarterpipe off the queried layer
	# and demand the SAME scan now disagrees on every interior sample. A
	# zero-disagreement verdict earned against a query that can no longer
	# see anything is CH40's empty hide-list exactly.
	var body := _park.collider_body_at(2)
	var keep: int = body.collision_layer
	body.collision_layer = 0
	var blind: Dictionary = await _volume_scan(2, 0xFFFFFFFF)
	body.collision_layer = keep
	print("     BLIND: [2] off its layer -> in-drawn %d  in-server %d  DISAGREE %d"
		% [int(blind["a"]), int(blind["b"]), int(blind["dis"])])
	_check(int(blind["b"]) == 0, "V BLIND CHECK: with the body off the layer the server finds nothing")
	_check(int(blind["dis"]) == int(blind["a"]) and int(blind["a"]) > 0,
		"V BLIND CHECK: and every interior sample becomes a disagreement (%d)" % int(blind["dis"]))
	# And it comes back, so the verdict above was not measured on a world
	# this phase then left broken.
	var back: Dictionary = await _volume_scan(2, 0xFFFFFFFF)
	_check(int(back["dis"]) == 0, "V and the agreement RETURNS when the layer is restored")

## Samples one module's world AABB and classifies every point twice.
func _volume_scan(index: int, mask: int) -> Dictionary:
	var node := _park.module_node(index)
	var faces: PackedVector3Array = node.mesh.get_faces()
	var xform: Transform3D = node.global_transform
	var world := PackedVector3Array()
	for v in faces:
		world.append(xform * v)
	var box: AABB = xform * node.mesh.get_aabb()
	var n: int = 0
	var a: int = 0
	var b: int = 0
	var a_only: int = 0
	var b_only: int = 0
	var params := PhysicsPointQueryParameters3D.new()
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.collision_mask = mask
	await get_tree().physics_frame
	var space := node.get_world_3d().direct_space_state
	for ix in VOL_STEPS.x:
		for iy in VOL_STEPS.y:
			# One physics frame per row keeps the space state fresh and
			# keeps a scan of 1521 queries off a single frame.
			await get_tree().physics_frame
			space = node.get_world_3d().direct_space_state
			for iz in VOL_STEPS.z:
				# ⚠️ OFFSET BY AN IRRATIONAL-ISH FRACTION so no sample lands
				# on a face, an edge or a vertex. A parity test taken on a
				# boundary is a coin toss published as a measurement.
				var p := box.position + Vector3(
					box.size.x * (float(ix) + 0.3183) / float(VOL_STEPS.x),
					box.size.y * (float(iy) + 0.2718) / float(VOL_STEPS.y),
					box.size.z * (float(iz) + 0.4142) / float(VOL_STEPS.z))
				n += 1
				var ia: bool = _in_drawn(p, world)
				params.position = p
				var ib: bool = not space.intersect_point(params, 4).is_empty()
				if ia:
					a += 1
				if ib:
					b += 1
				if ia and not ib:
					a_only += 1
				if ib and not ia:
					b_only += 1
	return {"n": n, "a": a, "b": b, "dis": a_only + b_only, "a_only": a_only, "b_only": b_only}

## Inside the DRAWN mesh, by parity of an upward ray against its own
## world-space triangles.
func _in_drawn(p: Vector3, tris: PackedVector3Array) -> bool:
	if p.y < 0.0:
		return false
	var hits: int = 0
	for t in range(0, tris.size(), 3):
		if _ray_up_hits(p, tris[t], tris[t + 1], tris[t + 2]):
			hits += 1
	return (hits % 2) == 1

func _ray_up_hits(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var v0 := Vector2(c.x - a.x, c.z - a.z)
	var v1 := Vector2(b.x - a.x, b.z - a.z)
	var v2 := Vector2(p.x - a.x, p.z - a.z)
	var den: float = v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-12:
		return false
	var u: float = (v2.x * v1.y - v1.x * v2.y) / den
	var v: float = (v0.x * v2.y - v2.x * v0.y) / den
	if u < 0.0 or v < 0.0 or u + v > 1.0:
		return false
	return a.y + u * (c.y - a.y) + v * (b.y - a.y) > p.y

# =====================================================================
# THE RIDE
#
# ⚠️ CH60 -- THE APPROACH IS READ OFF THE MODULE, NOT TYPED NEXT TO IT.
# CH57 could hard-code (0, 52) -> (0, 40) because there was one module
# and its yaw was zero. There are now four, two of them yawed (0.30 and
# PI), and a station typed in world coordinates would be a SECOND
# SPELLING of where a module faces -- the defect this repo pays for most
# often. So a ride is a signed distance along the module's OWN local +Z,
# taken from the transform of the node that was built.

## Signed multiples of `_ramp_dir(index)`: where the board starts and
## where it is aimed, relative to the module's own ground centre.
##
##   * the FUNBOX is entered by its local +Z ramp and aimed through to
##     the far side -- CH57's ride, restated in the module's frame and
##     gated below against the world coordinates CH57 published.
##   * a QUARTERPIPE is entered from its LOW side, which is local -Z:
##     the node's origin sits at the FOOT of the transition (the mesh
##     runs local z = 0 -> height), so the rider arrives from -Z and
##     travels up toward +Z. Module 2 is yawed 0 and faces south, module
##     3 is yawed PI and faces north -- an opposing pair, which is what
##     those two yaws MEAN now that the profile is the right way round.
const RIDES: Array[Dictionary] = [
	{"index": 0, "from": 6.5, "to": -5.5},
	{"index": 2, "from": -9.0, "to": 4.0},
	{"index": 3, "from": -8.0, "to": 4.0},
]

## The direction a rider travels UP a module, in world and flattened: the
## module's own local +Z, read off the node that carries the mesh.
func _ramp_dir(index: int) -> Vector3:
	var d: Vector3 = _park.module_node(index).global_transform.basis * Vector3(0.0, 0.0, 1.0)
	return Vector3(d.x, 0.0, d.z).normalized()

func _ride_ends(ride: Dictionary) -> Array:
	var index: int = int(ride["index"])
	var centre: Vector3 = _park.module_centre(index)
	var dir: Vector3 = _ramp_dir(index)
	return [centre + dir * float(ride["from"]), centre + dir * float(ride["to"])]

## The patch of a module the ride is JUDGED over, in the module's own
## local XZ. Published per kind rather than guessed from the AABB,
## because the two kinds are judged on OPPOSITE statistics:
##
##   * the FUNBOX on the MINIMUM height over its deck core -- "every tick
##     over the deck was ON it", CH57's gate, which is what separates a
##     climb from a pass-through.
##   * a QUARTERPIPE on the MAXIMUM height over its climbable ramp. A
##     minimum would be meaningless there: the ramp's own height varies
##     across the patch, so the board is legitimately low at the foot.
func _core_rect(index: int) -> Rect2:
	var spec: Dictionary = HubSkatepark.MODULES[index]
	var args: Array = HubSkatepark.build_args(spec)
	var size: Vector3 = spec["size"]
	match StringName(spec["kind"]):
		HubSkatepark.KIND_FUNBOX:
			var hx: float = size.x * 0.5 - 0.30
			var hz: float = args[1] * 0.5 - 0.10
			return Rect2(-hx, -hz, hx * 2.0, hz * 2.0)
		HubSkatepark.KIND_QUARTERPIPE:
			# From just past the foot to the last facet the board can
			# legally stand on (see `_climb_facet`).
			var reach: Vector2 = _climb_reach(args[1])
			return Rect2(-(size.x * 0.5 - 0.30), 0.05, size.x - 0.60, reach.x)
	# THE RAIL HAS NO SUCH PATCH, and returning an empty rect says so
	# rather than quietly borrowing another kind's rule. Its contract is
	# not "how high did it get over a patch" -- it is "blocked here,
	# through there" -- and PHASE J gates that on positions, never on this.
	return Rect2()

## ⚠️ HOW HIGH A QUARTERPIPE CAN ACTUALLY BE CLIMBED, AND IT IS NOT THE
## LIP. `SkateBoardBody` leaves `floor_max_angle` at Godot's 45 deg with a
## written reason, so every facet steeper than that is a WALL to the
## engine, not a floor. The profile's facets run 3.75, 11.25, ... 86.25
## deg, so the last one a body may stand on is the sixth, and the highest
## point it can reach is P6 -- (0.7071, 0.2929) * height, i.e. 29 % of the
## module's drawn rise and NOT its 100 %.
##
## This is a MEASURED consequence of the module being a real quarterpipe
## again, and it is the honest ceiling to gate against: a gate written at
## the lip would demand a climb no kinematic body without stored momentum
## can make.
func _climb_facet(height: float) -> int:
	var prof: Array[Vector2] = SkateparkMesh.quarterpipe_profile(height)
	var last: int = 0
	for s in SkateparkMesh.QP_SEGMENTS:
		if rad_to_deg(atan2(prof[s + 1].y - prof[s].y, prof[s + 1].x - prof[s].x)) <= 45.0:
			last = s + 1
	return last

func _climb_reach(height: float) -> Vector2:
	return SkateparkMesh.quarterpipe_profile(height)[_climb_facet(height)]

## Places the board, mounts him on it the way HubTransport does, aims it,
## and steps `ticks` physics frames while sampling. Returns the trace.
func _roll(label: String, index: int, from: Vector3, to: Vector3, ticks: int) -> Dictionary:
	var body := _transport.board_body()
	if _transport.is_riding_board():
		# ⚠️ CH61 -- HAND THE BOARD BACK ON OPEN LAWN, NOT WHERE THE RIDE
		# ENDED. `leave_board` steps the rider off with a hop, and a hop
		# that LANDS is offered to every hotspot HubWorld holds. Before
		# inertia every ride stopped short of its module and the few
		# metres they ended in happened to be empty; now the board rides
		# OVER the funbox and stops at (0, 40), inside the SEESAW's
		# landing disc. Measured: the seesaw took the rider,
		# `mount_carrier` refused every mount afterwards -- its one
		# precondition is `_state == IDLE` -- and PHASE R scored the two
		# quarterpipes at `path 0.00 u` against a board nobody was on.
		#
		# The game is right: a walk landing beside the seesaw is SUPPOSED
		# to be offered it. The bench was putting its rider down inside
		# another prop's hotspot.
		body.clear_target()
		body.velocity = Vector3.ZERO
		body.global_position = HubSurface.ground(NEUTRAL_PARK)
		_keepy.call("follow_carrier")
		await get_tree().physics_frame
		_transport.leave_board()
		for _i in 20:
			await get_tree().physics_frame
	_keepy.dismount_vehicle()
	body.clear_target()
	body.velocity = Vector3.ZERO
	body.global_position = HubSurface.ground(Vector3(from.x, 0.0, from.z))
	body.rotation.y = 0.0
	_keepy.global_position = HubSurface.ground(Vector3(from.x, 0.0, from.z))
	for _i in SETTLE:
		await get_tree().physics_frame
	var mounted: bool = _transport.mount_board()
	_transport.set_board_target(HubRegion.clamp_to(to))
	var node := _park.module_node(index)
	var to_local: Transform3D = node.global_transform.affine_inverse()
	var rect: Rect2 = _core_rect(index)
	var trace := {"mounted": mounted, "max_y": -1e9, "core_min_y": 1e9, "core_max_y": -1e9,
		"core_ticks": 0, "supported": 0, "under_surface": 0, "rider_off": 0, "path": 0.0,
		"arrived": false, "held_max_y": -1e9}
	var last: Vector3 = body.flat_position()
	for _t in ticks:
		await get_tree().physics_frame
		var flat: Vector3 = body.flat_position()
		var y: float = body.global_position.y
		trace["path"] = float(trace["path"]) + flat.distance_to(last)
		last = flat
		trace["max_y"] = maxf(float(trace["max_y"]), y)
		# ⚠️ CH61 -- THE HIGHEST THE MODULE EVER **HELD** IT, which is not
		# the highest it ever got. Before inertia the two were the same
		# thing: the board could not leave a surface, so every height it
		# reached was a height something was holding it at. Now it can be
		# thrown clear of a lip, and the two questions come apart. The
		# phantom test below wants the FIRST of them.
		if body.on_module():
			trace["held_max_y"] = maxf(float(trace["held_max_y"]), y)
		if body.supported():
			trace["supported"] = int(trace["supported"]) + 1
		# ⚠️ D1's invariant, checked on EVERY tick and not at the end:
		# HubSurface is the floor and physics may never put the body under
		# it. A sampled-at-the-end version of this passes for free.
		if y < HubSurface.height_at(flat) - 0.0005:
			trace["under_surface"] = int(trace["under_surface"]) + 1
		# Carrier-then-carried: the rider's feet are on the deck THIS tick,
		# never one frame behind it.
		if _transport.is_riding_board():
			var want: float = y + SkateparkMesh.DECK_TOP
			if absf(_keepy.global_position.y - want) > 0.0005:
				trace["rider_off"] = int(trace["rider_off"]) + 1
		var local: Vector3 = to_local * body.global_position
		if rect.has_point(Vector2(local.x, local.z)):
			trace["core_ticks"] = int(trace["core_ticks"]) + 1
			trace["core_min_y"] = minf(float(trace["core_min_y"]), y)
			trace["core_max_y"] = maxf(float(trace["core_max_y"]), y)
		if flat.distance_to(Vector3(to.x, 0.0, to.z)) < 1.0:
			trace["arrived"] = true
	trace["end"] = body.flat_position()
	print("     %-38s path %.2f u   max y %.3f   core %d ticks (y %s .. %s)   supported %d   arrived %s"
		% [label, trace["path"], trace["max_y"], trace["core_ticks"],
			("n/a" if int(trace["core_ticks"]) == 0 else "%.3f" % float(trace["core_min_y"])),
			("n/a" if int(trace["core_ticks"]) == 0 else "%.3f" % float(trace["core_max_y"])),
			trace["supported"], trace["arrived"]])
	return trace

func _phase_ride() -> void:
	print("-- PHASE R: THE POSITIVE -- the board climbs each solid module --")
	# CH57's published stations, restated from the module's own frame. A
	# bench that cannot reproduce a number already on file has no standing
	# to publish a new one.
	var ends: Array = _ride_ends(RIDES[0])
	print("     the funbox ride derived from the module: %s -> %s   (CH57 published %s -> %s)"
		% [str((ends[0] as Vector3).snappedf(0.01)), str((ends[1] as Vector3).snappedf(0.01)),
			str(RIDE_FROM), str(RIDE_TO)])
	_check((ends[0] as Vector3).distance_to(RIDE_FROM) < 0.01
			and (ends[1] as Vector3).distance_to(RIDE_TO) < 0.01,
		"R the derived funbox ride IS the one CH57 published")
	for ride in RIDES:
		await _ride_one(ride)

func _ride_one(ride: Dictionary) -> void:
	var index: int = int(ride["index"])
	var kind: StringName = _park.module_kind(index)
	var ends: Array = _ride_ends(ride)
	var from: Vector3 = ends[0]
	var to: Vector3 = ends[1]
	# The instrument before the ride: a station outside the region would be
	# refused by `_fence` and the whole case would pass by never happening.
	_check(HubRegion.contains(from) and HubRegion.contains(to),
		"R[%d] INSTRUMENT: both ends of the %s ride are inside the region" % [index, String(kind)])
	var t: Dictionary = await _roll("[%d] %s, with collider" % [index, String(kind)],
		index, from, to, RIDE_TICKS)
	_check(bool(t["mounted"]), "R[%d] he is aboard (mount_board took him)" % index)
	_check(float(t["path"]) > 6.0, "R[%d] INSTRUMENT: the board actually rolled (%.2f u > 6)"
		% [index, float(t["path"])])
	_check(int(t["core_ticks"]) > 0, "R[%d] INSTRUMENT: the roll reached the judged patch (%d ticks)"
		% [index, int(t["core_ticks"])])
	_check(int(t["under_surface"]) == 0,
		"R[%d] D1: never below HubSurface, on any tick (%d violations)" % [index, int(t["under_surface"])])
	_check(int(t["rider_off"]) == 0,
		"R[%d] carrier-then-carried: the rider is on the deck every tick (%d off)"
			% [index, int(t["rider_off"])])
	_check(int(t["supported"]) > 0,
		"R[%d] the module HELD it: supported() was true on %d ticks" % [index, int(t["supported"])])
	if kind == HubSkatepark.KIND_FUNBOX:
		var deck_h: float = float(HubSkatepark.MODULES[index]["size"].y)
		_check(float(t["core_min_y"]) >= deck_h - 0.03,
			"R[%d] HEIGHT: every tick over the deck was ON it (min y %.3f >= %.3f)"
				% [index, float(t["core_min_y"]), deck_h - 0.03])
		_check(bool(t["arrived"]),
			"R[%d] DISTANCE: it reached the far side of the module, it did not stop beside it" % index)
		return
	# A quarterpipe. Two axes again, and neither alone would do: a height
	# gate alone passes for a board that climbed a phantom, a "it got
	# there" gate alone passes for one that rolled straight through.
	var args: Array = HubSkatepark.build_args(HubSkatepark.MODULES[index])
	var reach: Vector2 = _climb_reach(args[1])
	# ⚠️ THE INDEX IS THE MEASURED ONE. The first version of this line
	# printed QP_SEGMENTS -- the LAST facet -- next to the coordinates of
	# the SIXTH, which is CLAUDE.md's "%e" defect: a true number under
	# another control's label sends the next reader to diagnose the wrong
	# thing.
	print("     [%d] climbable to P%d of %d = (z %.3f, y %.3f) of a %.2f u lip; reached %.3f"
		% [index, _climb_facet(args[1]), SkateparkMesh.QP_SEGMENTS,
			reach.x, reach.y, args[1], float(t["core_max_y"])])
	_check(float(t["core_max_y"]) >= reach.y * 0.5,
		"R[%d] HEIGHT: it CLIMBED the transition (%.3f >= half of the %.3f it can reach)"
			% [index, float(t["core_max_y"]), reach.y])
	# ⚠️ CH61 REWROTE BOTH OF THE ASSERTIONS BELOW, AND THE REASON IS THAT
	# EACH OF THEM CONFLATED TWO THINGS THAT ONLY CAME APART WITH INERTIA.
	#
	# (1) "never above the lip -- no phantom volume". What it is FOR is a
	# collider bigger than the drawn solid: a board standing on air. What
	# it MEASURED is height, and height above a lip now has a second and
	# entirely legitimate cause -- the board is thrown clear of the top
	# and is briefly a projectile. Measured on the 1.45 u ramp: 1.551 u,
	# red, on a collider PHASE V had just proved identical to the drawn
	# mesh on 1521 samples. So the test is moved onto what it always
	# meant: nothing may HOLD the board above the lip. Real air is
	# unsupported by construction and cannot trip it; a phantom volume is
	# supported by definition and cannot escape it.
	#
	# (2) "the transition STOPPED it". True of a body with no stored
	# elan, and CH60 wrote it as a property of quarterpipes. It is not:
	# it is a property of the ENERGY against the LIP. At the arrival this
	# ride produces the board has about v^2/2g = 1.55 u in hand, so the
	# 2.10 u ramp still stops it and the 1.45 u one does not -- it flies
	# out of the top, which is the module's own trick name ("air") and is
	# what a 1.45 u quarterpipe taken at speed does. The gate becomes the
	# arithmetic instead of the blanket claim, and it says which of the
	# two outcomes each module is owed.
	_check(float(t["held_max_y"]) <= args[1] + 0.05,
		"R[%d] nothing HELD it above the lip -- no phantom volume (held max %.3f <= %.3f)"
			% [index, float(t["held_max_y"]), args[1]])
	var lip: float = args[1]
	if bool(t["arrived"]):
		_check(float(t["core_max_y"]) > lip,
			"R[%d] it left by the TOP, over the %.2f u lip (%.3f) -- not through the solid"
				% [index, lip, float(t["core_max_y"])])
		_check(lip < 1.60,
			"R[%d] and only the SHORT ramp is clearable at this arrival (lip %.2f u)" % [index, lip])
	else:
		_check(float(t["core_max_y"]) < lip,
			"R[%d] the transition STOPPED it below its %.2f u lip (%.3f)"
				% [index, lip, float(t["core_max_y"])])
		_check(lip > 1.60,
			"R[%d] and it is the TALL ramp that stops it (lip %.2f u)" % [index, lip])

func _phase_neutralised() -> void:
	print("-- PHASE N: RED BEFORE GREEN, at runtime -- take each collider off the layer --")
	for ride in RIDES:
		var index: int = int(ride["index"])
		var kind: StringName = _park.module_kind(index)
		var ends: Array = _ride_ends(ride)
		var wall := _park.collider_body_at(index)
		var keep: int = wall.collision_layer
		wall.collision_layer = 0
		var t: Dictionary = await _roll("[%d] %s, NEUTRALISED" % [index, String(kind)],
			index, ends[0], ends[1], RIDE_TICKS)
		_check(float(t["path"]) > 6.0, "N[%d] INSTRUMENT: the neutralised run rolled too (%.2f u)"
			% [index, float(t["path"])])
		_check(int(t["core_ticks"]) > 0, "N[%d] INSTRUMENT: it crossed the same patch (%d ticks)"
			% [index, int(t["core_ticks"])])
		_check(int(t["core_ticks"]) > 0 and float(t["core_max_y"]) < 0.05,
			"N[%d] WITHOUT the collider it goes THROUGH the %s (max y over it %s)"
				% [index, String(kind),
					("n/a" if int(t["core_ticks"]) == 0 else "%.3f" % float(t["core_max_y"]))])
		_check(int(t["supported"]) == 0, "N[%d] and nothing held it (supported ticks %d)"
			% [index, int(t["supported"])])
		wall.collision_layer = keep
		var back: Dictionary = await _roll("[%d] %s, RESTORED" % [index, String(kind)],
			index, ends[0], ends[1], RIDE_TICKS)
		_check(int(back["core_ticks"]) > 0 and float(back["core_max_y"]) > 0.10,
			"N[%d] and the climb COMES BACK when the layer is restored (max y %s)"
				% [index, ("n/a" if int(back["core_ticks"]) == 0 else "%.3f" % float(back["core_max_y"]))])

func _phase_lateral() -> void:
	print("-- PHASE L: the other half of D1 -- a vertical face BLOCKS --")
	var t: Dictionary = await _roll("into the funbox east face", 0, SIDE_FROM, SIDE_TO, RIDE_TICKS)
	var centre: Vector3 = _park.module_centre(0)
	var half_x: float = float(HubSkatepark.MODULES[0]["size"].x) * 0.5
	var end: Vector3 = t["end"]
	_check(float(t["path"]) > 1.5, "INSTRUMENT: it set off (%.2f u)" % t["path"])
	_check(float(t["max_y"]) < 0.05, "it never got on top of the box (max y %.3f)" % t["max_y"])
	_check(end.x > centre.x + half_x - 0.30,
		"it was stopped east of the face (x %.3f, face at %.3f)" % [end.x, centre.x + half_x])
	_check(not _transport.board_body().has_target(),
		"and the stall guard dropped the target rather than grinding for ever")

# =====================================================================
# PHASE J -- THE RAIL, WHICH IS THE ONE MODULE THAT MUST BLOCK IN ONE
# PLACE AND NOT IN ANOTHER
#
# ⚠️ A RAIL CANNOT BE GATED THE WAY A RAMP IS. Its beam is 0.12 across
# and its underside sits at 0.56, while the board's capsule tops out at
# 2 * (DECK_WIDTH / 2) = 0.26: the board passes UNDER the beam, and the
# only thing in the module that can stop it is a LEG. So a gate that only
# asked "does the rail block the board" would be satisfied by a collider
# twice the size of the drawn rail, and a gate that only asked "does the
# board get through" would be satisfied by no collider at all.
#
# Both, then, on the SAME instrument and in the same run:
#
#   * head-on into a leg   -> STOPPED, and released when neutralised.
#   * across the gap       -> THROUGH, with the collider fully in place.
#
# The second is the one that prices the decomposition: a hull inflated by
# a hair, or a beam whose box was built from the wrong half-extent, shows
# up there and nowhere else. It is also this phase's own instrument
# control -- two opposite verdicts from one bench, so neither is the free
# kind.

func _phase_rail() -> void:
	print("-- PHASE J: the rail blocks at a leg and lets the board through between them --")
	var index: int = 1
	var node := _park.module_node(index)
	var args: Array = HubSkatepark.build_args(HubSkatepark.MODULES[index])
	var length: float = args[0]
	var leg_z: float = length * 0.5 * SkateparkMesh.RAIL_LEG_SPAN
	var across: Vector3 = _ramp_dir(index).cross(Vector3.UP).normalized()
	print("     rail: length %.2f  legs at local z +-%.3f  beam underside %.3f  board top %.3f"
		% [length, leg_z, args[1] - SkateparkMesh.RAIL_BEAM * 0.5, SkateparkMesh.DECK_WIDTH])
	_check(SkateparkMesh.DECK_WIDTH < args[1] - SkateparkMesh.RAIL_BEAM * 0.5,
		"J INSTRUMENT: the board really is short enough to pass under the beam")
	# (1) HEAD-ON INTO A LEG. The station is the leg's own world position,
	# read through the node's transform -- never typed.
	var leg: Vector3 = node.global_transform * Vector3(0.0, 0.0, leg_z)
	leg = Vector3(leg.x, 0.0, leg.z)
	var hit: Dictionary = await _roll("[1] rail, head-on into a leg", index,
		leg + across * 5.0, leg - across * 5.0, RIDE_TICKS)
	var end_hit: Vector3 = hit["end"]
	var missed: float = end_hit.distance_to(leg)
	print("     stopped %.3f u from the leg's axis (started 5.00 u out)" % missed)
	_check(float(hit["path"]) > 2.0, "J INSTRUMENT: it set off (%.2f u)" % float(hit["path"]))
	_check(missed < 1.0, "J1 it was STOPPED at the leg (%.3f u from its axis)" % missed)
	_check(not _transport.board_body().has_target(),
		"J1 and the stall guard dropped the target rather than grinding for ever")
	# ...and RED BEFORE GREEN on the same station.
	var wall := _park.collider_body_at(index)
	var keep: int = wall.collision_layer
	wall.collision_layer = 0
	var thru: Dictionary = await _roll("[1] rail, NEUTRALISED, same station", index,
		leg + across * 5.0, leg - across * 5.0, RIDE_TICKS)
	wall.collision_layer = keep
	var end_thru: Vector3 = thru["end"]
	_check(end_thru.distance_to(leg - across * 5.0) < 1.0,
		"J1 WITHOUT the collider it goes straight through the leg to the far side")
	# (2) ACROSS THE GAP, collider in place: the board must get through.
	var gap: Vector3 = node.global_transform * Vector3(0.0, 0.0, 0.0)
	gap = Vector3(gap.x, 0.0, gap.z)
	var pass_t: Dictionary = await _roll("[1] rail, between the legs", index,
		gap + across * 5.0, gap - across * 5.0, RIDE_TICKS)
	var end_pass: Vector3 = pass_t["end"]
	print("     between the legs it ended %.3f u from the far station" % end_pass.distance_to(gap - across * 5.0))
	_check(float(pass_t["max_y"]) < 0.05,
		"J2 it stayed on the ground -- the beam is not a floor (max y %.3f)" % float(pass_t["max_y"]))
	_check(bool(pass_t["arrived"]),
		"J2 and it PASSED UNDER the beam: the collider is not fatter than the drawn rail")

# =====================================================================
# PHASE T -- THE TRAVERSAL, WITH THE SWITCH UP
#
# Garde-fou 4 of the brief: "par D2 le risque est structurellement nul,
# mais CONFIRME-LE plutot que de le supposer". Form B's argument is that
# a tween consults no collider, so a walk cannot be deflected -- and
# CLAUDE.md answers that a structural argument is still an argument.
# This walks the published diagonal WITH the colliders in the world and
# demands the published figure to the frame.

func _phase_traversal() -> void:
	print("-- PHASE T: the published diagonal, walked with the physics world live --")
	if _transport.is_riding_board():
		_transport.leave_board()
		for _i in 30:
			await get_tree().physics_frame
	_keepy.dismount_vehicle()
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	var from := Vector3(-h, 0.0, -h)
	var to := Vector3(h, 0.0, h)
	_keepy.global_position = HubSurface.ground(from)
	_hops = 0
	_idle = false
	_keepy.hop_landed.connect(_on_landed)
	_keepy.became_idle.connect(_on_idle)
	_keepy.hop_to(to)
	var frames: int = 0
	while not _idle and frames < 6000:
		await get_tree().process_frame
		frames += 1
	_keepy.hop_landed.disconnect(_on_landed)
	_keepy.became_idle.disconnect(_on_idle)
	var seconds: float = float(frames) / FPS
	print("     diagonal: hops=%d frames=%d  %.3f s   (published %d / %.3f s)"
		% [_hops, frames, seconds, PUBLISHED_DIAGONAL_HOPS, PUBLISHED_DIAGONAL_S])
	_check(_hops == PUBLISHED_DIAGONAL_HOPS, "the hop count is the published one")
	_check(absf(seconds - PUBLISHED_DIAGONAL_S) < 1.0 / FPS,
		"and the crossing time is the published one, to the frame")

func _on_landed(_p: Vector3) -> void:
	_hops += 1

func _on_idle() -> void:
	_idle = true

# =====================================================================
# PHASE B -- ZERO PRIMITIVES, ZERO DRAW CALLS
#
# CH56's verdict rests on it: "un collider ne dessine rien. C'est
# exactement la monnaie dont CH52 mesure qu'il n'en reste AUCUNE au bord
# nord." The park's own budget probe would not see this -- it runs with
# the switch down -- so the comparison is made HERE, by building the hub
# a second time with the switch down and reading the SAME census.
#
# The census is HubPerfOverlay's own snapshot(), because CLAUDE.md says
# the producer publishes and the reader never reconstructs: a count
# rebuilt here would be wrong the first time somebody adds a node kind.
# `tris_scene` / `nodes_scene` are transforms and hold under any driver;
# the engine's two counters need a real one and are PRINTED, not gated,
# with the reason said out loud.

## The station both hubs are read from. IN THE PARK, so the module under
## test is in the frame that is being counted, and IDENTICAL for the two
## builds -- the first version of this phase read the ON hub wherever the
## traversal phase had left Keepy (the far corner of the plateau) and the
## OFF hub at its spawn, and reported the two DIFFERENT FRUSTA as a
## difference of 6 957 primitives. The scene census did not move by one
## triangle across the same pair, which is what showed the reading up.
const BUDGET_STATION: Vector3 = Vector3(0.0, 0.0, 52.0)

## How many frames each world is allowed to live before it is read. The
## SAME number for both, because that is the only thing that makes two
## pictures comparable in a hub whose actors move: CH37 measured the bear
## walking 1.27 u between two runs of one tree against 0.17 u between two
## trees, i.e. NOISE LARGER THAN SIGNAL, and named the repair -- turn the
## metric on itself before reading a difference as a regression.
const WORLD_AGE: int = 24

func _phase_budget() -> void:
	print("-- PHASE B: a collider draws nothing --")
	# OFF first and ON second, each built fresh and read at the same age at
	# the same station. The ON world is the one kept for every phase after
	# this: reading it here, before it has been ridden, is the whole point.
	DevTools.set_physics_override(false)
	var off_hub: Node = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(off_hub)
	var off: Dictionary = await _age_and_read(off_hub)
	var off_again: Dictionary = _census(off_hub)
	off_hub.queue_free()
	for _i in 10:
		await get_tree().process_frame
	DevTools.set_physics_override(true)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	var on: Dictionary = await _age_and_read(_hub)
	var on_again: Dictionary = _census(_hub)
	for key in ["nodes_scene", "tris_scene", "engine_prims", "engine_calls"]:
		print("     %-13s ON %8d (repeat %8d)   OFF %8d (repeat %8d)   delta %d"
			% [key, int(on.get(key, -1)), int(on_again.get(key, -1)),
				int(off.get(key, -1)), int(off_again.get(key, -1)),
				int(on.get(key, -1)) - int(off.get(key, -1))])
	_check(int(on.get("nodes_scene", -1)) > 0, "INSTRUMENT: the census counted something at all")
	# The scene census is transforms: driver-independent and exactly
	# reproducible, so it is gated on equality with no tolerance at all.
	_check(int(on.get("nodes_scene", -1)) == int(off.get("nodes_scene", -2)),
		"the same number of drawn nodes with the switch up as with it down")
	_check(int(on.get("tris_scene", -1)) == int(off.get("tris_scene", -2)),
		"and the same number of triangles in the scene")
	if DisplayServer.get_name() == "headless":
		print("     (engine primitive / draw-call counters need a real driver -- run under xvfb to sign them)")
		return
	# The engine's two counters are a FRAME reading, so each is gated only
	# where its own bench is immobile -- the repeat reading on the same
	# world, nothing touched. CLAUDE.md, CH41: a noisy station is PRINTED
	# and left out of the gate, with the reason written, never gated
	# against a tremor borrowed from somewhere else.
	for key in ["engine_prims", "engine_calls"]:
		var tremor: int = maxi(absi(int(on.get(key, -1)) - int(on_again.get(key, -1))),
			absi(int(off.get(key, -1)) - int(off_again.get(key, -1))))
		if tremor != 0:
			print("     (%s left OUT of the gate: the bench moves %d on its own here)" % [key, tremor])
			continue
		_check(int(on.get(key, -1)) == int(off.get(key, -2)),
			"%s in frame unchanged (bench immobile on both worlds)" % key)

## Lets a world live exactly WORLD_AGE frames, parks it at the station and
## reads it. Both halves of the comparison go through this one function so
## that neither the age nor the station can differ between them.
func _age_and_read(hub: Node) -> Dictionary:
	for _i in WORLD_AGE:
		await get_tree().process_frame
	await _station(hub, BUDGET_STATION)
	return _census(hub)

## Puts a hub's Keepy at `flat`, snaps its camera onto him and lets the
## frame settle -- the only way two builds are read from one frustum.
func _station(hub: Node, flat: Vector3) -> void:
	var keepy := hub.find_child("Keepy", true, false) as KeepyHopper
	var camera := hub.find_child("Camera3D", true, false) as Camera3D
	if keepy != null:
		keepy.dismount_vehicle()
		keepy.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	if camera != null and camera.has_method("snap_to_target"):
		camera.call("snap_to_target")
	for _i in SETTLE * 3:
		await get_tree().process_frame

func _census(hub: Node) -> Dictionary:
	var perf := hub.find_child("PerfOverlay", true, false) as HubPerfOverlay
	if perf == null:
		return {}
	return perf.snapshot()
