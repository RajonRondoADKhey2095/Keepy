extends Node
## CH56 LOT 0 -- WHAT A PHYSICS TICK COSTS, MEASURED, WITH THE RIGHT TO
## SAY NO.
##
## =====================================================================
## WHY THIS FILE EXISTS
##
## CH55 designed a physics foundation for the hub and then refused to
## price it, in as many words: "AUCUNE MILLISECONDE N'A ETE MESUREE DANS
## CE LOT [...] Le tableau 4.3 est une echelle, pas une prediction."
## Its section 4.4 ends on the only honest conclusion available without a
## bench -- "ce n'est pas decidable sans une mesure, et cette mesure
## n'existe pas."
##
## This is that measurement. It measures nothing about gameplay: no
## module gets a collider, no scene is touched, no script of the game is
## read at runtime except SkateparkMesh, and only to get REAL geometry
## rather than a cube that would flatter every number below.
##
## AND IT IS ALLOWED TO CONCLUDE "NOT AFFORDABLE". That is why the gates
## below are gates on the INSTRUMENT and never on the answer: a probe
## whose red light means "the hub cannot have physics" would be a probe
## nobody could leave in the repository, and the number it defends would
## be a number calibrated on THIS sandbox's Xeon, which is not the
## number a phone would produce. What is permanent here is the bench;
## what is published is a CURVE, so that Mathieu's device reading can
## recalibrate it without re-running anything.
##
## =====================================================================
## WHY THE BENCH IS BARE, AND WHY THAT IS NOT A SHORTCUT
##
## CH55's lot 0 sketch said "dans le monde du hub". PHASE Z measures the
## room rather than asserting anything about it: it instantiates HubWorld,
## reads its frame cost under whichever driver is running, and prints the
## physics steps per frame that cost implies. On a software rasteriser
## that number is large, `max_physics_steps_per_frame = 8` is what would
## clamp it, and a millisecond measured in that room would be a
## millisecond of llvmpipe contention no phone will ever pay.
##
## So the curve is measured in an empty room, where the physics signal is
## the only signal, and the room's own cost is published as the intercept
## at N = 0 rather than subtracted silently.
##
## =====================================================================
## THE TWO CURVES, BECAUSE "N BODIES" IS TWO DIFFERENT QUESTIONS
##
## CURVE A -- N STATIC colliders in the world, ONE moving body. This is
## form B of CH55 section 2.2 exactly: the collider belongs to the
## carrier, the park is scenery that blocks. Its cost is broadphase plus
## whatever the one moving body sweeps against.
##
## CURVE B -- N MOVING bodies against a fixed environment. This is the
## question the brief actually asks in its point 6 ("combien de corps
## physiques simultanes"), and it is NOT curve A: a static shape is
## cheap to hold and a moving one is not.
##
## Both are swept over the same N in {0, 1, 6, 20, 100}, and curve A is
## swept over both collision shapes so that D5's arbitration (convex
## pieces, never a trimesh) carries a price tag even though it is already
## decided -- the number is what makes the decision re-openable.
##
## =====================================================================
## HOW THIS PROBE AVOIDS BEING THE NINETEENTH FALSE SIGNAL
##
## Three separate guards, because this repo has already paid for each of
## them being absent:
##
## 1. INSTRUMENT CONTROL (PHASE I). Before any millisecond is believed,
##    the bench reproduces a number already on file -- the skatepark's
##    triangle count -- with the same builders the game ships. CLAUDE.md:
##    "un banc incapable de restituer la diagonale a 66 hops n'a pas
##    qualite a publier un chiffre neuf."
##
## 2. THE WITNESS IS THE SERVER, NOT THE SCENE TREE (PHASE V and every
##    measured point). Counting nodes proves a probe built nodes. What
##    has to be proven is that the PHYSICS SERVER holds them, so every
##    body's RID is asked `body_get_space()` and `body_get_shape_count()`
##    directly, and a live `intersect_shape` is run beside it as a second
##    and independent channel. A bench that measured an engine holding
##    nothing would read exactly like a cheap engine.
##
## 3. THE BLIND CHECK IS ORDERED POSITIVE-FIRST (PHASE V). "Zero objects
##    at N = 0" passes for free against a counter wired to nothing, which
##    is why the void is read, then ONE body is added and the counter is
##    required to MOVE, then it is removed and the zero is read again.
##    The middle step is the only thing that makes either zero mean
##    anything.
##
## And the moving body is required to actually TOUCH something
## (`contact_ticks > 0` at every measured point): a capsule falling
## through empty air exercises no narrowphase at all and would publish a
## physics engine's cost without ever asking it to resolve a collision.
##
## =====================================================================
## THE NOISE FLOOR, PUBLISHED, BECAUSE A DELTA WITHOUT ONE IS NOT A
## MEASUREMENT
##
## CLAUDE.md (CH40, CH41): a delta below the bench's own tremble is not a
## result. Every point of every curve is measured REPEATS times from a
## fresh build, and the spread of those repeats IS the floor for that
## point. A second, independent floor comes from splitting each single
## measurement window in half and comparing the halves -- that one
## catches drift inside a run, which repeat-to-repeat spread cannot see.
##
## =====================================================================
## WHY IT RUNS UNDER xvfb + opengl3
##
## The brief's instruction, and it is the right one even though physics
## is pure CPU and CLAUDE.md would send a transforms-only probe to
## --headless. The reason is not the pixels: it is that a bench measuring
## "the cost of physics inside a frame" should be measuring inside a
## frame that a renderer is also drawing, because that is the frame the
## phone has. The run script drives it under BOTH drivers and the report
## publishes both readings; if they agree, the number is robust to the
## room, and if they do not, the difference is itself the answer to how
## much the renderer steals.
##
## Nothing here reads a pixel, so nothing here can be broken by the dummy
## driver -- which is why running it headless as a second reading is
## safe, and why that second reading is a control rather than a shortcut.

# =====================================================================
# THE SWEEP

## The N of both curves. 0 is the intercept (the room's own cost), 1 is
## one carrier, 6 is the realistic shape of form B (five modules plus the
## board), 20 is CH55 section 1.6's census of everything that moves in
## this hub today, and 100 is deliberately past anything anyone has
## proposed -- a curve that stops at the plausible cannot show where it
## stops being plausible.
const SWEEP: PackedInt32Array = [0, 1, 6, 20, 100]

## Physics ticks measured per repeat, after the warm-up. Ten simulated
## seconds at 60 Hz. The first version used 240 and the repeat-to-repeat
## spread on the wall clock came back at ~20 % of the value being
## measured, which is a noise floor wide enough to swallow the whole
## static curve; a longer window buys that back directly, and the sweep
## still finishes inside a fraction of the watchdog budget.
const MEASURE_TICKS: int = 600

## Ticks run and thrown away before measuring. The broadphase pairs up on
## the first ticks after a build and the allocator is cold; a bench that
## measured those would publish a build cost as a running cost.
const WARMUP_TICKS: int = 40

## Fresh builds per point. Five, not two: the spread of these IS this
## bench's noise floor for that point, and a floor estimated from two
## samples is a range, not a floor.
const REPEATS: int = 5

## Wall-clock budget. The sweep is ~22 000 physics ticks and finishes in
## a couple of minutes on this sandbox; 900 s is ProbeWatchdog's default
## and is left alone.
const BUDGET_S: float = 900.0

## The skatepark's own triangle total, as CH53 built it and CH55 reported
## it. Reproduced by PHASE I from the shipped builders -- if this number
## ever stops matching, the bench is measuring different geometry than
## the game ships and every millisecond below is about something else.
const PARK_TRIS_ON_FILE: int = 468

## Collision layers, taken from Chased rather than invented: ground on
## layer 1, the moving body on layer 2 masking 1 (scenes/TrackSegment.tscn
## and scenes/Keepy.tscn). CH55 section 4.1 notes the hub's SubViewport
## shares the root World3D, so a hub implementation would have to avoid
## these two -- this bench runs in its own scene and reuses them on
## purpose, so that what is measured is the pairing Chased already ships.
const LAYER_WORLD: int = 1
const LAYER_ACTOR: int = 2

## Ceiling handed to the convex decomposition. Not a target: VHACD stops
## when the concavity threshold is met, so what this number does is stop
## it from stopping at ONE. The piece counts it actually returns are
## published per kind by PHASE I, and they are the number D5 pays for.
const MAX_HULLS: int = 32

## The concavity VHACD is allowed to leave inside one hull. The default is
## 1.0, which accepts anything. This is low enough that a swept ramp and a
## dish are actually cut apart -- which is what makes the convex column of
## curve A a price for D5's PIECES rather than for one hull per module.
const MAX_CONCAVITY: float = 0.01

## "This room cannot resolve the signal", which is neither 0 nor 1.
##
## The folder's convention is 0 = the contract holds, 1 = it is violated,
## and ProbeWatchdog already carved out 2 for "ran out of wall clock --
## the absence of a verdict". A bench whose own tremble is larger than the
## quantity it is measuring has produced the same kind of nothing, and
## reporting it as a violation would be reporting a finding about the
## world that the probe never made. MEASURED, not anticipated: under
## xvfb + opengl3 in this sandbox llvmpipe rasterises an empty 1080x1920
## window every iteration at ~8.5 ms with a +-2 ms tremble, and the whole
## of curve B's hundred-body rise is 2.1 ms. Two assertions came back RED
## on a bench that was working perfectly.
const EXIT_UNRESOLVED: int = 3

var _fails: int = 0
var _lines: Array[String] = []

# The bench.
var _ground: StaticBody3D = null
var _statics: Array[StaticBody3D] = []
var _actors: Array[CharacterBody3D] = []
var _areas: Array[Area3D] = []
## The incumbent: N hand-written kinematic vehicles, driven by the SAME
## VehicleDrive this hub already ships on four vehicles.
var _kins: Array[Dictionary] = []

# Shapes, built ONCE per module kind and shared by every body that uses
# them -- which is what a real implementation would do, and which keeps
# a convex decomposition out of the measured window.
var _convex: Dictionary = {}    # kind -> Array[Shape3D]
var _trimesh: Dictionary = {}   # kind -> Shape3D
var _kind_tris: Dictionary = {} # kind -> int

# Sampling state, written by _physics_process.
var _driving: bool = false
var _sampling: bool = false
var _tick: int = 0
var _clock: float = 0.0
var _samples: Array[float] = []
var _contact_ticks: int = 0
var _mon_active: int = 0
var _mon_pairs: int = 0
var _mon_islands: int = 0
var _want_query: bool = false
var _last_hits: int = 0
var _decomp_used: bool = true
var _gravity: float = 9.8
var _mon_changes: int = 0
var _mon_prev: float = -1.0
var _mon_change_log: Array[int] = []

# Results: key -> Array of per-repeat mean ms.
var _results: Dictionary = {}
var _halves: Array[float] = []

func _ready() -> void:
	ProbeWatchdog.arm(self, "PHYSICS COST PROBE", BUDGET_S)
	# The loop must run flat out or the wall-clock instrument measures the
	# vsync, not the physics. --fixed-fps already disables real-time
	# synchronisation; these two close the door from the other side.
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	Engine.max_fps = 0
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	_say("  [%s] %s" % ["OK " if ok else "RED", what])

func _say(s: String) -> void:
	_lines.append(s)
	print(s)

func _process(_delta: float) -> void:
	set_process(false)
	_run()

# =====================================================================
# THE DRIVER. Everything that touches the physics server per tick lives
# here, so that the cost of the probe's own bookkeeping is IDENTICAL at
# every N of curve A -- one move_and_slide, whatever the world contains.
# Curve B's bookkeeping is deliberately NOT constant: N move_and_slide
# calls is exactly what curve B is asking the price of.

func _physics_process(delta: float) -> void:
	if _want_query:
		_last_hits = _run_query()
		_want_query = false
	if not _driving:
		return
	_clock += delta
	# The incumbent, stepped exactly the way SledBody._physics_process
	# steps it: flat position, node yaw, world velocity, the same fence
	# and the same steer rate. Nothing here is a simplified stand-in --
	# a cheaper imitation of the thing being compared against would
	# flatter physics by exactly the amount it left out.
	for kin in _kins:
		var drive: VehicleDrive = kin["drive"]
		var node: Node3D = kin["node"]
		var input: KartInput = kin["input"]
		input.steer = sin((_clock + float(kin["phase"])) * 1.5)
		input.throttle = 1.0
		var out: Dictionary = drive.step(
			Vector3(node.global_position.x, 0.0, node.global_position.z),
			node.rotation.y, kin["velocity"], delta, input, true,
			SledBody.WORLD_FENCE, KartTuning.steer_rate() * SledBody.STEER_RATIO)
		node.rotation.y = float(out["yaw"])
		kin["velocity"] = out["velocity"]
		node.global_position = out["position"] as Vector3
	var touched := false
	for actor in _actors:
		# A lateral sweep across the module field, so the capsule keeps
		# meeting geometry instead of settling into one contact and
		# staying there. The phase offset spreads curve B's actors so
		# they are not all doing the same thing on the same tick.
		var phase: float = float(actor.get_meta("phase", 0.0))
		var amp: float = float(actor.get_meta("amp", 6.0))
		actor.velocity.x = amp * sin((_clock + phase) * 1.5)
		actor.velocity.y -= _gravity * delta
		if actor.is_on_floor() and actor.velocity.y < 0.0:
			actor.velocity.y = -0.1
		actor.move_and_slide()
		if actor.is_on_floor() or actor.get_slide_collision_count() > 0:
			touched = true
	if not _sampling:
		return
	_tick += 1
	var mon: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	if mon != _mon_prev:
		_mon_changes += 1
		_mon_prev = mon
	_samples.append(mon)
	if touched:
		_contact_ticks += 1
	_mon_active = maxi(_mon_active, int(Performance.get_monitor(
		Performance.PHYSICS_3D_ACTIVE_OBJECTS)))
	_mon_pairs = maxi(_mon_pairs, int(Performance.get_monitor(
		Performance.PHYSICS_3D_COLLISION_PAIRS)))
	_mon_islands = maxi(_mon_islands, int(Performance.get_monitor(
		Performance.PHYSICS_3D_ISLAND_COUNT)))

# =====================================================================
# THE WITNESSES. Two channels, and they are independent on purpose.
#
# W1 asks the PhysicsServer what it holds, body by body, by RID. It is a
# ledger lookup: exact, and it cannot be fooled by a query's semantics.
# W2 runs a real collision query against the same space. It is weaker
# (a shape query has a result cap and its own idea of what counts as an
# overlap) but it is the only one that proves the space actually RESOLVES
# anything, which is the property a cost measurement depends on.

func _space() -> RID:
	return get_tree().root.world_3d.space

## W1: how many collision objects the SERVER holds in this space, and how
## many shapes they carry between them.
##
## It walks the scene tree for CollisionObject3D rather than iterating the
## lists this probe filled in, and the difference matters: a ledger built
## from "what I think I created" cannot report a body that leaked from a
## previous point, and leaking between points is precisely the failure
## that would make every later measurement wrong in the same direction.
## CLAUDE.md, on the same shape one level up: "le producteur publie ce
## qu'il a construit ; le lecteur ne le reconnait jamais."
func _server_ledger() -> Dictionary:
	var space := _space()
	var bodies: int = 0
	var shapes: int = 0
	var all: Array[Node] = get_tree().root.find_children(
		"*", "CollisionObject3D", true, false)
	for node in all:
		var rid: RID = (node as CollisionObject3D).get_rid()
		var in_space: bool = false
		if node is Area3D:
			in_space = PhysicsServer3D.area_get_space(rid) == space
			if in_space:
				bodies += 1
				shapes += PhysicsServer3D.area_get_shape_count(rid)
		else:
			in_space = PhysicsServer3D.body_get_space(rid) == space
			if in_space:
				bodies += 1
				shapes += PhysicsServer3D.body_get_shape_count(rid)
	return {"bodies": bodies, "shapes": shapes}

## W2: a live shape query over the whole bench. Returns the number of
## shape hits, capped generously above anything the sweep builds.
##
## It is asked for from _physics_process and NEVER from a phase, and that
## is not tidiness: a PhysicsDirectSpaceState3D refuses to answer while
## the server is flushing queries, and the refusal is an error line plus
## an EMPTY result -- which reads exactly like "the space holds nothing",
## i.e. like the blind check passing. A witness whose failure mode is
## indistinguishable from its success mode is not a witness.
func _query_hits() -> int:
	_want_query = true
	while _want_query:
		await get_tree().physics_frame
	return _last_hits

func _run_query() -> int:
	var sphere := SphereShape3D.new()
	sphere.radius = 400.0
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D.IDENTITY
	params.collision_mask = 0xFFFFFFFF
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var state := get_tree().root.world_3d.direct_space_state
	return state.intersect_shape(params, 4096).size()

# =====================================================================
# BUILDING THE BENCH

## D5's convex pieces, built the way Godot itself builds them.
##
## ⚠️ MEASURED, not read in documentation: `Mesh.convex_decompose()` does
## NOT exist on ArrayMesh in 4.3 -- the first version of this probe called
## it and died on "Nonexistent function 'convex_decompose' in base
## 'ArrayMesh'". The exposed entry point is
## MeshInstance3D.create_multiple_convex_collisions(), which runs the same
## VHACD pass and hangs a StaticBody3D of ConvexPolygonShape3D children off
## the node. The shapes are harvested from it and the scaffolding is thrown
## away, so nothing built here ever reaches a measured window.
##
## If it comes back with nothing, the single hull is used and _decomp_used
## says so -- because a bench that silently substituted one hull for a
## decomposition would publish D5's price as somebody else's.
func _decompose(mesh: ArrayMesh) -> Array[Shape3D]:
	var pieces: Array[Shape3D] = []
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	# ⚠️ MEASURED: the no-argument call is NOT a decomposition.
	# MeshConvexDecompositionSettings.max_convex_hulls defaults to 1, so
	# create_multiple_convex_collisions() with no settings returns ONE hull
	# per mesh and looks exactly like a decomposition that found nothing to
	# split. The first run of this probe read "0 of 4 kinds came back as
	# more than one hull" and stopped there -- which is the instrument
	# control doing its job, and the reason the gate exists at all.
	# And max_convex_hulls alone is STILL not a decomposition: with
	# max_concavity left at its default 1.0 -- the most permissive value
	# there is -- VHACD accepts a quarterpipe's swept concave profile as
	# convex enough and hands back one hull anyway. Measured: raising the
	# ceiling to 32 changed nothing at all, and the gate stayed red. Two
	# knobs, and the second is the one that does the work.
	var settings := MeshConvexDecompositionSettings.new()
	settings.max_convex_hulls = MAX_HULLS
	settings.max_concavity = MAX_CONCAVITY
	mi.create_multiple_convex_collisions(settings)
	for child in mi.get_children():
		if child is StaticBody3D:
			for sub in (child as StaticBody3D).get_children():
				if sub is CollisionShape3D and (sub as CollisionShape3D).shape != null:
					pieces.append((sub as CollisionShape3D).shape)
	mi.queue_free()
	if pieces.is_empty():
		_decomp_used = false
		pieces.append(mesh.create_convex_shape(true, true))
	return pieces

func _build_ground() -> void:
	_ground = StaticBody3D.new()
	_ground.name = "BenchGround"
	_ground.collision_layer = LAYER_WORLD
	_ground.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 2.0, 400.0)
	var cs := CollisionShape3D.new()
	cs.shape = box
	cs.position = Vector3(0.0, -1.0, 0.0)
	_ground.add_child(cs)
	add_child(_ground)

## Where module i stands. Index 0 sits ON the capsule's sweep so that
## every N >= 1 exercises narrowphase; the rest fill rows behind it, so
## that raising N raises broadphase pressure without silently raising the
## number of contacts too. Those are two different costs and a bench that
## conflated them could not tell which one it had measured.
func _module_pos(i: int) -> Vector3:
	if i == 0:
		return Vector3.ZERO
	var k: int = i - 1
	return Vector3(float(k % 10) * 7.0 - 31.5, 0.0, 7.0 + float(k / 10) * 7.0)

func _build_statics(n: int, trimesh: bool) -> void:
	for i in n:
		var spec: Dictionary = HubSkatepark.MODULES[i % HubSkatepark.MODULES.size()]
		var kind: StringName = StringName(spec["kind"])
		var body := StaticBody3D.new()
		body.name = "Bench_%s_%d" % [String(kind), i]
		body.collision_layer = LAYER_WORLD
		body.collision_mask = 0
		body.position = _module_pos(i)
		if trimesh:
			var cs := CollisionShape3D.new()
			cs.shape = _trimesh[kind]
			body.add_child(cs)
		else:
			for piece in (_convex[kind] as Array):
				var cs := CollisionShape3D.new()
				cs.shape = piece
				body.add_child(cs)
		add_child(body)
		_statics.append(body)

func _build_actors(n: int) -> void:
	for i in n:
		var body := CharacterBody3D.new()
		body.name = "BenchActor_%d" % i
		# Hitboxes is THE collision contract of this repo (its own header
		# says the constants are the source of truth and the scenes are
		# not). The bench reads it rather than retyping 0.5 / 1.6.
		body.collision_layer = LAYER_ACTOR
		body.collision_mask = LAYER_WORLD
		var capsule := CapsuleShape3D.new()
		capsule.radius = Hitboxes.KEEPY_RADIUS
		capsule.height = Hitboxes.KEEPY_HEIGHT
		var cs := CollisionShape3D.new()
		cs.shape = capsule
		cs.position = Vector3(0.0, Hitboxes.KEEPY_Y, 0.0)
		body.add_child(cs)
		# Actor 0 stands on module 0; the rest fill a grid beside it, close
		# enough that they stay inside the park rather than trailing off
		# into empty ground -- a population strung out over 160 u would
		# measure a hundred bodies that never meet anything.
		#
		# ⚠️ AND THEY START 0.6 u UP, NOT 2.0. MEASURED: at 2.0 the capsule
		# needs ~0.64 s to fall to the ground, which is longer than PHASE
		# V's settle, and V7 came back RED on a bench that was working --
		# "not standing on the ground" was true, and it meant "still
		# falling". A gate that reads a transient as a defect sends the
		# next session after the wrong thing.
		body.position = Vector3(
			float(i % 10) * 1.6 - 7.2, 0.6, -2.0 - float(i / 10) * 1.6)
		body.set_meta("phase", float(i) * 0.37)
		add_child(body)
		_actors.append(body)

func _build_kins(n: int) -> void:
	for i in n:
		var node := Node3D.new()
		node.position = Vector3(
			float(i % 10) * 1.6 - 7.2, 0.0, -2.0 - float(i / 10) * 1.6)
		add_child(node)
		_kins.append({
			"drive": VehicleDrive.new(), "node": node, "input": KartInput.new(),
			"velocity": Vector3.ZERO, "phase": float(i) * 0.37,
		})

func _teardown() -> void:
	for k in _kins:
		(k["node"] as Node3D).queue_free()
	_kins.clear()
	for b in _statics:
		b.queue_free()
	for a in _actors:
		a.queue_free()
	for a in _areas:
		a.queue_free()
	_statics.clear()
	_actors.clear()
	_areas.clear()
	# queue_free lands at the end of the frame; the server does not drop
	# the body until the node actually leaves the tree. Two frames, then
	# the ledger is re-read by the caller.
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

# =====================================================================
# ONE MEASUREMENT

## Runs warm-up then MEASURE_TICKS with sampling on, and returns the
## per-tick cost by both instruments plus the witnesses.
func _measure() -> Dictionary:
	_driving = true
	_sampling = false
	for _i in WARMUP_TICKS:
		await get_tree().physics_frame
	_samples.clear()
	_tick = 0
	_mon_changes = 0
	_mon_prev = -1.0
	_contact_ticks = 0
	_mon_active = 0
	_mon_pairs = 0
	_mon_islands = 0
	_sampling = true
	var t0: int = Time.get_ticks_usec()
	var half: int = 0
	var t_half: int = 0
	for i in MEASURE_TICKS:
		await get_tree().physics_frame
		if i == MEASURE_TICKS / 2 - 1:
			t_half = Time.get_ticks_usec()
			half = _samples.size()
	var t1: int = Time.get_ticks_usec()
	_sampling = false
	_driving = false
	var mon_ms: float = 0.0
	for s in _samples:
		mon_ms += s
	mon_ms = (mon_ms / float(maxi(_samples.size(), 1))) * 1000.0
	var wall_ms: float = float(t1 - t0) / 1000.0 / float(MEASURE_TICKS)
	var wall_h1: float = float(t_half - t0) / 1000.0 / float(MEASURE_TICKS / 2)
	var wall_h2: float = float(t1 - t_half) / 1000.0 / float(MEASURE_TICKS / 2)
	var led := _server_ledger()
	var hits: int = await _query_hits()
	return {
		"mon_ms": mon_ms, "wall_ms": wall_ms,
		"h1": wall_h1, "h2": wall_h2,
		"ticks": _samples.size(), "contacts": _contact_ticks,
		"bodies": led["bodies"], "shapes": led["shapes"],
		"hits": hits,
		"active": _mon_active, "pairs": _mon_pairs, "islands": _mon_islands,
		"mon_changes": _mon_changes,
	}

# =====================================================================
# STATS

static func _median(a: Array[float]) -> float:
	var b := a.duplicate()
	b.sort()
	var n := b.size()
	if n == 0:
		return 0.0
	if n % 2 == 1:
		return b[n / 2]
	return (b[n / 2 - 1] + b[n / 2]) * 0.5

static func _minf_of(a: Array[float]) -> float:
	var m: float = a[0]
	for v in a:
		m = minf(m, v)
	return m

## The tremble of the POINTS BEING COMPARED, never the worst tremble on the
## bench.
##
## CLAUDE.md, CH41, in as many words: "la mesure est gatee PAR STATION
## contre le tremblement DE CETTE STATION [...] Un gate global (pire delta
## contre pire tremblement) est soit gratuit, soit faux." This probe wrote
## the global version first and MOD4 came back RED on a perfectly real
## +0.2234 ms, because the floor it was held against came from curve B's
## N=100 point -- a reading fourteen times larger, measured somewhere
## else, with nothing to do with the comparison being made.
func _floor_between(keys: Array) -> float:
	var f: float = 0.0
	for k in keys:
		var a: Array[float] = _results[k]
		f = maxf(f, _maxf_of(a) - _minf_of(a))
	return f

static func _maxf_of(a: Array[float]) -> float:
	var m: float = a[0]
	for v in a:
		m = maxf(m, v)
	return m

# =====================================================================

func _run() -> void:
	_say("=== PHYSICS COST PROBE -- CH56 LOT 0 ===")
	_say("  driver: %s   display: %s" % [
		RenderingServer.get_video_adapter_name(), DisplayServer.get_name()])
	_say("  sweep N = %s   repeats %d   window %d ticks (warm-up %d)" % [
		str(SWEEP), REPEATS, MEASURE_TICKS, WARMUP_TICKS])
	_say("")
	await _phase_config()
	await _phase_instrument()
	if _fails > 0:
		_say("=== INSTRUMENT FAILED -- every millisecond below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_void()
	if _fails > 0:
		_say("=== BLIND CHECK FAILED -- the bench cannot prove it sees an empty space. Stopping. ===")
		get_tree().quit(1)
		return
	_build_ground()
	if not await _phase_resolution():
		# PHASE Z still runs, and it is the ONE thing an unusable room is
		# uniquely good for: a room too noisy to price physics is a room
		# that is rasterising, and what it can measure is how expensive
		# the real hub is to draw here -- which is the measured reason the
		# bench is bare in the first place.
		await _phase_room()
		_say("=== NO VERDICT -- this room cannot resolve the quantity being measured. ===")
		get_tree().quit(EXIT_UNRESOLVED)
		return
	await _phase_curve_a()
	await _phase_curve_b()
	await _phase_contact()
	await _phase_incumbent()
	await _phase_areas()
	_phase_model()
	await _phase_room()
	_say("")
	_say("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	# CLAUDE.md: a probe that quits the same frame it built a world leaves
	# "ObjectDB instances leaked at exit" behind and breaks byte-identical
	# comparison between runs. One real frame to let PHASE Z's hub go.
	await get_tree().process_frame
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE C -- the configuration, READ and not assumed.
#
# CH55 sections 4.1 and 7.3/7.4 derived the whole cost model from the
# ABSENCE of settings in two files. An absence is a fine reason to expect
# a default and a poor reason to publish one, so every number the model
# rests on is read back off the running engine here, and the export
# preset is read off disk.

func _phase_config() -> void:
	_say("-- PHASE C: the configuration the cost model rests on, read back --")
	var ticks: int = int(ProjectSettings.get_setting(
		"physics/common/physics_ticks_per_second", 60))
	var maxsteps: int = int(ProjectSettings.get_setting(
		"physics/common/max_physics_steps_per_frame", 8))
	var jitter: float = float(ProjectSettings.get_setting(
		"physics/common/physics_jitter_fix", 0.5))
	var grav: float = float(ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8))
	var engine_name := str(ProjectSettings.get_setting(
		"physics/3d/physics_engine", "DEFAULT"))
	var sep: bool = bool(ProjectSettings.get_setting(
		"physics/3d/run_on_separate_thread", false))
	_say("     ticks/s %d   max_steps/frame %d   jitter_fix %.2f   gravity %.2f" % [
		ticks, maxsteps, jitter, grav])
	_say("     engine '%s'   run_on_separate_thread %s" % [engine_name, str(sep)])
	_check(ticks == 60, "C1 physics runs at 60 Hz (the model's denominator)")
	_check(maxsteps == 8, "C2 max_physics_steps_per_frame is 8 (the clamp CH55 4.2 names)")
	_check(not sep, "C3 physics does NOT run on a separate thread")
	var txt := ""
	var f := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	if f != null:
		txt = f.get_as_text()
		f.close()
	_check(txt != "", "C4 export_presets.cfg is readable from the probe")
	var has_threads := txt.contains("variant/thread_support=true")
	_say("     export_presets.cfg: 'variant/thread_support=true' present = %s" % str(has_threads))
	_check(not has_threads,
		"C5 the Web export declares no thread support -- WASM is single-threaded,"
		+ " so a physics millisecond lands on the render thread")
	_say("")

# =====================================================================
# PHASE I -- the instrument control.

func _phase_instrument() -> void:
	_say("-- PHASE I: the bench reproduces a number already on file, then builds its shapes --")
	# The mapping from a MODULES entry to a mesh lives in HubSkatepark and
	# is NOT retyped here: an instance is made without entering the tree,
	# so _ready never runs and nothing is built in the world, and its own
	# _mesh_for is called. One spelling, the shipped one.
	var park := HubSkatepark.new()
	var total: int = 0
	for spec in HubSkatepark.MODULES:
		var kind: StringName = StringName(spec["kind"])
		var builder := SkateparkMesh.new()
		var mesh: ArrayMesh = park._mesh_for(builder, spec)
		# CH64: the CONCRETE only (surface 0). The modules now carry a
		# second, decor surface -- coping tubes, steel edges -- that is
		# solid to nothing (D5: the pieces are the concrete), so the bench
		# prices the geometry a collider is a reading of and not the trim.
		var solid := ArrayMesh.new()
		solid.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(0))
		var tris: int = builder.concrete_triangle_count()
		total += tris
		if not _kind_tris.has(kind):
			_kind_tris[kind] = tris
			_trimesh[kind] = solid.create_trimesh_shape()
			_convex[kind] = _decompose(solid)
	park.free()
	for kind in _kind_tris:
		_say("     %-12s %3d tris   trimesh 1 shape   convex %d piece(s)" % [
			String(kind), int(_kind_tris[kind]), (_convex[kind] as Array).size()])
	_say("     park total %d CONCRETE triangles (on file: %d; decor apart since CH64)" % [total, PARK_TRIS_ON_FILE])
	_check(total == PARK_TRIS_ON_FILE,
		"I1 the bench's geometry IS the shipped park's geometry (%d tris)" % PARK_TRIS_ON_FILE)
	_check(_convex.size() == 4 and _trimesh.size() == 4,
		"I2 a shape of each kind was built for both collision forms (4 kinds)")
	var multi: int = 0
	for kind in _convex:
		if (_convex[kind] as Array).size() > 1:
			multi += 1
	_check(multi > 0,
		("I3 the decomposition actually SPLIT something (%d of %d kinds came back as"
			+ " more than one hull) -- D5's convex PIECES are what is being priced here,"
			+ " not one hull standing in for them") % [multi, _convex.size()])
	_check(_decomp_used, "I4 the shapes came from the engine's own convex decomposition,"
		+ " not from the single-hull fallback")
	var conc := 0
	for kind in _trimesh:
		if _trimesh[kind] is ConcavePolygonShape3D:
			conc += 1
	_check(conc == 4, "I5 every trimesh shape is a ConcavePolygonShape3D")
	# CH55 section 4.3 and CLAUDE.md's CH39 transposition: backface_collision
	# false is a floor you fall through in silence. Read, and published.
	var bf := (_trimesh[_trimesh.keys()[0]] as ConcavePolygonShape3D).backface_collision
	_say("     ConcavePolygonShape3D.backface_collision default = %s"
		% str(bf) + "  (false = a wrongly wound trimesh is an invisible hole)")
	_say("")

# =====================================================================
# PHASE V -- the blind check, ordered POSITIVE-FIRST.
#
# CLAUDE.md: an assertion of ABSENCE passes for free against a mechanism
# that was never wired. So the void is read, then one body is added and
# every witness is required to MOVE, then it is removed and the void is
# read again. Without the middle step neither zero is evidence of
# anything.

func _phase_void() -> void:
	_say("-- PHASE V: blind check -- the empty space, then a body, then empty again --")
	await get_tree().physics_frame
	var led0 := _server_ledger()
	var hits0: int = await _query_hits()
	var act0 := int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	var pai0 := int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	var isl0 := int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT))
	_say("     void      : server bodies %d shapes %d | query hits %d | active %d pairs %d islands %d"
		% [led0["bodies"], led0["shapes"], hits0, act0, pai0, isl0])
	_check(int(led0["bodies"]) == 0 and int(led0["shapes"]) == 0,
		"V1 the server holds NOTHING AT ALL in this space before anything is built")
	_check(hits0 == 0, "V2 a live shape query over the whole bench returns nothing")
	_check(act0 == 0, "V3 PHYSICS_3D_ACTIVE_OBJECTS reads 0")

	# THE MIDDLE STEP. Ground plus one actor, resting on it: that pairing
	# has to move every witness, or the three zeros above were free.
	_build_ground()
	_build_actors(1)
	_driving = true
	for _i in 60:
		await get_tree().physics_frame
	var led1 := _server_ledger()
	var hits1: int = await _query_hits()
	var act1 := int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	var pai1 := int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	var isl1 := int(Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT))
	var floored: bool = _actors[0].is_on_floor()
	_say("     +1 actor  : server bodies %d shapes %d | query hits %d | active %d pairs %d islands %d | on_floor %s"
		% [led1["bodies"], led1["shapes"], hits1, act1, pai1, isl1, str(floored)])
	_check(int(led1["bodies"]) == 2 and int(led1["shapes"]) == 2,
		"V4 the server now holds exactly the 2 bodies / 2 shapes that were built")
	_check(hits1 >= 2, "V5 the query channel MOVED (>= 2 hits) -- it is wired to the space")
	_check(pai1 > pai0,
		"V6 PHYSICS_3D_COLLISION_PAIRS MOVED (%d -> %d) -- the space is resolving contacts"
		% [pai0, pai1])
	_check(floored, "V7 the capsule is actually STANDING on the ground"
		+ " -- narrowphase ran, this is not a body falling through empty air")
	_say("     ** which of the four monitors moved is itself a finding, see the report:")
	_say("        active %d->%d   pairs %d->%d   islands %d->%d"
		% [act0, act1, pai0, pai1, isl0, isl1])

	_driving = false
	await _teardown()
	_ground.queue_free()
	_ground = null
	await get_tree().process_frame
	await get_tree().physics_frame
	var led2 := _server_ledger()
	var hits2: int = await _query_hits()
	_say("     void again: server bodies %d shapes %d | query hits %d"
		% [led2["bodies"], led2["shapes"], hits2])
	_check(int(led2["bodies"]) == 0 and hits2 == 0,
		"V8 tear-down returns the space to empty -- no measured point inherits the last one")
	_say("")

# =====================================================================
# PHASE R -- CAN THIS ROOM RESOLVE THE SIGNAL AT ALL?
#
# Asked FIRST, and on the cheapest pair that carries the answer: the room
# with no moving body against the room with one. That delta is the
# smallest thing this probe intends to publish, so a bench that cannot
# see it cannot see anything below it either -- and the whole sweep would
# be ten minutes of numbers whose error bars cover them.
#
# It returns false rather than raising a red. CLAUDE.md's own reasoning
# for ProbeWatchdog's exit code 2 applies unchanged: "un timeout n'est ni
# 0 ni 1 [...] c'est l'absence de verdict, et un appelant qui le traiterait
# comme une assertion echouee rapporterait une trouvaille que la sonde n'a
# jamais faite."

func _phase_resolution() -> bool:
	_say("-- PHASE R: can this room resolve the signal? --")
	for n in [0, 1]:
		var walls: Array[float] = []
		for _r in REPEATS:
			_build_statics(HubSkatepark.MODULES.size(), false)
			_build_actors(n)
			var res := await _measure()
			walls.append(float(res["wall_ms"]))
			await _teardown()
		_results["R_%d" % n] = walls
	var r0: float = _median(_results["R_0"])
	var r1: float = _median(_results["R_1"])
	var f: float = _floor_between(["R_0", "R_1"])
	_say("     room with no moving body : %.4f ms/tick" % r0)
	_say("     room with one            : %.4f ms/tick" % r1)
	_say("     signal %+.4f   this room's tremble %.4f" % [r1 - r0, f])
	if r1 - r0 > f:
		_say("     ** RESOLVED. The sweep may publish numbers.")
		_say("")
		return true
	_say("")
	_say("     ** NOT RESOLVED, and this is not a defect in anything being measured.")
	_say("        The room's own frame-to-frame tremble is larger than one moving")
	_say("        physics body, so every delta the sweep would print is inside its")
	_say("        error bars. The commonest cause here is a SOFTWARE RASTERISER:")
	_say("        driver '%s' on display '%s' redraws the window every"
		% [RenderingServer.get_video_adapter_name(), DisplayServer.get_name()])
	_say("        iteration, and that cost is both large and unsteady.")
	_say("        Re-run under --headless, where nothing is rasterised. Nothing in")
	_say("        this probe reads a pixel, so the dummy driver cannot fool it --")
	_say("        PHASE V's witnesses are the physics SERVER and a live space query,")
	_say("        neither of which has anything to do with rendering.")
	return false

# =====================================================================
# PHASE A -- CURVE A: N static colliders, ONE moving body.

func _phase_curve_a() -> void:
	_say("-- PHASE A: CURVE A -- N static module colliders, 1 moving capsule --")
	_say("     the per-tick script work is CONSTANT across N here (one move_and_slide),")
	_say("     so every millisecond of slope below belongs to the engine, not to this probe.")
	_say("     'ms' is WALL CLOCK per main-loop iteration (see the monitor verdict below);")
	_say("     'monMAX' is what Performance.TIME_PHYSICS_PROCESS said, printed and NOT used.")
	for trimesh in [false, true]:
		var form := "trimesh" if trimesh else "convex "
		_say("")
		_say("     form = %s" % form.strip_edges())
		_say("     %5s %9s %9s %9s %9s %8s %7s %7s %7s %6s" % [
			"N", "med ms", "min ms", "max ms", "spread", "monMAX", "shapes",
			"hits", "contact", "pairs"])
		for n in SWEEP:
			var mons: Array[float] = []
			var walls: Array[float] = []
			var last := {}
			for r in REPEATS:
				_build_statics(n, trimesh)
				_build_actors(1)
				last = await _measure()
				mons.append(float(last["mon_ms"]))
				walls.append(float(last["wall_ms"]))
				_halves.append(absf(float(last["h1"]) - float(last["h2"])))
				_mon_change_log.append(int(last["mon_changes"]))
				await _teardown()
			var key := "A_%s_%d" % [form.strip_edges(), n]
			_results[key] = walls
			_results[key + "_mon"] = mons
			var expect_shapes: int = 1 + 1 + _expected_shapes(n, trimesh)
			_say("     %5d %9.4f %9.4f %9.4f %9.4f %8.3f %7d %7d %7d %6d" % [
				n, _median(walls), _minf_of(walls), _maxf_of(walls),
				_maxf_of(walls) - _minf_of(walls), _median(mons),
				int(last["shapes"]), int(last["hits"]), int(last["contacts"]),
				int(last["pairs"])])
			_check(int(last["bodies"]) == n + 2,
				"A/%s N=%d the server held exactly the %d bodies built (ground + capsule + %d)"
				% [form.strip_edges(), n, n + 2, n])
			_check(int(last["shapes"]) == expect_shapes,
				"A/%s N=%d the server held exactly %d shapes"
				% [form.strip_edges(), n, expect_shapes])
			_check(int(last["contacts"]) > 0,
				"A/%s N=%d the capsule TOUCHED something on %d of %d ticks"
				% [form.strip_edges(), n, int(last["contacts"]), MEASURE_TICKS])
	_say("")

func _expected_shapes(n: int, trimesh: bool) -> int:
	var total: int = 0
	for i in n:
		var spec: Dictionary = HubSkatepark.MODULES[i % HubSkatepark.MODULES.size()]
		var kind: StringName = StringName(spec["kind"])
		total += 1 if trimesh else (_convex[kind] as Array).size()
	return total

# =====================================================================
# PHASE B -- CURVE B: N moving bodies, fixed environment.

func _phase_curve_b() -> void:
	_say("-- PHASE B: CURVE B -- N moving capsules against the REAL park (5 modules, convex) --")
	_say("     unlike curve A the probe's own per-tick work grows with N here, and that is")
	_say("     the point: N move_and_slide calls is what 'N physics bodies' costs a game.")
	_say("     %5s %9s %9s %9s %9s %8s %7s %7s %6s %6s" % [
		"N", "med ms", "min ms", "max ms", "spread", "monMAX", "shapes",
		"contact", "pairs", "isl"])
	for n in SWEEP:
		var mons: Array[float] = []
		var walls: Array[float] = []
		var last := {}
		for r in REPEATS:
			_build_statics(HubSkatepark.MODULES.size(), false)
			_build_actors(n)
			last = await _measure()
			mons.append(float(last["mon_ms"]))
			walls.append(float(last["wall_ms"]))
			_halves.append(absf(float(last["h1"]) - float(last["h2"])))
			_mon_change_log.append(int(last["mon_changes"]))
			await _teardown()
		_results["B_%d" % n] = walls
		_results["B_%d_mon" % n] = mons
		_say("     %5d %9.4f %9.4f %9.4f %9.4f %8.3f %7d %7d %6d %6d" % [
			n, _median(walls), _minf_of(walls), _maxf_of(walls),
			_maxf_of(walls) - _minf_of(walls), _median(mons),
			int(last["shapes"]), int(last["contacts"]),
			int(last["pairs"]), int(last["islands"])])
		_check(int(last["bodies"]) == n + 1 + HubSkatepark.MODULES.size(),
			"B N=%d the server held exactly the %d bodies built"
			% [n, n + 1 + HubSkatepark.MODULES.size()])
		if n > 0:
			_check(int(last["contacts"]) > 0,
				"B N=%d the capsules TOUCHED something on %d of %d ticks"
				% [n, int(last["contacts"]), MEASURE_TICKS])
	_say("")

# =====================================================================
# PHASE M -- the Area3D question CH55 section 7.5 left open.
#
# HubPortal.gd claims monitoring = false saves "a broadphase entry per
# frame", and CH55 flagged the wording as doubtful: a shape stays in the
# broadphase either way, and what monitoring buys is the pairing and the
# callback. Free to settle here, so it is settled here.

func _phase_areas() -> void:
	_say("-- PHASE M: does Area3D.monitoring cost anything? (CH55 section 7.5) --")
	_say("     %10s %5s %8s %8s %8s" % ["monitoring", "N", "med ms", "min ms", "max ms"])
	var overlaps: int = 0
	for monitoring in [false, true]:
		for n in [3, 100]:
			var mons: Array[float] = []
			for r in REPEATS:
				_build_statics(HubSkatepark.MODULES.size(), false)
				_build_actors(1)
				for i in n:
					var area := Area3D.new()
					area.monitoring = monitoring
					area.monitorable = monitoring
					area.collision_layer = LAYER_WORLD
					area.collision_mask = LAYER_ACTOR
					var cyl := CylinderShape3D.new()
					# HubPortal's exact shape, so the answer is about the
					# portal that exists and not about a generic area.
					cyl.radius = 1.35
					cyl.height = 3.0
					var cs := CollisionShape3D.new()
					cs.shape = cyl
					cs.position = Vector3(0.0, 1.5, 0.0)
					area.add_child(cs)
					area.position = Vector3(fmod(float(i) * 1.7, 12.0) - 6.0, 0.0,
						-1.0 - fmod(float(i) * 0.9, 6.0))
					add_child(area)
					_areas.append(area)
				var res := await _measure()
				mons.append(float(res["wall_ms"]))
				if monitoring:
					var seen: int = 0
					for a in _areas:
						seen += (a as Area3D).get_overlapping_bodies().size()
					overlaps = maxi(overlaps, seen)
				await _teardown()
			_results["M_%s_%d" % [str(monitoring), n]] = mons
			_say("     %10s %5d %8.4f %8.4f %8.4f" % [
				str(monitoring), n, _median(mons), _minf_of(mons), _maxf_of(mons)])
	# WITHOUT THIS THE PHASE IS FREE. "monitoring costs nothing" passes at
	# no charge against a set of areas the capsule never entered, because
	# an area that overlaps nothing has nothing to report either way. The
	# monitoring=true legs have to be shown actually MONITORING something.
	_say("     areas overlapping the capsule while monitoring was on: %d" % overlaps)
	_check(overlaps > 0,
		"M1 at least one monitoring Area3D actually held the capsule (%d overlaps)"
		% overlaps + " -- without this the whole phase would pass on areas nothing entered")
	var fm: float = _floor_between(["M_false_100", "M_true_100"])
	_say("     monitoring on vs off at N=100: %+.4f ms/tick, station floor %.4f"
		% [_median(_results["M_true_100"]) - _median(_results["M_false_100"]), fm])
	_say("")

# =====================================================================
# PHASE T -- THE CONTACT TEST, which is the only place D5's arbitration
# can actually be priced.
#
# Curve A raises N by adding modules the capsule never touches, on
# purpose: broadphase pressure and narrowphase work are two different
# costs and a bench that raised both at once could not say which one it
# had measured. The consequence is that curve A's trimesh column compares
# two collision FORMS the capsule only ever meets through ONE 20-triangle
# funbox -- a comparison that would come out flat whatever the answer.
#
# So the forms are compared where the difference lives: one capsule
# riding INSIDE the bowl, the 312-triangle module that is two thirds of
# the whole park's geometry, at the same station, same motion, same
# window, with only the shape swapped. That is the number a lot 3 would
# spend.

func _phase_contact() -> void:
	_say("-- PHASE T: convex pieces vs trimesh, IN CONTACT, on the 312-triangle bowl --")
	_say("     same station, same motion, same window; only the collision shape changes.")
	_say("     %10s %9s %9s %9s %9s %8s %8s" % [
		"form", "med ms", "min ms", "max ms", "spread", "shapes", "contact"])
	var spec: Dictionary = HubSkatepark.MODULES[4]
	_check(StringName(spec["kind"]) == HubSkatepark.KIND_BOWL,
		"T0 MODULES[4] is the bowl (the bench is pointing at the module it names)")
	for trimesh in [false, true]:
		var form := "trimesh" if trimesh else "convex"
		var walls: Array[float] = []
		var last := {}
		for _r in REPEATS:
			var body := StaticBody3D.new()
			body.collision_layer = LAYER_WORLD
			body.collision_mask = 0
			var kind: StringName = StringName(spec["kind"])
			if trimesh:
				var cs := CollisionShape3D.new()
				cs.shape = _trimesh[kind]
				body.add_child(cs)
			else:
				for piece in (_convex[kind] as Array):
					var cs2 := CollisionShape3D.new()
					cs2.shape = piece
					body.add_child(cs2)
			add_child(body)
			_statics.append(body)
			_build_actors(1)
			# Inside the dish, and swinging only as far as the dish goes:
			# a capsule thrown clear of the bowl would spend the window on
			# the ground plane and measure the ground.
			_actors[0].position = Vector3(0.0, 0.4, 0.0)
			_actors[0].set_meta("amp", 2.4)
			last = await _measure()
			walls.append(float(last["wall_ms"]))
			_halves.append(absf(float(last["h1"]) - float(last["h2"])))
			await _teardown()
		_results["T_" + form] = walls
		_say("     %10s %9.4f %9.4f %9.4f %9.4f %8d %8d" % [
			form, _median(walls), _minf_of(walls), _maxf_of(walls),
			_maxf_of(walls) - _minf_of(walls), int(last["shapes"]),
			int(last["contacts"])])
		_check(int(last["contacts"]) > MEASURE_TICKS / 2,
			"T/%s the capsule was in contact on %d of %d ticks -- this measures a"
			% [form, int(last["contacts"]), MEASURE_TICKS]
			+ " collision being RESOLVED, not a body in free air")
	_say("")

# =====================================================================
# PHASE K -- THE INCUMBENT, because "affordable" is a comparison and this
# hub is not starting from zero.
#
# CH55 section 1.3: "Le hub n'a pas 'pas de physique'. Il a une physique
# cinematique maison, sur trois vehicules, dont deux valides sur device."
# VehicleDrive.step() is a full per-frame velocity integrator -- steering
# on the heading, forward/lateral decomposition, exponential grip, scrub,
# brake, reverse, and a Rect2 fence with bounce -- and the hub already
# pays for it every physics tick a vehicle is driven.
#
# So the question a lot 1 actually faces is not "what does physics cost"
# but "what does physics cost MORE than what is already running". That
# ratio is the one number in this whole probe that does not need a device
# reading to be meaningful, because both halves are measured on the same
# machine in the same window and the machine cancels.

func _phase_incumbent() -> void:
	_say("-- PHASE K: Godot physics vs the kinematic integrator this hub ALREADY runs --")
	_say("     VehicleDrive.step() called exactly as SledBody calls it, same fence, same")
	_say("     steer rate. Same sweep, same window, same room as curve B.")
	_say("     %5s %9s %9s %9s %9s" % ["N", "med ms", "min ms", "max ms", "spread"])
	for n in SWEEP:
		var walls: Array[float] = []
		for _r in REPEATS:
			_build_statics(HubSkatepark.MODULES.size(), false)
			_build_kins(n)
			var res := await _measure()
			walls.append(float(res["wall_ms"]))
			_halves.append(absf(float(res["h1"]) - float(res["h2"])))
			await _teardown()
		_results["K_%d" % n] = walls
		_say("     %5d %9.4f %9.4f %9.4f %9.4f" % [
			n, _median(walls), _minf_of(walls), _maxf_of(walls),
			_maxf_of(walls) - _minf_of(walls)])
	var k1: float = _median(_results["K_1"])
	var k100: float = _median(_results["K_100"])
	var k0: float = _median(_results["K_0"])
	var f_k: float = _floor_between(["K_1", "K_100"])
	_check(k100 > k1 + f_k,
		("K1 the incumbent's own curve rises (%.4f -> %.4f, station floor %.4f) -- without"
			+ " this, 'physics costs N times the incumbent' would be a division by a"
			+ " number the bench never measured") % [k1, k100, f_k])
	_say("     incumbent marginal cost of ONE more vehicle: %.5f ms/tick"
		% ((k100 - k1) / 99.0))
	_say("     (room with none of either: %.4f ms/tick)" % k0)
	_say("")

# =====================================================================
# PHASE Z -- THE ROOM THE BENCH REFUSED, MEASURED RATHER THAN ASSERTED.
#
# CH55's lot 0 sketch said the bench should live "dans le monde du hub".
# It does not, and "llvmpipe would swamp it" is a claim, not a reason --
# so the claim is measured: HubWorld is instantiated, its frame cost is
# read under whatever driver is running, and the implied physics steps
# per rendered frame are printed beside it.
#
# ⚠️ AND THIS IS ALSO WHY THE BENCH IS TRUSTWORTHY, not only why the hub
# is not. `--fixed-fps 60` disables real-time synchronisation, so the
# engine runs exactly ONE physics step per iteration and
# max_physics_steps_per_frame NEVER engages. Every ms/tick above is
# therefore one tick. Inside the hub, at the frame cost printed below,
# the clamp is exactly what WOULD engage -- and a TIME_PHYSICS_PROCESS
# covering several steps is not a per-tick number any more.
#
# It runs LAST, after the verdict is printed, so that a hub that fails to
# build costs nothing that was already measured.

func _phase_room() -> void:
	_say("-- PHASE Z: the room the bench refused, measured --")
	if DisplayServer.get_name() == "headless":
		_say("     SKIPPED under the dummy driver: nothing is rasterised, so a frame")
		_say("     cost measured here would be a frame cost of nothing -- and freeing")
		_say("     the hub's meshes on this driver prints ~170 benign 'Parameter \"m\"")
		_say("     is null' lines that would bury the verdict above. Read this phase")
		_say("     from the opengl3 run -- and read the NUMBER there, not here: a")
		_say("     figure copied into a message is a figure that drifts (CLAUDE.md,")
		_say("     'un chiffre qui n'a pas de SOURCE dans le depot n'a pas de valeur').")
		_say("")
		return
	var scene: PackedScene = load("res://scenes/HubWorld.tscn")
	if scene == null:
		_say("     HubWorld.tscn did not load; nothing to report.")
		return
	var hub: Node = scene.instantiate()
	add_child(hub)
	for _i in 20:
		await get_tree().process_frame
	var t0: int = Time.get_ticks_usec()
	var frames: int = 60
	for _i in frames:
		await get_tree().process_frame
	var t1: int = Time.get_ticks_usec()
	var ms: float = float(t1 - t0) / 1000.0 / float(frames)
	var fps: float = 1000.0 / maxf(ms, 1e-6)
	_say("     driver %s: HubWorld renders at %.2f ms/frame (%.1f FPS on THIS machine)"
		% [DisplayServer.get_name(), ms, fps])
	_say("     at that frame time a real-time engine runs %.2f physics steps per frame,"
		% (60.0 / maxf(fps, 1e-6)))
	_say("     and max_physics_steps_per_frame = 8 caps it -- which is exactly the")
	_say("     condition under which TIME_PHYSICS_PROCESS stops being a per-tick number.")
	_say("     The bench above runs under --fixed-fps 60, where that clamp cannot engage,")
	_say("     so each of its readings is ONE tick.")
	if DisplayServer.get_name() == "headless":
		_say("     ** headless: nothing is rasterised, so this frame cost is NOT the room's")
		_say("        cost. The opengl3 run is the one to read this line from.")
	hub.queue_free()
	await get_tree().process_frame
	_say("")

# =====================================================================
# THE MODEL. Arithmetic on the numbers above, and nothing else.

func _phase_model() -> void:
	# -----------------------------------------------------------------
	# THE INSTRUMENT VERDICT, first, because it decides which of the two
	# columns above is allowed into the arithmetic.
	_say("-- THE TWO INSTRUMENTS, AND WHY ONLY ONE OF THEM IS USED --")
	var changes: int = 0
	for c in _mon_change_log:
		changes = maxi(changes, c)
	var windows: int = _mon_change_log.size()
	var secs: float = float(MEASURE_TICKS) / 60.0
	_say("     Performance.TIME_PHYSICS_PROCESS changed at most %d times in a %d-tick"
		% [changes, MEASURE_TICKS])
	_say("     window (%.1f simulated seconds), over %d windows." % [secs, windows])
	_check(changes <= int(secs) + 2,
		("MON1 the engine monitor updates about ONCE PER SECOND (max %d changes in %.1f s)"
			+ " -- it is a per-second MAXIMUM, not a per-tick cost, and averaging it over a"
			+ " window averages a handful of stale spikes") % [changes, secs])
	_say("     ** REJECTED as a cost instrument, and the numbers say why rather than a")
	_say("        memory of the engine's source: it read %.4f ms for a world with ZERO"
		% _median(_results["A_trimesh_0_mon"]))
	_say("        static colliders and %.4f ms for one with a hundred. A monitor whose"
		% _median(_results["A_convex_100_mon"]))
	_say("        reading FALLS as the world grows is not measuring the world.")
	_say("     ** USED INSTEAD: wall clock across the measured window, divided by ticks.")
	_say("        Under --fixed-fps the main loop is unthrottled, so one iteration is one")
	_say("        physics tick plus whatever else the loop does -- and PHASE B's N=0 row")
	_say("        prints what 'whatever else' costs: %.4f ms with no moving body at all."
		% _median(_results["B_0"]))
	_say("")

	_say("-- NOISE FLOOR --")
	var floor_repeat: float = 0.0
	var worst_key := ""
	for key in _results:
		if key.ends_with("_mon"):
			continue
		var a: Array[float] = _results[key]
		var sp: float = _maxf_of(a) - _minf_of(a)
		if sp > floor_repeat:
			floor_repeat = sp
			worst_key = key
	var floor_half: float = 0.0
	for h in _halves:
		floor_half = maxf(floor_half, h)
	var nfloor: float = maxf(floor_repeat, floor_half)
	_say("     worst repeat-to-repeat spread over every measured point : %.4f ms/tick (at %s)"
		% [floor_repeat, worst_key])
	_say("     worst half-window-to-half-window drift inside one run   : %.4f ms/tick" % floor_half)
	_say("     FLOOR USED BELOW                                        : %.4f ms/tick" % nfloor)
	_say("     ** any delta smaller than that is not a result. CLAUDE.md, CH40.")
	_say("")

	_say("-- THE COST MODEL --")
	var a0: float = _median(_results["A_convex_0"])
	var a6: float = _median(_results["A_convex_6"])
	var a100: float = _median(_results["A_convex_100"])
	var t0: float = _median(_results["A_trimesh_0"])
	var t6: float = _median(_results["A_trimesh_6"])
	var t100: float = _median(_results["A_trimesh_100"])
	var b0: float = _median(_results["B_0"])
	var b1: float = _median(_results["B_1"])
	var b6: float = _median(_results["B_6"])
	var b20: float = _median(_results["B_20"])
	var b100: float = _median(_results["B_100"])
	var tc: float = _median(_results["T_convex"])
	var tt: float = _median(_results["T_trimesh"])
	var shapes100: int = _expected_shapes(100, false)
	var per_actor: float = (b100 - b1) / 99.0
	var first_actor: float = b1 - b0
	_say("     A. THE ROOM")
	_say("       main loop with NO moving body, 5 static modules   : %.4f ms/tick" % b0)
	_say("       + the FIRST moving capsule                        : %.4f ms/tick (+%.4f)"
		% [b1, first_actor])
	_say("")
	_say("     B. STATIC COLLIDERS -- curve A, 1 capsule, N modules added")
	_say("       N=0 %.4f   N=6 %.4f   N=100 %.4f ms/tick (convex, %d shapes at N=100)"
		% [a0, a6, a100, shapes100])
	_say("       N=0 %.4f   N=6 %.4f   N=100 %.4f ms/tick (trimesh, 100 shapes)"
		% [t0, t6, t100])
	var fa: float = _floor_between(["A_convex_0", "A_convex_100"])
	var ft: float = _floor_between(["A_trimesh_0", "A_trimesh_100"])
	_say("       rise over 100 modules: convex %+.4f (station floor %.4f)"
		% [a100 - a0, fa])
	_say("                              trimesh %+.4f (station floor %.4f)"
		% [t100 - t0, ft])
	_say("       ** the rise is the SIZE OF THE TREMBLE at those two stations, so what")
	_say("          this bench publishes is an UPPER BOUND and not a slope:")
	_say("          one static convex module costs at most %.5f ms/tick,"
		% (maxf(absf(a100 - a0), fa) / 100.0))
	_say("          i.e. one convex PIECE costs at most %.6f ms/tick (%d shapes at N=100)."
		% [maxf(absf(a100 - a0), fa) / float(maxi(shapes100, 1)), shapes100])
	_say("          One static TRIMESH module costs at most %.5f ms/tick."
		% (maxf(absf(t100 - t0), ft) / 100.0))
	_say("          That the bench cannot resolve it further is a RESULT, not a failure:")
	_say("          the same instrument moves %.4f ms over curve B's identical sweep."
		% (b100 - b1))
	_say("")
	_say("     C. MOVING BODIES -- curve B, the question the brief asks")
	_say("       N=1 %.4f   N=6 %.4f   N=20 %.4f   N=100 %.4f ms/tick"
		% [b1, b6, b20, b100])
	_say("       marginal cost of ONE more moving capsule          : %.5f ms/tick" % per_actor)
	_say("       (the FIRST one costs %.4f, %.1fx the marginal: it is the one riding the"
		% [first_actor, first_actor / maxf(per_actor, 1e-9)])
	_say("        funbox, and a body RESOLVING a contact is not a body walking on a plane)")
	_say("")
	_say("     D. D5's ARBITRATION, PRICED IN CONTACT (PHASE T, the bowl)")
	_say("       convex pieces (%d shapes) : %.4f ms/tick" % [
		(_convex[HubSkatepark.KIND_BOWL] as Array).size(), tc])
	_say("       trimesh (312 triangles)   : %.4f ms/tick" % tt)
	_say("       difference                : %+.4f ms/tick   floor %.4f" % [tt - tc, nfloor])
	if absf(tt - tc) < nfloor:
		_say("       ** UNDER THE FLOOR. This bench cannot separate the two forms even on")
		_say("          the module built to separate them. D5 stands on the SILENT-HOLE")
		_say("          argument (backface_collision = false), not on a cost argument.")
	_say("")
	var k1: float = _median(_results["K_1"])
	var k100: float = _median(_results["K_100"])
	var per_kin: float = (k100 - k1) / 99.0
	_say("     D-bis. AGAINST THE INCUMBENT (PHASE K) -- the only ratio here that does")
	_say("            NOT need a device reading, because both halves ran on this machine")
	_say("       one Godot CharacterBody3D + move_and_slide : %.5f ms/tick" % per_actor)
	_say("       one VehicleDrive.step() the hub already runs: %.5f ms/tick" % per_kin)
	_say("       physics costs x%.2f the integrator already shipping"
		% (per_actor / maxf(per_kin, 1e-9)))
	_say("")
	_say("     E. WASM IS SINGLE-THREADED (PHASE C) AND PHYSICS IS 60 Hz FIXED, so the")
	_say("        cost PER RENDERED FRAME is ms/tick x (60 / FPS). CH55 4.2: a slower")
	_say("        frame pays MORE physics inside it, which is the wrong direction.")
	var formb: float = maxf(a6, b1)
	_say("        form B as CH55 specifies it (5 module colliders + 1 carrier) = %.4f ms/tick"
		% formb)
	_say("     %8s %12s %12s %14s %12s" % [
		"FPS", "steps/frame", "frame ms", "form B ms", "% of frame"])
	for fps in [60.0, 56.0, 50.0, 46.0]:
		var steps: float = 60.0 / fps
		var ms: float = formb * steps
		_say("     %8.0f %12.2f %12.2f %14.4f %11.2f %%" % [
			fps, steps, 1000.0 / fps, ms, 100.0 * ms / (1000.0 / fps)])
	_say("")
	_say("     F. HOW MANY MOVING BODIES FIT, at 50 FPS (CH52's proposed floor, so")
	_say("        1.20 physics ticks per rendered frame):")
	_say("     %12s %16s %16s" % ["budget ms/frame", "ms/tick allowed", "moving bodies"])
	for budget in [0.10, 0.25, 0.50, 1.00, 2.00]:
		var allowed: float = budget / 1.20
		var n: float = 1.0 + (allowed - b1) / maxf(per_actor, 1e-9)
		_say("     %12.2f %16.4f %16.0f" % [budget, allowed, maxf(n, 0.0)])
	_say("")
	_say("     H. THE ONE UNKNOWN, MADE EXPLICIT. Everything above is a native x86")
	_say("        build on this sandbox's CPU; the phone runs single-threaded WASM.")
	# ⚠️ THE FORMAT TRAP, caught by re-reading the OUTPUT and not the code.
	# The first of these two lines carried a %.4f and the `% formb` sat on
	# the SECOND, so the run printed the specifier verbatim. CLAUDE.md
	# already says a probe's output is re-read once to check every label
	# against its test; this is the same rule one notch down -- a line
	# whose conversion has no argument does not raise, it just prints
	# nonsense in the middle of a number the reader is meant to use.
	_say("        Call that ratio F. Form B costs %.4f ms/tick here, so on device"
		% formb)
	_say("        it costs that x F, and at 50 FPS that is 1.20 of those per frame:")
	_say("     %8s %14s %16s %14s" % ["F", "ms/tick", "ms per frame", "% of 20 ms"])
	for fac in [1.0, 3.0, 5.0, 10.0, 20.0]:
		var ms: float = formb * fac * 1.20
		_say("     %8.0f %14.4f %16.4f %13.1f %%" % [
			fac, formb * fac, ms, 100.0 * ms / 20.0])
	_say("        ** F IS NOT KNOWN AND THIS LOT CANNOT MEASURE IT. It is the single")
	_say("           number that decides the answer, and one device reading fixes it:")
	_say("           the same scene with and without one physics body.")
	_say("")
	_say("     ** these are SANDBOX bodies on a 2.80 GHz Xeon. The transferable shape is")
	_say("        the CURVE (a fixed room cost, then a straight line in N); the intercept")
	_say("        and the slope both have to be re-read on device before the count in the")
	_say("        right-hand column means anything about a phone.")
	_say("")

	# ---------------------------------------------------------------
	# THE GATES. They gate the BENCH, never the answer -- see the header.
	#
	# MOD1 is the positive control that licenses MOD2: an absence claim
	# ("static colliders cost nothing") is worthless unless the same
	# instrument is shown MOVING on something else, which is the whole
	# blind-check doctrine applied to a cost curve rather than to a pixel.
	var f_b: float = _floor_between(["B_1", "B_100"])
	_check(b100 > b1 + f_b,
		("MOD1 the instrument MOVES: curve B rises %.4f -> %.4f ms/tick over the sweep,"
			+ " past its own station floor %.4f") % [b1, b100, f_b])
	_check(absf(a100 - a0) < 0.25 * (b100 - b1),
		("MOD2 a hundred STATIC colliders cost less than a quarter of what a hundred"
			+ " MOVING bodies cost (%+.4f vs %+.4f) -- and MOD1 is what makes that an"
			+ " observation rather than a dead instrument") % [a100 - a0, b100 - b1])
	var f_t: float = _floor_between(["T_convex", "T_trimesh"])
	_check(tt > tc - f_t,
		("MOD3 trimesh is not CHEAPER than convex in contact (%.4f vs %.4f, station"
			+ " floor %.4f) -- a negative cost beyond the tremble would mean the two runs"
			+ " were not the same experiment") % [tt, tc, f_t])
	# MOD4 asks "is what we are measuring physics, or is it the main loop?"
	# The sharpest form of that question is the FIRST body's cost -- and on
	# a software rasteriser that delta sits under the render tremble, so
	# gating it there would make this probe RED on a bench that is working.
	# It is therefore PRINTED with its resolvability and gated on the whole
	# of curve B's rise, which is the same claim at a station where every
	# driver can resolve it. CLAUDE.md, CH41: publish the noisy station,
	# gate elsewhere, and say which is which.
	var f_01: float = _floor_between(["B_0", "B_1"])
	var f_0_100: float = _floor_between(["B_0", "B_100"])
	_say("     G. IS ANY OF THIS PHYSICS?")
	_say("       first moving body      : %+.4f ms/tick, station tremble %.4f -- %s"
		% [first_actor, f_01,
			"RESOLVED" if first_actor > f_01 else "BELOW THE TREMBLE at this station"])
	_say("       all hundred            : %+.4f ms/tick, station tremble %.4f -- %s"
		% [b100 - b0, f_0_100,
			"RESOLVED" if (b100 - b0) > f_0_100 else "below the tremble"])
	_say("")
	_check(b100 - b0 > f_0_100,
		("MOD4 curve B's whole rise clears its own station tremble (%+.4f vs %.4f)"
			+ " -- if it did not, every millisecond above would be the main loop and"
			+ " none of it physics") % [b100 - b0, f_0_100])
