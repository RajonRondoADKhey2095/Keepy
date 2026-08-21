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
##
## =====================================================================
## THE TINT ALONE CANNOT CARRY IT ANY MORE -- MEASURED AT LOT 6
##
## The paragraph above was written when both fighters were flat unlit
## capsules, where `albedo_color` IS the colour on screen and a ramp to
## ALERT_COLOR lands on ALERT_COLOR exactly. On an imported .glb the same
## write MULTIPLIES a baseColor texture instead, and how much of the ramp
## survives is then a property of the ASSET, not of this file.
##
## Measured on the shipped Battle scene, rest vs fully-alarmed, averaged
## in linear light over the fighter's OWN pixels (mask taken by rendering
## the same frame with the slot hidden, so no colour classification and no
## silhouette edge can contaminate it):
##
##   fighter                          luminance   hue swing   sat swing
##   capsule Keepy    (lots 2-5)        1.63:1       26.9 deg    +0.18
##   capsule Sparring (lots 2-5)        1.61:1      159.6 deg    +0.47
##   Keepy squirrel .glb                2.21:1       11.4 deg    +0.53
##   Sparring owl .glb                  1.57:1       10.2 deg    +0.52
##
## The player's squirrel comes out AHEAD -- a warm cream body times red
## is a bigger luminance drop than the orange capsule managed. The
## opponent does not. Its luminance and saturation swings survive; what
## collapses is HUE, from 159.6 degrees to 10.2. The blue capsule turning
## red was a near-complementary flip, the single loudest thing about the
## old telegraph. A brown owl turning red is barely a hue change at all,
## because red times brown is brown.
##
## The opponent is the fighter a player actually reads, so lot 6 would
## otherwise have shipped a quieter warning than the one five lots were
## spent making legible.
##
## So the cue no longer lives only on the asset's material. `Body/Alert`
## is an engine-side marker -- geometry and colours this project owns,
## above the fighter's head, hidden except during an attack telegraph.
## That is the project's established answer to exactly this problem: the
## pursuer's eyes in Chased are engine-side nodes and not part of the
## .glb, for the same reason (see CLAUDE.md, "cue emission -> separate
## node; cue albedo -> slot material"). The tint ramp is KEPT -- it still
## reads on a light model, and two channels beat one -- but nothing now
## depends on it alone.
##
## The marker is two prisms, bright core inside a near-black outline, so
## one of the two always clears 3.0:1 whether it is drawn against the
## dark sky or against the lit ground. BattleReadabilityProbe PHASE G
## gates that, and gates that the marker never shows for a guard or a
## dodge -- colour still means exactly one thing.

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
## Impact, on the fighter TAKING it. FOUR outcomes, four looks -- lot 5.
##
## =====================================================================
## THIS IS A DIFFERENT COLOUR CHANNEL FROM THE TELEGRAPH, AND THE LOT-2
## RULE IS INTACT
##
## Lot 2's rule is that the sustained RAMP toward ALERT_COLOR during a
## windup means one thing and one thing only: an attack is coming at
## you. That rule is untouched -- _windup() is still the only place a
## colour is held over time, and it still ramps for attacks alone.
##
## These are IMPACT flashes: momentary, fired on contact, on the fighter
## that was hit. That channel already carried two meanings before this
## lot (white / cold blue). Lot 5 adds the two it was missing, because
## the device report was precisely that the player cannot tell a
## mistimed defence from a defence that never happened -- and an option
## a player cannot learn the timing of is a dead option (the Chased
## lesson, already in CLAUDE.md).
##
## BREAK_FLASH_COLOR is violet on purpose: it must not be read as the
## telegraph's red, and it must not be read as the neutral white of
## "you were just standing there". It says "you DID press it, and you
## were early or late".
const HIT_FLASH_COLOR := Color(1.0, 1.0, 1.0)
const BLOCK_FLASH_COLOR := Color(0.70, 0.88, 1.0)
const DODGE_FLASH_COLOR := Color(0.62, 1.0, 0.92)
const BREAK_FLASH_COLOR := Color(0.86, 0.26, 1.0)
const FLASH_IN_S := 0.05
const FLASH_OUT_S := 0.24
## A broken defence holds its flash longer than a plain hit. The player
## has to have time to notice that this was a DIFFERENT failure from
## simply standing still.
const BREAK_OUT_S := 0.40
## A successful evade is the one outcome with no contact at all, so it
## gets the shortest, brightest flash of the four -- a snap, not a bruise.
const DODGE_OUT_S := 0.16

## Shape, not just colour, for the two defensive verdicts. Colour alone
## is the channel most likely to be lost to a small screen, a bright
## room, or colour-blindness, and these are exactly the two events the
## player has to learn a timing from.
##
## A guard that HELD compresses further under the blow: it absorbed it.
## A guard or dodge that BROKE flares outward and rolls: the shape falls
## apart. The two are opposite motions on purpose.
const ABSORB_SQUASH := 0.90
const ABSORB_S := 0.09
const BREAK_FLARE := 1.14
const BREAK_ROLL_DEG := 14.0
const BREAK_S := 0.07
## The extra slip an evade adds on top of the pose it is already in --
## small, because the dodge pose is doing the reading; this only says
## "and it worked".
const EVADE_SLIP := -0.10
const EVADE_S := 0.08

## The engine-side attack marker (Body/Alert). Sized and placed from the
## slot's MEASURED visual AABB, never from a per-profile number, so a
## future .glb of any height gets it in the right place with no .tres
## field to remember -- the "one .tres and one .glb, zero lines of code"
## contract has to survive this file too.
const ALERT_GAP := 0.22
## It starts visible but small rather than at nothing: a marker that pops
## in from zero reads as an event, and the event has not happened yet.
## Growth over the windup is the clock, same as the tint.
const ALERT_MIN_SCALE := 0.28
const ALERT_MAX_SCALE := 1.0
## Off is a short fade, not a cut -- the warning ending is not itself
## information, so it must not draw the eye away from the strike.
const ALERT_OFF_S := 0.09

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

## The attack marker and its own tween. Resolved lazily for the same
## reason the material is: at this node's _ready() the slot still carries
## the placeholder, so its visual AABB -- which decides where the marker
## sits -- is not the one the fighter will actually be drawn with.
var _alert: Node3D = null
var _alert_resolved := false
var _alert_tween: Tween = null

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
	_kill(_alert_tween)
	_pose_tween = null
	_tint_tween = null
	_idle_tween = null
	_alert_tween = null
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
	_alert_off()
	_rest(0.28)

func _on_state_changed(state: BattleTypes.State, action: BattleTypes.Action) -> void:
	if not _enabled:
		return
	# The phase's REAL length, straight from the fighter that just entered
	# it, rather than this file re-deriving it from the profile. One less
	# copy of the action -> timing map, and it stays true if a phase is
	# ever shortened by the overshoot Fighter.advance() carries.
	var phase := maxf(_fighter.phase_duration(), MIN_POSE_S)
	# The marker is driven from HERE and nowhere else. Every other pose
	# helper would otherwise need its own _alert_off(), and the one that
	# got forgotten would leave a warning hanging over a fighter that is
	# no longer threatening anything -- the exact failure the marker
	# exists to prevent, wearing the opposite sign.
	if state == BattleTypes.State.WINDUP and BattleTypes.is_attack_like(action):
		_alert_on(maxf(_fighter.telegraph_duration(), MIN_POSE_S))
	else:
		_alert_off()
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

## The verdict of one strike, on the fighter that just took it. FOUR
## distinct readings, which is the whole of lot 5's task C:
##
##   guard held    cold blue  + the brace compresses further (absorbed)
##   dodge worked  bright aqua + an extra slip             (clean miss)
##   defence broke violet     + the pose flares and rolls  (MISTIMED)
##   caught cold   white      + nothing                    (no input)
##
## The fourth versus the third is the pair that matters. Before this lot
## they were the same white flash, so a guard pressed 80 ms too late was
## visually identical to never having pressed anything -- which is
## exactly what "you have no confidence that it works" describes.
##
## The recoil of a clean hit still belongs to STAGGER, which Fighter
## emits immediately after this; the break flare below is deliberately
## shorter than that transition so it reads as the guard shattering
## FIRST and the body being thrown afterwards, not as two shoves.
func _on_hit_taken(_damage: int, outcome: BattleTypes.Outcome, attempted: BattleTypes.Action) -> void:
	if not _enabled:
		return
	if outcome == BattleTypes.Outcome.MISSED:
		return
	match outcome:
		BattleTypes.Outcome.DODGED:
			_flash(DODGE_FLASH_COLOR, DODGE_OUT_S)
			_evade_accent()
		BattleTypes.Outcome.BLOCKED:
			_flash(BLOCK_FLASH_COLOR, FLASH_OUT_S)
			_absorb_accent()
		_:
			# A clean hit. Whether it is a FAILURE or merely a hit
			# depends entirely on whether the player asked for a defence
			# -- which is why Fighter hands that fact over explicitly.
			if attempted == BattleTypes.Action.NONE:
				_flash(HIT_FLASH_COLOR, FLASH_OUT_S)
				return
			_flash(BREAK_FLASH_COLOR, BREAK_OUT_S)
			_break_accent()

func _flash(colour: Color, out_s: float) -> void:
	_ensure_material()
	if _material == null:
		return
	_kill(_tint_tween)
	_tint_tween = create_tween()
	_tint_tween.tween_property(_material, "albedo_color", colour, FLASH_IN_S)
	_tint_tween.tween_property(_material, "albedo_color", _base_color, out_s)

## The guard held: it compresses further into the blow. Scale only, from
## wherever the brace already is, so it reads as absorbing rather than as
## a second pose being started.
func _absorb_accent() -> void:
	_kill(_pose_tween)
	var squashed := Vector3(_slot.scale.x, _base_scale.y * GUARD_CROUCH * ABSORB_SQUASH, _slot.scale.z)
	_pose_tween = create_tween()
	_pose_tween.tween_property(_slot, "scale", squashed, ABSORB_S) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "scale", _slot.scale, ABSORB_S * 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## The evade worked: a little more distance, fast. Positive, and clearly
## not an impact -- nothing touched this fighter.
func _evade_accent() -> void:
	_kill(_pose_tween)
	_pose_tween = create_tween()
	_pose_tween.tween_property(_slot, "position", _slot.position + _offset(EVADE_SLIP, 0.0) - _base_position, EVADE_S) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## The defence BROKE. Opposite motion to _absorb_accent(): the shape
## flares outward and rolls instead of compressing, so the two verdicts
## are told apart by silhouette and not only by hue. STAGGER follows
## immediately and takes the pose over from here.
func _break_accent() -> void:
	_kill(_pose_tween)
	_pose_tween = create_tween().set_parallel(true)
	_pose_tween.tween_property(_slot, "scale", _base_scale * BREAK_FLARE, BREAK_S) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "rotation_degrees", _lean(0.0, BREAK_ROLL_DEG), BREAK_S) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

## Shows the attack marker and grows it over the telegraph's own length,
## with the same EASE_IN the tint ramp uses -- the two channels have to be
## the SAME clock, or a player would learn to read whichever one happens
## to lead.
##
## A feint gets telegraph_duration() here exactly like a plain attack
## does, so the marker finishes growing at the usual moment and then
## simply stays up through the hold. It cannot leak the lie: it is driven
## from the same number Fighter hands the tint.
func _alert_on(duration: float) -> void:
	_ensure_alert()
	if _alert == null:
		return
	_kill(_alert_tween)
	_alert.visible = true
	_alert.scale = Vector3.ONE * ALERT_MIN_SCALE
	_alert_tween = create_tween()
	_alert_tween.tween_property(_alert, "scale", Vector3.ONE * ALERT_MAX_SCALE, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _alert_off() -> void:
	if not _alert_resolved:
		# Never resolved means never shown -- nothing to take down, and
		# resolving here would force the AABB read on the first IDLE
		# transition, before the model is necessarily installed.
		return
	if _alert == null:
		return
	_kill(_alert_tween)
	if not _alert.visible:
		return
	_alert_tween = create_tween()
	_alert_tween.tween_property(_alert, "scale", Vector3.ZERO, ALERT_OFF_S) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_alert_tween.tween_callback(func() -> void: _alert.visible = false)

## Finds the marker and puts it just clear of whatever the slot actually
## draws -- measured, so it lands correctly above a 1.35 m squirrel and a
## 1.70 m owl without either profile carrying a height field.
##
## Lazy for the same reason _ensure_material() is: children _ready()
## before their parent, so at this node's _ready() the fighter has not run
## _apply_profile_art() and visual_aabb() would still be reporting the
## capsule.
func _ensure_alert() -> void:
	if _alert_resolved:
		return
	_alert_resolved = true
	if _slot == null:
		return
	_alert = _slot.get_node_or_null("Alert") as Node3D
	if _alert == null:
		# A fighter scene without the marker still animates in full; only
		# the second telegraph channel is missing. Loud, because that is
		# a scene that has drifted from this file.
		push_warning("FighterView: no Body/Alert marker, attack telegraph is tint-only.")
		return
	_alert.position.y = _slot.visual_aabb().end.y + ALERT_GAP
	# Cancel the fighter's yaw so the marker's flat face points at the
	# camera instead of at the opposite wall. The fighters are turned a
	# quarter-turn to face each other, and a child of the slot inherits
	# that -- the first version of this rendered the prism EDGE ON and
	# read as a 6 cm splinter rather than as a warning. Read off the
	# slot's own basis rather than hard-coding +-90, so it stays correct
	# if the arena is ever re-laid-out.
	#
	# Once, at resolve time, and not per frame: the pose tweens lean the
	# body by at most 8 degrees, which tilts the marker slightly with the
	# fighter, and that reads as part of the same motion.
	_alert.rotation.y = -_slot.global_basis.get_euler().y
	_alert.visible = false
	_alert.scale = Vector3.ZERO

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
