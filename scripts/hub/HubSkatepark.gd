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
## CH82.
const KIND_LEDGE: StringName = &"ledge"

## =====================================================================
## ⚠️ CH82 -- THE PARK HAS A DIRECTION, AND IT IS NOW WRITTEN DOWN
##
## The header above has said since CH53 that the park "is meant to be
## ridden SOUTHWARD" and that the board is parked at the north end
## BECAUSE of that. It was a sentence in a comment; three lots later a
## layout lot needed it as a VALUE -- every module this lot adds is laid
## along it, and SkateGrindProbe gates that they are.
##
## It is also the axis the auto-grind is built on. `SkateBoardBody`
## catches a board only when it is travelling roughly ALONG a grind line
## (GRIND_ALIGN_COS), which is what keeps a rider CROSSING the park from
## being snatched onto a rail he was only passing -- SkatePhysicsProbe
## PHASE J2's contract, unchanged, and now protected by the flow rather
## than by luck. A park whose obstacles all point one way is therefore
## not a styling choice here: it is what makes the magnetism legible.
const FLOW: Vector2 = Vector2(0.0, -1.0)

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
	# =================================================================
	# ⚠️ CH69 -- THE BOWL MOVED, AND THE SWEEP CHOSE THE PLACE
	#
	# CH53 stood it at (-0.5, 55.5), where its ring cut 0.693 u into the
	# big quarterpipe's east lip and 0.685 u into the small one's west
	# foot (CH66 measured 968 and 140 shared samples; CH68 reproduced the
	# two distances at 2.907 and 2.915 u). That is why it shipped without
	# a collider for three chantiers.
	#
	# The place below is the MINIMUM-CONCRETE solution of a sweep over
	# 19 865 candidates against six constraints at once: zero overlap, a
	# DECK LENGTH of clearance from every solid, the board's parking
	# footprint at (3, 60), the big quarterpipe's landing at
	# (-4.20, 57.58), HubRegion on all 36 rim points, and the rim on the
	# slab within CH68's 0.100 u (the overhang the delivered bowl already
	# had -- a threshold that condemns the shipped state proves nothing).
	# It clears the funbox by 0.950 u and costs 0.40 u of concrete.
	#
	# ⚠️ AND A SEVENTH CONSTRAINT ARRIVED FROM A PROBE, NOT FROM THE
	# SWEEP. `landed_within` picks the nearest module whose `tap_radius`
	# covers a landing, so two scoring discs that overlap make a strip of
	# ground where WHICH module you scored is an accident of a centimetre
	# -- SkateparkProbe G5 gates it, and it caught this lot's first answer
	# (-6.75, 45.75) at -0.209 u against the big quarterpipe. Re-swept with
	# the discs held KeepyHopper.ARRIVE_EPSILON apart (the distance a roll
	# ends within, so two discs are never closer than the precision of the
	# landing itself), the minimum moved 0.75 u south to here, for the same
	# 0.40 u of concrete and a disc gap of 0.462 u. The intermediate
	# answer, (-6.75, 45.50), was disjoint by THIRTEEN MILLIMETRES: a gate
	# standing at its own limit, which is not a gate.
	#
	# ⚠️ AND THE PARK'S NORTH HALF WAS MEASURED, NOT ASSUMED AWAY. Keeping
	# the bowl at z >= 50 is possible -- (-8.75, 57.00), 0.924 u of
	# clearance -- but it costs 73.88 u2 of slab (20.5 %) and lands the
	# bowl 8.75 u off the park's axis, where HubCamera can show it from
	# 2 of 133 standing stations against 29 for the place below. The
	# camera arithmetic in this file's header is what decides that: the
	# frame is +-3.69 u wide at the player's own z, so a wide module only
	# reads from far SOUTH of the player, and there is no far south left
	# north of the ramps.
	#
	# `rollin_aim` is where the rider comes FROM: the mouth of the
	# roll-in is centred on the bearing to it, so the door faces the gap
	# between the funbox and the big quarterpipe that a board coming down
	# from the parking actually threads. It is a POINT and not a sector
	# index because an index would have to be re-derived by hand the day
	# the bowl moves again.
	{"kind": KIND_BOWL, "at": Vector2(-6.75, 45.0), "yaw": 0.0,
		"size": Vector3(7.2, 1.35, 7.2), "footprint": 4.4, "tap_radius": 3.0,
		"rollin_aim": Vector2(0.0, 50.0),
		"trick": &"carve", "points": 80},
	# =================================================================
	# ⚠️ CH82 -- THE STREET SECTION, AND IT IS APPENDED AND NEVER
	# INSERTED
	#
	# Six files index this table by NUMBER (SkatePhysicsProbe's RIDES,
	# PhysicsCostProbe's MODULES[4], SkateInertiaProbe's two lips,
	# SkateDismountProbe's funbox, SkateAirProbe's two ramps). An insert
	# would move every one of them silently, so the three below are
	# indices 5, 6 and 7 and the five above keep theirs.
	#
	# WHERE. South of the five, on the slab this lot grows to meet them,
	# on ground a recon measured EMPTY: inside x [-16, 16] and
	# z [22, 46] the only published footprints in the whole hub are the
	# funbox's and the bowl's own. Nothing was moved to make room.
	#
	# THE FLOW. All three carry yaw 0.0, i.e. long on Z, i.e. along
	# `FLOW`. The rider comes off the funbox heading south and meets
	# them in sequence; the camera never yaws and shows only z below its
	# own, so content laid SOUTH of the park is content ahead of him
	# (CH53's arithmetic, re-measured for this lot: from z = 46 the
	# frame is 7.00 u half-wide at z = 38 and 8.24 at z = 35).
	#
	# ⚠️ THE RAIL AT INDEX 1 KEEPS ITS 0.30 rad, and that is a decision
	# and not an oversight. It stands 17.19 deg off `FLOW` -- measured,
	# not read off the constant -- which is inside the 40 deg the catch
	# allows, so it grinds from a straight southward run like the three
	# below. Turning it would move a module three chantiers have
	# measured stations against, to buy an alignment the catch does not
	# need.
	#
	# HEIGHTS. 0.30, 0.45, 0.62: a curb, a ledge, a block. The tallest
	# is the rail's own authored height, so the park's grind lines span
	# the reachable band rather than clustering. Every one of them is
	# under SkateBoardBody.GRIND_CATCH_DROP with margin -- gated, and
	# printed, by SkateGrindProbe PHASE C.
	#
	# TAP RADIUS 1.8 and not the 2.4 the ramps carry: a scoring disc is
	# what `landed_within` picks a module by, and two overlapping discs
	# make a strip of ground where WHICH module you scored is an
	# accident of a centimetre (CH69's seventh constraint, gated by
	# SkateparkProbe G5). A long thin block has no business claiming a
	# ramp's disc, and 1.8 keeps the tightest pair -- this first one
	# against the funbox -- 0.46 u apart.
	# ⚠️ AND THE FIRST ONE IS LAID ON THE RAIL'S OWN LINE, ON PURPOSE.
	# Measured: the rail's south end stands at (3.313, 45.634) and its
	# line prolonged south passes x = 3.30 at z = 45. A ledge at x = 3.4
	# is therefore where a rider who has just ground the rail southward
	# ARRIVES, and the two catch volumes are 1.44 u apart at the join --
	# far enough that neither steals the other (GRIND_CATCH_R is 0.46),
	# close enough that the rail LINKS into it. That link is the whole of
	# what "un seul sens de parcours" buys, and it is the reason these
	# three are a line and not a scatter.
	{"kind": KIND_LEDGE, "at": Vector2(3.4, 41.6), "yaw": 0.0,
		"size": Vector3(0.55, 0.30, 5.2), "footprint": 3.0, "tap_radius": 1.8,
		"trick": &"grind", "points": 35},
	{"kind": KIND_LEDGE, "at": Vector2(1.0, 38.0), "yaw": 0.0,
		"size": Vector3(0.55, 0.45, 4.4), "footprint": 2.6, "tap_radius": 1.8,
		"trick": &"grind", "points": 40},
	{"kind": KIND_LEDGE, "at": Vector2(-1.8, 34.4), "yaw": 0.0,
		"size": Vector3(0.55, 0.62, 3.4), "footprint": 2.1, "tap_radius": 1.8,
		"trick": &"grind", "points": 45},
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

## =====================================================================
## CH64 / CH69 -- THE SLAB, AND WHY IT IS A RECTANGLE WITH CORNERS
##
## The concrete the park stands on. CH64 wrote it as a WIDTH and a DEPTH
## centred on PARK_CENTRE, which is the right shape for a pad nobody has
## to grow. CH69 had to grow it on ONE side, and a size centred on a
## point cannot do that without moving the park: extending 0.25 u to the
## west by widening to 20.5 would have put a matching 0.25 u of concrete
## on the east that nothing asked for and that the scatter would have
## cleared for no reason.
##
## So the slab is its two CORNERS, and the width, the depth and the
## centre are read off them. Nothing else in the file knows a slab
## dimension: `footprints()` and the build both go through the accessors.
##
## ⚠️ WHAT CH69 BOUGHT WITH 0.40 u OF CONCRETE, and the number is the
## sweep's, not a taste. With the slab as CH64 left it there IS a legal
## place for the bowl (zero overlap, rim on the concrete, scoring discs
## apart): (-6.25, 44.75), and it clears the funbox by 0.450 u. Half a
## metre between two solids is a gap a 0.92 u deck cannot turn in.
## Moving the west edge from -10.00 to -10.40 -- 7.20 u2, 2 % more
## concrete -- moves the best position to (-6.75, 45.00) and the gap to
## 0.950 u, i.e. one deck length, which is the floor every other gap in
## this park is measured against.
##
## ⚠️ AND THE RIM IS ON THE CONCRETE WITH ROOM, NOT INSIDE A TOLERANCE.
## CH68 had to set its slab threshold at 0.100 u because the delivered
## bowl already overhung by exactly that much, and a threshold that
## condemns the shipped state proves nothing. Once the slab is the LEVER
## that tolerance is not needed: the rim's westmost point is -10.35
## against a kerb at -10.40, so the gate reads "every module's concrete
## is ON the slab" with 0.05 u to spare. SkatePhysicsProbe PHASE X
## measures it -- until CH69 nothing in the repo read a slab dimension at
## all, and a constant nothing reads is a constant that outlives its lot.
## ⚠️ CH82 -- THE SOUTH EDGE MOVES FROM 41.0 TO 32.0, AND THE CORNERS
## ARE WHY THAT IS ONE NUMBER AND NOT A RELAYOUT. CH69 turned the slab
## from a centred size into its two corners precisely so a later lot
## could grow it on ONE side; this is that lot. The north edge, the two
## sides and every one of the five modules CH69 placed are untouched --
## `slab_centre()` moves, and nothing reads it but the build and the
## footprint.
##
## 32.0 and not less: the southmost module's concrete ends at z = 32.70
## (index 7, half-length 1.70 about z = 34.4), so the kerb clears it by
## 0.70 u. SkatePhysicsProbe PHASE X prints that margin and gates it.
const SLAB_MIN: Vector2 = Vector2(-10.40, 32.0)
const SLAB_MAX: Vector2 = Vector2(10.0, 59.0)
const SLAB_WIDTH: float = SLAB_MAX.x - SLAB_MIN.x
const SLAB_DEPTH: float = SLAB_MAX.y - SLAB_MIN.y

## The slab's own middle, which is NOT PARK_CENTRE any more: the site
## marker, the module layout and the camera arithmetic are all written
## against PARK_CENTRE and none of them moves when the concrete grows.
static func slab_centre() -> Vector2:
	return (SLAB_MIN + SLAB_MAX) * 0.5
var _slab: MeshInstance3D = null
var _slab_tris: int = 0

func _build() -> void:
	# CH64: the park's own concrete (grain, smooth diffuse, baked shading
	# in the vertices) -- not the hub's toon concrete.
	var concrete := CozyPalette.skate_concrete_material()
	var slab_builder := SkateparkMesh.new()
	_slab = MeshInstance3D.new()
	_slab.name = "SkateparkSlab"
	_slab.mesh = slab_builder.slab(SLAB_WIDTH, SLAB_DEPTH)
	_slab.set_surface_override_material(0, concrete)
	_slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_slab.position = HubSurface.ground(Vector3(slab_centre().x, 0.0, slab_centre().y))
	add_child(_slab)
	_slab_tris = slab_builder.triangle_count()
	for index in MODULES.size():
		var spec: Dictionary = MODULES[index]
		var builder := SkateparkMesh.new()
		var mesh: ArrayMesh = _mesh_for(builder, spec)
		var node := MeshInstance3D.new()
		node.name = "Skate_%s_%d" % [String(spec["kind"]), index]
		node.mesh = mesh
		node.set_surface_override_material(0, concrete)
		# CH64: the decor surface (coping, steel), same material -- one
		# more draw call on the modules that carry any.
		if mesh.get_surface_count() > 1:
			node.set_surface_override_material(1, concrete)
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
## CH57 LOT 1 / CH60 LOT 3a / CH69 -- ALL FIVE MODULES ARE SOLID
##
## CH64: UNCONDITIONAL. CH57 put this behind DevTools.physics_enabled()
## for the A/B that measured F; the A/B is done and the switch is gone,
## so every player's park is solid. What a collider costs when nobody
## rides is measured, not assumed -- SkatePhysicsProbe PHASE I.
##
## CH57 made the FUNBOX solid and said why it was alone: a box between
## two wedges is three exactly convex pieces, so its collider could be
## proved right by looking at it. CH60 adds the RAIL (three boxes, the
## same argument) and the TWO QUARTERPIPES (genuinely concave, twelve
## exact pieces each -- the argument is in SkateparkMesh).
##
## ⚠️ CH69 ADDS THE BOWL, AND IT TOOK A LAYOUT LOT AND NOT A GEOMETRY
## ONE. CH56 section 12.4 refused it on the tool's behalf; CH66 wrote the
## exact ring and rode it on a TEMPORARY body, then left it unwired
## because where it stood it cut into both quarterpipes and had no ground
## entry. CH69 moved it (the sweep in MODULES), grew the slab 0.25 u
## under it and cut a roll-in through its wall, and this is where the
## 105 hulls now land. `pieces_for()` is still the published perimeter
## and PHASE X still gates it on the overlap measurement, not on a name.
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
		KIND_LEDGE:
			return [size.z, size.y, size.x]
		KIND_BOWL:
			return [size.x * 0.5, size.y, bowl_gate_first(spec), SkateparkMesh.BOWL_GATE_SECTORS]
	return []

## =====================================================================
## CH69 -- WHICH SECTORS THE ROLL-IN OPENS, DERIVED AND NOT TYPED
##
## The mouth is centred on the bearing from the bowl to `rollin_aim`,
## taken IN THE MODULE'S OWN FRAME (the node carries the yaw, so a bowl
## that were ever turned would turn its door with it). Published here
## because both the mesh and the pieces need it and neither may own it --
## the same reason `build_args` exists at all.
static func bowl_gate_first(spec: Dictionary) -> int:
	var aim: Vector2 = spec.get("rollin_aim", Vector2.ZERO)
	var d: Vector2 = aim - (spec["at"] as Vector2)
	var yaw: float = float(spec["yaw"])
	# World -> local. A node at rotation.y = yaw maps local (x, z) to
	# world (x cos + z sin, -x sin + z cos); this is its inverse.
	var l := Vector2(d.x * cos(yaw) - d.y * sin(yaw), d.x * sin(yaw) + d.y * cos(yaw))
	var step: float = TAU / float(SkateparkMesh.BOWL_AZIMUTH)
	var bearing: float = fposmod(atan2(l.y, l.x), TAU)
	var sector: int = int(floor(bearing / step))
	return wrapi(sector - (SkateparkMesh.BOWL_GATE_SECTORS - 1) / 2, 0, SkateparkMesh.BOWL_AZIMUTH)

## The bearing the mouth must contain, in the module's local frame --
## what a probe gates the door's aim against.
static func bowl_aim_bearing(spec: Dictionary) -> float:
	var aim: Vector2 = spec.get("rollin_aim", Vector2.ZERO)
	var d: Vector2 = aim - (spec["at"] as Vector2)
	var yaw: float = float(spec["yaw"])
	var l := Vector2(d.x * cos(yaw) - d.y * sin(yaw), d.x * sin(yaw) + d.y * cos(yaw))
	return fposmod(atan2(l.y, l.x), TAU)

## The convex pieces a module's collider is made of, or EMPTY for a
## module no chantier has made solid.
##
## ⚠️ CH69 -- THE BOWL IS THE FIFTH, AND THE PERIMETER IS STILL A
## MEASUREMENT AND NOT A LIST OF NAMES. CH56 section 12.4 refused it
## ("un bol decompose en hulls convexes est GEOMETRIQUEMENT FAUX -- une
## cuvette ouverte devient un tas de solides pleins") and priced a
## decomposition without ever checking whether it was right. CH66 wrote
## the exact ring instead -- a prism per (azimuth sector, profile
## segment), union == the drawn dish, ridden on a temporary body -- and
## still returned EMPTY, because where CH53 stood the bowl the ring cut
## into both quarterpipes and its vertical skirt left no way in on the
## ground. CH69 answers both: the sweep in MODULES puts it where nothing
## is closer than a deck length, the slab grows 0.25 u under it, and
## SkateparkMesh cuts the roll-in.
##
## What did NOT change is the gate. SkatePhysicsProbe PHASE X asserts
## that the bowl carries pieces IF AND ONLY IF its ring shares no sample
## with a solid module, so a future layout that pushed it back into a
## ramp turns this line red instead of shipping a wall inside a
## transition. A reader asking "which modules are solid" asks THIS, never
## a list of kinds.
static func pieces_for(spec: Dictionary) -> Array:
	var a: Array = build_args(spec)
	match StringName(spec["kind"]):
		KIND_QUARTERPIPE:
			return SkateparkMesh.quarterpipe_pieces(a[0], a[1])
		KIND_RAIL:
			return SkateparkMesh.rail_pieces(a[0], a[1])
		KIND_FUNBOX:
			return SkateparkMesh.funbox_pieces(a[0], a[1], a[2], a[3])
		KIND_LEDGE:
			return SkateparkMesh.ledge_pieces(a[0], a[1], a[2])
		KIND_BOWL:
			return SkateparkMesh.bowl_pieces(a[0], a[1], a[2], a[3])
	return []

## =====================================================================
## CH82 -- WHERE A MODULE CAN BE GROUND, AND WHO OWNS THE ANSWER
##
## ⚠️ ONE BRANCH PER KIND, INCLUDING THE ONES THAT ANSWER "NOWHERE".
## CH76's defect was a two-branch dispatch on a three-member enum: the
## third member fell into the `else` and inherited a number measured for
## something else, silently, and the lot that ARMED it had no reason to
## re-read a table it did not touch. Four kinds, four branches, and a
## fifth kind added tomorrow gets a `push_error` instead of a rail's
## geometry.
##
## The LINE ITSELF is the builder's (SkateparkMesh.*_grind_line), for
## the reason every other number in this pair of files is: the collision
## pieces and the mesh already come from one place, and a third reading
## of "where is the top of this thing" would be the second spelling this
## whole convention exists to refuse.
static func grind_line_local(spec: Dictionary) -> Array:
	var a: Array = build_args(spec)
	match StringName(spec["kind"]):
		KIND_RAIL:
			return SkateparkMesh.rail_grind_line(a[0], a[1])
		KIND_LEDGE:
			return SkateparkMesh.ledge_grind_line(a[0], a[1])
		KIND_QUARTERPIPE:
			# A transition has a COPING, and a coping is a grind in a
			# real park. It is not one here and the reason is measured,
			# not stylistic: the lip of the 2.10 stands 1.62 u above
			# what SkateBoardBody.GRIND_CATCH_DROP reaches, so a rider
			# could only ever be caught on it out of an air CH66 priced
			# at 0.762 s of window against 0.817 s of flight. A feature
			# reachable in five hundredths of a second is a feature
			# nobody has. Named here rather than left to an `else`.
			return []
		KIND_FUNBOX:
			# Its deck EDGE is grindable in a real park too, and here it
			# is the deck itself the board rides -- a line along the
			# edge would fight the surface 3 cm beside it for the same
			# board. The funbox stays a thing you ride over.
			return []
		KIND_BOWL:
			return []
	push_error("HubSkatepark: no grind answer for module kind '%s'." % spec["kind"])
	return []

## The park's grind lines in WORLD space, read off the nodes this file
## BUILT -- never recomposed from `at` and `yaw`, which would be a second
## spelling of a placement the tree already holds.
##
## Handed to SkateBoardBody once, by HubWorld, at setup. The board does
## not know the park exists; the park does not know a board does.
func grind_edges() -> Array:
	var out: Array = []
	for index in MODULES.size():
		var line: Array = grind_line_local(MODULES[index])
		if line.is_empty():
			continue
		var node: MeshInstance3D = _nodes[index]
		out.append({
			"module": index,
			"a": node.global_transform * (line[0] as Vector3),
			"b": node.global_transform * (line[1] as Vector3),
		})
	return out

## The highest grind line the park publishes. Read by SkateGrindProbe,
## which gates it against the catch's reach: the day a module is laid
## whose line is out of the board's range, that probe goes red instead of
## the park quietly growing a rail nobody can get onto.
func grind_edge_max_height() -> float:
	var top: float = -1e9
	for e in grind_edges():
		top = maxf(top, maxf((e["a"] as Vector3).y, (e["b"] as Vector3).y))
	return top

func _maybe_collide(node: MeshInstance3D, index: int, spec: Dictionary) -> void:
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
		KIND_LEDGE:
			return builder.ledge(a[0], a[1], a[2])
		KIND_BOWL:
			return builder.bowl(a[0], a[1], a[2], a[3])
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
## =====================================================================
## ⚠️ CH61 -- THE PARK'S OWN EXTENT, PUBLISHED SO NOBODY RETYPES IT
##
## The widest thing a board can be asked to cross without leaving the
## park: the greatest distance between two module centres, plus the
## footprint each of those two keeps clear around itself. It is what
## SkateBoardBody's coast distance is solved from, so that "a released
## board comes to rest inside the park" is a fact about THIS layout and
## follows the layout when a module moves.
##
## Derived from MODULES and from nothing else -- CLAUDE.md's rule that a
## reader never rebuilds an inventory the producer already holds. The
## day a sixth module lands further out, this grows and the board coasts
## further, with nobody editing a number.
static func park_span() -> float:
	var worst: float = 0.0
	for a in MODULES.size():
		for b in range(a + 1, MODULES.size()):
			var pa: Vector2 = MODULES[a]["at"]
			var pb: Vector2 = MODULES[b]["at"]
			var d: float = pa.distance_to(pb) \
				+ float(MODULES[a]["footprint"]) + float(MODULES[b]["footprint"])
			worst = maxf(worst, d)
	return worst

static func footprints() -> Array:
	var out: Array = []
	for spec in MODULES:
		out.append({"position": Vector3(spec["at"].x, 0.0, spec["at"].y),
			"radius": float(spec["footprint"])})
	# CH64: the slab. A disc that covers its rectangle, so no grass tuft
	# is planted through the concrete. Measured by SkateparkProbe as a
	# change in the scatter's north census, like every footprint.
	out.append({"position": Vector3(slab_centre().x, 0.0, slab_centre().y),
		"radius": Vector2(SLAB_WIDTH, SLAB_DEPTH).length() * 0.5})
	return out

## CH64: the slab's triangles, published beside `triangle_total()` (the
## five modules') so the park's whole price is two published numbers and
## not one plus a guess.
func decor_triangles() -> int:
	return _slab_tris

func slab_node() -> MeshInstance3D:
	return _slab

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
