extends RefCounted
class_name BattleTypes
## Shared vocabulary of Keepy Battle: the combat FSM's states, the three
## actions, and the outcome of one strike resolution.
##
## Lives in its own file rather than inside Fighter.gd for one structural
## reason: the HUD, the AI brain and the arena all speak this vocabulary,
## and none of them should have to depend on the Fighter class just to
## name a state. A UI script that has to `preload("Fighter.gd")` to read
## an enum is a UI script that can quietly grow a reference to combat
## logic -- exactly the coupling this lot's "zero business logic in UI"
## rule exists to prevent.
##
## Nothing here is per-fighter. Everything that differs between two
## combatants lives in FighterProfile (a .tres), never in an enum.

## The combat FSM. ONE machine, driven identically whether a human tap or
## the AI brain pushed the action in -- see Fighter.request_action().
##
##   IDLE      accepts a new action (and only IDLE does)
##   WINDUP    committed, telegraph phase, still vulnerable
##   ACTIVE    the action's effect window (a strike lands, a guard blocks,
##             a dodge evades) -- this is the whole timing game
##   RECOVERY  committed, cannot act, punishable
##   STAGGER   hit clean; cancels whatever was in progress
##   KO        terminal
enum State {
	IDLE,
	WINDUP,
	ACTIVE,
	RECOVERY,
	STAGGER,
	KO,
}

## The three tap zones, and the three things a fighter can commit to.
## NONE is the resting action carried while IDLE/STAGGER/KO, so
## `current_action` is never a null-ish special case to guard against.
## FEINT is the opponent-only fourth commitment (lot 4). It is NOT a
## fourth tap zone: BattleHUD emits three actions and only three, so a
## human never requests it. It exists so an attack telegraph can turn out
## to have been a lie -- see Fighter._advance_phase(), which routes it
## WINDUP -> RECOVERY with no effect window at all.
enum Action {
	NONE,
	ATTACK,
	GUARD,
	DODGE,
	FEINT,
}

## What one strike resolution produced, reported to the HUD so a player
## can tell "my guard worked" from "I got hit anyway".
enum Outcome {
	HIT,      ## Clean: full damage, defender staggers.
	BLOCKED,  ## Defender was in GUARD's active window: chip damage, no stagger.
	DODGED,   ## Defender was in DODGE's active window: no damage at all.
	MISSED,   ## Defender was already KO -- resolution is a no-op.
}

## The two commitments that open on an attack telegraph. Defined ONCE
## here, in the vocabulary every layer already speaks, so "what looks
## like an attack" has a single answer that the FSM (Fighter.
## is_threatening) and the view layer (FighterView._windup) both defer
## to. Two separate `== ATTACK or == FEINT` tests would be two things
## that can be updated one at a time -- and the one left behind would be
## a channel that quietly tells a feint apart.
static func is_attack_like(action: Action) -> bool:
	return action == Action.ATTACK or action == Action.FEINT

## Human-readable state, for the HUD only. Kept next to the enum it
## describes so a new state cannot be added without this going stale in
## the same file rather than three directories away.
static func state_label(state: State) -> String:
	match state:
		State.IDLE: return "Pret"
		State.WINDUP: return "Prepare"
		State.ACTIVE: return "Actif"
		State.RECOVERY: return "Recupere"
		State.STAGGER: return "Sonne"
		State.KO: return "K.O."
	return "?"

## Human-readable action, for the HUD only.
##
## =====================================================================
## FEINT DELIBERATELY REPORTS ITSELF AS "Attaque", AND THAT IS THE WHOLE
## POINT -- DO NOT "FIX" THIS
##
## BattleHUD prints this string live, next to the opponent's state, while
## the windup is still running. A label reading "Feinte" would give the
## answer away before the player has even looked at the fighter, which
## would make the entire lot-4 mechanic worthless: the feint has to be
## INDISTINGUISHABLE from an attack for exactly as long as an attack's
## windup lasts. Every other channel is held to the same rule --
## Fighter.is_threatening() answers true for both, and FighterView plays
## the identical telegraph -- and BattleFeintProbe gates all three.
##
## The reveal is the ABSENCE of the strike at the end of the windup, and
## it arrives at that moment and not one millisecond earlier.
static func action_label(action: Action) -> String:
	match action:
		Action.ATTACK: return "Attaque"
		Action.FEINT: return "Attaque"
		Action.GUARD: return "Garde"
		Action.DODGE: return "Esquive"
		Action.NONE: return ""
	return "?"

static func outcome_label(outcome: Outcome) -> String:
	match outcome:
		Outcome.HIT: return "TOUCHE"
		Outcome.BLOCKED: return "BLOQUE"
		Outcome.DODGED: return "ESQUIVE"
		Outcome.MISSED: return ""
	return "?"

## The verdict as the DEFENDER earned it, which is not the same question
## as `outcome_label`. A clean HIT has two completely different meanings
## depending on whether the defender had pressed anything:
##
##   attempted NONE  -> "TOUCHE"        you were caught standing
##   attempted GUARD -> "GARDE BRISEE"  you guarded, and mistimed it
##   attempted DODGE -> "ESQUIVE RATEE" you dodged, and mistimed it
##
## Lot 5 exists because those three were one string. A player who cannot
## tell "the button did nothing" from "you were 80 ms late" has no way
## to learn the timing, and an option nobody can learn is an option
## nobody takes -- which is exactly what the device report said.
static func strike_label(outcome: Outcome, attempted: Action) -> String:
	if outcome != Outcome.HIT or attempted == Action.NONE:
		return outcome_label(outcome)
	if attempted == Action.GUARD:
		return "GARDE BRISEE"
	if attempted == Action.DODGE:
		return "ESQUIVE RATEE"
	return outcome_label(outcome)
