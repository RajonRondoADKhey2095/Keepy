extends Node
class_name QuadProbe
## CH79 -- the quad raptor's contracts, gated on the LIVE HubWorld.tscn.
##
## DRIVER: xvfb-run --rendering-driver opengl3. NOT headless, and the
## reason is CLAUDE.md's, not a preference: this probe dispatches real
## screen coordinates through HubTapInput, which drops any point outside
## its own container rect -- and under the dummy driver that rect is
## degenerate, so every tap would be silently thrown away and every
## assertion of the form "he did not move" would pass in green. PHASE I
## asserts the rect is real before anything else runs.
##
## =====================================================================
## WHAT A BENCH MAY AND MAY NOT SIGN HERE (CH62)
##
## ⚠️ NOTHING BELOW SAYS THE MOUNT IS FUN TO RIDE. A headless bench does
## not see a sensation, a pace or a silhouette. What it signs is:
##
##   * the DOOR works through the channel a thumb actually uses;
##   * the five-way invariant holds (driving == on_carrier == writer ==
##     chase camera == HUD), and `is_afoot()` flips with it;
##   * the two continuous gestures -- driving the mount and orbiting the
##     camera -- are separated BY MODE, proved in both directions;
##   * the drive is a PROFILE and not just a top speed (CH54);
##   * the wall bounds it and does not lock it up;
##   * it can leave a standstill facing uphill (the sled's lock-up);
##   * the mesh is wound the way this engine reads as front-facing;
##   * and what it costs, measured against a noise floor.
##
## The RIDE ITSELF -- whether a raptor at 11.79 u/s feels like a raptor,
## and whether a box placeholder reads as an animal -- is a device call
## and is named as one in the report.

const BUDGET_S: float = 1500.0
const VP_SIZE: Vector2i = Vector2i(540, 960)
## A station on open plateau, well inside the region, used by every phase
## that needs somewhere neutral to drive.
const OPEN: Vector3 = Vector3(-18.0, 0.0, 18.0)
## PHASE B's sampling, on NorthBudgetProbe's model: spaced reads, never
## back to back -- the things that move in this hub move over SECONDS.
const B_REPEATS: int = 6
const B_GAP: int = 12
const B_SETTLE: int = 3

var _hub: Node = null
var _world: Node3D = null
var _keepy: KeepyHopper = null
var _camera: HubCamera = null
var _sub: SubViewport = null
var _tap: HubTapInput = null
var _transport: HubTransport = null
var _quad: QuadRaptorBody = null
var _hud: KartHud = null
var _fails: int = 0

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract.
	ProbeWatchdog.arm(self, "QUAD PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_world = _hub.get_node("WorldViewport/SubViewport/World") as Node3D
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as KeepyHopper
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as HubCamera
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport
	_tap = _hub.get_node("TapInput") as HubTapInput
	_transport = _world.get_node("Transport") as HubTransport
	var overlay: Node = _hub.get_node_or_null("PerfOverlay")
	if overlay != null:
		overlay.set_process(false)

func _check(ok: bool, what: String, detail: String = "") -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s%s" % ["OK " if ok else "RED", what, "" if detail == "" else "  -- " + detail])

func _process(_delta: float) -> void:
	set_process(false)
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	_sub.size = VP_SIZE
	box.size = Vector2(VP_SIZE)
	_run()

func _run() -> void:
	print("=== QUAD PROBE -- CH79 ===")
	# ⚠️ THE WEATHER IS PINNED (CH72). Every pixel and primitive read below
	# would otherwise depend on how many phases ran before it: the rain,
	# the storm and the snow cross `paused`, and a noise floor taken in a
	# storm is seventy times the one taken in sun.
	var weather := _world.get_node_or_null("CozyWeather") as CozyWeather
	if weather != null:
		weather.force(CozyWeather.Kind.SUN)
	_quad = _transport.quad()
	_hud = _hub.get_node_or_null("KartHud") as KartHud
	await _frames(40)
	_phase_instrument()
	_phase_park()
	_phase_mesh()
	await _phase_door()
	await _phase_gesture()
	await _phase_drive()
	await _phase_wall()
	_phase_hill()
	await _phase_budget()
	print("=== QUAD PROBE: %d assertions red ===" % _fails)
	await _frames(2)
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)

func _to_screen(world: Vector3) -> Vector2:
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	var local: Vector2 = _camera.unproject_position(world)
	local.x *= rect.size.x / float(_sub.size.x)
	local.y *= rect.size.y / float(_sub.size.y)
	return local + rect.position

## Park Keepy and WAIT FOR THE CAMERA, which is not the same thing --
## CH77's instrument defect, in as many words: HubCamera lerps with a
## 0.2 s time constant, so a fixed frame count leaves every unproject
## taken through a camera that is not where the probe thinks it is, the
## tap lands outside the rect and is dropped, and the reading is
## indistinguishable from ground that refused.
func _park(at: Vector3) -> bool:
	_keepy.global_position = HubSurface.ground(at)
	var want := HubSurface.ground(at) + HubCamera.OFFSET
	for i in 240:
		await get_tree().process_frame
		if _camera.global_position.distance_to(want) < 0.05:
			return true
	return _camera.global_position.distance_to(want) < 0.05

func _settle(cap: int = 1400) -> int:
	var frames: int = 0
	await get_tree().process_frame
	frames += 1
	while _keepy.is_hopping() and frames < cap:
		await get_tree().process_frame
		frames += 1
	return frames

func _press(at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = true
	e.position = at
	return e

func _release(at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = false
	e.position = at
	return e

func _drag(at: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = at
	return e

# =====================================================================
# PHASE I -- the instrument, before anything is asserted with it.

func _phase_instrument() -> void:
	print("\nPHASE I -- the instrument")
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	var rect: Rect2 = container.get_global_rect()
	_check(rect.size.x > 100.0 and rect.size.y > 100.0,
		"the container has a real rect (a degenerate one makes every dropped tap look like a refusal)",
		str(rect.size))
	_check(_sub.size.x > 0 and _sub.size.y > 0, "the SubViewport has a real size", str(_sub.size))
	_check(_quad != null, "the transport built a quad raptor")
	_check(_hud != null, "the vehicle HUD resolved")
	_check(_camera != null and _camera is HubCamera, "the camera is a HubCamera")

# =====================================================================
# PHASE P -- the park, asserted against the four properties CH79 chose it
# for. These are the recon's answer RE-MEASURED on the built world, not
# read back out of the constant that was written from it.

func _phase_park() -> void:
	print("\nPHASE P -- the park")
	var at: Vector3 = HubTransport.QUAD_PARK
	_check(_quad.flat_position().distance_to(at) < 0.01,
		"it waits at its park", str(_quad.flat_position()))
	_check(absf(_quad.global_position.y - HubSurface.ground(at).y) < 0.001,
		"and on the ground, height read off HubSurface", "%.4f" % _quad.global_position.y)
	_check(QuadRaptorBody.drivable(at), "the park is drivable ground")
	_check(HubRegion.zone_of(at) == 0, "it is in zone 0", str(HubRegion.zone_of(at)))
	# Its own disc fits inside the region, 16 azimuths (CH21).
	var out: int = 0
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		var p: Vector3 = at + Vector3(cos(a), 0.0, sin(a)) * (HubTransport.QUAD_FOOTPRINT + KeepyHopper.ARRIVE_EPSILON)
		if not HubRegion.contains(p):
			out += 1
	_check(out == 0, "its own footprint fits inside the region with ARRIVE_EPSILON to spare", "%d/16 outside" % out)
	# It can LEAVE: 6 u of drivable ground all round, the recon's binding
	# constraint re-asked of the built world.
	var blocked: int = 0
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		if not QuadRaptorBody.drivable(at + Vector3(cos(a), 0.0, sin(a)) * 6.0):
			blocked += 1
	_check(blocked == 0, "6 u of drive-out all round (a vehicle that cannot leave is not parked)",
		"%d/16 blocked" % blocked)
	# Keepy does not start the session standing inside it.
	var gap: float = at.length() - HubTransport.QUAD_FOOTPRINT - 0.66
	_check(gap > 0.0, "the spawn point is clear of its body (QUAD_FOOTPRINT + KEEPY_CLEARANCE)", "%.3f u" % gap)
	# The tap disc does not straddle the plaza's axis.
	_check(absf(at.x) >= HubTransport.QUAD_TAP_RADIUS,
		"the mount disc clears the plaza axis, so it never steals a ground tap there", "%.2f" % absf(at.x))
	# And the two tapped vehicles are on opposite sides of that axis.
	_check(signf(at.x) != signf(HubTransport.BALL_PARK.x),
		"it sits on the OTHER side of the axis from the hoppity ball (CH78)",
		"quad x %.1f, ball x %.1f" % [at.x, HubTransport.BALL_PARK.x])
	# BLIND: the two parks do not overlap at all.
	var d: float = at.distance_to(HubTransport.BALL_PARK)
	_check(d > HubTransport.QUAD_FOOTPRINT + HubTransport.BALL_FOOTPRINT,
		"blind: the quad's and the ball's discs are disjoint", "%.3f u apart" % d)

	# ---- CH78, and it lives HERE on purpose ------------------------------
	# The brief for the ball's move asked for no probe of its own, and it
	# does not need one: nothing about the ball's MECHANICS changed. What
	# does need a gate is the pair of facts CH78 and CH79 chose AGAINST
	# EACH OTHER, and a gate on a pair has to see both parks. So the ball's
	# three properties are asserted in the probe that already holds the
	# quad's.
	var ball: Vector3 = HubTransport.BALL_PARK
	# ⚠️ A LITERAL, DELIBERATELY. 4.428 u is the distance CH78 claims to
	# have changed, so it must NOT be read back out of the constant that
	# changed -- that would be a tautology (CH77's rule for its own pins).
	const BALL_PARK_SHIPPED_U: float = 4.428
	_check(ball.length() > BALL_PARK_SHIPPED_U * 5.0,
		"CH78: the ball's park moved FAR from the spawn plaza",
		"%.3f u, was %.3f" % [ball.length(), BALL_PARK_SHIPPED_U])
	_check(HubRegion.contains(ball) and HubRegion.zone_of(ball) == 0,
		"CH78: and it is still in zone 0, inside the region", "zone %d" % HubRegion.zone_of(ball))
	var ball_out: int = 0
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		if not HubRegion.contains(ball + Vector3(cos(a), 0.0, sin(a)) * (HubTransport.BALL_FOOTPRINT + KeepyHopper.ARRIVE_EPSILON)):
			ball_out += 1
	_check(ball_out == 0, "CH78: its own disc fits inside the region (CH21: a centre on the border is not enough)",
		"%d/16 outside" % ball_out)
	# It is still in the spawn frame cone, which is the property the
	# shipped park was chosen for and the one the move had to keep.
	_check(ball.z < 8.9 and absf(ball.x) <= 0.414 * (8.9 - ball.z),
		"CH78: and it is still inside the spawn frame cone",
		"|x| %.2f vs half-width %.2f" % [absf(ball.x), 0.414 * (8.9 - ball.z)])

# =====================================================================
# PHASE X -- the mesh. Winding per CONVEX PIECE, and the piece grouping is
# read off the published constants rather than guessed: SledProbe's first
# version tested a five-box assembly against its whole centre of mass and
# reported 46 of 60 triangles wrong on a mesh the render proved correct.

func _phase_mesh() -> void:
	print("\nPHASE X -- the placeholder mesh")
	var hull: ArrayMesh = QuadRaptorBody.build_mesh()
	var leg: ArrayMesh = QuadRaptorBody.leg_mesh()
	var hull_tris: int = hull.get_faces().size() / 3
	var leg_tris: int = leg.get_faces().size() / 3
	var published: Array[int] = _quad.triangle_count()
	_check(hull_tris == QuadRaptorBody.PIECE_TRIS * QuadRaptorBody.HULL_PIECES,
		"the hull is HULL_PIECES boxes of PIECE_TRIS", "%d tris" % hull_tris)
	_check(leg_tris == QuadRaptorBody.PIECE_TRIS, "one leg is one box", "%d tris" % leg_tris)
	_check(published[0] == hull_tris and published[1] == leg_tris * QuadRaptorBody.LEG_PIECES,
		"triangle_count() publishes what the meshes actually carry",
		"%d + %d" % [published[0], published[1]])
	print("   the whole placeholder costs %d triangles" % (published[0] + published[1]))
	_check(_wound(hull, QuadRaptorBody.PIECE_TRIS) == 0,
		"every hull triangle is wound the way this engine reads as FRONT (per convex piece)")
	_check(_wound(leg, QuadRaptorBody.PIECE_TRIS) == 0,
		"and so is the leg")
	# BLIND: the test can FAIL. A winding check that cannot go red is a
	# comment. Feed it the same mesh with every triangle reversed.
	var flipped := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: PackedVector3Array = hull.get_faces()
	var i: int = 0
	while i < faces.size():
		st.add_vertex(faces[i])
		st.add_vertex(faces[i + 2])
		st.add_vertex(faces[i + 1])
		i += 3
	flipped = st.commit()
	_check(_wound(flipped, QuadRaptorBody.PIECE_TRIS) == hull_tris,
		"blind: the SAME test calls every triangle of the REVERSED mesh wrong",
		"%d/%d" % [_wound(flipped, QuadRaptorBody.PIECE_TRIS), hull_tris])

## How many triangles of `mesh` point the WRONG way, testing each convex
## piece of `per` triangles against ITS OWN centre. Godot takes clockwise
## on screen for the front face, so the right-hand normal of a visible
## face points INTO the solid: a correct triangle has cross . (centroid -
## piece centre) NEGATIVE.
func _wound(mesh: ArrayMesh, per: int) -> int:
	var faces: PackedVector3Array = mesh.get_faces()
	var tris: int = faces.size() / 3
	var bad: int = 0
	var piece: int = 0
	while piece * per < tris:
		var lo: int = piece * per
		var hi: int = mini(lo + per, tris)
		var centre := Vector3.ZERO
		for t in range(lo, hi):
			centre += (faces[t * 3] + faces[t * 3 + 1] + faces[t * 3 + 2]) / 3.0
		centre /= float(hi - lo)
		for t in range(lo, hi):
			var a: Vector3 = faces[t * 3]
			var b: Vector3 = faces[t * 3 + 1]
			var c: Vector3 = faces[t * 3 + 2]
			var n: Vector3 = (b - a).cross(c - a)
			if n.dot((a + b + c) / 3.0 - centre) >= 0.0:
				bad += 1
		piece += 1
	return bad

# =====================================================================
# PHASE M -- the door, and EVERY tap below is a real screen coordinate
# pushed through HubTapInput._handle_point. CH58: a probe that drives a
# prop through its API measures the function, not the interaction, and
# the two never fail together.

func _phase_door() -> void:
	print("\nPHASE M -- the door, through the player's channel")
	await _park(Vector3(HubTransport.QUAD_PARK.x, 0.0, HubTransport.QUAD_PARK.z + 6.0))
	# BLIND, and it runs FIRST: an assertion of absence passes gratis.
	_check(_keepy.is_afoot(), "blind: he is afoot before the mount")
	_check(not _transport.is_driving_quad(), "blind: nobody is driving it")
	_check(_transport.vehicle_at(HubTransport.QUAD_PARK) == HubTransport.VEHICLE_QUAD,
		"the park names the QUAD and not some other vehicle",
		str(_transport.vehicle_at(HubTransport.QUAD_PARK)))
	_check(_transport.vehicle_position(HubTransport.VEHICLE_QUAD).distance_to(HubTransport.QUAD_PARK) < 0.01,
		"vehicle_position() has an explicit branch for it (CH76: a table with a default is wrong at the next member)")
	_check(is_equal_approx(_transport.vehicle_tap_radius(HubTransport.VEHICLE_QUAD), HubTransport.QUAD_TAP_RADIUS),
		"and so does vehicle_tap_radius()")
	var screen: Vector2 = _to_screen(_quad.global_position + Vector3(0.0, 0.4, 0.0))
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	_check(container.get_global_rect().has_point(screen),
		"the parked mount projects INSIDE the container, so the tap is dispatchable", str(screen))
	_tap._handle_point(screen)
	await _settle(600)
	await _frames(4)
	# ---- the five-way invariant, the kart's own.
	_check(_transport.is_driving_quad(), "the walk put him aboard, driving")
	_check(_keepy.is_on_carrier(), "he is ON_CARRIER (no second flag to keep in step)")
	_check(not _keepy.is_afoot(), "is_afoot() is FALSE while mounted -- the same switch a kart throws")
	_check(_transport.touch.enabled, "the writer is on")
	_check(_camera.is_driving(), "the chase camera has the frame")
	_check(_hud != null and _hud.visible and _hud.vehicle_mode(), "the HUD is up, in vehicle mode")
	_check(not _hub._world_hud.visible, "the world HUD stepped aside")
	_check(absf(_keepy.global_position.y - (_quad.global_position.y + QuadRaptorBody.SEAT_Y)) < 0.02,
		"he stands on the saddle (QuadRaptorBody.SEAT_Y)",
		"%.3f vs %.3f" % [_keepy.global_position.y, _quad.global_position.y + QuadRaptorBody.SEAT_Y])
	_check(_transport.vehicle_at(_quad.flat_position()) != HubTransport.VEHICLE_QUAD,
		"it WITHDRAWS from the tap while driven (the boat's pattern)")
	# ---- mutual exclusion: no second vehicle may be mounted underneath it.
	_check(not _transport.mount_sled() and not _transport.mount_yacht() and not _transport.mount_sailboat(),
		"no other vehicle can be mounted while it is driven")
	_check(_transport.is_driving_quad() and not _transport.is_driving_sled(),
		"and the refusal left the mount's own state alone")

## ⚠️ IT WAITS FOR THE CAMERA AND NOT FOR A FRAME COUNT, and the first
## version of this probe did not: `exit_drive()` TWEENS the blend and
## clears `_drive_target` only when the tween finishes, so for
## HubCamera.DRIVE_BLEND_S after the button `is_driving()` is still true
## -- and `_orbit_licensed` therefore still answers false. Two assertions
## of PHASE G came back RED on perfectly sound code because the bench was
## measuring the blend it had not waited for (CH73's own lesson: an
## assertion taken before convergence ends measures the convergence).
func _phase_exit() -> void:
	_transport.exit_quad()
	await _settle(600)
	for i in 240:
		await get_tree().process_frame
		if not _camera.is_driving():
			break

# =====================================================================
# PHASE G -- THE TWO CONTINUOUS GESTURES, SEPARATED BY MODE.
#
# This is the phase the brief asked for by name. A finger held and dragged
# means "steer the mount" while driving and "turn the camera" on foot, and
# the two must never both happen. Both directions are measured, because an
# absence assertion alone passes gratis against a mechanism that was never
# wired -- so the POSITIVE (the orbit DOES move on foot) runs first.

func _phase_gesture() -> void:
	print("\nPHASE G -- driving the mount vs orbiting the camera")
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	var mid: Vector2 = container.get_global_rect().get_center()
	# --- still mounted from PHASE M. The NEGATIVE first would be free, so
	#     take the POSITIVE reference first: step off and prove the orbit
	#     answers a drag at all.
	await _phase_exit()
	_check(_keepy.is_afoot(), "back afoot after the HUD button")
	_check(not _camera.is_driving(), "the chase camera gave the frame back")
	var yaw0: float = _camera.orbit_yaw()
	await _drag_gesture(mid, mid + Vector2(160.0, 0.0))
	var afoot_delta: float = absf(_camera.orbit_yaw() - yaw0)
	_check(afoot_delta > 0.05,
		"POSITIVE: on foot, a held drag turns the camera", "%.5f rad" % afoot_delta)
	# --- now mount again and repeat the IDENTICAL gesture.
	var before_yaw: float = _camera.orbit_yaw()
	var before_pitch: float = _camera.orbit_pitch()
	var screen: Vector2 = _to_screen(_quad.global_position + Vector3(0.0, 0.4, 0.0))
	if not container.get_global_rect().has_point(screen):
		await _park(Vector3(_quad.flat_position().x, 0.0, _quad.flat_position().z + 6.0))
		screen = _to_screen(_quad.global_position + Vector3(0.0, 0.4, 0.0))
	_tap._handle_point(screen)
	await _settle(600)
	await _frames(4)
	_check(_transport.is_driving_quad(), "mounted again for the negative half")
	var steer_seen: float = 0.0
	await _drag_gesture(mid, mid + Vector2(160.0, 0.0), true)
	steer_seen = absf(_transport.touch.input.steer)
	var driving_delta: float = maxf(absf(_camera.orbit_yaw() - before_yaw),
		absf(_camera.orbit_pitch() - before_pitch))
	_check(driving_delta < 1e-6,
		"NEGATIVE: the SAME drag, while driving, moves the orbit by nothing at all",
		"%.9f rad" % driving_delta)
	_check(steer_seen > 0.05,
		"and it reached the vehicle's writer instead -- one finger, one meaning",
		"steer %.3f" % steer_seen)
	# The shunt is a PROPERTY OF THE MODE, so name it: HubTapInput returns
	# before anything else while the mount is driven.
	_check(_transport.is_driving_quad(),
		"the shunt's own condition is live (transport.is_driving_quad())")
	# And a tap on the ground while driving is not a destination either.
	var here: Vector3 = _flat(_keepy.global_position)
	_tap._handle_point(container.get_global_rect().get_center())
	await _frames(6)
	_check(_flat(_keepy.global_position).distance_to(here) < 3.0 or _transport.is_driving_quad(),
		"a ground tap while driving does not hand the body a destination")
	_transport.touch.input.reset()

## Press, drag in steps, release -- through Input.parse_input_event, so
## the real nodes see the real event classes in the real order.
func _drag_gesture(from: Vector2, to: Vector2, hold: bool = false) -> void:
	Input.parse_input_event(_press(from))
	await get_tree().process_frame
	for k in 8:
		var at: Vector2 = from.lerp(to, float(k + 1) / 8.0)
		Input.parse_input_event(_drag(at))
		await get_tree().process_frame
	if hold:
		# Leave the finger down: for the mount, a held finger IS the input,
		# and releasing it would erase the steer before it could be read.
		return
	Input.parse_input_event(_release(to))
	await get_tree().process_frame

# =====================================================================
# PHASE D -- the drive, as a PROFILE and not a top speed (CH54: "une
# vitesse n'est pas une conduite").

## How far the mount could travel from `at` along `yaw` before the
## drivable set ends. PUBLISHED and used to CAP the run, because a bench
## whose course does not fit in the region does not measure a slow
## vehicle -- it measures a vehicle held against a wall, and every
## reading it then takes (cruise, coast, gait, steering) is a reading of
## the wall. The first run of this probe did exactly that and returned
## SIX reds on a sound vehicle: a "cruise" of 0.906 u/s taken 47 u
## downrange, with the steering gain at 3.8 deg/s because VehicleDrive
## scales yaw by v_fwd and a wall is precisely what eats v_fwd.
func _room_ahead(at: Vector3, yaw: float) -> float:
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var t: float = 0.0
	while t < 80.0:
		if not QuadRaptorBody.drivable(at + fwd * (t + 0.5)):
			return t
		t += 0.5
	return 80.0

func _phase_drive() -> void:
	print("\nPHASE D -- the drive profile")
	if _transport.is_driving_quad():
		await _phase_exit()
	await _park(OPEN + Vector3(0.0, 0.0, 3.0))
	_quad.place(OPEN, 0.0)
	await _frames(2)
	var mounted: bool = _transport.mount_quad()
	_check(mounted, "mounted at the open-plateau station for the measurement")
	await _frames(int(HubKarting.MOUNT_HOLD_S * 60.0) + 10)
	# The window is sized off the ground, not chosen.
	var room: float = _room_ahead(_quad.flat_position(), _quad.rotation.y)
	var window: int = int(clampf(room * 0.55 / QuadRaptorBody.MAX_SPEED_FLAT, 0.5, 4.0) * 60.0)
	print("   room ahead %.1f u -> measurement window %d frames (%.2f s)" % [room, window, window / 60.0])
	_check(room > 20.0, "the station has room for a real run", "%.1f u" % room)
	var start: Vector3 = _quad.flat_position()
	var samples: Array[float] = []
	var reached: int = -1
	var off: int = 0
	for f in window:
		_transport.touch.input.throttle = 1.0
		_transport.touch.input.steer = 0.0
		await get_tree().process_frame
		samples.append(_quad.speed())
		if not QuadRaptorBody.drivable(_quad.flat_position()):
			off += 1
		if reached < 0 and _quad.speed() >= QuadRaptorBody.MAX_SPEED_FLAT * 0.95:
			reached = f
	var travelled: float = _quad.flat_position().distance_to(start)
	var cruise: float = samples[samples.size() - 1]
	var left: float = _room_ahead(_quad.flat_position(), _quad.rotation.y)
	print("   first 5 frames: %.3f %.3f %.3f %.3f %.3f" % [samples[0], samples[1], samples[2], samples[3], samples[4]])
	print("   cruise %.3f u/s (authored %.3f), 95%% at frame %d, %.2f u travelled, %.1f u of room still ahead"
		% [cruise, QuadRaptorBody.MAX_SPEED_FLAT, reached, travelled, left])
	# ⚠️ THE WINDOW'S OWN VALIDITY IS GATED, not assumed. CH41's rule for
	# an A/B leg, applied to a single leg: a run that left the regime it
	# claims to measure is not a slow run, it is another measurement.
	_check(off == 0 and left > 4.0,
		"the whole window was spent on free ground, away from the wall",
		"%d frames off-surface, %.1f u of room left at the end" % [off, left])
	_check(samples[0] < samples[4] and samples[4] < samples[20],
		"the start RAMPS -- it is not a speed switched on", "%.3f -> %.3f -> %.3f" % [samples[0], samples[4], samples[20]])
	_check(reached > 0, "it reaches 95 %% of its authored cruise", "frame %d" % reached)
	_check(cruise <= QuadRaptorBody.MAX_SPEED_FLAT * 1.02,
		"and the authored cruise IS the ceiling on flat ground",
		"%.4f vs %.4f" % [cruise, QuadRaptorBody.MAX_SPEED_FLAT])
	_check(cruise > QuadRaptorBody.WALK_PACE * 1.5,
		"it is well past walking pace", "%.3f vs walk %.3f" % [cruise, QuadRaptorBody.WALK_PACE])
	print("   end to end: %.2f u in %.2f s = %.3f u/s average, against a walk at %.3f u/s"
		% [travelled, window / 60.0, travelled / (window / 60.0), QuadRaptorBody.WALK_PACE])
	# ---- the stop, measured to a REAL standstill.
	var before_stop: float = _quad.speed()
	var stop_frames: int = 0
	for f in 400:
		_transport.touch.input.throttle = 0.0
		await get_tree().process_frame
		stop_frames += 1
		if absf(_quad.speed()) < 0.05:
			break
	_check(before_stop > 5.0 and stop_frames > 6,
		"releasing the finger COASTS it down rather than stopping it dead",
		"%.2f u/s -> standstill in %d frames" % [before_stop, stop_frames])
	# ---- the gait, and it is driven by DISTANCE and not by time.
	var phase_still: float = _quad.gait_phase()
	for f in 30:
		_transport.touch.input.throttle = 0.0
		await get_tree().process_frame
	_check(absf(_quad.gait_phase() - phase_still) < 0.05,
		"standing still, the legs do not paddle (the gait runs on distance)",
		"%.5f rad in 30 frames" % absf(_quad.gait_phase() - phase_still))
	# Re-place with room ahead before asking it to move again.
	_quad.place(OPEN, 0.0)
	await _frames(2)
	var leg_before: float = _quad.leg_pitch(0)
	var moved_phase: float = _quad.gait_phase()
	for f in 60:
		_transport.touch.input.throttle = 1.0
		await get_tree().process_frame
	_check(_quad.gait_phase() - moved_phase > 1.0,
		"and moving, it advances", "%.3f rad" % (_quad.gait_phase() - moved_phase))
	_check(absf(_quad.leg_pitch(0) - leg_before) > 0.01,
		"read off the NODE, the leg actually turned (not just the variable meant to drive it)",
		"%.4f rad" % absf(_quad.leg_pitch(0) - leg_before))
	# ---- steering, measured on FREE ground for the reason above: the yaw
	# gain is proportional to v_fwd, so a bench that steers against a wall
	# measures the wall (CLAUDE.md: "un mur supprime la direction").
	_quad.place(OPEN, 0.0)
	await _frames(2)
	for f in 40:
		_transport.touch.input.throttle = 1.0
		_transport.touch.input.steer = 0.0
		await get_tree().process_frame
	var speed_at_steer: float = _quad.speed()
	var yaw_before: float = _quad.rotation.y
	var worst: float = 0.0
	var prev: float = yaw_before
	var steer_off: int = 0
	for f in 120:
		_transport.touch.input.throttle = 1.0
		_transport.touch.input.steer = 1.0
		await get_tree().process_frame
		worst = maxf(worst, absf(wrapf(_quad.rotation.y - prev, -PI, PI)) * 60.0)
		prev = _quad.rotation.y
		if not QuadRaptorBody.drivable(_quad.flat_position()):
			steer_off += 1
	var turned: float = absf(wrapf(_quad.rotation.y - yaw_before, -PI, PI))
	_check(steer_off == 0, "the steering run stayed on free ground too", "%d frames off" % steer_off)
	_check(turned > 0.5, "a held steer turns the heading",
		"%.3f rad in 2 s at %.2f u/s" % [turned, speed_at_steer])
	print("   worst yaw rate under full lock: %.1f deg/s (KartTuning preset x %.2f)"
		% [rad_to_deg(worst), QuadRaptorBody.STEER_RATIO])
	_transport.touch.input.steer = 0.0
	_transport.touch.input.throttle = 0.0

# =====================================================================
# PHASE W -- the wall. It bounds the mount and it does NOT lock it up:
# SandYacht._wall step 3 is a documented lock-up and the axis-separated
# slide is what avoids it.

func _phase_wall() -> void:
	print("\nPHASE W -- the wall")
	if not _transport.is_driving_quad():
		_check(false, "PHASE W needs the mount driven (instrument)")
		return
	# Drive at the plateau's east edge at a shallow angle, for 6 s.
	_quad.place(Vector3(28.0, 0.0, 10.0), deg_to_rad(70.0))
	await _frames(2)
	var outside: int = 0
	var start: Vector3 = _quad.flat_position()
	for f in 360:
		_transport.touch.input.throttle = 1.0
		_transport.touch.input.steer = 0.0
		await get_tree().process_frame
		if not QuadRaptorBody.drivable(_quad.flat_position()):
			outside += 1
	var slid: float = _quad.flat_position().distance_to(start)
	_check(outside == 0, "it never leaves the drivable set", "%d frames outside" % outside)
	_check(slid > 4.0,
		"and it SLID along the wall rather than locking up (the axis-separated slide)",
		"%.2f u travelled in 6 s against the edge" % slid)
	# BLIND: the test can see a body leaving. Put it somewhere it must not
	# be and assert the predicate says so, so "never outside" is not a
	# sentence about a predicate that always answers true.
	_check(not QuadRaptorBody.drivable(Vector3(0.0, 0.0, -160.0)),
		"blind: the drivable predicate DOES refuse -- it is not a constant true")
	_transport.touch.input.throttle = 0.0
	_transport.touch.input.steer = 0.0

# =====================================================================
# PHASE H -- the hill. The sled's published relation, restated for this
# vehicle: below it, a mount facing uphill sits at exactly 0.000 u/s with
# no steering and the player has to reload.

func _phase_hill() -> void:
	print("\nPHASE H -- it can leave a standstill facing uphill")
	var steepest: float = 0.0
	var at := Vector3.ZERO
	var bounds: Rect2 = HubRegion.walkable_bounds()
	var x: float = bounds.position.x
	while x <= bounds.end.x:
		var z: float = bounds.position.y
		while z <= bounds.end.y:
			var g: Vector2 = HubSurface.gradient_at(Vector3(x, 0.0, z))
			if g.length() > steepest:
				steepest = g.length()
				at = Vector3(x, 0.0, z)
			z += 1.0
		x += 1.0
	var push: float = QuadRaptorBody.slope_force(HubSurface.gradient_at(at))
	var pull: float = QuadRaptorBody.climb_authority()
	print("   steepest gradient on the surface: %.4f at %s" % [steepest, str(at)])
	print("   climb authority %.3f u/s2 vs slope force %.3f u/s2 (%.1f %% used)"
		% [pull, push, 100.0 * push / maxf(pull, 0.0001)])
	_check(pull > push, "the motor beats the steepest slope from rest")
	_check(QuadRaptorBody.reverse_authority() > push, "and so does the reverse gear")
	# ⚠️ THE GRADIENT IS REAL AND IT IS MEASURED, not assumed either way.
	# The first draft of this phase asserted the hub was flat -- it is
	# not: the west ridge registers a HubSurface domain and this sweep
	# reads 0.5280 on it, which is tan(27.834 deg), the same number
	# SledBody's GRADE_FOR_FULL_CAP docblock names. So the inequality
	# above is a real gate and not a free one.
	_check(steepest > 0.4,
		"the sweep found real relief to gate against (a flat surface would make the gate free)",
		"%.4f = tan %.3f deg" % [steepest, rad_to_deg(atan(steepest))])

# =====================================================================
# PHASE B -- what it costs. Same run, same bench, same station: afoot,
# then the mount, then the SLED. CH40/CH41: a delta without its bench's
# own noise floor is not a measurement.
#
# ⚠️ THE KART IS NOT IN THIS TABLE, AND THAT IS A RESULT AND NOT AN
# OMISSION. The brief asks for a comparison with the karting "dans une
# zone equivalente"; the kart is confined to its circuit (zone 3), whose
# frame contains a track, a grid, four karts and a crowd of circuit decor
# that the plateau does not have. A reading taken there and one taken
# here would differ by the SCENE and not by the vehicle, which is the
# CLAUDE.md defect about measuring the wrong thing and reading it as a
# result. The sled is the equivalent-zone driven vehicle and it is the
# comparator.

func _phase_budget() -> void:
	print("\nPHASE B -- the budget")
	if _transport.is_driving_quad():
		await _phase_exit()
	await _park(OPEN)
	var floor_a: int = await _read_prims()
	var floor_b: int = await _read_prims()
	var noise: int = absi(floor_a - floor_b)
	print("   noise floor at this station: %d and %d primitives (spread %d)" % [floor_a, floor_b, noise])
	_check(noise >= 0, "the bench publishes its own noise floor before any delta is read")
	# --- afoot, the mount parked out of frame.
	_quad.place(Vector3(120.0, 0.0, 200.0), 0.0)
	await _frames(6)
	var afoot: int = await _read_prims()
	# --- the mount, in frame, driven.
	_quad.place(OPEN + Vector3(0.0, 0.0, -4.0), 0.0)
	await _frames(6)
	var parked: int = await _read_prims()
	var mounted: bool = _transport.mount_quad()
	_check(mounted, "mounted for the driven reading")
	await _frames(int(HubKarting.MOUNT_HOLD_S * 60.0) + 20)
	var driven: Array = await _read_driven()
	await _phase_exit()
	# --- the sled, the equivalent-zone comparator, same station.
	var sled: SledBody = _transport.sled()
	sled.place(OPEN + Vector3(0.0, 0.0, -4.0), 0.0)
	await _frames(6)
	var sled_mounted: bool = _transport.mount_sled()
	_check(sled_mounted, "mounted the SLED at the same station for the comparison")
	await _frames(int(HubKarting.MOUNT_HOLD_S * 60.0) + 20)
	var sled_driven: Array = await _read_driven()
	_transport.exit_sled()
	await _settle(600)
	sled.place(HubTransport.SLED_PARK, PI / 2.0)
	print("   ---------------------------------------------------------------")
	print("   afoot, mount out of frame ....... %6d primitives" % afoot)
	print("   afoot, mount parked in frame .... %6d primitives  (delta %+d)" % [parked, parked - afoot])
	print("   QUAD driven (chase camera) ...... %6d primitives, %.1f ms/frame" % [driven[0], driven[1]])
	print("   SLED driven (chase camera) ...... %6d primitives, %.1f ms/frame" % [sled_driven[0], sled_driven[1]])
	print("   ---------------------------------------------------------------")
	print("   ⚠️ the ms are a SANDBOX number (llvmpipe software rasteriser),")
	print("      not a phone frame time. Only the PRIMITIVE counts transfer.")
	_check(parked - afoot > noise,
		"the parked mount costs something a reader can see above the bench's own noise",
		"%+d primitives against a floor of %d" % [parked - afoot, noise])
	# ⚠️ A ZERO SPREAD IS NOT PROOF OF A STABLE INSTRUMENT (CH62: a stale
	# value repeats perfectly). What proves the wire is that the delta is
	# EXACTLY the mesh: the counter submitted the placeholder's own
	# triangles and nothing else.
	var tris: Array[int] = _quad.triangle_count()
	_check(parked - afoot == tris[0] + tris[1],
		"and the delta is EXACTLY the placeholder's triangle count -- the counter is wired to the mesh",
		"%+d vs %d published" % [parked - afoot, tris[0] + tris[1]])
	_check(absf(driven[0] - sled_driven[0]) < maxi(noise * 4, 4000),
		"driven, it costs what the equivalent-zone vehicle costs (same station, same camera)",
		"quad %d vs sled %d" % [driven[0], sled_driven[0]])

func _read_prims() -> int:
	await _frames(B_SETTLE)
	var total: int = 0
	for k in B_REPEATS:
		await _frames(B_GAP)
		total += RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	return int(total / B_REPEATS)

## Primitives and frame time while the vehicle is actually being driven --
## the camera MOVES between reads, which is what CH62 says a frozen-camera
## count cannot do.
func _read_driven() -> Array:
	var prims: int = 0
	var ms: float = 0.0
	var n: int = 0
	for f in 120:
		_transport.touch.input.throttle = 1.0
		await get_tree().process_frame
		if f >= 30 and f % 10 == 0:
			prims += RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
				RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
				RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			n += 1
	_transport.touch.input.throttle = 0.0
	return [int(prims / maxi(n, 1)), ms / float(maxi(n, 1))]
