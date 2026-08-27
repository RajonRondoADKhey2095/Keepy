# WATERLINE RECON -- a world-height tint line, so the body is wet and the
head stays dry, measured for the batch that will actually wire it

**27 August 2026. RECON ONLY: no gameplay file is touched.** Branch
`claude/water-tint-height-recon-avzd47`, cut from `origin/staging`
(`2c1563f`, which carries the shipped uniform 75% tint). `origin/main` is
`a007e78` and `origin/staging` is `2c1563f`, both exactly as the brief
expected. Refs sorted by date and compared by TREE rather than by name --
every branch newer than `main` is already an ancestor of `origin/staging`,
so no branch carries this brief and no concurrent session is running.

`git diff --stat` against `origin/staging` touches only `docs/` and
`CLAUDE.md`. All probes are throwaway and deleted before the commit;
`ProbeTimeoutAudit` is re-run afterwards to prove the baseline is back.

**Mathieu's decision, restated so nothing below re-litigates it**: the
uniform 75% tint is shipped and judged INSUFFICIENT on device -- the whole
of Keepy turns turquoise and it does not read as "he is standing in
water". These are PADDLING POOLS: the BODY is wet, the HEAD stays dry and
above the surface. The limit is a **waterline at a CONSTANT WORLD Y**, not
a proportion of the body, chosen so it stays correct the day variable
depths or swimming arrive. Swimming is out of scope. The boat is out of
scope.

Everything below comes from four throwaway probes driving the shipped
`scenes/HubWorld.tscn`, `KeepyHopper`, `ModelSlot`, `HubBuilder`,
`HubRegion` and `HubWater`, all under
`xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60`, with the
viewport ASSERTED at 1080x1920 before any pixel is read.

---

## PREMISES CORRECTED BY MEASUREMENT -- four of them are mine

Published in failure rather than smoothed over, in the order they were
caught.

1. **"ModelSlot reports 2 mesh instances, so the single-mesh claim needs
   re-checking."** Mathieu is right and the ambiguity is closed. The GLB
   itself carries **one mesh, one primitive, one material** (`material.001`,
   `KHR_materials_unlit`, 3121 vertices, one `baseColorTexture`). Live, the
   slot draws two `MeshInstance3D` and only one of them draws anything:

   | node | mesh | surfaces | verts |
   |---|---|---|---|
   | `Body` (the ModelSlot itself) | **null** | 0 | 0 |
   | `Body/keepy_squirrel_hero/Mesh1_0` | ArrayMesh | 1 | 4123 |

   `Body`'s own mesh is cleared when the model installs. There is no
   head/body split to address by property write, and the shader route is
   the only route. (4123 > 3121 because Godot's importer splits vertices
   on UV/normal seams; it is still one surface.)

2. ⚠️ **MINE, and it made my first shader wrong for a reason I had
   backwards: "the shipped material culls back faces."** FALSE.
   `slot_material()` reports `cull_mode = 2` (**DISABLED**),
   `transparency = 0` (opaque), `no_depth_test = false`,
   `shading_mode = 0` (UNSHADED), `albedo_color = (1,1,1,1)`,
   `albedo_texture` a 1024x1024 `CompressedTexture2D`. My throwaway
   shader's `cull_disabled` was the CORRECT match; the assertion I wrote
   against it was the wrong one.

3. ⚠️ **MINE: "the first ladder render is speckled, so the boundary is
   depth-fighting."** FALSE, and the measurement refuted the picture. Per
   screen column crossing the body, a clean waterline flips wet/dry ONCE;
   depth-fighting flips many times. Measured across four render modes:

   | shader `render_mode` | flips/column | worst column |
   |---|---|---|
   | `cull_disabled` + `ALPHA` write (my first try) | **0.96** | 3 |
   | `cull_disabled`, no `ALPHA` | 0.96 | 3 |
   | cull BACK + `ALPHA` | 0.96 | 3 |
   | cull BACK, no `ALPHA` | 0.96 | 3 |

   All four are identical and all four are ~one flip per column: **the
   boundary is clean in every combination.** What I read as speckle was
   the fur texture's own markings on a profile pose. The re-shot ladder
   below ranges 0.36 to 1.55 flips/column, the higher figures being rungs
   where the line legitimately crosses the tail and the body separately.

4. ⚠️ **THE BRIEF'S OWN METRIC RUNS THE WRONG WAY, and this is the most
   consequential correction here.** The brief asks for "the contrast of
   the HEAD against the water" and asks me to quantify the gain over the
   uniform tint's 1.64-1.81:1. Measured, a DRY head scores **1.13-1.23:1**
   against the water -- **WORSE than the shipped uniform tint's 1.89:1**.
   Not a defect in the design: WCAG contrast is a LUMINANCE ratio, the
   water renders bright (relative luminance 0.457) and Keepy's natural
   cream/rust is bright too (0.409), while the 75% tint is dark (0.193).
   What makes a dry head read as "not water" is HUE, and on that axis the
   dry head is **155 degrees** from the water against the tinted body's
   **41 degrees**. Both axes are reported throughout; neither alone is the
   answer. See Q3.

5. **MINE, three probe defects, each of which produced a confident wrong
   number before it was caught.**
   * A GDScript **parse error** (`Cannot infer the type of "spread"`) meant
     a 15-minute run measured nothing at all -- the exact trap this repo
     already documents. Every probe since is parse-checked with a
     seconds-long `--headless ... --quit-after 2` first.
   * `wet_fraction` diffed each pose against a reference frame captured at
     a DIFFERENT pose, so it measured where the silhouette had MOVED TO.
     It reported a rising Keepy as getting **wetter** (0.189 -> 0.948),
     the exact opposite of the truth. Fixed by rendering the SAME pose
     twice, tint off then tint on, and calling the differing pixels the
     tinted ones.
   * `--fixed-fps 60` was omitted, so a 0.28s hop finished in **three**
     llvmpipe frames and the hop table was meaningless.

---

## Q1 -- what `gl_compatibility` actually compiles

`project.godot` pins `renderer/rendering_method="gl_compatibility"` on both
desktop and mobile. Four shader variants were applied to Keepy's real
drawn surface, rendered, and judged on stderr AND on pixels.

| variant | compiles? | outcome |
|---|---|---|
| **A** `varying vec3` written in `vertex()` from `MODEL_MATRIX * vec4(VERTEX,1.0)` | **yes** | world-space line, correct |
| **B** `fragment()`-side `INV_VIEW_MATRIX * vec4(VERTEX,1.0)`, no varying | **yes** | rendered identically to A |
| **C** `varying vec3 v = VERTEX` (model space) | **yes** | compiles and is WRONG -- see Q2 |
| **D** deliberately broken, to prove the detector can fail red | **no** | error below |

Variant D's exact output, which is what a real failure looks like here:

```
SHADER ERROR: Unknown identifier in expression: 'THIS_DOES_NOT_EXIST'.
          at: (null) (:9)
ERROR: Shader compilation failed.
   at: set_code (drivers/gles3/storage/material_storage.cpp:2972)
```

**Everything the implementation needs is available in this mode**, all of
it exercised rather than assumed: `shader_type spatial`,
`render_mode unshaded`, `render_mode cull_disabled`, `uniform sampler2D`
with `: source_color`, `uniform vec4 : source_color`, `uniform float`,
`varying vec3` across `vertex()`/`fragment()`, `MODEL_MATRIX`,
`INV_VIEW_MATRIX`, `VERTEX`, `UV`, `ALBEDO`, `ALPHA`, and `step()`/`mix()`.

⚠️ **A and B are equivalent and A is the one to ship**: a varying is
computed once per vertex, the `INV_VIEW_MATRIX` form once per fragment.
Both were measured to render the same thing under the same sampling
window. A is what every table below uses.

⚠️ **Limit of the D result, stated rather than dressed up**: the exact
compile error is definitive, but what a failed shader DRAWS was not
reliably measured -- the sampling window in place at that point was the
loose one that premise 5 retired, and it returned an identical pixel count
for all four variants, which is not credible. The compile error is the
finding; the failure's appearance is not claimed.

---

## Q2 -- THE PRIORITY TRAP: the test must be in WORLD space, and the
difference is not subtle

The two coordinate systems are separated by a **fixed offset of 0.6754 and
a scale of 1.07368**, both read off the shipped scene rather than guessed:
the `Body` slot sits at `y = 0.9`, `model_offset = (0, -0.2246, 0)`,
`model_scale = 1.07368` (the same values `resources/battle/keepy.tres`
carries for this asset -- an independent cross-check that lands exactly).

```
model VERTEX.y  in [-0.6291 .. +0.6283]
world       y   in [ 0.0000 .. +1.3500]      height 1.3501
```

So `water_y = 0.55` means **40.7% of him** read as world, and **93.8% of
him** read as model space. Measured, at a line held at world `y = 0.55`,
with the wet pixels being those that change between a tint-off and a
tint-on render of the SAME pose:

| Keepy world y | WORLD wet frac | WORLD line row | MODEL wet frac | MODEL line row |
|---|---|---|---|---|
| 0.00 | **0.187** | 1042 | 0.906 | 943 |
| 0.20 | 0.083 | 1049 | 0.907 | 924 |
| 0.40 | 0.034 | 1063 | 0.909 | 905 |
| 0.60 | **0.000** | none | 0.911 | 885 |
| 0.90 | **0.000** | none | 0.914 | 855 |

The camera's own projection of world `y = 0.55` is row **1060** at every
one of those poses. **The world-space shader lands on it and dries him
completely once his feet clear the line; the model-space shader keeps him
soaked at every altitude and its line marches UP the screen with him
(943 -> 855).** That is the trap, and it is worth naming precisely: the
model-space version compiles, renders, and looks plausible in a still
frame.

**Lateral movement, judged on the ROW rather than the fraction:**

| pose | mask px | drawn line row | camera says | gap |
|---|---|---|---|---|
| (0, 0, 0) | 20275 | 1042 | 1060 | -18 px |
| (6, 0, 0) | 20275 | 1042 | 1060 | -18 px |
| (-6, 0, 4) | 17498 | 1055 | 1060 | -5 px |
| (0, 0, -8) | 25938 | 1042 | 1060 | -18 px |

⚠️ **The fraction is NOT usable across poses and the mask column says
why**: the mask is built by diffing body-shown against body-hidden, so
wherever Keepy's colour matches whatever is behind him those pixels never
register, and the denominator moves between 17498 and 25938 for the same
body. The ROW does not have that problem, and it is flat.

⚠️ **The residual 18 px is not drift -- a horizontal plane does not
project to one screen row.** The camera is tilted -34 degrees, so world
`y = 0.55` spreads across rows with DEPTH. Computed independently of the
engine (a camera model that reproduces the probe's own 1060 to 0.1 px):

| z (Keepy's own extent is +-1.02) | screen row |
|---|---|
| -1.02 (far side) | 992 |
| 0.00 (centre) | 1060 |
| +1.02 (near side) | 1139 |

The band is **147 px tall** and the measured topmost tinted row, 1042,
sits inside it. Nothing is drifting.

**A REAL hop, shipped `KeepyHopper`, `HOP_HEIGHT` 0.60, at
`--fixed-fps 60`.** The same hop is driven TWICE -- tint off, then tint on
-- and the tinted pixels are those differing between the two runs at the
same frame index, so no mask and no cross-pose comparison is involved:

| frame | Keepy y | tinted px |
|---|---|---|
| 0 | 0.134 | 7778 |
| 3 | 0.435 | 2521 |
| 6 | 0.583 | 721 |
| 9 | 0.578 | 623 |
| 12 | 0.420 | 3587 |
| 15 | 0.109 | 9466 |
| 18 | 0.000 | 11634 |
| **apex 0.599** | | **592** |

**The body crosses a line that stays put**: 11634 tinted pixels at rest on
the ground, 592 at the apex -- a 95% collapse. He leaves the water when he
jumps out of it, which is what a world-fixed line means.

⚠️ **A design consequence that falls out of this and is NOT decided here**:
with a world-constant line, every hop taken while wading is a full
wet -> dry -> wet cycle inside 0.28s. That is physically right and may
still read as flicker. Nobody has seen it on a phone.

---

## Q3 -- the ladder, and what the head is actually worth

Standing in the great lake's spawn lobe, the one body already in frame
from the plateau's own spawn. Water sampled from the frame beside Keepy,
never from the authored constant:

```
water as RENDERED   (0.231, 0.784, 0.724)   hue 173.6 deg
authored hue        (0.251, 0.878, 0.816)   -- fog has not been applied to it
```

Two ends of the scale first, both over the same true mask:

| state | body colour | hue | WCAG vs water | hue distance |
|---|---|---|---|---|
| **SHIPPED uniform 75%** | (0.378, 0.542, 0.413) | 132.6 | **1.89:1** | **40.9 deg** |
| **fully dry** | (0.864, 0.596, 0.479) | 18.2 | **1.15:1** | **155.3 deg** |

**That is the inversion premise 4 names, in one table.** The shipped tint
wins on luminance and loses on hue by nearly 4x. A dry head is not "higher
contrast" against this water -- it is a different HUE FAMILY, which is
what makes it read as a squirrel rather than as more water.

The ladder. `wet frac` is the share of his SILHOUETTE that reads wet;
`wet height` is the exact geometric share of his 1.3501 (feet at world 0),
which no masking artefact can move:

| rung (world y) | wet height | wet frac | flips/col | dry part above the line | WCAG | hue dist |
|---|---|---|---|---|---|---|
| 0.10 | 7.4% | 0.021 | 0.36 | (0.853, 0.598, 0.483) | 1.15 | 155.0 |
| 0.25 | 18.5% | 0.059 | 0.84 | (0.865, 0.574, 0.451) | 1.20 | 155.8 |
| 0.45 | 33.3% | 0.110 | 0.96 | (0.865, 0.564, 0.441) | 1.22 | 156.1 |
| **0.62** | **45.9%** | 0.217 | 0.96 | (0.864, 0.563, 0.439) | 1.23 | 156.0 |
| **0.78** | **57.8%** | 0.302 | 1.19 | (0.869, 0.567, 0.439) | 1.21 | 155.7 |
| **0.92** | **68.1%** | 0.429 | 1.46 | (0.870, 0.563, 0.433) | 1.22 | 155.7 |
| 1.05 | 77.8% | 0.575 | 1.55 | (0.872, 0.574, 0.443) | 1.19 | 155.3 |
| 1.18 | 87.4% | 0.748 | 1.44 | (0.874, 0.599, 0.467) | 1.13 | 154.1 |

⚠️ **The dry part's colour barely moves down the whole ladder** (WCAG
1.13-1.23, hue distance 154-156 deg) and that is the point rather than a
flat result: **whatever survives above the line keeps Keepy's own hue
family completely.** The choice of rung is therefore not a colour
trade-off at all -- it is a choice of HOW MUCH of him survives, and every
rung's survivor is equally legible as "not water".

**The sheet: `docs/color-sheets/waterline_ladder_sheet.png`**, ten tiles --
fully dry, the shipped uniform tint, then all eight rungs -- every one from
the shipped camera at the shipped 1080x1920 and **all in the SAME pose**.
(The first version of this sheet had the shipped tile in a different
orientation, because a hop earlier in that probe had turned him; it was
re-shot rather than explained away, since it would have had Mathieu
comparing two poses instead of two treatments.) Read off the render, with
the anatomy corrected against the picture rather than kept as I first
labelled it:

| rung | where the line actually cuts | verdict from the tile |
|---|---|---|
| 0.10 / 0.25 / 0.45 | feet, lower legs, hips | **effectively invisible** -- see below |
| **0.62** | belly, under the badge | first rung where "he is in water" reads |
| **0.78** | chest, at the badge -- head, arms and face dry | body wet, head dry |
| **0.92** | the jaw line -- exactly head and ears dry | body wet, head dry |
| 1.05 | across the eyes -- only crown and ears dry | the head is going under |
| 1.18 | above the eyes -- only the crown dry | nearly the shipped look |

⚠️ **The bottom three rungs are very nearly a no-op, and the wet fractions
say so before the eye does: 0.021, 0.059, 0.110.** Keepy is modelled
SITTING, so his legs and feet are small and largely self-occluded; a line
below roughly 0.6 has almost nothing to colour. **The usable range starts
at 0.62**, which is narrower than the eight rungs make it look.

**The band that matches the decision -- body wet, head dry -- is 0.78 to
0.92**, marked on the sheet. **This recon does not pick between them; that
is Mathieu's, on a real screen.**

⚠️ **One property of the effect nobody asked about, and the sheet makes it
unmissable**: the tint colour IS the water colour, so the submerged part
does not read as "wet Keepy" so much as it DISAPPEARS into the water
behind him. At 0.62-0.78 that is exactly right and sells the paddling
pool. By 0.92 the body below the jaw has largely merged with the
background and he is closer to a floating head than to a squirrel standing
in a pool -- which may be the desired read, or may be one rung too far.
It is a consequence of tinting toward the water's own hue at 75%, and the
implementation could soften it by tinting the submerged part to something
NEAR the water rather than AT it. Not decided here, and not asked for.

## Q4 -- the shader REPLACES the albedo write; it does NOT replace
`HubWater`, and 6 of the gating probe's 34 checks have to be rewritten

**Measured, not reasoned about.**

**It coexists.** A world-Y line with no membership gate wets Keepy on dry
land: the spawn `(0,0,0)` reports `HubWater.contains() == false`, his feet
sit at world `y = 0.000`, and a line at 0.550 is above them -- so the
height test alone would put him knee-deep in grass. `HubWater.gd` (179
lines) is untouched and still answers "is he in water at all"; the shader
answers "how much of him". What changes is only what the wet state DOES.

**The tween survives intact.** `tween_property(mat,
"shader_parameter/tint_fraction", 0.75, 0.18)` -- the exact call shape
`_set_keepy_wet()` uses today, aimed at a uniform instead of a property --
was driven on a live `ShaderMaterial`: **mid-tween 0.4986, final 0.7500.**
A shader uniform tweens exactly like `albedo_color` does, so
`KEEPY_TINT_FADE_S`, the kill-and-restart, and the `_keepy_wet` latch all
carry over unchanged.

**What leaves and what stays in `scripts/hub/HubWorld.gd`:**

| line(s) | today | after |
|---|---|---|
| 114 | `var _keepy_material: StandardMaterial3D` | becomes `ShaderMaterial` |
| 115 | `_keepy_base_color` | no longer the tint source -- the shader multiplies the texture directly |
| 116-117, 123 | `_resolved` / `_tint_tween` / `_keepy_wet` | **unchanged** |
| 271, 344 | the two `_set_keepy_wet()` call sites | **unchanged** |
| 417 | `KEEPY_WATER_TINT_FRACTION = 0.75` | **unchanged** -- it becomes the uniform's target |
| 419 | `KEEPY_TINT_FADE_S = 0.18` | **unchanged** |
| 422-456 | `_set_keepy_wet()` | tweens `shader_parameter/tint_fraction` instead of `albedo_color` |
| 458-470 | `_ensure_keepy_material()` | still reads the `StandardMaterial3D` (for its `albedo_texture`), then builds and binds a `ShaderMaterial` |
| **new** | -- | one constant for the waterline's world Y, plus setting `water_y` |

The lazy resolve and the `duplicate()` discipline both survive for the
same reasons the file already documents -- the importer binds ONE shared
material on the mesh, and Battle's player fighter is the same `.glb`.

**`scripts/dev/WaterTintProbe.gd`: 6 of 34 checks break, and they are
named.** Its reader is `_drawn_albedo()` (line 322), which casts to
`StandardMaterial3D` and returns MAGENTA on a null cast. Bound against a
live `ShaderMaterial`, measured:

```
before: slot_material() -> StandardMaterial3D   _drawn_albedo() -> (1, 1, 1, 1)
after : slot_material() -> ShaderMaterial       _drawn_albedo() -> (1, 0, 1, 1)
```

| check | what it does | verdict |
|---|---|---|
| 232, 233, 240 | PHASE C, the tint reaches the drawn surfaces | **must be rewritten** |
| 305 (x3 portals) | PHASE F, the tint ran before the portal branch | **must be rewritten** |
| the other 28 | membership, both rim margins, the ride, draw-node count, portals opening | **untouched** |

The rewrite is small and keeps the phase's whole point (read what is
DRAWN, never the variable `HubWorld` wrote): read
`slot_material()` as `ShaderMaterial` and assert
`get_shader_parameter("tint_fraction")` and `("water_y")` instead of
`albedo_color`. **Both rim constants, both margins and the five-body test
are entirely unaffected** -- this batch does not touch `HubWater.gd`.

⚠️ **MY OWN PREDICTION WAS WRONG BY ONE, and the measurement is more
interesting than the prediction.** Reading the code, I said 6 checks would
break. Run for real -- the shipped probe against a patched `HubWorld`
binding a `ShaderMaterial`, then reverted with `git checkout` -- it is
**5**:

```
BEFORE (shipped StandardMaterial3D):  34 OK, 0 failures
AFTER  (world-height ShaderMaterial): 29 OK, 5 failures
  FAIL  a landing in water tints the DRAWN surfaces to 75%
  FAIL  a landing on land removes the tint completely
  FAIL  'Chased': the tint was updated (dry) on the way past
  FAIL  'Quizz':  the tint was updated (dry) on the way past
  FAIL  'Battle': the tint was updated (dry) on the way past
```

The sixth, line 233 -- `the wet albedo is not just the base colour` --
**PASSES, for the wrong reason**: it is a NEGATIVE assertion, `_drawn_albedo()`
returns MAGENTA, and MAGENTA is indeed "not the base colour". It goes green
against a material it could not read at all. That is worth knowing on its
own terms: it is a check that cannot fail in the direction it is pointed,
and the rewrite should give it something positive to assert.

---

## Q5 -- cost: no node, no pass, nothing measurable

Three `HubPerfBaseline` runs each side, in one session on one machine --
the only comparison this file's own rules allow.

| | BEFORE (StandardMaterial3D) | AFTER (ShaderMaterial) |
|---|---|---|
| draw nodes, excl. portals | **98 / 98 / 98** | **98 / 98 / 98** |
| draw nodes, total | **104 / 104 / 104** | **104 / 104 / 104** |
| MultiMeshInstance3D batches | 9 / 9 / 9 | 9 / 9 / 9 |
| construction (ms) | 37.73 / 37.05 / 36.30 | 36.26 / 36.43 / 40.59 |
| simulated FPS, mean | 25.1 / 25.3 / 25.2 | 26.3 / 27.1 / 25.4 |
| simulated FPS, min | 19.1 / 16.2 / 17.4 | 19.3 / 21.8 / 11.6 |

**No draw node is added and none is removed** -- 98 and 104 are identical
across all six runs, and the 260 ceiling is untouched (margin stays 162).
A material swap is a material swap: the same one `MeshInstance3D`
(`Mesh1_0`) draws the same one surface, with a different program bound.
No extra render pass, no second material resource beyond the one the
shipped code already duplicates.

⚠️ **The honest reading of the FPS rows is "the ranges overlap", NOT "it
got faster".** The AFTER means sit marginally higher and the AFTER minimum
is both the best (21.8) and the worst (11.6) figure in the table -- that is
noise on a shared 4-core box, not a signal. What the rows support is the
narrow claim that **no cost is detectable**, which is the claim Q5 asks
for.

⚠️ **And as always: llvmpipe under xvfb is a software rasteriser.** A
per-fragment `step()` and `mix()` is close to free on a phone GPU and
comparatively expensive here, so if anything this measurement is
pessimistic -- but nothing in it says how the plateau behaves on a phone.
These numbers are also NOT comparable to the FPS rows in
`docs/HUB_PERF_BASELINE.md`; only a BEFORE/AFTER pair inside one session
is.

---

## Q6 -- what this recon CANNOT prove

Said plainly, because a sandbox capture is not a phone.

1. **Every render here is llvmpipe/Mesa under xvfb through Godot's
   `opengl3` desktop backend. The game ships WebGL2 in Safari on iOS.**
   They are different GLSL compilers behind the same `gl_compatibility`
   source. A shader that compiles here can still fail there, and the two
   most likely places are exactly the ones this design leans on:
   **`varying` interpolation precision** (WebGL2 on mobile commonly gives
   `mediump` by default in fragment shaders, where desktop gives `highp`)
   and **`MODEL_MATRIX` availability and precision in `vertex()`**. A world
   Y around 0.55 carried in `mediump` should be fine; nothing here proves
   it.
2. **No number in Q3 is a device colour.** The rendered water
   `(0.231, 0.784, 0.724)`, the contrast ratios and the hue distances are
   all this rasteriser's output at this fog density. A phone screen's
   gamut, brightness and the viewer's ambient light are all outside it.
3. **This recon renders STILL FRAMES.** Whether a wet/dry boundary reads as
   a waterline or as a seam AT SPEED, and whether the hop's
   wet -> dry -> wet cycle inside 0.28s reads as physics or as flicker, is
   not something a still can answer.
4. **No rung is chosen.** The sheet exists so the choice is made on
   pictures rather than on an impression; making it is not this recon's
   job.
5. **One water body was laddered**, the great lake's spawn lobe. The brief
   cites a worst case of 1.52:1 on the stream under the uniform tint;
   this recon measured 1.89:1 for the shipped tint on the spawn lobe and
   did NOT re-measure the other four bodies. Fog varies by distance, so
   the ladder's absolute colours will differ elsewhere -- the DRY part's
   own colour will not, since it is Keepy's own texture either way.
6. **The five water surfaces are not at one height** -- great lake lobe A
   0.0270, lobe B 0.0295, pond 0.0800, small lake 0.0800, stream 0.0950.
   The spread is **0.0680, i.e. 5.04% of Keepy's height**. A single
   world-constant line is defensible at that scale and is what was
   decided; nobody has looked at whether the 5% shows.

---

## What the implementation batch has to decide, and what it can just take

**Take, already measured:**
* the shader form (Q1 variant A -- a `varying` from `MODEL_MATRIX`);
* that the uniform tweens exactly like the property it replaces
  (0.4986 mid, 0.7500 final);
* that `HubWater.gd` stays and gates the effect;
* that `KEEPY_WATER_TINT_FRACTION` and `KEEPY_TINT_FADE_S` carry over;
* that nothing costs a node or a measurable frame.

**Decide:**
1. **THE RUNG.** The band that matches the decision is **0.78 to 0.92**;
   the sheet is `docs/color-sheets/waterline_ladder_sheet.png`. Mathieu's,
   on a screen.
2. **Whether the hop should suppress the transition.** A world-fixed line
   means a wading hop fully dries and re-wets inside 0.28s (measured:
   11634 tinted px -> 592 -> 11634). Correct, possibly ugly.
3. **What `WaterTintProbe`'s PHASE C and PHASE F assert instead** --
   `get_shader_parameter("tint_fraction")` and `("water_y")` read off the
   DRAWN material, keeping the phase's original point, plus something
   POSITIVE for line 233 so it can fail in the direction it is aimed.
4. **Whether one constant Y is enough for all five bodies** (point 6
   above), or whether the stream's 0.0950 wants its own.

---

## Validation of this recon itself

Godot 4.3-stable editor installed in this sandbox from the official GitHub
release, **size verified against `Content-Length` before extracting**
(50,276,070 bytes, no silent truncation). Export templates were NOT needed:
this batch touches no Godot resource, so there is nothing to export.

* Import, headless: **exit 0, 24 `.scn`, 0 errors** -- a complete import
  verified rather than assumed, since a truncated one produces a false red.
* `ProbeTimeoutAudit`: **PASSED, 49 probe scenes + 1 `--script` probe.**
  ⚠️ The previous recon records this baseline as 48; that figure predates
  `WaterTintProbe.tscn`, which the implementation batch added. The check
  that actually matters was done by SET rather than by count:
  `scripts/dev/*.tscn` in this tree is **identical to `origin/staging`** --
  no probe added, none removed, all four throwaways gone.
* `AssetContractAudit`: **PASSED, 12/12 visuals swapped, not one collider
  moved.**
* `WaterTintProbe`, shipped and unpatched: **34 OK, 0 failures** -- the
  baseline the Q4 table is read against.
* `git status`: nothing outside `docs/` and `CLAUDE.md`.
  `scripts/hub/HubWorld.gd` was temporarily patched to measure Q4/Q5 and
  reverted with `git checkout`; the revert is confirmed clean.

**Cross-checks that had to agree before any of the above was trusted**, each
one arriving by a different route:

* `model_scale` derived from the GLB's own bbox (1.3501 / 1.2574 = 1.0737)
  against the value the scene carries (**1.07368**) and the value
  `resources/battle/keepy.tres` carries for the same asset (**1.07368**).
* A camera model written from scratch outside the engine reproduces the
  probe's own `unproject_position` for world y=0.55 as **1059.9 against
  1060**.
* The shipped tint's albedo, computed by hand as
  `White.lerp(#40E0D0, 0.75) = (0.4383, 0.9085, 0.8620)`, against the
  engine's own **(0.4383, 0.9088, 0.8618)**.
