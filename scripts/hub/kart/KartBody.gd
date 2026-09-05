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
## `MAX_SPEED` sets the pace of the whole zone: 13 u/s on a 230 u lap is a
## ~25 s lap for a clean drive, which is the length a cozy time trial can
## be repeated at without becoming a chore.
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

const MAX_SPEED: float = 13.0
const MAX_SPEED_OFF_TRACK: float = 5.5
const REVERSE_SPEED: float = 3.5
## Top speed at full boost (input.boost == 1.0); a ~27 % push over cruise,
## on and off track alike (BOOST_SPEED_RATIO scales whichever cap applies).
const BOOST_MAX_SPEED: float = 16.5
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
func drive(delta: float, input: KartInput, on_track: bool, fence: Rect2) -> void:
	_on_track = on_track
	var fwd := forward()
	var v_fwd: float = velocity.dot(fwd)
	# ---- steering: rotate the HEADING; the velocity stays in the world.
	var ratio: float = clampf(absf(v_fwd) / STEER_FULL_SPEED, 0.0, 1.0)
	var ease: float = 1.0 - (1.0 - STEER_HIGH_SPEED_KEEP) * clampf(absf(v_fwd) / MAX_SPEED, 0.0, 1.0)
	var gain: float = ratio * ease
	if v_fwd < -0.05:
		gain = -gain * 0.7
	rotation.y -= input.steer * KartTuning.steer_rate() * gain * delta
	fwd = forward()
	var rgt := right()
	# ---- decompose the (unchanged) world velocity in the NEW frame: the
	# turn just gave the kart a lateral component, which grip now eats.
	v_fwd = velocity.dot(fwd)
	var v_lat: float = velocity.dot(rgt)
	var grip: float = GRIP_ON_TRACK if on_track else GRIP_OFF_TRACK
	v_lat *= exp(-grip * delta)
	# Sliding scrubs pace.
	v_fwd = move_toward(v_fwd, 0.0, absf(v_lat) * SCRUB * delta)
	# ---- throttle / brake.
	var cap: float = MAX_SPEED if on_track else MAX_SPEED_OFF_TRACK
	# V7b accelerator: cruise is untouched (boost defaults to 0 for every
	# writer that predates it -- KartLineInput, the probe); pushing raises
	# the cap toward BOOST_MAX_SPEED, never the cruise pace itself.
	cap *= lerpf(1.0, BOOST_SPEED_RATIO, clampf(input.boost, 0.0, 1.0))
	if input.brake:
		if v_fwd > 0.3:
			v_fwd = maxf(v_fwd - BRAKE_DECEL * delta, 0.0)
		else:
			v_fwd = move_toward(v_fwd, -REVERSE_SPEED, BRAKE_DECEL * 0.4 * delta)
	else:
		var target: float = cap * input.throttle
		var lambda: float
		if v_fwd > cap:
			lambda = OFF_TRACK_LAMBDA
		elif target > v_fwd:
			lambda = ACCEL_LAMBDA
		else:
			lambda = COAST_LAMBDA
		if v_fwd < 0.0 and input.throttle > 0.0:
			# Reversing and the throttle comes back: brake the reverse
			# firmly, then the ordinary curve takes over.
			v_fwd = move_toward(v_fwd, 0.0, BRAKE_DECEL * delta)
		else:
			v_fwd = lerpf(v_fwd, target, 1.0 - exp(-lambda * delta))
	velocity = fwd * v_fwd + rgt * v_lat
	global_position += velocity * delta
	global_position.y = 0.0
	_fence(fence)
	_animate(delta)
	_last_velocity = velocity

func _fence(fence: Rect2) -> void:
	var p := global_position
	var hit := false
	if p.x < fence.position.x:
		p.x = fence.position.x
		if velocity.x < 0.0:
			velocity.x = -velocity.x * FENCE_BOUNCE
			hit = true
	elif p.x > fence.end.x:
		p.x = fence.end.x
		if velocity.x > 0.0:
			velocity.x = -velocity.x * FENCE_BOUNCE
			hit = true
	if p.z < fence.position.y:
		p.z = fence.position.y
		if velocity.z < 0.0:
			velocity.z = -velocity.z * FENCE_BOUNCE
			hit = true
	elif p.z > fence.end.y:
		p.z = fence.end.y
		if velocity.z > 0.0:
			velocity.z = -velocity.z * FENCE_BOUNCE
			hit = true
	global_position = p
	if hit:
		_bump = 1.0

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
