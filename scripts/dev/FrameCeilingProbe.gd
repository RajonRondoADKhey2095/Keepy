extends Node
## CH36 -- the frame ceiling, RE-READ off the live camera, and the climb
## gate that hangs from it.
##
## =====================================================================
## WHY THIS FILE EXISTS
##
## HubTrees carried, for two lots, a ceiling written as a closed form:
## `y = 7.6 - 8.9 * tan(40.5 deg - 36.4 deg) = 6.96 u`. The 40.5 deg is
## atan(7.6 / 8.9) -- the pitch a camera would have if it LOOKED AT
## Keepy's ground point. HubCamera does not look at anything: its
## rotation is FIXED and authored in HubWorld.tscn, at 34.0 deg
## (asin(0.55919)). 34.0 is SMALLER than the vertical half-angle, so the
## top ray leaves the lens going UP and the sign of the whole term flips.
## The real ceiling is 7.968 u, and the formula was low by 1.008 u.
##
## Nothing caught it because nothing MEASURED it. So this probe never
## computes an angle: it asks the camera the scene actually ships, at the
## resolution the phone actually has, and bisects.
##
## =====================================================================
## THE TWO READINGS, AND WHY THERE ARE TWO
##
##   * unproject_position -- bisect the aplomb column on the sign of the
##     projected screen y. The ceiling is where it changes.
##   * project_position   -- take the ray through the TOP-CENTRE pixel,
##     intersect it with the aplomb column, read its y.
##
## They share the camera and nothing else: one goes world -> screen, the
## other screen -> world. A transcription error in either shows up as a
## disagreement, and CH36's own measurement put them within 1e-4.
##
## =====================================================================
## RUN IT HEADLESS -- and the assert that makes that safe
##
## Only transforms are read here, so this belongs in the headless half of
## CLAUDE.md's rule (under llvmpipe it would crawl for nothing). But the
## dummy driver reports a 0x0 viewport, which would make every unprojection
## garbage and every check pass by never running. PHASE 0 therefore FORCES
## the SubViewport to 1080x1920 -- with `stretch = false` on its container
## first, because a stretching container IGNORES an explicit size and only
## warns -- and ASSERTS the camera's own visible rect reads back 1080x1920.
## A degenerate rect fails loudly instead of passing for free.
##
## Exit 0 all green, 1 any red, ProbeWatchdog.EXIT_TIMEOUT = INCONCLUSIVE.

const VP_SIZE: Vector2i = Vector2i(1080, 1920)
## Bisection bracket for the aplomb column, in world units, and its
## iteration count: 12 u over 2^50 is far below any tolerance here.
##
## ⚠️ THE TOP OF THE BRACKET IS NOT FREE, and the first version of this
## file got it wrong. A camera pitched 34 deg DOWN has its own view plane
## slicing the vertical column: everything above y = 20.79 at the aplomb
## is BEHIND it, and unproject_position happily returns a large POSITIVE
## screen y for such a point (measured: y=60 reads 3839.2, y=30 reads
## 6923.8) -- the projection wraps through infinity. A bracket that
## reached up there read "same sign at both ends" and refused to bisect,
## which is the harmless failure; the dangerous one is a bracket that
## straddles the wrap and bisects onto it. Hence 12.0, which is above the
## ceiling (7.968) and well below the wrap, AND the explicit
## is_position_behind guard in _screen_y.
const BISECT_LO: float = 0.0
const BISECT_HI: float = 12.0
const BISECT_ITERS: int = 50
## How far the two independent readings may disagree, and how far the
## published constant may sit from what the camera says.
const AGREE_TOL: float = 1.0e-4
const PUBLISHED_TOL: float = 5.0e-3
## The gate the old (wrong) ceiling produced, kept ONLY to name which
## trees this lot re-admits. Never used as a threshold.
const OLD_SEAT_MAX_Y: float = 4.85

var _hub: Node = null
var _frames: int = 0
var _fails: int = 0

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract.
	ProbeWatchdog.arm(self, "FRAME CEILING PROBE", 300.0)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

## Screen y of a world point on the aplomb column, through the LIVE
## camera. NAN when the point is behind the lens: unproject_position does
## not say so on its own, it returns a wrapped POSITIVE number that looks
## exactly like "well below the top edge".
func _screen_y(cam: Camera3D, column: Vector3, y: float) -> float:
	var p := Vector3(column.x, y, column.z)
	if cam.is_position_behind(p):
		return NAN
	return cam.unproject_position(p).y

## Reading A -- bisect the column for the height whose projection lands on
## the top edge of the picture (screen y = 0). Returns INF if the bracket
## does not straddle it, which is the blind check: the sign MUST move.
func _ceiling_by_unproject(cam: Camera3D, column: Vector3) -> float:
	var at_lo: float = _screen_y(cam, column, BISECT_LO)
	var at_hi: float = _screen_y(cam, column, BISECT_HI)
	if is_nan(at_lo) or is_nan(at_hi):
		return INF
	if at_lo <= 0.0 or at_hi >= 0.0:
		return INF
	var lo: float = BISECT_LO
	var hi: float = BISECT_HI
	for _i in BISECT_ITERS:
		var mid: float = (lo + hi) * 0.5
		if _screen_y(cam, column, mid) < 0.0:
			hi = mid
		else:
			lo = mid
	return (lo + hi) * 0.5

## Reading B -- the ray through the top-centre pixel, met with the aplomb
## column. Independent of A: screen -> world, not world -> screen.
func _ceiling_by_project(cam: Camera3D, column: Vector3) -> float:
	var top := Vector2(float(VP_SIZE.x) * 0.5, 0.0)
	var p0: Vector3 = cam.project_position(top, 1.0)
	var p1: Vector3 = cam.project_position(top, 2.0)
	var dir: Vector3 = p1 - p0
	if absf(dir.z) < 1.0e-9:
		return INF
	var t: float = (column.z - p0.z) / dir.z
	return p0.y + t * dir.y

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 6:
		if _frames == 2:
			_force_viewport()
		return
	set_process(false)
	_run()

## PHASE 0 -- make the viewport real, or die trying.
func _force_viewport() -> void:
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	var vp := _hub.get_node("WorldViewport/SubViewport") as SubViewport
	box.stretch = false
	vp.size = VP_SIZE

func _run() -> void:
	var cam := _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	var keepy := _hub.get_node("WorldViewport/SubViewport/World/Keepy") as Node3D
	var trees := _hub.get_node("WorldViewport/SubViewport/World/Trees") as HubTrees

	print("=== FRAME CEILING PROBE (CH36) ===")
	print("-- PHASE 0: the viewport is real --")
	var rect: Vector2 = cam.get_viewport().get_visible_rect().size
	_check(rect == Vector2(VP_SIZE), "camera viewport reads %s (wanted %s)" % [rect, Vector2(VP_SIZE)])
	if rect != Vector2(VP_SIZE):
		print("ABORT: a degenerate viewport makes every reading below meaningless.")
		get_tree().quit(1)
		return
	print("   camera basis pitch: %.4f deg, fov %.1f, keep_aspect %d"
		% [rad_to_deg(asin(cam.global_transform.basis.z.y)), cam.fov, cam.keep_aspect])

	print("-- PHASE 1: the ceiling at Keepy's own aplomb --")
	var ground := Vector3(keepy.global_position.x, 0.0, keepy.global_position.z)
	_check(cam.global_position.distance_to(ground + HubCamera.OFFSET) < 1.0e-3,
		"camera sits exactly at Keepy's ground + OFFSET (%.5f u off)"
			% cam.global_position.distance_to(ground + HubCamera.OFFSET))
	var a: float = _ceiling_by_unproject(cam, ground)
	var b: float = _ceiling_by_project(cam, ground)
	_check(is_finite(a), "unproject bisection bracketed the top edge (screen y changed sign)")
	_check(is_finite(b), "project_position met the aplomb column")
	print("   unproject %.6f u   project %.6f u   published %.6f u"
		% [a, b, HubCamera.FRAME_TOP_AT_APLOMB])
	_check(is_finite(a) and is_finite(b) and absf(a - b) < AGREE_TOL,
		"the two readings agree within %f (%.7f)" % [AGREE_TOL, absf(a - b)])
	_check(is_finite(a) and absf(a - HubCamera.FRAME_TOP_AT_APLOMB) < PUBLISHED_TOL,
		"HubCamera.FRAME_TOP_AT_APLOMB matches the live camera within %f (%.6f)"
			% [PUBLISHED_TOL, absf(a - HubCamera.FRAME_TOP_AT_APLOMB)])

	print("-- PHASE 2: the ceiling does not depend on where he stands --")
	# The offset is constant, so it must not; measuring it rather than
	# assuming it is what lets PHASE 3 read one ceiling for 50-odd trees.
	for at in [Vector3(-12.0, 0.0, 9.0), Vector3(21.0, 0.0, -30.0), Vector3(3.0, 0.0, -97.0)]:
		keepy.global_position = at
		cam.snap_to_target()
		var c: float = _ceiling_by_unproject(cam, at)
		_check(is_finite(c) and absf(c - a) < PUBLISHED_TOL,
			"ceiling at (%.0f, %.0f) is %.6f u" % [at.x, at.z, c])

	print("-- PHASE 3: every climbable tree keeps his head in frame --")
	var admitted: Array = []
	var readmitted: Array = []
	for i in trees.count():
		var seat: float = trees.seat_height(i)
		var head: float = seat + HubTrees.HEAD_ABOVE_SEAT
		var pos: Vector3 = trees.position_of(i)
		# Re-read the ceiling at THIS tree's own column, on the real
		# camera parked where the player would park it.
		keepy.global_position = Vector3(pos.x, 0.0, pos.z)
		cam.snap_to_target()
		var ceil_here: float = _ceiling_by_unproject(cam, pos)
		var row := {"i": i, "at": pos, "seat": seat, "head": head, "ceiling": ceil_here,
			"perch": trees.is_perch(i)}
		admitted.append(row)
		if seat > OLD_SEAT_MAX_Y:
			readmitted.append(row)
		_check(is_finite(ceil_here) and head <= ceil_here,
			"tree %d at (%.1f, %.1f): seat %.3f + head %.1f = %.3f <= ceiling %.3f"
				% [i, pos.x, pos.z, seat, HubTrees.HEAD_ABOVE_SEAT, head, ceil_here])

	print("-- PHASE 4: the gate itself --")
	_check(absf(HubTrees.SEAT_MAX_Y - (HubCamera.FRAME_TOP_AT_APLOMB
		- HubTrees.HEAD_ABOVE_SEAT - HubTrees.FRAME_MARGIN)) < 1.0e-9,
		"SEAT_MAX_Y (%.4f) is derived from the ceiling, not retyped" % HubTrees.SEAT_MAX_Y)
	var worst: float = 0.0
	for row in admitted:
		worst = maxf(worst, float(row["head"]))
	print("   tallest admitted head: %.4f u -- %.4f u of picture left above it"
		% [worst, a - worst])
	_check(is_finite(a) and a - worst >= 0.0, "the tallest admitted head is inside the frame")
	# Anything still refused for its seat must be refused by the NEW gate.
	for e in trees.excluded():
		var why: String = str(e["why"])
		if not why.begins_with("seat "):
			continue
		var v: float = float(why.substr(5))
		_check(v < HubTrees.SEAT_MIN_Y or v > HubTrees.SEAT_MAX_Y,
			"still-excluded seat %.2f is outside [%.2f, %.4f]"
				% [v, HubTrees.SEAT_MIN_Y, HubTrees.SEAT_MAX_Y])

	print("-- THE LIST: trees this lot RE-ADMITS (seat > %.2f, the old gate) --" % OLD_SEAT_MAX_Y)
	if readmitted.is_empty():
		print("   (none -- no published tree has a seat between %.2f and %.4f)"
			% [OLD_SEAT_MAX_Y, HubTrees.SEAT_MAX_Y])
	for row in readmitted:
		var p: Vector3 = row["at"]
		print("   READMIT index %d  at (%.2f, %.2f)  seat %.3f  head %.3f  ceiling %.3f  perch %s"
			% [row["i"], p.x, p.z, row["seat"], row["head"], row["ceiling"], str(row["perch"])])
	print("   admitted total: %d  (re-admitted by CH36: %d)" % [admitted.size(), readmitted.size()])

	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
