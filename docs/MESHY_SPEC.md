# Meshy asset specification

What to ask Meshy for, and what each asset has to satisfy to drop into
Keepy without changing how the game plays.

Every number here was **measured off the running project**, not read off a
scene file by eye. Re-generate the measurements at any time with:

    godot4 --headless --path . res://scripts/dev/AssetContractAudit.tscn

---

## 1. The one rule

**An asset may change any visual. It may not change any hitbox.**

That split is now structural, not a convention to remember:

- Every collider dimension lives in `scripts/world/Hitboxes.gd` and is
  written onto the real shape at `_ready()` by the owning script. The
  scenes are no longer the source of truth for them.
- Every placeholder mesh is a `ModelSlot`
  (`scripts/world/ModelSlot.gd`), and no line of that file reads or
  writes a `CollisionShape3D`.
- `AssetContractAudit` installs a substitute model into all 12 slots and
  re-measures every collider. Measured today: **12/12 visuals changed,
  0/10 colliders moved.**

This matters because every fairness contract in the game is written
against a collider, not a mesh — `JUMPABLE_OBSTACLE_TOP_HEIGHT`'s ~0.51s
clearance window, DODGE being unjumpable because its box stands above
`JUMP_PEAK_HEIGHT`, `RISK_MIN_SURVIVABLE_LATERAL_M`'s derivation from
"the widest hazard hitbox is 1.2m". A stray half-metre on a collider
would rebalance all of them at once, and **no other probe in
`scripts/dev/` would report it** — they measure whether the game is fair,
not whether it is still the same game.

Corollary worth stating plainly: **the visual does not have to match the
hitbox.** Two shipped assets already disagree on purpose — the CHARGER's
wedge is 1.5 x 1.8 x 2.4m over a 1.2 x 2.0 x 1.0m box, and collectibles
draw at 0.3m radius over a deliberately generous 0.4m pickup sphere. Size
an asset so it *reads* right; the hitbox stays where it is.

## 2. How to install one

1. Drop the `.glb` in `assets/models/`, textures in `assets/textures/`.
   Naming: `keepy_<subject>_<variant>.glb`.
2. Open the owning scene, select the `ModelSlot` node (they keep their
   current names — `MeshInstance3D`, `DodgeMesh`, `Silhouette`, ...), and
   set **`Model Scene`** to the imported `.glb`.
3. If it comes in rotated or at the wrong scale, fix it there with
   **`Model Rotation Degrees`** / **`Model Scale`**. Do not re-export and
   do not edit the slot's own transform — that one is gameplay-driven
   (the STOMPER animates its `scale`, the AIR_ENEMY its `position.y`).
4. Run the acceptance checklist in §9.

Nothing else changes. The placeholder node stays, so every `.visible`,
`.scale` and `.position` write in the gameplay code keeps working, and
pooling is untouched: the model installs once, at load, never per frame.

### 2.1 If the slot's material is ANIMATED, check it after installing

A material reaches a surface by one of two routes, and which one is used is
decided by who authored the mesh:

- **surface override** — what a *scene* author writes. Every placeholder in
  this project (`surface_material_override/0` in `Obstacle.tscn`,
  `TrackSegment.tscn`, ...).
- **mesh surface** — what an *importer* writes. Godot's glTF importer binds
  a `.glb`'s material here and **never sets an override**.

`ModelSlot.slot_material()` used to read only the override, so it returned
`null` for every real asset — and the callers' own null-guards swallowed it.
**Fixed 2026-08-11**; it now falls back to the mesh-bound material, override
still first. Measured on `assets/models/keepy_stump_prop.glb`:
`get_surface_override_material(0)` is `null`,
`mesh.surface_get_material(0)` is a real `StandardMaterial3D`.

What it cost while it was broken: `Obstacle._ready()` would have gone on
getting `null` for `EnemyMesh`, so `_apply_enemy_alarm` returned on its
guard every frame and the ENEMY/AIR_ENEMY approach telegraph became a
**silent no-op** — no error, no crash, and no red probe, because
`SubstituteModel.tscn` carried an override and so could not reproduce the
one axis that mattered. It binds on the mesh now.

**The slots this applies to are the ones whose owning script ANIMATES the
material**, not every slot: `Obstacle/EnemyMesh` and `Obstacle/AirEnemyMesh`
(the alarm ramp) and `TrackSegment/MeshInstance3D` (the per-segment ground
tint). Installing a `.glb` on any of them means running
`scripts/dev/AlarmRampAudit.tscn` afterwards — it asserts the ramp reaches
every drawn surface, resets for the next pooled spawn, and stays
per-instance.

Two things to expect on an imported asset, neither of them a bug:

- **Emission is inert on an unlit material**, and §8/§9 make every asset
  here unlit. Both appliers move albedo *and* emission; on a `.glb` only the
  albedo half lands. That is why the probe gates albedo.
- **An EMISSION cue therefore cannot live on the slot at all.** The
  pursuer's closing cue is the worked example: its eyes are deliberately
  engine-side `MeshInstance3D` children of the slot, not part of the asset,
  precisely so an unlit imported body cannot take the cue away (`Pursuer.gd`,
  "THE EYES ARE DELIBERATELY NOT SLOTS").

## 3. Orientation

**Measured, not assumed** — `ChargerShapeProbe` asserts this against the
real built mesh, and it is the one thing here that is easy to get
backwards and invisible everywhere else if you do.

| Thing | Faces | Why |
|---|---|---|
| Hazards (all 6) | **+Z** | Obstacles travel from -Z to +Z. +Z is the direction of travel, i.e. toward the player at Z=0. |
| Keepy | **-Z** | He runs into the screen. The camera sits at +Z looking toward -Z, so **you see his back**. |
| Pursuer (Hibou) | **-Z** | It chases Keepy from behind, so it too is **seen from behind** (see §6). |
| Track tile | n/a | Length runs along Z. |

Up is **+Y**, and `y = 0` is the ground plane every offset in §4 is
measured from.

glTF and Godot share the same convention (+Y up, -Z forward), so a model
authored facing -Z in Blender arrives facing -Z. Meshy output is often
Z-up or arbitrarily rotated — correct it with `Model Rotation Degrees`.

## 4. Dimensional table

`visual` is the placeholder's mesh AABB in slot space; `slot y` is the
slot's own height above the object's origin. **Match the visual column**
(or read it as "this is what the space looks like"); **never change the
collider column.**

| Asset | Slot node | visual X x Y x Z | slot y | collider | collider y |
|---|---|---|---|---|---|
| **Keepy** (player) | `Keepy/MeshInstance3D` | 1.00 x 1.60 x 1.00 | +0.80 | Capsule r0.5 h1.6 | +0.80 |
| **DODGE** (unjumpable wall) | `Obstacle/DodgeMesh` | 1.20 x 2.00 x 1.00 | +1.00 | Box 1.2 x 2.0 x 1.0 | +1.00 |
| **JUMP** (low log) | `Obstacle/JumpMesh` | 1.20 x 0.70 x 1.00 | +0.35 | Box 1.2 x 0.7 x 1.0 | +0.35 |
| **ENEMY** (swaying) | `Obstacle/EnemyMesh` | 0.60 x 0.70 x 0.60 | +0.35 | Capsule r0.3 h0.7 | +0.35 |
| **STOMPER** (jump-only) | `Obstacle/StomperMesh` | 1.50 x 0.70 x 1.50 | +0.35 | Box 1.2 x 0.7 x 1.0 | +0.35 |
| **AIR_ENEMY** (flier) | `Obstacle/AirEnemyMesh` | 1.20 x 0.35 x 1.20 | +2.358 | Box 1.2 x 1.2 x 1.0 | +2.358 |
| **CHARGER** (wedge) | `Obstacle/ChargerMesh` | 1.50 x 2.40 x 1.80 | +0.90 | Box 1.2 x 2.0 x 1.0 | +1.00 |
| **Jump marker** | `Obstacle/JumpMarkerMesh` | 0.34 x 0.24 x 0.34 | +1.00 | *(none)* | — |
| **Noisette** | `Noisette/MeshInstance3D` | 0.60 x 0.60 x 0.60 | 0.00 | Sphere r0.4 | 0.00 |
| **Gland** | `Gland/MeshInstance3D` | 0.60 x 0.60 x 0.60 | 0.00 | Sphere r0.4 | 0.00 |
| **Track tile** | `TrackSegment/MeshInstance3D` | 6.00 x 0.40 x 20.00 | -0.20 | Box 6 x 0.4 x 20 | -0.20 |
| **Pursuer body** | `Pursuer/Silhouette` | 2.20 x 3.40 x 2.20 | +1.70 | *(none, by design)* | — |

Fixed geometry the assets sit inside:

- **Lanes** at x = **-2.0 / 0.0 / +2.0** — a hazard wider than ~1.9 in X
  will visually bleed into the neighbouring lane and make a legal dodge
  look illegal.
- **Track tile length 20m**, 7 tiles live at once (140m of track).
- **Jump peak 1.558m** (Keepy's capsule *bottom*). Anything a player is
  meant to clear must read as shorter than that; anything they are not
  (DODGE, CHARGER) must read as taller.
- **AIR_ENEMY / Gland height 2.358m** — derived from the jump arc, not a
  free number.
- The **lane barrier** (track-shrink wall, 1.7 x 2.4 x 170m) is built in
  code in `LaneBarrier.gd` and is deliberately **not** a swap point; it
  is a shader-striped wall, not a model.

## 5. Keepy (the squirrel)

- **Bounding box 1.0 x 1.6 x 1.0**, origin at the **feet** (`y = 0` is
  the sole of the foot, not the centre of mass). The collider's origin
  is Keepy's floor and the jump maths depends on it.
- Faces **-Z**. Seen from behind and slightly above (camera at +4.2Y,
  +7Z, pitched -20°) for the entire game — **the back, the tail and the
  back of the head are the surfaces that actually get looked at.** Front
  detail is nearly wasted.
- **A-pose or strict T-pose**, limbs clearly separated from the body,
  and — the one that usually breaks auto-rigging — **the tail must be
  clearly detached from the back**, not merged into it. A tail fused to
  the spine gives auto-riggers a single blob and no rig comes out of it.
- **Plan B, request it in the same batch:** an export **in separate
  parts** (head, body, 2 arms, 2 legs, tail as distinct meshes, each with
  its own sensible origin). If the rig fails, those parts get parented
  into an articulated hierarchy and animated by transform — the Crossy
  Road approach. `ModelSlot` supports this natively: it draws every
  `MeshInstance3D` in the imported scene, at any nesting depth.

## 6. The Hibou (pursuer)

Sized by a **measured screen-occupancy budget**, not by taste.
`PursuerFramingAudit` projects the body's real AABB into screen space
every frame of a driven run and caps it at **30% of screen height**.
Current measured values with the placeholder capsule:

| Phase | mean | p95 | max |
|---|---|---|---|
| INTRO sighting | 15.8% | 24.0% | 24.0% |
| VISIBLE (closing) | 25.3% | 26.3% | **27.3%** |
| CAPTURE lunge | 32.2% | 37.4% | 37.5% *(uncapped by design)* |

Occupancy scales linearly with the asset's height, and the placeholder is
3.4 units tall at 27.3% against a 30% cap. So:

- **Target total height 3.4 units** (with 2.2 width/depth) — inherits the
  existing budget exactly.
- **Hard ceiling ~3.7 units.** Past that the audit fails.
- A **wider** or **deeper** owl is nearly free; a **taller** one is not.
  Wings spread laterally cost almost nothing in this metric.

Two things specific to this asset:

- **It is seen from BEHIND.** Measured at all three poses (FAR_Z,
  CAUGHT_Z, CAPTURE_Z): the camera-facing side is the owl's **back**. So
  author the back — plumage, wing shapes, silhouette — as the readable
  surface.
- **Do not bake in glowing eyes.** They stay engine-side: the closing cue
  is a live `emission_energy` ramp (1x -> 3x closing, 5x during the
  capture lunge) that cannot be driven inside an imported material.

  **Known issue, flagged not fixed** (it is a visual gameplay change,
  outside this batch): the placeholder's eye spheres sit on the **-Z**
  face — the side pointing *away* from the camera — with their centres
  1.011 units from the body axis against a body surface at 1.093, so they
  protrude **0.088 units** past a 1.1-radius body. The pursuer's headline
  closing cue is, today, almost entirely buried on the far side. When the
  Hibou lands, the eye placeholders should be repositioned onto the
  camera-facing surface, or the cue moved to glowing markings on the back
  or wing edges. Worth deciding *while* authoring the asset rather than
  after.

  **Still true with the real asset**: the eye spheres are children of
  `Silhouette`, not of the installed model, so they did not move when the
  Hibou landed (2026-08-08) and this remains open, unchanged by this batch.

**2026-08-08 -- measured with the real Hibou mesh** (`model_scale = 1.79`,
`model_rotation_degrees = (0, 180, 0)`), seed 20260806, same driven run as
the placeholder baseline above:

| Phase | mean | p95 | max |
|---|---|---|---|
| INTRO sighting | 15.5% | 23.6% | 23.6% |
| VISIBLE (closing) | 24.9% | 26.0% | **27.0%** |
| CAPTURE lunge | 31.8% | 37.0% | 37.1% *(uncapped by design)* |

All three phases read marginally *lower* than the placeholder capsule (the
owl's actual silhouette is narrower than the capsule it replaced at the
same 3.4 x 2.2 x 2.1 AABB). INTRO and VISIBLE stay comfortably under the
30% cap; CAPTURE is exempt by design. `visual_aabb()` reports
2.198 x 3.400 x 2.098 -- height lands exactly on the 3.4 target.

## 7. Triangle and payload budget

**Frame target: 50,000 triangles.** Justified rather than picked:

- Renderer is **`gl_compatibility`** (`project.godot`), i.e. WebGL2 in
  mobile Safari — no compute, no clustered lighting, and a real per-draw
  CPU cost.
- The frame already pays for a **full-screen screen-texture copy** during
  every dark phase (`screen_invert.gdshader`) and **shadow mapping** from
  one `DirectionalLight3D` with shadows enabled.
- Roughly **31 mesh instances** are live at once: 7 ground tiles, up to 7
  hazards, up to 7 noisettes and 7 glands, Keepy, the pursuer, the
  barrier.
- Gameplay is physics-tied at 60fps, so the headroom is not optional.

### 7.1 The budget as authored (a target, not a measurement)

| Asset | Max triangles | Live at once | Frame cost |
|---|---|---|---|
| Keepy | 6,000 | 1 | 6,000 |
| Hibou | 8,000 | 1 | 8,000 |
| Hazard (each of 6) | 1,200 | 7 | 8,400 |
| Track tile | 800 | 7 | 5,600 |
| Noisette / Gland | 300 | 14 | 4,200 |
| Markers, trail bars | primitives | ~5 | negligible |
| | | **total** | **~32,200** |

**This table is the budget, i.e. what each asset is ALLOWED. It is not, and
never was, a measurement of what the game draws** — it was written before
the hibou and the squirrel were installed and before any decor existed. Do
not quote its ~32,200 as the current cost; see 7.2.

### 7.2 What the frame actually draws — measured 2026-08-09

`scripts/dev/TrackPropsAudit.tscn` phase 1 counts every visible
`MeshInstance3D` in a live 60s run, per physics frame, and keeps the WORST
frame. Re-run it after any batch that adds geometry rather than trusting
the numbers below:

    godot4 --headless --fixed-fps 60 --path . \
      res://scripts/dev/TrackPropsAudit.tscn

| Family | Budgeted (7.1) | Measured, worst frame | |
|---|---|---|---|
| collectibles | 4,200 | **25,344 – 29,568** | **OVER by ~6x** |
| pursuer | 8,000 | **15,518** | **OVER by ~2x** *(cause misattributed — see 7.3)* |
| hazards | 8,400 | 7,068 – 8,372 | ~~within~~ *(misattributed — see 7.4)* |
| keepy | 6,000 | 3,129 | within |
| track slab + curbs | 5,600 | 252 | within |
| decor hills | — | 165 | new since 7.1 |
| trackside props | — | 511 – 584 | new, see 8.2 |
| | | **52,780 – 56,284 total** | **OVER the 50,000 target** |

The ranges are real: the peak depends on how many pooled objects happen to
be visible together, and the decor generators are unseeded, so consecutive
runs differ. Every run measured so far exceeded the target.

**Two findings, both pre-existing, neither caused by the decor work.**
Measured directly, not by subtraction — with trackside props disabled the
frame still peaks at **52,780**, already 2,780 over.

1. **Collectibles are the whole problem: ~4,096 triangles each.**
   `Noisette.tscn` and `Gland.tscn` carry a `SphereMesh` left at Godot's
   default tessellation (`radial_segments` 64, `rings` 32) for a ball
   0.3 m across that renders a few dozen pixels wide. 7.1 budgets 300.
   Dropping to 16 x 8 gives 256 triangles — on the budget line, and at
   that on-screen size visually indistinguishable — which alone would take
   the frame to roughly **28,000, i.e. ~44% headroom**. Deliberately NOT
   done in the props batch: it changes the silhouette of a gameplay object
   and belongs in a batch whose device review is looking at collectibles.
2. **The `pursuer` FAMILY is 15,518 triangles against a 8,000 cap.**
   ~~A real asset overrunning its own spec, which is exactly what §11's
   pre-import check exists to catch and did not.~~ **That second sentence
   was wrong — the `.glb` is not the overrun. See 7.3.**

Neither is a rendering fault today — the game runs — but the 50,000 target
was justified above rather than picked, and the frame is over it.

### 7.3 The "15,518-triangle hibou" was a misattribution — measured 2026-08-09

The row above compares a *family* total against an *asset* budget line, and
the prose under it named the wrong culprit. Re-measured directly, parsing
the glTF JSON chunk (`indices.count / 3`, the same method §11 uses on every
asset before import) and cross-checked against what Godot actually builds:

| what | triangles |
|---|---|
| `assets/models/keepy_hibou_pursuer.glb` (one mesh, one primitive) | **7,070** |
| `Silhouette/EyeLeft` — `SphereMesh` at Godot's default 64 x 32 | **4,224** |
| `Silhouette/EyeRight` — same sub-resource | **4,224** |
| `Silhouette`'s own `CapsuleMesh` placeholder | 0 *(cleared by `ModelSlot`)* |
| | **15,518** |

7,070 + 4,224 + 4,224 = 15,518 **exactly**, which is the whole of the figure
7.2 recorded. So:

- **The Hibou asset was never over budget.** 7,070 against a cap of 8,000 —
  within it by 930, exactly as §11's own pre-import check measured it on the
  day it landed. That check did not fail; nothing read its result afterwards.
- **The overrun was two placeholder eye spheres**, 8,448 triangles, i.e.
  **54.4%** of the family — the same default-tessellation defect finding 1
  identifies in the collectibles, on a different object. Under 7.1 they fall
  in the "markers, trail bars — primitives — negligible" line.
- **Decimating the `.glb` could not have fixed it.** At *zero* triangles the
  family would still be 8,448, over the 8,000 cap. Any batch that had gone
  ahead and decimated the owl would have degraded the one silhouette the
  player must read, and still missed the target.

**Fixed** by setting the shared `SphereMesh_Eye` sub-resource to 16 x 8
(**288** triangles, not the 256 finding 1 estimates — see the correction
below): family **15,518 -> 7,646**, under the 8,000 cap by 354, and a flat
**-7,872 triangles in every frame**, since pursuer geometry is fixed and
measured identical in all 11 runs.

**The eyes were costing that and drawing nothing.** Rendering the real
`Pursuer.tscn` offscreen at all three poses `PursuerFramingAudit` uses
(`FAR_Z` 3.0 / `CAUGHT_Z` 1.0 / `CAPTURE_Z` 0.15, game camera at
`(0, 4.2, 7)` pitched -20°), before vs after, the images are **pixel-identical
— zero changed pixels at every gameplay pose.** The spheres sit inside the
owl's own eye sockets on its **-Z face**, which §6 already documents as the
side pointing *away* from the camera, so they are fully depth-occluded by
the head. They are only visible at all from a camera placed in front of the
owl's face, where the tessellation drop changes 0.30% of pixels (confined to
a bounding box around the two discs, which still read as circles). Nothing
in the game ever puts a camera there.

**Two measured corrections to 7.2's own numbers**, both understated there:

- A default `SphereMesh` is **4,224** triangles, not "~4,096" — so the
  collectibles' worst frame is 4,224 x N, and finding 1's estimate of the
  saving is correspondingly low.
- **16 x 8 gives 288** triangles, not 256. Godot's `SphereMesh` builds
  `2 x radial_segments x (rings + 1)`.

**Collectibles remain untouched and remain the dominant cost**, deliberately:
finding 1's own reasoning still applies — that change alters the silhouette
of a *visible* gameplay object and belongs in a batch whose device review is
looking at collectibles. This batch's review is looking at the pursuer, which
is why the eye spheres were in scope and the noisettes were not. Measured over
11 unseeded runs after the fix, the worst frame is **57,402** (collectibles
25,344 – 38,016), still **7,402 over** the 50,000 target. The frame is not
under budget yet; only the pursuer is.

### 7.4 The hazards row's "within" was the same misattribution — measured 2026-08-11

7.2 marks the `hazards` family **within** budget. That verdict is an
artefact of the live MIX, not evidence that the hazard assets are inside
their budget — and it hides two variants that are well outside it. Same
class of error as 7.3: a *family* number standing in for *asset* numbers.

Measured per variant, `get_faces()/3` on `Obstacle.tscn`'s own meshes, the
same method `TrackPropsAudit` uses. 7.1 budgets **1,200 triangles per
hazard**:

| Variant | Triangles | Against the 1,200 unit budget |
|---|---|---|
| ChargerMesh (`PrismMesh`) | 8 | 0.01x |
| DodgeMesh (**`keepy_dodge_trunk.glb`**, was a `BoxMesh` at 12) | **150** | **0.13x** |
| JumpMesh (**`keepy_jump_log.glb`**, was a `BoxMesh` at 12) | **150** | **0.12x** |
| JumpMarkerMesh (`CylinderMesh`) | 44 | 0.04x |
| StomperMesh (**`keepy_stomper_toad.glb`**, was a `CylinderMesh` at 768) | **148** | **0.12x** |
| EnemyMesh (**`keepy_enemy_rat.glb`**, was a `CapsuleMesh` at 3,456) | **148** | **0.12x** |
| **AirEnemyMesh** (`TorusMesh`) | **4,096** | **3.41x — OVER** |

Why the family total still measured "within": the 8,400 line is 7 x 1,200,
and four of the six variants are near-zero primitives, so a typical live
mix is dominated by 8–12 triangle boxes. Two objects alone —
one ENEMY plus one AIR_ENEMY — already draw **7,552**, i.e. 90% of the
family line. Seven live hazards all of the expensive kind would draw
**28,672**, 3.4x that line. (Whether the spawner can actually produce that
mix is not asserted here; the point is that the measured 7,068–8,372 range
describes a *sample of mixes*, not a bound.)

Root cause is the one finding 1 already named for the collectibles:
**a primitive left at Godot's default tessellation**. `CapsuleMesh` and
`TorusMesh` default to 64 radial segments for shapes that render a few
dozen pixels across, exactly as `SphereMesh` does on
`Noisette.tscn`/`Gland.tscn`.

**Consequence for the incoming hazard `.glb` batch, and it inverts the
usual expectation:** replacing the ENEMY and AIR_ENEMY placeholders with
assets at or under their 1,200 cap is a triangle **reduction**, not an
addition — up to −2,256 and −2,896 per live instance. The two variants
where an import *adds* cost are the ones whose placeholder is a 12-triangle
box (JUMP, DODGE) and the 8-triangle prism (CHARGER). Budget each import
against 7.1's **per-asset** 1,200, never against the family row.

**Confirmed by the first hazard import, same day.** JUMP was one of the
predicted three, and it added exactly as expected: **12 → 150 per instance
(+138)**, 0.12x its unit budget, one-of-each family total 8,352 → 8,490.
Nothing else moved. It also confirms why `TrackPropsAudit`'s family number
is not a budget figure: three runs each side of the install gave **before
4,188 / 7,732 / 8,260, after 7,996 / 11,496 / 11,930** — a spread the log
cannot produce, since one extra AIR_ENEMY on screen is **+4,096 by itself**.
The probe is unseeded; the per-variant table above is the deterministic
number.

**The second hazard import goes the other way, and it is the first one
that does.** STOMPER's placeholder was not a 12-triangle box but a
`CylinderMesh` at **768** — the one primitive in the family already
carrying real tessellation cost. Replacing it with a 148-triangle asset is
therefore a **reduction of 620 per live instance**, and the one-of-each
family total falls **8,490 → 7,870**. The inversion the paragraph above
predicts for ENEMY and AIR_ENEMY turns out to apply, in a milder form, to
STOMPER as well: three of the six variants are cheaper as imported art
than as Godot primitives. Only DODGE and CHARGER remain cases where an
import genuinely adds.

**ENEMY, the prediction's own headline case, lands 2026-08-11 — and beats
it by 1,052.** `keepy_enemy_rat.glb` draws **148** triangles against the
placeholder's 3,456, i.e. **−3,308 per live instance**, not the −2,256
this section forecast. The two numbers are not in conflict and the older
one was not wrong: **−2,256 is the saving against the 1,200 unit cap**
(3,456 − 1,200), which is the most an asset *at* its cap could return. The
asset came in at 148, an eighth of that cap, so the forecast was a **floor
on the gain rather than an estimate of it**. Read the same way, AIR_ENEMY's
−2,896 is also a floor: an asset decimated to the same ~150 LOD the four
shipped hazards use would return **−3,946**.

One-of-each family total, hazards only: **8,008 → 4,700** (**8,052 →
4,744** counting `JumpMarkerMesh`, which is not a hazard variant and is
excluded from the 8,400 line). `AirEnemyMesh` at 4,096 is now **87% of
the entire hazard family**, and the single largest remaining primitive
left at Godot's default tessellation anywhere in this scene.

**AIR_ENEMY lands 2026-08-12 at −3,098, and it is the one case where the
floor above OVERSHOOTS the result — because the forecast assumed a LOD
this subject cannot use.** `keepy_air_enemy_dragonfly.glb` draws **998**
triangles against the placeholder torus's 4,096. The −3,946 predicted
just above is what a ~150-triangle LOD would have returned, and 150 is
exactly what this asset had to refuse: a dragonfly's silhouette is a
pierced wing lattice, decimation closes fine holes before it touches
bulk, and at 150 the wing membrane does not merely close but
disintegrates (see 11, 2026-08-12). The gap between −3,946 and −3,098 is
therefore **848 triangles bought deliberately**, and it buys the only
property that distinguishes this hazard's silhouette from a bar.

It remains the largest single-instance saving in the project — larger
than ENEMY's −3,308 relative to nothing else changing — and 998 still
sits **under 7.1's 1,200-per-hazard cap**, so the openness was not paid
for out of the budget at all.

One-of-each family total, hazards only: **4,700 → 1,602**. The 8,400
line now has 6,798 of headroom against it, and no hazard variant is left
at Godot's default tessellation. CHARGER is the last variant whose
placeholder is a bare primitive (a 8-triangle prism), and it is the only
one where an import will genuinely add.

**CHARGER lands 2026-08-12 and is the only import in the batch that adds
a real cost — as this section predicted three times over.**
`keepy_charger_boar.glb` draws **560** triangles against the placeholder
prism's 8: **+552 per live instance**, the largest single-instance
*increase* in the project, on the only variant that had nowhere to fall
from. One-of-each family total, hazards only: **1,602 → 2,154** (**1,646
→ 2,198** counting `JumpMarkerMesh`). Measured on both sides with the same
throwaway census, not deduced from the delta.

**560 rather than the ~150 four of the six ship at, and the criterion is
not triangle count.** A boar's read is a lowered, pointed head that has to
stay distinct from the shoulder mass; decimation eats the extremities that
carry it. Sampling maximum half-width per Z band against the source, the
snout band retains **74% at LOD 150, 78% at 220, 83% at 300, and 95% at
380**; the **mane crest**, which is what breaks the top of the head-on
outline, only returns at **560**. 560 is the smallest LOD whose entire
front half matches LOD 800's profile (**98.3%, identical through 800**) —
i.e. the JUMP entry's own rule, *indistinguishable from 800*, applied to a
subject on which it lands somewhere else entirely. Whole-mesh bounding box
tells the same story from another angle: X recovers from **−17.4% at LOD
150** to −2.0% only above 520.

Still **47% of 7.1's 1,200-per-hazard cap**, so as with the dragonfly the
legibility was not paid for out of the budget. The family line keeps
6,246 of headroom against 8,400.

**With CHARGER in, every hazard variant now carries an imported asset**,
and the running total of the six installs is a **net reduction**: the
family went 8,352 before the first import to 2,154 after the last, i.e.
**−6,198 per one-of-each**, despite two of the six (DODGE +138, CHARGER
+552) adding. The section's inverted expectation held for four of six.

Meshy's raw output routinely lands at 30k–150k triangles for a single
character. **Ask for a retopologised / low-poly output at these numbers**,
or decimate in Blender before importing — Godot does not decimate on
import.

**Download payload:** keep all `.glb` + textures **under ~2 MB combined**.
The web build already ships a ~35 MB `.wasm`, so the assets are not the
bottleneck, but they are the part that grows without limit if unwatched.
Prefer **one 512x512 or 1024x1024 albedo atlas per character** over
several maps; normal/roughness maps buy very little on unshaded or
flat-lit low-poly.

## 8. Materials and the permanent swamp — the constraint that decides legibility

**This whole section was rewritten on 2026-08-11, when the swamp became the
game's permanent look.** Two pipelines have been deleted since it was first
written, and everything either of them implied about colour is void:

- the **invert + six-hue tint** (`final = (1-rendered)*0.45 + tint*0.55`),
  deleted by the swamp refonte;
- the **luminance-keyed screen grade** that replaced it, deleted by the
  permanent-swamp batch.

There is **no post-process on the frame at all any more**. The value written
into a material is the value that reaches the player, full stop. If you are
reading an older note anywhere in this repo that tells you to author a
colour as the *pre-image* of something, or warns that hue will not survive,
it is describing machinery that no longer exists.

### The look

**Updated 11 August 2026, saturation pass** (device feedback: the values
below this table originally shipped read as near-black on a phone, not as
green — see the dated addendum after the measured table below for the full
before/after and why value could not simply be raised instead).

| | |
|---|---|
| Sky / background | `0.062, 0.115, 0.044` — dark, saturated swamp green |
| Distance haze (`fog_light_color`) | `0.151, 0.260, 0.114` |
| Ambient light | `0.42, 0.50, 0.35` @ energy 0.75 |
| Directional light | `0.66, 0.74, 0.52` @ energy 0.9 |
| Ground slab (albedo) | `0.24, 0.46, 0.17` — saturated green, hue clearly dominant over red |

The track is the **brightest large surface in the frame** and everything
else sinks away from it: that is what makes it read as a path through a bog
rather than a strip in a void. `scripts/world/SwampAtmosphere.gd` breathes
the sky, haze and fog density between this baseline and a slightly deeper
pair (`GameState.SWAMP_*_DEEP`); the breath is confined to the backdrop and
never touches a gameplay surface.

### What actually decides legibility now

The ground renders at **relative luminance 0.150** (was 0.153 before the
11 August saturation pass — held deliberately close, see the addendum
below). That single number sets what is reachable, and it is worth stating
as arithmetic rather than as advice, because it is not obvious:

- to clear **3.0:1 by being brighter**, a surface needs relative luminance
  **≥ 0.549** — a genuinely bright colour, not merely a light one;
- to clear it **by being darker**, it needs **≤ 0.017** — near black.

Anything landing between those two is *below the floor no matter what hue it
is*. So the rule is no longer "put contrast inside the asset" (that was the
invert's rule, when value was the only surviving channel). It is:

> **Every gameplay surface must be decisively brighter or decisively darker
> than the track. Mid-value is the one place nothing can be rescued from.**

Hue now survives to the screen, and it is doing real work again — a red
barrier, an amber ledge and a pink charger are three different colours to
the player for the first time in this project's history. But hue contributes
**nothing** to the WCAG ratio the probes report, so it can never be the
argument for a surface that sits at the track's own value.

### Measured, `DarkPaletteAudit`, both ends of the mist breath

Contrast is WCAG relative-luminance ratio on real sampled pixels, against
the ground (the load-bearing comparison — the camera is close and angled
down, so gameplay objects are read against the track, not the sky).

| Object | shading | albedo | vs ground |
|---|---|---|---|
| DODGE | lit | `0.30, 0.025, 0.025` | **3.19:1** (was 3.28:1) |
| JUMP | **unshaded** | `1.00, 0.78, 0.28` | **3.28:1** (was 3.23:1) |
| STOMPER | **unshaded** | `0.62, 0.86, 1.00` | **3.41:1** (was 3.36:1) |
| CHARGER | **unshaded** | `1.00, 0.72, 0.88` | **3.20:1** (was 3.15:1) |
| ENEMY | lit + emissive | `0.52, 0.08, 0.72` | 1.50:1 — alarm tint, see below |
| AIR_ENEMY | lit + emissive | `0.12, 0.85, 0.22` | 1.08:1 — alarm tint, see below |
| Noisette | lit | `0.95, 0.78, 0.15` | 2.37:1 (reported, never gated) |
| Gland | lit + emissive | `1.00, 0.72, 0.15` | 4.54:1 (reported, never gated) |

DODGE, JUMP and STOMPER were re-authored by the permanent-swamp batch and
all three cleared the floor as a result — 1.72 → 3.28, 1.39 → 3.23 and
1.14 → 3.36. JUMP was switched to **unshaded** at the same time, for the
reason this section already gives below: an unshaded surface renders as
exactly its albedo, which is the only way its measured value is a *known*
number rather than a product of the light hitting it.

> **SATURATION PASS, 11 August 2026 (device feedback: the swamp read as
> black, not green).** The "vs ground" column above is the CURRENT
> measurement, after the ground albedo, sky, haze, curbs and decor tints
> all moved to higher saturation and a unified ~105 deg hue (see "The
> look" table above). Ground albedo moved `0.42, 0.44, 0.24` (raw H=66,
> S=0.46, V=0.44) → `0.24, 0.46, 0.17` (raw H=105.5, S=0.63, V=0.46);
> **rendered** ground (what `DarkPaletteAudit` actually samples, after
> this scene's ambient/directional light) moved H=76.7/S=0.68/L=0.153 →
> H=103.1/S=0.81/L=0.150 — the ambient light (`0.42, 0.5, 0.35`) pulls
> saturation and hue further than the raw albedo alone would suggest,
> which is why the final value was reached by re-measuring with the real
> probe rather than by picking a number on paper: a first attempt at
> `0.25, 0.47, 0.18` rendered at L=0.158, close enough to the CHARGER
> ceiling above to drop it to 3.08:1. Held ground luminance deliberately
> close to its old value (0.150 vs 0.153) for the same reason the
> arithmetic two sections up exists — the four hazard floors this table
> exists to protect. Sky/haze moved the same direction: `SWAMP_SKY` raw
> S=0.35/V=0.08 → S=0.62/V=0.115 (the low V was why the title screen and
> the opening seconds of a run read as grey-black rather than green —
> `SwampIdentityAudit`'s TITLE SCREEN sample went from mean saturation
> 0.295 to 0.582 as a direct result). `PursuerContrastAudit` silhouette
> moved 4.13/4.06 → 4.05/3.99 (floor 2.5:1, still comfortable).

> **ENEMY and AIR_ENEMY are measured in their ALARM tint, not at rest,**
> and the probe's own `(resting)` labels are wrong about this. At the
> capture distance the alarm ramp (`Obstacle.ENEMY_ALARM_ALBEDO`,
> `0.95, 0.08, 0.12`) has fully taken over the material, so what those two
> rows measure is the red telegraph, not the base albedo — changing the
> base colour barely moves them. That red is luminance-poor against the
> track regardless of its hue, which is why both sit low. Raising them means retuning the
> **telegraph**, not the art: a gameplay-legibility decision, left for
> Mathieu. The mislabelling is pre-existing and is called out here rather
> than silently corrected, because the numbers under it are real.

> **The CHARGER is the case where hue and luminance genuinely disagree.**
> Its shipped hot magenta (`1.00, 0.15, 0.62`) measured **1.45:1** — not a
> tuning miss but a property of magenta, which has no green channel and so
> cannot be luminance-bright at any saturation. It is the only *fatal*
> hazard, so it is also the one that must never be missed. The batch raised
> it to a pale hot pink to clear the floor by value while keeping the hue
> identity. The accessibility argument is the one that decided it: for a
> deuteranope, magenta against olive is precisely the confusable pair, and
> luminance is all that is left.

**Still true, and still the strongest advice here:**

- **Silhouette is the most reliable cue there is** — it is geometry, and no
  palette change touches it. Give each hazard a shape readable in pure
  black at a glance.
- **Use `shading_mode = unshaded`** for anything whose appearance must be
  predictable. CHARGER, STOMPER, JUMP, the jump marker, the lane curbs, the
  trackside props and the pursuer body all do.
- **Emission is no longer inverted** (nothing inverts), so a glow is once
  again a dependable "always bright" cue.
### 8.1 Background decor (procedural, no asset yet)

`scripts/world/Decor.gd` (`World/Decor` in `Game.tscn`) draws the two
background hill layers with plain Godot primitives (`CylinderMesh` cones) —
no `.glb`, no texture, nothing this file's import checklist applies to yet.
It follows the same colour rule as every other dark-mode-visible surface in
§8: unshaded, and separated from the ground and from each other by **value**
(far layer darker than the ground, near layer lighter, both short of the
sky), never by hue alone.

When a real low-poly mountain/hill asset replaces a layer, it hooks in the
same way the ground tile itself is already prepared for: swap the
`CylinderMesh` for a `ModelSlot`-style install point on that layer's pooled
instances (see `ModelSlot.gd`'s own doc for the pattern), keep the same
per-layer value separation, and keep `shading_mode = unshaded` unless the
new asset's own internal contrast is verified to hold under the invert —
§8's own "put the contrast inside the asset" rule applies here exactly as
much as it does to a hazard. Budget-wise, a background hill has no
gameplay-legibility requirement at all (it competes with nothing the player
must read), so it can be considerably cheaper than the §7 hazard/character
figures — a few hundred triangles across the whole layer is already visually
generous for something this far from the camera and this rarely the focus of
attention.

The ground tile's own per-segment tint variation (`TrackSegment.gd`,
`_reroll_ground_tint`) is the other half of this batch and needs no asset
hook at all: it duplicates the ground `ModelSlot`'s material once per pooled
segment (via `apply_material()`/`slot_material()`, never the slot's `mesh`
or a direct `surface_material_override`) and re-rolls a small albedo drift
around the ground's own base colour every time that segment is populated —
so it keeps working unchanged the day a real ground tile asset is installed
in that same slot.

**RNG rule for anything added under `Decor.gd` or the ground/curb variation
it sits next to:** always draw from a dedicated `RandomNumberGenerator`
instance, never the global `randf()`/`randi()`/`randf_range()` free
functions. Those draw from Godot's single global RNG stream, which is the
exact stream `TrackManager`'s own spawn rolls draw from and the one several
`scripts/dev/*Audit.gd` probes call the global `seed()` against for
reproducible runs (see e.g. `StrikeAudit.gd`, `DevSeed.seed_value()`). A
decor draw on that shared stream does not change any probability, but it
does shift every gameplay roll that comes after it by one step — silently
turning a purely-visual system into something that changes which hazards a
seeded run actually spawns. Caught in this same batch (see the commit
history around `Decor.gd`/`TrackSegment.gd`'s `_tint_rng`) before it shipped.

### 8.2 Trackside props (four procedural, two imported since 2026-08-10)

`TrackSegment.gd` (`_build_trackside_props` / `_place_trackside_props`)
draws low-poly props standing on the ground plane just outside the track.

**Four of the six kinds are still plain Godot primitives** — one 6x3
`SphereMesh` squashed and yawed for a rock, boxes on capless cylinders for
the bench and sign, three squashed spheres for the bush — with no `.glb`
and no texture, so this file's import checklist does not apply to them.

**Two are imported meshes as of 2026-08-10**: `tree` (a bare winter tree)
and `stump` each draw one 150-triangle `.glb` from `assets/models/`. They
are **not** `ModelSlot` installs and §2's procedure does not describe them
— see 8.3. Their albedos are unchanged, and are still the swept values in
the table below: the mesh changed, the palette did not.

> **The `tree` kind lost its second albedo.** It was a trunk under a
> canopy, i.e. two values on one object; the bare tree is all branches, so
> `_TREE_CANOPY_COLOR` (0.14, 0.20, 0.15) is gone with the cone that
> carried it and `_TREE_TRUNK_COLOR` is now the whole prop. That REMOVES a
> value from the swept set without adding one, so no pair below needs
> re-measuring — and it retires the worst pair the table shipped with, the
> canopy-vs-trunk 1.29:1 that was the hardest of the six to tell apart.

**They belong to a TILE, not to the world**, which is why they are built
and pooled by `TrackSegment` rather than added to `Decor.gd`. A hill needs
its own pool because it scrolls at its own parallax rate and belongs to no
segment; a prop standing on this slab's shoulder travels and recycles with
that slab for free, exactly like the pooled Obstacle/Noisette/Gland
siblings. Built once in `_ready()`, then only ever shown, hidden and
repositioned by `populate()` — nothing is allocated during a run.

**The keep-out is the load-bearing constraint.** The ground slab is
`Hitboxes.GROUND_SIZE.x` = 6 m wide with lanes at ±2 m, and everything
inside it is the readable play area. So the rule is written against a
prop's **silhouette edge**, never its centre: a trunk centred at
|x| = 3.2 satisfies "outside the slab" while its 0.9 m canopy still hangs
a third of a metre over a lane the player is reading a hazard in. Every
placement adds `_PROP_KEEPOUT_X` (slab half-width + 0.4 m margin) **and
the prop's own half-width** before it adds any random spread, so the
clearance is arithmetic rather than a tuning value that happens to be big
enough. For a yawed, z-stretched rock the half-width used is its longest
semi-axis, which bounds the silhouette at every rotation.
`scripts/dev/TrackPropsAudit.tscn` phase 2 rolls 4,000 `populate()` calls
and measures the closest approach off the real mesh AABBs — measured, not
re-derived from the placement formula, which would only ever agree with
itself. Worst observed: **3.244 m against a 3.000 m slab.**

**Colour.** Same rule as everything else here: unshaded, separated by
**value**, never hue. What changed relative to 8.1 is *what they are seen
against*. There is no ground mesh beyond |x| = 3, so the backdrop for a
trackside prop is the sky and the two hill layers — the brightest surfaces
in the scene — and not the ground. That puts the whole prop family in the
scene's darkest band. Contrast ratios (WCAG, sRGB-linearised, computed on
the raw albedos; §8's affine argument means dark-mode preserves the
ordering at 45% strength):

| | albedo | vs ground | vs curb | vs far hill | vs near hill | vs sky |
|---|---|---|---|---|---|---|
| tree canopy | `0.14, 0.20, 0.15` | 2.76 | 9.67 | **1.63** | 4.80 | 6.90 |
| tree trunk | `0.13, 0.10, 0.07` | 3.57 | 12.52 | **2.11** | 6.21 | 8.94 |
| rock | `0.18, 0.19, 0.20` | 2.73 | 9.57 | **1.61** | 4.75 | 6.83 |

The far hills (`0.28, 0.32, 0.30`) are the binding constraint at
1.61–1.63:1, which lands inside the 1.56–1.92:1 band §8 already measured
for the lane barrier — a deliberately high-contrast object — against the
ground. **There is no better answer available in this scene:** sweeping
target luminance across the whole range, the best achievable worst-case
against ground/curb/both hills is 2.57:1 at pure black and falls off
monotonically from there, because the far hills are themselves dark. Going
brighter to escape them collides with the ground or the near hills
instead.

Two honest limitations, neither fixed:

- **The trunk sits at 1.18:1 against the pursuer's near-black body.**
  Accepted rather than resolved: escaping it means brightening into the
  far-hill collision above. The separation is carried by silhouette and
  position instead — §8's own "silhouette is the most reliable cue there
  is" — a 0.1 m trunk flanking the track against a 2.2 x 3.4 m owl
  centred behind the player.
- **Internal light/dark structure is weak** (canopy vs trunk 1.29:1),
  well short of the 3:1 §8 asks for. That rule is written for *hazards*,
  which the player must read under time pressure; 8.1 already establishes
  that background decor "competes with nothing the player must read", and
  the hills themselves carry a single flat colour each.

**Cost:** 511–584 triangles at the worst measured frame, ~1% of the
50,000 target (§7.2), across at most four props per tile. Tessellation is
set once at build time, never per placement — a primitive left at Godot's
default is ~4,000 triangles for one boulder, and
`TrackPropsAudit.PROPS_TRIANGLE_BUDGET` exists mainly to catch exactly
that mistake.

**Zero gameplay coupling**, and the props need a stronger claim here than
the hills do because they live *inside* a `StaticBody3D`: a
`MeshInstance3D` child contributes nothing to that body's shape set, only
a `CollisionShape3D` does, and none is created. `TrackPropsAudit` phase 3
asserts the segment still carries exactly one shape (the slab) rather than
leaving that as prose. They also never touch `GameState` — not even the
one-way reads `Decor.gd` and `LaneBarrier.gd` make — and they are
invisible to everything that walks a segment's children, since
`TrackManager` and the bot probes all filter on `child is Obstacle` and
`AssetContractAudit` collects only `ModelSlot` and `CollisionShape3D`
nodes.

The **RNG rule from 8.1 applies unchanged**, and props use their own
`_prop_rng`, separate from `_tint_rng` so that retuning one can never
re-sequence the other.

When a real low-poly tree or rock asset replaces these, it hooks in the
way 8.1 describes for the hills: a `ModelSlot`-style install point on the
pooled instances, same value separation, `shading_mode = unshaded` unless
the asset's own internal contrast is verified under the invert — and the
keep-out arithmetic must then be fed the **asset's** measured half-width,
not the primitive's, or the guarantee above quietly stops holding.

#### Second pass — bench, sign, stump, bush (2026-08-09)

Four more kinds, same system: built once in `_ready()`, shown/hidden and
repositioned by `populate()`, recycled with the tile. No new pool, no new
`DecorRng` stream — `_prop_rng` is reused, because taking a new stream
would re-number every stream created after it and move the background the
F10 contrast probes measure against (see `DecorRng.gd`'s own note).

Which kind a populated slot draws is now a **weighted roll over six**
rather than a tree/rock coin flip, so a tile is a mixed handful instead of
the same catalogue in the same order. Exactly one draw picks the kind
whatever the outcome, so the weights can be retuned without re-sequencing
the rest of a segment's decor.

| kind | primitives | triangles | weight |
|---|---|---|---|
| tree | tapered trunk + 5-sided cone | 25 | 0.32 |
| rock | one 6x3 squashed sphere | 48 | 0.20 |
| bush | three 6x2 squashed spheres, offset into a clump | **108** | 0.18 |
| stump | 6-sided cylinder + squashed dome | 48 | 0.14 |
| bench | 2 boxes + 2 capless cylinders | 44 | 0.09 |
| sign | capless post + **blank** box board | 22 | 0.07 |

Counted with `mesh.get_faces().size() / 3`, the same call
`TrackPropsAudit` uses, so these are directly comparable with its
per-family table. Tessellation is fixed at build time and never varies
with the size rolls, so each figure is exact rather than a worst case.

**The sign board is blank by construction** — no texture, no text, no
second albedo. It is a silhouette and nothing on it is ever meant to be
read, so there is no legibility claim to defend at any camera distance.

**Keep-out: unchanged in kind, extended to the new shapes.** Every
placement still adds `_PROP_KEEPOUT_X` **and the prop's own half-width**
before any random spread. What each kind contributes as that half-width:

- **bench / sign** take a small yaw (±0.21 rad) rather than the rock's
  free spin, so their half-width is the *exact* rotated extent,
  `depth/2·|cos θ| + length/2·|sin θ|`, not the bounding circle a free
  spin would force. A bench is 1.1–1.7 m long; bounding-circling it would
  have pushed it ~0.4 m further out for nothing.
- **stump** uses its flared base radius, the widest point; the dome never
  exceeds the cylinder's own radius.
- **bush** adds its furthest blob's offset to that blob's radius — the
  cluster's silhouette edge, not the cluster centre. Same shape of
  argument as the tree adding its *canopy* radius rather than its trunk's.

`TrackPropsAudit` phase 2 measures this off the real mesh AABBs over
4,000 `populate()` calls, and `nearest_prop_edge_x()` now walks a single
`_PROP_MESH_KEYS` list rather than a literal — so a kind added later
cannot be silently left out of the check that keeps props off the play
area. Green on 8 consecutive runs with the new kinds live.

**Colour — swept, not eyeballed, and the sweep found a real limit.**
Method as above (sRGB-linearised relative luminance, WCAG ratio on raw
albedos). The scene's occupied luminance line, sorted:

| surface | L |
|---|---|
| tree trunk | 0.0109 |
| tree canopy | 0.0288 |
| rock | 0.0297 |
| far hill | 0.0786 |
| ground | 0.1674 |
| near hill | 0.3282 |
| sky | 0.4939 |
| curb | 0.7122 |

Sweeping target luminance, the best achievable worst-case against the
five environment surfaces **and** the three existing prop families at
once is **1.32:1**, at L≈0.236. That is the finding, not a shortfall in
the search: the dark band that gives the best backdrop contrast — which
is why all three original props live in it — is already full, so
separating four *more* families from those three and from the backdrop
pulls in opposite directions. The four largest usable gaps in the line
give only 1.23–1.27:1 to their own edges.

Chosen accordingly, spread **up** the line rather than crowded into the
dark band:

| | albedo | L | vs ground | vs curb | vs far hill | vs near hill | vs sky | vs canopy | vs trunk | vs rock |
|---|---|---|---|---|---|---|---|---|---|---|
| bush | `0.11, 0.16, 0.12` | 0.0192 | 3.14 | 11.02 | 1.86 | 5.47 | 7.86 | 1.14 | **1.14** | 1.15 |
| stump | `0.32, 0.24, 0.15` | 0.0528 | 2.12 | 7.42 | **1.25** | 3.68 | 5.29 | 1.30 | 1.69 | 1.29 |
| bench | `0.45, 0.36, 0.26` | 0.1164 | 1.31 | 4.58 | **1.29** | 2.27 | 3.27 | 2.11 | 2.73 | 2.09 |
| sign | `0.50, 0.48, 0.42` | 0.1963 | 1.13 | 3.09 | 1.92 | **1.54** | 2.21 | 3.13 | 4.05 | 3.09 |

Mutual separation of the six kinds is 1.48:1 at worst (bench/sign) —
**better than the 1.29:1 the canopy/trunk pair already ships with**, so
the family is internally more legible than before, not less.

Two limitations, stated rather than tuned away, in the same spirit as the
two above:

- **The bush sits at 1.14:1 against the tree trunk and canopy.** No
  luminance in that sub-band does better: the trunk↔canopy gap is
  0.0109–0.0288 wide and its own midpoint is only 1.13:1 from either
  edge. It is also the case where value separation matters least — a bush
  *is* foliage, sharing the canopy's value is correct scene logic, and
  the silhouettes (a low three-lobed clump against a tall cone, or
  against a 0.1 m vertical trunk) are what separate them. §8's "silhouette
  is the most reliable cue there is", the same argument the trunk already
  leans on at 1.18:1 against the pursuer.
- **Bench and stump dip to 1.29 / 1.25:1 against the far hills**, below
  the 1.61:1 floor the original three hold. That is the price of the
  spread: they buy 2.09–2.73:1 against every existing prop, which is what
  stops a bench reading as a boulder. Going darker to fix the hill
  contrast would collapse them back onto the rock.

**Cost and the frame it is spent against — re-measured 2026-08-09**, on
the tree that already carries the eye-sphere fix of 7.3. Eight runs of
`TrackPropsAudit` before and after, worst frame kept per run:

| | props family | frame total |
|---|---|---|
| before (six-kind system absent) | 344 – 582 | 44,943 – **53,858** |
| after | 377 – **871** | 41,423 – **61,947** |

The props' own share is what this batch controls, and it stays well
inside the 1,500 `PROPS_TRIANGLE_BUDGET` the probe enforces — 871 at
worst, 58% of it. Against the 50,000 frame target there is **no positive
headroom and there was none before this batch**: the worst frame measured
on the untouched tree is already 3,858 over. The dominant contributor is
unchanged and out of scope here — collectibles ranged 21,120–33,792
across these runs, against the 300 §7.1 budgets for them (finding 1 of
7.2, still not done).

> ⚠️ **`TrackPropsAudit` does not seed anything, so `--seed=20260806` is
> inert for it.** It calls neither `DevSeed.apply()` nor
> `DecorRng.force_seed()` — checked, not assumed. Its frame total is
> therefore a sample from an *unseeded* run: the same binary measured
> 44,943 and 53,858 on consecutive invocations with nothing changed.
> **Any single run of it is not a budget figure**, which is why the table
> above reports ranges over eight, and why the 57,402 recorded earlier
> and the numbers here cannot be compared one-to-one. This is the same
> class of defect F10 fixed for the contrast probes (`docs/PROBE_AUDIT.md`);
> it is recorded here rather than fixed because seeding this probe would
> change what every previously recorded frame figure means, and that
> deserves its own batch. The keep-out and collider phases are unaffected
> — they assert over 4,000 rolls, not over one sampled frame.

**Zero gameplay coupling holds unchanged**, and was re-verified rather
than argued: all seven gated bot probes plus `AssetContractAudit` and
`ChargerShapeProbe` byte-identical before and after at seed 20260806,
0 colliders moved. The new kinds add `MeshInstance3D` children only —
still no `CollisionShape3D` anywhere under a segment beyond the slab's.

### 8.3 Imported decor props are flat, untextured and unlit — by decision

The two imported props of 8.2 carry **no texture at all**: no base colour
map, no normal, no metallic-roughness. Their material is a single flat
albedo with `KHR_materials_unlit`. Three reasons, in the order they bind.

**1. Payload.** The five distinct Meshy decor sources import to **64.91 MB
of `.ctex`** against a whole shipped `.pck` of **4.23 MB** — a 15x
increase, on a game whose payload lesson (§7, 2026-08-09) was learned by
finding 35.84 MB of dead weight and cutting it. The single worst offender
was a 4096x4096 metallic-roughness map on every asset, which is also the
least useful one here. Dropped, the two installed props cost **+13,120
bytes of `.pck` between them**, measured.

**2. Unlit has no use for most of those maps anyway.** §8's rule is
unshaded, because only an unshaded surface has a *known* colour once the
dark-mode inversion runs. Metallic and roughness do nothing on an unlit
material, and a normal map does nothing without a light to perturb.

**3. The decimator cannot carry UVs.** Welding the separate shells is what
lets a quadric decimator reach these targets at all (see §11), and it does
not preserve UVs, so a texture could not survive the trip at any triangle
count. Keeping the texture would mean not decimating, which reason 1
forbids. This is also exactly why the leafy tree was **not** installed:
its character *is* its leaf colour, so the pipeline destroys the thing
worth having, and the result reads worse than the 25-triangle cone it
would have replaced.

> **`KHR_materials_unlit` IS ADDED BY US, NOT CARRIED OVER.** Not one of
> the five Meshy sources declares it — `extensionsUsed` is absent from all
> of them, and all are PBR with baseColor + metallicRoughness + normal.
> `scripts/dev/decimate_decor.py` writes the extension into every file it
> emits. Do not read a `.glb` in `assets/models/` as evidence of what
> Meshy produced.

> **`baseColorFactor` is LINEAR; the palette in `TrackSegment.gd` is
> sRGB.** Godot's `StandardMaterial3D.albedo_color` is an sRGB colour and
> 8.2's sweep was run against `_unshaded(Color(...))` materials carrying
> those numbers, so the decimator converts before baking. Writing the sRGB
> value straight in — which the first version of the script did — made
> Godot read `_TREE_TRUNK_COLOR`'s 0.13 back as **0.396**, far brighter
> than the swept value. It never reached the screen, because
> `_build_prop_mesh` overrides the surface material with the GDScript
> colour, but that made the override the only thing holding the palette
> rather than a second line of defence. Both now agree, verified by
> reading the material back after import.

## 9. Godot 4.3 import notes

- A `.glb` imports as a **`PackedScene`** whose root is a `Node3D`.
  `ModelSlot` expects exactly that and will refuse (loudly, keeping the
  placeholder) anything else.
- **Keep `.import` files committed.** They carry the import settings; a
  missing one means a different-looking asset on the CI machine.
- Godot imports glTF PBR as a **lit `StandardMaterial3D`**. To make one
  unshaded (§8), extract the material in the Import dock and set
  `Shading > Shading Mode = Unshaded`, then re-save. Setting it on the
  imported scene directly is lost on reimport.
- **Textures:** the Web export needs a mobile-friendly VRAM format. Leave
  compression at the default `VRAM Compressed` and let the exporter pick;
  do not force S3TC/BC, which mobile Safari does not support.
- **`gl_compatibility` has no SDFGI, no volumetric fog, no SSAO.** Keep
  materials to albedo + optional normal. Anything fancier silently does
  nothing.
- Meshy exports are frequently **Z-up and at an arbitrary unit scale**.
  Correct both on the slot (`Model Rotation Degrees` / `Model Scale`), not
  by re-exporting — the slot is the documented place for it.
- The web build uses the **`web_nothreads`** template. Nothing about the
  assets depends on that, but it is why the `.wasm` is large.

## 10. Acceptance checklist

Run all five after installing any asset. The first two are the ones that
catch a rebalancing.

    godot4 --headless --path . res://scripts/dev/AssetContractAudit.tscn
    godot4 --headless --fixed-fps 60 --path . res://scripts/dev/PursuerFramingAudit.tscn
    godot4 --headless --path . res://scripts/dev/ChargerShapeProbe.tscn
    godot4 --headless --path . res://scripts/dev/AlarmRampAudit.tscn
    godot4 --headless --path . --export-release "Web" build/web/index.html

- **`AssetContractAudit`** must stay green: every collider still matches
  `Hitboxes.gd`, and the pursuer still has none.
- **`AlarmRampAudit`** must stay green whenever the asset lands on a slot
  whose material is ANIMATED — `Obstacle/EnemyMesh`,
  `Obstacle/AirEnemyMesh`, `TrackSegment/MeshInstance3D`. See §2.1: an
  imported material binds differently from a placeholder one, and the
  failure mode is a telegraph that silently stops rather than anything
  that looks broken. Cheap enough to run on every install regardless.
- **`PursuerFramingAudit`** must stay under 30% — this is the Hibou's size
  gate (§6).
- **`ChargerShapeProbe`** will **deliberately fail** once a model is
  installed in the CHARGER's slot: it reads the placeholder prism's own
  vertices to assert the nose points at +Z. That contract does not stop
  mattering when the art lands — it needs re-expressing against the
  imported geometry. Treat the failure as the to-do it is.
- Then re-run the gameplay probes (`AntiFrustrationAudit`,
  `RushFrustrationAudit`, `PursuerAudit`, `StrikeAudit`, `ShrinkAudit`)
  with a fixed `-- --seed=<int>`. Their output should be **byte-identical**
  to the pre-swap run at the same seed. If it is not, an asset reached
  something it should not have.

## 11. Import log

Attempts to install a real Meshy asset, and why they did or did not proceed.
Kept here so the next session does not repeat a measurement that already
has an answer.

### 2026-08-08 -- Hibou (pursuer), REJECTED at the pre-import check

`assets_source/pursuer/Meshy_AI_Emberwing_Owl_0808114211_texture.glb`
(26.9 MB) was measured before any Godot import, per §2's "verify before you
import" rule and this batch's explicit instruction not to skip it.

Parsed the glTF JSON chunk directly (no Blender/Godot in this sandbox;
`pygltflib`/`trimesh` were not preinstalled and were added ad hoc for this
check) and summed `indices.count / 3` over the mesh's one primitive:

    total triangles : 581,260
    total vertices   : 301,606
    budget (Hibou)   :   8,000   (Section 7)

**581,260 is exactly Meshy's own pre-decimation figure** referenced in this
batch's task brief -- the file was exported straight off the generator with
no decimation pass applied at all, not a "decimated but still too heavy"
asset. It is **72.7x the 8,000-triangle budget** and the 26.9 MB payload
(vs. the ~2 MB combined target in §7) is the same defect showing up as file
size instead of triangle count.

**Decision: do not import.** No ModelSlot change, no scene edit, no
install. §1's contract (visual-only changes) cannot even be evaluated until
the mesh is inside budget -- an oversized visual is still a visual-only
change by that contract's letter, but it defeats the frame-budget reasoning
in §7 that the contract exists to protect, on the one GPU-bound renderer
(`gl_compatibility`) this project ships on.

**Decimation, checked for feasibility, not performed as a deliverable:**
this sandbox does not carry Blender, but `pip install trimesh
fast_simplification` succeeded and `trimesh.Trimesh.simplify_quadric_decimation
(face_count=6000)` ran on the real file, producing 5,999 triangles in
about a minute. That confirms an in-budget decimation is mechanically
possible, but it was not carried through to a committed asset here: quadric
decimation on a single merged primitive does not guarantee the 4 separate
JPEG maps (`base_color`, `metallic_roughness`, `normal`, `emissive`) stay
correctly UV-mapped afterward, and that needs a visual check this sandbox
cannot do (no renderer, no way to eyeball the result). Recommended next
step, either one:

- **In Meshy:** re-export requesting the "retopologized / low-poly" output
  explicitly (§7 already says the raw output is 30k-150k triangles for a
  single character; this one skipped that stage entirely), target
  5,000-6,000 triangles for the Hibou.
- **In Blender:** apply a Decimate modifier (Collapse, ~1% of 581,260 to
  land near 5,800) on the source file, verify the 4 texture maps still line
  up in the UV editor before re-export, then drop the result at the same
  `assets_source/pursuer/` path for the next session to pick up.

Orientation (the -Z-facing-back check from §3/§6) was not evaluated --
that step only applies once the budget step passes, and it did not.

### 2026-08-08 -- Hibou (pursuer), second attempt, ACCEPTED after texture recompression

`assets_source/pursuer/owl_pursuer_decimated.glb` (22.3 MB) superseded the
581,260-triangle file above. Verified before any Godot import, per §2:

**Triangle budget** -- parsed the glTF JSON chunk directly (`struct`/`json`
in Python, no Blender/Godot), summed `indices.count / 3` over the mesh's one
primitive:

    total triangles : 7,070
    total vertices   : 7,399
    budget (Hibou)   : 8,000   (Section 7)

Matches Meshy's own claimed figure -- this file, unlike the first attempt,
really was decimated. **Within budget, by 930 triangles.**

**22.3 MB diagnosis** -- read each of the 4 image bufferViews' PNG `IHDR`
chunk directly: `Baked_Emit` 4096x4096 (3.0 MB), `normal` 2048x2048 (4.2 MB),
`Baked_BaseColor` 2048x2048 (5.7 MB), `Baked_MetallicRoughness` 4096x4096
(8.1 MB) -- all uncompressed PNG. **The 22.3 MB is entirely texture
payload, not mesh data** (the 4 accessors backing POSITION/NORMAL/
TEXCOORD_0/indices total 279,188 bytes, i.e. 0.28 MB). Confirms the task
brief's framing: face budget and file weight are separate defects, and only
the second one is present here. Against the ~2 MB combined target in §7,
these four maps needed recompression before import; the triangle count did
not.

**Recompression, performed in-sandbox** (Pillow, no Blender/Godot needed for
this step): checked the material's `alphaMode` first -- unset, i.e. glTF
default OPAQUE, so the RGBA alpha channel present in 3 of the 4 PNGs is
ignored by any correct renderer and was safe to drop. Resized and
re-encoded, same UV space (no atlas repacking, so UV correctness is
preserved by construction, not just by inspection):

| map | before | after | format |
|---|---|---|---|
| Baked_BaseColor | 2048x2048 PNG, 5.7 MB | 1024x1024, 239 KB | JPEG q88 |
| Baked_Emit | 4096x4096 PNG, 3.0 MB | 1024x1024, 65 KB | JPEG q88 |
| normal | 2048x2048 PNG, 4.2 MB | 512x512, 393 KB | PNG (kept lossless) |
| Baked_MetallicRoughness | 4096x4096 PNG, 8.1 MB | 512x512, 64 KB | JPEG q90 |

Base colour and emissive kept at 1024 (they carry the readable plumage and
the closing-cue stripes); normal and metallic/roughness dropped further
since §7 already notes they "buy very little on unshaded or flat-lit
low-poly" and this material ended up unshaded anyway (see below). Rebuilt
the `.glb` binary chunk by hand (same header, same 4 mesh bufferViews
byte-identical, images re-encoded and re-offset, 4-byte aligned) rather than
through a round-trip exporter, so no other property could drift. Result:
**22.3 MB -> 1.01 MB**, verified after rebuild that triangle/vertex counts
are unchanged (7,070 / 7,399) and all 4 image references still resolve.

**Orientation** -- rendered the rebuilt `.glb` offscreen (Godot headless,
`--rendering-driver opengl3` under `xvfb-run`, a throwaway probe scene, not
committed) from both `+Z` and `-Z` looking at the origin. The mesh's
authored front (face, eyes, beak) points **+Z** in local space, its back
(feathers, the emissive stripe pattern) points **-Z** -- backwards from
this project's convention (Pursuer faces -Z, back visible to the +Z-side
camera, per §3/§6). This is exactly the case §9 already documents ("Meshy
exports are frequently ... at an arbitrary rotation -- correct it with
`Model Rotation Degrees`"): fixed with `model_rotation_degrees = (0, 180,
0)` on the slot rather than a re-export. After the 180 degree correction the
back -- with the emissive striations converging toward the belly, matching
the concept art's "seen from behind" brief -- faces the camera side, visually
confirmed in a second render pass.

**UV mapping** -- visually confirmed in the same offscreen renders (front,
back, and a `+X` side view): plumage, eyes and beak read as continuous
surfaces with no stretching, seams or swapped maps after the resolution
drop. Since the recompression only resamples pixels within the existing UV
footprint (no atlas repacking), this was expected, and the render is the
positive confirmation the first attempt's rejection couldn't get to.

**Decision: import**, with the recompressed textures and a 180 degree yaw
correction at the slot. See §6 and §10 for the installed measurements.

**Validation, same day.** Full local run of Godot 4.3.stable headless (not
CI-only this time -- the editor and export templates were fetched into the
sandbox so every probe below ran for real, not by inference from the doc
baseline):

- `AssetContractAudit`: PASSED. 12/12 visuals swap, 0/10 colliders moved,
  pursuer still has none.
- `PursuerFramingAudit`, real mesh, seed 20260806: INTRO 15.5/23.6/23.6%,
  VISIBLE 24.9/26.0/27.0% (mean/p95/max) -- both under the 30% cap, both
  marginally lower than the placeholder capsule at the same AABB (§6).
  CAPTURE is exempt by design.
- `ChargerShapeProbe`: PASSED (rc=0), unaffected -- this batch never
  touches the CHARGER slot, so its wedge-orientation assertion has nothing
  to react to. The "will deliberately fail once a model lands" note in this
  section is about the CHARGER's *own* future swap, not this one.
- **Seven gated bot probes, seed 20260806, before/after diff**:
  `AntiFrustrationAudit`, `ComboAudit`, `PursuerAudit`, `RushFrustrationAudit`,
  `ShrinkAudit`, `StrikeAudit` -- **byte-identical** stdout, pre-swap vs
  post-swap. `PursuerFramingAudit` differs **only** in the occupancy
  percentages above (expected -- that is the one number a visual swap is
  allowed to move). No other line in any of the seven changed, which is the
  actual evidence for "visual-only," not just the AssetContractAudit
  collider check.
- **`PursuerContrastAudit`** (measures the Hibou's own silhouette, which
  `DarkPaletteAudit` does not sample -- see its file header): the GLB's
  default Godot import is a **lit** `StandardMaterial3D`, and that alone
  regressed this probe: silhouette-vs-ground fell under the 2.5:1 floor on
  5 of 6 dark palettes (worst 2.29:1), against the placeholder's clean pass
  (worst 2.72:1) on the identical scene. Root cause matches this probe's
  own documented math: pure black is the optimal albedo against this
  invert+tint, and a lit material picking up scene lighting is not pure
  black in practice. Fixed by adding `KHR_materials_unlit` to the GLB's
  material (the portable, reimport-safe equivalent of the Import dock's
  Shading Mode = Unshaded from §9) -- re-measured, all 6 dark palettes and
  the light phase PASS (worst DARK/2 at 2.53:1). Re-ran the seven-probe
  byte-identical comparison once more against this final unshaded asset:
  same result, material shading does not touch gameplay logic.
- **Web export**: built for real (`--export-release "Web"`, templates
  4.3-stable). `index.pck` **21.79 MB -> 22.01 MB**, a **+0.22 MB** delta
  for the asset -- far below the 1.01 MB source `.glb`, because Godot's own
  VRAM texture compression on export re-encodes the JPEG/PNG maps into a
  smaller GPU-native format. Not a meaningful hit to mobile load time.

**2026-08-09 -- re-measured under a "decimate the owl" brief; the asset was
never the problem, and was NOT decimated.** The brief carried §7.2's figure
forward as "the hibou renders 15,518 triangles against its 8,000 cap" and
asked for an in-sandbox decimation. Re-measuring first -- which the brief
itself asked for -- refuted the premise before any mesh was touched:

- **The `.glb` is 7,070 triangles**, unchanged since this entry recorded it
  above, and **930 inside its 8,000 cap**. Parsed from the glTF JSON chunk
  (`indices.count / 3`) and independently confirmed against what Godot
  builds at runtime (`Mesh.get_faces().size() / 3` on the imported
  `ArrayMesh`): both say 7,070.
- **The other 8,448 came from `EyeLeft`/`EyeRight`**, two `SphereMesh`
  placeholders left at Godot's default 64 x 32 tessellation, 4,224 each.
  7,070 + 4,224 + 4,224 = 15,518, matching §7.2's figure to the triangle.
- **The requested remedy could not have reached the stated goal.** Even a
  zero-triangle owl leaves the family at 8,448, still over 8,000. So the
  decimation was **not performed**: it would have traded away the pursuer's
  gameplay-readable silhouette -- the thing the brief itself said matters
  most -- for a target it could not hit.

**Done instead:** `SphereMesh_Eye` (one shared sub-resource, so one edit
covers both eyes) set to `radial_segments = 16`, `rings = 8`. Family
**15,518 -> 7,646**. Full detail, including why this is invisible in
gameplay, in **§7.3**.

**Validation** (Godot 4.3.stable headless, editor + `4.3-stable` templates
fetched into the sandbox, `--fixed-fps 60` before `--path` and before `--`
per this section's own reproducibility note):

- **Seven gated bot probes, seed 20260806, before/after: byte-identical**,
  all seven, including `PursuerFramingAudit` -- which for the *asset* swap
  above legitimately moved (occupancy is the one number a visual swap may
  change). Here it does not move at all: the eye spheres are children of
  `Silhouette`, not of the installed model, so they never entered
  `visual_aabb()` and the §6 occupancy table is unaffected.
- `AssetContractAudit`: PASSED, 12/12 visuals swap, **0/10 colliders moved**,
  pursuer still has none. `ChargerShapeProbe`: PASSED (rc=0), untouched.
- **Offscreen renders, before vs after, at all three gameplay poses:
  pixel-identical (zero changed pixels).** See §7.3.
- **Web export**: `index.pck` **4,410,432 -> 4,410,448 bytes, +16 bytes** --
  two integers in a scene sub-resource. Both sides built from a throwaway
  worktree at `origin/main` vs the current tree, same templates.
- **`PursuerContrastAudit`: FAILS, and already failed on unmodified
  `origin/main`** -- 6/6 dark palettes under the 2.5:1 silhouette floor
  (worst DARK/2 **1.86:1**), against the **2.53:1 PASS** this entry records
  above. Measured three times on clean `main` before any edit, three times
  after; the two sets are indistinguishable (DARK/2 1.86/1.86/1.84 before,
  1.85/1.84/1.84 after), so **this batch neither caused nor fixed it**.
  It is a **pre-existing regression, open and unexplained**, introduced
  somewhere between the hibou landing and today. Prime suspect, not
  confirmed: the decor batch's per-segment ground tint drift
  (`TrackSegment._reroll_ground_tint`, §8.1) changes the very surface this
  probe measures the silhouette *against*, and it is unseeded -- consistent
  with the run-to-run wobble seen in the light-phase numbers
  (7.37/7.40/7.28:1). Worth someone's next batch; it is the pursuer's
  dark-mode legibility, which is exactly what §8 exists to protect.

### 2026-08-09 -- Keepy (hero squirrel), ACCEPTED

`assets_source/hero/Meshy_AI_Kawaii_Squirrel_with__0808231658_texture.glb`
(22.8 MB). Verified before any Godot import, per §2, independently of the
recon numbers carried into this batch's brief (parsed the glTF JSON chunk
directly, `indices.count / 3` on the mesh's one primitive):

    total triangles : 3,129
    total vertices   : 3,121
    budget (Keepy)   : 6,000   (Section 7)

Matches the brief's numbers exactly. **Within budget, by 2,871 triangles**
-- no decimation needed, unlike either Hibou attempt.

**22.8 MB diagnosis** -- read each of the 4 image bufferViews' PNG `IHDR`
chunk directly: `Baked_Emit` 4096x4096, `normal` 2048x2048,
`Baked_BaseColor` 2048x2048, `Baked_MetallicRoughness` 4096x4096, all
uncompressed PNG -- the same defect shape as both Hibou attempts, texture
payload only. **Material `alphaMode`** -- absent from the glTF material,
i.e. glTF default `OPAQUE` (checked directly rather than assumed from the
Hibou precedent, per this batch's instruction): safe to drop the RGBA
alpha channel present in 3 of the 4 PNGs.

**Recompression, performed in-sandbox** (Pillow, same method as Hibou's
second attempt -- hand-rebuilt `.glb` binary chunk, mesh bufferViews
byte-identical, images re-encoded and re-offset, 4-byte aligned):

| map | before | after | format |
|---|---|---|---|
| Baked_BaseColor | 2048x2048 PNG | 1024x1024, 178 KB | JPEG q88 |
| Baked_Emit | 4096x4096 PNG | 1024x1024, 114 KB | JPEG q88 |
| normal | 2048x2048 PNG | 512x512, 352 KB | PNG (kept lossless) |
| Baked_MetallicRoughness | 4096x4096 PNG | 512x512, 48 KB | JPEG q90 |

Result: **22.8 MB -> 813 KB** (combined with the separately-extracted
texture files Godot's importer writes alongside the `.glb`, ~1.5 MB on
disk total -- still comfortably under the §7 ~2 MB target). Verified after
rebuild that triangle/vertex counts are unchanged (3,129 / 3,121) and all
4 image references still resolve.

**Orientation -- measured, not copied from the Hibou.** Rendered the
rebuilt `.glb` offscreen (Godot headless, `--rendering-driver opengl3`
under `xvfb-run`, a throwaway probe scene, not committed) from `+Z`,
`-Z`, `+X` and top. From the `+Z` camera position (matching the game
camera, which sits at +Z looking toward -Z) the mesh's authored front --
face, eyes, the "K" chest badge -- is what's visible; the `-Z` view shows
the back (tail, back of head). That is backwards from the project's
contract (§3: Keepy faces -Z, back visible to the camera), so the fix is
`model_rotation_degrees = (0, 180, 0)` -- numerically identical to the
Hibou's correction, but arrived at independently by rendering this mesh,
not assumed from precedent.

**Scale and origin.** `POSITION` accessor bounds: X [-0.6164, 0.6129], Y
[-0.6291, 0.6283], Z [-0.9488, 0.9485] -- a nearly-symmetric Y range
(within 0.06%), confirming the brief's prediction that the raw mesh's
origin sits at the model's vertical *centre* (a seated "kawaii" pose,
tail curled up and out along Z), not at the feet. `model_scale` is
computed from the Y span against the §5 height target:

    model_scale = 1.6 / (0.6283 - (-0.6291)) = 1.6 / 1.2574 = 1.2725

No slot-level translation was added, and none was needed: `Keepy/
MeshInstance3D`'s own position, `(0, 0.8, 0)`, was already set (for the
capsule placeholder) to exactly half of the 1.6 target height. Because
the squirrel mesh's local origin is itself within 0.06% of its own
vertical centre, installing it at that same slot position -- with only
`model_scale` applied, no other change -- lands its feet at **world
y = -0.00046** and its head at **y = 1.5995**, both within half a
millimetre of the intended 0/1.6 bounds. Confirmed by
`AssetContractAudit`'s own measurement post-install (below): visual Y
span reports exactly `1.600`. Had the origin *not* been this close to
centred, no fix would have been available under this project's rule (art
corrections live only in `model_scale`/`model_rotation_degrees`, and the
slot's own transform is off-limits) -- this would have needed flagging as
a known issue the way the Hibou's eye-placement was, rather than forcing
a translation the slot has no property for. That did not turn out to be
necessary here.

X and Z do depart from the placeholder's 1.0 x 1.0 footprint at this
scale -- measured (`AssetContractAudit`) at **1.564 wide x 2.414 deep**,
driven mostly by the curled tail sweeping along Z. Per §1's own
corollary ("the visual does not have to match the hitbox") and the
existing CHARGER/Hibou precedent for visual overhang beyond the
collider, this was accepted rather than treated as a defect: the
collider stays the unchanged 0.5 m-radius capsule, and 1.564 m of visual
width is still under the ~1.9 m lane-bleed threshold in §4.

**Installed**: `assets/models/keepy_squirrel_hero.glb` (+ the 4
Godot-extracted textures + `.import` files, same layout as the Hibou),
wired into `scenes/Keepy.tscn`'s `Keepy/MeshInstance3D` (the existing
`ModelSlot`, no new node) with `model_scale = 1.2725`,
`model_rotation_degrees = (0, 180, 0)`.

**Validation**, same day, Godot 4.3.stable headless (editor + `4.3-stable`
web export templates fetched into the sandbox, matching
`.github/workflows/web-build.yml`'s pinned version):

- `AssetContractAudit`: PASSED. `keepy/MeshInstance3D` visual now measures
  `1.564 x 1.600 x 2.414`, `node_y` unchanged at `+0.800`. 0/10 colliders
  moved; `keepy/CollisionShape3D` still `Capsule(r=0.5, h=1.6)` at
  `offset_y +0.800`.
- `ChargerShapeProbe`: PASSED (rc=0), unaffected -- this batch never
  touches the CHARGER slot.
- **Six gated bot probes, seed 20260806, before/after diff**:
  `AntiFrustrationAudit`, `ComboAudit`, `PursuerAudit`,
  `RushFrustrationAudit`, `ShrinkAudit`, `StrikeAudit` -- **byte-identical**
  stdout, pre-swap vs post-swap, confirming the swap changed no gameplay
  roll.

  **Reproducibility pitfall found and fixed while doing this check, worth
  recording**: the first comparison attempt, run without `--fixed-fps 60`,
  came back DIFFERING on all six probes -- not just before-vs-after, but
  (verified separately) **the identical tree run twice in a row against
  itself**, same code, same seed, zero concurrent load. That proved the
  divergence was environmental, not caused by this asset: this sandbox's
  headless Godot does not hold a deterministic physics-tick count across
  runs unless `--fixed-fps 60` pins the simulation to wall-clock-independent
  steps. Two consecutive same-tree runs with `--fixed-fps 60` came back
  byte-identical; the real before/after comparison was then redone under
  the same flag and is the PASSED result recorded above. (A second,
  unrelated mistake during this same check: an earlier before-batch process
  was killed by targeting only its `AntiFrustrationAudit` child rather than
  its whole process group, leaving the parent script alive for ~25 minutes
  writing *after*-tree results into the *before* log directory,
  overwriting two of the six logs with contaminated content. Caught by
  inspecting `ps` output and `/proc/<pid>/cwd` rather than trusting the
  script's own name; both stray trees were killed and the batch re-run
  clean before drawing any conclusion.) Neither issue was caused by, or
  reveals anything about, the squirrel asset itself -- both are recorded
  here so a future session does not have to rediscover them.
- **Web export**: built for real (`--export-release "Web"`, templates
  4.3-stable), before/after via a throwaway worktree at the pre-swap
  commit. `index.pck` **40,767,408 -> 43,352,656 bytes**, a **+2.47 MB**
  delta for the asset. Notably larger than the Hibou's own +0.22 MB --
  the likely reason, not confirmed further because it is outside this
  batch's checklist: the Hibou's material was later switched to
  `KHR_materials_unlit` (see its §11 entry, `PursuerContrastAudit` fix),
  which appears to make its normal/metallic-roughness maps unreferenced
  and let the exporter drop them; Keepy's material imports as the default
  **lit** `StandardMaterial3D` per §9, so all 4 recompressed maps are
  VRAM-compressed and packed into the `.pck`. Still a small fraction of
  the ~35 MB `.wasm` already shipped, and well within what §7 calls "not
  the bottleneck" -- flagged here as a possible follow-up (matching
  Keepy's material shading to §8's dark-mode rules the way the Hibou's
  was) rather than fixed in this batch, since no Keepy-specific contrast
  probe is part of the §10 acceptance checklist this task specified.

**2026-08-09, follow-up in the same day's second batch -- unlit applied, and
the payload hypothesis above CORRECTED.** The flagged follow-up was carried
out, and measuring it properly disproved the explanation this entry had just
offered for the +2.47 MB.

- **`KHR_materials_unlit` applied** to `keepy_squirrel_hero.glb` by the same
  hand-edit as the Hibou (JSON chunk only, BIN chunk verified byte-identical,
  so no mesh or image data could drift). Confirmed by loading the imported
  scene and reading the material back: `shading_mode = 0` (unshaded), and
  Godot reports `normal_texture = null` / `emission_enabled = false` -- i.e.
  three of the four maps are discarded at import, exactly as the Hibou's are.
- **The lit-material explanation for the +2.47 MB was WRONG.** Applying unlit
  and re-exporting moved `index.pck` from 43,352,656 to **43,387,664 bytes --
  35 KB *bigger*, not smaller.** The reason the maps were still being paid for
  is `export_presets.cfg`'s `export_filter="all_resources"`, which packs every
  resource in the project whether any material references it or not. Import-
  time discarding never reaches the exporter. The Hibou's own +0.22 MB was
  therefore never evidence of unlit saving payload either -- the two figures
  were measured against different-sized project trees and are not comparable.
- **The real payload defect, found while measuring the above:** the raw Meshy
  originals in `assets_source/` were being imported and **shipped in the web
  build**. Measured on one identical tree, changing nothing but the export
  filter: `index.pck` **43,387,664 bytes with `assets_source/` -> 5,810,208
  without**, i.e. **35.84 MB of dead payload** that no scene references and
  that every mobile player was downloading. Fixed by adding `assets_source/*`
  to `exclude_filter`, alongside the `scripts/dev/*` exclusion that was
  already there for exactly the same reason (a directory the shipped game
  never loads from). This dwarfs every asset figure in §7 and is the single
  biggest payload item this document has recorded.
- **Unused maps then stripped from the `.glb` itself.** With the material
  proven unlit, `emissiveTexture` / `normalTexture` / `metallicRoughness
  Texture` and their images are unreachable, so they were removed from the
  glTF and their extracted `assets/models/*` siblings deleted: **813,356 ->
  298,344 bytes**, one image (`Baked_BaseColor`) left. Triangle/vertex counts
  re-verified unchanged (3,129 / 3,121), and the result re-rendered offscreen
  against the ground colour to confirm the asset still reads correctly
  unshaded. Recoverable if the material is ever made lit again: the full
  4-map original is what `assets_source/hero/` holds.
- **Net result against the figure this entry originally flagged**, measured
  with `assets_source/` excluded on BOTH sides so the two are comparable:
  baseline (`90bfd39`) `index.pck` 3,164,800 bytes, current 4,430,656 --
  **+1.21 MB for the squirrel plus this batch's two audio cues**, against the
  **+2.47 MB** flagged above. And the build a player actually downloads fell
  from 43.35 MB to **4.23 MB**.
- **Contrast coverage, stated rather than assumed:** there is **no
  Keepy-specific contrast probe in this project.** `PursuerContrastAudit`
  measures the pursuer's silhouette only (zero references to Keepy);
  `StrikeContrastAudit` / `StrikeFatalContrastAudit` / `ComboContrastAudit`
  are HUD-text probes; `DarkPaletteAudit` does sample Keepy, but its
  per-object path carries the documented llvmpipe defect in §8's own note and
  cannot be relied on. So the unlit switch here is justified by §8's argument
  (an unshaded surface's post-invert colour is a *known* value) and by the
  offscreen render, **not** by a measured six-palette contrast pass like the
  Hibou got. A Keepy equivalent of `PursuerContrastAudit` is the honest next
  step before anyone treats Keepy's dark-mode legibility as verified.

#### The StrikeAudit four-line diff -- traced, and resolved

The two audio cues made `StrikeAudit` append four lines to its own stdout
*after* its `PASSED` verdict, breaking the byte-identical comparison this
project gates asset and UI changes on:

    WARNING: ObjectDB instances leaked at exit
         at: cleanup (core/object/object.cpp:2284)
    ERROR: 1 resources still in use at exit
       at: clear (core/io/resource.cpp:604)

**Root cause**, traced with `--verbose` (which names the survivors) and
isolated by changing one variable at a time:

| repro | leak |
|---|---|
| players exist, `play()` never called | **no** |
| `AudioStreamPlayer`s removed from the scene | **no** |
| `play()`, then quit ~10 frames later (0.16s, cue is 0.20s) | **yes** |
| `play()`, then quit after 2s of real time | **no** |

So it is neither the nodes, the streams, nor the `.wav` import: it is
**quitting while a playback is still live.** `play()` instantiates an
`AudioStreamPlaybackWAV` holding a reference to the `AudioStreamWAV`; both are
still alive at `ObjectDB` cleanup, which is why the count is exactly *one*
resource. `StrikeAudit`'s last run frequently ends *on* a strike (the fatal
cue is 0.55s) and then goes `_end_run -> _finish_phase -> _report -> quit()`
within a frame or two.

**Why it was intermittent (5 runs in 6) at a fixed seed:** playbacks retire on
the AudioServer's own thread against the **wall clock**, while the probe runs
under `--fixed-fps 60`, where frames advance by a fixed delta as fast as the
CPU allows. It is a race the seed does not control. (An earlier note here
called it deterministic; that was drawn from two agreeing samples and was
wrong. An earlier note also said the resource was "held somewhere the script
cannot reach from GDScript" -- also wrong, and superseded by this entry: it is
reachable, it simply needs real elapsed time before `quit()`.)

**It never reached a measurement, and could not have.** The diff is a pure
append at EOF -- 5,351 lines identical, 4 added. `HUD.gd` never writes
`GameState` (every one of its references is a read, a constant, or a signal
connect); `StrikeAudit` never references the HUD; both are independent
subscribers to `GameState.strike_taken`. The leaked objects are audio playback
objects, not gameplay state. And `scripts/dev/*` is excluded from the shipped
build, so no player ever runs this path.

**Fixed in the probe, not in the game** (`StrikeAudit._settle_audio_before_quit`),
since nothing in `HUD.gd` was misbehaving. Note it is a **real-time** wait
(`OS.delay_msec`), not a frame wait: awaiting frames, or a `SceneTreeTimer`,
is also driven by the fixed delta and can return before the audio thread has
done anything. Re-measured **byte-identical** to the pre-audio baseline. Any
future probe that fires audio and quits promptly needs the same treatment.

### 2026-08-10 -- Trackside decor batch, NOT INSTALLED (measured, not assumed)

Six `.glb` were committed **directly to `main`** (`0502fb8`, "decor") without a
branch or a PR -- the same binary-transfer exception already recorded for the
Emberwing Owl. See CLAUDE.md for the exception itself; this entry is about what
the files turned out to be.

**The brief described seven files and six subjects (deciduous tree, conifer,
rock, stump, bush, bench). None of those three counts is what arrived.**
Measured, not read off the filenames:

| file | md5 | tri | verts | PNG maps |
|---|---|---|---|---|
| `..._Low_Poly_Tree_0810131748_texture.glb` | `befb3ee0` | 5,230 | 5,798 | 3 (14.60 MB) |
| `..._Winter_s_Reach_0810130613_texture.glb` | `2d260e82` | 4,486 | 6,635 | 3 (18.14 MB) |
| `..._Low_Poly_Tree_Stump_0810131232_texture.glb` | `69f8c267` | 4,130 | 3,650 | 3 (14.37 MB) |
| `..._Green_Cluster_0810130244_texture.glb` | `b811fdb8` | 4,945 | 4,112 | 3 (11.90 MB) |
| `..._Green_Cluster_0810132223_generate.glb` | `442af52e` | 4,950 | 7,372 | 0 (0.25 MB) |
| `..._Winter_s_Reach_..._texture - Copie.glb` | `2d260e82` | -- | -- | byte-identical duplicate |

So: **six files, five distinct payloads, four distinct subjects.** `- Copie` is
the same bytes as its sibling (identical md5), and `..._generate` is an
untextured variant of the Green Cluster.

**Subjects verified by offscreen render, never by filename** (§3's rule). The
renders also settle the orientation question: all four are Y-up with the
trunk/base at -Y, i.e. correct as authored, no `model_rotation_degrees` needed.

* `Low_Poly_Tree` -- a leafy deciduous tree. Matches "arbre feuillu".
* `Winter_s_Reach` -- **a bare, leafless winter tree, NOT a conifer.** Its
  bounding box (1.86 x 1.54 x 1.91) is roughly cubic, which is already the
  wrong shape for a conifer; the render confirms it.
* `Low_Poly_Tree_Stump` -- a stump with flared roots. Matches "souche".
* `Green_Cluster` -- a clump of foliage blobs. Matches "buisson".

**There is no rock and no bench.** The procedural `rock` and `bench` kinds
(and `sign`) have no supplied replacement, so this batch could never have been
the wholesale swap the brief describes.

#### Why none of them was installed

Three independent blockers, each measured.

**1. Triangles.** `TrackPropsAudit` on the untouched tree: frame **48,376 tri
against the 50,000 target -- 1,624 of headroom**, with the props family at
**781**. Per-kind census (`TracksidePropCensus`, new in this batch) puts
**12.6 props on screen at once** in steady state, distributed by
`_PROP_KIND_WEIGHTS`. Replacing the three kinds that *do* have a subject, at
the decimator's unaided floor (tree 603, stump 423, bush 256 tri):

| kind | instances | now | as .glb | delta |
|---|---|---|---|---|
| tree | 4.03 | 25 tri | 603 tri | +2,329 |
| bush | 2.27 | 108 tri | 256 tri | +336 |
| stump | 1.76 | 48 tri | 423 tri | +660 |

Props go **781 -> ~3,945 tri (2.6x their 1,500 budget)** and the frame to
**~51,540, over target**. Worst-frame extrapolation from the observed per-kind
maxima reaches ~7,217 tri of props and ~54,800 in frame.

The obvious answer -- reclaim budget from the collectibles, which draw 29,568
tri of the 48,376 (§7.2) -- is **deliberately not taken here**: that fix
changes the silhouette of a visible gameplay object and is already recorded as
needing its own device review.

**2. Payload.** The five distinct `.glb` import to **64.91 MB of `.ctex`**
against a whole shipped `.pck` of **4.23 MB** -- a 15x increase, on a game
whose payload lesson (§7, 2026-08-09) was learned by finding 35.84 MB of dead
weight and cutting it. The single worst offender is a **4096x4096
metallic-roughness map** on every asset, which is the *least* useful map here:
these props are unshaded, and metallic/roughness has no effect on an unlit
material.

**3. Materials.** **Not one of the five declares `KHR_materials_unlit`**
(`extensionsUsed` is absent entirely). All are PBR with baseColor +
metallicRoughness + normal, and `doubleSided`. §8's rule is unlit, and §8.2's
contrast table for these six prop kinds was swept against flat unshaded
albedos -- a textured PBR prop is not a drop-in for a value that was chosen by
measurement.

#### What decimation can and cannot rescue

`scripts/dev/decimate_decor.py` (added this batch) welds then decimates, and
emits a flat unlit texture-free `.glb` carrying the kind's existing §8.2
albedo. **Welding is the load-bearing step**: Meshy builds these as heaps of
separate closed shells, and a quadric decimator cannot collapse across shells,
so the leafy tree floors at 603 tri at any ratio. Rounding positions to
0.6% of the longest bbox edge merges the shells and lets every subject reach
any target.

Rendered at 100 / 150 / 250 tri and read off the images, not predicted:

| subject | at ~150 tri | verdict |
|---|---|---|
| bare tree | branch structure still legible | **best of the four** -- a silhouette the game does not currently have |
| stump | flared roots survive | **better than** the shipping cylinder+dome |
| bush | lumpy mass, reads as a bush | comparable to the shipping 3-blob clump |
| leafy tree | **a featureless blob, trunk nearly gone** | **worse than** the 25-tri cone it would replace |

The leafy tree fails for a structural reason, not a tuning one: its character
is the trunk/canopy separation and the leaf colour, and the pipeline destroys
both -- welding merges the canopy blobs, and decimation **cannot carry UVs**,
so the texture cannot come along at any triangle count. Keeping the texture
would mean not decimating, which is blocker 1.

**Consequently: `bare_tree` and `stump` are installable at ~150 tri and fit the
budget (props ~891 tri mean, frame ~48,486); `tree` and `bush` are not worth
installing** -- one is worse than what it replaces, the other is a lateral move
for +40 tri an instance.

#### Left for a decision, not guessed at

Installing the two viable subjects still commits three things this batch had no
mandate to decide: dropping textures as the decor art direction; whether
`bare_tree` replaces `tree` or becomes a seventh kind (which changes the mix
`_PROP_KIND_WEIGHTS` produces, and therefore the decor background the F10/F11
contrast probes measure); and whether a roadside mixing `.glb` stumps with
procedural rocks, benches and signs is acceptable while the latter three have
no supplied asset.

### 2026-08-10 -- bare tree and stump, INSTALLED (the recon's two viable subjects)

Acts on the three decisions the recon above left open, all taken by Mathieu:
install **only** `bare_tree` and `stump`; drop textures as the decor art
direction; and make `bare_tree` a **REPLACEMENT for the `tree` kind**, not a
seventh kind. The leafy tree and the bush are still not installed, for the
reasons the recon measured.

**What was produced.** `scripts/dev/decimate_decor.py 150`, on those two
subjects only:

| subject | source | welded | installed | file | installed as |
|---|---|---|---|---|---|
| bare tree | 4,486 tri, 18.14 MB PNG | 4,455 | **146 tri** | 3.9 KB | `assets/models/keepy_bare_tree_prop.glb` |
| stump | 4,130 tri, 14.37 MB PNG | 3,889 | **150 tri** | 3.7 KB | `assets/models/keepy_stump_prop.glb` |

**Two defects in the decimator, found by verifying its output rather than
reading it.** Both are fixed in this batch:

- **JSON chunk padded with `0x00`.** glTF 2.0 requires the JSON chunk to be
  padded with **spaces**, and only the BIN chunk with zeros, because the
  padding is part of the text handed to the parser. Validity therefore
  depended on JSON length modulo 4: `stump` happened to land aligned and
  parsed, `bare_tree` did not and raised `Extra data`.
- **`baseColorFactor` written in sRGB.** It is a **LINEAR** field. See the
  second callout in 8.3 for what this did and why the surface override hid
  it.

**Orientation -- measured on these meshes, not taken from the recon.** The
bounding box alone cannot settle it for the bare tree, which is near-cubic
(1.352 x 1.333 x 1.540 after decimation). Sliced the vertices into ten bands
along each axis and measured the cross-sectional spread of each band:

    bare_tree, along Y : 0.22 0.00 0.00 0.77 1.55 1.98 1.90 1.42 0.89 0.24
    stump,     along Y : 2.71 1.77 1.91 1.62 1.21 1.31 0.00 0.00 0.00 1.61

A thin stem at the bottom opening into a wide crown and tapering at the tips
is a tree standing on Y; neither X nor Z shows a stem. The stump is widest at
its base (flared roots) and closes on a cut face. **Both are Y-up with the
base at -Y**, so no `model_rotation_degrees` is needed -- which is what the
recon said, now independently confirmed.

#### Not a ModelSlot install, and section 2 does not describe it

A `ModelSlot` addresses ONE fixed node by name. These are a recycled pool of
interchangeable instances that no gameplay code points at, so there is no
node to address -- the same reason `Decor.gd`'s billboards sit outside that
path. §2 stays written for slots; this is the second deviation from it, and
the first for a `.glb`.

The mesh is loaded **once** and shared by every instance in every segment,
read off the imported `PackedScene`'s `SceneState` so **no node is ever
instantiated or freed**. Instantiating worked too, but freeing a
`MeshInstance3D` under the headless dummy renderer prints `Parameter "m" is
null` on stderr -- harmless in itself, and fatal to a project that compares
probe output byte for byte. Pooling is unchanged: instances are built in
`_ready()` and thereafter only toggled, repositioned and scaled, and a `.glb`
is resized by scaling its instance rather than by rewriting the mesh, so the
shared resource is never mutated.

**Keep-out is measured, not assumed.** Yaw is free, so the clearance uses the
bounding circle about the instance origin over the scaled AABB's four
horizontal corners -- the same bound, and the same reasoning, as the rock's
longest semi-axis. An imported AABB is **not** centred on its origin the way
a primitive's is, so the ground contact subtracts the box's own minimum Y
rather than half its height. `TrackPropsAudit`'s keep-out phase asserts the
result over 4,000 rolls and passes.

#### The mix is untouched, and that was verified rather than argued

`_PROP_KINDS` and `_PROP_KIND_WEIGHTS` are **byte-identical** to
`origin/main`. Beyond that, `_place_model` draws **exactly the five values
from `_prop_rng`** that both placements it replaced drew (the tree: trunk
radius, trunk height, canopy radius, canopy height, spread; the stump:
radius, height, dome rise, spread, yaw) -- on **every** path, including the
one where the model fails to load, so a missing file cannot re-sequence the
decor either.

Verified with the decor streams seeded (`DecorRng.force_seed`), by dumping
every prop whose node name exists on both trees and diffing:

> **All five visible rocks, benches, signs and bush blobs land at a
> BYTE-IDENTICAL segment-local position, scale and rotation** against
> `origin/main`.

(The first attempt compared *global* positions and showed all five differing
in Z by the same constant ~3.8698 while X, scale and rotation matched
exactly. That is world scroll at the sampling instant, not a decor
difference -- a stream divergence perturbs X, scale and rotation
independently and cannot produce one shared offset across props in different
tiles. Re-measured in segment-local space, which is what `_place_*` actually
writes, the diff is empty.)

So the change is: two silhouettes, at the same tiles, the same Z, the same
side, the same count. Only their X shifts, by the difference between the new
bounding circle and the old canopy radius.

#### Triangle budget -- the frame is fine, the props' own sub-budget is not

Per-kind, from `TracksidePropCensus` (3,600 frames):

| kind | tri/instance | mean on screen | mean tri | max tri |
|---|---|---|---|---|
| tree | **146** (was 25) | 5.03 | 734.3 | 876 |
| stump | **150** (was 48) | 2.79 | 418.2 | 450 |
| bush | 108 | 1.28 | 138.2 | 324 |
| rock | 48 | 1.43 | 68.7 | 192 |
| bench | 44 | 1.10 | 48.3 | 132 |
| sign | 22 | 0.93 | 20.5 | 22 |
| | | **12.56 props** | **1,428.2** | |

`TrackPropsAudit` worst frame, **six runs each side**. **This probe is NOT
seeded** (`--seed=` is inert in it), so single runs are not budget figures
and only ranges mean anything:

| | props, worst frame | frame total |
|---|---|---|
| `origin/main` | 459 - 868 | 45,567 - 56,570 |
| this branch | 908 - 1,926 | 46,825 - 58,143 |

- **Frame total: not meaningfully moved.** The props add ~700-1,000
  triangles; run-to-run noise on this probe is ~±6,000. The two ranges
  overlap, and **both straddle the 50,000 target** -- the baseline reaches
  56,570 on its own. That the frame is already over target is pre-existing
  and dominated by the collectibles (§7.2), not by this batch.
- **Props: 1,500 budget exceeded on 2 of 6 runs (worst 1,926).** The six:
  908 / 1,348 / **1,532** / **1,926** / 1,392 / 1,380.

**The props budget was NOT raised to make this pass**, and `TrackPropsAudit`
is left FAILING on the runs where it exceeds. Moving a threshold to fit a
measurement is the faux-vert this repo has recorded five times. What the
number means is worth stating, though, because the probe's own header says
it: 1,500 was *"sized about 3x the measured peak"* of the all-primitives era,
and its stated purpose is *"to catch the mistake that actually happens here
-- a primitive left at Godot's default tessellation, which is ~4,000
triangles for a single boulder"*. It is a **defect detector calibrated to
primitives**, and the same header explains that the whole-frame total is
deliberately *reported* rather than asserted because that is the number the
budget is really about.

**Three ways out, none of them taken here -- this is Mathieu's call:**

1. **Re-decimate the two to ~100 tri.** Mean props would fall to ~1,060 and
   the worst frame under 1,500. Cost: the 150-tri LOD is the one the recon
   judged by rendering and the one that was approved; 100 was rendered but
   never judged for these two subjects. A quality decision, not a tuning one.
2. **Re-scope the props budget to the imported-mesh era** (~2,500 keeps the
   3x-of-peak logic and still catches a 4,000-triangle default-tessellation
   boulder on the first draw). Defensible on the probe's own stated purpose,
   but it is a threshold move and must be argued as one, in its own batch.
3. **Reclaim the collectibles' 16,896 triangles** (§7.2 — two `SphereMesh`
   at Godot's default tessellation, 4,224 each, against 300 budgeted). By far
   the largest win available and it would put the *frame* comfortably under
   target, but it changes the silhouette of a visible gameplay object and
   already carries its own device-review requirement.

#### Validation

Godot 4.3.stable headless, editor and `4.3-stable` templates fetched into the
sandbox, `--fixed-fps 60` before `--path` and before `--` per §11's
reproducibility note.

- **`AssetContractAudit`: PASSED.** 12/12 visuals swap, **0/10 colliders
  moved**, pursuer still has none.
- **`DecorStabilityAudit`: PASSED.** 5 recycle events, **0 while clearly
  visible** — the billboard lot has not regressed.
- **`TrackPropsAudit`** keep-out and collider phases: PASSED. Exactly one
  shape on the segment body (the slab). Budget phase as above.
- **`TracksidePropCensus`** needed fixing before it could report at all: it
  keys kinds to prop node-name prefixes, and the renamed nodes made it report
  both kinds at **zero instances with a `-1-0` per-instance cost**. That is
  how a stale prefix there fails — quietly, and looking like a measurement.
- **`ProbeTimeoutAudit`: PASSED** (32 probe scenes bounded) — required after
  touching anything under `scripts/dev/`.
- **All NINE gated probes, seed 20260806, `origin/main` vs this branch:
  BYTE-IDENTICAL stdout and same exit code** — `AntiFrustrationAudit`,
  `ComboAudit`, `PursuerAudit`, `RushFrustrationAudit`, `ShrinkAudit`,
  `StrikeAudit`, `PursuerFramingAudit`, `ChargerShapeProbe`,
  `DeathModelAudit`. Eight PASS; `StrikeAudit` exits 1 on **both** trees,
  which is the pre-existing F13 red (capture-share gap 15 points against the
  20 required) and not something this batch moved. Expected for
  a decor-only change, and worth having as evidence rather than inference:
  the decor streams are separate `RandomNumberGenerator`s from the global one
  the gameplay rolls draw on, and this batch adds no `DecorRng.make()` call,
  so stream numbering could not shift. `PursuerFramingAudit` is included and
  does not move — unlike the hibou swap, which legitimately changed its
  occupancy figures, nothing here is inside the pursuer's `visual_aabb()`.
- **`index.wasm` md5 identical** between the two trees, as it must be for a
  change that touches no engine feature.
- **Scale does not compound across recycles.** `_place_model` computes
  `scale_y` as `height / instance.get_aabb().size.y`, which is only correct
  if `get_aabb()` excludes the node's own scale — otherwise every
  re-placement would divide by an already-scaled box and props would grow
  without bound. `nearest_prop_edge_x()` implies local (it multiplies by the
  transform afterwards), but implication is not measurement. Measured
  directly, no game scene involved: `get_aabb().size` reads
  `(1.352013, 1.333252, 1.540203)` at node scale 1.0, **3.0 and 7.0 alike**,
  and `transform * get_aabb()` at scale 7 gives exactly 7x that. Local, so
  no compounding.
- **Web export**: clean, exit 0. `index.pck` **4,723,040 -> 4,736,160 bytes,
  +13,120** for both assets, built from a throwaway worktree at `origin/main`
  against the current tree with identical templates.
- **Deployed to staging and fingerprinted.** CI run `31411751966` on
  `staging` (`9247dda`) is green — export step clean, the production step
  correctly **skipped**, the staging step successful, and
  `keepy-staging.vercel.app` re-aliased to
  `keepy-8qh59xph4-rajonrondoadkhey2095s-projects.vercel.app`. The CI's own
  "Verify export output" step reports `index.pck` **4,736,160**, `index.js`
  **331,495**, `index.wasm` **35,376,909** — byte-for-byte the sizes of the
  local export above, so the artefact serving staging is the one that was
  measured here. (The staging alias itself cannot be fetched from a sandbox:
  it is behind Vercel Deployment Protection and answers 302 to
  `vercel.com/sso-api`, so the CI log is the authoritative fingerprint.)

**`index.pck` is NOT byte-size-stable across repeat exports of the identical
tree — found while re-verifying this batch after a container restart, worth
knowing before ever using pck size as a determinism check again.** Three
back-to-back local `--export-release "Web"` runs against the exact same
commit produced three different `index.pck` sizes (4,736,128 / 4,761,392 /
4,761,376 bytes, a ~25 KB band), while `index.wasm` and `index.js` were
**byte-for-byte identical (matching md5) on every run**. CI's own build of
the SAME commit reported a fourth value, `4,736,144`. The two new assets
carry no texture, so none of this variance can come from them — it is
Godot's VRAM texture compression pass (mentioned earlier in this section,
"re-encodes the JPEG/PNG maps into a smaller GPU-native format") acting on
the OTHER textured assets in the project (hibou, squirrel), and that
encoder is not bit-for-bit deterministic run to run. **Consequence for any
future verification**: `index.pck` byte count is not a valid identity
check by itself. `index.wasm`/`index.js` identity (proves no engine/script
change), the gated-probe byte-identical sweep (proves no gameplay change),
and CI's OWN reported size for the build actually served (proves the
artefact matches what was measured, not that repeat exports agree with
each other) are what this batch relied on instead — and that is what
should be relied on again.

### 2026-08-10, later the same day -- merged to production, explicit authorisation

Mathieu authorised the `staging` -> `main` merge after device validation on
`keepy-staging.vercel.app` (two iPhone captures: bare trees and stumps
legible at play speed; dark-mode/fog not exercised by those captures, but
the general render was judged good). `staging` was confirmed at exactly the
expected head (`762e83f`, nothing newer had landed) before merging.

Merge commit `7d0c791` on `main`. Re-validated post-merge rather than
assumed carried over: `AssetContractAudit` re-run on the merge commit
itself (12/12 visuals, 0/10 colliders moved) to catch a merge that silently
resolved wrong, which a clean `--no-ff` of a fast-forward-able history
would not by itself rule out.

CI run `31416689552` on `main`: green, `[PRODUCTION -- main]` deployed,
`[STAGING -- staging]` correctly skipped (push was to `main`, not
`staging`). `▲ Aliased https://keepy-ten.vercel.app` in the deploy log.
**Fingerprint verified against the LIVE site, not just the CI log this
time** — `keepy-ten.vercel.app` has no Deployment Protection (unlike
staging), so it was fetched directly: its embedded `GODOT_CONFIG.fileSizes
.index.pck` reads **4,736,144**, matching CI's own "Verify export output"
step for this exact run to the byte, with an `etag`/`last-modified` dated
~24s after the deploy log's own timestamp. Two independent readings of the
same deployed artefact agree; see the non-determinism note above for why
this specific number does NOT need to match any of this session's earlier
local exports.

Known and accepted before this merge, not reopened by it — the props
sub-budget overage and the F10/F11 sandbox-inconclusive result both
carried forward unchanged, per Mathieu's explicit brief for this merge.

**`PursuerContrastAudit` and `StrikeFatalContrastAudit` (F10/F11) are
INCONCLUSIVE in this sandbox** — both hit the `ProbeWatchdog`'s 900s
wall-clock budget and exit 2 without reaching their completion check. Same
limitation the F14 lot recorded one day earlier in the same environment
(no GPU, `llvmpipe` under `xvfb`; these two are the only probes here that
capture rendered frames in bulk). Not a defect and not a regression:
`PursuerContrastAudit` reached **51,171s of simulated time in 900s of wall
clock**, i.e. ~57x real time, which is proof `--fixed-fps 60` was honoured
and that the probe was progressing, not stuck. Its own timeout hint about
flag order is generic boilerplate and does not apply — the flags were in
the documented order.

**Why the mix argument still leaves F11 open, stated rather than assumed:**

- **F10 is not reachable by this batch.** It measures the pursuer's
  silhouette against the **ground**. The pursuer is untouched; the ground's
  tint comes from `_tint_rng`, a *different* `DecorRng` stream, and this
  batch adds no `DecorRng.make()` call, so stream numbering — and therefore
  `_tint_rng`'s seed and sequence — is unchanged. Props cannot reach the
  sampled surface either: the keep-out puts every prop's silhouette edge at
  `|x| >= 3.4` against a 6m slab, asserted over 4,000 rolls by
  `TrackPropsAudit`, which passes. Note also that F10 was **already failing
  on untouched `origin/main`** (6/6 dark palettes, worst 1.86:1), so a red
  result from it is not attributable to this batch in either direction.
- **F11 is narrowed but NOT ruled out, and it would be dishonest to claim
  otherwise.** It samples the fatal-strike label against **the 3D world
  behind it**, and two prop kinds changed silhouette and shifted slightly in
  X. What bounds it: no prop changed tile, Z, side or count, and X moved
  only by the difference between the new bounding circle and the old canopy
  radius. What does *not* bound it: nothing in the geometry proves no tree
  or stump ever lands behind that label. The failure mode that flipped F11's
  verdict **twice before** — a HUD layout shift moving the label onto a
  different patch of world — is structurally impossible here, since no HUD
  node is touched; the 3D-background channel is a narrower one, but it is
  real. **Measure it on a machine that can finish the probe before reading
  anything into a verdict**, and note that the DARK/5 tint decision was
  already open and is Mathieu's.

### 2026-08-11 — JUMP (mossy log), INSTALLED — the first hazard asset

`assets/models/keepy_jump_log.glb`, on `Obstacle/JumpMesh`. **150 triangles,
3.7 KB, flat, unlit, untextured**, carrying the authored JUMP amber. Lands on
top of the same day's alarm-ramp repair (see the entry above), which had to
come first: any `.glb` on a hazard slot was silently deleting the ENEMY
telegraph before it.

**Which file it is was measured, not read off the name.** The batch shipped
two trunk/log subjects and the brief named neither unambiguously:

| file | bbox | verdict |
|---|---|---|
| `Meshy_AI_Low_Poly_Log_…` | 1.901 x **0.534** x 0.608 | long in X, flat in Y → **lies down → JUMP** |
| `Meshy_AI_Crimson_Hollow_Trunk_…` | 1.031 x **1.901** x 0.992 | long in Y → **stands up → DODGE**, not this |

Confirmed by rendering from three axes: round cross-section on the side view,
**moss on the +Y face** from above, axis already across the track.
`model_rotation_degrees` stays zero — a log lying across the lane has no
meaningful "front", so §3's +Z rule is satisfied by "long axis across X, moss
up", which is what was actually checked.

**Two of the batch's stated premises were wrong**, both measured before any
code was written:

| claim | measured |
|---|---|
| "capped at 1,200 triangles" | the six arrive at **4,000–5,258**; this one 4,555 (3.8x its budget) |
| implied ready to install | **none of the six declares `KHR_materials_unlit`**; all PBR, each with a 4096x4096 metallic-roughness map — the one map an unlit material cannot use |

Third batch running where the announced description and the measurement
disagree. Measure first, always.

**`scripts/dev/decimate_hazard.py`** closes both. It **imports**
`decimate_decor.py`'s glTF pipeline rather than copying it — one reader, one
writer, one hard-won chunk-padding rule (JSON padded with spaces, BIN with
zeros). `decimate_decor.py` is deliberately **not** renamed: §11's decor entry
references it by name and its name is still true of what it does.

**Losing the texture costs a hazard nothing it was allowed to keep.** For a
decor prop that was an art-direction decision; here it is a *requirement*. §8
gates hazard albedo against the ground at 3.0:1 and nothing post-processes the
frame, so a textured, lit, Meshy-authored log could not have a known contrast
ratio at all. Flat + unlit is the only state a hazard is permitted in — which
is why the leafy decor tree remains uninstallable while this one is not merely
installable but *improved* by the same operation.

**LOD 150 chosen ON RENDER**, not prediction. Its outline is indistinguishable
from 800's, and for an unlit flat asset triangles buy **silhouette only** —
there is no shading to reveal interior geometry, so anything past the outline's
needs is pure frame cost. Drawn material verified `UNSHADED
albedo=(1.0000, 0.7800, 0.2800)`, an exact round-trip of `Obstacle.tscn`'s
`StandardMaterial3D_Jump` through sRGB→linear→sRGB.

**Scale 0.63483 fits X to the collider's 1.20 exactly**, and that is a fairness
choice, not an aesthetic one: §4 warns that a visual wider than its hitbox makes
a legal dodge look illegal. The asset is far more slender than the box it
replaces, so at that scale it **under-fills the hitbox** — 0.331 vs 0.700 in Y,
0.379 vs 1.000 in Z. **No uniform scale can fix this**: filling Y needs s=1.343,
which puts X at 2.538, past the ~1.9 lane-bleed threshold *and* twice the hitbox
width. Reported rather than papered over. Consequence to judge on device: ~0.37 m
of hitbox sits above the visible log and ~0.31 m ahead of it. The Y gap is
heavily mitigated by the jump arc clearing 1.558 m; the Z gap means a contact can
register slightly before the log looks reached.

**`ModelSlot.model_offset` is new**, third of the same family as `model_scale`
and `model_rotation_degrees`. The log's own origin is its middle, so at the
slot's authored `y = +0.35` it hovered 18.5 cm. Moving the **slot** instead
would have been the smaller diff and would have silently broken the fallback: a
0.7-tall placeholder box centred on a lowered node sinks through the ground, so
"leave `model_scene` null and this file does nothing at all" would stop being
true in the state nobody looks at.

**Colliders untouched** — `JumpShape` still `Box(1.2, 0.7, 1.0)` at +0.350,
`AssetContractAudit` 12/12 visuals swapped, 0 colliders moved. That probe's
PHASE 1 table now marks **`[glb]` vs `[-- ]`** per row: its header said
"placeholder meshes", which stopped being true for the first time here, and a
table that cannot distinguish an installed asset from the primitive it replaced
is exactly the quietly-wrong output `scripts/dev/` exists to prevent. It
immediately makes visible that **three** slots now carry assets: Keepy,
`JumpMesh`, and the pursuer's `Silhouette`.

#### ⚠️ `DarkPaletteAudit` reads JUMP 3.28 → 3.02:1, and the colour did NOT change

Still above the 3.0 floor, but the margin looks collapsed. **It is a measurement
artifact, proved rather than argued**, and the contrast contract is intact.

The pixel histogram of the probe's own 29x29 sample window:

    783 px  (251,196,70)   <- pure amber, byte-identical to the placeholder's
     54 px  (54,125,26)    <- ground
      4 px  near-ground

Solving `observed = (1-f)·jump + f·ground` independently per channel gives
**f = 0.0704 (R), 0.0686 (G), 0.0680 (B)** — three channels agreeing on a single
blend fraction with the ground, which a colour change cannot produce. **The log
renders at exactly the authored amber**; the sample is 93% log, 7% ground.

Cause: the log's silhouette is far thinner than the box's, so the fixed-size
window centred on the object's **AABB centre** now clips its lower edge. Note
that the AABB's projected size (**149.8 x 59.0 px**) *overstates* the silhouette
at the centre column, because an angled camera makes a thin box's screen extent
span top-back to bottom-front corner.

**This is an F10-family probe defect and is left for its own batch.** A
shape-aware clamp was written, **measured not to bind** (the window already fits
inside 59 px, so it changed nothing), and **reverted rather than kept as a fix
that fixes nothing**. Tuning the inset constant until this one asset's number
came out right would be exactly the false-green `ProbeCoverage.gd` documents five
times. Every other hazard and both collectibles are byte-identical, since the
defect only reaches objects thinner than the window.

#### Validation

`AssetContractAudit`, `AlarmRampAudit`, `ProbeTimeoutAudit`, `DeathModelAudit`,
`ChargerShapeProbe`, `PursuerFramingAudit` — all **exit 0**. `DarkPaletteAudit`
exit 0.

Import + `--export-release "Web"` both **exit 0**.

**The payload trap held**: the 166 MB of raw sources in
`assets_source/ennemis/` did **not** ship — **0** imported ennemis entries in
the pack, only uid-cache path strings, exactly as the decor batch already
leaves.

#### Still open, and deliberately not decided here

- **The four remaining subjects** — toad (STOMPER), dragonfly (AIR_ENEMY),
  beaver (ENEMY), boar (CHARGER) — measured and rendered, **not installed**. The
  upright trunk is DODGE's, also not installed. Each needs the same decimation
  pass and its own scale/offset judgement against §4. Note §7.4's inversion:
  ENEMY and AIR_ENEMY imports should *reduce* triangles, not add.
- **The hitbox under-fill above.** Device call: does the log read as something
  to jump, and does the invisible hitbox above and ahead of it ever feel unfair?
- **The alarm telegraph on an imported asset is carried by ALBEDO alone**, since
  emission is inert on an unshaded material (see the alarm-ramp entry above).
  Nothing to judge yet — no ENEMY/AIR_ENEMY asset is installed, and the
  placeholders still get the full albedo+emission ramp. Revisit when one is.

### 2026-08-11, later the same day — STOMPER (toad), INSTALLED

`assets/models/keepy_stomper_toad.glb` on `Obstacle/StomperMesh` — **148
triangles, 3.7 KB, flat, unlit, untextured**, carrying STOMPER's existing
ice-blue. Second hazard asset, same pipeline as the JUMP log.

#### Identified by rendering, not by name — and the name would have been right

`Meshy_AI_Geometric_Toad` *is* the toad, but that was established the way
§11 has had to establish everything in this batch: all five remaining files
rendered from three axes. The batch has already produced one genuinely
ambiguous pair (`Low_Poly_Log` vs `Crimson_Hollow_Trunk`, both "trunk"),
so a name that happens to be accurate is still not evidence.

The measurement is also what makes it the STOMPER rather than any other
hazard. It is the **only crouching subject** in the batch:

| file | bbox (X × Y × Z) | posture | hazard |
|---|---|---|---|
| **Geometric_Toad** | **1.898 × 0.703 × 1.672** | **crouched, splayed limbs** | **STOMPER** |
| Emerald_Geometric_Dra (dragonfly) | 1.901 × 0.960 × 0.170 | flat, wings spread | AIR_ENEMY |
| Low_Poly_Beaver (reads as a rat) | 1.299 × 1.050 × 1.899 | quadruped, long curled tail | ENEMY |
| Shadowtusk (boar) | 0.831 × 1.128 × 1.903 | quadruped, tusks, standing | CHARGER |
| Crimson_Hollow_Trunk | 1.031 × 1.901 × 0.992 | upright | DODGE |

**Orientation needed no correction, and that was verified rather than
inherited from the JUMP log.** Rendered from +Z and from −Z: the +Z view
carries the mouth line and the eye bumps, the −Z view is the smooth rump.
Segments spawn at −Z and travel toward the camera at +Z, so the toad
already faces the player at `model_rotation_degrees = 0`.

#### Scale: deliberately NOT the JUMP rule, and the ratio was never at risk

**The width-to-height ratio is scale-INVARIANT**, because `model_scale` is
a single uniform float. The brief's concern — that matching the collider
might break the 2.1:1 contract — cannot occur: the asset fixes the ratio at
**2.692:1**, *squatter* than the placeholder cylinder's 2.143:1, at every
possible scale. The "hop over me, I am not a wall" read is preserved and
slightly strengthened. What the scale actually decides is absolute size.

Uniform scale can match X, Y or Z — not all three. The toad is intrinsically
flatter than the box (0.371 as tall as wide, against the hitbox's 0.583).
Both candidates, measured:

| | scale | rest (X×Y×Z) | at pulse peak ×1.22 | invisible hitbox above |
|---|---|---|---|---|
| A: width → collider 1.20 | 0.63608 | 1.200 × 0.446 × 1.076 | 1.464 × 0.544 × 1.313 | 0.254 |
| **B: width → placeholder base 1.50** | **0.79510** | **1.500 × 0.557 × 1.345** | **1.830 × 0.680 × 1.641** | **0.143** |

**B was chosen.** The JUMP log took A because §4 says a visual wider than
its hitbox makes a legal sidestep look illegal — but **a STOMPER has no
sidestep to misread**: it glues itself to the player's lane by design
(`blocks_lane_switch`, `_process_stomper`). Applying that rule mechanically
here would shrink a telegraph `TELEGRAPH-STOMPER` calls load-bearing by 20%
in width and 36% in height, and would make the one axis that *does* bind —
vertical clearance, since the hazard is jumped — measurably worse.

Two properties of B that A does not have, both measured on the built scene:
its rest width **1.500 is exactly the placeholder's base diameter** and its
peak width **1.830 is exactly the placeholder's peak**, so lateral on-screen
presence is unchanged; and at peak it reaches **0.680 against the 0.700
hitbox**, where the placeholder *overshoots* to 0.854.

**Residuals, stated rather than smoothed over:** 0.143 of hitbox sits above
the visible toad, and the visual is 0.345 deeper than the hitbox (0.17 at
each end). Depth over-fill is the forgiving direction for a jumped hazard —
it looks like it needs more clearance than it does. Lane bleed was checked,
not assumed: at peak the toad's half-width is 0.915 against an adjacent-lane
Keepy edge at 1.500. **Device call, as with the JUMP log.**

**The pulse sinks the toad 0.077 below the ground plane at peak — and the
placeholder does exactly the same.** `_process_stomper` scales the SLOT, and
both meshes bottom out at the same slot-local −0.35, so the dip is
identical. Not a new artefact.

#### ⚠️ `DarkPaletteAudit` reads 3.43 → 3.41 on one line, and the gated number did not move at all

Same family as the JUMP log's 3.28 → 3.02, and checked the same way rather
than assumed to be the same thing. Full-output diff against `f4b3190` in a
separate worktree: **exactly one line differs in the entire probe**, the
deep-mist STOMPER sample.

Histogram of the real sample window, taken by instrumenting the probe
itself (reverted afterwards):

| phase | baseline (cylinder) | after (toad) |
|---|---|---|
| shallow | 196 px, **all** `(156,216,251)` → 3.41:1 | 196 px, **all** `(156,216,251)` → 3.41:1 |
| deep | 196 px, **all** `(155,215,250)` → 3.43:1 | 110 px `(155,215,250)` + 43 `(155,214,249)` + 43 `(155,214,250)` → 3.41:1 |

**This is NOT the JUMP artefact.** That one had 54 px of *ground* bleeding
into a window centred on a thinner silhouette. Here the window is **100%
stomper pixels in both trees, zero ground pixels**, and the dominant value
is **bit-identical to the placeholder's**. 86 of 196 sampled pixels sit one
8-bit step lower in G and/or B — a curved unlit surface at slightly
different depth under the scene's exponential fog, not a colour change. The
material was independently confirmed on the built scene as `UNSHADED
albedo=(0.6200, 0.8600, 1.0000)`, an exact round-trip of
`StandardMaterial3D_Stomper`.

**And the number the probe gates is the worst across both mist ends, which
is 3.41:1 before and after** — unchanged, 0.41 above the 3.0 floor, still
the widest margin of the four gated hazards. Only the better of the two
ends moved. The sample centre shifted 9 px down (the toad's AABB centre is
lower than the cylinder's), which is the whole mechanism.

#### Validation

`AssetContractAudit` (12/12 visuals, **0 colliders moved**, `StomperShape`
still `Box(1.2, 0.7, 1.0)` @ +0.350), `DarkPaletteAudit`, `AlarmRampAudit`,
`ProbeTimeoutAudit` (33 probes armed), `DeathModelAudit`,
`ChargerShapeProbe`, `PursuerFramingAudit` (26.9% max, under the 30% gate)
— all **exit 0**. Import and `--export-release "Web"` both **exit 0**.

`AssetContractAudit`'s PHASE 1 table now shows **four** slots carrying a
real asset — Keepy, `JumpMesh`, `StomperMesh`, `pursuer/Silhouette`:
`obstacle/StomperMesh [glb] size 1.500 × 0.557 × 1.345 node_y +0.350
unshaded rgb(0.62, 0.86, 1.00)`.

**The payload trap held**: **0** imported `assets_source` entries in the
pack, only uid-cache path strings. `index.pck` 4,749,024 — which is *not*
offered as proof of anything, per the stability caveat recorded above.

#### Still open

- **Four subjects remain uninstalled** — dragonfly (AIR_ENEMY), rat (ENEMY),
  boar (CHARGER), upright trunk (DODGE). §7.4's inversion still applies, and
  is now confirmed on a second variant.
- **The hitbox under-fill and the depth over-fill.** Device call: does the
  toad read as something to hop, and does the pulse still read as a threat
  ramp at its new proportions?

### 2026-08-11, third of the day — DODGE (upright trunk), INSTALLED

`assets/models/keepy_dodge_trunk.glb` on `Obstacle/DodgeMesh` — **150
triangles, 3.7 KB, flat, unlit, untextured**. Third hazard asset, same
pipeline as the JUMP log and the STOMPER toad, but the **first one that had
to change a gated colour**, and the reason is structural rather than
aesthetic.

#### Identified by measurement, then confirmed at the render

`Crimson_Hollow_Trunk` is the **only remaining subject whose dominant axis
is Y** (1.031 × 1.901 × 0.992). The other four are long in X or Z — see the
STOMPER entry's posture table above, which this closes. A DODGE is a
full-lane-height wall the player goes *around*, so "stands up" is not a
nice-to-have, it is the entire classification.

Rendered from four views before decimating (side +X, front +Z, back −Z, top
+Y): an upright hollow trunk, broken off at the top, small branch stubs low
on the shaft, ring-shaped cross-section from above. **It has no face and is
very nearly rotationally symmetric about Y**, so unlike the toad there was
no "which way does it look" question to answer — `model_rotation_degrees`
stays at zero because there is no orientation to get wrong, not because the
toad's answer was reused.

Source profile matches the rest of the batch and still contradicts the
original brief: **4,314 triangles**, PBR with three maps, **no
`KHR_materials_unlit`**.

#### The albedo HAD to change, and the number says so

**DODGE was the only one of the four gated hazards still LIT** —
`StandardMaterial3D_Dodge` carried no `shading_mode = 0`, alone among
JUMP/STOMPER/CHARGER. Its measured 3.19:1 was therefore the ratio of an
albedo **multiplied by the scene ambient**, not of the albedo itself.
Section 8 requires an imported asset to be unlit, which removes that
multiplication — so carrying the colour across verbatim, the thing the two
previous assets could safely do, **would not have held the ratio here**:

| albedo | shading | rendered | vs ground |
|---|---|---|---|
| `(0.30, 0.025, 0.025)` | LIT (baseline) | `(0.2157, 0.0588, 0.0157)` | **3.19:1** |
| `(0.30, 0.025, 0.025)` | unlit, carried across | `(0.2954, 0.0289, 0.0263)` *(predicted)* | **2.945:1 — UNDER THE FLOOR** |
| **`(0.21, 0.0175, 0.0175)`** | **unlit, shipped** | **`(0.2039, 0.0197, 0.0000)`** | **3.37:1** |

The solve held the DODGE red hue **exactly** (12:1:1, so only the value
moves, never the tint), against the probe's own measured ground luminance
and a fog fraction of 0.0238 taken off the **already-unlit STOMPER** — the
one asset in the scene whose albedo→rendered mapping needs no lighting
model at all. The model reproduces the baseline to within 0.005 of a ratio
point (predicted 3.194 against the probe's 3.19), which is what earned it
the right to predict the failure above rather than discover it.

#### This is a REAL colour change, not the JUMP window artefact — histogram

The JUMP log moved 3.28 → 3.02 for a *measurement* reason (54 px of ground
bleeding into a window centred on a thinner silhouette). DODGE moves in the
opposite direction and for the opposite reason. Probe instrumented, run on
**both trees**, then reverted:

| tree | window contents | dominant value | ratio |
|---|---|---|---|
| baseline (`origin/staging`, LIT box) | **196 px, 0 ground** | `(55,15,4)` | 3.19:1 |
| this lot (unlit trunk) | **196 px, 0 ground** | `(52,5,0)` | 3.37:1 |

**Both windows are 100% object pixels at both mist ends.** Neither
measurement is contaminated, so the difference between them is the object's
colour and nothing else. The signature is unmistakable: the **green channel
collapses 15 → 5** while red barely moves, which is exactly what removing a
multiplication by an ambient of `(0.42, 0.5, 0.35)` — green-dominant — does
to an albedo whose own green is near zero.

⚠️ One observed detail deliberately **not** explained rather than explained
away: the shipped blue channel reads **exactly 0** where the albedo and the
fog both predict ~5/255, while green at the identical albedo value reads the
predicted 5. No tonemapper is configured (`scenes/Game.tscn` has no
`tonemap_*` key), so that is not the cause. It is left as an open
observation because chasing it changes nothing: one 8-bit step of blue on a
near-black silhouette moves the ratio by **less than 0.01**, and the window
purity above already proves the measurement is of the object.

#### Contrast: the tightest margin of the four becomes the second-widest

| hazard | before | after | margin over the 3.0 floor |
|---|---|---|---|
| **DODGE** | **3.19:1** | **3.37:1** | **+0.37** *(was +0.19, the tightest)* |
| JUMP | 3.02:1 | 3.02:1 | +0.02 |
| CHARGER | 3.20:1 | 3.20:1 | +0.20 |
| STOMPER | 3.41:1 | 3.41:1 | +0.41 |

The gated number is the **worst across both mist ends**: 3.39 shallow /
**3.37 deep**. DODGE was the tightest of the four gated hazards and is now
second only to STOMPER; the tightest is CHARGER at +0.20. The three other
rows are **bit-identical** to baseline, as they must be — nothing else was
touched.

#### Scale: the JUMP rule applied straight, not a derogation

`model_scale = 1.18793` puts the visual's X on the collider's **1.200
exactly** — half-width **0.600, byte-identical to the placeholder box**, so
lateral presence does not move at all. Unlike the STOMPER, this is §4's
fairness rule applied without exception: **a DODGE exists to be dodged
sideways**, so width is the axis that decides whether a legal dodge reads as
legal.

The rejected alternative is recorded because it looks better on paper:

| | scale | rest (X×Y×Z) | X vs hitbox 1.200 |
|---|---|---|---|
| **A: width → collider 1.20** | **1.18793** | **1.200 × 2.253 × 1.111** | **±0.000** |
| B: height → hitbox 2.00 | 1.05210 | 1.085 × 2.000 × 1.044 | **−0.115 — hitbox WIDER than the trunk** |

B matches the hitbox height, but leaves the hitbox 0.058 wider *per side*
than the visual: the player clears the trunk on screen and dies to empty
air. That is the punishing direction of the same error, on the exact
mechanic the hazard is named after. A was chosen.

**Residues, reported rather than hidden**: the trunk stands **0.253 above**
the hitbox top and is **0.111 deeper** than it in Z. Both are the forgiving
direction. The overhang cannot make a legal jump look illegal **because
there is no legal jump over a DODGE** — unjumpable by construction, hitbox
2.0 against a 1.558 jump peak — and the depth over-fill only lets the player
brush the visual edge without being hit, the same sense as the STOMPER's
accepted 0.345.

`model_offset = (0, 0.13542, 0)` rests the trunk on the ground: the mesh is
centred on its own origin, so at the slot's authored `y = +1.00` it would
sink 0.135 below the floor.

#### The placeholder material was changed too, on purpose

`StandardMaterial3D_Dodge` goes `shading_mode = 0` and takes the same new
albedo. It is now the **fallback path only** — the `.glb` draws its own
unlit material — but leaving it lit would have made the placeholder and the
shipped asset differ **on the very axis this lot changes**. That is the
fixture-diverges-from-the-real trap `AlarmRampAudit` exists to close, and
reintroducing it in the same repo that documents it would be indefensible.

#### Triangles

`DodgeMesh` 12 → **150**, +138 per live instance. This is one of the three
variants §7.4 predicted would *cost* triangles on import (the two 12-triangle
boxes and the 8-triangle prism), against STOMPER's −620 and the −2,256 /
−2,896 still waiting on ENEMY and AIR_ENEMY. Family one-of-each **7,870 →
8,008**, still under the 8,400 line.

#### Validation

`AssetContractAudit` (12/12 visuals, **0 colliders moved**, `DodgeShape`
still `Box(1.2, 2.0, 1.0)` @ +1.00), `DarkPaletteAudit`, `AlarmRampAudit`,
`ProbeTimeoutAudit`, `DeathModelAudit`, `ChargerShapeProbe`,
`PursuerFramingAudit` (37.1% max, CAPTURE exempt by design) — all **exit
0**. Import and `--export-release "Web"` both **exit 0**.

**The payload trap held**: **0** imported `assets_source` resources in the
pack (58 bare uid-cache path strings, no derived `.scn`/`.ctex`).
`index.pck` 4,755,104 — again *not* offered as proof of anything, per the
stability caveat recorded above.

#### Still open

- **Three subjects remain uninstalled** — dragonfly (AIR_ENEMY), rat
  (ENEMY), boar (CHARGER). §7.4's inversion is still unexercised on the two
  variants where it pays most.
- **The overhang and the depth over-fill.** Device call: does the trunk read
  as a wall to go *around* rather than something to jump, and does the
  invisible 0.25 of hitbox below its top ever feel wrong?
- **The darker red.** No probe says a colour is *right*. DODGE is now a
  darker silhouette than it was; whether it still reads as red rather than
  black on a phone screen at speed is Mathieu's call, not a measurement.

### 2026-08-12 — ENEMY (rat), INSTALLED — the telegraph's first real asset

`assets/models/keepy_enemy_rat.glb` on `Obstacle/EnemyMesh` — **148
triangles, 3.7 KB, flat, unlit, untextured**. Fourth hazard asset, same
pipeline as the three before it, and the first to land on a slot whose
material is **animated by gameplay** (§2.1): the ENEMY approach telegraph.

#### The name says beaver, the render says rat

Fourth file in this batch whose name does not survive a render — and the
first where the name is not merely vague but **names the wrong animal**.
`Meshy_AI_Low_Poly_Beaver_...` rendered from four axes is a **rat**:
pointed snout, small round ears, and a long thin curved tail. A beaver's
tail is a flat paddle; nothing on this mesh is.

The assignment does not rest on likeness alone. All three remaining
subjects were rendered in the same pass so it also holds by elimination:

| file | bbox | render | slot |
|---|---|---|---|
| `Low_Poly_Beaver` | 1.299 × 1.050 × 1.899 | rodent, thin curved tail | **ENEMY** |
| `Shadowtusk` | 0.831 × 1.128 × 1.903 | tusked, maned boar | CHARGER |
| `Emerald_Geometric_Dra` | 1.901 × 0.960 × 0.170 | insect, almost all wing | AIR_ENEMY |

Only one rodent exists in the batch, so ENEMY had exactly one candidate.

**Facing measured, not inherited from the toad.** Rendered from +Z: snout,
eyes, ears and front paws. From −Z: the rump only, with the tail sweeping
away. Segments spawn at −Z and travel toward the camera at +Z, so the rat
already faces the player and `model_rotation_degrees` stays at **zero**.

Source profile matches the rest of the batch: **4,800 triangles**, PBR with
three maps, **no `KHR_materials_unlit`**. LOD chosen at the render, on
**silhouettes rather than shaded views** — an unlit flat surface draws no
internal shading, so triangles buy outline and nothing else. At 100 the ear
is gone and the snout blunts; at 150 the snout, ear notch and tail all
survive; 250 and 800 add rounding and no new readable feature. At playing
size 150 and 800 are indistinguishable.

#### Losing emission is a REAL change to the telegraph, and it made it stronger

`_apply_enemy_alarm` ramps **albedo and emission** (energy 0.3 →
`ENEMY_ALARM_EMISSION_ENERGY` 1.5). An unshaded material ignores emission
entirely, so on this asset the cue loses a channel and the **albedo carries
it alone**. That is not a caveat to note and move past — it fixes the
direction of the base colour:

- `ENEMY_ALARM_ALBEDO` `(0.95, 0.08, 0.12)` renders unlit at relative
  luminance **0.187**; the ground renders at **0.150**. The two are within
  **1.20:1**, so the alarm cannot be read against the ground at all.
- It can only be read against the **resting** colour, which therefore has
  to sit far from 0.187. Only one direction works: **below** it, and the
  alarm brightens. Above it (a pale purple past luminance 0.55) the ramp
  would be a **darkening**, which is not what an alarm looks like.

Value only, tone held exactly at the shipped `0.52 : 0.08 : 0.72` purple —
same discipline as DODGE, and purple is ENEMY's type identity against every
other gameplay hue. **0.35× → `(0.182, 0.028, 0.252)`**, chosen as the
*shallowest* darkening that clears the §8 floor with real margin rather
than the deepest that clears it at all: further steps down buy margin
nobody asked for and spend hue legibility on a 0.6 m silhouette.

Predicted first, from a two-point fog model calibrated on the **STOMPER**
(the only already-unlit hazard, hence the only one whose albedo→rendered
mapping needs no lighting model), then **measured**. The model reproduced
DODGE's shipped 3.39/3.37 to within 0.02 before being trusted to predict
anything.

#### Measured, both ends of the breath, instrumented probe then reverted

`DarkPaletteAudit` samples ENEMY at `CAPTURE_Z`, close enough that the ramp
has **fully saturated** — its `ENEMY (resting)` label has always been false
and this entry does not repeat it. A temporary instrumentation held the ramp
at t=0 and t=1 and sampled both, on the baseline tree and on this one:

| | rest vs ground | **alarmed** vs ground | telegraph (rest ↔ alarmed) |
|---|---|---|---|
| before — placeholder, LIT + emissive | 1.57 / 1.57 | **1.50 / 1.52** | 2.35 / 2.38 |
| after — rat `.glb`, UNLIT | **3.27 / 3.23** | **1.20 / 1.20** | **3.92 / 3.87** |

Three readings, and only one of them is a loss:

- **The telegraph itself got stronger: 2.35 → 3.92.** Losing the emission
  half did not weaken the cue; the albedo had more room than emission was
  using, and the base colour is what bought it. This is the number that
  actually communicates "danger rising", and it is the one this batch was
  free to move.
- **Resting legibility more than doubles: 1.57 → 3.27**, clearing the 3.0
  floor for the first time in ENEMY's history. A lit purple against an olive
  ground was very nearly invisible at rest.
- **The alarmed red vs the ground drops: 1.50/1.52 → 1.20/1.20.** Cause,
  measured not guessed: with emission at energy 1.5 the placeholder drives
  the red channel to **clip** — the baseline print is literally
  `rendered=(1, 0.2485, 0.1142)`. Unlit removes that overdrive, so the alarm
  red renders at its own albedo value, which is dimmer and therefore closer
  to the ground's luminance.

**Not fixed here, and deliberately.** The alarmed colour is
`ENEMY_ALARM_ALBEDO`, a gameplay telegraph constant **shared with
AIR_ENEMY**. Moving it retunes the telegraph rather than the art, on two
hazards, one of which has no asset yet — §8's own note already parks that
as Mathieu's call. Worth stating plainly: this pair was **never** legible
against the ground (1.50 was as far below the 3.0 floor as 1.20 is), and it
is **ungated** for exactly that reason. What changed is that the resting
state is now the legible one and the alarm is a change *from* it, which is
how an escalating cue is supposed to work.

#### Scale: §4 applied as written, and a capsule is not a box

`model_scale = 0.46266` pins X to the collider's **0.600** width — the JUMP
log's rule, unmodified, for the same mechanic: an ENEMY is escaped by
**switching lanes**, so a visual wider than its hitbox would make a legal
dodge read as illegal. Pinning Y instead (s = 0.68639) would put the visual
**0.290 wider** than the capsule: that error in its punishing direction.

The **ratio is invariant under scale**, as it was for the toad — 1.272:1
before and after — because `model_scale` is a uniform float. That property
is about the *scale*, though, not about the *collider*, and the capsule
adds a constraint a box does not:

> A box has the same half-width at every height. A capsule's **collapses to
> nothing at both ends** — full radius only over `y = 0.30 .. 0.40` — and a
> ground-hugging quadruped is widest exactly where the capsule is narrowest.

Measured per height band, the visual sits **0.063 to 0.178 outside** the
capsule over the bottom 0.15 m (paws and tail, where the capsule is a
tapering tip). Over the whole silhouette it does not: the visual's widest
half-width is **0.304** against the capsule's **0.300** — four millimetres —
and a lane dodge is decided by the widest section, not by the ground band. A
render of the rat overlaid on the placeholder capsule from the same camera
confirms it: the body sits well inside the envelope, only paws and tail
cross the lower edge.

`model_offset = (0, −0.10231, 0)` lands the visual's bottom at world
**y = 0.0000** exactly.

**Residuals, flagged rather than dressed up:**

- **0.228 of hitbox above the visible rat** (visual 0.472 tall, hitbox
  0.700). Forgiving in the *lateral* sense but **adverse for the jump**: an
  ENEMY is jumpable, so a jump that visually clears the rat can still clip.
  Mitigated by construction rather than by hope — the cyan `JumpMarkerMesh`
  floats at `JUMPABLE_OBSTACLE_TOP_HEIGHT`, so the honest clearance height
  is already drawn, independent of the mesh. Smaller than the JUMP log's own
  0.37, which was judged fine on device.
- **0.254 of visual beyond the hitbox in Z.** Forgiving: the player can graze
  the nose or tail without being hit. Same sense as the toad's accepted 0.345.

#### The placeholder material moved too, on purpose

`StandardMaterial3D_Enemy` gains `shading_mode = 0` and the same new albedo.
Leaving it lit and emissive would make the **fallback diverge from the
shipped asset on the exact axis this batch changes** — which is the
fixture-versus-reality gap `AlarmRampAudit` exists to close, rebuilt inside
the very slot that first exposed it. It also aligns ENEMY with the four
hazard placeholders already unshaded; AIR_ENEMY stays lit because no asset
has landed on it.

#### `AlarmRampAudit` now gates the REAL asset (PHASE D)

The whole point of this batch. The ramp fix shipped on 2026-08-11 was proved
against `SubstituteModel.tscn` — a fixture built to *look* like a `.glb`.
Trusting it to speak for a real asset would repeat, at one remove, the exact
mistake that made the fix necessary. **PHASE D runs the same two assertions
on `Obstacle.tscn` as authored**, with no fixture: real bytes, real importer,
real material class (the `StandardMaterial3D` cast in `Obstacle._ready()`
fails silently if that ever changes), real binding route, real per-instance
duplicate.

```
--- PHASE D: Obstacle.tscn AS SHIPPED (real assets, no fixture) ---
  OK   ENEMY as shipped [glb]: all 1 drawn surface(s) reach rgb(0.95, 0.08, 0.12)
  OK   ENEMY as shipped [glb]: resets to its own base rgb(0.18, 0.03, 0.25)
  OK   AIR_ENEMY as shipped [-- ]: all 1 drawn surface(s) reach rgb(0.95, 0.08, 0.12)
  OK   AIR_ENEMY as shipped [-- ]: resets to its own base rgb(0.12, 0.85, 0.22)
```

The `[glb]` / `[-- ]` marker is **read off the slot**, never assumed from the
phase, so the day a slot's asset is added or removed the log says so instead
of quietly degrading into a second copy of PHASE A.

**PHASE A had to change with it.** It got the placeholder for free only while
no enemy slot shipped an asset; the moment one did, "no model installed"
would have become a second reading of the shipped rat under a label saying
otherwise. It now clears `model_scene` explicitly.

#### Validation

`AlarmRampAudit` (**12/12 OK**, PHASE D included), `AssetContractAudit`
(12/12 visuals, **0 colliders moved**, `EnemyShape` still `Capsule(r 0.300,
h 0.700)` @ +0.350), `DarkPaletteAudit` (0 missed samples),
`ProbeTimeoutAudit` (33 probe scenes, all armed), `DeathModelAudit`,
`ChargerShapeProbe`, `PursuerFramingAudit` (INTRO 23.6% / VISIBLE 27.0% /
CAPTURE 37.1%, exempt by design) — all **exit 0**. Import and
`--export-release "Web"` both **exit 0**.

**Diffs against the baseline tree are exactly as small as they should be**,
compared in a separate worktree on `origin/main` rather than assumed:

- `AssetContractAudit`: **one line**, the ENEMY row —
  `[-- ] 0.600 × 0.700 × 0.600 lit rgb(0.52, 0.08, 0.72) +emissive` →
  `[glb] 0.600 × 0.472 × 0.854 unshaded rgb(0.18, 0.03, 0.25)`.
- `DarkPaletteAudit`: **two lines**, the ENEMY row at each end of the breath.
  DODGE 3.39/3.37, JUMP 3.04/3.02, CHARGER 3.20/3.21, STOMPER 3.41/3.41 and
  every barrier/marker line are **byte-identical**.
- `ProbeTimeoutAudit`, `DeathModelAudit`, `ChargerShapeProbe`,
  `PursuerFramingAudit`: **byte-identical on both streams**.

**The payload trap held**: **0** imported `assets_source` resources in the
pack — 58 bare uid-cache path strings, no derived `.scn`/`.ctex`, against
**407 MB** of raw sources on disk. `index.pck` 4,761,792; `index.wasm`
35,376,909 (md5 `af4a8fc2925d992348eb30deeeb54360`). Per the stability
caveat recorded above, the `.pck` figure is **not** offered as proof of
anything on its own.

#### Still open

- **Two subjects remain uninstalled** — dragonfly (AIR_ENEMY), boar
  (CHARGER). AIR_ENEMY is now, alone, 87% of the hazard family's triangles.
- **The 0.228 of hitbox above the rat.** Device call, and specifically a
  *jump* call: does a jump that visually clears the rat ever feel stolen?
- **The alarmed red at 1.20:1.** Not a regression this batch can fix without
  retuning a shared gameplay telegraph. Whether the escalation reads at speed
  on a phone — now carried by albedo alone — is Mathieu's call, not a
  measurement.

### 2026-08-12, second of the day — AIR_ENEMY (dragonfly), INSTALLED

Fifth Meshy hazard, and the first whose LOD was chosen by a criterion other
than triangle count. `assets/models/keepy_air_enemy_dragonfly.glb` on
`Obstacle/AirEnemyMesh` — **998 triangles, 17.7 KB, flat, unlit,
untextured**.

#### Identification: the one file whose name was never the question

`Meshy_AI_Emerald_Geometric_Dra_*` measures **1.901 x 0.960 x 0.170**. Eleven
times wider than it is thick, it is a flat spread-winged insect regardless of
what it is called, and AIR_ENEMY is the only flying hazard in the game — so
unlike the log/trunk pair and the "beaver" that was a rat, there was no
ambiguity to resolve. The three-axis render was run anyway, and confirms:
four wings spread along X, body along Y head-up, and a pierced wing lattice.

Its **thin axis is Z**, which is the axis the camera looks down, so the mesh
presents its full 1.901 x 0.960 spread to the player with no rotation at all.
`model_rotation_degrees` stays at zero because the asset arrives face-on —
not because the previous four answers were reused.

#### The premise this batch was given is false, and that makes the result stronger

The brief warned that the placeholder is a *pierced torus* and that the
replacement must stay open or the player stops understanding what to avoid.
The constraint is right. The baseline it names is not.

**Measured, by rasterising the torus's own projection along the camera axis:
0.00% enclosed open area, zero enclosed regions.** A Godot `TorusMesh` has its
hole on the Y axis; the camera sees it edge-on, and every ray through the
silhouette hits tube somewhere. The placeholder is pierced in **topology** and
solid in **silhouette**.

So the dragonfly does not preserve an openness the hazard had. It **introduces
one the hazard never had**, and the risk of losing it in decimation was real
in a way the brief did not anticipate — because there was nothing to lose,
only something to fail to gain.

#### LOD 1000, not the 150 the other four use

Openness was scored directly: rasterise each candidate's player-facing
silhouette, flood-fill the background from the border, and measure what is
left — background **enclosed by** the mesh. Triangle count says nothing about
this.

| LOD | open area | solid pieces | largest piece |
|---|---|---|---|
| 150 | **0.85%** | **14** | 78.3% |
| 250 | 4.64% | 20 | 82.6% |
| 300 | 3.17% | 25 | 87.5% |
| 400 | 5.64% | 15 | 96.2% |
| 800 | 20.64% | 23 | 98.1% |
| **1000** | **27.61%** | **16** | **99.6%** |
| 1200 | 28.53% | 9 | 99.8% |
| source (4,000) | 30.57% | 3 | 99.9% |

**At 150 the wing membrane does not close, it disintegrates** — which is why
the openness number goes *down* rather than up: the gaps stop being enclosed
because the wing around them is gone. The silhouette breaks into 14 pieces
and reads as floating debris. Every other hazard in this project ships at
~150; this is the first subject for which that answer is measurably wrong,
and the fragmentation column is what distinguishes "closed up" from "fell
apart" — two opposite failures a hole-fraction alone cannot tell apart.

1000 is the knee: 1200 buys 0.9 further points for 200 triangles. It is also
**under 7.1's 1,200-per-hazard cap**, so the lattice costs nothing that had to
be bought from the budget.

**Judged at real on-screen size, not at render resolution.** 75° vertical FOV
over a 1080x1920 viewport gives 1251/d px per metre, so the 1.9 m span is
~120 px at 20 m and ~340 px at closest approach. Re-scored there, LOD 1000
holds 10.9% openness at 120 px and 27.6% at 246 px, against LOD 150's 3.0%
and 0.9%.

#### Triangles: the largest single-instance saving in the project

The placeholder is a `TorusMesh` left at Godot's default 64x32 tessellation —
**4,096 triangles**, the largest primitive anywhere in the scene. The install
is **−3,098 per live instance**, and hazard family one-of-each falls
**4,700 → 1,602** (see 7.4, which records why the earlier −3,946 forecast
overshoots: it assumed a ~150 LOD this subject cannot use).

#### The telegraph: measured before and after, not reasoned by analogy

AIR_ENEMY is the only hazard that was **LIT *and* emissive at energy 1.1**
(ENEMY's emission energy is 0.3). Going unlit deletes a multiplication *and*
an additive term, so the shipped albedo is nowhere near what the player sees.
Measured with a throwaway probe built on `DarkPaletteAudit`'s scene, camera
and sampling, on `origin/staging` in a separate worktree and again after the
install:

| | before (torus, LIT + emissive) | after (dragonfly, unlit) |
|---|---|---|
| slot | `[-- ]` | `[glb]` |
| resting, dominant | `rgb(0.2442, 1.0000, 0.3188)` — lum **0.7315** | `rgb(0.2353, 0.9882, 0.3059)` — lum **0.7113** |
| alarmed, dominant | `rgb(1.0000, 0.2654, 0.1281)` — lum **0.2546** | `rgb(0.9373, 0.0784, 0.1098)` — lum **0.1893** |
| **telegraph rest↔alarm** | **2.57:1** | **3.18:1** |
| hue swing | 116.5° | 106.9° |

**The cue is WIDER after the install, not narrower** — the outcome the brief
treated as the risk. Losing the emission boost darkens the *alarm* far more
(0.2546 → 0.1893) than it darkens the *rest* (0.7315 → 0.7113), because the
resting albedo was solved to reproduce the rendered resting colour rather than
carried over raw. Carried over raw, `(0.12, 0.85, 0.22)` would have rendered
near luminance 0.50 — a third of the resting brightness gone, and the cue
narrowed with it.

Two independent cross-checks fell out of this and are worth recording: the
alarmed dominant lands at luminance **0.1893** against the 0.187 the ENEMY
batch derived for the unlit alarm, and alarm-vs-ground computes **1.20:1**
against the "within 1.20:1" that batch measured. Different session, different
probe, same numbers.

**The ramp direction INVERTS relative to ENEMY, and that is correct.** ENEMY
had to be *darkened* so its alarm could brighten into red, because a dark
rodent sat near the alarm's own luminance. AIR_ENEMY rests at 0.71 against an
alarm at 0.19, so its ramp is a large **darkening** plus a ~107° hue swing —
both channels agreeing, in the one direction available.

#### A sampling artefact this asset creates, and how it was told apart

The mean over `DarkPaletteAudit`'s 14 px sample box is **not** this object's
colour, and it is the first hazard for which that is true. The torus is solid
in projection, so its box was 100% object pixels; a preserved wing lattice
lets the background through and drags the mean toward it — **61% of the box is
object** after the install. Same family as the JUMP log's 3.28 → 3.02 window
contamination, opposite mechanism.

Told apart by histogram rather than argued: the dominant value is reported
alongside the mean above, and it is the dominant that shows the resting colour
barely moved (0.7315 → 0.7113, 2.8%) while the mean appears to fall much
further. `DarkPaletteAudit`'s own AIR_ENEMY line moves **1.08/1.09 → 1.32/1.32**
for the same reason — it is not gated, and it moves *up*.

#### Scale and fit

`model_scale = 0.63173` pins X to the collider's **1.200** width. Section 4
again, and AIR_ENEMY earns it twice: it is escaped by switching lanes, and
once landed it is jumpable, so a visual wider than its hitbox would make a
legal dodge read as illegal.

It reproduces the placeholder's lateral presence **to the millimetre**
(1.20000 against 1.2), **improves** the vertical fill from the torus's 0.350
to 0.606, and **removes** the torus's 0.2 of Z overhang past the 1.0 hitbox —
the install is closer to its own hitbox on all three axes than the primitive
it replaces.

**No `model_offset`.** The mesh arrives centred on its own origin within
**1.7 mm scaled**, measured rather than assumed. A collider centred on the
slot wants a visual centred on the slot, and writing 1.7 mm of measurement
noise into the scene would claim more precision than exists. This is the
first hazard needing no offset at all — the other four are floor-anchored,
this one is centre-anchored because its hitbox is.

#### Probes

`AlarmRampAudit` **PHASE D now reads `[glb]` for AIR_ENEMY** and gates the
ramp on the shipped asset: it reaches `rgb(0.95, 0.08, 0.12)` and resets to
`rgb(0.24, 1.00, 0.31)`, the imported material's own colour. 12/12 OK.
`AssetContractAudit` 12/12 visuals, **0/10 colliders moved**, `AirEnemyShape`
still `Box(1.20000, 1.20000, 1.00000)` at `+2.358`. `DarkPaletteAudit` exit 0,
**0 missed samples**, four gated hazards still above 3.0:1.

**Six slots now carry an asset** — Keepy, `pursuer/Silhouette`, `JumpMesh`,
`DodgeMesh`, `StomperMesh`, `AirEnemyMesh`. The placeholder material moved
with the asset (`shading_mode = 0`, same new albedo) so the fallback cannot
diverge from the shipped asset on the axis this batch changes.

#### Still open

- **CHARGER (boar) is the last uninstalled subject**, and the only variant
  where an import will genuinely add triangles — its placeholder is an
  8-triangle prism.
- **The resting green is now carried by albedo alone.** It reproduces the
  rendered colour to within 2.8% of luminance, but nothing measured here says
  a flat green reads the same as a glowing one in motion on a phone. Device
  call.
- **0.594 of hitbox above and below the visible dragonfly.** The jump arc is
  fixed and tuned to clear the hitbox top, so no legal jump is at risk, but
  whether the airborne hazard's lethal volume reads as larger than it looks
  is a device call.

### 2026-08-12, third of the day — ENEMY (rat), RECOLOURED to a brown-grey

Not an install: the rat has been on `Obstacle/EnemyMesh` since earlier the
same day and its geometry, scale, offset and collider are untouched here.
**Only `baseColorFactor` moves**, plus the placeholder that shadows it.

#### Why

Device feedback on the shipped purple `(0.182, 0.028, 0.252)`: at real speed
it reads as **RED**, not as an animal. That is worse than a merely
unattractive colour — it puts the RESTING state inside the ALARM's own colour
family, and the alarm is the only other state this material has. The
replacement is a warm dark brown-grey, the natural fur register the reference
render was pointing at.

#### The one edit that could not move the telegraph

The direction argument that fixed this value in the first place says nothing
about hue. It is entirely a statement about where the resting **luminance**
sits relative to the alarm's 0.187: below it, so the ramp is a BRIGHTENING.
Hold luminance, and the telegraph is preserved by construction rather than by
luck.

| | authored sRGB | H | S | V | authored rel. luminance |
|---|---|---|---|---|---|
| before | `(0.182, 0.028, 0.252)` | 280° | 0.89 | 0.25 | 0.011186 |
| **after** | **`(0.135, 0.102, 0.076)`** | **26.4°** | **0.44** | **0.135** | **0.011344** |

+1.4% of luminance. Rendered, the fog pulls hue and chroma **UP** rather than
washing them out: H 26.4° → 35.3°, S 0.44 → 0.52.

#### Measured, both ends of the breath, ramp pinned, probe then reverted

`DarkPaletteAudit`'s `ENEMY (resting)` row is mislabelled — at `CAPTURE_Z` the
ramp has fully saturated, so that row measures `ENEMY_ALARM_ALBEDO` and is
**structurally incapable of seeing this change**. A throwaway probe built on
that audit's scene, camera and sampling box pinned the ramp at t=0 and t=1
with the obstacle's own `_physics_process` disabled, on the baseline tree and
on this one:

| | resting rendered | resting vs ground | **telegraph (rest ↔ alarm)** |
|---|---|---|---|
| before (purple) | `(0.1765, 0.0353, 0.2471)` L 0.0111 | 3.27 / 3.23 | **3.92 / 3.87** |
| **after (brown-grey)** | **`(0.1294, 0.1020, 0.0627)`** L 0.0110 | **3.27 / 3.26** | **3.92 / 3.90** |

The telegraph is held exactly at the shallow end and **improves 0.03 at the
deep end**. The alarm rendered `(0.9373, 0.0784, 0.1098)` on both trees, to the
bit — as it must, `ENEMY_ALARM_ALBEDO` being untouched and shared with
AIR_ENEMY.

**The window is 784 px of ONE distinct colour, before and after, at both
ends** — `(45,9,63)` then `(33,26,16)`. Neither measurement is contaminated,
so the difference between the two runs IS the object's colour. This is the
DODGE proof, not the JUMP log's window artefact.

#### Confusion checked against EVERY on-track object, not the two named

The brief named STOMPER's ice blue and the trackside props. Both were checked,
and so was every other hazard — a check that only looks where it is told to
look would have missed the pair that actually matters.

| against | contrast | hue delta (before → after) |
|---|---|---|
| STOMPER (ice blue) | 11.17:1 | 77.9° → **166.8°** (improves sharply) |
| **DODGE (dark red)** | **1.04:1** | 88° → **27.2°** (closest pair in the scene) |
| JUMP (amber) | 9.94:1 | → 8.5° (separated by value, 10:1) |
| CHARGER (pink) | 10.49:1 | → 69.1° |
| decor stump / bench / sign | 1.35 / 1.84 / 2.38 | 147-150° → **31-34°** |
| decor trunk / rock / bush | 1.05 / 1.15 / 1.09 | 166-173° → **71-79°** |

**Two of these are real costs and are not dressed up.** Against DODGE and
against the olive props the hue separation NARROWS. What each one rests on
instead:

- **DODGE** renders `(52,7,0)` at saturation **1.00**; the rat renders
  `(33,26,16)` at **0.52** — a 3.7× gap in the green channel, and a
  pure-hue near-black against a muted brown. Beyond colour: a 2m unjumpable
  upright trunk is not a 0.6m ground quadruped.
- **The props sit off the track slab by keep-out** and are never adjacent to a
  hazard. The rat also holds the **highest dark-object contrast against the
  track** of anything measured here — 3.27:1 against the stump's 2.42, the
  bench's 1.78, the sign's 1.38.
- **Neither matters inside the reaction window.** `ENEMY_ALARM_RAMP_WINDOW_S`
  is 4.5s, so by the time a player must act the rat is `(239,20,28)` and 11:1
  clear of every object in the table. The resting colour's job is identity at
  distance, not the danger read.

The chosen hue sits deliberately between the two collisions: rendered 35.3°,
which is 27.2° from DODGE and 31.4° from the nearest prop. Pushing it toward
either buys separation from one by spending it on the other.

#### The glb went THROUGH the pipeline, and that was proven before use

Geometry read back out of the shipped file and rewritten by
`decimate_decor.write_glb` — **not hand-patched**. Proven lossless first by
rewriting with the OLD colour and confirming a byte-for-byte match against the
shipped asset, so the only possible difference in the new file is the colour.
Verified after: **BIN chunk byte-identical** (2,688 bytes, 76 verts, 148 tri),
`KHR_materials_unlit` preserved, JSON identical apart from `baseColorFactor`.

#### It is FLAT, not per-facet — a real gap against the reference

The reference render varies tone between facets. This does not, and cannot
cheaply:

- the decimator **cannot carry UVs** (already documented for the decor leafy
  tree), so no texture survives at any triangle budget;
- vertex colours would **multiply with the alarm ramp's albedo write**,
  turning the one signal that has to read instantly into a mottled red;
- every contrast number in this project is computed on a single flat albedo —
  per-facet variation would make "the rat's colour" a distribution rather than
  a number.

#### Validation

`DarkPaletteAudit` **byte-identical on stdout AND stderr** — the predicted
result, and the strongest possible confirmation that the alarm-tinted row was
what it was always measuring. Four gated hazards unmoved (DODGE 3.39/3.37,
JUMP 3.04/3.02, CHARGER 3.20/3.21, STOMPER 3.41/3.41), 0 missed samples.

`AlarmRampAudit` **12/12 OK, exit 0, diff of exactly two lines** — the ENEMY
base colour on the placeholder path and on the shipped-glb path, which is the
whole change. stderr identical.

`AssetContractAudit`, `ProbeTimeoutAudit`, `DeathModelAudit`,
`ChargerShapeProbe`, `PursuerFramingAudit` — all exit 0. Import and Web export
exit 0; `index.wasm` 35,376,909 as on every previous batch. Payload trap
holds: 0 `assets_source` resources imported into the pack.

#### Still open

- **Does a dark brown-grey read as an ANIMAL rather than as debris** at real
  speed on a phone? No probe answers that; it is the whole point of the batch
  and it is a device call.
- **DODGE at 27° of hue** — measured, argued from saturation and silhouette,
  but only an eye at speed can say whether "dark red wall" and "brown rodent"
  ever get confused in the fraction of a second before the ramp fires.
- **The flat finish**, above.
- ~~**CHARGER (boar) remains the last uninstalled subject.**~~ **CLOSED the
  same day** — installed at LOD 560, see the entry below. No subject of the
  batch remains uninstalled.

### 2026-08-12, fourth of the day — CHARGER (boar), INSTALLED — the last subject

Branch `claude/charger-hazard-decimation-9j7aeq`, off `main` = `staging`
(`756b943`). `assets/models/keepy_charger_boar.glb` on `Obstacle/ChargerMesh`
— **560 triangles, 10.7 KB, flat, unlit, untextured**, carrying CHARGER's
existing pink verbatim. Sixth and final asset of the hazard batch; every
variant now carries one.

This is the most constrained install of the six, for three reasons that
compound: CHARGER is the **only fatal hazard** (one contact ends the run, see
the half-strike rebalance), it held the **narrowest gated contrast margin**
of the four at 3.20:1, and its telegraph's strongest cue is a **shape that
points at the player** — the one cue that survives every palette by
construction rather than by measurement.

#### Identified by render; the name happened to be right

`Shadowtusk` is a tusked, maned boar and CHARGER was the only hazard left, so
unlike the "beaver" that turned out to be a rat this file's name survived
contact with a render. The method did not change: rendered from six axes
first. From **+Z** the snout, eyes, ears, tusks and front legs are all
present; from **−Z** only the rump and the tail sweeping away. Bbox
**0.831 × 1.128 × 1.903**, dominant in Z — long nose-to-tail, which is what a
hazard travelling *at* the player along the track wants to be.

Both of the batch's recurring premises held again, measured on entry: the
source is **4,848 triangles** (not the 1,200 cap the original brief claimed)
and declares **no `KHR_materials_unlit`** — PBR with three textures, like all
six.

#### ⚠️ `model_rotation_degrees` is NOT zero here, and the asset is not why

The other five installs left it at zero. This one cannot, and the reason has
nothing to do with the boar: **`ChargerMesh` is the only slot in
`Obstacle.tscn` carrying a rotated transform**,
`Transform3D(1,0,0, 0,0,-1, 0,1,0, 0,0.9,0)` — a quarter turn about X that
exists so the PLACEHOLDER prism's apex leads (a `PrismMesh` narrows toward its
own +Y; the slot turns that into world +Z). An installed model is a **child**
of the slot and inherits it, so a boar that is correct in its own space would
be drawn standing on its nose, its up-axis pointing at the player.

`model_rotation_degrees = (-90, 0, 0)` cancels it exactly, leaving the net
rotation identity. The slot's own transform is deliberately left alone:
`ModelSlot.gd`'s `model_offset` note already carries the general form of the
argument — correcting the slot rather than the model breaks the placeholder,
and breaks it in the state nobody looks at.

**Corollary for any future slot:** `model_offset` is expressed in SLOT-local
units, so on this slot its axes are rotated too. Local +Y is world +Z and
local +Z is world −Y. The shipped `Vector3(-0.01547, 0.53393, -0.12699)`
reads as "1.5 cm left, 53 cm forward, 12.7 cm down" only after that mapping.

#### LOD 560, and the criterion is neither triangles nor eyeballs

Full reasoning and the per-band table are in 7.4. In short: a boar's read is
a lowered pointed head distinct from the shoulder mass, and decimation eats
the extremities that carry it. The **snout band** holds 74% of its true
half-width at LOD 150 and 95% at 380; the **mane crest** — the feature that
breaks the top of the head-on outline — only returns at **560**, which is the
smallest LOD whose whole front half matches LOD 800's (98.3%, identical
through 800).

⚠️ **A finding worth carrying forward, because it reframes what a LOD buys on
this hazard: head-on, at every LOD tested, the boar's flat silhouette is a
MASS, not a pointed wedge.** The snout is foreshortened onto the body by the
very axis that makes it a charger. Rasterising the outline at true on-screen
size (75° vertical FOV on 1080×1920 gives 1251/d px per metre; ~150 px tall at
17 m, ~270 px at 10 m) shows the LODs differing only at the crest, the legs
and the tusk notches. What triangles buy here is those outline breaks, not a
point — which is precisely why the crest, not the snout, set the number.

#### Scale: the placeholder's lateral presence, held exactly

`model_scale = 1.82584` pins X to **1.5000**, the placeholder's own width —
*not* to the collider's 1.2. That is the deliberate generous visual
`Hitboxes.gd` defends in its own comment as "the single clearest existing
proof in this project that a hazard's silhouette and its hitbox are already
allowed to differ". Pinning here makes lateral presence **bit-identical to
what ships today**, so this batch cannot move any lane-dodge judgement: it
changes the shape, not the footprint.

`model_offset` also **centres the mesh in X**. It arrives 15.5 mm off-centre
— nine times the 1.7 mm the dragonfly install rightly dismissed as
measurement noise — and on a fatal, laterally-dodged hazard an off-centre
visual is a left/right dodge asymmetry rather than a cosmetic one.

Resulting world extents, off the built scene: **X 1.5000, Y 0.0000–2.0787,
Z −1.2000–2.2870.**

⚠️ **`AssetContractAudit` prints this row as `1.500 x 3.487 x 2.079`, and that
is not a contradiction: it reports the AABB in SLOT space, which on this one
slot is rotated.** Its Y is world Z. Nothing else in the project reports a
3.5 m-tall boar.

**Residuals, stated rather than dressed up:**

- **The body is 3.487 m deep against a 1.0 m hitbox**, so the nose reaches
  **1.787 m ahead of the lethal front face**. Forgiving, not punitive: the
  hitbox arrives *after* the nose visually does, and the charger's own visual
  envelope already spanned 5.3 m of track because of its trail bars — the rear
  is unchanged and only the nose extends further.
- **2.0787 m tall against a 2.0 m hitbox** (+0.079). Harmless on an unjumpable
  hazard: there is no legal jump for an over-tall visual to make look illegal,
  the same argument DODGE's 0.253 m overshoot rests on. It clears the jump peak
  by **0.521 m** where the placeholder cleared it by 0.242 m.

#### ⚠️ The trail bars were 0% visible before this install

The MOTION third of the telegraph — three speed-line bars that `Obstacle.gd`
calls "unambiguous even in peripheral vision" — is **entirely occluded by the
placeholder wedge from the game camera**, and this install is what revealed
it. Measured by rasterising the assembled charger from the camera
`CameraFollow` actually produces (it lerps to `target + (0,4.2,7)` then
`look_at`s `target + (0,1,-4)` every frame, so `Game.tscn`'s authored −20° is
overwritten and the real pitch is **−16.2°**):

| obstacle z | placeholder, same lane | boar, same lane | placeholder, adjacent lane | boar, adjacent lane |
|---|---|---|---|---|
| −16 | **0%** | 16% | **0%** | 26% |
| −12 | **0%** | 22% | **0%** | 35% |
| −8 | **0%** | 34% | **0%** | 49% |
| −5 | **0%** | 52% | 2% | 64% |
| −3 | **0%** | 67% | 2% | 72% |

The wedge is 1.8 m tall and full-width at its rear face; the bars sit at
y = 1.1 just 0.4 m behind it, so from a camera 4.2 m up every ray to a bar is
blocked. The boar's narrower, lower rump lets them through for the first
time. **Not confirmed on device** — this is a composite render whose geometry
agrees with `ChargerShapeProbe`'s numbers off the built scene, not a
screenshot of the game.

The body's tail is placed on **z = −1.200**, the placeholder's own rear plane,
so the 0.100 m gap to the nearest bar is preserved exactly rather than merely
kept positive.

#### Colour: a verbatim carry-over, and that is the point

`StandardMaterial3D_Charger` already carries `shading_mode = 0` and **no
emission**, exactly like JUMP and STOMPER. DODGE, ENEMY and AIR_ENEMY each had
to be re-solved because going unlit removed a multiplication (and, for two of
them, an additive emission term) — none of that applies here, so the shipped
`(1.0, 0.72, 0.88)` renders to the same pixels it already renders to.
Re-solving a correct colour would move a gated number on the one hazard where
being wrong ends the run, in exchange for nothing. The hue is not free either:
`Obstacle.gd`'s TELEGRAPH block picks magenta precisely because every other hue
in the game is taken, and names the five it would collide with.

**`DarkPaletteAudit` diff against `origin/main`: exactly three lines, all
CHARGER, and the margin goes UP.**

| | baseline | this batch |
|---|---|---|
| CHARGER shallow | `rgb(0.9882, 0.7098, 0.8667)` — **3.20:1** | `rgb(0.9882, 0.7098, 0.8706)` — **3.21:1** |
| CHARGER deep | `rgb(0.9804, 0.7059, 0.8627)` — **3.21:1** | `rgb(0.9809, 0.7059, 0.8627)` — **3.21:1** |

Gated margin above the 3.0 floor: **+0.20 → +0.21. Nothing was spent.**
DODGE 3.39/3.37, JUMP 3.04/3.02, ENEMY 1.20/1.20, AIR_ENEMY 1.32/1.32,
STOMPER 3.41/3.41 are **byte-identical**, as they must be. 0 missed samples.

**Verified by histogram rather than assumed**, because this batch has produced
both a window artefact (JUMP, 3.28 → 3.02) and a real colour change (DODGE)
that look alike from the ratio alone. Sample window instrumented on both trees,
then reverted:

| tree | window contents | dominant value |
|---|---|---|
| baseline (prism), shallow / deep | **196 px, 1 distinct colour** | `(252,181,221)` / `(250,180,220)` |
| this batch (boar), shallow / deep | **196 px, 2 distinct** | `(252,181,222)` ×195 / `(250,180,220)` ×171 |

**Both windows are 196/196 object pixels — zero ground, zero sky, on both
sides**, so neither measurement is contaminated and the difference between
them is real. It is **one 8-bit step** (blue 221→222 shallow; red 250→251 on
25 px of 196 deep), on a curved unlit surface sitting at slightly different
depth under the exponential fog — the STOMPER install's signature exactly, not
a colour change. The authored albedo is independently provable: the
placeholder row and the imported-mesh row of `AssetContractAudit` both print
`unshaded rgb(1.00, 0.72, 0.88)`.

#### `ChargerShapeProbe` rewritten — before the install, not after

The probe read `mesh_instance.mesh` and asserted that a `PrismMesh` narrows
toward +Z. That is a contract about a primitive, not about the CHARGER: it was
written to fail loudly the moment a `.glb` landed here, deferring the rework.
Rewritten first, so the expected failure never had to be chased.

It now asserts the same contract off **whatever the slot draws**, in two
phases (placeholder / as-shipped), reading vertices through
`ModelSlot.get_transform_to_slot()`:

- the front of the body is narrower than the rear — **asserted against the
  tail rather than a constant**, because a model installed back-to-front is
  the failure this guards and nothing else in the project would notice it
  (source boar reads 0.72; reversed it would read ~1.0);
- it genuinely tapers (ceiling 85% of its widest);
- it sits on the ground and stands above the jump peak;
- **the trail bars are behind it AND not swallowed by it** — new, and new
  because the placeholder was a metre shallower than any imported body.

⚠️ **A `ModelSlot` property this found by failing, worth knowing before
copying `AlarmRampAudit`'s trick:** clearing `model_scene` on a live slot does
**not** restore the placeholder. `_install_model()` sets `mesh = null` when it
installs and the null-model branch never puts it back, so the slot ends up
drawing **no geometry at all**. `AlarmRampAudit` is unaffected because material
overrides survive that path; vertices do not. PHASE A therefore clears
`model_scene` **before** the node enters the tree, which is also the more
honest test — it exercises the path that would really ship.

Verified on the pre-install tree first, reproducing the old probe's numbers
exactly (X 1.500, Y 0.000–1.800, Z −1.200–1.200), then green on both phases
after.

#### Validation

`ChargerShapeProbe` (both phases), `AssetContractAudit` (**12/12 visuals, 0/10
colliders moved**, `ChargerShape` still `Box(1.2, 2.0, 1.0)` @ +1.000),
`DarkPaletteAudit` (0 missed samples, 4 gated hazards above 3.0),
`AlarmRampAudit` (12/12), `ProbeTimeoutAudit` (**33 probes**, back to baseline
after the throwaway census was removed), `DeathModelAudit`,
`PursuerFramingAudit` (37.1% max, CAPTURE exempt by design) — **all exit 0**.

Diffs against `origin/main` are exactly as small as they should be:
`AssetContractAudit` **one line** (the ChargerMesh row, `[-- ]` → `[glb]`),
`DarkPaletteAudit` **three lines** (above); `AlarmRampAudit`,
`ProbeTimeoutAudit`, `DeathModelAudit` and `PursuerFramingAudit`
**byte-identical on both streams**.

**Seeded gameplay probes byte-identical on both streams** (seed 20260806,
separate worktree): `ChargerAudit`, `ShrinkAudit`, `ComboAudit`. That is the
bar for a purely visual batch, and it says more than a matching verdict would.

Import and Web export **exit 0**. `index.wasm` **35,376,909**, identical to
every previous batch — that is the identity proof, not the `.pck` (4,810,896
here; its size is not stable across exports of the same commit). Payload trap
holds: **0** `assets_source` resources imported into the pack against **407 MB**
of raw sources on disk. The shipped `.glb` declares `KHR_materials_unlit`
(used *and* required), carries **0 images, 0 textures, 0 samplers** and a
`POSITION`-only attribute set.

**EIGHT slots now carry an asset**: Keepy, `pursuer/Silhouette`, and all six
hazard meshes.

#### Still open

- **Device judgement, and it is worth more here than on the other five.** No
  probe says a boar reads as a charging boar at speed on a phone, and this is
  the only hazard where being unreadable ends the run rather than costing half
  a strike.
- **The 1.787 m nose overhang** ahead of the lethal front face — argued as
  forgiving above, but only an eye at real speed can say whether "it is on me"
  and "it has hit me" separate cleanly.
- **The trail bars becoming visible for the first time** is a change to a
  telegraph that has never actually been seen. It should be better; it has not
  been confirmed on device, and it was not asked for.
- **Head-on the boar is a mass, not a point** — the shape cue that
  `Obstacle.gd` credits with surviving every palette is carried by the crest
  and legs breaking the outline, not by a visible taper. Whether that still
  reads as "aimed at me" is exactly what a device pass has to answer.
