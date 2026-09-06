extends Node3D
class_name HubTransport
## Carte-blanche v3 -- the transport network: balloon LINES (family A,
## fixed points) and the hoppity ball "Sautillon" (family B, free vehicle).
##
## =====================================================================
## FAMILY A -- ONE LINE = TWO DOCKS + ONE BALLOON
##
## A line is a pair of docks and a balloon that waits at one of them. A tap
## on the dock where it waits boards it and flies to the twin dock; a tap
## on the EMPTY dock CALLS it (it flies over empty, lands, and takes the
## waiting Keepy back). Both docks WITHDRAW from the tap for the whole of a
## trip (the boat pattern, through this node rather than a flag), so a tap
## made meanwhile falls through to the ground path and is dropped there by
## state -- legitimate only because a trip is BOUNDED by a tween that
## always ends on a dock (the zipline's licence, RECON 1).
##
## The balloon is also RE-MOORED on the boat's rule: when Keepy is far from
## both docks and neither is on screen, it is moved to the nearer one with
## no animation, so a player arriving at a dock usually finds it there.
##
## Every fact below is authored ONCE (docks in LINES, the ball's park in
## BALL_PARK) and read by HubTapInput, HubWorld and CozyScatter through the
## accessors -- never retyped.
##
## =====================================================================
## FAMILY B -- THE BALL IS A HOP MODIFIER, NOT A RIDE
##
## Tap the parked ball: Keepy walks to it and climbs on. From then on every
## ordinary tap-to-move hop is longer and higher (KeepyHopper's vehicle
## modifier); no new control. Any prop interaction drops the ball where he
## stood; a tap on himself while standing still drops it too. The ball is
## re-parked on the same off-screen rule as the balloons.

## Where a line's balloon is drawn from and what colour its pennants take.
## Dock positions are on the ground plane; both must be inside HubRegion.
## The FIRST dock is where the balloon starts.
const LINES: Array = [
	{"name": "or", "glb": "balloon_0", "colour": Color(0.98, 0.76, 0.22),
		"docks": [Vector3(10.5, 0.0, 14.5), Vector3(11.0, 0.0, -55.0)]},
	# v3 P2: the sky line, from the west of the Mother Tree clearing to the
	# moor's western fields -- the second leg of the chain, so a rider who
	# arrives on the gold balloon sees the blue one 25 u across the clearing.
	{"name": "ciel", "glb": "balloon_1", "colour": Color(0.40, 0.70, 0.96),
		"docks": [Vector3(-14.0, 0.0, -50.0), Vector3(-6.0, 0.0, -110.0)]},
	# CH29: the coral line, DIRECT from the plateau to the cove -- the
	# longest walk on the map (spawn -> fifth zone, four gates) is the one
	# a line has to close, and a chain of three flights would not. The
	# plateau dock stands on the plateau's SOUTH edge, IN THE SPAWN FRAME
	# (the only side the camera ever shows): CoveRecon scanned the whole
	# plateau on a 1 u grid for ground that is region, dry, off every path
	# and clear of every footprint -- behind the spawn, where the gold dock
	# is, nothing clears more than 1.7 u; (-13, -33) clears 2.90 u and is
	# framed from the plaza. The cove dock is by the corridor mouth so a
	# rider steps off with the lighthouse framed ahead (same recon).
	{"name": "corail", "glb": "balloon_2", "colour": Color(0.96, 0.52, 0.70),
		"docks": [Vector3(-13.0, 0.0, -33.0), Vector3(52.0, 0.0, -98.0)]},
]

## Where the hoppity ball is parked on the plateau: just south of the
## spawn plaza, between the cabin path and the dock path. MEASURED against
## the camera, not chosen for clearance alone: at Keepy's own z the frame
## is only ~7 u wide (half-fov 22.5 deg at 8.9 u), so the first candidate
## (-6.5, 0.5) -- 2.2 u of clearance, left of the owl -- was simply not in
## the spawn frame. z = 5.2 is inside the bottom edge (ground visible to
## z ~ 6.2) and x = 0.5 is centred, so the ball is the first thing behind
## Keepy on the first frame.
const BALL_PARK: Vector3 = Vector3(0.5, 0.0, 4.4)

## CH29 -- FAMILY B, SECOND VEHICLE: the sand yacht ("char a voile"), the
## cove's own. Same door as the ball (tap it, walk, climb on).
##
## =====================================================================
## CH30 -- IT IS NOW DRIVEN, NOT HOPPED
##
## CH29 made it a hop modifier: each tap on the ground was one flat glide.
## Mathieu's retour is that it must be driven like the kart -- a finger
## held down, direction under the thumb. It is: the yacht is a SandYacht
## node driven by the SAME KartTouchInput writing the SAME KartInput into
## the SAME VehicleDrive the kart uses, watched by the SAME chase camera,
## and the rider is carried by mount_carrier() exactly as he is in the
## kart. Nothing here is a second copy of anything there; this file is the
## COORDINATOR (mount, drive, exit), the way HubKarting is the kart's.
##
## The yacht's own numbers -- pace, grip, heel, and the one place it may
## not go -- live in SandYacht.gd. This file owns the door and the mode.
##
## It is NOT re-parked by the off-screen rule. Where the player leaves it
## is where it stays, across sessions (WorldSave.cove_yacht): a vehicle
## whose point is to cross the map must not walk home on its own.
##
const VEHICLE_BALL: int = 0
const VEHICLE_YACHT: int = 1
const YACHT_PARK: Vector3 = Vector3(48.0, 0.0, -112.0)
## Deck top of yacht_hull_0 (the box at y 0.35..0.65 plus its cushion): his
## feet stand there. CH30: authored ONCE, in SandYacht, and republished
## here for every reader that predates the move.
const YACHT_SEAT_Y: float = SandYacht.SEAT_Y
const YACHT_TAP_RADIUS: float = 1.8
## Where the driver steps off, and how long the accelerator waits for the
## camera blend. Both are the kart's numbers (HubKarting.EXIT_SIDE,
## MOUNT_HOLD_S): the two vehicles are boarded and left the same way, and
## a second pair of literals would be two numbers to keep in step.
const EXIT_SIDE: float = 1.8
const MOUNT_HOLD_S: float = 1.2
const YACHT_FOOTPRINT: float = 2.0
## CH29's glide geometry, kept as the AUTHORED PACE of the drive: 3.2 u
## per 0.30 s is 10.7 u/s in the sun (x2.0 on foot, x1.35 the ball), and
## SandYacht.BASE_SPEED is that same number, so CH30 changed how the
## vehicle is controlled and not how fast it crosses the map. The wind
## still scales it, capped so a storm run (13.3 u/s) stays at the
## balloon's proven 13 u/s under this camera.
const YACHT_GLIDE_DISTANCE: float = 3.2
const YACHT_GLIDE_S: float = 0.30
const YACHT_WIND_MIN: float = 0.85
const YACHT_WIND_MAX: float = 1.25

const DECK_TOP: float = 0.16
## Ground radius the scatter keeps clear around a dock (deck 1.9 + step
## 0.38 + a margin to walk round it).
const DOCK_FOOTPRINT: float = 2.9
## Tap disc: a little past the step, on the boat's "generous on purpose"
## reasoning -- the deck is drawn small and the ground round it is nobody
## else's target.
const DOCK_TAP_RADIUS: float = 2.6
const BALL_TAP_RADIUS: float = 1.5
const BALL_FOOTPRINT: float = 1.4
## Top of the ball, where his feet stand (hopball_0: sphere r 0.62 squashed
## 0.94 -> 1.166 high; the feet sink 0.15 into the top).
const BALL_LIFT: float = 1.02
## Seat in the basket: on its floor.
const SEAT: Vector3 = Vector3(0.0, 0.05, 0.0)

## 4.0 and not higher, MEASURED on a mid-flight capture: the camera never
## tilts, so at Keepy's own xz nothing above y ~ 8 is in frame (top ray at
## +2.4 deg over 8.9 u from a 7.6 u camera). At 5.2 the whole envelope was
## cut off and the shot read as a basket on a rope; at 4.0 the basket, the
## skirt and the lower half of the envelope stay in frame while still
## clearing every canopy on the line (layout trees at 0.8x top out ~4.5 u,
## the hedge and the autumn trees ~5 u -- the basket floor is at 4.16).
const CRUISE_HEIGHT: float = 4.0
const FLIGHT_SPEED: float = 13.0
## Seconds added to a trip for the rise and the descent.
const FLIGHT_PAD_S: float = 2.4
const REMOOR_MIN_DISTANCE: float = 14.0

## Emitted when a trip ends at `dock` of `line`; `empty` when nobody rode.
signal trip_finished(line: int, dock: int, empty: bool)

var _lines: Array[Dictionary] = []
var _ball: Node3D = null
var _yacht: SandYacht = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _weather: Node = null
var _time: float = 0.0
## CH30 -- the drive mode. `touch` is this vehicle's writer, the same
## class the kart uses; `_driving` is the one flag, and every other fact
## (the rider is ON_CARRIER, the camera is chasing, the HUD is up) is
## turned on and off with it in the same two functions.
var touch: KartTouchInput = null
var _hud: KartHud = null
var _driving: bool = false

signal yacht_driving_changed(driving: bool)

func _ready() -> void:
	for i in LINES.size():
		_build_line(i)
	_build_ball()
	_build_yacht()
	touch = KartTouchInput.new()
	touch.name = "YachtTouch"
	add_child(touch)

## Handed the nodes this needs, once, by HubWorld. `hud` is the kart's
## HUD in its vehicle mode (one exit button and the steering ghost): a
## second HUD would be a second copy of the same two widgets.
func setup(keepy: Node3D, camera: Camera3D, weather: Node, hud: KartHud = null) -> void:
	_keepy = keepy
	_camera = camera
	_weather = weather
	_hud = hud
	if _hud != null:
		_hud.exit_pressed.connect(exit_yacht)
	if _keepy.has_signal("vehicle_dismounted"):
		_keepy.connect("vehicle_dismounted", _on_vehicle_dismounted)
	if _keepy.has_signal("vehicle_mounted"):
		_keepy.connect("vehicle_mounted", _on_vehicle_mounted)

## ---- building --------------------------------------------------------

func _glb_node(name: String, mesh_name: String, material: Material) -> MeshInstance3D:
	var mesh: Mesh = CozyPalette.glb_mesh(CozyPalette.decor_path(mesh_name))
	var node := MeshInstance3D.new()
	node.name = name
	if mesh == null:
		push_error("HubTransport: %s.glb missing" % mesh_name)
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _build_line(index: int) -> void:
	var spec: Dictionary = LINES[index]
	var docks: Array = spec["docks"]
	var colour: Color = spec["colour"]
	var entry := {"docks": [], "balloon": null, "at": 0, "riding": false, "tween": null, "phase": float(index) * 1.7,
		"from": 0, "to": 1, "rider": false, "sign_dir": []}
	for d in docks.size():
		var here: Vector3 = docks[d]
		var twin: Vector3 = docks[1 - d]
		var toward := Vector3(twin.x - here.x, 0.0, twin.z - here.z).normalized()
		entry["docks"].append(Vector3(here.x, 0.0, here.z))
		var dock := _glb_node("Dock_%d_%d" % [index, d], "dock_0", CozyPalette.decor_material())
		dock.position = Vector3(here.x, 0.0, here.z)
		dock.rotation.y = float(d) * 1.1 + float(index) * 0.4
		add_child(dock)
		# The arrow sign stands just outside the deck on the side of the
		# twin dock and points AT it -- the only "where does this go" the
		# network offers, and it is geometry rather than UI.
		var sign := _glb_node("Sign_%d_%d" % [index, d], "docksign_0", CozyPalette.decor_material())
		# BESIDE the deck, not in front of it: from this camera a sign placed
		# on the twin's side is behind the balloon and never seen (capture
		# p1_dock). The arrow still points at the twin.
		var side := Vector3(-toward.z, 0.0, toward.x)
		sign.position = Vector3(here.x, 0.0, here.z) + side * 2.75 + toward * 0.4
		sign.rotation.y = atan2(toward.x, toward.z)
		add_child(sign)
		# Pennant in the line's colour, hung from the sign post.
		var flag := MeshInstance3D.new()
		flag.name = "Flag_%d_%d" % [index, d]
		var box := BoxMesh.new()
		box.size = Vector3(0.04, 0.46, 0.62)
		flag.mesh = box
		flag.material_override = CozyPalette.decor_material_tinted(colour)
		flag.position = sign.position + Vector3(0.0, 1.55, 0.0) + toward * (-0.34)
		flag.rotation.y = sign.rotation.y
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(flag)
	var balloon := _glb_node("Balloon_%d" % index, spec["glb"], CozyPalette.decor_material())
	add_child(balloon)
	entry["balloon"] = balloon
	_lines.append(entry)
	_park(index, 0)

func _build_ball() -> void:
	_ball = _glb_node("HopBall", "hopball_0", CozyPalette.decor_material())
	_ball.position = BALL_PARK
	add_child(_ball)

## CH30: a SandYacht node -- the hull and the sail on a heeling deck, and
## the driving model with them. The GLB lookups stay here (this file owns
## the palette calls); the vehicle owns what it does with them.
func _build_yacht() -> void:
	_yacht = SandYacht.new()
	_yacht.name = "Yacht"
	add_child(_yacht)
	_yacht.build(
		CozyPalette.glb_mesh(CozyPalette.decor_path("yacht_hull_0")), CozyPalette.decor_material(),
		CozyPalette.glb_mesh(CozyPalette.decor_path("yacht_sail_0")), CozyPalette.decor_material_wind(0.10, 2.6))
	var saved: Vector3 = WorldSave.cove_yacht()
	# ⚠️ `drivable`, not `contains`: a save written before CH30 can hold a
	# yacht parked ON THE KARTING GRID (Mathieu did exactly that), and the
	# refusal has to survive a reload or the guard would only cover the
	# session that added it.
	var at: Vector3 = saved if (saved != Vector3.INF and SandYacht.drivable(saved)) else YACHT_PARK
	# Nose toward the sea at the park; a saved yacht keeps only its place,
	# the yaw is rewritten by the first drive anyway.
	_yacht.place(Vector3(at.x, 0.0, at.z), PI / 2.0)

## ---- what the scatter and the tap need -----------------------------

## Ground discs nothing should be sown in: every dock and the ball's park.
static func footprints() -> Array:
	var out: Array = []
	for spec in LINES:
		for d in spec["docks"]:
			out.append({"position": Vector3(d.x, 0.0, d.z), "radius": DOCK_FOOTPRINT})
	out.append({"position": BALL_PARK, "radius": BALL_FOOTPRINT})
	out.append({"position": YACHT_PARK, "radius": YACHT_FOOTPRINT})
	return out

## Every dock, flat, for the path builder.
static func dock_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for spec in LINES:
		for d in spec["docks"]:
			out.append(Vector3(d.x, 0.0, d.z))
	return out

func line_count() -> int:
	return _lines.size()

func dock_position(line: int, dock: int) -> Vector3:
	return _lines[line]["docks"][dock]

func balloon(line: int) -> Node3D:
	return _lines[line]["balloon"]

## Which dock the balloon of `line` is waiting at, or -1 in flight.
func balloon_at(line: int) -> int:
	return -1 if _lines[line]["riding"] else int(_lines[line]["at"])

func is_line_idle(line: int) -> bool:
	return not _lines[line]["riding"]

func nearest_dock(line: int, point: Vector3) -> int:
	var flat := Vector3(point.x, 0.0, point.z)
	var docks: Array = _lines[line]["docks"]
	var best := 0
	var best_d := INF
	for d in docks.size():
		var dist: float = flat.distance_to(docks[d])
		if dist < best_d:
			best_d = dist
			best = d
	return best

## The line whose dock `point` is on, or -1. FALSE FOR THE WHOLE OF A TRIP
## AT BOTH DOCKS -- the withdrawal, asked before either dock is looked at.
func accepts_balloon_tap(point: Vector3) -> int:
	var flat := Vector3(point.x, 0.0, point.z)
	for i in _lines.size():
		if _lines[i]["riding"]:
			continue
		for dock in _lines[i]["docks"]:
			if flat.distance_to(dock) <= DOCK_TAP_RADIUS:
				return i
	return -1

func ball_node() -> Node3D:
	return _ball

func ball_position() -> Vector3:
	return Vector3(_ball.global_position.x, 0.0, _ball.global_position.z)

## True when the tap means "climb on a vehicle" (the ball or, CH29, the
## yacht): the point is on one he is not already riding. The ridden one
## withdraws, so a tap on it is an ordinary hop -- which is the whole idea.
func accepts_vehicle_tap(point: Vector3) -> bool:
	return vehicle_at(point) >= 0

## CH29: WHICH vehicle a tap at `point` means -- VEHICLE_BALL, VEHICLE_YACHT
## or -1 -- on accepts_vehicle_tap's exact terms. The ball is asked first
## (it is the older channel); the two parks are 120 u apart so the order
## can only ever decide when the player dropped one on the other.
func vehicle_at(point: Vector3) -> int:
	# Only the vehicle he RIDES withdraws: a tap on the other one while
	# mounted means "swap" (HubWorld drops the first where he stands), so a
	# player who bounced up to the yacht on the ball is not asked to step
	# off first. Nobody mounted: both answer.
	var riding: Node3D = null
	if _keepy != null and _keepy.has_method("vehicle_node"):
		riding = _keepy.call("vehicle_node")
	var flat := Vector3(point.x, 0.0, point.z)
	if riding != _ball and flat.distance_to(ball_position()) <= BALL_TAP_RADIUS:
		return VEHICLE_BALL
	# CH30: the yacht WITHDRAWS from the tap for the length of a drive
	# (the boat's pattern, the kart's `accepts_tap`), so a tap made while
	# driving falls through to the ground path and is refused there by
	# ON_CARRIER -- never swallowed by the thing being driven.
	if _yacht != null and not _driving and flat.distance_to(yacht_position()) <= YACHT_TAP_RADIUS:
		return VEHICLE_YACHT
	return -1

func yacht_node() -> Node3D:
	return _yacht

func yacht() -> SandYacht:
	return _yacht

func yacht_position() -> Vector3:
	return _yacht.flat_position()

func is_driving_yacht() -> bool:
	return _driving

func vehicle_position(kind: int) -> Vector3:
	return yacht_position() if kind == VEHICLE_YACHT else ball_position()

func vehicle_tap_radius(kind: int) -> float:
	return YACHT_TAP_RADIUS if kind == VEHICLE_YACHT else BALL_TAP_RADIUS

## The wind's multiplier on the yacht's pace: 0.85 in snow, 1.0 in the
## sun, 1.12 in rain, 1.25 (the cap) in a storm. Read by _process and
## pushed into KeepyHopper every frame he rides.
func yacht_speed_factor() -> float:
	return clampf(0.85 + 0.15 * _wind(), YACHT_WIND_MIN, YACHT_WIND_MAX)

func _on_vehicle_mounted() -> void:
	pass

## CH29's hook, kept for the BALL: dropping a vehicle no longer touches
## the yacht's save (CH30 writes it in exit_yacht, where stepping off the
## yacht actually happens).
func _on_vehicle_dismounted() -> void:
	pass

## ---- CH30: the drive mode ----------------------------------------------
## The kart's shape exactly (HubKarting._mount / exit_kart), and the
## invariant it is gated on is the same one: driving == the rider is
## ON_CARRIER on THIS deck == touch.enabled == the camera is chasing ==
## the HUD is up. One function turns them all on, one turns them all off.

## Climbs aboard. Refused unless he is standing still, and refused if the
## yacht somehow sits where it may not drive (a defence in depth over the
## build-time refusal: a yacht there could not be driven off it).
func mount_yacht() -> bool:
	if _driving or _keepy == null or _yacht == null:
		return false
	if not SandYacht.drivable(yacht_position()):
		_yacht.place(YACHT_PARK, PI / 2.0)
		return false
	if not _keepy.call("mount_carrier", _yacht.deck(), SandYacht.SEAT):
		return false
	_driving = true
	_yacht.velocity = Vector3.ZERO
	touch.enabled = true
	# The accelerator waits for the camera blend, exactly as the kart's
	# does, so the yacht does not leave under a camera still swinging.
	touch.hold_throttle(MOUNT_HOLD_S)
	_keepy.call("follow_carrier")
	if _camera != null and _camera.has_method("enter_drive"):
		_camera.call("enter_drive", _yacht)
	if _hud != null:
		_hud.set_vehicle_mode(true)
		_hud.visible = true
	WorldSave.note("yacht_rides")
	yacht_driving_changed.emit(true)
	return true

## The HUD button. Stops the yacht where it is, gives the body back to a
## point BESIDE it clamped to ground it could itself have driven on, and
## re-opens it to the tap.
func exit_yacht() -> void:
	if not _driving:
		return
	touch.enabled = false
	touch.input.reset()
	_yacht.velocity = Vector3.ZERO
	_driving = false
	if _camera != null and _camera.has_method("exit_drive"):
		_camera.call("exit_drive")
	if _hud != null:
		_hud.visible = false
		_hud.set_ghost(Vector2.ZERO, Vector2.ZERO, false)
		_hud.set_vehicle_mode(false)
	var at: Vector3 = yacht_position()
	var landing: Vector3 = _step_off(at + _yacht.right() * EXIT_SIDE)
	if landing.distance_to(at) < 0.8:
		landing = _step_off(at - _yacht.right() * EXIT_SIDE)
	_keepy.call("leave_carrier", landing)
	# Where he steps off is where the yacht will be next session.
	WorldSave.cove_set_yacht(at)
	yacht_driving_changed.emit(false)

## A landing point for the step-off: the region's own clamp, refused back
## to the yacht's own position if it lands where the yacht may not be
## (the corridor mouths are the only place that can happen).
func _step_off(wanted: Vector3) -> Vector3:
	var landing: Vector3 = HubRegion.clamp_to(wanted)
	return landing if HubRegion.contains(landing) else yacht_position()

## ---- flying -----------------------------------------------------------

func _park(line: int, dock: int) -> void:
	var entry: Dictionary = _lines[line]
	var balloon: Node3D = entry["balloon"]
	var at: Vector3 = entry["docks"][dock]
	balloon.global_position = Vector3(at.x, DECK_TOP, at.z)
	var twin: Vector3 = entry["docks"][1 - dock]
	balloon.rotation.y = atan2(twin.x - at.x, twin.z - at.z)
	entry["at"] = dock
	entry["riding"] = false

## Starts a trip from `from_dock` to the other dock. `rider` says whether
## Keepy is aboard (HubWorld has already mounted him). Refused while a
## trip runs.
func depart(line: int, from_dock: int, rider: bool) -> bool:
	var entry: Dictionary = _lines[line]
	if entry["riding"]:
		return false
	var a: Vector3 = entry["docks"][from_dock]
	var b: Vector3 = entry["docks"][1 - from_dock]
	var seconds: float = a.distance_to(b) / FLIGHT_SPEED + FLIGHT_PAD_S
	entry["riding"] = true
	entry["from"] = from_dock
	entry["to"] = 1 - from_dock
	entry["rider"] = rider
	entry["at"] = -1
	var balloon: Node3D = entry["balloon"]
	var tween := balloon.create_tween()
	tween.tween_method(_apply_flight.bind(line), 0.0, 1.0, seconds)
	tween.finished.connect(_on_trip_finished.bind(line), CONNECT_ONE_SHOT)
	entry["tween"] = tween
	return true

## The flight pose at `t`, and -- in the SAME call, immediately after --
## the rider. Horizontal: cosine ease between the docks. Vertical: a
## plateau reached over the first ~20 % and left over the last ~20 %, so
## it lifts off, cruises, and settles. Sway: a lateral sine scaled by the
## weather's wind (a balloon in a storm is not a balloon in the sun).
func _apply_flight(t: float, line: int) -> void:
	var entry: Dictionary = _lines[line]
	var balloon: Node3D = entry["balloon"]
	if balloon == null or not is_instance_valid(balloon):
		return
	var a: Vector3 = entry["docks"][entry["from"]]
	var b: Vector3 = entry["docks"][entry["to"]]
	var p: float = 0.5 - 0.5 * cos(PI * t)
	var ground: Vector3 = a.lerp(b, p)
	var lift: float = CRUISE_HEIGHT * clampf(sin(PI * t) * 1.45, 0.0, 1.0)
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var wind: float = _wind()
	var sway: float = sin(t * 11.0 + entry["phase"]) * (0.18 + 0.22 * wind) * (lift / CRUISE_HEIGHT)
	balloon.global_position = Vector3(ground.x, DECK_TOP + lift, ground.z) + side * sway
	balloon.rotation.y = atan2(dir.x, dir.z) + deg_to_rad(5.0 * wind) * sin(t * 7.0 + entry["phase"])
	balloon.rotation.z = deg_to_rad(3.0 * wind) * sin(t * 11.0 + entry["phase"]) * (lift / CRUISE_HEIGHT)
	if entry["rider"] and _keepy != null and _keepy.has_method("is_on_carrier") and _keepy.call("is_on_carrier"):
		_keepy.call("follow_carrier")

func _on_trip_finished(line: int) -> void:
	var entry: Dictionary = _lines[line]
	var dock: int = entry["to"]
	var was_empty: bool = not entry["rider"]
	entry["tween"] = null
	# Put it EXACTLY on the deck rather than wherever the last step wrote it
	# (the owl's reasoning: a cut tween still leaves a parked balloon).
	_park(line, dock)
	var balloon: Node3D = entry["balloon"]
	balloon.rotation.z = 0.0
	if not was_empty and _keepy != null and _keepy.call("is_on_carrier"):
		_keepy.call("follow_carrier")
	trip_finished.emit(line, dock, was_empty)

func _wind() -> float:
	if _weather != null and _weather.has_method("current_look"):
		var look: Dictionary = _weather.call("current_look")
		return float(look.get("wind", 1.0))
	return 1.0

## ---- per frame --------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	var wind: float = _wind()
	# CH29: the sail leans with the wind and flutters; the rider's pace
	# follows the same number, pushed into the hopper here so that the
	# glide and the cloth answer to ONE reading of the weather.
	if _yacht != null:
		_yacht.breathe(wind, _time)
	for i in _lines.size():
		var entry: Dictionary = _lines[i]
		if entry["riding"]:
			continue
		var balloon: Node3D = entry["balloon"]
		var at: Vector3 = entry["docks"][entry["at"]]
		var phase: float = entry["phase"]
		# Parked: a slow bob and a lean into the wind, so the dock reads as
		# alive from across the plateau.
		balloon.global_position = Vector3(at.x, DECK_TOP + 0.06 * sin(_time * 1.1 + phase) * (0.5 + 0.5 * wind), at.z)
		balloon.rotation.z = deg_to_rad(2.5 * wind) * sin(_time * 0.9 + phase)
		if entry["rider"] and _keepy != null and _keepy.call("is_on_carrier"):
			_keepy.call("follow_carrier")

## CH30: the yacht's own physics step. Carrier first, carried immediately
## after in the SAME call -- the turnstile's one-frame-lag measurement,
## and the reason the rider never trails the deck by a frame.
func _physics_process(delta: float) -> void:
	if not _driving or _yacht == null:
		return
	_yacht.drive(delta, touch.input, yacht_speed_factor())
	_keepy.call("follow_carrier")
	if _hud != null:
		_hud.set_ghost(touch.anchor, touch.finger, touch.steering_active)

## The boat's re-mooring rule, for every idle balloon and for the parked
## ball: far from every dock (or the park) AND every one of them off
## screen, the prop is moved with no animation. Driven by HubWorld each
## frame so the position arrives from the one place that reads it.
func update(keepy_position: Vector3) -> void:
	var flat := Vector3(keepy_position.x, 0.0, keepy_position.z)
	for i in _lines.size():
		var entry: Dictionary = _lines[i]
		if entry["riding"]:
			continue
		var docks: Array = entry["docks"]
		var nearest := nearest_dock(i, flat)
		if nearest == int(entry["at"]):
			continue
		var far := true
		for d in docks:
			if flat.distance_to(d) < REMOOR_MIN_DISTANCE:
				far = false
		if not far:
			continue
		if _visible(docks[0], 2.2) or _visible(docks[1], 2.2):
			continue
		_park(i, nearest)
	# The ball: back to its park when abandoned far away and unseen.
	if _ball != null and not (_keepy != null and _keepy.call("is_on_vehicle")):
		var here := ball_position()
		if here.distance_to(BALL_PARK) > 0.5 and flat.distance_to(here) >= REMOOR_MIN_DISTANCE \
				and flat.distance_to(BALL_PARK) >= REMOOR_MIN_DISTANCE \
				and not _visible(here, 1.0) and not _visible(BALL_PARK, 1.0):
			_ball.global_position = BALL_PARK
			_ball.scale = Vector3.ONE

func _visible(point: Vector3, margin: float) -> bool:
	if _camera == null:
		return true
	for probe in [point, point + Vector3(margin, 0, 0), point + Vector3(-margin, 0, 0),
			point + Vector3(0, 0, margin), point + Vector3(0, 0, -margin), point + Vector3(0, 6.5, 0)]:
		if _camera.is_position_in_frustum(probe):
			return true
	return false
