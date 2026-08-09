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

| Asset | Max triangles | Live at once | Frame cost |
|---|---|---|---|
| Keepy | 6,000 | 1 | 6,000 |
| Hibou | 8,000 | 1 | 8,000 |
| Hazard (each of 6) | 1,200 | 7 | 8,400 |
| Track tile | 800 | 7 | 5,600 |
| Noisette / Gland | 300 | 14 | 4,200 |
| Markers, trail bars | primitives | ~5 | negligible |
| | | **total** | **~32,200** |

That leaves ~35% headroom against the 50k target.

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
- **KNOWN OPEN DEFECT, not fixed: the strike cues leak one resource at engine
  shutdown.** This is the first time audio has existed in this project at all,
  and it is the one thing in this batch that does not come back clean.
  `StrikeAudit` (the probe that fires these cues most -- its bots stumble by
  design) ends with `ObjectDB instances leaked at exit` +
  `1 resources still in use at exit`.

  **Measured, with the sample counts stated** -- because an earlier reading in
  this same batch called it "deterministic" off two agreeing samples and was
  wrong:

  | tree | runs | runs showing the leak |
  |---|---|---|
  | before (no audio at all) | 4 | **0** |
  | after (two cues) | 6 | **5** |

  So the audio causes it, and it is *intermittent*, not deterministic.
  Attempted and **failed** to fix: `_exit_tree()` calling `stop()` on both
  players (one clean run, then the leak returned); additionally clearing
  `stream` on both (3 of 3 runs still leaked). Whatever holds the resource is
  not reachable from this script, and chasing it further was out of proportion
  to its impact. The `stop()` calls were kept as ordinary teardown hygiene,
  with the limit stated honestly in `HUD.gd` rather than implied fixed.

  **Why it was judged not to block:** the leak lines land *after* the probe's
  own `PASSED` verdict, every measurement above them is byte-identical across
  all six probes, and `scripts/dev/*` is excluded from the shipped build, so
  no player ever runs the code path that produces it. What it does break is
  the literal byte-identical stdout comparison this project gates changes on
  -- which is why it is written down here in full rather than waved through:
  the next session running that comparison will see StrikeAudit differ by
  these four lines and needs to know it is this, and not something new.
- So the unlit switch here is justified by §8's argument
  (an unshaded surface's post-invert colour is a *known* value) and by the
  offscreen render, **not** by a measured six-palette contrast pass like the
  Hibou got. A Keepy equivalent of `PursuerContrastAudit` is the honest next
  step before anyone treats Keepy's dark-mode legibility as verified.
