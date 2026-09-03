extends Node
## Dev-only: MEASUREMENT ONLY, gates nothing. Follow-up recon on top of
## CH21_TYROLIENNE.md's PARTIE 3, for three questions Mathieu asked after
## reading that first recon:
##
##   1) Does the fog-occlusion defect ("a near-horizontal wire reads as a
##      flat line lost in the fog band near the top of frame") actually
##      reproduce at the steepest candidate slope (delta=3u, 6.37 deg), and
##      if not, at what height (if any) does it clear -- measured on real
##      rendered pixels, not asserted.
##   2) Recompute the two clearance conflicts CH21 already found (point A
##      vs the DivingBoard post, point B vs the owl decor mesh) under a few
##      candidate nudges, so Mathieu has actual numbers per option rather
##      than a bare proposal.
##   3) Distance from point A to the GREAT lake (HubRegion.lakes(), not the
##      small pond CH21 already checked) via the published accessor, plus a
##      render from Keepy's REAL position at point A (not the spawn-based
##      standard view CH21 used for anchor identification).
##
## ⚠️ No "13 degree" / "14-22u readable band" threshold is documented
## anywhere in this repo either (grepped CLAUDE.md + docs/lots/*.md again
## for this probe: zero hits beyond CH21's own note that it does not
## exist). This probe does not test against that band; it measures the
## corridor fresh, the same discipline CH21 already applied.
##
## Two phases, split the same way every offscreen-pixel probe in this repo
## is split (CLAUDE.md's own headless-vs-xvfb trap):
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/CorridorFollowupProbe.tscn
##   xvfb-run --rendering-driver opengl3 godot4 --fixed-fps 60 --path . \
##     res://scripts/dev/CorridorFollowupProbe.tscn

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

const POINT_A_FRACTION: Vector2 = Vector2(0.52, 0.24)
const POINT_B_FRACTION: Vector2 = Vector2(0.38, 0.72)
const FRAME_SIZE: Vector2i = Vector2i(1080, 1920)

## Deck-height offsets to sweep for the wire-readability test. 3.0 is the
## steepest candidate CH21 already tabled (6.37 deg); the rest are ADDED
## by this probe to answer "does any reasonable height clear it".
const DECK_DELTAS: Array[float] = [0.0, 3.0, 6.0, 10.0, 16.0, 24.0]

## Minimum deck height off the ground for the NEAR anchor (A), before the
## delta is added to the FAR anchor (B) to produce the slope -- otherwise
## a 0.0-delta wire would sit ON the ground, which is not what a tower
## looks like. PROPOSED, not shipped: stated here as a free choice, same
## footing as CH21's own PROPOSED_STRUCTURE_RADIUS.
const NEAR_TOWER_BASE: float = 2.0

## Candidate nudge distances tried for the two clearance conflicts, in
## world units, moved directly away from the conflicting object along the
## anchor-to-object vector (the cheapest direction: it does not require
## guessing a "clear" bearing, it reads the real one off the AABB found).
const NUDGE_CANDIDATES: Array[float] = [1.0, 1.5, 2.0, 3.0]

const PROPOSED_STRUCTURE_RADIUS: float = 3.5

var _world_root: Node3D = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "CORRIDOR FOLLOWUP PROBE")

	print("=== CORRIDOR FOLLOWUP PROBE (measurement only, gates nothing) ===")
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
		await _phase_capture(hub, keepy, camera, viewport, container, point_a, point_b, builder)
	else:
		print("")
		print("(driver=headless: skipping PHASE CAPTURE, no pixel can be read)")

	container.stretch = had_stretch
	hub.queue_free()
	print("")
	print("=== END CORRIDOR FOLLOWUP PROBE ===")
	get_tree().quit(0)

func _raycast_ground(camera: Camera3D, fraction: Vector2) -> Vector3:
	var local := Vector2(fraction.x * FRAME_SIZE.x, fraction.y * FRAME_SIZE.y)
	var origin := camera.project_ray_origin(local)
	var direction := camera.project_ray_normal(local)
	var ground := Plane(Vector3.UP, 0.0)
	var hit: Variant = ground.intersects_ray(origin, direction)
	if hit == null:
		push_error("CorridorFollowupProbe: ray for fraction %s missed Plane(UP,0)." % fraction)
		return Vector3.ZERO
	return hit

## ---------------------------------------------------------------------
## PHASE MEASURE -- great-lake distance (via the published accessor) and
## the two clearance-conflict nudge tables. Pure geometry, headless-safe.
func _phase_measure(builder: HubBuilder, point_a: Vector3, point_b: Vector3) -> void:
	print("--- PHASE MEASURE ---")
	print("  point A = %s   point B = %s" % [point_a, point_b])
	print("")

	print("--- POINT 3.1: great-lake distance from point A (HubRegion.lakes(), published accessor) ---")
	var flat_a := Vector2(point_a.x, point_a.z)
	var lakes: Array[Dictionary] = HubRegion.lakes()
	for i in lakes.size():
		var entry: Dictionary = lakes[i]
		var centre: Vector3 = entry["centre"]
		var radius: float = entry["radius"]
		var flat_c := Vector2(centre.x, centre.z)
		var d: float = flat_a.distance_to(flat_c)
		var clearance: float = d - radius
		print("  lakes()[%d]  centre=%s  radius=%.4f  dist(A,centre)=%.4f  clearance-to-shore=%.4f%s" %
			[i, centre, radius, d, clearance,
			(" *** POINT A IS INSIDE THIS LOBE'S WATER CIRCLE ***" if clearance < 0.0 else "")])
	print("  (HubRegion.GREATLAKE_WATER_RADIUS=%.1f is the main lobe -- 'grand lac'; SPAWN_LAKE_WATER_RADIUS=%.1f is the spawn-side lobe, a second body of the same great-lake family, not the small pond CH21 already checked via pond_centre()/POND_WATER_RADIUS)" %
		[HubRegion.GREATLAKE_WATER_RADIUS, HubRegion.SPAWN_LAKE_WATER_RADIUS])

	print("")
	print("--- POINT 2: clearance-conflict nudge candidates (recomputed against the live built AABB tree) ---")
	var all_aabbs: Array = _collect_world_aabbs(builder)
	var tall_aabbs: Array = []
	for entry in all_aabbs:
		var box: AABB = entry["aabb"]
		if box.size.y > 1.0:
			tall_aabbs.append(entry)

	print("  --- conflict 1: point A vs DivingBoard post ---")
	_report_nudges("point A", point_a, point_b, true, tall_aabbs)

	print("  --- conflict 2: point B vs owl decor ---")
	_report_nudges("point B", point_b, point_a, false, tall_aabbs)

func _nearest_tall(point: Vector3, aabbs: Array) -> Dictionary:
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
	return {"dist": nearest_dist, "path": nearest_path, "aabb": nearest_aabb}

## Nudges `point` directly away from its nearest tall obstacle by each of
## NUDGE_CANDIDATES, then reports: the new clearance to that SAME
## obstacle, whether the nudged point now collides with any OTHER tall
## obstacle, and the effect on the A<->B distance/slope table (recomputed
## with the OTHER endpoint held fixed -- `other` and `other_is_b` say
## which one is not moving).
func _report_nudges(label: String, point: Vector3, other: Vector3, other_is_b: bool, tall_aabbs: Array) -> void:
	var nearest: Dictionary = _nearest_tall(point, tall_aabbs)
	print("    %s baseline: nearest tall obstacle = %s at %.4fu (box=%s)" %
		[label, nearest["path"], nearest["dist"], nearest["aabb"]])
	var box: AABB = nearest["aabb"]
	var cx: float = clampf(point.x, box.position.x, box.position.x + box.size.x)
	var cz: float = clampf(point.z, box.position.z, box.position.z + box.size.z)
	var away: Vector2 = Vector2(point.x - cx, point.z - cz)
	if away.length() < 0.001:
		away = Vector2(1.0, 0.0)
		print("    (point sits exactly on the obstacle footprint's edge -- using +X as the nudge direction, arbitrary)")
	away = away.normalized()
	print("    nudge direction (away from obstacle, XZ) = %s" % away)

	print("    option A -- NUDGE THE ANCHOR by N u along that direction:")
	for n in NUDGE_CANDIDATES:
		var moved: Vector3 = point + Vector3(away.x, 0.0, away.y) * n
		var new_dist_to_obstacle: float = _point_to_aabb_xz_distance(moved, box)
		var second: Dictionary = _nearest_tall(moved, tall_aabbs)
		var moved_a: Vector3
		var moved_b: Vector3
		if other_is_b:
			moved_a = moved
			moved_b = other
		else:
			moved_a = other
			moved_b = moved
		var new_horiz: float = Vector2(moved_a.x, moved_a.z).distance_to(Vector2(moved_b.x, moved_b.z))
		print("      +%.1fu -> clearance to same obstacle = %.4fu (%s) | nearest obstacle overall after move = %s at %.4fu | new A<->B horizontal distance = %.4fu (was %.4fu, delta %.4fu)" %
			[n, new_dist_to_obstacle,
			("CLEARS %.1fu radius" % PROPOSED_STRUCTURE_RADIUS if new_dist_to_obstacle >= PROPOSED_STRUCTURE_RADIUS else "still short of %.1fu radius" % PROPOSED_STRUCTURE_RADIUS),
			second["path"], second["dist"],
			new_horiz, point.distance_to(other), new_horiz - point.distance_to(other)])

	print("    option B -- REDUCE THE STRUCTURE RADIUS to just clear the baseline obstacle:")
	var needed_radius: float = nearest["dist"]
	print("      radius would need to drop to <= %.4fu (from the proposed %.1fu) to clear THIS obstacle with zero anchor movement" %
		[needed_radius, PROPOSED_STRUCTURE_RADIUS])

## ---------------------------------------------------------------------
## Shared AABB plumbing (same technique as ZiplineReconProbe.gd).
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

## ---------------------------------------------------------------------
## PHASE CAPTURE -- three render sets: (1) wire-readability sweep against
## fog from the CH21 standard hub camera pose, (2) a render from Keepy's
## REAL position at point A (not the spawn-based standard view).
func _phase_capture(hub: Node, keepy: Node3D, camera: Camera3D, viewport: SubViewport, container: SubViewportContainer, point_a: Vector3, point_b: Vector3, builder: HubBuilder) -> void:
	print("")
	print("--- PHASE CAPTURE ---")
	print("  DisplayServer driver: %s" % DisplayServer.get_name())

	var env: Environment = (_world_root.get_node("WorldEnvironment") as WorldEnvironment).environment
	print("  fog_enabled=%s fog_density=%.4f fog_sky_affect=%.4f fog_light_color=%s (HubWorld's fog is static -- no SwampAtmosphere node in this scene, confirmed absent by search)" %
		[env.fog_enabled, env.fog_density, env.fog_sky_affect, env.fog_light_color])

	print("")
	print("--- POINT 1: wire-readability sweep, standard hub camera, fog ON (the scene's own always-on fog) ---")
	# Standard hub camera pose: Keepy and camera at their spawn positions,
	# exactly CH21's own "standard view" render -- this is the view a
	# player actually has of the corridor from the hub, not a synthetic
	# along-the-wire shot.
	keepy.global_position = Vector3.ZERO
	camera.global_position = Vector3.ZERO + HubCamera.OFFSET
	await get_tree().process_frame

	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	for delta in DECK_DELTAS:
		var a_top: Vector3 = point_a + Vector3(0.0, NEAR_TOWER_BASE, 0.0)
		var b_top: Vector3 = point_b + Vector3(0.0, NEAR_TOWER_BASE + delta, 0.0)
		var wire := _make_wire(a_top, b_top)
		_world_root.add_child(wire)
		var marker_a := _make_marker(Color(1.0, 0.15, 0.15))
		marker_a.position = a_top
		_world_root.add_child(marker_a)
		var marker_b := _make_marker(Color(0.15, 0.4, 1.0))
		marker_b.position = b_top
		_world_root.add_child(marker_b)
		await get_tree().process_frame

		var fname: String = "user://corridor_wire_delta_%02d.png" % int(delta)
		await _render_and_save(viewport, fname)

		var img: Image = viewport.get_texture().get_image()
		_measure_wire_readability(camera, a_top, b_top, img, delta)

		wire.queue_free()
		marker_a.queue_free()
		marker_b.queue_free()
		await get_tree().process_frame

	print("")
	print("--- POINT 3.2: render from Keepy's REAL position at point A (not the spawn-based standard view) ---")
	keepy.global_position = point_a
	camera.global_position = Vector3(point_a.x, 0.0, point_a.z) + HubCamera.OFFSET
	await get_tree().process_frame
	await _render_and_save(viewport, "user://corridor_point_a_real_position.png")

	print("")
	print("--- POINT 3.2b: which great-lake landmark sits closest to A -- identified from the LAYOUT (variant 0=spire, 1=cairn, 2=slabs/'totems'), not guessed from a render ---")
	# Three &"landmark" entries exist on the great lake per
	# resources/hub/hub_layout.tres: (17.372,-12.464) variant 0 spire,
	# (6.836,-20.528) variant 1 cairn, (19.884,-25.496) variant 2 slabs.
	# Read from the layout resource directly (not retyped by hand here)
	# so a future edit to the layout cannot silently desync this report.
	var candidates: Array = []
	for entry in builder.layout.props:
		if entry.get("type", &"") == &"landmark":
			candidates.append(entry)
	var flat_a2 := Vector2(point_a.x, point_a.z)
	var nearest_landmark: Dictionary = {}
	var nearest_landmark_dist: float = INF
	for entry in candidates:
		var pos: Vector3 = entry.get("position", Vector3.ZERO)
		var d: float = flat_a2.distance_to(Vector2(pos.x, pos.z))
		var variant: int = entry.get("variant", 0)
		var name: String = ["spire (needle, single)", "cairn (blocky pile, single)", "slabs (TWO standing bars -- 'totems')"][variant] if variant < 3 else "unknown"
		print("  landmark variant=%d (%s) at %s -> %.4fu from point A" % [variant, name, pos, d])
		if d < nearest_landmark_dist:
			nearest_landmark_dist = d
			nearest_landmark = entry
	print("  NEAREST to point A: variant=%d at %.4fu" % [nearest_landmark.get("variant", 0), nearest_landmark_dist])

	# Render 3: camera pulled up and back, looking down at the centroid of
	# the three landmark positions, so each silhouette (needle / blocky
	# pile / paired bars) is directly visible in one frame rather than
	# inferred from whichever one happens to poke into the standard view.
	var centroid := Vector3.ZERO
	for entry in candidates:
		centroid += (entry.get("position", Vector3.ZERO) as Vector3)
	if candidates.size() > 0:
		centroid /= candidates.size()
	camera.global_position = centroid + Vector3(0.0, 26.0, 22.0)
	camera.look_at(centroid, Vector3.UP)
	await get_tree().process_frame
	await _render_and_save(viewport, "user://corridor_greatlake_landmarks_id.png")

	# That single wide shot may crop the farther islets at this camera's
	# narrow-ish FOV -- so also shoot each NEARBY candidate individually
	# (within 25u of point A -- the three actually in view/relevant from
	# A, not all 12 landmarks on the whole plateau), close and
	# near-overhead, where its silhouette cannot be ambiguous.
	var closeup_index: int = 0
	for entry in candidates:
		var pos: Vector3 = entry.get("position", Vector3.ZERO)
		var d_from_a: float = flat_a2.distance_to(Vector2(pos.x, pos.z))
		if d_from_a > 25.0:
			continue
		var variant: int = entry.get("variant", 0)
		camera.global_position = pos + Vector3(6.0, 11.0, 6.0)
		camera.look_at(pos + Vector3(0.0, 3.0, 0.0), Vector3.UP)
		await get_tree().process_frame
		await _render_and_save(viewport, "user://corridor_landmark_%d_variant%d_%.1fu_closeup.png" % [closeup_index, variant, d_from_a])
		closeup_index += 1

	keepy.global_position = Vector3.ZERO
	camera.global_position = Vector3.ZERO + HubCamera.OFFSET

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
	mat.albedo_color = Color(1.0, 0.95, 0.1) # bright yellow: maximum contrast vs the dark swamp fog colour, so any occlusion measured here is NOT an artifact of an unlucky wire colour choice
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
	sphere.radius = 0.4
	sphere.height = 0.8
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh_inst.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_inst.material_override = mat
	return mesh_inst

## Objective readability check: projects both endpoints to screen space
## (rejecting the sample if either falls behind the camera -- the BLIND
## CHECK doctrine this repo documents), then samples the ACTUAL rendered
## pixel at the wire's screen midpoint plus a background reference pixel
## offset 40px directly above it (still sky/fog, not the wire), and
## reports a WCAG-style luminance contrast ratio between the two -- the
## same style of number this project already gates hazard/floor contrast
## with elsewhere (CLAUDE.md's "3.0:1" convention).
func _measure_wire_readability(camera: Camera3D, a: Vector3, b: Vector3, img: Image, delta: float) -> void:
	var behind_a: bool = camera.is_position_behind(a)
	var behind_b: bool = camera.is_position_behind(b)
	if behind_a or behind_b:
		print("  delta=%.1fu: *** endpoint behind camera (A behind=%s, B behind=%s) -- cannot measure on-screen, skipping ***" %
			[delta, behind_a, behind_b])
		return
	var screen_a: Vector2 = camera.unproject_position(a)
	var screen_b: Vector2 = camera.unproject_position(b)
	var mid: Vector2 = (screen_a + screen_b) * 0.5
	var w: int = img.get_width()
	var h: int = img.get_height()
	var mid_clamped := Vector2i(clampi(int(mid.x), 0, w - 1), clampi(int(mid.y), 0, h - 1))
	var bg_y: int = clampi(mid_clamped.y - 40, 0, h - 1)
	var bg_clamped := Vector2i(mid_clamped.x, bg_y)

	var wire_px: Color = img.get_pixel(mid_clamped.x, mid_clamped.y)
	var bg_px: Color = img.get_pixel(bg_clamped.x, bg_clamped.y)
	var contrast: float = _contrast_ratio(wire_px, bg_px)

	var span_px: float = absf(screen_a.y - screen_b.y)
	var span_frac: float = span_px / float(h)

	print("  delta=%.1fu  screen A=%s screen B=%s  wire vertical span=%.1fpx (%.2f%% of frame height)  wire px@mid=%s  bg px(40px above)=%s  contrast=%.2f:1%s" %
		[delta, screen_a, screen_b, span_px, span_frac * 100.0, wire_px, bg_px, contrast,
		("  *** BELOW 3.0:1, reads as lost in the fog band ***" if contrast < 3.0 else "  (clears 3.0:1)")])

func _contrast_ratio(c1: Color, c2: Color) -> float:
	var l1: float = _relative_luminance(c1)
	var l2: float = _relative_luminance(c2)
	var lighter: float = maxf(l1, l2)
	var darker: float = minf(l1, l2)
	return (lighter + 0.05) / (darker + 0.05)

func _relative_luminance(c: Color) -> float:
	var r: float = _linearize(c.r)
	var g: float = _linearize(c.g)
	var b: float = _linearize(c.b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b

func _linearize(v: float) -> float:
	if v <= 0.03928:
		return v / 12.92
	return pow((v + 0.055) / 1.055, 2.4)

func _render_and_save(viewport: SubViewport, out_path: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var err: int = image.save_png(out_path)
	print("  save_png(%s) -> %d  (globalized: %s)" %
		[out_path, err, ProjectSettings.globalize_path(out_path)])
