extends Node
## Dev-only: the death model's contract, asserted directly rather than
## inferred from a bot's luck.
##
## =====================================================================
## WHY THIS EXISTS, AND WHY IT IS NOT A SECTION OF StrikeAudit
##
## StrikeAudit drives four skill profiles through thousands of simulated
## seconds and reports WHAT KILLED THEM. That is the right instrument for
## "does the death model produce the intended experience", and it is what
## caught this rebalance's real consequences on capture share and run
## length. It is the WRONG instrument for "is a CHARGER contact still
## exactly one hit", for a reason that has already produced five false
## greens in this folder (see ProbeCoverage.gd): a bot only reaches a given
## state BY CHANCE. A seed where no bot ever touches a CHARGER leaves
## StrikeAudit silent about CHARGERs and still passing.
##
## So this probe asserts the CONTRACT itself, at the one signal that
## applies it, with no bot, no track and no RNG in the path:
##
##   1. CLASSIFICATION -- is_fatal is true for CHARGER and false for the
##      other five. Enumerated over Obstacle.Type.values() rather than over
##      a list written here, so a SEVENTH type added later cannot slip
##      through unclassified: it would have to be added to this probe's own
##      expectation before it could pass.
##   2. CHARGER IS ONE HIT. From full resistance, a single contact ends the
##      run, as DeathCause.COLLISION, having credited no strike at all.
##   3. THE LADDER. Every other type costs exactly CONTACT_COST_HALF: the
##      run survives every contact up to STRIKE_CAPACITY_HALF - 1 and ends
##      on exactly the capacity-th, as DeathCause.PURSUER -- checked for
##      EACH of the five, not for a representative one.
##   4. The invulnerability window still swallows a contact taken too soon.
##   5. Each recovery path gives back exactly ONE half-unit, not a full
##      strike -- the constant that decides whether recovery outpaces
##      damage (see GameState.COMBO_TO_CLEAR_STRIKE).
##
## =====================================================================
## HERMETIC BY CONSTRUCTION
##
## It instantiates Keepy.tscn and Obstacle.tscn ALONE -- no Game.tscn, no
## TrackManager, no pursuer, no HUD. Nothing else in the tree can call
## register_strike() or end_run(), so every state transition observed here
## was caused by this probe's own contact. Both nodes are process-disabled
## and the obstacle is parked far off-origin, so the physics server cannot
## fire a contact of its own either.
##
## Contact is delivered by EMITTING Obstacle's own `body_entered`, which is
## the signal the physics server itself fires and which Obstacle._ready()
## has already connected to _on_body_entered. That is the real door, one
## level above reaching into a private method -- same discipline
## StrikeContrastAudit.gd and StrikeFatalContrastAudit.gd insist on, and
## for the same reason: a shortcut past the real call site tests a state
## the game can produce rather than the path it produces it by.
##
## Run time is advanced by writing GameState.run_time_s directly between
## contacts, exactly as StrikeFatalContrastAudit does and for the reason it
## documents: advance_time() would also drain the pursuer lead and turn the
## dark/combo clocks, none of which this probe has any reason to touch. The
## ONE place it does use advance_time() is the recovery-by-time check,
## because there the clock IS the thing under test.
##
## Excluded from the web export (export_presets.cfg excludes scripts/dev/*),
## never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/DeathModelAudit.tscn

## The one type that ends a run on contact. Written here as this probe's
## own expectation rather than read from Obstacle.is_fatal -- a test that
## asks the implementation what the answer should be cannot fail.
const EXPECTED_FATAL: Array[int] = [Obstacle.Type.CHARGER]

## Cap on the recovery-by-time wait, in simulated seconds. Comfortably past
## TIME_TO_CLEAR_STRIKE_S so a real clear is never cut short, and finite so
## a broken recovery path reports INCONCLUSIVE instead of spinning.
const RECOVERY_WAIT_CAP_S: float = 60.0

var _keepy: Keepy
var _obstacle: Obstacle
var _failures: int = 0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "DeathModelAudit")
	var seeded := DevSeed.apply()
	print("=== DEATH MODEL AUDIT ===")
	print("rng                : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("                     (this probe draws no RNG of its own -- the seed only")
	print("                      pins start_run's dark-variant roll, which it never reads)")
	print("capacity           : %d half-units (%d contacts), %d per contact" % [
		GameState.STRIKE_CAPACITY_HALF, GameState.STRIKE_CAPACITY_HALF,
		GameState.CONTACT_COST_HALF])
	print("invulnerable       : %.1fs after a credited contact" % GameState.STRIKE_INVULNERABLE_S)
	print("recovery           : %.1fs clean, or a combo reaching a multiple of %d" % [
		GameState.TIME_TO_CLEAR_STRIKE_S, GameState.COMBO_TO_CLEAR_STRIKE])
	print("")

	_keepy = load("res://scenes/Keepy.tscn").instantiate()
	_obstacle = load("res://scenes/Obstacle.tscn").instantiate()
	add_child(_keepy)
	add_child(_obstacle)
	# Nothing but this probe may drive either node -- see the class doc.
	_keepy.process_mode = Node.PROCESS_MODE_DISABLED
	_obstacle.process_mode = Node.PROCESS_MODE_DISABLED
	_obstacle.position = Vector3(0.0, 0.0, 1000.0)
	# The pursuer does not exist in this tree, but advance_time() still
	# drains its lead and can end the run from under the recovery check.
	GameState.pursuer_enabled = false

	_phase_classification()
	_phase_charger_is_one_hit()
	_phase_ladder()
	_phase_invulnerability()
	_phase_recovery()
	_report()

## Delivers one contact through Obstacle's own body_entered signal.
func _contact(type: int) -> void:
	_obstacle.obstacle_type = type
	_obstacle.body_entered.emit(_keepy)

## Clears the invulnerability window without turning any other clock.
func _skip_invulnerability() -> void:
	GameState.run_time_s += GameState.STRIKE_INVULNERABLE_S + 0.01

func _fail(message: String) -> void:
	_failures += 1
	print("  FAIL  %s" % message)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  OK    %s" % message)
	else:
		_fail(message)

# --- 1. classification ------------------------------------------------
## Enumerates Obstacle.Type.values() rather than a list of six written
## here: a type added later arrives in this loop automatically and fails
## until someone classifies it on purpose.
func _phase_classification() -> void:
	print("--- PHASE 1: is_fatal, over every declared Obstacle.Type ---")
	for type in Obstacle.Type.values():
		var expected: bool = type in EXPECTED_FATAL
		var actual := Obstacle.is_fatal(type)
		if actual == expected:
			print("  OK    %-10s is_fatal=%s" % [_type_name(type), actual])
		else:
			_fail("%s is_fatal=%s, expected %s" % [_type_name(type), actual, expected])
	print("")

# --- 2. CHARGER is one hit -------------------------------------------
func _phase_charger_is_one_hit() -> void:
	print("--- PHASE 2: a CHARGER ends the run in ONE contact ---")
	GameState.start_run()
	_check(GameState.strikes_used_half == 0,
		"a fresh run starts at 0 half-units (got %d)" % GameState.strikes_used_half)
	_contact(Obstacle.Type.CHARGER)
	_check(GameState.state != GameState.State.PLAYING,
		"the run ended on the first CHARGER contact (state %s)" % GameState.state)
	_check(GameState.death_cause == GameState.DeathCause.COLLISION,
		"it is reported as COLLISION, not as being run down")
	_check(GameState.strikes_used_half == 0,
		"it credited no strike at all (got %d half-units)" % GameState.strikes_used_half)
	print("")

# --- 3. the half-strike ladder ---------------------------------------
## Run for EACH non-fatal type rather than for a representative one: the
## whole content of this batch is that four types changed sides, and a
## check that only exercises DODGE would pass just as happily if ENEMY had
## been left fatal.
func _phase_ladder() -> void:
	print("--- PHASE 3: every non-CHARGER type costs exactly %d half-unit(s) ---" % GameState.CONTACT_COST_HALF)
	for type in Obstacle.Type.values():
		if type in EXPECTED_FATAL:
			continue
		var name := _type_name(type)
		GameState.start_run()
		var survived_all := true
		var ended_early := false
		for contact_index in range(1, GameState.STRIKE_CAPACITY_HALF + 1):
			_contact(type)
			var expected_half: int = contact_index * GameState.CONTACT_COST_HALF
			if contact_index < GameState.STRIKE_CAPACITY_HALF:
				if GameState.state != GameState.State.PLAYING:
					_fail("%s: the run ended on contact %d of %d -- it must survive up to %d" % [
						name, contact_index, GameState.STRIKE_CAPACITY_HALF,
						GameState.STRIKE_CAPACITY_HALF - 1])
					ended_early = true
					break
				if GameState.strikes_used_half != expected_half:
					_fail("%s: contact %d left %d half-units, expected %d" % [
						name, contact_index, GameState.strikes_used_half, expected_half])
					survived_all = false
			else:
				if GameState.state == GameState.State.PLAYING:
					_fail("%s: the run was still going after %d contacts -- capacity is %d" % [
						name, contact_index, GameState.STRIKE_CAPACITY_HALF])
					survived_all = false
				elif GameState.death_cause != GameState.DeathCause.PURSUER:
					_fail("%s: the capacity-th contact ended the run as %s, not as being run down" % [
						name, GameState.death_cause])
					survived_all = false
			_skip_invulnerability()
		if survived_all and not ended_early:
			print("  OK    %-10s survived %d contacts, caught on contact %d (PURSUER)" % [
				name, GameState.STRIKE_CAPACITY_HALF - 1, GameState.STRIKE_CAPACITY_HALF])
	print("")

# --- 4. invulnerability ----------------------------------------------
func _phase_invulnerability() -> void:
	print("--- PHASE 4: a contact inside the invulnerability window is swallowed ---")
	GameState.start_run()
	_contact(Obstacle.Type.DODGE)
	var after_first: int = GameState.strikes_used_half
	# Deliberately NO _skip_invulnerability() here -- that is the point.
	_contact(Obstacle.Type.DODGE)
	_check(GameState.strikes_used_half == after_first,
		"a second contact %.1fs early cost nothing (still %d half-units)" % [
			GameState.STRIKE_INVULNERABLE_S, GameState.strikes_used_half])
	print("")

# --- 5. recovery ------------------------------------------------------
## Both paths give back ONE half-unit, i.e. exactly what one contact cost.
## That symmetry is the whole reason this phase exists: if a recovery
## returned a FULL strike while a contact cost half of one, recovery would
## outpace damage two to one, and with COMBO_TO_CLEAR_STRIKE at 3 an active
## player's strike budget would effectively never deplete.
func _phase_recovery() -> void:
	print("--- PHASE 5: each recovery path gives back exactly 1 half-unit ---")

	# BY TIME. advance_time() is the real driver of _update_strikes, so this
	# one leg uses it rather than writing run_time_s -- the clock IS the
	# thing under test here.
	GameState.start_run()
	_contact(Obstacle.Type.DODGE)
	_skip_invulnerability()
	_contact(Obstacle.Type.DODGE)
	var before_time: int = GameState.strikes_used_half
	var waited := 0.0
	while GameState.strikes_used_half == before_time and waited < RECOVERY_WAIT_CAP_S:
		GameState.advance_time(1.0 / 60.0)
		waited += 1.0 / 60.0
	if waited >= RECOVERY_WAIT_CAP_S:
		_fail("no strike came back within %.0fs of clean play -- the time path is dead at %.1fs" % [
			RECOVERY_WAIT_CAP_S, GameState.TIME_TO_CLEAR_STRIKE_S])
	else:
		_check(GameState.strikes_used_half == before_time - 1,
			"time gave back 1 half-unit after %.1fs (%d -> %d)" % [
				waited, before_time, GameState.strikes_used_half])

	# BY COMBO, through the same door the game uses.
	GameState.start_run()
	_contact(Obstacle.Type.DODGE)
	_skip_invulnerability()
	_contact(Obstacle.Type.DODGE)
	var before_combo: int = GameState.strikes_used_half
	for i in GameState.COMBO_TO_CLEAR_STRIKE:
		GameState.register_risk_event(GameState.RiskEvent.NEAR_MISS)
	_check(GameState.strikes_used_half == before_combo - 1,
		"a %d-event chain gave back 1 half-unit (%d -> %d)" % [
			GameState.COMBO_TO_CLEAR_STRIKE, before_combo, GameState.strikes_used_half])
	print("")

func _report() -> void:
	if _failures > 0:
		push_error("DEATH MODEL AUDIT FAILED: %d check(s) did not hold." % _failures)
		get_tree().quit(1)
		return
	print("PASSED: CHARGER alone is fatal and ends a run in one contact; each of the")
	print("        other %d types costs %d half-unit, is survived %d times and catches the" % [
		Obstacle.Type.values().size() - EXPECTED_FATAL.size(),
		GameState.CONTACT_COST_HALF, GameState.STRIKE_CAPACITY_HALF - 1])
	print("        player on the %dth; the invulnerability window still holds; and both" % GameState.STRIKE_CAPACITY_HALF)
	print("        recovery paths give back one half-unit, never a whole strike.")
	get_tree().quit(0)

func _type_name(type: int) -> String:
	match type:
		Obstacle.Type.DODGE: return "DODGE"
		Obstacle.Type.JUMP: return "JUMP"
		Obstacle.Type.ENEMY: return "ENEMY"
		Obstacle.Type.AIR_ENEMY: return "AIR_ENEMY"
		Obstacle.Type.CHARGER: return "CHARGER"
		Obstacle.Type.STOMPER: return "STOMPER"
		_: return "TYPE_%d" % type
