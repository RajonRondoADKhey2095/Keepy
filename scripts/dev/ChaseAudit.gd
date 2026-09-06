extends Node
## CH30 -- WHAT THE HUB LOOKS LIKE FROM A CAMERA IT WAS NEVER BUILT FOR.
##
## =====================================================================
## WHY THIS IS THE RISK OF THE LOT
##
## This plateau was designed for ONE angle of view (HubCamera.OFFSET, a
## fixed 3/4 that never yaws and never approaches), and every correction
## CH22 and CH29 made -- the palms' framing, the parasol, the lighthouse
## beam, COVE_CAMERA_BAND -- was calibrated for it. A chase camera behind
## a sand yacht shows the same decor from azimuths nobody has ever
## looked from, and CLAUDE.md names, with measurements, three ways that
## goes wrong silently:
##
##   * A HAND-BUILT RIBBON WOUND THE WRONG WAY. Godot treats CLOCKWISE
##     faces as front faces. A ribbon wound anti-clockwise disappears
##     entirely under cull_back -- node present, AABB right, material
##     right, ZERO pixels, and no error of any kind. It has been paid for
##     three times in this repo, and it hides behind CULL_DISABLED until
##     the day a shader arrives.
##   * A visibility_range_end CALIBRATED FOR THE OLD FRAME. Pure CPU
##     culling with the fade disabled, set against a camera 11.7 u away
##     with a 45 deg horizontal fov. The drive camera is 7.6 u back with
##     a 60 deg fov and a 120 u far plane; anything culled inside that is
##     a pop, and a rider culled while its kart still draws is a headless
##     kart.
##   * DECOR THAT IS ONLY FINISHED ON THE SIDE THE FIXED CAMERA SEES.
##
## So this probe looks. It renders the drive pose at STATIONS across all
## five zones, at eight azimuths, under all four weathers, and it reports
## numbers a diff can compare: primitives on the `gpu` line (CLAUDE.md:
## the one a plafond gates on, never `scene`), the fraction of the frame
## that is sky, and the darkest and brightest samples. It also audits,
## statically, every hand-built surface's winding and every cull distance
## against the chase camera's reach.
##
## ⚠️ RUNS UNDER xvfb + --rendering-driver opengl3, NEVER --headless: the
## dummy driver renders black, reports the viewport 0x0, and would let
## every check below pass by never executing. The container rect is
## ASSERTED non-degenerate before anything is believed.
##
## Args after `--`: --out=DIR  --only=winding|cull|albedo|sweep|all  --shots

const STATIONS: Array[Dictionary] = [
	{"zone": "plateau", "at": Vector3(0.0, 0.0, 0.0)},
	# NOT (0, -60): the Mother Tree's trunk is at (0, -62) with a 2.7 u
	# hole, so a camera there is INSIDE the tree and every frame is bark.
	# 12 u west of it is in the clearing and looks at the whole hollow.
	{"zone": "hollow", "at": Vector3(-12.0, 0.0, -58.0)},
	{"zone": "moor", "at": Vector3(0.0, 0.0, -106.0)},
	{"zone": "circuit", "at": Vector3(0.0, 0.0, -142.0)},
	{"zone": "cove", "at": Vector3(56.0, 0.0, -110.0)},
]
const AZIMUTHS: int = 8
## The chase camera's reach: HubCamera.DRIVE_FAR is 120 u, but a thing is
## only READABLE while the fog has not eaten it. At CozyPalette's
## HAZE_DENSITY (0.022) a body keeps 20 % of itself at 73 u and 8 % at
## 115 u. 73 u is the honest line for "a player can still tell what that
## is", so anything culled nearer than that can pop where it will be seen.
const READABLE_U: float = 73.0

var _hub: Node = null
var _sub: SubViewport = null
var _camera: HubCamera = null
var _weather: CozyWeather = null
var _rig: Node3D = null
var _out_dir: String = "/tmp/chase"
var _only: String = "all"
var _shots: bool = false
var _failures: int = 0
var _checks: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "CHASE", 900.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg == "--shots":
			_shots = true
	WorldSave.SAVE_PATH_OVERRIDE = "user://chase_audit.json"
	WorldSave.reset()
	var packed: PackedScene = load("res://scenes/HubWorld.tscn")
	_hub = packed.instantiate()
	add_child(_hub)
	_sub = _hub.get_node("WorldViewport/SubViewport")
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	_weather = _hub.get_node("WorldViewport/SubViewport/World/CozyWeather")
	_run()

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s%s" % ["ok" if ok else "FAIL", label, ("  -- " + detail) if detail != "" else ""])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	await _frames(6)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	# ⚠️ THE RECT ASSERT. Under --headless this is 0x0 and every measure
	# below reads a surface that was never drawn.
	print("PHASE RECT")
	# ⚠️ A HEADLESS RUN OF THIS PROBE HAS NO VERDICT TO GIVE, and must say
	# so rather than reporting failures. --headless forces the DUMMY
	# driver, which renders black and reports 0x0 (CLAUDE.md, four
	# separate breakages), so every pixel measurement below would be a
	# false RED and the winding/cull phases a false green beside it. The
	# folder's convention for "no verdict" is ProbeWatchdog.EXIT_TIMEOUT,
	# and it is what a batch runner must see here.
	var headless: bool = DisplayServer.get_name() == "headless"
	var probe: Image = null if headless else _sub.get_texture().get_image()
	if headless or _sub.size.x <= 16 or _sub.size.y <= 16 or probe == null:
		print("  INCONCLUSIVE: no real rendering surface (display=%s, rect=%s)." % [DisplayServer.get_name(), str(_sub.size)])
		print("  Run this probe under: xvfb-run -a godot4 --rendering-driver opengl3 ...")
		print("CHASE AUDIT: INCONCLUSIVE")
		get_tree().quit(ProbeWatchdog.EXIT_TIMEOUT)
		return
	_check("the container rect is not degenerate", _sub.size.x > 16 and _sub.size.y > 16, str(_sub.size))
	_check("a frame was actually rendered (not the dummy driver's null)", probe != null)
	var mid: Color = probe.get_pixel(probe.get_width() / 2, probe.get_height() / 2)
	_check("the frame is not black (blind: the dummy driver renders black)",
		mid.r + mid.g + mid.b > 0.05, str(mid))
	if _only == "all" or _only == "winding":
		_phase_winding()
	if _only == "all" or _only == "cull":
		_phase_cull()
	if _only == "all" or _only == "albedo":
		_phase_albedo()
	if _only == "all" or _only == "sweep":
		await _phase_sweep()
	print("")
	print("CHASE AUDIT: %d checks, %d failures -> %s" % [_checks, _failures, "PASS" if _failures == 0 else "FAIL"])
	get_tree().quit(0 if _failures == 0 else 1)

## ---- PHASE WINDING ------------------------------------------------------
## Every surface built in CODE (an ArrayMesh with no resource path: a
## SurfaceTool ribbon, a hand-written index buffer) is checked for the
## enrolment CLAUDE.md documents. The sign is worth deriving in full,
## because getting it backwards is exactly as silent as the bug it looks
## for -- and the first version of this file DID get it backwards and
## called all eight of the hub's ribbons broken.
##
##   * For a triangle (a, b, c) the right-hand-rule normal is
##     n = (b - a) x (c - a). Seen from the side n points TOWARD, the
##     order a -> b -> c reads COUNTER-clockwise. That is the definition
##     of the cross product, not a convention.
##   * Godot's front face is the one from which the winding reads
##     CLOCKWISE. So the FRONT of a triangle is the side OPPOSITE n, and
##     the outward-facing normal of a front face is -n.
##   * A ground ribbon is meant to be seen FROM ABOVE. Its front normal
##     must therefore point up, i.e. -n.y > 0, i.e. **n.y < 0**.
##
## The historical anchor confirms it: CLAUDE.md records the stream ribbon
## disappearing under cull_back with "la normale du premier triangle
## (0, 1, 0) par la regle de la main droite" -- a POSITIVE n.y was the
## broken one, and StreamBank reads -1.000 today because that lot fixed
## it. Any hand-built ground ribbon that reads a positive n.y is wound
## the way the stream was before it vanished.
##
## Reported, not assumed: a wall, a sign or a lighthouse beam is not a
## ground ribbon, so only surfaces whose own AABB is flat in Y are gated,
## and every other hand-built surface is listed for the record.

func _phase_winding() -> void:
	print("\nPHASE WINDING")
	var world: Node = _hub.get_node("WorldViewport/SubViewport/World")
	var built: Array = []
	var flat_bad: Array = []
	var flat_total: int = 0
	for mi in _all_meshes(world):
		var mesh: Mesh = mi.mesh
		if mesh == null or mesh.resource_path != "":
			continue
		if not (mesh is ArrayMesh):
			continue
		for s in mesh.get_surface_count():
			var arrays: Array = (mesh as ArrayMesh).surface_get_arrays(s)
			if arrays.size() <= Mesh.ARRAY_INDEX:
				continue
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			if verts.size() < 3:
				continue
			var a: Vector3
			var b: Vector3
			var c: Vector3
			if idx != null and idx is PackedInt32Array and (idx as PackedInt32Array).size() >= 3:
				a = verts[idx[0]]
				b = verts[idx[1]]
				c = verts[idx[2]]
			else:
				a = verts[0]
				b = verts[1]
				c = verts[2]
			var n: Vector3 = (b - a).cross(c - a)
			if n.length() < 1e-9:
				continue
			n = n.normalized()
			var aabb: AABB = mesh.get_aabb()
			var is_ribbon: bool = aabb.size.y < 0.35 and aabb.size.x > 1.0 and aabb.size.z > 1.0
			var row := {"node": String(mi.get_path()).right(60), "surface": s, "n_y": snappedf(n.y, 0.001), "ribbon": is_ribbon}
			built.append(row)
			if is_ribbon:
				flat_total += 1
				# n.y > 0 == the front face looks DOWN == invisible from
				# above under cull_back. See the derivation above.
				if n.y > 0.0:
					flat_bad.append(row)
	print("    %d hand-built surfaces, %d of them flat ground ribbons" % [built.size(), flat_total])
	for row in built:
		print("      %-58s s%d  first-tri n.y = %+0.3f  %s" % [row["node"], row["surface"], row["n_y"], "RIBBON" if row["ribbon"] else ""])
	_check("(blind) the audit found ribbons to judge at all", flat_total > 0, str(flat_total))
	_check("every hand-built ground ribbon presents its FRONT face upward (first-tri n.y < 0)", flat_bad.is_empty(), str(flat_bad))
	# The historical anchor: the stream bank is the ribbon CLAUDE.md
	# records as having been wound the wrong way and fixed. If this probe
	# ever reads it as broken, the PREDICATE is broken, not the ribbon.
	var bank_ok: bool = false
	for row in built:
		if String(row["node"]).contains("StreamBank") and float(row["n_y"]) < 0.0:
			bank_ok = true
	_check("(anchor) the stream bank -- the ribbon this rule was written for -- reads as correct", bank_ok)

## ---- PHASE CULL ---------------------------------------------------------

func _phase_cull() -> void:
	print("\nPHASE CULL")
	var world: Node = _hub.get_node("WorldViewport/SubViewport/World")
	var buckets: Dictionary = {}
	var short_list: Array = []
	for mi in _all_meshes(world):
		var r: float = mi.visibility_range_end
		if r <= 0.0:
			continue
		var key: String = "%.0f" % r
		buckets[key] = int(buckets.get(key, 0)) + 1
		if r < READABLE_U:
			short_list.append({"node": String(mi.get_path()).right(70), "range": r})
	var keys: Array = buckets.keys()
	keys.sort()
	for k in keys:
		print("    visibility_range_end %6s u : %d meshes" % [k, buckets[k]])
	print("    %d meshes are culled INSIDE the chase camera's readable band (%.0f u)" % [short_list.size(), READABLE_U])
	var riders: int = 0
	for row in short_list:
		if String(row["node"]).contains("Rider"):
			riders += 1
	print("    of which %d are kart RIDERS" % riders)
	_check("(blind) the census found culled meshes at all", not buckets.is_empty(), str(buckets.size()))
	_check("no kart rider is culled inside the chase camera's readable band", riders == 0, "%d riders under %.0f u" % [riders, READABLE_U])

## ---- PHASE ALBEDO -------------------------------------------------------
## Everything in this hub is UNLIT and nothing post-processes the frame
## (CLAUDE.md), so the colour a .glb carries is literally the colour that
## reaches the screen, times whatever gain the renderer applies. A tree
## whose vertex colours are four times darker than every other tree in the
## same family is therefore not a lighting problem that a camera move
## could fix -- it is the asset, and it reads as a black silhouette the
## moment a camera comes close enough for the haze not to hide it.
##
## This phase reads the mean vertex colour of every decor tree actually
## used by the scatter, applies CozyPalette.FAMILY_GAIN, and gates the
## EFFECTIVE luminance against the hub ground's own rendered value: the
## ground is L = 0.0799, and a body at 0.15 is the point at which the two
## are distinguishable at all. It found the cypress at 0.069 -- BELOW the
## ground it stands on.

const TREES: Array[String] = ["cypress_0", "cypress_1", "olive_0", "tree_4_conifer", "bush_0", "palm_0"]
## The hub ground, MEASURED at the rendered frame (CLAUDE.md CH02): a body
## darker than this is darker than the floor.
const GROUND_L: float = 0.0799
const MIN_TREE_L: float = 0.15

func _phase_albedo() -> void:
	print("\nPHASE ALBEDO")
	var dark: Array = []
	var seen: int = 0
	for name in TREES:
		var mesh: Mesh = CozyPalette.glb_mesh(CozyPalette.decor_path(name))
		if mesh == null:
			continue
		var sum := Vector3.ZERO
		var n: int = 0
		for si in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(si)
			var cols = arr[Mesh.ARRAY_COLOR]
			if cols == null:
				continue
			for c in cols:
				sum += Vector3(c.r, c.g, c.b)
				n += 1
		if n == 0:
			continue
		seen += 1
		var m: Vector3 = sum / float(n)
		var raw: float = 0.2126 * m.x + 0.7152 * m.y + 0.0722 * m.z
		var gain: float = CozyPalette.family_gain(name)
		var eff: float = raw * gain
		print("    %-16s vertex lum %.4f  x gain %.2f  ->  %.4f   %s" % [name, raw, gain, eff,
			"BELOW THE GROUND (%.4f)" % GROUND_L if eff < GROUND_L else ""])
		if eff < MIN_TREE_L:
			dark.append("%s %.4f" % [name, eff])
	_check("(blind) the audit read a vertex colour off every tree it names", seen == TREES.size(), "%d/%d" % [seen, TREES.size()])
	_check("no decor tree renders darker than %.2f effective luminance" % MIN_TREE_L, dark.is_empty(), str(dark))

## ---- PHASE SWEEP --------------------------------------------------------

func _phase_sweep() -> void:
	print("\nPHASE SWEEP")
	_rig = Node3D.new()
	_rig.name = "ChaseRig"
	_hub.get_node("WorldViewport/SubViewport/World").add_child(_rig)
	_camera.enter_drive(_rig)
	_camera._blend = 1.0
	var worst_sky: float = 0.0
	var worst_where: String = ""
	var max_gpu: int = 0
	var max_gpu_where: String = ""
	var black_frames: int = 0
	var rows: Array = []
	for kind in [CozyWeather.Kind.SUN, CozyWeather.Kind.RAIN, CozyWeather.Kind.SNOW, CozyWeather.Kind.STORM]:
		_weather.force(kind)
		await _frames(6)
		for station in STATIONS:
			for a in AZIMUTHS:
				var yaw: float = TAU * float(a) / float(AZIMUTHS)
				_rig.global_position = station["at"]
				_rig.rotation.y = yaw
				_camera._drive_heading = yaw
				_camera._drive_position = _camera._drive_wanted()
				await _frames(3)
				var image: Image = _sub.get_texture().get_image()
				if image == null:
					continue
				var stats: Dictionary = _frame_stats(image)
				var gpu: int = RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
					RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
					RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
				var where: String = "%s/%s/%d" % [_weather_name(kind), station["zone"], int(round(rad_to_deg(yaw)))]
				rows.append({"where": where, "sky": stats["sky"], "gpu": gpu, "lum": stats["lum"]})
				if float(stats["sky"]) > worst_sky:
					worst_sky = float(stats["sky"])
					worst_where = where
				if gpu > max_gpu:
					max_gpu = gpu
					max_gpu_where = where
				if float(stats["lum"]) < 0.02:
					black_frames += 1
				if _shots and (a == 0 or a == 4):
					image.save_png("%s/%s_%s_%03d.png" % [_out_dir, _weather_name(kind), station["zone"], int(round(rad_to_deg(yaw)))])
	_weather.force(CozyWeather.Kind.SUN)
	print("    %d frames rendered (%d stations x %d azimuths x 4 weathers)" % [rows.size(), STATIONS.size(), AZIMUTHS])
	print("    worst empty frame: %.1f %% sky at %s" % [worst_sky * 100.0, worst_where])
	print("    heaviest frame:    gpu %d primitives at %s" % [max_gpu, max_gpu_where])
	for row in rows:
		print("      %-26s sky %5.1f %%   gpu %7d   lum %.3f" % [row["where"], float(row["sky"]) * 100.0, int(row["gpu"]), float(row["lum"])])
	_check("(blind) the sweep rendered every station", rows.size() == STATIONS.size() * AZIMUTHS * 4, str(rows.size()))
	_check("no frame is black", black_frames == 0, str(black_frames))
	_check("no azimuth shows an empty world (more than 97 % sky)", worst_sky <= 0.97, "%.1f %% at %s" % [worst_sky * 100.0, worst_where])
	_camera.exit_drive()

## The fraction of the frame that matches the sky sampled at the top
## centre (within a tolerance), and the mean luminance. A frame that is
## almost all sky at ground level is a hole in the world -- a ribbon that
## vanished, a wall only built on one side, a cull that fired too near.
func _frame_stats(image: Image) -> Dictionary:
	var w: int = image.get_width()
	var h: int = image.get_height()
	# ⚠️ THE SKY SAMPLE IS A MEDIAN OF THREE, not the top centre pixel.
	# MEASURED: at circuit/180 the camera sits a metre from the start
	# gantry's cream post, which fills the top CENTRE of the frame -- so
	# the first version sampled the POST as "the sky" and reported 58 % of
	# that frame empty. The world was fine; the yardstick was standing
	# against a wall. Three points across the top row, median by
	# luminance, and a post can only take one of them.
	var s0: Color = image.get_pixel(w / 8, 2)
	var s1: Color = image.get_pixel(w / 2, 2)
	var s2: Color = image.get_pixel(w - w / 8, 2)
	var trio: Array = [s0, s1, s2]
	trio.sort_custom(func(a: Color, b: Color) -> bool:
		return (0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b) < (0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b))
	var sky: Color = trio[1]
	var same: int = 0
	var total: int = 0
	var lum: float = 0.0
	var step: int = maxi(1, h / 220)
	for y in range(0, h, step):
		for x in range(0, w, step):
			var c: Color = image.get_pixel(x, y)
			total += 1
			lum += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			if absf(c.r - sky.r) < 0.02 and absf(c.g - sky.g) < 0.02 and absf(c.b - sky.b) < 0.02:
				same += 1
	return {"sky": float(same) / maxf(float(total), 1.0), "lum": lum / maxf(float(total), 1.0)}

func _weather_name(kind: int) -> String:
	match kind:
		CozyWeather.Kind.SUN: return "sun"
		CozyWeather.Kind.RAIN: return "rain"
		CozyWeather.Kind.SNOW: return "snow"
		CozyWeather.Kind.STORM: return "storm"
	return "?"

func _all_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out
