extends CanvasLayer
class_name HUD
## In-run score + collectible counters display. Purely reactive to
## GameState signals -- holds no gameplay logic of its own.

@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var nut_label: Label = $MarginContainer/VBoxContainer/CountsRow/NutLabel
@onready var gland_label: Label = $MarginContainer/VBoxContainer/CountsRow/GlandLabel

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.counts_changed.connect(_on_counts_changed)
	score_label.text = str(GameState.score)
	_on_counts_changed(GameState.nut_count, GameState.gland_count)

func _on_score_changed(new_score: int) -> void:
	score_label.text = str(new_score)

func _on_counts_changed(nut_count: int, gland_count: int) -> void:
	nut_label.text = "Noisettes : %d" % nut_count
	gland_label.text = "Glands : %d" % gland_count
