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
## It is NOT re-parked by the off-screen rule: where the player leaves it
## is where it stays for the rest of THIS session -- a vehicle whose point
## is to cross the map must not walk home on its own. CH45: it no longer
## survives a reload. It always respawns at YACHT_PARK, because Mathieu
## lost it once and had no way to find it again.
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

## CH33 -- FAMILY B, THIRD VEHICLE: the sailboat, on the sea CH29 already
## built. Same door as the ball and the yacht (tap it, walk, climb on),
## same coordinator shape as the yacht (this file mounts/exits/drives it;
## SailBoat.gd owns its own numbers and its grounding). It is driven by
## the SAME touch writer and watched by the SAME chase camera as the
## other two -- CLAUDE.md's doctrine for a shared mode (CH30) applies here
## without a new exception to debate.
##
## NO PERSISTENCE (brief CH33, explicit): unlike the yacht, this vehicle
## has no WorldSave field. It is always found at SAILBOAT_MOORING at the
## next session, however it was left.
const VEHICLE_SAILBOAT: int = 2
## Just off the cove's beach, inside the sea (HubRegion.in_sea/shore_distance
## both agree, checked by SailBoatProbe) and close enough to shore that a
## walk from any part of the beach reaches the tap radius below -- HubRegion
## already treats this water as walkable ground up to COVE_MAX.x, so no new
## rule is needed for Keepy to wade to it.
const SAILBOAT_MOORING: Vector3 = Vector3(65.0, 0.0, -110.0)
## Deck top: authored ONCE in SailBoat (itself reusing SandYacht.SEAT_Y,
## the same hull GLB), republished here for every reader that predates it.
const SAILBOAT_SEAT_Y: float = SailBoat.SEAT_Y
const SAILBOAT_TAP_RADIUS: float = 1.8
const SAILBOAT_FOOTPRINT: float = 2.0
const SAILBOAT_WIND_MIN: float = 0.85
const SAILBOAT_WIND_MAX: float = 1.25

## CH41 -- FAMILY B, FOURTH VEHICLE: the electric sled, and the first one
## on this map that drives on a SURFACE. Same door as the other three (tap
## it, walk, climb on), same coordinator shape (this file mounts/exits/
## drives it; SledBody.gd owns its numbers, its body and its wall), same
## touch writer, same chase camera, same HUD. What is new is entirely
## inside SledBody: SurfaceDrive rebases it onto HubSurface and pushes it
## down a slope.
##
## NO PERSISTENCE (brief CH41, explicit, like the sailboat): no WorldSave
## field, no schema bump. It is found at SLED_PARK at every start, however
## it was left.
const VEHICLE_SLED: int = 3
## THE SUMMIT of the west ridge, and it is the summit BY CONSTRUCTION:
## HubMountain.BUMPS[0] is a raised cosine centred here, so its peak is
## this point and no second measurement is needed. Its y is deliberately
## 0 -- SledBody.place() reads the height off HubSurface, and a y typed
## here would be a second spelling of a fact the grid already owns.
const SLED_PARK: Vector3 = Vector3(-49.0, 0.0, 3.0)
## Deck top: authored ONCE in SledBody, republished here for the readers
## that ask this file rather than the vehicle.
const SLED_SEAT_Y: float = SledBody.SEAT_Y
const SLED_TAP_RADIUS: float = 1.8

## =====================================================================
## CH53 -- FAMILY B, FIFTH VEHICLE: the skateboard.
##
## The SAUTILLON's pattern exactly, and Mathieu named it that way: tap
## it, walk to it, `KeepyHopper.mount_vehicle(board, lift)` -- a BOUNCING
## vehicle, so every ordinary hop becomes VEHICLE_HOP_DISTANCE 2.7 u and
## VEHICLE_HOP_HEIGHT 1.15 u. Not a gliding one (the yacht's shape) and
## not a driven one (the yacht, the sailboat and the sled since CH30):
##
##   * the brief asks for "session libre, score continu, pas de debut ni
##     de fin", which is the tap-to-move loop and not a drive;
##   * a DRIVEN vehicle brings the CHASE camera, and CH52 section 8.5 is
##     explicit that its whole budget is measured under HubCamera.OFFSET
##     and "ne vaut pas pour une poursuite". A chase camera over the north
##     lobe is a lot of its own (a ChaseAudit), not a line in this one;
##   * and a bounce IS the trick. The board exists so a landing lands
##     somewhere a walk would not reach.
##
## NO PERSISTENCE, and no schema field -- the sailboat's and the sled's
## precedent. It is found at SKATE_PARK at every start, however it was
## left. What DOES persist is the park's stock (WorldSave.SKATE_STOCK_ID),
## because that is the anti-farm guard and a guard that forgets on reload
## is not one.
const VEHICLE_SKATE: int = 4
## ⚠️ THE NORTH END OF THE PARK, AND THAT IS A RENDERED DECISION.
##
## The obvious place is the SOUTH lip, on the walk in from the plateau.
## Rendered, it is the wrong one: HubCamera sits at the player's z + 8.9
## and never yaws, so a rider who mounts at the south rides AWAY from the
## lens into a park that is entirely behind it. Mounting at the NORTH he
## rides southward with the whole park in frame ahead of him -- the same
## five modules, the same camera, and the opposite reading. See the frame
## arithmetic in HubSkatepark's header, and the probe run that measured
## one module in frame out of five before this moved.
##
## x = 3 and not 0, and that is a probe finding rather than a choice:
## parked on the axis at (0, 60) the board sat 4.53 u from the bowl's
## centre against a required 5.6 -- i.e. ON the bowl's rim, which reads
## as a board dropped INTO the dish. PHASE G caught it as a footprint
## clash. (3.0, 60.0) clears every module, keeps 1.62 u of margin to the
## lobe rim, and still frames all five modules from the mount.
##
## The minimap PLACE marker on the park is what makes it findable from
## the plateau, which is the job a marker exists for (CH46).
##
## ⚠️ Flat by construction -- the y is 0 and stays 0 here, and the node is
## placed through HubSurface like every other ground point in this file's
## neighbours. A y typed into a park position is the second spelling
## CLAUDE.md keeps paying for.
const SKATE_PARK: Vector3 = Vector3(3.0, 0.0, 60.0)
## The ball's radius, and for the ball's stated reason: the board is drawn
## small (0.92 u long) and the ground round it is nobody else's target.
const SKATE_TAP_RADIUS: float = 1.5
const SKATE_FOOTPRINT: float = 1.2
## Deck top: authored ONCE in SkateparkMesh, republished here.
const SKATE_LIFT: float = SkateparkMesh.DECK_TOP
## =====================================================================
## CH54 -- THE BOARD ROLLS. It no longer bounces.
##
## SkateDriveProbe measured the CH53 board exactly as Mathieu described it
## from the device: 7.94 u/s from the first frame to a dead stop, six
## 2.7 u arcs 1.30 u high -- the Sautillon's bounce with a plank drawn
## under it. So the board is now a GLIDING vehicle (CH29's shape, the sand
## yacht's before CH30 drove it) with the pace profile CH54 added to that
## shape: a run-up over SKATE_ACCEL_U, a cruise at SKATE_CRUISE, a run-out
## over SKATE_BRAKE_U into the tap, and a push-off again after a reversal.
##
## Still tap-to-move, still the fixed camera, still no physics: the
## brief's guard-rails and CH53's own reasons (a DRIVEN vehicle brings the
## chase camera, whose north-lobe budget CH52 says is unmeasured). What a
## rider gets is a speed of his own, a start that builds and a stop that
## eases -- the three things a bounce at constant pace cannot give.
##
## THE NUMBERS. Cruise 10.0 u/s is x1.87 the walk (5.36 u/s measured)
## and x1.26 the bounce; the yacht's CH29 glide was 10.7 and read fast on
## device, the park is 10 u long, so a shade under. It was 9.0 first,
## and SkateDriveProbe measured the 16 u ride from the park at 2.233 s
## against the bounce's 2.100 s: the ramps cost more than the cruise
## bought, and a ride that is slower end to end than the thing it
## replaces is not a ride. Segments of 1.6 u: short enough that a
## re-tap answers within 0.16 s at cruise and the ramps have three
## steps, long enough that a roll across the park lands six times rather
## than twelve (every landing runs HubWorld's whole landing chain).
## Run-up and run-out of 3.2 u each, i.e. two segments: from rest the
## first 3.2 u take 0.50 s (about what two walking hops take), so a tap
## still answers at once -- it just does not leave at cruise. The 16 u
## ride measures 1.967 s on the board against 2.100 s bouncing and
## ~3.0 s on foot, the first 3 frames at 3.8 u/s and the last 3 at 3.7
## (SkateDriveProbe PHASE P, xvfb, fixed-fps 60).
const SKATE_CRUISE: float = 10.0
const SKATE_GLIDE_STEP: float = 1.6
const SKATE_GLIDE_S: float = SKATE_GLIDE_STEP / SKATE_CRUISE
const SKATE_ACCEL_U: float = 3.2
const SKATE_BRAKE_U: float = 3.2
## CH61: how far a board that stops being pushed at cruise may coast
## before it stops. NOT a fourth taste -- it is the skatepark's own
## extent, published by the park and read here, so "a released board
## comes to rest inside the park it was pushed in" is a property of the
## layout rather than of a number typed next to three others. Move a
## module and this follows; retype it here and it does not.
##
## A function and not a const because a const cannot call one, and the
## alternative -- writing the span down -- is the second spelling this
## whole convention exists to refuse.
static func skate_coast_u() -> float:
	return HubSkatepark.park_span()

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
var _sailboat: SailBoat = null
var _sled: SledBody = null
var _board: Node3D = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _weather: Node = null
## CH33: the wet test, handed in by setup() -- the one instance HubWorld
## already builds (HubWater.new()), never a second one over the same
## bodies. Read once per driven frame for on_surface; null is legal (a
## world without it simply always answers "not on sea", the safe default).
var _water: HubWater = null
var _time: float = 0.0
## CH30 -- the drive mode. `touch` is this vehicle's writer, the same
## class the kart uses; `_driving` is the one flag, and every other fact
## (the rider is ON_CARRIER, the camera is chasing, the HUD is up) is
## turned on and off with it in the same two functions. CH33 adds
## `_driving_sailboat` alongside it rather than folding it in: mutual
## exclusion between the two is enforced explicitly in both mount
## functions below, so a reader never has to infer which flag a shared
## `touch`/camera/HUD currently belongs to.
var touch: KartTouchInput = null
var _hud: KartHud = null
var _driving: bool = false
var _driving_sailboat: bool = false
var _driving_sled: bool = false

signal yacht_driving_changed(driving: bool)
signal sailboat_driving_changed(driving: bool)
signal sled_driving_changed(driving: bool)

func _ready() -> void:
	for i in LINES.size():
		_build_line(i)
	_build_ball()
	_build_board()
	_build_yacht()
	_build_sailboat()
	_build_sled()
	touch = KartTouchInput.new()
	touch.name = "YachtTouch"
	add_child(touch)
	# CH63 LOT 1: the board's own writer. A SECOND node and not a second
	# use of `touch` -- that one writes a KartInput for three vehicles
	# that share VehicleDrive, and the board shares none of it. Built
	# unconditionally (it costs one empty Node and it is disabled) so
	# that flipping the scheme mid-session has nothing to construct.
	_board_touch = SkateTouchInput.new()
	_board_touch.name = "BoardTouch"
	add_child(_board_touch)
	_board_touch.pushed.connect(_on_board_pushed)

## Handed the nodes this needs, once, by HubWorld. `hud` is the kart's
## HUD in its vehicle mode (one exit button and the steering ghost): a
## second HUD would be a second copy of the same two widgets. `water` is
## CH33's wet test (HubWater), read every driven frame for the sailboat's
## on_surface; optional so a caller that predates it still resolves.
func setup(keepy: Node3D, camera: Camera3D, weather: Node, hud: KartHud = null, water: HubWater = null) -> void:
	_keepy = keepy
	_camera = camera
	_weather = weather
	_hud = hud
	_water = water
	if _hud != null:
		_hud.exit_pressed.connect(exit_yacht)
		_hud.exit_pressed.connect(exit_sailboat)
		_hud.exit_pressed.connect(exit_sled)
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
		# CH46: a dock is a PLACE on the map -- six of them, and they are
		# the only reason a player walks to the far corners of the plateau.
		MinimapMarkers.mark(dock, MinimapMarkers.PLACE)
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
	# CH46: a balloon is a VEHICLE -- it carries Keepy and it MOVES, which
	# is the whole reason a marker is worth a frame of work.
	MinimapMarkers.mark(balloon, MinimapMarkers.VEHICLE, StringName("balloon_%d" % index))
	add_child(balloon)
	entry["balloon"] = balloon
	_lines.append(entry)
	_park(index, 0)

func _build_ball() -> void:
	_ball = _glb_node("HopBall", "hopball_0", CozyPalette.decor_material())
	_ball.position = BALL_PARK
	# CH46: the hop ball rides and re-garages itself out of frame, which is
	# exactly the thing a player cannot find without a map.
	MinimapMarkers.mark(_ball, MinimapMarkers.VEHICLE, &"hopball")
	add_child(_ball)

## CH53: the skateboard. Built HERE and not by HubSkatepark, because what
## makes it usable is this file's vehicle door -- `vehicle_at`, the
## `tapped_vehicle` channel, `_try_mount_ball`'s "one vehicle at a time".
## A board owned by the park would have to grow a second copy of all of
## it, and CLAUDE.md's ladder pattern is what a second tap channel turns
## into when nobody is watching.
## CH57: and behind DevTools.physics_enabled() the same drawing hangs off
## a CharacterBody3D instead of being the node itself. ONE MeshInstance3D
## either way, one mesh, one material, one shadow setting -- the draw call
## and the primitive count are identical, which is what CH56's verdict
## point 3 promised and what SkatePhysicsProbe PHASE B measures.
func _build_board() -> void:
	var builder := SkateparkMesh.new()
	var visual := MeshInstance3D.new()
	visual.mesh = builder.skateboard()
	visual.material_override = CozyPalette.decor_material()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if DevTools.physics_enabled():
		visual.name = "SkateboardMesh"
		var body := SkateBoardBody.new()
		body.add_child(visual)
		# The board's dimensions are AUTHORED in SkateparkMesh and read
		# here; the body publishes none of them. Same four numbers the
		# mesh above was built from, in the same call site, so a lot that
		# retunes the deck cannot leave the shape behind.
		body.attach_shape(SkateparkMesh.DECK_WIDTH * 0.5, SkateparkMesh.DECK_LENGTH)
		# CH54's ride, handed over rather than re-authored. These are the
		# same three constants HubWorld passes to mount_vehicle when the
		# switch is down, so the two modes ride the same numbers and any
		# difference Mathieu feels is the PHYSICS and not a retune.
		body.configure(SKATE_CRUISE, SKATE_ACCEL_U, SKATE_BRAKE_U, skate_coast_u())
		_board = body
		# CH62: the two responses that need a node of their own. Built
		# HERE, in the same branch and behind the same switch as the
		# body, so "PHYS OFF is unchanged" is a property of the ONE `if`
		# that already decides what a board is -- not of four scattered
		# guards that a later lot could get out of step.
		_board_audio = SkateAudio.new()
		_board_audio.setup(body)
		add_child(_board_audio)
		_board_shadow = SkateShadow.new()
		_board_shadow.setup(body)
		add_child(_board_shadow)
	else:
		_board = visual
	_board.name = "Skateboard"
	_board.position = HubSurface.ground(SKATE_PARK)
	# A VEHICLE on the map: it carries Keepy, it moves, and it is 46 u
	# north of the spawn -- exactly the thing CH46 built markers for. No
	# THUMBS entry, so it draws with the abstract vehicle icon; that is
	# the documented fallback and it avoids re-baking the atlas.
	MinimapMarkers.mark(_board, MinimapMarkers.VEHICLE)
	add_child(_board)

func board_node() -> Node3D:
	return _board

func board_position() -> Vector3:
	return Vector3(_board.global_position.x, 0.0, _board.global_position.z)

## =====================================================================
## CH57 LOT 1 -- THE BOARD AS A CARRIER
##
## Under DevTools.physics_enabled() the board stops being a hop modifier
## and becomes the fifth CARRIER of this file: mount_carrier / follow_
## carrier / leave_carrier, the contract already validated on the balloon,
## the owl, the zipline, the bear and the three driven vehicles.
##
## ⚠️ WHAT THIS COSTS, SAID OUT LOUD RATHER THAN DISCOVERED LATER: while
## he rides it the hopper is ON_CARRIER, and ON_CARRIER emits no
## `hop_landed`. HubSkatepark.note_landing is therefore NEVER CALLED, so
## a physics roll SCORES NOTHING. That is not an oversight and it is not
## a regression of the shipped game (the switch is off for every player):
## CH55 section 3.3 requires a physics mode to emit no landing at all, on
## HubPortal's grounds, and CH55's LOT 2 is the lot that replaces the
## proxy with a real arithmetic classification. This lot measures F; it
## does not re-score anything.
var _riding_board: bool = false
## CH62. Null with the physics switch down, and never built at all in
## that case -- see `_build_board`.
var _board_audio: SkateAudio = null
var _board_shadow: SkateShadow = null

## =====================================================================
## CH63 LOT 1 -- THE DRAG SCHEME'S WRITER, AND THE TEMPORARY ADAPTER
##
## `_board_touch` captures a gesture (see SkateTouchInput). What it does
## NOT do is drive: this file turns its two outputs into the one call the
## shipped board already understands, `set_target()`, and CH61's inertia
## model is not touched by this lot at all.
##
## ⚠️ THE ADAPTER IS TEMPORARY AND IS LABELLED SO ON PURPOSE. It exists to
## make the CAPTURE measurable on device without a second lot's worth of
## change riding along with it. LOT 2 replaces it with a heading the drive
## model reads directly, and moves the board to the chase camera; until
## then a held heading is expressed as a destination out in front, which
## is the only vocabulary `SkateBoardBody.drive()` has.
var _board_touch: SkateTouchInput = null

## How far in front of the board the held heading plants its destination.
##
## ⚠️ IT IS A MARGIN, NOT A TASTE, and it is the one number this adapter
## writes down. `drive()` brakes instead of pushing once the target is
## inside the run-out (`v^2 / 2b + ARRIVE_EPSILON`, which at cruise is
## SKATE_BRAKE_U + 0.45), so a destination nearer than that would make a
## held drag decelerate -- a gesture that means "go" producing a stop.
## Twice the run-out keeps the board outside its own braking window at
## every speed it can reach, and SkateInputProbe PHASE D gates exactly
## that property (a held drag on the flat reaches cruise) rather than
## gating the digit.
const BOARD_DRAG_LEAD: float = SKATE_BRAKE_U * 2.0

func board_touch() -> SkateTouchInput:
	return _board_touch

## The ONE place the writer is armed or disarmed. mount_board(),
## leave_board() and HubWorld's TAP/DRAG button all call this and nothing
## else touches `enabled` -- so a ride can never start with the scheme
## half-applied, and flipping the scheme mid-ride takes effect on the
## spot without a scene rebuild.
func sync_board_input() -> void:
	if _board_touch == null:
		return
	var want: bool = _riding_board and SkateTouchInput.drag_enabled()
	if _board_touch.enabled != want:
		_board_touch.enabled = want

## The tap half of the scheme: relaunch along the heading the board is
## already pointing. Deliberately NOT a destination under the finger --
## that is the OTHER scheme, and a push that also aimed would make the two
## schemes indistinguishable on device, which is the whole thing this A/B
## is for.
func _on_board_pushed() -> void:
	var body := board_body()
	if body == null or not _riding_board:
		return
	var facing := Vector3(sin(body.rotation.y), 0.0, cos(body.rotation.y))
	if facing.length() < 0.0001:
		return
	body.set_target(HubRegion.clamp_to(
		body.flat_position() + facing.normalized() * BOARD_DRAG_LEAD))

## The drag half: re-plant the destination out in front of wherever the
## board now is, every physics tick a finger holds a heading.
##
## ⚠️ WHILE A FINGER HOLDS A HEADING, THE STALL GUARD IS THE FINGER. A
## carrot that moves with the board never lets `remaining` improve, so
## `set_target()`'s reset is what keeps SkateBoardBody's progress guard
## from firing half a second into every held drag. That is stated rather
## than discovered: the guard exists to end a push nobody is watching, and
## under this scheme somebody is -- they lift. What still ends a drag into
## a wall is `_fence`, which clears the target itself at the region
## border and is untouched by this lot.
func _apply_board_drag() -> void:
	var body := board_body()
	if body == null or _board_touch == null or not _board_touch.has_heading():
		return
	var heading: Vector3 = _board_touch.heading_world(_camera)
	if heading == Vector3.ZERO:
		return
	body.set_target(HubRegion.clamp_to(
		body.flat_position() + heading * BOARD_DRAG_LEAD))

func board_body() -> SkateBoardBody:
	return _board as SkateBoardBody

func board_audio() -> SkateAudio:
	return _board_audio

func board_shadow() -> SkateShadow:
	return _board_shadow

## CH62: the three responses that follow the ride rather than the board.
## One call site each way, so a ride can never start with two of them on
## and one off.
func _set_ride_feel(riding: bool) -> void:
	if _board_audio != null:
		_board_audio.set_riding(riding)
	if _board_shadow != null:
		_board_shadow.set_riding(riding)

func is_riding_board() -> bool:
	return _riding_board

## Climbs aboard. mount_sled()'s shape exactly, minus the drive mode: no
## `touch.enabled`, no chase camera, no HUD -- see the class header of
## SkateBoardBody for why a tapped destination is not a piloted vehicle.
func mount_board() -> bool:
	var body := board_body()
	if body == null or _keepy == null:
		return false
	if _driving or _driving_sailboat or _driving_sled or _riding_board:
		return false
	body.clear_target()
	if not _keepy.call("mount_carrier", body, body.seat(SKATE_LIFT)):
		return false
	_riding_board = true
	# CH63 LOT 1: arm the drag writer if the drag scheme is selected. One
	# call, the same one leave_board() and the menu button make.
	sync_board_input()
	_keepy.call("follow_carrier")
	# CH62: the camera starts reacting to the ride. `has_method` for the
	# same reason the three driven vehicles use it -- a bench that hands
	# this file a bare Camera3D still mounts.
	if _camera != null and _camera.has_method("enter_ride"):
		_camera.call("enter_ride", body)
	_set_ride_feel(true)
	return true

## Steps off beside the board, on the sled's terms: the region's own clamp,
## refused back onto the board's own position if the side lands where he
## may not stand. The landing is FLAT -- leave_carrier reads its height off
## HubSurface, so a y written here would be a second spelling of it.
func leave_board() -> void:
	if not _riding_board:
		return
	var body := board_body()
	_riding_board = false
	# CH63 LOT 1: disarm first, so no event delivered during the step-off
	# can plant a destination on a board nobody is riding.
	sync_board_input()
	if body != null:
		body.clear_target()
	if _camera != null and _camera.has_method("exit_ride"):
		_camera.call("exit_ride")
	_set_ride_feel(false)
	var at: Vector3 = board_position()
	var side := Vector3(cos(_board.rotation.y), 0.0, -sin(_board.rotation.y)) * EXIT_SIDE
	var landing: Vector3 = _step_off(at + side, at)
	if landing.distance_to(at) < 0.8:
		landing = _step_off(at - side, at)
	_keepy.call("leave_carrier", landing)

## The tap, while riding. The point arrives ALREADY CLAMPED by
## HubTapInput, exactly as a hop destination does.
func set_board_target(point: Vector3) -> void:
	var body := board_body()
	if body == null or not _riding_board:
		return
	body.set_target(point)

## True when the board is standing still under him -- what HubWorld asks
## before reading a tap on Keepy himself as "get off", so a tap made
## mid-roll steers instead of ejecting.
func board_at_rest() -> bool:
	var body := board_body()
	return body != null and body.at_rest()

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
	# CH45: no saved position (removed -- Mathieu lost the yacht mid-session
	# and had no way to find it again). Always the park, nose toward the sea.
	_yacht.place(YACHT_PARK, PI / 2.0)

## CH33: a SailBoat node -- same GLB pair as the land yacht (yacht_hull_0,
## yacht_sail_0: brief's asset rule, no new model), no saved position (the
## brief's "aucune persistance"), so it is placed at SAILBOAT_MOORING
## every time, facing out to sea (+x).
func _build_sailboat() -> void:
	_sailboat = SailBoat.new()
	_sailboat.name = "SailBoat"
	add_child(_sailboat)
	_sailboat.build(
		CozyPalette.glb_mesh(CozyPalette.decor_path("yacht_hull_0")), CozyPalette.decor_material(),
		CozyPalette.glb_mesh(CozyPalette.decor_path("yacht_sail_0")), CozyPalette.decor_material_wind(0.10, 2.6))
	_sailboat.place(SAILBOAT_MOORING, PI / 2.0)

## CH41: a SledBody node -- a PROCEDURAL mesh (the brief forbids
## generating an asset, and the decor inventory holds nothing sled-shaped)
## under a chassis that tilts onto the ground. Parked at the summit with
## its nose pointing down the long east flank, which is the way a player
## coming up from the plateau meets it.
func _build_sled() -> void:
	_sled = SledBody.new()
	_sled.name = "Sled"
	add_child(_sled)
	_sled.build()
	_sled.place(SLED_PARK, PI / 2.0)

## ---- what the scatter and the tap need -----------------------------

## Ground discs nothing should be sown in: every dock and the ball's park.
static func footprints() -> Array:
	var out: Array = []
	for spec in LINES:
		for d in spec["docks"]:
			out.append({"position": Vector3(d.x, 0.0, d.z), "radius": DOCK_FOOTPRINT})
	out.append({"position": BALL_PARK, "radius": BALL_FOOTPRINT})
	out.append({"position": YACHT_PARK, "radius": YACHT_FOOTPRINT})
	out.append({"position": SAILBOAT_MOORING, "radius": SAILBOAT_FOOTPRINT})
	out.append({"position": SKATE_PARK, "radius": SKATE_FOOTPRINT})
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

## CH29/CH33: WHICH vehicle a tap at `point` means -- VEHICLE_BALL,
## VEHICLE_YACHT, VEHICLE_SAILBOAT or -1 -- on accepts_vehicle_tap's exact
## terms. The ball is asked first (it is the older channel), then the
## yacht, then the sailboat; the three parks are far enough apart that the
## order can only ever decide when the player dropped one on another.
func vehicle_at(point: Vector3) -> int:
	# Only the vehicle he RIDES withdraws: a tap on another one while
	# mounted means "swap" (HubWorld drops the first where he stands), so a
	# player who bounced up to a vehicle on another is not asked to step
	# off first. Nobody mounted: all three answer.
	var riding: Node3D = null
	if _keepy != null and _keepy.has_method("vehicle_node"):
		riding = _keepy.call("vehicle_node")
	var flat := Vector3(point.x, 0.0, point.z)
	if riding != _ball and flat.distance_to(ball_position()) <= BALL_TAP_RADIUS:
		return VEHICLE_BALL
	# CH30/CH33: a driven vehicle WITHDRAWS from the tap for the length of
	# its drive (the boat's pattern, the kart's `accepts_tap`), so a tap
	# made meanwhile falls through to the ground path and is refused there
	# by ON_CARRIER -- never swallowed by the thing being driven.
	if _yacht != null and not _driving and flat.distance_to(yacht_position()) <= YACHT_TAP_RADIUS:
		return VEHICLE_YACHT
	if _sailboat != null and not _driving_sailboat and flat.distance_to(sailboat_position()) <= SAILBOAT_TAP_RADIUS:
		return VEHICLE_SAILBOAT
	if _sled != null and not _driving_sled and flat.distance_to(sled_position()) <= SLED_TAP_RADIUS:
		return VEHICLE_SLED
	# CH53: the board, last, and on the ball's exact terms -- only the one
	# he RIDES withdraws, so a tap on it while riding something else means
	# "swap" and HubWorld drops the first where he stands.
	# CH57: under the physics switch the rider is ON_CARRIER, so
	# `vehicle_node()` is null and the "only the one he rides withdraws"
	# test above cannot see him. `_riding_board` is that same withdrawal,
	# written the way the three driven vehicles write theirs -- without it
	# a tap on the board he is standing on would re-mount it.
	if _board != null and riding != _board and not _riding_board \
			and flat.distance_to(board_position()) <= SKATE_TAP_RADIUS:
		return VEHICLE_SKATE
	return -1

func yacht_node() -> Node3D:
	return _yacht

func yacht() -> SandYacht:
	return _yacht

func yacht_position() -> Vector3:
	return _yacht.flat_position()

func is_driving_yacht() -> bool:
	return _driving

func sailboat_node() -> Node3D:
	return _sailboat

func sailboat() -> SailBoat:
	return _sailboat

func sailboat_position() -> Vector3:
	return _sailboat.flat_position()

func is_driving_sailboat() -> bool:
	return _driving_sailboat

func sled_node() -> Node3D:
	return _sled

func sled() -> SledBody:
	return _sled

func sled_position() -> Vector3:
	return _sled.flat_position()

func is_driving_sled() -> bool:
	return _driving_sled

func vehicle_position(kind: int) -> Vector3:
	if kind == VEHICLE_YACHT:
		return yacht_position()
	if kind == VEHICLE_SAILBOAT:
		return sailboat_position()
	if kind == VEHICLE_SLED:
		return sled_position()
	if kind == VEHICLE_SKATE:
		return board_position()
	return ball_position()

func vehicle_tap_radius(kind: int) -> float:
	if kind == VEHICLE_YACHT:
		return YACHT_TAP_RADIUS
	if kind == VEHICLE_SAILBOAT:
		return SAILBOAT_TAP_RADIUS
	if kind == VEHICLE_SLED:
		return SLED_TAP_RADIUS
	if kind == VEHICLE_SKATE:
		return SKATE_TAP_RADIUS
	return BALL_TAP_RADIUS

## The wind's multiplier on the yacht's pace: 0.85 in snow, 1.0 in the
## sun, 1.12 in rain, 1.25 (the cap) in a storm. Read by _process and
## pushed into KeepyHopper every frame he rides.
func yacht_speed_factor() -> float:
	return clampf(0.85 + 0.15 * _wind(), YACHT_WIND_MIN, YACHT_WIND_MAX)

## Same shape for the sailboat -- its own constants, so a future lot that
## makes one vehicle more wind-sensitive than the other moves one pair of
## numbers, not a shared formula.
func sailboat_speed_factor() -> float:
	return clampf(0.85 + 0.15 * _wind(), SAILBOAT_WIND_MIN, SAILBOAT_WIND_MAX)

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
	if _driving or _driving_sailboat or _keepy == null or _yacht == null:
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
	yacht_driving_changed.emit(false)

## CH33: climbs aboard the sailboat. The yacht's mount_yacht() shape
## exactly, minus the drivable-ground refusal (a boat has no "may not be
## here" the way a land vehicle does -- the grounding in SailBoat.gd is a
## drag, not a place it is forbidden to occupy) and minus any WorldSave
## write (brief: no persistence for this vehicle).
func mount_sailboat() -> bool:
	if _driving or _driving_sailboat or _keepy == null or _sailboat == null:
		return false
	if not _keepy.call("mount_carrier", _sailboat.deck(), SailBoat.SEAT):
		return false
	_driving_sailboat = true
	_sailboat.velocity = Vector3.ZERO
	touch.enabled = true
	touch.hold_throttle(MOUNT_HOLD_S)
	_keepy.call("follow_carrier")
	if _camera != null and _camera.has_method("enter_drive"):
		_camera.call("enter_drive", _sailboat)
	if _hud != null:
		_hud.set_vehicle_mode(true)
		_hud.visible = true
	sailboat_driving_changed.emit(true)
	return true

## The HUD button, for the sailboat. Stops it where it is and gives the
## body back beside it -- exactly exit_yacht()'s shape, minus the
## WorldSave write (no persistence, brief CH33): the boat is simply left
## where the drive stopped it, and the NEXT SESSION starts it back at
## SAILBOAT_MOORING regardless.
func exit_sailboat() -> void:
	if not _driving_sailboat:
		return
	touch.enabled = false
	touch.input.reset()
	_sailboat.velocity = Vector3.ZERO
	_driving_sailboat = false
	if _camera != null and _camera.has_method("exit_drive"):
		_camera.call("exit_drive")
	if _hud != null:
		_hud.visible = false
		_hud.set_ghost(Vector2.ZERO, Vector2.ZERO, false)
		_hud.set_vehicle_mode(false)
	var at: Vector3 = sailboat_position()
	var landing: Vector3 = _step_off(at + _sailboat.right() * EXIT_SIDE, at)
	if landing.distance_to(at) < 0.8:
		landing = _step_off(at - _sailboat.right() * EXIT_SIDE, at)
	_keepy.call("leave_carrier", landing)
	sailboat_driving_changed.emit(false)

## CH41: climbs aboard the sled. mount_yacht()'s shape exactly, including
## its drivable-ground refusal (a sled is a LAND vehicle, so a sled that
## somehow sat where it may not drive could not be driven off it), and
## minus any WorldSave write (brief: no persistence).
##
## Mutual exclusion with the other three is the yacht's own: the guard
## refuses while any drive flag is up, and _try_mount_ball drops a held
## vehicle before it gets here.
func mount_sled() -> bool:
	if _driving or _driving_sailboat or _driving_sled or _keepy == null or _sled == null:
		return false
	if not SledBody.drivable(sled_position()):
		_sled.place(SLED_PARK, PI / 2.0)
		return false
	if not _keepy.call("mount_carrier", _sled.deck(), SledBody.SEAT):
		return false
	_driving_sled = true
	_sled.velocity = Vector3.ZERO
	touch.enabled = true
	touch.hold_throttle(MOUNT_HOLD_S)
	_keepy.call("follow_carrier")
	if _camera != null and _camera.has_method("enter_drive"):
		_camera.call("enter_drive", _sled)
	if _hud != null:
		_hud.set_vehicle_mode(true)
		_hud.visible = true
	sled_driving_changed.emit(true)
	return true

## The HUD button, for the sled. exit_yacht()'s shape, minus the WorldSave
## write. The landing is taken BESIDE it and clamped to ground it could
## itself have driven on -- and the step-off arc reads its own ground
## height, so stepping off on a hillside lands on the hillside
## (KeepyHopper.leave_carrier takes _hop_to_y off HubSurface).
func exit_sled() -> void:
	if not _driving_sled:
		return
	touch.enabled = false
	touch.input.reset()
	_sled.velocity = Vector3.ZERO
	_driving_sled = false
	if _camera != null and _camera.has_method("exit_drive"):
		_camera.call("exit_drive")
	if _hud != null:
		_hud.visible = false
		_hud.set_ghost(Vector2.ZERO, Vector2.ZERO, false)
		_hud.set_vehicle_mode(false)
	var at: Vector3 = sled_position()
	var landing: Vector3 = _step_off(at + _sled.right() * EXIT_SIDE, at)
	if landing.distance_to(at) < 0.8:
		landing = _step_off(at - _sled.right() * EXIT_SIDE, at)
	# The flat landing, exactly as the yacht hands it over: leave_carrier
	# reads the height off HubSurface itself, so a y written here would be
	# a second spelling of it.
	_keepy.call("leave_carrier", landing)
	sled_driving_changed.emit(false)

## A landing point for the step-off: the region's own clamp, refused back
## to `fallback` (the vehicle's own position) if it lands where the
## vehicle may not be (the corridor mouths are the only place that can
## happen for the yacht; for the sailboat, mid-sea if the region's wading
## limit is somehow exceeded).
func _step_off(wanted: Vector3, fallback: Vector3 = Vector3.INF) -> Vector3:
	var landing: Vector3 = HubRegion.clamp_to(wanted)
	if HubRegion.contains(landing):
		return landing
	return fallback if fallback != Vector3.INF else yacht_position()

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
	if _sailboat != null:
		_sailboat.breathe(wind, _time)
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

## CH30/CH33: the driven vehicle's own physics step. Carrier first,
## carried immediately after in the SAME call -- the turnstile's
## one-frame-lag measurement, and the reason the rider never trails the
## deck by a frame. At most one of the two branches runs (mount_yacht()
## and mount_sailboat() refuse each other), so `touch.input` is never read
## by both in the same frame.
func _physics_process(delta: float) -> void:
	if _driving and _yacht != null:
		_yacht.drive(delta, touch.input, yacht_speed_factor())
		_keepy.call("follow_carrier")
		if _hud != null:
			_hud.set_ghost(touch.anchor, touch.finger, touch.steering_active)
	elif _driving_sailboat and _sailboat != null:
		var on_sea: bool = _water != null and _water.body_at(_sailboat.flat_position()) == &"sea"
		_sailboat.drive(delta, touch.input, sailboat_speed_factor(), on_sea)
		_keepy.call("follow_carrier")
		if _hud != null:
			_hud.set_ghost(touch.anchor, touch.finger, touch.steering_active)
	elif _driving_sled and _sled != null:
		# CH41: no wind and no wet test -- the ground under it is the only
		# thing this vehicle answers to, and SledBody reads that itself.
		_sled.drive(delta, touch.input)
		_keepy.call("follow_carrier")
		if _hud != null:
			_hud.set_ghost(touch.anchor, touch.finger, touch.steering_active)
	elif _riding_board and _board is SkateBoardBody:
		# CH57: carrier first, carried immediately after, in the SAME call
		# -- the discipline the other three branches above are written on,
		# and the reason the rider never trails the deck by a frame.
		#
		# NO `touch.input`, NO HUD, NO chase camera: this board is tapped
		# to a destination, not piloted frame by frame, so CLAUDE.md's
		# camera table leaves it on the FIXED camera and D6 stays shut.
		#
		# ⚠️ CH63 LOT 1 -- AND UNDER THE DRAG SCHEME IT *IS* PILOTED FRAME
		# BY FRAME, so that sentence has an expiry date. The camera is
		# still FIXED here because moving it is LOT 2's work and CLAUDE.md
		# requires a ChaseAudit pass with it; what changes today is only
		# that a held heading re-plants the destination each tick. With
		# the TAP scheme selected `_board_touch` is disabled, this call
		# returns on its first line, and the branch is byte-identical in
		# behaviour to CH57's.
		_apply_board_drag()
		(_board as SkateBoardBody).drive(delta)
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
