extends Node
## Dev-only: MEASUREMENT ONLY, gates nothing. Locates the cabin, confirms
## the hub's orientation convention, and lists every candidate zone that
## could match Mathieu's visual reference (a pond + wooden dock + a
## cluster of tall pale-grey wooden pillars/"totems" + pines + a yellow
## flower), north (+Z, per HubRegion.gd's documented "north lobe" at
## (0, +35)) and on the OPPOSITE side of the plateau from the cabin.
##
## Headless-safe: pure geometry/layout reads, no pixel involved.
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/NorthZoneReconProbe.tscn

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

func _ready() -> void:
	ProbeWatchdog.arm(self, "NORTH ZONE RECON PROBE")
	print("=== NORTH ZONE RECON PROBE (measurement only, gates nothing) ===")
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var builder: HubBuilder = hub.get_node("WorldViewport/SubViewport/World/Props")

	print("--- Orientation convention ---")
	print("  HubRegion.north_lobe_centre() = %s  (documented: 'north lobe', (0,+35), CH16/HubRegion.gd -- north = +Z)" %
		[HubRegion.north_lobe_centre()])

	print("")
	print("--- Cabin (published cabins() accessor, as-built) ---")
	var cabins: Array[Dictionary] = builder.cabins()
	for i in cabins.size():
		print("  cabins()[%d] = %s" % [i, cabins[i]])
	var cabin_pos: Vector3 = Vector3.ZERO
	if cabins.size() > 0:
		cabin_pos = cabins[0].get("position", Vector3.ZERO)
	print("  cabin position = %s  (z=%.2f -> %s, x=%.2f -> %s)" %
		[cabin_pos, cabin_pos.z, ("NORTH" if cabin_pos.z > 0 else "SOUTH"),
		cabin_pos.x, ("EAST" if cabin_pos.x > 0 else "WEST")])
	print("  -> 'opposite side from the cabin' therefore reads as: EAST (since the cabin itself already sits in the north half, this cannot mean south-vs-north -- it has to be the X axis)")

	print("")
	print("--- Small pond (published pond_centre()/POND_WATER_RADIUS accessor) ---")
	print("  pond_centre() = %s   POND_WATER_RADIUS = %.4f" % [builder.pond_centre(), HubBuilder.POND_WATER_RADIUS])

	print("")
	print("--- Every &\"landmark\" entry (variant 0=spire, 1=cairn, 2=slabs/'totems'), split by hemisphere ---")
	for entry in builder.layout.props:
		if entry.get("type", &"") == &"landmark":
			var pos: Vector3 = entry.get("position", Vector3.ZERO)
			var variant: int = entry.get("variant", 0)
			var name: String = ["spire", "cairn", "slabs('totems')"][variant] if variant < 3 else "?"
			print("  variant=%d (%s) at %s  z=%.2f -> %s  x=%.2f -> %s" %
				[variant, name, pos, pos.z, ("NORTH" if pos.z > 0 else "SOUTH"),
				pos.x, ("EAST" if pos.x > 0 else "WEST")])

	print("")
	print("--- Every &\"pontoon\" entry (wooden dock), split by hemisphere ---")
	for entry in builder.layout.props:
		if entry.get("type", &"") == &"pontoon":
			var pos: Vector3 = entry.get("position", Vector3.ZERO)
			print("  pontoon at %s  z=%.2f -> %s  x=%.2f -> %s" %
				[pos, pos.z, ("NORTH" if pos.z > 0 else "SOUTH"), pos.x, ("EAST" if pos.x > 0 else "WEST")])

	print("")
	print("--- Every &\"pond\"/&\"lake\"/&\"greatlake\" body ---")
	for entry in builder.layout.props:
		var t: StringName = entry.get("type", &"")
		if t == &"pond" or t == &"lake" or t == &"greatlake":
			var pos: Vector3 = entry.get("position", Vector3.ZERO)
			print("  %s at %s  z=%.2f -> %s  x=%.2f -> %s" %
				[t, pos, pos.z, ("NORTH" if pos.z > 0 else "SOUTH"), pos.x, ("EAST" if pos.x > 0 else "WEST")])

	print("")
	print("--- Every &\"tree\" and &\"flower\" within 15u of the small pond (%s), for the 'sapins + petite fleur jaune' detail ---" % builder.pond_centre())
	var pond_flat := Vector2(builder.pond_centre().x, builder.pond_centre().z)
	for entry in builder.layout.props:
		var t2: StringName = entry.get("type", &"")
		if t2 == &"tree" or t2 == &"flower":
			var pos2: Vector3 = entry.get("position", Vector3.ZERO)
			var d: float = pond_flat.distance_to(Vector2(pos2.x, pos2.z))
			if d <= 15.0:
				print("  %s at %s  dist-to-pond=%.2f  (colour=%s)" % [t2, pos2, d, entry.get("colour", entry.get("color", "?"))])

	var driver: String = DisplayServer.get_name()
	if driver != "headless":
		await _phase_capture(hub, builder)
	else:
		print("")
		print("(driver=headless: skipping PHASE CAPTURE, no pixel can be read)")

	hub.queue_free()
	print("")
	print("=== END NORTH ZONE RECON PROBE ===")
	get_tree().quit(0)

## ---------------------------------------------------------------------
## PHASE CAPTURE -- renders the two candidate "totems" clusters that
## qualify as NORTH (z>0, per HubRegion's documented north-lobe
## convention) AND on the opposite (east) side from the cabin (west).
## Camera: the REAL in-game HubCamera pose (fixed rotation, OFFSET from
## Keepy's ground position) with Keepy actually standing there -- same
## technique as the point-A "real position" render, not a synthetic
## survey shot. The scene's fixed camera looks toward -Z (world), so
## Keepy is placed a few units NORTH of each landmark for it to appear
## ahead rather than behind.
func _phase_capture(hub: Node, builder: HubBuilder) -> void:
	print("")
	print("--- PHASE CAPTURE: two NORTH+EAST 'totems' candidates, real in-game camera ---")
	var keepy: Node3D = hub.get_node("WorldViewport/SubViewport/World/Keepy")
	var camera: Camera3D = hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	var viewport: SubViewport = hub.get_node("WorldViewport/SubViewport")
	var container: SubViewportContainer = viewport.get_parent() as SubViewportContainer
	var had_stretch: bool = container.stretch
	container.stretch = false
	viewport.size = Vector2i(1080, 1920)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame

	var candidates: Array = [
		{"name": "candidate1_totems_29_13_east", "landmark": Vector3(29.346, 0.0, 12.76)},
		{"name": "candidate2_totems_0_13_centre", "landmark": Vector3(0.6, 0.0, 12.6)},
	]
	for c in candidates:
		var landmark_pos: Vector3 = c["landmark"]
		var stand_pos: Vector3 = landmark_pos + Vector3(0.0, 0.0, 4.0) # a few u NORTH of the pillars, so they read ahead of the fixed south-facing camera
		keepy.global_position = stand_pos
		camera.global_position = Vector3(stand_pos.x, 0.0, stand_pos.z) + HubCamera.OFFSET
		await get_tree().process_frame
		await _render_and_save(viewport, "user://northzone_%s.png" % c["name"])

	container.stretch = had_stretch

func _render_and_save(viewport: SubViewport, out_path: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var err: int = image.save_png(out_path)
	print("  save_png(%s) -> %d  (globalized: %s)" %
		[out_path, err, ProjectSettings.globalize_path(out_path)])
