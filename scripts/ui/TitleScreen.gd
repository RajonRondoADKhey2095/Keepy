extends Control
## Boot screen for Keepy Chased. "Jouer" hands off to the gameplay scene,
## which is independently loadable (Game.tscn does its own reset via
## GameState.start_run() in its _ready()).
##
## THE WAY BACK OUT, AND WHY IT IS NEW HERE (23 aout 2026). This screen
## never had one. Quizz shipped with a BackButton in its header and Battle
## with a Quit button on its HUD, so when the plateau hub replaced
## Hub.tscn only those two needed their target repointed at
## HubWorld.tscn -- Chased had no target to repoint, which is why it was
## the only sub-game a player could not leave. The fix is a return PATH,
## not a corrected path: this button, plus HubButton on GameOverScreen
## (entering a run is one tap from here, so a run that ends must also
## offer the hub, not only "Rejouer").
const HUB_SCENE := "res://scenes/HubWorld.tscn"

@onready var play_button: Button = $CenterContainer/TitlePanel/VBoxContainer/PlayButton
@onready var back_button: Button = $BackButton

func _ready() -> void:
	# Canvas fills the screen here: this is a UI screen, so the 9:16 letterbox
	# Chased is tuned at would only be black bars. Game.tscn asks for KEEP back
	# in its own _ready() -- see SafeArea.gd's canvas-aspect block.
	SafeArea.fill_screen()
	play_button.pressed.connect(_on_play_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)
