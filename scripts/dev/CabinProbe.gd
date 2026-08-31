extends Node

## Gates the cabin: the tree-house on the plateau, and -- since 29 aout
## 2026 -- the door into a scene of its own.
##
## =====================================================================
## ⚠️ WHAT THIS FILE USED TO ASSERT, AND WHY THOSE PHASES ARE GONE
##
## Until this batch the cabin was a RIDE STATE. A tap walked Keepy to the
## doorstep, KeepyHopper.enter_cabin() ducked him down and HID him on the
## spot, the doorstep WITHDREW from the tap the way the boat's does, and
## any later tap fell through to the ground path and became the way out.
## Phases C, D and E gated exactly that: `is_in_cabin()`, `body.visible`,
## `tap.cabin_available`, "he came out on the spot he vanished at".
##
## Every one of those assertions is now about machinery that DOES NOT
## EXIST -- State.IN_CABIN, enter_cabin/leave_cabin, cabin_entered/
## cabin_exited and cabin_available were deleted with the mechanism. They
## are not disabled or skipped here: an assertion whose subject is gone is
## not a weaker test, it is a test of nothing, and leaving one behind is
## how a probe keeps printing OK about a feature nobody ships any more.
##
## What replaces them asserts the SAME PLAYER-VISIBLE CLAIM through the
## new mechanism: tapping the doorstep takes you inside, and coming out
## puts you back at that doorstep rather than in the middle of the
## plateau.
##
## =====================================================================
## STILL GATED RATHER THAN REPORTED, for the reason it always was: every
## way this feature fails is SILENT. An unassigned cabin_scene is swallowed
## by _build()'s push_error; a model left floating or sunk means the ground
## offset never reached the child; a doorstep derived on the wrong side of
## the trunk leaves a tap that walks Keepy round the back and never opens;
## a spawn never written leaves the way out of the cabin dropping him at
## the world origin. Not one of those raises, and every one of them looks
## like "the cabin was never installed" on a device rather than like an
## error.
##
## PHASE R is verified RED BEFORE GREEN by neutering the route call: see
## the batch report. It carries a BLIND CHECK of its own -- "no spawn is
## pending" passes for free against a probe that never entered, so the
## clean start is asserted before the write means anything.
##
## PHASE UNTOUCHED re-checks what this lot must not have moved: the boat,
## the owl, the turnstile, the seesaw, the three ladders and the three
## portals.
##
## =====================================================================
## SINCE 29 AOUT 2026, TWO MORE THINGS, AND BOTH FAIL SILENTLY
##
## PHASE M -- THE DOORSTEP HAS A MARK ON IT. The device report was that
## from out on the plateau nothing says where to tap to go in: the
## previous lot marked the ladder, the bed and the door INSIDE the cabin
## and left the way IN unmarked. A mark that is never built, is built at
## the wrong point, is built smaller than the trigger it stands for, or
## quietly stops matching the three portals beside it raises nothing at
## all -- it looks exactly like "the mark was never added".
##
## PHASE P -- THE BED CAN BE LAIN ON. Every failure here is silent too: an
## intent that clears on a pass-through landing leaves him standing beside
## the bed; a bed that does not WITHDRAW leaves a second tap re-entering a
## state he is already in and nothing able to wake him; a wake that does
## not undo the roll leaves him walking round the loft on his side.
##
## Both are verified RED BEFORE GREEN -- see the batch report for the two
## neutered calls and the exact failures they produced.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")
const INTERIOR_SCENE: PackedScene = preload("res://scenes/CabinInterior.tscn")

## The layout entry this lot ships, read back rather than duplicated so a
## future reposition cannot silently desync this probe from the thing it
## is checking.
const _EXPECTED_POSITION: Vector3 = Vector3(-17.43, 0.0, 28.18)

## The scale this entry ships at. Two scale-up lots: 1.0 -> 3.5 -> 7.0.
## The door and the built AABB both derive from it below, read here rather
## than copied twice.
##
## 7.0 is not a round number picked for tidiness -- it is what puts the
## cabin 17.6% above the tallest tree-shaped thing on the plateau (the
## spire landmark, measured at 9.4640 world units), which is the target
## the scale-up lot was given.
##
## ⚠️ THE INTERIOR SCENE DOES NOT SHARE IT, and that is deliberate rather
## than a drift: out here the number answers "how tall against the trees",
## in there it answers "how much of the frame do two storeys fill", and
## the interior settled on 11.0. Two questions, two numbers, and the probe
## reads each off the file that owns it.
const _EXPECTED_SCALE: float = 7.0

## The doorstep _build derives from that position, that scale and the
## entry's own rotation_y of 0: straight out along the open face, which is
## model +Z, by the model's own +Z half-depth SCALED plus the visitor's
## FIXED standoff -- 28.18 + (0.78078 * scale) + 0.70.
##
## Two terms and not one because the single scaled reach it replaced put
## the doorstep further from the wall the bigger the cabin got, which is
## what floated the trigger disc off the prop and onto open lawn. Written
## out here rather than computed so a change to either constant has to be
## restated deliberately.
const _EXPECTED_DOOR: Vector3 = Vector3(-17.43, 0.0,
		28.18 + 0.78078 * _EXPECTED_SCALE + 0.70)

## How far the doorstep must sit off the front wall, at ANY scale. This is
## the invariant the two-term reach exists to hold, and the number the
## stray-entry defect broke: it was 0.669 at scale 1 and 2.342 at scale
## 3.5, which is how the disc ended up standing on lawn.
const _EXPECTED_WALL_GAP: float = 0.70

var _failures: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "CABIN PROBE")
	var dl := ProbeWatchdog.deadline("CABIN PROBE")

	print("=== CABIN PROBE ===")
	print("")

	# A probe that inherited a spawn from something else would measure that
	# instead of its own, and PHASE S's clean-start check would be reading
	# whatever the run before it left behind.
	HubSpawn.clear()

	var tree := get_tree()

	# ⚠️ PARENTED TO THE WINDOW ROOT AND DECLARED THE CURRENT SCENE, and
	# those two lines are what let PHASE R drive the REAL route rather than
	# a recording stand-in.
	#
	# change_scene_to_file frees whatever current_scene points at. Left
	# alone that is THIS PROBE -- so the first honest end-to-end entry test
	# deleted the probe mid-phase and every assertion after it read a null
	# tree (`Parameter "data.tree" is null`, PHASE R and PHASE S both lost).
	#
	# ⚠️ AND set_current_scene REFUSES A NODE THAT IS NOT ROOT'S OWN CHILD,
	# silently as far as the probe is concerned: it pushes an engine error
	# and leaves current_scene alone, so a hub added with add_child() here
	# still left the probe as the thing the router would delete. Measured
	# too -- "Condition p_scene->get_parent() != root is true", followed by
	# the same phase failing a different way.
	#
	# Pointing it at the hub is not a fiction: the hub IS the scene under
	# test, and replacing it is precisely the router's job.
	# ⚠️ ONE FRAME FIRST, and it is not superstition: root is still setting
	# up its own children while this _ready() runs, so add_child() on it
	# fails outright -- "Parent node is busy setting up children" -- and the
	# probe then measured an EMPTY plateau, reporting zero cabins, zero
	# portals and zero boats as if the lot had deleted the whole hub.
	await tree.process_frame
	var hub: Node = HUB_SCENE.instantiate()
	tree.root.add_child(hub)
	tree.current_scene = hub
	await tree.process_frame
	await tree.process_frame

	var world: Node3D = hub.get_node("WorldViewport/SubViewport/World") as Node3D
	var props: HubBuilder = world.get_node("Props") as HubBuilder
	var keepy: KeepyHopper = world.get_node("Keepy") as KeepyHopper
	var tap: HubTapInput = hub.get_node("TapInput") as HubTapInput
	var camera: Camera3D = world.get_node("Camera3D") as Camera3D

	_phase_a_presence(props)
	dl.abort_if_exceeded()
	_phase_b_geometry(props)
	dl.abort_if_exceeded()
	_phase_g_gone(keepy, tap)
	dl.abort_if_exceeded()
	await _phase_i_interior()
	dl.abort_if_exceeded()
	await _phase_t_no_stray_entry(hub, props, keepy, tap, camera)
	dl.abort_if_exceeded()
	await _phase_f_no_funnel(hub, props, keepy, tap, camera)
	dl.abort_if_exceeded()
	_phase_m_doorstep_mark(hub, props)
	dl.abort_if_exceeded()
	_phase_v_cutaway_magpie(props)
	dl.abort_if_exceeded()
	_phase_untouched(props)
	dl.abort_if_exceeded()
	await _phase_s_spawn(tree)
	dl.abort_if_exceeded()
	# LAST, because it ROUTES: it replaces the scene the hub is standing
	# in, so every phase that needs the plateau has to have run already.
	await _phase_r_route(tree, hub, props, keepy)
	dl.abort_if_exceeded()
	# AFTER the route, and it has to be: it drives the door for real, so it
	# ends in a second scene change. Nothing may follow it.
	await _phase_z_first_tap(tree)
	dl.abort_if_exceeded()

	print("")
	print("--- %d failure(s) ---" % _failures)
	# Off the CAPTURED tree, never off get_tree(): PHASE R hands the hub to
	# the router, and a probe that has just watched its own subtree be
	# replaced may no longer be able to ask for one.
	tree.quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("  OK    %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s" % label)

func _phase_a_presence(props: HubBuilder) -> void:
	print("--- PHASE A: the prop was built ---")
	var cabins: Array[Dictionary] = props.cabins()
	_check(cabins.size() == 1, "exactly one cabin is registered (%d)" % cabins.size())
	if cabins.is_empty():
		return
	var entry: Dictionary = cabins[0]
	var root: Node3D = entry.get("root")
	_check(root != null and is_instance_valid(root), "the cabin root is a live node")
	if root == null:
		return
	_check(root.name == "Cabin", "the root is named 'Cabin' (%s)" % root.name)
	var mesh: MeshInstance3D = _find_mesh(root)
	_check(mesh != null, "the .glb reached the tree as a MeshInstance3D")
	if mesh == null:
		return
	var mat: StandardMaterial3D = mesh.mesh.surface_get_material(0) as StandardMaterial3D
	_check(mat != null, "the drawn surface carries a StandardMaterial3D")
	if mat == null:
		return
	# The whole point of the KHR_materials_unlit surgery: the hub scene has
	# no DirectionalLight3D at all, so a material that imported LIT would
	# draw the cabin black rather than raise anything.
	_check(mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"the material is UNSHADED (mode %d)" % mat.shading_mode)
	_check(mat.albedo_texture != null, "the baked baseColor survived the strip")
	# And the map that was removed, confirmed absent on the surface that
	# actually draws rather than only in the file.
	_check(mat.metallic_texture == null and mat.roughness_texture == null,
			"no metallic/roughness texture on the drawn material")

func _phase_b_geometry(props: HubBuilder) -> void:
	print("")
	print("--- PHASE B: where it stands, and where its door is ---")
	var cabins: Array[Dictionary] = props.cabins()
	if cabins.is_empty():
		return
	var entry: Dictionary = cabins[0]
	var root: Node3D = entry.get("root")
	if root == null:
		return
	var pos: Vector3 = entry["position"]
	_check(pos.distance_to(_EXPECTED_POSITION) < 0.001,
			"placed at the surveyed spot %s" % str(pos))
	var door: Vector3 = entry["door"]
	_check(door.distance_to(_EXPECTED_DOOR) < 0.001,
			"the doorstep is out along the open face %s" % str(door))
	# THE DOORSTEP IS ON THE OPEN SIDE, not merely at the right distance:
	# the open face is model +Z and the entry ships rotation_y = 0, so the
	# door has to be at greater z than the trunk. A door derived on the
	# wrong side would still pass a distance test and would walk Keepy
	# round the back of a closed trunk.
	_check(door.z > pos.z, "the doorstep is on the OPEN (+Z) face")
	_check(HubRegion.contains(door), "the doorstep is walkable ground")

	var aabb: AABB = _world_aabb(root)
	_check(absf(aabb.position.y) < 0.01,
			"it sits ON the ground (lowest point y = %.4f)" % aabb.position.y)
	# The raw model is 1.8929 x 1.5901 (X x Y, measured), scaled by the
	# SCALE-UP LOT's own entry scale -- never a second literal for "the
	# built size", which is exactly the two-numbers-for-one-thing mistake
	# the doorstep comment above warns about.
	var expected_x: float = 1.8929 * _EXPECTED_SCALE
	var expected_y: float = 1.5901 * _EXPECTED_SCALE
	_check(absf(aabb.size.x - expected_x) < 0.01 and absf(aabb.size.y - expected_y) < 0.01,
			"built at scale %.1f (%.3f x %.3f x %.3f)"
					% [_EXPECTED_SCALE, aabb.size.x, aabb.size.y, aabb.size.z])
	var half: float = maxf(aabb.size.x, aabb.size.z) * 0.5
	var footprint: float = HubBuilder.CABIN_FOOTPRINT_RADIUS * root.scale.x
	_check(footprint >= half,
			"the footprint (%.2f) covers the built half-span (%.3f)"
					% [footprint, half])

## The old ride state is GONE, asserted rather than assumed.
##
## ⚠️ THIS IS THE PHASE THAT REPLACES C, D AND E, and it is deliberately
## the shape they are not: they drove a mechanism, this one proves the
## mechanism is not there. Deleting them and adding nothing would leave the
## removal untested -- a half-removed state (the enum value gone but
## enter_cabin() still on the class, say) compiles, ships, and does nothing
## visible until a tap finds it.
##
## Read off the CLASS through has_method/get, not by calling anything: the
## point is that the surface does not exist.
func _phase_g_gone(keepy: KeepyHopper, tap: HubTapInput) -> void:
	print("")
	print("--- PHASE G: the old in-place hide is gone ---")
	_check(not keepy.has_method("enter_cabin"), "KeepyHopper has no enter_cabin()")
	_check(not keepy.has_method("leave_cabin"), "KeepyHopper has no leave_cabin()")
	_check(not keepy.has_method("is_in_cabin"), "KeepyHopper has no is_in_cabin()")
	var signals: Array[StringName] = []
	for s in keepy.get_signal_list():
		signals.append(StringName(s["name"]))
	_check(not signals.has(&"cabin_entered") and not signals.has(&"cabin_exited"),
			"the cabin_entered/cabin_exited signals are gone")
	# The withdrawal went with the mechanism: with the visit now a scene
	# change, this whole screen stops existing for its length, so there is
	# no "meanwhile" a flag could describe.
	var fields: Array[StringName] = []
	for pr in tap.get_property_list():
		fields.append(StringName(pr["name"]))
	_check(not fields.has(&"cabin_available"),
			"HubTapInput has no cabin_available withdrawal any more")
	# And what REPLACED it is wired: the route exists, and it is the same
	# table the three portals go through rather than a second scene-changer
	# grown inside HubWorld.
	_check(HubRouter.ROUTES.has(&"cabin"),
			"HubRouter carries a 'cabin' route (%s)"
					% str(HubRouter.ROUTES.get(&"cabin", "<missing>")))
	_check(String(HubRouter.ROUTES.get(&"cabin", "")) == "res://scenes/CabinInterior.tscn",
			"and it points at the interior scene")

## The interior scene stands up on its own, and its two floors are where
## the calibration put them.
##
## Instantiated ON ITS OWN rather than reached through the route, because
## what is under test here is the SCENE -- a controller with no levels, a
## link whose ends do not sit on their floors, or a backdrop that never
## instantiated are all silent, and none of them needs the hub to show up.
func _phase_i_interior() -> void:
	print("")
	print("--- PHASE I: the interior scene builds ---")
	# add_child runs _ready() synchronously, so everything the scene builds
	# exists on the line after this one -- no frame to wait for.
	var interior: Node = INTERIOR_SCENE.instantiate()
	add_child(interior)
	var controller: LevelController = interior.get_node("LevelController") as LevelController
	_check(controller != null, "the interior carries a LevelController")
	if controller == null:
		interior.queue_free()
		return
	_check(controller.levels.size() == 2,
			"two levels: a floor and a loft (%d)" % controller.levels.size())
	_check(controller.links.size() == 1,
			"one transition between them (%d)" % controller.links.size())
	if controller.levels.size() < 2 or controller.links.is_empty():
		interior.queue_free()
		return

	var floor_level: LevelDefinition = controller.levels[0]
	var loft_level: LevelDefinition = controller.levels[1]
	# The loft is ABOVE the floor -- the one thing a two-storey scene
	# cannot get wrong and still be a two-storey scene.
	_check(loft_level.plane_y > floor_level.plane_y,
			"the loft (%.3f) is above the floor (%.3f)"
					% [loft_level.plane_y, floor_level.plane_y])
	# Both heights come out of ONE conversion in the scene, so they are
	# checked against that same conversion rather than against a second
	# copy of the arithmetic here.
	var expect_floor: float = (CabinInterior.FLOOR_MODEL_Y
			+ CabinInterior.CABIN_MODEL_OFFSET_Y) * CabinInterior.CABIN_SCALE
	var expect_loft: float = (CabinInterior.LOFT_MODEL_Y
			+ CabinInterior.CABIN_MODEL_OFFSET_Y) * CabinInterior.CABIN_SCALE
	_check(absf(floor_level.plane_y - expect_floor) < 0.001,
			"the floor plane is the MEASURED floor (%.4f)" % floor_level.plane_y)
	_check(absf(loft_level.plane_y - expect_loft) < 0.001,
			"the loft plane is the MEASURED slab top (%.4f)" % loft_level.plane_y)

	# THE LINK'S TWO ENDS SIT ON THEIR OWN FLOORS. Built from the level
	# definitions in the scene for exactly this reason -- a hand-written
	# height here would be a second opinion about where a floor is, and the
	# failure it causes is a climb that ends in mid-air.
	var link: LevelTransition = controller.links[0]
	_check(link.level_a == 0 and link.level_b == 1,
			"the link joins level 0 to level 1 (%d -> %d)" % [link.level_a, link.level_b])
	_check(absf(link.point_a.y - floor_level.plane_y) < 0.001,
			"its foot is on the floor (%.4f)" % link.point_a.y)
	_check(absf(link.point_b.y - loft_level.plane_y) < 0.001,
			"its top is on the loft (%.4f)" % link.point_b.y)
	# And BOTH ends stand on the level they serve, rather than out over the
	# edge of it: a foot outside the floor's extent is a ladder a player
	# cannot legally walk to.
	_check(floor_level.contains(link.point_a),
			"the foot is inside the floor's extent")
	_check(loft_level.contains(link.point_b),
			"the top is inside the loft's extent")

	# The walker starts standing on the ground floor, at the spot the door
	# is meant to open onto.
	var walker: LevelWalker = interior.get_node(
			"WorldViewport/SubViewport/World/Walker") as LevelWalker
	_check(walker != null, "the interior carries a LevelWalker")
	if walker != null:
		_check(absf(walker.global_position.y - floor_level.plane_y) < 0.001,
				"Keepy starts ON the ground floor (%.4f)" % walker.global_position.y)
		_check(floor_level.contains(walker.global_position),
				"and inside it, not over the edge")
		_check(walker.find_child("Body", true, false) != null,
				"his body reached the walker")

	# The backdrop is ONE static node, never moved: everything else in the
	# scene is positioned against it.
	var props: Node3D = interior.get_node(
			"WorldViewport/SubViewport/World/Props") as Node3D
	var cabin: Node3D = props.get_node_or_null("Cabin") as Node3D
	_check(cabin != null, "the .glb backdrop was built")
	if cabin != null:
		_check(absf(cabin.scale.x - CabinInterior.CABIN_SCALE) < 0.001,
				"at the interior's own scale %.1f (%.3f)"
						% [CabinInterior.CABIN_SCALE, cabin.scale.x])
		_check(cabin.global_position.is_equal_approx(Vector3.ZERO),
				"and at the origin, unmoved %s" % str(cabin.global_position))

	# THE CAMERA IS FIXED, and that is the decision this batch took rather
	# than an accident: no LevelCamera, no follow, no occlusion fade.
	var camera: Camera3D = interior.get_node(
			"WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_check(camera != null and not (camera is LevelCamera),
			"the interior camera is a plain fixed Camera3D, not a LevelCamera")
	if camera != null:
		var pitch: float = camera.rotation_degrees.x
		_check(absf(pitch + 22.0) < 0.5,
				"pitched at the calibrated -22 deg (%.2f)" % pitch)
		_check(camera.keep_aspect == Camera3D.KEEP_WIDTH,
				"KEEP_WIDTH, so the frame does not narrow on a taller phone")
		# And BOTH floors are in front of it -- a fixed camera that cannot
		# see one of its two levels is the failure this scene risks.
		_check(not camera.is_position_behind(Vector3(0.0, expect_floor, 0.0)),
				"the ground floor is in front of it")
		_check(not camera.is_position_behind(Vector3(0.0, expect_loft, 0.0)),
				"the loft is in front of it")

	# NOTHING JOINED level_occluder, and that is measured rather than
	# forgotten: the cabin is ONE mesh and the walker stands INSIDE its
	# world AABB on both floors, so a slab test would report "blocking"
	# every frame from every camera position and hold the whole building at
	# fade alpha for the entire visit.
	_check(get_tree().get_nodes_in_group("level_occluder").is_empty(),
			"no node joined level_occluder (the cabin is one mesh around the player)")

	_phase_j_standing(interior, controller, walker)
	_phase_k_taps(interior, controller, walker)
	_phase_p_rest(interior, controller, walker)
	await _phase_n_magpie(interior, controller, walker)
	interior.queue_free()

## =====================================================================
## HE STANDS **ON** THE FLOOR, ON BOTH STOREYS
##
## ⚠️ THE DEFECT THIS GATES SHIPPED, AND THIS FILE WATCHED IT GO PAST.
## PHASE I already checked that a node called "Body" reached the walker --
## and it had. What nothing checked was how high it was DRAWN, so Keepy
## went out sunk 0.9166 world units, 67.9% of his own height, with only
## his head above the boards. Every other assertion stayed green.
##
## The cause was that his lift was copied out of the hub as ONE of the two
## authored numbers that make it up there -- the slot's y = 0.9 was
## dropped, and ModelSlot's model_offset was multiplied by a scale
## ModelSlot does not multiply it by.
##
## So this measures the LOWEST DRAWN VERTEX, in world space, off the AABBs
## of whatever MeshInstance3Ds the body actually contains. Not the node's
## position, which was never wrong; not a constant, which would just be the
## same arithmetic asserting itself.
func _phase_j_standing(interior: Node, controller: LevelController,
		walker: LevelWalker) -> void:
	print("")
	print("--- PHASE J: Keepy stands on the floor, not in it ---")
	var body: Node3D = walker.find_child("Body", true, false) as Node3D
	_check(body != null, "his body reached the walker")
	if body == null:
		return
	var meshes: Array = _mesh_instances(body)
	_check(not meshes.is_empty(), "the body draws at least one mesh (%d)" % meshes.size())
	if meshes.is_empty():
		return
	# TOLERANCE. A hop's arc is 0.6 and his own height 1.35, so anything
	# this loose would still be visible; it is a millimetre band because
	# the placement is exact arithmetic, not a fit.
	const TOL: float = 0.002
	for index in controller.levels.size():
		var level: LevelDefinition = controller.levels[index]
		walker.global_position = level.centre()
		# The transforms have to be recomputed before the AABBs are read.
		interior.propagate_notification(CanvasItem.NOTIFICATION_TRANSFORM_CHANGED)
		var low: float = _lowest_drawn_y(meshes)
		_check(absf(low - level.plane_y) < TOL,
				"on '%s' his lowest drawn vertex is the floor (%.6f vs %.6f, off by %+.6f)"
						% [level.level_name, low, level.plane_y, low - level.plane_y])
		var high: float = _highest_drawn_y(meshes)
		# And he is the size he is outdoors. A lift fixed by SHRINKING him
		# would satisfy the line above and be a different bug.
		_check(absf((high - low) - 1.3501) < 0.01,
				"and he is still 1.35 tall (%.4f)" % (high - low))

func _mesh_instances(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_mesh_instances(child))
	return out

func _lowest_drawn_y(meshes: Array) -> float:
	var low: float = 1.0e9
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		var box: AABB = mi.get_aabb()
		for k in range(8):
			low = minf(low, (mi.global_transform * box.get_endpoint(k)).y)
	return low

func _highest_drawn_y(meshes: Array) -> float:
	var high: float = -1.0e9
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		var box: AABB = mi.get_aabb()
		for k in range(8):
			high = maxf(high, (mi.global_transform * box.get_endpoint(k)).y)
	return high

## =====================================================================
## THE TAPPABLE SPOTS, AND THE WAY OUT
##
## ⚠️ THIS PHASE OPENS WITH THE POSITIVE, for PHASE T's reason. "A tap over
## there does not leave the room" is satisfied for free by a door that was
## never wired at all, so the door has to be shown FIRING before any of its
## refusals mean anything.
func _phase_k_taps(interior: Node, controller: LevelController,
		walker: LevelWalker) -> void:
	print("")
	print("--- PHASE K: the door, the bed and the ladder answer taps ---")
	_check(controller.hotspots.size() == 3,
			"three hotspots: a door, a bed and the magpie (%d)"
					% controller.hotspots.size())
	var door: LevelHotspot = null
	var bed: LevelHotspot = null
	for spot in controller.hotspots:
		if spot.kind == &"door":
			door = spot
		elif spot.kind == &"bed":
			bed = spot
	_check(door != null, "one of them is the door")
	_check(bed != null, "one of them is the bed")
	if door == null or bed == null:
		return
	var floor_level: LevelDefinition = controller.levels[0]
	var loft_level: LevelDefinition = controller.levels[1]
	_check(door.level_index == 0, "the door is on the ground floor")
	_check(bed.level_index == 1, "the bed is on the loft")
	_check(absf(door.point.y - floor_level.plane_y) < 0.001,
			"the door sits on the ground floor (%.4f)" % door.point.y)
	_check(absf(bed.point.y - loft_level.plane_y) < 0.001,
			"the bed sits on the loft (%.4f)" % bed.point.y)
	_check(floor_level.contains(door.point), "the door is inside the floor's extent")
	_check(loft_level.contains(bed.point), "the bed is inside the loft's extent")

	# THE POSITIVE FIRST: the door's own point means the door.
	_check(door.accepts_tap(door.point, 0), "a tap ON the door means the door")
	# AND THE LADDER STILL WINS ITS OWN GROUND. Links are asked before
	# hotspots, so this is what makes that ordering a fact about the LAYOUT
	# rather than about the order of two loops.
	var link: LevelTransition = controller.links[0]
	var gap: float = Vector2(link.point_a.x - door.point.x,
			link.point_a.z - door.point.z).length()
	_check(gap > link.tap_radius + door.tap_radius,
			"the ladder's foot and the door do not overlap (%.3f apart, radii sum %.3f)"
					% [gap, link.tap_radius + door.tap_radius])
	# ⚠️ AND ON THE LOFT THE BED HAS TO SHARE A SMALL SQUARE WITH THE
	# LADDER'S TOP. This is the tightest pair in the scene and the reason
	# BED_TAP_RADIUS is 0.70 rather than the door's 0.85.
	var loft_gap: float = Vector2(link.point_b.x - bed.point.x,
			link.point_b.z - bed.point.z).length()
	_check(loft_gap > link.tap_radius + bed.tap_radius,
			"the ladder's top and the bed do not overlap (%.3f apart, radii sum %.3f)"
					% [loft_gap, link.tap_radius + bed.tap_radius])

	# THE REFUSALS. Asked on the AIM, which is the only thing a hotspot is
	# ever allowed to read -- see LevelHotspot's header for the funnel this
	# would otherwise open at the floor's +Z edge, 0.35 u past the door.
	_check(not door.accepts_tap(floor_level.flat(Vector3(door.point.x, 0.0, door.point.z - 2.0)), 0),
			"a tap two units into the room does not mean the door")
	_check(not door.accepts_tap(door.point, 1),
			"and the door does not answer at all from the loft")
	_check(not bed.accepts_tap(bed.point, 0), "the bed does not answer from the floor")

	# THE WITHDRAWAL, the boat's and not the ladder's: once leaving has
	# started the door stops accepting, so a second tap falls THROUGH to
	# the ground path instead of asking for a scene change already queued.
	door.set_busy(true)
	_check(not door.accepts_tap(door.point, 0),
			"a withdrawn door refuses even its own point")
	door.set_busy(false)
	_check(door.accepts_tap(door.point, 0), "and accepts again once released")

	# ONE TAP, ONE SIGNAL: a tap on the door must arrive as tapped_hotspot
	# and NOT as tapped_ground, or the walk and the exit would both fire.
	var ground_hits: Array = []
	var hotspot_hits: Array = []
	controller.tapped_ground.connect(func(d): ground_hits.append(d))
	controller.tapped_hotspot.connect(func(h, _d): hotspot_hits.append(h))
	var camera: Camera3D = interior.get_node(
			"WorldViewport/SubViewport/World/Camera3D") as Camera3D
	var container: SubViewportContainer = interior.get_node(
			"WorldViewport") as SubViewportContainer
	# Through the REAL dispatch, from a REAL screen point, so what is
	# measured is the path a finger takes and not a function called direct.
	var screen: Vector2 = camera.unproject_position(door.point) 			* (container.get_global_rect().size / Vector2(
					(interior.get_node("WorldViewport/SubViewport") as SubViewport).size)) 			+ container.get_global_rect().position
	controller.dispatch(screen)
	_check(hotspot_hits.size() == 1 and ground_hits.is_empty(),
			"a screen tap on the door fires tapped_hotspot once and tapped_ground never (%d/%d)"
					% [hotspot_hits.size(), ground_hits.size()])
	if hotspot_hits.size() == 1:
		_check((hotspot_hits[0] as LevelHotspot).kind == &"door",
				"and the hotspot it carried is the door")

	# THE EXIT INTENT SURVIVES A PASS-THROUGH LANDING. This is the owl
	# batch's lesson, and it is asserted rather than trusted: a version
	# that cleared on the first landing whatever it was left Keepy standing
	# beside the thing having never used it, and its probe was green until
	# a walk grew to two hops.
	walker.global_position = floor_level.flat(
			Vector3(door.point.x, 0.0, door.point.z - 3.0))
	interior.call("_on_tapped_hotspot", door, door.point)
	_check(bool(interior.get("_exit_pending")), "tapping the door arms the exit intent")
	# A landing HALF WAY there must not leave, and must not drop it.
	interior.call("_on_hop_landed",
			floor_level.flat(Vector3(door.point.x, 0.0, door.point.z - 1.5)))
	_check(bool(interior.get("_exit_pending")),
			"a landing short of the door KEEPS the intent")
	_check(not bool(interior.get("_leaving")), "and has not left")
	# A plain tap elsewhere CANCELS it -- the player replaced the decision.
	interior.call("_on_tapped_ground", floor_level.centre())
	_check(not bool(interior.get("_exit_pending")),
			"a plain tap somewhere else cancels the exit intent")

	# ⚠️ AND NO POINT ON THE LOFT CAN REACH THE DOOR. _on_hop_landed
	# compares to DOOR_SPOT in XZ WITHOUT asking which level the landing
	# was on, so a loft corner within DOOR_REACH of the doorstep would end
	# the visit from upstairs -- a scene change nobody asked for. It cannot
	# today: the nearest loft point is 1.583 away against a reach of 0.9.
	#
	# That is a fact about two rectangles, NOT about the code, and moving
	# the loft or widening the reach would break it in silence. Asserted
	# rather than trusted, and derived from the shipped constants so it
	# cannot drift from what the scene actually builds.
	var loft_lo := CabinInterior.LOFT_CENTRE - Vector2.ONE * CabinInterior.LOFT_HALF_EXTENT
	var loft_hi := CabinInterior.LOFT_CENTRE + Vector2.ONE * CabinInterior.LOFT_HALF_EXTENT
	var nearest_loft := Vector2(
			clampf(CabinInterior.DOOR_SPOT.x, loft_lo.x, loft_hi.x),
			clampf(CabinInterior.DOOR_SPOT.y, loft_lo.y, loft_hi.y))
	var loft_gap_to_door: float = nearest_loft.distance_to(CabinInterior.DOOR_SPOT)
	_check(loft_gap_to_door > CabinInterior.DOOR_REACH,
			"no point on the loft is within the door's reach (%.3f vs %.3f)"
					% [loft_gap_to_door, CabinInterior.DOOR_REACH])

## The doorstep must not answer for the lawn in front of the cabin.
##
## THE DEFECT THIS GATES, and it shipped: the tap radius was argued from
## the size of the BUILDING, and the doorstep was placed against the
## CIRCUMSCRIBED footprint rather than the front face. Both errors grow
## with scale, and at 3.5 they had put a 4.4-unit invisible disc of pure
## lawn 2.3 u in front of the wall. A player walking up to look at the
## cabin tapped that lawn; the tap he meant as "walk there" was spent as
## "go inside", and he vanished. Nothing raised, nothing looked broken.
##
## ⚠️ THE CONSEQUENCE IS WORSE NOW, NOT BETTER: a stray entry used to cost
## a duck-in he could tap his way out of. It now costs a SCENE CHANGE. So
## this phase and PHASE F below are kept in full, unchanged in what they
## assert, even though the mechanism behind the signal was replaced.
##
## THE POINTS ARE DERIVED FROM THE BUILDING, NEVER FROM THE RADIUS. Sizing
## them off CABIN_TAP_RADIUS would make this phase pass for any radius at
## all -- it would be asserting that a circle is a circle. They are three
## places a player demonstrably stands: two paces back from the doorway to
## look up at the roof, and one pace either side walking across the front.
##
## AND IT OPENS WITH THE POSITIVE. "Nothing triggered" is satisfied for
## free by a doorstep that was never wired, so the phase shows it CAN fire
## before its refusals mean anything.
##
## THE SIGNAL HALF RUNS WITH HubWorld's HANDLER DISCONNECTED, and that is
## not tidiness: what is under test is WHICH SIGNAL a tap becomes, and
## leaving the handler live would ROUTE OUT OF THE SCENE mid-phase.
func _phase_t_no_stray_entry(hub: Node, props: HubBuilder, keepy: KeepyHopper,
		tap: HubTapInput, camera: Camera3D) -> void:
	print("")
	print("--- PHASE T: walking past does not put him indoors ---")
	if props.cabins().is_empty():
		return
	var entry: Dictionary = props.cabins()[0]
	var door: Vector3 = entry["door"]
	var root: Node3D = entry.get("root")
	if root == null:
		return

	# The invariant the two-term reach exists to hold, checked against the
	# wall as BUILT rather than against either constant.
	var aabb: AABB = _world_aabb(root)
	var wall: float = aabb.position.z + aabb.size.z
	_check(absf((door.z - wall) - _EXPECTED_WALL_GAP) < 0.02,
			"the doorstep stands %.3f u off the front wall (want %.2f, any scale)"
					% [door.z - wall, _EXPECTED_WALL_GAP])
	# And the disc is tied to the DOORWAY, so it must not have grown with
	# the prop: a radius that reaches the far side of the building is a
	# radius answering for ground the building is nowhere near.
	_check(HubWorld.CABIN_TAP_RADIUS < aabb.size.x * 0.5,
			"the trigger (%.2f) is smaller than the cabin's own half-width (%.3f)"
					% [HubWorld.CABIN_TAP_RADIUS, aabb.size.x * 0.5])
	print("  ..    %.2f u of walkable ground behind the doorstep (edge at z = %.1f)"
			% [HubRegion.PLATEAU_HALF_EXTENT - door.z, HubRegion.PLATEAU_HALF_EXTENT])

	var container: SubViewportContainer = hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0,
			"the container has a real rect %s (run under xvfb, not --headless)" % rect)
	if rect.size.x <= 0.0:
		return

	await _settle(keepy)
	# ⚠️ PLACED AND THE CAMERA SNAPPED, exactly as PHASE F does and for the
	# reason it states -- but here it is not a refinement, it is what makes
	# the phase able to measure anything at all. The doorstep is 33 u out
	# at z = +34 and the camera looks down -Z, so from the spawn the door
	# is BEHIND it: unproject_position returns a point off the container,
	# _handle_point drops it, and every assertion below reads an empty
	# signal list. Measured -- the first run of this phase reported four
	# failures with `[]` for every tap, including its own blind check.
	keepy.global_position = Vector3(door.x, 0.0, door.z)
	camera.global_position = Vector3(door.x, 0.0, door.z) + HubCamera.OFFSET
	for i in 4:
		await get_tree().process_frame

	# Two paces back, and one either side. Stated in world units so they
	# say "a person standing clear of a doorway" rather than "outside
	# whatever the radius happens to be".
	var away := 2.0
	var candidates: Array = [
		[Vector3(door.x, 0.0, door.z + away), "two paces BACK from the door"],
		[Vector3(door.x + away, 0.0, door.z), "one pace to the SIDE of it"],
		[Vector3(door.x - away, 0.0, door.z), "one pace to the OTHER side"],
	]
	for candidate in candidates:
		var where: Vector3 = candidate[0]
		if not HubRegion.contains(where):
			print("  ..    %s is off the map, and clamps to %.2f u from the door -- asserted anyway"
					% [candidate[1], HubRegion.clamp_to(where).distance_to(door)])

	# --- which SIGNAL does each tap become? ------------------------------
	var saw: Array[StringName] = []
	var on_cabin := func(_p: Vector3) -> void: saw.append(&"cabin")
	var on_ground := func(_p: Vector3) -> void: saw.append(&"ground")
	tap.tapped_cabin.connect(on_cabin)
	tap.tapped_ground.connect(on_ground)
	# Handler off for the length of the signal test -- see the note above.
	tap.tapped_cabin.disconnect(Callable(hub, "_on_tapped_cabin"))
	tap.tapped_ground.disconnect(Callable(hub, "_on_tapped_ground"))

	saw.clear()
	tap._handle_point(_to_screen(container, camera, door))
	_check(saw.size() == 1 and saw[0] == &"cabin",
			"BLIND CHECK: a tap ON the doorstep still means the cabin (%s)" % str(saw))

	for probe in candidates:
		var where: Vector3 = probe[0]
		var what: String = probe[1]
		saw.clear()
		tap._handle_point(_to_screen(container, camera, where))
		_check(saw.size() == 1 and saw[0] == &"ground",
				"a walking tap %s (%.2f u out) stays a walking tap (%s)"
						% [what, where.distance_to(door), str(saw)])

	tap.tapped_cabin.connect(Callable(hub, "_on_tapped_cabin"))
	tap.tapped_ground.connect(Callable(hub, "_on_tapped_ground"))
	tap.tapped_cabin.disconnect(on_cabin)
	tap.tapped_ground.disconnect(on_ground)

	# --- and end to end, through the real routing ------------------------
	# One walking tap, driven all the way: he must walk, and the hub must
	# still be the scene when the walk is over. `_entering` is what a
	# stray entry would arm, and it is the thing to read now that going in
	# leaves no state on Keepy at all.
	await _settle(keepy)
	var lawn: Vector3 = candidates[1][0]
	tap._handle_point(_to_screen(container, camera, lawn))
	var frames: int = 0
	while keepy.is_hopping() and frames < 900:
		await get_tree().process_frame
		frames += 1
	_check(is_instance_valid(hub) and hub.is_inside_tree(),
			"a walking tap one pace to the side did NOT route away (%d frames)" % frames)
	_check(not HubSpawn.has_pending(), "and wrote no return spawn")
	await _settle(keepy)

## PHASE F -- THE CLAMP MUST NOT BE A FUNNEL INTO THE DOORSTEP.
##
## The third stray-entry cause, and the one no radius could have fixed.
## _handle_point resolves a tap in two steps that used to share one
## variable: clamp_to() answers "where can he stand", and each prop test
## answers "what did the player mean". Reading the second off the first
## turns the clamp into a FUNNEL -- every tap on ground that does not exist
## is dragged to the nearest ground that does, and a prop sitting near that
## edge starts answering for the whole half-plane behind it.
##
## The cabin is the only prop on this plateau exposed to it, measured
## rather than assumed: its doorstep stands 0.655 u inside the north edge,
## while the boat, the owl and the three ladder feet are 6.85 u to
## infinitely far from any off-map ground.
##
## ⚠️ THE FUNNEL IS ASSERTED TO EXIST BEFORE ANYTHING IS ASKED TO RESIST
## IT. Every refusal below would pass gratuitously against a layout where
## the clamp simply left these points far from the door.
func _phase_f_no_funnel(hub: Node, props: HubBuilder, keepy: KeepyHopper,
		tap: HubTapInput, camera: Camera3D) -> void:
	print("")
	print("--- PHASE F: off-map taps behind the cabin are walks, not entries ---")
	if props.cabins().is_empty():
		return
	var door: Vector3 = (props.cabins()[0])["door"]
	var container: SubViewportContainer = hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0,
			"the container has a real rect %s (run under xvfb, not --headless)" % rect)
	if rect.size.x <= 0.0:
		return

	await _settle(keepy)
	# Placed and the camera SNAPPED, rather than left wherever the phase
	# before happened to end: a half-converged camera aims every screen
	# point below from somewhere no player stands.
	keepy.global_position = Vector3(door.x, 0.0, door.z)
	camera.global_position = Vector3(door.x, 0.0, door.z) + HubCamera.OFFSET
	for i in 4:
		await get_tree().process_frame

	# --- the funnel is real, or the refusals below mean nothing ---------
	var behind: Array[float] = [2.0, 3.0, 4.0]
	for back in behind:
		var aim := Vector3(door.x, 0.0, door.z + back)
		_check(not HubRegion.contains(aim),
				"%.0f u behind the door is off the map" % back)
		_check(HubRegion.clamp_to(aim).distance_to(door) <= HubWorld.CABIN_TAP_RADIUS,
				"  and the clamp still drags it onto the doorstep (%.3f u, radius %.2f)"
						% [HubRegion.clamp_to(aim).distance_to(door), HubWorld.CABIN_TAP_RADIUS])

	# --- which SIGNAL does each become? ---------------------------------
	var saw: Array[StringName] = []
	var on_cabin := func(_p: Vector3) -> void: saw.append(&"cabin")
	var on_ground := func(_p: Vector3) -> void: saw.append(&"ground")
	tap.tapped_cabin.connect(on_cabin)
	tap.tapped_ground.connect(on_ground)
	tap.tapped_cabin.disconnect(Callable(hub, "_on_tapped_cabin"))
	tap.tapped_ground.disconnect(Callable(hub, "_on_tapped_ground"))

	saw.clear()
	tap._handle_point(_to_screen(container, camera, door))
	_check(saw.size() == 1 and saw[0] == &"cabin",
			"BLIND CHECK: a tap ON the doorstep still means the cabin (%s)" % str(saw))

	for back in behind:
		var aim := Vector3(door.x, 0.0, door.z + back)
		var screen := _to_screen(container, camera, aim)
		if camera.is_position_behind(aim) or not rect.has_point(screen):
			print("  ..    %.0f u behind is not on screen from the doorstep -- not measured" % back)
			continue
		saw.clear()
		tap._handle_point(screen)
		_check(saw.size() == 1 and saw[0] == &"ground",
				"a tap %.0f u BEHIND the cabin is a walking tap, not an entry (%s)"
						% [back, str(saw)])

	tap.tapped_cabin.connect(Callable(hub, "_on_tapped_cabin"))
	tap.tapped_ground.connect(Callable(hub, "_on_tapped_ground"))
	tap.tapped_cabin.disconnect(on_cabin)
	tap.tapped_ground.disconnect(on_ground)

	# --- and end to end, through the real routing -----------------------
	# The whole report, in one assertion: aim past the cabin, and still be
	# on the plateau when the walk is over.
	await _settle(keepy)
	keepy.global_position = Vector3(door.x, 0.0, door.z - 2.0)
	camera.global_position = Vector3(door.x, 0.0, door.z - 2.0) + HubCamera.OFFSET
	for i in 4:
		await get_tree().process_frame
	var past := Vector3(door.x, 0.0, door.z + 3.0)
	tap._handle_point(_to_screen(container, camera, past))
	var frames: int = 0
	while keepy.is_hopping() and frames < 900:
		await get_tree().process_frame
		frames += 1
	_check(is_instance_valid(hub) and hub.is_inside_tree(),
			"aiming 3 u PAST the cabin did not route away (%d frames, %.3f u from the door)"
					% [frames, Vector3(keepy.global_position.x, 0.0, keepy.global_position.z).distance_to(door)])
	_check(not HubSpawn.has_pending(), "and wrote no return spawn")
	await _settle(keepy)

## The way out puts him back on the doorstep, not at the world origin.
##
## THE DEFECT THIS EXISTS FOR, and it is the one every other return path
## on this screen still has: HubWorld.tscn's Keepy node carries no
## transform, so a bare change_scene_to_file drops him at (0,0,0) -- the
## middle of the plateau, a full 33 units from the cabin he just walked
## out of.
##
## Driven STANDALONE rather than off the entry in PHASE R, and that is the
## order the two were swapped into deliberately: R ends the run (it hands
## the hub to the router), so a spawn test hanging off it would be a test
## that can only ever run after the scene it needs has been replaced.
## Chaining them would also have made this phase pass or fail for reasons
## belonging to that one.
func _phase_s_spawn(tree: SceneTree) -> void:
	print("")
	print("--- PHASE S: coming back out lands on the doorstep ---")
	# BLIND CHECK. Every assertion below is about a spawn being honoured,
	# and "he is at the origin" passes for free when nothing was ever
	# requested -- so the clean start is proven before the request means
	# anything.
	_check(not HubSpawn.has_pending(), "BLIND CHECK: nothing is pending to begin with")

	HubSpawn.request(_EXPECTED_DOOR)
	_check(HubSpawn.has_pending(), "a request leaves one pending")
	var where: Vector3 = HubSpawn.take()
	# Flattened on the way in: the plateau is single-altitude, and a height
	# stored here would be a second opinion about where the ground is.
	_check(absf(where.y) < 0.0001, "the spawn carries no height (%.4f)" % where.y)
	_check(where.distance_to(_EXPECTED_DOOR) < 0.001,
			"and it comes back as the point it was given %s" % str(where))
	# CONSUMED, not read: a spawn left set would apply to the next return
	# from Chased too, and put the player at a door they left an hour ago.
	_check(not HubSpawn.has_pending(), "take() cleared it")

	# End to end: load the hub the way a return does, and see where he
	# stands.
	HubSpawn.request(_EXPECTED_DOOR)
	var hub: Node = HUB_SCENE.instantiate()
	add_child(hub)
	await tree.process_frame
	await tree.process_frame
	var keepy: KeepyHopper = hub.get_node(
			"WorldViewport/SubViewport/World/Keepy") as KeepyHopper
	_check(keepy.global_position.distance_to(_EXPECTED_DOOR) < 0.01,
			"a fresh hub put him on the doorstep %s" % str(keepy.global_position))
	_check(not HubSpawn.has_pending(), "and consumed the spawn doing it")
	# THE CAMERA CAME WITH HIM. Children are readied before their parent,
	# so HubCamera snapped to the origin before HubWorld moved Keepy: with
	# no second snap the screen would open on the middle of the plateau and
	# slide over. That slide is invisible to every assertion above.
	var camera: HubCamera = hub.get_node(
			"WorldViewport/SubViewport/World/Camera3D") as HubCamera
	var want: Vector3 = Vector3(_EXPECTED_DOOR.x, 0.0, _EXPECTED_DOOR.z) + HubCamera.OFFSET
	_check(camera.global_position.distance_to(want) < 0.01,
			"and the camera is already framing it %s" % str(camera.global_position))

	# A SECOND load with nothing pending goes back to the authored origin,
	# which is what every sub-game return must keep doing.
	# REMOVED before freed: queue_free() alone leaves the node in the tree
	# for the rest of the frame, and HubCamera._process then reads a target
	# that is on its way out -- which prints `!is_inside_tree()` twice into
	# a log this repo compares byte for byte.
	remove_child(hub)
	hub.queue_free()
	await tree.process_frame
	HubSpawn.clear()
	var again: Node = HUB_SCENE.instantiate()
	add_child(again)
	await tree.process_frame
	await tree.process_frame
	var keepy2: KeepyHopper = again.get_node(
			"WorldViewport/SubViewport/World/Keepy") as KeepyHopper
	_check(keepy2.global_position.length() < 0.01,
			"with nothing pending he is back at the spawn %s" % str(keepy2.global_position))
	remove_child(again)
	again.queue_free()
	await tree.process_frame
	# And the next phase has to start from a clean slate of its own.
	HubSpawn.clear()

## A tap on the doorstep walks him there and ROUTES.
##
## ⚠️ THIS PHASE ENDS THE HUB, which is why it runs last: the router calls
## change_scene_to_file, and everything above needs the plateau standing.
## It is driven through HubWorld's own handler and the real hop chain,
## never by calling _try_enter_cabin directly -- what is worth gating is
## the WIRING, and a probe that called the method would pass against a
## signal that was never connected.
##
## The REAL router runs, with no stand-in: the entry is the one place the
## spawn and the route have to happen together and in that order, and a
## recording double would be free to agree with the file it is imitating
## about neither.
##
## VERIFIED RED BEFORE GREEN by neutering the route call in
## HubWorld._try_enter_cabin -- see the batch report.
func _phase_r_route(tree: SceneTree, hub: Node, props: HubBuilder,
		keepy: KeepyHopper) -> void:
	print("")
	print("--- PHASE R: the doorstep tap routes into the interior ---")
	if props.cabins().is_empty():
		return
	var door: Vector3 = props.cabins()[0]["door"]

	# BLIND CHECK. "A spawn is pending" and "the scene changed" both pass
	# for free against leftovers, so the clean start is asserted first.
	_check(not HubSpawn.has_pending(), "BLIND CHECK: nothing is pending before the tap")
	_check(tree.current_scene == hub,
			"BLIND CHECK: the hub is the scene the router is about to replace")

	hub.call("_on_tapped_cabin", door)
	var frames: int = 0
	while not HubSpawn.has_pending() and frames < 900:
		await tree.process_frame
		frames += 1
	_check(HubSpawn.has_pending(),
			"he walked to the door and the entry fired (%d frames)" % frames)
	if not HubSpawn.has_pending():
		return
	# THE SPAWN IS THE DOORSTEP HE STOOD ON, which is the one fact linking
	# this phase to PHASE S: that one proved a spawn is honoured, this one
	# proves the right point is written.
	_check(HubSpawn.take().distance_to(_EXPECTED_DOOR) < 0.001,
			"and the spawn it wrote IS the doorstep %s" % str(_EXPECTED_DOOR))

	# THE SCENE CHANGE ITSELF, and it is a TWO-STEP one -- measured, not
	# assumed. change_scene_to_packed nulls current_scene and queues the
	# old scene for deletion straight away, then installs the new one at
	# the END of the idle frame. So there is a window in which the tree has
	# no current scene at all, and a probe that waited only for
	# `current_scene != hub` reads null and reports the interior missing.
	# That is exactly what the first run of this phase did.
	frames = 0
	while (tree.current_scene == hub or tree.current_scene == null) and frames < 240:
		await tree.process_frame
		frames += 1
	_check(tree.current_scene != hub, "the hub scene was left (%d frames)" % frames)
	var loaded: Node = tree.current_scene
	_check(loaded != null and loaded.get_script() != null
					and loaded.get_script().resource_path
							== "res://scripts/cabin/CabinInterior.gd",
			"and the interior is the current scene (%s)"
					% ("<null>" if loaded == null else loaded.name))
	# He arrives standing on the ground floor of it, which is the whole
	# claim the player will check first.
	if loaded != null:
		var walker: LevelWalker = loaded.get_node_or_null(
				"WorldViewport/SubViewport/World/Walker") as LevelWalker
		var controller: LevelController = loaded.get_node_or_null(
				"LevelController") as LevelController
		if walker != null and controller != null and not controller.levels.is_empty():
			var floor_level: LevelDefinition = controller.levels[0]
			_check(absf(walker.global_position.y - floor_level.plane_y) < 0.001,
					"and Keepy is standing on its ground floor (%.4f)"
							% walker.global_position.y)

## Puts him back outside, still, and clear of the doorstep, so the next
## assertion measures its own tap and not the one before it.
func _settle(keepy: KeepyHopper) -> void:
	var frames: int = 0
	while keepy.is_hopping() and frames < 900:
		await get_tree().process_frame
		frames += 1

## PHASE V: the magpie is drawn in the plateau's cutaway view of the cabin,
## in the SAME corner of the SAME room the interior stands her in -- and she
## is scenery out there, nothing more.
##
## GATED and not reported, because every way this can fail is SILENT. An
## unassigned magpie_scene pushes an error and draws nothing; a pose that
## drifts from the interior's puts her through a wall or out on the lawn at
## the wrong size, and the two views are never on screen together for
## anyone to notice; and a hotspot added here would make a tap near the
## cabin ambiguous without any error at all. None of it crashes, and all of
## it looks like "the bird was never added".
##
## THE AGREEMENT IS MEASURED AGAINST THE BODY THE INTERIOR ACTUALLY BUILDS,
## never against a second copy of the arithmetic: the interior scene is
## instantiated here and its Magpie node read off the tree, then the hub's
## local pose is fed back through CABIN_SCALE and the two are required to
## land on the same world position and the same world size. That is what
## magpie_local_pose()'s header promises, checked rather than trusted.
func _phase_v_cutaway_magpie(props: HubBuilder) -> void:
	print("")
	print("--- PHASE V: the magpie shows in the hub's cutaway cabin ---")
	var cabins: Array[Dictionary] = props.cabins()
	if cabins.is_empty():
		_check(false, "there is a cabin to furnish")
		return
	var root: Node3D = cabins[0].get("root") as Node3D
	_check(root != null, "the built cabin publishes its root")
	if root == null:
		return
	var bird: Node3D = root.get_node_or_null("Magpie") as Node3D
	_check(bird != null, "a Magpie hangs inside the built cabin")
	if bird == null:
		return

	# She has to DRAW. A wrapper that instantiated to an empty Node3D would
	# satisfy every position check below and put nothing on screen.
	var meshes: int = 0
	var stack: Array[Node] = [bird]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D or node is MultiMeshInstance3D:
			meshes += 1
		for kid in node.get_children():
			stack.append(kid)
	_check(meshes > 0, "she carries drawn geometry (%d draw node(s))" % meshes)
	_check(bird.visible and root.visible, "and both she and the cabin are visible")

	# ⚠️ A CHILD OF THE ROOT, not of the .glb node. The root is what _build
	# gives the entry's scale and rotation to, so this is what makes a
	# resized or turned cabin carry her along instead of leaving her behind
	# at the origin, full size.
	_check(bird.get_parent() == root,
			"she hangs on the cabin ROOT, so its scale and yaw carry her")

	# THE SAME BIRD AS INSIDE, measured against the interior's own built
	# body rather than against the constants a second time.
	var interior: Node = INTERIOR_SCENE.instantiate()
	add_child(interior)
	var inside: Node3D = interior.get_node_or_null(
			"WorldViewport/SubViewport/World/Props/Magpie") as Node3D
	_check(inside != null, "the interior's own Magpie could be read")
	if inside == null:
		interior.queue_free()
		return
	var scale_ratio: float = CabinInterior.CABIN_SCALE
	var hub_as_interior := bird.position * scale_ratio
	var dp: float = hub_as_interior.distance_to(inside.position)
	_check(dp < 0.001,
			"scaled back up she stands exactly where the interior stands her (%.5f u)" % dp)
	var hub_size: float = bird.scale.x * scale_ratio
	_check(absf(hub_size - inside.scale.x) < 0.0001,
			"and she is exactly the interior's size (%.5f vs %.5f)"
					% [hub_size, inside.scale.x])
	var dyaw: float = absf(bird.rotation_degrees.y - inside.rotation_degrees.y)
	_check(dyaw < 0.001,
			"facing the same way (%.3f vs %.3f deg)"
					% [bird.rotation_degrees.y, inside.rotation_degrees.y])
	interior.queue_free()

	# INSIDE THE ROOM, not out on the lawn. Her local offset is in model
	# units, so it is compared against the model's own footprint radius --
	# the same number ground_footprints() scales for this prop.
	var flat := Vector2(bird.position.x, bird.position.z)
	_check(flat.length() < HubBuilder.CABIN_FOOTPRINT_RADIUS,
			"she stands within the cabin's own footprint (%.4f < %.4f)"
					% [flat.length(), HubBuilder.CABIN_FOOTPRINT_RADIUS])
	# Above the model's own base, so she is standing on the floor of the
	# cutaway rather than sunk under it.
	_check(bird.position.y > 0.0,
			"and above its base, on the drawn floor (y = %.4f)" % bird.position.y)

	# SCENERY, AND NOTHING ELSE. The kiss lives in CabinInterior; a second
	# way to talk to her out here would be a second bird.
	var interactive: int = 0
	stack = [bird]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Area3D or node is CollisionObject3D or node is CabinMarker:
			interactive += 1
		for kid in node.get_children():
			stack.append(kid)
	_check(interactive == 0,
			"nothing tappable was hung on her (%d)" % interactive)
	# And the cabin's published tables are untouched: a tap near this cabin
	# still means the DOOR and only the door.
	_check(cabins.size() == 1 and cabins[0].has("door"),
			"the cabin still publishes exactly one door")

func _phase_untouched(props: HubBuilder) -> void:
	print("")
	print("--- PHASE UNTOUCHED: everything this lot must not have moved ---")
	_check(props.portals().size() == 3, "three portals (%d)" % props.portals().size())
	for portal in props.portals():
		_check(portal.game_id != &"", "portal %s still carries its id" % portal.game_id)
	_check(props.diving_boards().size() == 3,
			"three diving boards (%d)" % props.diving_boards().size())
	_check(props.owls().size() == 1, "one owl (%d)" % props.owls().size())
	_check(props.spinning_props().size() == 1,
			"one turnstile (%d)" % props.spinning_props().size())
	_check(props.seesaws().size() == 1, "one seesaw (%d)" % props.seesaws().size())
	_check(props.boat() != null, "the boat is still there")
	# AND THE THREE PORTAL ROUTES ARE UNTOUCHED. The cabin was added to
	# HubRouter's table this batch, which is the one file every sub-game
	# entry passes through -- a typo there breaks Chased, not the cabin.
	_check(String(HubRouter.ROUTES.get(&"chased", "")) == "res://scenes/TitleScreen.tscn",
			"chased still routes to TitleScreen")
	_check(String(HubRouter.ROUTES.get(&"quizz", "")) == "res://scenes/QuizzHomeScreen.tscn",
			"quizz still routes to QuizzHomeScreen")
	_check(String(HubRouter.ROUTES.get(&"battle", "")) == "res://scenes/Battle.tscn",
			"battle still routes to Battle")
	# NOTHING ELSE STOLE THE CABIN'S TAP, and nothing had its own stolen:
	# the doorstep has to be clear of every other prop that reads a tap.
	var door: Vector3 = props.cabins()[0]["door"] if not props.cabins().is_empty() \
			else Vector3.ZERO
	var worst: float = INF
	var who: String = ""
	for board in props.diving_boards():
		var d: float = door.distance_to(board["ladder"] as Vector3)
		if d < worst:
			worst = d
			who = "ladder"
	for owl in props.owls():
		var d: float = door.distance_to(owl["position"] as Vector3)
		if d < worst:
			worst = d
			who = "owl perch"
	for spinner in props.spinning_props():
		var d: float = door.distance_to(spinner["position"] as Vector3)
		if d < worst:
			worst = d
			who = "turnstile"
	for seesaw in props.seesaws():
		var d: float = door.distance_to(seesaw["position"] as Vector3)
		if d < worst:
			worst = d
			who = "seesaw"
	_check(worst > HubWorld.CABIN_TAP_RADIUS + 2.5,
			"nearest other tap target is the %s at %.2f u, clear of r = %.1f"
					% [who, worst, HubWorld.CABIN_TAP_RADIUS])

## =====================================================================
## PHASE M -- THE DOORSTEP CARRIES A MARK, IN THE PORTALS' OWN INK
##
## ⚠️ IT OPENS WITH THE POSITIVE for PHASE T's reason. "The mark is not
## drawn smaller than the trigger" and "it is not in the wrong ink" are
## both satisfied for free by a mark that was never built, so the mark has
## to be shown to EXIST before any of its properties mean anything.
##
## The ink is compared against HubPortal.tscn READ OFF DISK rather than
## against a literal repeated here. The claim is not "the ring is
## rgb(0.95, 0.74, 0.30)" -- that would pass happily while the three
## portals moved on without it. The claim is "the doorstep is drawn in the
## same ink as the doors beside it", and only the shipped scene can say.
func _phase_m_doorstep_mark(hub: Node, props: HubBuilder) -> void:
	print("")
	print("--- PHASE M: the doorstep is marked, out on the plateau ---")
	var cabins: Array[Dictionary] = props.cabins()
	if cabins.is_empty():
		_check(false, "there is a cabin to mark")
		return
	var marks: Array = []
	for child in props.get_children():
		if child is CabinMarker:
			marks.append(child)
	_check(marks.size() == cabins.size(),
			"one mark per cabin (%d marks, %d cabins)" % [marks.size(), cabins.size()])
	if marks.is_empty():
		return
	var mark: CabinMarker = marks[0]
	var door: Vector3 = cabins[0]["door"]
	# ⚠️ ON THE TRIGGER, NOT NEAR IT. A mark a metre off the circle the tap
	# test measures is a mark that teaches the wrong place to aim, and
	# nothing would report it.
	_check(mark.global_position.distance_to(door) < 0.001,
			"it stands ON the published doorstep (%.4f u away)"
					% mark.global_position.distance_to(door))
	_check(mark.visible, "and it is visible -- permanent, like the portals")

	# THE RING IS THE TRIGGER'S OWN SIZE. Read off the drawn TorusMesh, so
	# a marker drawn smaller than the circle it stands for cannot pass.
	var ring: MeshInstance3D = null
	var pad: MeshInstance3D = null
	var label: Label3D = null
	for child in mark.get_children():
		if child is Label3D:
			label = child
		elif child is MeshInstance3D:
			var mi: MeshInstance3D = child
			if mi.mesh is TorusMesh:
				ring = mi
			elif mi.mesh is CylinderMesh:
				pad = mi
	_check(ring != null and pad != null and label != null,
			"it has a ring, a pad and a label")
	if ring == null or pad == null or label == null:
		return
	var torus: TorusMesh = ring.mesh
	_check(absf(torus.outer_radius - HubWorld.CABIN_TAP_RADIUS) < 0.001,
			"the ring is exactly the tap radius (%.3f vs %.3f)"
					% [torus.outer_radius, HubWorld.CABIN_TAP_RADIUS])

	# THE INK, AGAINST THE THREE DOORS BESIDE IT -- read off the shipped
	# HubPortal.tscn rather than restated.
	var portal_ink := _portal_ink()
	_check(not portal_ink.is_empty(), "HubPortal.tscn's own ink could be read")
	if portal_ink.is_empty():
		return
	var ring_mat: StandardMaterial3D = ring.material_override
	var pad_mat: StandardMaterial3D = pad.material_override
	_check(ring_mat != null and pad_mat != null, "both surfaces carry a material")
	if ring_mat == null or pad_mat == null:
		return
	_check(ring_mat.albedo_color.is_equal_approx(portal_ink["ring"]),
			"the ring is the portals' amber (%s)" % ring_mat.albedo_color)
	_check(pad_mat.albedo_color.is_equal_approx(portal_ink["pad"]),
			"the pad is the portals' green (%s)" % pad_mat.albedo_color)
	_check(ring_mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"and it is UNSHADED, like every other surface out here")
	# ⚠️ AND IT IS NOT THE CABIN'S INDOOR INK. Stated as its own assertion
	# because the two constants sit six lines apart in one file, and the
	# way this breaks is a default argument left in place.
	_check(not ring_mat.albedo_color.is_equal_approx(CabinMarker.CABIN_RING_COLOR),
			"and NOT the cream it is drawn in indoors")
	# THE LIFTS ARE THE PLATEAU'S SMALL ONES. The cabin's clear a drawn
	# floor that wanders; this lawn is a flat plane and does not.
	_check(absf(pad.position.y - CabinMarker.HUB_PAD_LIFT) < 0.0001
			and absf(ring.position.y - CabinMarker.HUB_RING_LIFT) < 0.0001,
			"it lies on the lawn, not a fifth of a metre above it (pad %.3f, ring %.3f)"
					% [pad.position.y, ring.position.y])
	_check(label.text == HubWorld.CABIN_DOOR_LABEL,
			"the sign says what the doorstep is called (\"%s\")" % label.text)

	# THE APPROACH CUE, on the portals' own two thresholds and driven
	# through the REAL per-frame path rather than by poking set_near().
	var keepy: KeepyHopper = hub.get_node(
			"WorldViewport/SubViewport/World/Keepy") as KeepyHopper
	var was := keepy.global_position
	keepy.global_position = door
	hub.call("_pulse_cabin_markers", keepy.global_position)
	_check(bool(mark.get("_near")), "standing on it, the ring breathes")
	keepy.global_position = door + Vector3(
			HubWorld.CABIN_TAP_RADIUS * HubPortal.NEAR_RELEASE + 1.0, 0.0, 0.0)
	hub.call("_pulse_cabin_markers", keepy.global_position)
	_check(not bool(mark.get("_near")), "and stops once he walks away")
	keepy.global_position = was

## HubPortal.tscn's ring and pad colours, read off the SHIPPED scene.
func _portal_ink() -> Dictionary:
	var packed: PackedScene = load("res://scenes/HubPortal.tscn")
	if packed == null:
		return {}
	var portal: Node = packed.instantiate()
	var out: Dictionary = {}
	var ring := portal.get_node_or_null("Ring") as MeshInstance3D
	var pad := portal.get_node_or_null("Pad") as MeshInstance3D
	if ring != null and ring.get_surface_override_material(0) != null:
		out["ring"] = (ring.get_surface_override_material(0) as StandardMaterial3D).albedo_color
	if pad != null and pad.get_surface_override_material(0) != null:
		out["pad"] = (pad.get_surface_override_material(0) as StandardMaterial3D).albedo_color
	portal.free()
	return out if out.has("ring") and out.has("pad") else {}

## =====================================================================
## PHASE P -- HE CAN LIE ON THE BED, AND GET BACK UP
##
## ⚠️ THE POSITIVE FIRST, again: every refusal below ("a landing short of
## the bed does not lay him down", "a tap while resting does not walk
## him") passes for free against a bed that was never wired, so the bed is
## shown WORKING before any of them is asked.
func _phase_p_rest(interior: Node, controller: LevelController,
		walker: LevelWalker) -> void:
	print("")
	print("--- PHASE P: the bed can be lain on, and left ---")
	var bed: LevelHotspot = null
	for spot in controller.hotspots:
		if spot.kind == &"bed":
			bed = spot
	_check(bed != null, "the bed hotspot is held")
	var body: Node3D = walker.find_child("Body", true, false) as Node3D
	_check(body != null, "and his body is on the walker")
	if bed == null or body == null:
		return
	var loft: LevelDefinition = controller.levels[1]
	var link: LevelTransition = controller.links[0]
	controller.set_current(1)

	# THE POSITIVE: a tap on the bed from ACROSS THE LOFT arms the intent,
	# survives the landing that does not arrive, and lays him down on the
	# one that does.
	walker.global_position = loft.flat(Vector3(bed.point.x + 2.0, 0.0, bed.point.z))
	interior.call("_on_tapped_hotspot", bed, bed.point)
	_check(bool(interior.get("_rest_pending")), "tapping the bed arms the rest intent")
	_check(not bool(interior.get("_resting")), "and does NOT lay him down where he stands")
	# ⚠️ THE PASS-THROUGH LANDING. This is the owl batch's measured bug and
	# the third thing in this repository to copy the fix; asserted rather
	# than trusted, because its probe was green until a walk grew to two
	# hops.
	walker.global_position = loft.flat(Vector3(bed.point.x + 1.2, 0.0, bed.point.z))
	interior.call("_on_hop_landed", walker.global_position)
	_check(bool(interior.get("_rest_pending")),
			"a landing short of the bed KEEPS the intent")
	_check(not bool(interior.get("_resting")), "and has not laid him down")
	# AND THE LANDING THAT ARRIVES.
	walker.global_position = loft.flat(bed.point)
	interior.call("_on_hop_landed", walker.global_position)
	_check(bool(interior.get("_resting")), "landing at the bed lays him down")
	_check(not bool(interior.get("_rest_pending")), "and spends the intent")

	# THE POSE ITSELF, measured off the BODY rather than off the constants
	# that placed it.
	_check(absf(body.rotation_degrees.z - CabinInterior.REST_ROLL_DEGREES) < 0.001,
			"he is rolled onto his side (%.1f deg)" % body.rotation_degrees.z)
	_check(absf(body.rotation_degrees.x) < 0.001,
			"and NOT tipped onto his back -- that buries him and stands the tail up")
	# ⚠️ THE LIFT COMES OFF HIS X EXTENT because the roll put that axis
	# vertical. Checked on the DRAWN geometry: his lowest vertex has to
	# land on the bedding, exactly the way PHASE J checks him standing.
	var meshes: Array = _mesh_instances(body)
	interior.propagate_notification(CanvasItem.NOTIFICATION_TRANSFORM_CHANGED)
	var low: float = _lowest_drawn_y(meshes)
	var bed_y: float = (CabinInterior.BED_MODEL_Y + CabinInterior.CABIN_MODEL_OFFSET_Y) \
			* CabinInterior.CABIN_SCALE
	_check(absf(low - bed_y) < 0.01,
			"his lowest drawn vertex rests on the bedding (%.4f vs %.4f)" % [low, bed_y])
	# AND THE BEDDING IS NOT JUST THE FLOOR HE WALKS ON.
	_check(bed_y < loft.plane_y - 0.10,
			"which is BELOW the walking plane, in the bedding (%.4f under %.4f)"
					% [bed_y, loft.plane_y])
	# HE HAS NOT MOVED IN XZ. No teleport to watch: only the height moved.
	_check(Vector2(walker.global_position.x, walker.global_position.z)
			.distance_to(CabinInterior.BED_SPOT) < 0.001,
			"and he lies exactly where he stood, not somewhere better")

	# ⚠️ THE WITHDRAWAL -- the boat's, and the whole reason a second tap
	# can mean "get up". Both the bed AND the ladder, because the ladder is
	# the only other thing on this storey that answers.
	_check(not bed.accepts_tap(bed.point, 1), "the bed withdraws while he is in it")
	_check(not link.accepts_tap(link.entry_for(1), 1),
			"and so does the ladder -- nothing crosses storeys mid-nap")

	# THE WAY UP. A tap that FELL THROUGH to the ground path, which is what
	# a withdrawn hotspot produces.
	var before := walker.global_position
	interior.call("_on_tapped_ground", loft.flat(Vector3(0.0, 0.0, -1.0)))
	_check(not bool(interior.get("_resting")), "a tap gets him up")
	_check(absf(body.rotation_degrees.z) < 0.001, "the roll is undone")
	_check(absf(body.position.y - (-CabinInterior.KEEPY_MODEL_MIN_Y
			* CabinInterior.KEEPY_SCALE)) < 0.0001,
			"and he is lifted as a standing Keepy again (%.4f)" % body.position.y)
	interior.propagate_notification(CanvasItem.NOTIFICATION_TRANSFORM_CHANGED)
	low = _lowest_drawn_y(meshes)
	_check(absf(low - loft.plane_y) < 0.01,
			"standing back ON the loft, not in it (%.4f vs %.4f)" % [low, loft.plane_y])
	# ⚠️ AND THAT TAP DID NOT ALSO WALK HIM. One tap, one answer: the tap
	# that wakes him must not ALSO be spent as a destination, or getting up
	# would fling him across the loft.
	_check(walker.global_position.x == before.x
			and walker.global_position.z == before.z,
			"and it did not ALSO send him walking")
	_check(bed.accepts_tap(bed.point, 1), "the bed takes taps again")
	_check(link.accepts_tap(link.entry_for(1), 1), "and so does the ladder")

	# ONE MORE, AND IT IS THE ONE A LANDING-ONLY PATH WOULD MISS: tapping
	# the bed while ALREADY standing on it. A zero-length walk finishes in
	# _advance() with became_idle and NEVER emits hop_landed, so a version
	# wired only to the landing would do nothing at all here.
	walker.global_position = loft.flat(bed.point)
	interior.call("_on_tapped_hotspot", bed, bed.point)
	_check(bool(interior.get("_resting")),
			"tapping the bed while standing on it lies down on the spot")
	interior.call("_on_tapped_ground", loft.flat(Vector3(0.0, 0.0, -1.0)))
	_check(not bool(interior.get("_resting")), "and he gets up again")

## =====================================================================
## PHASE N -- THE MAGPIE, AND THE FOUR TRAPS THIS REPOSITORY HAS ALREADY
## PAID FOR
##
## GATED and not reported, because every way she fails is SILENT:
##
##   * the .glb never installed, or installed with the maps that an UNLIT
##     material cannot use -- 10.7 MB of dead payload, and nothing raises;
##   * her feet derived from a copied lift instead of from her own mesh --
##     the 0.9166 that shipped, where only a head showed above the boards;
##   * the tap honouring `destination` instead of the fixed stand spot --
##     Keepy kissing the air from wherever the clamp happened to drop him;
##   * an intent that a pass-through landing clears, or a zero-length walk
##     that spends nothing -- BOTH of which shipped on the door.
##
## ⚠️ IT ASSERTS THE POSITIVE BEFORE EVERY REFUSAL. "The magpie did not
## answer" and "no second kiss started" pass for FREE against a branch that
## was never wired, so the kiss is shown FIRING first and only then shown
## refusing. That is the blind-check discipline PHASE R and the hub's own
## probes carry, applied to the one phase in this file that could otherwise
## be green on a magpie nobody can talk to.
func _phase_n_magpie(interior: Node, controller: LevelController,
		walker: LevelWalker) -> void:
	print("")
	print("--- PHASE N: the magpie, the snap and the kiss ---")
	var magpie: LevelHotspot = null
	var door: LevelHotspot = null
	for spot in controller.hotspots:
		if spot.kind == &"magpie":
			magpie = spot
		elif spot.kind == &"door":
			door = spot
	_check(magpie != null, "the magpie is registered as a hotspot")
	_check(door != null, "and the door is still there beside her")
	if magpie == null or door == null:
		return
	var floor_level: LevelDefinition = controller.levels[0]
	var link: LevelTransition = controller.links[0]
	var body: Node3D = walker.find_child("Body", true, false) as Node3D
	_check(body != null, "his body is on the walker")
	if body == null:
		return

	# ---- SHE IS A THIRD `kind`, NOT A THIRD MECHANISM -------------------
	# LevelHotspot's own header names "a door, a bed, a chest": the generic
	# registry was already there, so this asserts she joined it rather than
	# that something new was built for her.
	_check(magpie.level_index == 0, "she stands on the ground floor")
	_check(absf(magpie.point.y - floor_level.plane_y) < 0.001,
			"her hotspot sits ON that floor (%.4f)" % magpie.point.y)
	_check(magpie.accepts_tap(magpie.point, 0), "a tap ON her means her")
	_check(not magpie.accepts_tap(magpie.point, 1),
			"and she does not answer at all from the loft")
	# The three things a tap on the ground floor can mean must not overlap.
	var door_gap: float = Vector2(magpie.point.x - door.point.x,
			magpie.point.z - door.point.z).length()
	_check(door_gap > magpie.tap_radius + door.tap_radius,
			"she and the door do not overlap (%.3f apart, radii sum %.3f)"
					% [door_gap, magpie.tap_radius + door.tap_radius])
	var ladder_gap: float = Vector2(magpie.point.x - link.point_a.x,
			magpie.point.z - link.point_a.z).length()
	_check(ladder_gap > magpie.tap_radius + link.tap_radius,
			"she and the ladder's foot do not overlap (%.3f apart, radii sum %.3f)"
					% [ladder_gap, magpie.tap_radius + link.tap_radius])

	# ---- THE BIRD HERSELF ------------------------------------------------
	var bird: Node3D = interior.get_node_or_null(
			"WorldViewport/SubViewport/World/Props/Magpie") as Node3D
	_check(bird != null, "the .glb was built into the scene")
	if bird == null:
		return
	_check(absf(bird.scale.x - CabinInterior.MAGPIE_SCALE) < 0.0001,
			"at the calibrated scale %.2f (%.3f)"
					% [CabinInterior.MAGPIE_SCALE, bird.scale.x])
	# HER FEET, off the LOWEST DRAWN VERTEX and not off her node position --
	# the node was never wrong when Keepy shipped sunk; the drawing was.
	var box: AABB = _world_aabb(bird)
	_check(absf(box.position.y - floor_level.plane_y) < 0.01,
			"her feet are ON the floor (%.4f vs %.4f)"
					% [box.position.y, floor_level.plane_y])
	# THE DEAD MAPS ARE GONE. Godot's glTF importer never binds a normal or
	# a metallic-roughness map on an UNLIT material -- measured, on this
	# very material -- so shipping them is payload that cannot reach a
	# pixel. This is the assertion that keeps them out.
	var mesh: MeshInstance3D = _find_mesh(bird)
	_check(mesh != null, "she draws one mesh")
	if mesh != null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		var mat: StandardMaterial3D = mesh.mesh.surface_get_material(0) as StandardMaterial3D
		_check(mat != null, "and carries a StandardMaterial3D")
		if mat != null:
			_check(mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
					"UNSHADED, like every other asset in this project")
			_check(mat.albedo_texture != null, "with its baked base colour kept")
			_check(mat.normal_texture == null and not mat.normal_enabled,
					"and NO normal map, which unlit cannot use")
			_check(mat.metallic_texture == null and mat.roughness_texture == null,
					"and no metallic-roughness map either")

	# ---- HER DRAWN HEIGHT MATCHES HIS, MEASURED ON BOTH SIDES -------------
	# ⚠️ NOT DERIVED FROM MAGPIE_SCALE'S OWN ARITHMETIC -- that would only
	# prove the constant multiplies correctly, not that it multiplies the
	# RIGHT number. Device found the earlier 0.50 pass reading as "comes up
	# to his shoulder"; this reads the REAL local AABB of both shipped
	# meshes, the same two readings (a standalone glTF parser and a headless
	# Godot probe) that agreed to the 6th significant figure when
	# MAGPIE_SCALE was derived, now gated so a future re-export of either
	# .glb cannot silently drift the pairing.
	var keepy_mesh: MeshInstance3D = _find_mesh(body)
	_check(keepy_mesh != null, "and Keepy's own body draws one mesh to compare against")
	if mesh != null and mesh.mesh != null and keepy_mesh != null and keepy_mesh.mesh != null:
		var her_drawn_height: float = mesh.mesh.get_aabb().size.y * CabinInterior.MAGPIE_SCALE
		var his_drawn_height: float = keepy_mesh.mesh.get_aabb().size.y * CabinInterior.KEEPY_SCALE
		_check(absf(her_drawn_height - his_drawn_height) < 0.01,
				"her drawn height (%.4f) now matches his (%.4f), not half of it"
						% [her_drawn_height, his_drawn_height])

	# ---- THE STAND SPOT IS SOMEWHERE HE CAN LEGALLY BE --------------------
	var stand := Vector3(CabinInterior.MAGPIE_STAND_SPOT.x, floor_level.plane_y,
			CabinInterior.MAGPIE_STAND_SPOT.y)
	_check(floor_level.contains(stand),
			"the stand spot is inside the walkable floor %s"
					% str(CabinInterior.MAGPIE_STAND_SPOT))
	_check(stand.is_equal_approx(floor_level.clamp_to(stand)),
			"and survives the clamp untouched -- it is not on an edge")
	# ⚠️ AND THE DOOR DOES NOT ANSWER FROM IT. He stands there for the whole
	# of a kiss; a doorstep that reached this far would breathe under him and
	# offer to end the visit every time he says hello.
	var door_reach: float = (CabinInterior.MAGPIE_STAND_SPOT
			- CabinInterior.DOOR_SPOT).length()
	_check(door_reach > CabinInterior.DOOR_REACH,
			"and stands clear of the doorstep (%.3f > %.3f)"
					% [door_reach, CabinInterior.DOOR_REACH])
	# She is NOT inside the walkable square, and that is deliberate: the
	# square is Keepy's, shrunk by his own half-width. A prop has no such
	# constraint, and the floor was measured flat out to x = -1.6.
	_check(not floor_level.contains(magpie.point),
			"SHE is outside his square, as a prop may be %s"
					% str(CabinInterior.MAGPIE_SPOT))

	# ---- AND CLEAR OF THE FOOTPRINT HOLE THE SIZE CORRECTION CUT ----------
	# A ground tap can never be handed a destination inside
	# MAGPIE_FOOTPRINT_RADIUS of her now (LevelDefinition's own hole, see its
	# header) -- the stand spot living inside that hole would make the kiss
	# snap him onto ground the level itself refuses to hand out as a
	# destination anywhere else.
	var magpie_ground := Vector3(CabinInterior.MAGPIE_SPOT.x, floor_level.plane_y,
			CabinInterior.MAGPIE_SPOT.y)
	var hole_clearance: float = stand.distance_to(magpie_ground) \
			- CabinInterior.MAGPIE_FOOTPRINT_RADIUS
	_check(absf(hole_clearance - 0.524) < 0.01,
			"and clears her footprint hole by %.3f (radius %.2f, want ~0.524)"
					% [hole_clearance, CabinInterior.MAGPIE_FOOTPRINT_RADIUS])

	# ---- AND A GROUND TAP AIMED AT HER FOOTPRINT NEVER LANDS THERE --------
	# LevelDefinition.clamp_to()'s hole push, exercised on the REAL floor
	# this cabin ships (floor_level itself), not a synthetic level built to
	# resemble it. Picked well clear of any square edge, so what is measured
	# is the HOLE subtracting ground and not a boundary coincidence --
	# MAGPIE_SPOT itself sits ON the square's own west edge, which would
	# make that particular point a bad witness for this.
	var aim_inside_hole := Vector3(-0.80, floor_level.plane_y, 0.90)
	_check(Vector2(aim_inside_hole.x, aim_inside_hole.z)
					.distance_to(CabinInterior.MAGPIE_SPOT) < CabinInterior.MAGPIE_FOOTPRINT_RADIUS,
			"the aim point really is inside her footprint radius, by construction")
	_check(not floor_level.contains(aim_inside_hole),
			"and the level refuses it as walkable ground")
	var pushed: Vector3 = floor_level.clamp_to(aim_inside_hole)
	var pushed_gap: float = Vector2(pushed.x, pushed.z).distance_to(CabinInterior.MAGPIE_SPOT)
	_check(absf(pushed_gap - (CabinInterior.MAGPIE_FOOTPRINT_RADIUS + 0.02)) < 0.001,
			"clamp_to() pushes it to exactly the rim margin instead (%.4f)" % pushed_gap)
	_check(floor_level.contains(pushed), "and the pushed point IS walkable ground")
	_check(absf(pushed.y - floor_level.plane_y) < 0.0001,
			"still at floor height, not lifted (%.4f)" % pushed.y)

	# ---- THE TAP DISCARDS `destination` -----------------------------------
	# ⚠️ PUT HIM BACK ON THE GROUND FLOOR FIRST. PHASE P leaves him on the
	# LOFT, and LevelWalker._flat() takes its height from whatever level the
	# controller says is current -- so without this the whole walk below
	# happens at 7.54 and every XZ-only assertion passes on a Keepy floating
	# a storey above the bird.
	controller.set_current(0)
	# THE CONTROL: he starts a real walk away from her, so what is measured
	# below is a snap and not "he was already there".
	var far := floor_level.flat(Vector3(2.20, 0.0, -1.50))
	walker.global_position = far
	# ⚠️ AND CLEAR THE TARGET PHASE P LEFT BEHIND. Its last act sends him
	# walking on the LOFT; moving the node does not cancel that, so without
	# this he would still be travelling to a point one storey up while this
	# phase measured where he ended.
	walker.hop_to(far)
	await _settle_walker(walker)
	walker.global_position = far
	_check(absf(walker.global_position.y - floor_level.plane_y) < 0.001,
			"he is back on the ground floor to begin with (%.4f)"
					% walker.global_position.y)
	interior.call("_refresh_proximity")
	var start_gap: float = Vector2(far.x, far.z).distance_to(
			CabinInterior.MAGPIE_STAND_SPOT)
	_check(start_gap > LevelWalker.ARRIVE_EPSILON,
			"he starts a REAL walk away from the stand spot (%.3f > %.3f)"
					% [start_gap, LevelWalker.ARRIVE_EPSILON])
	_check(not bool(interior.get("_kissing")), "and is not kissing")
	_check(not bool(interior.get("_kiss_pending")), "with no kiss intent standing")
	# The destination handed in is a LIE -- the far corner, nowhere near her.
	# The branch must throw it away. If it honoured it he would walk there
	# and kiss the air, which is the funnel bug wearing another hat.
	var lie := floor_level.flat(Vector3(-1.05, 0.0, 1.60))
	interior.call("_on_tapped_hotspot", magpie, lie)
	_check(bool(interior.get("_kiss_pending")),
			"tapping her arms the kiss intent")
	_check(not bool(interior.get("_kissing")),
			"and does NOT kiss her from across the room")

	# ---- A PASS-THROUGH LANDING KEEPS THE INTENT --------------------------
	# The owl batch's bug: an intent dropped at the first landing leaves him
	# standing beside the thing having never used it.
	var hops: int = 0
	while walker.state() != LevelWalker.State.IDLE and hops < 3 and not bool(interior.get("_kissing")):
		await get_tree().process_frame
		hops += 1
	if not bool(interior.get("_kissing")):
		_check(bool(interior.get("_kiss_pending")),
				"a pass-through landing KEEPS the intent")
	await _settle_walker(walker)
	var landed := Vector2(walker.global_position.x, walker.global_position.z)
	# ⚠️ MEASURED AGAINST ARRIVE_EPSILON AND NOT AGAINST ZERO. _advance()
	# stops a chain once the remainder is under ARRIVE_EPSILON, so he lands
	# NEAR the target and never ON it -- an exact-position assertion here
	# would have been red on correct code. What has to be true is the thing
	# _try_kiss() itself measures: he is inside MAGPIE_REACH of the spot.
	var to_spot: float = landed.distance_to(CabinInterior.MAGPIE_STAND_SPOT)
	_check(to_spot <= LevelWalker.ARRIVE_EPSILON,
			"he ends at the FIXED stand spot %s (%.3f <= %.3f)"
					% [str(landed), to_spot, LevelWalker.ARRIVE_EPSILON])
	_check(to_spot <= CabinInterior.MAGPIE_REACH,
			"which is the reach the kiss is gated on (%.3f <= %.3f)"
					% [to_spot, CabinInterior.MAGPIE_REACH])
	_check(landed.distance_to(Vector2(lie.x, lie.z)) > 1.0,
			"and nowhere near the destination he was handed (%.3f away)"
					% landed.distance_to(Vector2(lie.x, lie.z)))
	_check(bool(interior.get("_kissing")), "and arriving kisses her")
	_check(not bool(interior.get("_kiss_pending")), "spending the intent")
	# ⚠️ AND THE KISS SNAPS HIM THE REST OF THE WAY. Without it the gap
	# between the two of them would depend on which side he walked in from,
	# by up to ARRIVE_EPSILON either way -- from the far side that is closer
	# than his own muzzle is long. The bed snaps for the same reason.
	var snapped := Vector2(walker.global_position.x, walker.global_position.z)
	_check(snapped.distance_to(CabinInterior.MAGPIE_STAND_SPOT) < 0.001,
			"and the kiss SNAPS him onto the spot exactly %s" % str(snapped))
	_check(absf(walker.global_position.y - floor_level.plane_y) < 0.001,
			"without lifting him off the floor doing it (%.4f)"
					% walker.global_position.y)

	# ---- THE KISS ITSELF ---------------------------------------------------
	# ⚠️ THE LEAN IS POLLED, NOT SAMPLED. _apply_kiss rides a 4t(1-t) bell,
	# which is exactly ZERO at t = 0 -- and t = 0 is precisely where the
	# kiss is when the landing that started it returns. Reading it here on
	# the spot was red on correct code, the same family as the hearts.
	var peak: float = 0.0
	var leaned: int = Time.get_ticks_msec()
	while bool(interior.get("_kissing")) and Time.get_ticks_msec() - leaned < 6000:
		peak = maxf(peak, absf(body.rotation_degrees.x))
		if peak > 1.0:
			break
		await get_tree().process_frame
	_check(peak > 1.0, "he leans in (peak %.2f deg)" % peak)
	# THE WITHDRAWAL, the boat's and not the ladder's -- one tap, one signal.
	# Read through is_available(), never the field: LevelHotspot's header
	# warns that a second reader bypassing the accessor is how one field
	# starts giving two answers.
	_check(not magpie.is_available(), "she withdraws for the length of the kiss")
	_check(not magpie.accepts_tap(magpie.point, 0),
			"so a second tap cannot start a second kiss on top of this one")
	# ⚠️ THE LADDER IS DELIBERATELY NOT HELD. The bed holds it because the
	# bed shares a small square with the ladder's top; the kiss happens on
	# the ground floor, where the foot is far away -- and the gap asserted
	# above is what makes that a fact about the layout rather than a hope.
	_check(link.accepts_tap(link.entry_for(0), 0),
			"and the ladder is NOT held, being nowhere near her")
	# THE HEARTS. Sprite3D billboards on a tween, not particles: there is no
	# particle system anywhere in this repository and that is a written
	# decision, not an omission.
	var hearts: Node3D = interior.get_node_or_null(
			"WorldViewport/SubViewport/World/Props/Hearts") as Node3D
	_check(hearts != null, "the hearts holder was built")
	if hearts != null:
		var waited: int = Time.get_ticks_msec()
		while hearts.get_child_count() == 0 and Time.get_ticks_msec() - waited < 6000:
			await get_tree().process_frame
		_check(hearts.get_child_count() > 0,
				"and hearts rise during the kiss (%d)" % hearts.get_child_count())

	# ---- IT ENDS, AND EVERYTHING IT TOUCHED GOES BACK ----------------------
	await _settle_kiss(interior)
	_check(not bool(interior.get("_kissing")), "the kiss ends on its own")
	_check(absf(body.rotation_degrees.x) < 0.001, "the lean is undone")
	_check(absf(body.position.y - (-CabinInterior.KEEPY_MODEL_MIN_Y
			* CabinInterior.KEEPY_SCALE)) < 0.001,
			"and he is back at his standing lift (%.4f)" % body.position.y)
	_check(absf(body.position.z) < 0.001, "and back off his reach-in")
	_check(magpie.is_available(), "she takes taps again -- there is NO cooldown")
	if hearts != null:
		var freed: int = Time.get_ticks_msec()
		while hearts.get_child_count() > 0 and Time.get_ticks_msec() - freed < 8000:
			await get_tree().process_frame
		_check(hearts.get_child_count() == 0,
				"and every heart frees itself (%d left)" % hearts.get_child_count())

	# ---- THE SNAP, ON AN APPROACH THAT PROVABLY STOPS SHORT ---------------
	# ⚠️ THE APPROACH ABOVE DOES NOT DISCRIMINATE, and that was measured
	# rather than assumed: _begin_hop takes a last step of min(HOP_DISTANCE,
	# |delta|), so a walk whose remainder is between ARRIVE_EPSILON and
	# HOP_DISTANCE lands EXACTLY on its target and the snap has nothing to
	# do. He only stops short when a FULL hop leaves a remainder under
	# ARRIVE_EPSILON. This is such an approach.
	var short_far := floor_level.flat(Vector3(1.394, 0.0, -0.944))
	# THE CONTROL: the walker ALONE, with no magpie in it, on this exact
	# approach. Not a restatement of his arithmetic -- the real walk.
	walker.global_position = short_far
	walker.hop_to(stand)
	await _settle_walker(walker)
	var without: float = Vector2(walker.global_position.x,
			walker.global_position.z).distance_to(CabinInterior.MAGPIE_STAND_SPOT)
	_check(without > 0.01,
			"the walker ALONE stops SHORT of the spot on this approach (%.3f)"
					% without)
	# And now the same approach, through her.
	walker.global_position = short_far
	walker.hop_to(short_far)
	await _settle_walker(walker)
	walker.global_position = short_far
	interior.call("_on_tapped_hotspot", magpie, lie)
	await _settle_walker(walker)
	_check(bool(interior.get("_kissing")), "the same approach through her kisses")
	var with_snap: float = Vector2(walker.global_position.x,
			walker.global_position.z).distance_to(CabinInterior.MAGPIE_STAND_SPOT)
	_check(with_snap < 0.001,
			"and the kiss snaps him the rest of the way (%.3f -> %.3f)"
					% [without, with_snap])
	await _settle_kiss(interior)

	# ---- THE ZERO-LENGTH WALK, WHICH IS THE DOOR'S SHIPPED DEFECT ----------
	# ⚠️ THE CONTROL, and the claim means nothing without it: standing
	# anywhere else this would measure an ordinary walk, which was never
	# broken. LevelWalker._advance() ends a walk shorter than ARRIVE_EPSILON
	# with became_idle and NEVER with hop_landed, so a branch wired only to
	# the landing does nothing at all from here.
	walker.global_position = stand
	var zero: float = Vector2(walker.global_position.x,
			walker.global_position.z).distance_to(CabinInterior.MAGPIE_STAND_SPOT)
	_check(zero <= LevelWalker.ARRIVE_EPSILON,
			"he stands within a zero-length walk of her (%.3f <= %.3f)"
					% [zero, LevelWalker.ARRIVE_EPSILON])
	_check(magpie.accepts_tap(magpie.point, 0), "and she is asking to be tapped")
	interior.call("_on_tapped_hotspot", magpie, lie)
	_check(bool(interior.get("_kissing")),
			"tapping her while ALREADY standing there kisses on the spot")
	_check(not bool(interior.get("_kiss_pending")),
			"and leaves no kiss intent standing behind it")
	await _settle_kiss(interior)
	_check(not bool(interior.get("_kissing")), "and that one ends too")
	# REPEATABLE WITHOUT LIMIT: nothing is remembered between kisses, so the
	# third one is the first one again.
	interior.call("_on_tapped_hotspot", magpie, lie)
	_check(bool(interior.get("_kissing")),
			"and she can be kissed again immediately -- no counter, no cooldown")
	await _settle_kiss(interior)

	# ---- THE DOUBLE-DISPATCH RACE, THIS FILE'S OWN SHIPPED DEFECT ---------
	# ⚠️ THROUGH controller.dispatch(), NOT interior.call() directly -- every
	# check above this line calls _on_tapped_hotspot()/_on_tapped_ground()
	# straight, which is structurally blind to this bug: it never lets
	# LevelController's OWN routing decide where the SECOND of a pair of taps
	# lands. Godot's emulate_mouse_from_touch delivers one physical tap as
	# BOTH an InputEventScreenTouch release and a synthesised
	# InputEventMouseButton release, and CabinInterior._unhandled_input()
	# dispatches EACH one independently, in the same input pass.
	#
	# Reproduced on this exact path by a throwaway probe before the guard
	# below existed: 25 of 31 traced frames moved AWAY from the stand spot,
	# worst +0.3811 in one frame, ending exactly on MAGPIE_SPOT -- he was
	# yanked off his own kiss and walked onto her.
	controller.set_current(0)
	walker.global_position = stand
	interior.set("_kiss_pending", false)
	interior.set("_kissing", false)
	magpie.set_busy(false)
	interior.call("_refresh_proximity")
	_check(not bool(interior.get("_kissing")), "starting the race from outside a kiss")
	var race_camera: Camera3D = interior.get_node(
			"WorldViewport/SubViewport/World/Camera3D") as Camera3D
	var race_container: SubViewportContainer = interior.get_node(
			"WorldViewport") as SubViewportContainer
	var race_target: Vector2 = _to_screen(race_container, race_camera, magpie.point)
	# THE FIRST of the pair: standing within a zero-length walk of her, the
	# SAME immediate-entry branch the zero-length-walk check above already
	# proved fires -- shown once more here as the blind check this race
	# depends on, not assumed to still hold.
	controller.dispatch(race_target)
	_check(bool(interior.get("_kissing")),
			"the first of the pair enters the kiss immediately, as it must")
	_check(not magpie.is_available(), "which withdraws her, as it must")
	var held: Vector3 = walker.global_position
	# THE SECOND of the pair, the synthesised mouse release riding the same
	# physical tap: her hotspot is busy, so LevelController's own routing --
	# not this test's -- sends it down the ground path with a destination at
	# her own point. This is the race, reproduced through the real dispatch,
	# not asserted by construction.
	controller.dispatch(race_target)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bool(interior.get("_kissing")),
			"and the SECOND of the pair does not end the kiss it just started")
	var drift: float = walker.global_position.distance_to(held)
	_check(drift < 0.001,
			"nor drags him toward her one frame from the pose he was just snapped to (%.4f)"
					% drift)
	await _settle_kiss(interior)
	_check(not bool(interior.get("_kissing")),
			"and the kiss he was never yanked out of still ends on its own")

## Waits for the walker to actually stop, on a WALL-CLOCK budget rather than
## a frame count: a hop chain converges in TIME, and budgeting frames for it
## is exactly the flakiness LevelNavProbe's fade assertions were fixed for.
func _settle_walker(walker: LevelWalker, budget_ms: int = 12000) -> void:
	var started: int = Time.get_ticks_msec()
	while walker.state() != LevelWalker.State.IDLE and Time.get_ticks_msec() - started < budget_ms:
		await get_tree().process_frame

## Same, for the kiss tween. KISS_S is a duration, so this waits on the
## CONDITION and not on a count of frames that may each be 20 ms or 200.
func _settle_kiss(interior: Node, budget_ms: int = 12000) -> void:
	var started: int = Time.get_ticks_msec()
	while bool(interior.get("_kissing")) and Time.get_ticks_msec() - started < budget_ms:
		await get_tree().process_frame

## World point -> screen point, in the container's own space, inverting
## exactly what _handle_point does on the way in.
func _to_screen(container: SubViewportContainer, camera: Camera3D, world: Vector3) -> Vector2:
	var rect := container.get_global_rect()
	var viewport := camera.get_viewport() as SubViewport
	var local: Vector2 = camera.unproject_position(world)
	local.x *= rect.size.x / float(viewport.size.x)
	local.y *= rect.size.y / float(viewport.size.y)
	return local + rect.position

func _world_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c
		var a: AABB = mi.global_transform * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out

func _find_mesh(n: Node) -> MeshInstance3D:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		return c as MeshInstance3D
	return null


## =====================================================================
## PHASE Z -- THE FIRST TAP OF A VISIT, WHICH USED TO BE THROWN AWAY
##
## THE DEFECT THIS GATES, and it shipped: the door's branch of
## _on_tapped_hotspot called hop_to() and then armed _exit_pending, and
## ONLY _on_hop_landed could ever spend it. LevelWalker._advance() ends a
## walk shorter than ARRIVE_EPSILON (0.45) with became_idle and NEVER with
## hop_landed -- so standing within 0.45 of the doorstep, the tap did
## nothing at all and left the intent armed behind it.
##
## ⚠️ REACHABLE ON THE VERY FIRST TAP OF EVERY VISIT, because DOOR_SPOT is
## ENTRY_SPOT: he arrives standing exactly on it, distance 0.000. Not a
## corner case -- the default state of the room.
##
## The bed's branch has carried the immediate _try_rest() for this exact
## reason since it was written, with a ⚠️ comment naming the mechanism.
## The door simply never got its half.
##
## ⚠️ DRIVEN ON THE SCENE THE ROUTER ITSELF JUST LOADED, not on a fresh
## instance of it. That interior is the one a player is looking at one
## frame after tapping the doorstep outside, with the walker standing
## where the scene puts him -- so the thing measured is the real first tap
## and not a reconstruction of it.
##
## It runs LAST because leaving is a scene change: this phase hands the
## current scene back to the hub, and anything after it would be reading a
## tree that had just been replaced.
func _phase_z_first_tap(tree: SceneTree) -> void:
	print("")
	print("--- PHASE Z: the first tap of a visit leaves at once ---")
	var interior: Node = tree.current_scene
	if interior == null or interior.get_script() == null 			or interior.get_script().resource_path != "res://scripts/cabin/CabinInterior.gd":
		_check(false, "PHASE R left the interior current (nothing to drive)")
		return
	var controller: LevelController = interior.get_node_or_null(
			"LevelController") as LevelController
	var walker: LevelWalker = interior.get_node_or_null(
			"WorldViewport/SubViewport/World/Walker") as LevelWalker
	if controller == null or walker == null:
		_check(false, "the loaded interior carries a controller and a walker")
		return
	var door: LevelHotspot = null
	for spot in controller.hotspots:
		if spot.kind == &"door":
			door = spot
	if door == null:
		_check(false, "the loaded interior carries a door")
		return

	# THE CONTROL, and without it the assertion below means nothing: if he
	# were standing far from the door this would measure an ordinary walk,
	# which was never broken. The claim is that a ZERO-LENGTH walk works.
	var here := Vector2(walker.global_position.x, walker.global_position.z)
	var walk: float = here.distance_to(CabinInterior.DOOR_SPOT)
	_check(walk <= LevelWalker.ARRIVE_EPSILON,
			"he starts within a zero-length walk of the door (%.3f <= %.3f)"
					% [walk, LevelWalker.ARRIVE_EPSILON])
	_check(not bool(interior.get("_exit_pending")),
			"and with no exit intent standing")
	_check(not bool(interior.get("_leaving")), "and not already leaving")

	# THE TAP ITSELF, through the door's own branch.
	interior.call("_on_tapped_hotspot", door, door.point)
	_check(bool(interior.get("_leaving")),
			"tapping the door while ALREADY on it leaves at once")
	_check(not bool(interior.get("_exit_pending")),
			"and leaves no exit intent standing behind it")
	# Through is_available(), never the field: LevelHotspot's own header
	# warns that a second reader bypassing the accessor is how one field
	# starts giving two answers.
	_check(not door.is_available(),
			"and the door withdrew, so a second tap cannot re-ask")

