extends Control
class_name HubMinimap
## CH46 -- THE PERMANENT MINIMAP: a north-fixed plan of the walkable world,
## visible on foot AND in every vehicle. Drawn in the bottom-LEFT corner
## until CH48 moved it to the bottom RIGHT (Mathieu: the left is where his
## thumb rests) and replaced its four abstract shapes with 22 miniatures of
## the real models. See the CH48 block below and docs/lots/CH48_*.md.
##
## =====================================================================
## THE FIVE DECISIONS THIS FILE OBEYS (Mathieu, brief CH46) -- not to be
## re-opened here
##
## 1. PERMANENT, in a corner. No full-screen map, no button to open it.
## 2. NORTH FIXED. The plan never rotates with the camera.
## 3. THE FRAME IS THE WALKABLE WORLD ALONE (HubRegion.walkable_bounds(),
##    137 x 247 u), not the all-vehicle frame. Anything outside -- the
##    sailboat runs up to 82 u past it in x -- is CLAMPED to the border
##    and drawn with a different icon. Nothing ever disappears silently.
## 4. THE ZONE BOUNDARIES ARE THE PAINTED ONES (CozyPalette.*_EDGE_Z),
##    not the logical ones (HubRegion). They differ by 2 to 4 u, and the
##    map has to agree with what Mathieu sees through the glass.
## 5. NO SubViewport. CH44 axe 5 measured one at +74 085 primitives and
##    +421 draw calls -- more than the entire 3D scene.
##
## =====================================================================
## WHY ONE TEXTURE FOR EVERYTHING, AND WHAT IT BOUGHT
##
## CH44 axe 5 measured a `Control._draw` built from `draw_circle` at
## +2 619 primitives / +43 draw calls for 40 markers, and named the
## cause: `draw_circle` emits a POLYGON command, and polygons do not
## batch -- one draw call per marker, linear in the number of markers and
## nothing to do with their size.
##
## Everything this file draws is therefore a `draw_texture_rect_region`
## on ONE runtime-built atlas: the baked plan occupies the top of the
## image, the four marker icons a strip under it. Same texture, same
## material, same command kind -- so Godot's canvas renderer coalesces
## the whole map, background included, into a handful of calls whatever
## the marker count. The measurement of both approaches is in
## docs/lots/CH46_MINIMAP.md; it was taken on the CH38/CH40 bench, same
## protocol as CH44, so the two are comparable.
##
## THE ICONS ARE WHITE SHAPES WITH BLACK OUTLINES, AND THAT IS LOAD-BEARING.
## A marker is tinted by the `modulate` argument, which MULTIPLIES: white
## fill becomes the kind's colour, and black outline stays black under any
## colour whatsoever. So every marker keeps a hard dark edge against grass,
## sand, heather, lawn or sea without a single per-kind contrast decision
## -- CLAUDE.md's own warning that WCAG scores nothing INSIDE a luminance
## band, answered by construction rather than by a table of tones.
##
## =====================================================================
## WHY IT KNOWS NO NODE PATHS
##
## See MinimapMarkers.gd. Half the entities worth drawing have no stable
## name at all (CH44 axe 3: the bear is `@Node3D@228`), so the map
## enumerates four groups and asks nothing else. An entity joins or leaves
## the map by one line at its own construction site.
##
## =====================================================================
## CH47 -- THE THREE RANKS, AND THE CLUSTERS
##
## Mathieu, on device, after CH46: "je ne comprends rien a cette map, il y
## a plein de points, on n'arrive pas a distinguer les amis de Keepy des
## vehicules". That is a READABILITY failure, not a correctness one -- CH46
## measured 69 green assertions on a map nobody could read, because it
## never gated the one thing that matters: that the four KINDS look
## different from each other.
##
## THE DEFECT, NAMED. CH46 gave three of its four kinds the SAME 14 px
## icon: player a disc r 4.2, vehicle a disc r 3.9, npc THE SAME disc
## r 3.9, place a diamond r 4.2. Vehicle and NPC were byte-identical
## shapes at byte-identical sizes; only the tint told them apart. And tint
## is the one channel this repo has documented as unusable for four-way
## separation (CLAUDE.md: the WCAG scores NOTHING inside a luminance band,
## and no probe here measures hue).
##
## LEVER A -- THREE RANKS OF SALIENCE. Every kind now has its own SHAPE and
## its own SIZE, ordered by how much of the player's attention it deserves:
##
##   rank 1  player   large disc      "where am I"
##   rank 1  vehicle  large diamond   "what can I drive"
##   rank 2  npc      triangle        "who is about"
##   rank 3  place    small dot       map DECOR, not a claim on the eye
##
## Nothing was removed -- all 37 markers are still drawn (Mathieu's own
## decision 1). What changed is that the eye stops processing them at one
## rank. The tints follow the same order in LUMINANCE (rank 1 lightest,
## rank 3 darkest) and are asserted to, but the tint is a SECOND cue on top
## of shape and size, never the carrier.
##
## LEVER B -- CLUSTERS. The measured problem was never the total ink: 37
## markers cover 16 % of a 155 x 280 plan. It is LOCAL agglomeration.
## MinimapDensityRecon measured, at spawn: SEVEN npcs on ONE pixel (the
## birds, boar, cat, fawn and beaver all sit on the world origin, under
## Keepy's own marker), FOUR karts inside 2.80 px on the starting grid, and
## THREE portals inside 6.78 px. So same-kind markers closer than
## `merge_px(kind)` are drawn as ONE marker, at the position of a real
## member of the group, with a punched-out centre that says "several".
##
## `merge_px` is MEASURED, not chosen: it is twice the icon's own drawn
## reach, read back off the baked atlas (`_measure_reach`), so it is
## exactly "these two icons touch". A literal here would drift the day a
## radius changes and nothing would say so.
##
## KEEPY NEVER MERGES WITH ANYTHING -- decision, and it is enforced by
## `merge_px(PLAYER) == 0.0` rather than by a special case at the call
## site, so there is one place to read it.
##
## =====================================================================
## MOUSE_FILTER_IGNORE IS NOT A DETAIL
##
## `Control`'s default is STOP, and both `HubTapInput._unhandled_input`
## and `KartTouchInput._unhandled_input` run AFTER the GUI pick. A minimap
## left at the default would swallow the tap-to-move under it on foot and
## the throttle/reverse anchor in a vehicle -- silently, with no error.
## It is set in `_ready()` AND in the scene file, and MinimapProbe proves
## it by pushing real events through the widget's rect.

## The plan's height in canvas pixels. The width follows from the world
## frame's own aspect, so the map is never stretched.
##
## ⚠️ CH48 DERIVED THIS, IT IS NOT A TASTE. The threshold is CH46's own
## published number for the shipped map -- "37 markers cover 16 % of a
## 155 x 280 plan" -- and the sweep (MinimapThumbBake PHASE 3f, the real
## marker positions at spawn, the shipped leader clustering re-run at each
## candidate) asks the smallest plan whose glyph ink is back under it with
## 32 px thumbnails on it:
##
##   plan 155 x 280 : 27 glyphs, ink 28.2 %      plan 189 x 340 : 19.1 %
##   plan 166 x 300 : 24.5 %                     plan 200 x 360 : 17.0 %
##   plan 177 x 320 : 21.6 %                     plan 211 x 380 : 15.3 %  <--
##
## 380 is the first rung at or under 16 %, and the lot ships the first
## rung: Mathieu asked for "un peu plus grande seulement". It is 1.36x
## CH47 linearly, 19.5 % of the canvas width where CH47 was 14.4 %.
const MAP_PX_H: int = 380

## ⚠️ CH48 -- BOTTOM RIGHT, and the margins are the same two numbers. The
## corner moved on Mathieu's decision 4: the bottom LEFT is where his thumb
## rests, and a map under the thumb is a map he cannot see. CH44 axe 4
## measured the occupancy of both modes and the BOTTOM THIRD is free on
## both sides; the one thing that lives on the right is KartHud's boost
## gauge, and it is drawn VERTICALLY CENTRED (`y = vp.y * 0.5 - GAUGE_H *
## 0.5`, KartHud._draw_boost_gauge), not bottom-anchored as its own comment
## says. On a 1920 canvas it runs y 830..1090 and this widget's top edge is
## at 1390; MinimapProbe measures both rects and asserts they are disjoint,
## because "its comment says centred" is not a measurement.
const MARGIN_X: float = 24.0
const MARGIN_Y: float = 150.0

## One atlas cell, in pixels.
##
## ⚠️ CH48 DERIVED THIS TOO, and the first method it tried FAILED. The
## brief asked for the size by COVERAGE, the CH46/CH47 method: bake every
## thumbnail at a ladder of sizes and find where two of the same rank stop
## separating. Measured (MinimapThumbBake PHASE 3), the worst same-kind
## pair reads 0.551 at 16 px and 0.483 at 64 px -- the separation gets
## WORSE as the icon gets BIGGER, because at 16 px more of the box is edge.
## A criterion that improves as the picture shrinks cannot name a minimum
## size, and saying so is part of this lot rather than a gap in it.
##
## What does degrade monotonically is how much of the subject survives the
## downsample (PHASE 3b: downsample to S, blow back up, compare with the
## reference render). Its return per pixel of cell:
##
##   16->20 0.0118/px   24->28 0.0072   32->36 0.0056   44->48 0.0039
##   20->24 0.0098      28->32 0.0061   36->40 0.0047   48->56 0.0032
##
## 32 is the last rung still returning at least half of what the first
## pixel returned (0.0059). Buying to 64 px would add 0.085 of fidelity and
## cost a map 60 % wider.
const ICON_PX: int = 32

## How far the black outline runs past the white fill, in pixels. One
## number for every icon, so "hard dark edge" means the same thing at
## every rank -- and so a small rank-3 dot is not left with a rim as thick
## as its body.
const OUTLINE_PX: float = 1.4

## ---- CH48: the thumbnails, and the plate that carries the contrast ----
##
## The 22 pictures, baked once by scripts/dev/MinimapThumbBake.gd from the
## BUILT hub -- the entities the map already marks, photographed in place
## through their own materials at HubCamera.OFFSET's own distance (11.7034
## u, the only distance this camera ever has). Straight alpha, 32 px cells,
## MinimapMarkers.THUMBS order, one row of the sheet per id.
const THUMB_SHEET: Texture2D = preload("res://assets/textures/ui/minimap_thumbs.png")
const SHEET_COLS: int = 8

## ⚠️ REAL COLOURS CANNOT SIGN A 3.0:1 CONTRACT, AND THE SWEEP PROVES IT
## RATHER THAN THE OTHER WAY ROUND. The brief asked for the minimum
## desaturation of the painted bands that would let the thumbnails reach
## the 3.0:1 floor. Swept from w = 0.0 to w = 1.0 (MinimapThumbBake PHASE
## 3d), the WORST subject never gets above 2.6 % of its ink clearing 3.0:1
## against every band at once -- at ANY desaturation, including bands
## washed to pure white.
##
## That is not the wash failing. A contrast RATIO is one tone against one
## tone; a badger has white fur and a black mask, and whatever a band's
## luminance is, one of those two sits near it. 3.0:1 is a contract an
## ICON's flat fill can sign and a PHOTOGRAPH cannot.
##
## So the floor is carried by a DARK PLATE, which is one tone and can sign
## it. Measured: this plate is L = 0.0070 and its worst ratio against the
## eight painted band tones is 4.38:1 (against the sea bed, the darkest of
## them) -- clear of 3.0:1 everywhere with margin, on every band, in every
## weather the plan is baked for. What the thumbnail then has to clear is
## THE PLATE, a known fixed tone: measured per subject, between 47.2 %
## (the boar) and 100 % (the sled, the three birds) of its ink does.
const PLATE_TONE: Color = Color(0.07, 0.08, 0.09)
const PLATE_RIM: Color = Color(0.0, 0.0, 0.0)
const CLAMP_RIM: Color = Color(1.00, 0.96, 0.86)
const PLATE_R: float = 7.0

## ⚠️ THE RIM CARRIES THE KIND, BECAUSE THE FILL NO LONGER CAN. CH47 said
## the kind with a SHAPE and a TINT; a portrait has neither to spare -- its
## silhouette is the model's and its colours are the model's (decision 2).
## So CH47's rank tints move to the plate's rim, where they multiply
## nothing: rank 1 warm and light, rank 3 dark, the same luminance order
## CH47 derived and MinimapProbe still asserts.
##
## ⚠️ AND KEEPY'S RIM IS THICKER THAN EVERY OTHER, deliberately and by one
## number. Mathieu's first need, in his own words, is finding himself among
## the 37 -- "le marqueur de Keepy doit rester identifiable au premier coup
## d'oeil". CH47 gave him the largest disc; CH48 cannot, because every
## portrait is one 32 px plate. A rim 2.4 px wide against everyone else's
## 1.4 is the cue that survives that, and it is a COVERAGE difference the
## probe can gate rather than a hue nothing in this repo measures.
const RIM_PX: float = 2.4
const PLAYER_RIM_PX: float = 3.2
const CLAMP_RIM_PX: float = 3.2

## ⚠️ THE KIND'S RING IS A SEPARATE CELL, DRAWN OVER THE PORTRAIT, AND THE
## FIRST DESIGN BAKED IT IN AND WAS WRONG. Baking the kind's colour into
## each portrait means reading the groups at BAKE TIME -- and the bake runs
## on the first frame, while the badger, the sled, the stream boat and the
## sailboat all join their group after it. All four came out with the
## fallback BLACK rim, and MinimapProbe PHASE 4 read exactly that: "lights
## only 0 px of its tone", four glyphs, on a map that was otherwise right.
## A repaint-on-change was tried first and is the kind of fix that has to be
## re-earned every time the world's build order moves.
##
## The ring is now THREE cells of its own -- ordinary, player, clamped --
## baked WHITE and drawn over the portrait with the kind's tone as the
## modulate. The kind is then resolved where it is always correct: at draw
## time, from the group the glyph came out of. It costs one more quad per
## glyph, of the SAME texture, so the map is still one draw call.
const RING_NORMAL: int = 0
const RING_PLAYER: int = 1
const RING_CLAMP: int = 2
const RING_COUNT: int = 3

## ⚠️ AND A BLACK KEYLINE OUTSIDE ALL OF IT, WHICH IS NOT DECORATION.
## The first cut gave the plate ONE rim, in the kind's tone, and MinimapProbe
## PHASE 14 -- rebuilt after its own red pass R8 exposed it as a false green
## -- walked the plate's perimeter against the ground it touches and found
## 43 of 68 samples under 3.0:1, worst 1.16:1. The cause is arithmetic: the
## rank-1 tones are LIGHT by CH47's own construction (player L 0.8392,
## vehicle 0.6476) and the painted bands are light too, so a light rim on a
## light band is no boundary at all. CH46's rule was right the first time --
## the thing that survives any background is BLACK -- and CH48 keeps it by
## putting the kind's colour just INSIDE a black keyline instead of in place
## of it. 1.2 px buys the contract back and costs the picture nothing it was
## using.
const KEYLINE_PX: float = 1.6

## ⚠️ AND KEEPY'S GLYPH IS DRAWN BIGGER, because a thicker ring alone was
## not enough and the measurement said so. With the ring at 3.2 px against
## everyone else's 2.4, MinimapProbe counted 184 opaque pixels of Keepy's
## ring against 176 of a vehicle's -- a 4.5 % difference, which is not a cue
## anybody finds "au premier coup d'oeil". CH47 had the right instinct and
## CH48 lost it by giving every portrait one cell: rank 1 was the BIGGEST
## marker. The cell stays 32 px for everyone (one atlas, one sheet, one
## bake); the player's is DRAWN into a larger rect, which is a scale at the
## draw call and costs nothing but a slightly softer picture.
##
## Everything downstream reads it through node_reach(), so the clustering
## bound, the clamp inset and every probe assertion move with it rather
## than needing to know about it.
const PLAYER_SCALE: float = 1.28

## ⚠️ AND THE WASH IS NOT THE CONTRAST LEVER -- IT IS THE CHROMA ONE.
## Desaturating at constant lightness is contrast-NEUTRAL, which is
## arithmetic and not opinion: WCAG scores relative luminance, and pulling
## GRASS_A all the way to its own grey moves it from L 0.4717 to L 0.4491.
## Mathieu's report ("les aplats sont vifs et saturés, ils dominent les
## marqueurs") is about CHROMA, and chroma is what a wash toward white
## actually removes -- lerp(c, white, w) leaves a band's chroma at exactly
## (1 - w) of its own.
##
## The minimum is therefore the wash that stops the LOUDEST band
## out-shouting the markers themselves. Measured: the loudest painted band
## is AUTUMN at chroma 0.5200, the 22 thumbnails average 0.3442, so
## w >= 1 - 0.3442/0.5200 = 0.3382. The ceiling is the point where two
## bands the plan separates BY TONE would stop being separable: the
## tightest such pair is MOOR/SHALLOW at 0.2315 and the plan's own 8 %
## alpha bleed is the resolution limit, so w <= 1 - 0.08/0.2315 = 0.6545.
## The window [0.3382, 0.6545] is non-empty and this ships its FLOOR.
##
## ⚠️ GRASS/LAWN (0.0640 apart) WAS ALREADY UNDER THAT BLEED BEFORE THIS
## LOT, at w = 0. Those two bands were never told apart by tone; the hedge
## line _bake_zone_edges draws at CIRCUIT_EDGE_Z is what separates them,
## and it still does. The wash does not create that, and MinimapProbe
## gates the line rather than the tone there.
const WASH: float = 0.34

## The three states an icon can be in. They are VARIANTS of a kind, never
## kinds of their own: a clamped vehicle is still orange, a merged place is
## still a small violet dot. Only the geometry changes.
const V_SIMPLE: int = 0
const V_MERGED: int = 1
const V_CLAMPED: int = 2
const VARIANT_COUNT: int = 3

## Kind -> column in the atlas strip. The cell is `kind * VARIANT_COUNT +
## variant`, so the strip reads player/vehicle/npc/place, three cells each.
const K_PLAYER: int = 0
const K_VEHICLE: int = 1
const K_NPC: int = 2
const K_PLACE: int = 3
const KIND_COUNT: int = 4
const ICON_COUNT: int = KIND_COUNT * VARIANT_COUNT

## Ground alpha inside the walkable world, and the tone everything outside
## it is washed with. The shape of the world IS the map's main information:
## a plan that painted grass everywhere would say the circuit is as wide as
## the plateau.
const GROUND_ALPHA: float = 0.92
const OUT_TONE: Color = Color(0.05, 0.06, 0.08, 0.52)
const EDGE_TONE: Color = Color(0.10, 0.13, 0.10, 0.80)
const TRACK_TONE: Color = Color(0.99, 0.97, 0.90, 0.95)
const BORDER_TONE: Color = Color(0.09, 0.11, 0.09, 0.95)

## Marker tints. Multiplied into a white fill, so these ARE the fill
## colours; the black outline baked beside them is untouched by any of
## them (see the atlas note above).
## ⚠️ NOT CREAM, AND THE PROBE IS WHY. A cream player marker (1.00, 0.99,
## 0.90) renders within 0.03 of the circuit's own line (0.97, 0.96, 0.87
## once the plan's alpha is applied) -- so the player standing on the
## karting circuit would be a pale dot on a pale line, and MinimapProbe's
## blind sweep read two plan pixels as "a player" during a red pass. A
## warm yellow is 0.71 away in blue from that line and clear of every
## painted band tone as well.
##
## ⚠️ CH47 ORDERS THEM BY LUMINANCE, AND THE ORDER IS THE RANK. Rank 1 is
## the lightest, rank 3 the darkest, so a place reads as map decor even
## before its shape is resolved. CH46's four tints did NOT do this -- its
## npc blue (0.577) was LIGHTER than its vehicle orange (0.535), so the
## animal shouted louder than the kart. MinimapProbe asserts the ordering
## on the rendered relative luminance, because a tint table that drifts out
## of rank order is exactly the kind of thing nothing else would notice.
## The player's tone is NOT re-opened: CH46 measured it against the
## circuit's own pale line and a warm yellow is what came out of that.
const PLAYER_TONE: Color = Color(1.00, 0.86, 0.16)
const VEHICLE_TONE: Color = Color(1.00, 0.58, 0.28)
const NPC_TONE: Color = Color(0.30, 0.52, 0.90)
const PLACE_TONE: Color = Color(0.46, 0.31, 0.62)

## Painted-zone bands, read off CozyPalette in the SAME ORDER the ground
## shader mixes them (cozy_ground.gdshader fragment(): grass, then autumn,
## then moor, then circuit lawn, then the cove's sand and sea). The order
## is the fact here, not the individual thresholds: reversing it would put
## heather over the circuit.
const _PAINTED_BASE: Color = CozyPalette.GRASS_A

## Back to front: places under animals under vehicles under the player, so
## the one marker a player is actually looking for is never the hidden one.
##
## ⚠️ PUBLISHED, because it is not only a drawing detail: whether a marker
## can be COVERED depends on it, and MinimapProbe has to know which markers
## it may legitimately not find. Written twice, the probe and the widget
## disagreed on the first run -- three balloon docks read back in the
## VEHICLE tone (a balloon parks ON its dock 0, at the same coordinates)
## and the probe called that a miss instead of an occlusion. One list, read
## by both.
const DRAW_ORDER: Array[StringName] = [
	MinimapMarkers.PLACE, MinimapMarkers.NPC, MinimapMarkers.VEHICLE, MinimapMarkers.PLAYER]

## The fill colour of a kind's marker, its atlas column, and its rank.
## Static so a probe asks for them rather than restating them -- CH46 paid
## for a probe that spelled the draw order out a second time and then
## disagreed with the widget about what was occluded.
static func tone_of(kind: StringName) -> Color:
	if kind == MinimapMarkers.PLAYER:
		return PLAYER_TONE
	if kind == MinimapMarkers.VEHICLE:
		return VEHICLE_TONE
	if kind == MinimapMarkers.NPC:
		return NPC_TONE
	return PLACE_TONE

static func column_of(kind: StringName) -> int:
	if kind == MinimapMarkers.PLAYER:
		return K_PLAYER
	if kind == MinimapMarkers.VEHICLE:
		return K_VEHICLE
	if kind == MinimapMarkers.NPC:
		return K_NPC
	return K_PLACE

## The salience rank a kind is drawn at: 1 = the player and what he can
## drive, 2 = who is about, 3 = map decor. Published because the tone
## ordering and the sizes both follow it, and a probe gates that they do.
static func rank_of(kind: StringName) -> int:
	if kind == MinimapMarkers.PLAYER or kind == MinimapMarkers.VEHICLE:
		return 1
	if kind == MinimapMarkers.NPC:
		return 2
	return 3

## The atlas cell for a KIND's abstract icon. Cells 0..11 are the four
## CH47 shapes x three variants and are the fallback for anything marked
## without a portrait -- which is every one of the fifteen places, and
## anything a later lot adds.
static func cell_of(kind: StringName, variant: int) -> int:
	return column_of(kind) * VARIANT_COUNT + variant

## The atlas cell for one of the 22 portraits. Cells 12.. are the
## thumbnails, in MinimapMarkers.THUMBS order, three variants each. The
## ORDER IS NOT RESTATED HERE: it is read out of MinimapMarkers, the one
## place it exists, which the baker reads too.
static func thumb_cell_of(thumb: StringName, variant: int) -> int:
	var row: int = MinimapMarkers.thumb_row(thumb)
	if row < 0:
		return -1
	return ICON_COUNT + RING_COUNT + row * VARIANT_COUNT + variant

## Which ring a glyph wears: the player's is thicker (Mathieu's first need),
## a clamped one is cream (it is saying something else entirely).
static func ring_cell_of(kind: StringName, variant: int) -> int:
	if variant == V_CLAMPED:
		return ICON_COUNT + RING_CLAMP
	return ICON_COUNT + (RING_PLAYER if kind == MinimapMarkers.PLAYER else RING_NORMAL)

## Every cell the atlas carries: the twelve abstract ones, then three per
## portrait.
static func atlas_cells() -> int:
	return ICON_COUNT + RING_COUNT + MinimapMarkers.THUMBS.size() * VARIANT_COUNT

## ---- the shapes, in one table --------------------------------------
##
## `_R_IN` is the WHITE FILL radius in the shape's own metric (a Euclidean
## radius for a disc, an L1 radius for a diamond, an inradius for the
## triangle, an L-infinity half-extent for the clamped square). The black
## outline always runs OUTLINE_PX further, and the drawn REACH that follows
## from all that is never written down here: it is MEASURED off the baked
## pixels, because that is the number the merge threshold is built on.
##
## The clamped square's half-extent is the kind's own measured reach, so a
## clamped marker is exactly "this kind's icon, put in a box" -- strictly
## larger than the icon it replaces, at every rank, which is what makes the
## coverage test able to tell them apart for a disc as well as for a
## diamond (a circumscribed square is only 27 % larger in area than its
## disc; a square built on the reach is 62 % larger).
const SHAPE_DISC: int = 0
const SHAPE_DIAMOND: int = 1
const SHAPE_TRIANGLE: int = 2
const SHAPE_SQUARE: int = 3

## kind column -> [shape, simple fill radius, merged fill radius, merged
## punch radius]. The merged glyph is ONE SIZE UP with its centre punched
## out: bigger, because a cluster is MORE and not less, and hollow, because
## that is the cue that says "several" without a digit nobody could read at
## 25 px. The player's row is never used for a merged cell -- Keepy does
## not cluster -- but it is written out so the table has no hole in it.
const SHAPES: Array[int] = [SHAPE_DISC, SHAPE_DIAMOND, SHAPE_TRIANGLE, SHAPE_DISC]
##
## ⚠️ THE RANK-3 RADIUS IS 2.7 AND NOT 2.3, AND THE PROBE IS WHY. At 2.3 the
## place dot's fully-opaque core is about nine pixels before the widget's
## own sub-pixel placement filters it, and MinimapProbe read FOUR pixels of
## the kind's tone where it wants six. Small is the point of rank 3; four
## device pixels of tone is smaller than legible, and the failing assertion
## was right about the art rather than wrong about itself.
const R_SIMPLE: Array[float] = [7.0, 7.6, 3.0, 2.7]
const R_MERGED: Array[float] = [7.0, 9.6, 4.4, 4.7]
const R_PUNCH: Array[float] = [0.0, 2.2, 2.0, 1.7]

## The drawn reach of every atlas cell, in pixels, MEASURED off the baked
## image (see _measure_reach). Never a literal: `merge_px()` is built on
## it, and a radius edited above with a threshold left behind is exactly
## the silent drift this repo keeps paying for.
var _reach: PackedFloat32Array = PackedFloat32Array()

var _atlas: ImageTexture = null
var _frame: Rect2 = Rect2()
var _bg_size: Vector2i = Vector2i.ZERO
var _atlas_size: Vector2i = Vector2i.ZERO
var _route_baked: bool = false
var _route_retried: bool = false
var _scolded: Dictionary = {}

func _ready() -> void:
	# BOTH of these, and neither is redundant: the scene file carries it so
	# an author reading HubWorld.tscn sees it, and this line carries it so a
	# minimap built in code (every probe does) is never at the STOP default.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = HubRegion.walkable_bounds()
	var w: int = maxi(1, roundi(float(MAP_PX_H) * _frame.size.x / _frame.size.y))
	_bg_size = Vector2i(w, MAP_PX_H)
	# CH48: the icons are a GRID under the plan, not a strip. 78 cells of
	# 32 px in one row would be 2496 px wide for a 211 px plan; eight columns
	# make it 256 x 320, and the atlas stays ONE texture -- which is the
	# whole reason CH46's map costs one draw call and this one still does.
	var icon_rows: int = int(ceil(float(atlas_cells()) / float(SHEET_COLS)))
	_atlas_size = Vector2i(maxi(w, ICON_PX * SHEET_COLS), MAP_PX_H + icon_rows * ICON_PX)
	# ⚠️ ANCHORS AND OFFSETS WRITTEN OUT, NEVER set_anchors_preset() + position.
	# CLAUDE.md documents the trap and this repo has already paid it once (V7,
	# the kart's clock panel cut off on device): after a preset, `position` is
	# an OFFSET FROM THE ANCHOR, so a widget anchored bottom-left and given a
	# positive y lands off the bottom of the screen. Four offsets against two
	# anchors say exactly one thing.
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -(MARGIN_X + float(w))
	offset_right = -MARGIN_X
	offset_top = -(MARGIN_Y + float(MAP_PX_H))
	offset_bottom = -MARGIN_Y

func _process(_delta: float) -> void:
	# Baked on the first frame rather than in _ready(): the karting circuit
	# is built by KartTrack._ready(), and HubWorld's own _ready() cascade is
	# still running when this node's _ready() fires. Re-baked once if the
	# route turns up later, so an ordering change cannot silently cost the
	# circuit -- and MinimapProbe gates the drawn PIXELS of that line, not
	# the fact that this ran.
	if _atlas == null:
		_bake()
	elif not _route_baked and not _route_retried \
			and not get_tree().get_nodes_in_group(MinimapMarkers.ROUTE).is_empty():
		# ⚠️ EXACTLY ONE RETRY, and it is gated on the group being non-empty
		# rather than on `not _route_baked` alone. A bake is 43 400
		# HubRegion.contains() calls: a hub with no circuit (every probe
		# that builds a bare world) would otherwise pay that EVERY FRAME
		# forever, and a route member that turns out to publish nothing
		# drawable would do the same. `_route_retried` closes both.
		_route_retried = true
		_bake()
	queue_redraw()

## ---- the frame, and what falls outside it --------------------------

## The world frame the plan covers, in world units (x, z). Published so a
## probe reads the same rectangle the drawing does instead of restating it.
func frame() -> Rect2:
	return _frame

## Where a world point lands inside the widget, in local pixels, and
## whether it had to be pulled in. NORTH (+z) IS UP: v runs from the
## frame's +z edge down to its -z edge.
##
## The clamp is deliberately to the widget's inner edge minus half an icon,
## so a clamped marker is fully drawn instead of half-cut -- an entity that
## is off the map must still be READABLE, or "clamped" and "gone" look the
## same.
## ⚠️ CH47: THE INSET IS THE ICON'S OWN REACH, NOT HALF A CELL. CH46 pulled
## every marker in by ICON_PX / 2 because its cell WAS its ink. A 25 px cell
## whose place-dot inks 7 px of it would push that dot 12 px inland -- a
## marker drawn 11 world units from where the thing is. Each caller passes
## the reach of the glyph it is about to draw, so every icon is drawn whole
## and none is drawn further in than it has to be.
func project(world: Vector3, inset: float = 0.0) -> Dictionary:
	var u: float = (world.x - _frame.position.x) / _frame.size.x
	var v: float = (_frame.position.y + _frame.size.y - world.z) / _frame.size.y
	var outside: bool = u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0
	var px: float = clampf(u * size.x, inset, maxf(inset, size.x - inset))
	var py: float = clampf(v * size.y, inset, maxf(inset, size.y - inset))
	return {"at": Vector2(px, py), "clamped": outside}

## ---- the clusters ----------------------------------------------------

## The drawn reach of one glyph, in pixels, as measured off the atlas.
## Returns 0 before the first bake, which is the honest answer.
func reach(kind: StringName, variant: int) -> float:
	var cell: int = cell_of(kind, variant)
	if cell < 0 or cell >= _reach.size():
		return 0.0
	return _reach[cell]

## How close two same-kind markers have to be to become one, in widget
## pixels. ONE reach -- centre to centre -- and CH48 changed it from CH47's
## two, which is a design decision and not a tuning.
##
## ⚠️ CH47 MERGED WHEN TWO ICONS TOUCHED (2 x reach), AND THAT RULE EATS
## THIS LOT. At 8 px of ink "touching" is 16 px; at a 32 px plate it is
## 29 px, which on this plan is 19 WORLD UNITS. Measured on the delivered
## world at 2 x reach, the vehicles folded {HopBall, Balloon_0, the stream
## boat} into ONE glyph 26 px across -- three different vehicles, three
## different portraits, one picture shown. CH47 could afford that because
## its glyphs carried no identity beyond their kind; CH48's whole point is
## that they do, so a merge that hides two of three portraits destroys the
## thing the lot exists to deliver.
##
## ONE reach is the honest threshold, and it is the same criterion the map
## sizing used: two glyphs fold only when the later one would BURY the
## earlier one -- centre inside the other's ink, so the covered one is
## invisible anyway and a stacked plate tells the truth. Above it both are
## partly visible and folding them would hide what the map could show.
## Measured after the change: {Yacht, SailBoat} and {HopBall, Balloon_0,
## boat} stop folding; the four karts on the grid and the three birds on
## the world origin still do.
##
## ⚠️ KEEPY IS ZERO, AND THAT IS THE WHOLE RULE. The player never merges
## with anything; writing it as a threshold rather than as an `if` at the
## call site means there is one place to read it and one place to gate it.
func merge_px(kind: StringName) -> float:
	if kind == MinimapMarkers.PLAYER:
		return 0.0
	return kind_reach(kind)

## The cell a NODE is drawn with: its own portrait if it declared one,
## otherwise its kind's abstract shape. One place decides it, so the
## drawing, the clustering and the probe cannot disagree about what is on
## screen -- CH46 paid for exactly that disagreement when the draw order
## was written down twice.
func cell_for(node: Node, kind: StringName, variant: int) -> int:
	var thumb: StringName = MinimapMarkers.thumb_of(node)
	if thumb != &"":
		var cell: int = thumb_cell_of(thumb, variant)
		if cell >= 0:
			return cell
	return cell_of(kind, variant)

## The drawn reach of a NODE's own glyph, in pixels, off the baked atlas.
func node_reach(node: Node, kind: StringName, variant: int) -> float:
	var cell: int = cell_for(node, kind, variant)
	if cell < 0 or cell >= _reach.size():
		return 0.0
	return _reach[cell] * draw_scale(node, kind)

## How much bigger than its cell a glyph is drawn. One for everything but
## the player, whose marker is the one a player is looking for.
func draw_scale(node: Node, kind: StringName) -> float:
	if kind != MinimapMarkers.PLAYER or MinimapMarkers.thumb_of(node) == &"":
		return 1.0
	return PLAYER_SCALE

## The largest simple reach drawn anywhere in `kind`. CH47 could take the
## kind's one icon; CH48 cannot, because a kind can now mix portraits and
## shapes (nothing in the delivered world does, but a later lot marking one
## new vehicle without a portrait would). Taking the MAX keeps the
## clustering bound true for every member instead of only for most.
func kind_reach(kind: StringName) -> float:
	var r: float = reach(kind, V_SIMPLE)
	for node in members(kind):
		r = maxf(r, node_reach(node, kind, V_SIMPLE))
	return r

## What the map actually DRAWS for `kind`: one entry per glyph, after the
## same-kind markers that sit on top of each other have been folded into
## one. Published so MinimapProbe reads the very list the drawing walks --
## a probe that recomputed the clustering would be free to disagree with
## it, which is the CH46 draw-order defect all over again.
##
## The algorithm is LEADER clustering, not single-link, and the difference
## is load-bearing: single-link chains, so three markers each 15 px from
## the next would collapse into one glyph 30 px from a member it claims to
## stand for. Here every member is within `merge_px` of the LEADER, the
## glyph is drawn ON the leader -- a real member's own position, never a
## centroid that may sit on nothing -- and the bound is therefore exact and
## assertable.
##
## Clamped and in-frame markers never merge with each other: they are
## saying different things, and one of them is "I am not on this map".
func clusters(kind: StringName) -> Array[Dictionary]:
	var pts: Array[Dictionary] = []
	for node in members(kind):
		var flag: bool = bool(project(node.global_position)["clamped"])
		var variant: int = V_CLAMPED if flag else V_SIMPLE
		pts.append({
			"at": (project(node.global_position, node_reach(node, kind, variant))["at"] as Vector2),
			"clamped": flag, "node": node})
	# A STABLE order, so the leader of a group does not depend on the order
	# get_nodes_in_group happened to return: west to east, then north to
	# south, then by instance id for an exact tie.
	pts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Vector2 = a["at"]
		var pb: Vector2 = b["at"]
		if not is_equal_approx(pa.x, pb.x):
			return pa.x < pb.x
		if not is_equal_approx(pa.y, pb.y):
			return pa.y < pb.y
		return (a["node"] as Node3D).get_instance_id() < (b["node"] as Node3D).get_instance_id())
	var threshold: float = merge_px(kind)
	var taken: Array[bool] = []
	for _i in pts.size():
		taken.append(false)
	var out: Array[Dictionary] = []
	for i in pts.size():
		if taken[i]:
			continue
		taken[i] = true
		var group: Array[Node3D] = [pts[i]["node"] as Node3D]
		if threshold > 0.0:
			for j in range(i + 1, pts.size()):
				if taken[j] or bool(pts[j]["clamped"]) != bool(pts[i]["clamped"]):
					continue
				if (pts[j]["at"] as Vector2).distance_to(pts[i]["at"] as Vector2) > threshold:
					continue
				taken[j] = true
				group.append(pts[j]["node"] as Node3D)
		out.append({"at": pts[i]["at"], "clamped": pts[i]["clamped"],
			"count": group.size(), "members": group})
	return out

## Which cell a cluster is drawn with. CLAMPED WINS OVER MERGED when both
## apply -- there is no fourth variant, and "this is off the map" is the
## more urgent of the two things to say. Stated here rather than inline so
## the probe can read the same rule.
static func variant_of(count: int, clamped: bool) -> int:
	if clamped:
		return V_CLAMPED
	return V_MERGED if count > 1 else V_SIMPLE

## ---- what the map draws --------------------------------------------

func _draw() -> void:
	if _atlas == null:
		return
	draw_texture_rect_region(_atlas, Rect2(Vector2.ZERO, size),
		Rect2(0.0, 0.0, float(_bg_size.x), float(_bg_size.y)), Color(1.0, 1.0, 1.0, 1.0))
	for kind in DRAW_ORDER:
		_draw_kind(kind)

## ⚠️ A PORTRAIT IS DRAWN AT modulate WHITE, AND THAT IS THE POINT.
## `modulate` MULTIPLIES (CH46's own doctrine, and the reason a black
## outline survives any tint): tinting a portrait would multiply the
## model's real colours by the kind's colour and the badger would come out
## blue. Mathieu's decision 2 is "couleurs REELLES du modele", so a
## portrait passes through untouched and only the abstract shapes -- the
## fifteen places, and anything a later lot marks without a portrait --
## still carry a kind tint.
func _draw_kind(group: StringName) -> void:
	var tone: Color = tone_of(group)
	for shot in clusters(group):
		var at: Vector2 = shot["at"]
		var lead: Node = shot["members"][0]
		var cell: int = cell_for(lead, group, variant_of(int(shot["count"]), bool(shot["clamped"])))
		var variant: int = variant_of(int(shot["count"]), bool(shot["clamped"]))
		var portrait: bool = cell >= ICON_COUNT + RING_COUNT
		# ⚠️ SNAPPED TO WHOLE PIXELS, AND CH47 ALREADY PAID FOR THIS ONCE.
		# Its own note: at radius 2.3 "le coeur pleinement opaque du point
		# fait neuf pixels AVANT le placement sous-pixel du widget", and the
		# probe read four. CH48 met it again from the other side -- the
		# kind's 2 px ring peaked at 0.835 of its tone instead of 1.000 on
		# glyphs whose cluster position happened to be fractional, so
		# MinimapProbe's "this glyph carries its kind's tone" read ZERO on
		# four of them while the ring was plainly there on the capture.
		#
		# A whole-pixel origin puts every 1-2 px feature -- this ring AND the
		# black keyline that signs the contrast contract -- back at full
		# strength. The cost is at most half a pixel of position, which on
		# this plan is 0.32 world units.
		var side: float = float(ICON_PX) * draw_scale(lead, group)
		var box := Rect2((at - Vector2(side, side) * 0.5).round(), Vector2(side, side))
		draw_texture_rect_region(_atlas, box, _icon_region(cell),
			Color(1.0, 1.0, 1.0, 1.0) if portrait else tone)
		if portrait:
			# The kind's ring, over the portrait, in the kind's own tone --
			# resolved HERE, from the group this glyph came out of, which is
			# the one place that cannot be stale.
			draw_texture_rect_region(_atlas, box,
				_icon_region(ring_cell_of(group, variant)),
				CLAMP_RIM if variant == V_CLAMPED else tone)

## Every live Node3D of `group`. A member that is not a Node3D has no world
## position and cannot be drawn -- said out loud ONCE per group rather than
## dropped, because a marker that silently never appears is the failure
## this whole design exists to avoid.
func members(group: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(group):
		var spatial := node as Node3D
		if spatial == null:
			if not _scolded.has(group):
				_scolded[group] = true
				push_error("HubMinimap: group '%s' holds a %s, which has no world position." % [group, node.get_class()])
			continue
		if spatial.is_queued_for_deletion():
			continue
		out.append(spatial)
	return out

## The baked atlas and where a cell sits in it. Published so a probe reads
## THE IMAGE THE WIDGET DRAWS FROM rather than re-deriving one -- CH46 paid
## for a probe that restated the draw order and then disagreed with the
## widget about what was occluded.
func atlas_image() -> Image:
	return null if _atlas == null else _atlas.get_image()

func icon_rect(cell: int) -> Rect2:
	return _icon_region(cell)

func _icon_region(cell: int) -> Rect2:
	return Rect2(float((cell % SHEET_COLS) * ICON_PX),
		float(_bg_size.y + (cell / SHEET_COLS) * ICON_PX),
		float(ICON_PX), float(ICON_PX))

## ---- the atlas ------------------------------------------------------

func _bake() -> void:
	var img := Image.create(_atlas_size.x, _atlas_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	_bake_ground(img)
	_bake_zone_edges(img)
	_route_baked = _bake_route(img)
	_bake_border(img)
	_bake_icons(img)
	_atlas = ImageTexture.create_from_image(img)

## The plan itself: the painted ground where the region admits a point, the
## wash everywhere else.
func _bake_ground(img: Image) -> void:
	for py in _bg_size.y:
		for px in _bg_size.x:
			var world: Vector3 = _world_at(px, py)
			if HubRegion.contains(world):
				var col: Color = painted_tone(world)
				col.a = GROUND_ALPHA
				img.set_pixel(px, py, col)
			else:
				img.set_pixel(px, py, OUT_TONE)

## The ground colour the SHADER would paint at this point, minus its noise:
## same bands, same order, same constants (CozyPalette). Static so a probe
## can ask it the same question the bake asks.
static func painted_tone(world: Vector3) -> Color:
	var col: Color = _PAINTED_BASE
	if world.z <= CozyPalette.AUTUMN_EDGE_Z:
		col = CozyPalette.AUTUMN_A
	if world.z <= CozyPalette.MOOR_EDGE_Z:
		col = CozyPalette.MOOR_A
	if world.z <= CozyPalette.CIRCUIT_EDGE_Z:
		col = CozyPalette.LAWN_A
	var rect: Vector4 = CozyPalette.COVE_RECT
	if world.x >= rect.x and world.x <= rect.z and world.z >= rect.y and world.z <= rect.w:
		col = CozyPalette.SAND_A
		var d: float = HubRegion.shore_distance(world)
		if d < 0.0:
			col = CozyPalette.SEA_SHALLOW_BED.lerp(CozyPalette.SEA_BED, clampf(-d / 9.0, 0.0, 1.0))
		elif d < 3.5:
			col = CozyPalette.SAND_A.lerp(CozyPalette.SAND_WET, 1.0 - d / 3.5)
	return washed(col)

## CH48: the band as the PLAN paints it -- the world's own tone pulled
## WASH of the way to white. One function, so the widget and the probe ask
## the same question and a band tone is never washed twice or not at all.
static func washed(col: Color) -> Color:
	return Color(lerpf(col.r, 1.0, WASH), lerpf(col.g, 1.0, WASH), lerpf(col.b, 1.0, WASH), col.a)

## The three painted hedges (and the cove's painted west edge) as lines, so
## a boundary reads as a boundary and not only as a change of tint -- two
## of the four bands are close enough in value that the tint alone is a
## guess. THE PAINTED z, per decision 4: CozyPalette, never HubRegion.
func _bake_zone_edges(img: Image) -> void:
	for edge_z in [CozyPalette.AUTUMN_EDGE_Z, CozyPalette.MOOR_EDGE_Z, CozyPalette.CIRCUIT_EDGE_Z]:
		var py: int = _pixel_z(float(edge_z))
		for px in _bg_size.x:
			_wash(img, px, py, EDGE_TONE)
	var rect: Vector4 = CozyPalette.COVE_RECT
	var px_edge: int = _pixel_x(rect.x)
	var z0: int = _pixel_z(rect.w)
	var z1: int = _pixel_z(rect.y)
	for py in range(mini(z0, z1), maxi(z0, z1) + 1):
		_wash(img, px_edge, py, EDGE_TONE)

## The karting circuit, from whatever joined MinimapMarkers.ROUTE. Returns
## false when nothing has, which is what makes _process bake again.
func _bake_route(img: Image) -> bool:
	var drew: bool = false
	for node in get_tree().get_nodes_in_group(MinimapMarkers.ROUTE):
		if not node.has_method("ideal_line"):
			continue
		var line: Array = node.call("ideal_line")
		if line.size() < 2:
			continue
		var spatial := node as Node3D
		var basis_xform: Transform3D = spatial.global_transform if spatial != null else Transform3D.IDENTITY
		var prev: Vector2 = Vector2.ZERO
		for i in range(line.size() + 1):
			var world: Vector3 = basis_xform * (line[i % line.size()] as Vector3)
			var here := Vector2(float(_pixel_x(world.x)), float(_pixel_z(world.z)))
			if i > 0:
				_segment(img, prev, here, TRACK_TONE)
			prev = here
		drew = true
	return drew

func _bake_border(img: Image) -> void:
	for px in _bg_size.x:
		img.set_pixel(px, 0, BORDER_TONE)
		img.set_pixel(px, _bg_size.y - 1, BORDER_TONE)
	for py in _bg_size.y:
		img.set_pixel(0, py, BORDER_TONE)
		img.set_pixel(_bg_size.x - 1, py, BORDER_TONE)

## The atlas cells. TWELVE abstract ones first -- the CH47 shapes, still
## the fallback for anything marked without a portrait, and still what all
## fifteen places draw -- then THREE per portrait.
##
## The pass runs in order because two cells are DERIVED from measurements
## of earlier ones: the clamped abstract square's half-extent is the simple
## cell's own measured reach.
func _bake_icons(img: Image) -> void:
	_reach.resize(atlas_cells())
	for k in KIND_COUNT:
		_paint_icon(img, k * VARIANT_COUNT + V_SIMPLE, SHAPES[k], R_SIMPLE[k], 0.0)
		_paint_icon(img, k * VARIANT_COUNT + V_MERGED, SHAPES[k], R_MERGED[k], R_PUNCH[k])
	for k in KIND_COUNT:
		_paint_icon(img, k * VARIANT_COUNT + V_CLAMPED, SHAPE_SQUARE,
			_reach[k * VARIANT_COUNT + V_SIMPLE] - OUTLINE_PX, 0.0)
	_paint_ring(img, ICON_COUNT + RING_NORMAL, RIM_PX)
	_paint_ring(img, ICON_COUNT + RING_PLAYER, PLAYER_RIM_PX)
	_paint_ring(img, ICON_COUNT + RING_CLAMP, CLAMP_RIM_PX)
	var sheet: Image = THUMB_SHEET.get_image()
	if sheet == null:
		push_error("HubMinimap: the thumbnail sheet did not load; the map falls back to shapes.")
		return
	if sheet.is_compressed():
		# Said out loud rather than worked around: a VRAM-compressed sheet
		# would give back approximate colours and a soft alpha, and every
		# "these are the model's real colours" claim below would be false.
		sheet.decompress()
	for row in MinimapMarkers.THUMBS.size():
		for v in VARIANT_COUNT:
			_paint_thumb(img, sheet, thumb_cell_of(MinimapMarkers.THUMBS[row], v), row, v)

## ⚠️ WHAT A PORTRAIT CELL IS MADE OF, AND WHY IT IS A PLATE.
##
## A dark rounded plate, a rim, and the baked picture over it. The plate is
## the part that signs the 3.0:1 contract against the ground (measured:
## 4.38:1 at worst, against the sea bed); the picture is the part that says
## which entity this is. See PLATE_TONE for the sweep that shows a
## photograph cannot sign that contract itself at any desaturation.
##
## The three variants say three things and each is a GEOMETRY change, never
## a tint -- the CH47 rule, kept, because a portrait is already drawn at
## `modulate` white and has no tint left to spend:
##
##   V_SIMPLE   one plate
##   V_MERGED   a second plate behind it, down-right, dimmed: a stack
##   V_CLAMPED  a CREAM rim instead of a black one: "I am off this map"
## A ring cell: WHITE where the kind's colour goes, transparent everywhere
## else, so it can be laid over any portrait with the kind's tone as the
## modulate. Its outer edge is the keyline's inner edge, so a ring never
## covers the black edge that signs the contrast contract.
func _paint_ring(img: Image, cell: int, width: float) -> void:
	var c: float = float(ICON_PX) * 0.5 - 0.5
	var half: float = float(ICON_PX) * 0.5 - 1.0
	var reach_px: float = 0.0
	for py in ICON_PX:
		for px in ICON_PX:
			var d: float = _rsq(float(px) - c, float(py) - c, half, PLATE_R)
			var outer: float = clampf(0.5 - (d + KEYLINE_PX), 0.0, 1.0)
			var inner: float = clampf(0.5 - (d + KEYLINE_PX + width), 0.0, 1.0)
			var a: float = clampf(outer - inner, 0.0, 1.0)
			if a > 0.5:
				reach_px = maxf(reach_px, maxf(absf(float(px) - c), absf(float(py) - c)))
			var at: Vector2i = _cell_origin(cell) + Vector2i(px, py)
			img.set_pixel(at.x, at.y, Color(1.0, 1.0, 1.0, a))
	_reach[cell] = reach_px

func _paint_thumb(img: Image, sheet: Image, cell: int, row: int, variant: int) -> void:
	var c: float = float(ICON_PX) * 0.5 - 0.5
	var half: float = float(ICON_PX) * 0.5 - 1.0
	# The plate carries a black keyline and nothing else that is per-kind:
	# the ring is a cell of its own, laid over this one at draw time.
	var rim_px: float = 0.0
	var rim_col: Color = PLATE_RIM
	var front: Vector2 = Vector2(-1.0, -1.0) if variant == V_MERGED else Vector2.ZERO
	var back: Vector2 = Vector2(3.0, 3.0)
	var sx: int = (row % SHEET_COLS) * ICON_PX
	var sy: int = (row / SHEET_COLS) * ICON_PX
	var reach_px: float = 0.0
	for py in ICON_PX:
		for px in ICON_PX:
			var dx: float = float(px) - c
			var dy: float = float(py) - c
			var out_a: float = 0.0
			var col := Color(0.0, 0.0, 0.0)
			if variant == V_MERGED:
				var db: float = _rsq(dx - back.x, dy - back.y, half, PLATE_R)
				var rb: float = clampf(0.5 - db, 0.0, 1.0)
				var bb: float = clampf(0.5 - (db + KEYLINE_PX), 0.0, 1.0)
				out_a = rb
				col = PLATE_RIM.lerp(PLATE_TONE.darkened(0.35), bb)
			var d: float = _rsq(dx - front.x, dy - front.y, half, PLATE_R)
			var rimf: float = clampf(0.5 - d, 0.0, 1.0)
			# Three shells, outermost first: the BLACK keyline that signs the
			# contrast contract, the kind's tone inside it, then the plate.
			var body: float = clampf(0.5 - (d + KEYLINE_PX + rim_px), 0.0, 1.0)
			var plate: Color = PLATE_RIM.lerp(PLATE_TONE, body)
			# The picture, straight alpha off the sheet, clipped to the plate's
			# BODY -- inside both shells. Letting it run out to the keyline
			# instead was tried and measured: it covers the kind's own ring
			# wherever the subject is opaque, and PHASE 4 (which reads the
			# kind's tone under every glyph) dropped below its six-pixel
			# floor for vehicles and npcs. A cue a picture can cover is not
			# a cue.
			var t: Color = sheet.get_pixel(sx + px, sy + py)
			plate = plate.lerp(Color(t.r, t.g, t.b), minf(t.a, body))
			col = col.lerp(plate, rimf)
			out_a = maxf(out_a, rimf)
			if out_a > 0.5:
				reach_px = maxf(reach_px, maxf(absf(dx), absf(dy)))
			var at: Vector2i = _cell_origin(cell) + Vector2i(px, py)
			img.set_pixel(at.x, at.y, Color(col.r, col.g, col.b, out_a))
	_reach[cell] = reach_px

## Signed distance to a rounded square of half-extent `half` and corner
## radius `r`, negative inside. Written out because a plate drawn from four
## line segments and four arcs is four chances to be off by half a pixel.
static func _rsq(dx: float, dy: float, half: float, r: float) -> float:
	var qx: float = absf(dx) - (half - r)
	var qy: float = absf(dy) - (half - r)
	return Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - r

## One abstract cell. `punch` > 0 knocks the fill out of the middle,
## leaving the outline's black there -- the merged glyph's "several" cue.
## It only touches the FILL, never the alpha, so a merged marker has
## exactly the silhouette of an enlarged simple one.
##
## ⚠️ CH48 CHANGED WHAT `reach` MEANS, and the reason is the plate. CH47
## recorded the maximum RADIAL distance still inked, which for a disc is
## its radius. For a SQUARE plate that is the half-DIAGONAL: 22.6 px for a
## 32 px cell, so `merge_px` would say two plates touch while they are
## still six pixels apart. The number recorded is now the half-EXTENT
## (max |dx|, max |dy|), which is exactly "these two glyphs touch" for a
## square and is unchanged for a disc or a diamond on their axes. It is
## still MEASURED off the baked pixels and never written down.
func _paint_icon(img: Image, cell: int, shape: int, r_in: float, punch: float) -> void:
	var c: float = float(ICON_PX) * 0.5 - 0.5
	var reach_px: float = 0.0
	for py in ICON_PX:
		for px in ICON_PX:
			var dx: float = float(px) - c
			var dy: float = float(py) - c
			var radial: float = sqrt(dx * dx + dy * dy)
			var metric: float = radial
			match shape:
				SHAPE_DIAMOND:
					metric = absf(dx) + absf(dy)
				SHAPE_SQUARE:
					metric = maxf(absf(dx), absf(dy))
				SHAPE_TRIANGLE:
					# Up-pointing equilateral, written as the largest of its
					# three half-plane distances, with the INCENTRE at the
					# cell's centre. That is deliberate: the incentre of an
					# equilateral triangle IS its area centroid, so the glyph
					# is centred on the thing it marks even though its
					# bounding box is not symmetric about it.
					metric = maxf(dy, maxf(0.866025 * (-dx) - 0.5 * dy, 0.866025 * dx - 0.5 * dy))
				_:
					metric = radial
			var a_out: float = clampf(r_in + OUTLINE_PX + 0.5 - metric, 0.0, 1.0)
			var a_in: float = clampf(r_in + 0.5 - metric, 0.0, 1.0)
			if punch > 0.0:
				a_in = minf(a_in, clampf(radial - punch + 0.5, 0.0, 1.0))
			if a_out > 0.5:
				reach_px = maxf(reach_px, maxf(absf(dx), absf(dy)))
			var at: Vector2i = _cell_origin(cell) + Vector2i(px, py)
			img.set_pixel(at.x, at.y, Color(a_in, a_in, a_in, a_out))
	_reach[cell] = reach_px

func _cell_origin(cell: int) -> Vector2i:
	return Vector2i((cell % SHEET_COLS) * ICON_PX, _bg_size.y + (cell / SHEET_COLS) * ICON_PX)

## ---- pixel <-> world -------------------------------------------------

func _world_at(px: int, py: int) -> Vector3:
	var x: float = _frame.position.x + (float(px) + 0.5) / float(_bg_size.x) * _frame.size.x
	var z: float = _frame.position.y + _frame.size.y - (float(py) + 0.5) / float(_bg_size.y) * _frame.size.y
	return Vector3(x, 0.0, z)

func _pixel_x(x: float) -> int:
	return int(floor((x - _frame.position.x) / _frame.size.x * float(_bg_size.x)))

func _pixel_z(z: float) -> int:
	return int(floor((_frame.position.y + _frame.size.y - z) / _frame.size.y * float(_bg_size.y)))

## Darken a plan pixel rather than replace it, so a hedge line drawn over
## the wash outside the world does not read as walkable ground.
func _wash(img: Image, px: int, py: int, tone: Color) -> void:
	if px < 0 or py < 0 or px >= _bg_size.x or py >= _bg_size.y:
		return
	var under: Color = img.get_pixel(px, py)
	img.set_pixel(px, py, Color(
		lerpf(under.r, tone.r, tone.a),
		lerpf(under.g, tone.g, tone.a),
		lerpf(under.b, tone.b, tone.a), under.a))

func _segment(img: Image, a: Vector2, b: Vector2, tone: Color) -> void:
	var steps: int = int(ceil(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	if steps <= 0:
		_wash(img, int(a.x), int(a.y), tone)
		return
	for i in range(steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		_wash(img, int(round(p.x)), int(round(p.y)), tone)
