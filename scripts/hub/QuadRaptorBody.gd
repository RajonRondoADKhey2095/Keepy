extends Node3D
class_name QuadRaptorBody
## CH79 -- THE QUAD, the hub's sixth driven vehicle: a four-wheeled sport
## ATV Keepy rides, driven frame by frame by a held finger.
##
## =====================================================================
## ⚠️ CH80 CORRECTED WHAT THIS THING IS, AND NOTHING ELSE
##
## CH79 read "quad raptor" as an ANIMAL and shipped ten boxes with a neck,
## a tail and four swinging legs. It is a QUAD BIKE -- "Raptor" is the
## name of a Yamaha ATV, not a dinosaur -- and CH80 rebuilds the mesh as
## one, to that machine's proportions.
##
## What CH80 changed: `build_mesh()`, `leg_mesh()`, the colours, the four
## moving parts, and SEAT_Y. What it did NOT change, to the digit: the
## pace, the hill, the friction, the steering, the wall, the door, the
## camera, the writer, the HUD. CH79's docblock claimed no mechanic here
## or anywhere reads the mesh; CH80 MEASURED that claim -- `QuadProbe` is
## 75 assertions run on both trees and the rebuild moved none of them.
##
## ⚠️ AND THE RIDER'S POSE IS NOT IN THIS FILE. The brief asks for Keepy
## SITTING ASTRIDE the saddle. There is no sitting pose in this repo:
## `KeepyHopper.mount_carrier()` writes him STANDING at the seat point --
## `_body.scale = _base_scale`, `_body.rotation_degrees.x = _base_pitch`
## -- and the kart, the sled, the yacht and the sailboat all ride that
## way. Posing him astride is a change to KeepyHopper shared by six
## vehicles, which is a mechanic and out of this lot. What IS in this file
## is the geometry he stands in the middle of: the saddle is narrow and
## long, the tank flares either side of his feet, the footpegs are where
## his feet would hang, and the bar is 0.39 u above the seat -- the same
## rise over the rider that KartBody's steering wheel has. He reads as
## astride it because the machine is built around where he stands.
##
## =====================================================================
## IT IS THE SLED'S SHAPE, AND DELIBERATELY NOT A NEW ONE
##
## CLAUDE.md's brief for CH79 is explicit: reuse the continuous control
## pattern that exists rather than invent a cleaner one. So this file is
## SledBody.gd's division of labour, member for member:
##
##   * SurfaceDrive owns the kinematics AND the ground query (CH41's
##     composite, which its own docblock says is adopted by the NEW
##     vehicle -- this is that vehicle);
##   * VehicleDrive underneath it is the same model the kart, the sand
##     yacht, the sailboat and the sled are driven by, configured here
##     with this machine's own numbers and nothing else;
##   * KartTouchInput is the writer, unchanged -- one finger, anchor,
##     left/right steers, up is pace and down is the gear;
##   * the rider is ON_CARRIER through mount_carrier(), so every other
##     hub branch refuses him by STATE and there is no second flag;
##   * the chase camera is ChaseTuning.vehicle(), the default the other
##     four already take;
##   * HubTransport owns the door (mount, drive, exit) exactly as it owns
##     the sled's.
##
## ⚠️ THE HANDLING NUMBERS BELOW WERE TUNED FOR AN ANIMAL AND ARE LEFT
## ALONE ON PURPOSE. SLOPE_GAIN 0.55 and GRIP_ON 6.5 are argued in their
## own comments as "legs, so it holds"; on a quad the same numbers read as
## long-travel suspension and knobbly tyres, and CH79's ride was validated
## on device. Re-arguing them is a FEEL lot with a device pass, not a
## mesh lot -- CH70 is the precedent for what happens when a taste
## constant is reopened without measuring who stood on it since.
##
## =====================================================================
## WHERE IT MAY GO
##
## `drivable()` READS SandYacht's, which is the published predicate all
## three free-roaming land vehicles already share -- "the walkable region
## minus the karting circuit". A second spelling of that set is exactly
## the defect CLAUDE.md's "un fait est publie une fois" section exists to
## refuse, and a vehicle on the starting grid when the lights go out is
## the bug the yacht's lot closed.
##
## The region is NOT convex, and this vehicle does not use the pedestrian
## router (a driven vehicle has no destination to route to). `_wall()` is
## SandYacht's axis-separated slide, three attempts in the same order --
## the same thing that has bounded the yacht, the sailboat and the sled
## since CH30, on the same ground.
##
## =====================================================================
## ⚠️ THE FOUR MOVING PARTS ARE STILL CALLED LEGS IN THE PUBLIC NAMES
##
## `leg_mesh()`, `LEG_PIECES` and `leg_pitch()` are the names CH79 gave
## the four things that swing under this body. They are now WHEELS, and
## the names are wrong -- but they are the names QuadProbe addresses them
## by, and CH80's brief forbids touching the probe (a red there is the
## lot's evidence that a mechanic read the mesh, so the probe must stay
## the CH79 one for the comparison to mean anything). Renaming the three
## together with the probe is a one-commit job for a lot that is allowed
## to edit it; it is written down in CH80's report rather than done here.

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
##
## ⚠️ 1.06 -> 0.82 IS THE ONE NUMBER OUTSIDE THE MESH THAT CH80 MOVED, and
## it is a mesh number wearing a mechanic's coat: it is the height of a
## SEAT, and CH79's seat was the back of an animal. Keepy is 1.7 u to the
## crown (KeepyHopper.CROWN_HEIGHT), so one unit is a metre on this map,
## and 0.82 is a sport quad's seat height read at that scale. Nothing
## derives a contract from it -- QuadProbe reads it off this publisher,
## HubTransport republishes it, and `mount_carrier` puts him where it
## says.
const SEAT_Y: float = 0.82
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

## ---- the wheels ---------------------------------------------------------
## ⚠️ THE REAR PAIR IS TALLER AND WIDER THAN THE FRONT, and after the
## track width and the handlebar it is the third thing that says "quad".
## The real machine's two diameters differ by millimetres and its two
## widths by a lot; at 11.7 u under a shader with no shading on a flank
## (CH35-C) a width difference alone does not read from behind, so the
## rear is given 0.07 u of extra radius as well. That exaggeration is the
## whole of it -- everything else here is a Raptor 700's dimensions at
## 1 u = 1 m.
const FRONT_WHEEL_RADIUS: float = 0.33
const FRONT_WHEEL_WIDTH: float = 0.26
const REAR_WHEEL_RADIUS: float = 0.40
const REAR_WHEEL_WIDTH: float = 0.38
## Axle centres in the vehicle's frame: |x| is the half-track, z the
## wheelbase. ⚠️ THE TRACK IS THE FIRST IDENTIFYING TRAIT and it is a
## RATIO, not a width: this machine is 1.740 u across and 2.010 u long
## (0.866), against the kart's 1.480 / 2.150 (0.688). A quad is squat;
## a kart is long. FrameProbe-free, but the numbers are published so a
## later lot can re-derive the ratio instead of re-measuring the mesh.
const AXLES: Array[Vector3] = [
	Vector3(-0.62, FRONT_WHEEL_RADIUS, 0.62),
	Vector3(0.62, FRONT_WHEEL_RADIUS, 0.62),
	Vector3(-0.68, REAR_WHEEL_RADIUS, -0.62),
	Vector3(0.68, REAR_WHEEL_RADIUS, -0.62),
]
const WHEEL_RADIUS: Array[float] = [
	FRONT_WHEEL_RADIUS, FRONT_WHEEL_RADIUS, REAR_WHEEL_RADIUS, REAR_WHEEL_RADIUS,
]
const WHEEL_WIDTH: Array[float] = [
	FRONT_WHEEL_WIDTH, FRONT_WHEEL_WIDTH, REAR_WHEEL_WIDTH, REAR_WHEEL_WIDTH,
]
## ⚠️ DERIVED, NOT TYPED. A wheel that rolls without slipping turns by
## 1 / radius radians per unit travelled; KartBody writes the same
## relation as `_wheel_spin += v / WHEEL_RADIUS * delta`. `_gait` holds
## the ODOMETER -- signed units covered along the heading -- and each
## wheel converts it with its OWN radius, which is what makes the two
## sizes visible in motion and not only at rest. One publisher, two
## consequences: retune a radius above and the roll follows.
const ROLL_PER_U: Array[float] = [
	1.0 / FRONT_WHEEL_RADIUS, 1.0 / FRONT_WHEEL_RADIUS,
	1.0 / REAR_WHEEL_RADIUS, 1.0 / REAR_WHEEL_RADIUS,
]

## ---- the colours --------------------------------------------------------
## ⚠️ MEASURED AGAINST THE GROUND, AND THE MEASUREMENT REFUSED THE
## OBVIOUS ANSWER. CH79 chose teal "so a green mount is not a silhouette
## with no edge". Scored as WCAG relative luminance against the nine
## ground bands this vehicle can stand on, CH79's teal is 1.23:1 at its
## worst (against AUTUMN_A) -- it does not merely lose contrast there, it
## DISAPPEARS. It is not a teal problem: the worst band sits at L 0.313,
## so crossing 3.0:1 anywhere on this map needs L <= 0.071, and no tone a
## body panel would wear is that dark. That is CLAUDE.md's "la palette est
## coupee en deux bandes par le sol", met again on the hub's own greens.
##
## So the floor is carried the way CH48 carries it for a minimap marker
## that holds a PHOTOGRAPH: by a piece of ONE tone that can. The tyres and
## the frame are near-black -- 5.87:1 and 3.91:1 against the WORST band --
## and they ring the whole lower half of this machine, its wheels, its
## skid plate, its swingarms, its bars and its bumpers. The silhouette's
## edge is theirs at every station. The BODY tone is then free, and is
## chosen for three things it can actually deliver:
##
##   * FLEET DISTINCTNESS -- the kart is coral (0.93, 0.40, 0.30) and the
##     sled is cream and red. Blue is the one hue no vehicle here owns;
##   * HUE DISTANCE -- 218 deg against grass at 90-120 deg, and blue
##     against green is the separation an eye makes even at equal
##     luminance, which is the half WCAG explicitly does not score;
##   * and it is the colour the reference machine is actually sold in.
##
## Worst case against the nine bands: body 2.20:1, wing 1.72:1, seat
## 3.75:1, frame 3.91:1, tyre 5.87:1, hub 1.31:1. Inside the vehicle the
## four roles the brief asks to separate are 2.67:1 (body/tyre), 2.31:1
## (body/seat) and 7.93:1 (tyre/hub) apart.
##
## ⚠️ AND A SANDBOX CANNOT SIGN THIS. Every ratio above is arithmetic on
## authored albedo; the decor shader is unlit, so those albedos ARE what
## shows (CLAUDE.md), but "does it read as a quad on the grass" is a
## device call and CH80's report names it as one.
const BODY_COLOUR: Color = Color(0.16, 0.36, 0.72)
## The four mudguards, one step lighter, so the "wings" a quad is read by
## from the front separate from the tank instead of merging into it.
const WING_COLOUR: Color = Color(0.28, 0.54, 0.86)
## The saddle, and nothing else wears it.
const SEAT_COLOUR: Color = Color(0.46, 0.39, 0.35)
## Frame, engine, swingarms, footpegs, bars, bumpers, exhaust.
const FRAME_COLOUR: Color = Color(0.22, 0.23, 0.25)
## Tyres, and the handlebar grips -- the same rubber, said once.
const TYRE_COLOUR: Color = Color(0.12, 0.11, 0.11)
## Hub caps and headlights: the one light tone, small, where it breaks the
## dark mass of a wheel.
const HUB_COLOUR: Color = Color(0.80, 0.82, 0.84)

## ---- how the mesh is GROUPED --------------------------------------------
## ⚠️ EVERY PIECE OF THIS VEHICLE IS ONE CONVEX HEXAHEDRON OF PIECE_TRIS
## TRIANGLES, and that is a discipline, not an accident.
##
## SledBody._hexa is eight corners and six quads; its runner noses are
## already SHEARED, so the same twelve triangles also make a frustum, a
## tilted plate, and -- the piece CH80 needed -- a WEDGE of a cylinder
## (centre, three rim points, extruded: eight corners, six faces, twelve
## triangles, and convex for any span under 180 degrees). Two rim segments
## per wedge, so `sectors` wedges make a cylinder of `2 * sectors` sides:
## three for a coarse tube, six for the 12-sided wheels KartBody already
## chose for the same viewing distance.
##
## Holding to it buys the thing that matters: QuadProbe's winding test
## groups the committed mesh into runs of PIECE_TRIS triangles and scores
## each against ITS OWN centre, which is only valid on a CONVEX piece
## (SledProbe's first version tested a five-box assembly against one
## centre of mass and called 46 of 60 triangles wrong on a correct mesh).
## A mesh built of anything else would have to be tested by something
## weaker. CH60's rule, in advance: the property the test needs is named
## here, in the code, and every piece satisfies it.
const PIECE_TRIS: int = 12
## ⚠️ A LITERAL THAT MUST MATCH WHAT build_mesh() EMITS, and PHASE X of
## QuadProbe is what makes that true rather than hopeful: it counts the
## committed triangles and refuses this number if it drifts.
const HULL_PIECES: int = 68
## Wedges per wheel -- six, so each wheel is a 12-sided cylinder, the
## tessellation KartBody's tyres already use at this camera distance.
const WHEEL_SECTORS: int = 6
## The four wheels' pieces, all of them instances of `leg_mesh()`. The
## name is CH79's; see the header.
const LEG_PIECES: int = 4 * WHEEL_SECTORS

var velocity: Vector3 = Vector3.ZERO

var _chassis: Node3D = null
var _legs: Array[Node3D] = []
var _drive: SurfaceDrive = null
var _normal: Vector3 = Vector3.UP
var _prev: Vector3 = Vector3.ZERO
var _on_ground: bool = true
## The rolling odometer: signed units covered along the heading since the
## last place(). The wheels are written from it, each by its own radius.
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

## Builds the quad under a TILTING chassis. The root carries position and
## yaw (what the driving model writes); the chassis carries the ground's
## normal, and the rider is seated on the CHASSIS so he leans with the
## hill exactly as he heels with the yacht's deck.
##
## ⚠️ EACH WHEEL IS SIX NODES, NOT ONE, and that is what buys a round
## wheel without breaking the mesh discipline: `leg_mesh()` is one convex
## wedge, and six of it scaled by that wheel's radius and width make the
## 12-sided cylinder. KartBody spends about the same on its own wheels
## (eight nodes for four tyres and four hub caps); this is one object in
## the scene, never scattered, so the node count is paid once. CLAUDE.md's
## rule for what stays an individual node names this case exactly -- a
## batch nested under a MOVING pivot -- so a MultiMesh is not the answer
## here even though the instances are identical.
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
	var sector: ArrayMesh = leg_mesh()
	for i in AXLES.size():
		var pivot := Node3D.new()
		pivot.name = "Wheel%d" % i
		pivot.position = AXLES[i]
		_chassis.add_child(pivot)
		var r: float = WHEEL_RADIUS[i]
		var w: float = WHEEL_WIDTH[i]
		for k in WHEEL_SECTORS:
			var phi: float = TAU * float(k) / float(WHEEL_SECTORS)
			var arc := MeshInstance3D.new()
			arc.name = "Sector%d" % k
			arc.mesh = sector
			# The wedge is authored with its axle on +Y and its rim in XZ;
			# this basis stands it up on the vehicle's X axis, turns it to
			# its share of the circle, and scales it to this wheel. The
			# determinant is r * r * w, so it is a rotation and a positive
			# scale and the winding survives it.
			arc.transform = Transform3D(Basis(
				Vector3(0.0, cos(phi), sin(phi)) * r,
				Vector3(1.0, 0.0, 0.0) * w,
				Vector3(0.0, sin(phi), -cos(phi)) * r), Vector3.ZERO)
			arc.material_override = CozyPalette.decor_material()
			arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(arc)
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

## The rolling odometer, in UNITS of ground covered along the heading --
## not radians, and not per-wheel: this is the one fact both wheel sizes
## are written from (see ROLL_PER_U). Published so the probe reads what
## the wheels were WRITTEN from rather than re-deriving it.
##
## ⚠️ The name and the "rad" the probe prints beside it are CH79's, from
## when this was an animal's gait phase; the number is a distance. Fixing
## the label is a probe edit CH80 is not allowed to make -- see the
## header.
func gait_phase() -> float:
	return _gait

## How far one wheel has rolled as of the last frame, radians, wrapped --
## read off the NODE and not off `_gait`, so a probe that gates "the
## wheels turn" is looking at what is drawn and not at the variable that
## was meant to drive it. The name is CH79's; see the header.
func leg_pitch(index: int) -> float:
	if index < 0 or index >= _legs.size():
		return 0.0
	return _legs[index].rotation.x

## Triangles, both halves: the hull and the four wheels. Published as TWO
## numbers because "the model is cheap" and "the scene is cheap" are not
## the same sentence.
func triangle_count() -> Array[int]:
	return [PIECE_TRIS * HULL_PIECES, PIECE_TRIS * LEG_PIECES]

## Puts the quad down at `at` facing `yaw`, stopped, ON THE GROUND. The
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
	# ⚠️ THE ODOMETER ADVANCES ON THE DISTANCE ACTUALLY COVERED -- after the
	# wall, not before it. A quad held against a hedge has travelled zero
	# and its wheels must say so.
	#
	# ⚠️ AND IT IS SIGNED, along the heading. A wheel rolls backwards in
	# reverse, and a body shoved SIDEWAYS by the wall's slide has not
	# rolled at all: `distance_to` could not say either.
	_gait += (flat_position() - _prev).dot(forward())
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

## Rolls the four wheels off the odometer, each by its OWN radius.
## Wrapped, because a Node3D's cached euler is the thing `leg_pitch()`
## reads back and an angle that only ever grows would drift away from
## anything readable.
func _apply_legs() -> void:
	for i in _legs.size():
		_legs[i].rotation.x = wrapf(_gait * ROLL_PER_U[i], -PI, PI)

## ---- the mesh -----------------------------------------------------------

## The hull: frame, bodywork, saddle, mudguards, handlebar, bumpers and
## hub caps. HULL_PIECES convex hexahedra, PIECE_TRIS triangles each, no
## texture, vertex colours read straight by the decor shader's COLOR.
##
## ⚠️ THE WINDING DECISION IS SledBody._quad's, CALLED AND NOT COPIED.
## CH39 is why it exists: Godot takes clockwise-on-screen for the FRONT
## face, so the right-hand normal of a visible face points INTO the solid,
## and the decor shader is `cull_disabled` -- a mesh wound backwards is
## invisible as a defect in this sandbox and fatal the day anything culls.
## `_solid` below hands that function an OUTWARD direction per face and
## lets it pick the order; nothing here writes a triangle by hand.
static func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_frame(st)
	_build_body(st)
	_build_saddle(st)
	_build_guards(st)
	_build_bars(st)
	_build_ends(st)
	_build_hubs(st)
	return st.commit()

## One wheel's worth of tyre is SIX of these, and every wheel in the scene
## is instances of this one mesh scaled by its own radius and width -- so
## "a wheel" is authored once and the front/rear sizes are a transform.
##
## The name is CH79's; see the header. It is a WEDGE of a cylinder: unit
## radius, half-height 0.5 along +Y (the axle), the rim spanning a sixth
## of a turn about +X in the XZ plane.
static func leg_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_solid(st, _wedge(PI / float(WHEEL_SECTORS)), Transform3D.IDENTITY, TYRE_COLOUR)
	return st.commit()

## ---- the pieces ---------------------------------------------------------
## The frame: everything dark and structural. It is deliberately the FIRST
## group built and the one that reaches furthest down and furthest out,
## because it is the tone that carries this machine's edge against every
## ground band (see the colours above).
static func _build_frame(st: SurfaceTool) -> void:
	# Skid plate. Its underside at 0.26 is the GROUND CLEARANCE: there is
	# daylight under this vehicle from every angle, which is the fourth
	# thing that says "quad" and the first thing a chassis laid on the
	# grass would lose.
	_box(st, Vector3(-0.34, 0.26, -0.70), Vector3(0.34, 0.32, 0.60), FRAME_COLOUR)
	# Engine block under the saddle, rear axle housing, two swingarms.
	_box(st, Vector3(-0.24, 0.30, -0.34), Vector3(0.24, 0.62, 0.22), FRAME_COLOUR)
	_box(st, Vector3(-0.30, 0.30, -0.74), Vector3(0.30, 0.52, -0.46), FRAME_COLOUR)
	_box(st, Vector3(-0.32, 0.34, -0.70), Vector3(-0.22, 0.44, -0.24), FRAME_COLOUR)
	_box(st, Vector3(0.22, 0.34, -0.70), Vector3(0.32, 0.44, -0.24), FRAME_COLOUR)
	# Front A-arms, reaching out to the front hubs through the gap the
	# clearance opens.
	_box(st, Vector3(-0.62, 0.28, 0.50), Vector3(-0.30, 0.34, 0.62), FRAME_COLOUR)
	_box(st, Vector3(0.30, 0.28, 0.50), Vector3(0.62, 0.34, 0.62), FRAME_COLOUR)
	# Footpegs and the nerf rails outboard of them, in the gap between the
	# front and rear wheels -- where a rider's feet hang.
	_box(st, Vector3(-0.56, 0.28, -0.16), Vector3(-0.34, 0.33, 0.22), FRAME_COLOUR)
	_box(st, Vector3(0.34, 0.28, -0.16), Vector3(0.56, 0.33, 0.22), FRAME_COLOUR)
	_box(st, Vector3(-0.60, 0.27, -0.26), Vector3(-0.52, 0.34, 0.30), FRAME_COLOUR)
	_box(st, Vector3(0.52, 0.27, -0.26), Vector3(0.60, 0.34, 0.30), FRAME_COLOUR)
	# Exhaust: a header down the right flank into a can behind the wheel.
	_box(st, Vector3(0.17, 0.50, -0.70), Vector3(0.25, 0.58, -0.24), FRAME_COLOUR)
	_tube(st, _axis(Vector3(0.22, 0.54, -0.84), Vector3(0.0, 0.0, 1.0), 0.085, 0.26),
		3, FRAME_COLOUR)

## The plastics. ⚠️ THE NOSE NARROWS: the tank is 0.50 u across at the
## rider and the snout 0.22 u at its tip, which is the fifth trait the
## brief names and the one that keeps this from reading as a crate.
static func _build_body(st: SurfaceTool) -> void:
	# Fuel tank: widest and tallest at the rider, tapering forward. It
	# flares wider than the saddle on both sides, which is the shape a
	# standing rider's legs sit against.
	_piece(st, [-0.25, 0.25, 0.56, 0.80], -0.12, [-0.16, 0.16, 0.52, 0.70], 0.48,
		Transform3D.IDENTITY, BODY_COLOUR)
	# Side panels over the engine.
	_box(st, Vector3(-0.35, 0.44, -0.48), Vector3(-0.22, 0.66, 0.04), BODY_COLOUR)
	_box(st, Vector3(0.22, 0.44, -0.48), Vector3(0.35, 0.66, 0.04), BODY_COLOUR)
	# The snout.
	_piece(st, [-0.17, 0.17, 0.38, 0.62], 0.48, [-0.11, 0.11, 0.36, 0.52], 0.88,
		Transform3D.IDENTITY, BODY_COLOUR)
	# And the raked front plate that closes it.
	_piece(st, [-0.15, 0.15, -0.03, 0.03], -0.17, [-0.15, 0.15, -0.03, 0.03], 0.17,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(58.0)), Vector3(0.0, 0.50, 0.88)),
		BODY_COLOUR)

## The saddle: HIGH and NARROW and long front to back, its own tone, and
## its top IS SEAT_Y at z = 0 -- the point mount_carrier() stands him on,
## so the flat of it is under his feet and the dip is ahead of them.
static func _build_saddle(st: SurfaceTool) -> void:
	_box(st, Vector3(-0.17, 0.66, -0.54), Vector3(0.17, SEAT_Y, 0.12), SEAT_COLOUR)
	_piece(st, [-0.17, 0.17, 0.66, SEAT_Y], 0.12, [-0.11, 0.11, 0.62, 0.74], 0.44,
		Transform3D.IDENTITY, SEAT_COLOUR)

## The four mudguards -- the "wings" a quad is recognised by head-on.
## Three plates each, laid on an arc about the axle, stopping just inboard
## of the tyre's outer face so the wheel is never faired in.
static func _build_guards(st: SurfaceTool) -> void:
	for i in AXLES.size():
		var at: Vector3 = AXLES[i]
		var side: float = signf(at.x)
		var half_w: float = WHEEL_WIDTH[i] * 0.5
		var arc: float = WHEEL_RADIUS[i] + 0.09
		var span: float = deg_to_rad(58.0 if i < 2 else 62.0)
		var inner: float = 0.42
		var outer: float = absf(at.x) + half_w - 0.01
		var x_lo: float = inner if side > 0.0 else -outer
		var x_hi: float = outer if side > 0.0 else -inner
		for k in 3:
			var a0: float = lerpf(-span, span, float(k) / 3.0)
			var a1: float = lerpf(-span, span, float(k + 1) / 3.0)
			_plate(st, Vector3(0.0, at.y, at.z), arc, a0, a1, x_lo, x_hi, 0.05,
				WING_COLOUR)

## The handlebar. ⚠️ SECOND IDENTIFYING TRAIT, so it is built to be SEEN:
## a column off the top of the tank, a wide cross tube, and rubber grips
## at both ends. Its bar sits 0.39 u above SEAT_Y, the same rise over the
## rider that KartBody gives its steering wheel over the kart's seat.
static func _build_bars(st: SurfaceTool) -> void:
	_piece(st, [-0.055, 0.055, -0.30, 0.30], -0.055, [-0.055, 0.055, -0.30, 0.30], 0.055,
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-10.0)), Vector3(0.0, 0.90, 0.50)),
		FRAME_COLOUR)
	_tube(st, _axis(Vector3(0.0, 1.21, 0.45), Vector3(1.0, 0.0, 0.0), 0.038, 0.52),
		3, FRAME_COLOUR)
	for s in [-1.0, 1.0]:
		_tube(st, _axis(Vector3(0.32 * s, 1.21, 0.45), Vector3(1.0, 0.0, 0.0), 0.055, 0.16),
			3, TYRE_COLOUR)
	_box(st, Vector3(-0.10, 1.24, 0.42), Vector3(0.10, 1.30, 0.48), BODY_COLOUR)

## Front bumper, rear grab bar, headlights.
static func _build_ends(st: SurfaceTool) -> void:
	_box(st, Vector3(-0.30, 0.30, 0.92), Vector3(0.30, 0.37, 0.99), FRAME_COLOUR)
	_box(st, Vector3(-0.30, 0.30, 0.92), Vector3(-0.23, 0.56, 0.99), FRAME_COLOUR)
	_box(st, Vector3(0.23, 0.30, 0.92), Vector3(0.30, 0.56, 0.99), FRAME_COLOUR)
	_box(st, Vector3(-0.30, 0.50, 0.90), Vector3(0.30, 0.56, 0.97), FRAME_COLOUR)
	_box(st, Vector3(-0.28, 0.36, 0.70), Vector3(-0.22, 0.42, 0.95), FRAME_COLOUR)
	_box(st, Vector3(0.22, 0.36, 0.70), Vector3(0.28, 0.42, 0.95), FRAME_COLOUR)
	_box(st, Vector3(-0.28, 0.64, -0.90), Vector3(0.28, 0.70, -0.82), FRAME_COLOUR)
	_box(st, Vector3(-0.27, 0.50, -0.88), Vector3(-0.20, 0.70, -0.80), FRAME_COLOUR)
	_box(st, Vector3(0.20, 0.50, -0.88), Vector3(0.27, 0.70, -0.80), FRAME_COLOUR)
	_box(st, Vector3(-0.13, 0.46, 0.855), Vector3(-0.05, 0.58, 0.905), HUB_COLOUR)
	_box(st, Vector3(0.05, 0.46, 0.855), Vector3(0.13, 0.58, 0.905), HUB_COLOUR)

## A hub cap just proud of each tyre's outer face: the one light tone on
## the machine, and the thing that keeps a wheel from reading as a black
## hole. It does NOT turn with the tyre and does not need to -- it is a
## disc about its own axle, so a still one and a spinning one draw the
## same pixels.
static func _build_hubs(st: SurfaceTool) -> void:
	for i in AXLES.size():
		var at: Vector3 = AXLES[i]
		var out: float = absf(at.x) + WHEEL_WIDTH[i] * 0.5 + 0.015
		var r: float = WHEEL_RADIUS[i] * 0.45
		_tube(st, _axis(Vector3(out * signf(at.x), at.y, at.z), Vector3(1.0, 0.0, 0.0), r, 0.05),
			3, HUB_COLOUR)

## ---- the primitives -----------------------------------------------------

## The eight corners of a cylinder wedge: unit radius, half-height 0.5
## along Y, the rim spanning +/- `half_span` radians about +X in the XZ
## plane, in SledBody._hexa's corner order (bottom ring, then top ring).
## Three rim points, so TWO rim segments per wedge.
static func _wedge(half_span: float) -> Array:
	var out: Array = []
	for y in [-0.5, 0.5]:
		out.append(Vector3(0.0, y, 0.0))
		out.append(Vector3(cos(-half_span), y, sin(-half_span)))
		out.append(Vector3(1.0, y, 0.0))
		out.append(Vector3(cos(half_span), y, sin(half_span)))
	return out

## Emits ONE convex hexahedron: `v` in SledBody._hexa's corner order,
## placed by `xform`.
##
## ⚠️ THE OUTWARD HINTS ARE THE PIECE'S OWN AUTHORED AXES carried through
## `xform.basis`, NOT anything derived from the emitted vertices -- and
## that is deliberate. QuadProbe's winding test builds its own reference
## from each piece's CENTROID; if this function used the centroid too, the
## test would be checking the builder against itself and would stay green
## on any mesh at all. CH62's tautology, avoided by construction.
static func _solid(st: SurfaceTool, v: Array, xform: Transform3D, colour: Color) -> void:
	var w: Array = []
	for p in v:
		w.append(xform * (p as Vector3))
	var b: Basis = xform.basis
	SledBody._quad(st, w[0], w[3], w[2], w[1], b * Vector3.DOWN, colour)
	SledBody._quad(st, w[4], w[5], w[6], w[7], b * Vector3.UP, colour)
	SledBody._quad(st, w[0], w[1], w[5], w[4], b * Vector3(0.0, 0.0, -1.0), colour)
	SledBody._quad(st, w[3], w[7], w[6], w[2], b * Vector3(0.0, 0.0, 1.0), colour)
	SledBody._quad(st, w[0], w[4], w[7], w[3], b * Vector3.LEFT, colour)
	SledBody._quad(st, w[1], w[2], w[6], w[5], b * Vector3.RIGHT, colour)

## One piece spanning from the end at `bz` to the end at `fz`. Each end is
## [x_lo, x_hi, y_lo, y_hi] in the piece's own frame, so equal ends make a
## box and unequal ones a frustum -- the tapered tank, the narrowing
## snout, the dipping saddle.
static func _piece(st: SurfaceTool, back: Array, bz: float, front: Array, fz: float,
		xform: Transform3D, colour: Color) -> void:
	_solid(st, [
		Vector3(back[0], back[2], bz), Vector3(back[1], back[2], bz),
		Vector3(front[1], front[2], fz), Vector3(front[0], front[2], fz),
		Vector3(back[0], back[3], bz), Vector3(back[1], back[3], bz),
		Vector3(front[1], front[3], fz), Vector3(front[0], front[3], fz),
	], xform, colour)

static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, colour: Color) -> void:
	_piece(st, [lo.x, hi.x, lo.y, hi.y], lo.z, [lo.x, hi.x, lo.y, hi.y], hi.z,
		Transform3D.IDENTITY, colour)

## A cylinder of `2 * sectors` sides, as `sectors` wedges. `xform` carries
## the axis (local +Y), the rim (local XZ at unit radius) and the size.
static func _tube(st: SurfaceTool, xform: Transform3D, sectors: int, colour: Color) -> void:
	var half: float = PI / float(sectors)
	var v: Array = _wedge(half)
	for k in sectors:
		_solid(st, v, xform * Transform3D(Basis(Vector3.UP, 2.0 * half * float(k)),
			Vector3.ZERO), colour)

## The placement of a cylinder: `axis` is the direction its LENGTH runs
## in, `at` its centre. The rim's reference direction is whatever is left
## of world up after `axis` is taken out of it, which only matters for a
## coarse tube whose facets can be seen.
static func _axis(at: Vector3, axis: Vector3, radius: float, length: float) -> Transform3D:
	var y_axis: Vector3 = axis.normalized()
	var ref: Vector3 = Vector3.UP
	if absf(y_axis.dot(ref)) > 0.9:
		ref = Vector3(0.0, 0.0, 1.0)
	var x_axis: Vector3 = (ref - y_axis * ref.dot(y_axis)).normalized()
	return Transform3D(Basis(x_axis * radius, y_axis * length,
		x_axis.cross(y_axis) * radius), at)

## One plate of a mudguard: a slab `thickness` thick and `x_lo`..`x_hi`
## wide, laid on the arc of radius `radius` about `centre` between the
## angles `a0` and `a1`, measured from straight up toward +Z. Its ends sit
## ON the arc, so consecutive plates meet.
static func _plate(st: SurfaceTool, centre: Vector3, radius: float, a0: float, a1: float,
		x_lo: float, x_hi: float, thickness: float, colour: Color) -> void:
	var mid: float = (a0 + a1) * 0.5
	var half: float = (a1 - a0) * 0.5
	var chord: float = radius * sin(half)
	var seat: float = radius * cos(half)
	var end: Array = [x_lo, x_hi, -thickness * 0.5, thickness * 0.5]
	_piece(st, end, -chord, end, chord,
		Transform3D(Basis(Vector3.RIGHT, mid),
			centre + Vector3(0.0, cos(mid), sin(mid)) * seat), colour)
