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

### F10 -- pixel probes measuring something other than their column header. RESOLVED.

Same family as F1-F5 one level down: the probe ran, the number printed, and
the number was not of the quantity the header named. Two defects were
diagnosed going in (a, b); a third (c) was found by measuring whether the
fix for (b) had actually worked, and turned out to dominate it.

Both probes were **red before and after** this work. Nothing here made a
failing thing pass, and no floor was moved. What changed is that the
numbers now describe the game.

#### F10a -- PursuerContrastAudit was measuring Keepy, not the ground

`_silhouette_rect()` unprojects a 180px box around the pursuer, and the
background for it is obtained by hiding the pursuer and re-capturing. That
box lies **entirely inside the pursuer's projected bounds**, and at the
pinned lead **Keepy stands directly behind it**. Hiding the pursuer did not
uncover the ground. It uncovered the player. The probe reported
pursuer-vs-Keepy under the header `silhouette:ground`, in every palette,
for its whole life.

Measured on the same frame, hiding Keepy or not -- not reasoned about:

| palette | bg, Keepy in box | bg, ground | ratio, Keepy | ratio, ground |
|---|---|---|---|---|
| LIGHT | `#eda488` | `#ffc7a6` | 7.39 | 9.98 |
| DARK/0 | `#933946` | `#8c2938` | 2.44 | 2.87 |
| DARK/1 | `#939140` | `#8c8232` | 2.08 | 2.49 |
| DARK/2 | `#18b55c` | `#11a54f` | 1.85 | 2.20 |
| DARK/3 | `#187fc1` | `#1170b3` | 2.03 | 2.48 |
| DARK/4 | `#4a39c1` | `#4329b3` | 2.32 | 2.77 |
| DARK/5 | `#933994` | `#8c2987` | 2.34 | 2.75 |

Fixed by hiding `World/Keepy` in `_freeze()` -- for the **whole**
measurement, not just the background capture. Hiding it only for the
background swaps one wrong answer for another: the pursuer's own "darkest
pixel" is picked from the same box in the with-everything frame, so Keepy's
body would go on standing in for the pursuer's there.

**This also explains a stale green in this document.** The 2026-08-08 Hibou
entry in `docs/MESHY_SPEC.md` §11 records this probe passing all six dark
palettes, worst `DARK/2` at 2.53:1, and the baseline table below still
carries `rc 0` from that measurement. Both were readings of
pursuer-vs-**placeholder-Keepy**. The Keepy squirrel landed the next day
(§11, 2026-08-09), the reference surface changed underneath the probe, and
on `origin/main` today the *unfixed* probe fails **all six** dark palettes
(worst 1.85:1). That batch had no reason to suspect it -- its own §11 entry
states, correctly as to the source, that `PursuerContrastAudit` has "zero
references to Keepy". It had zero references and was sampling its pixels.

#### The re-derived verdict, and it is not a pass

With the reference surface corrected, the pursuer silhouette against the
**ground**, decor pinned (see F10b), floor 2.5:1 as shipped:

| palette | silhouette:ground | verdict |
|---|---|---|
| LIGHT | 11.02 | PASS |
| DARK/0 | 2.98 | PASS |
| DARK/1 | 2.66 | PASS |
| DARK/2 | **2.37** | **FAIL** |
| DARK/3 | 2.69 | PASS |
| DARK/4 | 2.94 | PASS |
| DARK/5 | 2.87 | PASS |

**`DARK/2` (green) fails, and the floor was not moved to make it pass.**
Three things about it are worth stating rather than filing as a number:

1. **The 2.5 floor's own derivation is now suspect.** Its source comment
   justifies 2.5 as "below the 2.65 worst case actually measured" -- but
   that 2.65 was measured against Keepy. The true worst case against the
   ground is 2.20 unseeded / 2.37 pinned. The floor was calibrated on the
   contaminated reading.
2. **On the same comment's own sweep, `DARK/2` cannot be fixed by
   re-colouring the pursuer.** It puts green's ceiling -- the best contrast
   *any* unshaded albedo can reach against that ground through the
   invert+tint -- at 2.05. The measured 2.37 is already above that ceiling
   (the emissive eyes are not an unshaded albedo), so the sweep is not a
   hard bound either; but nothing about the pursuer's own colour has 0.13
   of headroom to give. If `DARK/2` is to clear 2.5, the ground albedo or
   `DARK_TINT_AMOUNT` is what has to move.
3. **Deliberately not fixed here.** It is a visual/design decision, and it
   belongs in the batch that can make the colour choice against these
   numbers -- exactly the treatment `StrikeFatalContrastAudit`'s failure
   already gets below.

#### What this stops measuring, recorded rather than dropped

**Pursuer against Keepy is now measured by nothing.** It is a real
legibility question -- the pursuer looms directly behind the player, so the
two silhouettes genuinely are read against each other, and the numbers in
the first table above are low (1.85 at worst). Losing it is a real loss,
not a cleanup: it needs its own probe, with its own reference surface and
its own floor. What was wrong was answering it by accident under the wrong
label. This is the second entry asking for a Keepy-specific contrast probe;
§11's Keepy entry is the first.

#### The latent `_silhouette_rect()` offset: real, and it does not move these numbers

`_silhouette_rect()` centres its box on `global_position + (0, 1.7, 0)`,
using the `Silhouette` child's **local** y while the node carries
`scale 0.6125` -- so the true centre is at `1.7 * 0.6125 = 1.04`. Measured,
that is a **119px** vertical error on a 180px box (centre unprojects to
y=1124 vs y=1244); the two boxes overlap by only a third of their height.

It is left alone, as instructed, and confirmed harmless to the post-fix
verdict -- both boxes were sampled in the same frame:

| palette | ratio, assumed box | ratio, true-centre box |
|---|---|---|
| LIGHT | 9.98 | 9.99 |
| DARK/0 | 2.87 | 2.88 |
| DARK/1 | 2.49 | 2.48 |
| DARK/2 | 2.20 | 2.18 |
| DARK/3 | 2.48 | 2.46 |
| DARK/4 | 2.77 | 2.78 |
| DARK/5 | 2.75 | 2.76 |

Worst difference 0.02, no verdict changes. **But note why it is harmless:**
once Keepy is hidden the box sees near-uniform ground, so where the box
sits stops mattering. Against the *contaminated* background the same offset
moved the ratio by up to 0.29 (DARK/3, 2.03 vs 2.32), because box placement
decided how much of Keepy got sampled. The fix masks this defect rather
than repairing it -- anything that re-introduces structure into the sampled
region will make it matter again.

#### F10b -- decor was unseeded, so contrast verdicts were coin flips

`TrackSegment._tint_rng`, `TrackSegment._prop_rng` and `Decor._rng` took
their state from OS entropy at construction. The pixel probes sample real
rendered pixels of exactly that decor as their reference surface, so their
verdicts moved run to run with nothing in the game having changed.

`StrikeFatalContrastAudit`, three runs of byte-identical code, `DARK/0`
against its 3.0 floor: **2.87 / 3.31 / 3.19 -- FAIL, PASS, PASS.** A
fourth, earlier run reported `DARK/5` failing, which none of these three
do. The probe was not measuring the HUD; it was measuring the HUD plus a
dice roll.

Seeded via `scripts/world/DecorRng.gd`, a factory the three streams now
take their RNG from. Two properties it has to hold at once:

- **The streams stay separate from the global RNG.** That separation is the
  reason those three RNGs were created as instances in the first place --
  a decor draw on the global stream shifts every gameplay roll after it,
  silently, with no probability having changed. `DecorRng` never calls
  global `seed()`/`randf()`; it hands out `RandomNumberGenerator` instances
  and either `randomize()`s them or assigns `.seed`. **Verified, not
  asserted: all seven gated bot probes are byte-identical before and after,
  at seed 20260806** -- plus `AssetContractAudit` and `ChargerShapeProbe`,
  and confirmed twice, on two independent cycles. If they had moved, the
  isolation would be broken and that would matter more than this fix.
- **Seeding is opt-in and probe-driven, not a new default.** The shipped
  game never calls `force_seed()`, so its decor is entropy-driven exactly
  as before -- no loss of visual variety between sessions. It is
  deliberately *not* wired to DevSeed's `--seed=` flag: `scripts/dev/` is
  excluded from the export, so shipped code cannot reference `DevSeed` at
  all, and a probe reproducible only when the caller remembers a flag is
  the precise failure mode F6 was.

`PursuerContrastAudit` is fixed outright by this: **three runs, identical
reported table**, the gauge column included -- it previously swung
8.73-9.60 in the light phase alone.

> **One caveat on every "byte-identical" claim in this document, found
> while checking this one.** Godot intermittently emits
> `Function blocked during in/out signal ... set_monitoring` on stderr --
> the pre-existing `Area3D.monitoring` race `TrackSegment.gd`'s class doc
> already describes. It depends on machine timing, not on code: across
> four validation cycles here it appeared in 1 of 9 runs of one probe and
> 0 of 3 of another, on **both** sides of the change. A raw `diff` of two
> runs of unmodified code can therefore differ by that line alone. The
> comparisons below filter it, which is the honest comparison -- not
> filtering it would report a code change that did not happen.

`StrikeFatalContrastAudit` was **not**, and that is the useful part.

#### F10c -- the decor was not the main thing wrong with StrikeFatalContrastAudit

Seeded, re-run three times, it still disagreed with itself: one failing
palette, then two, then none. The measurement said the residual was not
random at all. Three hypotheses were tested and **discarded on evidence**
rather than reasoned about -- the pursuer vignette (varies in the 4th
decimal), the camera shake the probe's own two strikes arm (trauma already
0 at capture), and the invert shader's uniforms (identical). Dumping the
background frames and differencing them localised it: **99% of pixels
differed, by a near-constant offset** -- a whole-screen wash, not a scene
change.

It is `HUD/StrikeFlash`: a **full-screen white ColorRect** that HUD ramps
to `STRIKE_FLASH_MAX_ALPHA` (0.55) over `STRIKE_FLASH_DURATION_S` (0.30s)
on every strike -- and this probe fires **two real strikes** immediately
before it captures. Two frames later, where it stops HUD's `_process`, the
flash is still near peak. Measured at capture: **alpha 0.47-0.55, decided
by how fast the machine rendered two frames.**

So the probe's "background" was up to **half a white wash at an
uncontrolled opacity**, and had been since it was written. The decor was a
real contributor but a second-order one.

Pinned to rest for the capture -- the same treatment, and the same
argument, this probe already applies to the fatal pulse: the flash is a
transient impact cue, the fatal label persists for the rest of the run, and
a contrast floor measures colour, not motion.

**Result: the verdict is now identical on every run.** Three runs, all
seven phases, same PASS/FAIL. Residual numeric jitter is <= 0.01 in the six
dark phases and <= 0.17 in the light phase (6.02-6.19, against a 3.0 floor
-- no verdict is anywhere near it). The light-phase residual is not chased
here; it is recorded rather than rounded away.

**The failing set changed, and it must not be read as a fix.** It moved
from "DARK/0, DARK/4 or DARK/5, depending on the run" to a stable **DARK/5
at 2.99:1** -- 0.01 under the floor. Nothing about the HUD's colours was
touched. The old numbers were measurements of a white overlay; the new ones
are measurements of the game. The failure is still open and still belongs
to its own batch.

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

> **Superseded in part by F10 (see Findings).** `PursuerContrastAudit`'s
> `rc 0` in this table was measured against the wrong surface and against
> the placeholder Keepy; corrected, it is red. The count is **22 of 25**.
> `StrikeFatalContrastAudit` was already red here, but its numbers -- and
> which palettes they blamed -- were not reproducible. Both rows are
> annotated below.

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
| PursuerContrastAudit | **1** | 96s | **stale green -- see F10a.** `rc 0` here was pursuer-vs-placeholder-Keepy; corrected, `DARK/2` fails |
| DarkPaletteAudit | 0 | 155s | |
| PursuerAudit | 0 | 166s | gated bot probe |
| StrikeAudit | 0 | 227s | gated bot probe; slowest that finishes |
| **StrikeFatalContrastAudit** | **1** | 60s | **real FAILURE, pre-existing -- see below.** Since F10c the failure is *reproducible*: stable `DARK/5` at 2.99:1 |
| **LiveRunProbe** | **124** | -- | needs `--quit-after`, by design -- see below |

All seven gated bot probes (AntiFrustration, Combo, Pursuer,
PursuerFraming, RushFrustration, Shrink, Strike) are green
**simultaneously at one seed**, each with its coverage ledger satisfied.
That is the baseline the Meshy import should be measured against.

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

> **F10 corrects the paragraph above, and the count above it.** The
> run-to-run difference was NOT the unseeded global stream -- that stream
> feeds gameplay rolls, and this probe's world is frozen. It was HUD's
> full-screen `StrikeFlash`, frozen mid-decay at an alpha set by machine
> speed (0.47-0.55), with unseeded decor as a smaller second term. Both
> are fixed in F10b/F10c, and the failure is now a stable **one** palette:
> `DARK/5` at 2.99:1. Being pre-existing and a design question, it is
> still deliberately not fixed.

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

## Still open after this batch

- **`StrikeFatalContrastAudit` fails on `DARK/5`, at 2.99:1.** A real
  legibility defect in the shipped HUD, verified pre-existing on
  `origin/main`, deliberately left for its own batch. Since F10c it is a
  *reproducible* failure -- same palette, same number, every run -- where
  before it named 0, 1 or 2 palettes depending on the run. ("2-3 palettes,
  the only red verdict in the suite" was this entry's earlier wording; both
  halves were wrong, see F10.)
- **`PursuerContrastAudit` fails on `DARK/2`, at 2.37:1** against its own
  2.5 silhouette floor -- the pursuer is genuinely hard to read against
  green-tinted ground. Newly *visible*, not newly true: the probe was
  measuring Keepy until F10a. Left open deliberately -- the floor was not
  moved to make it pass, and F10a records why the pursuer's own colour has
  no headroom to give.
- **Nothing measures the pursuer against Keepy.** F10a stopped this being
  measured by accident under the wrong label; it has not been replaced. The
  numbers that existed (1.85:1 at worst) are low enough that this wants a
  probe of its own, alongside the Keepy-vs-ground probe `docs/MESHY_SPEC.md`
  §11 already asks for.
- **The other pixel probes still take their background unseeded.**
  `ComboContrastAudit`, `StrikeContrastAudit`, `DarkPaletteAudit` and
  `InvertCapture` all sample the 3D world without calling
  `DecorRng.force_seed()`, so they carry F10b's exposure. None was measured
  for it here. The fix is the one line the two probes in this batch now
  carry.
- **Nine probes still ignore `--seed`** (no `DevSeed.apply()`):
  `StomperAudit`, `JumpDodgeRewardAudit`, `DarkPaletteAudit`,
  `LiveRunProbe`, `AssetContractAudit`, `ChargerShapeProbe`,
  `ComboContrastAudit`, `StrikeContrastAudit`,
  `StrikeFatalContrastAudit`, `PursuerContrastAudit`. For most it is
  harmless (they never run a real seeded run). For the first four it
  means "I passed `--seed`" is not evidence the run was reproducible --
  which is precisely how F6 hid. Not fixed here because none is in the
  reference baseline's gated set. (F10b does not change this: the two
  contrast probes it touches seed their **decor** streams from their own
  `DECOR_SEED` const, deliberately not from `--seed` -- see `DecorRng.gd`
  for why. They still ignore `--seed` for the global stream.)
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
