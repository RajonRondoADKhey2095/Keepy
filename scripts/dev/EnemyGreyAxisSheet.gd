extends Node
## Grey-axis colour RECON for the rat's (ENEMY) resting-state albedo.
## NOT part of the shipped game (scripts/dev/* is excluded from the web
## export). NOT gated -- a measurement/report tool, not a probe with a
## pass/fail verdict: it writes a PNG and prints a table, nothing more.
##
## WHY THIS EXISTS, AND WHY IT IS NOT ANOTHER HUE-HUNT -- the colour
## already live on `staging` (rgb(0.9608, 0.8980, 0.9137), H=344.6deg)
## was ITSELF picked to be a near-neutral "blanc-gris", and it is the one
## that collides with CHARGER (1.27:1 contrast, 1.2deg hue apart,
## measured outside this session). "Blanc-gris" is therefore not virgin
## ground to explore -- it is precisely the zone that just cost a
## collision. This script stays IN that zone on purpose and asks a
## narrower question: does ANY point on a genuinely neutral grey axis
## separate reliably from CHARGER, or is the whole zone unsafe.
##
## WHY HUE-DEGREE ALONE IS NOT TRUSTED HERE (read before touching
## GREY_CANDIDATES) -- at low saturation (S < ~0.10) two greys can sit
## far apart in HUE DEGREES while reading as visually identical, because
## hue is derived from a tiny RGB spread that render noise (fog, AA,
## box-sampling) can rotate substantially without moving what the eye
## sees. Every candidate below is therefore judged on THREE independent
## signals, never hue degrees alone:
##   1. LUMINANCE separation (relative luminance, WCAG formula -- the
##      same one DarkPaletteAudit/EnemyColourSheetAxis already use for
##      their vs-ground contrast numbers) against all four hazards.
##   2. Its OWN saturation -- rows with S < HUE_RELIABLE_MIN_SAT are
##      marked "TEINTE PEU FIABLE": the hue-distance column on that row
##      is printed anyway (for the record) but must not be read as a
##      real separation on its own.
##   3. A real RENDERED comparison: every candidate gets a scene composed
##      with the real CHARGER boar in the SAME frame, real camera, real
##      lanes, at the real decision distance (z=DECISION_Z) -- this is
##      the only signal that survives contact with a phone screen, and
##      it is what the report leans on, not the degree column.
##
## METHOD -- copied deliberately from EnemyColourSheetAxis.gd (itself
## copied from DarkPaletteAudit.gd), not reinvented: a private
## calibration scene whose WorldEnvironment, DirectionalLight3D and
## ground material are READ OUT OF Game.tscn / TrackSegment.tscn at run
## time (PackedScene.get_state(), never hand-copied hex), a camera posed
## at CameraFollow's own steady-state transform, the REAL Obstacle.tscn
## instantiated (twice -- see TWO OBSTACLES below) and reused, and the
## REAL SwampAtmosphere.gd driving the mist breath through
## GameState.mist_intensity so both ends of the breath are measured
## rather than assumed identical.
##
## TWO OBSTACLES, NOT ONE -- `_obstacle` plays every single-object row
## (the four already-placed hazards, the shipped ENEMY, and each grey
## candidate on its own); `_charger_ref` is a SECOND, independent
## Obstacle instance permanently configured as CHARGER, used only to
## stand next to `_obstacle` in the composed shots. Two instances rather
## than one reused back-to-back because a composed shot needs BOTH
## objects on screen in the SAME frame -- there is no way to fake that
## with a single node measured twice.
##
## ⚠️ ENEMY'S ALARM RAMP WOULD OTHERWISE CLOBBER THE OVERRIDE -- read
## before deleting the `_enemy_settling = false` lines. CAPTURE_Z is
## close enough to contact that Obstacle._physics_process's own settling
## logic locks ENEMY to full alarm colour (ENEMY_ALARM_ALBEDO) within a
## single physics tick once GameState.state == PLAYING (this is the same
## mechanism CLAUDE.md already documents for DarkPaletteAudit's "ENEMY
## (resting)" row actually measuring the ALARM tint, not the resting
## one). This script needs the REST colour -- the candidate's own
## albedo, not a shared alarm red -- so every time `_obstacle` is
## configured as ENEMY, `_enemy_settling` is forced back to false right
## after `configure()`, which keeps `_physics_process` on its very first
## early-return branch (`if not _enemy_settling: return`) and never lets
## `_apply_enemy_alarm` touch the material again. GameState.state stays
## PLAYING regardless (needed for the mist breath and for CHARGER's own
## self-advance in the composed shots), so nothing else in this file
## changes.
##
## ⚠️ NEVER add --headless: it forces the DUMMY rendering driver and
## silently overrides --rendering-driver, so every sample reads (0,0,0).
## Run under xvfb-run, WITHOUT --headless (same lesson as
## DarkPaletteAudit / EnemyColourSheetAxis).
##
## Run it with:
##   xvfb-run -a godot4 --rendering-driver opengl3 --path . \
##     res://scripts/dev/EnemyGreyAxisSheet.tscn

const SETTLE_FRAMES: int = 3
const CAPTURE_Z: float = -2.2 # same close framing DarkPaletteAudit/EnemyColourSheetAxis use
const DECISION_Z: float = -12.0 # real decision distance (charger_candidate_08_comparison.png convention)
const GAME_SCENE_PATH := "res://scenes/Game.tscn"
const TRACK_SEGMENT_SCENE_PATH := "res://scenes/TrackSegment.tscn"

const SAMPLE_HALF_PX: int = 14
const GROUND_STRIP_TOP_FRAC: float = 0.92

const CONTRAST_FLOOR: float = 3.0
const CONTRAST_SAFE_MARGIN: float = 3.05 # brief's own "arret" -- clearing 3.0 exactly is not enough margin
const HUE_MIN_SEPARATION: float = 45.0
const HUE_RELIABLE_MIN_SAT: float = 0.10 # below this, the hue-distance column is not to be trusted alone
const LUM_SEPARATION_HEURISTIC: float = 0.12 # flagging aid only, see class doc -- not a scientific floor

const CROP_PAD_PX: int = 36
const CROP_MAX_DIM: int = 260
const WIDE_CROP_PAD_PX: int = 48
const WIDE_CROP_MAX_W: int = 900
const WIDE_CROP_MAX_H: int = 320

const OUT_PNG_PATH := "res://docs/color-sheets/enemy_grey_axis_sheet.png"

const MESH_NODE_FOR_TYPE := {
	Obstacle.Type.DODGE: "DodgeMesh",
	Obstacle.Type.JUMP: "JumpMesh",
	Obstacle.Type.STOMPER: "StomperMesh",
	Obstacle.Type.CHARGER: "ChargerMesh",
	Obstacle.Type.ENEMY: "EnemyMesh",
}

var _root3d: Node3D
var _camera: Camera3D
var _atmosphere: Node
var _obstacle: Obstacle
var _charger_ref: Obstacle

## label -> measurement Dictionary, insertion order preserved (Godot
## Dictionaries are ordered).
var _results: Dictionary = {}
## label -> Image (deep-phase close crop).
var _crops: Dictionary = {}
## label -> Image (composed candidate+CHARGER crop at DECISION_Z), only
## populated for grey candidates.
var _wide_crops: Dictionary = {}

## Currently installed on `staging` -- kept live pending this choice, see
## class doc. Measured for real (no override) as the FIRST row so the
## already-known collision reproduces on this tree before anything else
## is judged against it.
const ENEMY_SHIPPED_LABEL := "ENEMY shipped (installed pink, staying live pending this choice)"

## AXIS: near-neutral grey-white candidates. Two very light, two medium,
## one deliberately kept above HUE_RELIABLE_MIN_SAT to test whether a
## small, real tint can buy a dependable separation without losing the
## "realistic grey" identity. S/V picked up front, not swept -- this is
## a targeted recon of a named zone, not an open hunt (see
## EnemyColourSheetAxis.gd for that).
const GREY_CANDIDATES: Array = [
	{"label": "G1 Very light, warm-neutral near-white", "h": 25.0, "s": 0.03, "v": 0.92},
	{"label": "G2 Very light, cool-neutral near-white", "h": 200.0, "s": 0.05, "v": 0.90},
	{"label": "G3 Medium, warm-neutral grey", "h": 25.0, "s": 0.04, "v": 0.58},
	{"label": "G4 Medium, cool-neutral grey", "h": 200.0, "s": 0.06, "v": 0.55},
	{"label": "G5 Medium, green-grey (deliberately above the reliability floor)", "h": 110.0, "s": 0.11, "v": 0.60},
]

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- see
	# ProbeWatchdog.gd. Not gated, but every scripts/dev/ entry point
	# still owes the timeout guarantee ProbeTimeoutAudit checks.
	ProbeWatchdog.arm(self, "EnemyGreyAxisSheet")
	_run.call_deferred()

func _run() -> void:
	_build_calibration_scene()
	await _wait_frames(SETTLE_FRAMES)
	GameState.state = GameState.State.PLAYING

	print("=== ENEMY (rat) grey-axis recon -- neutral candidates vs CHARGER/JUMP/STOMPER/DODGE ===")
	print("")

	# ---- Reference hazards, measured for real -- never trusted from docs.
	print("--- Reference hazards (measured this run, on staging's current tree) ---")
	for type in [Obstacle.Type.DODGE, Obstacle.Type.JUMP, Obstacle.Type.STOMPER, Obstacle.Type.CHARGER]:
		var label: String = Obstacle.Type.keys()[type]
		var rec := await _measure_close(label, type, null, true)
		_print_row(rec)

	# ---- ENEMY: shipped reality (the already-collided anchor).
	print("")
	print("--- ENEMY reference row (already known to collide with CHARGER) ---")
	var shipped := await _measure_close(ENEMY_SHIPPED_LABEL, Obstacle.Type.ENEMY, null, true)
	_print_row(shipped)

	# ---- Grey axis candidates.
	print("")
	print("--- GREY AXIS -- neutral candidates, judged on luminance + own saturation + rendered comparison ---")
	for c in GREY_CANDIDATES:
		var color := Color.from_hsv(float(c.h) / 360.0, c.s, c.v, 1.0)
		var label := String(c.label)
		var rec := await _measure_close(label, Obstacle.Type.ENEMY, color, true)
		_print_row(rec)
		await _capture_wide(label, color)

	print("")
	print("=== Writing composite PNG to %s ===" % OUT_PNG_PATH)
	await _compose_png()
	print("DONE")
	get_tree().quit(0)

# =====================================================================
# CALIBRATION SCENE -- copied pattern from DarkPaletteAudit.gd /
# EnemyColourSheetAxis.gd. Env, light and ground material are READ from
# the shipped scenes, never hand-copied.
# =====================================================================

func _build_calibration_scene() -> void:
	_root3d = Node3D.new()
	_root3d.name = "Root3D"
	add_child(_root3d)

	var env: Environment = _scene_environment(GAME_SCENE_PATH).duplicate()
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	_root3d.add_child(world_env)

	var light := _scene_directional_light(GAME_SCENE_PATH)
	_root3d.add_child(light)

	var ground_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 0.4, 60) # long enough to still read as ground at DECISION_Z
	ground_mesh.mesh = box
	ground_mesh.set_surface_override_material(0, _scene_ground_material(TRACK_SEGMENT_SCENE_PATH))
	ground_mesh.position = Vector3(0, -0.2, -15)
	_root3d.add_child(ground_mesh)

	_camera = Camera3D.new()
	_root3d.add_child(_camera)
	# CameraFollow's own converged steady-state against a target fixed at
	# (0,1,0): offset (0,4.2,7), look_ahead (0,1,-4) -- read from
	# scripts/camera/CameraFollow.gd's @export defaults, not guessed.
	# Kept STATIONARY for both the close (CAPTURE_Z) and far (DECISION_Z)
	# shots -- only the objects move -- so every crop in this sheet is
	# the same real camera looking down the same real lane.
	_camera.position = Vector3(0, 5.2, 7)
	_camera.look_at(Vector3(0, 2, -4), Vector3.UP)
	_camera.current = true

	# The REAL SwampAtmosphere.gd, attached before entering the tree so
	# _ready() runs the normal way.
	_atmosphere = Node.new()
	_atmosphere.set_script(load("res://scripts/world/SwampAtmosphere.gd"))
	_atmosphere.set("world_environment_path", NodePath("../Root3D/WorldEnvironment"))
	add_child(_atmosphere)

	_obstacle = preload("res://scenes/Obstacle.tscn").instantiate()
	_root3d.add_child(_obstacle)
	_obstacle.position = Vector3(0.0, 0.0, CAPTURE_Z)
	_obstacle.visible = true

	_charger_ref = preload("res://scenes/Obstacle.tscn").instantiate()
	_root3d.add_child(_charger_ref)
	_charger_ref.configure(Obstacle.Type.CHARGER)
	_charger_ref.position = Vector3(TrackSegment.LANE_X[0], 0.0, DECISION_Z)
	_charger_ref.rotation = Vector3.ZERO
	_charger_ref.visible = false # only shown during composed shots

# =====================================================================
# MEASUREMENT -- close row (CAPTURE_Z), matches the gated convention
# used throughout this project (worst of shallow/deep vs ground).
# =====================================================================

func _measure_close(label: String, type: Obstacle.Type, albedo_override, capture_crop: bool) -> Dictionary:
	var rec := {"label": label, "type": type, "override": albedo_override}
	for phase in [{"key": "shallow", "intensity": 0.0}, {"key": "deep", "intensity": 1.0}]:
		GameState.mist_intensity = phase.intensity
		_configure_at(_obstacle, type, Vector3(0.0, 0.0, CAPTURE_Z), albedo_override)
		await _wait_frames(SETTLE_FRAMES)
		# Re-apply AFTER the settle wait too: self-moving types
		# (CHARGER/STOMPER) drift once GameState.state == PLAYING, and
		# ENEMY's alarm guard must be re-forced every time configure()
		# runs (configure() resets _enemy_settling to true on every
		# call) -- see this file's class doc.
		_configure_at(_obstacle, type, Vector3(0.0, 0.0, CAPTURE_Z), albedo_override)
		await _wait_frames(1)

		var ground := _sample_strip(GROUND_STRIP_TOP_FRAC, 1.0)
		var point := _obstacle_sample_point(_obstacle, type)
		var color := _sample_point(point)
		var ratio := _contrast_ratio(color, ground)
		rec[phase.key + "_color"] = color
		rec[phase.key + "_ground"] = ground
		rec[phase.key + "_ratio"] = ratio

		if capture_crop and phase.key == "deep":
			_crops[label] = _capture_crop([_obstacle_sample_bounds(_obstacle, type)], CROP_PAD_PX, CROP_MAX_DIM, CROP_MAX_DIM)

	rec["worst_ratio"] = minf(rec["shallow_ratio"], rec["deep_ratio"])
	# Hue/sat/val/luminance reported from the DEEP-phase colour --
	# SwampAtmosphere only ever touches sky/haze/fog_density (see its own
	# header), so hue/luminance are expected to be phase-invariant for
	# gameplay objects; the shallow colour stays on the record too.
	var deep_color: Color = rec["deep_color"]
	rec["hue"] = deep_color.h * 360.0
	rec["sat"] = deep_color.s
	rec["val"] = deep_color.v
	rec["lum"] = _relative_luminance(deep_color)
	_results[label] = rec
	return rec

## Configures `node` as `type` at `pos`, optionally overriding ENEMY's
## real per-instance material albedo. Also forces `_enemy_settling` back
## to false immediately when `type` is ENEMY -- see this file's class
## doc for why: `configure()` itself sets it back to true every time it
## runs, and leaving it true would let the alarm ramp clobber the
## override on the very next physics tick.
func _configure_at(node: Obstacle, type: Obstacle.Type, pos: Vector3, albedo_override) -> void:
	node.configure(type)
	node.position = pos
	node.rotation = Vector3.ZERO
	if type == Obstacle.Type.ENEMY:
		node._enemy_settling = false
		if albedo_override != null and node._enemy_material:
			node._enemy_material.albedo_color = albedo_override

# =====================================================================
# COMPOSED SHOT -- candidate ENEMY (right lane) next to the real CHARGER
# (left lane), both at DECISION_Z, same camera, same frame. This is the
# signal the report leans on -- not the hue-degree column.
# =====================================================================

func _capture_wide(label: String, candidate_color: Color) -> void:
	GameState.mist_intensity = 1.0 # deep end -- the worst-case atmosphere, matches the gated rows
	var enemy_pos := Vector3(TrackSegment.LANE_X[2], 0.0, DECISION_Z)
	var charger_pos := Vector3(TrackSegment.LANE_X[0], 0.0, DECISION_Z)

	_configure_at(_obstacle, Obstacle.Type.ENEMY, enemy_pos, candidate_color)
	_charger_ref.configure(Obstacle.Type.CHARGER)
	_charger_ref.position = charger_pos
	_charger_ref.rotation = Vector3.ZERO
	_charger_ref.visible = true
	await _wait_frames(SETTLE_FRAMES)

	# Re-apply after the settle wait -- same reason as _measure_close.
	_configure_at(_obstacle, Obstacle.Type.ENEMY, enemy_pos, candidate_color)
	_charger_ref.configure(Obstacle.Type.CHARGER)
	_charger_ref.position = charger_pos
	_charger_ref.rotation = Vector3.ZERO
	await _wait_frames(1)

	var enemy_bounds := _obstacle_sample_bounds(_obstacle, Obstacle.Type.ENEMY)
	var charger_bounds := _obstacle_sample_bounds(_charger_ref, Obstacle.Type.CHARGER)
	_wide_crops[label] = _capture_crop([enemy_bounds, charger_bounds], WIDE_CROP_PAD_PX, WIDE_CROP_MAX_W, WIDE_CROP_MAX_H)

	_charger_ref.visible = false

# =====================================================================
# BOUNDS / SAMPLING -- generalised to accept any Obstacle instance
# (this file has two), copied pattern from EnemyColourSheetAxis.gd.
# =====================================================================

func _obstacle_sample_point(node: Obstacle, type: Obstacle.Type) -> Vector3:
	return _obstacle_sample_bounds(node, type).get_center()

func _obstacle_sample_bounds(node: Obstacle, type: Obstacle.Type) -> AABB:
	var slot := node.get_node_or_null(NodePath(MESH_NODE_FOR_TYPE[type]))
	if slot == null:
		push_error("EnemyGreyAxisSheet: no mesh node '%s' on Obstacle." % MESH_NODE_FOR_TYPE[type])
		return AABB(node.global_position, Vector3.ONE * 0.1)
	var merged := AABB()
	var any := false
	for n in _visual_descendants(slot):
		var box: AABB = n.global_transform * n.get_aabb()
		if box.size == Vector3.ZERO:
			continue
		merged = box if not any else merged.merge(box)
		any = true
	if not any:
		push_error("EnemyGreyAxisSheet: mesh node '%s' draws nothing measurable." % MESH_NODE_FOR_TYPE[type])
		return AABB(node.global_position, Vector3.ONE * 0.1)
	return merged

func _visual_descendants(node: Node) -> Array[VisualInstance3D]:
	var found: Array[VisualInstance3D] = []
	if node is VisualInstance3D and node.visible:
		found.append(node)
	for child in node.get_children():
		found.append_array(_visual_descendants(child))
	return found

# =====================================================================
# PIXEL SAMPLING / CONTRAST -- copied verbatim in spirit from
# DarkPaletteAudit.gd / EnemyColourSheetAxis.gd.
# =====================================================================

func _sample_point(world_pos: Vector3) -> Color:
	var img: Image = get_viewport().get_texture().get_image()
	var screen := _camera.unproject_position(world_pos)
	var visible_size := get_viewport().get_visible_rect().size
	var sx := float(img.get_width()) / maxf(visible_size.x, 1.0)
	var sy := float(img.get_height()) / maxf(visible_size.y, 1.0)
	return _sample_box(img, int(screen.x * sx), int(screen.y * sy), SAMPLE_HALF_PX)

func _sample_strip(top_frac: float, bottom_frac: float) -> Color:
	var img: Image = get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var y0 := int(h * top_frac)
	var y1 := int(h * bottom_frac)
	var cx := w / 2
	return _sample_box(img, cx, (y0 + y1) / 2, mini((y1 - y0) / 2, w / 4))

func _sample_box(img: Image, cx: int, cy: int, half: int) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var acc := Vector3.ZERO
	var samples := 0
	var step := maxi(1, half / 6)
	for y in range(maxi(0, cy - half), mini(h, cy + half), step):
		for x in range(maxi(0, cx - half), mini(w, cx + half), step):
			var c := img.get_pixel(x, y)
			acc += Vector3(c.r, c.g, c.b)
			samples += 1
	if samples == 0:
		push_error("EnemyGreyAxisSheet: sample box (%d,%d) half=%d off-screen." % [cx, cy, half])
		return Color(0, 0, 0)
	acc /= float(samples)
	return Color(acc.x, acc.y, acc.z)

## Crops the rendered frame down to the union of `bounds_list`'s
## projected screen rects, with padding, capped to max_w x max_h (long
## edge downscaled proportionally) -- a real render, not a flat swatch.
## `bounds_list` with more than one entry is how the composed shots get
## both objects in a single crop.
func _capture_crop(bounds_list: Array, pad_px: int, max_w: int, max_h: int) -> Image:
	var img: Image = get_viewport().get_texture().get_image()
	var visible_size := get_viewport().get_visible_rect().size
	var sx := float(img.get_width()) / maxf(visible_size.x, 1.0)
	var sy := float(img.get_height()) / maxf(visible_size.y, 1.0)
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for bounds in bounds_list:
		var b: AABB = bounds
		for i in 8:
			var corner := b.position + Vector3(
				b.size.x if (i & 1) else 0.0,
				b.size.y if (i & 2) else 0.0,
				b.size.z if (i & 4) else 0.0)
			var s := _camera.unproject_position(corner)
			s.x *= sx
			s.y *= sy
			minp.x = minf(minp.x, s.x)
			minp.y = minf(minp.y, s.y)
			maxp.x = maxf(maxp.x, s.x)
			maxp.y = maxf(maxp.y, s.y)
	var x0 := maxi(0, int(minp.x) - pad_px)
	var y0 := maxi(0, int(minp.y) - pad_px)
	var x1 := mini(img.get_width(), int(maxp.x) + pad_px)
	var y1 := mini(img.get_height(), int(maxp.y) + pad_px)
	if x1 <= x0 or y1 <= y0:
		push_error("EnemyGreyAxisSheet: crop rect degenerate, off-screen object.")
		var fallback := Image.create(max_w, max_h, false, Image.FORMAT_RGB8)
		fallback.fill(Color.MAGENTA)
		return fallback
	var crop := img.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
	var scale := 1.0
	if crop.get_width() > max_w:
		scale = minf(scale, float(max_w) / float(crop.get_width()))
	if crop.get_height() > max_h:
		scale = minf(scale, float(max_h) / float(crop.get_height()))
	if scale < 1.0:
		crop.resize(maxi(1, int(crop.get_width() * scale)), maxi(1, int(crop.get_height() * scale)))
	return crop

func _contrast_ratio(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	var hi := maxf(la, lb)
	var lo := minf(la, lb)
	return (hi + 0.05) / (lo + 0.05)

func _relative_luminance(c: Color) -> float:
	return 0.2126 * _linearize(c.r) + 0.7152 * _linearize(c.g) + 0.0722 * _linearize(c.b)

func _linearize(channel: float) -> float:
	if channel <= 0.03928:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)

func _hue_distance(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, 360.0 - d)

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

# =====================================================================
# SHIPPED-SCENE READERS -- verbatim pattern from DarkPaletteAudit.gd.
# =====================================================================

func _scene_environment(scene_path: String) -> Environment:
	var packed: PackedScene = load(scene_path)
	var value: Variant = _scene_property(packed, "environment")
	var env := value as Environment
	if env == null:
		push_error("EnemyGreyAxisSheet: no WorldEnvironment.environment found in %s" % scene_path)
		return Environment.new()
	return env

func _scene_directional_light(scene_path: String) -> DirectionalLight3D:
	var packed: PackedScene = load(scene_path)
	var state := packed.get_state()
	var light := DirectionalLight3D.new()
	for i in state.get_node_count():
		if state.get_node_type(i) != &"DirectionalLight3D":
			continue
		for j in state.get_node_property_count(i):
			light.set(state.get_node_property_name(i, j), state.get_node_property_value(i, j))
		return light
	push_error("EnemyGreyAxisSheet: no DirectionalLight3D found in %s" % scene_path)
	return light

func _scene_ground_material(scene_path: String) -> StandardMaterial3D:
	var packed: PackedScene = load(scene_path)
	var value: Variant = _scene_property(packed, "surface_material_override/0")
	var mat := value as StandardMaterial3D
	if mat == null:
		push_error("EnemyGreyAxisSheet: no ground surface_material_override/0 found in %s" % scene_path)
		return StandardMaterial3D.new()
	return mat.duplicate()

func _scene_property(packed: PackedScene, property_name: String) -> Variant:
	var state := packed.get_state()
	for i in state.get_node_count():
		for j in state.get_node_property_count(i):
			if String(state.get_node_property_name(i, j)) == property_name:
				return state.get_node_property_value(i, j)
	return null

# =====================================================================
# REPORTING
# =====================================================================

func _print_row(rec: Dictionary) -> void:
	var d_charger: Variant = _hue_distance_to(rec, "CHARGER")
	var d_jump: Variant = _hue_distance_to(rec, "JUMP")
	var d_stomper: Variant = _hue_distance_to(rec, "STOMPER")
	var d_dodge: Variant = _hue_distance_to(rec, "DODGE")
	var l_charger: Variant = _lum_distance_to(rec, "CHARGER")
	var l_jump: Variant = _lum_distance_to(rec, "JUMP")
	var l_stomper: Variant = _lum_distance_to(rec, "STOMPER")
	var l_dodge: Variant = _lum_distance_to(rec, "DODGE")
	var flag := _flag_string(rec, d_charger, d_jump, d_stomper, d_dodge, l_charger)
	print("%-58s hue=%6.1f sat=%.3f val=%.2f lum=%.4f | shallow=%.2f:1 deep=%.2f:1 worst=%.2f:1" % [
		rec.label, rec.hue, rec.sat, rec.val, rec.lum,
		rec.shallow_ratio, rec.deep_ratio, rec.worst_ratio,
	])
	print("    dHue vs C/J/S/D  = %s / %s / %s / %s deg  (floor %.0fdeg, unreliable if own sat<%.2f)" % [
		_fmt_dist(d_charger), _fmt_dist(d_jump), _fmt_dist(d_stomper), _fmt_dist(d_dodge), HUE_MIN_SEPARATION, HUE_RELIABLE_MIN_SAT,
	])
	print("    dLum vs C/J/S/D  = %s / %s / %s / %s  (relative luminance, WCAG 0..1 scale)" % [
		_fmt_dist(l_charger), _fmt_dist(l_jump), _fmt_dist(l_stomper), _fmt_dist(l_dodge),
	])
	if flag != "":
		print("   " + flag)

func _fmt_dist(d) -> String:
	if d == null:
		return "n/a"
	return "%.3f" % d if absf(float(d)) < 10.0 else "%.1f" % d

func _hue_distance_to(rec: Dictionary, ref_label: String):
	var ref := _find_ref(ref_label)
	if ref == null or String(rec.label) == ref_label:
		return null
	return _hue_distance(rec.hue, ref.hue)

func _lum_distance_to(rec: Dictionary, ref_label: String):
	var ref := _find_ref(ref_label)
	if ref == null or String(rec.label) == ref_label:
		return null
	return absf(float(rec.lum) - float(ref.lum))

## Reference hazard rows are keyed by their bare Type name (e.g.
## "CHARGER") in _results -- this looks that up regardless of what a
## candidate's own label is.
func _find_ref(ref_label: String):
	if _results.has(ref_label):
		return _results[ref_label]
	return null

func _flag_string(rec: Dictionary, d_c, d_j, d_s, d_d, l_c) -> String:
	var reasons: Array[String] = []
	if rec.worst_ratio < CONTRAST_FLOOR:
		reasons.append("BELOW CONTRAST FLOOR (%.2f:1 < %.1f:1)" % [rec.worst_ratio, CONTRAST_FLOOR])
	elif rec.worst_ratio < CONTRAST_SAFE_MARGIN:
		reasons.append("MARGIN TOO THIN (%.2f:1, wants >= %.2f:1)" % [rec.worst_ratio, CONTRAST_SAFE_MARGIN])
	if rec.sat < HUE_RELIABLE_MIN_SAT:
		reasons.append("HUE UNRELIABLE ZONE (sat=%.3f < %.2f -- judge on luminance + rendered comparison)" % [rec.sat, HUE_RELIABLE_MIN_SAT])
	if l_c != null and float(l_c) < LUM_SEPARATION_HEURISTIC and rec.sat < HUE_RELIABLE_MIN_SAT:
		reasons.append("RISK: close luminance to CHARGER (dLum=%.3f) AND hue unreliable -- exactly the zone that already collided" % [l_c])
	if reasons.is_empty():
		return ""
	return "<<< " + " | ".join(reasons)

# =====================================================================
# PNG COMPOSITE
# =====================================================================

const CANVAS_W: int = 1500
const ROW_H: int = 210
const WIDE_ROW_H: int = 340
const CROP_CELL: int = 160
const SWATCH_CELL: int = 160
const TEXT_X: int = 20 + CROP_CELL + 12 + SWATCH_CELL + 20
const TEXT_W: int = CANVAS_W - TEXT_X - 20
const HEADER_H: int = 150

func _compose_png() -> void:
	var order: Array[String] = []
	order.append_array(["DODGE", "JUMP", "STOMPER", "CHARGER"])
	order.append(ENEMY_SHIPPED_LABEL)
	var grey_labels: Array[String] = []
	for c in GREY_CANDIDATES:
		grey_labels.append(String(c.label))
	order.append_array(grey_labels)

	var section_breaks := {
		4: "ENEMY REFERENCE ROW -- already-collided anchor",
		5: "GREY AXIS -- each row: close crop + swatch + numbers, then a WIDE composed shot with the real CHARGER (same frame, decision distance z=%d)" % int(DECISION_Z),
	}

	# ---- layout pass: compute each row's top-of-cell y, reserving an
	# extra WIDE_ROW_H underneath every grey-candidate row for its
	# composed shot.
	var row_y := {}
	var wide_row_y := {}
	var y := HEADER_H
	for i in order.size():
		if section_breaks.has(i):
			y += 40
		var label: String = String(order[i])
		row_y[label] = y
		y += ROW_H
		if _wide_crops.has(label):
			wide_row_y[label] = y
			y += WIDE_ROW_H
	var canvas_h := y + 40

	var sub := SubViewport.new()
	sub.size = Vector2i(CANVAS_W, canvas_h)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.transparent_bg = false
	add_child(sub)

	var canvas := GreyAxisCanvas.new()
	canvas.size = Vector2(CANVAS_W, canvas_h)
	canvas.custom_minimum_size = Vector2(CANVAS_W, canvas_h)
	canvas.results = _results
	canvas.order = order
	canvas.section_breaks = section_breaks
	canvas.row_y = row_y
	canvas.wide_row_y = wide_row_y
	canvas.hue_distance_fn = Callable(self, "_hue_distance_to")
	canvas.lum_distance_fn = Callable(self, "_lum_distance_to")
	canvas.flag_fn = Callable(self, "_flag_string")
	sub.add_child(canvas)

	await _wait_frames(1)
	canvas.queue_redraw()
	await _wait_frames(3)

	var out_img: Image = sub.get_texture().get_image()
	out_img.convert(Image.FORMAT_RGBA8)

	# ------------------------------------------------------------------
	# CROPS BLITTED HERE, PLAIN CPU PIXEL COPY -- NOT draw_texture_rect()
	# IN THE CONTROL ABOVE. Same reason as EnemyColourSheetAxis.gd: in
	# this sandbox's software GL stack, draw_texture_rect() on an
	# ImageTexture built from a captured viewport crop rendered flat
	# white, while draw_rect() fills (swatches/backgrounds/section bars)
	# were never affected. Sidestepping the 2D texture-draw path
	# entirely avoids the whole class of bug.
	for label in _crops.keys():
		if not row_y.has(label):
			continue
		var crop: Image = _crops[label]
		crop.convert(Image.FORMAT_RGBA8)
		var iw := crop.get_width()
		var ih := crop.get_height()
		var scale := minf(float(CROP_CELL) / maxf(iw, 1.0), float(CROP_CELL) / maxf(ih, 1.0))
		var dw := maxi(1, int(iw * scale))
		var dh := maxi(1, int(ih * scale))
		if dw != iw or dh != ih:
			crop.resize(dw, dh)
		var yy: int = row_y[label]
		var dst_x := 20 + int((CROP_CELL - dw) / 2.0)
		var dst_y := yy + int((CROP_CELL - dh) / 2.0)
		out_img.blit_rect(crop, Rect2i(0, 0, dw, dh), Vector2i(dst_x, dst_y))

	for label in _wide_crops.keys():
		if not wide_row_y.has(label):
			continue
		var crop: Image = _wide_crops[label]
		crop.convert(Image.FORMAT_RGBA8)
		var iw := crop.get_width()
		var ih := crop.get_height()
		var avail_w := CANVAS_W - 40
		var avail_h := WIDE_ROW_H - 30
		var scale := minf(float(avail_w) / maxf(iw, 1.0), float(avail_h) / maxf(ih, 1.0))
		scale = minf(scale, 1.0)
		var dw := maxi(1, int(iw * scale))
		var dh := maxi(1, int(ih * scale))
		if dw != iw or dh != ih:
			crop.resize(dw, dh)
		var yy: int = wide_row_y[label]
		var dst_x := 20 + int((avail_w - dw) / 2.0)
		var dst_y := yy + 10
		out_img.blit_rect(crop, Rect2i(0, 0, dw, dh), Vector2i(dst_x, dst_y))

	var err := out_img.save_png(OUT_PNG_PATH)
	if err != OK:
		push_error("EnemyGreyAxisSheet: save_png failed with error %d" % err)
	else:
		print("Saved %dx%d PNG to %s" % [out_img.get_width(), out_img.get_height(), OUT_PNG_PATH])

## Inner Control that draws the composite: crop cell frame, flat swatch
## (the real measured rendered colour), text block, and a labelled
## wide-cell frame under every grey-candidate row for its composed shot.
class GreyAxisCanvas:
	extends Control

	var results: Dictionary = {}
	var order: Array = []
	var section_breaks: Dictionary = {}
	var row_y: Dictionary = {}
	var wide_row_y: Dictionary = {}
	var hue_distance_fn: Callable
	var lum_distance_fn: Callable
	var flag_fn: Callable

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.08, 1.0))
		draw_string(font, Vector2(20, 30), "ENEMY (rat) grey-axis colour sheet -- neutral candidates vs CHARGER/JUMP/STOMPER/DODGE",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 24, Color(1, 1, 1))
		draw_string(font, Vector2(20, 56), "Real game camera + real hazard meshes + real fog/mist breath. Ground contrast floor 3.0:1 (safe margin 3.05:1). Hue floor 45deg -- UNRELIABLE below sat 0.10.",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 15, Color(0.75, 0.78, 0.75))
		draw_string(font, Vector2(20, 78), "Close crop/swatch = CAPTURE_Z=-2.2 (gated numbers). Wide crop = both objects at DECISION_Z=-12, same camera, same frame -- the real verdict.",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 15, Color(0.9, 0.9, 0.6))
		draw_string(font, Vector2(20, 100), "The already-installed rat (rgb 0.9608,0.8980,0.9137, H=344.6) already sits in this exact zone and already collides with CHARGER -- see ENEMY reference row.",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 15, Color(0.85, 0.75, 0.75))

		var crop_cell := 160
		var swatch_cell := 160
		var text_x := 20 + crop_cell + 12 + swatch_cell + 20
		var text_w := int(size.x) - text_x - 20

		for i in order.size():
			var label: String = String(order[i])
			if not row_y.has(label):
				continue
			var yy: int = row_y[label]
			if section_breaks.has(i):
				var header: String = String(section_breaks[i])
				draw_rect(Rect2(0, yy - 40, size.x, 34), Color(0.16, 0.18, 0.14, 1.0))
				draw_string(font, Vector2(20, yy - 17), header,
					HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 17, Color(0.95, 0.95, 0.55))
			if not results.has(label):
				continue
			var rec: Dictionary = results[label]

			draw_rect(Rect2(20, yy, crop_cell, crop_cell), Color(0.15, 0.15, 0.15, 1), false, 1.0)

			var deep_c: Color = rec.get("deep_color", Color.MAGENTA)
			draw_rect(Rect2(20 + crop_cell + 12, yy, swatch_cell, crop_cell), deep_c)
			draw_rect(Rect2(20 + crop_cell + 12, yy, swatch_cell, crop_cell), Color(0.15, 0.15, 0.15, 1), false, 1.0)

			var d_c: Variant = hue_distance_fn.call(rec, "CHARGER")
			var d_j: Variant = hue_distance_fn.call(rec, "JUMP")
			var d_s: Variant = hue_distance_fn.call(rec, "STOMPER")
			var d_d: Variant = hue_distance_fn.call(rec, "DODGE")
			var l_c: Variant = lum_distance_fn.call(rec, "CHARGER")
			var l_j: Variant = lum_distance_fn.call(rec, "JUMP")
			var l_s: Variant = lum_distance_fn.call(rec, "STOMPER")
			var l_d: Variant = lum_distance_fn.call(rec, "DODGE")
			var flag: String = flag_fn.call(rec, d_c, d_j, d_s, d_d, l_c)

			var lines := PackedStringArray()
			lines.append(label)
			lines.append("H=%.1fdeg  S=%.3f  V=%.2f  Lrel=%.4f    RGB rendered=(%.3f, %.3f, %.3f)" % [
				rec.hue, rec.sat, rec.val, rec.lum, deep_c.r, deep_c.g, deep_c.b])
			lines.append("contrast vs ground: shallow=%.2f:1  deep=%.2f:1  worst(gated)=%.2f:1  (floor 3.0:1, safe 3.05:1)" % [
				rec.shallow_ratio, rec.deep_ratio, rec.worst_ratio])
			lines.append("dHue -> C/J/S/D = %s/%s/%s/%s deg  (floor 45, sat<0.10 = unreliable)" % [
				_fmt(d_c), _fmt(d_j), _fmt(d_s), _fmt(d_d)])
			lines.append("dLum -> C/J/S/D = %s/%s/%s/%s  (relative luminance, 0..1)" % [
				_fmt(l_c), _fmt(l_j), _fmt(l_s), _fmt(l_d)])
			if flag != "":
				lines.append(flag)
			else:
				lines.append("OK on the printed floors -- still judge the wide composed shot below by eye")

			var text_color := Color(1, 0.6, 0.55) if flag != "" else Color(0.85, 0.9, 0.85)
			var ty := yy + 2
			for li in lines.size():
				var line_color := text_color if li == lines.size() - 1 else Color(0.85, 0.87, 0.85)
				if li == 0:
					line_color = Color(1, 1, 1)
				draw_string(font, Vector2(text_x, ty + 16), String(lines[li]),
					HORIZONTAL_ALIGNMENT_LEFT, text_w, 15, line_color)
				ty += 24

			if wide_row_y.has(label):
				var wy: int = wide_row_y[label]
				draw_string(font, Vector2(20, wy - 6), "Composed at decision distance (z=-12): candidate ENEMY (right lane) next to the real CHARGER (left lane) --",
					HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 14, Color(0.8, 0.85, 1.0))
				draw_rect(Rect2(20, wy + 8, size.x - 40, 300), Color(0.15, 0.15, 0.15, 1), false, 1.0)

	func _fmt(d) -> String:
		if d == null:
			return "n/a"
		return "%.3f" % d if absf(float(d)) < 10.0 else "%.1f" % d
