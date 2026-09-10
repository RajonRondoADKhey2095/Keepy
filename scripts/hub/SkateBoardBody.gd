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
## ⚠️ CH63 LOT 2 -- AND NOW IT IS A PILOTED VEHICLE, WHICH REVERSES THE
## PARAGRAPH THAT STOOD HERE
##
## What stood here said the opposite, and it was right at the time: "this
## board is still tapped to a destination exactly as CH54's is, the camera
## therefore stays FIXED, and no ChaseAudit is owed". CLAUDE.md's camera
## table keys on CONTINUOUS PILOTING -- "le joueur choisit la direction
## frame par frame" -- and under the DRAG scheme that is now literally
## what happens: a held finger writes this board's heading and its
## throttle, every tick, and nothing between the thumb and the push is a
## destination any more.
##
## So the board takes the fourth seat at the piloted table, beside the
## kart, the sand yacht and the sled: `HubCamera.enter_drive()` on mount,
## `exit_drive()` on the step-off, and the ChaseAudit that CLAUDE.md
## requires WITH a chase camera -- because a chase pose shows the decor at
## azimuths the fixed frame has never shown, and everything this hub has
## calibrated was calibrated for the fixed frame. CH30 ran that audit on a
## hub two visual audits had already called clean and found two real
## defects.
##
## ⚠️ THE TAP SCHEME IS STILL THERE AND STILL A DESTINATION, and that is
## not a contradiction: it is the A/B. Under TAP the destination lives in
## HubTransport's adapter, which turns it into the same two fields this
## file now speaks -- so there is one drive model with two ways of being
## asked, rather than two drive models.
##
## =====================================================================
## CH61 LOT 3c -- THE PACE PROFILE BECOMES A LAW OF MOTION
##
## ⚠️ WHAT CH60 MEASURED, AND WHY NO AMOUNT OF SPEED WOULD HAVE FIXED IT.
##
## Mathieu, device in hand, on the CH60 build: "je n'arrive pas du tout a
## monter les rampes, je suis juste bloque". CH60 had already chiffred the
## ceiling -- 0.577 u reached on a 2.10 u lip, 0.386 u on a 1.45 u lip --
## and read it as the honest consequence of a body with no stored elan.
##
## THAT READING WAS HALF RIGHT, AND THE HALF THAT WAS WRONG IS THE HALF
## THIS LOT TURNS ON. Put the two numbers over their own lips:
##
##     0.577 / 2.10 = 0.2748          0.386 / 1.45 = 0.2662
##
## The same FRACTION of two different ramps, not the same HEIGHT. An
## energy ceiling is an ABSOLUTE height -- v^2 / 2g, which at CH54's
## cruise of 10.0 u/s and this file's gravity of 26.0 is 1.923 u, well
## over BOTH lips. A ceiling that scales with the ramp instead is a
## SHAPE constant, and CH60's own section 6 names it without drawing the
## conclusion: `floor_max_angle` is Godot's 45 deg, the profile's facets
## are 3.75 / 11.25 / ... / 86.25 deg, so the last facet a body may stand
## on is the sixth and the highest point it can reach is
##
##     P6 = height * (1 - cos 45 deg) = 0.2929 * height
##
## 0.2748 and 0.2662 are that number, minus the capsule's own contact
## offset. The board was never short of energy. It was being told, every
## tick, that the seventh facet is a WALL.
##
## So this lot does BOTH things, and one without the other buys nothing:
## a body given inertia against a 45 deg cap still stops at 29 %, and a
## cap raised under a dictated pace still climbs at whatever height the
## pace happens to reach. What replaces the profile is below; what
## happens to the cap is in `_ready()`.
##
## =====================================================================
## THE LAW, AND WHY CH54'S THREE NUMBERS SURVIVE IT UNCHANGED
##
## CH54 measured the ride Mathieu asked for -- a run-up over
## SKATE_ACCEL_U, a cruise at SKATE_CRUISE, a run-out over SKATE_BRAKE_U
## -- and wrote it as a per-SEGMENT pace in KeepyHopper
## (`_glide_segment_pace`). CH57 integrated that same profile per tick:
## a DICTATED speed, rewritten from scratch every frame, which conserves
## nothing and cannot convert anything.
##
## CH61 keeps the three numbers and throws the dictation away. They stop
## being a speed and become the ACCELERATIONS that produce it:
##
##     push  = (cruise^2 - rest^2) / (2 * accel_u)     u/s^2
##     brake = (cruise^2 - rest^2) / (2 * brake_u)     u/s^2
##
## -- straight out of v^2 = v0^2 + 2 a d, with `rest` the run-up's own
## starting pace (KeepyHopper.GLIDE_PACE_FLOOR * cruise). The velocity
## then PERSISTS from tick to tick and everything else acts on it.
##
## The consequence worth stating plainly: CH54's profile is no longer
## imposed, it is REPRODUCED. On the flat the board still reaches cruise
## over accel_u, still holds it, still stops over brake_u -- not because
## anything says so, but because those are the accelerations. PHASE L of
## SkateInertiaProbe measures all three against the published figures
## rather than trusting this paragraph.
##
## WHAT ACTS ON THE VELOCITY, in the order it is applied:
##
##   1. THE PUSH. A foot on the ground, so it is horizontal, it is capped
##      at `cruise` ALONG THE HEADING (a skater cannot push faster than
##      his legs swing -- that, and not drag, is what makes cruise a top
##      speed), and it is scaled by `n.y` = cos(slope). That factor is
##      not a taste: the force a foot can pass to the ground is limited
##      by friction, friction is proportional to the normal force, and
##      the normal force on a slope is m g cos(slope). At the top of a
##      transition there is nothing left to push against, which is why
##      the height reached is a function of the speed ARRIVED WITH and
##      not of how long the finger held a target beyond the ramp.
##   2. THE BRAKE, the same shape, when the command asks for one. CH63
##      LOT 2 made the throttle SIGNED: +1 pushes along the heading, -1
##      spends `brake` against the velocity the board already has. The
##      DRAG scheme only ever writes 0 or +1 -- a lifted finger coasts,
##      it does not brake -- and the TAP adapter in HubTransport is what
##      writes -1, so that a tapped destination still ENDS at the tap
##      instead of coasting a whole park span through it.
##   3. THE COAST. A quadratic term plus a constant one; the constant one
##      is what makes a released board stop in finite time rather than
##      asymptote, and CLAUDE.md's "le hub devient une patinoire" is the
##      failure it exists to prevent. Both are scaled by `n.y` for the
##      same normal-force reason.
##   4. GRAVITY, LAST -- CH41's rule, and it is a rule this repo has paid
##      for. "Une force injectee AVANT step() gele le vehicule face a la
##      montee": a slope force composed before the drive model made
##      `v_fwd` negative, the model took its reverse branch, and the
##      vehicle sat at 0.000 u/s on a hill with no steering and no way
##      out. Here the drive model IS steps 1-3, so gravity composes after
##      them, into the velocity they have just written.
##
##      When something holds the board up, gravity is applied TANGENTIALLY
##      -- `g - n (g . n)` -- which is the whole of what this lot is for:
##      it SUBTRACTS from a climb and ADDS to a descent, in the plane the
##      board is actually on. When nothing holds it up it is applied
##      whole, and the board is a projectile.
##
## HubTransport passes SKATE_CRUISE / SKATE_ACCEL_U / SKATE_BRAKE_U /
## SKATE_COAST_U into `configure()`; this file authors none of them and
## the rest pace is read straight off KeepyHopper, where it lives.

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

## =====================================================================
## ⚠️ CH61 -- WHAT WAS DONE TO `floor_max_angle`, AND WHY IT IS A
## MEASUREMENT AND NOT A FEELING
##
## CH57 left it at Godot's 45 deg with a reason written down, and the
## reason was true of the only module that was solid then: "the funbox
## ramp is 30.6 deg, so it is a FLOOR; a wall of the deck box is 90 deg
## and stops it. Nothing here needs tuning between the two." CH60 made
## the two quarterpipes solid and that sentence stopped covering the
## park, silently -- see the header: a transition is an ARC, and 45 deg
## cuts it at 29 % of its own height.
##
## The angle is not tuned toward a feel. The park's collision solids have
## exactly TWO populations of faces and the gap between them is the whole
## design margin:
##
##   * RIDING surfaces -- the funbox deck (0 deg), its two ramps
##     (30.6 deg), the rail's boxes (0 deg) and the twelve chords of each
##     quarterpipe profile, the steepest of which is the last one at
##     (QP_SEGMENTS - 0.5) / QP_SEGMENTS * 90 = 86.25 deg;
##   * WALLS -- every side face of every box, every side wall and the
##     vertical back of each quarterpipe: 90 deg exactly, because they
##     are axis-aligned faces of prisms and their normals have y = 0 to
##     the bit.
##
## Any angle strictly between 86.25 and 90 admits the ENTIRE drawn
## transition and refuses EVERY wall. 88.0 is the middle of that gap. It
## is not a number with no measurement behind it: SkateInertiaProbe
## PHASE A enumerates the supporting planes of all thirty convex pieces
## the park actually holds, publishes the steepest riding facet and the
## shallowest wall, and gates this constant strictly between the two --
## so the day a module is added whose ramp is steeper than the gap, the
## probe goes red instead of the board quietly climbing a wall.
##
## ⚠️ AND IT DOES NOT LOOSEN THE TERRAIN BY ONE UNIT. The lawn carries no
## collider (D1), so this angle is never consulted about the ground: what
## catches the board on open ground is `_hub_floor()` below, which is
## HubSurface overruling the engine, exactly as before.
const FLOOR_MAX_ANGLE: float = deg_to_rad(88.0)

## How far below itself the body looks for a floor it has just left, so a
## deck-to-ramp transition is a roll rather than a hop. Well under the
## funbox's 0.85 u height: a snap longer than the module would let the
## board grab a surface it is genuinely airborne above.
const SNAP_LENGTH: float = 0.3

## Rest pace: what a roll STARTS at, CH54's whole complaint about a board
## that left at full speed from a standstill. Read off the file that owns
## the profile.
const PACE_FLOOR: float = KeepyHopper.GLIDE_PACE_FLOOR

## =====================================================================
## WHAT "NOT MOVING" MEANS, AND WHY IT OUTLIVED THE STALL GUARD
##
## ⚠️ CH63 LOT 2 DELETED THE STALL GUARD, AND THIS CONSTANT IS WHAT IT
## LEFT BEHIND. CH57 and CH61 had one because the board was aimed at a
## DESTINATION nobody was watching: a target that stopped producing
## progress had to be dropped, or a tap into a wall would grind for ever
## with the player's tap channel spent. Under a held throttle there is no
## target to drop and nobody to rescue -- the finger IS the guard, and it
## lifts. The destination scheme still has one, but it now lives with the
## destination, in HubTransport's tap adapter, which is the file that owns
## the concept at all.
##
## What survives is the THRESHOLD, because two other readers need a
## definition of motionless that does not depend on a guard: `at_rest()`,
## which is what separates "a tap gets off" from "a tap steers", and every
## probe that waits for a roll to end. It is a per-tick flat displacement,
## converted to a speed by the engine's own tick rate in `rest_speed()`.
## One spelling, so a file cannot hold two answers to "is it moving".
const REST_STEP: float = 0.004

## =====================================================================
## THE COAST, AND THE ONE NUMBER THIS FILE WOULD OTHERWISE HAVE INVENTED
##
## A quadratic drag alone never stops a body, it only asymptotes, so a
## board released at cruise would still be drifting a minute later --
## CLAUDE.md's patinoire. A constant term stops it in finite time, and
## the question is how big.
##
## It is NOT chosen by feel. `configure()` is handed a COAST DISTANCE and
## solves for the deceleration that spends `cruise` over it, exactly as
## the push and the brake are solved from CH54's two distances. What
## HubTransport hands in is the skatepark's OWN extent, published by
## `HubSkatepark.park_span()`: a board that stops being pushed at full
## cruise comes to rest inside the park it was pushed in. That is a
## property somebody can look at, and PHASE L measures it.
##
## The split between the two terms is the one place a ratio is written
## down. At `cruise` the quadratic term carries this fraction of the
## total and the constant term the rest -- high, because a skateboard
## really does lose most of a fast roll to speed-dependent losses and
## almost none of a slow one, and because a coast that ends in a long
## crawl reads as a bug.
const COAST_QUADRATIC_SHARE: float = 0.75

var _cruise: float = 0.0
var _accel_u: float = 0.0
var _brake_u: float = 0.0
var _coast_u: float = 0.0
## Solved once in `configure()` from the four distances above. u/s^2,
## except `_drag_k` which is 1/u.
var _push: float = 0.0
var _brake: float = 0.0
var _drag_k: float = 0.0
var _roll_stop: float = 0.0
## =====================================================================
## CH63 LOT 2 -- THE WHOLE OF THE COMMAND, AND IT IS TWO FIELDS
##
## The board no longer holds a destination. It holds a HEADING and a
## THROTTLE, written by whoever is driving it (the finger, through
## HubTransport, in DRAG mode; the tap adapter in TAP mode), and it
## forgets neither and remembers nothing else.
##
## `_heading` is flat and unit, or ZERO -- and ZERO is not "stop", it is
## "keep your own facing". A finger pressed and held still inside the
## slop writes exactly that, and it has to mean straight on: a scheme
## where the first millimetre of every gesture did nothing would be a
## board that ignores the player until he wiggles.
var _heading: Vector3 = Vector3.ZERO
## +1 push along the heading, 0 free roll, -1 brake against the velocity.
## Signed rather than split into two fields for KartInput's own reason: a
## thumb cannot ask for both, and two fields would let a stale one survive
## the other.
var _throttle: float = 0.0
var _shape: CollisionShape3D = null
## Diagnostics the probe and the overlay read. Never a control input.
var _supported: bool = false
var _on_module: bool = false
var _last_step: float = 0.0
## The normal of whatever held the board up on the tick that has just
## been stepped. Vector3.UP when nothing did.
var _hold_normal: Vector3 = Vector3.UP
var _held: bool = false

## =====================================================================
## CH64 -- THE AIR, AS A PREDICATE A TRICK CAN BE ARMED ON
##
## `airborne()` (CH62) is `_supported and not _on_module`: above the
## surface and not on a module floor. It is the right reading for a
## sound and a shadow, and the WRONG one to arm a gesture on, for a
## reason CH63 wrote down: `is_on_floor()` describes the move that has
## already happened, so a board that stops dead on a module deck can
## read one tick of "not on floor" while going nowhere, and a circle
## traced over a parked board would fire a trick on the spot.
##
## `in_air()` is that reading with a DWELL: the board has to have been
## without support for AIR_ARM_TICKS consecutive physics ticks before it
## counts as flying, and it stops counting on the FIRST tick something
## holds it again. Two consequences, both deliberate and both gated by
## SkateTrickProbe:
##
##   * a one-tick flicker of the floor flag on a resting board never
##     arms (it is re-held on the next tick, because gravity puts a body
##     that is going nowhere straight back down);
##   * a hop shorter than the dwell -- a bump on the lawn -- is not an
##     air either. At 26 u/s^2 a body needs 0.78 u/s of vertical speed to
##     stay up 0.1 s; a launch off either quarterpipe at cruise stays up
##     several times that. The dwell is 6 ticks, 0.1 s.
##
## Landing is the transition back, and it is a SIGNAL because two things
## wait on it: the touch writer (which cuts a circle in progress and
## re-anchors the finger so the board does not turn on contact) and the
## flip (which has to finish before the board reads as upright again).
const AIR_ARM_TICKS: int = 6

signal took_off
signal landed

var _air_ticks: int = 0
var _in_air: bool = false

## =====================================================================
## CH64 -- THE FLIP: WHAT A TRICK LOOKS LIKE
##
## Two tricks, one per direction of the finger's circle: a KICKFLIP
## (clockwise on the glass) rolls the deck one full turn about its long
## axis one way, a HEELFLIP (anticlockwise) rolls it the other way. The
## roll is written on the DRAWN deck -- the MeshInstance3D child handed
## in by `adopt_visual()` -- never on this body: the rider is seated in
## this body's space, and a body that rolled would hang him upside down.
##
## The angle is INTEGRATED, not tweened, and it is the one place a rate
## lives: `_flip_target` steps by a whole turn per trick (so a second
## circle in the same air queues a second turn -- "cercles enchaines =
## trick repete"), and `_flip_angle` chases it at FLIP_RATE, tripled from
## the tick the board lands (a deck still mid-turn on the ground would
## read as broken, so it snaps round rather than stopping crooked).
## A full turn takes 0.33 s in the air; a typical launch off the big
## quarterpipe stays up ~0.7 s.
const FLIP_RATE: float = TAU / 0.33
const FLIP_LAND_GAIN: float = 3.0

var _visual: Node3D = null
var _flip_angle: float = 0.0
var _flip_target: float = 0.0
var _flip_turns: int = 0

func _ready() -> void:
	collision_layer = 1 << (LAYER_BOARD - 1)
	collision_mask = 1 << (LAYER_PARK - 1)
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	up_direction = Vector3.UP
	floor_snap_length = SNAP_LENGTH
	floor_max_angle = FLOOR_MAX_ANGLE
	# ⚠️ AND THE BODY MUST BE ALLOWED TO SLIDE BACK DOWN. Godot's default
	# is `true`, which pins a body to any slope it is standing on -- the
	# right default for a walker and the exact opposite of a transition,
	# whose entire behaviour is that you come back down it. With this
	# false, what brings the board down is the tangential gravity in
	# `drive()` and nothing else, which is also what makes the descent
	# RELAUNCH instead of merely releasing.
	floor_stop_on_slope = false
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

## The board's tuning, handed in by its owner. CH54's three numbers plus
## CH61's coast distance, and this file publishes none of them -- it
## SOLVES them, once, into the four accelerations the law of motion uses.
##
## ⚠️ THE FOUR DISTANCES ARE THE AUTHORED THING AND THE ACCELERATIONS ARE
## DERIVED, never the other way round. CLAUDE.md's most expensive
## recurring defect is a fact retyped somewhere else, and an acceleration
## typed here would be a second spelling of a run-up distance that lives
## in HubTransport. Solve, do not copy.
func configure(cruise: float, accel_u: float, brake_u: float, coast_u: float) -> void:
	_cruise = maxf(cruise, 0.01)
	_accel_u = maxf(accel_u, 0.0)
	_brake_u = maxf(brake_u, 0.0)
	_coast_u = maxf(coast_u, 0.01)
	var rest: float = PACE_FLOOR * _cruise
	# The coast, split between a quadratic term and a constant one so that
	# it both bites at speed and reaches zero in finite time -- and SOLVED
	# for the distance rather than for the deceleration.
	#
	# ⚠️ THE DIFFERENCE BETWEEN THE TWO IS A FACTOR OF 1.85 AND IT WAS
	# MEASURED, NOT SPOTTED. A first version set the total deceleration
	# at cruise to `cruise^2 / (2 coast_u)` -- the constant-deceleration
	# formula -- and the board coasted 33.166 u against a 18.043 u park.
	# The formula is right for ONE term and wrong for two: a quadratic
	# term contributes far less DISTANCE than its share of the
	# deceleration at cruise, because it fades as the square of a speed
	# that is falling.
	#
	# The closed form is short enough to write down. With
	# dv/dt = -(k v^2 + c), separating on distance gives
	#     x = (1 / 2k) * ln(1 + k V^2 / c)
	# and writing the share `s` of the deceleration at cruise carried by
	# the quadratic term (k V^2 = s D, c = (1 - s) D) turns that into
	#     x = V^2 * ln(1 / (1 - s)) / (2 s D),
	# i.e. D = V^2 * ln(1 / (1 - s)) / (2 s coast_u). PHASE L rolls the
	# board and measures the distance rather than trusting this block.
	var span: float = log(1.0 / (1.0 - COAST_QUADRATIC_SHARE))
	var total: float = _cruise * _cruise * span / (2.0 * COAST_QUADRATIC_SHARE * _coast_u)
	_drag_k = COAST_QUADRATIC_SHARE * total / (_cruise * _cruise)
	_roll_stop = (1.0 - COAST_QUADRATIC_SHARE) * total
	# =================================================================
	# ⚠️ AND THE PUSH AND THE BRAKE ARE SOLVED **AGAINST THE COAST**, not
	# in a vacuum -- which is the whole reason the coast is solved first.
	#
	# MEASURED, and it is why this block is not the two-line
	# v^2 = v0^2 + 2 a d it started as. With push and brake taken from
	# the frictionless identity, the flat run-up measured 4.492 u against
	# CH54's authored 3.20: the push now has the coast working against it
	# the whole way up, so the same acceleration buys less ground. The
	# frictionless numbers are not CH54's ride with inertia added -- they
	# are a slower ride wearing its labels.
	#
	# CH54's two DISTANCES are the authored things and the accelerations
	# follow from them. With v dv/dx = A - k v^2 (A = push - roll_stop)
	# the run-up integrates in closed form to
	#     A = k (V^2 - v0^2 E) / (1 - E),     E = exp(-2 k accel_u)
	# and the run-out, where the coast HELPS instead of hindering, to
	#     B = k (V^2 - v0^2 F) / (F - 1),     F = exp(+2 k brake_u)
	# with `brake = B - roll_stop`. PHASE L rolls both and gates the two
	# distances against CH54's published figures rather than re-deriving
	# them from this comment.
	var v0_sq: float = rest * rest
	var v_sq: float = _cruise * _cruise
	var e_up: float = exp(-2.0 * _drag_k * maxf(_accel_u, 0.01))
	var e_down: float = exp(2.0 * _drag_k * maxf(_brake_u, 0.01))
	_push = _roll_stop + _drag_k * (v_sq - v0_sq * e_up) / maxf(1.0 - e_up, 1e-6)
	_brake = _drag_k * (v_sq - v0_sq * e_down) / maxf(e_down - 1.0, 1e-6) - _roll_stop
	# A brake that solved negative would be a coast strong enough to stop
	# the board inside `brake_u` on its own; the run-out is then the coast
	# and there is nothing left to add. Written down because a negative
	# deceleration fed to `move_toward` would ACCELERATE the board into
	# its own target, silently.
	_brake = maxf(_brake, 0.0)

# =====================================================================
# WHAT IT PUBLISHES

## Where the rider's feet stand, in the board's own space. The one place
## this is spelled; HubTransport reads it and KeepyHopper is handed it.
func seat(deck_top: float) -> Vector3:
	return Vector3(0.0, deck_top, 0.0)

func flat_position() -> Vector3:
	return Vector3(global_position.x, 0.0, global_position.z)

## True while something is actively commanding this board -- pushing it
## or braking it. It replaces `has_target()`: the question every caller
## was really asking was "is it being driven", and the destination was
## only ever how that got expressed.
func driving() -> bool:
	return not is_zero_approx(_throttle)

## What is currently commanded. Published so a bench reads the command the
## board actually holds rather than the one it thinks it wrote.
func throttle() -> float:
	return _throttle

func heading() -> Vector3:
	return _heading

## ⚠️ CH61 -- "STANDING STILL UNDER HIM" NOW HAS TO MEAN IT.
##
## HubWorld reads this to tell a tap that means "get off" from a tap that
## means "steer", and CH58's rule is that a tap made mid-roll must STEER
## rather than eject the rider at speed. Under CH57's dictated pace the
## two were the same question: no target meant no velocity, on the tick.
## With inertia a board can have no target and still be rolling, so the
## speed has to be asked about as well or the rider is ejected off a
## moving board.
##
## The threshold is not a new number: it is `REST_STEP`, this file's one
## definition of not moving, converted from a per-tick step to a speed by
## the engine's own tick rate. Having two different answers to "is it
## moving" in one file is how a lot ships a contradiction.
func rest_speed() -> float:
	return REST_STEP * float(Engine.physics_ticks_per_second)

func speed() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()

func at_rest() -> bool:
	return _throttle <= 0.0 and speed() <= rest_speed()

## True on the tick the module held the board above HubSurface -- the
## observable that says "it is ON the funbox" without reading a height
## the probe would then have to trust.
func supported() -> bool:
	return _supported

## Flat distance covered on the last tick. Published so a bench measures
## the roll rather than differencing positions it also wrote.
func last_step() -> float:
	return _last_step

## ⚠️ CH62 -- HOW HIGH THE BOARD IS, AND IT IS PUBLISHED ONCE.
##
## Height above HubSurface, never below zero. Two readers need it and they
## would have written it identically: the camera (which climbs a share of
## it, so a climb reads as a climb) and the blob shadow (which shrinks and
## fades with it). CLAUDE.md -- un fait est publie une fois, jamais
## recopie -- and this one is a SUBTRACTION between two spellings of the
## ground, which is exactly the kind of expression two files drift on.
##
## Reads NOTHING this file does not already read: `_hub_floor()` computes
## the same difference every tick to decide whether something else is
## holding the board up. This is that number, exposed rather than thrown
## away.
func lift() -> float:
	return maxf(global_position.y - HubSurface.height_at(flat_position()), 0.0)

## The drawn deck, handed in once by HubTransport so a flip has something
## to roll. Null is legal (a bench that builds a bare body still drives).
func adopt_visual(visual: Node3D) -> void:
	_visual = visual

## CH64: the armed air -- see AIR_ARM_TICKS. This is what arms a trick;
## `airborne()` below is what a shadow and a sound read.
func in_air() -> bool:
	return _in_air

## How many consecutive ticks nothing has held the board. Published for
## the bench so the dwell is measured and not trusted.
func air_ticks() -> int:
	return _air_ticks

## One trick: queue a full turn of the deck. `clockwise` is the finger's
## sense on the glass; the two senses roll opposite ways.
func flip(clockwise: bool) -> void:
	_flip_target += -TAU if clockwise else TAU
	_flip_turns += 1

func flipping() -> bool:
	return absf(_flip_target - _flip_angle) > 0.0001

## The deck's current roll and how many turns have been asked for since
## the body was built. Read by the bench and by nothing else.
func flip_angle() -> float:
	return _flip_angle

func flip_turns() -> int:
	return _flip_turns

## True while nothing at all is under the board -- CH62's air reading.
##
## The two existing observables answer different questions and neither
## alone answers this one: `on_module()` is the ENGINE's floor contact,
## `supported()` is "the body is above HubSurface", which is true BOTH on
## a module and in mid-air. Air is the second minus the first, and the
## board could not be in that state at all before CH61 gave it a
## velocity.
func airborne() -> bool:
	return _supported and not _on_module

## CH61: the pace is no longer a state, it is a reading -- what fraction
## of cruise the board is actually doing. Nothing steers on it; the
## overlay and the probes print it.
func pace() -> float:
	return speed() / _cruise if _cruise > 0.0 else 0.0

## True while the ENGINE has the board on a module face. Distinct from
## `supported()`, which only says the board is above HubSurface and is
## therefore also true of a board in mid-air over the lawn -- a state
## that could not exist before this lot and can now.
func on_module() -> bool:
	return _on_module

## The four accelerations `configure()` solved, u/s^2 (and 1/u for the
## quadratic term). Published so a bench measures the law against the
## distances that authored it instead of re-deriving them: CLAUDE.md, a
## fact is published once and never retyped by its reader.
func push_accel() -> float:
	return _push

func brake_accel() -> float:
	return _brake

func drag_k() -> float:
	return _drag_k

func roll_stop() -> float:
	return _roll_stop

## The horizontal acceleration gravity applies on a surface of normal `n`
## -- |g_t| = G cos(theta) sin(theta), the same identity SledBody
## publishes for the sled's hill. Zero on the flat, zero on the vertical,
## largest at 45 deg.
static func slope_force(n: Vector3) -> float:
	return GRAVITY * n.y * Vector2(n.x, n.z).length()

## What the board can still push with at that slope: `push * n.y`, the
## grip term. Published beside `slope_force` for CH41's reason -- the two
## are only meaningful against each other, and a lot that retunes one
## without looking at the other ships a hill nothing can leave.
func climb_authority(n: Vector3) -> float:
	return _push * n.y

# =====================================================================
# THE COMMAND
#
# ⚠️ CH63 LOT 2 REPLACED A DESTINATION WITH A HEADING AND A THROTTLE, and
# reason is a correction of spec rather than a refactor. LOT 1 captured a
# held finger and expressed it as `set_target(point ahead)` because that
# was the only vocabulary this file had; Mathieu's contract is that a held
# finger PROPELS, continuously, and that a lifted one hands the board back
# to the coast. A destination cannot say that -- it says "go here and
# stop" -- so the vocabulary changed instead of the gesture being bent to
# fit it.
#
# What went with the destination, and it went for a reason each time:
#
#   * THE RUN-OUT on `remaining` -- braking because the target was inside
#     stopping distance. There is no target to be inside of. The BRAKE
#     itself survives, as the negative half of the throttle, because the
#     TAP scheme still needs a roll that ends where it was aimed.
#   * THE STALL GUARD -- dropping a target that stopped making progress.
#     See REST_STEP's block: a held throttle has a finger watching it, and
#     the destination scheme's guard moved to the file that still owns a
#     destination.

## The command, for the next tick and every tick until it is replaced.
##
## `heading` is taken flat and normalised; ZERO means "keep your own
## facing", which is what a finger inside the slop writes. `throttle` is
## clamped to [-1, +1]: positive pushes ALONG the heading, negative spends
## the brake against whatever velocity the board has, zero is free roll.
##
## ⚠️ IT DOES NOT TOUCH THE VELOCITY, in any of the three cases. That is
## the whole of what CH61's inertia means and this lot does not spend it:
## a command changes what the board is being asked for, never what it is
## already doing.
func hold(heading_in: Vector3, throttle_in: float) -> void:
	var flat := Vector3(heading_in.x, 0.0, heading_in.z)
	_heading = flat.normalized() if flat.length() > 0.0001 else Vector3.ZERO
	_throttle = clampf(throttle_in, -1.0, 1.0)

## Hands the board back to the coast: no push, no brake, no heading. The
## lifted finger, and the tap adapter's arrival, both land here.
##
## ⚠️ IT LEAVES THE VELOCITY ALONE, DELIBERATELY -- that is the difference
## between this and `stop()`, and getting the two the wrong way round
## would read on device as a handbrake on every lift.
func release() -> void:
	_heading = Vector3.ZERO
	_throttle = 0.0

## ⚠️ AND THIS ONE DOES ZERO THE VELOCITY. Every caller means "this board
## is done moving" -- the fence refusing a step out of the region,
## HubTransport mounting and dismounting a rider. None of them wants a
## board that keeps its elan across the event, and a dismount that left
## the board rolling away under the player's feet is the one thing worse
## than one that stops it too hard. It is `clear_target()`'s body under a
## name that says what it does now that there is no target to clear.
func stop() -> void:
	release()
	velocity = Vector3.ZERO

# =====================================================================
# THE TICK

func drive(delta: float) -> void:
	if delta <= 0.0:
		return
	var before := flat_position()
	# ⚠️ WHAT HOLDS THE BOARD UP IS READ FROM THE PREVIOUS STEP, and that
	# is the standard one-tick lag of every character controller in this
	# engine -- `is_on_floor()` and `get_floor_normal()` describe the
	# `move_and_slide` that has already happened. It is named here rather
	# than hidden because CLAUDE.md's turnstile measurement is exactly
	# this lag, and a reader who assumes the normal is this tick's would
	# mis-read every number the probes print.
	var n: Vector3 = Vector3.UP
	_held = false
	if is_on_floor():
		n = get_floor_normal()
		_held = true
	elif not _supported:
		# On the lawn, where D1 says there is no collider at all: the
		# surface itself is the support, and its normal is read from the
		# one accessor that publishes it. EXACTLY Vector3.UP while no
		# domain is registered -- so this is a no-op on today's flat hub
		# and correct on the day it is not, which is the only way to
		# write it that a later lot does not have to come back to.
		n = HubSurface.normal_at(before)
		_held = true
	_hold_normal = n

	# ---- the aim ----------------------------------------------------
	# ⚠️ A COMMANDED HEADING OF ZERO IS "STRAIGHT ON", NOT "NOWHERE". The
	# push needs a direction every tick it is asked for, and the board's
	# own facing is the only honest answer when the finger has not asked
	# for another one. Reading it off `rotation.y` rather than off the
	# velocity is deliberate: a board pushed from a standstill has no
	# velocity to read a direction from, and one sliding sideways would
	# be pushed sideways.
	var aim: Vector3 = _heading
	if aim == Vector3.ZERO:
		aim = Vector3(sin(rotation.y), 0.0, cos(rotation.y))

	# ---- 1-3: the drive model, on the HORIZONTAL velocity ------------
	# It PERSISTS. Nothing below rewrites it from a profile; every term
	# adds to or subtracts from what the last tick left, which is the
	# whole of what "inertie" means here.
	var vh := Vector3(velocity.x, 0.0, velocity.z)
	var was: float = vh.length()
	if _throttle > 0.0:
		# The push. Capped ALONG THE HEADING, so a board already faster
		# than cruise (down a transition) is not pushed further, and a
		# board rolling sideways to where the finger points still gets the
		# full push toward it.
		#
		# ⚠️ THE LAST STEP IS TRIMMED TO THE CAP RATHER THAN TAKEN WHOLE.
		# Measured before it was: a plain `if along < cruise` lets the
		# final tick add a whole `push * delta` on top, and the flat run
		# topped out at 10.180 u/s against CH54's 10.00. A cap that a tick
		# can step over is not a cap, and 0.18 u/s of it is exactly the
		# kind of number a later lot finds in a table and cannot explain.
		var along: float = vh.dot(aim)
		if along < _cruise:
			vh += aim * minf(_push * n.y * delta * _throttle, _cruise - along)
	elif _throttle < 0.0:
		# The brake, against the velocity itself rather than along the
		# heading: a brake that pushed backwards along the aim would turn
		# a board that is sliding sideways, which is a steering input
		# wearing a brake's name.
		vh = vh.move_toward(Vector3.ZERO, _brake * n.y * delta * absf(_throttle))
	# The coast, always -- a pushed board pays it too, which is why the
	# terminal speed on the flat is a hair under cruise rather than
	# exactly it, and why PHASE L gates the run-up on distance rather
	# than on a speed equality that would be false in the last decimal.
	vh -= vh * minf(_drag_k * was * delta, 1.0)
	vh = vh.move_toward(Vector3.ZERO, _roll_stop * n.y * delta)
	velocity.x = vh.x
	velocity.z = vh.z

	# ---- 4: gravity, AFTER the drive model (CH41) --------------------
	var g := Vector3(0.0, -GRAVITY, 0.0)
	if _held:
		# The surface takes the component going INTO it -- and only that
		# one, so a board thrown clear of a lip keeps the velocity that
		# throws it. Then the TANGENTIAL part of gravity, which is the
		# whole lot in one line: it opposes a climb and drives a descent.
		var into: float = velocity.dot(n)
		if into < 0.0:
			velocity -= n * into
		velocity += (g - n * g.dot(n)) * delta
	else:
		velocity += g * delta

	if _heading != Vector3.ZERO:
		# ⚠️ SET, NOT TWEENED, AND THE REASON IS NOW THE OPPOSITE OF CH57's.
		# That lot wrote "a body that rotates while it travels reads as
		# being steered, and this one is not steered". This one IS steered
		# -- that is the lot -- so the facing is the finger's, directly and
		# with no rate between them, which is what "la direction suit la
		# position du doigt en continu" says.
		#
		# What keeps that from reading as a snap is not smoothing here:
		# the VELOCITY is integrated (a reversed heading spends `push`
		# against the momentum rather than teleporting it) and the chase
		# camera lags the board's heading by DRIVE_HEADING_LAMBDA. If
		# device says it is still too abrupt, a turn RATE is the first
		# knob and it belongs in a feel lot with a number measured on a
		# phone, not invented here.
		rotation.y = atan2(_heading.x, _heading.z)
	move_and_slide()
	_on_module = is_on_floor()
	_supported = _hub_floor()
	_fence(before)
	_last_step = flat_position().distance_to(before)
	_advance_air(delta)

## CH64: the dwell and the two edges, then the flip. Read AFTER the move,
## on this tick's own support -- the one place the lagging floor flag is
## consulted where its lag cannot fabricate an air (a board that is held
## on this tick is not in the air on this tick, whatever last tick said).
func _advance_air(delta: float) -> void:
	var held_now: bool = _on_module or not _supported
	if held_now:
		_air_ticks = 0
		if _in_air:
			_in_air = false
			landed.emit()
	else:
		_air_ticks += 1
		if not _in_air and _air_ticks >= AIR_ARM_TICKS:
			_in_air = true
			took_off.emit()
	if flipping():
		var rate: float = FLIP_RATE * (1.0 if _in_air else FLIP_LAND_GAIN)
		_flip_angle = move_toward(_flip_angle, _flip_target, rate * delta)
		if _visual != null:
			_visual.rotation.z = _flip_angle

## HubSurface OVERRULES the engine, and this is the whole of D1's ground
## ownership in four lines. Returns true when the body was ABOVE the
## surface, i.e. when something else was holding it up.
func _hub_floor() -> bool:
	var ground: float = HubSurface.height_at(flat_position())
	if global_position.y < ground:
		global_position.y = ground
		if velocity.y < 0.0:
			# ⚠️ ONLY THE COMPONENT INTO THE SURFACE, and on a flat hub
			# that is the whole of velocity.y. Written as a projection
			# rather than as `= 0.0` so that the day HubSurface has a
			# slope under the park, a board landing on it keeps the part
			# of its fall that runs ALONG the ground instead of losing
			# it -- the same rule the module branch in `drive()` uses,
			# and one spelling of it would have been enough if the two
			# supports were the same object. They are not, so it is
			# written twice and gated once.
			var sn: Vector3 = HubSurface.normal_at(flat_position())
			var into: float = velocity.dot(sn)
			if into < 0.0:
				velocity -= sn * into
		return false
	return global_position.y > ground + 0.0005

## The region is the wall, exactly as it is for the three other piloted
## vehicles (SandYacht._wall, SledBody._wall): a refusal that puts the
## body back where it was rather than a clamp that slides it along an
## edge.
##
## ⚠️ IT STOPS THE BOARD AND SAYS SO, AND THE SAYING IS THE NEW HALF. Under
## the destination scheme the fence cleared the target itself, because the
## stall guard was otherwise the only thing that could ever end a push into
## a wall. There is no target here to clear -- so the fence emits, and
## HubTransport's tap adapter drops its destination when it hears it. The
## DRAG scheme needs no such rescue and takes none: a finger held into the
## border keeps commanding a heading, the board is refused every tick, and
## the player steers away whenever he likes.
##
## ⚠️ AND THAT IS ONLY SAFE BECAUSE THE HEADING IS WRITTEN, NOT INTEGRATED.
## CLAUDE.md's CH42 arithmetic -- "le gain de braquage est proportionnel a
## v_fwd, donc un mur supprime la direction" -- has cost this repo three
## vehicles, and it bites a model whose turn rate is scaled by the forward
## speed a wall is eating. This board's facing comes straight from the
## thumb, so a board pinned against the region keeps every degree of its
## steering authority.
signal fenced

func _fence(before: Vector3) -> void:
	if HubRegion.contains(flat_position()):
		return
	global_position = Vector3(before.x, global_position.y, before.z)
	velocity.x = 0.0
	velocity.z = 0.0
	release()
	fenced.emit()
