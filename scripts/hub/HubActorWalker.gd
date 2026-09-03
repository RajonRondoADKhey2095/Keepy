extends Node3D
class_name HubActorWalker
## A non-player actor that walks, on the ground, from where it stands to a
## point it is TOLD -- never to a point it knows.
##
## GENERIC ON PURPOSE. Nothing in here names a bear, a seesaw or the hub:
## the model, its scale, its walk clip, its speed and every destination
## arrive as data. The one thing it does know is that it walks on the flat,
## which is the plateau's own model (`HubRegion` throws y away, and
## `HubTapInput` raycasts a single `Plane(UP, 0)`) -- so this is not a
## limitation this script invents, it is the ground the hub already is.
##
## ⚠️ WHY THE TRAVEL IS CONSTANT-SPEED AND NOT HubCamera'S EXPONENTIAL LERP
##
## `HubCamera` smooths with `weight = 1 - exp(-lambda * delta)`, and that
## form is the right one for anything whose only requirement is to be
## frame-rate independent. It is the WRONG form for feet: a lerp's speed is
## proportional to the distance still to cover, so one and the same walk
## cycle would be played at ~9 u/s at the start of a 6-unit trip and at
## ~0 u/s at the end of it. A character whose legs cycle at a fixed cadence
## while its ground speed swings by an order of magnitude is the definition
## of foot-sliding -- the exact thing this lot was told to avoid.
##
## So the POSITION moves at a constant `walk_speed` (`move_toward`, which is
## already frame-rate independent because it is metres-per-second), and the
## exponential form is kept for the FACING, where it belongs: a turn has no
## cadence to disagree with, and snapping the yaw would read as the actor
## pivoting on the spot.
##
## ⚠️ ARRIVAL IS A SNAP, NOT AN ASYMPTOTE. `move_toward` does land exactly,
## but the last step is a partial one, so the test is the same `ARRIVE_EPSILON`
## shape `KeepyHopper._advance()` uses rather than an equality on floats.

enum State { IDLE, WALKING, ARRIVED }

## Ground speed in units per second while WALKING.
##
## ⚠️ DERIVED FROM THE CLIP'S OWN STANCE PHASE, not picked, and not derived
## from stride length either.
##
## The only speed at which a foot does not skate is the speed at which the
## PLANTED foot travels backwards in the rig's own frame. So the reconning
## probe sampled every bone across the shipped `Walking` clip (length
## 1.033333 s, 24 bones, authored loop_mode NONE), kept the frames where a
## foot is at its lowest -- i.e. on the ground -- and fitted dz/dt across
## that contiguous stance window, with the rig already at its 1.130876
## scale:
##
##     LeftToeBase   18/64 frames   0.7501 u/s
##     LeftFoot      15/64 frames   0.7332 u/s
##     RightFoot     20/64 frames   0.7835 u/s
##     RightToeBase   7/64 frames   1.1586 u/s   <- DISCARDED
##
## The outlier is discarded on its sample count, not on its value: seven
## frames is a stance window the threshold cut short, so its slope is
## carrying the toe's roll through toe-off rather than the ground speed.
## The three that agree average 0.7556.
##
## A whole-cycle stride estimate would have said 0.81-1.05 depending on
## whether it read the ankle or the toe, and that spread is exactly why the
## stance fit was done instead.
@export var walk_speed: float = 0.7556

## Multiplies the ground speed AND the clip's playback, together.
##
## ⚠️ ONE KNOB AND NOT TWO, AND THAT IS THE WHOLE POINT. `walk_speed` above
## is the speed at which the PLANTED foot travels backwards in the rig's own
## frame at playback rate 1.0 -- the only speed at which a foot does not
## skate. That relation is exactly linear in the playback rate: run the clip
## at k and the planted foot sweeps ground k times faster, so the
## no-foot-slide speed is `walk_speed * k`. Exposing the two separately is
## how a caller ends up asking for a faster walk and getting a moonwalk;
## exposing the ratio makes the invariant structural instead of remembered.
##
## 1.0 is the measured cadence. The hub's bear is driven above it because
## the seesaw it is called over to only rocks for `SEESAW_ROCK_S`, and an
## actor that arrives after the ride is over has not arrived -- see
## `HubWorld.BEAR_WALK_RATE` for that timing budget.
@export var walk_rate: float = 1.0

## How sharply the actor turns onto its heading. Same exponential form and
## the same units as `HubCamera.FOLLOW_LAMBDA`; larger is snappier.
@export var turn_lambda: float = 6.0

## Below this, the destination is reached. Same value and the same reason as
## `KeepyHopper.ARRIVE_EPSILON`: a walk ends NEAR its target, and testing
## for equality on a float never ends at all.
@export var arrive_epsilon: float = 0.05

## The rig to draw. Supplied by the caller so this script stays an actor and
## not one particular animal.
@export var model_scene: PackedScene

## Uniform scale for the rig, in the caller's units. For the bear this is
## the 1.130876 Lot B measured off `get_bone_global_pose()` -- see
## `BearAnimSpike.gd` for why an AABB reads a hundredfold low here.
@export var model_scale: float = 1.0

## The looping clip played while WALKING.
@export var walk_anim: StringName = &"Walking"

signal arrived

var _state: int = State.IDLE
var _target: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _model: Node3D = null
var _player: AnimationPlayer = null
## The name the actor plays. NOT `walk_anim`: the clip is duplicated into
## a per-instance library in _ready(), for the shared-resource reason
## _freeze() spells out.
var _clip_name: StringName = &""
var _clip_length: float = 0.0


func _ready() -> void:
	set_process(false)
	if model_scene == null:
		push_error("HubActorWalker: no model_scene set; nothing to draw.")
		return
	_model = model_scene.instantiate() as Node3D
	_model.scale = Vector3.ONE * model_scale
	add_child(_model)
	_force_unshaded(_model)
	_player = _find_player(_model)
	if _player == null or not _player.has_animation(walk_anim):
		push_error("HubActorWalker: animation %s not found on the rig." % walk_anim)
		return
	# ⚠️ THE CLIP IS DUPLICATED, AND THIS IS NOT TIDINESS.
	#
	# The shipped `Walking` clip is authored loop_mode NONE (measured: 0),
	# so somebody has to make it loop. Writing that on the clip the player
	# hands back writes it on the SHARED resource -- `instantiate()` copies
	# nodes, not the Animations they point at -- so a second actor drawn
	# from the same glb, or the Lot B spike scene, would silently inherit
	# it. Same family as the importer's single shared material that
	# `_force_unshaded` duplicates its way out of, one resource type over.
	#
	# So this actor gets its own library, and the glb's own clip is never
	# written to at all.
	var clip: Animation = _player.get_animation(walk_anim).duplicate()
	clip.loop_mode = Animation.LOOP_LINEAR
	var lib := AnimationLibrary.new()
	lib.add_animation(&"walk", clip)
	_player.add_animation_library(&"actor", lib)
	_clip_name = &"actor/walk"
	_clip_length = clip.length
	# The other half of `walk_rate`. Written on the PLAYER, never on the clip:
	# a speed baked into an Animation would be a shared-resource write, the
	# same trap the duplicate above exists to close.
	_player.speed_scale = maxf(walk_rate, 0.0001)
	_yaw = rotation.y
	_freeze()


## Sends the actor walking to `point`. Y is discarded: the plateau is flat
## and the caller's y is never the actor's business.
##
## ⚠️ THE DESTINATION IS AN ARGUMENT AND NEVER A CONSTANT. A seesaw-shaped
## number living in here is how this stops being an actor and becomes one
## prop's animation.
func walk_to(point: Vector3) -> void:
	_target = Vector3(point.x, 0.0, point.z)
	if _flat().distance_to(_target) <= arrive_epsilon:
		# Already there. Arriving is still the honest answer -- a caller
		# that asked for a walk gets told the walk is over, rather than
		# being left waiting on a signal that a zero-length trip would
		# never emit. Same shape as the zero-length-walk case the cabin's
		# hotspots had to learn about the hard way.
		_arrive()
		return
	_state = State.WALKING
	if _player != null:
		_player.play(_clip_name)
	set_process(true)


func is_walking() -> bool:
	return _state == State.WALKING


func state() -> int:
	return _state


func clip_length() -> float:
	return _clip_length


## The speed the feet actually travel at: the measured cadence scaled by
## `walk_rate`. Published so a caller can budget a walk without re-deriving
## the product, and so a probe reads the number the actor really uses rather
## than the one it was configured with.
func ground_speed() -> float:
	return walk_speed * maxf(walk_rate, 0.0001)


## Turns the actor to face `direction` at once, with no ease.
##
## ⚠️ WRITES BOTH `rotation.y` AND `_yaw`, and the second half is the point.
## `_process` eases FROM `_yaw`, so a caller that set only the node's
## rotation would see the next walk snap back to whatever heading the actor
## last eased to -- a turn that visibly un-does itself one frame into the
## departure. Nothing else in this script touches `_yaw` from outside.
##
## No ease because the callers that need this are placing the actor, not
## animating it: a rider written onto a moving prop every frame has to be
## AT its pose when the frame is drawn, not on its way to it.
func face(direction: Vector3) -> void:
	var flat := Vector2(direction.x, direction.z)
	if flat.length_squared() < 1.0e-8:
		return
	_yaw = atan2(direction.x, direction.z)
	rotation.y = _yaw


func _process(delta: float) -> void:
	var here: Vector3 = _flat()
	var to_target: Vector3 = _target - here
	var dist: float = to_target.length()

	# Face where the travel is going, not where the destination is: on the
	# last partial step those differ by nothing, and on the first they are
	# the same vector, but reading it off the travel keeps a future caller
	# that re-targets mid-walk from snapping the actor round.
	if dist > arrive_epsilon:
		# The rig's face is model +Z -- MEASURED, not assumed: rendered
		# through the hub's own camera (which looks down -Z, so it sees a
		# node's +Z side) at rotation zero, the bear's face, hat and belt
		# are all in view. Same convention Keepy's own model uses.
		var wanted: float = atan2(to_target.x, to_target.z)
		var weight: float = 1.0 - exp(-turn_lambda * delta)
		_yaw = lerp_angle(_yaw, wanted, weight)
		rotation.y = _yaw

	var step: float = ground_speed() * delta
	if dist <= maxf(step, arrive_epsilon):
		global_position = Vector3(_target.x, global_position.y, _target.z)
		_arrive()
		return
	var moved: Vector3 = here + to_target / dist * step
	global_position = Vector3(moved.x, global_position.y, moved.z)


func _arrive() -> void:
	_state = State.ARRIVED
	set_process(false)
	_freeze()
	arrived.emit()


## Holds a single static pose instead of animating.
##
## ⚠️ PAUSING, NEVER A loop_mode WRITE. Pausing is per-PLAYER; a loop_mode
## is per-RESOURCE, and `instantiate()` shares resources between instances
## of the same PackedScene -- so an Animation edited to make ONE actor stop
## would stop every actor drawn from the same glb. The clip this plays is
## this actor's own duplicate (see _ready) precisely so that even the
## looping write cannot escape it.
##
## A walk cycle's last frame is its first frame -- that is what makes it a
## cycle -- so seeking to 0 and seeking to `length` hold the same pose, and
## 0 is the one that cannot wrap.
func _freeze() -> void:
	if _player == null:
		return
	_player.play(_clip_name)
	_player.seek(0.0, true)
	_player.pause()


## Holds a static pose taken from ANY clip the rig ships, at any time in
## it. `_freeze()` generalised, and the one route this project has to a
## pose the animator never authored.
##
## ⚠️ WHY THIS AND NOT `Skeleton3D.set_bone_pose()`. RECON 3
## (docs/lots/CH21_TYROLIENNE.md) measured both rigs: they carry `Running`
## and `Walking` and NOTHING else -- no hang, no grip, no idle -- and a
## grep over this repo finds ZERO uses of `set_bone_pose*`, so per-bone
## posing would be a first for the project and would need its own
## red-before-green pass to be trusted. Seeking an existing clip to a
## MEASURED frame is the mechanism `_freeze()` already uses and already
## ships.
##
## ⚠️ THE ORIGINAL CLIP, NOT THE DUPLICATE, AND NOTHING IS WRITTEN TO IT.
## `_freeze()` plays this actor's own duplicated `actor/walk` because that
## clip had its `loop_mode` REWRITTEN, which is a shared-resource write.
## Nothing here writes anything: `play` / `seek` / `pause` are all per
## PLAYER, so holding the glb's own `Running` at a frame cannot escape this
## instance the way a `loop_mode` would.
##
## A time outside the clip is clamped rather than refused: a caller that
## measured a frame off a slightly different export should get the nearest
## real pose, not a rig that silently keeps walking.
func freeze_at(clip: StringName, time: float) -> void:
	if _player == null:
		return
	if not _player.has_animation(clip):
		push_error("HubActorWalker: no clip %s on this rig; the pose was not taken." % clip)
		return
	_state = State.ARRIVED
	set_process(false)
	_player.play(clip)
	_player.seek(clampf(time, 0.0, _player.get_animation(clip).length), true)
	_player.pause()


## Tilts the DRAWN RIG about its own X, leaving this node's yaw alone.
##
## ⚠️ ON THE MODEL AND NOT ON THIS NODE, and that is load-bearing rather
## than tidy. `face()` and `_process` write `rotation.y` on THIS node; a
## pitch written beside it would compose into one Euler triple, so every
## turn would swing the lean around with it and `_yaw` would no longer be
## the whole of the heading. The model child carries no yaw of its own, so
## a pitch there is exactly a pitch.
func set_model_pitch(degrees: float) -> void:
	if _model == null:
		return
	_model.rotation_degrees.x = degrees


## Forces every drawn surface UNSHADED, on a DUPLICATE of the material.
##
## ⚠️ THE HUB HAS NO LIGHTS AT ALL -- measured, zero `Light3D` nodes -- so
## this is the project's standing rule (only an unshaded surface has a
## KNOWN colour), applied to an actor that would otherwise be at the mercy
## of whatever its import happened to set.
##
## For this particular rig it is currently a no-op ON PIXELS: as imported it
## carries `metallic = 1`, which zeroes the diffuse term the hub's ambient
## COLOUR is the only thing able to feed, so nothing but its EMISSION map
## draws -- and that map is byte-identical to its albedo map. Lit and
## unshaded therefore render the same picture, measured at 0 of 2 073 600
## differing pixels, with the ambient cranked to red at 3.0 and with the
## ambient disabled outright both leaving it unchanged.
##
## That equality is exactly why this is forced rather than left alone: it
## rests on an emissive map surviving every future re-export. Drop that map
## and a fully metallic surface under no lights draws BLACK, silently. On
## albedo it cannot.
##
## The material is DUPLICATED before writing because the glTF importer binds
## ONE shared material on the mesh; writing through it tints every instance
## of this glb in the project. Same rule `FighterView._ensure_material()`
## states for this same squirrel-and-friends asset family.
func _force_unshaded(root: Node) -> void:
	for mi in _meshes(root):
		for surf in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(surf)
			if src is not BaseMaterial3D:
				continue
			var mat: BaseMaterial3D = (src as BaseMaterial3D).duplicate()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.set_surface_override_material(surf, mat)


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


## Depth-first, because the glTF importer's node names are its own business
## -- the same reason BearAnimSpike.gd searches rather than hard-codes.
func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var found: AnimationPlayer = _find_player(c)
		if found != null:
			return found
	return null


func _flat() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)
