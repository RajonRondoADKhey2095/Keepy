extends RefCounted
class_name HumanRefDriver
## CH31 -- THE REFERENCE PLAYER, and the reason the CH30 bench lied.
##
## =====================================================================
## WHY THIS FILE EXISTS
##
## CH30 measured difficulty against a KartAiDriver profile called
## `human_ref`, and derived a "floor" from another one called `limit_ref`.
## Both are the SAME CONTROLLER as the opponents: pure pursuit on the
## spine against a speed profile built with perfect, global, zero-latency
## knowledge of the whole lap. Measured (RaceReconProbe, CH31): that
## reference lapped 24.400 s -- SLOWER than the cat it was meant to
## measure. A bench whose yardstick is the thing it measures cannot see
## that the field is slow, and CH30's tables are green for exactly that
## reason.
##
## A human is not that controller, in ways that cut in BOTH directions:
##
##   WORSE  he sees a few seconds of track, not the whole lap; his thumb
##          arrives late; his aim is noisy; he re-decides a few times a
##          second, not sixty.
##   BETTER he is not held to a per-sample speed profile at all. He
##          carries speed into a bend and lets the kart slide, because
##          this kart is forgiving (GRIP_ON_TRACK 5.0, SCRUB 0.55, a
##          10 u ribbon and a 0.6 u margin): running wide costs pace, not
##          the lap. The AI's profile refuses to do that.
##
## So this model is deliberately NOT a better KartAiDriver. It aims at a
## point ahead and drives at a target speed it picks from what it can
## SEE, with latency and noise on top -- and it is allowed to be wrong,
## which is what makes its lap time a plausible human one instead of an
## optimum.
##
## ⚠️ A SIMULATION WITH PERFECT LATENCY LIES (brief CH31). Latency is not
## decoration here: a pure-pursuit loop is a feedback loop, and delay in
## a feedback loop is what produces the over-correction a real thumb
## produces. A zero-latency run of this same model laps measurably
## quicker and NEVER weaves -- which is why every number this bench
## publishes comes from n >= 300 runs with latency and jitter drawn per
## run, and is published as a DISTRIBUTION, never as one lap.

## How often the model re-decides (Hz). A thumb is not a 60 Hz servo.
const DECISION_HZ: float = 9.0
## Thumb + display latency, seconds: mean and sigma of a per-run draw.
## The band is the usual one for a touchscreen game loop (touch sampling,
## one frame of render, one of display) plus human reaction to what the
## screen already shows.
const LATENCY_MEAN_S: float = 0.135
const LATENCY_SIGMA_S: float = 0.035
const LATENCY_MIN_S: float = 0.060
const LATENCY_MAX_S: float = 0.280
## Gaussian noise on the steer command, per decision (fraction of lock).
const STEER_SIGMA: float = 0.085
## Gaussian noise on where he thinks the apex is (u), per decision.
const AIM_SIGMA_U: float = 0.55
## How far ahead he reads the track, in seconds of travel.
const PREVIEW_S: float = 1.15
const PREVIEW_MIN_U: float = 6.0
## Steer gain per radian of heading error -- the same pure pursuit the
## opponents use, so the DIFFERENCE between the two is the model, not
## the controller.
const STEER_GAIN: float = 1.0 / 0.55
## Lookahead, u.
const LOOKAHEAD_BASE: float = 4.2
const LOOKAHEAD_PER_SPEED: float = 0.34
const LOOKAHEAD_MAX: float = 10.0
## The lateral acceleration he is willing to carry, at skill 1.0. Higher
## than any opponent's on purpose: he is not obeying a profile, he is
## leaning on a forgiving kart.
const A_LAT_AT_FULL_SKILL: float = 11.0
const A_LAT_AT_ZERO_SKILL: float = 5.5
## How hard he brakes when the preview says he is too quick (u/s2).
const A_BRAKE: float = 12.0
## Speed over his target before he actually touches the brake.
const BRAKE_MARGIN: float = 1.4
## The lane he settles on: a hint of the inside of a bend, like anyone.
const CORNER_BIAS: float = -0.8
const LANE_MARGIN: float = 0.9

## 0..1. 1.0 = a clean quick drive; 0.5 = an ordinary one.
var skill: float = 1.0
## Whether he uses the accelerator at all. ⚠️ FALSE is the case that
## matters: Mathieu's retour is that he cannot find the boost, so the
## band that describes HIM today is the one measured with this off.
var uses_boost: bool = true
var released: bool = true

var _track: KartTrack = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hint: int = -1
var _latency_s: float = LATENCY_MEAN_S
## The command pipeline: {t, steer, throttle, brake, boost} in issue order.
var _queue: Array = []
var _clock: float = 0.0
var _next_decision: float = 0.0
var _held: Dictionary = {"steer": 0.0, "throttle": 1.0, "brake": false, "boost": 0.0}
var _lane: float = 0.0

func setup(track: KartTrack, seed_value: int, skill_value: float = 1.0, boost: bool = true) -> void:
	_track = track
	_rng.seed = seed_value
	skill = clampf(skill_value, 0.0, 1.0)
	uses_boost = boost
	_hint = -1
	_clock = 0.0
	_next_decision = 0.0
	_queue.clear()
	_held = {"steer": 0.0, "throttle": 1.0, "brake": false, "boost": 0.0}
	_lane = 0.0
	# One latency per RUN, not per frame: a player's lag is a property of
	# his hands and his phone, and re-drawing it every frame would average
	# it away -- which is precisely how a bench stops seeing latency.
	_latency_s = clampf(_rng.randfn(LATENCY_MEAN_S, LATENCY_SIGMA_S), LATENCY_MIN_S, LATENCY_MAX_S)

func latency_s() -> float:
	return _latency_s

## The lateral acceleration this skill carries.
func a_lat() -> float:
	return lerpf(A_LAT_AT_ZERO_SKILL, A_LAT_AT_FULL_SKILL, skill)

## One physics step. Same signature shape as KartAiDriver.drive so the
## bench can swap one for the other.
func drive(kart: KartBody, input: KartInput, delta: float = 1.0 / 60.0) -> void:
	if _track == null:
		return
	_clock += delta
	if not released:
		input.set_all(0.0, 0.0, false, 0.0)
		return
	if _clock >= _next_decision:
		_next_decision = _clock + 1.0 / DECISION_HZ
		_queue.append(_decide(kart))
	# Deliver whatever is old enough. A command issued at t arrives at
	# t + latency; until the first one arrives he is holding the wheel
	# straight with the throttle on, which is what a player does.
	while _queue.size() > 0 and float(_queue[0]["t"]) + _latency_s <= _clock:
		_held = _queue.pop_front()
	input.set_all(float(_held["steer"]), float(_held["throttle"]), bool(_held["brake"]), float(_held["boost"]))

## What he decides to do, from what he can see right now.
func _decide(kart: KartBody) -> Dictionary:
	var progress: Dictionary = _track.progress_at(kart.global_position, _hint)
	_hint = int(progress["index"])
	var s: float = float(progress["s"])
	var spine_s: float = _track.start_line_offset() + s
	var v: float = kart.speed()
	# ---- the lane he wants: inside the bend he can see, noisily.
	var n: int = _track.sample_count()
	var k_signed: float = _track.signed_curvature((_hint + 4) % n)
	var limit: float = KartTrack.HALF_WIDTH - LANE_MARGIN
	var want: float = clampf(CORNER_BIAS * k_signed * 10.0 + _rng.randfn(0.0, AIM_SIGMA_U), -limit, limit)
	_lane = lerpf(_lane, want, 0.45)
	# ---- steering: pure pursuit at a lookahead point on that lane.
	var lookahead: float = minf(LOOKAHEAD_BASE + LOOKAHEAD_PER_SPEED * absf(v), LOOKAHEAD_MAX)
	var target_s: float = spine_s + lookahead
	var target: Vector3 = _track.point_at(target_s) + _track.side_at(target_s) * _lane
	var to: Vector3 = target - kart.global_position
	var err: float = wrapf(atan2(to.x, to.z) - kart.rotation.y, -PI, PI)
	var steer: float = clampf(-err * STEER_GAIN + _rng.randfn(0.0, STEER_SIGMA), -1.0, 1.0)
	# ---- speed: the WORST curvature inside his preview window, and what
	# that allows him to carry. No backward pass over the lap -- he cannot
	# see round the omega from the straight, and that is the point.
	var horizon: float = maxf(PREVIEW_MIN_U, absf(v) * PREVIEW_S)
	var walked: float = 0.0
	var i: int = _hint
	var k_worst: float = KartAiDriver.K_FLOOR
	while walked < horizon:
		i = (i + 1) % n
		var ds: float = _track.sample_s(i + 1) - _track.sample_s(i) if i + 1 < n else _track.length() - _track.sample_s(i)
		walked += maxf(ds, 0.05)
		k_worst = maxf(k_worst, _track.curvature(i))
	var v_bend: float = sqrt(a_lat() / k_worst)
	# Braking distance to that bend, the one piece of arithmetic a driver
	# really does do: if he cannot slow to v_bend in `horizon`, he is
	# already too fast.
	var v_allowed: float = sqrt(maxf(v_bend * v_bend + 2.0 * A_BRAKE * horizon, 0.0))
	var cruise: float = KartBody.MAX_SPEED
	var ceiling: float = KartBody.MAX_SPEED * KartBody.BOOST_SPEED_RATIO if uses_boost else cruise
	var v_target: float = minf(ceiling, v_allowed)
	var boost: float = 0.0
	if uses_boost and v_target > cruise:
		boost = clampf((v_target / cruise - 1.0) / (KartBody.BOOST_SPEED_RATIO - 1.0), 0.0, 1.0)
	var cap: float = cruise * lerpf(1.0, KartBody.BOOST_SPEED_RATIO, boost)
	var throttle: float = 1.0 if v < v_target - 1.0 else clampf(v_target / maxf(cap, 0.01), 0.0, 1.0)
	var brake: bool = v > v_target + BRAKE_MARGIN
	return {"t": _clock, "steer": steer, "throttle": throttle, "brake": brake, "boost": boost}
