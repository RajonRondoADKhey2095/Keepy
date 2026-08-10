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
| hazards | 8,400 | 7,068 – 8,372 | within |
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

## 8. Materials and dark mode — the constraint that decides legibility

Every ~20 seconds the game inverts the entire rendered frame and blends it
55% toward one of six saturated tints. At full dark, per pixel:

    final = (1 - rendered) * 0.45  +  tint * 0.55

Two consequences follow from that formula directly, and they are the whole
of the colour guidance:

1. **Hue separation collapses.** Every colour on screen is dragged 55% of
   the way toward *the same* saturated hue. Two objects that differed only
   in hue end up nearly the same colour.
2. **Value (luminance) separation survives, at exactly 45% strength.** The
   map is affine with slope -0.45 per channel, so any two colours'
   per-channel difference is preserved — scaled to 45% of what it was, and
   *inverted* (the lighter one becomes the darker one).

Measured confirmation, from the lane barrier (a bright striped wall) across
all six palettes:

| | measured range |
|---|---|
| Barrier **vs ground** (silhouette contrast) | **1.56:1 – 1.92:1** |
| Barrier's **own internal stripes** | **3.18:1 – 4.07:1** |

And from the tint sweep: the worst object-vs-ground contrast sits at
**1.00:1 – 1.03:1 across the entire tint range 0.18 → 0.75**. The floor is
set by the raw albedos against the ground colour — *not* by the tint
amount. Turning the tint down would not fix it.

**So, concretely:**

- **Do not rely on colour to separate an asset from the ground.** It does
  not survive, and no tint setting makes it survive.
- **Put the contrast INSIDE the asset.** Internal light/dark contrast
  holds 3.18–4.07:1 through every palette, while silhouette-vs-ground
  falls to 1.56:1. Strong value structure — a pale belly against a dark
  back, banded markings, a light rim — is what stays readable.
- **Silhouette is the most reliable cue there is**, because it is geometry
  and survives every palette unchanged. Give each hazard a shape readable
  in pure black at a glance.
- **Avoid mid-luminance albedos near the ground's** `rgb(0.55, 0.42, 0.32)`.
  Go clearly lighter or clearly darker.
- **Use `shading_mode = unshaded`** for anything whose dark-mode appearance
  must be predictable. An unshaded surface renders as exactly its albedo
  regardless of light angle, which is the only way its post-inversion
  colour is a *known* value. The CHARGER, STOMPER, jump marker and pursuer
  body all already do this.
- **Emission inverts too.** A bright emissive surface becomes dark after
  the invert. Do not use a glow as a "always bright" cue.

Current placeholder palette, for reference (do not reuse these hues
blindly — they were chosen to be mutually distinct, which §8 just
explained is the *weakest* axis in dark mode):

| Object | shading | albedo |
|---|---|---|
| Keepy | lit | `0.92, 0.55, 0.20` |
| DODGE | lit | `0.55, 0.05, 0.05` |
| JUMP | lit | `0.45, 0.28, 0.12` |
| ENEMY | lit + emissive | `0.40, 0.05, 0.55` |
| AIR_ENEMY | lit + emissive | `0.12, 0.85, 0.22` |
| CHARGER | **unshaded** | `1.00, 0.15, 0.62` |
| STOMPER | **unshaded** | `0.05, 0.20, 0.95` |
| Jump marker | **unshaded** | `0.15, 0.95, 1.00` |
| Noisette | lit | `0.95, 0.78, 0.15` |
| Gland | lit + emissive | `1.00, 0.72, 0.15` |
| Pursuer body | **unshaded** | `0.02, 0.02, 0.03` |
| Ground | lit | `0.55, 0.42, 0.32` |

> **Note on a known probe defect.** `DarkPaletteAudit`'s per-object
> sampling path currently reports `(0,0,0)` for 26 of its samples under
> software rendering (llvmpipe). Those values are **impossible shader
> outputs** — at full dark with the green tint, `final.r >= 0.12 * 0.55 =
> 0.066`, so a true zero cannot occur — and the probe's *barrier* pass,
> which samples through a different code path, returns correct non-zero
> values for the very same palettes. The per-object numbers from that path
> should not be trusted until it is fixed; the barrier numbers and the
> sweep summary above are the ones this section relies on. Unrelated to
> this batch, not fixed here.

> **Open design item, awaiting Mathieu's call -- pursuer body vs `DARK/2`
> ground (2026-08-09, `docs/PROBE_AUDIT.md` F10a).** Measured against the
> correct reference surface (the ground, not Keepy -- the probe used to
> sample the wrong thing, see F10a), `Pursuer body`'s `0.02, 0.02, 0.03`
> reads **2.37:1** against `DARK/2`'s ground, under this project's own
> 2.5:1 silhouette floor. This table's palette already sits at pure black,
> which the sweep behind the 2.5 floor puts at the *optimum* achievable
> value against this ground on this tint -- there is no darker or lighter
> unshaded albedo that reads better here, and the sweep's own ceiling for
> green (2.05) is already below the measured 2.37, so re-picking the
> pursuer's colour cannot close this gap. The two variables that can:
> **the ground's own albedo** (`0.55, 0.42, 0.32` above) or
> **`GameState.DARK_TINT_AMOUNT`** (0.55) -- both of which move every
> other object's dark-mode contrast on this table, not only the pursuer's.
> That is a project-wide colour call, not a per-asset one, and it is left
> for Mathieu to make. No code or probe change is pending on this note.

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

Run all four after installing any asset. The first two are the ones that
catch a rebalancing.

    godot4 --headless --path . res://scripts/dev/AssetContractAudit.tscn
    godot4 --headless --fixed-fps 60 --path . res://scripts/dev/PursuerFramingAudit.tscn
    godot4 --headless --path . res://scripts/dev/ChargerShapeProbe.tscn
    godot4 --headless --path . --export-release "Web" build/web/index.html

- **`AssetContractAudit`** must stay green: every collider still matches
  `Hitboxes.gd`, and the pursuer still has none.
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

`TrackPropsAudit` worst frame, five runs each side. **This probe is NOT
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
- **Props: 1,500 budget exceeded on 2 of 5 runs (worst 1,926).**

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
- **Web export**: clean, exit 0. `index.pck` **4,723,040 -> 4,736,160 bytes,
  +13,120** for both assets, built from a throwaway worktree at `origin/main`
  against the current tree with identical templates. `index.wasm` md5
  identical.
