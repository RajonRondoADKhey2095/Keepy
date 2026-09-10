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

var _hub_basis: Basis = Basis.IDENTITY
var _hub_fov: float = 45.0
var _hub_far: float = 4000.0
var _hub_position: Vector3 = Vector3.ZERO
var _drive_target: Node3D = null
var _drive_heading: float = 0.0
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

func drive_blend() -> float:
	return _blend

## Starts the chase on `kart` -- any Node3D whose `rotation.y` is its
## heading and whose `global_position` is where it is. CH63 LOT 2 added a
## fourth: the skateboard, which satisfies both (its facing is written
## from the commanded heading in `SkateBoardBody.drive()`).
func enter_drive(kart: Node3D) -> void:
	_drive_target = kart
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
	global_transform = Transform3D(_hub_basis, _hub_position)
	fov = _hub_fov
	far = _hub_far

func _drive_wanted() -> Vector3:
	if _drive_target == null or not is_instance_valid(_drive_target):
		return _hub_position
	var heading := Vector3(sin(_drive_heading), 0.0, cos(_drive_heading))
	var at: Vector3 = _drive_target.global_position
	return HubSurface.ground(at) - heading * DRIVE_BACK + Vector3(0.0, DRIVE_UP, 0.0)

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
## It runs ONLY while HubTransport is riding the CharacterBody3D board,
## which exists only under DevTools.physics_enabled(). Walking, the ball,
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
			global_position = global_position.lerp(_wanted() + _ride_offset(), weight)
			_hub_position = global_position
			fov = _hub_fov + SkateFeel.fov_gain(_ride_rush) * _ride_blend
			return
		global_position = global_position.lerp(_wanted(), weight)
		_hub_position = global_position
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
	_drive_heading = lerp_angle(_drive_heading, kart.rotation.y, 1.0 - exp(-DRIVE_HEADING_LAMBDA * delta))
	_drive_position = _drive_position.lerp(_drive_wanted(), 1.0 - exp(-DRIVE_POSITION_LAMBDA * delta))
	var heading := Vector3(sin(_drive_heading), 0.0, cos(_drive_heading))
	var look: Vector3 = HubSurface.ground(kart.global_position) + heading * DRIVE_LOOK_AHEAD + Vector3(0.0, DRIVE_LOOK_UP, 0.0)
	var drive_xform := Transform3D(Basis.IDENTITY, _drive_position).looking_at(look, Vector3.UP)
	var hub_xform := Transform3D(_hub_basis, _hub_position)
	global_transform = hub_xform.interpolate_with(drive_xform, _blend)
	fov = lerpf(_hub_fov, DRIVE_FOV, _blend)

func _wanted() -> Vector3:
	# The ground UNDER him, not sea level under him: the frame holds its
	# shape over relief because the offset is measured from the surface.
	var ground := HubSurface.ground(target.global_position)
	return ground + OFFSET
