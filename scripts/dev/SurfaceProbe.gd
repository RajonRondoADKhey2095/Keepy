extends Node
## CH37 -- HubSurface: the accessor, and every ground y wired to it.
##
## =====================================================================
## WHY EVERY PHASE OPENS WITH A BLIND CHECK
##
## This probe asserts, over and over, that some y equals `height_at` of
## some point. With NO domain registered `height_at` is 0.0 everywhere --
## and that is exactly the shape the hub ships in CH37. So "y == h" would
## be "y == 0" written longer, and every assertion here would pass
## against an accessor that was never wired to anything.
##
## That failure mode is not hypothetical in this repo: three assertions
## once went green against a mechanism that had never been connected, and
## a coverage assertion passed by never running. So EVERY phase below
## prints `height_at(the point it is about to test)` and FAILS if it is
## zero, before it asserts anything. A red blind check means the phase
## proved nothing, and says so.
##
## =====================================================================
## RUN IT HEADLESS
##
## Only transforms are read: no pixel, no MultiMesh instance, no shader.
## Under llvmpipe this would crawl for nothing. But the dummy driver
## reports a 0x0 viewport, which would make project_ray_origin garbage
## and let phase B pass by never running -- so phase 0 FORCES the
## SubViewport to 1080x1920 (with `stretch = false` FIRST: a stretching
## container ignores an explicit size and only warns) and ASSERTS the
## camera's visible rect reads back 1080x1920.
##
## Exit 0 all green, 1 any red, ProbeWatchdog.EXIT_TIMEOUT = INCONCLUSIVE.

const VP_SIZE: Vector2i = Vector2i(1080, 1920)

## The test domain: a 20 x 20 u box centred on the spawn, sampled at
## 0.5 u, carrying a bump 3 u high.
##
## ⚠️ NOT A PLAIN GAUSSIAN. A gaussian never reaches zero, and the C0
## contract wants EXACTLY zero on the perimeter -- a hair of height there
## is a step, and the 0.45 u hop cannot tell a step from a slope. So the
## bump is a gaussian OFFSET and RESCALED to vanish at r = RADIUS and
## clamped to zero beyond it: h(0) = HEIGHT exactly, h(RADIUS) = 0
## exactly, and the box corners (r = 14.14) are flat.
const DOMAIN_HALF: float = 10.0
const DOMAIN_PITCH: float = 0.5
const BUMP_HEIGHT: float = 3.0
const BUMP_SIGMA: float = 3.0
const BUMP_RADIUS: float = 10.0
## Where the box sits. Clear of every CozyPalette band (autumn is at
## z = -39 +/- 7, the nearest) -- register_domain would refuse it
## otherwise, which is itself checked in phase A.
const DOMAIN_CENTRE: Vector2 = Vector2(0.0, 0.0)

const EPS_EXACT: float = 1.0e-6

var _hub: Node = null
var _fails: int = 0
## Phase C's landing tally -- members, never lambda captures.
var _land_count: int = 0
var _land_worst: float = 0.0
## Phase TAP's captured destination -- a member, for the lambda reason.
var _tapped: Vector3 = Vector3.INF
var _tap_seen: int = 0

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract.
	ProbeWatchdog.arm(self, "SURFACE PROBE", 600.0)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

## THE BLIND CHECK. Prints the height the phase is about to lean on and
## fails if it is zero -- an assertion about a flat world proves nothing
## about an accessor.
func _blind(at: Vector3, what: String) -> float:
	var h: float = HubSurface.height_at(at)
	_check(absf(h) > 1.0e-3,
		"BLIND %s: height_at(%.2f, %.2f) = %.4f (must not be 0)" % [what, at.x, at.z, h])
	return h

## The analytic bump. Only ever used to FILL the grid -- never consulted
## at query time, which is the point of the grid existing.
static func _bump(x: float, z: float) -> float:
	var r: float = Vector2(x - DOMAIN_CENTRE.x, z - DOMAIN_CENTRE.y).length()
	if r >= BUMP_RADIUS:
		return 0.0
	var s2: float = 2.0 * BUMP_SIGMA * BUMP_SIGMA
	var edge: float = exp(-BUMP_RADIUS * BUMP_RADIUS / s2)
	return BUMP_HEIGHT * (exp(-r * r / s2) - edge) / (1.0 - edge)

## Builds the test domain's spec. `shift` displaces the sampling lattice
## so the red-before-green pass can hand register_domain a grid whose
## perimeter is NOT flat.
static func _spec(name_of: StringName, centre: Vector2, shift: float) -> Dictionary:
	var n: int = int(round(2.0 * DOMAIN_HALF / DOMAIN_PITCH)) + 1
	var origin := Vector2(centre.x - DOMAIN_HALF, centre.y - DOMAIN_HALF)
	var grid := PackedFloat32Array()
	grid.resize(n * n)
	for r in n:
		for c in n:
			var x: float = origin.x + float(c) * DOMAIN_PITCH
			var z: float = origin.y + float(r) * DOMAIN_PITCH
			grid[r * n + c] = _bump(x, z) + shift
	return {
		"name": name_of, "origin": origin, "pitch": DOMAIN_PITCH,
		"cols": n, "rows": n, "grid": grid,
	}

func _process(_delta: float) -> void:
	set_process(false)
	_force_viewport()
	_run()

func _force_viewport() -> void:
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	var vp := _hub.get_node("WorldViewport/SubViewport") as SubViewport
	box.stretch = false
	vp.size = VP_SIZE

func _run() -> void:
	print("=== SURFACE PROBE -- CH37 lot 1 ===")
	HubSurface.clear_domains()
	_phase_a()
	_phase_b()
	# ⚠️ AWAITED, not called. A phase function that contains an await is a
	# COROUTINE: calling it bare would run it ALONGSIDE everything after
	# it, and this repo has already measured two phases trampling each
	# other that way.
	await _phase_c()
	await _phase_d()
	await _phase_tap()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

## PHASE A -- the accessor's own contract: what it samples, and what it
## refuses.
func _phase_a() -> void:
	print("-- PHASE A: register_domain, sampling, and the C0 raccord --")
	HubSurface.clear_domains()
	# The flat world FIRST, so "0.0 outside" below is a measured contrast
	# and not a restatement of the default.
	_check(HubSurface.height_at(Vector3(DOMAIN_CENTRE.x, 0.0, DOMAIN_CENTRE.y)) == 0.0,
		"with no domain, height_at at the future summit is exactly 0.0")
	_check(HubSurface.domain_at(Vector3.ZERO) == -1, "with no domain, domain_at is -1")

	var idx: int = HubSurface.register_domain(_spec(&"probe_bump", DOMAIN_CENTRE, 0.0))
	_check(idx == 0, "register_domain accepted the test bump (index %d)" % idx)
	if idx < 0:
		return

	var centre := Vector3(DOMAIN_CENTRE.x, 0.0, DOMAIN_CENTRE.y)
	var h_centre: float = _blind(centre, "summit")
	_check(absf(h_centre - BUMP_HEIGHT) < EPS_EXACT,
		"height_at(summit) = %.6f (want %.6f)" % [h_centre, BUMP_HEIGHT])
	_check(HubSurface.domain_at(centre) == 0, "domain_at(summit) = 0")
	# ground() is the single spelling -- and it must agree with height_at.
	var g: Vector3 = HubSurface.ground(centre)
	_check(g.x == centre.x and g.z == centre.z and g.y == h_centre,
		"ground(summit) = (%.2f, %.4f, %.2f), the same y height_at gave" % [g.x, g.y, g.z])

	# The C0 raccord, walked at 0.5 u on all four sides.
	var worst: float = 0.0
	var pts: int = 0
	var n: int = int(round(2.0 * DOMAIN_HALF / DOMAIN_PITCH)) + 1
	for i in n:
		var t: float = -DOMAIN_HALF + float(i) * DOMAIN_PITCH
		for p in [Vector3(DOMAIN_CENTRE.x + t, 0.0, DOMAIN_CENTRE.y - DOMAIN_HALF),
				Vector3(DOMAIN_CENTRE.x + t, 0.0, DOMAIN_CENTRE.y + DOMAIN_HALF),
				Vector3(DOMAIN_CENTRE.x - DOMAIN_HALF, 0.0, DOMAIN_CENTRE.y + t),
				Vector3(DOMAIN_CENTRE.x + DOMAIN_HALF, 0.0, DOMAIN_CENTRE.y + t)]:
			worst = maxf(worst, absf(HubSurface.height_at(p)))
			pts += 1
	_check(worst < 1.0e-4, "perimeter walked at %.1f u (%d points): worst |h| = %.8f"
		% [DOMAIN_PITCH, pts, worst])

	# Outside the AABB: EXACTLY zero, not nearly.
	var outside := Vector3(DOMAIN_CENTRE.x + DOMAIN_HALF + 3.0, 0.0, DOMAIN_CENTRE.y)
	_check(HubSurface.height_at(outside) == 0.0, "3 u outside the AABB: height_at is exactly 0.0")
	_check(HubSurface.domain_at(outside) == -1, "3 u outside the AABB: domain_at is -1")

	# The barycentric must return the node value AT a node -- that is what
	# says the query reads the lattice the mesh will be built from.
	var node_worst: float = 0.0
	for i in range(1, n - 1, 3):
		for j in range(1, n - 1, 3):
			var x: float = DOMAIN_CENTRE.x - DOMAIN_HALF + float(i) * DOMAIN_PITCH
			var z: float = DOMAIN_CENTRE.y - DOMAIN_HALF + float(j) * DOMAIN_PITCH
			node_worst = maxf(node_worst,
				absf(HubSurface.height_at(Vector3(x, 0.0, z)) - _bump(x, z)))
	_check(node_worst < 1.0e-5,
		"at grid nodes the barycentric returns the node value (worst %.8f)" % node_worst)

	# RED BEFORE GREEN, on the two refusals that are load-bearing.
	print("   (the two push_error lines below are the refusals being PROVEN, not failures)")
	var shifted: int = HubSurface.register_domain(_spec(&"probe_shifted", Vector2(60.0, 0.0), 0.01))
	_check(shifted == -1, "a lattice shifted by +0.01 breaks C0 and is REFUSED")
	var overlap: int = HubSurface.register_domain(_spec(&"probe_overlap", DOMAIN_CENTRE, 0.0))
	_check(overlap == -1, "an AABB overlapping a registered one is REFUSED")
	var f64 := _spec(&"probe_f64", Vector2(60.0, 0.0), 0.0)
	var wide := PackedFloat64Array()
	for v in (f64["grid"] as PackedFloat32Array):
		wide.append(float(v))
	f64["grid"] = wide
	_check(HubSurface.register_domain(f64) == -1, "a float64 grid is REFUSED")
	var band := _spec(&"probe_band", Vector2(0.0, CozyPalette.AUTUMN_EDGE_Z), 0.0)
	_check(HubSurface.register_domain(band) == -1,
		"an AABB crossing the autumn band is REFUSED")
	_check(HubSurface.domains().size() == 1, "after four refusals the table still holds 1 domain")

## PHASE B -- intersect_ray: identical to the plane when flat, and
## demonstrably NOT the plane when there is relief.
func _phase_b() -> void:
	print("-- PHASE B: intersect_ray --")
	var cam := _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	var vp := _hub.get_node("WorldViewport/SubViewport") as SubViewport
	_check(vp.size == VP_SIZE, "viewport forced to %dx%d (read back %dx%d)"
		% [VP_SIZE.x, VP_SIZE.y, vp.size.x, vp.size.y])
	_check(cam.get_viewport().get_visible_rect().size == Vector2(VP_SIZE),
		"the camera's own visible rect is not degenerate: %s"
			% str(cam.get_viewport().get_visible_rect().size))

	# The relief case FIRST (the positive), with the bump still registered
	# from phase A.
	var keepy := _hub.get_node("WorldViewport/SubViewport/World/Keepy") as Node3D
	keepy.global_position = Vector3(DOMAIN_CENTRE.x, 0.0, DOMAIN_CENTRE.y)
	var hubcam := cam as Node
	if hubcam.has_method("snap_to_target"):
		hubcam.call("snap_to_target")
	var pixel := Vector2(float(VP_SIZE.x) * 0.5, float(VP_SIZE.y) * 0.62)
	var origin: Vector3 = cam.project_ray_origin(pixel)
	var dir: Vector3 = cam.project_ray_normal(pixel)
	var flat_hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	_check(flat_hit != null, "the flat plane answers this ray at all")
	var surf_hit: Variant = HubSurface.intersect_ray(origin, dir)
	_check(surf_hit != null, "HubSurface answers this ray at all")
	if flat_hit != null and surf_hit != null:
		var fp: Vector3 = flat_hit
		var sp: Vector3 = surf_hit
		_blind(sp, "ray hit")
		# The tolerance is the MARCH\'S OWN RESOLUTION, read off HubSurface
		# rather than picked: a step of RAY_STEP refined RAY_BISECT_ITERS
		# times cannot place a hit closer than that, and a tighter number
		# here would only be a number that happens to pass on the slope
		# this probe drew. (It bit once: wave 2 raised the camera onto the
		# surface, the ray met a steeper flank, and a 1e-3 tolerance went
		# red on a hit that was 0.0011 off -- well inside the march.)
		var march_res: float = HubSurface.RAY_STEP / pow(2.0, float(HubSurface.RAY_BISECT_ITERS))
		_check(absf(sp.y - HubSurface.height_at(sp)) <= march_res,
			"the hit sits ON the surface to the march\'s own resolution: |y - h| = %.6f <= %.6f"
				% [absf(sp.y - HubSurface.height_at(sp)), march_res])
		var apart: float = Vector2(sp.x - fp.x, sp.z - fp.z).length()
		_check(apart > 1.0,
			"and it is NOT where the flat plane answers: %.3f u apart in xz" % apart)

	# The identity case: with no domain, EXACTLY the plane, on 20 rays.
	HubSurface.clear_domains()
	var worst: float = 0.0
	var checked: int = 0
	var nulls: int = 0
	for k in 20:
		var px := Vector2(float(VP_SIZE.x) * (0.1 + 0.04 * float(k)),
			float(VP_SIZE.y) * (0.55 + 0.02 * float(k)))
		var o: Vector3 = cam.project_ray_origin(px)
		var d: Vector3 = cam.project_ray_normal(px)
		var a: Variant = Plane(Vector3.UP, 0.0).intersects_ray(o, d)
		var b: Variant = HubSurface.intersect_ray(o, d)
		if a == null or b == null:
			nulls += 1
			_check(a == null and b == null, "ray %d: both answer null or neither" % k)
			continue
		checked += 1
		worst = maxf(worst, ((a as Vector3) - (b as Vector3)).length())
	_check(checked >= 15, "%d of 20 rays hit the ground (%d missed)" % [checked, nulls])
	_check(worst == 0.0,
		"with no domain, intersect_ray is BYTE-IDENTICAL to the plane on %d rays (worst delta %.9f)"
			% [checked, worst])


## PHASE C -- the walk itself. Every landing, every base line and the
## resting pose are read off the surface, not off zero.
##
## ⚠️ THE LANDING TALLY LIVES ON THE CLASS, and the listener is a NAMED
## METHOD. A GDScript lambda captures a local BY VALUE: a counter written
## inside one would be the lambda's own copy, this phase would read zero
## landings forever, and the trap is silent. Measured in this repo at
## least three times.
func _phase_c() -> void:
	print("-- PHASE C: the chain of hops --")
	HubSurface.clear_domains()
	var idx: int = HubSurface.register_domain(_spec(&"probe_bump", DOMAIN_CENTRE, 0.0))
	if idx < 0:
		_check(false, "phase C could not register its domain")
		return
	var keepy := _hub.get_node("WorldViewport/SubViewport/World/Keepy") as KeepyHopper
	var start := Vector3(DOMAIN_CENTRE.x + 4.0, 0.0, DOMAIN_CENTRE.y)
	var summit := Vector3(DOMAIN_CENTRE.x, 0.0, DOMAIN_CENTRE.y)
	var h_start: float = _blind(start, "walk start")
	var h_summit: float = _blind(summit, "walk target")
	_check(absf(h_summit - h_start) > 0.5,
		"the walk actually climbs: %.4f -> %.4f u" % [h_start, h_summit])

	keepy.global_position = HubSurface.ground(start)
	_land_count = 0
	_land_worst = 0.0
	keepy.hop_landed.connect(_on_land)
	keepy.hop_to(summit)
	var guard: int = 0
	while guard < 1200 and (keepy.is_hopping() or keepy._has_target):
		guard += 1
		await get_tree().process_frame
	keepy.hop_landed.disconnect(_on_land)
	_check(guard < 1200, "the walk terminated in %d frames" % guard)
	_check(_land_count >= 2, "the walk took %d hops (needs more than one)" % _land_count)
	_check(_land_worst < 1.0e-4,
		"every landing sat ON the surface (worst |y - h| = %.8f over %d)"
			% [_land_worst, _land_count])

	# C2 -- the resting pose.
	var rest: Vector3 = keepy.global_position
	var h_rest: float = _blind(rest, "resting pose")
	_check(absf(rest.y - h_rest) < 1.0e-4,
		"at rest y = %.4f, height_at = %.4f" % [rest.y, h_rest])
	_check(rest.y > 1.0, "and it is well above sea level (%.4f u)" % rest.y)

	# C3 -- mid-hop, read off the arc rather than timed. The tween is
	# killed and _apply_hop(0.5) called directly: the base line at t = 0.5
	# must be the LERP of the two ends, plus the arc's own peak.
	keepy.hop_to(Vector3(DOMAIN_CENTRE.x + 4.0, 0.0, DOMAIN_CENTRE.y))
	await get_tree().process_frame
	var from_y: float = keepy._hop_from_y
	var to_y: float = keepy._hop_to_y
	var peak: float = keepy._hop_height
	_check(absf(from_y - HubSurface.height_at(keepy._hop_from)) < 1.0e-4,
		"the arc STARTS on the surface: base %.4f vs height_at %.4f"
			% [from_y, HubSurface.height_at(keepy._hop_from)])
	_check(absf(to_y - HubSurface.height_at(keepy._hop_to)) < 1.0e-4,
		"the arc ENDS on the surface: base %.4f vs height_at %.4f"
			% [to_y, HubSurface.height_at(keepy._hop_to)])
	_check(absf(from_y) > 1.0e-3 or absf(to_y) > 1.0e-3,
		"BLIND arc: at least one end is off sea level (%.4f, %.4f)" % [from_y, to_y])
	if keepy._hop_tween and keepy._hop_tween.is_valid():
		keepy._hop_tween.kill()
	keepy._apply_hop(0.5)
	var mid_y: float = keepy.global_position.y
	var want: float = lerpf(from_y, to_y, 0.5) + peak
	_check(absf(mid_y - want) < 1.0e-4,
		"mid-hop y = %.4f = lerp(%.4f, %.4f) + arc %.4f = %.4f"
			% [mid_y, from_y, to_y, peak, want])
	HubSurface.clear_domains()

func _on_land(pos: Vector3) -> void:
	_land_count += 1
	_land_worst = maxf(_land_worst, absf(pos.y - HubSurface.height_at(pos)))


## PHASE D -- the camera. It follows the GROUND under Keepy, so its
## offset keeps its shape over relief instead of sinking into it.
func _phase_d() -> void:
	print("-- PHASE D: the camera follows the surface --")
	HubSurface.clear_domains()
	var idx: int = HubSurface.register_domain(_spec(&"probe_bump", DOMAIN_CENTRE, 0.0))
	if idx < 0:
		_check(false, "phase D could not register its domain")
		return
	var keepy := _hub.get_node("WorldViewport/SubViewport/World/Keepy") as Node3D
	var cam := _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as HubCamera
	var summit := Vector3(DOMAIN_CENTRE.x, 0.0, DOMAIN_CENTRE.y)
	var h: float = _blind(summit, "camera target")
	keepy.global_position = HubSurface.ground(summit)
	# 120 frames of the ordinary smoothing -- NOT snap_to_target(). The
	# follow in _process is the thing under test; a snap would prove the
	# other function.
	for _i in 120:
		await get_tree().process_frame
	var want: Vector3 = HubSurface.ground(summit) + HubCamera.OFFSET
	var got: Vector3 = cam.global_position
	_check(got.distance_to(want) < 1.0e-3,
		"camera at %s, wanted ground + OFFSET = %s (%.6f u apart)"
			% [str(got), str(want), got.distance_to(want)])
	_check(absf(got.y - (HubCamera.OFFSET.y + h)) < 1.0e-3,
		"its height is OFFSET.y + h = %.4f + %.4f = %.4f (read %.4f)"
			% [HubCamera.OFFSET.y, h, HubCamera.OFFSET.y + h, got.y])
	_check(absf(got.y - HubCamera.OFFSET.y) > 1.0,
		"BLIND: and that is %.4f u above where a flat hub would put it" % (got.y - HubCamera.OFFSET.y))
	HubSurface.clear_domains()


## PHASE TAP (wave 3) -- the tap resolves against the SURFACE.
##
## ⚠️ THE FIRST VERSION OF THIS PHASE MEASURED THE WRONG THING, and only
## the red-before-green pass said so: it went GREEN with HubSurface put
## back to a bare Plane. Two reasons, both worth writing down.
##   * `tapped_ground` does not always carry the ground point. A tap that
##     lands near a tree emits THE TREE'S position (HubTapInput:468), so
##     the numbers being compared were two tree positions.
##   * comparing a "flat run" against a "relief run" also moves the
##     CAMERA, because wave 2 put the camera on the surface too. The two
##     effects partly cancel -- measured at 0.143 u.
## So the camera is FROZEN to one pose here and the ONLY thing that
## changes between the two taps is whether a domain is registered; and
## several pixels are swept, because any single one may route to a prop
## in both runs and read as "no difference".
func _phase_tap() -> void:
	print("-- PHASE TAP: HubTapInput resolves on the surface --")
	# The source gate first: it is the one check that cannot be fooled by
	# routing, and it fails loudly if a later lot puts the plane back.
	var src: String = FileAccess.get_file_as_string("res://scripts/hub/HubTapInput.gd")
	_check(src.contains("HubSurface.intersect_ray(origin, direction)"),
		"HubTapInput resolves its ray through HubSurface")
	_check(not src.contains("Plane(Vector3.UP, 0.0).intersects_ray"),
		"and no bare ground plane survives in it")

	HubSurface.clear_domains()
	var idx: int = HubSurface.register_domain(_spec(&"probe_bump", DOMAIN_CENTRE, 0.0))
	if idx < 0:
		_check(false, "phase TAP could not register its domain")
		return
	var tap := _hub.get_node("TapInput")
	var keepy := _hub.get_node("WorldViewport/SubViewport/World/Keepy") as Node3D
	var cam := _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as HubCamera
	var summit := Vector3(DOMAIN_CENTRE.x, 0.0, DOMAIN_CENTRE.y)
	_blind(summit, "tap station")
	keepy.global_position = HubSurface.ground(summit)
	cam.snap_to_target()
	await get_tree().process_frame
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	var rect: Rect2 = box.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0,
		"the tap container is not degenerate: %s" % str(rect.size))
	# THE CAMERA POSE, taken once and re-imposed before each tap. No await
	# between writing it and tapping, or the follow would move it back.
	var pose: Transform3D = cam.global_transform

	tap.tapped_ground.connect(_on_tap)
	var moved: int = 0
	var swept: int = 0
	var worst: float = 0.0
	for k in 7:
		var pixel: Vector2 = rect.position + Vector2(rect.size.x * 0.5,
			rect.size.y * (0.50 + 0.03 * float(k)))
		HubSurface.clear_domains()
		HubSurface.register_domain(_spec(&"probe_bump", DOMAIN_CENTRE, 0.0))
		cam.global_transform = pose
		_tapped = Vector3.INF
		tap.call("_handle_point", pixel)
		var with_relief: Vector3 = _tapped
		HubSurface.clear_domains()
		cam.global_transform = pose
		_tapped = Vector3.INF
		tap.call("_handle_point", pixel)
		var flat: Vector3 = _tapped
		if with_relief == Vector3.INF or flat == Vector3.INF:
			continue
		swept += 1
		var apart: float = Vector2(with_relief.x - flat.x, with_relief.z - flat.z).length()
		worst = maxf(worst, apart)
		if apart > 0.5:
			moved += 1
	tap.tapped_ground.disconnect(_on_tap)
	_check(swept >= 5, "%d of 7 swept pixels produced a destination on both runs" % swept)
	_check(moved >= 1,
		"the SAME pixel through the SAME camera pose means somewhere else once relief is under it: %d of %d moved, worst %.3f u"
			% [moved, swept, worst])
	HubSurface.clear_domains()

func _on_tap(point: Vector3) -> void:
	_tapped = point
	_tap_seen += 1
