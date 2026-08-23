extends Control
class_name HubConfirmDialog
## The "are you sure" step between landing on a portal and being taken to a
## sub-game. Shows a game's name and two buttons, and answers with a signal.
##
## =====================================================================
## IT KNOWS NOTHING ABOUT ROUTING, ON PURPOSE
##
## HubRouter is still the ONE place that maps a game_id to a scene path and
## the one place that changes scene (see its header). This node carries a
## game_id it was handed, hands the same value straight back on `confirmed`,
## and never reads it. Nothing here would have to change if a route moved,
## and adding a fourth game touches HubRouter.ROUTES and the layout .tres --
## not this file.
##
## The display name comes in as a plain String from the caller, for the same
## reason: resources/hub/hub_layout.tres already carries a `label` per
## portal, and that is the single place a game is named. A lookup table
## here would be a second one, free to drift from the text painted on the
## plateau itself.
##
## =====================================================================
## WHY A LANDING IS NOT AN ENTRY ANY MORE
##
## A hop is aimed with a tap on the ground, and a tap is not precise: a
## player crossing the plateau could land inside a portal they only meant
## to hop past and be thrown into a sub-game with no way to say no. The
## portal's own header already refuses `body_entered` for a version of this
## problem (a hop passing THROUGH a portal in mid-air); this is the other
## half -- a landing is now a proposal, and only "Jouer" is an entry.
##
## Cancelling leaves Keepy exactly where they are. Standing inside a portal
## is a legal position on the plateau, so there is no push-back and no
## re-hop: the dialog re-opens only on the NEXT landing, which means a
## player who cancels can simply tap elsewhere and leave.
##
## =====================================================================
## MOUSE FILTER -- READ BEFORE TOUCHING THE SCENE
##
## This repo has already lost a plateau's worth of taps to a Control's
## default mouse_filter twice (see HubTapInput.gd's header). Here the
## danger runs the other way: HubTapInput listens in _unhandled_input, so
## anything this dialog does NOT swallow reaches the plateau and hops Keepy
## around underneath an open dialog.
##
## Measured on Godot 4.3, not assumed: Control and ColorRect both default to
## MOUSE_FILTER_STOP, so the authored scene is already correct. That default
## is deliberately NOT relied on -- HubConfirmDialog.tscn's root and its
## Scrim both spell `mouse_filter = 0` out, and `_ready()` re-asserts it on
## the root below, so a future edit cannot quietly turn this into a
## click-through overlay. Belt and braces on top of that: HubWorld also
## refuses ground taps while `is_open()` (the same guard its fallback menu
## already uses), so the plateau stays still even if picking is bypassed
## entirely.
##
## A tap on the scrim does nothing at all -- deliberately not a cancel. The
## dialog stands between a player and leaving the screen they are on; a
## stray finger next to the panel must not be able to answer for them, in
## either direction.

## Emitted when the player accepts. Carries back the exact game_id passed to
## open() -- HubWorld hands it to HubRouter, which is what routes.
signal confirmed(game_id: StringName)

## Emitted when the player declines. No payload: nothing about WHICH game
## was declined changes what the hub does next (nothing).
signal cancelled()

@onready var _title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var _play_button: Button = $Panel/VBoxContainer/PlayButton
@onready var _cancel_button: Button = $Panel/VBoxContainer/CancelButton

var _game_id: StringName = &""

func _ready() -> void:
	# See the MOUSE FILTER block above: authored in the scene, re-asserted
	# here so the two would have to be broken together.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_play_button.pressed.connect(_on_play_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)

## True while the dialog is up. HubWorld reads this to ignore plateau taps.
func is_open() -> bool:
	return visible

## Puts the dialog up for `game_id`, titled with `label`.
##
## A second call while already open is ignored rather than retargeted: two
## portals cannot both be landed on, so an open dialog being re-opened means
## something upstream fired twice, and silently swapping which game the
## visible "Jouer" leads to is the worst possible answer to that.
func open(game_id: StringName, label: String) -> void:
	if visible:
		return
	_game_id = game_id
	if label.is_empty():
		# A portal with no `label` in the layout .tres is a data typo, not a
		# reason to show an untitled panel with two buttons on it.
		_title_label.text = "Jouer ?"
	else:
		_title_label.text = "Jouer a %s ?" % label
	visible = true
	_play_button.grab_focus()

## Takes the dialog down without emitting anything. For a caller that needs
## to dismiss it for a reason that is not the player's answer.
func close() -> void:
	visible = false

func _on_play_pressed() -> void:
	# Hidden BEFORE the signal, never after: the handler changes scene, and
	# an interposed frame with the dialog still up would flash it over the
	# outgoing screen.
	visible = false
	confirmed.emit(_game_id)

func _on_cancel_pressed() -> void:
	visible = false
	cancelled.emit()
