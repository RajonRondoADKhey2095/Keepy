extends Node3D
class_name HubFunfair
## CH71 -- THE FUNFAIR: a roller coaster and a drop tower, on the east
## strip of the plateau, and the rides they carry.
##
## =====================================================================
## WHERE IT STANDS, AND WHY NO NEW GROUND WAS BOUGHT
##
## Mathieu's anchor is (35.2, 27.7) -- read off the debug overlay, not
## estimated. The CH71 recon (Ch71SiteRecon, run under xvfb, deleted
## before the commit) measured what is there: the point is INSIDE the
## region by 0.051 u (the skate lobe's rim, r 36 from (0, 35), passes at
## 35.949 from the site), the plateau's east edge on that row is
## x = 35.26, NO layout prop stands within 12 u, the zipline cable runs
## at x 25.2 -> 27.7 to the west, its P2 tower is 12.4 u away, and the
## forest wall's first trunks stand at x >= 36.6.
##
## The whole fair is therefore laid INSIDE the existing region, in the
## strip x in [28, 35] between the zipline and the plateau's edge:
##
##   * no HubRegion term is added, so the hub's worst crossing is
##     exactly what CH67 left it (21.817 s) and nothing is re-walked;
##   * no wall tree is cleared: the wall is sown OUTSIDE the region and
##     the region did not move. (A lobe east of x = 35 would have re-sown
##     the wall -- 13 near-wall trunks stand in x [36.6, 44.7] -- and the
##     brief forbids removing a tree without Mathieu's say.)
##   * the east rail's outer edge is at x = 34.9, 0.1 u inside the
##     square, and the valley of the drop passes 0.7 u from the anchor.
##
## The price is the price every prop in this hub pays: the ground cover
## under the low rails, the deck and the tower is kept clear by
## `footprints()`, which CozyScatter reads, and every rejected candidate
## skips its two RNG draws -- the carpet downstream is reshuffled
## (CLAUDE.md CH53, "irreducible"). FunfairProbe measures it at the spawn.
##
## =====================================================================
## THE CAMERA DECIDES THE HEIGHTS AND THE DIRECTION
##
## HubCamera never rises and never yaws (CLAUDE.md): it follows Keepy's
## GROUND point at a constant offset, so a rider is always at the
## aplomb and everything above FRAME_TOP_AT_APLOMB (7.968 u) is off the
## picture. Keepy's crown sits ~1.7 u above his seat; with the 0.4 u
## margin CLAUDE.md uses for the tree seats, the seat may not exceed
## 5.868 u. The coaster's crest rail is at 5.0 (seat 5.34), the gondola
## tops out at 5.1 (seat 5.22). FunfairProbe unprojects the crown every
## frame of both rides and requires it inside the frame.
##
## The camera shows only what lies at LOWER z than Keepy (it stands 8.9 u
## north of him). So the loop is a narrow oval along z, the STATION is on
## the west leg and the cart leaves it heading NORTH: the lift hill is
## climbed blind (the anticipation needs no view), the north turn at the
## crest reveals the whole east leg falling away to the south -- the drop,
## the camelback, the south turn and the tower beyond it -- in frame for
## the whole descent. Mirror of HubSkatepark's "ridden southward".
##
## =====================================================================
## THE RIDES ARE BOUNDED, AND THAT IS THEIR LICENCE TO DROP A TAP
##
## Both rides carry Keepy with KeepyHopper's carrier contract
## (mount_carrier / follow_carrier / leave_carrier -- the balloon's). A
## tap during a ride falls through to the ground path and is refused by
## ON_CARRIER, which CLAUDE.md licenses ONLY for a trip "borne par un
## tween qui se termine toujours a un point connu". Both rides are: the
## coaster's loop always ends at the station (its speed is floored at
## SPEED_FLOOR, so a held brake slows it and never stalls it), and the
## gondola always comes back to GONDOLA_REST_Y. Both doors WITHDRAW for
## the length of the ride (the boat pattern: accepts_tap answers -1), so
## the tap reaches the ground path and is dropped BY STATE, never
## swallowed by the thing being ridden.
##
## The coaster is "pilotable" in one axis: a HELD finger is the brake.
## Not a direction -- the rail owns that -- so the fixed camera stays
## (CLAUDE.md's criterion is "le joueur choisit la direction frame par
## frame", and he does not).
##
## =====================================================================
## WHAT IS SOLID (D5)
##
## Every collision piece is an axis-aligned BOX (FunfairMesh.solids ->
## BoxShape3D): the tower's base, mast and four legs, the station's two
## posts, and every rail support post. Convex by construction; no
## trimesh anywhere. On SkateBoardBody.LAYER_PARK, mask 0, so the board
## bumps into them and nothing scans for them. The rails themselves are
## NOT solid: they hang above the lawn, and the board passes under.

## ---- the loop --------------------------------------------------------
## Control points of the rail-top centre line, in RIDING ORDER, closed
## (the last joins the first). y is the rail-top height. Index 0 is the
## station stop, index 1 the lift foot; the crest is found by measurement
## off the baked curve, never by index.
const TRACK_POINTS: Array = [
	Vector3(29.5, 0.55, 20.0),   # 0  station stop (the cart rests here)
	Vector3(29.5, 0.55, 23.0),   # 1  lift foot
	Vector3(29.5, 1.60, 26.0),
	Vector3(29.5, 3.20, 29.5),
	Vector3(29.5, 4.60, 33.0),
	Vector3(30.0, 5.00, 35.6),   # 5  crest, north turn begins
	Vector3(32.0, 4.90, 37.0),   #    north tip
	Vector3(34.0, 4.70, 35.6),
	Vector3(34.5, 4.30, 33.5),   #    drop begins
	Vector3(34.5, 1.60, 30.0),
	Vector3(34.5, 0.55, 27.5),   # 10 valley (0.7 u from the anchor)
	Vector3(34.5, 2.40, 23.5),   #    camelback
	Vector3(34.5, 0.55, 19.5),
	Vector3(34.0, 0.55, 16.9),   #    south turn
	Vector3(32.0, 0.55, 15.8),   #    south tip
	Vector3(30.0, 0.55, 16.9),
	Vector3(29.5, 0.55, 18.0),   # 16 brake run
]
## Cardinal-spline tension for the handles: 0.5 is Catmull-Rom.
const TRACK_TENSION: float = 0.5
const TRACK_BAKE_INTERVAL: float = 0.1
const RAIL_GAUGE: float = 0.70
const RAIL_RADIUS: float = 0.06
const RAIL_SAMPLE: float = 0.5
const TIE_SPACING: float = 0.9
const TIE_THICK: float = 0.08
const TIE_WIDTH: float = 1.0
const POST_SPACING: float = 1.8
const POST_MIN_HEIGHT: float = 0.35
const POST_THICK: float = 0.16
const POST_BELOW_RAIL: float = 0.14

## ---- the cart and its run ------------------------------------------
const LIFT_SPEED: float = 2.2
const LIFT_ACCEL: float = 1.5
## 9.8, the physical one. NOT SkateBoardBody.GRAVITY (26.0): that is the
## board's own contract, tuned for a capsule on a quarterpipe. Energy
## conservation on a track is what makes the drop's speed READ as the
## hill's height, and the coaster answers to the height it was authored
## at. Shared with the tower's fall below.
const GRAVITY: float = 9.8
## Rolling loss, in u/s^2 of energy per unit travelled.
const ROLL_FRICTION: float = 0.35
## The player's brake: energy shed per unit while the finger is held.
const BRAKE_DECEL: float = 3.0
## The cart never goes slower than this while coasting, so a held brake
## cannot strand it on the camelback -- the ride stays BOUNDED.
const SPEED_FLOOR: float = 1.2
## The run-out into the station: speed falls to zero over these units.
const BRAKE_RUN_U: float = 3.0
const CART_SEAT: Vector3 = Vector3(0.0, 0.34, 0.0)
const CART_BODY: Vector3 = Vector3(0.80, 0.42, 1.10)
const CART_BODY_Y: float = 0.30
const WHEEL_SIZE: Vector3 = Vector3(0.12, 0.16, 0.16)

## ---- the station -----------------------------------------------------
## Where the rider stands to board, on the deck west of the cart. A stand
## point, not the cart: the cart is a moving thing.
const STATION_STAND: Vector3 = Vector3(28.5, 0.0, 20.0)
const DECK_CENTRE: Vector3 = Vector3(28.5, 0.0, 20.5)
const DECK_SIZE: Vector3 = Vector3(1.4, 0.006, 3.2)
## 3 mm over the lawn, under the blob shadow at LIFT_EPSILON 0.014 (the
## skatepark slab's reasoning, SkateparkMesh.SLAB_LIFT).
const DECK_LIFT: float = 0.003
const STATION_POST_HEIGHT: float = 2.2
const STATION_POST_THICK: float = 0.14
const STATION_ROOF: Vector3 = Vector3(1.9, 0.08, 2.8)
const COASTER_TAP_RADIUS: float = 2.0
const DECK_FOOTPRINT: float = 1.9
const LOW_RAIL_HEIGHT: float = 2.0
const LOW_RAIL_FOOTPRINT: float = 1.2
const POST_FOOTPRINT: float = 0.45

## ---- the drop tower --------------------------------------------------
## South of the loop's tip, INSIDE the square: the base slab reaches
## x = 34.3 and the published footprint (1.9, padded so a landing keeps
## KEEPY_CLEARANCE off the legs) reaches 34.9 -- both under 35, so
## nothing of it, drawn OR reserved, overhangs the edge (FunfairProbe
## B7; the first placement at x = 33.3 put the footprint 0.2 u past the
## edge and went red there). Its tightest layout neighbours, measured:
## a bush at (29.87, 7.14) r 0.63 with 0.89 u of gap, the spire landmark
## at (30.49, 12.87) r 1.461 with 1.68 u, the zipline's P1 stair (27.7,
## 9.2) r 1.932 further still. Re-gated by FunfairProbe PHASE B.
const TOWER_AT: Vector3 = Vector3(33.0, 0.0, 8.5)
const TOWER_STAND: Vector3 = Vector3(33.0, 0.0, 11.0)
const TOWER_TAP_RADIUS: float = 2.2
const TOWER_FOOTPRINT: float = 1.9
const TOWER_HALF_SPAN: float = 1.0
const TOWER_LEG_THICK: float = 0.16
const TOWER_MAST_THICK: float = 0.22
const TOWER_BASE: Vector3 = Vector3(2.6, 0.30, 2.6)
const TOWER_BRACE_THICK: float = 0.07
const TOWER_CAP: Vector3 = Vector3(2.4, 0.25, 2.4)
const GONDOLA_REST_Y: float = 0.45

## =====================================================================
## CH72 -- HOW HIGH, AND WHAT PAID FOR THE NUMBER
##
## CH71 topped the gondola at 5.10 because that is all a FIXED camera can
## show: `HubCamera.FRAME_TOP_AT_APLOMB` cuts the rider'"'"'s own column at
## 7.968 u, and a crown 1.7 u over the seat with CLAUDE.md'"'"'s 0.4 u margin
## caps the seat at 5.868. CLAUDE.md says in as many words that the
## answer to "je veux plus haut que ca" is "une camera qui monte,
## c'"'"'est-a-dire un autre lot". THIS is that lot: `HubCamera.set_fair_lift`
## raises the fixed pose WITH the gondola, and Ch72Recon R3 measured that
## the framing is then INVARIANT -- lift the camera and the rider by the
## same dy and the crown lands on screen pixel (270, 121) at dy = 0, 3, 6,
## 10 and 14, unchanged to four figures. The ceiling stops being a wall.
##
## So the height is decided by what it BUYS, and that was rendered, not
## argued (Ch72Recon R4, a camera at the gondola looking out, three
## headings, six heights). Two findings, one of which refutes a premise
## of the brief:
##
##   * NOTHING OCCLUDES THE VIEW, at any height. The sky/haze band is
##     0.0 % of the frame at 5.10 and 1.4 % at 20.0; no near trunk, no
##     ridge stands in the way. The brief'"'"'s "s'"'"'il y a des arbres/reliefs
##     qui bouchent la vue" is measured and answered NO -- the site does
##     not need moving, and it was not moved.
##   * HEIGHT BUYS REACH, and reach alone. The eye reaches ground at
##     24.0 u from y 5.10, 34.0 from 8, 44.5 from 11, 55.0 from 14,
##     65.5 from 17 and 76.0 from 20 -- about 3.5 u of reach per unit of
##     height. The count of layout props in frame, by contrast, is FLAT
##     (west 158 -> 160 over the whole sweep): what is in the picture is
##     decided by the heading, not by the altitude.
##
## The ceiling is therefore the HAZE, not the geometry. At
## `CozyPalette.HAZE_DENSITY` (0.022) a thing at 24 u keeps 59 % of
## itself, at 44.5 u 38 %, at 55 u 30 %, at 65.5 u 24 %, at 76 u 19 %.
## Past ~55 u the new ground a taller tower buys is more sky colour than
## ground. 14.0 is the last height whose reach still lands where a third
## of the picture survives -- 2.75x CH71'"'"'s ride, 2.35x its structure.
const GONDOLA_TOP_Y: float = 14.0

## The mast and the cap stand this far over the gondola'"'"'s top, CH71'"'"'s
## own 1.5 u (6.6 - 5.10). The tower'"'"'s height FOLLOWS the ride rather
## than being typed beside it: one fact, one spelling.
const TOWER_TOP_HEADROOM: float = 1.5
const TOWER_HEIGHT: float = GONDOLA_TOP_Y + TOWER_TOP_HEADROOM

## The lattice: the first ring, the pitch between rings, and the gap the
## last ring keeps under the cap. CH71 wrote [2.2, 4.2, 6.2] by hand for
## a 6.6 tower; `tower_brace_levels()` REPRODUCES that list exactly at
## that height (FunfairProbe gates it) and grows with any other.
const TOWER_BRACE_FIRST: float = 2.2
const TOWER_BRACE_PITCH: float = 2.0
const TOWER_BRACE_UNDER_CAP: float = 0.4

## =====================================================================
## CH72 -- THE CLIMB IS A DURATION, THE BRAKE IS A g, AND BOTH FOLLOW
## THE HEIGHT
##
## CH71 typed a rise SPEED (0.9 u/s) and a brake HEIGHT (1.6). Both are
## spellings of a height that has now changed, and left as literals they
## would have shipped a 15 s climb and a 10.8 g stop. What a player
## actually feels is a DURATION and a DECELERATION, so those are what
## this file publishes and the speeds follow.
##
## ⚠️ THE RATIO IS NOT INVENTED -- IT IS CH71'"'"'S OWN, READ BACK OUT. With
## H = TOP - REST and the brake taken over the last d units, energy gives
## decel = GRAVITY * (H - d) / d. CH71'"'"'s 1.6 on a 4.65 u drop is
## d = 1.15, so decel / GRAVITY = (4.65 - 1.15) / 1.15 = 3.0435 -- the
## "3.04 g" its own header quotes. Inverted, d = H / (1 + 3.0435), which
## returns 1.59999 for CH71'"'"'s height: the derivation reproduces the
## shipped number to a hundredth of a millimetre, and that is the gate.
## The stop therefore stays exactly as firm as the one Mathieu validated
## on device, at any height.
const TOWER_BRAKE_G: float = 3.0435
## CH71 climbed 4.65 u at 0.9 u/s = 5.17 s. 13.55 u at that speed is
## 15.1 s of nothing happening; this is the climb this lot authors, and
## it is a FEEL number -- Mathieu'"'"'s to move, not a bench'"'"'s.
const GONDOLA_RISE_S: float = 7.0
## CH71 held 1.6 s at a top that showed nothing. The whole point of
## CHANGE 2 is that the top now shows something, so the hold is longer --
## declared as a judgment tied to that purpose, not smuggled in.
const GONDOLA_HOLD_S: float = 2.4
const GONDOLA_SETTLE_S: float = 0.6
const GONDOLA_SEAT: Vector3 = Vector3(0.0, 0.12, 0.0)
const GONDOLA_FLOOR: Vector3 = Vector3(1.5, 0.15, 1.5)
const GONDOLA_RAIL_HEIGHT: float = 0.9

## =====================================================================
## CH75 -- THE COMET: THE THIRD RIDE, AND THE ONE THAT IS MEANT TO SCARE
##
## Brief (carte blanche, 11 sept 2026): a third ride in the fair, "nettement
## plus effrayant et plus rapide" than the two above, on a fixed rail with
## no player control, under the CHASE camera. The profile is decided by
## three measurements, not by taste:
##
##   (a) THE NUMBER. The CH71 coaster crests at 5.03 u and reaches
##       9.19 u/s; the CH72 tower falls at 14.21 u/s. Energy on a rail is
##       v = sqrt(2 g dh) less losses: a 14.0 u crest (the tower's own
##       height, the one CH72 rendered and kept) into a 0.9 u valley gives
##       ~16.1 u/s -- x1.75 the coaster, x1.13 the tower, x1.6 the
##       board's cruise (10.0). The drop is authored at 65-75 deg where
##       the coaster's steepest section is 37.6 deg, and the lift is a
##       45 deg climb where the coaster's is 17.7. CometProbe measures
##       every one of these on the built curve and on the ridden cart.
##   (b) UNLIT READABILITY. Nothing in this hub is lit (CLAUDE.md), so a
##       shape reads by SILHOUETTE alone. A tall lattice against the haze
##       is exactly what the CH72 tower already is (15.5 u, device-
##       validated visible); a drop reads as a drop because the rail's
##       silhouette falls. An INVERSION would not: `KeepyHopper.
##       follow_carrier` hands a rider the carrier's YAW ONLY (five rides
##       depend on that contract), so a looping cart would draw Keepy
##       upright through the loop -- a broken picture, and fixing it
##       means changing a shared, device-validated component. No loops.
##   (c) BUDGET. Ch75SiteRecon measured a chase pose at 16 u looking
##       south at 69 897 opaque primitives against 70 782 for the fixed
##       pose at the spawn: height buys nothing and costs nothing on this
##       plateau. The Comet itself is boxes and six-sided tubes,
##       CometProbe publishes its triangles.
##
## WHERE: the north-east wedge of zone 0, north of the CH71 loop (whose
## north tip is z 37.4), inside the skate lobe (r 36 from (0, 35)).
## Ch75SiteRecon: flat (h 0.000 everywhere), no layout prop but the
## seesaw at (18, 44) r 1.8 and the zipline P2 tower at (25.2, 35) r 3
## (its cable ends at z 34.5), no tall scatter inside the region, and
## the wall's first trunk at (35.2, 55.1) outside it. Every rail, the
## OUTER rail included (gauge/2 + radius), and every post is inside the
## region -- CH71's "nothing overhangs the edge", re-gated by CometProbe
## with the outer-rail offset, because the lobe is a circle and a
## 14 u rail past its rim would stand its posts among the wall trees.
##
## THE LOOP, in riding order, y = rail top. Station on the west leg
## heading NORTH; the lift climbs straight north -- gently for 7 u, then
## at ~60 deg (a two-slope chain, and the knee is where the FIXED camera
## decided it: the hub pose stands 8.9 u north of the rider at 7.6 u,
## i.e. over the lift 8.9 u north of the station, and a 45 deg lift put
## that rail at 8.2 u -- the boarding camera was INSIDE the lift's posts,
## CometProbe E11's last four frames. The gentle leg keeps the rail at
## ~4.6 u there, three units under the lens); a semicircle
## at 14 u carries the cart east (still on the chain: the crest is at
## the END of the turn, so the top is a 4 s crawl over the drop); the
## drop falls SOUTH along x 28.5; a camelback; a trim brake on its
## far side; a semicircle at ground level brings the cart back to the
## station. The turns are laid as semicircles with EVENLY spaced
## control points (~2 u): a Catmull-Rom through uneven points kinks,
## and a kink in the flat heading is a camera whip (measured before
## authoring: 0.48 u of turn radius from an uneven end point, 2.8 u
## with the points spread). Points 9-17 share x = 28.3 EXACTLY, so the
## ride frame's yaw on the drop is 180.00 deg and not a wobble read off
## a tangent whose flat component is tiny -- and the top turn FINISHES
## on the flat (point 9), one control point BEFORE the crest: a first
## draft ended the turn on the crest itself and the cart's yaw swung
## 36 deg in the few frames where the tangent tipped over (502 deg/s,
## CometProbe E24), because a heading read off a tangent that is
## mostly vertical turns as fast as the tangent tips. Point 9 exists
## for the same reason: without it the tangent at 10 (the chord 8 -> 11)
## pointed 40 deg east and the spline bulged past x 28.3 and back (an
## S, 0.49 u of radius in the replica).
const COMET_POINTS: Array = [
	Vector3(23.0, 0.55, 41.5),   # 0  station stop
	Vector3(23.0, 0.62, 43.2),   # 1  lift foot
	Vector3(23.0, 1.30, 45.2),   #    a gentle first leg (see below)
	Vector3(23.0, 2.60, 47.6),
	Vector3(23.0, 4.30, 50.0),   # 4  the knee: the chain steepens to ~60 deg
	Vector3(23.0, 8.50, 52.6),
	Vector3(23.0, 13.0, 55.2),   # 6  top of the climb, the turn begins
	Vector3(23.81, 13.4, 57.14),
	Vector3(25.75, 13.7, 57.95), # 8  the apex of the turn
	Vector3(27.6, 13.8, 57.3),
	Vector3(28.3, 13.9, 56.0),   # 10 the turn ends heading south, on the flat
	Vector3(28.3, 14.0, 54.7),   # 11 crest -- the drop begins, already due south
	Vector3(28.3, 12.3, 53.5),
	Vector3(28.3, 7.00, 51.6),
	Vector3(28.3, 2.20, 49.5),
	Vector3(28.3, 0.90, 47.6),   # 15 valley (COMET_VALLEY_INDEX)
	Vector3(28.3, 4.40, 45.0),   # 16 camelback
	Vector3(28.3, 2.40, 43.2),
	Vector3(28.3, 1.00, 41.5),   # 18 second valley, the turn begins
	Vector3(27.52, 0.70, 39.63),
	Vector3(25.65, 0.60, 38.85), # 20 the south apex
	Vector3(23.78, 0.60, 39.63),
]
## The index of the valley at the foot of the drop, read by the closed
## form below and by CometProbe -- never re-counted from the table.
const COMET_VALLEY_INDEX: int = 15
## The chain and the run-out. The lift is the CH71 chain (LIFT_SPEED /
## LIFT_ACCEL, shared); GRAVITY and ROLL_FRICTION are shared too, so the
## two coasters answer to the same physics and differ ONLY in what is
## authored -- the height. What is the Comet's own:
##   * no player brake: the brief says no control, and a held finger
##     does nothing (the ride is BOUNDED by the rail, the floor and the
##     run-out, which is the licence to drop a tap -- unchanged);
##   * a TWO-STAGE run-out. The cart reaches the bottom turn at ~13 u/s
##     and a 2.75 u semicircle at that speed is a 270 deg/s yaw -- a
##     camera whip, not a ride. So the last COMET_BRAKE_RUN_U units are
##     a TRIM over the first COMET_TRIM_U (speed falls linearly to
##     COMET_TURN_SPEED, ~1.9 g -- the magnetic brake a real ride has
##     there) and then the CH71 sqrt run-out from COMET_TURN_SPEED to a
##     stop at s = L. CometProbe A12 walks the run-out's own speed law
##     along the baked turn and gates its yaw under the camera's cap.
const COMET_BRAKE_RUN_U: float = 13.0
const COMET_TRIM_U: float = 4.0
const COMET_TURN_SPEED: float = 5.0
## Rails, ties and posts: the CH71 gauge and radius (one rail is one
## rail), a thicker post and a closer pitch because these stand 14 u.
const COMET_POST_SPACING: float = 1.5
const COMET_POST_THICK: float = 0.22
## Posts taller than this get a diagonal brace to the next one: the
## lattice is what makes a 14 u structure read as a STRUCTURE by
## silhouette, which is the only way anything reads here (b above).
const COMET_BRACE_MIN: float = 3.0
const COMET_BRACE_THICK: float = 0.09
## The station: the CH71 deck, one unit west of the rail.
const COMET_STAND: Vector3 = Vector3(22.0, 0.0, 41.5)
const COMET_DECK_CENTRE: Vector3 = Vector3(22.0, 0.0, 42.0)
const COMET_TAP_RADIUS: float = 2.0
## Solids that are not rail posts, on the fair's one body: the CH71
## station's 2 posts, the tower's base + mast + 4 legs, the Comet
## station's 2 posts. FunfairProbe D3 reads this instead of typing 8.
const FIXED_SOLIDS: int = 2 + 6 + 2

## ---- colours (vertex colours, unlit) --------------------------------
const WOOD: Color = Color(0.62, 0.44, 0.26)
const WOOD_TOP: Color = Color(0.70, 0.52, 0.32)
const STEEL: Color = Color(0.72, 0.74, 0.78)
const TOWER_RED: Color = Color(0.88, 0.36, 0.22)
const TOWER_RED_TOP: Color = Color(0.94, 0.46, 0.30)
const CONCRETE: Color = Color(0.60, 0.60, 0.59)
const CREAM: Color = Color(0.96, 0.80, 0.25)
const CREAM_TOP: Color = Color(0.84, 0.66, 0.18)
const WHEEL: Color = Color(0.22, 0.22, 0.24)
## CH75 -- the Comet's own: a DARK structure (it is seen against the
## haze from 14 u up, where a light steel would fade) and a BRIGHT rail
## (seen against the lawn from the ground, L ~0.65 against the hub's
## rendered 0.08). A device call like every colour here; distinct from
## the CH71 wood/steel/cream so the two rides never read as one.
const COMET_INK: Color = Color(0.30, 0.16, 0.48)
const COMET_INK_TOP: Color = Color(0.40, 0.24, 0.60)
const COMET_RAIL: Color = Color(0.98, 0.86, 0.30)
const COMET_CART: Color = Color(0.85, 0.20, 0.30)
const COMET_CART_TOP: Color = Color(0.96, 0.40, 0.46)

## The two rides, by index -- a TABLE from the first entry.
const RIDE_COASTER: int = 0
const RIDE_TOWER: int = 1
## CH75: the Comet.
const RIDE_COMET: int = 2

enum CoasterPhase { IDLE, DEPART, LIFT, COAST, BRAKE }
enum TowerPhase { IDLE, RISE, HOLD, FALL, BRAKE, SETTLE }
## CH75: the Comet's run. TRIM is the first stage of the run-out.
enum CometPhase { IDLE, DEPART, LIFT, COAST, TRIM, BRAKE }

signal ride_started(ride: int)
## `landing` is the flat ground point the rider steps off onto.
signal ride_finished(ride: int, landing: Vector3)

var _keepy: KeepyHopper = null
## CH72: the hub camera, for the tower's lift. Held the way HubTransport
## holds it -- a coordinator may drive the camera of the ride it owns.
var _camera: Node = null
var _curve: Curve3D = null
var _length: float = 0.0
var _crest_s: float = 0.0
var _lift_foot_s: float = 0.0
var _peak_y: float = 0.0
var _cart: Node3D = null
var _gondola: Node3D = null
var _tower_root: Node3D = null
var _track_node: MeshInstance3D = null
var _body: StaticBody3D = null
var _tris: int = 0
var _intent: int = -1

var _coaster_phase: int = CoasterPhase.IDLE
var _s: float = 0.0
var _v: float = 0.0
var _energy: float = 0.0
var _brake_entry_v: float = 0.0
var _brake_override: int = -1

var _tower_phase: int = TowerPhase.IDLE
var _gy: float = GONDOLA_REST_Y
var _gv: float = 0.0
var _hold_left: float = 0.0
var _brake_decel: float = 0.0

## CH75: the Comet's curve, cart and run.
var _comet_curve: Curve3D = null
var _comet_length: float = 0.0
var _comet_crest_s: float = 0.0
var _comet_lift_foot_s: float = 0.0
var _comet_peak_y: float = 0.0
var _comet_cart: Node3D = null
## CH75: the chase camera's MOUNT -- a node the fair trails on the rail
## HubCamera.DRIVE_BACK behind the cart. The camera stands over it and
## looks at the cart (HubCamera.ChaseTuning.coaster). See the tuning's
## header for the two poses that were measured inside the structure
## before this one.
var _comet_mount: Node3D = null
var _comet_track_node: MeshInstance3D = null
var _comet_tris: int = 0
var _comet_posts: int = 0
var _comet_phase: int = CometPhase.IDLE
var _cs: float = 0.0
var _cv: float = 0.0
var _cenergy: float = 0.0
var _ctrim_entry_v: float = 0.0
## Whether this file asked the camera for the Comet's chase, so the exit
## is only ever asked for a chase this file opened (HubTransport's
## `_board_chase` reasoning: never exit_drive() a camera chasing the
## kart).
var _comet_chase: bool = false

func _ready() -> void:
	_build_curve()
	_build_comet_curve()
	_build()
	_build_comet()

func setup(keepy: KeepyHopper, camera: Node = null) -> void:
	_keepy = keepy
	_camera = camera

# =====================================================================
# THE CURVE

## CH75: the spline arithmetic lives in CoasterRail, shared with the
## Comet -- one spelling of "how a closed loop is baked". Same tension,
## same interval, same crest sampling (0.05 u from s = 0): FunfairProbe
## PHASE A reads the CH71 numbers back (51.165 u, crest s 17.350 / y
## 5.027) on both trees, which is what makes this a move and not a change.
func _build_curve() -> void:
	_curve = CoasterRail.build_curve(TRACK_POINTS, TRACK_TENSION, TRACK_BAKE_INTERVAL)
	_length = _curve.get_baked_length()
	# The crest and the lift foot are MEASURED off the baked curve.
	var top: Dictionary = CoasterRail.crest(_curve)
	_peak_y = float(top["y"])
	_crest_s = float(top["s"])
	_lift_foot_s = _curve.get_closest_offset(TRACK_POINTS[1])

func track_length() -> float:
	return _length

func crest_s() -> float:
	return _crest_s

func lift_foot_s() -> float:
	return _lift_foot_s

func peak_rail_y() -> float:
	return _peak_y

func track_curve() -> Curve3D:
	return _curve

## The rail-top point at arc length `s` (wrapped).
func track_point(s: float) -> Vector3:
	return CoasterRail.point_at(_curve, s)

func track_tangent(s: float) -> Vector3:
	return CoasterRail.tangent_at(_curve, s)

## The SWEEP frame at `s`: columns (right, up, forward), origin on the
## rail top. Used to lay the rails and the ties down, and for nothing
## else.
##
## ⚠️ CH72 -- THIS BASIS IS MIRRORED (det = -1) AND MUST NEVER BE A NODE
## TRANSFORM. `t.cross(UP)` is the LEFT of the direction of travel, not
## its right: with t = +Z it returns (-1, 0, 0), so Basis(right, up, t)
## has determinant -1. That is harmless here and always has been -- the
## rails are laid symmetrically about the centre line (-gauge/2 and
## +gauge/2), so swapping left for right only renames them, and a
## six-sided tube swept about a flipped radial axis is the same hexagon
## rotated -- but a mirrored basis handed to a Node3D is not a rotation
## at all, and the yaw Godot decomposes out of one means nothing.
## Anything that RIDES the rail takes `ride_frame()` below.
func track_frame(s: float) -> Transform3D:
	return CoasterRail.sweep_frame(_curve, s)

## CH72 -- THE POSE OF ANYTHING THAT RIDES THE RAIL AT `s`: origin on the
## rail top, and **+Z along the direction of travel**.
##
## ⚠️ +Z, NOT -Z, AND THAT IS THE WHOLE OF CHANGE 1. A carrier hands its
## yaw to its rider verbatim -- `KeepyHopper.follow_carrier()` is
## `_yaw.rotation_degrees.y = _carrier.global_rotation_degrees.y` -- and
## Keepy'"'"'s model FACES +Z at yaw zero (`KeepyHopper._face`'"'"'s own comment,
## measured on the .glb). So the axis a rider looks along is the
## carrier'"'"'s +Z, and a cart posed by `Basis.looking_at(t, UP)` puts -Z on
## the tangent (that is what looking_at means) and therefore +Z on -t.
##
## MEASURED, not deduced (Ch72Recon R1, 900 frames of a real ride driven
## through the player'"'"'s own tap channel): the angle between Keepy'"'"'s drawn
## facing and the direction of travel read **180.00 deg on the first
## frame, mean 179.90, max 180.00** -- he rode the whole loop backwards,
## on the lift, through both turns and down the drop.
##
## Right-handed by construction, which `track_frame()` above is not:
## X = Y x Z is the identity Godot'"'"'s own yaw basis satisfies, so
## `global_rotation_degrees.y` decomposes back to the tangent'"'"'s bearing
## and the rider is handed the heading the rail actually has. Nothing is
## hard-coded to this loop: change a control point and the pose follows.
func ride_frame(s: float) -> Transform3D:
	return CoasterRail.ride_frame(_curve, s)

# ---------------------------------------------------------------------
# CH75 -- THE COMET'S CURVE, the same arithmetic over its own points

func _build_comet_curve() -> void:
	_comet_curve = CoasterRail.build_curve(COMET_POINTS, TRACK_TENSION, TRACK_BAKE_INTERVAL)
	_comet_length = _comet_curve.get_baked_length()
	var top: Dictionary = CoasterRail.crest(_comet_curve)
	_comet_peak_y = float(top["y"])
	_comet_crest_s = float(top["s"])
	_comet_lift_foot_s = _comet_curve.get_closest_offset(COMET_POINTS[1])

func comet_length() -> float:
	return _comet_length

func comet_crest_s() -> float:
	return _comet_crest_s

func comet_lift_foot_s() -> float:
	return _comet_lift_foot_s

func comet_peak_rail_y() -> float:
	return _comet_peak_y

func comet_curve() -> Curve3D:
	return _comet_curve

func comet_point(s: float) -> Vector3:
	return CoasterRail.point_at(_comet_curve, s)

func comet_tangent(s: float) -> Vector3:
	return CoasterRail.tangent_at(_comet_curve, s)

func comet_ride_frame(s: float) -> Transform3D:
	return CoasterRail.ride_frame(_comet_curve, s)

## The arc lengths at which the Comet stands a post: every
## COMET_POST_SPACING from s = 0 wherever the rail is over
## POST_MIN_HEIGHT. ONE spelling, read by the builder AND by
## footprints(): the D3 census (posts = box shapes - FIXED_SOLIDS)
## only holds if the two agree, and a second loop is how they stop
## agreeing.
static func comet_post_stations(curve: Curve3D) -> Array:
	var out: Array = []
	var length: float = curve.get_baked_length()
	var s: float = 0.0
	while s < length:
		if curve.sample_baked(s, true).y > POST_MIN_HEIGHT:
			out.append(s)
		s += COMET_POST_SPACING
	return out

# =====================================================================
# BUILDING

func _build() -> void:
	var mat: ShaderMaterial = CozyPalette.decor_material()
	_body = StaticBody3D.new()
	_body.name = "FunfairCollider"
	_body.collision_layer = 1 << (SkateBoardBody.LAYER_PARK - 1)
	_body.collision_mask = 0
	add_child(_body)

	# ---- the track
	var track := FunfairMesh.new()
	var frames_l: Array = []
	var frames_r: Array = []
	var s: float = 0.0
	var samples: int = int(floor(_length / RAIL_SAMPLE))
	for i in samples:
		var f: Transform3D = track_frame(float(i) * RAIL_SAMPLE)
		var drop: Vector3 = -f.basis.y * RAIL_RADIUS
		frames_l.append(Transform3D(f.basis, f.origin - f.basis.x * RAIL_GAUGE * 0.5 + drop))
		frames_r.append(Transform3D(f.basis, f.origin + f.basis.x * RAIL_GAUGE * 0.5 + drop))
	track.swept_tube(frames_l, RAIL_RADIUS, STEEL)
	track.swept_tube(frames_r, RAIL_RADIUS, STEEL)
	s = 0.0
	while s < _length:
		var f: Transform3D = track_frame(s)
		var under: Vector3 = f.origin - f.basis.y * (RAIL_RADIUS * 2.0 + TIE_THICK * 0.5)
		track.strut(under - f.basis.x * TIE_WIDTH * 0.5, under + f.basis.x * TIE_WIDTH * 0.5, TIE_THICK, WOOD)
		s += TIE_SPACING
	s = 0.0
	while s < _length:
		var p: Vector3 = track_point(s)
		if p.y > POST_MIN_HEIGHT:
			var top: float = p.y - POST_BELOW_RAIL
			var ground: Vector3 = HubSurface.ground(Vector3(p.x, 0.0, p.z))
			track.box(Vector3(p.x, (ground.y + top) * 0.5, p.z),
				Vector3(POST_THICK, top - ground.y, POST_THICK), WOOD, WOOD_TOP, true)
		s += POST_SPACING
	# ---- the station: deck, two posts, a flat roof
	var deck_ground: Vector3 = HubSurface.ground(DECK_CENTRE)
	track.box(Vector3(DECK_CENTRE.x, deck_ground.y + DECK_LIFT + DECK_SIZE.y * 0.5, DECK_CENTRE.z),
		DECK_SIZE, WOOD, WOOD_TOP, false)
	for dz in [-1.0, 1.0]:
		var foot := Vector3(DECK_CENTRE.x - DECK_SIZE.x * 0.5 + STATION_POST_THICK * 0.5, 0.0,
			DECK_CENTRE.z + dz * (DECK_SIZE.z * 0.5 - STATION_POST_THICK * 0.5))
		track.box(Vector3(foot.x, STATION_POST_HEIGHT * 0.5, foot.z),
			Vector3(STATION_POST_THICK, STATION_POST_HEIGHT, STATION_POST_THICK), WOOD, WOOD_TOP, true)
	track.box(Vector3(DECK_CENTRE.x + 0.35, STATION_POST_HEIGHT + STATION_ROOF.y * 0.5, DECK_CENTRE.z),
		STATION_ROOF, WOOD, WOOD_TOP, false)
	_track_node = _draw("Track", track, mat)
	_solids(track)

	# ---- the cart
	var cart := FunfairMesh.new()
	cart.box(Vector3(0.0, CART_BODY_Y, 0.0), CART_BODY, CREAM, CREAM_TOP, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			cart.box(Vector3(sx * (CART_BODY.x * 0.5 - 0.04), WHEEL_SIZE.y * 0.5, sz * 0.35), WHEEL_SIZE, WHEEL, WHEEL, false)
	_cart = Node3D.new()
	_cart.name = "Cart"
	add_child(_cart)
	_draw("CartMesh", cart, mat, _cart)
	_park_cart()

	# ---- the tower
	var tower := FunfairMesh.new()
	var tg: Vector3 = HubSurface.ground(TOWER_AT)
	tower.box(tg + Vector3(0.0, TOWER_BASE.y * 0.5, 0.0), TOWER_BASE, CONCRETE, CONCRETE.lightened(0.05), true)
	var base_top: float = tg.y + TOWER_BASE.y
	tower.box(tg + Vector3(0.0, (base_top + TOWER_HEIGHT) * 0.5, 0.0),
		Vector3(TOWER_MAST_THICK, TOWER_HEIGHT - base_top, TOWER_MAST_THICK), TOWER_RED, TOWER_RED_TOP, true)
	var legs: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := tg + Vector3(sx * TOWER_HALF_SPAN, 0.0, sz * TOWER_HALF_SPAN)
			legs.append(leg)
			tower.box(leg + Vector3(0.0, (base_top + TOWER_HEIGHT) * 0.5, 0.0),
				Vector3(TOWER_LEG_THICK, TOWER_HEIGHT - base_top, TOWER_LEG_THICK), TOWER_RED, TOWER_RED_TOP, true)
	# Braces: at each level a ring of four horizontals between the legs
	# and one diagonal per side, alternating direction level to level.
	var ring: Array = [legs[0], legs[1], legs[3], legs[2]]
	var levels: Array = tower_brace_levels()
	for li in levels.size():
		var y: float = float(levels[li])
		var below: float = float(levels[li - 1]) if li > 0 else base_top
		for k in 4:
			var a: Vector3 = ring[k] + Vector3(0.0, y, 0.0)
			var b: Vector3 = ring[(k + 1) % 4] + Vector3(0.0, y, 0.0)
			tower.strut(a, b, TOWER_BRACE_THICK, TOWER_RED)
			var d0: Vector3 = ring[k] + Vector3(0.0, below, 0.0)
			var d1: Vector3 = ring[(k + 1) % 4] + Vector3(0.0, y, 0.0)
			if li % 2 == 1:
				d0 = ring[(k + 1) % 4] + Vector3(0.0, below, 0.0)
				d1 = ring[k] + Vector3(0.0, y, 0.0)
			tower.strut(d0, d1, TOWER_BRACE_THICK, TOWER_RED)
	tower.box(tg + Vector3(0.0, TOWER_HEIGHT + TOWER_CAP.y * 0.5, 0.0), TOWER_CAP, TOWER_RED, TOWER_RED_TOP, false)
	_tower_root = Node3D.new()
	_tower_root.name = "Tower"
	add_child(_tower_root)
	_draw("TowerMesh", tower, mat, _tower_root)
	_solids(tower)
	# CH46: the tower is a PLACE on the minimap. The node that is marked
	# is the one that stands where the tower stands -- a Node3D at the
	# tower's own origin, never `self` (this coordinator sits at the
	# world origin, CLAUDE.md's marker-on-a-controller defect).
	var place := Node3D.new()
	place.name = "Funfair"
	place.position = tg
	_tower_root.add_child(place)
	MinimapMarkers.mark(place, MinimapMarkers.PLACE)

	# ---- the gondola
	var gond := FunfairMesh.new()
	gond.box(Vector3.ZERO, GONDOLA_FLOOR, CREAM, CREAM_TOP, false)
	var gh: float = GONDOLA_FLOOR.x * 0.5 - 0.06
	var corners: Array = [Vector3(-gh, 0.0, -gh), Vector3(gh, 0.0, -gh), Vector3(gh, 0.0, gh), Vector3(-gh, 0.0, gh)]
	for k in 4:
		var c: Vector3 = corners[k]
		gond.strut(c + Vector3(0.0, GONDOLA_FLOOR.y * 0.5, 0.0), c + Vector3(0.0, GONDOLA_RAIL_HEIGHT, 0.0), 0.07, CREAM_TOP)
		gond.strut(c + Vector3(0.0, GONDOLA_RAIL_HEIGHT, 0.0), corners[(k + 1) % 4] + Vector3(0.0, GONDOLA_RAIL_HEIGHT, 0.0), 0.06, CREAM_TOP)
	_gondola = Node3D.new()
	_gondola.name = "Gondola"
	add_child(_gondola)
	_draw("GondolaMesh", gond, mat, _gondola)
	_gy = tg.y + GONDOLA_REST_Y
	_place_gondola()

func _draw(name: String, builder: FunfairMesh, mat: Material, parent: Node = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = builder.mesh()
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	_tris += builder.triangle_count()
	return node

func _solids(builder: FunfairMesh) -> void:
	for piece in builder.solids:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = piece["size"]
		shape.shape = box
		shape.position = piece["centre"]
		_body.add_child(shape)

func _park_cart() -> void:
	_s = 0.0
	_v = 0.0
	_pose_cart()

func _pose_cart() -> void:
	# CH72: `ride_frame`, whose +Z IS the direction of travel -- see there
	# for why `Basis.looking_at(t, UP)` sat the rider backwards.
	_cart.global_transform = ride_frame(_s)

func _place_gondola() -> void:
	_gondola.global_position = Vector3(TOWER_AT.x, _gy, TOWER_AT.z)

# ---------------------------------------------------------------------
# CH75 -- BUILDING THE COMET: rails, ties, braced posts, station, cart

func _build_comet() -> void:
	var mat: ShaderMaterial = CozyPalette.decor_material()
	var before: int = _tris
	var track := FunfairMesh.new()
	var frames_l: Array = []
	var frames_r: Array = []
	var samples: int = int(floor(_comet_length / RAIL_SAMPLE))
	for i in samples:
		var f: Transform3D = CoasterRail.sweep_frame(_comet_curve, float(i) * RAIL_SAMPLE)
		var drop: Vector3 = -f.basis.y * RAIL_RADIUS
		frames_l.append(Transform3D(f.basis, f.origin - f.basis.x * RAIL_GAUGE * 0.5 + drop))
		frames_r.append(Transform3D(f.basis, f.origin + f.basis.x * RAIL_GAUGE * 0.5 + drop))
	track.swept_tube(frames_l, RAIL_RADIUS, COMET_RAIL)
	track.swept_tube(frames_r, RAIL_RADIUS, COMET_RAIL)
	var s: float = 0.0
	while s < _comet_length:
		var f: Transform3D = CoasterRail.sweep_frame(_comet_curve, s)
		var under: Vector3 = f.origin - f.basis.y * (RAIL_RADIUS * 2.0 + TIE_THICK * 0.5)
		track.strut(under - f.basis.x * TIE_WIDTH * 0.5, under + f.basis.x * TIE_WIDTH * 0.5, TIE_THICK, COMET_INK)
		s += TIE_SPACING
	# Posts, and a diagonal brace from each tall post's foot to the top
	# of the next tall post, alternating side to side.
	var stations: Array = comet_post_stations(_comet_curve)
	_comet_posts = stations.size()
	var feet: Array = []
	var tops: Array = []
	for st in stations:
		var p: Vector3 = comet_point(float(st))
		var top: float = p.y - POST_BELOW_RAIL
		var ground: Vector3 = HubSurface.ground(Vector3(p.x, 0.0, p.z))
		track.box(Vector3(p.x, (ground.y + top) * 0.5, p.z),
			Vector3(COMET_POST_THICK, top - ground.y, COMET_POST_THICK), COMET_INK, COMET_INK_TOP, true)
		feet.append(ground)
		tops.append(Vector3(p.x, top, p.z))
	for k in range(feet.size() - 1):
		var ha: float = tops[k].y - feet[k].y
		var hb: float = tops[k + 1].y - feet[k + 1].y
		if ha < COMET_BRACE_MIN or hb < COMET_BRACE_MIN:
			continue
		# Only between NEIGHBOURING posts (a gap in the stations -- the
		# rail dipping under POST_MIN_HEIGHT -- would otherwise be
		# bridged by a brace across the lawn).
		if float(stations[k + 1]) - float(stations[k]) > COMET_POST_SPACING * 1.5:
			continue
		if k % 2 == 0:
			track.strut(feet[k] + Vector3(0.0, 0.3, 0.0), tops[k + 1] - Vector3(0.0, 0.3, 0.0), COMET_BRACE_THICK, COMET_INK)
		else:
			track.strut(feet[k + 1] + Vector3(0.0, 0.3, 0.0), tops[k] - Vector3(0.0, 0.3, 0.0), COMET_BRACE_THICK, COMET_INK)
	# The station: the CH71 deck, posts and roof, in the Comet's ink.
	var deck_ground: Vector3 = HubSurface.ground(COMET_DECK_CENTRE)
	track.box(Vector3(COMET_DECK_CENTRE.x, deck_ground.y + DECK_LIFT + DECK_SIZE.y * 0.5, COMET_DECK_CENTRE.z),
		DECK_SIZE, WOOD, WOOD_TOP, false)
	for dz in [-1.0, 1.0]:
		var foot := Vector3(COMET_DECK_CENTRE.x - DECK_SIZE.x * 0.5 + STATION_POST_THICK * 0.5, 0.0,
			COMET_DECK_CENTRE.z + dz * (DECK_SIZE.z * 0.5 - STATION_POST_THICK * 0.5))
		track.box(Vector3(foot.x, STATION_POST_HEIGHT * 0.5, foot.z),
			Vector3(STATION_POST_THICK, STATION_POST_HEIGHT, STATION_POST_THICK), COMET_INK, COMET_INK_TOP, true)
	track.box(Vector3(COMET_DECK_CENTRE.x + 0.35, STATION_POST_HEIGHT + STATION_ROOF.y * 0.5, COMET_DECK_CENTRE.z),
		STATION_ROOF, COMET_INK, COMET_INK_TOP, false)
	_comet_track_node = _draw("CometTrack", track, mat)
	_solids(track)
	# The cart: the CH71 box and wheels, plus a headrest behind the seat
	# so its silhouette reads as a seat and not a crate.
	var cart := FunfairMesh.new()
	cart.box(Vector3(0.0, CART_BODY_Y, 0.0), CART_BODY, COMET_CART, COMET_CART_TOP, false)
	cart.box(Vector3(0.0, CART_BODY_Y + CART_BODY.y * 0.5 + 0.16, -CART_BODY.z * 0.5 + 0.10),
		Vector3(CART_BODY.x * 0.8, 0.32, 0.12), COMET_CART, COMET_CART_TOP, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			cart.box(Vector3(sx * (CART_BODY.x * 0.5 - 0.04), WHEEL_SIZE.y * 0.5, sz * 0.35), WHEEL_SIZE, WHEEL, WHEEL, false)
	_comet_cart = Node3D.new()
	_comet_cart.name = "CometCart"
	add_child(_comet_cart)
	_draw("CometCartMesh", cart, mat, _comet_cart)
	_comet_mount = Node3D.new()
	_comet_mount.name = "CometChaseMount"
	add_child(_comet_mount)
	_comet_tris = _tris - before
	_park_comet()

func _park_comet() -> void:
	_cs = 0.0
	_cv = 0.0
	_pose_comet()

func _pose_comet() -> void:
	_comet_cart.global_transform = comet_ride_frame(_cs)
	_comet_mount.global_transform = comet_ride_frame(_cs - HubCamera.DRIVE_BACK)

func comet_mount_node() -> Node3D:
	return _comet_mount

# =====================================================================
# WHAT THE FAIR PUBLISHES

## STATIC, on the same contract as HubSkatepark.footprints(): CozyScatter
## sows from its own _ready() and cannot depend on this node being built.
## The curve is therefore re-baked here rather than read off the node --
## the one second reading in this file, and FunfairProbe gates that the
## two lengths agree to the millimetre.
static var _footprint_cache: Array = []

## True when a scatter candidate at `p` (flat), reserving `own_radius`
## for itself, stands inside one of the fair's footprints. Read by
## CozyScatter._sprinkle AFTER the candidate's draws -- see there.
static func blocks(p: Vector3, own_radius: float) -> bool:
	for fp in footprints():
		if Vector2(p.x - fp["position"].x, p.z - fp["position"].z).length() < float(fp["radius"]) + own_radius:
			return true
	return false

static func footprints() -> Array:
	if not _footprint_cache.is_empty():
		return _footprint_cache
	var out: Array = []
	out.append({"position": Vector3(DECK_CENTRE.x, 0.0, DECK_CENTRE.z), "radius": DECK_FOOTPRINT})
	out.append({"position": Vector3(TOWER_AT.x, 0.0, TOWER_AT.z), "radius": TOWER_FOOTPRINT})
	var curve := _static_curve()
	var length: float = curve.get_baked_length()
	var s: float = 0.0
	while s < length:
		var p: Vector3 = curve.sample_baked(s, true)
		if p.y <= LOW_RAIL_HEIGHT:
			out.append({"position": Vector3(p.x, 0.0, p.z), "radius": LOW_RAIL_FOOTPRINT})
		s += 1.0
	s = 0.0
	while s < length:
		var p: Vector3 = curve.sample_baked(s, true)
		if p.y > POST_MIN_HEIGHT:
			out.append({"position": Vector3(p.x, 0.0, p.z), "radius": POST_FOOTPRINT})
		s += POST_SPACING
	# CH75: the Comet's deck, low rails and posts, on the same terms. The
	# posts come from comet_post_stations() -- the builder's own list.
	out.append({"position": Vector3(COMET_DECK_CENTRE.x, 0.0, COMET_DECK_CENTRE.z), "radius": DECK_FOOTPRINT})
	var comet := _static_comet_curve()
	var comet_length: float = comet.get_baked_length()
	s = 0.0
	while s < comet_length:
		var p: Vector3 = comet.sample_baked(s, true)
		if p.y <= LOW_RAIL_HEIGHT:
			out.append({"position": Vector3(p.x, 0.0, p.z), "radius": LOW_RAIL_FOOTPRINT})
		s += 1.0
	for st in comet_post_stations(comet):
		var p: Vector3 = comet.sample_baked(float(st), true)
		out.append({"position": Vector3(p.x, 0.0, p.z), "radius": POST_FOOTPRINT})
	_footprint_cache = out
	return out

static func _static_comet_curve() -> Curve3D:
	return CoasterRail.build_curve(COMET_POINTS, TRACK_TENSION, TRACK_BAKE_INTERVAL)

static func _static_curve() -> Curve3D:
	return CoasterRail.build_curve(TRACK_POINTS, TRACK_TENSION, TRACK_BAKE_INTERVAL)

func triangle_total() -> int:
	return _tris

func collider_body() -> StaticBody3D:
	return _body

func cart_node() -> Node3D:
	return _cart

func gondola_node() -> Node3D:
	return _gondola

func track_node() -> MeshInstance3D:
	return _track_node

func tower_node() -> Node3D:
	return _tower_root

func coaster_phase() -> int:
	return _coaster_phase

func coaster_s() -> float:
	return _s

func coaster_speed() -> float:
	return _v

func tower_phase() -> int:
	return _tower_phase

func gondola_y() -> float:
	return _gy

func gondola_speed() -> float:
	return _gv

## CH75: the Comet's readings.
func comet_node() -> Node3D:
	return _comet_cart

func comet_track_node() -> MeshInstance3D:
	return _comet_track_node

func comet_phase() -> int:
	return _comet_phase

func comet_s() -> float:
	return _cs

func comet_speed() -> float:
	return _cv

## Triangles the Comet alone laid down (inside triangle_total()).
func comet_triangle_total() -> int:
	return _comet_tris

func comet_post_count() -> int:
	return _comet_posts

## The speed the energy law predicts at the valley from the crest,
## losses included, for a bench to compare the ridden number against:
## v^2 = LIFT_SPEED^2 + 2 g (crest - valley) - 2 mu (arc length between).
func comet_predicted_valley_speed() -> float:
	var valley_s: float = _comet_curve.get_closest_offset(COMET_POINTS[COMET_VALLEY_INDEX])
	var dh: float = _comet_peak_y - comet_point(valley_s).y
	var v2: float = LIFT_SPEED * LIFT_SPEED + 2.0 * GRAVITY * dh - 2.0 * ROLL_FRICTION * (valley_s - _comet_crest_s)
	return sqrt(maxf(v2, 0.0))

func comet_valley_s() -> float:
	return _comet_curve.get_closest_offset(COMET_POINTS[COMET_VALLEY_INDEX])

## CH72 -- THE THREE NUMBERS THAT FOLLOW THE HEIGHT. Each is published
## once and read everywhere; none is typed beside the height it depends
## on. FunfairProbe re-derives all three at CH71's 5.10 and requires
## CH71's shipped values back.

## How far the gondola falls in all.
static func tower_drop_height() -> float:
	return GONDOLA_TOP_Y - GONDOLA_REST_Y

## Where the magnetic brake begins, so that the stop is TOWER_BRAKE_G
## regardless of how tall the tower is. See that constant for the
## inversion and for why 3.0435 is CH71's own number and not a new one.
static func gondola_brake_y() -> float:
	return GONDOLA_REST_Y + tower_drop_height() / (1.0 + TOWER_BRAKE_G)

## The rise speed that makes the climb last GONDOLA_RISE_S.
static func gondola_rise_speed() -> float:
	return tower_drop_height() / GONDOLA_RISE_S

## The rings of the lattice, bottom to top: one every TOWER_BRACE_PITCH
## from TOWER_BRACE_FIRST up to TOWER_BRACE_UNDER_CAP below the top.
## Returns exactly [2.2, 4.2, 6.2] at CH71's 6.6 m tower.
static func tower_brace_levels() -> Array:
	var out: Array = []
	var y: float = TOWER_BRACE_FIRST
	while y <= TOWER_HEIGHT - TOWER_BRACE_UNDER_CAP + 0.0001:
		out.append(y)
		y += TOWER_BRACE_PITCH
	return out

## The decel the magnetic brake needs, DERIVED from the fall: the speed
## reached at the brake height after a free fall from GONDOLA_TOP_Y, shed
## over the last brake_y - GONDOLA_REST_Y units. Equals
## TOWER_BRAKE_G * GRAVITY by construction; published as an arithmetic
## reading of the delivered numbers rather than as that identity, so a
## future change to either half shows up here instead of being asserted
## away.
static func tower_brake_decel() -> float:
	var brake_y: float = gondola_brake_y()
	var v2: float = 2.0 * GRAVITY * (GONDOLA_TOP_Y - brake_y)
	return v2 / (2.0 * (brake_y - GONDOLA_REST_Y))

func is_riding() -> bool:
	return _coaster_phase != CoasterPhase.IDLE or _tower_phase != TowerPhase.IDLE or _comet_phase != CometPhase.IDLE

## The stand point of a ride, flat.
static func stand_point(ride: int) -> Vector3:
	if ride == RIDE_COMET:
		return COMET_STAND
	return STATION_STAND if ride == RIDE_COASTER else TOWER_STAND

# =====================================================================
# CH72 -- WHAT EACH RIDE ASKS OF THE CAMERA

## How far below the horizon a POV on `ride` looks.
##
## LEVEL on the coaster: the rail supplies all the motion there, and a
## pitch that fought it would be the one term making people ill.
##
## TIPPED DOWN on the tower, and this number is the whole of CHANGE 2's
## payoff. Ch72Recon R4 rendered the view from the gondola with a 0.30
## rise/run tip -- 16.7 deg -- and measured the eye reaching ground at
## 55 u from 14.0 with 0.0 to 1.4 % of the frame sky. Level, the picture
## would be horizon; this is the angle that was actually measured, kept.
static func pov_pitch_deg(ride: int) -> float:
	return 0.0 if ride == RIDE_COASTER else TOWER_POV_PITCH_DEG
const TOWER_POV_PITCH_DEG: float = 16.7

## CH72 -- how far the fixed camera must rise for the tower ride to stay
## in frame: exactly how far the gondola is off its own rest. Zero
## whenever the tower is idle, and zero for the coaster, whose whole
## track was authored under the fixed ceiling and still fits under it.
func camera_lift() -> float:
	if _tower_phase == TowerPhase.IDLE:
		return 0.0
	return maxf(_gy - (HubSurface.ground(TOWER_AT).y + GONDOLA_REST_Y), 0.0)

func _push_camera_lift() -> void:
	if _camera != null and is_instance_valid(_camera) and _camera.has_method("set_fair_lift"):
		_camera.call("set_fair_lift", camera_lift())

# =====================================================================
# THE TAP DOOR (the boat pattern) AND THE INTENT (the kart's)

## Which ride a tap at `aim` (flat, UNCLAMPED) means, or -1. A ride that
## is running WITHDRAWS: the tap then falls through to the ground path.
func accepts_tap(aim: Vector3) -> int:
	var flat := Vector3(aim.x, 0.0, aim.z)
	if _coaster_phase == CoasterPhase.IDLE and flat.distance_to(Vector3(TRACK_POINTS[0].x, 0.0, TRACK_POINTS[0].z)) <= COASTER_TAP_RADIUS:
		return RIDE_COASTER
	if _tower_phase == TowerPhase.IDLE and flat.distance_to(Vector3(TOWER_AT.x, 0.0, TOWER_AT.z)) <= TOWER_TAP_RADIUS:
		return RIDE_TOWER
	# CH75: the Comet's station, withdrawing on the same terms.
	if _comet_phase == CometPhase.IDLE and flat.distance_to(Vector3(COMET_POINTS[0].x, 0.0, COMET_POINTS[0].z)) <= COMET_TAP_RADIUS:
		return RIDE_COMET
	return -1

# =====================================================================
# CH72 -- THE RIDER'S OWN TAP CHANNEL (the POV toggle)

## How near the tap RAY must pass the rider's body to mean "him". In
## world units, on the ray, and NOT a disc around a ground point -- see
## below for the measurement that rules the ground point out.
const RIDER_TAP_RADIUS: float = 0.75
## Two dispatches, one gesture: `emulate_mouse_from_touch` is true by
## default, so ONE finger produces a touch release AND a synthesised
## mouse release and `_handle_point` runs TWICE, in the same frame
## (CLAUDE.md, measured). A toggle read twice is a toggle that never
## moves, so a second answer inside this many frames is refused.
const RIDER_TAP_DEBOUNCE_FRAMES: int = 3

var _rider_tap_frame: int = -1000

## True when a tap aimed along (`origin`, `direction`) means the RIDER --
## i.e. "switch the point of view" -- rather than a place to walk to.
##
## ⚠️ ON THE RAY, NOT ON A GROUND DISC, AND THAT IS MEASURED. CLAUDE.md
## CH58 says a tap on a raised body is tested against its DRAWN ground
## point, because the camera never rises and a body above the plane is
## drawn where the ground under it is not. That rule was written for a
## board 0.85 u up, where the smear is centimetres. On this tower it
## breaks down completely: at the top of the ride the ray through his
## feet meets the ground 26.8 u south of him and the ray through his
## crown 35.3 u south -- his drawn SILHOUETTE covers 8.5 u of ground, and
## unlifted it covers 71.1. There is no disc that is "him".
##
## The perpendicular distance from his body to the tap ray has none of
## that: a body of radius r is hit exactly when the ray passes within r
## of it, at any height, under any lift, with no parallax term at all.
## It is the same instrument `HubTrees.tree_hit` already uses for a
## crown, in the same tap function.
##
## ⚠️ AND IN POV IT IS A TAP ANYWHERE. CH64's board precedent, verbatim:
## "under the chase camera there is no fixed pixel that means 'him' any
## more, so the gesture is a tap ANYWHERE rather than a tap on a body".
## Inside his own head there is no drawn Keepy at all. This is what stops
## the POV being a room with no door -- CLAUDE.md's PATRON ECHELLE -- and
## it is why this channel ADDS a meaning to a tap that the ON_CARRIER
## drop was throwing away, and removes no exit that existed.
func accepts_rider_tap(origin: Vector3, direction: Vector3) -> bool:
	if not is_riding() or _keepy == null:
		return false
	# CH75: no POV on the Comet. Its camera is the CHASE (HubCamera's
	# drive mode), and a POV opened over a running drive would be two
	# writers on one camera. Under the chase there is no fixed pixel that
	# means "him" either (CH64's reasoning). The tap falls through to the
	# ground path and is dropped by ON_CARRIER like every other.
	if _comet_phase != CometPhase.IDLE:
		return false
	if Engine.get_process_frames() - _rider_tap_frame < RIDER_TAP_DEBOUNCE_FRAMES:
		return false
	if _pov_on():
		return true
	var body: Vector3 = _keepy.global_position + Vector3.UP * (KeepyHopper.CROWN_HEIGHT * 0.5)
	var along: Vector3 = body - origin
	var perp: Vector3 = along - direction * along.dot(direction)
	return along.dot(direction) > 0.0 and perp.length() <= RIDER_TAP_RADIUS

## Stamps the gesture as spent, so the second dispatch of the same finger
## cannot undo it. Called by the listener that acts on the tap.
func mark_rider_tap() -> void:
	_rider_tap_frame = Engine.get_process_frames()

func _pov_on() -> bool:
	return _camera != null and is_instance_valid(_camera) and _camera.has_method("is_pov") and bool(_camera.call("is_pov"))

## Which ride is running, or -1 -- the POV needs to know which pitch to
## take, and `is_riding()` alone does not say.
func running_ride() -> int:
	if _coaster_phase != CoasterPhase.IDLE:
		return RIDE_COASTER
	if _tower_phase != TowerPhase.IDLE:
		return RIDE_TOWER
	if _comet_phase != CometPhase.IDLE:
		return RIDE_COMET
	return -1

## Arms the walk intent for `ride` and returns where to walk.
func arm(ride: int) -> Vector3:
	_intent = ride
	return stand_point(ride)

func intent() -> int:
	return _intent

func cancel_intent() -> void:
	_intent = -1

## Called by HubWorld on every ordinary landing. Mounts when the landing
## finishes the boarding walk; the intent SURVIVES a landing in passing.
func on_landing(position: Vector3) -> bool:
	if _intent < 0:
		return false
	var ride: int = _intent
	var here := Vector3(position.x, 0.0, position.z)
	if here.distance_to(stand_point(ride)) > KeepyHopper.ARRIVE_EPSILON + 0.05:
		return false
	_intent = -1
	return board(ride)

## Puts the rider on the ride and starts it. Refused unless the ride is
## idle and KeepyHopper is standing still (mount_carrier's own rule).
func board(ride: int) -> bool:
	if _keepy == null:
		return false
	if ride == RIDE_COASTER:
		if _coaster_phase != CoasterPhase.IDLE:
			return false
		_park_cart()
		if not _keepy.mount_carrier(_cart, CART_SEAT):
			return false
		_coaster_phase = CoasterPhase.DEPART
		_energy = 0.0
		ride_started.emit(RIDE_COASTER)
		return true
	if ride == RIDE_TOWER:
		if _tower_phase != TowerPhase.IDLE:
			return false
		if not _keepy.mount_carrier(_gondola, GONDOLA_SEAT):
			return false
		_tower_phase = TowerPhase.RISE
		_gv = 0.0
		ride_started.emit(RIDE_TOWER)
		return true
	if ride == RIDE_COMET:
		if _comet_phase != CometPhase.IDLE:
			return false
		_park_comet()
		if not _keepy.mount_carrier(_comet_cart, CART_SEAT):
			return false
		_comet_phase = CometPhase.DEPART
		_cenergy = 0.0
		_sync_comet_camera(true)
		ride_started.emit(RIDE_COMET)
		return true
	return false

## CH75 -- the Comet's camera is the CHASE, the karting's (the brief:
## "camera poursuite, comme le karting"), with the airborne tuning
## (HubCamera.ChaseTuning.coaster()): anchored on the cart, not on the
## ground under it. Asked for at most once per change, and the exit only
## for a chase this file opened.
func _sync_comet_camera(chase: bool) -> void:
	if chase == _comet_chase:
		return
	if _camera == null or not is_instance_valid(_camera):
		_comet_chase = chase
		return
	if chase:
		if not _camera.has_method("enter_drive"):
			return
		_camera.call("enter_drive", _comet_mount, HubCamera.ChaseTuning.coaster(_comet_cart))
		_comet_chase = true
		return
	if _camera.has_method("exit_drive"):
		_camera.call("exit_drive")
	_comet_chase = false

func is_comet_chasing() -> bool:
	return _comet_chase

## The brake: a held finger anywhere on the screen (touch emulates the
## mouse button, CLAUDE.md), or the probe's override.
func brake_held() -> bool:
	if _brake_override >= 0:
		return _brake_override == 1
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

## -1 reads the finger; 0 forces the brake off; 1 forces it on. For the
## bench only (FunfairProbe's positive control on the brake).
func set_brake_override(mode: int) -> void:
	_brake_override = mode

# =====================================================================
# THE RUNS

func _process(delta: float) -> void:
	if _coaster_phase != CoasterPhase.IDLE:
		_advance_coaster(delta)
	if _tower_phase != TowerPhase.IDLE:
		_advance_tower(delta)
	if _comet_phase != CometPhase.IDLE:
		_advance_comet(delta)

## CH75 -- the Comet's run: the CH71 chain and energy law (dh taken off
## the table, so the energy is exact whatever the frame), no player
## brake, and the two-stage run-out described at COMET_BRAKE_RUN_U.
func _advance_comet(delta: float) -> void:
	var s0: float = _cs
	match _comet_phase:
		CometPhase.DEPART:
			_cv = minf(LIFT_SPEED, _cv + LIFT_ACCEL * delta)
			if _cs >= _comet_lift_foot_s:
				_comet_phase = CometPhase.LIFT
		CometPhase.LIFT:
			_cv = LIFT_SPEED
			if _cs >= _comet_crest_s:
				_comet_phase = CometPhase.COAST
				_cenergy = 0.5 * _cv * _cv
		_:
			pass
	var s1: float = s0 + _cv * delta
	var run_start: float = _comet_length - COMET_BRAKE_RUN_U
	var turn_start: float = run_start + COMET_TRIM_U
	if _comet_phase == CometPhase.COAST:
		var h0: float = comet_point(s0).y
		var h1: float = comet_point(s1).y
		var ds: float = s1 - s0
		_cenergy += -GRAVITY * (h1 - h0) - ROLL_FRICTION * ds
		_cenergy = maxf(_cenergy, 0.5 * SPEED_FLOOR * SPEED_FLOOR)
		_cv = sqrt(2.0 * _cenergy)
		if s1 >= run_start:
			_comet_phase = CometPhase.TRIM
			_ctrim_entry_v = _cv
	if _comet_phase == CometPhase.TRIM:
		var u: float = clampf((s1 - run_start) / COMET_TRIM_U, 0.0, 1.0)
		_cv = lerpf(_ctrim_entry_v, COMET_TURN_SPEED, u)
		if s1 >= turn_start:
			_comet_phase = CometPhase.BRAKE
	if _comet_phase == CometPhase.BRAKE:
		var u: float = clampf((s1 - turn_start) / (COMET_BRAKE_RUN_U - COMET_TRIM_U), 0.0, 1.0)
		_cv = maxf(COMET_TURN_SPEED * sqrt(1.0 - u), 0.25)
		if s1 >= _comet_length:
			_park_comet()
			_comet_phase = CometPhase.IDLE
			if _keepy != null and _keepy.is_on_carrier():
				_keepy.follow_carrier()
			# The chase is released BEFORE the signal, the karting's
			# order: the listener steps the rider off under a camera
			# already blending home.
			_sync_comet_camera(false)
			ride_finished.emit(RIDE_COMET, COMET_STAND)
			return
	_cs = s1
	_pose_comet()
	if _keepy != null and _keepy.is_on_carrier():
		_keepy.follow_carrier()

func _advance_coaster(delta: float) -> void:
	var s0: float = _s
	match _coaster_phase:
		CoasterPhase.DEPART:
			_v = minf(LIFT_SPEED, _v + LIFT_ACCEL * delta)
			if _s >= _lift_foot_s:
				_coaster_phase = CoasterPhase.LIFT
		CoasterPhase.LIFT:
			_v = LIFT_SPEED
			if _s >= _crest_s:
				_coaster_phase = CoasterPhase.COAST
				_energy = 0.5 * _v * _v
		CoasterPhase.COAST:
			pass
		CoasterPhase.BRAKE:
			pass
	var s1: float = s0 + _v * delta
	if _coaster_phase == CoasterPhase.COAST:
		var h0: float = track_point(s0).y
		var h1: float = track_point(s1).y
		var ds: float = s1 - s0
		_energy += -GRAVITY * (h1 - h0) - ROLL_FRICTION * ds
		if brake_held():
			_energy -= BRAKE_DECEL * ds
		_energy = maxf(_energy, 0.5 * SPEED_FLOOR * SPEED_FLOOR)
		_v = sqrt(2.0 * _energy)
		if s1 >= _length - BRAKE_RUN_U:
			_coaster_phase = CoasterPhase.BRAKE
			_brake_entry_v = _v
	if _coaster_phase == CoasterPhase.BRAKE:
		var u: float = clampf((s1 - (_length - BRAKE_RUN_U)) / BRAKE_RUN_U, 0.0, 1.0)
		_v = maxf(_brake_entry_v * sqrt(1.0 - u), 0.25)
		if s1 >= _length:
			_park_cart()
			_coaster_phase = CoasterPhase.IDLE
			if _keepy != null and _keepy.is_on_carrier():
				_keepy.follow_carrier()
			ride_finished.emit(RIDE_COASTER, STATION_STAND)
			return
	_s = s1
	_pose_cart()
	if _keepy != null and _keepy.is_on_carrier():
		_keepy.follow_carrier()

func _advance_tower(delta: float) -> void:
	var rest: float = HubSurface.ground(TOWER_AT).y + GONDOLA_REST_Y
	var top: float = HubSurface.ground(TOWER_AT).y + GONDOLA_TOP_Y
	var brake_y: float = HubSurface.ground(TOWER_AT).y + gondola_brake_y()
	match _tower_phase:
		TowerPhase.RISE:
			_gv = gondola_rise_speed()
			_gy = minf(top, _gy + _gv * delta)
			if _gy >= top:
				_tower_phase = TowerPhase.HOLD
				_hold_left = GONDOLA_HOLD_S
				_gv = 0.0
		TowerPhase.HOLD:
			_hold_left -= delta
			if _hold_left <= 0.0:
				_tower_phase = TowerPhase.FALL
		TowerPhase.FALL:
			_gv -= GRAVITY * delta
			_gy += _gv * delta
			if _gy <= brake_y:
				_tower_phase = TowerPhase.BRAKE
				# The decel that stops it exactly at rest from HERE, with
				# the speed it actually has -- never the closed form alone.
				_brake_decel = (_gv * _gv) / (2.0 * maxf(_gy - rest, 0.05))
		TowerPhase.BRAKE:
			_gv = minf(0.0, _gv + _brake_decel * delta)
			_gy += _gv * delta
			if _gy <= rest or _gv >= -0.001:
				_gy = rest
				_gv = 0.0
				_tower_phase = TowerPhase.SETTLE
				_hold_left = GONDOLA_SETTLE_S
		TowerPhase.SETTLE:
			_hold_left -= delta
			if _hold_left <= 0.0:
				_tower_phase = TowerPhase.IDLE
				_place_gondola()
				if _keepy != null and _keepy.is_on_carrier():
					_keepy.follow_carrier()
				# The lift is dropped BEFORE the signal: a listener that
				# steps the rider off must not be handed a camera still
				# riding 13 u of tower. It is already ~0 here (the
				# gondola is back at rest), so this is not a cut.
				_push_camera_lift()
				ride_finished.emit(RIDE_TOWER, TOWER_STAND)
				return
	_place_gondola()
	_push_camera_lift()
	if _keepy != null and _keepy.is_on_carrier():
		_keepy.follow_carrier()
