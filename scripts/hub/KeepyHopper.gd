extends Node3D
class_name KeepyHopper
## Keepy crosses the plateau in discrete HOPS, never by sliding.
##
## =====================================================================
## WHY HOPS AND NOT A LERP TOWARDS THE TAP
##
## keepy_squirrel_hero.glb carries NO skeleton and NO animation -- measured
## on the file, not assumed: one node, one mesh, one primitive, zero skins,
## zero animations. A model that cannot deform can still read as alive if
## the thing moving it has weight, and a hop is the cheapest motion that
## has any: it has a takeoff, an airborne arc and a landing, so the eye is
## given three events per 0.35s instead of a constant velocity that reads
## as a sprite being dragged.
##
## Every channel below is PROCEDURAL, driven by tweens on transforms --
## the same technique scripts/battle/FighterView.gd uses on the same asset
## through the same ModelSlot, for the same reason.
##
## =====================================================================
## THE ONE RULE THAT MAKES IT FEEL HEAVY
##
## A tap landing DURING a hop never interrupts that hop. It replaces the
## destination, and the change is honoured at the next LANDING.
##
## This is the whole difference between "a character with weight" and "a
## cursor". If a tap could redirect mid-air, Keepy would snap direction in
## flight and every hop would look like it weighs nothing; worse, a player
## tapping repeatedly would see him jitter in place rather than travel.
## Committing to the hop in progress costs at most HOP_DURATION of
## responsiveness (0.35s) and buys a body that obeys momentum.
##
## The queue is deliberately DEPTH ONE. A queue of taps would replay a
## stale path the player has already changed their mind about; the only
## destination that has ever been interesting is the most recent one.

## Length of a single hop, in world units. Distance to the target shorter
## than this is covered by one final, shorter hop rather than by a partial
## one -- an abrupt half-length landing reads better than a hop that stops
## in mid-arc.
const HOP_DISTANCE: float = 1.5

## Peak height of the arc.
const HOP_HEIGHT: float = 0.6

## Wall-clock length of one hop, ground to ground.
const HOP_DURATION: float = 0.35

## How close to the target counts as arrived. Slightly under a third of a
## hop: below this, another hop would overshoot and Keepy would oscillate
## around the point forever.
const ARRIVE_EPSILON: float = 0.45

## Squash/stretch envelope, as multipliers on the model's authored scale.
## Compression at takeoff AND at landing, extension at the apex: this is
## the channel that carries the weight, and it is why the model does not
## need a skeleton to sell the motion.
const SQUASH_TAKEOFF: Vector3 = Vector3(1.18, 0.76, 1.18)
const STRETCH_APEX: Vector3 = Vector3(0.90, 1.16, 0.90)
const SQUASH_LAND: Vector3 = Vector3(1.22, 0.72, 1.22)

## Forward pitch, in degrees, at the top of the arc. Returns to flat by the
## landing frame -- a body that lands still tilted reads as a bug.
const PITCH_DEG: float = 14.0

## Emitted on every landing, with the world position landed on. The hub
## uses this and nothing else to decide whether a portal was reached:
## triggering on overlap instead would fire mid-flight, when Keepy is
## merely passing over a portal on the way somewhere else.
signal hop_landed(position: Vector3)

## Emitted when the last queued destination has been reached and Keepy is
## standing still. Not used for routing -- kept because "is he done moving"
## is the question any future camera or cue will want to ask.
signal became_idle()

## Yaw carrier. Kept separate from this node so world position (written by
## the hop) and facing (written by the turn) never contend for one
## transform, and separate from the model slot so pitch stays body-local.
@onready var _yaw: Node3D = $Yaw

## The ModelSlot drawing Keepy. Pitch and squash are written HERE, never on
## the slot's own model_* art corrections -- those are authored placement,
## this is animation, and the two must not fight over one property.
@onready var _body: ModelSlot = $Yaw/Body

var _base_scale: Vector3 = Vector3.ONE
var _base_pitch: float = 0.0

## Destination requested by the player. Depth one, on purpose (see header).
var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false

var _hopping: bool = false
var _hop_from: Vector3 = Vector3.ZERO
var _hop_to: Vector3 = Vector3.ZERO
var _hop_tween: Tween = null

func _ready() -> void:
	_base_scale = _body.scale
	_base_pitch = _body.rotation_degrees.x
	_target = global_position

## Asks Keepy to travel to `point`. Safe to call at any time and as often
## as the player taps: mid-hop it only replaces the destination, and the
## new one is acted on at the next landing.
func hop_to(point: Vector3) -> void:
	_target = Vector3(point.x, 0.0, point.z)
	_has_target = true
	if not _hopping:
		_advance()

## True while a hop is in the air. Read by the camera so it can hold still
## rather than chase the vertical arc.
func is_hopping() -> bool:
	return _hopping

func _advance() -> void:
	if not _has_target:
		return
	var here := Vector3(global_position.x, 0.0, global_position.z)
	var delta := _target - here
	if delta.length() <= ARRIVE_EPSILON:
		_has_target = false
		became_idle.emit()
		return
	_begin_hop(here, delta)

func _begin_hop(here: Vector3, delta: Vector3) -> void:
	var step: float = minf(HOP_DISTANCE, delta.length())
	_hop_from = here
	_hop_to = here + delta.normalized() * step

	# Face the direction BEFORE leaving the ground: a body that rotates in
	# mid-air looks like it is being steered, which is exactly the reading
	# the commit-to-the-hop rule above exists to avoid.
	_face(delta)

	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_hopping = true
	# ONE tween driving a normalised 0..1, not three parallel property
	# tweens: the arc is a parabola and the squash is piecewise, neither of
	# which a property tween can express. Position, scale and pitch are all
	# written from the same t, so they cannot drift apart.
	_hop_tween = create_tween()
	_hop_tween.tween_method(_apply_hop, 0.0, 1.0, HOP_DURATION)
	_hop_tween.finished.connect(_on_hop_finished, CONNECT_ONE_SHOT)

func _face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.000001:
		return
	# The model faces +Z at model_rotation_degrees zero (measured on the
	# .glb by rendering it, and the same orientation resources/battle
	# /keepy.tres relies on), so the yaw is atan2 of the direction itself.
	# Set, not tweened: this runs while Keepy is still on the ground, one
	# frame before the arc starts, so there is no airborne steering to see.
	# A turn spread over the hop would be exactly the mid-air redirection
	# the commit rule above rejects.
	_yaw.rotation_degrees.y = rad_to_deg(atan2(flat.x, flat.z))

func _apply_hop(t: float) -> void:
	var ground := _hop_from.lerp(_hop_to, t)
	# 4t(1-t) peaks at exactly 1.0 at t = 0.5 and is exactly 0 at both
	# ends, so the arc cannot leave Keepy hovering on a rounding error.
	var height: float = HOP_HEIGHT * 4.0 * t * (1.0 - t)
	global_position = Vector3(ground.x, height, ground.z)
	_body.scale = _squash_at(t)
	_body.rotation_degrees.x = _base_pitch - PITCH_DEG * sin(PI * t)

func _squash_at(t: float) -> Vector3:
	# Four segments: compress off the ground, extend into the apex, relax
	# back down, absorb the landing. Each is a plain lerp between two
	# authored multipliers, so retuning the feel is editing a constant.
	if t < 0.12:
		return _base_scale * SQUASH_TAKEOFF.lerp(STRETCH_APEX, t / 0.12)
	if t < 0.5:
		return _base_scale * STRETCH_APEX
	if t < 0.86:
		return _base_scale * STRETCH_APEX.lerp(Vector3.ONE, (t - 0.5) / 0.36)
	return _base_scale * Vector3.ONE.lerp(SQUASH_LAND, (t - 0.86) / 0.14)

func _on_hop_finished() -> void:
	_hopping = false
	global_position = Vector3(_hop_to.x, 0.0, _hop_to.z)
	_body.rotation_degrees.x = _base_pitch
	# Landing recoil, then back to rest. Started AFTER the hop tween has
	# finished so it can never be killed by the next hop mid-recoil -- the
	# next hop's own takeoff squash overwrites the scale anyway.
	var recoil := create_tween()
	recoil.tween_property(_body, "scale", _base_scale, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	hop_landed.emit(global_position)
	# Ordered deliberately: listeners see the landing BEFORE the next hop
	# starts, so a portal reached on this landing routes away instead of
	# being overrun by a queued destination beyond it.
	_advance()
