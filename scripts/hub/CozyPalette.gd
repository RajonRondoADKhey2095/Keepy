extends RefCounted
class_name CozyPalette
## The hub's carte-blanche palette and the two shader materials every piece
## of decor on this branch draws with. ONE file, read by HubBuilder (the
## layout's props), CozyScatter (ground cover and the forest wall) and
## HubWorld (the environment), so the sky, the haze and the greens cannot
## drift apart between the three.
##
## Voie A of the brief: a light, warm register. Every value is sRGB as
## authored (what Godot's Color inspector shows); the shaders receive them
## through `source_color` uniforms, which converts to linear exactly as
## StandardMaterial3D.albedo_color does.

## Sky / background and the colour the far ground and canopy haze toward.
## The camera pitch leaves only a sliver of true sky at the top of the
## frame; what reads as "sky" is the hazed far ground, so the two share
## one value on purpose.
const SKY: Color = Color(0.74, 0.87, 0.95)
const HAZE: Color = Color(0.74, 0.87, 0.95)
## Exponential haze per world unit of view distance, and the distance at
## which it starts. 0.022 puts the plateau edge (~40 u from the camera at
## its farthest) at ~52 % haze and the 300 u ground edge fully in the sky.
const HAZE_DENSITY: float = 0.022
const HAZE_START: float = 8.0

## Ground greens. GRASS_A is the base, B the darker patch, C the lighter.
const GRASS_A: Color = Color(0.55, 0.78, 0.36)
const GRASS_B: Color = Color(0.44, 0.69, 0.32)
const GRASS_C: Color = Color(0.66, 0.83, 0.41)

## Toon lighting shared by every decor batch.
const SUN_DIR: Vector3 = Vector3(0.35, 0.80, 0.45)
const LIT: float = 1.06
const SHADE: float = 0.78
const SHADE_TINT: Color = Color(0.84, 0.91, 1.0)
const BAND_SOFTNESS: float = 0.28
const RIM_STRENGTH: float = 0.20
const RIM_COLOR: Color = Color(1.0, 0.97, 0.85)

## Landmark recolours (their shapes stay: they are orientation cues).
const LANDMARK_SPIRE_TRUNK: Color = Color(0.42, 0.29, 0.19)
const LANDMARK_SPIRE_CROWN: Color = Color(0.30, 0.62, 0.42)
const LANDMARK_CAIRN_STONE: Color = Color(0.66, 0.60, 0.52)
const LANDMARK_CAIRN_CAP: Color = Color(0.76, 0.70, 0.60)
const LANDMARK_SLAB_STONE: Color = Color(0.66, 0.72, 0.60)
const LANDMARK_SLAB_BASE: Color = Color(0.56, 0.60, 0.48)

## Water, bank and islet recolours. Water keeps its alpha (transparency is
## asked for by HubBuilder._make_water_body, unchanged).
const WATER: Color = Color(0.42, 0.78, 0.86, 0.82)
const STREAM_WATER: Color = Color(0.46, 0.80, 0.88, 0.80)
const BANK: Color = Color(0.86, 0.78, 0.56)
const ISLET: Color = Color(0.86, 0.78, 0.56)

const DECOR_SHADER: Shader = preload("res://assets/shaders/cozy_decor.gdshader")
const GROUND_SHADER: Shader = preload("res://assets/shaders/cozy_ground.gdshader")
const WATER_SHADER: Shader = preload("res://assets/shaders/cozy_water.gdshader")
const SHADOW_SHADER: Shader = preload("res://assets/shaders/cozy_shadow.gdshader")
const BUTTERFLY_SHADER: Shader = preload("res://assets/shaders/cozy_butterfly.gdshader")
const WATER_SHALLOW: Color = Color(0.50, 0.82, 0.88, 0.80)
const WATER_DEEP: Color = Color(0.38, 0.74, 0.85, 0.86)
const WATER_FOAM: Color = Color(0.96, 0.99, 1.0)

static var _decor_static: ShaderMaterial = null
static var _decor_wind: Dictionary = {}
static var _decor_tinted: Dictionary = {}
static var _cloud: ShaderMaterial = null
static var _ground: ShaderMaterial = null
static var _noise: NoiseTexture2D = null
static var _water: Dictionary = {}
static var _shadow: ShaderMaterial = null
static var _butterfly: ShaderMaterial = null
static var _meshes: Dictionary = {}

## The decor material without wind. One instance shared by every batch.
static func decor_material() -> ShaderMaterial:
	if _decor_static == null:
		_decor_static = _make_decor(0.0, 1.0)
	return _decor_static

## A decor material whose vertices sway; one instance per (amount, height)
## pair so grass and canopies can move differently.
static func decor_material_wind(amount: float, height: float) -> ShaderMaterial:
	var key := "%0.3f/%0.3f" % [amount, height]
	if not _decor_wind.has(key):
		_decor_wind[key] = _make_decor(amount, height)
	return _decor_wind[key]

## A decor material for a primitive with no vertex colours: `colour`
## becomes the albedo through the shader's tint uniform. One per colour.
static func decor_material_tinted(colour: Color) -> ShaderMaterial:
	var key := colour.to_html(false)
	if not _decor_tinted.has(key):
		var mat := _make_decor(0.0, 1.0)
		mat.set_shader_parameter("tint", colour)
		_decor_tinted[key] = mat
	return _decor_tinted[key]

## Clouds: the decor toon look with NO haze (they sit 100+ u out, where
## the haze would dissolve them into the sky they are meant to sit in).
static func cloud_material() -> ShaderMaterial:
	if _cloud == null:
		_cloud = _make_decor(0.0, 1.0)
		_cloud.set_shader_parameter("tint", Color(0.985, 0.99, 1.0))
		_cloud.set_shader_parameter("haze_density", 0.0)
		_cloud.set_shader_parameter("shade", 0.86)
		_cloud.set_shader_parameter("rim_strength", 0.0)
	return _cloud

static func _make_decor(wind_amount: float, wind_height: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DECOR_SHADER
	mat.set_shader_parameter("sun_dir", SUN_DIR)
	mat.set_shader_parameter("lit", LIT)
	mat.set_shader_parameter("shade", SHADE)
	mat.set_shader_parameter("shade_tint", SHADE_TINT)
	mat.set_shader_parameter("band_softness", BAND_SOFTNESS)
	mat.set_shader_parameter("rim_strength", RIM_STRENGTH)
	mat.set_shader_parameter("rim_color", RIM_COLOR)
	mat.set_shader_parameter("haze_color", HAZE)
	mat.set_shader_parameter("haze_density", HAZE_DENSITY)
	mat.set_shader_parameter("haze_start", HAZE_START)
	mat.set_shader_parameter("wind_amount", wind_amount)
	mat.set_shader_parameter("wind_height", wind_height)
	return mat

## One seamless 256x256 simplex texture, shared by the ground and the
## water: a texture fetch is what a mobile GPU is fast at, a procedural
## noise in the fragment shader is not.
static func noise_texture() -> NoiseTexture2D:
	if _noise == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.seed = 20260905
		noise.frequency = 0.02
		noise.fractal_octaves = 3
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		tex.noise = noise
		_noise = tex
	return _noise

## Water material for a disc of model-space `radius` (foam rim), or a
## ribbon when 0. `two_sided` for the stream, whose ribbon is one-sided
## geometry the old material drew with culling off.
static func water_material(radius: float, two_sided: bool = false) -> ShaderMaterial:
	var key := "%0.3f/%s" % [radius, two_sided]
	if not _water.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = WATER_SHADER
		mat.set_shader_parameter("noise_tex", noise_texture())
		mat.set_shader_parameter("shallow", WATER_SHALLOW)
		mat.set_shader_parameter("deep", WATER_DEEP)
		mat.set_shader_parameter("foam", WATER_FOAM)
		mat.set_shader_parameter("radius", radius)
		mat.set_shader_parameter("haze_color", HAZE)
		mat.set_shader_parameter("haze_density", HAZE_DENSITY)
		mat.set_shader_parameter("haze_start", HAZE_START)
		_water[key] = mat
	return _water[key]

static func butterfly_material() -> ShaderMaterial:
	if _butterfly == null:
		_butterfly = ShaderMaterial.new()
		_butterfly.shader = BUTTERFLY_SHADER
		_butterfly.set_shader_parameter("haze_color", HAZE)
		_butterfly.set_shader_parameter("haze_density", HAZE_DENSITY)
		_butterfly.set_shader_parameter("haze_start", HAZE_START)
	return _butterfly

static func shadow_material() -> ShaderMaterial:
	if _shadow == null:
		_shadow = ShaderMaterial.new()
		_shadow.shader = SHADOW_SHADER
	return _shadow

static func ground_material() -> ShaderMaterial:
	if _ground == null:
		var mat := ShaderMaterial.new()
		mat.shader = GROUND_SHADER
		mat.set_shader_parameter("noise_tex", noise_texture())
		mat.set_shader_parameter("grass_a", GRASS_A)
		mat.set_shader_parameter("grass_b", GRASS_B)
		mat.set_shader_parameter("grass_c", GRASS_C)
		mat.set_shader_parameter("haze_color", HAZE)
		mat.set_shader_parameter("haze_density", HAZE_DENSITY)
		mat.set_shader_parameter("haze_start", HAZE_START)
		_ground = mat
	return _ground

## The Mesh inside a decor GLB, cached by path. The GLB is a PackedScene
## whose single MeshInstance3D carries the mesh; the vertex colours ride on
## the mesh, so a batch needs nothing but this.
static func glb_mesh(path: String) -> Mesh:
	if _meshes.has(path):
		return _meshes[path]
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("CozyPalette: cannot load %s" % path)
		return null
	var scene := packed.instantiate()
	var found: Mesh = null
	var stack: Array[Node] = [scene]
	while not stack.is_empty() and found == null:
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			found = (node as MeshInstance3D).mesh
		for child in node.get_children():
			stack.append(child)
	scene.free()
	if found == null:
		push_error("CozyPalette: no mesh in %s" % path)
	_meshes[path] = found
	return found

static func decor_path(name: String) -> String:
	return "res://assets/models/decor/%s.glb" % name

## Deterministic per-instance tint: a small brightness / warmth wobble so
## forty trees from three GLBs do not read as three trees.
static func tint(seed_value: int, amount: float = 0.08) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var b: float = 1.0 + rng.randf_range(-amount, amount)
	var warm: float = rng.randf_range(-amount * 0.5, amount * 0.5)
	return Color(b + warm, b, b - warm * 0.5, 1.0)
