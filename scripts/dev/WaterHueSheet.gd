extends Node
## Dev-only: a RENDER SHEET of candidate colour families for the hub's four
## bodies of water (pond, stream, lake, great lake).
##
## =====================================================================
## WHAT THIS FILE IS AND IS NOT
##
## It CHOOSES NOTHING and asserts nothing. It renders the shipped hub with
## each candidate family applied, measures what each water body actually
## draws as, and prints the numbers a human needs in order to pick. The
## shipped colours in HubBuilder.gd are NOT touched by this batch: the
## candidates live here, in the sheet, exactly so that judging one costs a
## render and not a commit.
##
## Same standing as EnemyEarthtoneAxisSheet / ChargerEarthtoneAxisSheet
## before it: a recon sheet, kept so the plate can be reproduced instead of
## being an anecdote from one session. scripts/dev/* is in
## export_presets.cfg's exclude_filter, so keeping it costs the build zero.
##
## =====================================================================
## WHY THE BODIES ARE MASKED AND NOT SAMPLED IN A BOX
##
## Every earlier recolour in this project measured a hazard through a fixed
## sample window and read the histogram-dominant colour out of it. That
## works on a flat unlit hazard that fills its window with one value; it is
## WRONG here, twice over:
##
##   * the water is ALPHA-BLENDED (0.55) over its own bank, so a window that
##     strays past the rim reads bank, not water;
##   * the stream is a 1.2-unit ribbon seen at an angle, so no fixed box
##     is ever all-object.
##
## So each body is masked instead. One extra ID pass per view renders the
## target body opaque white with fog off, everything else black; a pixel is
## that body's iff it comes back exactly 255,255,255. The measurement then
## runs on those pixels only, and the "share" column below is the proof the
## mask is clean rather than a claim that it is.
##
## =====================================================================
## WHY IT MUST RUN UNDER xvfb AND NOT --headless
##
## --headless forces the DUMMY rendering driver, which returns an empty
## surface from get_image(): every sample reads (0,0,0), every ratio comes
## out 1.00:1, and the probe still exits 0. That is the exact false green
## this repo has already paid for once. Run it as:
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --path . \
##       res://scripts/dev/WaterHueSheet.tscn -- --out=/abs/dir
##
## The rendered frames are written to --out (default user://) as raw PNGs;
## composing them into the annotated plate is a separate, non-Godot step.

const HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

## Half the shipped 1080x1920. The RATIO is what fixes the framing (the
## camera is keep_aspect KEEP_WIDTH, so the horizontal fov is fixed and the
## vertical one follows the aspect); the pixel count only fixes how big the
## plate is. Half-size keeps three views per row readable and keeps the
## llvmpipe software renderer in this sandbox from taking minutes a frame.
const VIEW_SIZE: Vector2i = Vector2i(540, 960)

## Frames to let settle before a capture. The camera and the hopper are both
## frozen by then, so this is only the render target catching up.
const SETTLE_FRAMES: int = 4

## ⚠️ STALE, AND IT WAS STALE BEFORE SPAWN-LAKE-1 -- measured on
## origin/staging, not inferred: this table still holds the PRE-WATER-HUE-2
## colours, so `_build()` already failed with "no mesh found for water body
## 'pond'" and quit(1) on the shipped tree. SPAWN-LAKE-1 makes it
## unfixable by colour at all: every body now shares one albedo, so nothing
## here could ever tell them apart again. A future run of this sheet has to
## key on the layout CENTRE instead -- WaterAlphaSweep.gd already does, and
## its BODIES table is the shape to copy. Left as it is rather than
## half-repaired inside an unrelated batch; it gates nothing.
##
## The four water constants as HubBuilder.gd ships them, used ONLY to work
## out which MeshInstance3D is which. Matching on the material colour rather
## than on a node name or index is what StreamGeometryProbe already does,
## and for the same reason: the layout file decides how many props come
## before the water, so an index is a number that goes stale silently.
const SHIPPED: Dictionary = {
	"pond": Color(0.16, 0.30, 0.36, 0.55),
	"lake": Color(0.30, 0.46, 0.82, 0.55),
	"greatlake": Color(0.32, 0.23, 0.60, 0.55),
	"stream": Color(0.42, 0.78, 0.86, 0.55),
}
const BODIES: PackedStringArray = ["pond", "stream", "lake", "greatlake"]

## A view is a ground point to look at plus how far back to stand. The
## camera keeps the scene's own basis and fov and only ever moves, which is
## exactly what it does in play: HubCamera puts it at (Keepy on the ground)
## + OFFSET and never yaws. `range_z` is the extra distance beyond that
## offset, i.e. how far up the frame the subject sits.
const VIEWS: Array[Dictionary] = [
	{
		"key": "junction",
		"title": "LES DEUX LACS -- LA JONCTION",
		"look": Vector3(-33.10, 0.0, -7.05),
		"range_z": 20.9,
	},
	{
		"key": "pond",
		"title": "LA MARE ET LA TETE DU RUISSEAU",
		"look": Vector3(19.10, 0.0, 7.00),
		"range_z": 14.0,
	},
	{
		"key": "laketail",
		"title": "LE PETIT LAC ET LA QUEUE DU RUISSEAU",
		"look": Vector3(-21.80, 0.0, -3.00),
		"range_z": 18.0,
	},
]

## The candidate families. CURRENT is in the list on purpose: a plate that
## only shows the proposals gives the eye nothing to reject them against,
## and its measured row is also what proves the measuring rig agrees with
## the numbers already written down for the shipped build.
##
## Every candidate colour here clears the bright-band floor of the project's
## palette rule (relative luminance >= 0.549 on the ALBEDO). What that does
## and does not buy once the 0.55 alpha is applied is the whole subject of
## the measured output below -- see the report, not this comment.
const FAMILIES: Array[Dictionary] = [
	{
		"key": "current",
		"title": "ACTUEL (shipped)",
		"note": "reference, non modifie",
		"pond": Color(0.1600, 0.3000, 0.3600, 0.55),
		"stream": Color(0.4200, 0.7800, 0.8600, 0.55),
		"lake": Color(0.3000, 0.4600, 0.8200, 0.55),
		"greatlake": Color(0.3200, 0.2300, 0.6000, 0.55),
	},
	{
		"key": "A",
		"title": "A -- ANCRE STRICTE",
		"note": "le grand lac EST #40E0D0; les trois autres derivent, ecart mene par la TEINTE",
		"pond": Color(0.1840, 0.8464, 0.9200, 0.55),
		"stream": Color(0.3800, 1.0000, 0.7727, 0.55),
		"lake": Color(0.4800, 0.8267, 1.0000, 0.55),
		"greatlake": Color(0.2510, 0.8784, 0.8157, 0.55),
	},
	{
		"key": "B",
		"title": "B -- TEINTE RESSERREE, SATURATION ECARTEE",
		"note": "toutes les teintes dans 170-180; l'ecart est porte par la SATURATION seule",
		"pond": Color(0.0800, 1.0000, 0.8467, 0.55),
		"stream": Color(0.7200, 1.0000, 1.0000, 0.55),
		"lake": Color(0.2510, 0.8784, 0.8157, 0.55),
		"greatlake": Color(0.8000, 1.0000, 0.9933, 0.55),
	},
	{
		"key": "C",
		"title": "C -- TEINTE ETALEE, SATURATION AU PLAFOND",
		"note": "146/172/196/220 deg; saturation la plus haute que la bande claire autorise a chaque teinte",
		"pond": Color(0.1425, 0.9500, 0.4924, 0.55),
		"stream": Color(0.1500, 1.0000, 0.8867, 0.55),
		"lake": Color(0.3400, 0.8240, 1.0000, 0.55),
		"greatlake": Color(0.6700, 0.7800, 1.0000, 0.55),
	},
]

var _out_dir: String = "user://"
var _hub: Node = null
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _ground: MeshInstance3D = null
var _env: Environment = null
var _water: Dictionary = {}          # body key -> MeshInstance3D
var _masks: Dictionary = {}          # "view|body" -> PackedInt32Array of pixel indices

func _ready() -> void:
	ProbeWatchdog.arm(self, "WATER HUE SHEET")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
	if not _out_dir.ends_with("/"):
		_out_dir += "/"
	_run()

func _run() -> void:
	print("=== WATER HUE SHEET ===")
	print("driver=%s  out=%s  view=%dx%d" % [
		DisplayServer.get_name(), _out_dir, VIEW_SIZE.x, VIEW_SIZE.y])
	if DisplayServer.get_name() == "headless":
		push_error("WaterHueSheet: DUMMY driver -- every pixel would read black. Run under xvfb.")
		get_tree().quit(2)
		return
	if not _build():
		get_tree().quit(1)
		return
	await _settle()
	await _build_masks()
	await _render_families()
	print("--- done ---")
	get_tree().quit(0)

func _build() -> bool:
	var packed := load(HUB_WORLD_SCENE) as PackedScene
	if packed == null:
		push_error("WaterHueSheet: cannot load %s" % HUB_WORLD_SCENE)
		return false
	_hub = packed.instantiate()
	add_child(_hub)

	var container := _hub.get_node_or_null("WorldViewport") as SubViewportContainer
	_viewport = _hub.get_node_or_null("WorldViewport/SubViewport") as SubViewport
	var world := _hub.get_node_or_null("WorldViewport/SubViewport/World")
	_camera = _hub.get_node_or_null("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_ground = _hub.get_node_or_null("WorldViewport/SubViewport/World/Ground") as MeshInstance3D
	var env_node := _hub.get_node_or_null("WorldViewport/SubViewport/World/WorldEnvironment") as WorldEnvironment
	if container == null or _viewport == null or world == null or _camera == null \
			or _ground == null or env_node == null:
		push_error("WaterHueSheet: the hub scene does not have the nodes this sheet reads.")
		return false
	_env = env_node.environment

	# A SubViewportContainer with stretch on FORCES the SubViewport to its own
	# size, so an explicit size is ignored with only a warning -- already paid
	# for once in this repo, where two aspect ratios measured identically.
	container.stretch = false
	_viewport.size = VIEW_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Freeze everything that would move under the measurement. The camera
	# lerps toward Keepy every frame and the hopper writes his transform, so
	# a capture taken with either alive is a capture of a moment, not a pose.
	_camera.set_process(false)
	for path in ["WorldViewport/SubViewport/World/Keepy", "Mooring", "TapInput"]:
		var node := _hub.get_node_or_null(path)
		if node:
			node.set_process(false)
			node.set_physics_process(false)

	for child in world.get_node("Props").get_children():
		_collect_water(child)
	for key in BODIES:
		if not _water.has(key):
			push_error("WaterHueSheet: no mesh found for water body '%s'." % key)
			return false
	print("water bodies found: %d/%d" % [_water.size(), BODIES.size()])
	return true

## Walks a prop subtree for the alpha-blended surfaces. The four bodies are
## the ONLY translucent surfaces on the plateau, so alpha < 1 finds them and
## the shipped colour says which is which.
func _collect_water(node: Node) -> void:
	var mesh := node as MeshInstance3D
	if mesh:
		var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat and mat.albedo_color.a < 1.0:
			for key in SHIPPED.keys():
				if mat.albedo_color.is_equal_approx(SHIPPED[key]):
					_water[key] = mesh
	for child in node.get_children():
		_collect_water(child)

func _settle() -> void:
	for _i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw

func _place(view: Dictionary) -> void:
	var look: Vector3 = view["look"]
	var range_z: float = view["range_z"]
	# HubCamera.OFFSET, plus the extra standoff this view asks for. The basis
	# is left exactly as the scene authored it -- pitch and fov are the real
	# camera's, only the position moves.
	_camera.position = Vector3(look.x, HubCamera.OFFSET.y, look.z + HubCamera.OFFSET.z + range_z)

## One ID pass per body per view: the target opaque white, the other three
## opaque black, fog off. A pixel belongs to that body iff it comes back
## exactly white, so the mask is exact rather than thresholded.
func _build_masks() -> void:
	var fog_was: bool = _env.fog_enabled
	_env.fog_enabled = false
	var saved: Dictionary = {}
	for key in BODIES:
		saved[key] = _material(key).albedo_color
	var ground_mat := _ground.get_surface_override_material(0) as StandardMaterial3D
	var ground_was: Color = ground_mat.albedo_color

	for view in VIEWS:
		_place(view)
		for target in BODIES:
			for key in BODIES:
				_set_key(key, Color.WHITE if key == target else Color.BLACK)
			await _settle()
			_masks["%s|%s" % [view["key"], target]] = _white_mask(await _grab())
		for key in BODIES:
			_set_key(key, Color.BLACK)
		ground_mat.albedo_color = Color.WHITE
		await _settle()
		_masks["%s|ground" % view["key"]] = _white_mask(await _grab())
		ground_mat.albedo_color = ground_was

	for key in BODIES:
		_material(key).albedo_color = saved[key]
	_env.fog_enabled = fog_was
	print("masks built: %d" % _masks.size())

func _set_key(key: String, colour: Color) -> void:
	_material(key).albedo_color = colour

func _material(key: String) -> StandardMaterial3D:
	var mesh: MeshInstance3D = _water[key]
	return mesh.get_surface_override_material(0) as StandardMaterial3D

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return _viewport.get_texture().get_image()

func _white_mask(img: Image) -> PackedInt32Array:
	var out := PackedInt32Array()
	var w := img.get_width()
	for y in img.get_height():
		for x in w:
			var c := img.get_pixel(x, y)
			if c.r8 == 255 and c.g8 == 255 and c.b8 == 255:
				out.append(y * w + x)
	return out

func _render_families() -> void:
	for family in FAMILIES:
		print("")
		print("### FAMILY %s -- %s" % [family["key"], family["title"]])
		print("    %s" % family["note"])
		for view in VIEWS:
			_place(view)
			for key in BODIES:
				_material(key).albedo_color = family[key]
			await _settle()
			var img := await _grab()
			var path := "%swater_%s_%s.png" % [_out_dir, family["key"], view["key"]]
			img.save_png(path)
			# The same frame again with every water OPAQUE. Not for looking
			# at -- it is the second point of a straight line. Fog and the
			# 0.55 blend are both linear blends, so the rendered colour is
			# AFFINE in the alpha; two measured alphas therefore give the
			# exact rendered result at any alpha, with no model in between.
			for key in BODIES:
				var opaque: Color = family[key]
				opaque.a = 1.0
				_material(key).albedo_color = opaque
			await _settle()
			var solid := await _grab()
			print("  [%s] %s" % [view["key"], path])
			_measure(img, solid, view["key"])

## The MEAN is the headline and the dominant is the check, and that is the
## opposite of every hazard recolour in this project -- deliberately. A flat
## unlit hazard fills its sample window with ONE value, so the dominant IS
## its colour. These four surfaces are large and span a lot of depth, so the
## exponential fog grades them continuously: the dominant of a great lake
## 34 000 pixels wide carries 4-9% of them and is just the most common step
## of a gradient. The mean over the mask is the colour of the surface; the
## dominant, its share and the distinct count are what say how graded it is.
func _measure(img: Image, solid: Image, view_key: String) -> void:
	var width := img.get_width()
	var ground_mask: PackedInt32Array = _masks.get("%s|ground" % view_key, PackedInt32Array())
	var ground := _stats(img, ground_mask, width)
	if ground.is_empty():
		print("    ground: not visible in this view")
		return
	var gl: float = _luminance(ground["mean"])
	print("    ground    mean %s Lrel %.4f  (dominant %s share %5.1f%% distinct %4d)" % [
		_hex(ground["mean"]), gl, _hex(ground["dominant"]),
		ground["share"] * 100.0, ground["distinct"]])
	var floor_l: float = 3.0 * (gl + 0.05) - 0.05
	for key in BODIES:
		var mask: PackedInt32Array = _masks.get("%s|%s" % [view_key, key], PackedInt32Array())
		var stats := _stats(img, mask, width)
		if stats.is_empty():
			continue
		var mean: Color = stats["mean"]
		var wl: float = _luminance(mean)
		var opaque_l: float = _luminance(_stats(solid, mask, width)["mean"])
		print("    %-9s mean %s Lrel %.4f vs sol %5.2f:1 hsv(%6.1f,%5.3f,%5.3f) | dom %s %5.1f%% d%4d px%6d | a=1 Lrel %.4f -> a pour 3.0:1 %s" % [
			key, _hex(mean), wl, _ratio(wl, gl), _hue(mean), _sat(mean), mean.v,
			_hex(stats["dominant"]), stats["share"] * 100.0, stats["distinct"],
			stats["pixels"], opaque_l, _alpha_for(floor_l, wl, opaque_l)])

## Rendered luminance is affine in the material alpha, and both endpoints
## here are MEASURED rather than modelled: wl at the shipped 0.55 and
## opaque_l at 1.0. Solving that line for the bright-band floor says what
## alpha this exact colour would need -- the one lever that is not a hue.
func _alpha_for(target_l: float, l_at_055: float, l_at_1: float) -> String:
	var slope: float = (l_at_1 - l_at_055) / (1.0 - 0.55)
	if absf(slope) < 1e-6:
		return "n/a"
	var a: float = 0.55 + (target_l - l_at_055) / slope
	if a > 1.0:
		return ">1.00"
	if a < 0.0:
		return "atteint"
	return "%.2f" % a

## Histogram-dominant, not the mean. This project has produced BOTH a
## window artefact and a real colour change that a mean could not tell
## apart; the dominant value plus the share of the pixels that carry it is
## what separates them.
func _stats(img: Image, mask: PackedInt32Array, width: int) -> Dictionary:
	if mask.is_empty():
		return {}
	var counts: Dictionary = {}
	var acc := Vector3.ZERO
	for index in mask:
		var c := img.get_pixel(index % width, index / width)
		var packed: int = (c.r8 << 16) | (c.g8 << 8) | c.b8
		counts[packed] = int(counts.get(packed, 0)) + 1
		# Averaged in LINEAR light. Averaging sRGB bytes would bias every
		# graded surface toward its dark end, which is precisely the end
		# the fog is adding.
		acc += Vector3(_lin(c.r), _lin(c.g), _lin(c.b))
	acc /= float(mask.size())
	var best: int = -1
	var best_n: int = 0
	for packed in counts.keys():
		var n: int = counts[packed]
		if n > best_n:
			best_n = n
			best = packed
	return {
		"mean": Color(_srgb(acc.x), _srgb(acc.y), _srgb(acc.z)),
		"dominant": Color8((best >> 16) & 255, (best >> 8) & 255, best & 255),
		"share": float(best_n) / float(mask.size()),
		"distinct": counts.size(),
		"pixels": mask.size(),
	}

func _srgb(v: float) -> float:
	var c: float = clampf(v, 0.0, 1.0)
	return c * 12.92 if c <= 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055

func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)

func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)

func _ratio(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)

func _hue(c: Color) -> float:
	return c.h * 360.0

func _sat(c: Color) -> float:
	return c.s

func _hex(c: Color) -> String:
	return "#%02X%02X%02X" % [c.r8, c.g8, c.b8]
