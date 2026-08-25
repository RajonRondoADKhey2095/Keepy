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

	_tap.tapped_ground.connect(_on_tapped_ground)
	_tap.tapped_boat.connect(_on_tapped_boat)
	_keepy.hop_landed.connect(_on_hop_landed)
	_keepy.ride_moved.connect(_on_ride_moved)
	_keepy.ride_started.connect(_on_ride_started)
	_keepy.ride_ended.connect(_on_ride_ended)

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
	# Any ordinary tap cancels a boarding walk in progress: the player
	# aimed somewhere else, and arriving at the boat anyway would be the
	# screen overruling them.
	_boarding = false
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
	_keepy.hop_to(point)
	# Already standing at the boat: nothing to walk, so board on the spot
	# rather than waiting for a landing that will never come.
	if not _keepy.is_hopping():
		_try_board(point)

func _on_hop_landed(position: Vector3) -> void:
	# NO PORTAL WHILE ABOARD. A ride emits no landings, so this branch
	# should never be reached mid-ride -- it is here because "no landing is
	# emitted" is a property of another file that could change, and the
	# failure it would cause (being carried into a sub-game the player was
	# only sailing past) is exactly the kind that only shows up on device.
	if _keepy.is_riding():
		return
	# The landing that finishes a boarding walk starts the ride, before
	# anything else looks at where it landed.
	if _boarding and _try_board(position):
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
	_boarding = false
	if _route == null or not _mooring.is_available():
		return false
	var here := _keepy.global_position
	if here.distance_to(_mooring.boat_position()) > BoatMooring.BOARD_TAP_RADIUS:
		return false
	_keepy.board(_route, _ride_half_width, toward)
	return true

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
