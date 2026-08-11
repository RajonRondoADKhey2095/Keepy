extends Node
## Capture probe for the dark-mode SWAMP GRADE -- NOT part of the shipped
## game (nothing instantiates it; scripts/dev/* is excluded from the web
## export). Must run with a REAL GL context, since the whole point is to
## prove the shader compiles and runs under the Compatibility renderer
## this project pins:
##
##   xvfb-run -a godot4 --rendering-driver opengl3 \
##     --path . res://scripts/dev/SwampGradeCapture.tscn
##
## REPLACES InvertCapture.gd, whose assertion died with the invert it was
## written for. That probe checked `normal + inverted ~= (1,1,1)` per
## channel -- a correct test of a per-channel negative, and meaningless
## against a luminance-keyed ramp. Worth recording that it had ALREADY
## stopped meaning anything before this refonte: once the six-hue tint
## pass was added on top of the invert, the sum stopped landing on 1 and
## the probe printed INVERSION_VERIFIED=NO on healthy code. It was a probe
## whose premise had quietly expired and which nobody had re-read, so it
## is renamed rather than patched -- a file called InvertCapture measuring
## a grade is the same trap one layer along.
##
## WHAT IT ASSERTS NOW, and each of these is a property the swamp grade is
## supposed to have rather than a number someone liked:
##
##   1. THE GRADE FIRES AT ALL. The mean frame colour must actually move
##      between intensity 0 and 1. Catches the shader failing to compile,
##      the ColorRect staying hidden, or the uniforms never being pushed --
##      all of which render as "the game looks normal" and would otherwise
##      be found on a device.
##
##   2. IT LANDS IN THE SWAMP. The fully-graded frame must be GREENER than
##      it is red or blue (g > r and g > b). This is the one that would
##      have caught the actual defect this refonte exists to fix: two of
##      the old six hues drove the whole frame BLUE, and no probe anywhere
##      said so -- it took a person looking at a phone. A cheap directional
##      check on the mean pixel is enough to notice a night that is not
##      the colour it is supposed to be.
##
##   3. IT GETS DARKER. Grading into a night palette that is not darker
##      than day is a contradiction, and mean luminance is the cheapest
##      possible statement of it.
##
##   4. THE FADE IS MONOTONE. Half intensity must sit between the two ends
##      on mean luminance, so the transition is a fade and not a pop --
##      the same property InvertCapture's half-intensity check covered,
##      kept because it is still true and still worth guarding.
##
## WHAT IT DELIBERATELY DOES NOT DO: judge contrast. Mean frame colour says
## nothing about whether the pursuer reads against the ground -- that is
## PursuerContrastAudit's question, measured on sampled regions with a WCAG
## metric. This probe answers "is the swamp on, and is it a swamp", nothing
## finer.

const SETTLE_FRAMES: int = 20

var _game: Node = null

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "SwampGradeCapture")
	_run.call_deferred()

func _run() -> void:
	var game_scene: PackedScene = load("res://scenes/Game.tscn")
	_game = game_scene.instantiate()
	add_child(_game)

	# Let the world spawn and a few frames render before sampling.
	await _wait_frames(SETTLE_FRAMES)

	# The dark cycle is driven from GameState in the shipped game, so the
	# probe drives THAT rather than the shader: DarkModeEffect's own
	# _process stays live and does the real work, uniforms and sky alike.
	await _settle_at(0.0)
	var day := _sample()

	await _settle_at(1.0)
	var night := _sample()

	# 0.5 is the one value GameState has no stable target for -- the phase
	# machine only ever converges on 0 or 1 -- so it is re-pinned every
	# frame and the intensity ACTUALLY in force at sample time is printed
	# below rather than assumed to be the value asked for.
	await _settle_at(0.5)
	var half_intensity := GameState.dark_intensity
	var half := _sample()

	print("day    mean rgb = (%.4f, %.4f, %.4f)  luma %.4f" % [day.x, day.y, day.z, _luma(day)])
	print("night  mean rgb = (%.4f, %.4f, %.4f)  luma %.4f" % [night.x, night.y, night.z, _luma(night)])
	print("half   mean rgb = (%.4f, %.4f, %.4f)  luma %.4f   (intensity actually in force: %.3f)" % [half.x, half.y, half.z, _luma(half), half_intensity])
	print("")

	var moved := (night - day).length()
	var green_dominant := night.y > night.x and night.y > night.z
	var darker := _luma(night) < _luma(day)
	var monotone := _luma(half) < _luma(day) and _luma(half) > _luma(night)

	print("1 grade fires      : %s (mean rgb moved %.4f, need > 0.02)" % ["OK" if moved > 0.02 else "FAIL", moved])
	print("2 lands in swamp   : %s (night g %.4f vs r %.4f / b %.4f)" % ["OK" if green_dominant else "FAIL", night.y, night.x, night.z])
	print("3 night is darker  : %s (luma %.4f -> %.4f)" % ["OK" if darker else "FAIL", _luma(day), _luma(night)])
	print("4 fade is monotone : %s (half luma %.4f sits between)" % ["OK" if monotone else "FAIL", _luma(half)])

	var ok := moved > 0.02 and green_dominant and darker and monotone
	print("")
	print("SWAMP_GRADE_VERIFIED=" + ("yes" if ok else "NO"))
	if not ok:
		push_error("SWAMP GRADE CAPTURE FAILED: the dark phase is not rendering as a darker, green-dominant, smoothly faded grade.")
		get_tree().quit(1)
		return
	get_tree().quit()

## Pins the dark cycle at a chosen intensity and HOLDS it there.
##
## Writing GameState.dark_intensity once is NOT enough, and the first
## version of this probe got that wrong in a way worth recording: while
## the run is PLAYING, GameState._update_dark_cycle move_toward()s the
## intensity every frame toward whatever the CURRENT dark_phase implies.
## With the phase left at INACTIVE that target is 0, so a one-shot write
## of 1.0 decayed back over the settle frames and the probe sampled a
## half-faded frame while reporting it as the full night -- it read as a
## colour defect in the shader, which is exactly the kind of false lead a
## probe should not manufacture. Matching the PHASE to the intensity makes
## GameState's own move_toward hold the value instead of fighting it, and
## pushing the phase start to INF stops the cycle flipping mid-measurement.
## Same approach DarkPaletteAudit._hold_state already uses.
func _settle_at(intensity: float) -> void:
	GameState.state = GameState.State.PLAYING
	# THE WORLD MUST BE HELD STILL, and this is a correction rather than a
	# tidy-up. Left running, the track scrolls, Keepy meets a hazard, and
	# HUD.gd's full-screen strike flash lands over the frame -- so the mean
	# pixel this probe reports stops being "the world under the grade" and
	# becomes "the world under the grade plus a red flash caught at some
	# arbitrary point in its decay". Measured, not theorised: with the run
	# live, the DAY sample came back (0.84, 0.50, 0.41) -- bright orange --
	# instead of the pale blue sky that is actually there, and both verdicts
	# that compare day against night inverted as a result. This is the same
	# defect docs/PROBE_AUDIT.md records as F10c for the strike-contrast
	# probes; it generalises to any probe that samples whole frames while a
	# run is allowed to advance.
	GameState.current_speed = 0.0
	GameState.pursuer_enabled = false
	GameState.dark_phase = GameState.DarkPhase.DARK if intensity > 0.5 else GameState.DarkPhase.LIGHT
	GameState.set("_dark_phase_started_s", INF)
	for i in SETTLE_FRAMES:
		# Re-pinned EVERY frame, not once: _update_dark_cycle runs on the
		# same frames this loop does.
		GameState.dark_intensity = intensity
		await get_tree().process_frame
	GameState.dark_intensity = intensity

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _luma(c: Vector3) -> float:
	return 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z

func _sample() -> Vector3:
	var img: Image = get_viewport().get_texture().get_image()
	var acc := Vector3.ZERO
	var samples := 0
	# Sample a coarse grid over the whole frame rather than every pixel.
	var step := 16
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			acc += Vector3(c.r, c.g, c.b)
			samples += 1
	return acc / float(samples)
