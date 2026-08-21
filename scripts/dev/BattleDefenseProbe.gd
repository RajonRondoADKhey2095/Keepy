extends Node
## Dev-only: measures whether DEFENDING is a real option in Keepy Battle,
## from the point of view of a player who is NOT perfect.
##
## =====================================================================
## WHY THIS FILE EXISTS -- THE DEVICE CONTRADICTED THE PROBES, AND THE
## DEVICE WAS RIGHT
##
## Lot 4's probes reported guard succeeding 99.3% of the time and dodge
## 93.3%. On a phone, Mathieu reported the opposite: "guarding or dodging
## makes no sense, the damage is huge and you have no confidence it
## works -- if you want to win, you attack."
##
## Both were true, because they measured different players.
## BattleFeintProbe answers a telegraph at LATENCIES of 0.12, 0.18 and
## 0.24 s -- times a human cannot produce. Simple visual reaction time
## bottoms out near 0.25 s in a lab, and a tap on a phone adds touch
## digitiser and browser event latency on top: 0.30-0.45 s is the honest
## band for "see a telegraph, tap a button" through Safari on iOS.
##
## So the old probes were not wrong about their player. They were
## measuring a player who does not exist, and the one number that
## decides whether defence is viable -- HOW LATE CAN YOU BE AND STILL BE
## COVERED -- was never reported at all.
##
## This probe reports that number, and gates it.
##
## =====================================================================
## WHAT IS GATED AND WHAT IS ONLY REPORTED
##
## GATED (PHASE A, B, C): the geometry of the defensive windows. Those
## are arithmetic facts about the shipped .tres files -- "a guard tapped
## at 0.40 s after the telegraph starts is active when the blow lands"
## is either true or it is not, and if it stops being true the mechanic
## is silently dead again.
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
## seconds, measured from the first frame of the telegraph.
##
## 0.30 is a fast, attentive player who already knows the game. 0.45 is
## the same player a few minutes in, or anyone on a busy phone. This is
## NOT the lab figure for a bare reaction time (~0.25 s): a touchscreen
## adds digitiser sampling, and a browser adds event dispatch on top of
## whatever frame the canvas last drew.
##
## The gate below uses HUMAN_LATE. Passing at HUMAN_FAST only would mean
## the mechanic works for the one person who wrote it.
const HUMAN_FAST := 0.30
const HUMAN_TYPICAL := 0.38
const HUMAN_LATE := 0.45

var _failures := 0
var _checks := 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "BattleDefenseProbe")
	print("=== BATTLE DEFENCE VIABILITY PROBE ===")
	print("tick=%.6fs  attacker=%s  defender=%s" % [TICK_S, DummyProfile.display_name, KeepyProfile.display_name])
	print("human tap band: fast %.2fs / typical %.2fs / late %.2fs" % [HUMAN_FAST, HUMAN_TYPICAL, HUMAN_LATE])
	_phase_a_chronogram()
	_phase_b_tolerance()
	_phase_c_punishment()
	_phase_c2_punish_window()
	_phase_e_feedback()
	_phase_d_imperfect()
	print("\n--- %d check(s), %d failure(s) ---" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

# ---------------------------------------------------------------- PHASE A

## The chronogram the whole lot turns on: when the telegraph is visible,
## when the blow actually lands, and where a defensive ACTIVE window sits
## for a tap placed at a given moment.
##
## Every number is produced by RUNNING the shipped FSM, never by adding
## up fields from the .tres -- the two agree only as long as nothing in
## Fighter.gd carries an overshoot or clamps a phase, and it does both.
func _phase_a_chronogram() -> void:
	print("\n--- PHASE A: chronogram (ticks from telegraph start) ---")

	var plain := _strike_tick(BattleTypes.Action.ATTACK)
	var feint := _strike_tick(BattleTypes.Action.FEINT)
	var telegraph := _telegraph_ticks(BattleTypes.Action.ATTACK)

	print("  attacker telegraph visible : tick 0 .. %d  (%.0f ms)" % [telegraph, telegraph * TICK_S * 1000.0])
	print("  plain ATTACK lands at      : tick %d  (%.0f ms)" % [plain, plain * TICK_S * 1000.0])
	print("  held FEINT lands at        : tick %d  (%.0f ms)  [+%.0f ms]" % [
		feint, feint * TICK_S * 1000.0, (feint - plain) * TICK_S * 1000.0])

	_expect(plain > 0, "a plain attack lands after its telegraph")
	_expect(feint > plain, "a feint lands strictly later than a plain attack")
	_expect(telegraph <= plain, "the telegraph does not outlast the blow it announces")

	print("  defender window if tapped at tick T (ACTIVE span, ticks):")
	for tap in [0, 12, 18, 23, 27, 30, 36]:
		var g := _defence_span(BattleTypes.Action.GUARD, tap)
		var d := _defence_span(BattleTypes.Action.DODGE, tap)
		print("    T=%2d (%3.0f ms)  guard %2d..%2d %s%s   dodge %2d..%2d %s%s" % [
			tap, tap * TICK_S * 1000.0,
			g.x, g.y, _covers_mark(g, plain), _covers_mark(g, feint),
			d.x, d.y, _covers_mark(d, plain), _covers_mark(d, feint)])
	print("    (first mark = plain attack, second = held feint; + covered, - not)")

# ---------------------------------------------------------------- PHASE B

## The number the device report was really about: how late may the tap
## be. Reported in milliseconds against the human band, and GATED at
## HUMAN_LATE for the guard.
##
## Guard and dodge are held to DIFFERENT bars on purpose, and the
## difference is the whole risk/reward of this game:
##
##   * GUARD must be answerable on reaction, and must cover a plain
##     attack AND a held feint from the same tap. It is the safe option:
##     a player who cannot yet read a feint must still have something
##     that works.
##   * DODGE must NOT cover both. It is the read: it beats what you
##     correctly predicted and leaves you in recovery when you guessed
##     wrong. A dodge that covered everything would make guard pointless
##     and the feint decorative.
func _phase_b_tolerance() -> void:
	print("\n--- PHASE B: how late can the tap be (GATED) ---")

	var plain := _strike_tick(BattleTypes.Action.ATTACK)
	var feint := _strike_tick(BattleTypes.Action.FEINT)

	var g_plain := _cover_band(BattleTypes.Action.GUARD, BattleTypes.Action.ATTACK)
	var g_feint := _cover_band(BattleTypes.Action.GUARD, BattleTypes.Action.FEINT)
	var d_plain := _cover_band(BattleTypes.Action.DODGE, BattleTypes.Action.ATTACK)
	var d_feint := _cover_band(BattleTypes.Action.DODGE, BattleTypes.Action.FEINT)

	_report_band("guard vs plain", g_plain)
	_report_band("guard vs feint", g_feint)
	_report_band("dodge vs plain", d_plain)
	_report_band("dodge vs feint", d_feint)

	var g_both := _intersect(g_plain, g_feint)
	_report_band("guard vs BOTH", g_both)

	var late := _ticks(HUMAN_LATE)
	var fast := _ticks(HUMAN_FAST)

	_expect(_band_holds(g_plain, late), "guard tapped at %.0f ms still blocks a plain attack" % (HUMAN_LATE * 1000.0))
	_expect(_band_holds(g_feint, late), "guard tapped at %.0f ms still blocks a held feint" % (HUMAN_LATE * 1000.0))
	_expect(_band_holds(g_both, late), "one guard tap at %.0f ms covers plain AND feint" % (HUMAN_LATE * 1000.0))
	_expect(_band_holds(g_both, fast), "one guard tap at %.0f ms covers plain AND feint" % (HUMAN_FAST * 1000.0))
	_expect(_band_holds(d_plain, late), "dodge tapped at %.0f ms still evades a plain attack" % (HUMAN_LATE * 1000.0))

	# The feint has to stay a real read, or lot 4 is decoration. This is
	# the ONLY assertion here that wants something to FAIL: a reflex
	# dodge, thrown at the same moment that beats a plain attack, must
	# be caught by the held blow.
	_expect(not _band_holds(d_feint, fast), "a reflex dodge at %.0f ms is still punished by a feint" % (HUMAN_FAST * 1000.0))

	# And guard must not become strictly dominant either: it costs a
	# longer lockout and chip damage, which is what dodge buys out of.
	_expect(_span(g_both) > _span(d_feint), "guard's safe band is wider than dodge's feint read")

# ---------------------------------------------------------------- PHASE C

## Punishment. A defensive option nobody dares take is not an option, and
## the size of the mistake is what decides whether taking it is rational.
func _phase_c_punishment() -> void:
	print("\n--- PHASE C: cost of one mistake (GATED) ---")
	# CROSS-PAIR, not each profile against itself. What decides whether a
	# player dares take a risk is what the OTHER fighter's hit costs
	# them, and a self-referential ratio only happens to agree with that
	# while the two profiles carry the same numbers.
	for pair in [[KeepyProfile, DummyProfile], [DummyProfile, KeepyProfile]]:
		var defender: FighterProfile = pair[0]
		var attacker: FighterProfile = pair[1]
		var clean := int(ceil(float(defender.max_hp) / float(attacker.attack_damage)))
		var chip := int(ceil(float(attacker.attack_damage) * defender.guard_damage_ratio))
		var blocked := int(ceil(float(defender.max_hp) / float(maxi(chip, 1))))
		var share := float(attacker.attack_damage) / float(defender.max_hp)
		print("  %-10s hp %d vs %s's hit %d (%.0f%% of hp) -> %d clean hits to KO; blocked %d -> %d" % [
			defender.display_name, defender.max_hp, attacker.display_name,
			attacker.attack_damage, share * 100.0, clean, chip, blocked])
		_expect(clean >= 6, "%s survives at least 6 clean hits" % defender.display_name)
		_expect(share <= 0.18, "%s: one mistake costs at most 18%% of hp" % defender.display_name)
		_expect(chip >= 1, "%s: a blocked hit still chips" % defender.display_name)
		_expect(blocked > clean * 2, "%s: blocking is worth far more than eating it" % defender.display_name)

# --------------------------------------------------------------- PHASE C2

## THE RULE THAT MADE MASHING STOP WINNING, and the one lot 5 nearly
## missed by fixing only the guard windows.
##
## Widening the guard was necessary and not sufficient. With the windows
## fixed but the timings otherwise untouched, a player who did nothing
## but hammer ATTACK still won 300 fights out of 300 -- BETTER than
## before the fix. The reason is arithmetic, not tuning:
##
##   A fighter who blocks is locked out for its whole guard cycle. To
##   make the attacker pay for the exchange it then has to land a strike
##   of its own, which costs a full attack windup. If the attacker's
##   RECOVERY is shorter than (defender's remaining guard lockout +
##   defender's windup), the counter never arrives -- the attacker is
##   already covered by its next telegraph. Blocking becomes something
##   that merely delays you, and the correct strategy is to never stop
##   attacking.
##
## Lot 2 lengthened the telegraph and lot 5 lengthened it much further,
## which grew the left-hand side of that inequality every time without
## anybody growing the right-hand one. attack_recovery_s had been sized
## against a 0.30 s windup and was never re-sized.
##
## Gated, because it is the difference between "defence works" and
## "defence is a slower way to lose".
func _phase_c2_punish_window() -> void:
	print("\n--- PHASE C2: is a block actually punishable (GATED) ---")
	for pair in [[KeepyProfile, DummyProfile], [DummyProfile, KeepyProfile]]:
		var defender: FighterProfile = pair[0]
		var attacker: FighterProfile = pair[1]
		# Blocker comes free this long after the blow it absorbed. The
		# guard was tapped roughly a human latency into the telegraph, so
		# by the time the strike lands it is already part-way through its
		# active window.
		var guard_left := defender.guard_windup_s + defender.guard_active_s + defender.guard_recovery_s \
			- (attacker.attack_windup_s - HUMAN_TYPICAL)
		var counter_at := maxf(guard_left, 0.0) + defender.attack_windup_s
		var next_blow := attacker.attack_active_s + attacker.attack_recovery_s + attacker.attack_windup_s
		print("  %-10s blocks %-10s: free +%.2fs, counter lands +%.2fs, next blow +%.2fs  (margin %+.2fs)" % [
			defender.display_name, attacker.display_name,
			maxf(guard_left, 0.0), counter_at, next_blow, next_blow - counter_at])
		_expect(counter_at < next_blow,
			"%s can punish %s after blocking" % [defender.display_name, attacker.display_name])
		_expect(attacker.stagger_duration_s > attacker.attack_recovery_s,
			"%s: being hit is worse than whiffing" % attacker.display_name)

# ---------------------------------------------------------------- PHASE D

## The measurement lot 4's probes could not make: three caricature
## players, each with a REALISTIC and IMPRECISE tap, over enough fights
## that the answer is not noise.
##
## REPORTED, NEVER GATED -- see the header. The bar this lot is aiming
## at is written in the output rather than asserted: a defensive policy
## should beat the masher at every latency a human actually has.
##
## n is 300 per cell and not 40: lot 3 already paid for that lesson, the
## binomial standard deviation at n=40 is ~8 points and two configs a
## whole design apart looked identical.
func _phase_d_imperfect() -> void:
	print("\n--- PHASE D: imperfect players, n=300 per cell (reported) ---")
	print("  policy      latency  jitter   wins/300   round mean")
	var runs := 300
	for policy in [Policy.MASH, Policy.GUARD, Policy.DODGE, Policy.MIXED]:
		for latency in [HUMAN_FAST, HUMAN_TYPICAL, HUMAN_LATE]:
			var wins := 0
			var ticks := 0
			for i in runs:
				var r := _policy_fight(policy, latency, 0.09, 20260821 + i, 9000)
				if r.player_won:
					wins += 1
				ticks += r.ticks
			print("  %-10s  %4.0f ms  %3.0f ms   %3d/%d      %5.1fs" % [
				_policy_name(policy), latency * 1000.0, 90.0,
				wins, runs, float(ticks) / float(runs) * TICK_S])

# ---------------------------------------------------------------- PHASE E

## The four verdicts must be four verdicts, all the way to the channels a
## player actually perceives.
##
## Task C of lot 5: before this, a guard pressed 80 ms too late produced
## the SAME white flash and the SAME "TOUCHE" as pressing nothing at all.
## A player cannot learn a timing they get no error signal from, and an
## option nobody can learn is an option nobody takes -- which is exactly
## what "you have no confidence that it works" means.
##
## Gated at the source (`hit_taken` carries the attempted defence) and at
## the sink (BattleTypes.strike_label turns it into four distinct
## strings). The VIEW's four looks cannot be asserted headlessly -- there
## are no pixels -- so what is gated is the fact that FighterView is
## handed enough to tell them apart, which is the part that can silently
## regress.
func _phase_e_feedback() -> void:
	print("\n--- PHASE E: four outcomes, four verdicts (GATED) ---")

	var plain := _strike_tick(BattleTypes.Action.ATTACK)
	# A tap far too late to matter: the defence is still in WINDUP when
	# the blow lands. This is the case the device report was about.
	var late := plain + 2
	# A tap far too early: the window has already expired.
	var early := 0

	var cases := [
		[BattleTypes.Action.GUARD, _ticks(HUMAN_TYPICAL), BattleTypes.Outcome.BLOCKED, BattleTypes.Action.GUARD, "BLOQUE"],
		[BattleTypes.Action.DODGE, _ticks(HUMAN_TYPICAL), BattleTypes.Outcome.DODGED, BattleTypes.Action.DODGE, "ESQUIVE"],
		[BattleTypes.Action.GUARD, late, BattleTypes.Outcome.HIT, BattleTypes.Action.GUARD, "GARDE BRISEE"],
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
		print("    %-6s tap %2d -> outcome %d, attempted %d, \"%s\"" % [
			BattleTypes.action_label(defence) if defence != BattleTypes.Action.NONE else "(none)",
			tap, got[0], got[1], label])
		_expect(got[0] == want_outcome and got[1] == want_attempted,
			"%s at tick %d reports the right pair" % [want_label, tap])
		_expect(label == want_label, "it reads \"%s\"" % want_label)
		seen[label] = true
	_expect(seen.size() == 5, "the five verdicts are five DISTINCT strings")

	# The one that used to be invisible: a mistimed defence must not be
	# reported the same way as no input at all.
	_expect(BattleTypes.strike_label(BattleTypes.Outcome.HIT, BattleTypes.Action.GUARD)
		!= BattleTypes.strike_label(BattleTypes.Outcome.HIT, BattleTypes.Action.NONE),
		"a broken guard does not read as being caught standing")

## Like _resolve(), but returns BOTH what the strike produced and what the
## defender was committed to -- read off `hit_taken` itself, so this
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

# ---------------------------------------------------------------- geometry

## Tick index, counted from the first tick of the WINDUP, at which
## `action`'s strike actually resolves. Read off strike_activated from a
## real Fighter rather than summed out of the profile.
func _strike_tick(action: BattleTypes.Action) -> int:
	var f := _make(DummyProfile)
	var at := [-1]
	var n := [0]
	f.strike_activated.connect(func() -> void: at[0] = n[0])
	f.request_action(action)
	while at[0] < 0 and n[0] < 600:
		f.advance(TICK_S)
		n[0] += 1
	f.free()
	return at[0]

## How many ticks the anticipation POSE runs for -- telegraph_duration(),
## which a feint deliberately keeps equal to a plain attack's.
func _telegraph_ticks(action: BattleTypes.Action) -> int:
	var f := _make(DummyProfile)
	f.request_action(action)
	var d := f.telegraph_duration()
	f.free()
	# floor, not round: this is the number of COMPLETE ticks the pose
	# runs for, which is what the strike tick below is also counted in.
	return int(floor(d / TICK_S))

## The [first, last] tick indices during which a defence tapped at tick
## `tap` is in its ACTIVE window. Simulated, so the input buffer and the
## overshoot carry are both exercised exactly as they are in a fight.
func _defence_span(defence: BattleTypes.Action, tap: int) -> Vector2i:
	var f := _make(KeepyProfile)
	var first := -1
	var last := -1
	for n in 240:
		if n == tap:
			f.request_action(defence)
		if f.state == BattleTypes.State.ACTIVE and f.current_action == defence:
			if first < 0:
				first = n
			last = n
		f.advance(TICK_S)
	f.free()
	return Vector2i(first, last)

## Every tap tick at which `defence` actually produces a non-HIT outcome
## against `attack`, measured by REALLY resolving the strike through
## Fighter.receive_strike() -- not by comparing spans. Returned as the
## contiguous band [first, last], with (-1, -1) for "never".
func _cover_band(defence: BattleTypes.Action, attack: BattleTypes.Action) -> Vector2i:
	var first := -1
	var last := -1
	for tap in 90:
		if _resolve(defence, attack, tap) != BattleTypes.Outcome.HIT:
			if first < 0:
				first = tap
			last = tap
	return Vector2i(first, last)

## One telegraph, one tap, one strike -- through the shipped classes.
func _resolve(defence: BattleTypes.Action, attack: BattleTypes.Action, tap: int) -> BattleTypes.Outcome:
	var attacker := _make(DummyProfile)
	var defender := _make(KeepyProfile)
	var outcome := [BattleTypes.Outcome.MISSED]
	attacker.strike_activated.connect(func() -> void:
		outcome[0] = defender.receive_strike(attacker.profile.attack_damage))
	attacker.request_action(attack)
	for n in 240:
		if n == tap:
			defender.request_action(defence)
		attacker.advance(TICK_S)
		defender.advance(TICK_S)
		if outcome[0] != BattleTypes.Outcome.MISSED:
			break
	attacker.free()
	defender.free()
	return outcome[0]

func _covers_mark(span: Vector2i, at: int) -> String:
	return "+" if span.x >= 0 and at >= span.x and at <= span.y else "-"

func _band_holds(band: Vector2i, tap: int) -> bool:
	return band.x >= 0 and tap >= band.x and tap <= band.y

func _intersect(a: Vector2i, b: Vector2i) -> Vector2i:
	if a.x < 0 or b.x < 0:
		return Vector2i(-1, -1)
	var lo: int = maxi(a.x, b.x)
	var hi: int = mini(a.y, b.y)
	return Vector2i(lo, hi) if lo <= hi else Vector2i(-1, -1)

func _span(band: Vector2i) -> int:
	return 0 if band.x < 0 else band.y - band.x + 1

func _ticks(seconds: float) -> int:
	return int(round(seconds / TICK_S))

func _report_band(label: String, band: Vector2i) -> void:
	if band.x < 0:
		print("  %-15s : NEVER covered" % label)
		return
	print("  %-15s : tap %2d..%2d ticks = %3.0f..%3.0f ms  (width %3.0f ms)" % [
		label, band.x, band.y,
		band.x * TICK_S * 1000.0, band.y * TICK_S * 1000.0, _span(band) * TICK_S * 1000.0])

# ---------------------------------------------------------------- policies

enum Policy { MASH, GUARD, DODGE, MIXED }

func _policy_name(policy: Policy) -> String:
	match policy:
		Policy.MASH: return "masher"
		Policy.GUARD: return "guardian"
		Policy.DODGE: return "dodger"
		Policy.MIXED: return "mixed"
	return "?"

class PolicyResult:
	var player_won: bool = false
	var ticks: int = 0

## One fight: the opponent is driven by the REAL FighterBrain (exactly as
## BattleArena wires it), the player by a caricature policy with a
## realistic, IMPRECISE tap.
##
## The imprecision is the point. A policy that answers a telegraph on the
## exact same tick every time is the superhuman player lot 4 measured;
## here the answer lands at `latency + gauss(0, jitter)`, clamped at
## zero, drawn from the fight's own seeded rng. Nothing touches the
## global RNG, so a (policy, latency, seed) triple replays identically.
func _policy_fight(policy: Policy, latency: float, jitter: float, fight_seed: int, tick_cap: int) -> PolicyResult:
	var result := PolicyResult.new()
	var player := _make(KeepyProfile)
	var opponent := _make(DummyProfile)
	var rng := RandomNumberGenerator.new()
	rng.seed = fight_seed
	var brain := FighterBrain.new()
	brain.setup(opponent, player, opponent.profile, rng)

	player.strike_activated.connect(func() -> void: opponent.receive_strike(player.profile.attack_damage))
	opponent.strike_activated.connect(func() -> void: player.receive_strike(opponent.profile.attack_damage))

	# Armed when a telegraph appears; fires once, late by a random amount.
	var pending := -1
	var was_threatening := false

	while result.ticks < tick_cap and player.is_alive() and opponent.is_alive():
		var threatening := opponent.is_threatening()
		if threatening and not was_threatening and policy != Policy.MASH:
			var delay := latency + rng.randfn(0.0, jitter)
			pending = result.ticks + maxi(_ticks(delay), 0)
		was_threatening = threatening

		if policy == Policy.MASH:
			# No reading at all: hammer the one button, every time the
			# fighter is free. This is the strategy the device report
			# says currently wins, and it is the bar the others must beat.
			player.request_action(BattleTypes.Action.ATTACK)
		elif pending >= 0 and result.ticks >= pending:
			pending = -1
			player.request_action(_answer(policy, rng))
		elif player.state == BattleTypes.State.IDLE and not threatening:
			# Nothing incoming: take the turn. A defensive player who
			# never attacks cannot win, only survive, and a win rate for
			# a policy that cannot win measures nothing.
			player.request_action(BattleTypes.Action.ATTACK)

		player.advance(TICK_S)
		opponent.advance(TICK_S)
		brain.advance(TICK_S)
		result.ticks += 1

	result.player_won = not opponent.is_alive()
	player.free()
	opponent.free()
	return result

func _answer(policy: Policy, rng: RandomNumberGenerator) -> BattleTypes.Action:
	match policy:
		Policy.GUARD: return BattleTypes.Action.GUARD
		Policy.DODGE: return BattleTypes.Action.DODGE
		Policy.MIXED:
			return BattleTypes.Action.GUARD if rng.randf() < 0.7 else BattleTypes.Action.DODGE
	return BattleTypes.Action.ATTACK

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
