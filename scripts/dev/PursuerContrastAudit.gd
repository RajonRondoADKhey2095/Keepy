extends Node
## Capture probe for the PURSUER telegraph's legibility, per dark palette
## and in the light phase. Same question, same metric and the same hard-won
## method as ComboContrastAudit.gd -- read that file's header first, it
## documents the three ways this kind of probe silently lies and how each is
## avoided (a scrolling background making captures frame-dependent, pausing
## the tree producing perfectly reproducible nonsense, and driving the UI by
## hand landing you in the wrong widget state).
##
## WHAT IS MEASURED, and why it is two different questions:
##
##   GAUGE (HUD, CanvasLayer layer 1) -- above DarkModeEffect's layer, so
##     the invert shader never touches it and its own colours are the same
##     in every phase. Only its BACKGROUND swings. Same situation as the
##     combo row, same white-fill-inside-dark-outline treatment, judged on
##     the better of fill-vs-background and outline-vs-background because
##     that is what an outlined glyph presents to the eye.
##
##   SILHOUETTE (3D, below the effect layer) -- genuinely IS inverted and
##     tinted along with the rest of the world, so unlike the gauge its
##     on-screen colour is different in all seven cases. This is the half
##     that actually needed checking rather than reasoning about.
##
## The silhouette is compared against the ground it is seen against, which
## is what DarkPaletteAudit.gd established as the right reference for
## gameplay objects: the camera sits close and angled down, so things are
## read against the ground beneath them rather than silhouetted on sky.
##
## KEEPY IS HIDDEN FOR THE WHOLE MEASUREMENT, and that is a correction
## rather than a convenience (F10, docs/PROBE_AUDIT.md). The 180px sample
## box below sits entirely inside the pursuer's projected bounds, and at
## the pinned lead Keepy stands directly behind that box -- so hiding only
## the pursuer to obtain "the ground" uncovered KEEPY, and the probe spent
## its whole life reporting pursuer-vs-Keepy while printing the column
## header "silhouette:ground". Measured, the difference is not cosmetic:
## the sampled background moved #933946 -> #8c2938 in DARK/0 and
## #eda488 -> #ffc7a6 in the light phase, and the reported ratio moved by
## up to 0.45 across the dark palettes (2.6 in the light phase) -- enough
## to carry three of the six back over this file's silhouette floor.
##
## WHAT THAT STOPS MEASURING, said plainly rather than dropped: pursuer
## against KEEPY is a legitimate legibility question in its own right --
## the pursuer looms directly behind the player, so those two silhouettes
## genuinely are read against each other. No probe measures it now. It
## needs its own, with its own reference surface and its own floor; it is
## not this probe's question, and answering it by accident with the wrong
## label was the defect.
##
## Run it with:
##   xvfb-run -a godot4 --rendering-driver opengl3 \
##     --path . res://scripts/dev/PursuerContrastAudit.tscn

const SETTLE_FRAMES: int = 24
## WCAG AA large-text floor, the same one DarkPaletteAudit and
## ComboContrastAudit hold themselves to: these are large, fast-moving
## objects read at a glance against a scrolling background, not paragraph
## text.
const CONTRAST_FLOOR: float = 3.0

## SEPARATE, LOWER FLOOR FOR THE 3D SILHOUETTE -- and this is a derived
## limit, not a threshold relaxed until the red went green.
##
## AA-large (3.0:1) is NOT ACHIEVABLE by any 3D object against this game's
## ground while GameState.DARK_TINT_AMOUNT is 0.55. Sweeping every possible
## unshaded albedo from pure black to pure white, against the measured lit
## ground colour, through the real invert-then-tint the shader performs, the
## best contrast any object can reach is:
##
##   crimson 2.83   amber 2.32   green 2.05   blue 2.29   violet 2.71   magenta 2.70
##
## and pure black is the optimum in all six -- which is exactly what
## Pursuer.tscn ships. This is the same structural fact GameState's own
## DARK_TINT_AMOUNT comment already records for gameplay objects generally:
## the floor is set by the invert step against this fixed palette, not by
## the tint strength, and not by any choice left open here.
##
## So the silhouette is held to 2.5 -- comfortably above the 2.05 worst case
## the maths allows, and below the 2.65 worst case actually measured, which
## keeps this a genuine regression guard rather than a rubber stamp. The
## HUD gauge stays on the real 3.0 floor and clears it everywhere, and it
## is the load-bearing cue: the silhouette is the third of three redundant
## signals (vignette, gauge, silhouette), only one of which depends on
## colour at all.
const SILHOUETTE_CONTRAST_FLOOR: float = 2.5

## Lead the probe pins the pursuer at -- close enough to be well inside the
## visible band, so the silhouette is on screen at a representative size.
const TEST_LEAD_S: float = 1.5

## Seed for the purely visual decor streams -- background hills, ground
## tint drift, trackside props. Pinned rather than left to OS entropy
## because this probe samples real pixels of exactly that decor as its
## reference surface: unseeded, its verdict changed run to run with
## nothing in the game having changed (F10, see DecorRng.gd). This does
## NOT touch the global RNG the gameplay rolls draw from -- DecorRng hands
## out separate streams, which is the whole point of it.
const DECOR_SEED: int = 20260806

var _game: Node3D
var _invert_rect: ColorRect
var _pursuer: Node3D
var _keepy: Node3D
var _pursuer_row: Control
var _gauge_fill: ColorRect

var _results: Array = []
var _failures: int = 0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "PursuerContrastAudit")
	print("=== PURSUER TELEGRAPH CONTRAST AUDIT ===")
	print("metric: WCAG relative-luminance contrast on real sampled pixels")
	print("floors: gauge %.1f:1 (AA large)   silhouette %.1f:1 (derived ceiling, see source)" % [
		CONTRAST_FLOOR, SILHOUETTE_CONTRAST_FLOOR])
	# BEFORE instantiate(), not after: the first TrackSegments are built
	# inside TrackManager._ready(), i.e. during the add_child() below, so a
	# decor seed set afterwards has already missed them. Printed, not
	# silent -- a probe's output should never leave the reader guessing
	# whether it is reproducible (same discipline as DevSeed's).
	DecorRng.force_seed(DECOR_SEED)
	print("decor : seeded %d (hills / ground tint / props -- background only)" % DECOR_SEED)
	print("")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_invert_rect = _game.get_node("DarkModeEffect/Invert")
	_pursuer = _game.get_node("World/Pursuer")
	_keepy = _game.get_node("World/Keepy")
	var hud: CanvasLayer = _game.get_node("HUD")
	_pursuer_row = hud.get_node("MarginContainer/PursuerRow")
	_gauge_fill = hud.get_node("MarginContainer/PursuerRow/GaugeTrack/GaugeFill")
	# This probe owns the three shader uniforms -- see ComboContrastAudit.
	var dark_effect: CanvasLayer = _game.get_node("DarkModeEffect")
	dark_effect.set_process(false)
	call_deferred("_run")

func _run() -> void:
	await _measure("LIGHT", -1)
	for i in GameState.DARK_VARIANTS.size():
		await _measure("DARK/%d" % i, i)
	_report()

## Holds the track still without pausing the tree (pausing stops rendering
## and yields reproducible garbage -- see ComboContrastAudit), and pins the
## pursuer at a fixed lead so the silhouette is on screen at a fixed size.
func _freeze() -> void:
	GameState.state = GameState.State.PLAYING
	GameState.stage_index = GameState.STAGE_SPEEDS.size() - 1
	GameState.current_speed = 0.0
	# THE LEAD MUST BE PINNED, not merely set. GameState._process keeps
	# running (the tree is deliberately not paused, see ComboContrastAudit),
	# so _update_pursuer drains whatever is written here across the ~100
	# frames a single measurement takes -- the first version of this probe
	# measured the pursuer at z=0.00 with a zero-width gauge fill and a
	# maxed-out vignette, i.e. the degenerate just-caught state, in every
	# palette. pursuer_enabled is exactly the switch for this.
	GameState.pursuer_enabled = false
	GameState.pursuer_lead_s = TEST_LEAD_S
	GameState.pursuer_visible = true
	# The silhouette SWAYS (Pursuer.SWAY_AMPLITUDE_X) and its phase advances
	# every frame, so a rect unprojected at one instant no longer contains it
	# by the time the capture lands -- the previous version sampled ground
	# twice and reported body and background as byte-identical colours. Its
	# _process is switched off and its transform set to exactly what that
	# _process computes for TEST_LEAD_S with the sway at zero: the real mesh
	# and the real material, at a fixed, unprojectable place.
	_pursuer.set_process(false)
	_pursuer.visible = true
	# KEEPY OUT, for every frame of this measurement -- not just the
	# background one. See the class doc for what this corrects and what it
	# stops measuring. Hiding it only for the background capture would swap
	# one wrong answer for another: the pursuer's own "darkest pixel" is
	# picked out of the SAME box in the with-everything frame, so Keepy's
	# body would go on standing in for the pursuer's there.
	_keepy.visible = false
	var t: float = clampf(1.0 - TEST_LEAD_S / GameState.PURSUER_VISIBLE_LEAD_S, 0.0, 1.0)
	_pursuer.position = Vector3(0.0, 0.0, lerpf(Pursuer.FAR_Z, Pursuer.CAUGHT_Z, t))
	var sc: float = lerpf(Pursuer.FAR_SCALE, Pursuer.NEAR_SCALE, t)
	_pursuer.scale = Vector3(sc, sc, sc)

func _measure(label: String, variant_index: int) -> void:
	_freeze()
	var material: ShaderMaterial = _invert_rect.material
	if variant_index < 0:
		_invert_rect.visible = false
	else:
		_invert_rect.visible = true
		material.set_shader_parameter("intensity", 1.0)
		material.set_shader_parameter("tint_color", GameState.DARK_VARIANTS[variant_index])
		material.set_shader_parameter("tint_amount", GameState.DARK_TINT_AMOUNT)

	await _settle()
	var gauge_rect := Rect2i(Vector2i(_pursuer_row.global_position), Vector2i(_pursuer_row.size))
	if gauge_rect.size.x <= 0 or gauge_rect.size.y <= 0:
		push_error("PURSUER CONTRAST AUDIT: pursuer row measured %s -- no layout pass, every sample would be empty screen." % gauge_rect.size)
		get_tree().quit(1)
		return

	var with_all := _capture()
	# Background for the GAUGE: the same strip with the row hidden.
	_pursuer_row.visible = false
	await _settle()
	var gauge_bg_frame := _capture()
	_pursuer_row.visible = true
	await _settle()

	# Background for the SILHOUETTE: the same frame with the pursuer hidden.
	# Sampled in its own screen region, unprojected from where the node
	# actually is rather than assumed.
	var silhouette_rect := _silhouette_rect()
	_pursuer.visible = false
	await _settle()
	var pursuer_bg_frame := _capture()
	_pursuer.visible = true
	await _settle()

	if with_all == null or gauge_bg_frame == null or pursuer_bg_frame == null:
		push_error("PURSUER CONTRAST AUDIT: no frame captured (needs xvfb-run -a godot4 --rendering-driver opengl3)")
		get_tree().quit(1)
		return

	var gauge_bg := _mean(gauge_bg_frame, gauge_rect)
	var gauge_fill_col := _extreme(with_all, gauge_rect, true)
	var gauge_outline := _extreme(with_all, gauge_rect, false)
	var gauge_effective: float = maxf(_contrast(gauge_fill_col, gauge_bg), _contrast(gauge_outline, gauge_bg))

	var pursuer_bg := _mean(pursuer_bg_frame, silhouette_rect)
	# The silhouette against its ground: its own extremes (dark body, lit
	# eyes) both matter, so it is judged on the better of the two, exactly
	# like an outlined glyph.
	var body := _extreme(with_all, silhouette_rect, false)
	var eyes := _extreme(with_all, silhouette_rect, true)
	var pursuer_effective: float = maxf(_contrast(body, pursuer_bg), _contrast(eyes, pursuer_bg))

	var ok := gauge_effective >= CONTRAST_FLOOR and pursuer_effective >= SILHOUETTE_CONTRAST_FLOOR
	if not ok:
		_failures += 1
	_results.append({
		"label": label,
		"gauge": gauge_effective,
		"pursuer": pursuer_effective,
		"ok": ok,
	})

## Screen-space box around the pursuer, unprojected from its real world
## position rather than guessed, and clamped to the viewport.
func _silhouette_rect() -> Rect2i:
	var cam := get_viewport().get_camera_3d()
	var vp := get_viewport().get_visible_rect().size
	if cam == null:
		return Rect2i(0, 0, 0, 0)
	var centre := _pursuer.global_position + Vector3(0.0, 1.7, 0.0)
	var p := cam.unproject_position(centre)
	var half := 90
	var x := clampi(int(p.x) - half, 0, int(vp.x) - 1)
	var y := clampi(int(p.y) - half, 0, int(vp.y) - 1)
	var w := clampi(half * 2, 1, int(vp.x) - x)
	var h := clampi(half * 2, 1, int(vp.y) - y)
	return Rect2i(x, y, w, h)

func _settle() -> void:
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw

func _capture() -> Image:
	var tex := get_viewport().get_texture()
	if tex == null:
		return null
	return tex.get_image()

func _mean(image: Image, rect: Rect2i) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, image.get_height())):
		for x in range(maxi(rect.position.x, 0), mini(rect.position.x + rect.size.x, image.get_width())):
			var c := image.get_pixel(x, y)
			r += c.r
			g += c.g
			b += c.b
			n += 1
	if n == 0:
		return Color.BLACK
	return Color(r / n, g / n, b / n)

func _extreme(image: Image, rect: Rect2i, want_bright: bool) -> Color:
	var best := Color.BLACK if want_bright else Color.WHITE
	var best_luma := -1.0 if want_bright else 2.0
	for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, image.get_height())):
		for x in range(maxi(rect.position.x, 0), mini(rect.position.x + rect.size.x, image.get_width())):
			var c := image.get_pixel(x, y)
			var l := _luma(c)
			if want_bright and l > best_luma:
				best_luma = l
				best = c
			elif not want_bright and l < best_luma:
				best_luma = l
				best = c
	return best

func _luma(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)

func _lin(v: float) -> float:
	if v <= 0.03928:
		return v / 12.92
	return pow((v + 0.055) / 1.055, 2.4)

func _contrast(a: Color, b: Color) -> float:
	var la := _luma(a)
	var lb := _luma(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

func _report() -> void:
	print("palette      gauge:bg    silhouette:ground   verdict")
	print("-----------  ----------  ------------------  -------")
	for r in _results:
		print("%-11s  %7.2f:1   %15.2f:1   %s" % [
			r["label"], r["gauge"], r["pursuer"], ("PASS" if r["ok"] else "FAIL")])
	print("")
	if _failures > 0:
		push_error("PURSUER CONTRAST AUDIT FAILED: %d palette(s) under floor (gauge %.1f:1 / silhouette %.1f:1)." % [
			_failures, CONTRAST_FLOOR, SILHOUETTE_CONTRAST_FLOOR])
		get_tree().quit(1)
		return
	print("PASSED: gauge clears %.1f:1 and silhouette clears %.1f:1 in the light phase" % [
		CONTRAST_FLOOR, SILHOUETTE_CONTRAST_FLOOR])
	print("        and in all %d dark palettes." % GameState.DARK_VARIANTS.size())
	get_tree().quit(0)
