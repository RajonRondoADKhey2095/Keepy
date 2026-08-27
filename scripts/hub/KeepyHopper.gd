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
## Nothing here is validated by a sonde; only Mathieu's eye picks a row.
@export var climb_push_ratio: float = 0.55

## Lateral sway on each push, in world units, perpendicular to the ladder
## (board["side"]) and alternating rung to rung. Zero again by the time
## the pause begins: sin(PI * push_t) returns to 0 at push_t = 1, so the
## feet are back directly over the ladder foot for every held rung, and a
## rung that is HELD still reads as gripped rather than swaying under him.
## Same exposure reasoning as climb_push_ratio above.
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
enum State { IDLE, HOPPING, RIDING, CLIMBING, ON_BOARD, DIVING }

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
	_hop_height = HOP_HEIGHT
	# Reset alongside the height, and for the same reason: a sloped arc
	# left over from a dive must not leak into the ordinary hop after it.
	_hop_from_y = 0.0
	_hop_to_y = 0.0
	var step: float = minf(HOP_DISTANCE, delta.length())
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
	# The line the arc is drawn ON. Flat for every hop on the plateau
	# (both ends default to 0.0); sloped only for the dive, which starts
	# on the board and ends in the water.
	var base: float = lerpf(_hop_from_y, _hop_to_y, t)
	# 4t(1-t) peaks at exactly 1.0 at t = 0.5 and is exactly 0 at both
	# ends, so the arc cannot leave Keepy hovering on a rounding error --
	# it lands exactly ON the base line, whatever that line is.
	var height: float = _hop_height * 4.0 * t * (1.0 - t)
	global_position = Vector3(ground.x, base + height, ground.z)
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
	_state = State.IDLE
	_hop_height = HOP_HEIGHT
	# Snapped to the END of the base line, not to zero. Identical for
	# every plateau hop, where that line is flat at zero; for the dive it
	# is what puts the feet on the water surface instead of teleporting
	# them from wherever the tween's last frame happened to fall.
	global_position = Vector3(_hop_to.x, _hop_to_y, _hop_to.z)
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
