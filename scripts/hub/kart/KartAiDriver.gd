extends RefCounted
class_name KartAiDriver
## An OPPONENT's writer of a KartInput -- carte-blanche V8, karting lot 2.
##
## =====================================================================
## WHAT IT IS, AND WHAT IT IS NOT
##
## The V7 test driver (scripts/dev/KartLineInput.gd, pure pursuit on the
## spine, "0.62 throttle when the far heading turns") moved here and grew
## into a racer. It still writes the SAME KartInput a thumb writes, and
## the kart it drives is the SAME KartBody with the SAME drive(): there is
## no AI physics, only an AI source of steer / throttle / brake / boost.
## KartProbe drives the PLAYER's kart with one of these (profile "probe")
## to lap the real track, exactly as it did with KartLineInput.
##
## =====================================================================
## HOW IT DRIVES -- three ideas
##
##  1. LINE. Pure pursuit: aim at the spine point `lookahead` ahead,
##     offset sideways by `_lane` -- a lateral target (u, positive = right
##     of travel) the driver EASES toward. The lane is the personality's
##     natural line, biased toward the inside or the outside of a bend
##     (`corner_bias` x signed curvature), and pushed to the freer side
##     when another kart is close ahead (the overtake). A lane is never
##     a teleport: it moves at LANE_RATE u/s, which is what makes an
##     overtake read as a swerve and a fault as a drift.
##
##  2. SPEED PROFILE. Once per race (setup()), a v_max per spine sample:
##     the slower of "what the tyres allow" (sqrt(a_lat / curvature)) and
##     "what the steering allows" (the yaw rate KartBody.drive() gives at
##     that speed, with STEER_HEADROOM in hand for corrections), then a
##     BACKWARD pass so v[i] <= sqrt(v[i+1]^2 + 2 a_brake ds): the kart
##     brakes BEFORE the bend, at a distance that depends on how fast it
##     arrives -- not "slows down when it is already turning". The driver
##     reads the profile one sample ahead and steers throttle / boost /
##     brake toward it. Boost (KartInput.boost) is how an opponent goes
##     faster than the cruise, exactly like the player's push.
##
##  3. PERSONALITY = the profile's numbers + a WOBBLE (steer noise, an
##     amplitude and a frequency) + FAULTS (a Poisson event per minute:
##     the lane is thrown outside the track for ~1 s and the brake is
##     ignored, so the kart runs wide onto the grass and pays for it in
##     the body's own off-track cap). Three profiles, chosen so they are
##     told apart by WATCHING, not by reading a top speed: the cat is
##     quick in the bends and slow on the straight, the beaver drives the
##     same line every lap, the boar boosts down the straights, takes the
##     bends wide and runs off now and then.
##
## RUBBER BAND. `speed_scale` is written by HubKarting from the gap to the
## player (see HubKarting.rubber_band_for). It multiplies the profile's
## v_max, and it is bounded there (0.93 .. 1.05) -- a leash, not a magnet.

## Steer gain per radian of heading error (KartLineInput's own).
const STEER_GAIN: float = 1.0 / 0.55
## Headroom kept on the steering limit when deriving v_max from the yaw
## rate (>1: the kart can still correct a wobble at the profile's speed).
const STEER_HEADROOM: float = 1.15
## How fast the lateral target moves (u/s).
const LANE_RATE: float = 2.6
## Lookahead in u: a base plus a fraction of the speed.
const LOOKAHEAD_BASE: float = 3.6
const LOOKAHEAD_PER_SPEED: float = 0.32
const LOOKAHEAD_MAX: float = 9.0
## A kart this far ahead (u along the lap) and within OVERTAKE_LATERAL of
## the lane is something to pass.
const OVERTAKE_RANGE: float = 8.0
const OVERTAKE_LATERAL: float = 1.7
const OVERTAKE_SHIFT: float = 2.1
## The lane stays this far inside the edge line, except during a fault.
const LANE_MARGIN: float = 1.1
const FAULT_S: float = 0.95
## Minimum curvature considered (a straight): keeps sqrt(a / k) finite.
const K_FLOOR: float = 0.004

## The three racers, plus the probe's neutral profile. Every number is
## in world units and seconds:
##   a_lat        lateral acceleration the driver accepts in a bend (u/s2)
##   top          boost the driver is willing to hold on a straight (0..1)
##   brake_margin speed over the profile before the brake is pressed (u/s)
##   a_brake      deceleration assumed by the backward pass (u/s2)
##   corner_bias  lane offset per unit of signed curvature x 10 (u): + = outside
##   lane         natural lateral offset on the straights (u)
##   wobble_amp   steer noise amplitude (0..1 of full lock)
##   wobble_hz    steer noise frequency
##   fault_rate   faults per minute of racing
const PROFILES: Dictionary = {
	"cat": {"a_lat": 7.2, "top": 0.35, "brake_margin": 1.3, "a_brake": 9.0, "corner_bias": -0.9, "lane": -0.6,
		"wobble_amp": 0.10, "wobble_hz": 2.6, "fault_rate": 0.9},
	"beaver": {"a_lat": 5.6, "top": 0.55, "brake_margin": 0.5, "a_brake": 7.0, "corner_bias": 0.0, "lane": 0.0,
		"wobble_amp": 0.03, "wobble_hz": 0.8, "fault_rate": 0.25},
	"boar": {"a_lat": 4.6, "top": 1.0, "brake_margin": 1.6, "a_brake": 11.0, "corner_bias": 1.1, "lane": 0.7,
		"wobble_amp": 0.07, "wobble_hz": 0.5, "fault_rate": 1.6},
	# The probe's driver: no boost, no noise, no faults -- the V7 test
	# driver's behaviour, kept so the lap-timing contract is measured on
	# a deterministic drive.
	"probe": {"a_lat": 6.0, "top": 0.0, "brake_margin": 0.8, "a_brake": 8.0, "corner_bias": 0.0, "lane": 0.0,
		"wobble_amp": 0.0, "wobble_hz": 0.0, "fault_rate": 0.0},
}

var profile_id: String = "probe"
var profile: Dictionary = PROFILES["probe"]
## Rubber band, written by the coordinator each frame. 1 = the profile.
var speed_scale: float = 1.0
## False until the lights go out: the driver then holds everything at 0.
var released: bool = true
## True while a fault is being driven (for probes and the journal).
var faulting: bool = false
var faults_total: int = 0

var _track: KartTrack = null
var _hint: int = -1
var _vmax: PackedFloat32Array = PackedFloat32Array()
var _lane: float = 0.0
var _lane_goal: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0
var _fault_left: float = 0.0
var _fault_side: float = 1.0
var _noise_walk: float = 0.0

func setup(track: KartTrack, id: String = "probe", seed_value: int = 1) -> void:
	_track = track
	profile_id = id if PROFILES.has(id) else "probe"
	profile = PROFILES[profile_id]
	_rng.seed = seed_value
	_hint = -1
	_lane = float(profile["lane"])
	_lane_goal = _lane
	_time = 0.0
	_fault_left = 0.0
	faulting = false
	faults_total = 0
	speed_scale = 1.0
	_build_profile()

## The speed profile, one v_max per spine sample. Recomputed at every
## setup() because the steering limit reads the LIVE KartTuning preset.
func _build_profile() -> void:
	var n: int = _track.sample_count()
	_vmax.resize(n)
	var top: float = KartBody.MAX_SPEED * lerpf(1.0, KartBody.BOOST_SPEED_RATIO, float(profile["top"]))
	var a_lat: float = float(profile["a_lat"])
	var steer_rate: float = KartTuning.steer_rate()
	for i in n:
		var k: float = maxf(_track.curvature(i), K_FLOOR)
		var v_tyres: float = sqrt(a_lat / k)
		# The body's yaw rate at speed v is steer_rate * (1 - 0.28 v / 13)
		# once above STEER_FULL_SPEED; the curvature it can hold is that
		# over v. Solving rate (1 - e v / M) = k' v for v, k' = k * headroom.
		var e: float = (1.0 - KartBody.STEER_HIGH_SPEED_KEEP) / KartBody.MAX_SPEED
		var v_steer: float = steer_rate / (k * STEER_HEADROOM + steer_rate * e)
		_vmax[i] = minf(top, minf(v_tyres, v_steer))
	# Backward pass, twice round the loop so the wrap is consistent.
	var a_brake: float = float(profile["a_brake"])
	for _pass in 2:
		for j in range(n - 1, -1, -1):
			var i: int = j
			var nxt: int = (i + 1) % n
			var ds: float = _track.sample_s(i + 1) - _track.sample_s(i) if i + 1 < n else _track.length() - _track.sample_s(i)
			var allowed: float = sqrt(_vmax[nxt] * _vmax[nxt] + 2.0 * a_brake * maxf(ds, 0.01))
			_vmax[i] = minf(_vmax[i], allowed)

## The profile at spine sample `i` (for probes and the journal).
func vmax_at(i: int) -> float:
	return _vmax[posmod(i, _vmax.size())] if _vmax.size() > 0 else 0.0

func lane() -> float:
	return _lane

## One frame. `others` is the list of other racers' {kart, s, lateral} on
## the track (the coordinator publishes it once per frame); `delta` is
## the physics step.
func drive(kart: KartBody, input: KartInput, delta: float = 1.0 / 60.0, others: Array = []) -> void:
	if _track == null:
		return
	_time += delta
	if not released:
		input.set_all(0.0, 0.0, false, 0.0)
		return
	var progress: Dictionary = _track.progress_at(kart.global_position, _hint)
	_hint = int(progress["index"])
	var s: float = float(progress["s"])
	var spine_s: float = _track.start_line_offset() + s
	var v: float = kart.speed()
	# ---- the lane: natural line, corner bias, overtake, fault.
	var i: int = _hint
	var k_signed: float = _track.signed_curvature((i + 3) % _track.sample_count())
	# Outside of a bend = the side opposite its sign (right bend, positive
	# curvature: outside is left, negative lateral); corner_bias > 0 goes
	# there, < 0 hugs the inside.
	var goal: float = float(profile["lane"]) - float(profile["corner_bias"]) * k_signed * 10.0
	for o in others:
		var ds: float = fposmod(float(o["s"]) - s, _track.length())
		if ds > 0.2 and ds < OVERTAKE_RANGE and absf(float(o["lateral"]) - _lane) < OVERTAKE_LATERAL:
			# Pass on the side with more room; the boar pushes right.
			var their: float = float(o["lateral"])
			var go_left: bool = their > 0.0
			goal = their + (-OVERTAKE_SHIFT if go_left else OVERTAKE_SHIFT)
			break
	var limit: float = KartTrack.HALF_WIDTH - LANE_MARGIN
	goal = clampf(goal, -limit, limit)
	_tick_fault(delta)
	if faulting:
		goal = _fault_side * (KartTrack.HALF_WIDTH + 1.4)
	_lane = move_toward(_lane, goal, LANE_RATE * delta)
	# ---- the line: pure pursuit on the offset point.
	var lookahead: float = minf(LOOKAHEAD_BASE + LOOKAHEAD_PER_SPEED * absf(v), LOOKAHEAD_MAX)
	var target_s: float = spine_s + lookahead
	var target: Vector3 = _track.point_at(target_s) + _track.side_at(target_s) * _lane
	var to: Vector3 = target - kart.global_position
	var want_yaw: float = atan2(to.x, to.z)
	var err: float = wrapf(want_yaw - kart.rotation.y, -PI, PI)
	# steer > 0 turns RIGHT, i.e. yaw DECREASES (KartBody.drive).
	var steer: float = -err * STEER_GAIN
	var amp: float = float(profile["wobble_amp"])
	if amp > 0.0:
		_noise_walk = clampf(_noise_walk + _rng.randf_range(-1.0, 1.0) * delta * 2.0, -1.0, 1.0)
		steer += amp * (sin(_time * TAU * float(profile["wobble_hz"])) * 0.6 + _noise_walk * 0.4)
	input.steer = clampf(steer, -1.0, 1.0)
	# ---- the speed: read the profile a sample ahead, chase it.
	var v_target: float = _vmax[(i + 1) % _vmax.size()] * speed_scale
	if faulting:
		v_target = maxf(v_target, KartBody.MAX_SPEED)
	var boost: float = clampf((v_target / KartBody.MAX_SPEED - 1.0) / (KartBody.BOOST_SPEED_RATIO - 1.0), 0.0, 1.0)
	var cap: float = KartBody.MAX_SPEED * lerpf(1.0, KartBody.BOOST_SPEED_RATIO, boost)
	var throttle: float = 1.0 if v < v_target - 1.0 else clampf(v_target / cap, 0.0, 1.0)
	var brake: bool = (not faulting) and v > v_target + float(profile["brake_margin"])
	input.set_all(input.steer, throttle, brake, boost)

func _tick_fault(delta: float) -> void:
	if faulting:
		_fault_left -= delta
		if _fault_left <= 0.0:
			faulting = false
		return
	var rate: float = float(profile["fault_rate"])
	if rate <= 0.0:
		return
	if _rng.randf() < rate / 60.0 * delta:
		faulting = true
		faults_total += 1
		_fault_left = FAULT_S
		_fault_side = 1.0 if _rng.randf() < 0.5 else -1.0

## Probes: force a fault now (the blind check that a fault changes the
## drive before "no fault happened" is believed).
func force_fault(side: float = 1.0) -> void:
	faulting = true
	faults_total += 1
	_fault_left = FAULT_S
	_fault_side = signf(side) if side != 0.0 else 1.0
