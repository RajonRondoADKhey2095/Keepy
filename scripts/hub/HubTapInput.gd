extends Node
class_name HubTapInput
## Turns a tap on the screen into a point on the plateau.
##
## =====================================================================
## TAP, NOT SWIPE -- AND DELIBERATELY NOT SwipeDetector.gd
##
## scripts/input/SwipeDetector.gd exists and is NOT reused here. It answers
## "which direction did the finger travel", which is Chased's lane-change
## question; this screen's question is "which point did the finger land
## on". Reusing it would mean deriving a destination from a gesture that
## carries no destination, and would put two unrelated semantics on one
## file the moment either needed tuning.
##
## Only the RELEASE half of a touch is acted on. Acting on the press would
## fire while a finger is still down and still moving -- a player who
## touches the screen and drags to look would be sent to wherever their
## finger first met the glass.
##
## =====================================================================
## WHY THE MOUSE PATH EXISTS
##
## project.godot sets no `emulate_touch_from_mouse`, so on a desktop
## browser a click produces InputEventMouseButton and NOTHING else -- a
## touch-only handler leaves the plateau unusable outside a phone, which
## is where a lot of the looking-at happens.
##
## A finger, on the other hand, DOES produce both: emulate_mouse_from_touch
## defaults to true, so one tap arrives as a touch release AND as a
## synthesised mouse release, and _handle_point runs twice. Measured, not
## assumed -- a real touch injected into a real window emitted
## tapped_ground twice. It is harmless because hop_to() is depth-one: the
## second call re-states the same destination.
##
## =====================================================================
## WHY THIS ONLY EVER FIRES IF NO CONTROL EATS THE EVENT FIRST
##
## _unhandled_input runs AFTER GUI picking. Any Control under the finger
## whose mouse_filter is STOP consumes the event and calls
## set_input_as_handled(), and nothing downstream of that ever sees it --
## no error, no warning, just a plateau that ignores taps.
##
## HubWorld.tscn's root Control is full-screen, so at Control's DEFAULT
## MOUSE_FILTER_STOP it swallowed every tap on the plateau. It carries
## mouse_filter = MOUSE_FILTER_IGNORE for exactly that reason; the
## fallback Button and menu are separate Controls and are still picked
## normally, so the change costs nothing they need. Do not "tidy" that
## property away, and give any Control added over the plateau the same
## treatment.

## Emitted with the world point under the finger, on the ground plane.
signal tapped_ground(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the moored boat to mean "board it", with that same ground point.
##
## Exactly one of the two fires per tap. Emitting both and letting the
## listener pick would make every tap ambiguous downstream; deciding here
## is what makes the boat a priority rather than a competing reading of the
## same event.
signal tapped_boat(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the BADGER waiting at one end of the zipline to mean "ride across with
## it", on the same world-units terms the boat is picked out on. Same
## one-tap-one-signal rule.
##
## THE BOAT'S WITHDRAWAL, THROUGH A NODE RATHER THAN A FLAG. `ZiplineDoor`
## answers false for the whole of a trip AT BOTH ENDS and in either
## direction, so a tap made meanwhile falls through to tapped_ground.
## `owl_available` is a bare bool because a perch is one place; a zipline
## has two boarding points and one shared trip, which is a state a single
## bool cannot express and two bools would be free to disagree about --
## see ZiplineDoor.gd.
##
## ⚠️ RENAMED 4 SEPTEMBRE 2026 (tier 3), FROM `tapped_zipline`. RECON 1
## (docs/lots/CH21_TYROLIENNE.md) settled that a stair with a hotspot that
## emits whatever the body is doing is the banned LADDER PATTERN; it did
## NOT settle that the stair must forever carry nothing, and Mathieu has
## since asked for exactly that -- see `tapped_zipline_solo` below and the
## doctrine note in ZiplineDoor.gd. This channel keeps the ORIGINAL
## behaviour, name changed only to sit beside its sibling without either
## one reading as the general case.
signal tapped_zipline_badger(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the STRUCTURE of a zipline tower -- deck, mast or stair, at EITHER end --
## to mean "ride across alone", on the same world-units terms the badger
## channel is picked out on. Same one-tap-one-signal rule.
##
## ⚠️ THE DOCTRINE CHANGE, NAMED. `ZiplineDoor.accepts_structure_tap`
## withdraws on the boat's own terms (false for the whole of a trip, at
## both ends) and EXCLUDES the badger's own disc where a badger is
## currently waiting, so a tap can never mean both channels at once -- see
## that file's header for why the two discs cannot be made geometrically
## disjoint and are kept unambiguous in code instead.
signal tapped_zipline_solo(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## an OWL PERCH to mean "fly with it", on the same world-units terms the
## boat is picked out on. Same one-tap-one-signal rule.
##
## MODELLED ON THE BOAT AND DELIBERATELY NOT ON THE LADDER. The boat asks
## its mooring, which answers false for the whole of a ride, so a tap
## during one falls through to tapped_ground and BECOMES the eject. The
## ladder has no such withdrawal: it emits tapped_ladder whatever Keepy is
## doing, and HubWorld then drops it -- which is fine for a board, whose
## only other meaning would be a dive it already handles by state, and
## would be wrong here, because a tap during a flight has to be able to
## reach the ground path. `owl_available` is that withdrawal, and it is a
## plain flag rather than a second node only because there is no owl-side
## object to ask: HubWorld already knows whether a flight is running.
signal tapped_owl(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## a CABIN DOOR to mean "go inside", on the same world-units terms the boat
## and the owl are picked out on. Same one-tap-one-signal rule.
##
## ⚠️ NO WITHDRAWAL, UNLIKE THE BOAT AND THE OWL -- and that is a deletion
## rather than an omission. It used to carry a `cabin_available` flag on
## the mooring's pattern, because Keepy USED to hide inside the prop and a
## tap made meanwhile had to fall through to the ground path to become the
## way back out. Since 29 aout 2026 going in is a SCENE CHANGE: this whole
## screen stops existing for the length of the visit, so there is no
## "meanwhile" in which a tap could need to mean something else, and a flag
## that can never be false is a flag no one is reading.
signal tapped_cabin(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the diving board's LADDER FOOT to mean "climb that", on the same
## world-units terms the boat is picked out on. Same one-tap-one-signal
## rule: a tap is a climb or a destination, never both.
signal tapped_ladder(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the CAMPFIRE to mean "send the badger there" (or, on the next tap, "bring
## it back"), on the same world-units terms the boat, owl and cabin are
## picked out on. Same one-tap-one-signal rule.
##
## NO WITHDRAWAL ON THIS SIGNAL, unlike the badger's own zipline channel --
## and that omission is deliberate, on the cabin's pattern rather than the
## boat's: a tap on the campfire always MEANS the campfire, whichever leg
## the badger is on, because HubWorld decides here (send / recall / ignore
## mid-transit) rather than this file refusing to say the tap landed there
## at all. What withdraws instead is `tapped_zipline_badger`, through
## `ZiplineDoor` -- see HubWorld.gd's campfire wiring -- because THAT channel
## has a second meaning (walk to the badger's tower) that a tap must not
## accidentally trigger while the badger is away from both ends.
signal tapped_campfire(point: Vector3)

## Carte-blanche v3. Emitted INSTEAD of tapped_ground when the finger
## landed on a balloon DOCK (either dock of a line, balloon present or
## not), on the boat's world-unit terms. `HubTransport.accepts_balloon_tap`
## is false for the whole of a trip at BOTH docks -- the boat's withdrawal
## through a node -- so a tap then falls through to tapped_ground.
signal tapped_balloon(point: Vector3)

## Carte-blanche v3. Emitted INSTEAD of tapped_ground when the finger
## landed on the parked hoppity ball. Withdrawn while it is ridden, so a
## tap then is an ordinary hop -- the vehicle is a hop modifier, and the
## channel only exists to climb on.
signal tapped_vehicle(point: Vector3)

## Carte-blanche v4. Emitted INSTEAD of tapped_ground when the finger
## landed on a climbable tree -- v6: strictly the camera ray through the
## APEX (HubTrees.tree_hit, CLIMB_APEX_R sphere on `top` only; neither
## the ground disc nor the trunk nor the rest of the crown answer any
## more). `index` is the tree. The tree he is ON withdraws for the whole
## of the ride (tree_hit answers -1 for it), so a tap on it meanwhile
## falls through to tapped_ground -- with the tree's own foot as the
## point when the ray hit its apex -- where HubWorld reads it BY STATE:
## shake, or come down.
signal tapped_tree(point: Vector3, index: int)
## V6: a tap on one of the new inhabitants (`kind` names which: &"boar"
## ...). Withdrawn by each animal's own module for the length of its ride
## (the boat's terms), so a tap meanwhile falls through to tapped_ground
## and reaches the state branch that owns it.
signal tapped_critter(point: Vector3, kind: StringName, index: int)
## v7: the parked kart. Withdrawn through HubKarting for the drive.
signal tapped_kart(point: Vector3)
## CH29: a sandcastle spot in the cove (`index` names which). Withdrawn by
## HubCove while that spot's castle is rising (the boat's terms), so a tap
## meanwhile falls through to tapped_ground and cancels the intent.
signal tapped_castle(point: Vector3, index: int)
## CH71: the finger landed on the coaster's station or on the drop tower
## (`aim` in its disc), on the boat's world-unit terms. `ride` is
## HubFunfair.RIDE_COASTER or RIDE_TOWER. A ride that is running
## withdraws through its node (HubFunfair.accepts_tap answers -1) for
## the length of the trip, so a tap made meanwhile falls through to
## tapped_ground and is refused there by ON_CARRIER -- the licence
## CLAUDE.md grants a BOUNDED ride, and both of these are.
signal tapped_funfair(point: Vector3, ride: int)

## CH72: emitted INSTEAD of tapped_ground when a funfair ride is RUNNING
## and the tap means the RIDER rather than a place -- "switch the point
## of view". Same one-tap-one-signal rule as every channel above.
##
## ⚠️ ASKED ON THE RAY, NOT ON `aim`, AND IT IS THE ONE CHANNEL THAT IS.
## Every other prop here is a disc on the ground because every other prop
## IS on the ground. A rider 14 u up is DRAWN where the ground under him
## is not, and his silhouette smears 8.5 u of ground at the top of the
## tower (measured) -- there is no disc that means him. See
## `HubFunfair.accepts_rider_tap` for the whole of it.
##
## It does not need a withdrawal, because it IS one: it answers false
## unless a ride is running, which is exactly when every other funfair
## door has withdrawn.
signal tapped_funfair_rider()

## =====================================================================
## CH73 -- A FINGER THAT TRAVELS IS A LOOK-AROUND, NOT A DESTINATION
##
## ⚠️ THERE WAS NO TAP/DRAG THRESHOLD IN THIS FILE AT ALL, AND THE HEADER
## ABOVE SAYS SO FROM THE OTHER SIDE. "Only the RELEASE half is acted on
## [...] a player who touches the screen and drags to look would be sent
## to wherever their finger first met the glass" -- true of the PRESS,
## and what shipped instead sent him to wherever his finger LIFTED.
## Every release called `_handle_point`, unconditionally, however far the
## finger had travelled. Nothing was wrong with that while there was
## nothing to drag FOR; CH73 gives the drag a meaning, so the two
## gestures have to be told apart.
##
## ⚠️ THE THRESHOLD IS READ FROM SkateTouchInput, NOT RETYPED HERE.
## `SLOP_PX` is already this repo's published answer to "how far must a
## finger travel before it is a drag", and its own comment justifies it
## in terms of A THUMB AND MATHIEU'S PHONE -- "16 px is a little over a
## millimetre, large enough that a thumb pressing and lifting registers
## as a tap" -- not in terms of a skateboard. That makes it the same
## fact, and CLAUDE.md's "un fait est publie une fois, jamais recopie"
## says a second spelling of it is a defect waiting for the first tuning
## pass. If the board's feel ever wants its own number, the split is a
## deliberate commit, not an accident of two literals.
##
## ⚠️ ITS SIBLING `TAP_MAX_S` IS **NOT** TAKEN, and the reason is on
## `_gesture_was_tap` below. Short version: on the board a held finger
## is the throttle and the time limit tells two real gestures apart; in
## the hub a held finger means nothing else, so the limit would only
## invent a press that does nothing and says nothing.
##
## =====================================================================
## THE DOUBLE DISPATCH IS PRE-EXISTING DEBT, AND THE ORBIT IS BUILT SO
## IT CANNOT TOUCH IT
##
## This file does NOT drop `DEVICE_ID_EMULATION`, unlike KartTouchInput
## and SkateTouchInput, and that is deliberate and load-bearing: the
## project sets no `emulate_touch_from_mouse`, so on a desktop browser a
## click produces a mouse event and NOTHING else. Dropping the emulated
## class here would leave the plateau unusable outside a phone.
##
## The price is the debt CLAUDE.md and SkateInputProbe both record: one
## real finger arrives TWICE, as `InputEventMouseButton device=-1` FIRST
## and then as `InputEventScreenTouch device=0`. Harmless for a tap --
## `hop_to()` is depth-one, so the second call re-states the same
## destination. NOT harmless for a drag, in two independent ways, and
## both were found by reading the shipped writers rather than by running
## into them:
##
##   1. A MOTION APPLIED ON BOTH CLASSES TURNS THE CAMERA TWICE AS FAR
##      on a phone as on a desktop, with nothing to report it.
##   2. A LATCH CLEARED ON RELEASE IS CLEAR AGAIN BY THE SECOND ONE, so
##      the twin release would read the drag as a tap and walk Keepy to
##      wherever the finger lifted -- precisely the defect the threshold
##      exists to close, re-entering through the back door.
##
## CH73 is scoped to the camera and does not touch the debt. It is
## neutralised by SHAPE instead, and neither half costs anything:
##
##   * ONE GESTURE IS CLAIMED BY ONE EVENT CLASS. The first press claims
##     it; a press of the other class while a gesture is live is the
##     emulated twin and is ignored whole. Whichever class arrives
##     first, the motion is integrated ONCE. (Robust to either order on
##     purpose: the measured order is mouse-first, and a measurement is
##     not a guarantee about a future engine build.)
##   * `_dragged` IS CLEARED ON THE CLAIMING PRESS, NEVER ON A RELEASE.
##     So both releases of one gesture read the same latch and agree,
##     and the next gesture's press is what starts it over. A tap still
##     reaches `_handle_point` twice, exactly as it shipped -- this lot
##     does not change what a tap does.
##
## Both are gated, not asserted: OrbitCameraProbe PHASE D delivers a
## full double-dispatch drag through `Input.parse_input_event` and
## demands the single-channel yaw and zero `tapped_ground`.
##
## =====================================================================
## WHY THE ORBIT IS ARMED HERE AND NOT IN HubCamera
##
## "Is this finger a look-around" is a question about the GESTURE and
## about who else wants that finger, and every part of the answer is
## already in this file: the four driven-vehicle shunts at the top of
## `_unhandled_input`, the container rect, the camera. HubCamera owns the
## POSE and clamps the angle it is handed; it does not get a second
## opinion on when it may be turned.
##
## ⚠️ THE ARMING IS A LICENCE, NOT A STATE, and CLAUDE.md's CH58 entry is
## why the distinction is written out. What licenses an orbit is "the
## camera is in its own resting pose and the player is on his feet" --
## `_orbit_licensed()` spells that out as a predicate rather than
## leaving five callers to each remember a different subset of it.
##
## ⚠️ AND IT IS NOT THE PATRON ECHELLE. A drag NEVER swallows a tap that
## would otherwise have meant something: a gesture is a drag only once
## the finger has PASSED the slop, which is a thing a tap does not do.
## Below the slop every release goes down the shipped path untouched,
## whatever the camera is doing. There is no state in which the player
## has no way to say anything.

## The three nodes this needs, as scene-authored paths.
##
## NodePath and not a typed node export (`@export var camera: Camera3D`),
## MEASURED and not preferred: a typed node export written by hand into a
## .tscn does NOT resolve at load -- the probe for this batch got null for
## all three and every tap died on the guard below. The editor populates
## that form through machinery a hand-written scene file does not carry.
## An exported NodePath resolves either way, and is still a path the scene
## author owns rather than a `get_node("../../X")` walk baked into code.
@export var camera_path: NodePath
@export var container_path: NodePath
@export var viewport_path: NodePath

## The mooring, asked -- before any destination is resolved -- whether the
## tap was on the boat. Optional: a plateau whose layout carries no boat
## resolves this to null and every tap is a ground tap, exactly as before.
@export var mooring_path: NodePath

## The zipline's door, asked -- before any destination is resolved --
## whether the tap was on the badger waiting to ride. Optional, exactly as
## the mooring is: a plateau whose layout carries no zipline resolves this
## to null and every tap is a ground tap.
##
## A scene path and not a code-set property, unlike the owl perches and the
## ladder feet, because this one carries STATE rather than a table: the
## withdrawal that keeps a trip from swallowing taps lives in it, and a
## node the scene owns is a node a probe can reach without going through
## HubWorld's 2000 lines.
@export var zipline_path: NodePath

## Carte-blanche v3: the transport network (docks, balloons, the ball),
## asked on the same terms as the mooring and the zipline door. Optional.
@export var transport_path: NodePath
## Carte-blanche v4: the climbable trees. Optional; withdraws the one he
## is on through its node (HubTrees.accepts_tap), never through a flag.
@export var trees_path: NodePath
@export var critters_path: NodePath
## Carte-blanche v7: the karting coordinator. Optional. Withdraws the kart
## for the length of a drive, and while it drives NO point is handled
## here at all -- the touch belongs to KartTouchInput.
@export var karting_path: NodePath
## CH29: the cove module (the castle spots). Optional.
@export var cove_path: NodePath
## CH71: the funfair (coaster station and drop tower), same shape.
@export var funfair_path: NodePath
## CH73: Keepy, asked whether he is on his feet -- the state half of the
## orbit's licence. Optional like every path above: a layout that hands
## over no hopper never licenses an orbit, and every tap behaves exactly
## as it always has.
@export var hopper_path: NodePath

var camera: Camera3D = null
var container: SubViewportContainer = null
var viewport: SubViewport = null
var mooring: BoatMooring = null
var zipline: ZiplineDoor = null
var transport: HubTransport = null
var trees: HubTrees = null
var critters: HubCritters = null
var karting: HubKarting = null
var cove: HubCove = null
var funfair: HubFunfair = null

## THE WALKABLE LIMIT LIVES IN HubRegion, NOT HERE.
##
## This file used to own `const PLATEAU_HALF_EXTENT` and clamp each axis
## against it. That worked while the walkable hub was a square; the lake
## zone made it a union-minus-a-disc, and a per-axis clampf cannot express
## a hole. The constant moved to HubRegion.gd together with the rest of the
## shape, so there is still exactly one owner -- see that file for the
## measured crossing costs and for why the square stopped growing at 35.
##
## What changed for a player: a tap outside is still pulled to the nearest
## reachable point rather than dropped, and a tap ON the great lake is now
## pulled to its shore instead of walking Keepy into the water.

## Every diving board's ladder foot, flat, and how close a tap has to land
## to mean one. Empty until HubWorld hands over the built boards, so a
## layout with no board simply never emits tapped_ladder.
##
## Set from the BUILT boards rather than read from the layout here: the
## plank the player aims at and the foot this radius is measured from have
## to be the same fact.
##
## A LIST, not one point: the plateau carries three ladders now, and a
## single foot could only ever have answered for the first of them --
## tapping either of the others would have fallen through to tapped_ground
## and walked Keepy up to a plank he then could not climb. The radius stays
## a single number because it is a property of the GESTURE, not of any one
## board; the feet are metres apart, so no tap can be inside two.
var ladder_feet: Array[Vector3] = []
var ladder_radius: float = 0.0

## Every owl perch, flat, and how close a tap has to land to mean one.
## Empty until HubWorld hands over the built owls, so a layout with no owl
## simply never emits tapped_owl.
##
## Set from the BUILT owls for the reason the feet are: the prop the player
## aims at and the point this radius is measured from have to be one fact.
##
## `owl_available` is the boat's withdrawal, written above: HubWorld clears
## it for the length of a flight so a tap then falls through to the ground
## path instead of being swallowed here.
var owl_perches: Array[Vector3] = []
var owl_radius: float = 0.0
var owl_available: bool = true

## Every cabin doorstep, flat, and how close a tap has to land to mean one.
## Empty until HubWorld hands over the built cabins, so a layout with no
## cabin simply never emits tapped_cabin.
##
## Set from the BUILT cabins for the reason the perches and the feet are:
## the prop the player aims at and the point this radius is measured from
## have to be one fact.
##
## No availability flag beside them -- see the signal's own comment.
var cabin_doors: Array[Vector3] = []
var cabin_radius: float = 0.0

## The campfire's tap point(s), flat, and how close a tap has to land to
## mean one. Empty until HubWorld hands over the built campfire, so a
## layout with no campfire simply never emits tapped_campfire.
##
## A LIST from the first commit, on the table doctrine every other prop
## registry here already follows -- CH23's fire is one instance today, but a
## second one is not this file's business to have ruled out.
var campfire_points: Array[Vector3] = []
var campfire_radius: float = 0.0

## =====================================================================
## CH73 -- THE GESTURE'S OWN STATE. See the block at the top of the file.

## Which event class owns the gesture in flight. The emulated twin of a
## real finger is whichever of the two did NOT claim it, and it is
## ignored whole for the length of the gesture.
enum Claim { NONE, MOUSE, TOUCH }

var _claim: int = Claim.NONE
## Where the claiming press landed, in raw screen pixels, and where the
## finger was last seen. The orbit integrates the DIFFERENCE between
## consecutive samples, never the offset from the anchor: an integrated
## delta means a finger that returns to its anchor returns the camera
## with it, which is what "the camera follows the finger" means.
var _anchor: Vector2 = Vector2.ZERO
var _last: Vector2 = Vector2.ZERO
## ⚠️ CLEARED ON THE CLAIMING PRESS, NEVER ON A RELEASE -- the whole of
## the double-dispatch defence. See the file header.
var _dragged: bool = false

## The hub camera, when the scene's camera is one. `camera` above stays
## typed `Camera3D` because every ray this file casts only needs that;
## this is the orbit's writer and nothing else reads it.
var hub_camera: HubCamera = null
## Keepy, asked one question: is he on his feet. Optional -- a layout
## that hands over no hopper simply never licenses an orbit.
var hopper: KeepyHopper = null

## ⚠️ THE LICENCE, WRITTEN ONCE. Four things have to be true, and a
## caller that remembered three of them would be the inherited-guard
## defect CLAUDE.md records against ON_CARRIER.
##
##   * there IS a hub camera to turn;
##   * it is in its OWN pose -- not a chase (a piloted vehicle owns the
##     frame) and not a POV (CH72: the camera IS the rider's head, and a
##     finger there already means "give me the third person back");
##   * Keepy is on his FEET -- walking or standing. Every other state is
##     a carrier or a ride, where the camera is either somebody else's
##     or deliberately fixed on an authored trajectory;
##   * and the gesture reached the glass at all, which the four
##     driven-vehicle shunts at the top of `_unhandled_input` have
##     already answered by returning before anything here runs.
func _orbit_licensed() -> bool:
	if hub_camera == null or not is_instance_valid(hub_camera):
		return false
	if hub_camera.is_driving() or hub_camera.is_pov():
		return false
	if hopper == null or not is_instance_valid(hopper):
		return false
	return hopper.is_afoot()

## The press half. Claims the gesture, seeds the anchor, clears the latch.
##
## ⚠️ IT CLAIMS EVEN WHEN THE ORBIT IS NOT LICENSED, and that is not an
## oversight. The licence is asked again on every motion, so a gesture
## that starts while a ride is running and outlives it does not suddenly
## start turning the camera mid-stroke; what the claim buys here is that
## the SECOND press of the twin pair never re-seeds an anchor the first
## one has already set, which is a property of the event pair and has
## nothing to do with what the camera is doing.
func _gesture_begin(claim: int, at: Vector2) -> void:
	if _claim != Claim.NONE:
		return
	_claim = claim
	_anchor = at
	_last = at
	_dragged = false

## The motion half. Latches the drag on the RAW travel from the anchor --
## SkateTouchInput's own rule, for its reason: the latch decides whether
## a release is a tap, and a thumb that has plainly travelled 40 px must
## not read as a tap.
func _gesture_move(claim: int, at: Vector2) -> void:
	if _claim != claim:
		return
	var step: Vector2 = at - _last
	_last = at
	if (at - _anchor).length() >= SkateTouchInput.SLOP_PX:
		_dragged = true
	if not _dragged:
		return
	if not _orbit_licensed():
		return
	# ⚠️ THE SIGNS. Dragging RIGHT turns the camera so the world sweeps
	# left under it -- the camera orbits the way the finger pushes,
	# which is what every map and every turntable on a phone does.
	# Dragging DOWN lowers the camera toward the horizon; dragging UP
	# lifts it toward the overhead view. Both are the gesture of moving
	# the CAMERA, not of moving the world, and they are gated from a
	# known pixel travel (PHASE G) rather than left to a reading of
	# these two minus signs.
	hub_camera.orbit_by(-step.x * HubCamera.ORBIT_GAIN, -step.y * HubCamera.ORBIT_GAIN)

## The release half. Answers ONE question -- was this a tap -- and the
## answer is the same for both releases of a twin pair because the latch
## is not cleared here.
##
## ⚠️ THE SLOP, AND **NOT** `TAP_MAX_S`. The board's writer gates on
## both; this one gates on distance alone, and the divergence is a
## decision with a reason rather than an omission.
##
## On the board a HELD FINGER HAS A SECOND MEANING -- it is the
## throttle, so a finger pressed and held without sliding is the gesture
## for "go straight on", and reading it as the exit tap would eject a
## rider who was asking to accelerate. `TAP_MAX_S` is what tells those
## two apart, and its own comment says exactly that: "a finger held
## motionless for a second is not asking to get off".
##
## In the hub a held finger has NO second meaning. There are two
## gestures and one of them is defined by MOVING; a press that never
## moves can only ever have meant the place under it. Adding a time
## limit here would invent a third outcome -- press, wait, lift,
## NOTHING HAPPENS -- with no feedback to explain it, and the player it
## would catch is the deliberate one resting his thumb before lifting.
##
## ⚠️ AND THE LIMIT WAS MEASURED BEFORE IT WAS DECLINED, on a bench that
## had already been bitten by it. Under llvmpipe one `process_frame` is
## ~0.14 s of WALL CLOCK (TAP_MAX_S is real time; `--fixed-fps` only
## fixes the simulation step), so the probe's own six-frame tap lasts
## 0.824 s and fell outside a 0.450 s window -- which made one assertion
## pass or fail according to machine load, and sent a red pass chasing a
## defect that was not there. That is CLAUDE.md's "une sonde a sequence
## temporelle se rejoue a charge comparable" arriving through the code
## instead of through the bench. It is the evidence, not the reason:
## the reason is the paragraph above, and it would hold on a phone that
## renders at 120 Hz.
func _gesture_was_tap() -> bool:
	return not _dragged

## Ends the gesture for the CLAIMING class only, so the twin's release
## still reads the latch before the next press clears it.
func _gesture_end(claim: int) -> void:
	if _claim == claim:
		_claim = Claim.NONE

func _ready() -> void:
	camera = get_node_or_null(camera_path) as Camera3D
	# CH73: the same node, asked for the one thing the orbit needs. Null
	# on any layout whose camera is a plain Camera3D, which simply means
	# no orbit -- never an error, on the mooring's optional-node pattern.
	hub_camera = camera as HubCamera
	container = get_node_or_null(container_path) as SubViewportContainer
	viewport = get_node_or_null(viewport_path) as SubViewport
	mooring = get_node_or_null(mooring_path) as BoatMooring
	zipline = get_node_or_null(zipline_path) as ZiplineDoor
	transport = get_node_or_null(transport_path) as HubTransport
	trees = get_node_or_null(trees_path) as HubTrees
	critters = get_node_or_null(critters_path) as HubCritters
	karting = get_node_or_null(karting_path) as HubKarting
	cove = get_node_or_null(cove_path) as HubCove
	funfair = get_node_or_null(funfair_path) as HubFunfair
	hopper = get_node_or_null(hopper_path) as KeepyHopper
	if camera == null or container == null or viewport == null:
		push_error("HubTapInput: camera_path, container_path and viewport_path must all resolve.")

func _unhandled_input(event: InputEvent) -> void:
	# v7: while the kart is driven the screen is a steering wheel, not a
	# map. Not handled, so KartTouchInput sees it whichever runs first.
	# CH30: and the same for the sand yacht, which is driven by the same
	# writer -- one condition per DRIVEN VEHICLE, not per vehicle.
	if karting != null and karting.is_driving():
		return
	if transport != null and transport.is_driving_yacht():
		return
	# CH33: and the same for the sailboat, the third vehicle driven by the
	# same writer -- one condition per DRIVEN VEHICLE, not per vehicle.
	if transport != null and transport.is_driving_sailboat():
		return
	# CH63 / CH64: and the same for the board, the fourth condition of the
	# same shape. A ridden board is piloted frame by frame by a held finger
	# (SkateTouchInput), which is CLAUDE.md's own criterion for a piloted
	# vehicle, so every point made while riding belongs to that writer.
	#
	# ⚠️ THIS IS WHAT SHUNTS THE SHIPPED TAP ROUTE while riding, and it has
	# to be HERE rather than at a board branch in HubWorld: one finger has
	# ONE meaning, and a second reader of the same point would be the
	# double dispatch CH63's red pass exists to prove absent. CH64 removed
	# the TAP scheme (and its `drag_enabled()` half of this test): the
	# ride alone decides. `_handle_point` and `_on_tapped_ground` are not
	# touched, and the ten states and eighteen probes that share them
	# neither know nor care that the board exists.
	if transport != null and transport.is_riding_board():
		return
	# =================================================================
	# CH73 -- THE GESTURE IS READ FIRST, AND THE TAP PATH IS UNCHANGED
	# BELOW THE SLOP.
	#
	# Both classes are read, for the reason the header gives: a desktop
	# browser produces the mouse class and nothing else.
	#
	# ⚠️ WHAT KEEPS A PHONE'S TWIN PAIR FROM BEING INTEGRATED TWICE IS
	# THE INTEGRATION, NOT THE CLAIM, and the red pass is what said so.
	# `_gesture_move` accumulates the difference between CONSECUTIVE
	# samples, so a twin delivered at the same pixel contributes the
	# delta once and exactly zero the second time -- removing the claim
	# entirely left the probe ALL GREEN. The claim earns its place
	# against a different defect (a hover; see `_orbit_licensed`'s
	# neighbours and OrbitCameraProbe D4), and crediting it with this one
	# would be the mistake CLAUDE.md records about attribution.
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			_gesture_begin(Claim.TOUCH, touch.position)
			# NOT marked handled: the press is not consumed today and
			# consuming it now would take it from every other reader of
			# the press half, which is a change this lot has no reason
			# to make.
			return
		var was_tap: bool = _gesture_was_tap()
		_gesture_end(Claim.TOUCH)
		if was_tap:
			_handle_point(touch.position)
		get_viewport().set_input_as_handled()
		return
	var drag := event as InputEventScreenDrag
	if drag:
		_gesture_move(Claim.TOUCH, drag.position)
		return
	var motion := event as InputEventMouseMotion
	if motion:
		# Only while a gesture of the mouse class is live: a mouse moved
		# with no button down is a hover, and a phone's emulated motion
		# is the twin of a drag the touch class has already claimed.
		if _claim == Claim.MOUSE:
			_gesture_move(Claim.MOUSE, motion.position)
		return
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			_gesture_begin(Claim.MOUSE, click.position)
			return
		var was_tap: bool = _gesture_was_tap()
		_gesture_end(Claim.MOUSE)
		if was_tap:
			_handle_point(click.position)
		get_viewport().set_input_as_handled()

func _handle_point(screen_point: Vector2) -> void:
	if camera == null or container == null or viewport == null:
		return
	var rect := container.get_global_rect()
	if not rect.has_point(screen_point):
		return
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var local := screen_point - rect.position
	local.x *= float(viewport.size.x) / rect.size.x
	local.y *= float(viewport.size.y) / rect.size.y

	var origin := camera.project_ray_origin(local)
	var direction := camera.project_ray_normal(local)
	# Maths, not a physics raycast: the ground is a decorative PlaneMesh
	# with no collider, and giving it one purely so a ray could hit it
	# would add a physics body to a screen that has no physics.
	#
	# HubSurface answers this, not a bare Plane, so a tap lands on the
	# ground the player can SEE rather than on sea level under it. With no
	# domain registered it IS the bare Plane -- the same call, not an
	# approximation of it (SurfaceProbe phase B checks that identity on 20
	# rays), so today this line is byte-identical to the one it replaces.
	# =====================================================================
	# CH72 -- THE RIDER'S CHANNEL IS ASKED HERE, ABOVE THE HORIZON RETURN,
	# AND THAT POSITION IS LOAD-BEARING.
	#
	# Every question below this block needs a point ON THE GROUND, so they
	# all sit under the `hit == null` return. This one does not: it is a
	# toggle, it carries no destination, and it is answered off the RAY.
	#
	# ⚠️ ASKED BELOW THAT RETURN IT WOULD HAVE BEEN THE PATRON ECHELLE.
	# While the POV is running the camera IS the rider's head, and a head
	# looking level down a coaster rail aims most of the screen AT OR
	# ABOVE THE HORIZON -- where `HubSurface.intersect_ray` answers null
	# and this function gives up three lines later. Every one of those
	# taps would have been swallowed, and the tap that swaps the view back
	# is the only way out of the POV: a player looking at the sky would
	# have been sealed inside his own eyes with the menu still working,
	# which is CH58's shipped defect exactly. Asked here, the way out does
	# not depend on what he happens to be looking at.
	if funfair != null and funfair.accepts_rider_tap(origin, direction):
		tapped_funfair_rider.emit()
		return
	var hit: Variant = HubSurface.intersect_ray(origin, direction)
	if hit == null:
		# Camera looking at or above the horizon. Nothing to aim at.
		return
	var point: Vector3 = hit
	# WHERE THE FINGER POINTED, and it is a SEPARATE fact from where he can
	# walk. Every prop below is asked about `aim`; only the destination is
	# clamped. Those were one variable until the cabin proved they are two.
	#
	# ⚠️ THE THIRD STRAY-ENTRY CAUSE, and the one no radius could have
	# fixed. clamp_to() answers "where can he stand"; a prop test answers
	# "what did the player mean". Reading the second off the first makes
	# the clamp a FUNNEL: every tap on ground that does not exist is
	# dragged to the nearest ground that does, and if a prop happens to sit
	# near that edge, the whole half-plane behind it starts meaning the
	# prop. Measured on the shipped layout: the cabin's doorstep stands
	# 0.655 u inside the plateau's north edge, so a 2.246 u strip of that
	# edge lies inside the doorstep disc -- and taps aimed from as far as
	# 49.8 u off the map landed on it and MEANT "go inside". Standing at
	# the door, 15.26% of all visible ground said "go inside", 89.2% of it
	# aimed at ground that is not there.
	#
	# WHY THE OTHER THREE ARE ASKED THE SAME WAY when only the cabin was
	# broken: measured, the boat, the owl and the three ladder feet are
	# 6.85 u to infinitely far from any off-map ground and NOT ONE off-map
	# point funnels into any of them, so this costs them nothing today. It
	# is written once rather than as a cabin special case because the
	# funnel is a property of standing near an EDGE, not of being a cabin,
	# and the next prop placed near one would rediscover it.
	var aim := Vector3(point.x, 0.0, point.z)
	# One shape, one owner. The region is a union minus the great lake, so
	# this is a nearest-point projection and not two independent clamps --
	# see HubRegion for why the difference matters and what it costs.
	var destination := HubRegion.clamp_to(point)

	# =====================================================================
	# CH57 -- THE PHYSICS BOARD TAKES EVERY TAP, AND IT IS THE ONLY PROP
	# THAT DOES
	#
	# CH58 routed a ridden board's tap here, straight to tapped_ground,
	# because the board was then a carrier that was NOT piloted -- the
	# screen was still a map. CH64: it is piloted (SkateTouchInput), so it
	# joined the shunt in `_unhandled_input` beside the three other driven
	# vehicles, and no point reaches this function while riding.
	# THE BOAT WINS, and it is asked BEFORE the ground point becomes a
	# destination. The radius is in WORLD units and is measured on this
	# same ground point, so "the boat or the ground behind it" is decided
	# in the space a hop destination already lives in rather than in
	# pixels, where the target would shrink with distance.
	#
	# accepts_boarding_tap() is false for the whole of a ride, so a tap
	# then falls through to tapped_ground -- which is what turns it into
	# an eject. One tap, one signal, either way.
	if mooring != null and mooring.accepts_boarding_tap(aim):
		tapped_boat.emit(destination)
		return
	# THE ZIPLINE, asked on the boat's exact terms and for the boat's exact
	# reason: `accepts_boarding_tap()` is false for the whole of a trip AT
	# BOTH ENDS, so a tap then falls through to tapped_ground and reaches
	# the state branch that owns it. One tap, one signal, either way.
	#
	# Ordered after the boat only because the boat was here first. The
	# hull sails the stream at the west of the plateau and the badger waits
	# at x ~ +26, twenty-odd units away, so the order between them can
	# never actually decide anything.
	#
	# Asked on `aim` like every prop above and below, not on `destination`:
	# a disc read off the CLAMPED point turns the plateau's edge into a
	# funnel -- the cabin's measured defect, written once for every prop
	# because being near an edge is what causes it, not being a cabin.
	if zipline != null and zipline.accepts_boarding_tap(aim):
		tapped_zipline_badger.emit(destination)
		return
	# THE STRUCTURE, asked right after the badger and on the same `aim`
	# terms, for the same edge-funnel reason. Checked SECOND so a tap
	# landing in the small lens where the two discs geometrically
	# overlap (see ZiplineDoor.gd) would in principle read as the badger
	# first -- though `accepts_structure_tap` already excludes that lens
	# on its own, so this order cannot actually change the answer.
	if zipline != null and zipline.accepts_structure_tap(aim) >= 0:
		tapped_zipline_solo.emit(destination)
		return
	# THE BALLOON DOCKS and THE BALL (v3), asked on `aim` like everything
	# else and withdrawn through their node for the whole of a trip / a
	# ride. Ordered here only because the zipline came first; the docks and
	# the park are metres from every other disc, so the order cannot decide.
	if transport != null and transport.accepts_balloon_tap(aim) >= 0:
		tapped_balloon.emit(destination)
		return
	if transport != null and transport.accepts_vehicle_tap(aim):
		tapped_vehicle.emit(destination)
		return
	# THE SANDCASTLE SPOTS (CH29), on `aim`, right after the vehicles: the
	# yacht can be dropped anywhere, a castle spot included, and a body on
	# a spot beats the spot (the boar's rule over the pile).
	if cove != null:
		var spot: int = cove.accepts_castle_tap(aim)
		if spot >= 0:
			tapped_castle.emit(destination, spot)
			return
	# THE FUNFAIR (CH71), on `aim`, right after the castle spots and on
	# the vehicles' exact terms: a ride that is running WITHDRAWS through
	# its node, so a tap made meanwhile falls through to the ground path
	# and is dropped there by ON_CARRIER. Ordered here only because the
	# castles came first; the fair stands on the plateau's east strip,
	# metres from every other disc, so the order cannot decide.
	if funfair != null:
		# CH72: the rider's own channel is NOT asked here -- it is asked
		# above the horizon return, for the reason written there. A ride
		# that is running has withdrawn from `accepts_tap`, so the two
		# questions can never both answer anyway.
		var ride: int = funfair.accepts_tap(aim)
		if ride >= 0:
			tapped_funfair.emit(destination, ride)
			return
	# THE CLIMBABLE TREES (v4), on `aim` like everything else -- and (v5)
	# on the RAY, because a crown is what the player taps and a crown at
	# 3 u projects onto the ground 3.5 u south of its trunk. The perchoirs'
	# discs are metres from every other prop's (V4SiteProbe); the decor
	# trees' discs are a trunk plus a hand, so a path beside one stays a
	# path. The occupied tree answers only through the ground channel, at
	# its own foot, which is how the seat's shake is asked for.
	if trees != null:
		var tree: int = trees.tree_hit(aim, origin, direction, true)
		if tree >= 0:
			if tree == trees.occupied():
				tapped_ground.emit(trees.position_of(tree))
			else:
				tapped_tree.emit(destination, tree)
			return
	# THE INHABITANTS (V6), on `aim` like everything else, each module
	# withdrawing on its own terms for the length of its ride. Asked after
	# the trees: the boar rests in the hollow, metres from any crown, so
	# the order between them cannot decide anything.
	# v7: the kart, on `aim`, before the inhabitants (the grid is in the
	# circuit, metres from every animal; the order cannot decide).
	if karting != null and karting.accepts_tap(aim):
		tapped_kart.emit(destination)
		return
	if critters != null:
		var critter_hit: Dictionary = critters.accepts_tap(aim)
		if not critter_hit.is_empty():
			tapped_critter.emit(destination, critter_hit["kind"], int(critter_hit["index"]))
			return
	# THE OWL, asked after the boat and before the ladder, on the same
	# world-unit terms both of them use. The order between the owl and the
	# ladder can never actually decide anything -- the perch is by the
	# spawn and the three ladder feet are out over the water, metres away
	# -- so it is only that the boat came first and the ladder was here
	# before this.
	#
	# Nothing is asked here about whether Keepy is FREE to fly: that is
	# KeepyHopper's business and it refuses from any state but standing
	# still. What IS asked is `owl_available`, which is a different
	# question -- not "may he" but "is this signal still meaningful", the
	# boat's own withdrawal, and the thing that turns a tap during a
	# flight back into an ordinary ground tap.
	if owl_available and owl_radius > 0.0:
		var owl_flat := aim
		for perch in owl_perches:
			if owl_flat.distance_to(perch) <= owl_radius:
				tapped_owl.emit(destination)
				return
	# THE CABIN, asked on the identical world-unit terms but NOT gated on a
	# withdrawal, unlike the two above -- see the signal's comment. Ordered
	# here only because the owl was here first: the perch is by the spawn
	# and the cabin is out at z = +28, so the order between them can never
	# actually decide anything.
	#
	# Nothing is asked here about whether Keepy is free to go in. HubWorld
	# refuses a tap made mid-ride, and the walk to the door is an ordinary
	# hop chain that any later tap may cancel.
	if cabin_radius > 0.0:
		var cabin_flat := aim
		for door in cabin_doors:
			if cabin_flat.distance_to(door) <= cabin_radius:
				tapped_cabin.emit(destination)
				return
	# THE CAMPFIRE, asked on the identical world-unit terms and, like the
	# cabin, NOT gated on a withdrawal here -- see the signal's own comment.
	# Ordered after the cabin only because the cabin was here first; the two
	# sites are metres apart, so the order between them can never actually
	# decide anything.
	if campfire_radius > 0.0:
		var campfire_flat := aim
		for spot in campfire_points:
			if campfire_flat.distance_to(spot) <= campfire_radius:
				tapped_campfire.emit(destination)
				return
	# THE LADDER, asked after the boat and on the same terms: a world-unit
	# radius on the ground point, so the target does not shrink with
	# distance the way a pixel one would. Ordered after the boat only
	# because the boat came first; the two are metres apart at opposite
	# ends of the plateau, so the order can never actually decide anything.
	#
	# Nothing is asked here about whether Keepy is FREE to climb. That is
	# KeepyHopper's business, and it refuses from any state but standing
	# still -- asking twice is how the two answers start to differ.
	if ladder_radius > 0.0:
		var flat := aim
		for foot in ladder_feet:
			if flat.distance_to(foot) <= ladder_radius:
				tapped_ladder.emit(destination)
				return
	tapped_ground.emit(destination)
