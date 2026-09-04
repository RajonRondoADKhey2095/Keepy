extends Node
class_name HubTapInput
## Turns a tap on the screen into a point on the plateau.
##
## =====================================================================
## TAP, NOT SWIPE -- AND DELIBERATELY NOT SwipeDetector.gd
##
## scripts/input/SwipeDetector.gd exists and is NOT reused here. It answers
## "which direction did the finger travel", which is Chased's lane-change
## question; this screen's question is "which point did the finger land
## on". Reusing it would mean deriving a destination from a gesture that
## carries no destination, and would put two unrelated semantics on one
## file the moment either needed tuning.
##
## Only the RELEASE half of a touch is acted on. Acting on the press would
## fire while a finger is still down and still moving -- a player who
## touches the screen and drags to look would be sent to wherever their
## finger first met the glass.
##
## =====================================================================
## WHY THE MOUSE PATH EXISTS
##
## project.godot sets no `emulate_touch_from_mouse`, so on a desktop
## browser a click produces InputEventMouseButton and NOTHING else -- a
## touch-only handler leaves the plateau unusable outside a phone, which
## is where a lot of the looking-at happens.
##
## A finger, on the other hand, DOES produce both: emulate_mouse_from_touch
## defaults to true, so one tap arrives as a touch release AND as a
## synthesised mouse release, and _handle_point runs twice. Measured, not
## assumed -- a real touch injected into a real window emitted
## tapped_ground twice. It is harmless because hop_to() is depth-one: the
## second call re-states the same destination.
##
## =====================================================================
## WHY THIS ONLY EVER FIRES IF NO CONTROL EATS THE EVENT FIRST
##
## _unhandled_input runs AFTER GUI picking. Any Control under the finger
## whose mouse_filter is STOP consumes the event and calls
## set_input_as_handled(), and nothing downstream of that ever sees it --
## no error, no warning, just a plateau that ignores taps.
##
## HubWorld.tscn's root Control is full-screen, so at Control's DEFAULT
## MOUSE_FILTER_STOP it swallowed every tap on the plateau. It carries
## mouse_filter = MOUSE_FILTER_IGNORE for exactly that reason; the
## fallback Button and menu are separate Controls and are still picked
## normally, so the change costs nothing they need. Do not "tidy" that
## property away, and give any Control added over the plateau the same
## treatment.

## Emitted with the world point under the finger, on the ground plane.
signal tapped_ground(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the moored boat to mean "board it", with that same ground point.
##
## Exactly one of the two fires per tap. Emitting both and letting the
## listener pick would make every tap ambiguous downstream; deciding here
## is what makes the boat a priority rather than a competing reading of the
## same event.
signal tapped_boat(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the BADGER waiting at one end of the zipline to mean "ride across with
## it", on the same world-units terms the boat is picked out on. Same
## one-tap-one-signal rule.
##
## THE BOAT'S WITHDRAWAL, THROUGH A NODE RATHER THAN A FLAG. `ZiplineDoor`
## answers false for the whole of a trip AT BOTH ENDS and in either
## direction, so a tap made meanwhile falls through to tapped_ground.
## `owl_available` is a bare bool because a perch is one place; a zipline
## has two boarding points and one shared trip, which is a state a single
## bool cannot express and two bools would be free to disagree about --
## see ZiplineDoor.gd.
##
## ⚠️ RENAMED 4 SEPTEMBRE 2026 (tier 3), FROM `tapped_zipline`. RECON 1
## (docs/lots/CH21_TYROLIENNE.md) settled that a stair with a hotspot that
## emits whatever the body is doing is the banned LADDER PATTERN; it did
## NOT settle that the stair must forever carry nothing, and Mathieu has
## since asked for exactly that -- see `tapped_zipline_solo` below and the
## doctrine note in ZiplineDoor.gd. This channel keeps the ORIGINAL
## behaviour, name changed only to sit beside its sibling without either
## one reading as the general case.
signal tapped_zipline_badger(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the STRUCTURE of a zipline tower -- deck, mast or stair, at EITHER end --
## to mean "ride across alone", on the same world-units terms the badger
## channel is picked out on. Same one-tap-one-signal rule.
##
## ⚠️ THE DOCTRINE CHANGE, NAMED. `ZiplineDoor.accepts_structure_tap`
## withdraws on the boat's own terms (false for the whole of a trip, at
## both ends) and EXCLUDES the badger's own disc where a badger is
## currently waiting, so a tap can never mean both channels at once -- see
## that file's header for why the two discs cannot be made geometrically
## disjoint and are kept unambiguous in code instead.
signal tapped_zipline_solo(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## an OWL PERCH to mean "fly with it", on the same world-units terms the
## boat is picked out on. Same one-tap-one-signal rule.
##
## MODELLED ON THE BOAT AND DELIBERATELY NOT ON THE LADDER. The boat asks
## its mooring, which answers false for the whole of a ride, so a tap
## during one falls through to tapped_ground and BECOMES the eject. The
## ladder has no such withdrawal: it emits tapped_ladder whatever Keepy is
## doing, and HubWorld then drops it -- which is fine for a board, whose
## only other meaning would be a dive it already handles by state, and
## would be wrong here, because a tap during a flight has to be able to
## reach the ground path. `owl_available` is that withdrawal, and it is a
## plain flag rather than a second node only because there is no owl-side
## object to ask: HubWorld already knows whether a flight is running.
signal tapped_owl(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## a CABIN DOOR to mean "go inside", on the same world-units terms the boat
## and the owl are picked out on. Same one-tap-one-signal rule.
##
## ⚠️ NO WITHDRAWAL, UNLIKE THE BOAT AND THE OWL -- and that is a deletion
## rather than an omission. It used to carry a `cabin_available` flag on
## the mooring's pattern, because Keepy USED to hide inside the prop and a
## tap made meanwhile had to fall through to the ground path to become the
## way back out. Since 29 aout 2026 going in is a SCENE CHANGE: this whole
## screen stops existing for the length of the visit, so there is no
## "meanwhile" in which a tap could need to mean something else, and a flag
## that can never be false is a flag no one is reading.
signal tapped_cabin(point: Vector3)

## Emitted INSTEAD of tapped_ground when the finger landed close enough to
## the diving board's LADDER FOOT to mean "climb that", on the same
## world-units terms the boat is picked out on. Same one-tap-one-signal
## rule: a tap is a climb or a destination, never both.
signal tapped_ladder(point: Vector3)

## The three nodes this needs, as scene-authored paths.
##
## NodePath and not a typed node export (`@export var camera: Camera3D`),
## MEASURED and not preferred: a typed node export written by hand into a
## .tscn does NOT resolve at load -- the probe for this batch got null for
## all three and every tap died on the guard below. The editor populates
## that form through machinery a hand-written scene file does not carry.
## An exported NodePath resolves either way, and is still a path the scene
## author owns rather than a `get_node("../../X")` walk baked into code.
@export var camera_path: NodePath
@export var container_path: NodePath
@export var viewport_path: NodePath

## The mooring, asked -- before any destination is resolved -- whether the
## tap was on the boat. Optional: a plateau whose layout carries no boat
## resolves this to null and every tap is a ground tap, exactly as before.
@export var mooring_path: NodePath

## The zipline's door, asked -- before any destination is resolved --
## whether the tap was on the badger waiting to ride. Optional, exactly as
## the mooring is: a plateau whose layout carries no zipline resolves this
## to null and every tap is a ground tap.
##
## A scene path and not a code-set property, unlike the owl perches and the
## ladder feet, because this one carries STATE rather than a table: the
## withdrawal that keeps a trip from swallowing taps lives in it, and a
## node the scene owns is a node a probe can reach without going through
## HubWorld's 2000 lines.
@export var zipline_path: NodePath

var camera: Camera3D = null
var container: SubViewportContainer = null
var viewport: SubViewport = null
var mooring: BoatMooring = null
var zipline: ZiplineDoor = null

## THE WALKABLE LIMIT LIVES IN HubRegion, NOT HERE.
##
## This file used to own `const PLATEAU_HALF_EXTENT` and clamp each axis
## against it. That worked while the walkable hub was a square; the lake
## zone made it a union-minus-a-disc, and a per-axis clampf cannot express
## a hole. The constant moved to HubRegion.gd together with the rest of the
## shape, so there is still exactly one owner -- see that file for the
## measured crossing costs and for why the square stopped growing at 35.
##
## What changed for a player: a tap outside is still pulled to the nearest
## reachable point rather than dropped, and a tap ON the great lake is now
## pulled to its shore instead of walking Keepy into the water.

## Every diving board's ladder foot, flat, and how close a tap has to land
## to mean one. Empty until HubWorld hands over the built boards, so a
## layout with no board simply never emits tapped_ladder.
##
## Set from the BUILT boards rather than read from the layout here: the
## plank the player aims at and the foot this radius is measured from have
## to be the same fact.
##
## A LIST, not one point: the plateau carries three ladders now, and a
## single foot could only ever have answered for the first of them --
## tapping either of the others would have fallen through to tapped_ground
## and walked Keepy up to a plank he then could not climb. The radius stays
## a single number because it is a property of the GESTURE, not of any one
## board; the feet are metres apart, so no tap can be inside two.
var ladder_feet: Array[Vector3] = []
var ladder_radius: float = 0.0

## Every owl perch, flat, and how close a tap has to land to mean one.
## Empty until HubWorld hands over the built owls, so a layout with no owl
## simply never emits tapped_owl.
##
## Set from the BUILT owls for the reason the feet are: the prop the player
## aims at and the point this radius is measured from have to be one fact.
##
## `owl_available` is the boat's withdrawal, written above: HubWorld clears
## it for the length of a flight so a tap then falls through to the ground
## path instead of being swallowed here.
var owl_perches: Array[Vector3] = []
var owl_radius: float = 0.0
var owl_available: bool = true

## Every cabin doorstep, flat, and how close a tap has to land to mean one.
## Empty until HubWorld hands over the built cabins, so a layout with no
## cabin simply never emits tapped_cabin.
##
## Set from the BUILT cabins for the reason the perches and the feet are:
## the prop the player aims at and the point this radius is measured from
## have to be one fact.
##
## No availability flag beside them -- see the signal's own comment.
var cabin_doors: Array[Vector3] = []
var cabin_radius: float = 0.0

func _ready() -> void:
	camera = get_node_or_null(camera_path) as Camera3D
	container = get_node_or_null(container_path) as SubViewportContainer
	viewport = get_node_or_null(viewport_path) as SubViewport
	mooring = get_node_or_null(mooring_path) as BoatMooring
	zipline = get_node_or_null(zipline_path) as ZiplineDoor
	if camera == null or container == null or viewport == null:
		push_error("HubTapInput: camera_path, container_path and viewport_path must all resolve.")

func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch:
		if not touch.pressed:
			_handle_point(touch.position)
			get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		_handle_point(click.position)
		get_viewport().set_input_as_handled()

func _handle_point(screen_point: Vector2) -> void:
	if camera == null or container == null or viewport == null:
		return
	var rect := container.get_global_rect()
	if not rect.has_point(screen_point):
		return
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var local := screen_point - rect.position
	local.x *= float(viewport.size.x) / rect.size.x
	local.y *= float(viewport.size.y) / rect.size.y

	var origin := camera.project_ray_origin(local)
	var direction := camera.project_ray_normal(local)
	# A maths plane, not a physics raycast: the ground is a decorative
	# PlaneMesh with no collider, and giving it one purely so a ray could
	# hit it would add a physics body to a screen that has no physics.
	var ground := Plane(Vector3.UP, 0.0)
	var hit: Variant = ground.intersects_ray(origin, direction)
	if hit == null:
		# Camera looking at or above the horizon. Nothing to aim at.
		return
	var point: Vector3 = hit
	# WHERE THE FINGER POINTED, and it is a SEPARATE fact from where he can
	# walk. Every prop below is asked about `aim`; only the destination is
	# clamped. Those were one variable until the cabin proved they are two.
	#
	# ⚠️ THE THIRD STRAY-ENTRY CAUSE, and the one no radius could have
	# fixed. clamp_to() answers "where can he stand"; a prop test answers
	# "what did the player mean". Reading the second off the first makes
	# the clamp a FUNNEL: every tap on ground that does not exist is
	# dragged to the nearest ground that does, and if a prop happens to sit
	# near that edge, the whole half-plane behind it starts meaning the
	# prop. Measured on the shipped layout: the cabin's doorstep stands
	# 0.655 u inside the plateau's north edge, so a 2.246 u strip of that
	# edge lies inside the doorstep disc -- and taps aimed from as far as
	# 49.8 u off the map landed on it and MEANT "go inside". Standing at
	# the door, 15.26% of all visible ground said "go inside", 89.2% of it
	# aimed at ground that is not there.
	#
	# WHY THE OTHER THREE ARE ASKED THE SAME WAY when only the cabin was
	# broken: measured, the boat, the owl and the three ladder feet are
	# 6.85 u to infinitely far from any off-map ground and NOT ONE off-map
	# point funnels into any of them, so this costs them nothing today. It
	# is written once rather than as a cabin special case because the
	# funnel is a property of standing near an EDGE, not of being a cabin,
	# and the next prop placed near one would rediscover it.
	var aim := Vector3(point.x, 0.0, point.z)
	# One shape, one owner. The region is a union minus the great lake, so
	# this is a nearest-point projection and not two independent clamps --
	# see HubRegion for why the difference matters and what it costs.
	var destination := HubRegion.clamp_to(point)

	# THE BOAT WINS, and it is asked BEFORE the ground point becomes a
	# destination. The radius is in WORLD units and is measured on this
	# same ground point, so "the boat or the ground behind it" is decided
	# in the space a hop destination already lives in rather than in
	# pixels, where the target would shrink with distance.
	#
	# accepts_boarding_tap() is false for the whole of a ride, so a tap
	# then falls through to tapped_ground -- which is what turns it into
	# an eject. One tap, one signal, either way.
	if mooring != null and mooring.accepts_boarding_tap(aim):
		tapped_boat.emit(destination)
		return
	# THE ZIPLINE, asked on the boat's exact terms and for the boat's exact
	# reason: `accepts_boarding_tap()` is false for the whole of a trip AT
	# BOTH ENDS, so a tap then falls through to tapped_ground and reaches
	# the state branch that owns it. One tap, one signal, either way.
	#
	# Ordered after the boat only because the boat was here first. The
	# hull sails the stream at the west of the plateau and the badger waits
	# at x ~ +26, twenty-odd units away, so the order between them can
	# never actually decide anything.
	#
	# Asked on `aim` like every prop above and below, not on `destination`:
	# a disc read off the CLAMPED point turns the plateau's edge into a
	# funnel -- the cabin's measured defect, written once for every prop
	# because being near an edge is what causes it, not being a cabin.
	if zipline != null and zipline.accepts_boarding_tap(aim):
		tapped_zipline_badger.emit(destination)
		return
	# THE STRUCTURE, asked right after the badger and on the same `aim`
	# terms, for the same edge-funnel reason. Checked SECOND so a tap
	# landing in the small lens where the two discs geometrically
	# overlap (see ZiplineDoor.gd) would in principle read as the badger
	# first -- though `accepts_structure_tap` already excludes that lens
	# on its own, so this order cannot actually change the answer.
	if zipline != null and zipline.accepts_structure_tap(aim) >= 0:
		tapped_zipline_solo.emit(destination)
		return
	# THE OWL, asked after the boat and before the ladder, on the same
	# world-unit terms both of them use. The order between the owl and the
	# ladder can never actually decide anything -- the perch is by the
	# spawn and the three ladder feet are out over the water, metres away
	# -- so it is only that the boat came first and the ladder was here
	# before this.
	#
	# Nothing is asked here about whether Keepy is FREE to fly: that is
	# KeepyHopper's business and it refuses from any state but standing
	# still. What IS asked is `owl_available`, which is a different
	# question -- not "may he" but "is this signal still meaningful", the
	# boat's own withdrawal, and the thing that turns a tap during a
	# flight back into an ordinary ground tap.
	if owl_available and owl_radius > 0.0:
		var owl_flat := aim
		for perch in owl_perches:
			if owl_flat.distance_to(perch) <= owl_radius:
				tapped_owl.emit(destination)
				return
	# THE CABIN, asked on the identical world-unit terms but NOT gated on a
	# withdrawal, unlike the two above -- see the signal's comment. Ordered
	# here only because the owl was here first: the perch is by the spawn
	# and the cabin is out at z = +28, so the order between them can never
	# actually decide anything.
	#
	# Nothing is asked here about whether Keepy is free to go in. HubWorld
	# refuses a tap made mid-ride, and the walk to the door is an ordinary
	# hop chain that any later tap may cancel.
	if cabin_radius > 0.0:
		var cabin_flat := aim
		for door in cabin_doors:
			if cabin_flat.distance_to(door) <= cabin_radius:
				tapped_cabin.emit(destination)
				return
	# THE LADDER, asked after the boat and on the same terms: a world-unit
	# radius on the ground point, so the target does not shrink with
	# distance the way a pixel one would. Ordered after the boat only
	# because the boat came first; the two are metres apart at opposite
	# ends of the plateau, so the order can never actually decide anything.
	#
	# Nothing is asked here about whether Keepy is FREE to climb. That is
	# KeepyHopper's business, and it refuses from any state but standing
	# still -- asking twice is how the two answers start to differ.
	if ladder_radius > 0.0:
		var flat := aim
		for foot in ladder_feet:
			if flat.distance_to(foot) <= ladder_radius:
				tapped_ladder.emit(destination)
				return
	tapped_ground.emit(destination)
