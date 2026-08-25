extends Node
## Dev-only: the geometry of the &"stream" entry in resources/hub/hub_layout.tres,
## measured against the hop chain that covers the same two endpoints.
##
## =====================================================================
## WHAT THIS FILE IS NOT
##
## It asserts nothing and never fails on purpose. Every gated file in this
## folder is a CONTRACT -- a number a future change must not cross. This one
## is a MEASUREMENT, taken to answer one open question: can a rideable stream
## be a SHORTCUT, or only a passive way to travel? Nothing here says which,
## it only prints the numbers that decide it.
##
## PERMANENT rather than throwaway, for the reason HubPerfBaseline gives: a
## reference measurement that cannot be re-run identically later is not a
## reference, it is an anecdote from one session. Being permanent costs the
## shipped game nothing -- export_presets.cfg's exclude_filter carries
## scripts/dev/* so nothing in this folder is packed.
##
## =====================================================================
## THE CONTROL POLYLINE IS NOT THE PATH A RIDER WOULD TRAVEL
##
## The layout entry holds 12 CONTROL POINTS. HubBuilder does not draw them:
## it runs them through _centripetal() (centripetal Catmull-Rom, alpha 0.5)
## at STREAM_SAMPLES_PER_SPAN samples per span and ribbons the result. The
## spline BULGES outside the chords of a polyline through the same points,
## so its arc length is the LONGER of the two, and it is the one a rider
## would actually cover.
##
## Both are therefore printed. The polyline is what the layout file states;
## the spine is what the game builds. The ride-speed answer below is
## computed from the SPINE, because using the shorter number would quote a
## minimum speed the real geometry cannot honour.
##
## The spline sampler here is a transcription of HubBuilder._centripetal().
## That is a fixture that can diverge from the code it mirrors -- the exact
## trap this repo has paid for once already -- so the probe does not trust
## it: PHASE B rebuilds scenes/HubWorld.tscn for real and reads the vertices
## of the ArrayMesh that ships, then checks the transcription against them.
##
## =====================================================================
## WHY THE HOP TIME IS QUANTISED AND NOT hops * HOP_DURATION
##
## A hop is one Tween over HOP_DURATION, and a Tween ends on a FRAME
## boundary. At 60 fps 0.28s is 16.8 frames, so the tween finishes on frame
## 17 and a hop really occupies 17/60 = 0.2833s. Every hop chain therefore
## costs ~1.19% more than the nominal multiplication. Both are printed; the
## quantised one is the one that matches a stopwatch.
const _LAYOUT_PATH: String = "res://resources/hub/hub_layout.tres"
const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

## The frame rate the hop chain is quantised against. Matches the
## `--fixed-fps 60` every timed probe in this folder is invoked with.
const _FPS: float = 60.0

## Radius around each stream endpoint that a prop is reported within.
const _ENDPOINT_NEIGHBOUR_RADIUS: float = 3.0

func _ready() -> void:
	# Armed first, before anything that could itself hang -- see
	# ProbeWatchdog.gd. arm() covers the frame-driven half (PHASE B waits on
	# frames); the deadline covers the blocking half, where no frame exists
	# for an armed watchdog to run in. Both, because this probe has both
	# shapes.
	ProbeWatchdog.arm(self, "STREAM GEOMETRY PROBE")
	var dl := ProbeWatchdog.deadline("STREAM GEOMETRY PROBE")

	print("=== STREAM GEOMETRY PROBE ===")
	print("reference measurement, not a contract -- nothing here is gated")
	print("")

	var layout: HubLayout = load(_LAYOUT_PATH) as HubLayout
	if layout == null:
		push_error("StreamGeometryProbe: %s did not load as a HubLayout." % _LAYOUT_PATH)
		get_tree().quit(1)
		return

	var stream: Dictionary = {}
	var others: Array[Dictionary] = []
	for entry in layout.props:
		if entry.get("type", &"") == &"stream":
			stream = entry
		else:
			others.append(entry)
	if stream.is_empty():
		push_error("StreamGeometryProbe: no &\"stream\" entry in the layout.")
		get_tree().quit(1)
		return

	var trace: Array[Vector3] = []
	for value in stream.get("points", []):
		if value is Vector3:
			trace.append(value)
	var width: float = stream.get("width", 0.0)

	_phase_a(trace, width, dl)
	await _phase_b(trace, width)
	_phase_c(trace, dl)
	_phase_d(trace, others, dl)

	print("")
	print("=== END STREAM GEOMETRY PROBE ===")
	get_tree().quit(0)

## ---------------------------------------------------------------------
## PHASE A -- the layout entry, read straight off the resource.
func _phase_a(trace: Array[Vector3], width: float, dl: ProbeDeadline) -> void:
	print("--- PHASE A: the layout entry, read from the .tres ---")
	print("  control points read WITHOUT building any mesh : %d" % trace.size())
	print("  width field                                    : %.4f" % width)
	print("  ribbon HALF-WIDTH as used at construction      : %.4f" % (width * 0.5))
	print("  HubBuilder.STREAM_WIDTH (default, unused here) : %.4f" % HubBuilder.STREAM_WIDTH)
	print("  HubBuilder.STREAM_SAMPLES_PER_SPAN             : %d" % HubBuilder.STREAM_SAMPLES_PER_SPAN)
	print("  HubBuilder.STREAM_SURFACE_Y                    : %.4f" % HubBuilder.STREAM_SURFACE_Y)
	print("")

	var head: Vector3 = trace[0]
	var tail: Vector3 = trace[trace.size() - 1]
	print("  endpoint HEAD (world) : (%.4f, %.4f, %.4f)" % [head.x, head.y, head.z])
	print("  endpoint TAIL (world) : (%.4f, %.4f, %.4f)" % [tail.x, tail.y, tail.z])
	print("")

	var polyline_len: float = _arc_length(trace, dl)
	var chord: float = Vector3(head.x, 0.0, head.z).distance_to(Vector3(tail.x, 0.0, tail.z))
	print("-- control polyline (the 12 points joined by straight segments) --")
	print("  L_arc   (sum of the 11 segments) : %.4f u" % polyline_len)
	print("  L_corde (point[0] -> point[11])  : %.4f u" % chord)
	print("  ratio   (L_arc / L_corde)        : %.6f" % (polyline_len / chord))
	var poly_curv := _min_curvature_radius(trace, dl)
	print("  minimum radius of curvature      : %.4f u (at index %d)" % [
		poly_curv["radius"], poly_curv["index"]])
	print("  half-width for comparison        : %.4f u" % (width * 0.5))
	print("")

## ---------------------------------------------------------------------
## PHASE B -- the spine the game actually builds, plus the check that this
## file's transcription of _centripetal() has not drifted from it.
func _phase_b(trace: Array[Vector3], width: float) -> void:
	print("--- PHASE B: the spline HubBuilder actually ribbons ---")
	var spine: Array[Vector3] = _centripetal(trace, HubBuilder.STREAM_SAMPLES_PER_SPAN)
	print("  samples on the spine : %d" % spine.size())

	var spine_len: float = _arc_length(spine, null)
	var head: Vector3 = spine[0]
	var tail: Vector3 = spine[spine.size() - 1]
	var chord: float = Vector3(head.x, 0.0, head.z).distance_to(Vector3(tail.x, 0.0, tail.z))
	print("  L_arc   (spine)  : %.4f u" % spine_len)
	print("  L_corde (spine)  : %.4f u" % chord)
	print("  ratio            : %.6f" % (spine_len / chord))
	var spine_curv := _min_curvature_radius(spine, null)
	print("  minimum radius of curvature : %.4f u (%.2fx the half-width %.3f)" % [
		spine_curv["radius"], spine_curv["radius"] / (width * 0.5), width * 0.5])
	print("")

	# The transcription check. A hand-copied spline that quietly disagrees
	# with the shipped one would make every number above look measured and
	# be wrong, so it is confronted with the real mesh rather than trusted.
	var hub := (preload(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame

	var built := _find_stream_mesh(hub)
	if built == null:
		print("  !! the built stream mesh was not found -- transcription UNCHECKED")
		hub.queue_free()
		print("")
		return

	var verts: PackedVector3Array = built.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Six vertices per quad, and the first two of each quad are the left and
	# right edge at that sample -- so their midpoint is spine[i]. The last
	# sample is only reachable from the tail of the final quad.
	var quads: int = verts.size() / 6
	var rebuilt: Array[Vector3] = []
	for q in quads:
		rebuilt.append((verts[q * 6] + verts[q * 6 + 1]) * 0.5)
	rebuilt.append((verts[verts.size() - 1] + verts[verts.size() - 2]) * 0.5)

	print("  built mesh : %d vertices, %d triangles, %d quads" % [
		verts.size(), verts.size() / 3, quads])
	if rebuilt.size() != spine.size():
		print("  !! sample count differs: transcription %d, built %d" % [
			spine.size(), rebuilt.size()])
	else:
		var worst: float = 0.0
		for i in spine.size():
			var flat_a := Vector3(spine[i].x, 0.0, spine[i].z)
			var flat_b := Vector3(rebuilt[i].x, 0.0, rebuilt[i].z)
			worst = maxf(worst, flat_a.distance_to(flat_b))
		print("  transcription vs built spine, worst deviation : %.9f u" % worst)
	print("  built ribbon arc length (from the mesh) : %.4f u" % _arc_length(rebuilt, null))
	hub.queue_free()
	print("")

## ---------------------------------------------------------------------
## PHASE C -- the hop chain over the same two endpoints, and the ride speed
## that would have to beat it.
func _phase_c(trace: Array[Vector3], dl: ProbeDeadline) -> void:
	print("--- PHASE C: the equivalent hop chain, and the speed to beat it ---")
	print("  KeepyHopper.HOP_DISTANCE   : %.4f u" % KeepyHopper.HOP_DISTANCE)
	print("  KeepyHopper.HOP_DURATION   : %.4f s" % KeepyHopper.HOP_DURATION)
	print("  KeepyHopper.ARRIVE_EPSILON : %.4f u" % KeepyHopper.ARRIVE_EPSILON)

	var head: Vector3 = Vector3(trace[0].x, 0.0, trace[0].z)
	var tail: Vector3 = Vector3(trace[trace.size() - 1].x, 0.0, trace[trace.size() - 1].z)
	var straight: float = head.distance_to(tail)

	# Counted by walking _advance()'s own rule rather than a closed form:
	# it steps min(HOP_DISTANCE, remaining) and stops once the remainder is
	# within ARRIVE_EPSILON, and a formula that agrees with that today can
	# stop agreeing after one edit to the hopper.
	var hops: int = 0
	var remaining: float = straight
	while remaining > KeepyHopper.ARRIVE_EPSILON:
		if dl != null and dl.abort_if_exceeded(get_tree()):
			return
		remaining -= minf(KeepyHopper.HOP_DISTANCE, remaining)
		hops += 1

	var frames_per_hop: int = int(ceil(KeepyHopper.HOP_DURATION * _FPS))
	var nominal_s: float = float(hops) * KeepyHopper.HOP_DURATION
	var quantised_s: float = float(hops * frames_per_hop) / _FPS
	print("  straight-line endpoint to endpoint : %.4f u" % straight)
	print("  hops in the chain                  : %d" % hops)
	print("  frames per hop at %.0f fps          : %d (%.4f s)" % [
		_FPS, frames_per_hop, float(frames_per_hop) / _FPS])
	print("  hop time, NOMINAL   (hops * HOP_DURATION) : %.4f s" % nominal_s)
	print("  hop time, QUANTISED (what a stopwatch sees) : %.4f s" % quantised_s)
	print("")

	var spine_len: float = _arc_length(_centripetal(trace, HubBuilder.STREAM_SAMPLES_PER_SPAN), null)
	var poly_len: float = _arc_length(trace, null)
	print("-- minimum ride speed for the stream to be STRICTLY faster --")
	print("  (a ride covers the SPINE, not the chord: the water is where it is)")
	print("  vs QUANTISED hop time, on the spine    : > %.4f u/s" % (spine_len / quantised_s))
	print("  vs NOMINAL   hop time, on the spine    : > %.4f u/s" % (spine_len / nominal_s))
	print("  vs QUANTISED hop time, on the polyline : > %.4f u/s" % (poly_len / quantised_s))
	print("  for scale, ground speed of the hop chain : %.4f u/s" % (
		KeepyHopper.HOP_DISTANCE / (float(frames_per_hop) / _FPS)))
	print("")

## ---------------------------------------------------------------------
## PHASE D -- what stands near each end, i.e. what could block a boarding
## or landing spot.
func _phase_d(trace: Array[Vector3], others: Array[Dictionary], dl: ProbeDeadline) -> void:
	print("--- PHASE D: props within %.1f u of an endpoint ---" % _ENDPOINT_NEIGHBOUR_RADIUS)
	var ends: Array[Vector3] = [
		Vector3(trace[0].x, 0.0, trace[0].z),
		Vector3(trace[trace.size() - 1].x, 0.0, trace[trace.size() - 1].z),
	]
	var names: Array[String] = ["HEAD", "TAIL"]
	for e in ends.size():
		if dl != null and dl.abort_if_exceeded(get_tree()):
			return
		print("  %s (%.2f, %.2f):" % [names[e], ends[e].x, ends[e].z])
		var found: int = 0
		for entry in others:
			var pos: Vector3 = entry.get("position", Vector3.ZERO)
			var flat := Vector3(pos.x, 0.0, pos.z)
			var d: float = flat.distance_to(ends[e])
			if d > _ENDPOINT_NEIGHBOUR_RADIUS:
				continue
			found += 1
			print("      %-9s at (%7.2f, %7.2f)  d = %.4f u  scale %.2f" % [
				String(entry.get("type", &"?")), pos.x, pos.z, d,
				float(entry.get("scale", 1.0))])
		if found == 0:
			print("      (none)")
	print("")

## ---------------------------------------------------------------------
## Helpers.

## Length of a polyline, measured FLAT: y is a constant on the ribbon and a
## stray authored y must not be able to inflate a distance the rider would
## never travel.
func _arc_length(points: Array, dl: ProbeDeadline) -> float:
	var total: float = 0.0
	for i in points.size() - 1:
		if dl != null and dl.exceeded():
			return total
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		total += Vector3(a.x, 0.0, a.z).distance_to(Vector3(b.x, 0.0, b.z))
	return total

## Smallest circumradius over consecutive triples -- the tightest bend the
## path takes. A RIBBON WHOSE RADIUS OF CURVATURE DROPS BELOW ITS OWN
## HALF-WIDTH FOLDS: the inner edge crosses itself and the surface pinches.
## That failure is invisible to a clearance check, which was measured on
## this very trace once, so the number is printed next to the half-width
## rather than on its own.
func _min_curvature_radius(points: Array, dl: ProbeDeadline) -> Dictionary:
	var best: float = INF
	var at: int = -1
	for i in range(1, points.size() - 1):
		if dl != null and dl.exceeded():
			break
		var a := Vector3(points[i - 1].x, 0.0, points[i - 1].z)
		var b := Vector3(points[i].x, 0.0, points[i].z)
		var c := Vector3(points[i + 1].x, 0.0, points[i + 1].z)
		var ab: float = a.distance_to(b)
		var bc: float = b.distance_to(c)
		var ca: float = c.distance_to(a)
		# Twice the signed area of the triangle, in the ground plane.
		var cross: float = absf((b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x))
		if cross < 0.000001:
			continue  # collinear: infinite radius, nothing to report
		var radius: float = (ab * bc * ca) / (2.0 * cross)
		if radius < best:
			best = radius
			at = i
	return {"radius": best, "index": at}

## A transcription of HubBuilder._centripetal(). Checked against the shipped
## mesh in PHASE B rather than trusted -- see this file's header.
func _centripetal(points: Array[Vector3], per_span: int) -> Array[Vector3]:
	var padded: Array[Vector3] = []
	padded.append(points[0] * 2.0 - points[1])
	padded.append_array(points)
	padded.append(points[points.size() - 1] * 2.0 - points[points.size() - 2])

	var out: Array[Vector3] = []
	for i in padded.size() - 3:
		var p0: Vector3 = padded[i]
		var p1: Vector3 = padded[i + 1]
		var p2: Vector3 = padded[i + 2]
		var p3: Vector3 = padded[i + 3]
		var t0: float = 0.0
		var t1: float = t0 + sqrt(maxf(p0.distance_to(p1), 0.0001))
		var t2: float = t1 + sqrt(maxf(p1.distance_to(p2), 0.0001))
		var t3: float = t2 + sqrt(maxf(p2.distance_to(p3), 0.0001))
		var last: int = per_span - 1
		if i == padded.size() - 4:
			last = per_span
		for k in last + 1:
			var t: float = t1 + (t2 - t1) * float(k) / float(per_span)
			var a1: Vector3 = p0.lerp(p1, (t - t0) / (t1 - t0))
			var a2: Vector3 = p1.lerp(p2, (t - t1) / (t2 - t1))
			var a3: Vector3 = p2.lerp(p3, (t - t2) / (t3 - t2))
			var b1: Vector3 = a1.lerp(a2, (t - t0) / (t2 - t0))
			var b2: Vector3 = a2.lerp(a3, (t - t1) / (t3 - t1))
			out.append(b1.lerp(b2, (t - t1) / (t2 - t1)))
	return out

## The one MeshInstance3D under the built hub whose surface material is the
## stream's own colour. Found by MATERIAL and not by node order: the layout
## file decides how many props precede the stream, so an index would be a
## silent dependency on a data file this probe also reads.
func _find_stream_mesh(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		var mat := mi.get_surface_override_material(0)
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_color.is_equal_approx(
				HubBuilder.STREAM_WATER_COLOR):
			return mi
	for child in root.get_children():
		var found := _find_stream_mesh(child)
		if found != null:
			return found
	return null
