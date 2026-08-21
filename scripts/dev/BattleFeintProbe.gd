extends Node
## Dev-only: gates the lot-4 feint -- the one mechanic in Keepy Battle
## whose whole value is that a player CANNOT tell it is happening.
##
## =====================================================================
## WHY THIS FILE EXISTS SEPARATELY FROM BattleContractProbe
##
## That probe gates the combat contract: phase order, the resolution
## matrix, the input buffer, determinism. Those are rules a player can be
## punished by. The feint is different in kind -- it is a rule about what
## a player is allowed to KNOW, and it fails in a way no combat assertion
## can see. Give the feint one millisecond less windup, one degree less
## lean, one different HUD string, and every phase of every other probe
## still passes while the mechanic is worthless: the player just reads
## the tell and the bluff never works again.
##
## So PHASE A does nothing but compare an attack and a feint on every
## channel a player has: the label the HUD prints, what an observer can
## perceive, the length of the telegraph, and the actual per-tick
## transforms FighterView writes onto the ModelSlot. All four must be
## indistinguishable for as long as a real attack's windup lasts, and
## they are compared rather than argued.
##
## PHASE C is the one that earns the lot. It scripts the exact situation
## the whole design is for -- an opponent feints, a player answers the
## telegraph after a HUMAN reaction latency -- and requires the dodge to
## be punished while the guard survives. That asymmetry is not a special
## rule anywhere in the code; it falls out of guard_active_s being wider
## than dodge_active_s, which means it can silently stop being true after
## an innocent-looking .tres edit. Hence a gate.
##
## Everything here drives the SHIPPED classes through their real
## advance(); nothing is stubbed or reimplemented.

const TICK_S := 1.0 / 60.0
const FighterScene := preload("res://scenes/BattleFighter.tscn")
const KeepyProfile := preload("res://resources/battle/keepy.tres")
const DummyProfile := preload("res://resources/battle/dummy.tres")

## The reaction latencies a human plausibly answers a telegraph with. The
## punish must hold across the whole band, not at one convenient value --
## a feint tuned to a single latency is a feint that stops working the
## day Mathieu is tired.
const LATENCIES: Array[float] = [0.12, 0.18, 0.24]

var _checks := 0
var _failures := 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "BATTLE FEINT PROBE")
	print("=== BATTLE FEINT PROBE ===")
	_phase_a_indistinguishable()
	_phase_b_hold()
	_phase_c_punish()
	_phase_d_gate()
	_phase_e_determinism()
	_phase_f_player_side()
	print("\n--- %d check(s), %d failure(s) ---" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

# ---------------------------------------------------------------- PHASE A

func _phase_a_indistinguishable() -> void:
	print("\n--- PHASE A: a feint is indistinguishable from an attack, on every channel ---")
	var p := DummyProfile

	_expect(BattleTypes.action_label(BattleTypes.Action.FEINT)
		== BattleTypes.action_label(BattleTypes.Action.ATTACK),
		"HUD label: FEINT prints '%s', exactly as ATTACK does"
			% BattleTypes.action_label(BattleTypes.Action.FEINT))

	var t_atk := p.timing_for(BattleTypes.Action.ATTACK)
	var t_fnt := p.timing_for(BattleTypes.Action.FEINT)
	_expect(is_equal_approx(t_fnt.x, t_atk.x + p.feint_hold_s),
		"timing: the feint's windup is the attack's plus the hold (%.3f = %.3f + %.3f)"
			% [t_fnt.x, t_atk.x, p.feint_hold_s])
	_expect(is_equal_approx(t_fnt.y, t_atk.y) and is_equal_approx(t_fnt.z, t_atk.z),
		"timing: active and recovery are the attack's own fields, not copies")

	# The two things an observer -- brain or player -- can read, sampled
	# every tick of a real attack's windup rather than once.
	var mismatch_threat := -1
	var mismatch_telegraph := -1
	var mismatch_pose := -1
	var atk := _run_windup(BattleTypes.Action.ATTACK)
	var fnt := _run_windup(BattleTypes.Action.FEINT)
	var span := mini(atk.size(), fnt.size())
	for i in span:
		var a: Dictionary = atk[i]
		var f: Dictionary = fnt[i]
		if mismatch_threat < 0 and a["threat"] != f["threat"]:
			mismatch_threat = i
		if mismatch_telegraph < 0 and not is_equal_approx(a["telegraph"], f["telegraph"]):
			mismatch_telegraph = i
		if mismatch_pose < 0 and a["pose"] != f["pose"]:
			mismatch_pose = i
	_expect(span >= int(t_atk.x / TICK_S),
		"sampled the whole of a real attack's windup (%d ticks)" % span)
	_expect(mismatch_threat < 0,
		"perception: is_threatening() agrees on all %d ticks" % span)
	_expect(mismatch_telegraph < 0,
		"telegraph_duration() agrees on all %d ticks (%.3f s)" % [span, atk[0]["telegraph"]])
	_expect(mismatch_pose < 0,
		"FighterView writes the SAME slot transform on all %d ticks" % span)

## Drives one fighter through `action` and samples, per tick, everything
## a defender could possibly read. The View is left attached and running:
## the pose column is the transform it actually wrote, not a prediction
## of what it would write.
func _run_windup(action: BattleTypes.Action) -> Array:
	var fighter := _make(DummyProfile)
	var slot: Node3D = fighter.get_node("Body")
	var out: Array = []
	fighter.request_action(action)
	while fighter.state == BattleTypes.State.WINDUP and out.size() < 600:
		out.append({
			"threat": fighter.is_threatening(),
			"telegraph": fighter.telegraph_duration(),
			"pose": "%.4f|%.4f|%.4f" % [slot.position.z, slot.rotation_degrees.x, slot.scale.y],
		})
		fighter.advance(TICK_S)
	fighter.free()
	return out

# ---------------------------------------------------------------- PHASE B

func _phase_b_hold() -> void:
	print("\n--- PHASE B: the strike is HELD, not withheld ---")
	var p := DummyProfile
	var atk := _ticks_to_strike(BattleTypes.Action.ATTACK)
	var fnt := _ticks_to_strike(BattleTypes.Action.FEINT)
	_expect(atk > 0, "an ATTACK strikes (%d ticks)" % atk)
	_expect(fnt > 0, "a FEINT strikes too -- it is late, not absent (%d ticks)" % fnt)
	var expected := int(round(p.feint_hold_s / TICK_S))
	_expect(absi((fnt - atk) - expected) <= 1,
		"the feint is late by exactly the hold (%d ticks, nominal %d, +/-1)"
			% [fnt - atk, expected])
	_expect(_strike_count(BattleTypes.Action.FEINT) == 1,
		"a feint emits strike_activated exactly once, like any attack")

func _ticks_to_strike(action: BattleTypes.Action) -> int:
	var fighter := _make(DummyProfile)
	var seen := {"t": -1}
	var t := {"n": 0}
	fighter.strike_activated.connect(func() -> void:
		if seen["t"] < 0:
			seen["t"] = t["n"])
	fighter.request_action(action)
	while seen["t"] < 0 and t["n"] < 600:
		fighter.advance(TICK_S)
		t["n"] += 1
	fighter.free()
	return seen["t"]

func _strike_count(action: BattleTypes.Action) -> int:
	var fighter := _make(DummyProfile)
	var n := {"c": 0}
	fighter.strike_activated.connect(func() -> void: n["c"] += 1)
	fighter.request_action(action)
	for i in 600:
		fighter.advance(TICK_S)
	fighter.free()
	return n["c"]

# ---------------------------------------------------------------- PHASE C

func _phase_c_punish() -> void:
	print("\n--- PHASE C: the feint punishes a DODGE and not a GUARD ---")
	# The control first. If a plain attack already beat the dodge there
	# would be nothing here worth building, and the numbers below would
	# be measuring the dodge being bad rather than the feint being good.
	for lat in LATENCIES:
		_expect(_answer(BattleTypes.Action.ATTACK, BattleTypes.Action.DODGE, lat)
			== BattleTypes.Outcome.DODGED,
			"control: a plain attack answered by a dodge at %.2f s is DODGED" % lat)
	for lat in LATENCIES:
		_expect(_answer(BattleTypes.Action.FEINT, BattleTypes.Action.DODGE, lat)
			== BattleTypes.Outcome.HIT,
			"a feint answered by a dodge at %.2f s lands CLEAN" % lat)
		_expect(_answer(BattleTypes.Action.FEINT, BattleTypes.Action.GUARD, lat)
			== BattleTypes.Outcome.BLOCKED,
			"a feint answered by a guard at %.2f s is BLOCKED" % lat)

## One scripted exchange: the attacker commits `action` at tick 0, the
## defender answers with `answer` once the telegraph has been visible for
## `latency` seconds -- ONE tap, the way a person answers a read, not a
## button held down. Returns what the strike produced.
func _answer(action: BattleTypes.Action, answer: BattleTypes.Action, latency: float) -> BattleTypes.Outcome:
	var attacker := _make(DummyProfile)
	var defender := _make(KeepyProfile)
	var got := {"o": BattleTypes.Outcome.MISSED, "n": 0}
	attacker.strike_activated.connect(func() -> void:
		got["n"] += 1
		got["o"] = defender.receive_strike(DummyProfile.attack_damage))
	attacker.request_action(action)
	var seen := 0.0
	var answered := false
	for i in 600:
		if not answered and attacker.is_threatening():
			if seen >= latency:
				answered = true
				defender.request_action(answer)
			seen += TICK_S
		defender.advance(TICK_S)
		attacker.advance(TICK_S)
		if got["n"] > 0:
			break
	attacker.free()
	defender.free()
	return got["o"]

# ---------------------------------------------------------------- PHASE D

func _phase_d_gate() -> void:
	print("\n--- PHASE D: when the brain is allowed to bluff ---")
	# The direction of this test is the whole finding of lot 4, and it is
	# the opposite of what it looks like it should be. See
	# Fighter.is_free() for the measurement.
	var at_busy := _feints_over(200, false, 0.6)
	_expect(at_busy > 0,
		"the brain DOES feint at a COMMITTED opponent (%d of 200 offensive decisions)" % at_busy)
	_expect(_feints_over(200, true, 0.6) == 0,
		"the brain NEVER feints at a FREE opponent -- who would simply hit it first")
	_expect(_feints_over(200, false, 0.0) == 0,
		"ai_feint_rate = 0 disables the mechanic outright")

## Counts feints over `n` forced offensive decisions, with the opponent
## held either free (IDLE) or committed. Drives the real brain against
## real fighters; the only thing scripted is the opponent's availability.
func _feints_over(n: int, opponent_free: bool, rate: float) -> int:
	var profile := DummyProfile.duplicate() as FighterProfile
	profile.ai_feint_rate = rate
	profile.ai_reaction_delay_s = 0.0
	profile.ai_reaction_jitter_s = 0.0
	profile.ai_aggression = 1.0
	var count := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260821
	for i in n:
		var fighter := _make(profile)
		var opponent := _make(KeepyProfile)
		if not opponent_free:
			# A GUARD, so the opponent is committed but NOT threatening:
			# that isolates the free/committed axis from the separate
			# "never feint into an incoming attack" branch, which would
			# otherwise explain a zero on its own.
			opponent.request_action(BattleTypes.Action.GUARD)
			opponent.advance(TICK_S)
		var brain := FighterBrain.new()
		brain.setup(fighter, opponent, profile, rng)
		var started := {"a": BattleTypes.Action.NONE}
		fighter.action_started.connect(func(a: BattleTypes.Action) -> void: started["a"] = a)
		for t in 8:
			if started["a"] != BattleTypes.Action.NONE:
				break
			brain.advance(TICK_S)
			fighter.advance(TICK_S)
		if started["a"] == BattleTypes.Action.FEINT:
			count += 1
		fighter.free()
		opponent.free()
	return count

# ---------------------------------------------------------------- PHASE E

func _phase_e_determinism() -> void:
	print("\n--- PHASE E: feints are part of the seeded fight, not noise on it ---")
	var a := _trace(20260820)
	var b := _trace(20260820)
	var c := _trace(31415926)
	_expect(a.feints > 0,
		"the traced fight actually contains feints (%d) -- otherwise the two\n          checks below would pass on a fight this phase never exercised" % a.feints)
	_expect(a.text == b.text,
		"same seed -> byte-identical trace with feints enabled (%d chars)" % a.text.length())
	_expect(a.text != c.text, "different seed -> different fight")

class Trace:
	var text: String = ""
	var feints: int = 0

func _trace(fight_seed: int) -> Trace:
	var profile := DummyProfile.duplicate() as FighterProfile
	profile.ai_feint_rate = 0.6
	var left := _make(KeepyProfile)
	var right := _make(profile)
	var rng := RandomNumberGenerator.new()
	rng.seed = fight_seed
	var brain := FighterBrain.new()
	brain.setup(right, left, profile, rng)
	# A brain on BOTH sides. Not decoration: the feint only fires at a
	# committed opponent, so an idle stand-in would be feinted at exactly
	# zero times and this phase would then be checking determinism on a
	# fight that contains none of what it claims to cover -- which is the
	# first thing the check below refuses to let happen.
	var mirror := FighterBrain.new()
	mirror.setup(left, right, KeepyProfile, rng)
	left.strike_activated.connect(func() -> void: right.receive_strike(KeepyProfile.attack_damage))
	right.strike_activated.connect(func() -> void: left.receive_strike(profile.attack_damage))
	var result := Trace.new()
	right.action_started.connect(func(a: BattleTypes.Action) -> void:
		if a == BattleTypes.Action.FEINT:
			result.feints += 1)
	var parts := PackedStringArray()
	var t := 0
	while t < 3000 and left.is_alive() and right.is_alive():
		left.advance(TICK_S)
		right.advance(TICK_S)
		brain.advance(TICK_S)
		mirror.advance(TICK_S)
		parts.append("%d:%d:%d" % [right.hp, right.state, right.current_action])
		t += 1
	left.free()
	right.free()
	result.text = "|".join(parts)
	return result

# ---------------------------------------------------------------- PHASE F

func _phase_f_player_side() -> void:
	print("\n--- PHASE F: the player's own profile holds no option the player has ---")
	# BattleHUD emits three actions and only three. A player-side profile
	# with a feint rate would be an AI standing in for Mathieu while
	# holding a button he does not have -- and every balance figure taken
	# with it would be measuring a different game.
	_expect(is_zero_approx(KeepyProfile.ai_feint_rate),
		"%s carries ai_feint_rate = 0.00" % KeepyProfile.display_name)

# ---------------------------------------------------------------- helpers

func _make(profile: FighterProfile) -> Fighter:
	var fighter := FighterScene.instantiate() as Fighter
	fighter.profile = profile
	add_child(fighter)
	return fighter

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("    OK    %s" % label)
		return
	_failures += 1
	printerr("    FAIL  %s" % label)
	print("    FAIL  %s" % label)
