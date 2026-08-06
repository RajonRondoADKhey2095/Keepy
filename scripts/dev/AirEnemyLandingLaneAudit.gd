extends Node
## Dev-only diagnostic: measures the REAL distribution of AIR_ENEMY's
## landing lane (chantier 3, playtest-fixes batch --
## Obstacle._resolve_air_enemy_landing_lane) across a large sample,
## before trusting any theory about whether it is fair. Same technique
## as EnemyLaneAudit.gd (see that probe's own header for the full
## rationale): boots the real Game.tscn (real TrackManager, real pooled
## Obstacle/TrackSegment, real RNG calls), collision neutered so a single
## continuous run covers the whole sample without restart churn.
##
## WHY THIS IS A SEPARATE PROBE FROM AirHazardAudit.gd RATHER THAN AN
## EXTENSION OF IT: AirHazardAudit's Keepy never moves (no input
## injected, stationary on the center lane the whole run) -- exactly
## right for its OWN job (proving a landed AIR_ENEMY is lethal if ignored
## and safely jumpable if timed), but exactly WRONG for measuring landing
## LANE fairness: _resolve_air_enemy_landing_lane targets wherever the
## player actually IS, so a stationary Keepy would make every single
## sample land on lane 1 by construction, telling us nothing about the
## real distribution. This probe instead reuses AntiFrustrationAudit's
## OWN technique -- a randomized roaming bot -- specifically so the
## target lane varies across the sample the same way a real player's
## position would.
##
## Records TWO independent measurements per AIR_ENEMY, same rigor as
## EnemyLaneAudit.gd:
##   1. "landing lane" -- the lane index read the instant `air_enemy_landed`
##      flips false -> true (Obstacle._process_air_enemy), i.e. what the
##      obstacle's OWN state machine believes it committed to.
##   2. "contact lane" -- the lane index derived from the obstacle's
##      actual global_position.x the frame it crosses the player plane
##      (z >= 0), i.e. the position collision is really tested against.
## A mismatch between the two would itself be a bug (a landing that
## doesn't stick, or a lane that keeps drifting after air_enemy_landed
## flips true) -- reported separately so it cannot hide inside one count.
##
## ALSO reports, per sample, whether the landing lane matched the lane
## the bot happened to be on at the moment the AIR_ENEMY's descent began
## (the decision instant, AIR_ENEMY_DESCENT_LEAD_S before contact) -- a
## direct empirical check that the mechanism really is "target the
## player's current lane, redirected only when unsafe" rather than
## something else that merely happens to look plausible in aggregate.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/AirEnemyLandingLaneAudit.tscn

const TARGET_SAMPLES: int = 200 # same target/margin precedent as EnemyLaneAudit.gd
const MAX_SIM_SECONDS: float = 8000.0 # AIR_ENEMY is rarer than ENEMY (implicit remainder of the type weights) -- more headroom
const BOT_SWITCH_MIN_INTERVAL_S: float = 0.6 # same cadence as AntiFrustrationAudit's own roaming bot
const BOT_SWITCH_MAX_INTERVAL_S: float = 2.4

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0
var _next_bot_switch_t: float = 0.0

# segment instance id -> [t_landed, landed_x, decision_lane]
var _air_enemy_landing: Dictionary = {}
var _was_landed: Dictionary = {}
var _decision_lane_at_descent: Dictionary = {} # segment id -> lane index, captured once descent starts
var _prev_z: Dictionary = {}

var _landing_lane_counts: Array[int] = [0, 0, 0]
var _contact_lane_counts: Array[int] = [0, 0, 0]
var _landing_contact_mismatch: int = 0
var _matched_bot_lane_at_decision: int = 0
var _sample_count: int = 0

func _ready() -> void:
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	# Same neutering as EnemyLaneAudit.gd/PacingAudit.gd/AntiFrustrationAudit.gd:
	# clears collision so the probe survives contact instead of ending the
	# run, touching no gameplay source file.
	_keepy.collision_layer = 0
	_next_bot_switch_t = randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)

	print("=== AIR ENEMY LANDING LANE AUDIT ===")
	print("target samples: %d (landing event = air_enemy_landed false -> true)" % TARGET_SAMPLES)
	print("lane x values  : %s (index 0=left, 1=center, 2=right)" % [TrackSegment.LANE_X])
	print("bot: randomized roaming (same cadence as AntiFrustrationAudit) so the target lane varies")
	print("")

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return
	_t += delta
	_drive_bot()
	_scan_obstacles()
	if _sample_count >= TARGET_SAMPLES or _t >= MAX_SIM_SECONDS:
		_summary()
		get_tree().quit()

func _drive_bot() -> void:
	if _t < _next_bot_switch_t:
		return
	_next_bot_switch_t = _t + randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)
	_keepy.move_lane([-1, 1].pick_random())

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
			_was_landed.erase(key)
			_decision_lane_at_descent.erase(key)
			continue

		var z: float = obstacle.global_position.z

		if obstacle.obstacle_type == Obstacle.Type.AIR_ENEMY:
			# Capture the bot's lane the instant this instance's descent
			# begins (obstacle.get("_air_enemy_lane_decided") flips false
			# -> true) -- the SAME instant _resolve_air_enemy_landing_lane
			# reads it, so this is a faithful record of what the decision
			# was actually based on, not a guess made from outside.
			var decided: bool = obstacle.get("_air_enemy_lane_decided")
			if decided and not _decision_lane_at_descent.has(key):
				_decision_lane_at_descent[key] = _keepy.lane_index

			var landed: bool = obstacle.air_enemy_landed
			if not _was_landed.get(key, false) and landed:
				_air_enemy_landing[key] = [_t, obstacle.position.x]
			_was_landed[key] = landed

		if _prev_z.has(key):
			var prev: float = _prev_z[key]
			if prev < 0.0 and z >= 0.0 and obstacle.obstacle_type == Obstacle.Type.AIR_ENEMY:
				_on_air_enemy_passed(key, obstacle)
		_prev_z[key] = z

func _on_air_enemy_passed(key: int, obstacle: Obstacle) -> void:
	if not _air_enemy_landing.has(key):
		# Contact happened without ever observing a landing frame for this
		# segment's obstacle instance (e.g. probe started mid-approach on
		# the very first sample) -- skip, do not fabricate a landing lane.
		return
	var rec: Array = _air_enemy_landing[key]
	var landed_x: float = rec[1]
	var contact_x: float = obstacle.global_position.x

	var landing_lane := _lane_index_for_x(landed_x)
	var contact_lane := _lane_index_for_x(contact_x)

	_landing_lane_counts[landing_lane] += 1
	_contact_lane_counts[contact_lane] += 1
	if landing_lane != contact_lane:
		_landing_contact_mismatch += 1

	if _decision_lane_at_descent.has(key) and _decision_lane_at_descent[key] == landing_lane:
		_matched_bot_lane_at_decision += 1

	_sample_count += 1
	_air_enemy_landing.erase(key)
	_decision_lane_at_descent.erase(key)

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
	print("landing/contact mismatches: %d (should be 0 -- a non-zero value IS a bug: the landing doesn't stick, or X keeps moving after landing)" % _landing_contact_mismatch)
	print("")
	if _sample_count == 0:
		print("no AIR_ENEMY reached the player during the run")
		return

	print("--- landing lane distribution (at the moment air_enemy_landed flips true) ---")
	_print_histogram(_landing_lane_counts)
	print("")
	print("--- contact lane distribution (at the moment the AIR_ENEMY crosses the player) ---")
	_print_histogram(_contact_lane_counts)
	print("")
	var match_pct := 100.0 * float(_matched_bot_lane_at_decision) / float(maxi(_sample_count, 1))
	print("landed on the bot's lane AT DECISION TIME: %d/%d (%.1f%%) -- <100%% is expected and healthy: it means" % [_matched_bot_lane_at_decision, _sample_count, match_pct])
	print("the anti-frustration redirect (TrackManager.lane_has_conflicting_jump_hazard) is actually firing")
	print("sometimes, not that the targeting itself is broken -- a redirect only overrides the target lane,")
	print("never abandons landing altogether.")

func _print_histogram(counts: Array[int]) -> void:
	var total := 0
	for c in counts:
		total += c
	var labels := ["left  (lane 0)", "center(lane 1)", "right (lane 2)"]
	for i in counts.size():
		var pct := 100.0 * float(counts[i]) / float(maxi(total, 1))
		print("  %s : %4d  (%5.1f%%)" % [labels[i], counts[i], pct])
