extends Node
## Dev-only diagnostic for the temporary track shrink (see GameState's
## TRACK SHRINK section for the mechanic itself).
##
## AntiFrustrationAudit already proves the FAIRNESS half -- that an
## escape still exists while a lane is shut. This probe answers the two
## questions that one cannot:
##
##   PHASE 1, REACHABILITY -- does a bot ever actually SCORE 3000? The
##   mechanic does not exist below SHRINK_UNLOCK_SCORE, so if no
##   realistic profile gets there, every green in this directory is
##   vacuous with respect to it: the code would be verified and the
##   feature would never once have run. This phase drives the three real
##   bot profiles (SAFE / INTERMEDIATE / RISKY, lifted from ComboAudit
##   and PursuerAudit as every probe here lifts them) with collision AND
##   the pursuer LEFT ON -- i.e. real play, real deaths -- and reports
##   the best score each one reaches against the gate. It deliberately
##   does NOT lower the gate: lowering it here would answer a different
##   question than the one asked.
##
##   PHASE 2, BEHAVIOUR -- how often does a window actually open once
##   unlocked, how long does it last, and do the two invariants the
##   mechanic rests on hold every frame? Those are:
##     - the condemned lane is NEVER the player's lane at the instant it
##       is chosen (otherwise the mechanic pushes them out of a lane they
##       chose, without them acting);
##     - the condemned lane is ALWAYS an edge lane (closing the centre
##       would split the track into two halves a +-1 switch cannot
##       cross -- see Keepy.move_lane).
##   It also checks that no CHARGER is ever live during a window, since
##   the STOMPER/CHARGER arbitration suspends exactly that hazard (see
##   TrackManager._try_charger_lane for why it is the charger and not the
##   stomper), and that the player never ends up standing on a shut lane.
##
##   Phase 2 uses the neutered, never-dying roaming bot -- the same one
##   AntiFrustrationAudit uses and for the same reason: this phase
##   measures the SPAWNER's behaviour over many windows, and one
##   continuous run samples far more of them than a bot that keeps
##   dying. It lowers the score gate so those windows start early in the
##   run rather than two minutes into it; that is an override of the
##   SCORE only, and the real trigger path (live-track compatibility
##   gate included) still has to agree before any window opens.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/ShrinkAudit.tscn -- --seed=20260807

# --- phase 1: reachability ------------------------------------------
## Simulated seconds per bot profile, summed across as many runs as it
## takes -- the same phase-then-restart shape PursuerAudit uses. Long
## enough that a profile's BEST run is a real best rather than one lucky
## sample.
const REACH_PHASE_SECONDS: float = 400.0
const MAX_RUN_S: float = 240.0

# --- phase 2: behaviour ---------------------------------------------
const BEHAVIOUR_SECONDS: float = 600.0
const BOT_SWITCH_MIN_INTERVAL_S: float = 0.6
const BOT_SWITCH_MAX_INTERVAL_S: float = 2.4
## Same override, and same reasoning, as
## AntiFrustrationAudit.PROBE_UNLOCK_SCORE.
const PROBE_UNLOCK_SCORE: int = 600

# --- bots (lifted verbatim from ComboAudit.gd / PursuerAudit.gd) -----
const SAFE_ESCAPE_LEAD_S: float = 1.2
const RISKY_LATE_ESCAPE_S: float = 0.40
const RISKY_GRAZE_TARGET_M: float = (Obstacle.RISK_MIN_SURVIVABLE_LATERAL_M + Obstacle.NEAR_MISS_MAX_LATERAL_M) * 0.5
const HALF_AIR_TIME_S: float = Keepy.JUMP_VELOCITY / Keepy.GRAVITY

enum Phase { SAFE, INTERMEDIATE, RISKY, BEHAVIOUR }

## Mechanics each phase must actually have produced. Every hazard type,
## plus the SHRINK this probe is entirely about -- required only of the
## BEHAVIOUR phase, which is the one that lowers the gate so a window
## can fire. Phase 1 measures whether real play REACHES the gate, so
## demanding a window there would be demanding its own answer.
## See ProbeCoverage.gd.
const REQUIRED_HAZARDS: Array[int] = [
	ProbeCoverage.Mechanic.DODGE, ProbeCoverage.Mechanic.JUMP,
	ProbeCoverage.Mechanic.ENEMY, ProbeCoverage.Mechanic.AIR_ENEMY,
	ProbeCoverage.Mechanic.CHARGER, ProbeCoverage.Mechanic.STOMPER,
]
const REQUIRED_BEHAVIOUR: Array[int] = [ProbeCoverage.Mechanic.SHRINK]

var _coverage := ProbeCoverage.new()

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _phase: Phase = Phase.SAFE
var _phase_t: float = 0.0
var _run_t: float = 0.0
var _runs: int = 0
var _alternate_escape: bool = false
var _next_bot_switch_t: float = 0.0

# Phase 1 bookkeeping.
var _best_score: int = 0
var _score_sum: int = 0
var _runs_over_gate: int = 0
var _reach: Dictionary = {}

# Phase 2 bookkeeping.
var _windows: int = 0
var _window_started_t: float = 0.0
var _window_durations: Array[float] = []
var _window_gaps: Array[float] = []
var _last_window_end_t: float = -1.0
var _first_window_score: int = -1
var _was_shrink_active: bool = false
var _condemned_was_player_lane: int = 0
var _condemned_was_centre: int = 0
var _player_on_closed_lane_frames: int = 0
var _charger_during_window_frames: int = 0
var _shrunk_frames: int = 0
var _behaviour_frames: int = 0

func _ready() -> void:
	# Must run BEFORE Game.tscn is instantiated below -- see DevSeed.gd.
	var seeded := DevSeed.apply()
	print("=== SHRINK AUDIT ===")
	print("rng                : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("shipped gate       : score >= %d" % GameState.SHRINK_UNLOCK_SCORE)
	print("window shape       : %.1fs closing + %.1fs held + %.1fs opening = %.1fs unavailable" % [
		GameState.SHRINK_CLOSING_S, GameState.SHRINK_HELD_S, GameState.SHRINK_OPENING_S,
		GameState.SHRINK_CLOSING_S + GameState.SHRINK_HELD_S + GameState.SHRINK_OPENING_S])
	print("interval           : %.0f-%.0fs between windows" % [
		GameState.SHRINK_INTERVAL_MIN_S, GameState.SHRINK_INTERVAL_MAX_S])
	print("")
	print("--- phase 1: REACHABILITY (real play -- collision ON, pursuer ON, shipped gate) ---")
	_start_phase(Phase.SAFE)

func _start_phase(phase: Phase) -> void:
	if DevSeed.seed_value() != 0:
		seed(DevSeed.seed_value())
	_phase = phase
	_phase_t = 0.0
	_runs = 0
	_best_score = 0
	_score_sum = 0
	_runs_over_gate = 0
	if phase == Phase.BEHAVIOUR:
		print("")
		print("--- phase 2: BEHAVIOUR (neutered roaming bot, gate lowered to %d) ---" % PROBE_UNLOCK_SCORE)
		GameState.pursuer_enabled = false
		GameState.shrink_unlock_score = PROBE_UNLOCK_SCORE
	else:
		# Real play: both systems left exactly as shipped, and the gate
		# untouched -- the whole point of this phase.
		GameState.pursuer_enabled = true
		GameState.shrink_unlock_score = GameState.SHRINK_UNLOCK_SCORE
	_coverage.begin_phase(_phase_name(phase))
	_start_run()

func _start_run() -> void:
	if _game:
		_game.process_mode = Node.PROCESS_MODE_DISABLED
		_game.queue_free()
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	_coverage.run_restarted()
	if _phase == Phase.BEHAVIOUR:
		_keepy.collision_layer = 0
		_next_bot_switch_t = _phase_t + randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)
	_run_t = 0.0

func _physics_process(delta: float) -> void:
	if _phase == Phase.BEHAVIOUR:
		_physics_behaviour(delta)
		return
	if GameState.state == GameState.State.PLAYING and _run_t < MAX_RUN_S:
		_run_t += delta
		_phase_t += delta
		_drive_bot()
		_coverage.observe(_track, _keepy)
		return
	_end_reach_run()

# =====================================================================
# PHASE 1 -- REACHABILITY
# =====================================================================

func _drive_bot() -> void:
	match _phase:
		Phase.SAFE:
			_drive_safe_bot()
		Phase.INTERMEDIATE:
			_drive_intermediate_bot()
		_:
			_drive_risky_bot()

func _end_reach_run() -> void:
	_runs += 1
	_best_score = maxi(_best_score, GameState.score)
	_score_sum += GameState.score
	if GameState.score >= GameState.SHRINK_UNLOCK_SCORE:
		_runs_over_gate += 1
	if _phase_t < REACH_PHASE_SECONDS:
		_start_run()
		return
	var over := float(_runs_over_gate) * 100.0 / float(maxi(_runs, 1))
	_reach[_phase] = {"best": _best_score, "mean": _score_sum / maxi(_runs, 1), "runs": _runs, "over": _runs_over_gate, "over_pct": over}
	print("  %-14s runs %2d   best score %6d   mean %5d   runs over gate %d (%.0f%%)" % [
		_phase_name(_phase), _runs, _best_score, _score_sum / maxi(_runs, 1), _runs_over_gate, over])
	match _phase:
		Phase.SAFE: _start_phase(Phase.INTERMEDIATE)
		Phase.INTERMEDIATE: _start_phase(Phase.RISKY)
		_: _start_phase(Phase.BEHAVIOUR)

func _phase_name(phase: Phase) -> String:
	match phase:
		Phase.SAFE: return "SAFE"
		Phase.INTERMEDIATE: return "INTERMEDIATE"
		Phase.RISKY: return "RISKY"
		_: return "BEHAVIOUR"

# =====================================================================
# PHASE 2 -- BEHAVIOUR
# =====================================================================

func _physics_behaviour(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return
	_phase_t += delta
	_behaviour_frames += 1
	_drive_roaming_bot()
	_coverage.observe(_track, _keepy)
	_sample_window()
	if _phase_t >= BEHAVIOUR_SECONDS:
		_report()

## Aimless random lane roaming -- see AntiFrustrationAudit.gd's own doc
## for why this is deliberately NOT reactive/skilled play.
func _drive_roaming_bot() -> void:
	if _phase_t < _next_bot_switch_t:
		return
	_next_bot_switch_t = _phase_t + randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)
	_keepy.move_lane([-1, 1].pick_random())

func _sample_window() -> void:
	var active := GameState.shrink_active()

	if active and not _was_shrink_active:
		# The frame a window OPENS -- the only frame on which "was the
		# condemned lane the player's own" is a meaningful question, since
		# the player is free to move afterwards.
		_windows += 1
		_window_started_t = _phase_t
		if _first_window_score < 0:
			_first_window_score = GameState.score
		if _last_window_end_t >= 0.0:
			_window_gaps.append(_phase_t - _last_window_end_t)
		if GameState.shrink_lane == _keepy.lane_index:
			_condemned_was_player_lane += 1
		if GameState.shrink_lane == 1:
			_condemned_was_centre += 1
	elif not active and _was_shrink_active:
		_window_durations.append(_phase_t - _window_started_t)
		_last_window_end_t = _phase_t

	if active:
		_shrunk_frames += 1
		if GameState.lane_blocked(_keepy.lane_index):
			_player_on_closed_lane_frames += 1
		if _charger_live():
			_charger_during_window_frames += 1

	_was_shrink_active = active

func _charger_live() -> bool:
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle != null and obstacle.obstacle_type == Obstacle.Type.CHARGER:
			return true
	return false

## The SHRINK requirement, scoped to the BEHAVIOUR phase only -- see
## REQUIRED_BEHAVIOUR for why the reachability phases are exempt.
func _behaviour_coverage_gaps() -> Array[String]:
	var out: Array[String] = []
	var label := _phase_name(Phase.BEHAVIOUR)
	if _coverage.count(label, ProbeCoverage.Mechanic.SHRINK) < 1:
		out.append("%s never met SHRINK -- the mechanic this probe exists for did not run" % label)
	return out

func _report() -> void:
	print("simulated time             : %.1fs" % _phase_t)
	print("windows opened             : %d" % _windows)
	print("score at first window      : %d" % _first_window_score)
	print("mean window duration       : %.2fs (nominal %.2fs)" % [
		_mean(_window_durations),
		GameState.SHRINK_CLOSING_S + GameState.SHRINK_HELD_S + GameState.SHRINK_OPENING_S])
	print("min / max window duration  : %.2fs / %.2fs" % [_min(_window_durations), _max(_window_durations)])
	print("mean gap between windows   : %.1fs (interval knob %.0f-%.0fs)" % [
		_mean(_window_gaps), GameState.SHRINK_INTERVAL_MIN_S, GameState.SHRINK_INTERVAL_MAX_S])
	print("time spent shrunk          : %.1f%% of the run" % (
		float(_shrunk_frames) * 100.0 / float(maxi(_behaviour_frames, 1))))
	print("--- invariants (all must be 0) ---")
	print("condemned lane == player's : %d" % _condemned_was_player_lane)
	print("condemned lane == centre   : %d" % _condemned_was_centre)
	print("player on a closed lane    : %d frames" % _player_on_closed_lane_frames)
	print("charger live during window : %d frames" % _charger_during_window_frames)
	print("")

	var failed := _condemned_was_player_lane > 0 or _condemned_was_centre > 0 \
		or _player_on_closed_lane_frames > 0 or _charger_during_window_frames > 0
	# COVERAGE FIRST -- see ProbeCoverage.gd. The hazard requirement is held
	# against every phase; the SHRINK requirement only against BEHAVIOUR,
	# which is the phase that lowers the gate so a window can fire at all.
	_coverage.report(REQUIRED_HAZARDS + REQUIRED_BEHAVIOUR)
	var gaps := _coverage.verify(REQUIRED_HAZARDS)
	gaps.append_array(_behaviour_coverage_gaps())
	if not gaps.is_empty():
		for gap in gaps:
			push_error("SHRINK AUDIT INCONCLUSIVE: %s." % gap)
		get_tree().quit(1)
		return
	if _windows == 0:
		push_error("SHRINK AUDIT INCONCLUSIVE: no window ever opened, so nothing below phase 1 was measured.")
		get_tree().quit(1)
		return
	if failed:
		push_error("SHRINK AUDIT FAILED: player-lane %d, centre-lane %d, player-on-closed %d frames, charger-during-window %d frames." % [
			_condemned_was_player_lane, _condemned_was_centre,
			_player_on_closed_lane_frames, _charger_during_window_frames])
		get_tree().quit(1)
		return

	# Phase 1's verdict is reported, never enforced. Whether a bot clears
	# the shipped gate is a fact about the DIFFICULTY CURVE, not a
	# regression -- a profile that stops reaching 3000 after some future
	# balance change is something a reader must SEE, but failing the
	# build on it would make this probe fight every legitimate tuning
	# pass. The hard failures above are the ones that are genuinely
	# always-wrong.
	var any_reach := false
	print("--- phase 1 verdict: can a real bot reach the shipped gate of %d? ---" % GameState.SHRINK_UNLOCK_SCORE)
	for phase in [Phase.SAFE, Phase.INTERMEDIATE, Phase.RISKY]:
		if not _reach.has(phase):
			continue
		var r: Dictionary = _reach[phase]
		var reached: bool = r["best"] >= GameState.SHRINK_UNLOCK_SCORE
		any_reach = any_reach or reached
		print("  %-14s best %6d  -> %s" % [_phase_name(phase), r["best"], "REACHES the gate" if reached else "never reaches it"])
	if not any_reach:
		print("  WARNING: no profile reached the gate in real play. The mechanic is")
		print("  correct (phase 2 exercised %d windows) but would never be MET." % _windows)
	print("")
	print("PASSED: %d windows, mean %.2fs, never the player's lane, never the centre," % [_windows, _mean(_window_durations)])
	print("        never a live charger, player never stood on a shut lane.")
	get_tree().quit(0)

func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / float(values.size())

func _min(values: Array[float]) -> float:
	var best := INF
	for v in values:
		best = minf(best, v)
	return 0.0 if is_inf(best) else best

func _max(values: Array[float]) -> float:
	var best := -INF
	for v in values:
		best = maxf(best, v)
	return 0.0 if is_inf(best) else best

# =====================================================================
# BOTS + TRACK QUERIES -- lifted verbatim from ComboAudit.gd, same as
# every other probe in this directory does. Duplicated rather than
# shared so this file reads standalone and a shared-helper edit can
# never quietly change what it measures.
# =====================================================================

func _drive_safe_bot() -> void:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var own: float = lane_ttc[_keepy.lane_index]
	if own < 0.0 or own > SAFE_ESCAPE_LEAD_S:
		return
	# STOMPER: no lane switch ever escapes it (Obstacle.blocks_lane_switch),
	# so the only answer is a jump. The INTERMEDIATE and RISKY bots below
	# already have this for free -- they jump anything blocks_jump does not
	# exclude, and STOMPER is not excluded -- but this one never jumps at
	# all, so it needed saying explicitly.
	#
	# WITHOUT IT THIS PHASE'S HEADLINE WAS AN ARTIFACT. Phase 1 asks whether
	# a realistic profile ever reaches the 3000 gate, and reported that SAFE
	# never does: 15 runs, best score 750. The coverage ledger then showed
	# SAFE meeting a STOMPER on its own lane in 15 of those 15 runs -- it was
	# not failing to reach the gate, it was being killed by the first STOMPER
	# of every single run. Same defect as ComboAudit's SAFE bot, found the
	# same day, and the reason ProbeCoverage.gd exists.
	var own_obstacle := _nearest_obstacle_on_lane(_keepy.lane_index)
	if own_obstacle != null and Obstacle.blocks_lane_switch(own_obstacle.obstacle_type):
		if own <= HALF_AIR_TIME_S and _keepy.is_on_floor():
			_keepy.velocity.y = Keepy.JUMP_VELOCITY
		return
	var best_step := 0
	var best_ttc := own
	for step in [-1, 1]:
		var lane: int = _keepy.lane_index + step
		if lane < 0 or lane > 2:
			continue
		# A lane shut by a shrink window is not a destination -- without
		# this the bot would keep choosing it (it is empty, so its ttc is
		# the best on the board), have the move refused by
		# Keepy.move_lane, and stand still in front of the hazard. That
		# would understate what these profiles can score for a reason
		# that has nothing to do with the difficulty curve.
		if GameState.lane_blocked(lane):
			continue
		var ttc: float = lane_ttc[lane] if lane_ttc[lane] >= 0.0 else INF
		if ttc > best_ttc:
			best_ttc = ttc
			best_step = step
	if best_step != 0:
		_keepy.move_lane(best_step)

## Mid-skill: reacts to what is on its lane but never hunts risk. Same
## shape as PursuerAudit's own INTERMEDIATE bot -- jump what is jumpable,
## step around what is not, and never chase a gland.
func _drive_intermediate_bot() -> void:
	var threat := _nearest_obstacle_on_lane(_keepy.lane_index)
	if threat == null:
		return
	var ttc: float = threat.time_to_contact_s()
	if not Obstacle.blocks_jump(threat.obstacle_type):
		if ttc <= HALF_AIR_TIME_S and ttc > 0.0 and _keepy.is_on_floor():
			_keepy.velocity.y = Keepy.JUMP_VELOCITY
		return
	if ttc <= SAFE_ESCAPE_LEAD_S and ttc > 0.0:
		_keepy.move_lane(_safest_adjacent_step())

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

## Never returns 0: the caller has already decided it must move. Closed
## lanes are skipped for the same reason as in _drive_safe_bot; only if
## BOTH neighbours are unusable does it fall back to a step that
## move_lane will refuse, which cannot happen while only an edge lane is
## ever condemned.
func _safest_adjacent_step() -> int:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var best_step := 1 if _keepy.lane_index == 0 else -1
	var best_ttc := -INF
	for step in [-1, 1]:
		var lane: int = _keepy.lane_index + step
		if lane < 0 or lane > 2:
			continue
		if GameState.lane_blocked(lane):
			continue
		var ttc: float = lane_ttc[lane] if lane_ttc[lane] >= 0.0 else INF
		if ttc > best_ttc:
			best_ttc = ttc
			best_step = step
	return best_step

## Reused across frames rather than re-allocated on every call -- a probe
## must not be the thing that introduces per-frame garbage into a run it
## is measuring.
var _lane_ttc_buf: Array[float] = [-1.0, -1.0, -1.0]

func _nearest_hazard_ttc_per_lane() -> Array[float]:
	_lane_ttc_buf[0] = -1.0
	_lane_ttc_buf[1] = -1.0
	_lane_ttc_buf[2] = -1.0
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		var lane := _lane_index_for_x(obstacle.position.x)
		if lane == -1:
			continue
		var ttc: float = obstacle.time_to_contact_s()
		if ttc <= 0.0:
			continue
		if _lane_ttc_buf[lane] < 0.0 or ttc < _lane_ttc_buf[lane]:
			_lane_ttc_buf[lane] = ttc
	return _lane_ttc_buf

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
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		for lane in TrackSegment.LANE_X.size():
			if GameState.lane_blocked(lane):
				continue
			if not is_inf(segment.active_gland_z_on_lane(lane)):
				return lane
	return -1

func _gland_ttc_on_lane(lane: int) -> float:
	var best := INF
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var z: float = segment.active_gland_z_on_lane(lane)
		if is_inf(z):
			continue
		var ttc := -z / maxf(GameState.current_speed, 0.001)
		if ttc > 0.0:
			best = minf(best, ttc)
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
