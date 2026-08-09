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
## It also owns this tile's purely visual decor, on that same
## build-once-then-only-reposition contract: the two lane curbs
## (_build_lane_curbs, static), the per-segment ground tint
## (_reroll_ground_tint, re-rolled per populate) and the trackside props
## (_build_trackside_props / _place_trackside_props, re-rolled per
## populate). None of the three has a collider or touches GameState; see
## each section's own doc.
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
## Handed out by DecorRng (F10) so a probe can pin the background it
## measures against; unforced, still an OS-entropy stream as before.
var _tint_rng := DecorRng.make()

## Top face of this segment's ground slab, in the segment's OWN local
## space -- the y = 0 plane every hazard offset in Hitboxes.gd is measured
## from, expressed where a child of this node can actually use it.
##
## Derived from the slab's own half-thickness rather than written as a
## literal: the ground MeshInstance3D sits at -GROUND_SIZE.y * 0.5 so its
## TOP lands on the plane (see _apply_hitbox), and anything standing on
## that plane has to move with it if the slab is ever re-dimensioned. Two
## call sites (the lane curbs and the trackside props below), one
## expression -- a decor surface that quietly floated or sank because a
## second copy of "+ 0.2" was missed is exactly the class of drift this
## avoids.
func _ground_top_y() -> float:
	return _ground.position.y + Hitboxes.GROUND_SIZE.y * 0.5

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
	_build_trackside_props()

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
		strip.position = Vector3(x, _ground_top_y() + _CURB_HEIGHT * 0.5, 0.0)
		add_child(strip)

# =====================================================================
# TRACKSIDE PROPS (decor batch, second pass) -- low-poly trees and rocks
# standing on the ground plane just OUTSIDE the track, so the run reads as
# passing THROUGH somewhere rather than along an endless bare strip.
#
# Same lifecycle as _build_lane_curbs() above, and for the same reason: a
# prop is a property of a track TILE, not of the world. Built once in
# _ready(), then only ever shown/hidden and repositioned by populate() --
# so a prop travels and recycles with its segment for free, exactly like
# the pooled Obstacle/Noisette/Gland siblings, and nothing is allocated
# during a run. This is deliberately NOT a second Decor.gd-style global
# layer: Decor's hills need their own pool because they scroll at their
# own parallax rate and belong to no tile, which is the opposite of what
# a prop standing on this slab's shoulder is.
#
# ZERO GAMEPLAY COUPLING, BY CONSTRUCTION -- the same guarantee Decor.gd
# states for the hills, and it holds here for stronger reasons because
# these live INSIDE a physics body:
#   * no collider. A MeshInstance3D child of a StaticBody3D contributes
#     nothing to that body's shape set; only a CollisionShape3D does, and
#     not one is created below. The slab Keepy stands on is still exactly
#     the one _apply_hitbox() writes from Hitboxes.GROUND_SIZE.
#   * no GameState access at all -- not even the one-way reads Decor.gd
#     and LaneBarrier.gd make. Props are placed from populate()'s own call
#     and never look at run state.
#   * never read by Hitboxes.gd or ModelSlot.gd, and invisible to every
#     consumer that walks a segment's children: TrackManager and the dev
#     probes all filter on `child is Obstacle`, and AssetContractAudit
#     collects only ModelSlot and CollisionShape3D nodes. A plain
#     MeshInstance3D matches none of those.
# scripts/dev/TrackPropsAudit.gd asserts the collider half of that rather
# than leaving it as this paragraph, and the six gated bot probes prove
# the rest by returning byte-identical output with props live.
#
# THE KEEP-OUT IS THE LOAD-BEARING PART. The ground slab is 6m wide
# (Hitboxes.GROUND_SIZE.x) with lanes at -2/0/+2, and the readable play
# area is everything inside it. A prop must never overlap it, so the
# constraint is written against the prop's own SILHOUETTE EDGE, not its
# centre: a trunk placed at |x| = 3.2 satisfies "centre outside the slab"
# while its 0.9m canopy still hangs a third of a metre over the lane the
# player is reading. Every placement below therefore starts from
# _PROP_KEEPOUT_X and adds the prop's own half-width before it adds any
# random spread, so the nearest edge is at |x| >= _PROP_KEEPOUT_X by
# arithmetic rather than by a tuning value that happens to be big enough.
#
# DARK-MODE VALUE (docs/MESHY_SPEC.md section 8): unshaded, and separated
# from everything by VALUE, never hue -- see section 8.2 for the measured
# contrast table these three albedos were chosen from.
# =====================================================================

## Clear margin between the edge of the ground slab and the nearest point
## of any prop. Small on purpose: the props should read as lining the
## track, not as a distant treeline.
const _PROP_CLEARANCE_M: float = 0.4

## No part of any prop may be closer to the track centre than this.
## Derived from the slab's own width so it cannot drift out of agreement
## with the surface it is a margin around -- a hand-written 3.4 would
## silently start overlapping the day GROUND_SIZE.x changed.
const _PROP_KEEPOUT_X: float = Hitboxes.GROUND_SIZE.x * 0.5 + _PROP_CLEARANCE_M

## How far beyond the keep-out a prop may be pushed, on top of its own
## half-width. Wide enough that a row of props never lines up into a
## corridor wall.
const _PROP_X_SPREAD: float = 4.2

## Prop positions per side of the track. TWO rather than one so a side can
## come up empty, single OR clustered: with a single slot every populated
## tile would show exactly one prop per side, which is the "one prop per
## 20m like clockwork" rhythm this system exists to avoid.
const _PROP_SLOTS_PER_SIDE: int = 2

## Chance that a given slot shows anything at all, rolled fresh per
## populate(). Below 0.5 on purpose: combined with two slots a side, it
## makes empty stretches and small clumps both common, and the pair
## (nothing this tile, three props the next) is what breaks the metronome.
const _PROP_PRESENCE_CHANCE: float = 0.45

## Split between the two prop kinds when a slot is populated.
const _PROP_TREE_CHANCE: float = 0.6

## How far along the tile a prop may sit, either side of its centre. Just
## inside the 20m tile's own half-length, so a prop never straddles the
## seam between two segments -- where it would be visibly cut in half the
## moment one of the two recycled.
const _PROP_Z_HALF_RANGE: float = 9.0

## Trees: a tapered trunk under a low-facet cone canopy, two primitives.
const _TREE_TRUNK_RADIUS: Vector2 = Vector2(0.09, 0.15)
const _TREE_TRUNK_HEIGHT: Vector2 = Vector2(0.8, 1.5)
const _TREE_CANOPY_RADIUS: Vector2 = Vector2(0.55, 0.95)
const _TREE_CANOPY_HEIGHT: Vector2 = Vector2(1.5, 2.6)
## Sides on both cylinders. Five reads as a low-poly silhouette from the
## camera's distance and costs a handful of triangles.
const _TREE_SIDES: int = 5
## Fraction of the canopy's height that overlaps the top of the trunk, so
## the two primitives never show a gap between them at a low camera angle.
const _TREE_CANOPY_SINK: float = 0.12

## Rocks: one squashed low-facet sphere, randomly yawed and stretched
## along z so no two read as the same boulder.
const _ROCK_RADIUS: Vector2 = Vector2(0.30, 0.62)
## Height as a fraction of the diameter -- always under 1.0, i.e. always
## flatter than a ball.
const _ROCK_FLATNESS: Vector2 = Vector2(0.55, 0.9)
const _ROCK_Z_STRETCH: Vector2 = Vector2(0.7, 1.25)
const _ROCK_SIDES: int = 6
const _ROCK_RINGS: int = 3
## Fraction of the rock's half-height left above the ground plane, so it
## sits bedded IN the ground rather than balanced on it.
const _ROCK_SINK: float = 0.82

## See docs/MESHY_SPEC.md section 8.2 for the measured contrast table.
## All three sit in the scene's darkest band, well below the far hills
## (the darkest thing they are ever seen against), because the backdrop
## for anything beyond the slab edge is sky and hillside -- the two
## BRIGHTEST surfaces in the scene -- not the ground.
const _TREE_CANOPY_COLOR: Color = Color(0.14, 0.20, 0.15)
const _TREE_TRUNK_COLOR: Color = Color(0.13, 0.10, 0.07)
const _ROCK_COLOR: Color = Color(0.18, 0.19, 0.20)

## One entry per prop slot: the three mesh instances it can draw (a tree
## is trunk + canopy, a rock is one mesh) and which side of the track it
## belongs to. All three exist for every slot from _ready() onward and are
## only ever toggled, so switching a slot from tree to rock allocates
## nothing.
var _prop_slots: Array[Dictionary] = []

## OWN RandomNumberGenerator, for the same reason _tint_rng and Decor's
## _rng have one: the global randf() stream is the one TrackManager's
## spawn rolls draw from and the one dev probes seed for reproducible
## runs, so drawing decor from it would shift every gameplay roll after
## it -- a purely visual system silently deciding which hazards a seeded
## run spawns. Separate from _tint_rng rather than shared so that
## retuning one of the two can never re-sequence the other -- DecorRng
## hands each its own stream, so that stays true when seeded (F10).
var _prop_rng := DecorRng.make()

func _build_trackside_props() -> void:
	var canopy_material := _unshaded(_TREE_CANOPY_COLOR)
	var trunk_material := _unshaded(_TREE_TRUNK_COLOR)
	var rock_material := _unshaded(_ROCK_COLOR)

	for side in [-1.0, 1.0]:
		for i in _PROP_SLOTS_PER_SIDE:
			# Named rather than left to Godot's @MeshInstance3D@NN
			# auto-names: scripts/dev/TrackPropsAudit.gd attributes every
			# triangle in the frame to a family, and a segment's plain
			# mesh children (slab, curbs, props) are otherwise
			# indistinguishable from each other by anything but a guess at
			# their mesh type.
			var label := "%s%d" % ["L" if side < 0.0 else "R", i]

			# Tessellation is set HERE, not per roll: it never varies, and
			# a primitive left at its Godot default would sit on a 64x32
			# vertex buffer (~4,000 triangles for a boulder) from _ready()
			# until its first placement -- paid for whether or not that
			# slot ever draws.
			var trunk_mesh := CylinderMesh.new()
			trunk_mesh.radial_segments = _TREE_SIDES
			trunk_mesh.rings = 0
			# Both caps are hidden in every case -- the bottom by the
			# ground, the top by the canopy sunk over it -- so neither is
			# worth drawing.
			trunk_mesh.cap_top = false
			trunk_mesh.cap_bottom = false
			var trunk := _build_prop_mesh(trunk_mesh, trunk_material, "PropTrunk" + label)

			# A cone: the cheapest primitive that reads as foliage, same
			# choice and same reasoning as Decor.gd's hills.
			var canopy_mesh := CylinderMesh.new()
			canopy_mesh.top_radius = 0.0
			canopy_mesh.radial_segments = _TREE_SIDES
			canopy_mesh.rings = 0
			# The underside IS visible: the camera sits above the track
			# looking forward and down, so a capless cone would show
			# hollow from behind.
			canopy_mesh.cap_bottom = true
			var canopy := _build_prop_mesh(canopy_mesh, canopy_material, "PropCanopy" + label)

			var rock_mesh := SphereMesh.new()
			rock_mesh.radial_segments = _ROCK_SIDES
			rock_mesh.rings = _ROCK_RINGS
			var rock := _build_prop_mesh(rock_mesh, rock_material, "PropRock" + label)
			_prop_slots.append({
				"side": side,
				"trunk": trunk,
				"canopy": canopy,
				"rock": rock,
			})
	_hide_all_props()

## One prop mesh instance, added to this segment and hidden. `cast_shadow`
## is off for the same reason Decor.gd switches it off on the hills and
## _build_lane_curbs does on the curbs: this is decor sitting outside the
## readable play area, and it has no business adding to the one
## DirectionalLight3D's shadow pass.
func _build_prop_mesh(mesh: PrimitiveMesh, material: StandardMaterial3D, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.set_surface_override_material(0, material)
	instance.visible = false
	add_child(instance)
	return instance

func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

func _hide_all_props() -> void:
	for slot in _prop_slots:
		slot["trunk"].visible = false
		slot["canopy"].visible = false
		slot["rock"].visible = false

## Re-rolls every prop slot: present or not, tree or rock, and where.
## Called from populate(), i.e. once at the initial fill and once per
## recycle -- never per frame.
func _place_trackside_props() -> void:
	for slot in _prop_slots:
		var side: float = slot["side"]
		var show_prop := _prop_rng.randf() < _PROP_PRESENCE_CHANCE
		var show_tree := show_prop and _prop_rng.randf() < _PROP_TREE_CHANCE
		slot["trunk"].visible = show_tree
		slot["canopy"].visible = show_tree
		slot["rock"].visible = show_prop and not show_tree
		if not show_prop:
			continue
		var z := _prop_rng.randf_range(-_PROP_Z_HALF_RANGE, _PROP_Z_HALF_RANGE)
		if show_tree:
			_place_tree(slot, side, z)
		else:
			_place_rock(slot, side, z)

func _place_tree(slot: Dictionary, side: float, z: float) -> void:
	var trunk_radius := _prop_rng.randf_range(_TREE_TRUNK_RADIUS.x, _TREE_TRUNK_RADIUS.y)
	var trunk_height := _prop_rng.randf_range(_TREE_TRUNK_HEIGHT.x, _TREE_TRUNK_HEIGHT.y)
	var canopy_radius := _prop_rng.randf_range(_TREE_CANOPY_RADIUS.x, _TREE_CANOPY_RADIUS.y)
	var canopy_height := _prop_rng.randf_range(_TREE_CANOPY_HEIGHT.x, _TREE_CANOPY_HEIGHT.y)

	var trunk_mesh := slot["trunk"].mesh as CylinderMesh
	trunk_mesh.top_radius = trunk_radius * 0.75
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.height = trunk_height

	var canopy_mesh := slot["canopy"].mesh as CylinderMesh
	canopy_mesh.bottom_radius = canopy_radius
	canopy_mesh.height = canopy_height

	# The canopy is the widest part of a tree, so it is the canopy's radius
	# -- not the trunk's -- that the keep-out has to clear.
	var x := _prop_x(side, canopy_radius)
	var ground_y := _ground_top_y()
	slot["trunk"].position = Vector3(x, ground_y + trunk_height * 0.5, z)
	slot["canopy"].position = Vector3(
		x,
		ground_y + trunk_height + canopy_height * (0.5 - _TREE_CANOPY_SINK),
		z,
	)

func _place_rock(slot: Dictionary, side: float, z: float) -> void:
	var radius := _prop_rng.randf_range(_ROCK_RADIUS.x, _ROCK_RADIUS.y)
	var flatness := _prop_rng.randf_range(_ROCK_FLATNESS.x, _ROCK_FLATNESS.y)
	var z_stretch := _prop_rng.randf_range(_ROCK_Z_STRETCH.x, _ROCK_Z_STRETCH.y)

	var rock: MeshInstance3D = slot["rock"]
	var mesh := rock.mesh as SphereMesh
	mesh.radius = radius
	mesh.height = radius * 2.0 * flatness

	# Stretched along z and spun on its own axis, so six facets and one
	# mesh still never produce two boulders that read as copies.
	rock.scale = Vector3(1.0, 1.0, z_stretch)
	rock.rotation = Vector3(0.0, _prop_rng.randf_range(0.0, TAU), 0.0)

	# A yawed ellipse can present at most its LONGEST semi-axis sideways,
	# whatever the angle -- so clearing that bounds the silhouette for
	# every rotation, without the keep-out having to know the yaw.
	var half_width := radius * maxf(1.0, z_stretch)
	var half_height := radius * flatness
	rock.position = Vector3(_prop_x(side, half_width), _ground_top_y() + half_height * _ROCK_SINK, z)

## X for a prop whose silhouette reaches `half_width` either side of its
## own centre. The keep-out and the half-width are both added BEFORE the
## random spread, which is what makes "no part of a prop is ever closer to
## the centre line than _PROP_KEEPOUT_X" arithmetic rather than a hope
## about how the ranges above happen to be tuned.
func _prop_x(side: float, half_width: float) -> float:
	return side * (_PROP_KEEPOUT_X + half_width + _prop_rng.randf_range(0.0, _PROP_X_SPREAD))

## Distance from the track centre line to the nearest point of any prop
## currently drawn by this segment, or INF when it is showing none.
##
## MEASURED off the real mesh AABBs rather than recomputed from _prop_x's
## arithmetic: a check that re-derived the placement formula would agree
## with itself no matter how wrong the formula was. Kept as a narrow
## accessor (one number) rather than exposing the prop nodes, same shape
## and same reason as active_gland_z_on_lane above. Read only by
## scripts/dev/TrackPropsAudit.gd.
func nearest_prop_edge_x() -> float:
	var nearest := INF
	for slot in _prop_slots:
		for key in ["trunk", "canopy", "rock"]:
			var instance: MeshInstance3D = slot[key]
			if not instance.visible:
				continue
			var box: AABB = instance.transform * instance.get_aabb()
			var near_edge := minf(absf(box.position.x), absf(box.position.x + box.size.x))
			nearest = minf(nearest, near_edge)
	return nearest

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
	_place_trackside_props()
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
