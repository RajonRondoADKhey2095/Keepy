extends Node3D
class_name SandYacht
## CH30 -- THE SAND YACHT, now a DRIVEN vehicle.
##
## =====================================================================
## WHAT CHANGED, AND WHY IT IS THE SAME THING AS THE KART
##
## CH29 shipped the char a voile as a HOP MODIFIER: every ordinary tap on
## the ground became a flat, long glide, and a crossing was a sequence of
## taps. Mathieu's retour is that it must be driven like the kart --
## a finger held down, direction under the thumb, no sequence of taps.
##
## So it is: the SAME KartInput a thumb writes for the kart, written by
## the SAME KartTouchInput, read by the SAME VehicleDrive (CH30's
## extraction) with this vehicle's own numbers, watched by the SAME
## HubCamera.enter_drive() chase. There is no second copy of any of it --
## which was the brief's hard constraint, and the reason the extraction
## came first.
##
## What is NOT shared is the numbers. A land yacht is not a kart: it
## builds speed slowly (a sail, not an engine), slides more on sand, and
## turns lazily. Its steering rate is derived from the LIVE KartTuning
## preset rather than written here, so the 8/7/6 knob Mathieu validated
## on his own thumb moves both vehicles together and neither drifts away
## from the other.
##
## =====================================================================
## WHERE IT MAY GO -- and the one place it may NOT (brief P0 bis)
##
## Mathieu parked the yacht on the karting grid and nothing stopped him.
## The refusal is a property of WHERE IT MAY DRIVE, written once here:
## the drivable set is HubRegion minus the circuit zone and its corridor.
## A vehicle that cannot enter the circuit cannot be on the grid when the
## lights go out, so the guard needs no hook into the race at all -- and
## a saved position inside the circuit (a yacht left there before this
## lot) is refused at build and the yacht goes back to its park.
##
## The wall is AXIS-SEPARATED, not a clamp to the nearest region point:
## at 13 u/s a frame is 0.22 u, so trying the x move and the z move
## separately gives a wall the yacht SLIDES along instead of one it
## sticks to. A clamp_to() would have teleported it across the map the
## first time it touched a corner between two rectangles. See _wall() for
## the third case -- the one that stops a head-on hit from locking the
## vehicle up for good, which the first version of this file did.
##
## =====================================================================
## THE SEAT IS ON THE DECK, NOT ON THE ROOT
##
## The root carries position and yaw (what the driving model writes); the
## Deck carries the HEEL, and the rider is seated on the DECK, so he
## leans with the boat exactly as Keepy leans with the kart's chassis.
## One constant for where he sits, read by whoever mounts (RIDE_SEAT_Y's
## rule, the boat pattern).

## Pace. BASE_SPEED is CH29's glide pace kept to the metre --
## YACHT_GLIDE_DISTANCE / YACHT_GLIDE_S = 3.2 / 0.30 = 10.67 u/s -- so a
## crossing takes what it took before this lot and no travel time in the
## save or the journal moves. The wind still multiplies it, on the same
## 0.85 .. 1.25 band; a storm run is 13.3 u/s, the balloon's proven pace
## under this camera.
const BASE_SPEED: float = 10.67
## Off the sand it is not punished, only slowed (the kart's rule). Today
## the wall means this is never reached; it exists so a future zone can
## be soft ground without a new branch.
const OFF_SPEED: float = 4.6
const REVERSE_SPEED: float = 2.4
## Sheeting in: pushing the thumb up the screen (the kart's boost gesture)
## buys 18 % over the wind's pace. Modest on purpose -- the wind is what
## makes this vehicle fast, and a boost that dwarfed it would make the
## weather decorative.
const SHEET_RATIO: float = 1.18
## A sail builds speed more slowly than an engine, and loses it slowly.
const ACCEL_LAMBDA: float = 0.55
const COAST_LAMBDA: float = 0.22
const OVER_LAMBDA: float = 1.4
const BRAKE_DECEL: float = 9.0
## Steering. The RATE is not a literal: it is the live KartTuning preset
## times this ratio, so the 8/7/6 knob moves both vehicles and the yacht
## can never drift away from the feel Mathieu validated. 0.85 because a
## long-wheelbase land yacht turns lazily next to a kart -- it is the one
## place the two vehicles are deliberately not the same.
const STEER_RATIO: float = 0.85
const STEER_FULL_SPEED: float = 3.4
const STEER_HIGH_SPEED_KEEP: float = 0.66
## Sand holds less than tarmac: more carry-over on every turn, and the
## slide scrubs more pace. This is the character, not a defect.
const GRIP_ON_SAND: float = 3.2
const GRIP_OFF: float = 1.6
const SCRUB: float = 0.70
## Where his feet stand: the deck top of yacht_hull_0 (the box at
## y 0.35..0.65 plus its cushion). CH29's number, unchanged.
const SEAT_Y: float = 0.66
const SEAT: Vector3 = Vector3(0.0, SEAT_Y, 0.0)
## Heel: degrees of lean per unit of lateral acceleration, and the cap. A
## land yacht heels AWAY from the turn (the sail is pushed over), which is
## the opposite read from the kart's roll and is what tells the two apart
## at a glance.
const HEEL_DEG_PER_ACCEL: float = 1.6
const HEEL_MAX_DEG: float = 13.0
const HEEL_LAMBDA: float = 6.0
## A rectangle wide enough to contain every region rectangle, so
## VehicleDrive's own fence never bites and the wall below is the only
## thing that stops this vehicle. It is a backstop, not a boundary.
const WORLD_FENCE: Rect2 = Rect2(-220.0, -320.0, 440.0, 640.0)

var velocity: Vector3 = Vector3.ZERO

var _deck: Node3D = null
var _sail: MeshInstance3D = null
var _motion: VehicleDrive = null
var _last_velocity: Vector3 = Vector3.ZERO
var _heel: float = 0.0
var _time: float = 0.0
var _prev: Vector3 = Vector3.ZERO
var _on_sand: bool = true

## ---- where it may drive ------------------------------------------------

## The drivable set: the walkable region, minus the karting circuit and
## its corridor. Static so a probe and the scatter can ask without an
## instance (CLAUDE.md: a fact is published once, by an accessor).
static func drivable(point: Vector3) -> bool:
	return HubRegion.contains(point) and not HubRegion.in_circuit(point)

func _ready() -> void:
	_motion = VehicleDrive.new()
	_motion.max_speed = BASE_SPEED
	_motion.max_speed_off = OFF_SPEED
	_motion.reverse_speed = REVERSE_SPEED
	_motion.boost_speed_ratio = SHEET_RATIO
	_motion.accel_lambda = ACCEL_LAMBDA
	_motion.coast_lambda = COAST_LAMBDA
	_motion.off_lambda = OVER_LAMBDA
	_motion.brake_decel = BRAKE_DECEL
	_motion.steer_full_speed = STEER_FULL_SPEED
	_motion.steer_high_speed_keep = STEER_HIGH_SPEED_KEEP
	_motion.grip_on = GRIP_ON_SAND
	_motion.grip_off = GRIP_OFF
	_motion.scrub = SCRUB
	_prev = Vector3(global_position.x, 0.0, global_position.z)

## Builds the hull and the sail under a heeling deck. `mesh_for` is the
## owner's GLB loader, so this file does not duplicate the palette
## lookups HubTransport already owns.
func build(hull_mesh: Mesh, hull_material: Material, sail_mesh: Mesh, sail_material: Material) -> void:
	_deck = Node3D.new()
	_deck.name = "Deck"
	add_child(_deck)
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = hull_mesh
	hull.material_override = hull_material
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_deck.add_child(hull)
	_sail = MeshInstance3D.new()
	_sail.name = "Sail"
	_sail.mesh = sail_mesh
	_sail.material_override = sail_material
	_sail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_deck.add_child(_sail)

## The node a rider is seated on: the DECK, so he heels with the boat.
func deck() -> Node3D:
	return _deck

func forward() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))

func right() -> Vector3:
	var f := forward()
	return Vector3(f.z, 0.0, -f.x)

func speed() -> float:
	return velocity.dot(forward())

func flat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)

## Puts the yacht down at `at` facing `yaw`, stopped. Refuses a point it
## may not drive on and uses its park instead -- which is what turns a
## save written before this lot (a yacht left on the karting grid) into a
## yacht at its park rather than a yacht that cannot move.
func place(at: Vector3, yaw: float) -> void:
	var flat := Vector3(at.x, 0.0, at.z)
	global_position = flat
	rotation.y = yaw
	velocity = Vector3.ZERO
	_last_velocity = Vector3.ZERO
	_heel = 0.0
	_prev = flat
	_apply_deck()

## One physics step, driven by `input`. `wind` is the weather's factor on
## the pace (HubTransport.yacht_speed_factor()). The caller writes the
## rider immediately after, in the same call (carrier-then-carried).
func drive(delta: float, input: KartInput, wind: float) -> void:
	_motion.max_speed = BASE_SPEED * wind
	_on_sand = drivable(flat_position())
	var out: Dictionary = _motion.step(flat_position(), rotation.y, velocity, delta, input,
		_on_sand, WORLD_FENCE, KartTuning.steer_rate() * STEER_RATIO)
	rotation.y = float(out["yaw"])
	velocity = out["velocity"]
	global_position = _wall(out["position"] as Vector3)
	_prev = flat_position()
	_animate(delta)
	_last_velocity = velocity

## The wall. Three attempts, in order, and the order is what was MEASURED
## to matter:
##
##  1. the whole move, if it lands on drivable ground;
##  2. the x half or the z half alone -- but ONLY the half that actually
##     moves. This is the axis-separated slide that makes a rectangle
##     boundary something the yacht runs along instead of into, and it
##     covers every region edge on this map;
##  3. otherwise a BOUNCE: the velocity is reversed and scaled, and the
##     yacht stays where it was.
##
## ⚠️ STEP 3 EXISTS BECAUSE THE FIRST VERSION LOCKED THE VEHICLE UP, and
## CoveProbe found it in the first run. Driving due east across the moor
## the yacht met the windmill's hole head on. The x half was refused (it
## is the way into the hole); the z half was "drivable" -- because with a
## due-east heading the z half MOVES NOTHING, so it is the point the yacht
## already occupies -- and it was accepted with velocity.x zeroed. From
## then on the yacht sat at zero speed against the obstacle FOREVER: the
## driving model gives no yaw authority at zero speed (a parked vehicle
## does not pivot, VehicleDrive's `ratio`), and the automatic throttle
## pushed it back into the wall every frame. A player would have had to
## step off and walk.
##
## So a half-move is only accepted when it is a MOVE, and a refusal that
## leaves nowhere to go bounces instead of stopping: the yacht comes off
## the obstacle at WALL_BOUNCE of its speed, which is enough to keep the
## steering alive while the player turns away. It reads like nudging a
## rock, which is what it is.
const WALL_BOUNCE: float = 0.45
const WALL_EPSILON: float = 0.0005

func _wall(wanted: Vector3) -> Vector3:
	if drivable(wanted):
		return wanted
	var step: Vector3 = wanted - _prev
	if absf(step.x) > WALL_EPSILON:
		var only_x := Vector3(wanted.x, 0.0, _prev.z)
		if drivable(only_x):
			velocity.z = 0.0
			return only_x
	if absf(step.z) > WALL_EPSILON:
		var only_z := Vector3(_prev.x, 0.0, wanted.z)
		if drivable(only_z):
			velocity.x = 0.0
			return only_z
	velocity = -velocity * WALL_BOUNCE
	return _prev

## ---- the body ----------------------------------------------------------

func _animate(delta: float) -> void:
	_time += delta
	var accel: Vector3 = (velocity - _last_velocity) / maxf(delta, 0.0001)
	var lat_a: float = accel.dot(right())
	# AWAY from the turn: the sail is pushed over, the windward runner
	# lifts. The kart leans the other way; that is the read.
	var want: float = clampf(-lat_a * HEEL_DEG_PER_ACCEL, -HEEL_MAX_DEG, HEEL_MAX_DEG)
	_heel = lerpf(_heel, want, 1.0 - exp(-HEEL_LAMBDA * delta))
	_apply_deck()

func _apply_deck() -> void:
	if _deck == null:
		return
	_deck.rotation_degrees = Vector3(0.0, 0.0, _heel)

## The sail's own life: it leans with the wind and flutters. Called by the
## owner every frame, driven or parked, so a yacht seen from across the
## cove is alive.
func breathe(wind: float, t: float) -> void:
	if _sail == null:
		return
	_sail.rotation.z = deg_to_rad(-7.0 * wind) * (0.75 + 0.25 * sin(t * 2.3))
