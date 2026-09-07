extends Node
class_name ReverseProbe
## CH42 -- THE CLIFF LOCK-UP, AND THE GEAR THAT ANSWERS IT.
##
## =====================================================================
## WHAT THE LOT WAS ASKED, AND WHAT THE FIRST PHASE FOUND
##
## Mathieu is pinned against the west ridge's edge and full lock does not
## free him. The brief's four hypotheses were: a wall that does not repel
## on that stretch, a corner no rotation can leave, the sled's slope and
## the wall cancelling, or a combination. PHASE WALL and PHASE PIN answer
## them with numbers, and the answer is NONE OF THE FOUR AS WRITTEN:
##
##   * the wall is CORRECT. Every sampled edge point is inside the region
##     and every point past it is outside, on all three ridge edges, and
##     the axis-separated slide accepts exactly the half-moves it should;
##   * the corners are not dead either -- reverse leaves every one of them;
##   * the slope CANNOT be involved at a ridge edge: HubSurface refuses a
##     domain whose perimeter is not flat (its C0 raccord), so the wall and
##     a gradient never coincide there. Measured grade at the pin: 0.0000;
##   * what pins the vehicle is the STEERING GAIN. VehicleDrive turns the
##     heading at `|v_fwd| / steer_full_speed` of full rate -- v_fwd, the
##     FORWARD component, not the speed. Against a wall the forward
##     component is what the wall eats, so a vehicle sliding along the edge
##     at 1 u/s has 0.05 u/s of it forward and steers at 2 % of full lock.
##     In a corner both halves are refused, the bounce zeroes the velocity,
##     and the yaw rate is EXACTLY zero.
##
## So it is a combination -- of a correct wall and a missing input. The
## remedy is the gear, and no wall changes: PHASE ESCAPE replays the pins
## with it.
##
## =====================================================================
## WHAT IS GATED HERE, AND WHAT IS GATED ELSEWHERE
##
## The four vehicles' FORWARD behaviour is not this file's business: it is
## proved byte-identical by KartTraceProbe and YachtTraceProbe replayed on
## both trees, and by SailBoatProbe and SledProbe run unchanged. What this
## file gates is the gear -- that it reaches a negative speed, that the
## vehicle REALLY MOVES backwards (a speed with no displacement is the
## false green this repo has found fourteen times), that the steering
## follows the direction of travel, and that the sled's ramp beats its own
## hill.

const BUDGET_S: float = 900.0
const FIXED_DELTA: float = 1.0 / 60.0
## Long enough for the gear to reach its speed and carry the vehicle clear,
## short enough that a freed vehicle has not driven into the next wall.
const GEAR_FRAMES: int = 180
## The pinning runs: 10 s, which is far longer than a player would hold a
## full lock before deciding the game is broken.
const PIN_FRAMES: int = 600
## ⚠️ WHAT COUNTS AS GETTING AWAY, AND WHY IT IS NOT THE END POSITION.
##
## The first version of this phase measured the distance from the start
## AFTER PIN_FRAMES, and it produced FOUR FALSE PINS. Traced: the sample
## that "covered 0.570 u in 10 s" spends 4.7 s on the wall, breaks free,
## drives a 36.7 u loop at 352.7 deg of full lock, and ARRIVES BACK where
## it started. Held lock draws a circle; a circle ends where it began.
##
## So a run is scored on the FIRST FRAME at which it is ESCAPE_RADIUS from
## where it started -- the farthest it ever got and how long that took,
## never where it happened to be when the clock stopped.
const ESCAPE_RADIUS: float = 4.0
## A pin is a run that needed longer than this to reach that radius. 2 s of
## full lock with nothing happening is already what a player calls stuck --
## the same lock in the OPEN takes 59 frames (0.98 s), which PHASE PIN
## measures as its control rather than assuming.
const PIN_FRAMES_CEILING: int = 120
## What the gear has to buy. MEASURED, not chosen: with it every pin on the
## ridge clears ESCAPE_RADIUS in 121-143 frames, so 180 is that worst case
## with a fifth of itself in hand. A tuning pass that made the gear slower
## than this fails here rather than on Mathieu's thumb.
const GEAR_FRAMES_CEILING: int = 180

var _fails: int = 0
## The worst pin PHASE PIN found, handed to PHASE ESCAPE so the two phases
## are about the SAME point and not about two points that happen to share
## a description.
var _pin_worst_at: Vector3 = Vector3.ZERO
var _pin_worst_yaw: float = 0.0
var _pin_worst_steer: float = 1.0
var _hub: Node = null
var _transport: HubTransport = null
var _karting: Node = null

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract.
	ProbeWatchdog.arm(self, "REVERSE PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://reverse_probe.json"
	WorldSave.reset()
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_transport = _hub.get_node("WorldViewport/SubViewport/World/Transport") as HubTransport
	_karting = _hub.get_node("WorldViewport/SubViewport/World/Karting")

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	_run()

func _run() -> void:
	print("=== REVERSE PROBE -- CH42 ===")
	print("  reverse speeds: kart %.2f  yacht %.2f  sailboat %.2f  sled %.2f"
		% [KartBody.REVERSE_SPEED, SandYacht.REVERSE_SPEED,
			SailBoat.REVERSE_SPEED, SledBody.REVERSE_SPEED])
	print("  reverse ramps:  kart %.2f  yacht %.2f  sailboat %.2f  sled %.2f  (u/s2)"
		% [KartBody.REVERSE_ACCEL, SandYacht.REVERSE_ACCEL,
			SailBoat.REVERSE_ACCEL, SledBody.REVERSE_ACCEL])
	_phase_blind()
	_phase_wall()
	_phase_pin()
	_phase_gear()
	_phase_steer()
	_phase_slope()
	_phase_escape()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

## =====================================================================
## THE INSTRUMENTS
##
## One driver per vehicle, so a phase names a vehicle and not a branch.
## `wind` is pinned at 1.0 for the yacht and the sailboat: the weather's
## factor is not what any assertion here is about, and letting it vary
## would put the weather RNG inside every number below.

func _drive(who: String, delta: float, input: KartInput) -> void:
	match who:
		"kart":
			var kart: KartBody = _karting.player_kart()
			var track: KartTrack = _karting.track
			var progress: Dictionary = track.progress_at(kart.global_position, -1)
			var on_track: bool = absf(float(progress["lateral"])) <= KartTrack.HALF_WIDTH + KartTrack.ON_TRACK_MARGIN
			kart.drive(delta, input, on_track, track.fence())
		"yacht":
			_transport.yacht().drive(delta, input, 1.0)
		"sailboat":
			_transport.sailboat().drive(delta, input, 1.0, true)
		"sled":
			_transport.sled().drive(delta, input)

func _place(who: String, at: Vector3, yaw: float) -> void:
	match who:
		"kart":
			_karting.player_kart().place(at, yaw)
		"yacht":
			_transport.yacht().place(at, yaw)
		"sailboat":
			_transport.sailboat().place(at, yaw)
		"sled":
			_transport.sled().place(at, yaw)

func _flat(who: String) -> Vector3:
	match who:
		"kart":
			var k: KartBody = _karting.player_kart()
			return Vector3(k.global_position.x, 0.0, k.global_position.z)
		"yacht":
			return _transport.yacht().flat_position()
		"sailboat":
			return _transport.sailboat().flat_position()
	return _transport.sled().flat_position()

func _yaw_of(who: String) -> float:
	match who:
		"kart":
			return _karting.player_kart().rotation.y
		"yacht":
			return _transport.yacht().rotation.y
		"sailboat":
			return _transport.sailboat().rotation.y
	return _transport.sled().rotation.y

func _speed_of(who: String) -> float:
	match who:
		"kart":
			return _karting.player_kart().speed()
		"yacht":
			return _transport.yacht().speed()
		"sailboat":
			return _transport.sailboat().speed()
	return _transport.sled().speed()

## One run. Returns the signed advance along the heading it set out on,
## the lowest forward speed seen, and the net yaw.
func _leg(who: String, at: Vector3, yaw: float, frames: int, steer: float,
		reverse: float, throttle: float = 1.0) -> Dictionary:
	_place(who, at, yaw)
	var input := KartInput.new()
	input.throttle = throttle
	input.steer = steer
	input.reverse = reverse
	var lowest: float = 0.0
	var far: float = 0.0
	var escape_f: int = -1
	var path: float = 0.0
	var yaw_total: float = 0.0
	var prev: Vector3 = at
	var prev_yaw: float = yaw
	var fwd_sum: float = 0.0
	for f in frames:
		_drive(who, FIXED_DELTA, input)
		var here: Vector3 = _flat(who)
		path += here.distance_to(prev)
		yaw_total += absf(wrapf(_yaw_of(who) - prev_yaw, -PI, PI))
		prev = here
		prev_yaw = _yaw_of(who)
		lowest = minf(lowest, _speed_of(who))
		var d: float = here.distance_to(at)
		far = maxf(far, d)
		if escape_f < 0 and d >= ESCAPE_RADIUS:
			escape_f = f
		if escape_f < 0:
			fwd_sum += absf(_speed_of(who))
	var moved: Vector3 = _flat(who) - at
	return {
		"advance": moved.dot(Vector3(sin(yaw), 0.0, cos(yaw))),
		"moved": moved.length(),
		"lowest": lowest,
		"yaw_net": wrapf(_yaw_of(who) - yaw, -PI, PI),
		"end": _flat(who),
		# CH42's real metrics -- see ESCAPE_RADIUS.
		"far": far,
		"escape_f": escape_f if escape_f >= 0 else frames,
		"escaped": escape_f >= 0,
		"path": path,
		"yaw_total": yaw_total,
		# Mean |v_fwd| over the frames BEFORE it got away: the window in
		# which the vehicle is actually on its wall, and the only window in
		# which a steering-gain number means anything.
		"fwd_mean": fwd_sum / maxf(float(escape_f if escape_f >= 0 else frames), 1.0),
	}

## =====================================================================
## PHASE BLIND -- prove every instrument can answer NO before any of them
## is believed on a YES.

func _phase_blind() -> void:
	print("-- PHASE BLIND: the instruments can say no --")
	# 1. A default KartInput reverses nothing: the field exists and is off.
	var fresh := KartInput.new()
	_check(fresh.reverse == 0.0, "a fresh KartInput holds reverse %.1f" % fresh.reverse)
	fresh.reverse = 0.7
	fresh.reset()
	_check(fresh.reverse == 0.0, "and reset() clears it (%.1f)" % fresh.reverse)
	# 2. THE LEG INSTRUMENT CAN SEE MOVEMENT. Open sand, no wall in reach,
	#    no gear: the yacht must cover ground FORWARD. Without this every
	#    "it did not move" below would pass on a broken instrument.
	var open := Vector3(0.0, 0.0, 0.0)
	var fwd_leg: Dictionary = _leg("yacht", open, 0.0, GEAR_FRAMES, 0.0, 0.0)
	_check(float(fwd_leg["advance"]) > 10.0,
		"in the open, with no gear, the yacht advances %+.3f u in %d frames"
		% [fwd_leg["advance"], GEAR_FRAMES])
	# 3. AND IT CAN SEE THE SIGN. The same leg with the gear held must come
	#    back NEGATIVE -- an assertion on |distance| would pass either way,
	#    which is the trap SledProbe's coasting pair fell into once.
	var back_leg: Dictionary = _leg("yacht", open, 0.0, GEAR_FRAMES, 0.0, 1.0)
	_check(float(back_leg["advance"]) < -1.0,
		"and with the gear held it advances %+.3f u -- the sign, not the distance"
		% back_leg["advance"])

## =====================================================================
## PHASE WALL -- is the bounding predicate wrong on this stretch?
##
## The brief's first hypothesis, and it is answered on the predicate
## itself rather than on a vehicle: for every sample the point INSIDE is
## drivable and the point 1 u past the edge is not. A wall that "does not
## repel" would show up here as a drivable point outside the ridge.

const EDGE_INSET: float = 0.30
const EDGE_STEP: float = 3.0

## The ridge edges that are REAL walls -- the ones the plateau does not
## continue past. The east edge (x = -35) is shared with the square and is
## not a wall at all, which is why it is not sampled.
func _edge_samples() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var x: float = HubRegion.MOUNTAIN_MIN.x + 1.0
	while x <= HubRegion.MOUNTAIN_MAX.x - 1.0:
		out.append({"at": Vector3(x, 0.0, HubRegion.MOUNTAIN_MAX.y - EDGE_INSET),
			"yaw": 0.0, "edge": "N"})
		out.append({"at": Vector3(x, 0.0, HubRegion.MOUNTAIN_MIN.y + EDGE_INSET),
			"yaw": PI, "edge": "S"})
		x += EDGE_STEP
	var z: float = HubRegion.MOUNTAIN_MIN.y + 1.0
	while z <= HubRegion.MOUNTAIN_MAX.y - 1.0:
		out.append({"at": Vector3(HubRegion.MOUNTAIN_MIN.x + EDGE_INSET, 0.0, z),
			"yaw": -PI / 2.0, "edge": "W"})
		z += EDGE_STEP
	return out

func _phase_wall() -> void:
	print("-- PHASE WALL: the bounding predicate on the ridge's three real edges --")
	var samples: Array[Dictionary] = _edge_samples()
	var inside_ok: int = 0
	var outside_ok: int = 0
	var worst_grade: float = 0.0
	for s in samples:
		var at: Vector3 = s["at"]
		var yaw: float = s["yaw"]
		var past: Vector3 = at + Vector3(sin(yaw), 0.0, cos(yaw)) * 1.0
		if SledBody.drivable(at):
			inside_ok += 1
		if not SledBody.drivable(past):
			outside_ok += 1
		worst_grade = maxf(worst_grade, HubSurface.gradient_at(at).length())
	_check(samples.size() > 20, "sampled %d edge points" % samples.size())
	_check(inside_ok == samples.size(),
		"every sampled point INSIDE the ridge is drivable (%d of %d)" % [inside_ok, samples.size()])
	_check(outside_ok == samples.size(),
		"and every point 1 u PAST it is refused (%d of %d) -- the wall is not the defect"
		% [outside_ok, samples.size()])
	# HYPOTHESIS 3 -- "the slope pushes the sled into the wall and the two
	# cancel" -- and it is closed by the surface's own contract rather than
	# by a preference: HubSurface REFUSES a domain whose perimeter is not
	# flat (its C0 raccord, PERIMETER_TOL), so a ridge edge is the foot of
	# the relief and not a flank of it. What is gated is the number that
	# would have to be large for the hypothesis to hold -- the slope FORCE
	# there, against the motor the sled answers it with.
	#
	# ⚠️ THE FIRST VERSION GATED THE GRADE AT 0.02 AND WENT RED AT 0.0765.
	# The tolerance the surface enforces is on the HEIGHT at the perimeter,
	# not on the derivative 0.30 u inside it, so that assertion was asking
	# the wrong question of a correct surface -- kept here because the
	# distinction is exactly the one CLAUDE.md's "la metrique peut etre la
	# mauvaise" section is about.
	var edge_force: float = SledBody.slope_force(Vector2(worst_grade, 0.0))
	var climb: float = SledBody.climb_authority()
	_check(edge_force < 0.25 * climb,
		"and the steepest edge sample tilts %.4f -- a slope force of %.4f u/s2 against %.4f of climb (%.0f %%), so slope and wall cannot cancel there"
		% [worst_grade, edge_force, climb, 100.0 * edge_force / climb])

## =====================================================================
## PHASE PIN -- reproduce the blockage, and name it.

func _phase_pin() -> void:
	print("-- PHASE PIN: full lock into the wall, no gear --")
	var pinned: int = 0
	var total: int = 0
	var worst_f: int = -1
	var worst_at := Vector3.ZERO
	var worst_yaw: float = 0.0
	var worst_steer: float = 1.0
	var never: int = 0
	for s in _edge_samples():
		for steer in [1.0, -1.0]:
			total += 1
			var r: Dictionary = _leg("sled", s["at"], s["yaw"], PIN_FRAMES, steer, 0.0)
			if int(r["escape_f"]) > PIN_FRAMES_CEILING:
				pinned += 1
			if not bool(r["escaped"]):
				never += 1
			if int(r["escape_f"]) > worst_f:
				worst_f = int(r["escape_f"])
				worst_at = s["at"]
				worst_yaw = float(s["yaw"])
				worst_steer = steer
	# THE CONTROL, and it is what makes the numbers above a measurement:
	# the same vehicle, the same lock, the same frames, in the OPEN. If a
	# free sled also took seconds to get 4 u away then the wall would not
	# be what the phase is looking at.
	var open_run: Dictionary = _leg("sled", Vector3(0.0, 0.0, -20.0), 0.0, PIN_FRAMES, 1.0, 0.0)
	print("     %d of %d sled runs needed more than %d frames (%.1f s) to get %.1f u away; %d never did; worst %d frames"
		% [pinned, total, PIN_FRAMES_CEILING, PIN_FRAMES_CEILING * FIXED_DELTA,
			ESCAPE_RADIUS, never, worst_f])
	print("     CONTROL, same lock in the open: %d frames (%.2f s), reached %.2f u"
		% [open_run["escape_f"], int(open_run["escape_f"]) * FIXED_DELTA, open_run["far"]])
	_check(bool(open_run["escaped"]) and int(open_run["escape_f"]) < 60,
		"blind: in the open the same full lock is %.1f u away in %d frames (%.2f s)"
		% [ESCAPE_RADIUS, open_run["escape_f"], int(open_run["escape_f"]) * FIXED_DELTA])
	_check(pinned > 0,
		"the blockage REPRODUCES: %d of %d full-lock runs are still within %.1f u of their wall after %.1f s"
		% [pinned, total, ESCAPE_RADIUS, PIN_FRAMES_CEILING * FIXED_DELTA])
	_check(worst_f > 4 * int(open_run["escape_f"]),
		"and the worst needs %d frames (%.2f s) against the control's %d -- x%.1f"
		% [worst_f, worst_f * FIXED_DELTA, open_run["escape_f"],
			float(worst_f) / maxf(float(open_run["escape_f"]), 1.0)])
	# ---- THE NAMED CAUSE, measured over the window the vehicle is ON the
	# wall -- the frames before it gets away -- and at the worst sample the
	# sweep itself found rather than at a point chosen by hand.
	#
	# ⚠️ TWO EARLIER VERSIONS OF THIS MEASUREMENT WERE WRONG, both in the
	# same direction: they averaged over the WHOLE run, which for a held
	# lock is mostly a free 6 u/s loop around the ridge, and reported a
	# steering gain of 0.59-0.67 -- a number that says the vehicle steers
	# perfectly well, taken over the seconds in which it is not stuck.
	var pin: Dictionary = _leg("sled", worst_at, worst_yaw, PIN_FRAMES, worst_steer, 0.0)
	var gain: float = clampf(float(pin["fwd_mean"]) / SledBody.STEER_FULL_SPEED, 0.0, 1.0)
	print("     worst pin %s heading %.3f steer %+.0f: %d frames on the wall, mean |v_fwd| %.4f u/s there -> steering gain %.4f of full lock"
		% [worst_at, worst_yaw, worst_steer, pin["escape_f"], pin["fwd_mean"], gain])
	_check(gain < 0.20,
		"THE CAUSE: on the wall the mean forward speed is %.4f u/s, so the yaw rate is %.4f of full lock -- VehicleDrive gains on |v_fwd|, and the wall is what eats v_fwd"
		% [pin["fwd_mean"], gain])
	# ⚠️ AND THE WORST ONE IS NOT MERELY SLOW. The first version of this
	# assertion claimed the opposite -- "the geometry is not a dead corner,
	# only a slow one" -- and went RED at 1.04 u. It was written from the
	# 4.7 s pin traced on the WEST edge, where the sled does eventually
	# break out; the corner the sweep actually names is worse than that.
	# The brief's hypothesis 2 is therefore CONFIRMED, for the corners
	# only, and it is confirmed IN COMBINATION with the cause above rather
	# than instead of it: the corner is inescapable because the corner is
	# where the yaw rate is zero, not because the corner is narrow.
	_check(not bool(pin["escaped"]),
		"and the worst is NOT merely slow: %d frames (%.1f s) of full lock and its farthest excursion is %.2f u -- no rotation frees this corner"
		% [PIN_FRAMES, PIN_FRAMES * FIXED_DELTA, pin["far"]])
	_pin_worst_at = worst_at
	_pin_worst_yaw = worst_yaw
	_pin_worst_steer = worst_steer

## =====================================================================
## PHASE GEAR -- the four vehicles, one assertion each, and the blind
## check is the DISPLACEMENT: a negative speed that moves nothing is a
## number, not a reverse gear.

## Where each vehicle is put for its gear run: open ground it can drive on,
## far from any wall, so the run measures the gear and not a bounce.
func _gear_stations() -> Array[Dictionary]:
	var track: KartTrack = _karting.track
	var pose: Dictionary = track.start_pose(0)
	return [
		{"who": "kart", "at": pose["position"], "yaw": pose["yaw"], "top": KartBody.REVERSE_SPEED},
		{"who": "yacht", "at": Vector3(0.0, 0.0, 0.0), "yaw": 0.0, "top": SandYacht.REVERSE_SPEED},
		{"who": "sailboat", "at": HubTransport.SAILBOAT_MOORING, "yaw": PI,
			"top": SailBoat.REVERSE_SPEED},
		{"who": "sled", "at": HubTransport.SLED_PARK, "yaw": PI / 2.0, "top": SledBody.REVERSE_SPEED},
	]

func _phase_gear() -> void:
	print("-- PHASE GEAR: a negative speed AND a real displacement, per vehicle --")
	for st in _gear_stations():
		var who: String = st["who"]
		var at: Vector3 = st["at"]
		var yaw: float = st["yaw"]
		var top: float = st["top"]
		var off: Dictionary = _leg(who, at, yaw, GEAR_FRAMES, 0.0, 0.0)
		var on: Dictionary = _leg(who, at, yaw, GEAR_FRAMES, 0.0, 1.0)
		print("     %-9s no gear %+8.3f u  |  gear %+8.3f u, lowest speed %+7.3f u/s (reverse_speed %.2f)"
			% [who, off["advance"], on["advance"], on["lowest"], top])
		_check(float(on["lowest"]) < -0.5 * top,
			"%s reaches %+.3f u/s, past half of its %.2f u/s reverse speed" % [who, on["lowest"], top])
		# THE BLIND HALF: the vehicle really went backwards. Signed, along
		# the heading it started on.
		_check(float(on["advance"]) < -1.0,
			"and it travels %+.3f u BACKWARD in %d frames -- displacement, not just a sign on a float"
			% [on["advance"], GEAR_FRAMES])
		_check(float(off["advance"]) > 0.0,
			"while the same station with no gear goes %+.3f u forward" % off["advance"])

## =====================================================================
## PHASE STEER -- the classic trap the brief names: a reverse whose
## steering is inverted by mistake.
##
## The contract is that full lock swings the NOSE the OTHER WAY when the
## vehicle is travelling backwards, which is what a real vehicle does and
## what VehicleDrive's `v_fwd < -0.05` line has always done for the brake's
## reverse. Gated as a SIGN COMPARISON against the same lock going
## forward, so it cannot pass by both being zero.

func _phase_steer() -> void:
	print("-- PHASE STEER: full lock forward and full lock in reverse turn OPPOSITE ways --")
	for st in _gear_stations():
		var who: String = st["who"]
		var fwd: Dictionary = _leg(who, st["at"], st["yaw"], GEAR_FRAMES, 1.0, 0.0)
		var rev: Dictionary = _leg(who, st["at"], st["yaw"], GEAR_FRAMES, 1.0, 1.0)
		var a: float = float(fwd["yaw_net"])
		var b: float = float(rev["yaw_net"])
		print("     %-9s forward %+8.3f deg  |  reverse %+8.3f deg"
			% [who, rad_to_deg(a), rad_to_deg(b)])
		_check(absf(a) > 0.05, "%s: the same lock forward turns it %+.2f deg" % [who, rad_to_deg(a)])
		_check(absf(b) > 0.02, "and in reverse it turns %+.2f deg -- neither is a zero passing for a match"
			% rad_to_deg(b))
		_check(a * b < 0.0,
			"and the two have OPPOSITE signs: the nose follows the direction of travel, not the input")

## =====================================================================
## PHASE SLOPE -- the sled, uphill and downhill, and the relation that
## makes the harder of the two possible at all.

func _steep_point() -> Vector3:
	var best := Vector3(HubRegion.MOUNTAIN_MIN.x, 0.0, HubRegion.MOUNTAIN_MIN.y)
	var worst: float = -1.0
	for r in HubMountain.rows():
		var z: float = HubRegion.MOUNTAIN_MIN.y + float(r) * HubMountain.PITCH
		for c in HubMountain.columns():
			var x: float = HubRegion.MOUNTAIN_MIN.x + float(c) * HubMountain.PITCH
			var p := Vector3(x, 0.0, z)
			var g: float = HubSurface.gradient_at(p).length()
			if g > worst:
				worst = g
				best = p
	return best

func _phase_slope() -> void:
	print("-- PHASE SLOPE: the sled backs up AND down its own hill --")
	var flank: Vector3 = _steep_point()
	var g: Vector2 = HubSurface.gradient_at(flank)
	var down_yaw: float = atan2(-g.x, -g.y)
	var up_yaw: float = down_yaw + PI
	var force: float = SledBody.slope_force(g)
	var authority: float = SledBody.reverse_authority()
	print("     steepest point %s  |g| %.4f (%.2f deg)  slope force %.4f u/s2  reverse ramp %.4f"
		% [flank, g.length(), rad_to_deg(atan(g.length())), force, authority])
	# BLIND: the ground under this phase is real and it is steep.
	_check(g.length() > 0.3, "blind: the flank is real -- |gradient| %.4f" % g.length())
	# THE RELATION, and it is the reason REVERSE_ACCEL is 13.0 and not a
	# feel number: backing up with the nose downhill is climbing, and the
	# gear answers gravity with a flat ramp.
	_check(force < authority,
		"the slope pushes %.4f u/s2 and the gear answers %.4f (%.0f %% used) -- it can back UP the flank"
		% [force, authority, 100.0 * force / authority])
	# Nose DOWNHILL, gear held: it must climb backwards.
	var up: Dictionary = _leg("sled", flank, down_yaw, GEAR_FRAMES, 0.0, 1.0)
	# Nose UPHILL, gear held: it must run away downhill.
	var dn: Dictionary = _leg("sled", flank, up_yaw, GEAR_FRAMES, 0.0, 1.0)
	print("     nose downhill, gear held: %+.3f u (climbing backwards)  |  nose uphill, gear held: %+.3f u"
		% [up["advance"], dn["advance"]])
	_check(float(up["advance"]) < -1.0,
		"nose DOWNHILL the gear backs it %+.3f u UP the slope" % up["advance"])
	_check(float(dn["advance"]) < -1.0,
		"and nose UPHILL it backs %+.3f u DOWN it -- the gear works both ways on the hill"
		% dn["advance"])
	# AND THE ORDER IS STILL RIGHT. CH41's freeze was the slope force
	# injected before step(); a gear that re-froze the sled would show up
	# as a run that never left zero.
	_check(float(up["lowest"]) < -0.5,
		"and neither run is the CH41 freeze: lowest speed %+.3f u/s, not 0.000" % up["lowest"])

## =====================================================================
## PHASE ESCAPE -- the blockage, and the gear against it. The pair is the
## measurement: the same start, the same lock, the same frames, one field
## different.

func _phase_escape() -> void:
	print("-- PHASE ESCAPE: every pin replayed with the gear --")
	var freed: int = 0
	var pinned: int = 0
	var worst_with: int = -1
	var sum_off: int = 0
	var sum_on: int = 0
	var rows: Array[String] = []
	for who in ["sled", "yacht"]:
		for s in _edge_samples():
			for steer in [1.0, -1.0]:
				var off: Dictionary = _leg(who, s["at"], s["yaw"], PIN_FRAMES, steer, 0.0)
				if int(off["escape_f"]) <= PIN_FRAMES_CEILING:
					continue
				pinned += 1
				var on: Dictionary = _leg(who, s["at"], s["yaw"], PIN_FRAMES, steer, 1.0)
				sum_off += int(off["escape_f"])
				sum_on += int(on["escape_f"])
				worst_with = maxi(worst_with, int(on["escape_f"]))
				if bool(on["escaped"]) and int(on["escape_f"]) <= GEAR_FRAMES_CEILING:
					freed += 1
				else:
					rows.append("     NOT FREED %-6s %s steer%+.0f at (%.1f, %.1f): %d frames -> %d frames"
						% [who, s["edge"], steer, float(s["at"].x), float(s["at"].z),
							off["escape_f"], on["escape_f"]])
	for r in rows:
		print(r)
	print("     %d pins; with the gear %d clear %.1f u inside %d frames. Mean time to get away: %.1f frames -> %.1f frames"
		% [pinned, freed, ESCAPE_RADIUS, GEAR_FRAMES_CEILING,
			float(sum_off) / maxf(float(pinned), 1.0), float(sum_on) / maxf(float(pinned), 1.0)])
	_check(pinned > 0, "the pins are still there to be freed (%d of them)" % pinned)
	_check(freed == pinned,
		"THE GEAR ALONE FREES EVERY ONE: %d of %d clear %.1f u within %.1f s, worst %d frames (%.2f s)"
		% [freed, pinned, ESCAPE_RADIUS, GEAR_FRAMES_CEILING * FIXED_DELTA,
			worst_with, worst_with * FIXED_DELTA])
	# ---- AND THE CORNER PHASE PIN NAMED, BY NAME. The averages above
	# could be carried by the easy samples; this is the one the sweep said
	# no rotation frees.
	var dead_off: Dictionary = _leg("sled", _pin_worst_at, _pin_worst_yaw, PIN_FRAMES, _pin_worst_steer, 0.0)
	var dead_on: Dictionary = _leg("sled", _pin_worst_at, _pin_worst_yaw, PIN_FRAMES, _pin_worst_steer, 1.0)
	print("     the dead corner %s: no gear %.2f u at its farthest in %d frames  |  gear %.2f u, away in %d frames"
		% [_pin_worst_at, dead_off["far"], PIN_FRAMES, dead_on["far"], dead_on["escape_f"]])
	_check(not bool(dead_off["escaped"]),
		"blind: without the gear that corner still holds it (%.2f u at its farthest)" % dead_off["far"])
	_check(bool(dead_on["escaped"]) and int(dead_on["escape_f"]) <= GEAR_FRAMES_CEILING,
		"and WITH the gear it is %.1f u clear in %d frames (%.2f s) -- the corner needed an input, not a wall fix"
		% [ESCAPE_RADIUS, dead_on["escape_f"], int(dead_on["escape_f"]) * FIXED_DELTA])
	_check(sum_on * 2 < sum_off,
		"and it more than halves the time on the wall: %.1f frames against %.1f"
		% [float(sum_on) / maxf(float(pinned), 1.0), float(sum_off) / maxf(float(pinned), 1.0)])
