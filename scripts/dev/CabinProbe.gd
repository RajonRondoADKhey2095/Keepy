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
	_phase_i_interior()
	dl.abort_if_exceeded()
	await _phase_t_no_stray_entry(hub, props, keepy, tap, camera)
	dl.abort_if_exceeded()
	await _phase_f_no_funnel(hub, props, keepy, tap, camera)
	dl.abort_if_exceeded()
	_phase_untouched(props)
	dl.abort_if_exceeded()
	await _phase_s_spawn(tree)
	dl.abort_if_exceeded()
	# LAST, because it ROUTES: it replaces the scene the hub is standing
	# in, so every phase that needs the plateau has to have run already.
	await _phase_r_route(tree, hub, props, keepy)
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
	interior.queue_free()

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
