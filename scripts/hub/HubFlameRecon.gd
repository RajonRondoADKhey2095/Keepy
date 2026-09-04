extends Node3D
class_name HubFlameRecon
## RECON, not a feature. Stands the two or three flame techniques the brief
## names side by side on the plateau so Mathieu can arbitrate them on an
## iPhone -- which is the only place the visual question can be answered.
## Nothing here is tappable, nothing poses Keepy, nothing imports an asset.
##
## =====================================================================
## WHY THE CANDIDATES ARE BUILT SIDE BY SIDE AND NOT ONE AT A TIME
##
## A flame judged alone is judged against a memory of the previous build.
## The three sit 2 u apart on the SAME ground, under the SAME ambient and
## the SAME fog, in ONE frame, so a difference a reader sees is a
## difference between the techniques rather than between two sessions.
##
## =====================================================================
## THE SITE IS GIVEN, NOT DERIVED
##
## (19.9, 25.4) was read off the device by Mathieu through HubWorld's
## position overlay, to one decimal. This file does not second-guess it and
## does not search for a "better" spot. What WAS measured, before anything
## was placed, is the clearance around it -- the XZ convex hull of the eight
## transformed corners of every drawn piece on the plateau:
##
##   slot A (17.9, 25.4)  3.575 u clear
##   site   (19.9, 25.4)  3.521 u clear
##   slot C (21.9, 25.4)  1.676 u clear   <- the tight one, still ~3x the
##                                           widest flame drawn here
##
## The nearest ground-level neighbour is a TreeCrown in every case, and the
## zipline cable passes overhead from y = 3.23 up, never through the site.
## All four points are inside HubRegion.contains().
##
## =====================================================================
## WHAT CARRIES THE LIGHT SIGNAL HERE -- MEASURED, NOT ASSUMED
##
## The plateau is unlit 154/154 and CLAUDE.md records emission as inert on
## an unshaded surface. Re-measured in this renderer for this lot, on a
## quad rendered through the shipped path: emission on an UNLIT material
## moves the pixel by 0.0000 (core mean 0.5451 with and without), while
## Environment glow DOES exist under gl_compatibility -- 1809 halo pixels
## at albedo 1.0 and 5043 at albedo 4.0.
##
## So the halo is NOT free and NOT unavailable: it costs a full-screen post
## pass on the hub's Environment, which today has none. That is a lot-2
## decision with a frame-time price this lot measures rather than takes.
## Everything below therefore carries its signal in ALBEDO alone, and reads
## the same whether or not glow is later switched on.

## The point Mathieu relayed from device. ONE spelling, read by the builder
## and by the labels alike.
const SITE: Vector2 = Vector2(19.9, 25.4)

## Gap between candidates. The brief's "environ 2 u", kept literal.
const SPACING: float = 2.0

## How tall a candidate flame stands, and how wide its widest billboard is.
## Both are recon values: lot 2 arbitrates the real size against the real
## campfire, which does not exist yet.
const FLAME_HEIGHT: float = 1.15
const FLAME_WIDTH: float = 0.55

## Particle budget per emitter. Deliberately equal between A and B so the
## primitive counts this lot publishes compare TECHNIQUES rather than two
## different amounts of work.
const PARTICLE_AMOUNT: int = 28
const PARTICLE_LIFETIME: float = 1.4

## Height of the floating label above each candidate.
const LABEL_HEIGHT: float = 1.95

## The sprite sheet candidate C bakes: a 4x4 grid of 64 px cells.
const SHEET_GRID: int = 4
const SHEET_CELL: int = 64
const SHEET_FPS: float = 12.0

## The flame ramp, hot core to cold tip. Read by all three candidates from
## HERE and never retyped into any of them: three spellings of one gradient
## is how two of them end up a shade apart and the comparison stops being
## about the technique.
const RAMP_CORE: Color = Color(1.00, 0.93, 0.62)
const RAMP_MID: Color = Color(1.00, 0.56, 0.13)
const RAMP_EDGE: Color = Color(0.78, 0.17, 0.04)

## Baked ONCE per run and shared by every candidate that wants it, which is
## what "bake-once" means here: the atlas is a pure function of the
## constants above, so computing it per frame -- or per candidate -- would
## be the same pixels at a cost.
static var _sheet: ImageTexture = null
static var _ramp: GradientTexture1D = null
static var _puff: ImageTexture = null

var _candidates: Dictionary = {}

func _ready() -> void:
	_build()

## The three candidates, west to east, in the order the labels announce.
func _build() -> void:
	var slots: Array[Dictionary] = [
		{"key": &"gpu", "label": "A GPU", "lift": 0.0},
		{"key": &"cpu", "label": "B CPU", "lift": 0.42},
		{"key": &"sheet", "label": "C SHEET", "lift": 0.0},
	]
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var offset: float = (float(i) - 1.0) * SPACING
		var root := Node3D.new()
		root.name = "Flame_%s" % slot["key"]
		root.position = Vector3(SITE.x + offset, 0.0, SITE.y)
		add_child(root)
		match slot["key"]:
			&"gpu":
				root.add_child(_make_gpu())
			&"cpu":
				root.add_child(_make_cpu())
			&"sheet":
				root.add_child(_make_sheet())
		root.add_child(_make_label(slot["label"], slot["lift"]))
		_candidates[slot["key"]] = root

## The candidates, by key, for a probe that needs to switch one off and
## re-measure. Published rather than re-walked from node names: a reader
## that guesses a name gets a null and a green run that measured nothing.
func candidates() -> Dictionary:
	return _candidates.duplicate()

# =====================================================================
# CANDIDATE A -- GPUParticles3D
#
# Its viability was the brief's gating question and it was measured before
# a line of this was written: under gl_compatibility, a GPUParticles3D
# emitting an unshaded quad drew 2078 magenta pixels where an empty frame
# drew 0 and a CPUParticles3D control drew 980. It is NOT a silent no-op in
# this renderer. What that measurement cannot reach is Safari's WebGL2, and
# nothing in this file pretends otherwise.
# =====================================================================
func _make_gpu() -> GPUParticles3D:
	var node := GPUParticles3D.new()
	node.name = "GpuFlame"
	node.amount = PARTICLE_AMOUNT
	node.lifetime = PARTICLE_LIFETIME
	node.explosiveness = 0.0
	node.randomness = 0.35
	node.fixed_fps = 30
	node.draw_pass_1 = _particle_quad()
	node.material_override = _particle_material()

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = FLAME_WIDTH * 0.35
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.gravity = Vector3(0.0, 0.55, 0.0)
	pm.initial_velocity_min = FLAME_HEIGHT * 0.35
	pm.initial_velocity_max = FLAME_HEIGHT * 0.70
	pm.scale_min = 0.55
	pm.scale_max = 1.0
	pm.color_ramp = _flame_ramp()
	node.process_material = pm
	node.position = Vector3(0.0, FLAME_HEIGHT * 0.18, 0.0)
	node.emitting = true
	return node

# =====================================================================
# CANDIDATE B -- CPUParticles3D
#
# The same amount, the same lifetime, the same quad and the same ramp as A,
# on purpose: anything this lot publishes about the two is then about where
# the simulation runs, not about two differently-tuned fires.
# =====================================================================
func _make_cpu() -> CPUParticles3D:
	var node := CPUParticles3D.new()
	node.name = "CpuFlame"
	node.amount = PARTICLE_AMOUNT
	node.lifetime = PARTICLE_LIFETIME
	node.explosiveness = 0.0
	node.randomness = 0.35
	node.mesh = _particle_quad()
	node.material_override = _particle_material()
	node.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	node.emission_sphere_radius = FLAME_WIDTH * 0.35
	node.direction = Vector3.UP
	node.spread = 12.0
	node.gravity = Vector3(0.0, 0.55, 0.0)
	node.initial_velocity_min = FLAME_HEIGHT * 0.35
	node.initial_velocity_max = FLAME_HEIGHT * 0.70
	node.scale_amount_min = 0.55
	node.scale_amount_max = 1.0
	node.color_ramp = _flame_gradient()
	node.position = Vector3(0.0, FLAME_HEIGHT * 0.18, 0.0)
	node.emitting = true
	return node

# =====================================================================
# CANDIDATE C -- one billboard quad, one baked sheet, one shader
#
# The predictable one, and the brief says not to neglect it: ONE draw call,
# ONE quad, no simulation, and a cost that cannot vary with what the frame
# is doing. The atlas is baked once into an ImageTexture rather than
# imported, so this candidate adds no asset to the repository -- which the
# brief forbids -- while still being a real sprite-sheet animation.
# =====================================================================
func _make_sheet() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(FLAME_WIDTH * 1.6, FLAME_HEIGHT)

	var shader := Shader.new()
	shader.code = _SHEET_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("sheet", _flame_sheet())
	mat.set_shader_parameter("grid", float(SHEET_GRID))
	mat.set_shader_parameter("fps", SHEET_FPS)

	var node := MeshInstance3D.new()
	node.name = "SheetFlame"
	node.mesh = quad
	node.set_surface_override_material(0, mat)
	node.position = Vector3(0.0, FLAME_HEIGHT * 0.5, 0.0)
	return node

## ⚠️ `cull_disabled` here is on a FLAT QUAD, not on a closed body, so the
## back-face-repaints-the-front failure CLAUDE.md records for the water
## shader cannot occur: there is no second surface to repaint the first.
## `depth_draw_never` is stated rather than inherited, and the blend is
## ADDITIVE -- a fire adds light to what is behind it, and additive needs
## no depth sort between the three candidates standing in a row.
const _SHEET_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D sheet : source_color, filter_linear;
uniform float grid = 4.0;
uniform float fps = 12.0;

void vertex() {
	// Y-locked billboard: yaw follows the camera, the flame stays upright.
	// Written out rather than taken from BILLBOARD_FIXED_Y because this
	// material is a ShaderMaterial and never sees that flag.
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, up));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float cells = grid * grid;
	float frame = floor(mod(TIME * fps, cells));
	vec2 cell = vec2(mod(frame, grid), floor(frame / grid));
	vec2 uv = (UV + cell) / grid;
	vec4 texel = texture(sheet, uv);
	ALBEDO = texel.rgb * texel.a;
	ALPHA = texel.a;
}
"""

# =====================================================================
# Shared pieces
# =====================================================================

## The quad both particle candidates draw. Tessellation is explicit and
## minimal -- a QuadMesh is two triangles and stays two triangles, which is
## the whole reason a fire made of 28 of them is affordable at all.
func _particle_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(FLAME_WIDTH * 0.5, FLAME_WIDTH * 0.6)
	return quad

## ONE material for A and B. Transparency is set EXPLICITLY: CLAUDE.md
## records that albedo's alpha channel is ignored while `transparency`
## stays DISABLED, which on a fire would render 28 opaque orange cards.
func _particle_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	# ⚠️ NOT a flourish, and the first version of this file did without it.
	# An untextured QuadMesh billboard is a HARD SQUARE: the first capture
	# of this recon showed A and B as stacks of blocky yellow tiles next to
	# C's clean teardrop, which would have put the comparison on the ART
	# instead of on the technique -- exactly the "fixture that diverges from
	# the real on the axis that matters" failure CLAUDE.md records. The puff
	# is white, so the colour still comes from each candidate's own ramp
	# through vertex_color_use_as_albedo, and A, B and C share ONE gradient.
	mat.albedo_texture = _puff_texture()
	mat.disable_receive_shadows = true
	return mat

## The gradient, as a Gradient (what CPUParticles3D wants).
func _flame_gradient() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([
		Color(RAMP_CORE.r, RAMP_CORE.g, RAMP_CORE.b, 1.0),
		Color(RAMP_MID.r, RAMP_MID.g, RAMP_MID.b, 0.75),
		Color(RAMP_EDGE.r, RAMP_EDGE.g, RAMP_EDGE.b, 0.0),
	])
	return g

## The same gradient, as a texture (what ParticleProcessMaterial wants).
## Baked once and shared, for the reason the header gives.
func _flame_ramp() -> GradientTexture1D:
	if _ramp == null:
		_ramp = GradientTexture1D.new()
		_ramp.gradient = _flame_gradient()
		_ramp.width = 64
	return _ramp

## The soft round particle A and B draw, baked ONCE and shared. White with
## a squared falloff in alpha: the shape is the texture's job, the colour is
## the ramp's, and neither duplicates the other.
func _puff_texture() -> ImageTexture:
	if _puff != null:
		return _puff
	var n: int = 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx: float = (float(x) + 0.5) / float(n) - 0.5
			var dy: float = (float(y) + 0.5) / float(n) - 0.5
			var r: float = sqrt(dx * dx + dy * dy) / 0.5
			var a: float = clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a * a))
	_puff = ImageTexture.create_from_image(img)
	return _puff

## The sprite sheet, baked ONCE. A teardrop flame profile with a
## deterministic per-frame wobble -- deterministic because a sheet that
## differed between two runs would make every later pixel comparison
## meaningless.
func _flame_sheet() -> ImageTexture:
	if _sheet != null:
		return _sheet
	var size: int = SHEET_GRID * SHEET_CELL
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var frames: int = SHEET_GRID * SHEET_GRID
	var grad := _flame_gradient()
	for f in frames:
		var phase: float = TAU * float(f) / float(frames)
		var ox: int = (f % SHEET_GRID) * SHEET_CELL
		var oy: int = int(f / SHEET_GRID) * SHEET_CELL
		for py in SHEET_CELL:
			# v = 0 at the base of the cell, 1 at the tip.
			var v: float = 1.0 - (float(py) + 0.5) / float(SHEET_CELL)
			# Teardrop half-width: fattest a third of the way up, pinched
			# at both ends.
			var half: float = sin(pow(v, 0.65) * PI) * 0.42 * (1.0 - v * 0.35)
			# The wobble is what makes 16 frames read as motion.
			var sway: float = sin(phase + v * 3.2) * 0.10 * v * v
			for px in SHEET_CELL:
				var u: float = (float(px) + 0.5) / float(SHEET_CELL) - 0.5 - sway
				if half <= 0.0001:
					continue
				var t: float = absf(u) / half
				if t >= 1.0:
					continue
				# Hot in the middle and low down, cold at the rim and the tip.
				var radial: float = 1.0 - t * t
				var heat: float = clampf(radial * (1.0 - v * 0.85), 0.0, 1.0)
				var c: Color = grad.sample(1.0 - heat)
				c.a = clampf(radial * radial * (1.0 - v * v * 0.55), 0.0, 1.0)
				img.set_pixel(ox + px, oy + py, c)
	_sheet = ImageTexture.create_from_image(img)
	return _sheet

## A floating name over each candidate, because a comparison a reader
## cannot label is three fires and a guess.
## ⚠️ The lift is not decoration: at 2 u apart the first spelling of these
## captions OVERLAPPED each other in the delivered framing, and three names
## a reader cannot tell apart is the same as no names at all. B is raised so
## the row reads as three, and the text is short enough to survive a phone.
func _make_label(text: String, lift: float) -> Label3D:
	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.0016
	label.position = Vector3(0.0, LABEL_HEIGHT + lift, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.shaded = false
	label.double_sided = true
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.94, 0.72)
	label.outline_modulate = Color(0.03, 0.05, 0.02, 1.0)
	label.outline_size = 18
	return label
