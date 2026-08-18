extends Control
## Umbrella screen for "Keepy's Memorial Quest" (18 aout 2026): the landing
## point right after Google Sign-In, from which each sub-game is entered.
##
## It sits BETWEEN LoginScreen and TitleScreen rather than adding a second
## button to TitleScreen, because TitleScreen is Keepy Chased's OWN boot
## screen -- its logo, its subtitle, its "Jouer". A second sub-game listed
## there would read as a mode of Chased rather than a sibling of it, and a
## third one later would have nowhere to go. TitleScreen.tscn is therefore
## untouched by this lot and still loads standalone, exactly as it did when
## the sign-in gate was put in front of it.
##
## Keepy Quizz is present but inert. The button exists so the umbrella reads
## as two sub-games from the very first frame, and so the place to wire the
## real gameplay is a named node rather than a decision to re-take. See
## docs/QUIZZ_SPEC.md for the screens it will lead to.

const CHASED_SCENE := "res://scenes/TitleScreen.tscn"

@onready var chased_button: Button = $CenterContainer/HubPanel/VBoxContainer/ChasedCard/ChasedButton
@onready var quizz_button: Button = $CenterContainer/HubPanel/VBoxContainer/QuizzCard/QuizzButton

func _ready() -> void:
	chased_button.pressed.connect(_on_chased_pressed)
	# The scene owns `disabled = true`; this asserts it rather than assuming
	# it, because "no navigation is possible on Quizz" is a contract of this
	# lot and not a styling detail. Nothing is connected to
	# quizz_button.pressed, so a button enabled by accident would be a dead
	# control -- silent, and indistinguishable from a coming-soon button that
	# is merely greyed. Same discipline as HUD.gd asserting its pip count:
	# it errors, it does not guess.
	if not quizz_button.disabled:
		push_error("Hub: QuizzButton must stay disabled until Keepy Quizz ships")

func _on_chased_pressed() -> void:
	get_tree().change_scene_to_file(CHASED_SCENE)
