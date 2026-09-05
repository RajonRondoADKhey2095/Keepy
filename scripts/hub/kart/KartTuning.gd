extends RefCounted
class_name KartTuning
## V7b -- the STEERING FEEL as a runtime-selectable preset, behind
## DevTools.enabled(). One journal lot cannot validate a driving sensation
## from a sandbox capture (CLAUDE.md: "aucune capture ne peut valider une
## sensation de conduite") -- so instead of guessing one number, this ships
## three, switchable live, for Mathieu to compare on a real thumb without
## leaving the kart or reloading the page.
##
## =====================================================================
## WHAT WAS MEASURED BEFORE ANY NUMBER WAS PICKED
##
## Mathieu named two suspects for "10/10, want ~7/10": KartBody.STEER_RATE
## and KartBody.GRIP_ON_TRACK. A frame-by-frame Python replica of drive()
## (journal V7b) showed GRIP is nearly a non-factor for RESPONSIVENESS:
## halving it left peak yaw rate and total heading swing UNCHANGED for the
## same steer input -- grip only governs how long a lateral slide lingers
## after the turn, not how hard the turn hits. It was fixed once, low, for
## every preset below (see KartBody.GRIP_ON_TRACK) rather than tied to the
## 8/7/6 scale.
##
## The real levers are STEER_RATE (the yaw rate at full lock) and the
## TOUCH mapping in KartTouchInput: STEER_SPAN was 150 px (~1 cm on an
## iPhone) with a LINEAR response, so a ~3 mm involuntary thumb wobble
## already commanded ~20 % steer. Widening the span, growing the dead
## zone a little, and reshaping the curve to a power >1 (full lock still
## reachable at full drag, but a small nudge now buys proportionally much
## less) cuts the response to a SMALL correction far more than to a big,
## deliberate one -- which is exactly "less abrupt without going mou".
##
## =====================================================================
## THE THREE PRESETS, on Mathieu's own 1-10 reactivity scale
##
## Simulated ratio of heading swing vs the current (10/10) build, same
## fixed thumb gesture: a 40 px "micro" nudge and a 100 px "deliberate"
## drag, both held 0.25 s. 8/10 -> ~38 %/~53 % of baseline; 7/10 (default)
## -> ~19 %/~36 %; 6/10 -> ~10 %/~23 %. Full-lock authority (a full drag to
## each preset's OWN span) only drops to ~83/~73/~64 % of baseline -- a
## committed turn still turns, it is the accidental wobble that calms down.

const PRESETS: Array[Dictionary] = [
	{"id": "8", "label": "8/10", "steer_rate": 1.75, "steer_span": 190.0, "dead_zone": 14.0, "curve_exp": 1.25},
	{"id": "7", "label": "7/10", "steer_rate": 1.55, "steer_span": 210.0, "dead_zone": 16.0, "curve_exp": 1.4},
	{"id": "6", "label": "6/10", "steer_rate": 1.35, "steer_span": 230.0, "dead_zone": 18.0, "curve_exp": 1.55},
]
## Mathieu's stated target: 7/10. Index into PRESETS, not a preset id.
const DEFAULT_INDEX: int = 1

static var _index: int = DEFAULT_INDEX

static func current() -> Dictionary:
	return PRESETS[_index]

static func index() -> int:
	return _index

static func set_index(i: int) -> void:
	_index = clampi(i, 0, PRESETS.size() - 1)

static func steer_rate() -> float:
	return float(PRESETS[_index]["steer_rate"])

static func steer_span() -> float:
	return float(PRESETS[_index]["steer_span"])

static func dead_zone() -> float:
	return float(PRESETS[_index]["dead_zone"])

static func curve_exp() -> float:
	return float(PRESETS[_index]["curve_exp"])
