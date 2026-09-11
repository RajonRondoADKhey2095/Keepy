extends Node
## CH71 -- THE FUNFAIR'S GATES: the coaster and the drop tower, ridden
## through the player's own channel, plus what they stand on and what
## they cost.
##
## =====================================================================
## ⚠️ THIS PROBE RUNS UNDER xvfb + opengl3, NEVER --headless
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
##     --path . res://scripts/dev/FunfairProbe.tscn
##
## Three phases need a real driver and say so: PHASE I reads MultiMesh
## transforms (identity under the dummy driver, CLAUDE.md CH50), PHASE C
## and PHASE H read PIXELS, and every ride is started from a SCREEN
## POINT through HubTapInput._handle_point, which returns before
## projecting anything when the container rect is 0x0 (CLAUDE.md: "chaque
## check passe en ne s'exécutant jamais"). PHASE I asserts the rect.
##
## =====================================================================
## WHAT THIS PROBE CANNOT SIGN
##
## Whether the drop feels like a drop, whether the tower reads as tall
## from a phone, whether a held finger is discoverable as a brake. Those
## are Mathieu's device call (CLAUDE.md CH62: a bench does not judge a
## game feel). What it signs is that the speed is a CURVE that moves,
## that the brake is WIRED to it (the braked run is measurably slower,
## and the unbraked control comes first), that both rides are BOUNDED
## and end with the rider standing on the ground where the fair said,
## that every tap made during a ride is dropped and none is swallowed,
## that nothing the fair draws leaves the frame, and what it costs.
##
## =====================================================================
## PHASES
##
##   I  instrument: rasterised frame, MultiMesh transforms, container rect
##   A  the fair as built vs what it publishes (two curve spellings agree,
##      every rail inside the square, the camera ceilings)
##   B  clearances: layout footprints, the zipline cable, the region,
##      the carpet kept off the fair (with its blind check)
##   C  winding judge, CH39's: cull_back vs cull_disabled, same pixels
##   D  D5: one static body, box shapes only, on the park layer, live
##   E  the coaster, twice, through the real tap channel: free, braked
##   F  the drop tower through the real tap channel
##   G  budget: primitives and triangles with the fair shown / hidden
##   H  pixels: the fair is SEEN from its own stations

const VP_SIZE: Vector2i = Vector2i(540, 960)
const SETTLE: int = 3
const BUDGET_S: float = 900.0
## The stations, flat. The tap stations are where the target is IN
## FRAME: the camera shows only lower z than Keepy, +-3.69 u wide at his
## own z (HubSkatepark's arithmetic).
const SPAWN := Vector3(0.0, 0.0, 0.0)
const COASTER_TAP_FROM := Vector3(27.0, 0.0, 26.0)
const TOWER_TAP_FROM := Vector3(33.3, 0.0, 18.0)
const DROP_VIEW := Vector3(32.0, 0.0, 40.0)
const CH22_WORST := Vector3(-5.0, 0.0, 35.0)
## A ground point far from any door, used for the "tap during a ride is
## dropped" checks and for the negative tap control.
const BARE_GROUND := Vector3(24.0, 0.0, 30.0)
## Keepy's crown above his origin, and the margin, as CLAUDE.md's tree
## seats use them (HubTrees' SEAT_MAX_Y derivation).
const CROWN: float = 1.7
const CROWN_MARGIN: float = 0.4
## Pixel margin inside the frame for the crown, on the probe's viewport.
const FRAME_MARGIN_PX: float = 24.0
const CABLE_CLEARANCE: float = 1.5
const P1 := Vector3(27.7, 0.0, 9.2)
const P2 := Vector3(25.2, 0.0, 35.0)
const CABLE_HEIGHT: float = 2.0

var _fails: int = 0
var _hub: Node = null
var _world: Node3D = null
var _keepy: KeepyHopper = null
var _camera: Camera3D = null
var _sub: SubViewport = null
var _scatter: Node = null
var _props: HubBuilder = null
var _overlay: Node = null
var _tap: HubTapInput = null
var _fair: HubFunfair = null
var _clearance: float = 0.0
var _finished_rides: Array = []

func _ready() -> void:
	ProbeWatchdog.arm(self, "FUNFAIR PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_world = _hub.get_node("WorldViewport/SubViewport/World") as Node3D
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as KeepyHopper
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport
	_scatter = _hub.get_node("WorldViewport/SubViewport/World/CozyScatter")
	_props = _world.get_node("Props") as HubBuilder
	_overlay = _hub.get_node_or_null("PerfOverlay")
	_tap = _hub.get_node("TapInput") as HubTapInput
	_fair = _world.get_node("Funfair") as HubFunfair
	if _overlay != null:
		_overlay.set_process(false)
	var consts: Dictionary = (_hub.get_script() as Script).get_script_constant_map()
	_clearance = float(consts.get("KEEPY_CLEARANCE", 0.0))
	_fair.ride_finished.connect(func(ride: int, _landing: Vector3): _finished_rides.append(ride))

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	_sub.size = VP_SIZE
	box.size = Vector2(VP_SIZE)
	_run()

func _run() -> void:
	print("=== FUNFAIR PROBE -- CH71 ===")
	print("  loop length %.3f u   crest s %.3f   lift foot s %.3f   peak rail y %.3f   triangles %d" % [
		_fair.track_length(), _fair.crest_s(), _fair.lift_foot_s(), _fair.peak_rail_y(), _fair.triangle_total()])
	print("")
	await _phase_i()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- nothing below would be worth reading. Stopping. ===")
		get_tree().quit(1)
		return
	_phase_a()
	_phase_b()
	await _phase_c()
	await _phase_d()
	await _phase_e()
	await _phase_f()
	await _phase_g()
	await _phase_h()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# HELPERS

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)

func _station(flat: Vector3) -> void:
	_keepy.global_position = HubSurface.ground(_flat(flat))
	_camera.call("snap_to_target")
	for _i in SETTLE:
		await get_tree().process_frame

func _to_screen(world: Vector3) -> Vector2:
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	var local: Vector2 = _camera.unproject_position(world)
	local.x *= rect.size.x / float(_sub.size.x)
	local.y *= rect.size.y / float(_sub.size.y)
	return local + rect.position

func _tap_world(world: Vector3) -> void:
	_tap._handle_point(_to_screen(world))

func _settle_walk(cap: int = 1200) -> int:
	var frames: int = 0
	await get_tree().process_frame
	frames += 1
	while _keepy.is_hopping() and frames < cap:
		await get_tree().process_frame
		frames += 1
	return frames

func _in_frame(world: Vector3, margin: float) -> bool:
	if _camera.is_position_behind(world):
		return false
	var p: Vector2 = _camera.unproject_position(world)
	return p.x >= margin and p.y >= margin and p.x <= float(_sub.size.x) - margin and p.y <= float(_sub.size.y) - margin

func _prims() -> int:
	return RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)

func _calls() -> int:
	return RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)

func _read() -> Dictionary:
	await get_tree().process_frame
	var rep: Dictionary = _overlay.call("snapshot") if _overlay != null else {}
	return {"gpu": _prims(), "calls": _calls(), "lod0": int(rep.get("tris_frame", -1)), "scene": int(rep.get("tris_scene", -1))}

func _frame() -> Image:
	await get_tree().process_frame
	await get_tree().process_frame
	return _sub.get_texture().get_image()

func _count_magenta(img: Image) -> int:
	var n: int = 0
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.85 and c.g < 0.15 and c.b > 0.85:
				n += 1
	return n

func _diff_pixels(a: Image, b: Image) -> int:
	var n: int = 0
	for y in a.get_height():
		for x in a.get_width():
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.06:
				n += 1
	return n

# =====================================================================
# PHASE I -- THE INSTRUMENT SEES

func _phase_i() -> void:
	print("-- PHASE I: instrument control --")
	await _station(SPAWN)
	var img: Image = await _frame()
	var seen := {}
	for y in range(0, img.get_height(), 37):
		for x in range(0, img.get_width(), 37):
			seen[img.get_pixel(x, y).to_rgba32()] = true
	_check(seen.size() > 1, "I1 the frame carries %d colours on a 37 px lattice (the dummy driver renders 1)" % seen.size())
	var moved: int = 0
	var total: int = 0
	for nm in _scatter.call("batch_nodes"):
		var node := _scatter.get_node_or_null(String(nm)) as MultiMeshInstance3D
		if node == null:
			continue
		for i in node.multimesh.instance_count:
			total += 1
			if node.multimesh.get_instance_transform(i).origin.length() > 0.01:
				moved += 1
	_check(total > 0 and moved == total, "I2 MultiMesh transforms read back non-identity: %d / %d" % [moved, total])
	var rect: Rect2 = _tap.container.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0, "I3 the container has a real rect (%s), so a screen tap projects" % rect)
	_check(_clearance > 0.0, "I4 read HubWorld.KEEPY_CLEARANCE (%.3f)" % _clearance)
	_check(_fair != null and _fair.track_length() > 0.0, "I5 the fair is built and its loop has length")
	print("")

# =====================================================================
# PHASE A -- AS BUILT vs AS PUBLISHED

func _phase_a() -> void:
	print("-- PHASE A: the fair as built --")
	var length: float = _fair.track_length()
	var static_length: float = HubFunfair._static_curve().get_baked_length()
	_check(absf(length - static_length) < 0.001,
		"A1 the two spellings of the loop agree to the millimetre (%.4f vs %.4f)" % [length, static_length])
	_check(_fair.crest_s() > _fair.lift_foot_s() and _fair.crest_s() < length * 0.5,
		"A2 the crest (s %.2f) is past the lift foot (s %.2f) and in the first half of the loop" % [_fair.crest_s(), _fair.lift_foot_s()])
	_check(absf(_fair.peak_rail_y() - 5.0) < 0.05, "A3 the peak rail is at the authored 5.0 (%.3f)" % _fair.peak_rail_y())
	# Every rail inside the square: the outer edge of the east rail.
	var max_x: float = -INF
	var min_x: float = INF
	var min_z: float = INF
	var max_z: float = -INF
	var s: float = 0.0
	while s < length:
		var f: Transform3D = _fair.track_frame(s)
		for side in [-1.0, 1.0]:
			var edge: Vector3 = f.origin + f.basis.x * (side * HubFunfair.RAIL_GAUGE * 0.5 + side * HubFunfair.RAIL_RADIUS)
			max_x = maxf(max_x, edge.x)
			min_x = minf(min_x, edge.x)
			min_z = minf(min_z, edge.z)
			max_z = maxf(max_z, edge.z)
		s += 0.25
	print("     rails span x [%.3f, %.3f]  z [%.3f, %.3f]" % [min_x, max_x, min_z, max_z])
	_check(max_x < HubRegion.PLATEAU_HALF_EXTENT, "A4 the east rail's outer edge %.3f stays inside the square's %.1f" % [max_x, HubRegion.PLATEAU_HALF_EXTENT])
	_check(min_x > P1.x + 1.0, "A5 the west rail (%.3f) is east of the zipline's stair line" % min_x)
	# The camera ceilings, on the rule HubTrees derives SEAT_MAX_Y from.
	var ceiling: float = HubCamera.FRAME_TOP_AT_APLOMB - CROWN - CROWN_MARGIN
	var cart_seat: float = _fair.peak_rail_y() + HubFunfair.CART_SEAT.y
	var gond_seat: float = HubFunfair.GONDOLA_TOP_Y + HubFunfair.GONDOLA_SEAT.y
	_check(cart_seat <= ceiling, "A6 the coaster's highest seat %.3f is under the seat ceiling %.3f" % [cart_seat, ceiling])
	_check(gond_seat <= ceiling, "A7 the gondola's highest seat %.3f is under the seat ceiling %.3f" % [gond_seat, ceiling])
	var tower_top: float = HubFunfair.TOWER_HEIGHT + HubFunfair.TOWER_CAP.y
	_check(tower_top <= HubCamera.FRAME_TOP_AT_APLOMB, "A8 the tower's cap (%.2f) is under the frame top at the aplomb (%.3f): a rider sees the whole tower" % [tower_top, HubCamera.FRAME_TOP_AT_APLOMB])
	# The published brake decel is a derived number, and it is a thrill.
	var decel: float = HubFunfair.tower_brake_decel()
	print("     tower: free fall %.2f u, brake over %.2f u, decel %.2f u/s2 (%.2f g)" % [
		HubFunfair.GONDOLA_TOP_Y - HubFunfair.GONDOLA_BRAKE_Y, HubFunfair.GONDOLA_BRAKE_Y - HubFunfair.GONDOLA_REST_Y, decel, decel / HubFunfair.GRAVITY])
	_check(decel > HubFunfair.GRAVITY and decel < 5.0 * HubFunfair.GRAVITY, "A9 the brake is between 1 and 5 g")
	print("")

# =====================================================================
# PHASE B -- CLEARANCES

func _phase_b() -> void:
	print("-- PHASE B: clearances and the region --")
	var fps: Array = _props.ground_footprints()
	# The tower's base against every layout footprint.
	var worst_gap: float = INF
	var worst_at := Vector3.ZERO
	for fp in fps:
		var gap: float = _flat(fp["position"]).distance_to(_flat(HubFunfair.TOWER_AT)) - float(fp["radius"]) - HubFunfair.TOWER_FOOTPRINT
		if gap < worst_gap:
			worst_gap = gap
			worst_at = fp["position"]
	print("     tower's tightest layout neighbour: %s, gap %.3f u" % [worst_at, worst_gap])
	_check(worst_gap >= _clearance, "B1 the tower clears every layout footprint by KEEPY_CLEARANCE (%.3f >= %.3f)" % [worst_gap, _clearance])
	# The low rails and the deck against the same footprints.
	var low_gap: float = INF
	var s: float = 0.0
	while s < _fair.track_length():
		var p: Vector3 = _fair.track_point(s)
		if p.y <= HubFunfair.LOW_RAIL_HEIGHT:
			for fp in fps:
				low_gap = minf(low_gap, _flat(fp["position"]).distance_to(_flat(p)) - float(fp["radius"]) - HubFunfair.RAIL_GAUGE * 0.5)
		s += 0.25
	_check(low_gap >= _clearance, "B2 every low rail clears every layout footprint (tightest %.3f u)" % low_gap)
	# The cable: every rail sample against the P1 -> P2 segment at 2 u.
	var a: Vector3 = P1 + Vector3.UP * CABLE_HEIGHT
	var b: Vector3 = P2 + Vector3.UP * CABLE_HEIGHT
	var cable_gap: float = INF
	s = 0.0
	while s < _fair.track_length():
		var f: Transform3D = _fair.track_frame(s)
		var west: Vector3 = f.origin - f.basis.x * (HubFunfair.RAIL_GAUGE * 0.5 + HubFunfair.RAIL_RADIUS)
		var q: Vector3 = Geometry3D.get_closest_point_to_segment(west, a, b)
		cable_gap = minf(cable_gap, q.distance_to(west))
		s += 0.25
	_check(cable_gap >= CABLE_CLEARANCE, "B3 the nearest rail is %.3f u from the zipline cable (>= %.1f)" % [cable_gap, CABLE_CLEARANCE])
	# The region: every control point, both stand points, walkable.
	var inside: int = 0
	for p in HubFunfair.TRACK_POINTS:
		if HubRegion.contains(p):
			inside += 1
	_check(inside == HubFunfair.TRACK_POINTS.size(), "B4 all %d control points are on walkable ground (%d)" % [HubFunfair.TRACK_POINTS.size(), inside])
	_check(HubRegion.contains(HubFunfair.STATION_STAND) and HubRegion.contains(HubFunfair.TOWER_STAND), "B5 both stand points are walkable")
	_check(HubRegion.zone_of(HubFunfair.STATION_STAND) == 0 and HubRegion.zone_of(HubFunfair.TOWER_AT) == 0, "B6 the fair is in zone 0")
	_check(HubRegion.contains(HubFunfair.TOWER_AT + Vector3(HubFunfair.TOWER_FOOTPRINT, 0.0, 0.0)), "B7 the tower's east rim (x %.2f) is still walkable ground -- nothing overhangs the edge" % (HubFunfair.TOWER_AT.x + HubFunfair.TOWER_FOOTPRINT))
	# The stand points are not inside any solid of the fair.
	var body: StaticBody3D = _fair.collider_body()
	var stands_clear: bool = true
	for stand in [HubFunfair.STATION_STAND, HubFunfair.TOWER_STAND]:
		for shape in body.get_children():
			var cs := shape as CollisionShape3D
			var box := cs.shape as BoxShape3D
			var c: Vector3 = cs.global_position
			if absf(stand.x - c.x) < box.size.x * 0.5 + _clearance and absf(stand.z - c.z) < box.size.z * 0.5 + _clearance:
				stands_clear = false
	_check(stands_clear, "B8 neither stand point is within KEEPY_CLEARANCE of a solid")
	# The carpet is kept off the fair -- and the census can see.
	var inside_fp: int = 0
	var ring: int = 0
	for nm in _scatter.call("batch_nodes"):
		var node := _scatter.get_node_or_null(String(nm)) as MultiMeshInstance3D
		if node == null:
			continue
		for i in node.multimesh.instance_count:
			var o: Vector3 = (node.global_transform * node.multimesh.get_instance_transform(i)).origin
			for fp in HubFunfair.footprints():
				var d: float = _flat(o).distance_to(_flat(fp["position"]))
				if d < float(fp["radius"]):
					inside_fp += 1
					break
				elif d < float(fp["radius"]) + 1.5:
					ring += 1
					break
	_check(ring > 0, "B9 (blind) the census sees %d carpet instances in the ring just outside the fair's %d footprints" % [ring, HubFunfair.footprints().size()])
	_check(inside_fp == 0, "B10 and none inside them (%d)" % inside_fp)
	print("")

# =====================================================================
# PHASE C -- THE WINDING JUDGE (CH39)

func _judge(node: MeshInstance3D, station: Vector3, label: String) -> void:
	await _station(station)
	var kept: Material = node.material_override
	var counts: Array = []
	for cull in [BaseMaterial3D.CULL_BACK, BaseMaterial3D.CULL_DISABLED]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.0, 1.0)
		m.cull_mode = cull
		m.set("disable_fog", true)
		node.material_override = m
		var img: Image = await _frame()
		counts.append(_count_magenta(img))
	node.material_override = kept
	await get_tree().process_frame
	var back: int = counts[0]
	var both: int = counts[1]
	_check(back > 0 and both > 0, "C %s paints under both cull modes (%d / %d px)" % [label, back, both])
	_check(absf(back - both) <= maxf(6.0, 0.01 * both), "C %s covers the same pixels under cull_back and cull_disabled (%d vs %d): wound the right way" % [label, back, both])

func _phase_c() -> void:
	print("-- PHASE C: winding judge, cull_back vs cull_disabled --")
	await _judge(_fair.track_node(), DROP_VIEW, "track")
	await _judge(_fair.cart_node().get_node("CartMesh") as MeshInstance3D, COASTER_TAP_FROM, "cart")
	await _judge(_fair.tower_node().get_node("TowerMesh") as MeshInstance3D, TOWER_TAP_FROM, "tower")
	await _judge(_fair.gondola_node().get_node("GondolaMesh") as MeshInstance3D, TOWER_TAP_FROM, "gondola")
	print("")

# =====================================================================
# PHASE D -- D5, AND THE SOLIDS ARE LIVE

func _phase_d() -> void:
	print("-- PHASE D: the solids (D5) --")
	var body: StaticBody3D = _fair.collider_body()
	_check(body != null and body.collision_layer == 1 << (SkateBoardBody.LAYER_PARK - 1) and body.collision_mask == 0,
		"D1 one static body on the park layer, masking nothing")
	var boxes: int = 0
	var others: int = 0
	for shape in body.get_children():
		if shape is CollisionShape3D and (shape as CollisionShape3D).shape is BoxShape3D:
			boxes += 1
		else:
			others += 1
	var posts: int = 0
	for fp in HubFunfair.footprints():
		if absf(float(fp["radius"]) - HubFunfair.POST_FOOTPRINT) < 0.001:
			posts += 1
	print("     %d box shapes: %d rail posts + 2 station posts + tower base, mast and 4 legs = %d expected" % [boxes, posts, posts + 2 + 6])
	_check(others == 0, "D2 every shape is a BoxShape3D -- convex, no trimesh (%d others)" % others)
	_check(boxes == posts + 2 + 6, "D3 the shape count is what the fair publishes")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	var mask: int = 1 << (SkateBoardBody.LAYER_PARK - 1)
	var q := PhysicsRayQueryParameters3D.create(HubFunfair.TOWER_AT + Vector3(0.0, 8.0, 0.0), HubFunfair.TOWER_AT + Vector3(0.0, -1.0, 0.0), mask)
	var hit: Dictionary = space.intersect_ray(q)
	_check(not hit.is_empty() and hit["collider"] == body, "D4 a ray down the tower's axis hits the fair's body (the mast) at y %.3f" % (float(hit["position"].y) if not hit.is_empty() else -1.0))
	q = PhysicsRayQueryParameters3D.create(HubFunfair.STATION_STAND + Vector3(0.0, 3.0, 0.0), HubFunfair.STATION_STAND + Vector3(0.0, -1.0, 0.0), mask)
	hit = space.intersect_ray(q)
	_check(hit.is_empty(), "D5 (blind) a ray down onto the deck's stand point hits nothing -- the deck is not solid and the ray does not lie")
	print("")

# =====================================================================
# PHASE E -- THE COASTER, THROUGH THE PLAYER'S CHANNEL

func _ride_coaster(label: String, brake_mode: int) -> Dictionary:
	print("   -- %s --" % label)
	_finished_rides.clear()
	_fair.set_brake_override(brake_mode)
	await _station(COASTER_TAP_FROM)
	var rest: Vector3 = HubFunfair.TRACK_POINTS[0]
	_check(_in_frame(_flat(rest), 0.0), "E the cart's rest point is in frame from the tap station")
	_tap_world(_flat(rest))
	await get_tree().process_frame
	_check(_fair.intent() == HubFunfair.RIDE_COASTER or _fair.is_riding(), "E the tap armed the coaster intent")
	var walked: int = await _settle_walk()
	for _i in 3:
		await get_tree().process_frame
	_check(_keepy.is_on_carrier() and _fair.coaster_phase() != HubFunfair.CoasterPhase.IDLE,
		"E he boarded on arrival (%d frames of walk) and the cart departed" % walked)
	var out := {"frames": 0, "v_max": 0.0, "v_crest": -1.0, "v_valley": 0.0, "y_max": -INF, "crown_out": 0, "follow_worst": 0.0,
		"phases": {}, "tap_dropped": false, "withdrawn": false, "v_first_coast": -1.0}
	if not _keepy.is_on_carrier():
		return out
	var cart: Node3D = _fair.cart_node()
	var valley_s: float = _fair.crest_s() + 12.0
	var tapped_mid: bool = false
	var last_phase: int = -1
	while _keepy.is_on_carrier() and out["frames"] < 60 * 60:
		await get_tree().process_frame
		out["frames"] += 1
		var v: float = _fair.coaster_speed()
		var s: float = _fair.coaster_s()
		var ph: int = _fair.coaster_phase()
		if ph != last_phase:
			out["phases"][ph] = out["frames"]
			last_phase = ph
			if ph == HubFunfair.CoasterPhase.COAST:
				out["v_first_coast"] = v
		out["v_max"] = maxf(out["v_max"], v)
		if ph == HubFunfair.CoasterPhase.COAST and absf(s - valley_s) < 0.6:
			out["v_valley"] = maxf(out["v_valley"], v)
		out["y_max"] = maxf(out["y_max"], _keepy.global_position.y)
		# Read only while he is STILL aboard: the frame that ends the ride
		# also starts his step-off hop, and a reading taken then measures
		# the hop, not the carry (8.4 cm on the first run of this probe).
		if _keepy.is_on_carrier():
			var seat: Vector3 = cart.to_global(HubFunfair.CART_SEAT)
			out["follow_worst"] = maxf(out["follow_worst"], seat.distance_to(_keepy.global_position))
		if not _in_frame(_keepy.global_position + Vector3.UP * CROWN, FRAME_MARGIN_PX):
			out["crown_out"] += 1
		if not tapped_mid and ph == HubFunfair.CoasterPhase.COAST:
			# A tap DURING the ride: on bare ground, and on the station.
			tapped_mid = true
			out["withdrawn"] = _fair.accepts_tap(_flat(rest)) == -1
			_tap_world(BARE_GROUND)
			await get_tree().process_frame
			out["tap_dropped"] = _keepy.is_on_carrier() and not _keepy.is_hopping() and _fair.coaster_phase() == HubFunfair.CoasterPhase.COAST
	# The step-off.
	var settle: int = await _settle_walk(300)
	out["landed_at"] = _flat(_keepy.global_position)
	out["idle"] = not _keepy.is_hopping() and not _keepy.is_on_carrier()
	out["finished"] = _finished_rides.count(HubFunfair.RIDE_COASTER)
	out["settle"] = settle
	_fair.set_brake_override(-1)
	return out

func _phase_e() -> void:
	print("-- PHASE E: the coaster, free then braked --")
	# NEGATIVE CONTROL FIRST: a tap on bare ground arms nothing.
	await _station(COASTER_TAP_FROM)
	_tap_world(BARE_GROUND)
	await get_tree().process_frame
	_check(_fair.intent() < 0 and not _fair.is_riding(), "E0 (blind) a tap on bare ground arms no ride")
	await _settle_walk()
	var free: Dictionary = await _ride_coaster("run 1: free (brake forced OFF)", 0)
	_report_run(free)
	_check(int(free["finished"]) == 1 and bool(free["idle"]), "E1 the ride ended once and he stands on the ground (%d frames aboard)" % int(free["frames"]))
	_check(Vector3(free["landed_at"]).distance_to(HubFunfair.STATION_STAND) < 0.05, "E2 he stepped off onto the deck's stand point (%.3f u off)" % Vector3(free["landed_at"]).distance_to(HubFunfair.STATION_STAND))
	_check(float(free["follow_worst"]) < 0.001, "E3 he was carried by the cart, not alongside it (worst %.5f u)" % float(free["follow_worst"]))
	_check(int(free["crown_out"]) == 0, "E4 his crown stayed inside the frame every frame (%d out)" % int(free["crown_out"]))
	_check(float(free["v_max"]) >= 7.0 and float(free["v_max"]) <= 12.0, "E5 the top speed %.2f u/s is a drop, not a walk (7..12)" % float(free["v_max"]))
	_check(absf(float(free["v_first_coast"]) - HubFunfair.LIFT_SPEED) < 0.05, "E6 the crest is crossed at lift speed (%.2f vs %.2f)" % [float(free["v_first_coast"]), HubFunfair.LIFT_SPEED])
	var phases: Dictionary = free["phases"]
	_check(phases.has(HubFunfair.CoasterPhase.LIFT) and phases.has(HubFunfair.CoasterPhase.COAST) and phases.has(HubFunfair.CoasterPhase.BRAKE),
		"E7 the run went through DEPART, LIFT, COAST and BRAKE, in that order")
	_check(bool(free["withdrawn"]), "E8 the station withdrew from the tap for the length of the ride")
	_check(bool(free["tap_dropped"]), "E9 a tap on bare ground mid-ride was dropped by state: still aboard, not hopping, still coasting")
	_check(_fair.accepts_tap(_flat(HubFunfair.TRACK_POINTS[0])) == HubFunfair.RIDE_COASTER, "E10 and the station answers again once the ride is over")
	var energy_seat: float = float(free["y_max"]) - HubFunfair.CART_SEAT.y
	_check(absf(energy_seat - _fair.peak_rail_y()) < 0.08, "E11 he was carried over the crest (max y %.3f, rail %.3f)" % [float(free["y_max"]), _fair.peak_rail_y()])
	var braked: Dictionary = await _ride_coaster("run 2: braked (brake forced ON the whole way)", 1)
	_report_run(braked)
	_check(int(braked["finished"]) == 1 and bool(braked["idle"]), "E12 the braked ride still ends (BOUNDED) with him on the ground")
	_check(float(braked["v_valley"]) < float(free["v_valley"]) - 1.0,
		"E13 the brake is WIRED: valley speed %.2f braked vs %.2f free" % [float(braked["v_valley"]), float(free["v_valley"])])
	_check(int(braked["frames"]) > int(free["frames"]) + 30, "E14 and the braked ride is longer (%d vs %d frames)" % [int(braked["frames"]), int(free["frames"])])
	_check(float(braked["v_max"]) >= HubFunfair.SPEED_FLOOR, "E15 the floor held under the brake (min speed never below %.1f)" % HubFunfair.SPEED_FLOOR)
	print("")

func _report_run(r: Dictionary) -> void:
	print("     frames aboard %d  v_max %.3f  crest %.3f  valley %.3f  y_max %.3f  crown out %d  follow %.5f  settle %d" % [
		int(r["frames"]), float(r["v_max"]), float(r["v_first_coast"]), float(r["v_valley"]), float(r["y_max"]), int(r["crown_out"]), float(r["follow_worst"]), int(r["settle"])])

# =====================================================================
# PHASE F -- THE DROP TOWER, THROUGH THE PLAYER'S CHANNEL

func _phase_f() -> void:
	print("-- PHASE F: the drop tower --")
	_finished_rides.clear()
	await _station(TOWER_TAP_FROM)
	_check(_in_frame(_flat(HubFunfair.TOWER_AT), 0.0), "F0 the tower's base is in frame from the tap station")
	_tap_world(_flat(HubFunfair.TOWER_AT))
	await get_tree().process_frame
	_check(_fair.intent() == HubFunfair.RIDE_TOWER or _fair.is_riding(), "F1 the tap armed the tower intent")
	var walked: int = await _settle_walk()
	for _i in 3:
		await get_tree().process_frame
	_check(_keepy.is_on_carrier() and _fair.tower_phase() == HubFunfair.TowerPhase.RISE, "F2 he boarded on arrival (%d frames of walk) and the gondola rises" % walked)
	var gond: Node3D = _fair.gondola_node()
	var base_top: float = HubSurface.ground(HubFunfair.TOWER_AT).y + HubFunfair.TOWER_BASE.y
	var rise_vmax: float = 0.0
	var y_max: float = -INF
	var y_min: float = INF
	var v_min: float = 0.0
	var crown_out: int = 0
	var follow_worst: float = 0.0
	var hold_frames: int = 0
	var frames: int = 0
	var last_y: float = _fair.gondola_y()
	var tapped: bool = false
	var dropped: bool = false
	var withdrawn: bool = false
	var floor_ok: bool = true
	while _keepy.is_on_carrier() and frames < 60 * 40:
		await get_tree().process_frame
		frames += 1
		var y: float = _fair.gondola_y()
		var ph: int = _fair.tower_phase()
		if ph == HubFunfair.TowerPhase.RISE:
			rise_vmax = maxf(rise_vmax, (y - last_y) * 60.0)
		if ph == HubFunfair.TowerPhase.HOLD:
			hold_frames += 1
		y_max = maxf(y_max, y)
		y_min = minf(y_min, y)
		v_min = minf(v_min, _fair.gondola_speed())
		if y - HubFunfair.GONDOLA_FLOOR.y * 0.5 < base_top - 0.001:
			floor_ok = false
		if _keepy.is_on_carrier():
			follow_worst = maxf(follow_worst, gond.to_global(HubFunfair.GONDOLA_SEAT).distance_to(_keepy.global_position))
		if not _in_frame(_keepy.global_position + Vector3.UP * CROWN, FRAME_MARGIN_PX):
			crown_out += 1
		if not tapped and ph == HubFunfair.TowerPhase.HOLD:
			tapped = true
			withdrawn = _fair.accepts_tap(_flat(HubFunfair.TOWER_AT)) == -1
			_tap_world(BARE_GROUND)
			await get_tree().process_frame
			dropped = _keepy.is_on_carrier() and not _keepy.is_hopping()
		last_y = y
	var settle: int = await _settle_walk(300)
	print("     frames aboard %d  rise v_max %.3f  hold %d frames  y max %.3f  y min %.3f  fall v min %.3f  crown out %d  follow %.5f  settle %d" % [
		frames, rise_vmax, hold_frames, y_max, y_min, v_min, crown_out, follow_worst, settle])
	_check(_finished_rides.count(HubFunfair.RIDE_TOWER) == 1 and not _keepy.is_on_carrier() and not _keepy.is_hopping(), "F3 the ride ended once and he stands on the ground")
	_check(_flat(_keepy.global_position).distance_to(HubFunfair.TOWER_STAND) < 0.05, "F4 he stepped off onto the tower's stand point")
	_check(rise_vmax <= HubFunfair.GONDOLA_RISE_SPEED + 0.05 and rise_vmax > 0.5, "F5 the rise is slow: %.3f u/s (authored %.2f)" % [rise_vmax, HubFunfair.GONDOLA_RISE_SPEED])
	_check(absf(y_max - (HubSurface.ground(HubFunfair.TOWER_AT).y + HubFunfair.GONDOLA_TOP_Y)) < 0.02, "F6 it reached the authored top (%.3f)" % y_max)
	_check(hold_frames >= int(HubFunfair.GONDOLA_HOLD_S * 60.0) - 2, "F7 it held at the top for %d frames (%.1f s authored)" % [hold_frames, HubFunfair.GONDOLA_HOLD_S])
	var expected_fall: float = -sqrt(2.0 * HubFunfair.GRAVITY * (HubFunfair.GONDOLA_TOP_Y - HubFunfair.GONDOLA_BRAKE_Y))
	_check(v_min <= expected_fall + 0.3, "F8 the fall reached %.2f u/s (free fall predicts %.2f at the brake line)" % [v_min, expected_fall])
	_check(floor_ok and y_min >= HubSurface.ground(HubFunfair.TOWER_AT).y + HubFunfair.GONDOLA_REST_Y - 0.001,
		"F9 the gondola's floor never went through the base slab (y min %.3f, rest %.3f)" % [y_min, HubFunfair.GONDOLA_REST_Y])
	_check(crown_out == 0, "F10 his crown stayed in frame every frame (%d out)" % crown_out)
	_check(follow_worst < 0.001, "F11 he was carried by the gondola (worst %.5f u)" % follow_worst)
	_check(withdrawn and dropped, "F12 the tower withdrew for the ride and a mid-ride tap was dropped by state")
	_check(_fair.accepts_tap(_flat(HubFunfair.TOWER_AT)) == HubFunfair.RIDE_TOWER, "F13 and the tower answers again afterwards")
	print("")

# =====================================================================
# PHASE G -- BUDGET

func _phase_g() -> void:
	print("-- PHASE G: budget, fair shown vs hidden (gpu = opaque prims; scene = replay) --")
	var stations: Array = [["spawn", SPAWN], ["CH22 worst", CH22_WORST], ["coaster tap", COASTER_TAP_FROM], ["drop view", DROP_VIEW], ["tower tap", TOWER_TAP_FROM]]
	var site_delta: int = 0
	var scene_delta: int = -1
	for st in stations:
		await _station(st[1])
		get_tree().paused = true
		for _i in SETTLE:
			await get_tree().process_frame
		var a: Dictionary = await _read()
		var a2: Dictionary = await _read()
		_fair.visible = false
		for _i in SETTLE:
			await get_tree().process_frame
		var b: Dictionary = await _read()
		_fair.visible = true
		for _i in SETTLE:
			await get_tree().process_frame
		get_tree().paused = false
		var floor_: int = absi(int(a["gpu"]) - int(a2["gpu"]))
		var d: int = int(a["gpu"]) - int(b["gpu"])
		print("     %-12s gpu %6d (floor %d) -> hidden %6d  delta %+6d   calls %3d -> %3d   lod0 %+6d   scene %d -> %d (%+d)" % [
			st[0], int(a["gpu"]), floor_, int(b["gpu"]), d, int(a["calls"]), int(b["calls"]), int(a["lod0"]) - int(b["lod0"]), int(a["scene"]), int(b["scene"]), int(a["scene"]) - int(b["scene"])])
		if st[0] == "drop view":
			site_delta = d
		scene_delta = int(a["scene"]) - int(b["scene"])
	_check(scene_delta == _fair.triangle_total(), "G1 the replay's scene delta IS the fair's published triangle total (%d vs %d)" % [scene_delta, _fair.triangle_total()])
	_check(site_delta > 0, "G2 the fair costs primitives from the drop view (%+d)" % site_delta)
	print("")

# =====================================================================
# PHASE H -- PIXELS

func _phase_h() -> void:
	print("-- PHASE H: the fair is SEEN (hide / re-read, against the floor) --")
	for st in [["drop view", DROP_VIEW], ["tower tap", TOWER_TAP_FROM], ["coaster tap", COASTER_TAP_FROM]]:
		await _station(st[1])
		get_tree().paused = true
		for _i in SETTLE:
			await get_tree().process_frame
		var a: Image = await _frame()
		var a2: Image = await _frame()
		_fair.visible = false
		var b: Image = await _frame()
		_fair.visible = true
		await _frame()
		get_tree().paused = false
		var floor_: int = _diff_pixels(a, a2)
		var d: int = _diff_pixels(a, b)
		print("     %-12s changed %6d px when hidden, floor %d" % [st[0], d, floor_])
		_check(d > 3 * floor_ + 400, "H %s: the fair paints pixels well above the floor" % st[0])
	print("")
