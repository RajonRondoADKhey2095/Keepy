extends RefCounted
class_name DecorRng
## Factory for the PURELY VISUAL random streams -- background hills, ground
## tint drift, trackside props. One place, so the rule they all obey is
## stated once instead of re-argued in three headers.
##
## THE RULE: decor never draws from the global randf() stream.
##
## That stream is the one TrackManager's spawn rolls draw from, and the one
## dev probes call the global seed() against for reproducible runs (see
## scripts/dev/DevSeed.gd). A single decor draw on it shifts every gameplay
## roll that follows by one step -- silent, with no probability anywhere
## having changed, and exactly the "decor deciding which hazards spawn"
## the brief rules out. Each caller therefore gets its OWN
## RandomNumberGenerator instance from here, and nothing in this file ever
## touches the global stream. That separation is the load-bearing property;
## seeding, below, must not cost it.
##
## WHY SEEDING WAS ADDED (F10, see docs/PROBE_AUDIT.md).
##
## Unseeded, these three streams take their state from OS entropy at
## construction, so the decor behind the HUD differed on every invocation.
## The pixel-sampling contrast probes measure HUD text against exactly that
## background, which made their verdicts run-to-run coin flips:
## StrikeFatalContrastAudit read 2.87 / 2.86 / 2.98 against a 3.0 floor on
## three runs of identical code, and on a fourth flipped WHICH palettes it
## reported as failing. A probe whose answer changes when nothing changed
## cannot be a regression guard.
##
## SEEDING IS OPT-IN AND PROBE-DRIVEN, not a new default. force_seed() is
## called by the probes that need a fixed background, before they
## instantiate Game.tscn; the shipped game never calls it, so its decor is
## entropy-driven exactly as before -- byte-identical behaviour, no loss of
## visual variety between play sessions.
##
## It is deliberately NOT wired to DevSeed's `--seed=` command-line flag.
## DevSeed lives under scripts/dev/, which export_presets.cfg excludes from
## the build, so shipped code cannot reference it at all; and a probe that
## depended on the caller remembering a flag would be reproducible only
## when someone remembered -- the precise failure mode F6 was.

## Base seed for the decor streams, or 0 for "not forced" (entropy).
## 0 doubles as the absent value on purpose, the same convention and for
## the same reason as DevSeed.seed_value().
static var _forced_seed: int = 0

## How many streams have been handed out. Each gets a different derived
## seed, so two streams created from the same base are not clones of one
## another -- without this every TrackSegment would roll an identical tint
## and identical props, which is a visual change, not determinism.
##
## Salting BY CREATION ORDER rather than by any property of the caller is
## what keeps this file free of knowledge about its callers. Construction
## order is deterministic (scene instantiation and TrackManager's segment
## loop both are), so the same run yields the same assignment every time.
## The corollary is worth knowing before adding a call site: inserting one
## re-numbers every stream created after it.
static var _streams_handed_out: int = 0

## Odd 32-bit constant (2^32 / phi, the usual Fibonacci-hashing multiplier)
## so consecutive stream indices land far apart in seed space rather than
## adjacent, which correlated PCG states would otherwise show as visibly
## similar decor on neighbouring segments.
const _STREAM_STRIDE: int = 0x9E3779B1

## Pins the decor streams to a reproducible sequence. MUST be called before
## the caller instantiates Game.tscn: the first TrackSegments are built
## inside TrackManager._ready(), i.e. during that add_child(), so a seed set
## afterwards has already missed them. Same constraint, same reason, as
## DevSeed.apply()'s.
static func force_seed(base: int) -> void:
	_forced_seed = base
	_streams_handed_out = 0

## A fresh stream: reproducible if force_seed() was called, OS entropy
## otherwise.
static func make() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var index := _streams_handed_out
	_streams_handed_out += 1
	if _forced_seed == 0:
		rng.randomize()
	else:
		rng.seed = _forced_seed + (index + 1) * _STREAM_STRIDE
	return rng
