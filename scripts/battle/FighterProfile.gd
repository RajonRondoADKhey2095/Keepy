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
## LOT 12 REVERSED LOT 11's WINDUP EQUALITY -- attack_windup_s IS NOT A
## SYMMETRIZABLE COMBAT FIELD, AND THIS IS STRUCTURAL, NOT A TASTE CALL
##
## Lot 11's brief classed attack_windup_s as a COMBAT field that had to be
## identical on both profiles, alongside max_hp/attack_damage/etc. That
## classification was WRONG: attack_windup_s is not a price paid or a
## resource spent, it is the field that GENERATES THE OPPONENT'S CHARGE
## BAR -- the one channel a defender reads to know a blow is coming and
## WHEN it lands (see the field's own doc below). Forcing it equal at
## zero did not make the fight fairer, it deleted the telegraph on both
## sides at once, and lot 11's own measurement proved the cost: panic-
## dodge and read+riposte became the SAME policy (27.7% each) because
## there was nothing left to READ, only a phase-luck dodge.
##
## Mathieu's call, and the one durable exception to "every combat field
## equal": dummy.tres gets attack_windup_s back to 0.9 -- Sparring is
## LEGIBLE again. keepy.tres keeps 0.0 -- the player's tap IS the blow,
## unchanged since lot 8. EVERY OTHER combat field (max_hp, attack_damage,
## riposte_damage, attack_recovery_s, dodge_*, stagger_duration_s,
## riposte_window_s) stays strictly identical between the two profiles,
## exactly as lot 11 mandated. This is NOT a power asymmetry: Sparring
## does not hit harder, survive longer, or recover faster for having a
## telegraph. It is the difference between a fighter a player has to
## READ and a fighter the player CONTROLS -- and one of the two combatants
## in this duel has to be each, or there is nothing to react to and
## nothing to decide.
##
## A future lot must NOT "fix" this back to equality in the name of
## symmetry: the asymmetry is the fix. If it is ever revisited, it must
## be revisited by MEASURING what a shared value does to the reading
## dimension (as lot 11 measured, and got wrong), not by pattern-matching
## on "every other field is equal so this one should be too".
##
## Consequence unchanged from lot 8/11 and still true here: a REACTIVE
## dodge against KEEPY's zero-length wind-up remains impossible (the
## defender's own dodge_windup_s alone costs 3 ticks, and the strike
## resolves on the very next tick after the tap) -- that half of the
## asymmetry is accepted, not new. What lot 12 restores is the OTHER
## half: a REACTIVE dodge against SPARRING's wind-up is possible again,
## exactly as it was through lots 8-10. See BattleDefenseProbe's and
## BattleReadabilityProbe's lot-12 guards, and CLAUDE.md's Keepy Battle
## lot 12 section, for the measured numbers.
##
## =====================================================================
## LOT 8 SPLIT ONE ATTACK INTO TWO PAYOFFS
##
## The player's attack became INSTANT (attack_windup_s = 0) and the
## reward for a successful dodge became a RIPOSTE: an attack begun while
## riposte-ready deals riposte_damage AND staggers, where an ordinary
## "blind" attack deals attack_damage and does not stagger at all.
##
## Both are per-profile numbers. The riposte-vs-chip split survives lot 12
## unchanged, and so does the asymmetry this header describes: "instant,
## unavoidable chip against a slow, readable, heavy blow" is, once again
## (after lot 11's brief detour through shared zero), exactly what the
## shipped fight is.
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
##
## =====================================================================
## ZERO IS A MEANINGFUL VALUE, AND IT IS WHAT THE PLAYER SHIPS WITH
##
## A fighter whose wind-up is 0 throws INSTANTLY: the strike resolves on
## the tick after the tap, there is no telegraph, and -- because there is
## no telegraph -- no charge bar is raised and no evade band is drawn.
## FighterView keys that off the phase having no length, so it is a
## consequence of this number and not a per-side flag someone has to
## remember to set.
##
## It also means the blow CANNOT BE DODGED except by luck: a defender
## already inside its own dodge window evades it, and nobody reacts to an
## instant. That is why keepy.tres pairs a zero wind-up with a small
## attack_damage -- see the field itself. An attack's damage is priced by
## how avoidable it is.
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
##
## =====================================================================
## LOT 8: ">0" WAS NEVER THE RIGHT BAR. IT HAS TO CLEAR A HUMAN.
##
## Lot 7 satisfied that inequality and published the margin: +13 ms at
## the worst tap of the drawn band. Measured against a person that is
## nothing -- the player came free thirteen milliseconds early and then
## had to spend a 300-450 ms reaction before they could press anything.
## The punish window existed on paper and could not be taken.
##
## Written out, the free time a defender really gets is
##
##   punish = (W + active + recovery)_attacker
##          - (t_tap + dodge_windup + dodge_active + dodge_recovery)_defender
##
## at the LATEST tap the drawn band promises. It is this field, minus the
## defender's dodge cycle, minus a constant -- so it is the attacker's
## recovery that pays for the defender's punish window, and nothing else
## can. BattleDefenseProbe PHASE C now gates it against the human band
## instead of against zero.
@export var attack_recovery_s: float = 0.62
## Damage of an ORDINARY attack -- one thrown without a riposte pending.
##
## It does NOT stagger. That is not a softening, it is the rule that
## makes an instant attack survivable to face: a hit that cancels what
## the target was doing, repeated faster than the target's wind-up, is a
## stun-lock, and MEASURED it wins 300 fights out of 300. With the cancel
## gone, a telegraph completes even while its owner is being chipped, so
## mashing trades damage for every blow the opponent throws.
@export var attack_damage: int = 14

@export_group("Riposte")
## THE REWARD FOR READING THE BAR. An attack begun while this fighter is
## riposte-ready deals this instead of attack_damage, and it DOES
## stagger.
##
## Must be strictly greater than attack_damage, or dodging is a detour on
## the way to the same hit and the whole loop collapses back into "just
## attack" -- the sentence four device reports contained. Gated.
@export var riposte_damage: int = 14
## How long a successful dodge stays spendable.
##
## =====================================================================
## IT COUNTS DOWN ONLY WHILE THE FIGHTER IS IDLE
##
## The dodge that earns the riposte also locks its owner up for the rest
## of its own cycle, and that lockout must not eat the reward: a window
## measured from the evade instant would be mostly spent before the
## player could act at all. Counting only FREE time makes this field mean
## exactly what a player would assume -- "you have this long, once you
## can move again" -- so it can be gated directly against a human
## reaction instead of against a lockout that varies with where the tap
## landed.
@export var riposte_window_s: float = 1.20

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

## drive every action through one code path instead of branching per
## action in the FSM itself.
##
## This match is the ONLY place in the codebase that maps an action to
## its numbers, and it maps to FIELDS, not to values. Lot 7 shrank it
## from four cases to two by deleting actions, which is the direction it
## is supposed to be able to move in as easily as the other one.
## What one of this fighter's strikes costs. The ONE place the two damage
## numbers are chosen between -- BattleArena prices a real strike with it
## and every probe resolves with it, so a fixture cannot quietly price a
## riposte as a chip and still pass. That divergence, on the one axis a
## lot changes, is the failure this repo already paid for once
## (SubstituteModel.tscn).
##
## Its companion rule -- only a riposte staggers -- is a single boolean
## and stays at the call site in BattleArena, where resolution lives.
func damage_for(riposte: bool) -> int:
	return riposte_damage if riposte else attack_damage

## (windup, active, recovery) in seconds for `action`, so Fighter.gd can
## drive every action through one code path instead of branching per
## action in the FSM itself.
##
## This match is the ONLY place in the codebase that maps an action to
## its numbers, and it maps to FIELDS, not to values.
func timing_for(action: BattleTypes.Action) -> Vector3:
	match action:
		BattleTypes.Action.ATTACK:
			return Vector3(attack_windup_s, attack_active_s, attack_recovery_s)
		BattleTypes.Action.DODGE:
			return Vector3(dodge_windup_s, dodge_active_s, dodge_recovery_s)
	return Vector3.ZERO
