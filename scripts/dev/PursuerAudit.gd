extends Node
## Dev-only diagnostic for the PURSUER (see the PURSUER block in
## GameState.gd). Answers the three questions the feature has to survive.
##
## 1. DOES IT REWARD RISK, or is it just a timer? A safe bot must get caught
##    and a risky bot must stay clear. If both get caught, or neither does,
##    the pursuer is not reading the player's behaviour at all -- it is a
##    countdown with extra steps.
##
## 2. IS IT SURVIVABLE WHEN THE TRACK GIVES YOU NOTHING? The pursuer feeds
##    on risk events, and risk events need obstacles to be taken against. A
##    stretch of track offering none must not be a death sentence. The
##    HOSTILE phase measures the exact floor by running a bot that takes
##    literally zero risk events, which is the true worst case -- worse than
##    any real player, since the SAFE bot still gets a few forced on it.
##
## 3. WHAT HAPPENS AT THE WORST PILE-UP THE GAME CAN PRODUCE -- pursuer
##    visible, a CHARGER inbound and a rush window open, all at once. Phase
##    CROSS watches for that coincidence over a long run and reports what
##    the player is actually left with when it happens.
##
## The bots are lifted from ComboAudit.gd (same SAFE and RISKY logic, same
## constants, same reasoning) rather than reinvented -- the comparison is
## only meaningful if "safe" and "risky" mean here exactly what they meant
## when the combo system was measured. Duplicated rather than shared for the
## same reason RushFrustrationAudit duplicates AntiFrustrationAudit's check:
## each probe reads standalone, and a shared-helper edit can never quietly
## change what the OTHER one verifies.
##
## Collision is REAL in every phase. A pursuer probe with collision neutered
## would be measuring a bot that can only ever die one way, which is exactly
## the comparison it is supposed to be making.
##
## Excluded from the web export (export_presets.cfg excludes scripts/dev/*),
## never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/PursuerAudit.tscn -- --seed=20260806

const PHASE_SECONDS: float = 300.0
const MAX_RUN_S: float = 200.0

# --- bots (lifted verbatim from ComboAudit.gd) ----------------------
const SAFE_ESCAPE_LEAD_S: float = 1.2
const RISKY_LATE_ESCAPE_S: float = 0.40
const RISKY_GRAZE_TARGET_M: float = (Obstacle.RISK_MIN_SURVIVABLE_LATERAL_M + Obstacle.NEAR_MISS_MAX_LATERAL_M) * 0.5
const GLAND_CHASE_SAFE_LEAD_S: float = 1.5
const HALF_AIR_TIME_S: float = Keepy.JUMP_VELOCITY / Keepy.GRAVITY

enum Phase { SAFE, RISKY, HOSTILE, CROSS }

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _phase: Phase = Phase.SAFE
var _alternate_escape: bool = false

var _phase_t: float = 0.0
var _run_t: float = 0.0
var _runs: int = 0

var _caught_by_pursuer: int = 0
var _died_by_collision: int = 0
var _lead_sum: float = 0.0
var _lead_min: float = INF
var _visible_time: float = 0.0
var _survival_sum: float = 0.0
var _risk_events: int = 0

var _results: Dictionary = {}

# CROSS phase bookkeeping.
var _cross_hits: int = 0
var _cross_min_lead: float = INF
var _cross_worst_escapes: int = 99
var _cross_examples: Array = []

func _ready() -> void:
	var seeded := DevSeed.apply()
	print("=== PURSUER AUDIT ===")
	print("rng               : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("start lead        : %.1fs   ceiling %.1fs   visible under %.1fs" % [
		GameState.PURSUER_START_LEAD_S, GameState.PURSUER_MAX_LEAD_S, GameState.PURSUER_VISIBLE_LEAD_S])
	print("drain             : %.2f lead-s per second of no risk (grace %.1fs)" % [
		GameState.PURSUER_CLOSE_RATE, GameState.PURSUER_GRACE_S])
	print("reward            : +%.1f lead-s per risk event" % GameState.PURSUER_RISK_REWARD_S)
	print("predicted floor   : %.1fs with zero risk events (start / drain + grace)" % (
		GameState.PURSUER_START_LEAD_S / GameState.PURSUER_CLOSE_RATE + GameState.PURSUER_GRACE_S))
	print("")
	_start_phase(Phase.SAFE)

func _start_phase(phase: Phase) -> void:
	if DevSeed.seed_value() != 0:
		seed(DevSeed.seed_value())
	_phase = phase
	_phase_t = 0.0
	_runs = 0
	_caught_by_pursuer = 0
	_died_by_collision = 0
	_lead_sum = 0.0
	_lead_min = INF
	_visible_time = 0.0
	_survival_sum = 0.0
	_risk_events = 0
	print("--- phase %s ---" % _phase_name(phase))
	_start_run()

func _phase_name(phase: Phase) -> String:
	match phase:
		Phase.SAFE: return "SAFE bot"
		Phase.RISKY: return "RISKY bot"
		Phase.HOSTILE: return "HOSTILE (bot takes zero risk events -- the floor)"
		_: return "CROSS (pursuer + charger + rush pile-up)"

func _start_run() -> void:
	if _game:
		_game.process_mode = Node.PROCESS_MODE_DISABLED
		_game.queue_free()
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	if _phase == Phase.HOSTILE:
		# The floor measurement must not be cut short by an unrelated
		# collision: what is being measured is how long the LEAD lasts with
		# no risk taken, not how long a motionless bot avoids obstacles.
		_keepy.collision_layer = 0
	_run_t = 0.0

func _physics_process(delta: float) -> void:
	if GameState.state == GameState.State.PLAYING and _run_t < MAX_RUN_S:
		_run_t += delta
		_phase_t += delta
		_drive_bot()
		_sample(delta)
		return
	_end_run()

func _drive_bot() -> void:
	match _phase:
		Phase.SAFE:
			_drive_safe_bot()
		Phase.RISKY:
			_drive_risky_bot()
		Phase.CROSS:
			# THE SAFE BOT, not the risky one, and that is a finding rather
			# than a preference. The first run of this probe used the risky
			# bot here and observed the pile-up ZERO times in 300s -- because
			# a bot banking 17.6 risk events a minute never lets its lead
			# fall under 9.95s, and the pursuer only becomes visible under
			# 5.0s. The conjunction this phase exists to measure is
			# unreachable for that bot by construction. The safe bot spends
			# ~39% of its time with the pursuer on screen, so it is the only
			# one that can actually put all three together.
			_drive_safe_bot()
		Phase.HOSTILE:
			pass # deliberately motionless -- see _phase_name

func _sample(delta: float) -> void:
	_lead_sum += GameState.pursuer_lead_s * delta
	_lead_min = minf(_lead_min, GameState.pursuer_lead_s)
	if GameState.pursuer_visible:
		_visible_time += delta
	if _phase == Phase.CROSS:
		_sample_cross()

## The worst pile-up the game can produce: the pursuer already on screen, a
## CHARGER inbound (the only hazard that closes faster than the world), and
## a rush window open (peak obstacle density) -- all at the same instant.
func _sample_cross() -> void:
	if not GameState.pursuer_visible:
		return
	if not _track.is_rush_active():
		return
	var charger_ttc := _nearest_charger_ttc()
	if charger_ttc < 0.0:
		return
	_cross_hits += 1
	_cross_min_lead = minf(_cross_min_lead, GameState.pursuer_lead_s)
	# How many lanes are actually free at this instant -- the real question
	# is whether the pile-up ever leaves the player with nowhere to go.
	var escapes := _free_lane_count()
	_cross_worst_escapes = mini(_cross_worst_escapes, escapes)
	if _cross_examples.size() < 5:
		_cross_examples.append("t=%.1fs lead=%.2fs charger_ttc=%.2fs free_lanes=%d" % [
			_run_t, GameState.pursuer_lead_s, charger_ttc, escapes])

func _nearest_charger_ttc() -> float:
	var best := -1.0
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null or obstacle.obstacle_type != Obstacle.Type.CHARGER:
			continue
		var ttc: float = obstacle.time_to_contact_s()
		if ttc <= 0.0:
			continue
		if best < 0.0 or ttc < best:
			best = ttc
	return best

## Lanes with no imminent ground threat, using the same
## Obstacle.ENEMY_REACTION_WINDOW_S notion of "imminent" the two
## frustration audits use, so this number means the same thing they mean.
func _free_lane_count() -> int:
	var blocked := [false, false, false]
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		var ttc: float = obstacle.time_to_contact_s()
		if ttc <= 0.0 or ttc > Obstacle.ENEMY_REACTION_WINDOW_S:
			continue
		var lane := _lane_index_for_x(obstacle.position.x)
		if lane != -1:
			blocked[lane] = true
	var free := 0
	for b in blocked:
		if not b:
			free += 1
	return free

func _end_run() -> void:
	_runs += 1
	_survival_sum += _run_t
	_risk_events += GameState.risk_event_counts[0] + GameState.risk_event_counts[1] \
		+ GameState.risk_event_counts[2] + GameState.risk_event_counts[3]
	if GameState.death_cause == GameState.DeathCause.PURSUER:
		_caught_by_pursuer += 1
	elif GameState.state == GameState.State.GAME_OVER:
		_died_by_collision += 1
	if _phase == Phase.HOSTILE:
		# One run is the whole measurement here: the floor is a property of
		# the constants, not something to average over noise.
		_finish_phase()
		return
	if _phase_t < PHASE_SECONDS:
		_start_run()
		return
	_finish_phase()

func _finish_phase() -> void:
	var r := {
		"runs": _runs,
		"mean_survival": _survival_sum / float(maxi(_runs, 1)),
		"caught": _caught_by_pursuer,
		"collided": _died_by_collision,
		"mean_lead": _lead_sum / maxf(_phase_t, 0.001),
		"min_lead": _lead_min,
		"visible_frac": _visible_time / maxf(_phase_t, 0.001),
		"risk_events": _risk_events,
		"events_per_min": float(_risk_events) * 60.0 / maxf(_phase_t, 0.001),
	}
	_print_phase(_phase_name(_phase), r)
	_results[_phase] = r
	match _phase:
		Phase.SAFE: _start_phase(Phase.RISKY)
		Phase.RISKY: _start_phase(Phase.HOSTILE)
		Phase.HOSTILE: _start_phase(Phase.CROSS)
		_: _report()

func _print_phase(label: String, r: Dictionary) -> void:
	print("  %s" % label)
	print("    runs                   : %d, mean survival %.1fs" % [r["runs"], r["mean_survival"]])
	print("    deaths by PURSUER      : %d" % r["caught"])
	print("    deaths by COLLISION    : %d" % r["collided"])
	print("    mean lead (time-wtd)   : %.2fs" % r["mean_lead"])
	print("    minimum lead reached   : %.2fs" % r["min_lead"])
	print("    time pursuer visible   : %.1f%%" % (r["visible_frac"] * 100.0))
	print("    risk events            : %d = %.1f/min" % [r["risk_events"], r["events_per_min"]])
	print("")

func _report() -> void:
	var safe: Dictionary = _results[Phase.SAFE]
	var risky: Dictionary = _results[Phase.RISKY]
	var hostile: Dictionary = _results[Phase.HOSTILE]

	print("=== SAFE vs RISKY ===")
	print("  risk events/min        : safe %.1f    risky %.1f" % [safe["events_per_min"], risky["events_per_min"]])
	print("  mean lead              : safe %.2fs   risky %.2fs" % [safe["mean_lead"], risky["mean_lead"]])
	print("  minimum lead           : safe %.2fs   risky %.2fs" % [safe["min_lead"], risky["min_lead"]])
	print("  time pursuer visible   : safe %.1f%%   risky %.1f%%" % [
		safe["visible_frac"] * 100.0, risky["visible_frac"] * 100.0])
	print("  caught by pursuer      : safe %d      risky %d" % [safe["caught"], risky["caught"]])
	print("  mean survival          : safe %.1fs   risky %.1fs" % [safe["mean_survival"], risky["mean_survival"]])
	print("")
	print("=== HOSTILE FLOOR (zero risk events available) ===")
	print("  survived               : %.1fs before being caught" % hostile["mean_survival"])
	print("  risk events banked     : %d (must be 0 for this to be the true floor)" % hostile["risk_events"])
	print("")
	print("=== CROSS: pursuer visible + charger inbound + rush active ===")
	print("  (driven by the SAFE bot -- the risky bot never lets the pursuer")
	print("   become visible at all, so it cannot produce this conjunction)")
	print("  coincidences observed  : %d frames" % _cross_hits)
	if _cross_hits > 0:
		print("  lowest lead at one     : %.2fs" % _cross_min_lead)
		print("  fewest free lanes      : %d (0 would mean nowhere to go)" % _cross_worst_escapes)
		for e in _cross_examples:
			print("    e.g. %s" % e)
	else:
		print("  never observed in this run -- reported as not-measured, not as safe")
	print("")

	# --- pass criteria -----------------------------------------------
	if safe["caught"] == 0:
		push_error("PURSUER AUDIT FAILED: the SAFE bot was never caught (%d runs, min lead %.2fs) -- the pursuer is not punishing passive play, so it changes nothing." % [safe["runs"], safe["min_lead"]])
		get_tree().quit(1)
		return
	if risky["caught"] > 0:
		push_error("PURSUER AUDIT FAILED: the RISKY bot was caught %d time(s) -- taking risks is supposed to be the answer to this threat, and here it was not enough." % risky["caught"])
		get_tree().quit(1)
		return
	if risky["mean_lead"] <= safe["mean_lead"]:
		push_error("PURSUER AUDIT FAILED: risky mean lead %.2fs is not above safe %.2fs -- the lead is not tracking how the player plays." % [risky["mean_lead"], safe["mean_lead"]])
		get_tree().quit(1)
		return
	if hostile["risk_events"] != 0:
		push_error("PURSUER AUDIT FAILED: the HOSTILE bot banked %d risk event(s), so its survival time is not the zero-risk floor it is reported as." % hostile["risk_events"])
		get_tree().quit(1)
		return
	# The floor must comfortably exceed the longest stretch the track can go
	# without offering anything to take a risk against. A calm window is
	# 2-3s (TrackManager.CALM_DURATION_MIN_S..MAX_S); anything near that
	# order would make a hostile stretch lethal on its own.
	if hostile["mean_survival"] < 30.0:
		push_error("PURSUER AUDIT FAILED: with zero risk available the player survives only %.1fs -- too tight against the track's own quiet stretches." % hostile["mean_survival"])
		get_tree().quit(1)
		return
	if _cross_hits > 0 and _cross_worst_escapes <= 0:
		push_error("PURSUER AUDIT FAILED: the pursuer+charger+rush pile-up left 0 free lanes at least once -- a pre-existing escape guarantee has been broken.")
		get_tree().quit(1)
		return
	print("PASSED: safe play gets caught, risky play never does, and the zero-risk")
	print("        floor is %.0fs." % hostile["mean_survival"])
	if _cross_hits > 0:
		print("        Worst observed pile-up still left %d lane(s) free (%d frames seen)." % [
			_cross_worst_escapes, _cross_hits])
	else:
		print("        PILE-UP NOT OBSERVED in this run -- that criterion is untested here,")
		print("        not satisfied. Re-run on another seed to sample it.")
	get_tree().quit(0)

# ---------------------------------------------------------------------
# BOTS -- lifted from ComboAudit.gd, see the class doc.
# ---------------------------------------------------------------------

func _drive_safe_bot() -> void:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var own: float = lane_ttc[_keepy.lane_index]
	if own < 0.0 or own > SAFE_ESCAPE_LEAD_S:
		return
	var best_step := 0
	var best_ttc := own
	for step in [-1, 1]:
		var lane: int = _keepy.lane_index + step
		if lane < 0 or lane > 2:
			continue
		var ttc: float = lane_ttc[lane] if lane_ttc[lane] >= 0.0 else INF
		if ttc > best_ttc:
			best_ttc = ttc
			best_step = step
	if best_step != 0:
		_keepy.move_lane(best_step)

func _drive_risky_bot() -> void:
	var threat := _nearest_obstacle_on_lane(_keepy.lane_index)
	if threat != null:
		var ttc: float = threat.time_to_contact_s()
		if not Obstacle.blocks_jump(threat.obstacle_type):
			if ttc <= HALF_AIR_TIME_S and ttc > 0.0 and _keepy.is_on_floor():
				_keepy.velocity.y = Keepy.JUMP_VELOCITY
			return
		var target: float = _graze_escape_ttc(threat) if _alternate_escape else RISKY_LATE_ESCAPE_S
		if ttc <= target and ttc > 0.0:
			_alternate_escape = not _alternate_escape
			_keepy.move_lane(_safest_adjacent_step())
		return
	var gland_lane := _reachable_gland_lane()
	if gland_lane == -1:
		return
	if gland_lane != _keepy.lane_index:
		_keepy.move_lane(signi(gland_lane - _keepy.lane_index))
		return
	if _keepy.is_on_floor() and _gland_ttc_on_lane(gland_lane) <= HALF_AIR_TIME_S:
		_keepy.velocity.y = Keepy.JUMP_VELOCITY

func _graze_escape_ttc(hazard: Obstacle) -> float:
	var window_open_s: float = Obstacle.RISK_PROXIMITY_Z / maxf(hazard.closing_speed(), 0.001)
	var pitch: float = TrackSegment.LANE_X[1] - TrackSegment.LANE_X[0]
	var fraction: float = clampf(RISKY_GRAZE_TARGET_M / pitch, 0.0, 0.99)
	var lerp_s: float = -log(1.0 - fraction) / Keepy.LANE_SWITCH_SPEED
	return window_open_s + lerp_s

func _safest_adjacent_step() -> int:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var best_step := 1 if _keepy.lane_index == 0 else -1
	var best_ttc := -INF
	for step in [-1, 1]:
		var lane: int = _keepy.lane_index + step
		if lane < 0 or lane > 2:
			continue
		var ttc: float = lane_ttc[lane] if lane_ttc[lane] >= 0.0 else INF
		if ttc > best_ttc:
			best_ttc = ttc
			best_step = step
	return best_step

var _lane_ttc_scratch: Array[float] = [-1.0, -1.0, -1.0]

func _nearest_hazard_ttc_per_lane() -> Array[float]:
	for lane in 3:
		_lane_ttc_scratch[lane] = -1.0
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		var ttc: float = obstacle.time_to_contact_s()
		if ttc <= 0.0:
			continue
		var lane := _lane_index_for_x(obstacle.position.x)
		if lane == -1:
			continue
		if _lane_ttc_scratch[lane] < 0.0 or ttc < _lane_ttc_scratch[lane]:
			_lane_ttc_scratch[lane] = ttc
	return _lane_ttc_scratch

func _nearest_obstacle_on_lane(lane: int) -> Obstacle:
	var best: Obstacle = null
	var best_ttc := INF
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		if _lane_index_for_x(obstacle.position.x) != lane:
			continue
		var ttc: float = obstacle.time_to_contact_s()
		if ttc <= 0.0 or ttc >= best_ttc:
			continue
		best_ttc = ttc
		best = obstacle
	return best

func _reachable_gland_lane() -> int:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var best_lane := -1
	var best_z := -INF
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		for lane in 3:
			if lane_ttc[lane] >= 0.0 and lane_ttc[lane] < GLAND_CHASE_SAFE_LEAD_S:
				continue
			var z: float = segment.active_gland_z_on_lane(lane)
			if z == INF or z >= 0.0:
				continue
			if z > best_z:
				best_z = z
				best_lane = lane
	return best_lane

func _gland_ttc_on_lane(lane: int) -> float:
	var best := INF
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var z: float = segment.active_gland_z_on_lane(lane)
		if z == INF or z >= 0.0:
			continue
		best = minf(best, -z / GameState.current_speed)
	return best

func _active_obstacle_in(segment: TrackSegment) -> Obstacle:
	for child in segment.get_children():
		if child is Obstacle and child.visible:
			return child
	return null

func _lane_index_for_x(x: float) -> int:
	for lane in TrackSegment.LANE_X.size():
		if absf(x - TrackSegment.LANE_X[lane]) < 0.01:
			return lane
	return -1
