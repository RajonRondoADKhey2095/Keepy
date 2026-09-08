extends Node
## CH48 -- THE THUMBNAIL BAKER, AND THE LEGIBILITY LADDER THAT SIZES IT.
##
## =====================================================================
## WHY IT RENDERS THE BUILT WORLD AND NOT A FIXTURE
##
## CLAUDE.md, "un fixture qui diverge du reel sur un axe ne protege pas de
## cet axe": SubstituteModel.tscn imitated an imported model by its NODE
## STRUCTURE and not at all by its MATERIAL BINDING -- exactly the axis the
## defect lived on. A thumbnail baker that re-instantiated each .glb by
## hand would rebuild that trap: it would have to restate every scale,
## every lift, every material override and every yaw that HubBuilder,
## HubCritter and HubTransport apply, and any one of them retyped wrong
## would produce a picture of something the player never sees.
##
## So this tool builds `HubWorld.tscn` and photographs THE ENTITIES THE
## MAP ALREADY MARKS, in place, through the same shaders, with the same
## materials and at the same scales the hub gives them. It never
## instantiates a model, never copies a transform, and never names a path:
## it enumerates MinimapMarkers' own groups.
##
## =====================================================================
## HOW ONE THUMBNAIL IS TAKEN
##
## A dedicated SubViewport shares the hub's World3D and carries an
## ORTHOGRAPHIC camera whose cull_mask is one layer nothing else is on.
## The subject's VisualInstance3Ds are moved onto that layer for the
## duration of the shot and put back after, so the picture contains the
## subject and nothing else -- no neighbour, no ground, no scatter. That
## is the CLAUDE.md identification pass ("le reste en noir"), done by
## culling rather than by hiding thousands of nodes.
##
## THE MATTE IS TWO PASSES, not a colour key. The same frame is rendered
## against BLACK and against WHITE; a pixel the two agree on is subject,
## a pixel they differ on is background, and the difference IS the alpha
## (a = 1 - (white - black)). A key colour would eat any subject pixel
## that happened to be that colour -- and this world has a magenta-free
## palette by luck, not by rule.
##
## THE ANGLE IS THE GAME CAMERA'S OWN, and it is chosen once for all 22:
## HubCamera.OFFSET is (0, 7.6, 8.9), an elevation of 40.5 degrees, and
## the shot is taken from that direction expressed IN THE SUBJECT'S OWN
## YAW. So every thumbnail is the same three-quarter view a player already
## has of that entity when it faces him -- not a world-frame view, which
## would show one kart's flank and another's tail depending on where the
## grid left it.
##
## ⚠️ THIS SHADER HAS THREE TERMS THAT MOVE WITH THE CAMERA, AND THE FIRST
## RUN FOUND ALL THREE BY ASKING FOR ONE.
##
## The tool opened with a single assertion -- "the same subject shot from
## 5 u and from 9 u is one image" -- meant to prove the haze was off. It
## came back RED on 17 of 22, and unpicking it cost three separate causes,
## none of which was guessed:
##
##  1. THE WORLD WAS NOT FROZEN. Animals walk, karts roll, balloons bob:
##     two shots four frames apart are two poses. `get_tree().paused`.
##  2. `visibility_range_end` IS A DISTANCE CULL, and HubCritter puts one
##     on every animal mesh (CLAUDE.md: pure CPU culling in Compatibility).
##     A subject shot from beyond its own cull is not a dim picture, it is
##     NO picture. Switched off for the shot, restored after. That alone
##     took 16 reds to 6.
##  3. `haze` (length(view_pos)) AND `rim` (a view VECTOR rebuilt from
##     VIEW, which is position-based even under an orthographic camera)
##     are both real distance terms of the SHIPPED look. They cannot be
##     removed and still call the result "the real model".
##
## So the contract changed, and it changed to something truer: THE SHOT IS
## TAKEN AT THE GAME CAMERA'S OWN DISTANCE. HubCamera.OFFSET is
## (0, 7.6, 8.9), length 11.7034 u, and CLAUDE.md already records that this
## camera never approaches -- 11.703 u is the ONLY distance from which a
## player ever sees any of these entities. A thumbnail taken there is
## literally his own view of the thing.
##
## The haze is the one term deliberately switched off, and it is a stated
## choice rather than an oversight: at 11.7 u it mixes 9.8 % of pale sky
## into every subject, and the plan these icons sit on is already a light
## palette (measured: the painted bands run L 0.1996 to 0.9320). A map is
## a diagram, not a window; an atmospheric depth cue inside a 40 px icon
## buys nothing and costs contrast. `wind_amount` goes with it, for a
## different reason: it is driven by shader TIME, which the SceneTree's
## pause does not stop, so a sail left swaying makes two shots of one
## subject differ by a full channel (measured: peak 1.000 on the yacht).
##
## And the neutralisation is PROVEN rather than assumed, three ways:
## determinism at one distance, a paired haze-on/haze-off shot that must
## DIFFER, and a two-distance shot that must ALSO differ -- the last one
## being the blind check that says the comparison can see anything at all.
const LAYER: int = 1 << 19
const SS: int = 256
const LADDER: Array[int] = [16, 20, 24, 28, 32, 36, 40, 44, 48, 56, 64]
## THE bake distance: HubCamera.OFFSET's own length, asserted against it
## rather than retyped (CLAUDE.md: a fact is published once). The second
## distance exists only for the blind check below.
const DIST_B: float = 5.0
## The delivered cell, and the picture inside it. THUMB_PX is CH48's
## measured answer (PHASE 3b: the fidelity curve's return per pixel of cell
## falls below half its own opening rate between 32 and 36, so 32 is the
## last rung still paying its way); INNER leaves the plate's rim and its
## dark ring the outer three pixels.
const THUMB_PX: int = 32
const INNER_PX: int = 26
const SHEET_COLS: int = 8
const OUT_DIR: String = "user://ch48"
const SHEET_PATH: String = "res://assets/textures/ui/minimap_thumbs.png"

var _hub: Node = null
var _vp: SubViewport = null
var _cam: Camera3D = null
var _env: Environment = null
var _shots: Dictionary = {}
var _order: Array[String] = []
var _kind_of: Dictionary = {}
var _flattened: int = 0
var _red: int = 0
var _checks: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "CH48 THUMB BAKE")
	_hub = (preload("res://scenes/HubWorld.tscn") as PackedScene).instantiate()
	add_child(_hub)
	_run()

func _check(ok: bool, text: String) -> void:
	_checks += 1
	if not ok:
		_red += 1
	print("  [%s] %s" % ["OK " if ok else "RED", text])

func _run() -> void:
	await get_tree().process_frame
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	var hub_vp := _hub.get_node("WorldViewport/SubViewport") as SubViewport
	box.stretch = false
	hub_vp.size = Vector2i(1080, 1920)
	(_hub.get_node("WorldViewport/SubViewport/World/CozyWeather") as Node).call("force", 0)
	for _i in 30:
		await get_tree().process_frame

	print("=== CH48 THUMBNAIL BAKE ===")
	print("-- PHASE 0: the render surface --")
	var rect: Vector2 = get_viewport().get_visible_rect().size
	_check(rect.x > 0.0 and rect.y > 0.0, "root viewport is not degenerate: %s" % rect)

	_build_rig(hub_vp)
	_check(_vp.size.x == SS and _vp.size.y == SS, "bake viewport is %s" % _vp.size)

	_phase_inventory()
	await _phase_shoot()
	get_tree().paused = false
	_phase_ladder()
	_phase_fidelity()
	_phase_tones()
	_phase_wash()
	_phase_plate()
	_phase_mapsize(32)
	_phase_mapsize(40)
	_phase_write()

	print("")
	print("=== %d checks, %d red ===" % [_checks, _red])
	print("ALL GREEN" if _red == 0 else "FAILED")
	get_tree().quit(0 if _red == 0 else 1)

func _build_rig(hub_vp: SubViewport) -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SS, SS)
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	# AFTER add_child: a SubViewport given a World3D before it enters the
	# tree gets its own back when it does, and the shot would then be of an
	# empty world -- a black frame that mattes to zero coverage, which is
	# exactly why the coverage assertion below exists.
	_vp.world_3d = hub_vp.get_world_3d()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0, 0, 0, 1)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	_env.fog_enabled = false
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.environment = _env
	_cam.cull_mask = LAYER
	_cam.near = 0.05
	_vp.add_child(_cam)
	_cam.current = true

## ---- PHASE 1: what the map marks, and what it is made of -------------

func _phase_inventory() -> void:
	print("-- PHASE 1: the subjects, on the BUILT tree --")
	var sig_seen: Dictionary = {}
	for kind in [MinimapMarkers.PLAYER, MinimapMarkers.VEHICLE, MinimapMarkers.NPC]:
		var nodes: Array = get_tree().get_nodes_in_group(kind)
		print("  group %s : %d" % [kind, nodes.size()])
		for n in nodes:
			var s := n as Node3D
			if s == null:
				continue
			var vis: Array[VisualInstance3D] = _visuals(s)
			var tri: int = 0
			var sig: Array[String] = []
			for v in vis:
				var mi := v as MeshInstance3D
				if mi != null and mi.mesh != null:
					tri += _tris(mi.mesh)
					var rp: String = mi.mesh.resource_path
					sig.append(rp if rp != "" else "%s#%d" % [mi.mesh.get_class(), mi.mesh.get_rid().get_id()])
			sig.sort()
			var key: String = "|".join(sig)
			var id: String = _label(s, kind)
			_order.append(id)
			_kind_of[id] = kind
			var dup: String = ""
			if sig_seen.has(key) and key != "":
				dup = "  <== SAME MESH SET AS %s" % sig_seen[key]
			elif key != "":
				sig_seen[key] = id
			var ab: AABB = _bounds(s, vis)
			print("    %-12s cls=%-14s vis=%2d tri=%6d ext=(%.2f %.2f %.2f) vis_on=%s%s"
				% [id, s.get_class(), vis.size(), tri, ab.size.x, ab.size.y, ab.size.z,
					"y" if s.visible else "N", dup])
	_check(_order.size() == 22, "22 subjects enumerated (got %d)" % _order.size())
	var uniq: Dictionary = {}
	for id in _order:
		uniq[id] = true
	_check(uniq.size() == _order.size(),
		"every subject has its OWN label (%d labels for %d subjects)" % [uniq.size(), _order.size()])

## ⚠️ THE FIRST VERSION OF THIS FUNCTION COLLIDED, AND THE COLLISION READ
## AS A MEASUREMENT. CH46 already records that five of the 37 markers have
## no `.name` at all (Godot calls them `@Node3D@228`), so the fallback was
## "parent/class" -- and the bear and the badger are BOTH anonymous Node3Ds
## under `World`. Both got the label "World/Node3D", the second overwrote
## the first in `_shots`, and the separation matrix then reported the pair
## at 0.0000: two different meshes (5846 and 5623 triangles, the inventory
## says so on the line above) declared identical because they were the same
## stored image. A probe defect that looks exactly like a finding.
##
## The fallback is now the SCENE FILE the node was instantiated from --
## read off the built tree, never a path written here -- which is the one
## identity an anonymous node still carries.
func _label(n: Node3D, kind: StringName) -> String:
	var nm: String = n.name
	if kind == MinimapMarkers.NPC and n is HubCritter:
		var pc: Node = n.get_parent()
		return "" if pc == null else String(pc.name)
	if nm.begins_with("@"):
		var tag: String = _model_tag(n)
		var p: Node = n.get_parent()
		nm = tag if tag != "" else "%s/%s" % ["?" if p == null else p.name, n.get_class()]
	return nm

## The .glb an anonymous node was built from: the first descendant that
## carries a `scene_file_path`, which for an imported model is the file
## itself. Measured off the tree, not looked up in a table.
func _model_tag(n: Node) -> String:
	if n.scene_file_path != "":
		return n.scene_file_path.get_file().get_basename().replace("keepy_", "").replace("_walker", "")
	for c in n.get_children():
		var t: String = _model_tag(c)
		if t != "":
			return t
	return ""

func _visuals(n: Node) -> Array[VisualInstance3D]:
	var out: Array[VisualInstance3D] = []
	var v := n as VisualInstance3D
	if v != null:
		out.append(v)
	for c in n.get_children():
		out.append_array(_visuals(c))
	return out

func _tris(m: Mesh) -> int:
	var t: int = 0
	for i in m.get_surface_count():
		var a: Array = m.surface_get_arrays(i)
		if a.is_empty():
			continue
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.size() > 0:
			t += idx.size() / 3
		else:
			var vtx: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			t += vtx.size() / 3
	return t

## The union of the subject's drawn geometry in WORLD space. An AABB is
## used here and only here -- CLAUDE.md forbids it for silhouette claims
## and this is a FRAMING term, where being conservative is the wanted
## behaviour.
func _bounds(root: Node3D, vis: Array[VisualInstance3D]) -> AABB:
	var out := AABB()
	var first: bool = true
	for v in vis:
		var local: AABB = v.get_aabb()
		var xf: Transform3D = v.global_transform
		for i in 8:
			var p: Vector3 = xf * local.get_endpoint(i)
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	if first:
		out = AABB(root.global_position, Vector3.ONE * 0.5)
	return out

## ---- PHASE 2: the shots ----------------------------------------------

func _phase_shoot() -> void:
	print("-- PHASE 2: 22 shots at the game camera's own distance --")
	# ⚠️ THE WORLD IS FROZEN FOR THE WHOLE PHASE, and the first run is why.
	# The two-distance assertion came back RED on 17 of 22 subjects because
	# animals walk, karts roll and balloons bob: two shots four frames apart
	# are two different poses, not two different distances.
	get_tree().paused = true
	var dist: float = HubCamera.OFFSET.length()
	_check(is_equal_approx(dist, sqrt(7.6 * 7.6 + 8.9 * 8.9)),
		"the bake distance IS HubCamera.OFFSET's length: %.4f u" % dist)
	for kind in [MinimapMarkers.PLAYER, MinimapMarkers.VEHICLE, MinimapMarkers.NPC]:
		for n in get_tree().get_nodes_in_group(kind):
			var s := n as Node3D
			if s == null:
				continue
			var id: String = String(MinimapMarkers.thumb_of(s))
			_check(id != "", "%-14s declares a thumbnail id" % _label(s, kind))
			if id == "":
				id = _label(s, kind)
			var a: Image = await _shoot(s, dist, true)
			var again: Image = await _shoot(s, dist, true)
			_check(a.get_data() == again.get_data(),
				"%-12s two shots at one distance are ONE image" % id)
			var cov: float = _coverage(a)
			_check(cov > 0.01 and cov < 0.95,
				"%-12s inks the frame, and does not fill it (coverage %.4f)" % [id, cov])
			_shots[id] = a
	_check(_flattened > 0, "%d materials were actually haze/wind-flattened" % _flattened)
	# ---- the two blind checks -------------------------------------------
	# Both ask the SAME comparison to say NO. Without them "one image" would
	# also be true of a comparison that cannot see anything -- and CH47's
	# own PHASE 4 shipped a 0/0 green for exactly that reason.
	print("  -- blind checks: the comparison must be able to say NO --")
	var probe_node: Node3D = get_tree().get_nodes_in_group(MinimapMarkers.VEHICLE)[1] as Node3D
	var near_shot: Image = await _shoot(probe_node, DIST_B, true)
	var d1: Array = _diff(_shots[_label(probe_node, MinimapMarkers.VEHICLE)], near_shot)
	_check(d1[0] > 0.02, "a %.1f u shot DIFFERS from the %.2f u one: %.4f of the box, peak %.3f"
		% [DIST_B, dist, d1[0], d1[1]])
	var hazy: Image = await _shoot(probe_node, dist, false)
	var d2: Array = _diff(_shots[_label(probe_node, MinimapMarkers.VEHICLE)], hazy)
	_check(d2[0] > 0.02, "haze LEFT ON differs from haze off: %.4f of the box, peak %.3f"
		% [d2[0], d2[1]])

## One shot. Everything it changes it changes back.
##
## ⚠️ THE FRAME IS FOUND BY RENDERING, NOT BY get_aabb(). The first version
## of this tool framed on the union of `VisualInstance3D.get_aabb()` and
## walked straight into the trap CLAUDE.md names: a Mixamo rig carries an
## `Armature` at scale 0.01, so the bear's mesh AABB read back through it
## measured 0.01 x 0.02 x 0.01 u for a body 1.6 u tall. The two rigged
## actors came out at coverage 1.0000 (the camera framed a box INSIDE the
## bear) and 0.0000. Neither error is visible in the code; both are
## obvious in the picture.
##
## So the subject is shot once inside a deliberately generous box, the INK
## BOUNDING BOX IS MEASURED OFF THE RENDERED PIXELS, the camera is re-aimed
## on it, and that is repeated once more. It is the drawn thing that sets
## the frame -- which is the same rule this repo already applies to
## silhouettes, applied to framing.
func _shoot(subject: Node3D, dist: float, flatten: bool) -> Image:
	var vis: Array[VisualInstance3D] = _visuals(subject)
	var saved_layers: Array[int] = []
	var saved_vis: Array[bool] = []
	var saved_over: Array = []
	var saved_surf: Array = []
	var saved_range: Array[float] = []
	for v in vis:
		saved_layers.append(v.layers)
		saved_vis.append(v.visible)
		v.layers = LAYER
		v.visible = true
		# ⚠️ visibility_range_end IS A DISTANCE TERM TOO, and it is the one
		# the repo deliberately uses (CLAUDE.md: pure CPU culling in
		# Compatibility with the fade DISABLED). HubCritter puts it on every
		# animal mesh. A subject photographed from 9 u with a cull at 8 u is
		# not the same picture as the same subject from 5 u -- it is no
		# picture at all -- so it is switched off for the shot and put back.
		var gi := v as GeometryInstance3D
		saved_range.append(0.0 if gi == null else gi.visibility_range_end)
		if gi != null:
			gi.visibility_range_end = 0.0
		var mi := v as MeshInstance3D
		saved_over.append(null if mi == null else mi.material_override)
		var per_surface: Array = []
		if mi != null and mi.mesh != null:
			# EVERY channel a material can reach a surface through, because
			# the haze lives on the shared decor shader and this repo has
			# already paid once for assuming a material arrives by only one
			# path (SubstituteModel: an author writes an override, an
			# importer writes on the mesh surface and never an override).
			if flatten:
				mi.material_override = _flatten(mi.material_override)
			for i in mi.get_surface_override_material_count():
				per_surface.append(mi.get_surface_override_material(i))
				var src: Material = mi.get_surface_override_material(i)
				if src == null and mi.mesh != null:
					src = mi.mesh.surface_get_material(i)
				var flat: Material = _flatten(src) if flatten else src
				if flat != src:
					mi.set_surface_override_material(i, flat)
		saved_surf.append(per_surface)
	# A bird is `visible = false` until Keepy is inside the crown, and a
	# hidden ANCESTOR hides the subject just as surely as a hidden subject.
	# Both are forced for the shot and both are put back.
	var chain: Array[Node3D] = []
	var chain_vis: Array[bool] = []
	var walk: Node = subject
	while walk != null and walk != _hub:
		var w3 := walk as Node3D
		if w3 != null:
			chain.append(w3)
			chain_vis.append(w3.visible)
			w3.visible = true
		walk = walk.get_parent()
	var yaw: float = subject.global_basis.get_euler().y
	var dir: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0.0, 7.6, 8.9).normalized()
	var centre: Vector3 = subject.global_position + Vector3(0.0, 1.5, 0.0)
	var half: float = 9.0
	var black: Image = null
	var white: Image = null
	for _pass in 3:
		_aim(centre, half, dir, dist)
		black = await _frame(Color(0, 0, 0, 1))
		white = await _frame(Color(1, 1, 1, 1))
		var box: Rect2i = _ink_bbox(black, white)
		if box.size.x <= 0 or box.size.y <= 0:
			break
		var per_px: float = (half * 2.0) / float(SS)
		var cx: float = float(box.position.x) + float(box.size.x) * 0.5 - float(SS) * 0.5
		var cy: float = float(box.position.y) + float(box.size.y) * 0.5 - float(SS) * 0.5
		centre += _cam.global_basis.x * (cx * per_px) - _cam.global_basis.y * (cy * per_px)
		half = maxf(float(maxi(box.size.x, box.size.y)) * per_px * 0.5 * 1.08, 0.05)
	for i in chain.size():
		chain[i].visible = chain_vis[i]
	for i in vis.size():
		vis[i].layers = saved_layers[i]
		vis[i].visible = saved_vis[i]
		var gi := vis[i] as GeometryInstance3D
		if gi != null:
			gi.visibility_range_end = saved_range[i]
		var mi := vis[i] as MeshInstance3D
		if mi != null:
			mi.material_override = saved_over[i]
			var per: Array = saved_surf[i]
			for k in per.size():
				mi.set_surface_override_material(k, per[k])
	return _matte(black, white)

## A copy of `src` with the DISTANCE HAZE switched off, or `src` itself
## when it carries no haze. cozy_decor.gdshader mixes toward haze_color by
## `length(view_pos)`, so without this the same subject is a different
## picture from 5 u and from 9 u -- which is precisely what the two-distance
## assertion asks, and precisely what it caught on the first run.
func _flatten(src: Material) -> Material:
	var sm := src as ShaderMaterial
	if sm == null or sm.shader == null or not _has_uniform(sm, &"haze_density"):
		return src
	var flat: ShaderMaterial = sm.duplicate() as ShaderMaterial
	flat.set_shader_parameter("haze_density", 0.0)
	# The sail's sway is driven by shader TIME, which SceneTree.paused does
	# not stop: two shots of one yacht differed by a FULL channel until this
	# line existed (peak 1.000, measured).
	flat.set_shader_parameter("wind_amount", 0.0)
	_flattened += 1
	return flat

## The bounding box of the pixels the two background passes DISAGREE about
## -- i.e. of everything that is not background. Read straight off the two
## frames rather than off a built matte, because this runs three times per
## shot per distance and a needless 65 k-pixel Image per call is the whole
## difference between a tool and a wait.
func _ink_bbox(black: Image, white: Image) -> Rect2i:
	var x0: int = SS
	var y0: int = SS
	var x1: int = -1
	var y1: int = -1
	for y in SS:
		for x in SS:
			var cb: Color = black.get_pixel(x, y)
			var cw: Color = white.get_pixel(x, y)
			if ((cw.r - cb.r) + (cw.g - cb.g) + (cw.b - cb.b)) / 3.0 < 0.5:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

func _has_uniform(m: ShaderMaterial, name: StringName) -> bool:
	for u in m.shader.get_shader_uniform_list():
		if StringName(u["name"]) == name:
			return true
	return false

## The camera, in the SUBJECT'S OWN YAW. Roll and pitch are dropped on
## purpose: a heeling yacht must not tilt its own portrait, and the angle
## is HubCamera.OFFSET's own -- 40.5 degrees of elevation, the view the
## player already has of that entity when it faces him.
func _aim(centre: Vector3, half: float, dir: Vector3, dist: float) -> void:
	_cam.global_transform = Transform3D().looking_at(-dir, Vector3.UP)
	_cam.global_position = centre + dir * dist
	_cam.size = half * 2.0
	_cam.far = dist + half * 4.0 + 4.0

func _frame(bg: Color) -> Image:
	_env.background_color = bg
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()

## a = 1 - (white - black); the black pass IS the premultiplied colour.
func _matte(black: Image, white: Image) -> Image:
	var w: int = black.get_width()
	var h: int = black.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var cb: Color = black.get_pixel(x, y)
			var cw: Color = white.get_pixel(x, y)
			var a: float = clampf(1.0 - ((cw.r - cb.r) + (cw.g - cb.g) + (cw.b - cb.b)) / 3.0, 0.0, 1.0)
			out.set_pixel(x, y, Color(cb.r, cb.g, cb.b, a))
	return out

## How far apart two shots are: the fraction of the box that differs at
## all, and the worst single-channel delta. A BOOLEAN would have said
## "different" for a cull and for a rounding bit alike; the pair of numbers
## says WHICH, and that is what turned the first run's red into a diagnosis.
func _diff(a: Image, b: Image) -> Array:
	var n: int = 0
	var peak: float = 0.0
	for y in a.get_height():
		for x in a.get_width():
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var d: float = maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)),
				maxf(absf(ca.b - cb.b), absf(ca.a - cb.a)))
			peak = maxf(peak, d)
			if d > 0.02:
				n += 1
	return [float(n) / float(a.get_width() * a.get_height()), peak]

func _coverage(img: Image) -> float:
	var n: int = 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return float(n) / float(img.get_width() * img.get_height())

## ---- PHASE 3: the legibility ladder ----------------------------------

func _phase_ladder() -> void:
	print("-- PHASE 3: the separation ladder --")
	var small: Dictionary = {}
	for s in LADDER:
		small[s] = {}
		for id in _order:
			small[s][id] = _down(_shots[id], s)
	# The floor: the SAME subject, downsampled twice by the same path. It
	# is a degenerate floor and it is printed as one -- what it proves is
	# that the metric is deterministic, not that the renderer is quiet.
	var floor_max: float = 0.0
	for id in _order:
		floor_max = maxf(floor_max, _sep_pix(small[LADDER[0]][id], _down(_shots[id], LADDER[0])))
	print("  metric floor (same subject, re-downsampled): %.4f" % floor_max)
	for s in LADDER:
		var worst: float = 1.0
		var worst_pair: String = ""
		var worst_rank: float = 1.0
		var worst_rank_pair: String = ""
		for i in _order.size():
			for j in range(i + 1, _order.size()):
				var a: String = _order[i]
				var b: String = _order[j]
				var d: float = _sep_pix(small[s][a], small[s][b])
				if d < worst:
					worst = d
					worst_pair = "%s/%s" % [a, b]
				if _kind_of[a] == _kind_of[b] and d < worst_rank:
					worst_rank = d
					worst_rank_pair = "%s/%s" % [a, b]
		print("  size %2d px : worst pair %.4f (%s)   worst same-kind %.4f (%s)"
			% [s, worst, worst_pair, worst_rank, worst_rank_pair])
	# The five brown quadrupeds, called out by the brief and answered here
	# whatever the answer is.
	print("  -- the five brown quadrupeds, pairwise, at each ladder size --")
	var brown: Array[String] = []
	for id in _order:
		if id in ["Boar", "Fawn", "Beaver", "Bear", "Badger", "Cat"]:
			brown.append(id)
	for id in _order:
		if _kind_of[id] == MinimapMarkers.NPC and not (id in brown) and not id.begins_with("Bird"):
			brown.append(id)
	print("  quadruped set: %s" % str(brown))
	for s in LADDER:
		var line: String = "  size %2d :" % s
		for i in brown.size():
			for j in range(i + 1, brown.size()):
				line += " %s/%s=%.3f" % [brown[i].substr(0, 3), brown[j].substr(0, 3),
					_sep_pix(small[s][brown[i]], small[s][brown[j]])]
		print(line)
	# The full matrix at three candidate sizes, so the weak pair is named
	# rather than hidden behind a minimum.
	for s in [24, 32, 40]:
		print("  -- full matrix at %d px (disagreement coverage) --" % s)
		for i in _order.size():
			var row: String = "    %-12s" % _order[i]
			for j in _order.size():
				row += " %.2f" % (0.0 if i == j else _sep_pix(small[s][_order[i]], small[s][_order[j]]))
			print(row)

## Downsample of a PREMULTIPLIED RGBA image. Premultiplied is what makes a
## plain filtered resize correct here: averaging straight (unassociated)
## colour across an edge would drag the background's colour into the fringe.
## Image.resize is the engine's own C++ resampler -- a hand-written box
## filter in GDScript over 22 subjects x 11 ladder sizes is 60 M pixel
## reads, which is the "sonde lente lue comme une sonde bloquee" trap.
func _down(src: Image, to: int) -> Image:
	var out: Image = Image.create_from_data(src.get_width(), src.get_height(),
		false, src.get_format(), src.get_data())
	out.resize(to, to, Image.INTERPOLATE_LANCZOS)
	return out

## How much of the box the two pictures DISAGREE on. Premultiplied, so a
## difference in shape and a difference in colour both land in it -- which
## is the point: CH47's metric was |coverage(A) - coverage(B)|, and two
## different silhouettes of the same area read 0.0000 on that.
func _sep_pix(a: Image, b: Image) -> float:
	var n: int = 0
	for y in a.get_height():
		for x in a.get_width():
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)),
					maxf(absf(ca.b - cb.b), absf(ca.a - cb.a))) > 0.06:
				n += 1
	return float(n) / float(a.get_width() * a.get_height())

## ---- PHASE 3b: the size, and the criterion that can actually name one --
##
## ⚠️ THE DISAGREEMENT MATRIX CANNOT NAME A MINIMUM SIZE, AND SAYING SO IS
## PART OF THIS LOT. Measured above: the worst same-kind pair reads 0.551
## at 16 px and 0.483 at 64 px -- it gets WORSE as the icon gets BIGGER,
## because at 16 px a larger share of the box is edge, where two subjects
## differ. A criterion that improves as the picture shrinks is not a
## legibility criterion. CH47 said the same thing in words ("la distinction
## reste mesuree en COUVERTURE, pas en perception"); this is the number.
##
## What DOES degrade monotonically is how much of the subject survives the
## downsample. Each thumbnail is downsampled to S, blown back up to the
## reference size, and compared with the reference: FIDELITY is the share
## of the box the two agree on. The floor is not invented -- it is the
## point at which the next rung of the ladder buys less than the metric's
## own noise, which is CLAUDE.md's rule that a delta under its floor is not
## a measurement.
func _phase_fidelity() -> void:
	print("-- PHASE 3b: reconstruction fidelity, the one curve that degrades --")
	var prev: float = -1.0
	for size in LADDER:
		var worst: float = 1.0
		var worst_id: String = ""
		var mean: float = 0.0
		for id in _order:
			var small: Image = _down(_shots[id], size)
			var back: Image = _down(small, SS)
			var f: float = 1.0 - _sep_pix(back, _shots[id])
			mean += f
			if f < worst:
				worst = f
				worst_id = id
		mean /= float(_order.size())
		var gain: String = "  --" if prev < 0.0 else "  +%.4f" % (worst - prev)
		print("  size %2d px : worst fidelity %.4f (%s)   mean %.4f%s"
			% [size, worst, worst_id, mean, gain])
		prev = worst

## ---- PHASE 3c: what these thumbnails are made of, in luminance --------
##
## The contrast study's raw material, and it is measured off the baked
## pixels rather than off any palette constant: for every thumbnail, the
## WCAG relative luminance of its ink, and how much of that ink clears
## 3.0:1 against each painted band the map can put it on.
func _phase_tones() -> void:
	print("-- PHASE 3c: the ink, in WCAG relative luminance --")
	var bands: Dictionary = {
		"GRASS": CozyPalette.GRASS_A, "AUTUMN": CozyPalette.AUTUMN_A,
		"MOOR": CozyPalette.MOOR_A, "LAWN": CozyPalette.LAWN_A,
		"SAND": CozyPalette.SAND_A, "SEABED": CozyPalette.SEA_BED,
		"SHALLOW": CozyPalette.SEA_SHALLOW_BED, "TRACK": Color(0.99, 0.97, 0.90)}
	print("  band luminances:")
	for k in bands:
		print("    %-8s L = %.4f" % [k, _wcag(bands[k])])
	print("  per subject: mean ink luminance, then the share of ink clearing 3.0:1 per band")
	var head: String = "    %-14s  Lmean " % "subject"
	for k in bands:
		head += " %-7s" % k
	print(head)
	for id in _order:
		var img: Image = _down(_shots[id], 40)
		var lsum: float = 0.0
		var n: int = 0
		var pass_n: Dictionary = {}
		for k in bands:
			pass_n[k] = 0
		for y in img.get_height():
			for x in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a < 0.9:
					continue
				# premultiplied -> straight, at a >= 0.9 the divide is safe
				var straight := Color(c.r / c.a, c.g / c.a, c.b / c.a)
				var l: float = _wcag(straight)
				lsum += l
				n += 1
				for k in bands:
					if _ratio(l, _wcag(bands[k])) >= 3.0:
						pass_n[k] = int(pass_n[k]) + 1
		var row: String = "    %-14s %.4f " % [id, 0.0 if n == 0 else lsum / float(n)]
		for k in bands:
			row += " %6.1f%%" % (0.0 if n == 0 else 100.0 * float(pass_n[k]) / float(n))
		print(row)

## ---- PHASE 3d: the wash sweep ----------------------------------------
##
## ⚠️ DESATURATION AT CONSTANT LIGHTNESS IS CONTRAST-NEUTRAL, and that is
## arithmetic rather than opinion: WCAG scores relative LUMINANCE, and
## pulling a colour toward its own grey moves its luminance by under 5 %
## (measured on this palette: GRASS_A 0.4717 fully saturated, 0.4491 fully
## grey). So the brief's two asks -- "desature les aplats" and "que les
## vignettes atteignent le plancher de contraste" -- are two different
## levers, and only one of them is desaturation.
##
## ONE operation serves both: a wash TOWARD WHITE. It drops chroma (which
## is what "les aplats sont vifs et dominent" is about) AND it raises the
## band's luminance, which is what a dark-ish thumbnail needs to clear
## 3.0:1. So the sweep below has one parameter, and it is derived here.
func _phase_wash() -> void:
	print("-- PHASE 3d: the wash toward white, swept --")
	var bands: Dictionary = {
		"GRASS": CozyPalette.GRASS_A, "AUTUMN": CozyPalette.AUTUMN_A,
		"MOOR": CozyPalette.MOOR_A, "LAWN": CozyPalette.LAWN_A,
		"SAND": CozyPalette.SAND_A, "SEABED": CozyPalette.SEA_BED,
		"SHALLOW": CozyPalette.SEA_SHALLOW_BED}
	var inks: Array[Image] = []
	for id in _order:
		inks.append(_down(_shots[id], 40))
	for wi in 11:
		var w: float = float(wi) * 0.1
		var worst_share: float = 1.0
		var worst_id: String = ""
		var closest: float = 999.0
		var closest_pair: String = ""
		var keys: Array = bands.keys()
		for a in keys.size():
			for b in range(a + 1, keys.size()):
				var d: float = _dist(_wash(bands[keys[a]], w), _wash(bands[keys[b]], w))
				if d < closest:
					closest = d
					closest_pair = "%s/%s" % [keys[a], keys[b]]
		var lmin: float = 9.0
		for k in keys:
			lmin = minf(lmin, _wcag(_wash(bands[k], w)))
		for i in _order.size():
			var share: float = _share_clearing(inks[i], bands, w)
			if share < worst_share:
				worst_share = share
				worst_id = _order[i]
		print("  w=%.1f  darkest band L %.4f  worst subject %5.1f%% of ink clears 3.0:1 (%s)  closest band pair %.4f (%s)"
			% [w, lmin, 100.0 * worst_share, worst_id, closest, closest_pair])

func _share_clearing(img: Image, bands: Dictionary, w: float) -> float:
	var n: int = 0
	var ok: int = 0
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.9:
				continue
			n += 1
			var l: float = _wcag(Color(c.r / c.a, c.g / c.a, c.b / c.a))
			var all_ok: bool = true
			for k in bands:
				if _ratio(l, _wcag(_wash(bands[k], w))) < 3.0:
					all_ok = false
					break
			if all_ok:
				ok += 1
	return 0.0 if n == 0 else float(ok) / float(n)

static func _wash(c: Color, w: float) -> Color:
	return Color(lerpf(c.r, 1.0, w), lerpf(c.g, 1.0, w), lerpf(c.b, 1.0, w))

static func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

## WCAG relative luminance -- linearised sRGB, NOT the Rec.709-on-sRGB
## shortcut MinimapProbe uses to ORDER tints. A contrast RATIO scored on
## unlinearised values is not a contrast ratio.
static func _wcag(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)

static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)

static func _ratio(l1: float, l2: float) -> float:
	return (maxf(l1, l2) + 0.05) / (minf(l1, l2) + 0.05)

## ---- PHASE 3e: the plate, and the contract a PICTURE can actually meet -
##
## ⚠️ A MULTICOLOURED PICTURE CANNOT CLEAR A CONTRAST FLOOR AS A WHOLE, and
## PHASE 3d proves it rather than asserting it: swept from w = 0.0 to
## w = 1.0, the WORST subject never gets above 2.6 % of its ink clearing
## 3.0:1 against every band at once. That is not a failure of the wash. A
## contrast RATIO is a property of one tone against one tone; a badger has
## white fur and a black mask, and whatever a band's luminance is, one of
## those two is close to it. 3.0:1 is a contract an ICON's fill can sign
## and a PHOTOGRAPH cannot.
##
## So the floor is carried by a DARK PLATE the thumbnail is drawn on, which
## is one tone and can sign it -- and the thumbnail's own job becomes
## contrast against THE PLATE, which is a fixed known tone rather than
## eight moving ones. Both halves are measured here.
func _phase_plate() -> void:
	print("-- PHASE 3e: the dark plate, and what the ink does against it --")
	var bands: Dictionary = {
		"GRASS": CozyPalette.GRASS_A, "AUTUMN": CozyPalette.AUTUMN_A,
		"MOOR": CozyPalette.MOOR_A, "LAWN": CozyPalette.LAWN_A,
		"SAND": CozyPalette.SAND_A, "SEABED": CozyPalette.SEA_BED,
		"SHALLOW": CozyPalette.SEA_SHALLOW_BED, "TRACK": Color(0.99, 0.97, 0.90)}
	var plate := Color(0.07, 0.08, 0.09)
	var lp: float = _wcag(plate)
	var worst: float = 99.0
	var worst_band: String = ""
	for k in bands:
		var r: float = _ratio(lp, _wcag(bands[k]))
		if r < worst:
			worst = r
			worst_band = k
	print("  plate %s  L = %.4f" % [plate.to_html(false), lp])
	print("  plate vs every painted band: worst %.2f:1 (%s)  -> floor 3.0:1 %s"
		% [worst, worst_band, "CLEARED" if worst >= 3.0 else "MISSED"])
	print("  per subject: share of ink clearing 3.0:1 AGAINST THE PLATE, and mean chroma")
	var chroma_sum: float = 0.0
	for id in _order:
		var img: Image = _down(_shots[id], 32)
		var n: int = 0
		var ok: int = 0
		var chroma: float = 0.0
		for y in img.get_height():
			for x in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a < 0.9:
					continue
				var straight := Color(c.r / c.a, c.g / c.a, c.b / c.a)
				n += 1
				chroma += maxf(maxf(straight.r, straight.g), straight.b) \
					- minf(minf(straight.r, straight.g), straight.b)
				if _ratio(_wcag(straight), lp) >= 3.0:
					ok += 1
		var mc: float = 0.0 if n == 0 else chroma / float(n)
		chroma_sum += mc
		print("    %-14s %6.1f%% of ink clears the plate   mean chroma %.4f"
			% [id, 0.0 if n == 0 else 100.0 * float(ok) / float(n), mc])
	var mean_chroma: float = chroma_sum / float(_order.size())
	print("  MEAN MARKER CHROMA over the 22 subjects: %.4f" % mean_chroma)
	# ---- the wash, derived from CHROMA rather than from contrast --------
	# "les aplats sont vifs et dominent visuellement les marqueurs" is a
	# statement about CHROMA, and chroma is exactly what a wash toward white
	# reduces: lerp(c, white, w) subtracts (1-w) from the spread, so a
	# band's chroma is (1 - w) x its own. The minimum w is therefore the one
	# that brings the LOUDEST band down to the markers' own mean.
	var loudest: float = 0.0
	var loud_name: String = ""
	for k in bands:
		var c: Color = bands[k]
		var ch: float = maxf(maxf(c.r, c.g), c.b) - minf(minf(c.r, c.g), c.b)
		if ch > loudest:
			loudest = ch
			loud_name = k
	print("  loudest band chroma: %.4f (%s)" % [loudest, loud_name])
	var need: float = maxf(0.0, 1.0 - mean_chroma / maxf(loudest, 0.0001))
	print("  MINIMUM WASH so no band out-shouts the mean marker: w = %.4f" % need)
	for wi in range(0, 11):
		var w: float = float(wi) * 0.05
		var closest: float = 999.0
		var pair: String = ""
		var keys: Array = bands.keys()
		for a in keys.size():
			for b in range(a + 1, keys.size()):
				var d: float = _dist(_wash(bands[keys[a]], w), _wash(bands[keys[b]], w))
				if d < closest:
					closest = d
					pair = "%s/%s" % [keys[a], keys[b]]
		print("    w=%.2f  loudest band chroma %.4f   closest band pair %.4f (%s)"
			% [w, (1.0 - w) * loudest, closest, pair])

## ---- PHASE 3f: how big the map has to be to carry 32 px thumbnails ----
##
## The frame is fixed (HubRegion.walkable_bounds(), 137 x 247 u) so the map
## size is exactly the scale: a taller plan spreads the same 37 markers
## over more pixels. What is swept here is the plan height, and what is
## counted is the thing a bigger cell breaks -- glyphs that OVERLAP.
## Same-kind neighbours fold into one glyph (CH47's leader clustering, the
## shipped rule, re-run here at the candidate reach); CROSS-KIND ones never
## fold, so they are the ones that collide.
func _phase_mapsize(cell: int) -> void:
	print("-- PHASE 3f: the smallest plan that carries a %d px thumbnail --" % cell)
	var frame: Rect2 = HubRegion.walkable_bounds()
	print("  frame %s   thumb cell %d px, reach %.1f px; a place keeps CH47's 4.0 px dot"
		% [frame, cell, float(cell) * 0.5])
	for h in [280, 300, 320, 340, 360, 380, 400, 440, 480]:
		var w: int = maxi(1, roundi(float(h) * frame.size.x / frame.size.y))
		var pts: Array = []
		for kind in MinimapMarkers.KINDS:
			var reach: float = 4.0 if kind == MinimapMarkers.PLACE else float(cell) * 0.5
			var here: Array = []
			for n in get_tree().get_nodes_in_group(kind):
				var sp := n as Node3D
				if sp == null:
					continue
				var u: float = (sp.global_position.x - frame.position.x) / frame.size.x
				var v: float = (frame.position.y + frame.size.y - sp.global_position.z) / frame.size.y
				here.append(Vector2(clampf(u * float(w), reach, float(w) - reach),
					clampf(v * float(h), reach, float(h) - reach)))
			# leader clustering at merge = 2 x reach, exactly the shipped rule
			var taken: Array[bool] = []
			for _i in here.size():
				taken.append(false)
			for i in here.size():
				if taken[i]:
					continue
				taken[i] = true
				for j in range(i + 1, here.size()):
					if not taken[j] and (here[j] as Vector2).distance_to(here[i]) <= 2.0 * reach:
						taken[j] = true
				pts.append({"at": here[i], "reach": reach, "kind": kind})
		var clash: int = 0
		var ink: float = 0.0
		var thumbs: int = 0
		for e in pts:
			# The PLATE's own footprint: a rounded square of side 2 x reach,
			# taken at 0.86 of the square (measured on the baked cell below).
			var r: float = float(e["reach"])
			ink += 0.86 * 4.0 * r * r
			if StringName(e["kind"]) != MinimapMarkers.PLACE:
				thumbs += 1
		var buried: int = 0
		for i in pts.size():
			for j in pts.size():
				if i == j:
					continue
				if j > i and (pts[i]["at"] as Vector2).distance_to(pts[j]["at"] as Vector2) \
						< float(pts[i]["reach"]) + float(pts[j]["reach"]):
					clash += 1
				# "buried" = this glyph's CENTRE is inside a glyph drawn
				# LATER, i.e. it is not merely touched, it is gone. Occlusion
				# by a later glyph is legitimate (DRAW_ORDER exists for it);
				# what is not legitimate is not knowing how much of it there
				# is. Keepy draws last and can never be buried.
				var oi: int = MinimapMarkers.KINDS.find(StringName(pts[i]["kind"]))
				var oj: int = MinimapMarkers.KINDS.find(StringName(pts[j]["kind"]))
				if oj <= oi:
					continue
				if (pts[i]["at"] as Vector2).distance_to(pts[j]["at"] as Vector2) < float(pts[j]["reach"]):
					buried += 1
					break
		var area: float = float(w) * float(h)
		print("  plan %3d x %3d px (%4.1f%% of canvas w, %.4f u/px) : %2d glyphs (%2d thumbs), ink %5.1f%% of plan, %2d buried, %2d touching"
			% [w, h, 100.0 * float(w) / 1080.0, frame.size.x / float(w),
				pts.size(), thumbs, 100.0 * ink / area, buried, clash])

## ---- PHASE 4: the sheet that ships -----------------------------------
##
## ONE PNG, 22 cells in MinimapMarkers.THUMBS order, straight alpha. The
## plate, the rim, the merged copy and the clamped box are all composed at
## RUNTIME from these cells (HubMinimap._bake_icons), so the sheet carries
## the one thing only a render can produce -- the picture -- and nothing
## that a constant in the widget can express. That also keeps CH46's single
## draw call intact: the cells are blitted into the same runtime atlas the
## plan already lives in, so there is still exactly one texture.
func _phase_write() -> void:
	print("-- PHASE 4: the sheet that ships --")
	var rows: int = int(ceil(float(MinimapMarkers.THUMBS.size()) / float(SHEET_COLS)))
	var sheet := Image.create(SHEET_COLS * THUMB_PX, rows * THUMB_PX, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var missing: Array[String] = []
	for i in MinimapMarkers.THUMBS.size():
		var id: String = String(MinimapMarkers.THUMBS[i])
		if not _shots.has(id):
			missing.append(id)
			continue
		var cell: Image = _down(_shots[id], INNER_PX)
		# premultiplied -> straight: the sheet is blended at runtime, and a
		# premultiplied sheet blended normally would darken every fringe.
		for y in INNER_PX:
			for x in INNER_PX:
				var c: Color = cell.get_pixel(x, y)
				if c.a > 0.003:
					cell.set_pixel(x, y, Color(c.r / c.a, c.g / c.a, c.b / c.a, c.a))
				else:
					cell.set_pixel(x, y, Color(0, 0, 0, 0))
		var pad: int = (THUMB_PX - INNER_PX) / 2
		sheet.blit_rect(cell, Rect2i(0, 0, INNER_PX, INNER_PX),
			Vector2i((i % SHEET_COLS) * THUMB_PX + pad, (i / SHEET_COLS) * THUMB_PX + pad))
	_check(missing.is_empty(), "every THUMBS id was shot (missing: %s)" % str(missing))
	var err: int = sheet.save_png(ProjectSettings.globalize_path(SHEET_PATH))
	_check(err == OK, "wrote %s (%d x %d)" % [SHEET_PATH, sheet.get_width(), sheet.get_height()])
	# The reference sheet at 128 px, for reading with human eyes only.
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var cols: int = 6
	var big_rows: int = int(ceil(float(_order.size()) / float(cols)))
	var big := Image.create(cols * 128, big_rows * 128, false, Image.FORMAT_RGBA8)
	big.fill(Color(0, 0, 0, 0))
	var k: int = 0
	for id in MinimapMarkers.THUMBS:
		if _shots.has(String(id)):
			big.blit_rect(_down(_shots[String(id)], 128), Rect2i(0, 0, 128, 128),
				Vector2i((k % cols) * 128, (k / cols) * 128))
		k += 1
	big.save_png("%s/master.png" % OUT_DIR)
	print("  reference sheet: %s" % ProjectSettings.globalize_path("%s/master.png" % OUT_DIR))
	print("  order: %s" % str(MinimapMarkers.THUMBS))
