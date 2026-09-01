extends Control
class_name CabinInterior
## Inside the tree-house: two walkable levels, one ladder, and the .glb as
## a fixed backdrop.
##
## =====================================================================
## THE BRIEF'S PREMISE WAS WRONG, AND MEASURING IT IS WHAT MADE THIS LOT
## POSSIBLE
##
## It said the furnished interior is "une TEXTURE PEINTE sur la coque, pas
## une geometrie creuse", and that therefore "AUCUNE mesure de vertex ne
## peut donner ou est le sol reel -- ca n'existe pas comme donnee".
##
## It does exist as data. keepy_cabin_decor.glb is one mesh of 12 990
## vertices / 7 262 triangles, and it is genuinely HOLLOWED OUT: a depth
## map looking along -Z finds the middle band of the front face sitting at
## z = -0.20 model units while the shell around it sits at +0.18, a recess
## about 0.4 model units deep. Casting rays down INSIDE that recess finds
## a flat floor at model y = -0.5305 that is consistent to three decimals
## across the whole room (-0.532, -0.529, -0.528, -0.530, -0.529...), a
## slab whose top is at -0.115, and a ceiling at +0.106.
##
## So the floors below are MEASURED off the mesh, not eyeballed against a
## reference render, and the render was used to CONFIRM them rather than to
## find them. They were right the first time -- see the batch report.
##
## =====================================================================
## ⚠️ BUT THE LEVELS ARE STILL INVISIBLE PLANES, AND THE MESH IS STILL A
## BACKDROP
##
## Which is the brief's design, arrived at from the other end. The measured
## surfaces are not COLLISION -- nothing in this project has any -- and
## they are not flat everywhere. An exhaustive search over every height in
## the model for the largest axis-aligned square whose surface stays within
## +-0.18 world units of one plane finds:
##
##   y ~ 1.75-2.00   half_extent 1.00   <- the ground floor
##   y ~ 10.50       half_extent 0.60   <- branch tops, up in the canopy
##   y ~ 11.00       half_extent 0.40   <- canopy again
##
## and NOTHING else above 0.4. On the loft the largest strictly-flat patch
## is 0.5 x 0.5 world units, against a Keepy who is 1.32 wide and 2.04
## deep. Read as collision, this asset has one floor and no mezzanine.
##
## Read as a BACKDROP -- which is what it is -- the loft is a drawn wooden
## deck spanning the back of the room, and an invisible plane at its
## dominant height puts Keepy on it. Where the drawing has a shelf or a bed
## a few centimetres off that plane, he passes over it exactly as he passes
## through a tree on the plateau, which is this project's settled rule:
## nothing out there blocks an approach either.
##
## =====================================================================
## ⚠️ THE CAMERA IS FIXED, AND LevelCamera IS DELIBERATELY NOT USED
##
## Three reasons, in the order that decides it. Only the first is taste.
##
## 1. A diorama is meant to be seen whole. Both storeys are in frame at
##    once, which is how the model was drawn and how the reference render
##    reads.
##
## 2. THE CAVITY OPENS ON ONE SIDE ONLY. Rendered on four axes: from +Z the
##    trunk is hollowed and furnished, from -Z it is a closed trunk with no
##    opening at all. A camera that follows the walker in XZ can be carried
##    round to where there is nothing to see.
##
## 3. ⚠️ AND THE DECIDING ONE, MEASURED: LevelCamera's occlusion test
##    cannot work on this asset. It fades any node in the `level_occluder`
##    group whose WORLD AABB the camera-to-walker segment crosses. The
##    cabin is ONE mesh, so its AABB is the whole building -- at this scale
##    x[-10.43, 10.40] y[0, 17.49] z[-8.42, 8.59] -- and the walker stands
##    INSIDE it on both levels. A segment that ENDS inside a box always
##    intersects that box, so the test would report "blocking" on every
##    frame from every camera position, and the entire cabin would sit at
##    alpha 0.25 for the whole visit.
##
##    That is why nothing here joins `level_occluder`. It is not an
##    oversight and it must not be "fixed" by adding the cabin to the
##    group: the group is for geometry that can stand BETWEEN the camera
##    and the walker, and a room the walker is inside cannot.
##
## LevelCamera itself is NOT modified. LevelController only asks for a
## Camera3D, and a plain one satisfies it.
##
## =====================================================================
## WHY NAVIGATION IS FREE XZ AND NOT CONSTRAINED TO AN AXIS
##
## The brief asked for that decision to be taken out loud. It offered a
## corridor -- movement along the visible width only -- on the grounds that
## the painted Z depth "ne correspond a aucune vraie profondeur 3D".
##
## It does. The ground floor's measured footprint at this scale is about
## 3.5 wide by 5.5 deep, which is depth Keepy can actually use, so the
## ground level is a free XZ square and needs no special case.
##
## The LOFT is the constrained one, and it is constrained by MEASUREMENT
## rather than by rule: its deck is about 3.6 wide and 2.0 deep, so the
## largest square that fits is what makes it feel like a gallery you walk
## ALONG. That falls out of half_extent; no second navigation mode exists.

const CABIN := preload("res://assets/models/keepy_cabin_decor.glb")
const KEEPY := preload("res://assets/models/keepy_squirrel_hero.glb")
const HUB_SCENE := "res://scenes/HubWorld.tscn"

## Scale the .glb is drawn at INSIDE this scene.
##
## NOT the plateau's 7.0, and the difference is the one number this scene
## is free to choose: out there the cabin is a landmark among trees, in
## here it is the room. Chosen by rendering 7 / 11 / 14 / 18 side by side
## with Keepy standing on the measured floor in each:
##
##   7   the whole tree fits the frame -- canopy, mound, lawn. You are
##       looking AT a tree-house, not standing in one, and the room is a
##       small part of the picture.
##   11  the room fills the frame, both storeys read, the round window and
##       the fireplace are legible.  <- this one
##   14  closer, and the loft starts to crop at the top.
##   18  too close: the loft and the window are gone.
##
## Everything below scales with it, so this constant is the only thing to
## change if that judgement is revisited on a device.
const CABIN_SCALE: float = 11.0

## Lifts the model so its lowest point sits at y = 0, exactly as
## HubBuilder.CABIN_MODEL_OFFSET does on the plateau. Measured off the
## shipped .glb's POSITION accessor (min.y = -0.800420) rather than assumed
## from the model being centred -- the origin of a .glb is wherever its
## author left it.
const CABIN_MODEL_OFFSET_Y: float = 0.800420

## =====================================================================
## THE TWO FLOORS, IN MODEL UNITS
##
## Stated in the model's OWN space and multiplied by CABIN_SCALE below, so
## that changing the scale moves the floors with the drawing instead of
## leaving them behind. A world-space literal here would be a second,
## silent copy of the scale.

## The ground floor. The flattest thing in the model: 117 sampled cells
## agreed to a standard deviation of 0.0175 model units (0.12 world at this
## scale), which is well under the 0.6 arc of a single hop.
const FLOOR_MODEL_Y: float = -0.5305

## The loft deck's top face, measured the same way (-0.112 / -0.115 / -0.139
## across the columns that have one).
const LOFT_MODEL_Y: float = -0.1150

## =====================================================================
## THE TWO WALKABLE SQUARES, IN WORLD UNITS AT CABIN_SCALE
##
## Sized off the measured extent of each drawn surface, then confirmed on a
## render with Keepy standing at the centre and at the corners of each.

const FLOOR_CENTRE := Vector2(0.60, 0.00)
const FLOOR_HALF_EXTENT: float = 1.70

const LOFT_CENTRE := Vector2(-0.70, -1.32)
const LOFT_HALF_EXTENT: float = 1.10

## The ladder, as the layout of the drawing has it: up the right-hand side
## of the room, past the fireplace, onto the right end of the loft.
const LADDER_FOOT := Vector2(2.05, -1.45)
const LADDER_TOP := Vector2(0.25, -1.30)
## How close an AIM has to land to mean the ladder. World units, like every
## other prop radius in this project, so the target does not shrink with
## distance the way a pixel one would.
const LADDER_TAP_RADIUS: float = 1.10

## Where Keepy starts a visit: just inside the door, at the front of the
## ground floor, facing into the room.
const ENTRY_SPOT := Vector2(0.60, 1.35)

## =====================================================================
## THE TAPPABLE SPOTS THAT ARE NOT THE LADDER
##
## ⚠️ DOOR_SPOT IS NO LONGER ENTRY_SPOT -- device report: the exit hotspot
## and the kiss shared the same corner of the room, so "Sortir" read on top
## of the bisou and a re-shove tap near the magpie could resolve as leaving.
## Mathieu's call, explicit: relocate the HOTSPOT itself (tap AND snap
## destination), not just its label -- the label-offset fix from a prior
## lot was a symptom patch on the wrong side of the same corner and is gone
## now that the corner itself has moved.
##
## ⚠️ RELOCATED A SECOND TIME, THIS LOT, ON A DIFFERENT CLARIFICATION.
## (2.20, 0.65) fixed the kiss-corner overlap but device read it as "at the
## foot of the ladder" -- true by construction, it was chosen as the
## closest-to-the-ladder point that cleared every gate. Mathieu's later,
## explicit wording supersedes that framing outright: "between the coffee
## table and the staircase", not at the base of either. That phrase is
## measured here, not eyeballed -- projected through the REAL fixed camera
## (`unproject_position`, run WITHOUT --headless, which under this project's
## own already-documented pitfall reports the wrong viewport size for this
## exact call) against the same landmarks a player sees: the table
## (ENTRY_SPOT) screens at x = 52.8%, the ladder's foot at x = 63.7%.
## (1.30, 1.50) screens at x = 59.5%, close to the midpoint of the two
## (58.25%) and visibly inside that band rather than pinned to either edge.
##
## A naive geometric middle of the room FAILS outright: the ladder link's
## own exclusion disc (radius 1.950 around LADDER_FOOT) is large relative
## to this room, so every candidate an eyeballed "midway" search tried
## first -- x in [1.20, 1.80] at the depth halfway between table and
## ladder -- came back FAIL on that one gate (best case 1.946 against the
## required 1.950). The true legal frontier was mapped by exhaustive scan
## rather than guessed at, and (1.30, 1.50) sits on the table's side of it,
## verified against the real LevelDefinition/LevelHotspot/LevelTransition
## objects this file itself builds (jettable probe, same constructor calls,
## never hand-rolled circle/rectangle arithmetic):
##   - clear of the ladder LINK's own tap circle: gap 3.044 against a
##     radii-sum of 1.950 (+1.094) -- comfortably past the old fix's own
##     +0.155 margin, because the frontier at this table-side x needs a
##     higher z than the ladder-side candidate did.
##   - inside the floor square: LevelDefinition.contains() = true.
##   - the loft's own square cannot reach it: its nearest point is 1.941
##     from here against a DOOR_REACH of 0.9.
##   - clear of the magpie's own hotspot circle and of her footprint hole
##     by a wide margin (2.474 against a 0.73 + 0.85 minimum).
##   - clear of the RELOCATED MAGPIE_STAND_SPOT (see its own comment, this
##     same lot) by 1.208 against a 1.05 minimum.
##   - clear of the bed's circle on the loft by 4.096 against a 1.550
##     minimum -- never close, checked anyway because it is cheap.
const DOOR_SPOT := Vector2(1.30, 1.50)
## Smaller than the ladder's 1.10. See LevelHotspot's header for why a
## generous circle is harmless on the AIM and would have been a funnel on a
## clamped point.
const DOOR_TAP_RADIUS: float = 0.85

## The bed, on the loft. BED_SPOT is where it is actually DRAWN -- its
## ground position, used for the marker and for where Keepy is sent to lie
## down. It is NOT where the hit-test circle is centred; see
## BED_TAP_ANCHOR below for why those two had to split.
const BED_SPOT := Vector2(-1.67, -1.32)

## ⚠️ THE SAME BUG THE MAGPIE HAD, FOUND BY THE SAME METHOD -- swept, not
## assumed. LevelController.resolve() always raycasts against the loft's
## FLAT plane, never the drawn mesh, so a tap that visually lands on a
## raised prop resolves to a ground point that drifts away from the prop
## as the camera's parallax stretches with height. The magpie's fix
## doesn't imply the bed has the same symptom on its own -- it was swept
## the same way (0%/10%/.../100% of the bed's own measured drawn-surface
## range, 6.5522-7.5952, run through the exact resolve() arithmetic) to
## find out.
##
## The sweep alone overstates the bug, though, and cross-referencing it
## against actual camera-to-point OCCLUSION (Möller–Trumbore against the
## shipped .glb, not eyeballed off a screenshot) narrows it to what a
## player can actually see and mis-tap:
##   0%            -- occluded (nothing to mis-tap; irrelevant)
##   10%, 20%       -- VISIBLE, and REJECTED by the shipped 0.70 circle
##   30%, 40%, 50%  -- occluded (irrelevant)
##   60%, 70%, 80%  -- VISIBLE, and REJECTED by the shipped 0.70 circle
##   90%, 100%      -- VISIBLE, and already ACCEPTED
##
## So the real, player-facing bug is the visible-but-rejected 10-20% and
## 60-80% bands, not "everything below 90%" the raw sweep would suggest.
##
## ⚠️ WIDENING BED_TAP_RADIUS ALONE CANNOT FIX EITHER BAND -- proven, not
## assumed. The shipped 0.70 was already ladder-clearance-forced (see the
## old comment this replaced: gap 1.920 against radii summing to 1.80,
## i.e. margin 0.120). Re-deriving the WIDEST circle the ladder allows
## around BED_SPOT itself (ladder_ceiling 0.8201, minus the same 0.20
## safety margin MAGPIE_TAP_ANCHOR's own fix used) gives radius 0.6201 --
## SMALLER than what shipped, because BED_SPOT sits close enough to the
## ladder that little room is left to grow into. Recentring is not a
## stylistic echo of the magpie's fix, it is the only axis this bed has.
##
## BED_TAP_ANCHOR is picked at the natural MIDPOINT of the measured height
## range (50%), mirroring exactly how MAGPIE_TAP_ANCHOR was derived --
## not a numerically search-optimised point. BED_TAP_RADIUS is then taken
## up to the ladder's clearance ceiling from THAT anchor (1.9519), minus
## the same 0.20 safety margin, landing on 1.75.
##
## Together they cover fraction range [7.3%, 81.2%] -- both real
## visible-and-broken bands, 10-20% and 60-80%. ⚠️ AND THIS COSTS THE
## 90-100% BAND, HONESTLY, NOT SILENTLY: no anchor/radius pair clears the
## ladder circle AND covers both ends at once (checked exhaustively, not
## assumed) -- preserving 90/100% tops out at fraction 80.2%, missing the
## larger 60-80% band entirely. 90-100% is the narrow tip of the book
## stack; 60-80% is the wider, more central part of the bed a player is
## more likely to actually aim at. That's the trade taken here, on
## purpose, and it's the one honest limit of this fix: after it, tapping
## the very peak of the pile no longer registers as "the bed."
##
## Sanity-checked against swallowing ordinary floor taps: the new anchor
## sits 2.681 from BED_SPOT and 2.719 from LOFT_CENTRE, both outside the
## 1.75 radius -- an everyday "just walk here" tap near the bed's own
## ground position or the loft's centre is unaffected by this circle.
const BED_TAP_ANCHOR := Vector2(-1.291703, 1.333841)
const BED_TAP_RADIUS: float = 1.75

## The ring drawn for the bed keeps the OLD 0.70 -- it was never reported
## as visually wrong, only the hit-test circle was blind. Drawn at
## BED_SPOT, the bed's real ground position, same as before this fix.
const BED_MARKER_RADIUS: float = 0.70

## =====================================================================
## THE BED'S OWN DRAWN SURFACE, AND WHY IT IS NOT THE LOFT PLANE
##
## ⚠️ THE FIRST THING MEASURING FOUND IS THAT THE LOFT *IS* THE BED. The
## mezzanine's drawn top face and the teal duvet painted across it are the
## same surface -- ray-casting down the model over the loft's walkable
## square finds one plateau at 7.52-7.59 world units and no separate
## mattress anywhere inside it. So "lay him on the bed" and "lay him on
## the mezzanine floor" would have been the same instruction over most of
## that square, and the brief's warning against the second could not be
## obeyed by finding a higher one: there ISN'T a higher one you can stand
## on.
##
## What there IS, and what this constant is: right under the marker the
## drawn bedding DIPS. Sampling the model beneath the marker's own centre
## -- a 0.25-radius disc, about the width his body presents to the bed --
## the drawn surface runs 6.91 to 7.60 with a median of 7.3686, which is
## 0.1710 BELOW the walking plane. That hollow is the gap between the
## bed's front rail and the duvet behind it.
##
## So lying at the plane leaves him resting on bedding that is not under
## him. Lying at the MEDIAN of what IS under him puts him in it.
##
## ⚠️ AND THE RENDER PICKED THE SAME NUMBER INDEPENDENTLY. Six candidate
## depths were rendered through the shipped camera (0.00 / 0.12 / 0.18 /
## 0.25 below the plane, at three yaws); 0.18 read best -- 0.25 put the
## bed's front rail across his chin, 0.00 left him sitting on top of the
## frame. The measurement says 0.1710. Two roads, one centimetre apart.
##
## Stated in MODEL units and multiplied by CABIN_SCALE through _world_y(),
## exactly as the two floors are: a world literal here would be a second
## silent copy of the scale.
const BED_MODEL_Y: float = -0.13055

## =====================================================================
## THE LYING POSE ITSELF
##
## ⚠️ HE IS ROLLED ONTO HIS SIDE, NOT TIPPED ONTO HIS BACK, AND THAT IS
## FORCED BY THE MESH RATHER THAN CHOSEN. Keepy is modelled SITTING with
## a tail that curls up behind him: measured off the shipped .glb his
## nose-to-tail depth is 2.0371 world units against a height of 1.3501 and
## a width of 1.3198. Tipping him back 90 degrees about X swaps his DEPTH
## into the vertical -- so a two-metre axis stands up out of a bed whose
## drawn bedding is a fifth of that. It was rendered rather than argued:
## the result is a tail sticking out of the duvet with the body buried
## under it, and nothing that reads as a squirrel.
##
## Rolling about his own forward axis swaps his WIDTH into the vertical
## instead -- 1.32, half of it below the origin -- and leaves the long
## axis lying along the bed where it belongs. He ends up on his side,
## facing the room, tail curled over him.
##
## ⚠️ NO ANIMATION, AND NONE IS POSSIBLE. The .glb carries one node, one
## mesh, no skin and no animation -- the same finding the owl batch
## published for the same family of assets. Every pose in this project is
## a transform on the whole body, and this is one more.
const REST_ROLL_DEGREES: float = 90.0

## Which way he faces while he lies there.
##
## The bed's long axis runs along world X with the pillow at -X: read off
## a render with world-space markers dropped on it, not guessed from the
## layout. A roll of +90 already lays his head toward -X with the walker
## unturned, so this yaw is not what points him at the pillow -- it is a
## three-quarter turn towards the camera, so the face and the tail both
## read instead of a flat profile. Rendered at 0 / 5 / 20 / 35; 20 is
## where he stops looking like a decal and starts looking curled up.
const REST_YAW_DEGREES: float = 20.0

## Lowest point of the shipped Keepy .glb along its OWN X, read off the
## POSITION accessor like KEEPY_MODEL_MIN_Y beside it: -0.616405 against
## max.x = +0.612863, so he is not centred there either.
##
## It is X and not Y because the roll above puts his X axis vertical. The
## lift while lying is therefore this number, not the standing one, and
## using the standing one would bury his flank by the difference.
const KEEPY_MODEL_MIN_X: float = -0.616405

## =====================================================================
## THE MAGPIE, AND THE ONE THING SHE DOES DIFFERENTLY FROM THE DOOR AND
## THE BED
##
## A bird standing on the living-room floor. Tap her and Keepy walks to a
## FIXED spot in front of her, leans in for a kiss, and a few hearts rise.
## Repeatable for as long as anyone wants: no cooldown, no counter, nothing
## remembered between kisses.
##
## ⚠️ SHE IS THE FIRST HOTSPOT WHOSE DESTINATION IS NOT THE TAP.
##
## The door and the bed both pass LevelController's `destination` -- the
## CLAMPED point the finger landed on -- straight to hop_to(). That is right
## for them: a doorway and a bed are places you walk ONTO, so wherever inside
## their circle you aimed is where you meant to stand.
##
## A bird is not. You do not walk onto her; you walk UP TO her, and there is
## exactly one place to stand where a kiss reads. So this branch DISCARDS
## `destination` and walks to MAGPIE_STAND_SPOT instead.
##
## That is the AIM/destination separation this project already carries, used
## for the first time in the direction it was always going to be needed:
## the AIM decides WHAT was meant, and what was meant here is a place this
## file chooses rather than one the finger picked. Reading the stand spot off
## the tap would put Keepy wherever in a 0.60 circle the thumb happened to
## land, kissing the air from the far side of her as often as not.

const MAGPIE := preload("res://assets/models/keepy_magpie_prop.glb")

## Where she stands, on the ground floor.
##
## MEASURED rather than eyeballed, and RE-MEASURED after the first render
## put her behind Keepy. Ray-casting down the cabin mesh finds the front band
## (z >= 0.3) flat to within 0.06 world units of the floor plane, everything
## at z <= -0.34 occupied by drawn furniture standing 3.3 to 4.3 above it,
## and -- sweeping further left than the walkable square goes -- the plank
## floor continuing flat out to x = -1.6 before the wall starts to climb at
## -1.8. She stands in that margin.
##
## ⚠️ SHE IS DELIBERATELY OUTSIDE THE WALKABLE SQUARE (x >= -1.10), which is
## not a mistake: that square is Keepy's, shrunk by his own half-width so a
## destination never puts his body through a wall. A prop has no such
## constraint, and putting her inside it would have cost the one thing the
## first render proved matters.
##
## ⚠️ AND WHAT THE FIRST RENDER PROVED: SHE AND KEEPY MUST NOT SHARE A LINE
## OF SIGHT. Placed at (-0.80, 0.30) with the stand spot at (-0.35, 1.05),
## Keepy stood BETWEEN her and the camera -- this camera is fixed at
## (0.3, 9.5, 12.5) looking down -Z, so larger z is nearer -- and a 1.35-tall
## squirrel in front of a 0.88-tall bird hid all but a sliver of her. The
## capture is what found it; no constant said anything was wrong.
##
## So she is now the NEARER of the two and he is behind and to the right:
## she is smaller, so she cannot hide him, and he is offset in x, so he
## cannot hide her.
const MAGPIE_SPOT := Vector2(-1.10, 0.90)

## THE FIXED SPOT KEEPY SNAPS TO. Inside the walkable square, on measured-flat
## floor, 2.159 from her and further from the camera than she is.
##
## ⚠️ THE OLD 1.254 GAP WAS STALE, AND THIS IS THE FIX RATHER THAN A NEW
## GUESS. It was sized off both bodies at the FIRST MAGPIE_SCALE (0.50); a
## later lot raised MAGPIE_SCALE to 0.76461 to match Keepy's own drawn
## height, her half-depth grew with her, and nobody re-tuned the distance --
## the codebase's own prior comment named this as an open risk in exactly
## these words: "whether the bigger bird's resting contact still reads as a
## kiss and not an already-buried muzzle is open." Device confirmed it does
## not: he buried her head at rest.
##
## MEASURED, not eyeballed -- a jettable probe built the real transform
## chain _build_magpie()/_enter_kiss()/_apply_kiss() use (her scaled AABB,
## his lean bell curve sampled across the whole 0..1 sweep, not just the
## peak) and computed the actual world-space XZ overlap of their two
## silhouettes as a fraction of her own footprint area:
##   at the shipped (0.05, 0.40): REST 41.7% of her already overlapped,
##   PEAK (mid-lean) 62.7% -- her head was gone.
##   at (1.00, 0.40): REST 0.0% (they read as two separate bodies at
##   rest), PEAK 10.6% -- a small, deliberate touch during the gesture
##   itself and nothing before or after it, which is what the original
##   0.18-unit "muzzle overlap... which for a kiss was the point" was
##   always going for.
##
## ⚠️ THE FIX MOVES ALONG +X, NOT +Z, AND THAT IS NOT ARBITRARY: the
## MAGPIE_SPOT comment above already explains that x is the axis this
## design uses to keep the two bodies from hiding each other on the fixed
## camera (he is "offset in x, so he cannot hide her"), while z is the
## camera's OWN depth axis, carefully tuned so she stays nearer the lens
## than he is. Sweeping candidates confirmed this: moving along x shrinks
## the overlap far faster per unit of distance than moving along z, AND
## keeps her drawn facing angle in the flattering three-quarter view the
## original yaw-from-stand-spot design intended. Z is left untouched at
## 0.40, so the near/far ordering against the camera is exactly the one
## MAGPIE_SPOT's own comment already argued for.
##
## ⚠️ RE-TUNED A SECOND TIME, DEVICE FEEDBACK IN THE OTHER DIRECTION: the
## first fix (x = 1.00) closed the overlap bug but overcorrected it --
## REST read 0.0%, PEAK only 10.6%, and on a phone the two bodies read as
## standing side by side rather than kissing. x = 0.80 shipped next,
## measured on her WHOLE-BODY silhouette at REST 4.8% / PEAK 19.8% --
## "roughly double the shipped contact" -- 5.2 points under a 25% ceiling
## on that same whole-body figure.
##
## ⚠️ DEVICE FOUND THAT FIX INVISIBLE TOO, AND A THIRD PASS FOUND WHY: THE
## 25% CEILING WAS GATING THE WRONG SILHOUETTE. Body/tail/wing overlap can
## climb for reasons that have nothing to do with whether a KISS reads --
## her tail is nowhere near her face -- and a jettable probe
## (`KissHeadZoneSweep.gd`, deleted before commit, renders kept under
## docs/hub-shots/kiss_sweep_x*.png) measured her actual HEAD zone instead:
## the small blob at the top of her model (model-space y > 0.708, ray-cast
## off the raw glTF vertex buffer, not the importer's box) that reads as
## face/beak/eyes rather than plumage.
##
## Re-measured on THAT zone, at the shipped 0.80: REST 0.0% (clean, as
## expected) but PEAK 0.0% TOO -- his muzzle never once reached her face
## across the whole lean, which is what "roughly double the shipped
## contact" was hiding: the extra overlap was all body-against-body,
## nothing new against her face. That single number explains a device
## report of "no perceptible difference" better than any percentage would.
##
## THE OLD "WALL" BETWEEN x = 0.70 (24.6%) AND x = 0.65 (27.0%) WAS REAL,
## BUT ON THE WRONG AXIS. Re-run on the head zone, the same two candidates
## read REST 0.0% / PEAK 15.7% (x = 0.70) and REST 0.0% / PEAK 24.3%
## (x = 0.65): her face is completely untouched whenever he is simply
## standing there, and genuinely, visibly touched at the peak of the lean,
## at BOTH. x = 0.65 was rejected once for crossing a ceiling that was
## never measuring her face.
##
## THE REAL WALL SITS FURTHER IN, ALSO MEASURED RATHER THAN GUESSED:
##   x = 0.55 -- REST head-WIDE (head+neck, the looser of the two cuts)
##   turns non-zero for the first time (7.7%): he grazes her neck zone
##   even before leaning in at all. PEAK head-tight already 41.8%.
##   x = 0.40 -- REST head-TIGHT (face/beak/eyes) is non-zero (11.9%): his
##   own head already overlaps hers while just standing there, not kissing
##   anyone. PEAK 68.1% -- her face is gone, confirmed on the render and
##   not just the number: kiss_sweep_x040_peak.png shows almost nothing of
##   her left past his cheek, where kiss_sweep_x065_peak.png and
##   kiss_sweep_x070_peak.png both show her face plainly, his muzzle
##   against it.
##
## x = 0.65 IS THE PICK: the nearer of the two clean candidates, giving the
## deeper of the two genuine-contact readings (24.3% vs 15.7% at peak)
## while staying EXACTLY as clean at rest as 0.70 (0.0% on both cuts) --
## no cost to taking it over 0.70, and more margin above "barely grazing"
## before a phone's own compression and smaller screen flatten the contact
## back into nothing, the same failure this whole lot exists to close.
##
## STILL CLEAR OF THE FOOTPRINT HOLE: 1.820 from MAGPIE_SPOT (was 1.965 at
## 0.80, 2.159 at 1.00) against a MAGPIE_FOOTPRINT_RADIUS of 0.73 leaves
## 1.090 of margin, asserted in CabinProbe rather than left as an unchecked
## coincidence.
##
## And clear of DOOR_SPOT by 1.278 against a DOOR_REACH of 0.9 -- MORE
## margin than 0.80 had (1.208), because closing on the bird moves away
## from the door, not toward it.
const MAGPIE_STAND_SPOT := Vector2(0.65, 0.40)

## Drawn to MATCH Keepy's own drawn height, not half of it -- device found
## the 0.50 pass ("comes up to his shoulder") too small to read as a peer.
## MEASURED, not eyeballed, by two independent readings of the same .glb
## (a standalone Python glTF-chunk parser and a headless Godot AABB probe,
## both agreeing to the 6th significant figure): her model is 1.765680 tall
## in model units, Keepy's own drawn height is 1.257416 * KEEPY_SCALE =
## 1.350062, so 1.350062 / 1.765680 = 0.76461 draws her exactly as tall as
## him. This is the one number to change if the proportion is rejudged on a
## device again.
const MAGPIE_SCALE: float = 0.76461

## Her circumscribed footprint on the ground, at MAGPIE_SCALE, in the SAME
## convention HubBuilder's per-type FOOTPRINT_RADIUS uses for every other
## prop on the plateau: half the larger of her two measured horizontal
## extents (X 1.899911, Z 1.507811 in model units -- X is larger), rounded
## UP rather than to nearest so the excluded ground is never smaller than
## what she actually draws. 0.949956 (half the model-space X extent) *
## MAGPIE_SCALE = 0.7263, rounded up to the same two decimal places
## OWL_FOOTPRINT_RADIUS and CABIN_FOOTPRINT_RADIUS already use.
##
## This is a DIFFERENT number from MAGPIE_TAP_RADIUS on purpose -- one is
## how close a FINGER has to land to mean her, the other is how much
## GROUND her body actually occupies. Reusing the tap radius here would tie
## two unrelated questions to one float, free to drift the day either is
## retuned alone.
const MAGPIE_FOOTPRINT_RADIUS: float = 0.73

## Lowest point of her mesh in ITS OWN units, read off the POSITION accessor
## rather than assumed from the model being centred. It is not: min.y =
## -0.880644 against max.y = +0.885036.
const MAGPIE_MODEL_MIN_Y: float = -0.880644

## And her highest, read the same way. The pair gives her drawn height, which
## is what puts the hearts at beak level instead of at an authored guess.
const MAGPIE_MODEL_MAX_Y: float = 0.885036

## ⚠️ THE HIT-TEST ANCHOR IS NOT MAGPIE_SPOT -- DEVICE REPORT: a tap only
## registered from a narrow zone near her feet, "nothing happens" everywhere
## else on her visibly drawn body. MEASURED, not guessed: LevelController's
## resolve() ray-casts every tap from the FIXED camera down onto the level's
## single FLAT floor plane (see LevelDefinition's own header), and does this
## for EVERY hotspot regardless of how tall the thing it marks actually is.
## A tap that visually lands on her raised body -- not her feet -- resolves
## to a floor-plane XZ point offset from MAGPIE_SPOT by however far that ray
## travels between her body's height and the floor, and the offset GROWS
## with tap height: 0% (her feet) = 0.000, 20% = 0.504, 30% = 0.773 -- already
## past the OLD 0.60 radius -- 100% (top of her head) = 3.045. A repro probe
## confirmed this is uniform and Keepy-position-INDEPENDENT (9/9 starting
## positions around the room fail identically at a representative body-height
## tap): pure floor-plane geometry, not navigation, not the footprint hole.
##
## THE FIX RECENTRES THE ANCHOR rather than only widening the radius at her
## feet. Widening MAGPIE_TAP_RADIUS alone, anchored at MAGPIE_SPOT, tops out
## at 1.623863 before touching the door's circle (door_gap 2.473863 -
## DOOR_TAP_RADIUS 0.85) -- covering at most ~57% of her drawn height,
## permanently missing her upper body and head. Recentring to the
## floor-plane resolution of a tap at 50% of her drawn height moves the
## anchor away from the door (gap widens 2.473863 -> 3.211440, ceiling
## 1.623863 -> 2.361440) while only narrowing the ladder's gap a little
## (3.930013 -> 3.462812, ceiling still 2.362812) -- both ceilings land
## within a hair of each other by coincidence, and both comfortably clear
## the radius chosen below. The BED's hotspot lives on level_index 1 (the
## loft) while the magpie is level_index 0 -- LevelHotspot.accepts_tap()
## checks serves(index) before distance, so the bed is never even tested
## while tapping her and its nearby XZ coordinates are not a constraint.
##
## MAGPIE_TAP_ANCHOR read directly off LevelController.resolve() for a tap
## at (MAGPIE_SPOT.x, floor_y + 0.5 * drawn_height, MAGPIE_SPOT.y), and
## cross-checked by hand with the camera-ray/floor-plane intersection this
## project's camera (no roll) makes exact -- t = (floor_y - camera.y) /
## (W.y - camera.y), anchor = camera + t * (W - camera) -- differing from
## the engine's own screen-space round-trip by under 1e-5. MAGPIE_SPOT
## itself, the footprint hole, MAGPIE_STAND_SPOT and her facing are ALL
## untouched: this constant exists ONLY for hit-testing, exactly like every
## other LevelHotspot.point, which is already free to differ from a prop's
## visual anchor.
const MAGPIE_TAP_ANCHOR := Vector2(-1.261384, -0.437180)

## How close an AIM has to land to mean her, now measured FROM
## MAGPIE_TAP_ANCHOR rather than from her feet. 1.80 covers her whole drawn
## body with margin either side: the FARTHEST point along the tap-height
## sweep from the new anchor is 1.697867 (100% height, the top of her
## head), so 1.80 clears it by 0.102; the nearer of the two neighbour
## ceilings computed AT the new anchor is 2.361440 (the door), so 1.80
## still clears IT by 0.561 -- comfortably inside both, not squeezed to
## either edge.
const MAGPIE_TAP_RADIUS: float = 1.80

## How close a LANDING has to be to the stand spot to actually kiss. The
## door's and the bed's number, not a new one -- all three answer the same
## question, and ARRIVE_EPSILON is the same 0.45 for all three.
const MAGPIE_REACH: float = 0.9

## ⚠️ HER FACING IS DERIVED PLUS A BIAS, AND THE BIAS IS THE LOT'S ONE PIECE
## OF STAGING.
##
## Pointed straight at the stand spot she faces 113.5 degrees -- across the
## room and slightly AWAY from the camera, so the render shows her back. This
## turns her back toward it by 45, to about 68.5: a three-quarter view where
## the eyes, the beak and the flower all read.
##
## It is the same move, and the same reason, as REST_YAW_DEGREES on the bed:
## a pose that is geometrically correct and photographically flat is worth
## one authored offset. Keepy takes NO such bias -- he is the one acting, and
## a lean that does not point at her stops being a kiss.
const MAGPIE_FACING_BIAS_DEGREES: float = -45.0

## =====================================================================
## THE KISS
##
## ⚠️ NO SKELETON, SO NO CLIP. Her .glb and his both carry one node, one
## mesh, no skin and no animation -- the same finding the owl and the cabin
## batches published for this family of assets. Every pose in this project is
## a transform on the whole body, and this is one more.
##
## He leans forward and comes back on ONE tween over a normalised 0..1, with
## the bell 4t(1-t) that is exactly 0 at both ends -- so he cannot be left
## leaning by a rounding error the way a pair of chained tweens can.

## How far he tips toward her at the top of the lean. Degrees about his own
## X, which after _face_magpie() points across his line to her.
const KISS_LEAN_DEGREES: float = 26.0

## And how far he closes the gap while he does it. Small: the lean is the
## gesture, the step is what stops it reading as a bow to nobody.
const KISS_REACH_IN: float = 0.15

## Long enough to read at real speed, short enough that a second tap is a
## second kiss rather than a wait. There is NO cooldown beyond this: the
## moment it ends she answers taps again.
const KISS_S: float = 0.85

## Where in the kiss the hearts leave -- at the top of the lean, not at the
## start, so they read as caused by it.
const KISS_HEARTS_AT: float = 0.46

## How close a LANDING has to be to the door to actually leave. Compared in
## XZ, like LevelWalker's own ENTRY_REACH and for its reason: the arrival
## is on the floor by construction, so height cannot disagree.
const DOOR_REACH: float = 0.9

## And the same for the bed. The door's number, not a new one: both answer
## the same question -- "did the walk that was meant as `use this` actually
## get there" -- and ARRIVE_EPSILON, which is what a hop chain is allowed
## to stop short by, is the same 0.45 for both.
const BED_REACH: float = 0.9

## Ring pulses when the walker is inside this many times a marker's radius,
## and stops at the release. Two numbers and not one, straight out of
## HubPortal: a body standing exactly on one threshold would otherwise
## strobe the marker on and off every frame.
const NEAR_FACTOR: float = 2.2
const NEAR_RELEASE: float = 2.6

## =====================================================================
## KEEPY'S OWN ART CORRECTIONS
##
## ⚠️ THE LIFT IS DERIVED, THE SIZE IS COPIED, AND THAT SPLIT IS THE WHOLE
## POINT -- getting it wrong sank him by 0.9166 world units, 67.9% of his
## own height, so that only his head showed above the floor.
##
## KEEPY_SCALE is COPIED from the shipped hub node so he is drawn indoors
## at exactly the size he is drawn outdoors. That part of the old comment
## was right and is kept.
##
## The LIFT is NOT an art correction and must not be copied from there.
## LevelWalker's contract is that its origin is the FEET: it sets
## global_position.y to the level's floor and _apply_hop draws the arc on
## that same line. So the body has to be raised by exactly the depth the
## model hangs below its own origin, scaled -- which is what the line in
## _place_walker() computes.
##
## WHAT THE SHIPPED CODE DID INSTEAD, and why it looked plausible: the hub
## states that lift as TWO authored numbers that only mean anything
## together -- the Body slot sits at y = 0.9 in HubWorld.tscn and
## ModelSlot then places the model at model_offset = -0.2246 inside it,
## for a total of 0.6754. This file copied the SECOND of those two terms
## on its own, and multiplied it by the scale on top -- and ModelSlot does
## not scale it (it assigns model_offset straight to the child's
## position). So the body sat at -0.2246 * 1.07368 = -0.2411 instead of
## +0.6754: the 0.9 dropped, and a term the hub never scales scaled.
##
## Deriving it closes both at once and cannot drift with either number.
## Cross-checked THREE ways rather than argued:
##   * the hub, feet at y = -0.000020 with its two authored terms;
##   * scenes/dev/LevelNavTest.tscn, whose capsule is height 1.3 at local
##     y = 0.65 -- bottom exactly on the walker's origin, same contract;
##   * this constant, which reproduces the hub's 0.6754 to 4.5e-5.
const KEEPY_SCALE: float = 1.07368

## Lowest point of the shipped Keepy .glb, in ITS OWN model units, read off
## the POSITION accessor of assets/models/keepy_squirrel_hero.glb rather
## than assumed from the model being centred. It is not: min.y = -0.629070
## against max.y = +0.628346.
const KEEPY_MODEL_MIN_Y: float = -0.629070

@onready var _controller: LevelController = $LevelController
@onready var _walker: LevelWalker = $WorldViewport/SubViewport/World/Walker
@onready var _props: Node3D = $WorldViewport/SubViewport/World/Props

## The door hotspot, held so the exit can withdraw it. The bed's is not
## held: nothing withdraws it yet, and a field kept "for later" is a field
## nobody maintains.
var _door: LevelHotspot = null

## THE BED, held for the same reason the door is: the rest state has to
## withdraw it. The comment above used to say the bed's was NOT held
## because nothing withdrew it yet -- something does now.
var _bed: LevelHotspot = null

## THE HELD EXIT INTENT, and it is LevelWalker's `_pending` in miniature --
## including the lesson that one cost.
##
## ⚠️ IT MUST SURVIVE A PASS-THROUGH LANDING. The owl batch shipped a
## version of that walker intent which cleared on the FIRST landing
## whatever it was, so any walk longer than one hop ended with Keepy
## standing next to the thing having never used it -- and the probe was
## green until a control tap pushed the walk out to two hops. A tap on the
## door from across the room is exactly such a walk, so this is released
## on a landing AT the door, on a plain tap somewhere else, or never.
var _exit_pending: bool = false

## Set once the scene change has been asked for. change_scene_to_file() is
## deferred to the end of the frame, so without this a second tap in the
## same frame asks twice.
var _leaving: bool = false

## =====================================================================
## THE HELD REST INTENT, AND THE STATE IT ARMS
##
## `_rest_pending` is `_exit_pending` in every respect including the one
## that matters: IT SURVIVES A PASS-THROUGH LANDING. A tap on the bed from
## the top of the ladder is a walk of more than one hop, and an intent
## that cleared on the first landing whatever it was would leave Keepy
## standing beside the bed having never got into it -- the owl batch's
## measured bug, restated here because this is the third thing to copy it.
##
## `_resting` is a state and not a tween: nothing animates, nothing has to
## be put back at a deadline, and the only way out is a tap.
var _rest_pending: bool = false
var _resting: bool = false

## =====================================================================
## THE MAGPIE'S HELD INTENT, AND THE STATE THE KISS ARMS
##
## `_kiss_pending` is `_exit_pending` and `_rest_pending` in every respect
## including the one that matters: IT SURVIVES A PASS-THROUGH LANDING. A tap
## on her from across the room is a walk of more than one hop, and an intent
## that cleared on the first landing whatever it was would leave Keepy
## standing beside her having never leaned in -- the owl batch's measured
## bug, and this is the fourth thing in this file to be built not to repeat
## it.
##
## `_kissing` is held for the length of the tween and for nothing else. It
## exists so a second tap during a kiss cannot start a second one on the
## same body, and it is cleared by the tween itself.
var _kiss_pending: bool = false
var _kissing: bool = false

## Her hotspot, held so the kiss can withdraw it -- the boat's shape, the
## same one the bed and the door use.
var _magpie: LevelHotspot = null

## The bird herself, and the hearts that rise off her.
var _magpie_body: Node3D = null
var _hearts: CabinHearts = null

## One marker per tappable thing, kept so the ladder's can follow Keepy
## between storeys and the others can hide when he is not on their level.
var _ladder_marker: CabinMarker = null
var _door_marker: CabinMarker = null
var _bed_marker: CabinMarker = null
var _magpie_marker: CabinMarker = null

func _ready() -> void:
	# ⚠️ MOUSE_FILTER_IGNORE, and it is load-bearing. _unhandled_input runs
	# AFTER GUI picking, so a full-screen Control left at Control's DEFAULT
	# MOUSE_FILTER_STOP consumes every tap and calls set_input_as_handled()
	# -- no error, no warning, a screen that ignores taps. HubWorld shipped
	# exactly that and it cost a batch to find. The button below is still
	# picked normally: only the ROOT is taken out of the way.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SafeArea.fill_screen()

	_controller.levels = [
		LevelDefinition.make(&"cabin_floor", _world_y(FLOOR_MODEL_Y),
				FLOOR_HALF_EXTENT, FLOOR_CENTRE.x, FLOOR_CENTRE.y),
		LevelDefinition.make(&"cabin_loft", _world_y(LOFT_MODEL_Y),
				LOFT_HALF_EXTENT, LOFT_CENTRE.x, LOFT_CENTRE.y),
	]
	# Both ends built FROM the level definitions, so the height a player
	# arrives at and the height that level's floor is at are one fact
	# rather than two literals free to drift. Straight out of
	# LevelNavTestWorld, and for its reason.
	var floor_level: LevelDefinition = _controller.levels[0]
	var loft_level: LevelDefinition = _controller.levels[1]
	_controller.links = [
		LevelTransition.make(0, 1,
			Vector3(LADDER_FOOT.x, floor_level.plane_y, LADDER_FOOT.y),
			Vector3(LADDER_TOP.x, loft_level.plane_y, LADDER_TOP.y),
			LADDER_TAP_RADIUS),
	]
	# THE DOOR AND THE BED, as hotspots on the ground floor and the loft.
	# Built FROM the level definitions for the reason the link's ends are:
	# a hand-written height here would be a second opinion about where a
	# floor is.
	_door = LevelHotspot.make(0,
			Vector3(DOOR_SPOT.x, floor_level.plane_y, DOOR_SPOT.y),
			DOOR_TAP_RADIUS, &"door", "Sortir")
	# ⚠️ BUILT FROM BED_TAP_ANCHOR, NOT BED_SPOT -- see BED_TAP_ANCHOR's own
	# comment. This is the relocated, parallax-corrected circle the hit
	# test needs; BED_SPOT stays reserved for where the bed is actually
	# drawn and where Keepy is sent to lie down.
	_bed = LevelHotspot.make(1,
			Vector3(BED_TAP_ANCHOR.x, loft_level.plane_y, BED_TAP_ANCHOR.y),
			BED_TAP_RADIUS, &"bed", "Lit")
	# THE MAGPIE, on the ground floor. Registered exactly like the other two
	# and through the same generic class -- LevelHotspot's own header already
	# names "a door, a bed, a chest" as what it is for, so a third kind of
	# thing to tap needs no new machinery, only a new StringName.
	_magpie = LevelHotspot.make(0,
			Vector3(MAGPIE_TAP_ANCHOR.x, floor_level.plane_y, MAGPIE_TAP_ANCHOR.y),
			MAGPIE_TAP_RADIUS, &"magpie", "Pie")
	_controller.hotspots = [_door, _bed, _magpie]
	# ⚠️ THE FOOTPRINT HOLE -- see LevelDefinition's own header for the whole
	# argument. A ground tap can never CHOOSE a destination inside her
	# measured footprint; MAGPIE_STAND_SPOT itself is untouched by this (it
	# is 1.254 from her against a hole radius of 0.73, comfortably clear),
	# and neither is the hop chain already under way toward it -- this stops
	# a TAP from landing on her, it does not steer an ongoing walk around
	# her, exactly as the lake never did either.
	floor_level.set_hole(MAGPIE_SPOT.x, MAGPIE_SPOT.y, MAGPIE_FOOTPRINT_RADIUS)

	_controller.tapped_ground.connect(_on_tapped_ground)
	_controller.tapped_transition.connect(_on_tapped_transition)
	_controller.tapped_hotspot.connect(_on_tapped_hotspot)
	_controller.level_changed.connect(_on_level_changed)

	_build_backdrop()
	_build_magpie()
	_place_walker()
	_build_markers()
	# The walker moves the markers' near/far state, and its landings are
	# where a held exit intent is honoured.
	_walker.hop_landed.connect(_on_hop_landed)
	_walker.became_idle.connect(_refresh_proximity)
	_on_level_changed(_controller.current_index())

## Model space to world space. ONE conversion, used by both floors and by
## nothing else, so the scale and the lift cannot be applied twice to one
## of them and once to the other.
static func _world_y(model_y: float) -> float:
	return (model_y + CABIN_MODEL_OFFSET_Y) * CABIN_SCALE

## The .glb, once, as scenery. Never moved, never rotated, never scaled
## again after this: everything else in the scene is positioned against it,
## so it is the fixed thing.
func _build_backdrop() -> void:
	var model := CABIN.instantiate() as Node3D
	if model == null:
		push_error("CabinInterior: the cabin .glb did not instantiate to a Node3D.")
		return
	# The lift is applied to the CHILD in model units and the scale to the
	# holder, which is exactly how HubBuilder builds the same asset on the
	# plateau. Doing it the other way round would multiply the lift by the
	# scale twice.
	model.position = Vector3(0.0, CABIN_MODEL_OFFSET_Y, 0.0)
	var holder := Node3D.new()
	holder.name = "Cabin"
	holder.add_child(model)
	holder.scale = Vector3.ONE * CABIN_SCALE
	_props.add_child(holder)

## The magpie, and the hearts holder that goes with her.
##
## Instantiated DIRECTLY rather than through a ModelSlot, on the owl's and
## the cabin's own terms: a slot exists to hold a PLACEHOLDER that a real
## model later replaces, and this is either the bird or nothing.
##
## ⚠️ HER YAW IS DERIVED, NOT AUTHORED. She faces MAGPIE_STAND_SPOT, which
## is the one place Keepy can ever be while talking to her -- so a second
## authored angle here would be a second opinion about where he stands, free
## to drift from the spot itself the first time either moves. Her model's
## face is on +Z, measured by rendering her on four axes rather than assumed
## from the other assets: at yaw 0 the eyes, beak and flower are visible and
## at 180 only her back is.
func _build_magpie() -> void:
	var bird := MAGPIE.instantiate() as Node3D
	if bird == null:
		push_error("CabinInterior: the magpie .glb did not instantiate to a Node3D.")
		return
	bird.name = "Magpie"
	bird.scale = Vector3.ONE * MAGPIE_SCALE
	var floor_level: LevelDefinition = _controller.levels[0]
	# Lifted by exactly the depth she hangs below her own origin, scaled --
	# the derivation that cost 0.9166 world units when it was copied instead.
	bird.position = Vector3(
			MAGPIE_SPOT.x,
			floor_level.plane_y - MAGPIE_MODEL_MIN_Y * MAGPIE_SCALE,
			MAGPIE_SPOT.y)
	bird.rotation_degrees = Vector3(0.0,
			_yaw_towards(MAGPIE_SPOT, MAGPIE_STAND_SPOT) + MAGPIE_FACING_BIAS_DEGREES,
			0.0)
	_props.add_child(bird)
	_magpie_body = bird
	# The hearts live on Props and not on the bird, so her own transform --
	# which a later batch may well want to animate -- cannot carry them.
	_hearts = CabinHearts.new()
	_hearts.name = "Hearts"
	_props.add_child(_hearts)

## The yaw that points a node's +Z from `from` at `to`. One conversion, so
## nothing in this file writes atan2 twice with the arguments in a different
## order.
static func _yaw_towards(from: Vector2, to: Vector2) -> float:
	var d := to - from
	if d.length_squared() <= 0.0:
		return 0.0
	return rad_to_deg(atan2(d.x, d.y))

## WHERE THE MAGPIE STANDS, IN THE CABIN MODEL'S OWN UNITS.
##
## Published so the plateau can draw her in its cutaway view of this same
## .glb without restating a single one of the numbers above. She is the
## first thing this project has ever needed to show in TWO places at once,
## and the two places draw the cabin at DIFFERENT scales -- the hub entry
## carries 7.0 and CABIN_SCALE here is 11.0 -- so a copied world coordinate
## would be wrong by that ratio and a copied SCALE would make her the wrong
## size. Everything below is therefore divided back out of CABIN_SCALE into
## the model's own frame, which is the one frame both views share.
##
## The caller hangs the result on whatever node it built the .glb under, so
## its own scale and its own rotation_y carry her with them: a cabin turned
## in the layout takes its magpie along instead of leaving her facing a wall.
##
## DERIVED, never authored. Every term is one of the constants
## _build_magpie() itself uses, so the two cannot drift -- and CabinProbe
## asserts that feeding this back through CABIN_SCALE reproduces the body
## that was actually built, rather than trusting that they agree.
##
## Position y already carries CABIN_MODEL_OFFSET_Y, exactly as the backdrop
## child does, so the bird and the building sit in the same local frame.
static func magpie_local_pose() -> Dictionary:
	return {
		"position": Vector3(
				MAGPIE_SPOT.x / CABIN_SCALE,
				FLOOR_MODEL_Y + CABIN_MODEL_OFFSET_Y
						- MAGPIE_MODEL_MIN_Y * MAGPIE_SCALE / CABIN_SCALE,
				MAGPIE_SPOT.y / CABIN_SCALE),
		"scale": MAGPIE_SCALE / CABIN_SCALE,
		"yaw_degrees": _yaw_towards(MAGPIE_SPOT, MAGPIE_STAND_SPOT)
				+ MAGPIE_FACING_BIAS_DEGREES,
	}

## Keepy's body, hung on the walker.
##
## Instantiated DIRECTLY and not through a ModelSlot, on the owl's and the
## cabin prop's own terms: a slot exists to hold a PLACEHOLDER that a real
## model later replaces, and this is either Keepy or nothing.
##
## His SIZE is copied from the shipped hub node so he is drawn here exactly
## as he is drawn out there. His LIFT is derived from the mesh instead of
## copied -- see the KEEPY_SCALE block for the 0.9166 that cost.
func _place_walker() -> void:
	var body := KEEPY.instantiate() as Node3D
	if body == null:
		push_error("CabinInterior: the Keepy .glb did not instantiate to a Node3D.")
	else:
		body.name = "Body"
		body.scale = Vector3.ONE * KEEPY_SCALE
		# Raise him by exactly the depth he hangs below his own origin, so
		# his lowest vertex lands ON the walker's origin -- which IS the
		# floor. One multiplication, no authored offset to drift.
		body.position = Vector3(0.0, -KEEPY_MODEL_MIN_Y * KEEPY_SCALE, 0.0)
		_walker.add_child(body)
	var floor_level: LevelDefinition = _controller.levels[0]
	_walker.global_position = Vector3(ENTRY_SPOT.x, floor_level.plane_y, ENTRY_SPOT.y)

## =====================================================================
## THE MARKERS
##
## One per tappable thing. The door's and the ladder's ring IS the circle
## the code tests, because neither of them ever needed a second one.
##
## ⚠️ THE MAGPIE'S AND THE BED'S ARE NOT, ANYMORE -- and that split is
## deliberate rather than a drift the other two should be pulled into. Both
## of them are tall, visually-raised things whose HIT-TEST anchor had to
## move off their real ground position to survive LevelController's
## flat-plane raycast (see MAGPIE_TAP_ANCHOR's and BED_TAP_ANCHOR's own
## comments) -- and a ring drawn AT that relocated anchor, at the relocated
## RADIUS, draws correctly for accepts_tap() and wrong for a player's eye:
## it floats off the prop it marks, sized to cover a parallax spread rather
## than to match what is actually standing there. So the ring for each of
## these two is built from a SEPARATE pair -- its real ground position and
## a radius sized to its footprint -- while the LevelHotspot it marks keeps
## the relocated, parallax-corrected pair for the hit test. See CabinMarker
## for why the hub's colours are not reused.
func _build_markers() -> void:
	var floor_level: LevelDefinition = _controller.levels[0]
	_ladder_marker = _add_marker(_controller.links[0].tap_radius, "Mezzanine")
	_door_marker = _add_marker(DOOR_TAP_RADIUS, "Sortir")
	_door_marker.position = Vector3(DOOR_SPOT.x, floor_level.plane_y, DOOR_SPOT.y)
	# ⚠️ BED_MARKER_RADIUS, NOT BED_TAP_RADIUS -- same split as the magpie's,
	# for the same reason: the ring is drawn at the bed's real ground
	# position (BED_SPOT) and its old, never-reported-as-wrong size, while
	# BED_TAP_ANCHOR/BED_TAP_RADIUS (see their own comment) keep doing the
	# hit test from a relocated, parallax-corrected circle.
	_bed_marker = _add_marker(BED_MARKER_RADIUS, "Lit")
	var loft_level: LevelDefinition = _controller.levels[1]
	_bed_marker.position = Vector3(BED_SPOT.x, loft_level.plane_y, BED_SPOT.y)
	# ⚠️ DRAWN AT MAGPIE_SPOT WITH MAGPIE_FOOTPRINT_RADIUS, NOT AT
	# MAGPIE_TAP_ANCHOR WITH MAGPIE_TAP_RADIUS -- DEVICE REPORT, SECOND ONE:
	# the FUNCTIONAL fix above made her taps register, and the very next
	# report was that the ring drawn to celebrate it was oversized, sitting
	# 1.35 off her own feet at a 1.80 radius that swallowed a third of the
	# room. The ring a player SEES and the circle accepts_tap() TESTS never
	# had to be the same circle -- CabinMarker.setup() takes whatever radius
	# it is given, and nothing reads it back. So the ring goes back to being
	# a small mark hugging her body, at her real ground position, the same
	# visual role DOOR_TAP_RADIUS/DOOR_SPOT and BED_MARKER_RADIUS/BED_SPOT
	# already play for their own hotspots -- while MAGPIE_TAP_ANCHOR and
	# MAGPIE_TAP_RADIUS keep doing the hit-testing, untouched.
	#
	# MAGPIE_FOOTPRINT_RADIUS is reused rather than a new constant invented:
	# it already answers "how much ground does she occupy" for the floor
	# hole, and a ring sized to that ground is a ring sized to her, not a
	# second measurement of the same body free to drift from the first.
	# Rendered at three candidate radii before picking this one (1.00, 0.73,
	# 0.60 at the anchor first, then 0.85, 0.73, 0.60 at MAGPIE_SPOT once the
	# position moved too) -- 0.73 at MAGPIE_SPOT is the one that reads as
	# hugging her, matching the door's own ring style at a comparable scale.
	_magpie_marker = _add_marker(MAGPIE_FOOTPRINT_RADIUS, "Pie")
	_magpie_marker.position = Vector3(MAGPIE_SPOT.x, floor_level.plane_y, MAGPIE_SPOT.y)

func _add_marker(radius: float, text: String,
		label_offset: Vector3 = Vector3.ZERO) -> CabinMarker:
	var marker := CabinMarker.new()
	marker.setup(radius, text, CabinMarker.Surface.CABIN_FLOOR, label_offset)
	_props.add_child(marker)
	return marker

## Markers follow the storey Keepy is on.
##
## ⚠️ THE LADDER'S MARKER MOVES, and that is the honest thing rather than
## the cheap one. The link has an entry on EACH level, and only the one on
## the level Keepy is standing on answers a tap -- accepts_tap() measures
## against entry_for(current). Drawing both ends at once would put a ring
## on the loft that does nothing while he is downstairs, which is a marker
## that lies about being tappable. So there is one ring and it is always at
## the end that works.
##
## The door and the bed simply hide off their own level, for the same
## reason: a tappable-looking thing that is not tappable is worse than no
## mark at all.
func _on_level_changed(index: int) -> void:
	var level: LevelDefinition = _controller.level_at(index)
	if level == null:
		return
	var link: LevelTransition = _controller.links[0]
	if _ladder_marker != null:
		_ladder_marker.position = link.entry_for(index)
		_ladder_marker.visible = link.serves(index)
	if _door_marker != null:
		_door_marker.visible = _door != null and _door.serves(index)
	if _bed_marker != null:
		_bed_marker.visible = _bed != null and _bed.serves(index)
	if _magpie_marker != null:
		_magpie_marker.visible = _magpie != null and _magpie.serves(index)
	_refresh_proximity()

## Pulses whatever Keepy is standing near, with HubPortal's hysteresis.
##
## ⚠️ EACH CALL PASSES ITS OWN ANCHOR, NOT `marker.position`, ANYMORE. The
## door's and the ladder's marker sit exactly on the circle accepts_tap()
## tests, so reading their own position was harmless. The magpie's and the
## bed's marker were just moved to their real ground position (see
## _build_markers' own header) -- which is no longer that circle. What
## "near" is meant to tell a player is "a tap here will register", so the
## pulse has to track the same relocated, parallax-corrected anchor the
## hit test itself uses, not the ring drawn on the ground beside it.
func _refresh_proximity() -> void:
	var here := _walker.global_position
	_pulse_if_near(_ladder_marker, _ladder_marker.position if _ladder_marker != null else Vector3.ZERO,
			_controller.links[0].tap_radius, here)
	_pulse_if_near(_door_marker, Vector3(DOOR_SPOT.x, 0.0, DOOR_SPOT.y),
			DOOR_TAP_RADIUS, here)
	_pulse_if_near(_bed_marker, Vector3(BED_TAP_ANCHOR.x, 0.0, BED_TAP_ANCHOR.y),
			BED_TAP_RADIUS, here)
	_pulse_if_near(_magpie_marker, Vector3(MAGPIE_TAP_ANCHOR.x, 0.0, MAGPIE_TAP_ANCHOR.y),
			MAGPIE_TAP_RADIUS, here)

func _pulse_if_near(marker: CabinMarker, anchor: Vector3, radius: float, here: Vector3) -> void:
	if marker == null or not marker.visible:
		return
	var a := Vector3(anchor.x, 0.0, anchor.z)
	var b := Vector3(here.x, 0.0, here.z)
	var d := a.distance_to(b)
	# Two thresholds, never one -- see NEAR_FACTOR.
	if d <= radius * NEAR_FACTOR:
		marker.set_near(true)
	elif d >= radius * NEAR_RELEASE:
		marker.set_near(false)

func _on_tapped_ground(destination: Vector3) -> void:
	# ⚠️ A TAP WHILE HE IS LYING DOWN IS THE WAY UP, AND IT ARRIVES HERE
	# BECAUSE THE BED WITHDREW -- which is the boat's shape and the whole
	# reason the withdrawal was chosen over the ladder's. `_enter_rest`
	# holds the bed and the ladder busy, so neither answers; the tap falls
	# THROUGH to this path, and this is where it becomes "get up".
	#
	# It returns rather than walking. He asked to stop lying down; sending
	# him off across the loft in the same gesture would be two answers to
	# one tap.
	if _resting:
		_wake()
		return
	# ⚠️ A TAP WHILE HE IS KISSING HER MUST DO NOTHING, AND THIS GUARD IS
	# THE ONE THIS FILE SHIPPED WITHOUT -- confirmed the missing half of a
	# pair by empirical trace, not assumed. `_enter_kiss()` withdraws the
	# hotspot (`_magpie.set_busy(true)`) exactly as `_enter_rest()`
	# withdraws the bed, but unlike `_resting` two lines up, `_kissing` had
	# no reader here at all.
	#
	# That gap is reachable on EVERY real tap that lands close enough to
	# enter the kiss immediately (the "already standing there" branch
	# `_try_kiss()` shares with the door's and the bed's): Godot's own
	# emulate_mouse_from_touch fires an InputEventScreenTouch release AND a
	# synthesised InputEventMouseButton release for one physical tap, both
	# independently dispatched by _unhandled_input(). The first entry snaps
	# him into the lean and busies her; the second, landing on a now-busy
	# hotspot, fell through to exactly this function with a destination at
	# or near her own point -- and hop_to() below had no opinion about a
	# kiss already running, so it walked him straight off his own pose and
	# onto her. Measured via a throwaway probe driving the real dispatch()
	# path: 25 of 31 traced frames moved AWAY from the stand spot, worst
	# +0.3811 in one frame, ending exactly on MAGPIE_SPOT.
	#
	# It returns rather than walking, for the reason her own header already
	# gives and this guard now actually enforces: "she is held for KISS_S
	# and not one frame longer, and the TWEEN ITSELF is what releases her."
	# There is no cancel gesture for a kiss the way there is a wake-up
	# gesture for a nap -- nothing here needs a bed's _wake()-style side
	# effect, only silence until she lets him go.
	if _kissing:
		return
	# A plain destination tap CANCELS a held exit intent -- the player
	# asked for somewhere else, and honouring the old intent on arrival
	# would be the screen acting on a decision he has already replaced.
	# LevelWalker.hop_to() does exactly this to its own link intent.
	_exit_pending = false
	_rest_pending = false
	_kiss_pending = false
	_walker.hop_to(destination)

func _on_tapped_transition(link: LevelTransition, _destination: Vector3) -> void:
	_exit_pending = false
	_rest_pending = false
	_kiss_pending = false
	if _ladder_marker != null:
		_ladder_marker.flash()
	_walker.request_transition(link)

## A tap on something that is not a level change.
##
## The door is the LADDER'S shape and not the button's: he WALKS there and
## leaves on arrival. Measured rather than assumed to be the house style --
## the hub's own ladder does not fire at tap time either; _on_tapped_ladder
## arms an intent and calls hop_to(), and the landing is what climbs.
func _on_tapped_hotspot(hotspot: LevelHotspot, destination: Vector3) -> void:
	match hotspot.kind:
		&"door":
			if _door_marker != null:
				_door_marker.flash()
			_walker.hop_to(destination)
			# Armed AFTER hop_to(). That call clears the WALKER's own link
			# intent, and arming before it would read as though the two
			# were the same field -- they are not, and only one of them is
			# cleared there.
			_exit_pending = true
			# ⚠️ ALREADY STANDING ON IT: nothing to walk, so leave on the
			# spot. _advance() finishes a zero-length walk by emitting
			# became_idle and NOT hop_landed, so a landing-only path never
			# fires here and the intent armed one line up would simply be
			# left standing.
			#
			# ⚠️ THIS IS THE DEFECT THAT SHIPPED, and it is the bed's line
			# below that shows how long the other half of the pair had
			# been right: DOOR_SPOT is ENTRY_SPOT, so he arrives standing
			# exactly on the doorstep, and the FIRST tap of every visit
			# was thrown away. Reachable from the opening frame, not a
			# corner case.
			_try_exit()
		&"bed":
			if _bed_marker != null:
				_bed_marker.flash()
			# THE LADDER'S SHAPE, exactly as the door has it: he WALKS
			# there and lies down on arrival. Not because a rule says so
			# but because it is what every other reachable thing in this
			# project already does -- the hub's boat, its ladder, its
			# perch, its doorstep, and this scene's own door all arm an
			# intent and let the landing act.
			_exit_pending = false
			# ⚠️ `destination` IS DELIBERATELY DISCARDED HERE TOO, NOW --
			# the second branch in this file that does it, after the
			# magpie's. Before the fix above this line read exactly like
			# the door's (`hop_to(destination)`), and that was correct
			# then: BED_SPOT and the hit-test anchor were the SAME point.
			# They no longer are -- accepts_tap() now tests against the
			# relocated BED_TAP_ANCHOR, so `destination` resolves near
			# THAT circle, not near the bed itself. Walking him to it
			# would land him a couple of units off the mattress instead
			# of on it. BED_SPOT is where the bed is actually drawn.
			var loft_level: LevelDefinition = _controller.levels[1]
			_walker.hop_to(Vector3(BED_SPOT.x, loft_level.plane_y, BED_SPOT.y))
			# Armed AFTER hop_to(), for the reason the door's is: that call
			# clears the WALKER's own link intent, and arming first would
			# read as though the two were one field.
			_rest_pending = true
			# ⚠️ ALREADY STANDING ON IT: nothing to walk, so lie down on
			# the spot. _advance() finishes a zero-length walk by emitting
			# became_idle and NOT hop_landed, so a landing-only path would
			# simply never fire here -- the hub's _on_tapped_cabin carries
			# the same line for the same reason.
			_try_rest()
		&"magpie":
			if _magpie_marker != null:
				_magpie_marker.flash()
			_exit_pending = false
			_rest_pending = false
			# ⚠️ `destination` IS DELIBERATELY DISCARDED HERE, and this is the
			# only branch in this file that does it. See the MAGPIE block at
			# the top: a bird is walked UP TO and not ONTO, so the place to
			# stand is one this file chooses, not one the thumb picked out of
			# a 0.60 circle.
			var floor_level: LevelDefinition = _controller.levels[0]
			_walker.hop_to(Vector3(MAGPIE_STAND_SPOT.x, floor_level.plane_y,
					MAGPIE_STAND_SPOT.y))
			# Armed AFTER hop_to(), for the reason the door's and the bed's
			# are: that call clears the WALKER's own link intent, and arming
			# first would read as though the two were one field.
			_kiss_pending = true
			# ⚠️ ALREADY STANDING THERE: nothing to walk, so kiss on the spot.
			# _advance() finishes a zero-length walk by emitting became_idle
			# and NOT hop_landed, so a landing-only path would never fire --
			# which is exactly the defect that shipped on the door and was
			# reachable from the opening frame of every visit.
			_try_kiss()
		_:
			_exit_pending = false
			_rest_pending = false
			_kiss_pending = false
			_walker.hop_to(destination)

## Every landing: proximity, and the held intents.
##
## ⚠️ THE POSITION IS NOT READ HERE. Both _try_rest() and _try_exit() ask
## the WALKER where he is rather than trusting an argument, because both
## have a second caller -- the tap itself, when the walk is zero-length --
## that has no landing to hand them.
func _on_hop_landed(_position: Vector3) -> void:
	_refresh_proximity()
	# The rest intent is honoured BEFORE the exit intent for no reason
	# beyond needing an order: the two cannot be armed at once, because
	# arming either clears the other.
	if _rest_pending and _try_rest():
		return
	if _kiss_pending and _try_kiss():
		return
	if _exit_pending:
		_try_exit()

## =====================================================================
## LYING DOWN, AND GETTING UP
##
## ⚠️ THE WITHDRAWAL IS THE BOAT'S AND THE LADDER'S IS BANNED, which is
## LevelHotspot's own header repeated on the second thing to obey it. The
## bed AND the ladder are both held busy for the whole of the rest, so
## neither answers a tap -- and the tap therefore falls THROUGH to the
## ground path, where it becomes "get up". One tap, one signal, in both
## directions.
##
## The LADDER is held too, and that is not tidiness: it is the only other
## thing on the loft that answers a tap, and a crossing started while he
## is lying down would drive the body from LevelWalker while this file
## thinks it owns it. Held, it simply has nothing to do.
##
## THE DOOR is NOT held, and does not need to be: it lives on level 0 and
## accepts_tap() refuses from anywhere else. Holding it would be a second
## opinion about a refusal that already exists.

## Leaves if he has actually reached the door. Returns whether it did, so
## the caller knows the landing is spent -- _try_rest()'s shape exactly,
## and for the same two callers.
##
## ⚠️ IT DOES NOT GUARD ON `_resting`, and that omission is deliberate
## rather than missed. Lying down happens on the LOFT, and no point on the
## loft is within DOOR_REACH of the doorstep -- the nearest is 1.941
## against a reach of 0.9 (was 1.999 before this lot's relocation, still
## nowhere close). A guard that can never fire is a guard nobody reads, so
## the geometry is asserted in CabinProbe PHASE K instead, where moving the
## loft would break it loudly.
##
## ⚠️ AND IT LEAVES WITHOUT WALKING ANYWHERE INSIDE DOOR_REACH, not only
## from a dead stop. Between ARRIVE_EPSILON (0.45) and DOOR_REACH (0.9)
## the walk is real but he is already close enough to have arrived, so the
## immediate call spends the intent and he goes. That is not a side effect
## of the fix -- it is what the shipped bed has always done, its BED_REACH
## being the same 0.9 against the same immediate call, and having the two
## disagree would be the odder of the two answers.
func _try_exit() -> bool:
	if _leaving:
		return false
	var here := _walker.global_position
	var flat := Vector2(here.x, here.z)
	if flat.distance_to(DOOR_SPOT) > DOOR_REACH:
		# NOT there yet. The intent is KEPT -- this is the pass-through
		# landing that LevelWalker's own `_pending` exists to survive.
		return false
	_exit_pending = false
	_leave_to_hub()
	return true

## Kisses her if he has actually reached the stand spot. Returns whether it
## did, so the caller knows the landing is spent -- _try_exit()'s and
## _try_rest()'s shape exactly, and for the same two callers.
##
## ⚠️ IT MEASURES AGAINST MAGPIE_STAND_SPOT AND NOT AGAINST HER. The walk was
## aimed at the stand spot, so that is what "did he arrive" means; measuring
## against the bird would be asking a question nobody was walking towards,
## and would let a landing anywhere in a 0.9 ring around her count.
func _try_kiss() -> bool:
	if _kissing or _resting or _leaving or _magpie == null:
		return false
	var here := _walker.global_position
	var flat := Vector2(here.x, here.z)
	if flat.distance_to(MAGPIE_STAND_SPOT) > MAGPIE_REACH:
		# NOT there yet. The intent is KEPT -- the pass-through landing that
		# LevelWalker's own `_pending` exists to survive.
		return false
	_kiss_pending = false
	_enter_kiss()
	return true

## =====================================================================
## THE KISS ITSELF
##
## ⚠️ THE WITHDRAWAL IS THE BOAT'S, AND THE LADDER'S IS BANNED -- the rule
## LevelHotspot's header states and this file already obeys twice. She stops
## answering taps for the length of the lean, so a tap during it falls
## THROUGH to the ground path and moves him instead of stacking a second
## tween on the same body.
##
## ⚠️ AND THAT IS NOT A COOLDOWN. The brief asked for the interaction to be
## repeatable without limit, and it is: she is held for KISS_S and not one
## frame longer, and the tween itself is what releases her. There is no
## timer after it, no counter, and nothing remembered between kisses.
##
## THE LADDER IS NOT HELD, unlike during a rest. A rest happens on the loft
## where the ladder is the only other thing to tap and a crossing started
## mid-pose would drive the body from LevelWalker while this file thinks it
## owns it. The kiss happens on the GROUND FLOOR, where the ladder's foot is
## 3.344 away against radii summing to 1.70 -- so a tap cannot reach both,
## and holding it would be a second opinion about a refusal the geometry
## already makes.
func _enter_kiss() -> void:
	var body := _walker.get_node_or_null("Body") as Node3D
	if body == null:
		push_error("CabinInterior: cannot kiss -- the walker has no Body.")
		return
	_kissing = true
	_magpie.set_busy(true)
	# The marker stops breathing while she is busy: a ring pulsing over a
	# thing that refuses is a ring that lies.
	if _magpie_marker != null:
		_magpie_marker.set_near(false)
	# ⚠️ HE SNAPS TO THE SPOT, and this line is load-bearing rather than
	# tidy. LevelWalker._advance() stops a hop chain once the remainder is
	# under ARRIVE_EPSILON (0.45), so a walk ENDS NEAR its target and never
	# ON it -- measured at 0.383 short on one approach. Without this the
	# gap between the two of them would depend on which side of the room he
	# came from: further than designed from the north, and from the far
	# side CLOSER than his own muzzle is long, which is a squirrel drawn
	# through a bird. The bed does exactly this, for exactly this reason.
	#
	# Only XZ and the yaw move. The height is the floor he is already on,
	# read off the level rather than restated.
	_walker.global_position = Vector3(MAGPIE_STAND_SPOT.x,
			_controller.levels[0].plane_y, MAGPIE_STAND_SPOT.y)
	# He turns to her BEFORE the lean, and the angle is derived from the two
	# points rather than authored -- the same one conversion her own yaw came
	# out of, with the arguments the other way round.
	_walker.rotation_degrees = Vector3(0.0,
			_yaw_towards(MAGPIE_STAND_SPOT, MAGPIE_SPOT), 0.0)
	var hearts_fired := [false]
	var tw := create_tween()
	tw.tween_method(
		func(t: float) -> void: _apply_kiss(body, hearts_fired, t),
		0.0, 1.0, KISS_S)
	tw.tween_callback(_end_kiss)

## One tween over a normalised 0..1, with the bell 4t(1-t).
##
## ⚠️ THE BELL IS EXACTLY 0 AT BOTH ENDS BY CONSTRUCTION, which is why this
## is one tween_method and not a chained lean-out/lean-back pair: he cannot
## be left leaning by a rounding error, and there is no second tween that
## could be killed halfway and strand him. The hub's impact ring and
## CabinMarker's own flash are the same shape for the same reason.
func _apply_kiss(body: Node3D, fired: Array, t: float) -> void:
	if not is_instance_valid(body):
		return
	var bell := 4.0 * t * (1.0 - t)
	# Positive X leans a Node3D forward -- its up vector tips toward local
	# +Z, which _yaw_towards() has just pointed at her.
	body.rotation_degrees = Vector3(KISS_LEAN_DEGREES * bell, 0.0, 0.0)
	body.position = Vector3(0.0,
			-KEEPY_MODEL_MIN_Y * KEEPY_SCALE,
			KISS_REACH_IN * bell)
	# The hearts leave at the top of the lean, once. A boolean in a boxed
	# array and not a field: it belongs to this one kiss, and a field would
	# have to be reset by whoever starts the next one.
	if not bool(fired[0]) and t >= KISS_HEARTS_AT:
		fired[0] = true
		if _hearts != null:
			_hearts.burst(_kiss_point())

## Where the hearts leave from: half way between her head and his, at her
## head's height. DERIVED from the two spots and the two models' own
## measured heights, so nothing here is a fourth opinion about where either
## of them is standing.
func _kiss_point() -> Vector3:
	var floor_level: LevelDefinition = _controller.levels[0]
	var bird_head := Vector3(MAGPIE_SPOT.x,
			floor_level.plane_y + (MAGPIE_MODEL_MAX_Y - MAGPIE_MODEL_MIN_Y) * MAGPIE_SCALE * 0.86,
			MAGPIE_SPOT.y)
	var his := Vector3(MAGPIE_STAND_SPOT.x, bird_head.y, MAGPIE_STAND_SPOT.y)
	return bird_head.lerp(his, 0.5)

## Puts him back. Everything is DERIVED rather than restored from a snapshot
## taken on the way in -- _wake()'s rule, and for its reason: a saved
## transform is a copy that goes stale the first time anything else moves
## him.
##
## His YAW is left facing her, exactly as _wake() leaves his facing the way
## he lay. The next hop turns him again through LevelWalker._face().
func _end_kiss() -> void:
	_kissing = false
	var body := _walker.get_node_or_null("Body") as Node3D
	if body != null:
		body.rotation_degrees = Vector3.ZERO
		body.position = Vector3(0.0, -KEEPY_MODEL_MIN_Y * KEEPY_SCALE, 0.0)
	if _magpie != null:
		_magpie.set_busy(false)
	_refresh_proximity()

## Lies him down if he has actually reached the bed. Returns whether it
## did, so the caller knows the landing is spent.
func _try_rest() -> bool:
	if _resting or _leaving or _bed == null:
		return false
	var here := _walker.global_position
	var flat := Vector2(here.x, here.z)
	if flat.distance_to(BED_SPOT) > BED_REACH:
		# NOT there yet. The intent is KEPT -- the pass-through landing the
		# owl batch's bug was made of.
		return false
	_rest_pending = false
	_enter_rest()
	return true

func _enter_rest() -> void:
	var body := _walker.get_node_or_null("Body") as Node3D
	if body == null:
		# Nothing to lay down. Refusing loudly beats a state with no body
		# in it, which would swallow every later tap as "get up".
		push_error("CabinInterior: cannot rest -- the walker has no Body.")
		return
	_resting = true
	_bed.set_busy(true)
	_controller.links[0].set_busy(true)
	# The marker stops breathing: it is not tappable while he is in it, and
	# a ring pulsing over a thing that refuses is a ring that lies.
	if _bed_marker != null:
		_bed_marker.set_near(false)
	# XZ is UNTOUCHED -- he lies exactly where he stood, so there is no
	# teleport to see. Only the height moves, onto the bedding that is
	# actually under him.
	_walker.global_position = Vector3(BED_SPOT.x, _world_y(BED_MODEL_Y), BED_SPOT.y)
	_walker.rotation_degrees = Vector3(0.0, REST_YAW_DEGREES, 0.0)
	body.rotation_degrees = Vector3(0.0, 0.0, REST_ROLL_DEGREES)
	# ⚠️ THE LIFT COMES OFF HIS X EXTENT, NOT HIS Y. The roll puts his
	# model X axis vertical, so the depth he hangs below his own origin is
	# now KEEPY_MODEL_MIN_X. Reusing the standing lift here would bury his
	# flank by the difference between the two -- the same class of mistake
	# that sank him 0.9166 into the floor, one axis over.
	body.position = Vector3(0.0, -KEEPY_MODEL_MIN_X * KEEPY_SCALE, 0.0)

## Gets him up. Everything is DERIVED rather than restored from a snapshot
## taken on the way in: a saved transform is a copy that goes stale the
## first time anything else moves him, and every value below already has
## exactly one owner.
##
## His YAW is deliberately left where the pose put it. He stands up facing
## the way he lay, which is what a body does; the next hop faces him again
## through LevelWalker._face().
func _wake() -> void:
	if not _resting:
		return
	_resting = false
	var body := _walker.get_node_or_null("Body") as Node3D
	if body != null:
		body.rotation_degrees = Vector3.ZERO
		body.position = Vector3(0.0, -KEEPY_MODEL_MIN_Y * KEEPY_SCALE, 0.0)
	var loft_level: LevelDefinition = _controller.levels[1]
	_walker.global_position = Vector3(BED_SPOT.x, loft_level.plane_y, BED_SPOT.y)
	if _bed != null:
		_bed.set_busy(false)
	_controller.links[0].set_busy(false)
	_refresh_proximity()

## THE ONE WAY OUT -- and since the debug "< Sortir" button was retired for
## production, the DOOR is the only thing that asks for it.
##
## It stays a named function rather than being inlined into the door's
## landing for two reasons: "what leaving means" is one fact worth having
## one home, and the withdrawal below is the boat's -- the door stops
## accepting taps the moment leaving starts, so a second tap falls THROUGH
## to the ground path instead of asking for a scene change already queued.
##
## ⚠️ NOTHING ABOUT THE DOORSTEP IS COMPUTED HERE, and that is the point.
## The hub derives the doorstep from the cabin's own position, scale and
## rotation, and it recorded it with HubSpawn on the way IN -- so this
## scene never has to know where on the plateau it stands. A second copy of
## that arithmetic in here is exactly how a door ends up on the wrong side
## of a building somebody turned in the layout.
##
## It also means this file has NO dependency on the plateau at all beyond
## the scene path: no HubBuilder, no HubRegion, no layout resource.
func _leave_to_hub() -> void:
	if _leaving:
		return
	_leaving = true
	if _door != null:
		_door.set_busy(true)
	get_tree().change_scene_to_file(HUB_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	# Release only, and both paths, for HubTapInput's measured reasons:
	# acting on the press would fire while a finger is still moving, and a
	# desktop click produces no touch event at all.
	var touch := event as InputEventScreenTouch
	if touch:
		if not touch.pressed:
			_controller.dispatch(touch.position)
			get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		_controller.dispatch(click.position)
		get_viewport().set_input_as_handled()
