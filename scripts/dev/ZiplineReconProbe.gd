extends Node
## Dev-only: MEASUREMENT ONLY, gates nothing. Pure recon for the tyrolienne
## brief (3 sept 2026): converts Mathieu's two screen-annotated points (A
## top/back, B bottom/front) into world coordinates via the SAME camera ->
## Plane(UP, 0) raycast HubTapInput.gd already uses for every tap, from the
## standard hub camera spawn, then measures altitude, distance, slope,
## decor clearance (real AABBs, not guessed), pond intersection (via the
## published pond_centre()/POND_WATER_RADIUS accessor, never recopied),
## and saves two offscreen renders of the A<->B corridor.
##
## No prior CH21 file existed before this probe was written, and no
## "13 degree slope threshold" or "14-22u readable band" is documented
## anywhere in this repo (grepped CLAUDE.md and every docs/lots/*.md) --
## so this probe does not verify against such a threshold, it MEASURES
## the corridor fresh and proposes a threshold for Mathieu to accept or
## reject, per this repo's own "mesurer, pas supposer" doctrine.
##
## Two phases, split on the actual rendering driver in use -- the same
## split LakeZoneReconProbe.gd already uses, for the same reason:
##   PHASE MEASURE  raycasts, distances, AABB clearance, pond check.
##                   Pure transform/geometry math, no pixel read, so
##                   --headless is fine (DUMMY driver races through it).
##   PHASE CAPTURE   two offscreen renders of the corridor. Needs a real
##                   GPU driver -- --headless forces DUMMY, which cannot
##                   render a pixel (CLAUDE.md's own headless-vs-xvfb trap).
##
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/ZiplineReconProbe.tscn
##
##   xvfb-run --rendering-driver opengl3 godot4 --fixed-fps 60 --path . \
##     res://scripts/dev/ZiplineReconProbe.tscn
##
## Both invocations run PHASE MEASURE (needed by the captures too, to
## place the debug markers); only the xvfb one reaches PHASE CAPTURE.

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

## Mathieu's annotated screen fractions, read off his capture. (x, y) as
## fraction of the 1080x1920 standard frame this project has used for
## every screen-space recon since HubTapInput.gd shipped.
const POINT_A_FRACTION: Vector2 = Vector2(0.52, 0.24)
const POINT_B_FRACTION: Vector2 = Vector2(0.38, 0.72)
const FRAME_SIZE: Vector2i = Vector2i(1080, 1920)

## A conservative footprint radius for a stair+tower structure at each
## anchor -- half again the boat's own 2.5u tap-target radius, since a
## stair is a bigger footprint than a hull. Not a shipped constant
## anywhere in this repo (there is no prior zipline structure to read one
## off), so it is stated here as a PROPOSAL, not a measured fact.
const PROPOSED_STRUCTURE_RADIUS: float = 3.5

var _world_root: Node3D = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "ZIPLINE RECON PROBE")

	print("=== ZIPLINE RECON PROBE (measurement only, gates nothing) ===")
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

	# Standard camera spawn: Keepy at the origin, camera at HubCamera's own
	# published OFFSET, exactly as HubWorld.tscn authors it before any
	# follow-lerp runs. Same technique LakeZoneReconProbe already uses.
	keepy.global_position = Vector3.ZERO
	camera.global_position = Vector3.ZERO + HubCamera.OFFSET

	var container: SubViewportContainer = viewport.get_parent() as SubViewportContainer
	var had_stretch: bool = container.stretch
	container.stretch = false
	viewport.size = FRAME_SIZE
	await get_tree().process_frame

	var point_a: Vector3 = _raycast_ground(camera, POINT_A_FRACTION)
	var point_b: Vector3 = _raycast_ground(camera, POINT_B_FRACTION)

	_phase_measure(builder, point_a, point_b)

	var driver: String = DisplayServer.get_name()
	if driver != "headless":
		await _phase_capture(hub, camera, viewport, point_a, point_b)
	else:
		print("")
		print("(driver=headless: skipping PHASE CAPTURE, no pixel can be read)")

	container.stretch = had_stretch
	hub.queue_free()
	print("")
	print("=== END ZIPLINE RECON PROBE ===")
	get_tree().quit(0)

## Screen fraction -> world point, via the exact camera ray -> Plane(UP,0)
## intersection HubTapInput._handle_point() uses for every real tap. Not a
## reimplementation: same two calls, same plane.
func _raycast_ground(camera: Camera3D, fraction: Vector2) -> Vector3:
	var local := Vector2(fraction.x * FRAME_SIZE.x, fraction.y * FRAME_SIZE.y)
	var origin := camera.project_ray_origin(local)
	var direction := camera.project_ray_normal(local)
	var ground := Plane(Vector3.UP, 0.0)
	var hit: Variant = ground.intersects_ray(origin, direction)
	if hit == null:
		push_error("ZiplineReconProbe: ray for fraction %s missed Plane(UP,0) -- camera looking above the horizon." % fraction)
		return Vector3.ZERO
	return hit

## ---------------------------------------------------------------------
## PHASE MEASURE -- altitude, distance, slope, pond intersection, decor
## AABB clearance. Pure geometry, headless-safe.
func _phase_measure(builder: HubBuilder, point_a: Vector3, point_b: Vector3) -> void:
	print("--- PHASE MEASURE ---")
	print("  point A (frac %s) -> world %s" % [POINT_A_FRACTION, point_a])
	print("  point B (frac %s) -> world %s" % [POINT_B_FRACTION, point_b])
	print("")

	var dist: float = point_a.distance_to(point_b)
	var dy: float = point_b.y - point_a.y
	print("  altitude A.y=%.4f  altitude B.y=%.4f  delta=%.4f" % [point_a.y, point_b.y, dy])
	print("  distance A<->B (3D) = %.4f" % dist)
	if absf(dy) < 0.001:
		print("  BOTH points resolve to the SAME ground plane (Plane(UP,0), y=0).")
		print("  The hub's Ground mesh is a flat PlaneMesh with no height field --")
		print("  this is the same plane every hop/tap in the project resolves")
		print("  against, so it is not an approximation: any elevation the two")
		print("  zipline anchors end up at is a TOWER-HEIGHT design choice, not")
		print("  a terrain-driven necessity. Symmetric towers of equal height")
		print("  are therefore the natural default, not a compromise.")
	else:
		print("  *** ALTITUDES DIFFER -- decision point for Mathieu, not masked ***")

	# Horizontal bearing both ways, for a symmetric two-door design.
	var flat_a := Vector2(point_a.x, point_a.z)
	var flat_b := Vector2(point_b.x, point_b.z)
	var horiz_dist: float = flat_a.distance_to(flat_b)
	print("  horizontal distance A<->B = %.4f" % horiz_dist)

	print("")
	print("--- Pond intersection (published accessor, not recopied) ---")
	var pond: Vector3 = builder.pond_centre()
	var pond_r: float = HubBuilder.POND_WATER_RADIUS
	print("  builder.pond_centre() = %s   HubBuilder.POND_WATER_RADIUS = %.4f" % [pond, pond_r])
	if pond == Vector3.INF:
		print("  pond_centre() reports Vector3.INF -- pond not built on this run, cannot check.")
	else:
		var pond_flat := Vector2(pond.x, pond.z)
		var seg_dist: float = _point_segment_distance(pond_flat, flat_a, flat_b)
		print("  closest approach of segment A-B to pond centre = %.4f  (pond radius %.4f)" % [seg_dist, pond_r])
		if seg_dist < pond_r:
			print("  *** SEGMENT A-B CROSSES THE POND (%.4f < %.4f) ***" % [seg_dist, pond_r])
		else:
			print("  segment A-B clears the pond by %.4f u" % (seg_dist - pond_r))

	print("")
	print("--- Decor AABB clearance (world-space, collected live from the built hub) ---")
	# Collected from `builder` (the Props node), NOT the World root: the
	# World root also carries the Ground PlaneMesh (600x600, distance 0
	# from every point on the plateau by construction) and Keepy's own
	# placeholder capsule -- neither is "decor", and including the Ground
	# plane made every point read as a collision. Caught by re-reading this
	# probe's own first real output rather than trusted on the first
	# green/red split -- the exact "blind check" trap CLAUDE.md documents.
	var all_aabbs: Array = _collect_world_aabbs(builder)
	# A second filter, found only by reading the FIRST real run's output:
	# several of those 424 are near-zero-height ground overlays (islet
	# discs, the pond bank, the stream's water ribbon) with enormous XZ
	# footprints -- every point on the plateau falls "inside" one of them
	# trivially, which is correct for "is this point on decorated ground"
	# and meaningless for "does a stair/tower footprint collide with a
	# standing prop". Kept SEPARATE rather than silently dropped: both
	# counts are printed, so a future reader can see the filter was
	# applied and why, not just trust a smaller number.
	var aabbs: Array = []
	var tall_aabbs: Array = []
	for entry in all_aabbs:
		var box: AABB = entry["aabb"]
		if box.size.y > 0.3:
			aabbs.append(entry)
		if box.size.y > 1.0:
			tall_aabbs.append(entry)
	print("  total decor AABBs collected: %d  (%d with size.y>0.3, %d with size.y>1.0)" %
		[all_aabbs.size(), aabbs.size(), tall_aabbs.size()])
	print("  --- against size.y>0.3 (excludes only ground overlays: islets/bank/water) ---")
	_report_clearance("point A", point_a, aabbs)
	_report_clearance("point B", point_b, aabbs)
	_report_corridor_clearance(point_a, point_b, aabbs)
	print("  --- against size.y>1.0 (excludes ground decals AND flat markers like portal rings) ---")
	_report_clearance("point A", point_a, tall_aabbs)
	_report_clearance("point B", point_b, tall_aabbs)
	_report_corridor_clearance(point_a, point_b, tall_aabbs)

	print("  --- nearest 5 objects of ANY size, for a qualitative cross-check against Mathieu's own screen annotation ---")
	_report_nearest_n("point A", point_a, all_aabbs, 5)
	_report_nearest_n("point B", point_b, all_aabbs, 5)

	print("")
	print("--- Proposed slope check (no prior threshold exists in this repo --")
	print("    grepped CLAUDE.md + docs/lots/*.md, none found; this is a fresh")
	print("    measurement proposing a threshold, not a verification of one) ---")
	# A cable slope depends on the chosen tower-height difference, which is
	# a design free variable here (ground is flat -- see above). Report
	# the angle for a spread of plausible symmetric-vs-offset deck heights
	# so Mathieu can see the shape of the tradeoff rather than one number.
	for deck_delta in [0.0, 1.0, 2.0, 3.0]:
		var angle_deg: float = rad_to_deg(atan2(deck_delta, horiz_dist))
		print("  deck height offset %.1fu over %.4fu horizontal -> cable slope %.2f deg" %
			[deck_delta, horiz_dist, angle_deg])

func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 1e-8:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return p.distance_to(closest)

## Walks the built hub's live World node and collects every MeshInstance3D
## and MultiMeshInstance3D bound, in WORLD space -- generic, not scoped to
## any one decor family (this repo names no "totem"/"pillar" decor type by
## code, so this collects everything real rather than guessing a filter).
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
		print("    *** WITHIN PROPOSED %.1fu STRUCTURE RADIUS -- collision risk, relocate/shrink footprint or nudge anchor ***" % PROPOSED_STRUCTURE_RADIUS)
	else:
		print("    clears the proposed %.1fu structure radius by %.4fu" % [PROPOSED_STRUCTURE_RADIUS, nearest_dist - PROPOSED_STRUCTURE_RADIUS])

## Horizontal (XZ) distance from a point to an AABB's footprint -- ignores
## Y, since the concern is "does a tower/stair footprint fit on the
## ground here", not vertical overlap with foliage crowns.
func _point_to_aabb_xz_distance(point: Vector3, box: AABB) -> float:
	var min_x: float = box.position.x
	var max_x: float = box.position.x + box.size.x
	var min_z: float = box.position.z
	var max_z: float = box.position.z + box.size.z
	var cx: float = clampf(point.x, min_x, max_x)
	var cz: float = clampf(point.z, min_z, max_z)
	return Vector2(point.x - cx, point.z - cz).length()

## Sweeps the corridor A->B in ~1u steps and reports the single worst
## clearance found along it, not just at the endpoints.
func _report_nearest_n(label: String, point: Vector3, aabbs: Array, n: int) -> void:
	var scored: Array = []
	for entry in aabbs:
		scored.append({"d": _point_to_aabb_xz_distance(point, entry["aabb"]), "path": entry["path"], "aabb": entry["aabb"]})
	scored.sort_custom(func(a, b): return a["d"] < b["d"])
	print("  %s nearest %d:" % [label, n])
	for i in mini(n, scored.size()):
		print("    %.4fu  %s  box=%s" % [scored[i]["d"], scored[i]["path"], scored[i]["aabb"]])

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
	print("  corridor sweep (%d samples): worst clearance = %.4fu at t=%.2f (%.1f%% of the way A->B)" %
		[steps + 1, worst, worst_t, worst_t * 100.0])
	print("    worst-clearance object: %s  box=%s" % [worst_path, worst_box])

## ---------------------------------------------------------------------
## PHASE CAPTURE -- two offscreen renders of the corridor, marked with
## debug spheres at A and B, one render looking A->B and one B->A (the
## "both directions" the brief asks the corridor be checked in).
func _phase_capture(hub: Node, camera: Camera3D, viewport: SubViewport, point_a: Vector3, point_b: Vector3) -> void:
	print("")
	print("--- PHASE CAPTURE: corridor renders, both directions ---")
	print("  DisplayServer driver: %s" % DisplayServer.get_name())

	var marker_a := _make_marker(Color(1.0, 0.15, 0.15))
	marker_a.position = point_a + Vector3(0.0, 0.6, 0.0)
	_world_root.add_child(marker_a)
	var marker_b := _make_marker(Color(0.15, 0.4, 1.0))
	marker_b.position = point_b + Vector3(0.0, 0.6, 0.0)
	_world_root.add_child(marker_b)

	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Render 1: standard hub camera pose (shows both anchors as they will
	# actually be seen by the player standing at spawn).
	await _render_and_save(viewport, "user://zipline_recon_standard_view.png")

	# Render 2: camera pulled back and re-aimed to look along the A->B
	# corridor itself (a top-down-ish oblique), so the corridor's relation
	# to the pond and decor is visible in one frame from BOTH directions'
	# perspective at once, rather than two near-identical hub-camera shots.
	var mid: Vector3 = (point_a + point_b) * 0.5
	var to_b: Vector3 = (point_b - point_a)
	to_b.y = 0.0
	var corridor_len: float = maxf(to_b.length(), 0.001)
	var side: Vector3 = to_b.normalized().cross(Vector3.UP)
	var overhead_pos: Vector3 = mid + side * (corridor_len * 0.9) + Vector3(0.0, corridor_len * 0.9, 0.0)
	camera.global_position = overhead_pos
	camera.look_at(mid, Vector3.UP)
	await get_tree().process_frame
	await _render_and_save(viewport, "user://zipline_recon_corridor_overview.png")

	marker_a.queue_free()
	marker_b.queue_free()

func _make_marker(color: Color) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
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
