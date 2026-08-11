extends Node
## Capture probe for the STRIKE INDICATOR's legibility (see the STRIKES
## section of HUD.gd). Measures, per dark palette and in the light phase,
## whether the player can actually READ how many strikes they have left.
##
## WHY IT NEEDS MEASURING AT ALL, given the pips are HUD pixels that the
## invert shader never touches: what changes underneath them is the
## BACKGROUND, and it changes a great deal (see ComboContrastAudit.gd's own
## header for the full argument -- this probe is its sibling and shares its
## method wholesale). A fixed foreground over a swinging background is
## exactly where one colour choice quietly fails on some subset of palettes.
##
## WHAT IS MEASURED, and it is three things rather than one, because the
## indicator has three distinct jobs and any of them can fail alone:
##
##   PRESENCE  -- can the pip be SEEN at all against what is behind it. A pip
##                is a bright outer border around a near-black ring (see
##                HUD.tscn), so one of the two always carries: judged on the
##                BETTER of border:background and ring:background, which is
##                what the eye is actually presented with. Same "outlined
##                glyph" reasoning ComboContrastAudit applies to text, in
##                geometry instead of type. Unchanged between the two states,
##                by construction -- only the interior moves -- so it is
##                measured once.
##   STATE     -- can INTACT be told from SPENT. This is the measure that
##                carries the actual information, and it is deliberately
##                separate: a pip could clear its background handsomely in
##                both states and still look identical in both, at which
##                point the indicator shows a number of pips and nothing
##                else. Sampled from the INTERIOR rectangle alone -- sampling
##                the whole pip finds the same white border in both states
##                and reports a meaningless 1.00:1, which is exactly what the
##                first version of this probe did.
##
## THE SPENT STATE IS DRIVEN THROUGH GameState.register_strike(), never by
## writing strikes_used_half by hand, and that is a correction rather than a
## preference. Writing the field directly leaves _strike_clean_since_s where
## it was, so _update_strikes saw a strike that had already been "clean" for
## longer than TIME_TO_CLEAR_STRIKE_S and handed it straight back on the next
## frame -- the probe then captured two IDENTICAL frames and reported a
## 1.00:1 ratio between the two states, which reads exactly like a real
## legibility failure. Worse, it only did so on some palettes: each spurious
## clear re-armed the recovery clock, so whether a given phase measured the
## right state depended on how far into the run it happened to be. Going
## through the real entry point puts the run in the state a player would
## actually be in.
##
## CONTRAST METRIC: WCAG 2.x relative-luminance contrast ratio computed on
## ACTUAL POST-RENDER pixels sampled from the frame -- the same metric and
## the same "sample real rendered pixels, never hand-compute from hex codes"
## standard as ComboContrastAudit.gd, DarkPaletteAudit.gd and InvertCapture.gd.
##
## Run it with:
##   xvfb-run -a godot4 --rendering-driver opengl3 \
##     --path . res://scripts/dev/StrikeContrastAudit.tscn

## Generous on purpose: it must comfortably outlast the row's danger pulse
## period so a capture is never taken mid-swing at an unrepresentative scale.
const SETTLE_FRAMES: int = 24

## WCAG floor. 3.0:1 is the correct one here twice over: the pips are
## GRAPHICAL OBJECTS conveying information (WCAG 1.4.11 non-text contrast,
## floor 3.0), and the row's label renders at 22px with a 8px outline, i.e.
## large text (1.4.3, also 3.0) -- the same floor and reasoning
## ComboContrastAudit.gd already holds the combo row to.
const CONTRAST_FLOOR: float = 3.0

var _game: Node3D
var _atmosphere: Node
var _hud: CanvasLayer
var _strike_row: Control
var _pip0: ColorRect
var _pip0_interior: ColorRect

var _results: Array = []
var _failures: int = 0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "StrikeContrastAudit")
	print("=== STRIKE INDICATOR CONTRAST AUDIT ===")
	print("metric: WCAG relative-luminance contrast ratio on real sampled pixels")
	print("floor : %.1f:1 (non-text UI component / large text)" % CONTRAST_FLOOR)
	print("")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_hud = _game.get_node("HUD")
	# Same two corrections ComboContrastAudit.gd documents at length: the
	# world is held still by zeroing the speed (never by pausing the tree,
	# which stops the rendering the whole probe depends on), and
	# SwampAtmosphere's own _process is switched off so it cannot write over
	# the uniforms this probe sets by hand.
	_atmosphere = _game.get_node("SwampAtmosphere")
	# _process off so GameState cannot overwrite the pinned intensity every
	# frame; the probe then calls _apply() itself -- see _measure below.
	_atmosphere.set_process(false)
	_strike_row = _hud.get_node("MarginContainer/PursuerRow/StrikeRow")
	_pip0 = _hud.get_node("MarginContainer/PursuerRow/StrikeRow/Pip0")
	_pip0_interior = _hud.get_node("MarginContainer/PursuerRow/StrikeRow/Pip0/Ring/Fill")
	call_deferred("_run")

func _run() -> void:
	await _measure_phase("LIGHT", false)
	await _measure_phase("DARK", true)
	_report()

func _freeze_world() -> void:
	GameState.state = GameState.State.PLAYING
	GameState.stage_index = GameState.STAGE_SPEEDS.size() - 1
	GameState.current_speed = 0.0
	# The stumble slowdown multiplies the speed above, so it cannot un-freeze
	# the world -- but it is pinned anyway so a stray strike can never make a
	# capture happen at a different scale than the rest.
	GameState.player_speed_factor = 1.0

func _measure_phase(label: String, dark: bool) -> void:
	_freeze_world()
	# Drive the REAL SwampAtmosphere._apply() rather than writing the
	# shader uniforms by hand. Since the swamp refonte the dark look is
	# TWO things -- the screen grade AND the sky/haze colours written
	# into the WorldEnvironment -- and poking only the shader would
	# measure a swamp-graded world under a DAYTIME BLUE sky, which is
	# not a state the game can ever be in. Going through the real entry
	# point is the same discipline this probe already applies to
	# GameState.register_strike() and friends.
	_atmosphere._apply(1.0 if dark else 0.0)

	# Pip 0 INTACT: no strikes taken.
	_set_strikes(0)
	await _settle()
	var rect := Rect2i(Vector2i(_pip0.global_position), Vector2i(_pip0.size))
	if rect.size.x <= 0 or rect.size.y <= 0:
		push_error("STRIKE CONTRAST AUDIT: the pip measured %s -- it never got a layout pass, so every sample below would be of empty screen." % rect.size)
		get_tree().quit(1)
		return
	var interior_rect := Rect2i(
		Vector2i(_pip0_interior.global_position), Vector2i(_pip0_interior.size))
	var intact_frame := _capture()

	# Pip 0 SPENT: one strike taken, through the real door.
	_set_strikes(1)
	await _settle()
	var spent_frame := _capture()

	# The honest background: the same region with the whole row hidden.
	_set_strikes(0)
	_strike_row.visible = false
	await _settle()
	var empty_frame := _capture()
	_strike_row.visible = true
	await _settle()

	if intact_frame == null or spent_frame == null or empty_frame == null:
		push_error("STRIKE CONTRAST AUDIT: no frame captured (needs a real rendering driver, e.g. xvfb-run -a godot4 --rendering-driver opengl3)")
		get_tree().quit(1)
		return

	var background := _mean_color(empty_frame, rect)
	# Brightest and darkest pixel across the whole pip ARE its border and its
	# ring, measured as drawn rather than read back off the scene file.
	var border := _extreme_color(intact_frame, rect, true)
	var ring := _extreme_color(intact_frame, rect, false)
	# The interior, from its own rectangle. A MEAN rather than an extreme: it
	# is a solid fill, so the mean IS its colour, and it cannot be polluted by
	# a border pixel bleeding into the sample.
	var intact_interior := _mean_color(intact_frame, interior_rect)
	var spent_interior := _mean_color(spent_frame, interior_rect)

	var presence := maxf(_contrast(border, background), _contrast(ring, background))
	var states := _contrast(intact_interior, spent_interior)
	var ok := presence >= CONTRAST_FLOOR and states >= CONTRAST_FLOOR
	if not ok:
		_failures += 1
	_results.append({
		"label": label,
		"background": background,
		"presence": presence,
		"states": states,
		"ok": ok,
	})

## Puts the run at exactly `count` strikes. Clearing back down is the one
## thing that has no public door (nothing in the game ever un-takes a strike
## except the two recovery rules), so 0 is reached by resetting the field and
## re-arming the recovery clock through a fresh start_run -- which also
## guarantees no stumble slowdown is left running from the previous phase.
func _set_strikes(count: int) -> void:
	GameState.start_run()
	_freeze_world()
	for i in count:
		GameState.register_strike(Obstacle.Type.DODGE)
	_freeze_world()

func _settle() -> void:
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw

func _capture() -> Image:
	var texture := get_viewport().get_texture()
	if texture == null:
		return null
	return texture.get_image()

func _mean_color(image: Image, rect: Rect2i) -> Color:
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

func _extreme_color(image: Image, rect: Rect2i, want_bright: bool) -> Color:
	var best := Color.BLACK if want_bright else Color.WHITE
	var best_luma := -1.0 if want_bright else 2.0
	for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, image.get_height())):
		for x in range(maxi(rect.position.x, 0), mini(rect.position.x + rect.size.x, image.get_width())):
			var c := image.get_pixel(x, y)
			var luma := _relative_luminance(c)
			if want_bright and luma > best_luma:
				best_luma = luma
				best = c
			elif not want_bright and luma < best_luma:
				best_luma = luma
				best = c
	return best

## Standard sRGB -> linear -> luminance, per WCAG 2.x.
func _relative_luminance(c: Color) -> float:
	return 0.2126 * _linearise(c.r) + 0.7152 * _linearise(c.g) + 0.0722 * _linearise(c.b)

func _linearise(channel: float) -> float:
	if channel <= 0.03928:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)

func _contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	var lighter := maxf(la, lb)
	var darker := minf(la, lb)
	return (lighter + 0.05) / (darker + 0.05)

func _report() -> void:
	print("phase        background(rgb)      pip:bg (presence)   intact:spent (state)   verdict")
	print("-----------  -------------------  -----------------   --------------------   -------")
	for r in _results:
		var bg: Color = r["background"]
		print("%-11s  (%.2f, %.2f, %.2f)          %6.2f:1               %6.2f:1        %s" % [
			r["label"], bg.r, bg.g, bg.b,
			r["presence"], r["states"],
			("PASS" if r["ok"] else "FAIL"),
		])
	print("")
	if _failures > 0:
		push_error("STRIKE CONTRAST AUDIT FAILED: %d case(s) left the strike indicator under the %.1f:1 floor on presence, on the intact/spent distinction, or on both." % [_failures, CONTRAST_FLOOR])
		get_tree().quit(1)
		return
	print("PASSED: the pip is visible against its real background, and intact reads")
	print("        apart from spent, both above %.1f:1 in the light phase and in all" % CONTRAST_FLOOR)
	print("        the swamp-night dark phase.")
	get_tree().quit(0)
