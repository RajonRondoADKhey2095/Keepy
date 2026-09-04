extends Node3D
class_name HubCampfire
## The real campfire prop -- LOT 3 of CH23. Replaces HubFlameRecon.gd, which
## is gone: this file is no longer a comparison, it is the shipped object.
##
## Candidate E won the lot 2 arbitration on device (4 septembre 2026):
## Mathieu's own campfire_flame.png on a billboard, moved by shader. D1/D2
## (the procedural teardrop) are NOT here -- they never reached the
## illustrated, flat-area silhouette the brief asked for (a smooth single
## contour, not clipart aplats), and this file does not keep them "just in
## case". That result is recorded in full in docs/lots/CH23_FEU_VFX.md; it
## was a useful measurement, not a mistake to erase.
##
## The fire is ALWAYS LIT. No tap, no Area3D, no ignition state, no
## persistence -- Mathieu's decision for this lot. A campfire that can be
## turned off is a state machine this file is explicitly told not to build.
##
## =====================================================================
## TWO SCALES, SIDE BY SIDE, FOR DEVICE ARBITRATION -- ECHELLE IS NOT MINE
## TO DECIDE
##
## The brief is explicit that scale is Mathieu's call, not this session's.
## Lot 2's device capture showed the bare flame (no logs, scale x1.0)
## reading at roughly Keepy's head height -- and the brief itself predicts
## that once real logs sit under it, that reads small. Reasoning applied
## here, spelled out rather than asserted:
##
##   Keepy stands about 1.55 u tall (Body capsule: radius 0.4, height 1.3,
##   lifted 0.9 -- top around y=1.55). A campfire that is meant to read as
##   this camp's central gathering feature, not a garnish, wants to compete
##   with that silhouette rather than sit at knee height beside it.
##
## SCALE_SITE = 1.6 total flame height 1.84 u (1.15 * 1.6), plus the log
##   pile's own ~0.42 u -- puts the flame's tip close to Keepy's own head
##   height as seen from a few metres off, which is roughly where a real
##   sitting-height bonfire reads next to an adult. RECOMMENDED: this is
##   the scale that stops reading as "a candle on sticks" against the rest
##   of the hub's furniture (turnstile, seesaw, diving board all stand
##   taller than 1.6 u themselves).
## SCALE_ALT = 1.2 total flame height 1.38 u -- a conservative bump from
##   the validated x1.0, close enough to the lot 2 capture that Mathieu can
##   read it as "the same fire, only slightly bigger" rather than a new
##   guess.
##
## One occupies the exact site Mathieu read off the device; the other
## stands 3 u away for a direct side-by-side. Lot 4 keeps ONE of the two
## and deletes this comparison, per the brief's own NEXT STEPS.
## =====================================================================
const SITE: Vector2 = Vector2(19.9, 25.4)

## 3 u west of SITE, on the side lot 2 measured as the roomier neighbour
## (3.575 u clear at the west candidate slot, against 1.676 u to the east) --
## reused as a starting point, then re-measured in this lot with the log
## pile's own footprint included (see docs/lots/CH23_FEU_VFX.md lot 3).
const SITE_ALT: Vector2 = Vector2(16.9, 25.4)

const SCALE_SITE: float = 1.6
const SCALE_ALT: float = 1.2

const FLAME_HEIGHT: float = 1.15
const FLAME_WIDTH: float = 0.72
const FLAME_TEXTURE_PATH: String = "res://assets/textures/props/campfire_flame.png"

## Candidate E's motion, carried over byte-for-byte from the lot 2
## comparison: the brief did not ask this lot to re-tune it, only to ship
## it. Frequencies stay non-commensurable on purpose (see the shader
## below) so the fire never visibly repeats on a short cycle.
const PULSE_HZ: float = 0.83
const PULSE_AMOUNT: float = 0.085
const SWAY_HZ: float = 0.61
const SWAY_AMOUNT: float = 0.045
const FLICKER_HZ: float = 1.37
const FLICKER_AMOUNT: float = 0.11

## =====================================================================
## LOGS -- crossed cylinders, the tree trunks' own material, never a
## billboard
##
## A billboard log would spin to face the camera exactly like the flame
## does, and a spinning log is a log that betrays it is a drawing the
## instant the camera's relative angle changes -- the flame gets away
## with billboarding because fire has no fixed orientation to begin with,
## a log very much does. So every log below is real geometry: a
## CylinderMesh, oriented log by log with an explicit basis, never
## rotated to face anything.
##
## Six logs lean in from a ring at the base to a shared point overhead,
## teepee-style -- a shape chosen because it wraps the flame's base in
## roughly EVERY azimuth rather than only two opposing sides, which is
## what the flame's hard-cut bottom edge (assets/textures/props/
## campfire_flame.png's opaque body runs flat to its own bottom row, no
## fade) needs to stay hidden behind. Verified by offscreen render at
## eight azimuths in this lot's report, not assumed from the shape alone.
## =====================================================================
const LOG_COUNT: int = 6
const LOG_RING_RADIUS: float = 0.30
const LOG_BASE_HEIGHT: float = 0.05
const LOG_APEX_HEIGHT: float = 0.44
const LOG_RADIUS_TOP: float = 0.045
const LOG_RADIUS_BOTTOM: float = 0.065
const LOG_RADIAL_SEGMENTS: int = 6

## Reused, not retyped -- the "un fait est publié une fois" rule
## (CLAUDE.md): this is the exact colour every tree trunk in the hub
## already draws, read off HubBuilder rather than copied by eye.
static var _log_colour: Color = HubBuilder.TRUNK_COLOR

var _flame_texture: Texture2D = null
var _campfires: Dictionary = {}


func _ready() -> void:
	_build()


func _build() -> void:
	_campfires[&"site"] = _build_campfire(
		Vector3(SITE.x, 0.0, SITE.y), SCALE_SITE, "SITE  x%.1f (RECOMMANDE)" % SCALE_SITE)
	_campfires[&"alt"] = _build_campfire(
		Vector3(SITE_ALT.x, 0.0, SITE_ALT.y), SCALE_ALT, "ALT  x%.1f" % SCALE_ALT)


## Published for a probe that needs to switch one instance off and
## re-measure, or read its scale back, rather than guessing node names.
func campfires() -> Dictionary:
	return _campfires.duplicate()


func flame_texture() -> Texture2D:
	if _flame_texture == null:
		_flame_texture = load(FLAME_TEXTURE_PATH) as Texture2D
	return _flame_texture


## One full campfire: a scaled root, the flame billboard, six logs. The
## flame and the logs are both built at NOMINAL size and the whole root is
## uniformly scaled -- so the masking relationship between the flame's
## base and the log pile's height is scale-invariant by construction,
## never re-tuned per instance.
func _build_campfire(origin: Vector3, scale_factor: float, label_text: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire_%s" % label_text.split(" ")[0]
	root.position = origin
	root.scale = Vector3.ONE * scale_factor
	add_child(root)

	for i in LOG_COUNT:
		root.add_child(_make_log(i))

	root.add_child(_make_flame())

	var label := _make_label(label_text)
	label.position = origin + Vector3(0.0, (FLAME_HEIGHT + LOG_APEX_HEIGHT) * scale_factor + 0.35, 0.0)
	add_child(label)

	return root


func _make_log(index: int) -> MeshInstance3D:
	var angle: float = TAU * float(index) / float(LOG_COUNT)
	var base := Vector3(cos(angle) * LOG_RING_RADIUS, LOG_BASE_HEIGHT, sin(angle) * LOG_RING_RADIUS)
	var apex := Vector3(0.0, LOG_APEX_HEIGHT, 0.0)
	var dir: Vector3 = (apex - base).normalized()
	var length: float = base.distance_to(apex)

	var mesh := CylinderMesh.new()
	mesh.top_radius = LOG_RADIUS_TOP
	mesh.bottom_radius = LOG_RADIUS_BOTTOM
	mesh.height = length
	mesh.radial_segments = LOG_RADIAL_SEGMENTS
	mesh.rings = 1

	var basis := Basis(Quaternion(Vector3.UP, dir))
	var node := MeshInstance3D.new()
	node.name = "Log%d" % index
	node.mesh = mesh
	node.transform = Transform3D(basis, base.lerp(apex, 0.5))
	node.set_surface_override_material(0, _unshaded(_log_colour))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _make_flame() -> MeshInstance3D:
	var quad := QuadMesh.new()
	# 415x512 is the reference PNG's opaque bounding box (x[48..462],
	# y[0..511]) -- sizing to ITS aspect, not to a round number, keeps the
	# art from arriving stretched (docs/lots/CH23_FEU_VFX.md, lot 2).
	quad.size = Vector2(FLAME_HEIGHT * (415.0 / 512.0), FLAME_HEIGHT)

	var shader := Shader.new()
	shader.code = FLAME_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("flame", flame_texture())
	mat.set_shader_parameter("pulse_hz", PULSE_HZ)
	mat.set_shader_parameter("pulse_amount", PULSE_AMOUNT)
	mat.set_shader_parameter("sway_hz", SWAY_HZ)
	mat.set_shader_parameter("sway_amount", SWAY_AMOUNT)
	mat.set_shader_parameter("flicker_hz", FLICKER_HZ)
	mat.set_shader_parameter("flicker_amount", FLICKER_AMOUNT)

	var node := MeshInstance3D.new()
	node.name = "Flame"
	node.mesh = quad
	node.set_surface_override_material(0, mat)
	# Base at y=0, same ground height the logs' own base ring sits on --
	# the log pile is what hides the cut, not a lift out of it.
	node.position = Vector3(0.0, FLAME_HEIGHT * 0.5, 0.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Carried over from HubFlameRecon.gd's candidate E, unchanged: alpha
## blend (a flat step must still BE that colour once composited, see the
## file this replaces), Y-locked billboard written by hand because a
## ShaderMaterial never sees StandardMaterial3D's BILLBOARD_FIXED_Y flag.
const FLAME_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D flame : source_color, filter_linear_mipmap;
uniform float pulse_hz = 0.83;
uniform float pulse_amount = 0.085;
uniform float sway_hz = 0.61;
uniform float sway_amount = 0.045;
uniform float flicker_hz = 1.37;
uniform float flicker_amount = 0.11;

void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, up));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float tau = 6.28318530718;
	float v = 1.0 - UV.y;

	float scale = 1.0 + sin(TIME * pulse_hz * tau) * pulse_amount;
	float sv = v / scale;

	float sway = sin(TIME * sway_hz * tau + sv * 3.4) * sway_amount * sv * sv;

	vec2 uv = vec2(UV.x + sway, 1.0 - sv);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;
	}
	vec4 texel = texture(flame, uv);
	if (texel.a < 0.02) {
		discard;
	}

	float flicker = 1.0 + sin(TIME * flicker_hz * tau + 1.7) * flicker_amount;
	ALBEDO = texel.rgb * flicker;
	ALPHA = texel.a;
}
"""


func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material


func _make_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.0013
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.shaded = false
	label.double_sided = true
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.94, 0.72)
	label.outline_modulate = Color(0.03, 0.05, 0.02, 1.0)
	label.outline_size = 18
	return label
