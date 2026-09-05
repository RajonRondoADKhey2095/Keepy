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

## Starts the chase on `kart` (a KartBody: forward() and global_position).
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
	return Vector3(at.x, 0.0, at.z) - heading * DRIVE_BACK + Vector3(0.0, DRIVE_UP, 0.0)

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
		global_position = global_position.lerp(_wanted(), weight)
		_hub_position = global_position
		return
	_hub_position = _hub_position.lerp(_wanted(), weight)
	if not is_instance_valid(_drive_target):
		_on_drive_exited()
		return
	var kart: Node3D = _drive_target
	_drive_heading = lerp_angle(_drive_heading, kart.rotation.y, 1.0 - exp(-DRIVE_HEADING_LAMBDA * delta))
	_drive_position = _drive_position.lerp(_drive_wanted(), 1.0 - exp(-DRIVE_POSITION_LAMBDA * delta))
	var heading := Vector3(sin(_drive_heading), 0.0, cos(_drive_heading))
	var look: Vector3 = Vector3(kart.global_position.x, 0.0, kart.global_position.z) + heading * DRIVE_LOOK_AHEAD + Vector3(0.0, DRIVE_LOOK_UP, 0.0)
	var drive_xform := Transform3D(Basis.IDENTITY, _drive_position).looking_at(look, Vector3.UP)
	var hub_xform := Transform3D(_hub_basis, _hub_position)
	global_transform = hub_xform.interpolate_with(drive_xform, _blend)
	fov = lerpf(_hub_fov, DRIVE_FOV, _blend)

func _wanted() -> Vector3:
	var ground := Vector3(target.global_position.x, 0.0, target.global_position.z)
	return ground + OFFSET
