extends CanvasLayer
class_name HUD
## In-run score display. Purely reactive to GameState.score_changed --
## holds no gameplay logic of its own.

@onready var score_label: Label = $MarginContainer/ScoreLabel

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	score_label.text = str(GameState.score)

func _on_score_changed(new_score: int) -> void:
	score_label.text = str(new_score)
