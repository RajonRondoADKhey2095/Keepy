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
## Keepy Quizz is active as of the QuizzHomeScreen lot: it leads to
## scenes/QuizzHomeScreen.tscn, the first screen exercising the Quizz
## authoring autoload for real (create a quiz, list your own). See
## docs/QUIZZ_SPEC.md for the fuller screen set that lands later.

const CHASED_SCENE := "res://scenes/TitleScreen.tscn"
const QUIZZ_SCENE := "res://scenes/QuizzHomeScreen.tscn"

@onready var chased_button: Button = $CenterContainer/HubPanel/VBoxContainer/ChasedCard/ChasedButton
@onready var quizz_button: Button = $CenterContainer/HubPanel/VBoxContainer/QuizzCard/QuizzButton

func _ready() -> void:
	chased_button.pressed.connect(_on_chased_pressed)
	quizz_button.pressed.connect(_on_quizz_pressed)

func _on_chased_pressed() -> void:
	get_tree().change_scene_to_file(CHASED_SCENE)

func _on_quizz_pressed() -> void:
	get_tree().change_scene_to_file(QUIZZ_SCENE)
