extends Node3D
## Root of the gameplay scene. Wires the camera to the player and
## reacts to GameState transitions (fresh start, retry) by resetting
## the world -- none of that orchestration lives on the visual nodes
## themselves.

@onready var keepy: Keepy = $World/Keepy
@onready var track_manager: Node3D = $World/TrackManager
@onready var camera: CameraFollow = $World/CameraFollow

func _ready() -> void:
	# DEFENSIVE, not a fix for a screen that forgot: the tuned 9:16 framing is
	# what OBSTACLE_REACTION_BUDGET_S is calibrated against, so this scene must
	# never inherit whatever aspect the previous screen happened to leave. A
	# probe booting Game.tscn directly has to get it too.
	SafeArea.keep_game_framing()
	camera.target = keepy
	GameState.state_changed.connect(_on_state_changed)
	GameState.start_run()
	_reset_world()

func _on_state_changed(new_state: int) -> void:
	if new_state == GameState.State.PLAYING:
		_reset_world()

func _reset_world() -> void:
	keepy.position = Vector3(0.0, 1.0, 0.0)
	keepy.velocity = Vector3.ZERO
	keepy.reset_lane()
	track_manager.reset()
