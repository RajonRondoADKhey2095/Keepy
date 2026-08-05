extends Node
## Dev-only diagnostic for the AIR_ENEMY obstacle (see Obstacle.gd
## Type.AIR_ENEMY): empirically verifies the two halves of its safety
## contract instead of trusting the height math alone.
##
##   PHASE 1 (SURVIVAL) -- boots the real Game.tscn with REAL collision
##   (unlike PacingAudit.gd/EnemyLaneAudit.gd, Keepy's collision_layer is
##   NOT neutered here: this probe needs death to be possible so "it
##   never happens while just running" is an actual result, not a
##   tautology). No input is ever injected, so Keepy runs in a straight
##   line on the center lane and NEVER jumps -- which means it would ALSO
##   run straight into any DODGE/JUMP/ENEMY obstacle that happens to land
##   on that lane (JUMP requires a jump, DODGE/ENEMY require a lane
##   switch, neither of which this probe ever does). That is not a defect
##   in AIR_ENEMY, it is just this probe deliberately not playing the
##   other three obstacles at all -- so their Area3D.monitoring is forced
##   off every frame (deferred, per Godot's own guidance, never mid
##   signal-dispatch) the instant they spawn, isolating the survival
##   result to AIR_ENEMY specifically, which is the only thing this phase
##   is measuring. Runs long enough to guarantee multiple real AIR_ENEMY
##   passes (tracked explicitly, so an empty run can never be mistaken
##   for a safe one) and asserts GameState.state stays PLAYING throughout.
##
##   PHASE 2 (LETHALITY) -- a fresh run of the same scene, this time
##   watching for the next AIR_ENEMY obstacle and commanding a jump
##   (directly setting Keepy.velocity.y, bypassing the Input singleton
##   which has nothing to inject from in --headless) timed to land Keepy
##   in the air exactly as it reaches the player. Asserts the run DOES
##   end (GameState.state becomes GAME_OVER) shortly after -- proving the
##   hitbox is actually reachable, not just "never reached" by accident
##   of being placed too high/low to ever matter.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/AirHazardAudit.tscn

const SURVIVAL_SIM_SECONDS: float = 2400.0 # long enough for several real AIR_ENEMY passes
const MIN_AIR_ENEMY_PASSES_REQUIRED: int = 5 # else the survival result would be meaningless
const LETHALITY_TIMEOUT_S: float = 300.0 # safety cap while waiting for the first AIR_ENEMY

var _phase: int = 1
var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0
var _prev_z: Dictionary = {} # segment instance id -> previous obstacle Z
var _air_enemy_passes: int = 0

# Phase 2 state
var _jump_target_key: int = -1 # segment instance id of the obstacle we're timing the jump against
var _jump_commanded: bool = false
var _jump_commanded_t: float = 0.0

func _ready() -> void:
	print("=== AIR HAZARD AUDIT ===")
	print("phase 1: survival -- run straight, never jump, must never die to an AIR_ENEMY")
	_start_game()

func _start_game() -> void:
	if _game:
		_game.queue_free()
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	# Collision is INTENTIONALLY left at its real, shipped value here --
	# see the header. Only the Input-driven jump is absent (no injected
	# events), which is exactly what phase 1 needs to test.
	_prev_z.clear()

func _physics_process(delta: float) -> void:
	if _phase == 1:
		_run_phase_1(delta)
	else:
		_run_phase_2(delta)

func _run_phase_1(delta: float) -> void:
	_t += delta
	_scan_air_enemies(true)

	if GameState.state == GameState.State.GAME_OVER:
		push_error("PHASE 1 FAILED: Keepy died at t=%.2fs without ever jumping (%d AIR_ENEMY passes seen so far, all other obstacle types were neutered). The AIR_ENEMY hitbox reaches the grounded capsule -- this is a real bug." % [_t, _air_enemy_passes])
		get_tree().quit(1)
		return

	if _t >= SURVIVAL_SIM_SECONDS:
		if _air_enemy_passes < MIN_AIR_ENEMY_PASSES_REQUIRED:
			push_error("PHASE 1 INCONCLUSIVE: only %d AIR_ENEMY passes in %.1fs (wanted >= %d) -- survival result is not meaningful, re-run with a longer SURVIVAL_SIM_SECONDS." % [_air_enemy_passes, _t, MIN_AIR_ENEMY_PASSES_REQUIRED])
			get_tree().quit(1)
			return
		print("PHASE 1 PASSED: survived %.1fs, %d AIR_ENEMY passes, never jumped, never died." % [_t, _air_enemy_passes])
		print("")
		print("phase 2: lethality -- time a jump into the next AIR_ENEMY, must die")
		_phase = 2
		_t = 0.0
		_air_enemy_passes = 0
		_start_game()

func _run_phase_2(delta: float) -> void:
	_t += delta

	if GameState.state == GameState.State.GAME_OVER:
		if _jump_commanded:
			print("PHASE 2 PASSED: died %.3fs after the timed jump into an AIR_ENEMY -- hitbox is reachable and lethal, as designed." % [_t - _jump_commanded_t])
			get_tree().quit(0)
		else:
			# Died some other way (e.g. an unrelated obstacle spawned on
			# the center lane first) -- not a failure of THIS check, just
			# an inconclusive run. Restart phase 2 fresh rather than
			# report a false pass or fail.
			print("phase 2: died before the timed jump (unrelated obstacle) -- retrying")
			_jump_target_key = -1
			_jump_commanded = false
			_t = 0.0
			_start_game()
		return

	if _t >= LETHALITY_TIMEOUT_S:
		push_error("PHASE 2 FAILED: no AIR_ENEMY reached the player within %.1fs, or the timed jump did not result in death -- the hitbox may be unreachable." % LETHALITY_TIMEOUT_S)
		get_tree().quit(1)
		return

	_scan_air_enemies(false)

## Scans every live TrackSegment for an obstacle. Non-AIR_ENEMY obstacles
## are neutered on sight (see the PHASE 1 header comment) so only
## AIR_ENEMY can ever end the run in either phase -- a death is therefore
## always attributable to the thing this probe is actually testing. In
## phase 1, counts real AIR_ENEMY passes (Z crossing the player plane) as
## proof the survival result is meaningful. In phase 2, additionally arms
## a timed jump the frame a fresh AIR_ENEMY is first seen (locking onto
## ITS segment id so a later recycle of the same pooled node is never
## mistaken for the same encounter), then fires the jump when its
## time-to-contact matches Keepy's own jump arc duration -- long enough
## in the air that its capsule is guaranteed to still be elevated when
## the obstacle's Z reaches the player.
func _scan_air_enemies(track_passes: bool) -> void:
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
			if _jump_target_key == key:
				_jump_target_key = -1
				_jump_commanded = false
			continue
		if obstacle.obstacle_type != Obstacle.Type.AIR_ENEMY:
			# Deferred, not a direct assignment: Godot forbids toggling
			# Area3D.monitoring from inside an in-flight body_entered/
			# body_exited signal dispatch, which this scan can race with
			# on the same physics tick a DIFFERENT obstacle registers a
			# contact.
			obstacle.set_deferred("monitoring", false)
			_prev_z.erase(key)
			if _jump_target_key == key:
				_jump_target_key = -1
				_jump_commanded = false
			continue

		var z: float = obstacle.global_position.z

		if track_passes and _prev_z.has(key):
			var prev: float = _prev_z[key]
			if prev < 0.0 and z >= 0.0:
				_air_enemy_passes += 1
		_prev_z[key] = z

		if not track_passes and _jump_target_key == -1 and not _jump_commanded:
			_jump_target_key = key

		if not track_passes and _jump_target_key == key and not _jump_commanded:
			var time_to_contact := -z / GameState.current_speed
			# Half of Keepy's total air time (2 * JUMP_VELOCITY / GRAVITY)
			# is the time from liftoff to apex -- jumping this long before
			# contact lands the apex (and the AIR_ENEMY-height hitbox
			# overlap around it) right on top of the obstacle's arrival.
			var half_air_time := Keepy.JUMP_VELOCITY / Keepy.GRAVITY
			if time_to_contact <= half_air_time and _keepy.is_on_floor():
				_keepy.velocity.y = Keepy.JUMP_VELOCITY
				_jump_commanded = true
				_jump_commanded_t = _t
				print("  jumped at t=%.2fs, time-to-contact was %.3fs (target %.3fs)" % [_t, time_to_contact, half_air_time])
