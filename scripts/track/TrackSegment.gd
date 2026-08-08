extends StaticBody3D
class_name TrackSegment
## One 20-unit tile of running track.
##
## Owns a fixed pool of one Obstacle, three Noisette slots (one per
## lane) and one Gland slot, created once in _ready() and only ever
## shown/hidden and repositioned by populate() -- never freed and
## re-instantiated during gameplay, so recycling a segment allocates
## nothing.
##
## Every `.monitoring` toggle below goes through set_deferred(), never a
## direct assignment: Godot blocks (logs an error and no-ops) a direct
## Area3D.monitoring change made while ANY body_entered/body_exited signal
## is still being dispatched, and a segment recycle here can land on the
## exact same physics tick as Keepy colliding with something entirely
## unrelated elsewhere on the track. Found empirically (not by inspection)
## via scripts/dev/AirHazardAudit.gd, the first dev probe to run the real
## game with Keepy's own collision left ENABLED -- every earlier probe
## neutered it, so this race was never exercised before. `.monitorable`
## is left as a direct assignment: the engine only documents/blocks this
## specific restriction for `monitoring`.

const LANE_X: Array[float] = [-2.0, 0.0, 2.0]
# Obstacle root always sits at ground level (y=0) now: each of its four
# variants (DODGE/JUMP/ENEMY/AIR_ENEMY, see Obstacle.gd) carries its own
# vertical offset on its own mesh/shape children, so the segment never
# needs to know which variant is active to position it.
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

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _ground: ModelSlot = $MeshInstance3D

# =====================================================================
# GROUND TINT VARIATION (decor batch) -- purely visual, breaks the
# identical-tile repetition of a 7-segment pool without touching geometry
# or the collider Hitboxes.gd owns (see _apply_hitbox's own doc for why
# that shape is load-bearing). Reads as a run of separately-poured
# pavement slabs rather than one continuous strip -- a deliberate, small
# per-tile seam, not a rendering artefact.
#
# Goes through ModelSlot.apply_material()/slot_material() (never `mesh` or
# `surface_material_override` directly), the same accessor pair Obstacle.gd
# and Pursuer.gd already use to tint a pooled instance without bleeding
# into its siblings -- and the one that keeps working unchanged the day the
# ground slot gets a real Meshy tile installed (see ModelSlot.gd's own
# doc): this script never assumes the ground is still the placeholder box.
# =====================================================================

## Max per-channel drift applied on top of the ground's own base albedo,
## re-rolled every populate() call (both the initial fill and every
## recycle) so a segment does not carry the same tint for its whole
## pooled lifetime. Small enough that the ground still reads as one
## material family under any of the six dark-mode tints (see
## docs/MESHY_SPEC.md section 8) -- this is a repetition-breaker, not a
## second competing hue.
const _GROUND_TINT_DRIFT: float = 0.05

## Cached once in _ready(): the ground's OWN base material, duplicated so
## tinting this segment can never bleed into a sibling segment sharing the
## same StandardMaterial3D resource (same precedent as Obstacle.gd/
## Pursuer.gd duplicating their shared material at _ready()).
var _ground_material: StandardMaterial3D
var _ground_base_color: Color

## OWN RandomNumberGenerator instance, never the global randf()/randf_range()
## -- see scripts/world/Decor.gd's own doc on _rng for the full reasoning:
## the global stream is the one TrackManager's spawn rolls draw from and the
## one dev probes seed for reproducibility (DevSeed.seed_value()), so a
## decor draw on it would silently shift every gameplay roll after it.
var _tint_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_apply_hitbox()
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

	var base_material := _ground.slot_material() as StandardMaterial3D
	_ground_base_color = base_material.albedo_color if base_material else Color.WHITE
	_ground_material = StandardMaterial3D.new()
	if base_material:
		_ground_material.shading_mode = base_material.shading_mode
	# Base colour up front, not just white-until-first-populate(): a probe
	# that instantiates a bare TrackSegment without ever calling populate()
	# (scripts/dev/AssetContractAudit.gd does exactly this) should still see
	# this segment's real ground colour, not this material's default.
	_ground_material.albedo_color = _ground_base_color
	_ground.apply_material(_ground_material)
	_build_lane_curbs()

## Re-rolls this segment's ground tint around its base colour. Called from
## populate() -- i.e. once at the initial fill and once per recycle, never
## per frame.
func _reroll_ground_tint() -> void:
	_ground_material.albedo_color = Color(
		clampf(_ground_base_color.r + _tint_rng.randf_range(-_GROUND_TINT_DRIFT, _GROUND_TINT_DRIFT), 0.0, 1.0),
		clampf(_ground_base_color.g + _tint_rng.randf_range(-_GROUND_TINT_DRIFT, _GROUND_TINT_DRIFT), 0.0, 1.0),
		clampf(_ground_base_color.b + _tint_rng.randf_range(-_GROUND_TINT_DRIFT, _GROUND_TINT_DRIFT), 0.0, 1.0),
	)

## Two thin unshaded stripes marking the boundary between lane 0/1 and
## lane 1/2 -- "bordures de piste": built ONCE here (static geometry, no
## collider, never repositioned again -- they are children of this
## segment's own transform, so they travel and recycle with it for free,
## exactly like the pooled Obstacle/Noisette/Gland siblings above) rather
## than as a separate global system, since a curb is a property of a
## track TILE, not of the world.
##
## Unshaded, and clearly separated in VALUE from the ground albedo (not
## just a saturated hue) for the same docs/MESHY_SPEC.md section 8 reason
## every other dark-mode-visible decor surface in this batch is: hue does
## not survive the invert+tint blend, luminance does.
const _CURB_COLOR: Color = Color(0.90, 0.86, 0.74)
const _CURB_WIDTH: float = 0.12
const _CURB_HEIGHT: float = 0.03
const _CURB_X: Array[float] = [-1.0, 1.0] # midway between LANE_X's three lanes

func _build_lane_curbs() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _CURB_COLOR
	for x in _CURB_X:
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(_CURB_WIDTH, _CURB_HEIGHT, 20.0)
		strip.mesh = box
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strip.set_surface_override_material(0, material)
		# Just above the ground's own top face (y = 0, see _apply_hitbox's
		# doc) to avoid z-fighting with it, and offset by the ground
		# MeshInstance3D's own local position so it lines up with the
		# visible slab rather than the StaticBody3D's origin.
		strip.position = Vector3(x, _ground.position.y + 0.2 + _CURB_HEIGHT * 0.5, 0.0)
		add_child(strip)

## Writes the ground slab's collider from Hitboxes.gd. Byte-identical to
## what TrackSegment.tscn already carried, so nothing changes today.
##
## Worth doing anyway, and arguably the most load-bearing of the lot: this
## is the surface is_on_floor() reports, so the entire jump -- and with it
## every jumpable-hazard clearance window in the game -- rests on it being
## exactly this thick and exactly this high. When the ground mesh is
## replaced by a Meshy low-poly tile (a shape with rocks, grass, or an
## uneven edge), the slab underneath has to keep being a flat 0.4m box
## whose top face is the y = 0 plane every hazard offset is measured from.
func _apply_hitbox() -> void:
	var box := _collision_shape.shape as BoxShape3D
	if box:
		box.size = Hitboxes.GROUND_SIZE
	_collision_shape.position.y = Hitboxes.GROUND_Y

## spawn_obstacle: whether this segment should have a hazard.
## obstacle_type: which Obstacle.Type variant to show when spawn_obstacle
## is true (ignored otherwise).
## obstacle_lane: lane index (0..2) the obstacle occupies when
## spawn_obstacle is true (ignored otherwise). Decided by TrackManager,
## not drawn locally here -- unlike noisette_lane/gland_lane below (which
## were always TrackManager's call), obstacle_lane USED to be drawn
## inside this function, but AIR_ENEMY's placement needs to be checked
## against OTHER segments' recent history on the same lane (a JUMP
## obstacle or a Gland occupying that lane too recently, see
## TrackManager.AIR_HAZARD_SEPARATION_S) -- state only TrackManager has,
## since individual TrackSegment instances never talk to each other. So
## ALL obstacle types now get their lane from the caller, for one
## consistent rule instead of two.
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
## (DODGE, ENEMY or AIR_ENEMY, see Obstacle.blocks_jump) -- jumping into
## that lane to reach the Gland would run Keepy straight into the
## obstacle. (Gland-vs-AIR_ENEMY on DIFFERENT rows is a separate
## constraint TrackManager enforces before it ever offers a gland_lane
## here -- see AIR_HAZARD_SEPARATION_S.)
func populate(spawn_obstacle: bool, obstacle_type: Obstacle.Type, obstacle_lane: int, noisette_lane: int, gland_lane: int) -> void:
	_reroll_ground_tint()
	var obstacle_blocks_jump := false

	if spawn_obstacle:
		obstacle_blocks_jump = Obstacle.blocks_jump(obstacle_type)
		if obstacle_type == Obstacle.Type.ENEMY:
			var alt_lane := _pick_enemy_alt_lane(obstacle_lane)
			_obstacle.configure(obstacle_type, LANE_X[obstacle_lane], LANE_X[alt_lane])
		elif obstacle_type == Obstacle.Type.STOMPER:
			# No sway/alt lane -- see Obstacle._process_stomper, it never
			# needs one. Only the provisional spawn lane is meaningful, and
			# only until it commits and starts mirroring the player.
			_obstacle.configure(obstacle_type, LANE_X[obstacle_lane])
		else:
			_obstacle.configure(obstacle_type)
		_obstacle.position = Vector3(LANE_X[obstacle_lane], OBSTACLE_Y, 0.0)
		_obstacle.visible = true
		_obstacle.set_deferred("monitoring", true)
		_obstacle.monitorable = true
	else:
		_deactivate_obstacle()

	for lane in LANE_X.size():
		var slot := _noisette_slots[lane]
		if lane == noisette_lane and lane != obstacle_lane:
			slot.set_spawn_position(Vector3(LANE_X[lane], NOISETTE_Y, 0.0))
			slot.collected = false
			slot.visible = true
			slot.set_deferred("monitoring", true)
			slot.monitorable = true
		else:
			_deactivate_noisette(slot)

	if gland_lane != -1 and not (obstacle_blocks_jump and gland_lane == obstacle_lane):
		_gland.set_spawn_position(Vector3(LANE_X[gland_lane], GLAND_Y, 0.0))
		_gland.collected = false
		_gland.visible = true
		_gland.set_deferred("monitoring", true)
		_gland.monitorable = true
	else:
		_deactivate_gland()

## Global Z of this segment's Gland if it is currently live on `lane`,
## or INF when this segment has no active Gland there.
##
## Exists so TrackManager can answer "is a Gland arriving alongside this
## charger on this lane" against the LIVE track rather than against its
## per-lane row counters -- see
## TrackManager._lane_clear_of_glands_for_charger for why a row count
## cannot express that question for a hazard that overtakes rows. Kept as
## a narrow accessor (one lane, one number) rather than exposing _gland
## itself, so segments still never hand out their pooled nodes.
##
## `visible` is the ground truth for "in play", the same filter
## TrackManager._active_obstacle_in applies to obstacles and for the same
## reason -- a hidden pooled Gland still carries its last position.
func active_gland_z_on_lane(lane: int) -> float:
	if not _gland.visible or _gland.collected:
		return INF
	if not is_equal_approx(_gland.position.x, LANE_X[lane]):
		return INF
	return _gland.global_position.z

## Adjacent lane for an ENEMY obstacle to sway toward before settling on
## `lane` (see Obstacle.gd). The middle lane (index 1) has two neighbours
## and picks between them; either edge lane (0 or 2) only has the middle
## lane as a neighbour.
##
## Skips a lane closed by a temporary track shrink (see GameState's TRACK
## SHRINK section): the sway is a pre-contact animation between the two,
## and swaying THROUGH the barrier would show the player a hazard
## apparently occupying a lane the game has just told them is shut. When
## the only neighbour is closed the enemy simply does not sway -- it
## holds its own lane, which is what `lane` already means here.
func _pick_enemy_alt_lane(lane: int) -> int:
	if lane == 1:
		var low_open := not GameState.lane_blocked(0)
		var high_open := not GameState.lane_blocked(2)
		if low_open and high_open:
			return 0 if randf() < 0.5 else 2
		if low_open:
			return 0
		if high_open:
			return 2
		return lane
	return 1 if not GameState.lane_blocked(1) else lane

func _deactivate_obstacle() -> void:
	_obstacle.visible = false
	_obstacle.set_deferred("monitoring", false)
	_obstacle.monitorable = false

func _deactivate_noisette(slot: Noisette) -> void:
	slot.visible = false
	slot.set_deferred("monitoring", false)
	slot.monitorable = false

func _deactivate_gland() -> void:
	_gland.visible = false
	_gland.set_deferred("monitoring", false)
	_gland.monitorable = false
