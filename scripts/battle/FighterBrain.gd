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
## Personality is FOUR NUMBERS on the profile (ai_reaction_delay_s,
## ai_reaction_jitter_s, ai_aggression, ai_defense_rate + ai_guard_bias),
## never a subclass. A new opponent's behaviour is a .tres edit.
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

	if _fighter.state != BattleTypes.State.IDLE:
		# Committed or staggered: the clock only runs while a decision is
		# actually available, so a stagger cannot be "slept through" and
		# answered the instant it ends.
		_armed = false
		return

	if not _armed:
		_armed = true
		_decision_left = _profile.ai_reaction_delay_s
		if _profile.ai_reaction_jitter_s > 0.0:
			_decision_left += _rng.randf_range(0.0, _profile.ai_reaction_jitter_s)
		return

	_decision_left -= dt
	if _decision_left > 0.0:
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
		return BattleTypes.Action.ATTACK
	return _defensive_action()

func _defensive_action() -> BattleTypes.Action:
	if _rng.randf() < _profile.ai_guard_bias:
		return BattleTypes.Action.GUARD
	return BattleTypes.Action.DODGE
