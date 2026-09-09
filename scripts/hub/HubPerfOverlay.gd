extends PanelContainer
class_name HubPerfOverlay
## Carte-blanche v3 P0 -- what the DEVICE is doing, on the device.
##
## Shows, every frame, what the DEVICE is actually doing: FPS, the
## triangles and draw calls the SubViewport really rendered this frame,
## and the weather state. Two independent readings of the same frame are
## published side by side, on purpose:
##
##   * `moteur`  -- RenderingServer.viewport_get_render_info() on the 3D
##                  SubViewport: primitives / draw calls / objects the
##                  renderer counted. This is the truth when the backend
##                  fills it in; the Compatibility renderer does on desktop
##                  GL and this file does NOT assume it does on WebGL2 --
##                  a 0 here is shown as 0, never hidden.
##   * `frustum` -- this script's own culling replay: every VisualInstance3D
##                  whose world AABB crosses the camera frustum (the exact
##                  test Godot uses, AABB::intersects_convex_shape) counts
##                  its triangles x instances. It is what the GPU is asked
##                  to draw, computed in GDScript, so it cannot read 0 on a
##                  backend that reports nothing.
##
## The scene-wide total (`scene`) is the number every journal table so far
## has quoted; the frame numbers beside it are what this lot was asked to
## replace it with.
##
## Display is gated by HubWorld on DevTools.enabled(). That gate is what
## keeps this file worth having past the branch that wrote it: the overlay
## is reachable on staging AND on production, against the build that
## actually shipped, by someone who asks for it in the URL -- and by no
## one else. Measuring the device rather than the sandbox was the point.

@export var viewport_path: NodePath
@export var camera_path: NodePath
@export var world_path: NodePath
@export var weather_path: NodePath
@export var label_path: NodePath
## CH36 -- Keepy himself, for the POS line. NodePath and not a typed node
## export, for the reason HubTapInput and HubCamera both give: a typed
## node export hand-written into a .tscn does not resolve at load.
@export var keepy_path: NodePath

## How often (frames) the tree walk and the engine counters are refreshed.
## The FPS line is updated every frame; the walk over ~400 nodes is cheap
## but there is no reason to pay it 60 times a second.
const REFRESH_FRAMES: int = 20
## Window, in seconds, over which the minimum FPS is kept.
const MIN_WINDOW_S: float = 3.0

var _viewport: SubViewport = null
var _camera: Camera3D = null
var _world: Node3D = null
var _weather: Node = null
var _label: Label = null
var _keepy: Node3D = null

var _frame: int = 0
var _tris_by_mesh: Dictionary = {}
var _fps_min: float = INF
var _fps_min_age: float = 0.0
var _last: Dictionary = {}

func _ready() -> void:
	_viewport = get_node_or_null(viewport_path) as SubViewport
	_camera = get_node_or_null(camera_path) as Camera3D
	_world = get_node_or_null(world_path) as Node3D
	_weather = get_node_or_null(weather_path)
	_label = get_node_or_null(label_path) as Label
	_keepy = get_node_or_null(keepy_path) as Node3D
	_ask_build()
	if _viewport == null or _camera == null or _world == null or _label == null:
		push_error("HubPerfOverlay: viewport_path, camera_path, world_path and label_path must all resolve.")
		set_process(false)

func _process(delta: float) -> void:
	_frame += 1
	var fps: float = Engine.get_frames_per_second()
	_fps_min_age += delta
	if fps < _fps_min or _fps_min_age > MIN_WINDOW_S:
		_fps_min = fps
		_fps_min_age = 0.0
	if _frame % REFRESH_FRAMES == 1 or _last.is_empty():
		_last = snapshot()
	_last["fps"] = fps
	_last["fps_min"] = _fps_min
	_label.text = _format(_last)

## The current readings as one dictionary -- what the overlay shows and
## what CozyCapture writes into its COZY_STATS line.
func snapshot() -> Dictionary:
	var out := {}
	var rid: RID = _viewport.get_viewport_rid()
	var kind := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	out["engine_prims"] = RenderingServer.viewport_get_render_info(rid, kind, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	out["engine_calls"] = RenderingServer.viewport_get_render_info(rid, kind, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	out["engine_objects"] = RenderingServer.viewport_get_render_info(rid, kind, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
	out["engine_total_prims"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	out["engine_total_calls"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var est := _frustum_estimate()
	out.merge(est)
	out["weather"] = _weather.call("kind_name") if _weather != null and _weather.has_method("kind_name") else "?"
	out["fps"] = Engine.get_frames_per_second()
	return out

## Replays Godot's own culling test on every visual instance under the
## world: a node is "in frame" when its world AABB is not fully outside
## any frustum plane. Triangles are counted per mesh once and cached by
## RID; a MultiMesh counts its mesh once per instance, which is what the
## GPU does when the batch is submitted.
func _frustum_estimate() -> Dictionary:
	var planes: Array[Plane] = _camera.get_frustum()
	var tris_frame: int = 0
	var tris_scene: int = 0
	var nodes_frame: int = 0
	var nodes_scene: int = 0
	var surfaces_frame: int = 0
	var instances_frame: int = 0
	var tris_frame_unweighted: int = 0
	var stack: Array[Node] = [_world]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var mesh: Mesh = null
		var count: int = 1
		if node is MultiMeshInstance3D:
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			mesh = mm.mesh
			count = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		elif node is MeshInstance3D:
			mesh = (node as MeshInstance3D).mesh
			if mesh == null:
				continue
		else:
			continue
		var visual := node as VisualInstance3D
		if not visual.is_visible_in_tree():
			continue
		var mesh_tris: int = _mesh_tris(mesh)
		var tris: int = mesh_tris * count
		tris_scene += tris
		nodes_scene += 1
		var box: AABB = visual.global_transform * visual.get_aabb()
		if _in_frustum(box, planes):
			tris_frame += tris
			tris_frame_unweighted += mesh_tris
			nodes_frame += 1
			surfaces_frame += mesh.get_surface_count()
			instances_frame += count
	return {
		"tris_frame": tris_frame,
		"tris_scene": tris_scene,
		"nodes_frame": nodes_frame,
		"nodes_scene": nodes_scene,
		"draw_est_frame": surfaces_frame,
		"instances_frame": instances_frame,
		"tris_frame_unweighted": tris_frame_unweighted,
	}

## AABB::intersects_convex_shape, the plane half of it: the corner of the
## box that lies furthest AGAINST each plane's normal is tested; if even
## that corner is over the plane, the whole box is outside.
static func _in_frustum(box: AABB, planes: Array[Plane]) -> bool:
	var half: Vector3 = box.size * 0.5
	var centre: Vector3 = box.position + half
	for plane in planes:
		var corner := Vector3(
			-half.x if plane.normal.x > 0.0 else half.x,
			-half.y if plane.normal.y > 0.0 else half.y,
			-half.z if plane.normal.z > 0.0 else half.z) + centre
		if plane.is_point_over(corner):
			return false
	return true

func _mesh_tris(mesh: Mesh) -> int:
	var key: RID = mesh.get_rid()
	if _tris_by_mesh.has(key):
		return _tris_by_mesh[key]
	var tris := 0
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			tris += (idx as PackedInt32Array).size() / 3
		else:
			var verts = arrays[Mesh.ARRAY_VERTEX]
			if verts != null:
				tris += (verts as PackedVector3Array).size() / 3
	_tris_by_mesh[key] = tris
	return tris

static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var k := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		k += 1
		if k % 3 == 0 and i > 0:
			out = " " + out
	return out

## CH36 -- WHICH BUILD IS ON SCREEN. CACHE_VERSION is an epoch stamped
## into index.service.worker.js at export time; CLAUDE.md already uses it
## as the cheapest discriminator of "which build is Vercel serving". It
## lived only in a file nobody can read from a phone, so the device
## measurement had no way to say which build produced its numbers.
##
## Read ASYNCHRONOUSLY into a window global and polled, rather than by a
## synchronous XHR: this runs inside the frame budget the overlay exists
## to measure, and a blocking fetch would corrupt the very FPS line above
## it. Off the web there is no JavaScriptBridge at all, so the line says
## so instead of erroring.
const BUILD_JS: String = "(function(){if(window.__keepy_build!==undefined)return;window.__keepy_build='...';fetch('index.service.worker.js').then(function(r){return r.text()}).then(function(t){var m=t.match(/CACHE_VERSION\\s*=\\s*[\"']([^\"']+)/);window.__keepy_build=m?m[1]:'absent'}).catch(function(){window.__keepy_build='unreachable'})})()"

func _ask_build() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval(BUILD_JS, true)

func _build_version() -> String:
	if not OS.has_feature("web"):
		return "hors-web"
	return str(JavaScriptBridge.eval("window.__keepy_build", true))

func _format(d: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("FPS %d  (min %d)" % [int(d.get("fps", 0)), int(d.get("fps_min", 0))])
	# GPU = what the renderer counted (opaque list, auto-LOD applied);
	# LOD0 = this script's frustum replay at full detail; scene = everything.
	lines.append("TRI gpu %s   lod0 cadre %s   scene %s" % [_thousands(int(d.get("engine_prims", 0))), _thousands(int(d.get("tris_frame", 0))), _thousands(int(d.get("tris_scene", 0)))])
	lines.append("DRAW calls %d  obj %d   cadre %d/%d  inst %s" % [int(d.get("engine_calls", 0)), int(d.get("engine_objects", 0)), int(d.get("nodes_frame", 0)), int(d.get("nodes_scene", 0)), _thousands(int(d.get("instances_frame", 0)))])
	# CH45: TOTAL = every viewport, 3D "TRI gpu" above included -- the only
	# line any 2D layer (HUD, overlay, a future minimap) shows up in at all.
	lines.append("TOTAL tri %s  calls %d" % [_thousands(int(d.get("engine_total_prims", 0))), int(d.get("engine_total_calls", 0))])
	lines.append("METEO %s" % str(d.get("weather", "?")))
	# CH57: the A/B marker. Mathieu measures F -- the ratio between this
	# repo's Xeon and his phone -- by reading FPS at one station with the
	# physics switch up and then down, and the ONE thing that reading
	# needs is to be certain which of the two it is looking at.
	#
	# `physMAX` is Performance.TIME_PHYSICS_PROCESS and it is labelled MAX
	# because CH56 section 2 measured what it actually is: a MAXIMUM
	# PUBLISHED ONCE A SECOND, not a per-tick cost -- it changed at most 4
	# times over 600 ticks. It is shown because it is free and it moves
	# when the mode changes; it is NOT the number F comes from. F comes
	# from the FPS line at the top.
	#
	# Read straight off the engine rather than through snapshot(): that
	# dictionary is what CozyCapture writes into COZY_STATS, and a new key
	# there would change a published line for a display-only addition.
	lines.append("PHYS %s  bodies %d  pairs %d  physMAX %.2f ms" % [
		"ON" if DevTools.physics_enabled() else "off",
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)),
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	if _keepy != null:
		var at: Vector3 = _keepy.global_position
		lines.append("POS x %.1f  z %.1f   zone %d" % [at.x, at.z, HubRegion.zone_of(at)])
	lines.append("BUILD %s" % _build_version())
	return "\n".join(lines)
