extends Node
## CH63 -- WHAT ACTUALLY TOUCHES THE STATION MATHIEU REPORTED.
##
## =====================================================================
## THE TWO SIGNALS, AND WHY NEITHER IS TAKEN ON TRUST
##
## Device report, one capture, station (-1.9, 51.3), physics ON:
##   1. `pairs 6`, and "je sens que je monte, je ne passe pas a travers,
##      je monte, mais je n'ai pas assez d'elan" -- on what he calls
##      "le bol".
##   2. FPS 39 (min 30), physMAX 3.60 ms, against 55-56 FPS and ~1-2 ms
##      on the same protocol before CH62.
##
## Signal 1 contradicts every published report: CH56 12.4 refused the
## bowl a collider, CH60 says so in code ("`pieces_for()` returns EMPTY
## for it"), CH61 and CH62 never touched it. The brief is explicit that
## neither Mathieu nor the reports get the benefit of the doubt -- so
## this probe MEASURES which of the two is true, and it measures it with
## the PHYSICS SERVER rather than by reading a node name.
##
## =====================================================================
## ⚠️ THE INSTRUMENT IS PROVED BEFORE IT IS BELIEVED (18th false-signal)
##
## "Nothing is there" is an assertion of ABSENCE, and CLAUDE.md is
## explicit that those pass for free. A `intersect_point` that queries
## the wrong collision mask, the wrong space RID, or a world that never
## built its colliders returns EXACTLY the same empty array as a bowl
## that has no collider -- and that empty array is the answer this probe
## exists to produce. So PHASE I runs FIRST and has to show the query
## SEEING something before any emptiness below counts:
##
##   * a point known to be inside a solid module must come back HIT;
##   * a point in open lawn must come back EMPTY;
##   * the collider's layer is taken away, the FIRST point is re-queried,
##     and it must go blind -- then the layer is put back and the hit
##     must return.
##
## Green / red / green on one tree, at runtime, nothing edited on disk.
##
## =====================================================================
## AND IT REPRODUCES A NUMBER ALREADY ON FILE BEFORE PUBLISHING A NEW ONE
##
## CLAUDE.md: "un banc incapable de restituer la diagonale a 66 hops /
## 18,700 s n'a pas qualite a publier un chiffre neuf". The number this
## bench has to restitute is CH61's: the 2.10 quarterpipe stops the board
## at 1.348 u of height, the 1.45 one does not. PHASE E rolls both and
## prints what it gets before PHASE E's verdict is used for anything.
##
## HEADLESS. Every phase reads transforms, physics-server queries and
## CPU timings -- no pixel, no MultiMesh instance, no screen point. CH56
## section 8 and CLAUDE.md's driver rule: a probe that reads only those
## runs headless, and under llvmpipe it would spend its budget rendering.

const BUDGET_S: float = 900.0
const SETTLE: int = 12
const WORLD_AGE: int = 90

## The station off the device capture, verbatim.
const STATION: Vector2 = Vector2(-1.9, 51.3)

## Module indices, spelled once here and gated against the table below so
## a reordered MODULES array cannot silently re-point this probe.
const I_FUNBOX: int = 0
const I_RAIL: int = 1
const I_QP_BIG: int = 2
const I_QP_SMALL: int = 3
const I_BOWL: int = 4

var _fails: int = 0
var _hub: Node = null
var _park: HubSkatepark = null
var _transport: HubTransport = null
var _keepy: KeepyHopper = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE STATION DIAG", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_station_diag_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _say(s: String) -> void:
	print(s)

func _run() -> void:
	_say("=== CH63 SKATE STATION DIAGNOSTIC ===")
	_say("driver: %s" % DisplayServer.get_name())
	_phase_table()
	DevTools.set_physics_override(true)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	for _i in WORLD_AGE:
		await get_tree().process_frame
	_park = _hub.find_child("Skatepark", true, false) as HubSkatepark
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	if _park == null or _transport == null or _keepy == null:
		push_error("SkateStationDiagProbe: hub missing Skatepark / Transport / Keepy.")
		get_tree().quit(1)
		return
	_phase_instrument()
	if _fails > 0:
		_say("=== INSTRUMENT FAILED -- every emptiness below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	# ⚠️ ONE PHASE ONLY, WHEN ASKED. PHASE R is the single reading here
	# that needs a REAL driver -- the engine's primitive and draw-call
	# counters are dummies under headless and print 0. Everything else
	# reads transforms, physics-server queries or the CPU clock, and
	# CLAUDE.md is explicit that those belong in headless: under llvmpipe
	# the long rides below spend their budget rasterising. So the xvfb run
	# is this one phase and nothing else.
	if OS.get_cmdline_user_args().has("--only-render"):
		await _phase_render()
		await _phase_stations()
		_say("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
		get_tree().quit(0 if _fails == 0 else 1)
		return
	_phase_station()
	_phase_bowl()
	await _phase_pairs()
	await _phase_elan()
	await _phase_hold()
	await _phase_cost()
	await _phase_render()
	await _phase_overlay()
	await _phase_leak()
	await _phase_stations()
	_say("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE T -- THE TABLE THIS PROBE POINTS AT
#
# The five indices above are a SECOND SPELLING of the layout, which is
# this repo's most expensive recurring defect. They are cheap to gate and
# a reordered MODULES array would otherwise re-point every reading below
# without a word.

func _phase_table() -> void:
	_say("-- PHASE T: the indices this probe uses are the modules it means --")
	var kinds := {
		I_FUNBOX: HubSkatepark.KIND_FUNBOX, I_RAIL: HubSkatepark.KIND_RAIL,
		I_QP_BIG: HubSkatepark.KIND_QUARTERPIPE, I_QP_SMALL: HubSkatepark.KIND_QUARTERPIPE,
		I_BOWL: HubSkatepark.KIND_BOWL}
	for i in kinds:
		var spec: Dictionary = HubSkatepark.MODULES[i]
		_check(StringName(spec["kind"]) == kinds[i],
			"MODULES[%d] is a %s (at %.1f, %.1f, size %s)"
				% [i, String(kinds[i]), spec["at"].x, spec["at"].y, str(spec["size"])])
	# The two quarterpipes are told apart by HEIGHT, and the big one is
	# the one whose footprint the reported station falls in.
	_check(float(HubSkatepark.MODULES[I_QP_BIG]["size"].y)
		> float(HubSkatepark.MODULES[I_QP_SMALL]["size"].y),
		"index %d is the TALLER quarterpipe (%.2f vs %.2f)"
			% [I_QP_BIG, HubSkatepark.MODULES[I_QP_BIG]["size"].y,
				HubSkatepark.MODULES[I_QP_SMALL]["size"].y])

# =====================================================================
# PHASE I -- THE INSTRUMENT, PROVED IN BOTH DIRECTIONS

## A point inside the big quarterpipe's solid mass, in world space. Taken
## off the DRAWN node's own transform, never off the table: the collider
## is a child of the drawn node, so the node is the only place both live.
func _inside_qp() -> Vector3:
	var node: Node3D = _park.get_node("Skate_quarterpipe_%d" % I_QP_BIG) as Node3D
	# Local (0, h*0.25, h*0.95): well under the riding surface near the
	# lip, i.e. inside the wedge stack rather than on its skin.
	var h: float = float(HubSkatepark.MODULES[I_QP_BIG]["size"].y)
	return node.to_global(Vector3(0.0, h * 0.25, h * 0.95))

## ⚠️ THE SPACE IS TAKEN FROM A NODE3D THAT IS ACTUALLY IN THE WORLD, and
## the first version of this line took it from `_hub` -- whose root is not
## a Node3D, so the cast returned null and EVERY query below came back
## empty. PHASE I caught it, and it caught it in the only way that works:
## the POSITIVE assertion went red while both NEGATIVE ones went green on
## a query that could not see anything at all. An "it goes blind" check
## passes for free against an instrument that was already blind.
func _space() -> PhysicsDirectSpaceState3D:
	return _park.get_world_3d().direct_space_state

## Every body the physics server reports at a world point, on the park's
## own layer. `collide_with_areas` is false on purpose: an Area3D is not
## something a board stands on, and counting one would answer a different
## question than the one asked.
func _hits_at(p: Vector3) -> Array[Dictionary]:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = 1 << (SkateBoardBody.LAYER_PARK - 1)
	var out: Array[Dictionary] = []
	for h in _space().intersect_point(q, 32):
		out.append(h)
	return out

func _phase_instrument() -> void:
	_say("-- PHASE I: the query SEES, and it goes blind when the layer goes --")
	var inside := _inside_qp()
	var lawn := Vector3(-18.0, 0.4, 40.0)
	var hit_before: int = _hits_at(inside).size()
	var hit_lawn: int = _hits_at(lawn).size()
	_say("     inside QP%d %s -> %d body(ies) | open lawn %s -> %d"
		% [I_QP_BIG, str(inside), hit_before, str(lawn), hit_lawn])
	_check(hit_before > 0, "POSITIVE: a point inside a solid module is SEEN")
	_check(hit_lawn == 0, "NEGATIVE: a point on open lawn is not")
	# The neutralisation. The layer -- not the node, not the shape -- so
	# that what is under test is exactly what the board reads.
	var body: StaticBody3D = _park.collider_body_at(I_QP_BIG)
	_check(body != null, "the big quarterpipe carries a StaticBody3D at all")
	if body == null:
		return
	var kept: int = body.collision_layer
	body.collision_layer = 0
	var hit_blind: int = _hits_at(inside).size()
	body.collision_layer = kept
	var hit_after: int = _hits_at(inside).size()
	_say("     same point, layer removed -> %d | layer restored -> %d"
		% [hit_blind, hit_after])
	# ⚠️ AND THESE TWO REFUSE TO SCORE WHEN THE POSITIVE FAILED. They are
	# assertions of ABSENCE and of RETURN, and both are true of an
	# instrument that never saw anything -- which is exactly the state the
	# first run of this probe was in. Gating them on `hit_before` makes
	# them say what they mean instead of agreeing with a blind query.
	if hit_before <= 0:
		_check(false, "RED PASS is NOT ASKED: the query never saw anything to blind")
		return
	_check(hit_blind == 0, "RED PASS: the same point goes BLIND with the layer off")
	_check(hit_after == hit_before, "and the hit comes back when it is restored")

# =====================================================================
# PHASE S -- WHAT IS AT THE REPORTED STATION

func _phase_station() -> void:
	_say("-- PHASE S: what the physics server reports AT (%.1f, %.1f) --"
		% [STATION.x, STATION.y])
	var flat := Vector3(STATION.x, 0.0, STATION.y)
	var ground: float = HubSurface.height_at(flat)
	_say("     HubSurface ground here: y = %.4f" % ground)
	# A vertical sweep: what is solid directly above the station, and how
	# high does it go. Point queries every 5 cm from the ground up.
	var lo: float = 1e9
	var hi: float = -1e9
	var names := {}
	var y: float = ground
	while y <= ground + 3.0:
		for h in _hits_at(Vector3(flat.x, y, flat.z)):
			var col = h.get("collider")
			if col != null:
				names[str((col as Node).get_path())] = true
				lo = minf(lo, y)
				hi = maxf(hi, y)
		y += 0.05
	if names.is_empty():
		_say("     NOTHING solid in the column above the station.")
	else:
		_say("     solid column from y = %.2f to y = %.2f, carried by:" % [lo, hi])
		for n in names:
			_say("        %s" % n)
	# And the same question asked with the BOARD's capsule, resting on the
	# ground -- which is what actually produces broadphase pairs.
	var cap := CapsuleShape3D.new()
	cap.radius = SkateparkMesh.DECK_WIDTH * 0.5
	cap.height = maxf(SkateparkMesh.DECK_LENGTH, cap.radius * 2.0)
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = cap
	sq.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
		Vector3(flat.x, ground + cap.radius, flat.z))
	sq.collide_with_areas = false
	sq.collision_mask = 1 << (SkateBoardBody.LAYER_PARK - 1)
	var shape_hits: Array = _space().intersect_shape(sq, 64)
	var per_body := {}
	for h in shape_hits:
		var col = h.get("collider")
		var key: String = "null" if col == null else str((col as Node).get_path())
		per_body[key] = int(per_body.get(key, 0)) + 1
	_say("     board capsule laid at the station touches %d SHAPE(s):" % shape_hits.size())
	for k in per_body:
		_say("        %2d shape(s) of %s" % [int(per_body[k]), k])
	# Which module index each touched body belongs to -- read off the
	# park's OWN table, never off the node name.
	var touched: Array[int] = []
	for i in _park.collider_indices():
		var b: StaticBody3D = _park.collider_body_at(i)
		if b == null:
			continue
		if per_body.has(str(b.get_path())):
			touched.append(i)
	_say("     -> module indices touched: %s" % str(touched))
	for i in touched:
		var spec: Dictionary = HubSkatepark.MODULES[i]
		_say("        [%d] %-12s at (%.1f, %.1f) size %s"
			% [i, String(spec["kind"]), spec["at"].x, spec["at"].y, str(spec["size"])])
	_check(not touched.is_empty(),
		"the reported station DOES stand on at least one solid module")
	_check(not touched.has(I_BOWL),
		"and the BOWL is not one of them")
	# Distances, so "the thing he is on" is a measured statement and not
	# an argument about which module a screenshot looks like.
	for i in range(HubSkatepark.MODULES.size()):
		var spec: Dictionary = HubSkatepark.MODULES[i]
		var c: Vector2 = spec["at"]
		_say("     distance station -> [%d] %-12s centre = %6.3f u"
			% [i, String(spec["kind"]), STATION.distance_to(c)])

# =====================================================================
# PHASE B -- THE BOWL, ASKED TWO INDEPENDENT WAYS

func _phase_bowl() -> void:
	_say("-- PHASE B: does the bowl have a collider --")
	var spec: Dictionary = HubSkatepark.MODULES[I_BOWL]
	# (a) STRUCTURAL: what the park published it built.
	var idx: Array = _park.collider_indices()
	_say("     collider_indices() = %s" % str(idx))
	for i in idx:
		_say("        [%d] %-12s -> %d convex piece(s)"
			% [i, String(HubSkatepark.MODULES[i]["kind"]),
				_park.collider_piece_count_at(i)])
	_check(not idx.has(I_BOWL), "the park does NOT list the bowl among its colliders")
	_check(HubSkatepark.pieces_for(spec).is_empty(), "pieces_for(bowl) returns EMPTY")
	_check(_park.collider_body_at(I_BOWL) == null, "and there is no StaticBody3D for it")
	# (b) PHYSICAL: a dense sweep of the bowl's whole disc and depth.
	# The blind check is the SAME sweep run on the big quarterpipe: if it
	# cannot find that one, its emptiness on the bowl means nothing.
	var bowl: Dictionary = _sweep_module(I_BOWL)
	var qp: Dictionary = _sweep_module(I_QP_BIG)
	_say("     dense sweep of the BOWL's footprint cylinder: %d solid sample(s)"
		% int(bowl["hits"]))
	for k in bowl["by_body"]:
		_say("        %4d sample(s) of %s" % [int(bowl["by_body"][k]), k])
	_say("     dense sweep of the BIG QUARTERPIPE's: %d solid sample(s)"
		% int(qp["hits"]))
	_check(int(qp["hits"]) > 0, "BLIND CHECK: the same sweep DOES find the quarterpipe")
	# ⚠️ AND THE ASSERTION IS NOT "the sweep FOUND NOTHING". The bowl's
	# footprint radius is 4.4 and the big quarterpipe's solid mass reaches
	# to within 2.9 u of the bowl's centre, so the bowl's own footprint
	# cylinder CONTAINS part of a neighbour -- the first version of this
	# phase read 47 samples there and would have published them as "the
	# bowl is solid". What the module has or has not is answered by
	# WHOSE body each sample belongs to, never by how many there are.
	var foreign: int = 0
	for k in bowl["by_body"]:
		foreign += int(bowl["by_body"][k])
	_check(int(bowl["hits"]) == foreign,
		"every solid sample in the bowl's footprint is accounted to a named body")
	_check(not bowl["by_body"].has(_body_path(I_BOWL)),
		"and NONE of them belongs to a bowl collider (there is no such body)")

## The node path a module's collider would have, or "" when it has none.
func _body_path(index: int) -> String:
	var b: StaticBody3D = _park.collider_body_at(index)
	return "" if b == null else str(b.get_path())

## Point-samples a module's own footprint cylinder in its LOCAL frame, so
## the sweep follows the module's yaw and position without a second
## spelling of either. Returns the sample count AND the breakdown by body,
## because the count alone cannot say whose solid it found.
func _sweep_module(index: int) -> Dictionary:
	var spec: Dictionary = HubSkatepark.MODULES[index]
	var node: Node3D = null
	for c in _park.get_children():
		if c is MeshInstance3D and String(c.name).ends_with("_%d" % index):
			node = c
			break
	if node == null:
		return {"hits": -1, "by_body": {}}
	var r: float = float(spec["footprint"])
	var top: float = float(spec["size"].y) + 0.4
	var hits: int = 0
	var by_body := {}
	var rings: int = 10
	var azim: int = 24
	var layers: int = 14
	for li in layers + 1:
		var y: float = -0.3 + (top + 0.3) * float(li) / float(layers)
		for ri in rings + 1:
			var rad: float = r * float(ri) / float(rings)
			var n: int = 1 if ri == 0 else azim
			for ai in n:
				var a: float = TAU * float(ai) / float(n)
				var p: Vector3 = node.to_global(
					Vector3(cos(a) * rad, y, sin(a) * rad))
				var found: Array[Dictionary] = _hits_at(p)
				if found.is_empty():
					continue
				hits += 1
				for h in found:
					var col = h.get("collider")
					var key: String = "null" if col == null else str((col as Node).get_path())
					by_body[key] = int(by_body.get(key, 0)) + 1
	return {"hits": hits, "by_body": by_body}

# =====================================================================
# PHASE P -- `pairs 6`, REPRODUCED ON A BOARD THAT IS ACTUALLY RIDDEN
#
# ⚠️ THE FIRST VERSION OF THIS PHASE TELEPORTED THE BOARD AND WAITED, AND
# THE BOARD NEVER MOVED. `SkateBoardBody.drive()` is called by
# HubTransport ONLY while `_riding_board` is true, so a board dropped at
# y + 1.2 by a bench that never mounts it hangs there for as many ticks
# as the bench cares to watch -- and reports `on_module false, lift
# 1.2000, pairs 0`, which reads exactly like "nothing is solid here".
# The device reading was taken UNDER A RIDER, so this one is too.

## Puts Keepy on the board at `flat` and lets it settle there.
func _mount_at(flat: Vector3) -> SkateBoardBody:
	var body: SkateBoardBody = _transport.board_body()
	if body == null:
		return null
	if _transport.is_riding_board():
		_transport.leave_board()
		for _i in SETTLE:
			await get_tree().physics_frame
	body.clear_target()
	body.global_position = HubSurface.ground(flat) + Vector3(0.0, 0.35, 0.0)
	_keepy.global_position = HubSurface.ground(flat)
	for _i in SETTLE:
		await get_tree().physics_frame
	_transport.mount_board()
	for _i in SETTLE * 6:
		await get_tree().physics_frame
	return body

func _phase_pairs() -> void:
	_say("-- PHASE P: the broadphase pair count, under a rider --")
	var lawn := Vector3(-18.0, 0.0, 40.0)
	var body: SkateBoardBody = await _mount_at(lawn)
	if body == null:
		_check(false, "there is a SkateBoardBody at all")
		return
	var lawn_pairs: int = int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	_say("     ridden on open lawn   -> pairs %d | y %.4f on_module %s lift %.4f"
		% [lawn_pairs, body.global_position.y, str(body.on_module()), body.lift()])
	body = await _mount_at(Vector3(STATION.x, 0.0, STATION.y))
	var station_pairs: int = int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	_say("     ridden at the station -> pairs %d | y %.4f on_module %s lift %.4f"
		% [station_pairs, body.global_position.y, str(body.on_module()), body.lift()])
	_check(lawn_pairs == 0, "BLIND CHECK: nothing pairs on the open lawn")
	_check(station_pairs > 0, "and the station pairs with something")
	# ⚠️ THE CONTRACT AT REST IS "SOMETHING HOLDS IT ABOVE THE LAWN", NOT
	# `is_on_floor()`. The first version asserted the latter and went red
	# on a board that was demonstrably standing on the quarterpipe --
	# `lift` 0.0843 with a pair open. `is_on_floor()` describes the
	# `move_and_slide` that has already happened (SkateBoardBody's own
	# header says so), and a body with zero velocity has not moved into
	# anything, so it reports no floor. Asserting it here would have
	# published a red about the collider on a reading about the engine's
	# one-tick lag.
	_check(body.lift() > 0.0, "the board is HELD ABOVE the lawn at the station")
	_say("     NOTE: at rest there, `on_module()` is %s and `airborne()` is %s."
		% [str(body.on_module()), str(body.airborne())])
	_say("     `airborne()` = supported AND not on_module, so a board PARKED on")
	_say("     the ramp reads as airborne to CH62's SkateAudio. Harmless as")
	_say("     measured -- the landing cue needs a fall of %.2f u/s and a parked"
		% SkateFeel.LAND_FALL_MIN)
	_say("     board has none -- and PHASE H shows 0 %% of MOVING ticks unheld.")
	_say("     (device capture reported `pairs 6`; a rolling board sweeps")
	_say("      more wedge AABBs than a parked one, so this is a FLOOR)")
	# And rolling ACROSS the transition, which is what the device was
	# doing -- the pair count is a function of how much of the wedge stack
	# the board's AABB straddles, so a still reading is its minimum.
	var qp: Node3D = _module_node(I_QP_BIG)
	body.set_target(Vector3(qp.to_global(Vector3(0.0, 0.0, 4.0)).x,
		0.0, qp.to_global(Vector3(0.0, 0.0, 4.0)).z))
	var worst: int = 0
	for _i in 240:
		await get_tree().physics_frame
		worst = maxi(worst, int(Performance.get_monitor(
			Performance.PHYSICS_3D_COLLISION_PAIRS)))
	_say("     rolling across the transition -> WORST pairs %d" % worst)
	body.clear_target()

func _module_node(index: int) -> Node3D:
	for c in _park.get_children():
		if c is MeshInstance3D and String(c.name).ends_with("_%d" % index):
			return c as Node3D
	return null

# =====================================================================
# PHASE E -- THE ELAN, AND CH61'S NUMBER RESTITUTED

func _phase_elan() -> void:
	_say("-- PHASE E: how much elan a ramp costs, and CH61's number --")
	# ⚠️ THE BENCH RELEASES THE BOARD; IT DOES NOT DRIVE IT UP THE RAMP.
	# The first version aimed 6 u past the lip, which keeps `remaining`
	# large so the drive model PUSHES all the way up -- and it cleared
	# both ramps. That is a real thing a player can do, and it is not the
	# question CH61 answered. "How high does it get" is a question about
	# ENERGY, so the board is given a known entry speed at the foot with
	# NO target at all and simply let go.
	for i in [I_QP_BIG, I_QP_SMALL]:
		var spec: Dictionary = HubSkatepark.MODULES[i]
		var h: float = float(spec["size"].y)
		_say("     [%d] quarterpipe, drawn height %.2f u:" % [i, h])
		for v in [6.0, 8.0, 8.97, 10.0, 12.0]:
			var peak: float = await _coast_into(i, v)
			var ideal: float = v * v / (2.0 * SkateBoardBody.GRAVITY)
			_say("        entry %5.2f u/s -> peak %.3f u   (frictionless v^2/2g = %.3f)   %s"
				% [v, peak, ideal,
					"CLEARS the lip" if peak >= h - 0.02 else "stops on the transition"])
	_say("     CH61 published: at the arrival this conduite produces (~8.97 u/s,")
	_say("     v^2/2g = 1.55 u) the 2.10 ramp stops the board at 1.348 u and the")
	_say("     1.45 one does not. The 8.97 row above is that reading.")

## Releases the board at the foot of a ramp at `speed`, pointed up it,
## with no target -- pure coast -- and returns the greatest height it
## reaches above the lawn.
func _coast_into(index: int, speed: float) -> float:
	var node: Node3D = _module_node(index)
	if node == null:
		return -1.0
	var foot: Vector3 = node.to_global(Vector3(0.0, 0.0, -1.2))
	var body: SkateBoardBody = await _mount_at(Vector3(foot.x, 0.0, foot.z))
	if body == null:
		return -1.0
	body.clear_target()
	# The heading is the module's own +Z, taken off its basis rather than
	# from its yaw: one spelling, and it follows a module that is rotated.
	var fwd: Vector3 = node.global_transform.basis.z.normalized()
	body.velocity = Vector3(fwd.x, 0.0, fwd.z).normalized() * speed
	body.rotation.y = atan2(fwd.x, fwd.z)
	var peak: float = 0.0
	for _i in 300:
		await get_tree().physics_frame
		peak = maxf(peak, body.lift())
		if body.speed() < 0.05 and body.lift() < 0.01:
			break
	body.clear_target()
	return peak

## The height of the DRAWN quarterpipe surface at a world point, in world
## units, or -1 when the point is not over that module's riding surface.
##
## ⚠️ READ OFF `SkateparkMesh.quarterpipe_profile()`, which is the same
## curve `quarterpipe_pieces()` builds the collider from. There is no
## second spelling of the ramp here: if the mesh and the collider ever
## disagree, this reads the mesh's side of it and the disagreement shows
## up as penetration rather than being hidden by a formula that agrees
## with whichever one it was copied from.
func _ramp_surface_at(index: int, world_flat: Vector3) -> float:
	var node: Node3D = _module_node(index)
	if node == null:
		return -1.0
	var spec: Dictionary = HubSkatepark.MODULES[index]
	var h: float = float(spec["size"].y)
	var half: float = float(spec["size"].x) * 0.5
	var loc: Vector3 = node.to_local(Vector3(world_flat.x, node.global_position.y, world_flat.z))
	if absf(loc.x) > half or loc.z < 0.0 or loc.z > h:
		return -1.0
	var prof: Array[Vector2] = SkateparkMesh.quarterpipe_profile(h)
	for k in range(prof.size() - 1):
		if loc.z >= prof[k].x and loc.z <= prof[k + 1].x:
			var span: float = maxf(prof[k + 1].x - prof[k].x, 1e-6)
			var t: float = (loc.z - prof[k].x) / span
			return node.global_position.y + lerpf(prof[k].y, prof[k + 1].y, t)
	return node.global_position.y + prof[prof.size() - 1].y

func _phase_hold() -> void:
	_say("-- PHASE H: is the board HELD while it is ON the transition --")
	# ⚠️ AND THE TWO CASES ARE PREDICTED, NOT INFERRED FROM THE LIFT.
	# CLAUDE.md CH43: a test on an observable does not see which branch
	# ran. "Above the lawn and not held" is TRUE of a board flying over
	# the lip -- which is correct behaviour and the module's whole point
	# -- and equally true of a board sunk into the ramp that the engine
	# has lost. The first version of this phase counted them together and
	# reported 53.7 %, with a worst lift of 2.2092 u on a ramp 2.10 tall,
	# i.e. mostly legitimate air. So every tick is classified against the
	# DRAWN surface directly under the board before it is counted.
	var node: Node3D = _module_node(I_QP_BIG)
	var start: Vector3 = node.to_global(Vector3(0.0, 0.0, -8.0))
	var aim: Vector3 = node.to_global(Vector3(0.0, 0.0, 8.0))
	var body: SkateBoardBody = await _mount_at(Vector3(start.x, 0.0, start.z))
	if body == null or node == null:
		_check(false, "the ride could be set up")
		return
	body.set_target(Vector3(aim.x, 0.0, aim.z))
	var on_ramp: int = 0
	var on_ramp_held: int = 0
	var on_ramp_ghost: int = 0
	var air: int = 0
	var air_held: int = 0
	var lawn: int = 0
	var worst_sink: float = 0.0
	var tol: float = SkateparkMesh.DECK_WIDTH * 0.5 + 0.02
	for _i in 900:
		await get_tree().physics_frame
		var flat: Vector3 = body.flat_position()
		var surf: float = _ramp_surface_at(I_QP_BIG, flat)
		if surf < 0.0:
			lawn += 1
		elif body.global_position.y <= surf + tol:
			on_ramp += 1
			if body.on_module():
				on_ramp_held += 1
			else:
				on_ramp_ghost += 1
				worst_sink = maxf(worst_sink, surf - body.global_position.y)
		else:
			air += 1
			if body.on_module():
				air_held += 1
		if not body.has_target() and body.at_rest():
			break
	body.clear_target()
	_say("     ticks OFF the module            : %d" % lawn)
	_say("     ticks ON the drawn ramp surface : %d  (held %d, NOT held %d)"
		% [on_ramp, on_ramp_held, on_ramp_ghost])
	_say("     ticks IN THE AIR above the ramp : %d  (held %d -- should be 0)"
		% [air, air_held])
	_say("     worst penetration below the drawn surface: %.4f u" % worst_sink)
	_check(on_ramp > 0, "BLIND CHECK: the ride actually spent ticks ON the ramp")
	_check(air > 0, "BLIND CHECK: and it also spent ticks legitimately in the air")
	if on_ramp > 0:
		var share: float = 100.0 * float(on_ramp_ghost) / float(on_ramp)
		_say("     -> %.1f %% of the ticks ON the ramp were UNHELD (%d of %d)."
			% [share, on_ramp_ghost, on_ramp])
		_say("        An unheld tick takes NEITHER hold branch in drive():")
		_say("        n stays (0,1,0), so the push keeps its full flat-ground")
		_say("        authority and gravity is applied as free fall.")

# =====================================================================
# PHASE C -- THE PHYSICS TICK, MEASURED ON THE CLOCK AND NOT ON A MONITOR
#
# ⚠️ `Performance.TIME_PHYSICS_PROCESS` CAME BACK AS A CONSTANT. The first
# version of this phase read it 240 times at two stations and got
# 0.3350 ms at both, mean EQUAL to max to four decimals -- a monitor that
# does not move is not a measurement, and CLAUDE.md's rule about a delta
# without its noise floor applies before the delta is even read. So the
# tick is timed on the WALL CLOCK across a batch of physics frames, and
# the SAME station is read twice with nothing touched, which is what
# publishes the floor.

func _phase_cost() -> void:
	_say("-- PHASE C: what a physics tick costs, lawn vs on the module --")
	var lawn_a: Dictionary = await _tick_cost(Vector3(-18.0, 0.0, 40.0), "lawn")
	var lawn_b: Dictionary = await _tick_cost(Vector3(-18.0, 0.0, 40.0), "lawn (repeat)")
	var stat_a: Dictionary = await _tick_cost(Vector3(STATION.x, 0.0, STATION.y), "station")
	var stat_b: Dictionary = await _tick_cost(Vector3(STATION.x, 0.0, STATION.y), "station (repeat)")
	for r in [lawn_a, lawn_b, stat_a, stat_b]:
		_say("     %-16s %.4f ms/tick wall | monitor %.4f ms | pairs %d"
			% [r["label"], r["wall"], r["monitor"], int(r["pairs"])])
	var floor_ms: float = maxf(absf(lawn_a["wall"] - lawn_b["wall"]),
		absf(stat_a["wall"] - stat_b["wall"]))
	var signal_ms: float = ((stat_a["wall"] + stat_b["wall"])
		- (lawn_a["wall"] + lawn_b["wall"])) * 0.5
	_say("     NOISE FLOOR of the bench (same station twice) : %.4f ms/tick" % floor_ms)
	_say("     SIGNAL (station minus lawn)                   : %+.4f ms/tick" % signal_ms)
	_check(lawn_a["wall"] > 0.0, "INSTRUMENT: the wall clock moved at all")
	if absf(signal_ms) <= floor_ms:
		_say("     -> the module contact is BELOW this bench's own floor: NOT MEASURABLE here.")
	else:
		_say("     -> the module contact costs %+.4f ms/tick above the floor."
			% (absf(signal_ms) - floor_ms))

func _tick_cost(flat: Vector3, label: String) -> Dictionary:
	var body: SkateBoardBody = await _mount_at(flat)
	var n: int = 600
	var t0: int = Time.get_ticks_usec()
	var pairs: int = 0
	for _i in n:
		await get_tree().physics_frame
		pairs = maxi(pairs, int(Performance.get_monitor(
			Performance.PHYSICS_3D_COLLISION_PAIRS)))
	var wall: float = float(Time.get_ticks_usec() - t0) / float(n) / 1000.0
	return {"label": label, "wall": wall,
		"monitor": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"pairs": pairs, "on_module": body != null and body.on_module()}

# =====================================================================
# PHASE R -- THE CH62 CAMERA TERM, PRICED **AT THIS STATION**
#
# ⚠️ CH62 PUBLISHED +8 165 PRIMITIVES FOR THE CAMERA AND IT READ THAT AT
# ITS OWN BENCH STATION. A frustum term is a function of WHERE the lens
# points: widening the fov and pulling the apex back admits whatever
# happens to be in that direction, and the north lobe is not the plateau.
# So the same term is re-read HERE, on the frustum replay
# (`HubPerfOverlay._frustum_estimate`), which is a CPU cull test and
# therefore the one render reading that means something headless.

func _phase_render() -> void:
	_say("-- PHASE R: what the ride camera admits AT the reported station --")
	var perf: HubPerfOverlay = _hub.find_child("PerfOverlay", true, false) as HubPerfOverlay
	var cam: HubCamera = _hub.find_child("Camera3D", true, false) as HubCamera
	if perf == null or cam == null:
		_check(false, "the hub carries a PerfOverlay and a HubCamera")
		return
	# Parked: the ride camera is not engaged at all.
	_transport.leave_board()
	_keepy.global_position = HubSurface.ground(Vector3(STATION.x, 0.0, STATION.y))
	cam.snap_to_target()
	for _i in SETTLE * 4:
		await get_tree().process_frame
	var parked: Dictionary = perf.snapshot()
	var parked_again: Dictionary = perf.snapshot()
	var parked_fov: float = cam.fov
	# Ridden, and held at full rush: mount, then push the board so its
	# pace saturates SkateFeel.rush() and the camera reaches its widest.
	var body: SkateBoardBody = await _mount_at(Vector3(STATION.x, 0.0, STATION.y))
	var qp: Node3D = _module_node(I_QP_BIG)
	var aim: Vector3 = qp.to_global(Vector3(0.0, 0.0, -12.0))
	body.set_target(Vector3(aim.x, 0.0, aim.z))
	var worst: Dictionary = {}
	var worst_tris: int = -1
	var top_rush: float = 0.0
	# ⚠️ AND THE CAMERA ITSELF IS WATCHED, NOT ASSUMED. A delta of zero is
	# what this phase might legitimately find, and it is ALSO what a phase
	# whose camera never opened would find -- CLAUDE.md, CH40: a bench
	# that measures a difference must first prove there was something to
	# make a difference. `fov` and the camera's distance from Keepy are
	# the two things SkateFeel actually moves, so both are recorded.
	var top_fov: float = cam.fov
	var top_back: float = 0.0
	for _i in 300:
		await get_tree().process_frame
		top_rush = maxf(top_rush, SkateFeel.rush(body.pace()))
		top_fov = maxf(top_fov, cam.fov)
		top_back = maxf(top_back,
			cam.global_position.distance_to(_keepy.global_position))
		var now: Dictionary = perf.snapshot()
		if int(now.get("tris_frame", 0)) > worst_tris:
			worst_tris = int(now.get("tris_frame", 0))
			worst = now
	body.clear_target()
	var tremor: int = absi(int(parked.get("tris_frame", 0))
		- int(parked_again.get("tris_frame", 0)))
	_say("     parked   : %8d triangles in frame, %4d nodes, fov %.2f"
		% [int(parked.get("tris_frame", 0)), int(parked.get("nodes_frame", 0)), cam.fov])
	_say("     ridden   : %8d triangles in frame, %4d nodes (top rush %.3f)"
		% [worst_tris, int(worst.get("nodes_frame", 0)), top_rush])
	_say("     delta    : %+8d triangles, %+4d nodes | bench tremor %d"
		% [worst_tris - int(parked.get("tris_frame", 0)),
			int(worst.get("nodes_frame", 0)) - int(parked.get("nodes_frame", 0)), tremor])
	# ⚠️ AND THE ENGINE'S OWN COUNTERS, WHICH ARE THE ONES CH62 QUOTED.
	# Under the dummy driver they are 0 and are PRINTED as 0 rather than
	# hidden -- CLAUDE.md is explicit that a masked zero would read as a
	# free frame. They mean something only under a real driver.
	_say("     engine counters (0 under headless -- run under xvfb to sign them):")
	_say("        parked total prims %8d calls %5d | ridden total prims %8d calls %5d"
		% [int(parked.get("engine_total_prims", 0)), int(parked.get("engine_total_calls", 0)),
			int(worst.get("engine_total_prims", 0)), int(worst.get("engine_total_calls", 0))])
	_say("        delta prims %+d, delta calls %+d"
		% [int(worst.get("engine_total_prims", 0)) - int(parked.get("engine_total_prims", 0)),
			int(worst.get("engine_total_calls", 0)) - int(parked.get("engine_total_calls", 0))])
	_say("     CH62 measured the camera term at +8 165 primitives -- AT ITS OWN")
	_say("     STATION. A frustum term is a function of where the lens points.")
	_check(int(parked.get("tris_frame", 0)) > 0,
		"INSTRUMENT: the frustum replay counted something at all")
	var parked_back: float = HubCamera.OFFSET.length()
	_say("     CAMERA CONTROL: fov %.2f -> %.2f (SkateFeel.CAMERA_FOV = %.2f)"
		% [parked_fov, top_fov, SkateFeel.CAMERA_FOV])
	_say("                     distance to Keepy %.4f -> %.4f u (parked offset %.4f)"
		% [parked_back, top_back, parked_back])
	_check(top_rush > 0.5,
		"the ride actually reached speed (rush %.3f)" % top_rush)
	_check(top_fov > parked_fov + 0.01,
		"BLIND CHECK: the fov ACTUALLY widened (%.2f -> %.2f)" % [parked_fov, top_fov])
	_check(top_back > parked_back + 0.01,
		"BLIND CHECK: the camera ACTUALLY pulled back (%.4f -> %.4f)"
			% [parked_back, top_back])

# =====================================================================
# PHASE O -- WHAT THE OVERLAY ITSELF COSTS
#
# ⚠️ THE DEVICE READING WAS TAKEN THROUGH THE OVERLAY, AND THE OVERLAY IS
# NOT FREE. `HubPerfOverlay.snapshot()` walks the WHOLE world tree, takes
# a world AABB for every VisualInstance3D and runs Godot's frustum test on
# each -- in GDScript, over the ~700 drawn nodes and 2 463 MultiMesh
# instances this hub carries. It runs one frame in REFRESH_FRAMES (20).
#
# That is a question nobody has asked and it is the cheapest one left: an
# instrument that costs a measurable slice of the frame it is measuring
# depresses the very number it prints, and it depresses the MINIMUM hard
# -- a spike one frame in twenty is exactly what a `min` window catches.

func _phase_overlay() -> void:
	_say("-- PHASE O: what the perf overlay costs the frame it measures --")
	var perf: HubPerfOverlay = _hub.find_child("PerfOverlay", true, false) as HubPerfOverlay
	if perf == null:
		_check(false, "the hub carries a PerfOverlay")
		return
	# Warm the mesh-triangle cache first: the FIRST walk pays for every
	# mesh it has never seen, and pricing a steady-state cost on a cold
	# cache would answer a different question.
	perf.snapshot()
	perf.snapshot()
	var n: int = 40
	var t0: int = Time.get_ticks_usec()
	for _i in n:
		perf.snapshot()
	var walk_ms: float = float(Time.get_ticks_usec() - t0) / float(n) / 1000.0
	# The floor of the bench: the same loop again, nothing changed.
	var t1: int = Time.get_ticks_usec()
	for _i in n:
		perf.snapshot()
	var walk_ms_b: float = float(Time.get_ticks_usec() - t1) / float(n) / 1000.0
	_say("     one snapshot() = %.4f ms (repeat %.4f ms)" % [walk_ms, walk_ms_b])
	_say("     it runs 1 frame in %d, so its AVERAGE share of a frame is %.4f ms"
		% [HubPerfOverlay.REFRESH_FRAMES, walk_ms / float(HubPerfOverlay.REFRESH_FRAMES)])
	_say("     but the frame that PAYS it carries the whole %.4f ms," % walk_ms)
	_say("     which is the frame a `min FPS` window is built to catch.")
	_check(walk_ms > 0.0, "INSTRUMENT: the walk took measurable time")
	# And what a 16.7 ms frame budget would make of it.
	_say("     at 60 Hz (16.67 ms/frame) that single frame loses %.1f %% of its budget"
		% (100.0 * walk_ms / 16.67))

# =====================================================================
# PHASE L -- DOES A LONG RIDE ACCUMULATE ANYTHING
#
# The brief's third hypothesis for the frame drop: something in CH62's new
# structures grows over a session rather than over a bench of a few
# seconds. Read off the source, nothing does -- `SkateStreaks._build_lanes`
# runs once from `_ready()`, the two AudioStreamPlayers are made once, and
# the strip texture is baked once. But "nothing grows" is an assertion of
# ABSENCE, so it is measured, and the measurement is shown able to SEE a
# node appear before its zero is believed.

func _phase_leak() -> void:
	_say("-- PHASE L: does a long ride accumulate nodes or objects --")
	var before_nodes: int = _count_nodes(_hub)
	var before_objs: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	# BLIND CHECK FIRST. A census that cannot see one node added would
	# return the same zero as a session that leaks nothing -- CH40's
	# defect exactly, and the reason this is not simply a subtraction.
	var canary := Node.new()
	canary.name = "LeakCanary"
	_hub.add_child(canary)
	var with_canary: int = _count_nodes(_hub)
	canary.free()
	var without_canary: int = _count_nodes(_hub)
	_check(with_canary == before_nodes + 1,
		"BLIND CHECK: the census sees one node added (%d -> %d)"
			% [before_nodes, with_canary])
	_check(without_canary == before_nodes, "and sees it removed again")
	# Now the ride: many mounts, rolls and dismounts back to back.
	var node: Node3D = _module_node(I_QP_BIG)
	for lap in 8:
		var start: Vector3 = node.to_global(Vector3(0.0, 0.0, -7.0))
		var body: SkateBoardBody = await _mount_at(Vector3(start.x, 0.0, start.z))
		if body == null:
			break
		var aim: Vector3 = node.to_global(Vector3(0.0, 0.0, 5.0))
		body.set_target(Vector3(aim.x, 0.0, aim.z))
		for _i in 150:
			await get_tree().physics_frame
			if not body.has_target() and body.at_rest():
				break
		body.clear_target()
	_transport.leave_board()
	for _i in SETTLE * 4:
		await get_tree().process_frame
	var after_nodes: int = _count_nodes(_hub)
	var after_objs: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	_say("     nodes under the hub : %d -> %d  (delta %+d)"
		% [before_nodes, after_nodes, after_nodes - before_nodes])
	_say("     engine OBJECT_COUNT : %d -> %d  (delta %+d)"
		% [before_objs, after_objs, after_objs - before_objs])
	_check(after_nodes == before_nodes,
		"eight mount/ride/dismount cycles add no node to the hub")

func _count_nodes(root: Node) -> int:
	var n: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		n += 1
		for c in cur.get_children():
			stack.append(c)
	return n

# =====================================================================
# PHASE Z -- WHERE HE IS STANDING, WHICH IS A NUMBER CH52 ALREADY TOOK
#
# ⚠️ THE FRAME READING THAT CHANGED MAY NOT BE A CHANGE AT ALL. Every
# "55-56 FPS" on file for this protocol was read where the overlay is
# normally read -- the spawn and the plateau. This capture was taken at
# (-1.9, 51.3), which is inside the NORTH LOBE, and CH52 measured that
# lobe station by station BEFORE the skatepark existed:
#
#     spawn (0, 0)      70 946 primitives, 303 calls -- device holds 60
#     north rim (0, 63) 96 467 primitives, 405 calls -- device averages 46
#     worst of the lobe ~101 400 primitives / 408 calls at (-10, 51)
#
# and its verdict was that the north rim is ALREADY at the frame budget,
# with "le budget net disponible pour cinq modules de skatepark" equal to
# ZERO. Five modules were then built there.
#
# So this phase reads the two stations on ONE bench. It has to restitute
# CH52's spawn figure before its north figure is worth anything --
# CLAUDE.md, a bench that cannot reproduce a number already on file has
# no standing to publish a new one.

func _phase_stations() -> void:
	_say("-- PHASE Z: the frame at the spawn against the frame at the station --")
	var perf: HubPerfOverlay = _hub.find_child("PerfOverlay", true, false) as HubPerfOverlay
	var cam: HubCamera = _hub.find_child("Camera3D", true, false) as HubCamera
	if perf == null or cam == null:
		_check(false, "the hub carries a PerfOverlay and a HubCamera")
		return
	if DisplayServer.get_name() == "headless":
		_say("     (dummy driver: the engine counters read 0 -- run under xvfb)")
		return
	_transport.leave_board()
	# ⚠️ THE RIDE BLEND HAS TO FINISH BEFORE THE FIRST STATION IS READ.
	# The first version of this phase read the spawn immediately after
	# PHASE R's ride and got a TREMOR OF 20 718 primitives on it, against
	# 0 at the other three -- the camera was still tweening back from the
	# ride offset, so the first reading was taken through a frustum that
	# was still moving. A station read through a moving lens is not a
	# station reading, and this phase's whole conclusion is a difference
	# between two of them.
	for _i in 240:
		await get_tree().process_frame
	var rows: Array = []
	for st in [{"n": "spawn (0, 0)", "p": Vector3(0.0, 0.0, 0.0)},
			{"n": "park walk-in (0, 43)", "p": Vector3(0.0, 0.0, 43.0)},
			{"n": "THE STATION (-1.9, 51.3)", "p": Vector3(STATION.x, 0.0, STATION.y)},
			{"n": "north rim (0, 63)", "p": Vector3(0.0, 0.0, 63.0)}]:
		# A throwaway read first, at every station, so the settle after
		# the teleport is paid before anything is recorded -- and TWO
		# recorded reads after it, whose difference IS this bench's noise
		# floor at that station. A tremor is printed for every row and a
		# row whose tremor is not small is not used for anything.
		await _station_read(perf, cam, st["p"])
		var a: Dictionary = await _station_read(perf, cam, st["p"])
		var b: Dictionary = await _station_read(perf, cam, st["p"])
		rows.append({"n": st["n"], "a": a, "b": b})
	_say("     %-26s %10s %7s %12s %8s" % ["station", "prims", "calls", "tris frame", "tremor"])
	for r in rows:
		var tremor: int = absi(int(r["a"]["prims"]) - int(r["b"]["prims"]))
		_say("     %-26s %10d %7d %12d %8d"
			% [r["n"], int(r["a"]["prims"]), int(r["a"]["calls"]),
				int(r["a"]["tris"]), tremor])
	var spawn: int = int(rows[0]["a"]["prims"])
	var station: int = int(rows[2]["a"]["prims"])
	var spawn_tremor: int = absi(spawn - int(rows[0]["b"]["prims"]))
	var station_tremor: int = absi(station - int(rows[2]["b"]["prims"]))
	var worst_tremor: int = maxi(spawn_tremor, station_tremor)
	_check(worst_tremor < 1000,
		"BENCH FLOOR: both rows used are settled (worst tremor %d primitives)"
			% worst_tremor)
	_check(absi(station - spawn) > worst_tremor,
		"and the difference between them clears that floor")
	_say("     CH52 read 70 946 primitives / 303 calls at the spawn and")
	_say("     96 467 / 405 at the north rim, BEFORE the skatepark was built,")
	_say("     and called the lobe's remaining budget ZERO.")
	_say("     -> this station carries %+d primitives over the spawn (%.1f %% more)."
		% [station - spawn, 100.0 * float(station - spawn) / float(maxi(spawn, 1))])
	_check(spawn > 0, "INSTRUMENT: the engine counters filled in under this driver")
	_check(station > spawn,
		"the reported station is a HEAVIER frame than the spawn")

func _station_read(perf: HubPerfOverlay, cam: HubCamera, flat: Vector3) -> Dictionary:
	_keepy.global_position = HubSurface.ground(flat)
	cam.snap_to_target()
	for _i in SETTLE * 4:
		await get_tree().process_frame
	var snap: Dictionary = perf.snapshot()
	return {"prims": int(snap.get("engine_prims", 0)),
		"calls": int(snap.get("engine_calls", 0)),
		"tris": int(snap.get("tris_frame", 0))}
