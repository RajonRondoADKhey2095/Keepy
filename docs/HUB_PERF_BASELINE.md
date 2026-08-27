# Hub perf baseline

A reference measurement of `scenes/HubWorld.tscn`, taken right after the
MultiMesh decor refactor (259 -> 47 individual mesh nodes + 8 MultiMesh
batches) and BEFORE any Meshy asset lands on the plateau. Its only purpose
is to give a future asset install something concrete to be compared
against, instead of a guess about whether it "costs too much".

Produced by `scripts/dev/HubPerfBaseline.gd` /
`scripts/dev/HubPerfBaseline.tscn` -- a permanent, dev-only probe (excluded
from every export by `export_presets.cfg`'s `exclude_filter` on
`scripts/dev/*`, same as every other file in that folder). It asserts
nothing and always exits 0: there is no "correct" frame time for a hub
that has shipped zero `.glb`s yet, only a number worth writing down.

## ⚠️ WHAT THIS FILE CANNOT TELL YOU

This sandbox has no GPU. Every number below was rendered through
**llvmpipe** (software) under **xvfb** -- a real `--rendering-driver
opengl3` run, but not a real device, and not even a real desktop GPU.
**Do not read the FPS numbers below as an absolute verdict on device
fluidity.** What they CAN do, on the exact same renderer, is detect
**drift**: if a future asset add makes this same probe read slower on
this same software renderer, that is real signal a device test would only
confirm, not discover. A device test is still the only thing that answers
"does this feel smooth on a phone".

The FPS figure is timed on real wall-clock (`Time.get_ticks_usec()`
between `process_frame` yields), not on `--fixed-fps`'s reported delta --
that flag overrides the delta the engine *reports* to a fixed 1/60s, it
does not reflect how long a frame actually took to build and draw. See
the probe script's own header for the full argument. `--fixed-fps 60` is
still passed on the command line for every run in this file, purely so a
future run uses the identical engine flags this one did.

## How to reproduce a measurement

```
godot4 --headless --path . --import          # once, if .godot/ is stale
xvfb-run --rendering-driver opengl3 godot4 --path . --fixed-fps 60 \
  res://scripts/dev/HubPerfBaseline.tscn
```

Run without `--headless`: that flag forces the DUMMY rendering driver and
silently overrides `--rendering-driver opengl3` (a trap already documented
elsewhere in `CLAUDE.md`), which would make the FPS figure meaningless
(no real frame is ever built or drawn).

## Baseline — 25 aout 2026

- **Commit**: `ffcc552` (`docs: clarify why the stump prop type stays
  unbatched`, the tip of `origin/main` at measurement time).
- **Renderer**: xvfb + `--rendering-driver opengl3`, llvmpipe (software).
- **Method**: exact command above, `_WARMUP_FRAMES = 30`,
  `_SAMPLE_FRAMES = 180`.

⚠️ **The FPS figures are NOISY, measured and not smoothed over.** Three
consecutive runs on the same commit, same machine, same command gave mean
14.5 / 16.4 / 16.2 fps and min 12.4 / 7.7 / 10.8 fps — this sandbox shares
its CPU with other work, the same reason `TrackPropsAudit`'s un-seeded
frame counts already vary run to run elsewhere in this project. The
**draw node counts are exact and reproduced identically on all three
runs** (they come from a fixed tree, not a clock); the FPS figures below
are reported as **ranges across 3 runs**, not a single number, precisely
so a future comparison is not fooled by picking one lucky or unlucky run
on either side.

| metric | value | method |
|---|---|---|
| construction time | **45.3 – 52.4 ms** (3 runs: 52.39, 45.32, 48.61) | `instantiate()` + full `_ready()` cascade of `HubWorld.tscn`, wall-clock (`Time.get_ticks_usec()`) |
| draw nodes, HubBuilder only (excl. portals) | **55** (47 individual `MeshInstance3D` + 8 `MultiMeshInstance3D`), identical on all 3 runs | individual `MeshInstance3D` built by `HubBuilder` + its `MultiMeshInstance3D` batches, counted on the live tree under `Props` |
| draw nodes, total (HubBuilder + 3 portals) | **61** (55 + 6 `MeshInstance3D` owned by the 3 `HubPortal` instances), identical on all 3 runs | the above plus the `MeshInstance3D` nodes owned by the 3 `HubPortal` instances |
| simulated FPS, mean | **14.5 – 16.4 fps** (3 runs) | real wall-clock between `process_frame` yields, 180 frames after a 30-frame warm-up, the plateau camera's own `_process` cut before sampling to remove its follow-lerp as a noise source |
| simulated FPS, min | **7.7 – 12.4 fps** (3 runs) | the single worst frame (largest wall-clock delta) in that same 180-frame sample |
| `index.pck` | **5 833 104 octets** (clean export; two other exports of the same commit this session read 5 833 120 and 6 238 208 — the pre-existing, already-documented instability, not a defect of this measurement) | size of a fresh, clean export (`build/` removed first — see the permanent warning in `CLAUDE.md` on `.pck` size instability between exports of the same commit) |
| `index.wasm` | **35 376 909 octets**, md5 `af4a8fc2925d992348eb30deeeb54360` — **identical on all 3 exports this session** | same export; this is the file whose size/md5 should be treated as the identity check across builds, not `.pck` |

`index.js` md5 `4e08904b1b7107858246af44b602067b`, also identical across
all 3 exports. Payload trap re-checked on this export's `savepack` log:
**0** `Storing File` lines for `assets_source`, `scripts/dev`, `docs` or
`web` — `scripts/dev/HubPerfBaseline.gd`/`.tscn` included, confirmed
absent from the pack.

**Deployed to staging.** CI run #219 (`web-build.yml`) green on `staging`
`7aae0a4`. Verified **on the live service, not just the CI log**:
`keepy-staging.vercel.app`'s served `CACHE_VERSION` moved
`1787647515` (08:45:15 UTC, pre-merge) -> `1787651782` (09:56:22 UTC),
inside the run's own window (09:53:29 -> 09:56:51), `x-vercel-cache: MISS`
on both reads. The served `GODOT_CONFIG.fileSizes.index.wasm` is
`35376909` — identical to the local export above, as expected since this
change touches no Godot engine code.

## Comparisons

One row per future addition. Same method, same probe, same renderer as
the baseline row above — that is the entire point of keeping this file
instead of a one-off number in a session report.

| date | change | construction (ms) | draw nodes (excl. portals) | draw nodes (total) | FPS mean | FPS min | index.pck | index.wasm |
|---|---|---|---|---|---|---|---|---|
| 25 aout 2026 | baseline (no Meshy asset yet) | 45.3–52.4 | 55 | 61 | 14.5–16.4 | 7.7–12.4 | 5 833 104 | 35 376 909 / `af4a8fc2` |
| 25 aout 2026 | `KeepyHopper.HOP_DURATION` 0.35 → 0.28 (hop tuning; **no scene, no layout, no prop, no camera change**) | 47.8–65.3 | 55 | 61 | 15.1–16.7 | 8.7–10.4 | 5 833 088 | 35 376 909 / `af4a8fc2` |
| 25 aout 2026 | `HubTapInput.PLATEAU_HALF_EXTENT` 25 → 35 **+ 4 landmarks at r ~30** (far ring; no camera change, no `HOP_*` change, no new prop type) | 36.8–38.8 | **72** | **78** | 27.0–27.6 | 14.8–19.6 | 5 833 648 / 5 833 728 | 35 376 909 / `af4a8fc2` |
| 25 aout 2026 | new `&"lake"` prop type: **one** water body at (-25.10, -5.30), 2.5x the pond (water r 8.0, bank r 9.05, 40 segments) + 4 rim rocks (batched) + 3 props relocated out of its footprint. **No camera, no `HOP_*`, no `PLATEAU_HALF_EXTENT` change.** | 43.3–46.6 | **74** | **80** | 15.2–16.6 | 8.1–12.9 | 5 834 608 | 35 376 909 / `af4a8fc2` |
| 25 aout 2026 | new `&"stream"` prop type: **one** hand-built ribbon connecting the pond to the lake, 12 control points, width 1.2, 176 triangles. **No prop moved, no camera, no `HOP_*`, no `PLATEAU_HALF_EXTENT` change.** | 46.2–49.7 | **75** | **81** | 16.3–17.0 | 12.0–12.6 | 5 838 128 | 35 376 909 / `af4a8fc2` |
| 26 aout 2026 | the stream becomes RIDEABLE: new `&"boat"` prop type (**one** hull, 3 meshes: shell / inner shell / rim), a `RIDING` state in `KeepyHopper`, `BoatMooring`, `HubStreamRoute`. **No prop moved, no camera, no `HOP_DISTANCE`/`HOP_DURATION`, no `PLATEAU_HALF_EXTENT` change.** | 38.3–40.9 | **78** | **84** | 23.7–27.0 | 11.6–19.9 | 5 853 648 | 35 376 909 / `af4a8fc2` |
| 26 aout 2026 | **lake zone**: `HubRegion` (the walkable limit becomes a shape: square +-35 OR shore pad, MINUS the great lake's water), new `&"greatlake"` / `&"islet"` / `&"pontoon"` types, 1 lake (r 20 at 54 u, 96 segments) + 3 islets + 3 landmarks + 5 pontoons (batched) + 21 shore props + 1 prop relocated. **No camera, no `HOP_*` change; `PLATEAU_HALF_EXTENT` still 35.** | 37.5-39.7 | **96** | **102** | 21.6-22.1 | 17.5-18.4 | 5 862 224 | 35 376 909 / `af4a8fc2` |

**Reading of the stream row.** **+1 draw node, exactly the one the change
adds**, identical on all three runs — a stream is a single one-off ribbon
mesh, so there is nothing for a `MultiMesh` to repeat and nothing else in
the tree moved. That is the number this row exists to carry. Construction
(46.2–49.7 ms) sits inside the band every previous row has occupied, and
the FPS figures overlap the baseline's; neither is offered as evidence the
plateau got faster or slower, because this sandbox renders through
llvmpipe and 176 triangles is not a quantity a software rasteriser
notices. `index.pck` grows by 3 520 octets against the lake row — the
layout entry plus the builder code — and is offered only as corroboration,
never as proof: its size is not stable between exports of the same commit.
`index.wasm` is byte-identical, which is the actual identity check.

**Reading of the second row.** The **draw node counts are the numbers
that matter here, and they are identical to the baseline on all three
runs** — as they must be: this change edits one float in one script and
adds nothing to the tree. Everything else on the row is inside the
sandbox's own documented noise. Construction overlaps the baseline range
on two of three runs and puts one at **65.3 ms**, above it; FPS mean and
min both overlap. Nothing here is evidence of a cost, and — read the
warning above — **nothing here is evidence of a gain on a device
either**: this probe cannot see a hop at all, because it never taps, so
Keepy never moves during the sample.

`index.pck` is 16 bytes under the baseline, which is a comment edit in a
`.gd` plus the permanent `.pck` instability already documented in
`CLAUDE.md` — not a signal. `index.wasm` is byte-identical (same size,
same md5), the expected result for a change that touches no engine code,
and it is that file, not the `.pck`, that carries the identity check.

**Reading of the third row — READ THE CONTROL RUNS FIRST, NOT THE BASELINE
ROW.** This row's FPS figures (27.0–27.6 mean) are roughly **double** the
baseline row's (14.5–16.4). That is **not a speed-up**, and reading it as
one would be the single most likely mistake this file can invite: it is a
different day on a shared-CPU sandbox, and this run's llvmpipe simply had
more of the machine. The only comparison worth anything here is against
**three BEFORE runs taken in the same session, on the same machine, minutes
apart, on the parent commit**:

| | construction (ms) | draw excl. portals | draw total | FPS mean | FPS min |
|---|---|---|---|---|---|
| BEFORE (3 runs, parent commit) | 38.5 / 40.1 / 42.6 | 55 | 61 | 26.5–27.3 | 14.8–21.0 |
| AFTER (3 runs, this commit) | 36.8 / 38.1 / 38.8 | **72** | **78** | 27.0–27.6 | 14.8–19.6 |

**The draw node counts are the numbers that matter, and they are the only
ones that moved outside noise.** 55 → 72 excluding portals, 61 → 78 total:
exactly **+17 individual `MeshInstance3D`**, which is exactly what four
landmarks cost at cairn 5 + spire 4 + cairn 5 + slabs 3. The 8 MultiMesh
batches are untouched, as they must be — landmarks are not batched (see
`HubBuilder.gd`'s header for why). That leaves **188 under the 260
ceiling**, against 205 before.

Everything else is inside the sandbox's own documented noise, and in the
direction that proves it: construction is *lower* after adding 17 nodes
(36.8–38.8 vs 38.5–42.6) and FPS mean is flat (27.0–27.6 vs 26.5–27.3).
Construction genuinely getting faster while the tree grows is not a real
effect — it is the noise floor, restated. FPS min overlaps on the low end
at 14.8 on both sides.

And, as with every row here: **none of this is evidence about a device.**
A software renderer with no GPU cannot tell you whether four more silhouettes
at 30 units read well or cost anything on a phone. What it can tell you is
that nothing structural changed, and that the node budget moved by exactly
the amount predicted before the change was made.

`index.pck` is 5 833 648 on one clean export of this commit and 5 833 728 on
a second — the pre-existing instability documented in `CLAUDE.md`, here
bracketing rather than hidden behind a single number. Both are ~560–640
bytes over the previous row, consistent with 24 added lines of layout data
and an edited docblock. `index.wasm` is **byte-identical** (35 376 909,
md5 `af4a8fc2`) to both earlier rows, the expected result for a change that
touches no engine code — and it, not the `.pck`, is the identity check.
Payload trap re-checked on this export's own `savepack` log: **0** `Storing
File` lines for `assets_source`, `scripts/dev`, `docs` or `web`, out of 219
stored files.

**Deployed to staging.** CI run #226 (`web-build.yml`) green on `staging`
`aa10500` — read at the JOB level (`build-and-deploy`: completed / success,
all 17 steps, staging deploy 13:18:46 → 13:18:58 UTC), because the RUN-level
status stayed frozen on `in_progress` with `updated_at` stuck at 13:14:25.
That frozen-run trap is already recorded against runs #201 and #202 in
`CLAUDE.md`; the job level and the served build both settle it.

Verified **on the live service, not just the CI log**, in both directions and
on two independent markers:

| marker | before | after |
|---|---|---|
| `CACHE_VERSION` (`index.service.worker.js`) | `1787658495\|4288515` (11:48:15, run #224) | `1787663911\|4242878` (≈13:18:31, inside run #226's export step 13:18:26–13:18:32) |
| `GODOT_CONFIG.fileSizes.index.pck` (`index.html`) | 5 833 088 | **5 833 616** |
| `GODOT_CONFIG.fileSizes.index.wasm` | 35 376 909 | 35 376 909 (unchanged, as expected) |

Both "before" readings (13:14:55 and 13:15:11) and both "after" readings
(13:20:54 and 13:21:16) came back `x-vercel-cache: MISS` with `age: 0`, so
neither end is a frozen CDN copy.

⚠️ **The lot D reading trap reproduced twice, and was refused both times.**
Re-reads at 13:16:05 and 13:18:20 came back `x-vercel-cache: HIT` with
`age` 53 and 189 — copies frozen before the deploy landed. A HIT with a
non-zero age is not a freshness measurement. Note also that a `?query`
cache-buster does NOT work here: Vercel normalises it away for these static
assets, so both busted reads hit the same cached object. What does work is
waiting for the new deployment (a new deployment has its own cache, so the
first read after it MISSes) or requesting a path not yet in the CDN cache.

The served `.pck` (5 833 616) differs from both local clean exports of this
same commit (5 833 648 / 5 833 728) by tens of bytes — the same documented
`.pck` instability the row above brackets, not a different build. The
`.wasm` is identical everywhere, and it is the file that carries the
identity check.

**Reading of the fourth row — again, READ THE CONTROL RUNS, NOT THE ROW
ABOVE IT.** The third row's FPS figures (27.0–27.6 mean) came from a day
when this shared-CPU sandbox had more of the machine; this row's 15.2–16.6
is back in the same band as the baseline row, and **neither difference is a
property of the code**. The only comparison that carries anything is against
three BEFORE runs taken in this same session, minutes apart, on the parent
commit `6b4b46f` in a separate worktree:

| | construction (ms) | draw excl. portals | draw total | FPS mean | FPS min |
|---|---|---|---|---|---|
| BEFORE (3 runs, `6b4b46f`) | 47.34 / 47.70 / 51.07 | 72 | 78 | 15.1–16.1 | 8.7–12.1 |
| AFTER (3 runs, this commit) | 43.27 / 45.05 / 46.63 | **74** | **80** | 15.2–16.4 | 8.1–12.9 |

**The draw node counts are the only numbers that moved outside noise, and
they moved by exactly the predicted amount: +2.** A lake is one
`_make_water_body()` node with two `MeshInstance3D` children (the opaque
bank and the alpha water), and it is not batched — same reason as the pond,
there is one of it. 72 → 74 excluding portals, 78 → 80 total, which leaves
**186 under the 260 ceiling** against 188 before. The 8 `MultiMesh` batches
are untouched: the four new rim rocks are `&"rock"` entries, so they cost
four *instances* in the existing `Rock` batch and **zero** nodes — the
adding-a-hundred-flowers-costs-no-nodes property `HubLayout.gd` documents,
used deliberately here rather than a new bordering type.

⚠️ **Draw nodes were 74 / 80 on SIX consecutive runs of this commit**, not
three: the first three were run before the construction timing was captured
and are counted here only for that column. Construction is *lower* after
adding two nodes (43.3–46.6 vs 47.3–51.1) — that is the noise floor
restating itself, not a speed-up, exactly as the third row's reading warns.
FPS mean and min both overlap the BEFORE range on every run.

And, as with every row: **none of this is evidence about a device.** A
software renderer with no GPU cannot say whether one alpha-blended disc 16
units across costs anything on a phone. What it can say is that the node
budget moved by exactly the amount predicted before the change was made, and
that nothing structural changed.

`index.pck` is 5 834 608 on a clean export of this commit (`build/` and
`.godot/` removed first), ~960–1 520 bytes over the third row's two readings
— consistent with 21 added lines of layout data plus a ~60-line docblock and
the new builder function, and inside the `.pck` instability `CLAUDE.md`
documents permanently. `index.wasm` is **byte-identical** (35 376 909, md5
`af4a8fc2925d992348eb30deeeb54360`) and so is `index.js` (md5
`4e08904b1b7107858246af44b602067b`), the expected result for a change that
touches no engine code — and it, not the `.pck`, is the identity check.
Payload trap re-checked on this export's own `savepack` log: **0** `Storing
File` lines for `assets_source`, `scripts/dev`, `docs`, `web` or `build`,
out of 219 stored files.

**Deployed to staging.** CI run #229 (`web-build.yml`) on `staging` `47dac76`.
Verified **on the live service, not just the CI log, and on TWO independent
markers**:

| marker | before | after |
|---|---|---|
| `CACHE_VERSION` (`index.service.worker.js`) | `1787664307\|4350600` (13:25:07, run #227) | **`1787669738\|4285704`** (**14:55:38**, inside run #229's window, started 14:52:15) |
| `GODOT_CONFIG.fileSizes.index.pck` (`index.html`) | 5 833 632 | **5 834 592** |
| `GODOT_CONFIG.fileSizes.index.wasm` | 35 376 909 | 35 376 909 (unchanged, as expected) |

Both "before" readings and both "after" readings came back
`x-vercel-cache: MISS` with `age: 0`, so neither end is a frozen CDN copy.

⚠️ **The HIT/age reading trap reproduced twice mid-run and was refused both
times** — re-reads at 14:53:01 and 14:53:36 came back `x-vercel-cache: HIT`
with `age` 102 and 137, copies frozen before the deploy landed. A HIT with a
non-zero age is not a freshness measurement, so those were not counted as the
"still the old value" proof.

⚠️ **The frozen-run trap reproduced too**: the Actions API held run #229 at
`status: in_progress` with `updated_at` stuck at 14:52:21 well after the
deploy had landed. The served `CACHE_VERSION` settled it, as it has on runs
#201, #202 and #226.

The served `.pck` (5 834 592) is 16 bytes under this session's clean local
export (5 834 608) — the documented `.pck` instability, not a different build.
`index.wasm` is identical everywhere, and it is the file that carries the
identity check.



---

## Lake zone (26 aout 2026) -- before / after, same session, same renderer

`origin/staging` measured in a separate worktree sharing this session's
import cache, so both ends ran on the same binary, the same machine and the
same `xvfb-run --rendering-driver opengl3`. 3 runs each.

| | construction (ms) | draw excl. portals | draw total | FPS mean | FPS min |
|---|---|---|---|---|---|
| BEFORE (3 runs, `origin/staging`) | 38.51 / 38.97 / 36.87 | 78 | 84 | 19.8-21.9 | 12.0-18.2 |
| AFTER (3 runs, this commit) | 37.52 / 38.57 / 39.67 | **96** | **102** | 21.6-22.1 | 17.5-18.4 |

**+18 draw nodes excluding portals, and the 18 are accounted for one by
one** rather than inferred from the total: the great lake's 2 discs, 3
islets at 1 each, 3 landmarks at 4 + 5 + 3 (spire / cairn / slabs), and 1
new `MultiMeshInstance3D` for the batched pontoons (8 batches -> 9).
Margin under the 260 ceiling: 182 -> **164**.

Everything else overlaps. The construction and FPS ranges cross between
before and after, which is the documented noise floor of this sandbox --
this row is evidence the change cost nothing measurable here, NOT evidence
it made anything faster. Nothing in it says how the plateau behaves on a
phone; llvmpipe under xvfb is a different machine.

⚠️ **`index.pck` is NOT usable as a build identity check, and this batch is
where that stopped being a nuance.** Three sizes have now been observed for
two states of content -- 5 853 728 / 5 853 744 / 5 853 760 -- including a
**16-byte difference across a comment-only commit**. It remains fine as a
"a new build was served" marker, which is how it is used in the deploy
tables above. The lot G inference -- "the served `.pck` matches this
session's local export byte for byte, therefore it is my build" -- is
INVALID and must not be replayed. `index.wasm` is the identity check.

**Deployed to staging.** CI run #242 (`web-build.yml`) on `staging`
`73d45d2`. Served `CACHE_VERSION` moves `1787698811` (25 aout 23:00:11,
run #241) -> **`1787728327`** (26 aout **07:12:07**), inside that run's
`Export Web build` step (07:12:03-07:12:08). Served `index.pck` = 5 862 224,
`index.wasm` = 35 376 909. All three useful readings are `x-vercel-cache:
MISS` with `age: 0`.

⚠️ Only `CACHE_VERSION` was read at BOTH ends this time; the served `.pck`
is an after-only reading, so it stands as a second independent marker of the
current state rather than as proof of the transition. The HIT/age trap fired
once mid-run (`age: 151`, an edge copy this session's own pre-merge read had
populated) and was refused rather than counted.



---

## LAKE-MOVE (26 aout 2026) -- the lake moves inside, and the node count does not

`origin/staging` measured in a separate worktree sharing this session's
Godot binary and machine, both ends under `xvfb-run --rendering-driver
opengl3`. 3 runs each. Imports verified complete on both trees (24 `.scn`)
before any number was read -- a truncated import is the documented way to
produce a false red here.

| | construction (ms) | draw excl. portals | draw total | FPS mean | FPS min |
|---|---|---|---|---|---|
| BEFORE (3 runs, `origin/staging`) | 37.81 / 36.74 / 37.87 | 96 | 102 | 27.1-27.3 | 8.5-14.6 |
| AFTER (3 runs, this commit) | 37.88 / 35.52 / 37.44 | **96** | **102** | 24.6-26.3 | 11.5-20.4 |

**The node count does not move, and that is the expected result**: this
batch relocates entries, it creates and deletes none. 87 individual
`MeshInstance3D`, 9 `MultiMeshInstance3D`, 6 owned by the portals, on both
sides. Margin under the 260 ceiling stays **164**. Construction overlaps
run for run -- 35.52 to 37.88 ms across both trees with no separation.

⚠️ **FPS mean is DOWN and the ranges do NOT overlap** -- 27.1-27.3 before
against 24.6-26.3 after, consistent across three runs each. Reported
rather than rounded away. The most likely cause is simply that the lake is
now IN FRAME: the probe samples from the plateau centre, where the shipped
lake was 0% visible and the moved one covers 39% of the disc, so a large
alpha-blended water disc plus 3 islets have entered the fill-rate budget
that used to be empty grass. That is a real cost of the placement, not a
regression in the layout.

⚠️ **It is also the number in this table least worth trusting.** llvmpipe
under xvfb is a software rasteriser: fill rate is exactly what it is worst
at and exactly what a phone GPU is best at, so a fill-bound delta here
over-states the device cost by an unknown factor. Nothing in this row says
how the plateau behaves on a phone. **Device judgement.**

## SPAWN-LAKE-1 -- a second great-lake lobe (r10 at -12,-19.5) + one uniform water colour

Same Godot binary and machine, both ends under `xvfb-run --rendering-driver
opengl3`, 3 runs each, **run one at a time**. Imports verified complete on
both trees (24 `.scn`) before any number was read.

| | construction (ms) | draw excl. portals | draw total | FPS mean | FPS min |
|---|---|---|---|---|---|
| BEFORE (3 runs, `origin/staging`) | 57.42 / 47.55 / 63.07 | 96 | 102 | 14.3-15.0 | 6.1-7.8 |
| AFTER (3 runs, this batch) | 48.91 / 51.81 / 49.41 | **98** | **104** | 14.4-15.4 | 7.2-11.0 |

**+2 draw nodes, and that is the whole cost**: the new lobe is one bank
disc and one water disc, exactly like every other standing water here. 89
individual `MeshInstance3D` against 87 before, 9 `MultiMeshInstance3D` on
both sides (unchanged -- the lobe is not batched, there is one of it),
6 owned by the portals. Margin under the 260 ceiling: **164 -> 162**.

⚠️ **FPS did NOT drop, and the honest reading of that is "the ranges
overlap", not "it got faster"**: 14.3-15.0 before against 14.4-15.4 after,
with construction overlapping too (47.55-63.07 against 48.91-51.81). That
is a different result from LAKE-MOVE-1's row, which measured a clear drop
when the great lake first entered the frame. The likely reason the second
lobe does not repeat it: the probe samples from the plateau CENTRE, where
the great lake already occupies the frame, so the new lobe mostly adds
alpha to a budget that was already paying for water rather than to empty
grass.

⚠️ **DO NOT COMPARE THIS TABLE'S FPS TO THE ROWS ABOVE IT.** They were
measured in a different sandbox and run 27-ish fps for the same scene where
this one runs 15. Only the BEFORE/AFTER pair inside a single row block is
comparable, because only that pair shares a machine and a session.

⚠️ And as ever: llvmpipe under xvfb is a software rasteriser -- fill rate is
exactly what it is worst at and exactly what a phone GPU is best at, so
nothing in this row says how the plateau behaves on a phone. **Device
judgement.**

## DIVING BOARD (27 aout 2026) -- the plateau's first climbable prop

Same Godot binary and machine, both ends under `xvfb-run --rendering-driver
opengl3`, 3 runs each, **run one at a time**. Imports verified complete on
both trees (24 `.scn`) before any number was read.

| | construction (ms) | draw excl. portals | draw total | FPS mean |
|---|---|---|---|---|
| BEFORE (3 runs, `origin/main`) | 35.81 / 36.49 / 42.89 | 98 | 104 | 22.6-23.3 |
| AFTER (3 runs, this batch) | 37.44 / 45.74 / 38.07 | **106** | **112** | 22.3-23.2 |

**+8 draw nodes, and the eight are itemised rather than inferred from the
total**: `DivingBoardProbe` PHASE E walks the live tree and reports **7
mesh nodes** (one plank, four posts, two ladder rails) **plus one
`MultiMeshInstance3D` carrying 5 rungs**. A total that moved by the right
amount for the wrong reason is exactly what an itemisation catches, so the
7 and the batch are both gated, not merely printed. Margin under the 260
ceiling: **162 -> 154**.

The rung run is the one part of this prop a `MultiMesh` is for -- identical
geometry repeated up a ladder. Five rungs cost one draw node; the plank and
posts are one-offs and cost their own.

⚠️ **FPS did not move, and the honest reading is "the ranges overlap"**:
22.6-23.3 before against 22.3-23.2 after, with construction overlapping too
(35.81-42.89 against 37.44-45.74). Which is what a prop of this size on the
far bank should do -- unlike LAKE-MOVE-1, nothing here puts new fill into
the middle of the frame.

⚠️ **DO NOT COMPARE THIS TABLE'S FPS TO THE ROWS ABOVE IT.** Only the
BEFORE/AFTER pair inside one row block shares a machine and a session. This
sandbox runs ~23 fps for the scene the SPAWN-LAKE-1 sandbox ran at ~15 and
an earlier one at ~27.

⚠️ **A GAP IN THIS FILE, CONSTATED AND NOT PAPERED OVER.** The last row
before this one is SPAWN-LAKE-1: `grep -ci "shader\|waterline"` over this
file returns **0**, and `git log -- docs/HUB_PERF_BASELINE.md` confirms the
newest commit touching it is `e7c45cf` (SPAWN-LAKE-1). None of the eight
waterline/shader commits between it and this batch wrote a row here.

To be precise about what that is and is not: those commits do NOT claim in
their messages to have added one (`grep -ci "HUB_PERF_BASELINE"` over them
returns 0). They measured -- CLAUDE.md records "98 / 104 draw nodes,
unchanged" and three `HubPerfBaseline` runs per side for the waterline
batch -- and published the numbers in CLAUDE.md instead of here, which is
the file that exists to hold them. So this is a convention drift, not a
false claim.

**The missing rows are NOT reconstructed here.** They would be numbers from
another sandbox, entered by someone who did not take them, into a table
whose entire value is that each row's two halves were measured together.
The BEFORE column above is measured on `origin/main` in this session, so it
already carries whatever the waterline batch cost -- this row is complete
on its own terms, and the gap behind it stays visible.

⚠️ And as ever: llvmpipe under xvfb is a software rasteriser -- fill rate is
exactly what it is worst at and exactly what a phone GPU is best at, so
nothing in this row says how the plateau behaves on a phone. **Device
judgement.**

---

## DIVING BOARDS 2 AND 3 (27 aout 2026) -- one per remaining large water body

Two more `&"divingboard"` entries: one on the small lake's north-east bank,
one on the great lake's spawn lobe. No new prop TYPE and no new geometry
code -- `_make_divingboard()` was already generic, and each new entry is
the same seven mesh nodes the first one is.

Same session, same renderer, same machine, runs taken ONE AT A TIME so the
two sides are not measuring each other's contention.

| | construction (ms) | draw excl. portals | draw total | FPS mean | FPS min |
|---|---|---|---|---|---|
| BEFORE (3 runs, `origin/main`) | 51.93 / 44.61 / 42.50 | 106 | 112 | 26.4-27.1 | 22.6-22.9 |
| AFTER (3 runs, this batch) | 42.03 / 42.53 / 42.36 | **120** | **126** | 26.5-27.3 | 12.1-20.8 |

**+14 draw nodes, and the number is itemised rather than asserted**: two
boards x seven mesh nodes each (one plank, four posts, two rails). The
**MultiMesh batch count does not move** -- it stays at 10. The rung batch is
keyed by mesh and colour, so three ladders share ONE node and it simply
carries 15 instances where it carried 5. Margin under the 260 ceiling:
**140**.

⚠️ **The BEFORE column was RE-MEASURED, not copied from the previous row.**
It comes out at 106/112, which does agree with what the diving-board batch
published -- but agreeing is a result, not a licence to have skipped it.

⚠️ **FPS mean is flat (the two ranges overlap); FPS MIN is not, and the
honest reading is "one bad frame", not "slower".** Two of the three AFTER
runs sit at 20.3-20.8 against a BEFORE band of 22.6-22.9 -- a real but
small step. The third reports 12.1, which is a single worst frame in one
sample and is the kind of outlier this software rasteriser produces on a
shared machine; it is published rather than dropped, and it is not
evidence of a 2x cost. Construction is flat-to-better and says nothing
either way.

⚠️ llvmpipe under xvfb, as ever: fill rate is what it is worst at and what
a phone GPU is best at. Fourteen small opaque unshaded boxes and cylinders
are close to the cheapest thing that can be added to this scene. **Device
judgement.**
