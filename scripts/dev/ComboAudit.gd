extends Node
## Dev-only diagnostic for the RISK/COMBO system (combo batch, playtest:
## "je trouve le jeu globalement trop facile" -- diagnosed as "rien ne
## m'incite a prendre des risques", see GameState.RiskEvent and the COMBO
## tuning block).
##
## THE QUESTION THIS EXISTS TO ANSWER, and the only one it can settle: does
## playing RISKY actually pay meaningfully better than playing SAFE? If it
## does not, the whole batch is decoration -- a counter that goes up while
## changing nobody's incentives. Reasoning about the multiplier arithmetic
## on paper cannot answer it, because how OFTEN each risk kind is reachable
## on real track is an empirical property of the spawner, not of the
## formula.
##
## METHOD -- two bots, each played over the same total simulated budget on
## the same seeded track:
##   SAFE  -- reads every hazard early and gives it the widest berth
##            available. Never jumps (so never takes a gland, which sits at
##            jump apex by construction). This is the "I can survive
##            forever by playing boring" strategy the playtest complained
##            about, played deliberately well.
##   RISKY -- seeks risk on purpose: jumps jumpable hazards on its own lane
##            with real timing, goes out of its way for glands, and vacates
##            a lane an unjumpable hazard owns only at the last moment.
##
## COLLISION IS REAL FOR BOTH, and that is not incidental -- an earlier
## draft of this probe neutered Keepy's collision layer (the technique
## AntiFrustrationAudit.gd uses, to hold run length constant) and the
## result was worthless: collectibles are Area3D pickups that detect Keepy
## through that same layer, so BOTH bots collected exactly zero noisettes
## and zero glands, and the multiplier -- which by design applies to
## collectibles and to nothing else (see GameState.add_noisette/add_gland)
## -- had literally nothing to act on. A run where the mechanism under test
## cannot fire measures nothing. So both bots play for real and can die.
##
## WHICH MAKES "final score" THE WRONG HEADLINE NUMBER ON ITS OWN, and it
## is reported with that caveat: a bot that dies more has a lower final
## score for reasons that have nothing to do with the multiplier, since the
## dominant score term is distance, i.e. a pure function of time survived.
## The number that actually isolates this batch is EFFECTIVE MULTIPLIER ON
## COLLECTIBLES -- collectible points earned divided by what those exact
## same pickups would have been worth at x1. That one cannot be moved by
## surviving longer, by collecting more, or by any difference between the
## bots other than the multiplier itself, which is precisely why it is the
## pass criterion.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/ComboAudit.tscn -- --seed=20260806

## Total simulated PLAY time each bot is measured over, accumulated across
## as many runs as it takes (a bot that dies at 20s simply starts another).
## Long enough to span many speed paliers, dark cycles and rush windows, so
## neither bot is judged on one unlucky slice of track.
const PHASE_SECONDS: float = 300.0
## Safety cap on a single run, so a bot that somehow never dies still ends.
const MAX_RUN_S: float = 150.0

## Run time at which each run's score is also recorded, for a MATCHED-
## DURATION comparison between the two bots.
##
## This exists because raw "mean final score" is confounded, and badly:
## score is dominated by distance, distance is a function of time survived,
## and the speed table (GameState.STAGE_SPEEDS) means later seconds are
## worth more than early ones. A bot that survives 150s therefore banks
## more points per second than one that survives 48s, entirely
## independently of anything this batch changed -- comparing the two
## directly would measure the speed ramp, not the reward system. Sampling
## both bots at the SAME run time removes the ramp from the comparison,
## because at t seconds both have travelled through exactly the same
## paliers.
##
## 40s is chosen to be short enough that most runs of BOTH bots reach it
## (so the sample is not silently restricted to the risky bot's luckiest
## runs) while still being long enough to sit past the point where the
## combo, the rush windows and dark mode have all come into play.
const CHECKPOINT_S: float = 40.0

# --- SAFE bot ------------------------------------------------------
## Time-before-contact at which the safe bot commits to an escape. Far
## larger than Obstacle.ENEMY_REACTION_WINDOW_S (~0.35s, the tightest
## escape the game guarantees) precisely because that is what "safe" means:
## act on the first read, never on the last. At 1.2s the lane lerp
## (Keepy.LANE_SWITCH_SPEED = 12, 95% in 0.25s) has settled for a full
## second before the hazard arrives.
const SAFE_ESCAPE_LEAD_S: float = 1.2

# --- RISKY bot -----------------------------------------------------
## Escape timing for the LATE_DODGE half of the risky bot's repertoire:
## late enough to sit inside Obstacle.LATE_DODGE_WINDOW_S, wide enough that
## the lane lerp has carried it clear past the graze band by the time the
## hazard arrives (~1.98m at contact).
const RISKY_LATE_ESCAPE_S: float = 0.40

## Lateral clearance the GRAZE half aims for -- the middle of the near-miss
## band, so a frame of timing slop in either direction still lands inside
## it. The escape TIME that produces this clearance is not a constant and
## cannot be: it is derived per hazard in _graze_escape_ttc() from that
## hazard's own closing speed, because a CHARGER arrives at 2.35x world
## speed and enters the sampling window in well under half the time
## everything else does. The first draft of this probe used a single fixed
## 0.27s for every type and every palier, and the result was a near-miss
## rate of 1 event per 300s -- the timing simply missed the band almost
## everywhere on the speed curve.
const RISKY_GRAZE_TARGET_M: float = (Obstacle.RISK_MIN_SURVIVABLE_LATERAL_M + Obstacle.NEAR_MISS_MAX_LATERAL_M) * 0.5

## Don't chase a gland onto a lane with a hazard due within this long -- a
## risky player is not a suicidal one, and without this the bot walks into
## unjumpable hazards while reaching for a bonus, which measures the bot's
## stupidity rather than the reward system.
const GLAND_CHASE_SAFE_LEAD_S: float = 1.5
## Liftoff happens when time-to-contact equals half of Keepy's total air
## time, which puts the jump's apex exactly on the hazard's arrival -- the
## same technique JumpDodgeRewardAudit.gd and AirHazardAudit.gd both use.
const HALF_AIR_TIME_S: float = Keepy.JUMP_VELOCITY / Keepy.GRAVITY

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _risky: bool = false
var _alternate_escape: bool = false

var _phase_t: float = 0.0 # accumulated across runs within a phase
var _run_t: float = 0.0
var _runs: int = 0

# Time-weighted accumulators for the phase in progress. Plain floats/ints,
# no per-frame allocation.
var _combo_time_sum: float = 0.0
var _multiplier_time_sum: float = 0.0
var _time_above_x1: float = 0.0
var _combo_max: int = 0
var _score_sum: int = 0
## Score sampled at CHECKPOINT_S, and how many runs got that far -- the
## matched-duration comparison, see that constant.
var _checkpoint_score_sum: int = 0
var _checkpoint_runs: int = 0
var _checkpoint_taken: bool = false
var _nuts: int = 0
var _glands: int = 0
var _noisette_points: int = 0
var _gland_points: int = 0
var _events: Array[int] = [0, 0, 0, 0]

var _safe_result: Dictionary = {}
var _risky_result: Dictionary = {}

func _ready() -> void:
	# Must run BEFORE Game.tscn is instantiated -- see DevSeed.gd. Both
	# phases re-seed to this SAME value in _start_phase so the two bots meet
	# the identical spawn stream: without that the comparison would be
	# confounded by two different tracks.
	var seeded := DevSeed.apply()
	print("=== COMBO AUDIT ===")
	print("rng                : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("budget per bot     : %.0fs of real play, across as many runs as it takes" % PHASE_SECONDS)
	print("combo timeout      : %.1fs   tier size: %d   max multiplier: x%d" % [
		GameState.COMBO_TIMEOUT_S, GameState.COMBO_TIER_SIZE, GameState.COMBO_MAX_MULTIPLIER])
	print("near-miss band     : %.2fm .. %.2fm lateral" % [
		Obstacle.RISK_MIN_SURVIVABLE_LATERAL_M, Obstacle.NEAR_MISS_MAX_LATERAL_M])
	print("late-dodge window  : %.3fs before contact" % Obstacle.LATE_DODGE_WINDOW_S)
	print("")
	_start_phase(false)

func _start_phase(risky: bool) -> void:
	if DevSeed.seed_value() != 0:
		seed(DevSeed.seed_value())
	_risky = risky
	_phase_t = 0.0
	_runs = 0
	_combo_time_sum = 0.0
	_multiplier_time_sum = 0.0
	_time_above_x1 = 0.0
	_combo_max = 0
	_score_sum = 0
	_checkpoint_score_sum = 0
	_checkpoint_runs = 0
	_nuts = 0
	_glands = 0
	_noisette_points = 0
	_gland_points = 0
	for i in _events.size():
		_events[i] = 0
	print("--- phase %s: %.0fs of play ---" % ["RISKY" if risky else "SAFE", PHASE_SECONDS])
	_start_run()

func _start_run() -> void:
	if _game:
		# Disabled BEFORE freeing: a queued-but-not-yet-freed Game keeps
		# ticking its obstacles for the rest of the frame, and they read
		# global_position on a node already on its way out of the tree.
		_game.process_mode = Node.PROCESS_MODE_DISABLED
		_game.queue_free()
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	_run_t = 0.0
	_checkpoint_taken = false

func _physics_process(delta: float) -> void:
	if GameState.state == GameState.State.PLAYING and _run_t < MAX_RUN_S:
		_run_t += delta
		_phase_t += delta
		if _risky:
			_drive_risky_bot()
		else:
			_drive_safe_bot()
		_sample(delta)
		if not _checkpoint_taken and _run_t >= CHECKPOINT_S:
			_checkpoint_taken = true
			_checkpoint_score_sum += GameState.score
			_checkpoint_runs += 1
		return
	_end_run()

## Time-weighted, not per-event: "how much of the run was spent at a
## multiplier" is the honest way to state what a combo system is worth,
## since a chain held for 30s and a chain held for 1s are not the same thing
## even though both are one chain.
func _sample(delta: float) -> void:
	_combo_time_sum += float(GameState.combo_count) * delta
	_multiplier_time_sum += float(GameState.combo_multiplier) * delta
	if GameState.combo_multiplier > 1:
		_time_above_x1 += delta
	_combo_max = maxi(_combo_max, GameState.combo_count)

func _end_run() -> void:
	_runs += 1
	_score_sum += GameState.score
	_nuts += GameState.nut_count
	_glands += GameState.gland_count
	_noisette_points += GameState.noisette_score
	_gland_points += GameState.gland_score
	for i in _events.size():
		_events[i] += GameState.risk_event_counts[i]
	if _phase_t < PHASE_SECONDS:
		_start_run()
		return
	_finish_phase()

func _finish_phase() -> void:
	var total_events: int = _events[0] + _events[1] + _events[2] + _events[3]
	var collectible_points: int = _noisette_points + _gland_points
	# What those exact same pickups would have been worth with no combo at
	# all -- the denominator that turns "earned more" into "earned more PER
	# PICKUP", which is the only form of the question the multiplier alone
	# can answer.
	var base_points: int = _nuts * GameState.NOISETTE_VALUE + _glands * GameState.GLAND_VALUE
	var result := {
		"runs": _runs,
		"play_time": _phase_t,
		"mean_survival": _phase_t / float(maxi(_runs, 1)),
		"mean_score": _score_sum / maxi(_runs, 1),
		"checkpoint_runs": _checkpoint_runs,
		"checkpoint_score": _checkpoint_score_sum / maxi(_checkpoint_runs, 1),
		"score_per_min": float(_score_sum) * 60.0 / maxf(_phase_t, 0.001),
		"nuts": _nuts,
		"glands": _glands,
		"collectible_points": collectible_points,
		"base_points": base_points,
		"effective_multiplier": float(collectible_points) / maxf(float(base_points), 1.0),
		"collectible_points_per_min": float(collectible_points) * 60.0 / maxf(_phase_t, 0.001),
		"combo_mean": _combo_time_sum / maxf(_phase_t, 0.001),
		"combo_max": _combo_max,
		"multiplier_mean": _multiplier_time_sum / maxf(_phase_t, 0.001),
		"time_above_x1_frac": _time_above_x1 / maxf(_phase_t, 0.001),
		"jump_dodges": _events[GameState.RiskEvent.JUMP_DODGE],
		"near_misses": _events[GameState.RiskEvent.NEAR_MISS],
		"late_dodges": _events[GameState.RiskEvent.LATE_DODGE],
		"gland_events": _events[GameState.RiskEvent.GLAND],
		"total_events": total_events,
		"events_per_min": float(total_events) * 60.0 / maxf(_phase_t, 0.001),
	}
	_print_phase(("RISKY" if _risky else "SAFE"), result)
	if _risky:
		_risky_result = result
		_report()
		return
	_safe_result = result
	_start_phase(true)

func _print_phase(label: String, r: Dictionary) -> void:
	print("  %s result" % label)
	print("    runs / mean survival   : %d runs, %.1fs each" % [r["runs"], r["mean_survival"]])
	print("    mean final score       : %d      (%.0f pts/min)" % [r["mean_score"], r["score_per_min"]])
	print("    score at t=%.0fs          : %d      (over %d runs that reached it)" % [
		CHECKPOINT_S, r["checkpoint_score"], r["checkpoint_runs"]])
	print("    pickups                : %d noisettes, %d glands" % [r["nuts"], r["glands"]])
	print("    collectible points     : %d (base value %d)" % [r["collectible_points"], r["base_points"]])
	print("    EFFECTIVE MULTIPLIER   : x%.2f" % r["effective_multiplier"])
	print("    combo mean (time-wtd)  : %.2f" % r["combo_mean"])
	print("    combo max              : %d" % r["combo_max"])
	print("    multiplier mean        : x%.2f" % r["multiplier_mean"])
	print("    time at multiplier > x1: %.1f%%" % (r["time_above_x1_frac"] * 100.0))
	print("    risk events            : %d total = %.1f/min" % [r["total_events"], r["events_per_min"]])
	print("      jump-dodge %d / near-miss %d / late-dodge %d / gland %d" % [
		r["jump_dodges"], r["near_misses"], r["late_dodges"], r["gland_events"]])
	print("")

func _report() -> void:
	print("=== SAFE vs RISKY ===")
	print("  risk events/min        : safe %.1f    risky %.1f" % [
		_safe_result["events_per_min"], _risky_result["events_per_min"]])
	print("  combo mean             : safe %.2f    risky %.2f" % [
		_safe_result["combo_mean"], _risky_result["combo_mean"]])
	print("  combo max              : safe %d       risky %d" % [
		_safe_result["combo_max"], _risky_result["combo_max"]])
	print("  time above x1          : safe %.1f%%    risky %.1f%%" % [
		_safe_result["time_above_x1_frac"] * 100.0, _risky_result["time_above_x1_frac"] * 100.0])
	print("  effective multiplier   : safe x%.2f   risky x%.2f" % [
		_safe_result["effective_multiplier"], _risky_result["effective_multiplier"]])
	print("  collectible pts/min    : safe %.1f    risky %.1f" % [
		_safe_result["collectible_points_per_min"], _risky_result["collectible_points_per_min"]])
	# THE matched-duration number -- see CHECKPOINT_S for why the raw
	# final-score line below it cannot carry this comparison on its own.
	var safe_cp: int = _safe_result["checkpoint_score"]
	var risky_cp: int = _risky_result["checkpoint_score"]
	print("  score at t=%.0fs (matched) : safe %d    risky %d   (+%.1f%%)" % [
		CHECKPOINT_S, safe_cp, risky_cp, (float(risky_cp) / maxf(float(safe_cp), 1.0) - 1.0) * 100.0])
	print("  mean final score       : safe %d    risky %d" % [
		_safe_result["mean_score"], _risky_result["mean_score"]])
	print("  mean survival          : safe %.1fs   risky %.1fs" % [
		_safe_result["mean_survival"], _risky_result["mean_survival"]])
	print("")

	# --- pass criteria, in order of how load-bearing they are ---------
	#
	# 1. Safe play must not SUSTAIN a multiplier. Note this is deliberately
	#    not "safe play must bank zero risk events": a ground ENEMY hunts
	#    the player's own lane and only commits ~0.35s before contact (see
	#    Obstacle._resolve_late_lock), so even perfectly cautious play is
	#    sometimes FORCED into a genuinely late escape. That is real risk,
	#    honestly credited. What must not happen is those scattered events
	#    chaining into a standing multiplier.
	var safe_above_x1: float = _safe_result["time_above_x1_frac"]
	if safe_above_x1 > 0.05:
		push_error("COMBO AUDIT FAILED: the SAFE bot held a multiplier %.1f%% of the time -- cautious play is accumulating a chain by accident, so the thresholds are too loose." % (safe_above_x1 * 100.0))
		get_tree().quit(1)
		return
	# 2. Risky play must be able to SUSTAIN one, or the multiplier is
	#    unreachable in practice regardless of how good the arithmetic is.
	var risky_above_x1: float = _risky_result["time_above_x1_frac"]
	if risky_above_x1 < 0.25:
		push_error("COMBO AUDIT FAILED: the RISKY bot only held a multiplier %.1f%% of the time -- risk is too rare on real track to keep a chain alive." % (risky_above_x1 * 100.0))
		get_tree().quit(1)
		return
	# 3. The multiplier must actually cash in. This is the one criterion
	#    that cannot be satisfied by surviving longer or collecting more --
	#    see the class doc.
	var risky_mult: float = _risky_result["effective_multiplier"]
	if risky_mult < 1.5:
		push_error("COMBO AUDIT FAILED: risky play earned an effective x%.2f on its collectibles -- the chain exists but is not worth enough to change anyone's incentives." % risky_mult)
		get_tree().quit(1)
		return
	# 4. And it must show up in the SCORE at a matched duration -- the
	#    criterion the whole batch is answerable to ("si jouer safe rapporte
	#    presque autant, la feature ne sert a rien"). This is the check that
	#    caught the batch's real design flaw: with the multiplier working
	#    perfectly (x1.90 effective, held 46% of the time) the matched-
	#    duration gap was still only +5.0%, because collectibles were ~2% of
	#    a run's score and multiplying 2% of anything changes nothing. See
	#    GameState.NOISETTE_VALUE for the rebalance that fixed it.
	var gap: float = float(risky_cp) / maxf(float(safe_cp), 1.0) - 1.0
	if gap < 0.25:
		push_error("COMBO AUDIT FAILED: at a matched %.0fs the risky bot scored only +%.1f%% over the safe one -- the multiplier works but has too small a share of the score to change how anyone plays." % [CHECKPOINT_S, gap * 100.0])
		get_tree().quit(1)
		return
	print("PASSED: safe play never sustains a multiplier, risky play holds one %.0f%% of the" % (risky_above_x1 * 100.0))
	print("        time, cashes it in at an effective x%.2f per collectible, and is worth" % risky_mult)
	print("        +%.0f%% on the scoreboard at a matched run duration." % (gap * 100.0))
	get_tree().quit(0)

# ---------------------------------------------------------------------
# BOTS
# ---------------------------------------------------------------------

## Plays to survive and nothing else: finds the hazard due on its own lane
## and leaves EARLY (SAFE_ESCAPE_LEAD_S), for the adjacent lane whose own
## nearest hazard is furthest away. Never jumps -- which also means it never
## takes a gland, since a gland sits at jump apex by construction.
func _drive_safe_bot() -> void:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var own: float = lane_ttc[_keepy.lane_index]
	if own < 0.0 or own > SAFE_ESCAPE_LEAD_S:
		return # nothing to run from yet
	var best_step := 0
	var best_ttc := own
	for step in [-1, 1]:
		var lane: int = _keepy.lane_index + step
		if lane < 0 or lane > 2:
			continue
		# A lane shut by a track-shrink window is not a destination. A
		# no-op without the mechanic (lane_blocked is always false then),
		# so it leaves every pre-shrink measurement byte-identical -- but
		# without it the bot keeps CHOOSING that lane, because it is empty
		# and therefore looks like the safest option on the board, has the
		# move refused by Keepy.move_lane, and stands still in front of
		# the hazard it meant to escape. That measures the bot's blindness
		# to a wall it cannot see, not the difficulty of the game.
		if GameState.lane_blocked(lane):
			continue
		var ttc: float = lane_ttc[lane] if lane_ttc[lane] >= 0.0 else INF
		if ttc > best_ttc:
			best_ttc = ttc
			best_step = step
	if best_step != 0:
		_keepy.move_lane(best_step)

## Plays for the combo: jump what can be jumped (on its own lane, timed so
## the apex lands on contact), reach for glands, and leave a lane an
## unjumpable hazard owns only at the last moment it can still survive.
func _drive_risky_bot() -> void:
	var threat := _nearest_obstacle_on_lane(_keepy.lane_index)
	if threat != null:
		var ttc: float = threat.time_to_contact_s()
		if not Obstacle.blocks_jump(threat.obstacle_type):
			# Jumpable, and holding the lane is the whole point: clear it
			# vertically for a JUMP_DODGE instead of stepping around it.
			if ttc <= HALF_AIR_TIME_S and ttc > 0.0 and _keepy.is_on_floor():
				_keepy.velocity.y = Keepy.JUMP_VELOCITY
			return
		# Unjumpable (DODGE / CHARGER): the escape is lateral, and taken as
		# late as the bot can still survive. Alternated between the two
		# targets so both lateral kinds get exercised.
		var target: float = _graze_escape_ttc(threat) if _alternate_escape else RISKY_LATE_ESCAPE_S
		if ttc <= target and ttc > 0.0:
			_alternate_escape = not _alternate_escape
			_keepy.move_lane(_safest_adjacent_step())
		return
	# No hazard due on this lane -- go and get a gland if one is live.
	var gland_lane := _reachable_gland_lane()
	if gland_lane == -1:
		return
	if gland_lane != _keepy.lane_index:
		_keepy.move_lane(signi(gland_lane - _keepy.lane_index))
		return
	if _keepy.is_on_floor() and _gland_ttc_on_lane(gland_lane) <= HALF_AIR_TIME_S:
		_keepy.velocity.y = Keepy.JUMP_VELOCITY

## Time-before-contact at which leaving this hazard's lane lands the bot in
## the middle of the near-miss band, derived rather than guessed.
##
## Two terms, both from geometry the shipped code already declares:
##   1. when the SAMPLING window opens, in seconds before contact --
##      Obstacle.RISK_PROXIMITY_Z divided by THIS hazard's own closing
##      speed (a charger's is 2.35x the world's, which is exactly why one
##      fixed constant could never serve both);
##   2. how long the lane lerp needs to cover RISKY_GRAZE_TARGET_M, by
##      inverting Keepy's own exponential ease
##      d(t) = pitch * (1 - e^(-LANE_SWITCH_SPEED * t)).
## The minimum lateral distance over a passage is taken at the instant the
## window opens (the bot is still sliding away, so it only gets further
## after that), so leaving this far ahead of contact puts that minimum on
## the target.
func _graze_escape_ttc(hazard: Obstacle) -> float:
	var window_open_s: float = Obstacle.RISK_PROXIMITY_Z / maxf(hazard.closing_speed(), 0.001)
	var pitch: float = TrackSegment.LANE_X[1] - TrackSegment.LANE_X[0] # 2.0m, from the source
	var fraction: float = clampf(RISKY_GRAZE_TARGET_M / pitch, 0.0, 0.99)
	var lerp_s: float = -log(1.0 - fraction) / Keepy.LANE_SWITCH_SPEED
	return window_open_s + lerp_s

## Direction (-1/+1) toward the adjacent lane whose own nearest hazard is
## furthest out. Never returns 0: the caller has already decided it must
## move, and staying put means walking into an unjumpable hazard.
func _safest_adjacent_step() -> int:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var best_step := 1 if _keepy.lane_index == 0 else -1
	var best_ttc := -INF
	for step in [-1, 1]:
		var lane: int = _keepy.lane_index + step
		if lane < 0 or lane > 2:
			continue
		# A lane shut by a track-shrink window is not a destination. A
		# no-op without the mechanic (lane_blocked is always false then),
		# so it leaves every pre-shrink measurement byte-identical -- but
		# without it the bot keeps CHOOSING that lane, because it is empty
		# and therefore looks like the safest option on the board, has the
		# move refused by Keepy.move_lane, and stands still in front of
		# the hazard it meant to escape. That measures the bot's blindness
		# to a wall it cannot see, not the difficulty of the game.
		if GameState.lane_blocked(lane):
			continue
		var ttc: float = lane_ttc[lane] if lane_ttc[lane] >= 0.0 else INF
		if ttc > best_ttc:
			best_ttc = ttc
			best_step = step
	return best_step

# ---------------------------------------------------------------------
# TRACK QUERIES -- read-only scans of the live track, same shape as
# AntiFrustrationAudit.gd's own. SEGMENT_COUNT is 7, so these are cheap.
# ---------------------------------------------------------------------

## Reused across frames rather than re-allocated on every call -- a probe
## must not be the thing that introduces per-frame garbage into a run it is
## measuring.
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

## Lane of the nearest live Gland still ahead of the player, SKIPPING any
## lane with a hazard due within GLAND_CHASE_SAFE_LEAD_S -- see that
## constant for why a bot that ignores this measures its own recklessness
## rather than the reward system. Uses TrackSegment.active_gland_z_on_lane,
## the accessor the shipped spawner already exposes for exactly this kind of
## question, rather than reaching into a segment's pooled nodes.
func _reachable_gland_lane() -> int:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var best_lane := -1
	var best_z := -INF
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		for lane in 3:
			# Same reasoning as the escape picker above: a gland already
			# on the track when a shrink window opens can sit behind the
			# barrier, and chasing it is a move Keepy.move_lane refuses --
			# the bot would stall sideways against the wall. (The spawner
			# stops PLACING collectibles in a shut lane, so this only ever
			# catches ones that were already in flight.)
			if GameState.lane_blocked(lane):
				continue
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
