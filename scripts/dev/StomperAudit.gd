extends Node
## Dev-only diagnostic for Obstacle.Type.STOMPER's core contract: "jump is
## the only escape, lane switch never is" -- see the Type.STOMPER doc in
## Obstacle.gd. Empirically verifies the two halves of that claim, the
## same "measure, don't assume" standard AirHazardAudit.gd and
## JumpDodgeRewardAudit.gd already hold themselves to (this probe's
## PHASE structure and its "neuter every other obstacle on sight" and
## "timed half-air-time jump" techniques are both borrowed from those two
## files directly, see their own headers for the full reasoning).
##
## PHASE 1 (NEVER JUMPS, ROAMS LANES) -- boots the real Game.tscn with
## REAL collision. Every non-STOMPER obstacle is neutered on sight
## (monitoring disabled, same technique as AirHazardAudit.gd) so only a
## STOMPER can ever end the run -- a death is therefore always
## attributable to the thing this probe is actually testing. The bot
## roams lanes on the SAME randomized timer AntiFrustrationAudit.gd's
## does (never jumps, no reactive skill) specifically so this phase
## proves more than "standing still and ignoring it is lethal" --
## ACTIVELY switching lanes, with no jump, must ALSO always be lethal
## once a STOMPER commits, which is the literal claim "changer de lane ne
## l'esquive pas" makes. Asserts every run ends in GAME_OVER via a
## STOMPER within the timeout, across MIN_ENCOUNTERS_REQUIRED independent
## samples.
##
## PHASE 2 (JUMPS CORRECTLY) -- a fresh run of the same scene, same
## neutering, this time watching for a STOMPER and commanding a jump
## timed so its APEX lands exactly at the moment of contact (the same
## half-air-time technique JumpDodgeRewardAudit.gd/AirHazardAudit.gd use:
## liftoff at time-to-contact == Keepy.JUMP_VELOCITY/Keepy.GRAVITY).
## Asserts, for every encounter:
##   1. the run stays PLAYING (the jump actually cleared it);
##   2. GameState.jump_dodge_score increased by EXACTLY
##      GameState.JUMP_DODGE_BONUS_VALUE -- the SAME reward JUMP/ENEMY
##      already grant (Obstacle._trigger_jump_dodge_feedback, no new
##      vocabulary), proving the existing jump-dodge detection
##      (Obstacle._is_jump_dodge) already recognises a cleared STOMPER
##      with ZERO code changes: blocks_jump(STOMPER) is false, and once
##      committed a STOMPER's position.x is a live, exact copy of the
##      player's, so at the crossing instant it is is_equal_approx to
##      TrackSegment.LANE_X[player.lane_index] whenever the player is not
##      mid-slide -- exactly what _is_jump_dodge already checks for every
##      other jumpable type.
##   3. GameState.register_risk_event's own combo bookkeeping moved too
##      (GameState.combo_count increased) -- the SAME generic path every
##      OTHER RiskEvent already drives, confirming the risk event also
##      feeds the combo system as the task requires, again with no
##      STOMPER-specific code anywhere in GameState.gd.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/StomperAudit.tscn

const SIM_TIMEOUT_S: float = 240.0 # safety cap while waiting for the next STOMPER encounter
const MIN_ENCOUNTERS_REQUIRED: int = 5
const SURVIVAL_HOLD_S: float = 0.5 # confirm survival + score/combo credit a moment after the jump completes
const BOT_SWITCH_MIN_INTERVAL_S: float = 0.6
const BOT_SWITCH_MAX_INTERVAL_S: float = 2.4

var _phase: int = 1
var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0
var _encounters: int = 0
var _next_bot_switch_t: float = 0.0

# Phase 2 state
var _jump_target_key: int = -1
var _jump_commanded: bool = false
var _jump_commanded_t: float = 0.0
var _jump_dodge_score_before: int = 0
var _combo_count_before: int = 0
var _check_deadline: float = -1.0

func _ready() -> void:
	print("=== STOMPER AUDIT ===")
	print("phase 1: never jumping (but actively switching lanes) must always be lethal to a STOMPER")
	_start_game()

func _start_game() -> void:
	if _game:
		_game.queue_free()
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	_jump_target_key = -1
	_jump_commanded = false
	_check_deadline = -1.0
	_next_bot_switch_t = randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)

func _physics_process(delta: float) -> void:
	if _phase == 1:
		_run_phase_1(delta)
	else:
		_run_phase_2(delta)

func _run_phase_1(delta: float) -> void:
	_t += delta
	_drive_bot()
	_neuter_non_stompers()

	if GameState.state == GameState.State.GAME_OVER:
		_encounters += 1
		if _encounters >= MIN_ENCOUNTERS_REQUIRED:
			print("PHASE 1 PASSED: died to a STOMPER every time (%d/%d encounters), lane-switching never once saved a never-jumping bot." % [_encounters, MIN_ENCOUNTERS_REQUIRED])
			print("")
			print("phase 2: a well-timed jump over a STOMPER must always survive and credit the reward")
			_phase = 2
			_t = 0.0
			_encounters = 0
			_start_game()
			return
		print("phase 1: encounter %d/%d confirmed lethal, restarting for another sample" % [_encounters, MIN_ENCOUNTERS_REQUIRED])
		_t = 0.0
		_start_game()
		return

	if _t >= SIM_TIMEOUT_S:
		push_error("PHASE 1 FAILED: no STOMPER killed a lane-switching, never-jumping bot within %.1fs (%d/%d encounters). STOMPER should be lethal to ANY response that is not a jump, always." % [SIM_TIMEOUT_S, _encounters, MIN_ENCOUNTERS_REQUIRED])
		get_tree().quit(1)

func _run_phase_2(delta: float) -> void:
	_t += delta
	_neuter_non_stompers()

	if GameState.state == GameState.State.GAME_OVER:
		if _jump_commanded:
			push_error("PHASE 2 FAILED: died %.3fs after a jump timed to clear a STOMPER -- jump should always be a safe, sufficient escape." % [_t - _jump_commanded_t])
			get_tree().quit(1)
		else:
			print("phase 2: died before the timed jump (unrelated cause) -- retrying")
			_jump_target_key = -1
			_jump_commanded = false
			_check_deadline = -1.0
			_t = 0.0
			_start_game()
		return

	if _jump_commanded and _check_deadline >= 0.0 and _t >= _check_deadline:
		if GameState.state != GameState.State.PLAYING:
			push_error("PHASE 2 FAILED: run did not stay PLAYING after the timed jump over a STOMPER.")
			get_tree().quit(1)
			return
		var delta_score: int = GameState.jump_dodge_score - _jump_dodge_score_before
		if delta_score != GameState.JUMP_DODGE_BONUS_VALUE:
			push_error("PHASE 2 FAILED: jump_dodge_score changed by %d, expected exactly %d -- a cleared STOMPER should credit the same JUMP_DODGE reward as JUMP/ENEMY." % [delta_score, GameState.JUMP_DODGE_BONUS_VALUE])
			get_tree().quit(1)
			return
		var delta_combo: int = GameState.combo_count - _combo_count_before
		if delta_combo <= 0:
			push_error("PHASE 2 FAILED: combo_count did not increase (before=%d, after=%d) -- a cleared STOMPER should feed the combo system exactly like every other RiskEvent." % [_combo_count_before, GameState.combo_count])
			get_tree().quit(1)
			return
		_encounters += 1
		print("  encounter %d/%d: survived, jump_dodge_score +%d, combo_count +%d (total combo %d)" % [_encounters, MIN_ENCOUNTERS_REQUIRED, delta_score, delta_combo, GameState.combo_count])
		if _encounters >= MIN_ENCOUNTERS_REQUIRED:
			print("PHASE 2 PASSED: %d/%d timed jumps over a STOMPER all survived, all credited the JUMP_DODGE reward, all fed the combo -- the existing detection needed zero changes." % [_encounters, MIN_ENCOUNTERS_REQUIRED])
			get_tree().quit(0)
			return
		_jump_target_key = -1
		_jump_commanded = false
		_check_deadline = -1.0
		_t = 0.0
		_start_game()
		return

	if _t >= SIM_TIMEOUT_S:
		push_error("PHASE 2 FAILED: no STOMPER reached the player within %.1fs, or the timed jump was never armed." % SIM_TIMEOUT_S)
		get_tree().quit(1)
		return

	_scan_for_stomper()

func _drive_bot() -> void:
	if _t < _next_bot_switch_t:
		return
	_next_bot_switch_t = _t + randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)
	_keepy.move_lane([-1, 1].pick_random())

## Disables monitoring on every live non-STOMPER obstacle so only a
## STOMPER can ever end the run in either phase -- same technique and
## same set_deferred rationale as AirHazardAudit.gd's own
## _scan_air_enemies (Godot forbids toggling Area3D.monitoring from
## inside an in-flight body_entered/body_exited dispatch).
func _neuter_non_stompers() -> void:
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle: Obstacle = null
		for child in segment.get_children():
			if child is Obstacle:
				obstacle = child
				break
		if obstacle == null or not obstacle.visible:
			continue
		if obstacle.obstacle_type != Obstacle.Type.STOMPER:
			obstacle.set_deferred("monitoring", false)

func _scan_for_stomper() -> void:
	if _jump_commanded:
		return
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle: Obstacle = null
		for child in segment.get_children():
			if child is Obstacle:
				obstacle = child
				break
		if obstacle == null or not obstacle.visible:
			continue
		if obstacle.obstacle_type != Obstacle.Type.STOMPER:
			continue

		var key := segment.get_instance_id()
		if _jump_target_key == -1:
			_jump_target_key = key
		if _jump_target_key != key:
			continue

		var time_to_contact := obstacle.time_to_contact_s()
		var half_air_time := Keepy.JUMP_VELOCITY / Keepy.GRAVITY
		if time_to_contact <= half_air_time and _keepy.is_on_floor():
			_jump_dodge_score_before = GameState.jump_dodge_score
			_combo_count_before = GameState.combo_count
			_keepy.velocity.y = Keepy.JUMP_VELOCITY
			_jump_commanded = true
			_jump_commanded_t = _t
			_check_deadline = _t + 2.0 * half_air_time + SURVIVAL_HOLD_S
			print("  jumped at t=%.2fs, time-to-contact was %.3fs (target %.3fs)" % [_t, time_to_contact, half_air_time])
