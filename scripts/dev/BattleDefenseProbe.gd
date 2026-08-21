extends Node
## Dev-only: measures whether DEFENDING is a real option in Keepy Battle,
## from the point of view of a player who is NOT perfect.
##
## =====================================================================
## FOUR LOTS OF TUNING NEVER SHIFTED THE SAME DEVICE REPORT
##
## Lots 3, 4, 5 and 6 each found a different, measured, provable cause of
## "guard and dodge do not work, the only strategy is to attack", fixed
## it, and heard the same sentence back. Lot 5's version of this file
## reported guard covering a blow from a tap anywhere in the human band
## and still the report did not move.
##
## The cause finally retained is the one no window can supply: the player
## knew an attack was COMING and never knew WHEN it lands. Lot 7 states
## the instant -- a charge bar on the attacker whose fill reaches full
## exactly as the blow leaves -- and deletes GUARD and the FEINT, because
## a second defensive option and a lie about the impact instant are both
## hedges against a question that now has an answer.
##
## =====================================================================
## WHAT THAT CHANGES ABOUT THIS FILE
##
## Lot 5 sized everything against a REACTION: `human latency + startup`
## versus the telegraph's length, with the honest phone band at
## 0.30-0.45 s. That inequality is not wrong, it is no longer the one
## that decides. Watching a fill complete is an ANTICIPATION, and a
## player anticipating an instant is far more precise than one reacting
## to an onset -- so the question this file asks is no longer "how late
## can the tap be" but "HOW WIDE IS THE TARGET, AND CAN A HUMAN HIT IT".
##
## The reaction band survives for one thing only: the player still has to
## NOTICE the telegraph before they can start watching it, so the window
## must not open before a human could have seen the bar at all.
##
## =====================================================================
## WHAT IS GATED AND WHAT IS ONLY REPORTED
##
## GATED (PHASES A, B, C, C2, E): the geometry of the evade window, the
## punish arithmetic that makes evading worth anything, and the four
## verdicts. Those are facts about the shipped .tres files -- "a dodge
## tapped at 70% of the bar is active when the blow lands" is either true
## or it is not, and when it stops being true the mechanic is silently
## dead again.
##
## REPORTED, NEVER GATED (PHASE D): win rates of caricature policies.
## What a fair fight FEELS like is Mathieu's call on device, and a probe
## that gated a win rate is a number that gets tuned until it goes green
## -- the false pass ProbeCoverage.gd documents five times.
##
## Everything below drives the SHIPPED Fighter, FighterBrain and .tres
## through their real advance() at the arena's real tick. Nothing here
## reimplements a combat rule.

const TICK_S := 1.0 / 60.0
const FighterScene := preload("res://scenes/BattleFighter.tscn")
const KeepyProfile := preload("res://resources/battle/keepy.tres")
const DummyProfile := preload("res://resources/battle/dummy.tres")

## The honest band for a phone tap answering a visual telegraph, in
## seconds, measured from the first frame of the telegraph. 0.30 is a
## fast, attentive player who already knows the game; 0.45 is the same
## player a few minutes in. NOT the lab figure for a bare reaction time
## (~0.25 s): a touchscreen adds digitiser sampling and a browser adds
## event dispatch on top of whatever frame the canvas last drew.
##
## Lot 7 uses it only as a FLOOR on when the window may open -- see
## PHASE B. The width of the window is judged against timing jitter
## instead, which is a different and much smaller number.
const HUMAN_FAST := 0.30
const HUMAN_LATE := 0.45
## Standard deviation of a human's timing error on an ANTICIPATED
## instant -- pressing as a fill completes, not reacting to it appearing.
## Deliberately pessimistic: published figures for anticipation timing
## sit well under 100 ms, and a window narrower than +-2 sigma would be a
## window most attempts miss.
const HUMAN_JITTER := 0.09

var _failures := 0
var _checks := 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "BattleDefenseProbe")
	print("=== BATTLE DEFENCE VIABILITY PROBE ===")
	print("tick=%.6fs  attacker=%s  defender=%s" % [TICK_S, DummyProfile.display_name, KeepyProfile.display_name])
	print("human notice band %.2f..%.2fs, anticipation jitter sigma %.0f ms" % [
		HUMAN_FAST, HUMAN_LATE, HUMAN_JITTER * 1000.0])
	_phase_a_chronogram()
	_phase_b_window()
	_phase_c_punishment()
	_phase_c2_stagger()
	_phase_e_feedback()
	_phase_d_imperfect()
	print("\n--- %d check(s), %d failure(s) ---" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

# ---------------------------------------------------------------- PHASE A

## The chronogram the whole lot turns on: where the blow lands, and which
## taps evade it.
##
## Every number is produced by RUNNING the shipped FSM, never by adding
## up fields from the .tres -- the two agree only as long as nothing in
## Fighter rounds, clamps or carries anything, and Fighter carries phase
## overshoot deliberately.
func _phase_a_chronogram() -> void:
	print("\n--- PHASE A: chronogram (ticks from the first frame of the bar) ---")
	var strike := _strike_tick()
	var windup_ticks := int(round(DummyProfile.attack_windup_s / TICK_S))
	print("  the bar fills over %d ticks (%.0f ms); the blow lands on tick %d" % [
		windup_ticks, DummyProfile.attack_windup_s * 1000.0, strike])
	_expect(strike > 0, "the strike really resolves")
	_expect(absi(strike - windup_ticks) <= 1,
		"and it lands within one tick of a full bar -- the bar's whole promise")

	var band := _cover_band()
	_report_band("dodge evades", band)
	_expect(band.x >= 0, "there is a tap that evades at all")

# ---------------------------------------------------------------- PHASE B

## GATED. Is the target something a human can hit?
##
## Three separate ways it can fail, and they fail in different
## directions, which is why they are three assertions and not one:
##
##   1. TOO NARROW. The window has to absorb a human's timing error
##      around wherever they aim. Judged at +-2 sigma of HUMAN_JITTER,
##      i.e. it must be at least 4 sigma wide, because a target most
##      attempts miss is a target that teaches "the button does nothing".
##   2. TOO WIDE. A window covering most of the bar makes "tap whenever"
##      correct and deletes the decision -- the failure that would look
##      like success in every other number this file prints.
##   3. OPENS TOO EARLY TO BE SEEN. The player has to notice the bar
##      before they can watch it, so a window that has already closed by
##      the time a human could have reacted at all is unusable however
##      wide it is.
func _phase_b_window() -> void:
	print("\n--- PHASE B: can a human hit the evade window (GATED) ---")
	var band := _cover_band()
	var windup_ticks := int(round(DummyProfile.attack_windup_s / TICK_S))
	if band.x < 0:
		_expect(false, "a dodge can evade at all")
		return
	var width_s := _span(band) * TICK_S
	var lo_frac := float(band.x) / float(windup_ticks)
	var hi_frac := float(band.y) / float(windup_ticks)
	print("  window %.0f ms wide, at %.0f%%..%.0f%% of the bar" % [
		width_s * 1000.0, lo_frac * 100.0, hi_frac * 100.0])
	print("  needed for +-2 sigma of human jitter : %.0f ms" % (4.0 * HUMAN_JITTER * 1000.0))
	_expect(width_s >= 4.0 * HUMAN_JITTER,
		"the window absorbs +-2 sigma of a human's timing error")
	var covered := float(_span(band)) / float(windup_ticks)
	print("  window covers %.0f%% of the whole bar" % (covered * 100.0))
	_expect(covered <= 0.75,
		"and is NOT so wide that tapping anywhere works -- there is still a decision")
	print("  window CLOSES at %.0f ms; a human notices the bar by %.0f ms at worst" % [
		band.y * TICK_S * 1000.0, HUMAN_LATE * 1000.0])
	_expect(band.y * TICK_S > HUMAN_LATE,
		"the window is still open after the slowest human has noticed the bar")

	# The mark the game DRAWS has to be a subset of the taps that work.
	# BattleArena computes it; here it is checked against the mechanic.
	var arena_lo := (DummyProfile.attack_windup_s - KeepyProfile.dodge_windup_s
		- KeepyProfile.dodge_active_s) / DummyProfile.attack_windup_s
	var arena_hi := (DummyProfile.attack_windup_s - KeepyProfile.dodge_windup_s
		- BattleArena.EVADE_EDGE_ALLOWANCE_TICKS * TICK_S) / DummyProfile.attack_windup_s
	print("  the band the game DRAWS : %.3f .. %.3f of the bar" % [arena_lo, arena_hi])
	_expect(arena_lo >= lo_frac - 1e-6 and arena_hi <= hi_frac + 1e-6,
		"every tap inside the drawn band really evades -- the band never over-promises")

# ---------------------------------------------------------------- PHASE C

## GATED. Evading has to COST the attacker something, or it is a slower
## way to lose and the correct strategy is to never stop attacking -- the
## exact sentence four device reports contained.
##
## A defender who dodges is locked out for its whole dodge cycle from the
## tap. To make the exchange cost anything it has to come free EARLIER
## than the attacker does, and get the next attack out first:
##
##     tap + dodge cycle  <  wind-up + active + recovery
##
## Lot 5 found the GUARD version of this inequality failing while every
## other number said guard worked perfectly; a player who blocked was
## simply behind forever. Measured across the whole window, so it is not
## a claim about one lucky tap.
func _phase_c_punishment() -> void:
	print("\n--- PHASE C: does a successful evade actually punish (GATED) ---")
	var band := _cover_band()
	if band.x < 0:
		_expect(false, "a dodge can evade at all")
		return
	var attacker_free := (DummyProfile.attack_windup_s + DummyProfile.attack_active_s
		+ DummyProfile.attack_recovery_s)
	var cycle := (KeepyProfile.dodge_windup_s + KeepyProfile.dodge_active_s
		+ KeepyProfile.dodge_recovery_s)
	print("  attacker is free again at %.0f ms; dodge cycle is %.0f ms" % [
		attacker_free * 1000.0, cycle * 1000.0])
	var worst_lead := 1000.0
	for tap in range(band.x, band.y + 1):
		var defender_free := float(tap) * TICK_S + cycle
		worst_lead = minf(worst_lead, attacker_free - defender_free)
	print("  worst lead over the whole window : %.0f ms" % (worst_lead * 1000.0))
	_expect(worst_lead > 0.0,
		"a dodge tapped ANYWHERE in the window leaves the defender free first")
	# Measured rather than derived: the two fighters are actually run, and
	# the one that dodged has to land the next blow.
	var counter := _counter_lands(int(round(0.70 * DummyProfile.attack_windup_s / TICK_S)))
	print("  a dodge at 70%% of the bar, then a counter : %s" % ("LANDS" if counter else "does not land"))
	_expect(counter, "and the counter really lands, run through the shipped FSM")

# --------------------------------------------------------------- PHASE C2

## GATED. Being hit must be worse than whiffing. It is easy to invert
## this silently -- lot 5 lengthened attack_recovery_s past the shipped
## stagger and lot 7 lengthened it again -- and the symptom is that
## trading beats defending, which is exactly what nobody would attribute
## to a stagger constant.
func _phase_c2_stagger() -> void:
	print("\n--- PHASE C2: being hit is worse than whiffing (GATED) ---")
	for entry in [["Keepy", KeepyProfile], ["Sparring", DummyProfile]]:
		var label: String = entry[0]
		var p: FighterProfile = entry[1]
		var worst_recovery: float = maxf(p.attack_recovery_s, p.dodge_recovery_s)
		print("  %-9s stagger %.0f ms vs longest recovery %.0f ms" % [
			label, p.stagger_duration_s * 1000.0, worst_recovery * 1000.0])
		_expect(p.stagger_duration_s > worst_recovery,
			"%s: a clean hit costs more than any whiff" % label)

# ---------------------------------------------------------------- PHASE E

## GATED. THREE outcomes, three distinct verdicts.
##
## Lot 5 added this because a dodge pressed 80 ms too late looked exactly
## like never having pressed anything, and an option whose timing a
## player cannot learn is an option nobody takes. Lot 7 keeps it and
## makes it actionable: the charge bar says which way the tap was wrong.
func _phase_e_feedback() -> void:
	print("\n--- PHASE E: three outcomes, three verdicts (GATED) ---")
	var band := _cover_band()
	var good := int(round((band.x + band.y) * 0.5))
	# `band.y + 1` and not `band.y + 10`: a tap placed after the strike
	# has already resolved is not a mistimed defence at all, it is no
	# defence, and the probe would then assert that the wrong thing
	# passes. Lot 5 caught exactly that on this phase's first run.
	var late := band.y + 1
	var early := maxi(band.x - 6, 0)

	var cases := [
		[BattleTypes.Action.DODGE, good, BattleTypes.Outcome.DODGED, BattleTypes.Action.DODGE, "ESQUIVE"],
		[BattleTypes.Action.DODGE, late, BattleTypes.Outcome.HIT, BattleTypes.Action.DODGE, "ESQUIVE RATEE"],
		[BattleTypes.Action.DODGE, early, BattleTypes.Outcome.HIT, BattleTypes.Action.DODGE, "ESQUIVE RATEE"],
		[BattleTypes.Action.NONE, 0, BattleTypes.Outcome.HIT, BattleTypes.Action.NONE, "TOUCHE"],
	]
	var seen := {}
	for c in cases:
		var defence: BattleTypes.Action = c[0]
		var tap: int = c[1]
		var want_outcome: BattleTypes.Outcome = c[2]
		var want_attempted: BattleTypes.Action = c[3]
		var want_label: String = c[4]
		var got := _resolve_reported(defence, tap)
		var label: String = BattleTypes.strike_label(got[0], got[1])
		print("    %-8s tap %2d -> outcome %d, attempted %d, \"%s\"" % [
			BattleTypes.action_label(defence) if defence != BattleTypes.Action.NONE else "(none)",
			tap, got[0], got[1], label])
		_expect(got[0] == want_outcome and got[1] == want_attempted,
			"%s at tick %d reports the right pair" % [want_label, tap])
		_expect(label == want_label, "it reads \"%s\"" % want_label)
		seen[label] = true
	_expect(seen.size() == 3, "the three verdicts are three DISTINCT strings")
	_expect(BattleTypes.strike_label(BattleTypes.Outcome.HIT, BattleTypes.Action.DODGE)
		!= BattleTypes.strike_label(BattleTypes.Outcome.HIT, BattleTypes.Action.NONE),
		"a mistimed dodge does not read as being caught standing")

# ---------------------------------------------------------------- PHASE D

## REPORTED, NEVER GATED. Caricature players with human timing error.
##
## n is deliberately large: at n=40 the binomial standard deviation is
## about 8 points, and lot 3 spent a whole tuning pass reading noise as
## signal because of it.
##
## BOTH SIDES ARE DRIVEN. The opponent runs the real FighterBrain wired
## exactly as BattleArena wires it; the player runs a caricature. A bench
## with only one brain measures a punching bag, which this project has
## already been caught by three times.
const POLICY_N := 300
const POLICY_CAP_TICKS := 3600

func _phase_d_imperfect() -> void:
	print("\n--- PHASE D: imperfect players, n=%d (reported, NOT gated) ---" % POLICY_N)
	print("  mash        : hammer ATTACK, never read anything")
	print("  dodge-only  : read the bar, dodge, never attack")
	print("  read+counter: read the bar, dodge, attack when free")
	for policy in ["mash", "dodge-only", "read+counter"]:
		var wins := 0
		var total := 0.0
		var longest := 0.0
		for i in POLICY_N:
			var r := _policy_fight(policy, 20260821 + i)
			total += r.y
			longest = maxf(longest, r.y)
			if r.x > 0.5:
				wins += 1
		print("  %-12s wins %3d/%d (%5.1f%%)  mean %5.1fs  max %5.1fs" % [
			policy, wins, POLICY_N, 100.0 * wins / POLICY_N, total / POLICY_N, longest])

## One fight. `policy` drives the player, the shipped brain drives the
## opponent. The player's tap lands at its aim plus a gaussian error --
## a policy that hits the same tick every time is the superhuman player
## lot 4 measured and lot 5 proved does not exist.
func _policy_fight(policy: String, fight_seed: int) -> Vector2:
	var player := _make(KeepyProfile)
	var opponent := _make(DummyProfile)
	var rng := RandomNumberGenerator.new()
	rng.seed = fight_seed
	var brain := FighterBrain.new()
	brain.setup(opponent, player, opponent.profile, rng)
	player.strike_activated.connect(func() -> void: opponent.receive_strike(player.profile.attack_damage))
	opponent.strike_activated.connect(func() -> void: player.receive_strike(opponent.profile.attack_damage))

	var aim: float = KeepyProfile.ai_dodge_aim
	var planned := -1
	var watching := false
	var t := 0
	while player.is_alive() and opponent.is_alive() and t < POLICY_CAP_TICKS:
		if policy == "mash":
			if player.is_free():
				player.request_action(BattleTypes.Action.ATTACK)
		elif opponent.is_charging():
			if not watching:
				watching = true
				var target: float = aim * opponent.profile.attack_windup_s + rng.randfn(0.0, HUMAN_JITTER)
				planned = t + maxi(int(round(target / TICK_S)), 0)
			if t == planned:
				player.request_action(BattleTypes.Action.DODGE)
		else:
			watching = false
			planned = -1
			if policy == "read+counter" and player.is_free():
				player.request_action(BattleTypes.Action.ATTACK)
		player.advance(TICK_S)
		opponent.advance(TICK_S)
		brain.advance(TICK_S)
		t += 1
	var won := 1.0 if not opponent.is_alive() else 0.0
	player.free()
	opponent.free()
	return Vector2(won, float(t) * TICK_S)

# ---------------------------------------------------------------- geometry

## Tick index, counted from the first tick of the WINDUP, at which the
## attack's strike actually resolves. Read off strike_activated from a
## real Fighter rather than summed out of the profile.
func _strike_tick() -> int:
	var f := _make(DummyProfile)
	var at := [-1]
	var n := [0]
	f.strike_activated.connect(func() -> void: at[0] = n[0])
	f.request_action(BattleTypes.Action.ATTACK)
	while at[0] < 0 and n[0] < 600:
		n[0] += 1
		f.advance(TICK_S)
	f.free()
	return at[0]

## Every tap tick at which a dodge actually produces a non-HIT outcome,
## measured by REALLY resolving the strike through receive_strike() --
## not by comparing spans. Returned as the contiguous band [first, last],
## with (-1, -1) for "never".
func _cover_band() -> Vector2i:
	var first := -1
	var last := -1
	for tap in 90:
		if _resolve(tap) != BattleTypes.Outcome.HIT:
			if first < 0:
				first = tap
			last = tap
	return Vector2i(first, last)

## One telegraph, one tap, one strike -- through the shipped classes.
func _resolve(tap: int) -> BattleTypes.Outcome:
	var attacker := _make(DummyProfile)
	var defender := _make(KeepyProfile)
	var outcome := [BattleTypes.Outcome.MISSED]
	attacker.strike_activated.connect(func() -> void:
		outcome[0] = defender.receive_strike(attacker.profile.attack_damage))
	attacker.request_action(BattleTypes.Action.ATTACK)
	for n in 240:
		if n == tap:
			defender.request_action(BattleTypes.Action.DODGE)
		attacker.advance(TICK_S)
		defender.advance(TICK_S)
		if outcome[0] != BattleTypes.Outcome.MISSED:
			break
	attacker.free()
	defender.free()
	return outcome[0]

## Like _resolve(), but returns BOTH what the strike produced and what
## the defender was committed to -- read off `hit_taken` itself, so this
## measures the signal the view and the HUD actually receive rather than
## re-deriving it here.
func _resolve_reported(defence: BattleTypes.Action, tap: int) -> Array:
	var attacker := _make(DummyProfile)
	var defender := _make(KeepyProfile)
	var got := [BattleTypes.Outcome.MISSED, BattleTypes.Action.NONE, false]
	defender.hit_taken.connect(func(_d: int, o: BattleTypes.Outcome, a: BattleTypes.Action) -> void:
		got[0] = o
		got[1] = a
		got[2] = true)
	attacker.strike_activated.connect(func() -> void:
		defender.receive_strike(attacker.profile.attack_damage))
	attacker.request_action(BattleTypes.Action.ATTACK)
	for n in 240:
		if n == tap and defence != BattleTypes.Action.NONE:
			defender.request_action(defence)
		attacker.advance(TICK_S)
		defender.advance(TICK_S)
		if got[2]:
			break
	attacker.free()
	defender.free()
	return got

## Two fighters, one dodged attack, and then a race: does the fighter
## that evaded land the next blow first? This is PHASE C's inequality
## measured instead of computed -- both sides simply attack the moment
## they are free after the exchange.
func _counter_lands(tap: int) -> bool:
	var attacker := _make(DummyProfile)
	var defender := _make(KeepyProfile)
	var first_hit := [""]
	attacker.strike_activated.connect(func() -> void:
		if defender.receive_strike(attacker.profile.attack_damage) == BattleTypes.Outcome.HIT \
				and first_hit[0].is_empty():
			first_hit[0] = "attacker")
	defender.strike_activated.connect(func() -> void:
		if attacker.receive_strike(defender.profile.attack_damage) == BattleTypes.Outcome.HIT \
				and first_hit[0].is_empty():
			first_hit[0] = "defender")
	attacker.request_action(BattleTypes.Action.ATTACK)
	for n in 400:
		if n == tap:
			defender.request_action(BattleTypes.Action.DODGE)
		elif n > tap:
			# Both sides now simply take the turn as soon as they can.
			if attacker.is_free():
				attacker.request_action(BattleTypes.Action.ATTACK)
			if defender.is_free():
				defender.request_action(BattleTypes.Action.ATTACK)
		attacker.advance(TICK_S)
		defender.advance(TICK_S)
		if not first_hit[0].is_empty():
			break
	var won: bool = first_hit[0] == "defender"
	attacker.free()
	defender.free()
	return won

func _span(band: Vector2i) -> int:
	return 0 if band.x < 0 else band.y - band.x + 1

func _report_band(label: String, band: Vector2i) -> void:
	if band.x < 0:
		print("  %-15s : NEVER covered" % label)
		return
	print("  %-15s : tap %2d..%2d ticks = %3.0f..%3.0f ms  (width %3.0f ms)" % [
		label, band.x, band.y,
		band.x * TICK_S * 1000.0, band.y * TICK_S * 1000.0, _span(band) * TICK_S * 1000.0])

# ---------------------------------------------------------------- helpers

func _make(profile: FighterProfile) -> Fighter:
	var fighter := FighterScene.instantiate() as Fighter
	fighter.profile = profile
	add_child(fighter)
	return fighter

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("    OK   %s" % label)
		return
	_failures += 1
	printerr("    FAIL %s" % label)
