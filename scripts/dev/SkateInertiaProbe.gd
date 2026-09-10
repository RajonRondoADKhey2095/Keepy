extends Node
## CH61 LOT 3c -- THE GATE OF THE BOARD'S LAW OF MOTION.
##
## =====================================================================
## WHAT THIS LOT HAD TO PROVE, AND WHY ONE NUMBER WOULD NOT HAVE DONE IT
##
## Mathieu on the CH60 build: "je n'arrive pas du tout a monter les
## rampes, je suis juste bloque". CH60 had chiffred the ceiling already
## -- 0.577 u on a 2.10 u lip, 0.386 u on a 1.45 u lip -- and read it as
## a body with no stored elan.
##
## ⚠️ THE PREMISE OF THAT READING FALLS, AND IT FALLS TO ARITHMETIC THE
## SAME TWO NUMBERS CARRY. 0.577 / 2.10 = 0.2748 and 0.386 / 1.45 =
## 0.2662: the same FRACTION of two different ramps. An energy ceiling
## is an ABSOLUTE height -- v^2 / 2g, which at cruise is 1.923 u, over
## BOTH lips -- so a ceiling that scales with the ramp is not an energy
## ceiling at all. It is `floor_max_angle`, cutting the profile's arc at
## its 45 deg facet: 1 - cos 45 = 0.2929, minus the capsule's contact
## offset.
##
## Which is why this bench measures a TABLE and not a height. A single
## "it goes higher now" would pass for a board given a bigger dictated
## pace, and would say nothing at all about whether anything is being
## CONVERTED. What separates the two is that height must be a FUNCTION
## OF ARRIVAL SPEED -- monotone, and spread wide -- where CH60's board
## returns the same fraction of the ramp whatever it arrives at. PHASE E
## gates the shape of that function, not one of its values.
##
## =====================================================================
## THE RED PASS IS AT RUNTIME, AND IT REPRODUCES CH60 ON DEMAND
##
## CLAUDE.md's rouge-avant-vert, done the way CH57 PHASE N does it --
## by changing the world rather than the file, so there is nothing to
## `cmp` afterwards. PHASE R puts `floor_max_angle` back to Godot's 45
## deg on the LIVE body, rolls the FASTEST arrival again, and demands the
## climb collapse onto CH60's published figure; then it restores 88 deg
## and demands the climb come back.
##
## Green / red / green, on one tree, and the red is not merely a failure
## -- it is CH60's own measurement, re-derived by this bench. A bench
## that can reproduce the defect it claims to have fixed is the only kind
## with standing to publish the fix.
##
## =====================================================================
## AND IT RUNS HEADLESS
##
## CLAUDE.md's driver rule, both halves. Nothing here reads a pixel, a
## MultiMesh transform or a screen point: every number is a transform, a
## velocity or a face normal. Under llvmpipe a probe like this spends ten
## minutes rendering a verdict it reaches in seconds -- CH32 measured
## exactly that on two probes at their own budget, with real CPU and a
## growing log and no defect at all.
##
## The tap channel is NOT tested here for that reason, and it is tested
## where the screen is real: SkateDismountProbe PHASE M enters at a
## container pixel through `HubTapInput._handle_point`, which is the trap
## CH57 paid for and CH58 named.

const BUDGET_S: float = 2400.0
const FPS: float = 60.0
const SETTLE: int = 8

## CH60's published ceiling, restated so this bench can be checked against
## a number already on file rather than only against itself.
const CH60_REACHED: Dictionary = {2: 0.577, 3: 0.386}
## The fraction of a lip a 45 deg cap allows: 1 - cos(45 deg).
const P6_FRACTION: float = 0.29289321881345254

## The arrival speeds the table is taken at, u/s. The top one is CH54's
## cruise, the bottom one is a crawl; four rungs is enough to show a
## monotone curve and few enough that four modules fit the budget.
## ⚠️ THE BOTTOM RUNG IS 4.0 AND NOT 2.5, AND THE RUN-IN IS 2.0 AND NOT
## 3.0, BECAUSE THE FIRST VERSION MEASURED A BOARD THAT NEVER ARRIVED.
## The coast terms take their cut over the run-in, and at 2.5 u/s over
## 3.0 u they take all of it: the board stopped short of the foot and the
## row read `arrived 0.00, peak 0.000` -- a true reading of a run that is
## not an instance of what the table is about.
const ARRIVALS: Array[float] = [4.0, 6.0, 8.0, 10.0]
## How far out from the module's foot the board is launched. Far enough
## that the coast has settled into a clean roll, near enough that it has
## not spent the injected speed before it arrives.
const LAUNCH_U: float = 2.0
const RUN_TICKS: int = 260

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _park: HubSkatepark = null
var _transport: HubTransport = null
## CH64: the bench's finger. The TAP adapter that rolled this board to a
## point is gone with the TAP scheme; every roll below is commanded
## through the real writer (see SkateBench).
var _bench: SkateBench = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE INERTIA PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_inertia_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _run() -> void:
	print("=== SKATE INERTIA PROBE -- CH61 LOT 3c ===")
	print("driver: %s" % DisplayServer.get_name())
	_phase_angle()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every number below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	for _i in 24:
		await get_tree().process_frame
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	_park = _hub.find_child("Skatepark", true, false) as HubSkatepark
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	if _keepy == null or _park == null or _transport == null:
		push_error("SkateInertiaProbe: hub is missing Keepy / Skatepark / Transport.")
		get_tree().quit(1)
		return
	_bench = SkateBench.new()
	_bench.name = "Bench"
	add_child(_bench)
	_bench.setup(_transport, _hub.find_child("Camera3D", true, false) as Camera3D)
	await _phase_law()
	await _phase_energy()
	await _phase_red()
	await _phase_stall()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE A -- THE TWO POPULATIONS, AND THE ANGLE BETWEEN THEM
#
# ⚠️ THE POINT OF THIS PHASE IS THAT `floor_max_angle` IS NOT A TASTE.
# The park's drawn solids have exactly two kinds of face and the gap
# between them is the whole design margin: riding surfaces, of which the
# steepest is the last chord of a quarterpipe profile, and WALLS, which
# are the axis-aligned sides of prisms and are 90 deg to the bit. Any
# angle strictly inside that gap admits the whole transition and refuses
# every wall.
#
# It is measured on the DRAWN triangles rather than argued from the
# builder's comments, and by their TRUE face normals (the cross product
# of the two edges) rather than by the stored vertex normals -- CH60
# measured those two disagreeing by up to 86.25 deg on this very mesh,
# and a phase that read the stored ones would be reading the transposed
# shape.
#
# ⚠️ AND IT CLASSIFIES ON |n.y|, WHICH SIDESTEPS THE WINDING QUESTION
# ENTIRELY. CLAUDE.md, CH39: the outward side of a hand-built surface is
# taken from the ENGINE, never from the maths, and a face at slope theta
# has |n.y| = cos theta whichever way it is wound. Nothing here needs to
# know which side is out; it needs to know how steep the face is.

func _phase_angle() -> void:
	print("-- PHASE A: the two face populations, and where the cap sits between them --")
	var builder := SkateparkMesh.new()
	var steepest: float = -1.0
	var steepest_where: String = ""
	var shallowest_wall: float = 1e9
	var wall_faces: int = 0
	var ride_faces: int = 0
	for index in HubSkatepark.MODULES.size():
		var spec: Dictionary = HubSkatepark.MODULES[index]
		var kind: StringName = StringName(spec["kind"])
		if kind == HubSkatepark.KIND_BOWL:
			continue
		var mesh: ArrayMesh = _mesh_of(builder, kind, HubSkatepark.build_args(spec))
		if mesh == null:
			continue
		var faces: PackedVector3Array = mesh.get_faces()
		var worst_here: float = -1.0
		for t in range(0, faces.size(), 3):
			var n: Vector3 = (faces[t + 1] - faces[t]).cross(faces[t + 2] - faces[t])
			if n.length() < 1e-9:
				continue
			n = n.normalized()
			var slope: float = rad_to_deg(acos(clampf(absf(n.y), 0.0, 1.0)))
			if absf(n.y) < 1e-5:
				wall_faces += 1
				shallowest_wall = minf(shallowest_wall, slope)
			else:
				ride_faces += 1
				if slope > worst_here:
					worst_here = slope
				if slope > steepest:
					steepest = slope
					steepest_where = "%s[%d]" % [String(kind), index]
		print("     [%d] %-12s steepest non-vertical face %.3f deg" % [index, String(kind), worst_here])
	var cap: float = rad_to_deg(SkateBoardBody.FLOOR_MAX_ANGLE)
	print("     RIDING faces %d, steepest %.3f deg (%s)   WALL faces %d, shallowest %.3f deg"
		% [ride_faces, steepest, steepest_where, wall_faces, shallowest_wall])
	print("     the cap sits at %.3f deg   (CH57 shipped %.3f)" % [cap, 45.0])
	# The instrument, both ways: a gate written between two populations is
	# free if either is empty, and CLAUDE.md's tried > 0 guard is exactly
	# the one that caught CH47's 0-of-0 green.
	_check(ride_faces > 0 and wall_faces > 0,
		"A INSTRUMENT: both populations exist (%d riding, %d wall)" % [ride_faces, wall_faces])
	_check(shallowest_wall > steepest + 1.0,
		"A INSTRUMENT: the two populations really are separated (%.3f vs %.3f deg)"
			% [shallowest_wall, steepest])
	# The number CH60 published for the profile's last chord, reproduced
	# from the mesh rather than restated from the doc.
	var predicted: float = (float(SkateparkMesh.QP_SEGMENTS) - 0.5) / float(SkateparkMesh.QP_SEGMENTS) * 90.0
	_check(absf(steepest - predicted) < 0.5,
		"A the steepest riding facet IS the profile's last chord (%.3f deg, predicted %.3f)"
			% [steepest, predicted])
	_check(cap > steepest,
		"A the cap admits the ENTIRE drawn transition (%.3f > %.3f deg)" % [cap, steepest])
	_check(cap < shallowest_wall,
		"A and still refuses every wall (%.3f < %.3f deg)" % [cap, shallowest_wall])
	# And the half that says what CH57 could not: the shipped cap did NOT
	# admit the transition, which is the whole defect in one line.
	_check(45.0 < steepest,
		"A INSTRUMENT: CH57's 45 deg cap did NOT admit it -- %.3f deg of ramp was a wall"
			% steepest)

func _mesh_of(builder: SkateparkMesh, kind: StringName, a: Array) -> ArrayMesh:
	match kind:
		HubSkatepark.KIND_FUNBOX:
			return builder.funbox(a[0], a[1], a[2], a[3])
		HubSkatepark.KIND_QUARTERPIPE:
			return builder.quarterpipe(a[0], a[1])
		HubSkatepark.KIND_RAIL:
			return builder.rail(a[0], a[1])
	return null

# =====================================================================
# PHASE L -- THE LAW REPRODUCES CH54'S THREE PUBLISHED NUMBERS
#
# ⚠️ CLAUDE.md: "reproduire d'abord un chiffre deja au dossier avec le
# banc qu'on s'apprete a utiliser. Un banc incapable de restituer la
# diagonale a 66 hops n'a pas qualite a publier un chiffre neuf."
#
# CH54 authored a run-up over SKATE_ACCEL_U, a cruise at SKATE_CRUISE and
# a run-out over SKATE_BRAKE_U, and CH57 imposed them tick by tick. CH61
# throws the imposition away and keeps the numbers as ACCELERATIONS. If
# the profile does not come back out on the flat, the law is not CH54's
# ride with inertia added -- it is a different ride, and every number in
# PHASE E would be measuring something nobody asked for.

func _phase_law() -> void:
	print("-- PHASE L: the flat ride still IS CH54's, and the coast now ends --")
	var body := _transport.board_body()
	_check(body != null, "L INSTRUMENT: the board is a SkateBoardBody")
	if body == null:
		return
	print("     solved: push %.4f  brake %.4f  drag_k %.5f  roll_stop %.4f   (coast over %.3f u)"
		% [body.push_accel(), body.brake_accel(), body.drag_k(), body.roll_stop(),
			HubTransport.skate_coast_u()])
	# The accelerations are the distances, solved. Restating the identity
	# here is the only way a reader can tell a solve from a typed number.
	var rest: float = KeepyHopper.GLIDE_PACE_FLOOR * HubTransport.SKATE_CRUISE
	var gain: float = HubTransport.SKATE_CRUISE * HubTransport.SKATE_CRUISE - rest * rest
	_check(body.push_accel() > 0.0 and body.brake_accel() > 0.0,
		"L INSTRUMENT: both accelerations solved positive (push %.4f, brake %.4f)"
			% [body.push_accel(), body.brake_accel()])
	# ⚠️ THE SOLVE IS GATED AGAINST THE COAST, WHICH IS THE POINT OF IT.
	# A push taken from the frictionless identity would be SMALLER than
	# this one, and the difference is exactly what the coast eats on the
	# way up -- measured at 4.492 u of run-up against CH54's 3.20 before
	# the solve accounted for it. Asserting the inequality is what stops
	# a later lot from "simplifying" the closed form back to v^2 = 2 a d.
	var frictionless: float = gain / (2.0 * HubTransport.SKATE_ACCEL_U)
	_check(body.push_accel() > frictionless,
		"L the push is solved AGAINST the coast, not in a vacuum (%.4f > %.4f frictionless)"
			% [body.push_accel(), frictionless])
	_check(body.brake_accel() < gain / (2.0 * HubTransport.SKATE_BRAKE_U),
		"L and the brake is solved WITH it helping (%.4f < %.4f frictionless)"
			% [body.brake_accel(), gain / (2.0 * HubTransport.SKATE_BRAKE_U)])
	_check(absf(HubTransport.skate_coast_u() - HubSkatepark.park_span()) < 1e-4,
		"L and the coast distance is the PARK's own span, read not typed (%.3f u)"
			% HubSkatepark.park_span())
	# ---- the run-up, MEASURED: how far to reach cruise from rest.
	var run: Dictionary = await _flat_run(24.0)
	print("     flat run: reached %.3f u/s   run-up to 95%% of cruise in %.3f u   top at %.3f u"
		% [float(run["top"]), float(run["accel_u"]), float(run["top_at"])])
	_check(bool(run["mounted"]), "L INSTRUMENT: the rider is aboard for the flat run")
	_check(float(run["top"]) > HubTransport.SKATE_CRUISE * 0.90,
		"L the flat board still reaches CH54's cruise (%.3f of %.2f u/s)"
			% [float(run["top"]), HubTransport.SKATE_CRUISE])
	_check(float(run["top"]) <= HubTransport.SKATE_CRUISE + 0.05,
		"L and never exceeds it under push -- the cap is the legs, not the drag (%.3f)"
			% float(run["top"]))
	_check(absf(float(run["accel_u"]) - HubTransport.SKATE_ACCEL_U) < 0.6,
		"L the run-up is still CH54's %.2f u (measured %.3f u)"
			% [HubTransport.SKATE_ACCEL_U, float(run["accel_u"])])
	# ---- the run-out. CH64: there is no brake into a point any more (the
	# TAP adapter went with the TAP scheme, and a finger has no brake
	# gesture); the bench LIFTS the finger at the point and the board
	# coasts. What is gated is that the coast is the park's own span --
	# the property CH61 solved `configure()` for -- and not an ice rink.
	print("     run-out: the finger lifted at the point; stopped %.3f u past it, %.3f u/s left"
		% [float(run["miss"]), float(run["end_speed"])])
	_check(float(run["miss"]) <= HubSkatepark.park_span() * 1.25,
		"L the roll ends within one coast of where the finger lifted (%.3f u, park span %.3f)"
			% [float(run["miss"]), HubSkatepark.park_span()])
	_check(float(run["end_speed"]) <= body.rest_speed() + 0.01,
		"L and it is genuinely stopped there (%.4f u/s, rest is %.4f)"
			% [float(run["end_speed"]), body.rest_speed()])
	_check(bool(run["rested"]), "L at_rest() turned true, so the next tap means GET OFF")
	# ---- the coast: released at cruise, it stops, and inside the park.
	var coast: Dictionary = await _coast_run()
	print("     released at %.3f u/s: coasted %.3f u and stopped after %.2f s (park span %.3f u)"
		% [float(coast["from"]), float(coast["distance"]), float(coast["seconds"]),
			HubSkatepark.park_span()])
	_check(bool(coast["mounted"]), "L INSTRUMENT: the rider is aboard for the coast run")
	_check(bool(coast["stopped"]),
		"L a released board STOPS -- the hub is not an ice rink (%.3f u/s left)"
			% float(coast["end_speed"]))
	_check(float(coast["distance"]) > 1.0,
		"L INSTRUMENT: it really did coast (%.3f u) -- a board that never moved would stop for free"
			% float(coast["distance"]))
	_check(float(coast["distance"]) <= HubSkatepark.park_span() * 1.25,
		"L and it comes to rest inside the park it was pushed in (%.3f u <= %.3f)"
			% [float(coast["distance"]), HubSkatepark.park_span() * 1.25])

## A flat push from rest to a target 24 u away on open lawn, well clear of
## the park. Returns the run-up distance to 95 % of cruise, the top speed,
## and what is left at the tap.
func _flat_run(distance: float) -> Dictionary:
	var body := _transport.board_body()
	var from := Vector3(-26.0, 0.0, 30.0)
	var to := from + Vector3(0.0, 0.0, -1.0) * distance
	await _park_board(from)
	var mounted: bool = _transport.mount_board()
	_bench.aim(HubRegion.clamp_to(to))
	var top: float = 0.0
	var top_at: float = 0.0
	var accel_u: float = -1.0
	var rested: bool = false
	for _t in 900:
		await get_tree().physics_frame
		var travelled: float = body.flat_position().distance_to(from)
		var v: float = body.speed()
		if v > top:
			top = v
			top_at = travelled
		if accel_u < 0.0 and v >= HubTransport.SKATE_CRUISE * 0.95:
			accel_u = travelled
		if body.at_rest():
			rested = true
			break
	return {"top": top, "top_at": top_at, "accel_u": accel_u if accel_u >= 0.0 else 1e9,
		"miss": body.flat_position().distance_to(Vector3(to.x, 0.0, to.z)),
		"end_speed": body.speed(), "rested": rested,
		"mounted": mounted}

## Released at cruise with NO target: nothing pushes, nothing brakes, only
## the coast terms and gravity act. What a board left alone does.
func _coast_run() -> Dictionary:
	var body := _transport.board_body()
	var from := Vector3(-26.0, 0.0, 30.0)
	await _park_board(from)
	var mounted: bool = _transport.mount_board()
	body.stop()
	body.velocity = Vector3(0.0, 0.0, -1.0) * HubTransport.SKATE_CRUISE
	var started: float = body.speed()
	var ticks: int = 0
	var stopped: bool = false
	for t in 1800:
		await get_tree().physics_frame
		ticks = t + 1
		if body.speed() <= body.rest_speed():
			stopped = true
			break
	return {"from": started, "distance": body.flat_position().distance_to(from),
		"seconds": float(ticks) / FPS, "stopped": stopped, "end_speed": body.speed(),
		"mounted": mounted}

# =====================================================================
# PHASE E -- THE DELIVERABLE: HEIGHT AS A FUNCTION OF ARRIVAL SPEED
#
# ⚠️ WHY THE SPEED IS INJECTED AND NOT TAPPED. The independent variable
# of this table is the ARRIVAL SPEED, and there is no tap that names one:
# a target beyond the ramp pushes the board all the way to the foot and
# every run arrives at cruise, which is one row of a table, four times.
# So the board is launched with a velocity and NO target -- nothing
# pushes, nothing brakes, and what is measured is purely what the ramp
# does to an elan. That the player can reach these speeds by tapping is a
# separate question, and PHASE L answers it: the flat run reaches cruise.
#
# ⚠️ AND THE ARRIVAL SPEED IS THE ONE MEASURED AT THE FOOT, never the one
# injected. The board coasts LAUNCH_U before it gets there and the coast
# terms take their cut; publishing the injected number would be
# publishing an input as if it were an observation.
#
# WHAT IS GATED, and it is the SHAPE and not a value:
#
#   * MONOTONE -- more speed in, more height out, on every rung. This is
#     the assertion that fails on the CH60 tree, where the ceiling is a
#     property of the ARC and every rung returns the same fraction of it.
#   * SPREAD -- the fastest rung must beat the slowest by a wide margin,
#     so "monotone" cannot be satisfied by four numbers inside the noise.
#   * ABOVE CH60 -- the fastest rung must clear the published ceiling.
#
# The three together are what tells conversion from a bigger dictated
# pace, and no one of them does it alone.

var _table: Dictionary = {}

func _phase_energy() -> void:
	print("-- PHASE E: how high it gets, BY THE SPEED IT ARRIVES WITH --")
	for index in _park.collider_indices():
		var kind: StringName = _park.module_kind(index)
		if kind == HubSkatepark.KIND_RAIL:
			# The rail is not a ramp: the board passes UNDER its beam and
			# is stopped by a leg (CH60 PHASE J). There is no height to
			# convert to, and a row for it would be a row of zeroes
			# dressed as a measurement.
			print("     [%d] rail: no riding surface above the ground -- see CH60 PHASE J. Skipped."
				% index)
			continue
		var lip: float = float(HubSkatepark.MODULES[index]["size"].y)
		var rows: Array = []
		for want in ARRIVALS:
			var r: Dictionary = await _launch(index, want)
			rows.append(r)
			print("     [%d] %-12s injected %5.2f -> arrived %5.2f u/s   peak y %.3f   (%.1f%% of the %.2f u lip)"
				% [index, String(kind), want, float(r["arrival"]), float(r["peak"]),
					100.0 * float(r["peak"]) / lip, lip])
			_check(bool(r["mounted"]),
				"E[%d] INSTRUMENT: the rider is aboard for the %.1f u/s rung" % [index, want])
			_check(bool(r["reached"]),
				"E[%d] INSTRUMENT: the %.1f u/s rung REACHED the foot -- the row is a real arrival"
					% [index, want])
		_table[index] = rows
		var slow: float = float((rows[0] as Dictionary)["peak"])
		var fast: float = float((rows[rows.size() - 1] as Dictionary)["peak"])
		# INSTRUMENT: the rungs must really differ in arrival speed, or
		# "height rises with speed" is a claim about a variable that never
		# varied -- CLAUDE.md's blind check, applied to the input.
		var v_slow: float = float((rows[0] as Dictionary)["arrival"])
		var v_fast: float = float((rows[rows.size() - 1] as Dictionary)["arrival"])
		_check(v_fast > v_slow + 2.0,
			"E[%d] INSTRUMENT: the rungs really arrive at different speeds (%.2f vs %.2f u/s)"
				% [index, v_slow, v_fast])
		var monotone: bool = true
		for i in range(1, rows.size()):
			if float((rows[i] as Dictionary)["peak"]) < float((rows[i - 1] as Dictionary)["peak"]) - 0.01:
				monotone = false
		_check(monotone,
			"E[%d] the height RISES with the arrival speed on every rung -- it is being CONVERTED"
				% index)
		_check(fast > slow + 0.15,
			"E[%d] and the spread is real, not noise (%.3f u fast vs %.3f u slow)"
				% [index, fast, slow])
		if kind == HubSkatepark.KIND_FUNBOX:
			# The funbox is a DECK, not a transition: the height it offers
			# is bounded by its own top, so the row that matters is that a
			# fast arrival gets ONTO it.
			_check(fast >= lip - 0.05,
				"E[%d] a fast arrival gets ONTO the deck (%.3f of %.3f)" % [index, fast, lip])
			continue
		var ch60: float = float(CH60_REACHED.get(index, 0.0))
		var p6: float = lip * P6_FRACTION
		print("     [%d] CH60 reached %.3f, the 45 deg cap allowed %.3f (P6), this tree reaches %.3f"
			% [index, ch60, p6, fast])
		_check(fast > ch60 * 1.5,
			"E[%d] the fastest arrival CLEARS CH60's ceiling by half again (%.3f > %.3f)"
				% [index, fast, ch60 * 1.5])
		_check(fast > p6,
			"E[%d] and it passes the 45 deg iso-slope that was the real ceiling (%.3f > %.3f)"
				% [index, fast, p6])
		_check(fast <= lip + 0.60,
			"E[%d] and it does not sail through a phantom volume (%.3f <= lip %.3f + 0.60)"
				% [index, fast, lip])
	await _phase_signature()

# =====================================================================
# ⚠️ THE SIGNATURE -- AND IT IS A PAIR TEST, WHICH IS WHY IT IS HERE AND
# NOT INSIDE THE LOOP ABOVE
#
# CLAUDE.md, CH46: "une sonde qui ne compare chaque chose qu'a elle-meme
# ne peut pas voir que deux choses se ressemblent". Every assertion in
# PHASE E asks one module about itself, and a module that answers
# consistently about itself would pass all of them under EITHER law.
#
# The two laws are told apart by a question no single module can be
# asked. Under a SHAPE ceiling -- CH60's 45 deg iso-slope -- the height
# reached is a fraction of the LIP, so two ramps of different heights
# return DIFFERENT heights from the same arrival: 0.577 against 0.386, a
# ratio of 1.495, which is exactly the ratio of their lips. Under an
# ENERGY ceiling the height reached is v^2 / 2g, which knows nothing
# about the lip, so the same arrival must return very nearly the SAME
# height on both.
#
# That is the whole diagnosis of this lot, stated as something the bench
# can fail. The two quarterpipes differ in lip by 45 %; their heights at
# equal arrival speed must not.

func _phase_signature() -> void:
	print("-- PHASE E(2): the ENERGY signature -- two ramps, one arrival, one height --")
	var a: Array = _table.get(2, [])
	var b: Array = _table.get(3, [])
	if a.size() != b.size() or a.is_empty():
		_check(false, "E2 INSTRUMENT: both quarterpipes have a table to compare")
		return
	var lip_a: float = float(HubSkatepark.MODULES[2]["size"].y)
	var lip_b: float = float(HubSkatepark.MODULES[3]["size"].y)
	var lip_ratio: float = maxf(lip_a, lip_b) / minf(lip_a, lip_b)
	var ch60_ratio: float = float(CH60_REACHED[2]) / float(CH60_REACHED[3])
	_check(lip_ratio > 1.30,
		"E2 INSTRUMENT: the two lips really do differ (%.2f x: %.2f u against %.2f u)"
			% [lip_ratio, lip_a, lip_b])
	_check(absf(ch60_ratio - lip_ratio) < 0.15,
		"E2 INSTRUMENT: and CH60's two figures stood in exactly that ratio (%.3f vs %.3f) -- a SHAPE ceiling"
			% [ch60_ratio, lip_ratio])
	# ⚠️ AND THE FLOOR BELOW WAS PUT THERE BY THIS LOT'S OWN RED PASS.
	#
	# With the inertia neutralised in `SkateBoardBody.drive()`, every peak
	# in both tables is 0.000 -- and this phase came back ALL GREEN, twice
	# over: `worst ratio 0.000 < 1.25` and `0.000 vs 1.448`. A ratio of
	# two zeroes is not a measurement of similarity, it is the absence of
	# a measurement, and CLAUDE.md's blind check is exactly this shape:
	# "rien n'a bouge" and "rien ne tourne" read the same unless something
	# asserts the bench was alive. Two instruments that only ever check
	# CONSTANTS -- the lips, CH60's published pair -- cannot do it, because
	# constants cannot go red.
	var lowest: float = 1e9
	for i in a.size():
		lowest = minf(lowest, minf(float((a[i] as Dictionary)["peak"]),
			float((b[i] as Dictionary)["peak"])))
	_check(lowest > 0.02,
		"E2 INSTRUMENT: every row of both tables is a real climb (lowest peak %.3f u > 0.02)" % lowest)
	if lowest <= 0.02:
		return
	var worst: float = 0.0
	for i in a.size():
		var ha: float = float((a[i] as Dictionary)["peak"])
		var hb: float = float((b[i] as Dictionary)["peak"])
		var v: float = float((a[i] as Dictionary)["arrival"])
		var ratio: float = maxf(ha, hb) / maxf(minf(ha, hb), 1e-6)
		worst = maxf(worst, ratio)
		print("     arriving at %5.2f u/s:  2.10 u ramp -> %.3f   1.45 u ramp -> %.3f   ratio %.3f"
			% [v, ha, hb, ratio])
	print("     worst ratio %.3f   (the lips are %.3f apart, and CH60's heights were %.3f apart)"
		% [worst, lip_ratio, ch60_ratio])
	_check(worst < 1.25,
		"E2 the same arrival buys the SAME HEIGHT on both ramps (worst ratio %.3f < 1.25)" % worst)
	_check(worst < lip_ratio - 0.15,
		"E2 and that is NOT the lip ratio -- the ceiling is ENERGY, not SHAPE (%.3f vs %.3f)"
			% [worst, lip_ratio])

## One launch: park the board LAUNCH_U out from the module's foot on its
## own approach axis, give it `want` u/s toward the module, and let it
## coast in. Returns the speed measured AT the foot and the peak height.
func _launch(index: int, want: float) -> Dictionary:
	var body := _transport.board_body()
	var node := _park.module_node(index)
	# The module's own +z is the way a rider comes at it -- the axis CH57
	# derived the published stations from, read through the node's
	# transform and never typed.
	var d: Vector3 = node.global_transform.basis * Vector3(0.0, 0.0, 1.0)
	var dir := Vector3(d.x, 0.0, d.z).normalized()
	var kind: StringName = _park.module_kind(index)
	# A quarterpipe is met from its FOOT side (local -z); a funbox from
	# either, and its ramp starts half its length plus the ramp run out.
	var reach: float = float(HubSkatepark.MODULES[index]["size"].z) * 0.5
	if kind == HubSkatepark.KIND_FUNBOX:
		reach = float(HubSkatepark.MODULES[index]["size"].z) * 0.5 + 1.44
	var centre: Vector3 = _park.module_centre(index)
	var foot: Vector3 = centre - dir * reach
	var from: Vector3 = foot - dir * LAUNCH_U
	await _park_board(from)
	var mounted: bool = _transport.mount_board()
	if not mounted:
		print("     !! mount refused: state=%s hopping=%s on_carrier=%s on_vehicle=%s riding_board=%s keepy=%s board=%s"
			% [str(_keepy.get("_state")), _keepy.is_hopping(), _keepy.is_on_carrier(),
				_keepy.is_on_vehicle(), _transport.is_riding_board(),
				str(_keepy.global_position.snappedf(0.01)),
				str(body.global_position.snappedf(0.01))])
	body.stop()
	body.rotation.y = atan2(dir.x, dir.z)
	body.velocity = dir * want
	var peak: float = -1e9
	var arrival: float = -1.0
	var reached_foot: bool = false
	for _t in RUN_TICKS:
		await get_tree().physics_frame
		var here: Vector3 = body.flat_position()
		if not reached_foot and here.distance_to(from) >= LAUNCH_U:
			arrival = body.speed()
			reached_foot = true
		if reached_foot:
			peak = maxf(peak, body.global_position.y)
		if reached_foot and body.speed() <= body.rest_speed() and body.global_position.y < 0.02:
			break
	return {"arrival": arrival if reached_foot else 0.0,
		"peak": peak if reached_foot else 0.0, "reached": reached_foot,
		"mounted": mounted}

# =====================================================================
# PHASE R -- RED BEFORE GREEN, AT RUNTIME, AND THE ANSWER IT GAVE WAS
# NOT THE ONE THIS PHASE WAS WRITTEN TO EXPECT
#
# The cap goes back to Godot's 45 deg on the LIVE body and the fastest
# arrival is rolled again. This phase was first written to demand that
# the climb COLLAPSE onto CH60's published 0.577 / 0.386 -- one lever,
# one number, cause proved.
#
# ⚠️ IT DID NOT, AND THE MEASUREMENT IS THE RESULT. With the 45 deg cap
# back and the inertia still there the board reaches 0.855 on the 2.10 u
# lip and 0.771 on the 1.45 u one: well down from the 1.106 / 1.176 this
# tree reaches, and well UP from what CH60 measured. The reason is not
# subtle once it is seen -- CH60's board had no inertia EITHER, so
# restoring one of the two changes cannot restore its number. A body
# carrying speed into the facet the engine calls a wall does not stop
# there; it keeps the vertical velocity the climb gave it and coasts a
# little further up, ballistic.
#
# So the phase gates the DECOMPOSITION instead, which is what it should
# have asked for from the start and is a stronger statement than the one
# it replaced:
#
#     no inertia, 45 deg cap  (CH60, published)     0.577      0.386
#     inertia,    45 deg cap  (this phase)          0.855      0.771
#     inertia,    88 deg cap  (this tree, PHASE E)  1.106      1.176
#
# Each lever is worth roughly half, NEITHER IS DECORATIVE, and a lot
# that had shipped only one of them would have moved the number and left
# the ramps unridable. CLAUDE.md, CH46: two passes that do not overlap
# are the proof that both halves are really covered, where one pass that
# reddens everything distinguishes nothing. The second pass -- the one
# that neutralises the INERTIA and leaves the cap alone -- is the
# file-level red pass in this lot's dossier, and PHASE E's monotonicity
# is the assertion it turns red.
#
# ⚠️ THE RESTORE IS ASSERTED, NOT ASSUMED. A red pass that leaves the
# world neutralised turns every phase after it into a measurement of the
# broken tree, and nothing downstream can tell.

func _phase_red() -> void:
	print("-- PHASE R: put the 45 deg cap back and watch the climb collapse onto CH60 --")
	var body := _transport.board_body()
	var kept: float = body.floor_max_angle
	body.floor_max_angle = deg_to_rad(45.0)
	for index in [2, 3]:
		if not _park.collider_indices().has(index):
			continue
		var lip: float = float(HubSkatepark.MODULES[index]["size"].y)
		var r: Dictionary = await _launch(index, ARRIVALS[ARRIVALS.size() - 1])
		var p6: float = lip * P6_FRACTION
		var ch60: float = float(CH60_REACHED[index])
		print("     [%d] with the 45 deg cap back: arrived %.2f u/s, peak %.3f   (CH60 %.3f, P6 %.3f)"
			% [index, float(r["arrival"]), float(r["peak"]), ch60, p6])
		_check(float(r["arrival"]) > 5.0,
			"R[%d] INSTRUMENT: the neutralised run arrived fast too (%.2f u/s) -- it is the CAP that changed"
				% [index, float(r["arrival"])])
		var rows_i: Array = _table.get(index, [])
		var with_cap: float = 0.0 if rows_i.is_empty() \
			else float((rows_i[rows_i.size() - 1] as Dictionary)["peak"])
		print("     [%d] decomposition:  CH60 (no inertia, 45 deg) %.3f   |  inertia + 45 deg %.3f   |  this tree %.3f"
			% [index, ch60, float(r["peak"]), with_cap])
		_check(float(r["peak"]) < with_cap - 0.20,
			"R[%d] the 45 deg cap COSTS real height (%.3f against this tree's %.3f)"
				% [index, float(r["peak"]), with_cap])
		_check(float(r["peak"]) > ch60 + 0.15,
			"R[%d] and it does NOT fall back to CH60 (%.3f > %.3f) -- the inertia is the OTHER half"
				% [index, float(r["peak"]), ch60])
		_check(ch60 < p6 + 0.06,
			"R[%d] INSTRUMENT: CH60's figure really was the 45 deg iso-slope (%.3f vs P6 %.3f)"
				% [index, ch60, p6])
	body.floor_max_angle = kept
	_check(absf(body.floor_max_angle - SkateBoardBody.FLOOR_MAX_ANGLE) < 1e-6,
		"R the cap is RESTORED, so nothing below measures the broken tree")
	var back: Dictionary = await _launch(2, ARRIVALS[ARRIVALS.size() - 1])
	var rows: Array = _table.get(2, [])
	var was: float = 0.0 if rows.is_empty() else float((rows[rows.size() - 1] as Dictionary)["peak"])
	print("     [2] restored: peak %.3f   (it was %.3f before the red pass)" % [float(back["peak"]), was])
	# The same floor, and for the same reason the red pass gave: "it came
	# back to what it was" is satisfied by two zeroes.
	_check(float(back["peak"]) > 0.30,
		"R INSTRUMENT: the restored run is a real climb (%.3f u), not two zeroes agreeing"
			% float(back["peak"]))
	_check(float(back["peak"]) > was - 0.15,
		"R and the climb COMES BACK when the cap is restored (%.3f, was %.3f)"
			% [float(back["peak"]), was])

# =====================================================================
# PHASE S -- THE STALL GUARD, ON BOTH OF ITS VERDICTS
#
# The brief's garde-fou 2: with inertia, "coince" and "climbing slowly"
# look alike. CH57 scored per-tick FLAT displacement, which near a lip is
# almost zero on a legitimate climb -- and which an oscillation at the
# foot of a ramp satisfies for ever. CH61 scores PROGRESS toward the
# target instead (CH42: a run is scored on the furthest it got).
#
# One bench, two opposite verdicts, because a phase that only ever sees
# one of them cannot tell a guard from a guard that never fires.

func _phase_stall() -> void:
	print("-- PHASE S: the guard does not cut a climb, and still catches a wall --")
	var body := _transport.board_body()
	# (1) A CLIMB, tapped THROUGH the transport door, aimed past the lip.
	var index: int = 2
	var node := _park.module_node(index)
	var d: Vector3 = node.global_transform.basis * Vector3(0.0, 0.0, 1.0)
	var dir := Vector3(d.x, 0.0, d.z).normalized()
	var centre: Vector3 = _park.module_centre(index)
	var from: Vector3 = centre - dir * 9.0
	await _park_board(from)
	_check(_transport.mount_board(), "S INSTRUMENT: the rider is aboard for the climb")
	_bench.aim(HubRegion.clamp_to(centre + dir * 3.0))
	var peak: float = -1e9
	var peak_tick: int = -1
	var target_at_peak: bool = false
	var climbing_ticks: int = 0
	for t in 300:
		await get_tree().physics_frame
		var y: float = body.global_position.y
		if y > peak:
			peak = y
			peak_tick = t
			target_at_peak = _bench.has_destination()
		if y > 0.10:
			climbing_ticks += 1
	print("     climb: peak y %.3f at tick %d, guard still held the target: %s   (%d ticks off the ground)"
		% [peak, peak_tick, target_at_peak, climbing_ticks])
	_check(peak > 0.30,
		"S INSTRUMENT: the tapped run really climbed (peak %.3f u) -- a flat run would pass for free" % peak)
	_check(climbing_ticks > 20,
		"S INSTRUMENT: and it spent real time up there (%d ticks above 0.10 u)" % climbing_ticks)
	# Guarded by the two instruments above, which the red pass confirmed
	# go red on a bench where nothing climbed -- this assertion is about
	# a climb, and a run with no climb must not be allowed to sign it.
	# CH64: the game's stall guard is gone with the TAP scheme (a finger is
	# its own guard); what is gated here is the PROGRESS-BASED guard the
	# bench inherited verbatim from it -- CH61's correction, that a climb
	# makes almost no flat displacement and must not be shot down as a
	# stall -- so a bench that aims past a lip is still holding at the top.
	_check(peak > 0.30 and target_at_peak,
		"S the bench's progress guard did NOT cut the climb: the finger was still down at the highest point")
	# (2) A WALL. The funbox's east face, head on -- CH57 PHASE L's own
	# station, which is 90 deg and stops the board dead.
	var half_x: float = float(HubSkatepark.MODULES[0]["size"].x) * 0.5
	var box: Vector3 = _park.module_centre(0)
	var wall_from := Vector3(box.x + half_x + 5.0, 0.0, box.z)
	var wall_to := Vector3(box.x - half_x - 5.0, 0.0, box.z)
	await _park_board(wall_from)
	_check(_transport.mount_board(), "S INSTRUMENT: the rider is aboard for the wall run")
	_bench.aim(HubRegion.clamp_to(wall_to))
	var dropped: bool = false
	var dropped_at: int = -1
	for t in 420:
		await get_tree().physics_frame
		if _bench.stalled_out():
			dropped = true
			dropped_at = t
			break
	print("     wall: the bench's guard lifted the finger after %d ticks (board at x %.3f, face at %.3f)"
		% [dropped_at, body.flat_position().x, box.x + half_x])
	_check(dropped,
		"S and the same guard STILL catches a wall: the finger was lifted rather than held into it for ever")
	_check(body.flat_position().x > box.x + half_x - 0.40,
		"S INSTRUMENT: it was stopped AT the face (x %.3f) -- not dropped somewhere else"
			% body.flat_position().x)
	# CH64 -- THE GAME'S OWN PROPERTY, now that no guard rescues a player:
	# a board pinned against a wall keeps its steering authority (CLAUDE.md,
	# CH42 -- the heading is WRITTEN, not scaled by a forward speed the
	# wall is eating). Hold the finger AWAY from the face and the board
	# must leave it under its own push.
	var pinned: Vector3 = body.flat_position()
	_bench.hold(Vector3(1.0, 0.0, 0.0))
	for _t in 60:
		await get_tree().physics_frame
	_bench.release()
	var freed: float = body.flat_position().distance_to(pinned)
	print("     pinned at x %.3f, a finger held away moved it %.3f u in 60 ticks" % [pinned.x, freed])
	_check(freed > 1.0,
		"S a board pinned against a wall still obeys a finger held away from it (%.3f u)" % freed)

# =====================================================================
# THE BENCH'S OWN HOUSEKEEPING

## Puts the board and its rider on the ground at `flat`, at rest, with no
## target and no velocity carried over from the previous run. CLAUDE.md,
## CH43: an assertion on a HELD value re-reads whatever the last one left
## unless the reset is explicit -- and a launch that inherited the last
## launch's velocity would publish a table of the wrong variable.
## ⚠️ AND THE DISMOUNT HAPPENS AT `NEUTRAL`, NOT WHERE THE RUN ENDED.
##
## MEASURED, and it cost four runs of this bench before it was read
## rather than guessed. Every row from the funbox's third rung onward
## came back `arrived 0.00, peak 0.000`; the mount assertion said the
## rider was never aboard; the state print said `state=7`, which is
## `KeepyHopper.State.ON_SEESAW`.
##
## `leave_board` steps the rider off BESIDE the board and that step-off
## is a hop, and a hop that LANDS is offered to every hotspot HubWorld
## holds. The funbox's own launch station sits 2 u short of its foot at
## z = 40.46, which is inside the seesaw's landing disc -- so the bench
## dismounted its rider straight onto the seesaw, the seesaw took him,
## and `mount_carrier` refused every mount after that because its one
## precondition is `_state == IDLE`.
##
## Nothing was wrong with the game: a tap that lands a walk beside the
## seesaw is SUPPOSED to offer it. What was wrong is a bench that put its
## rider down inside another prop's hotspot and then measured a board
## nobody was riding. The repair is to hand the board back on open lawn
## -- the same station PHASE L's flat run uses, which is why that phase
## never showed the defect -- and only then to move it to the station the
## run needs.
const NEUTRAL: Vector3 = Vector3(-26.0, 0.0, 30.0)

func _park_board(flat: Vector3) -> void:
	var body := _transport.board_body()
	if _transport.is_riding_board():
		# Carry him out to open lawn BEFORE putting him down, so the
		# step-off lands where no hotspot is listening.
		body.stop()
		body.velocity = Vector3.ZERO
		body.global_position = HubSurface.ground(NEUTRAL)
		_keepy.call("follow_carrier")
		await get_tree().physics_frame
		_transport.leave_board()
		for _i in 20:
			await get_tree().physics_frame
	# ⚠️ AND THEN WAIT FOR HIM TO BE OFF IT AND STANDING STILL.
	# `KeepyHopper.mount_carrier` refuses outright unless the state is
	# IDLE. Measured: the funbox's first two rungs ran and every row after
	# them read `arrived 0.00, peak 0.000` -- the mount had silently been
	# refused and `drive()` was never called on a board nobody was riding.
	#
	# BOTH conditions, and CLAUDE.md says why the obvious one is not
	# enough: "un demontage de porteur qui saute n'emet ni became_idle ni
	# carrier_dismounted ... Lire l'ETAT (is_on_carrier / is_hopping), pas
	# le signal." A hopper part-way out of a carrier is neither hopping
	# nor idle, and a wait that only asked about the hop broke out of the
	# loop on its first iteration.
	for _i in 180:
		if not _keepy.is_hopping() and not _keepy.is_on_carrier():
			break
		await get_tree().physics_frame
	_keepy.dismount_vehicle()
	body.stop()
	body.velocity = Vector3.ZERO
	body.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	body.rotation.y = 0.0
	_keepy.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	for _i in SETTLE:
		await get_tree().physics_frame
