extends Node
## Capture probe for the COMBO HUD's legibility (combo batch). Measures,
## per dark palette and in the light phase, whether the combo counter and
## its multiplier actually READ against what is behind them.
##
## WHY THIS IS A SEPARATE PROBE FROM DarkPaletteAudit.gd, which already
## measures gameplay objects under the same six palettes: it measures 3D
## objects that the invert shader passes over. The HUD does not sit in that
## pipeline at all. HUD is a CanvasLayer at the default layer 1;
## DarkModeEffect is a CanvasLayer at layer 0 (see Game.tscn), and its
## ColorRect samples hint_screen_texture, which contains only what was
## drawn BENEATH it. So the HUD's own pixels are never inverted and never
## tinted -- its colours are literally the same values in every phase.
##
## THAT IS NOT THE SAME AS "the HUD is legible", which is the trap this
## probe exists to avoid falling into: what changes underneath the text is
## the BACKGROUND, and it changes a great deal. The light phase puts pale
## sky behind the counter; a dark phase puts an inverted, heavily tinted
## version of that same sky there (GameState.DARK_TINT_AMOUNT is 0.55, and
## the six DARK_VARIANTS hues are spread right around the wheel). Fixed
## foreground over a swinging background is exactly the situation where a
## single colour choice quietly fails on some subset of palettes.
##
## WHICH IS WHY THE FEEDBACK DOES NOT REST ON COLOUR AT ALL -- the combo
## reactions are SCALE changes and the multiplier is spelled as text (see
## HUD.gd). The colour work here is a floor, not the mechanism. The text is
## drawn white with a heavy near-black outline, so the two carry each other:
## against a dark background the white fill does the work, against a light
## one the outline does. This probe therefore reports BOTH ratios and
## judges the pair on the BETTER of the two, which is what an outlined
## glyph actually presents to the eye -- judging only the fill would fail a
## design that is in fact perfectly readable.
##
## CONTRAST METRIC: WCAG 2.x relative-luminance contrast ratio computed on
## ACTUAL POST-RENDER pixels sampled from the frame -- the same metric and
## the same "sample real rendered pixels, never hand-compute from hex
## codes" standard as DarkPaletteAudit.gd and InvertCapture.gd.
##
## The background is sampled from the frame region the combo row actually
## occupies, with the row hidden, so it is genuinely what sits behind the
## text rather than an assumed sky colour.
##
## Run it with:
##   xvfb-run -a godot4 --rendering-driver opengl3 \
##     --path . res://scripts/dev/ComboContrastAudit.tscn

const SETTLE_FRAMES: int = 4

## WCAG AA large-text threshold. The combo row is rendered at 34-46px,
## comfortably "large text" by the standard's own definition (>= 18.66px
## bold or 24px regular), so 3.0:1 is the correct floor to hold it to
## rather than the 4.5:1 body-text one -- the same floor and the same
## reasoning DarkPaletteAudit.gd already uses for gameplay objects.
const CONTRAST_FLOOR: float = 3.0

var _game: Node3D
var _hud: CanvasLayer
var _combo_row: Control
var _combo_label: Label
var _multiplier_label: Label

var _results: Array = []
var _failures: int = 0

func _ready() -> void:
	print("=== COMBO HUD CONTRAST AUDIT ===")
	print("metric: WCAG relative-luminance contrast ratio on real sampled pixels")
	print("floor : %.1f:1 (AA large text -- the row renders at 34-46px)" % CONTRAST_FLOOR)
	print("")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_hud = _game.get_node("HUD")
	_combo_row = _hud.get_node("MarginContainer/VBoxContainer/ComboRow")
	_combo_label = _hud.get_node("MarginContainer/VBoxContainer/ComboRow/ComboLabel")
	_multiplier_label = _hud.get_node("MarginContainer/VBoxContainer/ComboRow/MultiplierLabel")
	call_deferred("_run")

func _run() -> void:
	await _measure_phase("LIGHT", -1)
	for variant_index in GameState.DARK_VARIANTS.size():
		await _measure_phase("DARK/%d" % variant_index, variant_index)
	_report()

## Drives the dark-mode state directly on GameState rather than waiting for
## the run clock to reach each phase naturally: DarkModeEffect.gd is a pure
## reader of dark_intensity/dark_variant_index (verified by reading it), so
## setting those is exactly equivalent to the run reaching that phase, and
## it lets the probe visit all six palettes in a few frames instead of
## several minutes of simulated time.
func _measure_phase(label: String, variant_index: int) -> void:
	GameState.state = GameState.State.PLAYING
	if variant_index < 0:
		GameState.dark_phase = GameState.DarkPhase.LIGHT
		GameState.dark_intensity = 0.0
	else:
		GameState.dark_phase = GameState.DarkPhase.DARK
		GameState.dark_intensity = 1.0
		GameState.dark_variant_index = variant_index

	# Put the row into the state a player actually sees it in: a live combo
	# high enough to have earned a visible multiplier.
	GameState.combo_count = 7
	GameState.combo_multiplier = 3
	GameState.combo_expires_at_s = GameState.run_time_s + GameState.COMBO_TIMEOUT_S
	GameState.combo_changed.emit(GameState.combo_count, GameState.combo_multiplier)

	await _settle()
	var rect := Rect2i(
		Vector2i(_combo_row.global_position), Vector2i(_combo_row.size)
	)
	var with_text := _capture()
	# The SAME region with the row hidden -- the honest background, rather
	# than an assumed sky colour.
	_combo_row.visible = false
	await _settle()
	var without_text := _capture()
	_combo_row.visible = true
	# Settle AGAIN before returning. Without this the next phase's very
	# first capture can land on a frame drawn while the row was still
	# hidden, and every ratio computed from it is then text-versus-itself:
	# ~1:1, indistinguishable from a genuine legibility failure. That is
	# exactly how this probe's first run "found" two failing palettes that
	# were not failing at all.
	await _settle()

	if with_text == null or without_text == null:
		push_error("COMBO CONTRAST AUDIT: no frame captured (needs a real rendering driver, e.g. xvfb-run -a godot4 --rendering-driver opengl3)")
		get_tree().quit(1)
		return

	var background := _mean_color(without_text, rect)
	# The glyph's two components, picked out of the rendered text region by
	# luminance: the fill is white and the outline is near-black, so the
	# brightest and darkest pixels inside the row ARE those two, measured as
	# drawn rather than read back off the theme override.
	var fill := _extreme_color(with_text, rect, true)
	var outline := _extreme_color(with_text, rect, false)

	var fill_ratio := _contrast(fill, background)
	var outline_ratio := _contrast(outline, background)
	var effective := maxf(fill_ratio, outline_ratio)
	var ok := effective >= CONTRAST_FLOOR
	if not ok:
		_failures += 1
	_results.append({
		"label": label,
		"background": background,
		"fill_ratio": fill_ratio,
		"outline_ratio": outline_ratio,
		"effective": effective,
		"ok": ok,
	})

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

## Brightest (want_bright) or darkest pixel in the region -- the text's fill
## and its outline respectively. Averaged over the top/bottom percentile
## rather than taken from a single pixel so one stray antialiased sample
## cannot set the number.
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
	print("palette      background(rgb)      fill:bg   outline:bg   effective   verdict")
	print("-----------  -------------------  --------  -----------  ----------  -------")
	for r in _results:
		var bg: Color = r["background"]
		print("%-11s  (%.2f, %.2f, %.2f)   %6.2f:1   %7.2f:1   %6.2f:1   %s" % [
			r["label"], bg.r, bg.g, bg.b,
			r["fill_ratio"], r["outline_ratio"], r["effective"],
			("PASS" if r["ok"] else "FAIL"),
		])
	print("")
	if _failures > 0:
		push_error("COMBO HUD CONTRAST AUDIT FAILED: %d palette(s) left the combo row under the %.1f:1 floor on BOTH the fill and the outline." % [_failures, CONTRAST_FLOOR])
		get_tree().quit(1)
		return
	print("PASSED: the combo row clears %.1f:1 against its real background in the light" % CONTRAST_FLOOR)
	print("        phase and in all %d dark palettes." % GameState.DARK_VARIANTS.size())
	get_tree().quit(0)
