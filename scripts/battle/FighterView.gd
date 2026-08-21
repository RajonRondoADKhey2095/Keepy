extends Node
class_name FighterView
## The VISUAL half of a combatant: everything a player sees a fighter do,
## and nothing a fighter decides.
##
## =====================================================================
## WHY THIS FILE EXISTS -- THE MEASUREMENT THAT PRODUCED IT
##
## Lot 1 shipped a combat FSM that is correct and unreadable. The
## telegraph -- the window in which a defender can answer an incoming
## attack -- was carried by ONE small text label at the top of the
## screen, while the player's eyes are on two capsules in the middle of
## it. Measured headless on the shipped scripts before a line of this
## file was written:
##
##   * the HUD DOES subscribe to WINDUP and DOES render it, for 19 ticks
##     = 317 ms. The label was never desynchronised.
##   * 317 ms is not a short telegraph. It is an invisible one: nothing
##     on the fighters themselves moved at any point in the attack.
##
## So the defect was never "the HUD is late". It was that the combatants
## were mute. This file is the fix, and it is deliberately the ONLY place
## in Keepy Battle that knows what an attack looks like.
##
## =====================================================================
## STRICTLY READ-ONLY ON THE FSM -- THE RULE THAT MAKES THIS SAFE
##
## Every animation below is driven by Fighter's TYPED SIGNALS. This node
## never calls request_action(), never calls advance(), never writes a
## field on Fighter, and never reads one to decide anything other than
## which animation to play. It cannot change who wins.
##
## That is not a style preference. BattleArena's whole balance story
## rests on a fight being a pure function of (seed, tap timings in
## ticks); an animation layer that could reach back into the FSM would
## make the frame rate an input to the fight, and the divergence would be
## invisible until someone measured it. Tweens run on ENGINE time and the
## FSM runs on the arena's fixed-step accumulator: the two are allowed to
## drift by a frame, precisely BECAUSE nothing crosses from here to
## there. scripts/dev/BattleContractProbe.gd is byte-identical at a given
## seed with this file present, which is the proof rather than the claim.
##
## =====================================================================
## IT ANIMATES $Body (THE ModelSlot), NEVER THE CAPSULE GEOMETRY
##
## Every tween below writes `position`, `rotation_degrees` or `scale` on
## the fighter's ModelSlot, and the tint goes through
## ModelSlot.apply_material(). That is the project's established contract
## for gameplay-driven visuals (see ModelSlot.gd: Obstacle.gd already
## animates a slot's `.scale` and `.position.y` the same way), and it is
## what makes lot 4 free: a .glb installed into the slot is a CHILD of
## the node these tweens move, so it inherits all of them without one
## line changing here. Animating the capsule's mesh instead would have
## produced a telegraph that dies the day the placeholder does.
##
## The tint is the one thing that needs care across that swap, and it is
## handled: `_ensure_material()` DUPLICATES whatever the slot currently
## draws with before touching it, so an imported .glb's shared material
## can never be mutated for every instance at once, and only
## `albedo_color` is written -- which MULTIPLIES an albedo texture rather
## than replacing it. A textured model keeps its texture and still reds
## up on a windup.
##
## =====================================================================
## THE RED RAMP MEANS EXACTLY ONE THING
##
## Colour is reserved for INCOMING DANGER: a fighter ramps toward
## ALERT_COLOR only while winding up an ATTACK, and progressively, so the
## intensity itself is the clock a defender reads. Guard and dodge are
## told apart by SHAPE (brace, lean-back), never by tint. A telegraph
## that shares its channel with two harmless actions is a telegraph that
## has to be decoded rather than seen.

## Breathing. Small on purpose -- it exists so an idle screen is never
## dead, not so it competes with the telegraph.
const IDLE_BOB_RISE := 0.045
const IDLE_BOB_S := 1.6

## Anticipation. The fighter COILS: it pulls back away from its target
## and grows slightly, over the windup's real duration, so "how far it
## has wound up" reads as "how much time is left".
const WINDUP_RECOIL := 0.17
const WINDUP_LEAN_DEG := -8.0
const WINDUP_SCALE := 1.06

## The strike. Fast in (the snap), and NEVER as slow as the return --
## a lunge that eases out reads as a lean, not as a blow.
const LUNGE_REACH := 0.30
const LUNGE_LEAN_DEG := 12.0
const LUNGE_IN_S := 0.06

## Guard braces low and wide; dodge slips back and away. Neither uses
## colour -- see the header.
const GUARD_CROUCH := 0.86
const GUARD_WIDEN := 1.10
const DODGE_SLIDE := -0.28
const DODGE_LEAN_DEG := -16.0

## Being hit. Deeper than any recovery pose, because a clean hit must
## look worse than a whiff.
const STAGGER_RECOIL := 0.32
const STAGGER_ROLL_DEG := 9.0
const STAGGER_SETTLE_S := 0.12

## The topple. The slot's origin is the capsule's CENTRE, so laying it
## down also has to drop it to roughly its own radius or it floats.
const KO_FALL_DEG := -82.0
const KO_CENTRE_Y := 0.5
const KO_S := 0.5

## Incoming danger, and only that.
const ALERT_COLOR := Color(1.0, 0.28, 0.16)
## The instant of release: brighter and hotter than the ramp that led to
## it, so the frame the strike leaves is distinguishable from the frame
## before it.
const STRIKE_COLOR := Color(1.0, 0.66, 0.36)
## Impact, on the fighter TAKING it. White for a clean hit, cold for a
## block -- "my guard worked" is exactly the feedback this lot owes the
## player.
const HIT_FLASH_COLOR := Color(1.0, 1.0, 1.0)
const BLOCK_FLASH_COLOR := Color(0.70, 0.88, 1.0)
const FLASH_IN_S := 0.05
const FLASH_OUT_S := 0.24

## Floor under any tween duration read from a profile, so a phase that is
## nominally a couple of ticks long still produces a movement a human eye
## can catch rather than a teleport.
const MIN_POSE_S := 0.05

## The fighter this view watches. Resolved from the parent because this
## node is authored as a direct child of the Fighter root inside
## BattleFighter.tscn -- the scene IS the wiring, so there is no path to
## keep in sync and no way to point it at the wrong combatant.
var _fighter: Fighter = null
var _slot: ModelSlot = null

## Authored rest transform, captured once. Every pose below is expressed
## as an offset from it, so moving the fighters in the scene moves their
## animations with them.
var _base_position := Vector3.ZERO
var _base_rotation := Vector3.ZERO
var _base_scale := Vector3.ONE

## Owned copy of the slot's material, and the colour it rests at. Both
## resolved lazily -- see _ensure_material() for why it cannot happen in
## _ready().
var _material: StandardMaterial3D = null
var _material_resolved := false
var _base_color := Color.WHITE

## Three tweens, never one. Pose and tint are killed independently
## because a state change must be able to re-pose a fighter WITHOUT
## cutting an impact flash short, and the idle bob writes `position` too
## -- sharing a tween with it would have the two fight for the node every
## frame.
var _pose_tween: Tween = null
var _tint_tween: Tween = null
var _idle_tween: Tween = null

## False only when the wiring above failed, i.e. this node is not where
## the scene says it is. Deliberately NOT a "is there a display server"
## gate: skipping the animation layer on a headless run would mean
## BattleContractProbe never exercises the very file whose whole promise
## is that it cannot affect a fight, and the one branch that most needs
## proving would be the one branch no probe ever entered. The probe runs
## with these tweens live and must still produce a byte-identical trace.
var _enabled := false

func _ready() -> void:
	_fighter = get_parent() as Fighter
	if _fighter == null:
		push_error("FighterView must be a direct child of a Fighter node.")
		return
	_slot = _fighter.get_node_or_null("Body") as ModelSlot
	if _slot == null:
		push_error("FighterView: no ModelSlot at '%s/Body'." % _fighter.name)
		return

	_base_position = _slot.position
	_base_rotation = _slot.rotation_degrees
	_base_scale = _slot.scale
	_enabled = true
	_fighter.state_changed.connect(_on_state_changed)
	_fighter.hit_taken.connect(_on_hit_taken)

func _exit_tree() -> void:
	_kill(_pose_tween)
	_kill(_tint_tween)
	_kill(_idle_tween)
	_pose_tween = null
	_tint_tween = null
	_idle_tween = null
	if _fighter == null:
		return
	if _fighter.state_changed.is_connected(_on_state_changed):
		_fighter.state_changed.disconnect(_on_state_changed)
	if _fighter.hit_taken.is_connected(_on_hit_taken):
		_fighter.hit_taken.disconnect(_on_hit_taken)

## Returns a still-standing fighter to rest. Called by BattleArena when a
## round ends, and it exists because of a real consequence of freezing the
## simulation on the KO tick: the WINNER's FSM stops mid-ACTIVE and never
## emits another transition, so without this its view would hold the
## winning lunge, forever, in plain sight beside the result panel (which
## is 600x440 on a 1080x1920 screen and covers neither fighter).
##
## A KO'd fighter is deliberately left where it fell -- its topple IS the
## result being shown.
func settle() -> void:
	if not _enabled or _fighter == null:
		return
	if _fighter.state == BattleTypes.State.KO:
		return
	_rest(0.28)

func _on_state_changed(state: BattleTypes.State, action: BattleTypes.Action) -> void:
	if not _enabled:
		return
	# The phase's REAL length, straight from the fighter that just entered
	# it, rather than this file re-deriving it from the profile. One less
	# copy of the action -> timing map, and it stays true if a phase is
	# ever shortened by the overshoot Fighter.advance() carries.
	var phase := maxf(_fighter.phase_duration(), MIN_POSE_S)
	match state:
		BattleTypes.State.IDLE:
			_rest(0.16)
			_start_idle_bob()
		BattleTypes.State.WINDUP:
			# telegraph_duration(), NOT phase: a feint's windup is longer
			# than the pose that depicts it, on purpose. See Fighter.
			_windup(action, maxf(_fighter.telegraph_duration(), MIN_POSE_S))
		BattleTypes.State.ACTIVE:
			_active(action, phase)
		BattleTypes.State.RECOVERY:
			_recover(phase)
		BattleTypes.State.STAGGER:
			_stagger()
		BattleTypes.State.KO:
			_knock_out()

## The impact flash, on the fighter that just TOOK the strike. Tint only:
## the recoil belongs to STAGGER, which Fighter emits right after this,
## and doubling it here would make a blocked hit shove a fighter that by
## rule does not budge.
func _on_hit_taken(_damage: int, outcome: BattleTypes.Outcome) -> void:
	if not _enabled:
		return
	# A dodge is the absence of contact. Flashing it would light up the
	# one outcome where nothing touched the fighter at all.
	if outcome == BattleTypes.Outcome.DODGED or outcome == BattleTypes.Outcome.MISSED:
		return
	_ensure_material()
	if _material == null:
		return
	var flash := HIT_FLASH_COLOR if outcome == BattleTypes.Outcome.HIT else BLOCK_FLASH_COLOR
	_kill(_tint_tween)
	_tint_tween = create_tween()
	_tint_tween.tween_property(_material, "albedo_color", flash, FLASH_IN_S)
	_tint_tween.tween_property(_material, "albedo_color", _base_color, FLASH_OUT_S)

# ------------------------------------------------------------ poses

## Anticipation, and the only place colour is used as a clock: the ramp
## toward ALERT_COLOR runs for the WHOLE windup, so a defender reading
## "how red is it" is reading "how long do I have left". EASE_IN makes
## the last third the loudest, which is where the answer has to be given.
func _windup(action: BattleTypes.Action, phase: float) -> void:
	_stop_idle_bob()
	_kill(_pose_tween)
	_pose_tween = create_tween().set_parallel(true)
	# A FEINT takes this branch identically to an ATTACK -- same lean,
	# same recoil, same red ramp -- and `phase` is already the same
	# number, because FighterProfile.timing_for() hands a feint the
	# attack's own attack_windup_s field rather than a copy of it.
	# The two telegraphs are therefore not "similar": they are the same
	# animation, run for the same duration, from the same source value.
	#
	# This is the ONE place a tell would have been cheapest to introduce
	# and hardest to notice, so it is also the one BattleFeintProbe
	# gates hardest: it plays both and compares the resulting transforms
	# tick by tick.
	var attack_like := BattleTypes.is_attack_like(action)
	var lean := WINDUP_LEAN_DEG if attack_like else WINDUP_LEAN_DEG * 0.4
	var reach := -WINDUP_RECOIL if attack_like else -WINDUP_RECOIL * 0.35
	_pose_tween.tween_property(_slot, "position", _offset(reach, 0.0), phase) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pose_tween.tween_property(_slot, "rotation_degrees", _lean(lean, 0.0), phase) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pose_tween.tween_property(_slot, "scale", _base_scale * WINDUP_SCALE, phase) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if not attack_like:
		_tint_to(_base_color, phase * 0.5)
		return
	# Colour still means exactly ONE thing, and lot 4 does not widen it:
	# "an attack telegraph is running". That a telegraph can now turn out
	# to have been a lie is a property of the fight, not a second meaning
	# bolted onto the channel -- the ramp says the same sentence it said
	# in lot 2, it is just no longer always true.
	_tint_to(ALERT_COLOR, phase, Tween.EASE_IN)

## The effect window. Attack snaps forward; guard and dodge get their own
## silhouette so neither can be mistaken for a blow being thrown.
func _active(action: BattleTypes.Action, phase: float) -> void:
	_stop_idle_bob()
	_kill(_pose_tween)
	match action:
		BattleTypes.Action.ATTACK:
			_lunge()
		BattleTypes.Action.GUARD:
			_brace(phase)
		BattleTypes.Action.DODGE:
			_slip(phase)
		_:
			_rest(0.12)

func _lunge() -> void:
	_pose_tween = create_tween().set_parallel(true)
	_pose_tween.tween_property(_slot, "position", _offset(LUNGE_REACH, 0.0), LUNGE_IN_S) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "rotation_degrees", _lean(LUNGE_LEAN_DEG, 0.0), LUNGE_IN_S) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "scale", _base_scale, LUNGE_IN_S) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tint_to(STRIKE_COLOR, LUNGE_IN_S)

func _brace(phase: float) -> void:
	var braced := Vector3(_base_scale.x * GUARD_WIDEN, _base_scale.y * GUARD_CROUCH, _base_scale.z * GUARD_WIDEN)
	_pose_tween = create_tween().set_parallel(true)
	_pose_tween.tween_property(_slot, "position", _offset(0.0, -0.06), minf(phase, 0.10)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "rotation_degrees", _lean(4.0, 0.0), minf(phase, 0.10)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "scale", braced, minf(phase, 0.10)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tint_to(_base_color, 0.10)

func _slip(phase: float) -> void:
	_pose_tween = create_tween().set_parallel(true)
	_pose_tween.tween_property(_slot, "position", _offset(DODGE_SLIDE, 0.05), minf(phase, 0.10)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "rotation_degrees", _lean(DODGE_LEAN_DEG, 0.0), minf(phase, 0.10)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "scale", _base_scale, minf(phase, 0.10)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tint_to(_base_color, 0.10)

## The return, and it is SLOWER than the lunge by construction: it runs
## for the recovery phase's own length, which every profile sets far above
## LUNGE_IN_S. That asymmetry is the punish window made visible -- a
## fighter that has whiffed looks like it is still getting back up.
func _recover(phase: float) -> void:
	_stop_idle_bob()
	_kill(_pose_tween)
	_pose_tween = create_tween().set_parallel(true)
	_pose_tween.tween_property(_slot, "position", _base_position, phase) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "rotation_degrees", _base_rotation, phase) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "scale", _base_scale, phase) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tint_to(_base_color, minf(phase, 0.25))

## Hit clean: shoved back, then a short wobble that decays. Deliberately
## does NOT touch the tint -- Fighter emits hit_taken BEFORE this state,
## so the impact flash is already running and resetting the colour here
## would cut it off on the very frame it was meant to read.
func _stagger() -> void:
	_stop_idle_bob()
	_kill(_pose_tween)
	_pose_tween = create_tween()
	_pose_tween.set_parallel(true)
	_pose_tween.tween_property(_slot, "position", _offset(-STAGGER_RECOIL, 0.0), STAGGER_SETTLE_S) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "scale", _base_scale, STAGGER_SETTLE_S)
	_pose_tween.tween_property(_slot, "rotation_degrees", _lean(-6.0, STAGGER_ROLL_DEG), STAGGER_SETTLE_S) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_pose_tween.set_parallel(false)
	_pose_tween.tween_property(_slot, "rotation_degrees", _lean(-3.0, -STAGGER_ROLL_DEG * 0.55), 0.10) \
		.set_trans(Tween.TRANS_SINE)
	_pose_tween.tween_property(_slot, "rotation_degrees", _base_rotation, 0.14) \
		.set_trans(Tween.TRANS_SINE)

func _knock_out() -> void:
	_stop_idle_bob()
	_kill(_pose_tween)
	var fallen := Vector3(_base_position.x, KO_CENTRE_Y, _base_position.z)
	_pose_tween = create_tween().set_parallel(true)
	_pose_tween.tween_property(_slot, "position", fallen, KO_S) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "rotation_degrees", _lean(KO_FALL_DEG, 0.0), KO_S) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pose_tween.tween_property(_slot, "scale", _base_scale, KO_S)
	_tint_to(_base_color.darkened(0.45), KO_S)

func _rest(duration: float) -> void:
	_kill(_pose_tween)
	_pose_tween = create_tween().set_parallel(true)
	_pose_tween.tween_property(_slot, "position", _base_position, duration).set_trans(Tween.TRANS_SINE)
	_pose_tween.tween_property(_slot, "rotation_degrees", _base_rotation, duration).set_trans(Tween.TRANS_SINE)
	_pose_tween.tween_property(_slot, "scale", _base_scale, duration).set_trans(Tween.TRANS_SINE)
	_tint_to(_base_color, duration)

# ------------------------------------------------------------ idle bob

## Started only from IDLE, and killed by every pose below, so the bob can
## never be writing `position` at the same time as a telegraph.
func _start_idle_bob() -> void:
	_stop_idle_bob()
	var high := _base_position + Vector3(0.0, IDLE_BOB_RISE, 0.0)
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(_slot, "position", high, IDLE_BOB_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.16)
	_idle_tween.tween_property(_slot, "position", _base_position, IDLE_BOB_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_idle_bob() -> void:
	_kill(_idle_tween)
	_idle_tween = null

# ------------------------------------------------------------ helpers

## A pose offset in the fighter's own local space. Both fighters are
## authored facing each other along their own local +Z (PlayerFighter is
## yawed +90 at x=-1, OpponentFighter -90 at x=+1), so "toward the
## opponent" is +Z for BOTH and one sign convention serves both sides.
## scripts/dev/BattleReadabilityProbe.gd measures that rather than
## trusting it, because a scene edit could silently flip it.
func _offset(forward: float, rise: float) -> Vector3:
	return _base_position + Vector3(0.0, rise, forward)

## Pitch (toward/away from the opponent) and roll, as a full vector --
## never as `rotation_degrees:x` / `:z` sub-property tweens, which would
## put two writers on one property and let whichever ran second win.
func _lean(pitch_deg: float, roll_deg: float) -> Vector3:
	return _base_rotation + Vector3(pitch_deg, 0.0, roll_deg)

func _tint_to(color: Color, duration: float, ease_mode: Tween.EaseType = Tween.EASE_OUT) -> void:
	_ensure_material()
	if _material == null:
		return
	_kill(_tint_tween)
	_tint_tween = create_tween()
	_tint_tween.tween_property(_material, "albedo_color", color, maxf(duration, MIN_POSE_S)) \
		.set_trans(Tween.TRANS_SINE).set_ease(ease_mode)

## Takes ownership of a material this view may recolour.
##
## LAZY, and that is load-bearing: children _ready() before their parent,
## so at this node's _ready() the fighter has not run _apply_profile_art()
## yet and the slot is still carrying whatever the scene authored. The
## first tint request always arrives later than Fighter._ready(), so by
## then the placeholder tint -- or a lot-4 .glb -- is really installed.
##
## It DUPLICATES before writing. With the placeholder that is a copy of a
## copy and costs nothing; with an imported model it is the difference
## between tinting this fighter and tinting every instance of that .glb
## in the project, because Godot's glTF importer binds one shared
## material on the mesh itself (see ModelSlot.slot_material()).
func _ensure_material() -> void:
	if _material_resolved:
		return
	_material_resolved = true
	if _slot == null:
		return
	var current := _slot.slot_material() as StandardMaterial3D
	if current == null:
		# Not a StandardMaterial3D (a shader material on a future asset,
		# say). The transform telegraph still reads in full; only colour
		# is unavailable, and every _tint_to() below no-ops safely.
		return
	_material = current.duplicate() as StandardMaterial3D
	_base_color = _material.albedo_color
	_slot.apply_material(_material)

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
