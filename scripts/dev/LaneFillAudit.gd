extends Node
## Dev-only diagnostic: measures how many DISTINCT lanes can be
## simultaneously occupied by an active obstacle, restricted to the
## LOWEST speed palier (GameState.STAGE_SPEEDS[0], the first
## GameState.STAGE_START_S[1] seconds of a run) -- the exact question the
## playtest-fixes-2 task asks to verify BEFORE touching anything: "the map
## probably already uses its full width too early".
##
## Same technique as PacingAudit.gd/EnemyLaneAudit.gd (boots the real
## Game.tscn, neuters collision so the probe survives) but samples via
## REPEATED RESETS rather than one long run: the lowest palier only lasts
## STAGE_START_S[1] seconds (6s) before the game itself advances past it
## (untouched by this batch, see the task's own constraint), so a single
## boot only ever offers one short window of stage-0 data. Resetting
## GameState + TrackManager back to a fresh run the instant stage 0 ends
## turns that into as many independent stage-0 samples as needed --
## exactly the run_time_s window the real early game actually uses, not a
## hand-held approximation of it.
##
## "Occupied" here means an obstacle is currently a visible, active child
## of one of TrackManager's pooled segments -- i.e. anywhere across the
## whole SEGMENT_COUNT*SEGMENT_LENGTH=140m pooled track ahead of the
## player, not just an imminent one. That is deliberate: the playtest
## complaint is about how FULL the track already LOOKS at low speed, which
## is a question about the whole visible span, not just the next frame's
## reaction budget (AntiFrustrationAudit.gd already covers that separate
## question).
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/LaneFillAudit.tscn

const TARGET_RESETS: int = 150 # ~150 * 6s = 900s of stage-0 data, ample margin

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _resets_done: int = 0
var _frames_checked: int = 0

# Histogram: index i = number of frames where exactly i distinct lanes
# had >=1 active obstacle simultaneously (0..3).
var _lane_count_histogram: Array[int] = [0, 0, 0, 0]
var _max_lanes_seen: int = 0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "LaneFillAudit")
	# Must run BEFORE Game.tscn is instantiated below -- see DevSeed.gd.
	# No-op unless `-- --seed=<int>` was passed.
	var seeded := DevSeed.apply()
	print("=== LANE FILL AUDIT (lowest speed palier) ===")
	print("rng             : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("palier 0 speed  : %.1f m/s" % GameState.STAGE_SPEEDS[0])
	print("palier 0 window : 0s .. %.1fs (GameState.STAGE_START_S[1])" % GameState.STAGE_START_S[1])
	print("target resets   : %d" % TARGET_RESETS)
	print("")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	# Same neutering as PacingAudit.gd/AntiFrustrationAudit.gd -- this
	# probe only cares about what TrackManager generates, not whether
	# Keepy would survive it.
	_keepy.collision_layer = 0

func _physics_process(_delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return

	if GameState.run_time_s >= GameState.STAGE_START_S[1]:
		_resets_done += 1
		if _resets_done >= TARGET_RESETS:
			_summary()
			get_tree().quit(0)
			return
		# GameState.start_run() emits state_changed synchronously, which
		# Game._on_state_changed handles by calling _reset_world() itself
		# (track_manager.reset() + keepy.reset_lane()) -- no need to also
		# call those here, that would just double up the reset.
		GameState.start_run()
		return

	_check_lane_occupancy()

func _check_lane_occupancy() -> void:
	_frames_checked += 1
	var lanes_occupied: Array[bool] = [false, false, false]
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		var lane := _lane_index_for_x(obstacle.position.x)
		if lane == -1:
			continue # mid-sway ENEMY, not yet on a discrete lane -- see EnemyLaneAudit.gd for the same caveat
		lanes_occupied[lane] = true

	var count := 0
	for occupied in lanes_occupied:
		if occupied:
			count += 1
	_lane_count_histogram[count] += 1
	_max_lanes_seen = maxi(_max_lanes_seen, count)

func _active_obstacle_in(segment: TrackSegment) -> Node3D:
	for child in segment.get_children():
		if child is Obstacle and child.visible:
			return child
	return null

func _lane_index_for_x(x: float) -> int:
	for lane in TrackSegment.LANE_X.size():
		if absf(x - TrackSegment.LANE_X[lane]) < 0.01:
			return lane
	return -1

func _summary() -> void:
	print("--- result ---")
	print("resets performed      : %d" % _resets_done)
	print("physics frames checked: %d (all within palier 0, run_time_s < %.1fs)" % [_frames_checked, GameState.STAGE_START_S[1]])
	print("")
	print("--- distinct lanes simultaneously occupied by an active obstacle ---")
	for i in _lane_count_histogram.size():
		var n := _lane_count_histogram[i]
		var pct := 100.0 * float(n) / float(maxi(_frames_checked, 1))
		print("  %d lane(s) occupied: %6d frames (%5.1f%%)" % [i, n, pct])
	print("")
	print("MAX distinct lanes occupied at once during palier 0: %d / 3" % _max_lanes_seen)
