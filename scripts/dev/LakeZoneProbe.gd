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
## Landings counted for the CURRENT trip, and how many of them came
## down on great-lake water -- EITHER LOBE since SPAWN-LAKE-1, because the
## counter asks HubRegion.in_lake_water and that is now a loop over the
## table. Reset by _trip, read after it.
var _total_landings: int = 0
var _wet_landings: int = 0
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

	# The axis and the published azimuth are both derived from the cartesian
	# centre since LAKE-MOVE. Re-derived here from the degrees so the two
	# spellings can never silently disagree.
	var th: float = deg_to_rad(HubRegion.LAKE_AZIMUTH_DEG)
	var expected := Vector3(sin(th), 0.0, -cos(th))
	_check(HubRegion.lake_axis().distance_to(expected) < 1e-6,
		"axis matches azimuth %.3f deg -> %s" % [HubRegion.LAKE_AZIMUTH_DEG, HubRegion.lake_axis()])

	# THE CHECK THIS FILE WAS MISSING, and LAKE-MOVE is what made its
	# absence expensive: HubRegion holds the lake centre as constants and
	# hub_layout.tres holds it AGAIN as the greatlake entry's position. The
	# region and the drawn disc are two different objects built from two
	# different numbers, and nothing asserted they were the same number.
	# Move one and not the other and the water you can see stops being the
	# water you cannot walk into -- with no error anywhere.
	#
	# PLURAL SINCE SPAWN-LAKE-1. There are two great-lake lobes now, so the
	# check is a BIJECTION rather than one comparison: every layout entry
	# has to land on a distinct HubRegion lake, and every HubRegion lake has
	# to be claimed. Either half alone would pass while the other drifted --
	# a lobe drawn twice, or a subtracted hole nothing draws.
	var layout: HubLayout = load("res://resources/hub/hub_layout.tres") as HubLayout
	var stated: Array[Vector3] = []
	for entry in layout.props:
		if entry.get("type", &"") == &"greatlake":
			stated.append(entry.get("position", Vector3.INF) as Vector3)
	var claimed: Dictionary = {}
	var matched: bool = true
	for centre in stated:
		var index: int = HubRegion.lake_index_at(centre)
		if index < 0 or claimed.has(index):
			matched = false
		else:
			claimed[index] = centre
	_check(stated.size() == HubRegion.lakes().size() and matched
			and claimed.size() == HubRegion.lakes().size(),
		"the %d greatlake entries map one-to-one onto HubRegion's %d lakes: %s"
			% [stated.size(), HubRegion.lakes().size(), stated])
	# And the RADII, which the layout does not state at all: the builder
	# asks HubRegion for them, so this is the one place that says out loud
	# how big each drawn disc is.
	var radii: PackedFloat32Array = PackedFloat32Array()
	for lake in HubRegion.lakes():
		radii.append(float(lake["radius"]))
	print("    lakes: %s  radii %s" % [stated, radii])
	_check(absf(HubRegion.lake_centre().length() - HubRegion.LAKE_CENTRE_DISTANCE) < 1e-4,
		"lake centre at %.3f u -> %s" % [HubRegion.lake_centre().length(), HubRegion.lake_centre()])
	_check(absf(HubRegion.near_bank().length() - (HubRegion.LAKE_CENTRE_DISTANCE - HubRegion.LAKE_WATER_RADIUS)) < 1e-4,
		"near bank at %.3f u -> %s" % [HubRegion.near_bank().length(), HubRegion.near_bank()])

	_check(HubRegion.contains(Vector3.ZERO), "the plateau centre is walkable")
	_check(HubRegion.contains(Vector3(34.9, 0.0, 34.9)), "the square corner is walkable")
	_check(not HubRegion.contains(Vector3(40.0, 0.0, 40.0)), "past the square corner is not")
	var centres_dry: bool = true
	var rims_land: bool = true
	for lake in HubRegion.lakes():
		var centre: Vector3 = lake["centre"]
		var radius: float = lake["radius"]
		if HubRegion.contains(centre):
			centres_dry = false
		# Sampled all the way round: with two lobes a rim point can fall
		# inside the OTHER lobe, and only contains() is entitled to say so.
		#
		# ⚠️ SAMPLED AT radius + 0.001, NOT AT radius, and that is the same
		# nudge _out_of_lake() applies rather than a softened assertion.
		# in_lake_water compares STRICTLY against the radius, so a point
		# built as centre + dir*radius is a float coin-flip -- Vector3 is
		# float32, not float64. MEASURED, not argued: 7 of these 32 rim
		# points land 9.54e-07 INSIDE their own circle and read as water.
		# What the region actually promises is
		# that clamp_to's output is land, and clamp_to nudges -- so this
		# gates the promise instead of an unrepresentable edge case.
		for i in 16:
			var a: float = deg_to_rad(float(i) * 22.5)
			var rim := centre + Vector3(sin(a), 0.0, -cos(a)) * (radius + 0.001)
			if absf(rim.x) <= HubRegion.PLATEAU_HALF_EXTENT \
					and absf(rim.z) <= HubRegion.PLATEAU_HALF_EXTENT \
					and not HubRegion.contains(rim):
				rims_land = false
	_check(centres_dry, "the middle of every lobe is not walkable")
	_check(rims_land, "every lobe's waterline is walkable (the rim is land)")
	_check(HubRegion.contains(HubRegion.near_bank()), "the near bank waterline is (the rim is land)")

	# THE ASSERTION IS INVERTED SINCE LAKE-MOVE, deliberately and not
	# quietly. It used to demand that the shore pad add ground BEYOND the
	# square, because a pad that did not was decoration. With the lake now
	# INSIDE the square the pad is contained by arithmetic -- near bank
	# 8.520 out, pad radius 20, so the pad spans at most 28.520 from the
	# centre against a half-extent of 35 -- and the honest thing to gate is
	# that it really is contained, rather than to delete the check and
	# leave nobody watching. If a later batch pushes a lake back out
	# through an edge, THIS assertion is the one that will fail and say so.
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
	_check(beyond == 0,
		"the shore pad adds nothing past the square, as an interior lake implies (%d sampled points beyond, farthest %s)"
			% [beyond, farthest])
	_check(HubRegion.near_bank().length() + HubRegion.SHORE_PAD_RADIUS <= HubRegion.PLATEAU_HALF_EXTENT,
		"the pad is contained by arithmetic: %.3f + %.1f <= %.1f"
			% [HubRegion.near_bank().length(), HubRegion.SHORE_PAD_RADIUS, HubRegion.PLATEAU_HALF_EXTENT])

	# clamp_to must always answer with a point in the region, from anywhere
	# -- including from inside the water, which is the case the square
	# clamp could not express at all.
	var probes: Array[Vector3] = [
		HubRegion.lake_centre(),
		HubRegion.lake_centre() + Vector3(5.0, 0.0, -3.0),
		Vector3(HubRegion.SPAWN_LAKE_CENTRE_X, 0.0, HubRegion.SPAWN_LAKE_CENTRE_Z),
		Vector3(HubRegion.SPAWN_LAKE_CENTRE_X + 4.0, 0.0, HubRegion.SPAWN_LAKE_CENTRE_Z + 2.0),
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
	#
	# ⚠️ IDENTIFIED BY POSITION, NOT BY COLOUR, since SPAWN-LAKE-1 made every
	# water body share one albedo: the four bodies now differ only in ALPHA,
	# and the two great-lake lobes not even in that. A colour match would
	# silently collapse them into one reading. The layout's own centres are
	# the key instead, which is also the only key that cannot go stale
	# without the bijection check above failing first.
	var tops: Dictionary = {}
	var great_tops: PackedFloat32Array = PackedFloat32Array()
	for node in props.get_children():
		var root := node as Node3D
		if root == null:
			continue
		var top: float = -INF
		var found: bool = false
		for child in root.get_children():
			var mi := child as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var mat := mi.get_surface_override_material(0) as StandardMaterial3D
			if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
				continue
			top = maxf(top, (mi.global_transform * mi.mesh.get_aabb()).end.y)
			found = true
		if not found:
			continue
		var flat := Vector3(root.global_position.x, 0.0, root.global_position.z)
		if HubRegion.lake_index_at(flat) >= 0:
			great_tops.append(top)
		elif flat.distance_to(Vector3(-25.10, 0.0, -5.30)) < 0.01:
			tops["small water"] = top
	for node in _descendants(props):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mat := mi.get_surface_override_material(0) as StandardMaterial3D
		if mat != null and mat.albedo_color.is_equal_approx(HubBuilder.ISLET_COLOR):
			tops["islet"] = (mi.global_transform * mi.mesh.get_aabb()).end.y
	var ordered: bool = great_tops.size() == HubRegion.lakes().size() \
		and tops.has("islet") and tops.has("small water")
	if ordered:
		for t in great_tops:
			if t >= tops["islet"]:
				ordered = false
		ordered = ordered and tops["islet"] < tops["small water"]
		print("    tops: great-lake lobes %s < islet %.4f < small water %.4f"
			% [great_tops, tops["islet"], tops["small water"]])
	_check(ordered, "every great-lake lobe sits under the islets, and both under the small lake")

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
	# EIGHT AZIMUTHS, not three, and that is what LAKE-MOVE asked for: the
	# lake used to be a hole at the EDGE of the region and is now a hole in
	# the MIDDLE of it, so a tap on it can be pushed out in any direction
	# rather than always shorewards. Sampling one ring of eight is what
	# turns "clamp_to reads like it handles an interior hole" into a
	# measurement.
	var keepy: Node3D = camera.get_parent().get_node("Keepy") as Node3D
	# EIGHT AZIMUTHS PER LOBE since SPAWN-LAKE-1. The second lobe is not
	# covered for free by the first: clamp_to now offers a candidate per
	# lake and picks between them, so the branch that matters is the one
	# where pushing out of one lobe could land inside the other.
	var water_points: Array[Vector3] = []
	for lake in HubRegion.lakes():
		for i in 8:
			var a: float = deg_to_rad(float(i) * 45.0)
			water_points.append((lake["centre"] as Vector3)
				+ Vector3(sin(a), 0.0, -cos(a)) * (float(lake["radius"]) * 0.6))
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
	_check(tested >= water_points.size(),
		"all %d sampled lake points projected inside the viewport (%d tested)"
			% [water_points.size(), tested])
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

	# THERE IS NO LOBE TO TIME ANY MORE. The pad is contained (PHASE
	# REGION gates that), so the region is exactly the square minus an
	# interior disc and every walkable point is a square point. What is
	# worth timing instead is a trip whose straight chord runs THROUGH the
	# water, because that is the shape of trip an interior lake creates and
	# the one whose cost the recon predicted would not change: a lake
	# cannot bend a chord, so it cannot add a second.
	var through: float = 0.0
	var through_label: String = ""
	for pair in [
		[Vector3(-h, 0.0, h), Vector3(h, 0.0, -h)],
		[Vector3(0.0, 0.0, h), Vector3(h * 0.6, 0.0, -h)],
		[Vector3(-h, 0.0, 0.0), Vector3(h, 0.0, -h * 0.8)],
	]:
		var t: float = await _trip(keepy, "across the lake %s -> %s" % [pair[0], pair[1]], pair[0], pair[1])
		if t > through:
			through = t
			through_label = "%s -> %s" % [pair[0], pair[1]]

	print("    worst lake-crossing trip %.3f s (%s)" % [through, through_label])
	_check(diagonal < _CROSSING_BUDGET_S, "the square diagonal stays under the %.0f s budget" % _CROSSING_BUDGET_S)
	_check(through < _CROSSING_BUDGET_S, "the worst lake-crossing trip stays under the %.0f s budget" % _CROSSING_BUDGET_S)
	var worst: float = through
	_check(worst <= diagonal, "the square diagonal is still the hub's worst crossing")

	# THE THREE MARCHES A PLAYER ACTUALLY MAKES. Every session starts at
	# the plateau centre and walks to one of three portals, so these are
	# the only trips certain to happen -- and an interior lake is exactly
	# the change that could put one of them in the water. Gated, not
	# reported: a portal you cannot reach dry is a broken hub.
	var portal_targets: Dictionary = {
		"chased": Vector3(-5.4, 0.0, -4.6),
		"quizz": Vector3(0.0, 0.0, -7.2),
		"battle": Vector3(5.4, 0.0, -4.6),
	}
	var dry_marches: int = 0
	for name in portal_targets:
		var target: Vector3 = portal_targets[name]
		var t: float = await _trip(keepy, "centre -> %s portal" % name, Vector3.ZERO, target)
		print("    centre -> %s: %.3f s, %d landings, %d in water"
			% [name, t, _total_landings, _wet_landings])
		if _wet_landings == 0:
			dry_marches += 1
	_check(dry_marches == 3, "%d/3 marches from the plateau centre to a portal stay dry" % dry_marches)

	# WALKING ON WATER, REPORTED AND NOT GATED. Keepy's chord consults
	# nothing -- there is no obstacle avoidance anywhere in the repo -- so
	# these landings are a real, known defect that this batch makes WORSE
	# and deliberately does not fix. The count covers BOTH lobes since
	# SPAWN-LAKE-1, so a row that was 0 before can be non-zero now without
	# the great lake having moved a millimetre. Gating it would fail the hub for a
	# decision taken elsewhere; leaving it unmeasured would let the cost of
	# an interior lake go unsaid.
	for pair in [
		[Vector3(-h, 0.0, -h), Vector3(h, 0.0, h)],
		[Vector3(-h, 0.0, h), Vector3(h, 0.0, -h)],
		[Vector3.ZERO, Vector3(h, 0.0, -h)],
	]:
		var t: float = await _trip(keepy, "wet-count %s -> %s" % [pair[0], pair[1]], pair[0], pair[1])
		print("    %s -> %s: %d landings, %d on great-lake water (%.3f s)"
			% [pair[0], pair[1], _total_landings, _wet_landings, t])

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
	_total_landings = 0
	_wet_landings = 0
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

func _on_hop_landed(pos: Vector3) -> void:
	_hop_count += 1
	_total_landings += 1
	if HubRegion.in_lake_water(pos):
		_wet_landings += 1

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
