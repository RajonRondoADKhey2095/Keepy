extends Node
## DIAGNOSTIC ONLY -- not a probe, no verdict, no exit code contract.
##
## Decomposes what PursuerContrastAudit's silhouette measurement is
## actually reading, so the 2.53 -> 1.85 drop can be attributed rather
## than guessed at. It reproduces that probe's own _freeze()/_measure()
## setup byte-for-byte where it matters (same lead, same pinning, same
## shader uniforms, same 180px box, same WCAG maths) and then reports,
## for one palette at a time:
##
##   * how much of the sampled box is actually the pursuer at all
##   * where the darkest and brightest pixels it scores on come FROM
##   * the same numbers with each decor contributor removed in turn
##
## Run:
##   xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
##     --path . res://scripts/dev/SilhouetteSampleDiag.tscn

const SETTLE_FRAMES: int = 24
const TEST_LEAD_S: float = 1.5
## TrackSegment's own ground albedo before any per-segment reroll.
const _GROUND_BASE: Color = Color(0.55, 0.42, 0.32)

var _game: Node3D
var _invert_rect: ColorRect
var _pursuer: Node3D
var _decor: Node3D
var _keepy: Node3D
var _env: Environment

## Startup snapshots. Both toggles below RESTORE from these rather than
## reconstructing a state, because both underlying values are rolled from
## an unseeded RNG and are therefore not recoverable once overwritten.
var _prop_initial_visibility: Dictionary = {}
var _ground_rolled_color: Dictionary = {}

func _ready() -> void:
	ProbeWatchdog.arm(self, "SilhouetteSampleDiag")
	print("=== SILHOUETTE SAMPLE DIAGNOSTIC ===")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_invert_rect = _game.get_node("DarkModeEffect/Invert")
	_pursuer = _game.get_node("World/Pursuer")
	_decor = _game.get_node_or_null("World/Decor")
	_keepy = _game.get_node_or_null("World/Keepy")
	var we := _game.get_node_or_null("World/WorldEnvironment") as WorldEnvironment
	_env = we.environment if we else null
	var dark_effect: CanvasLayer = _game.get_node("DarkModeEffect")
	dark_effect.set_process(false)
	call_deferred("_run")

func _run() -> void:
	_freeze()
	# Geometry first: is the box even on the silhouette?
	await _settle()
	_capture_prop_visibility()
	_capture_ground_tints()
	_report_geometry()
	# The per-segment ground tint is re-rolled from an UNSEEDED
	# RandomNumberGenerator, so print what it actually rolled -- the
	# question "does this vary run to run, and by how much" is answered by
	# the spread of these, not by reading the constant.
	for node in _ground_rolled_color:
		print("ground tint rolled  : %s  -> %s" % [(node as Node).get_parent().name, _ground_rolled_color[node]])

	# One contributor removed at a time, then all of them, so each one's
	# share is attributable rather than inferred from the total.
	for vi in [-1, 0, 2]:
		var label := "LIGHT" if vi < 0 else "DARK/%d" % vi
		print("")
		print("---------- %s ----------" % label)
		await _scenario(vi, true, true, true, true, true)     # as shipped
		await _scenario(vi, false, true, true, true, true)    # no hills
		await _scenario(vi, true, false, true, true, true)    # no props
		await _scenario(vi, true, true, false, true, true)    # ground tint at base
		await _scenario(vi, true, true, true, false, true)    # no fog
		await _scenario(vi, true, true, true, true, false)    # no Keepy
		await _scenario(vi, false, false, false, false, false) # none of the five
	get_tree().quit(0)

func _freeze() -> void:
	GameState.state = GameState.State.PLAYING
	GameState.stage_index = GameState.STAGE_SPEEDS.size() - 1
	GameState.current_speed = 0.0
	GameState.pursuer_enabled = false
	GameState.pursuer_lead_s = TEST_LEAD_S
	GameState.pursuer_visible = true
	_pursuer.set_process(false)
	_pursuer.visible = true
	var t: float = clampf(1.0 - TEST_LEAD_S / GameState.PURSUER_VISIBLE_LEAD_S, 0.0, 1.0)
	_pursuer.position = Vector3(0.0, 0.0, lerpf(Pursuer.FAR_Z, Pursuer.CAUGHT_Z, t))
	var sc: float = lerpf(Pursuer.FAR_SCALE, Pursuer.NEAR_SCALE, t)
	_pursuer.scale = Vector3(sc, sc, sc)

## Same rect PursuerContrastAudit uses, copied verbatim.
func _silhouette_rect() -> Rect2i:
	var cam := get_viewport().get_camera_3d()
	var vp := get_viewport().get_visible_rect().size
	if cam == null:
		return Rect2i(0, 0, 0, 0)
	var centre := _pursuer.global_position + Vector3(0.0, 1.7, 0.0)
	var p := cam.unproject_position(centre)
	var half := 90
	var x := clampi(int(p.x) - half, 0, int(vp.x) - 1)
	var y := clampi(int(p.y) - half, 0, int(vp.y) - 1)
	var w := clampi(half * 2, 1, int(vp.x) - x)
	var h := clampi(half * 2, 1, int(vp.y) - y)
	return Rect2i(x, y, w, h)

## Where the pursuer's real geometry projects, versus where the probe
## looks. If these disagree the box is not measuring what it names.
func _report_geometry() -> void:
	var cam := get_viewport().get_camera_3d()
	var vp := get_viewport().get_visible_rect().size
	var rect := _silhouette_rect()
	print("viewport            : %dx%d" % [int(vp.x), int(vp.y)])
	print("pursuer world pos   : %s   scale %.3f" % [_pursuer.global_position, _pursuer.scale.x])
	print("probe box           : %s" % rect)
	var sil := _pursuer.get_node_or_null("Silhouette") as MeshInstance3D
	if sil == null:
		print("silhouette node     : MISSING")
		return
	# visual_aabb(), NOT get_aabb(): Silhouette is a ModelSlot, and a slot
	# with a model installed CLEARS its own `mesh` (see ModelSlot.gd), so
	# get_aabb() is an empty box at the origin and would report the real
	# geometry as a 0x0 point. PursuerFramingAudit uses the same accessor.
	var aabb: AABB = sil.visual_aabb() if sil.has_method("visual_aabb") else sil.get_aabb()
	var xf := sil.global_transform
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in 8:
		var corner := xf * (aabb.position + Vector3(
			aabb.size.x * float(i & 1),
			aabb.size.y * float((i >> 1) & 1),
			aabb.size.z * float((i >> 2) & 1)))
		var sp := cam.unproject_position(corner)
		mn.x = minf(mn.x, sp.x); mn.y = minf(mn.y, sp.y)
		mx.x = maxf(mx.x, sp.x); mx.y = maxf(mx.y, sp.y)
	print("silhouette on screen: x %d..%d  y %d..%d  (%dx%d px)" % [
		int(mn.x), int(mx.x), int(mn.y), int(mx.y), int(mx.x - mn.x), int(mx.y - mn.y)])
	var box_area := float(rect.size.x * rect.size.y)
	var ox := maxf(0.0, minf(mx.x, float(rect.position.x + rect.size.x)) - maxf(mn.x, float(rect.position.x)))
	var oy := maxf(0.0, minf(mx.y, float(rect.position.y + rect.size.y)) - maxf(mn.y, float(rect.position.y)))
	print("silhouette bbox covers %.1f%% of the probe box (upper bound -- bbox, not pixels)" % [
		100.0 * (ox * oy) / maxf(box_area, 1.0)])

## One measurement, with named contributors switched on or off.
func _scenario(variant_index: int, decor_on: bool, props_on: bool, tint_on: bool, fog_on: bool, keepy_on: bool) -> void:
	_set_decor(decor_on)
	_set_props(props_on)
	_set_tint(tint_on)
	if _env:
		_env.fog_enabled = fog_on
	if _keepy:
		_keepy.visible = keepy_on

	var material: ShaderMaterial = _invert_rect.material
	if variant_index < 0:
		_invert_rect.visible = false
	else:
		_invert_rect.visible = true
		material.set_shader_parameter("intensity", 1.0)
		material.set_shader_parameter("tint_color", GameState.DARK_VARIANTS[variant_index])
		material.set_shader_parameter("tint_amount", GameState.DARK_TINT_AMOUNT)

	await _settle()
	var rect := _silhouette_rect()
	var with_all := _capture()
	_pursuer.visible = false
	await _settle()
	var bg_frame := _capture()
	_pursuer.visible = true
	await _settle()
	if with_all == null or bg_frame == null:
		print("  NO FRAME")
		return

	var bg := _mean(bg_frame, rect)
	var dark := _extreme(with_all, rect, false)
	var bright := _extreme(with_all, rect, true)
	# Where do those extremes come from? Compare against the SAME extremes
	# taken on the pursuer-hidden frame: if the background alone already
	# produces them, the probe is not scoring the pursuer at all.
	var bg_dark := _extreme(bg_frame, rect, false)
	var bg_bright := _extreme(bg_frame, rect, true)
	var eff: float = maxf(_contrast(dark, bg), _contrast(bright, bg))

	var name := "hills=%s props=%s tint=%s fog=%s keepy=%s" % [
		("on" if decor_on else "OFF"), ("on" if props_on else "OFF"),
		("roll" if tint_on else "BASE"), ("on" if fog_on else "OFF"),
		("on" if keepy_on else "OFF")]
	print("  %-34s eff %5.2f:1  bg %s" % [name, eff, _cs(bg)])
	print("      darkest %s (bg-only %s)%s   brightest %s (bg-only %s)%s" % [
		_cs(dark), _cs(bg_dark), ("  <-- BACKGROUND" if _same(dark, bg_dark) else ""),
		_cs(bright), _cs(bg_bright), ("  <-- BACKGROUND" if _same(bright, bg_bright) else "")])

func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.004 and absf(a.g - b.g) < 0.004 and absf(a.b - b.b) < 0.004

func _cs(c: Color) -> String:
	return "(%.3f,%.3f,%.3f L=%.4f)" % [c.r, c.g, c.b, _luma(c)]

func _set_decor(on: bool) -> void:
	if _decor:
		_decor.visible = on

## Trackside props are children of each TrackSegment, built by
## _build_trackside_props(). Found by name rather than by a handle the
## segment does not expose.
##
## RESTORES THE RECORDED VISIBILITY, never sets everything true. Each
## slot owns three meshes (trunk, canopy, rock) of which at most two ever
## draw -- _place_trackside_props leaves the rest hidden. Switching them
## all on would show ~12 props a tile instead of the ~1.8 the game
## actually draws, and every other scenario measured against that would
## be measured against a scene that never ships. (First version of this
## file did exactly that, and attributed 0.11 of the drop to props on the
## strength of it.)
func _set_props(on: bool) -> void:
	for node in _prop_initial_visibility:
		if is_instance_valid(node):
			(node as Node3D).visible = _prop_initial_visibility[node] if on else false

func _capture_prop_visibility() -> void:
	for seg in _all_segments():
		for child in seg.get_children():
			if child is Node3D and String(child.name).begins_with("Prop"):
				_prop_initial_visibility[child] = (child as Node3D).visible

## Forces every segment's ground to its unrolled base albedo, or restores
## the rolled colour recorded at startup.
##
## RESTORES, rather than treating `on` as a no-op: writing the base colour
## is destructive (the roll is not recoverable from the material once
## overwritten), so a no-op `on` branch leaves every LATER scenario in the
## run silently pinned at base tint. The first version of this file did
## that, which put the fog and Keepy rows on a different tint state from
## the rows above them.
func _set_tint(on: bool) -> void:
	for node in _ground_rolled_color:
		if not is_instance_valid(node):
			continue
		var m := (node as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
		if m:
			m.albedo_color = _ground_rolled_color[node] if on else _GROUND_BASE

func _capture_ground_tints() -> void:
	for seg in _all_segments():
		var ground := seg.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if ground == null:
			continue
		var m := ground.get_surface_override_material(0) as StandardMaterial3D
		if m:
			_ground_rolled_color[ground] = m.albedo_color

func _all_segments() -> Array:
	var out: Array = []
	var track := _game.get_node_or_null("World/TrackManager")
	if track == null:
		return out
	for c in track.get_children():
		if c is Node3D:
			out.append(c)
	return out

func _settle() -> void:
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw

func _capture() -> Image:
	var tex := get_viewport().get_texture()
	if tex == null:
		return null
	return tex.get_image()

func _mean(image: Image, rect: Rect2i) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var n := 0
	for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, image.get_height())):
		for x in range(maxi(rect.position.x, 0), mini(rect.position.x + rect.size.x, image.get_width())):
			var c := image.get_pixel(x, y)
			r += c.r
			g += c.g
			b += c.b
			n += 1
	if n == 0:
		return Color.BLACK
	return Color(r / n, g / n, b / n)

func _extreme(image: Image, rect: Rect2i, want_bright: bool) -> Color:
	var best := Color.BLACK if want_bright else Color.WHITE
	var best_luma := -1.0 if want_bright else 2.0
	for y in range(maxi(rect.position.y, 0), mini(rect.position.y + rect.size.y, image.get_height())):
		for x in range(maxi(rect.position.x, 0), mini(rect.position.x + rect.size.x, image.get_width())):
			var c := image.get_pixel(x, y)
			var l := _luma(c)
			if want_bright and l > best_luma:
				best_luma = l
				best = c
			elif not want_bright and l < best_luma:
				best_luma = l
				best = c
	return best

func _luma(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)

func _lin(v: float) -> float:
	if v <= 0.03928:
		return v / 12.92
	return pow((v + 0.055) / 1.055, 2.4)

func _contrast(a: Color, b: Color) -> float:
	var la := _luma(a)
	var lb := _luma(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
