extends Node3D
class_name LevelWalker
## The body: a chain of hops across ONE level, and the arc between two.
##
## =====================================================================
## THE HOP CHAIN IS KeepyHopper'S, DELIBERATELY REBUILT AND NOT IMPORTED
##
## Same shape, same commit-to-the-hop rule, same generalised arc. It is
## rewritten here because this system must not depend on the hub -- that
## is the whole constraint of this batch -- and importing KeepyHopper would
## chain every future level to HubWorld, HubBuilder and the plateau layout.
##
## What that costs, said plainly: two implementations of a hop now exist,
## and they can drift. What it buys is a navigation core that runs with no
## hub in the scene at all, which is what makes it a candidate to REPLACE
## the hub's navigation later rather than sit beside it forever.
##
## =====================================================================
## THE ONE RULE THAT MAKES IT FEEL HEAVY, kept
##
## A tap landing DURING a hop never interrupts it. It replaces the
## destination, honoured at the next LANDING. The queue is DEPTH ONE: a
## queue of taps would replay a path the player has already changed their
## mind about.
##
## =====================================================================
## THE GENERALISED ARC IS THE ONE THING REUSED FROM THE HUB'S DESIGN
##
## KeepyHopper already carries `_hop_from_y` / `_hop_to_y` -- a hop drawn
## on a sloped base line rather than a flat one -- added for the dive off
## the diving board and proved EXACT at equal endpoints (DivingBoardProbe
## PHASE A samples it against the pre-change formula: worst divergence
## 0.000000000000 u over 1001 points, on three different hops).
##
## ⚠️ BUT EVERY CALLER THERE HARD-CODES `_hop_to_y = 0.0`. The board's
## dive, the boat's eject, the turnstile, the seesaw and the owl dismount
## all end at zero, and `_begin_hop` re-zeroes both on every ordinary hop.
## So the mechanism for travelling at a non-zero altitude exists and has
## never been reachable. Here it is bidirectional: a hop's base line is
## the CURRENT LEVEL'S floor, and a crossing's runs from one level's floor
## to another's.
##
## =====================================================================
## WHY THIS IS NOT THE TURNSTILE / SEESAW / OWL PATTERN
##
## Those three also change Keepy's height, so they look like the obvious
## precedent. They are not, and the difference is not cosmetic:
##
##   they are TRANSIENT      a tween ends them; a level persists
##   the PROP writes the body every frame; on a level nobody does
##   taps are INTERCEPTED and dropped; on a level taps must become
##                           destinations -- that IS the level
##   they always exit to y = 0, hard-coded
##
## A level Keepy cannot walk on is not a level, it is a seat. Studied and
## rejected as a state pattern; only their arc is kept, above.

## Length of one hop, in world units.
const HOP_DISTANCE: float = 1.5
## Duration of one hop. A 0.28 s hop occupies 17 frames at 60 fps
## (0.2833 s), so a measured trip costs ~1.2% more than the nominal
## arithmetic -- quote the measured row, never the multiplication.
const HOP_DURATION: float = 0.28
## Arc height of an ordinary hop.
const HOP_HEIGHT: float = 0.6
## Close enough to the destination to stop, rather than take a hop
## shorter than it is worth watching.
const ARRIVE_EPSILON: float = 0.45

## Arc height of a crossing, ON TOP of the climb or drop between the two
## floors. Bigger than an ordinary hop because a crossing is a bigger
## event than a step -- the same escalation the hub's own specials argue
## for (its mount is 0.40, its eject 1.05, its dive 1.55).
const CROSSING_ARC_HEIGHT: float = 0.9
## How long a crossing takes. Longer than a hop: it covers more ground and
## more height, and a crossing that took a hop's time would read as a
## teleport with an arc drawn on it.
const CROSSING_DURATION: float = 0.62

## How close to a link's entry point counts as having arrived there.
## Compared against the entry, in XZ -- the arrival is on the floor by
## construction, so height cannot disagree.
const ENTRY_REACH: float = 0.9

enum State { IDLE, HOPPING, CROSSING }

signal hop_landed(position: Vector3)
signal became_idle()
## Emitted once per crossing, at its two ends. The level index has ALREADY
## changed by the time `crossing_finished` fires -- a listener that reads
## the controller inside the handler sees the new level, never a half
## state.
signal crossing_started(link: LevelTransition, to_index: int)
signal crossing_finished(link: LevelTransition, to_index: int)

## The controller, as a scene-authored path. NodePath for the reason
## LevelController's own exports are.
@export var controller_path: NodePath

var controller: LevelController = null

var _state: State = State.IDLE
var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _hop_from: Vector3 = Vector3.ZERO
var _hop_to: Vector3 = Vector3.ZERO
var _hop_from_y: float = 0.0
var _hop_to_y: float = 0.0
var _hop_height: float = HOP_HEIGHT
var _tween: Tween = null

## The link the player asked for, held until he actually reaches its
## entry.
##
## ⚠️ IT SURVIVES A PASS-THROUGH LANDING, and that is measured rather than
## assumed to be needed: the owl batch shipped a version that cleared the
## intent on the FIRST landing whatever it was, so any walk longer than one
## hop ended with Keepy standing next to the prop having never boarded it.
## The probe was green anyway -- it only broke once a control tap pushed
## the walk out to two hops. Released on a successful crossing, on another
## tap, or on arriving with nothing left to do.
var _pending: LevelTransition = null

## The link currently being crossed. Non-null only while CROSSING.
var _crossing: LevelTransition = null
var _crossing_to: int = -1

func _ready() -> void:
	controller = get_node_or_null(controller_path) as LevelController
	if controller == null:
		push_error("LevelWalker: controller_path does not resolve to a LevelController.")

## Floor height of the level he is on. ONE owner -- the controller -- read
## rather than mirrored: a walker carrying its own copy of "where the
## ground is" is how a body and its world end up on different storeys.
func _ground_y() -> float:
	return 0.0 if controller == null else controller.ground_y()

func state() -> State:
	return _state

func is_crossing() -> bool:
	return _state == State.CROSSING

func has_pending_transition() -> bool:
	return _pending != null

## Asks him to travel to `point`. Safe to call at any time: mid-hop it only
## replaces the destination, honoured at the next landing.
##
## Refused outright while CROSSING, for RIDING's reason in the hub: the
## body is being written from somewhere else for the duration, and a stray
## hop_to would leave it walking while the arc kept driving it.
func hop_to(point: Vector3) -> void:
	if _state == State.CROSSING:
		return
	# A plain destination tap CANCELS a held link intent. The player asked
	# for somewhere else; honouring the old intent on arrival would be the
	# screen acting on a decision he has already replaced.
	_pending = null
	_target = _flat(point)
	_has_target = true
	if _state == State.IDLE:
		_advance()

## Asks him to use `link`: walk to its entry on this level, then cross.
##
## The walk is an ORDINARY hop chain and the crossing happens at the
## landing -- which is the hub's own boat/ladder/cabin shape, and NOT the
## thing the brief contrasted them with. Measured, not assumed: the hub's
## ladder does not fire CLIMBING at tap time either; _on_tapped_ladder arms
## an intent and calls hop_to(), and _on_hop_landed is what climbs.
func request_transition(link: LevelTransition) -> void:
	if link == null or _state == State.CROSSING:
		return
	if controller == null:
		return
	if not link.is_available():
		return
	var here := controller.current_index()
	if not link.serves(here):
		return
	_pending = link
	var entry := link.entry_for(here)
	_target = _flat(entry)
	_has_target = true
	if _state == State.IDLE:
		_advance()

## Runs the crossing itself. Public so a caller with its own idea of when
## to start one (a trigger volume, a scripted sequence) can, but the
## ordinary path is request_transition() plus a landing.
func begin_crossing(link: LevelTransition) -> void:
	if link == null or controller == null:
		return
	if _state == State.CROSSING or not link.is_available():
		return
	var from_index := controller.current_index()
	var to_index := link.other_side(from_index)
	if to_index < 0:
		return
	var entry := link.entry_for(from_index)
	var exit_point := link.exit_from(from_index)

	# THE WITHDRAWAL, held for the WHOLE crossing. From here until the arc
	# lands, accepts_tap() answers false, so a tap falls through to the
	# ground path -- where hop_to() refuses it because the body is being
	# written from here. The tap is never SWALLOWED; it simply has nothing
	# to do, which is the difference the ladder pattern gets wrong.
	link.set_busy(true)
	_pending = null
	_has_target = false
	_crossing = link
	_crossing_to = to_index
	_state = State.CROSSING

	_hop_from = Vector3(entry.x, 0.0, entry.z)
	_hop_to = Vector3(exit_point.x, 0.0, exit_point.z)
	_hop_from_y = entry.y
	_hop_to_y = exit_point.y
	_hop_height = CROSSING_ARC_HEIGHT
	_face(_hop_to - _hop_from)

	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply_hop, 0.0, 1.0, CROSSING_DURATION)
	_tween.finished.connect(_on_crossing_finished, CONNECT_ONE_SHOT)
	crossing_started.emit(link, to_index)

func _on_crossing_finished() -> void:
	var link := _crossing
	var to_index := _crossing_to
	_crossing = null
	_crossing_to = -1
	_state = State.IDLE
	# Snapped to the END of the base line rather than to zero: that is what
	# puts the feet on the destination floor instead of wherever the
	# tween's last frame happened to fall.
	global_position = Vector3(_hop_to.x, _hop_to_y, _hop_to.z)
	_hop_from_y = 0.0
	_hop_to_y = 0.0
	_hop_height = HOP_HEIGHT

	# ORDERED: the navigation moves BEFORE the withdrawal is released and
	# before anyone is told. A listener that read the controller while the
	# link was already free but the level had not changed would see a world
	# where a tap resolves against the floor he just left.
	if controller != null and to_index >= 0:
		controller.set_current(to_index)
	if link != null:
		link.set_busy(false)
	if link != null:
		crossing_finished.emit(link, to_index)
	became_idle.emit()

func _advance() -> void:
	if not _has_target:
		return
	if _state == State.CROSSING:
		return
	var here := _flat(global_position)
	var delta := _target - here
	delta.y = 0.0
	if delta.length() <= ARRIVE_EPSILON:
		_has_target = false
		_state = State.IDLE
		global_position = Vector3(global_position.x, _ground_y(), global_position.z)
		# The held link is honoured HERE, on arrival, and only if he
		# actually reached its entry. Checked rather than assumed: a walk
		# that was clamped short of the entry must not cross from wherever
		# it stopped.
		if _pending != null and _try_pending():
			return
		_pending = null
		became_idle.emit()
		return
	_begin_hop(here, delta)

## Crosses if the held link's entry is under his feet. Returns whether it
## did, so the caller knows not to also report idle.
func _try_pending() -> bool:
	if _pending == null or controller == null:
		return false
	var link := _pending
	var here := controller.current_index()
	if not link.serves(here) or not link.is_available():
		_pending = null
		return false
	var entry := link.entry_for(here)
	var flat_here := Vector3(global_position.x, 0.0, global_position.z)
	var flat_entry := Vector3(entry.x, 0.0, entry.z)
	if flat_here.distance_to(flat_entry) > ENTRY_REACH:
		# Not there yet -- and this is the pass-through case the intent
		# exists to survive. Kept, not dropped.
		return false
	_pending = null
	begin_crossing(link)
	return true

func _begin_hop(here: Vector3, delta: Vector3) -> void:
	var ground := _ground_y()
	_hop_height = HOP_HEIGHT
	# The base line is the CURRENT LEVEL'S floor at both ends, not zero.
	# This is the single line that makes an ordinary hop work off the
	# ground plane -- the hub re-zeroes both here and can therefore only
	# ever walk at y = 0.
	_hop_from_y = ground
	_hop_to_y = ground
	var flat_delta := Vector3(delta.x, 0.0, delta.z)
	var step: float = minf(HOP_DISTANCE, flat_delta.length())
	_hop_from = Vector3(here.x, 0.0, here.z)
	_hop_to = _hop_from + flat_delta.normalized() * step
	# Faced BEFORE leaving the ground: a body that rotates in mid-air looks
	# like it is being steered, which is the reading the commit rule exists
	# to avoid.
	_face(flat_delta)
	if _tween and _tween.is_valid():
		_tween.kill()
	_state = State.HOPPING
	# ONE tween driving a normalised 0..1, not parallel property tweens:
	# position and arc are written from the same t and cannot drift.
	_tween = create_tween()
	_tween.tween_method(_apply_hop, 0.0, 1.0, HOP_DURATION)
	_tween.finished.connect(_on_hop_finished, CONNECT_ONE_SHOT)

func _face(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.000001:
		return
	rotation_degrees.y = rad_to_deg(atan2(flat.x, flat.z))

## The arc. `base` is the line it is drawn ON -- flat within a level,
## sloped across a crossing.
##
## 4t(1-t) peaks at exactly 1.0 at t = 0.5 and is exactly 0 at both ends,
## so the arc cannot leave him hovering on a rounding error: it lands
## exactly ON the base line, whatever that line is.
func _apply_hop(t: float) -> void:
	var ground := _hop_from.lerp(_hop_to, t)
	var base: float = lerpf(_hop_from_y, _hop_to_y, t)
	var height: float = _hop_height * 4.0 * t * (1.0 - t)
	global_position = Vector3(ground.x, base + height, ground.z)

func _on_hop_finished() -> void:
	_state = State.IDLE
	_hop_height = HOP_HEIGHT
	global_position = Vector3(_hop_to.x, _hop_to_y, _hop_to.z)
	hop_landed.emit(global_position)
	# Ordered deliberately: listeners see the landing BEFORE the next hop
	# starts, so anything reached on this landing acts before a queued
	# destination beyond it overruns it.
	_advance()

func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, _ground_y(), point.z)
