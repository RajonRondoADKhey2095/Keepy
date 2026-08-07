extends RefCounted
class_name DevSeed
## Dev-only helper: OPT-IN deterministic seeding of the global RNG for the
## probes in this folder.
##
## WHY THIS EXISTS -- the probes here (PacingAudit, LaneFillAudit,
## AntiFrustrationAudit, RushFrustrationAudit) all measure a REAL run, and
## a real run draws from the global RNG constantly (obstacle type, lane,
## rush durations, the roaming bot). Unseeded, that is exactly what makes
## them useful as EXPLORATORY probes: every invocation samples a different
## run, so a rare violation eventually surfaces.
##
## It also makes them useless for one specific job: proving that a
## refactor changed NOTHING. "The mean gap moved from 1.628s to 1.641s"
## is unreadable when the run itself was different -- the only honest
## before/after comparison is the SAME run, both times.
##
## So seeding is OPT-IN, never the default: pass `--seed=<int>` AFTER a
## bare `--` on the command line, which Godot hands through verbatim as
## user args (OS.get_cmdline_user_args()) without trying to interpret it
## as an engine flag:
##
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/PacingAudit.tscn -- --seed=20260806
##
## Without the flag every probe keeps its pre-existing exploratory
## behaviour, byte-for-byte -- apply() returns false and touches nothing.
##
## SCOPE OF THE DETERMINISM: apply() must be called at the very TOP of a
## probe's _ready(), BEFORE the probe instantiates Game.tscn -- the
## track's very first segments are populated inside TrackManager._ready(),
## i.e. during that add_child(), so a seed set afterwards would already
## have missed the first 7 rows.

## Seeds the global RNG from a `--seed=<int>` user arg if one was passed.
## Returns true if a seed was applied (the caller prints it, so a probe's
## output always states whether it was a reproducible or an exploratory
## run -- never leaving the reader to guess which one they are reading).
static func apply() -> bool:
	var value := seed_value()
	if value == 0:
		return false
	seed(value)
	return true

## The requested seed, or 0 when none was passed. Split out of apply() so
## a probe can print the actual value it ran with rather than just "seeded".
## 0 doubles as "absent" deliberately: a caller wanting determinism can
## pass any other integer, and "seed 0" carrying no special meaning is
## cheaper than a second sentinel to plumb through.
static func seed_value() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.substr("--seed=".length()))
	return 0
