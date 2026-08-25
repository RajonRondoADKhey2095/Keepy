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
