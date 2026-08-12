#!/usr/bin/env python3
"""Weld + decimate a raw Meshy HAZARD .glb down to a frame-budget LOD.

WHY THIS EXISTS AS A SIBLING OF decimate_decor.py
-------------------------------------------------
Same mechanism, different family and different colour contract, so the whole
pipeline is IMPORTED from decimate_decor.py rather than copied: geometry(),
weld(), write_glb() and srgb_to_linear() all come from there. Only the source
directory, the subject table and the palette live here. A second copy of the
glTF reader would drift from the first the moment either is fixed, and the
padding rule inside write_glb (JSON padded with spaces, BIN with zeros) is
exactly the kind of hard-won detail that must not exist twice.

decimate_decor.py is deliberately NOT renamed to something family-neutral: it
is referenced by name from docs/MESHY_SPEC.md section 11's decor entry, and
that entry describes a batch that has already shipped. Its name is still true
of what it does.

WHY A HAZARD NEEDS THIS EVEN MORE THAN A DECOR PROP
---------------------------------------------------
Two independent reasons, both measured rather than inherited:

1. TRIANGLES. The six hazard .glb committed 2026-08-11 arrive at 4,000-5,258
   triangles each. MESHY_SPEC 7.1 budgets 1,200 per hazard, and 7.2 already
   measures the frame OVER its 50,000 target before any of them is installed.
   The brief for this batch described the assets as capped at 1,200 triangles;
   they are not, and this script is what closes that gap.

2. COLOUR, WHICH IS NOT OPTIONAL HERE. A decor prop losing its texture was an
   art-direction decision. A hazard losing its texture is a REQUIREMENT:
   MESHY_SPEC section 8 gates each hazard's albedo against the ground at a
   3.0:1 floor, DarkPaletteAudit asserts it, and nothing post-processes the
   frame any more, so the colour a .glb carries is literally the colour that
   ships. A textured, lit, Meshy-authored mossy log cannot have a known
   contrast ratio. Flat + unlit is the only state in which it can.

   The pleasant consequence is that the usual cost of decimation -- losing the
   UVs, and with them the texture -- costs a hazard NOTHING it was allowed to
   keep. This is the opposite of the leafy decor tree, whose character WAS its
   leaf texture and which is therefore still not installable at any budget.

USAGE
-----
    python3 scripts/dev/decimate_hazard.py [target_triangles ...]

Writes /tmp/lod/<kind>_<target>.glb. Nothing is installed automatically:
picking a LOD is a visual decision and installing one is a budget decision,
both of which belong to a human looking at a render.

Requires: numpy, fast-simplification (pip install fast-simplification).
Excluded from the web export, like everything else under scripts/dev/.
"""
import os
import sys

import numpy as np
import fast_simplification

from decimate_decor import geometry, weld, write_glb, srgb_to_linear, WELD_FRACTION

SRC = "assets_source/ennemis"
OUT_DIR = "/tmp/lod"

## Subject -> filename, established by RENDERING each .glb from three axes,
## never by reading its name. The batch's own brief called this one a "mossy
## trunk" and the file is called "Low_Poly_Log"; what settles it is that the
## mesh is 1.901 x 0.534 x 0.608 -- long in X, flat in Y -- i.e. a log LYING
## DOWN across the track, with the moss on its +Y face. The other trunk in the
## batch (Crimson_Hollow_Trunk, 1.031 x 1.901 x 0.992) stands UP and is the
## DODGE subject, not this one. Two files whose names both say "trunk/log"
## are separated here by measurement, which is the rule MESHY_SPEC section 11
## already learned the hard way on the decor batch.
##
## The STOMPER toad was picked the same way, and the measurement is what makes
## it the STOMPER rather than any other hazard: 1.898 x 0.703 x 1.672, i.e.
## WIDE across the track and only 0.70 tall. Obstacle.gd's TELEGRAPH-STOMPER
## says the silhouette must read as a squat, planted landing pad rather than a
## wall -- the placeholder cylinder does it at 1.50 base / 0.70 height, a
## 2.14:1 width-to-height ratio, and this mesh arrives at 2.70:1 unscaled. It
## is the only crouching subject in the batch; the other four stand up.
##
## Its face already points +Z, which is the player's side (segments spawn at
## -Z and travel toward the camera at +Z), so like the JUMP log it needs no
## model_rotation_degrees. Verified by rendering it from +Z and from -Z and
## looking at which end carries the mouth line and the eye bumps -- not by
## assuming Meshy's convention holds across a batch.
##
## The DODGE trunk closes the pair the JUMP entry above opened, and the
## measurement that separates them is the same one: Crimson_Hollow_Trunk is
## 1.031 x 1.901 x 0.992, i.e. the ONLY remaining subject whose dominant axis
## is Y. The other four are long in X or Z (dragonfly 1.901 x 0.960 x 0.170,
## toad 1.898 x 0.703 x 1.672, beaver 1.299 x 1.050 x 1.899, boar 0.831 x
## 1.128 x 1.903). A DODGE is a full-lane-height wall you go AROUND, so
## "stands up" is not a nice-to-have here, it is the whole classification.
##
## Rendered from four views before decimating: an upright hollow trunk, broken
## off at the top, with small branch stubs low on the shaft and a ring-shaped
## cross-section from above. It has no face and is very nearly rotationally
## symmetric about Y, so unlike the toad there is no "which way does it look"
## question to answer -- model_rotation_degrees stays at zero because there is
## no orientation to get wrong, not because the toad's answer was reused.
##
## THE ENEMY IS THE FOURTH FILE IN THIS BATCH WHOSE NAME IS WRONG, and this
## time the name is not merely vague, it names the wrong animal. The file is
## called "Low_Poly_Beaver"; rendered from four axes it is a RAT -- pointed
## snout, small round ears, and a long thin curved tail, where a beaver's tail
## is a flat paddle. The three remaining subjects were rendered together so the
## assignment could be made by elimination as well as by likeness: Shadowtusk
## is a tusked, maned boar (CHARGER) and Emerald_Geometric_Dra is an insect
## whose 1.901 x 0.960 x 0.170 bbox is almost entirely wing (AIR_ENEMY). Only
## one rodent exists in the batch, so ENEMY has exactly one candidate.
##
## Facing was measured, not inherited from the toad: rendered from +Z the
## snout, eyes, ears and front paws are all visible; from -Z there is only the
## rump with the tail sweeping away. Segments spawn at -Z and travel toward the
## camera at +Z, so the rat already faces the player and
## model_rotation_degrees stays at zero.
MODELS = {
    "jump_log": "Meshy_AI_Low_Poly_Log_0811080727_texture.glb",
    "stomper_toad": "Meshy_AI_Geometric_Toad_0811080929_texture.glb",
    "dodge_trunk": "Meshy_AI_Crimson_Hollow_Trunk_0811081732_texture.glb",
    "enemy_rat": "Meshy_AI_Low_Poly_Beaver_0811082534_texture.glb",
}

## Lifted verbatim from Obstacle.tscn's StandardMaterial3D_Jump, NOT sampled
## off the Meshy texture. That value is the one DarkPaletteAudit measures at
## 3.28:1 against the ground; sampling the bark would silently replace a gated
## decision with an arithmetic one, and would move a number this project gates.
## sRGB, as GDScript writes it -- srgb_to_linear handles the conversion glTF's
## baseColorFactor requires (see decimate_decor.py for why that matters).
##
## The STOMPER's blue is the widest-margin gate of the four DarkPaletteAudit
## asserts (3.41:1 against a 3.0 floor after the 2026-08-11 saturation pass),
## so it is carried over UNCHANGED rather than improved: there is nothing to
## win above the floor, and any new value would move a number this project
## gates in exchange for nothing.
## DODGE IS THE ONE ENTRY HERE THAT IS *NOT* A VERBATIM CARRY-OVER, AND THE
## REASON IS STRUCTURAL RATHER THAN AESTHETIC. Every other gated hazard was
## already unshaded when its asset arrived, so lifting its albedo unchanged
## reproduced its measured ratio exactly. DODGE is the only one of the four
## still LIT (StandardMaterial3D_Dodge carries no shading_mode = 0), so its
## 3.19:1 is the ratio of an albedo MULTIPLIED BY THE SCENE'S AMBIENT, not of
## the albedo itself. Section 8 requires an imported asset to be unlit, which
## removes that multiplication -- so carrying (0.30, 0.025, 0.025) across
## unchanged would NOT hold the ratio, it would change what the number means.
## Measured rather than argued: see MESHY_SPEC section 11 for the two-point
## measurement this value was solved from.
## ENEMY IS THE SECOND NON-CARRY-OVER, AND FOR A HARDER REASON THAN DODGE'S.
## DODGE was merely LIT, so unlighting it only removed a multiplication. ENEMY
## is lit AND EMISSIVE, and its emission is not decoration -- it is half of the
## approach telegraph: _apply_enemy_alarm ramps albedo AND emission (from
## energy 0.3 up to ENEMY_ALARM_EMISSION_ENERGY = 1.5). An unshaded material
## ignores emission entirely, so on this asset the telegraph loses a channel
## and the ALBEDO has to carry the whole cue on its own.
##
## That is what fixes the direction of this value. ENEMY_ALARM_ALBEDO
## (0.95, 0.08, 0.12) renders unlit at relative luminance 0.187, and the ground
## renders at 0.150 -- the two are within 1.20:1 of each other. So the alarm can
## only be read against the RESTING colour, and the resting colour has to sit
## far from 0.187. Only one of the two directions works: below it, a dark rat
## that BRIGHTENS into red; above it (a pale purple over luminance 0.55) the
## ramp would be a DARKENING, which is not what an alarm looks like.
##
## Value only, tone held exactly at the shipped 0.52 : 0.08 : 0.72 purple --
## same discipline as DODGE, and purple is ENEMY's type identity against every
## other gameplay hue (Obstacle.gd's TELEGRAPH section). 0.35x is the SHALLOWEST
## darkening that clears the section 8 floor with real margin rather than the
## deepest that clears it at all: every further step down buys margin nobody
## asked for and spends hue legibility on a 0.6m silhouette. Predicted from the
## two-point fog model calibrated on the STOMPER (the only already-unlit hazard,
## hence the only one needing no lighting model) and then MEASURED -- see
## MESHY_SPEC section 11.
COLORS = {
    "jump_log": (1.0, 0.78, 0.28),  # Obstacle.tscn StandardMaterial3D_Jump
    "stomper_toad": (0.62, 0.86, 1.0),  # Obstacle.tscn StandardMaterial3D_Stomper
    "dodge_trunk": (0.21, 0.0175, 0.0175),  # DARKENED from (0.30, 0.025, 0.025), see above
    "enemy_rat": (0.182, 0.028, 0.252),  # 0.35x of (0.52, 0.08, 0.72), see above
}


def main(targets):
    os.makedirs(OUT_DIR, exist_ok=True)
    for kind, filename in MODELS.items():
        verts, faces = geometry(os.path.join(SRC, filename))
        extent = float(np.ptp(verts, axis=0).max())
        welded_verts, welded_faces = weld(verts, faces, extent * WELD_FRACTION)
        size = np.ptp(verts, axis=0)
        print(
            "%-10s source %5d tri -> welded %5d tri   bbox %.3f x %.3f x %.3f"
            % (kind, len(faces), len(welded_faces), size[0], size[1], size[2])
        )
        for target in targets:
            ratio = max(0.0, min(0.999, 1.0 - target / len(welded_faces)))
            out_verts, out_faces = fast_simplification.simplify(welded_verts, welded_faces, ratio)
            out_path = os.path.join(OUT_DIR, "%s_%d.glb" % (kind, target))
            write_glb(out_path, out_verts, out_faces, srgb_to_linear(COLORS[kind]))
            out_size = np.ptp(out_verts, axis=0)
            print(
                "             %4d target -> %4d tri  %6.1f KB  bbox %.3f x %.3f x %.3f"
                % (
                    target,
                    len(out_faces),
                    os.path.getsize(out_path) / 1024.0,
                    out_size[0],
                    out_size[1],
                    out_size[2],
                )
            )


if __name__ == "__main__":
    main([int(a) for a in sys.argv[1:]] or [150, 250, 400, 800])
