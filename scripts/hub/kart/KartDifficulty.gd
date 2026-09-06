extends RefCounted
class_name KartDifficulty
## CH30 -- HOW HARD THE OPPONENTS RACE, as a runtime-selectable preset
## behind DevTools.enabled(). Same shape as KartTuning (V7b, the 8/7/6
## steering presets Mathieu compared on his own thumb): one axis, three
## points, switchable live from the kart HUD without leaving the race.
##
## =====================================================================
## WHY A MULTIPLIER SET AND NOT THREE COPIES OF PROFILES
##
## KartAiDriver.PROFILES holds the PERSONALITIES -- the cat is quick in
## the bends and slow on the straight, the boar boosts and runs wide.
## Difficulty must not flatten that: three hand-written copies of the
## table would drift apart the first time one personality is retuned, and
## the thing Mathieu validated ("on les distingue en REGARDANT") would be
## the first casualty. So this file scales, it does not replace: the
## personality stays in PROFILES, the pace comes from here, and a change
## to either is visible in the other's terms.
##
## =====================================================================
## CH31 -- THE SCALE WAS REBUILT, NOT SHIFTED, AND HERE IS WHY
##
## CH30 calibrated this table against a "floor" of 21.633 s, described as
## the fastest lap this vehicle can physically turn here. It was not.
## RaceReconProbe (CH31) took the three hypotheses of the brief in turn:
##
##   (c) REFUTED. The bench loads the live HubWorld.tscn, circuit_1,
##       230.711 u, the same four entries with the same profiles.
##   (b) REFUTED. The same opponent alone and in the pack differs by at
##       most 0.117 s of best lap, and the leash by at most 0.13 s.
##   (a) CONFIRMED, and it was a yardstick problem. CH30's reference
##       player and its "floor" were BOTH KartAiDriver profiles -- the
##       same controller as the opponents, with the same spine-built
##       speed profile. Its reference lapped 24.400 s, SLOWER than the
##       cat it was measuring. A bench cannot see that a field is slow
##       when its yardstick is a member of that field.
##
## Two things were repaired before a single number below was touched:
##
##   1. THE CEILING. KartAiDriver built its speed profile on the SPINE's
##      curvature while driving a line up to 3.9 u off it, so at the omega
##      every driver was pinned to 4.17 u/s. It is now built on the
##      curvature and the arc length of the line actually planned.
##   2. THE YARDSTICK. HumanRefDriver (scripts/dev) replaces the
##      `human_ref` profile: limited preview, gaussian aim and steer
##      noise, a thumb latency drawn per run, and NO global speed profile
##      -- a model that can be wrong, measured over n >= 300 runs and
##      published as a distribution.
##
## The scale below is written against THAT reference, and its levers are
## the ones RaceReconProbe measured to move a lap time.
##
## =====================================================================
## WHAT EACH LEVER BUYS -- and PACE and AGGRESSION are separate on purpose
##
##   pace       CH31, and it is the DOMINANT one: a straight multiplier on
##              the finished speed profile. Measured by DRIVING (the pace
##              sweep, RaceReconProbe phase B): the same driver holds the
##              ribbon up to about x1.6 and runs wide at x1.8 -- a lever
##              with a measured ceiling rather than a guess.
##   headroom   how much steering authority the driver keeps in hand at
##              its profile speed. Lower = later, tighter, more committed.
##              AGGRESSION, not pace.
##   bias       multiplies the personality's corner_bias: a tighter line
##              through a bend. Aggression, and it changes what a player
##              SEES, not only what the clock says.
##   a_brake    the deceleration the backward pass assumes: higher = on
##              the power later into a bend. Aggression.
##   a_lat      the lateral acceleration accepted in a bend. It SATURATES
##              (below) and is now a minor lever.
##   top        how much of the boost the driver holds where the profile
##              allows it.
##   wobble     steer noise. Lower = a tidier line, worth real time
##              because a wobble scrubs speed through SCRUB.
##   faults     the Poisson trip onto the grass. Lower = fewer gifts.
##
## The rubber band's bounds are here too, and they move in ONE direction
## as difficulty rises (CH30, unchanged): the LEASH on a leading opponent
## is released (rubber_min -> 1.0) so an AI in front is never held back,
## while the tow on a trailing one is let out further (rubber_max).
## MEASURED INERT twice -- CH30, and again in CH31 phase D at <= 0.13 s of
## finish over a 75 s race. It is kept honest, and it is NOT sold as a
## lever: the brief asked for that to be said plainly rather than dressed
## up, and this is it.
##
## ⚠️ a_lat SATURATES. At the omega the binding limit is the STEERING,
## not the tyres, so above a_lat ~= 5.1 the tightest bend stops caring.
## Scaling it hard flattens the personalities without buying a lap --
## measured in CH30, still true, and it is why `pace` exists.

## THE THREE PRESETS, and every number is measured (RaceBalanceProbe).
##
## ⚠️ `top` CARRIES THE BIGGEST SCALE, and that is not a taste: `top` is a
## HARD CAP applied after everything else (KartAiDriver._build_profile
## takes min(top, ...)), so a personality with a low `top` cannot be made
## quicker by any amount of `pace`. Measured, and it is what killed the
## first CH31 table: the cat's base top is 0.35, so taking pace from 1.20
## to 1.38 moved its lap by -0.05 s -- nothing, because it was pinned at
## its cap the whole way. The scale below lifts the CAP first and the
## corner speed second, which is the order the arithmetic imposes.
const PRESETS: Array[Dictionary] = [
	{"id": "x1", "label": "x1",
		"pace": 1.05, "headroom": 1.00, "bias": 1.00,
		"a_lat": 1.00, "top": 1.00, "a_brake": 1.00, "wobble": 1.00, "fault": 1.00,
		"rubber_min": 0.93, "rubber_max": 1.05},
	{"id": "x15", "label": "x1.5",
		"pace": 1.30, "headroom": 0.96, "bias": 1.05,
		"a_lat": 1.12, "top": 1.60, "a_brake": 1.12, "wobble": 0.72, "fault": 0.55,
		"rubber_min": 0.97, "rubber_max": 1.08},
	# ⚠️ x2.5 WAS PULLED BACK from pace 1.55 / headroom 0.92 / top 2.30, and
	# the reason is a gate rather than a taste: at those numbers the cat
	# turned an 18.467 s lap while spending 131 frames (2.2 s) OFF THE
	# RIBBON. An opponent that beats the circuit's driven floor by driving
	# on the grass is not a harder opponent, it is a broken one -- it reads
	# as cheating on device and it is invisible in a lap time. D6 now
	# asserts it, and these numbers are what keeps it green.
	{"id": "x25", "label": "x2.5",
		"pace": 1.45, "headroom": 0.95, "bias": 1.10,
		"a_lat": 1.22, "top": 2.10, "a_brake": 1.25, "wobble": 0.55, "fault": 0.35,
		"rubber_min": 1.00, "rubber_max": 1.11},
]
## Mathieu's stated target: the median. Index into PRESETS, not an id.
const DEFAULT_INDEX: int = 1

static var _index: int = DEFAULT_INDEX

static func current() -> Dictionary:
	return PRESETS[_index]

static func index() -> int:
	return _index

static func set_index(i: int) -> void:
	_index = clampi(i, 0, PRESETS.size() - 1)

static func set_id(id: String) -> void:
	for i in PRESETS.size():
		if String(PRESETS[i]["id"]) == id:
			_index = i
			return

static func scale_of(key: String) -> float:
	return float(PRESETS[_index].get(key, 1.0))

static func rubber_min() -> float:
	return float(PRESETS[_index]["rubber_min"])

static func rubber_max() -> float:
	return float(PRESETS[_index]["rubber_max"])

## The personality of `base` raced at the current difficulty. `top` is a
## 0..1 fraction, so it is CLAMPED after scaling rather than left to run
## past full boost; `headroom` is scaled DOWN by aggression and floored at
## 1.0 (below 1 the profile would claim steering the body does not have);
## every other lever is a plain multiplier.
static func apply(base: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	out["a_lat"] = float(base["a_lat"]) * scale_of("a_lat")
	out["top"] = clampf(float(base["top"]) * scale_of("top"), 0.0, 1.0)
	out["a_brake"] = float(base["a_brake"]) * scale_of("a_brake")
	out["wobble_amp"] = float(base["wobble_amp"]) * scale_of("wobble")
	out["fault_rate"] = float(base["fault_rate"]) * scale_of("fault")
	out["corner_bias"] = float(base["corner_bias"]) * scale_of("bias")
	out["pace"] = float(base.get("pace", 1.0)) * scale_of("pace")
	out["headroom"] = maxf(float(base.get("headroom", KartAiDriver.STEER_HEADROOM)) * scale_of("headroom"), 1.0)
	return out
