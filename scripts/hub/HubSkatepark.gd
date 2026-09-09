extends Node3D
class_name HubSkatepark
## CH53 -- THE SKATEPARK OF THE NORTH LOBE, AND ITS LEDGER.
##
## =====================================================================
## WHAT THIS NODE IS, AND WHY IT IS NOT AN AUTOLOAD
##
## The shape is HubKarting's / HubCove's / HubTransport's: a Node3D under
## World, built in `_ready()`, references handed back by
## `HubWorld.setup(...)`, `footprints()` read by CozyScatter, one landing
## hook, one `cancel_intent()`.
##
## CH51 wrote the argument against an autoload and it is stronger here
## than it was for HubRouter: an autoload holding a SCORE would be
## reachable from Battle, Chased and Quizz -- the three screens WorldSave
## refuses to know anything about. The park emits points; the ledger
## decides what they are worth; neither is globally addressable.
##
## =====================================================================
## THE SCORE IS A PROXY, AND THIS FILE SAYS SO OUT LOUD
##
## ⚠️ CH51 section 3.2 argued the opposite of what is built here, and it
## was right about the mechanism: "un test « l'atterrissage est dans le
## disque du module » ne distingue pas « il a fait un air sur la rampe »
## de « il est retombé à côté d'elle »". CH43's doctrine is the general
## form -- a test on an observable value does not see which branch ran.
##
## Mathieu overrode it explicitly for this lot: no physics, no colliders,
## the landing proxy, and the real thing named as a deferred debt. So the
## proxy is what ships, and the honest consequence is written here rather
## than dressed up: THIS FILE CANNOT TELL A TRICK FROM A LANDING. What it
## scores is "he came down on the module, on the board", and every name
## it gives a trick (`air`, `grind`, `carve`, `ollie`) is a LABEL FOR THE
## MODULE, not a classification of anything he did.
##
## Two consequences are wired in because of it, and they are the only
## defence a proxy can have:
##
##   1. NOTHING SCORES ON FOOT. `note_landing` is handed the hopper and
##      refuses unless he is on the board. Without it, walking across
##      the park would farm, and CH51 measured that a park with no bound
##      out-earns the whole world's exploration.
##   2. THE SAME MODULE TWICE IN A ROW DOES NOT CHAIN. A chain needs a
##      different module, which is the cheapest possible stand-in for
##      "he did something else" and the only one a proxy can honestly
##      make.
##
## =====================================================================
## THE TABLE IS A LIST FROM THE FIRST ENTRY
##
## CLAUDE.md: the diving board was a generic geometry with a SINGLETON
## downstream, a second plank was drawn and never climbable, and undoing
## that cost its own lot. MODULES is an Array of Dictionaries with five
## entries on day one, and every reader indexes it.

## =====================================================================
## WHERE THE PARK STANDS
##
## The lobe CH50 built: centre HubRegion.skate_lobe_centre() = (0, 0, 35),
## radius SKATE_LOBE_RADIUS = 28, walkable to z = 63. The layout below
## sits in the middle of it, well inside the rim, for reasons that are
## each a measurement someone already paid for:
##
##   * NOT AGAINST THE RIM. CLAUDE.md: a structure centred on the edge of
##     the walkable world puts parts of itself beyond it, and every tap
##     behind it is folded back onto the border -- the zipline's north
##     tower overhung by 1.682 u and nobody was warned. Every module's
##     FOOTPRINT RIM (not its centre) is inside the lobe, tightest margin
##     3.09 u, so the region needs no new lobe and no hole.
##
## =====================================================================
## ⚠️ THE LAYOUT IS THE CAMERA'S, AND THE FIRST ONE WAS WRONG
##
## The first layout of this lot spread the five modules over x in
## [-7.5, +8.5], which is what a skatepark looks like on paper. RENDERED,
## it was unreadable, and the probe said so in a way no argument would
## have: from the walk-in, module screen x came back
## -755 / 639 / 1835 / behind / 13292 on a 1080-wide canvas -- ONE module
## in frame out of five, and three of them painting literally ZERO pixels.
##
## The arithmetic that decides it, and it is entirely CLAUDE.md's:
## HubCamera is KEEP_WIDTH with fov 45, so 45 deg is the HORIZONTAL angle
## and the half-angle is 22.5. The camera sits at the player's z + 8.9
## and never yaws, so it shows ONLY z below its own. A module at world z
## is therefore in frame from a player at z_p iff
##
##     |x| <= tan(22.5 deg) * (z_p + 8.9 - z)      and   z < z_p + 8.9
##
## which at the player's own z is +-3.69 u and NOT the "about 3 u" of a
## rule of thumb. Everything wider than that is off screen, and anything
## more than 8.9 u NORTH of him is behind the lens entirely.
##
## So the park is narrow (x in [-4.2, +5.0]) and long (z in [45.5, 55.5]),
## and it is meant to be ridden SOUTHWARD. Checked at five stations:
## 5 modules in frame from z = 58 and 60, 4 from z = 52 and 55, 2 from
## z = 48, 1 from the plateau side at z = 42.
##
##   * AND THE BOARD IS PARKED AT THE NORTH END BECAUSE OF THAT. A rider
##     who mounts at the south rides AWAY from the camera into a park
##     that is behind the lens; mounting at the north he rides toward it,
##     with the whole park in frame ahead of him. Same modules, same
##     camera, opposite reading -- see HubTransport.SKATE_PARK.
##   * THE WALK-IN IS STILL ONE MODULE, and that is ACCEPTED, not missed.
##     CH51 section 4.3 put the "the park will fill the frame from the
##     south" compromise to Mathieu explicitly and he took it
##     ("je ne le rediscute pas"). What this layout buys is that the
##     RIDING direction reads; the approach cannot, under a camera that
##     does not turn.
##   * NOT IN THE SPAWN'S FRAME. The park is 46 u north of the spawn,
##     where the 0.016 exponential haze has already eaten 52 % of it.
##
const PARK_CENTRE: Vector2 = Vector2(0.0, 50.0)

## The kinds. StringNames because they are compared, never displayed raw.
const KIND_QUARTERPIPE: StringName = &"quarterpipe"
const KIND_BOWL: StringName = &"bowl"
const KIND_RAIL: StringName = &"rail"
const KIND_FUNBOX: StringName = &"funbox"

## =====================================================================
## THE MODULES
##
## `at` is FLAT (x, z): the ground point is taken from HubSurface at build
## time and never spelled with a y here. CLAUDE.md: "un point sol s'écrit
## (x, h, z), et il a une seule orthographe" -- a literal 0.0 baseline in
## a file that writes a world position is exactly the literal a later lot
## forgets. The lobe is flat today; that is not a reason to write it down.
##
## `footprint` is what CozyScatter keeps clear around the piece: the
## module's own half-extent plus room to stand. `tap_radius` is unused by
## the modules themselves (they have no tap channel -- the BOARD does,
## through HubTransport's existing vehicle door) and is what
## `landed_within` scores on.
##
## HEIGHTS. All five are between 0.55 and 2.10 u. The ceiling that
## matters is not the frame's -- HubCamera.FRAME_TOP_AT_APLOMB is 7.968 u
## at the player's own aplomb, so nothing here is close to leaving the
## picture. It is OCCLUSION: a 2 u wall 5 u north of the player covers
## the ground behind it, and CLAUDE.md is explicit that this is a
## question of IMAGE and that only a render answers it. PHASE F renders
## it.
const MODULES: Array[Dictionary] = [
	{"kind": KIND_FUNBOX, "at": Vector2(0.0, 45.5), "yaw": 0.0,
		"size": Vector3(4.4, 0.85, 3.2), "footprint": 3.4, "tap_radius": 2.4,
		"trick": &"ollie", "points": 35},
	{"kind": KIND_RAIL, "at": Vector2(4.2, 48.5), "yaw": 0.30,
		"size": Vector3(0.4, 0.62, 6.0), "footprint": 3.4, "tap_radius": 2.4,
		"trick": &"grind", "points": 45},
	{"kind": KIND_QUARTERPIPE, "at": Vector2(-4.2, 50.5), "yaw": 0.0,
		"size": Vector3(7.0, 2.1, 2.1), "footprint": 4.2, "tap_radius": 2.6,
		"trick": &"air", "points": 60},
	{"kind": KIND_QUARTERPIPE, "at": Vector2(5.0, 54.0), "yaw": PI,
		"size": Vector3(6.0, 1.45, 1.45), "footprint": 4.0, "tap_radius": 2.4,
		"trick": &"air", "points": 45},
	{"kind": KIND_BOWL, "at": Vector2(-0.5, 55.5), "yaw": 0.0,
		"size": Vector3(7.2, 1.35, 7.2), "footprint": 4.4, "tap_radius": 3.0,
		"trick": &"carve", "points": 80},
]

## =====================================================================
## THE CHAIN
##
## A chain is consecutive scoring landings, each on a DIFFERENT module,
## no more than CHAIN_WINDOW_S apart. Anything else -- a landing on the
## grass, the same module twice, a pause -- ends it.
##
## 3.4 s is not a taste: an ordinary vehicle hop is
## KeepyHopper.VEHICLE_HOP_DURATION = 0.34 s and covers 2.7 u, and the
## widest gap between two module centres in the layout above is 10.1 u,
## i.e. four hops, i.e. 1.36 s of flight plus the tap that aims them.
## 3.4 s is that with room for a finger, and it is short enough that a
## chain cannot survive a walk across the park.
##
## CH54 re-derived it for the ROLL and kept it: the same 10.1 u under
## HubTransport's profile (run-up 3.2 u, cruise 10.0 u/s, run-out 3.2 u)
## takes ~1.5 s from rest to rest -- longer than the bounce's 1.36 s,
## still well inside 3.4 s with a finger. A walk across the park is
## slower than either and still cannot keep a chain alive.
const CHAIN_WINDOW_S: float = 3.4
## The multiplier a chain of n adds: 1 + CHAIN_STEP * n, capped. Capped
## because the ledger's guard is a STOCK (WorldSave.award_from_activity)
## and an uncapped multiplier would drain a session's stock in one run.
const CHAIN_STEP: float = 0.5
const CHAIN_MAX: int = 5

## Emitted for every scoring landing. `points` is what the module was
## worth AFTER the chain multiplier and BEFORE the ledger's guard; the
## HUD shows this, the ledger decides what it converts to.
##
## CH51: emitted by the module coordinator, never by a global -- Battle,
## Chased and Quizz cannot reach this node and that is the point.
signal trick_scored(module: int, trick: StringName, points: int, chain: int)
## Emitted when a chain ends, so the HUD can let go of it.
signal chain_broken()

var _keepy: KeepyHopper = null
var _nodes: Array[MeshInstance3D] = []
var _tris: int = 0
var _chain: int = 0
var _last_module: int = -1
var _last_at: float = -1000.0
## ⚠️ THE SIMULATION CLOCK, NOT THE WALL CLOCK. Under `--fixed-fps 60` a
## probe simulates far faster than real seconds pass, so a chain window
## measured with Time.get_ticks_msec() would be a different rule in a
## probe than it is on a phone -- CH52 PHASE T is this repo's standing
## reminder that a wall-clock reading and a simulated one are two
## different measurements. This accumulates the same delta the hops do.
var _clock: float = 0.0
var _session_points: int = 0
var _last_award: int = 0

func _ready() -> void:
	_build()

func _process(delta: float) -> void:
	_clock += delta

# =====================================================================
# BUILD

func _build() -> void:
	var concrete := CozyPalette.concrete_material()
	for index in MODULES.size():
		var spec: Dictionary = MODULES[index]
		var builder := SkateparkMesh.new()
		var mesh: ArrayMesh = _mesh_for(builder, spec)
		var node := MeshInstance3D.new()
		node.name = "Skate_%s_%d" % [String(spec["kind"]), index]
		node.mesh = mesh
		node.set_surface_override_material(0, concrete)
		# ⚠️ ROTATION AND TRANSLATION, NEVER SCALE. CLAUDE.md, and it is
		# the reason every module is authored at its final size in
		# SkateparkMesh rather than built once and scaled: a scaled
		# carrier multiplies every choreography constant that crosses
		# to_global() by itself, silently.
		node.position = HubSurface.ground(Vector3(spec["at"].x, 0.0, spec["at"].y))
		node.rotation.y = float(spec["yaw"])
		add_child(node)
		_nodes.append(node)
		_tris += builder.triangle_count()
		_maybe_collide(node, index, spec)
	# THE SITE MARKER, and it goes on a node that is AT the site. CH46
	# pinned seven NPC markers on (0, 0, 0) because `mark(self)` was
	# called in a file where `self` is a controller that never moves from
	# the world origin -- this node is exactly such a controller, so the
	# marker goes on a child placed at the park's centre.
	var site := Node3D.new()
	site.name = "SkateparkSite"
	site.position = HubSurface.ground(Vector3(PARK_CENTRE.x, 0.0, PARK_CENTRE.y))
	MinimapMarkers.mark(site, MinimapMarkers.PLACE)
	add_child(site)

## =====================================================================
## CH57 LOT 1 / CH60 LOT 3a -- FOUR MODULES OF FIVE BECOME SOLID
##
## Behind DevTools.physics_enabled(), which is OFF for every player and
## OFF in every existing probe (see DevTools). With the switch down
## `_maybe_collide` returns on its first line and the park is
## byte-for-byte the one CH53 shipped.
##
## CH57 made the FUNBOX solid and said why it was alone: a box between
## two wedges is three exactly convex pieces, so its collider could be
## proved right by looking at it. CH60 adds the RAIL (three boxes, the
## same argument) and the TWO QUARTERPIPES (genuinely concave, twelve
## exact pieces each -- the argument is in SkateparkMesh).
##
## ⚠️ THE BOWL IS STILL OUT, AND IT IS THE SAME REASON, NOT INERTIA.
## CH56 section 12.4: "un bol decompose en hulls convexes est
## GEOMETRIQUEMENT FAUX -- une cuvette ouverte devient un tas de solides
## pleins", and CH56 measured that decomposition's COST without ever
## checking its correctness. It gets lot 3b. `pieces_for()` returns EMPTY
## for it, so the perimeter is a published fact and not a list of names a
## reader has to keep.
##
## THE SHAPE IS A CHILD OF THE DRAWN NODE, so it inherits the module's
## own position and yaw and cannot drift from what the player sees. There
## is no second spelling of where a module is -- CLAUDE.md's most
## expensive recurring defect, and the one `module_centre()` above
## already exists to avoid. CH60 closed the second half of the same hole:
## the builder ARGUMENTS are published by `build_args()` and read by both
## the mesh and the pieces.
##
## A collider draws NOTHING. CH56 verdict point 3: zero primitives, zero
## draw calls, which is exactly the currency CH52 measured none of at the
## north rim. SkatePhysicsProbe PHASE B gates that at the five stations
## CH53 published.
## Module index -> the StaticBody3D it carries. A TABLE from the first
## commit even when CH57 filled it with one row: CLAUDE.md's diving-board
## lesson is that a generic geometry with a SINGLETON downstream costs its
## own lot to undo, and CH60 is exactly the lot that would have paid it.
var _bodies: Dictionary = {}

## =====================================================================
## CH60 LOT 3a -- THE BUILDER'S ARGUMENTS, SPELLED ONCE
##
## CH57 wrote `funbox_pieces(size.x, size.z * 0.55, size.y, size.z * 0.45)`
## into `_maybe_collide` with a comment asking the reader to keep it in
## step with `_mesh_for`'s identical expression. That is a second
## SPELLING of one fact, which is this repo's most expensive recurring
## defect, and a comment is not a gate. Three modules would have made it
## three pairs.
##
## So the arguments are published HERE, once, and both the mesh builder
## and the piece builder consume them. Neither can drift from the other
## because neither owns them.
static func build_args(spec: Dictionary) -> Array:
	var size: Vector3 = spec["size"]
	match StringName(spec["kind"]):
		KIND_QUARTERPIPE:
			return [size.x, size.y]
		KIND_RAIL:
			return [size.z, size.y]
		KIND_FUNBOX:
			return [size.x, size.z * 0.55, size.y, size.z * 0.45]
		KIND_BOWL:
			return [size.x * 0.5, size.y]
	return []

## The convex pieces a module's collider is made of, or EMPTY for a module
## this chantier has not made solid yet.
##
## ⚠️ THE BOWL RETURNS EMPTY, AND THAT IS THE PERIMETER OF THIS LOT SAID
## IN CODE RATHER THAN IN A COMMENT. CH56 section 12.4: "un bol decompose
## en hulls convexes est GEOMETRIQUEMENT FAUX -- une cuvette ouverte
## devient un tas de solides pleins", and CH56 priced that decomposition
## without ever checking whether it was right. A dish is the one module
## here whose pieces cannot be read off the drawn mesh by eye, so it gets
## its own lot (3b) rather than a guess inside this one. A reader asking
## "which modules are solid" asks THIS, never a list of kinds.
static func pieces_for(spec: Dictionary) -> Array:
	var a: Array = build_args(spec)
	match StringName(spec["kind"]):
		KIND_QUARTERPIPE:
			return SkateparkMesh.quarterpipe_pieces(a[0], a[1])
		KIND_RAIL:
			return SkateparkMesh.rail_pieces(a[0], a[1])
		KIND_FUNBOX:
			return SkateparkMesh.funbox_pieces(a[0], a[1], a[2], a[3])
	return []

func _maybe_collide(node: MeshInstance3D, index: int, spec: Dictionary) -> void:
	if not DevTools.physics_enabled():
		return
	var pieces: Array = pieces_for(spec)
	if pieces.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "%sCollider" % String(spec["kind"]).capitalize()
	body.collision_layer = 1 << (SkateBoardBody.LAYER_PARK - 1)
	# Masks NOTHING: a static body that scans for others is paying
	# broadphase for a question nobody asks. It is asked ABOUT, never asks.
	body.collision_mask = 0
	for piece in pieces:
		var hull := ConvexPolygonShape3D.new()
		hull.points = piece
		var shape := CollisionShape3D.new()
		shape.shape = hull
		body.add_child(shape)
	node.add_child(body)
	_bodies[index] = body

## Which entries of MODULES carry a collider, ascending. Published rather
## than grepped for by kind: CLAUDE.md, "le producteur publie ce qu'il a
## construit ; le lecteur ne le reconnait jamais" -- a reader that looked
## for the solid modules by name would be wrong the day a fifth is laid,
## and CH60 is the lot where that day arrived.
func collider_indices() -> Array:
	var out: Array = _bodies.keys()
	out.sort()
	return out

func collider_body_at(index: int) -> StaticBody3D:
	return _bodies.get(index, null)

## How many convex pieces a module's collider actually holds, counted off
## the TREE rather than off the table that asked for them.
func collider_piece_count_at(index: int) -> int:
	var body: StaticBody3D = _bodies.get(index, null)
	return 0 if body == null else body.get_child_count()

func _mesh_for(builder: SkateparkMesh, spec: Dictionary) -> ArrayMesh:
	var a: Array = build_args(spec)
	match StringName(spec["kind"]):
		KIND_QUARTERPIPE:
			return builder.quarterpipe(a[0], a[1])
		KIND_RAIL:
			return builder.rail(a[0], a[1])
		KIND_FUNBOX:
			return builder.funbox(a[0], a[1], a[2], a[3])
		KIND_BOWL:
			return builder.bowl(a[0], a[1])
	push_error("HubSkatepark: unknown module kind '%s'." % spec["kind"])
	return builder.rail(1.0, 0.5)

## Hands the park what it needs to refuse a score. Called by HubWorld,
## the coordinator shape every module in this hub uses.
func setup(keepy: KeepyHopper) -> void:
	_keepy = keepy

# =====================================================================
# WHAT THE PARK PUBLISHES -- read by everyone, retyped by nobody

## STATIC, because CozyScatter asks the CLASS: it sows the ground cover
## from its own `_ready()` and cannot depend on this node having been
## built first. Same contract as HubTransport.footprints(),
## HubCove.footprints() and HubTrees.footprints().
static func footprints() -> Array:
	var out: Array = []
	for spec in MODULES:
		out.append({"position": Vector3(spec["at"].x, 0.0, spec["at"].y),
			"radius": float(spec["footprint"])})
	return out

func module_count() -> int:
	return MODULES.size()

## The module's ground centre, from the node actually built -- not from
## the table. CLAUDE.md: a fact is published once, and the fact here is
## where the piece IS, which is the node's own transform.
func module_centre(index: int) -> Vector3:
	if index < 0 or index >= _nodes.size():
		return Vector3.INF
	var p := _nodes[index].global_position
	return Vector3(p.x, 0.0, p.z)

func module_kind(index: int) -> StringName:
	if index < 0 or index >= MODULES.size():
		return &""
	return StringName(MODULES[index]["kind"])

func module_node(index: int) -> MeshInstance3D:
	if index < 0 or index >= _nodes.size():
		return null
	return _nodes[index]

## Every drawn node of the park -- what a budget probe hides to weigh it.
## PUBLISHED by the builder, never reconstructed by the reader: CLAUDE.md
## made that rule after an exclusion list was wrong at the first name
## somebody forgot ("Butterflies" against a node called "Butterflies1").
func module_nodes() -> Array[MeshInstance3D]:
	return _nodes.duplicate()

## Triangles the park actually laid down, COUNTED at build time from the
## index buffers. Gated against SkateparkMesh.BUDGET_TRIS by the probe.
func triangle_total() -> int:
	return _tris

func combo() -> int:
	return _chain

func session_points() -> int:
	return _session_points

## What the ledger credited for the last scoring landing (0 when the
## guard bit). Read by the HUD so it can say "the trick counted but the
## park is out of nuts" without re-deriving the rule -- CH51's reason for
## award_from_activity returning what it actually granted.
func last_award() -> int:
	return _last_award

# =====================================================================
# THE LANDING

## Which module a landing at `point` is on, or -1. HubPortal's exact
## shape: a flat distance to a centre, asked on a LANDING and never on a
## body entering an area -- a hop passes through an Area3D in mid-air.
func landed_within(point: Vector3) -> int:
	var flat := Vector2(point.x, point.z)
	var best: int = -1
	var best_d: float = 1e20
	for index in MODULES.size():
		var centre := module_centre(index)
		if centre == Vector3.INF:
			continue
		var d := flat.distance_to(Vector2(centre.x, centre.z))
		if d <= float(MODULES[index]["tap_radius"]) and d < best_d:
			best_d = d
			best = index
	return best

## Called by HubWorld on every ordinary landing. Returns true when the
## landing scored.
##
## ⚠️ ON THE BOARD OR NOTHING. See the header: the proxy has no way to
## tell a trick from a walk, so the only thing standing between this and
## a farm is that walking does not score.
func note_landing(point: Vector3) -> bool:
	if _keepy == null or not _keepy.is_on_vehicle():
		_break_chain()
		return false
	# CH54: the board ROLLS, in 1.6 u segments, and every segment end is a
	# `hop_landed`. A roll across the bowl would otherwise land in its
	# disc four times -- four "carves" for one pass, and every grass
	# segment between two modules would break the chain. Only the landing
	# that ENDS a roll counts: he rode onto the module and stopped there.
	# A landing in passing is neither a score nor a break; it is not a
	# landing at all, it is the middle of a roll.
	if _keepy.is_gliding() and _keepy.roll_remaining() > KeepyHopper.ARRIVE_EPSILON:
		return false
	var index := landed_within(point)
	if index < 0:
		_break_chain()
		return false
	var now := _clock
	var chained: bool = _chain > 0 or _last_module >= 0
	if index == _last_module or now - _last_at > CHAIN_WINDOW_S:
		# The same module twice, or too slow: this landing starts a chain
		# rather than continuing one.
		chained = false
	_chain = mini(_chain + 1, CHAIN_MAX) if chained else 0
	_last_module = index
	_last_at = now
	var base: int = int(MODULES[index]["points"])
	var points: int = int(round(float(base) * (1.0 + CHAIN_STEP * float(_chain))))
	_session_points += points
	_last_award = WorldSave.award_from_activity(&"skate", points)
	WorldSave.note("skate_tricks")
	WorldSave.note_max("skate_best_combo", _chain)
	trick_scored.emit(index, StringName(MODULES[index]["trick"]), points, _chain)
	return true

func _break_chain() -> void:
	if _chain == 0 and _last_module < 0:
		return
	_chain = 0
	_last_module = -1
	chain_broken.emit()

## The coordinator contract every module in this hub carries. The park
## holds no walk intent of its own (the BOARD is the thing you tap, and
## HubTransport owns that door), so this only lets the chain go.
func cancel_intent() -> void:
	_break_chain()
