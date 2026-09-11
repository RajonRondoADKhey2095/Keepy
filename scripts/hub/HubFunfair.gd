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
const TOWER_HEIGHT: float = 6.6
const TOWER_HALF_SPAN: float = 1.0
const TOWER_LEG_THICK: float = 0.16
const TOWER_MAST_THICK: float = 0.22
const TOWER_BASE: Vector3 = Vector3(2.6, 0.30, 2.6)
const TOWER_BRACE_THICK: float = 0.07
const TOWER_BRACE_LEVELS: Array = [2.2, 4.2, 6.2]
const TOWER_CAP: Vector3 = Vector3(2.4, 0.25, 2.4)
const GONDOLA_REST_Y: float = 0.45
const GONDOLA_TOP_Y: float = 5.10
const GONDOLA_RISE_SPEED: float = 0.9
const GONDOLA_HOLD_S: float = 1.6
## Where the magnetic brake begins on the way down; the decel that stops
## the gondola at GONDOLA_REST_Y from the speed it reaches there is
## DERIVED (published by tower_brake_decel()), never typed.
const GONDOLA_BRAKE_Y: float = 1.6
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

func setup(keepy: KeepyHopper) -> void:
	_keepy = keepy

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

## The frame at `s`: columns (right, up, forward), origin on the rail top.
func track_frame(s: float) -> Transform3D:
	var p: Vector3 = track_point(s)
	var t: Vector3 = track_tangent(s)
	var right: Vector3 = t.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(t).normalized()
	return Transform3D(Basis(right, up, t), p)

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
	for li in TOWER_BRACE_LEVELS.size():
		var y: float = float(TOWER_BRACE_LEVELS[li])
		var below: float = float(TOWER_BRACE_LEVELS[li - 1]) if li > 0 else base_top
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
	var p: Vector3 = track_point(_s)
	var t: Vector3 = track_tangent(_s)
	_cart.global_transform = Transform3D(Basis.looking_at(t, Vector3.UP), p)

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

## The decel the magnetic brake needs, DERIVED from the fall: the speed
## reached at GONDOLA_BRAKE_Y after a free fall from GONDOLA_TOP_Y, shed
## over the last GONDOLA_BRAKE_Y - GONDOLA_REST_Y units.
static func tower_brake_decel() -> float:
	var v2: float = 2.0 * GRAVITY * (GONDOLA_TOP_Y - GONDOLA_BRAKE_Y)
	return v2 / (2.0 * (GONDOLA_BRAKE_Y - GONDOLA_REST_Y))

func is_riding() -> bool:
	return _coaster_phase != CoasterPhase.IDLE or _tower_phase != TowerPhase.IDLE

## The stand point of a ride, flat.
static func stand_point(ride: int) -> Vector3:
	return STATION_STAND if ride == RIDE_COASTER else TOWER_STAND

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
	var brake_y: float = HubSurface.ground(TOWER_AT).y + GONDOLA_BRAKE_Y
	match _tower_phase:
		TowerPhase.RISE:
			_gv = GONDOLA_RISE_SPEED
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
				ride_finished.emit(RIDE_TOWER, TOWER_STAND)
				return
	_place_gondola()
	if _keepy != null and _keepy.is_on_carrier():
		_keepy.follow_carrier()
