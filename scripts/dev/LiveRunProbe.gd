extends Node
## End-to-end pacing probe: runs the REAL Game.tscn (real TrackManager,
## real obstacles, real DarkModeEffect node) and logs the palier and
## dark-cycle transitions as they actually happen in the running game,
## rather than driving GameState in isolation like PacingProbe.gd.
##
## Dev-only, excluded from the web export. Run with a fixed timestep so
## the simulated clock is exact and the run completes far faster than
## real time:
##
##   godot4 --headless --fixed-fps 60 --quit-after 25400 \
##     res://scripts/dev/LiveRunProbe.gd's scene
##
## Keepy.die() must be neutered for the duration (the probe never
## dodges), which is done by hand and reverted -- it is not committed as
## a permanent switch in gameplay code.

var _last_stage: int = -1
var _last_phase: int = -1
var _t: float = 0.0

func _ready() -> void:
	add_child(load("res://scenes/Game.tscn").instantiate())

func _process(delta: float) -> void:
	_t += delta
	if GameState.stage_index != _last_stage:
		_last_stage = GameState.stage_index
		print("t=%8.2fs  stage %d  speed %5.1f m/s  dist %7.1fm  score %d"
			% [_t, GameState.stage_index, GameState.current_speed,
			   GameState.distance_travelled, GameState.score])
	if GameState.dark_phase != _last_phase:
		_last_phase = GameState.dark_phase
		print("t=%8.2fs  DARK PHASE -> %s  (intensity %.2f, state %d)"
			% [_t, ["INACTIVE", "DARK", "LIGHT"][GameState.dark_phase],
			   GameState.dark_intensity, GameState.state])
