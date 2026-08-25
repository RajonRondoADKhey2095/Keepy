extends RefCounted
class_name HubStreamRoute
## The stream, as a thing a rider can travel along: an arc-length
## parameterisation of the spine HubBuilder actually ribboned.
##
## =====================================================================
## WHY THIS TAKES THE BUILT SPINE AND NEVER RE-DERIVES IT
##
## The layout entry holds 12 CONTROL points. What is drawn is the
## centripetal Catmull-Rom through them, sampled at
## HubBuilder.STREAM_SAMPLES_PER_SPAN, and the spline BULGES outside the
## chords of a polyline through the same points -- a rider following the
## control polyline would leave the water on every bend.
##
## Re-implementing _centripetal() here would be a second copy of the curve
## free to drift from the one on screen: exactly the "a fixture that
## diverges from the real thing on one axis does not protect you from that
## axis" trap this repo has already paid for once (SubstituteModel.tscn),
## and the trap StreamGeometryProbe goes out of its way to check itself
## against. So HubBuilder hands its OWN spine over (stream_spine()) and
## this class only measures it. There is one curve in the build, and the
## ride is on it.
##
## =====================================================================
## FLAT ON PURPOSE
##
## Every distance and projection here ignores y. The ribbon's y is a
## constant written by HubBuilder (STREAM_SURFACE_Y), never read from the
## trace, so a control point authored with a stray y cannot inflate an arc
## length the rider would never travel -- the same rule
## StreamGeometryProbe._arc_length() states for the same reason.

## Spine samples, flattened to y = 0, in build order.
var _points: PackedVector3Array = PackedVector3Array()

## Cumulative arc length at each sample. _cumulative[0] is always 0.0 and
## the last entry is the total, so a binary search over it turns an
## abscissa into a segment in log time.
var _cumulative: PackedFloat32Array = PackedFloat32Array()

## Builds a route from a spine. Anything shorter than two samples, or with
## no length at all, yields an EMPTY route -- is_valid() is false and every
## query is a safe no-op, rather than a divide-by-zero somewhere later on
## a screen every game is reached through.
func _init(spine: Array) -> void:
	if spine.size() < 2:
		return
	var flat := PackedVector3Array()
	for value in spine:
		if value is Vector3:
			var point: Vector3 = value
			flat.append(Vector3(point.x, 0.0, point.z))
	if flat.size() < 2:
		return
	var running := PackedFloat32Array()
	running.append(0.0)
	var total: float = 0.0
	for i in range(1, flat.size()):
		total += flat[i - 1].distance_to(flat[i])
		running.append(total)
	if total <= 0.0:
		return
	_points = flat
	_cumulative = running

func is_valid() -> bool:
	return _points.size() >= 2

## Total arc length, in world units. Zero for an invalid route.
func length() -> float:
	if not is_valid():
		return 0.0
	return _cumulative[_cumulative.size() - 1]

## The two ends, flattened. head() is abscissa 0, tail() is abscissa
## length(). Which one is "upstream" is not a question this class answers:
## the ride is bidirectional and takes its direction from where the player
## tapped, so neither end is privileged.
func head() -> Vector3:
	if not is_valid():
		return Vector3.ZERO
	return _points[0]

func tail() -> Vector3:
	if not is_valid():
		return Vector3.ZERO
	return _points[_points.size() - 1]

## World position at arc length `s`, clamped to the ends.
func point_at(s: float) -> Vector3:
	if not is_valid():
		return Vector3.ZERO
	var clamped: float = clampf(s, 0.0, length())
	var i: int = _segment_at(clamped)
	var span: float = _cumulative[i + 1] - _cumulative[i]
	if span <= 0.0:
		return _points[i]
	var t: float = (clamped - _cumulative[i]) / span
	return _points[i].lerp(_points[i + 1], t)

## Unit tangent at arc length `s`, pointing from head towards tail. Falls
## back to +Z on a degenerate segment so a caller can always build a basis.
func tangent_at(s: float) -> Vector3:
	if not is_valid():
		return Vector3(0.0, 0.0, 1.0)
	var i: int = _segment_at(clampf(s, 0.0, length()))
	var direction: Vector3 = _points[i + 1] - _points[i]
	if direction.length() < 0.000001:
		return Vector3(0.0, 0.0, 1.0)
	return direction.normalized()

## Arc length of the point on the spine nearest `point`, ignoring y.
##
## Walked segment by segment rather than sampled: the spine is 89 samples
## on the shipped layout, so the exact answer is cheap, and a sampled
## approximation would put the rider slightly off the water at exactly the
## bends where the ribbon has least room to spare.
func project(point: Vector3) -> float:
	if not is_valid():
		return 0.0
	var flat := Vector3(point.x, 0.0, point.z)
	var best_s: float = 0.0
	var best_d: float = INF
	for i in _points.size() - 1:
		var a: Vector3 = _points[i]
		var b: Vector3 = _points[i + 1]
		var span: Vector3 = b - a
		var span_len2: float = span.length_squared()
		var t: float = 0.0
		if span_len2 > 0.000001:
			t = clampf((flat - a).dot(span) / span_len2, 0.0, 1.0)
		var on: Vector3 = a + span * t
		var d: float = flat.distance_squared_to(on)
		if d < best_d:
			best_d = d
			best_s = _cumulative[i] + span.length() * t
	return best_s

## Distance from `point` to the nearest point of the spine, ignoring y.
func distance_to(point: Vector3) -> float:
	if not is_valid():
		return INF
	return point_at(project(point)).distance_to(Vector3(point.x, 0.0, point.z))

## Distance from `point` to the NEAREST END, ignoring y. The mooring rule
## is written in terms of the ends, not of the water, so it asks this.
func distance_to_nearest_end(point: Vector3) -> float:
	if not is_valid():
		return INF
	var flat := Vector3(point.x, 0.0, point.z)
	return minf(flat.distance_to(head()), flat.distance_to(tail()))

## The end nearest `point`: 0.0 for head, length() for tail. Returned as an
## ABSCISSA rather than a position so a caller can feed it straight back
## into point_at()/tangent_at() without a second lookup.
func nearest_end_abscissa(point: Vector3) -> float:
	if not is_valid():
		return 0.0
	var flat := Vector3(point.x, 0.0, point.z)
	if flat.distance_to(head()) <= flat.distance_to(tail()):
		return 0.0
	return length()

## Index of the segment containing arc length `s`. Binary search, so this
## stays cheap if the spine is ever sampled more finely.
func _segment_at(s: float) -> int:
	var low: int = 0
	var high: int = _cumulative.size() - 1
	while low < high - 1:
		var mid: int = (low + high) / 2
		if _cumulative[mid] <= s:
			low = mid
		else:
			high = mid
	return mini(low, _points.size() - 2)
