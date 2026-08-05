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

# =====================================================================
# ADAPTIVE OBSTACLE SPACING -- the whole reason the speed cap can be
# raised without the track turning into an unreadable wall.
#
# Obstacles sit on a fixed 20m grid (one per TrackSegment), so at a
# constant spawn probability the time between two of them shrinks in
# direct proportion to the run speed. Measured on the real scene, two
# adjacent rows leave the player 20/26 = 0.77s at the cap, of which the
# lane switch itself eats 0.25s -- 0.52s to actually read the next
# obstacle and commit. That is the number that makes a fast runner feel
# cheap rather than fast.
#
# The fix is spacing, not a lower cap: the minimum gap is expressed in
# SECONDS and converted to a number of rows against the current speed,
# so the track physically opens up as the run accelerates.
# =====================================================================

## Time the player is guaranteed to still have, once the previous
## obstacle has passed them, to READ the next one and commit to a lane --
## ON TOP of the time the lane switch itself then takes. The single knob
## for "how fair does the track feel"; raising it thins the track at
## speed, lowering it packs it tighter.
const OBSTACLE_REACTION_BUDGET_S: float = 0.6

## Minimum time that must therefore separate two consecutive obstacles,
## perception budget plus the lane switch's own travel time. Stated in
## seconds (never in metres) for exactly the same reason as
## Obstacle.ENEMY_REACTION_WINDOW_S: a fixed metre value would silently
## become a shorter and shorter reaction window as the speed table ramps.
const MIN_OBSTACLE_GAP_S: float = Obstacle.LANE_SWITCH_TIME_S + OBSTACLE_REACTION_BUDGET_S

## Spawn probability of an ELIGIBLE row (one far enough behind the last
## obstacle to be allowed one at all), lerped over
## GameState.BASE_SPEED..MAX_SPEED.
##
## It rises with speed to COMPENSATE the enforced gap above, not to add
## difficulty on top of it: once the minimum gap crosses one row (which
## it does at 22.5 m/s, where 0.85s of gap needs more than 20m), every
## other row becomes ineligible and a flat 0.55 chance would leave the
## late game emptier than the early game -- the spacing fix would have
## quietly made the hard part easier. At the cap, 0.85 on a two-row grid
## lands the mean gap at ~1.67s against the ~1.43s a flat 0.55 gave at
## 26 m/s before this change, i.e. roughly the density the track already
## had, now with a floor under the worst case instead of none.
const OBSTACLE_CHANCE_BASE: float = 0.55
const OBSTACLE_CHANCE_CAP: float = 0.85

# Relative weights for which Obstacle.Type spawns when an obstacle spawns
# at all. DODGE and JUMP stay the bulk of the spawn table; ENEMY (moving,
# forces a late reaction) is a rarer additional variant, not a
# replacement -- see Obstacle.gd Type.ENEMY. Must sum to 1.0.
const DODGE_TYPE_CHANCE: float = 0.45
const JUMP_TYPE_CHANCE: float = 0.45
# ENEMY_TYPE_CHANCE is implicitly 1.0 - DODGE_TYPE_CHANCE - JUMP_TYPE_CHANCE (0.10).

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

## Distance, IN ROWS, from the row currently being populated back to the
## last row that got an obstacle -- so it is directly comparable to
## _required_gap_rows() with no off-by-one to get wrong: 1 means "the
## previous row had one", not "zero rows have passed since". Starts at
## SEGMENT_COUNT, which reads as "no obstacle anywhere behind us".
##
## Segments are always populated in the order the player will meet them
## (at reset front to back, and mid-run one at a time as each recycles to
## the far end), so this single counter is enough to space a stream of
## rows -- no per-segment bookkeeping, no allocation.
var _rows_to_last_obstacle: int = SEGMENT_COUNT

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
	_rows_to_last_obstacle = SEGMENT_COUNT
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
	var eligible := (index == -1 or index >= SAFE_START_SEGMENTS) \
		and _rows_to_last_obstacle >= _required_gap_rows()
	var spawn_obstacle := eligible and randf() < _obstacle_chance()
	# 1, not 0: the NEXT row to be populated sits exactly one row after
	# this one, which is the value the gate above compares.
	_rows_to_last_obstacle = 1 if spawn_obstacle else _rows_to_last_obstacle + 1
	var obstacle_type := _pick_obstacle_type()

	var noisette_lane := -1
	if randf() < NOISETTE_CHANCE_PER_ROW:
		noisette_lane = randi_range(0, 2)

	var gland_lane := -1
	if randf() < GLAND_CHANCE_PER_ROW:
		gland_lane = randi_range(0, 2)

	segment.populate(spawn_obstacle, obstacle_type, noisette_lane, gland_lane)

## How many rows must sit between two obstacles at the pace this row is
## being laid out for. Rounded UP so the gap is never short by a fraction
## of a row, and floored at 1 so two obstacles can never land on the same
## row -- which the one-obstacle-per-TrackSegment pool makes impossible
## anyway, but the floor states it rather than relying on it.
##
## Uses GameState.lookahead_speed(), not current_speed: this row is
## spawned ~128m ahead and will be RUN THROUGH several seconds later,
## potentially one palier faster (see lookahead_speed's own comment).
func _required_gap_rows() -> int:
	return maxi(1, ceili(MIN_OBSTACLE_GAP_S * GameState.lookahead_speed() / SEGMENT_LENGTH))

## Spawn probability for a row that is already far enough from the last
## obstacle -- see OBSTACLE_CHANCE_BASE / OBSTACLE_CHANCE_CAP.
func _obstacle_chance() -> float:
	var t := clampf(
		(GameState.lookahead_speed() - GameState.BASE_SPEED)
			/ (GameState.MAX_SPEED - GameState.BASE_SPEED),
		0.0, 1.0
	)
	return lerpf(OBSTACLE_CHANCE_BASE, OBSTACLE_CHANCE_CAP, t)

## Weighted pick among the three Obstacle.Type variants -- see
## DODGE_TYPE_CHANCE / JUMP_TYPE_CHANCE above for the weights.
func _pick_obstacle_type() -> Obstacle.Type:
	var roll := randf()
	if roll < DODGE_TYPE_CHANCE:
		return Obstacle.Type.DODGE
	if roll < DODGE_TYPE_CHANCE + JUMP_TYPE_CHANCE:
		return Obstacle.Type.JUMP
	return Obstacle.Type.ENEMY
