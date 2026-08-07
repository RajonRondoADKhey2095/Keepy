extends Node
## Dev-only diagnostic: the SAME anti-frustration guarantee
## AntiFrustrationAudit.gd verifies over a whole run, but with every
## measurement RESTRICTED to physics frames where TrackManager reports a
## RUSH window is currently active (TrackManager.is_rush_active()) --
## the playtest-fixes-2 task's explicit ask to re-verify the guarantee
## SPECIFICALLY during rush windows, not just averaged across a run that
## is mostly NOT rushing.
##
## Logic is otherwise a straight copy of AntiFrustrationAudit.gd's own
## per-frame check (see that file for the full rule this re-derives) --
## duplicated rather than refactored into a shared helper so this file
## reads standalone and neither probe risks a shared-helper edit quietly
## changing what the OTHER one verifies.
##
## Runs long enough (SIM_SECONDS) to accumulate many independent rush
## windows: RUSH_MIN_START_S=18s before the first is even eligible, then
## windows of TrackManager.RUSH_DURATION_MIN_S..MAX_S (5-8s) separated by
## TrackManager.CALM_DURATION_MIN_S..MAX_S (2-3s) of calm and
## TrackManager.RUSH_COOLDOWN_MIN_S..MAX_S (4-10s) of cooldown -- a rush
## recurs roughly every 15-25s on average, so a 600s run samples on the
## order of 25-35 independent rush occurrences.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/RushFrustrationAudit.tscn

const SIM_SECONDS: float = 600.0
const BOT_SWITCH_MIN_INTERVAL_S: float = 0.6
const BOT_SWITCH_MAX_INTERVAL_S: float = 2.4

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0
var _next_bot_switch_t: float = 0.0

var _violations: int = 0
var _rush_frames_checked: int = 0
var _rush_imminent_threat_frames: int = 0
var _rush_windows_seen: int = 0
var _was_rush_active: bool = false

## Frames where a rush and a track-shrink window were BOTH open. Not a
## failure -- TrackManager refuses to START a rush during a window but
## deliberately never cuts short one already in flight (see its
## _update_density_phase), so a bounded overlap is the designed
## behaviour. Counted so "bounded" is a measurement rather than a claim,
## and so a future change that let the two stack freely would show up
## here as a number that stopped being small.
var _rush_shrink_overlap_frames: int = 0

## Same probe override as AntiFrustrationAudit.PROBE_UNLOCK_SCORE -- see
## its doc. Without it this probe's 600s run would spend its first ~2
## minutes below the shipped score gate, and the overlap it now reports
## would be measured over a shorter window than the run implies.
const PROBE_UNLOCK_SCORE: int = 600

func _ready() -> void:
	# Must run BEFORE Game.tscn is instantiated below -- see DevSeed.gd.
	# No-op unless `-- --seed=<int>` was passed.
	var seeded := DevSeed.apply()
	# The PURSUER is a parallel system and is not what this probe measures
	# -- see GameState.pursuer_enabled for the full reasoning. Short
	# version: this probe's bot has collision neutered so ONE continuous run
	# can cover the whole simulated window, and the pursuer kills exactly
	# that kind of bot, which leaves GameState out of PLAYING and hangs this
	# probe short of its own completion check. Switching it off is also what
	# keeps these numbers directly comparable to the pre-pursuer baseline.
	GameState.pursuer_enabled = false
	GameState.shrink_unlock_score = PROBE_UNLOCK_SCORE
	print("=== RUSH FRUSTRATION AUDIT ===")
	print("rng: %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("running %.0fs simulated, checking every physics frame WHILE A RUSH IS ACTIVE" % SIM_SECONDS)
	print("that the player's current lane always has a jump escape or a switch escape")
	print("")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	# Same neutering as AntiFrustrationAudit.gd -- see its header for why
	# this check's validity does not depend on Keepy surviving.
	_keepy.collision_layer = 0
	_next_bot_switch_t = randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return
	_t += delta

	_drive_bot()

	var rush_active: bool = _track.is_rush_active()
	if rush_active and not _was_rush_active:
		_rush_windows_seen += 1
	_was_rush_active = rush_active

	if rush_active:
		if GameState.shrink_active():
			_rush_shrink_overlap_frames += 1
		_check_current_lane()

	if _t >= SIM_SECONDS:
		print("--- result ---")
		print("simulated time                  : %.1fs" % _t)
		print("distinct rush windows entered    : %d" % _rush_windows_seen)
		print("physics frames checked (rush only): %d" % _rush_frames_checked)
		print("frames with imminent threat       : %d" % _rush_imminent_threat_frames)
		print("frames also inside a shrink window: %d (overlap is bounded, not forbidden)" % _rush_shrink_overlap_frames)
		print("violations (no escape)            : %d (must be 0)" % _violations)
		if _violations > 0:
			push_error("RUSH FRUSTRATION AUDIT FAILED: %d frame(s) during a rush window found the player's current lane with no jump escape and no switch escape available." % _violations)
			get_tree().quit(1)
		else:
			print("PASSED: every imminent threat during a rush window left at least one escape available.")
			get_tree().quit(0)

## Aimless random lane roaming -- see AntiFrustrationAudit.gd's own doc
## for why this is deliberately NOT reactive/skilled play.
func _drive_bot() -> void:
	if _t < _next_bot_switch_t:
		return
	_next_bot_switch_t = _t + randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)
	_keepy.move_lane([-1, 1].pick_random())

## Identical rule to AntiFrustrationAudit._check_current_lane() -- see
## that file's class doc for the full invariant this re-derives.
func _check_current_lane() -> void:
	_rush_frames_checked += 1
	var player_lane := _keepy.lane_index

	var ground_ttc: Array[float] = [-1.0, -1.0, -1.0]
	var ground_jumpable: Array[bool] = [false, false, false]
	var air_hazards: Array = []

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

		if obstacle.obstacle_type == Obstacle.Type.AIR_ENEMY and not obstacle.air_enemy_landed:
			air_hazards.append({"lane": lane, "ttc": ttc})

		if ttc <= 0.0 or ttc > Obstacle.ENEMY_REACTION_WINDOW_S:
			continue
		if obstacle.obstacle_type == Obstacle.Type.ENEMY and obstacle.get("_enemy_settling"):
			continue

		if ground_ttc[lane] < 0.0 or ttc < ground_ttc[lane]:
			ground_ttc[lane] = ttc
			# NOT "anything that is not DODGE is jumpable" any more:
			# CHARGER is also unjumpable (Obstacle.blocks_jump, same
			# hitbox as DODGE), so the old test would have credited the
			# player with a jump escape that does not exist and quietly
			# under-reported violations. AIR_ENEMY is deliberately still
			# treated as jumpable here -- by this point in the window it
			# has landed, and the still-airborne case is handled
			# separately via air_hazards / _jump_lethal_nearby.
			ground_jumpable[lane] = not (obstacle.obstacle_type == Obstacle.Type.DODGE \
				or obstacle.obstacle_type == Obstacle.Type.CHARGER)

	var threat_ttc: float = ground_ttc[player_lane]
	if threat_ttc < 0.0:
		return

	_rush_imminent_threat_frames += 1

	var jump_safe := ground_jumpable[player_lane] and not _jump_lethal_nearby(air_hazards, player_lane, threat_ttc)
	var switch_safe := false
	for adjacent in [player_lane - 1, player_lane + 1]:
		if adjacent < 0 or adjacent > 2:
			continue
		# Same exclusion, and the same reason, as
		# AntiFrustrationAudit._check_current_lane -- see that file's class
		# doc. A lane shut by a track-shrink window is empty because the
		# game stopped spawning there, so counting it as an escape would
		# make this probe pass on exactly the runs it exists to catch.
		if GameState.lane_blocked(adjacent):
			continue
		if ground_ttc[adjacent] < 0.0:
			switch_safe = true
			break

	if not jump_safe and not switch_safe:
		_violations += 1
		push_error("RUSH VIOLATION at t=%.2fs: lane %d has an imminent %s (ttc=%.3fs) with no jump escape (jumpable=%s) and no switch escape (lane %d ttc=%s, lane %d ttc=%s)." % [
			_t, player_lane,
			("DODGE" if not ground_jumpable[player_lane] else "jumpable hazard"),
			threat_ttc, ground_jumpable[player_lane],
			player_lane - 1, ("clear" if player_lane - 1 < 0 else str(ground_ttc[player_lane - 1])),
			player_lane + 1, ("clear" if player_lane + 1 > 2 else str(ground_ttc[player_lane + 1])),
		])

func _jump_lethal_nearby(air_hazards: Array, lane: int, threat_ttc: float) -> bool:
	for entry in air_hazards:
		if entry["lane"] != lane:
			continue
		if absf(entry["ttc"] - threat_ttc) < TrackManager.AIR_HAZARD_SEPARATION_S:
			return true
	return false

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
