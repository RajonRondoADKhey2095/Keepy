extends RefCounted
class_name BattleTypes
## Shared vocabulary of Keepy Battle: the combat FSM's states, the TWO
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
## =====================================================================
## LOT 7 DELETED GUARD AND FEINT. THIS IS THE SHORT VERSION; THE LONG
## ONE IS IN CLAUDE.md.
##
## Lots 3, 4, 5 and 6 each fixed a different, measured, proven cause of
## the same device report -- "guard and dodge do not work, the only
## strategy is to attack" -- and the report never changed. The probes
## said defending won; the player felt the opposite. The cause finally
## retained is that the player knew an attack was COMING (the telegraph,
## validated at lot 2) but never knew WHEN it would land, and lot 4
## deliberately made that instant ambiguous on top.
##
## So the model changed instead of being patched again: two actions, and
## a charge bar on the attacker whose fill reaches 100% at the exact
## instant of impact. There is nothing left to guess, so there is nothing
## left for a second defensive option to hedge against -- GUARD had no
## job, and a FEINT is a lie about an instant the bar now states.
##
## Nothing here is per-fighter. Everything that differs between two
## combatants lives in FighterProfile (a .tres), never in an enum.

## The combat FSM. ONE machine, driven identically whether a human tap or
## the AI brain pushed the action in -- see Fighter.request_action().
##
##   IDLE      accepts a new action (and only IDLE does)
##   WINDUP    committed, telegraph phase, still vulnerable. For an
##             ATTACK this is exactly the span the charge bar depicts.
##   ACTIVE    the action's effect window (a strike lands, a dodge
##             evades) -- this is the whole timing game
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

## The two tap zones, and the two things a fighter can commit to.
## NONE is the resting action carried while IDLE/STAGGER/KO, so
## `current_action` is never a null-ish special case to guard against.
##
## There is no third member and no AI-only member. Everything the brain
## can ask for, a human can ask for with the same two buttons -- which is
## the promise FighterBrain's header makes and which a fourth,
## opponent-only action (lot 4's FEINT) quietly broke.
enum Action {
	NONE,
	ATTACK,
	DODGE,
}

## What one strike resolution produced, reported to the HUD so a player
## can tell "my dodge worked" from "I got hit anyway".
enum Outcome {
	HIT,     ## Clean: full damage, defender staggers.
	DODGED,  ## Defender was in DODGE's active window: no damage at all.
	MISSED,  ## Defender was already KO -- resolution is a no-op.
}

## Human-readable state, for the HUD only. Kept next to the enum it
## describes so a new state cannot be added without this going stale in
## the same file rather than three directories away.
static func state_label(state: State) -> String:
	match state:
		State.IDLE: return "Pret"
		State.WINDUP: return "Charge"
		State.ACTIVE: return "Actif"
		State.RECOVERY: return "Recupere"
		State.STAGGER: return "Sonne"
		State.KO: return "K.O."
	return "?"

## Human-readable action, for the HUD only.
##
## Lot 4 needed a long note here explaining why FEINT deliberately lied
## about itself. There is nothing left to lie about: an attack says
## "Attaque", and the charge bar above the fighter says exactly when it
## lands.
static func action_label(action: Action) -> String:
	match action:
		Action.ATTACK: return "Attaque"
		Action.DODGE: return "Esquive"
		Action.NONE: return ""
	return "?"

static func outcome_label(outcome: Outcome) -> String:
	match outcome:
		Outcome.HIT: return "TOUCHE"
		Outcome.DODGED: return "ESQUIVE"
		Outcome.MISSED: return ""
	return "?"

## The verdict as the DEFENDER earned it, which is not the same question
## as `outcome_label`. A clean HIT has two different meanings depending on
## whether the defender had pressed anything:
##
##   attempted NONE  -> "TOUCHE"        you were caught standing
##   attempted DODGE -> "ESQUIVE RATEE" you dodged, and mistimed it
##
## Lot 5 exists because those were one string. A player who cannot tell
## "the button did nothing" from "you were 80 ms early" has no way to
## learn the timing, and an option nobody can learn is an option nobody
## takes. Lot 7 keeps the distinction and makes it far cheaper to act on:
## the charge bar says where in the fill the tap should have gone.
static func strike_label(outcome: Outcome, attempted: Action) -> String:
	if outcome == Outcome.HIT and attempted == Action.DODGE:
		return "ESQUIVE RATEE"
	return outcome_label(outcome)
