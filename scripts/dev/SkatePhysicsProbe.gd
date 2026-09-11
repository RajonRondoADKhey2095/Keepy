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
## CH64: the speed the bench feathers the throttle under for the phases
## that meet a WALL or a LEG head-on. The TAP adapter braked into its
## target, so those phases met their obstacle slowing; a held finger
## meets it at cruise and a capsule at 10 u/s glances off a 9 cm post
## (measured: 11.97 u past it). 3 u/s is a player easing up to a rail.
const SLOW_APPROACH: float = 3.0
## A flat point `_roll` measures its closest approach to (PHASE J: the
## leg's axis). Vector3.INF when no phase is watching one.
var _watch_point: Vector3 = Vector3.INF
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
## CH64: the bench's finger -- see SkateBench.
var _bench: SkateBench = null
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
	_bench = SkateBench.new()
	_bench.name = "Bench"
	add_child(_bench)
	_bench.setup(_transport, _hub.find_child("Camera3D", true, false) as Camera3D)
	await _phase_world()
	if _fails > 0:
		print("=== WORLD FAILED -- nothing physical was built. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_standing()
	await _phase_volume()
	await _phase_inventory()
	await _phase_bowl()
	await _phase_ride()
	await _phase_neutralised()
	await _phase_lateral()
	await _phase_rail()
	await _phase_traversal()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

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
	# CH64: BOARD_ARRIVE and BOARD_STALL_STEP went with the TAP adapter.
	# The bench that replaced it reads the same two off their owners
	# (SkateBench.aim's default, SkateBoardBody.REST_STEP) and never
	# retypes them.
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
## CH69: the bowl joins them. 21 azimuth sectors of 24 (three are the
## roll-in) times five profile segments -- written as the arithmetic and
## not as 105, because what has to be re-argued the day the door widens
## is the ARGUMENT, and the argument is one prism per (sector, segment).
const EXPECT_PIECES: Dictionary = {
	&"funbox": 3, &"rail": 3, &"quarterpipe": 12,
	&"bowl": (SkateparkMesh.BOWL_AZIMUTH - SkateparkMesh.BOWL_GATE_SECTORS) * SkateparkMesh.BOWL_RINGS,
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
		var shape_of: String = str(counts)
		if counts.size() > 12:
			shape_of = "%d x %d points" % [counts.size(), int(counts[0]) if counts.size() > 0 else 0]
		print("     [%d] %-12s args %s  %3d tri  pieces %s  union %d  drawn %d"
			% [index, String(kind), str(args), builder.triangle_count(),
				shape_of, _distinct(union).size(), drawn.size()])
		_check(pieces.size() == int(EXPECT_PIECES.get(kind, -1)),
			"G[%d] %s decomposes into %d pieces (got %d)"
				% [index, String(kind), int(EXPECT_PIECES.get(kind, -1)), pieces.size()])
		if kind == HubSkatepark.KIND_BOWL:
			# ⚠️ CH69 -- THE BOWL IS NOW SOLID, AND THE TEST IS THE SAME
			# TEST. CH66 wrote this branch for a module with NO pieces; it
			# now reads the shipped ones. What did not have to change is
			# the equality: the roll-in REMOVES faces and its two jambs
			# are fans over the profile polyline from the skirt's foot --
			# the very cross-section the pieces are cut from -- so the
			# door introduces no vertex position, and "the union of the
			# pieces IS the drawn concrete, floor centre apart" still
			# holds with 105 pieces instead of 120.
			var drawn_less_centre := PackedVector3Array()
			var centre_seen: int = 0
			for v in drawn:
				if v.length() < 0.0005:
					centre_seen += 1
				else:
					drawn_less_centre.append(v)
			var gate_first: int = int(args[2])
			var gate_count: int = int(args[3])
			print("     [%d] bowl ring: roll-in at sectors %d..%d of %d (mouth bearing %.1f deg, aim bearing %.1f deg), union %d points, drawn %d (floor centre %d)"
				% [index, gate_first, gate_first + gate_count - 1, SkateparkMesh.BOWL_AZIMUTH,
					rad_to_deg(SkateparkMesh.bowl_gate_bearing(gate_first, gate_count)),
					rad_to_deg(HubSkatepark.bowl_aim_bearing(spec)),
					_distinct(union).size(), drawn.size(), centre_seen])
			_check(centre_seen == 1, "G[%d] INSTRUMENT: the drawn dish carries exactly one floor-centre vertex (%d)" % [index, centre_seen])
			_check(_same_set(_distinct(union), drawn_less_centre),
				"G[%d] bowl: the union of the ring pieces IS the drawn dish, floor centre apart" % index)
			_check(not _same_set(_distinct(_flatten(SkateparkMesh.bowl_pieces(args[0], args[1] * 1.02, gate_first, gate_count))), drawn_less_centre),
				"G[%d] BLIND CHECK 3: ring pieces from a dish 2%% deeper do NOT match the drawn mesh" % index)
			# CH69 BLIND CHECK 4: the door is a real removal, not a
			# relabelling. The ungated ring must NOT match the drawn mesh
			# -- if it did, the gate would be drawing what it claims to
			# have taken away.
			_check(not _same_set(_distinct(_flatten(SkateparkMesh.bowl_pieces(args[0], args[1], gate_first, 0))), drawn_less_centre),
				"G[%d] BLIND CHECK 4: the UNGATED ring (120 pieces) does not match the drawn mesh -- the roll-in really is missing" % index)
			# And the door faces where the layout says. An arc, not a
			# point: the mouth spans gate_count sectors and the bearing to
			# `rollin_aim` has to fall inside it.
			var step: float = TAU / float(SkateparkMesh.BOWL_AZIMUTH)
			var off: float = absf(wrapf(HubSkatepark.bowl_aim_bearing(spec)
				- SkateparkMesh.bowl_gate_bearing(gate_first, gate_count), -PI, PI))
			_check(off <= step * float(gate_count) * 0.5,
				"G[%d] the roll-in's mouth CONTAINS the bearing to rollin_aim (%.1f deg off a %.1f deg half-arc)"
					% [index, rad_to_deg(off), rad_to_deg(step * float(gate_count) * 0.5)])
			solid += 1
			continue
		if pieces.is_empty():
			_check(false, "G[%d] %s has no pieces and no reason to have none" % [index, String(kind)])
			continue
		solid += 1
		_check(_same_set(_distinct(union), drawn),
			"G[%d] %s: the union of the pieces IS the set of distinct drawn vertex positions"
				% [index, String(kind)])
	_check(solid == 5, "G: CH69 -- ALL FIVE modules carry pieces (got %d)" % solid)
	# CH56 restated 468 park triangles and 20 for the funbox. A bench that
	# cannot restate a number on file has no standing to publish one.
	var fb := SkateparkMesh.new()
	var fb_args: Array = HubSkatepark.build_args(HubSkatepark.MODULES[0])
	fb.funbox(fb_args[0], fb_args[1], fb_args[2], fb_args[3])
	# CH64: the CONCRETE surface. The funbox now also carries a decor
	# surface (its two steel edges), solid to nothing and counted apart.
	_check(fb.concrete_triangle_count() == 20, "G the drawn funbox's concrete is 20 triangles (CH56 section 3.1: 20; decor apart: %d)" % fb.decor_triangle_count())
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
	return builder.bowl(args[0], args[1], args[2], args[3])

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
	_check(registered == [0, 1, 2, 3, 4],
		"CH69: every module carries a collider, the bowl included (%s)" % str(registered))
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
	var want_park: int = 3 + 3 + 12 + 12 + int(EXPECT_PIECES[&"bowl"])
	_check(shapes == want_park, "%d convex shapes in the park (3 + 3 + 12 + 12 + the bowl's ring), got %d" % [want_park, shapes])
	# ⚠️ CH69 -- THE BOWL, ASSERTED PRESENT. CH66 asserted it ABSENT here
	# and said why the assertion stood next to four positives: an absence
	# passes for free. The positive needs no such company, but it does
	# need to be the RING and not a stub, so the count above is what
	# carries it.
	_check(_park.collider_body_at(4) != null, "CH69: the bowl carries a body")
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
	# CH69: 256 and not 64. A rid appears once per SHAPE, and the park now
	# holds 135 hulls plus the board's capsule -- a 64-row cap truncated
	# the answer inside the bowl's ring and reported FOUR bodies for five,
	# which reads exactly like a body that was never built.
	var hits: Array = space.intersect_shape(params, 256)
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
	# CH71: THE EXPECTED SET IS PUBLISHED, NOT COUNTED. This used to read
	# `rids.size() == 6` -- five modules and the board -- and went red the
	# day the funfair stood its own StaticBody3D on the park layer, then
	# STOPPED the probe ("nothing physical was built"), which is not what
	# had happened. The gate's intent is "no body in the server that
	# nobody published": so the set is built from what the producers
	# publish (the park's bodies, the board, the fair's body when the
	# world has one) and compared as a SET, both ways -- an unpublished
	# body and a missing one both fail, and the next solid a lot adds
	# must publish itself here rather than bump a literal.
	var published: Array = []
	for index in _park.collider_indices():
		published.append(_park.collider_body_at(index).get_rid())
	published.append(body.get_rid())
	var fair: Node = _hub.get_node_or_null("WorldViewport/SubViewport/World/Funfair")
	if fair != null and fair.has_method("collider_body"):
		published.append((fair.call("collider_body") as StaticBody3D).get_rid())
	var unpublished: int = 0
	for rid in rids:
		if not published.has(rid):
			unpublished += 1
	var missing: int = 0
	for rid in published:
		if not rids.has(rid):
			missing += 1
	_check(unpublished == 0 and missing == 0 and rids.size() == published.size(),
		"the server holds exactly the %d published bodies (five modules, the board%s): %d live, %d unpublished, %d missing"
			% [published.size(), ", the fair" if fair != null else "", rids.size(), unpublished, missing])

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
	# ⚠️ CH69 -- SURFACE 0 ONLY, AND THE BOWL IS WHAT SHOWED IT UP.
	# `Mesh.get_faces()` returns EVERY surface, and D5 puts the coping and
	# the steel trim in surface 1 precisely because they are drawn and
	# solid to NOTHING. Comparing that against the server compares the
	# wrong two sets: a sample inside a coping tube is "drawn" and rightly
	# not on the server, and a ray leaving through a tube's wall flips a
	# parity that had been right. The quarterpipes have one tube each and
	# this grid never landed in it; the bowl has one per azimuth sector,
	# and the first run with the ring wired read 2 drawn-only and 2
	# server-only out of 1521 -- four samples that were the INSTRUMENT and
	# not the collider.
	var faces: PackedVector3Array = _solid_faces(node.mesh as ArrayMesh)
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

## The AABB of surface 0 alone, in the mesh's own frame. `Mesh.get_aabb()`
## spans every surface, and D5's coping stands proud of the concrete on
## purpose -- a slab test taken on it would be measuring the trim.
func _solid_aabb(mesh: ArrayMesh) -> AABB:
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	return box

## The triangles of surface 0 -- the SOLID surface -- in the mesh's own
## frame. Built from the index buffer rather than from `get_faces()`,
## which flattens every surface into one soup.
func _solid_faces(mesh: ArrayMesh) -> PackedVector3Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out := PackedVector3Array()
	for i in idx:
		out.append(verts[i])
	return out

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
# CH66 -- PHASE X: THE INVENTORY, AND WHY THE BOWL IS STILL NOT SOLID
#
# Mathieu asked for an AUDIT before any collider: what in the park is
# physical, what is not, measured. The answer is a published inventory
# (every CollisionObject3D the hub holds, counted off the tree and
# confirmed on the server by PHASE W), the pairwise overlap of the drawn
# solids, and the one fact that decides the bowl: its ring overlaps both
# quarterpipes where the layout stands. The perimeter is therefore gated
# on the MEASUREMENT -- the bowl stays unwired exactly as long as that
# overlap exists, and the day a layout lot moves it clear this phase goes
# red and says so.

const OVERLAP_STEPS: Vector3i = Vector3i(24, 12, 24)
var _bowl_verbose: bool = false
var _bowl_contacts: bool = false

func _collision_objects(root: Node, out: Array) -> void:
	if root is CollisionObject3D:
		out.append(root)
	for c in root.get_children():
		_collision_objects(c, out)

func _phase_inventory() -> void:
	print("-- PHASE X: the park's physical inventory, and the drawn solids against each other --")
	var found: Array = []
	_collision_objects(_hub, found)
	var areas: int = 0
	var statics: int = 0
	var chars: int = 0
	var shapes_total: int = 0
	for n in found:
		var co := n as CollisionObject3D
		var shapes: int = 0
		for c in co.get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
				shapes += 1
		shapes_total += shapes
		if co is Area3D:
			areas += 1
		elif co is StaticBody3D:
			statics += 1
		elif co is CharacterBody3D:
			chars += 1
		print("     %-70s %-16s layer %d mask %d shapes %d" % [_hub.get_path_to(n), co.get_class(), co.collision_layer, co.collision_mask, shapes])
	print("     inventory: %d areas (portals, inert), %d static bodies (modules), %d character bodies (the board), %d shapes"
		% [areas, statics, chars, shapes_total])
	# CH71: the funfair's one static body (its posts, station posts and
	# tower, all BoxShape3D -- D5) is a solid the park does not own. Its
	# counts are READ off what it publishes, never typed here: the day
	# the fair grows a post, this census follows it.
	var fair: Node = _hub.get_node_or_null("WorldViewport/SubViewport/World/Funfair")
	var fair_bodies: int = 0
	var fair_shapes: int = 0
	if fair != null and fair.has_method("collider_body"):
		var fb: StaticBody3D = fair.call("collider_body")
		fair_bodies = 1
		fair_shapes = fb.get_child_count()
	_check(areas == 3 and statics == 5 + fair_bodies and chars == 1 and found.size() == 9 + fair_bodies,
		"X the hub holds exactly 3 inert portal areas, 5 solid modules, 1 board and %d fair body (%d objects)" % [fair_bodies, found.size()])
	# CH69: the three portal cylinders, the board's capsule, the funbox's
	# 3, the rail's 3, twelve wedges each for the two quarterpipes, and
	# the bowl's ring -- spelled as its arithmetic, see EXPECT_PIECES.
	# CH71: plus the fair's published shapes.
	var want_shapes: int = 1 + 1 + 1 + 1 + 3 + 3 + 12 + 12 + int(EXPECT_PIECES[&"bowl"]) + fair_shapes
	_check(shapes_total == want_shapes, "X and %d shapes in all (got %d): the bowl brings %d, the fair %d" % [want_shapes, shapes_total, int(EXPECT_PIECES[&"bowl"]), fair_shapes])
	_check(_park.collider_indices() == [0, 1, 2, 3, 4], "X every module is solid, the bowl included (%s)" % str(_park.collider_indices()))
	# =================================================================
	# ⚠️ CH69 -- THE SLAB, AND UNTIL THIS LINE NOTHING READ IT.
	#
	# A module drawn half on the grass is not a defect the physics can
	# see: SLAB_WIDTH and SLAB_DEPTH had ONE reader in the whole repo
	# (SkateEdgeProbe, for a station's x) and no gate at all. CH69 grows
	# the concrete for the bowl, so the concrete gets a test -- otherwise
	# the constant that pays for the bowl's place outlives the reason it
	# has that value, which is CLAUDE.md's "une constante que rien ne
	# relit survit aux lots" exactly.
	#
	# The claim is the strong one: every module's CONCRETE (surface 0,
	# the solid one -- D5's coping may hang over) is ON the slab. CH68
	# had to tolerate 0.100 u of overhang because the delivered bowl had
	# it; here the slab is the lever, so the tolerance is gone and the
	# margin is printed.
	var worst_margin: float = 1e9
	var worst_who: String = ""
	for index in HubSkatepark.MODULES.size():
		var mn := _park.module_node(index)
		var box: AABB = mn.global_transform * _solid_aabb(mn.mesh as ArrayMesh)
		var margin: float = minf(minf(box.position.x - HubSkatepark.SLAB_MIN.x, HubSkatepark.SLAB_MAX.x - box.end.x),
			minf(box.position.z - HubSkatepark.SLAB_MIN.y, HubSkatepark.SLAB_MAX.y - box.end.z))
		if margin < worst_margin:
			worst_margin = margin
			worst_who = "[%d %s]" % [index, String(_park.module_kind(index))]
		print("     [%d] %-12s concrete x [%7.3f, %7.3f] z [%7.3f, %7.3f]  margin to the slab %+.3f"
			% [index, String(_park.module_kind(index)), box.position.x, box.end.x, box.position.z, box.end.z, margin])
	print("     slab x [%.2f, %.2f] z [%.2f, %.2f] = %.2f x %.2f; tightest module %s at %+.3f u"
		% [HubSkatepark.SLAB_MIN.x, HubSkatepark.SLAB_MAX.x, HubSkatepark.SLAB_MIN.y, HubSkatepark.SLAB_MAX.y,
			HubSkatepark.SLAB_WIDTH, HubSkatepark.SLAB_DEPTH, worst_who, worst_margin])
	_check(worst_margin > 0.0,
		"X every module's concrete stands ON the slab -- tightest %s at %+.3f u" % [worst_who, worst_margin])
	# The drawn solids against each other. Solid modules may not overlap
	# one another (a wall inside a ramp); the bowl's overlap is measured
	# and is the reason it is not solid.
	var tris: Array = []
	var boxes: Array = []
	for index in HubSkatepark.MODULES.size():
		var node := _park.module_node(index)
		tris.append(_world_faces(index))
		boxes.append(node.global_transform * (node.mesh as ArrayMesh).get_aabb())
	var bowl_overlaps: int = 0
	var solid_overlaps: int = 0
	for a in HubSkatepark.MODULES.size():
		for b in range(a + 1, HubSkatepark.MODULES.size()):
			var box: AABB = (boxes[a] as AABB).intersection(boxes[b])
			if box.size.x <= 0.0 or box.size.z <= 0.0:
				print("     [%d %s] x [%d %s]: AABBs disjoint" % [a, String(_park.module_kind(a)), b, String(_park.module_kind(b))])
				continue
			var r: Dictionary = await _overlap_scan(box, a, b, tris)
			print("     [%d %s] x [%d %s]: AABBs intersect (%.2f x %.2f x %.2f u); %d samples, in BOTH solids %d (%.1f %%), top y %.2f"
				% [a, String(_park.module_kind(a)), b, String(_park.module_kind(b)), box.size.x, box.size.y, box.size.z,
					int(r["n"]), int(r["both"]), 100.0 * float(r["both"]) / float(r["n"]), float(r["ymax"])])
			var bowl_pair: bool = _park.module_kind(a) == HubSkatepark.KIND_BOWL or _park.module_kind(b) == HubSkatepark.KIND_BOWL
			if bowl_pair:
				bowl_overlaps += int(r["both"])
			else:
				solid_overlaps += int(r["both"])
	_check(solid_overlaps == 0, "X no two SOLID modules share a sample: no wall inside a ramp (%d)" % solid_overlaps)
	print("     the bowl's ring shares %d samples with solid modules" % bowl_overlaps)
	_check((bowl_overlaps > 0) == HubSkatepark.pieces_for(HubSkatepark.MODULES[4]).is_empty(),
		"X the bowl is unwired IFF its ring overlaps a solid module (overlap %d, wired %s) -- move it clear and this line asks for the collider"
			% [bowl_overlaps, str(not HubSkatepark.pieces_for(HubSkatepark.MODULES[4]).is_empty())])
	# The ring classifier's own blind check: a point in the concrete ring
	# is IN, the dish's centre and a point above the lip are OUT.
	var centre: Vector3 = _park.module_centre(4)
	var args: Array = HubSkatepark.build_args(HubSkatepark.MODULES[4])
	var in_ring: bool = _in_bowl_ring(centre + Vector3(args[0] - 0.05, 0.10, 0.0), 4)
	var in_dish: bool = _in_bowl_ring(centre + Vector3(0.0, 0.10, 0.0), 4)
	var above: bool = _in_bowl_ring(centre + Vector3(args[0] - 0.05, args[1] + 0.10, 0.0), 4)
	_check(in_ring and not in_dish and not above, "X BLIND: the ring classifier sees the concrete (%s) and not the dish (%s) nor the air above the lip (%s)" % [str(in_ring), str(in_dish), str(above)])

func _world_faces(index: int) -> PackedVector3Array:
	var node := _park.module_node(index)
	var faces: PackedVector3Array = (node.mesh as ArrayMesh).get_faces()
	var xf: Transform3D = node.global_transform
	var out := PackedVector3Array()
	for v in faces:
		out.append(xf * v)
	return out

func _in_solid(p: Vector3, index: int, tris: PackedVector3Array) -> bool:
	if _park.module_kind(index) == HubSkatepark.KIND_BOWL:
		return _in_bowl_ring(p, index)
	return _in_drawn(p, tris)

## Inside the bowl's concrete RING: between the flat floor and the skirt,
## under the faceted dish profile. The dish itself is open, so a parity
## test on its faces is not a solid test -- this reads the published
## profile instead, which is the same curve the pieces are cut from.
func _in_bowl_ring(p: Vector3, index: int) -> bool:
	var node := _park.module_node(index)
	var local: Vector3 = node.global_transform.affine_inverse() * p
	var args: Array = HubSkatepark.build_args(HubSkatepark.MODULES[index])
	var prof: Array[Vector2] = SkateparkMesh.bowl_profile(args[0], args[1])
	# ⚠️ THE RING IS A 24-GON, NOT A CIRCLE. Every ring of the dish is
	# drawn as BOWL_AZIMUTH chords, so a point's radius is compared to the
	# profile at the chord's own scale: r_eq = r cos(d) / cos(pi / N),
	# where d is the angle to the nearest sector centre. Measured before
	# the line was written: the circular test called 8 samples in the
	# sliver between chord and arc "in" while the server (rightly) did not.
	# The vertices sit at k * 2 pi / N and the chords' MIDPOINTS half a
	# sector further round: the offset that matters is to the nearest
	# midpoint, where the polygon's radius is R cos(pi / N). (A first
	# version measured the offset to the nearest VERTEX and disagreed
	# with the server on 29 samples of 1521, all within one chord's
	# sagitta of a facet.)
	var n: float = float(SkateparkMesh.BOWL_AZIMUTH)
	var half: float = PI / n
	var theta: float = atan2(local.z, local.x)
	var sector: float = floor(theta / (2.0 * half))
	var d: float = theta - (sector + 0.5) * 2.0 * half
	var r: float = Vector2(local.x, local.z).length() * cos(d) / cos(half)
	# CH69: the roll-in's sectors carry no concrete at all. Asked with the
	# builder's own predicate, never with a re-derived angle test -- the
	# reader does not rebuild an inventory the producer holds.
	if SkateparkMesh.bowl_sector_open(wrapi(int(floor(fposmod(theta, TAU) / (2.0 * half))), 0, SkateparkMesh.BOWL_AZIMUTH),
		int(args[2]), int(args[3])):
		return false
	if local.y < 0.0 or r < prof[0].x or r > prof[prof.size() - 1].x:
		return false
	for s in prof.size() - 1:
		if r >= prof[s].x and r <= prof[s + 1].x:
			var y: float = prof[s].y + (prof[s + 1].y - prof[s].y) * (r - prof[s].x) / maxf(prof[s + 1].x - prof[s].x, 1e-6)
			return local.y <= y
	return false

func _overlap_scan(box: AABB, a: int, b: int, tris: Array) -> Dictionary:
	var n: int = 0
	var both: int = 0
	var ymax: float = 0.0
	for ix in OVERLAP_STEPS.x:
		await get_tree().process_frame
		for iy in OVERLAP_STEPS.y:
			for iz in OVERLAP_STEPS.z:
				var p := box.position + Vector3(box.size.x * (float(ix) + 0.3183) / float(OVERLAP_STEPS.x),
					box.size.y * (float(iy) + 0.2718) / float(OVERLAP_STEPS.y),
					box.size.z * (float(iz) + 0.4142) / float(OVERLAP_STEPS.z))
				n += 1
				if _in_solid(p, a, tris[a]) and _in_solid(p, b, tris[b]):
					both += 1
					ymax = maxf(ymax, p.y)
	return {"n": n, "both": both, "ymax": ymax}

# =====================================================================
# CH66 / CH69 -- PHASE Y: THE BOWL RIDES, ON THE SHIPPED COLLIDER
#
# CH66 proved the ring on a StaticBody3D hung for the length of the phase
# because `pieces_for` returned empty and there was nothing else to ride.
# CH69 wires it, so the temporary body is GONE and every test below is on
# the collider a player meets. The layer scan can be asked on LAYER_PARK
# now for a reason that is ASSERTED rather than assumed: at its new place
# the bowl's AABB no longer contains a slice of any other module, which
# is what forced CH66 onto a private layer (it measured 56 false
# "server" samples from the quarterpipes the old AABB swallowed).
#
# ⚠️ AND THE PHASE GAINS THE TEST THE MODULE EXISTS FOR. A bowl a board
# can only fall into is not a bowl: CH66's second reason for leaving it
# out was that a ring with a vertical skirt has no ground entry. So the
# roll-in is ridden IN, by the real input channel, and its blind check is
# CH67's -- the same approach at a FULL sector must be STOPPED, or
# "it went in" is passing against a wall that was never there.

func _phase_bowl() -> void:
	print("-- PHASE Y: the bowl's ring collider, as shipped, is ridden --")
	var index: int = 4
	var node := _park.module_node(index)
	var args: Array = HubSkatepark.build_args(HubSkatepark.MODULES[index])
	var radius: float = args[0]
	var lip: float = args[1]
	var gate_first: int = int(args[2])
	var gate_count: int = int(args[3])
	var centre: Vector3 = _park.module_centre(index)
	var body := _transport.board_body()
	var shipped := _park.collider_body_at(index)
	_check(shipped != null and _park.collider_piece_count_at(index) == int(EXPECT_PIECES[&"bowl"]),
		"Y the bowl carries its %d hulls off the TREE (%d)" % [int(EXPECT_PIECES[&"bowl"]), _park.collider_piece_count_at(index)])
	# INSTRUMENT: the AABB the scan below sweeps holds no other module, so
	# a hit on LAYER_PARK inside it can only be the bowl.
	var bowl_box: AABB = node.global_transform * (node.mesh as ArrayMesh).get_aabb()
	var intruders: int = 0
	for other in HubSkatepark.MODULES.size():
		if other == index:
			continue
		var on := _park.module_node(other)
		var box: AABB = on.global_transform * (on.mesh as ArrayMesh).get_aabb()
		var inter: AABB = bowl_box.intersection(box)
		if inter.size.x > 0.0 and inter.size.z > 0.0:
			intruders += 1
			print("     the bowl's AABB still holds a slice of [%d %s]" % [other, String(_park.module_kind(other))])
	_check(intruders == 0,
		"Y INSTRUMENT: no other module's AABB reaches into the bowl's (%d) -- the LAYER_PARK scan is unambiguous" % intruders)
	await get_tree().physics_frame
	# (a) the collided ring IS the drawn ring, sampled against the server
	var scan: Dictionary = await _ring_scan(index, true)
	print("     ring vs server: %d samples, in ring %d, in server %d, DISAGREE %d (ring-only %d, server-only %d)"
		% [int(scan["n"]), int(scan["a"]), int(scan["b"]), int(scan["dis"]), int(scan["a_only"]), int(scan["b_only"])])
	_check(int(scan["a"]) > 0 and int(scan["a"]) < int(scan["n"]) and int(scan["b"]) > 0 and int(scan["b"]) < int(scan["n"]),
		"Y INSTRUMENT: both classifiers vote both ways")
	_check(int(scan["dis"]) == 0, "Y every sample agrees: the ring collider is the drawn ring, the dish stays OPEN, the floor stays the lawn")
	# (b) ENTER FROM THE AIR: dropped from above the lip onto the dish
	# centre, it lands on the LAWN (HubSurface), held by no module.
	await _hand_back()
	await _park_for_ride(centre)
	body.global_position.y = lip + 0.6
	_check(_transport.mount_board(), "Y INSTRUMENT: aboard, above the dish")
	var landed_y: float = -1.0
	var landed_tick: int = -1
	for t in 90:
		await get_tree().physics_frame
		if landed_tick < 0 and body.global_position.y <= HubSurface.height_at(body.flat_position()) + 0.0005 and body.velocity.y <= 0.0:
			landed_tick = t
			landed_y = body.global_position.y
	print("     ENTER (from the air): landed at tick %d, y %.4f, on_module %s, at r %.2f from the axis"
		% [landed_tick, landed_y, str(body.on_module()), Vector2(body.global_position.x - centre.x, body.global_position.z - centre.z).length()])
	_check(landed_tick >= 0 and not body.on_module() and body.global_position.y <= HubSurface.height_at(body.flat_position()) + 0.0005,
		"Y ENTER: the board drops into the dish and lands on the lawn -- the floor is HubSurface's, no piece under it")
	# (b2) CH69 -- ENTER ON THE GROUND, THROUGH THE DOOR, BY THE FINGER.
	var mouth: Vector3 = _bowl_dir(node, SkateparkMesh.bowl_gate_bearing(gate_first, gate_count))
	var wall: Vector3 = _bowl_dir(node, SkateparkMesh.bowl_gate_bearing(gate_first, gate_count) + PI)
	var rolled: Dictionary = await _roll_in(centre, radius, lip, mouth, "ROLL-IN (through the door)")
	_check(float(rolled["min_r"]) < radius - lip,
		"Y ROLL-IN: the board rolled in at ground level and reached the flat floor (min r %.3f < %.2f)"
			% [float(rolled["min_r"]), radius - lip])
	# ⚠️ AND IT HAS TO HAVE CROSSED. The first version reported "y at the
	# rim 0.0000" for a run that never reached the rim at all, because a
	# missing crossing defaulted to zero -- an assertion of a VALUE
	# standing in for an assertion of an EVENT, which is the free pass
	# CLAUDE.md's blind check exists to close.
	_check(bool(rolled["crossed"]) and float(rolled["cross_y"]) <= 0.02,
		"Y ROLL-IN: it crossed the rim (%s) and did so ON THE GROUND (y %.4f at r = %.2f), not over the lip"
			% [str(rolled["crossed"]), float(rolled["cross_y"]), radius])
	_check(int(rolled["pops"]) == 0 and int(rolled["fenced"]) == 0,
		"Y ROLL-IN: nothing popped it and nothing fenced it (pops %d, fenced %d)" % [int(rolled["pops"]), int(rolled["fenced"])])
	# THE BLIND CHECK, and it is what makes the three above a result: the
	# same geometry aimed at a sector that is NOT the door is stopped by
	# the skirt. Without it "the board got in" would pass against a bowl
	# whose collider had never been built.
	var blind: Dictionary = await _roll_in(centre, radius, lip, wall, "BLIND (the same approach at a FULL sector)")
	print("     BLIND vs DOOR: min r %.3f (wall) against %.3f (door), for a skirt at %.2f and a floor at %.2f"
		% [float(blind["min_r"]), float(rolled["min_r"]), radius, radius - lip])
	_check(float(blind["min_r"]) > radius - 0.35,
		"Y BLIND: the same approach at a full sector is STOPPED at the skirt (min r %.3f vs %.2f)" % [float(blind["min_r"]), radius])
	# (c) ROLL and CLIMB, slow: pushed at the wall at 4 u/s it climbs the
	# transition part way, comes BACK to the floor, never crosses the
	# skirt, is never thrown over the lip.
	#
	# ⚠️ ABOARD, and the first CH69 run is why the word is here. CH66 ran
	# this leg on the board the ENTER drop had left MOUNTED in the dish;
	# CH69 inserted the roll-in between them, so the leg had to re-park --
	# and a re-park that dismounts leaves a body HubTransport does not
	# step. It read max r 0.000, max y 0.000, "back on the floor: never":
	# three numbers that look exactly like a board wedged at the axis, on
	# a bowl that was working.
	await _hand_back()
	await _park_for_ride(centre)
	var dir: Vector3 = wall
	body.rotation.y = atan2(dir.x, dir.z)
	_check(_transport.mount_board(), "Y INSTRUMENT: aboard for the free roll")
	# A free roll at 4 u/s (0.31 u of energy against a 1.35 u wall): this
	# is the GEOMETRY's test, so the board is given the speed and no
	# finger -- a finger pushes, and a push up a wall is the next test.
	body.velocity = dir * 4.0
	# ⚠️ WHAT THE CONTACT DUMP SAID, so nobody re-reads 0.139 u as a
	# defect: the roll spends 3.97 -> 3.03 u/s on the lawn (the coast) and
	# 3.03 -> 2.06 on the 9 deg foot facet, reaches the 27 deg facet with
	# 0.16 u of energy and climbs 0.139 -- on its FRONT TIP, the capsule
	# (0.92 u long) bridging a 1.35 u transition. Contact normals read
	# (-0.16, 0.99) then (-0.45, 0.89): the 9 and 27 deg facets, floors
	# both. The kinematics are gravity's; nothing catches, nothing kicks.
	var climb := await _watch_bowl(centre, radius, lip, 90)
	print("     CLIMB (free roll at 4 u/s): max held y %.3f, max y %.3f, max r %.3f (skirt %.2f), back on the floor at tick %d, pops %d, fenced %d, min speed after peak %.3f"
		% [float(climb["held_max_y"]), float(climb["max_y"]), float(climb["max_r"]), radius, int(climb["back_at"]), int(climb["pops"]), int(climb["fenced"]), float(climb["min_speed_after"])])
	_check(float(climb["held_max_y"]) > 0.10 and float(climb["held_max_y"]) < lip * 0.5,
		"Y CLIMB: the wall HELD the board part way up (%.3f of %.2f) -- it climbed, it was not thrown over" % [float(climb["held_max_y"]), lip])
	_check(float(climb["max_r"]) < radius + 0.05,
		"Y CLIMB: it never crossed the skirt (max r %.3f vs %.2f): nothing passes through the ring" % [float(climb["max_r"]), radius])
	_check(int(climb["back_at"]) > 0, "Y CLIMB: and it came back down to the floor (tick %d): not wedged" % int(climb["back_at"]))
	_check(int(climb["pops"]) == 0, "Y CLIMB: a climb that does not clear the lip gives no pop (%d)" % int(climb["pops"]))
	# The same wall with a FINGER held into it (the real channel): the
	# push climbs while the facet lets it, stalls where it cannot, and the
	# board comes back. What is gated is that a stall on the wall is not a
	# launch: no pop, never over the lip, never through, never wedged.
	await _hand_back()
	await _park_for_ride(centre)
	body.rotation.y = atan2(dir.x, dir.z)
	_check(_transport.mount_board(), "Y INSTRUMENT: aboard for the held climb")
	_bench.aim(HubRegion.clamp_to(centre + dir * 8.0), KeepyHopper.ARRIVE_EPSILON, 4.0)
	var held := await _watch_bowl(centre, radius, lip, 240)
	_bench.release()
	print("     CLIMB (finger held into the wall, feathered at 4 u/s): max held y %.3f, max y %.3f, max r %.3f, back on the floor at tick %d, pops %d, bench lifted at %d"
		% [float(held["held_max_y"]), float(held["max_y"]), float(held["max_r"]), int(held["back_at"]), int(held["pops"]), _bench.stalled_at()])
	_check(float(held["held_max_y"]) > float(climb["held_max_y"]) and float(held["max_y"]) < lip,
		"Y HELD: the push climbs higher than the free roll (%.3f > %.3f) and still not over the lip (%.3f)" % [float(held["held_max_y"]), float(climb["held_max_y"]), float(held["max_y"])])
	_check(int(held["pops"]) == 0 and float(held["max_r"]) < radius + 0.05 and int(held["back_at"]) > 0,
		"Y HELD: a stall on the wall is not a launch -- no pop (%d), not through (r %.3f), came back (tick %d)" % [int(held["pops"]), float(held["max_r"]), int(held["back_at"])])
	# (d) EXIT at cruise: it climbs the whole transition, leaves over the
	# lip, and lands OUTSIDE the ring, inside the region.
	await _hand_back()
	await _park_for_ride(centre - dir * 2.0)
	body.rotation.y = atan2(dir.x, dir.z)
	_check(_transport.mount_board(), "Y INSTRUMENT: aboard for the exit")
	_bench.aim(HubRegion.clamp_to(centre + dir * 12.0))
	var exit := await _watch_bowl(centre, radius, lip, 240)
	_bench.release()
	var end_r: float = Vector2(body.global_position.x - centre.x, body.global_position.z - centre.z).length()
	print("     EXIT (cruise): max held y %.3f, max y %.3f, max r %.3f, pops %d, fenced %d, ends at r %.2f, y %.3f, in region %s"
		% [float(exit["held_max_y"]), float(exit["max_y"]), float(exit["max_r"]), int(exit["pops"]), int(exit["fenced"]), end_r, body.global_position.y, str(HubRegion.contains(body.flat_position()))])
	# Held into the top of the wall. The ORIGIN's height while held reads
	# 0.88 to 1.04 from run to run (the capsule's front tip rides the
	# steep facet ahead of its origin, and the bench's approach shifts
	# with the chase camera's settle under machine load), so the gate is
	# the foot of the second-to-last facet; that the exit was from the
	# LIP facet is what "exactly one pop" proves below (POP_MAX_NORMAL_Y).
	var prof: Array[Vector2] = SkateparkMesh.bowl_profile(radius, lip)
	var upper_foot: float = prof[prof.size() - 3].y
	_check(float(exit["held_max_y"]) >= upper_foot, "Y EXIT: the wall held it into its top two facets (%.3f >= %.3f of a %.2f lip)" % [float(exit["held_max_y"]), upper_foot, lip])
	_check(end_r > radius + 0.3 and int(exit["fenced"]) == 0 and HubRegion.contains(body.flat_position()),
		"Y EXIT: it left over the lip and came down OUTSIDE the ring (r %.2f), inside the region" % end_r)
	_check(int(exit["pops"]) == 1, "Y EXIT: the lip gave exactly ONE pop (%d)" % int(exit["pops"]))
	_check(float(exit["max_y"]) < lip + 3.0, "Y EXIT: and it was not thrown to the sky (peak %.3f)" % float(exit["max_y"]))
	await _hand_back()

## A world-space direction from a LOCAL azimuth of the bowl -- the module
## carries the yaw, so the door turns with it.
func _bowl_dir(node: Node3D, bearing: float) -> Vector3:
	var local := Vector3(cos(bearing), 0.0, sin(bearing))
	return (node.global_transform.basis * local).normalized()

## Rolls the board at the bowl along `from_dir`, by the FINGER, and
## reports how deep it got. `from_dir` points from the bowl's axis toward
## where the board starts, so the run is inward.
func _roll_in(centre: Vector3, radius: float, lip: float, from_dir: Vector3, label: String) -> Dictionary:
	var body := _transport.board_body()
	# CH62: a bench leg that starts outside HubRegion measures a run that
	# never happened -- the fence REFUSES the step and ERASES the target.
	var start: Vector3 = centre + from_dir * (radius + 3.2)
	var in_region: bool = HubRegion.contains(Vector3(start.x, 0.0, start.z))
	await _hand_back()
	await _park_for_ride(start)
	# CH65: a bench that parks a body without saying which way it faces
	# measures an arc. Nose on the axis, so the run-up is a straight line.
	body.rotation.y = atan2(-from_dir.x, -from_dir.z)
	var mounted: bool = _transport.mount_board()
	var pops0: int = body.pops()
	var fenced: int = 0
	var on_fenced := func() -> void: fenced += 1
	body.fenced.connect(on_fenced)
	_bench.aim(centre - from_dir * 1.5)
	var min_r: float = 1e9
	var cross_y: float = -1.0
	var max_y: float = 0.0
	var last_r: float = (Vector2(body.global_position.x - centre.x, body.global_position.z - centre.z)).length()
	for _t in 200:
		await get_tree().physics_frame
		var r: float = Vector2(body.global_position.x - centre.x, body.global_position.z - centre.z).length()
		if last_r > radius and r <= radius and cross_y < 0.0:
			cross_y = body.global_position.y
		last_r = r
		min_r = minf(min_r, r)
		max_y = maxf(max_y, body.global_position.y)
	_bench.release()
	body.fenced.disconnect(on_fenced)
	print("     %-44s: start %s in region %s, mounted %s, min r %.3f, crossed the rim %s at y %s, peak y %.3f, pops %d, fenced %d, bench lifted at %d"
		% [label, str(Vector2(start.x, start.z)), str(in_region), str(mounted), min_r,
			str(cross_y >= 0.0), ("%.4f" % cross_y) if cross_y >= 0.0 else "--",
			max_y, body.pops() - pops0, fenced, _bench.stalled_at()])
	_check(in_region and mounted, "%s INSTRUMENT: the run starts inside the region and aboard" % label)
	return {"min_r": min_r, "crossed": cross_y >= 0.0, "cross_y": maxf(cross_y, 0.0), "max_y": max_y,
		"pops": body.pops() - pops0, "fenced": fenced}

func _watch_bowl(centre: Vector3, radius: float, lip: float, ticks: int) -> Dictionary:
	var body := _transport.board_body()
	var t := {"held_max_y": 0.0, "max_y": 0.0, "max_r": 0.0, "back_at": -1, "pops": 0, "fenced": 0, "min_speed_after": 1e9}
	var pops0: int = body.pops()
	var fenced: int = 0
	var on_fenced := func() -> void: fenced += 1
	body.fenced.connect(on_fenced)
	var peaked: bool = false
	var last_pops: int = pops0
	for tick in ticks:
		await get_tree().physics_frame
		var y: float = body.global_position.y
		var r: float = Vector2(body.global_position.x - centre.x, body.global_position.z - centre.z).length()
		if _bowl_verbose and (y > 0.3 or body.pops() != last_pops or _bowl_contacts):
			var contacts: String = ""
			for c in body.get_slide_collision_count():
				var col: KinematicCollision3D = body.get_slide_collision(c)
				contacts += " n(%.2f, %.2f, %.2f)" % [col.get_normal().x, col.get_normal().y, col.get_normal().z]
			print("        t%03d y %.3f r %.3f v (%.2f, %.2f, %.2f) module %s supported %s air_ticks %d pops %d speed %.2f floor %s%s"
				% [tick, y, r, body.velocity.x, body.velocity.y, body.velocity.z, str(body.on_module()), str(body.supported()), body.air_ticks(), body.pops() - pops0, body.speed(), str(body.is_on_floor()), contacts])
		last_pops = body.pops()
		t["max_y"] = maxf(float(t["max_y"]), y)
		if body.on_module():
			t["held_max_y"] = maxf(float(t["held_max_y"]), y)
		if y < lip:
			t["max_r"] = maxf(float(t["max_r"]), r)
		if y > 0.10:
			peaked = true
		elif peaked and int(t["back_at"]) < 0 and not body.on_module():
			t["back_at"] = tick
		if peaked:
			t["min_speed_after"] = minf(float(t["min_speed_after"]), body.speed())
	body.fenced.disconnect(on_fenced)
	t["pops"] = body.pops() - pops0
	t["fenced"] = fenced
	return t

## Samples the bowl's AABB and classifies every point by the ring
## profile and by the physics server.
func _ring_scan(index: int, _with_server: bool) -> Dictionary:
	var node := _park.module_node(index)
	var box: AABB = node.global_transform * (node.mesh as ArrayMesh).get_aabb()
	var n: int = 0
	var a: int = 0
	var b: int = 0
	var a_only: int = 0
	var b_only: int = 0
	var params := PhysicsPointQueryParameters3D.new()
	params.collide_with_bodies = true
	params.collide_with_areas = false
	# CH69: the SHIPPED layer. CH66 had to scan a private one because the
	# bowl's AABB then swallowed slices of both quarterpipes (56 false
	# "server" samples); PHASE Y asserts that AABB is clean now, which is
	# what lets this ask the layer a player's board asks.
	params.collision_mask = 1 << (SkateBoardBody.LAYER_PARK - 1)
	await get_tree().physics_frame
	var space := node.get_world_3d().direct_space_state
	for ix in VOL_STEPS.x:
		for iy in VOL_STEPS.y:
			await get_tree().physics_frame
			space = node.get_world_3d().direct_space_state
			for iz in VOL_STEPS.z:
				var p := box.position + Vector3(
					box.size.x * (float(ix) + 0.3183) / float(VOL_STEPS.x),
					box.size.y * (float(iy) + 0.2718) / float(VOL_STEPS.y),
					box.size.z * (float(iz) + 0.4142) / float(VOL_STEPS.z))
				n += 1
				var ia: bool = _in_bowl_ring(p, index)
				params.position = p
				var ib: bool = not space.intersect_point(params, 4).is_empty()
				if ia:
					a += 1
				if ib:
					b += 1
				if ia != ib and a_only + b_only < 6:
					var local: Vector3 = node.global_transform.affine_inverse() * p
					print("        disagree: ring %s server %s at local (%.3f, %.3f, %.3f) r %.3f" % [str(ia), str(ib), local.x, local.y, local.z, Vector2(local.x, local.z).length()])
				if ia and not ib:
					a_only += 1
				if ib and not ia:
					b_only += 1
	return {"n": n, "a": a, "b": b, "dis": a_only + b_only, "a_only": a_only, "b_only": b_only}

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
func _roll(label: String, index: int, from: Vector3, to: Vector3, ticks: int, speed_cap: float = INF) -> Dictionary:
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
		body.stop()
		body.velocity = Vector3.ZERO
		body.global_position = HubSurface.ground(NEUTRAL_PARK)
		_keepy.call("follow_carrier")
		await get_tree().physics_frame
		_transport.leave_board()
		for _i in 20:
			await get_tree().physics_frame
	_keepy.dismount_vehicle()
	body.stop()
	body.velocity = Vector3.ZERO
	body.global_position = HubSurface.ground(Vector3(from.x, 0.0, from.z))
	# ⚠️ CH65 -- PARKED FACING THE RUN, NOT FACING NORTH. `rotation.y = 0`
	# was free while the facing snapped to whatever heading arrived on the
	# first tick; since CH65 the nose is rate-limited and the push waits
	# for it, so a run aimed anywhere but north began with a pivot of up
	# to 2.1 s and then described a CURVE. Measured on the runs that come
	# in from the east: the board reached the funbox's face at x = -8.03
	# instead of x = 2.20, and the neutralised rail run passed 3.009 u
	# clear of a volume it was supposed to go straight through -- both
	# reading like collider defects, both an unstated starting facing.
	var _aim_dir := Vector3(to.x - from.x, 0.0, to.z - from.z)
	body.rotation.y = atan2(_aim_dir.x, _aim_dir.z) if _aim_dir.length() > 0.0001 else 0.0
	_keepy.global_position = HubSurface.ground(Vector3(from.x, 0.0, from.z))
	for _i in SETTLE:
		await get_tree().physics_frame
	var mounted: bool = _transport.mount_board()
	# CH64: the bench's finger. `speed_cap` feathers the throttle for the
	# phases that need a SLOW arrival (a leg, a wall) -- the deleted TAP
	# adapter braked into its target and those phases were written on
	# that arrival; a finger has no brake, only a lift.
	_bench.aim(HubRegion.clamp_to(to), KeepyHopper.ARRIVE_EPSILON, speed_cap)
	var node := _park.module_node(index)
	var to_local: Transform3D = node.global_transform.affine_inverse()
	var rect: Rect2 = _core_rect(index)
	var trace := {"mounted": mounted, "max_y": -1e9, "core_min_y": 1e9, "core_max_y": -1e9,
		"core_ticks": 0, "supported": 0, "under_surface": 0, "rider_off": 0, "path": 0.0,
		"arrived": false, "held_max_y": -1e9, "min_to_watch": 1e9}
	var last: Vector3 = body.flat_position()
	for _t in ticks:
		await get_tree().physics_frame
		var flat: Vector3 = body.flat_position()
		var y: float = body.global_position.y
		trace["path"] = float(trace["path"]) + flat.distance_to(last)
		last = flat
		if _watch_point != Vector3.INF:
			trace["min_to_watch"] = minf(float(trace["min_to_watch"]), flat.distance_to(_watch_point))
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
	trace["bench_lifted_at"] = _bench.stalled_at()
	print("        (bench: %d ticks, progress guard lifted the finger at tick %d)" % [_bench.ticks(), _bench.stalled_at()])
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
	# CH64: THE ARRIVAL CHANGED, AND THE ARITHMETIC WITH IT. The TAP
	# adapter BRAKED into a target four units behind the wall, so the
	# board met the foot of every transition already slowing (~1.55 u of
	# energy in hand: the 2.10 u ramp stopped it at 1.348, the 1.45 u one
	# let it out). A HELD FINGER meets the foot at cruise -- v^2/2g is
	# 1.923 u -- and keeps pushing up the transition while the surface
	# still offers grip, so BOTH quarterpipes are clearable (measured on
	# this tree: max y 2.191 over the 2.10 u lip). That is a player's
	# ride, and it is what makes a trick off either ramp reachable at all.
	# The gate is what it always meant: over the top or stopped below,
	# never THROUGH the solid -- read on the board's highest point rather
	# than on the core window, which the board leaves before the lip.
	var lip: float = args[1]
	if bool(t["arrived"]):
		_check(float(t["max_y"]) > lip - 0.05,
			"R[%d] it left by the TOP, over the %.2f u lip (max y %.3f) -- not through the solid"
				% [index, lip, float(t["max_y"])])
	else:
		_check(float(t["max_y"]) < lip + 0.05,
			"R[%d] the transition STOPPED it below its %.2f u lip (max y %.3f)"
				% [index, lip, float(t["max_y"])])
	print("     R[%d] a held finger arrives at cruise: v^2/2g = %.3f u against a %.2f u lip, and pushes on the way up"
		% [index, HubTransport.SKATE_CRUISE * HubTransport.SKATE_CRUISE / (2.0 * SkateBoardBody.GRAVITY), lip])

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
	var t: Dictionary = await _roll("into the funbox east face", 0, SIDE_FROM, SIDE_TO, RIDE_TICKS, SLOW_APPROACH)
	var centre: Vector3 = _park.module_centre(0)
	var half_x: float = float(HubSkatepark.MODULES[0]["size"].x) * 0.5
	var end: Vector3 = t["end"]
	_check(float(t["path"]) > 1.5, "INSTRUMENT: it set off (%.2f u)" % t["path"])
	_check(float(t["max_y"]) < 0.05, "it never got on top of the box (max y %.3f)" % t["max_y"])
	_check(end.x > centre.x + half_x - 0.30,
		"it was stopped east of the face (x %.3f, face at %.3f)" % [end.x, centre.x + half_x])
	_check(_bench.stalled_out() or not _bench.is_down(),
		"and the bench's progress guard lifted the finger rather than holding it into the face for ever")

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
	# CH64: A PUSHED BOARD SLIDES ROUND A POST, and the gate is the post's
	# SOLIDITY, not where the board ends. The TAP adapter braked into a
	# target five units past the leg, so the board reached the leg almost
	# stopped and stayed there (CH60: 0.506 u from the axis). A finger
	# keeps pushing, a capsule against a 9 cm post is never centred, and
	# the board slides round it and on to the target (measured: 7.4 u past
	# the axis at a 3 u/s approach, 12 u at cruise) -- a legitimate ride,
	# not a hole in the collider. What a solid post owes is that the board
	# never OCCUPIES it: its closest approach to the axis stays outside
	# the capsule's radius plus the post's half-width, and with the layer
	# off the same run passes THROUGH the axis.
	var solid_gap: float = SkateparkMesh.DECK_WIDTH * 0.5 + SkateparkMesh.RAIL_LEG * 0.5
	_watch_point = leg
	var hit: Dictionary = await _roll("[1] rail, head-on into a leg", index,
		leg + across * 5.0, leg - across * 5.0, RIDE_TICKS, SLOW_APPROACH)
	var end_hit: Vector3 = hit["end"]
	print("     closest approach to the leg's axis %.3f u (capsule + half post = %.3f); ended %.3f u past it"
		% [float(hit["min_to_watch"]), solid_gap, end_hit.distance_to(leg)])
	_check(float(hit["path"]) > 2.0, "J INSTRUMENT: it set off (%.2f u)" % float(hit["path"]))
	_check(float(hit["min_to_watch"]) > solid_gap - 0.03,
		"J1 the leg is SOLID: the board never came nearer its axis than %.3f u (>= %.3f)"
			% [float(hit["min_to_watch"]), solid_gap - 0.03])
	_check(not _bench.is_down(),
		"J1 and the bench's finger is up (the run ended, by arrival or by its progress guard)")
	var wall := _park.collider_body_at(index)
	var keep: int = wall.collision_layer
	wall.collision_layer = 0
	var thru: Dictionary = await _roll("[1] rail, NEUTRALISED, same station", index,
		leg + across * 5.0, leg - across * 5.0, RIDE_TICKS, SLOW_APPROACH)
	wall.collision_layer = keep
	_watch_point = Vector3.INF
	var end_thru: Vector3 = thru["end"]
	print("     NEUTRALISED: closest approach %.3f u; ended %.3f u past the axis"
		% [float(thru["min_to_watch"]), end_thru.distance_to(leg)])
	_check(float(thru["min_to_watch"]) < solid_gap,
		"J1 WITHOUT the collider it passes INSIDE the volume a solid post refuses (%.3f u < %.3f)"
			% [float(thru["min_to_watch"]), solid_gap])
	_check(bool(thru["arrived"]) and (end_thru - leg).dot(-across) > 0.0,
		"J1 and on to the far side")
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
	# CH64: ONE tree, read twice. The switch-down world this phase used to
	# build no longer exists, so the A/B is made on a THROWAWAY world: read
	# it with its colliders, take every StaticBody3D and the board's shape
	# OUT of it, read it again at the same age and station, and only then
	# build the world every phase after this one rides. The blind check is
	# the count of what was removed -- a zero there would make "colliders
	# draw nothing" and "there were no colliders" read alike.
	var trial: Node = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(trial)
	var with: Dictionary = await _age_and_read(trial)
	var with_again: Dictionary = _census(trial)
	# The park's four StaticBody3D, and the board's CollisionShape3D --
	# never the board NODE itself (HubTransport reads its position every
	# frame; freeing it under the transport crashed the first version of
	# this phase), and never the three portal Area3D (CH55: deliberately
	# inert, and their visuals hang under them).
	var removed_bodies: int = 0
	var removed_shapes: int = 0
	var trial_park := trial.find_child("Skatepark", true, false)
	for node in trial_park.find_children("*", "StaticBody3D", true, false):
		removed_shapes += node.get_child_count()
		removed_bodies += 1
		node.get_parent().remove_child(node)
		node.queue_free()
	var trial_transport := trial.find_child("Transport", true, false) as HubTransport
	var trial_board := trial_transport.board_body()
	for node in trial_board.find_children("*", "CollisionShape3D", false, false):
		removed_shapes += 1
		trial_board.remove_child(node)
		node.queue_free()
	for _i in 10:
		await get_tree().process_frame
	var without: Dictionary = await _age_and_read(trial)
	var without_again: Dictionary = _census(trial)
	trial.queue_free()
	for _i in 10:
		await get_tree().process_frame
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	for _i in WORLD_AGE:
		await get_tree().process_frame
	print("     removed %d collision objects carrying %d shapes from the trial world" % [removed_bodies, removed_shapes])
	var want_removed: int = 3 + 3 + 12 + 12 + int(EXPECT_PIECES[&"bowl"]) + 1
	_check(removed_bodies == 5 and removed_shapes == want_removed,
		"B BLIND CHECK: there were colliders to remove (5 park bodies, %d hulls + the board's capsule = %d shapes; got %d / %d)"
			% [want_removed - 1, want_removed, removed_bodies, removed_shapes])
	for key in ["nodes_scene", "tris_scene", "engine_prims", "engine_calls"]:
		print("     %-13s WITH %8d (repeat %8d)   WITHOUT %8d (repeat %8d)   delta %d"
			% [key, int(with.get(key, -1)), int(with_again.get(key, -1)),
				int(without.get(key, -1)), int(without_again.get(key, -1)),
				int(with.get(key, -1)) - int(without.get(key, -1))])
	_check(int(with.get("nodes_scene", -1)) > 0, "INSTRUMENT: the census counted something at all")
	_check(int(with.get("nodes_scene", -1)) == int(without.get("nodes_scene", -2)),
		"the colliders draw NOT ONE node: the census is the same with and without them")
	_check(int(with.get("tris_scene", -1)) == int(without.get("tris_scene", -2)),
		"and not one triangle")
	if DisplayServer.get_name() == "headless":
		print("     (engine primitive / draw-call counters need a real driver -- run under xvfb to sign them)")
		return
	for key in ["engine_prims", "engine_calls"]:
		var tremor: int = maxi(absi(int(with.get(key, -1)) - int(with_again.get(key, -1))),
			absi(int(without.get(key, -1)) - int(without_again.get(key, -1))))
		if tremor != 0:
			print("     (%s left OUT of the gate: the bench moves %d on its own here)" % [key, tremor])
			continue
		_check(int(with.get(key, -1)) == int(without.get(key, -2)),
			"%s in frame unchanged (bench immobile on both readings)" % key)

# =====================================================================
# PHASE I -- WHAT PERMANENT PHYSICS COSTS WHEN NOBODY RIDES
#
# CH64 removed the switch, and the brief's own warning is the reason this
# phase exists: the north lobe already has no frame budget (CH52), and a
# physics world that ticked for every player everywhere could sink the
# FPS far from the park. So the tick is MEASURED, at the spawn, on foot,
# 46 u from the park -- with the park's bodies in the space, then with
# every one of them taken out of it (PhysicsServer3D.body_set_space to a
# null space: no node freed, fully reversible), then back in -- and the
# difference is read against the bench's own floor (two readings of one
# configuration).
#
# Positive first (CLAUDE.md's blind check): with the rider aboard and the
# finger held, the same instrument must read a cost clearly above the
# floor, or it cannot see physics at all and the idle zero is worthless.
#
# ⚠️ WHAT THIS SIGNS AND WHAT IT DOES NOT. It signs that an IDLE physics
# world costs this sandbox nothing it can measure; it is a PROXY for the
# device (CH56's F is the unknown between the two), and the FPS Mathieu
# reads on his phone is the only number that decides. The reading is
# wall time per physics frame under --fixed-fps 60 headless, PhysicsCost
# Probe's own instrument.
const STANDING_TICKS: int = 240
## The standing budget, per physics tick on this sandbox: at F = 10
## (CH56's worst projection) and 50 FPS, 0.10 ms/tick is 1.2 ms of a
## 20 ms frame, 6 %.
const STANDING_BUDGET_MS: float = 0.10

func _phase_standing() -> void:
	print("-- PHASE I: the idle cost of permanent physics, at the spawn --")
	await _station(_hub, Vector3.ZERO)
	var bodies: Array = _hub.find_children("*", "PhysicsBody3D", true, false)
	var space: RID = _transport.board_body().get_world_3d().space
	var a: float = await _tick_ms(STANDING_TICKS)
	var a2: float = await _tick_ms(STANDING_TICKS)
	for b in bodies:
		PhysicsServer3D.body_set_space((b as CollisionObject3D).get_rid(), RID())
	var out: float = await _tick_ms(STANDING_TICKS)
	var out2: float = await _tick_ms(STANDING_TICKS)
	for b in bodies:
		PhysicsServer3D.body_set_space((b as CollisionObject3D).get_rid(), space)
	var back: float = await _tick_ms(STANDING_TICKS)
	var floor_ms: float = maxf(absf(a - a2), absf(out - out2))
	var idle_delta: float = (a + a2) * 0.5 - (out + out2) * 0.5
	print("     %d collision objects   tick with bodies %.4f / %.4f ms   without %.4f / %.4f ms   back in %.4f ms"
		% [bodies.size(), a, a2, out, out2, back])
	print("     idle delta %.4f ms/tick against a bench floor of %.4f ms/tick" % [idle_delta, floor_ms])
	_check(bodies.size() >= 5, "I INSTRUMENT: there were bodies to take out of the space (%d)" % bodies.size())
	# The positive: a RIDDEN board, finger held, must cost something this
	# instrument can see.
	await _park_for_ride(NEUTRAL_PARK)
	_check(_transport.mount_board(), "I INSTRUMENT: the rider is aboard for the positive")
	_bench.hold_straight()
	var riding: float = await _tick_ms(STANDING_TICKS)
	_bench.release()
	var ride_delta: float = riding - (out + out2) * 0.5
	print("     ridden, finger held: %.4f ms/tick -> +%.4f over the empty space" % [riding, ride_delta])
	_check(ride_delta > floor_ms * 2.0 and ride_delta > 0.02,
		"I BLIND CHECK: the instrument SEES a ridden board (+%.4f ms/tick, floor %.4f)" % [ride_delta, floor_ms])
	# Now the number means something. It is NOT gated to zero and not to
	# a fraction of a ride (a first version asked for a quarter and read
	# 0.019 then 0.062 ms/tick on two runs of one tree, either side of a
	# 0.04-0.05 floor -- a gate on a ratio of two numbers this close to a
	# bench's own noise is a coin toss dressed as a verdict). It is gated
	# against a BUDGET: STANDING_BUDGET_MS per tick, which at CH56's F = 10
	# and 50 FPS is 6 % of a 20 ms frame -- and against the ride, which an
	# idle world must cost less than. The reading is PUBLISHED with its
	# floor and its projection; the phone's FPS is the verdict.
	_check(idle_delta <= STANDING_BUDGET_MS,
		"I the idle park stands under the budget (%.4f <= %.2f ms/tick; floor %.4f)" % [idle_delta, STANDING_BUDGET_MS, floor_ms])
	_check(idle_delta < ride_delta,
		"I and costs less than one ride (%.4f vs %.4f ms/tick)" % [idle_delta, ride_delta])
	if idle_delta <= floor_ms:
		print("     -> idle cost UNDER the bench floor: not measurable here")
	else:
		print("     -> idle cost %.4f ms/tick above floor; at F=10 and 50 FPS that is %.2f %% of a 20 ms frame"
			% [idle_delta, idle_delta * 10.0 * 1.2 / 20.0 * 100.0])
	await _hand_back()

func _tick_ms(ticks: int) -> float:
	for _i in 12:
		await get_tree().physics_frame
	var t0: int = Time.get_ticks_usec()
	for _i in ticks:
		await get_tree().physics_frame
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(ticks)

func _park_for_ride(flat: Vector3) -> void:
	var body := _transport.board_body()
	_keepy.dismount_vehicle()
	body.stop()
	body.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	body.rotation.y = 0.0
	_keepy.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	for _i in SETTLE:
		await get_tree().physics_frame

func _hand_back() -> void:
	var body := _transport.board_body()
	if _transport.is_riding_board():
		body.stop()
		body.global_position = HubSurface.ground(NEUTRAL_PARK)
		_keepy.call("follow_carrier")
		await get_tree().physics_frame
		_transport.leave_board()
		for _i in 20:
			await get_tree().physics_frame
	_keepy.dismount_vehicle()

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
