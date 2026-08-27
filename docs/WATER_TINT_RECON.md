# WATER-TINT RECON -- Keepy's material tinting toward the water hue while
he is in it, measured, for the batch that will actually wire it

**27 aout 2026. RECON ONLY: no gameplay file is touched.** Branch
`claude/keepy-water-recon-3w83et`, ahead of it, on top of
`claude/keepy-water-collision-recon-6w1a0a` (`docs/WATER_WALK_RECON.md`)
and `claude/keepy-water-recon-3w83et` (`docs/WATER_ACCESS_RENDER_RECON.md`).
`origin/main` is `a007e78`, `origin/staging` is `916d7d8`, both exactly as
the brief expected. Refs sorted by date, trees compared rather than names
-- the newest ref in the repo (`claude/keepy-water-collision-rename-k9k6sq`,
06:05:42) is already an ancestor of `origin/staging`, so no branch carries
this brief and no concurrent session is running.

**Mathieu's decision, restated so nothing below re-litigates it**: the
effect is TINT. When Keepy is in any of the five water bodies, his
material shifts toward the shared water turquoise (`#40E0D0`, the one hue
already applied uniformly across pond/small lake/stream/both great-lake
lobes -- see `HubBuilder.POND_WATER_COLOR`'s own docblock for that
decision). Applied to all five bodies identically. Squash and a waterline
are explicitly OUT. The boat is out of scope. No shader distortion/reflect
-- already settled in the prior recon, gl_compatibility renderer.

Every number below comes from two THROWAWAY probes driving the shipped
`scenes/HubWorld.tscn`, `KeepyHopper`, `ModelSlot`, `HubBuilder`,
`HubRegion` and `HubStreamRoute` -- `WaterTintReconProbe` (numeric,
`--headless --fixed-fps 60`) and `WaterTintCaptureProbe` (pixels,
`xvfb-run --rendering-driver opengl3`, never `--headless` -- that forces
the DUMMY driver and a fabricated viewport size, the trap this repo has
already paid for on this exact screen, and independently again while
building `WaterTintReconProbe` itself, see the pitfall note below). Both
probes are deleted before this commit; `ProbeTimeoutAudit` was re-run after
deleting them and reports exactly the pre-existing baseline, **48 probe
scenes**.

---

## Q1 -- Keepy's material is a single StandardMaterial3D, and the
injection point already exists, on the same asset, in production

`assets/models/keepy_squirrel_hero.glb`, read directly (GLB JSON chunk,
not assumed): one mesh, one primitive, one material (`material.001`),
`KHR_materials_unlit`, a single `baseColorTexture`, no `pbrMetallicRoughness`
factors beyond it. **MEASURED on the live scene**, not just the file:
`ModelSlot.slot_material()` on Keepy's `Yaw/Body` node returns a
`StandardMaterial3D` with `albedo_color = (1,1,1,1)` and
`shading_mode = 0` (UNSHADED) -- the model's whole colour lives in the
texture, and the material's own albedo starts at pure white, which is
exactly the state `_ensure_material()`/`_tint_to()` in
`scripts/battle/FighterView.gd` are already written to multiply against
on this SAME asset (`keepy_squirrel_hero.glb`, Battle's player fighter).

**There is nothing to build.** `ModelSlot.apply_material(material)`
(`scripts/world/ModelSlot.gd`) already writes a surface-0 override onto
EVERY `MeshInstance3D` the slot draws -- measured at 2 nodes for Keepy's
installed model (`Body` itself, whose own `mesh` is cleared once the model
installs, plus `Mesh1_0`, the model's own draw node). The reusable pattern,
already shipped and already proven on this asset:

```
_ensure_material():  duplicate slot_material() as StandardMaterial3D
                      (a fresh copy -- writing the shared one would tint
                      every instance of this .glb in the project, not
                      just Keepy's)
_tint_to(colour, duration): tween the duplicate's albedo_color, ModelSlot
                      already carries the write via apply_material()
```

A hub-side tint needs the SAME three lines FighterView.gd already has,
called from `HubWorld.gd` (which already owns Keepy's `ModelSlot`
reference path) instead of from a `FighterView` node. No new mechanism,
no shader, no second material factory.

## Q2 -- MEASURED on the shipped asset and the shipped camera distance:
legible from 50%, unambiguous by 75%, still recognisable at 100%

Method: `WaterTintCaptureProbe` freezes `HubCamera` at the scene's own
baked spawn transform (Keepy at the origin, camera at
`(0,7.6,8.9)`/`-34deg`pitch -- the pose `HubWorld.tscn` already ships,
unmoved), duplicates Keepy's live material exactly as `_ensure_material()`
would, and writes `albedo_color = base.lerp(#40E0D0, f)` for
`f in {0, 0.25, 0.5, 0.75, 1.0}`, rendering and saving a PNG at each step.

**Not eyeballed on the full frame -- MASKED**, the same discipline this
project's water recolour batches already use for exactly this reason (a
fixed sample window reads background pixels the moment the subject does
not fill it). The mask is built by diffing a frame WITH Keepy against one
with `_body.visible = false`, at the identical frozen camera: **20,275 of
2,073,600 pixels (0.98%) are Keepy's own**, and every colour figure below
is the mean over exactly those pixels, never a crop guess.

| fraction | masked-mean RGB | RGB-euclid delta vs f=0 | hue delta vs f=0 (deg) |
|---|---|---|---|
| 0.00 (shipped) | (0.852, 0.605, 0.491) | 0.000 | 0.0 |
| 0.25 | (0.692, 0.586, 0.468) | 0.163 | 12.9 |
| 0.50 | (0.533, 0.568, 0.446) | 0.325 | 58.3 |
| 0.75 | (0.373, 0.550, 0.423) | 0.487 | 118.1 |
| 1.00 | (0.212, 0.531, 0.400) | 0.651 | 136.5 |

**Confirmed visually, not just numerically** -- five crops saved and
inspected (`blend_000.png` .. `blend_100.png`, cropped to Keepy's own
bounding box, 2x nearest-neighbour for inspection). At 0% Keepy is his
ordinary rust/cream self. At 25% the shift is real in the numbers (12.9deg
of hue) but reads to the eye as "a slightly muddier brown" -- not yet
legible as a colour EFFECT rather than a lighting quirk. By 50% (58.3deg,
crossing out of the orange/brown family) the shift is visible but still
ambiguous between "wet" and "unwell" -- an olive-brown that could be read
either way. At 75% (118.1deg, deep into the teal/cyan the water itself
uses) the shift is unambiguous: Keepy reads as visibly tinted toward a
blue-green, while his silhouette, ears, badge and eyes remain fully
legible -- nothing here approaches unrecognisable. At 100% (136.5deg) he
is close to the water's own hue family and the LOWEST-saturation, largest
patches (belly, cheeks) start to compete visually with a teal background,
but the darker facial markings, eyes and the "K" badge keep him
distinguishable at every fraction tested.

**MY OWN READ, published as a recon opinion and explicitly not a device
call** (every colour judgement in this project's own history says the
same about itself): **50% is the floor where the shift stops being
noise; 75% is the point I would pick if forced to name one** -- it is
already unambiguous and keeps the largest margin before the silhouette
starts competing with the background at 100%. Nothing here decides that;
it is Mathieu's call on a real screen, and this recon's job was only to
put a number and a picture behind each option rather than an impression
alone.

## Q3 -- a unified 5-body test costs almost nothing to build, and the
premise that it is "two different shapes of work" survives ONLY as a
shape distinction, not a cost one

`WaterTintReconProbe` builds the test live from public API that already
exists, changes nothing in `scripts/hub/`, and measures both correctness
and cost.

**The four discs** (pond, small lake, both great-lake lobes) are a
straight `centre.distance_to(point) < radius` each, reading centres/radii
off `HubBuilder.POND_WATER_RADIUS` / `HubBuilder.SMALL_LAKE_WATER_RADIUS`
/ `HubRegion.lakes()` -- no new constant, no new lookup.

**The stream is NOT a sixth disc row, exactly as the prior recon said**
-- but the machinery it needs already exists and needed writing NOTHING
new to prove: `HubStreamRoute.distance_to(point)` (used today by
`BoatMooring`) already returns "distance to the nearest point on the
built spine, ignoring y". Membership is
`route.distance_to(point) < HubBuilder.STREAM_WIDTH * 0.5`, one
`HubStreamRoute` built once from `HubBuilder.stream_spine()` (already a
public accessor) and reused per query.

**Correctness, all five bodies**: 1 known-inside point, 1 known-outside
point, each -- **0 failures out of 5**.

**Float32 rim, all five bodies now, including the stream's ribbon edge
(never swept before -- `WATER_ACCESS_RENDER_RECON.md` Q4 names this gap
explicitly)**: 360 azimuths per disc, 40 perpendicular offsets for the
ribbon, sampled at exactly the boundary and at boundary+0.001:

| body | at exact boundary | at boundary+0.001 |
|---|---|---|
| pond | 136/360 read as water | **0/360** |
| small lake | 141/360 | **0/360** |
| great lake lobe A | 137/360 | **0/360** |
| great lake lobe B (spawn) | 52/360 | **0/360** |
| stream (ribbon half-width) | 29/40 | **1/40** |

The four discs reproduce `WATER_WALK_RECON.md`'s own float32 finding
exactly (roughly half the boundary samples slip under strict `<` at the
float32 rim, all clear at +0.001). ⚠️ **The stream does NOT fully clear
at +0.001, and that is new information, not published before**: 1 of 40
perpendicular-offset samples still reads as water a millimetre past the
nominal edge. Cause not chased down further here (out of this recon's
mandate) -- `distance_to()` composes a `project()` (a per-segment nearest
point search) with a Euclidean distance, so its floating-point error
accumulates over more operations than a single `distance_to(centre)`
call does for a disc; a caller of this test on the stream should sample
slightly past the rim than +0.001 (e.g. +0.005) if it needs a guaranteed
land reading right at the ribbon edge, or accept that a stray query at
the exact millimetre can occasionally misclassify -- neither of which
this recon decides.

**Cost, usec/call, averaged over 20,000 calls per body**:

| body | usec/call |
|---|---|
| pond | 0.0995 |
| small lake | 0.1004 |
| great lake lobe A | 0.1070 |
| great lake lobe B | 0.1056 |
| **stream** | **18.5844** |

The stream is ~186x a disc query -- it walks all 88 spine segments per
call, where a disc is one `distance_to`. **Still cheap in absolute terms**
for the call pattern Q4 below needs (once per landing, not once per
frame): at 60fps a per-frame five-body test would cost ~18.9usec total per
frame (~0.11% of a 16.7ms frame budget even on this sandbox's software
rasteriser), and Q4's actual insertion point only needs it on a LANDING,
not every frame -- so the real cost is on the order of a few landings per
second, not 60/sec.

**What this recon does NOT decide, restated from the prior one**: "which
body am I in" (this file) and "how far to sink" (Q2 of
`WATER_ACCESS_RENDER_RECON.md`, not reused here since the design decision
is TINT, not sink-and-clip) remain two separate questions. A tint gate
only needs the first.

## Q4 -- the insertion point is `KeepyHopper._on_hop_finished()`, MEASURED
on the real hopper: the landing lands at frame 17, exactly where
`hop_landed` already fires

`WaterTintReconProbe` connects to the real `KeepyHopper.hop_landed` signal
on a live instance, drives an ordinary 6-unit hop with real
`--fixed-fps 60` frames, and records exactly when the signal fires:
**frame 17** after `hop_to()`, matching `HOP_DURATION` (0.28s = 16.8
frames, landing on the 17th -- the same quantisation
`KeepyHopper.HOP_DURATION`'s own docblock already documents for crossing
times).

Reading `KeepyHopper.gd`'s own line order in `_on_hop_finished()`:
`global_position` is snapped to the landing FIRST, `hop_landed.emit(...)`
fires SECOND. A listener on `hop_landed` (as `HubWorld._on_hop_landed`
already is, for portal detection) sees the landed position before doing
anything else -- so the water-membership test from Q3 slots in exactly
where `HubWorld._on_hop_landed` already runs its own per-landing checks,
using the SAME landed position that call already receives.

Mid-air (`_apply_hop(t)`, every frame of the tween) is the other
candidate, and this recon's opinion is that it is not needed: `HOP_HEIGHT`
(0.6) clears every one of the five water tops -- all under 0.10 above
Keepy's rest Y (`WATER_ACCESS_RENDER_RECON.md` Q2) -- well before the
apex, so a tint gated only on landings will never visibly "pop" mid-flight
over dry ground; the only moment that matters for a TINT effect (as
opposed to a sink-and-clip, which this batch does not do) is where feet
touch down.

A transition on/off is a TWEEN, not instant, by the same reasoning
`_tint_to()` in `FighterView.gd` already applies (every colour write on
this project is a tween, never a hard cut) -- this recon did not build a
separate render comparison for instant-vs-tween because the mechanism
Q1 hands over already only tweens, and re-arguing that choice for one
more call site was not asked for.

## Q5 -- zero new draw nodes, zero new materials beyond the one duplicate
Q1 already needs; the boat cannot share Keepy's material by construction

Current baseline, read from `docs/HUB_PERF_BASELINE.md`'s own latest row
rather than recomputed: **98 draw nodes excl. portals, 104 total,
margin 162 under the 260 ceiling.**

This batch's mechanism (Q1) writes a `StandardMaterial3D.albedo_color`
property on a material ALREADY bound as a surface override on TWO
already-drawn `MeshInstance3D` nodes. **No draw node is added, no new
mesh, no new material resource beyond the one duplicate `_ensure_material()`
-style call already makes once.** The 260-node ceiling is untouched by
this recon's design.

**The boat cannot pick up Keepy's tint by accident -- verified by reading
both construction paths, not asserted**: `HubBuilder._make_boat()` builds
every one of its parts through `_mesh_node()`, which calls
`_unshaded(colour)` -- a factory that allocates a FRESH
`StandardMaterial3D.new()` on every call and binds it via
`set_surface_override_material(0, ...)`. `grep`-ing
`scripts/hub/BoatMooring.gd` in full for `slot_material`, `apply_material`,
`ModelSlot` or `Body` returns **zero matches**: the boat's hull/inner/rim
materials and Keepy's `.glb` material are never the same `Resource`, never
touched by the same code path, and the boat is never a `ModelSlot`. There
is no shared-material risk to guard against; there is nothing to share.

## Q6 -- MEASURED on the real hopper and a real route: `hop_landed` never
fires while riding, zero times over a full ride, so the natural insertion
point is already immune without an extra guard AT THAT SITE

`WaterTintReconProbe` boards a real `KeepyHopper` onto a real
`HubStreamRoute` (built from a throwaway 4-point spine, since the
mechanism under test is `KeepyHopper`'s state machine, not the shipped
stream's exact geometry) and drives 102 real physics frames of a full
ride to its natural end:

```
is_riding() before board():                 false
is_riding() the SAME FRAME board() returns: true
hop_landed emissions during the whole ride: 0
is_riding() once the ride ends on its own:  false
```

**Zero landings fired across the entire ride**, confirming structurally
what reading `KeepyHopper.gd` already suggested: `RIDING` is written
exclusively through `_place_on_route()`, which never touches
`_apply_hop`/`_on_hop_finished` -- the only two places that ever emit
`hop_landed`. **A tint gated on `hop_landed` (Q4's insertion point) is
therefore already immune to firing while Keepy is visually on the boat,
with no extra `is_riding()` guard needed at that specific call site.**

That is narrower than "no guard needed anywhere", and said as such: any
FUTURE water-tint code that instead polls "am I in water" every frame
(rather than only on `hop_landed`) would need the same `is_riding()` guard
`HubWorld._on_hop_landed` and `BoatMooring` already both carry for
identical reasons -- riding the water is not being IN it. This recon does
not build that alternative design; it only confirms the one Q4 names is
already safe.

---

## Pitfall hit while building this recon, recorded because it is a second
independent instance of a pattern this repo already names

`WaterTintReconProbe`'s Q4/Q6 section is written as an `async` function
(`_q4_q6_hopper_cycle`, itself using `await get_tree().physics_frame`
inside) and was FIRST called from `_ready()` without an `await` in front
of it. The call started the coroutine, which suspended at its first
`await` and returned control to `_ready()` immediately -- which then
printed `=== DONE ===` and called `get_tree().quit(0)` before the
coroutine ever resumed. The bug produced no error at all: the probe
exited 0, printed a clean header for the section, and silently produced
NOTHING after it -- a probe that looks complete and is missing its whole
back half. Fixed with one `await` in front of the call. Worth naming
because it is the same family as the `--headless` DUMMY-viewport trap
this file's own probes were built to avoid -- a silent, structurally
correct-looking, and completely wrong result, from a one-word omission.

## What a follow-up implementation batch has to decide before it is scoped

1. **The blend fraction** (Q2) -- this recon's own opinion is 50% floor,
   75% recommended, but it is Mathieu's call on a real screen, and this
   recon deliberately did not pick for him.
2. **The stream's float32 rim margin should be a bit more than +0.001**
   (Q3) -- 1/40 samples still slipped there; a real implementation should
   pick its own safety margin rather than copy the disc convention
   verbatim.
3. **`HubWorld.gd` gains the actual wiring**: a `HubStreamRoute` cached
   once from `HubBuilder.stream_spine()`, the five-body test from Q3, a
   `_tint_to()`-shaped pair of functions borrowed from
   `scripts/battle/FighterView.gd`'s pattern, called from
   `_on_hop_landed()` at the point Q4 names -- none of that is written
   here.
4. **Nothing about performance, node budget, or the boat's material
   blocks this** (Q5) -- the only real open question is the colour
   itself and the rim margin above.
