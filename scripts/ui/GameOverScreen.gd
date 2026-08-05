extends CanvasLayer
class_name GameOverScreen
## Game over overlay: final score + "Rejouer" button. Shows itself when
## GameState transitions to GAME_OVER and hides on any other state.

@onready var root: Control = $Root
@onready var score_label: Label = $Root/CenterContainer/VBoxContainer/ScoreLabel
@onready var retry_button: Button = $Root/CenterContainer/VBoxContainer/RetryButton

func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	GameState.state_changed.connect(_on_state_changed)
	root.visible = false

func _on_state_changed(new_state: int) -> void:
	if new_state == GameState.State.GAME_OVER:
		score_label.text = "Score : %d" % GameState.score
		root.visible = true
	else:
		root.visible = false

func _on_retry_pressed() -> void:
	GameState.start_run()
