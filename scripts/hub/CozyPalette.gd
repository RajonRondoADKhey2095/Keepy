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
## v2 -- the autumn hollow's leaf-litter ground, three tones like the grass.
const AUTUMN_A: Color = Color(0.80, 0.54, 0.28)
const AUTUMN_B: Color = Color(0.66, 0.40, 0.20)
const AUTUMN_C: Color = Color(0.90, 0.68, 0.32)
const AUTUMN_EDGE_Z: float = -39.0
const AUTUMN_EDGE_W: float = 7.0
## v3: the moor. Heather mauves, lavender-row colours, and the three
## field rectangles (xmin, zmin, xmax, zmax) painted into the ground and
## planted by CozyScatter -- ONE table for both.
const MOOR_A: Color = Color(0.66, 0.58, 0.76)
const MOOR_B: Color = Color(0.54, 0.46, 0.66)
const MOOR_C: Color = Color(0.82, 0.76, 0.60)
const MOOR_EDGE_Z: float = -82.0
const MOOR_EDGE_W: float = 3.0
const ROW_VIOLET: Color = Color(0.50, 0.32, 0.72)
const ROW_SOIL: Color = Color(0.78, 0.70, 0.54)
const ROW_PITCH: float = 2.4
const LAVENDER_FIELDS: Array[Vector4] = [
	Vector4(-32.0, -120.0, -8.0, -100.0),
	Vector4(-30.0, -97.0, -10.0, -89.0),
	Vector4(22.0, -122.0, 36.0, -98.0),
]

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
static var _cells: NoiseTexture2D = null
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

## A seamless cellular texture for the ground's clover-carpet mottle.
static func cell_texture() -> NoiseTexture2D:
	if _cells == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.seed = 4242
		noise.frequency = 0.045
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		tex.noise = noise
		_cells = tex
	return _cells

const PATH: Color = Color(0.84, 0.74, 0.52)

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
		mat.set_shader_parameter("ribbon", 1.0 if two_sided else 0.0)
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
		mat.set_shader_parameter("cell_tex", cell_texture())
		mat.set_shader_parameter("grass_a", GRASS_A)
		mat.set_shader_parameter("grass_b", GRASS_B)
		mat.set_shader_parameter("grass_c", GRASS_C)
		mat.set_shader_parameter("autumn_a", AUTUMN_A)
		mat.set_shader_parameter("autumn_b", AUTUMN_B)
		mat.set_shader_parameter("autumn_c", AUTUMN_C)
		mat.set_shader_parameter("autumn_edge_z", AUTUMN_EDGE_Z)
		mat.set_shader_parameter("autumn_edge_w", AUTUMN_EDGE_W)
		mat.set_shader_parameter("haze_color", HAZE)
		mat.set_shader_parameter("haze_density", HAZE_DENSITY)
		mat.set_shader_parameter("haze_start", HAZE_START)
		mat.set_shader_parameter("moor_edge_z", MOOR_EDGE_Z)
		mat.set_shader_parameter("moor_edge_w", MOOR_EDGE_W)
		mat.set_shader_parameter("moor_a", MOOR_A)
		mat.set_shader_parameter("moor_b", MOOR_B)
		mat.set_shader_parameter("moor_c", MOOR_C)
		mat.set_shader_parameter("row_violet", ROW_VIOLET)
		mat.set_shader_parameter("row_soil", ROW_SOIL)
		mat.set_shader_parameter("row_pitch", ROW_PITCH)
		for k in 3:
			mat.set_shader_parameter("field_%d" % k, LAVENDER_FIELDS[k])
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


## ---- v2: weather ------------------------------------------------------
## One look per state. Everything the weather can change lives here, and
## apply_weather() below is the only writer of the materials this file
## caches. Colours are what the ground/sky READ, not albedos.
static func weather_look(kind: int) -> Dictionary:
	match kind:
		1: # RAIN
			return {"kind": 1, "sky": Color(0.60, 0.68, 0.76), "haze": Color(0.64, 0.70, 0.76), "density": 0.034,
				"tint": Color(0.80, 0.84, 0.92), "wind": 1.8, "lean": Vector2(0.10, 0.04), "rain": 1.0, "snow": 0.0,
				"overlay": Color(0.30, 0.38, 0.55, 0.16), "shadow": 0.35, "hidden": 1.0, "cloud": Color(0.72, 0.74, 0.80)}
		2: # STORM
			return {"kind": 2, "sky": Color(0.36, 0.40, 0.50), "haze": Color(0.42, 0.46, 0.54), "density": 0.045,
				"tint": Color(0.58, 0.62, 0.74), "wind": 3.0, "lean": Vector2(0.26, 0.10), "rain": 1.0, "snow": 0.0,
				"overlay": Color(0.12, 0.14, 0.28, 0.30), "shadow": 0.15, "hidden": 1.0, "cloud": Color(0.45, 0.47, 0.55)}
		3: # SNOW
			return {"kind": 3, "sky": Color(0.84, 0.87, 0.92), "haze": Color(0.88, 0.90, 0.94), "density": 0.040,
				"tint": Color(0.92, 0.94, 1.0), "wind": 0.8, "lean": Vector2(0.0, 0.0), "rain": 0.0, "snow": 1.0,
				"overlay": Color(0.85, 0.90, 1.0, 0.10), "shadow": 0.5, "hidden": 1.0, "cloud": Color(0.95, 0.96, 0.98)}
		_: # SUN
			return {"kind": 0, "sky": SKY, "haze": HAZE, "density": HAZE_DENSITY,
				"tint": Color(1.0, 1.0, 1.0), "wind": 1.0, "lean": Vector2(0.0, 0.0), "rain": 0.0, "snow": 0.0,
				"overlay": Color(0.0, 0.0, 0.0, 0.0), "shadow": 1.0, "hidden": 0.0, "cloud": Color(0.985, 0.99, 1.0)}

static func blend_looks(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key in b.keys():
		var vb = b[key]
		var va = a.get(key, vb)
		if vb is Color:
			out[key] = (va as Color).lerp(vb, t)
		elif vb is Vector2:
			out[key] = (va as Vector2).lerp(vb, t)
		elif vb is float:
			out[key] = lerpf(float(va), vb, t)
		else:
			out[key] = vb
	return out

static func _set_common(mat: ShaderMaterial, look: Dictionary, tint: Color) -> void:
	mat.set_shader_parameter("weather_tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("haze_color", look["haze"])
	mat.set_shader_parameter("haze_density", look["density"])

static func apply_weather(look: Dictionary) -> void:
	var flash: float = look.get("flash", 0.0)
	var base: Color = look["tint"]
	var tint := base.lerp(Color(1.55, 1.55, 1.65), flash)
	var decor: Array = [_decor_static]
	decor.append_array(_decor_wind.values())
	decor.append_array(_decor_tinted.values())
	for mat in decor:
		if mat == null:
			continue
		_set_common(mat, look, tint)
		mat.set_shader_parameter("wind_scale", look["wind"])
		mat.set_shader_parameter("lean", look["lean"])
		mat.set_shader_parameter("snow", look["snow"])
	if _cloud != null:
		_cloud.set_shader_parameter("tint", look["cloud"])
		_cloud.set_shader_parameter("weather_tint", Vector3(tint.r, tint.g, tint.b))
	if _ground != null:
		_set_common(_ground, look, tint)
		_ground.set_shader_parameter("wet", look.get("wet", 0.0))
		_ground.set_shader_parameter("snow", look["snow"])
	for mat in _water.values():
		_set_common(mat, look, tint)
		mat.set_shader_parameter("rain", look["rain"])
	if _butterfly != null:
		_set_common(_butterfly, look, tint)
		_butterfly.set_shader_parameter("hidden", look["hidden"])
	if _shadow != null:
		_shadow.set_shader_parameter("strength", look["shadow"])
	if _precip != null:
		_precip.set_shader_parameter("rain", look["rain"])
		_precip.set_shader_parameter("snow", look["snow"])
		_precip.set_shader_parameter("weather_tint", Vector3(tint.r, tint.g, tint.b))

static var _precip: ShaderMaterial = null
const PRECIP_SHADER: Shader = preload("res://assets/shaders/cozy_precip.gdshader")
static func precip_material() -> ShaderMaterial:
	if _precip == null:
		_precip = ShaderMaterial.new()
		_precip.shader = PRECIP_SHADER
	return _precip
