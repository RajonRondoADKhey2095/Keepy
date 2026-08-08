extends SceneTree
## Headless pacing probe -- NOT part of the shipped game (never
## instantiated by any scene; run explicitly with
## `godot4 --headless --script res://scripts/dev/PacingProbe.gd`).
##
## Drives GameState's run clock at a fixed step for several simulated
## minutes and prints the speed palier sequence and the dark/light cycle
## transitions, so the pacing is verified against measured numbers
## instead of by re-reading the constants.

const STEP: float = 1.0 / 60.0
const SIM_SECONDS: float = 420.0

# Instantiated directly rather than read from the GameState autoload:
# a `--script` main loop replaces the SceneTree before autoloads are
# registered, so the singleton does not exist in this context. Same
# script, same constants -- just a standalone instance.
const GameStateScript := preload("res://scripts/autoload/GameState.gd")

func _init() -> void:
	var gs := GameStateScript.new()

	gs.start_run()

	var last_stage := -1
	var last_dark_phase := -1
	var last_intensity_bucket := -1
	var t := 0.0
	var steps := int(SIM_SECONDS / STEP)

	print("=== speed paliers (time-based) ===")
	for i in steps:
		gs.advance_time(STEP)
		t += STEP

		if gs.stage_index != last_stage:
			last_stage = gs.stage_index
			print("  t=%7.2fs  stage %d  speed %.1f m/s" % [t, gs.stage_index, gs.current_speed])

		# Dark cycle reporting only exists once the cycle feature lands;
		# guard so this probe also runs against the speed-only step.
		if "dark_phase" in gs:
			if gs.dark_phase != last_dark_phase:
				last_dark_phase = gs.dark_phase
				print("  t=%7.2fs  DARK PHASE -> %s" % [t, _phase_name(gs.dark_phase)])
			var bucket := int(gs.dark_intensity * 10.0)
			if bucket != last_intensity_bucket:
				last_intensity_bucket = bucket
				print("      t=%7.2fs  intensity %.2f" % [t, gs.dark_intensity])

	print("=== end: t=%.1fs  speed %.1f m/s  distance-independent ===" % [t, gs.current_speed])
	gs.free()
	quit()

func _phase_name(phase: int) -> String:
	match phase:
		0: return "INACTIVE"
		1: return "DARK"
		2: return "LIGHT"
	return "?"
