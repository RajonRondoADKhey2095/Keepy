extends Node
## Dev-only: MEASUREMENT ONLY, gates nothing. Locks point A (the "totems"
## anchor Mathieu confirmed = Candidate 1 from NorthZoneReconProbe: Keepy
## standing 4u north of the slabs-landmark at (29.346,0,12.76), i.e.
## (29.346,0,16.76)) and finds a point B that (a) is where a player would
## naturally stand in open clear grass approaching this spot, and (b) is
## actually VISIBLE together with A from the SAME fixed-rotation HubCamera
## pose -- not assumed, tested via Camera3D.is_position_behind() the same
## way CorridorFollowupProbe already validated wire endpoints.
##
## The scene's camera has a FIXED rotation (HubCamera.gd's own docblock:
## never look_at) looking toward roughly world -Z (forward computed below
## from the .tscn-authored basis), offset (0,7.6,8.9) NORTH of whatever
## Keepy/the camera follows. That means a point is only visible if its z
## is LESS than camera z = standing_z + 8.9 -- so if B is Keepy's actual
## global hub spawn (0,0,0), camera sits at z=8.9, and A's z=16.76 is
## BEHIND it. This probe tests that directly instead of assuming it, then
## sweeps candidate standing points on the straight line from spawn toward
## A to find where A first becomes visible and reads as "far away, near
## the top of frame" the way Mathieu's reference composition shows it.
##
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/CorridorABConfirmProbe.tscn
##   xvfb-run --rendering-driver opengl3 godot4 --fixed-fps 60 --path . \
##     res://scripts/dev/CorridorABConfirmProbe.tscn

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"
const FRAME_SIZE: Vector2i = Vector2i(1080, 1920)

## Point A, LOCKED per Mathieu's confirmation of Candidate 1: the slabs
## ("totems") landmark sits at (29.346,0,12.76) per
## resources/hub/hub_layout.tres; Candidate 1's render stood Keepy 4u
## north of it (the walkable point actually shown and approved), so A is
## THAT point, not the landmark's own (non-walkable, inside the pillars)
## position.
const LANDMARK_POS: Vector3 = Vector3(29.346, 0.0, 12.76)
const POINT_A: Vector3 = Vector3(29.346, 0.0, 16.76)

## The OLD point B from the (now-invalidated-for-A) first recon pass, kept
## here ONLY as a labelled reference point to render alongside the new
## candidates -- not reused blindly, per the brief.
const OLD_POINT_B: Vector3 = Vector3(-0.912686, 0.0, 2.952071)

var _world_root: Node3D = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "CORRIDOR AB CONFIRM PROBE")
	print("=== CORRIDOR AB CONFIRM PROBE (measurement only, gates nothing) ===")
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var keepy: Node3D = hub.get_node("WorldViewport/SubViewport/World/Keepy")
	var camera: Camera3D = hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	var viewport: SubViewport = hub.get_node("WorldViewport/SubViewport")
	var builder: HubBuilder = hub.get_node("WorldViewport/SubViewport/World/Props")
	_world_root = hub.get_node("WorldViewport/SubViewport/World")

	print("--- POINT A, locked ---")
	print("  landmark (pillars) position = %s" % LANDMARK_POS)
	print("  point A (walkable, 4u north of the pillars -- the point Keepy stood at in the confirmed render) = %s" % POINT_A)

	print("")
	print("--- Visibility test: is point A visible from the GLOBAL hub spawn (Keepy at ZERO)? ---")
	keepy.global_position = Vector3.ZERO
	camera.global_position = Vector3.ZERO + HubCamera.OFFSET
	await get_tree().process_frame
	var behind_from_spawn: bool = camera.is_position_behind(POINT_A)
	print("  camera at spawn = %s   is_position_behind(point A) = %s" % [camera.global_position, behind_from_spawn])
	if behind_from_spawn:
		print("  *** CONFIRMED: point A is BEHIND the camera when Keepy stands at the global spawn -- the old point-B technique (raycast from THIS pose) cannot see A, so it cannot be reused blindly, exactly as flagged. ***")

	print("")
	print("--- Sweeping candidate B positions on the straight line from spawn toward point A's XZ ---")
	var dir_flat: Vector2 = Vector2(POINT_A.x, POINT_A.z).normalized()
	var candidates: Array[float] = [0.0, 2.0, 4.0, 6.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 16.76]
	for t in candidates:
		var cand: Vector3 = Vector3(dir_flat.x * t, 0.0, dir_flat.y * t)
		keepy.global_position = cand
		camera.global_position = cand + HubCamera.OFFSET
		await get_tree().process_frame
		var behind: bool = camera.is_position_behind(POINT_A)
		var screen: Vector2 = Vector2.INF
		if not behind:
			screen = camera.unproject_position(POINT_A)
		print("  B candidate at t=%.1fu along spawn->A bearing = %s  camera=%s  A behind=%s  A screen=%s" %
			[t, cand, camera.global_position, behind, screen])

	# Also test candidates OFF that exact bearing, at a few open-grass spots
	# near spawn's own foreground (the kind of "clear grass" the brief
	# describes), independent of the straight-line sweep above.
	print("")
	print("--- A few off-axis open-grass candidates near spawn, same visibility test ---")
	var off_axis: Array[Vector3] = [
		Vector3(5.0, 0.0, 5.0),
		Vector3(8.0, 0.0, 3.0),
		Vector3(10.0, 0.0, 6.0),
		OLD_POINT_B,
	]
	for cand2 in off_axis:
		keepy.global_position = cand2
		camera.global_position = cand2 + HubCamera.OFFSET
		await get_tree().process_frame
		var behind2: bool = camera.is_position_behind(POINT_A)
		var screen2: Vector2 = Vector2.INF
		if not behind2:
			screen2 = camera.unproject_position(POINT_A)
		print("  candidate %s  camera=%s  A behind=%s  A screen=%s" % [cand2, camera.global_position, behind2, screen2])

	print("")
	print("--- Pond/lake/decor context around point A and the winning B candidate (filled in after visual pick) ---")
	print("  builder.pond_centre() = %s  POND_WATER_RADIUS=%.4f" % [builder.pond_centre(), HubBuilder.POND_WATER_RADIUS])

	print("")
	print("--- Distance / altitude / slope, A <-> OLD_POINT_B (working hypothesis for B, NOT re-confirmed by a clean combined shot -- see the camera-framing finding above) ---")
	var dist: float = POINT_A.distance_to(OLD_POINT_B)
	var dy: float = OLD_POINT_B.y - POINT_A.y
	print("  point A = %s   point B(hypothesis) = %s" % [POINT_A, OLD_POINT_B])
	print("  altitude A.y=%.4f  altitude B.y=%.4f  delta=%.4f (both on the flat Ground plane, y=0 -- same as every prior recon on this plateau)" % [POINT_A.y, OLD_POINT_B.y, dy])
	print("  distance A<->B (3D) = %.4f" % dist)
	var flat_a := Vector2(POINT_A.x, POINT_A.z)
	var flat_b := Vector2(OLD_POINT_B.x, OLD_POINT_B.z)
	var horiz: float = flat_a.distance_to(flat_b)
	print("  horizontal distance A<->B = %.4f" % horiz)
	for deck_delta in [0.0, 1.0, 2.0, 3.0]:
		var angle_deg: float = rad_to_deg(atan2(deck_delta, horiz))
		print("  deck height offset %.1fu -> cable slope %.2f deg (A->B direction); same magnitude B->A" % [deck_delta, angle_deg])

	print("")
	print("--- Clearance: point A and point B against the live built AABB tree (same technique as CorridorFollowupProbe) ---")
	var all_aabbs: Array = _collect_world_aabbs(builder)
	var tall_aabbs: Array = []
	for entry in all_aabbs:
		var box: AABB = entry["aabb"]
		if box.size.y > 1.0:
			tall_aabbs.append(entry)
	print("  total decor AABBs: %d  (%d with size.y>1.0)" % [all_aabbs.size(), tall_aabbs.size()])
	_report_clearance("point A (totems)", POINT_A, tall_aabbs)
	_report_clearance("point B (hypothesis)", OLD_POINT_B, tall_aabbs)
	_report_corridor_clearance(POINT_A, OLD_POINT_B, tall_aabbs)

	print("")
	print("--- Pond clearance for point A (the totems sit right by the small pond) ---")
	var pond_c: Vector3 = builder.pond_centre()
	var pond_flat := Vector2(pond_c.x, pond_c.z)
	var a_to_pond: float = flat_a.distance_to(pond_flat)
	print("  distance point A to pond centre = %.4f  (pond radius %.4f)  clearance = %.4f" %
		[a_to_pond, HubBuilder.POND_WATER_RADIUS, a_to_pond - HubBuilder.POND_WATER_RADIUS])

	var driver: String = DisplayServer.get_name()
	if driver != "headless":
		await _phase_capture(hub, keepy, camera, viewport)
	else:
		print("")
		print("(driver=headless: skipping PHASE CAPTURE, no pixel can be read)")

	hub.queue_free()
	print("")
	print("=== END CORRIDOR AB CONFIRM PROBE ===")
	get_tree().quit(0)

func _phase_capture(hub: Node, keepy: Node3D, camera: Camera3D, viewport: SubViewport) -> void:
	print("")
	print("--- PHASE CAPTURE ---")
	var container: SubViewportContainer = viewport.get_parent() as SubViewportContainer
	var had_stretch: bool = container.stretch
	container.stretch = false
	viewport.size = FRAME_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame

	# Render 1: from the GLOBAL spawn, to visually document the "A behind
	# camera" finding rather than just asserting it.
	keepy.global_position = Vector3.ZERO
	camera.global_position = Vector3.ZERO + HubCamera.OFFSET
	var marker_a := _make_marker(Color(1.0, 0.15, 0.15))
	marker_a.position = POINT_A + Vector3(0.0, 0.8, 0.0)
	_world_root.add_child(marker_a)
	await get_tree().process_frame
	await _render_and_save(viewport, "user://ab_confirm_from_global_spawn.png")

	# Render 2..N: from each swept B candidate along the spawn->A bearing,
	# marker on A, so Mathieu can see the composition directly rather than
	# trust the is_position_behind() table alone.
	var dir_flat: Vector2 = Vector2(POINT_A.x, POINT_A.z).normalized()
	for t in [6.0, 9.0, 12.0]:
		var cand: Vector3 = Vector3(dir_flat.x * t, 0.0, dir_flat.y * t)
		keepy.global_position = cand
		camera.global_position = cand + HubCamera.OFFSET
		await get_tree().process_frame
		await _render_and_save(viewport, "user://ab_confirm_b_t%02d.png" % int(t))

	# Render: wire readability from B's REAL in-game camera pose (the
	# actual player viewpoint at B, fixed HubCamera rotation) -- tests
	# whether the fog is even the relevant question, given the sweep
	# above already found A sits far outside any sane on-screen framing
	# from anywhere near B.
	keepy.global_position = OLD_POINT_B
	camera.global_position = OLD_POINT_B + HubCamera.OFFSET
	var wire := _make_wire(POINT_A + Vector3(0.0, 2.0, 0.0), OLD_POINT_B + Vector3(0.0, 2.0, 0.0))
	_world_root.add_child(wire)
	await get_tree().process_frame
	await _render_and_save(viewport, "user://ab_confirm_wire_from_b.png")
	var behind_wire: bool = camera.is_position_behind(POINT_A + Vector3(0.0, 2.0, 0.0))
	print("  wire test from B: point A (raised) behind camera = %s" % behind_wire)
	wire.queue_free()

	# Render N+1: an OBLIQUE SURVEY shot -- camera freely repositioned and
	# look_at()'d at the A<->B midpoint, NOT the fixed in-game HubCamera
	# pose. This is a validation aid only (same technique
	# ZiplineReconProbe's "corridor_overview" render already used), so
	# Mathieu can see the real A<->B spatial relationship in one frame --
	# the sweep above already proved the ACTUAL gameplay camera cannot do
	# this from any reasonable B near spawn.
	var marker_b := _make_marker(Color(0.15, 0.4, 1.0))
	marker_b.position = OLD_POINT_B + Vector3(0.0, 0.8, 0.0)
	_world_root.add_child(marker_b)
	var mid: Vector3 = (POINT_A + OLD_POINT_B) * 0.5
	var to_a: Vector3 = POINT_A - OLD_POINT_B
	to_a.y = 0.0
	var seg_len: float = maxf(to_a.length(), 0.001)
	var side: Vector3 = to_a.normalized().cross(Vector3.UP)
	camera.global_position = mid + side * (seg_len * 0.7) + Vector3(0.0, seg_len * 0.7, 0.0)
	camera.look_at(mid, Vector3.UP)
	await get_tree().process_frame
	await _render_and_save(viewport, "user://ab_confirm_oblique_overview.png")
	marker_b.queue_free()

	marker_a.queue_free()
	container.stretch = had_stretch

func _make_wire(a: Vector3, b: Vector3) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var seg: Vector3 = b - a
	var length: float = maxf(seg.length(), 0.001)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = length
	cyl.radial_segments = 8
	mesh_inst.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.1)
	mesh_inst.material_override = mat
	mesh_inst.position = (a + b) * 0.5
	var up := Vector3.UP
	var dir := seg.normalized()
	if absf(dir.dot(up)) > 0.999:
		up = Vector3.FORWARD
	mesh_inst.basis = Basis().looking_at(dir, up) * Basis(Vector3.RIGHT, deg_to_rad(90.0))
	return mesh_inst

func _make_marker(color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_inst.material_override = mat
	return mesh_inst

const PROPOSED_STRUCTURE_RADIUS: float = 3.5

func _collect_world_aabbs(node: Node) -> Array:
	var out: Array = []
	_collect_world_aabbs_recursive(node, out)
	return out

func _collect_world_aabbs_recursive(node: Node, out: Array) -> void:
	var mesh_inst := node as MeshInstance3D
	if mesh_inst and mesh_inst.mesh:
		var local_aabb: AABB = mesh_inst.mesh.get_aabb()
		var world_aabb: AABB = mesh_inst.global_transform * local_aabb
		out.append({"aabb": world_aabb, "path": str(mesh_inst.get_path())})
	var mm_inst := node as MultiMeshInstance3D
	if mm_inst and mm_inst.multimesh and mm_inst.multimesh.mesh:
		var mm: MultiMesh = mm_inst.multimesh
		var local_aabb2: AABB = mm.mesh.get_aabb()
		for i in mm.instance_count:
			var xform: Transform3D = mm_inst.global_transform * mm.get_instance_transform(i)
			var world_aabb2: AABB = xform * local_aabb2
			out.append({"aabb": world_aabb2, "path": "%s[%d]" % [str(mm_inst.get_path()), i]})
	for child in node.get_children():
		_collect_world_aabbs_recursive(child, out)

func _point_to_aabb_xz_distance(point: Vector3, box: AABB) -> float:
	var min_x: float = box.position.x
	var max_x: float = box.position.x + box.size.x
	var min_z: float = box.position.z
	var max_z: float = box.position.z + box.size.z
	var cx: float = clampf(point.x, min_x, max_x)
	var cz: float = clampf(point.z, min_z, max_z)
	return Vector2(point.x - cx, point.z - cz).length()

func _report_clearance(label: String, point: Vector3, aabbs: Array) -> void:
	var nearest_dist: float = INF
	var nearest_path: String = ""
	var nearest_aabb: AABB = AABB()
	for entry in aabbs:
		var box: AABB = entry["aabb"]
		var d: float = _point_to_aabb_xz_distance(point, box)
		if d < nearest_dist:
			nearest_dist = d
			nearest_path = entry["path"]
			nearest_aabb = box
	print("  %s %s: nearest decor AABB = %s (footprint dist %.4f, box=%s)" %
		[label, point, nearest_path, nearest_dist, nearest_aabb])
	if nearest_dist < PROPOSED_STRUCTURE_RADIUS:
		print("    *** WITHIN PROPOSED %.1fu STRUCTURE RADIUS -- collision risk ***" % PROPOSED_STRUCTURE_RADIUS)
	else:
		print("    clears the proposed %.1fu structure radius by %.4fu" % [PROPOSED_STRUCTURE_RADIUS, nearest_dist - PROPOSED_STRUCTURE_RADIUS])

func _report_corridor_clearance(a: Vector3, b: Vector3, aabbs: Array) -> void:
	var dist: float = a.distance_to(b)
	var steps: int = maxi(int(ceil(dist)), 1)
	var worst: float = INF
	var worst_t: float = 0.0
	var worst_path: String = ""
	var worst_box: AABB = AABB()
	for i in (steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector3 = a.lerp(b, t)
		for entry in aabbs:
			var d: float = _point_to_aabb_xz_distance(p, entry["aabb"])
			if d < worst:
				worst = d
				worst_t = t
				worst_path = entry["path"]
				worst_box = entry["aabb"]
	print("  corridor sweep (%d samples): worst clearance = %.4fu at t=%.2f (%.1f%% A->B)" %
		[steps + 1, worst, worst_t, worst_t * 100.0])
	print("    worst-clearance object: %s  box=%s" % [worst_path, worst_box])

func _render_and_save(viewport: SubViewport, out_path: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var err: int = image.save_png(out_path)
	print("  save_png(%s) -> %d  (globalized: %s)" %
		[out_path, err, ProjectSettings.globalize_path(out_path)])
