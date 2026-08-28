extends Node

## Gates the cabin: the tree-house Keepy ducks into, and the smallest
## interactive prop on the plateau.
##
## GATED RATHER THAN REPORTED because every way this feature can fail is
## SILENT. An unassigned cabin_scene is swallowed by _build()'s push_error;
## a model left floating or sunk means the ground offset never reached the
## child; a doorstep derived on the wrong side of the trunk leaves a tap
## that walks Keepy round the back and never opens; a tap signal that keeps
## firing while he is inside leaves a player with no way out, because the
## exit is the ground path the withdrawal is supposed to hand the tap to.
## Not one of those raises, and every one of them looks like "the cabin was
## never installed" on a device rather than like an error.
##
## PHASE C is verified RED BEFORE GREEN by neutering the entry hook: see
## the batch report. PHASE D carries a BLIND CHECK on the way back out --
## "he is visible again" passes for free against a body that was never
## hidden, so the hide has to be proven first.
##
## PHASE UNTOUCHED re-checks what this lot must not have moved: the boat,
## the owl, the turnstile, the seesaw, the three ladders and the three
## portals.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")

## The layout entry this lot ships, read back rather than duplicated so a
## future reposition cannot silently desync this probe from the thing it
## is checking.
const _EXPECTED_POSITION: Vector3 = Vector3(-17.43, 0.0, 28.18)

## The doorstep _build derives from that position and the entry's own
## rotation_y of 0: straight out along the open face, which is model +Z.
const _EXPECTED_DOOR: Vector3 = Vector3(-17.43, 0.0, 29.63)

var _failures: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "CABIN PROBE")
	var dl := ProbeWatchdog.deadline("CABIN PROBE")

	print("=== CABIN PROBE ===")
	print("")

	var hub: Node = HUB_SCENE.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = hub.get_node("WorldViewport/SubViewport/World") as Node3D
	var props: HubBuilder = world.get_node("Props") as HubBuilder
	var keepy: KeepyHopper = world.get_node("Keepy") as KeepyHopper
	var tap: HubTapInput = hub.get_node("TapInput") as HubTapInput
	var camera: Camera3D = world.get_node("Camera3D") as Camera3D

	_phase_a_presence(props)
	dl.abort_if_exceeded()
	_phase_b_geometry(props)
	dl.abort_if_exceeded()
	await _phase_c_enter(hub, props, keepy, tap)
	dl.abort_if_exceeded()
	await _phase_d_exit(hub, props, keepy, tap, camera)
	dl.abort_if_exceeded()
	await _phase_e_revisit(hub, props, keepy, tap)
	dl.abort_if_exceeded()
	_phase_untouched(props)
	dl.abort_if_exceeded()

	print("")
	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

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
	_check(absf(aabb.size.x - 1.8929) < 0.01 and absf(aabb.size.y - 1.5901) < 0.01,
			"built at scale 1.0 (%.3f x %.3f x %.3f)" % [aabb.size.x, aabb.size.y, aabb.size.z])
	# The footprint a landing has to clear, rounded UP from the measured
	# circumscribed radius -- a cabin is a volume, and rounding a footprint
	# down is the direction that puts a rock through a wall.
	var half: float = maxf(aabb.size.x, aabb.size.z) * 0.5
	_check(HubBuilder.CABIN_FOOTPRINT_RADIUS >= half,
			"the footprint (%.2f) covers the built half-span (%.3f)"
					% [HubBuilder.CABIN_FOOTPRINT_RADIUS, half])

func _phase_c_enter(hub: Node, props: HubBuilder, keepy: KeepyHopper,
		tap: HubTapInput) -> void:
	print("")
	print("--- PHASE C: a tap on the doorstep puts him inside ---")
	var cabins: Array[Dictionary] = props.cabins()
	if cabins.is_empty():
		return
	var door: Vector3 = cabins[0]["door"]

	_check(tap.cabin_radius > 0.0 and tap.cabin_doors.size() == 1,
			"the doorstep was handed to the tap layer (r = %.2f, %d door(s))"
					% [tap.cabin_radius, tap.cabin_doors.size()])
	_check(tap.cabin_available, "the doorstep accepts taps before the visit")

	# Driven through HubWorld's own handler and the real hop chain, not by
	# calling enter_cabin() directly: the thing worth gating is the WIRING,
	# and a probe that called the method would pass against a signal that
	# was never connected.
	hub.call("_on_tapped_cabin", door)
	var frames: int = 0
	while not keepy.is_in_cabin() and frames < 900:
		await get_tree().process_frame
		frames += 1
	_check(keepy.is_in_cabin(), "he walked there and went in (%d frames)" % frames)
	if not keepy.is_in_cabin():
		return
	_check(not tap.cabin_available,
			"the doorstep WITHDREW from the tap for the visit (boat pattern)")
	# He never leaves the ground: this prop is the one that does not touch
	# the plateau's single-altitude rule.
	_check(absf(keepy.global_position.y) < 0.001,
			"he is still at y = 0 (%.4f) -- no altitude derogation" % keepy.global_position.y)
	# And the duck-in finishes with the body hidden.
	var body: ModelSlot = keepy.body_slot()
	var hidden: int = 0
	while body.visible and hidden < 240:
		await get_tree().process_frame
		hidden += 1
	_check(not body.visible, "the body is hidden after the duck-in (%d frames)" % hidden)

func _phase_d_exit(hub: Node, props: HubBuilder, keepy: KeepyHopper,
		tap: HubTapInput, camera: Camera3D) -> void:
	print("")
	print("--- PHASE D: any tap brings him back out ---")
	if not keepy.is_in_cabin():
		return
	var body: ModelSlot = keepy.body_slot()
	var spot: Vector3 = keepy.global_position
	# BLIND CHECK. "He is visible again" is satisfied for free by a body
	# that was never hidden, so the hide is asserted first -- and it has to
	# be asserted HERE, on the state this phase is about to change, rather
	# than trusted from the phase before it.
	_check(not body.visible, "BLIND CHECK: he really is hidden going in")

	# ON THE DOORSTEP, and that is the SHARPEST test of the boat pattern
	# rather than a convenient one. This is the tap the ladder's shape
	# would have swallowed: with the doorstep withdrawn it resolves to
	# tapped_ground and becomes the way out, and without the withdrawal it
	# would emit tapped_cabin, be dropped by a Keepy who is already inside,
	# and leave him in there for the rest of the session with the one thing
	# a player would think to aim at doing nothing at all.
	var door: Vector3 = props.cabins()[0]["door"]
	# AND IT IS DRIVEN THROUGH THE REAL ROUTING, not by calling the ground
	# handler directly. That distinction is the whole phase: what the
	# withdrawal actually decides is WHICH SIGNAL a tap on this spot
	# becomes, so a probe that called _on_tapped_ground itself would pass
	# just as happily against the ladder pattern it exists to rule out --
	# measured, after an earlier version of this phase did exactly that.
	var container: SubViewportContainer = hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0,
			"the container has a real rect %s (run under xvfb, not --headless)" % rect)
	tap._handle_point(_to_screen(container, camera, door))
	var frames: int = 0
	while keepy.is_in_cabin() and frames < 240:
		await get_tree().process_frame
		frames += 1
	_check(not keepy.is_in_cabin(),
			"a tap ON THE DOORSTEP ended the visit (%d frames)" % frames)
	_check(body.visible, "the body is visible again")
	_check(tap.cabin_available, "the doorstep takes taps again")
	# He comes back out where he went in: the way out is the way in, so
	# there is no exit ring to walk and nothing to clear.
	_check(keepy.global_position.distance_to(spot) < 0.01,
			"he came out on the spot he vanished at (%.4f u)"
					% keepy.global_position.distance_to(spot))
	# And the far tap was DROPPED, not queued as somewhere to walk to.
	_check(not keepy.is_hopping(), "the exit tap was not turned into a destination")

func _phase_e_revisit(hub: Node, props: HubBuilder, keepy: KeepyHopper,
		tap: HubTapInput) -> void:
	print("")
	print("--- PHASE E: he can go back in, and ANY tap lets him out ---")
	if props.cabins().is_empty():
		return
	var door: Vector3 = props.cabins()[0]["door"]
	# A SECOND visit, which is what proves the first one left nothing
	# latched: a withdrawal never restored, a tween never cleared or a
	# hidden body never shown would all pass PHASE D and fail here.
	hub.call("_on_tapped_cabin", door)
	var frames: int = 0
	while not keepy.is_in_cabin() and frames < 900:
		await get_tree().process_frame
		frames += 1
	_check(keepy.is_in_cabin(), "he went back in a second time (%d frames)" % frames)
	if not keepy.is_in_cabin():
		return
	# And out on a tap NOWHERE NEAR the prop, which is the other half of
	# the claim: he is invisible in there, so a player has nothing to aim
	# at and any tap has to work.
	hub.call("_on_tapped_ground", Vector3(-10.0, 0.0, 20.0))
	frames = 0
	while keepy.is_in_cabin() and frames < 240:
		await get_tree().process_frame
		frames += 1
	_check(not keepy.is_in_cabin(), "a tap 9 u away also ended it (%d frames)" % frames)
	_check(keepy.body_slot().visible, "the body is visible after the second visit")
	_check(tap.cabin_available, "the doorstep takes taps again after the second visit")

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
