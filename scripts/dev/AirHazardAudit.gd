extends Node
## Dev-only diagnostic for the AIR_ENEMY obstacle (see Obstacle.gd
## Type.AIR_ENEMY): empirically verifies its safety contract instead of
## trusting the height math alone.
##
## REWRITTEN for the mobile/landing AIR_ENEMY (difficulty+variety batch,
## playtest: "too easy, had to lose on purpose"). The ORIGINAL version of
## this probe asserted the OPPOSITE of what it asserts now: a jump timed
## to land Keepy's apex exactly at the moment of contact HAD to be
## lethal, and a straight-running, never-jumping Keepy HAD to survive
## forever. Both assertions are now FALSE BY DESIGN, and there is no way
## to keep them both true simultaneously -- read on for why, since this
## is the kind of thing a probe rewrite must justify, not just silently
## flip.
##
## Collision in this game is only ever tested in a NARROW window around
## the instant an obstacle's global Z crosses the player's fixed Z=0
## (Keepy never moves on Z -- see Keepy.gd / TrackManager.gd). Whatever
## height state AIR_ENEMY happens to be in AT THAT ONE INSTANT is the
## ONLY state that can ever matter for a real collision -- there is no
## meaningful "earlier pass" the way there might be in a game where the
## player also moves through Z. Obstacle._process_air_enemy schedules
## landing to complete a full ENEMY_REACTION_WINDOW_S BEFORE that instant
## (the same reaction budget the ground ENEMY's own hard lock guarantees,
## per the task's explicit ask) -- which means AIR_ENEMY is ALWAYS
## already landed by the time the one real collision test happens. A
## jump timed for that instant therefore ALWAYS lands on an already-
## grounded, JUMPABLE hazard (same Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT
## contract as ENEMY/JUMP) -- exactly the opposite of the old contract,
## where the hazard was airborne and jump-punishing at that same instant.
## There is no schedule that makes AIR_ENEMY BOTH "always landed with a
## guaranteed reaction window before contact" (what chantier 3 explicitly
## asks for: "il se comporte comme un ennemi au sol") AND "still airborne
## and jump-lethal exactly at contact" (the old contract) -- picking a
## smaller landing margin only trades one for the other, it cannot buy
## both. The task's explicit design goal (a mobile hazard that becomes a
## real, dodgeable ground threat) is the one kept.
##
##   PHASE 1 (IGNORING IT IS NOW LETHAL) -- boots the real Game.tscn with
##   REAL collision. No input is ever injected, so Keepy runs in a
##   straight line on the center lane and NEVER jumps, NEVER switches --
##   which means it would ALSO run straight into any DODGE/ENEMY obstacle
##   that happens to land on that lane, so those (and JUMP, which this
##   probe also never clears) are neutered on sight, isolating the result
##   to AIR_ENEMY specifically. Asserts the run DOES eventually end
##   (GAME_OVER) once a landed AIR_ENEMY reaches the player's lane --
##   this is the INVERSE of the old assertion, and correctly so: a landed
##   AIR_ENEMY left un-dodged must be exactly as lethal as a locked-on
##   ground ENEMY.
##
##   PHASE 2 (A WELL-TIMED JUMP CLEARS THE LANDED HAZARD) -- a fresh run
##   of the same scene, this time watching for the next AIR_ENEMY and
##   commanding a jump (directly setting Keepy.velocity.y, bypassing the
##   Input singleton which has nothing to inject from in --headless)
##   timed to land Keepy's apex exactly as it reaches the player -- the
##   SAME timing technique the old phase 2 used, kept unchanged, only the
##   expected OUTCOME is flipped. Asserts the run SURVIVES the pass
##   (state stays PLAYING) -- proving the jumpable-once-landed contract
##   is actually reachable and correct, not just "never reached" by
##   accident of some other obstacle ending the run first.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/AirHazardAudit.tscn

const SIM_TIMEOUT_S: float = 300.0 # safety cap while waiting for the next AIR_ENEMY encounter
const MIN_ENCOUNTERS_REQUIRED: int = 5 # else the phase's result would not be meaningful
const SURVIVAL_HOLD_S: float = 1.0 # how long phase 2 must stay PLAYING after the pass to count as a real survival, not a lucky race

## AIR_ENEMY AND NOTHING ELSE -- and that narrowness is the honest answer
## here, not a shortcut. See ProbeCoverage.gd for what the ledger is for.
##
## Every other hazard is switched off ON SIGHT by _scan_air_enemies
## (`obstacle.set_deferred("monitoring", false)`), deliberately, so that a
## death is always attributable to the thing this probe tests. They still
## spawn and still cross the player plane, so the ledger WOULD happily
## count them as "presented" -- and that count would be a lie of exactly
## the kind this file exists to prevent: present on the track, and
## incapable of affecting anything measured. Requiring them would also
## fail the probe for a reason that is not a defect, which
## ProbeCoverage.exempt_phase's own doc names as the mirror-image mistake.
##
## What IS worth gating, and what this probe never proved before, is that
## an AIR_ENEMY actually reached the player in each phase. Phase 1's whole
## claim is "ignoring one is lethal" and phase 2's is "jumping one is
## survivable"; if none arrived, both claims are vacuous. Phase 1 already
## fails on its own timeout, but phase 2 could previously reach its
## survival deadline without the ledger ever confirming the hazard came.
const REQUIRED_COVERAGE: Array[int] = [ProbeCoverage.Mechanic.AIR_ENEMY]

var _coverage := ProbeCoverage.new()

var _phase: int = 1
var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0
var _encounters: int = 0

# Phase 2 state
var _jump_target_key: int = -1 # segment instance id of the obstacle we're timing the jump against
var _jump_commanded: bool = false
var _jump_commanded_t: float = 0.0
var _survival_check_deadline: float = -1.0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "AirHazardAudit")
	# Must run BEFORE Game.tscn is instantiated in _start_game() below --
	# see DevSeed.gd.
	#
	# THIS CALL WAS MISSING, and its absence is the whole of finding F6 in
	# docs/PROBE_AUDIT.md ("AirHazardAudit is non-deterministic under
	# --seed"). It was not non-deterministic under --seed; it never read
	# --seed at all. DevSeed.apply() is what consumes the flag, no probe
	# gets it for free, and this one never called it -- so every invocation
	# drew a fresh RNG stream and produced a genuinely different run, which
	# is exactly what an unseeded probe is supposed to do. The recorded
	# symptom (same seed, ~1 failure in 11 on origin/main, 2 in 5 on the
	# branch, byte-identical inputs) is sampling variance in a probe that
	# was exploratory the whole time, and the recorded observation that
	# `git diff origin/main` was empty for this file and everything it
	# loads was correct and pointed the right way: nothing in the inputs
	# differed, because the seed was never among the inputs.
	#
	# The hypothesis recorded alongside F6 -- a startup-ordering race
	# between _process and the first _physics_process moving the liftoff
	# frame inside a narrow clearance window -- is not what was happening.
	# It was explicitly labelled a hypothesis rather than a diagnosis; it
	# is now measured, and it is not the cause. The 0.330-0.345s spread of
	# liftoff times it rested on is simply where an unseeded run's
	# AIR_ENEMY happened to be.
	var seeded := DevSeed.apply()
	print("=== AIR HAZARD AUDIT ===")
	print("rng    : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("phase 1: ignoring a landed AIR_ENEMY (never jump, never switch) must eventually be lethal")
	_coverage.begin_phase("phase 1")
	_start_game()

func _start_game() -> void:
	var restarting := _game != null
	if _game:
		_game.queue_free()
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	# Pooled segments in the NEW game reuse instance ids freely; without
	# this the ledger could read a fresh segment as a crossing of the old
	# one. See ProbeCoverage.run_restarted.
	if restarting:
		_coverage.run_restarted()
	# Collision is INTENTIONALLY left at its real, shipped value here --
	# see the header. Only the Input-driven jump/lane-switch is absent (no
	# injected events), which is exactly what phase 1 needs to test.
	_jump_target_key = -1
	_jump_commanded = false
	_survival_check_deadline = -1.0

func _physics_process(delta: float) -> void:
	# Before the phase body, which can restart the game or quit outright --
	# observing a torn-down track would record nothing useful and could read
	# a recycled segment as a crossing.
	_coverage.observe(_track, _keepy)
	if _phase == 1:
		_run_phase_1(delta)
	else:
		_run_phase_2(delta)

func _run_phase_1(delta: float) -> void:
	_t += delta
	_scan_air_enemies()

	if GameState.state == GameState.State.GAME_OVER:
		_encounters += 1
		if _encounters >= MIN_ENCOUNTERS_REQUIRED:
			print("PHASE 1 PASSED: died to a landed, un-dodged AIR_ENEMY (%d/%d encounters confirmed lethal)." % [_encounters, MIN_ENCOUNTERS_REQUIRED])
			print("")
			print("phase 2: a well-timed jump over a landed AIR_ENEMY must survive")
			_phase = 2
			_t = 0.0
			_encounters = 0
			_coverage.begin_phase("phase 2")
			_start_game()
			return
		print("phase 1: encounter %d/%d confirmed lethal, restarting for another sample" % [_encounters, MIN_ENCOUNTERS_REQUIRED])
		_t = 0.0
		_start_game()
		return

	if _t >= SIM_TIMEOUT_S:
		push_error("PHASE 1 FAILED: no AIR_ENEMY killed a straight-running, never-jumping Keepy within %.1fs (%d/%d encounters). A landed AIR_ENEMY should be exactly as lethal as a locked-on ground ENEMY when ignored -- this hitbox may not be reaching the grounded capsule." % [SIM_TIMEOUT_S, _encounters, MIN_ENCOUNTERS_REQUIRED])
		get_tree().quit(1)

func _run_phase_2(delta: float) -> void:
	_t += delta

	if GameState.state == GameState.State.GAME_OVER:
		if _jump_commanded and _target_is_at_the_player():
			push_error("PHASE 2 FAILED: died %.3fs after a jump timed to clear a landed AIR_ENEMY, WITH THAT SAME HAZARD at the player plane -- the once-landed hazard should be jumpable exactly like ENEMY/JUMP, this hitbox may still be lethal to a well-timed jump." % [_t - _jump_commanded_t])
			get_tree().quit(1)
		elif _jump_commanded:
			# Died in the survival hold, but NOT to the hazard under test --
			# see _target_is_at_the_player. Inconclusive, exactly like a
			# death before the jump.
			print("phase 2: died %.3fs after the jump but to a DIFFERENT hazard (the jumped one was already behind) -- retrying" % [_t - _jump_commanded_t])
			_jump_target_key = -1
			_jump_commanded = false
			_survival_check_deadline = -1.0
			_t = 0.0
			_start_game()
		else:
			# Died some other way (e.g. an unrelated obstacle spawned on
			# the center lane first) -- not a failure of THIS check, just
			# an inconclusive run. Restart phase 2 fresh rather than
			# report a false pass or fail.
			print("phase 2: died before the timed jump (unrelated obstacle) -- retrying")
			_jump_target_key = -1
			_jump_commanded = false
			_survival_check_deadline = -1.0
			_t = 0.0
			_start_game()
		return

	if _jump_commanded and _survival_check_deadline >= 0.0 and _t >= _survival_check_deadline:
		_encounters += 1
		print("  survived the timed jump (encounter %d/%d)" % [_encounters, MIN_ENCOUNTERS_REQUIRED])
		if _encounters >= MIN_ENCOUNTERS_REQUIRED:
			print("PHASE 2 PASSED: %d/%d timed jumps over a landed AIR_ENEMY all survived -- the landed hazard is safely jumpable, as designed." % [_encounters, MIN_ENCOUNTERS_REQUIRED])
			print("")
			_coverage.report(REQUIRED_COVERAGE)
			# COVERAGE LAST, and it still gates: both phases above are
			# written entirely around AIR_ENEMY arriving, so a pass that the
			# ledger cannot corroborate means the two phases agreed about
			# something neither of them saw.
			var gaps := _coverage.verify(REQUIRED_COVERAGE)
			if not gaps.is_empty():
				for gap in gaps:
					push_error("AIR HAZARD AUDIT INCONCLUSIVE: %s." % gap)
				get_tree().quit(1)
				return
			get_tree().quit(0)
			return
		_jump_target_key = -1
		_jump_commanded = false
		_survival_check_deadline = -1.0
		_t = 0.0
		_start_game()
		return

	if _t >= SIM_TIMEOUT_S:
		push_error("PHASE 2 FAILED: no AIR_ENEMY reached the player within %.1fs, or the timed jump was never armed -- the hitbox may be unreachable." % SIM_TIMEOUT_S)
		get_tree().quit(1)
		return

	_scan_air_enemies()

## Scans every live TrackSegment for an obstacle. Non-AIR_ENEMY obstacles
## are neutered on sight (see the PHASE 1 header comment) so only
## AIR_ENEMY can ever end the run in either phase -- a death is therefore
## always attributable to the thing this probe is actually testing. Arms
## a timed jump the frame a fresh AIR_ENEMY is first seen (locking onto
## ITS segment id so a later recycle of the same pooled node is never
## mistaken for the same encounter), then fires the jump when its
## time-to-contact matches Keepy's own jump arc's half-duration -- long
## enough in the air that its capsule is guaranteed to still be elevated
## (well above Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT) when the obstacle's Z
## reaches the player, exactly as it would need to be to clear a landed
## ENEMY or JUMP obstacle. Phase 1 never calls into the jump-arming branch
## (obstacle.obstacle_type != AIR_ENEMY is the only path phase 1's
## neutering takes; AIR_ENEMY itself is left alone and simply walked
## into).
func _scan_air_enemies() -> void:
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
			# Only drop the target while it was never actually jumped
			# into -- once a jump HAS been commanded (_jump_commanded),
			# the obstacle recycling/going invisible shortly after it
			# passes the player is EXPECTED (contact already happened,
			# see the class doc on why collision only ever tests once)
			# and must NOT cancel the pending survival check below: that
			# check is what actually decides pass/fail, and it needs
			# _jump_commanded to stay true until its own deadline fires.
			if _jump_target_key == key and not _jump_commanded:
				_jump_target_key = -1
			continue
		if obstacle.obstacle_type != Obstacle.Type.AIR_ENEMY:
			# Deferred, not a direct assignment: Godot forbids toggling
			# Area3D.monitoring from inside an in-flight body_entered/
			# body_exited signal dispatch, which this scan can race with
			# on the same physics tick a DIFFERENT obstacle registers a
			# contact.
			obstacle.set_deferred("monitoring", false)
			if _jump_target_key == key and not _jump_commanded:
				_jump_target_key = -1
			continue

		if _phase != 2:
			continue

		var z: float = obstacle.global_position.z

		if _jump_target_key == -1 and not _jump_commanded:
			_jump_target_key = key

		if _jump_target_key == key and not _jump_commanded:
			var time_to_contact := -z / GameState.current_speed
			# Half of Keepy's total air time (2 * JUMP_VELOCITY / GRAVITY)
			# is the time from liftoff to apex -- jumping this long before
			# contact lands the apex right on top of the obstacle's
			# arrival, well above JUMPABLE_OBSTACLE_TOP_HEIGHT.
			var half_air_time := Keepy.JUMP_VELOCITY / Keepy.GRAVITY
			if time_to_contact <= half_air_time and _keepy.is_on_floor():
				_keepy.velocity.y = Keepy.JUMP_VELOCITY
				_jump_commanded = true
				_jump_commanded_t = _t
				# Confirm survival a little after the FULL jump arc (not
				# just past contact) so a late-arriving second hazard on
				# the same lane can't be mistaken for this one surviving.
				_survival_check_deadline = _t + 2.0 * half_air_time + SURVIVAL_HOLD_S
				print("  jumped at t=%.2fs, time-to-contact was %.3fs (target %.3fs)" % [_t, time_to_contact, half_air_time])


## Whether the hazard this jump was timed against is ACTUALLY at the player
## plane right now -- i.e. whether it is a plausible cause of the death
## being attributed to it.
##
## WHY: phase 2 holds for SURVIVAL_HOLD_S after the jump lands, to be sure
## the survival is real. Keepy spends that hold ON THE GROUND, and this
## probe deliberately leaves every OTHER AIR_ENEMY alive (it neuters only the
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
