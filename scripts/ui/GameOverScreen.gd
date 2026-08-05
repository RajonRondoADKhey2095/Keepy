extends CanvasLayer
class_name GameOverScreen
## Game over overlay: final score + "Rejouer" button. Shows itself when
## GameState transitions to GAME_OVER and hides on any other state.
##
## Also updates the LOCAL best score (Leaderboard.record_local_best,
## user:// via FileAccess -- offline, no network) every time a run ends,
## and shows "Nouveau record !" when it was beaten. This is intentionally
## independent of the global leaderboard: it must keep working even with
## no connection or a dead Firestore project.

@onready var root: Control = $Root
@onready var score_label: Label = $Root/CenterContainer/VBoxContainer/ScoreLabel
@onready var record_label: Label = $Root/CenterContainer/VBoxContainer/RecordLabel
@onready var retry_button: Button = $Root/CenterContainer/VBoxContainer/RetryButton

func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	GameState.state_changed.connect(_on_state_changed)
	root.visible = false

func _on_state_changed(new_state: int) -> void:
	if new_state == GameState.State.GAME_OVER:
		_show_game_over()
	else:
		root.visible = false

func _show_game_over() -> void:
	var final_score := GameState.score
	score_label.text = "Score : %d" % final_score
	record_label.visible = Leaderboard.record_local_best(final_score)
	root.visible = true

func _on_retry_pressed() -> void:
	GameState.start_run()
