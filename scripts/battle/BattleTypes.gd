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
enum Action {
	NONE,
	ATTACK,
	GUARD,
	DODGE,
}

## What one strike resolution produced, reported to the HUD so a player
## can tell "my guard worked" from "I got hit anyway".
enum Outcome {
	HIT,      ## Clean: full damage, defender staggers.
	BLOCKED,  ## Defender was in GUARD's active window: chip damage, no stagger.
	DODGED,   ## Defender was in DODGE's active window: no damage at all.
	MISSED,   ## Defender was already KO -- resolution is a no-op.
}

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

static func action_label(action: Action) -> String:
	match action:
		Action.ATTACK: return "Attaque"
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
