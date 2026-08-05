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
# Obstacle root always sits at ground level (y=0) now: each of its three
# variants (DODGE/JUMP/ENEMY, see Obstacle.gd) carries its own vertical
# offset on its own mesh/shape children, so the segment never needs to
# know which variant is active to position it.
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
## (DODGE or ENEMY, see Obstacle.blocks_jump) -- jumping into that lane to
## reach the Gland would run Keepy straight into the obstacle.
func populate(spawn_obstacle: bool, obstacle_type: Obstacle.Type, noisette_lane: int, gland_lane: int) -> void:
	var obstacle_lane := -1
	var obstacle_blocks_jump := false

	if spawn_obstacle:
		obstacle_blocks_jump = Obstacle.blocks_jump(obstacle_type)
		if obstacle_type == Obstacle.Type.ENEMY:
			obstacle_lane = _pick_enemy_final_lane()
			var alt_lane := _pick_enemy_alt_lane(obstacle_lane)
			_obstacle.configure(obstacle_type, LANE_X[obstacle_lane], LANE_X[alt_lane])
		else:
			obstacle_lane = randi_range(0, LANE_X.size() - 1)
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
			slot.set_spawn_position(Vector3(LANE_X[lane], NOISETTE_Y, 0.0))
			slot.collected = false
			slot.visible = true
			slot.monitoring = true
			slot.monitorable = true
		else:
			_deactivate_noisette(slot)

	if gland_lane != -1 and not (obstacle_blocks_jump and gland_lane == obstacle_lane):
		_gland.set_spawn_position(Vector3(LANE_X[gland_lane], GLAND_Y, 0.0))
		_gland.collected = false
		_gland.visible = true
		_gland.monitoring = true
		_gland.monitorable = true
	else:
		_deactivate_gland()

## Final (settled) lane for an ENEMY obstacle. Deliberately NOT a plain
## randi_range(0, 2) uniform draw over the 3 lanes -- see the long
## comment below for why, and DODGE/JUMP's obstacle_lane draw in
## populate() above for what a plain uniform draw actually looks like
## (still used for those two, unaffected by this).
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

## Adjacent lane for an ENEMY obstacle to sway toward before settling on
## `lane` (see Obstacle.gd). The middle lane (index 1) has two neighbours
## and picks between them; either edge lane (0 or 2) only has the middle
## lane as a neighbour.
func _pick_enemy_alt_lane(lane: int) -> int:
	if lane == 1:
		return 0 if randf() < 0.5 else 2
	return 1

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
