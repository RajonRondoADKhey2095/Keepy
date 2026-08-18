extends Control
## Boot screen. "Jouer" hands off to the gameplay scene, which is
## independently loadable (Game.tscn does its own reset via
## GameState.start_run() in its _ready()).

@onready var play_button: Button = $CenterContainer/TitlePanel/VBoxContainer/PlayButton

func _ready() -> void:
	# Canvas fills the screen here: this is a UI screen, so the 9:16 letterbox
	# Chased is tuned at would only be black bars. Game.tscn asks for KEEP back
	# in its own _ready() -- see SafeArea.gd's canvas-aspect block.
	SafeArea.fill_screen()
	play_button.pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
