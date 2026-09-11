extends Camera3D
class_name HubCamera
## Follows Keepy at a fixed 3/4 offset, softly.
##
## Fixed ROTATION, not look_at: a look_at re-aimed every frame at a target
## whose height oscillates 0.6 units per hop would pitch the whole plateau
## up and down in time with the hops -- the horizon would bounce, which is
## far more noticeable than the character does.
##
## The follow target is Keepy's GROUND position, y discarded, for the same
## reason: the camera tracks where he is on the plateau, not where he is in
## his arc.

## Offset from Keepy's ground position, in world units. MEASURED, not
## picked: with the scene's -34 degree pitch and keep_aspect KEEP_WIDTH,
## this is the closest the camera gets before an outer portal's floating
## label leaves the frame. One step nearer (6.6, 7.7) puts Keepy at 144px
## tall and pushes both side labels off-screen; this one holds him at
## 124px with the outer portal pads at 7.8% and 92.2% of screen width.
## Checked at 1080x1920 and at 1170x2532.
const OFFSET: Vector3 = Vector3(0.0, 7.6, 8.9)

## CH36 -- WHERE THE TOP OF THE FRAME CROSSES KEEPY'S APLOMB, in world
## units. This camera NEVER RISES (it is a constant offset from Keepy's
## GROUND point, and its rotation is FIXED -- see above), so the column
## straight above him is cut by the top edge of the picture at one height
## and one only, and nothing published above it is on screen. Everything
## that asks "can the player see the top of this" -- HubTrees' SEAT_MAX_Y
## first -- derives from HERE rather than re-deriving its own angle.
##
## ⚠️ MEASURED, NEVER COMPUTED FROM AN ANGLE. The number this replaces
## (6.96 u) came from a closed form written as if the camera LOOKED AT
## Keepy's ground point -- atan(7.6 / 8.9) = 40.5 deg. It does not: the
## scene authors the pitch, 34.0 deg (HubWorld.tscn's Camera3D basis,
## asin(0.55919)), and 34.0 is SMALLER than the vertical half-angle, so
## the top ray leaves the lens going UP, not down, and the sign of the
## whole term flips. The formula's answer was 1.008 u too low and no
## probe gated it, so it survived two lots and cost eight trees their
## climb (CH26's SEAT_MAX_Y).
##
## What this value IS: at 1080x1920 with keep_aspect KEEP_WIDTH and
## fov 45 (so 22.5 deg HORIZONTAL half-angle, 36.37 deg vertical), the
## ray through the top edge of the picture, read back off the LIVE camera
## by unproject_position bisection and confirmed independently by
## project_position to 1e-4. FrameCeilingProbe re-reads it every run and
## fails if the scene's camera ever stops agreeing.
const FRAME_TOP_AT_APLOMB: float = 7.968

## Seconds-ish smoothing constant. Frame-rate independent via the
## exponential form below, so a 30fps phone and a 60fps one settle at the
## same rate rather than the phone lagging twice as far behind.
const FOLLOW_LAMBDA: float = 5.0

## The node to follow, as a scene-authored path. NodePath rather than a
## typed node export for the reason measured in HubTapInput.gd: a typed
## node export hand-written into a .tscn does not resolve at load.
@export var target_path: NodePath

var target: Node3D = null

## =====================================================================
## CARTE-BLANCHE V7 -- THE DRIVE MODE, the one licensed exception
##
## "The hub camera never yaws and never approaches" is doctrine (see
## OFFSET above, and CLAUDE.md), and it still is: OUTSIDE the kart every
## line of this file behaves exactly as before. Mathieu licensed a chase
## camera FOR THE LENGTH OF A DRIVE ONLY, because a kart circling a track
## under a fixed frame is unreadable -- the track leaves the frame and the
## player steers by memory.
##
## The mode is a BLEND, 0 = hub pose, 1 = drive pose, tweened in both
## directions, so entering the kart is a camera move and not a cut, and
## leaving it lands back on the hub pose the follow was converging on the
## whole time (the hub position keeps tracking Keepy's ground point while
## he sits in the kart, so the return has nowhere far to go). The hub
## BASIS is stored at _ready and restored byte-identically at blend 0:
## the exit cannot leave the horizon a hair off.
##
## The drive pose looks AT the kart (look_at is licensed here for the
## reason it is banned in the hub: the kart does not hop, so nothing
## bounces the horizon) from behind and above, along a HEADING that lags
## the kart's real heading -- the lag is what lets the player see the
## kart's nose swing into a corner.

const DRIVE_BACK: float = 7.6
const DRIVE_UP: float = 4.4
const DRIVE_LOOK_AHEAD: float = 5.5
const DRIVE_LOOK_UP: float = 0.4
## The drive pose looks toward the horizon, so frustum culling stops
## protecting the frame: MEASURED at the start line, 123 515 primitives
## against 69 551 at the spawn, because the moor, both hedges and the far
## wall were all in the frustum. The far plane closes at 120 u -- where
## CozyPalette.HAZE_DENSITY (0.022) has already dissolved 93 % of a thing
## into the sky colour -- and is restored with the basis on exit.
const DRIVE_FAR: float = 120.0
const DRIVE_HEADING_LAMBDA: float = 3.6
const DRIVE_POSITION_LAMBDA: float = 7.0
const DRIVE_FOV: float = 60.0
const DRIVE_BLEND_S: float = 0.9

## =====================================================================
## CH64 -- THE CHASE HAS A TUNING PER VEHICLE, AND THE BOARD'S IS CALM
##
## Mathieu, device in hand, on the CH63 build: the board's chase camera
## "donne mal a la tete et au ventre", "trop dynamique" -- he wants it
## "plus lente, moins liee aux mouvements". CH63 section 9 had already
## named the cause: the board's facing is written STRAIGHT from the thumb
## with no rate between them, and the camera then follows that facing at
## the kart's DRIVE_HEADING_LAMBDA, i.e. a yaw that answers every wobble
## of the finger within a third of a second.
##
## The kart, the sand yacht and the sled are device-validated on the
## numbers above and this lot does not touch them: `ChaseTuning.vehicle()`
## IS those constants, and the drive branch below takes the exact
## `lerp_angle` path it always took when handed it (a probe gates the
## equality). The board gets its own tuning, three knobs and a fov:
##
##   * `heading_lambda` -- the first-order lag of the orbit angle behind
##     the board's facing. 1.8 against the kart's 3.6: the time constant
##     doubles (0.56 s), so the camera arrives where the board is pointing
##     rather than being there already.
##   * `yaw_rate_max` -- a hard cap on how fast the camera may YAW. The
##     kart has none (a 90 deg flick at lambda 3.6 peaks at 324 deg/s).
##     110 deg/s sits just ABOVE the ~106 deg/s carve CH63 measured under
##     a finger held full across, so the validated turn is NOT slowed in
##     its steady state -- what the cap bounds is the TRANSIENT, the whip
##     the camera does when the finger flicks. It is measured again by
##     SkateInputProbe PHASE T and published.
##     ⚠️ IT IS APPLIED TO THE FINISHED POSE, NOT ONLY TO THE ORBIT. The
##     drive pose is a look-at, and a look-at yaws with the BOARD'S
##     POSITION whatever the orbit does: measured with the cap on the
##     orbit alone, a finger flicked full across turned the frame at
##     170 deg/s in its first second (against ~108 once settled). So the
##     cap is enforced on the pose's own yaw, frame to frame, by rotating
##     the finished transform back to the cap -- and the board's heading,
##     which is read off that basis, is bounded with it.
##   * `deadzone` -- the smallest error the orbit answers at all, applied
##     as a SOFT threshold (the error is shortened by it, never gated on
##     it, so the response is continuous at the edge and the camera
##     cannot chatter across it). 3 deg: a finger that trembles turns
##     the board a few degrees and the camera does not follow; a carve
##     holds 20-30 deg of error and is unaffected.
##   * `fov` -- 56 against the kart's 60. A wider lens puts more of the
##     scenery in motion at the edge of the frame, which is exactly the
##     reading a nauseous player is asking for less of.
##   * `keep_inside` -- the chase pose is held INSIDE the playable
##     region, this far in from its edge. Measured on a capture: a board
##     at the park's north rim facing south puts a camera 7.6 u behind
##     it OUTSIDE the lobe, in the wall trees CozyScatter plants along
##     the rim, and the frame was a canopy with the park behind it. The
##     kart's circuit never nears a wall; the park is bounded by one on
##     three sides. So the board's pose is clamped to the region and
##     pulled this far back in, toward the board -- a border makes the
##     camera come closer, which is what every chase camera does against
##     a wall. ChaseAudit PHASE CALM renders the board at three rims and
##     demands its pixels.
##
## ⚠️ WHAT THIS CANNOT SIGN. Motion sickness is a sensation; a probe
## measures a yaw rate and a frame position. ChaseAudit PHASE CALM gates
## that the board stays in frame under the calm tuning at cruise and in
## a full-lock carve, that the yaw never exceeds the cap, and that the
## orbit settles with no overshoot when the finger lifts. Whether it is
## COMFORTABLE is Mathieu's, on device. If it is still too lively, the
## knobs are these four numbers, in this file, and a change is a commit
## -- never a menu toggle (CH64 is the lot that removed those).
const BOARD_HEADING_LAMBDA: float = 1.8
const BOARD_POSITION_LAMBDA: float = 4.0
const BOARD_YAW_RATE_MAX: float = deg_to_rad(110.0)
const BOARD_DEADZONE: float = deg_to_rad(3.0)
const BOARD_FOV: float = 56.0
const BOARD_KEEP_INSIDE: float = 2.5
## CH75: the Comet's chase (see ChaseTuning.coaster()).
const COASTER_YAW_RATE_MAX: float = deg_to_rad(150.0)
const COASTER_FOV: float = 64.0
const COASTER_UP: float = 6.2

class ChaseTuning extends RefCounted:
	var heading_lambda: float = DRIVE_HEADING_LAMBDA
	var position_lambda: float = DRIVE_POSITION_LAMBDA
	## Radians per second; INF means no cap.
	var yaw_rate_max: float = INF
	## Radians; 0 means the orbit answers every error.
	var deadzone: float = 0.0
	var fov: float = DRIVE_FOV
	## World units in from the region's edge the pose is kept; negative
	## means the pose may leave the region (the three vehicles).
	var keep_inside: float = -1.0
	## CH75: the chase follows a body that LEAVES THE GROUND. The shipped
	## pose anchors on `HubSurface.ground(at)` -- the ground under the
	## vehicle -- and looks at that ground point, which is right for a
	## kart and puts a coaster cart 14 u up entirely out of the picture.
	## Airborne, the drive TARGET is a MOUNT the ride itself trails along
	## its rail (HubFunfair's comet mount, DRIVE_BACK behind the cart on
	## the curve), the pose stands `up` straight above that mount, and
	## the camera looks at `look_target` -- the cart.
	##
	## ⚠️ A MOUNT ON THE RAIL, NOT A POINT BEHIND THE CART, AND THAT IS
	## MEASURED THREE TIMES OVER. (1) DRIVE_BACK behind on the FLAT
	## heading, cart height + 6: CometProbe E11 read the camera INSIDE
	## the posts under the drop rail (24 frames) and ON the drop rail (8),
	## because posts stand on the rail's XZ line and that line climbs 23 u
	## in the 7.6 u behind a cart on a 72 deg drop. (2) DRIVE_BACK behind
	## along the cart's LAGGED 3D tangent: still 16 / 15 frames -- as the
	## tangent swings through the valley the trailing point sweeps across
	## the concave rail behind. (3) A mount ON the curve, `up` above it:
	## rails and posts are under the camera by construction, on the lift,
	## the drop, the camelback and both turns, and the only thing left to
	## measure is the position lag cutting the inside of the valley
	## (~0.9 u of a 6.2 u margin).
	var airborne: bool = false
	## The body an airborne chase LOOKS AT (the cart); the drive target
	## is then only where the pose stands.
	var look_target: Node3D = null
	## How far above the anchor the pose stands. The ground vehicles use
	## DRIVE_UP; the Comet stands higher, because 4.4 u over a cart at
	## the bottom of its camelback put the camera INTO the camelback's
	## rail on the way round (CometProbe E11: 27 frames inside a rail,
	## 37 inside a post, before this number existed).
	var up: float = DRIVE_UP

	## The three device-validated vehicles: the constants above, verbatim,
	## and the exact `lerp_angle` arithmetic they shipped with.
	static func vehicle() -> ChaseTuning:
		return ChaseTuning.new()

	## The skateboard's calm chase. See the block above.
	static func board() -> ChaseTuning:
		var t := ChaseTuning.new()
		t.heading_lambda = BOARD_HEADING_LAMBDA
		t.position_lambda = BOARD_POSITION_LAMBDA
		t.yaw_rate_max = BOARD_YAW_RATE_MAX
		t.deadzone = BOARD_DEADZONE
		t.fov = BOARD_FOV
		t.keep_inside = BOARD_KEEP_INSIDE
		return t

	## CH75: the Comet's chase -- the kart's lags (3.6 / 7.0, validated
	## on device three vehicles over), the board's yaw cap so the pose
	## never whips through a fast turn (150 deg/s, above anything the
	## rail asks: CometProbe measures the cart's own yaw rate and gates
	## the cap over it), no deadzone (the rail does not wobble), airborne,
	## and the widest fov of the four -- a FEEL number, Mathieu's to move.
	static func coaster(cart: Node3D) -> ChaseTuning:
		var t := ChaseTuning.new()
		t.yaw_rate_max = COASTER_YAW_RATE_MAX
		t.fov = COASTER_FOV
		t.airborne = true
		t.up = COASTER_UP
		t.look_target = cart
		return t

	## True when the tuning is exactly the shipped vehicle chase, so the
	## drive branch can take the byte-identical path for the three.
	func is_plain() -> bool:
		return deadzone <= 0.0 and yaw_rate_max == INF and keep_inside < 0.0 and not airborne

var _hub_basis: Basis = Basis.IDENTITY
var _hub_fov: float = 45.0
var _hub_far: float = 4000.0
var _hub_position: Vector3 = Vector3.ZERO
var _drive_target: Node3D = null
var _tuning: ChaseTuning = ChaseTuning.new()
var _drive_heading: float = 0.0
## The finished drive pose's yaw on the last frame, for the cap above.
var _drive_yaw: float = 0.0
var _drive_yaw_valid: bool = false
var _drive_position: Vector3 = Vector3.ZERO
var _blend: float = 0.0
var _blend_tween: Tween = null

func _ready() -> void:
	_hub_basis = global_transform.basis
	_hub_fov = fov
	_hub_far = far
	target = get_node_or_null(target_path) as Node3D
	if target == null:
		push_error("HubCamera: target_path does not resolve to a Node3D.")
	else:
		snap_to_target()
	_hub_position = global_position

func is_driving() -> bool:
	return _drive_target != null

## For a bench: the orbit angle the chase currently holds, and the tuning
## it holds it with.
func drive_heading() -> float:
	return _drive_heading

func drive_tuning() -> ChaseTuning:
	return _tuning

func drive_blend() -> float:
	return _blend

## Starts the chase on `kart` -- any Node3D whose `rotation.y` is its
## heading and whose `global_position` is where it is. CH63 LOT 2 added a
## fourth: the skateboard, which satisfies both (its facing is written
## from the commanded heading in `SkateBoardBody.drive()`).
## CH64: `tuning` selects the chase's response; null is the vehicles'
## own (kart / yacht / sled), the board hands in `ChaseTuning.board()`.
func enter_drive(kart: Node3D, tuning: ChaseTuning = null) -> void:
	_drive_target = kart
	_tuning = tuning if tuning != null else ChaseTuning.vehicle()
	_drive_yaw_valid = false
	_drive_heading = kart.rotation.y
	_drive_position = _drive_wanted()
	far = DRIVE_FAR
	_tween_blend(1.0)

## Back to the hub pose. The target stays referenced until the blend is
## done so the drive pose keeps its last shape while it fades.
func exit_drive() -> void:
	if _drive_target == null:
		return
	_tween_blend(0.0)

func _tween_blend(to: float) -> void:
	if _blend_tween and _blend_tween.is_valid():
		_blend_tween.kill()
	_blend_tween = create_tween()
	_blend_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_blend_tween.tween_property(self, "_blend", to, DRIVE_BLEND_S)
	if to <= 0.0:
		_blend_tween.finished.connect(_on_drive_exited, CONNECT_ONE_SHOT)

func _on_drive_exited() -> void:
	_drive_target = null
	_blend = 0.0
	# CH73: the pose the player LEFT, not the one the scene authored. A
	# drive that gave back the authored basis would quietly undo an orbit
	# every time he got into the kart, which is the opposite of sticky.
	global_transform = Transform3D(_hub_pose_basis(), _hub_position)
	fov = _hub_fov
	far = _hub_far

func _drive_wanted() -> Vector3:
	if _drive_target == null or not is_instance_valid(_drive_target):
		return _hub_position
	var heading := Vector3(sin(_drive_heading), 0.0, cos(_drive_heading))
	var at: Vector3 = _drive_target.global_position
	if _tuning.airborne:
		# CH75: the target IS the mount on the rail; the pose stands
		# straight above it.
		return at + Vector3(0.0, _tuning.up, 0.0)
	var ground: Vector3 = HubSurface.ground(at)
	var flat: Vector3 = ground - heading * DRIVE_BACK
	if _tuning.keep_inside >= 0.0:
		# CH64: held inside the region (see ChaseTuning). The clamp is the
		# region's own; the pull-in is toward the board, never along the
		# edge, so the pose approaches rather than slides.
		var probe := Vector3(flat.x, 0.0, flat.z)
		var inside: Vector3 = HubRegion.clamp_to(probe)
		if inside.distance_to(probe) > 0.0005:
			var toward: Vector3 = Vector3(ground.x, 0.0, ground.z) - inside
			var span: float = toward.length()
			# Never nearer than half a unit behind the board: a pose ON
			# the board's ground point looks straight down, which is a
			# degenerate look-at and a board under the bottom edge of the
			# frame (measured: 0 board pixels at the park's north rim).
			if span > 0.0005:
				inside += toward / span * minf(_tuning.keep_inside, maxf(span - 0.5, 0.0))
			flat = Vector3(inside.x, flat.y, inside.z)
	return HubSurface.ground(flat) + Vector3(0.0, DRIVE_UP, 0.0)

## =====================================================================
## CH62 -- THE RIDE MODE, and CH63 LOT 2 took its POSE away and left it
## its READING
##
## ⚠️ D6 IS OPEN FOR THE BOARD NOW, AND THAT DEMOTED THIS MODE. CH62 wrote
## "D6 (une camera de poursuite pour le hub) IS STILL SHUT", and opened
## the narrowest door it could instead -- a bounded OFFSET on the fixed
## pose -- because the physics board reached 1.7 u of air and 10 u/s on a
## screen where nothing moved in response. Mathieu has since tranche
## option A: the board is piloted continuously under the drag scheme, so
## it takes the DRIVE pose, which yaws, lags its heading and looks where
## the board is going. That does all three of the jobs below, better.
##
## ⚠️ SO THE THREE POSE TERMS ARE INERT WHILE A DRIVE IS RUNNING, and it is
## arithmetic rather than a promise: `_process` takes the drive branch
## when `_drive_target != null`, and that branch never reads
## `_ride_offset()` and never writes `_hub_fov + fov_gain`. What the ride
## mode still does, every frame, in EITHER branch, is ADVANCE AND PUBLISH
## `rush` -- the smoothed reading of the board's pace -- because
## SkateStreaks reads exactly that (`ride_rush() * ride_blend()`), and
## CLAUDE.md's "un fait est publie une fois" is why the streaks do not
## recompute it from the board's speed themselves. Dropping the ride call
## when the drive pose arrived would have killed a shipped,
## device-validated effect silently, in a lot that was not about it.
##
## What follows describes the pose terms as CH62 wrote them. They still
## apply to any future rider that enters the ride WITHOUT a drive; today
## nothing does.
##
## WHAT THE RIDE MODE DOES NOT DO, and this is the whole of why it is not
## D6: it does not yaw, it does not look_at, it does not lag a heading,
## it does not change `far`. The BASIS is untouched -- so the horizon
## cannot bounce, which is the reason the hub pose is fixed in the first
## place -- and the pose stays `_wanted() + OFFSET`, exactly as always,
## with a bounded EXTRA offset added to it. Three terms, all bounded, all
## published by SkateFeel:
##
##   1. a dolly back and up, proportional to `rush()`;
##   2. a share of the board's height above the surface, so a climb reads
##      as a climb instead of as the board sliding up the frame;
##   3. a small fov widening, which is the term that puts more scenery in
##      motion at the edge of the picture.
##
## It runs ONLY while HubTransport is riding the CharacterBody3D board
## (permanent since CH64). Walking, the ball,
## the yacht, the sailboat, the sled and the kart are untouched.
##
## ⚠️ AND IT IS AN OFFSET, NOT A SHADOW VARIABLE. The comment on
## `_process` below is load-bearing: outside the kart, `global_position`
## ITSELF is what gets smoothed, and a lot that smoothed a private copy
## and wrote it out broke CabinProbe silently. The ride adds to the
## TARGET of that same lerp, so an outside writer is still an outside
## writer.
const RIDE_BLEND_S: float = 0.7

var _ride_board: SkateBoardBody = null
var _ride_blend: float = 0.0
var _ride_tween: Tween = null
var _ride_rush: float = 0.0
var _ride_lift: float = 0.0

func is_riding() -> bool:
	return _ride_board != null

## The two readings, published for the bench: what fraction of the effect
## is faded in, and what the smoothed rush currently is.
func ride_blend() -> float:
	return _ride_blend

func ride_rush() -> float:
	return _ride_rush

func ride_offset() -> Vector3:
	return _ride_offset()

func enter_ride(board: SkateBoardBody) -> void:
	if board == null:
		return
	_ride_board = board
	# Rush and lift start at zero and are smoothed up from there, so
	# stepping onto a board that is already rolling is still a camera
	# MOVE and not a cut -- the same reason the kart blends.
	_ride_rush = 0.0
	_ride_lift = 0.0
	_tween_ride(1.0)

func exit_ride() -> void:
	if _ride_board == null:
		return
	_tween_ride(0.0)

func _tween_ride(to: float) -> void:
	if _ride_tween and _ride_tween.is_valid():
		_ride_tween.kill()
	_ride_tween = create_tween()
	_ride_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_ride_tween.tween_property(self, "_ride_blend", to, RIDE_BLEND_S)
	if to <= 0.0:
		_ride_tween.finished.connect(_on_ride_exited, CONNECT_ONE_SHOT)

## The exit restores the hub fov EXACTLY, from the value captured in
## `_ready()` -- `_on_drive_exited`'s discipline, for the same reason: a
## fov left a hair off would be a permanent change to every frame the
## player sees afterwards, and no probe of the ride would ever look at it.
func _on_ride_exited() -> void:
	_ride_board = null
	_ride_blend = 0.0
	_ride_rush = 0.0
	_ride_lift = 0.0
	fov = _hub_fov

func _ride_advance(delta: float) -> void:
	var wanted_rush: float = 0.0
	var wanted_lift: float = 0.0
	if _ride_board != null and is_instance_valid(_ride_board):
		wanted_rush = SkateFeel.rush(_ride_board.pace())
		wanted_lift = _ride_board.lift()
	elif _ride_board != null:
		# The board went away under the ride (a scene teardown, a probe
		# freeing its world). Fade out rather than hold the last pose.
		_ride_board = null
		_tween_ride(0.0)
	_ride_rush = SkateFeel.smooth(_ride_rush, wanted_rush, delta)
	_ride_lift = SkateFeel.smooth(_ride_lift, wanted_lift, delta)

func _ride_offset() -> Vector3:
	if _ride_blend <= 0.0:
		return Vector3.ZERO
	return SkateFeel.camera_offset(_ride_rush, _ride_lift) * _ride_blend

## =====================================================================
## CH73 -- THE ORBIT: THE FIXED POSE, TURNED BY A FINGER, AND IT STAYS
##
## CLAUDE.md's table reads: pilots continuously -> chase; WALKS -> FIXED;
## ride on a fixed trajectory -> fixed (CH72's POV is the fourth line).
## This does NOT move the walking row off "fixed": what it changes is
## WHICH fixed pose. The camera still never yaws by itself, never looks
## at Keepy, never approaches and never leaves the sphere it has always
## sat on -- it simply sits where the player last put it, instead of
## where the scene author put it.
##
## ⚠️ IT IS A RIGID ROTATION OF THE WHOLE RIG ABOUT KEEPY'S GROUND
## POINT, AND THAT IS THE WHOLE DESIGN. Both halves of the pose turn by
## the SAME rotation:
##
##     position = ground + R * OFFSET
##     basis    = R * _hub_basis
##
## Three properties fall straight out of that, none of them tuned:
##
##   1. AT (0, 0) THE ROTATION IS THE IDENTITY, so every line below is
##      arithmetically inert on a tree where nobody has dragged -- the
##      shipped frame is byte-identical, which OrbitCameraProbe PHASE I
##      gates rather than assumes.
##   2. THE DISTANCE CANNOT CHANGE. |R * OFFSET| == |OFFSET| == 11.7034 u
##      for any rotation. CH73 was told not to add a zoom; this shape
##      makes a zoom impossible to add by accident.
##   3. THE CAMERA STILL DOES NOT LOOK AT KEEPY. The offset's elevation
##      is 40.4951 deg and the authored basis pitches 34.0 -- a 6.5 deg
##      disagreement that CH36 measured and that FRAME_TOP_AT_APLOMB is
##      derived from. A rigid rotation carries that disagreement along
##      unchanged, so the framing the OFFSET comment describes (Keepy at
##      124 px, the outer portal pads at 7.8 % and 92.2 %) is preserved
##      at every yaw.
##
## ⚠️ AND THE ROLL IS EXACTLY ZERO, BY ARITHMETIC RATHER THAN BY CLAMP.
## `_hub_basis` is a pure X rotation (the scene authors pitch and nothing
## else), the pitch pivot is a pure X rotation, and the yaw is a pure Y
## rotation, so the product is Ry(yaw) * Rx(-(pitch + 34 deg)) -- a
## yaw-then-pitch basis whose up vector stays in the vertical plane.
## CH72's POV block spells out why a rolling view is the term that makes
## a ride nauseous; a camera the player turns with his thumb has the same
## exposure and gets the same guarantee.
##
## ⚠️ THE PITCH PIVOTS ABOUT THE **SPUN** RIGHT AXIS, not about world X.
## `spin * pivot` is `Rot(spin * X, -pitch) * spin`, so after a half turn
## a downward drag still tips the camera down rather than up. Written as
## a product in that order because the equivalent explicit axis is the
## same arithmetic with one more chance to get a sign wrong.
##
## =====================================================================
## STICKY, AND THE WORD IS LOAD-BEARING
##
## There is no recentring, no delay, no return interpolation and no
## timer: nothing in this file ever writes `_orbit_yaw` or
## `_orbit_pitch` back toward zero. A player who turns the camera and
## walks away keeps that camera for the rest of the session, across
## hops, rides, drives and scene returns. That is the contract Mathieu
## asked for in as many words, and it is gated (PHASE S holds the pose
## for 600 frames and across a walk, and demands bit-for-bit equality).
##
## The cost is stated rather than hidden: EVERY constant this repo has
## derived from the resting frame -- FRAME_TOP_AT_APLOMB and, through
## it, HubTrees.SEAT_MAX_Y, HubFunfair's seat ceiling, HubSkatepark's
## reading -- describes the frame AT ORBIT ZERO. Under an orbit they
## describe a frame the player has chosen to leave. They are still the
## right numbers to AUTHOR against (a prop must be visible to a player
## who has not touched the camera); they are not promises about a frame
## the player has turned.

## The orbit's two angles, in radians. Yaw is free and wraps; pitch is
## an offset on the resting ELEVATION and is clamped to the band below.
##
## ⚠️ NEITHER IS EVER WRITTEN BACK TOWARD ZERO. See the block above.
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.0

## The resting elevation of OFFSET above Keepy's ground point, measured
## from the constant rather than typed: atan2(7.6, 8.9) = 40.4951 deg.
## Everything below is expressed as a band around it, so moving OFFSET
## moves the band with it instead of silently changing what the bounds
## mean -- CLAUDE.md's "un fait est publie une fois, jamais recopie".
static func rest_elevation() -> float:
	return atan2(OFFSET.y, Vector2(OFFSET.x, OFFSET.z).length())

## ⚠️ THE TWO BOUNDS ARE MEASURED, NOT PICKED, AND THE GEOMETRIC LIMITS
## ARE NOT THEM.
##
## The geometric limits are easy and useless. The camera reaches the
## ZENITH at +49.4951 deg of pitch (elevation 90: straight overhead) and
## reaches KEEPY'S OWN GROUND PLANE at -40.4951 (elevation 0: buried).
## The brief forbids passing either. Stopping there would ship two
## degenerate frames, so Ch73Recon swept the band at 1 deg and read
## three quantities off the LIVE camera at each step:
##
##   * the camera's clearance above the surface under it;
##   * whether Keepy's crown still projects inside the container;
##   * what fraction of the container's pixels still resolve to a point
##     on the ground -- i.e. how much of the screen a tap can still
##     ADDRESS. This is the one that decides the low bound, and it is
##     CH72's lesson arriving from a new direction: a camera tilted
##     toward the horizon aims most of the screen AT OR ABOVE it, where
##     `HubSurface.intersect_ray` answers null and `_handle_point` gives
##     up. A player there is NOT sealed (a drag is decided before any
##     ray is cast, so he can always turn back) -- but a screen most of
##     which means nothing is a screen that reads as broken.
##
## ⚠️ THE SWEEP FOUND NO KNEE, AND THAT IS PART OF THE ANSWER. Keepy's
## crown projects INSIDE the container at all ninety steps -- the rigid
## rotation preserves the framing, so "he leaves the frame" bounds
## nothing -- and the addressable fraction falls off smoothly (93.3 % at
## rest, 80.0 at -12, 66.7 at -22, 40.0 at -40) with no cliff to put a
## bound on. So each bound is anchored on a PROPERTY that can be
## re-measured and gated, not on a number read off a graph:
##
##   LOW, -23.0 deg (elevation 17.4951). Two things hold there and stop
##   holding below it. The camera keeps 3.5183 u of clearance over the
##   surface -- more than TWICE Keepy's 1.7 u crown, so the lens never
##   descends into the grass layer the scatter plants (clearance reaches
##   the crown at about -32 and the ground itself at -40.5). And the
##   camera's OWN pitch is still 11.0 deg DOWNWARD: it reaches level at
##   -34.0, which is the angle past which the picture is mostly sky and
##   a tap means nothing over most of it. 60.0 % of the screen still
##   resolves to a ground point there, against 93.3 % at rest.
##
##   HIGH, +43.0 deg (elevation 83.4951). The hard limit is the ZENITH
##   at +49.4951, where the offset's HORIZONTAL component is zero -- and
##   a yaw is a rotation about the vertical axis, so at the zenith a
##   yaw drag moves the camera NOWHERE and the player is left holding a
##   dead control with nothing to tell him why. The bound keeps
##   1.3249 u of horizontal radius (11.7034 * cos 83.4951), so a yaw
##   still visibly turns the view at the very top of the band.
##
## ⚠️ WHAT THE SWEEP ALSO REFUTED, and it was this lot's own suspicion:
## a camera tilted toward the horizon was expected to open the frustum
## the way the DRIVE pose does (DRIVE_FAR exists because the drive pose
## measured 123 515 primitives against 69 551 at the spawn). Measured
## here: 74 538 at the very bottom of the band against 71 764 at rest,
## +3.9 %. The haze and the scatter's `visibility_range_end` are already
## doing the work. `far` is NOT touched, and that is a measurement
## rather than an omission.
##
## ⚠️ AND ONE LIMIT IS STATED RATHER THAN FIXED: this camera has never
## collided with terrain and still does not. At rest it floats 7.6 u up
## and the question never arose; at the low bound it has 3.5183 u over
## FLAT ground, so over a steep enough rise it could clip. That is the
## fixed pose's own pre-existing property with a smaller margin, not a
## new class of defect, and closing it is a collision shape this lot was
## not asked for.
##
## The full sweep is in docs/lots/CH73_CAMERA_ORBITABLE.md. Both anchor
## properties are re-measured on the LIVE camera by OrbitCameraProbe
## PHASE B every run, so a future OFFSET or fov that moved them fails
## loudly here instead of shipping a frame nobody checked.
const ORBIT_PITCH_MIN: float = -0.401426  # -23.0 deg: elevation 17.4951
const ORBIT_PITCH_MAX: float = 0.750492   # +43.0 deg: elevation 83.4951

## How many radians of orbit one pixel of finger travel is worth. One
## number for both axes: a thumb does not know which way it is moving,
## and two gains would let the same gesture mean different amounts in
## two directions with nothing to report it.
##
## 0.005 rad/px is 0.2865 deg/px, so a 500 px drag across Mathieu's
## 1080-wide phone turns the camera 143 deg -- most of the way round in
## one comfortable thumb sweep, which is the gesture budget a one-handed
## player actually has. Published and gated (PHASE G reads the yaw a
## known pixel travel produced) rather than left as an unchecked feel
## knob.
const ORBIT_GAIN: float = 0.005

## The orbit, for a bench and for anyone who needs the pose's real
## shape. Yaw is wrapped to (-PI, PI]; pitch is the clamped offset on
## the resting elevation.
func orbit_yaw() -> float:
	return _orbit_yaw

func orbit_pitch() -> float:
	return _orbit_pitch

## True while the pose is exactly the one the scene authored -- the state
## every tree that has never been dragged is in, and the state PHASE I
## proves byte-identical to what shipped.
func orbit_is_rest() -> bool:
	return _orbit_yaw == 0.0 and _orbit_pitch == 0.0

## Turns the camera by a finger's travel, in RADIANS. The only writer of
## the orbit, and it CLAMPS rather than trusts -- `set_fair_lift`'s own
## discipline, for its reason: a bounded angle that takes whatever it is
## handed is not bounded.
##
## ⚠️ THIS FILE DOES NOT DECIDE WHEN IT MAY BE CALLED. Whether a finger
## on the glass is a look-around at all is a question about the GESTURE
## and about who else wants that finger, and it is answered where the
## finger arrives -- HubTapInput. Answering it twice is how two answers
## start to differ.
func orbit_by(d_yaw: float, d_pitch: float) -> void:
	if not is_finite(d_yaw) or not is_finite(d_pitch):
		return
	_orbit_yaw = wrapf(_orbit_yaw + d_yaw, -PI, PI)
	_orbit_pitch = clampf(_orbit_pitch + d_pitch, ORBIT_PITCH_MIN, ORBIT_PITCH_MAX)

## The rigid rotation the two angles describe. IDENTITY at rest, which is
## what makes every call site below inert on an untouched tree.
func _orbit_rotation() -> Basis:
	if _orbit_yaw == 0.0 and _orbit_pitch == 0.0:
		return Basis.IDENTITY
	return Basis(Vector3.UP, _orbit_yaw) * Basis(Vector3.RIGHT, -_orbit_pitch)

## The hub pose's basis AS THE PLAYER HAS LEFT IT.
##
## ⚠️ EVERY READER OF THE RESTING BASIS GOES THROUGH HERE, AND
## `_hub_basis` ITSELF IS STILL NEVER WRITTEN. The distinction is the one
## the ride and lift blocks above spell out: the orbit is a DERIVED read
## of an authored fact, not a mutation of it. A lot that stored the
## turned basis into `_hub_basis` would have no way back to the authored
## one, and `_on_drive_exited` restores from it.
func _hub_pose_basis() -> Basis:
	if _orbit_yaw == 0.0 and _orbit_pitch == 0.0:
		return _hub_basis
	return _orbit_rotation() * _hub_basis

## The resting OFFSET, turned the same way. Same identity at rest, same
## reason.
func _orbit_offset() -> Vector3:
	if _orbit_yaw == 0.0 and _orbit_pitch == 0.0:
		return OFFSET
	return _orbit_rotation() * OFFSET

## =====================================================================
## CH72 -- THE FUNFAIR: A LIFT ON THE FIXED POSE, AND A POV
##
## Two additions, and only one of them is a new POSE. Both are scoped to
## a funfair ride, which is a BOUNDED trip -- a tween that always ends at
## a known point -- and both are off, at zero, and arithmetically inert
## the rest of the time.
##
## ---------------------------------------------------------------------
## 1. THE LIFT, and why it is NOT D6
##
## CLAUDE.md: "c'est la CAMERA qui plafonne un ride vertical, pas la
## geometrie [...] la reponse a 'je veux plus haut que ca' reste une
## camera qui monte, c'est-a-dire un autre lot". CH72 is that lot, and
## the door it opens is the NARROWEST one: a bounded vertical OFFSET
## added to the TARGET of the hub pose's own lerp.
##
## It is CH62's ride-mode shape exactly, and it fails every test for a
## chase camera: it does not yaw, it does not look_at, it does not lag a
## heading, it does not touch `far`, and `_hub_basis` is never written.
## The horizon cannot bounce, which is the reason the hub pose is fixed
## in the first place.
##
## ⚠️ AN OFFSET, NOT A SHADOW VARIABLE -- the discipline the ride block
## above spells out and that a lot once broke. The lift is added to
## `_wanted()`, inside the same `global_position.lerp(...)` the hub has
## always had, so an outside writer (CabinProbe parks this camera by
## hand) is still an outside writer.
##
## ⚠️ AND IT IS THE LERP, NOT A SNAP. The gondola falls at 14.1 u/s and
## the follow's time constant is 1 / FOLLOW_LAMBDA = 0.2 s, so the camera
## trails the rider by about v / lambda -- he slides DOWN the frame as
## the drop starts and the camera catches him up. FunfairProbe measures
## the worst excursion and requires the crown to stay in frame; it is not
## assumed to be small.
##
## Ch72Recon R3 is what made the lift worth writing: lift the camera and
## the rider by the SAME dy and the crown lands on screen pixel
## (270, 121) at dy = 0, 3, 6, 10 and 14 -- the framing is invariant, so
## height costs the picture nothing.
const FAIR_LIFT_MAX: float = 20.0

var _fair_lift: float = 0.0

## How far above the resting pose the camera is riding. Zero unless a
## funfair ride is lifting it.
func fair_lift() -> float:
	return _fair_lift

## The resting fov, captured at _ready. Published so a bench can check
## that a mode gave it back EXACTLY, which is the one thing about fov
## that a probe of the mode itself would never look at.
func hub_fov() -> float:
	return _hub_fov

## Asked every frame by the ride that is lifting, and asked with 0.0 the
## moment it stops. CLAMPED here rather than trusted: a bounded offset
## that takes whatever it is handed is not bounded.
func set_fair_lift(y: float) -> void:
	_fair_lift = clampf(y, 0.0, FAIR_LIFT_MAX)

func _fair_offset() -> Vector3:
	return Vector3(0.0, _fair_lift, 0.0) if _fair_lift > 0.0 else Vector3.ZERO

## ---------------------------------------------------------------------
## 2. THE POV, and it IS a new exception to the camera doctrine
##
## CLAUDE.md's table reads: pilots continuously -> chase; walks -> fixed;
## RIDE ON A FIXED TRAJECTORY -> fixed. The funfair is the third row, and
## this is a second camera for that row, entered and left BY THE PLAYER
## with a tap. The criterion the table is built on -- "le joueur choisit
## la direction frame par frame" -- is still false here and the default
## is still the fixed pose: what the tap buys is a point of VIEW on a
## trajectory the rider does not steer. The exception is written up in
## CLAUDE.md; it is not left implicit in this file.
##
## THE POSE IS THE HEAD AND NOTHING ELSE: `KeepyHopper.head_anchor()`,
## whose position and yaw a carrier writes for free. So the POV looks
## where the cart goes without this file knowing a coaster exists.
##
## ⚠️ YAW ONLY, REBUILT HERE. The anchor hangs off Keepy's yaw node and
## carries no pitch and no roll today, and this function does not trust
## that: the horizon is reconstructed from the heading alone, so no
## future writer on that node can tilt the picture. A rolling POV is how
## a ride becomes nausea, and CH64 already paid for motion sickness once.
## The only pitch is the ONE the ride authors and hands in -- level on
## the coaster, tipped down on the tower so the top of it shows the hub
## rather than the sky.
##
## ⚠️ WHAT THIS FILE CANNOT SIGN: whether any of it is comfortable.
## CLAUDE.md CH62 -- a bench does not judge a game feel. The fov below is
## a starting point between the hub's 45 and the board's 56, chosen wide
## enough to read as eyes and narrow enough not to bow the edges; it is
## Mathieu's to move on device.
const POV_FOV: float = 58.0
const POV_BLEND_S: float = 0.45
const POV_PITCH_MAX_DEG: float = 45.0

var _pov_head: Node3D = null
var _pov_pitch: float = 0.0
var _pov_blend: float = 0.0
var _pov_tween: Tween = null

func is_pov() -> bool:
	return _pov_head != null

func pov_blend() -> float:
	return _pov_blend

## Enters the POV on `head`, pitched `pitch_deg` below the horizon.
func enter_pov(head: Node3D, pitch_deg: float = 0.0) -> void:
	if head == null or not is_instance_valid(head):
		return
	_pov_head = head
	_pov_pitch = clampf(pitch_deg, -POV_PITCH_MAX_DEG, POV_PITCH_MAX_DEG)
	_tween_pov(1.0)

func exit_pov() -> void:
	if _pov_head == null:
		return
	_tween_pov(0.0)

func _tween_pov(to: float) -> void:
	if _pov_tween and _pov_tween.is_valid():
		_pov_tween.kill()
	_pov_tween = create_tween()
	_pov_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pov_tween.tween_property(self, "_pov_blend", to, POV_BLEND_S)
	if to <= 0.0:
		_pov_tween.finished.connect(_on_pov_exited, CONNECT_ONE_SHOT)

## The exit restores the hub fov EXACTLY from the value captured in
## `_ready()` -- `_on_drive_exited`'s discipline, for its reason: a fov
## left a hair off is a permanent change to every frame afterwards and no
## probe of this mode would ever look at it.
func _on_pov_exited() -> void:
	_pov_head = null
	_pov_pitch = 0.0
	_pov_blend = 0.0
	fov = _hub_fov

func _pov_wanted() -> Transform3D:
	var head: Transform3D = _pov_head.global_transform
	var fwd: Vector3 = head.basis.z
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	if flat.length_squared() < 0.000001:
		flat = Vector3.BACK
	flat = flat.normalized()
	# A camera looks down its own -Z and Keepy's model faces +Z, so the
	# aim point is his position PLUS his facing: the POV looks where he
	# looks. The pitch is applied to the AIM, which keeps the up vector
	# vertical and therefore the roll at exactly zero.
	var aim: Vector3 = head.origin + flat - Vector3.UP * tan(deg_to_rad(_pov_pitch))
	return Transform3D(Basis.IDENTITY, head.origin).looking_at(aim, Vector3.UP)

## Turns the live basis toward the orbit the player has asked for, at the
## SAME weight the position is lerped at.
##
## ⚠️ THE TWO HALVES LAG TOGETHER OR THE RIG IS NOT RIGID. The position
## swings around Keepy with a 0.2 s time constant (FOLLOW_LAMBDA); a
## basis that snapped instead would aim the camera where it is going to
## be rather than where it is, and Keepy would slide out of frame during
## a fast drag and come back after it. Same weight, same lag, same shape.
##
## ⚠️ AND IT IS A NO-OP AT REST -- not "nearly" one. With the orbit at
## its authored zero nothing below the first line executes, so the basis
## is never written on a tree where nobody has dragged and cannot drift
## through a slerp round-trip over a long session. `_apply_pov`'s own
## guard, for the same reason.
func _apply_orbit(weight: float) -> void:
	if orbit_is_rest():
		return
	global_transform.basis = global_transform.basis.slerp(_hub_pose_basis(), weight)

## Blends the POV over whatever the hub branch has just written. A NO-OP
## while none is running -- not "nearly" one: with `_pov_head` null and
## `_pov_blend` 0 nothing below the first line executes, and `fov` in
## particular is not written, which is what keeps the plain hub frame
## byte-identical to what shipped.
func _apply_pov() -> void:
	if _pov_head == null and _pov_blend <= 0.0:
		return
	if _pov_head != null and not is_instance_valid(_pov_head):
		_on_pov_exited()
		return
	if _pov_blend <= 0.0:
		return
	var hub_xform := Transform3D(_hub_pose_basis(), global_position)
	global_transform = hub_xform.interpolate_with(_pov_wanted(), _pov_blend)
	# The base is RECOMPUTED, never read back off `fov`: lerping the
	# live value toward POV_FOV every frame would creep it all the way
	# there at any blend, instead of holding the blend it was given.
	var base_fov: float = _hub_fov + SkateFeel.fov_gain(_ride_rush) * _ride_blend
	fov = lerpf(base_fov, POV_FOV, _pov_blend)

## Puts the camera at its resting offset IMMEDIATELY, with no smoothing.
##
## ⚠️ PUBLIC BECAUSE _ready() IS TOO EARLY FOR ONE CALLER. Children are
## readied before their parent, so this node snaps to wherever Keepy is
## authored in the scene -- the origin -- and HubWorld._ready() only moves
## him afterwards, when he is coming back to a door rather than to the
## spawn. Without a second snap the camera would spend its first seconds
## sliding across the plateau from the origin to where the player actually
## is, which reads as the screen catching up rather than as a return.
##
## Nothing else may call this per frame: the smoothing in _process is the
## whole reason the horizon does not jump, and a snap is a cut.
func snap_to_target() -> void:
	if target == null:
		return
	_hub_position = _wanted()
	if _drive_target == null:
		global_position = _hub_position
		# CH73: a snap is a snap for BOTH halves of a rigid rig. Guarded
		# on the orbit being off its rest, so a tree where nobody has
		# dragged never writes the basis at all.
		if not orbit_is_rest():
			global_transform.basis = _hub_pose_basis()

## ⚠️ OUTSIDE THE KART, `global_position` ITSELF is what is smoothed --
## the two lines the hub has always had -- and `_hub_position` merely
## mirrors it. The first version smoothed a private `_hub_position` and
## copied it out, which is the same motion EXCEPT for anyone who writes
## `global_position` from outside: CabinProbe does (it parks the camera
## over the doorstep and lets the follow hold it there), and with the
## shadow variable the follow dragged the camera back from where the
## probe had put it. Five taps projected off the container and every one
## read as an empty signal -- a regression against the pre-lot baseline,
## caught only by running the same probe on both trees. Hors conduite,
## this function is byte-identical in effect to what shipped.
func _process(delta: float) -> void:
	if target == null:
		return
	var weight: float = 1.0 - exp(-FOLLOW_LAMBDA * delta)
	if _drive_target == null:
		# CH62: the ride mode, and it is INSIDE the hub branch on purpose
		# -- it is an OFFSET added to the hub pose, never a second pose.
		# With no ride running `_ride_board` is null and `_ride_blend` is
		# 0.0, so the two lines under it are byte-identical to what has
		# always shipped, and nothing here writes `fov` at all.
		if _ride_board != null or _ride_blend > 0.0:
			_ride_advance(delta)
			# CH72: `_fair_offset()` is Vector3.ZERO unless a funfair ride
			# is lifting, so this line is the shipped one while none is.
			global_position = global_position.lerp(_wanted() + _ride_offset() + _fair_offset(), weight)
			_hub_position = global_position
			fov = _hub_fov + SkateFeel.fov_gain(_ride_rush) * _ride_blend
			_apply_orbit(weight)
			_apply_pov()
			return
		global_position = global_position.lerp(_wanted() + _fair_offset(), weight)
		_hub_position = global_position
		_apply_orbit(weight)
		_apply_pov()
		return
	# ⚠️ CH63 LOT 2: the ride READING is advanced in this branch too, and
	# its POSE is not. See the ride block's header: `rush` is what
	# SkateStreaks draws from, and the board now enters BOTH modes -- the
	# drive for the pose, the ride for the reading. Nothing below adds
	# `_ride_offset()`, which is what makes "the three pose terms are
	# inert under a drive" a fact about this function rather than a claim.
	if _ride_board != null or _ride_blend > 0.0:
		_ride_advance(delta)
	_hub_position = _hub_position.lerp(_wanted(), weight)
	if not is_instance_valid(_drive_target):
		_on_drive_exited()
		return
	var kart: Node3D = _drive_target
	if _tuning.is_plain():
		# The three vehicles: the line that shipped, untouched.
		_drive_heading = lerp_angle(_drive_heading, kart.rotation.y, 1.0 - exp(-_tuning.heading_lambda * delta))
	else:
		# CH64, the board: the same first-order lag on an error SHORTENED
		# by the deadzone, and the step capped at the yaw rate. Continuous
		# at the deadzone's edge (the error is shortened, not gated), and
		# incapable of overshoot (a first-order step never crosses its
		# target; a cap only makes it smaller).
		var err: float = wrapf(kart.rotation.y - _drive_heading, -PI, PI)
		var eff: float = signf(err) * maxf(absf(err) - _tuning.deadzone, 0.0)
		var step: float = eff * (1.0 - exp(-_tuning.heading_lambda * delta))
		var cap: float = _tuning.yaw_rate_max * delta
		_drive_heading = wrapf(_drive_heading + clampf(step, -cap, cap), -PI, PI)
	_drive_position = _drive_position.lerp(_drive_wanted(), 1.0 - exp(-_tuning.position_lambda * delta))
	var heading := Vector3(sin(_drive_heading), 0.0, cos(_drive_heading))
	var ahead: float = DRIVE_LOOK_AHEAD
	if not _tuning.is_plain():
		# CH64: a pose held inside the region (ChaseTuning.keep_inside)
		# can stand much nearer the board than DRIVE_BACK; aimed 5.5 u
		# past the board from 2.5 u behind it, the frame lost the board
		# off its bottom edge (measured: 0 board pixels at the park's
		# north rim). The look-ahead shrinks with the distance actually
		# held, so a near pose looks AT the board.
		var kart_ground: Vector3 = HubSurface.ground(kart.global_position)
		var held: float = Vector2(_drive_position.x - kart_ground.x, _drive_position.z - kart_ground.z).length()
		ahead = DRIVE_LOOK_AHEAD * clampf(held / DRIVE_BACK, 0.0, 1.0)
	# CH75: an airborne chase looks AT its body (the cart), never at the
	# ground under the mount it stands on.
	var look: Vector3 = HubSurface.ground(kart.global_position) + heading * ahead + Vector3(0.0, DRIVE_LOOK_UP, 0.0)
	if _tuning.airborne and _tuning.look_target != null and is_instance_valid(_tuning.look_target):
		look = _tuning.look_target.global_position + Vector3(0.0, DRIVE_LOOK_UP, 0.0)
	var drive_xform := Transform3D(Basis.IDENTITY, _drive_position).looking_at(look, Vector3.UP)
	if not _tuning.is_plain():
		# CH64: the cap, on the pose itself. The yaw of the finished
		# look-at is compared with last frame's and pulled back to the
		# cap; pitch and position are untouched, so the frame keeps its
		# height and its distance and only turns more slowly.
		var yaw_now: float = atan2(-drive_xform.basis.z.x, -drive_xform.basis.z.z)
		if _drive_yaw_valid:
			var step: float = angle_difference(_drive_yaw, yaw_now)
			var cap: float = _tuning.yaw_rate_max * delta
			if absf(step) > cap:
				var held: float = _drive_yaw + signf(step) * cap
				drive_xform.basis = drive_xform.basis.rotated(Vector3.UP, angle_difference(yaw_now, held))
				yaw_now = held
		_drive_yaw = yaw_now
		_drive_yaw_valid = true
	var hub_xform := Transform3D(_hub_pose_basis(), _hub_position)
	global_transform = hub_xform.interpolate_with(drive_xform, _blend)
	fov = lerpf(_hub_fov, _tuning.fov, _blend)

func _wanted() -> Vector3:
	# The ground UNDER him, not sea level under him: the frame holds its
	# shape over relief because the offset is measured from the surface.
	var ground := HubSurface.ground(target.global_position)
	# CH73: `_orbit_offset()` IS `OFFSET` until a finger has turned the
	# camera, so this line is byte-identical to the shipped one on any
	# tree where nobody has dragged -- and the rotation is rigid, so the
	# distance it returns is 11.7034 u whatever the player has done.
	return ground + _orbit_offset()
