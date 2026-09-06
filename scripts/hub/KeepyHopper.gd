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
## given three events per HOP_DURATION instead of a constant velocity that
## reads as a sprite being dragged.
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
## responsiveness and buys a body that obeys momentum.
##
## The queue is deliberately DEPTH ONE. A queue of taps would replay a
## stale path the player has already changed their mind about; the only
## destination that has ever been interesting is the most recent one.

## =====================================================================
## RIDING (26 aout 2026)
##
## A third state, not a second movement system. The hop code below is
## untouched by it: RIDING replaces where the body is written from (an
## abscissa along a HubStreamRoute instead of a tween along a chord), and
## every entry and exit from it goes back through the same _advance() the
## taps already used.
##
## The state machine used to be a bool. It is an enum now because there are
## three states and a bool cannot say which of two non-hopping states it is
## in -- and "is Keepy on the boat" is the question the portal check has to
## ask (see HubWorld._on_hop_landed).
##
## WHAT THE RIDE DELIBERATELY DOES NOT HAVE: no physics, no collision, no
## buoyancy, no per-frame steering. The boat is not simulated floating on
## water, it is drawn at the arc length the ride has reached. Everything on
## this plateau is decor without a collider, and the ride does not change
## that.

## Length of a single hop, in world units. Distance to the target shorter
## than this is covered by one final, shorter hop rather than by a partial
## one -- an abrupt half-length landing reads better than a hop that stops
## in mid-arc.
const HOP_DISTANCE: float = 1.5

## Peak height of the arc.
const HOP_HEIGHT: float = 0.6

## Wall-clock length of one hop, ground to ground.
##
## 0.35 until 25 aout 2026, when the plateau had grown to a half-extent of
## 25 and crossing it had become the complaint. This is the ONLY constant
## that shortens a hop without lengthening the stride: HOP_DISTANCE buys
## the same crossing time by making Keepy cover more ground per hop, which
## leaves the visual cadence alone; this one speeds the hop itself, so it
## is also the one that spends the weight the squash envelope below exists
## to sell. That trade is the whole reason the value is tuned here rather
## than in HOP_DISTANCE -- it was asked for as a feel change, not as a
## distance change.
##
## Measured on the shipped hopper at --fixed-fps 60, plateau half-extent
## 25, HOP_DISTANCE untouched -- so the hop COUNT is identical on both
## rows and only the seconds move, which is the check that this constant
## and nothing else changed:
##
##   trip                        hops   0.35       0.28
##   centre -> (25,0)              17   5.950 s    4.817 s
##   (-25,-25) -> (25,25)          47   16.450 s   13.317 s
##
## Those are WALL-CLOCK frame counts, not hops x this constant, and the
## two stopped agreeing here: 0.35 is exactly 21 frames at 60fps, 0.28 is
## 16.8, so a hop actually occupies 17 frames (0.2833s) and every trip
## costs ~1.2% more than the nominal arithmetic predicts. Small, but it is
## why the numbers above are 4.817/13.317 rather than the 4.76/13.16 a
## multiplication gives -- a future tune should quote the measured row.
##
## Note the landing recoil below is 0.12s of WALL CLOCK, not a fraction of
## this: shortening the hop makes the recoil a larger share of it (34% at
## 0.35, 43% at 0.28). It is still shorter than a hop, so the next hop's
## own takeoff squash still overwrites it -- but it is the first thing to
## look at if this value is ever taken much lower.
const HOP_DURATION: float = 0.28

## How close to the target counts as arrived. Slightly under a third of a
## hop: below this, another hop would overshoot and Keepy would oscillate
## around the point forever.
const ARRIVE_EPSILON: float = 0.45

## =====================================================================
## THE RIDE

## The floor RIDE_SPEED must clear for the stream to be a SHORTCUT rather
## than a scenic detour, in world units per second.
##
## MEASURED, not chosen: StreamGeometryProbe walks the shipped trace and
## reports it. The stream MEANDERS -- its spine is 41.2837 u against a
## 36.87 u straight line between the same two endpoints, a ratio of 1.1197
## -- while a hop chain crosses that straight line in 25 hops of 17 frames
## each. Below this speed a rider covering the longer path arrives LATER
## than someone who simply hopped, which would make the boat a slower way
## to travel that happens to look nicer.
##
## Do not lower ride_speed under this. The check in _ready() is what stops
## a future tune doing it by accident.
const RIDE_SPEED_FLOOR: float = 5.8283

## Speed along the stream spine, in world units per second.
##
## 8.0 puts the ride at roughly 5.2 s over the water against 7.08 s for the
## equivalent hop chain -- a real shortcut with room above the floor above,
## rather than a value sitting on it. Exported so it can be tuned from the
## scene without a code edit; the floor is a const so a probe can read it
## off the class without instancing anything.
@export var ride_speed: float = 8.0

## Arc height of the EJECT hop -- the one leap that carries Keepy off the
## boat and onto the bank. Deliberately taller than HOP_HEIGHT: leaving a
## boat is a different event from crossing the plateau, and the arc is the
## only channel that says so without a sound or a new mesh.
const EJECT_HOP_HEIGHT: float = 1.05

## =====================================================================
## THE BOARD

## Wall-clock length of the ladder climb, ground to deck. Fixed rather
## than derived from the height: the climb is scripted and uninterruptible,
## so it is a beat in the screen's rhythm before it is a distance, and a
## taller board should read as a taller board rather than as a longer wait.
##
## UNCHANGED by the 27 aout 2026 cadence rework below: that batch was asked
## to change the RHYTHM of the climb, not its length, and it does not touch
## this constant. What moved is how the same 0.85 s is spent.
const CLIMB_DURATION: float = 0.85

## The fraction of CLIMB_DURATION spent climbing RUNGS rather than mounting
## the deck. Same value as before the 27 aout 2026 cadence rework, but its
## meaning changed with it: this used to be "the fraction spent rising"
## against a flat walk-out; now it is the boundary between the quantized
## rung-by-rung tractions (see _apply_climb) and the final mounting hop
## (see CLIMB_MOUNT_HOP_HEIGHT), which folds what used to be that flat
## walk into one short arc onto the anchor.
const CLIMB_RISE_FRACTION: float = 0.72

## =====================================================================
## CLIMB CADENCE (27 aout 2026)
##
## The climb used to be one smooth lerp from the ladder foot to the
## anchor -- Mathieu's own word for it on device was "like an elevator".
## The fix is rhythm, not distance: the rise is now RUNG_COUNT - 1
## discrete tractions (RUNG_COUNT read off the board HubBuilder actually
## built -- board["rung_heights"], never a second copy of its formula),
## each a quick push followed by a still micro-pause, so the eye is given
## a repeated grab-and-settle beat instead of one constant velocity. The
## last rung is not a traction of its own -- see the header on
## _apply_climb for why -- it is folded into the final mounting hop.
##
## Keepy has no skeleton and no separable parts (measured on the .glb:
## one node, one mesh, one primitive, zero skins -- see the file header
## above), so nothing here can animate a hand closing on a rung. Every
## beat is sold by the body's own transform: height that pauses, a
## squash borrowed unchanged from the hop envelope, and a small sway.

## Fraction of ONE traction slot spent PUSHING (rising, eased out) rather
## than held in the pause that follows it. Exported rather than a const:
## the SOBER / MEDIAN / MARKED rows on the cadence sheet
## (docs/color-sheets/) are this same field at three values on three
## instanced hoppers, and MEDIAN -- the default below -- is what ships.
## No sonde judges cadence, only an eye can -- and it has: MEDIAN
## (0.55 / 0.05, this row and climb_sway_amplitude below) was validated on
## device by Mathieu on 27 Aug 2026.
@export var climb_push_ratio: float = 0.55

## Lateral sway on each push, in world units, perpendicular to the ladder
## (board["side"]) and alternating rung to rung. Zero again by the time
## the pause begins: sin(PI * push_t) returns to 0 at push_t = 1, so the
## feet are back directly over the ladder foot for every held rung, and a
## rung that is HELD still reads as gripped rather than swaying under him.
## Same exposure reasoning as climb_push_ratio above -- and the same
## device validation, 27 Aug 2026.
@export var climb_sway_amplitude: float = 0.05

## Arc height of the final beat -- the hop from the last quantized rung
## onto the deck, ON TOP OF the rise from that rung's height to the
## anchor's. Deliberately SMALLER than an ordinary HOP_HEIGHT (0.6): the
## escalation the eject (1.05) and the dive (1.55) each argue for is
## "further from where you started", and this beat starts one rung below
## the platform it lands on -- the smallest event this file arcs, not
## the biggest. "a small crossing", not a leap.
const CLIMB_MOUNT_HOP_HEIGHT: float = 0.40

## Arc height of the dive, ON TOP of the drop from the deck.
##
## Taller than EJECT_HOP_HEIGHT (1.05), which is itself taller than an
## ordinary hop, and for the escalating version of the same reason: the
## arc is the only channel this screen has for saying that one leap is a
## bigger event than another, and a dive off a board is the biggest one on
## it. It is measured from the sloped base line the generalised arc draws,
## so the actual apex clears the deck rather than merely clearing the
## water.
const DIVE_HOP_HEIGHT: float = 1.55

## Wall-clock length of the dive. Longer than HOP_DURATION because it
## covers more ground and more height; a dive at hop speed reads as a
## stumble off the end.
const DIVE_DURATION: float = 0.62

## How high Keepy's feet ride while aboard.
##
## The shell's inner floor, near enough: HubBuilder floats the rim at
## BOAT_FLOAT_Y with the keel BOAT_DEPTH under it, and a rider standing at
## y = 0 would be knee-deep through the hull. StreamRideProbe asserts this
## sits between that keel and that rim rather than trusting two files to
## keep agreeing -- the number lives here because it is where the BODY is
## written, and the relationship is gated because that is what stops it
## drifting.
const RIDE_SEAT_Y: float = 0.14

## Arc height of the step off the turnstile, ON TOP of the drop from the
## deck to the ground.
##
## SMALLER than an ordinary hop (0.6) and than every other special arc on
## this screen -- the climb's mount is 0.40, the boat's eject 1.05, the
## dive 1.55. The escalation those three argue for is "further from where
## you started", and stepping off a knee-high roundabout is the SMALLEST of
## the set: the sloped base line already carries the body down 0.31 on its
## own, so the apex still clears the deck without the arc having to say
## anything grander than "he got off".
const TURNSTILE_DISMOUNT_HOP_HEIGHT: float = 0.50

## How far past the outward-facing lock a dismount is aimed, in world units.
## The caller passes the landing itself -- HubWorld is the only thing that
## knows both the prop's clear radius and what props a landing has to miss
## -- so this file never computes one.

## How far past the ribbon's edge a disembark aims, in world units. The
## ribbon's own half-width is layout data (HubStreamRoute knows the curve,
## not the width), so the bank offset is passed in by the caller and this
## is only the extra clearance beyond it.
const BANK_MARGIN: float = 0.75

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

## Emitted every frame of a ride, with where the hull should be drawn and
## which way it should face. KeepyHopper moves KEEPY; the boat is decor
## owned by HubBuilder, so it is moved by whoever listens to this rather
## than by this file reaching into the prop tree.
signal ride_moved(position: Vector3, yaw_degrees: float)

## Emitted once when a ride starts, and once when it ends. HubWorld uses
## the pair to hold the mooring off while the hull is being carried.
signal ride_started()
signal ride_ended()

## The board, one signal per transition: planted on the deck, left it, and
## the dive's landing. Nothing routes on them -- the landing still arrives
## as an ordinary hop_landed, which is what keeps the water tint and every
## other landing listener working through a dive without knowing a board
## exists. They are here because "is he up there" is the question a future
## camera or cue will want, and asking a state enum from another file is
## how that enum stops being private.
signal board_mounted()
signal board_dived()
signal board_dismounted()

## The turnstile, mounted and left. Same shape and same purpose as the ride
## pair: HubWorld listens so it can hold other reactions off for the
## duration, and so the prop and the rider are never two opinions.
signal turnstile_mounted()
signal turnstile_dismounted()

## Emitted when a seesaw ride starts and when it ends, the turnstile pair's
## twins. The dismount fires AFTER the landing, so a listener sees the
## ground he arrived on rather than the plank he left.
signal seesaw_mounted
signal seesaw_dismounted

## Keepy has been put on the owl's back, and has been let off it again.
signal owl_flight_mounted
signal owl_flight_dismounted

## Keepy has taken hold of the zipline trolley, and has let go of it again.
##
## `zipline_mounted` fires at the END of the step off the deck, not at the
## tap: boarding is an arc up off the stair foot and there is nothing to
## carry until it lands on the handle. HubWorld starts the trip on this
## signal, so a trip can never begin under a body that is still in the air.
signal zipline_mounted
signal zipline_dismounted

## Yaw carrier. Kept separate from this node so world position (written by
## the hop) and facing (written by the turn) never contend for one
## transform, and separate from the model slot so pitch stays body-local.
@onready var _yaw: Node3D = $Yaw

## The ModelSlot drawing Keepy. Pitch and squash are written HERE, never on
## the slot's own model_* art corrections -- those are authored placement,
## this is animation, and the two must not fight over one property.
@onready var _body: ModelSlot = $Yaw/Body

## The slot drawing Keepy, READ-ONLY, for a caller that needs to recolour
## him. The one thing this file exposes about its own art.
##
## Handed over rather than let HubWorld walk `Keepy/Yaw/Body` itself: that
## path is this file's private business, and a second copy of it in another
## file is exactly how a rename becomes a silent null. Nothing here writes
## to the returned slot -- the hop's own squash and pitch still go through
## `_body` above, and a caller that tints it is writing a material, not a
## transform, so the two never contend.
func body_slot() -> ModelSlot:
	return _body

var _base_scale: Vector3 = Vector3.ONE
var _base_pitch: float = 0.0

## Destination requested by the player. Depth one, on purpose (see header).
var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false

## =====================================================================
## THE BOARD (27 aout 2026)
##
## Three more states, and the same shape as RIDING before them: none of
## them is a second movement system. CLIMBING and DIVING each replace
## where the body is written from for their own duration and hand back to
## the ordinary chain when they end; ON_BOARD writes nothing at all.
##
## WHY THE DECK IS NOT WALKABLE, on purpose. The plateau is a
## single-altitude model -- HubRegion.contains() throws Y away and
## HubTapInput raycasts a plane at y = 0 -- so there is no such thing as a
## tap that means "a point on the deck". Letting Keepy move freely up there
## would need a second, elevated ground for taps to resolve against, which
## is a plateau-wide change for one plank. Instead the board has exactly
## one standing place, and a tap while on it means DIVE, not WALK.
##
## Which is also why the tap is intercepted BY STATE, exactly as a tap
## during a ride is: the ground point still arrives resolved on y = 0, and
## it is still useful -- its side of the anchor is what picks the water
## dive from the landward one -- but it must never become a destination.
##
## The three of them share RIDING's other property too: they emit no
## hop_landed, so portal detection is silent for their whole duration. A
## board planted 9 u from the portal row would otherwise carry a diver into
## a sub-game they were only passing over.
enum State { IDLE, HOPPING, RIDING, CLIMBING, ON_BOARD, DIVING, ON_TURNSTILE, ON_SEESAW, ON_OWL_FLIGHT, ON_ZIPLINE, ON_CARRIER, ON_TREE }

var _state: State = State.IDLE
var _hop_from: Vector3 = Vector3.ZERO
var _hop_to: Vector3 = Vector3.ZERO
var _hop_tween: Tween = null

## Arc height of the hop in progress. Normally HOP_HEIGHT; raised for the
## single leap off the boat. Reset on every _begin_hop so a taller arc can
## never leak into the hop after it.
var _hop_height: float = HOP_HEIGHT

## Ground height at the two ends of the hop in progress, in world units.
##
## BOTH DEFAULT TO ZERO, and every hop the plateau has ever taken leaves
## them there: the plateau is a single-altitude model (HubRegion.contains()
## throws Y away, HubTapInput raycasts a plane at y = 0), so a hop between
## two points on it starts and ends on the ground by definition.
##
## They exist so ONE hop can start high and land low -- the dive off the
## board. Generalising the existing arc rather than adding a second one is
## deliberate: the squash envelope, the pitch and the landing recoil are
## all driven off the same normalised t as the height, and a parallel
## "high hop" implementation would be a second copy of all of them, free
## to drift from the one the whole plateau uses.
##
## The generalisation is EXACT at from == to, not merely close: at equal
## endpoints lerpf returns that value for every t, so the parabola is
## added to a constant and the trajectory is the one that shipped. Proved
## rather than argued -- DivingBoardProbe PHASE A samples the shipped
## _apply_hop against the pre-change formula and reports the worst
## divergence over the whole hop.
var _hop_from_y: float = 0.0
var _hop_to_y: float = 0.0

## The board this body is climbing, standing on or diving off, in the shape
## HubBuilder.diving_board() publishes. Empty whenever none of those three
## states is current.
var _board: Dictionary = {}
var _climb_tween: Tween = null

## Ride state. _route is null whenever _state is not RIDING.
var _route: HubStreamRoute = null
var _ride_s: float = 0.0
var _ride_dir: float = 1.0
## Half-width of the ribbon being ridden, so a disembark knows how far
## sideways the bank is. Passed in at boarding -- the width is layout data
## and this file only ever sees the curve.
var _ride_half_width: float = 0.0

## The turnstile pivot Keepy is riding, and where he sits IN THAT PIVOT'S
## OWN LOCAL SPACE. Both null/zero whenever _state is not ON_TURNSTILE.
##
## ⚠️ A LOCAL OFFSET AND A to_global() EVERY FRAME, never an angle of our
## own advanced alongside the prop's. Two numbers turning at the same rate
## is the definition of a thing that drifts; ONE transform applied to a
## fixed offset cannot, because it is the same transform the deck and the
## bars are drawn with. The brief asked for the spin to be synchronised
## rather than paralleled, and this is what makes it synchronised by
## construction instead of by tuning.
var _turnstile: Node3D = null
var _turnstile_seat: Vector3 = Vector3.ZERO

## The seesaw pivot Keepy is riding and where he sits IN THAT PIVOT'S OWN
## LOCAL SPACE. Both null/zero whenever _state is not ON_SEESAW.
##
## ⚠️ THE SAME LOCAL-OFFSET-AND-to_global RULE the turnstile states above,
## and it carries MORE here for free. A seesaw tilts, so the seat's world
## HEIGHT changes as well as its position -- and because the offset is
## local and the transform is the plank's own, the height comes out of the
## same multiply the plank is drawn with. A rider whose Y was advanced on a
## clock of its own would be a second number turning at the same rate,
## which is the definition of the thing that drifts.
var _seesaw: Node3D = null
var _seesaw_seat: Vector3 = Vector3.ZERO

## The owl currently carrying him, and where on it he sits -- in that
## node's own local space, so a seat written once stays put through every
## yaw and every metre of the loop.
var _owl: Node3D = null
var _owl_seat: Vector3 = Vector3.ZERO

## The zipline trolley currently carrying him, and where on it he hangs --
## in that node's own local space, so the seat is `(lateral, height,
## abscissa)` in the CARRIER's frame and never a world point.
##
## ⚠️ THIS IS THE SHAPE `RIDE_SEAT_Y` COULD NOT TAKE, and RECON 4 measured
## why. That constant is a bare float with ONE reader, written straight
## onto this body: it has no notion of an occupant, no lateral offset, and
## therefore no path at all for a SECOND rider. A trolley carries two, so
## the seat has to be a vector in the carrier's frame -- which is also what
## lets the badger's seat be the same fact with the opposite sign.
var _zipline: Node3D = null
var _zipline_seat: Vector3 = Vector3.ZERO

## Backward lean while hanging, in degrees. `_apply_hop` subtracts to pitch
## FORWARD into an arc, so a positive number here leans the body back --
## the pose of somebody being pulled along by their hands.
const ZIPLINE_HANG_PITCH_DEG: float = 12.0

## How high the arc off the stair foot rises above the straight line to the
## handle. Small: it is a step off a platform onto a grip a third of a unit
## below it, not a leap.
const ZIPLINE_BOARD_HOP_HEIGHT: float = 0.28

func _ready() -> void:
	_base_scale = _body.scale
	_base_pitch = _body.rotation_degrees.x
	_target = global_position
	if ride_speed < RIDE_SPEED_FLOOR:
		push_error("KeepyHopper: ride_speed %.4f is under the measured shortcut floor %.4f -- the stream would be SLOWER than hopping." % [ride_speed, RIDE_SPEED_FLOOR])

## Asks Keepy to travel to `point`. Safe to call at any time and as often
## as the player taps: mid-hop it only replaces the destination, and the
## new one is acted on at the next landing.
func hop_to(point: Vector3) -> void:
	# A tap during a ride is an EJECT, not a destination -- and it is
	# HubWorld that knows the props a landing has to clear, so it routes
	# that tap to leave_ride() instead. Refusing here is the second half of
	# that: a stray hop_to mid-ride would leave the body walking while the
	# hull kept sailing.
	# CLIMBING / ON_BOARD / DIVING are refused for the same reason RIDING
	# is: the body is being written from somewhere else for the duration,
	# and a stray hop_to would leave it walking while the plank, the
	# ladder or the arc kept driving it. HubWorld routes a tap in those
	# states to the board instead -- see _on_tapped_ground.
	# ON_TURNSTILE joins them for the same reason and needs no line of its
	# own: the test is "is anything else writing the body", and the answer
	# for a rider being swung round a pivot is yes.
	if _state != State.IDLE and _state != State.HOPPING:
		return
	_target = Vector3(point.x, 0.0, point.z)
	_has_target = true
	if _state == State.IDLE:
		_advance()

## True while a hop is in the air. Read by the camera so it can hold still
## rather than chase the vertical arc.
func is_hopping() -> bool:
	return _state == State.HOPPING

## True while Keepy is carried by the boat. Read by HubWorld to hold the
## mooring off, and -- the load-bearing one -- to keep portal detection
## silent for the whole ride.
func is_riding() -> bool:
	return _state == State.RIDING

## True while the turnstile is carrying him.
##
## ⚠️ DELIBERATELY NOT FOLDED INTO is_on_board(). That query exists because
## the three board states all answer ONE question the same way -- "may I
## treat a tap as a destination", no -- and a caller that asked it got the
## right answer for all three. This state answers that question the same
## way but a DIFFERENT one differently: a tap while standing on the plank
## means DIVE, and a tap while being swung round a roundabout means
## nothing at all. Folding it in would make is_standing_on_board() the only
## thing keeping a turnstile rider from diving off a plank he is not on,
## which is a load-bearing job for a query that was never given it.
func is_on_turnstile() -> bool:
	return _state == State.ON_TURNSTILE

## True while a seesaw owns the body. Like ON_TURNSTILE it emits no
## landings, so portal detection, boarding and climbing all go quiet for the
## whole ride without any of them needing a line about seesaws.
func is_on_seesaw() -> bool:
	return _state == State.ON_SEESAW

## True while the owl is carrying him round its loop.
func is_on_owl_flight() -> bool:
	return _state == State.ON_OWL_FLIGHT

## True while the trolley owns the body -- from the handle being taken to
## the drop at the far end. Like every other carried state it emits no
## landings, so portal detection, boarding and climbing all go quiet for
## the whole trip without any of them needing a line about ziplines.
func is_on_zipline() -> bool:
	return _state == State.ON_ZIPLINE

## True from the first rung to the moment the feet hit the water: the whole
## span in which the body belongs to the board rather than to the plateau.
##
## ONE query for the three states rather than three, because every caller
## outside this file asks the same question -- "may I treat a tap as a
## destination" -- and answering it in one place is what stops a fourth
## board state being added later and quietly missed by two of them.
func is_on_board() -> bool:
	return _state == State.CLIMBING or _state == State.ON_BOARD or _state == State.DIVING

## True only while planted on the deck, which is the one board state that
## can accept a tap. Read by HubWorld to tell a tap-that-dives from a tap
## that lands during a climb or a dive and must simply be dropped.
func is_standing_on_board() -> bool:
	return _state == State.ON_BOARD

## Puts Keepy on the boat and starts the ride.
##
## `route`      the stream, arc-length parameterised (built from the spine
##              HubBuilder actually ribboned -- see HubStreamRoute).
## `half_width` half the ribbon's width, so a disembark knows where the
##              bank is. Layout data; this file never guesses it.
## `toward`     the point the player asked for. Its PROJECTION onto the
##              spine decides which way the boat goes, so a tap upstream
##              and a tap downstream do opposite things with no direction
##              flag anywhere in the layout.
##
## Refused, quietly, on an invalid route or while already riding: a hub
## that silently does nothing beats one that crashes on the screen every
## game is reached through.
func board(route: HubStreamRoute, half_width: float, toward: Vector3) -> void:
	if route == null or not route.is_valid() or _state == State.RIDING:
		return
	dismount_vehicle()
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()

	_route = route
	_ride_half_width = maxf(half_width, 0.0)
	_ride_s = route.project(global_position)
	_has_target = false

	var target_s: float = route.project(toward)
	if absf(target_s - _ride_s) < 0.001:
		# The tap projects onto where Keepy already is, so it says nothing
		# about a direction. Head for the FAR end rather than refusing: a
		# player who tapped the boat asked to travel, and standing still
		# would read as the tap having been swallowed.
		_ride_dir = 1.0 if _ride_s < route.length() * 0.5 else -1.0
	else:
		_ride_dir = signf(target_s - _ride_s)

	_state = State.RIDING
	_body.scale = _base_scale
	_body.rotation_degrees.x = _base_pitch
	_place_on_route()
	ride_started.emit()

## Steps onto the turnstile and starts turning with it.
##
## `pivot` is the prop's spinner node, `deck_y` the TOP of its deck and
## `radius` how far out a rider sits -- all three in the pivot's own local
## space, all three published by HubBuilder from the pass that drew them.
## Nothing here re-derives any of them: the deck a rider stands on and the
## deck that was drawn have to be one fact.
##
## Refused, quietly, unless he is standing still. A mount mid-hop would
## teleport a body that is currently mid-arc, and a mount while another
## state already owns him is the same overlap every other entry point on
## this file refuses.
##
## THE SEAT ANGLE IS SNAPPED TO A GAP BETWEEN TWO BARS, and to the gap
## NEAREST THE WAY HE CAME. Two things are wanted and they pull apart: a
## rider standing inside a grip rail is wrong, and a rider who teleports
## round to the far side of the disc the instant he arrives is worse.
## Snapping to the nearest gap satisfies both -- he never moves more than
## half a gap from where he landed, and he never lands on a bar.
func mount_turnstile(pivot: Node3D, deck_y: float, radius: float, bars: int) -> bool:
	if pivot == null or not is_instance_valid(pivot):
		return false
	if _state != State.IDLE:
		return false
	dismount_vehicle()
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()

	# Where he is standing, expressed in the pivot's frame, so the gap is
	# chosen against the deck as it is turned RIGHT NOW rather than against
	# the layout's idea of which way it faces.
	var local: Vector3 = pivot.to_local(global_position)
	var arrival: float = atan2(local.z, local.x)
	var count: int = maxi(bars, 1)
	var step: float = TAU / float(count)
	# The bars sit at k*step exactly (HubBuilder builds them that way), so
	# the gaps sit half a step off them.
	var seat_angle: float = arrival
	if count > 0:
		var k: float = round((arrival - step * 0.5) / step)
		seat_angle = k * step + step * 0.5

	_turnstile = pivot
	_turnstile_seat = Vector3(cos(seat_angle) * radius, deck_y, sin(seat_angle) * radius)
	_has_target = false
	_state = State.ON_TURNSTILE
	# Rest pose, as every state that takes the body over sets it: a squash
	# left over from the landing that mounted him would ride round with him.
	_body.scale = _base_scale
	_body.rotation_degrees.x = _base_pitch
	follow_turnstile()
	turnstile_mounted.emit()
	return true

## Writes Keepy at the seat for the pivot's CURRENT facing. The ONE place a
## turnstile ride touches a transform -- the same rule _place_on_route()
## states, for the same reason.
##
## ⚠️ CALLED BY WHATEVER TURNS THE PIVOT, NEVER FROM _process(). The prop
## owns this motion (a Tween on the spinner's yaw), so a rider who SAMPLED
## that yaw on his own clock would be reading it at whatever point in the
## frame his own callback happened to fall. Measured when this file did
## exactly that: a one-frame lag, 12.0 deg at the peak of the shove, and
## process_priority did NOT move it -- Tween steps land after every node's
## _process whatever the priority says. So the caller that writes the angle
## writes the rider too, in that order, and the two cannot be a frame apart
## because they are one call. Same rule _place_on_route() follows for the
## boat, arrived at from the opposite direction.
func follow_turnstile() -> void:
	if _turnstile == null or not is_instance_valid(_turnstile):
		# The prop went away underneath him. Put the body back on the ground
		# rather than leaving it parked in mid-air on a dead reference: this
		# is unreachable while HubWorld owns both, which is exactly why it is
		# written down instead of assumed.
		_turnstile = null
		_turnstile_seat = Vector3.ZERO
		_state = State.IDLE
		global_position = Vector3(global_position.x, 0.0, global_position.z)
		return
	global_position = _turnstile.to_global(_turnstile_seat)
	# Facing OUTWARD: the seat offset IS the outward direction, flattened.
	# Taken through the pivot's basis rather than added to its yaw so the
	# prop's own placement rotation (the layout's rotation_y) is carried too.
	var out: Vector3 = _turnstile.global_transform.basis * Vector3(_turnstile_seat.x, 0.0, _turnstile_seat.z)
	if out.length_squared() > 0.000001:
		_yaw.rotation_degrees.y = rad_to_deg(atan2(out.x, out.z))

## Steps off the turnstile onto `landing`, which the caller has already
## measured to be clear ground outside the prop.
##
## Reuses the generalised arc -- from the seat height down to zero -- rather
## than writing a third way down off something, exactly as the dive and the
## boat eject already do.
func leave_turnstile(landing: Vector3) -> void:
	if _state != State.ON_TURNSTILE:
		return
	var seat_y: float = global_position.y
	var here := Vector3(global_position.x, 0.0, global_position.z)
	var target := Vector3(landing.x, 0.0, landing.z)
	_turnstile = null
	_turnstile_seat = Vector3.ZERO
	_has_target = false

	var delta := target - here
	if delta.length() < 0.001:
		# Degenerate: the caller aimed at the seat. Set him down rather than
		# tweening a zero-length arc.
		_state = State.IDLE
		global_position = here
		turnstile_dismounted.emit()
		became_idle.emit()
		return
	_face(delta)
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_state = State.HOPPING
	_hop_from = here
	_hop_to = target
	_hop_from_y = seat_y
	_hop_to_y = 0.0
	_hop_height = TURNSTILE_DISMOUNT_HOP_HEIGHT
	_hop_tween = create_tween()
	_hop_tween.tween_method(_apply_hop, 0.0, 1.0, HOP_DURATION)
	_hop_tween.finished.connect(_on_turnstile_dismount_finished, CONNECT_ONE_SHOT)

## The dismount lands and the body is handed straight back to the ordinary
## chain, the way the dive's does. The signal fires AFTER the landing so a
## listener sees the ground he arrived on, not the deck he left.
func _on_turnstile_dismount_finished() -> void:
	_on_hop_finished()
	turnstile_dismounted.emit()

## Puts Keepy on a seesaw plank, at the end he arrived at.
##
## `pivot` is the node that tilts, `seat_y` the TOP of the plank and
## `ride_x` how far out along it a rider sits -- all three in the pivot's
## own local space, all three published by HubBuilder from the pass that
## drew them. Nothing here re-derives any of them, for the reason
## mount_turnstile states: the plank a rider stands on and the plank that
## was drawn have to be one fact.
##
## THE END IS THE ONE HE CAME FROM, which is the seesaw's version of the
## turnstile snapping its seat to the nearest gap. A rider teleported to the
## far end the instant he arrives is the jolt that rule exists to avoid, and
## on a two-ended prop "nearest" is simply the sign of his local x.
##
## Refused, quietly, unless he is standing still -- the same overlap every
## other entry point on this file refuses.
func mount_seesaw(pivot: Node3D, seat_y: float, ride_x: float) -> bool:
	if pivot == null or not is_instance_valid(pivot):
		return false
	if _state != State.IDLE:
		return false
	dismount_vehicle()
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()

	# Where he is standing, expressed in the pivot's frame, so the end is
	# chosen against the plank as it is turned RIGHT NOW rather than against
	# the layout's idea of which way it points.
	var local: Vector3 = pivot.to_local(global_position)
	var side: float = 1.0 if local.x >= 0.0 else -1.0

	_seesaw = pivot
	_seesaw_seat = Vector3(side * ride_x, seat_y, 0.0)
	_has_target = false
	_state = State.ON_SEESAW
	# Rest pose, as every state that takes the body over sets it: a squash
	# left over from the landing that mounted him would ride with him.
	_body.scale = _base_scale
	_body.rotation_degrees.x = _base_pitch
	follow_seesaw()
	seesaw_mounted.emit()
	return true

## Writes Keepy at the seat for the plank's CURRENT tilt. The ONE place a
## seesaw ride touches a transform.
##
## ⚠️ CALLED BY WHATEVER TILTS THE PIVOT, NEVER FROM _process(). This is not
## a precaution copied across from the turnstile -- it is that file's
## MEASUREMENT: a rider who sampled the pivot on his own per-frame callback
## was a full frame behind it, 12.0 deg at the peak of the shove, and
## process_priority did not move it because Tween steps land after every
## node's _process whatever the priority says. So the caller that writes the
## angle writes the rider too, in that order.
func follow_seesaw() -> void:
	if _seesaw == null or not is_instance_valid(_seesaw):
		# The prop went away underneath him. Put the body back on the ground
		# rather than leaving it parked in mid-air on a dead reference: this
		# is unreachable while HubWorld owns both, which is exactly why it is
		# written down instead of assumed.
		_seesaw = null
		_seesaw_seat = Vector3.ZERO
		_state = State.IDLE
		global_position = Vector3(global_position.x, 0.0, global_position.z)
		return
	global_position = _seesaw.to_global(_seesaw_seat)
	# Facing along the plank, INWARD toward the fulcrum. Outward is what the
	# turnstile does because a roundabout rider faces the way he is flung;
	# a seesaw rider faces the middle, which is also the pose that keeps him
	# side-on to a camera that never yaws instead of showing it his back.
	var inward: Vector3 = _seesaw.global_transform.basis * Vector3(-_seesaw_seat.x, 0.0, 0.0)
	inward.y = 0.0
	if inward.length_squared() > 0.000001:
		_yaw.rotation_degrees.y = rad_to_deg(atan2(inward.x, inward.z))

## Steps off the seesaw onto `landing`, which the caller has already
## measured to be clear ground outside the prop.
##
## Reuses the generalised arc -- from the seat height down to zero -- rather
## than writing a fourth way down off something, exactly as the dive, the
## boat eject and the turnstile dismount already do. The seat height is READ
## OFF THE BODY rather than recomputed, because the plank may be at any
## tilt when the rock ends and the height he actually leaves from is the one
## the arc has to start at.
func leave_seesaw(landing: Vector3) -> void:
	if _state != State.ON_SEESAW:
		return
	var seat_y: float = global_position.y
	var here := Vector3(global_position.x, 0.0, global_position.z)
	var target := Vector3(landing.x, 0.0, landing.z)
	_seesaw = null
	_seesaw_seat = Vector3.ZERO
	_has_target = false

	var delta := target - here
	if delta.length() < 0.001:
		# Degenerate: the caller aimed at the seat. Set him down rather than
		# tweening a zero-length arc.
		_state = State.IDLE
		global_position = here
		seesaw_dismounted.emit()
		became_idle.emit()
		return
	_face(delta)
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_state = State.HOPPING
	_hop_from = here
	_hop_to = target
	_hop_from_y = seat_y
	_hop_to_y = 0.0
	_hop_height = TURNSTILE_DISMOUNT_HOP_HEIGHT
	_hop_tween = create_tween()
	_hop_tween.tween_method(_apply_hop, 0.0, 1.0, HOP_DURATION)
	_hop_tween.finished.connect(_on_seesaw_dismount_finished, CONNECT_ONE_SHOT)

## The dismount lands and the body is handed straight back to the ordinary
## chain, the way the turnstile's and the dive's do.
func _on_seesaw_dismount_finished() -> void:
	_on_hop_finished()
	seesaw_dismounted.emit()

## Puts Keepy on the owl's back.
##
## `carrier` is the node a flight MOVES and `seat_y` where on it he sits,
## both published by HubBuilder from the pass that drew the prop. Nothing
## here re-derives either, for the reason mount_seesaw and mount_turnstile
## both state: the back the player sees and the back a rider is written
## onto have to be one fact.
##
## NO SIDE TO CHOOSE, unlike the seesaw's two ends and the turnstile's gaps
## between bars: an owl has one back, so the seat is simply it. The seat is
## Y-only, which is what makes it survive the yaw the loop turns him
## through -- an X or Z offset would swing out sideways as the bird banks.
##
## Refused, quietly, unless he is standing still -- the same overlap every
## other entry point on this file refuses.
func mount_owl(carrier: Node3D, seat_y: float) -> bool:
	if carrier == null or not is_instance_valid(carrier):
		return false
	if _state != State.IDLE:
		return false
	dismount_vehicle()
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()

	_owl = carrier
	_owl_seat = Vector3(0.0, seat_y, 0.0)
	_has_target = false
	_state = State.ON_OWL_FLIGHT
	# Rest pose, as every state that takes the body over sets it: a squash
	# left over from the landing that mounted him would ride with him.
	_body.scale = _base_scale
	_body.rotation_degrees.x = _base_pitch
	follow_owl()
	owl_flight_mounted.emit()
	return true

## Writes Keepy at the seat for the owl's CURRENT pose. The ONE place a
## flight touches his transform.
##
## ⚠️ CALLED BY WHATEVER MOVES THE OWL, NEVER FROM _process(). This is not
## a precaution copied across from the seesaw -- it is the TURNSTILE'S
## MEASUREMENT: a rider who sampled his carrier on his own per-frame
## callback was a full frame behind it, 12.0 deg at the peak of the shove,
## and process_priority did not move it because Tween steps land after
## every node's _process whatever the priority says. A flight covers metres
## rather than degrees, so the same one-frame lag would be a Keepy visibly
## trailing the bird he is sitting on. The caller that writes the owl
## writes the rider too, in that order.
func follow_owl() -> void:
	if _owl == null or not is_instance_valid(_owl):
		# The prop went away underneath him. Put the body back on the
		# ground rather than leaving it parked in mid-air on a dead
		# reference: unreachable while HubWorld owns both, which is exactly
		# why it is written down instead of assumed.
		_owl = null
		_owl_seat = Vector3.ZERO
		_state = State.IDLE
		global_position = Vector3(global_position.x, 0.0, global_position.z)
		return
	global_position = _owl.to_global(_owl_seat)
	# Facing where the owl faces: a passenger on a bird's back looks the
	# way the bird is flying, and the owl's own yaw is already the tangent
	# of the loop -- so this is one fact read, not a second one computed.
	_yaw.rotation_degrees.y = _owl.global_rotation_degrees.y

## Steps off the owl onto `landing`, which the caller has already measured
## to be clear ground outside the perch.
##
## Reuses the generalised arc -- from the seat height down to zero -- rather
## than writing a fifth way down off something, exactly as the dive, the
## boat eject, the turnstile dismount and the seesaw dismount already do.
## The seat height is READ OFF THE BODY rather than recomputed: the flight
## ends with the owl back on its perch, so the height he actually leaves
## from is the one the arc has to start at whatever the loop did.
func leave_owl(landing: Vector3) -> void:
	if _state != State.ON_OWL_FLIGHT:
		return
	var seat_y: float = global_position.y
	var here := Vector3(global_position.x, 0.0, global_position.z)
	var target := Vector3(landing.x, 0.0, landing.z)
	_owl = null
	_owl_seat = Vector3.ZERO
	_has_target = false

	var delta := target - here
	if delta.length() < 0.001:
		# Degenerate: the caller aimed at the seat. Set him down rather
		# than tweening a zero-length arc.
		_state = State.IDLE
		global_position = here
		owl_flight_dismounted.emit()
		became_idle.emit()
		return
	_face(delta)
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_state = State.HOPPING
	_hop_from = here
	_hop_to = target
	_hop_from_y = seat_y
	_hop_to_y = 0.0
	_hop_height = TURNSTILE_DISMOUNT_HOP_HEIGHT
	_hop_tween = create_tween()
	_hop_tween.tween_method(_apply_hop, 0.0, 1.0, HOP_DURATION)
	_hop_tween.finished.connect(_on_owl_dismount_finished, CONNECT_ONE_SHOT)

## The dismount lands and the body is handed straight back to the ordinary
## chain, the way the turnstile's, the seesaw's and the dive's do.
func _on_owl_dismount_finished() -> void:
	_on_hop_finished()
	owl_flight_dismounted.emit()

## Steps off the tower's deck onto the trolley handle, and takes hold of it.
##
## ⚠️ AN ARC AND NOT A SNAP, and the reason is the geometry rather than the
## polish. The deck stands at `ZIPLINE_DECK_HEIGHT` 0.90 and the handle
## hangs at `cable - clearance - his own height` = 0.5999, so boarding is a
## step off a platform and a 0.30 u drop onto a grip -- which is what a
## zipline is. A body teleported onto the handle would read as the deck
## having no purpose at all.
##
## The arc is the SAME generalised one the dive, the boat eject and the
## three dismounts use, run in the other direction: `_hop_from_y` is the
## ground he leaves and `_hop_to_y` the seat he arrives at. There is no
## fifth way up onto something in this file, exactly as there is no fifth
## way down off one.
##
## Refused from any state but IDLE, on `mount_owl`'s terms: HubWorld asks
## once, on a landing, and a body already carried by something else has no
## business being asked twice.
func board_zipline(carrier: Node3D, seat: Vector3) -> bool:
	if carrier == null or not is_instance_valid(carrier):
		return false
	if _state != State.IDLE:
		return false
	dismount_vehicle()

	var handle: Vector3 = carrier.to_global(seat)
	var here := Vector3(global_position.x, 0.0, global_position.z)
	var target := Vector3(handle.x, 0.0, handle.z)
	_zipline = carrier
	_zipline_seat = seat
	_has_target = false

	var delta := target - here
	if delta.length() >= 0.001:
		_face(delta)
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_state = State.HOPPING
	_hop_from = here
	_hop_to = target
	_hop_from_y = global_position.y
	_hop_to_y = handle.y
	_hop_height = ZIPLINE_BOARD_HOP_HEIGHT
	_hop_tween = create_tween()
	_hop_tween.tween_method(_apply_hop, 0.0, 1.0, HOP_DURATION)
	_hop_tween.finished.connect(_on_zipline_board_finished, CONNECT_ONE_SHOT)
	return true

## The step lands on the handle: the body is handed to the trolley and the
## ride is announced.
##
## ⚠️ NOT ROUTED THROUGH `_on_hop_finished()`, unlike every DISMOUNT in
## this file. That handler puts the state back to IDLE and advances the hop
## chain towards `_target` -- correct for an arc that ends on the ground,
## and exactly wrong for one that ends thirty centimetres up on a grip: it
## would walk him off the handle in the same frame he took it.
func _on_zipline_board_finished() -> void:
	if _zipline == null or not is_instance_valid(_zipline):
		# The trolley went away mid-step. Put him back on the ground rather
		# than leaving the body parked in the air on a dead reference --
		# unreachable while HubWorld owns both, which is why it is written
		# down instead of assumed.
		_zipline = null
		_zipline_seat = Vector3.ZERO
		_state = State.IDLE
		global_position = Vector3(global_position.x, 0.0, global_position.z)
		_body.scale = _base_scale
		_body.rotation_degrees.x = _base_pitch
		became_idle.emit()
		return
	_state = State.ON_ZIPLINE
	# Rest scale, as every state that takes the body over sets it: a squash
	# left over from the step that boarded him would ride across with him.
	_body.scale = _base_scale
	follow_zipline()
	zipline_mounted.emit()

## Writes Keepy at his place on the trolley for its CURRENT pose. The ONE
## place a trip touches his transform.
##
## ⚠️ CALLED BY WHATEVER MOVES THE TROLLEY, NEVER FROM _process(). Not a
## precaution copied across -- it is the turnstile's MEASUREMENT, restated
## by RECON 4: a rider who sampled his carrier on his own per-frame
## callback was a full frame behind it, 12.0 deg at the peak of the shove,
## and `process_priority` did not move it because Tween steps land after
## every node's _process whatever the priority says. This carrier crosses
## 25.9 u, so a one-frame lag would be a Keepy visibly trailing the handle
## he is holding.
func follow_zipline() -> void:
	if _zipline == null or not is_instance_valid(_zipline):
		# The trolley went away underneath him. Put the body back on the
		# ground rather than leaving it parked in mid-air on a dead
		# reference -- follow_owl's own guard, for its own reason.
		_zipline = null
		_zipline_seat = Vector3.ZERO
		_state = State.IDLE
		global_position = Vector3(global_position.x, 0.0, global_position.z)
		_body.rotation_degrees.x = _base_pitch
		return
	global_position = _zipline.to_global(_zipline_seat)
	# Facing the way the trolley travels -- its own local +Z, which the
	# builder set to the span direction. One fact read, not a second one
	# computed from the two ends.
	var forward: Vector3 = _zipline.global_transform.basis * Vector3.BACK
	forward.y = 0.0
	if forward.length_squared() > 0.000001:
		_yaw.rotation_degrees.y = rad_to_deg(atan2(forward.x, forward.z))
	# Leaning back off the handle. Written every step rather than once at
	# the mount so a tween that replaced the body's pitch mid-trip could
	# not leave him upright without anything saying so.
	_body.rotation_degrees.x = _base_pitch + ZIPLINE_HANG_PITCH_DEG

## Lets go of the handle onto `landing`, which the caller has already
## measured to be clear ground outside the far tower.
##
## Reuses the generalised arc -- from the handle height down to zero --
## rather than writing a sixth way down off something, exactly as the dive,
## the boat eject and the three other dismounts do. The height is READ OFF
## THE BODY rather than recomputed: the trip ends wherever the tween left
## the trolley, so the height he actually leaves from is the one the arc
## has to start at.
##
## ⚠️ THE DESTINATION SURVIVES THE DROP, which is `leave_ride`'s rule and
## the reason this is a `leave_*` and not a bare dismount: one tap buys the
## drop AND the walk on to where it pointed. HubWorld hands `hop_to` the
## tapped point straight after calling this, and the arc's own
## `_on_hop_finished` picks it up.
func leave_zipline(landing: Vector3) -> void:
	if _state != State.ON_ZIPLINE:
		return
	var seat_y: float = global_position.y
	var here := Vector3(global_position.x, 0.0, global_position.z)
	var target := Vector3(landing.x, 0.0, landing.z)
	_zipline = null
	_zipline_seat = Vector3.ZERO
	_has_target = false
	# The lean goes with the handle: a body that landed still tilted back
	# reads as a bug, which is the same rule PITCH_DEG states for the hop.
	_body.rotation_degrees.x = _base_pitch

	var delta := target - here
	if delta.length() < 0.001:
		# Degenerate: the caller aimed at the handle itself. Set him down
		# rather than tweening a zero-length arc.
		_state = State.IDLE
		global_position = here
		zipline_dismounted.emit()
		became_idle.emit()
		return
	_face(delta)
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_state = State.HOPPING
	_hop_from = here
	_hop_to = target
	_hop_from_y = seat_y
	_hop_to_y = 0.0
	_hop_height = TURNSTILE_DISMOUNT_HOP_HEIGHT
	_hop_tween = create_tween()
	_hop_tween.tween_method(_apply_hop, 0.0, 1.0, HOP_DURATION)
	_hop_tween.finished.connect(_on_zipline_dismount_finished, CONNECT_ONE_SHOT)

## The drop lands and the body is handed straight back to the ordinary
## chain, the way the turnstile's, the seesaw's and the owl's do.
func _on_zipline_dismount_finished() -> void:
	_on_hop_finished()
	zipline_dismounted.emit()

## Leaves the boat: one taller-than-usual leap to the bank on the side the
## player tapped, and then the ordinary hop chain on towards the tap.
##
## `toward` is the point the player asked for; `blocked` is the list of
## ground footprints a landing must clear, as HubBuilder.ground_footprints()
## returns them. A blocked bank point is walked ALONG the bank until one is
## free rather than being used anyway -- landing inside a rock is the sort
## of thing that only shows up on device.
func leave_ride(toward: Vector3, blocked: Array) -> void:
	if _state != State.RIDING or _route == null:
		return
	var landing: Vector3 = _bank_point(toward, blocked)
	_route = null
	_ride_half_width = 0.0
	_state = State.IDLE
	ride_ended.emit()

	# The destination survives the leap: _advance() picks it up from the
	# landing, so ONE tap buys the eject AND the walk to where it pointed.
	_target = Vector3(toward.x, 0.0, toward.z)
	_has_target = true

	var here := Vector3(global_position.x, 0.0, global_position.z)
	var delta := landing - here
	if delta.length() < 0.001:
		# Degenerate: already standing on the bank point. Skip the leap and
		# let the ordinary chain take over, rather than tweening a zero.
		_advance()
		return
	_face(delta)
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_state = State.HOPPING
	_hop_from = here
	_hop_to = landing
	_hop_height = EJECT_HOP_HEIGHT
	# Flat, and set here rather than relied on: this is the one tween built
	# outside _begin_hop, so it is the one place a sloped arc left over from
	# a dive could leak into. Unreachable today -- every path into a ride
	# passes a landing, and _on_hop_finished zeroes them -- which is exactly
	# why it is written down instead of depended on.
	_hop_from_y = 0.0
	_hop_to_y = 0.0
	_hop_tween = create_tween()
	_hop_tween.tween_method(_apply_hop, 0.0, 1.0, HOP_DURATION)
	_hop_tween.finished.connect(_on_hop_finished, CONNECT_ONE_SHOT)

## Starts the ladder climb. `board` is HubBuilder.diving_board() as it was
## published; refused, quietly, on an empty board or from any state other
## than standing still -- a hub that does nothing beats one that crashes on
## the screen every game is reached through.
##
## The climb is SCRIPTED and takes no input: it runs a fixed duration and
## ends planted on the anchor. That is not a shortcut around a walk up the
## ladder -- there is no elevated ground for a walk to resolve against (see
## the enum's block above), so the alternative to a scripted climb is no
## climb at all.
func climb_board(board: Dictionary) -> void:
	if board.is_empty() or _state != State.IDLE:
		return
	dismount_vehicle()
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_board = board
	_has_target = false
	_state = State.CLIMBING

	# Face along the plank before the first rung, for the reason _face
	# gives: a body that turns while it is off the ground reads as being
	# steered rather than as having committed.
	_face(board["forward"])
	_body.scale = _base_scale
	_body.rotation_degrees.x = _base_pitch

	_climb_tween = create_tween()
	_climb_tween.tween_method(_apply_climb, 0.0, 1.0, CLIMB_DURATION)
	_climb_tween.finished.connect(_on_climb_finished, CONNECT_ONE_SHOT)

## Writes the body up the ladder in quantized tractions and then mounts
## the deck with one short hop.
##
## Two segments on ONE normalised t, not two chained tweens: a single
## parameter is what guarantees the hand-off happens at exactly one frame
## and cannot leave a gap where the body is at neither height.
##
## WHY THE LAST RUNG IS NOT A TRACTION OF ITS OWN. board["rung_heights"]
## has RUNG_COUNT entries, RUNG_COUNT - 1 of them (rung_heights[0 ..
## RUNG_COUNT - 2]) are used as push/pause stops below; the top rung,
## rung_heights[RUNG_COUNT - 2] -- read that again, the LAST INDEX USED,
## not the top of the physical ladder -- is instead the FROM height of
## the final hop up onto the deck. A real climb does not carefully place
## a foot on the very top rung before stepping onto a platform above it,
## it hauls up and over; folding that beat into an arc is also what turns
## the old flat "walk out along the plank" into one mounted leap (see
## CLIMB_MOUNT_HOP_HEIGHT).
##
## This also means the rise now reuses _apply_hop for its own last beat,
## the same way the dive already does: one arc formula for every leap on
## this screen, not a second copy of it free to drift.
func _apply_climb(t: float) -> void:
	var ladder: Vector3 = _board["ladder"]
	var anchor: Vector3 = _board["anchor"]
	var deck_height: float = anchor.y
	var rung_heights: Array = _board["rung_heights"]
	var side: Vector3 = _board["side"]
	# RUNG_COUNT - 1 tractions below the mount hop -- at least one, even on
	# the two-rung minimum HubBuilder's own rung_count floor allows.
	var traction_count: int = maxi(rung_heights.size() - 1, 1)
	var last_rung: float = rung_heights[traction_count - 1]

	if t <= CLIMB_RISE_FRACTION:
		# UP the ladder in TRACTION_COUNT discrete pulls: the feet stay
		# over the foot of it and only the height changes (as before),
		# but that height now holds still between pulls instead of
		# rising at one constant rate the whole way.
		var rise_t: float = t / CLIMB_RISE_FRACTION
		var slot_f: float = rise_t * float(traction_count)
		var slot: int = mini(int(slot_f), traction_count - 1)
		var local_t: float = clampf(slot_f - float(slot), 0.0, 1.0)
		var from_y: float = 0.0 if slot == 0 else rung_heights[slot - 1]
		var to_y: float = rung_heights[slot]

		# The push: eased OUT (decelerating into the rung) over the first
		# climb_push_ratio share of the slot. Beyond that the pause holds
		# the reached height still -- push_t is clamped to 1.0, so eased
		# is 1.0 and y == to_y for the rest of the slot.
		var push_t: float = clampf(local_t / climb_push_ratio, 0.0, 1.0)
		var eased: float = 1.0 - (1.0 - push_t) * (1.0 - push_t)
		var y: float = lerpf(from_y, to_y, eased)

		# Sway alternates rung to rung and is zero at push_t = 0 AND
		# push_t = 1 -- out and back within the push, never carried into
		# the pause, so a held rung reads as gripped rather than swaying.
		var sway_dir: float = 1.0 if slot % 2 == 0 else -1.0
		var sway: float = sway_dir * climb_sway_amplitude * sin(PI * push_t)

		global_position = Vector3(ladder.x, y, ladder.z) + side * sway
		# Reused unchanged, driven by the traction's own local_t rather
		# than the hop's: compress off the last rung, extend into the
		# reach, relax and settle into the one this traction ends on --
		# the same spring shape a hop already uses, borrowed rather than
		# re-authored.
		_body.scale = _squash_at(local_t)
		return

	# THE MOUNT: one short hop from the last rung's height onto the deck,
	# ground and height moving together -- which is what makes this ONE
	# leap rather than a rise glued to a slide. _apply_hop also writes
	# the squash and the forward pitch for this beat, so both are free:
	# the mount looks like a hop because it IS one.
	var hop_t: float = (t - CLIMB_RISE_FRACTION) / (1.0 - CLIMB_RISE_FRACTION)
	_hop_from = ladder
	_hop_to = Vector3(anchor.x, 0.0, anchor.z)
	_hop_from_y = last_rung
	_hop_to_y = deck_height
	_hop_height = CLIMB_MOUNT_HOP_HEIGHT
	_apply_hop(hop_t)

func _on_climb_finished() -> void:
	_climb_tween = null
	# Snapped to the anchor rather than left wherever the tween's last
	# frame fell: the anchor is the one place the deck can be stood on, and
	# a dive is measured from it.
	var anchor: Vector3 = _board["anchor"]
	global_position = anchor
	_state = State.ON_BOARD
	board_mounted.emit()

## Dives off the board towards `toward` -- the ground point the player
## tapped, resolved on y = 0 like every other tap.
##
## Which of the board's two targets is used is decided by the SIDE of the
## anchor the tap fell on, along the board's facing: forward of it means
## the water, behind it means back down to the ladder foot. The tap's
## distance is deliberately ignored -- a board has two places to land, and
## letting a far tap aim further would put Keepy down in open water with no
## way back.
func dive(toward: Vector3) -> void:
	if _state != State.ON_BOARD or _board.is_empty():
		return
	var anchor: Vector3 = _board["anchor"]
	var forward: Vector3 = _board["forward"]
	var reach: float = (Vector3(toward.x, 0.0, toward.z) - Vector3(anchor.x, 0.0, anchor.z)).dot(forward)
	var landing: Vector3 = _board["water_target"] if reach >= 0.0 else _board["land_target"]

	var here := Vector3(anchor.x, 0.0, anchor.z)
	var flat_landing := Vector3(landing.x, 0.0, landing.z)
	_state = State.DIVING
	_board = {}
	_face(flat_landing - here)

	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_hop_from = here
	_hop_to = flat_landing
	# THE GENERALISED ARC, and the only caller that uses it for anything:
	# off the deck at one end, on the water surface at the other.
	_hop_from_y = anchor.y
	_hop_to_y = 0.0
	_hop_height = DIVE_HOP_HEIGHT
	_hop_tween = create_tween()
	_hop_tween.tween_method(_apply_hop, 0.0, 1.0, DIVE_DURATION)
	_hop_tween.finished.connect(_on_dive_finished, CONNECT_ONE_SHOT)
	board_dived.emit()

## The dive lands and the body is handed straight back to the ordinary
## chain -- _on_hop_finished does the snapping, the recoil and the landing
## signal, so a dive ends exactly the way every other leap on this screen
## ends. Nothing here is special-cased: the water is walkable ground.
func _on_dive_finished() -> void:
	_on_hop_finished()
	board_dismounted.emit()

func _process(delta: float) -> void:
	if _state != State.RIDING or _route == null:
		return
	_ride_s += _ride_dir * ride_speed * delta
	var end_reached: bool = _ride_s <= 0.0 or _ride_s >= _route.length()
	_ride_s = clampf(_ride_s, 0.0, _route.length())
	_place_on_route()
	if end_reached:
		# Arriving at the end of the stream disembarks on its own. The
		# player is aimed just past the end so the ordinary chain carries
		# them off the water instead of leaving them floating on the last
		# sample.
		var tangent: Vector3 = _route.tangent_at(_ride_s) * _ride_dir
		var ahead: Vector3 = _route.point_at(_ride_s) + tangent * (_ride_half_width + BANK_MARGIN)
		leave_ride(ahead, [])

## Writes Keepy and the hull at the current abscissa. The ONE place a ride
## touches a transform, so the boat can never drift from the rider.
func _place_on_route() -> void:
	var where: Vector3 = _route.point_at(_ride_s)
	var heading: Vector3 = _route.tangent_at(_ride_s) * _ride_dir
	global_position = Vector3(where.x, RIDE_SEAT_Y, where.z)
	var yaw: float = rad_to_deg(atan2(heading.x, heading.z))
	_yaw.rotation_degrees.y = yaw
	ride_moved.emit(Vector3(where.x, 0.0, where.z), yaw)

## Where to land when leaving the boat: off to the side the player tapped,
## clear of the ribbon, and clear of anything standing there.
##
## The search walks ALONG the stream from the current abscissa rather than
## pushing further sideways: sideways is where the props the trace was
## routed to clear already are, so more of it finds more of them, while a
## step along the bank reaches fresh ground.
func _bank_point(toward: Vector3, blocked: Array) -> Vector3:
	var offset: float = _ride_half_width + BANK_MARGIN
	var flat_toward := Vector3(toward.x, 0.0, toward.z)
	var here: Vector3 = _route.point_at(_ride_s)
	var tangent: Vector3 = _route.tangent_at(_ride_s)
	var side := Vector3(-tangent.z, 0.0, tangent.x)
	# Which side of the water the tap is on. On the centre line either
	# side is as good; +1 keeps it deterministic.
	var sign_side: float = 1.0 if (flat_toward - here).dot(side) >= 0.0 else -1.0

	var length: float = _route.length()
	var steps: int = 12
	for step in steps:
		# Alternate ahead / behind so the first free point is the nearest
		# one, not the first one downstream.
		var reach: float = float((step + 1) / 2) * (offset * 0.9)
		var direction: float = 1.0 if step % 2 == 0 else -1.0
		var s: float = clampf(_ride_s + reach * direction, 0.0, length)
		var base: Vector3 = _route.point_at(s)
		var t: Vector3 = _route.tangent_at(s)
		var candidate: Vector3 = base + Vector3(-t.z, 0.0, t.x) * (sign_side * offset)
		if _is_clear(candidate, blocked):
			return candidate
	# Nothing clear inside the search. Take the straight sideways point
	# anyway rather than refusing to disembark -- being stuck on the boat
	# is worse than standing a little close to a bush.
	return here + side * (sign_side * offset)

## True when nothing in `blocked` overlaps `point`. Footprints are ground
## radii, not silhouettes -- a tree crown overhanging the bank is scenery,
## a trunk in the landing spot is not (see HubBuilder.FOOTPRINT_RADIUS).
func _is_clear(point: Vector3, blocked: Array) -> bool:
	var flat := Vector3(point.x, 0.0, point.z)
	for entry in blocked:
		var where: Vector3 = entry.get("position", Vector3.ZERO)
		var radius: float = entry.get("radius", 0.0)
		if flat.distance_to(Vector3(where.x, 0.0, where.z)) < radius + BANK_MARGIN * 0.5:
			return false
	return true

func _advance() -> void:
	if not _has_target:
		return
	if _state != State.IDLE and _state != State.HOPPING:
		return
	var here := Vector3(global_position.x, 0.0, global_position.z)
	var delta := _target - here
	if delta.length() <= ARRIVE_EPSILON:
		_has_target = false
		_state = State.IDLE
		became_idle.emit()
		return
	_begin_hop(here, delta)

func _begin_hop(here: Vector3, delta: Vector3) -> void:
	# v3: on the vehicle the hop is longer, higher and a touch slower.
	# CH29: on a GLIDING vehicle it is flat, and its length and pace are
	# the vehicle's own.
	var gliding: bool = is_gliding()
	_hop_height = 0.0 if gliding else (VEHICLE_HOP_HEIGHT if _vehicle != null else HOP_HEIGHT)
	# Reset alongside the height, and for the same reason: a sloped arc
	# left over from a dive must not leak into the ordinary hop after it.
	_hop_from_y = 0.0
	_hop_to_y = 0.0
	var reach: float = _vehicle_glide_step if gliding else (VEHICLE_HOP_DISTANCE if _vehicle != null else HOP_DISTANCE)
	var step: float = minf(reach, delta.length())
	_hop_from = here
	_hop_to = here + delta.normalized() * step

	# Face the direction BEFORE leaving the ground: a body that rotates in
	# mid-air looks like it is being steered, which is exactly the reading
	# the commit-to-the-hop rule above exists to avoid.
	_face(delta)

	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_state = State.HOPPING
	# ONE tween driving a normalised 0..1, not three parallel property
	# tweens: the arc is a parabola and the squash is piecewise, neither of
	# which a property tween can express. Position, scale and pitch are all
	# written from the same t, so they cannot drift apart.
	_hop_tween = create_tween()
	var seconds: float = HOP_DURATION
	if gliding:
		# A short last segment keeps the glide's SPEED, not its duration:
		# 0.3 s for 0.2 u would read as a stall at the finish line.
		seconds = _vehicle_glide_s * (step / _vehicle_glide_step) / _vehicle_speed
	elif _vehicle != null:
		seconds = VEHICLE_HOP_DURATION
	_hop_tween.tween_method(_apply_hop, 0.0, 1.0, maxf(seconds, 0.02))
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
	# The line the arc is drawn ON. Flat for every hop on the plateau
	# (both ends default to 0.0); sloped only for the dive, which starts
	# on the board and ends in the water.
	var base: float = lerpf(_hop_from_y, _hop_to_y, t)
	# 4t(1-t) peaks at exactly 1.0 at t = 0.5 and is exactly 0 at both
	# ends, so the arc cannot leave Keepy hovering on a rounding error --
	# it lands exactly ON the base line, whatever that line is.
	var height: float = _hop_height * 4.0 * t * (1.0 - t)
	global_position = Vector3(ground.x, base + height + _vehicle_lift, ground.z)
	if is_gliding():
		# CH29: a glide has no arc, so no squash and no pitch either -- a
		# body that squashed on a flat roll would read as bouncing on the
		# spot. The vehicle keeps its own shape for the same reason.
		_body.scale = _base_scale
		_body.rotation_degrees.x = _base_pitch
		_place_vehicle(ground, base, Vector3.ONE)
		return
	_body.scale = _squash_at(t)
	_body.rotation_degrees.x = _base_pitch - PITCH_DEG * sin(PI * t)
	# The vehicle is written in the SAME call as its rider (carrier-then-
	# carried discipline, the turnstile's measurement): under his feet, on
	# the ground arc, squashing with him.
	_place_vehicle(ground, base + height, _squash_at(t))

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
	_state = State.IDLE
	_hop_height = HOP_HEIGHT
	# Snapped to the END of the base line, not to zero. Identical for
	# every plateau hop, where that line is flat at zero; for the dive it
	# is what puts the feet on the water surface instead of teleporting
	# them from wherever the tween's last frame happened to fall.
	# v3: plus the vehicle's lift while he rides it, the ball under him.
	global_position = Vector3(_hop_to.x, _hop_to_y + _vehicle_lift, _hop_to.z)
	_place_vehicle(Vector3(_hop_to.x, 0.0, _hop_to.z), _hop_to_y, Vector3.ONE)
	_hop_from_y = 0.0
	_hop_to_y = 0.0
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


## =====================================================================
## CARTE-BLANCHE V3 -- THE CARRIER (balloon) AND THE VEHICLE (hoppity ball)
##
## Two new ways of being moved, both written on patterns this file already
## proved rather than on new ones:
##
##   * ON_CARRIER is the OWL FLIGHT generalised: a Node3D moves, and the
##     thing that moves it writes the rider in the SAME call, immediately
##     after (`follow_carrier()`), never from a _process of his own -- the
##     turnstile's one-frame-lag measurement. A carrier trip is BOUNDED by
##     a tween that always ends at a known dock, which is the zipline's
##     licence for dropping taps meanwhile; the balloon's dock withdraws on
##     the boat's terms so those taps reach the ground path at all.
##   * The VEHICLE is NOT a state. It is a modifier on the ordinary hop
##     chain: while mounted, hops are longer, higher and a touch slower per
##     hop (net faster), the body is lifted by the ball's height, and the
##     ball is written under him in `_apply_hop`. Every other carried state
##     drops the vehicle first, so nothing else in this file ever sees it.

signal carrier_mounted
signal carrier_dismounted
signal vehicle_mounted
signal vehicle_dismounted

var _carrier: Node3D = null
var _carrier_seat: Vector3 = Vector3.ZERO

var _vehicle: Node3D = null
var _vehicle_lift: float = 0.0
## CH29: a GLIDING vehicle (the sand yacht). When `_vehicle_glide_step` is
## set, every hop is flat (no arc, no squash, no pitch), `_vehicle_glide_step`
## long and `_vehicle_glide_s / _vehicle_speed` short -- a chain of them is
## a continuous roll. The numbers are the vehicle's, handed in at mount;
## the speed factor is pushed in per frame by whoever reads the weather.
var _vehicle_glide_step: float = 0.0
var _vehicle_glide_s: float = 0.0
var _vehicle_speed: float = 1.0

## Hop geometry while on the vehicle: 2.7 u per hop in 0.34 s is 7.9 u/s
## against 5.4 u/s on foot (x1.48), with an arc almost twice as tall -- the
## bounce IS the ride.
const VEHICLE_HOP_DISTANCE: float = 2.7
const VEHICLE_HOP_HEIGHT: float = 1.15
const VEHICLE_HOP_DURATION: float = 0.34

func is_on_carrier() -> bool:
	return _state == State.ON_CARRIER

func is_on_vehicle() -> bool:
	return _vehicle != null

## CH29: true while the mounted vehicle glides rather than bounces.
func is_gliding() -> bool:
	return _vehicle != null and _vehicle_glide_step > 0.0

## CH29: the vehicle node he rides, or null.
func vehicle_node() -> Node3D:
	return _vehicle

## CH29: the wind's multiplier on a glide's pace (1.0 = the authored pace).
## Ignored by a bouncing vehicle. Takes effect on the NEXT hop: a hop in
## flight is one tween and is never retimed mid-air (the commit rule).
func set_vehicle_speed(factor: float) -> void:
	_vehicle_speed = clampf(factor, 0.25, 4.0)

## Puts Keepy on `carrier` at `seat` (carrier-local) and hands the body
## over. Refused from any state but IDLE, on mount_owl's terms.
func mount_carrier(carrier: Node3D, seat: Vector3) -> bool:
	if carrier == null or not is_instance_valid(carrier):
		return false
	if _state != State.IDLE:
		return false
	dismount_vehicle()
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_carrier = carrier
	_carrier_seat = seat
	_has_target = false
	_state = State.ON_CARRIER
	_body.scale = _base_scale
	_body.rotation_degrees.x = _base_pitch
	follow_carrier()
	carrier_mounted.emit()
	return true

## Writes Keepy at the seat for the carrier's CURRENT pose. Called by
## whatever moves the carrier, in the same call, never from _process().
func follow_carrier() -> void:
	if _carrier == null or not is_instance_valid(_carrier):
		_carrier = null
		_state = State.IDLE
		global_position = Vector3(global_position.x, 0.0, global_position.z)
		return
	global_position = _carrier.to_global(_carrier_seat)
	_yaw.rotation_degrees.y = _carrier.global_rotation_degrees.y

## Steps off the carrier onto `landing` -- the generalised arc from the
## seat height down to the ground, exactly as leave_owl does.
func leave_carrier(landing: Vector3) -> void:
	if _state != State.ON_CARRIER:
		return
	var seat_y: float = global_position.y
	var here := Vector3(global_position.x, 0.0, global_position.z)
	var target := Vector3(landing.x, 0.0, landing.z)
	_carrier = null
	_carrier_seat = Vector3.ZERO
	_has_target = false
	var delta := target - here
	if delta.length() < 0.001:
		_state = State.IDLE
		global_position = here
		carrier_dismounted.emit()
		became_idle.emit()
		return
	_face(delta)
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_state = State.HOPPING
	_hop_from = here
	_hop_to = target
	_hop_from_y = seat_y
	_hop_to_y = 0.0
	_hop_height = TURNSTILE_DISMOUNT_HOP_HEIGHT
	_hop_tween = create_tween()
	_hop_tween.tween_method(_apply_hop, 0.0, 1.0, HOP_DURATION)
	_hop_tween.finished.connect(_on_carrier_dismount_finished, CONNECT_ONE_SHOT)

func _on_carrier_dismount_finished() -> void:
	_on_hop_finished()
	carrier_dismounted.emit()

## Climbs onto `vehicle` (a Node3D drawn by someone else) and rides it from
## here on: every hop carries it. `lift` is how high its top is above the
## ground -- his feet stand there. Refused unless he is standing still.
func mount_vehicle(vehicle: Node3D, lift: float, glide_step: float = 0.0, glide_s: float = 0.0) -> bool:
	if vehicle == null or not is_instance_valid(vehicle):
		return false
	if _state != State.IDLE or _vehicle != null:
		return false
	_vehicle = vehicle
	_vehicle_lift = maxf(lift, 0.0)
	_vehicle_glide_step = maxf(glide_step, 0.0) if glide_s > 0.0 else 0.0
	_vehicle_glide_s = maxf(glide_s, 0.0)
	_vehicle_speed = 1.0
	var ground := Vector3(global_position.x, 0.0, global_position.z)
	global_position = ground + Vector3(0.0, _vehicle_lift, 0.0)
	_place_vehicle(ground, 0.0, Vector3.ONE)
	vehicle_mounted.emit()
	return true

## Leaves the vehicle where he stands. Safe to call when not mounted.
func dismount_vehicle() -> void:
	if _vehicle == null:
		return
	var ground := Vector3(global_position.x, 0.0, global_position.z)
	_place_vehicle(ground, 0.0, Vector3.ONE)
	_vehicle = null
	_vehicle_lift = 0.0
	_vehicle_glide_step = 0.0
	_vehicle_glide_s = 0.0
	_vehicle_speed = 1.0
	if _state == State.IDLE:
		global_position = ground
	vehicle_dismounted.emit()

func _place_vehicle(ground: Vector3, height: float, squash: Vector3) -> void:
	if _vehicle == null or not is_instance_valid(_vehicle):
		_vehicle = null
		_vehicle_lift = 0.0
		return
	_vehicle.global_position = Vector3(ground.x, height, ground.z)
	_vehicle.rotation_degrees.y = _yaw.rotation_degrees.y
	_vehicle.scale = squash


## =====================================================================
## CARTE-BLANCHE V4 -- THE TREE: A VERTICAL RIDE
##
## Climbing is NOT a second navigation model. The plateau stays single-
## altitude (HubRegion throws Y away, taps resolve on y = 0) and the tree
## CARRIES Keepy the way the owl, the trolley and the balloon do: from the
## moment he grips the bark to the moment his feet touch the foot point
## again, every transform he has is written in the TREE'S LOCAL SPACE and
## read back through `to_global()` -- so a tree that wobbles (the shake)
## moves him with it by construction, not by tuning. No `_process` of his
## own: the ascent, the descent and the two hops are BOUNDED tweens, and
## the seated pose is written by `follow_tree()`, which the tree calls
## right after it writes itself (carrier-then-carried, the turnstile's
## measurement).
##
## THE MOVEMENT IS A LADDER OF PULLS, never a lift. `_tree_pulls()` turns
## the tween's linear t into TREE_PULLS reaches: each one rises fast for
## 62% of its slot and HOLDS for the rest, so the body visibly grips,
## pulls, settles. Riding on that: an alternating lateral sway (left hand,
## right hand), a body roll in the same rhythm, a stretch on every pull
## (the reach) and a pitch that breathes -- the levers the brief names,
## with the model's single rigid mesh. The descent is HEAD FIRST, the way
## a squirrel actually comes down a trunk, at the same rhythm.
##
## EXIT IS AS RELIABLE AS ENTRY, whatever the player taps and whenever:
##   * during the approach walk HubWorld cancels the intent (boat pattern:
##     the tree withdraws from the tap only once he is ON it);
##   * during the ascent a tap is REMEMBERED (`_tree_exit_pending`) and
##     the descent starts the instant he is seated -- the ascent is
##     bounded, so this never waits more than one climb;
##   * seated, a tap anywhere starts the descent toward it;
##   * during the descent a tap re-aims the landing.
## The last hop puts him on the foot point ON THE GROUND and hands the body
## back to the ordinary chain with the tapped point as its target, exactly
## as `leave_ride` carries the eject's destination.

signal tree_mounted
signal tree_seated
signal tree_dismounted
## v5: he is about to spring THROUGH the crown (up onto the dome, or down
## off it) -- the tree rustles its leaves on it.
signal tree_leaves_entered

enum TreePhase { NONE, MOUNT, ASCEND, TOP_HOP, SEATED, DROP_HOP, DESCEND, DISMOUNT }

var _tree: Node3D = null
## The family's contract, in the tree's LOCAL space: "trunk_h", "r_base",
## "r_top", "seat" (Vector3), "face" (unit xz vector toward the climbed
## side), "foot_gap".
var _tree_spec: Dictionary = {}
var _tree_phase: int = TreePhase.NONE
var _tree_tween: Tween = null
var _tree_landing: Vector3 = Vector3.INF
var _tree_exit_pending: bool = false
var _tree_seated_t: float = 0.0
var _tree_shake_t: float = -1.0

## Ascent / descent durations, and the number of reaches in each.
const TREE_CLIMB_S: float = 1.6
const TREE_DESCEND_S: float = 1.3
const TREE_PULLS: int = 5
## Fraction of a pull spent rising; the rest is the grip.
const TREE_PULL_RISE: float = 0.62
## Height of the first grip above the ground, and how far under the wreath
## the last one stops.
const TREE_GRIP_Y0: float = 0.34
const TREE_GRIP_TOP_MARGIN: float = 0.18
## Distance of the body's node from the bark: the belly touches, the
## model's half-depth is ~0.22.
const TREE_GRIP_GAP: float = 0.28
## Body pitch about its own lateral axis. MEASURED on captures, not
## deduced from a comment: a POSITIVE x rotation turns the nose DOWN
## (toward the bark when he faces the trunk). A first pass at -62 laid
## him on his back with his head toward the camera; a second at +22 put
## his muzzle -- 0.45 u ahead of his axis -- THROUGH the trunk, which
## read as a body lying across it. A climbing squirrel looks UP the
## trunk: nose slightly raised, belly on the bark, head clear of it.
const TREE_HUG_PITCH_DEG: float = -12.0
## Head-first descent is a ROLL of a half turn, not a pitch: rolling
## about his own forward axis keeps the belly on the bark while the head
## goes down; pitching him over (the first pass) put his belly to the
## camera. The same lean into the bark rides on top.
const TREE_HEADFIRST_ROLL_DEG: float = 180.0
const TREE_PULL_PITCH_DEG: float = 10.0
const TREE_SWAY: float = 0.07
const TREE_ROLL_DEG: float = 10.0
const TREE_REACH_STRETCH: float = 0.08
const TREE_MOUNT_HOP_HEIGHT: float = 0.32
const TREE_MOUNT_HOP_S: float = 0.26
const TREE_TOP_HOP_HEIGHT: float = 0.45
const TREE_TOP_HOP_S: float = 0.34
## Seated: a slow look-around and a breath.
const TREE_LOOK_DEG: float = 26.0
const TREE_LOOK_PERIOD_S: float = 5.4
const TREE_BREATH_HZ: float = 0.9
## The bounce when the wreath is shaken from the seat.
const TREE_SHAKE_S: float = 0.9

func is_on_tree() -> bool:
	return _state == State.ON_TREE

func is_seated_on_tree() -> bool:
	return _state == State.ON_TREE and _tree_phase == TreePhase.SEATED

func tree_phase() -> int:
	return _tree_phase

## The tree he is on, for the caller that asks "the same one?".
func tree_node() -> Node3D:
	return _tree

## Radius of the surface he grips at height `y` (carrier units): the
## trunk's linear taper, and (v5, decor trees) the crown's ellipsoid
## above it -- the larger of the two where they meet, so the profile
## never jumps inward at the crown's bottom pole.
func _tree_r(y: float) -> float:
	var h: float = float(_tree_spec.get("trunk_h", 3.3))
	var trunk: float = lerpf(float(_tree_spec.get("r_base", 0.3)), float(_tree_spec.get("r_top", 0.21)), clampf(y / h, 0.0, 1.0))
	if y <= h or not _tree_spec.has("crown"):
		return trunk
	return maxf(trunk, _tree_crown_r(y))

func _tree_crown_r(y: float) -> float:
	var crown: Dictionary = _tree_spec["crown"]
	var u: float = clampf((y - float(crown["cy"])) / float(crown["b"]), -1.0, 1.0)
	return float(crown["a"]) * sqrt(maxf(1.0 - u * u, 0.0))

## v5: how far the crown's flank leans back from the vertical at height
## `y`, in degrees -- the body lies along it (nose over the dome) instead
## of standing off it. 0 on a trunk and at the crown's equator.
func _tree_surface_tilt_deg(y: float) -> float:
	if not _tree_spec.has("crown") or y <= float(_tree_spec.get("trunk_h", 3.3)):
		return 0.0
	var crown: Dictionary = _tree_spec["crown"]
	var a: float = crown["a"]
	var b: float = crown["b"]
	var r: float = maxf(_tree_crown_r(y), 0.05)
	var slope: float = a * a * (y - float(crown["cy"])) / (b * b * r)
	# Capped low on purpose: captured at 58 deg his head went INTO the
	# leaves and only the tail showed; at ~20 deg he leans over the dome
	# and stays readable. The feet sink a little into the leaves instead.
	return clampf(rad_to_deg(atan(absf(slope))) * 0.5, 0.0, TREE_SURFACE_TILT_MAX_DEG)

const TREE_SURFACE_TILT_MAX_DEG: float = 20.0

func _tree_face() -> Vector3:
	return _tree_spec.get("face", Vector3(0, 0, 1))

func _tree_right() -> Vector3:
	var f: Vector3 = _tree_face()
	return Vector3(f.z, 0.0, -f.x)

## Local point of the grip at height `y`, `side` in -1..1 for the sway.
func _tree_grip(y: float, side: float) -> Vector3:
	return _tree_face() * (_tree_r(y) + TREE_GRIP_GAP) + _tree_right() * (TREE_SWAY * side) + Vector3(0.0, y, 0.0) + _tree_lean(y)

## v5: the trunk's lean at height `y` -- the families bend as t^2 (measured
## by HubTrees.measure_kind, zero for the straight perchoirs), so a grip
## follows the bark instead of the axis.
func _tree_lean(y: float) -> Vector3:
	var lean: Vector3 = _tree_spec.get("lean", Vector3.ZERO)
	if lean == Vector3.ZERO:
		return Vector3.ZERO
	var t: float = clampf(y / float(_tree_spec.get("trunk_h", 3.3)), 0.0, 1.0)
	return lean * (t * t)

## v5: the rhythm, per tree -- the perchoir's constants unless the spec
## says otherwise (a short trunk is fewer pulls in less time).
func _tree_pull_count() -> int:
	return int(_tree_spec.get("pulls", TREE_PULLS))

func _tree_climb_s() -> float:
	return float(_tree_spec.get("climb_s", TREE_CLIMB_S))

func _tree_descend_s() -> float:
	return float(_tree_spec.get("descend_s", TREE_DESCEND_S))

func _tree_top_y() -> float:
	if _tree_spec.has("top_y"):
		return float(_tree_spec["top_y"])
	return float(_tree_spec.get("trunk_h", 3.3)) - TREE_GRIP_TOP_MARGIN

## Where he stands to start (and lands to finish), on the ground, in WORLD.
func tree_foot_point(tree: Node3D, spec: Dictionary) -> Vector3:
	var face: Vector3 = spec.get("face", Vector3(0, 0, 1))
	var local: Vector3 = face * (float(spec.get("r_base", 0.3)) * 1.35 + float(spec.get("foot_gap", 0.42)))
	var world: Vector3 = tree.to_global(local)
	return Vector3(world.x, 0.0, world.z)

## Face the trunk (into the face direction) or away from it (out toward
## the camera side), from wherever he is.
func _tree_face_yaw(inward: bool) -> void:
	var dir: Vector3 = _tree.global_transform.basis * _tree_face()
	_face(-dir if inward else dir)

## Grips `tree` and climbs it. Refused unless he is standing still (every
## entry point's rule) -- the caller walks him to the foot point first and
## asks on the landing, AND immediately (a zero-length walk emits none).
func climb_tree(tree: Node3D, spec: Dictionary) -> bool:
	if tree == null or not is_instance_valid(tree):
		return false
	if _state != State.IDLE:
		return false
	dismount_vehicle()
	if _hop_tween and _hop_tween.is_valid():
		_hop_tween.kill()
	_tree = tree
	_tree_spec = spec
	_tree_landing = Vector3.INF
	_tree_exit_pending = false
	_tree_shake_t = -1.0
	_has_target = false
	_state = State.ON_TREE
	_tree_phase = TreePhase.MOUNT
	_body.scale = _base_scale
	_body.rotation_degrees.x = _base_pitch
	_body.rotation_degrees.z = 0.0
	# Snap to the foot point: a walk ends NEAR its target, never on it
	# (0.401 u short, measured), and the mount arc must start from one
	# known place or the grip lands a hand off the bark.
	global_position = tree_foot_point(tree, spec)
	_tree_face_yaw(true)
	var grip: Vector3 = _tree.to_global(_tree_grip(TREE_GRIP_Y0, 0.0))
	_hop_from = Vector3(global_position.x, 0.0, global_position.z)
	_hop_to = Vector3(grip.x, 0.0, grip.z)
	_hop_from_y = 0.0
	_hop_to_y = grip.y
	_hop_height = TREE_MOUNT_HOP_HEIGHT
	_tree_tween = create_tween()
	_tree_tween.tween_method(_apply_hop, 0.0, 1.0, TREE_MOUNT_HOP_S)
	_tree_tween.finished.connect(_on_tree_mount_finished, CONNECT_ONE_SHOT)
	tree_mounted.emit()
	return true

func _on_tree_mount_finished() -> void:
	if _state != State.ON_TREE:
		return
	_tree_phase = TreePhase.ASCEND
	_hop_height = HOP_HEIGHT
	_hop_from_y = 0.0
	_hop_to_y = 0.0
	_tree_tween = create_tween()
	_tree_tween.tween_method(_apply_tree_ascend, 0.0, 1.0, _tree_climb_s())
	_tree_tween.finished.connect(_on_tree_ascend_finished, CONNECT_ONE_SHOT)

## Linear t -> a ladder of TREE_PULLS reaches. Returns [progress 0..1,
## reach intensity 0..1 (1 at the middle of a rise, 0 while gripping),
## side -1..1 (which hand is up)].
func _tree_pulls(t: float) -> Array:
	var n: float = float(_tree_pull_count())
	var k: float = floor(t * n)
	var frac: float = t * n - k
	var rise: float = smoothstep(0.0, TREE_PULL_RISE, frac)
	var progress: float = clampf((k + rise) / n, 0.0, 1.0)
	var reach: float = sin(clampf(frac / TREE_PULL_RISE, 0.0, 1.0) * PI)
	var side: float = 1.0 if int(k) % 2 == 0 else -1.0
	# The sway crosses over DURING the rise, so a hand is never seen to
	# teleport: blend toward the next side as the reach completes.
	var sway: float = lerpf(side, -side, smoothstep(0.35, 1.0, frac)) if frac > 0.35 else side
	return [progress, reach, sway]

func _apply_tree_ascend(t: float) -> void:
	if _tree == null or not is_instance_valid(_tree):
		_tree_lost()
		return
	var pull: Array = _tree_pulls(t)
	var y: float = lerpf(TREE_GRIP_Y0, _tree_top_y(), pull[0])
	global_position = _tree.to_global(_tree_grip(y, pull[2]))
	_tree_face_yaw(true)
	_body.rotation_degrees.x = _base_pitch + TREE_HUG_PITCH_DEG - TREE_PULL_PITCH_DEG * pull[1] + _tree_surface_tilt_deg(y)
	_body.rotation_degrees.z = TREE_ROLL_DEG * pull[2]
	var stretch: float = 1.0 + TREE_REACH_STRETCH * pull[1]
	_body.scale = _base_scale * Vector3(1.0 - 0.35 * (stretch - 1.0), stretch, 1.0 - 0.35 * (stretch - 1.0))

func _on_tree_ascend_finished() -> void:
	if _state != State.ON_TREE:
		return
	_tree_phase = TreePhase.TOP_HOP
	_body.rotation_degrees.z = 0.0
	_body.scale = _base_scale
	# Turn to the camera side before the hop, never in the air (the
	# commit rule): from the last grip he springs onto the pad facing out.
	_face(Vector3(0.0, 0.0, 1.0))
	var from: Vector3 = _tree.to_global(_tree_grip(_tree_top_y(), 0.0))
	var seat: Vector3 = _tree.to_global(_tree_spec.get("seat", Vector3(0, 3.42, 0)))
	_hop_from = Vector3(from.x, 0.0, from.z)
	_hop_to = Vector3(seat.x, 0.0, seat.z)
	_hop_from_y = from.y
	_hop_to_y = seat.y
	_hop_height = TREE_TOP_HOP_HEIGHT
	_tree_tween = create_tween()
	_tree_tween.tween_method(_apply_hop, 0.0, 1.0, _tree_top_hop_s(seat.y - from.y))
	_tree_tween.finished.connect(_on_tree_top_hop_finished, CONNECT_ONE_SHOT)
	if _tree_spec.get("through_leaves", false):
		tree_leaves_entered.emit()

## v5: the spring from the last grip to the seat. On a perchoir it rises
## 0.30 u onto the pad (TREE_TOP_HOP_S, unchanged); on a decor tree it
## goes THROUGH the crown onto the dome, up to ~2 u, and gets up to 1.8x
## the time so the pop-out reads as a pop-out and not a teleport.
func _tree_top_hop_s(rise: float) -> float:
	return TREE_TOP_HOP_S * clampf(rise / 0.9, 1.0, 1.8)

func _on_tree_top_hop_finished() -> void:
	if _state != State.ON_TREE:
		return
	_tree_phase = TreePhase.SEATED
	_tree_seated_t = 0.0
	_hop_height = HOP_HEIGHT
	_hop_from_y = 0.0
	_hop_to_y = 0.0
	_body.rotation_degrees.x = _base_pitch
	_body.scale = _base_scale
	follow_tree(0.0)
	tree_seated.emit()
	if _tree_exit_pending:
		_tree_exit_pending = false
		_begin_tree_descent()

## Writes the seated pose for the tree's CURRENT transform. Called by the
## tree every frame, right after it writes itself -- the only place a seat
## touches his transform while he is up there.
func follow_tree(delta: float, sway: Vector3 = Vector3.ZERO) -> void:
	if _state != State.ON_TREE or _tree_phase != TreePhase.SEATED:
		return
	if _tree == null or not is_instance_valid(_tree):
		_tree_lost()
		return
	_tree_seated_t += delta
	var seat: Vector3 = _tree_spec.get("seat", Vector3(0, 3.42, 0))
	global_position = _tree.to_global(seat + sway)
	# Seated he faces the CAMERA side (world +z), whatever flank he came
	# up: the seat is the one place the player gets to see his face.
	_yaw.rotation_degrees.y = TREE_LOOK_DEG * sin(_tree_seated_t * TAU / TREE_LOOK_PERIOD_S)
	var breath: float = 1.0 + 0.012 * sin(_tree_seated_t * TAU * TREE_BREATH_HZ)
	var squash: float = 1.0
	if _tree_shake_t >= 0.0:
		# The bounce: he compresses with the wreath's dip and springs
		# back, damped over the shake's length.
		var u: float = clampf(_tree_shake_t / TREE_SHAKE_S, 0.0, 1.0)
		squash = 1.0 - 0.16 * sin(u * TAU * 3.0) * (1.0 - u)
		_tree_shake_t += delta
		if _tree_shake_t > TREE_SHAKE_S:
			_tree_shake_t = -1.0
	_body.scale = _base_scale * Vector3(1.0 / sqrt(squash), breath * squash, 1.0 / sqrt(squash))
	_body.rotation_degrees.x = _base_pitch

## The seat's bounce, started by the tree when the wreath is shaken.
func bounce_on_tree() -> void:
	if is_seated_on_tree():
		_tree_shake_t = 0.0

## Asks to come down and go to `landing`. Safe in every phase: remembered
## during the ascent, started when seated, re-aimed during the descent.
func leave_tree(landing: Vector3) -> void:
	if _state != State.ON_TREE:
		return
	_tree_landing = Vector3(landing.x, 0.0, landing.z)
	match _tree_phase:
		TreePhase.MOUNT, TreePhase.ASCEND, TreePhase.TOP_HOP:
			_tree_exit_pending = true
		TreePhase.SEATED:
			_begin_tree_descent()
		_:
			pass

func _begin_tree_descent() -> void:
	_tree_phase = TreePhase.DROP_HOP
	_tree_shake_t = -1.0
	_body.scale = _base_scale
	_body.rotation_degrees.x = _base_pitch
	# Turn to the trunk on the pad, then spring down onto the top grip.
	_tree_face_yaw(true)
	var seat: Vector3 = _tree.to_global(_tree_spec.get("seat", Vector3(0, 3.42, 0)))
	var grip: Vector3 = _tree.to_global(_tree_grip(_tree_top_y(), 0.0))
	_hop_from = Vector3(seat.x, 0.0, seat.z)
	_hop_to = Vector3(grip.x, 0.0, grip.z)
	_hop_from_y = seat.y
	_hop_to_y = grip.y
	_hop_height = TREE_TOP_HOP_HEIGHT * 0.6
	if _tree_tween and _tree_tween.is_valid():
		_tree_tween.kill()
	_tree_tween = create_tween()
	_tree_tween.tween_method(_apply_hop, 0.0, 1.0, _tree_top_hop_s(seat.y - grip.y) * 0.8)
	_tree_tween.finished.connect(_on_tree_drop_hop_finished, CONNECT_ONE_SHOT)
	if _tree_spec.get("through_leaves", false):
		tree_leaves_entered.emit()

func _on_tree_drop_hop_finished() -> void:
	if _state != State.ON_TREE:
		return
	_tree_phase = TreePhase.DESCEND
	_hop_height = HOP_HEIGHT
	_hop_from_y = 0.0
	_hop_to_y = 0.0
	_tree_tween = create_tween()
	_tree_tween.tween_method(_apply_tree_descend, 0.0, 1.0, _tree_descend_s())
	_tree_tween.finished.connect(_on_tree_descend_finished, CONNECT_ONE_SHOT)

func _apply_tree_descend(t: float) -> void:
	if _tree == null or not is_instance_valid(_tree):
		_tree_lost()
		return
	var pull: Array = _tree_pulls(t)
	var y: float = lerpf(_tree_top_y(), TREE_GRIP_Y0, pull[0])
	global_position = _tree.to_global(_tree_grip(y, pull[2]))
	_tree_face_yaw(true)
	# Head first (rolled 180 deg), the same lean reads with the opposite
	# sign: captured with + the head was buried in the crown, tail up.
	_body.rotation_degrees.x = _base_pitch + TREE_HUG_PITCH_DEG + TREE_PULL_PITCH_DEG * pull[1] - _tree_surface_tilt_deg(y)
	_body.rotation_degrees.z = TREE_HEADFIRST_ROLL_DEG - TREE_ROLL_DEG * pull[2]
	var stretch: float = 1.0 + TREE_REACH_STRETCH * 0.8 * pull[1]
	_body.scale = _base_scale * Vector3(1.0 - 0.35 * (stretch - 1.0), stretch, 1.0 - 0.35 * (stretch - 1.0))

func _on_tree_descend_finished() -> void:
	if _state != State.ON_TREE:
		return
	_tree_phase = TreePhase.DISMOUNT
	_body.rotation_degrees.z = 0.0
	_body.scale = _base_scale
	var grip: Vector3 = _tree.to_global(_tree_grip(TREE_GRIP_Y0, 0.0))
	var foot: Vector3 = tree_foot_point(_tree, _tree_spec)
	# Land facing the way he is about to go, decided on the ground before
	# the hop, never in the air.
	var onward: Vector3 = _tree_landing if _tree_landing != Vector3.INF else foot
	var dir: Vector3 = onward - foot
	if dir.length() > 0.05:
		_face(dir)
	else:
		_tree_face_yaw(false)
	_hop_from = Vector3(grip.x, 0.0, grip.z)
	_hop_to = foot
	_hop_from_y = grip.y
	_hop_to_y = 0.0
	_hop_height = TREE_MOUNT_HOP_HEIGHT
	_tree_tween = create_tween()
	_tree_tween.tween_method(_apply_hop, 0.0, 1.0, TREE_MOUNT_HOP_S)
	_tree_tween.finished.connect(_on_tree_dismount_finished, CONNECT_ONE_SHOT)

## Feet on the ground: the body is handed back to the ordinary chain with
## the tapped point as its target, the way every other dismount does.
func _on_tree_dismount_finished() -> void:
	if _state != State.ON_TREE:
		return
	var landing: Vector3 = _tree_landing
	_tree = null
	_tree_spec = {}
	_tree_phase = TreePhase.NONE
	_tree_landing = Vector3.INF
	_tree_exit_pending = false
	_body.rotation_degrees.z = 0.0
	if landing != Vector3.INF:
		_target = landing
		_has_target = true
	_on_hop_finished()
	tree_dismounted.emit()

## The tree went away under him (unreachable while HubWorld owns both;
## written down rather than assumed, as every carrier does).
func _tree_lost() -> void:
	if _tree_tween and _tree_tween.is_valid():
		_tree_tween.kill()
	_tree = null
	_tree_spec = {}
	_tree_phase = TreePhase.NONE
	_state = State.IDLE
	_body.rotation_degrees.x = _base_pitch
	_body.rotation_degrees.z = 0.0
	_body.scale = _base_scale
	global_position = Vector3(global_position.x, 0.0, global_position.z)
	tree_dismounted.emit()
	became_idle.emit()
