extends Node3D
class_name HubCove
## CH29 (6 septembre 2026) -- the fifth map, "la Crique": the module that
## owns everything the cove has that is not ground cover. Modelled on
## HubTransport / HubKarting: one node under World, built in _ready(),
## handed the nodes it needs by HubWorld.setup(), read by CozyScatter
## through STATIC accessors (footprints) so the sowing can keep clear of
## what stands here.
##
## =====================================================================
## WHAT IT BUILDS
##
##   * THE SEA -- one alpha water disc (the lakes' shader, the sea's two
##     tones and a thinner foam rim) whose centre and radius are
##     HubRegion.SEA_CENTRE / SEA_RADIUS, the ONE owner of that geometry
##     (the ground shader paints the bed from the same two numbers, and
##     CoveProbe gates the drawn disc against them).
##   * THE LIGHTHOUSE -- the zone's landmark, on the hole HubRegion carves
##     for it. Its lamp LIGHTS UP and a beam sweeps under rain and storm:
##     the cove's answer to "the zone must not be inert in bad weather".
##     Unlit materials cannot glow, so "lit" is an albedo swap to a tint
##     above 1.0 (the gold-acorn trick), and the beam is one alpha quad.
##   * THE SANDCASTLE SPOTS -- three discs of wet sand. A tap on one walks
##     Keepy there and a castle RISES out of the sand; a second and third
##     tap grow it (three stages, a flag on the last). Under rain and
##     storm every castle MELTS (scale toward zero, then gone). That is
##     the zone's own interaction: no character, one phrase, no text.
##   * Parasols, deckchairs, a lifeguard chair, three buoys that bob with
##     the wind, and the junction sign in the moor.
##   * THE BURROW (P2) -- a dune burrow with its ModelSlot for a future
##     inhabitant. Inert: no behaviour, no state, a documented slot.
##
## =====================================================================
## THE CASTLE CHANNEL IS THE BOAT PATTERN
##
## `accepts_castle_tap(aim)` answers -1 for a spot whose castle is
## currently RISING (a bounded tween), so a tap meanwhile falls through to
## the ground path and cancels the intent -- exactly the withdrawal the
## docks and the mooring do. There is no unbounded phase: Keepy never
## mounts anything, the walk is an ordinary hop chain any tap cancels.
##
## STATE lives in WorldSave (schema 2, the `cove` block): which spot holds
## which stage. Melting progress is NOT saved -- a save mid-melt reloads
## the castle whole, which is the kinder of the two errors.

## Sandcastle spots, on the wet strip 2.0-3.5 u inside the waterline
## (checked by CoveProbe against HubRegion.shore_distance, never assumed).
const CASTLE_SPOTS: Array[Vector3] = [
	Vector3(58.4, 0.0, -98.5),
	Vector3(57.2, 0.0, -110.5),
	Vector3(58.4, 0.0, -119.5),
]
## Tap disc on `aim`, and the disc the scatter keeps clear.
const CASTLE_TAP_RADIUS: float = 1.5
const CASTLE_FOOTPRINT: float = 1.7
## Where Keepy stands to build: on the dry side of the spot, so the
## castle rises in front of him rather than under his feet.
const CASTLE_APPROACH: Vector3 = Vector3(-1.45, 0.0, 0.0)
const CASTLE_REACH: float = 1.7
const CASTLE_STAGES: int = 3
const CASTLE_STAGE_SCALE: Array[float] = [0.62, 0.84, 1.0]
const CASTLE_BUILD_S: float = 1.3
## Seconds of steady rain (resp. storm) that melt a castle completely.
const CASTLE_MELT_RAIN_S: float = 18.0
const CASTLE_MELT_STORM_S: float = 8.0
## Top of the keep in the castle GLB's model space (see cove.py).
const CASTLE_FLAG_Y: float = 1.21

const LAMP_Y: float = 7.55
const LAMP_LIT_TINT: Color = Color(1.9, 1.75, 1.15)
const LAMP_OFF_TINT: Color = Color(1.0, 1.0, 1.0)
const BEAM_LENGTH: float = 11.0
const BEAM_RPM: float = 0.22
## The beam dips toward the ground: at 11 u it lands 2.3 u below the lamp.
const BEAM_PITCH_DEG: float = 12.0
const LIGHTHOUSE_FOOTPRINT: float = 2.8

## Fixed props: position, glb, yaw (degrees), scatter footprint.
const PROPS: Array[Dictionary] = [
	{"glb": "umbrella_0", "at": Vector3(52.0, 0.0, -104.5), "yaw": 20.0, "radius": 1.6},
	{"glb": "deckchair_0", "at": Vector3(50.9, 0.0, -103.0), "yaw": 100.0, "radius": 1.0},
	{"glb": "umbrella_1", "at": Vector3(53.5, 0.0, -117.0), "yaw": -35.0, "radius": 1.6},
	{"glb": "deckchair_1", "at": Vector3(52.5, 0.0, -118.6), "yaw": 75.0, "radius": 1.0},
	# Not on the north strip: a parasol 1.4 u inside the north edge stood
	# 4 u in front of the camera of anyone on the dock and filled the
	# bottom of the frame (capture "dock", second pass). Tall props keep
	# ~10 u south of COVE_MAX.y -- see CozyScatter.COVE_CAMERA_BAND.
	{"glb": "umbrella_0", "at": Vector3(49.5, 0.0, -107.5), "yaw": 140.0, "radius": 1.6},
	{"glb": "lifeguard_0", "at": Vector3(54.0, 0.0, -113.6), "yaw": 90.0, "radius": 1.4},
	{"glb": "driftwood_0", "at": Vector3(53.0, 0.0, -127.2), "yaw": 30.0, "radius": 1.3},
	{"glb": "driftwood_0", "at": Vector3(46.5, 0.0, -108.0), "yaw": -70.0, "radius": 1.3},
]
## Buoys float in the sea (CoveProbe gates each one against in_sea).
const BUOYS: Array[Vector3] = [Vector3(68.0, 0.0, -100.0), Vector3(72.0, 0.0, -118.0), Vector3(66.0, 0.0, -129.0)]
## The junction sign, IN THE MOOR by the corridor's north lip, arrow toward
## the cove (+x). The only "there is something east" the moor offers, and
## it is geometry rather than UI, on the docks' sign's own reasoning.
const SIGN_AT: Vector3 = Vector3(35.5, 0.0, -90.0)
const SIGN_FOOTPRINT: float = 0.7
## P2: the burrow, south-west corner of the beach, opening toward the sea.
const BURROW_AT: Vector3 = Vector3(47.5, 0.0, -124.5)
const BURROW_YAW_DEG: float = 90.0
const BURROW_FOOTPRINT: float = 2.6
## The slot stands on the doorstep, 2.0 u in front of the opening, facing
## the sea like the burrow does. Documented in docs/lots/CH29_CRIQUE.md.
const BURROW_SLOT_OFFSET: Vector3 = Vector3(0.0, 0.0, 2.0)
## Target height of a future occupant, in Keepy heights (brief: 0.75-0.85).
const BURROW_SLOT_KEEPY_RATIO: float = 0.80

signal castle_built(spot: int, stage: int)
signal castle_melted(spot: int)

var _keepy: Node3D = null
var _weather: Node = null
var _sea: MeshInstance3D = null
var _lamp: MeshInstance3D = null
var _beam: MeshInstance3D = null
var _beam_material: StandardMaterial3D = null
var _buoys: Array[MeshInstance3D] = []
var _castles: Array[Dictionary] = []
var _burrow_slot: ModelSlot = null
var _time: float = 0.0
var _lit: float = 0.0

func _ready() -> void:
	_build_sea()
	_build_lighthouse()
	_build_props()
	_build_buoys()
	_build_sign()
	_build_castle_spots()
	_build_burrow()

## Handed the two nodes this needs, once, by HubWorld. Restores the saved
## castles here rather than in _ready() so WorldSave has been read.
func setup(keepy: Node3D, weather: Node) -> void:
	_keepy = keepy
	_weather = weather
	var saved: Dictionary = WorldSave.cove_castles()
	for i in _castles.size():
		var stage: int = int(saved.get(str(i), 0))
		if stage > 0:
			_show_castle(i, clampi(stage, 1, CASTLE_STAGES), 1.0, false)

## ---- building --------------------------------------------------------

func _glb_node(name: String, mesh_name: String, material: Material) -> MeshInstance3D:
	var mesh: Mesh = CozyPalette.glb_mesh(CozyPalette.decor_path(mesh_name))
	var node := MeshInstance3D.new()
	node.name = name
	if mesh == null:
		push_error("HubCove: %s.glb missing" % mesh_name)
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _build_sea() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = HubRegion.SEA_RADIUS
	disc.bottom_radius = HubRegion.SEA_RADIUS
	disc.height = 0.06
	disc.radial_segments = 96
	disc.rings = 1
	_sea = MeshInstance3D.new()
	_sea.name = "Sea"
	_sea.mesh = disc
	_sea.position = HubRegion.SEA_CENTRE + Vector3(0.0, 0.05, 0.0)
	_sea.set_surface_override_material(0, CozyPalette.water_material(HubRegion.SEA_RADIUS, false, 0.035,
		[CozyPalette.SEA_SHALLOW, CozyPalette.SEA_DEEP]))
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)

func _build_lighthouse() -> void:
	var tower := _glb_node("Lighthouse", "lighthouse_0", CozyPalette.decor_material())
	tower.position = HubRegion.LIGHTHOUSE_AT
	# The door (+z in the GLB) faces the beach, i.e. -x.
	tower.rotation.y = -PI / 2.0
	add_child(tower)
	_lamp = _glb_node("Lamp", "lamp_0", CozyPalette.decor_material_tinted(LAMP_OFF_TINT))
	_lamp.position = HubRegion.LIGHTHOUSE_AT + Vector3(0.0, LAMP_Y, 0.0)
	add_child(_lamp)
	# The beam: one alpha wedge from the lamp outward, rotated about the
	# lamp. Its alpha IS the weather (0 in the sun), so it costs nothing
	# to a sunny frame and is a single transparent quad otherwise.
	# TWO quads in a cross (a horizontal and a vertical wedge), not one: the
	# hub camera stands at y 7.6, the lamp at 7.55, so a single horizontal
	# quad is seen exactly edge-on from everywhere on the beach and draws
	# nothing (capture "lamp_storm", first pass). The cross reads from any
	# side, and the node is pitched down BEAM_PITCH_DEG so the sweep lands
	# on the sand and the water, where the eye is.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var near_w := 0.22
	var far_w := 2.6
	var l := BEAM_LENGTH
	var planes := [
		[Vector3(-near_w, 0.0, 0.0), Vector3(near_w, 0.0, 0.0), Vector3(far_w, 0.0, l), Vector3(-far_w, 0.0, l)],
		[Vector3(0.0, -near_w, 0.0), Vector3(0.0, near_w, 0.0), Vector3(0.0, far_w * 0.6, l), Vector3(0.0, -far_w * 0.6, l)],
	]
	for quad in planes:
		for tri in [[0, 1, 2], [0, 2, 3]]:
			for k in tri:
				st.set_color(Color(1.0, 1.0, 1.0, 1.0 if k < 2 else 0.0))
				st.set_normal(Vector3.UP)
				st.add_vertex(quad[k])
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	_beam.mesh = st.commit()
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_material.vertex_color_use_as_albedo = true
	_beam_material.albedo_color = Color(1.0, 0.94, 0.68, 0.0)
	_beam_material.no_depth_test = false
	_beam.material_override = _beam_material
	_beam.position = _lamp.position
	_beam.rotation.x = deg_to_rad(-BEAM_PITCH_DEG)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)

func _build_props() -> void:
	for i in PROPS.size():
		var spec: Dictionary = PROPS[i]
		var glb: String = spec["glb"]
		var wind: float = 0.05 if glb.begins_with("umbrella") else 0.0
		var material: Material = CozyPalette.decor_material_wind(wind, 2.2) if wind > 0.0 else CozyPalette.decor_material()
		var node := _glb_node("Prop_%d_%s" % [i, glb], glb, material)
		node.position = spec["at"]
		node.rotation.y = deg_to_rad(float(spec["yaw"]))
		add_child(node)

func _build_buoys() -> void:
	for i in BUOYS.size():
		var buoy := _glb_node("Buoy_%d" % i, "buoy_0", CozyPalette.decor_material())
		buoy.position = BUOYS[i] + Vector3(0.0, 0.05, 0.0)
		add_child(buoy)
		_buoys.append(buoy)

func _build_sign() -> void:
	var sign := _glb_node("CoveSign", "docksign_0", CozyPalette.decor_material())
	sign.position = SIGN_AT
	# The arrow points +z in the GLB; the cove is toward +x.
	sign.rotation.y = PI / 2.0
	add_child(sign)
	var flag := MeshInstance3D.new()
	flag.name = "CoveSignFlag"
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.46, 0.62)
	flag.mesh = box
	flag.material_override = CozyPalette.decor_material_tinted(CozyPalette.SAND_A)
	flag.position = SIGN_AT + Vector3(-0.34, 1.55, 0.0)
	flag.rotation.y = sign.rotation.y
	flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flag)

func _build_castle_spots() -> void:
	for i in CASTLE_SPOTS.size():
		var root := Node3D.new()
		root.name = "Castle_%d" % i
		root.position = CASTLE_SPOTS[i]
		root.rotation.y = float(i) * 1.9
		add_child(root)
		# The spot: a flat darker disc, always drawn, so the buildable
		# place reads before anything stands on it.
		var disc := CylinderMesh.new()
		disc.top_radius = 1.25
		disc.bottom_radius = 1.25
		disc.height = 0.02
		disc.radial_segments = 20
		disc.rings = 1
		var mark := MeshInstance3D.new()
		mark.name = "Mark"
		mark.mesh = disc
		mark.position = Vector3(0.0, 0.015, 0.0)
		mark.material_override = CozyPalette.decor_material_tinted(Color(0.70, 0.60, 0.43))
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mark)
		var castle := _glb_node("Castle", "sandcastle_0", CozyPalette.decor_material())
		castle.visible = false
		root.add_child(castle)
		var flag := _glb_node("Flag", "castleflag_0", CozyPalette.decor_material_wind(0.04, 0.4))
		flag.position = Vector3(0.0, CASTLE_FLAG_Y, 0.0)
		flag.visible = false
		castle.add_child(flag)
		_castles.append({"root": root, "castle": castle, "flag": flag, "stage": 0, "melt": 0.0, "tween": null})

func _build_burrow() -> void:
	var burrow := _glb_node("Burrow", "burrow_0", CozyPalette.decor_material())
	burrow.position = BURROW_AT
	burrow.rotation.y = deg_to_rad(BURROW_YAW_DEG)
	add_child(burrow)
	# The slot: an empty ModelSlot on the doorstep. No model tonight, no
	# behaviour ever from this file -- see the lot doc for the contract.
	_burrow_slot = ModelSlot.new()
	_burrow_slot.name = "BurrowSlot"
	burrow.add_child(_burrow_slot)
	_burrow_slot.position = BURROW_SLOT_OFFSET
	_burrow_slot.rotation.y = 0.0

## ---- what the scatter and the tap need -----------------------------

## Ground discs nothing should be sown in.
static func footprints() -> Array:
	var out: Array = []
	out.append({"position": HubRegion.LIGHTHOUSE_AT, "radius": LIGHTHOUSE_FOOTPRINT})
	for spot in CASTLE_SPOTS:
		out.append({"position": spot, "radius": CASTLE_FOOTPRINT})
	for spec in PROPS:
		out.append({"position": spec["at"], "radius": float(spec["radius"])})
	out.append({"position": SIGN_AT, "radius": SIGN_FOOTPRINT})
	out.append({"position": BURROW_AT, "radius": BURROW_FOOTPRINT})
	return out

## The spot a tap at `aim` (unclamped) means, or -1. WITHDRAWN while that
## spot's castle is rising (the boat's rule), so a tap meanwhile is a walk.
func accepts_castle_tap(aim: Vector3) -> int:
	var flat := Vector3(aim.x, 0.0, aim.z)
	for i in CASTLE_SPOTS.size():
		if flat.distance_to(CASTLE_SPOTS[i]) <= CASTLE_TAP_RADIUS:
			var tw: Tween = _castles[i]["tween"]
			if tw != null and tw.is_valid() and tw.is_running():
				return -1
			return i
	return -1

func spot_count() -> int:
	return CASTLE_SPOTS.size()

## Where Keepy walks to for spot `index`.
func approach_point(index: int) -> Vector3:
	return CASTLE_SPOTS[index] + CASTLE_APPROACH

func castle_stage(index: int) -> int:
	return int(_castles[index]["stage"])

## The drawn scale of castle `index` (0 when nothing stands there) -- what
## the probe measures instead of the stage it just wrote.
func castle_drawn_scale(index: int) -> float:
	var castle: MeshInstance3D = _castles[index]["castle"]
	return castle.scale.y if castle.visible else 0.0

func burrow_slot() -> ModelSlot:
	return _burrow_slot

func sea_node() -> MeshInstance3D:
	return _sea

func lamp_lit() -> float:
	return _lit

## Grows the castle at `index` by one stage (builds it from nothing at
## stage 1). Returns false when Keepy is not within reach or the castle is
## full. Called by HubWorld on the landing that finishes the walk.
func build_castle(index: int, from: Vector3) -> bool:
	if index < 0 or index >= _castles.size():
		return false
	var here := Vector3(from.x, 0.0, from.z)
	if here.distance_to(approach_point(index)) > CASTLE_REACH:
		return false
	var entry: Dictionary = _castles[index]
	var stage: int = int(entry["stage"])
	if stage >= CASTLE_STAGES:
		# Full: a tap still means something -- the flag waves harder for
		# a moment. Cheap, and never a dropped tap.
		_wave_flag(index)
		return true
	_show_castle(index, stage + 1, 0.0, true)
	WorldSave.cove_set_castle(index, stage + 1)
	WorldSave.note("castles_built")
	castle_built.emit(index, stage + 1)
	return true

## Puts castle `index` at `stage`, drawn at `progress` of that stage's
## scale (1.0 = finished), and tweens the rest when `animate`.
func _show_castle(index: int, stage: int, progress: float, animate: bool) -> void:
	var entry: Dictionary = _castles[index]
	var castle: MeshInstance3D = entry["castle"]
	var flag: MeshInstance3D = entry["flag"]
	var target: float = CASTLE_STAGE_SCALE[stage - 1]
	entry["stage"] = stage
	entry["melt"] = 0.0
	castle.visible = true
	flag.visible = stage >= CASTLE_STAGES
	var tw: Tween = entry["tween"]
	if tw != null and tw.is_valid():
		tw.kill()
	entry["tween"] = null
	if not animate:
		castle.scale = Vector3.ONE * target
		return
	# Grows from what is drawn now (the previous stage's scale, or nothing
	# when the spot was empty), never from a number written elsewhere.
	var start: float = maxf(castle.scale.y if stage > 1 else target * progress, 0.001)
	castle.scale = Vector3.ONE * start
	var tween := castle.create_tween()
	tween.tween_property(castle, "scale", Vector3.ONE * target, CASTLE_BUILD_S) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entry["tween"] = tween
	_puff(CASTLE_SPOTS[index])

func _wave_flag(index: int) -> void:
	var flag: MeshInstance3D = _castles[index]["flag"]
	var tween := flag.create_tween()
	tween.tween_property(flag, "rotation:y", flag.rotation.y + TAU, 0.9).set_trans(Tween.TRANS_SINE)

## Sand puffs: five small tinted spheres thrown up and shrunk, freed after.
## MeshInstance3D and tweens, not GPUParticles3D -- the repo has never
## shipped a particle system and this is not the night to prove one.
func _puff(at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 31.0 + at.z * 17.0) + int(_time * 1000.0)
	for i in 5:
		var puff := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.11
		sphere.height = 0.22
		sphere.radial_segments = 6
		sphere.rings = 3
		puff.mesh = sphere
		puff.material_override = CozyPalette.decor_material_tinted(CozyPalette.SAND_A)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(0.5, 1.1)
		puff.position = at + Vector3(cos(a) * 0.4, 0.15, sin(a) * 0.4)
		add_child(puff)
		var tween := puff.create_tween()
		tween.set_parallel(true)
		tween.tween_property(puff, "position", at + Vector3(cos(a) * r, 0.9 + rng.randf_range(0.0, 0.4), sin(a) * r), 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "scale", Vector3.ONE * 0.05, 0.55).set_delay(0.15)
		tween.chain().tween_callback(puff.queue_free)

## ---- per frame: weather --------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var wind: float = 1.0
	var rain_w: float = 0.0
	var storm_w: float = 0.0
	if _weather != null:
		if _weather.has_method("current_look"):
			wind = float((_weather.call("current_look") as Dictionary).get("wind", 1.0))
		if _weather.has_method("weight"):
			rain_w = float(_weather.call("weight", CozyWeather.Kind.RAIN))
			storm_w = float(_weather.call("weight", CozyWeather.Kind.STORM))
	# Buoys: bob and lean with the wind. Storm = three times the sun's.
	for i in _buoys.size():
		var buoy: MeshInstance3D = _buoys[i]
		var phase: float = float(i) * 2.1
		buoy.position.y = 0.05 + 0.07 * (0.5 + 0.5 * wind) * sin(_time * 1.3 + phase)
		buoy.rotation.z = deg_to_rad(5.0 * wind) * sin(_time * 1.1 + phase)
		buoy.rotation.x = deg_to_rad(3.5 * wind) * sin(_time * 0.9 + phase * 1.3)
	# The lamp and the beam: lit by the weight of rain + storm on screen.
	var lit: float = clampf(rain_w + storm_w, 0.0, 1.0)
	if absf(lit - _lit) > 0.001:
		_lit = lit
		_lamp.material_override = CozyPalette.decor_material_tinted(LAMP_OFF_TINT.lerp(LAMP_LIT_TINT, lit))
		_beam_material.albedo_color = Color(1.0, 0.94, 0.68, 0.55 * lit)
		_beam.visible = lit > 0.01
	if _beam.visible:
		_beam.rotation.y = fmod(_beam.rotation.y + delta * TAU * BEAM_RPM, TAU)
	# Castles melt in the rain.
	var melt_rate: float = rain_w / CASTLE_MELT_RAIN_S + storm_w / CASTLE_MELT_STORM_S
	if melt_rate <= 0.0:
		return
	for i in _castles.size():
		var entry: Dictionary = _castles[i]
		if int(entry["stage"]) <= 0:
			continue
		var tw: Tween = entry["tween"]
		if tw != null and tw.is_valid() and tw.is_running():
			continue
		var melt: float = float(entry["melt"]) + delta * melt_rate
		entry["melt"] = melt
		var castle: MeshInstance3D = entry["castle"]
		var flag: MeshInstance3D = entry["flag"]
		var full: float = CASTLE_STAGE_SCALE[int(entry["stage"]) - 1]
		if melt >= 1.0:
			entry["stage"] = 0
			entry["melt"] = 0.0
			castle.visible = false
			flag.visible = false
			castle.scale = Vector3.ONE
			WorldSave.cove_set_castle(i, 0)
			castle_melted.emit(i)
			continue
		flag.visible = false
		castle.scale = Vector3(full * (1.0 - 0.45 * melt), full * (1.0 - melt) , full * (1.0 - 0.45 * melt))
