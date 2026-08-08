extends Node
## Dev-only diagnostic for the jump-dodge reward (chantier 2,
## playtest-fixes batch: "meme quand je le fais je ne sens rien" -- see
## Obstacle.gd _is_jump_dodge / _trigger_jump_dodge_feedback,
## GameState.add_jump_dodge_bonus). Empirically verifies the reward
## actually fires on a real timed jump over a real JUMP obstacle, rather
## than trusting the detection logic by inspection alone -- same
## "measure, don't assume" standard as every other probe in this folder.
##
## Boots the real Game.tscn with REAL collision (same technique as
## AirHazardAudit.gd's phase 2: no input injected, Keepy stays on the
## CENTER lane the whole run since it never moves and never needs to --
## a JUMP obstacle's lane is picked at SPAWN time, unlike ENEMY's late
## lock, so this probe only needs to wait for one to land on lane 1).
## Any OTHER obstacle type landing on the center lane before a JUMP does
## would end the run -- that just means "no sample this run", not a
## failure, so a run is simply restarted rather than treated as a result.
##
## For each JUMP obstacle encountered on lane 1: arms a timed jump (same
## half-air-time technique as AirHazardAudit's phase 2 -- liftoff at
## time-to-contact == half of Keepy's total air time lands the jump's
## apex exactly on the obstacle's arrival), then asserts, a short time
## after landing:
##   1. the run is STILL PLAYING (the jump actually cleared it -- if this
##      probe's own timing were wrong, this would catch it as surely as a
##      dedicated "does JUMP stay jumpable" probe would);
##   2. GameState.jump_dodge_score increased by EXACTLY
##      GameState.JUMP_DODGE_BONUS_VALUE since just before the jump --
##      the actual reward this probe exists to verify, isolated from
##      distance_score/noisette_score/gland_score (which also tick
##      during the same window) by reading the DEDICATED counter, never
##      the combined `score`.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/JumpDodgeRewardAudit.tscn

const SIM_TIMEOUT_S: float = 300.0 # safety cap while waiting for enough JUMP encounters
const MIN_ENCOUNTERS_REQUIRED: int = 5
const SURVIVAL_HOLD_S: float = 0.5 # confirm survival + score credit a moment after the jump completes

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0
var _encounters: int = 0

var _jump_target_key: int = -1
var _jump_commanded: bool = false
var _jump_commanded_t: float = 0.0
var _jump_dodge_score_before: int = 0
var _check_deadline: float = -1.0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "JumpDodgeRewardAudit")
	# MUST precede _start_game() -- see DevSeed.gd. Missing here for the
	# same reason it was missing in AirHazardAudit (finding F6a): --seed is
	# not ambient, DevSeed.apply() is the only thing that reads it, and this
	# file borrows AirHazardAudit's phase-2 technique wholesale -- it
	# inherited the gap along with the technique. Measured on this tree
	# before the call: 20 runs at one seed produced 20 distinct outputs.
	var seeded := DevSeed.apply()
	print("=== JUMP DODGE REWARD AUDIT ===")
	print("rng    : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("watching for a well-timed jump over a JUMP obstacle on the center lane;")
	print("asserts survival AND GameState.jump_dodge_score += JUMP_DODGE_BONUS_VALUE (%d)" % GameState.JUMP_DODGE_BONUS_VALUE)
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

func _physics_process(delta: float) -> void:
	_t += delta

	if GameState.state == GameState.State.GAME_OVER:
		if _jump_commanded and _target_is_at_the_player():
			push_error("JUMP DODGE REWARD AUDIT FAILED: died %.3fs after a jump timed to clear a JUMP obstacle, WITH THAT SAME OBSTACLE at the player plane -- either the jump timing or JUMP's own jumpability regressed." % (_t - _jump_commanded_t))
			get_tree().quit(1)
			return
		if _jump_commanded:
			print("  died %.3fs after the jump but to a DIFFERENT hazard (the jumped one was already behind) -- retrying" % (_t - _jump_commanded_t))
			_jump_target_key = -1
			_jump_commanded = false
			_check_deadline = -1.0
			_t = 0.0
			_start_game()
			return
		# Died some other way (a different obstacle type landed on the
		# center lane first) -- inconclusive, not a failure of this
		# check. Restart for another sample.
		print("  died before a timed jump (unrelated obstacle) -- retrying")
		_t = 0.0
		_start_game()
		return

	if _jump_commanded and _check_deadline >= 0.0 and _t >= _check_deadline:
		var delta_score: int = GameState.jump_dodge_score - _jump_dodge_score_before
		if GameState.state != GameState.State.PLAYING:
			push_error("JUMP DODGE REWARD AUDIT FAILED: run did not stay PLAYING after the timed jump.")
			get_tree().quit(1)
			return
		if delta_score != GameState.JUMP_DODGE_BONUS_VALUE:
			push_error("JUMP DODGE REWARD AUDIT FAILED: jump_dodge_score changed by %d, expected exactly %d." % [delta_score, GameState.JUMP_DODGE_BONUS_VALUE])
			get_tree().quit(1)
			return
		_encounters += 1
		print("  encounter %d/%d: survived + jump_dodge_score +%d (total %d)" % [_encounters, MIN_ENCOUNTERS_REQUIRED, delta_score, GameState.jump_dodge_score])
		if _encounters >= MIN_ENCOUNTERS_REQUIRED:
			print("PASSED: %d/%d timed jumps over a JUMP obstacle all survived AND credited the reward exactly once each." % [_encounters, MIN_ENCOUNTERS_REQUIRED])
			get_tree().quit(0)
			return
		_jump_target_key = -1
		_jump_commanded = false
		_check_deadline = -1.0
		_t = 0.0
		_start_game()
		return

	if _t >= SIM_TIMEOUT_S:
		push_error("JUMP DODGE REWARD AUDIT FAILED: no JUMP obstacle reached the center lane within %.1fs, or the timed jump was never armed." % SIM_TIMEOUT_S)
		get_tree().quit(1)
		return

	_scan_for_jump_obstacle()

func _scan_for_jump_obstacle() -> void:
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
		if obstacle.obstacle_type != Obstacle.Type.JUMP:
			continue
		if not is_equal_approx(obstacle.position.x, TrackSegment.LANE_X[1]):
			continue # not the center lane Keepy sits on -- not a candidate this run

		var key := segment.get_instance_id()
		if _jump_target_key == -1:
			_jump_target_key = key
		if _jump_target_key != key:
			continue

		var time_to_contact := obstacle.time_to_contact_s()
		var half_air_time := Keepy.JUMP_VELOCITY / Keepy.GRAVITY
		if time_to_contact <= half_air_time and _keepy.is_on_floor():
			_jump_dodge_score_before = GameState.jump_dodge_score
			_keepy.velocity.y = Keepy.JUMP_VELOCITY
			_jump_commanded = true
			_jump_commanded_t = _t
			_check_deadline = _t + 2.0 * half_air_time + SURVIVAL_HOLD_S
			print("  jumped at t=%.2fs, time-to-contact was %.3fs (target %.3fs)" % [_t, time_to_contact, half_air_time])


## Whether the hazard this jump was timed against is ACTUALLY at the player
## plane right now -- i.e. whether it is a plausible cause of the death
## being attributed to it.
##
## WHY: phase 2 holds for SURVIVAL_HOLD_S after the jump lands, to be sure
## the survival is real. Keepy spends that hold ON THE GROUND, and this
## probe deliberately leaves every OTHER JUMP obstacle alive (it neuters only the
## other types). A second one arriving inside the hold kills a stationary
## bot -- which is not a bug, it is what this probe's own earlier phase
## asserts must happen. Blaming the jumped hazard for that death is a false
## red, and a seed-dependent one.
##
## Measured on this tree before the guard: seeds 1 and 314159 of 20 failed
## this way. Instrumented on seed 1, the killer's segment key was
## 105277031797 while the jump target was 104689829729 -- a different,
## already-cleared hazard, 1.6s after a jump whose own target was behind
## the player.
##
## Keyed on the SEGMENT instance id, the handle _jump_target_key already
## records, because pooled Obstacle nodes reuse their ids across spawns and
## only the owning segment identifies the row.
func _target_is_at_the_player() -> bool:
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		if segment.get_instance_id() != _jump_target_key:
			continue
		for child in segment.get_children():
			if not (child is Obstacle) or not child.visible:
				continue
			return absf(child.global_position.z) <= Obstacle.RISK_PROXIMITY_Z
	return false
