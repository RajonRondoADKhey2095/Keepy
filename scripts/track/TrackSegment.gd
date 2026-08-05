extends StaticBody3D
class_name TrackSegment
## One 20-unit tile of running track.
##
## Owns a fixed pool of one Obstacle, three Noisette slots (one per
## lane) and one Gland slot, created once in _ready() and only ever
## shown/hidden and repositioned by populate() -- never freed and
## re-instantiated during gameplay, so recycling a segment allocates
## nothing.

const LANE_X: Array[float] = [-2.0, 0.0, 2.0]
# Obstacle root always sits at ground level (y=0) now: each of its
# variants (see Obstacle.gd) carries its own vertical offset on its own
# mesh/shape children, so the segment never needs to know which variant
# is active to position it.
const OBSTACLE_Y: float = 0.0
const NOISETTE_Y: float = 1.0
# Height of the Gland collectible: the CENTER of Keepy's capsule at the
# apex of a jump (JUMP_PEAK_HEIGHT = how high the capsule's BOTTOM rises,
# CAPSULE_HALF_HEIGHT = half the capsule's own height) -- see the
# constants' definitions in Keepy.gd for the full derivation. This is
# ABOVE the capsule's grounded top (1.6m, i.e. CAPSULE_HALF_HEIGHT * 2),
# which is what actually makes it unreachable without jumping: Keepy's
# capsule already spans 0..1.6m even standing still, so anything at or
# below that height needs no jump at all.
const GLAND_Y: float = Keepy.JUMP_PEAK_HEIGHT + Keepy.CAPSULE_HALF_HEIGHT

@export var obstacle_scene: PackedScene
@export var noisette_scene: PackedScene
@export var gland_scene: PackedScene

var _obstacle: Obstacle
var _noisette_slots: Array[Noisette] = []
var _gland: Gland

func _ready() -> void:
	_obstacle = obstacle_scene.instantiate()
	add_child(_obstacle)
	_deactivate_obstacle()

	for i in LANE_X.size():
		var noisette: Noisette = noisette_scene.instantiate()
		add_child(noisette)
		_deactivate_noisette(noisette)
		_noisette_slots.append(noisette)

	_gland = gland_scene.instantiate()
	add_child(_gland)
	_deactivate_gland()

## spawn_obstacle: whether this segment should have a hazard.
## obstacle_type: which Obstacle.Type variant to show when spawn_obstacle
## is true (ignored otherwise).
## noisette_lane: lane index (0..2) that should show a ground collectible,
## or -1 for none. At most ONE noisette per segment (i.e. per Z row) --
## Keepy can only occupy one lane at a time, so two noisettes at the same
## Z on different lanes would make one of them unreachable by
## construction. If noisette_lane collides with the obstacle's lane, the
## obstacle wins and no noisette is shown this segment.
## gland_lane: lane index (0..2) that should show the airborne bonus, or
## -1 for none. A Gland CAN share a lane with a ground noisette (they sit
## at different heights, see NOISETTE_Y / GLAND_Y) and CAN share a lane
## with a JUMP obstacle (the same jump clears the log and grabs the
## bonus). It can NEVER share a lane with an obstacle that blocks jumping
## (see Obstacle.blocks_jump) -- jumping into that lane to reach the
## Gland would run Keepy straight into the obstacle.
func populate(spawn_obstacle: bool, obstacle_type: Obstacle.Type, noisette_lane: int, gland_lane: int) -> void:
	var obstacle_lane := -1
	var obstacle_blocks_jump := false

	if spawn_obstacle:
		obstacle_lane = randi_range(0, LANE_X.size() - 1)
		obstacle_blocks_jump = Obstacle.blocks_jump(obstacle_type)
		_obstacle.configure(obstacle_type)
		_obstacle.position = Vector3(LANE_X[obstacle_lane], OBSTACLE_Y, 0.0)
		_obstacle.visible = true
		_obstacle.monitoring = true
		_obstacle.monitorable = true
	else:
		_deactivate_obstacle()

	for lane in LANE_X.size():
		var slot := _noisette_slots[lane]
		if lane == noisette_lane and lane != obstacle_lane:
			slot.position = Vector3(LANE_X[lane], NOISETTE_Y, 0.0)
			slot.collected = false
			slot.visible = true
			slot.monitoring = true
			slot.monitorable = true
		else:
			_deactivate_noisette(slot)

	if gland_lane != -1 and not (obstacle_blocks_jump and gland_lane == obstacle_lane):
		_gland.position = Vector3(LANE_X[gland_lane], GLAND_Y, 0.0)
		_gland.collected = false
		_gland.visible = true
		_gland.monitoring = true
		_gland.monitorable = true
	else:
		_deactivate_gland()

func _deactivate_obstacle() -> void:
	_obstacle.visible = false
	_obstacle.monitoring = false
	_obstacle.monitorable = false

func _deactivate_noisette(slot: Noisette) -> void:
	slot.visible = false
	slot.monitoring = false
	slot.monitorable = false

func _deactivate_gland() -> void:
	_gland.visible = false
	_gland.monitoring = false
	_gland.monitorable = false
