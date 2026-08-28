extends Node

## Renders the impact sheet: the two ORIENTATIONS a surface ring can take
## and the two COLOURS it can take, at four azimuths, plus a strip of the
## shipped choice across its own life.
##
## The grid tiles are drawn at a FROZEN mid-life pose -- scale and alpha
## set by hand rather than tweened -- because the grid's question is
## orientation and colour, and animating it would add a variable it is not
## asking about. The time strip below it uses the real tween, so the thing
## Mathieu judges for motion is the shipped path and not a reconstruction.
##
## ⚠️ NOTHING ON THIS SHEET IS VALIDATED. It is llvmpipe under xvfb through
## the desktop opengl3 backend; the game is WebGL2 under Safari. It exists
## so a device call can be made against pictures instead of adjectives --
## the same standing as the deck-height and climb-cadence sheets, both of
## which were settled on a phone and not here.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")
const OUT: String = "res://docs/color-sheets"

const WHITE: Color = Color(0.918, 1.0, 0.988, 0.85)
const TURQUOISE: Color = Color(0.251, 0.878, 0.816, 0.85)
const AZIMUTHS: Array[float] = [0.0, 90.0, 180.0, 270.0]

var _hub: Node = null
var _world: Node3D = null
var _cam: Camera3D = null
var _centre: Vector3 = Vector3.ZERO

func _ready() -> void:
	ProbeWatchdog.arm(self, "SplashSheetProbe")
	_hub = HUB_SCENE.instantiate()
	add_child(_hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_world = _hub.get_node("WorldViewport/SubViewport/World")
	_cam = _world.get_node("Camera3D")
	# ⚠️ THE CAMERA MUST BE STOPPED FIRST. HubCamera lerps itself back onto
	# Keepy every frame, so a probe that only writes global_position gets
	# one aimed tile and three of it drifting home -- which is exactly what
	# the first render of this sheet produced. Documented for the hub
	# already; walked into anyway, so it is nailed down here.
	_cam.set_process(false)
	var builder = _hub.get("_builder")
	_centre = builder.pond_centre()

	# Keepy stood in the water he just dived into, so the ring is judged
	# against the body it belongs to and not against empty turquoise.
	var keepy: Node3D = _world.get_node("Keepy")
	keepy.global_position = Vector3(_centre.x, 0.0, _centre.z)
	_hub.call("_ensure_keepy_material")
	_hub.call("_set_keepy_wet", true)
	await get_tree().process_frame

	var grid: Array[Image] = []
	for flat in [true, false]:
		for colour in [WHITE, TURQUOISE]:
			for az in AZIMUTHS:
				grid.append(await _shot_frozen(flat, colour, az))

	var strip: Array[Image] = []
	for frac in [0.18, 0.42, 0.68, 0.92]:
		strip.append(await _shot_live(frac))

	_compose(grid, strip)
	get_tree().quit(0)

func _aim(az: float) -> void:
	var a := deg_to_rad(az)
	# Closer than the game's own 8.9/7.6 so the ring is big enough in a
	# 300px tile to be judged at all. The PITCH is the shipped -34, which
	# is what decides how foreshortened a flat ring looks -- that part is
	# not allowed to move, because it is the whole question.
	_cam.global_position = _centre + Vector3(sin(a) * 4.6, 3.6, cos(a) * 4.6)
	_cam.rotation_degrees = Vector3(-34.0, az, 0.0)

## One tile with the ring held still at mid-life.
func _shot_frozen(flat: bool, colour: Color, az: float) -> Image:
	var ring := _build_ring(colour, flat)
	# Mid-life: a bit over half open, half faded.
	ring.scale = Vector3.ONE * (_c("SPLASH_RING_RADIUS") * 0.62)
	var m := ring.get_surface_override_material(0) as StandardMaterial3D
	m.albedo_color = Color(colour.r, colour.g, colour.b, colour.a * 0.62)
	_world.add_child(ring)
	_aim(az)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _hub.get_node("WorldViewport/SubViewport").get_texture().get_image()
	ring.queue_free()
	await get_tree().process_frame
	return img

## One tile driven by the SHIPPED spawn, sampled a given way through its
## life -- so the strip shows what actually ships, tween and all.
func _shot_live(frac: float) -> Image:
	_hub.call("_on_board_dived")
	_hub.call("_on_hop_landed", Vector3(_centre.x, 0.0, _centre.z))
	_aim(30.0)
	var target: float = _c("SPLASH_LIFE_S") * frac
	var e: float = 0.0
	while e < target:
		e += get_process_delta_time()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = _hub.get_node("WorldViewport/SubViewport").get_texture().get_image()
	var wait: float = 0.0
	while wait < _c("SPLASH_LIFE_S") + 0.3:
		wait += get_process_delta_time()
		await get_tree().process_frame
	return img

func _c(name: String) -> float:
	return _hub.get_script().get_script_constant_map().get(name, 0.0)

func _build_ring(colour: Color, flat: bool) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.78
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_BACK
	var n := MeshInstance3D.new()
	n.mesh = torus
	n.set_surface_override_material(0, m)
	# FLAT lies in the water's plane; UPRIGHT stands in it facing the
	# camera, which is the candidate that intersects the water plane and is
	# therefore the one transparent sorting has no correct answer for.
	n.rotation_degrees = Vector3(90.0, 0.0, 0.0) if flat else Vector3.ZERO
	n.position = Vector3(_centre.x, _c("SPLASH_RING_Y") + (0.0 if flat else 0.30), _centre.z)
	return n

## Cuts the middle out of the frame rather than squashing the whole 9:16
## down: the ring sits where Keepy is, and scaling a portrait frame into a
## square tile would shrink the one thing the sheet is about.
func _crop(img: Image, tw: int, th: int) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var side: int = mini(w, h)
	var out := Image.create(side, side, false, img.get_format())
	out.blit_rect(img, Rect2i((w - side) / 2, (h - side) / 2 + int(side * 0.10), side, side), Vector2i.ZERO)
	out.resize(tw, th, Image.INTERPOLATE_LANCZOS)
	return out

func _compose(grid: Array[Image], strip: Array[Image]) -> void:
	var tw := 380
	var th := 380
	var cols := 4
	var sheet := Image.create(tw * cols, th * 5 + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.05, 0.07, 0.05))
	for i in grid.size():
		var img: Image = _crop(grid[i], tw, th)
		sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i((i % 4) * tw, (i / 4) * th))
	for i in strip.size():
		var img: Image = _crop(strip[i], tw, th)
		sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i(i * tw, 4 * th + 8))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path := OUT + "/water_impact_sheet.png"
	sheet.save_png(path)
	print("=== WATER IMPACT SHEET ===")
	print("  rows 1-4 = frozen mid-life, columns = azimuth 0 / 90 / 180 / 270")
	print("    row 1  FLAT ring, near-white")
	print("    row 2  FLAT ring, water turquoise")
	print("    row 3  UPRIGHT ring, near-white")
	print("    row 4  UPRIGHT ring, water turquoise")
	print("  row 5  = the SHIPPED effect live, at 18 / 42 / 68 / 92 %% of its life")
	print("  -> %s" % ProjectSettings.globalize_path(path))
