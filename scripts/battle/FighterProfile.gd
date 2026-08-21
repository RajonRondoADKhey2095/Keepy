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
##     ai_* numbers below, not a bespoke behaviour script.
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
##
## =====================================================================
## LOT 7 DELETED THE GUARD AND FEINT GROUPS
##
## Four lots of guard tuning (3, 4, 5, 6) never shifted the same device
## report. The model is now two actions, and an attack whose landing
## instant is STATED by a charge bar rather than guessed at. Nine fields
## went with them -- guard_windup_s, guard_active_s, guard_recovery_s,
## guard_damage_ratio, feint_hold_s, ai_feint_rate, ai_guard_bias -- and
## none survives as a zeroed placeholder, because a field nobody reads is
## a field somebody eventually reads by accident.

@export_group("Identity")
## Shown by the HUD. The only string a player ever reads about a fighter.
@export var display_name: String = "Combattant"
@export var max_hp: int = 42

@export_group("Attack")
## The CHARGE BAR'S LENGTH. This is now the single most feel-critical
## number in the project, and its meaning changed at lot 7.
##
## =====================================================================
## IT IS NO LONGER A REACTION WINDOW -- IT IS A COUNTDOWN THE PLAYER READS
##
## Lot 5 sized it against a fact about people: a defence tapped in
## REACTION to an onset becomes active at `human latency + startup`, and
## the honest human latency through a touchscreen and a browser is
## 0.30-0.45 s, so a telegraph shorter than that could only be guessed
## at. That inequality was correct and it was never enough, because
## reacting to an onset only tells you an attack STARTED. Knowing when it
## LANDS was the missing half, and no length of telegraph supplies it.
##
## The bar supplies it. A player watching a fill complete is performing
## an ANTICIPATION, not a reaction, and human precision on an anticipated
## instant is far tighter than a reaction latency -- which is why lot 7
## could finally make the defensive window a fixed target instead of a
## race. What this number now buys is READING TIME: long enough that the
## fill is legible as a clock and not as a flicker.
##
## The floor that replaces lot 5's is in BattleDefenseProbe PHASE B: the
## dodge window, expressed as a fraction of THIS number, must be wide
## enough to absorb a human's timing jitter around wherever they aim.
@export var attack_windup_s: float = 0.90
## The strike resolves once, at the FIRST tick of this window. The
## window's LENGTH is therefore not the hit window -- it is how long the
## attacker stays committed and exposed after connecting.
@export var attack_active_s: float = 0.12
## Punish window. The defender's free hit if the attack whiffed -- and,
## since lot 5, the number that decides whether defending is worth doing
## at all.
##
## =====================================================================
## THE INEQUALITY THAT MAKES A SUCCESSFUL DODGE WORTH ANYTHING
##
## A defender who dodges is locked out for dodge_windup_s +
## dodge_active_s + dodge_recovery_s from their tap. For the exchange to
## have cost the attacker something, the defender must come free EARLIER
## than the attacker does and get the next attack out first:
##
##     tap + dodge cycle  <  windup + active + recovery
##
## Lot 5 found the guard version of this inequality failing and shipped a
## fix; the dodge version is what BattleDefenseProbe PHASE C gates now.
## If it fails, dodging is a slower way to lose and the correct strategy
## is to never stop attacking -- which is the exact sentence four device
## reports in a row contained.
@export var attack_recovery_s: float = 0.62
@export var attack_damage: int = 14

@export_group("Dodge")
## Startup. It is charged from the tap, so it moves the whole success
## window EARLIER by its own length -- a dodge tapped exactly as the bar
## completes is already this late. Keep it small.
@export var dodge_windup_s: float = 0.05
## The evade window, and the ONLY defensive window in the game now that
## guard is gone.
##
## =====================================================================
## HOW WIDE IT HAS TO BE, DERIVED RATHER THAN GUESSED
##
## A dodge tapped `t` seconds into the attacker's wind-up covers the blow
## iff  t + dodge_windup_s  <=  attack_windup_s  <=  t + dodge_windup_s +
## dodge_active_s, i.e.
##
##     t in [ W - dw - da , W - dw ]
##
## which is a window of exactly `dodge_active_s`, ending `dodge_windup_s`
## before the bar completes. So this field IS the player's margin for
## error, in seconds, one-for-one -- there is no other term.
##
## It must be comfortably wider than a human's timing jitter on an
## anticipated instant. Note what it must NOT be: wide enough to cover
## the whole bar, which would make "tap at any point" correct and delete
## the decision. BattleDefenseProbe PHASE B gates both ends.
@export var dodge_active_s: float = 0.40
## The cost. A dodge is not free: this is tempo handed back to the
## attacker, and it is the term that decides whether spamming the evade
## button beats reading the bar. Gated by PHASE C's inequality above.
@export var dodge_recovery_s: float = 0.36

@export_group("Reaction")
## How long a clean hit takes away. Longer than any recovery on purpose:
## being hit must be worse than whiffing -- gated in BattleDefenseProbe
## PHASE C2, because a lot that lengthens attack_recovery_s past the
## shipped stagger would otherwise invert it silently.
@export var stagger_duration_s: float = 0.70

@export_group("AI")
## Seconds of "thinking" before the brain commits, once its fighter is
## IDLE. Since lot 4 this measures the MINIMUM SPACING between decisions
## rather than a penalty after each one -- see FighterBrain.advance().
@export var ai_reaction_delay_s: float = 0.30
## Random spread added on top, drawn from the arena's SEEDED rng -- never
## from the global one. Exists so an opponent is not metronomic; keep it
## non-zero or a player can learn to tap on a beat.
@export var ai_reaction_jitter_s: float = 0.20
## Probability of choosing ATTACK when the opponent is NOT threatening.
@export_range(0.0, 1.0, 0.05) var ai_aggression: float = 0.70
## Probability of answering a telegraphed attack with a dodge instead of
## trading. 1.0 answers every wind-up and is unfun to fight -- note that
## it does NOT mean "dodges successfully": the timing below still has to
## be right.
@export_range(0.0, 1.0, 0.05) var ai_defense_rate: float = 0.65
## WHERE ON THE CHARGE BAR this fighter aims its dodge, as a fraction of
## the fill. The AI reads the bar exactly as the player does -- see
## FighterBrain's header for the measurement that put it there rather
## than leaving the brain blind.
##
## The ideal is the centre of the evade window, which for a defender with
## these dodge timings facing a wind-up of length W is
##
##     ( W - dodge_windup_s - dodge_active_s / 2 ) / W
##
## It is a per-profile NUMBER and not that formula, because the formula
## needs W -- the OPPONENT's wind-up -- and a brain that could read its
## opponent's profile would know something no player does. A future
## opponent whose numbers differ carries its own value here, which is the
## same "personality is numbers" contract as every other ai_ field.
@export_range(0.0, 1.0, 0.01) var ai_dodge_aim: float = 0.70
## How far off that mark this fighter actually lands, drawn once per
## telegraph from the seeded rng. This is the AI's timing error, and it
## is the honest difficulty dial for defence: 0.0 is a machine that never
## mistimes an evade.
@export_range(0.0, 1.0, 0.01) var ai_dodge_slop: float = 0.16

@export_group("Art")
## The imported .glb for this fighter, or null to keep the capsule
## placeholder. Handed straight to ModelSlot.model_scene, so the three
## corrections below have exactly the meaning documented in ModelSlot.gd.
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
## drive every action through one code path instead of branching per
## action in the FSM itself.
##
## This match is the ONLY place in the codebase that maps an action to
## its numbers, and it maps to FIELDS, not to values. Lot 7 shrank it
## from four cases to two by deleting actions, which is the direction it
## is supposed to be able to move in as easily as the other one.
func timing_for(action: BattleTypes.Action) -> Vector3:
	match action:
		BattleTypes.Action.ATTACK:
			return Vector3(attack_windup_s, attack_active_s, attack_recovery_s)
		BattleTypes.Action.DODGE:
			return Vector3(dodge_windup_s, dodge_active_s, dodge_recovery_s)
	return Vector3.ZERO
