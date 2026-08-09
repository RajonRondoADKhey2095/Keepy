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
| **ChargerAudit** | The charger's reaction window and spacing hold at every palier | 08-06 | STOMPER, pursuer, strikes, shrink | ok | ok | **hung (F7)**, off | n/a | n/a | invariant + ledger |
| **AirHazardAudit** | A landed AIR_ENEMY is lethal if ignored, safe if jumped | 08-05 | everything after 08-05 | n/a (neutered) | n/a (neutered) | n/a | n/a | n/a | invariant + ledger (AIR_ENEMY only) |
| **AirEnemyLandingLaneAudit** | AIR_ENEMY's landing lane distribution is fair | 08-06 | STOMPER, pursuer, strikes, shrink | ok | ok | **hung (F7)**, off | n/a | n/a | distribution reported + ledger |
| **EnemyLaneAudit** | An ENEMY's locked lane and its contact lane agree | 08-05 | everything after 08-05 | n/a | n/a | **2% sample (F7)**, off | n/a | n/a | distribution reported |
| **JumpDodgeRewardAudit** | A timed jump over a JUMP credits the reward exactly once | 08-06 | STOMPER, pursuer, strikes, shrink | n/a | n/a | n/a | n/a | n/a | invariant (exact equality) |
| **LaneFillAudit** | The early game does not use the full track width | 08-06 | STOMPER, pursuer, strikes, shrink | n/a | n/a | n/a | n/a | n/a | distribution only |
| **PacingAudit** | Palier timings, spacing and the enemy lock, measured not re-read | 08-05 | everything after 08-05 | ok | n/a | n/a | n/a | n/a | invariant |
| **AssetContractAudit** | A mesh swap changes every visual and moves no collider | 08-08 | -- | n/a | n/a | n/a | n/a | n/a | invariant (exact equality) |
| **TrackPropsAudit** | Trackside props stay outside the play area and add no collider; plus the measured frame triangle budget | 08-09 | -- | n/a | n/a | n/a | n/a | n/a | invariant x2 + **absolute** (props' own triangle share); frame total REPORTED, not asserted |
| **ChargerShapeProbe** | The charger wedge is oriented and grounded as designed | 08-06 | -- | n/a | n/a | n/a | n/a | n/a | invariant |
| **DarkPaletteAudit** | Every hazard stays legible against the ground on every palette | 08-06 | STOMPER (`5c2b3fb`), shrink (`ec1836a`) | **broken sampling** | **broken sampling** | n/a | n/a | ok | absolute (a contrast floor, legitimately) |
| **ComboContrastAudit** / **StrikeContrastAudit** / **StrikeFatalContrastAudit** / **PursuerContrastAudit** | The HUD reads against its real background on every palette | 08-06/07 | -- | n/a | n/a | n/a | n/a | n/a | absolute (a contrast floor, legitimately) |
| **InvertCapture** / **PacingProbe** / **LiveRunProbe** | Diagnostic printers, no verdict | 08-05 | -- | n/a | n/a | n/a | n/a | n/a | none |
| **SilhouetteSampleDiag** | Diagnostic printer, no verdict: decomposes what `PursuerContrastAudit`'s silhouette box actually samples, one contributor at a time (see F10) | 08-09 | -- | n/a | n/a | n/a | n/a | n/a | none |

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

### F6 -- AirHazardAudit was never seeded at all. RESOLVED.

The finding as originally recorded: `AirHazardAudit` passes and fails **on
the same seed**, on `origin/main` as much as on the branch -- 1 failure in
11 runs, then 2 in 5 -- while `git diff origin/main` was **empty** for
`AirHazardAudit.gd` and for every file it loads.

Every one of those observations was correct. The conclusion drawn from
them was not, and the reason is a single missing line:

**`AirHazardAudit._ready()` never called `DevSeed.apply()`.**

`--seed=<int>` is not ambient. `DevSeed.apply()` is the only thing that
reads the flag and calls `seed()`, no probe gets it for free, and this one
never called it. So `-- --seed=20260806` was accepted on the command line,
parsed by nobody, and every invocation drew a fresh RNG stream. The probe
was exploratory the entire time. A ~10-40% failure rate across runs is not
a probe whose verdict fails to be a function of its inputs; it is a probe
sampling a different run each time, which is exactly what an unseeded
probe is supposed to do.

This also explains the observation that looked most damning. "The inputs
are byte-identical and the outputs differ" was true and pointed the right
way -- nothing in the inputs differed **because the seed was never among
the inputs**.

The recorded hypothesis -- a startup-ordering race between `_process` and
the first `_physics_process`, moving the liftoff frame inside a narrow
clearance window -- is **not** the cause. It was labelled a hypothesis
rather than a diagnosis, which is what made it cheap to discard. The
0.330-0.345s spread of liftoff times it rested on is simply where each
unseeded run's AIR_ENEMY happened to be.

Fixed by adding the missing `DevSeed.apply()`, and the probe now prints
`seeded N (reproducible)` / `unseeded (exploratory)` like the others, so
the same mistake is visible in the output instead of silent.

#### Determinism, measured

20 consecutive runs of each tree at seed 20260806, stdout captured and
compared byte-for-byte. Not "it passed twice" -- the whole output.

| | exit 0 | exit 1 | distinct outputs |
|---|---|---|---|
| before (no `DevSeed.apply()`) | 15 / 20 | **5 / 20** | **20 of 20** |
| after | **20 / 20** | 0 | **1 of 20** |

The right-hand column is the finding. Before the fix **every single run
produced a different output** -- twenty runs, twenty distinct hashes, at
what was nominally the same seed. That is not a probe with an
intermittent race; that is a probe that never read the seed. The 25%
failure rate is the same sampling variance the original F6 entry recorded
as 1-in-11 and 2-in-5, now measured at a sample size where it is stable.

After the fix all twenty runs are the same bytes
(`e3f85c7e025f832e91459dcd0df87f98c57af3672995600bb28a0ede2212586d`).

#### The same defect, elsewhere

`AirEnemyLandingLaneAudit` had it too, and was fixed in the same batch.
Nine other probes still do not call `DevSeed.apply()`; for most that is
harmless (they never run a real seeded run -- `AssetContractAudit`,
`ChargerShapeProbe`, the four contrast probes, `InvertCapture`). Three
DO drive real runs and still ignore `--seed`: **`StomperAudit`,
`EnemyLaneAudit`, `JumpDodgeRewardAudit`**, plus `DarkPaletteAudit` and
`LiveRunProbe`. They are exploratory-only today whether or not a seed is
passed. Not fixed here -- none of them is in the reference baseline, and
the point of this entry is that "I passed `--seed`" is not evidence a
probe honoured it. Check for `DevSeed.apply()` before believing a seed.

### F7 -- The pursuer ends the run these probes depend on. RESOLVED, and it was three probes, not two.

Reproduced on `origin/main` and on the branch: neither `ChargerAudit` nor
`AirEnemyLandingLaneAudit` produced a single line past its header, at 100%
CPU, for as long as either was left running.

The recorded guess was that `ChargerAudit` "is advancing at roughly real
time rather than sprinting". **It is not slow. It is stopped**, and it had
been since the pursuer landed on 08-06. Measured: it sprints at ~45x real
time and completes its 900 simulated seconds in 21s of wall clock.

The mechanism, measured with an instrumented copy of the shared structure
at seed 20260806:

```
frame    1  sim_t   0.00s  wall 0.2s  state -> PLAYING
frame 4262  sim_t  71.02s  wall 1.8s  state PLAYING -> CAPTURED   death_cause=PURSUER
frame 4328  sim_t  71.02s  wall 1.8s  state CAPTURED -> GAME_OVER
              ... sim_t FROZEN at 71.02s for every frame thereafter
```

Both probes neuter the player's collision layer so one continuous run can
cover their whole sample. The pursuer does not go through collision at
all -- it drains a lead and calls `_begin_capture_sequence()` directly --
so it kills exactly the kind of bot they depend on. Both then gate
`_physics_process` on `state == PLAYING` and advance their simulated clock
**inside that gate**, so the clock stops permanently and the completion
check written against it (`_t >= SIM_SECONDS`; `_sample_count >=
TARGET_SAMPLES or _t >= MAX_SIM_SECONDS`) becomes unreachable.

This is the same shape as every other finding in this document: a probe
written before a mechanic, meeting it, and having no answer. Both were
written 08-06, before `e0c69dc`/`82f3a4b`.

`GameState.pursuer_enabled` documents this exact failure and exists for
it -- its own doc says so, having been written after the first
`AntiFrustrationAudit` hang. Five probes already use it. These two were
left behind. Fixed by using it in both; neither probe's subject can be
moved by the pursuer, so no number either reports changes.

| probe | before | after, seed 20260806 |
|---|---|---|
| `ChargerAudit` | never terminates | **21s**, 900s simulated, 90 charger crossings |
| `AirEnemyLandingLaneAudit` | never terminates | **84s**, 200/200 samples, 0 mismatches |

#### The same root cause, with the symptom hidden: EnemyLaneAudit

Found by checking which other probes share the shape. `EnemyLaneAudit`
(written 08-05) also boots the real game, also neuters collision, also
never disables the pursuer -- and **does not hang**, which is worse.

It has no `state != PLAYING` early return, so its simulated clock keeps
advancing after the capture. But the TRACK stops, so no further ENEMY
ever locks or reaches the player: the sample counter stops dead at ~71
simulated seconds while the clock runs on to `MAX_SIM_SECONDS`. Measured
on the pre-fix file, seed 20260806:

```
simulated time    : 6000.0s
samples collected : 4         (target 200)
exit code         : 0
```

It printed a lane distribution built from **four enemies -- 2% of the
requested sample** -- and exited 0. It does carry the string "TARGET NOT
REACHED ... read with caution", but only to a human reading the output;
every automated caller saw a pass. After the fix: 86s, 200/200 samples,
0 mismatches.

The hang is the loud symptom of this root cause. This is the quiet one,
and it is the reason the fix is the pursuer hatch rather than a timeout:
a timeout would have caught the two that spin and never noticed this one.

#### Three probes that could not fail at all

Fixing the above exposed a defect all three share, which is why they are
not merely restored but gated. **All three exited 0 unconditionally.**
`ChargerAudit` computed "BELOW REQUIREMENT" for its reaction window and
its spacing, printed it, and then `quit(0)` regardless.
`AirEnemyLandingLaneAudit` and `EnemyLaneAudit` did the same with the one
condition their own output calls a bug outright ("a non-zero value IS a
bug"), and with runs that finished under-sampled.

So the check ran, the verdict was computed, and the verdict was discarded.
That is the false-green family one level up -- not a probe that fails to
test something, but a probe whose finding reaches a human reader and
nothing else. Any script or CI job running them saw a pass no matter what
they found. All three now take their exit code from the numbers they
print.

### No probe can run forever

`scripts/dev/ProbeWatchdog.gd`, armed as the first statement of every
probe's `_ready()`.

F7 is the argument for it, and specifically the *shape* of F7 rather than
its cause. A probe that hangs is indistinguishable from a probe that is
slow, and that ambiguity is what let two dead probes be documented as
runnable and "expected to take a very long time" instead of being fixed.
A probe that gives up and says INCONCLUSIVE is strictly more useful than
one that occupies a terminal until someone kills it: the first is a
result, the second is the absence of one.

It measures **wall** clock, not simulated time -- the failure being
guarded against is precisely a simulated clock that has stopped, and a
budget denominated in the frozen quantity could never expire. It runs in
`_process` with `PROCESS_MODE_ALWAYS`, not `_physics_process`, because
every probe's own `_physics_process` early-returns on `state != PLAYING`
and a watchdog sharing that method would inherit the same blindness. It
reads nothing from the probe it guards.

On expiry it prints the GameState it died in, which is what turns "it
hung" into a diagnosis -- for the two probes above it reads
`state=GAME_OVER  death_cause=PURSUER`, naming the cause outright.

Budget: 900s, derived rather than picked -- ~4x the slowest probe that
genuinely finishes (see the timing table below). Exit code **2**,
deliberately not 1: the folder's convention is 0 = contract holds, 1 =
contract violated, and a timeout is neither.

### F6b / F9 -- the misattributed death, and its sibling. RESOLVED (follow-up).

F6 closed the *seeding* half. Measured afterwards on `main`, **AirHazardAudit
still failed 2 of 20 seeds** (1 and 314159): seeding made the probe
reproducible without making it correct, and the reference seed 20260806
passes only because it is one of the 18 lucky draws. A green baseline resting
on that is the exact trap this document exists to record.

The residual is a **misattributed death**. Phase 2 holds for
`SURVIVAL_HOLD_S` after the jump lands; Keepy spends that hold on the ground,
and the probe deliberately leaves every OTHER `AIR_ENEMY` alive -- it neuters
only the other types. A second one killing a stationary bot is not a bug: it
is what **phase 1 of the same probe asserts must happen.** The failure branch
blamed the hazard the jump had already cleared.

Instrumented on seed 1: killer segment key `105277031797`, jump target
`104689829729` -- a different, already-passed hazard, 1.6s after liftoff with
an air time of ~0.69s, i.e. half a second after landing.

`_target_is_at_the_player()` now gates the failure in both probes: a death in
the hold is a failure only if the hazard under test is at the player plane,
otherwise the run is inconclusive and retries -- the treatment deaths before
the jump already had.

**F9** is the same pair of defects in `JumpDodgeRewardAudit`, which borrows
AirHazardAudit's phase-2 technique wholesale and inherited both gaps with it:
no `DevSeed.apply()`, and the same blame-anything branch.

| | before | after |
|---|---|---|
| AirHazardAudit, 20 seeds | 2 failures | **0** |
| AirHazardAudit, 20 runs @20260806 | (seeded, already stable) | **1 output, 0 failures** |
| JumpDodgeRewardAudit, 20 runs @20260806 | **20 distinct outputs** | **1 output, 0 failures** |
| JumpDodgeRewardAudit, 12 seeds | -- | **0 failures** |

Still no gameplay defect: the game behaved correctly in every case measured.

### F10 -- PursuerContrastAudit's "ground" stopped being the ground. DIAGNOSED, NOT FIXED.

(F8 was never assigned. This is the next free number.)

`PursuerContrastAudit` logged **2.53:1** on its worst dark palette on
2026-08-08 and now fails **6 of 6** at **1.85:1**, against a 2.5 floor.
Nothing about the pursuer changed. **What changed is what the probe
measures it against.**

Confirmed pre-existing on unmodified `main` (`149c35b`), reproduced four
times: DARK/2 = **1.84 / 1.85 / 1.85 / 1.87**. The probe's own source is
**byte-identical** to the 2.53 baseline -- `git diff ce3bec9 149c35b --
scripts/dev/PursuerContrastAudit.gd` is empty. The entire move is scene-side.

#### When it broke

Probe re-run at each commit along `main`'s path, `--fixed-fps 60`, worst
palette (DARK/2):

| commit | | DARK/2 | Δ |
|---|---|---|---|
| `ce3bec9` | Hibou pursuer installed (the 2.53 baseline) | **2.53** PASS | -- |
| `6270afc` | background hills **+ fog enabled** | 2.39 FAIL | **-0.14** |
| `83ef8e0` | **per-tile ground tint** + lane curbs | 2.43 | +0.04 |
| `2ffc491` / `9dca8fb` / `90bfd39` | hill recycle fix, two merges | 2.40 / 2.39 / 2.45 | flat |
| `b3e3395` | Keepy squirrel installed (still **lit**) | 2.46 | flat |
| **`c7b2275`** | **Keepy made unlit**, emit map dropped | **1.84** | **-0.62, 6/6 FAIL** |
| `33c3d28` / `149c35b` | trackside props, merge | 1.86 / 1.85 | flat |

Two culprits, one small and one dominant. The leading suspect going in --
the decor batch's ground tint -- is **not** one of them.

#### The stated hypothesis, tested and refuted

`TrackSegment._reroll_ground_tint` really is unseeded (measured, not read
off the source: the seven live segments roll seven different albedos,
e.g. `(0.525,0.450,0.327)`, `(0.577,0.419,0.344)`, spread ±0.05 as
designed). **It does not move this probe.** Forcing every segment back to
the base albedo mid-run changes DARK/2 by **-0.01** and LIGHT by -0.04,
and the commit that introduced it moved DARK/2 *up* by 0.04. Against a
0.68 drop and a 0.03 run-to-run spread, the tint is not the story here.

#### What is, measured per contributor

`scripts/dev/SilhouetteSampleDiag.tscn` (added by this batch; diagnostic
only, no verdict) re-runs the probe's exact setup with one contributor
removed at a time:

| removed | DARK/2 | Δ | LIGHT | Δ |
|---|---|---|---|---|
| -- (as shipped) | 1.86 | -- | 7.37 | -- |
| background hills | 1.86 | **0.00** | 7.36 | 0.00 |
| trackside props | 1.86 | **0.00** | 7.36 | 0.00 |
| ground tint → base | 1.85 | **-0.01** | 7.36 | -0.04 |
| fog | 1.99 | **+0.13** | 8.60 | +1.24 |
| **Keepy** | **2.26** | **+0.40** | **9.73** | **+2.36** |
| all five | 2.28 | +0.42 | 10.86 | +3.49 |

(Not additive: switching fog off also changes the pursuer's own pixels,
so the last row is not the sum of the rest.)

#### Real legibility loss, or an unreliable probe? Both -- and separably

**Real, and small: fog.** `6270afc` enabled `fog_density = 0.0035` toward
the bright sky colour to hide hill recycling. Fog blends the pursuer's
near-black body toward that colour, measured on the body's own darkest
pixel: **L 0.0094 → 0.0200** in the light phase. The probe's floor was
derived on the premise that "pure black is the optimum albedo"; fog means
the pursuer is no longer rendered as pure black. That is a genuine,
player-visible loss, worth **~0.13-0.18** ratio points.

**Unreliable, and dominant: the probe is no longer sampling the ground.**
Measured, not inferred -- the diagnostic projects the silhouette's real
`visual_aabb()`:

    probe box           : x 450..630   y 1047..1227   (180x180)
    silhouette on screen: x 387..693   y 1022..1512   (305x490 px)

The 180px box lies **entirely inside** the pursuer's own projected
bounding box. So when the probe hides the pursuer to obtain "the
background", what it uncovers is not the ground -- it is **Keepy**, who
stands directly behind the pursuer at the pinned `TEST_LEAD_S = 1.5`.
Hiding Keepy moves the background mean from **L 0.4683 to 0.6613** in the
light phase, and the verdict by **+0.40** on DARK/2.

That is why `c7b2275` -- a commit that **does not touch the pursuer at
all** -- moved this number more than anything else: making Keepy unlit
(and dropping its emit map) changed the colour of the surface the probe
had quietly started calling "the ground".

The probe's header states the reference is "the ground it is seen
against", and its 2.5 floor is **derived** by sweeping albedos "against
the measured lit ground colour". Floor and measurement no longer refer to
the same surface. This is the F1-F5 family again, in a new place: not a
bot failing to meet a mechanic, but **a threshold and a sample that have
drifted apart** -- and the drift reports as a legibility failure of the
one object the player must see coming.

**So: the number is not noise** (0.03 spread against a 0.68 drop, two
reproducible mechanisms). But most of it is not about the pursuer.

#### A latent second defect in the same function, not the cause today

`_silhouette_rect()` centres on `_pursuer.global_position + (0, 1.7, 0)`
-- an **unscaled** 1.7m offset -- while `_freeze()` sets the node's scale
to `lerp(FAR_SCALE, NEAR_SCALE, t)` = 0.613 at this lead. The silhouette's
own origin is therefore at y≈1.04m, not 1.7m, and the box sits on the
upper body rather than the centre (box centre y=1137, silhouette bbox
centre y≈1267). It still lands on the pursuer today only because the model
is large. At `FAR_SCALE` (0.4) the offset is 2.5x the node's own height
scale, so the aim drifts with lead. Worth fixing whenever this function is
next opened.

#### Does the same root cause hit the other contrast probes?

Re-run at both `ce3bec9` and `149c35b`:

| probe | baseline | HEAD | shares the cause? |
|---|---|---|---|
| **ComboContrastAudit** | PASS, all 7 | **byte-identical**, PASS | **No.** Its background samples as `(0.55,0.75,0.95)` -- the **sky**. Ground decor cannot reach it. |
| **StrikeContrastAudit** | PASS (worst 4.79) | PASS (worst 5.21) | **Partly.** Its background *does* move (LIGHT 11.61→13.61) so it is reading a world surface that changed -- but against a 3.0 floor with 2.2+ of margin, no verdict is at risk. |
| **StrikeFatalContrastAudit** | FAIL DARK/0, DARK/5 | **FAIL DARK/0, DARK/5** | **No -- same two palettes, numbers move ≤0.02.** Its failure is the pre-existing one already recorded below, unrelated to this batch. |

**But `StrikeFatalContrastAudit` does have the unseeded-ground problem --
just not as the cause of its failure.** Three consecutive runs at HEAD:

| palette | run 1 | run 2 | run 3 | floor |
|---|---|---|---|---|
| LIGHT | 6.81 | 6.06 | 6.52 | 3.0 |
| DARK/0 | 2.87 | 2.86 | **2.98** | 3.0 |
| DARK/3 | 3.19 | 3.19 | 3.10 | 3.0 |
| DARK/4 | 3.13 | 3.24 | 3.23 | 3.0 |

Its sampled background colour visibly changes run to run
(`(0.71,0.56,0.43)` / `(0.70,0.51,0.44)` / `(0.73,0.53,0.48)`), because it
samples a *fixed* HUD rect at the bottom of the screen against a ground
whose tint and props are rolled from unseeded RNGs. **DARK/0 came within
0.02 of flipping FAIL→PASS**, and DARK/3 and DARK/4 sit 0.10-0.24 above
the floor with a ±0.11 spread. This probe's verdicts are genuinely
at the mercy of a roll. That is where the ground-tint hypothesis lands
correctly -- on a different probe than the one it was raised about.

#### Proposed fix -- NOT implemented, three separable decisions

1. **Make the silhouette probe measure what it names.**
   `scripts/dev/PursuerContrastAudit.gd`, in `_freeze()`: hide
   `World/Keepy` for the duration of the measurement, exactly as it
   already hides `_pursuer_row` and `_pursuer` to obtain their
   backgrounds. One line. The reference becomes the ground the 2.5 floor
   was actually derived against.
   *Tradeoff:* pursuer-seen-against-Keepy is a legitimate legibility
   question, and this stops measuring it. It should get its own check with
   its own floor rather than be folded silently into this one -- which is
   what is happening today.
   *Rejected alternative:* keep Keepy and re-derive the floor. The current
   floor's derivation is documented and reproducible; "whatever happens to
   stand behind the pursuer at lead 1.5" is not a stable reference to
   derive anything against.

2. **Decide about fog.** `scenes/Game.tscn`, `fog_density = 0.0035`. It
   costs the pursuer ~0.13-0.18 ratio points and breaks the "pure black is
   optimal" premise the floor rests on. Options: accept it and re-derive
   the floor with fog in the sweep; reduce the density; or keep it off
   near objects. The fog exists to hide hill recycling, so this is a design
   call, not a probe fix.

3. **Seed the decor RNGs -- for `StrikeFatalContrastAudit`'s sake, not the
   pursuer's.** `TrackSegment._tint_rng` / `_prop_rng` and `Decor._rng`.
   *Tradeoff:* these were deliberately given their own RNG instances so a
   decor draw could never perturb the gameplay stream. Seeding them from a
   `DevSeed`-derived constant **keeps** that property -- separate stream,
   now deterministic -- so it costs nothing that the current design was
   protecting. Without it, that probe's verdicts stay a coin-flip near the
   floor.

None of the three is applied here. This batch is diagnosis only.

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

## The reference baseline, re-measured

Seed 20260806, Godot 4.3-stable headless, `--fixed-fps 60`, 4-core CI-class
machine. Pixel-sampling probes run under `xvfb-run -a --rendering-driver
opengl3`; everything else `--headless`. Wall clock, not simulated time.

This table replaces the previous baseline. It is what the Meshy asset
import should be measured against.

**23 of 25 probes green.** The two that are not are covered below, and
neither is caused by this batch.

| probe | rc | wall | note |
|---|---|---|---|
| ChargerShapeProbe | 0 | 1s | |
| AssetContractAudit | 0 | 2s | the one that guards the mesh swap |
| JumpDodgeRewardAudit | 0 | 2s | |
| PacingAudit | 0 | 2s | measurement, no PASS/FAIL string |
| AirHazardAudit | 0 | 4s | **F6 fixed** -- seeded, 20/20 byte-identical |
| PursuerFramingAudit | 0 | 6s | gated bot probe |
| StomperAudit | 0 | 7s | |
| AntiFrustrationAudit | 0 | 8s | gated bot probe |
| InvertCapture | 0 | 11s | diagnostic printer, no verdict |
| RushFrustrationAudit | 0 | 14s | gated bot probe |
| LaneFillAudit | 0 | 20s | distribution only |
| StomperConflictAudit | 0 | 20s | |
| ChargerAudit | 0 | 24s | **F7 fixed** -- never terminated before |
| ShrinkAudit | 0 | 52s | gated bot probe |
| ComboContrastAudit | 0 | 58s | |
| ComboAudit | 0 | 80s | gated bot probe |
| StrikeContrastAudit | 0 | 80s | |
| AirEnemyLandingLaneAudit | 0 | 86s | **F7 fixed** -- never terminated before |
| EnemyLaneAudit | 0 | 93s | **F7 fixed** -- 4/200 sample before |
| PursuerContrastAudit | 0 | 96s | |
| DarkPaletteAudit | 0 | 155s | |
| PursuerAudit | 0 | 166s | gated bot probe |
| StrikeAudit | 0 | 227s | gated bot probe; slowest that finishes |
| **StrikeFatalContrastAudit** | **1** | 60s | **real FAILURE, pre-existing -- see below** |
| **LiveRunProbe** | **124** | -- | needs `--quit-after`, by design -- see below |

All seven gated bot probes (AntiFrustration, Combo, Pursuer,
PursuerFraming, RushFrustration, Shrink, Strike) are green
**simultaneously at one seed**, each with its coverage ledger satisfied.
That is the baseline the Meshy import should be measured against.

> **This table is a dated snapshot, not current state.** The
> `PursuerContrastAudit` row above reads `rc 0`; on `149c35b` it is `rc 1`,
> failing 6 of 6 dark palettes. It was not the asset imports that changed
> the pursuer -- see **F10** for the bisect and the cause. Do not read this
> row as evidence the probe is green today.

### The two that are not green

**`StrikeFatalContrastAudit` fails, and it is a real finding about the
game, not about the probe.** Two palettes leave the fatal-strike label
under the 3.0:1 WCAG floor on BOTH the fill and the outline -- i.e. the
"you are one hit from dead" label is illegible on those palettes.

Verified pre-existing rather than assumed: the **unmodified file from
`origin/main` (`1244142`)** was run in a scene of its own and failed the
same way (3 palettes that run). Nothing in this batch touches the HUD,
its colours, or the palettes. **Deliberately NOT fixed here** -- it is a
visual/design defect and belongs in its own batch, where the colour
choice can be made against the numbers rather than alongside a probe
refactor.

The 3-vs-2 difference between the two runs is itself informative: this
probe is one of the nine that never call `DevSeed.apply()`, so both runs
were exploratory. See the F6 note on that list.

**`LiveRunProbe` does not self-terminate, and that is by design.** Its
own header documents the invocation as `--quit-after 25400`; it is a
transition logger with no completion condition, meant to be bounded by
the caller. The 124 above is the harness cap, from running it without
that flag. It is not a defect and not an F7 case -- but it is now bounded
by the watchdog at 900s regardless, where before it was unbounded.

### What the watchdog budget is derived from

900s is ~4x the slowest probe that genuinely finishes (StrikeAudit,
227s). Wide enough that machine-to-machine variance, a debug build or a
loaded runner cannot trip it; narrow enough that a stuck probe is caught
in minutes rather than never.

### How to read an exit code

| code | meaning |
|---|---|
| 0 | the contract holds |
| 1 | the contract is violated, OR the run could not test it (INCONCLUSIVE) |
| 2 | ProbeWatchdog stopped it -- no verdict was reached |

2 is deliberately not 1. A timeout is the absence of a verdict, not a
finding, and a caller treating it as a failed assertion would report
something the probe never said.

### Before running any of this from a fresh checkout

`godot4 --headless --path . --import` must run once. `ProbeWatchdog`
declares a `class_name` and `.godot/` is gitignored, so without the import
step every probe fails to compile and hangs producing no output -- which
is, with some irony, exactly the symptom the watchdog exists to make
unmistakable. CI already imports before running anything.

**Flag order matters.** Godot treats the first non-flag argument as the
scene to run, so every engine flag must come BEFORE `--path` and before the
scene path -- `--fixed-fps 60` included. The pixel-sampling probes need a
real GL context, so they take the longer form:

    xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
      --path . res://scripts/dev/PursuerContrastAudit.tscn

`--fixed-fps 60` is not optional for anything being compared run-to-run:
this sandbox's headless Godot does not hold a deterministic physics-tick
count across runs without it (see `docs/MESHY_SPEC.md` §11, where the same
flag was what made a before/after comparison reproducible).

## Still open after this batch

- **`StrikeFatalContrastAudit` fails on 2-3 palettes.** A real legibility
  defect in the shipped HUD, verified pre-existing on `origin/main`,
  deliberately left for its own batch. **No longer the only red verdict in
  the suite** -- see the next item. Re-confirmed at `149c35b`: it fails on
  the same two palettes (DARK/0, DARK/5) it failed on at `ce3bec9`, with
  the numbers moving ≤0.02, so the decor/Keepy batches did not cause or
  worsen it. What F10 *does* add about it: **its verdicts near the floor
  are not reproducible** (DARK/0 measured 2.87 / 2.86 / 2.98 on three
  consecutive runs against a 3.0 floor). Fixing the colours without also
  seeding the decor RNGs would leave the pass unable to prove itself.
- **`PursuerContrastAudit` fails on 6 of 6 dark palettes, worst 1.85:1
  against a 2.5 floor. DIAGNOSED, NOT FIXED -- see F10.** Bisected to two
  scene-side commits (`6270afc` fog, `c7b2275` Keepy made unlit); the probe's
  own source is unchanged. Most of the drop is the probe sampling **Keepy**
  rather than the ground it claims to measure against; a smaller, genuine
  part is fog washing out the pursuer's black body. Three separable fixes
  are proposed in F10 and none is applied -- the decision is Mathieu's.
- **Nine probes still ignore `--seed`** (no `DevSeed.apply()`):
  `StomperAudit`, `JumpDodgeRewardAudit`, `DarkPaletteAudit`,
  `LiveRunProbe`, `AssetContractAudit`, `ChargerShapeProbe`,
  `ComboContrastAudit`, `StrikeContrastAudit`,
  `StrikeFatalContrastAudit`, `PursuerContrastAudit`. For most it is
  harmless (they never run a real seeded run). For the first four it
  means "I passed `--seed`" is not evidence the run was reproducible --
  which is precisely how F6 hid. Not fixed here because none is in the
  reference baseline's gated set.
- **`LiveRunProbe` has no completion condition** by design and relies on
  the caller passing `--quit-after`. Now bounded by the watchdog, but it
  is the one probe whose "green" cannot be obtained by running it the way
  every other probe here is run.

## Sample sizes

Several criteria were being judged on 1 to 3 runs. `PHASE_SECONDS` raised:
Combo 300 -> 1500, Pursuer 300 -> 1500, Strike 900 -> 2400 (control
300 -> 1200). This is not a loosening -- it is giving a statistic
resolution before judging it, and where the bar was right it stayed
untouched. ComboAudit's matched-duration criterion is the clean example:
the 25% target read +22 / +24 / +22 % on three seeds at the old size and
reads +26 to +37 % on all eight at the new one. The design target holds;
the bar never moved.
