extends Node
## CH82 -- THE GRIND, AND WHAT A BENCH CAN AND CANNOT SIGN ABOUT IT.
##
## =====================================================================
## ⚠️ WHAT THIS PROBE DOES NOT SIGN, WRITTEN FIRST BECAUSE CH62 SAYS SO
##
## It cannot tell you whether being TAKEN onto a rail without asking
## feels good. CH61 shipped a physics layer whose every number was right
## and which Mathieu could not enjoy, and CH62's answer is that a
## headless bench signs that a response is a CURVE, that an effect is
## WIRED to it, that nothing runs outside its switch and what it COSTS
## -- never a sensation. The magnetism's reach, its 40 deg of tolerance
## and the rail's friction are feel numbers and they are named as such in
## the lot's report, for a device call.
##
## What it does sign, and each of these is a line of Mathieu's brief:
##
##   * PHASE A -- the instrument, the published table, and both sides of
##     every threshold this mechanic owns.
##   * PHASE E -- "la vitesse d'entree dans le grind vient de la vitesse
##     au sol au moment du contact": an EQUALITY, measured at three
##     approach speeds so it is a curve and not a coincidence, with the
##     velocity vector at the catch gated for magnitude and for pitch
##     ("pas de vecteur de vitesse aberrant").
##   * PHASE D -- "une deceleration propre au rail": the published law,
##     fitted tick by tick, and MEASURED to be gentler than the ground's
##     at the same speed rather than asserted to be.
##   * PHASE M -- the mount, which is the one window where this file
##     writes a position the law of motion did not produce. Bounded by
##     the board's own POP_SPEED, with the rider on the deck every tick
##     and nothing under HubSurface.
##   * PHASE X -- "une sortie claire": all four of them, and after each
##     one the board is off the line, moving, and catchable again only
##     when it should be.
##   * PHASE J -- CH60's contract, unchanged: a board CROSSING the rail
##     still passes under the beam. This is the phase that proves the
##     alignment test is what protects it.
##   * PHASE R -- red before green, at RUNTIME: four neutralisations,
##     each with its positive twin in the same run, so no threshold is
##     signed from one side (CH65).
##
## =====================================================================
## AND IT RUNS HEADLESS
##
## SkatePhysicsProbe's reasoning, argument for argument: everything below
## is transforms, the physics server and integers, and not one line reads
## a pixel or a MultiMesh instance -- CH50's axis. The bench drives
## through the REAL writer (SkateTouchInput, via SkateBench) and that
## writer's mapping is an arithmetic inverse that never projects, so the
## dummy driver's 0x0 container cannot reach it.

const BUDGET_S: float = 1800.0
const FPS: float = 60.0
const SETTLE: int = 4
const RIDE_TICKS: int = 360
## Where the board is carried before its rider is put down, so a
## dismount never lands inside another prop's hotspot. SkatePhysicsProbe's
## NEUTRAL_PARK, and the same station for the same reason.
const NEUTRAL_PARK: Vector3 = Vector3(12.0, 0.0, 52.0)

## The module indices this lot lays, read back rather than typed: a probe
## that hard-coded 5, 6, 7 would be a second spelling of the table.
var _ledges: Array[int] = []
var _rail: int = -1

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _park: HubSkatepark = null
var _transport: HubTransport = null
var _board: SkateBoardBody = null
var _bench: SkateBench = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE GRIND PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_grind_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _run() -> void:
	print("=== SKATE GRIND PROBE -- CH82 ===")
	print("driver: %s" % DisplayServer.get_name())
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	await get_tree().process_frame
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	_park = _hub.find_child("Skatepark", true, false) as HubSkatepark
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	if _keepy == null or _park == null or _transport == null:
		push_error("SkateGrindProbe: hub is missing Keepy / Skatepark / Transport.")
		get_tree().quit(1)
		return
	_board = _transport.board_body()
	_bench = SkateBench.new()
	_bench.name = "Bench"
	add_child(_bench)
	_bench.setup(_transport, _hub.find_child("Camera3D", true, false) as Camera3D)
	for index in HubSkatepark.MODULES.size():
		var kind: StringName = StringName(HubSkatepark.MODULES[index]["kind"])
		if kind == HubSkatepark.KIND_LEDGE:
			_ledges.append(index)
		elif kind == HubSkatepark.KIND_RAIL:
			_rail = index
	_phase_instrument()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every number below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_entry()
	await _phase_decel()
	await _phase_mount()
	await _phase_exits()
	await _phase_crossing()
	await _phase_red()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE A -- THE INSTRUMENT, THE TABLE, AND BOTH SIDES OF EVERY THRESHOLD
#
# ⚠️ THE ORDER MATTERS. Everything after this phase is a ride, and a ride
# measured against a table nobody checked is a number under someone
# else's label (CLAUDE.md's "%e" defect). So the published lines are
# confronted with the nodes that carry them FIRST.

func _phase_instrument() -> void:
	print("-- PHASE A: the instrument, the published lines, and the thresholds --")
	var edges: Array = _park.grind_edges()
	print("     the park publishes %d grind lines; the board holds %d"
		% [edges.size(), _board.grind_edge_count()])
	_check(edges.size() > 0, "A INSTRUMENT: the park publishes at least one grind line")
	_check(_board.grind_edge_count() == edges.size(),
		"A the board was handed every line the park publishes (HubWorld's one wiring line)")
	_check(_rail >= 0 and _ledges.size() > 0,
		"A INSTRUMENT: the table holds a rail and %d ledges" % _ledges.size())
	_check(edges.size() == 1 + _ledges.size(),
		"A and exactly the rail and the ledges are grindable -- %d lines for %d candidates"
			% [edges.size(), 1 + _ledges.size()])
	# Every line, against the node that carries it. The park composes them
	# through `global_transform`; this recomposes them from the module's
	# own centre and yaw, which is a DIFFERENT reading of the same
	# placement -- if the two agree, neither is a transcription of the
	# other.
	var top: float = -1e9
	var worst_recompose: float = 0.0
	for e in edges:
		var index: int = int(e["module"])
		var spec: Dictionary = HubSkatepark.MODULES[index]
		var local: Array = HubSkatepark.grind_line_local(spec)
		var yaw: float = float(spec["yaw"])
		var at: Vector2 = spec["at"]
		var base := HubSurface.ground(Vector3(at.x, 0.0, at.y))
		for k in 2:
			var l: Vector3 = local[k]
			var want := base + Vector3(
				l.x * cos(yaw) + l.z * sin(yaw), l.y, -l.x * sin(yaw) + l.z * cos(yaw))
			var got: Vector3 = e["a"] if k == 0 else e["b"]
			worst_recompose = maxf(worst_recompose, want.distance_to(got))
		var a: Vector3 = e["a"]
		var b: Vector3 = e["b"]
		top = maxf(top, maxf(a.y, b.y))
		var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var off: float = rad_to_deg(absf(asin(clampf(dir.x * HubSkatepark.FLOW.y
			- dir.z * HubSkatepark.FLOW.x, -1.0, 1.0))))
		print("     [%d] %-12s y %.3f  length %.3f  %5.2f deg off FLOW"
			% [index, String(spec["kind"]), a.y, a.distance_to(b), off])
		if StringName(spec["kind"]) == HubSkatepark.KIND_LEDGE:
			_check(off < 0.01,
				"A[%d] the ledge is laid ALONG the park's flow (%.4f deg off)" % [index, off])
		else:
			_check(off < rad_to_deg(acos(SkateBoardBody.GRIND_ALIGN_COS)),
				"A[%d] the rail stands %.2f deg off the flow, inside the %.0f deg the catch allows"
					% [index, off, rad_to_deg(acos(SkateBoardBody.GRIND_ALIGN_COS))])
	_check(worst_recompose < 0.0005,
		"A the published lines ARE the nodes' own placement (worst disagreement %.6f u)" % worst_recompose)
	_check(absf(top - _park.grind_edge_max_height()) < 1e-6,
		"A and the park's published ceiling is the one the lines actually reach (%.4f)" % top)
	# ---- the reach, and the bound on the lift --------------------------
	print("     GRIND_CATCH_DROP %.4f = POP_SPEED %.2f x GRIND_MOUNT_S %.4f ; tallest line %.3f"
		% [SkateBoardBody.GRIND_CATCH_DROP, SkateBoardBody.POP_SPEED,
			SkateBoardBody.GRIND_MOUNT_S, top])
	_check(absf(SkateBoardBody.GRIND_CATCH_DROP
			- SkateBoardBody.POP_SPEED * SkateBoardBody.GRIND_MOUNT_S) < 1e-9,
		"A the catch's reach IS the pop's own reach in the mount's own time -- so the lift can never exceed POP_SPEED")
	_check(top < SkateBoardBody.GRIND_CATCH_DROP,
		"A every published line is inside the catch's reach (tallest %.3f < %.4f, margin %.3f u)"
			% [top, SkateBoardBody.GRIND_CATCH_DROP, SkateBoardBody.GRIND_CATCH_DROP - top])
	# ⚠️ AND THE RAIL IS OUT OF THE BOARD'S OWN REACH, which is the
	# measurement that makes this a magnetism and not a physics outcome.
	# Said here, in the probe, because it is the fact the whole design
	# rests on and a fact that lives only in a comment is a fact that
	# stops being checked.
	var apex: float = SkateBoardBody.POP_SPEED * SkateBoardBody.POP_SPEED \
		/ (2.0 * SkateBoardBody.GRAVITY)
	print("     the board's own pop reaches %.4f u from the flat; the tallest line is %.3f" % [apex, top])
	_check(top > apex,
		"A the tallest line is ABOVE what the board can reach on its own (%.3f > %.4f) -- the catch is a magnetism and this probe says so"
			% [top, apex])
	# ---- the friction, both ends --------------------------------------
	var longest: float = 0.0
	for e in edges:
		longest = maxf(longest, (e["a"] as Vector3).distance_to(e["b"] as Vector3))
	var cruise: float = HubTransport.SKATE_CRUISE
	var slide: float = cruise * cruise / (2.0 * SkateBoardBody.GRIND_DECEL)
	var ground: float = _board.drag_k() * cruise * cruise + _board.roll_stop()
	print("     GRIND_DECEL %.4f u/s2 -> a board entering at cruise slides %.2f u; longest line %.2f u"
		% [SkateBoardBody.GRIND_DECEL, slide, longest])
	print("     the GROUND takes %.4f u/s2 at the same speed (drag_k %.6f x %.1f^2 + roll_stop %.4f)"
		% [ground, _board.drag_k(), cruise, _board.roll_stop()])
	_check(slide > longest,
		"A a board entering at cruise CLEARS the longest line (%.2f u of slide for %.2f u of line)"
			% [slide, longest])
	_check(SkateBoardBody.GRIND_DECEL < ground,
		"A steel is slipperier than concrete: %.4f < %.4f u/s2" % [SkateBoardBody.GRIND_DECEL, ground])
	print("     GRIND_MIN_SPEED %.4f u/s (= sqrt(2 x %.4f x %.2f), one deck length of slide)"
		% [SkateBoardBody.GRIND_MIN_SPEED, SkateBoardBody.GRIND_DECEL, SkateparkMesh.DECK_LENGTH])
	print("     GRIND_CATCH_R %.3f  RISE %.3f  ALIGN %.0f deg  BAIL %.0f deg  COOLDOWN %.4f s"
		% [SkateBoardBody.GRIND_CATCH_R, SkateBoardBody.GRIND_CATCH_RISE,
			rad_to_deg(acos(SkateBoardBody.GRIND_ALIGN_COS)),
			rad_to_deg(acos(SkateBoardBody.GRIND_BAIL_COS)), SkateBoardBody.GRIND_COOLDOWN_S])
	_check(SkateBoardBody.GRIND_BAIL_COS < SkateBoardBody.GRIND_ALIGN_COS,
		"A the way OFF is wider than the way ON -- a rider correcting his line cannot fall off by accident")
	_check(not _board.grinding() and _board.grind_rides() == 0,
		"A INSTRUMENT: nothing has been ground before the first ride")
	print("")

# =====================================================================
# THE RIDE HARNESS
#
# SkatePhysicsProbe's `_roll`, cut down to what this lot measures and
# with its dismount dance kept verbatim -- a rider put down where a ride
# ended lands in another prop's hotspot and every mount afterwards is
# refused (CH61, measured).

func _roll(label: String, from: Vector3, to: Vector3, ticks: int,
		speed_cap: float = INF, bail_after: int = -1, bail_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	if _transport.is_riding_board():
		_board.stop()
		_board.velocity = Vector3.ZERO
		_board.global_position = HubSurface.ground(NEUTRAL_PARK)
		_keepy.call("follow_carrier")
		await get_tree().physics_frame
		_transport.leave_board()
		for _i in 20:
			await get_tree().physics_frame
	_keepy.dismount_vehicle()
	_board.stop()
	_board.velocity = Vector3.ZERO
	_board.global_position = HubSurface.ground(Vector3(from.x, 0.0, from.z))
	# ⚠️ PARKED FACING THE RUN. CH65: a board parked facing north and aimed
	# south spends 2.1 s pivoting and describes a CURVE, and every station
	# a bench reads off that run is somewhere else.
	var aim := Vector3(to.x - from.x, 0.0, to.z - from.z)
	_board.rotation.y = atan2(aim.x, aim.z) if aim.length() > 0.0001 else 0.0
	_keepy.global_position = HubSurface.ground(Vector3(from.x, 0.0, from.z))
	for _i in SETTLE:
		await get_tree().physics_frame
	var mounted: bool = _transport.mount_board()
	_bench.aim(HubRegion.clamp_to(to), KeepyHopper.ARRIVE_EPSILON, speed_cap)
	var t := {"mounted": mounted, "path": 0.0, "caught": false, "catch_tick": -1,
		"approach": -1.0, "prev_approach": -1.0, "entry": -1.0, "catch_module": -1,
		"catch_speed_after": -1.0, "catch_vy": 0.0, "catch_dy": 0.0,
		"grind_ticks": 0, "max_y": -1e9, "under_surface": 0, "rider_off": 0,
		"mount_rate": 0.0, "mount_ticks": 0, "run": 0.0, "exit_speed": -1.0,
		"exit_at": Vector3.ZERO, "exit_tick": -1, "airborne_after": 0,
		"samples": [], "end": Vector3.ZERO, "rides": 0, "max_speed": 0.0, "catch_nose": 0.0}
	var last: Vector3 = _board.flat_position()
	var was_grinding: bool = false
	var rides0: int = _board.grind_rides()
	for tick in ticks:
		var speed_before: float = _board.speed()
		var y_before: float = _board.global_position.y
		await get_tree().physics_frame
		var flat: Vector3 = _board.flat_position()
		var y: float = _board.global_position.y
		t["path"] = float(t["path"]) + flat.distance_to(last)
		last = flat
		t["max_y"] = maxf(float(t["max_y"]), y)
		t["max_speed"] = maxf(float(t["max_speed"]), _board.speed())
		if y < HubSurface.height_at(flat) - 0.0005:
			t["under_surface"] = int(t["under_surface"]) + 1
		if _transport.is_riding_board():
			var want: float = y + SkateparkMesh.DECK_TOP
			if absf(_keepy.global_position.y - want) > 0.0005:
				t["rider_off"] = int(t["rider_off"]) + 1
		var now_grinding: bool = _board.grinding()
		# ⚠️ EVERYTHING BELOW IS THE **FIRST** GRIND OF THE RUN AND ONLY
		# IT. A first version recorded on every catch and let each one
		# overwrite the last, which is how this bench came to print an
		# entry speed from one grind beside the first tick of another --
		# CLAUDE.md's "%e" defect, a true number under another control's
		# label. It matters here because the park LINKS: a board that
		# rides ledge 5 to its end falls straight into the rail's catch
		# (measured: exit at z 44.20, caught again 4 ticks later at
		# z 44.69), which is the layout working and is not what any of
		# these assertions is about.
		if now_grinding and not was_grinding and not bool(t["caught"]):
			t["caught"] = true
			t["catch_tick"] = tick
			# ⚠️ READ BEFORE THE RAIL'S FIRST TICK REWRITES THE VELOCITY.
			# The catch runs at the END of drive(), so on this frame the
			# velocity is still the APPROACH's; the grind branch replaces
			# it on the NEXT tick. This is therefore the one frame in
			# which "what it was doing on the ground" can be read at all.
			t["approach"] = _board.speed()
			t["prev_approach"] = speed_before
			t["entry"] = _board.grind_entry_speed()
			var ed: Array = _board.grind_edges_view()
			var gi: int = _board.grind_index()
			t["catch_module"] = int(ed[gi].get("module", -1))
			t["catch_dy"] = y - float((ed[gi]["a"] as Vector3).y)
			# ⚠️ WHERE THE BOARD'S NOSE WAS. This is what
			# GRIND_CATCH_LEAD buys and the only number that says
			# whether it bought it: a ledge's end face is a wall, and a
			# catch that fires once the board's CENTRE is on the line
			# fires after its nose has already hit. Signed along the
			# direction of travel from the end the board came in by --
			# negative is clear of it.
			var ea: Vector3 = ed[gi]["a"]
			var eb: Vector3 = ed[gi]["b"]
			var edir := Vector3(eb.x - ea.x, 0.0, eb.z - ea.z).normalized()
			var espan: float = Vector2(eb.x - ea.x, eb.z - ea.z).length()
			var facing := Vector3(sin(_board.rotation.y), 0.0, cos(_board.rotation.y))
			var nose: Vector3 = _board.flat_position() + facing * SkateparkMesh.DECK_LENGTH * 0.5
			var nose_along: float = (nose - Vector3(ea.x, 0.0, ea.z)).dot(edir)
			t["catch_nose"] = nose_along if _board.grind_speed() >= 0.0 and \
				(_board.velocity.z * edir.z + _board.velocity.x * edir.x) >= 0.0 \
				else espan - nose_along
		var first_grind: bool = bool(t["caught"]) and int(t["exit_tick"]) < 0
		if now_grinding and first_grind:
			t["grind_ticks"] = int(t["grind_ticks"]) + 1
			t["mount_rate"] = maxf(float(t["mount_rate"]), (y - y_before) * FPS)
			if _board.grind_mount() < 1.0:
				t["mount_ticks"] = int(t["mount_ticks"]) + 1
			t["run"] = _board.grind_run()
			(t["samples"] as Array).append([float(tick), _board.grind_speed()])
			if bail_after >= 0 and int(t["grind_ticks"]) == bail_after:
				_bench.hold(bail_dir)
		if was_grinding and not now_grinding and int(t["exit_tick"]) < 0:
			t["exit_tick"] = tick
			t["exit_speed"] = _board.speed()
			t["exit_at"] = _board.global_position
		if not now_grinding and int(t["exit_tick"]) >= 0 and _board.airborne():
			t["airborne_after"] = int(t["airborne_after"]) + 1
		# The velocity the FIRST grind tick wrote, read on the tick after
		# the catch: this is the "aberrant vector" gate's subject.
		if now_grinding and first_grind and int(t["grind_ticks"]) == 2 \
				and float(t["catch_speed_after"]) < 0.0:
			t["catch_speed_after"] = _board.velocity.length()
			t["catch_vy"] = _board.velocity.y
		was_grinding = now_grinding
	t["end"] = _board.global_position
	t["rides"] = _board.grind_rides() - rides0
	print("     %-42s path %6.2f u  caught %s (tick %3d, module %d)  grind %3d ticks  run %5.2f u  exit %s  catches %d"
		% [label, float(t["path"]), str(t["caught"]), int(t["catch_tick"]), int(t["catch_module"]),
			int(t["grind_ticks"]), float(t["run"]),
			("n/a" if float(t["exit_speed"]) < 0.0 else "%.3f u/s" % float(t["exit_speed"])),
			int(t["rides"])])
	return t

## The world-space line of a module, as the park publishes it.
func _line_of(module: int) -> Array:
	for e in _park.grind_edges():
		if int(e["module"]) == module:
			return [e["a"], e["b"]]
	return []

## The two stations of a run laid ALONG a module's grind line: `pre` u
## short of the end it starts from, `post` u past the one it ends at.
## Derived from the published line rather than typed, so a module that
## moves takes its bench with it (CH69: a station typed beside a layout
## is a second spelling of that layout).
func _along(module: int, pre: float, post: float, forward: bool) -> Array:
	var line: Array = _line_of(module)
	var a: Vector3 = line[0] if forward else line[1]
	var b: Vector3 = line[1] if forward else line[0]
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	return [Vector3(a.x, 0.0, a.z) - dir * pre, Vector3(b.x, 0.0, b.z) + dir * post]

# =====================================================================
# PHASE E -- THE ENTRY SPEED IS THE APPROACH SPEED
#
# Mathieu's sentence, as an equality: "la vitesse d'entree dans le grind
# vient de la vitesse au sol au moment du contact".
#
# ⚠️ AND IT IS MEASURED AT FOUR APPROACHES AND NOT ONE. A single run
# proves a number was copied; four prove it TRACKS. CH62: the spread is
# gated BEFORE the ordering, because a constant is monotone too -- and
# the floor the spread is gated against is this bench's own, taken by
# repeating one of the four with nothing changed.

func _phase_entry() -> void:
	print("-- PHASE E: the entry speed IS the approach speed --")
	var ends: Array = _along(_ledges[0], 4.0, 0.6, true)
	# ⚠️ THE FOURTH IS THE THIRD, REPEATED. It is not a spare data point:
	# it is this bench's own floor, and without it "the entry moves with
	# the approach" is a claim with nothing to measure itself against
	# (CH40).
	var caps: Array = [INF, 6.0, 4.0, 4.0]
	var entries: Array = []
	for k in caps.size():
		var cap: float = caps[k]
		var label: String = "[%d] ledge %d, cap %s" % [k, _ledges[0], ("none" if is_inf(cap) else "%.1f" % cap)]
		var t: Dictionary = await _roll(label, ends[0], ends[1], 300, cap)
		_check(bool(t["mounted"]), "E[%d] INSTRUMENT: he is aboard" % k)
		_check(float(t["path"]) > 3.0, "E[%d] INSTRUMENT: the board rolled (%.2f u)" % [k, float(t["path"])])
		_check(bool(t["caught"]), "E[%d] it was CAUGHT, with no gesture of any kind" % k)
		if not bool(t["caught"]):
			continue
		var approach: float = float(t["approach"])
		var entry: float = float(t["entry"])
		entries.append(entry)
		print("        approach %.6f  entry %.6f  (the tick before: %.6f)  dy at the catch %+.3f"
			% [approach, entry, float(t["prev_approach"]), float(t["catch_dy"])])
		_check(absf(entry - approach) < 1e-6,
			"E[%d] entry == the ground speed on the tick it was taken (%.6f vs %.6f)" % [k, entry, approach])
		# ⚠️ AND NO JUMP EITHER SIDE OF IT. The equality above reads two
		# numbers from the same tick; this one reads the tick BEFORE, so
		# a catch that had quietly rewritten the velocity would show up
		# as a step no ground tick could produce.
		var step_cap: float = (_board.push_accel() + _board.roll_stop()) / FPS + 1e-4
		_check(absf(entry - float(t["prev_approach"])) <= step_cap,
			"E[%d] and it is one ground tick away from the tick before (%.6f <= %.6f)"
				% [k, absf(entry - float(t["prev_approach"])), step_cap])
		# The vector the first grind tick writes: the same magnitude,
		# flat. "Pas de vecteur de vitesse aberrant au moment de
		# l'accrochage", as two numbers.
		# ⚠️ ONE TICK OF THE RAIL'S OWN LAW AND NOTHING ELSE. The catch
		# runs at the end of a tick, so the FIRST tick the grind writes
		# is the second frame -- it carries the entry speed less exactly
		# one tick of GRIND_DECEL. Comparing it to the entry itself
		# would be off by 0.0303 u/s and would have to be given a
		# tolerance that hid a real jump.
		var want_after: float = entry - SkateBoardBody.GRIND_DECEL / FPS
		_check(absf(float(t["catch_speed_after"]) - want_after) < 1e-4,
			"E[%d] the first grind tick carries that speed less one tick of the rail (%.6f vs %.6f)"
				% [k, float(t["catch_speed_after"]), want_after])
		_check(absf(float(t["catch_vy"])) < 1e-6,
			"E[%d] and no vertical component at all (vy %.8f)" % [k, float(t["catch_vy"])])
		_check(int(t["under_surface"]) == 0,
			"E[%d] D1: never below HubSurface (%d violations)" % [k, int(t["under_surface"])])
		# ⚠️ AND IT WAS TAKEN BEFORE IT COULD HIT THE THING IT IS ABOUT
		# TO GRIND. The ledge's end face is a wall 0.30 u high against a
		# capsule that tops out at 0.26; without GRIND_CATCH_LEAD the
		# catch fires only once the centre is on the line, by which time
		# the nose is 0.46 u past the face. Measured with the lead at
		# zero: 8.83 u/s at z 38.39 and 2.03 u/s one tick later.
		print("        nose was %+.3f u from the end it came in by (negative = still clear of it)"
			% float(t["catch_nose"]))
		_check(float(t["catch_nose"]) < 0.0,
			"E[%d] and its NOSE was still clear of the ledge when it was taken (%+.3f u)"
				% [k, float(t["catch_nose"])])
	if entries.size() == caps.size():
		var floor_noise: float = absf(float(entries[2]) - float(entries[3]))
		var spread: float = float(entries[0]) - float(entries[2])
		print("     entries %s ; bench floor (the repeat) %.6f ; spread %.4f"
			% [str(entries), floor_noise, spread])
		_check(spread > floor_noise * 10.0 and spread > 1.0,
			"E the entry MOVES with the approach -- %.4f u/s of spread over a %.6f floor" % [spread, floor_noise])
		_check(float(entries[0]) > float(entries[1]) and float(entries[1]) > float(entries[2]),
			"E and it is ordered: %.3f > %.3f > %.3f"
				% [float(entries[0]), float(entries[1]), float(entries[2])])
	print("")

# =====================================================================
# PHASE D -- THE RAIL'S OWN FRICTION
#
# Two questions and they are not the same one: is the slide the law this
# file publishes, and is that law gentler than the ground's? The second
# is what "une deceleration propre au rail" MEANS, and PHASE A checked
# it on the constants -- here it is checked on two measured runs.

func _phase_decel() -> void:
	print("-- PHASE D: the slide follows the published law, and the ground does not --")
	var ends: Array = _along(_ledges[0], 4.0, 0.6, true)
	var t: Dictionary = await _roll("[D] ledge %d, full throttle" % _ledges[0], ends[0], ends[1], 300)
	_check(bool(t["caught"]), "D INSTRUMENT: it was caught")
	var samples: Array = t["samples"]
	_check(samples.size() > 20, "D INSTRUMENT: %d ticks of slide to fit" % samples.size())
	if not bool(t["caught"]) or samples.size() < 20:
		print("")
		return
	var t0: float = float((samples[0] as Array)[0])
	var v0: float = float((samples[0] as Array)[1])
	var worst: float = 0.0
	for s in samples:
		var dt: float = (float((s as Array)[0]) - t0) / FPS
		var want: float = maxf(v0 - SkateBoardBody.GRIND_DECEL * dt, 0.0)
		worst = maxf(worst, absf(float((s as Array)[1]) - want))
	var run: float = float(t["run"])
	var last_v: float = float((samples[samples.size() - 1] as Array)[1])
	var closed: float = sqrt(maxf(v0 * v0 - 2.0 * SkateBoardBody.GRIND_DECEL * run, 0.0))
	print("     entry %.4f  run %.4f u  last slide tick %.4f  exit (one tick later) %.4f  closed form sqrt(v0^2 - 2 a x) = %.4f"
		% [v0, run, last_v, float(t["exit_speed"]), closed])
	_check(worst < 0.002,
		"D every tick of the slide is v0 - GRIND_DECEL t (worst residual %.6f u/s)" % worst)
	# ⚠️ THE LAST SLIDE TICK AND NOT THE SPEED AFTER THE EXIT, and the
	# difference is exactly one tick of the law (0.0303 u/s). `run` is
	# the distance at the last GRINDING tick; `exit_speed` is read one
	# frame later, with the board back under its own physics. Comparing
	# the two is comparing a distance and a speed taken a frame apart,
	# and the honest fix is to read the same frame -- not to widen the
	# tolerance until the mismatch fits inside it.
	#
	# What remains is the integration error of the Euler step this file
	# takes, which is a * dt * sqrt(n) and comes to 0.009 over a slide
	# this long. One tick of the law is the bound published for it.
	_check(absf(last_v - closed) < SkateBoardBody.GRIND_DECEL / FPS,
		"D and the speed it reaches is what that law predicts over the distance it ran (%.4f vs %.4f, inside one tick)"
			% [last_v, closed])
	# ---- and the ground, on the same board, at a comparable speed ----
	# ⚠️ A MEASUREMENT AND NOT AN ARGUMENT. PHASE A compares the two
	# constants; this rolls the board on open lawn, lifts the finger and
	# watches what the GROUND takes over the same number of ticks. The
	# two are then the same kind of number.
	var open_from := Vector3(12.0, 0.0, 56.0)
	var open_to := Vector3(12.0, 0.0, 44.0)
	var g: Dictionary = await _roll("[D] open lawn, then a lifted finger", open_from, open_to, 300)
	_check(not bool(g["caught"]), "D INSTRUMENT: the open-lawn leg touched no line at all")
	# The board has coasted to rest by the end; what matters is the rate
	# it shed at the speed the slide started from.
	var lawn_rate: float = _board.drag_k() * v0 * v0 + _board.roll_stop()
	print("     at %.3f u/s the lawn takes %.4f u/s2 and the rail %.4f u/s2 (ratio %.2f)"
		% [v0, lawn_rate, SkateBoardBody.GRIND_DECEL, lawn_rate / SkateBoardBody.GRIND_DECEL])
	_check(SkateBoardBody.GRIND_DECEL < lawn_rate,
		"D the rail is slipperier than the ground at the speed the slide starts from")
	print("")

# =====================================================================
# PHASE M -- THE MOUNT, WHICH IS THE ONE THING HERE THAT IS NOT PHYSICS
#
# The rail, because it is the TALLEST line and therefore the worst
# mount: 0.680 u of lift from a board rolling on the flat.

func _phase_mount() -> void:
	print("-- PHASE M: the mount is bounded by the board's own pop --")
	var ends: Array = _along(_rail, 3.0, 0.0, true)
	var t: Dictionary = await _roll("[M] the rail, along its own line", ends[0], ends[1], 300)
	_check(bool(t["caught"]), "M it was caught on the rail")
	if not bool(t["caught"]):
		print("")
		return
	var line: Array = _line_of(_rail)
	print("     caught %.3f u BELOW the line (line y %.3f), mount %d ticks, worst climb %.4f u/s"
		% [-float(t["catch_dy"]), (line[0] as Vector3).y, int(t["mount_ticks"]), float(t["mount_rate"])])
	_check(float(t["catch_dy"]) < -0.5,
		"M INSTRUMENT: it really was on the ground when it was taken (%.3f u below the line)"
			% -float(t["catch_dy"]))
	_check(float(t["mount_rate"]) <= SkateBoardBody.POP_SPEED + 1e-4,
		"M the lift never exceeded POP_SPEED (%.4f <= %.2f u/s)"
			% [float(t["mount_rate"]), SkateBoardBody.POP_SPEED])
	# ⚠️ THE BOUND IS THE SLOWER OF THE TWO GOVERNORS, because the mount
	# has two (see GRIND_CATCH_LEAD): the board's own ollie time, and
	# the time it takes to cover what is left of the lead. A gate
	# written on the first alone would be red on a slow entry and would
	# be re-tuned instead of re-read.
	var by_time: float = SkateBoardBody.GRIND_MOUNT_S
	var by_lead: float = SkateBoardBody.GRIND_CATCH_LEAD / maxf(float(t["entry"]), 0.01)
	var want_ticks: int = int(ceil(maxf(by_time, by_lead) * FPS))
	_check(int(t["mount_ticks"]) <= want_ticks + 2,
		"M and it took no longer than its two governors allow (%d ticks against %d: %.4f s by time, %.4f s by lead)"
			% [int(t["mount_ticks"]), want_ticks, by_time, by_lead])
	_check(int(t["under_surface"]) == 0,
		"M D1: never below HubSurface, on any tick (%d)" % int(t["under_surface"]))
	_check(int(t["rider_off"]) == 0,
		"M carrier-then-carried: the rider is on the deck every tick of the grind (%d off)"
			% int(t["rider_off"]))
	_check(float(t["max_y"]) < (line[0] as Vector3).y + 0.05,
		"M and nothing lifted it ABOVE the line (max y %.3f)" % float(t["max_y"]))
	print("")

# =====================================================================
# PHASE X -- THE FOUR WAYS OFF, AND THERE ARE ONLY FOUR
#
# ⚠️ THIS IS THE PHASE THE BRIEF ASKS FOR BY NAME: "un accrochage
# automatique sans sortie prevue cree un nouvel etat bloquant". This
# repo has shipped that defect once already -- CH58's board inherited a
# `return` that swallowed every tap and the only way out was reloading
# the page -- so the exits are enumerated and each one is ridden.
#
# The grind is NOT the patron ECHELLE and PHASE X is how that is shown:
# the thumb is never swallowed and never reinterpreted. It steers, and
# steering hard enough away IS the way off (1). The other three are the
# rail running out (2), the slide running out (3) and the rider getting
# off (4). There is no fifth, and none of them can fail to fire: the
# friction alone guarantees (3) in v0 / GRIND_DECEL seconds.

func _phase_exits() -> void:
	print("-- PHASE X: the four exits --")
	# (1) THE END OF THE LINE.
	var ends: Array = _along(_ledges[0], 4.0, 1.2, true)
	var t1: Dictionary = await _roll("[X1] ride it off the end", ends[0], ends[1], 300)
	_check(bool(t1["caught"]) and int(t1["exit_tick"]) > 0, "X1 caught, and it let go")
	_check(not _board.grinding(), "X1 and it is off the line at the end of the run")
	if int(t1["exit_tick"]) > 0:
		var line: Array = _line_of(_ledges[0])
		var b: Vector3 = line[1]
		var at: Vector3 = t1["exit_at"]
		print("        left at %s, %.3f u from the line's far end, at %.3f u/s, %d airborne ticks after"
			% [str(at.snappedf(0.01)), Vector2(at.x - b.x, at.z - b.z).length(),
				float(t1["exit_speed"]), int(t1["airborne_after"])])
		_check(Vector2(at.x - b.x, at.z - b.z).length() < 0.25,
			"X1 it left from the END of the line, not from the middle of it")
		_check(float(t1["exit_speed"]) > SkateBoardBody.GRIND_MIN_SPEED,
			"X1 with the speed it had (%.3f u/s) -- the end of a rail is a launch, not a stop"
				% float(t1["exit_speed"]))
		_check(int(t1["airborne_after"]) > 0,
			"X1 and it was briefly a projectile afterwards (%d ticks) -- gravity has it back"
				% int(t1["airborne_after"]))
	# (2) THE SLIDE RUNS OUT. The rail is the longest line, and an entry
	# barely over GRIND_MIN_SPEED cannot cross it.
	# ⚠️ A SHORT RUN-UP AND NOT A CAPPED THROTTLE. The bench's speed cap
	# feathers the finger, and feathered from a standstill the board
	# crawls at a fraction of the cap -- measured at 0.7 u/s for a cap of
	# 3.0, which is not "a slow entry", it is "no entry". Half a unit of
	# run-up gives an honest one: the board is caught the moment it has
	# the speed to be, and no more.
	var slow_ends: Array = _along(_rail, 0.5, 0.0, true)
	var t2: Dictionary = await _roll("[X2] onto the rail with half a unit of run-up",
		slow_ends[0], slow_ends[1], 300)
	_check(bool(t2["caught"]), "X2 INSTRUMENT: a crawl is still caught (it is over GRIND_MIN_SPEED)")
	if bool(t2["caught"]):
		print("        entry %.3f, ran %.3f u, let go at %.3f u/s after %d ticks"
			% [float(t2["entry"]), float(t2["run"]), float(t2["exit_speed"]), int(t2["grind_ticks"])])
		_check(int(t2["exit_tick"]) > 0 and float(t2["run"]) < 2.5,
			"X2 the slide ran out and it let go inside %.2f u" % float(t2["run"]))
		_check(float(t2["exit_speed"]) < SkateBoardBody.GRIND_MIN_SPEED + 1e-3,
			"X2 below the speed a grind is (%.4f)" % float(t2["exit_speed"]))
	_check(not _board.grinding(), "X2 and it is off the line")
	# (3) THE BAIL. A thumb held 180 deg from where the line is taking
	# him, twenty ticks in.
	var line3: Array = _line_of(_ledges[0])
	var away := Vector3((line3[0] as Vector3).x - (line3[1] as Vector3).x, 0.0,
		(line3[0] as Vector3).z - (line3[1] as Vector3).z).normalized()
	var t3: Dictionary = await _roll("[X3] thumb hard about, 20 ticks in", ends[0], ends[1],
		300, INF, 20, away)
	_check(bool(t3["caught"]), "X3 INSTRUMENT: it was caught before the bail")
	if bool(t3["caught"]):
		print("        bailed after %d grind ticks (asked at 20), run %.3f u"
			% [int(t3["grind_ticks"]), float(t3["run"])])
		_check(int(t3["grind_ticks"]) >= 20 and int(t3["grind_ticks"]) <= 23,
			"X3 it let go within three ticks of being asked (%d)" % int(t3["grind_ticks"]))
		_check(int(t3["rides"]) == 1,
			"X3 and the cooldown stopped it being caught again on the spot (%d catches in the run)"
				% int(t3["rides"]))
	_check(not _board.grinding(), "X3 and it is off the line")
	# (4) THE RIDER GETS OFF. Not a run: catch it, then do what
	# HubTransport does on a dismount.
	var t4: Dictionary = await _roll("[X4] caught, then the rider steps off", ends[0], ends[1], 120)
	_check(bool(t4["caught"]), "X4 INSTRUMENT: it was caught")
	_board.stop()
	_check(not _board.grinding(),
		"X4 stop() takes the board off the line -- a dismount cannot leave it sliding")
	_check(_board.velocity.length() < 1e-6, "X4 and it is not moving")
	print("")

# =====================================================================
# PHASE J -- CROSSING IS STILL CROSSING
#
# CH60's PHASE J2 asserts that a board rolling ACROSS the rail passes
# UNDER its beam. That contract is older than this lot and this lot must
# not have broken it -- and the thing that protects it is not luck, it
# is GRIND_ALIGN_COS. So it is re-measured here, on this probe's own
# bench, next to the ledge case that is its opposite: a ledge crossed at
# 90 deg is a WALL and stops the board.

func _phase_crossing() -> void:
	print("-- PHASE J: a board CROSSING a line is not grinding it --")
	var line: Array = _line_of(_rail)
	var a: Vector3 = line[0]
	var b: Vector3 = line[1]
	var mid := Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5)
	var across := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized().cross(Vector3.UP).normalized()
	var t: Dictionary = await _roll("[J1] across the rail, between the legs",
		mid + across * 5.0, mid - across * 5.0, 300)
	print("        max y %.4f, caught %s" % [float(t["max_y"]), str(t["caught"])])
	_check(float(t["path"]) > 3.0, "J1 INSTRUMENT: it set off (%.2f u)" % float(t["path"]))
	_check(not bool(t["caught"]),
		"J1 it was NOT taken onto the rail -- 90 deg is outside GRIND_ALIGN_COS")
	_check(float(t["max_y"]) < 0.05,
		"J1 and it stayed on the ground: CH60's contract, unchanged (max y %.4f)" % float(t["max_y"]))
	# The ledge, crossed: a wall, and it must still be one.
	var lline: Array = _line_of(_ledges[0])
	var lmid := Vector3((lline[0] as Vector3).x, 0.0,
		((lline[0] as Vector3).z + (lline[1] as Vector3).z) * 0.5)
	var t2: Dictionary = await _roll("[J2] across the ledge, head on",
		lmid + Vector3(5.0, 0.0, 0.0), lmid - Vector3(5.0, 0.0, 0.0), 300, 3.0)
	var half_w: float = float(HubSkatepark.MODULES[_ledges[0]]["size"].x) * 0.5
	var end: Vector3 = t2["end"]
	var stood_off: float = absf(end.x - lmid.x)
	print("        ended at x %.3f (the ledge's east face is at %.3f, its line at %.3f), max y %.4f, caught %s"
		% [end.x, lmid.x + half_w, lmid.x, float(t2["max_y"]), str(t2["caught"])])
	_check(not bool(t2["caught"]), "J2 crossing a ledge is not grinding it either")
	_check(end.x > lmid.x + half_w - 0.30,
		"J2 and the ledge STOPPED it: a block of concrete is a wall from the side")
	# ⚠️ AND WHAT CARRIES THAT "not caught" IS **NOT** THE ALIGNMENT
	# TEST, WHICH IS WHY THE LINE BELOW EXISTS. CH82's red pass removed
	# GRIND_ALIGN_COS and predicted five reds; it produced three, and
	# the two J2 assertions were among the ones that stayed green. The
	# reason is measured, not argued: the wall stops the board 0.736 u
	# from the line, which is outside GRIND_CATCH_R (0.460), so this
	# case never reaches the alignment test at all. J1 is the phase's
	# alignment gate -- it is the one that reddens -- and J2 is the WALL
	# gate. Two claims, and this line stops the second from being read
	# as the first.
	_check(stood_off > SkateBoardBody.GRIND_CATCH_R,
		"J2 INSTRUMENT: and the wall held it OUTSIDE the catch radius (%.3f > %.3f) -- this case is the wall's, not the alignment's"
			% [stood_off, SkateBoardBody.GRIND_CATCH_R])
	print("")

# =====================================================================
# PHASE R -- RED BEFORE GREEN, AT RUNTIME
#
# ⚠️ FOUR NEUTRALISATIONS, EACH WITH ITS POSITIVE TWIN IN THE SAME RUN.
# CH65 is the rule being obeyed: a threshold measured only from the side
# that passes is a threshold nobody has shown to separate anything, and
# this repo has watched a red pass come back ALL GREEN because the gate
# was wider than the effect. Every pair below is the same ride with one
# number moved across the line.
#
# It is done by handing the board a DIFFERENT LIST, never by editing a
# file: green / red / green on one tree, with nothing to `cmp`
# afterwards (SkatePhysicsProbe PHASE N's form).

func _phase_red() -> void:
	print("-- PHASE R: red before green, by handing the board other lines --")
	# R1 -- NO LINES AT ALL, on the ride PHASE E caught. The blind check
	# every assertion in this file leans on: with the mechanic off, the
	# same thumb on the same board over the same ground catches nothing.
	var park_ends: Array = _along(_ledges[0], 4.0, 0.6, true)
	_board.set_grind_edges([])
	var r1: Dictionary = await _roll("[R1] PHASE E's ride with NO lines", park_ends[0], park_ends[1], 300)
	_check(not bool(r1["caught"]) and int(r1["rides"]) == 0,
		"R1 with no lines it is never caught -- the ride is the board's own law and nothing else")
	_check(float(r1["path"]) > 3.0, "R1 INSTRUMENT: and it still rolled (%.2f u)" % float(r1["path"]))
	_board.set_grind_edges(_park.grind_edges())
	# =================================================================
	# ⚠️ AND THE THREE PAIRS BELOW ARE RUN ON OPEN LAWN, NOT ON A MODULE.
	# A first version turned and raised the LINE while leaving the
	# CONCRETE where it was, so the board hit a ledge nobody had moved
	# and the verdict was about a collision instead of about a
	# threshold. The corridor east of the park (NEUTRAL_PARK's own
	# station) has no solid in it at all, so a synthetic line there is
	# the only thing the board can meet.
	var mid := Vector3(12.0, 0.0, 51.0)
	var from := Vector3(12.0, 0.0, 44.0)
	var to := Vector3(12.0, 0.0, 57.0)
	_check(HubRegion.contains(from) and HubRegion.contains(to),
		"R INSTRUMENT: the synthetic corridor is inside the region")
	var half: float = 3.0
	# R2 -- THE HEIGHT, BOTH SIDES.
	for pair in [[SkateBoardBody.GRIND_CATCH_DROP + 0.20, false],
			[SkateBoardBody.GRIND_CATCH_DROP - 0.10, true]]:
		var h: float = pair[0]
		var want: bool = pair[1]
		_board.set_grind_edges([{"a": Vector3(mid.x, h, mid.z - half),
			"b": Vector3(mid.x, h, mid.z + half)}])
		var r: Dictionary = await _roll("[R2] one line at y %.3f (reach %.4f)"
			% [h, SkateBoardBody.GRIND_CATCH_DROP], from, to, 280)
		_check(bool(r["caught"]) == want,
			"R2 a line %.3f u up is %s (caught = %s, wanted %s)"
				% [h, ("inside the reach" if want else "OUT of the reach"), str(r["caught"]), str(want)])
		if want:
			_check(float(r["mount_rate"]) <= SkateBoardBody.POP_SPEED + 1e-4,
				"R2 and the worst lift this file can produce is still under POP_SPEED (%.4f)"
					% float(r["mount_rate"]))
	_board.set_grind_edges(_park.grind_edges())
	# R3 -- THE ALIGNMENT, BOTH SIDES, about the corridor's own middle.
	for pair2 in [[17.0, true], [60.0, false]]:
		var deg: float = pair2[0]
		var want2: bool = pair2[1]
		var d := Vector3(sin(deg_to_rad(deg)), 0.0, cos(deg_to_rad(deg)))
		_board.set_grind_edges([{"a": mid - d * half + Vector3(0.0, 0.40, 0.0),
			"b": mid + d * half + Vector3(0.0, 0.40, 0.0)}])
		var r2: Dictionary = await _roll("[R3] the same line turned %.0f deg" % deg, from, to, 280)
		_check(bool(r2["caught"]) == want2,
			"R3 a line %.0f deg off the run is %s (caught = %s, wanted %s)"
				% [deg, ("inside GRIND_ALIGN_COS" if want2 else "OUTSIDE it"), str(r2["caught"]), str(want2)])
	_board.set_grind_edges(_park.grind_edges())
	# R4 -- THE SPEED, BOTH SIDES, on the same synthetic line.
	_board.set_grind_edges([{"a": Vector3(mid.x, 0.40, mid.z - half),
		"b": Vector3(mid.x, 0.40, mid.z + half)}])
	for pair3 in [[1.0, false], [INF, true]]:
		var cap: float = pair3[0]
		var want3: bool = pair3[1]
		var r3: Dictionary = await _roll("[R4] the same line, throttle capped at %s"
			% ("none" if is_inf(cap) else "%.1f" % cap), from, to, 300, cap)
		print("        fastest it ever went: %.3f u/s (GRIND_MIN_SPEED %.3f)"
			% [float(r3["max_speed"]), SkateBoardBody.GRIND_MIN_SPEED])
		_check(bool(r3["caught"]) == want3,
			"R4 a board whose top speed was %.3f u/s is %s"
				% [float(r3["max_speed"]), ("caught" if want3 else "left alone")])
		if not want3:
			_check(float(r3["max_speed"]) < SkateBoardBody.GRIND_MIN_SPEED,
				"R4 INSTRUMENT: and it really never reached the floor (%.3f < %.3f)"
					% [float(r3["max_speed"]), SkateBoardBody.GRIND_MIN_SPEED])
			_check(float(r3["path"]) > 0.3,
				"R4 INSTRUMENT: but it did move (%.2f u) -- a board that never set off would pass this for free"
					% float(r3["path"]))
	_board.set_grind_edges(_park.grind_edges())
	_check(_board.grind_edge_count() == _park.grind_edges().size(),
		"R the board is back on the park's own lines (%d)" % _board.grind_edge_count())
	print("")
