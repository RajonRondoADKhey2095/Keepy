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

func _ready() -> void:
	target = get_node_or_null(target_path) as Node3D
	if target == null:
		push_error("HubCamera: target_path does not resolve to a Node3D.")
	else:
		snap_to_target()

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
	global_position = _wanted()

func _process(delta: float) -> void:
	if target == null:
		return
	var weight: float = 1.0 - exp(-FOLLOW_LAMBDA * delta)
	global_position = global_position.lerp(_wanted(), weight)

func _wanted() -> Vector3:
	var ground := Vector3(target.global_position.x, 0.0, target.global_position.z)
	return ground + OFFSET
