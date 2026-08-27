extends Node

## DIAGNOSTIC, not a gate. Answers ONE question: why the waterline reads
## correctly from the front and wrongly from every other angle.
##
## Reports, never asserts -- a diagnostic that fails a build has an opinion
## about the answer before it has measured it. It always exits 0.
##
## ===================================================================
## WHAT THE PREVIOUS BATCH COULD NOT SEE, and why
##
## Every capture it took was at ONE pose, and its edge metric was "wet/dry
## flips per screen column", which counts how CLEAN the waterline edge is.
## A body whose own triangles draw in the wrong order still has a clean
## edge wherever it draws -- the flips stay at 0.96 and the pose that was
## measured happens to be the one that is right. So the whole defect sat
## inside the one degree of freedom nobody swept.
##
## ===================================================================
## THE METRIC, and the one I had to THROW AWAY first
##
## The obvious metric is "every wet pixel is below every dry pixel", and it
## is WRONG. A horizontal world plane does not project to a horizontal
## screen row under a tilted camera: the recon measured y = 0.55 spreading
## 147 px across Keepy's own depth at this camera's -34 degrees. So screen
## row overlap has a legitimate floor of that size, and a sweep that read
## it as damage would be reporting the camera.
##
## It is still printed -- with that floor named -- because its SHAPE across
## azimuths is informative. It is not what anything is concluded from.
##
## What is concluded from is DIFFERENCE AGAINST A REFERENCE THAT HAS
## CORRECT DEPTH STATE, which no camera geometry enters:
##
##   dry  reference = the .glb's own StandardMaterial3D, i.e. exactly what
##                    the screen drew before this shader existed.
##   wet  reference = the same shader with its depth write restored.
##
## At tint_fraction 0 the shader's colour maths is ARITHMETICALLY the same
## expression as the material it replaced -- mix(a, a, x) is a. So a
## non-zero difference there cannot be a colour bug. It can only be render
## state, and that is the whole diagnosis in one number.
##
## ===================================================================
## HOW A PIXEL IS DECIDED TO BE HIS
##
## By rendering him ALONE against a background that is nothing like him:
## every other child of World is hidden and the environment is flattened to
## black with fog off. The alternative -- sampling a fixed box -- cannot
## work here, because the water he is standing in is the same turquoise the
## tint carries, so a box that spills off him reads the pond as Keepy.
##
## ===================================================================
## WET vs DRY
##
## The tint carries him 75% toward turquoise, so his blue channel overtakes
## his red one by a wide margin: measured on this asset, dry fur sits near
## b - r = -0.33 and tinted fur near +0.34. The classifier splits that gap
## at +0.10 and reports how many pixels land inside the gap, so a run where
## the separation stopped being clean says so instead of guessing.
##
## ===================================================================
## MUST RUN UNDER xvfb, NEVER --headless
##
## --headless forces the DUMMY driver: it compiles no shader and hands back
## a viewport that is not the shipped size, so every pixel read is a false
## green. The viewport is ASSERTED at 1080x1920 before anything is measured.

const AZIMUTHS: PackedFloat32Array = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

## Wet if blue leads red by this much. Halfway across the measured gap.
const WET_DISCRIMINANT: float = 0.10

## A pixel is his if it is not the flattened background.
const MASK_LUMA_FLOOR: float = 0.02

var _viewport: SubViewport = null
var _camera: Camera3D = null
var _world: Node3D = null
var _keepy: Node3D = null
var _yaw: Node3D = null
var _slot: ModelSlot = null
var _hidden: Array[Node3D] = []
var _shipped_material: Material = null
var _origin_material: Material = null
var _rows: Array[String] = []
var _ref_wet: ShaderMaterial = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "WATERLINE ORIENTATION PROBE")
	call_deferred("_run")

func _run() -> void:
	print("=== WATERLINE ORIENTATION PROBE ===")
	var scene: Node = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame

	var container := scene.get_node("WorldViewport") as SubViewportContainer
	# stretch forces the SubViewport to the container's size, so an explicit
	# size is ignored with only a warning and the aspect measured is the
	# window's. Off before anything is read.
	container.stretch = false
	_viewport = scene.get_node("WorldViewport/SubViewport") as SubViewport
	_viewport.size = Vector2i(1080, 1920)
	_world = scene.get_node("WorldViewport/SubViewport/World") as Node3D
	_camera = _world.get_node("Camera3D") as Camera3D
	_keepy = _world.get_node("Keepy") as Node3D
	_yaw = _keepy.get_node("Yaw") as Node3D
	_slot = _keepy.get_node("Yaw/Body") as ModelSlot

	# Nothing may move while pixels are being read.
	scene.set_process(false)
	scene.set_physics_process(false)
	for n in [_keepy, _camera]:
		n.set_process(false)
		n.set_physics_process(false)

	await _settle(4)
	print("  viewport = %dx%d  (asserted 1080x1920: %s)" % [
		_viewport.size.x, _viewport.size.y,
		"YES" if _viewport.size == Vector2i(1080, 1920) else "NO -- EVERY NUMBER BELOW IS VOID"])
	if _viewport.size != Vector2i(1080, 1920):
		_finish()
		return

	# The material is resolved LAZILY by HubWorld, on the first landing.
	# Without this call the slot still hands back the .glb's own
	# StandardMaterial3D and every number below would describe the material
	# this batch is investigating the REPLACEMENT of.
	scene.call("_set_keepy_wet", false)
	# _set_keepy_wet TWEENS the uniform over KEEPY_TINT_FADE_S, and a Tween
	# keeps running even with the node's processing off. The first sweep of
	# this probe wrote 0.75 into a uniform that a live tween was still
	# driving back to 0, and three azimuths came back with zero wet pixels
	# for that reason alone. Settled past the fade before anything is read.
	await _settle(30)
	_shipped_material = _slot.slot_material()
	print("  drawn material = %s" % _shipped_material.get_class())
	if _shipped_material is ShaderMaterial:
		print("  shader = %s" % (_shipped_material as ShaderMaterial).shader.resource_path)

	var mi := _drawn_instance()
	if mi != null:
		_origin_material = mi.mesh.surface_get_material(0)
	await _phase_d1()
	await _phase_d2()
	await _phase_d4()
	_finish()

# ===================================================================
# D1 -- the sweep nobody ran
# ===================================================================
func _phase_d1() -> void:
	print("")
	print("--- D1: EIGHT AZIMUTHS, WET AND DRY ---")
	print("  overlap = (bottom-most DRY row) - (top-most WET row), in px.")
	print("  NOT a defect score: a horizontal plane spans ~147 px of rows")
	print("  across Keepy's depth at this camera, so that much is geometry.")
	print("  diff = pixels differing from a depth-correct reference. THAT is")
	print("  the number, and it has no camera geometry in it.")
	for wet in [true, false]:
		print("")
		print("  %s" % ("IN WATER (tint_fraction 0.75)" if wet else "ON GRASS (tint_fraction 0.00)"))
		print("  %-5s %8s %8s %8s %9s %9s %9s" % [
			"yaw", "px", "wet", "dry", "overlap", "diff px", "max d"])
		for a in AZIMUTHS:
			_yaw.rotation_degrees.y = a
			_set_fraction(0.75 if wet else 0.0)
			var img := await _shot()
			var m := _classify(img)
			_slot.apply_material(_reference(wet))
			var ref := await _shot()
			_slot.apply_material(_shipped_material)
			var d := _diff(img, ref)
			print("  %-5.0f %8d %8d %8d %9s %9d %9.4f" % [
				a, m["px"], m["wet"], m["dry"],
				("n/a" if m["overlap"] == -9999 else str(m["overlap"])),
				d["count"], d["max"]])
			_rows.append("%s,%.0f,%d,%d,%d,%d,%d,%.4f" % [
				"wet" if wet else "dry", a, m["px"], m["wet"], m["dry"],
				m["overlap"], d["count"], d["max"]])

# ===================================================================
# D2 -- is the shader a no-op at tint_fraction 0?
# ===================================================================
## The question the previous batch never asked. HubWorld gates the tint to
## zero out of water, so if a dry Keepy still looks wrong the gate is not
## the suspect -- the shader is changing the picture at a fraction that is
## arithmetically a no-op, which can only be the RENDER STATE it brings
## with it and not the colour it computes.
##
## Compared against the material the .glb ships with, which is what the
## screen drew before c88de88.
func _phase_d2() -> void:
	print("")
	print("--- D2: IS THE DRY SHADER PIXEL-IDENTICAL TO THE MATERIAL IT REPLACED? ---")
	if _origin_material == null:
		print("  no drawn mesh instance; skipped")
		return
	print("  original = %s" % _origin_material.get_class())
	if _origin_material is StandardMaterial3D:
		var sm := _origin_material as StandardMaterial3D
		print("  original: transparency=%d cull_mode=%d depth_draw=%d shading=%d albedo=%s tex=%s" % [
			sm.transparency, sm.cull_mode, sm.depth_draw_mode, sm.shading_mode,
			sm.albedo_color, "yes" if sm.albedo_texture != null else "NULL"])

	for a in AZIMUTHS:
		_yaw.rotation_degrees.y = a
		_set_fraction(0.0)
		var shipped := await _shot()
		_slot.apply_material(_origin_material)
		var before := await _shot()
		_slot.apply_material(_shipped_material)
		var d := _diff(shipped, before)
		print("  yaw %-5.0f differing px = %-8d  max channel delta = %.4f" % [
			a, d["count"], d["max"]])

# ===================================================================
# D4 -- WHICH TERM of the shader is responsible
# ===================================================================
## Four variants of the SAME colour maths, differing only in render state.
## The colour each computes is identical, so any difference between their
## pictures is the state and nothing else -- which is the only way to tell
## a colour bug from a pipeline bug apart without guessing.
##
##   shipped            cull_disabled, writes ALPHA
##   no-alpha           cull_disabled, ALPHA left alone
##   depth_draw_always  cull_disabled, writes ALPHA, forces the depth write
##   cull_back          culls back faces, writes ALPHA
##
## Writing to ALPHA at all is what moves a spatial material into the
## transparent pass, and a transparent material does not write depth by
## default. With back faces also drawn, the far side of a closed body then
## paints over the near side in whatever order the index buffer happens to
## be in -- which is fixed, while which side is far is not. That is a
## mechanism that is wrong at some yaws and right at others, and this phase
## is what decides whether it is THIS one.
const _BODY_HEAD := """shader_type spatial;
render_mode unshaded, %s;
varying vec3 v_world;
uniform float water_y = 0.45;
uniform float tint_fraction : hint_range(0.0, 1.0) = 0.0;
uniform vec4 water_color : source_color = vec4(0.251, 0.878, 0.816, 1.0);
uniform sampler2D albedo_texture : source_color;
void vertex() { v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	float submerged = step(v_world.y, water_y);
	ALBEDO = mix(tex.rgb, mix(tex.rgb, water_color.rgb, tint_fraction), submerged);
%s}
"""

func _variant(modes: String, alpha: bool) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = _BODY_HEAD % [modes, ("\tALPHA = tex.a;\n" if alpha else "")]
	var m := ShaderMaterial.new()
	m.shader = sh
	var src := _shipped_material as ShaderMaterial
	m.set_shader_parameter("albedo_texture", src.get_shader_parameter("albedo_texture"))
	m.set_shader_parameter("water_color", src.get_shader_parameter("water_color"))
	m.set_shader_parameter("water_y", src.get_shader_parameter("water_y"))
	m.set_shader_parameter("tint_fraction", 0.75)
	return m

func _phase_d4() -> void:
	print("")
	print("--- D4: WHICH RENDER-STATE TERM CARRIES THE DEFECT ---")
	if not (_shipped_material is ShaderMaterial):
		print("  shipped material is not a ShaderMaterial; skipped")
		return
	var variants := {
		"shipped(cull_disabled,ALPHA)": _variant("cull_disabled", true),
		"no-ALPHA(cull_disabled)": _variant("cull_disabled", false),
		"ALPHA+depth_draw_always": _variant("cull_disabled, depth_draw_always", true),
		"ALPHA+cull_back": _variant("cull_back", true),
	}
	print("  pixels differing from the depth-correct reference, per azimuth.")
	print("  Every variant computes the SAME colour; only render state differs.")
	var head := "  %-30s" % "variant"
	for a in AZIMUTHS:
		head += "%7.0f" % a
	print(head + "%9s" % "worst")
	for name in variants:
		var line := "  %-30s" % name
		var worst := 0
		for a in AZIMUTHS:
			_yaw.rotation_degrees.y = a
			_slot.apply_material(variants[name])
			var img := await _shot()
			_slot.apply_material(_reference(true))
			var ref := await _shot()
			var d: int = _diff(img, ref)["count"]
			line += "%7d" % d
			worst = maxi(worst, d)
		print(line + "%9d" % worst)
	_slot.apply_material(_shipped_material)

# ===================================================================
# machinery
# ===================================================================
## The depth-correct twin of whatever is being measured.
##
## Dry: the .glb's own material -- literally the picture this shader
## replaced, so "differs from it" and "changed the screen" are the same
## sentence. Wet: the shader with its depth write restored, which is the
## only thing the fix is allowed to change.
func _reference(wet: bool) -> Material:
	if not wet:
		return _origin_material
	if _ref_wet == null:
		_ref_wet = _variant("cull_disabled, depth_draw_always", true)
	_ref_wet.set_shader_parameter("tint_fraction", 0.75)
	return _ref_wet

func _drawn_instance() -> MeshInstance3D:
	for c in _slot.get_children():
		var found := _find_mesh(c)
		if found != null:
			return found
	return null

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return n as MeshInstance3D
	for c in n.get_children():
		var f := _find_mesh(c)
		if f != null:
			return f
	return null

func _set_fraction(v: float) -> void:
	if _shipped_material is ShaderMaterial:
		(_shipped_material as ShaderMaterial).set_shader_parameter("tint_fraction", v)

## Hides every sibling of Keepy and flattens the sky to black with fog off,
## so a pixel that is not black is his.
func _isolate() -> void:
	if not _hidden.is_empty():
		return
	for c in _world.get_children():
		if c == _keepy or c == _camera:
			continue
		if c is Node3D and (c as Node3D).visible:
			(c as Node3D).visible = false
			_hidden.append(c as Node3D)
	var we := _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = Color(0, 0, 0, 1)
		we.environment.fog_enabled = false
		we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		we.environment.ambient_light_color = Color(0, 0, 0, 1)

func _settle(frames: int) -> void:
	for i in frames:
		await RenderingServer.frame_post_draw

func _shot() -> Image:
	_isolate()
	await _settle(3)
	var img := _viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	# Cropped to him, and read as raw bytes below: a get_pixel() sweep of the
	# full 1080x1920 across every render in this file is ~99 million GDScript
	# iterations and simply does not finish. The crop is taken from the slot's
	# own visual_aabb() unprojected through the shipped camera, padded, so it
	# cannot be tuned to flatter a result.
	return img.get_region(_crop())

## Screen rect of the eight corners of what the slot draws, padded.
func _crop() -> Rect2i:
	var box := _slot.visual_aabb()
	var xf := _slot.global_transform
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var corner := xf * box.get_endpoint(i)
		var p := _camera.unproject_position(corner)
		lo = lo.min(p)
		hi = hi.max(p)
	var pad := 48.0
	var r := Rect2i(
		Vector2i(int(lo.x - pad), int(lo.y - pad)),
		Vector2i(int(hi.x - lo.x + pad * 2.0), int(hi.y - lo.y + pad * 2.0)))
	return r.intersection(Rect2i(Vector2i.ZERO, _viewport.size))

func _measure(azimuth: float, wet: bool) -> Dictionary:
	_yaw.rotation_degrees.y = azimuth
	_set_fraction(0.75 if wet else 0.0)
	var img := await _shot()
	return _classify(img)

func _classify(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var px := 0
	var n_wet := 0
	var n_dry := 0
	var gap := 0
	var top_wet := 1 << 30
	var bottom_dry := -1
	var floor_sum: int = int(MASK_LUMA_FLOOR * 255.0 * 3.0)
	var disc: int = int(WET_DISCRIMINANT * 255.0)
	var i := 0
	for y in h:
		for x in w:
			var r: int = data[i]
			var g: int = data[i + 1]
			var b: int = data[i + 2]
			i += 4
			if r + g + b <= floor_sum:
				continue
			px += 1
			var d: int = b - r
			if d > disc:
				n_wet += 1
				top_wet = mini(top_wet, y)
			elif d < -disc:
				n_dry += 1
				bottom_dry = maxi(bottom_dry, y)
			else:
				gap += 1
	var overlap := -9999
	if n_wet > 0 and n_dry > 0:
		overlap = bottom_dry - top_wet
	return {"px": px, "wet": n_wet, "dry": n_dry, "gap": gap, "overlap": overlap}

func _diff(a: Image, b: Image) -> Dictionary:
	var da := a.get_data()
	var db := b.get_data()
	var n: int = mini(da.size(), db.size())
	var count := 0
	var worst := 0
	var i := 0
	while i < n:
		var d: int = maxi(maxi(
			absi(da[i] - db[i]),
			absi(da[i + 1] - db[i + 1])),
			absi(da[i + 2] - db[i + 2]))
		if d > 1:
			count += 1
		worst = maxi(worst, d)
		i += 4
	return {"count": count, "max": float(worst) / 255.0}

func _finish() -> void:
	print("")
	print("CSV state,yaw,px,wet,dry,overlap,diff_px,max_delta")
	for r in _rows:
		print("CSV " + r)
	print("=== END ===")
	get_tree().quit(0)
