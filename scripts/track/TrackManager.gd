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

# =====================================================================
# AIR_ENEMY <-> JUMP / GLAND SEPARATION -- AIR_ENEMY sits at the exact
# same height as a Gland and shares its lane with whatever JUMP obstacle
# happens to be nearby, so it is the first hazard whose fairness depends
# on ANOTHER ROW's content, not just its own. See Obstacle.gd
# Type.AIR_ENEMY for what it does; the two conflicts this section guards
# against are both "the player is forced to jump into it with no way to
# have seen it coming":
#   - a JUMP obstacle (which REQUIRES a jump to clear) landing too close,
#     on the same lane, to an AIR_ENEMY (which PUNISHES a jump) -- the
#     player would be forced to jump into the very thing that kills them;
#   - a Gland (which REQUIRES a jump to reach) landing too close, on the
#     same lane, to an AIR_ENEMY the player had no time to notice yet.
# Distinct lanes at the same Z are the OPPOSITE of a problem -- "do I
# switch lanes for the Gland, or stay safe" is exactly the interesting
# decision this obstacle exists to create -- so this rule is scoped to
# the SAME lane only, never across lanes.
# =====================================================================

## Minimum TIME that must separate an AIR_ENEMY obstacle from a JUMP
## obstacle or a Gland occupying the SAME lane, on either side (earlier
## or later -- generation is strictly sequential row by row, so whichever
## of the two is placed SECOND is always the one that can see the other
## and back off). Reuses OBSTACLE_REACTION_BUDGET_S (the ground track's
## own "time left to read and commit" budget) doubled: these two hazards
## sit higher up the screen than a ground obstacle and are read at a
## glance rather than dead ahead, so they need more margin to be told
## apart, not less. Converted to rows the same seconds-not-metres way as
## MIN_OBSTACLE_GAP_S, so it stays a constant amount of REACTION time
## across the whole speed ramp instead of shrinking as the run speeds up.
const AIR_HAZARD_SEPARATION_S: float = OBSTACLE_REACTION_BUDGET_S * 2.0

# Relative weights for which Obstacle.Type spawns when an obstacle spawns
# at all. DODGE and JUMP stay the bulk of the spawn table; ENEMY (moving,
# forces a late reaction) and AIR_ENEMY (punishes a jump, see Obstacle.gd
# Type.AIR_ENEMY) are rarer additional variants, not a replacement -- kept
# EQUALLY rare as each other so neither one saturates the track. Must sum
# to 1.0.
const DODGE_TYPE_CHANCE: float = 0.40
const JUMP_TYPE_CHANCE: float = 0.40
const ENEMY_TYPE_CHANCE: float = 0.10
# AIR_ENEMY_TYPE_CHANCE is implicitly 1.0 - the three above (0.10) -- see
# _pick_obstacle_type(). Kept as a remainder rather than a fourth named
# constant so the four weights can never silently drift out of summing
# to 1.0 by editing one and forgetting to compensate another.

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

# Same idea as _rows_to_last_obstacle above, but PER LANE and per hazard
# kind, for the AIR_ENEMY <-> JUMP / Gland separation rule (see
# AIR_HAZARD_SEPARATION_S). Index-aligned with TrackSegment.LANE_X (3
# lanes); fixed-size arrays allocated once here, never resized in the
# game loop. _NO_RECENT_HAZARD is a sentinel comfortably larger than any
# real separation gate, reading as "nothing recent on this lane" --
# same spirit as _rows_to_last_obstacle's SEGMENT_COUNT start value.
const _NO_RECENT_HAZARD: int = 9999
var _rows_since_jump_on_lane: Array[int] = [_NO_RECENT_HAZARD, _NO_RECENT_HAZARD, _NO_RECENT_HAZARD]
var _rows_since_air_enemy_on_lane: Array[int] = [_NO_RECENT_HAZARD, _NO_RECENT_HAZARD, _NO_RECENT_HAZARD]
var _rows_since_gland_on_lane: Array[int] = [_NO_RECENT_HAZARD, _NO_RECENT_HAZARD, _NO_RECENT_HAZARD]

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
	for lane in 3:
		_rows_since_jump_on_lane[lane] = _NO_RECENT_HAZARD
		_rows_since_air_enemy_on_lane[lane] = _NO_RECENT_HAZARD
		_rows_since_gland_on_lane[lane] = _NO_RECENT_HAZARD
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
	for lane in 3:
		_rows_since_jump_on_lane[lane] += 1
		_rows_since_air_enemy_on_lane[lane] += 1
		_rows_since_gland_on_lane[lane] += 1

	var eligible := (index == -1 or index >= SAFE_START_SEGMENTS) \
		and _rows_to_last_obstacle >= _required_gap_rows()
	var spawn_obstacle := eligible and randf() < _obstacle_chance()
	# 1, not 0: the NEXT row to be populated sits exactly one row after
	# this one, which is the value the gate above compares.
	_rows_to_last_obstacle = 1 if spawn_obstacle else _rows_to_last_obstacle + 1
	var obstacle_type := _pick_obstacle_type()

	var obstacle_lane := -1
	if spawn_obstacle:
		match obstacle_type:
			Obstacle.Type.ENEMY:
				obstacle_lane = _pick_enemy_final_lane()
			Obstacle.Type.JUMP:
				obstacle_lane = _pick_jump_lane()
			Obstacle.Type.AIR_ENEMY:
				obstacle_lane = _pick_air_enemy_lane()
				if obstacle_lane == -1:
					# Every lane was too close to a recent JUMP or Gland
					# (see AIR_HAZARD_SEPARATION_S) -- demote to DODGE
					# rather than force an unfair placement or waste the
					# row silently. DODGE has no lane restriction of its
					# own, so this can never cascade into a second demotion.
					obstacle_type = Obstacle.Type.DODGE
					obstacle_lane = randi_range(0, 2)
			_: # DODGE
				obstacle_lane = randi_range(0, 2)

		if obstacle_type == Obstacle.Type.JUMP:
			_rows_since_jump_on_lane[obstacle_lane] = 0
		elif obstacle_type == Obstacle.Type.AIR_ENEMY:
			_rows_since_air_enemy_on_lane[obstacle_lane] = 0

	var noisette_lane := -1
	if randf() < NOISETTE_CHANCE_PER_ROW:
		noisette_lane = randi_range(0, 2)

	var gland_lane := -1
	if randf() < GLAND_CHANCE_PER_ROW:
		var candidate := randi_range(0, 2)
		if _rows_since_air_enemy_on_lane[candidate] >= _required_air_hazard_separation_rows():
			gland_lane = candidate
		# else: too close to a recent AIR_ENEMY on this lane -- skip the
		# gland this row rather than force it onto a different lane (same
		# cancel-not-relocate precedent as the noisette/obstacle-lane
		# collision handled in TrackSegment.populate()).
	if gland_lane != -1:
		_rows_since_gland_on_lane[gland_lane] = 0

	segment.populate(spawn_obstacle, obstacle_type, obstacle_lane, noisette_lane, gland_lane)

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

## Same "seconds converted to rows against lookahead_speed()" pattern as
## _required_gap_rows() above, sized from AIR_HAZARD_SEPARATION_S instead
## of MIN_OBSTACLE_GAP_S -- see that constant for the full rationale.
func _required_air_hazard_separation_rows() -> int:
	return maxi(1, ceili(AIR_HAZARD_SEPARATION_S * GameState.lookahead_speed() / SEGMENT_LENGTH))

## Spawn probability for a row that is already far enough from the last
## obstacle -- see OBSTACLE_CHANCE_BASE / OBSTACLE_CHANCE_CAP.
func _obstacle_chance() -> float:
	var t := clampf(
		(GameState.lookahead_speed() - GameState.BASE_SPEED)
			/ (GameState.MAX_SPEED - GameState.BASE_SPEED),
		0.0, 1.0
	)
	return lerpf(OBSTACLE_CHANCE_BASE, OBSTACLE_CHANCE_CAP, t)

## Weighted pick among the four Obstacle.Type variants -- see
## DODGE_TYPE_CHANCE / JUMP_TYPE_CHANCE / ENEMY_TYPE_CHANCE above for the
## weights (AIR_ENEMY is the implicit remainder).
func _pick_obstacle_type() -> Obstacle.Type:
	var roll := randf()
	if roll < DODGE_TYPE_CHANCE:
		return Obstacle.Type.DODGE
	if roll < DODGE_TYPE_CHANCE + JUMP_TYPE_CHANCE:
		return Obstacle.Type.JUMP
	if roll < DODGE_TYPE_CHANCE + JUMP_TYPE_CHANCE + ENEMY_TYPE_CHANCE:
		return Obstacle.Type.ENEMY
	return Obstacle.Type.AIR_ENEMY

## Final (settled) lane for an ENEMY obstacle. Deliberately NOT a plain
## randi_range(0, 2) uniform draw over the 3 lanes -- see the long
## comment below for why, and DODGE's obstacle_lane draw above for what a
## plain uniform draw actually looks like (still used for that one,
## unaffected by this).
##
## DIAGNOSTIC (playtest report: the enemy's final lane felt very
## predictable, "almost always lateral, rarely center", killing the
## interest of the mechanic):
##
## The originally suspected cause was that Obstacle.gd's sway locks onto
## whatever lane the sinusoidal oscillation happens to be nearest to at
## an "arbitrary instant" -- and a sine wave spends most of its time near
## its two extremes (zero velocity at the bounds), so an arbitrary-instant
## sample would land near an extreme more often than near the midpoint.
## THAT HYPOTHESIS IS FALSE FOR THIS CODEBASE, measured (not assumed) via
## scripts/dev/EnemyLaneAudit.gd over 200 real enemy encounters: the lock
## lane and the lane actually collided with at contact matched in EVERY
## single sample (0/200 mismatches) -- the lock has always been a
## deterministic value pre-drawn at spawn (Obstacle._enemy_lane_x, set
## once in configure()), never derived from the sway's position at lock
## time. Same measurement also found each of the 3 INDIVIDUAL lanes
## already landing almost exactly 1/3 of the time under a plain uniform
## draw (33.5% / 32.0% / 34.5% measured) -- no RNG skew toward a specific
## lane either.
##
## So why did playtesting read it as "almost always lateral" anyway? A
## plain per-lane-uniform draw over 3 lanes still makes the CATEGORY
## "lateral" (lane 0 OR lane 2 combined) come up ~2x as often as the
## category "center" (lane 1 alone) -- 68.0% vs 32.0% measured -- simply
## because there are two lateral lanes and only one center lane, each
## drawn with equal odds. That 2:1 split is a real, learnable pattern
## ("when unsure, dodge sideways, you'll be right two times out of three")
## even though no single lane is favoured over the other two. It is this
## category-level skew, not a lane-level one, that the fix below targets:
## weighting the center lane at 50% and each edge lane at 25% makes
## "lateral" and "center" equally likely AS CATEGORIES, which is what
## actually removes the learnable "guess lateral" heuristic. Re-measured
## post-fix (same probe, same sample size): center/lateral converge to
## roughly 50/50 -- see the session report for the exact numbers.
func _pick_enemy_final_lane() -> int:
	if randf() < 0.5:
		return 1
	return 0 if randf() < 0.5 else 2

## Lane for a JUMP obstacle -- almost always a plain uniform draw, EXCEPT
## it also avoids a lane an AIR_ENEMY occupied too recently (see
## AIR_HAZARD_SEPARATION_S): landing a JUMP there would force the player,
## who MUST jump to clear it, straight into the air hazard with no way
## out. Falls back to a plain uniform draw (ignoring the rule) in the
## statistically negligible case where all 3 lanes are excluded -- unlike
## AIR_ENEMY's own picker below, there is no safe type to demote a JUMP
## obstacle TO that would not need the exact same kind of lane check, so
## an occasional unlucky JUMP is the accepted edge case rather than
## adding a second demotion path.
func _pick_jump_lane() -> int:
	var required := _required_air_hazard_separation_rows()
	var candidates: Array[int] = []
	for lane in 3:
		if _rows_since_air_enemy_on_lane[lane] >= required:
			candidates.append(lane)
	if candidates.is_empty():
		return randi_range(0, 2)
	return candidates[randi_range(0, candidates.size() - 1)]

## Lane for an AIR_ENEMY obstacle -- excludes any lane a JUMP obstacle OR
## a Gland occupied too recently (see AIR_HAZARD_SEPARATION_S): the
## former would force the player to jump into it, the latter would make
## grabbing the Gland fatal on a lane the player had no reason to distrust
## yet. Returns -1 if every lane is currently excluded (rare -- caller
## demotes to a different obstacle type in that case, see
## _populate_segment).
func _pick_air_enemy_lane() -> int:
	var required := _required_air_hazard_separation_rows()
	var candidates: Array[int] = []
	for lane in 3:
		if _rows_since_jump_on_lane[lane] >= required and _rows_since_gland_on_lane[lane] >= required:
			candidates.append(lane)
	if candidates.is_empty():
		return -1
	return candidates[randi_range(0, candidates.size() - 1)]
