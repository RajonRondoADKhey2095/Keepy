extends Node3D
class_name HubCampfire
## The real campfire prop -- LOT 3 of CH23 shipped it (E sprite billboard +
## six real crossed logs, x1.6). LOT 4 fixes what device caught: the flame
## read as PLANTED BEHIND the logs rather than jaillissant FROM them.
##
## ⚠️ WHY LOT 3'S OWN "0 LEAK" MEASUREMENT DIDN'T CATCH THIS -- THE METRIQUE
## WAS THE WRONG ONE, THE CLAUDE.md PATTERN NAMED "LA MÉTRIQUE PEUT ÊTRE LA
## MAUVAISE, ET LE CHIFFRE VERT AVEC"
##
## Lot 3 measured only whether the texture's literal hard-cut LAST ROW
## (v < 0.06, ~0.08 u wide at x1.6) leaked past the logs -- it never does,
## because that sliver is almost a point. What Mathieu saw on device was
## never that sliver: it is that campfire_flame.png flares from ~0.08 u to
## ~0.7-0.9 u wide within the bottom ~10-15 cm of its own height (measured
## on the source PNG, not assumed -- see docs/lots/CH23_FEU_VFX.md lot 4),
## while the old log pile's apex (LOG_APEX_HEIGHT 0.44 nominal, 0.70 u at
## x1.6) sat at a height where the flame was ALREADY near its widest belly
## and the logs had ALREADY tapered to nothing. The two shapes crossed at
## almost the top of the pile instead of staying nested through its whole
## height -- which reads exactly like "flame behind logs", because for
## most of the log pile's own height range the flame genuinely was wider
## than the wood that was supposed to be hiding it.
##
## This lot's fix is not "raise the logs" (already tried on paper, made it
## worse: the pile just gets a taller silhouette) -- it is LOWER AND
## WIDER logs (short, splayed pile the flame can nest inside end to end)
## plus a SINK on the flame itself (its literal cut is now driven a few
## centimetres BELOW y=0, buried behind the opaque Ground plane as a second,
## independent line of defence -- see docs/lots/CH23_FEU_VFX.md lot 4 for
## why a point below grade is provably occluded by the flat Ground mesh on
## this camera, not merely assumed). Verified by the same isolation-mask
## render technique lot 3 used, but against a MUST-COVER band matched to
## where the texture is actually wide, not the thin cut alone -- see the
## report for the numbers.
##
## The fire is ALWAYS LIT. No tap, no Area3D, no ignition state, no
## persistence -- Mathieu's decision, unchanged since lot 3.
## =====================================================================
const SITE: Vector2 = Vector2(19.9, 25.4)

## Echelle x1.6 is Mathieu's already-settled call from lot 3 (NOT reopened
## here) -- ONE scale now, shared by both variants below. What lot 4 puts
## up for arbitration is no longer scale, it is how far the flame sinks
## into the log pile.
const SCALE: float = 1.6

const FLAME_HEIGHT: float = 1.15
const FLAME_TEXTURE_PATH: String = "res://assets/textures/props/campfire_flame.png"

## Candidate E's motion, carried over byte-for-byte from lot 2/3: the brief
## did not ask this lot to re-tune it, only to fix the log/flame overlap.
const PULSE_HZ: float = 0.83
const PULSE_AMOUNT: float = 0.085
const SWAY_HZ: float = 0.61
const SWAY_AMOUNT: float = 0.045
const FLICKER_HZ: float = 1.37
const FLICKER_AMOUNT: float = 0.11

## =====================================================================
## LOGS -- crossed cylinders, never a billboard (unchanged reasoning from
## lot 3: a billboard log would spin to face the camera exactly like the
## flame, and a rotating log betrays the drawing the instant the camera's
## relative angle changes).
##
## Geometry that DOESN'T vary by variant: count, taper radii, segments.
## =====================================================================
## COUNT and RADII went up from lot 3's 6 / 0.045-0.065: the first render
## pass of this lot (docs/lots/CH23_FEU_VFX.md lot 4) measured that a
## sparse ring of thin sticks leaves real angular GAPS between individual
## logs that a continuous-envelope model on paper does not see -- 19 of
## 24 sampled views leaked on the must-cover band with the thin/sparse
## geometry, at azimuths on AND off the logs' own angular positions alike.
## Eight thicker logs close those gaps; verified by re-render, not assumed
## a second time.
const LOG_COUNT: int = 8
const LOG_RADIUS_TOP: float = 0.075
const LOG_RADIUS_BOTTOM: float = 0.12
const LOG_RADIAL_SEGMENTS: int = 6

## Revert LOT 5 (CH23) : l'éclaircissement du lot 4 était une demande
## erronée de Mathieu, pas un défaut constaté -- le rendu sombre qu'il
## avait pris pour un problème de matériau était en réalité le défaut
## d'imbrication flamme/bûches, corrigé au lot 4 par la géométrie seule
## (bûcher bas/étalé, flame_sink). Retour au matériau des troncs du hub,
## tel qu'il était avant le lot 4. Aucun plancher de contraste ne
## s'applique à ce prop décoratif (CLAUDE.md, hors sujet pour un feu).
const LOG_COLOUR: Color = HubBuilder.TRUNK_COLOR

## =====================================================================
## UNE SEULE INSTANCE -- LOT 5 (CH23) retire la variante ALT/PRUDENT
## (arbitrage tranché par Mathieu en faveur d'IMMERGE) et son Label3D,
## ainsi que le Label3D d'IMMERGE : plus aucune étiquette sur ce prop.
##
## Géométrie et flame_sink inchangés depuis le lot 4 (validés device) :
## ring 0.42, apex 0.22, flame_sink 0.08 (nominal, pré-échelle).
## =====================================================================
const VARIANT_IMMERGE: Dictionary = {
	"label": "IMMERGE (RECOMMANDE)",
	"ring_radius": 0.42,
	"base_height": 0.04,
	"apex_height": 0.22,
	"flame_sink": 0.08,
}

var _flame_texture: Texture2D = null
var _campfires: Dictionary = {}


func _ready() -> void:
	_build()


func _build() -> void:
	_campfires[&"immerge"] = _build_campfire(Vector3(SITE.x, 0.0, SITE.y), VARIANT_IMMERGE)


## Published for a probe that needs to switch one instance off and
## re-measure, or read its scale/variant back, rather than guessing node
## names.
func campfires() -> Dictionary:
	return _campfires.duplicate()


func flame_texture() -> Texture2D:
	if _flame_texture == null:
		_flame_texture = load(FLAME_TEXTURE_PATH) as Texture2D
	return _flame_texture


## One full campfire: a scaled root, eight logs at the variant's own
## nominal geometry, the flame billboard sunk by the variant's own
## nominal amount. Logs and flame are built at NOMINAL size and the whole
## root is uniformly scaled by SCALE -- so every ratio below is
## scale-invariant by construction.
func _build_campfire(origin: Vector3, variant: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire_%s" % String(variant["label"]).split(" ")[0]
	root.position = origin
	root.scale = Vector3.ONE * SCALE
	add_child(root)

	var ring_radius: float = variant["ring_radius"]
	var base_height: float = variant["base_height"]
	var apex_height: float = variant["apex_height"]
	var sink: float = variant["flame_sink"]

	for i in LOG_COUNT:
		root.add_child(_make_log(i, ring_radius, base_height, apex_height))

	root.add_child(_make_flame(sink))

	return root


func _make_log(index: int, ring_radius: float, base_height: float, apex_height: float) -> MeshInstance3D:
	var angle: float = TAU * float(index) / float(LOG_COUNT)
	var base := Vector3(cos(angle) * ring_radius, base_height, sin(angle) * ring_radius)
	var apex := Vector3(0.0, apex_height, 0.0)
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
	node.set_surface_override_material(0, _unshaded(LOG_COLOUR))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _make_flame(sink: float) -> MeshInstance3D:
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
	# Base at y = -sink (nominal, pre-scale): lot 3 put it at y=0, flush
	# with the log ring's own base. Lot 4 sinks it by `sink` so the
	# texture's literal hard cut lands BELOW ground (occluded by the
	# opaque Ground plane, verified not assumed -- see the report) and the
	# row that lands exactly at y=0 is already partway up the texture's
	# flare rather than its single narrowest pixel.
	node.position = Vector3(0.0, FLAME_HEIGHT * 0.5 - sink, 0.0)
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
