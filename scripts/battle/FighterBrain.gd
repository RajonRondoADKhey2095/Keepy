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
## this class can do, a player can do with three taps, and everything a
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
## ai_reaction_jitter_s, ai_aggression, ai_defense_rate, ai_guard_bias
## and, since lot 4, ai_feint_rate), never a subclass. A new opponent's
## behaviour is a .tres edit.
##
## =====================================================================
## THE FEINT NEEDS NO MACHINERY IN HERE, AND THAT IS DELIBERATE
##
## A feint is ONE action (FighterProfile: an attack whose strike is held
## back), so choosing it is a single roll in _offensive_action() and
## nothing else -- no queued second beat, no state to unwind if it gets
## interrupted, no branch that can leave this class waiting for a follow
## up that a stagger cancelled. An earlier design made it a two-beat
## combo and needed all of that; it was also measured not to work, for
## reasons written up in FighterProfile.gd.
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

func setup(fighter: Fighter, opponent: Fighter, profile: FighterProfile, rng: RandomNumberGenerator) -> void:
	_fighter = fighter
	_opponent = opponent
	_profile = profile
	_rng = rng
	reset()

func reset() -> void:
	_decision_left = 0.0
	_armed = false

func advance(dt: float) -> void:
	if _fighter == null or _opponent == null or _profile == null or _rng == null:
		return
	if not _fighter.is_alive() or not _opponent.is_alive():
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
	_fighter.request_action(_choose())

## The whole decision. Two branches, both driven by profile numbers.
func _choose() -> BattleTypes.Action:
	if _opponent.is_threatening():
		if _rng.randf() < _profile.ai_defense_rate:
			return _defensive_action()
		# Chose to trade rather than defend. A clean read by the player
		# beats this, which is exactly what ai_defense_rate < 1.0 buys:
		# an opponent that is readable and beatable, not one that
		# answers every windup perfectly.
		return BattleTypes.Action.ATTACK

	if _rng.randf() < _profile.ai_aggression:
		return _offensive_action()
	return _defensive_action()

## An offensive commitment: the real thing, or the lie that borrows its
## telegraph. The roll happens ONLY here, on the branch where the
## opponent is not already attacking -- feinting into an incoming attack
## would mean eating the hit to sell a bluff nobody is in a position to
## fall for, since the opponent is committed to its own action anyway.
##
## Draws from the same seeded rng as every other decision, so a feint is
## part of the reproducible fight rather than a source of noise on top
## of it.
func _offensive_action() -> BattleTypes.Action:
	# Only bluff someone who is in a position to be bluffed. See
	# Fighter.is_free() for the measurement that put this condition in
	# code instead of in a comment.
	if _profile.ai_feint_rate <= 0.0 or _opponent.is_free():
		return BattleTypes.Action.ATTACK
	if _rng.randf() < _profile.ai_feint_rate:
		return BattleTypes.Action.FEINT
	return BattleTypes.Action.ATTACK

func _defensive_action() -> BattleTypes.Action:
	if _rng.randf() < _profile.ai_guard_bias:
		return BattleTypes.Action.GUARD
	return BattleTypes.Action.DODGE
