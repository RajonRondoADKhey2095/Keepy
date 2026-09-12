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
##
## =====================================================================
## CH43 -- THE GESTURE CHANGED, THE PHYSICS DID NOT, AND FOUR PHASES SAY SO
##
## Mathieu refused CH42's second finger on device. The gear is now the DOWN
## half of the same vertical axis the accelerator already used, and this
## file grew the four phases that hold that claim up. Everything above is
## CH42's and is replayed UNCHANGED -- which is the point: if the gesture
## alone moved, PHASE GEAR / STEER / SLOPE / ESCAPE must still read what
## they read before, and they do.
##
##   * PHASE THRESHOLD  -- MEASURES the speed at which a held gear stops
##     braking and starts backing up, off a driven vehicle, frame by frame,
##     and brackets it. It never reads VehicleDrive.REVERSE_ENGAGE_SPEED to
##     prove REVERSE_ENGAGE_SPEED: it reads it once, at the end, to say
##     whether the measured bracket CONTAINS it.
##   * PHASE BRAKING   -- the guard-rail itself: the gear asked for at
##     cruising speed BRAKES, and no frame of it is a reverse.
##   * PHASE ARREST    -- the same gear asked for at a standstill engages,
##     at CH42's published ramp and to CH42's published speed.
##   * PHASE GESTURE   -- the writer: one axis, symmetric, and a second
##     finger that no longer does anything at all.
##
## ⚠️ THE WINDOW IS TAKEN FROM THE DATA, NOT CHOSEN. CH42's own diagnostic
## metric lied by measuring a fixed number of frames (see ESCAPE_RADIUS
## above), and CLAUDE.md names the family. PHASE BRAKING therefore does not
## ask "was the speed negative in the first N frames"; it finds the frame
## at which the speed FIRST reached the engagement band and asserts on the
## frames BEFORE that one, whichever frame it turns out to be. A fixed
## window would pass for free on a vehicle that simply brakes slowly.

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
	# ---- CH43. AFTER CH42's phases, deliberately: the four above are the
	# regression test on the physics, and they have to be seen to pass on
	# the tree that changed the gesture before the gesture is examined.
	_phase_threshold()
	_phase_braking()
	_phase_arrest()
	_phase_gesture()
	# ---- CH81. LAST, after CH43's own phase: PHASE GESTURE is the
	# regression test on the shared writer and has to be seen to pass on
	# the tree that took the gear off the kart before the kart is asked.
	_phase_lockout()
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
##
## ⚠️ CH81 -- WHAT THE "kart" ROW HERE IS, AND IS NOT. Since CH81 no player
## can write `input.reverse` for the kart: HubKarting sets
## `KartTouchInput.allows_reverse = false` on its own writer. This phase
## hands the body a KartInput DIRECTLY, so the kart row no longer says
## anything about the kart's CONTROLS -- it says that VehicleDrive's shared
## reverse branch still works, which is a live path (three vehicles by
## thumb, and `input.brake` at a standstill for every KartAiDriver on the
## grid). It is kept for exactly that regression, and PHASE LOCKOUT is
## where the kart's controls are gated. Reading this row as "the kart has
## a reverse" would be the stale-fact defect CLAUDE.md exists to stop.

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

## =====================================================================
## =====================================================================
## CH43 -- THE GESTURE MOVED. FOUR PHASES, AND THE PHYSICS IS UNTOUCHED.
## =====================================================================

## How far off a predicted per-frame step still counts as "that branch ran".
## Generous by six orders of magnitude against the smallest gap between two
## candidate branches on any vehicle (the sled's 12.0 brake against its 13.0
## ramp: 0.0167 u/s per frame), so the classifier can never be the reason a
## step is called one thing or the other.
const STEP_TOL: float = 1.0e-4
## The two candidate rates must be at least this far apart before a frame is
## classified at all. It is the blind half of the classifier: if a vehicle
## ever had brake_decel == reverse_accel, every "the gear engaged here"
## below would be a coin toss reported as a measurement.
const RATE_GAP_MIN: float = 1.0e-3

## ⚠️ WHERE CH43's THREE PHYSICS PHASES PUT THE SLED, AND WHY IT IS NOT
## WHERE CH42 PUT IT.
##
## MEASURED, on the first run of this phase, and it is a real distinction
## and not a tolerance to widen. `SLED_PARK` is at (-49, 3) -- the middle of
## the west ridge -- and SurfaceDrive adds `slope_accel * slope_gain * delta`
## to the world velocity AFTER VehicleDrive has written it (CH41). So on
## that station the sled's per-frame change is VehicleDrive's PLUS gravity's,
## and PHASE ARREST read its ramp as 14.4159 u/s2 against the published
## 13.0000, and its terminal speed as -2.3689 against -2.2000.
##
## Neither number is a defect: they are the hill, doing what CH41 built it to
## do, on a sled pointed down it. But they are the WRONG QUESTION for these
## three phases, which are about the branch inside VehicleDrive that ALL
## FOUR vehicles share -- and a phase that answered "the sled's ramp is
## 14.4159" would be measuring two things and reporting one.
##
## So CH43's phases drive the sled on FLAT ground, where `slope_accel` is
## exactly Vector3.ZERO and the sled IS a VehicleDrive; the sled on its hill
## stays CH42's PHASE SLOPE, replayed above, unchanged and green. The flat
## station is not asserted to be flat by assumption: `_phase_threshold`
## gates the measured slope at both stations and requires them to DIFFER,
## so a future surface that made the whole map flat would fail here rather
## than quietly turn PHASE SLOPE into a tautology.
const SLED_FLAT_STATION: Vector3 = Vector3(0.0, 0.0, -14.0)

## The gear stations, with the sled moved off its hill. Everything else is
## `_gear_stations()` verbatim -- the three vehicles that never touch a
## surface keep the exact points CH42 measured them at.
func _ch43_stations() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for st in _gear_stations():
		if String(st["who"]) == "sled":
			out.append({"who": "sled", "at": SLED_FLAT_STATION, "yaw": PI / 2.0,
				"top": SledBody.REVERSE_SPEED})
		else:
			out.append(st)
	return out

## The four vehicles' own numbers, published by their own files -- never
## retyped here (CLAUDE.md: un fait est publie une fois).
func _rates(who: String) -> Dictionary:
	match who:
		"kart":
			return {"brake": KartBody.BRAKE_DECEL, "ramp": KartBody.REVERSE_ACCEL,
				"top": KartBody.REVERSE_SPEED}
		"yacht":
			return {"brake": SandYacht.BRAKE_DECEL, "ramp": SandYacht.REVERSE_ACCEL,
				"top": SandYacht.REVERSE_SPEED}
		"sailboat":
			return {"brake": SailBoat.BRAKE_DECEL, "ramp": SailBoat.REVERSE_ACCEL,
				"top": SailBoat.REVERSE_SPEED}
	return {"brake": SledBody.BRAKE_DECEL, "ramp": SledBody.REVERSE_ACCEL,
		"top": SledBody.REVERSE_SPEED}

## Puts the vehicle down and drives it FORWARD for `frames`, leaving it in
## motion. The counterpart of `_leg`, which always starts from a standstill:
## every CH43 question about "what does the gear do to a vehicle that is
## already rolling" needs a rolling vehicle to ask it of.
func _spin_up(who: String, at: Vector3, yaw: float, frames: int) -> float:
	_place(who, at, yaw)
	var input := KartInput.new()
	input.throttle = 1.0
	for _f in frames:
		_drive(who, FIXED_DELTA, input)
	return _speed_of(who)

## ONE frame with the gear held, from wherever the vehicle currently is.
## Returns the speed before and after, and which of the two branches the
## step matches -- "brake", "gear", or "?" when it matches neither, which is
## the answer that makes this a measurement rather than a label.
func _gear_step(who: String) -> Dictionary:
	var rates: Dictionary = _rates(who)
	var before: float = _speed_of(who)
	var input := KartInput.new()
	input.throttle = 1.0
	input.reverse = 1.0
	_drive(who, FIXED_DELTA, input)
	var after: float = _speed_of(who)
	# What each branch WOULD have produced from `before`, spelled the way
	# VehicleDrive spells it, so a mismatch means the branch really differs.
	var as_brake: float = maxf(before - float(rates["brake"]) * FIXED_DELTA, 0.0)
	var as_gear: float = move_toward(before, -float(rates["top"]),
		float(rates["ramp"]) * FIXED_DELTA)
	var kind: String = "?"
	if absf(as_brake - as_gear) >= RATE_GAP_MIN:
		if absf(after - as_brake) <= STEP_TOL:
			kind = "brake"
		elif absf(after - as_gear) <= STEP_TOL:
			kind = "gear"
	return {"before": before, "after": after, "kind": kind,
		"as_brake": as_brake, "as_gear": as_gear}

## =====================================================================
## PHASE THRESHOLD -- WHERE the gear stops being a brake, MEASURED.
##
## The brief asked for the guard-rail's speed to be "prouve par sonde, pas
## par une affirmation", and reading VehicleDrive.REVERSE_ENGAGE_SPEED back
## would be the affirmation. So: spin the vehicle up to a different speed
## every run, then hold the gear and classify each frame by which branch's
## arithmetic it actually produced. The last frame classified `brake` and
## the first classified `gear` BRACKET the breakpoint, and the bracket
## tightens run by run because a different spin-up lands the samples at a
## different offset. The constant is opened once, at the very end, to say
## whether the bracket contains it.

## Spin-ups sampled. Coprime-ish spread rather than 1..N: what matters is
## that the decelerating samples land at many different residues of the
## brake step, which is what narrows the bracket.
const THRESHOLD_SPINS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 9, 11, 13, 17, 19, 23,
	29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101]
## Frames of held gear per spin-up: long enough for any of the four to cross
## the band from its spin-up speed, short enough not to drive into a wall.
const THRESHOLD_HOLD: int = 150

func _phase_threshold() -> void:
	print("-- PHASE THRESHOLD: the engagement speed, measured off the vehicle --")
	# ---- THE STATIONS ARE GATED BEFORE THEY ARE USED. The sled's flat
	# station has to be really flat, and SLED_PARK really not -- otherwise
	# "we moved it off the hill" is a sentence, not a measurement.
	var flat_g: float = SurfaceDrive.slope_accel_at(SLED_FLAT_STATION).length()
	var hill_g: float = SurfaceDrive.slope_accel_at(HubTransport.SLED_PARK).length()
	print("     sled stations: flat %s |slope| %.6f u/s2  |  CH42's SLED_PARK %s |slope| %.6f u/s2"
		% [SLED_FLAT_STATION, flat_g, HubTransport.SLED_PARK, hill_g])
	_check(SledBody.drivable(SLED_FLAT_STATION),
		"the sled's flat station %s is drivable" % SLED_FLAT_STATION)
	_check(flat_g == 0.0,
		"and gravity has EXACTLY no horizontal shadow there (%.9f u/s2) -- on it the sled is a plain VehicleDrive"
		% flat_g)
	_check(hill_g > 0.5,
		"while CH42's SLED_PARK carries %.4f u/s2 of it -- the two stations really are different ground, which is why PHASE SLOPE keeps that one"
		% hill_g)
	var unknown_total: int = 0
	var lo_all: float = -INF
	var hi_all: float = INF
	for st in _ch43_stations():
		var who: String = st["who"]
		# The greatest speed that still took the GEAR, and the smallest that
		# still took the BRAKE. The breakpoint is between them.
		var last_gear: float = -INF
		var first_brake: float = INF
		var gears: int = 0
		var brakes: int = 0
		var unknown: int = 0
		for spin in THRESHOLD_SPINS:
			_spin_up(who, st["at"], st["yaw"], spin)
			for _f in THRESHOLD_HOLD:
				var step: Dictionary = _gear_step(who)
				var kind: String = step["kind"]
				var before: float = step["before"]
				if kind == "brake":
					brakes += 1
					first_brake = minf(first_brake, before)
				elif kind == "gear":
					gears += 1
					last_gear = maxf(last_gear, before)
				else:
					unknown += 1
				# Once it is well into the gear there is nothing left to
				# bracket, and driving on only risks a wall.
				if before < -0.5:
					break
		unknown_total += unknown
		lo_all = maxf(lo_all, last_gear)
		hi_all = minf(hi_all, first_brake)
		print("     %-9s %5d brake frames, %5d gear frames, %d unclassified  |  bracket (%.6f, %.6f], width %.6f"
			% [who, brakes, gears, unknown, last_gear, first_brake, first_brake - last_gear])
		_check(brakes > 0 and gears > 0,
			"%s: the sweep saw BOTH branches run (%d brake, %d gear) -- a sweep that only ever saw one could not bracket anything"
			% [who, brakes, gears])
		_check(unknown == 0,
			"and every one of its %d frames matched one branch's arithmetic to within %.6f u/s -- no frame was labelled by elimination"
			% [brakes + gears + unknown, STEP_TOL])
		_check(last_gear < first_brake,
			"and the two never overlap: no speed took the brake below one that took the gear (%.6f < %.6f)"
			% [last_gear, first_brake])
		_check(last_gear <= VehicleDrive.REVERSE_ENGAGE_SPEED
				and first_brake > VehicleDrive.REVERSE_ENGAGE_SPEED,
			"and %s's own bracket (%.6f, %.6f] contains REVERSE_ENGAGE_SPEED %.4f"
			% [who, last_gear, first_brake, VehicleDrive.REVERSE_ENGAGE_SPEED])
	print("     ALL FOUR: (%.6f, %.6f], width %.6f, around REVERSE_ENGAGE_SPEED %.4f"
		% [lo_all, hi_all, hi_all - lo_all, VehicleDrive.REVERSE_ENGAGE_SPEED])
	_check(hi_all - lo_all < 0.30,
		"the four vehicles agree on a bracket %.6f u/s wide -- one threshold, in one place, for all of them"
		% (hi_all - lo_all))
	_check(lo_all <= VehicleDrive.REVERSE_ENGAGE_SPEED and hi_all > VehicleDrive.REVERSE_ENGAGE_SPEED,
		"and it contains %.4f -- the named constant IS the breakpoint the vehicles show, not a number written beside it"
		% VehicleDrive.REVERSE_ENGAGE_SPEED)
	# ---- THE BLIND HALF. The classifier must be able to find NOTHING.
	# Same sweep, same frames, gear NOT held: not one frame may come back
	# `gear`, or every count above is a label the classifier hands out.
	var false_gears: int = 0
	var moved: float = 0.0
	for st in _ch43_stations():
		var who: String = st["who"]
		_place(who, st["at"], st["yaw"])
		var input := KartInput.new()
		input.throttle = 1.0
		var rates: Dictionary = _rates(who)
		for _f in THRESHOLD_HOLD:
			var before: float = _speed_of(who)
			_drive(who, FIXED_DELTA, input)
			var as_gear: float = move_toward(before, -float(rates["top"]),
				float(rates["ramp"]) * FIXED_DELTA)
			if absf(_speed_of(who) - as_gear) <= STEP_TOL:
				false_gears += 1
		moved += absf(_speed_of(who))
	_check(moved > 1.0,
		"blind: with no gear held the four are still being driven (%.3f u/s of speed between them)" % moved)
	_check(false_gears == 0,
		"and NOT ONE of their %d frames matches the gear's arithmetic (%d did) -- the classifier can answer no"
		% [4 * THRESHOLD_HOLD, false_gears])

## =====================================================================
## PHASE BRAKING -- THE GUARD-RAIL. Sliding DOWN on a vehicle that is
## rolling forward brakes it, and not one frame of that is a reverse.
##
## ⚠️ THE WINDOW IS FOUND, NOT CHOSEN, and that is the whole design of this
## phase. "No reverse speed in the first N frames" passes for free on any
## vehicle slow enough not to have reached the band yet, and CH42's own
## escape metric was wrong in exactly that shape (ESCAPE_RADIUS, above).
## So the trace is walked to the frame where the speed FIRST enters the
## engagement band -- whichever frame that is -- and the assertions are
## about the frames BEFORE it. If a future tuning pass halved a brake
## rate, the window would simply get longer and the phase would still be
## asking the right question.

## Long enough for the slowest of the four to brake from cruise to the band
## and then reverse well past it, so the phase sees both sides of the story.
const BRAKING_FRAMES: int = 300
## Spin-up before the gear is asked for: 2 s of throttle, which puts every
## one of the four near its cap and far above the engagement band.
const BRAKING_SPIN: int = 120

func _phase_braking() -> void:
	print("-- PHASE BRAKING: the gear asked for AT SPEED brakes, and only brakes --")
	for st in _ch43_stations():
		var who: String = st["who"]
		var rates: Dictionary = _rates(who)
		var cruise: float = _spin_up(who, st["at"], st["yaw"], BRAKING_SPIN)
		# The trace, frame by frame, with the gear held from here on.
		var speeds: Array[float] = []
		var kinds: Array[String] = []
		for _f in BRAKING_FRAMES:
			var step: Dictionary = _gear_step(who)
			speeds.append(float(step["after"]))
			kinds.append(String(step["kind"]))
			if float(step["after"]) <= -float(rates["top"]) * 0.9:
				break
		# THE WINDOW, taken from the data: the first frame whose speed at
		# the START of the step was inside the engagement band.
		var enter: int = -1
		var before_f: float = cruise
		for i in speeds.size():
			if before_f <= VehicleDrive.REVERSE_ENGAGE_SPEED:
				enter = i
				break
			before_f = speeds[i]
		# What happened BEFORE that frame: every step a brake, every speed
		# still forward, and the speed falling on every single one of them.
		var brakes_before: int = 0
		var non_brake_before: int = 0
		var negatives_before: int = 0
		var rises_before: int = 0
		var prev: float = cruise
		var window: int = enter if enter >= 0 else speeds.size()
		for i in window:
			if kinds[i] == "brake":
				brakes_before += 1
			else:
				non_brake_before += 1
			if speeds[i] < 0.0:
				negatives_before += 1
			if speeds[i] >= prev:
				rises_before += 1
			prev = speeds[i]
		var bottom: float = 0.0
		for v in speeds:
			bottom = minf(bottom, v)
		print("     %-9s cruise %+7.3f u/s -> band at frame %d (%.3f s); %d braking frames, lowest before it %+7.3f; run bottoms at %+7.3f"
			% [who, cruise, window, float(window) * FIXED_DELTA, brakes_before,
				speeds[maxi(window - 1, 0)], bottom])
		_check(cruise > 3.0 * VehicleDrive.REVERSE_ENGAGE_SPEED,
			"%s: blind -- it really was ROLLING when the gear was asked for (%.3f u/s, %.1fx the band)"
			% [who, cruise, cruise / VehicleDrive.REVERSE_ENGAGE_SPEED])
		_check(enter >= 0, "and it reaches the band, in %d frames (%.3f s)"
			% [window, float(window) * FIXED_DELTA])
		_check(window > 3, "and it took %d frames to get there -- not a vehicle that was already stopped" % window)
		# THE GUARD-RAIL ITSELF.
		_check(negatives_before == 0,
			"NOT ONE of those %d frames is a reverse speed (%d were) -- the gear did not engage on a rolling vehicle"
			% [window, negatives_before])
		_check(non_brake_before == 0,
			"and every one of them ran the BRAKE branch (%d did not) -- measured by arithmetic, not by the sign of a float"
			% non_brake_before)
		# BLIND: the speed really is falling. A window of frames that all
		# sat at the same speed would satisfy both assertions above.
		_check(rises_before == 0,
			"and the speed falls on every one of them (%d did not) -- it is braking, not merely refusing to reverse"
			% rises_before)
		# AND IT DOES REVERSE, AFTERWARDS. Without this the phase would be
		# green on a vehicle whose gear never works at all.
		_check(bottom < -0.5 * float(rates["top"]),
			"and once stopped it DOES back up, to %+.3f u/s -- the guard-rail delays the gear, it does not cancel it"
			% bottom)

## =====================================================================
## PHASE ARREST -- the other half of Mathieu's sentence: the SAME slide,
## from a standstill, engages the gear at once.
##
## What is gated is the RAMP and the TOP SPEED against the numbers CH42
## published for the second finger, because that is the brief's condition:
## the gesture changed, the physics did not. The ramp is read as a real
## per-frame delta off the first frames of the run, never as the constant
## it should equal.

func _phase_arrest() -> void:
	print("-- PHASE ARREST: the same slide FROM REST engages, at CH42's ramp and speed --")
	for st in _ch43_stations():
		var who: String = st["who"]
		var rates: Dictionary = _rates(who)
		_place(who, st["at"], st["yaw"])
		_check(absf(_speed_of(who)) < 1.0e-6,
			"%s: blind -- it is at a standstill to begin with (%.9f u/s)" % [who, _speed_of(who)])
		# The FIRST step: from 0, which is inside the band, so the gear must
		# engage on it -- there is nothing to brake.
		var first: Dictionary = _gear_step(who)
		_check(String(first["kind"]) == "gear",
			"the very first frame runs the GEAR branch (it ran '%s') -- from rest there is nothing to brake first"
			% first["kind"])
		# The RAMP, measured: the delta over the second and third frames,
		# where the vehicle is moving but nowhere near its terminal speed.
		var a: float = _speed_of(who)
		_gear_step(who)
		var b: float = _speed_of(who)
		_gear_step(who)
		var c: float = _speed_of(who)
		var ramp1: float = (a - b) / FIXED_DELTA
		var ramp2: float = (b - c) / FIXED_DELTA
		# And the terminal speed, held long enough to reach it.
		for _f in GEAR_FRAMES:
			_gear_step(who)
		var top: float = _speed_of(who)
		print("     %-9s ramp %.4f / %.4f u/s2 (published %.4f)  |  top %+7.4f u/s (published %+7.4f)"
			% [who, ramp1, ramp2, rates["ramp"], top, -float(rates["top"])])
		_check(absf(ramp1 - float(rates["ramp"])) < 1.0e-3 and absf(ramp2 - float(rates["ramp"])) < 1.0e-3,
			"%s builds its reverse at %.4f u/s2 -- CH42's REVERSE_ACCEL %.4f, unchanged by the new gesture"
			% [who, ramp2, rates["ramp"]])
		_check(absf(top + float(rates["top"])) < 1.0e-3,
			"and it settles at %+.4f u/s -- CH42's REVERSE_SPEED %.4f, unchanged by the new gesture"
			% [top, rates["top"]])

## =====================================================================
## PHASE GESTURE -- THE WRITER. One axis, symmetric, and a second finger
## that no longer does anything at all.
##
## Everything above this line is about a KartInput and a vehicle; this is
## about the only thing CH43 actually changed, KartTouchInput. It drives a
## real instance with real InputEvents -- the same way YachtTraceProbe does
## -- because the question "does a second finger still do something" cannot
## be answered by reading the file: a `grep` finds the code that IS there,
## and what is being asserted is the absence of a behaviour.
##
## ⚠️ CH81 -- THE INSTANCE THIS PHASE DRIVES IS THE DEFAULT ONE, which
## since CH81 is a statement and not an accident: a bare KartTouchInput
## carries `allows_reverse = true`, i.e. the configuration HubTransport's
## sand yacht, sailboat, sled and quad all share. So every assertion below
## is the regression test on THOSE four, unchanged. The kart's writer is
## PHASE LOCKOUT's subject.
##
## ⚠️ IT IS SYNCHRONOUS ON PURPOSE. `_physics_process` is where the keyboard
## poll lives, and it would overwrite `input.reverse` between two events; no
## frame is advanced inside this phase, so every value read is the one the
## event just wrote. (The poll is harmless anyway while a finger is down --
## it returns early on `steering_active` -- but relying on that would be
## relying on a detail of the file under test.)

## The anchor, mid-screen on a 1080x1920 canvas. Any point does: the whole
## scheme is relative to wherever the first finger lands.
const G_ANCHOR := Vector2(540.0, 1400.0)

func _touch_down(t: Node, at: Vector2, index: int) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = at
	ev.pressed = true
	t.call("_unhandled_input", ev)

func _touch_up(t: Node, at: Vector2, index: int) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = at
	ev.pressed = false
	t.call("_unhandled_input", ev)

func _touch_drag(t: Node, at: Vector2, index: int) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = at
	t.call("_unhandled_input", ev)

## Anchor at G_ANCHOR, then a drag `dy` px UP the screen (negative = down).
## Returns the two halves of the axis the writer produced.
func _slide(t: Node, dy: float) -> Dictionary:
	_touch_down(t, G_ANCHOR, 0)
	_touch_drag(t, G_ANCHOR + Vector2(0.0, -dy), 0)
	var input: KartInput = t.get("input")
	var out := {"boost": input.boost, "reverse": input.reverse, "steer": input.steer}
	_touch_up(t, G_ANCHOR + Vector2(0.0, -dy), 0)
	return out

func _phase_gesture() -> void:
	print("-- PHASE GESTURE: one axis, and the second finger is gone --")
	var t: Node = KartTouchInput.new()
	add_child(t)
	t.set("enabled", true)
	var span: float = float(t.get("boost_span"))
	var dead: float = float(t.get("boost_dead_zone"))
	print("     span %.1f px  dead zone %.1f px" % [span, dead])
	# ---- 1. BLIND FIRST. The instrument must be able to read a NON-zero,
	#         or every "it stayed at zero" below is free.
	var up: Dictionary = _slide(t, span)
	_check(float(up["boost"]) > 0.99,
		"blind: a full slide UP writes boost %.4f -- the instrument can read a value" % up["boost"])
	_check(float(up["reverse"]) == 0.0,
		"and it writes reverse %.4f: up is pace, and only pace" % up["reverse"])
	# ---- 2. THE NEW HALF.
	var down: Dictionary = _slide(t, -span)
	_check(float(down["reverse"]) > 0.99,
		"a full slide DOWN writes reverse %.4f -- the gear, on the accelerator's own axis" % down["reverse"])
	_check(float(down["boost"]) == 0.0,
		"and boost %.4f: the two halves are exclusive, so a stale push cannot raise the cap of a vehicle being stopped"
		% down["boost"])
	# ---- 3. SYMMETRY, which is the word Mathieu used. The SAME travel each
	#         way must buy the same fraction, at three points and not one:
	#         two curves can agree at their ends and disagree everywhere in
	#         between.
	var worst: float = 0.0
	var rows: Array[String] = []
	for frac in [0.25, 0.5, 0.75, 1.0]:
		var d: float = dead + (span - dead) * float(frac)
		var u: Dictionary = _slide(t, d)
		var v: Dictionary = _slide(t, -d)
		worst = maxf(worst, absf(float(u["boost"]) - float(v["reverse"])))
		rows.append("       %+6.1f px -> boost %.6f   |   %+6.1f px -> reverse %.6f"
			% [d, u["boost"], -d, v["reverse"]])
	for r in rows:
		print(r)
	_check(worst < 1.0e-6,
		"the same travel buys the same fraction both ways at four points, worst mismatch %.9f -- one axis, one mapping"
		% worst)
	# ---- 4. THE DEAD ZONE IS SYMMETRIC TOO. A gear that engaged inside the
	#         zone where the accelerator does nothing would fire on the
	#         tremor of a thumb that is only steering.
	var in_dead_up: Dictionary = _slide(t, dead * 0.5)
	var in_dead_dn: Dictionary = _slide(t, -dead * 0.5)
	_check(float(in_dead_up["boost"]) == 0.0 and float(in_dead_dn["reverse"]) == 0.0,
		"half a dead zone buys nothing either way (boost %.4f, reverse %.4f)"
		% [in_dead_up["boost"], in_dead_dn["reverse"]])
	# ---- 5. LIFTING THE FINGER DROPS THE GEAR, AT ONCE. CH31's decay is
	#         for the boost and must not have been copied onto this half.
	_touch_down(t, G_ANCHOR, 0)
	_touch_drag(t, G_ANCHOR + Vector2(0.0, span), 0)
	var held: float = float((t.get("input") as KartInput).reverse)
	_touch_up(t, G_ANCHOR + Vector2(0.0, span), 0)
	var after_lift: float = float((t.get("input") as KartInput).reverse)
	_check(held > 0.99 and after_lift == 0.0,
		"the gear is %.4f while the thumb is down and %.4f the instant it lifts -- no decay on this half"
		% [held, after_lift])
	# ---- 6. THE SECOND FINGER IS GONE. The assertion CH43 exists for, and
	#         it is made three ways: the field that tracked it, the touch
	#         that used to arm it, and the mouse button that stood in for it
	#         on a desktop.
	_check(not ("_reverse_index" in t),
		"KartTouchInput no longer carries a second finger's index at all (the field CH42 added is gone)")
	_touch_down(t, G_ANCHOR, 0)
	var before2: KartInput = t.get("input")
	var boost_before: float = before2.boost
	var steer_before: float = before2.steer
	_touch_down(t, Vector2(900.0, 1600.0), 1)
	_touch_drag(t, Vector2(880.0, 1200.0), 1)
	var during: KartInput = t.get("input")
	_check(during.reverse == 0.0,
		"a SECOND finger pressed and dragged writes reverse %.4f -- CH42's gesture does nothing" % during.reverse)
	_check(during.boost == boost_before and during.steer == steer_before,
		"and it moves neither boost (%.4f) nor steer (%.4f): the axis belongs to the anchor finger alone"
		% [during.boost, during.steer])
	_touch_up(t, Vector2(880.0, 1200.0), 1)
	_check((t.get("input") as KartInput).reverse == 0.0,
		"and lifting it writes reverse %.4f as well" % (t.get("input") as KartInput).reverse)
	# The anchor finger still owns the axis while the second one is down --
	# a second finger that BROKE the first would be its own defect.
	_touch_drag(t, G_ANCHOR + Vector2(0.0, span), 0)
	_check((t.get("input") as KartInput).reverse > 0.99,
		"and with that second finger still on the glass the ANCHOR finger's slide down still works (%.4f)"
		% (t.get("input") as KartInput).reverse)
	_touch_up(t, G_ANCHOR + Vector2(0.0, span), 0)
	# The desktop stand-in, same question.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.position = Vector2(700.0, 1500.0)
	click.pressed = true
	t.call("_unhandled_input", click)
	_check((t.get("input") as KartInput).reverse == 0.0,
		"and the right mouse button, which stood in for that finger off-web, writes reverse %.4f"
		% (t.get("input") as KartInput).reverse)
	# ---- 7. AND THE MOUSE DOES DRIVE THE AXIS, so the removal above took
	#         the shortcut and not the desktop's ability to test the scheme.
	#
	# ⚠️ THE BLIND HALF OF THIS ONE WAS FOUND BY THE RED PASS, not written
	# in from the start, and it is worth the four lines. The first version
	# went straight to the drag -- and under the red pass (CH42's writer
	# restored verbatim) it PASSED, on a `reverse` the right-button check
	# above had left sitting at 1.0. A gesture assertion that reads a field
	# nobody has cleared is reading the previous assertion, which is the
	# fifteenth false signal this repo has caught and the second found by a
	# red pass rather than by a review.
	var up_r := InputEventMouseButton.new()
	up_r.button_index = MOUSE_BUTTON_RIGHT
	up_r.position = Vector2(700.0, 1500.0)
	up_r.pressed = false
	t.call("_unhandled_input", up_r)
	var down_l := InputEventMouseButton.new()
	down_l.button_index = MOUSE_BUTTON_LEFT
	down_l.position = G_ANCHOR
	down_l.pressed = true
	t.call("_unhandled_input", down_l)
	_check((t.get("input") as KartInput).reverse == 0.0,
		"blind: pressing the left button anchors and CLEARS the axis first (reverse %.4f) -- the next line cannot pass on a stale value"
		% (t.get("input") as KartInput).reverse)
	var move := InputEventMouseMotion.new()
	move.position = G_ANCHOR + Vector2(0.0, span)
	t.call("_unhandled_input", move)
	_check((t.get("input") as KartInput).reverse > 0.99,
		"and the left button dragged DOWN writes reverse %.4f -- the desktop has the whole axis, not half of it"
		% (t.get("input") as KartInput).reverse)
	t.queue_free()

## =====================================================================
## PHASE LOCKOUT -- THE KART HAS NO GEAR, AND THE OTHER FOUR STILL DO.
##
## Mathieu's retour: on the circuit Keepy must not be able to back up.
## Everything above this line is CH42/CH43 and still holds -- VehicleDrive's
## reverse branch is untouched, and so are the four vehicles that reach it
## with a thumb. What CH81 changed is ONE instance value on ONE writer,
## `KartTouchInput.allows_reverse`, and this is the only phase that knows
## it exists.
##
## ⚠️ IT ENTERS BY THE PLAYER'S CHANNEL, AT BOTH ENDS. A phase that wrote
## `input.reverse = 0.0` itself and then asserted the kart does not reverse
## would be asserting its own assignment; a phase that read `allows_reverse`
## back off the writer would be reading a variable and calling it a proof
## (CLAUDE.md: "une sonde qui gate une INTERACTION entre par le canal du
## joueur", and CH58's forty-three green assertions on a board no tap ever
## reached). So every number below comes from real InputEvents fed to a
## real KartTouchInput, and the vehicle they reach is the player's kart on
## the circuit, driven through the writer's OWN `_physics_process` so the
## automatic accelerator is the real one and not a literal typed here.
##
## ⚠️ AND THE BLIND HALF IS AN A/B ON THE SAME KART. "No negative speed" is
## an assertion of ABSENCE and passes for free against a bench that cannot
## produce a negative speed at all. So the identical gesture is played into
## the identical kart from the identical pose through two writers that
## differ in exactly one boolean -- the DEFAULT one, which is the
## configuration HubTransport's four vehicles share, must drive it
## BACKWARDS, and the kart's must not. The pair is the measurement; either
## run alone is not. It cuts both ways in one run, too: the kart's writer
## has to go FORWARD, which is what says the change took the gear and not
## the axis.

## Two seconds of held thumb. Short on purpose: the assertions are about
## the SIGN of the speed, and a longer run would put the forward leg into
## the first corner and the reverse leg behind the grid, where a fence
## reflection would be doing some of the arithmetic.
const LOCKOUT_FRAMES: int = 120
## How far down the screen the thumb is dragged: the kart's full span, so
## the gesture asks for ALL of whichever half it lands in.
const LOCKOUT_DRAG_PX: float = KartTouchInput.KART_BOOST_SPAN

## A writer configured the way HubKarting configures its own, or the way
## HubTransport leaves its default. Built here rather than borrowed from
## the live nodes so the A/B differs in ONE field: driving the live kart
## writer against the live yacht writer would also be comparing two boost
## spans, and a difference with two causes is not a measurement.
func _lockout_writer(allows_reverse: bool) -> Node:
	var t: Node = KartTouchInput.new()
	add_child(t)
	t.set("boost_span", KartTouchInput.KART_BOOST_SPAN)
	t.set("boost_dead_zone", KartTouchInput.KART_BOOST_DEAD_ZONE)
	t.set("boost_release_s", KartTouchInput.KART_BOOST_RELEASE_S)
	t.set("allows_reverse", allows_reverse)
	t.set("enabled", true)
	return t

## Anchor at G_ANCHOR and drag `dy` px UP the screen (negative = down),
## leaving the thumb DOWN -- the state the run below is measured in.
func _hold(t: Node, dy: float) -> void:
	_touch_down(t, G_ANCHOR, 0)
	_touch_drag(t, G_ANCHOR + Vector2(0.0, -dy), 0)

## The player's kart from the grid pose, driven for `frames` by whatever
## `t` is writing -- with the writer's own `_physics_process` called each
## frame, because that is where the automatic throttle lives. Called
## directly rather than by advancing a real frame: this phase is
## synchronous like PHASE GESTURE, and the question is what that function
## DOES, not when the engine gets round to it.
func _lockout_run(t: Node, frames: int) -> Dictionary:
	var pose: Dictionary = (_karting.track as KartTrack).start_pose(0)
	var at: Vector3 = pose["position"]
	var yaw: float = float(pose["yaw"])
	_place("kart", at, yaw)
	var lowest: float = 0.0
	var highest: float = 0.0
	for _f in frames:
		t.call("_physics_process", FIXED_DELTA)
		_drive("kart", FIXED_DELTA, t.get("input"))
		lowest = minf(lowest, _speed_of("kart"))
		highest = maxf(highest, _speed_of("kart"))
	var moved: Vector3 = _flat("kart") - at
	return {"lowest": lowest, "highest": highest,
		"advance": moved.dot(Vector3(sin(yaw), 0.0, cos(yaw)))}

## One poll of a writer's keyboard half with `key` held. `flush_buffered_
## events` is what makes this synchronous: `parse_input_event` only queues,
## and a phase that read the key state back without flushing would be
## reading the state before its own event -- a zero that looks like a
## refusal.
func _key_reverse(t: Node, key: Key) -> float:
	var down := InputEventKey.new()
	down.keycode = key
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	t.call("_physics_process", FIXED_DELTA)
	var got: float = float((t.get("input") as KartInput).reverse)
	var up := InputEventKey.new()
	up.keycode = key
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	return got

func _phase_lockout() -> void:
	print("-- PHASE LOCKOUT: the kart's writer refuses the gear, the shared one keeps it --")
	var kart_w: Node = _lockout_writer(false)
	var free_w: Node = _lockout_writer(true)
	# ---- 1. THE A/B, same kart, same pose, same gesture, one boolean apart.
	_hold(free_w, -LOCKOUT_DRAG_PX)
	_hold(kart_w, -LOCKOUT_DRAG_PX)
	var free_in: KartInput = free_w.get("input")
	var kart_in: KartInput = kart_w.get("input")
	print("     thumb held %.0f px DOWN:  shared writer reverse %.4f  |  kart writer reverse %.4f"
		% [LOCKOUT_DRAG_PX, free_in.reverse, kart_in.reverse])
	_check(free_in.reverse > 0.99,
		"blind: the SHARED writer still writes reverse %.4f on that slide -- the instrument can read a gear, and HubTransport's four vehicles keep it"
		% free_in.reverse)
	_check(kart_in.reverse == 0.0,
		"and the KART's writer writes reverse %.4f: the down half is inert on this instance" % kart_in.reverse)
	var free_run: Dictionary = _lockout_run(free_w, LOCKOUT_FRAMES)
	var kart_run: Dictionary = _lockout_run(kart_w, LOCKOUT_FRAMES)
	print("     %d frames of it on the SAME kart from the SAME grid pose:" % LOCKOUT_FRAMES)
	print("       shared writer: lowest %+8.4f u/s  advance %+8.3f u" % [free_run["lowest"], free_run["advance"]])
	print("       kart writer:   lowest %+8.4f u/s  advance %+8.3f u" % [kart_run["lowest"], kart_run["advance"]])
	_check(float(free_run["lowest"]) < -0.5 * KartBody.REVERSE_SPEED
			and float(free_run["advance"]) < -1.0,
		"blind: through the shared writer the kart reaches %+.4f u/s and travels %+.3f u BACKWARD -- this bench CAN reverse this kart"
		% [free_run["lowest"], free_run["advance"]])
	_check(float(kart_run["lowest"]) >= 0.0,
		"and through the kart's writer its speed never goes below %+.4f u/s: no reverse, at all"
		% kart_run["lowest"])
	_check(float(kart_run["advance"]) > 1.0,
		"while the SAME held thumb still drives it %+.3f u FORWARD at up to %.4f u/s -- the gear went, the axis did not, and the automatic accelerator is untouched"
		% [kart_run["advance"], kart_run["highest"]])
	# ---- 2. THE UP HALF AND THE STEER HALF SURVIVE ON THE KART'S WRITER.
	var up: Dictionary = _slide(kart_w, LOCKOUT_DRAG_PX)
	_check(float(up["boost"]) > 0.99 and float(up["reverse"]) == 0.0,
		"a full slide UP on the kart's writer still buys boost %.4f (reverse %.4f) -- CH31's accelerator is not what changed"
		% [up["boost"], up["reverse"]])
	# ⚠️ THE GATED RESET, AND THE RED PASS IS WHAT ASKED FOR IT. The first
	# version of the block below read a `throttle` that `_lockout_run` had
	# left at 1.0 a hundred frames earlier -- CH43's own "une assertion sur
	# une valeur tenue peut relire l'assertion precedente", committed in the
	# very phase that cites it. Clearing is not enough: the zero is
	# ASSERTED, because a clear that silently stopped working would put the
	# stale value straight back.
	kart_w.set("enabled", false)
	kart_w.set("enabled", true)
	var cleared: KartInput = kart_w.get("input")
	_check(cleared.throttle == 0.0 and cleared.reverse == 0.0 and cleared.steer == 0.0,
		"blind: the writer is cleared first (throttle %.4f, reverse %.4f, steer %.4f) -- the three lines below cannot pass on a stale value"
		% [cleared.throttle, cleared.reverse, cleared.steer])
	# ⚠️ DOWN THE SCREEN IS +y, SO THE OFFSET IS POSITIVE. The first version
	# wrote -LOCKOUT_DRAG_PX here and therefore drove the UP half while
	# claiming the down one -- a free green, and the red pass is what found
	# it (3 reds for 4 predicted). `_slide` takes the dy convention and
	# negates it itself, which is exactly how the two got mixed up.
	var diag_at: Vector2 = G_ANCHOR + Vector2(KartTuning.steer_span(), LOCKOUT_DRAG_PX)
	_touch_down(kart_w, G_ANCHOR, 0)
	_touch_drag(kart_w, diag_at, 0)
	var diag: KartInput = kart_w.get("input")
	_check(absf(diag.steer) > 0.99 and diag.reverse == 0.0,
		"and a DIAGONAL drag DOWN-and-right still steers %+.4f with reverse %.4f: the refusal is on one half of one axis and not on the drag"
		% [diag.steer, diag.reverse])
	kart_w.call("_physics_process", FIXED_DELTA)
	var held: KartInput = kart_w.get("input")
	_check(held.throttle == 1.0 and held.reverse == 0.0,
		"and the automatic accelerator still arrives under that same held thumb (throttle %.4f, reverse %.4f) -- pulling down costs the push and introduces no new state"
		% [held.throttle, held.reverse])
	_touch_up(kart_w, diag_at, 0)
	# ---- 3. THE KEYBOARD HALF OF THE SAME AXIS. Off-web it is what a probe
	#         and the editor drive, so a disagreement with the thumb would
	#         be invisible from device and green on a bench.
	for key in [KEY_DOWN, KEY_S, KEY_SPACE]:
		var shared: float = _key_reverse(free_w, key)
		var karted: float = _key_reverse(kart_w, key)
		print("       key %-6s  shared %.4f  |  kart %.4f" % [OS.get_keycode_string(key), shared, karted])
		_check(shared > 0.99,
			"blind: %s still writes reverse %.4f on the shared writer" % [OS.get_keycode_string(key), shared])
		_check(karted == 0.0,
			"and reverse %.4f on the kart's -- the keyboard obeys the same one licence as the thumb" % karted)
	# ---- 4. THE LIVE NODES, and this is the half the A/B above cannot see.
	#         Everything so far was measured on writers this phase built:
	#         it proves the mechanism, not that the GAME wired it. CH46's
	#         seven markers pinned on the world origin were a correct
	#         mechanism registered on the wrong node.
	var live_kart: Node = _karting.touch
	var live_shared: Node = _transport.touch
	_check(live_kart != null and not bool(live_kart.get("allows_reverse")),
		"the writer HubKarting actually built (%s) carries allows_reverse = %s"
		% [live_kart.name, live_kart.get("allows_reverse")])
	_check(live_shared != null and bool(live_shared.get("allows_reverse")),
		"and the one HubTransport built (%s) carries %s -- the yacht, the sailboat, the sled and the quad are one writer and it is not this lot's"
		% [live_shared.name, live_shared.get("allows_reverse")])
	_check(live_kart != live_shared,
		"and they are two distinct nodes, which is what makes a per-instance licence possible at all")
	# ---- 5. THE HUD DOES NOT NAME A COMMAND THE WRITER REFUSES. CH31's
	#         finding was that an unnamed command does not exist; the
	#         converse is a named command that cannot be reached, and it is
	#         worse -- the player pulls down, nothing happens, and the
	#         screen says it should.
	var hud: KartHud = _hub.get_node("KartHud") as KartHud
	_check(hud != null, "the hub's KartHud resolves")
	if hud != null:
		hud.set_reverse_available(true)
		var with_gear: String = hud.axis_hint_text()
		hud.set_reverse_available(false)
		var without: String = hud.axis_hint_text()
		print("       hint with a gear: %s" % with_gear)
		print("       hint without:     %s" % without)
		_check(with_gear.contains("reculer"),
			"blind: told it has a gear the HUD names it -- the instrument can read the line")
		_check(not without.contains("reculer") and without.contains("foncer"),
			"and told it has none the line drops the gear and keeps the accelerator")
		_check(with_gear != without, "and the two lines really differ")
		# Left in the state the game will set it to on the next mode entry.
		hud.set_reverse_available(true)
	kart_w.queue_free()
	free_w.queue_free()
