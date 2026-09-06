extends Node3D
class_name KartBody
## ONE kart: an arcade vehicle on the ground plane, and the body that draws
## it. Knows nothing about who drives it (KartInput), which track it is on
## (it is told, per frame, whether it is on the surface and where the soft
## fence is) or whose lap is being timed (KartLap).
##
## =====================================================================
## THE FEEL, and what each number buys
##
## Cozy, not a simulator: forgiving and readable. Three ideas, each one
## constant:
##
##   * SPEED follows a TARGET (the cap times the throttle) with a time
##     constant, so acceleration is a curve that eases out at the top
##     rather than a ramp that hits a wall -- and lifting the throttle
##     coasts instead of stopping dead. Off the track the cap drops: the
##     kart is not punished, it is slowed, and it comes back on its own.
##   * STEERING is a yaw rate that scales with speed up to a point (a
##     parked kart does not pivot) and then EASES BACK at the top end (a
##     kart at full speed turns a little wider than one at half speed),
##     which is what keeps the top speed from feeling twitchy.
##   * GRIP is what makes it a kart and not a train: the velocity is a
##     WORLD vector, so when the heading turns the velocity does not turn
##     with it -- it acquires a lateral component in the new frame, and
##     grip is how fast that component dies. High grip on the track is a
##     touch of slide on every corner; low grip on the grass is a real
##     slither. The slide also SCRUBS speed (SCRUB), so a corner taken too
##     fast costs pace, gently.
##
## Every constant is in world units and seconds and lives here, once.
## `MAX_SPEED` sets the pace of the whole zone.
##
## =====================================================================
## CH31 -- THE BASE PACE WENT UP, AND THE BOUND IS MEASURED
##
## Mathieu asked for more speed for the excitement, as a lever separate
## from the opponents' difficulty. It is separate: this constant moves the
## PLAYER and the AI alike (the AI's profile is capped by MAX_SPEED and
## BOOST_SPEED_RATIO), and difficulty is a multiplier on top.
##
## Swept with the reference player model (RaceBalanceProbe --only=ref,
## n = 40 runs per point, latency and jitter drawn per run). The two
## populations are a DISCIPLINED drive (no boost) and a PUSHING one:
##
##   cruise / boost   disciplined p50 (off %)   pushing p50 (off %)
##   13.0 / 16.51     22.750 s (0.00 %)         20.033 s ( 9.20 %)
##   14.5 / 18.41     22.317 s (5.02 %)         20.533 s (20.21 %)
##   15.0 / 19.05     21.700 s (5.05 %)         20.620 s (21.63 %)
##   16.0 / 20.32     20.467 s (6.86 %)         20.917 s (25.88 %)
##
## ⚠️ THE BOUND IS AT 16 u/s, AND IT IS VISIBLE AS A CROSSING. At 16.0 the
## PUSHING driver laps SLOWER than the disciplined one (20.917 vs 20.467)
## and spends a quarter of the lap off the ribbon: past that point the
## extra speed is no longer being converted into lap time, it is being
## spent running wide. 15.0 is the last value where pushing still pays and
## the disciplined band stays tight (sd 0.529 s).
##
## Raising the BOOST CEILING alone was measured too, and it is NOT a pace
## lever: at cruise 13.0, taking the ceiling from 16.51 to 18.20 moved the
## pushing p50 by +0.10 s (the wrong way) while doubling the off-track
## share, 9.20 % -> 18.79 %. The kart already cannot use 16.5 everywhere,
## so a bigger number on top of it buys nothing. The ratio is therefore
## kept where V7b left it and the CRUISE is what moved.
##
## The persistent best lap is keyed on KartTrack.TRACK_ID, which changed
## in the same lot for exactly this reason: a record set at 13 u/s is not
## comparable with one set at 15.
##
## =====================================================================
## V7b -- ACCELERATOR (boost) and STEERING PRESETS
##
## Retour 1 (Mathieu, device): the accelerator was fully automatic, no way
## to push. Kept the cruise exactly as it was (the kart still drives
## itself, CLAUDE.md's "esprit du schema actuel") and added a BOOST on top
## -- KartInput.boost, 0..1, raises the speed CAP toward BOOST_MAX_SPEED.
## The cruise pace (MAX_SPEED, unboosted) and every existing lap time are
## therefore untouched; boost only ever makes the kart faster than before.
##
## Retour 2: STEER_RATE is no longer a literal here. A measured diagnosis
## (KartTuning.gd, journal "V7b -- reglage conduite") found GRIP was NOT
## the source of the "10/10 brutal" feel -- it governs how long a slide
## lingers, not how hard a turn hits -- so it is fixed once, low, for every
## preset. STEER_RATE (and the touch mapping in KartTouchInput) IS the
## real lever, and it is read live from KartTuning so Mathieu can compare
## three presets without leaving the kart.

const MAX_SPEED: float = 15.0
const MAX_SPEED_OFF_TRACK: float = 5.5
const REVERSE_SPEED: float = 3.5
## Top speed at full boost (input.boost == 1.0); a ~27 % push over cruise,
## on and off track alike (BOOST_SPEED_RATIO scales whichever cap applies).
## CH31: 16.5 -> 19.05, which is the SAME 1.27 ratio over the new cruise.
## The ratio was measured not to be a lever on its own (see above); this
## moves with MAX_SPEED so the boost keeps costing and buying what it did.
const BOOST_MAX_SPEED: float = 19.05
const BOOST_SPEED_RATIO: float = BOOST_MAX_SPEED / MAX_SPEED
## Time constants (1/s) for speed approaching its target.
const ACCEL_LAMBDA: float = 0.85
const COAST_LAMBDA: float = 0.30
const OFF_TRACK_LAMBDA: float = 1.6
const BRAKE_DECEL: float = 15.0
const STEER_FULL_SPEED: float = 4.5
## Fraction of the steer rate kept at MAX_SPEED (1.0 = no easing).
const STEER_HIGH_SPEED_KEEP: float = 0.72
## Lateral velocity decay (1/s). V7b: lowered once from the shipped 6.5/2.4
## (measured to add a touch of carry-over on every correction -- CLAUDE.md
## GRIP doc below is now historical, drive() no longer reads a "6.5") --
## and then left FIXED across every steering preset: the diagnosis found
## grip is not what made direction feel brutal, so it does not need to
## scale with the 8/7/6 axis.
const GRIP_ON_TRACK: float = 5.0
const GRIP_OFF_TRACK: float = 1.8
## Forward speed lost per unit of lateral speed per second.
const SCRUB: float = 0.55
## Soft fence: velocity into the wall is reflected and scaled by this.
const FENCE_BOUNCE: float = 0.35
## Visual: chassis lean per unit of lateral acceleration (deg per u/s2),
## pitch per unit of forward acceleration, and their smoothing.
const ROLL_DEG_PER_ACCEL: float = 1.1
const ROLL_MAX_DEG: float = 9.0
const PITCH_DEG_PER_ACCEL: float = 0.55
const PITCH_MAX_DEG: float = 5.0
const CHASSIS_LAMBDA: float = 9.0
const WHEEL_RADIUS: float = 0.30
const FRONT_WHEEL_LOCK_DEG: float = 26.0
## Where a passenger sits, chassis-local: on the seat, feet on the floor
## pan. Published so the seat is one fact (CLAUDE.md), read by HubKarting
## for mount_carrier and by nothing else.
const SEAT: Vector3 = Vector3(0.0, 0.42, -0.18)
## The ground disc the kart occupies, for footprints and tap discs.
const FOOTPRINT: float = 1.4

var velocity: Vector3 = Vector3.ZERO
## The name this kart races under; the HUD and the lot-2 standings read it.
var racer_name: String = "Keepy"
var body_colour: Color = Color(0.93, 0.40, 0.30)

var _chassis: Node3D = null
var _wheels: Array[Node3D] = []
var _front_pivots: Array[Node3D] = []
var _wheel_spin: float = 0.0
var _roll: float = 0.0
var _pitch: float = 0.0
var _bob_t: float = 0.0
var _last_velocity: Vector3 = Vector3.ZERO
var _bump: float = 0.0
var _on_track: bool = true
## CH30: this kart's copy of the shared driving model, loaded once with
## the constants above. One per body, so a second vehicle can hold its
## own without either reaching into the other's.
var _motion: VehicleDrive = _make_motion()

static func _make_motion() -> VehicleDrive:
	var m := VehicleDrive.new()
	m.max_speed = MAX_SPEED
	m.max_speed_off = MAX_SPEED_OFF_TRACK
	m.reverse_speed = REVERSE_SPEED
	m.boost_speed_ratio = BOOST_SPEED_RATIO
	m.accel_lambda = ACCEL_LAMBDA
	m.coast_lambda = COAST_LAMBDA
	m.off_lambda = OFF_TRACK_LAMBDA
	m.brake_decel = BRAKE_DECEL
	m.steer_full_speed = STEER_FULL_SPEED
	m.steer_high_speed_keep = STEER_HIGH_SPEED_KEEP
	m.grip_on = GRIP_ON_TRACK
	m.grip_off = GRIP_OFF_TRACK
	m.scrub = SCRUB
	m.fence_bounce = FENCE_BOUNCE
	return m

func _ready() -> void:
	_build()

## The node a passenger is parented to (it leans with the kart).
func chassis() -> Node3D:
	return _chassis

func forward() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))

func right() -> Vector3:
	var f := forward()
	return Vector3(f.z, 0.0, -f.x)

## Signed forward speed, u/s.
func speed() -> float:
	return velocity.dot(forward())

func is_on_track() -> bool:
	return _on_track

## Puts the kart down at `at` facing `yaw`, stopped.
func place(at: Vector3, yaw: float) -> void:
	global_position = Vector3(at.x, 0.0, at.z)
	rotation.y = yaw
	velocity = Vector3.ZERO
	_last_velocity = Vector3.ZERO
	_roll = 0.0
	_pitch = 0.0
	_bump = 0.0
	_apply_chassis(0.0)

## One physics step. `on_track` is the track's verdict on the kart's
## position; `fence` is the rectangle the kart is kept inside (x/z).
##
## CH30: the kinematics moved to VehicleDrive (a pure move -- same
## statements, same order, proved by comparing lap times and sampled
## trajectories against origin/staging, journal CH30). What is left here
## is what a BODY owns: reading the live steering preset, writing its own
## transform once, and the chassis animation.
func drive(delta: float, input: KartInput, on_track: bool, fence: Rect2) -> void:
	_on_track = on_track
	var out: Dictionary = _motion.step(global_position, rotation.y, velocity, delta, input,
		on_track, fence, KartTuning.steer_rate())
	rotation.y = float(out["yaw"])
	velocity = out["velocity"]
	global_position = out["position"]
	if bool(out["hit_fence"]):
		_bump = 1.0
	_animate(delta)
	_last_velocity = velocity

## ---- the body ----------------------------------------------------------

func _animate(delta: float) -> void:
	var fwd := forward()
	var rgt := right()
	var accel: Vector3 = (velocity - _last_velocity) / maxf(delta, 0.0001)
	var lat_a: float = accel.dot(rgt)
	var fwd_a: float = accel.dot(fwd)
	# Lean OUT of the corner (roll toward the outside), nose up on
	# acceleration, nose down on braking -- the classic reads.
	var want_roll: float = clampf(lat_a * ROLL_DEG_PER_ACCEL, -ROLL_MAX_DEG, ROLL_MAX_DEG)
	var want_pitch: float = clampf(-fwd_a * PITCH_DEG_PER_ACCEL, -PITCH_MAX_DEG, PITCH_MAX_DEG)
	var w: float = 1.0 - exp(-CHASSIS_LAMBDA * delta)
	_roll = lerpf(_roll, want_roll, w)
	_pitch = lerpf(_pitch, want_pitch, w)
	var v: float = speed()
	_wheel_spin += v / WHEEL_RADIUS * delta
	_bob_t += delta * (6.0 + absf(v) * 0.9)
	_bump = maxf(_bump - delta * 4.0, 0.0)
	_apply_chassis(absf(v))

func _apply_chassis(abs_speed: float) -> void:
	if _chassis == null:
		return
	var bob: float = sin(_bob_t) * 0.006 * clampf(abs_speed / MAX_SPEED, 0.0, 1.0)
	var jolt: float = _bump * _bump * 0.05
	_chassis.position = Vector3(0.0, bob + jolt, 0.0)
	_chassis.rotation_degrees = Vector3(_pitch, 0.0, _roll)
	for wheel in _wheels:
		wheel.rotation.x = _wheel_spin
	for pivot in _front_pivots:
		pivot.rotation_degrees.y = -_steer_visual * FRONT_WHEEL_LOCK_DEG

var _steer_visual: float = 0.0

## V8 (lot 2): a jolt from outside -- a kart-to-kart bump resolved by the
## coordinator. Same channel the soft fence uses (`_bump`), so a contact
## reads exactly like a wall touch: a short lift of the chassis, decaying.
## The ONE addition to this file for lot 2 beyond constants, noted in
## CH27 as the contract asks.
func bump(strength: float = 1.0) -> void:
	_bump = maxf(_bump, clampf(strength, 0.0, 1.0))

## The last steer the driver asked for, for the front wheels. Written by
## the coordinator after drive() so the body needs no reference to the
## input it was driven with.
func show_steer(steer: float) -> void:
	_steer_visual = lerpf(_steer_visual, clampf(steer, -1.0, 1.0), 0.35)

func _mat(colour: Color) -> Material:
	return CozyPalette.decor_material_tinted(colour)

func _box(parent: Node3D, size: Vector3, at: Vector3, colour: Color, name_: String = "Part") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh
	node.position = at
	node.material_override = _mat(colour)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _cyl(parent: Node3D, radius: float, height: float, at: Vector3, colour: Color, segments: int, name_: String = "Part") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 0
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh
	node.position = at
	node.material_override = _mat(colour)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

## Primitives with EXPLICIT tessellation (CLAUDE.md): the whole kart is
## ~700 triangles. Forward is +Z, like every character in this world.
func _build() -> void:
	_chassis = Node3D.new()
	_chassis.name = "Chassis"
	add_child(_chassis)
	var dark := Color(0.30, 0.26, 0.26)
	var cream := Color(0.95, 0.92, 0.82)
	var seat := Color(0.36, 0.30, 0.28)
	var accent := body_colour.lightened(0.35)
	# Floor pan and the two side pods.
	_box(_chassis, Vector3(1.20, 0.10, 1.90), Vector3(0.0, 0.22, 0.0), dark, "Pan")
	_box(_chassis, Vector3(0.34, 0.24, 1.20), Vector3(-0.55, 0.36, -0.05), body_colour, "PodL")
	_box(_chassis, Vector3(0.34, 0.24, 1.20), Vector3(0.55, 0.36, -0.05), body_colour, "PodR")
	# Nose: a low wedge of two boxes, and the cream number plate.
	_box(_chassis, Vector3(0.86, 0.26, 0.70), Vector3(0.0, 0.34, 0.72), body_colour, "Nose")
	_box(_chassis, Vector3(1.10, 0.10, 0.36), Vector3(0.0, 0.30, 1.05), body_colour, "Bumper")
	_box(_chassis, Vector3(0.40, 0.22, 0.04), Vector3(0.0, 0.42, 1.08), cream, "Plate")
	# Seat, back rest, engine block behind, small exhaust.
	_box(_chassis, Vector3(0.62, 0.12, 0.56), Vector3(0.0, 0.34, -0.22), seat, "Seat")
	_box(_chassis, Vector3(0.62, 0.50, 0.12), Vector3(0.0, 0.60, -0.52), seat, "Back")
	_box(_chassis, Vector3(0.50, 0.30, 0.34), Vector3(0.0, 0.42, -0.78), dark, "Engine")
	_cyl(_chassis, 0.05, 0.36, Vector3(0.30, 0.40, -0.90), Color(0.62, 0.62, 0.60), 8, "Exhaust").rotation_degrees.x = 90.0
	_box(_chassis, Vector3(0.30, 0.06, 0.20), Vector3(0.0, 0.60, -0.80), accent, "EngineCap")
	# Steering column and wheel (a low-segment torus: 8 x 6).
	var column := _cyl(_chassis, 0.03, 0.42, Vector3(0.0, 0.62, 0.36), Color(0.62, 0.62, 0.60), 6, "Column")
	column.rotation_degrees.x = 55.0
	var torus := TorusMesh.new()
	torus.inner_radius = 0.10
	torus.outer_radius = 0.16
	torus.rings = 10
	torus.ring_segments = 6
	var wheel := MeshInstance3D.new()
	wheel.name = "SteeringWheel"
	wheel.mesh = torus
	wheel.position = Vector3(0.0, 0.79, 0.24)
	wheel.rotation_degrees.x = 55.0
	wheel.material_override = _mat(dark)
	wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chassis.add_child(wheel)
	# Four wheels: rear pair fixed, front pair on steering pivots. Each
	# wheel is a 12-segment cylinder lying on its side plus a hub cap.
	for spec in [[-0.62, 0.62, false], [0.62, 0.62, false], [-0.60, -0.62, true], [0.60, -0.62, true]]:
		var x: float = spec[0]
		var z: float = spec[1]
		var front: bool = spec[2]
		var pivot := Node3D.new()
		pivot.name = "Pivot"
		pivot.position = Vector3(x, WHEEL_RADIUS, z)
		_chassis.add_child(pivot)
		var spin := Node3D.new()
		spin.name = "Spin"
		pivot.add_child(spin)
		var tyre := _cyl(spin, WHEEL_RADIUS, 0.24, Vector3.ZERO, dark, 12, "Tyre")
		tyre.rotation_degrees.z = 90.0
		var cap := _cyl(spin, 0.14, 0.26, Vector3.ZERO, accent, 8, "Hub")
		cap.rotation_degrees.z = 90.0
		_wheels.append(spin)
		if front:
			_front_pivots.append(pivot)
	# A small flag on a mast behind the seat: the racer's colour, seen
	# from the hub camera's height when the body itself is under Keepy.
	_cyl(_chassis, 0.02, 0.9, Vector3(-0.40, 0.95, -0.70), Color(0.62, 0.62, 0.60), 5, "Mast")
	_box(_chassis, Vector3(0.03, 0.22, 0.34), Vector3(-0.40, 1.28, -0.54), accent, "Pennant")
