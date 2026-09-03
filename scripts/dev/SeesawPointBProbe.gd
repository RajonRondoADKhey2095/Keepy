extends Node
## Dev-only: MEASUREMENT ONLY, gates nothing. Follow-up to
## ZiplineBSearchProbe / CorridorABConfirmProbe: Mathieu's two annotated
## captures show the SEESAW (with the bear/mascot on it) AND the tower/totems
## (point A, locked at 29.346,0,16.76) in the SAME camera frame -- suggesting
## they sit much closer together than the north-band B candidates (14-22u
## away from A, in a zone where the seesaw did not appear on any prior
## render).
##
## This probe:
##   1. Reads the seesaw's AS-BUILT position via props.seesaws()[0]["position"]
##      -- never the raw layout value (0.00, 38.50), which is pre-placement
##      and not the fact this project publishes.
##   2. Measures the real distance seesaw<->A.
##   3. Locates the nearest "rock"-family AABB to the seesaw and reports its
##      size/position, to check against the ~3.3x2.5x3.3u rock near
##      (14.5,4,13.4) described in a prior recon.
##   4. Proposes point B "to the right of the seesaw" under BOTH readings
##      (screen-right from the standard hub camera, and right of the seesaw's
##      own facing/orientation), with distance/slope/clearance to A for each.
##   5. Renders the combined composition (seesaw + tower A + candidate B, all
##      markers) from a survey camera, for direct visual confirmation.
##
## Must run under xvfb+opengl3, NEVER --headless alone (MultiMesh instance
## transforms read back as identity under the dummy driver).
##
##   xvfb-run --rendering-driver opengl3 godot4 --fixed-fps 60 --path . \
##     res://scripts/dev/SeesawPointBProbe.tscn

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"
const FRAME_SIZE: Vector2i = Vector2i(1080, 1920)

const POINT_A: Vector3 = Vector3(29.346, 0.0, 16.76)
const REAL_STRUCTURE_RADIUS: float = 4.03 # StructureRadiusProbe, ladder-anchored max of 3 boards

var _world_root: Node3D = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "SEESAW POINT B PROBE")
	print("=== SEESAW POINT B PROBE (measurement only, gates nothing) ===")
	print("  point A (locked) = %s" % POINT_A)
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var builder: HubBuilder = hub.get_node("WorldViewport/SubViewport/World/Props")
	_world_root = hub.get_node("WorldViewport/SubViewport/World")

	var driver: String = DisplayServer.get_name()
	if driver == "headless":
		print("*** ABORT: this probe reads MultiMesh (rock) AABBs and renders pixels, both")
		print("*** unreliable under --headless. Re-run under xvfb-run --rendering-driver opengl3.")
		hub.queue_free()
		get_tree().quit(1)
		return

	# --- 1. seesaw as-built position -----------------------------------
	var seesaws: Array[Dictionary] = builder.seesaws()
	print("--- seesaws() as published (as-BUILT, not the raw layout entry) ---")
	print("  count = %d" % seesaws.size())
	if seesaws.is_empty():
		print("  *** ABORT: no seesaw published, nothing to measure.")
		hub.queue_free()
		get_tree().quit(1)
		return
	var seesaw_pos: Vector3 = seesaws[0]["position"] as Vector3
	print("  seesaws()[0][\"position\"] = %s" % seesaw_pos)
	print("  (raw layout entry for &\"seesaw\" was (0.00, 38.50) per CH16 -- as-built may differ, this is the fact that matters)")

	# --- 2. distance seesaw <-> A ---------------------------------------
	var dist_seesaw_a: float = seesaw_pos.distance_to(POINT_A)
	print("")
	print("--- distance seesaw <-> point A ---")
	print("  |seesaw - A| = %.4fu" % dist_seesaw_a)
	print("  previously-established readable band for A<->B: 14-22u")
	if dist_seesaw_a < 14.0:
		print("  -> seesaw is CLOSER than the 14u readable band floor (delta = %.4fu short)." % (14.0 - dist_seesaw_a))
		print("     A short A<->B run may not be subject to the fog-occlusion concern that motivated that band --")
		print("     to be checked by an actual render, not assumed away. See PHASE CAPTURE below.")
	else:
		print("  -> seesaw sits at or beyond the 14u band floor.")

	# --- 3. nearest rock to the seesaw -----------------------------------
	print("")
	print("--- decor census (world AABBs, xvfb+opengl3 only) ---")
	var all_aabbs: Array = _collect_world_aabbs(builder)
	var rock_aabbs: Array = []
	for entry in all_aabbs:
		var p: String = entry["path"]
		if p.findn("rock") != -1:
			rock_aabbs.append(entry)
	print("  %d total AABBs, %d path-matched \"rock\"" % [all_aabbs.size(), rock_aabbs.size()])

	var nearest_rock: Dictionary = {}
	var nearest_rock_d: float = INF
	for r in rock_aabbs:
		var box: AABB = r["aabb"]
		var centre: Vector3 = box.position + box.size * 0.5
		var d: float = Vector2(centre.x - seesaw_pos.x, centre.z - seesaw_pos.z).length()
		if d < nearest_rock_d:
			nearest_rock_d = d
			nearest_rock = r
			nearest_rock["centre"] = centre
			nearest_rock["size"] = box.size

	if not nearest_rock.is_empty():
		var c: Vector3 = nearest_rock["centre"]
		var s: Vector3 = nearest_rock["size"]
		print("  nearest rock to seesaw: %s" % nearest_rock["path"])
		print("    centre = %s   size = %s   distance(seesaw, centre, XZ) = %.4fu" % [c, s, nearest_rock_d])
		print("  prior recon described a corridor-blocking rock ~3.3x2.5x3.3u near (14.5,4,13.4):")
		print("    size match?  measured (%.2f,%.2f,%.2f) vs described (3.3,2.5,3.3) -> %s" %
			[s.x, s.y, s.z, ("PLAUSIBLE MATCH" if absf(s.x - 3.3) < 1.0 and absf(s.y - 2.5) < 1.0 and absf(s.z - 3.3) < 1.0 else "DOES NOT MATCH")])
		print("    position match? measured %s vs described (14.5,4,13.4) -> distance = %.4fu" %
			[c, Vector3(c.x, c.y, c.z).distance_to(Vector3(14.5, 4.0, 13.4))])
	else:
		print("  no AABB path matched \"rock\" anywhere in the built world -- cannot compare to the prior recon rock.")

	# Also report the single closest rock to point A itself, and to the
	# midpoint, so the identification isn't limited to "nearest to seesaw".
	var nearest_rock_to_a: Dictionary = {}
	var nearest_rock_to_a_d: float = INF
	for r2 in rock_aabbs:
		var box2: AABB = r2["aabb"]
		var centre2: Vector3 = box2.position + box2.size * 0.5
		var d2: float = Vector2(centre2.x - POINT_A.x, centre2.z - POINT_A.z).length()
		if d2 < nearest_rock_to_a_d:
			nearest_rock_to_a_d = d2
			nearest_rock_to_a = r2
			nearest_rock_to_a["centre"] = centre2
			nearest_rock_to_a["size"] = box2.size
	if not nearest_rock_to_a.is_empty():
		print("  nearest rock to point A: %s at %s size=%s distance=%.4fu" %
			[nearest_rock_to_a["path"], nearest_rock_to_a["centre"], nearest_rock_to_a["size"], nearest_rock_to_a_d])

	var max_rock_size: float = 0.0
	var max_rock_entry: Dictionary = {}
	for r4 in rock_aabbs:
		var box4: AABB = r4["aabb"]
		if box4.size.x > max_rock_size:
			max_rock_size = box4.size.x
			max_rock_entry = r4
			max_rock_entry["centre"] = box4.position + box4.size * 0.5
	print("")
	print("--- largest rock in the WHOLE batch (48 instances, sanity check on the 3.3x2.5x3.3 claim) ---")
	if not max_rock_entry.is_empty():
		print("  %s  centre=%s  size=%s" % [max_rock_entry["path"], max_rock_entry["centre"], max_rock_entry["aabb"].size])

	print("")
	print("--- full rock census near XZ (14.5,13.4), any Y, radius 10u (searching for the ~3.3x2.5x3.3 rock the brief describes) ---")
	var ref_xz := Vector2(14.5, 13.4)
	for r3 in rock_aabbs:
		var box3b: AABB = r3["aabb"]
		var c3: Vector3 = box3b.position + box3b.size * 0.5
		var d3: float = Vector2(c3.x, c3.z).distance_to(ref_xz)
		if d3 <= 10.0:
			print("    %s  centre=%s  size=%s  dist_to_ref_xz=%.4f" % [r3["path"], c3, box3b.size, d3])

	# --- 4. "to the right of the seesaw" -- two readings -----------------
	print("")
	print("--- point B candidates: 'to the right of the seesaw' ---")

	# Reading 1: SCREEN-right from the standard hub camera (fixed rotation,
	# looking toward -Z world per HubCamera). Screen-right at a south-facing
	# camera corresponds to world -X (camera basis: right vector when
	# looking down -Z with +Y up is +X in a standard convention, but
	# HubCamera's actual fixed rotation is read directly below rather than
	# assumed).
	var camera_probe: Camera3D = hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	var cam_basis: Basis = camera_probe.global_transform.basis
	var screen_right_world: Vector3 = cam_basis.x
	screen_right_world.y = 0.0
	screen_right_world = screen_right_world.normalized()
	print("  camera basis.x (world screen-right direction, flattened) = %s" % screen_right_world)

	# Reading 2: right of the seesaw's OWN orientation/facing. The seesaw
	# pivot's own basis.x (its local right), read from the built node.
	var pivot: Node3D = seesaws[0].get("pivot", null) as Node3D
	var seesaw_right_world: Vector3 = Vector3.RIGHT
	if pivot != null and is_instance_valid(pivot):
		seesaw_right_world = pivot.global_transform.basis.x
		seesaw_right_world.y = 0.0
		seesaw_right_world = seesaw_right_world.normalized()
		print("  seesaw pivot basis.x (world, flattened) = %s  (rotation_degrees=%.2f)" % [seesaw_right_world, rad_to_deg(pivot.global_rotation.y)])
	else:
		print("  *** seesaw pivot not resolved -- falling back to Vector3.RIGHT for the orientation reading")

	var offsets: Array = [6.0, 8.0, 10.0]
	var candidates: Array = []
	for off in offsets:
		var b_screen: Vector3 = seesaw_pos + screen_right_world * off
		var b_orient: Vector3 = seesaw_pos + seesaw_right_world * off
		candidates.append({"label": "screen-right +%.0fu" % off, "point": b_screen})
		candidates.append({"label": "seesaw-facing-right +%.0fu" % off, "point": b_orient})

	var pond_c: Vector3 = builder.pond_centre()
	var lakes: Array[Dictionary] = HubRegion.lakes()
	var tall_aabbs: Array = []
	for entry3 in all_aabbs:
		var box3: AABB = entry3["aabb"]
		if box3.size.y > 1.0:
			tall_aabbs.append(entry3)

	for cand in candidates:
		var b: Vector3 = cand["point"]
		var in_region: bool = HubRegion.contains(b)
		var in_water: bool = HubRegion.in_lake_water(b)
		var own_clear: float = INF
		var own_clear_path: String = ""
		for entry4 in tall_aabbs:
			var d4: float = _point_to_aabb_xz_distance(b, entry4["aabb"])
			if d4 < own_clear:
				own_clear = d4
				own_clear_path = entry4["path"]
		var dist_to_a: float = b.distance_to(POINT_A)
		var slope_deg: float = 0.0 # flat plateau, y=0 both sides, per PARTIE 3 of CH21
		print("  %-28s B=%s  in_region=%s in_water=%s  own_clear=%.4fu (%s) -> %s  dist_to_A=%.4fu" %
			[cand["label"], b, in_region, in_water, own_clear, own_clear_path,
				("clears" if own_clear >= REAL_STRUCTURE_RADIUS else "CONFLICT"), dist_to_a])

	# --- 5. combined composition render ----------------------------------
	var keepy: Node3D = hub.get_node("WorldViewport/SubViewport/World/Keepy")
	var camera: Camera3D = camera_probe
	var viewport: SubViewport = hub.get_node("WorldViewport/SubViewport")
	await _phase_capture(hub, keepy, camera, viewport, seesaw_pos, screen_right_world, seesaw_right_world)

	hub.queue_free()
	print("")
	print("=== END SEESAW POINT B PROBE ===")
	get_tree().quit(0)

func _point_to_aabb_xz_distance(point: Vector3, box: AABB) -> float:
	var min_x: float = box.position.x
	var max_x: float = box.position.x + box.size.x
	var min_z: float = box.position.z
	var max_z: float = box.position.z + box.size.z
	var cx: float = clampf(point.x, min_x, max_x)
	var cz: float = clampf(point.z, min_z, max_z)
	return Vector2(point.x - cx, point.z - cz).length()

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

func _phase_capture(hub: Node, keepy: Node3D, camera: Camera3D, viewport: SubViewport,
		seesaw_pos: Vector3, screen_right: Vector3, seesaw_right: Vector3) -> void:
	print("")
	print("--- PHASE CAPTURE ---")
	var container: SubViewportContainer = viewport.get_parent() as SubViewportContainer
	var had_stretch: bool = container.stretch
	container.stretch = false
	viewport.size = FRAME_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame

	var marker_a := _make_marker(Color(1.0, 0.15, 0.15))
	marker_a.position = POINT_A + Vector3(0.0, 0.8, 0.0)
	_world_root.add_child(marker_a)

	var marker_seesaw := _make_marker(Color(0.15, 1.0, 0.25))
	marker_seesaw.position = seesaw_pos + Vector3(0.0, 1.2, 0.0)
	_world_root.add_child(marker_seesaw)

	var b_screen: Vector3 = seesaw_pos + screen_right * 8.0
	var b_orient: Vector3 = seesaw_pos + seesaw_right * 8.0
	var marker_b_screen := _make_marker(Color(0.15, 0.4, 1.0))
	marker_b_screen.position = b_screen + Vector3(0.0, 0.8, 0.0)
	_world_root.add_child(marker_b_screen)
	var marker_b_orient := _make_marker(Color(1.0, 0.7, 0.0))
	marker_b_orient.position = b_orient + Vector3(0.0, 0.8, 0.0)
	_world_root.add_child(marker_b_orient)

	# Composition 1: recreate Mathieu's image 2 -- seesaw + tower A in the
	# same frame, from the real in-game camera. Stand Keepy on the seesaw<->A
	# axis, a few u back from the seesaw, so both read in view.
	var to_a: Vector3 = POINT_A - seesaw_pos
	to_a.y = 0.0
	var back_dir: Vector3 = -to_a.normalized()
	var stand_pos: Vector3 = seesaw_pos + back_dir * 6.0
	keepy.global_position = stand_pos
	camera.global_position = Vector3(stand_pos.x, 0.0, stand_pos.z) + HubCamera.OFFSET
	await get_tree().process_frame
	await _render_and_save(viewport, "user://seesawb_ingame_from_seesaw.png")

	print("  --- landmark screen projection from THIS exact camera pose (to identify the tower in frame) ---")
	var builder2: HubBuilder = hub.get_node("WorldViewport/SubViewport/World/Props")
	for entry5 in builder2.layout.props:
		if entry5.get("type", &"") == &"landmark":
			var lp: Vector3 = entry5.get("position", Vector3.ZERO)
			var variant5: int = entry5.get("variant", 0)
			var name5: String = ["spire", "cairn", "slabs"][variant5] if variant5 < 3 else "?"
			var behind: bool = camera.is_position_behind(lp)
			var scr: Vector2 = camera.unproject_position(lp) if not behind else Vector2(-9999, -9999)
			var d5: float = seesaw_pos.distance_to(lp)
			print("    %s at %s  dist_from_seesaw=%.2f  behind_cam=%s  screen=%s" %
				[name5, lp, d5, behind, scr])

	# Composition 2: oblique survey shot, all 4 markers (A, seesaw, B-screen,
	# B-orient) + connecting wires, spatial overview.
	var mid: Vector3 = (POINT_A + seesaw_pos) * 0.5
	var seg: Vector3 = to_a
	var seg_len: float = maxf(seg.length(), 0.001)
	var side: Vector3 = seg.normalized().cross(Vector3.UP)
	camera.global_position = mid + side * (seg_len * 0.9) + Vector3(0.0, seg_len * 0.85, 0.0)
	camera.look_at(mid, Vector3.UP)
	var wire_a_seesaw := _make_wire(POINT_A + Vector3(0.0, 2.0, 0.0), seesaw_pos + Vector3(0.0, 2.0, 0.0))
	_world_root.add_child(wire_a_seesaw)
	await get_tree().process_frame
	await _render_and_save(viewport, "user://seesawb_oblique_overview.png")

	# Composition 3: standing AT candidate B (screen-right reading), looking
	# back -- clear-grass / natural-approach sanity check.
	keepy.global_position = b_screen
	camera.global_position = b_screen + HubCamera.OFFSET
	await get_tree().process_frame
	await _render_and_save(viewport, "user://seesawb_at_b_screen_right.png")

	# Composition 4: standing AT candidate B (seesaw-orientation reading).
	keepy.global_position = b_orient
	camera.global_position = b_orient + HubCamera.OFFSET
	await get_tree().process_frame
	await _render_and_save(viewport, "user://seesawb_at_b_orient_right.png")

	marker_a.queue_free()
	marker_seesaw.queue_free()
	marker_b_screen.queue_free()
	marker_b_orient.queue_free()
	wire_a_seesaw.queue_free()
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

func _render_and_save(viewport: SubViewport, out_path: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var err: int = image.save_png(out_path)
	print("  save_png(%s) -> %d  (globalized: %s)" %
		[out_path, err, ProjectSettings.globalize_path(out_path)])
