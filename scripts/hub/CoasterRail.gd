extends RefCounted
class_name CoasterRail
## CH75 -- THE RAIL ARITHMETIC THE FUNFAIR'S TWO COASTERS SHARE.
##
## CH71 wrote the closed Catmull-Rom loop, the SWEEP frame that lays the
## rails and the RIDE frame that poses a cart, inside HubFunfair for its
## one coaster. CH75 adds a second one (the Comet), and a second copy of
## "how a closed spline is baked and how a frame is read off it" would be
## two spellings of one fact -- the first time a lot moved a control point
## on one and not the other, the two rides would disagree on what a rail
## IS. So the arithmetic moved HERE, verbatim, as static functions over a
## Curve3D, and HubFunfair delegates to it. FunfairProbe PHASE A gates the
## CH71 loop's baked length (51.165 u) and crest (s 17.350, y 5.027) to
## the millimetre on both trees, which is what proves the move is a move.
##
## Every function is STATIC and pure over the curve it is handed: nothing
## here knows which ride it serves, and nothing here reads a node.

## Builds the CLOSED cardinal spline through `points` (in riding order;
## the last joins the first). `tension` 0.5 is Catmull-Rom.
static func build_curve(points: Array, tension: float, bake_interval: float) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = bake_interval
	var n: int = points.size()
	for i in n + 1:
		var k: int = i % n
		var prev: Vector3 = points[(k - 1 + n) % n]
		var next: Vector3 = points[(k + 1) % n]
		var handle: Vector3 = (next - prev) * tension * 0.5
		curve.add_point(points[k], -handle, handle)
	return curve

## The rail-top point at arc length `s`, wrapped onto the loop.
static func point_at(curve: Curve3D, s: float) -> Vector3:
	return curve.sample_baked(fposmod(s, curve.get_baked_length()), true)

static func tangent_at(curve: Curve3D, s: float) -> Vector3:
	var a: Vector3 = point_at(curve, s - 0.05)
	var b: Vector3 = point_at(curve, s + 0.05)
	return (b - a).normalized()

## The SWEEP frame at `s`: columns (right, up, forward), origin on the
## rail top. Lays rails and ties, and nothing else.
##
## ⚠️ MIRRORED (det = -1) -- NEVER A NODE TRANSFORM. `t.cross(UP)` is the
## LEFT of the direction of travel (CH72, measured and gated by
## FunfairProbe K0/K1). Harmless for a symmetric sweep; meaningless as a
## pose. Anything that RIDES the rail takes `ride_frame()`.
static func sweep_frame(curve: Curve3D, s: float) -> Transform3D:
	var p: Vector3 = point_at(curve, s)
	var t: Vector3 = tangent_at(curve, s)
	var right: Vector3 = t.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(t).normalized()
	return Transform3D(Basis(right, up, t), p)

## The pose of anything that RIDES the rail at `s`: origin on the rail
## top, **+Z along the direction of travel**, right-handed (X = Y x Z), so
## `global_rotation_degrees.y` decomposes to the tangent's bearing and a
## rider handed the carrier's yaw (KeepyHopper.follow_carrier) faces the
## way the cart goes. CH72 CHANGE 1, measured at 0.03 deg worst.
##
## The guard is what lets the Comet's drop run STEEP: UP x t degenerates
## only when t is dead vertical, and neither ride's steepest section is
## (CH71 37.6 deg, CH75 measured by CometProbe and gated under 85 deg).
static func ride_frame(curve: Curve3D, s: float) -> Transform3D:
	var t: Vector3 = tangent_at(curve, s)
	var right: Vector3 = Vector3.UP.cross(t)
	if right.length_squared() < 0.000001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up: Vector3 = t.cross(right).normalized()
	return Transform3D(Basis(right, up, t), point_at(curve, s))

## The steepest slope of the baked curve, in degrees from horizontal,
## sampled every `step` units. Published so a probe can gate that the
## ride frame is never asked for a vertical tangent.
static func steepest_deg(curve: Curve3D, step: float = 0.1) -> float:
	var worst: float = 0.0
	var s: float = 0.0
	var length: float = curve.get_baked_length()
	while s < length:
		var t: Vector3 = tangent_at(curve, s)
		var flat: float = Vector2(t.x, t.z).length()
		worst = maxf(worst, rad_to_deg(atan2(absf(t.y), flat)))
		s += step
	return worst

## The highest rail-top point and the arc length where it is reached,
## sampled every `step` units -- {"s": float, "y": float}.
static func crest(curve: Curve3D, step: float = 0.05) -> Dictionary:
	var best_y: float = -INF
	var best_s: float = 0.0
	var s: float = 0.0
	var length: float = curve.get_baked_length()
	while s < length:
		var p: Vector3 = point_at(curve, s)
		if p.y > best_y:
			best_y = p.y
			best_s = s
		s += step
	return {"s": best_s, "y": best_y}
