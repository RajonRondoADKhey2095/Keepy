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
## cove's own. Same door as the ball (tap it, walk, climb on) and the
## same hop-modifier model in KeepyHopper -- but a GLIDE, not a bounce:
## each hop is flat, long and unsquashed, so a chain of them reads as a
## continuous roll across the ground, and its pace follows the weather's
## `wind` (a sail). Free and continuous on the ground: the one kind of
## trip neither the balloon (fixed points) nor the ball (a bounce) offers.
##
## It is NOT re-parked by the off-screen rule. Where the player leaves it
## is where it stays, across sessions (WorldSave.cove_yacht): a vehicle
## whose point is to cross the map must not walk home on its own.
##
## The seat is authored ONCE, here, on RIDE_SEAT_Y's terms (the boat
## pattern: one constant for where a rider sits, read by whoever mounts).
const VEHICLE_BALL: int = 0
const VEHICLE_YACHT: int = 1
const YACHT_PARK: Vector3 = Vector3(48.0, 0.0, -112.0)
## Deck top of yacht_hull_0 (the box at y 0.35..0.65 plus its cushion): his
## feet stand there.
const YACHT_SEAT_Y: float = 0.66
const YACHT_TAP_RADIUS: float = 1.8
const YACHT_FOOTPRINT: float = 2.0
## Glide geometry: 3.2 u per 0.30 s is 10.7 u/s in the sun (x2.0 on foot,
## x1.35 the ball), scaled by the wind factor below -- capped so a storm
## run (13.3 u/s) stays at the balloon's proven 13 u/s under this camera.
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
var _yacht: Node3D = null
var _yacht_sail: MeshInstance3D = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _weather: Node = null
var _time: float = 0.0

func _ready() -> void:
	for i in LINES.size():
		_build_line(i)
	_build_ball()
	_build_yacht()

## Handed the three nodes this needs, once, by HubWorld.
func setup(keepy: Node3D, camera: Camera3D, weather: Node) -> void:
	_keepy = keepy
	_camera = camera
	_weather = weather
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

## The yacht is an EMPTY Node3D (what KeepyHopper writes: position, yaw,
## and a scale it leaves at ONE for a glide) carrying the hull and, as a
## separate mesh, the sail -- which takes the WIND material so its cloth
## bellies with the weather on its own, and is leaned by _process.
func _build_yacht() -> void:
	_yacht = Node3D.new()
	_yacht.name = "Yacht"
	var hull := _glb_node("Hull", "yacht_hull_0", CozyPalette.decor_material())
	_yacht.add_child(hull)
	_yacht_sail = _glb_node("Sail", "yacht_sail_0", CozyPalette.decor_material_wind(0.10, 2.6))
	_yacht.add_child(_yacht_sail)
	var saved: Vector3 = WorldSave.cove_yacht()
	if saved != Vector3.INF and HubRegion.contains(saved):
		_yacht.position = Vector3(saved.x, 0.0, saved.z)
	else:
		_yacht.position = YACHT_PARK
	# Nose toward the sea at the park; a saved yacht keeps only its place,
	# the yaw is rewritten by the first glide anyway.
	_yacht.rotation.y = PI / 2.0
	add_child(_yacht)

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
	if _yacht != null and riding != _yacht and flat.distance_to(yacht_position()) <= YACHT_TAP_RADIUS:
		return VEHICLE_YACHT
	return -1

func yacht_node() -> Node3D:
	return _yacht

func yacht_position() -> Vector3:
	return Vector3(_yacht.global_position.x, 0.0, _yacht.global_position.z)

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
	if _keepy != null and _keepy.has_method("vehicle_node") and _keepy.call("vehicle_node") == _yacht:
		WorldSave.note("yacht_rides")

## Where the yacht stands when he steps off is where it will be next
## session (the save is the one memory of that).
func _on_vehicle_dismounted() -> void:
	if _yacht != null:
		WorldSave.cove_set_yacht(yacht_position())

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
	if _yacht_sail != null:
		_yacht_sail.rotation.z = deg_to_rad(-7.0 * wind) * (0.75 + 0.25 * sin(_time * 2.3))
	if _keepy != null and _keepy.has_method("vehicle_node") and _keepy.call("vehicle_node") == _yacht:
		_keepy.call("set_vehicle_speed", yacht_speed_factor())
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
