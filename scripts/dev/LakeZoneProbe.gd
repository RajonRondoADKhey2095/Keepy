extends Node
## Dev-only: gates the lake zone -- its walkable region, its crossing cost,
## and the height stack its geometry depends on.
##
## =====================================================================
## WHAT THIS EXISTS TO CATCH
##
## The lake zone turned the walkable hub from a scalar into a shape, and a
## shape fails in ways a float cannot. Three of those are silent:
##
##   - a tap on the lake walks Keepy into the water. No error; the player
##     simply ends up standing in a lake.
##   - the shore lobe quietly becomes the longest walk in the game, so the
##     22 s crossing budget is spent somewhere nobody looked.
##   - two water slabs land at the same height and z-fight. The great lake
##     and the small lake DO overlap -- forced by their fixed radii, not
##     chosen -- so the only thing keeping them apart is an ordering of
##     y values that a later edit could flatten without noticing.
##
## =====================================================================
## THIS PROBE MUST RUN UNDER xvfb, NOT --headless
##
## PHASE TAP drives the SHIPPED HubTapInput._handle_point, which projects
## a world point to a screen point and needs a real SubViewportContainer
## rect. Under the dummy driver that rect is 0x0 and the function returns
## before it projects anything -- a green that means nothing. The rect is
## therefore ASSERTED to be non-degenerate, so this probe fails loudly
## under --headless instead of passing for free. Same trap the boat ride's
## probe already pays, on the same screen.
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
##       --path . res://scripts/dev/LakeZoneProbe.tscn

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"
const _LAYOUT_PATH: String = "res://resources/hub/hub_layout.tres"

## The frame rate the hop chain is quantised against; matches the
## --fixed-fps 60 every timed probe here is invoked with. A 0.28 s hop
## occupies 17 frames, so a chain costs ~1.19% more than the nominal
## multiplication -- the frame count is what a stopwatch agrees with.
const _FPS: float = 60.0

## The project's standing crossing budget, and the property this batch was
## asked to preserve on top of it.
const _CROSSING_BUDGET_S: float = 22.0

var _failures: int = 0
var _hop_count: int = 0
var _hop_done: bool = false
var _tapped: Vector3 = Vector3.INF
var _tap_seen: bool = false

func _ready() -> void:
	# Armed before anything that could itself hang. arm() covers the
	# frame-driven phases; deadline() covers the blocking ones, where no
	# frame exists for an armed watchdog to run in.
	ProbeWatchdog.arm(self, "LAKE ZONE PROBE")
	var dl := ProbeWatchdog.deadline("LAKE ZONE PROBE")

	print("=== LAKE ZONE PROBE ===")
	print("")

	_phase_region()
	dl.abort_if_exceeded()

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = hub.get_node("WorldViewport/SubViewport/World") as Node3D
	var keepy: KeepyHopper = world.get_node("Keepy") as KeepyHopper
	var camera: Camera3D = world.get_node("Camera3D") as Camera3D
	var ground: MeshInstance3D = world.get_node("Ground") as MeshInstance3D
	var props: Node3D = world.get_node("Props") as Node3D
	var tap: HubTapInput = hub.get_node("TapInput") as HubTapInput

	_phase_geometry(props, ground)
	await _phase_tap(hub, tap, camera)
	await _phase_crossing(keepy)

	print("")
	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("    OK   %s" % label)
	else:
		_failures += 1
		print("    FAIL %s" % label)

## =====================================================================
## PHASE REGION -- the shape, on its own, with no scene attached.
func _phase_region() -> void:
	print("--- PHASE REGION: HubRegion shape ---")

	# The axis is a static var derived from the azimuth. Re-derived here so
	# a hand-edited component can never silently disagree with the degrees
	# the rest of the file documents.
	var th: float = deg_to_rad(HubRegion.LAKE_AZIMUTH_DEG)
	var expected := Vector3(sin(th), 0.0, -cos(th))
	_check(HubRegion.lake_axis().distance_to(expected) < 1e-6,
		"axis matches azimuth %.1f deg -> %s" % [HubRegion.LAKE_AZIMUTH_DEG, HubRegion.lake_axis()])
	_check(absf(HubRegion.lake_centre().length() - HubRegion.LAKE_CENTRE_DISTANCE) < 1e-4,
		"lake centre at %.3f u -> %s" % [HubRegion.lake_centre().length(), HubRegion.lake_centre()])
	_check(absf(HubRegion.near_bank().length() - (HubRegion.LAKE_CENTRE_DISTANCE - HubRegion.LAKE_WATER_RADIUS)) < 1e-4,
		"near bank at %.3f u -> %s" % [HubRegion.near_bank().length(), HubRegion.near_bank()])

	_check(HubRegion.contains(Vector3.ZERO), "the plateau centre is walkable")
	_check(HubRegion.contains(Vector3(34.9, 0.0, 34.9)), "the square corner is walkable")
	_check(not HubRegion.contains(Vector3(40.0, 0.0, 40.0)), "past the square corner is not")
	_check(not HubRegion.contains(HubRegion.lake_centre()), "the middle of the lake is not")
	_check(HubRegion.contains(HubRegion.near_bank()), "the near bank waterline is (the rim is land)")

	# The lobe has to add ground BEYOND the square, or the pad is
	# decoration. Scanned rather than aimed at a point picked by hand: the
	# first version of this assertion failed because the point I chose was
	# still inside the square, which says the guess was wrong, not the
	# region -- and a scan cannot make that mistake.
	var beyond: int = 0
	var farthest := Vector3.ZERO
	for i in 1441:
		var a: float = deg_to_rad(float(i) * 0.25)
		for step in range(1, 220):
			var p := Vector3(cos(a) * float(step) * 0.5, 0.0, sin(a) * float(step) * 0.5)
			if not HubRegion.contains(p):
				continue
			if absf(p.x) > HubRegion.PLATEAU_HALF_EXTENT or absf(p.z) > HubRegion.PLATEAU_HALF_EXTENT:
				beyond += 1
				if p.length() > farthest.length():
					farthest = p
	_check(beyond > 0, "the shore lobe reaches past the square (%d sampled points, farthest %s)"
		% [beyond, farthest])

	# clamp_to must always answer with a point in the region, from anywhere
	# -- including from inside the water, which is the case the square
	# clamp could not express at all.
	var probes: Array[Vector3] = [
		HubRegion.lake_centre(),
		HubRegion.lake_centre() + Vector3(5.0, 0.0, -3.0),
		Vector3(-300.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 900.0),
		Vector3(-45.0, 0.0, -45.0),
		Vector3(12.0, 0.0, 7.0),
	]
	var all_in: bool = true
	var idempotent: bool = true
	for p in probes:
		var c := HubRegion.clamp_to(p)
		if not HubRegion.contains(c):
			all_in = false
		if HubRegion.clamp_to(c).distance_to(c) > 1e-5:
			idempotent = false
	_check(all_in, "clamp_to lands inside the region from all %d probes" % probes.size())
	_check(idempotent, "clamp_to is idempotent")
	print("")

## =====================================================================
## PHASE GEOMETRY -- what the builder actually put in the scene.
func _phase_geometry(props: Node3D, ground: MeshInstance3D) -> void:
	print("--- PHASE GEOMETRY: built scene ---")

	var draws: int = 0
	var multis: int = 0
	var portal_meshes: int = 0
	for node in _descendants(props):
		if node is MultiMeshInstance3D:
			multis += 1
			draws += 1
		elif node is MeshInstance3D:
			draws += 1
			if _under_portal(node):
				portal_meshes += 1
	print("    draw nodes in Props: %d (of which %d MultiMesh, %d inside portals)"
		% [draws, multis, portal_meshes])
	print("    draw nodes excluding portals: %d" % (draws - portal_meshes))
	_check(draws - portal_meshes <= 260, "draw nodes excluding portals stay under the 260 ceiling")

	# Every MultiMesh must be TRANSFORM_3D. The 4.3 default is TRANSFORM_2D,
	# which throws away every transform written to it and draws the whole
	# batch at the origin -- with no error to say so.
	var all_3d: bool = true
	for node in _descendants(props):
		var mm := node as MultiMeshInstance3D
		if mm != null and mm.multimesh != null and mm.multimesh.transform_format != MultiMesh.TRANSFORM_3D:
			all_3d = false
	_check(all_3d, "every MultiMesh is TRANSFORM_3D")

	# The height stack. Ordering, not exact values: what matters is that
	# nothing shares a plane with anything it overlaps.
	var tops: Dictionary = {}
	for node in _descendants(props):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var top: float = (mi.global_transform * mi.mesh.get_aabb()).end.y
		var colour: Color = Color.BLACK
		var mat := mi.get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			colour = mat.albedo_color
		if colour.is_equal_approx(HubBuilder.GREATLAKE_WATER_COLOR):
			tops["great water"] = top
		elif colour.is_equal_approx(HubBuilder.ISLET_COLOR):
			tops["islet"] = top
		elif colour.is_equal_approx(HubBuilder.LAKE_WATER_COLOR):
			tops["small water"] = top
	var ordered: bool = tops.has("great water") and tops.has("islet") and tops.has("small water")
	if ordered:
		ordered = tops["great water"] < tops["islet"] and tops["islet"] < tops["small water"]
		print("    tops: great water %.4f < islet %.4f < small water %.4f"
			% [tops["great water"], tops["islet"], tops["small water"]])
	_check(ordered, "great water sits under the islets, and both under the small lake")

	# Nothing reachable may leave the ground mesh. The half-size is READ
	# from the scene, never assumed.
	var plane := ground.mesh as PlaneMesh
	var half: float = minf(plane.size.x, plane.size.y) * 0.5 * minf(ground.scale.x, ground.scale.z)
	var reach: float = 0.0
	for i in 721:
		var a: float = deg_to_rad(float(i) * 0.5)
		for r in range(1, 200):
			var p := Vector3(cos(a) * float(r) * 0.5, 0.0, sin(a) * float(r) * 0.5)
			if HubRegion.contains(p):
				reach = maxf(reach, maxf(absf(p.x), absf(p.z)))
	print("    worst reachable |axis| = %.2f against a ground half-size of %.1f" % [reach, half])
	_check(reach < half, "no reachable point leaves the ground mesh")
	print("")

## =====================================================================
## PHASE TAP -- the shipped tap path, on a real window.
func _phase_tap(hub: Node, tap: HubTapInput, camera: Camera3D) -> void:
	print("--- PHASE TAP: shipped HubTapInput, real window ---")
	var container := hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	print("    container rect = %s" % rect)
	# The whole phase is worthless on a 0x0 rect -- see the docblock.
	_check(rect.size.x > 1.0 and rect.size.y > 1.0,
		"the viewport container has a real rect (run under xvfb, not --headless)")
	if rect.size.x <= 1.0:
		print("")
		return

	tap.tapped_ground.connect(_on_tapped)
	# Keepy is MOVED to the shore for this, and the camera snapped to
	# where it would settle. The camera has a FIXED rotation looking -Z,
	# so the lake is only ever on screen when the player is standing south
	# of it -- aiming at the lake from the plateau centre projects every
	# water point off-screen, which is what the first run of this phase
	# measured (0 of 3 tested) rather than a fault in the tap path.
	var keepy: Node3D = camera.get_parent().get_node("Keepy") as Node3D
	var side := HubRegion.lake_axis().cross(Vector3.UP).normalized()
	var water_points: Array[Vector3] = [
		HubRegion.near_bank() + HubRegion.lake_axis() * 4.0,
		HubRegion.near_bank() + HubRegion.lake_axis() * 7.0 + side * 5.0,
		HubRegion.near_bank() + HubRegion.lake_axis() * 6.0 - side * 4.0,
	]
	var tested: int = 0
	var dry: int = 0
	for target in water_points:
		# Stand 12 units south of the water point; that puts it in frame.
		var stand := HubRegion.clamp_to(target + Vector3(0.0, 0.0, 12.0))
		keepy.global_position = Vector3(stand.x, 0.0, stand.z)
		camera.global_position = Vector3(stand.x, 0.0, stand.z) + HubCamera.OFFSET
		await get_tree().process_frame
		var screen: Vector2 = _to_screen(container, camera, target)
		if not rect.has_point(screen):
			print("    aimed at %s from %s -> off screen at %s, skipped" % [target, stand, screen])
			continue
		tested += 1
		_tap_seen = false
		tap._handle_point(screen)
		await get_tree().process_frame
		if _tap_seen and not HubRegion.in_lake_water(_tapped):
			dry += 1
		print("    tap aimed at %s -> destination %s (in water: %s)"
			% [target, _tapped, HubRegion.in_lake_water(_tapped)])
	tap.tapped_ground.disconnect(_on_tapped)
	_check(tested > 0, "at least one lake point projected inside the viewport (%d tested)" % tested)
	_check(tested > 0 and dry == tested, "%d/%d taps on the lake resolved to dry land" % [dry, tested])
	print("")

func _on_tapped(point: Vector3) -> void:
	_tapped = point
	_tap_seen = true

## World point -> screen point, in the container's own space, inverting
## exactly what _handle_point does on the way in.
func _to_screen(container: SubViewportContainer, camera: Camera3D, world: Vector3) -> Vector2:
	var rect := container.get_global_rect()
	var viewport := camera.get_viewport() as SubViewport
	var local: Vector2 = camera.unproject_position(world)
	local.x *= rect.size.x / float(viewport.size.x)
	local.y *= rect.size.y / float(viewport.size.y)
	return local + rect.position

## =====================================================================
## PHASE CROSSING -- the real hopper, real frames.
func _phase_crossing(keepy: KeepyHopper) -> void:
	print("--- PHASE CROSSING: shipped KeepyHopper at --fixed-fps 60 ---")
	var h: float = HubRegion.PLATEAU_HALF_EXTENT

	# Reproduce the published diagonal FIRST. A bench that cannot restate a
	# number already in the record has no standing to report a new one.
	var diagonal: float = await _trip(keepy, "square diagonal (published 66 hops / 18.700 s)",
		Vector3(-h, 0.0, -h), Vector3(h, 0.0, h))

	# The lobe's real extremes, SCANNED out of the region rather than
	# written down. The first version of this phase aimed at a point picked
	# by hand (near_bank +- side * (pad - 1)) and timed 16.717 s against
	# it -- but that point is inside the square, so it was timing the
	# plateau and calling it the lobe. A scan cannot make that mistake.
	var side := HubRegion.lake_axis().cross(Vector3.UP).normalized()
	var left := Vector3.ZERO
	var right := Vector3.ZERO
	for i in 1441:
		var a: float = deg_to_rad(float(i) * 0.25)
		for step in range(1, 240):
			var p := Vector3(cos(a) * float(step) * 0.5, 0.0, sin(a) * float(step) * 0.5)
			if not HubRegion.contains(p):
				continue
			if absf(p.x) <= HubRegion.PLATEAU_HALF_EXTENT and absf(p.z) <= HubRegion.PLATEAU_HALF_EXTENT:
				continue
			if p.dot(side) >= 0.0:
				if p.length() > left.length():
					left = p
			elif p.length() > right.length():
				right = p
	_check(left.length() > 0.0 and right.length() > 0.0,
		"the lobe reaches past the square on BOTH sides of the axis: %s / %s" % [left, right])

	var worst: float = 0.0
	var worst_label: String = ""
	for target in [left, right]:
		for corner in [Vector3(h, 0.0, h), Vector3(h, 0.0, -h), Vector3(-h, 0.0, h)]:
			var t: float = await _trip(keepy, "corner %s -> shore lobe %s" % [corner, target], corner, target)
			if t > worst:
				worst = t
				worst_label = "%s -> %s" % [corner, target]

	print("    worst lobe crossing %.3f s (%s)" % [worst, worst_label])
	_check(diagonal < _CROSSING_BUDGET_S, "the square diagonal stays under the %.0f s budget" % _CROSSING_BUDGET_S)
	_check(worst < _CROSSING_BUDGET_S, "the worst lobe crossing stays under the %.0f s budget" % _CROSSING_BUDGET_S)
	_check(worst <= diagonal, "the square diagonal is still the hub's worst crossing")

func _trip(keepy: KeepyHopper, label: String, start: Vector3, target: Vector3) -> float:
	# WAIT FOR IDLE FIRST, and this is not belt-and-braces. PHASE TAP fires
	# the real tapped_ground signal, which HubWorld answers with a real
	# hop_to() -- so Keepy is genuinely mid-journey when this phase starts.
	# Writing global_position under a live tween does nothing (_apply_hop
	# overwrites it every frame) and hop_to() only auto-advances from IDLE,
	# so without this the first trip measures the tail of the tap chain:
	# the run that caught it reported the square diagonal as 54 hops /
	# 15.200 s against a published 66 / 18.700.
	var settle: int = 0
	while keepy.is_hopping() and settle < 5000:
		await get_tree().process_frame
		settle += 1
	keepy.global_position = Vector3(start.x, 0.0, start.z)
	await get_tree().process_frame
	_hop_count = 0
	_hop_done = false
	keepy.hop_landed.connect(_on_hop_landed)
	keepy.became_idle.connect(_on_hop_idle)
	keepy.hop_to(target)
	var frames: int = 0
	while not _hop_done and frames < 5000:
		await get_tree().process_frame
		frames += 1
	keepy.hop_landed.disconnect(_on_hop_landed)
	keepy.became_idle.disconnect(_on_hop_idle)
	var seconds: float = float(frames) / _FPS
	print("    %-52s hops=%3d frames=%4d  %.3f s%s"
		% [label, _hop_count, frames, seconds, "" if _hop_done else "  ** FRAME CAP **"])
	return seconds

func _on_hop_landed(_pos: Vector3) -> void:
	_hop_count += 1

func _on_hop_idle() -> void:
	_hop_done = true

## =====================================================================
func _descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			out.append(child)
			stack.append(child)
	return out

func _under_portal(node: Node) -> bool:
	var walk: Node = node
	while walk != null:
		if walk is HubPortal:
			return true
		walk = walk.get_parent()
	return false
