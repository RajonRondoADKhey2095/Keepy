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

const BUDGET_S: float = 900.0
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
	await _phase_ride()
	await _phase_neutralised()
	await _phase_lateral()
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

func _phase_pieces() -> void:
	print("-- PHASE G: the collision pieces are a second READING of the drawn funbox --")
	var spec: Dictionary = HubSkatepark.MODULES[0]
	_check(StringName(spec["kind"]) == HubSkatepark.KIND_FUNBOX,
		"MODULES[0] is the funbox (the module this lot makes solid)")
	var size: Vector3 = spec["size"]
	var w: float = size.x
	var l: float = size.z * 0.55
	var h: float = size.y
	var r: float = size.z * 0.45
	var builder := SkateparkMesh.new()
	var mesh: ArrayMesh = builder.funbox(w, l, h, r)
	# CH56 restated 468 park triangles and 20 for this module. A bench
	# that cannot restate a number on file has no standing to publish one.
	_check(builder.triangle_count() == 20,
		"the drawn funbox is 20 triangles (CH56 section 3.1: 20)")
	var drawn := _distinct(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var pieces: Array = SkateparkMesh.funbox_pieces(w, l, h, r)
	_check(pieces.size() == 3, "three pieces: one deck box, two ramp wedges (got %d)" % pieces.size())
	var counts: Array = []
	var union := PackedVector3Array()
	for piece in pieces:
		counts.append(piece.size())
		for p in piece:
			union.append(p)
	print("     piece point counts %s   union distinct %d   drawn distinct %d"
		% [str(counts), _distinct(union).size(), drawn.size()])
	_check(counts == [8, 6, 6], "8 / 6 / 6 points -- a box and two triangular prisms")
	_check(_same_set(_distinct(union), drawn),
		"the union of the pieces IS the set of distinct drawn vertex positions")
	# The blind check: move ONE argument and the comparison must break.
	var wrong: Array = SkateparkMesh.funbox_pieces(w, l, h, r + 0.10)
	var wrong_union := PackedVector3Array()
	for piece in wrong:
		for p in piece:
			wrong_union.append(p)
	_check(not _same_set(_distinct(wrong_union), drawn),
		"BLIND CHECK: pieces built from a ramp 0.10 u longer do NOT match the drawn mesh")
	await get_tree().process_frame

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
	_check(_park.collider_index() == 0, "the collider is on MODULES[0], the funbox (got %d)" % _park.collider_index())
	_check(_park.collider_piece_count() == 3, "the funbox body holds 3 shapes (got %d)" % _park.collider_piece_count())
	_check(_park.module_nodes().size() == HubSkatepark.MODULES.size(),
		"all five modules are still drawn (%d)" % _park.module_nodes().size())
	# The one module with a collider, and the four without -- the perimeter
	# of this lot, asserted rather than described.
	var bodies: int = 0
	for node in _park.module_nodes():
		for child in node.get_children():
			if child is StaticBody3D:
				bodies += 1
	_check(bodies == 1, "exactly ONE module carries a static body (got %d)" % bodies)
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
	print("     live space query over the whole hub: %d collision objects" % hits.size())
	_check(hits.size() >= 2, "the server answers with at least the funbox and the board (%d)" % hits.size())

# =====================================================================
# THE RIDE

## Places the board, mounts him on it the way HubTransport does, aims it,
## and steps `ticks` physics frames while sampling. Returns the trace.
func _roll(label: String, from: Vector3, to: Vector3, ticks: int) -> Dictionary:
	var body := _transport.board_body()
	if _transport.is_riding_board():
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
	var spec: Dictionary = HubSkatepark.MODULES[0]
	var centre: Vector3 = _park.module_centre(0)
	var size: Vector3 = spec["size"]
	var deck_half_x: float = size.x * 0.5
	var deck_half_z: float = size.z * 0.55 * 0.5
	var deck_h: float = size.y
	var trace := {"mounted": mounted, "max_y": -1e9, "deck_min_y": 1e9, "deck_ticks": 0,
		"supported": 0, "under_surface": 0, "rider_off": 0, "path": 0.0,
		"deck_h": deck_h, "arrived": false}
	var last: Vector3 = body.flat_position()
	for _t in ticks:
		await get_tree().physics_frame
		var flat: Vector3 = body.flat_position()
		var y: float = body.global_position.y
		trace["path"] = float(trace["path"]) + flat.distance_to(last)
		last = flat
		trace["max_y"] = maxf(float(trace["max_y"]), y)
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
		if absf(flat.x - centre.x) <= deck_half_x - 0.30 and absf(flat.z - centre.z) <= deck_half_z - 0.10:
			trace["deck_ticks"] = int(trace["deck_ticks"]) + 1
			trace["deck_min_y"] = minf(float(trace["deck_min_y"]), y)
		if flat.distance_to(Vector3(to.x, 0.0, to.z)) < 1.0:
			trace["arrived"] = true
	trace["end"] = body.flat_position()
	print("     %-34s path %.2f u   max y %.3f   over-deck ticks %d (min y %s)   supported %d   arrived %s"
		% [label, trace["path"], trace["max_y"], trace["deck_ticks"],
			("n/a" if int(trace["deck_ticks"]) == 0 else "%.3f" % float(trace["deck_min_y"])),
			trace["supported"], trace["arrived"]])
	return trace

func _phase_ride() -> void:
	print("-- PHASE R: THE POSITIVE -- the board climbs onto the funbox and carries on --")
	var t: Dictionary = await _roll("with collider", RIDE_FROM, RIDE_TO, RIDE_TICKS)
	var deck_h: float = float(t["deck_h"])
	# The instrument first: a ride that never happened would pass every
	# height test below by never being anywhere.
	_check(bool(t["mounted"]), "he is aboard (mount_board took him)")
	_check(float(t["path"]) > 8.0, "INSTRUMENT: the board actually rolled (%.2f u > 8)" % t["path"])
	_check(int(t["deck_ticks"]) > 0, "INSTRUMENT: the roll crossed the deck footprint (%d ticks)" % t["deck_ticks"])
	# The two axes, and neither alone would do (see the header).
	_check(int(t["deck_ticks"]) > 0 and float(t["deck_min_y"]) >= deck_h - 0.03,
		"HEIGHT: every tick over the deck was ON it (min y %.3f >= %.3f)"
			% [float(t["deck_min_y"]), deck_h - 0.03])
	_check(bool(t["arrived"]), "DISTANCE: it reached the far side of the module, it did not stop beside it")
	_check(int(t["supported"]) > 0, "the module HELD it: supported() was true on %d ticks" % t["supported"])
	_check(int(t["under_surface"]) == 0, "D1: never below HubSurface, on any tick (%d violations)" % t["under_surface"])
	_check(int(t["rider_off"]) == 0, "carrier-then-carried: the rider is on the deck every tick (%d off)" % t["rider_off"])

func _phase_neutralised() -> void:
	print("-- PHASE N: RED BEFORE GREEN, at runtime -- take the collider off the layer --")
	var wall := _park.collider_body()
	var keep: int = wall.collision_layer
	wall.collision_layer = 0
	var t: Dictionary = await _roll("collider neutralised", RIDE_FROM, RIDE_TO, RIDE_TICKS)
	_check(float(t["path"]) > 8.0, "INSTRUMENT: the neutralised run rolled too (%.2f u)" % t["path"])
	_check(int(t["deck_ticks"]) > 0, "INSTRUMENT: it crossed the same footprint (%d ticks)" % t["deck_ticks"])
	_check(int(t["deck_ticks"]) > 0 and float(t["deck_min_y"]) < 0.05,
		"WITHOUT the collider it goes THROUGH the funbox (min y %s)"
			% ("n/a" if int(t["deck_ticks"]) == 0 else "%.3f" % float(t["deck_min_y"])))
	_check(int(t["supported"]) == 0, "and nothing held it (supported ticks %d)" % t["supported"])
	wall.collision_layer = keep
	var back: Dictionary = await _roll("collider restored", RIDE_FROM, RIDE_TO, RIDE_TICKS)
	_check(int(back["deck_ticks"]) > 0 and float(back["deck_min_y"]) >= float(back["deck_h"]) - 0.03,
		"and the climb COMES BACK when the layer is restored (min y %s)"
			% ("n/a" if int(back["deck_ticks"]) == 0 else "%.3f" % float(back["deck_min_y"])))

func _phase_lateral() -> void:
	print("-- PHASE L: the other half of D1 -- a vertical face BLOCKS --")
	var t: Dictionary = await _roll("into the east face", SIDE_FROM, SIDE_TO, RIDE_TICKS)
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
