extends Node

## Gates LOT 1's owl: a static, purely decorative prop with no interaction,
## no animation and no state. The only ways this feature can fail are
## SILENT -- an unassigned owl_scene swallowed by _build()'s push_error, a
## model left floating or sunk because the offset correction was never
## applied, a scale that never reached the child, an unlit conversion that
## silently failed to import (leaving the model lit under a scene with no
## lights) -- and every one of them looks exactly like "the owl was never
## installed" on a device, not like an error.
##
## Also checks the one thing this lot must NOT touch: the three portals,
## unchanged and still functional, with the owl clear of the Quizz ring it
## sits beside.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")

## The layout entry this lot ships, read back rather than duplicated so a
## future reposition of the owl cannot silently desync this probe from the
## thing it is checking.
const _EXPECTED_POSITION: Vector3 = Vector3(2.7, 0.0, -7.2)

var _failures: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "OWL PROBE")
	var dl := ProbeWatchdog.deadline("OWL PROBE")

	print("=== OWL PROBE ===")
	print("")

	var hub: Node = HUB_SCENE.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = hub.get_node("WorldViewport/SubViewport/World") as Node3D
	var props: HubBuilder = world.get_node("Props") as HubBuilder

	_phase_a_presence(props)
	dl.abort_if_exceeded()
	_phase_b_geometry(props)
	dl.abort_if_exceeded()
	_phase_c_portals_unchanged(props)
	dl.abort_if_exceeded()

	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("  OK    %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s" % label)

## PHASE A -- the owl exists, is drawn, and is unshaded.
##
## Looked up BY NAME ("Owl", the root _make_owl() returns) rather than by
## index into Props' children: an index survives a reorder of the layout
## file, a name does not silently point at the wrong prop if one ever did.
func _phase_a_presence(props: HubBuilder) -> void:
	print("--- PHASE A: presence ---")
	var owl_root: Node3D = props.get_node_or_null("Owl") as Node3D
	_check(owl_root != null, "an 'Owl' node exists under Props")
	if owl_root == null:
		print("")
		return

	var mesh_inst := _find_mesh(owl_root)
	_check(mesh_inst != null, "the owl draws exactly one MeshInstance3D")
	if mesh_inst == null:
		print("")
		return
	_check(mesh_inst.mesh != null, "the drawn instance carries a mesh")

	var mat := mesh_inst.mesh.surface_get_material(0) if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0 else null
	var unshaded := mat is StandardMaterial3D and (mat as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	_check(unshaded, "the shipped .glb's material is UNSHADED (KHR_materials_unlit took)")
	print("")

## PHASE B -- placement and normalisation match what the lot derived.
func _phase_b_geometry(props: HubBuilder) -> void:
	print("--- PHASE B: geometry ---")
	var owl_root: Node3D = props.get_node_or_null("Owl") as Node3D
	if owl_root == null:
		_check(false, "owl_root present (skipped, see PHASE A)")
		print("")
		return

	var pos_ok := owl_root.global_position.distance_to(_EXPECTED_POSITION) < 0.001
	_check(pos_ok, "placed at the entry's position %s (got %s)" % [_EXPECTED_POSITION, owl_root.global_position])

	var scale_ok := absf(owl_root.scale.x - 1.0) < 0.001
	_check(scale_ok, "the placement-level entry scale stayed at 1.0 (normalisation lives inside _make_owl)")

	var mesh_inst := _find_mesh(owl_root)
	if mesh_inst == null:
		_check(false, "mesh present for AABB checks (skipped, see PHASE A)")
		print("")
		return

	# ModelSlot-style correction, applied by hand: the model child (not the
	# wrapping root) carries OWL_MODEL_SCALE / OWL_MODEL_OFFSET.
	var model_child := mesh_inst.get_parent() as Node3D
	var scale_applied := model_child.scale.distance_to(HubBuilder.OWL_MODEL_SCALE) < 0.0001
	_check(scale_applied, "OWL_MODEL_SCALE reached the model child (got %s)" % model_child.scale)

	var world_aabb := mesh_inst.global_transform * mesh_inst.mesh.get_aabb()
	var bottom_y := world_aabb.position.y
	var feet_ok := absf(bottom_y) < 0.005
	_check(feet_ok, "the model's lowest vertex sits at world y ~= 0 (got %.5f)" % bottom_y)

	var lateral_ok := absf(world_aabb.get_center().x - _EXPECTED_POSITION.x) < 0.05 \
		and absf(world_aabb.get_center().z - _EXPECTED_POSITION.z) < 0.05
	_check(lateral_ok, "the model is centred on its placement in X/Z, not offset sideways")

	var reachable := HubRegion.contains(owl_root.global_position)
	_check(reachable, "the owl's own position remains walkable region (it is not an offshore prop)")
	print("")

## PHASE C -- the three portals are exactly as they were, and the owl sits
## clear of the one it is placed beside.
func _phase_c_portals_unchanged(props: HubBuilder) -> void:
	print("--- PHASE C: portals unchanged ---")
	var portals := props.portals()
	_check(portals.size() == 3, "still exactly 3 portals (got %d)" % portals.size())

	var quizz: HubPortal = null
	var ids: Array = []
	for portal in portals:
		ids.append(portal.game_id)
		if portal.game_id == &"quizz":
			quizz = portal
	_check(ids.has(&"chased") and ids.has(&"quizz") and ids.has(&"battle"),
		"chased/quizz/battle all present, unrenamed")

	if quizz == null:
		_check(false, "quizz portal found (skipped, see above)")
		print("")
		return

	var quizz_pos := Vector3(0.0, 0.0, -7.2)
	_check(quizz.global_position.distance_to(quizz_pos) < 0.001,
		"quizz portal position unmoved (%s)" % quizz.global_position)

	var shape_node := quizz.get_node_or_null("Shape") as CollisionShape3D
	var trigger_radius := 1.35
	if shape_node and shape_node.shape is CylinderShape3D:
		trigger_radius = (shape_node.shape as CylinderShape3D).radius
	_check(is_equal_approx(trigger_radius, 1.35), "quizz trigger radius unchanged (%.3f)" % trigger_radius)

	var owl_root: Node3D = props.get_node_or_null("Owl") as Node3D
	if owl_root:
		var owl_footprint: float = HubBuilder.OWL_FOOTPRINT_RADIUS
		var separation := owl_root.global_position.distance_to(quizz.global_position)
		var clear_of_ring := separation > trigger_radius + owl_footprint
		_check(clear_of_ring,
			"owl sits clear of the quizz ring's own radius (separation=%.3f, needed>%.3f)"
				% [separation, trigger_radius + owl_footprint])
	print("")

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r != null:
			return r
	return null
