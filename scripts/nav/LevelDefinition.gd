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
##
## =====================================================================
## THE OPTIONAL HOLE, AND WHY IT IS MATHS AND NOT A COLLIDER
##
## HubRegion carried exactly this shape once: `in_lake_water()` subtracted a
## disc from `contains()`, and `clamp_to()` pushed a point caught inside it
## out to the rim rather than assuming where the disc sat. Mathieu's later
## decision made the hub's water walkable everywhere and retired that one
## call site -- but the TECHNIQUE it used is untouched by that decision, and
## is exactly what the cabin's magpie needs: something a tap must never be
## sent onto, on a level that otherwise stays the flat square this file's own
## header promises.
##
## A StaticBody3D was considered and is explicitly NOT this. LevelCamera's
## own header names the reason: this navigation core has zero
## PhysicsDirectSpaceState calls anywhere in the repository, on purpose, and
## a collider added here to keep a hop chain off a prop would be this
## project's FIRST navigation collider -- a bigger change than the exclusion
## it serves, a new class of failure, and a physics tick a probe would then
## have to pump. A circle subtracted from two maths functions is exact,
## deterministic, and gateable without a physics server -- which is why the
## lake used it and why this reaches for the same tool rather than a new one.
##
## ⚠️ THE HOLE STOPS A TAP FROM LANDING INSIDE IT. IT DOES NOT STEER A HOP
## CHAIN AROUND IT. Exactly like the lake before it: a walk already under way
## follows a straight line to its `_target` and consults nothing about what
## lies between here and there -- this project has zero obstacle-avoidance
## anywhere, and giving one hole a private detour a hub crossing never had
## would be a second kind of walking, not a bigger version of the first. What
## the hole actually buys is that a TAP -- the thing that CHOOSES a
## destination -- can never choose one on top of what the hole guards.

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

## The optional hole -- see the header. hole_radius <= 0.0 means none, which
## is every level except the cabin's ground floor today.
var hole_centre_x: float = 0.0
var hole_centre_z: float = 0.0
var hole_radius: float = 0.0

static func make(name: StringName, plane_y: float, half_extent: float,
		centre_x: float = 0.0, centre_z: float = 0.0) -> LevelDefinition:
	var level := LevelDefinition.new()
	level.level_name = name
	level.plane_y = plane_y
	level.half_extent = maxf(half_extent, 0.0)
	level.centre_x = centre_x
	level.centre_z = centre_z
	return level

## Cuts a circular hole into this level's walkable ground. See the header --
## this is HubRegion's retired lake technique, not a collider.
func set_hole(hole_x: float, hole_z: float, radius: float) -> void:
	hole_centre_x = hole_x
	hole_centre_z = hole_z
	hole_radius = maxf(radius, 0.0)

func has_hole() -> bool:
	return hole_radius > 0.0

## Strict less-than, to match LevelHotspot's own boundary convention: a
## point exactly ON the rim (distance == hole_radius) reads as outside, so a
## point pushed there by clamp_to() below is never immediately re-caught by
## this same test.
func _in_hole(point: Vector3) -> bool:
	if not has_hole():
		return false
	var flat := Vector2(point.x, point.z)
	var centre := Vector2(hole_centre_x, hole_centre_z)
	return flat.distance_to(centre) < hole_radius

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
##
## The hole is subtracted AFTER the square, HubRegion's own order: a point
## outside the square was never walkable regardless of the hole, so asking
## "inside the hole" first would answer a question that does not arise yet.
func contains(point: Vector3) -> bool:
	if absf(point.x - centre_x) > half_extent \
			or absf(point.z - centre_z) > half_extent:
		return false
	return not _in_hole(point)

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
##
## The square clamp runs FIRST and the hole push SECOND, HubRegion's own
## order again: a point already outside the square is pulled in before
## there is any question of a hole to push it out of. The pushed point is
## re-clamped to the square afterwards -- a hole near an edge could
## otherwise push a point back out past it, which would answer "where can
## he stand" with a point this same function had just said he could not.
func clamp_to(point: Vector3) -> Vector3:
	var squared := Vector3(
		clampf(point.x, centre_x - half_extent, centre_x + half_extent),
		plane_y,
		clampf(point.z, centre_z - half_extent, centre_z + half_extent))
	if not _in_hole(squared):
		return squared
	var flat := Vector2(squared.x, squared.z)
	var hole_centre := Vector2(hole_centre_x, hole_centre_z)
	var away := flat - hole_centre
	if away.length() < 0.0001:
		# Degenerate: the clamped point landed exactly on the hole's own
		# centre. Any direction is as good as another, so push along +X
		# rather than leave a zero vector normalize() would refuse.
		away = Vector2(1.0, 0.0)
	# Pushed a fixed margin PAST the rim, not onto it: _in_hole() is a
	# strict less-than, so landing exactly at hole_radius already reads as
	# outside, but float noise on the distance computed to get here could
	# still land a hair short. The stream's own rim margin paid for this
	# once already -- 0.001 measured short, corrected to 0.02 -- so the
	# same margin is used here rather than re-discovering it.
	var pushed := hole_centre + away.normalized() * (hole_radius + 0.02)
	return Vector3(
		clampf(pushed.x, centre_x - half_extent, centre_x + half_extent),
		plane_y,
		clampf(pushed.y, centre_z - half_extent, centre_z + half_extent))
