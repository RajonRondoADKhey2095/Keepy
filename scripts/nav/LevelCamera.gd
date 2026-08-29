extends Camera3D
class_name LevelCamera
## Follows the walker at a fixed 3/4 offset, and follows the LEVEL up.
##
## =====================================================================
## THE INTERPOLATED OPTION, AND WHY IT COSTS NOTHING
##
## The design doc weighed a hard cut against an interpolated one. This is
## the interpolated one, and it needed no new machinery: the follow is
## already an exponential lerp, so handing it a higher target is the whole
## implementation. A cut would have needed code to suppress the lerp for
## one frame -- more work, for a jump that reads as a glitch.
##
## =====================================================================
## ⚠️ IT FOLLOWS plane_y, NEVER THE BODY'S OWN Y
##
## HubCamera throws the target's Y away on purpose: a camera re-aimed every
## frame at a target whose height oscillates 0.6 units per hop pitches the
## whole horizon up and down in time with the hops, which is far more
## noticeable than the character is.
##
## That argument is still entirely valid, so this does not simply stop
## discarding Y -- it substitutes the LEVEL'S floor for it. A level is
## stable; an arc is not. The camera therefore rises once per crossing and
## is perfectly still during every hop, which is the behaviour HubCamera
## has today plus the one thing it cannot express.
##
## HubCamera itself is NOT modified: that is a hub file, and this batch
## touches none.
##
## =====================================================================
## ⚠️ IT FADES WHATEVER STANDS BETWEEN IT AND THE TARGET
##
## A camera at a fixed 3/4 offset behind a body on a MULTI-STOREY world
## eventually has a storey in the way. Measured on the shipped test world
## rather than guessed: with this OFFSET, the upper slab covers the body
## for the whole last stretch of the approach to the link -- every lower
## z from -7 to the link foot at -9, at every lateral position across the
## slab (x -4 to +4), entering the slab at 52% of the way down the ray.
## The post joins it at the foot itself. That is not an edge case; it is
## the approach to the one transition the level has, so the player loses
## sight of himself exactly where he most needs to aim.
##
## HubCamera has no such logic and needs none: the plateau is
## single-altitude by construction, so nothing is ever ABOVE the walker
## to get in the way. It is NOT modified.
##
## =====================================================================
## WHY AN AABB TEST AND NOT A RAYCAST
##
## Godot's intersect_ray only reports CollisionObject3D. This navigation
## core has none -- it writes transforms, and the plateau it borrows its
## idiom from has none either (grep: zero intersect_ray / RayCast3D /
## PhysicsDirectSpaceState in the whole repository). Adding StaticBody3D
## to level geometry to make a ray hit it would introduce this project's
## first navigation collider: a bigger change than the fade it serves, a
## new class of failure, and a physics tick a probe would then have to
## pump. A segment-vs-AABB slab test is exact for a box occluder,
## deterministic, and gateable without a physics server.
##
## The AABB is the node's own, transformed into world space. For a
## rotated occluder that encloses more than the mesh does, so the fade
## engages slightly EARLY rather than slightly late -- the safe direction
## for a mechanism whose whole job is not to hide the player.
##
## =====================================================================
## ⚠️ THE ALPHA IS THE RISK THIS BATCH CANNOT CLOSE
##
## Transparency near the water already went GREEN in this sandbox
## (llvmpipe/opengl3 under xvfb) and BROKE on device (Safari iOS, WebGL2)
## -- the waterline shader wrote ALPHA, which moves a material into the
## transparent pass and costs it its depth write, and with a closed body
## the far face repainted the near one at some azimuths and not others.
## This is the same class of risk. Three things are done about it, and
## none of them is a proof:
##
##   * transparency is switched to ALPHA only WHILE a fade is on, and
##     switched back to DISABLED the moment the alpha returns to 1. An
##     occluder that nothing is hiding behind is an ordinary opaque,
##     depth-writing surface, so the risky state lasts as long as the
##     fade and no longer.
##   * cull_mode is left ALONE. The default is BACK, and back-face
##     culling on a closed box is precisely what the waterline defect
##     needed disabled to appear. This code never sets cull_disabled.
##   * an alpha below 1 with transparency DISABLED is silently IGNORED --
##     the lake already paid for that one -- so the two are written
##     together, never apart.
##
## What none of that establishes is the device. Only Mathieu's phone can
## say whether the fade reads cleanly at a low azimuth; a green probe
## here is necessary and NOT sufficient.

const OFFSET: Vector3 = Vector3(0.0, 7.6, 8.9)
const FOLLOW_LAMBDA: float = 5.0

## Nodes in THIS group, and nothing else, are candidates to be faded. The
## alternative -- fade whatever the segment happens to cross -- would take
## the walker's own body, a collectible, a future NPC, anything that
## drifted between the two points for a frame. Level geometry opts in.
const OCCLUDER_GROUP: StringName = &"level_occluder"

## Where on the body the camera is actually trying to see. The ray must end
## at the mass the player looks at, not at his feet: a floor slab's top face
## IS his feet, so a ray to the feet grazes every floor he stands on.
##
## 0.65 is the shipped walker Body's own local y in LevelNavTest.tscn (a
## 1.3-tall capsule sitting on the plane, so its centre is half its height
## up). It is a const rather than a read of the walker's node structure so
## that this camera stays usable by a level whose body is built some other
## way -- and LevelNavProbe asserts the two still agree, so the copy cannot
## drift in silence.
const TARGET_EYE_Y: float = 0.65

## What an occluding surface fades to. Low enough that a body behind it
## reads at a glance, high enough that the geometry does not vanish -- a
## storey that disappears entirely is a different bug from a storey that
## hides you.
const OCCLUDED_ALPHA: float = 0.25

## Exponential constant for the fade, same frame-rate-independent form as
## the follow above.
const FADE_LAMBDA: float = 9.0

## Seconds between occlusion TESTS. The fade itself still runs every frame,
## so this throttles the query and not the smoothness: at 12.5 Hz the test
## is six times cheaper than per-frame and its latency stays well under the
## fade's own settle time, which is what makes the throttle invisible.
const TEST_INTERVAL_S: float = 0.08

## Anything nearer the camera than this is not treated as an occluder. The
## camera sits 11.6 units from the body; a surface a few centimetres off
## the lens is a near-plane artefact, not a storey in the way.
const NEAR_MARGIN: float = 0.05

@export var target_path: NodePath
@export var controller_path: NodePath

var target: Node3D = null
var controller: LevelController = null

## instance_id -> true for every occluder the last test found in the way.
## Keyed by id rather than held as a parallel array of nodes so a freed
## occluder drops out instead of becoming a dangling entry -- the parallel
## bookkeeping this repository has already been bitten by.
var _blocking: Dictionary = {}
var _test_clock: float = 0.0

func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	controller = get_node_or_null(controller_path) as LevelController
	if target == null:
		push_error("LevelCamera: target_path does not resolve to a Node3D.")
	else:
		global_position = _wanted()

func _process(delta: float) -> void:
	if target == null:
		return
	var weight: float = 1.0 - exp(-FOLLOW_LAMBDA * delta)
	global_position = global_position.lerp(_wanted(), weight)
	_test_clock -= delta
	if _test_clock <= 0.0:
		_test_clock = TEST_INTERVAL_S
		refresh_occlusion()
	_advance_fades(delta)

func _wanted() -> Vector3:
	var floor_y: float = 0.0 if controller == null else controller.ground_y()
	var ground := Vector3(target.global_position.x, floor_y, target.global_position.z)
	return ground + OFFSET

## =====================================================================
## OCCLUSION

## Where the ray is trying to reach: the body's mass, not its feet.
func eye_point() -> Vector3:
	if target == null:
		return Vector3.ZERO
	return target.global_position + Vector3(0.0, TARGET_EYE_Y, 0.0)

## Re-runs the segment test and republishes the blocking set. Public and
## callable out of band so a probe can drive it deterministically instead
## of waiting on the throttle -- a test that has to sleep for a timer is a
## test that measures the timer.
func refresh_occlusion() -> void:
	_blocking.clear()
	if target == null or not is_inside_tree():
		return
	var from: Vector3 = global_position
	var to: Vector3 = eye_point()
	for node in get_tree().get_nodes_in_group(OCCLUDER_GROUP):
		var visual := node as VisualInstance3D
		if visual == null or not visual.is_inside_tree():
			continue
		if _segment_hits(from, to, visual.global_transform * visual.get_aabb()):
			_blocking[visual.get_instance_id()] = true

## True while this node is one of the ones being faded out.
func is_occluding(node: Node) -> bool:
	return node != null and _blocking.has(node.get_instance_id())

## Walks every occluder toward its wanted alpha. Every frame, and over the
## whole group rather than only over the blocking set -- a node that stopped
## blocking has to be walked back UP, and it is no longer in the set that
## would have told us to.
func _advance_fades(delta: float) -> void:
	if not is_inside_tree():
		return
	var weight: float = 1.0 - exp(-FADE_LAMBDA * delta)
	for node in get_tree().get_nodes_in_group(OCCLUDER_GROUP):
		var visual := node as VisualInstance3D
		if visual == null:
			continue
		var material := _own_material(visual)
		if material == null:
			continue
		var wanted: float = OCCLUDED_ALPHA if _blocking.has(visual.get_instance_id()) else 1.0
		var colour: Color = material.albedo_color
		var alpha: float = lerpf(colour.a, wanted, weight)
		# Snapped at the top end so the exponential, which only ever
		# APPROACHES its target, actually arrives -- otherwise the material
		# lives in the transparent pass for ever at alpha 0.999.
		if absf(alpha - wanted) < 0.002:
			alpha = wanted
		if is_equal_approx(alpha, colour.a):
			continue
		colour.a = alpha
		material.albedo_color = colour
		# Written together, never apart: an alpha below 1 with transparency
		# DISABLED is silently ignored, and a material left in the ALPHA
		# pass keeps paying the depth-write cost it only needs while faded.
		material.transparency = (BaseMaterial3D.TRANSPARENCY_DISABLED if alpha >= 1.0
			else BaseMaterial3D.TRANSPARENCY_ALPHA)

## The occluder's OWN material, duplicated once before anything writes to
## it. Godot binds one shared material across every instance of an imported
## mesh, so fading a shared resource fades every copy of that geometry in
## the project -- the reason FighterView duplicates before tinting, applied
## here to level geometry.
func _own_material(visual: VisualInstance3D) -> StandardMaterial3D:
	var mesh_node := visual as MeshInstance3D
	if mesh_node == null:
		return null
	if mesh_node.has_meta("level_camera_owns_material"):
		return mesh_node.material_override as StandardMaterial3D
	var source := mesh_node.material_override as StandardMaterial3D
	if source == null and mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
		source = mesh_node.mesh.surface_get_material(0) as StandardMaterial3D
	if source == null:
		# A ShaderMaterial on some future occluder, say. Nothing is
		# fabricated for it: the fade is unavailable and every write above
		# no-ops, rather than this quietly replacing the look it was given.
		return null
	var owned := source.duplicate() as StandardMaterial3D
	mesh_node.material_override = owned
	mesh_node.set_meta("level_camera_owns_material", true)
	return owned

## Segment-vs-AABB, slab method, clamped to the segment rather than run as
## an infinite ray: geometry BEHIND the camera or beyond the body is not in
## the way of anything.
func _segment_hits(from: Vector3, to: Vector3, box: AABB) -> bool:
	var direction: Vector3 = to - from
	var t_min: float = NEAR_MARGIN
	var t_max: float = 1.0
	var lo: Vector3 = box.position
	var hi: Vector3 = box.position + box.size
	for axis in 3:
		var d: float = direction[axis]
		if absf(d) < 0.000001:
			# Parallel to this slab: it can only ever be in the way if it
			# already starts inside it.
			if from[axis] < lo[axis] or from[axis] > hi[axis]:
				return false
			continue
		var inv: float = 1.0 / d
		var t_a: float = (lo[axis] - from[axis]) * inv
		var t_b: float = (hi[axis] - from[axis]) * inv
		if t_a > t_b:
			var swap: float = t_a
			t_a = t_b
			t_b = swap
		t_min = maxf(t_min, t_a)
		t_max = minf(t_max, t_b)
		if t_min > t_max:
			return false
	return true
