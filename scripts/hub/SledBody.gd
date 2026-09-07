extends Node3D
class_name SledBody
## CH41 -- THE ELECTRIC SLED, and the first vehicle on this map that
## drives on a SURFACE rather than on the y = 0 plane.
##
## =====================================================================
## IT IS A VEHICLE, NOT A DESCENT
##
## Mathieu's direction, and it is the whole shape of the lot: this is not
## a ride down a hill on rails. It is a fourth vehicle, tapped, mounted
## and driven exactly like the kart and the sand yacht -- held finger,
## direction under the thumb, free to go anywhere on the map -- whose only
## difference is that A SLOPE PUSHES IT. It is parked at the summit of the
## west ridge because that is where a sled belongs, not because the ridge
## is a track.
##
## Everything that makes it drive on the ground is in SurfaceDrive (the
## composite CH35 Q2-B recommended): this file owns the numbers, the body
## and the wall, which is exactly the division SandYacht already has with
## VehicleDrive. Nothing about the kart, the sand yacht or the sailboat
## changes -- they keep VehicleDrive directly, on ground that is flat
## under all three of them.
##
## =====================================================================
## THE VERROU, AND THE ROAD NOT TAKEN
##
## VehicleDrive pulls a speed above `max_speed` back toward it. CH35 Q2
## named that the one legitimate reason to open VehicleDrive.gd, and it
## turned out not to be needed: the pull is a DAMPING at off_lambda, so a
## constant slope acceleration `a` settles at max_speed + a/off_lambda,
## and `max_speed` is a plain instance variable that this file raises with
## the grade every frame (SailBoat already modulates it for the wind).
## Both knobs are below, both are measured by SledProbe, and
## VehicleDrive.gd is not touched. See docs/lots/CH41_LUGE.md for the
## numbers that closed the question.
##
## =====================================================================
## FEELING CONSTANTS -- ALL OF THEM, HERE, IN ONE BLOCK
##
## These are the ones Mathieu tunes after an iPhone run. They are grouped
## and named so that "the sled is too slow downhill" is one line to find,
## not a hunt through a driving model shared with three other vehicles.

## ---- pace ---------------------------------------------------------------
## Top speed the MOTOR alone reaches, on flat ground. Between the sand
## yacht's 10.67 and a walk: an electric sled is a stroll with a hill
## bonus, not a kart.
const MAX_SPEED_FLAT: float = 8.5
## Top speed the ceiling is raised to on the steepest descent. The gap
## between the two IS the "la pente accelere NETTEMENT" the brief asks
## for: 2.6x the motor's own pace.
const MAX_SPEED_DOWNHILL: float = 22.0
## The downhill grade (fall per unit travelled) at which the ceiling has
## fully risen. 0.45 is just under the ridge's steepest walkable slope
## (tan 27.834 deg = 0.528), so the steepest flank reaches the full cap
## and everything shallower gets a proportion of it.
const GRADE_FOR_FULL_CAP: float = 0.45
## How much of the slope's true gravity is injected as a force. Above 1.0
## on purpose: the west ridge is 4.5 u tall and a real 4.5 u hill is a
## gentle thing. The brief forbids deforming the relief, so the hill is
## made to FEEL like a hill here instead of being made bigger.
const SLOPE_GAIN: float = 2.6
## Off the drivable set it is slowed, not punished (the kart's rule).
## Today the wall means this is never reached.
const OFF_SPEED: float = 3.4
const REVERSE_SPEED: float = 2.2
## Thumb up the screen (the kart's boost gesture) buys 15 %.
const BOOST_RATIO: float = 1.15

## ---- how speed is gained and lost ---------------------------------------
## An electric motor pulls promptly, and a sled on runners keeps what it
## has: COAST is slower than any other vehicle here, and OVER (the pull
## back toward the ceiling) is slower than the kart's 1.6 so that speed
## stolen from a hill is given back over a long flat run instead of being
## erased at the bottom of it.
##
## ⚠️ ACCEL_LAMBDA IS NOT FREE TO MOVE: SEE climb_authority() BELOW.
## 1.6 is high for this repo (the kart is 0.85, the sail 0.55) and it is
## the vehicle's identity -- an electric motor delivers its pull from a
## standstill -- but it is ALSO the term that decides whether this thing
## can climb its own hill. It was 0.90 for exactly one probe run, and
## SledProbe PHASE E measured the sled FROZEN at 0.000 u/s facing up the
## steepest flank: the slope pushed it backwards, VehicleDrive's
## "reversing and the throttle comes back" branch pulled it to exactly
## zero, and at zero speed that model gives no yaw authority at all. A
## player would have had to step off and walk -- the sand yacht's own
## lock-up, arrived at from the other side.
const ACCEL_LAMBDA: float = 1.6
const COAST_LAMBDA: float = 0.18
const OVER_LAMBDA: float = 1.10
const BRAKE_DECEL: float = 12.0

## ⚠️ THE ONE RELATION BETWEEN THESE CONSTANTS, and breaking it is a
## LOCK-UP and not a slower climb.
##
## At a standstill the model raises v_fwd by lerpf(0, cap, 1 - exp(-lambda
## dt)), so the acceleration it can offer from rest is cap * ACCEL_LAMBDA.
## The slope pushes back with SLOPE_GAIN * g sin(theta) cos(theta). If the
## second is the larger, the sled cannot leave a standstill facing uphill
## -- and it does not creep backwards either, it sits at exactly zero with
## no steering.
##
## So the two are published as functions and SledProbe gates the
## inequality on the steepest slope the surface actually has. A tuning
## pass that raises SLOPE_GAIN past this fails loudly instead of shipping
## a hill the sled can be trapped on.
static func climb_authority() -> float:
	return MAX_SPEED_FLAT * ACCEL_LAMBDA

## The slope force, in u/s^2, on ground tilted by `gradient` (dh/dx, dh/dz).
## Reads SurfaceDrive rather than restating its formula: one publisher.
static func slope_force(gradient: Vector2) -> float:
	var denom: float = 1.0 + gradient.x * gradient.x + gradient.y * gradient.y
	return SLOPE_GAIN * SurfaceDrive.GRAVITY * gradient.length() / denom

## ---- friction and steering ----------------------------------------------
## Runners hold less than tyres and scrub less than sand: it slides wide
## and keeps its pace through the slide. That is the character.
const GRIP_ON: float = 3.6
const GRIP_OFF: float = 1.8
const SCRUB: float = 0.32
## The steering RATE is the live KartTuning preset times this, the sand
## yacht's rule: the 8/7/6 knob Mathieu validated on his own thumb moves
## every vehicle together.
const STEER_RATIO: float = 0.92
const STEER_FULL_SPEED: float = 3.0
const STEER_HIGH_SPEED_KEEP: float = 0.60

## ---- the body -----------------------------------------------------------
## Where his feet stand: the top of the deck slab, which is where DECK_TOP
## puts it. Authored ONCE and republished by HubTransport, never retyped.
const SEAT_Y: float = 0.28
const SEAT: Vector3 = Vector3(0.0, SEAT_Y, 0.0)
## How fast the chassis settles onto the ground's normal, 1/s.
##
## ⚠️ IT MUST BE SMOOTHED AND HubSurface SAYS WHY: the normal it publishes
## is the DRAWN TRIANGLE's, exact and therefore FACETED, and adjacent
## triangles on the ridge differ by up to 11.168 deg -- MEASURED off the
## grid by SledProbe, not the ~6 deg a raised cosine predicts on paper.
## Written straight into the chassis it would snap once per metre. The geometry stays exact; the
## body lags it, the way SandYacht's heel lags its lateral acceleration.
const CHASSIS_LAMBDA: float = 7.0
## A rectangle wide enough to contain every region rectangle, so
## VehicleDrive's own fence never bites and _wall() below is the only
## thing that stops this vehicle (SandYacht.WORLD_FENCE's reasoning, and
## its numbers, read rather than retyped).
const WORLD_FENCE: Rect2 = SandYacht.WORLD_FENCE
## The wall's bounce and the "did this half actually move" epsilon --
## SandYacht's, for the reason its docblock gives at length: a half-move
## that moves nothing is the lock-up CoveProbe found on the first run.
const WALL_BOUNCE: float = 0.45
const WALL_EPSILON: float = 0.0005

## ---- the mesh -----------------------------------------------------------
## PROCEDURAL, because the brief forbids generating an asset and the
## inventory holds nothing sled-shaped (the nearest are deckchair_0 and
## driftwood_0, and neither is one). Four boxes, 48 triangles, built with
## the winding Godot calls front -- see _quad().
const RUNNER_HALF_X: Array[float] = [-0.46, -0.32, 0.32, 0.46]
const RUNNER_BACK_Z: float = -1.05
const RUNNER_NOSE_Z: float = 1.10
const RUNNER_BOTTOM_Y: float = 0.02
const RUNNER_TOP_Y: float = 0.16
## The nose is lifted, which is the one line of the silhouette that says
## "sled" rather than "crate on sticks".
const RUNNER_NOSE_LIFT: float = 0.18
const DECK_LO: Vector3 = Vector3(-0.52, 0.16, -0.92)
const DECK_HI: Vector3 = Vector3(0.52, SEAT_Y, 0.72)
const POD_LO: Vector3 = Vector3(-0.30, SEAT_Y, 0.38)
const POD_HI: Vector3 = Vector3(0.30, 0.54, 0.70)
const BACK_LO: Vector3 = Vector3(-0.46, SEAT_Y, -0.98)
const BACK_HI: Vector3 = Vector3(0.46, 0.86, -0.86)
## Cream body, red runners and motor pod. The cream is the large surface
## on purpose: it is the half of the silhouette that carries against an
## unlit hillside, and the red is the character.
const BODY_COLOUR: Color = Color(0.96, 0.95, 0.90)
const TRIM_COLOUR: Color = Color(0.86, 0.28, 0.24)
## How the mesh is GROUPED, published because a reader cannot recover it
## and a reader that guesses gets the wrong answer.
##
## ⚠️ SledProbe's first version tested the winding against the whole
## sled's centre of mass and reported 46 of 60 triangles wrong -- on a
## mesh the render proved correct at the pixel (cull_back and
## cull_disabled covered the same 13 190 pixels). The test was wrong, not
## the mesh: five boxes side by side are NOT a convex body, so "outward"
## is not "away from the middle" -- the deck's underside and the runners'
## inner flanks all point back toward it. Each PIECE is convex; the
## assembly is not. So the pieces are emitted in order, PIECE_TRIS each,
## and the probe tests each one against ITS OWN centre.
const PIECE_TRIS: int = 12
const PIECE_COUNT: int = 5

var velocity: Vector3 = Vector3.ZERO

var _chassis: Node3D = null
var _drive: SurfaceDrive = null
var _normal: Vector3 = Vector3.UP
var _prev: Vector3 = Vector3.ZERO
var _on_ground: bool = true
## Last frame's readings, published for SledProbe rather than recomputed
## there -- one publisher, CLAUDE.md's rule.
var _grade: float = 0.0
var _cap: float = MAX_SPEED_FLAT

## Where a land vehicle may drive. READ off SandYacht rather than
## restated: "the region minus the karting circuit and its corridor" is
## one fact and it already has a publisher. A sled on the starting grid
## when the lights go out is the same bug the yacht's lot closed.
static func drivable(point: Vector3) -> bool:
	return SandYacht.drivable(point)

func _ready() -> void:
	_drive = SurfaceDrive.new()
	_drive.slope_gain = SLOPE_GAIN
	var m: VehicleDrive = _drive.motion
	m.max_speed = MAX_SPEED_FLAT
	m.max_speed_off = OFF_SPEED
	m.reverse_speed = REVERSE_SPEED
	m.boost_speed_ratio = BOOST_RATIO
	m.accel_lambda = ACCEL_LAMBDA
	m.coast_lambda = COAST_LAMBDA
	m.off_lambda = OVER_LAMBDA
	m.brake_decel = BRAKE_DECEL
	m.steer_full_speed = STEER_FULL_SPEED
	m.steer_high_speed_keep = STEER_HIGH_SPEED_KEEP
	m.grip_on = GRIP_ON
	m.grip_off = GRIP_OFF
	m.scrub = SCRUB
	_prev = flat_position()

## Builds the sled under a TILTING chassis. The root carries position and
## yaw (what the driving model writes); the chassis carries the ground's
## normal, and the rider is seated on the CHASSIS so he leans with the
## hill exactly as he heels with the yacht's deck.
func build() -> void:
	_chassis = Node3D.new()
	_chassis.name = "Chassis"
	add_child(_chassis)
	var body := MeshInstance3D.new()
	body.name = "Hull"
	body.mesh = build_mesh()
	body.material_override = CozyPalette.decor_material()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chassis.add_child(body)

## The node a rider is seated on: the CHASSIS, so he tilts with the hill.
func deck() -> Node3D:
	return _chassis

func forward() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))

func right() -> Vector3:
	var f := forward()
	return Vector3(f.z, 0.0, -f.x)

func speed() -> float:
	return velocity.dot(forward())

func flat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)

## The ground's normal as of the last drive(), for SledProbe.
func surface_normal() -> Vector3:
	return _normal

## The slope gain actually in force on this instance. Published because a
## probe that pins ONE of the two downhill mechanisms has to leave the
## OTHER exactly as the vehicle has it -- reading the SLOPE_GAIN constant
## instead let a red pass disagree with the vehicle it was measuring.
func slope_gain() -> float:
	return _drive.slope_gain

## The downhill grade along the heading as of the last drive(): positive
## descending. For SledProbe and for the report.
func grade() -> float:
	return _grade

## The speed ceiling the grade bought this frame -- the verrou's answer,
## published so a probe reads it instead of recomputing the lerp.
func speed_cap() -> float:
	return _cap

## Puts the sled down at `at` facing `yaw`, stopped, ON THE GROUND. The
## y of `at` is IGNORED: the surface says where the ground is, and a
## caller that passed its own would be a second spelling of it.
func place(at: Vector3, yaw: float) -> void:
	var flat := Vector3(at.x, 0.0, at.z)
	global_position = HubSurface.ground(flat)
	rotation.y = yaw
	velocity = Vector3.ZERO
	_prev = flat
	_normal = HubSurface.normal_at(flat)
	_grade = 0.0
	_cap = MAX_SPEED_FLAT
	_apply_chassis()

## One physics step, driven by `input`. The caller writes the rider
## immediately after, in the same call (carrier-then-carried).
func drive(delta: float, input: KartInput) -> void:
	# ---- THE VERROU, and it is these three lines. The ceiling is raised
	# with the grade BEFORE the step, so the damping inside VehicleDrive
	# pulls toward a downhill number instead of toward the motor's own.
	# Read through SurfaceDrive's published accessor: the ground is
	# differentiated once, by HubSurface, and never here.
	_grade = SurfaceDrive.grade_at(flat_position(), rotation.y)
	var lean: float = clampf(_grade / GRADE_FOR_FULL_CAP, 0.0, 1.0)
	_cap = lerpf(MAX_SPEED_FLAT, MAX_SPEED_DOWNHILL, lean)
	_drive.motion.max_speed = _cap
	_on_ground = drivable(flat_position())
	var out: Dictionary = _drive.step(flat_position(), rotation.y, velocity, delta, input,
		_on_ground, WORLD_FENCE, KartTuning.steer_rate() * STEER_RATIO)
	rotation.y = float(out["yaw"])
	velocity = out["velocity"]
	global_position = _wall(out["position"] as Vector3)
	_prev = flat_position()
	_animate(delta)

## SandYacht._wall(), and deliberately the same three attempts in the same
## order -- see its docblock for why step 3 exists. The one difference is
## that a refusal keeps the vehicle's own GROUND height rather than y = 0,
## because `_prev` here is flat and the node is not.
func _wall(wanted: Vector3) -> Vector3:
	var flat := Vector3(wanted.x, 0.0, wanted.z)
	if drivable(flat):
		return wanted
	var step: Vector3 = flat - _prev
	if absf(step.x) > WALL_EPSILON:
		var only_x := Vector3(flat.x, 0.0, _prev.z)
		if drivable(only_x):
			velocity.z = 0.0
			return HubSurface.ground(only_x)
	if absf(step.z) > WALL_EPSILON:
		var only_z := Vector3(_prev.x, 0.0, flat.z)
		if drivable(only_z):
			velocity.x = 0.0
			return HubSurface.ground(only_z)
	velocity = -velocity * WALL_BOUNCE
	return HubSurface.ground(_prev)

## ---- the chassis --------------------------------------------------------

## The target is read under where the body ACTUALLY ENDED, after the wall
## -- not `_drive.normal`, which is the ground under where the step wanted
## to put it. The two are the same frame after frame and differ exactly
## when a wall refusal moved it back, which is the one frame a chassis
## leaning on the wrong hillside would be visible.
func _animate(delta: float) -> void:
	var want: Vector3 = HubSurface.normal_at(flat_position())
	_normal = _normal.lerp(want, 1.0 - exp(-CHASSIS_LAMBDA * delta)).normalized()
	_apply_chassis()

## Writes the chassis basis from the (smoothed) world normal.
##
## The root is a pure yaw, so its local +Z is the heading and its local +X
## is right() -- which is why the normal only has to be turned into the
## root's frame and never into anything else. The basis is BUILT from the
## up vector rather than composed from a pitch and a roll: two Euler
## angles taken from a normal disagree with it by their own cross term,
## and "the chassis is on the normal" is the assertion SledProbe gates.
func _apply_chassis() -> void:
	if _chassis == null:
		return
	var up: Vector3 = global_transform.basis.inverse() * _normal
	if up.length_squared() < 0.0001:
		up = Vector3.UP
	up = up.normalized()
	var ahead := Vector3(0.0, 0.0, 1.0)
	var z_axis: Vector3 = ahead - up * up.dot(ahead)
	if z_axis.length_squared() < 0.0001:
		z_axis = Vector3(0.0, 0.0, 1.0)
	z_axis = z_axis.normalized()
	_chassis.transform.basis = Basis(up.cross(z_axis), up, z_axis)

## ---- the mesh -----------------------------------------------------------

## Two runners with lifted noses, a deck slab, a motor pod and a seat
## back. 48 triangles, no texture, vertex colours read straight by the
## decor shader's COLOR.
static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0, 2]:
		var x0: float = RUNNER_HALF_X[i]
		var x1: float = RUNNER_HALF_X[i + 1]
		var lift: float = RUNNER_NOSE_LIFT
		_hexa(st, [
			Vector3(x0, RUNNER_BOTTOM_Y, RUNNER_BACK_Z),
			Vector3(x1, RUNNER_BOTTOM_Y, RUNNER_BACK_Z),
			Vector3(x1, RUNNER_BOTTOM_Y + lift, RUNNER_NOSE_Z),
			Vector3(x0, RUNNER_BOTTOM_Y + lift, RUNNER_NOSE_Z),
			Vector3(x0, RUNNER_TOP_Y, RUNNER_BACK_Z),
			Vector3(x1, RUNNER_TOP_Y, RUNNER_BACK_Z),
			Vector3(x1, RUNNER_TOP_Y + lift, RUNNER_NOSE_Z),
			Vector3(x0, RUNNER_TOP_Y + lift, RUNNER_NOSE_Z),
		], TRIM_COLOUR)
	_box(st, DECK_LO, DECK_HI, BODY_COLOUR)
	_box(st, POD_LO, POD_HI, TRIM_COLOUR)
	_box(st, BACK_LO, BACK_HI, BODY_COLOUR)
	return st.commit()

static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, colour: Color) -> void:
	_hexa(st, [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z),
		Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z),
		Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z),
	], colour)

## Six quads from eight corners: 0-3 the bottom ring (-x-z, +x-z, +x+z,
## -x+z) and 4-7 the top ring in the same order. The corners may be
## SHEARED (the runners' noses are), so each face's outward direction is
## given as a hint and the exact normal is taken from the emitted triangle.
static func _hexa(st: SurfaceTool, v: Array, colour: Color) -> void:
	_quad(st, v[0], v[3], v[2], v[1], Vector3.DOWN, colour)
	_quad(st, v[4], v[5], v[6], v[7], Vector3.UP, colour)
	_quad(st, v[0], v[1], v[5], v[4], Vector3(0.0, 0.0, -1.0), colour)
	_quad(st, v[3], v[7], v[6], v[2], Vector3(0.0, 0.0, 1.0), colour)
	_quad(st, v[0], v[4], v[7], v[3], Vector3.LEFT, colour)
	_quad(st, v[1], v[2], v[6], v[5], Vector3.RIGHT, colour)

## ⚠️ THE WINDING, AND CH39 IS WHY IT IS DECIDED HERE AND NOT BY HAND.
##
## Godot takes CLOCKWISE-ON-SCREEN for the front face, so a triangle whose
## RIGHT-HAND cross product points AT the eye is the BACK one. For a
## closed body that means the right-hand normal of every visible face
## points INTO the solid -- the same sign HubMountain had to be corrected
## to, after the whole west ridge shipped invisible with no error of any
## kind.
##
## So this function is handed the OUTWARD direction and emits whichever of
## the two orders puts the right-hand normal AGAINST it. Getting it
## backwards is then not possible, and SledProbe re-reads the committed
## mesh to prove it rather than trusting this comment. (The decor shader
## is `cull_disabled`, so a wrong winding would not even be visible in the
## sandbox -- which is exactly the trap, and exactly why the probe renders
## the sled through a `cull_back` material as well.)
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		outward: Vector3, colour: Color) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		_tri(st, a, d, c, colour)
		_tri(st, a, c, b, colour)
	else:
		_tri(st, a, b, c, colour)
		_tri(st, a, c, d, colour)

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	# The emitted winding puts the right-hand normal INSIDE, so the normal
	# the shader wants -- the outward one -- is its negation.
	var n: Vector3 = -(b - a).cross(c - a).normalized()
	for p in [a, b, c]:
		st.set_color(colour)
		st.set_normal(n)
		st.add_vertex(p)
