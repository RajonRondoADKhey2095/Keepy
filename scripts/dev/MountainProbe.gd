extends Node
## CH38 lot 2 part A -- the west ridge: the domain, its slopes, and what it
## costs the frame.
##
## =====================================================================
## RUN IT UNDER XVFB, NOT --headless
##
##   xvfb-run --auto-servernum -- godot4 --rendering-driver opengl3 \
##     --fixed-fps 60 --path . res://scripts/dev/MountainProbe.tscn
##
## PHASE E reads RenderingServer's per-viewport primitive counter, which
## the dummy driver does not fill, and PHASE D reads a camera frustum,
## which the dummy driver reports 0x0 for. Both would pass by measuring
## nothing. The flags go BEFORE the `--`: `--fixed-fps` after it is
## swallowed by the game and PHASE F then walks in real time.
##
## PHASE F walks ~1 900 physics frames of the whole hub, so it shrinks the
## SubViewport to WALK_VP first and restores VP_SIZE afterwards. The
## viewport does not touch physics; under llvmpipe at 1080x1920 it is the
## difference between a minute and twenty.
##
## =====================================================================
## WHAT IT GATES
##
##   BLIND  height_at is 0 off the domain AND 0 everywhere before the
##          domain is registered -- proved BEFORE anything leans on it,
##          because every assertion below is of the form "the ground is
##          at h" and h = 0 would satisfy most of them for free
##   A      contains / domain_at / height_at on a lattice of points, in,
##          out, and exactly on each edge
##   B      the C0 raccord, re-walked here rather than trusted to
##          register_domain -- plus the red-before-green that a lifted
##          grid IS refused
##   C      the drawn mesh: same vertices as the grid, same triangulation,
##          winding whose normal is +Y, and every triangle <= 30 deg
##   D      from each station, the eye-to-summit line clears the terrain
##          -- a crest you cannot see is not a crest
##   E      the triangle budget, measured as the delta between the ridge
##          drawn and the ridge hidden, at 8 stations x 2 camera heights
##   F      the worst crossing this rectangle creates, WALKED on the real
##          hopper (HubRegion's header prices it at ~21.05 s against the
##          22 s the hub holds itself to)
##
## Exit 0 all green, 1 any red, ProbeWatchdog.EXIT_TIMEOUT = INCONCLUSIVE.

const VP_SIZE: Vector2i = Vector2i(1080, 1920)
## The viewport PHASE F walks under. Small on purpose: llvmpipe's cost is
## per fragment and the walk needs none of them.
const WALK_VP: Vector2i = Vector2i(96, 160)
const BUDGET_S: float = 900.0

## The ceiling CH35-C set for a walkable slope on unlit ground.
const MAX_WALKABLE_DEG: float = 30.0
## What a foot 30 u away may still be shown, from CH36's frame ceiling.
const MAX_VISIBLE_RISE: float = 9.0

## PHASE F's yardstick: the shipped diagonal, and the seconds the hub
## holds itself to. Both are HubRegion's published numbers, read here
## rather than restated as a third spelling.
const CROSSING_CEILING_S: float = 22.0

var _fails: int = 0
var _hub: Node = null
var _ridge: MeshInstance3D = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _sub: SubViewport = null
## PHASE F's landing flag. A MEMBER and not a captured local: a GDScript
## lambda captures a local BY VALUE, so a loop waiting on one never sees
## it change -- this repo has paid for that at least three times.
var _idle: bool = false

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract.
	ProbeWatchdog.arm(self, "MOUNTAIN PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_ridge = _hub.get_node("WorldViewport/SubViewport/World/Mountain") as MeshInstance3D
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as Node3D
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	_force_viewport(VP_SIZE)
	_run()

## `stretch = false` FIRST: a stretching container IGNORES an explicit
## size and only warns, and a probe that measured the window instead of
## the surface it asked for would report two ratios as one number.
func _force_viewport(size: Vector2i) -> void:
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	_sub.size = size

func _run() -> void:
	print("=== MOUNTAIN PROBE -- CH38 lot 2 part A ===")
	print("  domain %s  x [%.1f, %.1f]  z [%.1f, %.1f]  pitch %.2f  %dx%d  tris %d"
		% [HubMountain.DOMAIN_NAME, HubRegion.MOUNTAIN_MIN.x, HubRegion.MOUNTAIN_MAX.x,
			HubRegion.MOUNTAIN_MIN.y, HubRegion.MOUNTAIN_MAX.y, HubMountain.PITCH,
			HubMountain.columns(), HubMountain.rows(), HubMountain.triangle_count()])
	_phase_blind()
	_phase_a()
	_phase_b()
	_phase_c()
	await _phase_d()
	await _phase_e()
	await _phase_f()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

## The summit, READ OFF THE REGISTERED GRID rather than off BUMPS: the
## grid is the surface, and a probe that took the analytic maximum would
## be measuring a second opinion of it.
func _summit() -> Vector3:
	var best := Vector3(HubRegion.MOUNTAIN_MIN.x, -1.0, HubRegion.MOUNTAIN_MIN.y)
	for r in HubMountain.rows():
		var z: float = HubRegion.MOUNTAIN_MIN.y + float(r) * HubMountain.PITCH
		for c in HubMountain.columns():
			var x: float = HubRegion.MOUNTAIN_MIN.x + float(c) * HubMountain.PITCH
			var h: float = HubSurface.height_at(Vector3(x, 0.0, z))
			if h > best.y:
				best = Vector3(x, h, z)
	return best

## PHASE BLIND -- prove the accessor can SAY NO before believing it when
## it says yes. "height_at is 0 here" is an assertion of ABSENCE, and this
## repo has watched three of those pass green against a mechanism that was
## never wired at all.
func _phase_blind() -> void:
	print("-- PHASE BLIND: zero off the domain, and zero without one --")
	# 1. A point outside every domain, with the game's domain live.
	var off := Vector3(0.0, 0.0, 0.0)
	_check(HubSurface.domain_at(off) == -1, "spawn is in no domain (domain_at = %d)" % HubSurface.domain_at(off))
	_check(is_equal_approx(HubSurface.height_at(off), 0.0),
		"height_at(0, 0) = %.6f off the domain" % HubSurface.height_at(off))
	# 2. THE ONE THAT MATTERS: with no domain at all, the summit reads 0
	#    too. If the assertions below could not tell those two apart they
	#    would be measuring nothing.
	var summit := _summit()
	var live: float = summit.y
	var saved: Array[Dictionary] = []
	for d in HubSurface.domains():
		saved.append(d)
	HubSurface.clear_domains()
	var blind: float = HubSurface.height_at(Vector3(summit.x, 0.0, summit.z))
	for d in saved:
		HubSurface.domains().append(d)
	var back: float = HubSurface.height_at(Vector3(summit.x, 0.0, summit.z))
	_check(is_equal_approx(blind, 0.0), "with no domain the summit reads %.6f" % blind)
	_check(live > 1.0, "with the domain the SAME point reads %.4f" % live)
	_check(is_equal_approx(back, live), "and reads %.4f again once restored" % back)

## PHASE A -- containment and sampling on a lattice.
func _phase_a() -> void:
	print("-- PHASE A: contains / domain_at / height_at --")
	var lo := HubRegion.MOUNTAIN_MIN
	var hi := HubRegion.MOUNTAIN_MAX
	var index: int = HubMountain.register()
	_check(index >= 0, "the domain is registered (index %d)" % index)

	# Every lattice node the grid holds: in the domain, and its height is
	# exactly the grid cell (the sample must be interpolation-free ON a node).
	var grid: PackedFloat32Array = HubSurface.domains()[index]["grid"]
	var cols: int = HubMountain.columns()
	var worst_node: float = 0.0
	var outside: int = 0
	for r in HubMountain.rows():
		var z: float = lo.y + float(r) * HubMountain.PITCH
		for c in cols:
			var x: float = lo.x + float(c) * HubMountain.PITCH
			var p := Vector3(x, 0.0, z)
			if HubSurface.domain_at(p) != index:
				outside += 1
			worst_node = maxf(worst_node, absf(HubSurface.height_at(p) - grid[r * cols + c]))
	_check(outside == 0, "all %d lattice nodes are inside the domain (%d were not)"
		% [cols * HubMountain.rows(), outside])
	_check(worst_node < 1.0e-6, "height_at ON a node equals its grid cell (worst %.9f)" % worst_node)

	# Just OUTSIDE each of the four edges: no domain, height exactly 0.
	var out_pts: Array[Vector3] = [
		Vector3(lo.x - 0.1, 0.0, (lo.y + hi.y) * 0.5),
		Vector3(hi.x + 0.1, 0.0, (lo.y + hi.y) * 0.5),
		Vector3((lo.x + hi.x) * 0.5, 0.0, lo.y - 0.1),
		Vector3((lo.x + hi.x) * 0.5, 0.0, hi.y + 0.1),
	]
	for p in out_pts:
		_check(HubSurface.domain_at(p) == -1 and HubSurface.height_at(p) == 0.0,
			"(%.1f, %.1f) is off the domain and reads 0.0" % [p.x, p.z])

	# The region: the ridge is walkable, and it is still zone 0 -- no gate,
	# no corridor, no row in the zone tree.
	var summit := _summit()
	_check(HubRegion.contains(summit), "the summit (%.1f, %.1f) is walkable" % [summit.x, summit.z])
	_check(HubRegion.zone_of(summit) == 0, "and reads as zone %d" % HubRegion.zone_of(summit))
	_check(summit.y <= MAX_VISIBLE_RISE,
		"summit height %.3f u is under the %.1f u a foot 30 u away can be shown" % [summit.y, MAX_VISIBLE_RISE])
	_check(summit.y >= 4.0, "and over the 4 u that makes it a hill rather than a bulge")
	# The seam: a walk crosses x = -35 with no step, because BOTH sides
	# read 0 there. This is what buys the ridge its lack of a zone.
	var seam_worst: float = 0.0
	var z_seam: float = lo.y
	while z_seam <= hi.y + 0.001:
		seam_worst = maxf(seam_worst, absf(HubSurface.height_at(Vector3(hi.x, 0.0, z_seam))))
		seam_worst = maxf(seam_worst, absf(HubSurface.height_at(Vector3(hi.x + 0.5, 0.0, z_seam))))
		_check_silent(HubRegion.contains(Vector3(hi.x - 0.5, 0.0, z_seam))
			and HubRegion.contains(Vector3(hi.x + 0.5, 0.0, z_seam)))
		z_seam += 0.5
	_check(seam_worst == 0.0, "the plateau seam at x = %.1f is flat on both sides (worst %.9f)"
		% [hi.x, seam_worst])
	_check(_silent_fails == 0, "and walkable on both sides at every 0.5 u of it (%d gaps)" % _silent_fails)

var _silent_fails: int = 0
func _check_silent(ok: bool) -> void:
	if not ok:
		_silent_fails += 1

## PHASE B -- the C0 raccord, and the proof the gate can refuse.
func _phase_b() -> void:
	print("-- PHASE B: the C0 raccord, re-walked --")
	var lo := HubRegion.MOUNTAIN_MIN
	var hi := HubRegion.MOUNTAIN_MAX
	var worst: float = 0.0
	var step: float = HubSurface.PERIMETER_STEP
	var x: float = lo.x
	while x <= hi.x + 0.001:
		worst = maxf(worst, absf(HubSurface.height_at(Vector3(minf(x, hi.x), 0.0, lo.y))))
		worst = maxf(worst, absf(HubSurface.height_at(Vector3(minf(x, hi.x), 0.0, hi.y))))
		x += step
	var z: float = lo.y
	while z <= hi.y + 0.001:
		worst = maxf(worst, absf(HubSurface.height_at(Vector3(lo.x, 0.0, minf(z, hi.y)))))
		worst = maxf(worst, absf(HubSurface.height_at(Vector3(hi.x, 0.0, minf(z, hi.y)))))
		z += step
	_check(worst < HubSurface.PERIMETER_TOL,
		"perimeter |h| = %.9f, under the %.6f tolerance" % [worst, HubSurface.PERIMETER_TOL])
	_check(worst == 0.0, "and it is EXACTLY zero -- compact support, not a tolerance")

	# RED BEFORE GREEN. The gate above has never failed, so it has proved
	# nothing yet. Hand register_domain the SAME lattice lifted by 1 cm and
	# it must refuse -- if it accepted, the assertion above would be free.
	var lifted := HubMountain.build_grid()
	for i in lifted.size():
		lifted[i] = lifted[i] + 0.01
	var refused: int = HubSurface.register_domain({
		"name": &"west_ridge_lifted", "origin": Vector2(200.0, 200.0),
		"pitch": HubMountain.PITCH, "cols": HubMountain.columns(),
		"rows": HubMountain.rows(), "grid": lifted,
	})
	_check(refused < 0, "a lattice lifted 0.01 u IS refused (got index %d)" % refused)
	# And the same lattice unlifted, far from everything, IS accepted --
	# otherwise the refusal above could be about the position, not the step.
	var flat_spec := {
		"name": &"west_ridge_control", "origin": Vector2(200.0, 200.0),
		"pitch": HubMountain.PITCH, "cols": HubMountain.columns(),
		"rows": HubMountain.rows(), "grid": HubMountain.build_grid(),
	}
	var accepted: int = HubSurface.register_domain(flat_spec)
	_check(accepted >= 0, "the same lattice UNLIFTED is accepted there (index %d)" % accepted)
	if accepted >= 0:
		HubSurface.domains().remove_at(accepted)

## PHASE C -- the mesh IS the query, and no triangle is steeper than the
## ceiling.
func _phase_c() -> void:
	print("-- PHASE C: the drawn mesh, its winding, and its slopes --")
	var mesh: ArrayMesh = _ridge.mesh as ArrayMesh
	_check(mesh != null and mesh.get_surface_count() == 1,
		"the ridge node draws one surface")
	if mesh == null:
		return
	var mat: Material = _ridge.get_surface_override_material(0)
	_check(mat is ShaderMaterial, "and wears a ShaderMaterial (the cozy ground shader)")

	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_check(idx.size() / 3 == HubMountain.triangle_count(),
		"%d triangles drawn, %d published" % [idx.size() / 3, HubMountain.triangle_count()])

	# EVERY vertex sits exactly on the queried surface. This is the whole
	# "the feet are on the triangle you see" claim, and it is checked on
	# the drawn array rather than argued from the builder.
	var worst_v: float = 0.0
	for v in verts:
		worst_v = maxf(worst_v, absf(HubSurface.height_at(Vector3(v.x, 0.0, v.z)) - v.y))
	_check(worst_v < 1.0e-6, "every drawn vertex is on height_at (worst %.9f)" % worst_v)

	# WINDING. Godot takes CLOCKWISE faces for FRONT faces and the ground
	# shader is cull_back: a ribbon wound the other way is invisible with
	# no error of any kind. Checked on every triangle, not just the first.
	var wrong: int = 0
	var worst_deg: float = 0.0
	var worst_at := Vector3.ZERO
	var sample_worst: float = 0.0
	var t: int = 0
	while t < idx.size():
		var a: Vector3 = verts[idx[t]]
		var b: Vector3 = verts[idx[t + 1]]
		var c: Vector3 = verts[idx[t + 2]]
		var n: Vector3 = (b - a).cross(c - a)
		if n.y <= 0.0:
			wrong += 1
		var deg: float = rad_to_deg(acos(clampf(absf(n.y) / n.length(), 0.0, 1.0)))
		if deg > worst_deg:
			worst_deg = deg
			worst_at = (a + b + c) / 3.0
		# The centroid: an interior point of the drawn triangle, where the
		# barycentric sample must agree with the plane of that triangle.
		var mid: Vector3 = (a + b + c) / 3.0
		sample_worst = maxf(sample_worst, absf(HubSurface.height_at(Vector3(mid.x, 0.0, mid.z)) - mid.y))
		t += 3
	_check(wrong == 0, "every triangle's normal points at +Y (%d wound the other way)" % wrong)
	_check(sample_worst < 1.0e-5,
		"and height_at INSIDE each triangle is on its plane (worst %.9f) -- same triangulation" % sample_worst)
	_check(worst_deg <= MAX_WALKABLE_DEG,
		"worst drawn slope %.3f deg at (%.1f, %.1f), ceiling %.1f"
		% [worst_deg, worst_at.x, worst_at.z, MAX_WALKABLE_DEG])
	print("     (nothing on this domain is unwalkable, so the 45 deg short-flank")
	print("      allowance and the 55 deg cozy_ground ceiling are both moot here)")

## PHASE D -- the crest is SEEN. A relief whose summit is behind its own
## flank is a wall of green, which is the failure CH35-C named.
func _phase_d() -> void:
	print("-- PHASE D: the eye-to-summit line, from every station --")
	var summit := _summit()
	var stations := _stations()
	var blocked: int = 0
	var seen: int = 0
	for s in stations:
		var eye: Vector3 = HubSurface.ground(s) + HubCamera.OFFSET
		# Only stations the camera can actually look FROM toward the
		# summit: this camera never yaws, so a summit at higher z than the
		# station is behind the lens and is not this phase's business.
		if summit.z > s.z:
			continue
		seen += 1
		var under: float = 0.0
		for k in range(1, 40):
			var f: float = float(k) / 40.0
			var p: Vector3 = eye.lerp(summit, f)
			# The last sample IS the summit; clearing it by 0 is correct.
			var clearance: float = p.y - HubSurface.height_at(p)
			if f < 0.98:
				under = minf(under, clearance)
		if under < -0.01:
			blocked += 1
			print("     station (%.1f, %.1f): the line dips %.3f u under the ground" % [s.x, s.z, under])
	_check(seen >= 4, "%d of %d stations look toward the summit" % [seen, stations.size()])
	_check(blocked == 0, "and the eye-to-summit line clears the terrain from all of them (%d blocked)" % blocked)

	# The rise a foot 30 u out is shown: CH36's frame ceiling is what caps
	# it, and the summit has to fit under it or the camera crops the crest.
	var foot := Vector3(summit.x, 0.0, summit.z + 30.0)
	var rise: float = summit.y - HubSurface.height_at(foot)
	_check(rise <= MAX_VISIBLE_RISE,
		"rise seen from a foot 30 u away: %.3f u, ceiling %.1f (CH36 frame top %.3f)"
		% [rise, MAX_VISIBLE_RISE, HubCamera.FRAME_TOP_AT_APLOMB])

	# AND THE CREST IS IN THE FRAME, read off the REAL camera rather than
	# argued from an elevation angle. CH36 was the lot that found a frame
	# ceiling wrong by 1.01 u by doing exactly this instead of trusting the
	# arithmetic; a crest cropped by the top of the screen is the same
	# defect with a different subject.
	var cropped: int = 0
	var highest_seen: float = 1.0e9
	for s in stations:
		if summit.z > s.z:
			continue
		_keepy.global_position = HubSurface.ground(s)
		if _camera.has_method("snap_to_target"):
			_camera.call("snap_to_target")
		await get_tree().process_frame
		if _camera.is_position_behind(summit):
			continue
		var screen: Vector2 = _camera.unproject_position(summit)
		highest_seen = minf(highest_seen, screen.y)
		if screen.y < 0.0 or screen.y > float(VP_SIZE.y):
			cropped += 1
			print("     station (%.1f, %.1f): the summit projects to y = %.1f, off a %d-tall frame"
				% [s.x, s.z, screen.y, VP_SIZE.y])
	_check(cropped == 0,
		"the summit stays inside the frame from every station that looks at it (%d cropped)" % cropped)
	print("     highest the summit ever sits on screen: y = %.1f of %d" % [highest_seen, VP_SIZE.y])

## The eight stations: the ridge's own cardinal and diagonal rim points,
## plus the summit itself and the plateau seam. AZIMUTH means "where the
## player stands", not "where the camera looks" -- HubCamera never yaws.
func _stations() -> Array[Vector3]:
	var summit := _summit()
	var out: Array[Vector3] = []
	for k in 8:
		var a: float = TAU * float(k) / 8.0
		var p := Vector3(summit.x + cos(a) * 11.0, 0.0, summit.z + sin(a) * 11.0)
		p.x = clampf(p.x, HubRegion.MOUNTAIN_MIN.x + 0.5, HubRegion.MOUNTAIN_MAX.x - 0.5)
		p.z = clampf(p.z, HubRegion.MOUNTAIN_MIN.y + 0.5, HubRegion.MOUNTAIN_MAX.y - 0.5)
		out.append(p)
	return out

## PHASE E -- the triangle budget, gated from this lot's FIRST commit
## rather than bolted on after the fact.
##
## The delta is measured by HIDING the ridge and re-reading the SAME
## frame, which is exactly the question the ceiling asks ("what does the
## bare relief ADD"). `engine_prims` is the OPAQUE list at the LOD the
## engine chose -- the line a device will actually pay, and the one CH23
## established a ceiling has to be gated on.
func _phase_e() -> void:
	print("-- PHASE E: the triangle budget, 8 stations x 2 camera heights --")
	var stations := _stations()
	var worst_delta: int = 0
	var worst_where: String = ""
	var worst_on: int = 0
	for hi_cam in [false, true]:
		for s in stations:
			_keepy.global_position = HubSurface.ground(s)
			if _camera.has_method("snap_to_target"):
				_camera.call("snap_to_target")
			if hi_cam:
				# The SECOND camera position. No vehicle drives near this
				# domain -- the kart is at the circuit and the sand yacht at
				# the cove -- so there is no chase camera to read here. This
				# stands in for it: the same fixed rig lifted to a summit
				# station, which is the widest view of the ridge that exists.
				_camera.global_position = HubSurface.ground(s) + HubCamera.OFFSET + Vector3(0.0, 4.0, 0.0)
			await get_tree().process_frame
			await get_tree().process_frame
			var on: int = _prims()
			_ridge.visible = false
			await get_tree().process_frame
			await get_tree().process_frame
			var off: int = _prims()
			_ridge.visible = true
			var delta: int = on - off
			print("     station (%6.1f, %6.1f) cam %s : on %6d  off %6d  delta %+6d"
				% [s.x, s.z, "high" if hi_cam else "flat", on, off, delta])
			if delta > worst_delta:
				worst_delta = delta
				worst_where = "(%.1f, %.1f) cam %s" % [s.x, s.z, "high" if hi_cam else "flat"]
				worst_on = on
	# A ZERO IS PUBLISHED AS A ZERO. The Compatibility backend fills these
	# counters on desktop GL; nothing promises it does under WebGL2, and a
	# probe that hid a 0 would be claiming a free frame.
	_check(worst_on > 0, "the engine counter is filled at all (worst frame reads %d)" % worst_on)
	_check(worst_delta <= HubMountain.TRIANGLE_BUDGET,
		"worst added primitives %d at %s, ceiling %d"
		% [worst_delta, worst_where, HubMountain.TRIANGLE_BUDGET])
	_check(worst_delta > 0, "and the ridge DOES cost something (a 0 would mean it never drew)")

func _prims() -> int:
	return RenderingServer.viewport_get_render_info(
		_sub.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)

## PHASE F -- the worst crossing, WALKED.
##
## HubRegion's header prices this rectangle at ~21.05 s against the 22 s
## the hub holds itself to, from the shipped 0.18890 s/u. A ratio is not a
## measurement: the hopper is what decides, so it walks the pair.
func _phase_f() -> void:
	print("-- PHASE F: the worst crossing this rectangle creates, walked --")
	_force_viewport(WALK_VP)
	var from := Vector3(35.0, 0.0, -35.0)
	var to := Vector3(HubRegion.MOUNTAIN_MIN.x, 0.0, HubRegion.MOUNTAIN_MAX.y)
	_check(HubRegion.contains(from) and HubRegion.contains(to),
		"both ends of the pair are walkable")
	var seconds: float = await _walk(from, to)
	if seconds < 0.0:
		_check(false, "the walk did not land (INCONCLUSIVE for this phase)")
	else:
		_check(seconds <= CROSSING_CEILING_S,
			"(35, -35) -> (%.0f, %.0f) walked in %.3f s, ceiling %.1f"
			% [to.x, to.z, seconds, CROSSING_CEILING_S])
	# The shipped diagonal, walked with the SAME bench in the SAME run --
	# a bench that cannot reproduce a number already on file has no
	# standing to publish a new one.
	var diag: float = await _walk(Vector3(-35.0, 0.0, -35.0), Vector3(35.0, 0.0, 35.0))
	print("     control: the shipped diagonal walks in %.3f s (18.700 s on file)" % diag)
	_check(diag > 0.0 and absf(diag - 18.700) < 1.5,
		"the bench reproduces the published diagonal within 1.5 s")
	_force_viewport(VP_SIZE)

## Walks Keepy from a to b and returns the seconds it took, or -1 if he
## never landed inside the frame ceiling.
func _walk(from: Vector3, to: Vector3) -> float:
	_keepy.global_position = HubSurface.ground(from)
	if _camera.has_method("snap_to_target"):
		_camera.call("snap_to_target")
	await get_tree().physics_frame
	_idle = false
	if not _keepy.became_idle.is_connected(_on_idle):
		_keepy.became_idle.connect(_on_idle)
	_keepy.call("hop_to", HubSurface.ground(to))
	var frames: int = 0
	while not _idle and frames < 4000:
		await get_tree().physics_frame
		frames += 1
	var landed: float = Vector3(_keepy.global_position.x, 0.0, _keepy.global_position.z) \
		.distance_to(Vector3(to.x, 0.0, to.z))
	if not _idle:
		return -1.0
	print("     walked %.2f u in %d frames, stopped %.3f u from the target"
		% [from.distance_to(to), frames, landed])
	return float(frames) / 60.0

func _on_idle() -> void:
	_idle = true
