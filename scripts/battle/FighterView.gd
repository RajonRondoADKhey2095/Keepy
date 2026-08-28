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
## intensity itself is the clock a defender reads. A dodge is told apart
## by SHAPE (lean-back), never by tint. A telegraph that shares its
## channel with a harmless action is a telegraph that has to be decoded
## rather than seen.
##
## =====================================================================
## THE TINT ALONE CANNOT CARRY IT -- MEASURED AT LOT 6, STILL TRUE
##
## The paragraph above was written when both fighters were flat unlit
## capsules, where `albedo_color` IS the colour on screen and a ramp to
## ALERT_COLOR lands on ALERT_COLOR exactly. On an imported .glb the same
## write MULTIPLIES a baseColor texture instead, and how much of the ramp
## survives is then a property of the ASSET, not of this file.
##
## Measured on the shipped Battle scene, rest vs fully-alarmed, averaged
## in linear light over the fighter's OWN pixels:
##
##   fighter                          luminance   hue swing   sat swing
##   capsule Keepy    (lots 2-5)        1.63:1       26.9 deg    +0.18
##   capsule Sparring (lots 2-5)        1.61:1      159.6 deg    +0.47
##   Keepy squirrel .glb                2.21:1       11.4 deg    +0.53
##   Sparring owl .glb                  1.57:1       10.2 deg    +0.52
##
## The player's squirrel comes out AHEAD. The OPPONENT -- the fighter a
## player actually reads -- does not: its hue swing collapses from 159.6
## degrees to 10.2, because a blue capsule turning red is a
## near-complementary flip and a brown owl turning red is barely a hue
## change at all. So the telegraph cannot live on the asset's material
## alone, and lot 6 added engine-side geometry above the head to carry
## it: colours and shapes this project owns, which no future .glb can
## weaken.
##
## =====================================================================
## LOT 7: THAT GEOMETRY IS NOW A CHARGE BAR, AND THE MARKER IS DELETED
##
## Lot 6's marker was a triangle that grew over the wind-up. It said "an
## attack is coming, and roughly this far along". Four device reports in
## a row said that was not enough: the player knew an attack was coming
## and still could not defend, because nothing told them WHEN it lands.
##
## `Body/Charge` is a two-piece bar -- a dark Track and a bright Fill --
## and its fill fraction is `Fighter.charge_progress()` read every frame.
## The bar reaching full IS the instant of impact, by construction and
## not by tuning: the strike resolves on the first tick of ACTIVE, which
## is the tick the wind-up runs out on, which is the tick progress
## reaches 1.0. BattleReadabilityProbe PHASE G gates that to the frame.
##
## THE MARKER WAS REMOVED RATHER THAN KEPT ALONGSIDE, and that is a
## decision, not tidying. The bar carries the marker's entire content
## (an attack telegraph is running, this far through) and strictly more.
## Two growing cues stacked in the same patch of screen would compete for
## one read, and the player would learn whichever happens to lead -- the
## exact failure this file already warns about for tint versus marker
## ("the two channels have to be the SAME clock"). The marker's contrast
## argument transfers intact: bright fill inside a near-black track, so
## one of the two always clears 3.0:1 whether it is drawn over the dark
## sky or the lit ground, and PHASE G still gates that.
##
## THE TINT RAMP IS KEPT. It is a different surface (the body itself, no
## extra geometry), lot 6 measured that it survives on the player's
## model, and two channels beat one. What it no longer has to do is carry
## the telegraph alone.
##
## Colour still means EXACTLY ONE THING. The bar appears for an ATTACK
## wind-up and for nothing else; a dodge raises no bar and reddens
## nothing.

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

## Dodge slips back and away. It does not use colour -- see the header.
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
## Impact, on the fighter TAKING it. THREE outcomes, three looks.
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
## that was hit. Lot 5 added the distinction the device report asked for:
## a player cannot tell a mistimed defence from a defence that never
## happened, and an option a player cannot learn the timing of is a dead
## option (the Chased lesson, already in CLAUDE.md). Lot 7 keeps that
## distinction and drops the block flash with the action it described.
##
## BREAK_FLASH_COLOR is violet on purpose: it must not be read as the
## telegraph's red, and it must not be read as the neutral white of
## "you were just standing there". It says "you DID press it, and you
## were early or late".
const HIT_FLASH_COLOR := Color(1.0, 1.0, 1.0)
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

## Shape, not just colour, for the two dodge verdicts. Colour alone is
## the channel most likely to be lost to a small screen, a bright room,
## or colour-blindness, and these are exactly the two events the player
## has to learn a timing from.
##
## An evade that WORKED slips a little further clear. A dodge that was
## MISTIMED flares outward and rolls: the shape falls apart. The two are
## opposite motions on purpose.
const BREAK_FLARE := 1.14
const BREAK_ROLL_DEG := 14.0
const BREAK_S := 0.07
## The extra slip an evade adds on top of the pose it is already in --
## small, because the dodge pose is doing the reading; this only says
## "and it worked".
const EVADE_SLIP := -0.10
const EVADE_S := 0.08

## Held while a riposte is owed -- see _on_riposte_changed(). Deliberately
## a dimmer aqua than DODGE_FLASH_COLOR: a flash is an event and may shout,
## a hold sits on screen for over a second and must not.
const RIPOSTE_HOLD_COLOR := Color(0.45, 0.92, 0.86)
const RIPOSTE_FADE_S := 0.10

## The engine-side charge bar (Body/Charge). Placed from the slot's
## MEASURED visual AABB, never from a per-profile number, so a future
## .glb of any height gets it in the right place with no .tres field to
## remember -- the "one .tres and one .glb, zero lines of code" contract
## has to survive this file too.
const CHARGE_GAP := 0.22
## The Fill mesh's authored width, in the .tscn. Kept here because the
## fill is grown by scaling and re-centring it, which needs the number in
## code; asserted against the mesh at resolve time so the two cannot
## drift apart silently.
const CHARGE_WIDTH := 0.90
## Colours live HERE and are applied to the two meshes at resolve time,
## rather than being authored in BattleFighter.tscn. One source of truth:
## PHASE G gates these constants for contrast AND checks that the meshes
## really carry them, so a scene edit cannot quietly ship a bar that
## fails the floor the probe just approved.
##
## Bright fill inside a near-black track. Neither has to beat both
## backgrounds -- between them they must leave no backdrop that swallows
## the bar, which is exactly the argument lot 6's marker shipped with.
const CHARGE_FILL_COLOR := Color(1.0, 0.86, 0.35)
const CHARGE_TRACK_COLOR := Color(0.03, 0.02, 0.02)
## THE EVADE WINDOW, DRAWN. A band straddling the bar, marking the span
## of the fill in which a dodge tapped now would cover the blow.
##
## =====================================================================
## WHY THE WINDOW IS DRAWN AND NOT LEFT TO BE LEARNED
##
## Knowing WHEN the blow lands is only half of what a defender needs; the
## other half is when to PRESS, and those are not the same instant. A
## dodge has a startup and a finite active window, so the correct tap is
## a span ENDING slightly before the bar completes -- measured on the
## shipped profiles, ticks 26..49 of 54, i.e. the fill between 48% and
## 91%. A player told "tap when it is full" taps 83 ms too late, every
## time, and learns that the button does not work. That is the sentence
## four device reports in a row contained.
##
## So the span is drawn on the bar. The band stands PROUD of the track
## rather than being a coloured segment inside it: drawn inside, it would
## sit behind the fill for the first half of the wind-up and against the
## fill for the second, so its contrast would be a different number in
## each half. Standing proud, it is always seen against the same two
## backdrops the rest of the bar is gated against.
##
## Aqua on purpose -- the same family as DODGE_FLASH_COLOR, which is what
## a successful evade flashes. The mark and the reward say the same word.
const CHARGE_CUE_COLOR := Color(0.62, 1.0, 0.92)
## Off is a short fade, not a cut -- the warning ending is not itself
## information, so it must not draw the eye away from the strike. The bar
## is held FULL for the whole of it, because it was full at the instant
## the blow left and cutting it back would erase the one frame that
## teaches the timing.
const CHARGE_OFF_S := 0.12

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

## The charge bar, its two pieces, and its own tween. Resolved lazily for
## the same reason the material is: at this node's _ready() the slot still
## carries the placeholder, so its visual AABB -- which decides where the
## bar sits -- is not the one the fighter will actually be drawn with.
var _charge: Node3D = null
var _charge_fill: MeshInstance3D = null
var _charge_cue: MeshInstance3D = null
## The evade window as (lo, hi) fractions of this fighter's bar, handed
## in by BattleArena. NEGATIVE until it is, and the band stays hidden --
## a window derived from this fighter's OWN dodge numbers would be a
## guess about the fighter standing opposite, which is exactly the kind
## of plausible-but-wrong fixture this repo keeps paying for.
var _dodge_window := Vector2(-1.0, -1.0)
var _charge_resolved := false
var _charge_tween: Tween = null

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
	# Off until the wiring below is proven good: a view that failed to
	# find its fighter must not spend a frame callback asking it anything.
	set_process(false)
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
	set_process(true)
	_fighter.state_changed.connect(_on_state_changed)
	_fighter.hit_taken.connect(_on_hit_taken)
	_fighter.riposte_changed.connect(_on_riposte_changed)

## The ONE per-frame read in this file, and the only reason it exists:
## the charge bar has to be the FSM's phase clock rather than an
## animation that merely started at the same time as it.
##
## =====================================================================
## WHY A TWEEN WOULD BE WRONG HERE AND NOWHERE ELSE
##
## Every other animation in this file is a tween on ENGINE time, and that
## is fine because none of them makes a promise about a specific instant
## -- a lunge that finishes a frame late still reads as a lunge. The bar
## makes exactly that promise: full means the blow has left. A tween
## started on the WINDUP transition and run for the phase's nominal
## length would drift against the arena's fixed-step accumulator by
## whatever the frame times happened to be, and it would drift most
## visibly at the end, where the whole mechanic lives.
##
## Reading `charge_progress()` instead makes the two the same number by
## construction. It is still STRICTLY READ-ONLY -- this reads a float and
## writes a transform on a mesh; nothing crosses back -- so the rule that
## makes this file safe is untouched, and PHASE B still proves it by
## running the same fight with and without real frames between ticks.
func _process(_delta: float) -> void:
	if not _enabled or _fighter == null:
		return
	if not _fighter.is_charging():
		return
	_set_charge_fill(_fighter.charge_progress())

## The span of THIS fighter's charge bar in which its OPPONENT should tap
## a dodge, as (lo, hi) fractions. Handed in by BattleArena, the only
## object that knows both fighters -- see _dodge_window.
##
## Presentation only: it paints a band and nothing else. Called once per
## round, never during a tick.
func set_dodge_window(lo: float, hi: float) -> void:
	# A negative bound is BattleArena saying "this fighter has no wind-up
	# to draw a band on" -- an instant attacker. Kept as a negative rather
	# than clamped into range, so _apply_dodge_window() hides the band
	# instead of drawing a zero-width sliver at the left edge.
	if lo < 0.0 or hi < 0.0:
		_dodge_window = Vector2(-1.0, -1.0)
		_apply_dodge_window()
		return
	_dodge_window = Vector2(clampf(lo, 0.0, 1.0), clampf(hi, 0.0, 1.0))
	_apply_dodge_window()

func _exit_tree() -> void:
	_kill(_pose_tween)
	_kill(_tint_tween)
	_kill(_idle_tween)
	_kill(_charge_tween)
	_pose_tween = null
	_tint_tween = null
	_idle_tween = null
	_charge_tween = null
	if _fighter == null:
		return
	if _fighter.state_changed.is_connected(_on_state_changed):
		_fighter.state_changed.disconnect(_on_state_changed)
	if _fighter.hit_taken.is_connected(_on_hit_taken):
		_fighter.hit_taken.disconnect(_on_hit_taken)
	if _fighter.riposte_changed.is_connected(_on_riposte_changed):
		_fighter.riposte_changed.disconnect(_on_riposte_changed)

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
	_charge_off()
	_rest(0.28)

func _on_state_changed(state: BattleTypes.State, action: BattleTypes.Action) -> void:
	if not _enabled:
		return
	# The phase's REAL length, straight from the fighter that just entered
	# it, rather than this file re-deriving it from the profile. One less
	# copy of the action -> timing map, and it stays true if a phase is
	# ever shortened by the overshoot Fighter.advance() carries.
	var phase := maxf(_fighter.phase_duration(), MIN_POSE_S)
	# The bar is raised and lowered from HERE and nowhere else. Every
	# other pose helper would otherwise need its own _charge_off(), and
	# the one that got forgotten would leave a countdown hanging over a
	# fighter that is no longer threatening anything -- the exact failure
	# the bar exists to prevent, wearing the opposite sign.
	#
	# ACTIVE is the tick the strike LEAVES, so the bar is pinned FULL
	# there and then faded, rather than snapped away: the frame that
	# teaches the player "this is where the tap belonged" is the frame
	# where the fill met the end of the track.
	#
	# `is_charging()` and not `state == WINDUP`: a fighter whose wind-up is
	# zero passes through WINDUP for a single tick on its way to ACTIVE,
	# and raising a bar for one frame would flash a countdown for an attack
	# that has already been thrown. The instant attacker simply has no bar,
	# and that follows from its timings rather than from a flag.
	if state == BattleTypes.State.WINDUP and action == BattleTypes.Action.ATTACK \
			and _fighter.is_charging():
		_charge_on()
	elif state == BattleTypes.State.ACTIVE and action == BattleTypes.Action.ATTACK:
		_charge_release()
	else:
		_charge_off()
	match state:
		BattleTypes.State.IDLE:
			_rest(0.16)
			_start_idle_bob()
		BattleTypes.State.WINDUP:
			_windup(action, phase)
		BattleTypes.State.ACTIVE:
			_active(action, phase)
		BattleTypes.State.RECOVERY:
			_recover(phase)
		BattleTypes.State.STAGGER:
			_stagger()
		BattleTypes.State.KO:
			_knock_out()

## The verdict of one strike, on the fighter that just took it. THREE
## distinct readings:
##
##   dodge worked  bright aqua + an extra slip            (clean miss)
##   dodge broke   violet      + the pose flares and rolls (MISTIMED)
##   caught cold   white       + nothing                   (no input)
##
## The third versus the second is the pair that matters. Before lot 5
## they were the same white flash, so a dodge pressed 80 ms too late was
## visually identical to never having pressed anything -- which is
## exactly what "you have no confidence that it works" describes. Lot 7
## adds the other half of the same lesson: the charge bar says which way
## the tap was wrong, so a violet flash is now actionable rather than
## merely informative.
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
		_:
			# A clean hit. Whether it is a FAILURE or merely a hit
			# depends entirely on whether the player asked for a defence
			# -- which is why Fighter hands that fact over explicitly.
			if attempted == BattleTypes.Action.NONE:
				_flash(HIT_FLASH_COLOR, FLASH_OUT_S)
				return
			_flash(BREAK_FLASH_COLOR, BREAK_OUT_S)
			_break_accent()

## THE REWARD, SHOWN. A successful dodge already flashes aqua for a
## fraction of a second; this HOLDS that colour for exactly as long as the
## riposte is spendable, so "you are owed a heavy hit" is a state the
## player can see rather than a fact they have to remember.
##
## Same aqua family as DODGE_FLASH_COLOR and the bar's evade band: the
## mark that says "tap here", the flash that says "that worked" and the
## hold that says "now cash it" are one colour telling one story. The red
## ramp still means exactly one thing -- an attack is coming -- and it
## lives on the OPPONENT, never on the fighter wearing this.
##
## Driven by a signal rather than polled per frame: the hold has to end on
## the same tick the window does, and the only object that knows that tick
## is the FSM.
func _on_riposte_changed(ready: bool) -> void:
	if not _enabled:
		return
	_ensure_material()
	if _material == null:
		return
	_kill(_tint_tween)
	_tint_tween = create_tween()
	_tint_tween.tween_property(_material, "albedo_color", _rest_color(), RIPOSTE_FADE_S)

## What this fighter's colour SETTLES to once a flash is over. Not
## `_base_color`: a riposte is owed for over a second, and the evade flash
## that earns it fires immediately after `riposte_changed`, so a flash
## resting on the base colour would wipe the hold the same frame it went
## up -- the cue would exist and never be seen.
func _rest_color() -> Color:
	if _fighter != null and _fighter.is_riposte_ready():
		return RIPOSTE_HOLD_COLOR
	return _base_color

func _flash(colour: Color, out_s: float) -> void:
	_ensure_material()
	if _material == null:
		return
	_kill(_tint_tween)
	_tint_tween = create_tween()
	_tint_tween.tween_property(_material, "albedo_color", colour, FLASH_IN_S)
	_tint_tween.tween_property(_material, "albedo_color", _rest_color(), out_s)

## The evade worked: a little more distance, fast. Positive, and clearly
## not an impact -- nothing touched this fighter.
func _evade_accent() -> void:
	_kill(_pose_tween)
	_pose_tween = create_tween()
	_pose_tween.tween_property(_slot, "position", _slot.position + _offset(EVADE_SLIP, 0.0) - _base_position, EVADE_S) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## The dodge BROKE. Opposite motion to _evade_accent(): the shape flares
## outward and rolls instead of slipping clear, so the two verdicts are
## told apart by silhouette and not only by hue. STAGGER follows
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
	var attacking := action == BattleTypes.Action.ATTACK
	var lean := WINDUP_LEAN_DEG if attacking else WINDUP_LEAN_DEG * 0.4
	var reach := -WINDUP_RECOIL if attacking else -WINDUP_RECOIL * 0.35
	_pose_tween.tween_property(_slot, "position", _offset(reach, 0.0), phase) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pose_tween.tween_property(_slot, "rotation_degrees", _lean(lean, 0.0), phase) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_pose_tween.tween_property(_slot, "scale", _base_scale * WINDUP_SCALE, phase) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if not attacking:
		_tint_to(_rest_color(), phase * 0.5)
		return
	# Colour means exactly ONE thing: "an attack telegraph is running".
	# The bar above the head says the rest -- how far through it is, to
	# the frame -- so the two channels share one clock instead of two.
	_tint_to(ALERT_COLOR, phase, Tween.EASE_IN)

## The effect window. Attack snaps forward; a dodge gets its own
## silhouette so it cannot be mistaken for a blow being thrown.
func _active(action: BattleTypes.Action, phase: float) -> void:
	_stop_idle_bob()
	_kill(_pose_tween)
	match action:
		BattleTypes.Action.ATTACK:
			_lunge()
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

func _slip(phase: float) -> void:
	_pose_tween = create_tween().set_parallel(true)
	_pose_tween.tween_property(_slot, "position", _offset(DODGE_SLIDE, 0.05), minf(phase, 0.10)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "rotation_degrees", _lean(DODGE_LEAN_DEG, 0.0), minf(phase, 0.10)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_slot, "scale", _base_scale, minf(phase, 0.10)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tint_to(_rest_color(), 0.10)

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
	_tint_to(_rest_color(), minf(phase, 0.25))

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
	_tint_to(_rest_color(), duration)

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

## Raises the charge bar for an attack wind-up. There is no tween here on
## purpose: the fill is written every frame in _process() from
## Fighter.charge_progress(), so its length is the FSM's own phase clock
## rather than an engine-time animation that merely started at the same
## moment. A tween would look identical and be wrong exactly where it
## matters -- at the end, where the bar's promise is that full means
## thrown.
func _charge_on() -> void:
	_ensure_charge()
	if _charge == null:
		return
	_kill(_charge_tween)
	_charge.visible = true
	_charge.scale = Vector3.ONE
	_set_charge_fill(0.0)

## The strike has left. Pin the bar full -- it WAS full on this tick --
## and fade the whole thing out without shrinking the fill, so the last
## thing the player sees is the fill meeting the end of the track.
func _charge_release() -> void:
	if not _charge_resolved or _charge == null or not _charge.visible:
		return
	_set_charge_fill(1.0)
	_kill(_charge_tween)
	_charge_tween = create_tween()
	_charge_tween.tween_property(_charge, "scale", Vector3(1.0, 0.0, 1.0), CHARGE_OFF_S) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_charge_tween.tween_callback(func() -> void: _charge.visible = false)

## Takes the bar down for anything that is not an attack. Never resolved
## means never shown -- nothing to take down, and resolving here would
## force the AABB read on the first IDLE transition, before the model is
## necessarily installed.
func _charge_off() -> void:
	if not _charge_resolved or _charge == null:
		return
	_kill(_charge_tween)
	if not _charge.visible:
		return
	_charge.visible = false
	_set_charge_fill(0.0)

## The fill, at fraction `p`. Scaled AND re-centred so it grows from the
## left edge of the track: a BoxMesh is centred on its own origin, so
## scaling alone would grow it in both directions from the middle and the
## bar would read as a widening block rather than as a filling one.
func _set_charge_fill(p: float) -> void:
	if _charge_fill == null:
		return
	var f := clampf(p, 0.0, 1.0)
	_charge_fill.scale.x = f
	_charge_fill.position.x = -CHARGE_WIDTH * 0.5 * (1.0 - f)

## Finds the bar, colours it, and puts it just clear of whatever the slot
## actually draws -- measured, so it lands correctly above a 1.35 m
## squirrel and a 1.70 m owl without either profile carrying a height
## field.
##
## Lazy for the same reason _ensure_material() is: children _ready()
## before their parent, so at this node's _ready() the fighter has not run
## _apply_profile_art() and visual_aabb() would still be reporting the
## capsule.
func _ensure_charge() -> void:
	if _charge_resolved:
		return
	_charge_resolved = true
	if _slot == null:
		return
	_charge = _slot.get_node_or_null("Charge") as Node3D
	if _charge == null:
		# A fighter scene without the bar still animates in full; only the
		# channel that states the impact instant is missing. Loud, because
		# that is a scene that has drifted from this file.
		push_warning("FighterView: no Body/Charge bar, attack telegraph is tint-only.")
		return
	_charge_fill = _charge.get_node_or_null("Fill") as MeshInstance3D
	_charge_cue = _charge.get_node_or_null("Cue") as MeshInstance3D
	var track := _charge.get_node_or_null("Track") as MeshInstance3D
	if _charge_fill == null or track == null or _charge_cue == null:
		push_warning("FighterView: Body/Charge is missing Track, Fill or Cue.")
		_charge = null
		return
	# The colours come from THIS file, not from the .tscn, so the numbers
	# BattleReadabilityProbe gates for contrast are the numbers that get
	# drawn. A scene that authored its own would be a second source of
	# truth for a value a probe just approved somewhere else.
	track.set_surface_override_material(0, _bar_material(CHARGE_TRACK_COLOR))
	_charge_fill.set_surface_override_material(0, _bar_material(CHARGE_FILL_COLOR))
	_charge_cue.set_surface_override_material(0, _bar_material(CHARGE_CUE_COLOR))
	_apply_dodge_window()
	_charge.position.y = _slot.visual_aabb().end.y + CHARGE_GAP
	# Cancel the fighter's yaw so the bar's flat face points at the camera
	# instead of at the opposite wall. The fighters are turned a quarter
	# turn to face each other and a child of the slot inherits that -- lot
	# 6 shipped the marker edge-on the first time for exactly this reason.
	# Read off the slot's own basis rather than hard-coding +-90, so it
	# stays correct if the arena is ever re-laid-out.
	#
	# Once, at resolve time, and not per frame: the pose tweens lean the
	# body by at most 8 degrees, which tilts the bar slightly with the
	# fighter, and that reads as part of the same motion.
	_charge.rotation.y = -_slot.global_basis.get_euler().y
	_charge.visible = false
	_set_charge_fill(0.0)

## Unshaded, like every other surface in this project: the colour written
## is the colour seen, which is the only reason a contrast number
## measured off a constant means anything at all (CLAUDE.md, "DIRECTION
## ARTISTIQUE PERMANENTE").
## Places the evade band across [lo, hi] of the track, or hides it when
## no window has been handed in. Same scale-and-recentre arithmetic as
## the fill, and for the same reason: a BoxMesh is centred on its origin.
func _apply_dodge_window() -> void:
	if _charge_cue == null:
		return
	if _dodge_window.x < 0.0 or _dodge_window.y <= _dodge_window.x:
		_charge_cue.visible = false
		return
	var span := _dodge_window.y - _dodge_window.x
	var centre := (_dodge_window.x + _dodge_window.y) * 0.5
	_charge_cue.visible = true
	_charge_cue.scale.x = span
	_charge_cue.position.x = CHARGE_WIDTH * (centre - 0.5)

func _bar_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
