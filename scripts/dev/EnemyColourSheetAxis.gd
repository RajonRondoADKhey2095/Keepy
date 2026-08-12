extends Node
## Colour-sheet RECON for the rat's (ENEMY) resting-state albedo.
## NOT part of the shipped game (scripts/dev/* is excluded from the web
## export). NOT gated -- this is a measurement/report tool, not a probe
## with a pass/fail verdict: it writes a PNG and prints a table, nothing
## more.
##
## WHY THIS EXISTS -- ENEMY currently ships with an albedo that was
## measured, outside this session, to collide in hue with CHARGER's own
## resting colour (~1.2 deg apart). This script hunts for candidate hues
## that are >45 deg from ALL FOUR already-placed hazards (CHARGER, JUMP,
## STOMPER, DODGE) at once, on two axes: a BRIGHT band (orthogonal to the
## three bright hazards) and a DARK band (orthogonal to DODGE, the only
## hazard already living there).
##
## METHOD, copied deliberately from scripts/dev/DarkPaletteAudit.gd rather
## than reinvented: a private calibration scene whose WorldEnvironment,
## DirectionalLight3D and ground material are READ OUT OF Game.tscn /
## TrackSegment.tscn at run time (PackedScene.get_state(), never
## hand-copied hex), a camera posed at CameraFollow's own steady-state
## transform, the REAL Obstacle.tscn instantiated once and reused, and
## the REAL SwampAtmosphere.gd driving the mist breath through
## GameState.mist_intensity so both ends of the breath are measured
## rather than assumed identical.
##
## CANDIDATE APPLICATION -- every candidate lands on ENEMY's real,
## per-instance material. Obstacle._ready() duplicates EnemyMesh's shared
## material into `_enemy_material` exactly once and this script mutates
## `_enemy_material.albedo_color` directly between samples: no game code
## is touched, no ModelSlot/scene file is written, nothing is installed.
##
## ⚠️ NEVER add --headless: it forces the DUMMY rendering driver and
## silently overrides --rendering-driver, so every sample reads (0,0,0).
## Run under xvfb-run, WITHOUT --headless (same lesson as DarkPaletteAudit).
##
## Run it with:
##   xvfb-run -a godot4 --rendering-driver opengl3 --path . \
##     res://scripts/dev/EnemyColourSheetAxis.tscn

const SETTLE_FRAMES: int = 3
const CAPTURE_Z: float = -2.2  # same framing DarkPaletteAudit measures hazards at
const GAME_SCENE_PATH := "res://scenes/Game.tscn"
const TRACK_SEGMENT_SCENE_PATH := "res://scenes/TrackSegment.tscn"

const SAMPLE_HALF_PX: int = 14
const GROUND_STRIP_TOP_FRAC: float = 0.92

const CONTRAST_FLOOR: float = 3.0
const HUE_MIN_SEPARATION: float = 45.0

const CROP_PAD_PX: int = 36
const CROP_MAX_DIM: int = 260

const OUT_PNG_PATH := "res://docs/color-sheets/enemy_rat_colour_sheet.png"

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

## label -> measurement Dictionary, insertion order preserved (Godot
## Dictionaries are ordered), so the PNG/table walk the same sequence
## this script measured them in.
var _results: Dictionary = {}
## label -> Image (deep-phase crop), kept separate from _results so a
## measurement failure never silently drops a crop key lookup.
var _crops: Dictionary = {}

## AXIS A -- bright band. Hues picked up front from the hue-window maths
## (see this file's class doc); S/V picked with ONE real-measurement
## correction pass, same convention TrackSegment.gd's ground-tint comment
## documents ("un premier essai ... corrigé après mesure, pas par calcul
## sur papier"). FIRST PASS at S=0.55/V=1.00 measured A4's WCAG contrast
## at 1.62:1 -- the blue-violet family has almost no green channel at any
## hue in its safe window, and WCAG weights green at 0.7152, so "bright"
## (high V) does not mean "high luminance" once saturation pushes green
## toward zero. A4 is desaturated (not just brightened) to raise green
## back into the mix; B1/B2 are darkened further for the same reason in
## the opposite direction (their green was still leaking too much
## luminance in). The FIRST-PASS numbers are reported in this session's
## final report, not hidden -- they are the actual finding.
const AXIS_A: Array = [
	{"label": "A1 Green (center of the only wide safe window)", "h": 122.0, "s": 0.55, "v": 1.0},
	{"label": "A2 Yellow-green (JUMP-adjacent edge of window)", "h": 105.0, "s": 0.55, "v": 1.0},
	{"label": "A3 Teal-green (STOMPER-adjacent edge of window)", "h": 145.0, "s": 0.55, "v": 1.0},
	{"label": "A4 Blue-violet (desaturated to clear the WCAG floor -- see report)", "h": 264.0, "s": 0.20, "v": 1.0},
]

## AXIS B -- dark band, only DODGE (8.1 deg) to avoid. See AXIS_A's
## comment above for why S/V needed a real-measurement correction pass.
const AXIS_B: Array = [
	{"label": "B1 Dark blue-gray (darkened to clear the WCAG floor -- see report)", "h": 220.0, "s": 0.60, "v": 0.11},
	{"label": "B2 Dark green-brown (darkened+resaturated to clear the WCAG floor -- see report)", "h": 140.0, "s": 0.75, "v": 0.10},
	{"label": "B3 Dark plum", "h": 280.0, "s": 0.55, "v": 0.20},
]

## As literally described in the brief. NOT what the repo actually ships
## today (see the "shipped" reference below) -- measured anyway, exactly
## the same way, so the brief's own reference number is on the record.
const BRIEF_CLAIMED_PINK := Color(0.9608, 0.8980, 0.9137, 1.0)

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- see
	# ProbeWatchdog.gd. This script is not gated, but every scripts/dev/
	# entry point still owes the timeout guarantee ProbeTimeoutAudit checks.
	ProbeWatchdog.arm(self, "EnemyColourSheetAxis")
	_run.call_deferred()

func _run() -> void:
	_build_calibration_scene()
	await _wait_frames(SETTLE_FRAMES)
	GameState.state = GameState.State.PLAYING

	print("=== ENEMY (rat) colour-sheet recon -- bright + dark axis hunt ===")
	print("")

	# ---- Reference hazards, measured for real -- never trusted from docs.
	print("--- Reference hazards (measured this run) ---")
	for type in [Obstacle.Type.DODGE, Obstacle.Type.JUMP, Obstacle.Type.STOMPER, Obstacle.Type.CHARGER]:
		var label: String = Obstacle.Type.keys()[type]
		var rec := await _measure_type(label, type, null, true)
		_print_row(rec)

	# ---- ENEMY: shipped reality, then the brief's claimed colour.
	print("")
	print("--- ENEMY reference rows ---")
	var shipped := await _measure_type("ENEMY shipped (actual .glb albedo, no override)", Obstacle.Type.ENEMY, null, true)
	_print_row(shipped)
	var brief_pink := await _measure_type("ENEMY brief-claimed pink (NOT what ships -- see report)", Obstacle.Type.ENEMY, BRIEF_CLAIMED_PINK, true)
	_print_row(brief_pink)

	# ---- AXIS A: bright band.
	print("")
	print("--- AXIS A: bright band, hue >45deg from CHARGER/JUMP/STOMPER ---")
	for c in AXIS_A:
		var color := Color.from_hsv(float(c.h) / 360.0, c.s, c.v, 1.0)
		var rec := await _measure_type(String(c.label), Obstacle.Type.ENEMY, color, true)
		_print_row(rec)

	# ---- AXIS B: dark band.
	print("")
	print("--- AXIS B: dark band, hue >45deg from DODGE ---")
	for c in AXIS_B:
		var color := Color.from_hsv(float(c.h) / 360.0, c.s, c.v, 1.0)
		var rec := await _measure_type(String(c.label), Obstacle.Type.ENEMY, color, true)
		_print_row(rec)

	print("")
	print("=== Writing composite PNG to %s ===" % OUT_PNG_PATH)
	await _compose_png()
	print("DONE")
	get_tree().quit(0)

# =====================================================================
# CALIBRATION SCENE -- copied pattern from DarkPaletteAudit.gd. Env,
# light and ground material are READ from the shipped scenes, never
# hand-copied, so this cannot drift the way a hardcoded palette did.
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
	box.size = Vector3(6, 0.4, 40)
	ground_mesh.mesh = box
	ground_mesh.set_surface_override_material(0, _scene_ground_material(TRACK_SEGMENT_SCENE_PATH))
	ground_mesh.position = Vector3(0, -0.2, -10)
	_root3d.add_child(ground_mesh)

	_camera = Camera3D.new()
	_root3d.add_child(_camera)
	# CameraFollow's own converged steady-state against a target fixed at
	# (0,1,0): offset (0,4.2,7), look_ahead (0,1,-4) -- read from
	# scripts/camera/CameraFollow.gd's @export defaults, not guessed.
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

# =====================================================================
# MEASUREMENT
# =====================================================================

## Configures `_obstacle` as `type`, optionally overriding ENEMY's real
## per-instance material albedo (candidate colours), and measures it at
## BOTH ends of the mist breath -- the gated number this project reports
## is always the worst of the two, per DarkPaletteAudit's own convention.
func _measure_type(label: String, type: Obstacle.Type, albedo_override, capture_crop: bool) -> Dictionary:
	var rec := {"label": label, "type": type, "override": albedo_override}
	for phase in [{"key": "shallow", "intensity": 0.0}, {"key": "deep", "intensity": 1.0}]:
		GameState.mist_intensity = phase.intensity
		_obstacle.configure(type)
		_reset_obstacle_pose()
		if albedo_override != null and type == Obstacle.Type.ENEMY and _obstacle._enemy_material:
			_obstacle._enemy_material.albedo_color = albedo_override
		await _wait_frames(SETTLE_FRAMES)
		# Re-apply AFTER the settle wait too: CHARGER/STOMPER move
		# themselves once GameState.state == PLAYING (DarkPaletteAudit's
		# own documented reason for double-resetting the pose).
		_obstacle.configure(type)
		_reset_obstacle_pose()
		if albedo_override != null and type == Obstacle.Type.ENEMY and _obstacle._enemy_material:
			_obstacle._enemy_material.albedo_color = albedo_override
		await _wait_frames(1)

		var ground := _sample_strip(GROUND_STRIP_TOP_FRAC, 1.0)
		var point := _obstacle_sample_point(type)
		var color := _sample_point(point)
		var ratio := _contrast_ratio(color, ground)
		rec[phase.key + "_color"] = color
		rec[phase.key + "_ground"] = ground
		rec[phase.key + "_ratio"] = ratio

		if capture_crop and phase.key == "deep":
			_crops[label] = _capture_crop(_obstacle_sample_bounds(type))

	rec["worst_ratio"] = minf(rec["shallow_ratio"], rec["deep_ratio"])
	# Hue/sat/val reported from the DEEP-phase colour: SwampAtmosphere only
	# ever touches sky/haze/fog_density (see its own header, "no hazard...
	# changes colour as the breath moves"), so hue is expected to be
	# phase-invariant for gameplay objects -- verified per-row below by
	# also keeping the shallow colour on the record.
	var deep_color: Color = rec["deep_color"]
	rec["hue"] = deep_color.h * 360.0
	rec["sat"] = deep_color.s
	rec["val"] = deep_color.v
	_results[label] = rec
	return rec

func _reset_obstacle_pose() -> void:
	_obstacle.position = Vector3(0.0, 0.0, CAPTURE_Z)
	_obstacle.rotation = Vector3.ZERO

## World-space centre of the mesh actually drawn for `type` -- merged AABB
## of every visible VisualInstance3D under the named slot, so this keeps
## working whether the slot is a placeholder primitive or an imported
## .glb child. Copied pattern from DarkPaletteAudit._obstacle_sample_point.
func _obstacle_sample_point(type: Obstacle.Type) -> Vector3:
	var b := _obstacle_sample_bounds(type)
	return b.get_center()

func _obstacle_sample_bounds(type: Obstacle.Type) -> AABB:
	var slot := _obstacle.get_node_or_null(NodePath(MESH_NODE_FOR_TYPE[type]))
	if slot == null:
		push_error("EnemyColourSheetAxis: no mesh node '%s' on Obstacle." % MESH_NODE_FOR_TYPE[type])
		return AABB(_obstacle.global_position, Vector3.ONE * 0.1)
	var merged := AABB()
	var any := false
	for node in _visual_descendants(slot):
		var box: AABB = node.global_transform * node.get_aabb()
		if box.size == Vector3.ZERO:
			continue
		merged = box if not any else merged.merge(box)
		any = true
	if not any:
		push_error("EnemyColourSheetAxis: mesh node '%s' draws nothing measurable." % MESH_NODE_FOR_TYPE[type])
		return AABB(_obstacle.global_position, Vector3.ONE * 0.1)
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
# DarkPaletteAudit.gd (same formulas, same box-sampling strategy).
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
		push_error("EnemyColourSheetAxis: sample box (%d,%d) half=%d off-screen." % [cx, cy, half])
		return Color(0, 0, 0)
	acc /= float(samples)
	return Color(acc.x, acc.y, acc.z)

## Crops the rendered frame down to `bounds`' projected screen rect, with
## padding, for the composite PNG -- a real render, not a flat swatch.
func _capture_crop(bounds: AABB) -> Image:
	var img: Image = get_viewport().get_texture().get_image()
	var visible_size := get_viewport().get_visible_rect().size
	var sx := float(img.get_width()) / maxf(visible_size.x, 1.0)
	var sy := float(img.get_height()) / maxf(visible_size.y, 1.0)
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for i in 8:
		var corner := bounds.position + Vector3(
			bounds.size.x if (i & 1) else 0.0,
			bounds.size.y if (i & 2) else 0.0,
			bounds.size.z if (i & 4) else 0.0)
		var s := _camera.unproject_position(corner)
		s.x *= sx
		s.y *= sy
		minp.x = minf(minp.x, s.x)
		minp.y = minf(minp.y, s.y)
		maxp.x = maxf(maxp.x, s.x)
		maxp.y = maxf(maxp.y, s.y)
	var x0 := maxi(0, int(minp.x) - CROP_PAD_PX)
	var y0 := maxi(0, int(minp.y) - CROP_PAD_PX)
	var x1 := mini(img.get_width(), int(maxp.x) + CROP_PAD_PX)
	var y1 := mini(img.get_height(), int(maxp.y) + CROP_PAD_PX)
	if x1 <= x0 or y1 <= y0:
		push_error("EnemyColourSheetAxis: crop rect degenerate, off-screen object.")
		var fallback := Image.create(CROP_MAX_DIM, CROP_MAX_DIM, false, Image.FORMAT_RGB8)
		fallback.fill(Color.MAGENTA)
		return fallback
	var crop := img.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
	# Downscale the long edge to CROP_MAX_DIM so the composite stays a
	# reasonable size regardless of how close/far an object's AABB reads.
	var longest := maxi(crop.get_width(), crop.get_height())
	if longest > CROP_MAX_DIM:
		var scale := float(CROP_MAX_DIM) / float(longest)
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
		push_error("EnemyColourSheetAxis: no WorldEnvironment.environment found in %s" % scene_path)
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
	push_error("EnemyColourSheetAxis: no DirectionalLight3D found in %s" % scene_path)
	return light

func _scene_ground_material(scene_path: String) -> StandardMaterial3D:
	var packed: PackedScene = load(scene_path)
	var value: Variant = _scene_property(packed, "surface_material_override/0")
	var mat := value as StandardMaterial3D
	if mat == null:
		push_error("EnemyColourSheetAxis: no ground surface_material_override/0 found in %s" % scene_path)
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
	var flag := _flag_string(rec, d_charger, d_jump, d_stomper, d_dodge)
	print("%-58s hue=%6.1f sat=%.2f val=%.2f | shallow=%.2f:1 deep=%.2f:1 worst=%.2f:1 | dHue vs C/J/S/D = %s/%s/%s/%s %s" % [
		rec.label, rec.hue, rec.sat, rec.val,
		rec.shallow_ratio, rec.deep_ratio, rec.worst_ratio,
		_fmt_dist(d_charger), _fmt_dist(d_jump), _fmt_dist(d_stomper), _fmt_dist(d_dodge),
		flag,
	])

func _fmt_dist(d) -> String:
	if d == null:
		return "n/a"
	return "%.1f" % d

## null when `rec` itself IS that reference (distance to self is
## meaningless, not zero-and-flagged).
func _hue_distance_to(rec: Dictionary, ref_label: String):
	if not _results.has(ref_label):
		return null
	if String(rec.label) == ref_label:
		return null
	return _hue_distance(rec.hue, _results[ref_label].hue)

func _flag_string(rec: Dictionary, d_c, d_j, d_s, d_d) -> String:
	var reasons: Array[String] = []
	if rec.worst_ratio < CONTRAST_FLOOR:
		reasons.append("BELOW CONTRAST FLOOR")
	for pair in [["CHARGER", d_c], ["JUMP", d_j], ["STOMPER", d_s], ["DODGE", d_d]]:
		if pair[1] != null and float(pair[1]) < HUE_MIN_SEPARATION:
			reasons.append("HUE TOO CLOSE TO %s" % pair[0])
	if reasons.is_empty():
		return ""
	return "  <<< RED FLAG: " + ", ".join(reasons)

# =====================================================================
# PNG COMPOSITE
# =====================================================================

const CANVAS_W: int = 1500
const ROW_H: int = 190
const CROP_CELL: int = 160
const SWATCH_CELL: int = 160
const TEXT_X: int = 20 + CROP_CELL + 12 + SWATCH_CELL + 20
const TEXT_W: int = CANVAS_W - TEXT_X - 20

## Header/row constants shared between the text-pass (_draw(), which
## renders background/section headers/swatches/text through the normal
## GPU 2D pipeline -- proven correct: draw_rect fills of the exact
## measured colours came back pixel-correct) and the post-pass below
## (which blits crop PIXELS directly onto the finished Image).
const HEADER_H: int = 130

func _row_layout(order: Array[String], section_breaks: Dictionary) -> Dictionary:
	var layout := {}
	var y := HEADER_H
	for i in order.size():
		if section_breaks.has(i):
			y += 40
		layout[String(order[i])] = y
		y += ROW_H
	return layout

func _compose_png() -> void:
	var order: Array[String] = []
	order.append_array(["DODGE", "JUMP", "STOMPER", "CHARGER"])
	order.append("ENEMY shipped (actual .glb albedo, no override)")
	order.append("ENEMY brief-claimed pink (NOT what ships -- see report)")
	for c in AXIS_A:
		order.append(String(c.label))
	for c in AXIS_B:
		order.append(String(c.label))

	var section_breaks := {
		4: "ENEMY REFERENCE ROWS",
		6: "AXIS A -- bright band, >45deg from CHARGER / JUMP / STOMPER",
		10: "AXIS B -- dark band, >45deg from DODGE",
	}

	var rows := 0
	for i in order.size():
		if section_breaks.has(i):
			rows += 1
		rows += 1
	var canvas_h := HEADER_H + rows * ROW_H + 40
	var row_y := _row_layout(order, section_breaks)

	var sub := SubViewport.new()
	sub.size = Vector2i(CANVAS_W, canvas_h)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.transparent_bg = false
	add_child(sub)

	var canvas := ColourSheetCanvas.new()
	canvas.size = Vector2(CANVAS_W, canvas_h)
	canvas.custom_minimum_size = Vector2(CANVAS_W, canvas_h)
	canvas.results = _results
	canvas.order = order
	canvas.section_breaks = section_breaks
	canvas.row_y = row_y
	canvas.hue_distance_fn = Callable(self, "_hue_distance_to")
	canvas.flag_fn = Callable(self, "_flag_string")
	sub.add_child(canvas)

	await _wait_frames(1)
	canvas.queue_redraw()
	await _wait_frames(3)

	var out_img: Image = sub.get_texture().get_image()
	out_img.convert(Image.FORMAT_RGBA8)

	# ------------------------------------------------------------------
	# CROPS ARE BLITTED HERE, IN PLAIN CPU PIXEL COPY -- NOT DRAWN VIA
	# draw_texture_rect() IN THE CONTROL ABOVE, AND THAT IS DELIBERATE.
	#
	# draw_texture_rect() on an ImageTexture built from a captured
	# viewport crop rendered every crop cell as FLAT WHITE in this
	# sandbox (llvmpipe/Mesa under xvfb), even though everything else
	# proved the data was correct at every other checkpoint measured
	# while chasing this down: the crop Image saved straight to disk
	# showed the real hazard silhouette correctly, and so did
	# tex.get_image() -- reading the ImageTexture straight back off
	# a SubViewport's CanvasItem pipeline was blank. Solid draw_rect()
	# fills (the swatches, the backgrounds, the section bars) were NEVER
	# affected -- only texture sampling was -- which is what narrows it
	# to the 2D texture-draw path specifically, not a viewport-wide
	# tonemap/colour-space problem (that would have blown out the
	# swatches too, and it did not).
	#
	# Rather than chase a renderer/driver quirk that may be specific to
	# this one sandbox's software GL stack, the fix sidesteps the whole
	# GPU 2D draw path for crops: copy pixels directly into the already-
	# rendered composite Image via Image.blit_rect(), after the text
	# pass has finished. No shader, no texture sampler, no colour-space
	# conversion in between -- just bytes.
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
		var y: int = row_y[label]
		var dst_x := 20 + int((CROP_CELL - dw) / 2.0)
		var dst_y := y + int((CROP_CELL - dh) / 2.0)
		out_img.blit_rect(crop, Rect2i(0, 0, dw, dh), Vector2i(dst_x, dst_y))

	var err := out_img.save_png(OUT_PNG_PATH)
	if err != OK:
		push_error("EnemyColourSheetAxis: save_png failed with error %d" % err)
	else:
		print("Saved %dx%d PNG to %s" % [out_img.get_width(), out_img.get_height(), OUT_PNG_PATH])

## Inner Control that draws the whole composite in one _draw() pass:
## crop thumbnail, flat swatch (the REAL measured rendered colour, not a
## hand-typed hex) and a text block per row.
class ColourSheetCanvas:
	extends Control

	var results: Dictionary = {}
	var order: Array = []
	var section_breaks: Dictionary = {}
	## label -> top-of-row y, computed once by the owning script
	## (_row_layout) so the post-pass crop blit lands on the exact same
	## pixels this draw pass reserves for it with the empty-cell border.
	var row_y: Dictionary = {}
	var hue_distance_fn: Callable
	var flag_fn: Callable

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.08, 1.0))
		draw_string(font, Vector2(20, 34), "ENEMY (rat) resting-albedo colour sheet -- axis hunt vs CHARGER/JUMP/STOMPER/DODGE",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 24, Color(1, 1, 1))
		draw_string(font, Vector2(20, 60), "Real game camera + real hazard meshes + real fog/mist breath. Contrast floor 3.0:1. Hue separation floor 45deg (all four hazards).",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 15, Color(0.75, 0.78, 0.75))
		draw_string(font, Vector2(20, 82), "Crop = real render at CAPTURE_Z. Swatch = the SAME rendered pixel's colour, flat. REFERENCE HAZARDS measured this run, not assumed from docs.",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 15, Color(0.9, 0.9, 0.6))

		var row_h := 190
		var crop_cell := 160
		var swatch_cell := 160
		var text_x := 20 + crop_cell + 12 + swatch_cell + 20
		var text_w := int(size.x) - text_x - 20

		for i in order.size():
			var label: String = String(order[i])
			if not row_y.has(label):
				continue
			var y: int = row_y[label]
			if section_breaks.has(i):
				draw_rect(Rect2(0, y - 40, size.x, 34), Color(0.16, 0.18, 0.14, 1.0))
				draw_string(font, Vector2(20, y - 17), String(section_breaks[i]),
					HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 19, Color(0.95, 0.95, 0.55))
			if not results.has(label):
				continue
			var rec: Dictionary = results[label]

			# Crop CELL is only framed here -- the pixels themselves are
			# blitted onto the finished Image by the owning script
			# (_compose_png), CPU-side, after this draw pass. See that
			# function's own comment for why draw_texture_rect() is not
			# used for this.
			draw_rect(Rect2(20, y, crop_cell, crop_cell), Color(0.15, 0.15, 0.15, 1), false, 1.0)

			# Flat swatch of the real measured deep-phase colour
			var deep_c: Color = rec.get("deep_color", Color.MAGENTA)
			draw_rect(Rect2(20 + crop_cell + 12, y, swatch_cell, crop_cell), deep_c)
			draw_rect(Rect2(20 + crop_cell + 12, y, swatch_cell, crop_cell), Color(0.15, 0.15, 0.15, 1), false, 1.0)

			# Text block
			var d_c: Variant = hue_distance_fn.call(rec, "CHARGER")
			var d_j: Variant = hue_distance_fn.call(rec, "JUMP")
			var d_s: Variant = hue_distance_fn.call(rec, "STOMPER")
			var d_d: Variant = hue_distance_fn.call(rec, "DODGE")
			var flag: String = flag_fn.call(rec, d_c, d_j, d_s, d_d)

			var lines := PackedStringArray()
			lines.append(label)
			lines.append("H=%.1fdeg  S=%.2f  V=%.2f    RGB rendered=(%.3f, %.3f, %.3f)" % [
				rec.hue, rec.sat, rec.val, deep_c.r, deep_c.g, deep_c.b])
			lines.append("contrast vs ground: shallow=%.2f:1  deep=%.2f:1  worst(gated)=%.2f:1  (floor 3.0:1)" % [
				rec.shallow_ratio, rec.deep_ratio, rec.worst_ratio])
			lines.append("hue distance -> CHARGER=%s  JUMP=%s  STOMPER=%s  DODGE=%s  (floor 45deg)" % [
				_fmt(d_c), _fmt(d_j), _fmt(d_s), _fmt(d_d)])
			if flag != "":
				lines.append(flag)
			else:
				lines.append("OK -- clears the contrast floor and all four hue-distance floors")

			var text_color := Color(1, 0.55, 0.55) if flag != "" else Color(0.85, 0.9, 0.85)
			var ty := y + 4
			for li in lines.size():
				var line_color := text_color if li == lines.size() - 1 else Color(0.85, 0.87, 0.85)
				if li == 0:
					line_color = Color(1, 1, 1)
				draw_string(font, Vector2(text_x, ty + 18), String(lines[li]),
					HORIZONTAL_ALIGNMENT_LEFT, text_w, 16, line_color)
				ty += 26

	func _fmt(d) -> String:
		if d == null:
			return "n/a"
		return "%.1f" % d
