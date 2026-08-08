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
