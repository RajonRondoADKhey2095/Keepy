extends Node
## Dev-only diagnostic: empirically verifies the anti-frustration
## guarantee added alongside the ground-ENEMY-hunts-the-player-lane and
## mobile-landing-AIR_ENEMY difficulty batch -- "the player must never be
## in a situation where no action saves them" (task's cas interdit 1/2/3).
##
## Rather than trust that TrackManager.lane_has_conflicting_jump_hazard /
## Obstacle._resolve_late_lock's exclusions are correct by inspection,
## this probe RE-DERIVES the same "is there an escape" question
## independently, straight from the live obstacle state, every physics
## frame of a long real run -- the same "measure, don't assume" standard
## the rest of this dev/ folder holds itself to (see EnemyLaneAudit.gd's
## own header for the precedent).
##
## THE INVARIANT CHECKED, per physics frame, for the player's CURRENT
## lane P:
##   - "imminent ground threat on P" = any active obstacle on lane P
##     whose time-to-contact has fallen to or below
##     Obstacle.ENEMY_REACTION_WINDOW_S (>0, i.e. still ahead) -- the
##     same instant ENEMY hard-locks and AIR_ENEMY finishes landing, so
##     by this point EVERY ground-blocking obstacle type is in its FINAL,
##     committed state (no more sway, no more descent). Before this
##     instant nothing is imminent enough to matter yet.
##   - if one exists, the player is trapped UNLESS at least one of:
##       JUMP-SAFE   -- the threat is jumpable (not DODGE, and not an
##                       AIR_ENEMY that hasn't finished landing) AND no
##                       OTHER active obstacle on the SAME lane is an
##                       AIR_ENEMY still airborne with a time-to-contact
##                       close enough (AIR_HAZARD_SEPARATION_S) to
##                       collide with the timing a jump over the first
##                       threat would need.
##       SWITCH-SAFE -- at least one ADJACENT lane has no imminent ground
##                       threat of its own.
##   - trapped => violation, counted and logged, but the run keeps going
##     (a full picture of HOW OFTEN, not just whether, matters more here
##     than stopping at the first one).
##
## Collision is neutered (matches PacingAudit.gd/EnemyLaneAudit.gd) so a
## SINGLE continuous run covers the whole simulated window without
## restart churn -- this check's correctness does not depend on whether
## Keepy would actually survive, only on whether an escape EXISTS, so a
## bot that cannot die is the simplest way to keep exercising the ground
## ENEMY's late lock against every lane the bot visits. The bot itself
## roams lanes on a randomized timer (never learns, never reacts to
## danger) purely to vary which lane the ground ENEMY ends up targeting
## across the run -- see Obstacle._resolve_late_lock, which reads
## Keepy's ACTUAL current lane.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/AntiFrustrationAudit.tscn

const SIM_SECONDS: float = 330.0 # >= 5 minutes, per the task's explicit ask
const BOT_SWITCH_MIN_INTERVAL_S: float = 0.6
const BOT_SWITCH_MAX_INTERVAL_S: float = 2.4

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0
var _next_bot_switch_t: float = 0.0

var _violations: int = 0
var _frames_checked: int = 0
var _imminent_threat_frames: int = 0

func _ready() -> void:
	# Must run BEFORE Game.tscn is instantiated below -- see DevSeed.gd.
	# No-op unless `-- --seed=<int>` was passed; the default stays the
	# exploratory, different-every-time run this probe wants.
	var seeded := DevSeed.apply()
	# The PURSUER is a parallel system and is not what this probe measures
	# -- see GameState.pursuer_enabled for the full reasoning. Short
	# version: this probe's bot has collision neutered so ONE continuous run
	# can cover the whole simulated window, and the pursuer kills exactly
	# that kind of bot, which leaves GameState out of PLAYING and hangs this
	# probe short of its own completion check. Switching it off is also what
	# keeps these numbers directly comparable to the pre-pursuer baseline.
	GameState.pursuer_enabled = false
	print("=== ANTI-FRUSTRATION AUDIT ===")
	print("rng                        : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("running %.0fs simulated, checking every physics frame that the player's" % SIM_SECONDS)
	print("current lane always has a jump escape or a switch escape when threatened")
	print("")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	# Neutered exactly like PacingAudit.gd -- see the header for why this
	# check's validity does not depend on Keepy surviving.
	_keepy.collision_layer = 0
	_next_bot_switch_t = randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return
	_t += delta

	_drive_bot()
	_check_current_lane()

	if _t >= SIM_SECONDS:
		print("--- result ---")
		print("simulated time            : %.1fs" % _t)
		print("physics frames checked     : %d" % _frames_checked)
		print("frames with imminent threat: %d" % _imminent_threat_frames)
		print("violations (no escape)     : %d (must be 0)" % _violations)
		if _violations > 0:
			push_error("ANTI-FRUSTRATION AUDIT FAILED: %d frame(s) found the player's current lane with no jump escape and no switch escape available." % _violations)
			get_tree().quit(1)
		else:
			print("PASSED: every imminent threat left at least one escape available.")
			get_tree().quit(0)

## Aimless random lane roaming -- see the class doc for why this is
## deliberately NOT reactive/skilled play. Never jumps (irrelevant here,
## collision is neutered, and jump state has no bearing on which lane
## Obstacle._resolve_late_lock reads).
func _drive_bot() -> void:
	if _t < _next_bot_switch_t:
		return
	_next_bot_switch_t = _t + randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)
	_keepy.move_lane([-1, 1].pick_random())

## The invariant check -- see the class doc for the exact rule. Scans
## every live TrackSegment once per frame; SEGMENT_COUNT is small (7) and
## this is a dev-only probe, so no pooling concerns here (unlike the
## shipped gameplay code this measures).
func _check_current_lane() -> void:
	_frames_checked += 1
	var player_lane := _keepy.lane_index

	var ground_ttc: Array[float] = [-1.0, -1.0, -1.0] # per-lane nearest imminent ground threat, -1.0 = none
	var ground_jumpable: Array[bool] = [false, false, false]
	var air_hazards: Array = [] # [{lane:int, ttc:float}] -- every active, still-airborne AIR_ENEMY, any distance

	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		var lane := _lane_index_for_x(obstacle.position.x)
		if lane == -1:
			continue # mid-sway ENEMY, not yet locked -- not imminent by definition (see below)
		var ttc: float = obstacle.time_to_contact_s()

		if obstacle.obstacle_type == Obstacle.Type.AIR_ENEMY and not obstacle.air_enemy_landed:
			air_hazards.append({"lane": lane, "ttc": ttc})

		if ttc <= 0.0 or ttc > Obstacle.ENEMY_REACTION_WINDOW_S:
			continue # not yet in its final, committed state -- see class doc
		if obstacle.obstacle_type == Obstacle.Type.ENEMY and obstacle.get("_enemy_settling"):
			continue # still mid-sway despite the ttc window (shouldn't happen by construction, but don't assume)

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
		return # nothing imminent on the player's own lane -- no escape needed

	_imminent_threat_frames += 1

	var jump_safe := ground_jumpable[player_lane] and not _jump_lethal_nearby(air_hazards, player_lane, threat_ttc)
	var switch_safe := false
	for adjacent in [player_lane - 1, player_lane + 1]:
		if adjacent < 0 or adjacent > 2:
			continue
		if ground_ttc[adjacent] < 0.0:
			switch_safe = true
			break

	if not jump_safe and not switch_safe:
		_violations += 1
		push_error("VIOLATION at t=%.2fs: lane %d has an imminent %s (ttc=%.3fs) with no jump escape (jumpable=%s) and no switch escape (lane %d ttc=%s, lane %d ttc=%s)." % [
			_t, player_lane,
			("DODGE" if not ground_jumpable[player_lane] else "jumpable hazard"),
			threat_ttc, ground_jumpable[player_lane],
			player_lane - 1, ("clear" if player_lane - 1 < 0 else str(ground_ttc[player_lane - 1])),
			player_lane + 1, ("clear" if player_lane + 1 > 2 else str(ground_ttc[player_lane + 1])),
		])

## Whether jumping over the ground threat on `lane` at `threat_ttc` would
## fly straight into a still-airborne AIR_ENEMY -- reuses
## TrackManager.AIR_HAZARD_SEPARATION_S as the "close enough in time to
## collide" margin, the SAME margin Obstacle._resolve_late_lock's own
## redirect uses, so this check is judging the game by its own declared
## fairness budget, not a stricter or looser one invented for the probe.
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
