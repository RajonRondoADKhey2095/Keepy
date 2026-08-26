# WATER-ACCESS-RENDER RECON -- immersion geometry, measured, for the "Keepy
walks into the five waters" batch

**26 aout 2026. RECON ONLY: this batch changes no gameplay file.** Branch
`claude/keepy-water-recon-3w83et`, built on top of
`claude/keepy-water-collision-recon-6w1a0a` (`7b04132`,
`docs/WATER_WALK_RECON.md`) rather than directly on `origin/staging`
(`2ba12e0`) -- that predecessor branch had not yet reached `staging` when
this one started, and its file is what this brief's preamble asks to read
first. `origin/main` is `ae13b99`, `origin/staging` is `ab37db0` + `2ba12e0`,
both exactly as the brief expected. Refs sorted by date, trees compared
rather than names -- no branch carries this brief, no concurrent session.

**Mathieu's decision, restated so nothing below re-litigates it**: Keepy
must be able to enter all five water bodies (pond, small lake, stream, and
the great lake's two lobes). The existing guard on the two great-lake lobes
will be REMOVED in the next batch. `docs/WATER_WALK_RECON.md`'s "bank stop"
line of work is ABANDONED and not reused here except where this brief names
it explicitly (the float32 rim discipline, Q2's membership test). The boat
is OUT OF SCOPE and not touched or discussed.

Every number below comes from two THROWAWAY probes driving the shipped
`scenes/HubWorld.tscn`, `KeepyHopper`, `HubBuilder` and `HubRegion` --
`WaterRenderReconProbe` (numeric, `--headless --fixed-fps 60`) and
`WaterImmersionCaptureProbe` (pixels, `xvfb-run --rendering-driver opengl3`,
never `--headless` -- that forces the DUMMY driver and a 0x0/garbage
viewport, a trap this repo has already paid for once and this recon paid
for again independently, see Q6). Both probes are deleted before this
commit.

---

## Q1 -- Keepy's vertical position is a pure procedural parabola, never terrain

`scripts/hub/KeepyHopper.gd`, read in full, then confirmed live:

| line | function | what writes `y` |
|---|---|---|
| 418-430 | `_advance()` | decides HOP vs arrival; writes nothing itself |
| 432-452 | `_begin_hop(here, delta)` | sets up `_hop_from`/`_hop_to` (x/z only) and the tween driving `_apply_hop` |
| 467-474 | `_apply_hop(t)` | `height = _hop_height * 4*t*(1-t)`; `global_position = Vector3(ground.x, height, ground.z)` |
| 488-504 | `_on_hop_finished()` | snaps `global_position` to `(_hop_to.x, 0.0, _hop_to.z)` -- **`y = 0.0` literally** |
| 363-369 | `_place_on_route()` (RIDING) | `global_position = Vector3(where.x, RIDE_SEAT_Y, where.z)` -- **`y = 0.14` constant** |

**MEASURED, not read alone**: booting the real `HubWorld.tscn` and reading
`Keepy.global_position.y` at rest gives `0.000000`. `grep`-ing the whole
file for `Ray`, `PhysicsDirectSpaceState`, `intersect`, `terrain` returns
nothing: there is no terrain-following and no collision anywhere in this
file. `y` is 100% procedural, one of exactly two shapes -- the 4t(1-t)
parabola while hopping (peak `HOP_HEIGHT = 0.6`, i.e. 44.4% of the measured
model height, see Q5), or a hard-coded constant at rest (`0.0`) and while
riding (`RIDE_SEAT_Y = 0.14`).

**Consequence for a sink mechanic**: there is exactly ONE clean insertion
point for "how far underwater", and it is a Y OFFSET added on top of what
is already written -- at the idle branch of `_advance()`/`_on_hop_finished()`
for a standing sink, and composed into `_apply_hop`'s `height` for a sink
that also has to survive being airborne. `RIDE_SEAT_Y` is untouched by this
recon and out of scope (the boat).

## Q2 -- five water tops, five different heights, all within 10cm of Keepy's rest Y

Read from `scripts/hub/HubBuilder.gd`'s own slab constants (`_make_water_body`,
`GREATLAKE_BANK_SLABS`/`GREATLAKE_WATER_SLABS`, `STREAM_SURFACE_Y`) and
confirmed by booting the scene:

| body | centre | radius | water TOP y | alpha |
|---|---|---|---|---|
| pond | (20.70, 7.40) | 3.2 | **0.0800** | 0.95 |
| small lake | (-25.10, -5.30) | 8.0 | **0.0800** | 0.95 |
| stream | ribbon, half-width 0.6 | -- | **0.0950** (flat, NO bank) | 0.90 |
| great lake A | (15.5, -19.0) | 16.0 | **0.0270** | 0.95 |
| great lake B (spawn lobe) | (-12.0, -19.5) | 10.0 | **0.0295** | 0.95 |

Keepy's rest `y` is `0.0000` exactly (Q1). Every water top sits ABOVE that
by a few centimetres -- **stream highest (0.0950) to great lake A lowest
(0.0270), a 3.5x spread**, all five inside a 6.8cm band. Note in passing:
this means that even at 0% sink, a player standing over any of the five
already has his feet nominally a hair "under" that body's own water top --
and per Q3, that never shows, because nothing currently draws the water OVER
him regardless of how far under he nominally is.

## Q3 -- MEASURED: neither hypothesis. The water NEVER draws over Keepy, at any depth, at either alpha

**This is the premise that fails, published rather than smoothed over.**
The brief posed a binary -- "legible immersion OR the body disappearing
brutally". The measured outcome is a THIRD thing, worse than either named
option: **the body is ALWAYS fully, opaquely visible, with ZERO visual sign
of being in water, at 0%, 30% and 60% synthetic immersion, in both the
stream (a=0.90) and great lake B (a=0.95).**

Method: `WaterImmersionCaptureProbe`, real `HubWorld.tscn`, camera frozen at
the pose `HubCamera._wanted()` would settle to (ground + `(0,7.6,8.9)`),
Keepy's `global_position.y` set directly to `water_top - f*H` (H = the
measured model height, Q5) so a fraction `f` of his height sits below that
body's own water top. For every (body, f) pair it renders THREE frames at
the identical screen pixel (Keepy's geometric mid-height) -- the real scene
(BOTH), the matched water `MeshInstance3D` hidden (KEEPY-ONLY), and Keepy
hidden (WATER-ONLY) -- and diffs them:

| body | f | screen y (of 1920) | BOTH vs KEEPY-ONLY | BOTH vs WATER-ONLY | verdict |
|---|---|---|---|---|---|
| stream (a=0.90) | 0% | 1039.8 | **identical** (dist 0.0000) | dist 1.133 | IN-FRONT |
| stream | 30% | 1076.5 | identical | dist 1.137 | IN-FRONT |
| stream | 60% | 1111.9 | identical | dist 1.149 | IN-FRONT |
| great lake B (a=0.95) | 0% | 1045.9 | identical | dist 1.180 | IN-FRONT |
| great lake B | 30% | 1082.4 | identical | dist 1.177 | IN-FRONT |
| great lake B | 60% | 1117.4 | identical | dist 1.188 | IN-FRONT |

**All six: BOTH == KEEPY-ONLY to the last decimal.** The predicted
over-blend (`water_albedo*alpha + keepy_only*(1-alpha)`) is never what
renders; the water contributes exactly 0% at every one of these pixels,
at every depth, at both alphas.

**Confirmed visually, not just numerically** -- three renders saved and
inspected (`greatlakeB_a095_f00.png`, `_f60.png`, `stream_a090_f60.png`):
Keepy's WHOLE model (ears, badge, tail, paws) keeps drawing fully opaque
and fully formed at every depth; only his apparent screen position and
foreshortening shift (he reads as floating/perched, never as clipped,
tinted or hidden). In the stream capture he sits plainly in the ribbon,
fully legible against it, both portals' labels and the pond/lake visible in
the same frame.

**Why, mechanically**: the water is a genuinely flat, zero-thickness
(pond/lake: thin slabs; stream: literally zero-thickness, double-sided)
transparent disc/ribbon. Keepy's `.glb` is a solid opaque volume. At any
screen pixel his silhouette actually occupies, his own mesh surface is
closer to the camera along that ray than the water plane is at the same
(x,z) -- so the transparent pass's depth test discards the water fragment
there unconditionally, regardless of how far his Y has been pushed down.
The water can only ever appear in the empty space AROUND his silhouette,
never layered over it. This is not a gl_compatibility bug or a sort-order
accident to fix; it is the correct, expected behaviour of an opaque mesh in
front of a flat transparent plane -- and it means **moving Keepy's Y alone
can never produce a submersion visual**, at any alpha, on this renderer or
any other. A visible "he is in the water" effect needs a mechanism that does
NOT rely on the water plane occluding him -- e.g. a colour-grade toward the
water's hue as a function of depth, a scale/squash cue, ripple/foam decals
at the waterline, and/or an actual clip-plane shader on Keepy's material if
a literal cutoff is wanted. None of that exists today (Keepy's material is
plain unshaded per project convention) and none of it is designed here.

## Q4 -- HubRegion knows 2 of 5 bodies; extending it is two different shapes of work, not one

`scripts/hub/HubRegion.gd`, read and run: `lakes()` holds exactly the two
great-lake lobes (`{centre:(15.5,-19), r:16.0}`, `{centre:(-12,-19.5),
r:10.0}`); `contains()`'s subtraction is a loop over that table only.
**MEASURED, matching `docs/WATER_WALK_RECON.md`'s own Q2**: pond (r=3.2,
centre (20.70,7.40)) and small lake (r=8.0, centre (-25.10,-5.30)) are NOT
in that table -- their radii live as plain `const` in `HubBuilder.gd`.

⚠️ **NAMING COLLISION, found while reading both files side by side**:
`HubBuilder.LAKE_WATER_RADIUS` = **8.0** (the SMALL lake) and
`HubRegion.LAKE_WATER_RADIUS` = **16.0** (the GREAT lake) -- the identical
identifier, two different bodies, two different files. Whoever builds a
shared five-body table should rename one of the two FIRST; carrying both
into one file unrenamed is how a future edit picks the wrong constant by
habit rather than by reading it.

What a uniform five-body membership test needs to add, in two different
shapes:

1. **Two more disc rows** (pond, small lake) -- trivial, the centre+radius
   already exist as consts, this is a table-row problem plus the rename
   above.
2. **A ribbon test for the stream** -- NOT a disc. The stream is 89 samples
   of a centripetal Catmull-Rom spine (`HubBuilder._centripetal`, over the
   shipped 12-point trace) with a constant half-width of 0.6. A membership
   test here is nearest-point-on-polyline-to-a-point, the same shape of
   problem `HubStreamRoute.project()`/`point_at()` already solves for the
   boat -- reusable machinery, but a genuinely different code path from the
   four discs, not a fifth row in the same table.

**Float32 rim**: `docs/WATER_WALK_RECON.md` Q2 already measured
`radius + 0.001` sampling against all FOUR discs (pond, small lake, great A,
great B) -- that discipline transfers directly to a five-body table with no
new work. It has **not** been measured for the stream's ribbon edge (a
different geometry -- the analogous slip would be at the half-width
boundary, perpendicular to the spine, and nobody has swept it).

**What this file does NOT decide**: "which body am I in" is a 2D (x,z)
question. "How far to sink" is a separate, per-body lookup into Q2's
water-top table that any caller would still have to do afterwards -- this
recon does not fold the two together, and neither should the next batch
without saying so.

## Q5 -- model height measured at 1.3501u; the sink margin is generous on all five bodies

`Body.visual_aabb()` on the shipped `Keepy/Yaw/Body` `ModelSlot`
(`model_scene = keepy_squirrel_hero.glb`, `model_scale = 1.07368`,
`model_offset = (0,-0.2246,0)`), transformed to world space:

```
slot-local AABB   position=(-0.662, -0.900, -1.019)  size=(1.320, 1.350, 2.037)
world AABB        position=(-0.662, -0.00002, -1.019) size=(1.320, 1.350, 2.037)
```

**H = 1.3501 u**, feet at world `y = -0.00002` (i.e. `0.0000`, confirming
`model_offset` puts the feet exactly at Keepy's own `global_position`, as
the earlier Battle/Hub lots already established for this same asset and
this same `model_scale`). `HOP_HEIGHT` (0.6) is 44.4% of H.

Q3 measured that nothing is actually clipped today, so "visible margin"
below is what a FUTURE lot would get if it added real geometric occlusion
at the waterline (a shader clip-plane, most plausibly) -- not what happens
now:

| f (fraction of H submerged) | height remaining above the cut | % of H |
|---|---|---|
| 0% | 1.3501 | 100% |
| 30% | 0.9451 | 70% |
| 60% | 0.5400 | 40% |

Because the five water tops (Q2) span only 0.027-0.095 -- under 10% of H --
**which of the five bodies Keepy is in barely moves this table**: the
margin left visible at 30%/60% is close to identical everywhere. A future
clip-based render does not need a per-body correction beyond Q2's own
water-top constant.

## Q6 -- the stream has no bank to mask anything; the camera keeps every plateau point in frame by construction

`HubBuilder._make_stream`'s own comment: the stream "alpha-blends straight
onto the GROUND" -- **it has no bank ring at all**, unlike pond/lake/great
lake, which are the only bodies that own an opaque disc that could occlude
anything. So structurally, nothing named "a bank" can mask a body standing
IN the stream, because there is no bank geometry there.

⚠️ **Pitfall hit and recorded, a second instance of a pattern this repo
already documents for pixel-reading probes**: a first pass measured "is the
test point inside the frustum" under `--headless`, which reported the
`SubViewport`'s size as **`(1920, 1920)`** -- not the project's real
`1080x1920`. `--headless` forces the DUMMY display driver, which does not
honour `SubViewportContainer.stretch` against the project's configured
window size; any camera-frustum check that trusts `Viewport.size` under
`--headless` is reading a fabricated number. Re-run under
`xvfb-run --rendering-driver opengl3`, the real viewport reports **exactly
`(1080, 1920)`**, matching `project.godot`.

With that fixed: `HubCamera` follows Keepy's ground `(x,z)` at a fixed
offset `(0,7.6,8.9)` and a fixed `-34deg` pitch (`OFFSET`/`FOLLOW_LAMBDA`,
unchanged, not touched by this recon) -- so by construction, wherever on
the plateau Keepy stands, the camera reframes to the SAME relative
composition. MEASURED on the real render: the stream test point (a control
point of the shipped 12-point trace) unprojects to `(959.6, ~1040-1224)`
inside a `1080x1920` frame -- comfortably inside, at every one of the six
capture depths. The stream capture screenshot (`stream_a090_f60.png`)
confirms this directly: Keepy is plainly visible sitting in the ribbon,
with both other portal labels, the pond, the great lake and its islet
landmark all sharing the same frame.

What is NOT ruled out by this recon: ordinary decor (tree canopies) is
already documented elsewhere in this project as overhanging the stream's
trace by up to 0.525u at some points -- a screen-space occlusion this
recon's two sample points did not happen to sit under. That is a real,
open, un-measured risk for a future lot, not a resolved one.

---

## What a follow-up batch has to decide before it can be scoped

1. **Q3 is the one that changes the shape of the next batch.** "Keepy walks
   into the water" and "Keepy visibly LOOKS like he is in the water" are two
   different features. The first needs only the guard removal Mathieu has
   already decided (out of this recon's scope). The second needs a real
   mechanism -- colour grade toward the water hue, a scale/squash cue,
   waterline decals, and/or a clip-plane shader -- none of which exists
   today, and picking one is a design decision this recon does not make.
2. **The naming collision** (`HubBuilder.LAKE_WATER_RADIUS` = 8.0 vs
   `HubRegion.LAKE_WATER_RADIUS` = 16.0) should be resolved BEFORE a shared
   five-body table is written, not discovered while writing it.
3. **The stream needs its own membership test**, not a sixth row in a disc
   table -- and its float32 edge margin has never been swept, unlike the
   four discs.
4. **Per-body sink depth is a solved lookup** (Q2's water-top table) once
   "which body" (Q4) is answered; the two questions are independent and
   should stay that way in the code.
