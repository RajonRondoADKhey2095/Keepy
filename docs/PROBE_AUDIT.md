# Probe audit -- what each probe in `scripts/dev/` actually verifies

Recon carried out before the stabilisation batch that this document is the
first commit of. Nothing here is inferred from a probe's own header: every
"can this bot meet this mechanic" answer below is either read off the bot's
decision code or measured by running the probe.

Written because a pattern had become undeniable: **a probe written before a
mechanic existed validates a contract it is structurally incapable of
testing, and keeps reporting green while doing it.** Four such false greens
had already been found and fixed one at a time. This audit looks for the
rest of them at once, and the batch it opens then removes the conditions
that produce them.

## The mechanic timeline

Every probe is judged against this. A probe predating a row cannot have
been written with it in mind.

| Mechanic | Introduced | Commit |
|---|---|---|
| DODGE / JUMP / ENEMY | project start | 2026-08-05 |
| AIR_ENEMY (aerial, then landing) | 2026-08-05 | `b72b163`, `95c0ffd` |
| RISK events + COMBO chain | 2026-08-06 | `9c7c365`, `0098712` |
| CHARGER (own closing speed, unjumpable) | 2026-08-06 | `baae0a4` |
| STOMPER (jump is the ONLY escape) | 2026-08-06 | `dc57922` |
| PURSUER (lead, visibility, capture) | 2026-08-06 | `e0c69dc`, `82f3a4b` |
| pursuer visibility retune + INTERMEDIATE bot | 2026-08-07 | `60fb00d`, `d3e489a` |
| STRIKES -- DODGE/JUMP become NON-FATAL | 2026-08-07 | `c0ed19e`, `96d40f3`, `6bc4464` |
| TRACK SHRINK (a lane can be shut) | 2026-08-07 | `d40fc61`, `c96a308` |
| ModelSlot / Hitboxes split | 2026-08-08 | `5856737`, `ab2d247` |

## The table

`ok` = the bot can meet and correctly answer the mechanic. `blind` = the bot
meets it and answers wrongly. `n/a` = the probe has no bot, or neuters
collision so the mechanic cannot affect its measurement. Assertion column:
**invariant** = an ordering or a structural guarantee; **absolute** = a
hard-coded numeric threshold calibrated on exploratory runs.

| Probe | Contract, in one sentence | Written | Mechanics added since | CHARGER | STOMPER | pursuer | strikes | shrink | Assertions |
|---|---|---|---|---|---|---|---|---|---|
| **AntiFrustrationAudit** | Every imminent threat leaves at least one escape, re-derived per physics frame | 08-05 | risk/combo, CHARGER, STOMPER, pursuer, strikes, shrink | ok | partial | n/a | n/a | ok (`e5647ee`) | invariant (0 violations) |
| **RushFrustrationAudit** | Same guarantee, restricted to rush windows | 08-06 | STOMPER, pursuer, strikes, shrink | ok | partial | n/a | n/a | ok (`e5647ee`) | invariant (0 violations) |
| **ComboAudit** | Risky play must pay meaningfully better than safe play | 08-06 | STOMPER, pursuer, strikes, shrink | ok | **blind (F1)** | n/a | n/a | ok (`084a074`) | **absolute** x4 |
| **PursuerAudit** | The pursuer reads how the player plays, and a mid-skill player meets it | 08-06 | strikes, shrink | ok | ok (`d3e489a`) | ok | n/a | ok (`084a074`) | invariant x5 + **absolute** x2 |
| **StrikeAudit** | What each skill profile actually dies of, under the strike model | 08-07 | shrink | ok | ok | ok | ok | ok (`084a074`) | invariant x6 + **absolute** x2 |
| **ShrinkAudit** | The shrink is reachable in real play, and is never unfair when it fires | 08-07 | -- | ok | **blind, SAFE only (F5)** | ok | ok | ok | invariant |
| **PursuerFramingAudit** | The pursuer never eats the screen | 08-07 | -- | ok | ok | ok | ok | ok | absolute (a design cap, legitimately) |
| **StomperAudit** | Jump is the only escape from a STOMPER | 08-06 | strikes, shrink | n/a (neutered) | ok | n/a | n/a | n/a | invariant |
| **StomperConflictAudit** | A STOMPER and a jump-blocker never come due together | 08-06 | strikes, shrink | ok | ok | n/a | n/a | n/a | invariant |
| **ChargerAudit** | The charger's reaction window and spacing hold at every palier | 08-06 | STOMPER, pursuer, strikes, shrink | ok | n/a | n/a | n/a | n/a | invariant |
| **AirHazardAudit** | A landed AIR_ENEMY is lethal if ignored, safe if jumped | 08-05 | everything after 08-05 | n/a (neutered) | n/a (neutered) | n/a | n/a | n/a | invariant |
| **AirEnemyLandingLaneAudit** | AIR_ENEMY's landing lane distribution is fair | 08-06 | STOMPER, pursuer, strikes, shrink | n/a | n/a | n/a | n/a | n/a | distribution only |
| **EnemyLaneAudit** | An ENEMY's locked lane and its contact lane agree | 08-05 | everything after 08-05 | n/a | n/a | n/a | n/a | n/a | invariant |
| **JumpDodgeRewardAudit** | A timed jump over a JUMP credits the reward exactly once | 08-06 | STOMPER, pursuer, strikes, shrink | n/a | n/a | n/a | n/a | n/a | invariant (exact equality) |
| **LaneFillAudit** | The early game does not use the full track width | 08-06 | STOMPER, pursuer, strikes, shrink | n/a | n/a | n/a | n/a | n/a | distribution only |
| **PacingAudit** | Palier timings, spacing and the enemy lock, measured not re-read | 08-05 | everything after 08-05 | ok | n/a | n/a | n/a | n/a | invariant |
| **AssetContractAudit** | A mesh swap changes every visual and moves no collider | 08-08 | -- | n/a | n/a | n/a | n/a | n/a | invariant (exact equality) |
| **ChargerShapeProbe** | The charger wedge is oriented and grounded as designed | 08-06 | -- | n/a | n/a | n/a | n/a | n/a | invariant |
| **DarkPaletteAudit** | Every hazard stays legible against the ground on every palette | 08-06 | STOMPER (`5c2b3fb`), shrink (`ec1836a`) | **broken sampling** | **broken sampling** | n/a | n/a | ok | absolute (a contrast floor, legitimately) |
| **ComboContrastAudit** / **StrikeContrastAudit** / **StrikeFatalContrastAudit** / **PursuerContrastAudit** | The HUD reads against its real background on every palette | 08-06/07 | -- | n/a | n/a | n/a | n/a | n/a | absolute (a contrast floor, legitimately) |
| **InvertCapture** / **PacingProbe** / **LiveRunProbe** | Diagnostic printers, no verdict | 08-05 | -- | n/a | n/a | n/a | n/a | n/a | none |

## Findings

### F1 -- ComboAudit is a false green, and its headline number is an artifact

`ComboAudit._drive_safe_bot` **has no jump branch at all** and no reference
to `Obstacle.blocks_lane_switch`. Against a STOMPER -- which a lane switch
can never escape, and which is fatal -- it is dead by construction.

This is the identical defect fixed in `PursuerAudit` by `d3e489a` ("fix
SAFE's STOMPER blind spot"). The fix was carried into `StrikeAudit` and
`PursuerFramingAudit`, whose `_drive_safe_bot` are otherwise
character-for-character the same function. ComboAudit was left behind.

Measured, seed 20260806:

```
SAFE  : 11 runs, 28.0s each, risk events 1.6/min, jump-dodge 0, near-miss 0
        score at t=40s : 0      (over 0 runs that reached it)
RISKY :  3 runs, 119.3s each
PASSED: ... "+124500% on the scoreboard at a matched run duration."
```

The SAFE bot never survives to the 40s checkpoint, so the "matched
duration" comparison divides by a score of zero and prints `+124500%`. The
probe's central claim -- that risky play pays better -- is being measured
against a bot that is not playing safe, it is dying. **The probe reports
PASSED.**

### F2 -- PursuerAudit's mid-skill criterion is noise, not a measurement

`INTERMEDIATE_VISIBLE_FRAC_MIN/MAX = 0.10 .. 0.25` is asserted against a
sample of **1 to 3 runs**. Measured across 8 seeds:

| seed | 1 | 7 | 42 | 101 | 2026 | 20260806 | 314159 | 777 |
|---|---|---|---|---|---|---|---|---|
| mid visible % | 13.3 | 8.9 | **31.5** | 5.5 | 4.7 | 4.6 | 15.5 | **0.7** |

A statistic ranging 0.7%-31.5% cannot be gated on a 10%-25% band. 6 of 8
seeds fail. This is not a finding about the game; it is a measurement with
no resolution.

What DOES hold on all 8 seeds, with large margins:

- `mean_lead(SAFE)` 6.0-8.5s < `mean_lead(MID)` and `< mean_lead(RISKY)`, both 10.7-13.5s
- `visible(SAFE)` 61-91% > `visible(MID)` and `> visible(RISKY)`, both under 32%
- SAFE is caught every seed; RISKY is caught on 1 of 8
- the zero-risk floor is **53.0s on every seed** (it is arithmetic, not sampling)

What does NOT hold, and is a real finding rather than a sampling problem:
**MID and RISKY are not separable from each other.** `mean_lead(MID) >
mean_lead(RISKY)` on 4 of the 8 seeds. The pursuer separates passive play
from active play; it does not grade active play by degree.

### F3 -- StrikeAudit asserts a rare stochastic event as an absolute

Two of its criteria are absolute where the underlying quantity is noisy:

- `control["strikes"] != 0` fails the whole probe. The CONTROL bot takes
  exactly 1 strike (a DODGE) on 3 of 8 seeds. The premise the probe rests
  on is not "the infallible bot is literally infallible" but "the injected
  miss chance dominates the bot's own baseline lapses" -- which is a
  separation, not a zero.
- `RISKY_CAPTURE_SHARE_MAX = 0.25` against risky shares measured at
  22/10/0/8/25/**36**/14/20 %.

Its ordering criterion `safe > mid > risky` splits: `safe > mid` holds on
**8 of 8** seeds with wide margins (50-100% vs 13-50%); `mid > risky` holds
on **5 of 8**. Same finding as F2, reached independently: the safe/active
split is real, the mid/risky gradient is not resolvable at this sample size.

### F4 -- DarkPaletteAudit measures nothing for 26 of its samples, and scores them as passes

Reproduced exactly (26 samples of `(0, 0, 0, 1)`), and traced to two
independent defects:

1. **The obstacle walks out of frame and is never re-posed.** The canonical
   pass sets `GameState.state = PLAYING` so it drives the real
   `DarkModeEffect`. That also lets `Obstacle._physics_process` run, and
   `Type.CHARGER`'s `_process_charger` translates the node on +Z every
   visible frame. The single shared `_obstacle` node is positioned once at
   scene build and **never reset between measurements**, so from the first
   CHARGER measurement onward it drifts toward the camera and past it.
   Instrumented, the sample point goes
   `y=1254 -> 1575 -> 2657 (below a 1920px frame) -> -6717 (behind the camera)`.
   This is why the blackout begins exactly at CHARGER, never recovers, and
   never touches NOISETTE/GLAND -- those are separate nodes that do not move.

2. **A failed sample is silently reported as a black one.** `_sample_box`
   returns `Color.BLACK` when its box falls entirely outside the image.
   Black against a mid-tone ground is a *high* contrast ratio, so the
   failure mode **inflates** the result: the blacked-out hazards were
   recorded at 5.81:1, 7.01:1, 4.38:1, 3.06:1 and counted as comfortable
   passes. A sample that could not be taken must never be scored.

A third defect surfaced once the first two were fixed and the CHARGER could
be seen at all: **the sample point was the obstacle node's ORIGIN**, which
for a ground-anchored hazard is on the ground plane. The CHARGER wedge sits
ON the ground (`ChargerShapeProbe` asserts min Y ~= 0), so its origin
projects to the bottom edge of the silhouette and a 14px box around it is
mostly ground -- it measured `1.00:1`, reading the ground's colour and
comparing it to itself. Fixed by sampling the world-space centre of the
type's own `ModelSlot` mesh AABB.

Consequence for the record: of the canonical pass's **36 hazard contrast
measurements (6 hazards x 6 palettes), 9 were valid**. 26 were off-frame
misses scored as black, and the CHARGER's one on-frame sample was reading
the ground. NOISETTE and GLAND (12 samples) were always valid. The sweep
pass is unaffected (it never sets `PLAYING`, so nothing moves), as is the
barrier pass.

### Re-measured, after the fix

36/36 hazard samples valid, `0 missed samples`. Worst ratio per object
across the six shipped palettes:

| object | before | after | note |
|---|---|---|---|
| DODGE | 1.99 | **1.95** | 4 of 6 palettes were phantom |
| JUMP | 1.51 | **1.44** | 4 of 6 phantom |
| ENEMY | 1.58 | **1.47** | 4 of 6 phantom |
| AIR_ENEMY | 1.00 | **1.30** | 4 of 6 phantom |
| CHARGER | 1.00 | **1.61** | 5 of 6 phantom, 6th was ground |
| STOMPER | 2.46 | **1.94** | 5 of 6 phantom |
| NOISETTE / GLAND | 1.01 / 1.03 | 1.01 / 1.03 | unchanged, always valid |
| **hazard worst** | **1.00** | **1.30** | now AIR_ENEMY, was CHARGER-on-ground |

**No design conclusion flips**, and that is worth stating as plainly as the
defect: the aggregate verdict was "below the 3.0:1 floor" before and is
"below the 3.0:1 floor" after. The phantom samples all produced HIGH ratios,
so they could never become the `min()` the verdict is taken over -- they hid
inside the per-palette table instead.

That table is not decoration. This probe's own header states that the
CHARGER's and the STOMPER's colours were **chosen against these numbers**
(both are unshaded meshes with no pre-existing colour to inherit). Those two
rows were 5-of-6 and 5-of-6 phantom. The colour decisions were made against
measurements that did not exist.

Run-to-run reproducibility after the fix: all 36 hazard samples are
byte-identical between runs; only NOISETTE/GLAND move, in the 4th decimal,
from their own bob animation -- which is exactly what the sample box is
sized to average out.

### F5 -- ShrinkAudit's SAFE bot has the same blind spot, and it corrupted a published answer

Found by the coverage ledger below, not by reading. `ShrinkAudit._drive_safe_bot`
carries the identical defect to F1 -- no `blocks_lane_switch` branch, no
jump at all. `_drive_intermediate_bot` and `_drive_risky_bot` in the same
file are unaffected: they jump anything `blocks_jump` does not exclude, and
STOMPER is not excluded, so they get the answer for free. Only the bot that
never jumps needed it stated.

Phase 1 of that probe asks whether a realistic profile ever reaches the
`SHRINK_UNLOCK_SCORE` of 3000, and reported:

```
SAFE   runs 15   best score  750   runs over gate 0 (0%)   -> never reaches it
```

The ledger then showed `SAFE ... STOMPER 15/15` -- it met a STOMPER on its
own lane in every one of those 15 runs. It was not failing to reach the
gate; it was being killed by the first STOMPER of every run. With the jump
added:

```
SAFE   best score 4817  -> REACHES the gate
```

The probe's answer to its own headline question was wrong for that profile.

## What this batch changes

F1-F5 are five instances of one failure: a probe cannot tell "I verified
this" apart from "I never exercised this". Fixing them one at a time is
what produced the previous four false greens, and F5 shows the supply was
not exhausted.

So beyond the fixes, this batch adds a **coverage ledger**
(`scripts/dev/ProbeCoverage.gd`): every bot-driven probe records which
mechanics its bots actually met, and **fails if any required mechanic was
never met**. A green on a mechanic that never ran becomes impossible rather
than merely unlikely.

### Why the ledger lives inside each probe

The obvious shape -- one `MetaAudit.tscn` driving bots and checking they
meet everything -- does not work. A meta probe drives ITS OWN bots, so
passing proves the meta probe's bots are fine and says nothing about
PursuerAudit's SAFE bot, which is where the defect actually lives.
ComboAudit is the proof: three sibling probes carried the STOMPER fix and
would have passed any meta probe, while ComboAudit -- same function name,
same lineage -- did not, and stayed green. The check has to run on the
bots it is checking.

### The ledger's own first draft had the bug it exists to catch

Written the obvious way -- count an obstacle crossing `Z = 0` -- it was
blind to any hazard that **killed** the bot: the run ends at contact, so
the frame that would record the crossing never runs. The single most
consequential encounter a bot can have was the one encounter the guard
could not see. It surfaced as "SAFE never met STOMPER" for a bot that met
one every run and died to it every time (F5). Arrival is now counted from
2.0m out -- derived from hitbox depth plus one physics frame at top speed
-- so it is recorded whether or not the run survives it.

## What is genuinely not true, and is now reported rather than asserted

Two probes independently reached the same conclusion, and it is a finding
about the game rather than a defect in either:

**The pursuer separates PASSIVE play from ACTIVE play. It does not grade
active play by degree.**

| statement | holds on | margin |
|---|---|---|
| capture share: safe > mid | 8/8 | 36-56 points |
| capture share: safe > risky | 8/8 | 41-67 points |
| capture share: mid > risky | **6/8** | fails by 1 and 8 points |
| mean lead: safe < mid, safe < risky | 8/8 | 5.0-7.2s |
| mean lead: mid < risky | **4/8** | crosses either way |

Nearly tripling the sample did not resolve the mid-vs-risky pair. Both
probes now print that explicitly, so a future session does not read the
absence of the assertion as an oversight and "restore" it.

## Sample sizes

Several criteria were being judged on 1 to 3 runs. `PHASE_SECONDS` raised:
Combo 300 -> 1500, Pursuer 300 -> 1500, Strike 900 -> 2400 (control
300 -> 1200). This is not a loosening -- it is giving a statistic
resolution before judging it, and where the bar was right it stayed
untouched. ComboAudit's matched-duration criterion is the clean example:
the 25% target read +22 / +24 / +22 % on three seeds at the old size and
reads +26 to +37 % on all eight at the new one. The design target holds;
the bar never moved.
