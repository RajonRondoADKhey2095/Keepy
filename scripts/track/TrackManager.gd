extends Node3D
## Spawns track segments ahead of the player and recycles them once
## they pass behind -- a fixed-size object pool, never queue_free() /
## re-instantiate in the running loop.
##
## Architecture note -- the WORLD moves toward the static player
## instead of the player moving through the world. Keepy never
## advances on Z (see Keepy.gd); every frame this script instead
## nudges each TrackSegment's Z position toward the player by the
## current run speed. This keeps every moving Node3D's coordinates
## bounded to a small range around the origin forever, which avoids
## the floating point precision loss a genuinely unbounded player
## Z coordinate would eventually introduce (visible transform jitter
## after enough kilometers of "real" travel on a 32-bit float). It
## also means recycling a segment is just "move it back to the front
## and repopulate its contents" -- no allocation, no destruction.

const SEGMENT_SCENE: PackedScene = preload("res://scenes/TrackSegment.tscn")
const SEGMENT_LENGTH: float = 20.0
const SEGMENT_COUNT: int = 7
const RECYCLE_Z: float = 12.0 # segment behind the player past this Z gets recycled
const SAFE_START_SEGMENTS: int = 2 # no obstacles on the first N segments of a run
const OBSTACLE_CHANCE: float = 0.55
# Chance of a jump-type obstacle vs. a dodge-type one when an obstacle
# spawns at all (see Obstacle.gd Type). 0.5 = balanced mix of both gestures.
const JUMP_OBSTACLE_CHANCE: float = 0.5
# Chance of a noisette appearing at all in a segment. Only ONE lane is
# ever picked per segment (see TrackSegment.populate) -- Keepy can only
# be on one lane at a time, so this is no longer "per lane".
# Was 0.5. The one-noisette-per-row cap (TrackSegment.populate, previous
# fix) mechanically halved the ceiling on noisettes per row (two lanes
# could show one each before that cap), and roughly a third of remaining
# rolls are further dropped when the picked lane collides with the
# obstacle's lane (obstacle wins, see populate) -- both silently thin out
# the total count. Bumped to 0.85 to bring the actual per-run pickup
# density back in line with what it was before the cap.
const NOISETTE_CHANCE_PER_ROW: float = 0.85
# Gland is a rarer bonus than the ground noisette (it also requires jump
# timing to reach, see Gland.gd/TrackSegment.GLAND_Y) -- deliberately kept
# well below NOISETTE_CHANCE_PER_ROW.
const GLAND_CHANCE_PER_ROW: float = 0.12

var _segments: Array[TrackSegment] = []

func _ready() -> void:
	for i in SEGMENT_COUNT:
		var segment: TrackSegment = SEGMENT_SCENE.instantiate()
		add_child(segment)
		segment.position = Vector3(0.0, 0.0, -float(i) * SEGMENT_LENGTH)
		_segments.append(segment)
		_populate_segment(segment, i)

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return

	var move_amount := GameState.current_speed * delta
	GameState.add_distance(move_amount)

	for segment in _segments:
		segment.position.z += move_amount
		if segment.position.z > RECYCLE_Z:
			_recycle_segment(segment)

## Called by Game.gd when a new run starts (fresh game or retry) so the
## track always looks the same at the starting line.
func reset() -> void:
	for i in _segments.size():
		var segment := _segments[i]
		segment.position = Vector3(0.0, 0.0, -float(i) * SEGMENT_LENGTH)
		_populate_segment(segment, i)

func _recycle_segment(segment: TrackSegment) -> void:
	var furthest_z := 0.0
	for s in _segments:
		furthest_z = minf(furthest_z, s.position.z)
	segment.position.z = furthest_z - SEGMENT_LENGTH
	_populate_segment(segment, -1)

## index >= 0 is only used to keep the very first segments obstacle-free
## so a run always has a safe start; index == -1 means "mid-run recycle",
## always eligible for obstacles.
func _populate_segment(segment: TrackSegment, index: int) -> void:
	var spawn_obstacle := (index == -1 or index >= SAFE_START_SEGMENTS) and randf() < OBSTACLE_CHANCE
	var obstacle_type := Obstacle.Type.JUMP if randf() < JUMP_OBSTACLE_CHANCE else Obstacle.Type.DODGE

	var noisette_lane := -1
	if randf() < NOISETTE_CHANCE_PER_ROW:
		noisette_lane = randi_range(0, 2)

	var gland_lane := -1
	if randf() < GLAND_CHANCE_PER_ROW:
		gland_lane = randi_range(0, 2)

	segment.populate(spawn_obstacle, obstacle_type, noisette_lane, gland_lane)
