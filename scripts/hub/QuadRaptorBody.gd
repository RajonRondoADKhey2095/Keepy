extends Node3D
class_name QuadRaptorBody
## CH79 -- THE QUAD RAPTOR, the hub's fifth driven vehicle and its first
## MOUNT: a four-legged animal Keepy rides, driven frame by frame by a
## held finger.
##
## =====================================================================
## IT IS THE SLED'S SHAPE, AND DELIBERATELY NOT A NEW ONE
##
## CLAUDE.md's brief for this lot is explicit: reuse the continuous
## control pattern that exists rather than invent a cleaner one. So this
## file is SledBody.gd's division of labour, member for member:
##
##   * SurfaceDrive owns the kinematics AND the ground query (CH41's
##     composite, which its own docblock says is adopted by the NEW
##     vehicle -- this is that vehicle);
##   * VehicleDrive underneath it is the same model the kart, the sand
##     yacht, the sailboat and the sled are driven by, configured here
##     with this animal's own numbers and nothing else;
##   * KartTouchInput is the writer, unchanged -- one finger, anchor,
##     left/right steers, up is pace and down is the gear;
##   * the rider is ON_CARRIER through mount_carrier(), so every other
##     hub branch refuses him by STATE and there is no second flag;
##   * the chase camera is ChaseTuning.vehicle(), the default the other
##     four already take;
##   * HubTransport owns the door (mount, drive, exit) exactly as it owns
##     the sled's.
##
## What is NOT reused is what a MOUNT is not a sled about: this thing has
## legs, so it is far less pushed around by a hill (SLOPE_GAIN) and it
## holds its line (GRIP_ON above every wheeled vehicle here).
##
## =====================================================================
## WHERE IT MAY GO
##
## `drivable()` READS SandYacht's, which is the published predicate all
## three free-roaming land vehicles already share -- "the walkable region
## minus the karting circuit". A second spelling of that set is exactly
## the defect CLAUDE.md's "un fait est publie une fois" section exists to
## refuse, and a mount on the starting grid when the lights go out is the
## bug the yacht's lot closed.
##
## The region is NOT convex, and this vehicle does not use the pedestrian
## router (a driven vehicle has no destination to route to). `_wall()` is
## SandYacht's axis-separated slide, three attempts in the same order --
## the same thing that has bounded the yacht, the sailboat and the sled
## since CH30, on the same ground.
##
## =====================================================================
## THE ASSET IS A PLACEHOLDER AND THE FILE SAYS SO
##
## Primitive boxes, vertex-coloured, drawn by the decor material -- unlit
## like everything else on this map, so the colours below ARE the colours
## that show. It will be replaced by a Meshy asset in a later lot; nothing
## in the mechanics above reads the mesh, so that replacement is a change
## to `build_mesh()` and to the four leg boxes and to nothing else.

## ---- pace ---------------------------------------------------------------
## ⚠️ DERIVED FROM THE WALK, NOT TYPED. CH54's skate cruise is documented
## as "x1.87 the walk", and the walk is HOP_DISTANCE / HOP_DURATION --
## which means the ratio is the fact and the u/s is the consequence. A
## lot that ever retunes the hop then moves this with it instead of
## leaving a stale number behind.
const WALK_PACE: float = KeepyHopper.HOP_DISTANCE / KeepyHopper.HOP_DURATION
## ⚠️ AND THE RATIO ITSELF IS A FEEL NUMBER -- said plainly, because
## CH70 is the lot where a taste constant had silently become a floor
## somebody else stood on. Nothing derives a contract from this today:
## 2.2 puts the mount above the sand yacht (1.99) and below the circuit
## kart (2.43), so the fastest thing on the plateau is a mount and the
## fastest thing in the game is still the kart on its track.
const PACE_RATIO: float = 2.2
const MAX_SPEED_FLAT: float = WALK_PACE * PACE_RATIO
## Off the drivable set. Never reached today -- `_wall()` refuses the step
## before the model ever runs off-surface -- and kept for the same reason
## the sled keeps its own: the day a lot widens the drivable set past the
## wall, a vehicle that had no off-surface pace would simply stop.
const OFF_SPEED: float = 3.6
const REVERSE_SPEED: float = 2.5
## u/s^2. Above the sand yacht's ramp because an animal that backs up
## does it with the same legs it runs with; gated against the steepest
## slope by `reverse_authority()` below, the sled's own relation.
const REVERSE_ACCEL: float = 9.0
## Thumb up the screen: a sprint, and the widest boost on the map (the
## kart takes 1.0, the sled 1.15). It is the one thing a mount does that
## a machine does not.
const BOOST_RATIO: float = 1.25

## ---- how speed is gained and lost ---------------------------------------
## Legs leave from a standstill promptly and stop promptly: ACCEL is the
## sled's, COAST is far quicker than any rolling vehicle here (nothing
## free-wheels), and OVER is the kart's.
##
## ⚠️ ACCEL_LAMBDA IS NOT FREE TO MOVE -- `climb_authority()` below is the
## relation, and it is the sled's for the sled's measured reason: below
## it, a mount facing uphill sits at exactly 0.000 u/s with no steering.
const ACCEL_LAMBDA: float = 1.6
const COAST_LAMBDA: float = 0.90
const OVER_LAMBDA: float = 1.60
const BRAKE_DECEL: float = 14.0

## ---- the hill -----------------------------------------------------------
## How much of the slope's true gravity is injected as a force. WELL BELOW
## the sled's 2.6, and that is the whole difference between the two: a
## sled is a thing gravity drives, an animal is a thing that walks up.
## Not zero, because a mount that felt nothing on a hillside would make
## the relief free.
const SLOPE_GAIN: float = 0.55
## The downhill grade at which the ceiling has fully risen, and how far it
## rises. A run downhill is quicker, not a plunge: 1.25x, against the
## sled's 2.6x.
const GRADE_FOR_FULL_CAP: float = 0.45
const MAX_SPEED_DOWNHILL: float = MAX_SPEED_FLAT * 1.25

## ---- friction and steering ----------------------------------------------
## Claws, so it holds: GRIP_ON is above every wheeled vehicle on this map
## (the kart's 5.0, the sled's 3.6). It does not drift, and that is the
## character.
const GRIP_ON: float = 6.5
const GRIP_OFF: float = 1.8
const SCRUB: float = 0.60
## The steering RATE is the live KartTuning preset times this -- the sand
## yacht's rule, so the 8/7/6 knob Mathieu validated on his own thumb
## moves every vehicle together. Above 1 because a mount pivots.
const STEER_RATIO: float = 1.05
## It turns well at a walk, which a kart does not.
const STEER_FULL_SPEED: float = 2.4
const STEER_HIGH_SPEED_KEEP: float = 0.70

## ⚠️ THE ONE RELATION BETWEEN THESE CONSTANTS, and breaking it is a
## LOCK-UP and not a slower climb. SledBody's docblock states it at
## length; it is restated as CODE here and not as prose, so QuadProbe
## gates the inequality on the steepest ground the surface actually has.
static func climb_authority() -> float:
	return MAX_SPEED_FLAT * ACCEL_LAMBDA

static func reverse_authority() -> float:
	return REVERSE_ACCEL

## The slope force, u/s^2, on ground tilted by `gradient`. Reads
## SurfaceDrive's constant rather than restating 9.81: one publisher.
static func slope_force(gradient: Vector2) -> float:
	var denom: float = 1.0 + gradient.x * gradient.x + gradient.y * gradient.y
	return SLOPE_GAIN * SurfaceDrive.GRAVITY * gradient.length() / denom

## ---- the body -----------------------------------------------------------
## Where his feet stand: the top of the saddle. Authored ONCE here and
## republished by HubTransport, never retyped.
const SEAT_Y: float = 1.06
const SEAT: Vector3 = Vector3(0.0, SEAT_Y, 0.0)
## How fast the chassis settles onto the ground's normal, 1/s. The sled's,
## for the sled's measured reason: HubSurface publishes the DRAWN
## triangle's normal, which is faceted, and a body written straight onto
## it snaps once per metre.
const CHASSIS_LAMBDA: float = 7.0
## A rectangle wide enough to contain every region rectangle, so
## VehicleDrive's own fence never bites and `_wall()` is the only thing
## that stops this vehicle. SandYacht's, read rather than retyped.
const WORLD_FENCE: Rect2 = SandYacht.WORLD_FENCE
const WALL_BOUNCE: float = 0.45
const WALL_EPSILON: float = 0.0005

## ---- the mesh -----------------------------------------------------------
## PLACEHOLDER. Ten boxes: body, neck, head, two tail segments, saddle,
## and four legs -- the legs as separate NODES because they swing.
##
## The silhouette is the point, not the anatomy: a long low body, a neck
## that rises, a tail that counterweights it, and four legs under it. On
## an unlit map with no shading on a flank (CH35-C), that outline is the
## only thing that says "animal" rather than "crate", which is why the
## tail and the neck are here at all in a placeholder.
const BODY_LO: Vector3 = Vector3(-0.42, 0.52, -0.70)
const BODY_HI: Vector3 = Vector3(0.42, 1.00, 0.62)
const NECK_LO: Vector3 = Vector3(-0.24, 0.86, 0.52)
const NECK_HI: Vector3 = Vector3(0.24, 1.46, 0.94)
const HEAD_LO: Vector3 = Vector3(-0.22, 1.24, 0.88)
const HEAD_HI: Vector3 = Vector3(0.22, 1.60, 1.44)
const SNOUT_LO: Vector3 = Vector3(-0.15, 1.26, 1.40)
const SNOUT_HI: Vector3 = Vector3(0.15, 1.44, 1.76)
const TAIL1_LO: Vector3 = Vector3(-0.26, 0.68, -1.28)
const TAIL1_HI: Vector3 = Vector3(0.26, 1.00, -0.64)
const TAIL2_LO: Vector3 = Vector3(-0.13, 0.74, -1.88)
const TAIL2_HI: Vector3 = Vector3(0.13, 0.96, -1.24)
## The saddle, and SEAT_Y is its top -- one number, not two.
const SADDLE_LO: Vector3 = Vector3(-0.34, 0.98, -0.36)
const SADDLE_HI: Vector3 = Vector3(0.34, SEAT_Y, 0.30)
## A leg, in ITS OWN frame: the pivot is the hip, so the box hangs below
## the origin and the swing is a rotation about local X.
const LEG_LO: Vector3 = Vector3(-0.11, -0.60, -0.13)
const LEG_HI: Vector3 = Vector3(0.11, 0.02, 0.13)
## Where the four hips sit on the body, in the vehicle's own frame.
const HIPS: Array[Vector3] = [
	Vector3(-0.34, 0.62, 0.40), Vector3(0.34, 0.62, 0.40),
	Vector3(-0.34, 0.62, -0.44), Vector3(0.34, 0.62, -0.44),
]
## Diagonal pairs move together, which is what a four-legged trot is.
const LEG_PHASE: Array[float] = [0.0, PI, PI, 0.0]
## ⚠️ THE GAIT IS DRIVEN BY DISTANCE TRAVELLED, NOT BY TIME. A placeholder
## whose legs paddle while it stands still reads as a bug, and one whose
## legs turn at a fixed rate while the body accelerates reads as a slide.
## Radians of swing per unit travelled, and the amplitude it swings to.
const GAIT_RADS_PER_U: float = 1.25
const GAIT_AMPLITUDE: float = 0.55

## Teal body, warm ochre saddle and legs. ⚠️ CHOSEN AGAINST THE GROUND,
## not for prettiness: the hub's ground renders at L 0.0799 and its grass
## bands are mid greens, so a green mount would be a silhouette with no
## edge on the one surface it always stands on. Teal keeps a hue distance
## from the grass while staying in the cozy register, and the ochre breaks
## the mass so the legs read against the body.
const BODY_COLOUR: Color = Color(0.24, 0.58, 0.62)
const TRIM_COLOUR: Color = Color(0.90, 0.62, 0.28)

## How the HULL mesh is GROUPED -- published because a reader cannot
## recover it and a reader that guesses gets the wrong answer. SledBody's
## docblock is the long form: five boxes side by side are NOT a convex
## body, so a winding test against the whole centre of mass reports a
## correct mesh as broken. Each PIECE is convex; the assembly is not.
const PIECE_TRIS: int = 12
const HULL_PIECES: int = 7
const LEG_PIECES: int = 4

var velocity: Vector3 = Vector3.ZERO

var _chassis: Node3D = null
var _legs: Array[Node3D] = []
var _drive: SurfaceDrive = null
var _normal: Vector3 = Vector3.UP
var _prev: Vector3 = Vector3.ZERO
var _on_ground: bool = true
var _gait: float = 0.0
## Last frame's readings, published for QuadProbe rather than recomputed
## there -- one publisher.
var _grade: float = 0.0
var _cap: float = MAX_SPEED_FLAT

## Where a land vehicle may drive. READ off SandYacht rather than
## restated: "the region minus the karting circuit" is one fact and it
## already has a publisher.
static func drivable(point: Vector3) -> bool:
	return SandYacht.drivable(point)

func _ready() -> void:
	# CH46: on the minimap, as a vehicle. One line, at the site that builds
	# it -- the map enumerates the group and knows no path here.
	#
	# ⚠️ NO THUMBNAIL, and that is the SKATEBOARD's choice for the
	# skateboard's reason. A THUMBS row is a PORTRAIT baked off the built
	# world (CH48), so declaring one here would bake a picture of a
	# PLACEHOLDER and the Meshy lot would have to remember to re-bake it.
	# The abstract vehicle shape is correct until the real asset lands.
	MinimapMarkers.mark(self, MinimapMarkers.VEHICLE)
	_drive = SurfaceDrive.new()
	_drive.slope_gain = SLOPE_GAIN
	var m: VehicleDrive = _drive.motion
	m.max_speed = MAX_SPEED_FLAT
	m.max_speed_off = OFF_SPEED
	m.reverse_speed = REVERSE_SPEED
	m.reverse_accel = REVERSE_ACCEL
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

## Builds the animal under a TILTING chassis. The root carries position
## and yaw (what the driving model writes); the chassis carries the
## ground's normal, and the rider is seated on the CHASSIS so he leans
## with the hill exactly as he heels with the yacht's deck.
func build() -> void:
	_chassis = Node3D.new()
	_chassis.name = "Chassis"
	add_child(_chassis)
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = build_mesh()
	hull.material_override = CozyPalette.decor_material()
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chassis.add_child(hull)
	_legs.clear()
	for i in HIPS.size():
		var pivot := Node3D.new()
		pivot.name = "Leg%d" % i
		pivot.position = HIPS[i]
		_chassis.add_child(pivot)
		var limb := MeshInstance3D.new()
		limb.name = "Limb"
		limb.mesh = leg_mesh()
		limb.material_override = CozyPalette.decor_material()
		limb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(limb)
		_legs.append(pivot)

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

## The ground's normal as of the last drive(), for QuadProbe.
func surface_normal() -> Vector3:
	return _normal

## The slope gain actually in force on this instance. Published because a
## probe that pins ONE of the two downhill mechanisms has to leave the
## OTHER exactly as the vehicle has it.
func slope_gain() -> float:
	return _drive.slope_gain

## The downhill grade along the heading as of the last drive(): positive
## descending.
func grade() -> float:
	return _grade

## The speed ceiling the grade bought this frame.
func speed_cap() -> float:
	return _cap

## The gait's accumulated phase, radians. Published so the probe reads
## what the legs were WRITTEN from rather than re-deriving it.
func gait_phase() -> float:
	return _gait

## The swing of one leg as of the last frame, radians -- read off the NODE
## and not off `_gait`, so a probe that gates "the legs move" is looking at
## what is drawn and not at the variable that was meant to drive it.
func leg_pitch(index: int) -> float:
	if index < 0 or index >= _legs.size():
		return 0.0
	return _legs[index].rotation.x

## Triangles, both halves: the hull and the four legs. Published as TWO
## numbers because "the model is cheap" and "the scene is cheap" are not
## the same sentence.
func triangle_count() -> Array[int]:
	return [PIECE_TRIS * HULL_PIECES, PIECE_TRIS * LEG_PIECES]

## Puts the mount down at `at` facing `yaw`, stopped, ON THE GROUND. The
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
	_gait = 0.0
	_apply_chassis()
	_apply_legs()

## One physics step, driven by `input`. The caller writes the rider
## immediately after, in the same call (carrier-then-carried).
func drive(delta: float, input: KartInput) -> void:
	# The ceiling is raised with the grade BEFORE the step, so the damping
	# inside VehicleDrive pulls toward a downhill number instead of toward
	# the animal's own. Read through SurfaceDrive's published accessor: the
	# ground is differentiated once, by HubSurface, and never here.
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
	# ⚠️ THE GAIT IS ADVANCED ON THE DISTANCE ACTUALLY COVERED -- after the
	# wall, not before it. A mount held against a hedge has travelled zero
	# and its legs must say so.
	_gait += flat_position().distance_to(_prev) * GAIT_RADS_PER_U
	_prev = flat_position()
	_animate(delta)

## SandYacht._wall(), and deliberately the same three attempts in the same
## order -- see its docblock for why step 3 exists. The one difference is
## SledBody's: a refusal keeps the vehicle's own GROUND height rather than
## y = 0, because `_prev` here is flat and the node is not.
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

## ---- the chassis and the legs -------------------------------------------

## The target is read under where the body ACTUALLY ENDED, after the wall
## -- not `_drive.normal`, which is the ground under where the step wanted
## to put it.
func _animate(delta: float) -> void:
	var want: Vector3 = HubSurface.normal_at(flat_position())
	_normal = _normal.lerp(want, 1.0 - exp(-CHASSIS_LAMBDA * delta)).normalized()
	_apply_chassis()
	_apply_legs()

## Writes the chassis basis from the (smoothed) world normal. SledBody's,
## built from the up vector rather than composed from a pitch and a roll:
## two Euler angles taken from a normal disagree with it by their own
## cross term.
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

func _apply_legs() -> void:
	for i in _legs.size():
		_legs[i].rotation.x = GAIT_AMPLITUDE * sin(_gait + LEG_PHASE[i])

## ---- the mesh -----------------------------------------------------------

## The hull: body, neck, head, snout, two tail segments and the saddle.
## HULL_PIECES boxes, PIECE_TRIS triangles each, no texture, vertex
## colours read straight by the decor shader's COLOR.
##
## ⚠️ THE BOX HELPER IS SledBody's, CALLED AND NOT COPIED. CH39 is the
## reason it exists at all -- it is handed an OUTWARD direction and emits
## whichever winding puts the right-hand normal against it, because Godot
## takes clockwise-on-screen for the front face and the decor shader is
## `cull_disabled`, so a wrong winding is invisible in the sandbox and
## fatal the day anything culls. Copying that helper here would be a
## second spelling of the one thing in this file nobody may get wrong.
static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SledBody._box(st, BODY_LO, BODY_HI, BODY_COLOUR)
	SledBody._box(st, NECK_LO, NECK_HI, BODY_COLOUR)
	SledBody._box(st, HEAD_LO, HEAD_HI, BODY_COLOUR)
	SledBody._box(st, SNOUT_LO, SNOUT_HI, TRIM_COLOUR)
	SledBody._box(st, TAIL1_LO, TAIL1_HI, BODY_COLOUR)
	SledBody._box(st, TAIL2_LO, TAIL2_HI, BODY_COLOUR)
	SledBody._box(st, SADDLE_LO, SADDLE_HI, TRIM_COLOUR)
	return st.commit()

## One leg, in its own frame -- a separate mesh because a leg is a
## separate NODE that swings.
static func leg_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	SledBody._box(st, LEG_LO, LEG_HI, TRIM_COLOUR)
	return st.commit()
