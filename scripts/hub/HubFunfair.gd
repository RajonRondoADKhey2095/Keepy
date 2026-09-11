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

## The two rides, by index -- a TABLE from the first entry.
const RIDE_COASTER: int = 0
const RIDE_TOWER: int = 1

enum CoasterPhase { IDLE, DEPART, LIFT, COAST, BRAKE }
enum TowerPhase { IDLE, RISE, HOLD, FALL, BRAKE, SETTLE }

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

func _ready() -> void:
	_build_curve()
	_build()

func setup(keepy: KeepyHopper, camera: Node = null) -> void:
	_keepy = keepy
	_camera = camera

# =====================================================================
# THE CURVE

func _build_curve() -> void:
	_curve = Curve3D.new()
	_curve.bake_interval = TRACK_BAKE_INTERVAL
	var n: int = TRACK_POINTS.size()
	for i in n + 1:
		var k: int = i % n
		var prev: Vector3 = TRACK_POINTS[(k - 1 + n) % n]
		var next: Vector3 = TRACK_POINTS[(k + 1) % n]
		var handle: Vector3 = (next - prev) * TRACK_TENSION * 0.5
		_curve.add_point(TRACK_POINTS[k], -handle, handle)
	_length = _curve.get_baked_length()
	# The crest and the lift foot are MEASURED off the baked curve.
	_peak_y = -INF
	var s: float = 0.0
	while s < _length:
		var p: Vector3 = _curve.sample_baked(s, true)
		if p.y > _peak_y:
			_peak_y = p.y
			_crest_s = s
		s += 0.05
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
	return _curve.sample_baked(fposmod(s, _length), true)

func track_tangent(s: float) -> Vector3:
	var a: Vector3 = track_point(s - 0.05)
	var b: Vector3 = track_point(s + 0.05)
	return (b - a).normalized()

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
	var p: Vector3 = track_point(s)
	var t: Vector3 = track_tangent(s)
	var right: Vector3 = t.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(t).normalized()
	return Transform3D(Basis(right, up, t), p)

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
	var t: Vector3 = track_tangent(s)
	var right: Vector3 = Vector3.UP.cross(t)
	# A rail that ever ran dead vertical would make UP x t degenerate.
	# This one does not (its steepest section is 37.6 deg), but a guard
	# costs a branch and a silent NaN pose costs a lot more.
	if right.length_squared() < 0.000001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up: Vector3 = t.cross(right).normalized()
	return Transform3D(Basis(right, up, t), track_point(s))

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
	_footprint_cache = out
	return out

static func _static_curve() -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = TRACK_BAKE_INTERVAL
	var n: int = TRACK_POINTS.size()
	for i in n + 1:
		var k: int = i % n
		var prev: Vector3 = TRACK_POINTS[(k - 1 + n) % n]
		var next: Vector3 = TRACK_POINTS[(k + 1) % n]
		var handle: Vector3 = (next - prev) * TRACK_TENSION * 0.5
		curve.add_point(TRACK_POINTS[k], -handle, handle)
	return curve

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
	return _coaster_phase != CoasterPhase.IDLE or _tower_phase != TowerPhase.IDLE

## The stand point of a ride, flat.
static func stand_point(ride: int) -> Vector3:
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
	return false

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
