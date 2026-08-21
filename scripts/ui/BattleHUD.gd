extends CanvasLayer
class_name BattleHUD
## Keepy Battle's HUD: two hp bars, two state readouts, the three tap
## zones, and the end-of-round panel.
##
## =====================================================================
## ZERO BUSINESS LOGIC, AND WHAT THAT ACTUALLY MEANS HERE
##
## This file computes NOTHING about the fight. It does not know what a
## strike costs, whether guard beats dodge, how long a windup lasts or
## who is winning. It subscribes to Fighter's signals and renders what it
## is handed; the one number it derives is a progress bar's ratio, which
## is presentation.
##
## Input goes the other way and is just as thin: a tap emits
## `action_requested`, and BattleArena decides what to do with it. This
## node never calls Fighter.request_action() itself -- if it did, the
## HUD would become a second place where "can the player act right now"
## is answered, and the two answers would eventually disagree.
##
## =====================================================================
## TAP ONLY, THREE FIXED ZONES, NO GESTURES
##
## Three wide buttons pinned to the bottom, and nothing else. No swipe,
## for two independent reasons: Keepy Chased already owns swipe as its
## lane-change gesture, so the same motion would mean two things across
## one app; and a horizontal swipe on iOS Safari competes with the
## browser's own back-navigation and scroll gestures, which is not
## something a page can reliably win. A tap has no ambiguity to resolve.
##
## The buttons stay ENABLED while a fighter is committed rather than
## greying out mid-action. Fighter buffers an early tap for
## INPUT_BUFFER_S and replays it on IDLE, so an "early" press is a real,
## working input -- disabling the button would throw away a press the
## game was about to honour, and it would make the control panel flicker
## several times a second.

signal action_requested(action: BattleTypes.Action)
signal rematch_requested()
signal quit_requested()

## How long a strike verdict stays up.
##
## =====================================================================
## WHY 0.45 AND NOT THE 0.70 THIS SHIPPED WITH
##
## 0.70 was longer than the action that produced the verdict, and that
## is what a device capture caught: "Sparring : TOUCHE" still on screen
## while the same fighter's state line already read "Pret". Neither
## readout was wrong -- the verdict is a LAGGING report of something that
## happened, the state line is an INSTANTANEOUS report of now -- but
## shown together they contradict each other, and the player has no way
## to know which one to believe.
##
## Measured headless on the shipped profiles rather than estimated: after
## its strike resolves, an attacker stays committed for active +
## recovery, i.e. 480 ms (Keepy) and 540 ms (Sparring). At 700 ms the
## verdict outlived the shorter of those by 160 ms -- exactly the window
## the capture was taken in. 0.45 sits under BOTH, so a verdict can no
## longer survive the action it describes, whichever fighter threw it.
##
## This is a HUD presentation constant, not a combat timing: no windup,
## active, recovery or stagger value in any .tres is touched by this lot.
## Those stay for the tuning pass, on device, with a telegraph finally
## visible to tune against.
##
## It is also no longer the only carrier: FighterView flashes the fighter
## that was actually hit, at the moment of impact, in the middle of the
## screen. The line below is now confirmation of something already seen.
const FLASH_S := 0.45

@onready var player_name_label: Label = $Root/TopBar/PlayerBlock/NameRow/NameLabel
@onready var player_hp_bar: ProgressBar = $Root/TopBar/PlayerBlock/HpBar
@onready var player_hp_label: Label = $Root/TopBar/PlayerBlock/NameRow/HpLabel
@onready var player_state_label: Label = $Root/TopBar/PlayerBlock/StateLabel
@onready var opponent_name_label: Label = $Root/TopBar/OpponentBlock/NameRow/NameLabel
@onready var opponent_hp_bar: ProgressBar = $Root/TopBar/OpponentBlock/HpBar
@onready var opponent_hp_label: Label = $Root/TopBar/OpponentBlock/NameRow/HpLabel
@onready var opponent_state_label: Label = $Root/TopBar/OpponentBlock/StateLabel
@onready var flash_label: Label = $Root/FlashLabel
@onready var attack_button: Button = $Root/Controls/AttackButton
@onready var guard_button: Button = $Root/Controls/GuardButton
@onready var dodge_button: Button = $Root/Controls/DodgeButton
@onready var result_panel: PanelContainer = $Root/ResultPanel
@onready var result_label: Label = $Root/ResultPanel/VBox/ResultLabel
@onready var rematch_button: Button = $Root/ResultPanel/VBox/RematchButton
@onready var quit_button: Button = $Root/ResultPanel/VBox/QuitButton

var _player: Fighter = null
var _opponent: Fighter = null
var _flash_left: float = 0.0

func _ready() -> void:
	attack_button.pressed.connect(_on_attack)
	guard_button.pressed.connect(_on_guard)
	dodge_button.pressed.connect(_on_dodge)
	rematch_button.pressed.connect(_on_rematch)
	quit_button.pressed.connect(_on_quit)
	flash_label.text = ""
	result_panel.visible = false

func _exit_tree() -> void:
	_unbind()

## Subscribes to both fighters. Called by BattleArena once, after the
## scene is built -- the HUD never looks the fighters up itself, so it
## cannot acquire a hard-coded path into the 3D side of the scene.
func bind(player: Fighter, opponent: Fighter) -> void:
	_unbind()
	_player = player
	_opponent = opponent
	player_name_label.text = _display_name(player)
	opponent_name_label.text = _display_name(opponent)
	_player.hp_changed.connect(_on_player_hp)
	_player.state_changed.connect(_on_player_state)
	_opponent.hp_changed.connect(_on_opponent_hp)
	_opponent.state_changed.connect(_on_opponent_state)

func show_fight() -> void:
	result_panel.visible = false
	flash_label.text = ""
	_flash_left = 0.0
	_set_controls_visible(true)

## End of round.
##
## The two state lines are REPLACED here rather than left to whatever the
## FSM last emitted, and that is a fix for a second thing the device
## captures caught: at the KO screen the winner's line read
## "Attaque - Actif".
##
## It was not stale and it was not a HUD bug. A strike resolves inside
## the attacker's first ACTIVE tick, so the loser hits 0 hp on that very
## tick and BattleArena stops the clock immediately -- the winner's FSM
## is genuinely frozen in ACTIVE and will never leave it. The label was
## telling the truth about a simulation that had stopped.
##
## Which is exactly why it cannot stay: a live-phase readout implies a
## fight still running. Once the round is over the only honest thing
## those two lines can say is how it ended, so they say that. They go
## back to reporting phases on the next round, when Fighter.reset()
## emits IDLE ahead of show_fight().
func show_result(player_won: bool) -> void:
	result_label.text = "Victoire !" if player_won else "Defaite"
	result_panel.visible = true
	flash_label.text = ""
	_flash_left = 0.0
	player_state_label.text = "Vainqueur" if player_won else "K.O."
	opponent_state_label.text = "K.O." if player_won else "Vainqueur"
	_set_controls_visible(false)

## Verdict of one resolved strike. `by_player` says who threw it, so the
## line reads as the player's own action rather than as a fact about
## nobody in particular.
##
## `attempted` is what the DEFENDER had committed to, so the line can say
## "GARDE BRISEE" instead of a bare "TOUCHE" -- see
## BattleTypes.strike_label(). The subject stays the attacker either way:
## the player reads one line per exchange, and switching whose name it
## carries halfway through a fight would be worse than a coarser verb.
func report_strike(by_player: bool, outcome: BattleTypes.Outcome, attempted: BattleTypes.Action) -> void:
	if outcome == BattleTypes.Outcome.MISSED:
		return
	var who := "Toi" if by_player else _display_name(_opponent)
	flash_label.text = "%s : %s" % [who, BattleTypes.strike_label(outcome, attempted)]
	_flash_left = FLASH_S

func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		_flash_left = 0.0
		flash_label.text = ""

func _on_attack() -> void:
	action_requested.emit(BattleTypes.Action.ATTACK)

func _on_guard() -> void:
	action_requested.emit(BattleTypes.Action.GUARD)

func _on_dodge() -> void:
	action_requested.emit(BattleTypes.Action.DODGE)

func _on_rematch() -> void:
	rematch_requested.emit()

func _on_quit() -> void:
	quit_requested.emit()

func _on_player_hp(current: int, maximum: int) -> void:
	_render_hp(player_hp_bar, player_hp_label, current, maximum)

func _on_opponent_hp(current: int, maximum: int) -> void:
	_render_hp(opponent_hp_bar, opponent_hp_label, current, maximum)

func _on_player_state(state: BattleTypes.State, action: BattleTypes.Action) -> void:
	player_state_label.text = _state_text(state, action)

func _on_opponent_state(state: BattleTypes.State, action: BattleTypes.Action) -> void:
	opponent_state_label.text = _state_text(state, action)

func _render_hp(bar: ProgressBar, label: Label, current: int, maximum: int) -> void:
	bar.max_value = float(max(maximum, 1))
	bar.value = float(current)
	label.text = "%d / %d" % [current, maximum]

## "Attaque - Prepare" while committed, the bare state otherwise. Both
## halves come from BattleTypes so the vocabulary the player reads cannot
## drift from the enum the FSM runs on.
func _state_text(state: BattleTypes.State, action: BattleTypes.Action) -> String:
	var state_text := BattleTypes.state_label(state)
	if action == BattleTypes.Action.NONE:
		return state_text
	return "%s - %s" % [BattleTypes.action_label(action), state_text]

func _set_controls_visible(shown: bool) -> void:
	attack_button.visible = shown
	guard_button.visible = shown
	dodge_button.visible = shown

func _display_name(fighter: Fighter) -> String:
	if fighter == null or fighter.profile == null:
		return "?"
	return fighter.profile.display_name

func _unbind() -> void:
	if is_instance_valid(_player):
		_drop(_player.hp_changed, _on_player_hp)
		_drop(_player.state_changed, _on_player_state)
	if is_instance_valid(_opponent):
		_drop(_opponent.hp_changed, _on_opponent_hp)
		_drop(_opponent.state_changed, _on_opponent_state)
	_player = null
	_opponent = null

func _drop(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)
