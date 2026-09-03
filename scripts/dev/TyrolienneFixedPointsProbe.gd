extends Node

## RECON ONLY. Measures the hub for Mathieu's two FIXED tyrolienne points --
## relevé in-game via the position overlay -- rather than scanning for a
## site. Asserts NOTHING, gates NOTHING, changes NOTHING in the shipped
## tree; the only geometry it draws is parented under a rig this probe adds
## itself and never enters the layout.
##
## Points are DEFINITIVE, not to be optimised:
##   P1 (tower A) = (27.7,  9.2)
##   P2 (tower B) = (25.2, 35.0)
##
## ⚠️ MUST RUN UNDER xvfb WITH --rendering-driver opengl3, NEVER --headless.
## Same reason as ZiplineReconProbe: PHASE B/C project world points to
## screen through the real HubCamera and PHASE D reads pixels.

const _LABEL: String = "TyrolienneFixedPointsProbe"
const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"
const _OUT_DIR: String = "user://tyrolienne_fixed_recon"

const _SETTLE_FRAMES: int = 12

const _P1: Vector3 = Vector3(27.7, 0.0, 9.2)
const _P2: Vector3 = Vector3(25.2, 0.0, 35.0)

## A volume thinner than this is a floor/water slab, not an obstacle --
## same defect ZiplineReconProbe already found and fixed, reused verbatim.
const _OBSTACLE_MIN_HEIGHT: float = 0.20

## How much room a hanging rider needs below the cable line.
const _RIDER_DROP: float = 1.10

## Candidate structure radii to report clearance against. 0.0 is the raw
## point-to-obstacle distance; the rest are candidates a real tower footprint
## might take. 4.03 is the figure named in the brief -- carried through even
## though PHASE A below finds no such measurement anywhere in this repo, so
## the report can show exactly how much margin it would eat if it were real.
const _RADIUS_CANDIDATES: Array[float] = [0.0, 1.5, 1.932, 2.5, 3.5, 4.03]

## Platform-height deltas to render and measure readability at, per the brief.
const _HEIGHT_DELTAS: Array[float] = [1.0, 2.0, 3.0, 4.0, 6.0, 8.0]

var _hub: Node = null
var _world: Node3D = null
var _props: HubBuilder = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _viewport: SubViewport = null
var _rig: Node3D = null
var _silhouettes: Array = []
var _frames: int = 0


func _ready() -> void:
	ProbeWatchdog.arm(self, _LABEL)
	print("=== TYROLIENNE FIXED-POINTS RECON ===")
	print("P1 = (%.2f, %.2f)   P2 = (%.2f, %.2f)  -- FIXED, not to be moved" % [_P1.x, _P1.z, _P2.x, _P2.z])
	DirAccess.make_dir_recursive_absolute(_OUT_DIR)

	_hub = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(_hub)
	await get_tree().process_frame
	await get_tree().process_frame

	_world = _hub.find_child("World", true, false) as Node3D
	_props = _hub.find_child("Props", true, false) as HubBuilder
	_keepy = _hub.find_child("Keepy", true, false) as Node3D
	_camera = _hub.find_child("Camera3D", true, false) as Camera3D
	_viewport = _hub.find_child("SubViewport", true, false) as SubViewport
	if _world == null or _props == null or _keepy == null or _camera == null or _viewport == null:
		push_error("%s: hub scene did not give up World / Props / Keepy / Camera3D / SubViewport." % _LABEL)
		get_tree().quit(1)
		return
	if _viewport.size.x <= 0 or _viewport.size.y <= 0:
		push_error("%s: viewport is %dx%d -- running under the DUMMY driver. Use xvfb-run --rendering-driver opengl3."
			% [_LABEL, _viewport.size.x, _viewport.size.y])
		get_tree().quit(1)
		return

	var container := _hub.find_child("WorldViewport", true, false) as SubViewportContainer
	if container != null:
		container.stretch = false
		_viewport.size = Vector2i(1080, 1920)
		await get_tree().process_frame
		await get_tree().process_frame
	print("    captures taken at %dx%d (container stretch disabled for the probe)"
		% [_viewport.size.x, _viewport.size.y])

	_rig = Node3D.new()
	_rig.name = "TyrolienneFixedRig"
	_world.add_child(_rig)

	_phase_a_silhouettes()
	_phase_b_points()
	_phase_c_corridor()
	await _phase_d_captures()

	print("\n--- recon only: 0 assertion, 0 gate, nothing shipped ---")
	print("--- captures under %s ---" % ProjectSettings.globalize_path(_OUT_DIR))
	get_tree().quit(0)


# =====================================================================
# PHASE A -- silhouettes, identical method to ZiplineReconProbe
# =====================================================================

func _phase_a_silhouettes() -> void:
	print("\n[PHASE A] SILHOUETTES -- measured world AABBs off the BUILT tree")
	_collect(_props)
	_silhouettes.sort_custom(func(a, b): return a["top"] > b["top"])
	print("    %d drawn volumes measured (MultiMesh batches included)" % _silhouettes.size())
	# Confirm no "4.03" structure-radius figure exists anywhere in the built
	# silhouette table -- the brief names it as already measured; it is not.
	var max_diving_radius: float = 0.0
	for s in _silhouettes:
		if String(s["family"]).findn("DivingBoard") >= 0 or String(s["family"]).findn("Board") >= 0:
			max_diving_radius = maxf(max_diving_radius, float(s["radius"]))
	print("    max measured radius of any DivingBoard/Board-family volume in THIS built tree: %.3f u"
		% max_diving_radius)
	print("    (brief cites 4.03u as already measured on DivingBoard -- not found anywhere in this repo;")
	print("     see report. Treated below as an UNVERIFIED candidate, alongside the others.)")


func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			_record(_family_of(mi), mi.get_aabb(), mi.global_transform)
	elif node is MultiMeshInstance3D:
		var mm: MultiMeshInstance3D = node
		if mm.multimesh != null and mm.multimesh.mesh != null:
			var local: AABB = mm.multimesh.mesh.get_aabb()
			for i in mm.multimesh.instance_count:
				var xf: Transform3D = mm.global_transform * mm.multimesh.get_instance_transform(i)
				_record(mm.name, local, xf)
	for child in node.get_children():
		_collect(child)


func _family_of(node: Node) -> String:
	var here: Node = node
	var best: String = node.name
	while here != null and here != _props:
		if not String(here.name).begins_with("@"):
			best = String(here.name)
		here = here.get_parent()
	return best


func _record(who: String, local: AABB, xf: Transform3D) -> void:
	var world: AABB = xf * local
	var centre: Vector3 = world.get_center()
	_silhouettes.append({
		"family": who,
		"centre": Vector3(centre.x, 0.0, centre.z),
		"radius": maxf(world.size.x, world.size.z) * 0.5,
		"bottom": world.position.y,
		"top": world.position.y + world.size.y,
	})


# =====================================================================
# PHASE B -- the two fixed points, measured as they stand
# =====================================================================

func _phase_b_points() -> void:
	print("\n[PHASE B] THE TWO FIXED POINTS")
	var run: float = Vector2(_P2.x - _P1.x, _P2.z - _P1.z).length()
	var bearing: float = rad_to_deg(atan2(_P2.x - _P1.x, _P2.z - _P1.z))
	print("    distance P1->P2 = %.3f u   bearing = %.2f deg (0 = +Z)" % [run, bearing])
	print("    both points sit on the GROUND PLANE -- HubRegion/HubBuilder carry no terrain-height")
	print("    function anywhere in this repo (grepped); the plateau is flat, so altitude(P1) =")
	print("    altitude(P2) = 0.000 u, MEASURED as an absence rather than assumed.")

	for entry in [["P1", _P1], ["P2", _P2]]:
		var tag: String = entry[0]
		var p: Vector3 = entry[1]
		var inside: bool = HubRegion.contains(p)
		var ground: Array = _nearest_footprint(p)
		var hot: Array = _nearest_hotspot(p)
		var raw: Array = _nearest_silhouette(p)
		print("\n    --- %s = (%.2f, %.2f) ---" % [tag, p.x, p.z])
		print("      HubRegion.contains() = %s" % str(inside))
		print("      nearest existing ground footprint: %+7.3f u  (%s)" % [ground[0], ground[1]])
		print("      nearest existing tap/trigger hotspot: %+7.3f u  (%s)" % [hot[0], hot[1]])
		print("      nearest BUILT silhouette (point clearance, radius 0): %+7.3f u  (%s @ (%.2f, %.2f), top %.2f)"
			% [raw[0], raw[1], raw[2].x, raw[2].z, raw[3]])
		print("      net clearance by candidate tower structure radius:")
		for r in _RADIUS_CANDIDATES:
			var net: float = raw[0] - r
			var flag: String = "OK" if net >= 0.5 else ("TIGHT" if net >= 0.0 else "CONFLICT")
			print("        r=%.3f u  ->  net %+7.3f u   [%s]" % [r, net, flag])


func _nearest_silhouette(where: Vector3) -> Array:
	var best: float = INF
	var who: String = "-"
	var at: Vector3 = Vector3.ZERO
	var top: float = 0.0
	for s in _silhouettes:
		var centre: Vector3 = s["centre"]
		var d: float = Vector2(where.x - centre.x, where.z - centre.z).length() - float(s["radius"])
		if d < best:
			best = d
			who = s["family"]
			at = centre
			top = s["top"]
	return [best, who, at, top]


func _nearest_footprint(where: Vector3) -> Array:
	var best: float = INF
	var who: String = "-"
	for foot in _props.ground_footprints():
		var d: float = Vector2(where.x - foot["position"].x, where.z - foot["position"].z).length() \
			- float(foot["radius"])
		if d < best:
			best = d
			who = "r=%.2f @ (%.2f, %.2f)" % [foot["radius"], foot["position"].x, foot["position"].z]
	return [best, who]


func _nearest_hotspot(where: Vector3) -> Array:
	var discs: Array = []
	for owl in _props.owls():
		discs.append([owl["position"], HubWorld.OWL_TAP_RADIUS, "owl tap"])
	for cabin in _props.cabins():
		discs.append([cabin["door"], HubWorld.CABIN_TAP_RADIUS, "cabin doorstep"])
	for spin in _props.spinning_props():
		discs.append([spin["position"], float(spin["radius"]), "turnstile trigger"])
	for saw in _props.seesaws():
		discs.append([saw["position"], float(saw["radius"]), "seesaw trigger"])
	for board in _props.diving_boards():
		discs.append([board["ladder"], HubWorld.LADDER_TAP_RADIUS, "ladder tap"])
	for portal in _props.portals():
		discs.append([portal.global_position, 1.35, "portal"])
	var spine: Array = _props.stream_spine()
	if spine.size() >= 2:
		discs.append([spine[0], BoatMooring.BOARD_TAP_RADIUS, "boat tap (head)"])
		discs.append([spine[spine.size() - 1], BoatMooring.BOARD_TAP_RADIUS, "boat tap (tail)"])
	var best: float = INF
	var who: String = "-"
	for disc in discs:
		var at: Vector3 = disc[0]
		var d: float = Vector2(where.x - at.x, where.z - at.z).length() - float(disc[1])
		if d < best:
			best = d
			who = disc[2]
	return [best, who]


# =====================================================================
# PHASE C -- the corridor between the two fixed points
# =====================================================================

func _phase_c_corridor() -> void:
	print("\n[PHASE C] CORRIDOR P1 -> P2 -- BIDIRECTIONAL, so the cable is tested LEVEL")
	print("    (not sloped like a one-way descent -- both towers are the SAME structure, so")
	print("     the cable is tested at a CONSTANT height, once per candidate height delta)")
	for h in _HEIGHT_DELTAS:
		var worst := _cable_clearance_level(_P1, _P2, h)
		var flag: String = "OK" if worst["gap"] >= 0.8 else ("TIGHT" if worst["gap"] >= 0.0 else "CONFLICT")
		print("      H=%.1f u  ->  worst gap %+7.3f u at s=%.2f u against %s @ (%.2f, %.2f) (top %.2f)  [%s]"
			% [h, worst["gap"], worst["s"], worst["who"], worst["at"].x, worst["at"].z, worst["top"], flag])


## Same sampling method as ZiplineReconProbe._cable_clearance, but the cable
## height is CONSTANT (both ends are the same structure, so there is no
## deck/arrival split to interpolate between).
func _cable_clearance_level(from: Vector3, to: Vector3, height: float) -> Dictionary:
	var run: float = Vector2(to.x - from.x, to.z - from.z).length()
	var steps: int = maxi(int(run / 0.25), 8)
	var worst: float = INF
	var out: Dictionary = {"gap": INF, "s": 0.0, "who": "-", "top": 0.0, "at": Vector3.ZERO}
	var y: float = height - _RIDER_DROP
	for k in steps + 1:
		var t: float = float(k) / float(steps)
		var here: Vector3 = from.lerp(to, t)
		for s in _silhouettes:
			if s["top"] - s["bottom"] < _OBSTACLE_MIN_HEIGHT:
				continue
			if s["bottom"] > y or s["top"] < y:
				continue
			var gap: float = Vector2(here.x - s["centre"].x, here.z - s["centre"].z).length() - float(s["radius"])
			if gap < worst:
				worst = gap
				out = {"gap": gap, "s": t * run, "who": s["family"], "top": s["top"], "at": s["centre"]}
	return out


# =====================================================================
# PHASE D -- readability renders, per height delta, at both towers and
# from a north vantage that can hold the whole run in one frame.
# =====================================================================

func _phase_d_captures() -> void:
	print("\n[PHASE D] READABILITY CAPTURES")
	for h in _HEIGHT_DELTAS:
		_clear_rig()
		_draw_level_run(_P1, _P2, h, Color(1.0, 0.62, 0.12))
		var tag: String = "H%02d" % int(h)

		# North vantage: stand beyond the FARTHER point (max z) and look
		# toward -Z, the only direction this camera (never yaws) looks in --
		# the same convention ZiplineReconProbe's "run" shot uses. This is
		# the only station from which BOTH towers can appear in one frame,
		# because the corridor here runs almost due +Z (bearing -5.5 deg),
		# the opposite of the -Z-only visible field a single fixed camera
		# offers from anywhere south of it.
		var north_from: Vector3 = Vector3((_P1.x + _P2.x) * 0.5, 0.0, maxf(_P1.z, _P2.z) + 6.0)
		await _capture("%s__north_over_corridor" % tag, north_from)

		# Standing AT each tower, default camera pose: shows what that
		# station actually looks like to a player standing there, fog
		# included. Because the camera only sees -Z of wherever Keepy is,
		# standing at P1 (z=9.2) looking toward -Z faces AWAY from P2
		# (z=35.0, i.e. +Z of P1) -- so this shot is expected to show the
		# near tower/post only, not the far one. Published anyway: this is
		# exactly the "what does arriving at this station actually look
		# like" shot.
		await _capture("%s__at_P1" % tag, _P1)
		await _capture("%s__at_P2" % tag, _P2)

		print("    %s captured (north_over_corridor, at_P1, at_P2)" % tag)


func _draw_level_run(from: Vector3, to: Vector3, height: float, tint: Color) -> void:
	_post(Vector3(from.x, height * 0.5, from.z), height, 0.16, Color(0.42, 0.29, 0.17))
	_post(Vector3(to.x, height * 0.5, to.z), height, 0.16, Color(0.42, 0.29, 0.17))
	var a := Vector3(from.x, height, from.z)
	var b := Vector3(to.x, height, to.z)
	var span: Vector3 = b - a
	var cable := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.05
	mesh.height = span.length()
	mesh.radial_segments = 6
	mesh.rings = 0
	cable.mesh = mesh
	cable.material_override = _unshaded(tint)
	_rig.add_child(cable)
	cable.global_position = a + span * 0.5
	var up: Vector3 = span.normalized()
	var side: Vector3 = up.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	cable.global_transform.basis = Basis(side, up, side.cross(up).normalized())


func _post(centre: Vector3, height: float, radius: float, tint: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 0
	node.mesh = mesh
	node.material_override = _unshaded(tint)
	_rig.add_child(node)
	node.global_position = centre


func _unshaded(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	return mat


func _clear_rig() -> void:
	for child in _rig.get_children():
		child.queue_free()
		_rig.remove_child(child)


func _capture(tag: String, keepy_at: Vector3) -> void:
	_keepy.global_position = keepy_at
	_frames = 0
	while _frames < _SETTLE_FRAMES:
		await get_tree().process_frame
		_frames += 1
	var image: Image = _viewport.get_texture().get_image()
	image.save_png("%s/%s.png" % [_OUT_DIR, tag])
