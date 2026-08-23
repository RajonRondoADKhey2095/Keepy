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
##
## BASE COLOUR SATURATION PASS (11 August 2026, device feedback): the base
## albedo this drifts around moved from `Color(0.42, 0.44, 0.24)` (raw
## H=66, yellow-olive, R and G nearly equal) to `Color(0.24, 0.46, 0.17)`
## in scenes/TrackSegment.tscn (raw H=105.5, S=0.63) -- green clearly
## dominant over red. RENDERED colour (what DarkPaletteAudit samples,
## after ambient/directional light) moved from H=76.7/S=0.68 to
## H=103.1/S=0.81: this scene's ambient light (Color(0.42,0.5,0.35)) pulls
## saturation and hue further than the raw albedo alone predicts, so the
## final value was reached by RE-MEASURING with the real probe, not by
## picking a raw colour on paper and trusting it. Relative luminance
## (rendered) went 0.153 -> 0.150, deliberately close: docs/MESHY_SPEC.md
## section 8 pins the DODGE/JUMP/STOMPER/CHARGER hazard-vs-ground floors to
## a narrow rendered-luminance band (~0.137-0.160, derived from those four
## hazards' own rendered colours) -- moving hue and saturation costs
## nothing there, moving value much would not. A first attempt at
## `Color(0.25, 0.47, 0.18)` rendered at L=0.158, too close to the
## CHARGER ceiling (contrast dropped to 3.08:1); this is the corrected
## value. `_GROUND_TINT_DRIFT` is untouched, so the per-segment variance is
## the same fraction of a now-more-saturated base.
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
## just a saturated hue): the curbs are a LANE-READING aid, so they have
## to survive being glanced at, and value is what carries shape reading at
## a glance. That rule outlived the reason it was first written down (the
## deleted invert+tint blend destroyed hue), and it is why this stayed the
## brightest surface in the scene when the permanent-swamp batch moved it
## from cream to pale sickly olive.
##
## The brightest thing on screen, deliberately -- brighter than the ground
## it edges, so the three lanes stay legible against a track that is itself
## now the brightest LARGE surface. See docs/MESHY_SPEC.md section 8 for
## the measured pair.
##
## SATURATION PASS (11 August 2026): moved from a pale olive (H=66, S=0.30)
## to the same ~105 deg hue family as the rest of the swamp palette, at a
## lower saturation than the ground (S=0.50 vs the ground's ~0.62) so it
## still reads as the brightest, calmest surface rather than competing with
## the track for saturation -- value is still what carries the lane read.
## The shared swamp identity. Preloaded here rather than reached through
## the GameState autoload because these are `const`: an autoload is a
## runtime node and cannot be read at constant-folding time, while a
## preloaded resource can. The colours it feeds are `static var` because a
## const initialiser cannot read a resource instance's property either;
## nothing writes them, so treat them as the constants they replaced.
const _PALETTE: SwampPalette = preload("res://resources/world/swamp_palette.tres")

static var _CURB_COLOR: Color = _PALETTE.curb_color
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

## Which KIND a populated slot draws, as cumulative weights over
## _PROP_KINDS below. Weighted rather than uniform, and rolled per slot
## rather than per tile, so a tile is a mixed handful rather than a row of
## the same shape -- the "every tile shows the same catalogue in the same
## order" reading this replaced a single tree/rock coin flip to avoid.
##
## The organic four carry most of the weight because they are what a
## roadside mostly is; the two man-made kinds are deliberately rare, so a
## bench or a sign reads as a punctuation mark rather than as street
## furniture lining the whole run.
const _PROP_KINDS: Array[String] = ["tree", "rock", "bush", "stump", "bench", "sign"]
const _PROP_KIND_WEIGHTS: Array[float] = [0.32, 0.20, 0.18, 0.14, 0.09, 0.07]

## How far along the tile a prop may sit, either side of its centre. Just
## inside the 20m tile's own half-length, so a prop never straddles the
## seam between two segments -- where it would be visibly cut in half the
## moment one of the two recycled.
const _PROP_Z_HALF_RANGE: float = 9.0

## Trees and stumps: ONE imported mesh each, not primitives.
##
## These are the first two trackside props drawn from a .glb rather than
## built out of CylinderMesh/SphereMesh. They are NOT ModelSlot installs
## (docs/MESHY_SPEC.md section 2): a slot addresses one fixed node by name,
## and these are a recycled pool of interchangeable instances with no
## gameplay code pointing at any of them -- the same reason Decor.gd's
## billboards sit outside that path. See section 11's entry for this batch
## for the measurements, and 8.3 for why they carry no texture.
##
## The mesh is loaded ONCE and shared by every instance in every segment
## (_shared_model below). Nothing writes to it, unlike the primitives
## around it whose radius/height are rewritten per placement -- a .glb is
## resized by scaling its MeshInstance3D, so the resource itself is
## immutable and safe to share.
const _BARE_TREE_MODEL_PATH: String = "res://assets/models/keepy_bare_tree_prop.glb"
const _STUMP_MODEL_PATH: String = "res://assets/models/keepy_stump_prop.glb"

## Height in metres, floor to crown. Deliberately the SAME span the
## trunk+canopy pair covered before the swap (0.8-1.5 of trunk under a
## 1.5-2.6 canopy sunk 12% into it, i.e. ~2.1-3.8m), so the change is a
## silhouette change and not also a size change -- the keep-out, the
## parallax read and 8.2's backdrop contrast all depend on how much of the
## frame a prop fills, and moving two variables at once would leave no way
## to attribute whatever the device review sees.
const _BARE_TREE_HEIGHT: Vector2 = Vector2(2.1, 3.8)

## Likewise for the stump: the cylinder+dome pair stood 0.29-0.55m tall.
const _STUMP_MODEL_HEIGHT: Vector2 = Vector2(0.30, 0.55)

## One mesh drawn 4+ times on screen at once reads as a row of clones
## unless something breaks it up, and unlike a primitive we cannot re-roll
## its proportions -- so the two levers left are how stout it is (girth,
## applied to x and z against the height) and how much it is squashed
## along one horizontal axis (z_stretch). Combined with the free yaw below
## that is enough that no two instances present the same outline.
const _MODEL_PROP_GIRTH: Vector2 = Vector2(0.85, 1.15)
const _MODEL_PROP_Z_STRETCH: Vector2 = Vector2(0.85, 1.20)

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

## Bench: a seat and a backrest slab on two short legs, four boxes and
## cylinders. Long axis along Z (parallel to the track), because a bench
## beside a path faces the path -- which also means its X extent is the
## seat DEPTH, the small dimension, so it crowds the keep-out least.
const _BENCH_LENGTH: Vector2 = Vector2(1.10, 1.70)   # along z
const _BENCH_DEPTH: Vector2 = Vector2(0.34, 0.46)    # along x
const _BENCH_SEAT_H: float = 0.07
const _BENCH_SEAT_Y: Vector2 = Vector2(0.36, 0.50)
const _BENCH_BACK_H: Vector2 = Vector2(0.30, 0.46)
const _BENCH_BACK_T: float = 0.06                     # backrest thickness, along x
const _BENCH_LEG_R: float = 0.045
const _BENCH_LEG_SIDES: int = 5
## Leg inset from each end of the seat, as a fraction of the seat length.
const _BENCH_LEG_INSET: float = 0.18

## Sign: a post under a blank rectangular board. NO text and no texture --
## the board is a silhouette, nothing on it is ever meant to be read, so
## there is no legibility claim to defend at any camera distance.
const _SIGN_POST_R: float = 0.05
const _SIGN_POST_SIDES: int = 5
const _SIGN_POST_H: Vector2 = Vector2(1.05, 1.55)
const _SIGN_BOARD_W: Vector2 = Vector2(0.52, 0.78)   # along x when unyawed
const _SIGN_BOARD_H: Vector2 = Vector2(0.34, 0.52)
const _SIGN_BOARD_T: float = 0.05
## How far the board's centre sits below the top of the post.
const _SIGN_BOARD_DROP: float = 0.10

## Stump: see _STUMP_MODEL_PATH / _STUMP_MODEL_HEIGHT above. The
## cylinder+dome pair it replaced existed to avoid reading as "a broken
## tree"; the imported mesh keeps that separation for a better reason --
## it has the flared roots and the cut face a stump actually has, which is
## what the recon judged it on (section 11).

## Bush: a cluster of three squashed low-facet spheres, each offset from
## the cluster centre. Rounder and shorter than a rock, and unlike the
## rock it is never a single mass -- the lumpy outline is what separates
## the two at the distance they are seen from.
const _BUSH_BLOBS: int = 3
const _BUSH_RADIUS: Vector2 = Vector2(0.20, 0.36)
const _BUSH_FLATNESS: Vector2 = Vector2(0.62, 0.95)
const _BUSH_SIDES: int = 6
const _BUSH_RINGS: int = 2
## How far a blob may sit from the cluster centre, as a fraction of its
## own radius. Under 1.0 so the blobs always overlap into one clump
## rather than reading as three separate pebbles.
const _BUSH_SPREAD: float = 0.75
## Fraction of a blob's half-height left above the ground, same bedding
## idea as _ROCK_SINK.
const _BUSH_SINK: float = 0.78

## See docs/MESHY_SPEC.md section 8.2 for the measured contrast table.
##
## RE-HUED, NOT RE-ORDERED, by the permanent-swamp batch. The six values
## below keep the VALUE LADDER 8.2 swept -- same order, same rough
## spacing, so no pair in its table changes rank -- and move the hue into
## the swamp: near-black greens at the bottom, muddy olive at the top,
## nothing warm or saturated left. What that ladder was FOR is unchanged
## too: these are read against sky and haze, not against the track, and
## the backdrop is no longer the two BRIGHTEST surfaces in the scene but
## the two darkest, so the ladder now buys separation between the six
## kinds rather than against the sky behind them.
## _TREE_TRUNK_COLOR is now the WHOLE tree, not a trunk under a canopy:
## the imported mesh is a bare winter tree, so there is no foliage to give
## a second albedo to and _TREE_CANOPY_COLOR (0.14, 0.20, 0.15) is gone
## with the cone that carried it. That REMOVES a value from 8.2's swept
## set without adding one, so no pair in its table needs re-measuring --
## and it retires the worst pair the table shipped with (canopy-vs-trunk
## at 1.29:1, two values on the same object that were the hardest of the
## six to tell apart).
static var _TREE_TRUNK_COLOR: Color = _PALETTE.prop_tree_trunk_color
static var _ROCK_COLOR: Color = _PALETTE.prop_rock_color

## The four kinds added in the second props pass. Their luminances were
## picked by SWEEPING the scene's occupied luminance line, not by eye --
## see 8.2's extended table for the full measured grid and for the two
## limitations it records. In short: the dark band that gives the best
## contrast against the backdrop (sky and hills) already held all three
## kinds above, so these four are spread UP the line instead. That buys
## clean separation between the six kinds (worst pair 1.48:1, better than
## the 1.29:1 the canopy/trunk pair already ships with) and costs some
## backdrop contrast on the two mid-value kinds, which is the trade 8.2
## already makes explicit rather than a new compromise.
static var _BUSH_COLOR: Color = _PALETTE.prop_bush_color
static var _STUMP_COLOR: Color = _PALETTE.prop_stump_color
static var _BENCH_COLOR: Color = _PALETTE.prop_bench_color
static var _SIGN_COLOR: Color = _PALETTE.prop_sign_color

## Every mesh key a slot carries, in one place. _hide_all_props() and
## nearest_prop_edge_x() both walk this rather than each repeating a
## literal list -- the keep-out probe measures whatever this array names,
## so a kind added here cannot be silently left out of the check that
## keeps props off the play area.
const _PROP_MESH_KEYS: Array[String] = [
	"tree_model", "rock",
	"bench_seat", "bench_back", "bench_leg_a", "bench_leg_b",
	"sign_post", "sign_board",
	"stump_model",
	"bush_a", "bush_b", "bush_c",
]

## Which mesh keys each kind switches on. Kept beside _PROP_KINDS so the
## two cannot drift.
const _PROP_KIND_MESHES: Dictionary = {
	"tree": ["tree_model"],
	"rock": ["rock"],
	"bench": ["bench_seat", "bench_back", "bench_leg_a", "bench_leg_b"],
	"sign": ["sign_post", "sign_board"],
	"stump": ["stump_model"],
	"bush": ["bush_a", "bush_b", "bush_c"],
}

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
	# One material per colour, shared by every slot and every part of a
	# kind: a bench's seat, back and both legs are one object to the eye,
	# so they are one albedo, and sharing the resource keeps the material
	# count flat as kinds are added.
	var trunk_material := _unshaded(_TREE_TRUNK_COLOR)
	var rock_material := _unshaded(_ROCK_COLOR)
	var bench_material := _unshaded(_BENCH_COLOR)
	var sign_material := _unshaded(_SIGN_COLOR)
	var stump_material := _unshaded(_STUMP_COLOR)
	var bush_material := _unshaded(_BUSH_COLOR)

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
			# The tree is an imported mesh, so there is no tessellation to
			# set and nothing to size here: every instance points at the
			# same shared resource and is resized by its own scale at
			# placement. The albedo still comes from the GDScript constant
			# rather than the .glb's own baseColorFactor -- the two agree
			# (the decimator bakes this exact value in), but 8.2's swept
			# palette has to have ONE home, and a binary is the wrong place
			# for a number a contrast sweep is allowed to retune.
			var tree_model := _build_prop_mesh(
				_shared_model(_BARE_TREE_MODEL_PATH), trunk_material, "PropTree" + label)

			var rock_mesh := SphereMesh.new()
			rock_mesh.radial_segments = _ROCK_SIDES
			rock_mesh.rings = _ROCK_RINGS
			var rock := _build_prop_mesh(rock_mesh, rock_material, "PropRock" + label)

			# --- bench: two boxes on two capless cylinders ---
			var seat := _build_prop_mesh(BoxMesh.new(), bench_material, "PropBenchSeat" + label)
			var back := _build_prop_mesh(BoxMesh.new(), bench_material, "PropBenchBack" + label)
			# Legs: both caps hidden, the bottom by the ground and the top
			# by the seat sitting on them -- same reasoning as the trunk's.
			var leg_a := _build_prop_mesh(
				_capless_cylinder(_BENCH_LEG_R, _BENCH_LEG_SIDES), bench_material, "PropBenchLegA" + label)
			var leg_b := _build_prop_mesh(
				_capless_cylinder(_BENCH_LEG_R, _BENCH_LEG_SIDES), bench_material, "PropBenchLegB" + label)

			# --- sign: capless post under a blank board ---
			var post := _build_prop_mesh(
				_capless_cylinder(_SIGN_POST_R, _SIGN_POST_SIDES), sign_material, "PropSignPost" + label)
			var board := _build_prop_mesh(BoxMesh.new(), sign_material, "PropSignBoard" + label)

			# --- stump: imported mesh, same treatment as the tree ---
			var stump_model := _build_prop_mesh(
				_shared_model(_STUMP_MODEL_PATH), stump_material, "PropStump" + label)

			# --- bush: a clump of squashed spheres ---
			var blobs: Array[MeshInstance3D] = []
			for b in _BUSH_BLOBS:
				var blob_mesh := SphereMesh.new()
				blob_mesh.radial_segments = _BUSH_SIDES
				blob_mesh.rings = _BUSH_RINGS
				blobs.append(_build_prop_mesh(
					blob_mesh, bush_material, "PropBushBlob%d%s" % [b, label]))

			_prop_slots.append({
				"side": side,
				"tree_model": tree_model,
				"rock": rock,
				"bench_seat": seat,
				"bench_back": back,
				"bench_leg_a": leg_a,
				"bench_leg_b": leg_b,
				"sign_post": post,
				"sign_board": board,
				"stump_model": stump_model,
				"bush_a": blobs[0],
				"bush_b": blobs[1],
				"bush_c": blobs[2],
			})
	_hide_all_props()

## A cylinder with both caps off, at a fixed radius. Height is written per
## placement; radius never varies for the parts that use this, so it is set
## once here for the same reason tessellation is -- a mesh left at Godot's
## default sits on a 64-segment buffer from _ready() onward whether or not
## its slot ever draws.
func _capless_cylinder(radius: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = sides
	mesh.rings = 0
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	return mesh

## One prop mesh instance, added to this segment and hidden. `cast_shadow`
## is off for the same reason Decor.gd switches it off on the hills and
## _build_lane_curbs does on the curbs: this is decor sitting outside the
## readable play area, and it has no business adding to the one
## DirectionalLight3D's shadow pass.
## Takes `Mesh`, not `PrimitiveMesh`: since this batch two kinds draw an
## imported ArrayMesh instead of a generated primitive. Widening the
## parameter rather than adding a near-identical second builder keeps ONE
## place that decides a prop's shadow setting and starting visibility --
## the two properties a prop added later is most likely to be given
## wrongly by copying the wrong sibling.
func _build_prop_mesh(mesh: Mesh, material: StandardMaterial3D, node_name: String) -> MeshInstance3D:
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

## Cache of imported prop meshes, keyed by path. STATIC, so the segment
## pool's dozen instances and both of a segment's sides all point at ONE
## Mesh per subject instead of one per MeshInstance3D. Safe only because
## nothing ever writes to these -- an imported mesh is resized by scaling
## its instance, unlike the primitives beside it whose radius and height
## are rewritten on every placement.
static var _model_cache: Dictionary = {}

## The mesh inside a .glb, or null if it has none.
##
## Read off the imported PackedScene's SceneState rather than by
## instantiating it: the mesh is a property value in the packed data, so
## no node has to be built to reach it and none has to be freed
## afterwards. Instantiating worked too, but freeing a MeshInstance3D
## under the headless dummy renderer emits `Parameter "m" is null` on
## stderr -- harmless in itself, but this project compares probe output
## BYTE FOR BYTE, so a line of engine noise on a path every probe walks is
## a real cost. It also keeps the no-allocation claim literal.
##
## Runs from _ready(), never per frame: the first segment built pays the
## load, every segment after it is a dictionary hit.
##
## Assumes the model's own glTF node transform is identity, which is true
## by construction for anything scripts/dev/decimate_decor.py emits and was
## verified on both of this batch's assets. A model from another pipeline
## carrying a node-level rotation or offset would need it folded in here --
## the scale and ground contact in _place_model are measured from the mesh
## AABB alone.
static func _shared_model(path: String) -> Mesh:
	if _model_cache.has(path):
		return _model_cache[path]
	var mesh: Mesh = null
	var scene := load(path) as PackedScene
	if scene == null:
		# Loud, not silent: a missing prop model is a build/export defect
		# (see MESHY_SPEC 7's export_filter note), and a prop that quietly
		# draws nothing looks exactly like a tile that rolled empty.
		push_error("TrackSegment: could not load prop model %s" % path)
	else:
		mesh = _packed_mesh(scene)
		if mesh == null:
			push_error("TrackSegment: no MeshInstance3D mesh inside %s" % path)
	_model_cache[path] = mesh
	return mesh

## First MeshInstance3D's `mesh` property in a packed scene, without
## instantiating it.
static func _packed_mesh(scene: PackedScene) -> Mesh:
	var state := scene.get_state()
	for node in state.get_node_count():
		if state.get_node_type(node) != "MeshInstance3D":
			continue
		for property in state.get_node_property_count(node):
			if state.get_node_property_name(node, property) == "mesh":
				var value: Mesh = state.get_node_property_value(node, property)
				if value != null:
					return value
	return null

func _hide_all_props() -> void:
	for slot in _prop_slots:
		for key in _PROP_MESH_KEYS:
			slot[key].visible = false

## Picks a kind for a populated slot from _PROP_KIND_WEIGHTS. Exactly ONE
## draw whatever the outcome, so adding a kind never changes how many
## numbers a placement consumes -- which is what lets the weights be
## retuned without re-sequencing the rest of a segment's decor.
func _roll_prop_kind() -> String:
	var roll := _prop_rng.randf()
	var cumulative := 0.0
	for i in _PROP_KINDS.size():
		cumulative += _PROP_KIND_WEIGHTS[i]
		if roll < cumulative:
			return _PROP_KINDS[i]
	# Float error only; the weights sum to 1.
	return _PROP_KINDS[_PROP_KINDS.size() - 1]

## Re-rolls every prop slot: present or not, tree or rock, and where.
## Called from populate(), i.e. once at the initial fill and once per
## recycle -- never per frame.
func _place_trackside_props() -> void:
	for slot in _prop_slots:
		var side: float = slot["side"]
		var show_prop := _prop_rng.randf() < _PROP_PRESENCE_CHANCE
		# Hide everything first, then switch on only the chosen kind's
		# meshes. Clearing unconditionally is what makes a slot that was a
		# bench last tile and is a bush this one leave nothing behind.
		for key in _PROP_MESH_KEYS:
			slot[key].visible = false
		if not show_prop:
			continue
		var kind := _roll_prop_kind()
		for key in _PROP_KIND_MESHES[kind]:
			slot[key].visible = true
		var z := _prop_rng.randf_range(-_PROP_Z_HALF_RANGE, _PROP_Z_HALF_RANGE)
		match kind:
			"tree": _place_tree(slot, side, z)
			"rock": _place_rock(slot, side, z)
			"bench": _place_bench(slot, side, z)
			"sign": _place_sign(slot, side, z)
			"stump": _place_stump(slot, side, z)
			"bush": _place_bush(slot, side, z)

## Places one imported-mesh prop: scaled to a rolled height, freely yawed,
## its own base sitting on the ground, and pushed out past the keep-out by
## its own silhouette.
##
## DRAWS EXACTLY FIVE VALUES FROM _prop_rng, ON EVERY PATH, and that count
## is load-bearing rather than incidental. Both placements it replaced
## drew five as well (the tree: trunk radius, trunk height, canopy radius,
## canopy height, then _prop_x's spread; the stump: radius, height, dome
## rise, spread, yaw). Keeping the count identical means the decor stream
## is consumed exactly as before, so EVERY OTHER prop in the run -- every
## rock, bench, sign and bush, and every tree and stump's position and
## size -- lands precisely where it did before this swap. That is what
## makes this batch a change of two silhouettes rather than a reshuffle of
## the whole roadside, and it is what lets the F10/F11 contrast probes'
## backgrounds be reasoned about at all (see MESHY_SPEC 11).
##
## The two levers the four pre-spread draws feed are described on
## _MODEL_PROP_GIRTH: with one shared mesh per kind, proportion and yaw
## are all that stop four instances on screen reading as four copies.
func _place_model(instance: MeshInstance3D, side: float, z: float, height_range: Vector2) -> void:
	var height := _prop_rng.randf_range(height_range.x, height_range.y)
	var girth := _prop_rng.randf_range(_MODEL_PROP_GIRTH.x, _MODEL_PROP_GIRTH.y)
	var z_stretch := _prop_rng.randf_range(_MODEL_PROP_Z_STRETCH.x, _MODEL_PROP_Z_STRETCH.y)
	var yaw := _prop_rng.randf_range(0.0, TAU)

	# Mesh-local and unscaled, and -- unlike every primitive beside it --
	# NOT centred on the origin: a .glb keeps whatever origin it was
	# authored around, so both the keep-out and the ground contact below
	# work from the box's real corners rather than from half-sizes.
	var box := instance.get_aabb()
	var usable := box.size.y > 0.0
	var scale_y := (height / box.size.y) if usable else 0.0
	var scale_x := scale_y * girth
	var scale_z := scale_y * girth * z_stretch

	# Yaw is free, so the keep-out has to clear the widest silhouette the
	# prop can EVER present, at any angle: the bounding circle about the
	# instance's own origin, taken over the scaled box's four horizontal
	# corners. Same bound and same reasoning as the rock's longest
	# semi-axis -- an exact per-angle extent (_yawed_half_x) is only worth
	# computing for the two kinds whose yaw is small enough to keep it
	# tight.
	var half_width := 0.0
	for cx in [box.position.x, box.position.x + box.size.x]:
		for cz in [box.position.z, box.position.z + box.size.z]:
			half_width = maxf(half_width, Vector2(cx * scale_x, cz * scale_z).length())

	# Called unconditionally, and this is the fifth draw. A model that
	# failed to load must not consume a different number of values from
	# the others, or one missing file would re-sequence the decor for
	# every prop placed after it.
	var x := _prop_x(side, half_width)
	if not usable:
		# _shared_model has already pushed the error; draw nothing rather
		# than park an empty instance at an arbitrary spot.
		instance.visible = false
		return

	instance.scale = Vector3(scale_x, scale_y, scale_z)
	instance.rotation = Vector3(0.0, yaw, 0.0)
	# The mesh's own BASE meets the ground, not its origin.
	instance.position = Vector3(x, _ground_top_y() - box.position.y * scale_y, z)

func _place_tree(slot: Dictionary, side: float, z: float) -> void:
	_place_model(slot["tree_model"], side, z, _BARE_TREE_HEIGHT)

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

## The two man-made kinds get a SMALL yaw rather than the rock's free spin:
## a bench or a sign beside a path reads as aligned with it, and a fully
## random one reads as dropped there. Small enough that the exact rotated
## half-width below stays tight instead of degenerating to the bounding
## circle a free spin would force.
const _PROP_YAW_MAX: float = 0.21 # radians, ~12 degrees

## Half the X extent of a box of `depth` (x) by `length` (z) yawed by
## `yaw`. Exact, not a bound with slack: this is the number the keep-out
## is built from, so it has to be the real silhouette edge at the rotation
## actually used -- the same discipline the rock's longest-semi-axis
## follows.
func _yawed_half_x(depth: float, length: float, yaw: float) -> float:
	return depth * 0.5 * absf(cos(yaw)) + length * 0.5 * absf(sin(yaw))

## A part's offset from its prop's centre, yawed about Y with it.
func _yawed_offset(offset: Vector3, yaw: float) -> Vector3:
	var c := cos(yaw)
	var s := sin(yaw)
	return Vector3(offset.x * c + offset.z * s, offset.y, -offset.x * s + offset.z * c)

func _place_bench(slot: Dictionary, side: float, z: float) -> void:
	var length := _prop_rng.randf_range(_BENCH_LENGTH.x, _BENCH_LENGTH.y)
	var depth := _prop_rng.randf_range(_BENCH_DEPTH.x, _BENCH_DEPTH.y)
	var seat_y := _prop_rng.randf_range(_BENCH_SEAT_Y.x, _BENCH_SEAT_Y.y)
	var back_h := _prop_rng.randf_range(_BENCH_BACK_H.x, _BENCH_BACK_H.y)
	var yaw := _prop_rng.randf_range(-_PROP_YAW_MAX, _PROP_YAW_MAX)

	var seat: MeshInstance3D = slot["bench_seat"]
	var back: MeshInstance3D = slot["bench_back"]
	var leg_a: MeshInstance3D = slot["bench_leg_a"]
	var leg_b: MeshInstance3D = slot["bench_leg_b"]

	(seat.mesh as BoxMesh).size = Vector3(depth, _BENCH_SEAT_H, length)
	(back.mesh as BoxMesh).size = Vector3(_BENCH_BACK_T, back_h, length)
	var leg_h := maxf(0.05, seat_y - _BENCH_SEAT_H * 0.5)
	(leg_a.mesh as CylinderMesh).height = leg_h
	(leg_b.mesh as CylinderMesh).height = leg_h

	# The seat is the widest part in x, so it -- not the backrest, which is
	# thinner and sits inside the seat's footprint -- sets the keep-out.
	var half_x := _yawed_half_x(depth, length, yaw)
	var x := _prop_x(side, half_x)
	var ground_y := _ground_top_y()
	var centre := Vector3(x, ground_y, z)

	# Backrest on the far side from the track, so the bench faces it.
	var back_off := side * (depth * 0.5 - _BENCH_BACK_T * 0.5)
	var leg_z := length * (0.5 - _BENCH_LEG_INSET)
	_put(seat, centre, Vector3(0.0, seat_y, 0.0), yaw)
	_put(back, centre, Vector3(back_off, seat_y + _BENCH_SEAT_H * 0.5 + back_h * 0.5, 0.0), yaw)
	_put(leg_a, centre, Vector3(0.0, leg_h * 0.5, leg_z), yaw)
	_put(leg_b, centre, Vector3(0.0, leg_h * 0.5, -leg_z), yaw)

func _place_sign(slot: Dictionary, side: float, z: float) -> void:
	var post_h := _prop_rng.randf_range(_SIGN_POST_H.x, _SIGN_POST_H.y)
	var board_w := _prop_rng.randf_range(_SIGN_BOARD_W.x, _SIGN_BOARD_W.y)
	var board_h := _prop_rng.randf_range(_SIGN_BOARD_H.x, _SIGN_BOARD_H.y)
	var yaw := _prop_rng.randf_range(-_PROP_YAW_MAX, _PROP_YAW_MAX)

	var post: MeshInstance3D = slot["sign_post"]
	var board: MeshInstance3D = slot["sign_board"]
	(post.mesh as CylinderMesh).height = post_h
	# Blank board. No texture, no albedo variation, nothing to read -- the
	# board is a shape, and that is the whole of what it is.
	(board.mesh as BoxMesh).size = Vector3(board_w, board_h, _SIGN_BOARD_T)

	# Unyawed the board's width lies along x, so it is the wide part here;
	# the post is thinner than the board at every rotation this uses.
	var half_x := _yawed_half_x(board_w, _SIGN_BOARD_T, yaw)
	var x := _prop_x(side, half_x)
	var ground_y := _ground_top_y()
	var centre := Vector3(x, ground_y, z)
	_put(post, centre, Vector3(0.0, post_h * 0.5, 0.0), yaw)
	_put(board, centre, Vector3(0.0, post_h - _SIGN_BOARD_DROP - board_h * 0.5, 0.0), yaw)

func _place_stump(slot: Dictionary, side: float, z: float) -> void:
	_place_model(slot["stump_model"], side, z, _STUMP_MODEL_HEIGHT)

func _place_bush(slot: Dictionary, side: float, z: float) -> void:
	# Roll every blob FIRST, so the cluster's true half-width is known
	# before the keep-out places it -- the same order the tree uses, where
	# the canopy is rolled before _prop_x is asked for a clearance.
	var radii: Array[float] = []
	var half_heights: Array[float] = []
	var offsets: Array[Vector3] = []
	var half_x := 0.0
	for i in _BUSH_BLOBS:
		var r := _prop_rng.randf_range(_BUSH_RADIUS.x, _BUSH_RADIUS.y)
		var flatness := _prop_rng.randf_range(_BUSH_FLATNESS.x, _BUSH_FLATNESS.y)
		var angle := _prop_rng.randf_range(0.0, TAU)
		var reach := _prop_rng.randf_range(0.0, r * _BUSH_SPREAD)
		radii.append(r)
		half_heights.append(r * flatness)
		offsets.append(Vector3(cos(angle) * reach, 0.0, sin(angle) * reach))
		# The cluster's silhouette edge is the furthest blob's own edge,
		# not the cluster centre -- so the offset is added to the radius
		# BEFORE the keep-out sees it, exactly as the tree adds its canopy
		# radius rather than its trunk's.
		half_x = maxf(half_x, absf(offsets[i].x) + r)

	var x := _prop_x(side, half_x)
	var ground_y := _ground_top_y()
	var keys := ["bush_a", "bush_b", "bush_c"]
	for i in _BUSH_BLOBS:
		var blob: MeshInstance3D = slot[keys[i]]
		var mesh := blob.mesh as SphereMesh
		mesh.radius = radii[i]
		mesh.height = half_heights[i] * 2.0
		# Bedded into the ground on the same convention as the rock:
		# _BUSH_SINK of the half-height stays above the plane.
		blob.position = Vector3(
			x + offsets[i].x,
			ground_y + half_heights[i] * _BUSH_SINK,
			z + offsets[i].z,
		)
		blob.rotation = Vector3.ZERO

## Places one part of a multi-part prop: its offset from the prop's centre,
## yawed with the prop, plus the part's own matching rotation.
func _put(instance: MeshInstance3D, centre: Vector3, offset: Vector3, yaw: float) -> void:
	instance.position = centre + _yawed_offset(offset, yaw)
	instance.rotation = Vector3(0.0, yaw, 0.0)
	instance.scale = Vector3.ONE

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
		for key in _PROP_MESH_KEYS:
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
