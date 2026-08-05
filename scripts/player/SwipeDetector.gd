extends Node
class_name SwipeDetector
## Detects horizontal swipes (lane change) and vertical swipes (jump)
## from touch input. Keyboard input is handled separately by Keepy.gd
## via the ui_left / ui_right / ui_jump input map actions.

signal swiped_left
signal swiped_right
signal swiped_up

const MIN_SWIPE_DISTANCE: float = 60.0
const MAX_SWIPE_TIME: float = 0.6

var _touch_start: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _touch_active: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_touch_start_time = Time.get_ticks_msec() / 1000.0
			_touch_active = true
		else:
			if _touch_active:
				_evaluate_swipe(event.position)
			_touch_active = false

func _evaluate_swipe(end_position: Vector2) -> void:
	var elapsed := Time.get_ticks_msec() / 1000.0 - _touch_start_time
	if elapsed > MAX_SWIPE_TIME:
		return

	var delta := end_position - _touch_start
	if delta.length() < MIN_SWIPE_DISTANCE:
		return

	if absf(delta.x) > absf(delta.y):
		if delta.x < 0.0:
			swiped_left.emit()
		else:
			swiped_right.emit()
	else:
		if delta.y < 0.0:
			swiped_up.emit()
