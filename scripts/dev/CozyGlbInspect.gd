extends Node
## Prints, for every GLB under assets/models/decor/, what Godot imported:
## surfaces, vertices, triangles, whether COLOR_0 survived, the first vertex
## colour (to tell linear from sRGB), the AABB and the material class.
## Headless is fine here: nothing is drawn.

func _ready() -> void:
	var dir := DirAccess.open("res://assets/models/decor")
	if dir == null:
		push_error("no decor dir")
		get_tree().quit(1)
		return
	dir.list_dir_begin()
	var names: Array[String] = []
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".glb"):
			names.append(name)
		name = dir.get_next()
	names.sort()
	for n in names:
		var packed: PackedScene = load("res://assets/models/decor/" + n)
		if packed == null:
			print("INSPECT %s LOAD_FAILED" % n)
			continue
		var scene := packed.instantiate()
		var meshes: Array[MeshInstance3D] = []
		_collect(scene, meshes)
		for mi in meshes:
			var mesh := mi.mesh
			var info := {"file": n, "node": mi.name, "surfaces": mesh.get_surface_count(), "aabb": [mesh.get_aabb().position, mesh.get_aabb().size]}
			var arrays: Array = mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			info["verts"] = verts.size()
			info["tris"] = idx.size() / 3
			var cols = arrays[Mesh.ARRAY_COLOR]
			info["has_color"] = cols != null
			if cols != null and (cols as PackedColorArray).size() > 0:
				var c: Color = (cols as PackedColorArray)[0]
				info["color0"] = [snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001)]
				info["color_mid"] = _fmt((cols as PackedColorArray)[(cols as PackedColorArray).size() / 2])
			var mat := mesh.surface_get_material(0)
			info["material"] = mat.get_class() if mat else "none"
			if mat is BaseMaterial3D:
				info["shading"] = (mat as BaseMaterial3D).shading_mode
				info["albedo"] = _fmt((mat as BaseMaterial3D).albedo_color)
				info["vertex_color_as_albedo"] = (mat as BaseMaterial3D).vertex_color_use_as_albedo
			info["xform"] = [mi.transform.origin, mi.transform.basis.get_scale()]
			print("INSPECT " + JSON.stringify(info))
		scene.free()
	get_tree().quit(0)

static func _fmt(c: Color) -> Array:
	return [snappedf(c.r, 0.001), snappedf(c.g, 0.001), snappedf(c.b, 0.001)]

func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)
