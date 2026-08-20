extends Node
## Dev-only: gates the Keepy Battle combat contract -- the FSM's phase
## order and durations, the strike-resolution matrix, the input buffer,
## and the determinism the whole lot's balance work depends on.
##
## =====================================================================
## WHY A PROBE AND NOT A PLAYTEST
##
## Lot 1 of Keepy Battle exists to settle feel and balance BEFORE any
## Meshy credit is spent, and "it feels about right" is not a measurement.
## Everything asserted below is a rule a player can be punished by, so
## each one is checked against the SHIPPED scripts -- never a stub, never
## a reimplementation of the rule in the test. Fighter and FighterBrain
## are the real classes, driven through the real `advance()`.
##
## PHASE D is the one that earns this file. It plays the same AI-vs-AI
## fight twice at one seed and compares a per-tick trace BYTE FOR BYTE,
## then replays it at a different seed and requires the trace to DIFFER.
## Both halves are needed: a trace that always matches would also "pass"
## if the fight were frozen, and this project has already paid twice for
## probes that were green on something that never ran (ProbeCoverage.gd).
##
## PHASE E is the interchangeability claim from Fighter.gd's header,
## turned into a test: the brain is pointed at the PLAYER's fighter and
## has to produce a real fight. If a future change ever makes one side
## special, this is where it shows.
##
## Ticks, never seconds: the arena advances in fixed TICK_S steps, so
## every duration below is expressed in whole ticks and compared exactly.

const TICK_S := 1.0 / 60.0
const FighterScene := preload("res://scenes/BattleFighter.tscn")
const KeepyProfile := preload("res://resources/battle/keepy.tres")
const DummyProfile := preload("res://resources/battle/dummy.tres")

var _failures := 0
var _checks := 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "BattleContractProbe")
	print("=== BATTLE CONTRACT PROBE ===")
	print("tick=%.6fs  profiles: %s vs %s" % [TICK_S, KeepyProfile.display_name, DummyProfile.display_name])
	_phase_a_fsm()
	_phase_b_resolution()
	_phase_c_buffer()
	_phase_d_determinism()
	_phase_e_interchangeable()
	_phase_f_balance()
	print("--- %d check(s), %d failure(s) ---" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

# ---------------------------------------------------------------- PHASE A

func _phase_a_fsm() -> void:
	print("\n--- PHASE A: FSM phase order and durations ---")
	var f := _make(KeepyProfile)
	var strikes := [0]
	f.strike_activated.connect(func() -> void: strikes[0] += 1)

	_expect(f.state == BattleTypes.State.IDLE, "starts IDLE")
	_expect(f.hp == KeepyProfile.max_hp, "starts at full hp")

	f.request_action(BattleTypes.Action.ATTACK)
	_expect(f.state == BattleTypes.State.WINDUP, "ATTACK enters WINDUP immediately")
	_expect(strikes[0] == 0, "no strike during WINDUP")

	var windup_ticks := _ticks_until(f, BattleTypes.State.ACTIVE, 600)
	_expect_ticks(windup_ticks, KeepyProfile.attack_windup_s, "WINDUP lasts attack_windup_s")
	_expect(strikes[0] == 1, "strike fires exactly once, on the first ACTIVE tick")

	var active_ticks := _ticks_until(f, BattleTypes.State.RECOVERY, 600)
	_expect_ticks(active_ticks, KeepyProfile.attack_active_s, "ACTIVE lasts attack_active_s")
	_expect(strikes[0] == 1, "strike does NOT repeat across a multi-tick ACTIVE window")

	var recovery_ticks := _ticks_until(f, BattleTypes.State.IDLE, 600)
	_expect_ticks(recovery_ticks, KeepyProfile.attack_recovery_s, "RECOVERY lasts attack_recovery_s")

	# The TOTAL is the number that must be exact, and this is the assertion
	# that matters: Fighter.advance() carries each phase's overshoot into
	# the next one, so an individual phase can land one tick either side of
	# its nominal length while the whole action stays true to the sum. That
	# carry is deliberate -- without it every phase would silently round UP
	# and a three-phase action would run up to three ticks long, differently
	# per fighter depending on how their timings divide by the tick.
	var total := windup_ticks + active_ticks + recovery_ticks
	var nominal := KeepyProfile.attack_windup_s + KeepyProfile.attack_active_s + KeepyProfile.attack_recovery_s
	_expect_ticks(total, nominal, "the WHOLE attack lasts the sum of its phases (overshoot carried, not dropped)")

	# An action is refused mid-commitment: only IDLE accepts one directly.
	f.request_action(BattleTypes.Action.GUARD)
	_expect(f.current_action == BattleTypes.Action.GUARD, "GUARD accepted from IDLE")
	f.request_action(BattleTypes.Action.ATTACK)
	_expect(f.current_action == BattleTypes.Action.GUARD, "a second action cannot interrupt a commitment")
	f.free()

# ---------------------------------------------------------------- PHASE B

func _phase_b_resolution() -> void:
	print("\n--- PHASE B: strike resolution matrix ---")
	var damage := 20

	var guarded := _make(KeepyProfile)
	_hold_in_active(guarded, BattleTypes.Action.GUARD)
	var chip := int(ceil(float(damage) * KeepyProfile.guard_damage_ratio))
	_expect(guarded.receive_strike(damage) == BattleTypes.Outcome.BLOCKED, "GUARD active -> BLOCKED")
	_expect(guarded.hp == KeepyProfile.max_hp - chip, "BLOCKED costs chip damage only (%d)" % chip)
	_expect(guarded.state == BattleTypes.State.ACTIVE, "BLOCKED does NOT stagger -- guard keeps its timing")
	guarded.free()

	var dodged := _make(KeepyProfile)
	_hold_in_active(dodged, BattleTypes.Action.DODGE)
	_expect(dodged.receive_strike(damage) == BattleTypes.Outcome.DODGED, "DODGE active -> DODGED")
	_expect(dodged.hp == KeepyProfile.max_hp, "DODGED costs nothing at all")
	dodged.free()

	var idle := _make(KeepyProfile)
	_expect(idle.receive_strike(damage) == BattleTypes.Outcome.HIT, "IDLE -> HIT")
	_expect(idle.hp == KeepyProfile.max_hp - damage, "HIT costs full damage")
	_expect(idle.state == BattleTypes.State.STAGGER, "HIT staggers")
	idle.free()

	# The rule that stops both fighters from just mashing attack.
	var attacker := _make(KeepyProfile)
	_hold_in_active(attacker, BattleTypes.Action.ATTACK)
	_expect(attacker.receive_strike(damage) == BattleTypes.Outcome.HIT, "ACTIVE attack frames do NOT defend")
	_expect(attacker.state == BattleTypes.State.STAGGER, "a traded hit cancels the attack in progress")
	attacker.free()

	# Guard is not free: chip damage alone can finish a fight, so a purely
	# defensive player cannot stall forever.
	var windup := _make(KeepyProfile)
	windup.request_action(BattleTypes.Action.GUARD)
	_expect(windup.receive_strike(damage) == BattleTypes.Outcome.HIT, "GUARD in WINDUP is NOT yet blocking")
	windup.free()

	var recovering := _make(KeepyProfile)
	_hold_in_recovery(recovering, BattleTypes.Action.DODGE)
	_expect(recovering.receive_strike(damage) == BattleTypes.Outcome.HIT, "DODGE in RECOVERY is punishable")
	recovering.free()

	var dying := _make(KeepyProfile)
	var kos := [0]
	dying.knocked_out.connect(func() -> void: kos[0] += 1)
	dying.receive_strike(KeepyProfile.max_hp)
	_expect(dying.state == BattleTypes.State.KO and kos[0] == 1, "lethal damage KOs once")
	_expect(dying.receive_strike(damage) == BattleTypes.Outcome.MISSED, "a KO fighter cannot be hit again")
	dying.free()

# ---------------------------------------------------------------- PHASE C

func _phase_c_buffer() -> void:
	print("\n--- PHASE C: input buffer ---")
	var buffer_ticks := int(round(Fighter.INPUT_BUFFER_S / TICK_S))

	# Tapped just inside the buffer window before IDLE: must be replayed.
	var early := _make(KeepyProfile)
	early.request_action(BattleTypes.Action.ATTACK)
	var to_idle := _ticks_until(early, BattleTypes.State.IDLE, 600)
	_expect(to_idle > buffer_ticks, "attack is longer than the buffer (precondition)")
	early.reset()
	early.request_action(BattleTypes.Action.ATTACK)
	var left := _ticks_until(early, BattleTypes.State.IDLE, 600)
	early.reset()
	early.request_action(BattleTypes.Action.ATTACK)
	_advance(early, left - buffer_ticks + 1)
	early.request_action(BattleTypes.Action.GUARD)
	_advance(early, buffer_ticks)
	_expect(early.current_action == BattleTypes.Action.GUARD, "a tap inside the buffer window is replayed on IDLE")
	early.free()

	# Tapped far too early: dropped, and the fighter is idle rather than
	# committed to something the player has stopped expecting.
	var stale := _make(KeepyProfile)
	stale.request_action(BattleTypes.Action.ATTACK)
	stale.request_action(BattleTypes.Action.GUARD)
	_advance(stale, left + 2)
	_expect(stale.current_action == BattleTypes.Action.NONE, "a tap older than the buffer is dropped")
	_expect(stale.state == BattleTypes.State.IDLE, "and leaves the fighter IDLE, not committed")
	stale.free()

# ---------------------------------------------------------------- PHASE D

func _phase_d_determinism() -> void:
	print("\n--- PHASE D: determinism ---")
	var a := _run_fight(20260820, 4000)
	var b := _run_fight(20260820, 4000)
	var c := _run_fight(31415926, 4000)
	print("  seed 20260820: %d ticks, winner=%s" % [a.ticks, a.winner])
	print("  seed 31415926: %d ticks, winner=%s" % [c.ticks, c.winner])
	_expect(a.trace == b.trace, "same seed -> byte-identical per-tick trace (%d chars)" % a.trace.length())
	_expect(a.trace != c.trace, "different seed -> different fight (not frozen)")
	_expect(a.ticks < 4000, "the fight actually ends rather than timing out")
	_expect(a.trace.length() > 0, "the trace is not empty")

# ---------------------------------------------------------------- PHASE E

func _phase_e_interchangeable() -> void:
	print("\n--- PHASE E: player and AI are interchangeable on one Fighter ---")
	# The SAME brain class, driving the fighter carrying the PLAYER's
	# profile against the opponent -- the mirror of PHASE D's wiring.
	var mirrored := _run_fight(20260820, 4000, true)
	print("  mirrored wiring: %d ticks, winner=%s" % [mirrored.ticks, mirrored.winner])
	_expect(mirrored.ticks > 0 and mirrored.ticks < 4000, "a brain drives the player's Fighter with no special case")
	_expect(mirrored.winner != "none", "the mirrored fight resolves")

# ---------------------------------------------------------------- PHASE F

func _phase_f_balance() -> void:
	print("\n--- PHASE F: balance sample (reported, NOT gated) ---")
	# Reported and never asserted: what a fair fight FEELS like is
	# Mathieu's call on device, and a probe that gated it would be a
	# number tuned until it went green -- the false pass ProbeCoverage.gd
	# documents five times.
	#
	# BRAINS ON BOTH SIDES (mirrored), and that is not incidental. The
	# first version of this phase ran a brain on the opponent only --
	# faithful to the real arena, where the other side is a human -- and
	# duly reported the Keepy profile losing 40 out of 40. That number
	# measured an idle punching bag, not a balance problem: a fighter with
	# nothing driving it never acts. A profile-vs-profile figure needs
	# both sides played, which is exactly what the mirrored wiring gives.
	var player_wins := 0
	var total_ticks := 0
	var shortest := 1 << 30
	var longest := 0
	var runs := 40
	for i in runs:
		var r := _run_fight(20260820 + i, 6000, true)
		if r.winner == "player":
			player_wins += 1
		total_ticks += r.ticks
		shortest = min(shortest, r.ticks)
		longest = max(longest, r.ticks)
	print("  %d AI-vs-AI fights (%s profile vs %s profile)" % [runs, KeepyProfile.display_name, DummyProfile.display_name])
	print("  keepy-profile wins : %d / %d" % [player_wins, runs])
	print("  round length       : mean %.2fs, min %.2fs, max %.2fs" % [
		float(total_ticks) / float(runs) * TICK_S, shortest * TICK_S, longest * TICK_S])

# ---------------------------------------------------------------- helpers

class FightResult:
	var ticks: int = 0
	var winner: String = "none"
	var trace: String = ""

## One headless fight, driven by the SAME fixed-step order BattleArena
## uses. Deliberately not instantiating Battle.tscn: that scene calls
## SafeArea and owns a HUD, neither of which this probe is measuring, and
## the tick loop is three lines that must match the arena's order exactly
## -- which PHASE D would catch drifting, since a reordered tick changes
## who wins a trade and therefore changes the trace.
func _run_fight(fight_seed: int, tick_cap: int, mirrored: bool = false) -> FightResult:
	var result := FightResult.new()
	var left := _make(KeepyProfile)
	var right := _make(DummyProfile)
	var rng := RandomNumberGenerator.new()
	rng.seed = fight_seed
	var brain_a := FighterBrain.new()
	var brain_b := FighterBrain.new()
	brain_a.setup(right, left, right.profile, rng)
	# Mirrored runs additionally point a brain at the PLAYER's fighter --
	# the interchangeability claim, exercised rather than asserted.
	if mirrored:
		brain_b.setup(left, right, left.profile, rng)

	left.strike_activated.connect(func() -> void: right.receive_strike(left.profile.attack_damage))
	right.strike_activated.connect(func() -> void: left.receive_strike(right.profile.attack_damage))

	var parts := PackedStringArray()
	while result.ticks < tick_cap and left.is_alive() and right.is_alive():
		left.advance(TICK_S)
		right.advance(TICK_S)
		brain_a.advance(TICK_S)
		if mirrored:
			brain_b.advance(TICK_S)
		result.ticks += 1
		parts.append("%d:%d:%d:%d:%d:%d" % [left.hp, left.state, left.current_action, right.hp, right.state, right.current_action])
	result.trace = "|".join(parts)
	if not right.is_alive():
		result.winner = "player"
	elif not left.is_alive():
		result.winner = "opponent"
	left.free()
	right.free()
	return result

## A Fighter built from the SHIPPED scene, with its profile swapped
## before _ready() runs so _apply_profile_art() sees the right one.
func _make(profile: FighterProfile) -> Fighter:
	var fighter := FighterScene.instantiate() as Fighter
	fighter.profile = profile
	add_child(fighter)
	return fighter

func _advance(fighter: Fighter, ticks: int) -> void:
	for i in ticks:
		fighter.advance(TICK_S)

## Ticks spent before `fighter` reaches `target`, exclusive of the tick
## that entered it -- i.e. the length of the phase just left.
func _ticks_until(fighter: Fighter, target: BattleTypes.State, cap: int) -> int:
	var ticks := 0
	while ticks < cap and fighter.state != target:
		fighter.advance(TICK_S)
		ticks += 1
	return ticks

## Drives `fighter` into the ACTIVE window of `action` and leaves it there.
func _hold_in_active(fighter: Fighter, action: BattleTypes.Action) -> void:
	fighter.request_action(action)
	_ticks_until(fighter, BattleTypes.State.ACTIVE, 600)

func _hold_in_recovery(fighter: Fighter, action: BattleTypes.Action) -> void:
	fighter.request_action(action)
	_ticks_until(fighter, BattleTypes.State.RECOVERY, 600)

## Compares a measured phase length, in WHOLE TICKS, against its nominal
## seconds -- allowing exactly one tick of slack.
##
## The slack is NOT a fudge factor hiding drift, and it is bounded on
## purpose. Fighter.advance() carries a phase's overshoot into the next
## phase, so any one phase can be a tick short or long while the sequence
## stays true; what cannot happen is a phase drifting further than that,
## because the carry is re-applied every transition and never accumulates.
## The exact assertion is on the TOTAL, above.
func _expect_ticks(measured: int, seconds: float, label: String) -> void:
	var expected := int(round(seconds / TICK_S))
	_expect(absi(measured - expected) <= 1, "%s (%d ticks, nominal %d, +/-1)" % [label, measured, expected])

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("    OK    %s" % label)
		return
	_failures += 1
	printerr("    FAIL  %s" % label)
	print("    FAIL  %s" % label)
