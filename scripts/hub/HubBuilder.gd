extends Node3D
class_name HubBuilder
## Instantiates everything the plateau is made of, from HubLayout data.
##
## Nothing here decides WHERE anything goes -- that is entirely
## resources/hub/hub_layout.tres. This file only knows how to turn a type
## name into geometry, and it validates rather than trusts: a malformed
## entry is reported and skipped, because a typo in a decor file must
## never be the reason a player cannot reach their games.
##
## Prop meshes are built in code from primitives, deliberately. They are
## placeholders for this batch -- no Meshy credit is spent here -- and a
## primitive authored in code cannot drift from the layout the way a
## per-prop .tscn with its own baked transform would.
##
## Every material is UNSHADED, which is this project's standing rule for
## every surface (docs/MESHY_SPEC.md 8): the scene has no
## DirectionalLight3D, so a lit surface would render at whatever the
## ambient term alone gives it and its colour would stop being the colour
## that was authored.
##
## =====================================================================
## SCATTER PROPS ARE BATCHED, LANDMARKS AND PORTALS ARE NOT (25 aout 2026)
##
## tree / rock / bush / flower used to be a Node3D each with one
## or two MeshInstance3D children, which put the plateau at 259 draw nodes
## against a 260 ceiling -- one spare. They are now accumulated into a
## MultiMeshInstance3D per UNIQUE (mesh, colour) pair, filled in a second
## pass once every entry has been read.
##
## The unit of batching is the (mesh, colour) PAIR and not the semantic
## type, and the two do not line up: a tree contributes to two batches
## (trunk and crown are different meshes), a bush contributes TWO
## INSTANCES to one batch (its two lobes share a single SphereMesh at two
## offsets), and a flower's corolla splits three ways because its three
## tints are three different draws.
##
## Per-instance colour (MultiMesh.use_colors plus
## vertex_color_use_as_albedo) would collapse those three corolla nodes
## into one. It is NOT used: it would make the shipped material differ
## from the one this file used to build, on a batch nobody can look at
## before it is on staging, to save two nodes out of a budget this change
## empties. Three nodes carrying the exact material they carried before is
## the version whose parity can be proven rather than hoped for.
##
## WHAT STAYS AN INDIVIDUAL NODE, and why:
##
##   portal    it is an Area3D with a CollisionShape3D and a Label3D, and
##             HubWorld connects a signal to each one. A MultiMesh has no
##             per-instance node to connect to.
##   landmark  three silhouettes, 3 to 5 meshes each, 8 on the plateau --
##             batching them would trade 31 nodes for ~12 and lose the
##             per-variant readability of the tree.
##   pond      one instance on the plateau. There is nothing to batch,
##             and it is the only ALPHA-BLENDED surface on this screen --
##             together with lake, below.
##   lake       one instance, same reason as pond: nothing to batch. It is
##             built by the same _make_water_body() the pond is, so the two
##             cannot drift apart on the z-fight heights or on the
##             transparency flag that has to be asked for.
##   stream    one instance, and its mesh is a one-off ribbon built for its
##             own trace -- there is no shared mesh for a MultiMesh to
##             repeat. It is the third ALPHA-BLENDED surface here.
##   boat      one instance, and it is MOVED every frame of a ride. A
##             MultiMesh instance can be moved, but the hull also has to be
##             handed to BoatMooring as a node -- and there is exactly one,
##             so there is nothing to batch either way.
##   stump     14 on the plateau at one mesh each. Batching would save 13
##             nodes out of the ~220 this change frees; measured and left
##             individual until the count makes the indirection worth it.
##
## NO COLLISION IS LOST. tree / rock / bush / flower / stump / pond / lake /
## stream / boat have never
## had a CollisionShape3D -- grepped, not assumed -- so nothing on the
## plateau depends on a per-prop physics node. The ground is not a
## collider either: HubTapInput intersects a maths Plane rather than
## raycasting. The only Area3D on this screen belongs to HubPortal, which
## is exactly what this change leaves alone.

## The plateau's contents. Swap this resource and the whole screen
## re-lays-out with no code change -- the point of the split.
@export var layout: HubLayout

## Scene instantiated for every &"portal" entry.
@export var portal_scene: PackedScene

## Scene instantiated for every &"owl" entry -- the imported
## assets/models/keepy_owl_decor.glb, the first hub prop that is a Meshy
## model rather than a primitive built in this file. Same pattern as
## portal_scene: assigned once on the HubBuilder node in HubWorld.tscn,
## instantiated per entry by _make_owl().
@export var owl_scene: PackedScene

## Scene instantiated for every &"cabin" entry -- the imported
## assets/models/keepy_cabin_decor.glb, the tree-house Keepy ducks into.
##
## Same shape as owl_scene and for its reason: a .glb is a PackedScene, and
## a prop whose only appearance IS that scene has no placeholder to fall
## back to, so it is instantiated directly rather than through a ModelSlot
## -- which exists to swap a stand-in for a model, a job with no second
## side here. Assigned in HubWorld.tscn; one is instantiated per entry by
## _make_cabin().
@export var cabin_scene: PackedScene

## Scene drawn INSIDE every &"cabin" -- assets/models/keepy_magpie_prop.glb,
## the same bird CabinInterior stands on the living-room floor.
##
## PURELY DECORATIVE OUT HERE, and that is a decision rather than an
## omission. The plateau already shows this cabin in cutaway -- the table,
## the chairs, the bear and the ladder are baked into the .glb itself --
## so the one piece of that room the player could NOT see before walking in
## was the magpie, because she is the one piece built in code. She is drawn
## here so the room reads the same from outside as from inside; she is
## given no hotspot, no tap radius and no signal, because the kiss lives in
## CabinInterior and one bird with two ways to be talked to is two birds.
##
## Same shape as cabin_scene and for its reason: a .glb is a PackedScene
## with no placeholder to fall back to. Assigned in HubWorld.tscn.
@export var magpie_scene: PackedScene

const TRUNK_COLOR: Color = Color(0.20, 0.13, 0.08)
const CROWN_COLOR: Color = Color(0.17, 0.34, 0.13)
const ROCK_COLOR: Color = Color(0.26, 0.27, 0.24)
const BUSH_COLOR: Color = Color(0.21, 0.39, 0.16)

## Flower colours, LOCAL to the hub on purpose. SwampPalette.gd carries the
## identity Chased and the plateau share; these are hub-local decor, read by
## nothing else, and its own header says that kind of colour stays here
## rather than being promoted into the shared resource.
const FLOWER_STEM_COLOR: Color = Color(0.19, 0.35, 0.14)

## Three corolla tints rather than one: a field of a single colour reads as
## a repeated instance, which is exactly what it is. Entries pick one with
## an optional "variant" int; anything out of range falls back to 0 so a
## layout written without the field still builds.
##
## One MultiMesh batch each -- see the header. The batch keys are kept in
## step with this array by _FLOWER_PETAL_KEYS below.
const FLOWER_PETAL_COLORS: Array[Color] = [
	Color(0.93, 0.86, 0.42),
	Color(0.86, 0.52, 0.62),
	Color(0.72, 0.66, 0.88),
]

## Batch key per corolla tint, index-aligned with FLOWER_PETAL_COLORS. A
## fourth tint means a fourth entry in both, and the assert in _ready()
## fails loudly rather than silently drawing every extra tint as tint 0.
const _FLOWER_PETAL_KEYS: Array[StringName] = [
	&"FlowerPetal0",
	&"FlowerPetal1",
	&"FlowerPetal2",
]

## Landmark colours, LOCAL to the hub for the same reason as the flower
## tints above -- decor, not the identity SwampPalette carries.
##
## Deliberately LIGHT. A landmark's top pokes just above the horizon line
## (the camera's -34 deg pitch leaves the top of the frame ~2.4 deg above
## horizontal), so it is read against the sky, and the sky here is the
## near-black swamp green. A dark silhouette against a dark sky is not a
## landmark, it is a hole.
## The pond. Its water is the ONLY alpha-blended surface on the plateau:
## an opaque disc reads as a painted circle, and the point of a pond as a
## destination is that it reads as a hole in the ground rather than a mark
## on it. The bank is opaque and slightly wider, so the water has an edge
## to sit inside instead of ending on bare ground.
##
## Blue-green rather than blue. The ground is swamp green and the sky is
## near-black green: a saturated blue would be the only thing on this
## screen with no relation to anything else on it.
## SPAWN-LAKE-1: ONE COLOUR FOR EVERY WATER ON THE PLATEAU -- #40E0D0,
## rgb(0.2510, 0.8784, 0.8157). This REPLACES the WATER-HUE-2 saturation
## family (B) wholesale, and the replacement is a decision rather than a
## tuning pass: family B separated four bodies by SATURATION alone because
## three of them touch, and Mathieu judged the result on device -- the
## stream washed out, the great lake reading as glacier. Separation by
## saturation is ABANDONED. Every body now carries the one turquoise he
## approved on screen, which was already, exactly, the small lake's albedo.
##
## WHAT THAT COSTS, said plainly: with the colour shared, ALPHA is the only
## lever left. There is nothing else to trade if a body will not clear the
## contrast floor.
##
## ⚠️ ALPHA IS SWEPT, NEVER SOLVED. WATER-HUE-1 fitted an affine model to
## two points and it UNDERSHOT all four bodies -- every one landed at
## 2.48-2.94:1 at its predicted alpha, under the floor. Two points define a
## line; they do not prove linearity. scripts/dev/WaterAlphaSweep.tscn
## measures every 0.05 step against the hub's own ground (#2C5A20,
## Lrel 0.0799) through a per-body render mask, and the values below are
## read off that table.
##
## This body: a=0.95 -- 0.90 reaches 2.99:1 in its own view, a hair under,
## and 0.95 reaches 3.22:1.
const POND_WATER_COLOR: Color = Color(0.2510, 0.8784, 0.8157, 0.95)
const POND_BANK_COLOR: Color = Color(0.22, 0.21, 0.15)
const POND_WATER_RADIUS: float = 3.2
const POND_BANK_RADIUS: float = 3.62
const POND_SEGMENTS: int = 24

## The lake -- the pond's silhouette at 2.5x, far out in the outer ring as
## a second, bigger destination. LOCAL to the hub for the same reason every
## other decor colour here is: SwampPalette carries the identity Chased and
## the plateau share, not the plateau's own scenery.
##
## ⚠️ PRE-WATER-HUE-2 REASONING, SUPERSEDED TWICE. Kept for the record, not
## as a description of the shipped colour: it described a lake separated
## from the pond by HUE (198.0 vs 221.5 deg). Family B abandoned that for
## SATURATION, and SPAWN-LAKE-1 abandons per-body colour entirely -- see
## POND_WATER_COLOR's docblock, which owns the shared colour and the alpha
## rule for all five bodies.
##
## #40E0D0 was ALREADY this body's albedo under family B: it is family B's
## anchor and family B put that anchor on the small lake. So the uniform
## colour changes nothing here except its neighbours.
##
## This body: a=0.95 -- 0.90 reaches 2.82:1 in its own view and 0.95 reaches
## 3.04:1, the tightest clearance of the five. It also drops a hair from the
## shipped 0.96, which the WATER-HUE-2 report had already flagged as far
## enough toward opaque to cost the body its depth.
const LAKE_WATER_COLOR: Color = Color(0.2510, 0.8784, 0.8157, 0.95)

## 2.5x the pond on both discs (3.2 -> 8.0, 3.62 -> 9.05), so the rim keeps
## the same proportion rather than becoming a hairline on a much bigger disc.
##
## NAMED "SMALL_LAKE", not "LAKE": `HubRegion.gd` used to carry its own
## `LAKE_WATER_RADIUS` for the great lake (16.0, two lobes) -- same
## identifier, two different bodies, two different files. A pure rename, no
## value change on either side; see `HubRegion.GREATLAKE_WATER_RADIUS`.
const SMALL_LAKE_WATER_RADIUS: float = 8.0
const LAKE_BANK_RADIUS: float = 9.05

## Deliberately NOT the pond's 24, and not 2.5x it either. What matters is
## the ABSOLUTE facet deviation, and that scales with the radius: a circle
## of radius 8.0 drawn with the pond's 24 segments would bulge inward by
## 0.068 units between vertices against the pond's own 0.027 -- visibly
## faceted at this size, on the largest flat surface on the plateau. 40
## segments bring it to 0.0247 (bank 0.0279), i.e. marginally FLATTER per
## facet than the pond despite 2.5x the radius, for 16 extra segments.
## Still a low, explicit tessellation -- the docs/MESHY_SPEC.md 7.2 rule --
## just calibrated to the size instead of inherited from a smaller disc.
const LAKE_SEGMENTS: int = 40

## The stream that runs from the pond to the lake. A THIRD water tint, LOCAL
## to the hub like every other decor colour here.
##
## ⚠️ PRE-WATER-HUE-2 table, superseded -- kept for the record:
##   pond    hsv(198.0, 0.556, 0.36)  dark teal
##   lake    hsv(221.5, 0.634, 0.82)  light blue
##   stream  hsv(190.9, 0.512, 0.86)  bright cyan
## Under that palette each pair was told apart on a different axis (stream
## vs pond by VALUE, stream vs lake by HUE). Family B (WATER-HUE-2) narrows
## every hue into 170-180 deg and separates instead by SATURATION -- see
## POND_WATER_COLOR's docblock for the measured reason. Family B's own
## table:
##   pond       hsv(170.0, 0.922, 1.00)
##   lake       hsv(174.0, 0.714, 0.88)
##   stream     hsv(180.0, 0.278, 1.00)
##   great lake hsv(177.6, 0.200, 1.00)
## =====================================================================
## THE GREAT-LAKE LOBES, THE ISLETS AND THE PONTOONS
##
## The great lake is a THIRD standing water, twice the small lake across.
## It shipped OUTSIDE the square (radius 20, centre 54 out along the small
## lake's azimuth) and LAKE-MOVE brought it INSIDE, to (15.5, -19) at
## radius 16 -- the only placement the recon measured as clearly visible
## from the plateau centre, and the largest radius that fits the square at
## all. Those numbers are not re-derived here: HubRegion owns them, because
## the walkable region is built from the same ones and a second copy would
## be free to drift.
##
## SPAWN-LAKE-1 made it TWO lobes of the same family: a second disc at
## (-12, -19.5) radius 10, in front of the spawn. Everything below serves
## both -- the maker takes the radius from HubRegion and the slab height
## from the lobe's row in GREATLAKE_*_SLABS -- and the ONE thing that
## differs between them is that height.
##
## ⚠️ COLOUR: SUPERSEDED, and the paragraphs below are kept only as the
## record of how it got here. Since SPAWN-LAKE-1 there is no "fourth water
## tone": every body on the plateau is #40E0D0 and the whole subject lives
## in POND_WATER_COLOR's docblock.
##
## ⚠️ PRE-WATER-HUE-2 table, superseded -- kept for the record (the great
## lake used to be a deep indigo, separated from the other three by hue AND
## value):
##   pond    hsv(198.0, 0.56, 0.36)   dark teal
##   lake    hsv(221.5, 0.63, 0.82)   light blue
##   stream  hsv(190.9, 0.51, 0.86)   bright cyan
##   great   hsv(254.6, 0.62, 0.60)   deep indigo   <- this one, then
##
## ⚠️ SUPERSEDED BY SPAWN-LAKE-1 -- record only, not the shipped rule:
## WATER-HUE-2 (family B) narrows every hue into 170-180 deg instead and
## separates the pair that touched AT THE TIME -- the small lake and this
## one, then 0.347 u apart; LAKE-MOVE has since pulled them 18.849 u apart
## and every colour here is deliberately UNCHANGED by it, so that a recolour
## is its own batch with its own measurements rather than a side effect
## -- by SATURATION: dSAT 0.421 against family A's 0.188 and family C's
## 0.291, measured on the rendered plate, not the albedo alone (see
## POND_WATER_COLOR's docblock). Family B's table is in STREAM_WATER_COLOR's
## docblock, just above.
##
## HEIGHTS: the great lake's slabs sit BELOW the small lake's. That was
## forced when the two touched -- at radius 20 and distance 54 their waters
## came within 0.347 u and their banks OVERLAPPED by 2.003, and two opaque
## discs at one height z-fight. LAKE-MOVE separates them by 18.849 u of
## open water (16.499 bank to bank), so nothing forces the stack any more. It is KEPT anyway: the
## order is measured, gated by LakeZoneProbe, and costs nothing, whereas
## flattening it would be an unforced change to geometry nobody can look at
## before staging. If a later batch ever brings two waters back into
## contact, the resolution is already here.
##
##   ground        y = 0
##   great bank    y = 0.002 .. 0.013
##   great water   y = 0.015 .. 0.027
##   small bank    y = 0.005 .. 0.055   (unchanged)
##   small water   y = 0.020 .. 0.080   (unchanged)
##   islet         y = 0.030 .. 0.060
##   pontoon deck  y = 0.045 .. 0.095
##   stream        y = 0.095            (unchanged)
##
## The slabs are also THINNER than the pond's, for the reason the pond's
## own docblock gives for not scaling them at all: a lake-sized slab thick
## enough to see is a lake showing its own edge.
## SPAWN-LAKE-1: #40E0D0 like every other water here -- see
## POND_WATER_COLOR's docblock for the decision and the sweep rule. This
## constant now colours BOTH great-lake lobes, so they cannot disagree, and
## that is the point: the two are 1.505 u apart water to water and are meant
## to read as one mass in two lobes.
##
## ⚠️ THE ONLY BODIES THAT DO NOT CLEAR 3.0:1 EVERYWHERE THEY ARE VISIBLE,
## and the number is published rather than rescued. a=0.95 clears in each
## lobe's OWN view (great 3.14:1, spawn 3.22:1) and that is the value
## shipped -- the smallest step that clears where the body is the subject.
## Seen from across the plateau it cannot clear at ANY alpha up to 1.00:
##
##   view        distance   fog     best (a=1.00)
##   pond          49.6 u   54.8%   2.54:1   <- great lobe
##   twolobes      41.7 u   48.7%   2.89:1   <- great lobe
##   laketail      45.1 u   51.4%   2.68:1   <- spawn lobe
##   twolobes      42.2 u   49.1%   2.87:1   <- spawn lobe
##
## That is the exponential fog (hub_fog_density 0.016 toward a near-black
## green), not the colour: it has replaced half the surface before alpha
## gets a say, and it does the same to every opaque thing at that range.
## Pushing to 1.00 buys a failure AND costs the translucency that makes a
## lake read as a hole in the ground rather than a mark on it.
const GREATLAKE_WATER_COLOR: Color = Color(0.2510, 0.8784, 0.8157, 0.95)
## Bank margin, NOT the pond's 0.42 scaled up. It was sized when the two
## lakes touched: proportional scaling would have put the ring at 22.625
## and pushed its inner edge 2.0 further into the small lake. LAKE-MOVE
## ends that contact, and the margin is UNCHANGED -- 1.30 is a shore width
## that reads at this scale, and re-tuning it would move a rendered edge
## this batch cannot look at.
##
## ⚠️ It is also what puts the bank ring 1.06 u ACROSS the Battle portal's
## pad: at the shipped centre the portal sits 17.59 from the lake centre,
## so its 1.35 pad reaches to 16.24 while the bank runs out to 17.30. The
## WATER still clears the pad by 0.24, so nothing is walkable-into-water;
## it is a visual overlap and it is reported rather than papered over.
## Clearing it needs the centre at x >= 18, which is a different placement
## than the one that was chosen.
const GREATLAKE_BANK_MARGIN: float = 1.30
## 96 segments: sized against facet deviation r(1-cos(pi/n)), which grows
## with r. At the shipped radius of 20 that is 0.0107; at 16 it is 0.0086,
## flatter still. Left at 96 -- the disc did not get coarser by getting
## smaller, and a segment count is not worth a rendered change to re-tune.
const GREATLAKE_SEGMENTS: int = 96

## Slab thickness and centre height, ONE ROW PER LOBE, in HubRegion.lakes()
## order. Two rows since SPAWN-LAKE-1, and the second row is not cosmetic:
## the two lobes' BANK rings overlap by 1.096 u (their waters stay 1.505
## apart, so no water is ever drawn over water, but the opaque shore rings
## do interpenetrate). Two opaque discs at the SAME height z-fight; at
## different heights the higher one simply wins, and since both rings are
## POND_BANK_COLOR the seam is invisible either way. So the second lobe is
## lifted 2.5 mm, which is below anything else on this screen and above the
## first lobe's own stack:
##
##   great bank    y = 0.0020 .. 0.0130
##   great water   y = 0.0150 .. 0.0270
##   spawn bank    y = 0.0045 .. 0.0155
##   spawn water   y = 0.0175 .. 0.0295
##
## The spawn lobe's bank also overlaps the SMALL lake's bank by 1.030 u,
## and that one is settled by the small lake's own stack rather than here:
## its bank top is 0.055, well above both rows, so it wins that lens.
const GREATLAKE_BANK_SLABS: Array[Vector2] = [
	Vector2(0.011, 0.0075),
	Vector2(0.011, 0.0100),
]
const GREATLAKE_WATER_SLABS: Array[Vector2] = [
	Vector2(0.012, 0.0210),
	Vector2(0.012, 0.0235),
]

## An islet: a flat shingle disc just proud of the great lake's surface,
## there to carry a landmark out where the water is.
##
## FLUSH ON PURPOSE. KeepyHopper flattens y to 0 on every write it makes to
## a position (measured, in _apply_hop and _on_hop_finished both), so there
## is no landing height in its API and this batch deliberately does not add
## one. An islet 3 cm proud of the water reads as flush and costs nothing;
## a real raised quay would visibly break, and would need that API first.
## PALE, and that was a render finding rather than a preference. The first
## pass used the banks' dark olive; against the great lake's indigo it read
## as a HOLE in the water rather than as land standing in it. A shingle
## light enough to sit above the water's own value fixes it, and it is the
## only islet colour this file has ever had reason to want.
const ISLET_COLOR: Color = Color(0.46, 0.43, 0.31)
const ISLET_RADIUS: float = 3.2
const ISLET_SEGMENTS: int = 24
const ISLET_THICKNESS: float = 0.030
const ISLET_CENTRE_Y: float = 0.045

## A pontoon. One plank slab, batched, top face landing on the stream's own
## surface height so every flush thing on this screen sits on one line.
##
## It has NO function in this batch. It marks where boarding will happen
## when the lake gets a boat; today it is scenery, and nothing reads it.
const PONTOON_COLOR: Color = Color(0.38, 0.27, 0.17)
const PONTOON_LENGTH: float = 2.60
const PONTOON_WIDTH: float = 1.10
const PONTOON_THICKNESS: float = 0.05
const PONTOON_CENTRE_Y: float = 0.07

## SPAWN-LAKE-1: #40E0D0 like every other water here -- see
## POND_WATER_COLOR's docblock for the decision and the sweep rule.
##
## This body: a=0.90, and it is the ONE body that needs less than 0.95. Not
## a coincidence and not a rounding: the stream has no bank under it, so it
## alpha-blends straight onto the GROUND, while the four discs blend onto
## their own dark olive rim. It clears in all five views at 0.90 (worst
## 3.09:1) where 0.85 leaves it at 2.91:1.
## =====================================================================
## THE DIVING BOARD
##
## A ladder on the bank, a deck cantilevered out over the great lake, and
## the one piece of hub furniture Keepy can be ON rather than merely walk
## past. The states that use it live in KeepyHopper; this file only draws
## it and publishes where its two ends are.
##
## AUTHORED BY ITS TWO ENDS, NOT BY A ROTATION. The entry carries the
## ladder foot (its "position"), the deck anchor Keepy stands on (its
## "deck_anchor", y included) and the way a dive faces ("dive_direction").
## The geometry is then built to CONNECT those, so the plank the player
## sees and the point the state machine puts them on cannot drift apart --
## there is one source for each fact rather than a rotation here and a
## world position there saying the same thing twice.
##
## That is also why "rotation_y" and "scale" are refused on this type, the
## same way &"stream" refuses them: a second orthography of the facing
## would be free to disagree with the first.

## Deck plank. Length is authored per entry (it has to reach past the
## waterline, which is a property of where it is planted); the cross
## section is fixed here because it is the same plank everywhere.
const DIVINGBOARD_DECK_WIDTH: float = 0.95
const DIVINGBOARD_DECK_THICKNESS: float = 0.10

## How far the plank overhangs BEHIND the ladder. Small, and load-bearing
## for the reading: a deck that stopped exactly at the ladder would look
## like it was balanced on it rather than fixed to it.
const DIVINGBOARD_DECK_BACK_OVERHANG: float = 0.35

## Ladder rails: two uprights, this far either side of the centre line.
## The rungs span between them, so this is also half a rung's length.
const DIVINGBOARD_RAIL_HALF_SPAN: float = 0.34
const DIVINGBOARD_RAIL_RADIUS: float = 0.05

## Rungs. Spacing is a TARGET -- the count is rounded so the run divides
## evenly, because a last rung crammed against the deck reads as a mistake.
const DIVINGBOARD_RUNG_RADIUS: float = 0.035
const DIVINGBOARD_RUNG_SPACING: float = 0.30
const DIVINGBOARD_RUNG_LOWEST: float = 0.30

## Support posts under the deck: a pair at the ladder and a pair near the
## tip, standing in the water.
const DIVINGBOARD_POST_RADIUS: float = 0.09
const DIVINGBOARD_POST_HALF_SPAN: float = 0.36
const DIVINGBOARD_POST_TIP_INSET: float = 0.45

## How far past the anchor a dive lands, along the facing. Far enough that
## Keepy clears the plank he left rather than dropping alongside it.
const DIVINGBOARD_DIVE_REACH: float = 2.20

## Timber. BOTH REUSED, deliberately: the deck takes the pontoons' own
## plank colour and the frame takes the boat hull's darker one, so the
## board reads as built from what is already on this water rather than
## introducing a colour nobody has judged on a sheet.
const DIVINGBOARD_DECK_COLOR: Color = PONTOON_COLOR
const DIVINGBOARD_FRAME_COLOR: Color = BOAT_HULL_COLOR

const STREAM_WATER_COLOR: Color = Color(0.2510, 0.8784, 0.8157, 0.90)

## 1.2 units across. Half of that -- 0.6 -- is the number the trace was
## routed against: every prop's GROUND footprint clears the water's edge by
## at least 0.39, measured on the shipped layout rather than eyeballed.
const STREAM_WIDTH: float = 1.2

## Above the ground plane (y = 0), above the ponds' banks (top 0.055) and
## above their water (top 0.08), so it is never coplanar with any of them.
## The trace ends exactly on each water body's WATER rim, so the ribbon
## crosses the bank ring from outside and stops where the water starts:
## it covers the rim rather than leaving a gap, and it never overlaps an
## alpha surface with another alpha surface.
const STREAM_SURFACE_Y: float = 0.095

## Samples per control-point span. 8 gives 89 samples over the shipped
## 12-point trace, i.e. 176 triangles for the whole watercourse -- less
## than the lake's two discs cost on their own. Explicit rather than
## inherited, the docs/MESHY_SPEC.md 7.2 rule, and it is what fixes the
## curve's sagitta: doubling it halves the flat-edge deviation.
const STREAM_SAMPLES_PER_SPAN: int = 8

## =====================================================================
## THE BOAT, AND WHY ITS LENGTH IS A CALCULATION AND NOT A TASTE
##
## The hull rides the stream spine, so it has to fit inside the ribbon at
## the TIGHTEST bend the trace takes. Both numbers come from the shipped
## geometry rather than from a guess: StreamGeometryProbe measures the
## spine's minimum radius of curvature at 1.4058 u (sample 48) and the
## ribbon's half-width is the layout's own width / 2 = 0.6 u.
##
## A RIGID hull of length L and beam B, centred on the spine and turned
## along the tangent, has its worst point at an OUTER CORNER. On a circle
## of radius R that corner sits at
##
##     sqrt((R + B/2)^2 + (L/2)^2)
##
## from the circle's centre, so it leaves the spine by that minus R. The
## hull stays on the water while
##
##     sqrt((R + B/2)^2 + (L/2)^2) - R  <=  half-width
##
## At R = 1.4058, half-width 0.6, the shipped BOAT_LENGTH 0.78 and
## BOAT_BEAM 0.86 give 0.4709 u of corner excursion -- 0.1291 u of margin.
## The brief's ceiling of 0.80 x 1.00 would give 0.5415 and only 0.0585,
## which is why neither is taken to its limit. That inequality is asserted
## on the built spine by StreamRideProbe rather than left as a comment:
## re-trace the stream and the margin moves, and it must fail loudly if it
## ever goes negative.
##
## The corner form is CONSERVATIVE for this hull -- the shell is rounded,
## so its real extreme is inside the rectangle the formula bounds. Being
## conservative is the point: a bound that a future, boxier hull would
## still satisfy.
const BOAT_LENGTH: float = 0.78
const BOAT_BEAM: float = 0.86

## Depth of the shell below its rim, and the width of the rim lip.
const BOAT_DEPTH: float = 0.24
const BOAT_RIM: float = 0.09

## Ring/tier counts on the shell. Explicit, low, and calibrated to a hull
## under a metre across -- the same reasoning LAKE_SEGMENTS carries, and
## the same trap (a primitive left at Godot's default tessellation) that
## docs/MESHY_SPEC.md 7.2 caught on the collectibles.
const BOAT_RADIAL_SEGMENTS: int = 16
const BOAT_TIERS: int = 4

## How far the inner shell is set inside the hull, so the dark outer wall
## still reads as a thickness at the rim.
const BOAT_INNER_INSET: float = 0.06

## Height of the RIM above the ground plane.
##
## MEASURED, after the first version was wrong in a way no error reported.
## The shell hangs BOAT_DEPTH below its rim, so at the original 0.16 the
## keel sat at -0.08 -- under the ground plane, which is opaque at y = 0.
## Everything below the waterline was therefore clipped by the ground and
## the boat rendered as a hollow RING with the lake visible straight
## through it. Caught on a render, not in review; the geometry was correct
## the whole time and simply drawn inside the floor.
##
## At 0.30 the keel sat at 0.06, which cleared the floor but left a SECOND
## artifact the same render showed: the stream's own surface is at
## STREAM_SURFACE_Y = 0.095, ABOVE that keel, so the water plane cut
## through the inside of the shell and a sliver of stream was visible in
## the bottom of the boat.
##
## 0.34 puts the keel at 0.10 -- five millimetres over the stream's
## surface and two centimetres over the lake's, so it seats ON the
## waterline with nothing showing through, and the gap is far too small to
## read as hovering at a hull this size.
const BOAT_FLOAT_Y: float = 0.34

## Hull colours, LOCAL to the hub like every other decor colour in this
## file -- SwampPalette carries the identity Chased and the plateau share,
## not a prop tint.
##
## A nutshell, so the outside is bark-dark and close to the trees it came
## from; the rim is the cut edge, and the INSIDE is lighter still.
##
## The inner shell is not decoration. MEASURED on a render: with the hull
## drawn as one double-sided surface, what the camera sees of a bowl at
## this pitch is mostly the INSIDE of the far wall -- so a single dark
## tone made the boat read as a hole in the bank rather than as an object,
## the more so because it moors on the lake's own dark bank ring. Three
## tones, dark outside to light inside, is what turns the same silhouette
## into an open shell.
##
## The hull is also lifted off the trees' bark colour rather than sharing
## it (the way stump does): a stump beside a tree is telling a story, a
## boat lost against a bank is just missing.
const BOAT_HULL_COLOR: Color = Color(0.33, 0.21, 0.12)
const BOAT_INNER_COLOR: Color = Color(0.74, 0.60, 0.40)
const BOAT_RIM_COLOR: Color = Color(0.88, 0.76, 0.55)

## ---------------------------------------------------------------------
## THE TURNSTILE -- a playground roundabout, and the plateau's first prop
## with a MOVING part.
##
## Sizes rather than a scale factor, for the reason every other prop here
## states its own: the layout's `scale` is a uniform float applied to the
## whole node, and a roundabout whose bars grew with its deck would stop
## being a roundabout the moment anyone tuned one of the two.
##
## THE BASE DOES NOT TURN. It is a separate, slightly wider, very flat disc
## left OUTSIDE the spinner on purpose: a rotation is only readable against
## something that stays put, and a turnstile whose footing swung with it
## would read as the whole prop sliding rather than as a top spinning.
const TURNSTILE_BASE_RADIUS: float = 1.35
const TURNSTILE_BASE_THICKNESS: float = 0.06
const TURNSTILE_BASE_SEGMENTS: int = 20

const TURNSTILE_DECK_RADIUS: float = 1.15
const TURNSTILE_DECK_THICKNESS: float = 0.10
const TURNSTILE_DECK_Y: float = 0.26
const TURNSTILE_DECK_SEGMENTS: int = 20

const TURNSTILE_POST_RADIUS: float = 0.10
const TURNSTILE_POST_HEIGHT: float = 0.72

## The grip bars. A count, not a hardcoded four: the proportions sheet for
## this batch compares three against four and neither is device-validated.
const TURNSTILE_BARS: int = 4
## ⚠️ 0.06 AND NOT 0.045, and that came off a render rather than off a
## preference: at 0.045, from this screen's 34-degree camera, the bars read
## as twigs lying ON the deck instead of as rails standing above it.
const TURNSTILE_BAR_RADIUS: float = 0.06
const TURNSTILE_BAR_Y: float = 0.62
## Stopped just inside the deck rim so a bar end never pokes out past the
## thing it is bolted to.
const TURNSTILE_BAR_LENGTH: float = TURNSTILE_DECK_RADIUS - 0.13

## How far out from the pivot a rider stands. DERIVED, not chosen -- the
## geometry leaves exactly one window and this is its outer end.
##
## A rider faces OUTWARD (Mathieu's call), so the model's long axis lies
## along the radius: measured on the shipped .glb, Keepy is 2.0371 deep,
## which puts his TAIL at ride_radius - 1.0187. The centre post is 0.10
## across and stands from the deck up to local y 0.98 -- straight through
## the height his body occupies -- so the tail clears it only while
##
##     ride_radius >= 1.0187 + TURNSTILE_POST_RADIUS  ->  >= 1.1187
##
## and the deck rim is at 1.15. The whole legal window is [1.119, 1.150],
## which is under four centimetres wide, and the rim is its natural end:
## "on the edge" is what was asked for, and anything further in only moves
## the tail closer to the post it has to miss.
##
## ⚠️ HIS NOSE OVERHANGS, and that is measured rather than hidden: at this
## radius the model reaches 2.17 from the pivot against a 1.15 deck and a
## 1.35 footing. Keepy is 2.04 long and the deck is 2.30 across, so a body
## facing outward on it cannot be contained by it at any radius at all --
## the overhang is a property of the two sizes, not of this number. Turning
## him TANGENTIALLY would fit him (his width is only 1.32), and that is the
## one lever if the device says the overhang reads badly.
const TURNSTILE_RIDE_RADIUS: float = TURNSTILE_DECK_RADIUS

## How close a landing has to be to shove it. A property of THIS PROP's
## reach and not of the gesture, which is why it is published per entry in
## spinning_props() rather than held as one number by the caller: the
## ladder's tap radius is the same number for every board because a thumb
## is the same size everywhere, but a bigger roundabout would want a bigger
## reach.
##
## Base rim plus about a step: a landing a metre outside the footing is a
## player standing AT it, and a landing further than that is one walking
## past.
const TURNSTILE_TRIGGER_RADIUS: float = 2.40

## No new colours. The deck is the pontoon plank, the frame is the boat's
## PALE RIM, and the footing is the scatter rock -- so the prop is built out
## of the same wood and stone the plateau already is, and nothing here
## installs a hue that has never been on a sheet.
##
## ⚠️ THE FRAME IS THE RIM AND NOT THE HULL, and that is a render finding,
## not a taste. The first pass used BOAT_HULL_COLOR -- which is what the
## diving board's frame borrows -- and against a PONTOON_COLOR deck the two
## browns are close enough that the centre post DISAPPEARED and the bars
## read as marks drawn on the plank. The prop stopped being a roundabout and
## became a plate. The rim is the pale wood already on the boat, so the hub
## and its rails separate from the deck they are bolted to.
const TURNSTILE_DECK_COLOR: Color = PONTOON_COLOR
const TURNSTILE_FRAME_COLOR: Color = BOAT_RIM_COLOR
const TURNSTILE_BASE_COLOR: Color = ROCK_COLOR

## =====================================================================
## THE SEESAW -- the plateau's second prop that answers a landing.
##
## Built to the TURNSTILE's pattern deliberately, because the turnstile
## already paid for it: a static part, a pivot, a rider written onto that
## pivot in the same call that turns it, and a published registry the ride
## reads instead of re-deriving anything. What differs is one axis. The
## turnstile turns about Y and its rider's height never changes; a seesaw
## tilts about Z and his does, which is why the seat is a LOCAL offset
## through the pivot rather than a world position -- the same construction,
## carrying one more thing for free.
##
## THE PLANK RUNS ALONG X, and that is a readability choice rather than an
## arbitrary axis. HubCamera never yaws: it looks down -Z with a fixed
## -34 deg pitch, so a plank along X is broadside to it and its tilt reads
## as one end up and the other down in SCREEN vertical. A plank along Z
## would tilt toward and away from the camera, which is the one direction a
## fixed camera renders as almost no movement at all.
const SEESAW_FULCRUM_RADIUS: float = 0.30
const SEESAW_FULCRUM_SEGMENTS: int = 10

## Fulcrum height, and it is NOT a look: it is what keeps the low end of the
## plank above the ground at full tilt. The far corner of a tilted plank
## sits at
##
##   y = fulcrum - (length/2)*sin(tilt) - (thickness/2)*cos(tilt)
##     = 0.62 - 1.80*sin(15) - 0.07*cos(15) = 0.0865
##
## which is positive, so the plank never enters the ground -- with 8.6 cm to
## spare rather than by luck. SeesawProbe gates that inequality against the
## shipped numbers, so a later batch that lengthens the plank or deepens the
## tilt is told rather than left to sink it.
const SEESAW_FULCRUM_HEIGHT: float = 0.62

const SEESAW_PLANK_LENGTH: float = 3.60
const SEESAW_PLANK_WIDTH: float = 0.62
const SEESAW_PLANK_THICKNESS: float = 0.14

## Grip posts, one at each end, batched into ONE MultiMeshInstance3D for the
## reason the turnstile bars are: two instances of one mesh is one node, and
## the batch is also where the TRANSFORM_3D discipline lives.
const SEESAW_GRIPS: int = 2
const SEESAW_GRIP_RADIUS: float = 0.055
const SEESAW_GRIP_HEIGHT: float = 0.34
const SEESAW_GRIP_SEGMENTS: int = 6

## How far out along the plank a rider sits, and the grip sits OUTBOARD of
## him so he holds it rather than standing inside it -- the same problem the
## turnstile solved by snapping its seat to a gap between bars.
const SEESAW_RIDE_X: float = 1.38
const SEESAW_GRIP_X: float = 1.72

## The trigger radius: how close a landing has to be to set the plank
## rocking and put him on it. Larger than the turnstile's footing because
## the prop it has to cover is a 3.6 u plank rather than a 2.3 u disc, and
## sized from the plank rather than picked -- half the length plus the same
## reach the turnstile allows past its own footing.
const SEESAW_TRIGGER_RADIUS: float = SEESAW_PLANK_LENGTH * 0.5 + 0.80

## The plank and the fulcrum reuse the pontoon plank and the rock, exactly
## as the turnstile reuses the pontoon and the boat rim: no new colour is
## introduced by a decor prop, and a wooden plank on a stone pivot is what
## the two already are.
const SEESAW_PLANK_COLOR: Color = PONTOON_COLOR
const SEESAW_GRIP_COLOR: Color = BOAT_RIM_COLOR
const SEESAW_FULCRUM_COLOR: Color = ROCK_COLOR

## =====================================================================
## ZIPLINE -- TIER 1: THE STRUCTURE ONLY (3 septembre 2026)
##
## Two towers and the cable between them. NO interaction, NO ride, NO tap
## channel of any kind -- tier 2 owns all of that. What ships here is
## geometry a device can be pointed at, and the published facts tier 2
## will read rather than re-derive.
##
## AUTHORED BY ITS TWO ENDS, exactly like &"divingboard" and for the same
## reason: the entry carries "position" (the near tower) and "far_end"
## (the far one), and everything else -- the facing of each tower, where
## each stair runs, where the cable is strung -- is BUILT from those two
## points. A second orthography of the facing (a "rotation_y", a per-tower
## entry) would be free to disagree with the first, so this type refuses
## rotation_y and scale the way &"stream" and &"divingboard" do.
##
## ONE ENTRY, TWO TOWERS. A zipline is not two props that happen to face
## each other -- a cable that started at one end and missed the other is
## the failure this shape makes unrepresentable. It is also why
## ground_footprints() and _build's walkability check both read
## _zipline_ends() rather than the entry's "position" alone: an entry with
## two feet on the ground that reported one would be a tower nothing knows
## is there.
##
## THE NUMBERS MATHIEU FROZE, and which are not this file's to relitigate:
## P1 = (27.7, 0, 9.2), P2 = (25.2, 0, 35.0) -- 25.921 u apart, both at
## ground level (the plateau is flat; no terrain height function exists in
## this repo), so the cable is LEVEL and not a slope. Cable height 2.0 u:
## measured in recon (docs/lots/CH21_TYROLIENNE.md, RECON 5) to be the
## point past which extra height buys NO further corridor clearance --
## the same landmark stays the limiting factor from 2 u to 8 u.
##
## ⚠️ THE STRUCTURE RADIUS THIS IS BUILT AGAINST IS 1.932 u, MEASURED.
## A figure of "4.03 u, already measured on DivingBoard" circulated across
## several briefs; it EXISTS NOWHERE in this repo -- grepped over .gd,
## .md, .tscn and .json, zero hits -- and at P1 it would have put the
## tower 1.9 u INSIDE the neighbouring decor. The only radius ever
## published for the DivingBoard family is 1.932 u, measured twice on the
## built tree. Everything below is budgeted against that, and the probe
## re-measures the AS-BUILT footprint rather than trusting this comment.
const ZIPLINE_CABLE_HEIGHT: float = 2.0

## How far BELOW the cable a rider hangs. Measured in recon (RECON 5's
## corridor sweep subtracts exactly this before testing clearance), and
## published HERE rather than left in a probe, because it is the number
## the deck height is derived from -- and tier 2's ride will read it from
## this constant instead of retyping it.
const ZIPLINE_RIDER_DROP: float = 1.10

## The platform Keepy will stand on. DERIVED, never chosen: a rider hangs
## at cable height minus the drop, so a deck at that same height means the
## departure, the flight and the arrival are all one level. A deck picked
## independently would be a second answer to "how high does a rider fly",
## free to disagree with the first.
const ZIPLINE_DECK_HEIGHT: float = ZIPLINE_CABLE_HEIGHT - ZIPLINE_RIDER_DROP

## The platform slab. 1.30 u across -- Keepy is 0.66 at the shoulder, so
## this is a deck he stands ON rather than balances on.
const ZIPLINE_DECK_HALF: float = 0.65
const ZIPLINE_DECK_THICKNESS: float = 0.10

## The four uprights. The REAR pair stops at the deck; the FRONT pair (the
## one the cable leaves from) carries on up to cable height and becomes
## the head frame -- one part doing both jobs, so the mast and the cable
## anchor cannot drift apart.
const ZIPLINE_LEG_RADIUS: float = 0.09
const ZIPLINE_LEG_HALF_SPAN: float = 0.55
const ZIPLINE_LEG_FORWARD: float = 0.55

## The beam across the two masts, at cable height. The cable is anchored
## at its midpoint, which is why the beam's height is not a number of its
## own: it IS ZIPLINE_CABLE_HEIGHT.
const ZIPLINE_HEADBEAM_RADIUS: float = 0.06

## The stair, behind the deck. Four treads plus the deck itself makes five
## risers, so a tread is DECK_HEIGHT / 5 = 0.18 high on a 0.26 run -- a
## 35 deg climb, steep enough to keep the whole prop inside the 1.932 u
## budget and shallow enough to still read as stairs rather than a ladder.
## The count and the depth are exactly what that budget is spent on, and
## the arithmetic is tight rather than comfortable: at 0.28 the prop
## measures 1.859 u and still fits, at 0.30 it reaches 1.935 and does not.
const ZIPLINE_STEP_COUNT: int = 4
const ZIPLINE_STEP_DEPTH: float = 0.26
const ZIPLINE_STEP_WIDTH: float = 0.80
const ZIPLINE_STEP_THICKNESS: float = 0.10

## The two rails the treads sit between, from the deck edge down to the
## foot of the stair. They are the WIDEST thing this prop puts on the
## ground at its furthest reach, so they -- not the treads -- set the
## circumscribed footprint below.
const ZIPLINE_STRINGER_THICKNESS: float = 0.08
const ZIPLINE_STRINGER_DEPTH: float = 0.10
const ZIPLINE_STRINGER_HALF_SPAN: float = 0.42

## The cable. A CYLINDER and not a SurfaceTool ribbon, deliberately: the
## stream's ribbon exists because its trace is a wide curve that has to
## follow a spine, and a flat quad has an orientation that has to be right
## for the angle it is seen from. This cable is straight, 0.07 u across,
## and seen from a camera that never turns -- a thin cylinder is correct
## from every azimuth by construction, costs 32 triangles, and is opaque,
## so it never enters the transparent pass where this project has already
## paid for depth-write ordering once.
const ZIPLINE_CABLE_RADIUS: float = 0.035
const ZIPLINE_CABLE_SEGMENTS: int = 6

## What one tower puts on the ground, as a circumscribed radius: the far
## bottom corner of a stringer where it meets the ground at the foot of the
## stair -- see _zipline_circumscribed_radius() for the derivation.
##
## ⚠️ IT IS NOT hypot(DECK_HALF + COUNT * DEPTH, HALF_SPAN + THICKNESS/2).
## That reads 1.72880 and is WRONG BY 5 cm, because a stringer is TILTED:
## its faces are rectangles lying across the slope, so its furthest corner
## overhangs the foot of the stair by a further
## STRINGER_DEPTH/2 * (DECK_HEIGHT / slope length). MEASURED against the
## eight transformed corners of the BUILT box, and it took two goes: the
## naive expression first, then a corrected one that used run/length where
## the ratio is height/length. The as-built measurement caught both --
## 1.72880, then 1.78800, against a drawn 1.78308.
##
## Written as a literal because GDScript has no sqrt() in a const
## expression, and RE-DERIVED from those constants in _ready() so it cannot
## quietly drift from the geometry it claims to describe. Under Mathieu's
## 1.932 u budget with 0.149 u to spare.
const ZIPLINE_FOOTPRINT_RADIUS: float = 1.78308

## Timber, all three REUSED and none of them new: the deck and the treads
## take the pontoons' plank colour (as the diving board's deck does), the
## frame takes the boat hull's darker one (as the diving board's frame
## does), and the cable takes the boat rim's pale one -- already the
## project's "a thing you grab" colour on the seesaw grips and the
## turnstile bars. The rim colour is also the only one of the three that
## clears the hub ground's contrast floor: relative luminance 0.563
## against the rendered ground's 0.0799 is 4.72:1, well past 3.0:1, which
## is what a 0.07 u thread strung 24 u across the frame needs to be seen
## at all.
const ZIPLINE_DECK_COLOR: Color = PONTOON_COLOR
const ZIPLINE_FRAME_COLOR: Color = BOAT_HULL_COLOR
const ZIPLINE_CABLE_COLOR: Color = BOAT_RIM_COLOR

## The first non-Keepy Meshy model on this plateau: a static, purely
## decorative owl (assets/models/keepy_owl_decor.glb, converted from
## assets_source/openworld/perso/Meshy_AI_Ember_Eyed_Owlet_0828125359_texture.glb
## by adding KHR_materials_unlit -- the project rule for every asset, applied
## here exactly as it was for keepy_squirrel_hero.glb and
## keepy_hibou_pursuer.glb, with the source's own PBR maps left untouched).
## No interaction, no animation, no state: a lone MeshInstance3D under a
## wrapping Node3D, placed like any other &"owl" entry.
##
## Uniform scale derived by matching the model's own tallest raw axis (Y,
## the model measures 1.899284 standing) to Keepy's own built length in the
## hub (2.0371, the "2.04" the brief names) -- so the two read as
## comparable creature scales rather than one dwarfing the other. Typed as
## a Vector3 rather than a float so a future asset whose proportions need
## correcting does not have to re-plumb this constant to do it; this one
## measured out natural enough that all three components are equal.
const OWL_MODEL_SCALE: Vector3 = Vector3(1.07256, 1.07256, 1.07256)

## Raises the model so its lowest vertex (measured at model-space y =
## -0.95136, the raw AABB's own min.y) sits at the slot's y = 0 once scaled
## -- the JUMP log's lesson (a .glb's origin is wherever its author left
## it) applied here instead of assumed. The model's X/Z centre is within
## 1.3mm and 0.7mm of its own origin, the same order of noise the
## dragonfly's install already treated as measurement error rather than
## something to correct.
const OWL_MODEL_OFFSET: Vector3 = Vector3(0.0, 1.02039, 0.0)

## At-ground radius, post-scale: half of the built footprint's longer side
## (Z, 1.531), matching the FOOTPRINT_RADIUS convention below.
const OWL_FOOTPRINT_RADIUS: float = 0.77

## Where a rider sits on the owl's back, in the owl root's own local space.
##
## MEASURED ON THE MESH, not estimated from the bbox -- a prior pass here
## picked 60% of the model's total height (1.22) as "above the body mass,
## below the head", by analogy with a slender rider mount rather than by
## looking at THIS model. This owlet has no such waist: it is one rounded
## mass with the head fused into the body, and a straight-down raycast
## through the mesh at (x=0, z=0) -- the only point a seat can sit at, see
## below -- lands on a broad, smooth dome (sampled across a 0.4x0.3 patch
## centred on it, every point within 0.08 of its neighbours: a real
## surface, not a spike) at model-space y = 0.9031254854712962, not
## somewhere on a torso two-thirds of the way up. 1.22 buried Keepy's
## whole upper body in the owl's chest; this is the actual dorsal ridge a
## rider's feet land on.
##
##   OWL_MODEL_OFFSET.y + OWL_MODEL_SCALE.y * 0.9031254854712962
##     = 1.02039 + 1.07256 * 0.9031254854712962 = 1.98905 (rounded)
##
## Only Y: a seat offset on X or Z would swing out sideways the moment the
## owl yaws into its turn, and the whole point of writing the rider through
## the owl's own transform is that he cannot -- which is also why (0, 0) is
## not a choice among several candidate seats, it is the one point this
## constant is allowed to measure.
##
## Published by owls() rather than read by whoever seats him, on the terms
## spinning_props() states at length: the back the player sees and the back
## the rider is written onto have to be one fact.
const OWL_SEAT_Y: float = 1.98905

## Ground footprint radius per prop type, in LOCAL units (multiplied by the
## entry's uniform scale at read time). Used by the ride's disembark search
## to refuse a bank point that is already occupied.
##
## These are the AT-GROUND radii, deliberately NOT the silhouettes: a tree
## TRUNK is 0.24 while its crown is 0.95, but the crown floats two metres
## up. A trunk in the water is a bug; a crown overhanging it is what a real
## tree beside a stream does. That distinction is the same one the lot G
## routing measured with, so the two agree by construction.
## The cabin, as it is BUILT from assets/models/keepy_cabin_decor.glb.
##
## SCALE ONE, and that is the recon's measurement rather than a default
## left in place: the raw model is 1.893 x 1.590 x 1.546, which is already
## the size of a hut a 1.35-tall Keepy ducks into. The owl needed a factor
## because its own dominant axis had to be matched against Keepy's depth;
## this one was authored at the size it is wanted at.
const CABIN_MODEL_SCALE: Vector3 = Vector3(1.0, 1.0, 1.0)

## Lifts the model so its lowest point sits at y = 0.
##
## MEASURED off the POSITION accessor of the shipped .glb (min.y =
## -0.800420), not guessed from the fact that most models are centred: the
## origin of a .glb is wherever its author left it, which is the lesson the
## JUMP log charged for. X and Z are left at zero -- the mesh is centred on
## its own origin there to within a couple of millimetres, the same
## measurement noise the dragonfly was right to ignore.
const CABIN_MODEL_OFFSET: Vector3 = Vector3(0.0, 0.800420, 0.0)

## What this prop puts on the ground, for ground_footprints().
##
## The CIRCUMSCRIBED radius (1.228043, measured) rounded UP rather than the
## half-span of the widest side: a cabin is a solid volume a landing has no
## business being inside, and rounding a footprint down is the direction
## that puts a rock through a wall.
const CABIN_FOOTPRINT_RADIUS: float = 1.25

## The doorstep, in TWO terms -- and the split is the whole correction.
##
## It used to be one number scaled whole (CABIN_DOOR_REACH 1.45 x scale),
## measured against CABIN_FOOTPRINT_RADIUS. That footprint is the
## CIRCUMSCRIBED radius -- the corner -- and the doorstep is placed along
## the FACE, which on this model is 0.469 nearer per unit of scale. At
## scale one that error is 0.47 u and invisible; it multiplies, and at 3.5
## it had put the doorstep 2.34 u clear of the front wall, standing on open
## lawn with the whole trigger disc floating out there with it. MEASURED:
## the disc overlapped the building 18.2% at scale 1 and 0.0% at scale 3.5,
## which is the stray-entry report in one number.
##
## So the reach is now the FACE plus a VISITOR'S STANDOFF, and only the
## first of the two scales:
##
##   CABIN_DOOR_FACE_DEPTH  is the model's own +Z half-depth (measured off
##   the built AABB, 2.73274 / 3.5), so it tracks the wall wherever the
##   wall goes.
##
##   CABIN_DOOR_STANDOFF    is how far a VISITOR stands off that wall, and
##   it does NOT scale, because KEEPY DOES NOT SCALE. He is 0.66 wide at
##   the shoulder whatever size the cabin is, so the room he needs to stand
##   at a door is a constant and never a fraction of the building.
##
## The pair reproduces the shipped scale-one doorstep to 3 cm (1.4808 vs
## 1.45) and holds the gap to the wall at a flat 0.700 u at EVERY scale --
## that invariance is the decoupling, and it is what the probe gates.
##
## Along local +Z because that is the open face; _build rotates the pair by
## the entry's own rotation_y, so a cabin turned in the layout takes its
## doorstep with it instead of leaving it round the back.
const CABIN_DOOR_FACE_DEPTH: float = 0.78078
const CABIN_DOOR_STANDOFF: float = 0.70

const FOOTPRINT_RADIUS: Dictionary = {
	&"tree": 0.24,
	&"rock": 0.44,
	&"bush": 0.71,
	&"flower": 0.22,
	&"stump": 0.44,
	&"landmark": 1.66,
	&"portal": 1.35,
	&"pontoon": 1.30,
	# The ladder foot and the pair of posts around it. The deck reaches out
	# over WATER from there, which nothing can be standing on, so the
	# footprint is the frame on land and not the plank's whole length.
	&"divingboard": 0.50,
	# The stone footing, which is the whole of what this prop puts on the
	# ground -- the deck sits above it and the bars above that.
	&"turnstile": TURNSTILE_BASE_RADIUS,
	# Half the plank, so Keepy walks around it the way he walks around any
	# other prop: nothing on this plateau blocks an approach, and the seesaw
	# is not about to become the first thing that does.
	&"seesaw": SEESAW_PLANK_LENGTH * 0.5,
	&"owl": OWL_FOOTPRINT_RADIUS,
	&"cabin": CABIN_FOOTPRINT_RADIUS,
	# ONE radius, TWO feet. Every other type here puts its footprint at the
	# entry's own "position"; a zipline puts an identical tower at each of
	# its two ends, so ground_footprints() reads _zipline_ends() for this
	# type and emits the pair. A single footprint would leave the far tower
	# invisible to every landing check on the plateau.
	&"zipline": ZIPLINE_FOOTPRINT_RADIUS,
}

const LANDMARK_SPIRE_TRUNK: Color = Color(0.15, 0.10, 0.06)
const LANDMARK_SPIRE_CROWN: Color = Color(0.38, 0.58, 0.30)
const LANDMARK_CAIRN_STONE: Color = Color(0.44, 0.45, 0.40)
const LANDMARK_CAIRN_CAP: Color = Color(0.56, 0.56, 0.50)
const LANDMARK_SLAB_STONE: Color = Color(0.36, 0.44, 0.32)
const LANDMARK_SLAB_BASE: Color = Color(0.26, 0.30, 0.23)

var _portals: Array[HubPortal] = []

## The one &"boat" node, and the spine of the one &"stream", both kept so
## the ride can be handed the geometry that was actually BUILT rather than
## a second derivation of it. Null / empty when the layout carries neither,
## which is a legal plateau -- the ride simply does not exist there.
var _boat: Node3D = null
var _stream_spine: Array = []
var _stream_half_width: float = 0.0

## Where the one &"pond" and the one &"lake" were actually PLACED. Kept for
## the same reason as the spine above: a caller that needs to know where the
## water is has to be handed the centre this file drew the disc at, never a
## second reading of the layout. Two numbers describing one circle is how a
## bank slab ends up slicing a prop nobody was warned about -- the note
## HubRegion._lakes already carries for the great lake, and the great lake is
## the only family that already had a published table to answer from.
##
## Vector3.INF marks "the layout has none", which is a legal plateau: a hub
## without a pond simply has one fewer body of water, not a pond at the
## origin. A caller must test for it rather than trusting a zero.
## Every prop with a PIVOT to spin, as built -- see spinning_props().
##
## A LIST FROM THE FIRST COMMIT, with one entry in it. That is the lesson
## the diving board charged for: its geometry was generic from the start
## and it was the singleton TABLE downstream of it that made a second plank
## drawable-but-unclimbable, and unpicking that cost its own batch. The
## shape here is deliberately NOT turnstile-specific either -- position,
## radius, and the node to turn -- so a second kind of spinning prop is an
## entry in this array rather than a second parallel mechanism.
var _spinning_props: Array[Dictionary] = []

## Every &"seesaw" as built, in layout order. A LIST FROM THE FIRST COMMIT
## and with one entry in it, which is the lesson the diving board charged
## for: that prop's GEOMETRY was generic from the start and the singleton
## sat in the table DOWNSTREAM of it, so a second plank was drawable and
## unclimbable and undoing it cost its own batch. Nothing names THE seesaw
## -- a landing rocks whichever one it landed at -- so a second entry is
## another place to play rather than an ambiguity.
var _seesaws: Array[Dictionary] = []
var _last_seesaw: Dictionary = {}

## Every &"owl", as it was BUILT.
##
## A LIST FROM THE FIRST COMMIT, and that is the diving board's lesson paid
## forward rather than a guess about the future. The board's GEOMETRY was
## generic from the day it shipped; it was this table downstream of it that
## held one, so a second plank was drawn and then never climbable -- and
## undoing that cost its own batch. Nothing downstream names THE owl: a
## flight is started by whichever perch the player walked to, so a second
## owl is another place to fly from rather than an ambiguity.
var _owls: Array[Dictionary] = []
var _last_owl: Dictionary = {}

## Every &"cabin", as it was BUILT.
##
## A LIST FROM THE FIRST COMMIT, on the owl's terms and for the diving
## board's reason: that prop's geometry was generic the day it shipped and
## the singleton sat in the table DOWNSTREAM of it, so a second plank was
## drawn and never climbable and undoing it cost its own batch. Nothing
## downstream names THE cabin -- a landing enters whichever one it landed
## at -- so a second entry is another place to hide rather than an
## ambiguity.
var _cabins: Array[Dictionary] = []
var _last_cabin: Dictionary = {}

## Every &"divingboard" as built, in layout order -- see diving_boards()
## for the shape of one entry.
var _diving_boards: Array[Dictionary] = []

## Every &"zipline" built, in layout order. Plural from the first entry --
## see the note at its record site in _build.
var _ziplines: Array[Dictionary] = []

## Every &"islet" as built -- {"centre": Vector3 (flat), "radius": float}, in
## layout order. See islets() for why this exists at all.
var _islets: Array[Dictionary] = []

var _pond_centre: Vector3 = Vector3.INF
var _small_lake_centre: Vector3 = Vector3.INF

## Batch key -> {"mesh": Mesh, "colour": Color, "xforms": Array[Transform3D]}.
## Filled while the layout is walked, drained once at the end by
## _flush_batches(); a batch nothing landed in is never created.
var _batches: Dictionary = {}

## Batch keys in first-seen order, so the child order of the MultiMesh
## nodes follows the layout rather than Dictionary iteration order.
var _batch_order: Array[StringName] = []

func _ready() -> void:
	assert(_FLOWER_PETAL_KEYS.size() == FLOWER_PETAL_COLORS.size(),
		"HubBuilder: a corolla tint has no batch key, or the reverse.")
	# ZIPLINE_FOOTPRINT_RADIUS is a hand-written literal because GDScript
	# refuses sqrt() in a const expression. Re-derived here from the
	# constants it is supposed to summarise: change the stair depth or the
	# stringer span and the literal fails loudly instead of quietly
	# under-reporting what the tower puts on the ground.
	assert(absf(ZIPLINE_FOOTPRINT_RADIUS - _zipline_circumscribed_radius()) < 0.00001,
		"HubBuilder: ZIPLINE_FOOTPRINT_RADIUS no longer matches the stair it describes.")
	_build()

## The circumscribed ground radius of ONE tower, derived from the geometry
## rather than restated: the far bottom corner of a stringer where it meets
## the ground at the foot of the stair.
##
## Three terms, and the third is the one that is easy to miss -- twice.
## The stair reaches DECK_HALF + COUNT * DEPTH behind the tower centre; a
## stringer sits STRINGER_HALF_SPAN + THICKNESS/2 out to the side; and
## because the stringer is a box TILTED along the slope, its furthest
## corner overhangs the foot by DEPTH/2 scaled by the slope's VERTICAL
## fraction (DECK_HEIGHT / slope length), NOT its horizontal one. The
## thickness axis of a tilted box leans the opposite way to the box, which
## is why the intuitive run/length is the wrong ratio and reads 5 mm long.
## The legs (0.868) and the treads are both inside the result, which is why
## this is the only corner the expression needs.
func _zipline_circumscribed_radius() -> float:
	var run: float = ZIPLINE_STEP_DEPTH * float(ZIPLINE_STEP_COUNT)
	var slope_length: float = sqrt(run * run + ZIPLINE_DECK_HEIGHT * ZIPLINE_DECK_HEIGHT)
	var overhang: float = ZIPLINE_STRINGER_DEPTH * 0.5 * (ZIPLINE_DECK_HEIGHT / slope_length)
	var reach: float = ZIPLINE_DECK_HALF + run + overhang
	var lateral: float = ZIPLINE_STRINGER_HALF_SPAN + ZIPLINE_STRINGER_THICKNESS * 0.5
	return sqrt(reach * reach + lateral * lateral)

## Every portal built, in layout order. HubWorld connects them after the
## build rather than the builder knowing what a portal is wired to.
func portals() -> Array[HubPortal]:
	return _portals

## The hull built for the one &"boat" entry, or null if the layout has
## none. Owned by this node; BoatMooring only moves it.
func boat() -> Node3D:
	return _boat

## The spine of the one &"stream" entry -- the SAMPLED centripetal curve
## this file ribboned, not the layout's control points.
##
## Handed over rather than re-derived on purpose: the drawn curve bulges
## outside the chords of a polyline through the same control points, so a
## rider following the control points would leave the water on every bend.
## One curve in the build, and the ride is on it.
func stream_spine() -> Array:
	return _stream_spine

## Half the width of the one &"stream", as it was built. The ride needs it
## to know where the bank is; it is layout data, so it is reported from
## here rather than re-read from the resource by a second caller.
func stream_half_width() -> float:
	return _stream_half_width

## Every &"divingboard", as it was BUILT, in layout order; empty when the
## layout has none. Keys per entry: "ladder" (Vector3, flat, the foot on
## land), "anchor" (Vector3, y = deck height, where a climber ends up),
## "forward" (Vector3, flat unit, the way a dive faces), "side",
## "rung_heights", and "water_target" / "land_target" (Vector3, flat, where
## the two dives land).
##
## Published from the geometry rather than left to be re-read from the
## layout by KeepyHopper: the plank the player sees and the point they are
## planted on have to be the same fact, and the only way to guarantee that
## is for both to come out of the pass that drew it.
##
## WAS A SINGLETON, AND THAT WAS A REAL LIMIT rather than a style: a second
## entry used to be drawn and then refused with an error, so a plank the
## player could see was one they could never climb. The GEOMETRY was always
## generic -- _make_divingboard() reads position/deck_anchor/dive_direction
## off the entry and hardcodes nothing about the first one -- it was only
## this table, and the single ladder_foot downstream of it, that could hold
## one. Boards are independent of each other, so the plural is a list and
## not a special case; the climb still owns exactly one AT A TIME, which is
## KeepyHopper's business and unchanged.
## Every zipline that was actually DRAWN, as one dictionary each:
##
##   "towers"       two entries, layout order (near end first), each
##                  {"position": flat Vector3, "forward": unit Vector3
##                  towards the OTHER tower, "deck": the platform's top
##                  surface at the tower's centre, "anchor": where the
##                  cable is fixed on this tower, "stair_foot": the flat
##                  point on the ground the stair comes down to}
##   "cable"        {"from": Vector3, "to": Vector3} -- the drawn cable's
##                  two endpoints, which ARE the two towers' anchors
##   "cable_height" the level the cable was strung at
##   "rider_drop"   how far below the cable a rider hangs
##   "clear_radius" what one tower puts on the ground
##
## AS-BUILT and published once, so tier 2's ride reads where the cable
## actually is rather than recomputing it from the layout -- the failure
## this repo has already paid for on a doorstep that did not scale with
## its cabin and on two homonymous lake radii.
func ziplines() -> Array[Dictionary]:
	return _ziplines

func diving_boards() -> Array[Dictionary]:
	return _diving_boards

## Every prop that reacts to a landing by turning, as it was BUILT.
##
## Keys per entry:
##   "position"  Vector3, flat -- where the landing distance is measured to
##   "radius"    float   -- how close a landing has to be to set it going
##   "spinner"   Node3D  -- the sub-node to rotate, and ONLY that sub-node:
##                          whatever the prop leaves static (a footing, a
##                          foundation) is deliberately not under it
##   "deck_y"    float   -- TOP of the ridable surface, in the SPINNER's own
##                          local space, so a rider stands on it rather than
##                          in it
##   "ride_radius" float -- how far out from the pivot a rider sits, same
##                          local space
##   "bars"      int     -- how many radial grips the top carries, so a
##                          rider can be seated BETWEEN two of them instead
##                          of inside one
##   "clear_radius" float -- the static footing's own radius: the smallest
##                          circle a dismount has to land outside of
##
## THE LAST FOUR ARE PUBLISHED, NOT LEFT TO THE RIDER TO RECOMPUTE. Keepy is
## written onto this prop every frame while he rides it, and the height and
## the radius he is written at ARE the deck's -- so they come out of the pass
## that drew the deck, exactly as "radius" and "spinner" already do. The
## alternative is the same number living in two files, which is the failure
## this project has paid for often enough to stop choosing it.
##
## Published from the geometry rather than re-read from the layout, for the
## same reason the boards are: the thing the player sees turning and the
## thing a landing is measured against have to be one fact, and the only
## way to guarantee that is for both to come out of the pass that drew it.
func spinning_props() -> Array[Dictionary]:
	return _spinning_props

## Every &"seesaw", as it was BUILT, in layout order:
##
##   "position"     Vector3 -- flat world centre, the fulcrum
##   "radius"       float   -- trigger radius: how near a landing must be
##   "pivot"        Node3D  -- the node that TILTS; nothing else moves
##   "seat_y"       float   -- top of the plank, in the pivot's local space
##   "ride_x"       float   -- how far out along the plank a rider sits
##   "clear_radius" float   -- half the plank: what a dismount must clear
##
## PUBLISHED FROM THE PASS THAT DREW IT, never re-read from the layout, for
## the reason spinning_props() states at length: the plank the player sees
## tilting and the plank a rider is written onto have to be one fact, and
## the only way to guarantee that is for both to come out of one pass.
func seesaws() -> Array[Dictionary]:
	return _seesaws

## Every &"owl", as it was BUILT, in layout order:
##
##   "position" Vector3 -- flat world perch, where a tap is measured to
##   "carrier"  Node3D  -- the node a flight MOVES, and the node a rider is
##                         written through. The whole prop moves: there is
##                         one owl and it leaves the perch empty while it
##                         flies, rather than a second copy being spawned
##                         and the draw-node count paying for it
##   "seat_y"   float   -- OWL_SEAT_Y, in the carrier's own local space
##
## No "radius" here, unlike the seesaw and the turnstile: those two are
## triggered by a LANDING, so how near a landing must be is a property of
## the prop. This one is triggered by a TAP, so the reach belongs with the
## other tap radii in HubWorld -- see OWL_TAP_RADIUS there, which is also
## the number the arrival test and the dismount ring are measured with, so
## "near enough to tap" and "near enough to fly from" cannot drift apart.
func owls() -> Array[Dictionary]:
	return _owls

## Every &"cabin", as it was BUILT, in layout order:
##
##   "position" Vector3 -- the entry's own place, flat
##   "door"     Vector3 -- the point on the ground a visitor stands at to
##                         go in: the middle of the open face, pushed clear
##                         of the trunk. Published rather than recomputed
##                         by whoever walks to it, so the face the player
##                         aims at and the point the walk ends at are one
##                         fact and cannot drift apart.
##
## No node handle in it, unlike the owl's "carrier" and the turnstile's
## pivot: nothing ever MOVES a cabin. Keepy goes in and the prop stands
## still, which is the whole reason this is the smallest interactive prop
## on the plateau -- there is no carrier to write a rider against and no
## tween to keep a rider in step with.
func cabins() -> Array[Dictionary]:
	return _cabins

## Centre of the one &"pond", or Vector3.INF when the layout has none.
func pond_centre() -> Vector3:
	return _pond_centre

## Centre of the one &"lake" -- the SMALL one. The great lake's two lobes are
## not reported here: HubRegion.lakes() already publishes them, and this file
## draws them from that table rather than the other way round.
func small_lake_centre() -> Vector3:
	return _small_lake_centre

## Every &"islet", as it was BUILT -- {"centre": Vector3 (flat), "radius":
## float}. Read by HubWater to know where a great-lake island's dry ground
## is: a disc test alone cannot see it, because an islet sits well inside
## the water disc it stands on -- HubWater has to subtract it, not merely
## draw it.
##
## AS-BUILT, not as-declared, for the same reason pond_centre() and
## small_lake_centre() are: the layout's "radius" is scaled by the entry's
## own uniform "scale" before it becomes the disc actually drawn, and a
## caller that redid that multiplication itself would be a second reading of
## the layout -- which is exactly how one circle quietly becomes two.
func islets() -> Array[Dictionary]:
	return _islets

## Every prop's ground footprint, as {"position": Vector3, "radius": float},
## read from the LAYOUT rather than from the built tree -- batched props
## have no node of their own to measure, and a stream/boat has no single
## position at all. Both are skipped: neither is something to land on top
## of, and neither has a meaningful ground radius.
func ground_footprints() -> Array:
	var out: Array = []
	if layout == null:
		return out
	for entry in layout.props:
		var type: StringName = entry.get("type", &"")
		if not FOOTPRINT_RADIUS.has(type):
			continue
		var uniform: float = entry.get("scale", 1.0)
		var radius: float = float(FOOTPRINT_RADIUS[type]) * uniform
		# A zipline stands a tower at EACH of its two ends, so it reports
		# two footprints from one entry -- the same reason _build walks
		# _zipline_ends() for its walkability check. Read through the one
		# accessor rather than re-parsed here: two readings of "where are
		# the towers" is how one of them ends up unguarded.
		var feet: Array = _zipline_ends(entry) if type == &"zipline" else [entry.get("position", Vector3.ZERO)]
		for foot in feet:
			var where: Vector3 = foot
			out.append({
				"position": Vector3(where.x, 0.0, where.z),
				"radius": radius,
			})
	return out

## The two ends a &"zipline" entry is authored by, FLAT, in layout order --
## the near tower ("position") then the far one ("far_end"). Empty when the
## entry is malformed, which every caller treats as "there is no zipline
## here" rather than inventing a second end.
##
## THE one reading of those two points. _make_zipline builds from it,
## ground_footprints() guards from it, and _build's reachability check
## walks it -- so a layout that moves an end moves everything that depends
## on it, instead of moving two of the three.
func _zipline_ends(entry: Dictionary) -> Array:
	var near: Vector3 = entry.get("position", Vector3.ZERO)
	var far: Vector3 = entry.get("far_end", Vector3.INF)
	if far == Vector3.INF:
		return []
	return [Vector3(near.x, 0.0, near.z), Vector3(far.x, 0.0, far.z)]

func _build() -> void:
	if layout == null:
		push_error("HubBuilder: no layout assigned, plateau will be empty.")
		return
	for index in layout.props.size():
		var entry: Dictionary = layout.props[index]
		var type: StringName = entry.get("type", &"")
		var where: Vector3 = entry.get("position", Vector3.ZERO)
		var rotation_y: float = entry.get("rotation_y", 0.0)
		var uniform: float = entry.get("scale", 1.0)

		# The transform the prop's root node WOULD have had. Composed by
		# hand because a batched instance has no node to read it off --
		# and it is exact rather than approximate because the layout's
		# scale is a UNIFORM float: rotation and uniform scale commute, so
		# there is no ambiguity about which side Node3D applies the scale.
		# Asserted against a real node, not argued: see the batch's probe.
		var placement := Transform3D(
			Basis.from_euler(Vector3(0.0, deg_to_rad(rotation_y), 0.0)).scaled(Vector3.ONE * uniform),
			where)

		var node: Node3D = null
		if not _batch_prop(type, entry, placement):
			match type:
				&"portal":
					node = _make_portal(entry, index)
				&"landmark":
					node = _make_landmark(entry)
				&"stump":
					node = _make_stump()
				&"pond":
					node = _make_pond()
				&"lake":
					node = _make_lake()
				&"greatlake":
					node = _make_greatlake(entry)
				&"islet":
					node = _make_islet(entry)
				&"stream":
					node = _make_stream(entry)
				&"boat":
					node = _make_boat()
				&"divingboard":
					node = _make_divingboard(entry, index, where)
				&"turnstile":
					node = _make_turnstile(entry, index, where)
				&"seesaw":
					node = _make_seesaw(entry, index, where)
				&"owl":
					node = _make_owl(index)
				&"cabin":
					node = _make_cabin(index)
				&"zipline":
					node = _make_zipline(entry, index, where)
				_:
					push_error("HubBuilder: entry %d has unknown type '%s', skipped." % [index, type])
					continue
			if node == null:
				continue

		# A prop outside the tap clamp is drawn but can never be walked to.
		# Not fatal -- distant scenery is a legitimate thing to want -- so
		# warn and keep it rather than dropping it. The bound is READ from
		# HubTapInput, never copied: two copies of a play-area limit is how
		# they drift apart.
		#
		# This reads the LAYOUT, never the scene tree, which is why
		# batching changed nothing about it. It stays AFTER the type is
		# known good so an unknown type still produces one error and no
		# warning, exactly as before.
		# A stream has NO single position -- its trace is its placement -- so
		# the check walks every control point. Without this branch a stream
		# would fall back to Vector3.ZERO and pass for free: a silent hole in
		# the one guard that catches a prop nobody can walk to.
		#
		# The bound is no longer a float: the lake zone made the walkable
		# hub a union minus a disc, so the question "can this be walked to"
		# is HubRegion.contains() and nothing here restates it.
		#
		# "offshore": true is how an entry DECLARES it is meant to be out
		# of reach -- the islets, their landmarks and the lake itself are
		# deliberately unreachable on foot in this batch. The check is then
		# INVERTED rather than skipped: an offshore entry that turns out to
		# be walkable is warned about too. A flag that only ever silenced
		# things would be a way to silence a real mistake.
		var anchors: Array = [where]
		if type == &"stream":
			anchors = _trace_points(entry)
		elif type == &"zipline":
			# Both towers, for the same reason a stream walks its whole
			# trace: an entry with two feet that only checked one could
			# ship a tower nobody can walk to and warn about nothing.
			anchors = _zipline_ends(entry)
		var offshore: bool = entry.get("offshore", false)
		for anchor in anchors:
			var point: Vector3 = anchor
			var reachable: bool = HubRegion.contains(point)
			if offshore and reachable:
				push_warning("HubBuilder: entry %d ('%s') at %s is marked offshore but IS walkable; the flag is wrong." % [index, type, point])
			elif not offshore and not reachable:
				push_warning("HubBuilder: entry %d ('%s') at %s is outside the walkable region; visible but unreachable." % [index, type, point])

		if node != null:
			node.position = where
			node.rotation_degrees = Vector3(0.0, rotation_y, 0.0)
			node.scale = Vector3.ONE * uniform
			add_child(node)
			# The centre a water disc was actually drawn at, published so
			# nothing has to read the layout a second time to find the water.
			# A second entry is an error rather than a silent overwrite, the
			# same rule the hull below is held to: one pond, one lake.
			if type == &"pond":
				if _pond_centre != Vector3.INF:
					push_error("HubBuilder: a second &\"pond\" entry at %d; the first one is the one anything else can find." % index)
				else:
					_pond_centre = where
			elif type == &"lake":
				if _small_lake_centre != Vector3.INF:
					push_error("HubBuilder: a second &\"lake\" entry at %d; the first one is the one anything else can find." % index)
				else:
					_small_lake_centre = where
			if type == &"islet":
				# AS-BUILT: the radius the mesh was actually given, scaled by
				# the same uniform this entry's node.scale carries. Recorded
				# in layout order, plural from the first entry -- an islet
				# names no singleton the way THE pond does, it is one more
				# island for HubWater to subtract.
				_islets.append({
					"centre": Vector3(where.x, 0.0, where.z),
					"radius": float(entry.get("radius", ISLET_RADIUS)) * uniform,
				})
			if type == &"seesaw":
				# Recorded AFTER add_child, on the turnstile's terms and for
				# its reasons: every published pivot is one that actually
				# got drawn, and the list is plural because nothing
				# downstream names THE seesaw.
				if not _last_seesaw.is_empty():
					_seesaws.append(_last_seesaw)
			if type == &"cabin":
				# Recorded AFTER add_child, on the owl's and the boards' plural
				# terms: every published door is one that actually got drawn.
				#
				# The door is derived HERE, from the same `where` and `yaw` the
				# prop was placed with, rather than written into the layout as a
				# second coordinate: two numbers for one doorway is how a door
				# ends up on the wrong side of a cabin somebody rotated.
				if not _last_cabin.is_empty():
					var cabin_flat := Vector3(where.x, 0.0, where.z)
					# The FACE scales, the visitor's standoff does not --
					# see the two constants for why one number could not do
					# both and what it cost when it tried.
					var reach := Vector3(0.0, 0.0,
							CABIN_DOOR_FACE_DEPTH * uniform + CABIN_DOOR_STANDOFF)
					reach = reach.rotated(Vector3.UP, deg_to_rad(rotation_y))
					_last_cabin["position"] = cabin_flat
					_last_cabin["door"] = cabin_flat + reach
					# Published so a reader can recover the magpie's NET drawn
					# scale (bird.scale.x * uniform) without re-parsing the
					# layout a second time -- the same discipline every other
					# fact in this dictionary is held to.
					_last_cabin["uniform"] = uniform
					_cabins.append(_last_cabin)
			if type == &"owl":
				# Recorded AFTER add_child, on the boards' and the seesaw's
				# plural terms: every published perch is one that actually
				# got drawn, and nothing downstream names THE owl.
				if not _last_owl.is_empty():
					_last_owl["position"] = Vector3(where.x, 0.0, where.z)
					_owls.append(_last_owl)
			if type == &"turnstile":
				# Recorded AFTER add_child, alongside the boards, so every
				# published spinner is one that actually got drawn. Held to
				# the boards' plural rule and not the pond's singleton one:
				# nothing downstream names THE turnstile, a landing shoves
				# whichever one it landed at, so a second entry is another
				# place to play rather than an ambiguity.
				if not _last_turnstile.is_empty():
					_spinning_props.append(_last_turnstile)
			if type == &"zipline":
				# Recorded AFTER add_child, on the boards' plural terms:
				# every published cable is one that actually got drawn.
				# An Array from the first entry even though the layout
				# ships one -- a table is a list from the first commit,
				# which this repo has already paid a whole batch to learn
				# on the diving board's singleton.
				if not _last_zipline.is_empty():
					_ziplines.append(_last_zipline)
			if type == &"divingboard":
				# Recorded AFTER add_child, alongside the hull, so every
				# published board is one that actually got drawn.
				#
				# NOT held to the pond/lake/boat "one only" rule, and the
				# difference is not arbitrary: those three are singletons
				# because something downstream needs to name THE pond or
				# THE hull. Nothing names THE board -- a climb is started
				# by whichever ladder the player walked to -- so a second
				# plank is another place to climb, not an ambiguity.
				if not _last_board.is_empty():
					_diving_boards.append(_last_board)
			if type == &"boat":
				if _boat != null:
					push_error("HubBuilder: a second &\"boat\" entry at %d; the ride owns one hull, the extra is drawn but never moored." % index)
				else:
					_boat = node
	_flush_batches()

## Files a scatter prop into its batches. Returns false for a type that
## wants a node of its own, which is the caller's cue to fall through to
## the match.
func _batch_prop(type: StringName, entry: Dictionary, placement: Transform3D) -> bool:
	match type:
		&"tree":
			_instance(&"TreeTrunk", placement.translated_local(Vector3(0.0, 0.75, 0.0)))
			_instance(&"TreeCrown", placement.translated_local(Vector3(0.0, 2.0, 0.0)))
		&"rock":
			_instance(&"Rock", placement.translated_local(Vector3(0.0, 0.28, 0.0)))
		&"bush":
			# Two lobes, ONE mesh: two instances of a single batch.
			_instance(&"Bush", placement.translated_local(Vector3(0.0, 0.3, 0.0)))
			_instance(&"Bush", placement.translated_local(Vector3(0.42, 0.2, 0.18)))
		&"pontoon":
			# A deck, batched: every pontoon is the same plank slab at a
			# different angle, which is precisely what one MultiMesh is for.
			_instance(&"Pontoon", placement.translated_local(Vector3(0.0, PONTOON_CENTRE_Y, 0.0)))
		&"flower":
			_instance(&"FlowerStem", placement.translated_local(Vector3(0.0, 0.21, 0.0)))
			var variant: int = entry.get("variant", 0)
			if variant < 0 or variant >= FLOWER_PETAL_COLORS.size():
				variant = 0
			_instance(_FLOWER_PETAL_KEYS[variant], placement.translated_local(Vector3(0.0, 0.44, 0.0)))
		_:
			return false
	return true

func _instance(key: StringName, xform: Transform3D) -> void:
	if not _batches.has(key):
		var spec: Array = _batch_spec(key)
		var xforms: Array[Transform3D] = []
		_batches[key] = {"mesh": spec[0], "colour": spec[1], "xforms": xforms}
		_batch_order.append(key)
	_batches[key]["xforms"].append(xform)

## The (mesh, colour) pair a batch key stands for. Built once per key, on
## first use -- the whole point of a MultiMesh is that 39 trees share one
## trunk mesh rather than owning 39 copies of it.
##
## Godot's default tessellation on a primitive is far denser than any
## silhouette this size needs -- the same trap docs/MESHY_SPEC.md 7.2
## caught on the collectibles. Set explicitly rather than inherited.
func _batch_spec(key: StringName) -> Array:
	match key:
		&"TreeTrunk":
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.16
			trunk.bottom_radius = 0.24
			trunk.height = 1.5
			trunk.radial_segments = 8
			trunk.rings = 1
			return [trunk, TRUNK_COLOR]
		&"TreeCrown":
			var crown := SphereMesh.new()
			crown.radius = 0.95
			crown.height = 1.7
			crown.radial_segments = 10
			crown.rings = 5
			return [crown, CROWN_COLOR]
		&"Rock":
			var rock := SphereMesh.new()
			rock.radius = 0.6
			rock.height = 0.8
			rock.radial_segments = 8
			rock.rings = 4
			return [rock, ROCK_COLOR]
		&"Bush":
			var bush := SphereMesh.new()
			bush.radius = 0.5
			bush.height = 0.7
			bush.radial_segments = 8
			bush.rings = 4
			return [bush, BUSH_COLOR]
		&"Pontoon":
			var deck := BoxMesh.new()
			deck.size = Vector3(PONTOON_LENGTH, PONTOON_THICKNESS, PONTOON_WIDTH)
			return [deck, PONTOON_COLOR]
		&"DivingBoardRung":
			# Laid along local X so the batch's yaw basis swings it across
			# the ladder; the mesh is a cylinder standing on Y by default,
			# so the rotation is authored into the mesh here rather than
			# into every instance transform.
			var rung := CylinderMesh.new()
			rung.top_radius = DIVINGBOARD_RUNG_RADIUS
			rung.bottom_radius = DIVINGBOARD_RUNG_RADIUS
			rung.height = DIVINGBOARD_RAIL_HALF_SPAN * 2.0
			rung.radial_segments = 6
			rung.rings = 1
			return [rung, DIVINGBOARD_FRAME_COLOR]
		&"FlowerStem":
			var stem := CylinderMesh.new()
			stem.top_radius = 0.025
			stem.bottom_radius = 0.035
			stem.height = 0.42
			stem.radial_segments = 6
			stem.rings = 1
			return [stem, FLOWER_STEM_COLOR]
		&"ZiplineLeg":
			var leg := CylinderMesh.new()
			leg.top_radius = ZIPLINE_LEG_RADIUS
			leg.bottom_radius = ZIPLINE_LEG_RADIUS
			leg.height = ZIPLINE_DECK_HEIGHT
			leg.radial_segments = 8
			leg.rings = 1
			return [leg, ZIPLINE_FRAME_COLOR]
		&"ZiplineMast":
			var mast := CylinderMesh.new()
			mast.top_radius = ZIPLINE_LEG_RADIUS
			mast.bottom_radius = ZIPLINE_LEG_RADIUS
			mast.height = ZIPLINE_CABLE_HEIGHT
			mast.radial_segments = 8
			mast.rings = 1
			return [mast, ZIPLINE_FRAME_COLOR]
		&"ZiplineStep":
			var step := BoxMesh.new()
			step.size = Vector3(ZIPLINE_STEP_WIDTH, ZIPLINE_STEP_THICKNESS, ZIPLINE_STEP_DEPTH)
			return [step, ZIPLINE_DECK_COLOR]
		&"ZiplineStringer":
			# Long enough to span the stair exactly, derived here rather
			# than written down: sqrt() is legal in a function and not in
			# the const block, and one derivation beats a literal that
			# would have to be kept in step with the stair by hand.
			var run: float = ZIPLINE_STEP_DEPTH * float(ZIPLINE_STEP_COUNT)
			var stringer := BoxMesh.new()
			stringer.size = Vector3(ZIPLINE_STRINGER_THICKNESS, ZIPLINE_STRINGER_DEPTH,
				sqrt(run * run + ZIPLINE_DECK_HEIGHT * ZIPLINE_DECK_HEIGHT))
			return [stringer, ZIPLINE_FRAME_COLOR]
		_:
			var tint: int = _FLOWER_PETAL_KEYS.find(key)
			if tint < 0:
				push_error("HubBuilder: no mesh known for batch key '%s'." % key)
				return [SphereMesh.new(), Color.MAGENTA]
			var petal := SphereMesh.new()
			petal.radius = 0.15
			petal.height = 0.14
			petal.radial_segments = 8
			petal.rings = 3
			return [petal, FLOWER_PETAL_COLORS[tint]]

## Turns every filled batch into one MultiMeshInstance3D.
func _flush_batches() -> void:
	for key in _batch_order:
		var batch: Dictionary = _batches[key]
		var xforms: Array = batch["xforms"]
		if xforms.is_empty():
			continue
		var mesh: Mesh = batch["mesh"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = xforms.size()
		var bounds := AABB()
		var local_aabb: AABB = mesh.get_aabb()
		for i in xforms.size():
			var xform: Transform3D = xforms[i]
			multi.set_instance_transform(i, xform)
			var box: AABB = xform * local_aabb
			bounds = box if i == 0 else bounds.merge(box)
		# A MultiMesh derives an AABB of its own, and a wrong or stale one
		# makes the entire batch vanish when the camera turns -- a failure
		# with no error attached to it, on a screen no one can look at
		# before staging. The exact union is cheap to compute right here,
		# so it is written rather than trusted.
		multi.custom_aabb = bounds

		var node := MultiMeshInstance3D.new()
		node.name = String(key)
		node.multimesh = multi
		# material_override rather than a material on the mesh: the mesh is
		# shared by every instance in the batch, and this keeps the colour
		# on the node that draws it, next to the instances it applies to.
		node.material_override = _unshaded(batch["colour"])
		add_child(node)

func _make_portal(entry: Dictionary, index: int) -> Node3D:
	if portal_scene == null:
		push_error("HubBuilder: entry %d is a portal but no portal_scene is assigned." % index)
		return null
	var portal := portal_scene.instantiate() as HubPortal
	if portal == null:
		push_error("HubBuilder: portal_scene does not instantiate to a HubPortal.")
		return null
	portal.game_id = entry.get("game_id", &"")
	var label_node := portal.get_node_or_null("Label") as Label3D
	if label_node:
		label_node.text = entry.get("label", "")
	_portals.append(portal)
	return portal

## A static, purely decorative owl -- the first hub prop drawn from an
## imported Meshy model rather than built from primitives in this file.
##
##   Owl              <- placed by _build (position / rotation_y / scale)
##     Model          <- owl_scene instance, OWL_MODEL_SCALE / OWL_MODEL_OFFSET
##
## Same shape as the ModelSlot correction trio (model_scale / model_rotation
## / model_offset) used everywhere else a .glb replaces a placeholder, but
## applied by hand here rather than through a ModelSlot node: ModelSlot's
## whole point is a placeholder that can fall back to a primitive, and this
## prop has no placeholder to fall back to -- it is either the model or
## nothing, exactly like _make_portal() above already instantiates
## portal_scene directly rather than through an intermediary.
##
## No local rotation correction: the raw model already faces +Z (measured
## by rendering it from all four cardinal directions -- see the lot's
## report), so a placement entry with rotation_y = 0 already faces the
## model toward the camera. Nothing else about this prop moves: no signal,
## no _process, no state.
func _make_owl(index: int) -> Node3D:
	_last_owl = {}
	if owl_scene == null:
		push_error("HubBuilder: entry %d is an owl but no owl_scene is assigned." % index)
		return null
	var model := owl_scene.instantiate() as Node3D
	if model == null:
		push_error("HubBuilder: owl_scene does not instantiate to a Node3D.")
		return null
	model.scale = OWL_MODEL_SCALE
	model.position = OWL_MODEL_OFFSET
	var root := Node3D.new()
	root.name = "Owl"
	root.add_child(model)
	# Recorded here, from the pass that DREW it, and filed by _build once
	# add_child has actually happened -- the rule every other published
	# registry on this file is held to. The carrier is this root and not
	# the model child: a flight moves the whole prop, and the rider is
	# written through the same transform, so seat and body cannot drift.
	_last_owl = {
		"carrier": root,
		"seat_y": OWL_SEAT_Y,
	}
	return root

## A static tree-house. Purely decorative geometry -- the ONE thing it
## does, Keepy vanishing into it, is a state on him and touches nothing
## here.
##
##     Cabin          <- placed by _build (position / rotation_y / scale)
##       Model        <- cabin_scene instance, CABIN_MODEL_SCALE / _OFFSET
##
## Instantiated directly rather than through a ModelSlot, on the owl's
## terms: a slot exists to hold a PLACEHOLDER a real model later replaces,
## and this prop is either the .glb or nothing at all.
##
## THE OPEN FACE IS MODEL +Z, and that is what fixes the door offset below
## as well as the rotation the layout ships. Rendered on four axes before
## anything was written: from +Z the trunk is hollowed out and furnished --
## a bed, shelves, a hanging sign, steps at the foot -- and from -Z it is a
## closed trunk with no opening at all.
func _make_cabin(index: int) -> Node3D:
	_last_cabin = {}
	if cabin_scene == null:
		push_error("HubBuilder: entry %d is a cabin but no cabin_scene is assigned." % index)
		return null
	var model := cabin_scene.instantiate() as Node3D
	if model == null:
		push_error("HubBuilder: cabin_scene does not instantiate to a Node3D.")
		return null
	model.scale = CABIN_MODEL_SCALE
	model.position = CABIN_MODEL_OFFSET
	var root := Node3D.new()
	root.name = "Cabin"
	root.add_child(model)
	# Re-derived rather than threaded in from _build(): _build applies the
	# entry's own "scale" to the ROOT this function returns, AFTER this
	# call has already returned -- so at this point in the pipeline it is
	# not yet in scope anywhere except the layout entry itself, which is
	# exactly where _furnish_cabin's own legibility correction needs it.
	var cabin_uniform: float = (layout.props[index] as Dictionary).get("scale", 1.0)
	_furnish_cabin(root, cabin_uniform)
	# Filed by _build once add_child has actually happened, which is the rule
	# every published registry in this file is held to -- and the door is
	# derived there, where the placement rotation is in scope.
	_last_cabin = {
		"root": root,
	}
	return root

## The magpie, drawn inside the plateau's cutaway view of the cabin.
##
## A CHILD OF THE ROOT, never of the .glb node: _build gives the root the
## entry's uniform scale and its rotation_y, so hanging her here is what
## makes a resized or turned cabin carry her with it. The .glb child holds
## only the model's own lift, and CabinInterior.magpie_local_pose() already
## includes that same lift in its y, so the two sit in one local frame.
##
## THE POSE IS READ FROM CabinInterior, NEVER RESTATED. She has to stand in
## the same corner of the same room in both views, and the two views draw
## this .glb at different scales -- so a copied world coordinate would be
## wrong by that ratio. Reading the publisher is what makes "the same
## magpie" a fact instead of two numbers that agree until one is edited.
##
## NOTHING IS REGISTERED. No hotspot, no tap radius, no entry in any of the
## published tables this file keeps for the boat, the boards or the doors:
## a tap near this cabin means the DOOR, and it went on meaning exactly
## that. She is scenery out here, and the kiss stays indoors.
##
## ⚠️ HER SCALE IS A DELIBERATE HUB-ONLY LEGIBILITY CHOICE, NOT A PHYSICAL
## MEASUREMENT -- closing the open item the cutaway lot left behind ("sa
## taille... jamais jugée à l'oeil de loin"). MEASURED before anything was
## touched, through the shipped HubCamera (a jettable probe reading real
## AABBs off the built nodes, Keepy standing right at the cabin's own
## layout position so camera-to-subject distance is comparable both ways):
## at this entry's shipped scale of 7.0, `pose["scale"]` alone (which is
## MAGPIE_SCALE / CabinInterior.CABIN_SCALE, i.e. 0.76461/11) draws her at
## a world height of 0.8591 -- **96.06 px** on a 1080x1920 screen, against
## Keepy's own **123.89 px** at that same camera distance. 77.5% of him,
## and shrinking further the farther he stands from the cabin.
##
## `pose["scale"]` divides MAGPIE_SCALE by CabinInterior.CABIN_SCALE (11.0)
## because the INTERIOR needs her a fraction of that fixed camera's own
## frame; dividing again by THIS entry's cabin_uniform below undoes that
## division and multiplies back by cabin_uniform is what _build() applies
## to the whole root right after this function returns -- so the two
## uniforms cancel and what is left, net, is MAGPIE_SCALE itself: her own
## interior height, undiminished by how small the hub happens to draw the
## cabin around her. RE-MEASURED on the built result through the SAME
## probe: world height is exactly 1.3501 (matches
## MAGPIE_MODEL_MAX_Y - MAGPIE_MODEL_MIN_Y times MAGPIE_SCALE to the 5th
## decimal -- the formula does what it says), reading as **151.09 px**.
## That is LARGER than Keepy's own 123.89 px in this same framing, not
## merely close to it: her local position inside the cabin sits a little
## nearer the camera along its own depth than the exact spot Keepy was
## standing on for his own reading, and a scale correction cannot remove a
## depth difference. Accepted rather than fought -- a magpie that reads
## as big as or slightly bigger than Keepy from across the plateau is the
## legible failure mode; the 96.06 px original was the illegible one.
##
## This makes her taller, relative to THIS cabin prop, than she is relative
## to the cabin indoors -- a real physical inconsistency between the two
## views, accepted on purpose: legibility from a distance is the only job
## this copy of her has, and magpie_local_pose() (the interior's own,
## camera-tuned proportions) is never touched to get it.
func _furnish_cabin(root: Node3D, cabin_uniform: float) -> void:
	if magpie_scene == null:
		push_error("HubBuilder: a cabin was built but no magpie_scene is assigned; the cutaway view is missing its bird.")
		return
	var bird := magpie_scene.instantiate() as Node3D
	if bird == null:
		push_error("HubBuilder: magpie_scene does not instantiate to a Node3D.")
		return
	var pose: Dictionary = CabinInterior.magpie_local_pose()
	bird.name = "Magpie"
	bird.position = pose["position"]
	bird.scale = Vector3.ONE * (CabinInterior.MAGPIE_SCALE / maxf(cabin_uniform, 0.0001))
	bird.rotation_degrees = Vector3(0.0, float(pose["yaw_degrees"]), 0.0)
	root.add_child(bird)

## A cut trunk. Deliberately ONE mesh in the trees' own bark colour: a
## stump is what a tree leaves behind, so sharing the colour is what makes
## the pair read as a story rather than as two unrelated props. No lighter
## disc on the cut face -- that would be a second material for a surface
## the camera, at -34 degrees and 7.6 units up, sees almost edge-on.
func _make_stump() -> Node3D:
	var root := Node3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.44
	mesh.height = 0.55
	mesh.radial_segments = 8
	mesh.rings = 1
	root.add_child(_mesh_node(mesh, TRUNK_COLOR, Vector3(0.0, 0.275, 0.0)))
	return root

## Standing water, far out in the outer ring, as somewhere to go.
##
## Two flat discs, not one: an opaque bank slightly wider than the water,
## so the alpha surface has a rim to end on. Both are CylinderMesh rather
## than PlaneMesh -- a plane is single-sided, and a viewer who ever sees
## this screen from below the horizon would find the water simply absent.
##
## The heights are what keep it out of a z-fight with the ground. The
## ground is a PlaneMesh at exactly y = 0; the bank's underside sits at
## 0.005 and the water's at 0.02, so neither is ever coplanar with it.
## They are NOT scaled with the radius: a lake-sized slab 0.15 thick would
## show its own edge, which is the one thing a flat water surface must not
## do.
##
## Shared by pond and lake so the two cannot drift apart on either of the
## traps above.
##
## The two slabs are (thickness, centre y) pairs with the pond's own values
## as defaults, so pond and lake keep the exact geometry they shipped with
## and only the great lake -- which has to slide under the small one, see
## its constants -- ever passes anything else.
func _make_water_body(water_radius: float, bank_radius: float, segments: int, water_colour: Color,
		bank_slab: Vector2 = Vector2(0.05, 0.03), water_slab: Vector2 = Vector2(0.06, 0.05)) -> Node3D:
	var root := Node3D.new()

	var bank := CylinderMesh.new()
	bank.top_radius = bank_radius
	bank.bottom_radius = bank_radius
	bank.height = bank_slab.x
	bank.radial_segments = segments
	bank.rings = 1
	root.add_child(_mesh_node(bank, POND_BANK_COLOR, Vector3(0.0, bank_slab.y, 0.0)))

	var water := CylinderMesh.new()
	water.top_radius = water_radius
	water.bottom_radius = water_radius
	water.height = water_slab.x
	water.radial_segments = segments
	water.rings = 1
	var surface := _mesh_node(water, water_colour, Vector3(0.0, water_slab.y, 0.0))
	var material := surface.get_surface_override_material(0) as StandardMaterial3D
	# Alpha blending, and it has to be asked for: albedo_color's alpha
	# channel is ignored entirely while transparency stays at DISABLED, so
	# the water would render as flat opaque teal with no error to say so.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	root.add_child(surface)
	return root

func _make_pond() -> Node3D:
	return _make_water_body(POND_WATER_RADIUS, POND_BANK_RADIUS, POND_SEGMENTS, POND_WATER_COLOR)

## The lake. Same two discs as the pond, 2.5x across, in a light blue of
## its own -- see LAKE_WATER_COLOR for why a different HUE and not just a
## brighter pond. The bank reuses POND_BANK_COLOR on purpose: a bank is a
## bank, the same reasoning that has a stump share the trees' bark colour.
func _make_lake() -> Node3D:
	return _make_water_body(SMALL_LAKE_WATER_RADIUS, LAKE_BANK_RADIUS, LAKE_SEGMENTS, LAKE_WATER_COLOR)

## The great lake. Same two discs again, sized and coloured by its own
## constants and slid under the small lake's -- see GREATLAKE_WATER_COLOR
## for the height stack and for why the two shores necessarily merge.
##
## Segment count is calibrated to the RADIUS, not inherited. The flat-edge
## deviation of a disc is r*(1-cos(pi/n)), and it grows with r: the lake's
## 40 segments at radius 8 give 0.0247, and reusing them at radius 20 would
## give 0.0617 -- visibly faceted at more than twice the deviation. 96
## segments bring it back to 0.0107, flatter per edge than either of the
## smaller waters, for a mesh that is still trivially cheap.
##
## SPAWN-LAKE-1 made this maker serve TWO lobes, and the radius comes from
## HubRegion rather than from the entry: the drawn disc and the one
## `HubRegion.in_lake_water()` can still answer questions about have to be
## one circle, so the entry names WHICH lake and HubRegion says HOW BIG. A
## centre HubRegion does not know is an error and draws nothing, rather
## than silently defaulting to the first lobe's size. (HubRegion no longer
## subtracts this disc from the walkable region -- 26 aout 2026, Mathieu's
## decision that all five water bodies are walkable -- but it is still the
## one owner of this disc's geometry.)
func _make_greatlake(entry: Dictionary) -> Node3D:
	var centre: Vector3 = entry.get("position", Vector3.ZERO)
	var index: int = HubRegion.lake_index_at(centre)
	if index < 0:
		push_error("HubBuilder: greatlake at %s is not one of HubRegion's lakes; nothing drawn." % centre)
		return null
	var water_radius: float = HubRegion.water_radius_at(centre)
	return _make_water_body(
		water_radius,
		water_radius + GREATLAKE_BANK_MARGIN,
		GREATLAKE_SEGMENTS,
		GREATLAKE_WATER_COLOR,
		GREATLAKE_BANK_SLABS[index],
		GREATLAKE_WATER_SLABS[index])

## An islet in the great lake. One disc; the landmark that stands on it is
## a separate layout entry at the same position, so the pairing is data and
## an islet can be moved, resized or left bare without touching code.
func _make_islet(entry: Dictionary) -> Node3D:
	var radius: float = entry.get("radius", ISLET_RADIUS)
	if radius <= 0.0:
		push_error("HubBuilder: an islet needs a positive radius, got %f." % radius)
		return null
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = ISLET_THICKNESS
	disc.radial_segments = ISLET_SEGMENTS
	disc.rings = 1
	var root := Node3D.new()
	root.add_child(_mesh_node(disc, ISLET_COLOR, Vector3(0.0, ISLET_CENTRE_Y, 0.0)))
	return root

## The trace of a &"stream" entry, as plain Vector3s. Empty for anything
## malformed -- validated here rather than trusted, like every other entry.
func _trace_points(entry: Dictionary) -> Array:
	var raw: Variant = entry.get("points", null)
	if raw == null:
		return []
	if not (raw is PackedVector3Array or raw is Array):
		return []
	var out: Array = []
	for value in raw:
		if value is Vector3:
			out.append(value)
	return out

## Running water between two standing ones.
##
## WHY A HAND-BUILT RIBBON AND NOT A CSGPolygon3D ALONG A Path3D. Four
## reasons, in the order they decided it:
##
##   1. There is not ONE CSG node anywhere in this repository -- grepped,
##      not assumed. Every piece of hub decor is a primitive built in code.
##      A stream is not the place to introduce a second paradigm.
##   2. CSG is a runtime solver: a CSGShape3D keeps a brush and re-evaluates
##      it, and it carries a use_collision flag that would have to be
##      explicitly held off against this screen's standing rule that nothing
##      on the plateau has physics. An ArrayMesh is baked once, here, and
##      has no flag that can turn into a collider by default.
##   3. Segment control. CSGPolygon3D's path mode subdivides by an interval,
##      which is an indirect handle on the thing that actually matters --
##      the flat-edge deviation on a curve. STREAM_SAMPLES_PER_SPAN sets it
##      directly, the same way LAKE_SEGMENTS was calibrated to its radius.
##   4. A CSG node is not a MeshInstance3D, so it could not go through
##      _unshaded() -- and this file having exactly one material factory is
##      what keeps every surface on the plateau honest.
##
## ZERO THICKNESS, drawn double-sided. _make_water_body spells out why a
## flat water surface must never show its own edge; a ribbon with no
## thickness cannot, and CULL_DISABLED answers the "a plane is single-sided"
## objection by construction rather than by hoping nobody looks from below.
func _make_stream(entry: Dictionary) -> Node3D:
	var trace: Array = _trace_points(entry)
	if trace.size() < 2:
		push_error("HubBuilder: a stream needs at least 2 trace points, got %d." % trace.size())
		return null
	for key in ["position", "rotation_y", "scale"]:
		if entry.has(key):
			push_warning("HubBuilder: a stream entry carries '%s'; its trace IS its placement, so the field is ignored." % key)

	var width: float = entry.get("width", STREAM_WIDTH)
	if width <= 0.0:
		push_error("HubBuilder: a stream needs a positive width, got %f." % width)
		return null
	var half: float = width * 0.5
	_stream_half_width = half
	var spine: Array = _centripetal(trace, STREAM_SAMPLES_PER_SPAN)
	# Kept so HubStreamRoute can be handed the curve that was BUILT.
	# See stream_spine() for why it is not re-derived from the trace.
	_stream_spine = spine

	var left: Array = []
	var right: Array = []
	for i in spine.size():
		var before: Vector3 = spine[maxi(0, i - 1)]
		var after: Vector3 = spine[mini(spine.size() - 1, i + 1)]
		var tangent := Vector3(after.x - before.x, 0.0, after.z - before.z)
		if tangent.length() < 0.0001:
			tangent = Vector3(0.0, 0.0, 1.0)
		tangent = tangent.normalized()
		# Perpendicular in the ground plane. The ribbon is flat by
		# construction: y comes from the constant, never from the trace, so
		# a control point authored with a stray y cannot tilt the water.
		var side := Vector3(-tangent.z, 0.0, tangent.x) * half
		var middle: Vector3 = spine[i]
		left.append(Vector3(middle.x - side.x, STREAM_SURFACE_Y, middle.z - side.z))
		right.append(Vector3(middle.x + side.x, STREAM_SURFACE_Y, middle.z + side.z))

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in spine.size() - 1:
		for vertex in [left[i], right[i], right[i + 1], left[i], right[i + 1], left[i + 1]]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(vertex)

	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	var material := _unshaded(STREAM_WATER_COLOR)
	# Same trap the ponds hit: albedo_color's alpha is ignored entirely
	# while transparency stays DISABLED, and the stream would render as
	# flat opaque cyan with no error to say so.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.set_surface_override_material(0, material)
	return node

## An open nutshell, floating in the stream.
##
## SYMMETRIC FORE AND AFT, deliberately: the ride is bidirectional (its
## direction comes from where the player tapped, not from the layout), so
## a hull with a bow would be pointing the wrong way half the time and
## would need an orientation this file has no way to know. A shape with no
## front cannot be back to front.
##
## Built with SurfaceTool and NOT a CSG node, for the four reasons
## _make_stream() spells out -- there is not one CSG node in this
## repository, CSG is a runtime solver carrying a use_collision flag this
## screen must not grow, segment control here is direct, and a CSG node
## could not go through _unshaded().
##
## The shell is drawn DOUBLE-SIDED and hollow rather than as a closed
## solid: one surface then reads as a bowl from above and as a hull from
## the side, which is both the cheaper mesh and the shape a walnut half
## actually is. It carries NO collider, like every other prop here -- the
## ride is driven by an abscissa along HubStreamRoute, never by physics.
func _make_boat() -> Node3D:
	var root := Node3D.new()
	var shell := _mesh_node(_boat_shell_mesh(), BOAT_HULL_COLOR, Vector3(0.0, BOAT_FLOAT_Y, 0.0))
	# The shell is an open surface, so its inside faces AWAY from the
	# camera: at the default cull mode the bowl would be an invisible hole
	# with a rim floating over it. Same class of trap as the ponds' alpha
	# flag -- correct-looking geometry, nothing drawn, and no error to say
	# so. The rim is a flat annulus seen from above and needs no such help.
	var shell_material: StandardMaterial3D = shell.get_surface_override_material(0)
	shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(shell)
	# The hollow, drawn as its own slightly smaller shell in the light
	# tone. Inset so the dark outer wall still shows as a thickness at the
	# rim rather than the two surfaces meeting exactly.
	var inner := _mesh_node(_boat_shell_mesh(BOAT_INNER_INSET), BOAT_INNER_COLOR,
		Vector3(0.0, BOAT_FLOAT_Y + 0.005, 0.0))
	var inner_material: StandardMaterial3D = inner.get_surface_override_material(0)
	inner_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(inner)
	root.add_child(_mesh_node(_boat_rim_mesh(), BOAT_RIM_COLOR, Vector3(0.0, BOAT_FLOAT_Y, 0.0)))
	return root

## The hull: the lower half of an ellipsoid, keel at -BOAT_DEPTH, rim at 0.
##
## Parameterised by a quarter turn so the wall is vertical at the rim and
## flat at the keel -- a straight-sided cone would read as a bucket, and a
## hemisphere with the rim's radius would sit too deep for a hull under a
## metre long.
func _boat_shell_mesh(inset: float = 0.0) -> ArrayMesh:
	var half_beam: float = BOAT_BEAM * 0.5 - inset
	var half_length: float = BOAT_LENGTH * 0.5 - inset
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in BOAT_TIERS:
		var phi_a: float = PI * 0.5 * float(tier) / float(BOAT_TIERS)
		var phi_b: float = PI * 0.5 * float(tier + 1) / float(BOAT_TIERS)
		for seg in BOAT_RADIAL_SEGMENTS:
			var th_a: float = TAU * float(seg) / float(BOAT_RADIAL_SEGMENTS)
			var th_b: float = TAU * float(seg + 1) / float(BOAT_RADIAL_SEGMENTS)
			var quad: Array = [
				_boat_shell_point(phi_a, th_a, half_beam, half_length),
				_boat_shell_point(phi_b, th_a, half_beam, half_length),
				_boat_shell_point(phi_b, th_b, half_beam, half_length),
				_boat_shell_point(phi_a, th_a, half_beam, half_length),
				_boat_shell_point(phi_b, th_b, half_beam, half_length),
				_boat_shell_point(phi_a, th_b, half_beam, half_length),
			]
			for vertex in quad:
				tool.set_normal(Vector3.UP)
				tool.add_vertex(vertex)
	var mesh: ArrayMesh = tool.commit()
	return mesh

func _boat_shell_point(phi: float, theta: float, half_beam: float, half_length: float) -> Vector3:
	var r: float = sin(phi)
	return Vector3(
		half_beam * r * sin(theta),
		-BOAT_DEPTH * cos(phi),
		half_length * r * cos(theta))

## The cut edge of the shell: a flat annulus at the rim, in the lighter
## tint. Small, and it is what makes the hollow legible at the size this is
## drawn -- without it the bowl reads as a dark blob.
func _boat_rim_mesh() -> ArrayMesh:
	var inner_beam: float = BOAT_BEAM * 0.5
	var inner_length: float = BOAT_LENGTH * 0.5
	var outer_beam: float = inner_beam + BOAT_RIM
	var outer_length: float = inner_length + BOAT_RIM
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for seg in BOAT_RADIAL_SEGMENTS:
		var th_a: float = TAU * float(seg) / float(BOAT_RADIAL_SEGMENTS)
		var th_b: float = TAU * float(seg + 1) / float(BOAT_RADIAL_SEGMENTS)
		var ia := Vector3(inner_beam * sin(th_a), 0.0, inner_length * cos(th_a))
		var ib := Vector3(inner_beam * sin(th_b), 0.0, inner_length * cos(th_b))
		var oa := Vector3(outer_beam * sin(th_a), 0.0, outer_length * cos(th_a))
		var ob := Vector3(outer_beam * sin(th_b), 0.0, outer_length * cos(th_b))
		for vertex in [ia, oa, ob, ia, ob, ib]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(vertex)
	var mesh: ArrayMesh = tool.commit()
	return mesh

## Centripetal Catmull-Rom (alpha = 0.5) through the control points.
##
## CENTRIPETAL AND NOT UNIFORM, and it is the difference between a stream
## that fits and one that does not. The uniform form overshoots on a tight
## bend, and measured on this plateau that overshoot alone pushed the ribbon
## 0.4 units into props the trace was routed to clear. Centripetal is the
## variant that provably produces no cusp and no self-intersection.
##
## The end tangents are mirrored rather than duplicated, so the curve leaves
## each water body along the direction of its own first span instead of
## flattening against it.
func _centripetal(points: Array, per_span: int) -> Array:
	var padded: Array = []
	padded.append(points[0] * 2.0 - points[1])
	padded.append_array(points)
	padded.append(points[points.size() - 1] * 2.0 - points[points.size() - 2])

	var out: Array = []
	for i in padded.size() - 3:
		var p0: Vector3 = padded[i]
		var p1: Vector3 = padded[i + 1]
		var p2: Vector3 = padded[i + 2]
		var p3: Vector3 = padded[i + 3]
		var t0: float = 0.0
		var t1: float = t0 + sqrt(maxf(p0.distance_to(p1), 0.0001))
		var t2: float = t1 + sqrt(maxf(p1.distance_to(p2), 0.0001))
		var t3: float = t2 + sqrt(maxf(p2.distance_to(p3), 0.0001))
		var last: int = per_span - 1
		if i == padded.size() - 4:
			last = per_span
		for k in last + 1:
			var t: float = t1 + (t2 - t1) * float(k) / float(per_span)
			var a1: Vector3 = p0.lerp(p1, (t - t0) / (t1 - t0))
			var a2: Vector3 = p1.lerp(p2, (t - t1) / (t2 - t1))
			var a3: Vector3 = p2.lerp(p3, (t - t2) / (t3 - t2))
			var b1: Vector3 = a1.lerp(a2, (t - t0) / (t2 - t0))
			var b2: Vector3 = a2.lerp(a3, (t - t1) / (t3 - t1))
			out.append(b1.lerp(b2, (t - t1) / (t2 - t1)))
	return out

## An orientation marker, readable from the far side of the plateau.
##
## ~8.4 units tall against a standard tree's 2.85 -- roughly 3x, which is
## what buys it back over the tree field at 25+ units. Height alone is not
## enough though: a tree scaled up is still tree-shaped and reads as more
## of the same, so each variant is a DIFFERENT SILHOUETTE (a needle, a
## blocky pile, a pair of standing slabs). Telling one landmark from
## another at a glance is what carries orientation; merely having four of
## them does not.
##
## "variant" picks the silhouette, same mechanism as flower -- out of
## range falls back to 0 so a layout written without the field still
## builds.
func _make_landmark(entry: Dictionary) -> Node3D:
	var variant: int = entry.get("variant", 0)
	match variant:
		1:
			return _make_landmark_cairn()
		2:
			return _make_landmark_slabs()
		_:
			return _make_landmark_spire()

## Variant 0 -- a narrow needle. Distinguished at distance by being thin.
func _make_landmark_spire() -> Node3D:
	var root := Node3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.42
	trunk.height = 5.2
	trunk.radial_segments = 8
	trunk.rings = 1
	root.add_child(_mesh_node(trunk, LANDMARK_SPIRE_TRUNK, Vector3(0.0, 2.6, 0.0)))
	# Cones are CylinderMesh with a zero top radius; three stacked ones
	# give the stepped conifer edge a single cone cannot.
	var tiers: Array = [[1.25, 2.4, 5.0], [0.95, 2.1, 6.3], [0.62, 1.8, 7.55]]
	for tier in tiers:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = tier[0]
		cone.height = tier[1]
		cone.radial_segments = 8
		cone.rings = 1
		root.add_child(_mesh_node(cone, LANDMARK_SPIRE_CROWN, Vector3(0.0, tier[2], 0.0)))
	return root

## Variant 1 -- a blocky stacked mass. The opposite read to the spire:
## wide, stepped, and grey rather than green.
func _make_landmark_cairn() -> Node3D:
	var root := Node3D.new()
	var blocks: Array = [
		[Vector3(2.60, 1.50, 2.40), 0.75, 0.0, LANDMARK_CAIRN_STONE],
		[Vector3(2.10, 1.70, 1.90), 2.30, 22.0, LANDMARK_CAIRN_STONE],
		[Vector3(1.55, 1.90, 1.45), 4.00, -18.0, LANDMARK_CAIRN_STONE],
		[Vector3(1.05, 1.50, 0.95), 5.60, 35.0, LANDMARK_CAIRN_CAP],
	]
	for block in blocks:
		var box := BoxMesh.new()
		box.size = block[0]
		root.add_child(_mesh_node(box, block[3], Vector3(0.0, block[1], 0.0), Vector3(0.0, block[2], 0.0)))
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.55
	spike.height = 2.2
	spike.radial_segments = 6
	spike.rings = 1
	root.add_child(_mesh_node(spike, LANDMARK_CAIRN_CAP, Vector3(0.0, 7.3, 0.0)))
	return root

## Variant 2 -- two standing slabs of unequal height. Reads as a pair of
## vertical bars, which neither of the other two can be mistaken for.
func _make_landmark_slabs() -> Node3D:
	var root := Node3D.new()
	var rubble := BoxMesh.new()
	rubble.size = Vector3(2.90, 0.70, 1.90)
	root.add_child(_mesh_node(rubble, LANDMARK_SLAB_BASE, Vector3(0.0, 0.35, 0.0), Vector3(0.0, 6.0, 0.0)))
	var tall := BoxMesh.new()
	tall.size = Vector3(1.15, 8.00, 0.60)
	root.add_child(_mesh_node(tall, LANDMARK_SLAB_STONE, Vector3(-0.85, 4.00, 0.10), Vector3(0.0, 12.0, -4.0)))
	var short := BoxMesh.new()
	short.size = Vector3(0.95, 6.60, 0.50)
	root.add_child(_mesh_node(short, LANDMARK_SLAB_STONE, Vector3(0.90, 3.30, -0.15), Vector3(0.0, -18.0, 5.0)))
	return root

## Scratch for the board just built, handed to _build so it can enforce
## one-board-per-layout before publishing it. Not the published copy.
var _last_board: Dictionary = {}

## The diving board. A ladder on the bank, a plank out over the water, and
## the supports under it.
##
## `where` is the LADDER FOOT in world space -- the same value _build will
## give the returned node -- and it is passed in because the rungs are
## BATCHED, and a batch instance carries a world transform rather than
## living under this node.
##
## Everything else is measured off the entry's own two ends. The facing is
## the flat unit vector from the ladder to the anchor unless the entry
## states one, the deck height is the anchor's y, and the plank is drawn
## long enough to reach past the anchor -- so an author moves the board by
## moving its ends, and the drawing follows.
func _make_divingboard(entry: Dictionary, index: int, where: Vector3) -> Node3D:
	_last_board = {}

	# Refused rather than honoured, exactly as &"stream" refuses them: the
	# facing already comes from the two ends, so a rotation would be a
	# second orthography of it, free to disagree.
	if entry.has("rotation_y") or entry.has("scale"):
		push_warning("HubBuilder: entry %d is a divingboard and carries rotation_y/scale; its facing comes from its ends, so those are ignored." % index)

	var ladder := Vector3(where.x, 0.0, where.z)
	var anchor: Vector3 = entry.get("deck_anchor", Vector3.INF)
	if anchor == Vector3.INF:
		push_error("HubBuilder: entry %d is a divingboard with no \"deck_anchor\"; without it there is nowhere to stand." % index)
		return null
	var deck_height: float = anchor.y
	if deck_height <= 0.0:
		push_error("HubBuilder: entry %d has a deck_anchor at y = %.3f; a board at or below the ground cannot be dived from." % [index, deck_height])
		return null

	var forward: Vector3 = entry.get("dive_direction", Vector3.ZERO)
	forward = Vector3(forward.x, 0.0, forward.z)
	if forward.length_squared() < 0.000001:
		# Not stated: the ladder-to-anchor line IS the facing, which is the
		# only direction a board with those two ends could possibly face.
		forward = Vector3(anchor.x - ladder.x, 0.0, anchor.z - ladder.z)
	if forward.length_squared() < 0.000001:
		push_error("HubBuilder: entry %d has an anchor on top of its ladder and no dive_direction; the board has no facing." % index)
		return null
	forward = forward.normalized()
	var side := Vector3(forward.z, 0.0, -forward.x)

	# How far out along the facing the anchor sits, and therefore how long
	# the plank has to be to carry it plus a step of tip beyond.
	var anchor_reach: float = (Vector3(anchor.x, 0.0, anchor.z) - ladder).dot(forward)
	var deck_reach: float = maxf(anchor_reach + 0.60, 1.20)

	var root := Node3D.new()
	root.name = "DivingBoard"

	# ---- the plank
	var deck := BoxMesh.new()
	deck.size = Vector3(DIVINGBOARD_DECK_WIDTH,
		DIVINGBOARD_DECK_THICKNESS,
		deck_reach + DIVINGBOARD_DECK_BACK_OVERHANG)
	var deck_centre: float = (deck_reach - DIVINGBOARD_DECK_BACK_OVERHANG) * 0.5
	# Rotated to lie ALONG the facing. Built in the parent's space rather
	# than in a local frame because the node itself carries no rotation --
	# see the header on why this type refuses one.
	var deck_yaw: float = rad_to_deg(atan2(forward.x, forward.z))
	root.add_child(_mesh_node(deck, DIVINGBOARD_DECK_COLOR,
		forward * deck_centre + Vector3.UP * (deck_height + DIVINGBOARD_DECK_THICKNESS * 0.5),
		Vector3(0.0, deck_yaw, 0.0)))

	# ---- posts, a pair at the ladder and a pair under the tip
	var underside: float = deck_height
	for reach in [0.0, maxf(deck_reach - DIVINGBOARD_POST_TIP_INSET, 0.6)]:
		for lateral in [-DIVINGBOARD_POST_HALF_SPAN, DIVINGBOARD_POST_HALF_SPAN]:
			var post := CylinderMesh.new()
			post.top_radius = DIVINGBOARD_POST_RADIUS
			post.bottom_radius = DIVINGBOARD_POST_RADIUS
			post.height = underside
			post.radial_segments = 8
			post.rings = 1
			root.add_child(_mesh_node(post, DIVINGBOARD_FRAME_COLOR,
				forward * float(reach) + side * float(lateral) + Vector3.UP * (underside * 0.5)))

	# ---- ladder rails, set back behind the plank's leading edge
	for lateral in [-DIVINGBOARD_RAIL_HALF_SPAN, DIVINGBOARD_RAIL_HALF_SPAN]:
		var rail := CylinderMesh.new()
		rail.top_radius = DIVINGBOARD_RAIL_RADIUS
		rail.bottom_radius = DIVINGBOARD_RAIL_RADIUS
		rail.height = deck_height
		rail.radial_segments = 6
		rail.rings = 1
		root.add_child(_mesh_node(rail, DIVINGBOARD_FRAME_COLOR,
			forward * -DIVINGBOARD_DECK_BACK_OVERHANG * 0.5
				+ side * float(lateral) + Vector3.UP * (deck_height * 0.5)))

	# ---- rungs, BATCHED: identical geometry repeated up the ladder is the
	# one thing on this prop a MultiMesh is for. The count is rounded so
	# the run divides evenly rather than leaving a rung jammed under the
	# deck; the transforms are WORLD, because a batch has no node to sit
	# under.
	var rung_run: float = deck_height - DIVINGBOARD_RUNG_LOWEST - 0.15
	# rung_run / DIVINGBOARD_RUNG_SPACING lands EXACTLY on round()'s .5
	# knife-edge whenever deck_height sits on the 0.6-unit grid (deck_height
	# = 0.6 + 0.3*n) -- measured: BOTH 1.8 (n=4, true ratio 4.5) and 2.4
	# (n=6, true ratio 6.5) do, not just the height that happened to be
	# noticed. anchor.y is a Vector3 component, so it is float32 storage:
	# what reaches here is never the true tie, it is that tie perturbed by
	# ~1.6e-7 to ~3.2e-7 in whichever direction float32 rounding happens to
	# go -- and THAT arbitrary direction used to decide the rung count (5 vs
	# 6 at deck_height=1.8, measured before this fix). Rounding explicitly
	# with ties broken DOWN, at an epsilon three orders of magnitude above
	# that noise floor, makes the count depend on the intended height
	# instead of on a rounding artefact. Verified to still give
	# rung_count=5 at deck_height=1.8 -- the shipped, device-validated
	# MEDIAN cadence keys its rhythm to that number, not just to the height.
	const DIVINGBOARD_RUNG_TIE_EPS: float = 0.0001
	var rung_ratio: float = rung_run / DIVINGBOARD_RUNG_SPACING
	var rung_rounded: int = int(floor(rung_ratio + 0.5 - DIVINGBOARD_RUNG_TIE_EPS))
	var rung_count: int = maxi(rung_rounded + 1, 2)
	# A CylinderMesh stands on its own +Y, and a rung lies ACROSS the
	# ladder -- so the batch basis maps that +Y onto `side`. Built from the
	# two vectors the board already has rather than from an Euler angle:
	# the columns are orthonormal and right-handed by construction
	# (side x UP is a unit vector perpendicular to both), which an angle
	# would only be if the sign convention happened to be guessed right.
	var rung_basis := Basis(side.cross(Vector3.UP), side, Vector3.UP)
	# The exact heights are collected as they are computed for the drawn
	# rungs -- ONE formula, not a copy of it published alongside a second.
	# KeepyHopper's climb reads this array rather than re-deriving
	# DIVINGBOARD_RUNG_LOWEST/SPACING itself: those stay private here, and
	# the climb keys its cadence to whatever the ladder was actually built
	# with instead of a value free to disagree with it.
	var rung_heights: Array = []
	for i in rung_count:
		var frac: float = float(i) / float(rung_count - 1)
		var y: float = DIVINGBOARD_RUNG_LOWEST + rung_run * frac
		rung_heights.append(y)
		var origin: Vector3 = ladder + forward * (-DIVINGBOARD_DECK_BACK_OVERHANG * 0.5) + Vector3.UP * y
		_instance(&"DivingBoardRung", Transform3D(rung_basis, origin))

	# The two ends and the two dive targets, published as one fact each.
	var flat_anchor := Vector3(anchor.x, 0.0, anchor.z)
	_last_board = {
		"ladder": ladder,
		"anchor": Vector3(anchor.x, deck_height, anchor.z),
		"forward": forward,
		# The climb's lateral sway is measured off THIS side, not a second
		# one re-derived from "forward" in KeepyHopper -- the sign
		# convention already lives here, next to the rails and posts it
		# places the same way, and a second copy of it is exactly how a
		# rename or a flipped cross product becomes a sway that goes the
		# wrong way on one file and not the other.
		"side": side,
		"rung_heights": rung_heights,
		"water_target": flat_anchor + forward * DIVINGBOARD_DIVE_REACH,
		# BACK TO THE LADDER FOOT, and not to some point behind it: that is
		# ground a player has already stood on, so it is the one landward
		# spot that cannot turn out to be inside a rock or over water.
		"land_target": ladder,
	}
	return root


## Scratch for the zipline just built, handed to _build the way the
## board's and the turnstile's are. Not the published copy.
var _last_zipline: Dictionary = {}

## The zipline: a tower at each end of the entry's two points, and the
## cable strung between their head frames.
##
## TIER 1 -- STRUCTURE ONLY. Nothing here registers a tap channel, a
## trigger radius or a ride. The stairs in particular carry NO hotspot of
## their own, on purpose: RECON 1 (docs/lots/CH21_TYROLIENNE.md) settled
## that a stair that swallows taps and emits nothing is the LADDER PATTERN
## this repo has banned -- a player standing on it would have no way left
## to say anything. Whatever tier 2 wires up will be a BOAT-PATTERN door
## on the boarding structure, which withdraws itself while it is in use so
## a tap always falls through to the ground path.
##
## `where` is the NEAR end in world space -- the same value _build gives
## the returned node -- and it is passed in because the legs, treads and
## stringers are BATCHED, and a batch instance carries a WORLD transform
## rather than living under this node. Everything that IS a child of the
## root is therefore built in the root's own space (world minus `where`),
## which is the one subtraction in this function and is done in one place.
func _make_zipline(entry: Dictionary, index: int, where: Vector3) -> Node3D:
	_last_zipline = {}

	# Refused rather than honoured, exactly as &"stream" and
	# &"divingboard" refuse them: the facing of both towers already comes
	# from the two ends, so a rotation would be a second orthography of it.
	if entry.has("rotation_y") or entry.has("scale"):
		push_warning("HubBuilder: entry %d is a zipline and carries rotation_y/scale; both towers face along its two ends, so those are ignored." % index)

	var ends: Array = _zipline_ends(entry)
	if ends.is_empty():
		push_error("HubBuilder: entry %d is a zipline with no \"far_end\"; a cable needs two ends." % index)
		return null
	var near: Vector3 = ends[0]
	var far: Vector3 = ends[1]
	var span: Vector3 = far - near
	if span.length_squared() < 0.000001:
		push_error("HubBuilder: entry %d has a zipline whose two ends are the same point; there is nothing to string a cable across." % index)
		return null
	var forward: Vector3 = span.normalized()

	var root := Node3D.new()
	root.name = "Zipline"

	# Same structure at both ends, each facing the other -- the cable is
	# bidirectional, so there is no "start" tower and no "arrival" one to
	# build differently. ONE builder called twice rather than two nearly
	# identical blocks: a departure that drifted from an arrival is exactly
	# the kind of divergence a second copy invites.
	var towers: Array = [
		_build_zipline_tower(root, forward, near, where),
		_build_zipline_tower(root, -forward, far, where),
	]

	# ---- the cable, anchored on the two head frames it was measured from
	var from_world: Vector3 = towers[0]["anchor"]
	var to_world: Vector3 = towers[1]["anchor"]
	var cable := CylinderMesh.new()
	cable.top_radius = ZIPLINE_CABLE_RADIUS
	cable.bottom_radius = ZIPLINE_CABLE_RADIUS
	cable.height = from_world.distance_to(to_world)
	cable.radial_segments = ZIPLINE_CABLE_SEGMENTS
	cable.rings = 1
	# A CylinderMesh stands on its own +Y, and the cable lies ALONG the
	# span -- so the basis maps that +Y onto `forward`. Built from two
	# vectors rather than an Euler angle, on the diving board's rungs'
	# terms: the columns are orthonormal and right-handed by construction,
	# which an angle would only be if the sign convention were guessed
	# right.
	var cable_node: MeshInstance3D = _placed(cable, ZIPLINE_CABLE_COLOR,
		Basis(forward.cross(Vector3.UP), forward, Vector3.UP),
		(from_world + to_world) * 0.5 - where)
	# NAMED, and the probe filters on it: the cable spans 24 u between two
	# towers, so a footprint measurement that swept every drawn child of
	# this root without excluding it would report an emprise the width of
	# the plateau and pass nothing.
	cable_node.name = "Cable"
	root.add_child(cable_node)

	_last_zipline = {
		"towers": towers,
		"cable": {"from": from_world, "to": to_world},
		"cable_height": ZIPLINE_CABLE_HEIGHT,
		"rider_drop": ZIPLINE_RIDER_DROP,
		"clear_radius": ZIPLINE_FOOTPRINT_RADIUS,
	}
	return root

## One tower, at `origin` in world space, facing `forward` (towards the
## other tower). Adds its node-owned parts under `root` in the root's own
## space -- hence `root_origin`, the world position _build will give that
## root -- and files its repeated parts into the shared batches in WORLD
## space. Returns the facts about the tower it just drew.
func _build_zipline_tower(root: Node3D, forward: Vector3, origin: Vector3, root_origin: Vector3) -> Dictionary:
	var side := Vector3(forward.z, 0.0, -forward.x)
	# side x UP == forward, so these three columns are orthonormal and
	# right-handed by construction -- the same reasoning as the cable's.
	var facing := Basis(side, Vector3.UP, forward)
	var local: Vector3 = origin - root_origin

	# ---- the platform
	var deck := BoxMesh.new()
	deck.size = Vector3(ZIPLINE_DECK_HALF * 2.0, ZIPLINE_DECK_THICKNESS, ZIPLINE_DECK_HALF * 2.0)
	var deck_node: MeshInstance3D = _placed(deck, ZIPLINE_DECK_COLOR, facing,
		local + Vector3.UP * (ZIPLINE_DECK_HEIGHT - ZIPLINE_DECK_THICKNESS * 0.5))
	deck_node.name = "Deck"
	root.add_child(deck_node)

	# ---- uprights, BATCHED. Rear pair stops at the deck; front pair
	# carries on to cable height and becomes the head frame.
	for lateral in [-ZIPLINE_LEG_HALF_SPAN, ZIPLINE_LEG_HALF_SPAN]:
		var rear: Vector3 = origin - forward * ZIPLINE_LEG_FORWARD + side * float(lateral)
		_instance(&"ZiplineLeg",
			Transform3D(Basis.IDENTITY, rear + Vector3.UP * (ZIPLINE_DECK_HEIGHT * 0.5)))
		var front: Vector3 = origin + forward * ZIPLINE_LEG_FORWARD + side * float(lateral)
		_instance(&"ZiplineMast",
			Transform3D(Basis.IDENTITY, front + Vector3.UP * (ZIPLINE_CABLE_HEIGHT * 0.5)))

	# ---- the head beam across the two masts. Its +Y lies along `side`,
	# the rungs' basis exactly.
	var beam := CylinderMesh.new()
	beam.top_radius = ZIPLINE_HEADBEAM_RADIUS
	beam.bottom_radius = ZIPLINE_HEADBEAM_RADIUS
	beam.height = ZIPLINE_LEG_HALF_SPAN * 2.0 + ZIPLINE_LEG_RADIUS * 2.0
	beam.radial_segments = 6
	beam.rings = 1
	var anchor: Vector3 = origin + forward * ZIPLINE_LEG_FORWARD + Vector3.UP * ZIPLINE_CABLE_HEIGHT
	var beam_node: MeshInstance3D = _placed(beam, ZIPLINE_FRAME_COLOR,
		Basis(side.cross(Vector3.UP), side, Vector3.UP), anchor - root_origin)
	beam_node.name = "HeadBeam"
	root.add_child(beam_node)

	# ---- treads, BATCHED: identical geometry repeated down the stair is
	# the one thing on this prop a MultiMesh is for. The deck is the LAST
	# riser, which is why the count divides DECK_HEIGHT by COUNT + 1 --
	# a tread level with the deck would be a step onto nothing.
	for i in ZIPLINE_STEP_COUNT:
		var top: float = ZIPLINE_DECK_HEIGHT * float(i + 1) / float(ZIPLINE_STEP_COUNT + 1)
		var reach: float = ZIPLINE_DECK_HALF \
			+ ZIPLINE_STEP_DEPTH * (float(ZIPLINE_STEP_COUNT - 1 - i) + 0.5)
		_instance(&"ZiplineStep", Transform3D(facing,
			origin - forward * reach + Vector3.UP * (top - ZIPLINE_STEP_THICKNESS * 0.5)))

	# ---- stringers, BATCHED. From the foot of the stair up to the deck
	# edge, so the treads read as fixed between two rails rather than
	# floating. Their +Z lies along the slope; Y = Z x X keeps the basis
	# right-handed without an angle anywhere.
	#
	# ⚠️ THE SLOPE RUNS foot -> head, AND THE SIGN IS NOT COSMETIC. Written
	# first as (-forward * run + UP * height) -- backwards-and-up rather
	# than forwards-and-up -- which MIRRORED each rail about the vertical:
	# the drawn stringers ran from the deck edge at GROUND level up to the
	# stair foot at DECK height, crossing the treads instead of carrying
	# them. The emprise number is blind to it (a mirrored box has the same
	# circumscribed radius -- measured, identical to five decimals), which
	# is why the probe also gates that a rail's HIGH end is its end NEAREST
	# the tower.
	var run: float = ZIPLINE_STEP_DEPTH * float(ZIPLINE_STEP_COUNT)
	var slope: Vector3 = (forward * run + Vector3.UP * ZIPLINE_DECK_HEIGHT).normalized()
	var stair_foot: Vector3 = origin - forward * (ZIPLINE_DECK_HALF + run)
	for lateral in [-ZIPLINE_STRINGER_HALF_SPAN, ZIPLINE_STRINGER_HALF_SPAN]:
		var foot: Vector3 = stair_foot + side * float(lateral)
		var head: Vector3 = origin - forward * ZIPLINE_DECK_HALF + side * float(lateral) \
			+ Vector3.UP * ZIPLINE_DECK_HEIGHT
		_instance(&"ZiplineStringer",
			Transform3D(Basis(side, slope.cross(side), slope), (foot + head) * 0.5))

	return {
		"position": Vector3(origin.x, 0.0, origin.z),
		"forward": forward,
		"deck": Vector3(origin.x, ZIPLINE_DECK_HEIGHT, origin.z),
		"anchor": anchor,
		"stair_foot": Vector3(stair_foot.x, 0.0, stair_foot.z),
	}

## Scratch for the turnstile just built, handed to _build the same way the
## board's is. Not the published copy.
var _last_turnstile: Dictionary = {}

## The turnstile: a playground roundabout. A stone footing that stays put,
## and above it a deck, a centre post and a ring of grip bars that all turn
## together on one pivot.
##
## =====================================================================
## THE BARS ARE BATCHED, BUT NOT INTO THE SCATTER BATCHES -- and that is a
## measured constraint, not a preference.
##
## _instance()/_flush_batches() file a prop into a MultiMesh whose instance
## transforms are WORLD and are baked once, and whose node is added as a
## child of HubBuilder itself. Nothing about that can rotate: the bars
## would sit in a different subtree from the pivot, so turning the pivot
## would leave them behind, pointing where the roundabout used to face.
##
## So this prop owns a MultiMeshInstance3D of its OWN, parented under the
## spinner, with its instances in the spinner's LOCAL space. It is still
## one draw node for however many bars there are, which is the whole reason
## a batch is wanted here -- it simply cannot be a shared one.
##
## =====================================================================
## WHAT IS AND IS NOT UNDER THE PIVOT
##
##   Turnstile          <- placed by _build (position / rotation_y / scale)
##     Footing          <- STATIC. The thing the spin is read against.
##     Spinner          <- the pivot, and the ONLY node ever rotated
##       Deck
##       Post
##       Bars           <- MultiMeshInstance3D, TURNSTILE_BARS instances
##
## The deck is NOT WALKABLE and nothing here tries to make it so. The
## plateau is single-altitude by construction -- HubRegion drops y and
## HubTapInput resolves every tap against Plane(UP, 0) -- so there is no
## tap that could mean "a point on the deck", and giving this prop one
## would mean a second ground for the whole screen. Keepy walks past it at
## y = 0 exactly as he walks past a landmark.
func _make_turnstile(_entry: Dictionary, _index: int, where: Vector3) -> Node3D:
	_last_turnstile = {}

	var root := Node3D.new()
	root.name = "Turnstile"

	# ---- the footing, OUTSIDE the spinner on purpose (see the header)
	var footing := CylinderMesh.new()
	footing.top_radius = TURNSTILE_BASE_RADIUS
	footing.bottom_radius = TURNSTILE_BASE_RADIUS
	footing.height = TURNSTILE_BASE_THICKNESS
	# Stated, never inherited: a primitive left at Godot's default is far
	# denser than any silhouette this size needs -- docs/MESHY_SPEC.md 7.2.
	footing.radial_segments = TURNSTILE_BASE_SEGMENTS
	footing.rings = 1
	var footing_node := _mesh_node(footing, TURNSTILE_BASE_COLOR,
		Vector3.UP * (TURNSTILE_BASE_THICKNESS * 0.5))
	footing_node.name = "Footing"
	root.add_child(footing_node)

	var spinner := Node3D.new()
	spinner.name = "Spinner"
	root.add_child(spinner)

	# ---- the deck
	var deck := CylinderMesh.new()
	deck.top_radius = TURNSTILE_DECK_RADIUS
	deck.bottom_radius = TURNSTILE_DECK_RADIUS
	deck.height = TURNSTILE_DECK_THICKNESS
	deck.radial_segments = TURNSTILE_DECK_SEGMENTS
	deck.rings = 1
	var deck_node := _mesh_node(deck, TURNSTILE_DECK_COLOR, Vector3.UP * TURNSTILE_DECK_Y)
	deck_node.name = "Deck"
	spinner.add_child(deck_node)

	# ---- the centre post
	var post := CylinderMesh.new()
	post.top_radius = TURNSTILE_POST_RADIUS
	post.bottom_radius = TURNSTILE_POST_RADIUS
	post.height = TURNSTILE_POST_HEIGHT
	post.radial_segments = 8
	post.rings = 1
	var post_node := _mesh_node(post, TURNSTILE_FRAME_COLOR,
		Vector3.UP * (TURNSTILE_DECK_Y + TURNSTILE_POST_HEIGHT * 0.5))
	post_node.name = "Post"
	spinner.add_child(post_node)

	# ---- the grip bars
	var bar := CylinderMesh.new()
	bar.top_radius = TURNSTILE_BAR_RADIUS
	bar.bottom_radius = TURNSTILE_BAR_RADIUS
	bar.height = TURNSTILE_BAR_LENGTH
	bar.radial_segments = 6
	bar.rings = 1

	var multi := MultiMesh.new()
	# FIRST, and before mesh/instance_count: TRANSFORM_2D is the DEFAULT in
	# Godot 4.3, and a MultiMesh left at it silently discards every 3D
	# transform written to it and draws the whole batch at the origin. The
	# order is the one _flush_batches() already had to learn.
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = bar
	multi.instance_count = TURNSTILE_BARS
	var local_aabb: AABB = bar.get_aabb()
	var bounds := AABB()
	for i in TURNSTILE_BARS:
		var angle: float = TAU * float(i) / float(TURNSTILE_BARS)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		# A CylinderMesh stands on its own +Y and a bar lies ALONG `out`,
		# so the basis maps that +Y onto it. Built from the cross product
		# rather than from an Euler angle: the columns are orthonormal and
		# right-handed by construction, which an angle would only be if the
		# sign convention happened to be guessed right. Same construction
		# as the ladder rungs, for the same reason.
		var basis := Basis(out.cross(Vector3.UP), out, Vector3.UP)
		var xform := Transform3D(basis,
			out * (TURNSTILE_BAR_LENGTH * 0.5) + Vector3.UP * TURNSTILE_BAR_Y)
		multi.set_instance_transform(i, xform)
		var box: AABB = xform * local_aabb
		bounds = box if i == 0 else bounds.merge(box)
	# Written and not trusted: a MultiMesh derives an AABB of its own, and a
	# wrong or stale one makes the whole batch vanish when the camera turns
	# -- with no error attached, on a screen nobody can look at before
	# staging. _flush_batches() carries the same note for the same reason.
	multi.custom_aabb = bounds

	var bars := MultiMeshInstance3D.new()
	bars.name = "Bars"
	bars.multimesh = multi
	bars.material_override = _unshaded(TURNSTILE_FRAME_COLOR)
	spinner.add_child(bars)

	_last_turnstile = {
		"position": Vector3(where.x, 0.0, where.z),
		"radius": TURNSTILE_TRIGGER_RADIUS,
		"spinner": spinner,
		# The TOP of the deck, not its centre: a CylinderMesh is centred on
		# its own origin, so the surface a rider stands on is half a
		# thickness above the node that carries it. Measured on the built
		# tree at 0.31 world with this prop at scale 1.
		"deck_y": TURNSTILE_DECK_Y + TURNSTILE_DECK_THICKNESS * 0.5,
		"ride_radius": TURNSTILE_RIDE_RADIUS,
		"bars": TURNSTILE_BARS,
		"clear_radius": TURNSTILE_BASE_RADIUS,
	}
	return root

## The seesaw. Three draw nodes, no asset, and the turnstile's tree with
## one axis changed:
##
##   Seesaw            <- placed by _build (position / rotation_y / scale)
##     Fulcrum         <- STATIC. What the tilt is read AGAINST.
##     Pivot           <- the ONLY node ever tilted
##       Plank
##       Grips         <- MultiMeshInstance3D, SEESAW_GRIPS instances
##
## THE FULCRUM IS OUTSIDE THE PIVOT, exactly as the turnstile's footing is
## outside its spinner, and for the same measured reason: a rotation is only
## legible against something that stays put, and a seesaw whose stone pivot
## rocked with the plank would read as the whole prop sliding rather than as
## one end going up.
func _make_seesaw(_entry: Dictionary, _index: int, where: Vector3) -> Node3D:
	_last_seesaw = {}

	var root := Node3D.new()
	root.name = "Seesaw"

	# ---- the fulcrum, OUTSIDE the pivot on purpose (see above)
	var stone := CylinderMesh.new()
	stone.top_radius = SEESAW_FULCRUM_RADIUS * 0.72
	stone.bottom_radius = SEESAW_FULCRUM_RADIUS
	stone.height = SEESAW_FULCRUM_HEIGHT
	# Stated, never inherited: a primitive left at Godot's default is far
	# denser than any silhouette this size needs -- docs/MESHY_SPEC.md 7.2.
	stone.radial_segments = SEESAW_FULCRUM_SEGMENTS
	stone.rings = 1
	var stone_node := _mesh_node(stone, SEESAW_FULCRUM_COLOR,
		Vector3.UP * (SEESAW_FULCRUM_HEIGHT * 0.5))
	stone_node.name = "Fulcrum"
	root.add_child(stone_node)

	# ---- the pivot, sitting ON TOP of the fulcrum so the plank rocks about
	# the stone's crown rather than about the ground.
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.position = Vector3.UP * SEESAW_FULCRUM_HEIGHT
	root.add_child(pivot)

	# ---- the plank, along local X (see the constants for why X and not Z)
	var plank := BoxMesh.new()
	plank.size = Vector3(SEESAW_PLANK_LENGTH, SEESAW_PLANK_THICKNESS, SEESAW_PLANK_WIDTH)
	var plank_node := _mesh_node(plank, SEESAW_PLANK_COLOR, Vector3.ZERO)
	plank_node.name = "Plank"
	pivot.add_child(plank_node)

	# ---- the grips, one per end, batched
	var grip := CylinderMesh.new()
	grip.top_radius = SEESAW_GRIP_RADIUS
	grip.bottom_radius = SEESAW_GRIP_RADIUS
	grip.height = SEESAW_GRIP_HEIGHT
	grip.radial_segments = SEESAW_GRIP_SEGMENTS
	grip.rings = 1

	var multi := MultiMesh.new()
	# FIRST, and before mesh/instance_count: TRANSFORM_2D is the DEFAULT in
	# Godot 4.3, and a MultiMesh left at it silently discards every 3D
	# transform written to it and draws the whole batch at the origin. The
	# order is the one _flush_batches() and the turnstile bars already had
	# to learn.
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = grip
	multi.instance_count = SEESAW_GRIPS
	var local_aabb: AABB = grip.get_aabb()
	var bounds := AABB()
	var seat_top: float = SEESAW_PLANK_THICKNESS * 0.5
	for i in SEESAW_GRIPS:
		var side: float = 1.0 if i == 0 else -1.0
		# A CylinderMesh already stands on its own +Y and a grip stands
		# upright, so the basis is the identity -- unlike the turnstile
		# bars, which LIE along their radius and need one built.
		var xform := Transform3D(Basis(),
			Vector3(side * SEESAW_GRIP_X, seat_top + SEESAW_GRIP_HEIGHT * 0.5, 0.0))
		multi.set_instance_transform(i, xform)
		var box: AABB = xform * local_aabb
		bounds = box if i == 0 else bounds.merge(box)
	# Written and not trusted: a MultiMesh derives an AABB of its own, and a
	# wrong or stale one makes the whole batch vanish when the camera turns
	# -- with no error attached, on a screen nobody can look at before
	# staging.
	multi.custom_aabb = bounds

	var grips := MultiMeshInstance3D.new()
	grips.name = "Grips"
	grips.multimesh = multi
	grips.material_override = _unshaded(SEESAW_GRIP_COLOR)
	pivot.add_child(grips)

	_last_seesaw = {
		"position": Vector3(where.x, 0.0, where.z),
		"radius": SEESAW_TRIGGER_RADIUS,
		"pivot": pivot,
		# The TOP of the plank, not its centre: a BoxMesh is centred on its
		# own origin, so the surface a rider stands on is half a thickness
		# above the node that carries it. Same correction the turnstile's
		# deck_y carries, for the same reason.
		"seat_y": seat_top,
		"ride_x": SEESAW_RIDE_X,
		"clear_radius": SEESAW_PLANK_LENGTH * 0.5,
	}
	return root

## _mesh_node's sibling, for parts whose orientation is a BASIS rather than
## a yaw. Euler angles are fine for a prop that only ever turns about Y;
## the zipline's stringers lie along a slope and its cable and head beam
## lie along horizontal axes derived from the span, and an Euler triple for
## those is a sign convention waiting to be guessed wrong -- the same
## reason the diving board's rungs are placed by a basis built from two
## vectors it already has.
func _placed(mesh: Mesh, colour: Color, basis: Basis, origin: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.transform = Transform3D(basis, origin)
	node.set_surface_override_material(0, _unshaded(colour))
	return node

func _mesh_node(mesh: Mesh, colour: Color, offset: Vector3, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = offset
	node.rotation_degrees = rotation_deg
	node.set_surface_override_material(0, _unshaded(colour))
	return node

## The one material this file ever makes. UNSHADED is the project's
## standing rule for every surface (see the header), and having a single
## factory is what keeps a batched prop's material identical to the
## individual-node one it replaced.
func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material
