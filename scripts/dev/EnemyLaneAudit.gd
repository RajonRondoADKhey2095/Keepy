extends Node
## Dev-only diagnostic: measures the REAL distribution of ENEMY obstacles'
## final (locked) lane across a large sample, before trusting any theory
## about why it might be skewed. Boots the real Game.tscn (real
## TrackManager, real pooled Obstacle/TrackSegment, real RNG calls) --
## same technique as PacingAudit.gd (see its header for the collision-
## neutering rationale, reused verbatim here).
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/EnemyLaneAudit.tscn
##
## Records TWO independent measurements per enemy so a bug in ONE would
## show up as a mismatch between them:
##   1. "locked lane"  -- the lane index read the instant _enemy_settling
##      flips true -> false (Obstacle._physics_process), i.e. what the
##      obstacle's OWN state machine believes it committed to.
##   2. "contact lane" -- the lane index derived from the obstacle's
##      actual global_position.x the frame it crosses the player plane
##      (z >= 0), i.e. the position collision is really tested against.
## If these two ever disagreed, that would itself be the bug (a lock that
## doesn't stick). Reported separately so that mismatch cannot hide inside
## a single aggregated count.

const TARGET_SAMPLES: int = 200 # ">= 100" required by the diagnostic, doubled for margin
const MAX_SIM_SECONDS: float = 6000.0 # safety cap so a starved run still terminates

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0

# segment instance id -> [t_lock, locked_x]
var _enemy_lock: Dictionary = {}
var _was_settling: Dictionary = {}
var _prev_z: Dictionary = {}

# lane index (0=left, 1=center, 2=right) -> count
var _locked_lane_counts: Array[int] = [0, 0, 0]
var _contact_lane_counts: Array[int] = [0, 0, 0]
var _lock_contact_mismatch: int = 0
var _sample_count: int = 0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "EnemyLaneAudit")
	# Must run BEFORE Game.tscn is instantiated below -- see DevSeed.gd.
	# This probe never called it, so `-- --seed=<int>` was silently
	# ignored and every run was exploratory even when a reproducible one
	# was asked for. Same defect as AirHazardAudit (finding F6).
	var seeded := DevSeed.apply()
	# The PURSUER is a parallel system and is not what this probe measures
	# -- see GameState.pursuer_enabled, and AntiFrustrationAudit.gd for the
	# identical fix applied when the pursuer landed. Written 08-05, long
	# before the pursuer, and never given it.
	#
	# The failure here was QUIETER than ChargerAudit's and worse for it.
	# This probe has no `state != PLAYING` early return, so its simulated
	# clock keeps advancing after the pursuer captures the bot at ~71s --
	# it does not freeze. But the TRACK stops, so no further ENEMY ever
	# locks or reaches the player: the sample counter stops dead while the
	# clock runs on toward MAX_SIM_SECONDS. Measured: killed at a 900s
	# wall-clock cap without finishing.
	#
	# Had it reached MAX_SIM_SECONDS it would have printed a lane
	# distribution built from only the first ~71 seconds of one run and
	# exited 0 -- a "measurement" of 3 percent of the requested sample,
	# reported as a result. The hang is the symptom; the corrupted sample
	# is the actual defect.
	GameState.pursuer_enabled = false
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	# Same neutering as PacingAudit.gd: clears collision so the probe
	# survives contact instead of ending the run, touching no gameplay
	# source file. See PacingAudit.gd header for the full rationale.
	_keepy.collision_layer = 0

	print("=== ENEMY LANE AUDIT ===")
	print("rng           : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("target samples: %d (lock event = _enemy_settling true -> false)" % TARGET_SAMPLES)
	print("lane x values  : %s (index 0=left, 1=center, 2=right)" % [TrackSegment.LANE_X])
	print("")

func _physics_process(delta: float) -> void:
	_t += delta
	_scan_obstacles()
	if _sample_count >= TARGET_SAMPLES or _t >= MAX_SIM_SECONDS:
		_summary()
		get_tree().quit(_verdict())

## The exit code, taken from the numbers _summary() just printed.
##
## THIS PROBE USED TO EXIT 0 UNCONDITIONALLY, including on a run that hit
## MAX_SIM_SECONDS having gathered a fraction of TARGET_SAMPLES, and
## including on the one condition its own output calls a bug ("a non-zero
## value IS a bug"). Under the pursuer defect fixed above that is exactly
## the run it would have produced -- so the corrupted sample would have
## been reported as a pass. The distribution itself stays reported rather
## than gated (there is no fair-lane threshold to assert, and inventing
## one is the fitted-bar mistake this folder has been undoing), but
## under-sampling and lock/contact disagreement are contracts.
func _verdict() -> int:
	if _sample_count < TARGET_SAMPLES:
		push_error("ENEMY LANE AUDIT INCONCLUSIVE: only %d of %d samples gathered before MAX_SIM_SECONDS -- the distribution above is under-sampled, not a measurement." % [
			_sample_count, TARGET_SAMPLES])
		return 1
	if _lock_contact_mismatch > 0:
		push_error("ENEMY LANE AUDIT FAILED: %d lock/contact mismatch(es) -- the locked lane does not stick, or X keeps moving after _enemy_settling clears." % _lock_contact_mismatch)
		return 1
	print("")
	print("PASSED: %d samples, 0 lock/contact mismatches. Distribution reported, not gated." % _sample_count)
	return 0

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

		if obstacle.obstacle_type == Obstacle.Type.ENEMY:
			var settling: bool = obstacle._enemy_settling
			if _was_settling.get(key, false) and not settling:
				_enemy_lock[key] = [_t, obstacle.position.x]
			_was_settling[key] = settling

		if _prev_z.has(key):
			var prev: float = _prev_z[key]
			if prev < 0.0 and z >= 0.0 and obstacle.obstacle_type == Obstacle.Type.ENEMY:
				_on_enemy_passed(key, obstacle)
		_prev_z[key] = z

func _on_enemy_passed(key: int, obstacle: Obstacle) -> void:
	if not _enemy_lock.has(key):
		# Contact happened without ever observing a lock frame for this
		# segment's obstacle instance (e.g. probe started mid-approach on
		# the very first sample) -- skip, do not fabricate a lock lane.
		return
	var rec: Array = _enemy_lock[key]
	var locked_x: float = rec[1]
	var contact_x: float = obstacle.global_position.x

	var locked_lane := _lane_index_for_x(locked_x)
	var contact_lane := _lane_index_for_x(contact_x)

	_locked_lane_counts[locked_lane] += 1
	_contact_lane_counts[contact_lane] += 1
	if locked_lane != contact_lane:
		_lock_contact_mismatch += 1
	_sample_count += 1

	_enemy_lock.erase(key)

func _lane_index_for_x(x: float) -> int:
	var best_index := 0
	var best_dist := INF
	for i in TrackSegment.LANE_X.size():
		var d := absf(x - TrackSegment.LANE_X[i])
		if d < best_dist:
			best_dist = d
			best_index = i
	return best_index

func _summary() -> void:
	print("--- result ---")
	print("simulated time         : %.1fs" % _t)
	print("samples collected      : %d%s" % [
		_sample_count,
		" (TARGET NOT REACHED before MAX_SIM_SECONDS -- read with caution)" if _sample_count < TARGET_SAMPLES else ""
	])
	print("lock/contact mismatches: %d (should be 0 -- a non-zero value IS a bug: the lock doesn't stick)" % _lock_contact_mismatch)
	print("")
	if _sample_count == 0:
		print("no enemy reached the player during the run")
		return

	print("--- locked lane distribution (at the moment _enemy_settling flips false) ---")
	_print_histogram(_locked_lane_counts)
	print("")
	print("--- contact lane distribution (at the moment the enemy crosses the player) ---")
	_print_histogram(_contact_lane_counts)

func _print_histogram(counts: Array[int]) -> void:
	var total := 0
	for c in counts:
		total += c
	var labels := ["left  (lane 0)", "center(lane 1)", "right (lane 2)"]
	for i in counts.size():
		var pct := 100.0 * float(counts[i]) / float(maxi(total, 1))
		print("  %s : %4d  (%5.1f%%)" % [labels[i], counts[i], pct])
	var lateral := counts[0] + counts[2]
	var lateral_pct := 100.0 * float(lateral) / float(maxi(total, 1))
	var center_pct := 100.0 * float(counts[1]) / float(maxi(total, 1))
	print("  ---")
	print("  lateral (0+2) : %4d  (%5.1f%%)" % [lateral, lateral_pct])
	print("  center  (1)   : %4d  (%5.1f%%)" % [counts[1], center_pct])
