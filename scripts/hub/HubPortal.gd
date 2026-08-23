extends Area3D
class_name HubPortal
## One entrance on the plateau. Knows WHICH game it stands for and nothing
## about where that game lives -- routing is HubRouter's job.
##
## =====================================================================
## WHY IT DOES NOT USE body_entered
##
## An Area3D would happily report an overlap, and that is the wrong event.
## Keepy travels in arcs: a hop aimed past a portal passes THROUGH its
## volume in mid-air, and an overlap-triggered portal would swallow the
## player on the way to somewhere else. The portal therefore answers a
## question -- "was this landing inside me?" -- that HubWorld asks only on
## KeepyHopper.hop_landed.
##
## The Area3D and its CollisionShape3D are kept anyway, and are the SINGLE
## source of truth for the radius: the shape is what an author sees and
## drags in the editor, so reading the number off it means the trigger can
## never disagree with the thing drawn.

## Which game this portal stands for. Matched against HubRouter.ROUTES.
@export var game_id: StringName = &""

## Distance at which the portal starts pulsing, as a multiple of its own
## radius. Purely a cue: it changes nothing about when entry triggers.
const NEAR_FACTOR: float = 2.2

## Hysteresis on that cue, so a Keepy standing right on the boundary does
## not flicker the pulse on and off once per hop.
const NEAR_RELEASE: float = 2.6

const PULSE_SCALE: float = 1.14
const PULSE_S: float = 0.55

## Carries the label alongside the id: both are this portal's own authored
## data (game_id from the layout, the text from its own sign), and the
## confirmation step downstream needs the name without going and finding a
## second table that maps ids to names.
signal portal_entered(game_id: StringName, label: String)

@onready var _shape: CollisionShape3D = $Shape
@onready var _ring: MeshInstance3D = $Ring
@onready var _label: Label3D = $Label

var _radius: float = 1.0
var _base_scale: Vector3 = Vector3.ONE
var _near: bool = false
var _pulse: Tween = null

func _ready() -> void:
	# Never monitoring: this node deliberately has no physics behaviour.
	# Leaving it on would cost a broadphase entry per frame for an event
	# nothing listens to, and would invite a future reader to wire
	# body_entered back up -- the exact mistake the header rejects.
	monitoring = false
	monitorable = false
	_base_scale = _ring.scale
	var cylinder := _shape.shape as CylinderShape3D
	if cylinder:
		_radius = cylinder.radius
	else:
		push_error("HubPortal '%s': Shape must hold a CylinderShape3D." % name)

## True when `point` (a landing position) is inside this portal's footprint.
## Compared on the ground plane only: height is the arc's business, and a
## landing is always at y = 0 anyway.
func landed_within(point: Vector3) -> bool:
	return _ground_distance(point) <= _radius

## Emits portal_entered. Called by HubWorld rather than by this node, so
## the decision "a landing counts as an entry" stays in one place instead
## of being duplicated per portal.
func enter() -> void:
	portal_entered.emit(game_id, display_label())

## The game's name as painted on the plateau.
##
## Read back off the Label3D that HubBuilder already filled from
## resources/hub/hub_layout.tres, rather than stored a second time: the
## confirmation dialog must name the game the player is standing on, and
## a separate copy of that string is a copy free to drift from the sign.
func display_label() -> String:
	return _label.text if _label else ""

## Feeds the approach cue. Called once per frame by HubWorld with Keepy's
## position -- the portal stays ignorant of who is approaching, and of
## whether anyone is.
func set_proximity(point: Vector3) -> void:
	var distance := _ground_distance(point)
	if _near:
		if distance > _radius * NEAR_RELEASE:
			_set_near(false)
	elif distance <= _radius * NEAR_FACTOR:
		_set_near(true)

func _ground_distance(point: Vector3) -> float:
	var here := global_position
	return Vector2(point.x - here.x, point.z - here.z).length()

func _set_near(value: bool) -> void:
	if _near == value:
		return
	_near = value
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	if not _near:
		_pulse = create_tween()
		_pulse.tween_property(_ring, "scale", _base_scale, 0.2) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_ring, "scale", _base_scale * PULSE_SCALE, PULSE_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_ring, "scale", _base_scale, PULSE_S * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
