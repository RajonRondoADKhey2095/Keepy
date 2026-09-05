extends Node
## Carte-blanche capture probe (branch claude/carte-blanche-cozy).
##
## Loads the LIVE HubWorld.tscn, optionally moves Keepy to a requested
## point, waits for the camera to settle, then writes a PNG of what the
## real hub camera sees and a JSON line of draw statistics. It is the
## night's only in-engine visual control, so it runs under
## `xvfb-run ... --rendering-driver opengl3` (never --headless: the dummy
## driver renders black and places every MultiMesh at the origin).
##
## Own watchdog, no dependency on scripts/dev/ProbeWatchdog: a hard
## quit after MAX_FRAMES whatever happens, plus the shell's `timeout`.
##
## Args (after `--`):
##   --at=X,Z      put Keepy at (X, 0, Z) before capturing (default 0,0)
##   --out=PATH    PNG path (default /tmp/cozy_capture.png)
##   --frames=N    frames to wait before capturing (default 40)

const MAX_FRAMES: int = 2400

var _hub: Node = null
var _frames: int = 0
var _wait: int = 40
var _out: String = "/tmp/cozy_capture.png"
var _at: Vector3 = Vector3.ZERO
var _done: bool = false
## v2: --ride=x,z taps the boat at that point on frame 10; --frames is then
## the capture frame during the ride. Keepy's live position is reported.
var _ride: Vector3 = Vector3.INF
## v2: --walk=x,z taps the ground there on frame 10 (headless-safe: only
## transforms are read) and --nav prints HubRegion answers for the hollow.
var _walk: Vector3 = Vector3.INF
var _weather_force: int = -1
## --root captures the window (2D overlay included) instead of the SubViewport.
var _root: bool = false
var _ride_positions: Array = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var parts := arg.substr(5).split(",")
			if parts.size() == 2:
				_at = Vector3(float(parts[0]), 0.0, float(parts[1]))
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--frames="):
			_wait = int(arg.substr(9))
		elif arg.begins_with("--walk="):
			var wp := arg.substr(7).split(",")
			if wp.size() == 2:
				_walk = Vector3(float(wp[0]), 0.0, float(wp[1]))
		elif arg.begins_with("--weather="):
			_weather_force = ["sun", "rain", "storm", "snow"].find(arg.substr(10))
		elif arg == "--root":
			_root = true
		elif arg == "--nav":
			for q in [Vector3(0, 0, -62), Vector3(-28, 0, -38), Vector3(0, 0, -38), Vector3(0, 0, -60), Vector3(-34, 0, -38), Vector3(-25, 0, -33.5), Vector3(0, 0, -79)]:
				print("NAV %s contains=%s clamp=%s" % [q, HubRegion.contains(q), HubRegion.clamp_to(q)])
		elif arg.begins_with("--ride="):
			# "auto" taps wherever the mooring parked the boat at boot.
			_ride = Vector3.ZERO
	var packed: PackedScene = load("res://scenes/HubWorld.tscn")
	_hub = packed.instantiate()
	add_child(_hub)
	var keepy: Node3D = _hub.get_node_or_null("WorldViewport/SubViewport/World/Keepy")
	if keepy:
		keepy.global_position = _at
	var cam: Node = _hub.get_node_or_null("WorldViewport/SubViewport/World/Camera3D")
	if cam and cam.has_method("snap_to_target"):
		cam.call("snap_to_target")

func _process(_delta: float) -> void:
	_frames += 1
	if _done:
		return
	if _frames >= MAX_FRAMES:
		push_error("CozyCapture: watchdog fired at %d frames" % _frames)
		get_tree().quit(2)
		return
	if _frames == 2 and _weather_force >= 0:
		var w: Node = _hub.get_node("WorldViewport/SubViewport/World/CozyWeather")
		w.call("force", _weather_force)
		for i in 400:
			w.call("_process", 0.05)
	if _frames == 10 and _walk != Vector3.INF:
		_hub.get_node("TapInput").emit_signal("tapped_ground", _walk)
	if _walk != Vector3.INF and _frames % 60 == 0:
		var kw: Node3D = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
		_ride_positions.append([_frames, snappedf(kw.global_position.x, 0.01), snappedf(kw.global_position.y, 0.01), snappedf(kw.global_position.z, 0.01)])
	if _frames == 10 and _ride != Vector3.INF:
		_ride = _hub.get_node("Mooring").call("boat_position")
		print("RIDE_TAP at %s" % _ride)
		_hub.get_node("TapInput").emit_signal("tapped_boat", _ride)
	if _ride != Vector3.INF and _frames % 30 == 0:
		var k: Node3D = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
		_ride_positions.append([_frames, snappedf(k.global_position.x, 0.001), snappedf(k.global_position.y, 0.001), snappedf(k.global_position.z, 0.001), k.call("is_riding")])
	if _frames == _wait:
		_capture()

func _capture() -> void:
	_done = true
	var sub: SubViewport = _hub.get_node("WorldViewport/SubViewport")
	var rect: Vector2i = sub.size
	if rect.x <= 0 or rect.y <= 0:
		push_error("CozyCapture: degenerate viewport %s" % rect)
		get_tree().quit(3)
		return
	var image: Image = get_viewport().get_texture().get_image() if _root else sub.get_texture().get_image()
	if image == null:
		push_error("CozyCapture: no image (headless?)")
		var partial := {}
		_extras(partial)
		print("COZY_STATS " + JSON.stringify(partial))
		get_tree().quit(4)
		return
	var err := image.save_png(_out)
	var stats := _stats(_hub.get_node("WorldViewport/SubViewport/World"))
	stats["viewport"] = [rect.x, rect.y]
	stats["png"] = _out
	stats["png_error"] = err
	stats["keepy_at"] = [_at.x, _at.z]
	var keepy_now: Node3D = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
	stats["keepy_now"] = [snappedf(keepy_now.global_position.x, 0.001), snappedf(keepy_now.global_position.y, 0.001), snappedf(keepy_now.global_position.z, 0.001)]
	_extras(stats)
	# Blind check that the frame is not the dummy driver's black.
	var sample := image.get_pixel(rect.x / 2, rect.y / 2)
	stats["centre_pixel"] = [snappedf(sample.r, 0.001), snappedf(sample.g, 0.001), snappedf(sample.b, 0.001)]
	print("COZY_STATS " + JSON.stringify(stats))
	get_tree().quit(0)

func _extras(stats: Dictionary) -> void:
	stats["ride_trace"] = _ride_positions
	var bear: Node3D = _hub.get("_bear")
	if bear != null:
		stats["bear"] = [snappedf(bear.global_position.x, 0.01), snappedf(bear.global_position.z, 0.01)]
	var wnode: Node = _hub.get_node("WorldViewport/SubViewport/World/CozyWeather")
	stats["weather"] = wnode.call("kind_name")
	var gm: Material = (_hub.get_node("WorldViewport/SubViewport/World/Ground") as MeshInstance3D).get_surface_override_material(0)
	if gm is ShaderMaterial:
		stats["ground_tint"] = str((gm as ShaderMaterial).get_shader_parameter("weather_tint"))
		stats["ground_wet"] = (gm as ShaderMaterial).get_shader_parameter("wet")
	stats["overlay"] = str((_hub.get_node("WeatherOverlay") as ColorRect).color)

static func _surface_tris(mesh: Mesh) -> int:
	var tris := 0
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			tris += (idx as PackedInt32Array).size() / 3
		else:
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			tris += verts.size() / 3
	return tris

func _stats(root: Node) -> Dictionary:
	var mesh_nodes := 0
	var multi_nodes := 0
	var tris_mesh := 0
	var tris_multi := 0
	var instances := 0
	var surfaces := 0
	var per_multi := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MultiMeshInstance3D:
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			if mm and mm.mesh and (node as Node3D).is_visible_in_tree():
				multi_nodes += 1
				var t := _surface_tris(mm.mesh) * mm.instance_count
				tris_multi += t
				instances += mm.instance_count
				surfaces += mm.mesh.get_surface_count()
				per_multi[node.name] = [mm.instance_count, t]
		elif node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh and mi.is_visible_in_tree():
				mesh_nodes += 1
				tris_mesh += _surface_tris(mi.mesh)
				surfaces += mi.mesh.get_surface_count()
	return {
		"mesh_nodes": mesh_nodes,
		"multimesh_nodes": multi_nodes,
		"draw_calls_est": surfaces,
		"tris_mesh": tris_mesh,
		"tris_multimesh": tris_multi,
		"tris_total": tris_mesh + tris_multi,
		"multimesh_instances": instances,
		"per_multimesh": per_multi,
	}
