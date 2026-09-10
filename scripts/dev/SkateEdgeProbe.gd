extends Node
## CH67 -- THE NAVIGABLE EDGE, AND WHETHER A RIDER CAN SEE IT.
##
## Mathieu, on the board: "il faut etendre la zone [...] je suis bloque
## parce que la zone s'arrete". Two halves, and this probe gates both.
##
## THE REACH is arithmetic: how much room the park actually has, measured
## by bisection on `HubRegion.contains()` rather than read off a radius,
## because the region is a UNION and the disc is not the only term near
## the park.
##
## THE LEGIBILITY is not arithmetic and cannot be argued from a colour.
## CLAUDE.md is explicit twice over: a visual object gates on PIXELS
## (CH39: seven green phases on an invisible hillside), and a presence
## measured by a DIFFERENCE needs the noise floor of its own bench (CH40).
## So the kerb is measured the only way that means anything -- the SAME
## frame rendered with the band on and with it off, and the pixels that
## CHANGE are its ink. That makes the blind check and the measurement the
## same reading: a kerb that painted nothing would read zero, and a bench
## that could not see would read zero for the real one too, which is why
## the noise floor is published beside it.
##
## xvfb + opengl3: it reads pixels. --headless would hand back a blank
## surface and every ratio would come out 1.00 (CLAUDE.md).

const VP_SIZE: Vector2i = Vector2i(1080, 1920)
const BUDGET_S: float = 1200.0
const SETTLE: int = 4
## Enough of the frame that a band cannot be called visible on noise.
## Measured on this bench: the floor (two untouched reads) is 0 pixels,
## and the kerb inks thousands.
const MIN_INK: int = 400

var _fails: int = 0
var _hub: Node = null
var _world: Node3D = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _sub: SubViewport = null
var _park: HubSkatepark = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE EDGE PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_world = _hub.get_node("WorldViewport/SubViewport/World") as Node3D
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as Node3D
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport
	_park = _hub.get_node("WorldViewport/SubViewport/World/Skatepark") as HubSkatepark

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	# stretch FIRST: a stretching container ignores an explicit size and
	# only warns (CLAUDE.md).
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	_sub.size = VP_SIZE
	_run()

func _run() -> void:
	print("=== SKATE EDGE PROBE -- CH67 ===")
	await _phase_instrument()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every number below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_reach()
	await _phase_kerb()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

func _phase_instrument() -> void:
	print("-- PHASE I: the instrument --")
	await _station(Vector2(0.0, 60.0))
	var img := await _image()
	_check(img != null and img.get_width() == VP_SIZE.x and img.get_height() == VP_SIZE.y,
		"I1 the viewport really is %dx%d (got %dx%d)"
			% [VP_SIZE.x, VP_SIZE.y, img.get_width() if img else -1, img.get_height() if img else -1])
	var tones := {}
	for y in range(0, img.get_height(), 41):
		for x in range(0, img.get_width(), 41):
			tones[img.get_pixel(x, y).to_rgba32()] = true
	_check(tones.size() > 8,
		"I2 the frame is RASTERISED -- %d distinct sampled colours (the dummy driver gives 1)" % tones.size())

# =====================================================================
# PHASE E -- the reach.

func _phase_reach() -> void:
	print("-- PHASE E: how much room the park has, by bisection on contains() --")
	var centre: Vector3 = HubRegion.skate_lobe_centre()
	print("     lobe centre %s   radius %.1f   reach on the axis z %.1f"
		% [str(centre), HubRegion.SKATE_LOBE_RADIUS, centre.z + HubRegion.SKATE_LOBE_RADIUS])
	var slab_x: float = HubSkatepark.SLAB_WIDTH * 0.5
	var park_z: float = HubSkatepark.PARK_CENTRE.y
	var worst: float = 1e9
	for x in [-slab_x, -4.2, 0.0, 5.0, slab_x]:
		var run: float = _run_north(x, park_z)
		worst = minf(worst, run)
		print("     x %6.2f : %6.2f u of free run north of the park's centre (to z %.2f)"
			% [x, run, park_z + run])
	# ⚠️ THE NUMBER IS THE BOARD'S, NOT A ROUND ONE. HubTransport parks the
	# board at SKATE_PARK; at r = 28 that point sat 2.84 u from the rim, so
	# a rider who mounted and held his thumb north was fenced before the
	# run-up (SKATE_ACCEL_U) was over. The gate is that the parking place
	# has at least a full run-up of room in the direction it faces.
	var park: Vector3 = HubTransport.SKATE_PARK
	var from_park: float = _run_north(park.x, park.z)
	print("     the board's own parking place %s has %.2f u of room to the north (run-up is %.2f u)"
		% [str(Vector2(park.x, park.z)), from_park, HubTransport.SKATE_ACCEL_U])
	_check(from_park > HubTransport.SKATE_ACCEL_U,
		"E1 the board can complete a run-up from where it is parked (%.2f u > %.2f)"
			% [from_park, HubTransport.SKATE_ACCEL_U])
	_check(worst >= 15.0,
		"E2 every lane of the slab keeps at least 15 u of run north (worst %.2f)" % worst)
	# And the widening did not quietly open ground the wall does not close.
	_check(CozyScatter.WALL_NEAR_Z >= HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS,
		"E3 the tree wall still stands PAST the region's north edge (%.1f >= %.1f)"
			% [CozyScatter.WALL_NEAR_Z, HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS])
	_check(CozyScatter.COVER_MAX.y >= HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS,
		"E4 and the carpet is sown all the way to it (%.1f >= %.1f)"
			% [CozyScatter.COVER_MAX.y, HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS])
	# The ground under the new half-crescent is FLAT and real: no domain
	# reaches it, so HubSurface answers 0 and the board rolls on a plane.
	var high: float = 0.0
	for i in 41:
		var a: float = float(i) / 40.0 * PI - PI * 0.5
		var p: Vector3 = HubRegion.skate_lobe_centre() \
			+ Vector3(sin(a), 0.0, cos(a)) * (HubRegion.SKATE_LOBE_RADIUS - 0.5)
		high = maxf(high, absf(HubSurface.height_at(p)))
	_check(high < 0.001,
		"E5 the new ground is FLAT to %.4f u all along the rim -- nothing to fall off" % high)

func _run_north(x: float, from_z: float) -> float:
	var lo: float = 0.0
	var hi: float = 60.0
	for _i in 40:
		var mid: float = (lo + hi) * 0.5
		if HubRegion.contains(Vector3(x, 0.0, from_z + mid)):
			lo = mid
		else:
			hi = mid
	return lo

# =====================================================================
# PHASE K -- the kerb, in PIXELS.

func _phase_kerb() -> void:
	print("-- PHASE K: the painted kerb, measured as the pixels it CHANGES --")
	var mat: ShaderMaterial = CozyPalette.ground_material()
	var radius: float = float(mat.get_shader_parameter("kerb_radius"))
	var centre: Vector2 = mat.get_shader_parameter("kerb_centre")
	_check(absf(radius - (HubRegion.SKATE_LOBE_RADIUS - HubRegion.KERB_INSET)) < 0.001
			and centre.is_equal_approx(Vector2(HubRegion.skate_lobe_centre().x, HubRegion.skate_lobe_centre().z)),
		"K1 the painted circle IS the region's own: centre %s radius %.3f" % [str(centre), radius])
	# A station on the rim, looking down the lobe -- where a rider meets it.
	var station := Vector2(0.0, HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS - 6.0)
	var rim: Dictionary = await _ink_at(station, mat, radius)
	var off: Image = rim["off"]
	var on: Image = rim["on"]
	var ink: int = int(rim["ink"])
	var floor_px: int = int(rim["floor"])
	print("     the kerb inks %d sampled pixels (%.3f %% of the sampled frame), floor %d"
		% [ink, 100.0 * float(ink) / float(int(rim["sampled"])), floor_px])
	_check(ink > MIN_INK and ink > floor_px * 8,
		"K2 the kerb DRAWS: %d sampled pixels change when it is switched off, against a floor of %d" % [ink, floor_px])
	# ⚠️ AND IT DRAWS WHERE THE BOUNDARY IS. Ink alone would pass for a
	# band painted anywhere; every changed pixel is unprojected back onto
	# the ground plane and has to land in the band's own annulus.
	var stray: int = 0
	var counted: int = 0
	for y in range(0, VP_SIZE.y, 3):
		for x in range(0, VP_SIZE.x, 3):
			if off.get_pixel(x, y).is_equal_approx(on.get_pixel(x, y)):
				continue
			counted += 1
			var hit: Vector3 = _ground_under(Vector2(float(x), float(y)))
			if hit.y > 1e5:
				stray += 1
				continue
			var dr: float = absf(Vector2(hit.x, hit.z).distance_to(centre) - radius)
			if dr > HubRegion.KERB_WIDTH:
				stray += 1
	print("     of %d sampled changed pixels, %d land outside the band's own annulus" % [counted, stray])
	_check(counted > 0 and float(stray) / float(maxi(counted, 1)) < 0.05,
		"K3 the ink is ON the boundary: %d of %d sampled pixels stray (< 5 %%)" % [stray, counted])
	# The far side of the same circle is NOT painted: the arc is only the
	# region's edge where z >= the centre's, and south of that the square
	# takes over.
	var south: Dictionary = await _ink_at(Vector2(0.0, 10.0), mat, radius)
	print("     from the plateau (0, 10): band ink %d sampled pixels, floor at the SAME station %d"
		% [int(south["ink"]), int(south["floor"])])
	# ⚠️ AGAINST ITS OWN STATION'S FLOOR, and the first version of this
	# line was not. It compared an ON frame to an OFF frame taken eight
	# frames later and read 21044 -- on a station where the band is
	# BEHIND the camera and cannot paint a pixel. `paused` does not stop
	# a shader's TIME (CLAUDE.md, CH48/CH62), so the clouds, the water and
	# the rain move between two reads and that motion IS the number. Every
	# station now publishes its own floor, taken with the same spacing,
	# and the verdict is the ratio.
	_check(int(south["ink"]) < maxi(int(south["floor"]) * 2, MIN_INK),
		"K4 and it is NOT painted across the open plateau: %d sampled pixels against that station's own floor of %d"
			% [int(south["ink"]), int(south["floor"])])

## One station's reading: the bench's own noise floor (two OFF frames the
## same number of frames apart as the measurement) and then the band's
## ink (OFF against ON). Both are needed and neither means anything
## alone -- CLAUDE.md, CH40.
func _ink_at(station: Vector2, mat: ShaderMaterial, radius: float) -> Dictionary:
	await _station(station)
	mat.set_shader_parameter("kerb_radius", 0.0)
	for _i in SETTLE:
		await get_tree().process_frame
	var off_a := await _image()
	for _i in SETTLE:
		await get_tree().process_frame
	var off_b := await _image()
	var floor_px: int = _differing(off_a, off_b)
	mat.set_shader_parameter("kerb_radius", radius)
	for _i in SETTLE:
		await get_tree().process_frame
	var on := await _image()
	var sampled: int = int(ceil(float(VP_SIZE.x) / 3.0)) * int(ceil(float(VP_SIZE.y) / 3.0))
	return {"off": off_b, "on": on, "ink": _differing(off_b, on),
		"floor": floor_px, "sampled": sampled}

## Where the ray through a screen point meets y = 0, or a huge y if it
## never does.
func _ground_under(screen: Vector2) -> Vector3:
	var from: Vector3 = _camera.project_ray_origin(screen)
	var dir: Vector3 = _camera.project_ray_normal(screen)
	if absf(dir.y) < 1e-6 or (from.y > 0.0 and dir.y > -1e-6):
		return Vector3(0.0, 1e6, 0.0)
	var t: float = -from.y / dir.y
	if t < 0.0:
		return Vector3(0.0, 1e6, 0.0)
	return from + dir * t

func _differing(a: Image, b: Image) -> int:
	var n: int = 0
	for y in range(0, VP_SIZE.y, 3):
		for x in range(0, VP_SIZE.x, 3):
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				n += 1
	return n

func _station(flat: Vector2) -> void:
	get_tree().paused = false
	_keepy.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.y))
	if _camera.has_method("snap_to_target"):
		_camera.call("snap_to_target")
	for _i in SETTLE:
		await get_tree().process_frame
	get_tree().paused = true
	for _i in SETTLE:
		await get_tree().process_frame

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return _sub.get_texture().get_image()
