extends Node
## CH75 -- THE COMET'S GATES: the third ride of the fair, ridden through
## the player's own channel under the CHASE camera, plus what it stands
## on, what it clears, and what it costs.
##
## =====================================================================
## ⚠️ THIS PROBE RUNS UNDER xvfb + opengl3, NEVER --headless
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
##     --path . res://scripts/dev/CometProbe.tscn
##
## PHASE I reads MultiMesh transforms (identity under the dummy driver,
## CLAUDE.md CH50), PHASE C and PHASE H read PIXELS, PHASE G reads the
## primitive counter, and every ride is started from a SCREEN POINT
## through HubTapInput._handle_point, which returns before projecting
## anything when the container rect is 0x0. PHASE I asserts the rect.
##
## =====================================================================
## WHAT THIS PROBE CANNOT SIGN
##
## Whether the drop is frightening, whether 16 u/s feels fast, whether a
## 45 deg chain lift is dread or tedium, whether the chase camera's fov
## (64) and its 150 deg/s cap sit right on a phone, whether the trim
## brake on the camelback reads as a brake or as a stall, whether the
## Comet's purple reads against the haze. Every one of those is Mathieu's
## device call (CLAUDE.md CH62: a bench does not judge a game feel).
##
## What it signs: that the numbers the brief asked for are MEASURED on
## the built curve and on the ridden cart and are what the design says
## (x1.5+ the CH71 coaster's top speed, ridden on the same bench in the
## same run; above the tower's fall; a drop over 55 deg); that the
## energy law is WIRED (the valley speed matches the closed form, and the
## ride is a CURVE that moves); that the chase camera is entered through
## boarding and left through the run-out, that it never stands inside a
## solid or a rail, that its yaw never exceeds its cap, and that the
## rider is in its frame every frame; that nothing the Comet builds
## leaves the region or touches the CH71 loop, the tower, the zipline or
## a layout prop; that the carpet is kept off it; that every tap made
## during the ride is dropped and none is swallowed; and what it costs,
## at rest and from the chase.
##
## =====================================================================
## RED BEFORE GREEN (CLAUDE.md): three neutralisations, each with its
## predicted reds, run before this probe was believed on its green:
##   * GRAVITY term removed from _advance_comet (energy never grows)
##       -> E5 (top speed), E6 (valley vs closed form), E7 (x1.5 the
##          CH71 coaster), E13 (trim shed speed)
##   * _sync_comet_camera(true) never asked (no chase)
##       -> E9 (chase entered), E10 (rider in the chase frame -- the
##          fixed pose loses a 14 u rider), E17 (fov)
##   * accepts_tap without the Comet's phase condition
##       -> E12 (the station withdraws)
##
## =====================================================================
## PHASES
##
##   I  instrument: rasterised frame, MultiMesh transforms, container rect
##   A  the Comet as built vs what it publishes: the two curve spellings,
##      the crest, the slope, the numbers against the other two rides,
##      the drop's yaw, the frames, the run-out's fit
##   B  clearances: region (outer rails included), layout footprints, the
##      CH71 loop, the zipline, self-clearance, the carpet (blind)
##   C  winding judge (CH39): cull_back vs cull_disabled, same pixels
##   D  D5: the Comet's posts are live on the fair's body; blind on the deck
##   E  the CH71 coaster then the Comet, both through the tap channel:
##      the profile, the camera, the doors, the taps, the facing
##   P  CH76: the POV on the Comet, a second ride in the same run, held
##      from the station to the run-out -- the pose, the two doors, what
##      the eye passes through and what it costs against the chase
##   G  budget: shown vs hidden at the Comet's stations; the chase's cost
##   H  pixels: the Comet is SEEN from its stations

const VP_SIZE: Vector2i = Vector2i(540, 960)
const SETTLE: int = 3
const BUDGET_S: float = 900.0
const SPAWN := Vector3(0.0, 0.0, 0.0)
## Where the CH71 coaster is tapped from (FunfairProbe's own station).
const COASTER_TAP_FROM := Vector3(27.0, 0.0, 26.0)
## Where the Comet is tapped from: west of the station, the rest point
## 3.5 u east and 1 u ahead (in frame: the half-width at 1 u ahead is
## 0.414 x 9.9 = 4.1 u), the walk to the stand clear of both deck posts
## by more than a unit, and 2.1 u from the seesaw's (18, 44) r 1.8 disc.
const COMET_TAP_FROM := Vector3(19.5, 0.0, 42.5)
## Fixed-camera stations that see the Comet (the camera shows lower z).
const COMET_NORTH_VIEW := Vector3(25.0, 0.0, 60.0)
const COMET_SOUTH_VIEW := Vector3(26.0, 0.0, 50.0)
const BARE_GROUND := Vector3(24.0, 0.0, 30.0)
const CROWN: float = 1.7
const FRAME_MARGIN_PX: float = 24.0
const CABLE_CLEARANCE: float = 1.5
const P1 := Vector3(27.7, 0.0, 9.2)
const P2 := Vector3(25.2, 0.0, 35.0)
const CABLE_HEIGHT: float = 2.0
## A rider's crown over a rail top (seat 0.34 + crown 1.7) plus a hand:
## the least any other rail may come to this one.
const RIDER_HEADROOM: float = 2.6
## The camera counts as INSIDE a rail when nearer than this to its
## centre line (radius 0.06 plus the near plane's worth of margin).
const CAMERA_RAIL_CLEAR: float = 0.5
const CAMERA_SOLID_MARGIN: float = 0.3
## The most the CART's own heading may turn per second, anywhere on the
## loop: between the trimmed turn (~150) and an untrimmed one (~400),
## and between a turn ended on the flat (~145) and one ended on the
## crest (502, measured). The CAMERA is gated on its own cap, E23.
const CART_YAW_LIMIT_DEG: float = 200.0
## CH76 -- the POV's own clearances, and they are NOT the chase's.
##
## The eye rides 1.89 u over the rail top (CART_SEAT 0.34 + the head
## anchor's 1.55), so the cart's own rail is a permanent floor under
## every reading: a rail nearer than this means ANOTHER part of the loop
## came through the rider's face, which is the one thing a POV can do
## that a chase 6.2 u overhead cannot. The number is the near plane plus
## a rail radius plus a hand -- PHASE P prints the worst it measured
## next to it, so the margin is read rather than trusted.
const EYE_RAIL_CLEAR: float = 0.60
const EYE_SOLID_MARGIN: float = 0.10
## How near a rail has to come to be worth calling "structure in the
## picture": inside this, in frame, and in front of the eye.
const EYE_NEAR_FIELD: float = 8.0

var _fails: int = 0
var _hub: Node = null
var _world: Node3D = null
var _keepy: KeepyHopper = null
var _camera: Camera3D = null
var _sub: SubViewport = null
var _scatter: Node = null
var _props: HubBuilder = null
var _overlay: Node = null
var _tap: HubTapInput = null
var _fair: HubFunfair = null
var _clearance: float = 0.0
var _finished_rides: Array = []
var _comet_samples: PackedVector3Array = PackedVector3Array()
var _ch71_samples: PackedVector3Array = PackedVector3Array()

func _ready() -> void:
	ProbeWatchdog.arm(self, "COMET PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_world = _hub.get_node("WorldViewport/SubViewport/World") as Node3D
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as KeepyHopper
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport
	_scatter = _hub.get_node("WorldViewport/SubViewport/World/CozyScatter")
	_props = _world.get_node("Props") as HubBuilder
	_overlay = _hub.get_node_or_null("PerfOverlay")
	_tap = _hub.get_node("TapInput") as HubTapInput
	_fair = _world.get_node("Funfair") as HubFunfair
	if _overlay != null:
		_overlay.set_process(false)
	var consts: Dictionary = (_hub.get_script() as Script).get_script_constant_map()
	_clearance = float(consts.get("KEEPY_CLEARANCE", 0.0))
	_fair.ride_finished.connect(func(ride: int, _landing: Vector3): _finished_rides.append(ride))

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	_sub.size = VP_SIZE
	box.size = Vector2(VP_SIZE)
	_run()

func _run() -> void:
	print("=== COMET PROBE -- CH75 ===")
	# The weather is pinned to sun for the whole run: PHASE C, G and H
	# take pixel / primitive floors on a paused frame and `paused` does
	# not stop a shader's TIME (CLAUDE.md CH48, measured by CH72 at a
	# factor of seventy on this fair's own floor).
	var weather := _world.get_node_or_null("CozyWeather") as CozyWeather
	if weather != null:
		weather.force(CozyWeather.Kind.SUN)
		for _i in int(CozyWeather.TRANSITION_S * 60.0) + 30:
			await get_tree().process_frame
		print("  weather pinned: %s (forced %s)" % [weather.kind_name(), str(weather.is_forced())])
	var s: float = 0.0
	while s < _fair.comet_length():
		_comet_samples.append(_fair.comet_point(s))
		s += 0.25
	s = 0.0
	while s < _fair.track_length():
		_ch71_samples.append(_fair.track_point(s))
		s += 0.25
	print("  comet length %.3f u   crest s %.3f   lift foot s %.3f   peak rail y %.3f   posts %d   triangles %d (fair %d)" % [
		_fair.comet_length(), _fair.comet_crest_s(), _fair.comet_lift_foot_s(), _fair.comet_peak_rail_y(),
		_fair.comet_post_count(), _fair.comet_triangle_total(), _fair.triangle_total()])
	print("")
	await _phase_i()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- nothing below would be worth reading. Stopping. ===")
		get_tree().quit(1)
		return
	_phase_a()
	_phase_b()
	await _phase_c()
	await _phase_d()
	await _phase_e()
	await _phase_p()
	await _phase_g()
	await _phase_h()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# HELPERS

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)

func _station(flat: Vector3) -> void:
	_keepy.global_position = HubSurface.ground(_flat(flat))
	_camera.call("snap_to_target")
	for _i in SETTLE:
		await get_tree().process_frame

func _to_screen(world: Vector3) -> Vector2:
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	var local: Vector2 = _camera.unproject_position(world)
	local.x *= rect.size.x / float(_sub.size.x)
	local.y *= rect.size.y / float(_sub.size.y)
	return local + rect.position

func _tap_world(world: Vector3) -> void:
	_tap._handle_point(_to_screen(world))

func _settle_walk(cap: int = 1200) -> int:
	var frames: int = 0
	await get_tree().process_frame
	frames += 1
	while _keepy.is_hopping() and frames < cap:
		await get_tree().process_frame
		frames += 1
	return frames

func _in_frame(world: Vector3, margin: float) -> bool:
	if _camera.is_position_behind(world):
		return false
	var p: Vector2 = _camera.unproject_position(world)
	return p.x >= margin and p.y >= margin and p.x <= float(_sub.size.x) - margin and p.y <= float(_sub.size.y) - margin

func _prims() -> int:
	return RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)

func _calls() -> int:
	return RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)

func _read() -> Dictionary:
	await get_tree().process_frame
	var rep: Dictionary = _overlay.call("snapshot") if _overlay != null else {}
	return {"gpu": _prims(), "calls": _calls(), "scene": int(rep.get("tris_scene", -1))}

func _frame() -> Image:
	await get_tree().process_frame
	await get_tree().process_frame
	return _sub.get_texture().get_image()

func _count_magenta(img: Image) -> int:
	var n: int = 0
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.85 and c.g < 0.15 and c.b > 0.85:
				n += 1
	return n

func _diff_pixels(a: Image, b: Image) -> int:
	var n: int = 0
	for y in a.get_height():
		for x in a.get_width():
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.06:
				n += 1
	return n

## Keepy's drawn facing, flat (the +Z column of his Yaw node).
func _facing() -> Vector3:
	var f: Vector3 = (_keepy.get_node("Yaw") as Node3D).global_transform.basis.z
	return Vector3(f.x, 0.0, f.z).normalized()

func _camera_yaw() -> float:
	var b: Basis = _camera.global_transform.basis
	return atan2(-b.z.x, -b.z.z)

## Which sample is the nearest, for a reading that has to NAME what came
## close rather than only how close it came.
func _nearest_sample(samples: PackedVector3Array, p: Vector3) -> Vector3:
	var best: float = INF
	var out: Vector3 = Vector3.ZERO
	for q in samples:
		var d: float = q.distance_to(p)
		if d < best:
			best = d
			out = q
	return out

func _nearest(samples: PackedVector3Array, p: Vector3) -> float:
	var best: float = INF
	for q in samples:
		best = minf(best, q.distance_to(p))
	return best

## Whether `p` lies inside any box of the fair's body, padded by `pad`.
func _inside_solid(p: Vector3, pad: float) -> bool:
	for shape in _fair.collider_body().get_children():
		var cs := shape as CollisionShape3D
		if cs == null:
			continue
		var box := cs.shape as BoxShape3D
		if box == null:
			continue
		var c: Vector3 = cs.global_position
		if absf(p.x - c.x) < box.size.x * 0.5 + pad and absf(p.y - c.y) < box.size.y * 0.5 + pad and absf(p.z - c.z) < box.size.z * 0.5 + pad:
			return true
	return false

## The least distance from the segment a-b to any sample.
func _segment_nearest(samples: PackedVector3Array, a: Vector3, b: Vector3) -> float:
	var best: float = INF
	for q in samples:
		best = minf(best, Geometry3D.get_closest_point_to_segment(q, a, b).distance_to(q))
	return best

## True when the segment camera -> cart passes within a rail's radius
## (plus a hand) of a rail sample that is NOT the cart's own stretch.
func _sightline_crossed(cam: Vector3, cart: Vector3) -> bool:
	for q in _comet_samples:
		if q.distance_to(cart) < 1.5:
			continue
		if Geometry3D.get_closest_point_to_segment(q, cam, cart).distance_to(q) < HubFunfair.RAIL_RADIUS + 0.2:
			return true
	return false

## The closed form CH71 uses for the tower's fall speed at its brake line.
func _tower_fall_speed() -> float:
	return sqrt(2.0 * HubFunfair.GRAVITY * (HubFunfair.GONDOLA_TOP_Y - HubFunfair.gondola_brake_y()))

## The energy law's valley speed for the CH71 loop (crest to its valley,
## point 10), so the two coasters are compared by the SAME arithmetic.
func _ch71_predicted_valley_speed() -> float:
	var valley_s: float = _fair.track_curve().get_closest_offset(HubFunfair.TRACK_POINTS[10])
	var dh: float = _fair.peak_rail_y() - _fair.track_point(valley_s).y
	var v2: float = HubFunfair.LIFT_SPEED * HubFunfair.LIFT_SPEED + 2.0 * HubFunfair.GRAVITY * dh - 2.0 * HubFunfair.ROLL_FRICTION * (valley_s - _fair.crest_s())
	return sqrt(maxf(v2, 0.0))

# =====================================================================
# PHASE I -- THE INSTRUMENT SEES

func _phase_i() -> void:
	print("-- PHASE I: instrument control --")
	await _station(SPAWN)
	var img: Image = await _frame()
	var seen := {}
	for y in range(0, img.get_height(), 37):
		for x in range(0, img.get_width(), 37):
			seen[img.get_pixel(x, y).to_rgba32()] = true
	_check(seen.size() > 1, "I1 the frame carries %d colours on a 37 px lattice (the dummy driver renders 1)" % seen.size())
	var moved: int = 0
	var total: int = 0
	for nm in _scatter.call("batch_nodes"):
		var node := _scatter.get_node_or_null(String(nm)) as MultiMeshInstance3D
		if node == null:
			continue
		for i in node.multimesh.instance_count:
			total += 1
			if node.multimesh.get_instance_transform(i).origin.length() > 0.01:
				moved += 1
	_check(total > 0 and moved == total, "I2 MultiMesh transforms read back non-identity: %d / %d" % [moved, total])
	var rect: Rect2 = _tap.container.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0, "I3 the container has a real rect (%s), so a screen tap projects" % rect)
	_check(_clearance > 0.0, "I4 read HubWorld.KEEPY_CLEARANCE (%.3f)" % _clearance)
	_check(_fair != null and _fair.comet_length() > 0.0 and _fair.comet_node() != null, "I5 the Comet is built and its loop has length")
	print("")

# =====================================================================
# PHASE A -- AS BUILT vs AS PUBLISHED

func _phase_a() -> void:
	print("-- PHASE A: the Comet as built --")
	var static_curve: Curve3D = HubFunfair._static_comet_curve()
	_check(absf(static_curve.get_baked_length() - _fair.comet_length()) < 0.001,
		"A1 the two spellings of the Comet's loop agree (%.3f vs %.3f u)" % [static_curve.get_baked_length(), _fair.comet_length()])
	_check(_fair.comet_crest_s() > _fair.comet_lift_foot_s() + 5.0, "A2 the crest (s %.3f) comes after the lift foot (s %.3f)" % [_fair.comet_crest_s(), _fair.comet_lift_foot_s()])
	var authored_top: float = -INF
	for p in HubFunfair.COMET_POINTS:
		authored_top = maxf(authored_top, p.y)
	_check(absf(_fair.comet_peak_rail_y() - authored_top) < 0.25, "A3 the baked crest (%.3f) is the authored top (%.2f) to a quarter unit" % [_fair.comet_peak_rail_y(), authored_top])
	var steep: float = CoasterRail.steepest_deg(_fair.comet_curve())
	var ch71_steep: float = CoasterRail.steepest_deg(_fair.track_curve())
	print("     steepest: Comet %.1f deg, CH71 coaster %.1f deg" % [steep, ch71_steep])
	_check(steep > 55.0, "A4 the drop is a DROP: steepest %.1f deg (> 55; the CH71 coaster's is %.1f)" % [steep, ch71_steep])
	_check(steep < 85.0, "A4b and never dead vertical (< 85: the ride frame's guard is never the pose)")
	_check(_fair.comet_peak_rail_y() >= 2.0 * _fair.peak_rail_y(), "A5 the crest is at least twice the CH71 coaster's (%.3f vs %.3f)" % [_fair.comet_peak_rail_y(), _fair.peak_rail_y()])
	var v_comet: float = _fair.comet_predicted_valley_speed()
	var v_71: float = _ch71_predicted_valley_speed()
	var v_tower: float = _tower_fall_speed()
	print("     energy law: Comet valley %.2f u/s, CH71 valley %.2f u/s, tower fall %.2f u/s" % [v_comet, v_71, v_tower])
	_check(v_comet >= 1.5 * v_71, "A6 the closed form gives x%.2f the CH71 coaster's valley speed (>= 1.5)" % (v_comet / maxf(v_71, 0.001)))
	_check(v_comet > v_tower, "A7 and more than the tower's fall (%.2f > %.2f)" % [v_comet, v_tower])
	# The frames: right-handed on the drop, and the drop's yaw is exactly
	# south (points 10-14 share x, so the tangent's flat part is not a
	# wobble read off a nearly vertical tangent).
	var det_ok: bool = true
	var yaw_worst: float = 0.0
	for k in range(HubFunfair.COMET_VALLEY_INDEX - 3, HubFunfair.COMET_VALLEY_INDEX):
		var s: float = _fair.comet_curve().get_closest_offset(HubFunfair.COMET_POINTS[k])
		var f: Transform3D = _fair.comet_ride_frame(s)
		if f.basis.determinant() <= 0.0:
			det_ok = false
		var yaw: float = rad_to_deg(atan2(f.basis.z.x, f.basis.z.z))
		yaw_worst = maxf(yaw_worst, absf(absf(yaw) - 180.0))
	_check(det_ok, "A8 the ride frame is right-handed at every point of the drop")
	_check(yaw_worst < 0.5, "A9 the drop's yaw is due south to %.2f deg (a wobble here is a camera whip)" % yaw_worst)
	var min_y: float = INF
	for p in _comet_samples:
		min_y = minf(min_y, p.y)
	_check(min_y >= 0.40, "A10 the rail never dips into the lawn (lowest rail top %.3f)" % min_y)
	# The run-out fits the loop, and the turn is taken under the camera's cap.
	_check(HubFunfair.COMET_BRAKE_RUN_U < _fair.comet_length() - _fair.comet_crest_s() - 10.0, "A11 the run-out (%.1f u) leaves the drop alone" % HubFunfair.COMET_BRAKE_RUN_U)
	# The run-out's OWN speed law walked along the baked turn: yaw rate is
	# curvature times speed, and the speed falls as sqrt(1 - u) from
	# COMET_TURN_SPEED over the turn (the shipped BRAKE law).
	var turn_start: float = _fair.comet_length() - HubFunfair.COMET_BRAKE_RUN_U + HubFunfair.COMET_TRIM_U
	var turn_len: float = HubFunfair.COMET_BRAKE_RUN_U - HubFunfair.COMET_TRIM_U
	var worst_yaw: float = 0.0
	var worst_at: float = 0.0
	var s2: float = turn_start
	while s2 < _fair.comet_length() - 0.3:
		var t0: Vector3 = _fair.comet_tangent(s2)
		var t1: Vector3 = _fair.comet_tangent(s2 + 0.25)
		var k: float = absf(angle_difference(atan2(t0.x, t0.z), atan2(t1.x, t1.z))) / 0.25
		var u: float = clampf((s2 - turn_start) / turn_len, 0.0, 1.0)
		var v: float = maxf(HubFunfair.COMET_TURN_SPEED * sqrt(1.0 - u), 0.25)
		if k * v > worst_yaw:
			worst_yaw = k * v
			worst_at = s2
		s2 += 0.25
	var turn_yaw: float = rad_to_deg(worst_yaw)
	# ⚠️ THE THRESHOLD SITS BETWEEN THE FIX AND ITS ABSENCE (CLAUDE.md
	# CH65): with the trim, the law reads ~150 deg/s at the tightest
	# sample of the turn; without it the cart would enter at ~13 u/s and
	# read ~400. 200 is between the two. What the CAMERA does with it is
	# E23's business (its cap), not this gate's.
	_check(turn_yaw < CART_YAW_LIMIT_DEG, "A12 the run-out's own law yaws the cart at most %.0f deg/s through the bottom turn (at s %.1f; < %.0f, untrimmed ~400)" % [turn_yaw, worst_at, CART_YAW_LIMIT_DEG])
	_check(_fair.comet_post_count() == HubFunfair.comet_post_stations(static_curve).size(), "A13 the builder stood %d posts, the published list names %d" % [_fair.comet_post_count(), HubFunfair.comet_post_stations(static_curve).size()])
	print("")

# =====================================================================
# PHASE B -- CLEARANCES

func _phase_b() -> void:
	print("-- PHASE B: clearances and the region --")
	# B1: every OUTER rail sample inside the region. The offset is taken
	# along the sweep frame's x, both sides, gauge/2 + radius.
	var outside: int = 0
	var tested: int = 0
	var s: float = 0.0
	var half: float = HubFunfair.RAIL_GAUGE * 0.5 + HubFunfair.RAIL_RADIUS
	while s < _fair.comet_length():
		var f: Transform3D = CoasterRail.sweep_frame(_fair.comet_curve(), s)
		for side in [-1.0, 1.0]:
			tested += 1
			var q: Vector3 = _flat(f.origin + f.basis.x * half * side)
			if not HubRegion.contains(q):
				outside += 1
				if outside <= 3:
					print("     outer rail outside the region at (%.2f, %.2f), rail y %.2f" % [q.x, q.z, f.origin.y])
		s += 0.25
	_check(tested > 0 and outside == 0, "B1 every outer-rail sample is over walkable ground (%d / %d outside)" % [outside, tested])
	var posts_out: int = 0
	var stations: Array = HubFunfair.comet_post_stations(_fair.comet_curve())
	for st in stations:
		if not HubRegion.contains(_flat(_fair.comet_point(float(st)))):
			posts_out += 1
	_check(posts_out == 0, "B2 every post foot is on walkable ground (%d of %d outside)" % [posts_out, stations.size()])
	_check(HubRegion.contains(HubFunfair.COMET_STAND) and HubRegion.contains(HubFunfair.COMET_DECK_CENTRE), "B3 the stand and the deck are walkable")
	_check(HubRegion.zone_of(HubFunfair.COMET_STAND) == 0, "B4 the Comet is in zone 0")
	# Layout footprints against the low rails, the posts and the deck.
	var fps: Array = _props.ground_footprints()
	var low_gap: float = INF
	var post_gap: float = INF
	for p in _comet_samples:
		for fp in fps:
			if p.y <= HubFunfair.LOW_RAIL_HEIGHT:
				low_gap = minf(low_gap, _flat(fp["position"]).distance_to(_flat(p)) - float(fp["radius"]) - HubFunfair.RAIL_GAUGE * 0.5)
	for st in stations:
		var p: Vector3 = _fair.comet_point(float(st))
		for fp in fps:
			post_gap = minf(post_gap, _flat(fp["position"]).distance_to(_flat(p)) - float(fp["radius"]) - HubFunfair.COMET_POST_THICK * 0.5)
	var deck_gap: float = INF
	for fp in fps:
		deck_gap = minf(deck_gap, _flat(fp["position"]).distance_to(_flat(HubFunfair.COMET_DECK_CENTRE)) - float(fp["radius"]) - HubFunfair.DECK_FOOTPRINT)
	_check(low_gap >= _clearance, "B5 every low rail clears every layout footprint (tightest %.3f u)" % low_gap)
	_check(post_gap >= _clearance, "B6 every post clears every layout footprint (tightest %.3f u)" % post_gap)
	_check(deck_gap >= _clearance, "B7 the deck's reserve clears every layout footprint (tightest %.3f u)" % deck_gap)
	# The CH71 loop: no Comet rail within a rider's headroom of it, no
	# Comet post on its rails, and the two stations apart.
	var loop_gap: float = INF
	for p in _comet_samples:
		loop_gap = minf(loop_gap, _nearest(_ch71_samples, p))
	_check(loop_gap >= RIDER_HEADROOM, "B8 the Comet's rails stay %.3f u from the CH71 rails (>= %.1f, a rider's headroom)" % [loop_gap, RIDER_HEADROOM])
	var post_loop: float = INF
	for st in stations:
		var p: Vector3 = _flat(_fair.comet_point(float(st)))
		for q in _ch71_samples:
			post_loop = minf(post_loop, p.distance_to(_flat(q)))
	_check(post_loop >= 1.0, "B9 no Comet post stands on the CH71 centre line (nearest %.3f u, flat)" % post_loop)
	_check(_flat(HubFunfair.COMET_POINTS[0]).distance_to(_flat(HubFunfair.TRACK_POINTS[0])) > HubFunfair.COASTER_TAP_RADIUS + HubFunfair.COMET_TAP_RADIUS,
		"B10 the two stations' tap discs never overlap")
	# The zipline cable and the P2 tower's structure lobe.
	var a: Vector3 = P1 + Vector3.UP * CABLE_HEIGHT
	var b: Vector3 = P2 + Vector3.UP * CABLE_HEIGHT
	var cable_gap: float = INF
	var lobe_gap: float = INF
	for p in _comet_samples:
		cable_gap = minf(cable_gap, Geometry3D.get_closest_point_to_segment(p, a, b).distance_to(p))
		if p.y <= HubFunfair.LOW_RAIL_HEIGHT:
			lobe_gap = minf(lobe_gap, _flat(p).distance_to(P2) - HubRegion.STRUCTURE_LOBE_RADIUS)
	_check(cable_gap >= CABLE_CLEARANCE, "B11 the nearest Comet rail is %.3f u from the zipline cable (>= %.1f)" % [cable_gap, CABLE_CLEARANCE])
	_check(lobe_gap >= _clearance, "B12 the low rails stay off the P2 tower's lobe (%.3f u beyond it)" % lobe_gap)
	# Self-clearance: no two parts of the loop far apart along s come
	# within a rider's headroom of each other.
	var close_pairs: int = 0
	var n: int = _comet_samples.size()
	var length: float = _fair.comet_length()
	for i in range(0, n, 2):
		for j in range(i + 2, n, 2):
			var ds: float = minf(float(j - i) * 0.25, length - float(j - i) * 0.25)
			if ds > 6.0 and _comet_samples[i].distance_to(_comet_samples[j]) < RIDER_HEADROOM:
				close_pairs += 1
	_check(close_pairs == 0, "B13 the loop never crosses itself under a rider's headroom (%d close pairs)" % close_pairs)
	# The stand is not inside any solid.
	var stand_clear: bool = not _inside_solid(HubSurface.ground(HubFunfair.COMET_STAND) + Vector3.UP * 0.5, _clearance)
	_check(stand_clear, "B14 the stand point is not within KEEPY_CLEARANCE of a solid")
	# The carpet is kept off the Comet -- and the census can see.
	var inside_fp: int = 0
	var ring: int = 0
	var comet_fps: Array = []
	for fp in HubFunfair.footprints():
		var p: Vector3 = fp["position"]
		if p.z >= 37.5 and p.x <= 30.0:
			comet_fps.append(fp)
	for nm in _scatter.call("batch_nodes"):
		var node := _scatter.get_node_or_null(String(nm)) as MultiMeshInstance3D
		if node == null:
			continue
		for i in node.multimesh.instance_count:
			var o: Vector3 = (node.global_transform * node.multimesh.get_instance_transform(i)).origin
			for fp in comet_fps:
				var d: float = _flat(o).distance_to(_flat(fp["position"]))
				if d < float(fp["radius"]):
					inside_fp += 1
					break
				elif d < float(fp["radius"]) + 1.5:
					ring += 1
					break
	_check(comet_fps.size() > 10, "B15 the fair publishes the Comet's footprints (%d discs north of the CH71 loop)" % comet_fps.size())
	_check(ring > 0, "B16 (blind) the census sees %d carpet instances in the ring just outside them" % ring)
	_check(inside_fp == 0, "B17 and none inside them (%d)" % inside_fp)
	print("")

# =====================================================================
# PHASE C -- THE WINDING JUDGE (CH39)

func _judge(node: MeshInstance3D, station: Vector3, label: String) -> void:
	await _station(station)
	var kept: Material = node.material_override
	var counts: Array = []
	for cull in [BaseMaterial3D.CULL_BACK, BaseMaterial3D.CULL_DISABLED]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.0, 1.0)
		m.cull_mode = cull
		m.set("disable_fog", true)
		node.material_override = m
		var img: Image = await _frame()
		counts.append(_count_magenta(img))
	node.material_override = kept
	await get_tree().process_frame
	var back: int = counts[0]
	var both: int = counts[1]
	_check(back > 0 and both > 0, "C %s paints under both cull modes (%d / %d px)" % [label, back, both])
	_check(absf(back - both) <= maxf(6.0, 0.01 * both), "C %s covers the same pixels under cull_back and cull_disabled (%d vs %d): wound the right way" % [label, back, both])

func _phase_c() -> void:
	print("-- PHASE C: winding judge, cull_back vs cull_disabled --")
	await _judge(_fair.comet_track_node(), COMET_NORTH_VIEW, "comet track")
	await _judge(_fair.comet_node().get_node("CometCartMesh") as MeshInstance3D, COMET_TAP_FROM, "comet cart")
	print("")

# =====================================================================
# PHASE D -- D5: THE COMET'S POSTS ARE LIVE

func _phase_d() -> void:
	print("-- PHASE D: the Comet's solids --")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = _world.get_world_3d().direct_space_state
	var mask: int = 1 << (SkateBoardBody.LAYER_PARK - 1)
	var body: StaticBody3D = _fair.collider_body()
	var stations: Array = HubFunfair.comet_post_stations(_fair.comet_curve())
	var hit_posts: int = 0
	var tall: int = 0
	for st in stations:
		var p: Vector3 = _fair.comet_point(float(st))
		if p.y < 3.0:
			continue
		tall += 1
		# Down the post's own column, from ABOVE the rail: a ray that
		# starts inside a shape reports nothing (Godot's default), and the
		# first draft started 5 cm under the rail -- inside the post -- and
		# read 0 / 28 on posts the board bumps into.
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 0.5, p.z), Vector3(p.x, -1.0, p.z), mask)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] == body:
			hit_posts += 1
	_check(tall > 0 and hit_posts == tall, "D1 a ray down each tall post's column hits the fair's body (%d / %d)" % [hit_posts, tall])
	var q2 := PhysicsRayQueryParameters3D.create(HubFunfair.COMET_STAND + Vector3(0.0, 3.0, 0.0), HubFunfair.COMET_STAND + Vector3(0.0, -1.0, 0.0), mask)
	var hit2: Dictionary = space.intersect_ray(q2)
	_check(hit2.is_empty(), "D2 (blind) a ray down onto the Comet's stand point hits nothing")
	print("")

# =====================================================================
# PHASE E -- THE TWO COASTERS, THROUGH THE PLAYER'S CHANNEL

## The CH71 coaster, free, for the same-bench comparison. Its own gates
## live in FunfairProbe; here only its top speed is read.
func _ride_ch71() -> float:
	print("   -- the CH71 coaster, free, for comparison --")
	_finished_rides.clear()
	_fair.set_brake_override(0)
	await _station(COASTER_TAP_FROM)
	_tap_world(_flat(HubFunfair.TRACK_POINTS[0]))
	await get_tree().process_frame
	await _settle_walk()
	for _i in 3:
		await get_tree().process_frame
	var v_max: float = 0.0
	var frames: int = 0
	while _keepy.is_on_carrier() and frames < 60 * 60:
		await get_tree().process_frame
		frames += 1
		v_max = maxf(v_max, _fair.coaster_speed())
	await _settle_walk(300)
	_fair.set_brake_override(-1)
	print("     CH71 coaster: %d frames aboard, v_max %.3f" % [frames, v_max])
	_check(frames > 300 and _finished_rides.count(HubFunfair.RIDE_COASTER) == 1, "E1 the CH71 coaster still rides to its end through the tap channel (%d frames)" % frames)
	return v_max

func _phase_e() -> void:
	print("-- PHASE E: the rides --")
	# NEGATIVE CONTROL FIRST: a tap on bare ground arms nothing.
	await _station(COMET_TAP_FROM)
	_tap_world(BARE_GROUND)
	await get_tree().process_frame
	_check(_fair.intent() < 0 and not _fair.is_riding(), "E0 (blind) a tap on bare ground arms no ride")
	await _settle_walk()
	var v71: float = await _ride_ch71()
	print("   -- the Comet --")
	_finished_rides.clear()
	await _station(COMET_TAP_FROM)
	var rest: Vector3 = HubFunfair.COMET_POINTS[0]
	_check(_in_frame(_flat(rest), 0.0), "E2 the Comet's rest point is in frame from the tap station")
	var hub_fov: float = _camera.fov
	var hub_far: float = _camera.far
	_tap_world(_flat(rest))
	await get_tree().process_frame
	_check(_fair.intent() == HubFunfair.RIDE_COMET or _fair.is_riding(), "E3 the tap armed the Comet's intent")
	var walked: int = await _settle_walk()
	for _i in 3:
		await get_tree().process_frame
	_check(_keepy.is_on_carrier() and _fair.comet_phase() != HubFunfair.CometPhase.IDLE,
		"E4 he boarded on arrival (%d frames of walk) and the cart departed" % walked)
	if not _keepy.is_on_carrier():
		print("     (no ride -- the rest of PHASE E cannot run)")
		return
	var cart: Node3D = _fair.comet_node()
	var valley_s: float = _fair.comet_valley_s()
	var frames: int = 0
	var v_max: float = 0.0
	var v_valley: float = 0.0
	var v_first_coast: float = -1.0
	var v_trim_entry: float = -1.0
	var v_brake_worst: float = 0.0
	var y_max: float = -INF
	var phases := {}
	var last_phase: int = -1
	var chase_frames: int = 0
	var blend_done_frames: int = 0
	var crown_out: int = 0
	var cam_in_solid: int = 0
	var cam_in_rail: int = 0
	var sight_crossings: int = 0
	var cam_yaw_worst: float = 0.0
	var cart_yaw_worst: float = 0.0
	var cart_yaw_at: float = 0.0
	var cam_over_cap: int = 0
	var yaw_trace: Array = []
	var last_cam_yaw: float = 0.0
	var last_cart_yaw: float = 0.0
	var have_yaw: bool = false
	var last_yaw_frame: int = 0
	var follow_worst: float = 0.0
	var face_worst: float = 0.0
	var prims_max: int = 0
	var prims_sum: int = 0
	var prims_n: int = 0
	# CH76 -- REAL wall time per frame, so the POV's cost in PHASE P has a
	# same-run, same-bench, same-trip number to be read against. Sampled
	# only across a SINGLE elapsed frame: the mid-ride tap block below
	# awaits twice inside one iteration, and a three-frame gap read as one
	# is the mistake E23 already paid for on the yaw.
	var us_max: int = 0
	var us_sum: int = 0
	var us_n: int = 0
	var us_last: int = Time.get_ticks_usec()
	var us_last_frame: int = Engine.get_process_frames()
	var tapped_mid: bool = false
	var withdrawn: bool = false
	var tap_dropped: bool = false
	var rider_tap_answers: bool = false
	var rider_tap_off_body: bool = false
	var pov_opened: bool = false
	var order_ok: bool = true
	var expected_next: int = HubFunfair.CometPhase.DEPART
	while _keepy.is_on_carrier() and frames < 60 * 90:
		await get_tree().process_frame
		if not _keepy.is_on_carrier():
			break
		frames += 1
		var v: float = _fair.comet_speed()
		var s: float = _fair.comet_s()
		var ph: int = _fair.comet_phase()
		if ph != last_phase:
			phases[ph] = frames
			if ph != expected_next:
				order_ok = false
			expected_next = ph + 1
			last_phase = ph
			if ph == HubFunfair.CometPhase.COAST:
				v_first_coast = v
			if ph == HubFunfair.CometPhase.TRIM:
				v_trim_entry = v
		v_max = maxf(v_max, v)
		if ph == HubFunfair.CometPhase.COAST and absf(s - valley_s) < 0.4:
			v_valley = maxf(v_valley, v)
		if ph == HubFunfair.CometPhase.BRAKE:
			v_brake_worst = maxf(v_brake_worst, v)
		y_max = maxf(y_max, _keepy.global_position.y)
		var seat: Vector3 = cart.to_global(HubFunfair.CART_SEAT)
		follow_worst = maxf(follow_worst, seat.distance_to(_keepy.global_position))
		var t: Vector3 = _fair.comet_tangent(s)
		var travel := Vector3(t.x, 0.0, t.z).normalized()
		if travel.length() > 0.5:
			face_worst = maxf(face_worst, rad_to_deg(acos(clampf(_facing().dot(travel), -1.0, 1.0))))
		# The camera.
		if bool(_camera.call("is_driving")):
			chase_frames += 1
		var blend: float = float(_camera.call("drive_blend"))
		var cam: Vector3 = _camera.global_position
		if _inside_solid(cam, CAMERA_SOLID_MARGIN):
			cam_in_solid += 1
			if cam_in_solid <= 4:
				print("     camera inside a solid: cam %s cart %s s %.2f phase %d" % [cam, cart.global_position, s, ph])
		if _nearest(_comet_samples, cam) < CAMERA_RAIL_CLEAR or _nearest(_ch71_samples, cam) < CAMERA_RAIL_CLEAR:
			cam_in_rail += 1
			if cam_in_rail <= 4:
				print("     camera inside a rail: cam %s cart %s s %.2f phase %d" % [cam, cart.global_position, s, ph])
		if blend >= 0.999:
			blend_done_frames += 1
			if not _in_frame(_keepy.global_position + Vector3.UP * CROWN, FRAME_MARGIN_PX):
				crown_out += 1
			# A rail between the camera and the cart, the cart's own rail
			# excluded (the cart sits 6 cm over it, so every frame would
			# count): informational, printed, not gated.
			if _sightline_crossed(cam, cart.global_position) :
				sight_crossings += 1
			var cy: float = _camera_yaw()
			var ky: float = cart.rotation.y
			# ⚠️ PER ELAPSED FRAME, NOT PER LOOP ITERATION: the mid-ride tap
			# tests below await twice inside one iteration, so the sample
			# after them spans three frames. Read as one, a 66 deg/s turn
			# printed as 208 (run 7's yaw trace: 1.1 deg per frame, 3.3
			# over the gap) and E23 went red on a camera under its cap.
			var now_frame: int = Engine.get_process_frames()
			var elapsed: float = float(maxi(now_frame - last_yaw_frame, 1))
			if have_yaw:
				var cam_rate: float = rad_to_deg(absf(angle_difference(last_cam_yaw, cy))) * 60.0 / elapsed
				if cam_rate > rad_to_deg(HubCamera.COASTER_YAW_RATE_MAX) + 2.0 and cam_over_cap < 6:
					cam_over_cap += 1
					print("     camera yaw %.0f deg/s over the cap: s %.2f phase %d blend %.4f cam %s cart %s" % [cam_rate, s, ph, blend, cam, cart.global_position])
					print("       yaw trace (deg, last 4 frames then this): %s ; drive_heading %.2f ; basis.z %s" % [str(yaw_trace), rad_to_deg(float(_camera.call("drive_heading"))), _camera.global_transform.basis.z])
				cam_yaw_worst = maxf(cam_yaw_worst, cam_rate)
				var cart_rate: float = rad_to_deg(absf(angle_difference(last_cart_yaw, ky))) * 60.0 / elapsed
				if cart_rate > cart_yaw_worst:
					cart_yaw_worst = cart_rate
					cart_yaw_at = s
			yaw_trace.append(snappedf(rad_to_deg(cy), 0.01))
			if yaw_trace.size() > 5:
				yaw_trace.pop_front()
			last_cam_yaw = cy
			last_cart_yaw = ky
			last_yaw_frame = now_frame
			have_yaw = true
			var pr: int = _prims()
			prims_max = maxi(prims_max, pr)
			prims_sum += pr
			prims_n += 1
			var us_now: int = Time.get_ticks_usec()
			if now_frame - us_last_frame == 1:
				var dt: int = us_now - us_last
				us_max = maxi(us_max, dt)
				us_sum += dt
				us_n += 1
			us_last = us_now
			us_last_frame = now_frame
		if not tapped_mid and ph == HubFunfair.CometPhase.COAST and s > _fair.comet_crest_s() + 3.0:
			tapped_mid = true
			withdrawn = _fair.accepts_tap(_flat(rest)) == -1
			# A tap on bare ground mid-drop: dropped by state.
			_tap_world(BARE_GROUND)
			await get_tree().process_frame
			tap_dropped = _keepy.is_on_carrier() and not _keepy.is_hopping() and _fair.comet_phase() == HubFunfair.CometPhase.COAST
			# ⚠️ CH76 RE-VISED THIS, IT DID NOT RELAX IT. CH75 gated that
			# the rider's channel was SHUT on the Comet; this lot opens it,
			# so the old assertion is false on the delivered tree and the
			# property that survives is the one underneath: the channel must
			# answer for HIM and for nobody else.
			#
			# ⚠️ AND THE TOGGLE IS NOT DISPATCHED HERE. It is dispatched in
			# PHASE P, on a ride of its own, because a POV opened mid-drop
			# would put every chase reading BELOW this line -- the primitive
			# counter, E10's crown, E11's clearances, E23's yaw -- under the
			# wrong camera and this phase would stop describing the chase.
			var origin: Vector3 = _camera.global_position
			var dir: Vector3 = (_keepy.global_position + Vector3.UP * CROWN * 0.5 - origin).normalized()
			rider_tap_answers = _fair.accepts_rider_tap(origin, dir)
			rider_tap_off_body = not _fair.accepts_rider_tap(origin, (BARE_GROUND - origin).normalized())
			await get_tree().process_frame
			pov_opened = bool(_camera.call("is_pov"))
	var settle: int = await _settle_walk(300)
	var landed_at: Vector3 = _flat(_keepy.global_position)
	# The chase blends home over DRIVE_BLEND_S; wait it out, then read.
	for _i in int(HubCamera.DRIVE_BLEND_S * 60.0) + 10:
		await get_tree().process_frame
	print("     frames aboard %d (%.1f s)  v_max %.3f  first coast %.3f  valley %.3f (closed form %.3f)  trim entry %.3f  brake worst %.3f  y_max %.3f" % [
		frames, frames / 60.0, v_max, v_first_coast, v_valley, _fair.comet_predicted_valley_speed(), v_trim_entry, v_brake_worst, y_max])
	print("     chase frames %d / %d, blend done %d, crown out %d, camera in solid %d, in rail %d, sightline crossings %d" % [
		chase_frames, frames, blend_done_frames, crown_out, cam_in_solid, cam_in_rail, sight_crossings])
	print("     yaw rates: camera %.1f deg/s worst, cart %.1f deg/s worst at s %.2f (cap %.0f); facing worst %.2f deg; follow %.5f; settle %d" % [
		cam_yaw_worst, cart_yaw_worst, cart_yaw_at, rad_to_deg(HubCamera.COASTER_YAW_RATE_MAX), face_worst, follow_worst, settle])
	print("     chase primitives: max %d, mean %d over %d frames" % [prims_max, (prims_sum / maxi(prims_n, 1)), prims_n])
	# ⚠️ A SANDBOX NUMBER, AND IT SAYS SO. llvmpipe is a software
	# rasteriser; this is not the phone's frame time and no reading of it
	# is. What it IS good for is the RATIO against PHASE P's, measured on
	# the same bench over the same trip in the same run -- that ratio is
	# the honest half of "does the POV cost more than the chase".
	print("     chase frame time (SANDBOX llvmpipe, not device): mean %.2f ms, worst %.2f ms over %d single-frame samples" % [
		(float(us_sum) / maxf(float(us_n), 1.0)) / 1000.0, float(us_max) / 1000.0, us_n])
	print("     phases (first frame): %s" % str(phases))
	_check(v_max >= 15.0 and v_max <= 18.5, "E5 the top speed %.2f u/s is the drop the design says (15..18.5)" % v_max)
	_check(v_valley > 0.0 and absf(v_valley - _fair.comet_predicted_valley_speed()) < 0.03 * _fair.comet_predicted_valley_speed(),
		"E6 the energy law is WIRED: valley %.2f vs closed form %.2f (3 %%)" % [v_valley, _fair.comet_predicted_valley_speed()])
	_check(v71 > 0.0 and v_max >= 1.5 * v71, "E7 x%.2f the CH71 coaster's top speed on the same bench (%.2f vs %.2f; >= 1.5)" % [v_max / maxf(v71, 0.001), v_max, v71])
	_check(absf(v_first_coast - HubFunfair.LIFT_SPEED) < 0.05, "E8 the crest is crossed at lift speed (%.2f vs %.2f)" % [v_first_coast, HubFunfair.LIFT_SPEED])
	_check(chase_frames > frames - 5, "E9 the chase camera was driving for the whole ride (%d / %d frames)" % [chase_frames, frames])
	_check(blend_done_frames > 300 and crown_out == 0, "E10 his crown stayed inside the chase's frame every frame after the blend (%d out of %d)" % [crown_out, blend_done_frames])
	_check(cam_in_solid == 0 and cam_in_rail == 0, "E11 the camera never stood inside a solid (%d) or a rail (%d)" % [cam_in_solid, cam_in_rail])
	_check(withdrawn, "E12 the station withdrew from the tap for the length of the ride")
	_check(v_trim_entry > HubFunfair.COMET_TURN_SPEED + 3.0, "E13 the trim brake had speed to shed (entered at %.2f, turn speed %.1f)" % [v_trim_entry, HubFunfair.COMET_TURN_SPEED])
	_check(v_brake_worst <= HubFunfair.COMET_TURN_SPEED + 0.01, "E14 the bottom turn was taken at or under COMET_TURN_SPEED (worst %.2f)" % v_brake_worst)
	_check(phases.has(HubFunfair.CometPhase.LIFT) and phases.has(HubFunfair.CometPhase.COAST) and phases.has(HubFunfair.CometPhase.TRIM) and phases.has(HubFunfair.CometPhase.BRAKE) and order_ok,
		"E15 the run went DEPART, LIFT, COAST, TRIM, BRAKE in that order")
	_check(_finished_rides.count(HubFunfair.RIDE_COMET) == 1 and not _keepy.is_on_carrier() and not _keepy.is_hopping(), "E16 the ride ended once (BOUNDED) and he stands on the ground")
	_check(landed_at.distance_to(HubFunfair.COMET_STAND) < 0.05, "E17 he stepped off onto the Comet's stand point (%.3f u off)" % landed_at.distance_to(HubFunfair.COMET_STAND))
	_check(not bool(_camera.call("is_driving")) and absf(_camera.fov - hub_fov) < 0.01 and absf(_camera.far - hub_far) < 0.01,
		"E18 the chase was released and the hub pose is back (fov %.1f, far %.0f)" % [_camera.fov, _camera.far])
	_check(tap_dropped, "E19 a tap on bare ground mid-drop was dropped by state: still aboard, not hopping, still coasting")
	_check(rider_tap_answers and rider_tap_off_body and not pov_opened,
		"E20 mid-drop the rider's channel answers for HIM (%s) and for nobody else (%s), and nothing opened a POV on its own" % [
			str(rider_tap_answers), str(rider_tap_off_body)])
	_check(follow_worst < 0.001, "E21 he was carried by the cart, not alongside it (worst %.5f u)" % follow_worst)
	_check(face_worst < 20.0, "E22 he faced the way the cart goes, every frame (worst %.2f deg)" % face_worst)
	_check(cam_yaw_worst <= rad_to_deg(HubCamera.COASTER_YAW_RATE_MAX) + 2.0, "E23 the chase never yawed faster than its cap (%.1f deg/s)" % cam_yaw_worst)
	_check(cart_yaw_worst < CART_YAW_LIMIT_DEG, "E24 the cart itself never yawed faster than %.0f deg/s (worst %.1f at s %.2f; a turn's end on the crest read 502)" % [CART_YAW_LIMIT_DEG, cart_yaw_worst, cart_yaw_at])
	_check(_fair.accepts_tap(_flat(rest)) == HubFunfair.RIDE_COMET, "E25 and the station answers again once the ride is over")
	var energy_seat: float = y_max - HubFunfair.CART_SEAT.y
	_check(absf(energy_seat - _fair.comet_peak_rail_y()) < 0.12, "E26 he was carried over the crest (max y %.3f, rail %.3f)" % [y_max, _fair.comet_peak_rail_y()])
	print("")

# =====================================================================
# PHASE P -- CH76: THE POV ON THE COMET, AND WHAT IT COSTS
#
# ⚠️ ENTERED BY THE PLAYER'S OWN CHANNEL, NEVER BY `enter_pov`.
# CLAUDE.md's eighteenth false signal is a probe that drove a prop by its
# API while no tap ever reached it: "une sonde qui gate une INTERACTION
# entre par le canal du joueur". Every toggle below goes through
# `HubTapInput._handle_point` from a real screen point, and the ride is
# boarded the same way. This file never calls `enter_pov` or `exit_pov`.
#
# ⚠️ AND IT IS A SECOND RIDE, ON PURPOSE. One trip cannot be both
# cameras over its whole length, and the brief's question -- what does
# the POV cost against the chase, over the LIFT, the crest, the drop and
# the camelback -- is a comparison of two whole trips. PHASE E rides it
# under the chase and prints its primitives and its frame time; this
# phase rides it again, in the same run, on the same bench, through the
# same channel, and prints the same two quantities. Neither is a device
# number (llvmpipe is a software rasteriser); the RATIO between them is
# what the two runs buy.
#
# ⚠️ THE DOOR TEST GOES IN THE LIFT, NOT THE DROP, AND THAT IS MEASURED.
# Leaving and re-entering the POV costs 2 x POV_BLEND_S = 54 frames of
# blend. The drop (COAST) is 133 frames on this loop; spending 40 % of
# the one section the ride exists for on a blend would leave the cost
# measurement describing a transition rather than a view. The chain lift
# is 738 frames and every one of them is the same picture.

## A tap at a FRACTION of the container, for the points that have no
## world position -- the top of the screen, where a level eye aims at
## the sky and `HubSurface.intersect_ray` answers null.
func _tap_screen(fx: float, fy: float) -> void:
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	_tap._handle_point(rect.position + Vector2(rect.size.x * fx, rect.size.y * fy))

## How much of the picture's lower half still resolves to a point on the
## ground: five rays down the vertical centre line, at 55 % to 95 %.
##
## ⚠️ CH73'S INSTRUMENT, AND THE SINGLE CENTRE RAY WOULD HAVE BEEN A
## CONSTANT. `pov_pitch_deg(RIDE_COMET)` is 0.0, so `_pov_wanted` aims
## the eye EXACTLY level and the centre ray is parallel to the plane:
## `intersect_ray` answers null on every frame of the ride, by
## arithmetic rather than by measurement. Sampling DOWN the frame asks
## the question that has an answer -- how much of what he sees is world.
func _ground_fraction() -> float:
	var hit: int = 0
	for i in 5:
		var local := Vector2(float(_sub.size.x) * 0.5, float(_sub.size.y) * (0.55 + 0.10 * float(i)))
		if HubSurface.intersect_ray(_camera.project_ray_origin(local), _camera.project_ray_normal(local)) != null:
			hit += 1
	return float(hit) / 5.0

## The fov the two published blends say the camera should be at, from the
## accessors and nothing else. Read against the LIVE `fov` while the POV
## fades: a base read back off the live value instead of recomputed would
## creep toward POV_FOV at any blend, and this is what would catch it.
func _fov_expected() -> float:
	var tuning: Variant = _camera.call("drive_tuning")
	var drive_fov: float = float(tuning.fov) if tuning != null else float(_camera.call("hub_fov"))
	var base: float = lerpf(float(_camera.call("hub_fov")), drive_fov, float(_camera.call("drive_blend")))
	return lerpf(base, HubCamera.POV_FOV, float(_camera.call("pov_blend")))

func _phase_p() -> void:
	print("-- PHASE P: the POV on the Comet, through the tap channel --")
	# P0 / P1, the blind controls FIRST: he is on his feet, so a tap on
	# his own body is an ordinary walk and nothing swaps.
	await _station(COMET_TAP_FROM)
	_check(not bool(_camera.call("is_pov")), "P0 (blind) no POV before any of this")
	_tap_world(_keepy.global_position + Vector3.UP * (CROWN * 0.5))
	await get_tree().process_frame
	_check(not bool(_camera.call("is_pov")), "P1 (blind) a tap on his body while NOT riding opens no POV")
	await _settle_walk()
	# Board, through the tap channel.
	_finished_rides.clear()
	await _station(COMET_TAP_FROM)
	var hub_fov: float = float(_camera.call("hub_fov"))
	_tap_world(_flat(HubFunfair.COMET_POINTS[0]))
	await get_tree().process_frame
	await _settle_walk()
	for _i in 3:
		await get_tree().process_frame
	if not _keepy.is_on_carrier():
		_check(false, "P2 he boarded the Comet a second time (he did not -- the rest of PHASE P cannot run)")
		return
	_check(_fair.comet_phase() != HubFunfair.CometPhase.IDLE, "P2 he is aboard the Comet and it has departed")
	# P3 -- THE DOOR CH75 REFUSED. This is the assertion whose sign this
	# lot flips: E20 gates that the channel is shut on the shipped tree,
	# and the tree cannot satisfy both.
	var body: Vector3 = _keepy.global_position + Vector3.UP * (CROWN * 0.5)
	var origin: Vector3 = _camera.global_position
	var dir: Vector3 = (body - origin).normalized()
	_check(_fair.accepts_rider_tap(origin, dir), "P3 a tap on the RAY through the rider now means him, under the chase")
	# P4 -- ONE GESTURE, TWO DISPATCHES, ONE TOGGLE (the finger arrives
	# twice; FunfairProbe M3's reasoning, on this ride).
	_tap_world(body)
	_tap_world(body)
	for _i in int(HubCamera.POV_BLEND_S * 60.0) + 20:
		await get_tree().process_frame
	_check(bool(_camera.call("is_pov")) and float(_camera.call("pov_blend")) > 0.9,
		"P4 one gesture (dispatched TWICE) entered the POV once and STAYED (blend %.3f)" % float(_camera.call("pov_blend")))
	# P5 -- AND THE CHASE IS STILL THE DRIVE UNDERNEATH. This is the
	# whole of the lot's shape in one reading: the POV did not replace
	# the chase with a second pose, it blends over the one the drive
	# branch writes, so `is_driving()` is still true and `far` is still
	# the drive's.
	_check(bool(_camera.call("is_driving")), "P5 the chase is still the drive underneath -- the POV is a blend over it, not a second pose")
	# P6..P9 -- the pose IS his head, read off the LIVE camera.
	var head: Node3D = _keepy.head_anchor()
	var at_head: float = _camera.global_position.distance_to(head.global_position)
	var right: Vector3 = _camera.global_transform.basis.x
	var roll: float = rad_to_deg(asin(clampf(right.y, -1.0, 1.0)))
	var look: Vector3 = -_camera.global_transform.basis.z
	var pitch: float = rad_to_deg(asin(clampf(-look.y, -1.0, 1.0)))
	print("     POV: %.4f u from the head, roll %.4f deg, pitch %.2f deg (the Comet asks %.1f), fov %.1f (drive blend %.3f)" % [
		at_head, roll, pitch, HubFunfair.pov_pitch_deg(HubFunfair.RIDE_COMET), _camera.fov, float(_camera.call("drive_blend"))])
	_check(at_head < 0.02, "P6 the camera sits ON the head anchor (%.4f u) -- under a CHASE, which is what CH72's overlay could not do" % at_head)
	_check(absf(roll) < 0.01, "P7 and it does not roll (%.4f deg) -- the term that makes a POV sickening" % roll)
	_check(absf(pitch - HubFunfair.pov_pitch_deg(HubFunfair.RIDE_COMET)) < 1.0,
		"P8 it looks level, the %.1f deg the Comet asks for (%.2f) -- NOT the tower's %.1f" % [
			HubFunfair.pov_pitch_deg(HubFunfair.RIDE_COMET), pitch, HubFunfair.TOWER_POV_PITCH_DEG])
	_check(absf(_camera.fov - HubCamera.POV_FOV) < 0.5, "P9 and it is at the POV fov (%.1f)" % _camera.fov)
	# =================================================================
	# THE DOORS, in the chain lift where there is room for two blends.
	var phase_at_door: int = _fair.comet_phase()
	# P10 -- OUT BY A TAP ON THE TOP OF THE SCREEN. THE PATRON-ECHELLE
	# GATE, and on this ride it is not a formality: the eye is LEVEL, so
	# the whole upper half of the picture aims at or above the horizon,
	# where `HubSurface.intersect_ray` answers null and `_handle_point`
	# gives up three lines later. This tap is the only way out.
	# ⚠️ A BRACKET, NOT A THRESHOLD, AND THE BENCH'S OWN FLOOR IS WHY.
	# The first draft compared `fov` to the expectation built from the
	# blends READ AFTER the frame, and went red at 0.34887 on a correct
	# tree: `fov` is written inside `_process` and the tween steps
	# elsewhere in the same frame, so the live value legitimately holds
	# the PREVIOUS frame's blend. One frame of a sine-eased 0.45 s fade
	# across 58 -> 64 is about a third of a degree, which is exactly what
	# was measured -- an instrument skew, not a defect, and CLAUDE.md is
	# explicit that the answer is to measure the floor rather than widen
	# a threshold until the noise fits under it. Bracketed between the two
	# consecutive expectations the skew cannot produce a reading at all,
	# and there is no number to tune: the defect this exists for reads
	# 13 degrees OUTSIDE the bracket (the hub's 45 against a chase whose
	# expectation never leaves 58..64), against an epsilon of 0.01.
	var fov_drift: float = 0.0
	var head_recede: bool = true
	var last_gap: float = -1.0
	var exp_prev: float = _fov_expected()
	_tap_screen(0.5, 0.06)
	for _i in int(HubCamera.POV_BLEND_S * 60.0) + 20:
		await get_tree().process_frame
		var exp_now: float = _fov_expected()
		var lo: float = minf(exp_prev, exp_now)
		var hi: float = maxf(exp_prev, exp_now)
		fov_drift = maxf(fov_drift, maxf(lo - _camera.fov, _camera.fov - hi))
		exp_prev = exp_now
		# P12's evidence: the eye RECEDES from the head as the blend
		# falls. Under a base read back off the live pose it would creep
		# toward the POV instead and stay put.
		var gap: float = _camera.global_position.distance_to(head.global_position)
		if last_gap >= 0.0 and float(_camera.call("pov_blend")) > 0.0 and gap < last_gap - 0.001:
			head_recede = false
		last_gap = gap
	_check(not bool(_camera.call("is_pov")), "P10 a tap on the TOP of the screen -- where a level eye aims at no ground -- swapped back to the chase")
	_check(_keepy.is_on_carrier() and not _keepy.is_hopping() and _fair.comet_phase() != HubFunfair.CometPhase.IDLE,
		"P11 and it did not walk him off the ride, which is still running")
	# ⚠️ TWO ASSERTIONS, NOT ONE. The first draft asked both halves at
	# once and went red at 19.00000; a red that names two properties sends
	# the next reader to diagnose whichever he guesses. Split, the fov half
	# named the defect on its own (CH72's unconditional `fov = _hub_fov`
	# in `_on_pov_exited`, painting the hub's 45 over the chase's 64) while
	# the recede half stayed green, which is what said the base was already
	# recomputed correctly.
	_check(fov_drift < 0.01,
		"P12 the fade held INSIDE the bracket its two published blends allow, every frame -- worst excursion %.5f (a hub fov slammed over the chase reads about 13)" % fov_drift)
	_check(head_recede,
		"P12b and the eye RECEDED from the head as the blend fell -- the base is recomputed, not read back off the pose this function wrote")
	# P13 -- back in, for the rest of the ride.
	_tap_world(_keepy.global_position + Vector3.UP * (CROWN * 0.5))
	for _i in int(HubCamera.POV_BLEND_S * 60.0) + 20:
		await get_tree().process_frame
	_check(bool(_camera.call("is_pov")), "P13 back into the POV for the rest of the trip")
	# =================================================================
	# THE RIDE, IN THE POV, TO THE RUN-OUT.
	var frames: int = 0
	var held: int = 0
	var eye_solid: int = 0
	var eye_rail_worst: float = INF
	var eye_rail_at: float = 0.0
	var eye_rail_phase: int = -1
	var eye_rail_which: String = "-"
	var eye_rail_where: Vector3 = Vector3.ZERO
	var roll_worst: float = 0.0
	var pitch_worst: float = 0.0
	var head_worst: float = 0.0
	var prims_max: int = 0
	var prims_sum: int = 0
	var prims_n: int = 0
	var us_max: int = 0
	var us_sum: int = 0
	var us_n: int = 0
	var us_last: int = Time.get_ticks_usec()
	var us_last_frame: int = Engine.get_process_frames()
	var still_pov: bool = true
	var phases_seen := {}
	# Per-phase readings of what the level eye actually contains.
	var ground_sum := {}
	var ground_n := {}
	var rail_in_view := {}
	var stride: int = 4
	while _keepy.is_on_carrier() and frames < 60 * 90:
		await get_tree().process_frame
		if not _keepy.is_on_carrier():
			break
		frames += 1
		var ph: int = _fair.comet_phase()
		phases_seen[ph] = true
		if not bool(_camera.call("is_pov")):
			still_pov = false
		if float(_camera.call("pov_blend")) < 0.999:
			continue
		held += 1
		var eye: Vector3 = _camera.global_position
		head_worst = maxf(head_worst, eye.distance_to(head.global_position))
		var rgt: Vector3 = _camera.global_transform.basis.x
		roll_worst = maxf(roll_worst, absf(rad_to_deg(asin(clampf(rgt.y, -1.0, 1.0)))))
		var lk: Vector3 = -_camera.global_transform.basis.z
		pitch_worst = maxf(pitch_worst, absf(rad_to_deg(asin(clampf(-lk.y, -1.0, 1.0)))))
		if _inside_solid(eye, EYE_SOLID_MARGIN):
			eye_solid += 1
			if eye_solid <= 4:
				print("     EYE inside a solid: %s s %.2f phase %d" % [eye, _fair.comet_s(), ph])
		var d_comet: float = _nearest(_comet_samples, eye)
		var d_ch71: float = _nearest(_ch71_samples, eye)
		var d_rail: float = minf(d_comet, d_ch71)
		if d_rail < eye_rail_worst:
			eye_rail_worst = d_rail
			eye_rail_at = _fair.comet_s()
			eye_rail_phase = ph
			# WHICH rail, and where it is: "a rail came near" and "the rail
			# he is riding came near" are not the same reading, and the eye
			# rides 1.89 u over its own, so anything under that is another
			# piece of structure.
			eye_rail_which = "the Comet" if d_comet <= d_ch71 else "the CH71 loop"
			eye_rail_where = _nearest_sample(_comet_samples if d_comet <= d_ch71 else _ch71_samples, eye)
		var g: float = _ground_fraction()
		ground_sum[ph] = float(ground_sum.get(ph, 0.0)) + g
		ground_n[ph] = int(ground_n.get(ph, 0)) + 1
		# Structure IN the picture and near: the POV's answer to the
		# chase's 61 sightline crossings. A rail in view is not a defect
		# here -- it is the ride -- so this is PRINTED, never gated.
		var seen: int = 0
		var i: int = 0
		while i < _comet_samples.size():
			var q: Vector3 = _comet_samples[i]
			i += stride
			if q.distance_to(eye) > EYE_NEAR_FIELD:
				continue
			if _in_frame(q, 0.0):
				seen += 1
		rail_in_view[ph] = maxi(int(rail_in_view.get(ph, 0)), seen)
		var pr: int = _prims()
		prims_max = maxi(prims_max, pr)
		prims_sum += pr
		prims_n += 1
		var nf: int = Engine.get_process_frames()
		var us_now: int = Time.get_ticks_usec()
		if nf - us_last_frame == 1:
			var dt: int = us_now - us_last
			us_max = maxi(us_max, dt)
			us_sum += dt
			us_n += 1
		us_last = us_now
		us_last_frame = nf
	var settle: int = await _settle_walk(300)
	for _i in int(HubCamera.DRIVE_BLEND_S * 60.0) + 20:
		await get_tree().process_frame
	print("     POV held %d of %d frames aboard; phases seen %s (the door was opened in phase %d)" % [held, frames, str(phases_seen.keys()), phase_at_door])
	print("     pose: worst %.4f u off the head, worst roll %.4f deg, worst pitch %.3f deg" % [head_worst, roll_worst, pitch_worst])
	print("     the eye: inside a solid %d frames; nearest rail %.3f u -- %s at %s, with the rider at s %.2f in phase %d (floor %.2f, near plane %.3f, and the eye rides 1.89 u over its OWN rail)" % [
		eye_solid, eye_rail_worst, eye_rail_which, str(eye_rail_where), eye_rail_at, eye_rail_phase, EYE_RAIL_CLEAR, _camera.near])
	for ph in ground_n.keys():
		print("       phase %d: %d frames, %.0f %% of the lower frame resolves to ground, up to %d rail samples in view within %.0f u" % [
			ph, int(ground_n[ph]), 100.0 * float(ground_sum[ph]) / float(ground_n[ph]), int(rail_in_view.get(ph, 0)), EYE_NEAR_FIELD])
	print("     POV primitives: max %d, mean %d over %d frames" % [prims_max, (prims_sum / maxi(prims_n, 1)), prims_n])
	print("     POV frame time (SANDBOX llvmpipe, not device): mean %.2f ms, worst %.2f ms over %d single-frame samples" % [
		(float(us_sum) / maxf(float(us_n), 1.0)) / 1000.0, float(us_max) / 1000.0, us_n])
	_check(held > 600 and still_pov, "P14 the POV was held for the whole rest of the trip (%d of %d frames) and the ride ran ON under it" % [held, frames])
	_check(phases_seen.has(HubFunfair.CometPhase.COAST) and phases_seen.has(HubFunfair.CometPhase.TRIM) and phases_seen.has(HubFunfair.CometPhase.BRAKE),
		"P15 and the measured window covers the crest, the drop, the camelback and the run-out")
	# ⚠️ EVERY ONE OF THESE CARRIES `measured` -- THE BOOLEAN THAT SAYS
	# THE EVENT HAPPENED. Each is a reading over frames the POV was fully
	# up, and each has an initialiser that satisfies its own threshold:
	# `head_worst` and `roll_worst` start at 0.0, `eye_rail_worst` starts
	# at INF. With no POV held they are not small readings, they are NO
	# readings -- and all four would print green. CLAUDE.md, CH69: "toute
	# grandeur qui n'a de sens qu'APRES un evenement se publie avec le
	# booleen 'l'evenement a eu lieu', et le gate exige les DEUX". Found by
	# writing out this lot's third red pass before running it: it predicted
	# four free greens, and they were there.
	var measured: bool = held > 600
	_check(measured and head_worst < 0.02, "P16 the eye stayed ON the head anchor for every held frame (%d frames, worst %.4f u)" % [held, head_worst])
	_check(measured and roll_worst < 0.01, "P17 and it never rolled (%d frames, worst %.4f deg)" % [held, roll_worst])
	_check(measured and pitch_worst < 1.0, "P18 and it never pitched off the level the Comet asks for (%d frames, worst %.3f deg)" % [held, pitch_worst])
	_check(measured and eye_solid == 0, "P19 the eye never stood inside a solid of the fair (%d frames held, %d inside)" % [held, eye_solid])
	_check(measured and eye_rail_worst > EYE_RAIL_CLEAR and is_finite(eye_rail_worst),
		"P20 and no rail came through the rider's face (%d frames, nearest %.3f u, floor %.2f)" % [held, eye_rail_worst, EYE_RAIL_CLEAR])
	_check(_finished_rides.count(HubFunfair.RIDE_COMET) == 1 and not _keepy.is_on_carrier() and not _keepy.is_hopping(),
		"P21 the ride still ended once (BOUNDED) and he stands on the ground (settle %d)" % settle)
	_check(not bool(_camera.call("is_pov")), "P22 the POV did NOT outlive the ride -- it closed with it")
	_check(not bool(_camera.call("is_driving")) and absf(_camera.fov - hub_fov) < 0.001,
		"P23 the chase was released too and the hub fov came back EXACTLY (%.4f vs %.4f)" % [_camera.fov, hub_fov])
	_check(_fair.accepts_tap(_flat(HubFunfair.COMET_POINTS[0])) == HubFunfair.RIDE_COMET, "P24 and the station answers again")
	print("")

# =====================================================================
# PHASE G -- BUDGET

func _phase_g() -> void:
	print("-- PHASE G: budget, Comet shown vs hidden (gpu = opaque prims; scene = replay) --")
	var stations: Array = [["spawn", SPAWN], ["comet tap", COMET_TAP_FROM], ["north view", COMET_NORTH_VIEW], ["south view", COMET_SOUTH_VIEW]]
	var site_delta: int = 0
	var scene_delta: int = -1
	var spawn_gpu: int = 0
	var track: MeshInstance3D = _fair.comet_track_node()
	var cart: Node3D = _fair.comet_node()
	for st in stations:
		await _station(st[1])
		get_tree().paused = true
		for _i in SETTLE:
			await get_tree().process_frame
		var a: Dictionary = await _read()
		var a2: Dictionary = await _read()
		track.visible = false
		cart.visible = false
		for _i in SETTLE:
			await get_tree().process_frame
		var b: Dictionary = await _read()
		track.visible = true
		cart.visible = true
		for _i in SETTLE:
			await get_tree().process_frame
		get_tree().paused = false
		var floor_: int = absi(int(a["gpu"]) - int(a2["gpu"]))
		var d: int = int(a["gpu"]) - int(b["gpu"])
		print("     %-12s gpu %6d (floor %d) -> hidden %6d  delta %+6d   calls %3d -> %3d   scene %d -> %d (%+d)" % [
			st[0], int(a["gpu"]), floor_, int(b["gpu"]), d, int(a["calls"]), int(b["calls"]), int(a["scene"]), int(b["scene"]), int(a["scene"]) - int(b["scene"])])
		if st[0] == "north view":
			site_delta = d
		if st[0] == "spawn":
			spawn_gpu = int(a["gpu"])
		scene_delta = int(a["scene"]) - int(b["scene"])
	_check(scene_delta == _fair.comet_triangle_total(), "G1 the replay's scene delta IS the Comet's published triangle total (%d vs %d)" % [scene_delta, _fair.comet_triangle_total()])
	_check(site_delta > 0, "G2 the Comet costs primitives from the north view (%+d)" % site_delta)
	print("     (the chase's own cost is printed in PHASE E: max / mean primitives over the ride, against %d at the spawn)" % spawn_gpu)
	print("")

# =====================================================================
# PHASE H -- PIXELS

func _phase_h() -> void:
	print("-- PHASE H: the Comet is SEEN (hide / re-read, against the floor) --")
	var track: MeshInstance3D = _fair.comet_track_node()
	var cart: Node3D = _fair.comet_node()
	for st in [["north view", COMET_NORTH_VIEW], ["south view", COMET_SOUTH_VIEW]]:
		await _station(st[1])
		get_tree().paused = true
		for _i in SETTLE:
			await get_tree().process_frame
		var a: Image = await _frame()
		var a2: Image = await _frame()
		track.visible = false
		cart.visible = false
		var b: Image = await _frame()
		track.visible = true
		cart.visible = true
		await _frame()
		get_tree().paused = false
		var floor_: int = _diff_pixels(a, a2)
		var d: int = _diff_pixels(a, b)
		print("     %-12s changed %6d px when hidden, floor %d" % [st[0], d, floor_])
		_check(d > 3 * floor_ + 400, "H %s: the Comet paints pixels well above the floor" % st[0])
	print("")
