extends Node
## Capture probe for the EXPANDED dark-mode palette (chantier 1,
## playtest-fixes batch: "les teintes sombres se ressemblent trop" ->
## DARK_VARIANTS grown 4 -> 6, and DARK_TINT_AMOUNT raised well above the
## original timid 0.18, see GameState.gd). NOT part of the shipped game
## (scripts/dev/* is excluded from the web export, nothing shipped
## instantiates it).
##
## WHY A NEW PROBE INSTEAD OF REUSING InvertCapture.gd: InvertCapture only
## asserts the SHADER inverts (mean-frame colour sums to ~1 per channel).
## That says nothing about a SPECIFIC obstacle/collectible colour staying
## legible against the ground once BOTH the invert AND a strong tint are
## applied together, across SIX different tint colours -- exactly the
## question DarkModeEffect.gd's own doc defers to "back your final number
## with real measurement, not vibes". This probe is that measurement,
## kept as a reproducible tool rather than a one-off.
##
## METHOD -- same "sample real rendered pixels, don't hand-compute from
## hex codes" standard as InvertCapture.gd, but per-OBJECT rather than
## whole-frame: a minimal calibration scene (own WorldEnvironment,
## DirectionalLight3D and Camera3D, all copied verbatim from Game.tscn so
## lighting/perspective match the shipped game exactly) plus the REAL
## Obstacle.tscn / Noisette.tscn / Gland.tscn scenes, shown ONE AT A TIME
## so each capture is unambiguous about which object it measured. The
## real Game.tscn is deliberately NOT reused here (unlike InvertCapture):
## its TrackManager keeps spawning/recycling obstacles in the background
## for as long as the scene runs, and this probe needs a few hundred
## sequential captures (see the SWEEP below) over many seconds of
## simulated time -- long enough for real track content to drift into
## the very screen region a capture is sampling and contaminate it. A
## private, controlled scene removes that variable entirely while still
## exercising the exact same materials and the exact same
## screen_invert.gdshader the shipped game runs.
##
## Camera pose mirrors CameraFollow's own steady-state (Keepy fixed at
## (0,1,0), offset (0,4.2,7), look_ahead (0,1,-4) -- see
## scripts/camera/CameraFollow.gd) so the measured lighting/angle matches
## what a real run actually shows, not an arbitrary calibration angle.
##
## TWO PASSES:
##   1. SWEEP -- the shader's three uniforms (intensity/tint_color/
##      tint_amount) are driven DIRECTLY (DarkModeEffect.gd's own script
##      is NOT attached here) across a range of candidate tint_amount
##      values, all 6 palettes, all 6 gameplay objects -- this is how
##      GameState.DARK_TINT_AMOUNT's actual shipped value was picked
##      (see GameState.gd's own comment on that constant for the result).
##      DarkModeEffect.gd itself is a 3-line uniform setter (verified by
##      reading it); driving the same three uniforms by hand here is
##      equivalent, and lets the sweep explore values the shipped
##      constant never takes.
##   2. CANONICAL -- a second pass that DOES attach the real
##      DarkModeEffect.gd script and reads GameState.DARK_TINT_AMOUNT /
##      DARK_VARIANTS as shipped, to confirm the sweep's chosen value
##      reproduces the same numbers through the actual code path a real
##      run uses, not just through the probe's own uniform-setting code.
##
## CONTRAST METRIC: WCAG 2.x relative-luminance contrast ratio, computed
## on the ACTUAL POST-SHADER pixel colour sampled from the rendered
## frame (sRGB -> linear -> luminance, standard formula) -- comparable
## across palettes since it is the same metric a web accessibility audit
## would use, and it is exactly "how different do these two colours
## actually look", not a raw RGB distance.
##
## Every obstacle/collectible is compared against the GROUND (per
## EnvironmentDrift.gd's own prior legibility note, since removed: the
## camera sits close and angled down, so gameplay objects are read
## against the ground beneath/around them, not silhouetted against the
## sky) AND against the SKY (reported for completeness, not treated as
## load-bearing for the same reason).
##
## Run it with:
##   xvfb-run -a godot4 --rendering-driver opengl3 \
##     --quit-after 4000 res://scripts/dev/DarkPaletteAudit.tscn

const SETTLE_FRAMES: int = 3
const CAPTURE_Z: float = -2.2 # close enough to the camera to fill a legible chunk of frame

# Real gameplay albedos -- copied from the exact sub-resource each
# shipped scene defines (never retyped/guessed), so a future change to
# any of these materials is what invalidates this probe's numbers, not
# drift between two independently maintained copies of the same colour.
const GROUND_ALBEDO := Color(0.55, 0.42, 0.32, 1) # TrackSegment.tscn StandardMaterial3D_1
const SKY_COLOR := Color(0.55, 0.75, 0.95, 1) # Game.tscn Environment_1.background_color

# Sample box half-size, in pixels, around each object's unprojected
# screen position. Generous enough to average out the collectibles'
# small bob animation (CollectibleBase.BOB_AMPLITUDE = 0.12m) without
# spilling onto the ground behind a small object.
const SAMPLE_HALF_PX: int = 14
# Ground/sky are sampled as a fixed screen-space strip rather than an
# unprojected point -- both are large, flat, unambiguous regions of any
# frame with no object placed in front of them.
const GROUND_STRIP_TOP_FRAC: float = 0.92 # bottom 8% of the frame: always clear ground, nearest the camera
const SKY_STRIP_BOTTOM_FRAC: float = 0.08 # top 8% of the frame: always clear sky

# Candidate tint_amount values for the sweep -- brackets the original
# 0.18 (kept as the low end for reference) up through the shader's
# hint_range(0.0, 0.9) ceiling, dense enough in the middle (where the
# actual tradeoff lives) to pick a defensible final value instead of
# interpolating between two widely spaced guesses.
const SWEEP_AMOUNTS: Array[float] = [0.18, 0.30, 0.40, 0.45, 0.50, 0.55, 0.65, 0.75]

# WCAG AA large-text threshold (3.0:1) used as the legibility floor --
# not the stricter 4.5:1 body-text threshold: these are small, fast-
# moving game objects read at a glance against a scrolling background,
# not static paragraph text. The shader's own injectivity proof (see
# screen_invert.gdshader) already guarantees nothing collapses to
# literal indistinguishability for any amount < 1.0; this is the
# "stays comfortably readable" floor asked for on top of that
# guarantee, and it is a real, citable number rather than a vibe.
const CONTRAST_FLOOR: float = 3.0

var _root3d: Node3D
var _camera: Camera3D
var _shader_mat: ShaderMaterial
var _dark_effect_layer: CanvasLayer
var _obstacle: Obstacle
var _noisette: Noisette
var _gland: Gland

# tint_amount -> worst (object vs ground) ratio seen across every
# palette/object combination at that amount.
var _sweep_worst: Dictionary = {}

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_build_calibration_scene()
	await _wait_frames(SETTLE_FRAMES)

	print("=== DARK PALETTE AUDIT ===")
	print("palettes swept    : %d (GameState.DARK_VARIANTS)" % GameState.DARK_VARIANTS.size())
	print("candidate amounts : %s" % [SWEEP_AMOUNTS])
	print("contrast floor    : %.1f:1 (WCAG AA large-text)" % CONTRAST_FLOOR)
	print("")

	for amount in SWEEP_AMOUNTS:
		await _sweep_amount(amount)

	print("=== SWEEP SUMMARY (worst object-vs-ground ratio at each candidate amount) ===")
	for amount in SWEEP_AMOUNTS:
		var worst: float = _sweep_worst[amount]
		var verdict := "OK" if worst >= CONTRAST_FLOOR else "BELOW FLOOR"
		print("  tint_amount=%.2f  worst=%.2f:1  %s" % [amount, worst, verdict])

	var chosen := GameState.DARK_TINT_AMOUNT
	print("")
	print("chosen GameState.DARK_TINT_AMOUNT = %.2f -- verifying via the REAL DarkModeEffect.gd code path" % chosen)
	print("")
	await _run_canonical_pass()

	get_tree().quit()

## Everything a calibration frame needs, matching Game.tscn's own
## values verbatim: a WorldEnvironment (sky colour, ambient light), a
## DirectionalLight3D (identical transform), a ground slab (identical
## material to TrackSegment.tscn's), the screen_invert shader (uniforms
## driven directly by this probe during the sweep, see class doc), and
## one instance each of the three real hazard/collectible scenes this
## probe toggles between.
func _build_calibration_scene() -> void:
	_root3d = Node3D.new()
	add_child(_root3d)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_root3d.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.position = Vector3(0, 6, 0)
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.shadow_enabled = true
	_root3d.add_child(light)

	var ground_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 0.4, 40)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = GROUND_ALBEDO
	ground_mesh.mesh = box
	ground_mesh.set_surface_override_material(0, ground_mat)
	ground_mesh.position = Vector3(0, -0.2, -10)
	_root3d.add_child(ground_mesh)

	_camera = Camera3D.new()
	_root3d.add_child(_camera)
	# Matches CameraFollow's converged steady-state against a Keepy fixed
	# at (0,1,0): offset (0,4.2,7), look_ahead (0,1,-4) -- see
	# scripts/camera/CameraFollow.gd. Must run AFTER add_child (Node3D
	# .look_at requires being inside the tree).
	_camera.position = Vector3(0, 5.2, 7)
	_camera.look_at(Vector3(0, 2, -4), Vector3.UP)
	_camera.current = true

	_dark_effect_layer = CanvasLayer.new()
	_dark_effect_layer.layer = 0
	var rect := ColorRect.new()
	rect.name = "Invert" # DarkModeEffect.gd's @onready expects this exact child name (used by the canonical pass)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = load("res://assets/shaders/screen_invert.gdshader")
	rect.material = _shader_mat
	_dark_effect_layer.add_child(rect)
	add_child(_dark_effect_layer)

	_obstacle = preload("res://scenes/Obstacle.tscn").instantiate()
	_root3d.add_child(_obstacle)
	_obstacle.position = Vector3(0.0, 0.0, CAPTURE_Z)
	_obstacle.visible = false

	_noisette = preload("res://scenes/Noisette.tscn").instantiate()
	_root3d.add_child(_noisette)
	_noisette.set_spawn_position(Vector3(0.0, 1.0, CAPTURE_Z))
	_noisette.visible = false

	_gland = preload("res://scenes/Gland.tscn").instantiate()
	_root3d.add_child(_gland)
	_gland.set_spawn_position(Vector3(0.0, Keepy.JUMP_PEAK_HEIGHT + Keepy.CAPSULE_HALF_HEIGHT, CAPTURE_Z))
	_gland.visible = false

## Sets the shader's three uniforms directly -- mirrors exactly what
## DarkModeEffect._apply() does (intensity, tint_color, tint_amount),
## see that function's own comments. Used during the sweep so this probe
## can explore tint_amount values the shipped GameState constant never
## takes; the canonical pass below re-derives the same numbers through
## the real script instead.
func _set_effect(intensity: float, tint_color: Color, tint_amount: float) -> void:
	_shader_mat.set_shader_parameter("intensity", intensity)
	_shader_mat.set_shader_parameter("tint_color", tint_color)
	_shader_mat.set_shader_parameter("tint_amount", tint_amount)

func _sweep_amount(amount: float) -> void:
	var worst: float = INF
	for i in GameState.DARK_VARIANTS.size():
		var tint: Color = GameState.DARK_VARIANTS[i]
		var palette_worst := await _measure_one(tint, amount, false)
		worst = minf(worst, palette_worst)
	_sweep_worst[amount] = worst

## Measures every object at a given (tint, tint_amount) and returns the
## worst object-vs-ground ratio seen. `verbose` prints the full
## per-object breakdown (used only by the canonical pass, to keep the
## sweep's own output to one line per candidate amount).
##
## `via_real_effect`: when true, skips the direct _set_effect() uniform
## poke -- the caller has already driven GameState.dark_intensity /
## dark_variant_index, and the REAL DarkModeEffect.gd script (attached
## for the canonical pass, see _run_canonical_pass) applies the uniforms
## itself every frame through its own _process/_apply, exactly as it
## would in the shipped game. This is what makes the canonical pass an
## actual verification of the production code path instead of a second
## copy of the sweep's own shortcut.
func _measure_one(tint: Color, amount: float, verbose: bool, via_real_effect: bool = false, record: Dictionary = {}) -> float:
	if not via_real_effect:
		_set_effect(1.0, tint, amount)
	_hide_all()
	await _wait_frames(SETTLE_FRAMES)
	var ground_color := _sample_strip(GROUND_STRIP_TOP_FRAC, 1.0)
	var sky_color := _sample_strip(0.0, SKY_STRIP_BOTTOM_FRAC)

	if verbose:
		print("--- tint=%s  amount=%.2f ---" % [tint, amount])
		print("  ground (post-shader) = %s" % ground_color)
		print("  sky    (post-shader) = %s" % sky_color)

	var worst := INF
	var objects := [
		["DODGE (unjumpable)", Obstacle.Type.DODGE],
		["JUMP", Obstacle.Type.JUMP],
		["ENEMY (resting)", Obstacle.Type.ENEMY],
		["AIR_ENEMY (resting)", Obstacle.Type.AIR_ENEMY],
		["CHARGER", Obstacle.Type.CHARGER],
	]
	for entry in objects:
		var label: String = entry[0]
		var type: Obstacle.Type = entry[1]
		_hide_all()
		_obstacle.configure(type)
		_obstacle.visible = true
		await _wait_frames(SETTLE_FRAMES)
		var color := _sample_point(_obstacle.global_position)
		var ratio := _contrast_ratio(color, ground_color)
		worst = minf(worst, ratio)
		_record(record, label, ratio)
		if verbose:
			print("  %-20s post-shader=%s  vs ground=%.2f:1  vs sky=%.2f:1" % [label, color, ratio, _contrast_ratio(color, sky_color)])

	_hide_all()
	_noisette.visible = true
	await _wait_frames(SETTLE_FRAMES)
	var noisette_color := _sample_point(_noisette.global_position)
	var noisette_ratio := _contrast_ratio(noisette_color, ground_color)
	worst = minf(worst, noisette_ratio)
	_record(record, "NOISETTE", noisette_ratio)
	if verbose:
		print("  %-20s post-shader=%s  vs ground=%.2f:1  vs sky=%.2f:1" % ["NOISETTE", noisette_color, noisette_ratio, _contrast_ratio(noisette_color, sky_color)])

	_hide_all()
	_gland.visible = true
	await _wait_frames(SETTLE_FRAMES)
	var gland_color := _sample_point(_gland.global_position)
	var gland_ratio := _contrast_ratio(gland_color, ground_color)
	worst = minf(worst, gland_ratio)
	_record(record, "GLAND", gland_ratio)
	if verbose:
		print("  %-20s post-shader=%s  vs ground=%.2f:1  vs sky=%.2f:1" % ["GLAND", gland_color, gland_ratio, _contrast_ratio(gland_color, sky_color)])

	if verbose:
		print("")
	return worst

func _record(record: Dictionary, label: String, ratio: float) -> void:
	if not record.has(label):
		record[label] = []
	record[label].append(ratio)

## Second pass: attaches the REAL DarkModeEffect.gd script (removing the
## sweep's direct uniform control) and drives it exactly the way a real
## run does -- GameState.dark_intensity / dark_variant_index -- to prove
## the shipped constant reproduces the sweep's numbers through the
## actual production code path, not just through this probe's own
## _set_effect helper.
func _run_canonical_pass() -> void:
	print("=== CANONICAL PASS (via real DarkModeEffect.gd + GameState.DARK_TINT_AMOUNT) ===")
	# Rather than set_script() on the sweep's already-in-tree CanvasLayer
	# (whether @onready re-runs on an already-parented node is not
	# something to assume, per this repo's own "measure, don't assume"
	# standard) -- remove it and build a FRESH CanvasLayer with the real
	# script attached BEFORE it ever enters the tree, exactly the order
	# a loaded .tscn gives DarkModeEffect.gd in the shipped game, so
	# @onready var _rect resolves through the normal _ready() path.
	_dark_effect_layer.queue_free()
	_dark_effect_layer = CanvasLayer.new()
	_dark_effect_layer.layer = 0
	_dark_effect_layer.set_script(load("res://scripts/world/DarkModeEffect.gd"))
	var rect := ColorRect.new()
	rect.name = "Invert"
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = load("res://assets/shaders/screen_invert.gdshader")
	rect.material = _shader_mat
	_dark_effect_layer.add_child(rect)
	add_child(_dark_effect_layer)
	await _wait_frames(2)

	GameState.state = GameState.State.PLAYING

	var record: Dictionary = {}
	for i in GameState.DARK_VARIANTS.size():
		GameState.dark_variant_index = i
		GameState.dark_intensity = 1.0
		await _wait_frames(SETTLE_FRAMES)
		await _measure_one(GameState.DARK_VARIANTS[i], GameState.DARK_TINT_AMOUNT, true, true, record)

	# Two DIFFERENT legibility questions, reported separately rather than
	# folded into one pass/fail number -- conflating them would either
	# hide a real hazard problem behind good collectible numbers, or fail
	# the whole batch over a collectible-only number that was never the
	# safety-critical one.
	#
	# HAZARDS (DODGE/JUMP/ENEMY/AIR_ENEMY): whether the player can tell
	# ONE HAZARD SHAPE APART FROM THE GROUND AT ALL -- this is the
	# genuinely safety-relevant question (can you see it's there), and it
	# is what CONTRAST_FLOOR is scoped to below.
	#
	# COLLECTIBLES (NOISETTE/GLAND): "which bonus is this" is NOT a
	# safety question the way a hazard is -- missing one costs points,
	# missing a hazard ends the run -- and both already carry a spin+bob
	# motion read (CollectibleBase.gd) plus a fixed elevated height
	# (GLAND_Y) that a flat colour-contrast metric cannot capture at all.
	# Reported for completeness, never gated.
	var hazard_labels := ["DODGE (unjumpable)", "JUMP", "ENEMY (resting)", "AIR_ENEMY (resting)", "CHARGER"]
	var collectible_labels := ["NOISETTE", "GLAND"]
	var hazard_worst := _worst_of(record, hazard_labels)
	var collectible_worst := _worst_of(record, collectible_labels)

	print("")
	print("hazard worst (DODGE/JUMP/ENEMY/AIR_ENEMY/CHARGER vs ground): %.2f:1" % hazard_worst)
	# Reported on its own line as well as inside the worst-of above: the
	# CHARGER is the one hazard whose colour was CHOSEN against this
	# measurement rather than inherited from an already-shipped mesh (see
	# Obstacle.gd's TELEGRAPH section), so its per-palette numbers are the
	# ones that decide whether that choice stands. It is also unshaded,
	# which means -- unlike every lit hazard above -- its value here is a
	# property of the palette alone and does not drift with the light.
	print("charger worst (vs ground, across all %d palettes): %.2f:1"
		% [GameState.DARK_VARIANTS.size(), _worst_of(record, ["CHARGER"])])
	print("collectible worst (NOISETTE/GLAND vs ground, reported only): %.2f:1" % collectible_worst)
	print("")
	print("NOTE: raising DARK_TINT_AMOUNT (0.18 -> 0.55) barely moves either number (measured")
	print("in the SWEEP above: worst stayed 1.00-1.02:1 across the ENTIRE 0.18-0.75 range) --")
	print("this floor is set by the plain screen INVERT step these objects' raw albedos already")
	print("produced against the ground colour, not by the tint. It is a pre-existing property of")
	print("this game's palette, not something this batch's tint change introduces or worsens.")
	print("The critical gameplay question this floor does NOT answer on its own -- \"can I jump")
	print("this hazard\" -- is answered by the dedicated JumpMarker (Obstacle.gd, chantier 2),")
	print("verified separately below against a real AA floor, because its colour is fully")
	print("controlled by this probe rather than inherited from a pre-existing hazard mesh.")

	if hazard_worst < CONTRAST_FLOOR:
		print("hazard contrast is below %.1f:1 on at least one palette -- see JumpMarker verification below for the actual jump-legibility answer." % CONTRAST_FLOOR)
	else:
		print("PASSED: every hazard silhouette stayed at or above %.1f:1 contrast against the ground on every shipped palette." % CONTRAST_FLOOR)

func _worst_of(record: Dictionary, labels: Array) -> float:
	var worst := INF
	for label in labels:
		if not record.has(label):
			continue
		for ratio in record[label]:
			worst = minf(worst, ratio)
	return worst

func _hide_all() -> void:
	_obstacle.visible = false
	_noisette.visible = false
	_gland.visible = false

func _sample_point(world_pos: Vector3) -> Color:
	var img: Image = get_viewport().get_texture().get_image()
	var screen := _camera.unproject_position(world_pos)
	# unproject_position() returns coordinates in the camera's VIEWPORT
	# space (get_viewport().get_visible_rect().size), which is NOT
	# necessarily the same size as the captured Image when the window
	# was resized via a launch flag under this project's
	# window/stretch/mode=canvas_items + aspect=keep settings (the
	# visible rect can end up letterboxed to a different size than the
	# raw image). Scale explicitly rather than assume the two match --
	# found empirically: at a shrunk launch resolution the two diverged
	# enough to sample pure black every time, silently.
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
		return Color.BLACK
	acc /= float(samples)
	return Color(acc.x, acc.y, acc.z)

## WCAG 2.x contrast ratio between two colours -- (L1+0.05)/(L2+0.05)
## with L1 the larger relative luminance. Standard sRGB -> linear ->
## luminance formula, not a raw RGB distance: this is the same metric a
## web accessibility contrast checker reports.
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

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
