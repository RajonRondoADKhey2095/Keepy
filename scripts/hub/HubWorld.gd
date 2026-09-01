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
## LOT B SPIKE, DISPOSABLE and STAGING-ONLY: device access to the isolated
## bear-rig scene, in the SAME place and the SAME shape the multi-level nav
## bench used for its own device pass ("Test nav (dev)", b7e641b, retired by
## 1504982). The hub's fallback menu is this repo's one established entry
## point for an isolated test scene -- there is no debug menu anywhere else,
## and the cabin is not reached through one either: CabinInterior.tscn is
## ordinary gameplay, HubRouter.ROUTES[&"cabin"], entered by tapping the
## doorstep marker on the plateau.
##
## Deliberately NOT routed through HubRouter.ROUTES: that table is production
## routing, and this is a throwaway bench. Remove this node, this @onready
## line, the signal connection below and _on_fallback_spike() together, in
## the same lot that retires scenes/test/BearAnimSpike.tscn.
@onready var _spike_button: Button = $FallbackMenu/Panel/VBoxContainer/SpikeButton
@onready var _mooring: BoatMooring = $Mooring
@onready var _camera: HubCamera = $WorldViewport/SubViewport/World/Camera3D

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

## The spinner entry Keepy is currently riding, empty when he is not on
## one. Held rather than re-searched so the dismount lands off the prop he
## actually rode, even if a layout ever grows a second one.
var _turnstile_ride: Dictionary = {}

## Every seesaw, copied out of the builder in _ready() with a "tween" slot
## added, and the one Keepy is riding. Held apart from _spinners rather than
## merged into it: the two props move on DIFFERENT AXES -- a spinner's yaw,
## a seesaw's tilt -- so one list would need a discriminator on every read,
## which is a case statement pretending to be a table. The SHAPE of the two
## registries is deliberately identical, and that is what the seesaw
## actually reuses.
var _seesaws: Array[Dictionary] = []
var _seesaw_ride: Dictionary = {}

## Every owl, as _setup_owls copied it, plus the per-prop tween slot; and
## the one entry currently carrying Keepy.
var _owls: Array[Dictionary] = []
var _owl_ride: Dictionary = {}

## Every cabin, as _setup_cabins copied it.
##
## No per-prop tween slot, unlike the spinners, the seesaws and the owls,
## and no "the one he is inside" companion either -- unlike all three of
## them. Nothing here is ever animated and nothing has to be put back,
## because since 29 aout 2026 a cabin is not a ride at all: it is a SCENE
## CHANGE. There is no carrier to restore, no visit to remember, and no
## state on this screen that outlives the tap -- the whole of the interior
## lives in CabinInterior.tscn, and this screen stops existing while the
## player is in there.
var _cabins: Array[Dictionary] = []

## One doorstep mark per cabin, held so _process can pulse them.
##
## ⚠️ THE WHOLE POINT OF THIS BATCH, and the omission it repairs: the
## previous lot marked the ladder, the bed and the door INSIDE the cabin
## and marked nothing OUT HERE, so the one door in the game that leads to
## a new scene was the one with no ring around it. A player who had been
## taught by three portals what a tappable spot looks like walked up to the
## tree-house and found nothing to aim at.
##
## Held in a plural array for the reason _cabins is: nothing here names THE
## cabin, and a layout with two of them gets two marks rather than one.
var _cabin_markers: Array[CabinMarker] = []

## A tap on a doorstep armed a walk to it, and the landing that finishes
## that walk should take him inside. Exactly the latch _boarding, _climbing
## and _flying already are, and cleared on the same three occasions:
## another tap, a successful entry, or the chain running out without
## arriving.
##
## What differs from those three is what "a successful entry" DOES: they
## hand the body to a ride state on this screen, this one leaves the screen
## entirely. The latch is still needed for exactly the reason theirs are --
## the walk to the door takes several hops and the intent has to survive
## every landing that has not arrived yet.
var _entering: bool = false

## A tap on a perch armed a walk to it, and the landing that finishes that
## walk should start the flight. Exactly the latch _boarding and _climbing
## already are, and cleared on the same three occasions: another tap, a
## successful mount, or the chain running out without arriving.
var _flying: bool = false

## Armed by a dismount, consumed by the landing it produces.
##
## ⚠️ WITHOUT IT THIS FEATURE LOOPS FOREVER. A dismount ends in an ordinary
## landing, and an ordinary landing near the prop is exactly what mounts
## him -- so a dismount that came down inside the trigger radius would put
## him straight back on. The exit point is measured to clear that radius,
## which makes the latch unreachable today; it is written anyway because
## "the exit lands far enough away" is a fact about GEOMETRY AND LAYOUT,
## and layouts are edited without this file being reread. Same argument the
## dive gate below already makes, and the same shape as _dive_pending.
var _dismount_pending: bool = false

## How far the top swings when a landing sets it going, and over how long.
##
## EASE_OUT, and that is the whole reading: a real roundabout is shoved
## once and then coasts down. A linear spin or an ease-in-out would both
## read as a machine being driven rather than as something that was pushed.
const TURNSTILE_SPIN_TURNS: float = 1.5
const TURNSTILE_SPIN_S: float = 2.2

## How far outside a spinning prop's own footing a dismount aims.
##
## The landing has to clear the TRIGGER radius and not merely the footing:
## coming down inside the trigger would shove the prop again on the way
## off, which reads as the roundabout restarting itself the moment you let
## go. A step past that is the smallest margin that also leaves room for
## the body, which overhangs the deck.
const TURNSTILE_EXIT_MARGIN: float = 0.85

## How far round the prop the exit search may walk when the outward point
## is occupied, and in how many steps. It walks AROUND rather than further
## OUT for the reason the boat's bank search walks along the stream: the
## ring at one radius is fresh ground, while pushing outward only finds
## more of whatever is already in that direction.
const TURNSTILE_EXIT_ARC_DEG: float = 150.0
const TURNSTILE_EXIT_STEPS: int = 24

## How far the plank tilts, how many times it crosses level before it
## settles, and over how long.
##
## A DAMPED ROCK, not a spin: the shape is cos(TAU * cycles * t) * (1 - t),
## which starts at full tilt on the rider's side -- his weight -- crosses
## level SEESAW_ROCK_CYCLES times and arrives at exactly zero. Level at the
## end is arithmetic and not tuning: the (1 - t) factor is zero at t = 1
## whatever the cosine is doing, so the plank can never be left leaning.
##
## The tween that drives it is LINEAR on purpose. The easing IS the cosine;
## an EASE_OUT on top would ease an already-eased curve and the rock would
## stop looking like a rock.
const SEESAW_TILT_DEG: float = 15.0
const SEESAW_ROCK_CYCLES: float = 2.5
const SEESAW_ROCK_S: float = 2.4

## How much room a landing needs on top of whatever it is standing next to.
##
## Keepy's own half-width, MEASURED on the shipped .glb: the model is
## 1.3198 across, so half of it is 0.6599. Deliberately the WIDTH and not
## the depth (2.0371, which is mostly tail) -- the depth is the same
## overhang the boat's bank search already tolerates, and demanding a metre
## of clearance in every direction would refuse most of a plateau this
## densely scattered.
## How close a tap has to land to an owl perch to mean "fly with it", in
## world units -- and, because they are one number rather than two, also
## how close the arrival has to be to actually take off, and the ring the
## dismount is thrown clear on.
##
## SMALLER than the boat's and the ladder's 2.5, and measured rather than
## copied down. Those two are 2.5 because the thing aimed at is tiny: a
## ladder foot is half a unit across and would be a target nobody could hit
## at this camera distance. The owl is 1.39 x 1.53 on the ground and 2.04
## tall -- a far bigger mark -- and 2.5 centred on a perch 2.8 units from
## the spawn would have reached back over Keepy's own feet, so a tap at his
## toes would have meant "fly". 1.8 still leaves a comfortable margin round
## a prop 1.5 wide and leaves the spawn a full unit outside it.
const OWL_TAP_RADIUS: float = 1.8

## How close a tap has to land to a cabin's DOORWAY to mean "go in".
##
## SIZED ON THE DOORWAY, NOT ON THE BUILDING, and that is the correction
## this constant carries. It used to be 2.2, argued from the prop being
## "bigger than the owlet" -- an argument about the VOLUME, which is the
## one quantity a doorstep must not track. A door is the same size on a
## shed and on a cathedral, because the thing that has to fit through it is
## Keepy, and Keepy does not scale.
##
## THE DEFECT THAT CAME OF TRACKING THE BUILDING, measured rather than
## reasoned. With the old scaled doorstep, the disc this radius draws
## overlapped the cabin by 18.2% at scale 1 -- it HUGGED the prop, so
## "tap the cabin" and "tap the doorstep" were one gesture -- and by 0.0%
## at scale 3.5, where it had become a 4.4-unit band of invisible lawn
## floating 2.3 u in FRONT of the wall, 473-617 px wide on a 1080-wide
## screen. A player walking up to look at the cabin tapped that lawn, and
## the tap he meant as "walk there" was spent as "go inside". That is the
## whole of the report: he was not aspirated, he was ANSWERED -- one tap,
## one signal, and the signal he got was not the one he aimed.
##
## 1.30 is read off the behaviour that WORKED rather than picked: with the
## doorstep now held a flat 0.70 u off the wall at every scale, 1.30 puts
## 17.5% of the disc back on the building -- the 18.2% the shipped scale-1
## cabin had. It is scale-INVARIANT by construction, which is the point:
## the same 17.5% at 3.5 and at 7.0.
##
## NOT SCALED, and no future scale-up may make it so. If a bigger cabin
## ever needs a bigger door, the thing to grow is CABIN_DOOR_STANDOFF -- 
## where the visitor stands -- not how much lawn counts as the doorway.
const CABIN_TAP_RADIUS: float = 1.30

## What the doorstep's sign says.
##
## Stated HERE, beside the radius, and NOT read out of the layout the way
## the three portals read theirs. The layout entry for a cabin carries no
## `label` key at all, and adding one would mean a schema every future
## cabin has to fill in for a sign that would say the same word every time.
## The radius is already this file's to own; the word on the mark and the
## circle under it are one fact about what that doorstep is, so they live
## together.
const CABIN_DOOR_LABEL: String = "Cabane"

## How close he has to have ARRIVED to actually go in.
##
## DELIBERATELY LOOSER THAN THE TAP, by exactly the hop chain's own
## slack. _advance() stops when the remaining distance is within
## ARRIVE_EPSILON, so a walk aimed at a point R from the door can legally
## finish R + ARRIVE_EPSILON from it. Testing arrival at the tap's own R --
## which is what a single shared radius did -- leaves a player who tapped
## the rim of the doorstep walking all the way there and being told he is
## not there yet, with the intent still armed and nothing to show for it.
##
## Harmless to widen, because this is only ever consulted once _entering is
## already armed BY A DELIBERATE TAP: it decides whether a walk that was
## already meant as "go in" has got there, never whether a tap meant it.
const CABIN_ARRIVE_RADIUS: float = CABIN_TAP_RADIUS + KeepyHopper.ARRIVE_EPSILON

## How long the whole loop takes, perch to perch.
##
## Named rather than left in the call for the reason TURNSTILE_SPIN_S is,
## and the dismount hangs off the tween's own `finished` rather than off a
## copy of this number -- a second "how long a flight lasts" is a second
## number to keep in step, and the two drift the first time either is
## tuned. Within the 3.0-3.5 s the batch was scoped to; a device pass moves
## this constant and nothing else.
const OWL_FLIGHT_S: float = 3.2

## The loop, in world units: how far out to the side it swings, and how
## high it climbs at the far point.
##
## The path is a CIRCLE through the perch, so it closes EXACTLY -- see
## _apply_flight for why that is arithmetic rather than a setting. The
## radius puts the far point 2 x OWL_LOOP_RADIUS in front of the perch,
## which is where the loop is most visible from a camera that never yaws.
const OWL_LOOP_RADIUS: float = 3.2
const OWL_LOOP_APEX: float = 3.6

## Which way the loop leans off the perch, in degrees about Y.
##
## MEASURED, NOT PICKED. At zero the circle swings a full radius to either
## side of the perch, and the perch is already left of centre -- so the
## return leg left the frame: 26 of 33 sampled points on screen, the owl
## flying out and vanishing before it came back. Swept against the real
## camera at BOTH shipped ratios (1080x1920 and 1170x2532) with
## unproject_position, over radius and heading together: -35 degrees is the
## first heading that keeps the WHOLE loop on screen at the full radius,
## with about 100 px of margin at the tighter of the two. Leaning it
## further buys more margin and less of the plateau; leaning it back loses
## the left edge again.
const OWL_LOOP_HEADING_DEG: float = -35.0

const KEEPY_CLEARANCE: float = 0.66


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
	_setup_seesaws()
	_setup_owls()
	_tap.tapped_owl.connect(_on_tapped_owl)
	_setup_cabins()
	_tap.tapped_cabin.connect(_on_tapped_cabin)
	_tap.tapped_boat.connect(_on_tapped_boat)
	_keepy.hop_landed.connect(_on_hop_landed)
	_keepy.ride_moved.connect(_on_ride_moved)
	_keepy.ride_started.connect(_on_ride_started)
	_keepy.ride_ended.connect(_on_ride_ended)
	_keepy.became_idle.connect(_on_keepy_idle)
	_keepy.board_dived.connect(_on_board_dived)

	_confirm.confirmed.connect(_on_confirm_accepted)
	_confirm.cancelled.connect(_on_confirm_cancelled)

	# LAST, and after every _setup_* above: this moves Keepy, and the
	# camera snap it ends with has to be the final word on where the frame
	# opens. Placed before the builder had run it would be a spawn onto a
	# plateau that does not exist yet.
	_consume_return_spawn()

	_fallback_button.pressed.connect(_on_fallback_toggled)
	_fallback_close.pressed.connect(_on_fallback_toggled)
	_chased_button.pressed.connect(_on_fallback_chased)
	_quizz_button.pressed.connect(_on_fallback_quizz)
	_battle_button.pressed.connect(_on_fallback_battle)
	_spike_button.pressed.connect(_on_fallback_spike)

## Puts Keepy back where he left the plateau, when something asked.
##
## =====================================================================
## WHY THIS EXISTS -- and why only the cabin uses it
##
## Every other way back to this screen is a return from a SUB-GAME: you
## went somewhere else entirely and you come back to the middle of the
## plateau, which is what HubWorld.tscn's transform-less Keepy node gives
## for free. A DOOR is different: walking out of the cabin has to put you
## in front of the cabin, and nothing in the scene file can say so because
## the door coordinate is derived from the layout at build time.
##
## The pending spawn is CONSUMED (HubSpawn.take clears as it returns), so
## the next ordinary return -- out of Chased, say -- lands at the origin
## the way it always has, rather than at a door the player left an hour
## ago.
##
## ⚠️ THE CAMERA SNAP IS NOT OPTIONAL. HubCamera._ready() runs BEFORE this
## one (children are readied first) and snaps to Keepy at the origin, so
## without the second snap the screen would open on the middle of the
## plateau and then slide to the cabin over the first second. That reads as
## the camera catching up, not as coming out of a door.
func _consume_return_spawn() -> void:
	if not HubSpawn.has_pending():
		return
	var where: Vector3 = HubSpawn.take()
	_keepy.global_position = Vector3(where.x, 0.0, where.z)
	_camera.snap_to_target()

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
		# Copied WHOLESALE and then given the tween slot, rather than
		# listing the keys one by one: the registry grew four fields when
		# the turnstile became ridable, and a hand-written copy is exactly
		# the thing that silently drops the fifth.
		var entry: Dictionary = prop.duplicate()
		entry["tween"] = null
		_spinners.append(entry)


## Copies the built seesaws out of the builder, once, adding the per-prop
## tween slot. Wholesale duplicate() and then the slot, for the reason
## _setup_spinners() states: listing keys by hand is exactly the thing that
## silently drops the one added last.
func _setup_seesaws() -> void:
	for prop in _builder.seesaws():
		var entry: Dictionary = prop.duplicate()
		entry["tween"] = null
		_seesaws.append(entry)

## Copies the built owls out of the builder, once, adding the per-prop
## tween slot and the ONE reach this prop is measured with -- and then
## hands the perches to the tap so a finger can pick them out.
##
## The reach is added HERE rather than published by the builder because it
## is a TAP radius, and the two props that publish their own ("radius" on
## the turnstile and the seesaw) are triggered by a landing, where how near
## is a property of the prop. Writing it into the copied entry rather than
## reading the constant at three call sites is what makes "near enough to
## tap", "near enough to take off" and "far enough to be dropped clear" one
## number instead of three that can drift -- and is what lets the dismount
## reuse _ride_exit_point() unchanged, since that function only ever reads
## "position" and "radius" and knows nothing about any particular prop.
func _setup_owls() -> void:
	for prop in _builder.owls():
		# Copied WHOLESALE and then given the extra keys, for the reason
		# _setup_spinners() states: a hand-written copy is exactly the
		# thing that silently drops the field added last.
		var entry: Dictionary = prop.duplicate()
		entry["tween"] = null
		entry["radius"] = OWL_TAP_RADIUS
		_owls.append(entry)
	if _owls.is_empty():
		return
	var perches: Array[Vector3] = []
	for entry in _owls:
		perches.append(entry["position"])
	_tap.owl_perches = perches
	_tap.owl_radius = OWL_TAP_RADIUS

## A tap on an owl perch. ONE tap buys the whole thing -- the hop chain
## walks to the perch and _on_hop_landed takes off on arrival -- because
## that is exactly how a tap on the boat and on the ladder already behave.
func _on_tapped_owl(point: Vector3) -> void:
	if _fallback_menu.visible or _confirm.is_open():
		return
	if _keepy.is_riding() or _keepy.is_on_board():
		return
	_boarding = false
	_climbing = false
	_flying = true
	_keepy.hop_to(point)
	# Already standing at the perch: nothing to walk, so take off on the
	# spot rather than waiting for a landing that will never come.
	if not _keepy.is_hopping():
		_try_fly(_keepy.global_position)

## Takes off if the landing is close enough to a perch. Returns true when
## the flight started, so the caller can stop looking at that landing.
##
## The proximity test is the SAME radius the tap used, for the reason the
## boat's and the ladder's are: a player who tapped the owl and walked to
## it cannot arrive and be told they are not there yet.
##
## NEAREST perch and not first-match, on the ladder's terms: "first" is a
## fact about the layout file, and the player is standing at a place. And
## the intent SURVIVES a landing that has not arrived yet -- that was the
## boarding walk's own defect, which passed its probe for a whole batch
## because the arrival happened to fall inside the radius on hop one.
func _try_fly(position: Vector3) -> bool:
	if _owls.is_empty():
		_flying = false
		return false
	var flat := Vector3(position.x, 0.0, position.z)
	var entry: Dictionary = {}
	var nearest: float = INF
	for candidate in _owls:
		var d: float = flat.distance_to(candidate["position"] as Vector3)
		if d < nearest:
			nearest = d
			entry = candidate
	if nearest > OWL_TAP_RADIUS:
		return false
	var carrier: Node3D = entry.get("carrier")
	if carrier == null or not is_instance_valid(carrier):
		_flying = false
		return false
	if not _keepy.mount_owl(carrier, float(entry["seat_y"])):
		return false
	_flying = false
	_owl_ride = entry
	# The perch stops accepting taps for the length of the flight, so a tap
	# meanwhile falls through to the ground path exactly as the boat's does
	# -- which is what leaves it free to mean something else instead of
	# being swallowed by a prop that is not there any more.
	_tap.owl_available = false
	var flight: Tween = _build_owl_flight(entry)
	flight.finished.connect(_on_owl_flight_finished, CONNECT_ONE_SHOT)
	return true

## Builds and starts the flight tween for `entry`, and returns it.
##
## tween_method on a NORMALISED t, for the turnstile's measured reason: the
## rider is written in the same call as the carrier, so he cannot be a
## frame behind the bird he is sitting on -- see _apply_flight.
##
## LINEAR, deliberately. The shape of the flight is already in the curve:
## the horizontal sweep is a circle walked at constant angular rate and the
## height is a sine, so it already leaves slowly, climbs, and settles. An
## ease laid over that would be a second easing on top of one that is
## already there -- the argument _build_seesaw_rock makes about its own
## damped cosine.
func _build_owl_flight(entry: Dictionary) -> Tween:
	var carrier: Node3D = entry["carrier"]
	var tween := carrier.create_tween()
	tween.tween_method(_apply_flight.bind(entry), 0.0, 1.0, OWL_FLIGHT_S)
	entry["tween"] = tween
	return tween

## Moves the owl to its place on the loop at `t`, and -- in the SAME call,
## immediately after -- moves whoever is riding it.
##
## ⚠️ THE CLOSURE IS ARITHMETIC, NOT A SETTING, and that is the whole
## reason this curve was chosen over a hand-placed path. Every term is
## periodic in t and evaluates to exactly the perch at both ends:
##
##   x  = R * sin(TAU * t)          sin(0) = sin(TAU) = 0
##   z  = -R * (1 - cos(TAU * t))   cos(0) = cos(TAU) = 1, so both are 0
##   y  = APEX * sin(PI * t)        sin(0) = sin(PI) = 0
##
## so the owl is back on its perch at t = 1 because the trigonometry says
## so, not because a duration and a speed were tuned until it looked
## closed. That is a circle of radius R through the perch, centred R in
## front of it, which puts the far point of the loop 2R ahead -- the part
## of the plateau a camera that never yaws is actually looking at.
##
## The yaw is the TANGENT of that circle, which is never zero-length: a
## bird banking through a turn faces where it is going, and there is no
## degenerate instant to guard for the way a straight path between two
## points has at its ends.
func _apply_flight(t: float, entry: Dictionary) -> void:
	var carrier: Node3D = entry["carrier"]
	if carrier == null or not is_instance_valid(carrier):
		return
	var perch: Vector3 = entry["position"]
	var angle: float = TAU * t
	var lean: float = deg_to_rad(OWL_LOOP_HEADING_DEG)
	# The circle, in the perch's own frame, then LEANED -- see
	# OWL_LOOP_HEADING_DEG for why the lean is measured rather than chosen.
	# Rotating the offset rather than reshaping the curve is what keeps the
	# closure above true: a rotation of zero is still zero.
	var offset := Vector3(
		OWL_LOOP_RADIUS * sin(angle),
		0.0,
		-OWL_LOOP_RADIUS * (1.0 - cos(angle))).rotated(Vector3.UP, lean)
	carrier.global_position = Vector3(
		perch.x + offset.x,
		OWL_LOOP_APEX * sin(PI * t),
		perch.z + offset.z)
	# The tangent of that same circle, leaned by the same angle -- one
	# rotation applied to both, so the bird cannot face off its own path.
	var tangent := Vector3(cos(angle), 0.0, -sin(angle)).rotated(Vector3.UP, lean)
	carrier.rotation_degrees.y = rad_to_deg(atan2(tangent.x, tangent.z))
	# Only the rider of THIS prop, and only while he is actually aboard.
	if _keepy.is_on_owl_flight() and not _owl_ride.is_empty() \
			and _owl_ride.get("carrier") == carrier:
		_keepy.follow_owl()

## The loop has closed, so the rider steps off and the perch takes taps
## again.
##
## The owl is put back EXPLICITLY rather than left wherever the last tween
## step happened to write it. The curve closes exactly, so this should be a
## no-op to the float -- which is precisely why it is cheap, and why a
## flight that was ever cut short (a tween killed, a scene torn down
## mid-loop) still leaves a perch with an owl on it rather than an owl
## stranded in the air.
func _on_owl_flight_finished() -> void:
	_tap.owl_available = true
	if _owl_ride.is_empty():
		return
	var entry: Dictionary = _owl_ride
	var carrier: Node3D = entry.get("carrier")
	if carrier != null and is_instance_valid(carrier):
		carrier.global_position = entry["position"]
		carrier.rotation_degrees.y = 0.0
	_owl_ride = {}
	if not _keepy.is_on_owl_flight():
		return
	# The same ring the turnstile and the seesaw are dropped clear on, and
	# the same function: it reads "position" and "radius" and knows nothing
	# about any particular prop, so the owl needed it rather than a copy.
	_keepy.leave_owl(_ride_exit_point(entry))

func _setup_cabins() -> void:
	for prop in _builder.cabins():
		# Copied WHOLESALE and then given the extra key, for the reason
		# _setup_spinners() states: a hand-written copy is exactly the thing
		# that silently drops the field added last.
		var entry: Dictionary = prop.duplicate()
		entry["radius"] = CABIN_TAP_RADIUS
		_cabins.append(entry)
	if _cabins.is_empty():
		return
	var doors: Array[Vector3] = []
	for entry in _cabins:
		doors.append(entry["door"])
	_tap.cabin_doors = doors
	_tap.cabin_radius = CABIN_TAP_RADIUS
	_build_cabin_markers()

## The doorstep marks, one per cabin.
##
## ⚠️ BUILT FROM THE SAME TWO FACTS THE TAP TEST IS ASKED ABOUT -- the
## door point published by the builder and CABIN_TAP_RADIUS -- and not from
## a second position or a second size. The mark a player aims at and the
## circle HubTapInput measures are then one number: a marker can never be
## drawn beside the trigger, or smaller than it, because there is nothing
## for it to be drawn beside.
##
## ⚠️ ALWAYS VISIBLE, PULSING WHEN NEAR, which is the PORTALS' behaviour
## and not a new one. That was a decision to take rather than a default:
## a mark that only appears once you are close cannot tell you where to go,
## and the three portals across the plateau are already permanent. The
## brief asked for consistency with what ships, and what ships is
## permanent-plus-pulse.
##
## Parented to the SAME node the props are, so the marker is in world space
## beside the cabin rather than a child of it -- a mark hung under a prop
## would take that prop's scale, and this cabin is drawn at 7.0.
func _build_cabin_markers() -> void:
	for entry in _cabins:
		var marker := CabinMarker.new()
		# HUB_GRASS, which is the portals' own amber and dark green rather
		# than the cabin's cream -- and NOT because the cream would fail
		# out here. Measured on a real render at this very doorstep the
		# cream scores 4.76:1 against the lawn and the amber 3.16:1, so
		# contrast argues the other way. It is drawn in the portals' ink
		# because it is the fourth thing on this plateau that a tap takes
		# you somewhere else, and the other three look like this. See
		# CabinMarker for the full table.
		marker.setup(CABIN_TAP_RADIUS, CABIN_DOOR_LABEL,
				CabinMarker.Surface.HUB_GRASS)
		marker.position = entry["door"] as Vector3
		_builder.add_child(marker)
		_cabin_markers.append(marker)

## A tap on a cabin doorstep. ONE tap buys the whole thing -- the hop chain
## walks to the door and _on_hop_landed goes in on arrival -- because that
## is exactly how a tap on the boat, the ladder and the perch already
## behave.
func _on_tapped_cabin(point: Vector3) -> void:
	if _fallback_menu.visible or _confirm.is_open():
		return
	if _keepy.is_riding() or _keepy.is_on_board():
		return
	_boarding = false
	_climbing = false
	_flying = false
	_entering = true
	_keepy.hop_to(point)
	# Already standing at the door: nothing to walk, so go in on the spot
	# rather than waiting for a landing that will never come.
	if not _keepy.is_hopping():
		_try_enter_cabin(_keepy.global_position)

## Goes inside if the landing is close enough to a doorstep. Returns true
## when he went in, so the caller can stop looking at that landing.
##
## The proximity test is the tap's radius PLUS the hop chain's own arrival
## slack, for the reason the boat's, the ladder's and the perch's share the
## tap radius outright: a player who tapped the cabin and walked to it
## cannot arrive and be told they are not there yet. Those three can share
## one number because theirs is wide enough to swallow the slack; this one
## was narrowed to the doorway, so the slack had to be said out loud --
## see CABIN_ARRIVE_RADIUS.
##
## NEAREST door and not first-match, on the ladder's and the perch's terms:
## "first" is a fact about the layout file, and the player is standing at a
## place. And the intent SURVIVES a landing that has not arrived yet --
## that was the boarding walk's own defect, which passed its probe for a
## whole batch because the arrival happened to fall inside the radius on
## hop one.
##
## =====================================================================
## ⚠️ SINCE 29 AOUT 2026 THIS LEAVES THE SCREEN.
##
## It used to hand the body to a ride state (KeepyHopper.enter_cabin) that
## ducked him down and hid him ON THE SPOT, and a later tap brought him
## back out. That mechanism is GONE -- state, signals, tweens and the tap
## withdrawal with it -- because the cabin now has a real interior, and an
## interior is a scene rather than a pose.
##
## Two things follow, and both are the reason this is not simply a swapped
## call:
##
##   * THE SPAWN IS WRITTEN HERE, not in the interior. Every route out of
##     CabinInterior is the same bare change_scene_to_file the sub-games
##     use, and HubWorld.tscn's Keepy carries no transform -- so without a
##     spawn the way out of the cabin puts him at the world origin, which
##     is the middle of the plateau. The door coordinate is a fact this
##     screen already owns (HubBuilder derived it), so the hub records it
##     on the way IN and the interior never learns a single thing about
##     the plateau.
##
##   * IT ROUTES THROUGH HubRouter AND NOT change_scene_to_file. That file
##     is "the one place that changes scene", and a second scene-changer in
##     this one -- for the single prop that is not a portal -- is exactly
##     what its header refuses.
##
## No confirmation dialog, unlike the three portals, and that is not an
## omission. A portal is entered by LANDING on it, which a hop aimed past
## it does by accident; a doorstep is entered by TAPPING IT, on a target
## narrowed to 1.30 for exactly that reason. The question has already been
## asked by the gesture.
func _try_enter_cabin(position: Vector3) -> bool:
	if _cabins.is_empty():
		_entering = false
		return false
	var flat := Vector3(position.x, 0.0, position.z)
	var entry: Dictionary = {}
	var nearest: float = INF
	for candidate in _cabins:
		var d: float = flat.distance_to(candidate["door"] as Vector3)
		if d < nearest:
			nearest = d
			entry = candidate
	if nearest > CABIN_ARRIVE_RADIUS:
		return false
	_entering = false
	# The doorstep he is standing on, so the way back out puts him exactly
	# where he went in. Written BEFORE the route: change_scene_to_file is
	# deferred, but HubRouter latches on the first call and a spawn written
	# after a refused second call would be a spawn nobody consumes.
	HubSpawn.request(entry["door"] as Vector3)
	_router.route(&"cabin")
	return true

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
## Returns the entry the landing is standing at, or an empty Dictionary --
## so the caller can go on to put Keepy on the thing it just shoved without
## running the same proximity search a second time and risking a different
## answer from it.
func _spin_near(landing: Vector3) -> Dictionary:
	var flat := Vector3(landing.x, 0.0, landing.z)
	for entry in _spinners:
		var pivot: Node3D = entry["spinner"]
		if pivot == null or not is_instance_valid(pivot):
			continue
		if flat.distance_to(entry["position"] as Vector3) > float(entry["radius"]):
			continue
		# ⚠️ THE DEBOUNCE STOPS THE SHOVE, NOT THE ANSWER. Being in reach and
		# being shoved are two different facts, and only the first one is
		# what a rider asks about: a player who lands on a roundabout that
		# is still coasting must be able to get ON it, even though his
		# landing is correctly not counted as a second push. Returning
		# early here -- which the first draft of this did -- made a
		# coasting prop unmountable, silently.
		var running: Tween = entry["tween"]
		if running != null and running.is_valid() and running.is_running():
			return entry
		_build_turnstile_spin(entry)
		return entry
	return {}

## Builds and starts the shove tween for `entry`, from wherever the pivot
## currently sits, and returns it. THE ONE PLACE that construction lives:
## _spin_near()'s ordinary shove above and _reshove_turnstile()'s extension
## below both call it, so a re-tap travels the exact arc the first tap did
## -- same start, same trans, same ease, same duration, same turns.
##
## tween_method and not tween_property, and the angles it walks are
## identical to what _spin_near always built here -- so the SPIN is the
## shipped one to the degree. What the method buys is that the rider is
## written in the same call as the angle: see _apply_spin.
func _build_turnstile_spin(entry: Dictionary) -> Tween:
	var pivot: Node3D = entry["spinner"]
	# Wrapped before it is tweened, never reset to zero: the top keeps
	# whatever facing it coasted to, which is what a roundabout does, while
	# the number it is counted from stays bounded instead of climbing by
	# 540 degrees for every re-tap.
	var from_deg: float = fposmod(pivot.rotation_degrees.y, 360.0)
	pivot.rotation_degrees.y = from_deg
	var tween := pivot.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_apply_spin.bind(entry),
		from_deg, from_deg + 360.0 * TURNSTILE_SPIN_TURNS, TURNSTILE_SPIN_S)
	entry["tween"] = tween
	return tween

## Re-arms the ride Keepy is already on, if the tap landed within the SAME
## prop's own trigger radius -- and does nothing otherwise, which is what
## leaves it to coast down and dismount on its own exactly as before this
## batch. Called from _on_tapped_ground's is_on_turnstile() branch, in place
## of the plain drop that shipped until 28 aout 2026.
##
## A FRESH SHOVE, deliberately NOT _spin_near()'s. _spin_near() exists for a
## LANDING that finds the prop already turning and leaves it alone on
## purpose -- its own debounce, so a player who merely walks past a
## coasting turnstile cannot re-arm it by accident. Reusing that function
## here would always hit the same debounce, because the tween IS running
## for the entire time Keepy is aboard, and "tap again, ride again" would
## silently do nothing -- exactly the bug this batch was asked to close.
##
## The OLD tween is killed first, and killing does not fire `finished`: a
## kill is not a completion, so the ONE_SHOT connection riding on the old
## tween dies with it instead of firing on top of the new one. The
## replacement is reconnected the same way _mount_turnstile connects the
## first shove -- exactly one listener on "this shove ended", always
## pointed at whichever tween is actually driving the ride.
func _reshove_turnstile(point: Vector3) -> void:
	if _turnstile_ride.is_empty():
		return
	var pivot: Node3D = _turnstile_ride.get("spinner")
	if pivot == null or not is_instance_valid(pivot):
		return
	var flat := Vector3(point.x, 0.0, point.z)
	if flat.distance_to(_turnstile_ride["position"] as Vector3) > float(_turnstile_ride["radius"]):
		return
	var old: Tween = _turnstile_ride.get("tween")
	if old != null and old.is_valid():
		old.kill()
	var tween: Tween = _build_turnstile_spin(_turnstile_ride)
	tween.finished.connect(_on_turnstile_spin_finished, CONNECT_ONE_SHOT)

## Turns a spinning prop to `angle`, and -- in the SAME call, immediately
## after -- moves whoever is riding it.
##
## ⚠️ THIS IS WHY THE SPIN IS A tween_method. A rider who read the pivot on
## his own per-frame callback was measured a full frame behind it (12.0 deg
## at the peak of the shove, and process_priority did not help: Tween steps
## land after every node's _process). One writer, two writes, one order --
## the rider cannot be a frame behind the deck because there is no frame
## between them. It is the rule _place_on_route() already follows so the
## hull can never drift from the boat's passenger.
func _apply_spin(angle: float, entry: Dictionary) -> void:
	var pivot: Node3D = entry["spinner"]
	if pivot == null or not is_instance_valid(pivot):
		return
	pivot.rotation_degrees.y = angle
	# Only the rider of THIS prop, and only while he is actually aboard.
	if _keepy.is_on_turnstile() and not _turnstile_ride.is_empty() \
			and _turnstile_ride.get("spinner") == pivot:
		_keepy.follow_turnstile()

## Puts Keepy on a spinning prop and arranges for him to be let off when it
## stops.
##
## The ride lasts exactly as long as the SHOVE does -- the dismount hangs
## off the prop's own tween finishing, not off a duration copied next to
## it. A second number for "how long a spin lasts" is a second number to
## keep in step with TURNSTILE_SPIN_S, and the two would drift the first
## time either was tuned.
func _mount_turnstile(entry: Dictionary) -> bool:
	var pivot: Node3D = entry["spinner"]
	if pivot == null or not is_instance_valid(pivot):
		return false
	if not _keepy.mount_turnstile(pivot, float(entry["deck_y"]),
			float(entry["ride_radius"]), int(entry["bars"])):
		return false
	_turnstile_ride = entry
	var spin: Tween = entry["tween"]
	if spin != null and spin.is_valid() and spin.is_running():
		spin.finished.connect(_on_turnstile_spin_finished, CONNECT_ONE_SHOT)
	else:
		# Nothing is turning -- unreachable while _spin_near either shoves
		# or reports a running tween, and handled anyway because the
		# alternative failure is a rider stranded on a prop with no signal
		# left to let him off.
		_on_turnstile_spin_finished()
	return true

## The shove has coasted to a stop, so the rider steps off.
func _on_turnstile_spin_finished() -> void:
	if _turnstile_ride.is_empty() or not _keepy.is_on_turnstile():
		_turnstile_ride = {}
		return
	var landing: Vector3 = _ride_exit_point(_turnstile_ride)
	_turnstile_ride = {}
	_dismount_pending = true
	_keepy.leave_turnstile(landing)

## Sets rocking the seesaw the landing is standing at, and returns that
## entry so the caller can put Keepy on the very prop it just started
## without running the proximity search twice and risking a different
## answer.
##
## THE DEBOUNCE STOPS THE ROCK, NOT THE ANSWER -- the distinction
## _spin_near() had to learn the hard way. Being in reach and being rocked
## are two different facts, and a player who lands on a plank that is still
## settling must be able to get ON it even though his landing correctly is
## not counted as a second push.
func _rock_near(landing: Vector3) -> Dictionary:
	var flat := Vector3(landing.x, 0.0, landing.z)
	for entry in _seesaws:
		var pivot: Node3D = entry["pivot"]
		if pivot == null or not is_instance_valid(pivot):
			continue
		if flat.distance_to(entry["position"] as Vector3) > float(entry["radius"]):
			continue
		var running: Tween = entry["tween"]
		if running != null and running.is_valid() and running.is_running():
			return entry
		# WHICH END TOOK THE WEIGHT, decided HERE and only here, from the
		# landing point -- so it is settled before the tween can take its
		# first step. Set inside _mount_seesaw instead, it would be written
		# after the tween was already running, and the first frame of the
		# rock would tilt the wrong way whenever the engine happened to step
		# the tween first. Deciding it from the LANDING also means the plank
		# answers a landing that fails to mount, which is what a seesaw does.
		entry["down_side"] = 1.0 if pivot.to_local(flat).x >= 0.0 else -1.0
		_build_seesaw_rock(entry)
		return entry
	return {}

## Builds and starts the rock tween for `entry` and returns it. THE ONE
## PLACE that construction lives: the ordinary rock above and the re-pump
## below both call it, so a re-tap travels the exact arc the first tap did.
##
## tween_method and not tween_property, and this is the measured rule rather
## than a preference: the rider is written in the SAME CALL as the angle
## (see _apply_tilt), because a rider on his own callback was measured a
## full frame behind the prop and process_priority did not move it.
func _build_seesaw_rock(entry: Dictionary) -> Tween:
	var pivot: Node3D = entry["pivot"]
	var tween := pivot.create_tween()
	# LINEAR: the cosine in _apply_tilt is the easing. See SEESAW_TILT_DEG.
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(_apply_tilt.bind(entry), 0.0, 1.0, SEESAW_ROCK_S)
	entry["tween"] = tween
	return tween

## Tilts the plank for normalised rock time `t`, and -- in the same call,
## immediately after -- moves whoever is riding it.
##
## THE SIDE HE SAT ON GOES DOWN FIRST, which is the whole reading of a
## seesaw: it answers his weight. The sign is taken from the seat the rider
## actually holds, so it is his end that drops rather than a fixed one.
func _apply_tilt(t: float, entry: Dictionary) -> void:
	var pivot: Node3D = entry["pivot"]
	if pivot == null or not is_instance_valid(pivot):
		return
	var riding: bool = _keepy.is_on_seesaw() and not _seesaw_ride.is_empty() \
		and _seesaw_ride.get("pivot") == pivot
	# +Z rotation lifts the +X end, so a rider on +X needs a NEGATIVE angle
	# to be carried down. With nobody aboard the plank still rocks -- the
	# prop reacts to the landing whether or not the mount took.
	var side: float = float(entry.get("down_side", 1.0))
	var damp: float = 1.0 - t
	pivot.rotation_degrees.z = -side * SEESAW_TILT_DEG * cos(TAU * SEESAW_ROCK_CYCLES * t) * damp
	if riding:
		_keepy.follow_seesaw()

## Puts Keepy on a seesaw and arranges for him to be let off when it settles.
##
## The ride lasts exactly as long as the ROCK does -- the dismount hangs off
## the prop's own tween finishing, never off a duration copied beside it,
## which is the rule the turnstile states and the reason two numbers for
## "how long" cannot drift here.
func _mount_seesaw(entry: Dictionary) -> bool:
	var pivot: Node3D = entry["pivot"]
	if pivot == null or not is_instance_valid(pivot):
		return false
	if not _keepy.mount_seesaw(pivot, float(entry["seat_y"]), float(entry["ride_x"])):
		return false
	# NOT written here: _rock_near already decided which end went down, from
	# the same landing point mount_seesaw just picked his seat from. Two
	# writers for one fact is how the plank and its rider end up disagreeing
	# about which way is down -- SeesawProbe gates that they agree.
	_seesaw_ride = entry
	var rock: Tween = entry["tween"]
	if rock != null and rock.is_valid() and rock.is_running():
		rock.finished.connect(_on_seesaw_rock_finished, CONNECT_ONE_SHOT)
	else:
		# Nothing is rocking -- unreachable while _rock_near either starts
		# one or reports a running tween, and handled anyway because the
		# alternative failure is a rider stranded with no signal to let him
		# off.
		_on_seesaw_rock_finished()
	return true

## The rock has settled, so the rider steps off.
func _on_seesaw_rock_finished() -> void:
	if _seesaw_ride.is_empty() or not _keepy.is_on_seesaw():
		_seesaw_ride = {}
		return
	var landing: Vector3 = _ride_exit_point(_seesaw_ride)
	_seesaw_ride = {}
	_dismount_pending = true
	_keepy.leave_seesaw(landing)

## Re-pumps the seesaw Keepy is already on, when the tap landed within the
## SAME prop's trigger radius -- and does nothing otherwise, which leaves it
## to settle and dismount on its own.
##
## A FRESH ROCK, deliberately NOT _rock_near()'s, for the reason
## _reshove_turnstile spells out: _rock_near()'s debounce exists so someone
## merely walking past a settling plank cannot re-arm it, and during a ride
## the tween is ALWAYS running, so reusing it would swallow every re-tap in
## silence -- the exact defect the turnstile batch was written to fix.
##
## Killed rather than layered: Tween.kill() does NOT emit finished, so no
## stray dismount fires, and the replacement is reconnected the same way
## _mount_seesaw connects the first.
func _repump_seesaw(point: Vector3) -> void:
	if _seesaw_ride.is_empty():
		return
	var pivot: Node3D = _seesaw_ride.get("pivot")
	if pivot == null or not is_instance_valid(pivot):
		return
	var flat := Vector3(point.x, 0.0, point.z)
	if flat.distance_to(_seesaw_ride["position"] as Vector3) > float(_seesaw_ride["radius"]):
		return
	var old: Tween = _seesaw_ride.get("tween")
	if old != null and old.is_valid():
		old.kill()
	var tween: Tween = _build_seesaw_rock(_seesaw_ride)
	tween.finished.connect(_on_seesaw_rock_finished, CONNECT_ONE_SHOT)

## Where to step off: on the ground, outside the prop's reach, and clear of
## anything standing there.
##
## NAMED FOR THE RIDE AND NOT FOR THE TURNSTILE since the seesaw joined it.
## Nothing in here was ever turnstile-shaped -- it reads "position",
## "radius" and the footprint list and knows nothing else about the prop --
## so the seesaw needed the function rather than a copy of it. Renamed
## rather than called under a name that had stopped being true: this project
## has already paid for a file whose name described what it used to
## measure.
##
## OUTWARD FIRST, because that is the way he is already facing -- a rider
## flung off a roundabout carries on in the direction he was pointed, and
## turning him round to step off backwards would be the screen overruling
## the pose it just spent two seconds selling.
##
## The radius clears the TRIGGER radius rather than the footing, so the
## landing cannot shove the prop again on the way off. When the outward
## point is occupied the search walks AROUND the prop at that same radius:
## the ring is fresh ground, while pushing further out only finds more of
## whatever is already in that direction -- the argument the boat's bank
## search makes, applied to a circle.
func _ride_exit_point(entry: Dictionary) -> Vector3:
	var pivot_pos := Vector3(float(entry["position"].x), 0.0, float(entry["position"].z))
	var here := Vector3(_keepy.global_position.x, 0.0, _keepy.global_position.z)
	var out := here - pivot_pos
	if out.length_squared() < 0.000001:
		out = Vector3.FORWARD
	out = out.normalized()
	var reach: float = float(entry["radius"]) + TURNSTILE_EXIT_MARGIN
	var blocked: Array = _builder.ground_footprints()

	var fallback := HubRegion.clamp_to(pivot_pos + out * reach)
	for i in TURNSTILE_EXIT_STEPS:
		# 0, +step, -step, +2*step, ... so the first acceptable point is
		# always the one closest to straight ahead.
		var half: int = (i + 1) / 2
		var sign: float = 1.0 if i % 2 == 0 else -1.0
		var sweep: float = deg_to_rad(TURNSTILE_EXIT_ARC_DEG) * float(half) / float(TURNSTILE_EXIT_STEPS)
		var dir: Vector3 = out.rotated(Vector3.UP, sweep * sign)
		var candidate := pivot_pos + dir * reach
		if not HubRegion.contains(candidate):
			continue
		if candidate.distance_to(pivot_pos) < float(entry["radius"]):
			continue
		var free: bool = true
		for spot in blocked:
			if candidate.distance_to(spot["position"] as Vector3) < float(spot["radius"]) + KEEPY_CLEARANCE:
				free = false
				break
		if free:
			return candidate
	# Nowhere on the ring is clear. The outward point is used anyway rather
	# than leaving him aboard forever: standing in a bush is a blemish, and
	# never being let off a roundabout is a stuck screen.
	return fallback

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
	_pulse_cabin_markers(here)
	_mooring.update(here)

## The doorstep marks' approach cue, on HubPortal's own two thresholds.
##
## TWO and never one: a Keepy standing exactly on a single boundary would
## flicker the pulse on and off once per frame. The factors are read off
## HubPortal rather than restated so the doorstep breathes at the distance
## the portals do -- one rule about what "near" means on this plateau.
func _pulse_cabin_markers(here: Vector3) -> void:
	for marker in _cabin_markers:
		var flat := Vector2(marker.position.x - here.x,
				marker.position.z - here.z)
		var d: float = flat.length()
		if d <= CABIN_TAP_RADIUS * HubPortal.NEAR_FACTOR:
			marker.set_near(true)
		elif d >= CABIN_TAP_RADIUS * HubPortal.NEAR_RELEASE:
			marker.set_near(false)

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
	# A tap while the turnstile owns the body is intercepted BY STATE like
	# the ride's and the board's, for the identical reason: the point
	# arrived resolved on the y = 0 plane, so it can say which way the
	# player pointed but must never become somewhere to walk to.
	#
	# 28 AOUT 2026: it is no longer ALWAYS dropped. A tap that lands on the
	# SAME prop re-arms its ride instead -- see _reshove_turnstile for why
	# that is a fresh shove and not _spin_near()'s. A tap anywhere else is
	# still dropped exactly as before: there is nothing else it could mean,
	# and the one thing this branch must never do is turn it into a
	# destination to walk to once the ride is over.
	if _keepy.is_on_turnstile():
		_reshove_turnstile(point)
		return
	# And the seesaw on the identical terms: intercepted by state, re-pumped
	# when the tap is on the same prop, dropped otherwise -- never turned
	# into somewhere to walk to.
	if _keepy.is_on_seesaw():
		_repump_seesaw(point)
		return
	# A tap while the OWL owns the body is intercepted by state like the
	# ride's, the board's, the turnstile's and the seesaw's, for the
	# identical reason: the point arrived resolved on the y = 0 plane, so
	# it must never become somewhere to walk to while he is thirty feet up.
	#
	# Dropped and not queued, and there is deliberately nothing here for it
	# to mean. The turnstile and the seesaw re-arm on a tap because a
	# roundabout and a plank are things you push again; a loop that closes
	# exactly cannot be extended without breaking the one property the
	# curve was chosen for. It is reached at all only because the perch
	# withdraws from the tap for the length of the flight -- the boat's
	# withdrawal -- so this branch is what that fall-through lands in.
	if _keepy.is_on_owl_flight():
		return
	# Any ordinary tap cancels a boarding walk in progress: the player
	# aimed somewhere else, and arriving at the boat anyway would be the
	# screen overruling them.
	_boarding = false
	_climbing = false
	_flying = false
	_entering = false
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
	_flying = false
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
	_flying = false
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
	# NOR WHILE THE OWL HAS HIM. A flight emits no landings either, so
	# this branch should be as unreachable as the two above -- and it is
	# written for their reason: "no landing is emitted" is a property of
	# KeepyHopper that could change, and the failure it would cause is
	# being carried into a sub-game by a bird the player was only flying
	# over it on.
	if _keepy.is_on_owl_flight():
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
	var was_dismount: bool = _dismount_pending
	_dismount_pending = false
	if not was_dive:
		var shoved: Dictionary = _spin_near(position)
		# AND THEN HE GETS ON IT. The mount sits on the SAME landing and the
		# SAME proximity answer as the shove, so the prop he is put on can
		# never be a different one from the prop that turned.
		#
		# It returns immediately on success: he is ON_TURNSTILE from here, and
		# every branch below this point is about a body that is standing on
		# the plateau -- boarding a boat, climbing a ladder, entering a portal.
		# Portal detection in particular goes quiet for the whole ride exactly
		# as it does for the boat, and for the same reason: the state emits no
		# landings, so there is nothing for a portal to answer.
		if not was_dismount and not shoved.is_empty() and _mount_turnstile(shoved):
			return
		# THE SEESAW, on the same landing and under the same dive and
		# dismount gates. It sits here rather than in a branch of its own
		# below for the reason the shove does: every branch past this point
		# returns, so a reaction placed after them stops firing on exactly
		# the landings that go on to do something.
		var rocked: Dictionary = _rock_near(position)
		if not was_dismount and not rocked.is_empty() and _mount_seesaw(rocked):
			return

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
	# And the one that finishes a walk to a perch takes off. Sits with the
	# other two -- after the tint and the impact, before the portals -- for
	# the reason they do: a landing that goes on to fly still reports the
	# ground it left from, and every branch past this point returns.
	if _flying and _try_fly(position):
		return
	# And the one that finishes a walk to a doorstep goes inside. Sits with
	# the other three -- after the tint and the impact, before the portals --
	# for the reason they do: a landing that goes on to hide still reports
	# the ground it left from, and every branch past this point returns.
	if _entering and _try_enter_cabin(position):
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
	_flying = false
	_entering = false

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

## LOT B SPIKE, DISPOSABLE -- see the @onready declaration above. Bypasses
## HubRouter on purpose: ROUTES is the production table, and this path is a
## dev bench that is not meant to outlive the device pass it exists for.
## get_tree().change_scene_to_file() is HubRouter.route()'s own call, used
## directly rather than through it.
func _on_fallback_spike() -> void:
	get_tree().change_scene_to_file("res://scenes/test/BearAnimSpike.tscn")

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
