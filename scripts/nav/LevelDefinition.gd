extends RefCounted
class_name LevelDefinition
## ONE flat walking plane: its absolute height, its bounds, and its clamp.
##
## =====================================================================
## A LEVEL IS AS SIMPLE INSIDE AS THE HUB IS TODAY
##
## That is the whole design bet, and it is deliberate. The hub's walkable
## shape is a square plus two discs and one scalar half-extent, and it has
## stayed tractable for eight batches because it is FLAT and has ONE owner.
## Nothing here makes a level cleverer than that -- it is a square on a
## plane. The complexity of a multi-level world lives in the PASSAGE from
## one level to another (LevelTransition), not inside any one of them.
##
## =====================================================================
## flat() REPLACES Y, IT DOES NOT DISCARD IT -- the one real difference
##
## HubRegion._flat() returns Vector3(x, 0.0, z), so the hub region is
## literally two-dimensional: it cannot answer differently for two points
## that differ only in height. That is correct for one plane and fatal for
## two -- a point 4 units above this level's floor would otherwise read as
## standing on it.
##
## So flat() projects ONTO plane_y instead of onto zero. Every membership
## question is still asked in XZ, which is what keeps a level as cheap as
## the hub; what changes is that the answer is stated at a known height
## rather than at an assumed one.
##
## =====================================================================
## WHY half_extent IS PER LEVEL AND NOT A GLOBAL SCALAR
##
## HubRegion.PLATEAU_HALF_EXTENT is one float for the whole world, and that
## was right while there was one world. A cabin interior and a plateau do
## not share a size, and a single scalar describing both would be the same
## mistake the hub already paid for once, when its limit stopped being a
## number and had to become a shape.

## Name, for probes and error messages. Never used to look a level up --
## indices are the identity, because a name is a thing that gets renamed.
var level_name: StringName = &""

## ABSOLUTE world height of this level's floor. Not a delta from anything:
## a level knows where it is, and a chain of offsets is how two of them
## start disagreeing about where the ground is.
var plane_y: float = 0.0

## Half-side of the square walkable area, in world units.
var half_extent: float = 1.0

## Centre of that square in XZ. Y is IGNORED here on purpose -- plane_y is
## the one place this level's height is stated, and letting the centre
## carry a second copy of it is how the two drift.
var centre_x: float = 0.0
var centre_z: float = 0.0

static func make(name: StringName, plane_y: float, half_extent: float,
		centre_x: float = 0.0, centre_z: float = 0.0) -> LevelDefinition:
	var level := LevelDefinition.new()
	level.level_name = name
	level.plane_y = plane_y
	level.half_extent = maxf(half_extent, 0.0)
	level.centre_x = centre_x
	level.centre_z = centre_z
	return level

## The plane a tap on THIS level resolves against.
##
## Plane(UP, plane_y) and not Plane(UP, 0): HubTapInput's single hard-coded
## Plane(Vector3.UP, 0.0) is the one line that makes the hub single-storey,
## and reproducing it here would make this file a longer way of writing the
## same limitation.
func plane() -> Plane:
	return Plane(Vector3.UP, plane_y)

## `point` stated at this level's floor height. See the header: this
## REPLACES Y, it does not throw it away.
func flat(point: Vector3) -> Vector3:
	return Vector3(point.x, plane_y, point.z)

## Centre of the walkable square, at floor height.
func centre() -> Vector3:
	return Vector3(centre_x, plane_y, centre_z)

## Is this point on this level's walkable ground?
##
## Asked in XZ only, exactly as the hub asks it. The caller is responsible
## for having meant THIS level: a point 10 units above the floor and inside
## the square returns true, because "which level is he on" is
## LevelController's question and not this one's. Two files answering it
## would be two files free to disagree.
func contains(point: Vector3) -> bool:
	return absf(point.x - centre_x) <= half_extent \
		and absf(point.z - centre_z) <= half_extent

## The nearest walkable point of this level to `point`, at floor height.
##
## Pulled in rather than dropped, for HubRegion.clamp_to()'s reason: a tap
## near the horizon is a player asking to go as far as they can, and
## refusing it silently reads as the screen being broken.
##
## ⚠️ A CLAMPED DESTINATION IS NOT AN INTENTION. Everything a caller wants
## to know about what the player MEANT must be read off the unclamped aim
## instead -- see LevelController's AIM/DESTINATION block, and the measured
## funnel that made that separation necessary.
func clamp_to(point: Vector3) -> Vector3:
	return Vector3(
		clampf(point.x, centre_x - half_extent, centre_x + half_extent),
		plane_y,
		clampf(point.z, centre_z - half_extent, centre_z + half_extent))
