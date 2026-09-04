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

## Revert LOT 5 (CH23), attribution rectifiée au LOT 6 : l'éclaircissement
## du lot 4 ne venait PAS de Mathieu -- il n'a jamais rien demandé sur la
## couleur des bûches. C'était une correction ESTHÉTIQUE NON DEMANDÉE,
## glissée dans un correctif technique, lui, réellement demandé
## (l'imbrication flamme/bûches). Le rendu sombre n'était pas un défaut de
## matériau : c'était le défaut d'imbrication, corrigé au lot 4 par la
## géométrie seule (bûcher bas/étalé, flame_sink). Retour au matériau des
## troncs du hub, tel qu'il était avant le lot 4. Aucun plancher de
## contraste ne s'applique à ce prop décoratif (CLAUDE.md, hors sujet).
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

## =====================================================================
## LOT 6 (CH23) -- LE CERCLE DE PIERRES
##
## Le feu lui-même est CLOS et validé device : rien au-dessus de cette
## ligne n'est touché par ce lot. L'anneau s'ajoute AUTOUR.
##
## ⚠️ COMMENT LES ROCHERS DU HUB SONT POSÉS -- MESURÉ, PAS SUPPOSÉ
## (CampfireStoneRecon, sonde jetable du lot 6, sous xvfb + opengl3) :
## les 48 rochers gris sont UN MultiMesh partagé `Rock` accroché à
## `Props`, TRANSFORM_3D, `SphereMesh` r=0,6 h=0,8 seg=8 rings=4,
## `material_override` = `HubBuilder.ROCK_COLOR` unshaded. ZÉRO nœud
## individuel ne dessine ce mesh (les deux seuls nœuds à ROCK_COLOR sont
## le socle du tourniquet et le pivot de la balançoire).
##
## ⚠️ ET ON NE PEUT PAS AJOUTER D'INSTANCES À CE BATCH PARTAGÉ.
## Mesuré, pas raisonné : porter `instance_count` de 48 à 49 a rendu
## **0 transform sur 48** survivantes -- le buffer est réalloué et remis
## à zéro -- et `custom_aabb` ne suit pas. Un appelant extérieur devrait
## donc ré-écrire tout le semis procédural de HubBuilder et lui
## recalculer son AABB : c'est-à-dire posséder ses données.
##
## D'où le choix retenu : l'anneau porte SON PROPRE MultiMesh, avec le
## MESH et la COULEUR du rocher du hub (`HubBuilder.rock_mesh()` et
## `HubBuilder.ROCK_COLOR`, lus, jamais retapés), parenté sous la racine
## du feu. C'est exactement le patron déjà documenté dans HubLayout.gd
## pour les barres du tourniquet -- « un MultiMesh à lui, jamais un batch
## partagé » -- et les batches `Bars` (n=4) et `Grips` (n=2) relevés par
## la recon en sont la preuve vivante.
##
## ⚠️ IRRÉGULIER NE VEUT PAS DIRE ALÉATOIRE. Décision de Mathieu : un
## foyer est un objet FAIT MAIN, donc ça reste un CERCLE. Varient la
## TAILLE, l'ESPACEMENT angulaire, la ROTATION et l'ASSIETTE de chaque
## pierre. Le RAYON, lui, est STRICTEMENT constant -- pas « à peu près »,
## littéralement le même nombre pour les huit pierres des deux variantes,
## et la sonde l'assert à 0,000 u de variance. Une pierre plus loin ou
## plus près donnerait un semis, pas un foyer.
##
## ⚠️ UNE SPHÈRE DE RÉVOLUTION NE TOURNE PAS. Le mesh du rocher est une
## `SphereMesh` : un yaw seul n'y change PAS UN PIXEL -- c'est la leçon
## A3 de l'audit CH22, déjà payée sur le semis. Chaque pierre reçoit donc
## une compression NON UNIFORME écrite dans le repère du MODÈLE, puis
## l'assiette, puis le yaw -- via `Transform3D.scaled_local()`, qui
## post-multiplie (basis * S). L'ordre EST la correction : un
## `Transform3D.scaled()` pré-multiplierait, écraserait selon les axes
## MONDE, et le yaw redeviendrait un no-op silencieux.
##
## ⚠️ DÉTERMINISTE, JAMAIS DE RNG AU RUNTIME LIBRE. Chaque variante a sa
## graine entière fixe et tire dans un ordre fixe : le foyer est
## identique à chaque chargement, comme `_prop_distortion()` le fait déjà
## pour le semis.
##
## Les pierres REPOSENT AU SOL, partiellement enfoncées : l'enfouissement
## est une FRACTION de la hauteur réellement dessinée de chaque pierre,
## calculée sur son AABB une fois l'assiette et la compression
## appliquées -- pas un offset copié, parce que ce dépôt a déjà enterré
## un personnage sous 68 % de sa taille en recopiant une moitié de somme.
## =====================================================================

const STONE_COUNT: int = 8

## Nominal (pré-SCALE), comme toute la géométrie de ce fichier.
##
## Le rayon est CONTRAINT PAR LES DEUX BOUTS, et les deux bornes sont
## mesurées :
##   - dedans : l'emprise XZ réelle du feu construit vaut 0,772 u en
##     MONDE (lot 4, reproduite par la sonde du lot 6 au millième). Les
##     pierres doivent l'englober SANS LA TOUCHER.
##   - dehors : le second foyer d'arbitrage est à 3,40 u, au meilleur
##     créneau de MÊME PROFONDEUR CAMÉRA disponible (dégagement 2,258 u),
##     donc l'emprise extérieure de l'anneau doit rester nettement sous
##     1,70 u pour que les deux anneaux ne se rejoignent pas.
## 0,7625 nominal = 1,220 u monde : bord intérieur 0,911 u au pire
## (0,139 u de jeu sur le feu), bord extérieur 1,529 u au pire.
const STONE_RING_RADIUS: float = 0.7625

## Facteur appliqué au mesh du rocher du hub (rayon 0,6). 0,2552 nominal
## donne une pierre de 0,245 u de rayon en monde, soit 0,49 u de large --
## un galet, pas un bloc : le sommet reste sous l'apex du bûcher
## (0,352 u monde), pour que les pierres n'avalent pas le bois.
const STONE_MESH_SCALE: float = 0.2552

## Part de la hauteur dessinée de chaque pierre qui passe sous y = 0.
const STONE_BURIED_FRACTION: float = 0.26

## =====================================================================
## LES DEUX VARIANTES À ARBITRER -- elles diffèrent SEULEMENT par le
## DEGRÉ d'irrégularité. Même compte, même rayon, même mesh, même
## couleur, même enfouissement.
##
## Le lot 7 conserve celle que Mathieu retient et supprime l'autre ainsi
## que les deux Label3D.
## =====================================================================
const STONES_SOBRE: Dictionary = {
	"seed": 20260904,
	"size_min": 0.92,
	"size_max": 1.08,
	"angle_jitter_deg": 3.5,
	"tilt_max_deg": 4.0,
	"squash_xz_min": 0.88,
	"squash_y_min": 0.86,
	"squash_y_max": 1.06,
}

const STONES_MARQUE: Dictionary = {
	"seed": 20260906,
	"size_min": 0.74,
	"size_max": 1.26,
	"angle_jitter_deg": 12.0,
	"tilt_max_deg": 11.0,
	"squash_xz_min": 0.76,
	"squash_y_min": 0.72,
	"squash_y_max": 1.14,
}

## Le second site d'arbitrage. 3,40 u à l'ouest du site, sur le MÊME z --
## la caméra ne tourne jamais et le brouillard est exponentiel en
## distance, donc deux foyers à des profondeurs différentes ne sont pas
## comparables. Balayé (72 azimuts x 6 distances de 3,40 à 3,90 u,
## `HubRegion.contains` compris) : c'est le point de même profondeur au
## meilleur dégagement, 2,258 u contre 3,521 u au site.
const SITE_ALT: Vector2 = Vector2(16.5, 25.4)

var _flame_texture: Texture2D = null
var _campfires: Dictionary = {}


func _ready() -> void:
	_build()


func _build() -> void:
	_campfires[&"marque"] = _build_campfire(
		Vector3(SITE.x, 0.0, SITE.y), VARIANT_IMMERGE, STONES_MARQUE, "MARQUE")
	_campfires[&"sobre"] = _build_campfire(
		Vector3(SITE_ALT.x, 0.0, SITE_ALT.y), VARIANT_IMMERGE, STONES_SOBRE, "SOBRE")


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
func _build_campfire(origin: Vector3, variant: Dictionary, stones: Dictionary,
		label_text: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire_%s" % label_text
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
	root.add_child(_make_stone_ring(stones))

	# LOT 6 only, for the arbitration. The label hangs off THIS node, not
	# off the scaled root, so its size does not ride SCALE -- same shape
	# lot 3/4 used. The lot 7 that keeps one variant deletes both.
	var label := _make_label(label_text)
	label.position = origin + Vector3(0.0, (FLAME_HEIGHT + apex_height) * SCALE + 0.35, 0.0)
	add_child(label)

	return root


## The ring of stones, as ONE MultiMesh of its own carrying the hub's own
## rock mesh and colour. Parented under the campfire root, so it rides
## SCALE exactly like the logs and the flame do and every number below
## stays nominal.
func _make_stone_ring(stones: Dictionary) -> MultiMeshInstance3D:
	var mesh: SphereMesh = HubBuilder.rock_mesh()
	var local_aabb: AABB = mesh.get_aabb()
	# The drawn surface, for the burial below -- an AABB is the wrong
	# instrument for a body that is tilted and squashed, see _make_stone_ring's
	# note. Read once, outside the loop.
	var verts: PackedVector3Array = mesh.get_faces()

	var rng := RandomNumberGenerator.new()
	rng.seed = int(stones["seed"])
	var size_min: float = stones["size_min"]
	var size_max: float = stones["size_max"]
	var jitter: float = stones["angle_jitter_deg"]
	var tilt_max: float = stones["tilt_max_deg"]
	var squash_xz_min: float = stones["squash_xz_min"]
	var squash_y_min: float = stones["squash_y_min"]
	var squash_y_max: float = stones["squash_y_max"]

	var xforms: Array[Transform3D] = []
	for i in STONE_COUNT:
		# Drawn in a FIXED order from a FIXED seed: the foyer is identical
		# at every load, and adding a draw here would reshuffle every
		# stone after it -- which is why the order is not rearranged
		# casually.
		var angle: float = TAU * float(i) / float(STONE_COUNT) \
			+ deg_to_rad(rng.randf_range(-jitter, jitter))
		var size: float = rng.randf_range(size_min, size_max)
		var fx: float = rng.randf_range(squash_xz_min, 1.0)
		var fz: float = rng.randf_range(squash_xz_min, 1.0)
		var fy: float = rng.randf_range(squash_y_min, squash_y_max)
		var yaw: float = rng.randf_range(0.0, TAU)
		var tilt_axis: float = rng.randf_range(0.0, TAU)
		var tilt: float = deg_to_rad(rng.randf_range(0.0, tilt_max))

		# ⚠️ XZ IS CAPPED AT 1.0, like HubBuilder's own prop distortion:
		# the outer emprise this file publishes is size * STONE_MESH_SCALE,
		# and letting a stone stretch PAST that would turn a declared
		# bound into a lower bound, silently.
		var factor: float = STONE_MESH_SCALE * size
		var squash := Vector3(factor * fx, factor * fy, factor * fz)

		# yaw * tilt, then scaled_local post-multiplies the squash ->
		# squash in the MODEL frame, tilted, then turned. Basis has no
		# scaled_local() in 4.3 (it is a Parse Error), which is why this
		# goes through Transform3D.
		var basis := Basis(Vector3.UP, yaw) \
			* Basis(Vector3(cos(tilt_axis), 0.0, sin(tilt_axis)).normalized(), tilt)
		var at := Vector3(cos(angle) * STONE_RING_RADIUS, 0.0, sin(angle) * STONE_RING_RADIUS)
		var xform := Transform3D(basis, at).scaled_local(squash)

		# Settle it into the ground on ITS OWN drawn height.
		#
		# ⚠️ ON THE REAL VERTICES, NOT ON A TRANSFORMED AABB. The first
		# version of this line took the AABB of the transformed AABB, and
		# the probe measured what that costs: a BOX tilted 11 degrees has
		# a taller bounding box than the body inside it, so the burial
		# came out at 0.162 to 0.257 instead of the 0.26 asked for -- a
		# different, wrong depth for every stone, and none of them the
		# intended one. Nothing raises on that; the stones simply sit a
		# little high, by an amount that varies with their tilt.
		var lo: float = INF
		for v in verts:
			lo = minf(lo, (Transform3D(xform.basis, Vector3.ZERO) * v).y)
		var hi: float = -INF
		for v in verts:
			hi = maxf(hi, (Transform3D(xform.basis, Vector3.ZERO) * v).y)
		xform.origin.y = -lo - STONE_BURIED_FRACTION * (hi - lo)
		xforms.append(xform)

	var multi := MultiMesh.new()
	# ⚠️ FIRST LINE, ALWAYS. The 4.3 default is TRANSFORM_2D, which throws
	# away every transform written to it and draws the whole batch at the
	# origin -- here, eight stones stacked inside the fire.
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = xforms.size()

	var bounds := AABB()
	for i in xforms.size():
		multi.set_instance_transform(i, xforms[i])
		var box: AABB = xforms[i] * local_aabb
		bounds = box if i == 0 else bounds.merge(box)
	# Written explicitly: a stale or wrong custom_aabb makes the whole
	# batch VANISH when the camera turns, with no error attached.
	multi.custom_aabb = bounds

	var node := MultiMeshInstance3D.new()
	node.name = "StoneRing"
	node.multimesh = multi
	node.material_override = _unshaded(HubBuilder.ROCK_COLOR)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## LOT 6 only -- the two arbitration labels. Removed by lot 7.
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
