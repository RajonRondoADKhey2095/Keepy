extends StaticBody3D
class_name TrackSegment
## One 20-unit tile of running track.
##
## Owns a fixed pool of one Obstacle and three Noisette slots (one per
## lane), created once in _ready() and only ever shown/hidden and
## repositioned by populate() -- never freed and re-instantiated
## during gameplay, so recycling a segment allocates nothing.

const LANE_X: Array[float] = [-2.0, 0.0, 2.0]
const OBSTACLE_Y: float = 0.6
const NOISETTE_Y: float = 1.0

@export var obstacle_scene: PackedScene
@export var noisette_scene: PackedScene

var _obstacle: Obstacle
var _noisette_slots: Array[Noisette] = []

func _ready() -> void:
	_obstacle = obstacle_scene.instantiate()
	add_child(_obstacle)
	_deactivate_obstacle()

	for i in LANE_X.size():
		var noisette: Noisette = noisette_scene.instantiate()
		add_child(noisette)
		_deactivate_noisette(noisette)
		_noisette_slots.append(noisette)

## spawn_obstacle: whether this segment should have a hazard.
## noisette_lanes: lane indices (0..2) that should show a collectible.
## The obstacle's lane (if any) is removed from noisette_lanes so a
## noisette never overlaps a hazard.
func populate(spawn_obstacle: bool, noisette_lanes: Array[int]) -> void:
	var free_lanes := noisette_lanes.duplicate()

	if spawn_obstacle:
		var obstacle_lane := randi_range(0, LANE_X.size() - 1)
		_obstacle.position = Vector3(LANE_X[obstacle_lane], OBSTACLE_Y, 0.0)
		_obstacle.visible = true
		_obstacle.monitoring = true
		_obstacle.monitorable = true
		free_lanes.erase(obstacle_lane)
	else:
		_deactivate_obstacle()

	for lane in LANE_X.size():
		var slot := _noisette_slots[lane]
		if lane in free_lanes:
			slot.position = Vector3(LANE_X[lane], NOISETTE_Y, 0.0)
			slot.collected = false
			slot.visible = true
			slot.monitoring = true
			slot.monitorable = true
		else:
			_deactivate_noisette(slot)

func _deactivate_obstacle() -> void:
	_obstacle.visible = false
	_obstacle.monitoring = false
	_obstacle.monitorable = false

func _deactivate_noisette(slot: Noisette) -> void:
	slot.visible = false
	slot.monitoring = false
	slot.monitorable = false
