extends Node
## Dev-only end-to-end pacing AUDIT. Boots the real Game.tscn (real
## TrackManager, real pooled obstacles, real DarkModeEffect) and measures
## -- rather than re-reads -- everything the pacing depends on:
##
##   1. the speed palier sequence, with the distance actually covered in
##      each palier (so a palier's speed is cross-checked against
##      metres/second measured on the track, not just against the
##      constant it was set from);
##   2. the dark/light cycle transitions and their spacing;
##   3. the REACTION BUDGET the player actually gets between two
##      consecutive obstacles, per palier -- measured at the moment each
##      obstacle passes the player plane, so it reflects the adaptive
##      spacing under real speed, not a formula;
##   4. the ENEMY lane lock: how long before contact each enemy actually
##      commits, and how far a lane switch STARTED at that exact frame
##      would have got by the time contact happens.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/PacingAudit.tscn
##
## NOTE ON DISABLING DEATH: this probe never dodges anything, so Keepy
## must not die. It does that by clearing Keepy's collision_layer (see
## _ready) rather than by hand-editing Keepy.die() and remembering to
## revert it -- gameplay source is left byte-identical, so no probe run
## can ever leak a neutered die() into a commit. Keepy's collision_MASK
## is untouched, so it still stands on the track normally. Side effect:
## collectibles are not picked up either (they detect Keepy the same
## way), so score/nut counts stay at their distance-only value. That is
## irrelevant to pacing and is the price of not touching gameplay code.

const SIM_SECONDS: float = 180.0

## Simulated lane switches are evaluated against the same lerp Keepy
## uses (Keepy.gd _physics_process). The discrete per-frame lerp
## position.x = lerp(x, target, 1 - exp(-k*dt)) leaves a remaining error
## of exp(-k*dt) per frame, so after a duration d the remaining error is
## exactly exp(-k*d) whatever the frame size -- the closed form below is
## not an approximation of the frame loop, it is equal to it.
const LANE_SWITCH_SPEED: float = Keepy.LANE_SWITCH_SPEED
## "Switch complete" threshold, matching Obstacle.LANE_SWITCH_TIME_S's
## own definition (95% of the way there).
const LANE_SWITCH_DONE_FRACTION: float = 0.95

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0
var _last_stage: int = -1
var _last_phase: int = -1
var _stage_started_t: float = 0.0
var _stage_started_dist: float = 0.0
var _phase_started_t: float = 0.0

# Per-segment tracking of the obstacle it carries. Keyed by the SEGMENT's
# instance id: each TrackSegment owns exactly one pooled Obstacle node for
# the whole run, so the key is stable across recycles.
var _prev_z: Dictionary = {}
var _enemy_lock: Dictionary = {} # segment id -> [t_lock, ttc_at_lock, speed]
var _was_settling: Dictionary = {}

var _last_pass_t: float = -1.0
var _last_pass_stage: int = -1
# Per palier: [count, min_gap_s, sum_gap_s]
var _gap_stats: Array = []
# Enemy lock measurements: [min_lock_to_contact, count, sum]
var _enemy_min: float = INF
var _enemy_count: int = 0
var _enemy_sum: float = 0.0
var _enemy_min_speed: float = 0.0
# Same measurement restricted to enemies met at the speed CAP -- the
# case the enemy window has to be re-proven against, rather than assumed
# to carry over from the speed it was originally tuned at.
var _enemy_cap_min: float = INF
var _enemy_cap_count: int = 0

func _ready() -> void:
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	# See the header note: this is what keeps the probe alive, and it
	# touches no gameplay source file.
	_keepy.collision_layer = 0

	for i in GameState.STAGE_SPEEDS.size():
		_gap_stats.append([0, INF, 0.0])

	print("=== PACING AUDIT ===")
	print("paliers: %s" % [GameState.STAGE_SPEEDS])
	print("starts : %s" % [GameState.STAGE_START_S])
	print("lane switch to %d%%: %.3fs (Obstacle.LANE_SWITCH_TIME_S)"
		% [int(LANE_SWITCH_DONE_FRACTION * 100.0), Obstacle.LANE_SWITCH_TIME_S])
	print("enemy lock window   : %.3fs before contact (ENEMY_REACTION_WINDOW_S)"
		% Obstacle.ENEMY_REACTION_WINDOW_S)
	print("")
	print("--- timeline ---")

func _physics_process(delta: float) -> void:
	_t += delta
	_report_stage()
	_report_dark()
	_scan_obstacles()
	if _t >= SIM_SECONDS:
		_summary()
		get_tree().quit()

func _report_stage() -> void:
	if GameState.stage_index == _last_stage:
		return
	if _last_stage >= 0:
		var dt := _t - _stage_started_t
		var dd := GameState.distance_travelled - _stage_started_dist
		print("    palier %d held %6.2fs, covered %8.2fm -> %6.2f m/s measured (table says %.1f)"
			% [_last_stage, dt, dd, dd / maxf(dt, 0.0001), GameState.STAGE_SPEEDS[_last_stage]])
	_last_stage = GameState.stage_index
	_stage_started_t = _t
	_stage_started_dist = GameState.distance_travelled
	print("t=%7.2fs  PALIER %d  speed %5.1f m/s  dist %8.1fm"
		% [_t, GameState.stage_index, GameState.current_speed, GameState.distance_travelled])

func _report_dark() -> void:
	if GameState.dark_phase == _last_phase:
		return
	var held := _t - _phase_started_t
	var label: String = ["INACTIVE", "DARK", "LIGHT"][GameState.dark_phase]
	if _last_phase >= 0:
		print("t=%7.2fs  DARK -> %-8s (previous phase held %6.2fs, intensity %.2f)"
			% [_t, label, held, GameState.dark_intensity])
	else:
		print("t=%7.2fs  DARK -> %-8s (intensity %.2f)" % [_t, label, GameState.dark_intensity])
	_last_phase = GameState.dark_phase
	_phase_started_t = _t

## Walks every live TrackSegment, finds the pooled Obstacle it owns, and
## records the two events that matter: an obstacle crossing the player
## plane (z going negative -> non-negative), and an ENEMY committing to
## its final lane.
func _scan_obstacles() -> void:
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle: Obstacle = null
		for child in segment.get_children():
			if child is Obstacle:
				obstacle = child
				break
		if obstacle == null:
			continue
		var key := segment.get_instance_id()
		if not obstacle.visible:
			_prev_z.erase(key)
			_was_settling.erase(key)
			continue

		var z: float = obstacle.global_position.z

		# ENEMY lane lock: the frame _enemy_settling flips true -> false.
		if obstacle.obstacle_type == Obstacle.Type.ENEMY:
			var settling: bool = obstacle._enemy_settling
			if _was_settling.get(key, false) and not settling:
				_enemy_lock[key] = [_t, -z / GameState.current_speed, GameState.current_speed]
			_was_settling[key] = settling

		if _prev_z.has(key):
			var prev: float = _prev_z[key]
			if prev < 0.0 and z >= 0.0:
				_on_obstacle_passed(key, obstacle)
		_prev_z[key] = z

func _on_obstacle_passed(key: int, obstacle: Obstacle) -> void:
	var stage := GameState.stage_index
	if _last_pass_t >= 0.0 and _last_pass_stage == stage:
		# Gap measured between two obstacles that both belong to the same
		# palier, so the gap is attributable to one speed rather than
		# straddling a step.
		var gap: float = _t - _last_pass_t
		var stats: Array = _gap_stats[stage]
		stats[0] += 1
		stats[1] = minf(stats[1], gap)
		stats[2] += gap
	_last_pass_t = _t
	_last_pass_stage = stage

	if _enemy_lock.has(key):
		var rec: Array = _enemy_lock[key]
		var lock_to_contact: float = _t - float(rec[0])
		_enemy_count += 1
		_enemy_sum += lock_to_contact
		if lock_to_contact < _enemy_min:
			_enemy_min = lock_to_contact
			_enemy_min_speed = float(rec[2])
		if is_equal_approx(float(rec[2]), GameState.MAX_SPEED):
			_enemy_cap_count += 1
			_enemy_cap_min = minf(_enemy_cap_min, lock_to_contact)
		_enemy_lock.erase(key)

## Fraction of a lane switch completed after `d` seconds -- see the
## LANE_SWITCH_SPEED comment at the top for why this closed form is exact
## rather than an approximation of the per-frame lerp.
func _switch_completion(d: float) -> float:
	return 1.0 - exp(-LANE_SWITCH_SPEED * d)

func _summary() -> void:
	print("")
	print("--- obstacle reaction budget, per palier ---")
	print("(gap = measured seconds between two consecutive obstacles reaching")
	print(" the player; budget = gap minus the %.3fs the lane switch itself" % Obstacle.LANE_SWITCH_TIME_S)
	print(" takes, i.e. the time left to READ the next obstacle and commit)")
	print("")
	print(" idx  speed   samples   min gap   min budget   mean gap")
	for i in _gap_stats.size():
		var stats: Array = _gap_stats[i]
		if int(stats[0]) == 0:
			print("  %d   %5.1f        0        --           --          --" % [i, GameState.STAGE_SPEEDS[i]])
			continue
		var n := int(stats[0])
		var min_gap := float(stats[1])
		var mean_gap := float(stats[2]) / float(n)
		print("  %d   %5.1f    %5d    %6.3fs     %6.3fs     %6.3fs"
			% [i, GameState.STAGE_SPEEDS[i], n, min_gap,
			   min_gap - Obstacle.LANE_SWITCH_TIME_S, mean_gap])

	print("")
	print("--- enemy lane lock ---")
	if _enemy_count == 0:
		print("  no enemy reached the player during the run")
	else:
		var mean := _enemy_sum / float(_enemy_count)
		var completion := _switch_completion(_enemy_min)
		print("  samples                       : %d" % _enemy_count)
		print("  worst lock -> contact measured: %.4fs (at %.1f m/s)" % [_enemy_min, _enemy_min_speed])
		print("  mean  lock -> contact measured: %.4fs" % mean)
		print("  nominal window (constant)     : %.4fs" % Obstacle.ENEMY_REACTION_WINDOW_S)
		print("  lane switch needs             : %.4fs to reach %d%%"
			% [Obstacle.LANE_SWITCH_TIME_S, int(LANE_SWITCH_DONE_FRACTION * 100.0)])
		print("  switch completion in worst case: %.2f%%  -> %s"
			% [completion * 100.0,
			   "CLEARABLE" if completion >= LANE_SWITCH_DONE_FRACTION else "NOT CLEARABLE"])
		print("  spare time in worst case      : %.4fs" % (_enemy_min - Obstacle.LANE_SWITCH_TIME_S))
		if _enemy_cap_count == 0:
			print("  AT THE CAP (%.1f m/s)          : no sample" % GameState.MAX_SPEED)
		else:
			var cap_completion := _switch_completion(_enemy_cap_min)
			print("  AT THE CAP (%.1f m/s)          : %d samples, worst %.4fs, switch %.2f%% -> %s"
				% [GameState.MAX_SPEED, _enemy_cap_count, _enemy_cap_min, cap_completion * 100.0,
				   "CLEARABLE" if cap_completion >= LANE_SWITCH_DONE_FRACTION else "NOT CLEARABLE"])
	print("")
	print("--- end: t=%.2fs  palier %d  speed %.1f m/s  distance %.1fm ---"
		% [_t, GameState.stage_index, GameState.current_speed, GameState.distance_travelled])
