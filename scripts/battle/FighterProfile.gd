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
##     ai_* numbers below, not a bespoke behaviour script -- lot 4's
##     feint is one more of them (ai_feint_rate), not a new class.
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
##
## =====================================================================
## THE FLOOR UNDER THIS NUMBER IS A FACT ABOUT PEOPLE, NOT A TASTE (lot 5)
##
## A guard tapped in reaction to this telegraph becomes active at
## `human latency + guard_windup_s`. For it to be up when the blow lands:
##
##     attack_windup_s  >=  human latency + defender's guard_windup_s
##
## There is no way around that inequality -- not a wider guard, not
## cheaper damage. A telegraph shorter than a human reaction time is a
## telegraph that cannot be reacted to, only guessed at.
##
## The honest human band through a touchscreen and a browser is
## 0.30-0.45 s (see BattleDefenseProbe.HUMAN_*). Lots 1-4 shipped 0.30,
## which put the whole band OUTSIDE the window: the guard's coverage of a
## plain attack ended 217 ms in. Measured, a player who only mashed
## ATTACK beat every defensive strategy at every latency, which is what
## Mathieu reported from the device while the probes said guard worked
## 99.3% of the time. The probes were answering at 0.12-0.24 s.
##
## BattleDefenseProbe PHASE B gates the inequality. Do not lower this
## below ~0.50 without re-reading it.
@export var attack_windup_s: float = 0.34
## The strike resolves once, at the FIRST tick of this window. The
## window's LENGTH is therefore not the hit window -- it is how long the
## attacker stays committed and exposed after connecting.
@export var attack_active_s: float = 0.12
## Punish window. The defender's free hit if the attack whiffed -- and,
## since lot 5, the number that decides whether blocking is worth doing
## at all.
##
## =====================================================================
## WIDENING THE GUARD WAS NOT ENOUGH, AND THIS IS WHY (lot 5, measured)
##
## With the guard windows fixed but this left where lots 1-4 had it, a
## player who did nothing but hammer ATTACK won 300 fights out of 300 --
## BETTER than before the fix. Blocking worked perfectly and still lost.
##
## The arithmetic: a fighter that blocks is locked out for the rest of
## its guard cycle. To make the exchange cost the attacker anything it
## must then land a strike, which costs a full attack_windup_s. If
##
##     defender's remaining lockout + defender's attack_windup_s
##         >=  attack_active_s + attack_recovery_s + attack_windup_s
##
## the counter never arrives: the attacker is already behind its next
## telegraph. Blocking becomes a slower way to lose, and the correct
## strategy is to never stop attacking.
##
## Lot 2 lengthened the telegraph and lot 5 lengthened it much further.
## Both grew the left side of that inequality. Nobody grew the right one
## -- this field had been sized against a 0.30 s windup and never
## re-sized. BattleDefenseProbe PHASE C2 now gates it.
@export var attack_recovery_s: float = 0.40
@export var attack_damage: int = 12

@export_group("Guard")
## Startup. Adds directly to how early the tap has to be -- see
## attack_windup_s. Keep it small: every millisecond here is a
## millisecond taken off the player's reaction budget.
@export var guard_windup_s: float = 0.08
## The block window. Wide and cheap on purpose: guard is the safe answer,
## dodge is the greedy one.
##
## Since lot 5 it has a second job, and it is the one that sizes it: a
## guard must cover a plain attack AND a held feint from the SAME tap.
## That is what makes it the option a player can take before they can
## read a feint -- and a player with no such option has, in practice, no
## defence at all. It requires
##
##     guard_windup_s + guard_active_s  >=  attack_windup_s + feint_hold_s
##
## measured from a tap placed anywhere in the human band. Dodge is held
## to the OPPOSITE bar (see dodge_active_s) and the gap between the two
## is the whole risk/reward of this game.
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
##
## It must stay narrow enough that a dodge CANNOT cover a plain attack
## and a held feint from one tap -- otherwise it strictly dominates
## guard and the feint becomes decoration. BattleDefenseProbe PHASE B
## asserts that failure, which is the only assertion in this project
## that wants something not to work.
@export var dodge_active_s: float = 0.20
@export var dodge_recovery_s: float = 0.34

@export_group("Feint")
## A feint is an attack that HOLDS. The windup runs its normal length,
## the strike does not come, the fighter stays wound up for this long,
## and only then does it land -- one single action, never two.
##
## WHY IT IS A HELD STRIKE AND NOT "A WINDUP FOLLOWED BY NOTHING", WHICH
## IS WHAT LOT 4 SET OUT TO BUILD AND MEASURED ITS WAY OUT OF:
##
## The first design was a lie with no strike at all, followed by a real
## attack thrown immediately after. It cannot work in this FSM, and the
## reason is arithmetic rather than tuning: EVERY attack in this game
## carries the same attack_windup_s telegraph, so the second beat is
## exactly as readable as the first. A player who dodged the lie is out
## of their recovery and dodging again long before the follow-up lands.
## Measured, that version made a reflex-dodging player BETTER, not worse
## -- 85.7% wins with no feints, 96.3% at a 0.35 feint rate -- because
## every feint the AI threw was one attack it did not throw. Raising
## dodge_recovery_s from 0.32 all the way to 0.72 changed nothing, at
## three different player reaction latencies: the defender was never
## caught in that recovery, they were already answering the new
## telegraph.
##
## Holding the strike removes the second telegraph entirely. The
## defender still gets exactly one window to read, at exactly the usual
## moment; what they cannot know is WHEN the blow arrives. A dodge, whose
## active window is narrow, expires during the hold. A guard, whose
## window is more than twice as wide, usually does not. That asymmetry is
## not a special rule for feints -- there is none -- it falls straight
## out of guard_active_s vs dodge_active_s.
##
## Length of the hold, i.e. how long the strike is late by. Too short and
## a reflex dodge still covers it; too long and even a guard has dropped,
## which turns the feint into an unconditional hit. The band is measured
## in BattleFeintProbe, per player reaction latency, and it is narrow.
## The fighter is fully vulnerable throughout, so a hold is also the
## fighter standing still, telegraphing, for this much longer.
@export var feint_hold_s: float = 0.26
## Probability that an offensive decision comes out as a feint instead of
## a plain attack. 0.0 disables the mechanic entirely for this fighter,
## which is what every player-side profile must carry: BattleHUD emits
## three actions and only three, so a human has no feint button, and an
## AI standing in for the player must not hold an option the player does
## not have.
@export_range(0.0, 1.0, 0.05) var ai_feint_rate: float = 0.0

@export_group("Reaction")
## How long a clean hit takes away. Longer than any recovery on purpose:
## being hit must be worse than whiffing -- gated in
## BattleDefenseProbe PHASE C2, because lot 5 lengthened attack_recovery_s
## past the shipped stagger and would otherwise have inverted it silently.
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
## drive every action through one code path instead of branching per
## action in the FSM itself.
##
## This match is the ONLY place in the codebase that maps an action to
## its numbers, and it maps to FIELDS, not to values. Lot 4 proved the
## claim: adding FEINT touched this function and the exports above, and
## nothing else in this file.
func timing_for(action: BattleTypes.Action) -> Vector3:
	match action:
		BattleTypes.Action.ATTACK:
			return Vector3(attack_windup_s, attack_active_s, attack_recovery_s)
		BattleTypes.Action.GUARD:
			return Vector3(guard_windup_s, guard_active_s, guard_recovery_s)
		BattleTypes.Action.DODGE:
			return Vector3(dodge_windup_s, dodge_active_s, dodge_recovery_s)
		BattleTypes.Action.FEINT:
			# EVERY component is read from the attack's own fields -- the
			# feint owns no timing of its own except the hold it adds to
			# the windup. There is deliberately no feint_windup_s, no
			# feint_active_s and no feint_recovery_s: separable fields
			# are fields that eventually diverge, and a feint that is
			# even 50 ms off a real attack anywhere is a feint a player
			# reads on a stopwatch instead of on a guess.
			#
			# The hold lives INSIDE the windup, which is what makes the
			# whole mechanic one action rather than two. FighterView
			# still animates the telegraph over attack_windup_s alone
			# (Fighter.telegraph_duration()), so the pose reaches the
			# same place at the same moment and then simply stays there.
			return Vector3(attack_windup_s + feint_hold_s, attack_active_s, attack_recovery_s)
	return Vector3.ZERO
