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
##
## Keepy Battle (20 aout 2026) is the third sub-game, wired here by
## exactly the same three steps Quizz uses -- a scene path constant, an
## @onready button, a connect in _ready(). Nothing about a third entry
## needed a new mechanism, which is the whole reason this screen exists
## rather than a second button bolted onto TitleScreen.

const CHASED_SCENE := "res://scenes/TitleScreen.tscn"
const QUIZZ_SCENE := "res://scenes/QuizzHomeScreen.tscn"
const BATTLE_SCENE := "res://scenes/Battle.tscn"

@onready var chased_button: Button = $CenterContainer/HubPanel/VBoxContainer/ChasedCard/ChasedButton
@onready var quizz_button: Button = $CenterContainer/HubPanel/VBoxContainer/QuizzCard/QuizzButton
@onready var battle_button: Button = $CenterContainer/HubPanel/VBoxContainer/BattleCard/BattleButton

func _ready() -> void:
	# Defensive reset, not a per-exit-path fix: this is the one screen every
	# way back out of Quizz passes through today, so resetting here covers
	# a future second "back" button for free -- see SafeArea.gd's header.
	SafeArea.set_default()
	# Canvas fills the screen here: this is a UI screen, so the 9:16 letterbox
	# Chased is tuned at would only be black bars. Game.tscn asks for KEEP back
	# in its own _ready() -- see SafeArea.gd's canvas-aspect block.
	SafeArea.fill_screen()
	chased_button.pressed.connect(_on_chased_pressed)
	quizz_button.pressed.connect(_on_quizz_pressed)
	battle_button.pressed.connect(_on_battle_pressed)

func _on_chased_pressed() -> void:
	get_tree().change_scene_to_file(CHASED_SCENE)

func _on_quizz_pressed() -> void:
	get_tree().change_scene_to_file(QUIZZ_SCENE)

func _on_battle_pressed() -> void:
	get_tree().change_scene_to_file(BATTLE_SCENE)
