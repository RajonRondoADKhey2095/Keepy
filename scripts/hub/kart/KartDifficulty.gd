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
## WHAT EACH LEVER ACTUALLY BUYS -- MEASURED, see docs/lots/CH30_*.md
##
##   a_lat      the lateral acceleration a driver accepts in a bend. It is
##              the DOMINANT lever on this circuit: the omega's 3.40 u
##              minimum radius means most of the lap is curvature-limited,
##              not power-limited, so sqrt(a_lat / k) is what sets the lap.
##   top        how much of the 0..1 boost the driver holds where the
##              profile allows it: raises the cap toward BOOST_MAX_SPEED
##              (16.5 u/s) on the straights only. Second lever, and the
##              one that shows on the long straight where a player watches
##              the mirrors.
##   a_brake    the deceleration the backward pass assumes. Higher = the
##              driver stays on the power later before a bend.
##   wobble     steer noise. Lower = a tidier line, which is worth real
##              time because a wobble scrubs speed through SCRUB.
##   faults     the Poisson trip onto the grass. Lower = fewer gifts.
##
## The rubber band's bounds are here too, and they move in ONE direction
## as difficulty rises (brief, CH30): the LEASH on a leading opponent is
## released (rubber_min -> 1.0, an AI that leads is never held back so it
## can never read as "waiting"), while the tow on a trailing one is let
## out further (rubber_max). Assistance to the player is not a lever this
## file has.

## THE SCALE, AND WHAT ITS NUMBERS MEAN
##
## Named for what each one does to ADVERSITY, on Mathieu's own words
## ("environ x1,5"). "Adversity xN" is written here as something that can
## be measured and can fail: an opponent's DEFICIT is its best lap minus
## THE FLOOR -- the fastest lap this vehicle can physically turn on this
## circuit, measured with a driver whose tyres never give up
## (KartAiDriver's `limit_ref`, 21.633 s) -- and preset xN divides that
## deficit by N. It is a ratio against a fixed measured quantity rather
## than against a guess at how fast Mathieu drives, which is the only
## kind of denominator a sandbox can honestly supply.
##
## CALIBRATION (RaceBalanceProbe, seed 20260905, three laps, rubber band
## on, KartTuning preset 7/10; every number below is measured, not aimed):
##
##   floor (limit_ref)         21.633 s per lap
##   x1    best opponent lap   24.350 s   deficit 2.717 s   -- staging
##   x1.5  best opponent lap   ~23.44 s   deficit ~1.81 s   -- the default
##   x2.5  best opponent lap   ~22.72 s   deficit ~1.09 s
##
## ⚠️ THE SCALE IS COMPRESSIVE AT THE TOP, and the third preset is named
## x2.5 rather than x2 because of it. The floor is only 2.7 s away at x1,
## so every further step buys less: an x2 preset would sit 0.45 s per lap
## from x1.5 -- inside the run-to-run spread of a field that still makes
## mistakes, and not something a thumb can feel. x2.5 is ~0.7 s per lap
## clear of the default, about two seconds over a three-lap race, which
## is a difference rather than a rounding.
##
## ⚠️ AND a_lat SATURATES, which is why `top` carries most of each step.
## At the omega the binding limit is the STEERING, not the tyres
## (v_steer = 4.17 u/s at the 7/10 preset), so above a_lat ~= 5.1 the
## tightest bend stops caring -- the cat is ALREADY steering-limited
## there at x1. Scaling a_lat therefore buys time in the MEDIUM bends
## only, and scaling it hard flattens the personalities at the omega
## without buying a lap. Measured, and it is what killed the first
## version of this table.
const PRESETS: Array[Dictionary] = [
	{"id": "x1", "label": "x1",
		"a_lat": 1.00, "top": 1.00, "a_brake": 1.00, "wobble": 1.00, "fault": 1.00,
		"rubber_min": 0.93, "rubber_max": 1.05},
	{"id": "x15", "label": "x1.5",
		"a_lat": 1.12, "top": 1.25, "a_brake": 1.08, "wobble": 0.83, "fault": 0.75,
		"rubber_min": 0.97, "rubber_max": 1.08},
	{"id": "x25", "label": "x2.5",
		"a_lat": 1.22, "top": 1.46, "a_brake": 1.15, "wobble": 0.69, "fault": 0.54,
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
## past full boost; every other lever is a plain multiplier.
static func apply(base: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	out["a_lat"] = float(base["a_lat"]) * scale_of("a_lat")
	out["top"] = clampf(float(base["top"]) * scale_of("top"), 0.0, 1.0)
	out["a_brake"] = float(base["a_brake"]) * scale_of("a_brake")
	out["wobble_amp"] = float(base["wobble_amp"]) * scale_of("wobble")
	out["fault_rate"] = float(base["fault_rate"]) * scale_of("fault")
	return out
