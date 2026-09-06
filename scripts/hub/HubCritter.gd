extends Node3D
class_name HubCritter
## Carte-blanche V6 -- a non-player animal drawn from a SINGLE RIGID MESH
## (the five Meshy characters of 5 septembre 2026 carry no skin and no
## clip), walked and posed entirely by code.
##
## =====================================================================
## WHAT IT IS, AND WHAT IT DELIBERATELY IS NOT
##
## `HubActorWalker` walks a Mixamo rig and plays its clip; this walks a
## rigid model and FAKES the gait: a bob, a roll and a pitch on the model
## child, phased by the distance actually travelled so a body that stops
## stops bobbing (no foot to slide, but the same discipline -- the cadence
## is tied to the ground covered, never to the wall clock).
##
## THIS NODE IS AN EMPTY CARRIER. Rotation and translation live here; the
## SCALE lives on the model child and nowhere else -- the CLAUDE.md rule
## that a carrier never carries the scale of the thing it represents. A
## rider's seat (`KeepyHopper.mount_carrier`) is written in THIS node's
## local space, in Keepy's own units, and `to_global()` must not multiply
## it by the animal's size.
##
## NO `_process` OF ITS OWN. The owner calls `step(delta)`, then writes
## whatever rides it in the SAME call -- carrier-then-carried, the
## turnstile's one-frame-lag measurement. Two nodes each with their own
## `_process` is exactly how a rider ends up a frame behind its mount.
##
## The model faces +Z at yaw zero -- MEASURED on all four characters
## (CritterInspect renders, journal V6), the convention Keepy and the bear
## already use -- so the heading is `atan2(dir.x, dir.z)`, as everywhere
## else in the hub.

enum State { IDLE, WALKING }

signal arrived

## Ground speed while WALKING, units per second. The owner sets it per
## trip (a trot home is not a charge).
var speed: float = 2.5
## Turn sharpness, the same exponential form and units as
## HubActorWalker.turn_lambda / HubCamera.FOLLOW_LAMBDA.
var turn_lambda: float = 6.0
## Below this the destination is reached (HubActorWalker's own epsilon).
const ARRIVE_EPSILON: float = 0.05
const TURN_SETTLE_EPSILON: float = 5.0 * PI / 180.0
## Shorter than the scatter's 82 u leash, MEASURED at the spawn frame: at
## 82 the boar (65 u from the spawn camera, 65 % fogged) still cost its
## whole 4 726-tri mesh -- gpu 68 325 -> 73 051. At 52 u the fog has eaten
## 56 % of it and it pops in as a faint silhouette.
const CULL_DISTANCE: float = 52.0
## CH30: the range this instance actually uses, so a critter that is seen
## from a CHASE camera can be given a longer leash than one walking the
## hub under the fixed one. Written by the owner BEFORE setup_model();
## default is the hub's own number, so nothing that predates CH30 moves.
##
## ⚠️ IT IS PER INSTANCE AND NOT A NEW GLOBAL, deliberately. The 52 u
## above was measured against the SPAWN FRAME and the hub's triangle
## budget is already over its plafond there (73 861 gpu); raising it for
## every critter would aggravate exactly the frame that cannot afford it.
## The kart's riders are on the circuit, 100 u from the spawn, so their
## longer leash costs the spawn nothing.
var cull_distance: float = CULL_DISTANCE

## The gait: one cycle per `gait_stride` units of ground covered.
var gait_stride: float = 1.1
var gait_bob: float = 0.06
var gait_roll_deg: float = 4.0
var gait_pitch_deg: float = 2.5
## Idle breath: a slow scale swell on the model, always on.
var breath_amount: float = 0.012
var breath_hz: float = 0.75
## 0..1: a fast small jitter (cold, fright). Written by the owner.
var shiver: float = 0.0
## Extra pose the owner writes on top of the gait -- a nose-down dig, a
## bow, a curl. Degrees about the model's X; a y-scale multiplier.
var pose_pitch_deg: float = 0.0
var pose_squash: float = 1.0
## A one-shot scale punch (a squeak, a snort): set to 1, decays to 0.
var punch: float = 0.0

var _state: int = State.IDLE
var _target: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _turn_target: float = NAN
var _model: Node3D = null
var _lift: float = 0.0
var _scale: float = 1.0
var _phase: float = 0.0
var _gait_weight: float = 0.0
var _time: float = 0.0

## Draws `scene` (a .glb PackedScene) under this node at `scale`, with its
## origin raised by `lift` so the model's lowest vertex sits on y = 0.
## Both numbers are MEASURED by the owner on the imported mesh (vertex
## extents, never get_aabb() through a scaled node) and published there.
func setup_model(scene: PackedScene, scale: float, lift: float) -> void:
	if _model != null:
		_model.queue_free()
	_model = scene.instantiate() as Node3D
	if _model == null:
		push_error("HubCritter: the model scene does not instantiate to a Node3D")
		return
	_model.name = "Model"
	_scale = scale
	_lift = lift
	_model.scale = Vector3.ONE * scale
	_model.position = Vector3(0.0, lift, 0.0)
	add_child(_model)
	# Distance culling, the scatter's own rule (CLAUDE.md: visibility_range
	# works in Compatibility as pure CPU culling with the fade DISABLED):
	# an animal 80 u away is behind 72 % of fog and costs its whole mesh.
	for mi in _meshes(_model):
		mi.visibility_range_end = cull_distance
		mi.visibility_range_end_margin = 4.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_write_pose()

func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

func model() -> Node3D:
	return _model

func drawn_scale() -> float:
	return _scale

func lift() -> float:
	return _lift

func walk_to(point: Vector3) -> void:
	_turn_target = NAN
	_target = Vector3(point.x, 0.0, point.z)
	if flat().distance_to(_target) <= ARRIVE_EPSILON:
		_arrive()
		return
	_state = State.WALKING

## Stops where it stands, with no arrival.
func halt() -> void:
	_state = State.IDLE

func is_walking() -> bool:
	return _state == State.WALKING

func target() -> Vector3:
	return _target

## Turns at once, with no ease (placing, not animating). Writes both the
## node and the eased heading, HubActorWalker.face()'s own rule.
func face(direction: Vector3) -> void:
	var f := Vector2(direction.x, direction.z)
	if f.length_squared() < 1.0e-8:
		return
	_yaw = atan2(direction.x, direction.z)
	rotation.y = _yaw
	_turn_target = NAN

## Eases the heading to `direction` without walking.
func turn_to(direction: Vector3) -> void:
	if _state == State.WALKING:
		return
	var f := Vector2(direction.x, direction.z)
	if f.length_squared() < 1.0e-8:
		return
	_turn_target = atan2(direction.x, direction.z)

func facing() -> Vector3:
	return Vector3(sin(_yaw), 0.0, cos(_yaw))

func flat() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)

## Advances the walk / the turn by `delta` and writes the model's pose.
## Called by the owner, once per frame, BEFORE whatever rides this node.
func step(delta: float) -> void:
	_time += delta
	punch = maxf(0.0, punch - delta * 4.5)
	var moved: float = 0.0
	if _state == State.WALKING:
		var here: Vector3 = flat()
		var to_target: Vector3 = _target - here
		var dist: float = to_target.length()
		if dist > ARRIVE_EPSILON:
			var wanted: float = atan2(to_target.x, to_target.z)
			var weight: float = 1.0 - exp(-turn_lambda * delta)
			_yaw = lerp_angle(_yaw, wanted, weight)
			rotation.y = _yaw
		var stride: float = speed * delta
		if dist <= maxf(stride, ARRIVE_EPSILON):
			global_position = Vector3(_target.x, global_position.y, _target.z)
			moved = dist
			_arrive()
		else:
			var next: Vector3 = here + to_target / dist * stride
			global_position = Vector3(next.x, global_position.y, next.z)
			moved = stride
	elif not is_nan(_turn_target):
		var weight: float = 1.0 - exp(-turn_lambda * delta)
		_yaw = lerp_angle(_yaw, _turn_target, weight)
		rotation.y = _yaw
		if absf(angle_difference(_yaw, _turn_target)) < TURN_SETTLE_EPSILON:
			_yaw = _turn_target
			rotation.y = _yaw
			_turn_target = NAN
	# The gait phase advances with the GROUND COVERED; its weight eases in
	# and out so a start and a stop read as a body, not a switch.
	if moved > 0.0:
		_phase += moved / maxf(gait_stride, 0.05) * TAU
		_gait_weight = minf(1.0, _gait_weight + delta * 6.0)
	else:
		_gait_weight = maxf(0.0, _gait_weight - delta * 6.0)
	_write_pose()

func _arrive() -> void:
	_state = State.IDLE
	arrived.emit()

func _write_pose() -> void:
	if _model == null:
		return
	var g: float = _gait_weight
	var bob: float = gait_bob * absf(sin(_phase)) * g
	var roll: float = deg_to_rad(gait_roll_deg) * sin(_phase) * g
	var pitch: float = deg_to_rad(gait_pitch_deg) * sin(_phase * 2.0) * g + deg_to_rad(pose_pitch_deg)
	var jitter: float = shiver * 0.018 * sin(_time * 47.0)
	var breath: float = 1.0 + breath_amount * sin(_time * TAU * breath_hz) + punch * 0.22
	_model.position = Vector3(jitter, _lift + bob, 0.0)
	_model.rotation = Vector3(pitch, 0.0, roll + shiver * deg_to_rad(1.5) * sin(_time * 41.0))
	_model.scale = Vector3(_scale * (1.0 + punch * 0.10), _scale * pose_squash * breath, _scale * (1.0 + punch * 0.10))
