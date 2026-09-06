extends Node
## CH29 -- the cove's contracts on the LIVE HubWorld.tscn, transforms only
## (headless, --fixed-fps 60). Bounded by ProbeWatchdog from the first
## statement. Every equality was made to FAIL first (red-before-green, see
## docs/lots/CH29_CRIQUE.md); the blind checks are written into the phases
## (a thing is shown to MOVE before "it did not move" is believed).
##
## Exit 0 = every assertion held; 1 = at least one failed;
## ProbeWatchdog.EXIT_TIMEOUT = inconclusive.
##
## Args after `--`: --only=region|geometry|walk|castle|weather|yacht|balloon|save|times|all
## "times" is the travel-time table (informational lines prefixed TIME plus
## the two assertions that a ride beats the walk it replaces).

var _hub: Node = null
var _keepy: KeepyHopper = null
var _cove: HubCove = null
var _transport: HubTransport = null
var _weather: CozyWeather = null
var _camera: HubCamera = null
var _failures: int = 0
var _checks: int = 0
var _only: String = "all"
var _hops: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "COVE", 840.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
	WorldSave.SAVE_PATH_OVERRIDE = "user://cove_probe.json"
	WorldSave.reset()
	var packed: PackedScene = load("res://scenes/HubWorld.tscn")
	_hub = packed.instantiate()
	add_child(_hub)
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
	_cove = _hub.get_node("WorldViewport/SubViewport/World/Cove")
	_transport = _hub.get_node("WorldViewport/SubViewport/World/Transport")
	_weather = _hub.get_node("WorldViewport/SubViewport/World/CozyWeather")
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	_keepy.hop_landed.connect(func(_p): _hops += 1)
	_run()

func _run() -> void:
	await _frames(3)
	if _only == "all" or _only == "region":
		await _phase_region()
	if _only == "all" or _only == "geometry":
		await _phase_geometry()
	if _only == "all" or _only == "save":
		await _phase_save()
	if _only == "all" or _only == "walk":
		await _phase_walk()
	if _only == "all" or _only == "castle":
		await _phase_castle()
	if _only == "all" or _only == "weather":
		await _phase_weather()
	if _only == "all" or _only == "yacht":
		await _phase_yacht()
	if _only == "all" or _only == "balloon":
		await _phase_balloon()
	if _only == "all" or _only == "times":
		await _phase_times()
	print("")
	print("COVE PROBE: %d checks, %d failures -> %s" % [_checks, _failures, "PASS" if _failures == 0 else "FAIL"])
	get_tree().quit(0 if _failures == 0 else 1)

## ---- helpers ------------------------------------------------------------

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s%s" % ["ok" if ok else "FAIL", label, ("  -- " + detail) if detail != "" else ""])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)

func _put_keepy(at: Vector3) -> void:
	_keepy.global_position = _flat(at)
	_camera.snap_to_target()

## Waits until the hop chain is spent (no target, no via gate), or `cap`
## frames. Returns the frame count.
func _settle(cap: int) -> int:
	var frames := 0
	for i in cap:
		await get_tree().process_frame
		frames += 1
		if not _keepy.is_hopping() and _hub._via_expect == Vector3.INF and not _keepy._has_target:
			break
	return frames

func _weather_settle(kind: int) -> void:
	_weather.force(kind)
	for i in 600:
		await get_tree().process_frame
		if _weather.weight(kind) >= 0.999:
			break

## ---- PHASE REGION ---------------------------------------------------------

func _phase_region() -> void:
	print("\nPHASE REGION")
	var centre := Vector3(56.0, 0.0, -110.0)
	var corridor := Vector3(41.0, 0.0, -96.0)
	_check("cove centre is zone 4", HubRegion.zone_of(centre) == 4)
	_check("cove corridor is zone 4", HubRegion.zone_of(corridor) == 4)
	_check("moor east edge is still zone 2", HubRegion.zone_of(Vector3(36.0, 0.0, -110.0)) == 2)
	_check("circuit is still zone 3", HubRegion.zone_of(Vector3(0.0, 0.0, -165.0)) == 3)
	_check("cove centre is region", HubRegion.contains(centre))
	_check("corridor is region", HubRegion.contains(corridor))
	# Blind: the hedge band between the moor and the cove is NOT region
	# except at the corridor.
	_check("hedge north of the corridor is not region", not HubRegion.contains(Vector3(41.0, 0.0, -110.0)))
	_check("hedge south of the corridor is not region", not HubRegion.contains(Vector3(41.0, 0.0, -88.0)))
	# The lighthouse is a hole, like the trunk and the windmill.
	_check("lighthouse base is not walkable", not HubRegion.contains(HubRegion.LIGHTHOUSE_AT))
	var rim: Vector3 = HubRegion.clamp_to(HubRegion.LIGHTHOUSE_AT + Vector3(0.3, 0.0, 0.0))
	_check("a tap on the lighthouse lands on its rim", HubRegion.contains(rim) and absf(rim.distance_to(HubRegion.LIGHTHOUSE_AT) - HubRegion.LIGHTHOUSE_RADIUS) < 0.1, str(rim))
	# The sea is walkable up to the cove's east edge.
	var far := Vector3(300.0, 0.0, -110.0)
	var clamped: Vector3 = HubRegion.clamp_to(far)
	_check("a tap far out to sea clamps onto the cove's east edge", HubRegion.contains(clamped) and absf(clamped.x - HubRegion.COVE_MAX.x) < 0.01, str(clamped))
	_check("that edge is in the sea (water is a place)", HubRegion.in_sea(clamped))
	_check("the shoreline is inside the walkable cove", HubRegion.shore_distance(Vector3(HubRegion.COVE_MAX.x, 0.0, -110.0)) < 0.0 and HubRegion.shore_distance(Vector3(HubRegion.COVE_MIN.x, 0.0, -110.0)) > 0.0)
	# Gates: the tree.
	var g24: Array = _hub._gates_between(2, 4)
	_check("moor -> cove is one gate, the cove gate", g24.size() == 1 and g24[0] == _hub.COVE_GATE, str(g24))
	var g40: Array = _hub._gates_between(4, 0)
	_check("cove -> plateau is cove, moor, corridor gates", g40.size() == 3 and g40[0] == _hub.COVE_GATE and g40[1] == _hub.MOOR_GATE and g40[2] == _hub.CORRIDOR_GATE, str(g40))
	var g43: Array = _hub._gates_between(4, 3)
	_check("cove -> circuit is cove then circuit gate", g43.size() == 2 and g43[0] == _hub.COVE_GATE and g43[1] == _hub.CIRCUIT_GATE, str(g43))
	var g14: Array = _hub._gates_between(1, 4)
	_check("hollow -> cove is moor then cove gate", g14.size() == 2 and g14[0] == _hub.MOOR_GATE and g14[1] == _hub.COVE_GATE, str(g14))
	# Regression: the chain is what it was.
	var g03: Array = _hub._gates_between(0, 3)
	_check("plateau -> circuit is still three chain gates", g03.size() == 3 and g03[0] == _hub.CORRIDOR_GATE and g03[2] == _hub.CIRCUIT_GATE)
	var g30: Array = _hub._gates_between(3, 0)
	_check("circuit -> plateau is still three gates reversed", g30.size() == 3 and g30[0] == _hub.CIRCUIT_GATE and g30[2] == _hub.CORRIDOR_GATE)
	_check("same zone is no gate", _hub._gates_between(4, 4).is_empty() and _hub._gates_between(2, 2).is_empty())
	_check("cove gate is region and in the corridor", HubRegion.contains(_hub.COVE_GATE) and HubRegion.zone_of(_hub.COVE_GATE) == 4)

## ---- PHASE GEOMETRY --------------------------------------------------------

func _phase_geometry() -> void:
	print("\nPHASE GEOMETRY")
	# The drawn sea IS HubRegion's disc (the second-spelling gate).
	var sea: MeshInstance3D = _cove.sea_node()
	var disc := sea.mesh as CylinderMesh
	_check("sea disc drawn at HubRegion.SEA_CENTRE", _flat(sea.global_position).distance_to(HubRegion.SEA_CENTRE) < 0.01, str(sea.global_position))
	_check("sea disc radius is HubRegion.SEA_RADIUS", disc != null and absf(disc.top_radius - HubRegion.SEA_RADIUS) < 0.001)
	# Castle spots: on the wet strip, walkable, in the cove, dry.
	for i in HubCove.CASTLE_SPOTS.size():
		var spot: Vector3 = HubCove.CASTLE_SPOTS[i]
		var d: float = HubRegion.shore_distance(spot)
		_check("castle spot %d on the wet strip (1.5..4.5 u from the water)" % i, d > 1.5 and d < 4.5, "%.2f" % d)
		_check("castle spot %d walkable, in the cove" % i, HubRegion.contains(spot) and HubRegion.zone_of(spot) == 4)
		var approach: Vector3 = _cove.approach_point(i)
		_check("castle approach %d walkable and dry" % i, HubRegion.contains(approach) and not HubRegion.in_sea(approach))
	for i in HubCove.BUOYS.size():
		_check("buoy %d floats in the sea" % i, HubRegion.in_sea(HubCove.BUOYS[i]), "%.2f" % HubRegion.shore_distance(HubCove.BUOYS[i]))
	# Every fixed prop, the parks and the docks stand on dry walkable sand.
	for spec in HubCove.PROPS:
		var at: Vector3 = spec["at"]
		_check("prop %s at %s dry and walkable" % [spec["glb"], at], HubRegion.contains(at) and HubRegion.shore_distance(at) > 1.0)
	_check("burrow dry and walkable", HubRegion.contains(HubCove.BURROW_AT) and HubRegion.shore_distance(HubCove.BURROW_AT) > 3.0)
	_check("sign stands in the moor", HubRegion.contains(HubCove.SIGN_AT) and HubRegion.zone_of(HubCove.SIGN_AT) == 2)
	_check("yacht park dry and walkable", HubRegion.contains(HubTransport.YACHT_PARK) and HubRegion.shore_distance(HubTransport.YACHT_PARK) > 3.0)
	# The coral line: both docks in region and dry, and clear of every
	# footprint by their own radius (a dock inside a parasol is a dock
	# nobody can tap).
	var line: int = -1
	for i in HubTransport.LINES.size():
		if HubTransport.LINES[i]["name"] == "corail":
			line = i
	_check("the coral line exists", line >= 0)
	if line >= 0:
		var docks: Array = HubTransport.LINES[line]["docks"]
		_check("coral plateau dock in zone 0", HubRegion.contains(docks[0]) and HubRegion.zone_of(docks[0]) == 0)
		_check("coral cove dock in zone 4 and dry", HubRegion.contains(docks[1]) and HubRegion.zone_of(docks[1]) == 4 and HubRegion.shore_distance(docks[1]) > 2.0)
		var builder: Node = _hub.get_node("WorldViewport/SubViewport/World/Props")
		for d in 2:
			var best := INF
			var who := ""
			var all: Array = []
			all.append_array(builder.ground_footprints())
			all.append_array(HubTrees.footprints())
			all.append_array(HubCritters.footprints())
			all.append_array(HubCove.footprints())
			for fp in HubTransport.footprints():
				if (fp["position"] as Vector3).distance_to(docks[d]) > 0.1:
					all.append(fp)
			for fp in all:
				var dist: float = Vector2(docks[d].x - fp["position"].x, docks[d].z - fp["position"].z).length() - float(fp["radius"])
				if dist < best:
					best = dist
					who = str(fp["position"])
			_check("coral dock %d clears every footprint by its own radius" % d, best >= HubTransport.DOCK_FOOTPRINT - 0.3, "%.2f to %s" % [best, who])
	# The cove's own footprints do not overlap each other or the transport's.
	var overlaps := 0
	var mine: Array = HubCove.footprints()
	mine.append_array(HubTransport.footprints())
	for a in mine.size():
		for b in range(a + 1, mine.size()):
			var pa: Vector3 = mine[a]["position"]
			var pb: Vector3 = mine[b]["position"]
			if not HubRegion.in_cove(pa) and not HubRegion.in_cove(pb):
				continue
			# A deckchair stands under its parasol by design (the chair's
			# disc is the chair, the parasol's is its canopy's shade).
			if _is_deckchair(pa) or _is_deckchair(pb):
				continue
			if pa.distance_to(pb) < float(mine[a]["radius"]) + float(mine[b]["radius"]) - 0.6:
				overlaps += 1
				print("    overlap %s r%.1f / %s r%.1f" % [pa, mine[a]["radius"], pb, mine[b]["radius"]])
	_check("no two cove footprints overlap", overlaps == 0, str(overlaps))
	# The road to the cove stays clear of every footprint (it is drawn by
	# the scatter, so the check reads the scatter's samples).
	var scatter: Node = _hub.get_node("WorldViewport/SubViewport/World/CozyScatter")
	var road: Array = scatter._catmull_rom(scatter.COVE_ROAD, 7)
	var road_hits := 0
	var blockers: Array = HubCritters.footprints()
	blockers.append_array(HubCove.footprints())
	blockers.append_array(HubTransport.footprints())
	for q in road:
		for fp in blockers:
			if Vector2(q.x - fp["position"].x, q.z - fp["position"].z).length() < float(fp["radius"]) - 0.2:
				road_hits += 1
				print("    road sample %s inside footprint %s r%.1f" % [q, fp["position"], fp["radius"]])
	_check("cove road clear of props", road_hits == 0, str(road_hits))
	var off_region := 0
	for q in road:
		if not HubRegion.contains(q):
			off_region += 1
	_check("cove road entirely on walkable ground", off_region == 0, str(off_region))
	# The scatter sowed the cove (blind: counts are positive, and nothing
	# palm-shaped stands in the sea).
	var stats: Dictionary = scatter.stats()
	_check("palms were sown", int(stats.get("palm", 0)) >= 12, str(stats.get("palm", 0)))
	_check("shells were sown", int(stats.get("shell", 0)) >= 6, str(stats.get("shell", 0)))
	var wet_palms := 0
	for child in scatter.get_children():
		if not (child is MultiMeshInstance3D) or not child.name.begins_with("palm"):
			continue
		var mm: MultiMesh = child.multimesh
		for k in mm.instance_count:
			var o: Vector3 = mm.get_instance_transform(k).origin
			if HubRegion.shore_distance(o) < 2.0:
				wet_palms += 1
	_check("no palm in the water", wet_palms == 0, str(wet_palms))
	# The burrow slot: present, empty, on dry sand, facing the sea.
	var slot: ModelSlot = _cove.burrow_slot()
	_check("burrow slot exists and is empty", slot != null and not slot.has_model())
	if slot != null:
		var at: Vector3 = slot.global_position
		var forward: Vector3 = slot.global_transform.basis.z
		_check("burrow slot stands on dry walkable sand", HubRegion.contains(at) and HubRegion.shore_distance(at) > 3.0, str(at))
		_check("burrow slot faces the sea (+x)", forward.x > 0.9, str(forward))

func _is_deckchair(at: Vector3) -> bool:
	for spec in HubCove.PROPS:
		if String(spec["glb"]).begins_with("deckchair") and (spec["at"] as Vector3).distance_to(at) < 0.01:
			return true
	return false

## ---- PHASE SAVE ------------------------------------------------------------

class FakeClock extends "res://scripts/autoload/WorldSave.gd":
	var now: int = 1_000_000
	func _now() -> int:
		return now

func _fresh() -> FakeClock:
	var s := FakeClock.new()
	s._data = s._defaults()
	return s

func _phase_save() -> void:
	print("\nPHASE SAVE (schema 2)")
	var path := "user://cove_probe_save.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	# A REAL v1 document, as V4/V7 wrote it.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 1, "saved_at": 5, "resources": {"acorn": 5, "hazelnut": 2},
		"trees": {"t1": {"stock": 1, "at": 10}}, "ground": [[1.0, 2.0, "acorn"]],
		"stats": {"climbs": 3, "kart_laps": 2}, "next_id": 7, "placed": [{"id": 3}], "kart": {"best_ms": {"circuit": 41000}}}))
	f.close()
	var a := _fresh()
	a.SAVE_PATH_OVERRIDE = path
	a.now = 10
	a._load()
	_check("v1 boots as migrated", a.boot_status == "migrated", a.boot_status)
	_check("v1 acorns kept", a.resource(&"acorn") == 5, str(a.resource(&"acorn")))
	_check("v1 tree kept", a.tree_stock("t1") == 1)
	_check("v1 stats kept", a.stats().get("climbs", 0) == 3 and a.stats().get("kart_laps", 0) == 2)
	_check("v1 kart best kept", a.kart_best_ms("circuit") == 41000)
	_check("v1 reserved fields kept", a.next_id() == 7 and a.placed().size() == 1)
	_check("v1 has an empty cove", a.cove_castles().is_empty() and a.cove_yacht() == Vector3.INF and not a.cove_visited())
	a.save_now()
	var b := _fresh()
	b.SAVE_PATH_OVERRIDE = path
	b._load()
	_check("re-saved document is schema 2, boots loaded", b.boot_status == "loaded" and int(b._data["schema"]) == 2, b.boot_status)
	# Positive: the cove block round-trips.
	b.cove_set_castle(1, 2)
	b.cove_set_castle(2, 3)
	b.cove_set_yacht(Vector3(48.25, 0.0, -112.5))
	b.cove_note_visit()
	b.cove_note_visit()
	b.save_now()
	var c := _fresh()
	c.SAVE_PATH_OVERRIDE = path
	c._load()
	_check("castles round-trip", c.cove_castle_stage(1) == 2 and c.cove_castle_stage(2) == 3 and c.cove_castle_stage(0) == 0, str(c.cove_castles()))
	_check("yacht round-trips", c.cove_yacht().distance_to(Vector3(48.25, 0.0, -112.5)) < 0.02, str(c.cove_yacht()))
	_check("visit round-trips, counted once", c.cove_visited() and c.stats().get("cove_visits", 0) == 1, str(c.stats()))
	c.cove_set_castle(2, 0)
	_check("stage 0 erases the entry", not c.cove_castles().has("2"))
	# Malformed cove pieces are dropped, never the document.
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 2, "resources": {"acorn": 9},
		"cove": {"yacht": [1.0], "castles": {"1": 2, "x": 1, "2": 9, "0": "3"}, "visited": "yes"}}))
	f.close()
	var d := _fresh()
	d.SAVE_PATH_OVERRIDE = path
	d._load()
	_check("malformed cove: document still loads", d.boot_status == "loaded" and d.resource(&"acorn") == 9, d.boot_status)
	_check("malformed cove: bad yacht dropped", d.cove_yacht() == Vector3.INF)
	_check("malformed cove: only valid castles kept", d.cove_castle_stage(1) == 2 and d.cove_castle_stage(2) == 0 and d.cove_castle_stage(0) == 3 and d.cove_castles().size() == 2, str(d.cove_castles()))
	_check("malformed cove: non-bool visited reads false", not d.cove_visited())
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 3, "resources": {"acorn": 9}}))
	f.close()
	var e := _fresh()
	e.SAVE_PATH_OVERRIDE = path
	e._load()
	_check("schema 3 is still the future", e.boot_status == "future")
	DirAccess.remove_absolute(path)

## ---- PHASE WALK -------------------------------------------------------------

func _phase_walk() -> void:
	print("\nPHASE WALK")
	var centre := Vector3(56.0, 0.0, -110.0)
	_put_keepy(Vector3(0.0, 0.0, -106.0))
	await _frames(2)
	_hub._on_tapped_ground(centre)
	await _frames(2)
	_check("moor -> cove aims at the cove gate first", _hub._via_expect == _hub.COVE_GATE, str(_hub._via_expect))
	var reached_gate := false
	var left_region := 0
	for i in 1200:
		await get_tree().process_frame
		var here := _flat(_keepy.global_position)
		if here.distance_to(_hub.COVE_GATE) < 2.0:
			reached_gate = true
		if not _keepy.is_hopping() and not HubRegion.contains(here):
			left_region += 1
		if not _keepy.is_hopping() and _hub._via_expect == Vector3.INF and not _keepy._has_target:
			break
	_check("the walk passed the cove gate", reached_gate)
	_check("the walk never landed off the region", left_region == 0, str(left_region))
	_check("and ended in the cove", HubRegion.zone_of(_keepy.global_position) == 4 and _flat(_keepy.global_position).distance_to(centre) < 1.0, str(_keepy.global_position))
	# Back the other way, from the cove to the plateau: three gates.
	_hub._on_tapped_ground(Vector3(0.0, 0.0, -10.0))
	await _frames(2)
	_check("cove -> plateau aims at the cove gate first", _hub._via_expect == _hub.COVE_GATE, str(_hub._via_expect))
	var saw_moor := false
	var saw_corridor := false
	for i in 3000:
		await get_tree().process_frame
		var here := _flat(_keepy.global_position)
		if here.distance_to(_hub.MOOR_GATE) < 2.0:
			saw_moor = true
		if here.distance_to(_hub.CORRIDOR_GATE) < 2.0:
			saw_corridor = true
		if not _keepy.is_hopping() and _hub._via_expect == Vector3.INF and not _keepy._has_target:
			break
	_check("the walk home passed the moor gate", saw_moor)
	_check("and the corridor gate", saw_corridor)
	_check("and ended on the plateau", HubRegion.zone_of(_keepy.global_position) == 0 and _flat(_keepy.global_position).distance_to(Vector3(0.0, 0.0, -10.0)) < 1.0, str(_keepy.global_position))

## ---- PHASE CASTLE -----------------------------------------------------------

func _phase_castle() -> void:
	print("\nPHASE CASTLE")
	await _weather_settle(CozyWeather.Kind.SUN)
	var spot := 1
	_put_keepy(_cove.approach_point(spot) + Vector3(-6.0, 0.0, 0.0))
	await _frames(2)
	_check("blind: nothing stands on the spot yet", _cove.castle_drawn_scale(spot) == 0.0 and _cove.castle_stage(spot) == 0)
	_check("the spot accepts a tap", _cove.accepts_castle_tap(HubCove.CASTLE_SPOTS[spot] + Vector3(0.4, 0.0, 0.2)) == spot)
	_check("a tap beside the spot is a walk", _cove.accepts_castle_tap(HubCove.CASTLE_SPOTS[spot] + Vector3(2.5, 0.0, 0.0)) == -1)
	_hub._on_tapped_castle(HubCove.CASTLE_SPOTS[spot], spot)
	await _frames(1)
	_check("intent armed", _hub._building_castle == spot)
	await _settle(600)
	await _frames(2)
	_check("the walk built stage 1", _cove.castle_stage(spot) == 1, str(_cove.castle_stage(spot)))
	_check("intent released", _hub._building_castle == -1)
	_check("Keepy stands at the approach point", _flat(_keepy.global_position).distance_to(_cove.approach_point(spot)) < 0.6, str(_keepy.global_position))
	# WITHDRAWAL while rising (the boat's rule): the spot refuses a tap.
	_check("the rising spot withdraws from the tap", _cove.accepts_castle_tap(HubCove.CASTLE_SPOTS[spot]) == -1)
	var mid: float = _cove.castle_drawn_scale(spot)
	await _frames(int(HubCove.CASTLE_BUILD_S * 60.0) + 10)
	var done: float = _cove.castle_drawn_scale(spot)
	_check("the castle rose (blind: the scale moved)", done > mid and done > 0.5, "%.3f -> %.3f" % [mid, done])
	_check("stage 1 drawn at its scale", absf(done - HubCove.CASTLE_STAGE_SCALE[0]) < 0.02, "%.3f" % done)
	_check("the finished spot accepts a tap again", _cove.accepts_castle_tap(HubCove.CASTLE_SPOTS[spot]) == spot)
	_check("saved: stage 1", WorldSave.cove_castle_stage(spot) == 1 and WorldSave.stats().get("castles_built", 0) == 1)
	# Second and third tap from where he stands (zero-length walk: the
	# immediate try, never a landing).
	_hub._on_tapped_castle(HubCove.CASTLE_SPOTS[spot], spot)
	await _frames(int(HubCove.CASTLE_BUILD_S * 60.0) + 10)
	_check("second tap: stage 2", _cove.castle_stage(spot) == 2 and absf(_cove.castle_drawn_scale(spot) - HubCove.CASTLE_STAGE_SCALE[1]) < 0.02, "%.3f" % _cove.castle_drawn_scale(spot))
	var flag: MeshInstance3D = _cove._castles[spot]["flag"]
	_check("no flag before the last stage", not flag.visible)
	_hub._on_tapped_castle(HubCove.CASTLE_SPOTS[spot], spot)
	await _frames(int(HubCove.CASTLE_BUILD_S * 60.0) + 10)
	_check("third tap: stage 3 with the flag", _cove.castle_stage(spot) == 3 and flag.visible and absf(_cove.castle_drawn_scale(spot) - 1.0) < 0.02)
	_check("saved: stage 3, three builds", WorldSave.cove_castle_stage(spot) == 3 and WorldSave.stats().get("castles_built", 0) == 3)
	# A fourth tap is not dropped and does not overflow.
	_hub._on_tapped_castle(HubCove.CASTLE_SPOTS[spot], spot)
	await _frames(70)
	_check("a fourth tap keeps stage 3", _cove.castle_stage(spot) == 3 and _hub._building_castle == -1)
	# A tap elsewhere during the approach cancels (boat pattern).
	var other := 0
	_put_keepy(_cove.approach_point(other) + Vector3(-8.0, 0.0, 0.0))
	await _frames(2)
	_hub._on_tapped_castle(HubCove.CASTLE_SPOTS[other], other)
	await _frames(20)
	_hub._on_tapped_ground(_cove.approach_point(other) + Vector3(-3.0, 0.0, -4.0))
	await _frames(2)
	_check("a ground tap during the approach cancels the castle intent", _hub._building_castle == -1)
	await _settle(400)
	_check("and no castle was built there", _cove.castle_stage(other) == 0 and WorldSave.cove_castle_stage(other) == 0)
	# Restore across a boot: a fresh HubCove reads the save.
	var probe_cove := HubCove.new()
	add_child(probe_cove)
	probe_cove.setup(_keepy, _weather)
	await _frames(1)
	_check("a fresh cove restores stage 3 from the save, whole", probe_cove.castle_stage(spot) == 3 and absf(probe_cove.castle_drawn_scale(spot) - 1.0) < 0.001, "%.3f" % probe_cove.castle_drawn_scale(spot))
	probe_cove.queue_free()

## ---- PHASE WEATHER ----------------------------------------------------------

func _phase_weather() -> void:
	print("\nPHASE WEATHER")
	await _weather_settle(CozyWeather.Kind.SUN)
	var spot := 1
	if _cove.castle_stage(spot) == 0:
		_put_keepy(_cove.approach_point(spot))
		await _frames(2)
		_hub._on_tapped_castle(HubCove.CASTLE_SPOTS[spot], spot)
		await _frames(int(HubCove.CASTLE_BUILD_S * 60.0) + 10)
	var full: float = _cove.castle_drawn_scale(spot)
	_check("blind: a castle stands before the rain", full > 0.5, "%.3f" % full)
	_check("lamp off in the sun", _cove.lamp_lit() < 0.01 and not _cove._beam.visible)
	var buoy: MeshInstance3D = _cove._buoys[0]
	var y0: float = buoy.position.y
	await _frames(30)
	_check("blind: the buoy bobs in the sun", absf(buoy.position.y - y0) > 0.001)
	# Rain: the lamp lights, the beam sweeps, the castle melts.
	await _weather_settle(CozyWeather.Kind.RAIN)
	_check("lamp lit in the rain", _cove.lamp_lit() > 0.99 and _cove._beam.visible, "%.2f" % _cove.lamp_lit())
	var beam_a: float = _cove._beam.rotation.y
	await _frames(30)
	_check("the beam turns", absf(_cove._beam.rotation.y - beam_a) > 0.05)
	var before: float = _cove.castle_drawn_scale(spot)
	await _frames(120)
	var after: float = _cove.castle_drawn_scale(spot)
	_check("the castle melts in the rain (blind: it shrank in 2 s)", after < before - 0.03, "%.3f -> %.3f" % [before, after])
	# Storm melts it away; the save forgets it.
	await _weather_settle(CozyWeather.Kind.STORM)
	var gone := false
	for i in int(HubCove.CASTLE_MELT_STORM_S * 60.0) + 120:
		await get_tree().process_frame
		if _cove.castle_stage(spot) == 0:
			gone = true
			break
	_check("the storm melts the castle away", gone and _cove.castle_drawn_scale(spot) == 0.0)
	_check("saved: the spot is empty again", WorldSave.cove_castle_stage(spot) == 0)
	var castle: MeshInstance3D = _cove._castles[spot]["castle"]
	_check("the melted castle is hidden and unscaled for its next life", not castle.visible and castle.scale.is_equal_approx(Vector3.ONE))
	var storm_wind: float = float(_weather.current_look().get("wind", 1.0))
	_check("blind: the storm's wind is above the sun's", storm_wind > 2.0, "%.2f" % storm_wind)
	await _weather_settle(CozyWeather.Kind.SUN)
	_check("lamp off again in the sun", _cove.lamp_lit() < 0.01 and not _cove._beam.visible)
	# It can be rebuilt after the rain (nothing stuck).
	_put_keepy(_cove.approach_point(spot))
	await _frames(2)
	_hub._on_tapped_castle(HubCove.CASTLE_SPOTS[spot], spot)
	await _frames(int(HubCove.CASTLE_BUILD_S * 60.0) + 10)
	_check("rebuilt after the rain, stage 1 from nothing", _cove.castle_stage(spot) == 1 and absf(_cove.castle_drawn_scale(spot) - HubCove.CASTLE_STAGE_SCALE[0]) < 0.02, "%.3f" % _cove.castle_drawn_scale(spot))
	_weather.force_auto()
	await _weather_settle(CozyWeather.Kind.SUN)

## ---- PHASE YACHT -------------------------------------------------------------

func _phase_yacht() -> void:
	print("\nPHASE YACHT")
	await _weather_settle(CozyWeather.Kind.SUN)
	var park: Vector3 = HubTransport.YACHT_PARK
	_check("blind: the yacht waits at its park", _transport.yacht_position().distance_to(park) < 0.01, str(_transport.yacht_position()))
	_check("blind: not on a vehicle", not _keepy.is_on_vehicle())
	_check("the park accepts a vehicle tap and names the yacht", _transport.vehicle_at(park + Vector3(0.5, 0.0, 0.3)) == HubTransport.VEHICLE_YACHT)
	_check("the ball's park still names the ball", _transport.vehicle_at(HubTransport.BALL_PARK) == HubTransport.VEHICLE_BALL)
	# Inside the cove: (43, -110) is the HEDGE band, not the region, and a
	# body placed there reads as zone 0 and routes via the plateau gate
	# (the first run of this phase did exactly that).
	_put_keepy(park + Vector3(-3.0, 0.0, 2.0))
	_check("blind: the start stands in the cove", HubRegion.zone_of(_keepy.global_position) == 4 and HubRegion.contains(_keepy.global_position))
	await _frames(2)
	_hub._on_tapped_vehicle(park)
	await _settle(400)
	await _frames(2)
	_check("the walk mounted the yacht", _keepy.is_on_vehicle() and _keepy.is_gliding() and _keepy.vehicle_node() == _transport.yacht_node())
	_check("he stands on the seat (YACHT_SEAT_Y)", absf(_keepy.global_position.y - HubTransport.YACHT_SEAT_Y) < 0.01, "%.3f" % _keepy.global_position.y)
	_check("saved: one ride", WorldSave.stats().get("yacht_rides", 0) == 1)
	_check("the yacht withdraws from the tap while ridden", _transport.vehicle_at(_transport.yacht_position()) == -1)
	# A glide: flat, unsquashed, at the authored pace.
	var start := _flat(_keepy.global_position)
	var target := start + Vector3(0.0, 0.0, -18.0)
	_check("glide target is in the cove", HubRegion.contains(target) and HubRegion.zone_of(target) == 4)
	var base_scale: Vector3 = _keepy._base_scale
	var max_dy := 0.0
	var max_dscale := 0.0
	var yacht_max_dy := 0.0
	var yacht_under := 0
	var samples := 0
	_hub._on_tapped_ground(target)
	var frames := 0
	for i in 600:
		await get_tree().process_frame
		frames += 1
		if _keepy.is_hopping():
			samples += 1
			max_dy = maxf(max_dy, absf(_keepy.global_position.y - HubTransport.YACHT_SEAT_Y))
			max_dscale = maxf(max_dscale, (_keepy._body.scale - base_scale).length())
			var yp: Vector3 = _transport.yacht_node().global_position
			yacht_max_dy = maxf(yacht_max_dy, absf(yp.y))
			if _flat(yp).distance_to(_flat(_keepy.global_position)) < 0.01:
				yacht_under += 1
		if not _keepy.is_hopping() and not _keepy._has_target:
			break
	var dist: float = start.distance_to(_flat(_keepy.global_position))
	var speed: float = dist / (float(frames) / 60.0)
	print("    glide: %.2f u in %d frames = %.2f u/s (%d samples)" % [dist, frames, speed, samples])
	_check("blind: the glide was sampled in flight", samples > 20)
	_check("the glide is flat: no arc on the rider", max_dy < 0.01, "%.4f" % max_dy)
	_check("no squash on a glide", max_dscale < 0.001, "%.4f" % max_dscale)
	_check("the yacht stays on the ground and under him every frame", yacht_max_dy < 0.001 and yacht_under == samples, "%d/%d" % [yacht_under, samples])
	var expected: float = HubTransport.YACHT_GLIDE_DISTANCE / HubTransport.YACHT_GLIDE_S
	_check("pace is the authored glide (x1.0 in the sun)", absf(speed - expected) / expected < 0.12, "%.2f vs %.2f" % [speed, expected])
	_check("arrived", dist > 17.0 and _flat(_keepy.global_position).distance_to(target) < 0.6, "%.2f" % dist)
	# Storm: faster, by the wind factor.
	await _weather_settle(CozyWeather.Kind.STORM)
	await _frames(2)
	var storm_factor: float = _transport.yacht_speed_factor()
	_check("storm pushes the factor to the cap", absf(storm_factor - HubTransport.YACHT_WIND_MAX) < 0.001, "%.3f" % storm_factor)
	start = _flat(_keepy.global_position)
	target = start + Vector3(0.0, 0.0, 18.0)
	_hub._on_tapped_ground(target)
	frames = 0
	for i in 600:
		await get_tree().process_frame
		frames += 1
		if not _keepy.is_hopping() and not _keepy._has_target:
			break
	var storm_speed: float = start.distance_to(_flat(_keepy.global_position)) / (float(frames) / 60.0)
	print("    storm glide: %.2f u/s" % storm_speed)
	_check("the storm glide is faster by the factor", absf(storm_speed / speed - storm_factor) < 0.12, "%.2f / %.2f = %.3f vs %.3f" % [storm_speed, speed, storm_speed / speed, storm_factor])
	await _weather_settle(CozyWeather.Kind.SUN)
	# Region: a tap far out to sea ends on the cove's edge, never off it.
	# Through the clamp, as HubTapInput hands every destination (a raw
	# point is not something a player can emit) -- and the world clamps
	# once more on its own since this phase first rode 130 u off the map.
	var off := 0
	_hub._on_tapped_ground(HubRegion.clamp_to(Vector3(400.0, 0.0, -110.0)))
	for i in 900:
		await get_tree().process_frame
		if not HubRegion.contains(_keepy.global_position):
			off += 1
		if not _keepy.is_hopping() and not _keepy._has_target:
			break
	_check("a glide out to sea stops on the region's edge", off == 0 and absf(_keepy.global_position.x - HubRegion.COVE_MAX.x) < 0.6, "%d off, x=%.2f" % [off, _keepy.global_position.x])
	# Cross-zone on the yacht: gates still apply, the yacht comes along.
	_hub._on_tapped_ground(Vector3(0.0, 0.0, -106.0))
	await _frames(2)
	_check("a cross-zone glide aims at the cove gate first", _hub._via_expect == _hub.COVE_GATE)
	off = 0
	for i in 1200:
		await get_tree().process_frame
		if not _keepy.is_hopping() and not HubRegion.contains(_keepy.global_position):
			off += 1
		if not _keepy.is_hopping() and _hub._via_expect == Vector3.INF and not _keepy._has_target:
			break
	_check("the glide reached the moor still mounted", HubRegion.zone_of(_keepy.global_position) == 2 and _keepy.is_on_vehicle(), str(_keepy.global_position))
	_check("never landed off the region on the way", off == 0, str(off))
	_check("the yacht is under him in the moor", _transport.yacht_position().distance_to(_flat(_keepy.global_position)) < 0.01)
	# Dismount: a tap on himself. The yacht stays, and the save knows where.
	_hub._on_tapped_ground(_flat(_keepy.global_position) + Vector3(0.2, 0.0, 0.1))
	await _frames(2)
	_check("a tap on himself dismounts", not _keepy.is_on_vehicle() and absf(_keepy.global_position.y) < 0.001)
	var left_at: Vector3 = _transport.yacht_position()
	_check("the yacht stays where he stepped off", left_at.distance_to(_flat(_keepy.global_position)) < 0.5)
	_check("saved: the yacht's place", WorldSave.cove_yacht().distance_to(left_at) < 0.02, str(WorldSave.cove_yacht()))
	# Not re-parked by the off-screen rule: walk him far away and let the
	# transport run its update for a while.
	_put_keepy(Vector3(0.0, 0.0, 0.0))
	await _frames(120)
	_check("the yacht is not re-parked when abandoned", _transport.yacht_position().distance_to(left_at) < 0.01, str(_transport.yacht_position()))
	# A fresh transport reads the saved place (blind: it is not the park).
	var t2 := HubTransport.new()
	add_child(t2)
	await _frames(1)
	_check("a fresh transport puts the yacht where it was left", t2.yacht_position().distance_to(left_at) < 0.02 and left_at.distance_to(park) > 5.0, str(t2.yacht_position()))
	t2.queue_free()
	# Ball and yacht are exclusive: on the ball, a walk to the yacht drops
	# the ball and takes the yacht.
	_put_keepy(left_at + Vector3(-4.0, 0.0, 0.0))
	await _frames(2)
	var ball: Node3D = _transport.ball_node()
	ball.global_position = _flat(_keepy.global_position) + Vector3(-1.0, 0.0, 0.0)
	_hub._on_tapped_vehicle(_transport.ball_position())
	await _settle(200)
	await _frames(2)
	_check("on the ball first", _keepy.is_on_vehicle() and not _keepy.is_gliding())
	_hub._on_tapped_vehicle(left_at)
	await _settle(300)
	await _frames(2)
	_check("the yacht tap on the ball swaps vehicles", _keepy.is_on_vehicle() and _keepy.is_gliding())
	# Dropped where he STOOD when the swap happened, i.e. at the yacht.
	_check("the ball was left on the ground beside the yacht", absf(ball.global_position.y) < 0.001 and _transport.ball_position().distance_to(left_at) < 2.5, str(_transport.ball_position()))
	_hub._on_tapped_ground(_flat(_keepy.global_position) + Vector3(0.1, 0.0, 0.1))
	await _frames(2)
	_check("dismounted again", not _keepy.is_on_vehicle())
	ball.global_position = HubTransport.BALL_PARK
	WorldSave.cove_set_yacht(park)
	_transport.yacht_node().global_position = park

## ---- PHASE BALLOON -----------------------------------------------------------

func _phase_balloon() -> void:
	print("\nPHASE BALLOON (coral line)")
	var line: int = -1
	for i in HubTransport.LINES.size():
		if HubTransport.LINES[i]["name"] == "corail":
			line = i
	if line < 0:
		_check("the coral line exists", false)
		return
	# Parked at the plateau dock first: the re-mooring rule (far from both
	# docks, neither on screen -- and headless, NOTHING is ever on screen)
	# may have moved it to the cove dock during the phases before this one.
	_transport._park(line, 0)
	_check("the coral balloon waits at the plateau dock", _transport.balloon_at(line) == 0)
	var dock0: Vector3 = _transport.dock_position(line, 0)
	var dock1: Vector3 = _transport.dock_position(line, 1)
	_put_keepy(dock0 + Vector3(4.0, 0.0, 4.0))
	await _frames(2)
	_check("the dock accepts a balloon tap", _transport.accepts_balloon_tap(dock0) == line)
	_hub._on_tapped_balloon(dock0)
	var boarded_frame := -1
	var landed_frame := -1
	var max_y := 0.0
	for i in 1500:
		await get_tree().process_frame
		if boarded_frame < 0 and _keepy.is_on_carrier():
			boarded_frame = i
		if boarded_frame >= 0:
			max_y = maxf(max_y, _keepy.global_position.y)
			if not _keepy.is_on_carrier() and not _keepy.is_hopping():
				landed_frame = i
				break
	_check("he boarded", boarded_frame >= 0)
	_check("he flew (blind: he rose)", max_y > 3.0, "%.2f" % max_y)
	_check("the trip ended", landed_frame > boarded_frame)
	var here := _flat(_keepy.global_position)
	_check("he stepped off by the cove dock, in the cove", HubRegion.zone_of(here) == 4 and here.distance_to(dock1) < HubTransport.DOCK_TAP_RADIUS + 2.0, str(here))
	_check("landing is walkable and dry", HubRegion.contains(here) and not HubRegion.in_hole(here) and HubRegion.shore_distance(here) > 0.5)
	_check("the balloon now waits at the cove dock", _transport.balloon_at(line) == 1)
	print("    coral flight: %d frames = %.2f s from tap to feet on the sand" % [landed_frame, landed_frame / 60.0])
	# The other lines are what they were (regression).
	_check("gold line untouched", HubTransport.LINES[0]["docks"][0] == Vector3(10.5, 0.0, 14.5) and HubTransport.LINES[0]["docks"][1] == Vector3(11.0, 0.0, -55.0))
	_check("sky line untouched", HubTransport.LINES[1]["docks"][0] == Vector3(-14.0, 0.0, -50.0) and HubTransport.LINES[1]["docks"][1] == Vector3(-6.0, 0.0, -110.0))

## ---- PHASE TIMES --------------------------------------------------------------
## The travel-time table: walks measured on this build, rides measured on
## this build. Walks are not asserted against a number (the walk is not
## this lot's to change); the rides are asserted to BEAT the walk.

func _walk_time(from: Vector3, to: Vector3) -> float:
	_keepy.dismount_vehicle()
	_put_keepy(from)
	await _frames(2)
	_hub._on_tapped_ground(to)
	var frames: int = await _settle(4000)
	return float(frames) / 60.0

func _phase_times() -> void:
	print("\nPHASE TIMES")
	await _weather_settle(CozyWeather.Kind.SUN)
	var cove_centre := Vector3(56.0, 0.0, -110.0)
	var cove_dock: Vector3 = _transport.dock_position(2, 1)
	var plateau_dock: Vector3 = _transport.dock_position(2, 0)
	var spawn := Vector3.ZERO
	var t_walk_spawn_cove: float = await _walk_time(spawn, cove_centre)
	print("TIME walk spawn -> cove centre: %.2f s" % t_walk_spawn_cove)
	var t_walk_to_dock: float = await _walk_time(spawn, plateau_dock + Vector3(1.5, 0.0, 1.5))
	print("TIME walk spawn -> coral plateau dock: %.2f s" % t_walk_to_dock)
	# The balloon, from the dock (the balloon must wait there).
	if _transport.balloon_at(2) != 0:
		_transport._park(2, 0)
	_hub._on_tapped_balloon(plateau_dock)
	var frames := 0
	for i in 1500:
		await get_tree().process_frame
		frames += 1
		if i > 30 and not _keepy.is_on_carrier() and not _keepy.is_hopping() and not _keepy._has_target:
			break
	var t_fly: float = float(frames) / 60.0
	var t_walk_dock_to_centre: float = await _walk_time(_flat(_keepy.global_position), cove_centre)
	var t_after_balloon: float = t_walk_to_dock + t_fly + t_walk_dock_to_centre
	print("TIME coral: walk %.2f + flight %.2f + walk %.2f = %.2f s spawn -> cove centre" % [t_walk_to_dock, t_fly, t_walk_dock_to_centre, t_after_balloon])
	_check("the coral line beats the walk from spawn", t_after_balloon < t_walk_spawn_cove * 0.75, "%.2f vs %.2f" % [t_after_balloon, t_walk_spawn_cove])
	# The yacht, cove -> circuit gate and cove -> moor centre, vs the walk.
	var circuit_gate: Vector3 = _hub.CIRCUIT_GATE
	var moor_centre := Vector3(0.0, 0.0, -106.0)
	var t_walk_cove_circuit: float = await _walk_time(cove_centre, circuit_gate)
	print("TIME walk cove centre -> circuit gate: %.2f s" % t_walk_cove_circuit)
	var t_walk_cove_moor: float = await _walk_time(cove_centre, moor_centre)
	print("TIME walk cove centre -> moor centre: %.2f s" % t_walk_cove_moor)
	var t_walk_moor_cove: float = await _walk_time(moor_centre, cove_centre)
	print("TIME walk moor centre -> cove centre: %.2f s" % t_walk_moor_cove)
	_put_keepy(cove_centre)
	_transport.yacht_node().global_position = cove_centre + Vector3(0.0, 0.0, 1.0)
	await _frames(2)
	_hub._on_tapped_vehicle(_transport.yacht_position())
	await _settle(200)
	_check("mounted for the timing", _keepy.is_gliding())
	_put_keepy(cove_centre)
	_hub._on_tapped_ground(circuit_gate)
	var t_glide_cove_circuit: float = float(await _settle(4000)) / 60.0
	print("TIME yacht cove centre -> circuit gate: %.2f s (sun)" % t_glide_cove_circuit)
	_check("the yacht beats the walk to the circuit", t_glide_cove_circuit < t_walk_cove_circuit * 0.6, "%.2f vs %.2f" % [t_glide_cove_circuit, t_walk_cove_circuit])
	_hub._on_tapped_ground(moor_centre)
	var t_glide_circuit_moor: float = float(await _settle(4000)) / 60.0
	print("TIME yacht circuit gate -> moor centre: %.2f s (sun)" % t_glide_circuit_moor)
	_hub._on_tapped_ground(cove_centre)
	var t_glide_moor_cove: float = float(await _settle(4000)) / 60.0
	print("TIME yacht moor centre -> cove centre: %.2f s (sun)" % t_glide_moor_cove)
	_check("the yacht beats the walk moor -> cove", t_glide_moor_cove < t_walk_moor_cove * 0.6, "%.2f vs %.2f" % [t_glide_moor_cove, t_walk_moor_cove])
	_keepy.dismount_vehicle()
	_transport.yacht_node().global_position = HubTransport.YACHT_PARK
	WorldSave.cove_set_yacht(HubTransport.YACHT_PARK)
