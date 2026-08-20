extends Resource
class_name FighterProfile
## EVERYTHING that differs between two combatants. One .tres per fighter.
##
## =====================================================================
## THE "AND IN 6 MONTHS?" CONTRACT
##
## Adding an opponent must cost ONE .tres and ONE .glb, and ZERO lines of
## code. That is the whole reason this Resource exists, and it is the bar
## every future change to Keepy Battle has to clear:
##
##   * Fighter.gd is generic. It reads timings, damage, hp and art from
##     here and contains no `match species` anywhere. There is no
##     Keepy.gd, no Boar.gd, no per-animal subclass, and adding one would
##     be the failure this file is designed to prevent.
##   * FighterBrain.gd is generic too. An opponent's "personality" is the
##     four ai_* numbers below, not a bespoke behaviour script.
##   * The art swap is a PackedScene reference in this file, handed to
##     ModelSlot (scripts/world/ModelSlot.gd) at runtime -- the project's
##     established placeholder-to-.glb exchange point. See Fighter.gd's
##     `_apply_profile_art()` for the exact hand-off.
##
## What deliberately does NOT live here: anything shared by every
## fighter. The tick rate, the FSM's shape, the strike-resolution rules
## and the input buffer are properties of the GAME, not of a combatant --
## duplicating them per .tres would let two fighters silently disagree
## about the rules they are both playing by.

@export_group("Identity")
## Shown by the HUD. The only string a player ever reads about a fighter.
@export var display_name: String = "Combattant"
@export var max_hp: int = 100

@export_group("Attack")
## Telegraph: the defender's whole reaction window. Longer = more
## readable, more punishable. This is the single most feel-critical
## number in the file.
@export var attack_windup_s: float = 0.34
## The strike resolves once, at the FIRST tick of this window. The
## window's LENGTH is therefore not the hit window -- it is how long the
## attacker stays committed and exposed after connecting.
@export var attack_active_s: float = 0.12
## Punish window. The defender's free hit if the attack whiffed.
@export var attack_recovery_s: float = 0.40
@export var attack_damage: int = 12

@export_group("Guard")
@export var guard_windup_s: float = 0.08
## The block window. Wide and cheap on purpose: guard is the safe answer,
## dodge is the greedy one.
@export var guard_active_s: float = 0.42
@export var guard_recovery_s: float = 0.22
## Fraction of the damage a blocked strike still deals. 0.0 makes guard
## strictly dominant over dodge; chip damage is what keeps a purely
## defensive player from stalling forever.
@export_range(0.0, 1.0, 0.05) var guard_damage_ratio: float = 0.25

@export_group("Dodge")
@export var dodge_windup_s: float = 0.06
## Strictly narrower than guard_active_s, and that gap IS the risk/reward
## of this lot's combat: a read that lands costs the attacker a full
## recovery, a read that misses leaves you in dodge recovery with nothing.
@export var dodge_active_s: float = 0.20
@export var dodge_recovery_s: float = 0.34

@export_group("Reaction")
## How long a clean hit takes away. Longer than any recovery on purpose:
## being hit must be worse than whiffing.
@export var stagger_duration_s: float = 0.55

@export_group("AI")
## Seconds of "thinking" before the brain commits, once its fighter is
## IDLE. This is the difficulty dial: a lower value is a sharper opponent
## far more than a higher damage number would be.
@export var ai_reaction_delay_s: float = 0.42
## Random spread added on top, drawn from the arena's SEEDED rng -- never
## from the global one. Exists so an opponent is not metronomic; keep it
## non-zero or a player can learn to tap on a beat.
@export var ai_reaction_jitter_s: float = 0.28
## Probability of choosing ATTACK when the opponent is NOT threatening.
@export_range(0.0, 1.0, 0.05) var ai_aggression: float = 0.55
## Probability of answering a telegraphed attack defensively instead of
## trading. 1.0 reads every windup perfectly and is unfun to fight.
@export_range(0.0, 1.0, 0.05) var ai_defense_rate: float = 0.6
## Split between the two defensive answers: GUARD with this probability,
## DODGE otherwise.
@export_range(0.0, 1.0, 0.05) var ai_guard_bias: float = 0.65

@export_group("Art")
## The imported .glb for this fighter, or null to keep the capsule
## placeholder. Null on every profile in lot 1 by design -- this lot
## exists to settle feel and balance BEFORE any Meshy credit is spent.
##
## Handed straight to ModelSlot.model_scene, so the three corrections
## below have exactly the meaning documented in ModelSlot.gd. Nothing
## about the swap needs new code: drop a .glb in, point this at it.
@export var model_scene: PackedScene = null
@export var model_scale: float = 1.0
@export var model_rotation_degrees: Vector3 = Vector3.ZERO
@export var model_offset: Vector3 = Vector3.ZERO
## Tint of the capsule placeholder while model_scene is null. Applied
## UNSHADED, like every other surface in this project -- the colour
## written is the colour seen (see CLAUDE.md, "DIRECTION ARTISTIQUE
## PERMANENTE": nothing post-processes the frame any more).
@export var placeholder_color: Color = Color(0.85, 0.62, 0.28)

## (windup, active, recovery) in seconds for `action`, so Fighter.gd can
## drive all three actions through one code path instead of branching per
## action in the FSM itself.
##
## This match is the ONLY place in the codebase that maps an action to
## its numbers, and it maps to FIELDS, not to values -- a fourth action
## would touch this function and the exports above, nothing else.
func timing_for(action: BattleTypes.Action) -> Vector3:
	match action:
		BattleTypes.Action.ATTACK:
			return Vector3(attack_windup_s, attack_active_s, attack_recovery_s)
		BattleTypes.Action.GUARD:
			return Vector3(guard_windup_s, guard_active_s, guard_recovery_s)
		BattleTypes.Action.DODGE:
			return Vector3(dodge_windup_s, dodge_active_s, dodge_recovery_s)
	return Vector3.ZERO
