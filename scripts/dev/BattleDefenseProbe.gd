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
	_phase_r_riposte()
	_phase_r2_shipped()
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

	# =================================================================
	# LOT 8: "> 0" WAS THE WRONG BAR, AND THE MEASUREMENT SAYS SO
	#
	# Lot 7 satisfied the line above and published its margin: +13 ms at
	# the worst tap. A player cannot take a 13 ms opening -- they come
	# free, and then spend HUMAN_FAST..HUMAN_LATE before a finger lands.
	# The window has to be at least that wide or the punish exists only
	# on paper, which is what "j'esquive effectivement, mais je fais que
	# perdre" describes.
	#
	# Two floors, because two different things must be true:
	#   * the deterministic lead alone clears the FAST tap, so a quick
	#     player is punishing on the profiles alone;
	#   * the lead PLUS the opponent's minimum thinking time -- a hard
	#     floor, since ai_reaction_jitter_s is only ever added -- clears
	#     the LATE tap, so a slow player is punishing too.
	var guaranteed := worst_lead + DummyProfile.ai_reaction_delay_s
	print("  + the opponent's minimum think time (%.0f ms) = %.0f ms of guaranteed free time" % [
		DummyProfile.ai_reaction_delay_s * 1000.0, guaranteed * 1000.0])
	_expect(worst_lead >= HUMAN_FAST,
		"the lead alone clears a FAST human tap (%.0f ms >= %.0f ms)" % [
			worst_lead * 1000.0, HUMAN_FAST * 1000.0])
	_expect(guaranteed >= HUMAN_LATE,
		"lead + minimum think time clears a LATE human tap (%.0f ms >= %.0f ms)" % [
			guaranteed * 1000.0, HUMAN_LATE * 1000.0])
	# Measured rather than derived: the two fighters are actually run, and
	# the one that dodged has to land the next blow.
	var counter := _counter_lands(int(round(0.70 * DummyProfile.attack_windup_s / TICK_S)))
	print("  a dodge at 70%% of the bar, then a counter : %s" % ("LANDS" if counter else "does not land"))
	_expect(counter, "and the counter really lands, run through the shipped FSM")

# --------------------------------------------------------------- PHASE C2

## GATED, AND RESCOPED AT LOT 8 -- read this before "fixing" it.
##
## Through lot 7 this asserted stagger_duration_s > every recovery, on the
## reasoning that being hit must cost more TEMPO than whiffing. That was
## the right question while every clean hit staggered, because tempo was
## then the entire cost of being hit.
##
## It is not any more. Only a RIPOSTE staggers; an ordinary hit is damage
## and nothing else. So the old inequality now compares a riposte's
## stagger against a recovery that lot 8 had to lengthen to pay for the
## punish window, and it FAILS -- 700 ms against Sparring's 950 ms.
##
## Satisfying it was tried and measured, not waved away: raising the
## staggers past those recoveries hands the fight to a player who simply
## holds dodge, because one lucky riposte then locks the opponent out
## long enough to set up the next. Dodge-spam went from 0% to 100%. The
## number is published in CLAUDE.md rather than tuned around.
##
## What IS gated instead is the invariant that actually keeps the two
## strike kinds apart, and it is the one a future lot would break by
## accident: a riposte has to cost strictly more than a chip, on both
## axes. Flatten either and the reward for reading the bar disappears
## while every other probe here stays green.
func _phase_c2_stagger() -> void:
	print("\n--- PHASE C2: a riposte costs strictly more than a chip (GATED) ---")
	for entry in [["Keepy", KeepyProfile], ["Sparring", DummyProfile]]:
		var label: String = entry[0]
		var p: FighterProfile = entry[1]
		print("  %-9s chip %d dmg (no stagger) vs riposte %d dmg + %.0f ms stagger" % [
			label, p.attack_damage, p.riposte_damage, p.stagger_duration_s * 1000.0])
		_expect(p.riposte_damage > p.attack_damage,
			"%s: a riposte hurts more than a blind hit" % label)
		_expect(p.stagger_duration_s > 0.0,
			"%s: and it costs the target tempo a blind hit does not" % label)
		var worst_recovery: float = maxf(p.attack_recovery_s, p.dodge_recovery_s)
		print("    (reported, no longer gated: stagger %.0f ms vs longest recovery %.0f ms)" % [
			p.stagger_duration_s * 1000.0, worst_recovery * 1000.0])

# ---------------------------------------------------------------- PHASE R

## GATED. THE CONTRACT LOT 8 EXISTS FOR: a successful dodge has to pay.
##
## Everything before this phase measures that the player CAN dodge and
## that the opponent is left open afterwards. Neither is worth anything
## if the opening cannot be converted, and through lot 7 it could not be:
## the reward was 13 ms of tempo spent on a counter that was itself a
## 900 ms telegraph the opponent simply read and evaded.
##
## The riposte replaces that. Four properties, each of which silently
## deletes the mechanic if it stops holding:
##   1. it is EARNED by a real evade and by nothing else;
##   2. the window is long enough for a human to spend;
##   3. it is spendable -- the window survives the dodge lockout that
##      earned it, which is the specific way a naive implementation
##      fails;
##   4. it is spent ONCE.
func _phase_r_riposte() -> void:
	print("\n--- PHASE R: a successful dodge pays (GATED) ---")
	var window: float = KeepyProfile.riposte_window_s
	print("  riposte window %.0f ms of FREE time; chip %d dmg -> riposte %d dmg" % [
		window * 1000.0, KeepyProfile.attack_damage, KeepyProfile.riposte_damage])
	_expect(window >= HUMAN_LATE,
		"the window outlasts a LATE human tap (%.0f ms >= %.0f ms)" % [
			window * 1000.0, HUMAN_LATE * 1000.0])

	# (1) earned only by an evade that really covered a blow.
	var band := _cover_band()
	var mid := int((band.x + band.y) / 2)
	var f := _measure_riposte(mid)
	_expect(bool(f[0]), "a dodge that covered the blow earns a riposte")
	var early := _measure_riposte(0)
	_expect(not bool(early[0]), "a dodge tapped far too early earns nothing")

	# (3) SPENDABLE. The dodge that earned it locks its owner up for the
	# rest of the dodge cycle; if the window were charged for that lockout
	# the reward would be mostly gone before the player could move. Ticks
	# of window left AT THE MOMENT THE FIGHTER COMES FREE is the number
	# that matters, and it is read off the shipped FSM.
	var free_ms: float = float(f[1]) * TICK_S * 1000.0
	print("  window still open when the dodger comes free : %.0f ms" % free_ms)
	_expect(free_ms >= HUMAN_LATE * 1000.0,
		"a LATE human tap still finds the riposte up (%.0f ms >= %.0f ms)" % [
			free_ms, HUMAN_LATE * 1000.0])

	# (4) one dodge, one riposte.
	var once := _make(KeepyProfile)
	_hold_in_active_dodge(once)
	once.receive_strike(1, false)
	_expect(once.is_riposte_ready(), "riposte armed")
	while not once.is_free():
		once.advance(TICK_S)
	once.request_action(BattleTypes.Action.ATTACK)
	_expect(once.attack_is_riposte(), "the next attack IS the riposte")
	_expect(not once.is_riposte_ready(), "and it is spent -- a dodge cannot bank two")
	once.free()

## GATED, ON THE SHIPPED SCENE. Everything above builds its own fighters,
## which is the fixture this repo has already been burned by: a rule can
## be true of two Fighters a probe wired together and false of the arena
## the player actually plays. So the riposte is also resolved once
## through Battle.tscn itself -- real scene, real BattleArena pricing,
## real signal wiring.
func _phase_r2_shipped() -> void:
	print("\n--- PHASE R2: the riposte through the SHIPPED arena (GATED) ---")
	var arena := load("res://scenes/Battle.tscn").instantiate() as BattleArena
	add_child(arena)
	arena.set_process(false)
	var player: Fighter = arena.player
	var opponent: Fighter = arena.opponent
	var before: int = opponent.hp

	# Chip first: an ordinary tap, priced and staggered by the arena.
	player.request_action(BattleTypes.Action.ATTACK)
	for i in 4:
		arena._tick(TICK_S)
	var chip: int = before - opponent.hp
	print("  blind attack through the arena : %d dmg, opponent state %d" % [
		chip, opponent.state])
	_expect(chip == KeepyProfile.attack_damage, "a blind attack costs attack_damage")
	_expect(opponent.state != BattleTypes.State.STAGGER, "and does not stagger the opponent")

	# Now arm a riposte on the player and take the same tap.
	while not player.is_free():
		arena._tick(TICK_S)
	player.receive_strike(0, false)  # no-op damage; used only to reach a clean state
	var mid_hp: int = opponent.hp
	_force_riposte(player)
	player.request_action(BattleTypes.Action.ATTACK)
	for i in 4:
		arena._tick(TICK_S)
	var hit: int = mid_hp - opponent.hp
	print("  riposte through the arena      : %d dmg, opponent state %d" % [
		hit, opponent.state])
	_expect(hit == KeepyProfile.riposte_damage, "a riposte costs riposte_damage")
	_expect(opponent.state == BattleTypes.State.STAGGER, "and DOES stagger the opponent")
	arena.free()

## Arms a riposte the only way the game ever does -- by making a real
## dodge cover a real blow -- so nothing here can arm a state the fight
## cannot reach.
func _force_riposte(fighter: Fighter) -> void:
	fighter.request_action(BattleTypes.Action.DODGE)
	while fighter.state != BattleTypes.State.ACTIVE:
		fighter.advance(TICK_S)
	fighter.receive_strike(0, false)
	while not fighter.is_free():
		fighter.advance(TICK_S)

func _hold_in_active_dodge(fighter: Fighter) -> void:
	fighter.request_action(BattleTypes.Action.DODGE)
	var n := 0
	while fighter.state != BattleTypes.State.ACTIVE and n < 240:
		fighter.advance(TICK_S)
		n += 1

## Runs one telegraph with a dodge tapped at `tap`, and reports
## [earned a riposte, ticks of window left when the dodger came free].
func _measure_riposte(tap: int) -> Array:
	var attacker := _make(DummyProfile)
	var defender := _make(KeepyProfile)
	attacker.strike_activated.connect(func() -> void:
		var rip := attacker.attack_is_riposte()
		defender.receive_strike(attacker.profile.damage_for(rip), rip))
	attacker.request_action(BattleTypes.Action.ATTACK)
	var earned := false
	var left := 0
	for n in 400:
		if n == tap:
			defender.request_action(BattleTypes.Action.DODGE)
		attacker.advance(TICK_S)
		defender.advance(TICK_S)
		if defender.is_riposte_ready():
			earned = true
		if earned and defender.is_free():
			# Count the window down from here -- FREE ticks only, which is
			# exactly what the player gets to react in.
			while defender.is_riposte_ready() and left < 600:
				defender.advance(TICK_S)
				left += 1
			break
	attacker.free()
	defender.free()
	return [earned, left]

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
	print("  EVERY tap below costs a human reaction of %.0f..%.0f ms, drawn per tap." % [
		HUMAN_FAST * 1000.0, HUMAN_LATE * 1000.0])
	print("  Lot 7's bench let the counter fire on the same tick the fighter came free,")
	print("  which is a machine, not a person -- and it is why its reader read 98.7%.")
	print("  mash         : hammer ATTACK, never read anything")
	print("  dodge-only   : read the bar, dodge, never attack")
	print("  panic-dodge  : tap dodge the instant a bar appears, then attack")
	print("  read+riposte : read the BAND, dodge, cash the riposte")
	print("  ...sloppy    : the same player reading only 3 telegraphs in 4, at 140 ms jitter")
	print("  A PERFECT reader wins essentially every fight, and that is a machine, not a")
	print("  person: it reads every bar and never mistimes. The sloppy row is the margin --")
	print("  it is what the same strategy is worth once the reads stop being free.")
	for policy in ["mash", "dodge-only", "panic-dodge", "read+riposte", "read+riposte-sloppy"]:
		var wins := 0
		var total := 0.0
		var longest := 0.0
		for i in POLICY_N:
			var r := _policy_fight(policy, 20260821 + i)
			total += r.y
			longest = maxf(longest, r.y)
			if r.x > 0.5:
				wins += 1
		print("  %-20s wins %3d/%d (%5.1f%%)  mean %5.1fs  max %5.1fs" % [
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
	player.strike_activated.connect(func() -> void:
		var rip := player.attack_is_riposte()
		opponent.receive_strike(player.profile.damage_for(rip), rip))
	opponent.strike_activated.connect(func() -> void:
		var rip := opponent.attack_is_riposte()
		player.receive_strike(opponent.profile.damage_for(rip), rip))

	var aim: float = KeepyProfile.ai_dodge_aim
	# A sloppy player misses reads outright and is looser on the ones they
	# take. Both, because they fail differently: a missed read is a blow
	# taken clean, a loose one is "ESQUIVE RATEE".
	var sloppy := policy.ends_with("-sloppy")
	var jitter := 0.14 if sloppy else HUMAN_JITTER
	var read_rate := 0.75 if sloppy else 1.0
	var reads := true
	var planned := -1
	var watching := false
	var tapped := false
	# Ticks this player still owes before an OFFENSIVE tap can land. Drawn
	# fresh every time they come free: a person notices they can move
	# again, and only then presses. Lot 7's bench had no such term, and
	# that single omission is the whole gap between its 98.7% reader and
	# the device report.
	var think := -1
	var t := 0
	while player.is_alive() and opponent.is_alive() and t < POLICY_CAP_TICKS:
		if not player.is_free():
			think = -1
		elif think < 0:
			think = maxi(int(round(rng.randf_range(HUMAN_FAST, HUMAN_LATE) / TICK_S)), 0)
		var may_attack := player.is_free() and think == 0

		if policy == "mash":
			if player.is_free():
				player.request_action(BattleTypes.Action.ATTACK)
		elif opponent.is_charging():
			if policy == "panic-dodge":
				# No reading at all: tap the moment the bar appears. The
				# dodge window has long expired by the time the blow lands.
				if not tapped:
					tapped = true
					player.request_action(BattleTypes.Action.DODGE)
			else:
				if not watching:
					watching = true
					reads = rng.randf() < read_rate
					var target: float = aim * opponent.profile.attack_windup_s + rng.randfn(0.0, jitter)
					planned = t + maxi(int(round(target / TICK_S)), 0)
				if reads and t == planned:
					player.request_action(BattleTypes.Action.DODGE)
			# A riposte in hand is worth more than the dodge that would
			# hedge the incoming blow -- it staggers, so it cancels the
			# telegraph outright. Measured: a player who does NOT know
			# this went from 100% to 1.7% at lot 7's 13 ms punish window,
			# and the window this lot ships is what closes that gap.
			if may_attack and player.is_riposte_ready() and policy.begins_with("read+riposte"):
				player.request_action(BattleTypes.Action.ATTACK)
		else:
			watching = false
			tapped = false
			planned = -1
			if may_attack and policy != "dodge-only":
				player.request_action(BattleTypes.Action.ATTACK)
		if think > 0:
			think -= 1
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
		var rip := attacker.attack_is_riposte()
		outcome[0] = defender.receive_strike(attacker.profile.damage_for(rip), rip))
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
		var rip := attacker.attack_is_riposte()
		defender.receive_strike(attacker.profile.damage_for(rip), rip))
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
		var rip := attacker.attack_is_riposte()
		if defender.receive_strike(attacker.profile.damage_for(rip), rip) == BattleTypes.Outcome.HIT \
				and first_hit[0].is_empty():
			first_hit[0] = "attacker")
	defender.strike_activated.connect(func() -> void:
		var rip := defender.attack_is_riposte()
		if attacker.receive_strike(defender.profile.damage_for(rip), rip) == BattleTypes.Outcome.HIT \
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
