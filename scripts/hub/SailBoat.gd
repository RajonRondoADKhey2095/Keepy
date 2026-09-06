extends Node3D
class_name SailBoat
## CH33 -- THE SAILBOAT, on the sea CH29 already built. Calqued on
## SandYacht.gd (CH30): the same DRIVEN-VEHICLE shape (VehicleDrive.step(),
## the SAME KartTouchInput, the SAME HubCamera.enter_drive() chase), a
## different surface and a different way of refusing an edge.
##
## =====================================================================
## WHY THIS FILE IS NOT A COPY-PASTE OF SandYacht.gd WITH s/sand/sea/
##
## The land yacht's edge is a HARD WALL: HubRegion.contains() is a crisp
## yes/no, and SandYacht._wall() slides along it or bounces off it. The
## brief for THIS vehicle forbids exactly that shape -- a boat does not hit
## a wall at the shore, it runs aground, gradually, and a player who backs
## off must always get back to open water. So there is no _wall() here:
## the surface test (HubRegion.shore_distance, CH29's own published number,
## never restated) feeds a continuous GROUNDING FACTOR that the drive
## applies as extra drag, AFTER VehicleDrive.step() returns, never inside
## it (VehicleDrive.gd is not touched by this lot).
##
## =====================================================================
## WHY THE GROUNDING NEVER LOCKS THE BOAT
##
## The factor is a DRAG on velocity (an exponential pull toward zero,
## `_ground_pull()`), not a position clamp and not a hard zeroing. Even at
## full grounding (t = 1, keel dug into dry sand) the drag only shrinks
## whatever velocity the frame already has; it never overwrites the
## throttle's own target. VehicleDrive's reverse branch (brake input,
## `move_toward(v_fwd, -reverse_speed, ...)`) keeps pushing the boat
## backward every physics frame regardless of how aground it is, and the
## drag it fights is the SAME drag that will vanish the moment the hull is
## back over water (shore_distance is signed and continuous, so the pull
## relaxes exactly as fast as the boat clears the margin). That symmetry --
## one formula, read going in and read coming back out -- is what makes
## the reversal a property of the geometry rather than a special case
## `SailBoatProbe` has to hard-code.
##
## =====================================================================
## THE SEAT IS ON THE DECK, NOT ON THE ROOT (the boat pattern, RIDE_SEAT_Y)
##
## The root carries position and yaw (what VehicleDrive writes); the Deck
## carries the HEEL, and the rider is seated on the DECK so he leans with
## the hull exactly as Keepy leans with the kart's chassis and the land
## yacht's deck. SEAT is published ONCE here, the boat's own accessor, and
## every caller (HubTransport's mount/exit) reads it rather than retyping
## a height.
##
## No ladder pattern: the only tap channel this vehicle owns is
## HubTransport.vehicle_at()/mount_sailboat(), which WITHDRAWS while the
## boat is driven (the boat pattern) so a tap made meanwhile falls through
## to the ground path instead of being swallowed.

## ---- pace -----------------------------------------------------------
## Marine inertia: builds slowly (a sail, not an engine, same character as
## the land yacht but slower still -- a hull has more mass to move than a
## chassis on runners) and COASTS a long time when the thumb lifts, so the
## boat visibly carries its way rather than stopping on the spot. Starting
## values only, meant to be retuned on Mathieu's own thumb (brief CH33).
const BASE_SPEED: float = 9.5
const OFF_SPEED: float = 3.0
const REVERSE_SPEED: float = 2.6
const ACCEL_LAMBDA: float = 0.40
## Low on purpose: this is the number that reads as "way carries on".
const COAST_LAMBDA: float = 0.10
const OVER_LAMBDA: float = 1.3
const BRAKE_DECEL: float = 5.5
## Steering. Ratio of the live KartTuning preset, the same knob the kart
## and the land yacht already answer to -- a sailboat that ignored it
## would drift out of step with whatever Mathieu tunes there. Lower than
## the land yacht's 0.85: a keel turns slower than runners on sand.
const STEER_RATIO: float = 0.62
const STEER_FULL_SPEED: float = 3.0
const STEER_HIGH_SPEED_KEEP: float = 0.70
## Low grip afloat: a hull slides through a turn rather than gripping it,
## which is the other half of "conserve de l'erre" (the rest is COAST_LAMBDA
## above). Aground the keel bites the sand and stops sliding.
const GRIP_ON_SEA: float = 1.4
const GRIP_OFF: float = 4.0
const SCRUB: float = 0.45

## ---- grounding (echouage progressif) ---------------------------------
## HubRegion.shore_distance(): negative afloat (more negative = deeper),
## zero at the waterline, positive on dry sand. Nothing here restates
## SEA_CENTRE or SEA_RADIUS -- see the file docblock.
##
## Free water: at or beyond this margin INSIDE the sea, no drag at all.
const GROUND_FREE_MARGIN: float = 4.0
## Aground: at or beyond this margin ONTO the sand, the drag is at its cap
## (still not a hard stop -- see _ground_pull()).
const GROUND_AGROUND_MARGIN: float = 1.5
## The drag's time constant at full grounding (1/s). Chosen small enough
## that a held reverse (REVERSE_SPEED, built up over BRAKE_DECEL) still
## out-paces it -- see SailBoatProbe's reversibility check, run
## rouge-avant-vert against this exact constant before it was trusted.
const GROUND_DRAG_LAMBDA: float = 3.0

## Heel: a sailboat heels the SAME way a land yacht does (away from the
## turn, the sail pushed over) -- the read that tells both apart from the
## kart's roll toward the turn.
const HEEL_DEG_PER_ACCEL: float = 1.4
const HEEL_MAX_DEG: float = 11.0
const HEEL_LAMBDA: float = 5.0

## Where his feet stand: this vehicle reuses SandYacht's own hull GLB
## (yacht_hull_0 -- see CLAUDE.md's asset rule, brief CH33: no new asset),
## so its measured deck height (CH30's SandYacht.SEAT_Y) is exactly right
## and no second measurement is needed.
const SEAT_Y: float = SandYacht.SEAT_Y
const SEAT: Vector3 = Vector3(0.0, SEAT_Y, 0.0)

## A rectangle far larger than the sea, so VehicleDrive's own fence never
## bites and the grounding above is the only thing that ever slows this
## vehicle down (SandYacht.gd's own WORLD_FENCE, same reasoning: a
## backstop, not a boundary).
const WORLD_FENCE: Rect2 = Rect2(-220.0, -320.0, 440.0, 640.0)

var velocity: Vector3 = Vector3.ZERO

var _deck: Node3D = null
var _sail: MeshInstance3D = null
var _motion: VehicleDrive = null
var _last_velocity: Vector3 = Vector3.ZERO
var _heel: float = 0.0
var _time: float = 0.0
## The last grounding factor computed, 0 (free water) to 1 (aground). Read
## by SailBoatProbe rather than recomputed -- one publisher, CLAUDE.md's
## rule for a fact used by more than one file.
var _ground_factor: float = 0.0

func _ready() -> void:
	_motion = VehicleDrive.new()
	_motion.max_speed = BASE_SPEED
	_motion.max_speed_off = OFF_SPEED
	_motion.reverse_speed = REVERSE_SPEED
	_motion.accel_lambda = ACCEL_LAMBDA
	_motion.coast_lambda = COAST_LAMBDA
	_motion.off_lambda = OVER_LAMBDA
	_motion.brake_decel = BRAKE_DECEL
	_motion.steer_full_speed = STEER_FULL_SPEED
	_motion.steer_high_speed_keep = STEER_HIGH_SPEED_KEEP
	_motion.grip_on = GRIP_ON_SEA
	_motion.grip_off = GRIP_OFF
	_motion.scrub = SCRUB

## Builds the hull and the sail under a heeling deck. `mesh_for` is the
## owner's GLB loader, so this file does not duplicate the palette lookups
## HubTransport already owns -- the sand yacht's own pattern.
func build(hull_mesh: Mesh, hull_material: Material, sail_mesh: Mesh, sail_material: Material) -> void:
	_deck = Node3D.new()
	_deck.name = "Deck"
	add_child(_deck)
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = hull_mesh
	hull.material_override = hull_material
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_deck.add_child(hull)
	_sail = MeshInstance3D.new()
	_sail.name = "Sail"
	_sail.mesh = sail_mesh
	_sail.material_override = sail_material
	_sail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_deck.add_child(_sail)

## The node a rider is seated on: the DECK, so he heels with the hull.
func deck() -> Node3D:
	return _deck

func forward() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))

func right() -> Vector3:
	var f := forward()
	return Vector3(f.z, 0.0, -f.x)

func speed() -> float:
	return velocity.dot(forward())

func flat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)

## Puts the boat down at `at` facing `yaw`, stopped.
func place(at: Vector3, yaw: float) -> void:
	var flat := Vector3(at.x, 0.0, at.z)
	global_position = flat
	rotation.y = yaw
	velocity = Vector3.ZERO
	_last_velocity = Vector3.ZERO
	_heel = 0.0
	_ground_factor = 0.0
	_apply_deck()

## The grounding factor at flat point `p`: 0 in free water (at or beyond
## GROUND_FREE_MARGIN under the surface), 1 once GROUND_AGROUND_MARGIN
## onto dry sand, linear between. HubRegion.shore_distance is the single
## published number this reads -- see the file docblock for why nothing
## here restates SEA_CENTRE or SEA_RADIUS.
static func ground_factor_at(p: Vector3) -> float:
	var shore: float = HubRegion.shore_distance(p)
	return clampf((shore + GROUND_FREE_MARGIN) / (GROUND_FREE_MARGIN + GROUND_AGROUND_MARGIN), 0.0, 1.0)

## One physics step, driven by `input`. `wind` is the weather's factor on
## the pace (HubTransport.sailboat_speed_factor()); `on_sea` is the
## caller's verdict from HubWater.body_at() == &"sea" (CH33 brief: derived
## there, not re-tested here). The caller writes the rider immediately
## after, in the same call (carrier-then-carried).
func drive(delta: float, input: KartInput, wind: float, on_sea: bool) -> void:
	_motion.max_speed = BASE_SPEED * wind
	var out: Dictionary = _motion.step(flat_position(), rotation.y, velocity, delta, input,
		on_sea, WORLD_FENCE, KartTuning.steer_rate() * STEER_RATIO)
	rotation.y = float(out["yaw"])
	velocity = out["velocity"]
	var moved: Vector3 = out["position"] as Vector3
	# ---- grounding: a continuous drag, applied to velocity only, AFTER
	# VehicleDrive has already moved the hull for this frame. Never a
	# position clamp -- see the file docblock for why that is what keeps
	# the reversal working.
	_ground_factor = ground_factor_at(moved)
	if _ground_factor > 0.0:
		velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-GROUND_DRAG_LAMBDA * _ground_factor * delta))
	global_position = moved
	_animate(delta)
	_last_velocity = velocity

## The grounding factor as of the last drive() call, for SailBoatProbe.
func ground_factor() -> float:
	return _ground_factor

## ---- the body ----------------------------------------------------------

func _animate(delta: float) -> void:
	_time += delta
	var accel: Vector3 = (velocity - _last_velocity) / maxf(delta, 0.0001)
	var lat_a: float = accel.dot(right())
	var want: float = clampf(-lat_a * HEEL_DEG_PER_ACCEL, -HEEL_MAX_DEG, HEEL_MAX_DEG)
	_heel = lerpf(_heel, want, 1.0 - exp(-HEEL_LAMBDA * delta))
	_apply_deck()

func _apply_deck() -> void:
	if _deck == null:
		return
	_deck.rotation_degrees = Vector3(0.0, 0.0, _heel)

## The sail's own life: it leans with the wind and flutters. Called by the
## owner every frame, driven or moored, so the boat is alive seen from the
## shore. Same shape as SandYacht.breathe().
func breathe(wind: float, t: float) -> void:
	if _sail == null:
		return
	_sail.rotation.z = deg_to_rad(-7.0 * wind) * (0.75 + 0.25 * sin(t * 2.3))
