extends Node
## Dev-only: sweeps the ALPHA of every water body on the plateau and reports,
## per body, the smallest step that clears the 3.0:1 floor against the hub
## ground in EVERY view that body is visible in.
##
## =====================================================================
## WHY A SWEEP AND NOT A FORMULA
##
## WATER-HUE-1 fitted an affine model to two points (the shipped alpha and
## fully opaque) and extrapolated. WATER-HUE-2 measured the result and the
## model UNDERSHOT all four bodies -- every one of them came out at
## 2.48-2.94:1 at its predicted alpha, under the floor. Two points define a
## line; they do not prove linearity. So this file measures every candidate
## step instead of deriving one, and that is now the standing rule for any
## water tuning in this repo.
##
## SPAWN-LAKE-1 needs it again for a reason of its own: the colour is now
## UNIFORM across all five bodies (#40E0D0), so alpha is the ONLY remaining
## lever. If a body cannot clear the floor at alpha <= 1.0, the honest
## answer is to say so and publish the best it reached -- not to bend the
## colour back to rescue the number.
##
## =====================================================================
## IT CHOOSES NOTHING, AND IT GATES NOTHING
##
## It prints a table and exits 0. The values it recommends are copied into
## HubBuilder.gd by hand, in a separate commit, exactly as WATER-HUE-2 did.
##
## =====================================================================
## WHY IT MUST RUN UNDER xvfb AND NOT --headless
##
## --headless forces the DUMMY driver: get_image() returns an empty surface,
## every sample reads (0,0,0), every ratio comes out 1.00:1 and the probe
## still exits 0. The exact false green this repo has already paid for.
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --path . \
##       res://scripts/dev/WaterAlphaSweep.tscn

const HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

## Half the shipped 1080x1920. The RATIO fixes the framing (the camera is
## KEEP_WIDTH, so the horizontal fov is fixed and the vertical follows the
## aspect); the pixel count only fixes how long a frame takes under llvmpipe.
const VIEW_SIZE: Vector2i = Vector2i(540, 960)
const SETTLE_FRAMES: int = 4

## The WCAG floor this project holds water to, against the hub's own ground.
const CONTRAST_FLOOR: float = 3.0

## Bodies are keyed by the layout CENTRE that builds them, never by colour.
## Colour stopped being an identifier the moment every body took the same
## albedo; a centre cannot go stale without LakeZoneProbe's bijection check
## failing first. The stream has no centre in the layout, so its node sits
## at the origin -- which is itself a unique key here.
const BODIES: Array[Dictionary] = [
	{"key": "pond", "at": Vector3(20.70, 0.0, 7.40)},
	{"key": "smalllake", "at": Vector3(-25.10, 0.0, -5.30)},
	{"key": "greatlake", "at": Vector3(15.5, 0.0, -19.0)},
	{"key": "spawnlake", "at": Vector3(-12.0, 0.0, -19.5)},
	{"key": "stream", "at": Vector3.ZERO},
]

## A view is a ground point to stand behind plus how far back to stand. The
## camera keeps the scene's own basis and fov and only ever moves, which is
## what the real camera does when Keepy walks.
const VIEWS: Array[Dictionary] = [
	{"key": "pond", "look": Vector3(19.10, 0.0, 7.00), "range_z": 14.0},
	{"key": "laketail", "look": Vector3(-21.80, 0.0, -3.00), "range_z": 18.0},
	{"key": "greatlake", "look": Vector3(15.50, 0.0, -19.00), "range_z": 22.0},
	{"key": "spawnlake", "look": Vector3(-12.00, 0.0, -19.50), "range_z": 18.0},
	{"key": "twolobes", "look": Vector3(1.75, 0.0, -19.25), "range_z": 30.0},
]

## Steps to try, coarsest usable to fully opaque. 0.05 is the granularity
## WATER-HUE-2 swept at and the granularity its shipped values sit on.
## Array[float] and not PackedFloat32Array: a packed array constructor is
## not a constant expression in 4.3, and a probe whose script fails to parse
## does not fail fast -- the scene never loads, so nothing arms a watchdog.
const ALPHAS: Array[float] = [
	0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.85, 0.90, 0.95, 1.00]

## A mask smaller than this is not a measurement -- it is a sliver of a body
## the view barely catches, and its mean is noise. Bodies under it are
## reported as "not visible in this view" and excluded from the verdict.
const MIN_MASK_PIXELS: int = 200

var _hub: Node = null
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _ground: MeshInstance3D = null
var _env: Environment = null
var _water: Dictionary = {}
var _masks: Dictionary = {}
var _ground_l: Dictionary = {}
var _alphas: Array[float] = ALPHAS.duplicate()

func _ready() -> void:
	ProbeWatchdog.arm(self, "WATER ALPHA SWEEP")
	# --alphas=0.95,0.90 narrows the sweep to named steps. That is what a
	# CONFIRM run uses after the values are written into HubBuilder: it
	# re-measures the shipped constants themselves instead of a runtime
	# override of them, and it costs one column instead of eleven.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--alphas="):
			_alphas = []
			for piece in arg.substr(9).split(",", false):
				_alphas.append(float(piece))
	_run()

func _run() -> void:
	print("=== WATER ALPHA SWEEP ===")
	print("driver=%s  view=%dx%d  floor=%.1f:1" % [
		DisplayServer.get_name(), VIEW_SIZE.x, VIEW_SIZE.y, CONTRAST_FLOOR])
	if DisplayServer.get_name() == "headless":
		push_error("WaterAlphaSweep: DUMMY driver -- every pixel would read black. Run under xvfb.")
		get_tree().quit(2)
		return
	if not _build():
		get_tree().quit(1)
		return
	await _settle()
	await _build_masks()
	await _sweep()
	print("--- done ---")
	get_tree().quit(0)

func _build() -> bool:
	var packed := load(HUB_WORLD_SCENE) as PackedScene
	if packed == null:
		push_error("WaterAlphaSweep: cannot load %s" % HUB_WORLD_SCENE)
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
		push_error("WaterAlphaSweep: the hub scene does not have the nodes this sweep reads.")
		return false
	_env = env_node.environment

	# stretch FORCES the SubViewport to the container's size, so an explicit
	# size is ignored with only a warning -- already paid for once here.
	container.stretch = false
	_viewport.size = VIEW_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Freeze anything that would move under the measurement.
	_camera.set_process(false)
	for path in ["WorldViewport/SubViewport/World/Keepy", "Mooring", "TapInput"]:
		var node := _hub.get_node_or_null(path)
		if node:
			node.set_process(false)
			node.set_physics_process(false)

	for child in world.get_node("Props").get_children():
		var root := child as Node3D
		if root == null:
			continue
		var mesh := _translucent_mesh(root)
		if mesh == null:
			continue
		var flat := Vector3(root.position.x, 0.0, root.position.z)
		for body in BODIES:
			if flat.distance_to(body["at"] as Vector3) < 0.01:
				_water[body["key"]] = mesh
	for body in BODIES:
		if not _water.has(body["key"]):
			push_error("WaterAlphaSweep: no translucent mesh at %s for '%s'." % [body["at"], body["key"]])
			return false
	print("water bodies found: %d/%d" % [_water.size(), BODIES.size()])
	return true

## The one alpha-blended surface in a water prop's subtree. Every standing
## water body is one translucent disc over an opaque bank, so this is exact.
##
## THE ROOT ITSELF COUNTS, and that is not defensive: _make_stream returns a
## bare MeshInstance3D (its ribbon has no bank to sit inside), while the
## discs return a Node3D with two children. Looking only at children finds
## four bodies out of five and errors on the fifth -- measured, not guessed.
func _translucent_mesh(root: Node3D) -> MeshInstance3D:
	var candidates: Array[Node] = [root]
	candidates.append_array(root.get_children())
	for node in candidates:
		var mesh := node as MeshInstance3D
		if mesh == null:
			continue
		var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			return mesh
	return null

func _settle() -> void:
	for _i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw

func _place(view: Dictionary) -> void:
	var look: Vector3 = view["look"]
	_camera.position = Vector3(
		look.x, HubCamera.OFFSET.y, look.z + HubCamera.OFFSET.z + float(view["range_z"]))

## One ID pass per body per view: target opaque white, everything else black,
## fog off. A pixel is that body's iff it comes back exactly white, so the
## mask is exact rather than thresholded. A fixed sample box cannot work
## here -- the water is alpha over its own bank and the stream is a 1.2 u
## ribbon seen at an angle, so no box is ever all-object.
func _build_masks() -> void:
	var fog_was: bool = _env.fog_enabled
	_env.fog_enabled = false
	var saved: Dictionary = {}
	for body in BODIES:
		saved[body["key"]] = _material(body["key"]).albedo_color
	var ground_mat := _ground.get_surface_override_material(0) as StandardMaterial3D
	var ground_was: Color = ground_mat.albedo_color

	for view in VIEWS:
		_place(view)
		for target in BODIES:
			for body in BODIES:
				_set_key(body["key"], Color.WHITE if body["key"] == target["key"] else Color.BLACK)
			await _settle()
			_masks["%s|%s" % [view["key"], target["key"]]] = _white_mask(await _grab())
		for body in BODIES:
			_set_key(body["key"], Color.BLACK)
		ground_mat.albedo_color = Color.WHITE
		await _settle()
		_masks["%s|ground" % view["key"]] = _white_mask(await _grab())
		ground_mat.albedo_color = ground_was

	for body in BODIES:
		_material(body["key"]).albedo_color = saved[body["key"]]
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

func _sweep() -> void:
	var shipped: Dictionary = {}
	for body in BODIES:
		shipped[body["key"]] = _material(body["key"]).albedo_color

	# The ground, once per view, with the shipped water in place. It is the
	# denominator of every ratio below, so it is measured and never assumed.
	for view in VIEWS:
		_place(view)
		await _settle()
		var img := await _grab()
		var stats := _stats(img, _masks["%s|ground" % view["key"]], img.get_width())
		_ground_l[view["key"]] = _luminance(stats["mean"]) if not stats.is_empty() else -1.0
		print("    ground in view %-10s Lrel %.4f  (%d px)" % [
			view["key"], _ground_l[view["key"]], int(stats.get("pixels", 0))])

	var verdict: Dictionary = {}
	for body in BODIES:
		var key: String = body["key"]
		print("")
		print("### %s" % key.to_upper())
		var per_alpha: Dictionary = {}
		for view in VIEWS:
			var mask: PackedInt32Array = _masks["%s|%s" % [view["key"], key]]
			if mask.size() < MIN_MASK_PIXELS:
				print("    view %-10s not visible (%d px < %d), excluded"
					% [view["key"], mask.size(), MIN_MASK_PIXELS])
				continue
			_place(view)
			var line: String = "    view %-10s %6d px |" % [view["key"], mask.size()]
			for a in _alphas:
				var col: Color = shipped[key]
				_material(key).albedo_color = Color(col.r, col.g, col.b, a)
				await _settle()
				var img2 := await _grab()
				var st := _stats(img2, mask, img2.get_width())
				var ratio: float = _ratio(_luminance(st["mean"]), _ground_l[view["key"]])
				line += " %.2f:%.2f" % [a, ratio]
				var worst: float = float(per_alpha.get(a, 99.0))
				per_alpha[a] = minf(worst, ratio)
			print(line)
			_material(key).albedo_color = shipped[key]
		var chosen: float = -1.0
		for a in _alphas:
			if per_alpha.has(a) and float(per_alpha[a]) >= CONTRAST_FLOOR:
				chosen = a
				break
		if chosen < 0.0:
			var best_a: float = -1.0
			var best_r: float = -1.0
			for a in _alphas:
				if per_alpha.has(a) and float(per_alpha[a]) > best_r:
					best_r = float(per_alpha[a])
					best_a = a
			print("    VERDICT: NO alpha <= 1.00 clears %.1f:1. Best %.2f:1 at a=%.2f."
				% [CONTRAST_FLOOR, best_r, best_a])
			verdict[key] = "FAIL best %.2f:1 at a=%.2f" % [best_r, best_a]
		else:
			print("    VERDICT: smallest alpha clearing %.1f:1 in every view = %.2f (worst view %.2f:1)"
				% [CONTRAST_FLOOR, chosen, float(per_alpha[chosen])])
			verdict[key] = "a=%.2f worst %.2f:1" % [chosen, float(per_alpha[chosen])]
	print("")
	print("### SUMMARY")
	for body in BODIES:
		print("    %-10s %s" % [body["key"], verdict.get(body["key"], "?")])

## Averaged in LINEAR light. Averaging sRGB bytes would bias every graded
## surface toward its dark end -- which is the end the fog is adding.
func _stats(img: Image, mask: PackedInt32Array, width: int) -> Dictionary:
	if mask.is_empty():
		return {}
	var acc := Vector3.ZERO
	for index in mask:
		var c := img.get_pixel(index % width, index / width)
		acc += Vector3(_lin(c.r), _lin(c.g), _lin(c.b))
	acc /= float(mask.size())
	return {
		"mean": Color(_srgb(acc.x), _srgb(acc.y), _srgb(acc.z)),
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
