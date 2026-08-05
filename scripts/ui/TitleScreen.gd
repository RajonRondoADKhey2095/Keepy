extends Control
## Boot screen. "Jouer" hands off to the gameplay scene, which is
## independently loadable (Game.tscn does its own reset via
## GameState.start_run() in its _ready()).

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")
