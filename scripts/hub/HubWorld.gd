extends Control
class_name HubWorld
## The plateau hub: the screen reached right after sign-in, from which each
## sub-game is entered by hopping onto its portal.
##
## Replaces the three-button scenes/Hub.tscn. That scene and its script are
## deliberately LEFT IN THE REPO by this batch: they are the rollback, and
## a screen this central should not lose its previous version in the same
## commit that first ships its replacement.
##
## =====================================================================
## WHAT THIS FILE DOES AND WHAT IT REFUSES TO DO
##
## It is the coordinator, and it holds no rules of its own:
##
##   HubTapInput   -> where did the finger land on the plateau
##   KeepyHopper   -> how a body crosses that plateau
##   HubPortal     -> is this landing inside me, and how do I look when
##                    someone is close
##   HubRouter     -> which scene a game_id means
##   HubBuilder    -> what the plateau is made of (from the layout data)
##
## Every one of those is separately replaceable. What lives HERE is only
## the wiring between them, plus the one decision none of them can make
## alone: a landing inside a portal is a PROPOSAL (see the block below).
##
## =====================================================================
## THE FALLBACK MENU IS NOT DEAD WEIGHT
##
## A 3D screen can fail in ways a button list cannot -- a WebGL context
## that never comes back, a viewport that renders black, a tap projection
## wrong on some aspect ratio. Any of those would strand a player on the
## one screen every game is reached through. The fallback carries the
## exact three change_scene_to_file calls the old hub had, one small
## button away, so the worst case is an ugly screen rather than an
## unreachable game.
##
## =====================================================================
## A LANDING PROPOSES, IT NO LONGER ENTERS (23 aout 2026)
##
## Landing inside a portal used to route straight into the sub-game. A hop
## is aimed with a tap on the ground, so that made a mis-aimed tap enough
## to leave the plateau -- and Chased, at the time, had no way back.
## HubConfirmDialog now sits between the landing and HubRouter: the landing
## opens it, "Jouer" routes, "Annuler" leaves Keepy standing where they
## are. The ROUTING is unchanged, only delayed by one deliberate tap.
##
## The fallback menu deliberately keeps routing DIRECTLY. Pressing a button
## labelled "Keepy Quizz" is already an explicit choice; a confirmation on
## top of it would be a second dialog asking about the first, on the very
## path that exists to be the simple one when the 3D screen has failed.
##
## =====================================================================
## THE RIDE, AND THE ONE THING THAT MUST NOT HAPPEN DURING IT (26 aout 2026)
##
## A tap near the moored boat buys the whole journey: the ordinary hop
## chain to the water, then boarding, in ONE tap. That is the same
## already-established shape as a tap across the plateau -- KeepyHopper
## chains its own hops -- so the boarding is armed here and fired on the
## landing that reaches the boat.
##
## NO PORTAL IS DETECTED WHILE KEEPY IS ABOARD. Portal detection is
## already keyed to hop_landed and a ride emits no landings, so it is
## silent for free -- but "for free" is exactly the kind of guarantee that
## quietly stops being true, so _on_hop_landed refuses outright while
## is_riding(). The stream arcs in front of the portal row (9.25 u from the
## nearest at its closest), and being carried past one must never enter a
## sub-game. Detection resumes on the first landing AFTER the eject, which
## is the eject hop's own landing.

## The shared swamp identity. The plateau and Keepy Chased are the same
## marsh, and were authored months apart from copies of the same numbers --
## this is what stops them drifting.
const _PALETTE: SwampPalette = preload("res://resources/world/swamp_palette.tres")

@onready var _container: SubViewportContainer = $WorldViewport
@onready var _builder: HubBuilder = $WorldViewport/SubViewport/World/Props
@onready var _keepy: KeepyHopper = $WorldViewport/SubViewport/World/Keepy
@onready var _tap: HubTapInput = $TapInput
@onready var _router: HubRouter = $Router
@onready var _fallback_menu: Control = $FallbackMenu
@onready var _fallback_button: Button = $FallbackButton
@onready var _world_env: WorldEnvironment = $WorldViewport/SubViewport/World/WorldEnvironment
@onready var _fallback_close: Button = $FallbackMenu/Panel/VBoxContainer/CloseButton
@onready var _confirm: HubConfirmDialog = $ConfirmDialog
@onready var _chased_button: Button = $FallbackMenu/Panel/VBoxContainer/ChasedButton
@onready var _quizz_button: Button = $FallbackMenu/Panel/VBoxContainer/QuizzButton
@onready var _battle_button: Button = $FallbackMenu/Panel/VBoxContainer/BattleButton
@onready var _mooring: BoatMooring = $Mooring

## The 3D root, and the ONE reason this path is held: the impact splash is
## parented HERE and never under Props.
##
## That is not tidiness, it is what keeps a transient node out of a
## permanent budget. Every draw-node count this project publishes --
## HubPerfBaseline's, DivingBoardProbe PHASE E's -- walks
## World/Props and nothing else. A splash parented under Props would be
## counted as a prop for the fraction of a second it exists, so the number
## would depend on WHEN the probe happened to sample, which is the kind of
## measurement that reads as a regression and is not one.
@onready var _world: Node3D = $WorldViewport/SubViewport/World

var _portals: Array[HubPortal] = []

## The stream, arc-length parameterised, built from the spine HubBuilder
## actually ribboned. Null on a layout with no stream, which is a legal
## plateau -- there is simply no ride there.
var _route: HubStreamRoute = null

## Half the ribbon's width, carried so a disembark knows where the bank is.
## Layout data, read once at build time.
var _ride_half_width: float = 0.0

## Set when a tap asked to board: the hop chain is walking to the water and
## the landing that gets there starts the ride. Cleared by any other tap,
## so a player who changes their mind simply walks somewhere else.
var _boarding: bool = false

## Set while a hop chain is walking to the ladder foot, cleared the moment
## the climb starts or the chain runs out. Same shape and same lifetime as
## _boarding above -- and separate from it because a player who taps the
## boat mid-walk to the ladder means the boat.
var _climbing: bool = false

## The five-body water test, built once from the geometry HubBuilder just
## drew. Never null after _ready(); a plateau with no water simply answers
## false to everything.
var _water: HubWater = null

## Keepy's material, DUPLICATED, and the tween that recolours it. See
## _ensure_keepy_material() for why the duplicate is not optional.
##
## A ShaderMaterial since the waterline batch: the tint stopped being a
## whole-body property and became a per-fragment split, which no
## StandardMaterial3D property can express. What drives it did NOT change
## -- the same landing hook, the same latch, the same tween, now aimed at
## a shader uniform instead of albedo_color.
var _keepy_material: ShaderMaterial = null
var _keepy_material_resolved: bool = false
var _keepy_tint_tween: Tween = null

## What the tint is currently aimed at, so a landing that does not change
## the answer does not restart the tween. Without it, hopping along a lake
## bed would re-fire a 0.18s fade every 0.28s and the tint would never
## settle.
var _keepy_wet: bool = false

## Set when a dive LEAVES the board, consumed by the landing that ends it.
##
## WHY A LATCH AND NOT A STATE READ. By the time the dive's landing is
## emitted the state is already back to IDLE -- _on_hop_finished sets it
## before it emits, and the dive goes through that same function on
## purpose so the water tint and every other landing listener keep working
## without knowing a board exists. So a listener cannot tell a dive's
## landing from an ordinary hop's by asking, and the only honest way to
## know is to have been told when the dive started.
##
## Armed on board_dived, which fires once inside dive(). Consumed in
## _on_hop_landed, where the landing position and the water answer are
## both already in hand -- so the effect uses the SAME water test the tint
## uses, not a second one that could disagree with it.
var _dive_pending: bool = false

## The waterline pulse, held so a second dive cannot leave two tweens
## fighting over one uniform. Killed and restarted rather than queued: the
## newest impact is the one worth showing.
var _keepy_waterline_tween: Tween = null

## Every prop that answers a landing by turning, as HubBuilder built them,
## plus the tween each one currently owns.
##
## ONE array holding both rather than a registry here and a parallel array
## of tweens beside it: index-aligned parallel arrays are how the tween for
## prop three ends up killing prop four. Copied out of the builder once, in
## _ready(), and never resized.
##
## The entries carry HubBuilder's own keys -- "position", "radius",
## "spinner" -- with a "tween" slot added. Nothing in here is
## turnstile-shaped, so a second kind of spinning prop needs no second
## mechanism.
var _spinners: Array[Dictionary] = []

## How far the top swings when a landing sets it going, and over how long.
##
## EASE_OUT, and that is the whole reading: a real roundabout is shoved
## once and then coasts down. A linear spin or an ease-in-out would both
## read as a machine being driven rather than as something that was pushed.
const TURNSTILE_SPIN_TURNS: float = 1.5
const TURNSTILE_SPIN_S: float = 2.2

func _ready() -> void:
	# Both inherited from the screen this replaces, for the same reasons:
	# the swamp safe-area paint (this is still the one screen every way
	# back out of Quizz passes through), and a full-screen canvas because
	# a UI screen letterboxed at Chased's 9:16 would only gain black bars.
	SafeArea.set_default()
	SafeArea.fill_screen()

	_apply_swamp_palette()

	_portals = _builder.portals()
	for portal in _portals:
		portal.portal_entered.connect(_on_portal_entered)

	_setup_ride()
	# AFTER _setup_ride(), which is what owns the one HubStreamRoute: the
	# water test is handed that same route rather than building a second
	# one over the same spine.
	_water = HubWater.new(_builder, _route)

	_tap.tapped_ground.connect(_on_tapped_ground)
	_tap.tapped_ladder.connect(_on_tapped_ladder)
	_setup_boards()
	_setup_spinners()
	_tap.tapped_boat.connect(_on_tapped_boat)
	_keepy.hop_landed.connect(_on_hop_landed)
	_keepy.ride_moved.connect(_on_ride_moved)
	_keepy.ride_started.connect(_on_ride_started)
	_keepy.ride_ended.connect(_on_ride_ended)
	_keepy.became_idle.connect(_on_keepy_idle)
	_keepy.board_dived.connect(_on_board_dived)

	_confirm.confirmed.connect(_on_confirm_accepted)
	_confirm.cancelled.connect(_on_confirm_cancelled)

	_fallback_button.pressed.connect(_on_fallback_toggled)
	_fallback_close.pressed.connect(_on_fallback_toggled)
	_chased_button.pressed.connect(_on_fallback_chased)
	_quizz_button.pressed.connect(_on_fallback_quizz)
	_battle_button.pressed.connect(_on_fallback_battle)

## Repaints this screen's atmosphere from the shared palette.
##
## The .tscn ships these same values, so this is a no-op on the pixels --
## it exists so the plateau cannot drift away from Chased when a colour is
## tuned in the .tres. The scene keeps its literals as the first-frame
## baseline, which is also what makes this screen correct if this node
## ever fails to run.
##
## THE FOG IS DELIBERATELY NOT CHASED'S. A plateau read from a fixed
## camera wants the horizon closed much sooner than a track the player is
## running down, so it fogs toward the SKY colour at roughly 4.6x the
## density. Those two values are named `hub_*` in the palette rather than
## left as literals here, so the deviation is visible next to what it
## deviates from instead of hiding in a scene file.
## How close a tap has to land to the ladder foot to mean "climb it", in
## world units.
##
## The SAME 2.5 the boat uses (BoatMooring.BOARD_TAP_RADIUS), and for the
## same measured reason: a ladder foot is a fraction of a unit across and
## would be a target nobody can hit at this camera distance. Kept as its
## own constant rather than reaching for the boat's -- they answer
## questions about two different props, and one of them may well be
## retuned on device without the other.
const LADDER_TAP_RADIUS: float = 2.5

## Hands the built boards to whatever needs to know where they are. Called
## once, after the props are built; a layout with no board leaves the tap
## radius at zero and nothing downstream ever fires.
func _setup_boards() -> void:
	var boards: Array[Dictionary] = _builder.diving_boards()
	if boards.is_empty():
		return
	var feet: Array[Vector3] = []
	for board in boards:
		feet.append(board["ladder"])
	_tap.ladder_feet = feet
	_tap.ladder_radius = LADDER_TAP_RADIUS

## Copies the built spinning props out of the builder, once, adding the
## per-prop tween slot. A layout with none leaves the list empty and every
## landing below simply walks a list of nothing.
func _setup_spinners() -> void:
	for prop in _builder.spinning_props():
		_spinners.append({
			"position": prop["position"],
			"radius": prop["radius"],
			"spinner": prop["spinner"],
			"tween": null,
		})

## Sets going every spinning prop the landing is standing at.
##
## NO NEW STATE, and that is the point of the whole feature: Keepy is IDLE
## when this runs, he is IDLE when it returns, nothing about him changes and
## nothing here touches KeepyHopper. The prop reacts to him; he does not
## interact with it.
##
## DEBOUNCE BY IGNORING, not by restarting. A player who taps back onto the
## same spot while the top is still coasting must not see it snap back to
## full speed -- that is a jolt, and a jolt is exactly what a second tween
## laid over a running one produces. A shove that arrives while it is
## already turning is simply not a shove.
func _spin_near(landing: Vector3) -> void:
	var flat := Vector3(landing.x, 0.0, landing.z)
	for entry in _spinners:
		var pivot: Node3D = entry["spinner"]
		if pivot == null or not is_instance_valid(pivot):
			continue
		if flat.distance_to(entry["position"] as Vector3) > float(entry["radius"]):
			continue
		var running: Tween = entry["tween"]
		if running != null and running.is_valid() and running.is_running():
			continue
		# Wrapped before it is tweened, never reset to zero: the top keeps
		# whatever facing it coasted to, which is what a roundabout does,
		# while the number it is counted from stays bounded instead of
		# climbing by 540 degrees for the rest of the session.
		var from_deg: float = fposmod(pivot.rotation_degrees.y, 360.0)
		pivot.rotation_degrees.y = from_deg
		var tween := pivot.create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(pivot, "rotation_degrees:y",
			from_deg + 360.0 * TURNSTILE_SPIN_TURNS, TURNSTILE_SPIN_S)
		entry["tween"] = tween

func _apply_swamp_palette() -> void:
	var env: Environment = _world_env.environment
	if env == null:
		return
	env.background_color = _PALETTE.sky_shallow
	env.ambient_light_color = _PALETTE.ambient_light_color
	env.ambient_light_energy = _PALETTE.ambient_light_energy
	env.fog_light_color = _PALETTE.hub_fog_light_color
	env.fog_density = _PALETTE.hub_fog_density

## Hands the ride its geometry, once, after the build. The route is made
## from HubBuilder's OWN spine rather than re-derived from the layout's
## control points: the drawn curve bulges outside the chords through those
## points, so a second derivation would put the rider off the water on
## every bend. One curve in the build.
func _setup_ride() -> void:
	var spine: Array = _builder.stream_spine()
	if spine.size() < 2:
		return
	_route = HubStreamRoute.new(spine)
	if not _route.is_valid():
		_route = null
		return
	_ride_half_width = _builder.stream_half_width()
	_mooring.setup(_builder.boat(), _route, _ride_half_width)
	# Parked before the first frame is drawn, ignoring the distance and
	# frustum rules that govern every later move -- there is nothing on
	# screen yet for the placement to be seen arriving at.
	_mooring.moor_now(_keepy.global_position)

func _process(_delta: float) -> void:
	# Three calls a frame, and the portals stay ignorant of who is
	# approaching -- pushing the position beats each portal holding a
	# reference back to Keepy.
	var here := _keepy.global_position
	for portal in _portals:
		portal.set_proximity(here)
	_mooring.update(here)

func _on_tapped_ground(point: Vector3) -> void:
	# A tap while either overlay is up is a tap on the overlay, not on the
	# plateau behind it.
	#
	# Both overlays already swallow the event by GUI picking, so neither of
	# these guards should ever fire -- they are the second half of the belt
	# and braces described in HubConfirmDialog.gd's MOUSE FILTER block.
	# Losing the plateau's taps to a Control has cost this screen twice
	# already (HubTapInput.gd), and the failure in that direction is silent;
	# a guard that is normally dead is the cheap half of not finding out the
	# hard way that Keepy hops around under an open dialog.
	if _fallback_menu.visible or _confirm.is_open():
		return
	# A tap DURING a ride ejects. This is the only place that knows both
	# that a ride is running and what a landing has to clear, so it is the
	# only place that can turn a tap into a leap for the bank.
	if _keepy.is_riding():
		_keepy.leave_ride(point, _builder.ground_footprints())
		return
	# A tap while the board owns the body is intercepted BY STATE, exactly
	# as the ride's is, and for the same reason: the point arrived resolved
	# on the y = 0 ground plane, which is the only plane taps resolve
	# against, so it can say WHICH WAY the player pointed but must never
	# become somewhere to walk to. Standing on the deck it means dive;
	# mid-climb or mid-dive it means nothing at all, and is dropped rather
	# than queued -- a climb that could be interrupted would leave Keepy
	# walking out of a ladder halfway up it.
	if _keepy.is_on_board():
		if _keepy.is_standing_on_board():
			_keepy.dive(point)
		return
	# Any ordinary tap cancels a boarding walk in progress: the player
	# aimed somewhere else, and arriving at the boat anyway would be the
	# screen overruling them.
	_boarding = false
	_climbing = false
	_keepy.hop_to(point)

## A tap on the moored boat. ONE tap buys the whole thing -- the hop chain
## walks to the water and _on_hop_landed boards on arrival -- because that
## is already how a tap across the plateau behaves, and a boat that needed
## a second tap would be the one object on this screen that did not.
func _on_tapped_boat(point: Vector3) -> void:
	if _fallback_menu.visible or _confirm.is_open():
		return
	if _keepy.is_riding() or _route == null:
		return
	_boarding = true
	_climbing = false
	_keepy.hop_to(point)
	# Already standing at the boat: nothing to walk, so board on the spot
	# rather than waiting for a landing that will never come.
	if not _keepy.is_hopping():
		_try_board(point)

## A tap on the ladder foot. ONE tap buys the whole thing -- the hop chain
## walks to the ladder and _on_hop_landed climbs on arrival -- because that
## is exactly how a tap on the boat already behaves, and a board that
## needed a second tap would be the one object on this screen that did.
func _on_tapped_ladder(point: Vector3) -> void:
	if _fallback_menu.visible or _confirm.is_open():
		return
	if _keepy.is_riding() or _keepy.is_on_board():
		return
	_boarding = false
	_climbing = true
	_keepy.hop_to(point)
	# Already standing at the foot: nothing to walk, so climb on the spot
	# rather than waiting for a landing that will never come.
	if not _keepy.is_hopping():
		_try_climb(_keepy.global_position)

## Climbs if the landing is close enough to the ladder foot. Returns true
## when the climb started, so the caller can stop looking at that landing.
##
## The proximity test is the SAME radius the tap used, for the reason the
## boat's is: a player who tapped the ladder and walked to it cannot arrive
## and be told they are not there yet.
## WHICH board, now that there are three: the NEAREST ladder foot within
## the radius, chosen from where Keepy actually landed rather than from
## which entry came first in the layout. Nearest and not first-match
## because "first" is a fact about the file, and the player is standing at
## a place -- the feet are metres apart so the two only ever differ when
## first-match would be plainly wrong.
func _try_climb(position: Vector3) -> bool:
	var boards: Array[Dictionary] = _builder.diving_boards()
	if boards.is_empty():
		_climbing = false
		return false
	var flat := Vector3(position.x, 0.0, position.z)
	var board: Dictionary = {}
	var nearest: float = INF
	for candidate in boards:
		var d: float = flat.distance_to(candidate["ladder"] as Vector3)
		if d < nearest:
			nearest = d
			board = candidate
	if nearest > LADDER_TAP_RADIUS:
		# NOT YET, and the intent SURVIVES -- the boarding walk's own
		# defect, which passed its probe for a whole batch because the
		# arrival happened to fall inside the radius on hop one. A climb
		# further than one hop away must not lose its intent on the way.
		return false
	_climbing = false
	_keepy.climb_board(board)
	return true

func _on_hop_landed(position: Vector3) -> void:
	# NO PORTAL WHILE ABOARD. A ride emits no landings, so this branch
	# should never be reached mid-ride -- it is here because "no landing is
	# emitted" is a property of another file that could change, and the
	# failure it would cause (being carried into a sub-game the player was
	# only sailing past) is exactly the kind that only shows up on device.
	if _keepy.is_riding():
		return
	# NOR WHILE THE BOARD OWNS HIM. A climb and a dive emit no landings
	# either, so this branch should be as unreachable as the one above --
	# and it is here for the same reason: "no landing is emitted" is a
	# property of KeepyHopper that could change, and the failure it would
	# cause is being carried into a sub-game from the top of a ladder.
	#
	# The dive's OWN landing is deliberately not covered: by the time it
	# fires the state is back to IDLE, because the water is ordinary
	# walkable ground and a dive ends like any other leap.
	if _keepy.is_on_board():
		return

	# WHERE KEEPY IS, decided before anything about what this landing goes
	# on to TRIGGER. A landing in a portal still updates the tint on its way
	# to opening the dialog; a landing that starts a ride still reports the
	# ground it left from. Both of the branches below return early, so a
	# tint placed after them would simply stop updating on the landings that
	# do something -- silently, and only sometimes.
	var in_water: bool = _water != null and _water.contains(position)
	_set_keepy_wet(in_water)

	# THE IMPACT, and it is consumed here for two reasons that both matter.
	#
	# It sits immediately under the tint and above every branch that
	# returns, for the reason the tint itself is written here: the branches
	# below leave this function early, so an effect placed after them would
	# simply stop firing on the landings that do something -- silently, and
	# only sometimes.
	#
	# And it reuses `in_water` rather than asking the water again. One
	# landing, one water answer: a second test could drift from the first
	# by a float, and then Keepy would be tinted without a splash or
	# splashed without a tint on exactly the rim cases HubWater's own two
	# margins exist to document.
	#
	# The latch is cleared whatever the answer, so a dive back to the
	# LADDER FOOT -- dry land, the board's other target -- disarms it
	# instead of leaving it primed for the next unrelated landing.
	var was_dive: bool = _dive_pending
	if _dive_pending:
		_dive_pending = false
		if in_water:
			_on_water_impact(position)

	# THE SPINNING PROPS, and they sit here for the reason the tint and the
	# impact above do: every branch below this point returns, so a reaction
	# placed after them would stop firing on exactly the landings that go on
	# to do something -- silently, and only sometimes.
	#
	# NOT ON A DIVE. A dive is not a walk, and a prop that answered one
	# would be answering a leap off a plank rather than someone arriving on
	# foot. The gate is written out rather than left to the placement: the
	# boards are all over water and the turnstile is on dry land, so today
	# the distance test would refuse a dive landing anyway -- but that is a
	# fact about the layout, which is DATA, and a layout is exactly the kind
	# of thing that gets edited without this file being reread.
	if not was_dive:
		_spin_near(position)

	# The landing that finishes a boarding walk starts the ride, before
	# anything else looks at where it landed.
	if _boarding and _try_board(position):
		return
	# And the one that finishes a walk to the ladder starts the climb. Both
	# sit AFTER the tint and BEFORE the portals, which is the whole reason
	# the tint is written at the top of this function: a landing that goes
	# on to climb still reports the ground it left from.
	if _climbing and _try_climb(position):
		return
	# A landing while the dialog is up cannot happen from a plateau tap
	# (they are refused above), but a hop already in the air when the dialog
	# opened would still land. Re-opening on top of itself is refused by
	# HubConfirmDialog.open(); this stops the question even being asked
	# twice.
	if _confirm.is_open():
		return
	# On a LANDING, never on an overlap: a hop aimed past a portal flies
	# straight through its volume, and entering there would take the
	# player somewhere they were only passing over. First match wins --
	# the layout keeps portals well apart, and picking one of two
	# overlapping portals deterministically beats routing to neither.
	for portal in _portals:
		if portal.landed_within(position):
			portal.enter()
			return

## Boards if the landing is close enough to the moored hull. Returns true
## when the ride started, so the caller can stop looking at that landing.
##
## The proximity test is the SAME radius the tap used, so "close enough to
## mean board" and "close enough to board from" are one number: a player
## who tapped the boat and walked to it cannot arrive and be told they are
## not there yet.
func _try_board(toward: Vector3) -> bool:
	if _route == null or not _mooring.is_available():
		_boarding = false
		return false
	var here := _keepy.global_position
	if here.distance_to(_mooring.boat_position()) > BoatMooring.BOARD_TAP_RADIUS:
		# NOT YET, and the intent SURVIVES. Clearing it here was this
		# batch's one real defect: a boarding walk longer than a single
		# hop lost its intent on the first landing, so Keepy finished the
		# walk standing beside the boat and never got in. It passed the
		# probe anyway until an unrelated tap was added ahead of it and
		# pushed the walk one hop further out -- the green had only ever
		# been the arrival happening to fall inside the radius on hop one.
		return false
	_boarding = false
	_keepy.board(_route, _ride_half_width, toward)
	return true

## The chain ran out without reaching the hull. Drops the intent rather
## than leaving it armed: a later, unrelated landing must not board.
func _on_keepy_idle() -> void:
	_boarding = false
	_climbing = false

## The hull follows the rider, and only ever from here: KeepyHopper moves
## KEEPY, the boat is decor owned by HubBuilder, and neither file reaches
## into the other's tree.
func _on_ride_moved(position: Vector3, yaw_degrees: float) -> void:
	var boat: Node3D = _builder.boat()
	if boat == null:
		return
	boat.global_position = position
	boat.rotation_degrees.y = yaw_degrees

func _on_ride_started() -> void:
	_mooring.set_riding(true)
	# RIDING THE WATER IS NOT BEING IN IT. Measured, a ride emits no
	# landings at all, so nothing can turn the tint ON mid-ride -- but a
	# boarding walk whose last landing was in the shallows would carry a
	# tint aboard and hold it for the whole crossing, because the next
	# landing that could clear it is the one after disembarking. Cleared
	# here instead of trusting the geometry: the hull is moored ON the
	# water at both ends, so that landing being wet is the ordinary case,
	# not the freak one.
	_set_keepy_wet(false)

func _on_ride_ended() -> void:
	_mooring.set_riding(false)

## A landing inside a portal now PROPOSES the sub-game instead of entering
## it. The routing table is untouched: the same game_id reaches the same
## HubRouter, one tap later, from _on_confirm_accepted below.
func _on_portal_entered(game_id: StringName, label: String) -> void:
	_confirm.open(game_id, label)

func _on_confirm_accepted(game_id: StringName) -> void:
	_router.route(game_id)

## Nothing to undo. Keepy stays exactly where they landed -- standing on a
## portal is a legal position, and shoving the player back off one would
## answer a question they just declined to answer with a movement they
## never asked for. The next tap takes them wherever they aim.
func _on_confirm_cancelled() -> void:
	pass

func _on_fallback_toggled() -> void:
	_fallback_menu.visible = not _fallback_menu.visible

func _on_fallback_chased() -> void:
	_router.route(&"chased")

func _on_fallback_quizz() -> void:
	_router.route(&"quizz")

func _on_fallback_battle() -> void:
	_router.route(&"battle")

## =====================================================================
## KEEPY TINTS TOWARD THE WATER HE IS STANDING IN
##
## The plateau's five waters are all painted one turquoise, and the part
## of Keepy BELOW the waterline is blended 75% of the way toward it while
## he is in any of them. Mathieu picked the fraction on the recon's
## rendered ladder (0/25/50/75/100% captured against the shipped camera):
## 25% reads as a lighting quirk rather than an effect, 50% is ambiguous
## between "wet" and "unwell", and 100% starts putting his palest patches
## into competition with a teal background. 75% is unambiguous with the
## silhouette, ears, eyes and badge all still fully legible.
##
## ⚠️ THE UNIFORM VERSION OF THIS SHIPPED FIRST AND WAS JUDGED
## INSUFFICIENT ON DEVICE. Tinting ALL of him turned the whole squirrel
## turquoise, which reads as "Keepy is made of water" rather than "Keepy
## is standing in water". The fraction was never the problem and is
## unchanged; WHICH PART OF HIM it applies to is what this batch fixes.
## See KEEPY_WATERLINE_Y below and the shader it drives.
##
## WHY A SHADER AND NOT A CHEAPER ROUTE -- both alternatives were MEASURED
## and neither works on this asset:
##
##   sink him and let the water draw over him -- does literally nothing.
##     An opaque mesh in front of a flat transparent plane wins the depth
##     test everywhere its silhouette draws, so 0/30/60% submerged came
##     back pixel-identical to the dry frame.
##   address head and body separately -- there is nothing to address. The
##     .glb is ONE mesh, ONE primitive, ONE material.
##
## So the split is per-fragment or it does not exist. Squash was considered
## and dropped; swimming and the boat are out of scope.
##
## The plumbing is not new. scripts/battle/FighterView.gd already tints
## THIS EXACT ASSET through a ModelSlot, and these two functions are its
## _ensure_material()/_tint_to() pair with the battle-specific parts left
## behind and a shader where its albedo write was. That file is not
## touched; it is copied from deliberately, so the two screens cannot
## drift into two different ways of recolouring one .glb.

## How long the tint takes to arrive or leave. Short enough that a landing
## is visibly its cause -- it is under a hop, so the fade is done before
## Keepy could reach the next tile.
##
## A TWEEN AND NOT A CUT, on the same reasoning every colour write in this
## project already follows: an instant swap on the landing frame reads as a
## rendering fault rather than as something that happened. The capture below
## validates the ENDPOINT (that 75% is reached, and fully removed on land);
## the duration is convention, not a measured optimum, and is said as such.
## How far toward the water's hue Keepy is taken. MATHIEU'S CALL, made on
## the recon's rendered ladder rather than on a preference -- see the block
## above for what each rung looked like. Applied identically in all five
## bodies: the waters share one hue, so being in one of them is one state,
## not five.
const KEEPY_WATER_TINT_FRACTION: float = 0.75

const KEEPY_TINT_FADE_S: float = 0.18

## The world height the waterline sits at, in metres above the plateau.
##
## MATHIEU'S CALL, made on docs/color-sheets/waterline_ladder_sheet.png --
## eight rungs rendered from the shipped camera in one pose. This is the
## "hips" rung: the water reaches Keepy's hips, and his whole upper body,
## arms and HEAD stay dry and above the surface. THESE ARE PADDLING POOLS
## and the read that matters is "he is standing in water", not "he is
## submerged in it".
##
## ⚠️ The recon recommended 0.78-0.92 and was OVERRULED, deliberately, so
## nothing here re-opens it. Its metric was the share of his silhouette
## that turns turquoise, and by that metric the low rungs look near-inert
## (wet fractions 0.021 / 0.059 / 0.110) because Keepy is modelled SITTING
## and his legs are small and self-occluded. But surface area is not the
## same as legibility of intent, and the sheet settles it: at 0.45 the
## intent reads instantly. Do not propose a higher rung.
##
## WHY A WORLD HEIGHT AND NOT A FRACTION OF HIM. A constant world Y stays
## correct the day the depths differ or swimming arrives; a fraction of
## his body would travel with him and soak him mid-air. That is not a
## hypothetical -- it is the exact difference the recon measured between
## the world-space and model-space forms of this shader, and the
## model-space one renders plausibly enough in a still frame to ship by
## accident. See assets/shaders/keepy_waterline.gdshader.
##
## ⚠️ ONE CONSTANT FOR FIVE BODIES, and it is not exact. The real surfaces
## sit at 0.0270 / 0.0295 / 0.0800 / 0.0800 / 0.0950, a spread of 0.0680
## -- 5.04% of Keepy's 1.3501. So the line lands a little differently on
## him depending on which water he is in; this batch MEASURES that spread
## rather than assuming it away, and whether it needs a constant per body
## is Mathieu's, not this file's.
const KEEPY_WATERLINE_Y: float = 0.45

# ======================= THE WATER IMPACT =======================
#
# What a dive into water gets that an ordinary landing does not: the
# waterline rides UP him for a quarter of a second, and a ring spreads on
# the surface where he went in. Both are transient, both are keyed on the
# dive's own landing, and a dive back down to the ladder foot -- dry land
# -- gets neither.
#
# ⚠️ NO PARTICLE SYSTEM, and that is a decision taken before this batch
# rather than a shortcut inside it. There is not one GPUParticles3D or
# CPUParticles3D anywhere in this repository -- not in the hub, not in
# Chased, not in Battle. Introducing the project's first one inside an
# effect nobody can look at until it reaches staging would put an unproven
# rendering technology and an unproven effect on the same commit, with no
# way to tell which of them was at fault. A MeshInstance3D with an
# unshaded material and a scale/alpha tween is the mechanism this screen
# already uses everywhere else, and it is the one used here.

## How far up Keepy the waterline is thrown by the impact, and back down
## to KEEPY_WATERLINE_Y after.
##
## The pulse is driven through the SAME uniform the shipped waterline
## uses, so the shader file is not touched by this batch at all -- and it
## must not be: the one time that shader was edited it took a device round
## trip to find that the edit had cost it its depth write. The uniform was
## already proven tweenable in the batch that shipped it, on this same
## material, and this reuses that proof rather than re-deriving it.
const KEEPY_SPLASH_WATERLINE_Y: float = 0.92

## Up fast, down slow, and the asymmetry is the whole read: an impact is a
## sudden displacement of water followed by it settling back, so a rise and
## fall of equal length would read as a pulse rather than as a splash.
## Same shape, and the same reason, as the pursuer's drop cue in Chased.
const KEEPY_SPLASH_RISE_S: float = 0.09
const KEEPY_SPLASH_FALL_S: float = 0.19

## The height the ring is drawn at, and it is ABOVE EVERY WATER SURFACE ON
## THE PLATEAU rather than at any one of them.
##
## MEASURED on the built tree, not read off the constants: the five discs'
## TOP faces sit at 0.0270 / 0.0295 / 0.0800 / 0.0800 / 0.0950. A ring at
## a body's own height would need a second copy of that body's height
## living here, and this project has already paid for one number kept in
## two files. One number that clears all five is a single inequality a
## probe can assert against the built scene, which a per-body table is not.
##
## The cost is real and is not hidden: on the great lake, whose surface is
## the lowest at 0.0270, the ring floats 0.0930 above the water -- 6.9% of
## Keepy's 1.3501. The error is deliberately in the SAFE direction. A ring
## a few centimetres high reads as spray; a ring a few centimetres low is
## drawn INSIDE the disc and reads as nothing at all, which is exactly
## what the isolation probe rendered when this constant was first written
## against the disc's centre instead of its top face.
const SPLASH_RING_Y: float = 0.12

## The ring's reach, in metres, at the end of its spread.
const SPLASH_RING_RADIUS: float = 1.15

## How long the ring takes to open, and how long it lives. It fades over
## the whole of its life while it is still spreading, so it never sits
## still at full size -- a ring that stops is a prop, a ring that is still
## moving when it disappears is a splash.
const SPLASH_GROW_S: float = 0.20
const SPLASH_LIFE_S: float = 0.34

## The ring's colour. Near-white rather than the water's own hue: the
## water is already turquoise at 0.95 alpha, and a turquoise ring on it
## separates only by alpha. Both were rendered -- see the sheet named in
## the batch notes -- and this is a starting value for a device call, not
## a measured optimum.
const SPLASH_RING_COLOR: Color = Color(0.918, 1.0, 0.988, 0.85)

## Tessellation, stated rather than defaulted. A Godot TorusMesh left
## alone is 64x32, i.e. 4096 triangles for one transient node -- the exact
## "primitive left at the engine default" trap this project has now
## measured five separate times. 24 ring segments keep the circle round at
## this size; the tube is nearly edge-on to the camera and needs almost
## nothing.
const SPLASH_RING_SEGMENTS: int = 24
const SPLASH_TUBE_SEGMENTS: int = 4

## The waterline shader, applied to Keepy's own material rather than to a
## whole-body property. See the shader for why the split cannot be done
## any other way on this asset.
const KEEPY_WATERLINE_SHADER: Shader = preload(
	"res://assets/shaders/keepy_waterline.gdshader")

## Aims the tint at wet or dry, doing nothing when that has not changed.
##
## The uniform is tweened EXACTLY as albedo_color used to be -- measured on
## a live ShaderMaterial before this batch was written, because a uniform
## that could not be tweened would have cost the fade the whole project's
## colour writes are built on: 0.4986 mid-tween, 0.7500 final, the same
## numbers the property gave.
func _set_keepy_wet(wet: bool) -> void:
	if wet == _keepy_wet and _keepy_material_resolved:
		return
	_keepy_wet = wet
	_ensure_keepy_material()
	if _keepy_material == null:
		return
	# HOW FAR the submerged part is carried, not WHICH part -- the shader
	# owns the split, and it owns it in world space, so this value never
	# has to know where Keepy is. Zero is a true no-op: the shader still
	# samples his texture and mixes nothing into it.
	var target := KEEPY_WATER_TINT_FRACTION if wet else 0.0
	if _keepy_tint_tween != null and _keepy_tint_tween.is_valid():
		_keepy_tint_tween.kill()
	_keepy_tint_tween = create_tween()
	_keepy_tint_tween.tween_property(
		_keepy_material, "shader_parameter/tint_fraction", target, KEEPY_TINT_FADE_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Takes ownership of a material this screen may recolour.
##
## LAZY, and never written THROUGH -- both load-bearing, and both for the
## reasons FighterView.gd already documents on this same asset:
##
##   lazy      -- the slot is only carrying its final model once the model
##                has installed; resolving in _ready() can catch the scene's
##                authored placeholder instead.
##   not written through -- Godot's glTF importer binds ONE shared material
##                on the mesh itself, so writing the material the slot hands
##                back would tint every instance of keepy_squirrel_hero.glb
##                in the project. Battle's player fighter is the same .glb.
##
## ⚠️ The shipped code USED to satisfy that second point with duplicate().
## It no longer duplicates anything: a brand-new ShaderMaterial is built
## and bound over the top, which is strictly safer (a material this
## function constructed cannot be shared with anything) but is NOT the same
## mechanism, and a comment still claiming duplicate() would send the next
## reader looking for a call that is not there.
##
## An asset whose slot material is not a StandardMaterial3D leaves
## _keepy_material null and every tint call above no-ops. Keepy stops
## changing colour in water; nothing else on this screen notices.
##
## WHAT IT READS OFF THE OLD MATERIAL, and why the read is still needed
## even though the material is replaced: the model's entire colour lives
## in its baseColorTexture, and the shader has to sample the same one or
## Keepy loses his markings, his badge and his eyes. albedo_color is NOT
## carried over -- it is (1,1,1,1) on this asset, i.e. a no-op multiply,
## and folding a would-be tint into it is exactly the whole-body effect
## this batch replaces.
## Armed by the dive leaving the board. See _dive_pending for why the
## landing cannot work this out for itself.
func _on_board_dived() -> void:
	_dive_pending = true

## A dive that ended IN WATER. Never called for the board's other target,
## the ladder foot, which is dry land.
func _on_water_impact(position: Vector3) -> void:
	_pulse_keepy_waterline()
	_spawn_impact_ring(position)

## Throws the waterline up Keepy and lets it settle back.
##
## ⚠️ IT ALWAYS ENDS ON KEEPY_WATERLINE_Y, and that is load-bearing rather
## than tidy. This uniform is the shipped waterline; a pulse that was
## interrupted and left it high would leave Keepy soaked to the shoulders
## for the rest of the session, on dry land included, with nothing to say
## why. So the previous pulse is KILLED rather than allowed to finish, and
## the fall is part of the same tween as the rise -- there is no path
## through this function that raises the line without also scheduling its
## return.
func _pulse_keepy_waterline() -> void:
	_ensure_keepy_material()
	if _keepy_material == null:
		return
	if _keepy_waterline_tween != null and _keepy_waterline_tween.is_valid():
		_keepy_waterline_tween.kill()
	_keepy_waterline_tween = create_tween()
	_keepy_waterline_tween.tween_property(
		_keepy_material, "shader_parameter/water_y",
		KEEPY_SPLASH_WATERLINE_Y, KEEPY_SPLASH_RISE_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_keepy_waterline_tween.tween_property(
		_keepy_material, "shader_parameter/water_y",
		KEEPY_WATERLINE_Y, KEEPY_SPLASH_FALL_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## The ring on the surface: one MeshInstance3D, built here, spread and
## faded, then freed.
##
## ⚠️ CULL_BACK, NOT CULL_DISABLED, and this is the batch's one carried
## scar. A torus is a CLOSED body. The waterline shader's device failure
## was an alpha-writing material with cull_disabled on a closed body: with
## no depth write, the far side paints over the near side in index-buffer
## order, which is fixed while which-side-is-far is not -- so the picture
## comes out right at some yaws and wrong at others. An alpha ring lying
## next to an alpha water disc is the same neighbourhood, so the back
## faces are dropped and only the near surface ever draws.
##
## Parented to the 3D world root and never to Props -- see _world.
func _spawn_impact_ring(position: Vector3) -> void:
	if _world == null:
		return
	var torus := TorusMesh.new()
	# Authored at unit-ish size and grown by SCALE, so one mesh serves any
	# reach and the tween has a single property to drive.
	torus.inner_radius = 0.78
	torus.outer_radius = 1.0
	torus.rings = SPLASH_RING_SEGMENTS
	torus.ring_segments = SPLASH_TUBE_SEGMENTS

	var material := StandardMaterial3D.new()
	# UNSHADED, the project's standing rule for every surface on this
	# screen: there is no DirectionalLight3D in this scene at all, so a lit
	# surface would not return the colour written here.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SPLASH_RING_COLOR
	# Asked for explicitly. albedo_color's alpha is ignored outright while
	# transparency stays DISABLED -- the ring would pop in fully opaque and
	# never fade, with no error to say so. The same trap the water discs
	# themselves carry a comment about.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_BACK

	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.set_surface_override_material(0, material)
	# FLAT IN THE WATER'S OWN PLANE. A torus is authored standing up, so
	# the quarter turn is what lays it down; a ring lying on the surface
	# reads as the water moving, where an upright one reads as a sign
	# planted in it.
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring.position = Vector3(position.x, SPLASH_RING_Y, position.z)
	ring.scale = Vector3.ONE * 0.001
	_world.add_child(ring)

	# The tween is created ON THE RING, so it is bound to it: if anything
	# frees the ring early the tween goes with it instead of writing to a
	# freed object.
	var grow := ring.create_tween()
	grow.set_parallel(true)
	grow.tween_property(ring, "scale", Vector3.ONE * SPLASH_RING_RADIUS, SPLASH_GROW_S) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.tween_property(material, "albedo_color:a", 0.0, SPLASH_LIFE_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# EXPLICIT, and chained after the parallel block rather than left to
	# the node outliving the scene. A cue that leaks one node per dive is a
	# leak that only shows up after a long session, which is the hardest
	# kind to attribute later.
	grow.chain().tween_callback(ring.queue_free)

func _ensure_keepy_material() -> void:
	if _keepy_material_resolved:
		return
	_keepy_material_resolved = true
	var slot := _keepy.body_slot()
	if slot == null:
		return
	var current := slot.slot_material() as StandardMaterial3D
	if current == null:
		return
	var shaded := ShaderMaterial.new()
	shaded.shader = KEEPY_WATERLINE_SHADER
	shaded.set_shader_parameter("albedo_texture", current.albedo_texture)
	shaded.set_shader_parameter("water_color", HubWater.hue())
	shaded.set_shader_parameter("water_y", KEEPY_WATERLINE_Y)
	# Starts DRY. The first landing decides the rest; until one arrives,
	# a zero fraction is indistinguishable from the material this replaces.
	shaded.set_shader_parameter("tint_fraction", 0.0)
	_keepy_material = shaded
	slot.apply_material(_keepy_material)
