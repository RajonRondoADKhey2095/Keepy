extends Node
## Dev-only: MEASUREMENT ONLY, gates nothing. Systematic search for a
## zipline point B around the LOCKED point A (29.346,0,16.76 -- Mathieu's
## confirmed totems anchor, CorridorABConfirmProbe), abandoning the old
## point B (-0.913,0,2.952), which was never chosen for THIS A and already
## conflicts (hibou decor, out-of-band distance).
##
## Candidates are swept on a polar grid around A (radius 14-22u, the
## readable band already used by this chantier's prior recon; angle every
## 10 degrees) and filtered by:
##   1. HubRegion.contains() -- walkable region
##   2. not inside any lake/pond water disc -- dry footing for a tower base
##   3. clearance to the nearest "solid" decor AABB (size.y>1.0) at B itself
##      >= the REAL structure radius measured by StructureRadiusProbe
##      (~3.90-4.03u across the three shipped DivingBoards, ladder-anchored
##      -- NOT the never-verified 3.5u guess), reported as a scalar so a
##      report can compare candidates directly.
##   4. corridor A->B sampled every ~1u against the SAME "solid" AABB set,
##      worst clearance reported (informational: Point 1 in CH21's SUIVI
##      section already established a wire-height cable does not need
##      ground clearance along its whole span, only a straight look to
##      avoid a decor silhouette planted right in the sightline).
##
## Must run under xvfb+opengl3, NEVER --headless alone: MultiMesh instance
## transforms (trees/rocks/flowers, all batched) read back as identity
## under the dummy driver -- CLAUDE.md's own documented trap, already hit
## once by this chantier's first recon pass.
##
##   xvfb-run --rendering-driver opengl3 godot4 --fixed-fps 60 --path . \
##     res://scripts/dev/ZiplineBSearchProbe.tscn

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"
const FRAME_SIZE: Vector2i = Vector2i(1080, 1920)

const POINT_A: Vector3 = Vector3(29.346, 0.0, 16.76)

## Measured by StructureRadiusProbe against the three shipped DivingBoards
## (ladder-anchored max corner distance): 4.0291, 3.9785, 3.8994. The max
## of the three, not the mean, so the filter stays conservative (a real
## future tower could be as large as the biggest measured comparable).
const REAL_STRUCTURE_RADIUS: float = 4.03

const BAND_MIN: float = 14.0
const BAND_MAX: float = 22.0

var _world_root: Node3D = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "ZIPLINE B SEARCH PROBE")
	print("=== ZIPLINE B SEARCH PROBE (measurement only, gates nothing) ===")
	print("  point A (locked) = %s" % POINT_A)
	print("  real structure radius (measured, ladder-anchored, max of 3 DivingBoards) = %.4f" % REAL_STRUCTURE_RADIUS)
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var builder: HubBuilder = hub.get_node("WorldViewport/SubViewport/World/Props")
	_world_root = hub.get_node("WorldViewport/SubViewport/World")

	var driver: String = DisplayServer.get_name()
	if driver == "headless":
		print("*** ABORT: this probe collects MultiMesh (tree/rock/flower) AABBs, which are")
		print("*** unreliable under --headless. Re-run under xvfb-run --rendering-driver opengl3.")
		hub.queue_free()
		get_tree().quit(1)
		return

	var all_aabbs: Array = _collect_world_aabbs(builder)
	var tall_aabbs: Array = []
	for entry in all_aabbs:
		var box: AABB = entry["aabb"]
		if box.size.y > 1.0:
			tall_aabbs.append(entry)
	print("--- decor census: %d total AABBs, %d with size.y>1.0 (\"solid\") ---" % [all_aabbs.size(), tall_aabbs.size()])
	print("")

	var a_own_clear: float = INF
	var a_own_path: String = ""
	for entry0 in tall_aabbs:
		var d0: float = _point_to_aabb_xz_distance(POINT_A, entry0["aabb"])
		if d0 < a_own_clear:
			a_own_clear = d0
			a_own_path = entry0["path"]
	print("--- point A's OWN clearance (fixed, independent of B) ---")
	print("  nearest solid AABB to A: %s at %.4fu  (real structure radius = %.4fu -> %s)" %
		[a_own_path, a_own_clear, REAL_STRUCTURE_RADIUS,
			("WITHIN RADIUS -- conflict confirmed" if a_own_clear < REAL_STRUCTURE_RADIUS else "clears")])
	print("")

	var pond_c: Vector3 = builder.pond_centre()
	var lakes: Array[Dictionary] = HubRegion.lakes()

	print("--- sweeping candidates: radius 14-22u step 2u, angle 0-350 step 10deg ---")
	var results: Array = []
	var radius: float = BAND_MIN
	while radius <= BAND_MAX + 0.001:
		var angle_deg: float = 0.0
		while angle_deg < 360.0:
			var rad: float = deg_to_rad(angle_deg)
			var cand: Vector3 = POINT_A + Vector3(sin(rad) * radius, 0.0, cos(rad) * radius)
			var verdict: Dictionary = _evaluate_candidate(cand, radius, angle_deg, tall_aabbs, pond_c, lakes)
			if verdict.get("ok", false):
				results.append(verdict)
			angle_deg += 10.0
		radius += 2.0

	print("  %d candidates pass ALL filters (region, dry, own clearance >= %.2fu)" % [results.size(), REAL_STRUCTURE_RADIUS])
	print("")

	results.sort_custom(func(a, b): return a["corridor_worst"] > b["corridor_worst"])

	print("--- top 10 candidates by corridor worst-clearance (descending = most open) ---")
	for i in mini(10, results.size()):
		var r: Dictionary = results[i]
		var edge_dist: float = HubRegion.PLATEAU_HALF_EXTENT - maxf(absf(r["point"].x), absf(r["point"].z))
		print("  #%d  B=%s  r=%.1f theta=%.0f  own_clear=%.4f  corridor_worst=%.4f (%s at t=%.2f)  dist_A_B=%.4f  edge_dist=%.4f" %
			[i, r["point"], r["radius"], r["angle"], r["own_clear"], r["corridor_worst"], r["corridor_worst_path"], r["corridor_worst_t"], r["dist"], edge_dist])

	print("")
	print("--- pond/lake clearance for the top 5 (dry footing sanity check) ---")
	for i in mini(5, results.size()):
		var r2: Dictionary = results[i]
		var p: Vector3 = r2["point"]
		var flat := Vector2(p.x, p.z)
		var pond_flat := Vector2(pond_c.x, pond_c.z)
		print("  #%d  B=%s  distance to pond centre=%.4f (radius %.4f, clearance %.4f)" %
			[i, p, flat.distance_to(pond_flat), HubBuilder.POND_WATER_RADIUS, flat.distance_to(pond_flat) - HubBuilder.POND_WATER_RADIUS])
		for lake in lakes:
			var lc: Vector3 = lake["centre"]
			var lr: float = lake["radius"]
			var lake_flat := Vector2(lc.x, lc.z)
			print("      distance to lake %s (radius %.4f) = %.4f  clearance=%.4f" %
				[lc, lr, flat.distance_to(lake_flat), flat.distance_to(lake_flat) - lr])

	var keepy: Node3D = hub.get_node("WorldViewport/SubViewport/World/Keepy")
	var camera: Camera3D = hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	var viewport: SubViewport = hub.get_node("WorldViewport/SubViewport")
	await _phase_capture(hub, keepy, camera, viewport, results)

	hub.queue_free()
	print("")
	print("=== END ZIPLINE B SEARCH PROBE ===")
	get_tree().quit(0)

func _evaluate_candidate(cand: Vector3, radius: float, angle: float, tall_aabbs: Array,
		pond_c: Vector3, lakes: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {"ok": false, "point": cand, "radius": radius, "angle": angle}

	if not HubRegion.contains(cand):
		return out
	if HubRegion.in_lake_water(cand):
		return out
	# A candidate hugging the plateau boundary reads as "the very corner of
	# the map", not the open grass the brief asks for, and the north lobe
	# especially is only a 12u disc -- a 2u margin keeps a candidate off
	# its own rim. Filtered here, not just noted, so it cannot climb the
	# ranking on clearance alone the way the FIRST run's #2 did (edge_dist
	# 0.24u, i.e. at the literal edge of the plateau).
	var edge_dist: float = HubRegion.PLATEAU_HALF_EXTENT - maxf(absf(cand.x), absf(cand.z))
	if edge_dist < 2.0:
		return out
	var pond_flat := Vector2(pond_c.x, pond_c.z)
	if Vector2(cand.x, cand.z).distance_to(pond_flat) < HubBuilder.POND_WATER_RADIUS:
		return out

	var own_clear: float = INF
	for entry in tall_aabbs:
		var d: float = _point_to_aabb_xz_distance(cand, entry["aabb"])
		own_clear = minf(own_clear, d)
	if own_clear < REAL_STRUCTURE_RADIUS:
		return out

	var dist: float = POINT_A.distance_to(cand)

	var corridor: Dictionary = _corridor_clearance(POINT_A, cand, tall_aabbs)

	out["ok"] = true
	out["own_clear"] = own_clear
	out["dist"] = dist
	out["corridor_worst"] = corridor["worst"]
	out["corridor_worst_t"] = corridor["worst_t"]
	out["corridor_worst_path"] = corridor["worst_path"]
	return out

## Samples t in (0,1], NOT [0,1]: t=0 is point A itself, whose own
## clearance to the pillar landmark (2.5297u, already established and
## fixed regardless of B) would otherwise dominate every candidate's
## "worst" figure identically and make the corridor comparison useless
## between candidates -- caught by inspecting the first run's output,
## where every single candidate reported the exact same worst=2.5297 at
## t=0.00 against the same mesh. A's own conflict is reported separately.
func _corridor_clearance(a: Vector3, b: Vector3, aabbs: Array) -> Dictionary:
	var dist: float = a.distance_to(b)
	var steps: int = maxi(int(ceil(dist)), 1)
	var worst: float = INF
	var worst_t: float = 0.0
	var worst_path: String = ""
	for i in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector3 = a.lerp(b, t)
		for entry in aabbs:
			var d: float = _point_to_aabb_xz_distance(p, entry["aabb"])
			if d < worst:
				worst = d
				worst_t = t
				worst_path = entry["path"]
	return {"worst": worst, "worst_t": worst_t, "worst_path": worst_path}

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

func _phase_capture(hub: Node, keepy: Node3D, camera: Camera3D, viewport: SubViewport, results: Array) -> void:
	print("")
	print("--- PHASE CAPTURE (top 3 candidates) ---")
	var container: SubViewportContainer = viewport.get_parent() as SubViewportContainer
	var had_stretch: bool = container.stretch
	container.stretch = false
	viewport.size = FRAME_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame

	var marker_a := _make_marker(Color(1.0, 0.15, 0.15))
	marker_a.position = POINT_A + Vector3(0.0, 0.8, 0.0)
	_world_root.add_child(marker_a)

	for i in mini(3, results.size()):
		var r: Dictionary = results[i]
		var b: Vector3 = r["point"]

		var marker_b := _make_marker(Color(0.15, 0.4, 1.0))
		marker_b.position = b + Vector3(0.0, 0.8, 0.0)
		_world_root.add_child(marker_b)
		var wire := _make_wire(POINT_A + Vector3(0.0, 2.0, 0.0), b + Vector3(0.0, 2.0, 0.0))
		_world_root.add_child(wire)

		# Oblique survey shot, both markers + wire, spatial overview.
		var mid: Vector3 = (POINT_A + b) * 0.5
		var to_a: Vector3 = POINT_A - b
		to_a.y = 0.0
		var seg_len: float = maxf(to_a.length(), 0.001)
		var side: Vector3 = to_a.normalized().cross(Vector3.UP)
		camera.global_position = mid + side * (seg_len * 0.7) + Vector3(0.0, seg_len * 0.75, 0.0)
		camera.look_at(mid, Vector3.UP)
		await get_tree().process_frame
		await _render_and_save(viewport, "user://bsearch_cand%d_oblique.png" % i)

		# Real in-game view standing AT B (fixed HubCamera rotation): the
		# "clear grass, natural approach" check the brief still asks for
		# (soft criterion, not a filter).
		keepy.global_position = b
		camera.global_position = b + HubCamera.OFFSET
		await get_tree().process_frame
		await _render_and_save(viewport, "user://bsearch_cand%d_at_b.png" % i)

		marker_b.queue_free()
		wire.queue_free()

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

func _render_and_save(viewport: SubViewport, out_path: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var err: int = image.save_png(out_path)
	print("  save_png(%s) -> %d  (globalized: %s)" %
		[out_path, err, ProjectSettings.globalize_path(out_path)])
