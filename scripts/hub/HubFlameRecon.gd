extends Node3D
class_name HubFlameRecon
## RECON, not a feature -- LOT 2. Stands the three flame candidates the
## brief names side by side on the plateau so Mathieu can arbitrate them on
## an iPhone, which is the only place the visual question can be answered.
## Nothing here is tappable, nothing poses Keepy, nothing is definitive.
##
## =====================================================================
## WHAT LOT 1 SETTLED, AND IS NOT RE-MEASURED HERE
##
## `GPUParticles3D` IS functional under the Compatibility renderer on
## Safari iOS / WebGL2 -- verified by Mathieu ON DEVICE on 04/09/2026.
## That is a reusable project-wide fact, recorded in
## docs/lots/CH23_FEU_VFX.md, and NOT a licence to re-open the question.
##
## Lot 1's three candidates -- A GPU, B CPU, C SHEET -- are GONE from this
## file. None of them produced the illustrated style the brief asks for, so
## keeping them would spend three slots of Mathieu's attention on answers
## already given. What survives them is their measured site clearance,
## reused below rather than re-walked.
##
## =====================================================================
## THE SITE IS GIVEN, NOT DERIVED -- AND THE THREE SLOTS ARE NOT EQUAL
##
## (19.9, 25.4) was read off the device by Mathieu through HubWorld's
## position overlay. Lot 1 measured the clearance around it as the XZ
## convex hull of the eight transformed corners of every drawn piece:
##
##   slot WEST   (17.9, 25.4)  3.575 u clear
##   site CENTRE (19.9, 25.4)  3.521 u clear
##   slot EAST   (21.9, 25.4)  1.676 u clear   <- THE TIGHT ONE
##
## ⚠️ The nearest neighbour in every case is a TreeCrown, and at the EAST
## slot it is 1.676 u away instead of ~3.5. Whoever stands there is read
## against a NEARER, BUSIER backdrop than the other two. That is a bias in
## the comparison, not a bug, and it cannot be removed without moving the
## site Mathieu chose -- so it is DECLARED instead: the slot order below is
## fixed and published, and the lot report names who draws the short straw.
##
## =====================================================================
## WHY THE PALETTE IS MEASURED OFF MATHIEU'S OWN REFERENCE
##
## D1 and D2 do not invent a flame ramp. Their four steps are the four
## dominant colour buckets of assets/textures/props/campfire_flame.png,
## measured on its 120 301 opaque pixels (16-level cube, see the lot
## report). Candidate E draws that same PNG directly. So hue is HELD
## CONSTANT across the three, and what differs between them is the thing
## the comparison is actually about.
##
## ⚠️ ONE CONFOUND SURVIVES AND MUST NOT BE SWEPT UNDER: the reference PNG
## is a CONTINUOUS GRADIENT -- 10 200 distinct opaque colours, warming
## smoothly from #F75C2C at its top to #FDD850 at its base. D1/D2 quantise
## into four flat steps because the brief asks for flat steps; E cannot,
## because that would mean rewriting Mathieu's asset. So "flat vs gradient"
## and "procedural silhouette vs fixed silhouette" arrive in ONE image.
## They are two questions. The report says so; this file will not pretend
## a single verdict answers both.

## The point Mathieu relayed from device. ONE spelling, read by the builder
## and by the labels alike.
const SITE: Vector2 = Vector2(19.9, 25.4)

## Gap between candidates. The brief's "environ 2 u", kept literal.
const SPACING: float = 2.0

## How tall a candidate flame stands and how wide its quad is. Recon
## values: lot 3 sizes the real fire against real logs, which do not exist
## yet. Held IDENTICAL across the three so a size difference can never be
## mistaken for a technique difference.
const FLAME_HEIGHT: float = 1.15
const FLAME_WIDTH: float = 0.72

## Height of the floating label above each candidate.
const LABEL_HEIGHT: float = 1.95

## The reference texture. Mathieu's asset, read and never written.
const FLAME_TEXTURE_PATH: String = "res://assets/textures/props/campfire_flame.png"

## =====================================================================
## THE FOUR STEPS -- MEASURED, NOT CHOSEN
##
## Each is the mean of one dominant bucket of campfire_flame.png, with its
## share of the opaque body and its relative luminance:
##
##   CORE  #FEF175  (254,241,117)   3.4%   L = 0.8527
##   HOT   #FED847  (254,216, 71)   6.6%   L = 0.7064
##   MID   #FD9625  (253,150, 37)   9.5%   L = 0.4283
##   EDGE  #F95B25  (249, 91, 37)  19.8%   L = 0.2776   <- most common
##
## ⚠️ Against the hub floor's RENDERED L = 0.0799 (CLAUDE.md, hub -- not
## the Chased floor's 0.150), the first three clear 3.0:1 (6.95, 5.82,
## 3.68) and EDGE does NOT: 2.52:1. That is a property of the reference
## art, not of a decision made here, and it is reported rather than
## quietly corrected -- correcting it would mean D no longer matches the
## PNG E draws, which is the one thing holding this comparison together.
## =====================================================================
const STEP_CORE: Color = Color(0.996, 0.945, 0.459)
const STEP_HOT: Color = Color(0.996, 0.847, 0.278)
const STEP_MID: Color = Color(0.992, 0.588, 0.145)
const STEP_EDGE: Color = Color(0.976, 0.357, 0.145)

## =====================================================================
## THE AXIS THAT SEPARATES D1 FROM D2 -- named, because the brief asks
##
## The chosen axis is NOT speed. It is HOW FAR THE NOISE IS ALLOWED TO
## BREAK THE SILHOUETTE, because that is the only thing a procedural
## flame can do that a billboard structurally cannot: a tongue that is
## born, detaches, floats free and dies. Speed rides along with it --
## a detached tongue that does not travel reads as a rendering bug rather
## than as fire -- but fragmentation is the variable, and it is the one
## Mathieu is actually being asked to arbitrate.
##
##   D1 "unie"     -- low turbulence. The teardrop stays ONE body; the
##                    noise only nibbles its upper contour. Closest to
##                    clipart, and the safest bet against E.
##   D2 "nerveuse" -- high turbulence. Tongues genuinely separate from
##                    the body and rise alone. Furthest from clipart,
##                    and the only one of the three that can ever look
##                    like a fire rather than like a drawing of one.
##
## Everything else about them -- palette, size, band count, cut, the
## shader itself -- is byte-identical. Two uniforms differ.
## =====================================================================
const D1_TURBULENCE: float = 0.34
const D1_RISE: float = 0.42
const D2_TURBULENCE: float = 0.82
const D2_RISE: float = 0.86

## Candidate E's motion, all of it. Amplitudes are deliberately small:
## the brief's premise is that E's SILHOUETTE does not change, so a shader
## that visibly warped it would be answering a different question.
const E_PULSE_HZ: float = 0.83      ## vertical scale breathing
const E_PULSE_AMOUNT: float = 0.085 ## +/- 8.5% of height
const E_SWAY_HZ: float = 0.61       ## horizontal ripple, growing upward
const E_SWAY_AMOUNT: float = 0.045  ## in UV, at the tip
const E_FLICKER_HZ: float = 1.37    ## brightness
const E_FLICKER_AMOUNT: float = 0.11

var _candidates: Dictionary = {}
var _flame_texture: Texture2D = null


func _ready() -> void:
	_build()


## The three candidates, west to east, in the order the labels announce.
## ⚠️ D2 takes the EAST slot -- the 1.676 u one. Deliberate and declared:
## D2 is the candidate whose whole claim is that its tongues LEAVE the
## body, so it is the one that most needs to be seen against a near
## backdrop. Putting the safest candidate there instead would have hidden
## the failure mode the comparison exists to find.
func _build() -> void:
	var slots: Array[Dictionary] = [
		{"key": &"d1", "label": "D1 UNIE"},
		{"key": &"e", "label": "E SPRITE"},
		{"key": &"d2", "label": "D2 NERVEUSE"},
	]
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var offset: float = (float(i) - 1.0) * SPACING
		var root := Node3D.new()
		root.name = "Flame_%s" % slot["key"]
		root.position = Vector3(SITE.x + offset, 0.0, SITE.y)
		add_child(root)
		match slot["key"]:
			&"d1":
				root.add_child(_make_procedural("D1", D1_TURBULENCE, D1_RISE, 0.0))
			&"d2":
				# A phase offset, so two instances of one shader standing
				# 4 u apart are never caught mid-frame in lockstep.
				root.add_child(_make_procedural("D2", D2_TURBULENCE, D2_RISE, 13.7))
			&"e":
				root.add_child(_make_sprite())
		root.add_child(_make_label(slot["label"]))
		_candidates[slot["key"]] = root


## The candidates, by key, for a probe that needs to switch one off and
## re-measure. Published rather than re-walked from node names: a reader
## that guesses a name gets a null and a green run that measured nothing.
func candidates() -> Dictionary:
	return _candidates.duplicate()


## The reference texture, loaded ONCE and shared. Published so a probe
## measures the texel density of the SAME texture the scene draws rather
## than of one it loaded itself.
func flame_texture() -> Texture2D:
	if _flame_texture == null:
		_flame_texture = load(FLAME_TEXTURE_PATH) as Texture2D
	return _flame_texture


# =====================================================================
# CANDIDATES D1 / D2 -- one procedural shader, two settings
# =====================================================================
func _make_procedural(tag: String, turbulence: float, rise: float, phase: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(FLAME_WIDTH, FLAME_HEIGHT)

	var shader := Shader.new()
	shader.code = PROCEDURAL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("step_core", STEP_CORE)
	mat.set_shader_parameter("step_hot", STEP_HOT)
	mat.set_shader_parameter("step_mid", STEP_MID)
	mat.set_shader_parameter("step_edge", STEP_EDGE)
	mat.set_shader_parameter("turbulence", turbulence)
	mat.set_shader_parameter("rise", rise)
	mat.set_shader_parameter("phase", phase)

	var node := MeshInstance3D.new()
	node.name = "Flame%s" % tag
	node.mesh = quad
	node.set_surface_override_material(0, mat)
	node.position = Vector3(0.0, FLAME_HEIGHT * 0.5, 0.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## ⚠️ `blend_mix`, NOT `blend_add` -- and this is the single most
## consequential line in the file.
##
## Lot 1's candidates were additive, which is the physically flattering
## choice for fire and the WRONG one here: additive blending sums the
## flame into whatever is behind it, so a "flat step" stops being flat the
## moment the backdrop changes brightness, and two of the four steps wash
## toward white. The brief asks for FRANC FLAT AREAS. Only an alpha blend
## can put a measured colour on screen and have it still BE that colour.
## Candidate E is alpha-blended for the same reason.
##
## ⚠️ `cull_disabled` here sits on a FLAT QUAD, never a closed body, so the
## back-face-repaints-the-front failure CLAUDE.md records for the water
## shader cannot occur: there is no second surface to repaint the first.
## `depth_draw_never` is stated rather than inherited -- CLAUDE.md records
## that writing ALPHA already costs the depth write, so saying it out loud
## costs nothing and stops a reader from assuming otherwise.
const PROCEDURAL_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 step_core : source_color;
uniform vec4 step_hot : source_color;
uniform vec4 step_mid : source_color;
uniform vec4 step_edge : source_color;
uniform float turbulence = 0.34;
uniform float rise = 0.42;
uniform float phase = 0.0;

// Value noise on a hash. Two octaves, and the count is deliberate: this
// shader runs PER PIXEL and the lot measures its fill cost, so a third
// octave is a decision with a price rather than a free improvement.
float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.56);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	// Y-locked billboard: yaw follows the camera, the flame stays upright.
	// Written out rather than taken from BILLBOARD_FIXED_Y because a
	// ShaderMaterial never sees that StandardMaterial3D flag.
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 fwd = normalize(cross(right, up));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	// v = 0 at the base of the quad, 1 at the tip. UV.y runs the other way.
	float v = 1.0 - UV.y;
	float u = UV.x - 0.5;

	// The body: a teardrop, fattest a third of the way up, pinched at both
	// ends. This is the silhouette the noise is then allowed to eat into.
	float half_w = sin(pow(max(v, 0.0), 0.62) * 3.14159265) * 0.46 * (1.0 - v * 0.30);
	if (half_w <= 0.0005) {
		discard;
	}

	// Noise ADVECTED UPWARD. This -- and only this -- is what makes a
	// tongue be born low, travel, and die high: a given noise cell moves
	// up the quad while the threshold it must clear also rises with v.
	float t = TIME * rise + phase;
	vec2 q = vec2(u * 4.2, v * 3.1 - t);
	float n = vnoise(q) * 0.65 + vnoise(q * 2.3 + vec2(11.0, 7.0)) * 0.35;

	float radial = 1.0 - clamp(abs(u) / half_w, 0.0, 1.0);
	float fuel = 1.0 - v;

	// heat carries the noise MULTIPLICATIVELY, so where the noise dips the
	// flame does not merely dim -- it falls below the cut and the body
	// SPLITS. Additive noise would only have shaded it.
	float heat = radial * fuel * mix(1.0, n * 2.0, clamp(turbulence, 0.0, 1.0));

	// FOUR HARD STEPS. No smoothstep anywhere below this line: a
	// smoothstep is exactly the continuous gradient the brief rules out.
	if (heat < 0.055) {
		discard;
	}
	vec3 col;
	if (heat < 0.16) {
		col = step_edge.rgb;
	} else if (heat < 0.34) {
		col = step_mid.rgb;
	} else if (heat < 0.58) {
		col = step_hot.rgb;
	} else {
		col = step_core.rgb;
	}
	ALBEDO = col;
	ALPHA = 1.0;
}
"""


# =====================================================================
# CANDIDATE E -- Mathieu's PNG on a billboard, moved by shader
#
# The silhouette does NOT change shape. That is assumed, it is the whole
# premise of this candidate, and it is what the comparison must settle:
# whether a drawing that breathes reads better on this plateau than a
# procedural fire that genuinely moves.
# =====================================================================
func _make_sprite() -> MeshInstance3D:
	# The PNG is 512x512 and its opaque body spans x[48..462], y[0..511] --
	# 415 x 512, so it is very nearly square and the quad is sized to the
	# TEXTURE's aspect rather than to D's, or the reference art would arrive
	# stretched and the comparison would be about the stretch.
	var quad := QuadMesh.new()
	quad.size = Vector2(FLAME_HEIGHT * (415.0 / 512.0), FLAME_HEIGHT)

	var shader := Shader.new()
	shader.code = SPRITE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("flame", flame_texture())
	mat.set_shader_parameter("pulse_hz", E_PULSE_HZ)
	mat.set_shader_parameter("pulse_amount", E_PULSE_AMOUNT)
	mat.set_shader_parameter("sway_hz", E_SWAY_HZ)
	mat.set_shader_parameter("sway_amount", E_SWAY_AMOUNT)
	mat.set_shader_parameter("flicker_hz", E_FLICKER_HZ)
	mat.set_shader_parameter("flicker_amount", E_FLICKER_AMOUNT)

	var node := MeshInstance3D.new()
	node.name = "FlameE"
	node.mesh = quad
	node.set_surface_override_material(0, mat)
	node.position = Vector3(0.0, FLAME_HEIGHT * 0.5, 0.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## ⚠️ The three frequencies are 0.83 / 0.61 / 1.37 Hz and their ratios are
## deliberately not small integers: three motions on commensurable
## frequencies re-synchronise on a short cycle, and a fire that visibly
## repeats every two seconds is a fire a player stops believing. That is
## the brief's "phases desynchronisees", spelled as numbers.
const SPRITE_SHADER: String = """
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
	// v = 0 at the base, 1 at the tip -- same convention as the procedural
	// shader, so the two files read the same way.
	float v = 1.0 - UV.y;

	// 1. Vertical breathing, ABOUT THE BASE. Scaling about the centre
	//    would lift the flame off its logs every other second.
	float scale = 1.0 + sin(TIME * pulse_hz * tau) * pulse_amount;
	float sv = v / scale;

	// 2. Horizontal ripple, growing toward the tip. v*v rather than v:
	//    the foot of a fire is pinned by its fuel, the tip is not.
	float sway = sin(TIME * sway_hz * tau + sv * 3.4) * sway_amount * sv * sv;

	vec2 uv = vec2(UV.x + sway, 1.0 - sv);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		discard;
	}
	vec4 texel = texture(flame, uv);
	if (texel.a < 0.02) {
		discard;
	}

	// 3. Brightness. Multiplicative and small: the reference art already
	//    carries its own gradient and this must not re-grade it.
	float flicker = 1.0 + sin(TIME * flicker_hz * tau + 1.7) * flicker_amount;
	ALBEDO = texel.rgb * flicker;
	ALPHA = texel.a;
}
"""


# =====================================================================
# Shared pieces
# =====================================================================

## A floating name over each candidate, because a comparison a reader
## cannot label is three fires and a guess.
## ⚠️ Lot 1 needed a per-candidate lift because two of its captions
## OVERLAPPED at 2 u apart. That lift is GONE here on purpose: the three
## names now differ in length and in first character ("D1", "E", "D2"), so
## a row read at a glance is unambiguous without a staircase. If a device
## capture shows them colliding again, the lift comes back -- but a
## staircase that is not needed makes the row look like it means something.
func _make_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.name = "Label"
	label.text = text
	label.font_size = 96
	label.pixel_size = 0.0013
	label.position = Vector3(0.0, LABEL_HEIGHT, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.shaded = false
	label.double_sided = true
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.94, 0.72)
	label.outline_modulate = Color(0.03, 0.05, 0.02, 1.0)
	label.outline_size = 18
	return label
