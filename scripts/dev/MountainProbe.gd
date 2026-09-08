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
##   G      THE PIXELS. Every phase above reads geometry or a counter, and
##          CH39 is what that costs: the ridge shipped wound inside out,
##          Godot discarded all but its far flank, and this file was ALL
##          GREEN over it. PHASE G renders the hill through an
##          identification pass and gates on the face test discarding
##          NOTHING -- which is the one question no amount of arithmetic
##          about a cross product can answer.
##   F      the worst crossing this rectangle creates, WALKED on the real
##          hopper (HubRegion's header prices it at ~21.05 s against the
##          22 s the hub holds itself to)
##
## CH40 lot 2 part B -- the dressing:
##
##   H      THE RIDGE IS NO LONGER BALD. CozyScatter.COVER_MIN stopped at
##          x = -37 while the domain starts at -63, so the two rectangles
##          overlapped by 2 u and CH39 counted 21 instances on the whole
##          hill, all of them where it is already flat. Gated on SPREAD,
##          not on a total: every cell of a 4 x 4 grid over the domain
##          has to hold something, which a 2 u strip cannot fake
##   I      NOTHING FLOATS AND NOTHING IS BURIED. Every instance standing
##          on the domain sits at HubSurface.height_at of its own (x, z),
##          and every instance off it still sits at 0 -- the second half
##          is what proves the ground lift is the no-op it claims to be
##   J      the dressing's OWN triangle budget, and the domain's
##          registration contract re-read after the pass
##   K      no piece of the dressing puts its APEX out of the frame of a
##          camera that never tilts -- a 4.9 u conifer on a 4.5 u hill is
##          9.4 u, over CH36's ceiling, before it is scaled
##   L      THE PIXELS OF THE DRESSING, at the two stations Mathieu read
##          on device -- it paints something, and the crest still owns the
##          frame with it there
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
var _scatter: Node3D = null
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
	_scatter = _hub.get_node("WorldViewport/SubViewport/World/CozyScatter") as Node3D

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
	await _phase_g()
	_phase_h()
	_phase_i()
	await _phase_j()
	_phase_k()
	await _phase_l()
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

	# WINDING. Godot takes CLOCKWISE-ON-SCREEN faces for FRONT faces and
	# the ground shader is cull_back: a lattice wound the other way is
	# invisible with no error of any kind.
	#
	# ⚠️ CH39: THIS ASSERTION SHIPPED BACKWARDS AND WAS GREEN 1 680 TIMES
	# OUT OF 1 680 ON A HILL GODOT WAS THROWING ENTIRELY AWAY. It required
	# the right-hand cross product to point at +Y, which is the MATHS
	# convention for "up" and the exact negation of the ENGINE convention
	# the comment above it names: a triangle whose right-hand normal is +Y
	# reads COUNTER-CLOCKWISE from any camera above it, which is the BACK
	# face. So a walkable top surface here must carry a right-hand normal
	# of -Y, and that is what is checked.
	#
	# The arithmetic below can only ever restate a convention. PHASE G is
	# the one that reads PIXELS, and it is not optional: no assertion in
	# this file that predates it could tell a drawn hill from a discarded
	# one.
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
		if n.y >= 0.0:
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
	_check(wrong == 0,
		"every triangle is CLOCKWISE from above -- Godot's front face, right-hand normal -Y (%d wound the other way)"
		% wrong)
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

## PHASE G -- THE PIXELS, and the reason this file exists in this shape.
##
## ⚠️ WHAT WENT WRONG WITHOUT IT. CH38 shipped the ridge wound so that its
## right-hand normals pointed at +Y. Godot's front face is CLOCKWISE on
## screen, so every one of those triangles was a BACK face to a camera
## above them, and `cull_back` on the ground shader discarded them. What
## survived was the far flank -- the triangles facing AWAY -- showing
## through the invisible near one, which from thirty units off looks
## exactly like a clean dome and from a station standing ON it looks like
## nothing at all. Measured at the two points Mathieu reported: 13 898 and
## 14 ridge pixels of a 1080x1920 frame, against 315 181 and 317 646 with
## the face test switched off.
##
## AND EVERY OTHER PHASE WAS GREEN THROUGH IT, each for its own reason:
##   PHASE C  asserted the winding -- backwards (see its own note)
##   PHASE D  raycasts height_at, which is the GRID: a query knows
##            nothing about which side of a triangle faces the eye
##   PHASE E  reads PRIMITIVES_IN_FRAME, which counts primitives
##            SUBMITTED. Back-face culling happens downstream of that
##            counter, so a hill that draws nothing still costs its whole
##            triangle budget and still reports a positive delta -- the
##            "and the ridge DOES cost something" line was true and
##            meant the opposite of what it was read to mean
##   PHASE F  walks the surface, which is the grid again
##
## THE GATE IS NOT A PIXEL COUNT. A threshold would have to be re-tuned
## for every station and would encode the very thing that was wrong. What
## is gated is that TURNING THE FACE TEST OFF CHANGES NOTHING: if the
## lattice is wound the way Godot draws it, `cull_back` and
## `cull_disabled` cover the same pixels. That holds at any station, on
## any shape, and it fails loudly on an inside-out mesh.
const IDENT_ONE_SIDED: String = """
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled, fog_disabled;
void fragment() { ALBEDO = vec3(1.0, 0.0, 1.0); }
"""
const IDENT_TWO_SIDED: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;
void fragment() { ALBEDO = vec3(1.0, 0.0, 1.0); }
"""
## How much of the frame the ridge must own from a station standing on it.
## Deliberately far under the 60.40 % / 20.71 % measured: this is a "the
## hill is on screen at all" floor, not a framing gate -- the real gate is
## the face-test line below, which needs no threshold at all. With the
## inside-out winding the same two stations read 0.00 % and 0.70 %, so a
## floor of 10 % refuses that by a factor of fourteen at the station that
## HID the defect, and by everything at the one that did not.
const MIN_COVERAGE: float = 0.10
## How far the two face tests may disagree. Not zero: the silhouette is a
## row of pixels wide and a rasteriser is free to differ by one there.
const CULL_TOLERANCE: float = 0.01

func _phase_g() -> void:
	print("-- PHASE G: the pixels, and the face test that must discard nothing --")
	var one := ShaderMaterial.new()
	one.shader = Shader.new()
	one.shader.code = IDENT_ONE_SIDED
	var two := ShaderMaterial.new()
	two.shader = Shader.new()
	two.shader.code = IDENT_TWO_SIDED
	# The summit is the worst case for an inside-out lattice: standing on
	# it, every triangle in the frame faces the eye, so a wrong winding
	# leaves nothing at all. The rim station is the case that HID the
	# defect for a whole lot -- from there the far flank alone still reads
	# as a dome.
	var summit := _summit()
	var here: Array[Vector3] = [
		Vector3(summit.x, 0.0, summit.z + 3.0),
		Vector3(summit.x + 11.0, 0.0, summit.z + 11.0),
	]
	# CH40: and the two points Mathieu actually stood on, on device. With
	# a dressing in front of it the crest can lose the frame to its own
	# trees, so the coverage floor is re-read exactly where the device
	# report was written rather than only where the geometry is worst.
	here.append(DEVICE_STATIONS[0])
	here.append(DEVICE_STATIONS[1])
	var kept: Material = _ridge.get_surface_override_material(0)
	var total: float = float((VP_SIZE.x / 2) * (VP_SIZE.y / 2))
	for s in here:
		_keepy.global_position = HubSurface.ground(s)
		if _camera.has_method("snap_to_target"):
			_camera.call("snap_to_target")
		# BLIND FIRST. "The ridge covers N pixels" is worthless until the
		# instrument has been seen to answer ZERO -- this repo has watched
		# three assertions of presence pass against nothing at all.
		_ridge.visible = false
		var blind: int = await _ident_pixels(one)
		_ridge.visible = true
		var culled: int = await _ident_pixels(one)
		var uncut: int = await _ident_pixels(two)
		_ridge.set_surface_override_material(0, kept)
		_check(blind == 0, "station (%.1f, %.1f): with the ridge hidden the mask reads %d pixels"
			% [s.x, s.z, blind])
		_check(float(culled) / total >= MIN_COVERAGE,
			"station (%.1f, %.1f): the ridge owns %.2f %% of the frame (floor %.0f %%)"
			% [s.x, s.z, 100.0 * float(culled) / total, 100.0 * MIN_COVERAGE])
		var gap: float = absf(float(uncut - culled)) / maxf(float(uncut), 1.0)
		_check(gap <= CULL_TOLERANCE,
			"station (%.1f, %.1f): cull_back %d vs cull_disabled %d -- the face test discards %.2f %% (ceiling %.0f %%)"
			% [s.x, s.z, culled, uncut, 100.0 * gap, 100.0 * CULL_TOLERANCE])

## Pixels the ridge owns, by an identification pass. IT CONTAINS AN
## `await`, so it is a COROUTINE and every call site awaits it: calling
## one without `await` runs it in PARALLEL with what follows, and this
## repo has watched two phases measure the same thing that way.
##: the ridge alone is
## painted a colour nothing else in this hub carries, fog off, and a pixel
## belongs to it IFF it comes back EXACTLY that colour. A window would
## drift onto sky and plateau as the dome moves in the frame; the repo
## already paid for a window once.
func _ident_pixels(mat: Material) -> int:
	_ridge.set_surface_override_material(0, mat)
	for _k in 6:
		await get_tree().process_frame
	var img: Image = _sub.get_texture().get_image()
	# ASSERT THE SURFACE. A 0x0 image under the dummy driver would make
	# every count above a free pass, which is the whole family of failure
	# this phase was added to close.
	if img.get_width() < VP_SIZE.x or img.get_height() < VP_SIZE.y:
		push_error("MountainProbe PHASE G: the viewport rendered %dx%d -- run under xvfb with opengl3."
			% [img.get_width(), img.get_height()])
		return -1
	var n: int = 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.999 and c.g < 0.001 and c.b > 0.999:
				n += 1
	return n

## =====================================================================
## CH40 -- THE DRESSING
##
## Every MultiMesh instance of ground decor, as {node, index, origin}.
##
## The set of decor batches is taken from CozyScatter.batch_nodes(), which
## is the list _flush actually built -- NOT a blacklist of the nodes that
## are something else. A blacklist was written first and was wrong on its
## first run: it said "Butterflies" and the node is "Butterflies1", so a
## swarm flying at 1.06 u over the hill was counted as buried decor. A
## reader that has to recognise its subject is a reader that will be wrong
## the day a twelfth hand-built node appears.
##
## The transforms are read off the LIVE MultiMesh -- what the engine will
## draw -- and never off anything CozyScatter kept in a variable.
func _decor_instances() -> Array:
	var out: Array = []
	for name_of in (_scatter.call("batch_nodes") as Array):
		var mmi := _scatter.get_node_or_null(NodePath(String(name_of))) as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		for i in mmi.multimesh.instance_count:
			out.append({
				"node": String(mmi.name),
				"index": i,
				"origin": mmi.multimesh.get_instance_transform(i).origin,
			})
	return out

static func _in_domain(p: Vector3) -> bool:
	return p.x >= HubRegion.MOUNTAIN_MIN.x and p.x <= HubRegion.MOUNTAIN_MAX.x \
		and p.z >= HubRegion.MOUNTAIN_MIN.y and p.z <= HubRegion.MOUNTAIN_MAX.y

## How the domain is diced for the spread gate. 4 x 4 over 28 x 30 u is
## 7.0 x 7.5 u cells -- wider than the 2 u strip the old bound left, which
## is the whole point: a count floor could be met by piling everything in
## that strip, and a spread gate cannot.
const COVER_CELLS: int = 4
## And a floor on the total, so "one tuft per cell" cannot pass for cover.
const COVER_FLOOR: int = 40

## PHASE H -- the ridge is no longer bald.
##
## ⚠️ WHAT WAS WRONG. CozyScatter.COVER_MIN.x was -37 and
## HubRegion.MOUNTAIN_MIN.x is -63: the cover rectangle and the domain
## overlapped by exactly 2 u at the ridge's east rim. CH39 measured 21
## instances on the whole 840 u2 domain, every one of them in that strip,
## where the relief is already at h = 0. An unlit ground carries no shading
## on a slope (CH35-C; CH39 measured r^2 = 0.010 and 0.117 between slope
## and delivered luminance), so an object of KNOWN SIZE standing on the
## hillside is not decoration here -- it is the only instrument the player
## has for reading that the ground is tilted.
func _phase_h() -> void:
	print("-- PHASE H: the domain is covered, and covered EVENLY --")
	var all: Array = _decor_instances()
	var on_domain: int = 0
	var grid: Array[int] = []
	grid.resize(COVER_CELLS * COVER_CELLS)
	grid.fill(0)
	var w: float = (HubRegion.MOUNTAIN_MAX.x - HubRegion.MOUNTAIN_MIN.x) / float(COVER_CELLS)
	var h: float = (HubRegion.MOUNTAIN_MAX.y - HubRegion.MOUNTAIN_MIN.y) / float(COVER_CELLS)
	# BLIND FIRST, and it is a real absence: the great lake's own water is
	# inside the cover rectangle and inside the region, and the scatter
	# refuses it. An instrument that cannot report zero cannot report N.
	var blind: int = 0
	var lake: Vector3 = HubRegion.lakes()[0]["centre"]
	for e in all:
		var p: Vector3 = e["origin"]
		if Vector2(p.x - lake.x, p.z - lake.z).length() < float(HubRegion.lakes()[0]["radius"]) - 2.0:
			blind += 1
		if not _in_domain(p):
			continue
		on_domain += 1
		var cx: int = clampi(int((p.x - HubRegion.MOUNTAIN_MIN.x) / w), 0, COVER_CELLS - 1)
		var cz: int = clampi(int((p.z - HubRegion.MOUNTAIN_MIN.y) / h), 0, COVER_CELLS - 1)
		grid[cz * COVER_CELLS + cx] += 1
	_check(blind == 0, "BLIND: the counter reads %d instances inside the great lake" % blind)
	_check(all.size() > 0, "there is ground decor to count at all (%d instances)" % all.size())
	var empty: int = 0
	var line: String = ""
	for cz in COVER_CELLS:
		for cx in COVER_CELLS:
			var n: int = grid[cz * COVER_CELLS + cx]
			line += "%5d" % n
			if n == 0:
				empty += 1
		line += " |"
	print("     %d x %d cell counts: %s" % [COVER_CELLS, COVER_CELLS, line])
	print("     %d instances on the domain (%.4f per u2)"
		% [on_domain, float(on_domain) / 840.0])
	_check(on_domain >= COVER_FLOOR,
		"the domain carries %d instances (floor %d; it carried 21 with the old bound)"
		% [on_domain, COVER_FLOOR])
	_check(empty == 0, "%d of the %d cells of the domain are EMPTY"
		% [empty, COVER_CELLS * COVER_CELLS])
	# The bound is the region's, not a second spelling of -63.
	_check(is_equal_approx(CozyScatter.COVER_MIN.x, HubRegion.MOUNTAIN_MIN.x),
		"COVER_MIN.x %.1f is the region's own MOUNTAIN_MIN.x %.1f"
		% [CozyScatter.COVER_MIN.x, HubRegion.MOUNTAIN_MIN.x])

## How far an instance may sit off the surface under it. A MultiMesh
## transform is float32 and the grid is float32, so this is rounding and
## nothing else.
const GROUND_TOL: float = 1.0e-3

## PHASE I -- nothing floats, nothing is buried, and the lift is a no-op
## everywhere else.
##
## Both halves matter. The first is CH35-C's constraint on this lot: a
## prop planted at a supposed y on a 4.5 u hill is either hanging in the
## air or sunk in it, and neither reads as an object standing on ground.
## The second is the proof that taking HubSurface.ground() inside
## _sprinkle changed NOTHING off the domain -- height_at is 0 there by
## contract, and this walks every instance in the hub to say so rather
## than quoting the contract.
func _phase_i() -> void:
	print("-- PHASE I: every instance stands ON the surface under it --")
	var all: Array = _decor_instances()
	var worst_on: float = 0.0
	var worst_off: float = 0.0
	var where: String = ""
	var n_on: int = 0
	for e in all:
		var p: Vector3 = e["origin"]
		if _in_domain(p):
			n_on += 1
			var d: float = absf(p.y - HubSurface.height_at(p))
			if d > worst_on:
				worst_on = d
				where = "%s[%d] at (%.2f, %.2f) y %.4f vs surface %.4f" \
					% [e["node"], e["index"], p.x, p.z, p.y, HubSurface.height_at(p)]
		else:
			worst_off = maxf(worst_off, absf(p.y))
	_check(n_on > 0, "there are instances on the domain to check (%d)" % n_on)
	_check(worst_on <= GROUND_TOL,
		"worst gap to the surface on the domain %.6f u (tolerance %.6f)%s"
		% [worst_on, GROUND_TOL, "" if where == "" else " -- worst: " + where])
	_check(worst_off <= GROUND_TOL,
		"off the domain every one of %d instances is still at y = 0 (worst %.6f)"
		% [all.size() - n_on, worst_off])
	# AND NO BLOB SHADOW ON THE RELIEF. _blob_shadows draws FLAT horizontal
	# quads at a fixed y; there is no correct height for one on a 28 deg
	# slope, so CozyScatter refuses to emit any on a domain rather than
	# emitting a wrong one. Counted here because the shadow batch is not a
	# decor batch and every count above skips it.
	var blobs: MultiMeshInstance3D = _scatter.get_node_or_null("BlobShadows") as MultiMeshInstance3D
	var on_relief: int = 0
	var blob_total: int = 0
	if blobs != null and blobs.multimesh != null:
		blob_total = blobs.multimesh.instance_count
		for i in blob_total:
			if _in_domain(blobs.multimesh.get_instance_transform(i).origin):
				on_relief += 1
	_check(blob_total > 0, "there are blob shadows at all (%d) -- a 0 would pass the next line for free" % blob_total)
	_check(on_relief == 0, "%d of the %d blob shadows stand on the relief" % [on_relief, blob_total])
	# BLIND: the gap test must be able to SAY NO. One instance is lifted by
	# half a unit in the LIVE MultiMesh, re-read through the same accessor,
	# and put back -- an assertion that has never been seen to fail is not
	# an assertion. Restored and re-read rather than assumed restored.
	var victim: MultiMeshInstance3D = null
	var v_index: int = -1
	for child in _scatter.get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		if not (String(mmi.name) in (_scatter.call("batch_nodes") as Array)):
			continue
		for i in mmi.multimesh.instance_count:
			if _in_domain(mmi.multimesh.get_instance_transform(i).origin):
				victim = mmi
				v_index = i
				break
		if victim != null:
			break
	if victim == null:
		_check(false, "BLIND: no instance on the domain to lift")
		return
	var kept: Transform3D = victim.multimesh.get_instance_transform(v_index)
	var lifted := kept
	lifted.origin.y += 0.5
	victim.multimesh.set_instance_transform(v_index, lifted)
	var seen: Vector3 = victim.multimesh.get_instance_transform(v_index).origin
	var flagged: bool = absf(seen.y - HubSurface.height_at(seen)) > GROUND_TOL
	victim.multimesh.set_instance_transform(v_index, kept)
	var back: Vector3 = victim.multimesh.get_instance_transform(v_index).origin
	_check(flagged, "BLIND: a 0.5 u lift on %s[%d] IS caught by the same test"
		% [victim.name, v_index])
	_check(back.distance_to(kept.origin) < 1.0e-6,
		"BLIND: and the instance is back where it was (%.9f u)" % back.distance_to(kept.origin))

## The two stations Mathieu read on device for CH39 (iPhone, Safari,
## staging): the dome he could see, and the one where the hill vanished.
## Every CH40 render and both pixel gates are taken here, so a sandbox
## number and a device number are about the same two points.
const DEVICE_STATIONS: Array[Vector3] = [
	Vector3(-46.4, 0.0, 13.0),
	Vector3(-50.4, 0.0, 5.8),
]

## Triangles of a mesh, counted on the FACES it will draw. Cached because
## the dressing shares four meshes across fifty instances.
var _tri_cache: Dictionary = {}

func _mesh_tris(mesh: Mesh) -> int:
	var key: String = str(mesh.get_rid())
	if _tri_cache.has(key):
		return int(_tri_cache[key])
	var n: int = mesh.get_faces().size() / 3
	_tri_cache[key] = n
	return n

## The dressing's own batch nodes -- the ones whose family CozyScatter
## published in RIDGE_FAMILIES. Read off that list rather than off a name
## prefix invented here: the pass owns its families, and a probe that
## re-derived them would be a second spelling of the same fact.
func _ridge_nodes() -> Array[MultiMeshInstance3D]:
	var out: Array[MultiMeshInstance3D] = []
	for name_of in (_scatter.call("batch_nodes") as Array):
		for family in CozyScatter.RIDGE_FAMILIES:
			if String(name_of).begins_with(family + "_"):
				var mmi := _scatter.get_node_or_null(NodePath(String(name_of))) as MultiMeshInstance3D
				if mmi != null:
					out.append(mmi)
				break
	return out

## PHASE J -- what the dressing costs, and the contract it may not break.
##
## TWO READINGS, and they answer two different questions.
##
##   SUBMITTED is arithmetic: every decor instance whose (x, z) is on the
##   domain, times the triangles of the mesh that instance draws. It is an
##   UPPER BOUND on what any frame can pay for this domain -- the frustum
##   and the LOD can only take away -- and it is the only reading that
##   covers the thinned carpet as well, because a carpet batch is a CELL
##   batch shared with ground off the ridge and cannot be hidden on its
##   own without corrupting it (CH23: growing or rewriting a MultiMesh
##   from outside zeroes what is already in it).
##
##   MEASURED is the CH38 method: hide the dressing's own nodes and re-read
##   the SAME frame, at 8 stations x 2 camera heights. That prices the
##   props, on the `engine_prims` line a device pays.
##
## Both are gated on CozyScatter.RIDGE_TRIANGLE_BUDGET, which has been in
## the file since the commit that created the pass.
func _phase_j() -> void:
	print("-- PHASE J: the dressing's triangle budget, submitted and measured --")
	# THE CONTRACT FIRST. The pass plants instances; it may not have moved
	# the domain, changed its shape, or made it cross a palette band --
	# register_domain refuses all three, and this re-reads the answer.
	var index: int = HubMountain.register()
	_check(index >= 0, "the domain is still registered after the dressing (index %d)" % index)
	var box: Rect2 = HubSurface.domains()[index]["aabb"]
	_check(is_equal_approx(box.position.x, HubRegion.MOUNTAIN_MIN.x)
			and is_equal_approx(box.position.y, HubRegion.MOUNTAIN_MIN.y)
			and is_equal_approx(box.end.x, HubRegion.MOUNTAIN_MAX.x)
			and is_equal_approx(box.end.y, HubRegion.MOUNTAIN_MAX.y),
		"and its AABB is unchanged: x [%.1f, %.1f] z [%.1f, %.1f]"
		% [box.position.x, box.end.x, box.position.y, box.end.y])

	var submitted: int = 0
	var dressing_pieces: int = 0
	var carpet_pieces: int = 0
	var ridge_names: Array[String] = []
	for mmi in _ridge_nodes():
		ridge_names.append(String(mmi.name))
	var per_family: Dictionary = {}
	for name_of in (_scatter.call("batch_nodes") as Array):
		var mmi := _scatter.get_node_or_null(NodePath(String(name_of))) as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		var tris: int = _mesh_tris(mmi.multimesh.mesh)
		for i in mmi.multimesh.instance_count:
			if not _in_domain(mmi.multimesh.get_instance_transform(i).origin):
				continue
			submitted += tris
			if String(name_of) in ridge_names:
				dressing_pieces += 1
				per_family[String(name_of)] = int(per_family.get(String(name_of), 0)) + 1
			else:
				carpet_pieces += 1
	for k in per_family:
		print("     %-40s %d" % [k, per_family[k]])
	print("     %d dressing pieces + %d carpet pieces on the domain, %d triangles submitted"
		% [dressing_pieces, carpet_pieces, submitted])
	print("     densities: dressing %.4f /u2, carpet %.4f /u2, total %.4f /u2 (plateau carpet is 0.4488)"
		% [dressing_pieces / 840.0, carpet_pieces / 840.0, (dressing_pieces + carpet_pieces) / 840.0])
	_check(dressing_pieces > 0, "the dressing put something down at all (%d pieces)" % dressing_pieces)
	_check(submitted <= CozyScatter.RIDGE_TRIANGLE_BUDGET,
		"SUBMITTED: %d triangles stand on the domain, ceiling %d"
		% [submitted, CozyScatter.RIDGE_TRIANGLE_BUDGET])

	# ⚠️ AND THE COUNTER HAS A NOISE FLOOR, WHICH THIS PHASE LEARNED THE
	# HARD WAY. The red-before-green pass that stops the dressing pass from
	# running left _ridge_nodes() EMPTY, so "hide them and re-read" hid
	# nothing -- and the frame still moved by +64 primitives between two
	# reads. "The dressing costs something" came back GREEN over a hill
	# with nothing on it, which is the CH39 family of failure exactly: an
	# assertion of presence answered by an instrument that was never
	# connected to the subject. So the delta is now measured against the
	# counter's OWN jitter, read at the same station with nothing touched
	# at all, and the phase asserts there is something to hide first.
	var nodes_to_hide: int = _ridge_nodes().size()
	_check(nodes_to_hide > 0, "there are dressing batches to hide (%d) -- with none, hiding them changes nothing and every delta below is jitter" % nodes_to_hide)
	var stations := _stations()
	var worst: int = 0
	var worst_where: String = ""
	var worst_on: int = 0
	var worst_noise: int = 0
	for hi_cam in [false, true]:
		for st in stations:
			_keepy.global_position = HubSurface.ground(st)
			if _camera.has_method("snap_to_target"):
				_camera.call("snap_to_target")
			if hi_cam:
				_camera.global_position = HubSurface.ground(st) + HubCamera.OFFSET + Vector3(0.0, 4.0, 0.0)
			await get_tree().process_frame
			await get_tree().process_frame
			var on: int = _prims()
			# The control: two more frames, NOTHING touched.
			await get_tree().process_frame
			await get_tree().process_frame
			var again: int = _prims()
			worst_noise = maxi(worst_noise, absi(again - on))
			for mmi in _ridge_nodes():
				mmi.visible = false
			await get_tree().process_frame
			await get_tree().process_frame
			var off: int = _prims()
			for mmi in _ridge_nodes():
				mmi.visible = true
			var delta: int = on - off
			print("     station (%6.1f, %6.1f) cam %s : on %6d  off %6d  delta %+6d  (jitter %d)"
				% [st.x, st.z, "high" if hi_cam else "flat", on, off, delta, absi(again - on)])
			if delta > worst:
				worst = delta
				worst_where = "(%.1f, %.1f) cam %s" % [st.x, st.z, "high" if hi_cam else "flat"]
				worst_on = on
	_check(worst_on > 0, "the engine counter is filled at all (worst frame reads %d)" % worst_on)
	_check(worst > worst_noise,
		"MEASURED: the dressing costs %d primitives, clear of the counter's own jitter of %d"
		% [worst, worst_noise])
	_check(worst <= CozyScatter.RIDGE_TRIANGLE_BUDGET,
		"MEASURED: worst added primitives %d at %s, ceiling %d"
		% [worst, worst_where, CozyScatter.RIDGE_TRIANGLE_BUDGET])

## PHASE K -- the apex, and the frame of a camera that never tilts.
##
## ⚠️ THE NUMBER THAT BITES HERE IS A SUM, AND THIS REPO HAS PAID FOR
## HALF-SUMS BEFORE. A conifer GLB is 4.871 u tall; on flat ground that is
## comfortably inside CH36's 9 u ceiling for a foot 30 u away. On the crown
## of a 4.5 u hill it is 9.37 u BEFORE any scale, and the half that made it
## fail is the one nobody types. The apex is measured on the mesh AS
## BUILT -- the drawn AABB of the batch's own mesh, times the instance's
## own scale -- never on a constant in the pass.
func _phase_k() -> void:
	print("-- PHASE K: no piece of the dressing leaves the top of the frame --")
	var worst: float = -1.0
	var where: String = ""
	var n: int = 0
	var tallest: Vector3 = Vector3.ZERO
	for mmi in _ridge_nodes():
		if mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		var top: float = mmi.multimesh.mesh.get_aabb().end.y
		for i in mmi.multimesh.instance_count:
			var t: Transform3D = mmi.multimesh.get_instance_transform(i)
			var apex: float = t.origin.y + top * t.basis.get_scale().y
			n += 1
			if apex > worst:
				worst = apex
				where = "%s[%d] at (%.2f, %.2f)" % [mmi.name, i, t.origin.x, t.origin.z]
				tallest = Vector3(t.origin.x, apex, t.origin.z)
	_check(n > 0, "there are dressed pieces to measure (%d)" % n)
	_check(worst <= MAX_VISIBLE_RISE,
		"tallest apex %.3f u at %s, ceiling %.1f u" % [worst, where, MAX_VISIBLE_RISE])
	# BLIND: the ceiling has to be able to REFUSE. The same arithmetic on
	# the same piece at twice its scale must break it -- an assertion never
	# seen to fail is not an assertion.
	var doubled: float = tallest.y + (worst - tallest.y)
	for mmi in _ridge_nodes():
		if mmi.multimesh == null or mmi.multimesh.mesh == null or mmi.multimesh.instance_count == 0:
			continue
		var top: float = mmi.multimesh.mesh.get_aabb().end.y
		var t: Transform3D = mmi.multimesh.get_instance_transform(0)
		doubled = maxf(doubled, t.origin.y + top * t.basis.get_scale().y * 3.0)
	_check(doubled > MAX_VISIBLE_RISE,
		"BLIND: the same pieces at 3x scale WOULD break the ceiling (%.3f u)" % doubled)
	# And the tallest piece, projected on the REAL camera from the station
	# CH38 called the weakest -- unproject on the rig itself, never an
	# elevation angle worked out on paper (CH36 found one wrong by 1.01 u).
	var st: Vector3 = DEVICE_STATIONS[0]
	_keepy.global_position = HubSurface.ground(st)
	if _camera.has_method("snap_to_target"):
		_camera.call("snap_to_target")
	var screen: Vector2 = _camera.unproject_position(tallest)
	var in_front: bool = not _camera.is_position_behind(tallest)
	print("     tallest apex %s projects to (%.1f, %.1f) of %dx%d from (%.1f, %.1f)"
		% [tallest, screen.x, screen.y, _sub.size.x, _sub.size.y, st.x, st.z])
	_check(in_front and screen.y >= 0.0,
		"and it is not cut by the top of the frame (screen y %.1f, top is 0)" % screen.y)

## Ident pass for the dressing, in a colour nothing in this hub carries.
## A MASK, not a window: a pixel belongs to the dressing IFF it comes back
## exactly (0, 1, 1). The repo paid for a window once already.
const IDENT_DRESSING: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;
void fragment() { ALBEDO = vec3(0.0, 1.0, 1.0); }
"""
## What the dressing must own of the frame from a station standing on the
## hill. Small on purpose -- this is "it is on screen at all", the same
## shape of floor PHASE G uses, and the thing being refused is a pass that
## planted fifty pieces none of which the camera can see.
const DRESSING_MIN_COVERAGE: float = 0.005

func _phase_l() -> void:
	print("-- PHASE L: the dressing's own pixels, at the two device stations --")
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = IDENT_DRESSING
	var nodes := _ridge_nodes()
	var kept: Array[Material] = []
	for mmi in nodes:
		kept.append(mmi.material_override)
	var total: float = float((VP_SIZE.x / 2) * (VP_SIZE.y / 2))
	for st in DEVICE_STATIONS:
		_keepy.global_position = HubSurface.ground(st)
		if _camera.has_method("snap_to_target"):
			_camera.call("snap_to_target")
		# BLIND FIRST: hidden, the mask must read zero. Coverage is an
		# assertion of PRESENCE and passes for free against an instrument
		# that cannot say no -- three of them did exactly that in this repo.
		for mmi in nodes:
			mmi.material_override = mat
			mmi.visible = false
		var blind: int = await _mask_pixels()
		for mmi in nodes:
			mmi.visible = true
		var painted: int = await _mask_pixels()
		for i in nodes.size():
			nodes[i].material_override = kept[i]
		_check(blind == 0, "station (%.1f, %.1f): hidden, the dressing mask reads %d pixels"
			% [st.x, st.z, blind])
		_check(float(painted) / total >= DRESSING_MIN_COVERAGE,
			"station (%.1f, %.1f): the dressing owns %.3f %% of the frame (floor %.1f %%)"
			% [st.x, st.z, 100.0 * float(painted) / total, 100.0 * DRESSING_MIN_COVERAGE])

func _mask_pixels() -> int:
	for _k in 6:
		await get_tree().process_frame
	var img: Image = _sub.get_texture().get_image()
	if img.get_width() < VP_SIZE.x or img.get_height() < VP_SIZE.y:
		push_error("MountainProbe PHASE L: the viewport rendered %dx%d -- run under xvfb with opengl3."
			% [img.get_width(), img.get_height()])
		return -1
	var n: int = 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			if c.r < 0.001 and c.g > 0.999 and c.b > 0.999:
				n += 1
	return n

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
