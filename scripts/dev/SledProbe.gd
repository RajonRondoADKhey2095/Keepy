extends Node
## CH41 -- THE ELECTRIC SLED, and the composite that puts a vehicle on the
## ground instead of on the y = 0 plane.
##
## =====================================================================
## RUN IT UNDER XVFB, NOT --headless
##
##   xvfb-run --auto-servernum -- godot4 --rendering-driver opengl3 \
##     --fixed-fps 60 --path . res://scripts/dev/SledProbe.tscn
##
## PHASE H renders the sled twice through two face tests and PHASE I reads
## RenderingServer's per-viewport primitive counter: the dummy driver
## fills neither, and both would pass by measuring nothing. The flags go
## BEFORE the `--`.
##
## =====================================================================
## WHAT IT GATES
##
##   BLIND  the slope accessors can say NO -- gradient_at is EXACTLY zero
##          off a domain and with no domain at all, so every "the hill
##          pushed it" assertion below cannot pass against a flat world
##   A      HubSurface.gradient_at IS the plane of the DRAWN triangle,
##          compared against HubMountain's committed mesh face by face
##   B      SurfaceDrive is a NO-OP on flat ground: 600 frames beside a
##          bare VehicleDrive on identical input, identical to the bit --
##          which is what lets the kart, the yacht and the boat stay where
##          they are without being re-measured
##   C      y == height_at on EVERY physics frame of a real drive, and the
##          y actually MOVED while it was being checked
##   D      the chassis IS the surface normal at rest, and never more than
##          ONE FACET behind it while driving -- the facet step being
##          measured off the relief, not picked
##   E      DESCENT IS FASTER THAN ASCENT -- with the grade printed at
##          BOTH ENDS of both legs, a CONTROL PAIR with the hill switched
##          off for the noise floor, a COASTING pair that isolates the
##          gravity from the raised ceiling, and the verrou's own
##          measurement (what the ceiling buys over the damping alone)
##   F      it never leaves the map, over a long steered drive
##   G      mount and dismount, on the live hub, with no lock-up
##   H      THE WINDING: every triangle's right-hand normal points into
##          the solid, and cull_back covers the same pixels as
##          cull_disabled. CH39 is why this is a render and not a proof
##   I      what the sled costs the frame, 8 stations x 2 camera heights,
##          against the counter's own jitter
##   J      the CHASE camera clears the ground on every slope of the
##          domain -- this is the first vehicle to drive one
##
## Exit 0 all green, 1 any red, ProbeWatchdog.EXIT_TIMEOUT = INCONCLUSIVE.

const VP_SIZE: Vector2i = Vector2i(1080, 1920)
const BUDGET_S: float = 900.0

## PHASE B's length, and it is long on purpose: the float32 heading cell
## inside VehicleDrive separates two builds at the last printed digit by
## frame 30 (CH30), so a short comparison proves nothing.
const NOOP_FRAMES: int = 600
const FIXED_DELTA: float = 1.0 / 60.0
## PHASE E's LONG run, in physics frames -- 4 s, long enough for a whole
## flank and for the raised ceiling to be reached. Used for the verrou
## measurement only, where crossing the summit does not matter.
const RUN_FRAMES: int = 240
## PHASE E's SYMMETRIC pair, and it is short ON PURPOSE.
##
## ⚠️ THE FIRST VERSION RAN THE PAIR AT 240 FRAMES AND THE UPHILL LEG
## MEASURED 19.597 u/s -- FASTER THAN THE DESCENT. It was not wrong about
## the number: in 4 s the sled climbed the flank, went OVER the summit and
## came down the far side at full tilt. The reading was honest and the
## question was not the one being asked. 90 frames is 1.5 s, which on this
## hill keeps both legs on the flank they started on -- and the phase
## checks the SIGN of the grade at both ends of both legs rather than
## trusting that.
const LEG_FRAMES: int = 90
## PHASE F's steered drive.
const ROAM_FRAMES: int = 1800
## PHASE E's control legs. Shorter than a run leg because a control has to
## fit inside ground the vehicle cannot leave: at MAX_SPEED_FLAT, 120
## frames is 17 u and the ridge rectangle holds that in both directions.
const CONTROL_FRAMES: int = 120

## PHASE A's tolerance on "the gradient IS the drawn face". Not zero, and
## the reason is float32: the grid HubSurface samples and the vertices the
## mesh draws are the SAME float32 values, but the face plane is recovered
## from a cross product of three of them and the query divides two of
## them, and those are different roundings of the same numbers. Measured
## worst over the ridge's 1 680 faces: 1.2e-4 on a gradient of 0.53, which
## is 2.3e-4 relative -- 0.013 deg of tilt. A ceiling of 1e-3 refuses a
## wrong triangulation (the blind below reads 9e-3, an order of magnitude
## out) while admitting the arithmetic's own noise.
const FACE_TOL: float = 1.0e-3
## How far the two face tests may disagree, PHASE H. MountainProbe's
## number and its reason: a silhouette is a row of pixels wide.
const CULL_TOLERANCE: float = 0.01

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

var _fails: int = 0
var _hub: Node = null
var _transport: HubTransport = null
var _sled: SledBody = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _sub: SubViewport = null

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract.
	ProbeWatchdog.arm(self, "SLED PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_transport = _hub.get_node("WorldViewport/SubViewport/World/Transport") as HubTransport
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as Node3D
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	_sub.size = VP_SIZE
	_run()

func _run() -> void:
	_sled = _transport.sled()
	print("=== SLED PROBE -- CH41 ===")
	print("  park %s  seat %.2f  triangles %d"
		% [HubTransport.SLED_PARK, SledBody.SEAT_Y, _mesh_tris(SledBody.build_mesh())])
	print("  caps: flat %.2f  downhill %.2f  slope_gain %.2f  over_lambda %.2f"
		% [SledBody.MAX_SPEED_FLAT, SledBody.MAX_SPEED_DOWNHILL,
			SledBody.SLOPE_GAIN, SledBody.OVER_LAMBDA])
	_phase_blind()
	_phase_a()
	_phase_b()
	_phase_c()
	_phase_d()
	_phase_e()
	_phase_f()
	await _phase_g()
	await _phase_h()
	await _phase_i()
	_phase_j()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

## The summit, READ OFF THE REGISTERED GRID and not off HubMountain.BUMPS:
## the grid is the surface, and the analytic maximum would be a second
## opinion of it. MountainProbe's own _summit(), same reason.
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

func _mesh_tris(m: Mesh) -> int:
	return m.get_faces().size() / 3

## =====================================================================
## PHASE BLIND -- prove the instrument can answer NO.
##
## Every phase below is of the form "the hill did something". A flat world
## satisfies most of those for free (nothing moved, so nothing is wrong),
## which is the family of failure this repo has watched pass green three
## times over a mechanism that was never wired. So: the accessors are made
## to say ZERO first, on a point where they later say something else.
func _phase_blind() -> void:
	print("-- PHASE BLIND: zero off the domain, and zero without one --")
	var off := Vector3(0.0, 0.0, 0.0)
	_check(HubSurface.gradient_at(off) == Vector2.ZERO,
		"gradient_at(spawn) is exactly %s off the domain" % HubSurface.gradient_at(off))
	_check(HubSurface.normal_at(off) == Vector3.UP,
		"normal_at(spawn) is exactly %s" % HubSurface.normal_at(off))
	_check(SurfaceDrive.slope_accel_at(off) == Vector3.ZERO,
		"slope_accel_at(spawn) is exactly %s -- the force adds NOTHING on a flat hub"
		% SurfaceDrive.slope_accel_at(off))
	# The flank, where the answer must NOT be zero -- and the same point
	# with no domain at all, which is the half that gives the first half
	# its meaning.
	var flank := _steep_point()
	var live: Vector2 = HubSurface.gradient_at(flank)
	var saved: Array[Dictionary] = []
	for d in HubSurface.domains():
		saved.append(d)
	HubSurface.clear_domains()
	var blind: Vector2 = HubSurface.gradient_at(flank)
	var blind_a: Vector3 = SurfaceDrive.slope_accel_at(flank)
	for d in saved:
		HubSurface.domains().append(d)
	var back: Vector2 = HubSurface.gradient_at(flank)
	_check(blind == Vector2.ZERO, "with no domain the flank reads %s" % blind)
	_check(blind_a == Vector3.ZERO, "and its slope force reads %s" % blind_a)
	_check(live.length() > 0.2, "with the domain the SAME point reads %s (|g| %.4f, %.3f deg)"
		% [live, live.length(), rad_to_deg(atan(live.length()))])
	_check(back == live, "and reads %s again once restored" % back)

## The steepest lattice point of the domain, measured on the grid. PHASE
## BLIND, D and E all want "somewhere it is actually steep" and this is
## the one place that answer is computed.
func _steep_point() -> Vector3:
	var best := Vector3.ZERO
	var worst: float = -1.0
	for r in HubMountain.rows() - 1:
		var z: float = HubRegion.MOUNTAIN_MIN.y + (float(r) + 0.5) * HubMountain.PITCH
		for c in HubMountain.columns() - 1:
			var x: float = HubRegion.MOUNTAIN_MIN.x + (float(c) + 0.5) * HubMountain.PITCH
			var p := Vector3(x, 0.0, z)
			var g: float = HubSurface.gradient_at(p).length()
			if g > worst:
				worst = g
				best = p
	return best

## =====================================================================
## PHASE A -- the gradient IS the drawn triangle's plane.
##
## HubSurface's contract is "the feet land on the triangle you see". The
## normal a chassis leans on has to be that triangle's too, or the sled
## tilts onto a surface nobody is looking at -- the "fixture that diverges
## from the real thing" this repo closed in advance. So the answer is
## compared against the COMMITTED MESH, face by face, and not against a
## second evaluation of the height function.
func _phase_a() -> void:
	print("-- PHASE A: gradient_at is the plane of the drawn triangle --")
	var mesh: ArrayMesh = HubMountain.build_mesh()
	var faces: PackedVector3Array = mesh.get_faces()
	var worst: float = 0.0
	var worst_at: String = ""
	var tested: int = 0
	# Every triangle's own centroid: a point that is unambiguously inside
	# ONE triangle, so there is no edge case to argue about.
	for i in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		var centre: Vector3 = (a + b + c) / 3.0
		var flat := Vector3(centre.x, 0.0, centre.z)
		# The triangle's own plane, from its three drawn vertices.
		var n: Vector3 = (b - a).cross(c - a)
		if absf(n.y) < 1.0e-9:
			continue
		# h = h0 - (nx (x-x0) + nz (z-z0)) / ny  ->  dh/dx = -nx/ny
		var want := Vector2(-n.x / n.y, -n.z / n.y)
		var got: Vector2 = HubSurface.gradient_at(flat)
		var err: float = (got - want).length()
		if err > worst:
			worst = err
			worst_at = "(%.1f, %.1f)" % [flat.x, flat.z]
		tested += 1
	_check(tested > 1000, "compared %d drawn triangles" % tested)
	print("     worst disagreement with a drawn face: %.9f at %s" % [worst, worst_at])
	_check(worst < FACE_TOL, "worst disagreement with a drawn face: %.9f at %s (ceiling %.6f)"
		% [worst, worst_at, FACE_TOL])
	# BLIND: the test must be able to FAIL. The other diagonal of the same
	# cell is a real plane through real grid points, and it is a DIFFERENT
	# plane wherever the cell is not itself flat -- so a probe that could
	# not tell the two apart would be measuring nothing.
	var flank := _steep_point()
	var pitch: float = HubMountain.PITCH
	var here: float = HubSurface.height_at(flank)
	var dx: float = HubSurface.height_at(flank + Vector3(pitch, 0.0, 0.0)) - here
	var wrong := Vector2(dx / pitch, HubSurface.gradient_at(flank).y)
	_check((wrong - HubSurface.gradient_at(flank)).length() > 1.0e-4,
		"blind: a CHORD across the next cell reads %s where the face reads %s -- the two are distinguishable"
		% [wrong, HubSurface.gradient_at(flank)])

## =====================================================================
## PHASE B -- SurfaceDrive is a NO-OP on flat ground.
##
## This is the phase that lets the kart, the sand yacht and the sailboat
## stay exactly where they are. CH35 Q2 recommended the composite BECAUSE
## it is arithmetically identical to VehicleDrive wherever height_at is 0,
## and "identical" is a measurement, not an argument: the same input is
## pushed through both for 600 frames and the two are compared to the bit.
##
## ⚠️ THE INPUT IS NOT CONSTANT. A straight-line run at full throttle
## would agree between almost any two models; the steering has to be
## exercised, because it is the steering that feeds back into the line and
## it is the steering that carries VehicleDrive's float32 heading cell.
func _phase_b() -> void:
	print("-- PHASE B: on flat ground the composite is VehicleDrive, to the bit --")
	var bare := VehicleDrive.new()
	var comp := SurfaceDrive.new()
	# The sled's own numbers on both, so this is the model the game runs.
	for m in [bare, comp.motion]:
		m.max_speed = SledBody.MAX_SPEED_FLAT
		m.max_speed_off = SledBody.OFF_SPEED
		m.reverse_speed = SledBody.REVERSE_SPEED
		m.boost_speed_ratio = SledBody.BOOST_RATIO
		m.accel_lambda = SledBody.ACCEL_LAMBDA
		m.coast_lambda = SledBody.COAST_LAMBDA
		m.off_lambda = SledBody.OVER_LAMBDA
		m.brake_decel = SledBody.BRAKE_DECEL
		m.steer_full_speed = SledBody.STEER_FULL_SPEED
		m.steer_high_speed_keep = SledBody.STEER_HIGH_SPEED_KEEP
		m.grip_on = SledBody.GRIP_ON
		m.grip_off = SledBody.GRIP_OFF
		m.scrub = SledBody.SCRUB
	var input := KartInput.new()
	var p1 := Vector3(0.0, 0.0, 20.0)
	var p2 := p1
	var y1: float = 0.0
	var y2: float = 0.0
	var v1 := Vector3.ZERO
	var v2 := Vector3.ZERO
	var same := true
	var worst: float = 0.0
	for f in NOOP_FRAMES:
		input.throttle = 1.0
		input.brake = false
		input.boost = 0.0
		# A steering wave, so the heading is worked and the two models are
		# compared on the term that actually separates builds.
		input.steer = sin(float(f) * 0.031) * 0.9
		var o1: Dictionary = bare.step(p1, y1, v1, FIXED_DELTA, input, true,
			SledBody.WORLD_FENCE, 7.0)
		var o2: Dictionary = comp.step(p2, y2, v2, FIXED_DELTA, input, true,
			SledBody.WORLD_FENCE, 7.0)
		p1 = o1["position"]
		y1 = o1["yaw"]
		v1 = o1["velocity"]
		p2 = o2["position"]
		y2 = o2["yaw"]
		v2 = o2["velocity"]
		var d: float = maxf((p1 - p2).length(), (v1 - v2).length())
		worst = maxf(worst, maxf(d, absf(y1 - y2)))
		if p1 != p2 or y1 != y2 or v1 != v2:
			same = false
	_check(same, "%d frames, byte-identical position / yaw / velocity (worst delta %.9f)"
		% [NOOP_FRAMES, worst])
	_check(p1.length() > 5.0, "and the run actually went somewhere (%.2f u from the start)" % p1.length())
	# BLIND: the comparison must be able to SEE a difference. The same 600
	# frames started ON the ridge diverge -- so "identical" above is a
	# result and not the two models never having been exercised.
	var flank := _steep_point()
	var q1: Vector3 = flank
	var q2: Vector3 = flank
	var w1: float = 0.0
	var w2: float = 0.0
	var u1 := Vector3.ZERO
	var u2 := Vector3.ZERO
	for f in NOOP_FRAMES:
		input.steer = sin(float(f) * 0.031) * 0.9
		var o1: Dictionary = bare.step(q1, w1, u1, FIXED_DELTA, input, true, SledBody.WORLD_FENCE, 7.0)
		var o2: Dictionary = comp.step(q2, w2, u2, FIXED_DELTA, input, true, SledBody.WORLD_FENCE, 7.0)
		q1 = o1["position"]
		w1 = o1["yaw"]
		u1 = o1["velocity"]
		q2 = o2["position"]
		w2 = o2["yaw"]
		u2 = o2["velocity"]
	# The gate is against the FLAT number, which was exactly 0.000000000
	# above: any separation at all is a separation the comparison saw.
	_check(Vector2(q1.x - q2.x, q1.z - q2.z).length() > 0.005,
		"blind: the SAME %d frames started on the ridge separate by %.4f u in xz -- the comparison can see"
		% [NOOP_FRAMES, Vector2(q1.x - q2.x, q1.z - q2.z).length()])

## =====================================================================
## PHASE C -- y == height_at on every physics frame of a real drive.
func _phase_c() -> void:
	print("-- PHASE C: the sled is ON the ground, every frame --")
	var start := _summit()
	_sled.place(Vector3(start.x, 0.0, start.z), 0.0)
	var input := KartInput.new()
	input.throttle = 1.0
	var worst: float = 0.0
	var lowest: float = INF
	var highest: float = -INF
	for f in RUN_FRAMES * 3:
		input.steer = sin(float(f) * 0.017) * 0.6
		_sled.drive(FIXED_DELTA, input)
		var want: float = HubSurface.height_at(_sled.flat_position())
		worst = maxf(worst, absf(_sled.global_position.y - want))
		lowest = minf(lowest, _sled.global_position.y)
		highest = maxf(highest, _sled.global_position.y)
	_check(worst < 1.0e-5, "%d physics frames, worst |y - height_at| = %.9f" % [RUN_FRAMES * 3, worst])
	# THE HALF THAT MATTERS. y == height_at is satisfied for free by
	# 0 == 0: unless the y MOVED while it was being checked, this phase
	# proves nothing at all.
	_check(highest - lowest > 1.0,
		"and the y actually moved while being checked: %.3f .. %.3f u (span %.3f)"
		% [lowest, highest, highest - lowest])

## =====================================================================
## PHASE D -- the chassis settles on the surface normal.
func _phase_d() -> void:
	print("-- PHASE D: the chassis is on the ground\'s normal --")
	var flank := _steep_point()
	var n: Vector3 = HubSurface.normal_at(flank)
	var tilt: float = rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))
	# BLIND FIRST: the ground under the test must actually be tilted, and
	# by how much is printed. On flat ground "the chassis is on the
	# normal" is "the chassis is level", which is true of a chassis that
	# was never written at all.
	_check(tilt > 5.0, "blind: the ground under the test is tilted %.3f deg (normal %s)" % [tilt, n])

	# ---- 1. AT REST, the chassis is the normal EXACTLY. place() reads the
	# surface and writes the body, so this is the basis construction with
	# no lag in it at all.
	_sled.place(flank, 0.0)
	var up0: Vector3 = _sled.deck().global_transform.basis.y.normalized()
	var err0: float = rad_to_deg(acos(clampf(up0.dot(n), -1.0, 1.0)))
	_check(err0 < 0.001, "parked: chassis up %s is the surface normal to %.6f deg" % [up0, err0])
	_check(rad_to_deg(acos(clampf(up0.dot(Vector3.UP), -1.0, 1.0))) > 5.0,
		"and it is %.3f deg off level, so it is not just an untouched node"
		% rad_to_deg(acos(clampf(up0.dot(Vector3.UP), -1.0, 1.0))))
	# The chassis basis is ORTHONORMAL and its forward still points along
	# the hull -- a basis built from a normal can be neither for free.
	var b: Basis = _sled.deck().transform.basis
	_check(absf(b.determinant() - 1.0) < 1.0e-4 and absf(b.x.dot(b.y)) < 1.0e-4
			and absf(b.y.dot(b.z)) < 1.0e-4,
		"and the chassis basis is orthonormal (det %.6f)" % b.determinant())

	# ---- 2. MOVING, the chassis is never more than ONE FACET behind.
	#
	# ⚠️ THE TOLERANCE IS MEASURED OFF THE MESH, NOT PICKED. HubSurface
	# publishes the DRAWN triangle\'s normal, which is exact and therefore
	# FACETED: the target the chassis chases jumps at every triangle
	# boundary, so a moving vehicle is always some fraction of one jump
	# behind. The size of that jump is a property of the relief and it is
	# read here, off the same grid the sled drives on. A fixed 0.5 deg
	# ceiling was used for one run and a red pass that changed only the
	# vehicle\'s SPEED walked it to 1.67 -- a tolerance that moves with the
	# thing it is not measuring.
	var facet: float = _worst_facet_step()
	# Pointed DOWN the slope at full throttle: the target normal then jumps
	# from facet to facet several times a second, which is the condition
	# the lag has to survive. A gentle throttle on a steep flank barely
	# moves and tests nothing -- measured at 0.048 u/s for one run.
	var g0: Vector2 = HubSurface.gradient_at(flank)
	_sled.place(flank, atan2(-g0.x, -g0.y))
	var input := KartInput.new()
	input.throttle = 1.0
	# ⚠️ SHORT ENOUGH TO STILL BE ON THE FLANK, AND THE PHASE CHECKS THAT.
	# This vehicle covers ground: at 60 frames the run reaches the FOOT of
	# the hill (14.99 u/s, ground tilted 1.096 deg), where an untilted
	# chassis matches the normal PERFECTLY -- the red pass that disabled
	# the chassis altogether read 0.0000 deg there and this assertion came
	# back GREEN over a body that was never written. 40 frames was still
	# on the flat. The tilt at the moment of reading is now a blind of its
	# own, so the day the relief or the pace changes this fails loudly
	# instead of going quietly free.
	for _f in 25:
		_sled.drive(FIXED_DELTA, input)
	var here: Vector3 = HubSurface.normal_at(_sled.flat_position())
	var up: Vector3 = _sled.deck().global_transform.basis.y.normalized()
	var err: float = rad_to_deg(acos(clampf(up.dot(here), -1.0, 1.0)))
	var under: float = rad_to_deg(acos(clampf(here.y, -1.0, 1.0)))
	print("     moving at %.3f u/s: chassis %.4f deg behind the ground (tilted %.3f deg), worst facet step on this relief %.4f deg"
		% [_sled.velocity.length(), err, under, facet])
	_check(under > 5.0,
		"blind: the ground under it AT THE MOMENT OF READING is still tilted %.3f deg -- on the flat this check is free"
		% under)
	_check(err < facet,
		"driving, the chassis is %.4f deg behind the ground -- under one facet step (%.4f deg)"
		% [err, facet])
	# And the body really is written FROM the smoothed normal, not from
	# something that happens to look like it.
	var sm: Vector3 = _sled.surface_normal().normalized()
	_check(rad_to_deg(acos(clampf(up.dot(sm), -1.0, 1.0))) < 0.001,
		"the chassis is built from the published smoothed normal, to %.6f deg"
		% rad_to_deg(acos(clampf(up.dot(sm), -1.0, 1.0))))

## The largest angle between two triangles that share an edge on the
## registered relief, in degrees -- the biggest single jump the chassis\'s
## target can make. Read off the GRID, which is the surface the sled
## drives on, so it moves with the relief instead of being a literal.
func _worst_facet_step() -> float:
	var worst: float = 0.0
	var pitch: float = HubMountain.PITCH
	for r in HubMountain.rows() - 1:
		for c in HubMountain.columns() - 1:
			var x: float = HubRegion.MOUNTAIN_MIN.x + float(c) * pitch
			var z: float = HubRegion.MOUNTAIN_MIN.y + float(r) * pitch
			# The two triangles of this cell, and the cell to the east.
			var a: Vector3 = HubSurface.normal_at(Vector3(x + pitch * 0.25, 0.0, z + pitch * 0.25))
			var b2: Vector3 = HubSurface.normal_at(Vector3(x + pitch * 0.75, 0.0, z + pitch * 0.75))
			var e: Vector3 = HubSurface.normal_at(Vector3(x + pitch * 1.25, 0.0, z + pitch * 0.25))
			worst = maxf(worst, rad_to_deg(acos(clampf(a.dot(b2), -1.0, 1.0))))
			worst = maxf(worst, rad_to_deg(acos(clampf(b2.dot(e), -1.0, 1.0))))
	return worst

## =====================================================================
## PHASE E -- DESCENT FASTER THAN ASCENT, and the verrou measured.
##
## THREE readings, and the first two are worthless without the third:
##
##   * downhill and uphill from the same point, same throttle;
##   * the SAME PAIR on flat ground, which is the NOISE FLOOR: if two
##     opposite headings differ on the plateau then the difference above
##     is the heading and not the hill, and CH40's own lesson is that a
##     delta without its floor is not a measurement;
##   * the verrou: the same downhill run with the CEILING LEFT FLAT, i.e.
##     the damping alone. That is what says whether raising max_speed per
##     instance was needed, and by how much -- the question CH35 Q2 asked
##     before anyone was allowed near VehicleDrive.gd.
func _phase_e() -> void:
	print("-- PHASE E: descent vs ascent, with a flat control and the verrou --")
	var flank := _steep_point()
	# The heading straight down the slope, and its opposite.
	var g: Vector2 = HubSurface.gradient_at(flank)
	var down_yaw: float = atan2(-g.x, -g.y)
	var up_yaw: float = down_yaw + PI
	var grade_down: float = SurfaceDrive.grade_at(flank, down_yaw)
	var grade_up: float = SurfaceDrive.grade_at(flank, up_yaw)
	# BLIND: the slope under the two runs is real, measured, and opposite.
	_check(grade_down > 0.2, "blind: the grade downhill is %+.4f (%.2f deg nose-down)"
		% [grade_down, rad_to_deg(atan(grade_down))])
	_check(grade_up < -0.2, "blind: and uphill %+.4f -- the same ground, the other way"
		% grade_up)
	# ⚠️ AND THE CLIMB HAS TO BE POSSIBLE AT ALL. This assertion exists
	# because the first run of this probe measured the sled FROZEN at
	# 0.000 u/s facing up this exact flank: the slope out-pushed the motor
	# from rest, VehicleDrive pulled the reversal to exactly zero, and at
	# zero speed there is no yaw authority -- a player trapped with no way
	# to steer off. It is gated on the relation, not on the symptom.
	var force: float = SledBody.slope_force(g)
	var authority: float = SledBody.climb_authority()
	_check(force < authority,
		"the slope pushes %.4f u/s2 on the steepest ground and the motor answers %.4f from rest (%.0f %% used)"
		% [force, authority, 100.0 * force / authority])
	var down: Dictionary = _run_leg(flank, down_yaw, true, LEG_FRAMES)
	var up: Dictionary = _run_leg(flank, up_yaw, true, LEG_FRAMES)
	print("     DOWNHILL  top %.3f u/s  mean %.3f  travelled %.2f u  grade %+.4f -> %+.4f"
		% [down["top"], down["mean"], down["travel"], down["grade_start"], down["grade_end"]])
	print("     UPHILL    top %.3f u/s  mean %.3f  travelled %.2f u  grade %+.4f -> %+.4f"
		% [up["top"], up["mean"], up["travel"], up["grade_start"], up["grade_end"]])
	# THE LEGS MEASURED WHAT THEY SAY: NEITHER CROSSED THE SUMMIT. What is
	# forbidden is a REVERSAL of sign -- an "uphill" leg that ends up
	# descending, which is exactly how the 240-frame version reported an
	# uphill run at 19.6 u/s and was believed for one run. Running OUT of
	# the flank onto the flat (grade 0) is not a reversal: the downhill leg
	# covers 17.5 u and the flank is 14 u of radius, so it reaches the foot
	# with its top speed already made.
	_check(float(down["grade_end"]) >= -0.01,
		"the downhill leg never turned into a climb (%+.4f at its end)" % down["grade_end"])
	_check(float(up["grade_end"]) <= 0.01,
		"and the uphill leg never turned into a descent (%+.4f at its end) -- neither crossed the summit"
		% up["grade_end"])
	_check(up["travel"] > 1.0,
		"and the UPHILL run still climbs rather than freezing: %.3f u at %.3f u/s mean"
		% [up["travel"], up["mean"]])
	# ⚠️ THE CONTROL IS THE SAME POINT WITH THE DOMAIN TURNED OFF, and the
	# two versions before it were both wrong in the same way.
	#
	# The question is "does the HEADING alone move this number", so the
	# control has to differ from the runs above in the SLOPE and in
	# nothing else. Putting it somewhere flat on the plateau does not:
	# a straight 34 u leg and its opposite need 68 u of clear map, this
	# hub has no such corridor, and the first version's "noise floor"
	# was one leg meeting a region wall (0.2003 u/s, entirely a bounce).
	# Clearing the domain leaves the same start, the same two headings,
	# the same region and the same walls -- and no hill.
	var saved_domains: Array[Dictionary] = []
	for d in HubSurface.domains():
		saved_domains.append(d)
	HubSurface.clear_domains()
	var fa: Dictionary = _run_leg(flank, down_yaw, true, CONTROL_FRAMES)
	var fb: Dictionary = _run_leg(flank, up_yaw, true, CONTROL_FRAMES)
	for d in saved_domains:
		HubSurface.domains().append(d)
	var floor_u: float = absf(fa["top"] - fb["top"])
	print("     CONTROL (same point, domain OFF)  %.3f u/s and %.3f u/s -- noise floor %.5f u/s"
		% [fa["top"], fb["top"], floor_u])
	_check(not bool(fa["bounced"]) and not bool(fb["bounced"]),
		"neither control leg met a wall (%s / %s) -- a bounce would be read as noise"
		% [fa["bounced"], fb["bounced"]])
	_check(floor_u < 0.01,
		"the noise floor between two opposite headings with NO hill is %.5f u/s" % floor_u)
	_check(fa["travel"] > 5.0,
		"and the control actually ran: %.2f u in %d frames" % [fa["travel"], CONTROL_FRAMES])
	_check(down["top"] - up["top"] > floor_u * 20.0,
		"DESCENT IS FASTER: %.3f u/s against %.3f uphill -- a gap of %.3f, %.0fx the floor"
		% [down["top"], up["top"], down["top"] - up["top"],
			(down["top"] - up["top"]) / maxf(floor_u, 0.0001)])
	_check(down["travel"] > up["travel"] * 1.2,
		"and it covers %.2f u against %.2f in the same %d frames"
		% [down["travel"], up["travel"], LEG_FRAMES])
	# THE VERROU. The motor's own ceiling is MAX_SPEED_FLAT; a descent that
	# never passed it would mean the damping erased the hill, which is the
	# case CH35 Q2 said would justify opening VehicleDrive.gd.
	# ---- ⚠️ THE COASTING PAIR, AND THE RED PASS IS WHY IT EXISTS.
	#
	# Everything above is measured AT FULL THROTTLE, and at full throttle
	# there are TWO downhill mechanisms working together: the slope force,
	# and the ceiling this vehicle raises with the grade. The red pass that
	# set `slope_gain` to ZERO left "DESCENT IS FASTER" GREEN at 12.891 u/s
	# against 8.081 -- the raised ceiling alone carried the whole result,
	# and the phase could not tell the two apart. A sled whose descent is
	# its motor pushing harder is not a sled.
	#
	# So: the same two headings with the THROTTLE SHUT. Nothing then moves
	# the vehicle but gravity, and gravity is exactly what is being
	# claimed. With the force off this pair reads zero.
	var coast_down: Dictionary = _run_leg(flank, down_yaw, true, LEG_FRAMES, 0.0)
	var coast_up: Dictionary = _run_leg(flank, up_yaw, true, LEG_FRAMES, 0.0)
	print("     COASTING (throttle shut)  downhill top %.3f u/s, advance %+.2f u  |  uphill top %.3f u/s, advance %+.2f u"
		% [coast_down["top"], coast_down["advance"], coast_up["top"], coast_up["advance"]])
	_check(coast_down["top"] > 3.0,
		"WITH THE THROTTLE SHUT the hill alone drives it to %.3f u/s -- the force, not the ceiling"
		% coast_down["top"])
	# ⚠️ THE SIGN, NOT THE DISTANCE. Coasting UPHILL the sled stops and
	# slides BACK DOWN, and a leg that slid backwards covers just as much
	# ground as one that drove forwards -- the first version of this pair
	# compared |travel| and read x1.7 where the truth is a reversal.
	_check(float(coast_down["advance"]) > 3.0,
		"it coasts %+.2f u FORWARD down the hill" % coast_down["advance"])
	_check(float(coast_up["advance"]) < 0.0,
		"and %+.2f u BACKWARD up it -- gravity, and nothing else, is moving this vehicle"
		% coast_up["advance"])

	# ---- THE VERROU, on its own LONG run. Crossing the summit is not a
	# problem for this question: what is asked is whether a real descent
	# ever passes the motor's own ceiling, and by how much the per-instance
	# ceiling buys over VehicleDrive's damping alone.
	var full: Dictionary = _run_leg(flank, down_yaw, true, RUN_FRAMES)
	var damped: Dictionary = _run_leg(flank, down_yaw, false, RUN_FRAMES)
	print("     VERROU over %d frames: ceiling raised %.3f u/s vs ceiling left flat %.3f u/s (damping alone), MAX_SPEED_FLAT %.2f"
		% [RUN_FRAMES, full["top"], damped["top"], SledBody.MAX_SPEED_FLAT])
	_check(full["top"] > SledBody.MAX_SPEED_FLAT * 1.5,
		"a full descent passes the motor's own ceiling: %.3f u/s against %.2f (x%.2f)"
		% [full["top"], SledBody.MAX_SPEED_FLAT, full["top"] / SledBody.MAX_SPEED_FLAT])
	_check(damped["top"] > SledBody.MAX_SPEED_FLAT,
		"even with the ceiling left flat the damping alone is passed: %.3f > %.2f -- off_lambda is a DRAG, not a wall"
		% [damped["top"], SledBody.MAX_SPEED_FLAT])
	_check(full["top"] > damped["top"] * 1.15,
		"and raising it per instance buys %.1f %% more -- which is why VehicleDrive.gd stays shut"
		% [100.0 * (full["top"] / maxf(damped["top"], 0.0001) - 1.0)])

## One straight full-throttle leg. `raise_cap` false runs it with the
## ceiling pinned to MAX_SPEED_FLAT -- the sled's own drive() with the
## verrou's three lines removed, which is what makes that comparison a
## measurement of THOSE LINES and not of two different vehicles.
func _run_leg(from: Vector3, yaw: float, raise_cap: bool, frames: int = RUN_FRAMES,
		throttle: float = 1.0) -> Dictionary:
	_sled.place(from, yaw)
	var input := KartInput.new()
	input.throttle = throttle
	input.steer = 0.0
	var top: float = 0.0
	var sum: float = 0.0
	var cap: float = 0.0
	var bounced := false
	var start: Vector3 = _sled.flat_position()
	var grade_start: float = SurfaceDrive.grade_at(start, yaw)
	for _f in frames:
		var was: Vector3 = _sled.flat_position()
		if raise_cap:
			_sled.drive(FIXED_DELTA, input)
		else:
			_drive_pinned(input)
		# A wall refusal leaves the vehicle where it was, or reverses it:
		# either way the leg stops measuring what it was asked to measure,
		# and a leg that met one is reported rather than averaged in.
		if _sled.flat_position().distance_to(was) < 1.0e-6 and _sled.velocity.length() > 0.1:
			bounced = true
		var s: float = _sled.velocity.length()
		top = maxf(top, s)
		sum += s
		cap = maxf(cap, _sled.speed_cap())
	return {
		"top": top, "mean": sum / float(frames), "cap": cap, "bounced": bounced,
		"travel": start.distance_to(_sled.flat_position()),
		# SIGNED, along the heading the leg set out on: a leg that slid
		# BACKWARDS travelled just as far as one that drove forwards, and
		# only the sign tells them apart.
		"advance": (_sled.flat_position() - start).dot(Vector3(sin(yaw), 0.0, cos(yaw))),
		"grade_start": grade_start,
		"grade_end": SurfaceDrive.grade_at(_sled.flat_position(), _sled.rotation.y),
	}

## The sled's step with the ceiling NOT raised by the grade. Written here
## rather than as a switch inside SledBody: a vehicle that can be built
## with its own verrou disabled is a vehicle that can SHIP with it
## disabled, and this repo has the doctrine on probes that can turn off
## the thing they gate.
func _drive_pinned(input: KartInput) -> void:
	var drive := SurfaceDrive.new()
	drive.slope_gain = _sled.slope_gain()
	drive.motion.max_speed = SledBody.MAX_SPEED_FLAT
	drive.motion.max_speed_off = SledBody.OFF_SPEED
	drive.motion.reverse_speed = SledBody.REVERSE_SPEED
	drive.motion.boost_speed_ratio = SledBody.BOOST_RATIO
	drive.motion.accel_lambda = SledBody.ACCEL_LAMBDA
	drive.motion.coast_lambda = SledBody.COAST_LAMBDA
	drive.motion.off_lambda = SledBody.OVER_LAMBDA
	drive.motion.brake_decel = SledBody.BRAKE_DECEL
	drive.motion.steer_full_speed = SledBody.STEER_FULL_SPEED
	drive.motion.steer_high_speed_keep = SledBody.STEER_HIGH_SPEED_KEEP
	drive.motion.grip_on = SledBody.GRIP_ON
	drive.motion.grip_off = SledBody.GRIP_OFF
	drive.motion.scrub = SledBody.SCRUB
	var out: Dictionary = drive.step(_sled.flat_position(), _sled.rotation.y, _sled.velocity,
		FIXED_DELTA, input, true, SledBody.WORLD_FENCE, KartTuning.steer_rate() * SledBody.STEER_RATIO)
	_sled.rotation.y = float(out["yaw"])
	_sled.velocity = out["velocity"]
	_sled.global_position = out["position"]

## =====================================================================
## PHASE F -- it never leaves the map.
func _phase_f() -> void:
	print("-- PHASE F: a long steered drive never leaves the map --")
	# BLIND: the test has to be able to REFUSE. A point 200 u out is not
	# drivable, and a gate that said yes to it would say yes to anything.
	_check(not SledBody.drivable(Vector3(200.0, 0.0, 200.0)),
		"blind: a point 200 u off the map is refused by the same test")
	_check(SledBody.drivable(HubTransport.SLED_PARK), "and the park itself is accepted")
	var start := _summit()
	_sled.place(Vector3(start.x, 0.0, start.z), 0.0)
	var input := KartInput.new()
	input.throttle = 1.0
	var escapes: int = 0
	var worst_h: float = 0.0
	var far: float = 0.0
	for f in ROAM_FRAMES:
		# A long lazy weave that drives it off the ridge, across the
		# plateau seam and into the region's walls.
		input.steer = sin(float(f) * 0.004) * 1.0
		_sled.drive(FIXED_DELTA, input)
		var p: Vector3 = _sled.flat_position()
		if not SledBody.drivable(p):
			escapes += 1
		worst_h = maxf(worst_h, absf(_sled.global_position.y - HubSurface.height_at(p)))
		far = maxf(far, p.length())
	_check(escapes == 0, "%d frames, %d off the drivable set (reached %.1f u from the origin)"
		% [ROAM_FRAMES, escapes, far])
	_check(far > 30.0, "and it actually roamed: %.1f u from the origin at its furthest" % far)
	_check(worst_h < 1.0e-5, "and stayed on the ground throughout (worst %.9f)" % worst_h)

## =====================================================================
## PHASE G -- mount and dismount on the LIVE hub, with no lock-up.
##
## The boat pattern's own gate: the vehicle WITHDRAWS while it is ridden
## (vehicle_at refuses it), so a tap on it falls through to the ground
## path instead of being swallowed. The ladder pattern is banned and this
## is the assertion that says which one shipped.
func _phase_g() -> void:
	print("-- PHASE G: mount, drive, step off --")
	_transport.exit_sled()
	_sled.place(HubTransport.SLED_PARK, PI / 2.0)
	var park: Vector3 = _sled.flat_position()
	_keepy.global_position = HubSurface.ground(park + Vector3(0.9, 0.0, 0.0))
	await get_tree().process_frame
	_check(_transport.vehicle_at(park) == HubTransport.VEHICLE_SLED,
		"a tap on the park means the sled (kind %d)" % _transport.vehicle_at(park))
	var mounted: bool = _transport.mount_sled()
	_check(mounted, "mount_sled() accepted")
	_check(_keepy.call("is_on_carrier"), "and he is ON_CARRIER")
	var seat: Vector3 = _sled.deck().to_global(SledBody.SEAT)
	_check(_keepy.global_position.distance_to(seat) < 0.01,
		"seated on the CHASSIS at %s (%.4f u off)" % [seat, _keepy.global_position.distance_to(seat)])
	# THE WITHDRAWAL. While ridden, the sled must not answer a tap.
	_check(_transport.vehicle_at(_sled.flat_position()) != HubTransport.VEHICLE_SLED,
		"while ridden it withdraws from the tap (kind %d) -- the boat pattern, not the ladder"
		% _transport.vehicle_at(_sled.flat_position()))
	_check(not _transport.mount_yacht(), "and no other vehicle may be mounted while it is driven")
	_check(not _transport.mount_sailboat(), "the sailboat is refused too")
	# Drive it a little, on the hub's own loop, and check the rider rides.
	var input := KartInput.new()
	input.throttle = 1.0
	for _f in 60:
		_sled.drive(FIXED_DELTA, input)
		_keepy.call("follow_carrier")
	var seat2: Vector3 = _sled.deck().to_global(SledBody.SEAT)
	_check(_keepy.global_position.distance_to(seat2) < 0.01,
		"still seated after 60 driven frames (%.4f u off)" % _keepy.global_position.distance_to(seat2))
	_check(_sled.flat_position().distance_to(park) > 1.0,
		"and it moved %.2f u" % _sled.flat_position().distance_to(park))
	# Step off, and WAIT for the arc rather than assuming it is instant.
	#
	# ⚠️ THE STATE IS POLLED, NOT A SIGNAL, AND THAT IS A FINDING.
	# The first version waited on `became_idle` and timed out while every
	# other assertion below passed -- he WAS back on his feet. The reason
	# is in KeepyHopper: `leave_carrier` sets `_has_target = false`, and
	# `_advance()` (which is what would emit `became_idle`) returns on its
	# very first line when there is no target. A carrier dismount that
	# HOPS therefore emits `hop_landed` and NOTHING ELSE -- not
	# `became_idle`, and not `carrier_dismounted` either, which only the
	# zero-distance branch emits. That asymmetry predates this lot and is
	# shared by the yacht and the sailboat; it is REPORTED, not fixed
	# here, because changing it would change two conduites Mathieu has
	# validated. Reported in docs/lots/CH41_LUGE.md.
	_transport.exit_sled()
	var landed := false
	for _f in 300:
		await get_tree().process_frame
		if not _keepy.call("is_on_carrier") and not _keepy.call("is_hopping"):
			landed = true
			break
	_check(landed, "exit_sled() put him back on his feet (state polled, see the note above)")
	_check(not _keepy.call("is_on_carrier"), "and he is off the carrier")
	_check(not _transport.is_driving_sled(), "the drive flag is down")
	var foot: Vector3 = _keepy.global_position
	_check(absf(foot.y - HubSurface.height_at(foot)) < 0.05,
		"he landed ON the ground, not at y = 0: y %.4f vs height_at %.4f"
		% [foot.y, HubSurface.height_at(foot)])
	_check(SledBody.drivable(Vector3(foot.x, 0.0, foot.z)),
		"and on ground he could have driven on")
	_check(_transport.vehicle_at(_sled.flat_position()) == HubTransport.VEHICLE_SLED,
		"the sled is open to the tap again")

## =====================================================================
## PHASE H -- THE WINDING, and CH39 is why it is a render.
##
## The decor shader is `cull_disabled`, so an inside-out sled would look
## PERFECTLY FINE in this sandbox and on device -- which is worse than
## CH39, not better: nothing would ever complain. The arithmetic check is
## therefore the gate, and the render is there to prove the arithmetic is
## about the same thing the engine does.
func _phase_h() -> void:
	print("-- PHASE H: the winding, arithmetic and rendered --")
	var mesh: ArrayMesh = SledBody.build_mesh()
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tris: int = verts.size() / 3
	_check(tris == SledBody.PIECE_TRIS * SledBody.PIECE_COUNT,
		"the sled draws %d triangles, %d pieces of %d -- the grouping this phase relies on"
		% [tris, SledBody.PIECE_COUNT, SledBody.PIECE_TRIS])
	# ⚠️ EACH PIECE AGAINST ITS OWN CENTRE. Five boxes side by side are not
	# a convex body: the deck's underside and the runners' inner flanks
	# point back toward the assembly's middle, so a single centre of mass
	# calls 14 correct triangles wrong. Measured exactly that way once,
	# on a mesh the render had already proved right at the pixel.
	var inward: int = 0
	var outward_normals: int = 0
	for piece in SledBody.PIECE_COUNT:
		var centre := Vector3.ZERO
		for k in SledBody.PIECE_TRIS * 3:
			centre += verts[piece * SledBody.PIECE_TRIS * 3 + k]
		centre /= float(SledBody.PIECE_TRIS * 3)
		for t in SledBody.PIECE_TRIS:
			var i: int = (piece * SledBody.PIECE_TRIS + t) * 3
			var a: Vector3 = verts[i]
			var b: Vector3 = verts[i + 1]
			var c: Vector3 = verts[i + 2]
			var rh: Vector3 = (b - a).cross(c - a)
			var out_dir: Vector3 = (a + b + c) / 3.0 - centre
			if rh.dot(out_dir) < 0.0:
				inward += 1
			if norms[i].dot(out_dir) > 0.0:
				outward_normals += 1
	_check(inward == tris,
		"every right-hand normal points INTO the solid (%d of %d) -- Godot's front face" % [inward, tris])
	_check(outward_normals == tris,
		"and every written NORMAL points out of it (%d of %d) -- what the toon shader wants"
		% [outward_normals, tris])
	# THE RENDER. Park Keepy beside the sled, paint the sled alone, and
	# count with the face test on and off.
	_sled.place(HubTransport.SLED_PARK, PI / 2.0)
	_keepy.global_position = HubSurface.ground(HubTransport.SLED_PARK)
	if _camera.has_method("snap_to_target"):
		_camera.call("snap_to_target")
	var hull: MeshInstance3D = _sled.deck().get_node("Hull") as MeshInstance3D
	var kept: Material = hull.material_override
	var one := ShaderMaterial.new()
	one.shader = Shader.new()
	one.shader.code = IDENT_ONE_SIDED
	var two := ShaderMaterial.new()
	two.shader = Shader.new()
	two.shader.code = IDENT_TWO_SIDED
	# BLIND FIRST: with the sled hidden the mask must read ZERO, or every
	# count below is measuring something else on the hill.
	hull.visible = false
	var blind: int = await _ident_pixels(hull, one)
	hull.visible = true
	var culled: int = await _ident_pixels(hull, one)
	var uncut: int = await _ident_pixels(hull, two)
	hull.material_override = kept
	_check(blind == 0, "blind: with the hull hidden the mask reads %d pixels" % blind)
	_check(culled > 50, "the sled paints %d pixels with cull_back on" % culled)
	var gap: float = absf(float(uncut - culled)) / maxf(float(uncut), 1.0)
	_check(gap <= CULL_TOLERANCE,
		"cull_back %d vs cull_disabled %d -- the face test discards %.2f %% (ceiling %.0f %%)"
		% [culled, uncut, 100.0 * gap, 100.0 * CULL_TOLERANCE])

func _ident_pixels(node: MeshInstance3D, mat: Material) -> int:
	node.material_override = mat
	for _k in 6:
		await get_tree().process_frame
	var img: Image = _sub.get_texture().get_image()
	if img.get_width() < VP_SIZE.x or img.get_height() < VP_SIZE.y:
		push_error("SledProbe PHASE H: the viewport rendered %dx%d -- run under xvfb with opengl3."
			% [img.get_width(), img.get_height()])
		return -1
	var n: int = 0
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.999 and c.g < 0.001 and c.b > 0.999:
				n += 1
	return n

## =====================================================================
## PHASE I -- what the sled costs the frame.
##
## ⚠️ IT IS NOT INSIDE CozyScatter.RIDGE_TRIANGLE_BUDGET, AND THAT IS A
## FACT ABOUT THE ACCOUNTING, NOT A LOOPHOLE. CH40's ceiling is read by
## MountainProbe PHASE J over the SCATTER's own batch nodes: the submitted
## figure walks CozyScatter.batch_nodes() and the measured one is the
## delta of hiding the dressing's batches. A hand-built Node3D is in
## neither reading -- it is in BOTH frames of the measured delta, so it
## cancels out of it exactly. So this phase prices the sled on its own,
## the same way and at the same stations, and the report puts the two
## numbers side by side rather than pretending one contains the other.
func _phase_i() -> void:
	print("-- PHASE I: what the sled costs, 8 stations x 2 camera heights --")
	var sled_node: Node3D = _transport.sled_node()
	_sled.place(HubTransport.SLED_PARK, PI / 2.0)
	var worst: int = 0
	var worst_where: String = ""
	var worst_on: int = 0
	var noise: int = 0
	var quiet: int = 0
	var quiet_worst: int = 0
	var quiet_bad: int = 0
	var quiet_paid: int = 0
	var mesh_tris: int = _mesh_tris(SledBody.build_mesh())
	var summit := _summit()
	for hi_cam in [false, true]:
		for k in 8:
			var a: float = TAU * float(k) / 8.0
			var st := Vector3(summit.x + cos(a) * 6.0, 0.0, summit.z + sin(a) * 6.0)
			st.x = clampf(st.x, HubRegion.MOUNTAIN_MIN.x + 0.5, HubRegion.MOUNTAIN_MAX.x - 0.5)
			st.z = clampf(st.z, HubRegion.MOUNTAIN_MIN.y + 0.5, HubRegion.MOUNTAIN_MAX.y - 0.5)
			_keepy.global_position = HubSurface.ground(st)
			if _camera.has_method("snap_to_target"):
				_camera.call("snap_to_target")
			if hi_cam:
				_camera.global_position = HubSurface.ground(st) + HubCamera.OFFSET + Vector3(0.0, 4.0, 0.0)
			await get_tree().process_frame
			await get_tree().process_frame
			var on: int = _prims()
			# The control: two more frames, NOTHING touched -- CH40's own
			# lesson, a delta without its jitter is not a measurement.
			await get_tree().process_frame
			await get_tree().process_frame
			var again: int = _prims()
			noise = maxi(noise, absi(again - on))
			sled_node.visible = false
			await get_tree().process_frame
			await get_tree().process_frame
			var off: int = _prims()
			sled_node.visible = true
			var d: int = on - off
			var j: int = absi(again - on)
			print("     station (%6.1f, %6.1f) cam %s : on %6d  off %6d  delta %+5d  (jitter %d)%s"
				% [st.x, st.z, "high" if hi_cam else "flat", on, off, d, j,
					"" if j == 0 else "   <- NOISY, not gated"])
			if j == 0:
				quiet += 1
				quiet_worst = maxi(quiet_worst, d)
				if d != 0 and d != mesh_tris:
					quiet_bad += 1
				if d == mesh_tris:
					quiet_paid += 1
			if d > worst:
				worst = d
				worst_where = "(%.1f, %.1f) cam %s" % [st.x, st.z, "high" if hi_cam else "flat"]
				worst_on = on
	_check(worst_on > 0, "the engine counter is filled at all (worst frame reads %d)" % worst_on)
	print("     QUIET stations %d of 16, worst quiet delta %d;  noisiest raw delta %d at %s (jitter up to %d)"
		% [quiet, quiet_worst, worst, worst_where, noise])
	# ⚠️ THE NOISY STATIONS ARE NOT GATED, AND SAYING SO IS THE POINT.
	# CH40's lesson is that a delta without its noise floor is not a
	# measurement; the other half, learned here, is that a delta BELOW its
	# noise floor is not one either. This hub's counter drifts by up to a
	# few hundred primitives between two untouched frames (butterflies,
	# precipitation, critters), and a 60-triangle prop cannot be weighed
	# on a scale that noisy. So the cost is read where the scale is STILL,
	# and the rest is printed and left alone.
	_check(quiet >= 8, "the counter was perfectly still at %d of 16 stations" % quiet)
	_check(quiet_bad == 0,
		"at every quiet station the sled costs either 0 (out of frame) or exactly its own %d triangles (%d stations disagreed)"
		% [mesh_tris, quiet_bad])
	_check(quiet_paid > 0,
		"and it DID cost its %d triangles at %d of them -- a 0 everywhere would mean it never drew"
		% [mesh_tris, quiet_paid])
	# What it would be if it DID count against CH40's ceiling: the headroom
	# CH40 published is 125 triangles, and this is the number to compare.
	_check(mesh_tris <= 125,
		"and it fits inside CH40's published headroom of 125 triangles even though it is not accounted there (%d)"
		% mesh_tris)

func _prims() -> int:
	return RenderingServer.viewport_get_render_info(
		_sub.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)

## =====================================================================
## PHASE J -- the CHASE camera on a slope. This is the first vehicle to
## drive a domain, so the pose CH37 rebased onto ground() has never been
## exercised on one.
##
## The pose is HubSurface.ground(vehicle) - heading * DRIVE_BACK + DRIVE_UP:
## the height comes from under the VEHICLE and the camera is then pushed
## 7.6 u back HORIZONTALLY. Driving downhill, the ground behind is HIGHER
## than the ground under it -- so the clearance is DRIVE_UP minus the rise
## over 7.6 u, and on a 27.8 deg flank that rise is 4.01 u against a
## DRIVE_UP of 4.4. The margin is real and it is thin; it is measured here
## rather than argued, at every lattice point and eight headings.
func _phase_j() -> void:
	print("-- PHASE J: the chase camera clears the ground on every slope --")
	var worst: float = INF
	var worst_at: String = ""
	var tested: int = 0
	var pitch: float = HubMountain.PITCH
	for r in HubMountain.rows():
		var z: float = HubRegion.MOUNTAIN_MIN.y + float(r) * pitch
		for c in HubMountain.columns():
			var x: float = HubRegion.MOUNTAIN_MIN.x + float(c) * pitch
			var at := Vector3(x, 0.0, z)
			for k in 8:
				var yaw: float = TAU * float(k) / 8.0
				var heading := Vector3(sin(yaw), 0.0, cos(yaw))
				var eye: Vector3 = HubSurface.ground(at) - heading * HubCamera.DRIVE_BACK \
					+ Vector3(0.0, HubCamera.DRIVE_UP, 0.0)
				var clear: float = eye.y - HubSurface.height_at(eye)
				tested += 1
				if clear < worst:
					worst = clear
					worst_at = "(%.1f, %.1f) heading %.0f deg" % [x, z, rad_to_deg(yaw)]
	_check(tested > 5000, "swept %d (point, heading) pairs over the domain" % tested)
	_check(worst > 0.0,
		"the chase eye is ABOVE the ground everywhere: worst clearance %.4f u at %s" % [worst, worst_at])
	# BLIND: the sweep must be able to find a violation. The same sweep
	# with the camera 4 u lower has to fail, or it is not looking.
	var blind_worst: float = INF
	for r in HubMountain.rows():
		var z: float = HubRegion.MOUNTAIN_MIN.y + float(r) * pitch
		for c in HubMountain.columns():
			var x: float = HubRegion.MOUNTAIN_MIN.x + float(c) * pitch
			var at := Vector3(x, 0.0, z)
			for k in 8:
				var yaw: float = TAU * float(k) / 8.0
				var heading := Vector3(sin(yaw), 0.0, cos(yaw))
				var eye: Vector3 = HubSurface.ground(at) - heading * HubCamera.DRIVE_BACK \
					+ Vector3(0.0, HubCamera.DRIVE_UP - 4.0, 0.0)
				blind_worst = minf(blind_worst, eye.y - HubSurface.height_at(eye))
	_check(blind_worst < 0.0,
		"blind: the same sweep 4 u lower DOES find ground (worst %.4f u) -- the sweep can fail"
		% blind_worst)
	print("     DRIVE_BACK %.2f  DRIVE_UP %.2f  worst clearance %.4f u  margin over the blind %.4f"
		% [HubCamera.DRIVE_BACK, HubCamera.DRIVE_UP, worst, worst - blind_worst])
