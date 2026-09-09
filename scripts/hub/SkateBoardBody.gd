extends CharacterBody3D
class_name SkateBoardBody
## CH57 LOT 1 -- THE FIRST REAL PHYSICS BODY THIS HUB HAS EVER HAD.
##
## =====================================================================
## WHAT THIS IS, IN ONE SENTENCE
##
## The skateboard, when DevTools.physics_enabled() is true: a
## CharacterBody3D that HubTransport steps once per physics tick, with
## Keepy written onto it by the carrier contract in the SAME call. When
## the switch is off this file is never instantiated and the board is the
## MeshInstance3D CH54 shipped, unchanged in every particular.
##
## =====================================================================
## WHY THE COLLIDER IS HERE AND NOT ON KEEPY (D2, Mathieu)
##
## CH55 section 2.2 priced both shapes and section 3.1 chiffred the
## consequence. Form A -- the hopper becomes a CharacterBody3D -- gives
## the character a capsule in ALL TWELVE of his states, so a body hanging
## from a zipline or sitting on a seesaw carries a shape into the physics
## space where it would block and be blocked, and the failure is silent.
## Worse, it spends the traversal guarantee: the hub's worst pair walks
## 111.414 u in 20.967 s against a 22.0 s ceiling, which is 1.033 s of
## margin, which is 5.469 u of DETOUR for the whole map. One obstacle
## that costs more than that breaks the ceiling and there is no budget
## for a second.
##
## Form B -- the collider belongs to the CARRIER -- costs none of it, and
## the reason is structural rather than statistical: a tween writes
## `global_position` and CONSULTS NO COLLIDER, so a hopper that is never
## a physics body cannot be deflected by one. Nothing to re-walk, nothing
## to re-measure. SkatePhysicsProbe PHASE T confirms it rather than
## assuming it, because CLAUDE.md says a structural argument is still an
## argument until something measures it.
##
## =====================================================================
## ⚠️ WHO OWNS THE GROUND (D1, Mathieu), AND THE ONE LINE OF IT THAT HAD
## TO BE INTERPRETED
##
## D1: "HubSurface reste la SOURCE UNIQUE du sol. Pas de HeightMapShape3D,
## pas de seconde orthographe. La physique bloque LATERALEMENT seulement."
##
## Taken to the letter -- physics may never write a Y -- this lot cannot
## reach its own stated goal, which is that the board CLIMBS ONTO the
## funbox instead of stopping beside it. So the line is read the only way
## that keeps both halves true:
##
##   * THE TERRAIN is HubSurface's, entirely and without exception. There
##     is no HeightMapShape3D, no collider under the lawn, no second grid
##     and no second reading of `height_at`. `_hub_floor()` below is the
##     whole of it: after every move_and_slide, a body below the surface
##     is put back ON it. HubSurface is not consulted BY the engine; it
##     OVERRULES the engine.
##   * WHAT STANDS ON THE TERRAIN is the collider's. A funbox is not
##     ground -- it is a prop resting on ground, and its 20 triangles are
##     the only thing in this world that may put the board above
##     `height_at`.
##
## The invariant, stated so a probe can gate it and PHASE S does:
##     global_position.y >= HubSurface.height_at(flat), ALWAYS,
##     and strictly greater ONLY while a module holds it up.
##
## =====================================================================
## WHAT IT IS NOT: A PILOTED VEHICLE
##
## D6 (the chase camera) is explicitly NOT decided and explicitly outside
## this lot. CLAUDE.md's camera table keys on CONTINUOUS PILOTING -- "le
## joueur choisit la direction frame par frame" -- and this board is
## still tapped to a destination exactly as CH54's is. The camera
## therefore stays FIXED, no ChaseAudit of the north lobe is owed, and
## nothing here reads `touch.input`. What changed is HOW the board gets
## to the destination, not how the player asks for it.
##
## =====================================================================
## THE PACE PROFILE IS CH54'S, MADE CONTINUOUS
##
## CH54 measured the ride Mathieu asked for -- a run-up, a cruise, a
## run-out -- and wrote it as a per-SEGMENT pace in KeepyHopper
## (`_glide_segment_pace`). A physics body has no segments, so the same
## profile is integrated per tick instead, from the SAME numbers:
## HubTransport passes its own SKATE_CRUISE / SKATE_ACCEL_U /
## SKATE_BRAKE_U into `configure()` and this file authors none of them.
## The floor is read straight off KeepyHopper, where it lives.

## ⚠️ A COPIED NUMBER, AND IT IS GATED RATHER THAN TRUSTED. 26.0 is
## `Keepy.GRAVITY`, this repo's only other physics gravity (Chased). It is
## re-declared here rather than read across because Chased is a different
## screen whose feel is tuned on its own jump arc, and a hub that silently
## followed a retune of that arc would be the "moitié de somme" defect of
## CLAUDE.md. SkatePhysicsProbe PHASE C asserts the two are equal and
## PRINTS both: the day it goes red, that is a decision to take, not a
## number to sync behind everyone's back.
const GRAVITY: float = 26.0

## =====================================================================
## COLLISION LAYERS -- AND WHY 3 AND 4 AND NOT 1 AND 2
##
## CH55 section 4.1: HubWorld's SubViewport has no `own_world_3d`, so it
## inherits the root World3D, i.e. the same physics space anything else
## the window holds would use. Chased has ALREADY reserved layer 1 (its
## ground, TrackSegment) and layer 2 (its player capsule). D3 -- share the
## space or split it -- is NOT decided, and this lot does not need it
## decided: staying off both reserved layers makes the question moot for
## as long as the park is the only physical thing in the hub. A later lot
## that wants more may still take `own_world_3d`, and will owe the pixel
## proof CH55 says it owes.
const LAYER_PARK: int = 3
const LAYER_BOARD: int = 4

## How far below itself the body looks for a floor it has just left, so a
## deck-to-ramp transition is a roll rather than a hop. Well under the
## funbox's 0.85 u height: a snap longer than the module would let the
## board grab a surface it is genuinely airborne above.
const SNAP_LENGTH: float = 0.3

## Arrival, in the hopper's own units so a physics roll and a tween roll
## agree on what "there" means. Read, not retyped.
const ARRIVE_EPSILON: float = KeepyHopper.ARRIVE_EPSILON
## Rest pace: what a roll STARTS at, CH54's whole complaint about a board
## that left at full speed from a standstill. Read off the file that owns
## the profile.
const PACE_FLOOR: float = KeepyHopper.GLIDE_PACE_FLOOR

## =====================================================================
## THE STALL GUARD
##
## CLAUDE.md, CH42: "le gain de braquage est proportionnel a v_fwd, donc
## un mur supprime la direction" -- a body pressed into geometry loses the
## authority to leave it, and every vehicle in this repo has paid that
## arithmetic at least once. This board has no reverse (it is not
## piloted), so the guard is the other half of the same answer: a target
## that stops producing displacement is DROPPED, and the player gets his
## tap channel back rather than a board grinding into a wall for ever.
##
## The threshold is per-TICK displacement, not a position at the end of a
## window: CH42's other finding is that a bounded trajectory "finit ou
## elle commence", so a final position cannot tell "stuck" from "came
## back".
const STALL_STEP: float = 0.004
const STALL_TICKS: int = 30

var _cruise: float = 0.0
var _accel_u: float = 0.0
var _brake_u: float = 0.0
var _pace: float = PACE_FLOOR
var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _stalled_ticks: int = 0
var _shape: CollisionShape3D = null
## Diagnostics the probe and the overlay read. Never a control input.
var _supported: bool = false
var _last_step: float = 0.0

func _ready() -> void:
	collision_layer = 1 << (LAYER_BOARD - 1)
	collision_mask = 1 << (LAYER_PARK - 1)
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up_direction = Vector3.UP
	floor_snap_length = SNAP_LENGTH
	# Left at Godot's 45 deg. The funbox ramp is atan(0.85 / 1.44) = 30.6
	# deg, so it is a FLOOR and the body climbs it; a wall of the deck box
	# is 90 deg and stops it. Nothing here needs tuning between the two,
	# and a tuned angle would be a number with no measurement behind it.
	# ⚠️ NEVER call move_and_slide from a _physics_process of our own:
	# HubTransport steps this body and writes the rider in the SAME call
	# (carrier-then-carried, the turnstile's one-frame-lag measurement).
	# A second driver here would be a second writer of the same transform.
	set_physics_process(false)

## =====================================================================
## ⚠️ THE SHAPE IS A CAPSULE ON ITS SIDE, AND A BOX WAS **MEASURED** WRONG
##
## The obvious shape is a box the size of the deck, and it does not work.
## Measured, not reasoned: with a box whose underside sits flush at y = 0,
## the board reached the funbox ramp and STOPPED DEAD 0.46 u short of it
## -- exactly its own half-length -- for the rest of the run. The
## per-tick contact dump says why, and it says it in one number:
##
##     t20  pos (0.000, 0.0000, 48.2809)  floor=false wall=true
##          n=(0, 0, 1) d=0.0009   n=(0, 0, 1) d=0.0001
##
## The contact normal is (0, 0, 1) -- a VERTICAL WALL -- against a ramp
## whose real normal is (0, 0.861164, 0.508327). The ramp wedge tapers to
## a ZERO-THICKNESS EDGE at y = 0 and the box's underside is a FLAT FACE
## at y = 0: the two are COPLANAR, so the minimum translation direction
## that separates them is horizontal, and the engine classifies a 30.6 deg
## slope as a 90 deg wall. The true slope normal appeared on exactly one
## tick out of thirty (t28), drowned by two wall contacts on the same
## frame. Nothing is wrong with the hull, the winding, the layer or the
## angle: it is the FLATNESS of the bottom face that is wrong.
##
## A capsule lying along the board's length has no bottom FACE at all --
## it touches the ground along a tangent LINE and an edge at a POINT --
## so the separating direction against the ramp tip is the one that runs
## from the capsule's axis to the edge, which at first contact is
## straight UP. The ramp reads as a floor and the board climbs it.
##
## And it costs nothing in accuracy where accuracy is wanted: the tangent
## line is at exactly y = 0 in the body's own space, so a board resting on
## the funbox deck has its ORIGIN at the deck's height with no fudge
## factor to subtract -- which is what lets PHASE R gate the ride against
## the module's authored 0.85 rather than against a tuned epsilon.
##
## Called once by HubTransport, which owns the board's geometry -- this
## file never authors a dimension.
func attach_shape(radius: float, length: float) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = maxf(length, radius * 2.0)
	_shape = CollisionShape3D.new()
	_shape.name = "BoardShape"
	_shape.shape = capsule
	# Godot's capsule stands on Y; the board is long on Z. Laid down, and
	# raised by exactly its radius so its lowest line is the body's own
	# origin -- the point HubTransport parks and `_hub_floor()` restores.
	_shape.rotation_degrees.x = 90.0
	_shape.position = Vector3(0.0, radius, 0.0)
	add_child(_shape)

## The board's tuning, handed in by its owner. CH54's three numbers, and
## this file publishes none of them.
func configure(cruise: float, accel_u: float, brake_u: float) -> void:
	_cruise = maxf(cruise, 0.01)
	_accel_u = maxf(accel_u, 0.0)
	_brake_u = maxf(brake_u, 0.0)

# =====================================================================
# WHAT IT PUBLISHES

## Where the rider's feet stand, in the board's own space. The one place
## this is spelled; HubTransport reads it and KeepyHopper is handed it.
func seat(deck_top: float) -> Vector3:
	return Vector3(0.0, deck_top, 0.0)

func flat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)

func has_target() -> bool:
	return _has_target

func at_rest() -> bool:
	return not _has_target

## True on the tick the module held the board above HubSurface -- the
## observable that says "it is ON the funbox" without reading a height
## the probe would then have to trust.
func supported() -> bool:
	return _supported

## Flat distance covered on the last tick. Published so a bench measures
## the roll rather than differencing positions it also wrote.
func last_step() -> float:
	return _last_step

func pace() -> float:
	return _pace

# =====================================================================
# THE TAP

## Rolls toward `point`. The destination is CLAMPED by the caller, exactly
## as a hop destination is -- CLAUDE.md's AIM vs DESTINATION rule is about
## what the player MEANT, and nothing about it changes because the mover
## became a rigid body.
func set_target(point: Vector3) -> void:
	_target = Vector3(point.x, 0.0, point.z)
	_has_target = true
	_stalled_ticks = 0
	_pace = maxf(_pace, PACE_FLOOR)

func clear_target() -> void:
	_has_target = false
	_stalled_ticks = 0
	_pace = PACE_FLOOR
	velocity = Vector3.ZERO

# =====================================================================
# THE TICK

func drive(delta: float) -> void:
	if delta <= 0.0:
		return
	var before := flat_position()
	var heading := Vector3.ZERO
	var remaining: float = 0.0
	if _has_target:
		var to_target := _target - before
		remaining = to_target.length()
		if remaining <= ARRIVE_EPSILON:
			_has_target = false
		else:
			heading = to_target / remaining
	# The pace profile, integrated. `step` is the distance the PREVIOUS
	# pace bought, which is what makes the run-up a function of ground
	# covered rather than of seconds elapsed -- CH54 authored it in units
	# of roll and this keeps it there.
	var step: float = _cruise * _pace * delta
	if _has_target:
		var brake_cap: float = 1.0
		if _brake_u > 0.0:
			brake_cap = lerpf(PACE_FLOOR, 1.0, clampf(remaining / _brake_u, 0.0, 1.0))
		var climbed: float = 1.0
		if _accel_u > 0.0:
			climbed = minf(_pace + (1.0 - PACE_FLOOR) * step / _accel_u, 1.0)
		_pace = clampf(minf(climbed, brake_cap), PACE_FLOOR, 1.0)
	else:
		_pace = PACE_FLOOR
	var speed: float = _cruise * _pace if _has_target else 0.0
	velocity.x = heading.x * speed
	velocity.z = heading.z * speed
	# Gravity every tick, unconditionally. The lawn has no collider, so
	# `is_on_floor()` is FALSE on open ground by design and cannot be used
	# to skip this -- what catches the fall is `_hub_floor()` below, which
	# is HubSurface and not the engine.
	velocity.y -= GRAVITY * delta
	if heading != Vector3.ZERO:
		# Set, never tweened, and before the move: KeepyHopper._face's
		# reason exactly -- a body that rotates while it travels reads as
		# being steered, and this one is not steered.
		rotation.y = atan2(heading.x, heading.z)
	move_and_slide()
	_supported = _hub_floor()
	_fence(before)
	_last_step = flat_position().distance_to(before)
	if _has_target:
		_stalled_ticks = _stalled_ticks + 1 if _last_step < STALL_STEP else 0
		if _stalled_ticks >= STALL_TICKS:
			clear_target()

## HubSurface OVERRULES the engine, and this is the whole of D1's ground
## ownership in four lines. Returns true when the body was ABOVE the
## surface, i.e. when something else was holding it up.
func _hub_floor() -> bool:
	var ground: float = HubSurface.height_at(flat_position())
	if global_position.y < ground:
		global_position.y = ground
		if velocity.y < 0.0:
			velocity.y = 0.0
		return false
	return global_position.y > ground + 0.0005

## The region is the wall, exactly as it is for the three piloted vehicles
## (SandYacht._wall, SledBody._wall): a refusal that puts the body back
## where it was rather than a clamp that slides it along an edge. A board
## that cannot leave the region also cannot be aimed out of it, so the
## target goes with it -- otherwise the stall guard would be the only
## thing that ever ended the push.
func _fence(before: Vector3) -> void:
	if HubRegion.contains(flat_position()):
		return
	global_position = Vector3(before.x, global_position.y, before.z)
	velocity.x = 0.0
	velocity.z = 0.0
	clear_target()
