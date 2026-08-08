extends Node
## Capture probe for the dark-mode inversion shader -- NOT part of the
## shipped game (nothing instantiates it; scripts/dev/* is excluded from
## the web export). Must run with a REAL GL context, since the whole
## point is to prove the shader compiles and runs under the Compatibility
## renderer this project pins:
##
##   xvfb-run -a godot4 --rendering-driver opengl3 \
##     --quit-after 400 res://scripts/dev/InvertCapture.tscn
##
## Runs as its own main scene (so the GameState autoload exists) and
## hosts a real Game.tscn as a child.
##
## Captures the viewport twice -- once with the effect off, once with it
## forced to full intensity -- and prints the mean RGB of each plus the
## per-channel sum, so "the screen really did invert" is a measured
## number rather than a claim.

const SETTLE_FRAMES: int = 20

var _game: Node = null

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "InvertCapture")
	_run.call_deferred()

func _run() -> void:
	var game_scene: PackedScene = load("res://scenes/Game.tscn")
	_game = game_scene.instantiate()
	add_child(_game)

	# Let the world spawn and a few frames render before sampling.
	await _wait_frames(SETTLE_FRAMES)

	GameState.dark_intensity = 0.0
	await _wait_frames(SETTLE_FRAMES)
	var normal := _sample()

	GameState.dark_intensity = 1.0
	await _wait_frames(SETTLE_FRAMES)
	var inverted := _sample()

	print("normal   mean rgb = (%.4f, %.4f, %.4f)" % [normal.x, normal.y, normal.z])
	print("inverted mean rgb = (%.4f, %.4f, %.4f)" % [inverted.x, inverted.y, inverted.z])
	var total := normal + inverted
	print("sum      (expect ~1,1,1 per channel if truly inverted) = (%.4f, %.4f, %.4f)"
		% [total.x, total.y, total.z])

	var ok := absf(total.x - 1.0) < 0.05 and absf(total.y - 1.0) < 0.05 and absf(total.z - 1.0) < 0.05
	print("INVERSION_VERIFIED=" + ("yes" if ok else "NO"))

	# Half intensity must land near the midpoint (grey-ish), proving the
	# fade interpolates the inversion amount rather than toggling.
	GameState.dark_intensity = 0.5
	await _wait_frames(SETTLE_FRAMES)
	var half := _sample()
	print("half     mean rgb = (%.4f, %.4f, %.4f)" % [half.x, half.y, half.z])
	var mid := (normal + inverted) * 0.5
	print("half vs midpoint delta = (%.4f, %.4f, %.4f)"
		% [absf(half.x - mid.x), absf(half.y - mid.y), absf(half.z - mid.z)])

	get_tree().quit()

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

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
