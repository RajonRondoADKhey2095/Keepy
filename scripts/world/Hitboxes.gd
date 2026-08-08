extends RefCounted
class_name Hitboxes
## THE collision contract: every hitbox dimension and vertical offset in
## the game, in one place, as plain numbers.
##
## WHY THIS FILE EXISTS -- the graphics phase is about to replace every
## primitive placeholder mesh in this project with a Meshy .glb. Before
## this file, a hitbox's size lived as a baked literal inside a
## CollisionShape3D sub-resource that sat in the SAME .tscn, a few lines
## away from a MeshInstance3D carrying the same numbers again. Nothing
## enforced the separation; the only thing keeping "resize the visual"
## from also meaning "resize the hitbox" was that whoever edited the
## scene happened to touch one node and not the other.
##
## That is not a property a rebalancing-by-accident can be ruled out
## from. Every hazard's fairness contract in this game is a NUMBER that
## has been measured (Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT's clearance
## window, Obstacle.RISK_MIN_SURVIVABLE_LATERAL_M's derivation from "the
## widest hazard hitbox is 1.2m wide", the DODGE top standing above
## JUMP_PEAK_HEIGHT so it can never be jumped). A silent half-metre on a
## collider moves all of them at once, and no probe in scripts/dev/ would
## report it as anything other than the game simply playing differently.
##
## SO: these constants are the source of truth, the scenes are not. Each
## owning script writes them onto its own shapes at _ready() (see
## Keepy.gd, Obstacle.gd, CollectibleBase.gd, TrackSegment.gd), so the
## values below are what the physics server actually gets, every run,
## whatever the .tscn happens to say. Swapping a mesh cannot reach them:
## a ModelSlot (scripts/world/ModelSlot.gd) never touches a
## CollisionShape3D, and scripts/dev/AssetContractAudit.gd asserts
## exactly that by installing a substitute model and re-measuring every
## collider.
##
## THESE ARE GAMEPLAY CONSTANTS, NOT ART DIRECTION. Changing one is a
## rebalancing, and belongs in a batch that re-runs the frustration /
## pursuer / strike probes. Changing a mesh to match one of them is art,
## and is free. The whole point of the split is that the second thing can
## never turn into the first by accident.
##
## LEAF BY CONSTRUCTION: this file references NO other class_name script.
## Keepy, Obstacle, CollectibleBase and TrackSegment all depend on it, and
## Godot's resource loader cannot resolve a mutual class reference between
## two class_name scripts (it fails the whole project import with
## "Parse Error: Busy" -- see the note on Obstacle._track_manager_ref,
## found empirically, not read in documentation). A constant here that
## needed TrackSegment.GLAND_Y would reintroduce exactly that cycle, which
## is why AIR_ENEMY's vertical offset is deliberately absent below and
## stays derived at runtime in Obstacle._ready().

# =====================================================================
# KEEPY -- the player capsule.
#
# The one collider in the game that is not a hazard, and the reference
# every hazard's fairness contract is written against: the "widest
# hazard half-width 0.6 plus Keepy's radius 0.5" arithmetic behind
# Obstacle.RISK_MIN_SURVIVABLE_LATERAL_M, and the "hazard half-depth 0.5
# plus Keepy's radius 0.5" behind Obstacle.RISK_PROXIMITY_Z, both read
# these two numbers. Neither of those constants can be re-derived from a
# mesh, and after this file neither has to be.
# =====================================================================

## Radius of Keepy's capsule collider.
const KEEPY_RADIUS: float = 0.5
## Full height of Keepy's capsule collider, hemispherical caps included.
const KEEPY_HEIGHT: float = 1.6
## Local Y the capsule is centred at, i.e. half its height, which puts its
## bottom exactly on the body origin. Keepy.gd's `position.y` IS the
## capsule's floor, and the jump clearance maths in that file depends on
## it (see JUMP_PEAK_HEIGHT's derivation) -- so this offset is load
## bearing, not cosmetic centring.
const KEEPY_Y: float = KEEPY_HEIGHT * 0.5

# =====================================================================
# HAZARDS -- one entry per Obstacle.Type variant. Sizes are full extents
# (Godot BoxShape3D.size / CapsuleShape3D height are full, not half).
#
# All six sit on ONE lane, 2.0m from the next (TrackSegment.LANE_X), and
# every one of them is 1.0m DEEP. That depth equality is not a
# coincidence to be tuned away from: Obstacle.RISK_PROXIMITY_Z states it
# as the reason its sampling window is exactly 1.0m, so a hazard that
# stopped being 1.0m deep would quietly change what "a graze" means.
# =====================================================================

## DODGE -- full lane height, deliberately taller than Keepy's jump arc
## (Keepy.JUMP_PEAK_HEIGHT ~= 1.558m) so that it can NEVER be cleared by
## timing, only by a lane switch. The 2.0 here is what makes that true;
## it is a rule, not a look.
const DODGE_SIZE: Vector3 = Vector3(1.2, 2.0, 1.0)
const DODGE_Y: float = 1.0

## JUMP -- the low log. Its top sits at JUMP_Y + JUMP_SIZE.y * 0.5 = 0.7m,
## which is the value Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT names and every
## other jumpable hazard reuses. The ~0.51s clearance window measured in
## Keepy.gd is a direct consequence of this number.
const JUMP_SIZE: Vector3 = Vector3(1.2, 0.7, 1.0)
const JUMP_Y: float = 0.35

## ENEMY -- narrower than the box hazards (a capsule, radius 0.3), which
## is why Obstacle.RISK_MIN_SURVIVABLE_LATERAL_M is written against the
## WIDEST hitbox rather than a per-type one: a body can pass this at a
## distance that would have hit a DODGE, and both must read as the same
## "too close to be a graze".
const ENEMY_RADIUS: float = 0.3
const ENEMY_HEIGHT: float = 0.7
const ENEMY_Y: float = 0.35

## STOMPER -- geometrically identical to JUMP (it is jumpable on exactly
## the same contract) but declared SEPARATELY on purpose.
##
## Obstacle.tscn used to point StomperShape at JUMP's own BoxShape3D
## sub-resource -- literally the same resource instance, shared. Retuning
## the JUMP log's hitbox would silently have retuned the STOMPER's too,
## in a batch that had no reason to even open the STOMPER's file. The two
## are equal today because the mechanic says they should be, not because
## they are the same object, and this pair of constants is what makes
## that difference expressible.
const STOMPER_SIZE: Vector3 = Vector3(1.2, 0.7, 1.0)
const STOMPER_Y: float = 0.35

## AIR_ENEMY -- a box, NOT the torus that draws it (the visual has a hole
## in the middle; the hitbox never did). Already fully decoupled before
## this file existed, and kept that way.
##
## NO Y CONSTANT HERE, deliberately: its height is TrackSegment.GLAND_Y,
## itself derived from Keepy.JUMP_PEAK_HEIGHT + Keepy.CAPSULE_HALF_HEIGHT,
## and is applied at runtime in Obstacle._ready() / configure(). Copying
## it here would either duplicate a derived value or force this leaf file
## to import TrackSegment -- see the LEAF BY CONSTRUCTION note above.
const AIR_ENEMY_SIZE: Vector3 = Vector3(1.2, 1.2, 1.0)

## CHARGER -- identical to DODGE's hitbox, and that is the point: its
## fairness contract is then a known quantity inherited from an already
## verified hazard rather than a newly tuned one (see Obstacle.gd's
## Type.CHARGER doc). Its VISUAL is much bigger than this (a 1.5 x 1.8 x
## 2.4m wedge, measured by ChargerShapeProbe) -- the single clearest
## existing proof in this project that a hazard's silhouette and its
## hitbox are already allowed to differ, and nothing breaks.
const CHARGER_SIZE: Vector3 = Vector3(1.2, 2.0, 1.0)
const CHARGER_Y: float = 1.0

# =====================================================================
# COLLECTIBLES -- Noisette and Gland share one radius (see
# CollectibleBase, which is where the sharing is enforced).
# =====================================================================

## Pickup radius. Deliberately MORE generous than the visible mesh
## (0.3m): a margin, so a pickup never feels precision-frustrating. That
## the two differ is the intended state, not a mesh/collider mismatch to
## be "fixed" -- and it is the second existing precedent, alongside the
## CHARGER, for a visual and a collider legitimately disagreeing.
const COLLECTIBLE_RADIUS: float = 0.4

# =====================================================================
# TRACK -- the ground Keepy stands on. is_on_floor() (and therefore the
# entire jump) depends on this collider existing at this height.
# =====================================================================

## One track tile's ground slab. 6m wide covers the three lanes at
## +-2.0m plus a margin; 20m is TrackManager's SEGMENT_LENGTH.
const GROUND_SIZE: Vector3 = Vector3(6.0, 0.4, 20.0)
## Centre of the slab, so its TOP face lands exactly on y = 0 -- the
## plane every hazard offset above is measured from.
const GROUND_Y: float = -GROUND_SIZE.y * 0.5
