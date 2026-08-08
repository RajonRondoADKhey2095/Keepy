extends Node
## Headless validation probe for the Decor.gd recycle fix -- not part of
## the shipped game, run manually via `godot4 --headless` against
## DecorParallaxProbe.tscn. Steps _physics_process for several hundred
## frames (spanning many recycle cycles per hill, at multiple speed
## stages) and asserts every hill stays within its own layer's
## [spawn_z_min, spawn_z_max] band -- i.e. apparent distance never drifts
## toward the camera/track regardless of how many times a hill recycles.

func _ready() -> void:
	GameState.start_run()
	var decor := Decor.new()
	add_child(decor)

	var violations := 0
	var min_seen := {}
	var max_seen := {}
	for frame in 2000:
		# Sweep through the speed stages so the probe also covers the
		# faster-recycling regime late in a run, not just START_SPEED.
		GameState.current_speed = 8.0 + float(frame) * 0.05
		decor._physics_process(1.0 / 60.0)
		for layer_index in Decor._LAYERS.size():
			var layer: Dictionary = Decor._LAYERS[layer_index]
			var lo: float = layer["spawn_z_min"]
			var hi: float = layer["spawn_z_max"]
			for hill in decor._pools[layer_index]:
				var z: float = hill.position.z
				if not min_seen.has(layer_index) or z < min_seen[layer_index]:
					min_seen[layer_index] = z
				if not max_seen.has(layer_index) or z > max_seen[layer_index]:
					max_seen[layer_index] = z
				if z < lo - 0.01 or z > hi + 0.01:
					violations += 1
					if violations <= 5:
						print("VIOLATION frame=%d layer=%d z=%f band=[%f,%f]" % [frame, layer_index, z, lo, hi])

	for layer_index in Decor._LAYERS.size():
		print("layer %d observed z range: [%f, %f]" % [layer_index, min_seen[layer_index], max_seen[layer_index]])

	if violations == 0:
		print("PASS: 2000 frames, all hills stayed within their spawn band")
	else:
		print("FAIL: %d out-of-band frames" % violations)
	get_tree().quit(0 if violations == 0 else 1)
