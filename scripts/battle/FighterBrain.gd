extends RefCounted
class_name FighterBrain
## The AI, in full: a selector that decides WHICH action to request and
## WHEN, then calls Fighter.request_action() -- the same function a human
## tap goes through.
##
## =====================================================================
## WHAT THIS DELIBERATELY IS NOT
##
## It is not a second combat system. It owns no state machine, no
## timings, no damage rule and no notion of hit resolution: all of that
## belongs to Fighter and is identical for both combatants. Everything
## this class can do, a player can do with two taps, and everything a
## player can do, this class can do. Give it the player's Fighter and it
## plays that side; give the player's taps to the AI's Fighter and that
## side becomes human. Nothing else changes.
##
## The reason is not elegance. An AI with its own timings is an AI that
## can be tuned against rules the player is not playing by, and the
## divergence stays invisible until someone measures it -- which is the
## failure mode CLAUDE.md already records for a probe fixture that
## matched the real thing everywhere except the one axis that mattered.
##
## Personality is NUMBERS on the profile (ai_reaction_delay_s,
## ai_reaction_jitter_s, ai_aggression, ai_defense_rate), never a
## subclass. A new opponent's behaviour is a .tres edit.
##
## =====================================================================
## LOT 7 SHRANK THIS FILE BY DELETING TWO FUNCTIONS, NOT BY ADDING ONE
##
## With GUARD and FEINT gone, `_offensive_action()` and
## `_defensive_action()` each had exactly one reachable return value.
## They are inlined rather than kept as one-branch helpers: a function
## whose body cannot vary is a decision point that no longer exists, and
## leaving it in place invites a future reader to look for the choice it
## implies. The whole decision is now the two rolls in `_choose()`.
##
## =====================================================================
## THE BRAIN READS THE CHARGE BAR, AND IT HAS TO
##
## An earlier draft of lot 7 withheld Fighter.charge_progress() from this
## class, on the reasoning that the bar is "information for the human
## eye". Measured, that was wrong, and wrong in this file's own
## characteristic way: a player who hammers ATTACK and nothing else won
## 294 fights out of 300 against it, because a brain that cannot see the
## bar taps its dodge as soon as it notices a telegraph -- typically far
## too early -- and its window has expired by the time the blow lands.
##
## The bar is on screen. The player HAS it. An opponent denied it is not
## a harder or easier opponent, it is an opponent playing a different
## game -- which breaks the promise in this header and, worse, makes
## every balance number in this project a measurement against a proxy
## that cannot do what a person does. That is the SubstituteModel failure
## again, one lot after the last one.
##
## =====================================================================
## LOT 8: AGAINST AN INSTANT ATTACKER THERE IS NOTHING LEFT TO READ
##
## LOT 11 UPDATE: this is no longer just the player's case. Every combat
## field is now equal between profiles, and measurement picked a shared
## ZERO wind-up (see FighterProfile.gd's lot-11 header) -- so everything
## below is true of BOTH fighters attacking, not one.
##
## The player's attack now has a zero-length wind-up, so `is_charging()`
## is never true for them, so the `_dodge_aim` path below is UNREACHABLE
## against the shipped player. Nothing replaces it: an instant blow has
## no telegraph, and no amount of AI would make one appear. The brain
## therefore falls back to a blind dodge -- a guess -- which is exactly
## what a person facing an unreactable attack has, and precisely why
## keepy.tres prices that attack as a chip rather than a blow.
##
## Measured rather than assumed: with the bar gone from the player, a
## mashing player wins 11% instead of the 294-out-of-300 that a blind
## brain conceded at lot 7. The difference is not smarter AI, it is that
## an ordinary hit no longer cancels the telegraph it lands on, so the
## opponent's blow completes and the trade is real.
##
## The path is KEPT, not deleted: it is the brain's behaviour against any
## telegraphed opponent, which is what it faces the moment BattleArena's
## wiring is mirrored -- BattleContractProbe PHASE E does exactly that.
##
## So the brain reads it, WITH HUMAN-LIKE ERROR: it draws a target bar
## fraction once per telegraph (ai_dodge_aim, spread by ai_dodge_slop)
## and taps when the fill crosses it. What it still cannot do is anything
## a player cannot: it does not know the opponent's timings, it cannot
## see the exact millisecond, and it pays its reaction delay before it
## even starts watching.
##
## =====================================================================
## DETERMINISM
##
## Every random draw goes through the RandomNumberGenerator handed in by
## BattleArena, which is seeded explicitly. `randf()`, `randi()` and the
## global seed are never touched -- so a given (seed, tap sequence) plays
## out identically every time, which is what makes this lot's balance
## measurable at all rather than anecdotal.
##
## Like Fighter, this is advanced by the arena's fixed-step loop. It is a
## RefCounted, not a Node: it has no transform, no children and nothing
## to draw, and keeping it out of the tree means it cannot accidentally
## acquire a _process of its own.

var _fighter: Fighter = null
var _opponent: Fighter = null
var _profile: FighterProfile = null
var _rng: RandomNumberGenerator = null

## Seconds left before the next decision. Armed when the fighter is IDLE
## and re-armed after every commitment, so "reaction delay" is measured
## from the moment this fighter could actually act -- not from a global
## metronome that would let it answer instantly if a decision happened to
## come due mid-recovery.
var _decision_left: float = 0.0
var _armed: bool = false
## A dodge decided but not yet spent: the bar fraction this fighter is
## waiting for. Negative means "no dodge planned".
##
## Held rather than tapped straight away, because tapping on the DECISION
## is what makes a dodge miss -- the decision lands wherever the reaction
## clock happened to expire, and the window is only dodge_active_s wide.
## This is the AI equivalent of a player watching the fill and waiting.
var _dodge_aim: float = -1.0

func setup(fighter: Fighter, opponent: Fighter, profile: FighterProfile, rng: RandomNumberGenerator) -> void:
	_fighter = fighter
	_opponent = opponent
	_profile = profile
	_rng = rng
	reset()

func reset() -> void:
	_decision_left = 0.0
	_armed = false
	_dodge_aim = -1.0

func advance(dt: float) -> void:
	if _fighter == null or _opponent == null or _profile == null or _rng == null:
		return
	if not _fighter.is_alive() or not _opponent.is_alive():
		return

	# A dodge is already decided and waiting for the bar. Spend it, drop
	# it, or keep waiting -- and do all three BEFORE the reaction clock
	# below, so a plan cannot be overwritten by a fresh decision it has
	# not yet had a chance to act on.
	if _dodge_aim >= 0.0:
		if not _opponent.is_charging():
			# The telegraph ended without this fighter getting its tap in
			# -- the blow has landed, or a stagger cancelled it. Either
			# way the plan is stale; holding it would fire a dodge into
			# an empty stretch of the fight.
			_dodge_aim = -1.0
		elif _opponent.charge_progress() >= _dodge_aim:
			_dodge_aim = -1.0
			_fighter.request_action(BattleTypes.Action.DODGE)
			return
		else:
			return

	# THE REACTION CLOCK RUNS CONTINUOUSLY -- IT IS NEVER RESET BY THE
	# FIGHTER'S OWN STATE. Read the block below before changing that.
	#
	# =================================================================
	# WHY, AND WHAT IT COST TO FIND OUT (lot 4, measured)
	#
	# Before lot 4 this clock was cleared on every non-IDLE tick, so the
	# brain paid its full ai_reaction_delay_s AFTER each of its own
	# actions and AFTER every stagger, never during them. Its real
	# cadence was therefore action_length + delay, not max(the two) --
	# and against the shipped profiles the arithmetic simply never
	# closed. A player who mashed ATTACK and nothing else won 300 fights
	# out of 300 in 3.4 s, stun-locking the opponent from the first
	# clean hit, because stagger 0.55 + delay 0.36..0.66 + a guard
	# windup 0.08 always exceeded the 0.78 s attack cycle coming at it.
	#
	# That was NOT reachable by tuning, and it was measured rather than
	# assumed: the mash still won 120 out of 120 at attack_recovery_s of
	# 0.36, 0.44, 0.52, 0.60 AND 0.70. No .tres edit fixes it, because
	# the defect was never in the combat rules.
	#
	# It was this file breaking the promise in its own header --
	# "everything a player can do, this class can do". A human thinks
	# during their own recovery and during a stagger, and taps into
	# Fighter's 0.16 s input buffer so the answer is already committed
	# the instant they are free. The brain could do neither, so the two
	# sides were playing different games on precisely the axis that
	# decided the match: the divergence-you-only-find-by-measuring this
	# project has already paid for once (CLAUDE.md, SubstituteModel).
	#
	# What this is NOT: free actions. The delay is still charged in
	# full, every decision still goes through the same _choose(), and
	# nothing can be acted on before the fighter is genuinely IDLE. The
	# clock now measures the MINIMUM SPACING between decisions, which is
	# what a reaction time actually is, instead of a penalty bolted onto
	# the end of every commitment.
	if not _armed:
		_armed = true
		_decision_left = _profile.ai_reaction_delay_s
		if _profile.ai_reaction_jitter_s > 0.0:
			_decision_left += _rng.randf_range(0.0, _profile.ai_reaction_jitter_s)
		return

	_decision_left -= dt
	if _decision_left > 0.0:
		return

	# Decided, but still committed or stunned: hold it and spend it on
	# the first free tick. Requesting it here instead would push it into
	# Fighter's input buffer, where it expires after INPUT_BUFFER_S and
	# is silently lost whenever the remaining lockout is longer -- the
	# answer would vanish for exactly the reason it was needed.
	if _fighter.state != BattleTypes.State.IDLE:
		return

	_armed = false
	var action := _choose()
	if action == BattleTypes.Action.DODGE and _opponent.is_charging():
		# Do not tap yet: watch the bar and tap when it reaches the mark.
		# The mark is drawn ONCE per telegraph, from the seeded rng, so a
		# replayed fight replays the same imprecision too.
		_dodge_aim = clampf(
			_profile.ai_dodge_aim + _rng.randf_range(-_profile.ai_dodge_slop, _profile.ai_dodge_slop),
			0.0, 1.0)
		return
	_fighter.request_action(action)

## The whole decision. Two rolls, both driven by profile numbers.
##
## Note what the first branch is NOT doing: it answers "an attack is
## coming" and never "it lands in 0.31 s". The brain commits on the
## coarse signal and then lives with its timing exactly as a player does,
## which is what keeps ai_defense_rate an honest difficulty dial rather
## than a switch between blind and omniscient.
func _choose() -> BattleTypes.Action:
	# A riposte is owed: spend it. Read off THIS fighter's own state, which
	# is the same thing the player is shown, so the AI plays the loop the
	# game teaches rather than a private one. Placed first because an
	# unspent riposte expires -- hesitating with one in hand is strictly
	# worse than any other choice available on this tick.
	if _fighter.is_riposte_ready():
		return BattleTypes.Action.ATTACK

	if _opponent.is_threatening():
		if _rng.randf() < _profile.ai_defense_rate:
			return BattleTypes.Action.DODGE
		# Chose to trade rather than evade. A clean read by the player
		# beats this, which is exactly what ai_defense_rate < 1.0 buys:
		# an opponent that is readable and beatable, not one that
		# answers every wind-up perfectly.
		return BattleTypes.Action.ATTACK

	if _rng.randf() < _profile.ai_aggression:
		return BattleTypes.Action.ATTACK
	return BattleTypes.Action.DODGE
