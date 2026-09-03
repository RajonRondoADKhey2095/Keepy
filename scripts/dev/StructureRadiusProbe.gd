extends Node
## Dev-only: MEASUREMENT ONLY, gates nothing. Measures the REAL footprint
## of an already-shipped staircase+platform structure (DivingBoard, the
## only structure in this repo with a ladder leading to a raised deck) to
## replace the never-measured "3.5u structure radius" guess used by
## CorridorFollowupProbe/CorridorABConfirmProbe for zipline-tower
## clearance verdicts.
##
## Pure transforms (individual MeshInstance3D nodes under each DivingBoard
## root, no MultiMesh involved) -- safe to run fully headless per
## CLAUDE.md's own doctrine on which probes may skip xvfb.
##
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/StructureRadiusProbe.tscn

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

func _ready() -> void:
	ProbeWatchdog.arm(self, "STRUCTURE RADIUS PROBE")
	print("=== STRUCTURE RADIUS PROBE (measurement only, gates nothing) ===")
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var builder: HubBuilder = hub.get_node("WorldViewport/SubViewport/World/Props")

	print("--- diving_boards() as published, %d entries ---" % builder.diving_boards().size())
	var boards: Array = builder.diving_boards()
	for i in boards.size():
		print("  [%d] %s" % [i, boards[i]])

	print("")
	print("--- Real mesh footprint of each built DivingBoard node ---")
	var root_world: Node3D = hub.get_node("WorldViewport/SubViewport/World")
	var props_node: Node = builder
	# add_child()'s default force_readable_name is FALSE: a name collision
	# (all three boards' root nodes are named "DivingBoard" by
	# _make_divingboard) makes Godot silently rename the 2nd/3rd to an
	# anonymous "@Node3D@N" instead of "DivingBoard2"/"3" -- confirmed by
	# dumping every Props child name, not assumed. So boards are matched
	# here by POSITION (node.position == the entry's own "ladder", set by
	# HubBuilder._build right before add_child) rather than by name.
	for entry in boards:
		var ladder_pt: Vector3 = entry.get("ladder", Vector3.INF)
		var found: Node3D = null
		for child in props_node.get_children():
			if child is Node3D and not (child is MultiMeshInstance3D) and not (child is Area3D):
				var c3 := child as Node3D
				if c3.position.distance_to(ladder_pt) < 0.001:
					found = c3
					break
		if found:
			_measure_board(found, entry)
		else:
			print("  no node found at ladder=%s" % ladder_pt)

	hub.queue_free()
	print("")
	print("=== END STRUCTURE RADIUS PROBE ===")
	get_tree().quit(0)

func _measure_board(board_root: Node3D, entry: Dictionary) -> void:
	var ladder: Vector3 = entry.get("ladder", Vector3.INF)
	var all_boxes: Array = []
	_collect_mesh_aabbs(board_root, all_boxes)
	if all_boxes.is_empty():
		print("  %s: no MeshInstance3D children found" % board_root.name)
		return

	# Combined XZ envelope of every mesh under this board, in world space.
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for box: AABB in all_boxes:
		min_x = minf(min_x, box.position.x)
		max_x = maxf(max_x, box.position.x + box.size.x)
		min_z = minf(min_z, box.position.z)
		max_z = maxf(max_z, box.position.z + box.size.z)

	var envelope_centre := Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)
	var half_x: float = (max_x - min_x) * 0.5
	var half_z: float = (max_z - min_z) * 0.5

	print("  %s  ladder(anchor point)=%s" % [board_root.name, ladder])
	print("    world XZ envelope: x=[%.4f, %.4f]  z=[%.4f, %.4f]  (half-extents %.4f x %.4f)" %
		[min_x, max_x, min_z, max_z, half_x, half_z])

	# Real radius, two ways: (a) max distance from the ladder foot (the
	# interaction anchor a player actually taps near) to any corner of the
	# envelope -- what a NEW structure's clear-ground requirement should
	# look like if modelled on this one; (b) same, from the envelope's own
	# geometric centre, for comparison.
	if ladder != Vector3.INF:
		var max_corner_dist_from_ladder: float = 0.0
		var corners: Array = [
			Vector2(min_x, min_z), Vector2(min_x, max_z),
			Vector2(max_x, min_z), Vector2(max_x, max_z),
		]
		var ladder_flat := Vector2(ladder.x, ladder.z)
		for c: Vector2 in corners:
			max_corner_dist_from_ladder = maxf(max_corner_dist_from_ladder, ladder_flat.distance_to(c))
		print("    max corner distance FROM LADDER FOOT = %.4fu  <-- real structure radius, ladder-anchored" % max_corner_dist_from_ladder)

	var centre_flat := Vector2(envelope_centre.x, envelope_centre.z)
	var max_corner_dist_from_centre: float = 0.0
	for box: AABB in all_boxes:
		var corners2: Array = [
			Vector2(box.position.x, box.position.z),
			Vector2(box.position.x + box.size.x, box.position.z + box.size.z),
		]
		for c2: Vector2 in corners2:
			max_corner_dist_from_centre = maxf(max_corner_dist_from_centre, centre_flat.distance_to(c2))
	print("    max corner distance from envelope CENTRE = %.4fu" % max_corner_dist_from_centre)

	print("    (%d mesh parts total under this node; rungs are batched via MultiMesh, not counted here -- thin cylinders, not the extent driver)" % all_boxes.size())

func _collect_mesh_aabbs(node: Node, out: Array) -> void:
	var mesh_inst := node as MeshInstance3D
	if mesh_inst and mesh_inst.mesh:
		var local_aabb: AABB = mesh_inst.mesh.get_aabb()
		var world_aabb: AABB = mesh_inst.global_transform * local_aabb
		out.append(world_aabb)
	for child in node.get_children():
		_collect_mesh_aabbs(child, out)
