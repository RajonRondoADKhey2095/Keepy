extends Node3D
class_name Fighter
## ONE generic combatant. Everything specific to a given animal is read
## from `profile` (a FighterProfile .tres); nothing in this file names
## one. See FighterProfile.gd's header for the contract that guarantees.
##
## =====================================================================
## THE FSM IS SHARED BY PLAYER AND AI, AND THAT IS THE POINT
##
## There is no "player fighter" and no "AI fighter" -- there is a
## Fighter, and something that calls `request_action()` on it. A human
## tap (BattleHUD's two zones) and the AI brain (FighterBrain.gd) enter
## through the SAME function and are indistinguishable from here on.
## Swapping which one drives which fighter is a wiring change in
## BattleArena, not a code change here.
##
## That is not a stylistic preference: an AI running a parallel system
## with its own timings is an AI that can be balanced against rules the
## player is not actually playing by, and the divergence is invisible
## until someone measures it. This project has already paid for that
## exact class of bug once -- see CLAUDE.md on SubstituteModel.tscn, a
## test fixture that diverged from the real thing on the one axis that
## mattered.
##
## =====================================================================
## DETERMINISM
##
## This node has NO _process and NO _physics_process. It is advanced by
## BattleArena calling `advance(dt)` with a FIXED accumulated timestep,
## so the same inputs at the same tick indices always produce the same
## fight, at any framerate. Nothing here reads `delta` from the engine,
## and nothing here draws from the global RNG -- this file contains no
## randomness at all.
##
## =====================================================================
## THE LOT-3 ART SWAP POINT
##
## $Body is a ModelSlot (scripts/world/ModelSlot.gd), carrying a capsule
## placeholder exactly the way Pursuer.tscn's $Silhouette carries one.
## Installing a Meshy .glb is: set `model_scene` (plus the scale /
## rotation / offset corrections) on the fighter's .tres. No node is
## added, moved, renamed or removed, so nothing in this file, in
## BattleArena or in the HUD has to be re-pointed. `_apply_profile_art()`
## below is the entire hand-off, and it is already written -- lot 3 puts
## a value in a .tres, not a line in a script.

## Emitted whenever hp moves, including on reset. Carries the maximum too
## so the HUD never has to reach back into the profile for it.
signal hp_changed(current: int, maximum: int)
## Emitted on every FSM transition. `action` is the action the state
## belongs to (NONE while IDLE/STAGGER/KO).
signal state_changed(state: BattleTypes.State, action: BattleTypes.Action)
## Emitted the tick an action is accepted out of IDLE.
signal action_started(action: BattleTypes.Action)
## Emitted once per resolved strike against this fighter, whatever the
## outcome -- DODGED is reported too, because "my dodge worked" is
## exactly the feedback this game needs to be readable.
##
## `attempted` is the defensive action this fighter was COMMITTED TO when
## the blow landed, or NONE if it was not defending at all. It carries
## the one distinction lot 5 exists to make visible: a clean HIT with
## `attempted == DODGE` is a dodge that was MISTIMED, and it must not
## look to the player like a dodge that was never pressed.
##
## It is a signal argument and not something a listener reads back off
## `current_action`, even though that would work today: this signal is
## emitted BEFORE _enter_stagger() clears the action, so the read-back
## is correct only for as long as nobody reorders those two lines -- and
## the failure would be silent, in the exact channel this lot adds to
## stop failures being silent.
signal hit_taken(damage: int, outcome: BattleTypes.Outcome, attempted: BattleTypes.Action)
## Emitted the tick this fighter's ATTACK enters its ACTIVE window.
## BattleArena listens and resolves it against the opponent: the strike
## rule lives in ONE place rather than in each fighter's view of the
## other.
signal strike_activated()
signal knocked_out()

## How long an early tap is remembered. Without it, a tap during the last
## frames of a recovery is silently eaten and the game feels broken
## rather than strict. Deliberately a GAME constant and not a per-profile
## export: it is a property of the controls, identical for every
## combatant, and letting two fighters disagree about it would mean two
## different games.
const INPUT_BUFFER_S := 0.16

## The .tres that makes this fighter that fighter. Set in the scene (or
## by BattleArena before the fight starts). Never read before _ready()
## has run -- see `_apply_profile_art()`.
@export var profile: FighterProfile = null

var hp: int = 0
var state: BattleTypes.State = BattleTypes.State.IDLE
var current_action: BattleTypes.Action = BattleTypes.Action.NONE

## Seconds left in the current phase. Counted DOWN in fixed steps rather
## than compared against an absolute clock, so no accumulated wall-time
## value can drift between the two fighters.
var _phase_left: float = 0.0
## The FULL length the current phase was given, kept alongside the one
## that decays. Exists so a listener reacting to `state_changed` can ask
## how long the phase it just heard about lasts -- FighterView animates a
## windup over exactly its own duration -- WITHOUT re-deriving it from
## the profile and growing a second copy of the action -> timing map.
##
## Read-only to the outside, through phase_duration(). Nothing in this
## file branches on it: it is a report of a decision already made, never
## an input to one.
var _phase_total: float = 0.0
var _buffered_action: BattleTypes.Action = BattleTypes.Action.NONE
var _buffer_left: float = 0.0
## True once this fighter's current ATTACK has already resolved, so a
## multi-tick ACTIVE window cannot land twice.
var _strike_spent: bool = false

@onready var _slot: ModelSlot = $Body

func _ready() -> void:
	_apply_profile_art()
	reset()

## Puts this fighter back to full hp and IDLE. Called at _ready() and on
## every rematch, so a rematch is genuinely a fresh fight rather than a
## scene reload -- and so BattleArena can re-seed its rng and replay the
## exact same match if it ever needs to.
func reset() -> void:
	hp = _max_hp()
	state = BattleTypes.State.IDLE
	current_action = BattleTypes.Action.NONE
	_phase_left = 0.0
	_phase_total = 0.0
	_buffered_action = BattleTypes.Action.NONE
	_buffer_left = 0.0
	_strike_spent = false
	hp_changed.emit(hp, _max_hp())
	state_changed.emit(state, current_action)

## The one entry point for "do something", shared by the human's taps and
## by FighterBrain. Accepted only out of IDLE; anything else is buffered
## for INPUT_BUFFER_S and replayed the moment IDLE comes back.
func request_action(action: BattleTypes.Action) -> void:
	if action == BattleTypes.Action.NONE:
		return
	if state == BattleTypes.State.KO:
		return
	if state == BattleTypes.State.IDLE:
		_begin_action(action)
		return
	_buffered_action = action
	_buffer_left = INPUT_BUFFER_S

## Advances the FSM by exactly `dt`. Called by BattleArena's fixed-step
## loop, never by the engine.
func advance(dt: float) -> void:
	if state == BattleTypes.State.KO:
		return

	if _buffer_left > 0.0:
		_buffer_left -= dt
		if _buffer_left <= 0.0:
			_buffered_action = BattleTypes.Action.NONE
			_buffer_left = 0.0

	if state == BattleTypes.State.IDLE:
		_consume_buffer()
		return

	_phase_left -= dt
	if _phase_left > 0.0:
		return

	# Carry the overshoot into the next phase instead of dropping it:
	# truncating here would make every phase silently up to one tick
	# longer, and the error would compound differently for each fighter
	# depending on how their timings divide by the tick.
	var overshoot := -_phase_left
	_advance_phase()
	if _phase_left > 0.0 and overshoot > 0.0:
		_phase_left = max(_phase_left - overshoot, 0.0)

## Resolves an incoming strike against this fighter's CURRENT state, and
## returns what happened so the arena can report it. The defensive rules
## live here rather than in the attacker because they are a property of
## the defender's own state machine.
func receive_strike(damage: int) -> BattleTypes.Outcome:
	if state == BattleTypes.State.KO:
		return BattleTypes.Outcome.MISSED

	# Captured BEFORE anything below can clear it, so a mistimed defence
	# is still nameable at the moment it fails. NONE unless this fighter
	# had actually committed to dodging: an attack caught mid-swing was
	# not a failed defence, it was a trade lost, and telling the player
	# otherwise would teach the wrong lesson.
	var attempted := last_defence()

	var defending := state == BattleTypes.State.ACTIVE
	if defending and current_action == BattleTypes.Action.DODGE:
		hit_taken.emit(0, BattleTypes.Outcome.DODGED, attempted)
		return BattleTypes.Outcome.DODGED

	# Everything else is a clean hit, INCLUDING being mid-attack: active
	# attack frames do not defend. That is what stops both fighters from
	# just mashing attack -- whoever commits second eats the trade.
	_apply_damage(damage)
	if state == BattleTypes.State.KO:
		return BattleTypes.Outcome.HIT
	hit_taken.emit(damage, BattleTypes.Outcome.HIT, attempted)
	_enter_stagger()
	return BattleTypes.Outcome.HIT

## The defensive action this fighter is committed to RIGHT NOW -- in any
## phase of it, windup and recovery included -- or NONE.
##
## Deliberately not "is the defence active": the whole point of lot 5's
## feedback is that a dodge which is still starting up, or has already
## dropped into recovery, is a dodge the player DID press and mistimed.
## Those are the two cases that used to be indistinguishable from having
## pressed nothing -- and with the charge bar they are the two the player
## can now actually correct, because the bar says which way they were
## wrong.
func last_defence() -> BattleTypes.Action:
	if current_action == BattleTypes.Action.DODGE:
		return current_action
	return BattleTypes.Action.NONE

func is_alive() -> bool:
	return state != BattleTypes.State.KO

## True while this fighter is free to commit to something right now.
##
## One of the two things FighterBrain may "see" about its opponent, and
## it is what stops the AI from throwing an attack into a window where
## the opponent can simply hit first.
func is_free() -> bool:
	return state == BattleTypes.State.IDLE

## True while this fighter is telegraphing or landing an attack -- the
## other of the two things FighterBrain is allowed to "see" about its
## opponent. Kept as a named question rather than letting the brain read
## `state` and `current_action` directly, so what the AI perceives is one
## explicit, reviewable surface instead of the whole FSM.
##
## It is a coarse "an attack is coming"; the charge bar is the fine
## answer to "and it lands WHEN". The brain only needs the coarse one,
## because it pays a reaction delay and then commits -- exactly what a
## player does. Nothing in here lets it read a phase clock a player
## cannot see.
func is_threatening() -> bool:
	return current_action == BattleTypes.Action.ATTACK \
		and (state == BattleTypes.State.WINDUP or state == BattleTypes.State.ACTIVE)

## Full length, in seconds, of the phase this fighter is currently in --
## 0.0 in IDLE and KO, which hold no phase. Valid to read from a
## `state_changed` handler, which is the only place it is used today.
##
## Presentation-only by design: it lets the view layer run an animation
## for exactly as long as the phase it depicts, instead of guessing a
## duration that would then drift from the FSM every time a .tres moves.
func phase_duration() -> float:
	return _phase_total

## =====================================================================
## THE CHARGE BAR CONTRACT -- LOT 7's WHOLE POINT, IN TWO FUNCTIONS
##
## The device report that lots 3-6 could not shift was that defending
## does not work. The cause finally retained is that the telegraph said
## an attack was COMING and never said WHEN it lands, so a defender could
## only guess -- and a guess that fails looks exactly like a button that
## does nothing.
##
## These two read-only functions are the fix. They expose the ONE number
## the player was missing: how far through its wind-up an attack is, as a
## fraction. FighterView draws it as a bar above the attacker's head, and
## the bar reaching full IS the instant of impact -- not approximately,
## by construction:
##
##   * `_phase_total` is the wind-up's own length, set by _set_phase()
##     from the profile;
##   * the strike resolves on the FIRST tick of ACTIVE, i.e. the tick
##     immediately after `_phase_left` runs out;
##   * so progress reaches 1.0 exactly when the phase ends, which is
##     exactly when the blow is thrown.
##
## PRESENTATION ONLY. Nothing in this file branches on either of them, no
## rule reads them, and the AI cannot: FighterBrain sees is_threatening()
## and is_free() and nothing else. A brain that could read this clock
## would be an opponent playing a different game from the player, which
## is the divergence this project has already paid for once.
##
## BattleReadabilityProbe PHASE G gates both halves -- the number here,
## tick by tick, and the bar FighterView actually draws from it.
func is_charging() -> bool:
	return state == BattleTypes.State.WINDUP and current_action == BattleTypes.Action.ATTACK

## 0.0 at the first tick of the wind-up, 1.0 the moment it ends. Returns
## 0.0 when not charging, so a caller that forgets is_charging() gets an
## empty bar rather than a stale one.
func charge_progress() -> float:
	if not is_charging() or _phase_total <= 0.0:
		return 0.0
	return clampf(1.0 - _phase_left / _phase_total, 0.0, 1.0)

func _begin_action(action: BattleTypes.Action) -> void:
	current_action = action
	_strike_spent = false
	_buffered_action = BattleTypes.Action.NONE
	_buffer_left = 0.0
	action_started.emit(action)
	_set_phase(BattleTypes.State.WINDUP)

func _consume_buffer() -> void:
	if _buffered_action == BattleTypes.Action.NONE:
		return
	var action := _buffered_action
	_buffered_action = BattleTypes.Action.NONE
	_buffer_left = 0.0
	_begin_action(action)

func _advance_phase() -> void:
	match state:
		BattleTypes.State.WINDUP:
			_set_phase(BattleTypes.State.ACTIVE)
			# The strike leaves HERE, on the first tick of ACTIVE, which
			# is the tick the wind-up ran out on. That is what makes the
			# charge bar exact rather than merely indicative: full bar
			# and thrown blow are the same event, not two events that
			# happen to be scheduled close together.
			if current_action == BattleTypes.Action.ATTACK and not _strike_spent:
				_strike_spent = true
				strike_activated.emit()
		BattleTypes.State.ACTIVE:
			_set_phase(BattleTypes.State.RECOVERY)
		BattleTypes.State.RECOVERY, BattleTypes.State.STAGGER:
			current_action = BattleTypes.Action.NONE
			state = BattleTypes.State.IDLE
			_phase_left = 0.0
			_phase_total = 0.0
			state_changed.emit(state, current_action)
			_consume_buffer()
		_:
			pass

func _set_phase(next_state: BattleTypes.State) -> void:
	state = next_state
	var timing := _timing()
	match next_state:
		BattleTypes.State.WINDUP: _phase_left = timing.x
		BattleTypes.State.ACTIVE: _phase_left = timing.y
		BattleTypes.State.RECOVERY: _phase_left = timing.z
		_: _phase_left = 0.0
	_phase_total = _phase_left
	state_changed.emit(state, current_action)

func _enter_stagger() -> void:
	current_action = BattleTypes.Action.NONE
	_strike_spent = false
	_buffered_action = BattleTypes.Action.NONE
	_buffer_left = 0.0
	state = BattleTypes.State.STAGGER
	_phase_left = _stagger_duration()
	_phase_total = _phase_left
	state_changed.emit(state, current_action)

func _apply_damage(amount: int) -> void:
	hp = max(hp - amount, 0)
	hp_changed.emit(hp, _max_hp())
	if hp > 0:
		return
	current_action = BattleTypes.Action.NONE
	state = BattleTypes.State.KO
	_phase_left = 0.0
	_phase_total = 0.0
	state_changed.emit(state, current_action)
	knocked_out.emit()

## The lot-3 exchange point, in full. Placeholder tint and .glb install
## are the SAME code path deliberately: the material is applied through
## ModelSlot.apply_material(), which reaches the installed model's
## surfaces once one exists, so a future .glb inherits the profile's
## colour handling rather than needing a second branch nobody exercises.
func _apply_profile_art() -> void:
	if profile == null or _slot == null:
		return
	if profile.model_scene != null:
		_slot.model_scale = profile.model_scale
		_slot.model_rotation_degrees = profile.model_rotation_degrees
		_slot.model_offset = profile.model_offset
		# Assigned LAST: ModelSlot's setter re-installs immediately when
		# the node is already in the tree (children _ready() before their
		# parent), so the three corrections above must already be in
		# place or the model would be installed untransformed for one
		# frame -- then silently stay that way if a setter were ever
		# changed to not re-apply them.
		_slot.model_scene = profile.model_scene
		return
	# Placeholder path. Duplicated per instance so two fighters sharing
	# the scene's sub-resource cannot tint each other -- the same reason
	# Obstacle.gd duplicates its own material.
	var base: Material = _slot.slot_material()
	var material: StandardMaterial3D = null
	if base is StandardMaterial3D:
		material = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = profile.placeholder_color
	_slot.apply_material(material)

func _max_hp() -> int:
	return profile.max_hp if profile else 100

func _stagger_duration() -> float:
	return profile.stagger_duration_s if profile else 0.5

func _timing() -> Vector3:
	return profile.timing_for(current_action) if profile else Vector3.ZERO
