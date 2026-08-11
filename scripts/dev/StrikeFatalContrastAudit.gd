extends Node
## Capture probe for the FATAL-STRIKE label colour specifically -- see
## HUD.gd's STRIKE_FATAL_COLOR / _fatal_active (playtest-fixes batch: the
## second strike needs to read as qualitatively worse than the first, per
## the STRIKES section of HUD's own class doc). StrikeContrastAudit.gd
## already covers the two pip STATES (intact/spent); this probe covers the
## one thing that changes ON TOP of that at the fatal strike -- the
## StrikeLabel's font colour and pulse -- which StrikeContrastAudit never
## exercises because it stops at one strike.
##
## METHOD is ComboContrastAudit.gd's wholesale, not reinvented: fill and
## outline are the label's two components (bright red fill,
## near-black outline, see HUD.tscn's StrikeLabel), picked out of the real
## rendered region by luminance extreme, judged against the real background
## sampled with the row hidden, on the BETTER of fill:bg / outline:bg -- an
## outlined glyph presents both to the eye, and judging only the fill would
## fail a design that is in fact readable through its outline.
##
## THE FATAL STATE IS DRIVEN THROUGH THE REAL DOOR, same discipline
## StrikeContrastAudit.gd insists on and for the same reason:
## STRIKE_CAPACITY_HALF real GameState.register_strike() calls put
## strikes_used_half at the capacity, which is what
## _begin_capture_sequence() actually gates HUD._fatal_active on (see
## GameState.gd and HUD.gd's _on_pursuer_caught). Setting HUD._fatal_active
## by hand would test a state the game can produce, sure, but writing
## GameState.strikes_used_half or state directly and skipping the real call
## sites is exactly the shortcut StrikeContrastAudit.gd's own class doc
## warns cost it a false pass once already.
##
## THE COUNT OF CALLS IS DERIVED FROM THE CAPACITY, never written as a
## literal 2. It used to be two hard-coded calls, correct while the capacity
## was two full strikes and silently wrong the moment the half-strike
## rebalance made it four half-units -- the probe would have stopped
## reaching the fatal state at all and failed for a reason that has nothing
## to do with the contrast it exists to measure. Its own error message below
## already anticipated exactly this ("either GameState.STRIKE_CAPACITY
## moved"); deriving the loop is what makes that anticipation unnecessary.
##
## Run it with:
##   xvfb-run -a godot4 --rendering-driver opengl3 \
##     --path . res://scripts/dev/StrikeFatalContrastAudit.tscn

const SETTLE_FRAMES: int = 24

## Same floor as ComboContrastAudit/StrikeContrastAudit: the label renders
## at 22px with an 8px outline, i.e. large text (WCAG 1.4.3), same reasoning
## both of those already apply.
const CONTRAST_FLOOR: float = 3.0

## Seed for the purely visual decor streams -- background hills, ground
## tint drift, trackside props (F10, see scripts/world/DecorRng.gd).
##
## This probe's "background" is real rendered pixels of the 3D world behind
## the strike row, so decor IS its reference surface. Unseeded, that surface
## was different on every invocation and the verdict moved with it: on three
## runs of byte-identical code DARK/0 read 2.87 / 3.31 / 3.19 against this
## 3.0 floor -- FAIL, PASS, PASS -- and a fourth run reported a different
## palette failing altogether. A regression guard whose answer changes when
## nothing changed is not one.
##
## This does NOT seed the global RNG the gameplay rolls draw from. DecorRng
## hands out separate streams and never touches it, which is precisely the
## property that lets this be seeded at all.
##
## SEEDING THE DECOR WAS NECESSARY AND NOT SUFFICIENT, and that is worth
## knowing before trusting it: measured after the seed, three runs still
## disagreed. The dominant term was HUD's own full-screen StrikeFlash, not
## the decor -- see where it is pinned to rest in _measure_phase below. The
## decor seed is what makes the remaining background reproducible once that
## overlay is out of the way.
const DECOR_SEED: int = 20260806

var _game: Node3D
var _atmosphere: Node
var _hud: CanvasLayer
var _strike_row: Control
var _strike_label: Label
var _strike_flash: ColorRect

var _results: Array = []
var _failures: int = 0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "StrikeFatalContrastAudit")
	print("=== STRIKE FATAL-LABEL CONTRAST AUDIT ===")
	print("metric: WCAG relative-luminance contrast ratio on real sampled pixels")
	print("floor : %.1f:1 (large text)" % CONTRAST_FLOOR)
	# BEFORE instantiate(): TrackManager builds its first segments inside
	# the add_child() below, so a decor seed set afterwards has already
	# missed them. Printed rather than silent, same reason DevSeed prints.
	DecorRng.force_seed(DECOR_SEED)
	print("decor : seeded %d (hills / ground tint / props -- background only)" % DECOR_SEED)
	print("")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_hud = _game.get_node("HUD")
	_atmosphere = _game.get_node("SwampAtmosphere")
	# _process off so GameState cannot overwrite the pinned intensity every
	# frame; the probe then calls _apply() itself -- see _measure below.
	_atmosphere.set_process(false)
	# THE PURSUER, muted outright -- and this probe needed a real run to find
	# out why it had to be. _freeze_world() below re-pins GameState.state to
	# PLAYING by direct assignment (same technique ComboContrastAudit/
	# StrikeContrastAudit already use), never through state_changed, so
	# Pursuer.gd's OWN _capture_active/_intro_active flags -- set by the real
	# state_changed emission register_strike's capacity branch fires -- never
	# get cleared by that reassignment. Left alone, the pursuer kept lunging
	# (or, on some frames, restarted its intro) for the entire probe, moving
	# 3D geometry behind the very screen region this probe samples as "the
	# background" -- which is what made an early run of this probe report a
	# DIFFERENT background colour for the same palette on different
	# invocations: the sample landed on a different frame of an animation
	# that was never supposed to still be running. This probe measures HUD
	# text against a background, not the pursuer, so it is simply switched
	# off rather than fought with state juggling.
	var pursuer: Node3D = _game.get_node("World/Pursuer")
	pursuer.set_process(false)
	pursuer.visible = false
	_strike_row = _hud.get_node("MarginContainer/PursuerRow/StrikeRow")
	_strike_label = _hud.get_node("MarginContainer/PursuerRow/StrikeRow/StrikeLabel")
	_strike_flash = _hud.get_node("StrikeFlash")
	call_deferred("_run")

func _run() -> void:
	await _measure_phase("LIGHT", false)
	await _measure_phase("DARK", true)
	_report()

## Same "hold the world still without pausing the tree" technique as
## ComboContrastAudit.gd -- pausing breaks rendering, and this probe needs
## real frames.
func _freeze_world() -> void:
	GameState.state = GameState.State.PLAYING
	GameState.stage_index = GameState.STAGE_SPEEDS.size() - 1
	GameState.current_speed = 0.0
	GameState.player_speed_factor = 1.0

## Puts the run at exactly STRIKE_CAPACITY_HALF half-units through the real
## entry point, which is what actually fires GameState.pursuer_caught and,
## through it, HUD._on_pursuer_caught -- see the class doc for why this is
## not optional. A fresh start_run() first, same as StrikeContrastAudit's
## own _set_strikes, so no stumble-slowdown or invulnerability window
## survives from a previous phase.
##
## register_strike REFUSES a hit taken before STRIKE_INVULNERABLE_S has
## elapsed since the last credited one (see GameState.gd) -- calling it
## twice back to back with run_time_s untouched in between hits exactly that
## guard, silently swallowing the second strike (found by running this
## probe for real: the first attempt never armed HUD._fatal_active at all).
## Nudging run_time_s past the window between calls clears it without going
## through advance_time() -- which would also drain the pursuer lead and
## advance the combo/dark-cycle clocks this probe has no reason to touch.
##
## DODGE for every call: the type is reported, never branched on
## (GameState.register_strike's own doc), and every non-fatal type costs the
## same CONTACT_COST_HALF, so one is as good as another here. It must not be
## a CHARGER, which would end the run outright and never credit anything.
func _enter_fatal_state() -> void:
	GameState.start_run()
	_freeze_world()
	for i in GameState.STRIKE_CAPACITY_HALF:
		if i > 0:
			GameState.run_time_s += GameState.STRIKE_INVULNERABLE_S + 0.01
		GameState.register_strike(Obstacle.Type.DODGE)
	# register_strike's own capacity branch moves state to CAPTURED (see
	# GameState._begin_capture_sequence) -- re-pin it to PLAYING so the
	# invert shader/track stay exactly as this probe's other phases left
	# them; HUD._fatal_active is a HUD-owned flag set by the pursuer_caught
	# signal already emitted above and is untouched by this.
	_freeze_world()

func _measure_phase(label: String, dark: bool) -> void:
	# Re-armed at the top of every phase: the previous phase's capture step
	# below disables this on purpose (see there) to pin the pulse at rest,
	# and without turning it back on here the pip repaint / fatal colour for
	# THIS phase would never apply either.
	_hud.set_process(true)
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

	_enter_fatal_state()
	if not _hud._fatal_active:
		push_error("STRIKE FATAL CONTRAST AUDIT: %d real contacts did not arm HUD._fatal_active -- the capacity branch has stopped emitting pursuer_caught, or the invulnerability nudge between calls no longer clears the window. This probe cannot measure a state that was never entered." % GameState.STRIKE_CAPACITY_HALF)
		get_tree().quit(1)
		return
	# ONE settle first, not the full amount -- just enough for HUD._process to
	# run once so the pip repaint and _apply_strike_color(STRIKE_FATAL_COLOR)
	# actually happen (both are edge-triggered off HUD's own _process, not
	# off the _fatal_active flag this probe just checked directly). THEN
	# freeze the row at rest scale and stop HUD's own _process before the
	# real settle: FATAL_PULSE_AMPLITUDE (0.32) means _update_strike_display
	# is still rewriting strike_row.scale every one of the frames the second
	# settle would otherwise wait through, off a sine whose phase this probe
	# does not control -- a real legibility bug, found by running this probe
	# for real: DARK/1 first reported fill=(1.00,1.00,1.00), the two PIPS'
	# own white border rendered INTO the label's nominal rect because the
	# whole row was scaled down about its own centre at that instant. This
	# probe measures the label's COLOUR, not its pulse, so the pulse is
	# pinned to rest for the capture -- the pulse itself is motion, which
	# survives every palette by construction (see HUD.gd's class doc) and
	# does not need a contrast floor.
	for i in 2:
		await RenderingServer.frame_post_draw
	_hud.set_process(false)
	_strike_row.scale = Vector2.ONE
	# THE STRIKE FLASH, pinned to rest for the same reason the pulse just
	# was -- and it was doing far more damage (F10c, docs/PROBE_AUDIT.md).
	# StrikeFlash is a FULL-SCREEN white ColorRect that HUD ramps to
	# STRIKE_FLASH_MAX_ALPHA (0.55) over STRIKE_FLASH_DURATION_S (0.30s) on
	# every strike -- and this probe fires two real ones immediately above.
	# Two frames later, where HUD's own _process is stopped, the flash is
	# still near its peak: measured 0.47-0.55 at capture, i.e. this probe's
	# "background" was up to half a white wash, at an alpha decided by how
	# fast the machine happened to render two frames. That is what made the
	# verdict a coin flip even after the decor was seeded -- the whole
	# screen shifted by ~6/255 between runs, enough to move DARK/4 and
	# DARK/5 across the floor.
	#
	# Zeroed rather than waited out: the flash is a transient impact cue,
	# while the fatal label persists for the rest of the run, so the state
	# worth holding the label's colour to is the one it spends its life in.
	# Same argument as the pulse above -- motion is not what a contrast
	# floor measures.
	_strike_flash.color.a = 0.0
	await _settle()
	# THE LABEL'S OWN RECT, not the row's. StrikeRow is an HBoxContainer that
	# also lays out the two pips beside the label -- sampling the whole row's
	# bounding box picks up the pips' bright WHITE border as the "brightest
	# pixel" and reports THAT as the label's fill colour, which is not what
	# this probe exists to measure. Found by running it for real: the first
	# version of this probe reported fill=(1.00, 1.00, 1.00) in every single
	# palette, i.e. it was sampling the pips, not the fatal-red text.
	var rect := Rect2i(Vector2i(_strike_label.global_position), Vector2i(_strike_label.size))
	if rect.size.x <= 0 or rect.size.y <= 0:
		push_error("STRIKE FATAL CONTRAST AUDIT: the strike label measured %s -- it never got a layout pass, so every sample below would be of empty screen." % rect.size)
		get_tree().quit(1)
		return
	var with_text := _capture()

	# Hide the LABEL alone, leaving the pips exactly where they were -- the
	# label's rect does not overlap either pip's (HBoxContainer lays them out
	# side by side), so this is the honest background the label itself sits
	# against, uncontaminated by toggling anything the label's own footprint
	# does not include.
	_strike_label.visible = false
	await _settle()
	var without_text := _capture()
	_strike_label.visible = true
	await _settle()

	if with_text == null or without_text == null:
		push_error("STRIKE FATAL CONTRAST AUDIT: no frame captured (needs a real rendering driver, e.g. xvfb-run -a godot4 --rendering-driver opengl3)")
		get_tree().quit(1)
		return

	var background := _mean_color(without_text, rect)
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
		"fill": fill,
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
	print("phase        background(rgb)      fill(rgb)            fill:bg   outline:bg   effective   verdict")
	print("-----------  -------------------  -------------------  --------  -----------  ----------  -------")
	for r in _results:
		var bg: Color = r["background"]
		var fill: Color = r["fill"]
		print("%-11s  (%.2f, %.2f, %.2f)   (%.2f, %.2f, %.2f)   %6.2f:1   %7.2f:1   %6.2f:1   %s" % [
			r["label"], bg.r, bg.g, bg.b,
			fill.r, fill.g, fill.b,
			r["fill_ratio"], r["outline_ratio"], r["effective"],
			("PASS" if r["ok"] else "FAIL"),
		])
	print("")
	if _failures > 0:
		push_error("STRIKE FATAL-LABEL CONTRAST AUDIT FAILED: %d case(s) left the fatal-strike label under the %.1f:1 floor on BOTH the fill and the outline." % [_failures, CONTRAST_FLOOR])
		get_tree().quit(1)
		return
	print("PASSED: the fatal-strike label clears %.1f:1 against its real background in the" % CONTRAST_FLOOR)
	print("        light phase and in the swamp-night dark phase.")
	get_tree().quit(0)
