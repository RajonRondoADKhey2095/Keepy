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
##
## THE DRAGONFLY IS THE ONLY SUBJECT IN THIS BATCH WHOSE NAME WAS ALREADY
## RIGHT, and it is also the only one where the name was never the question.
## Emerald_Geometric_Dra measures 1.901 x 0.960 x 0.170 -- 11x wider than it
## is thick -- so it is a flat spread-winged insect however it is labelled,
## and AIR_ENEMY is the only flying hazard. Rendered from three axes to
## confirm rather than to identify: four wings spread along X, body along Y
## head-up, and a pierced wing lattice.
##
## Its thin axis is Z, which is the axis the camera looks down, so the mesh
## already presents its full 1.901 x 0.960 spread to the player with no
## rotation at all. model_rotation_degrees stays at zero because the asset
## arrives face-on, not because the previous four answers were reused.
##
## THE BOAR IS THE LAST SUBJECT, AND THE ONLY ONE WHOSE NAME WAS NEVER IN
## DOUBT -- Shadowtusk is a tusked, maned boar, and CHARGER is the only hazard
## left. Its bbox is 0.831 x 1.128 x 1.903, i.e. dominant in Z: long
## nose-to-tail, which is what a hazard that travels AT the player along the
## track wants to be. Rendered from six axes before anything else was decided:
## from +Z the snout, eyes, ears, tusks and front legs are all present; from -Z
## there is only the rump and the tail. The mesh therefore already faces the
## player, and stands upright with +Y up.
##
## THAT DOES NOT MEAN model_rotation_degrees IS ZERO HERE, AND THIS IS THE ONE
## PLACE IN THE BATCH WHERE IT IS NOT -- for a reason that has nothing to do
## with the asset. ChargerMesh is the ONLY slot in Obstacle.tscn carrying a
## rotated transform: Transform3D(1,0,0, 0,0,-1, 0,1,0, 0,0.9,0), a quarter turn
## about X that exists so the PLACEHOLDER PrismMesh's apex leads (the prism
## narrows toward its own +Y, and the slot turns that into world +Z). An
## installed model is a CHILD of the slot, so it inherits that quarter turn: a
## boar that is correct in its own space would be drawn standing on its nose.
## model_rotation_degrees = (-90, 0, 0) cancels it exactly, leaving the net
## rotation identity. The slot's own transform is deliberately NOT changed --
## ModelSlot.gd's model_offset note already carries the general form of that
## argument: correcting the slot instead of the model silently breaks the
## placeholder, which is the state nobody looks at.
MODELS = {
    "jump_log": "Meshy_AI_Low_Poly_Log_0811080727_texture.glb",
    "stomper_toad": "Meshy_AI_Geometric_Toad_0811080929_texture.glb",
    "dodge_trunk": "Meshy_AI_Crimson_Hollow_Trunk_0811081732_texture.glb",
    "enemy_rat": "Meshy_AI_Low_Poly_Beaver_0811082534_texture.glb",
    "air_enemy_dragonfly": "Meshy_AI_Emerald_Geometric_Dra_0811081710_texture.glb",
    "charger_boar": "Meshy_AI_Shadowtusk_0811082449_texture.glb",
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
## The install held tone exactly at the shipped 0.52 : 0.08 : 0.72 purple and
## moved value only, at 0.35x -- the DODGE discipline, and purple was ENEMY's
## type identity in Obstacle.gd's TELEGRAPH table.
##
## THE HUE IS NOW BROWN-GREY, AND ONLY THE HUE MOVED. Device feedback on the
## shipped purple: at real speed it reads as RED rather than as an animal, which
## puts it in the alarm's own colour family -- the one thing a resting colour
## must not do when the alarm is the only other state. The replacement is a warm
## dark brown-grey, the natural fur register.
##
## LUMINANCE IS HELD TO THE PURPLE'S, DELIBERATELY, because the direction
## argument above does not care about hue at all -- it is entirely a statement
## about where the resting luminance has to sit relative to 0.187. Authored
## relative luminance goes 0.01119 (purple) -> 0.01134 (brown), a 1.4% move, so
## the telegraph is preserved by construction rather than by luck: MEASURED
## 3.92:1 -> 3.90:1 shallow and 3.87:1 -> 3.85:1 deep, and resting-vs-ground
## 3.27:1 -> 3.26:1. Changing hue at constant luminance is the ONLY edit here
## that could not have moved those numbers, which is why it was chosen.
##
## HUE 26.4 deg, SATURATION 0.44 -- both bounded from two sides, not picked:
##   * S must stay well clear of 0 or the rat reads as neutral grey and sinks
##     into the trackside props (rock S=0.22, stump/bench/sign S=0.28-0.35).
##   * H must stay clear of STOMPER's ice blue (202 deg -- 176 deg away, near
##     the maximum possible separation) AND of DODGE's near-black red (H~6 deg,
##     S=1.0). DODGE is the close one at ~21 deg of hue, and the separation it
##     rests on is SATURATION (1.0 vs 0.44) plus silhouette (a 2m upright trunk
##     against a 0.6m quadruped), not hue -- measured, see MESHY_SPEC section 11.
##   * Pushing H toward the props' olive (67 deg) to escape DODGE trades one
##     collision for another; 26 deg sits between them.
##
## IT IS A FLAT COLOUR, NOT A PER-FACET VARIATION, and that is a real gap
## against the reference render rather than an oversight. Two reasons, both
## structural: the decimator cannot carry UVs (already documented for the decor
## leafy tree), and vertex colours would MULTIPLY with the alarm ramp's albedo
## write -- turning the one signal that has to read instantly into a mottled
## red. Every contrast number in this project is also computed on a single flat
## albedo; per-facet variation would make "the rat's colour" a distribution.
##
## THE RAT IS NOW A PALE DESATURATED PINK, AND THAT MOVES IT ACROSS THE GROUND'S
## DIVIDING LINE -- read MESHY_SPEC sections 8.4 AND 8.5 before touching this
## value, because every argument written above it was made about a DARK rat and
## three of them expire here.
##
## The value is candidate "03" off docs/color-sheets/charger_colour_sheet.png,
## chosen by Mathieu. It is a CHARGER sheet: every candidate on it is the boar's
## own pink walked toward grey along a FIXED hue, which is why 01/02/03 all print
## the same "hue vs JUMP: 55.8 deg". Read two independent ways before use -- the
## printed annotation says raw rgb(245, 229, 233) and a pixel histogram of the 03
## swatch returns (245, 229, 233) at 97.7% dominance. sRGB 8-bit / 255 to 4 dp is
## (0.9608, 0.8980, 0.9137), which round-trips back to (245, 229, 233) exactly.
##
##   * BAND. Rendered luminance goes 0.0110 -> ~0.79. Section 8.4(1) says the
##     ground at 0.150 splits the palette in two and NOTHING clears 3.0:1 from
##     between; the rat leaves the DARK band (with DODGE) and joins the BRIGHT
##     one (JUMP, STOMPER, CHARGER), which becomes FOUR-strong. It clears the
##     ground floor with the widest margin of any hazard -- that gate was never
##     the risk here.
##   * HUE, AND THIS IS THE REAL COST. Section 8.4(2): inside a band WCAG scores
##     ~1:1 and hue is the only channel left. This colour is the CHARGER's own
##     hue, so the pair the player must never confuse -- the only FATAL hazard
##     and a half-strike rodent -- ends up hue-adjacent in the same band. It is
##     measured, reported in full rather than smoothed over, and it is why the
##     lot below carries a warning instead of a clean bill.
##   * WHAT IT DOES *NOT* CHANGE, and this is the third time it needs saying:
##     section 8.4(3) shows the alarm ramp has left the resting family 4.40 s
##     before contact, i.e. with the rat 5-11 px tall. This is an identity-at-
##     rest edit, NOT a fix for "the rat looks red" -- the red is the telegraph
##     working, and no resting colour can change what is seen at the decision
##     distance.
##
## LUMINANCE IS NO LONGER HELD, AND THE TELEGRAPH INVERTS BECAUSE OF IT. The
## direction argument that fixed the purple and survived the brown -- rest BELOW
## the alarm's 0.187 so the ramp BRIGHTENS -- is broken by this value, which
## rests far ABOVE it. The ramp is now a large DARKENING plus a hue swing, which
## is exactly the shape AIR_ENEMY already has (it rests at 0.71 against the same
## alarm). So the cue is not lost, it changes sign -- measured 3.92:1 -> 3.50:1,
## section 8.5. That inversion is a consequence of the colour, not a decision.
## AIR_ENEMY IS THE THIRD NON-CARRY-OVER, AND THE ONLY ONE WHERE THE SHIPPED
## ALBEDO IS NOT EVEN CLOSE TO WHAT THE PLAYER SEES. DODGE lost a
## multiplication when it went unlit; ENEMY lost an emission channel worth
## energy 0.3. AIR_ENEMY is the only hazard that is LIT *and* emissive at
## energy 1.1, so it loses both terms at once, and the additive one dominates.
##
## Measured, not modelled (AirEnemyTelegraphProbe, a throwaway probe built on
## DarkPaletteAudit's scene and sampling): the resting torus renders
## rgb(0.2414, 1.0000, 0.3139) on screen -- GREEN CLIPPED AT 1.0 -- from an
## authored albedo of (0.12, 0.85, 0.22). Its rendered luminance is 0.731.
## Carried across unchanged, that albedo would render unlit at ~0.50: the
## install would visibly DARKEN a hazard nobody asked to darken, and would
## narrow the telegraph in the process.
##
## So the value is solved against the RENDERED resting colour rather than the
## authored one -- the DODGE discipline applied to a two-term problem. Hue is
## held: green is AIR_ENEMY's type identity in Obstacle.gd's TELEGRAPH table,
## and only its value moves, to the place the player is already looking at.
##
## The direction of the ramp INVERTS relative to ENEMY, and that is correct
## rather than an oversight. ENEMY had to be darkened so its alarm could
## BRIGHTEN into red, because a dark rodent sat near the alarm's own
## luminance. AIR_ENEMY rests at 0.731 against an alarm that renders 0.187
## unlit, so its ramp is a large DARKENING plus a ~117 degree hue swing --
## the two channels agree, and the cue is wider after the install than
## before it (measured: 2.59:1 before, see MESHY_SPEC section 11).
## CHARGER GOES BACK TO BEING A VERBATIM CARRY-OVER, and the reason is the same
## structural one that made DODGE, ENEMY and AIR_ENEMY exceptions -- read the
## other way round. Those three had to be re-solved because their placeholders
## were LIT (DODGE), lit and emissive at energy 0.3 (ENEMY), or lit and emissive
## at energy 1.1 (AIR_ENEMY), so their authored albedo was not what the player
## saw and going unlit changed the render. StandardMaterial3D_Charger already
## carries shading_mode = 0 and no emission at all, exactly like JUMP and
## STOMPER: there is no multiplication and no additive term to lose, so the
## value below renders to the same pixels it renders to today.
##
## That matters more here than anywhere else in the batch. CHARGER is the only
## FATAL hazard, and at 3.20:1 it holds the NARROWEST margin of the four gated
## contrasts (DODGE 3.37, JUMP 3.02 -- itself a documented window artefact,
## STOMPER 3.41). Re-solving a colour that is already correct would move a
## number this project gates, on the one hazard where being wrong ends the run,
## in exchange for nothing -- the STOMPER's argument, and it applies with more
## force here. The hue is also not free to move even if the ratio were: the
## TELEGRAPH block in Obstacle.gd picks magenta precisely because every other
## hue in the game is taken, and names the five it would collide with.
##
## THE COLOUR HAS SINCE MOVED ANYWAY, AND THE PARAGRAPH ABOVE IS STILL TRUE --
## it is an argument about SHADING, not about art. Nothing had to be re-solved
## for the unlit switch, because there was no multiplication and no additive
## term to lose; what changed is a separate, purely artistic decision to take
## the boar off the hot pink and onto a dusty pink-brown, (0.96, 0.76, 0.80).
##
## Being free to move it is not the same as being free to move it far, and the
## two constraints that bound it are the ones the paragraph above names:
##   * VALUE. The ground renders at relative luminance 0.150, so clearing the
##     3.0:1 floor from above needs >= 0.549 (MESHY_SPEC section 8). The new
##     colour renders at 0.604 against the old 0.590 -- it does not spend the
##     margin, it widens it slightly, 3.21:1 -> 3.28:1. Anything in the dusty
##     register that dropped toward mid-value would fail outright, whatever
##     its hue, and that is what makes this a narrow corridor rather than a
##     free choice.
##   * HUE. Rendered hue moves 325.4 deg -> 348.2 deg, i.e. toward red, which
##     is where DODGE and the rat live -- but both of those are near-black, so
##     the pair is separated by VALUE and comfortably: 11.1:1 against DODGE and
##     10.7:1 against the resting rat, both measured, both up from the shipped
##     10.9 / 10.5. The hue that could actually collide is JUMP's amber (43.6
##     deg), the only other bright object, and the gap there is 55.5 deg.
## THE RAT LEAVES CHARGER'S OWN HUE, AND THIS IS THE FIFTH RECOLOUR OF ITS
## RESTING STATE -- the fourth (pale pink, immediately above) was the sheet's
## own CHARGER candidate walked toward grey, so it inherited CHARGER's hue by
## construction and collided with it (1.27:1, 1.2 deg -- see MESHY_SPEC 8.5).
## The replacement comes from an INDEPENDENT recon that never touches
## CHARGER's palette: EnemyEarthtoneAxisSheet.gd
## (scripts/dev/, branch claude/enemy-earthtone-axis-qnlzo5), which explores
## the BRIGHT band (the only one open, per 8.4(1)) at a REAL saturation
## (S ~ 0.15-0.25) rather than the near-neutral grey the previous axis had
## already closed.
##
## Candidate B1 -- "Kaki pale (olive-vert)" -- entered as HSV
## H=105.0 deg, S=0.22, V=0.88 (Color.from_hsv(105.0/360.0, 0.22, 0.88, 1.0)
## in the sheet script, never a hand-typed RGB literal). Converted here the
## same way, not re-derived by eye: RGB = (0.7348, 0.88, 0.6864). This is the
## INPUT value fed to albedo_color, not the sheet's RENDERED-measurement
## columns (H=105.0 deg S=0.219 chroma8=48.0 Lrel=0.63671, 3.49:1 vs ground) --
## the two differ because the sheet's Lrel/contrast are read off the actual
## screen pixel (AA, box-sampling), while the .glb's baseColorFactor has to
## carry the value the material was actually given.
##
##   * BAND. Stays BRIGHT (with JUMP, STOMPER, CHARGER) -- the sheet measured
##     3.49:1 against the 3.05 safe-margin floor, well clear.
##   * HUE, the axis the previous two rat colours both failed on. Separation
##     from all four gated hazards, measured on the sheet's own reference
##     rows rather than assumed: dHue(CHARGER)=117.0, dHue(JUMP)=61.4,
##     dHue(STOMPER)=97.3, dHue(DODGE)=99.2 -- every one clears the 45 deg
##     reliability floor with margin, and the CHARGER pair specifically (the
##     one collision that mattered) goes from 1.2 deg to 117.0.
##   * WHAT THIS BUYS AND WHAT IT DOES NOT. B1 is measurably separated from
##     CHARGER on BOTH WCAG channels the sheet checks (hue and, inside the
##     bright band, the direct pairwise ratio) rather than on saturation
##     alone, which is what made the pink candidate fragile. It reads as a
##     pale sage/olive-green, not a dark earth tone -- the bright band forces
##     high V (see the sheet's own header: clearing the ground floor from
##     above needs Lrel >= ~0.549, which pushes every bright candidate toward
##     pastel). No sonde measures whether that still reads as "a rat" instead
##     of "a pale green shape" at real speed; that is a device judgement, not
##     a gate this value can pass on its own.
COLORS = {
    "jump_log": (1.0, 0.78, 0.28),  # Obstacle.tscn StandardMaterial3D_Jump
    "stomper_toad": (0.62, 0.86, 1.0),  # Obstacle.tscn StandardMaterial3D_Stomper
    "dodge_trunk": (0.21, 0.0175, 0.0175),  # DARKENED from (0.30, 0.025, 0.025), see above
    "enemy_rat": (0.7348, 0.88, 0.6864),  # pale kaki/sage, earthtone-axis candidate B1, see above
    "air_enemy_dragonfly": (0.24, 1.0, 0.31),  # the RENDERED resting green, see above
    "charger_boar": (0.96, 0.76, 0.80),  # dusty pink-brown, RECOLOURED from the shipped pink, see above
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
