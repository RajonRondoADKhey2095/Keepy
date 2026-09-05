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
## v2 weather: the forcing row (preview only) and the system it drives.
@onready var _weather: CozyWeather = $WorldViewport/SubViewport/World/CozyWeather
@onready var _weather_overlay: ColorRect = $WeatherOverlay
@onready var _weather_label: Label = $FallbackMenu/Panel/VBoxContainer/WeatherLabel
@onready var _weather_row: HBoxContainer = $FallbackMenu/Panel/VBoxContainer/WeatherRow
## v3 P0: the performance overlay (preview only) and its menu toggle.
@onready var _perf: HubPerfOverlay = $PerfOverlay
## v3: the transport network (balloon lines + the ball).
@onready var _transport: HubTransport = $WorldViewport/SubViewport/World/Transport
@onready var _perf_button: Button = $FallbackMenu/Panel/VBoxContainer/PerfButton
@onready var _confirm: HubConfirmDialog = $ConfirmDialog
@onready var _chased_button: Button = $FallbackMenu/Panel/VBoxContainer/ChasedButton
@onready var _quizz_button: Button = $FallbackMenu/Panel/VBoxContainer/QuizzButton
@onready var _battle_button: Button = $FallbackMenu/Panel/VBoxContainer/BattleButton
@onready var _mooring: BoatMooring = $Mooring
@onready var _zipline_door: ZiplineDoor = $ZiplineDoor
@onready var _camera: HubCamera = $WorldViewport/SubViewport/World/Camera3D
@onready var _campfire: HubCampfire = $WorldViewport/SubViewport/World/Campfires
@onready var _guest_badge: Control = $GuestBadge

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

## The onlooker. One, built in _ready(), never rebuilt.
var _bear: HubActorWalker = null
## The plank the bear is currently SITTING on, or null. Not a bool and not
## read off `_seesaw_ride`: `_apply_tilt` is handed an entry and has to
## answer "is this the prop my second rider is on", and a re-pump replaces
## the tween while the ride keeps going.
var _bear_pivot: Node3D = null
## Its seat in that pivot's own frame -- the mirror of Keepy's.
var _bear_seat: Vector3 = Vector3.ZERO
## The mount the bear is still WALKING towards, or {}. Held rather than
## re-derived on arrival because by then Keepy may already be off, and a
## bear that mounts an empty settled plank is worse than one that gives up.
var _bear_pending: Dictionary = {}
## The heading the bear snaps to whenever it settles at rest -- first spawn
## AND the walk home after a dismount. Computed once in `_setup_bear()`
## from the seesaw's own published fulcrum; see `_on_bear_arrived()` for
## why this is the only fix either arrival needs.
var _bear_rest_facing: Vector3 = Vector3(0.0, 0.0, 1.0)

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

## THE BEAR THAT COMES TO WATCH THE SEESAW
##
## An onlooker, not a prop and not a ride: it has no hotspot, no tap radius
## and no entry in `hub_layout.tres`. It is parented under `World/` beside
## Keepy rather than under `World/Props`, because it MOVES -- a prop, in
## this file's vocabulary, is something the builder places once from the
## layout. That parenting also means the shared draw-node budget the
## `SeesawProbe`/`TurnstileProbe`/`WaterTintProbe` trio gates counts over
## `World/Props` only and cannot see this actor, so its cost is published
## in the report instead of riding an assertion that structurally cannot
## observe it: ONE MeshInstance3D, the rig's single skinned mesh.
const BEAR_SCENE: PackedScene = preload("res://assets/models/keepy_bear_walker.glb")

## Lot B's measured scale, taken off `Skeleton3D.get_bone_global_pose()`
## and NOT off an AABB -- the glb authors a 1.7-unit mesh and then puts a
## 0.01 scale on its Armature node, so anything reading `get_aabb()` here
## undercounts a hundredfold. See `BearAnimSpike.gd` for the full account.
const BEAR_SCALE: float = 1.130876

## The bear rig's rest-pose height at scale 1, Lot B's own measurement,
## restated here as a named constant for the SAME reason `BADGER_REST_SPAN`
## below is one: this figure is quoted by comments comparing the badger's
## height to the bear's, and a literal 1.671335 typed a second time there
## is exactly the "recopied fact" this file's own doctrine bans (see
## `KEEPY_DRAWN_HEIGHT`'s users). `BADGER_SCALE` itself is derived from
## `KEEPY_DRAWN_HEIGHT`, not from this constant -- see its own comment.
## Re-measured on the badger lot's own bench and read back 1.671344 against
## this figure -- 9 micro-units apart, standing to publish, not redo.
const BEAR_REST_SPAN: float = 1.671335

## The bear's drawn height. Published so nothing that reasons about the
## three-actor cast (Keepy, badger, bear) has to multiply the two facts
## above back together.
const BEAR_DRAWN_HEIGHT: float = BEAR_SCALE * BEAR_REST_SPAN

## Where the bear stands when nothing is happening.
##
## CHOSEN BY SCANNING THE LAYOUT, not by eye. On the seesaw's own local Z
## axis (the plank runs along its X), so both plank ends are the same walk
## and the bear does not favour one side; and BEHIND the seesaw from the
## camera, which sits at `target + (0, 7.6, 8.9)` looking down -Z -- so the
## bear walks toward the viewer in the background rather than crossing in
## front of Keepy.
##
## ⚠️ MOVED 35.5 -> 37.0 IN LOT D, and the reason is a stopwatch and not a
## taste. The rock lasts `SEESAW_ROCK_S` 2.4 s; the old rest point put the
## approach at 3.970 u, which is 5.254 s at the shipped cadence -- the
## dismount fired 2.85 s BEFORE the bear reached the plank, so it was never
## once seen aboard. Re-scanned against the layout at the new value: still
## 5.374 u clear of the nearest prop (the rock at (-5.18, 0, 38.43)), which
## is the same scan the original 35.5 was picked by.
const BEAR_REST: Vector3 = Vector3(0.0, 0.0, 37.0)

## How far to the near side of the plank the bear walks up, in the seesaw's
## own frame -- its X is the plank end it will sit on.
##
## ⚠️ BESIDE THE PLANK END AND NOT UNDER IT. At `SEESAW_TILT_DEG` 15 the
## plank end sweeps +-0.357 u vertically, so an actor standing on the plank
## line would be walked THROUGH the board on the way in. 0.8 clears that
## sweep and still leaves the mount snap short.
const BEAR_APPROACH_Z: float = 0.8

## Playback multiplier handed to the walker -- ground speed AND clip
## together, so the no-foot-slide relation `HubActorWalker.walk_speed`
## documents holds by construction rather than by memory.
##
## ⚠️ THIS IS THE OTHER HALF OF THE LOT D TIMING FIX, and neither half
## alone was enough. Even standing at the fulcrum the bear cannot start
## closer than `SEESAW_RIDE_X` 1.38 from a seat, so a rest point alone
## floors the walk near 1.83 s; and rate alone, from the old 35.5, needed
## k ~ 3.0 to fit -- a comical playback. Together: the approach is 1.547 u,
## which at 2.0 x 0.7556 = 1.5112 u/s takes 1.024 s, leaving the bear
## ABOARD for 1.376 s of the 2.4 s rock -- 57.3 % of it.
##
## `SEESAW_ROCK_S` is deliberately NOT the knob: it is Keepy's own
## device-validated ride length, and stretching it to fit an onlooker would
## re-tune gameplay to suit scenery.
const BEAR_WALK_RATE: float = 2.0

## Same knob, `_badger.walk_rate` ONLY -- never `walk_speed` (shared with
## `_bear`, and touching it would also change the bear's walk to the
## seesaw) and never `_bear.walk_rate` (`BEAR_WALK_RATE` above is its own,
## unrelated timing budget). RECON 4 (CH24) measured the campfire round
## trip at rate 1.0: 25.49 s from the near tower, 14.72 s from the far one
## -- both read as "too long" against a device tap. 2.5, Mathieu's call
## from that recon's table (3.0 was the ceiling checked -- half again past
## the only other rate this project has shipped, `BEAR_WALK_RATE` 2.0 --
## and even that does not reach 4 s in the worst case; a closer arrival
## point was costed and rejected because it would reopen the ring-clearance
## sweep the campfire's own arrival point already needed one fix for).
##
## Set once, BEFORE `_world.add_child(_badger)` in `_setup_zipline()`, on
## the bear's own reason: `HubActorWalker._ready()` reads `walk_rate` into
## `AnimationPlayer.speed_scale` a single time, so a value written after
## that call would speed up the FEET (`ground_speed()` re-reads `walk_rate`
## every frame) without speeding up the CLIP -- foot-slide, the exact
## defect the shared knob exists to rule out. `walk_to()` is never called
## on `_badger` outside the campfire detour (verified by grep, not
## assumed), so this is the badger's only walking speed full stop -- there
## is no "restore afterwards" to do, because there is no other rate it
## ever walked at.
const CAMPFIRE_WALK_RATE: float = 2.5

## CH25: the bear's OWN rate for its half of the campfire round trip --
## never `BEAR_WALK_RATE` (the seesaw's separate timing budget, see that
## constant's own note) and never `CAMPFIRE_WALK_RATE` (the badger's, a
## different rig walking a different distance). The brief asked for the
## two guests to arrive "a peu pres en meme temps", and CALCULATED rather
## than picked: the badger's own outbound leg (`_badger_rest(0)` to
## `_campfire_point`, 19.2577 u at `CAMPFIRE_WALK_RATE` 2.5) takes 10.1947 s
## of travel; the bear's own outbound leg (`BEAR_REST` to
## `_bear_campfire_point`, 22.9304 u -- longer, because the bear starts
## further from the fire) needs 2.9768 to cover that same distance in the
## same time, at the same shared `walk_speed` (0.7556) neither actor
## overrides. Reproduced independently in this lot's own script (not
## copied from CH25's recon), which is why the figure carries five, not
## three, significant digits.
##
## ⚠️ THIS IS NOT `BEAR_WALK_RATE`, AND SETTING IT ON THE SAME NODE IS THE
## EXACT FOOT-SLIDE TRAP `CAMPFIRE_WALK_RATE`'S OWN NOTE WARNS ABOUT.
## `HubActorWalker._ready()` used to read `walk_rate` into
## `AnimationPlayer.speed_scale` ONCE, at spawn -- so writing a second rate
## onto `_bear.walk_rate` later would have sped up the FEET
## (`ground_speed()` re-reads `walk_rate` every frame) without speeding up
## the CLIP, exactly the defect the badger's shared knob exists to rule
## out. Fixed at the root in `HubActorWalker.walk_to()` itself (re-applies
## `speed_scale` from whatever `walk_rate` is at the moment THAT walk
## starts, not only at `_ready()`), rather than worked around here: a
## generic actor that only ever supports ONE rate for its whole lifetime is
## a limitation nothing before this lot needed, and the fix is a single
## line that is a no-op for every existing single-rate caller (verified:
## neither the badger nor the bear's own seesaw approach ever changes
## `walk_rate` after it is set once, so `speed_scale` is re-applied to the
## SAME value every time for both of them -- this constant is the first
## caller that makes the re-application do anything).
##
## Set immediately before EACH of the bear's two campfire `walk_to()`
## calls in `_on_tapped_campfire` (both legs use it, since it is one round
## trip); reset to `BEAR_WALK_RATE` the moment the bear is home again, in
## `_on_bear_arrived()`'s `&"to_rest"` branch -- so a seesaw approach
## started any time afterwards still gets the seesaw's own budget, and the
## `_bear_campfire_leg` gate (see `_on_seesaw_mounted()`) already rules out
## the two ever being wanted on the same frame.
const BEAR_CAMPFIRE_WALK_RATE: float = 2.9768

## Site-centric azimuth (degrees, measured from +X, atan2(dz, dx) --
## `HubActorWalker`'s own yaw convention rotated 90 degrees to a bearing
## FROM the fire rather than a heading) of the bear's own arrival point
## around `HubCampfire.SITE`, at the same radius `R` = `CAMPFIRE_STONE_
## RING_OUTER` + `CAMPFIRE_ARRIVE_MARGIN` the badger's own point already
## sits at.
##
## THE DIRECT BEARING FROM `BEAR_REST` IS NOT PROPER, and this lot found
## the SAME shape of defect CH24 LOT 1 found on the badger's own arrival
## point, on a different axis: a candidate placed on the straight bearing
## `BEAR_REST -> SITE` (149.76 degrees on this convention) puts the SEGMENT
## `BEAR_REST -> candidate` within 0.21 u of a scale-0.719 tree at
## (6.643, 32.682) -- under `KEEPY_CLEARANCE` (0.66), a near-certain visual
## clip, checked against the segment WHOLE rather than trusted from the
## endpoint alone (this file's own standing rule since that same LOT 1).
##
## Found by a 3600-step sweep of this azimuth at the fixed radius `R`,
## keeping only candidates whose FULL segment from `BEAR_REST` (a) stays
## >= `CAMPFIRE_STONE_RING_OUTER` from the hearth at every point, (b) stays
## >= `KEEPY_CLEARANCE` from every decorative prop in the layout (tree,
## rock, bush, stump, flower -- read at each one's own `HubBuilder.
## FOOTPRINT_RADIUS * scale`, the same proxy CH24 used, since this engine
## does not treat these as a walking obstacle for `HubActorWalker` and so
## enforces none of this itself), and (c) stays >= 1.5 u (chord) from the
## badger's own `_campfire_point`, so the two guests do not converge on
## the same patch of ground. A valid band exists, 45.7-116.4 degrees; this
## is the best-margin point in it, 0.9628 u clear of that same tree (the
## binding constraint both ends of the band), 2.1779 u from the badger's
## point. Reproduced independently in this lot (own script, own full prop
## list, no size restricted to a bounding box) against CH25's recon, which
## proposed the identical point (20.818, 27.387) by a box-restricted sweep
## of 13 corridor props and slightly different margin figures (1.135 u /
## 130.2 degrees upper band edge) -- the different margins are down to a
## different prop subset, not a different conclusion: both sweeps agree on
## the SAME best point at the SAME azimuth, which is what makes it safe to
## commit rather than a coincidence to distrust.
const BEAR_CAMPFIRE_AZIMUTH_DEG: float = 65.2

## `false`  -- the bear stays where it arrived and waits for next time.
## `true`   -- the bear walks back to BEAR_REST when the rider steps off.
##
## 2 SEPTEMBRE 2026: FLIPPED TO `true`, and the seat outliving the rock is
## what made it worth flipping. A dismount used to be something the prop
## did to you every 2.4 s, so a bear that trekked home after each one would
## have spent the ride commuting. Now the rider decides when to leave and a
## seat can be held indefinitely, so a dismount is a rare, deliberate beat
## -- the one moment where the onlooker returning to its post reads as the
## scene resetting rather than as a treadmill.
##
## Safe against a re-tap MID-WALK, verified rather than assumed:
## `HubActorWalker.walk_to` simply replaces its target and stays WALKING,
## emitting nothing for the walk it abandoned, so a seesaw tapped while the
## bear is heading home just re-aims it at the approach point. Its
## `arrived` handler early-returns on an empty `_bear_pending`, so the
## homeward arrival itself is inert.
const BEAR_RETURNS_HOME: bool = true

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

	# Guest-preview bypass (5 sept 2026): LoginScreen.gd is the only place
	# that ever calls Auth.enter_guest_mode(), and only on a throwaway
	# *.vercel.app preview where Google sign-in is known broken. This badge
	# is the only visible trace of that state -- nothing here changes what
	# Leaderboard.gd / Quizz.gd / BattleStats.gd send, since those still
	# gate on Auth.is_signed_in(), untouched by guest mode.
	_guest_badge.visible = Auth.is_guest_mode()

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
	_setup_bear()
	_keepy.seesaw_mounted.connect(_on_seesaw_mounted)
	_keepy.seesaw_dismounted.connect(_on_seesaw_dismounted)
	_setup_zipline()
	_tap.tapped_zipline_badger.connect(_on_tapped_zipline_badger)
	_tap.tapped_zipline_solo.connect(_on_tapped_zipline_solo)
	_keepy.zipline_mounted.connect(_on_zipline_mounted)
	# AFTER _setup_zipline(): the campfire hotspot's arrival point is derived
	# from the badger's own home tower (see _setup_campfire), and the
	# round-trip toggle needs a live badger to send anywhere.
	_setup_campfire()
	_tap.tapped_campfire.connect(_on_tapped_campfire)
	_setup_weather()
	_setup_perf()
	_setup_transport()

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
	if _keepy.is_riding() or _keepy.is_on_board() or _keepy.is_on_zipline() or _keepy.is_on_carrier():
		return
	_boarding = false
	_climbing = false
	_flying = true
	_zipping = false
	_zipping_solo = false
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
	if _keepy.is_riding() or _keepy.is_on_board() or _keepy.is_on_zipline() or _keepy.is_on_carrier():
		return
	_boarding = false
	_climbing = false
	_flying = false
	_zipping = false
	_zipping_solo = false
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
	# THE SECOND RIDER, IN THIS SAME CALL AND NOWHERE ELSE. Not in the
	# bear's own _process, not on a signal: a rider that reads its prop on
	# its own callback was MEASURED a full frame behind on the turnstile
	# (12.0 deg at the shove peak), and process_priority did not move it,
	# because Tween steps land after every node's _process. The gate for
	# this is the pivot the bear sits on and not `_seesaw_ride`, so a
	# re-pump -- which replaces the tween mid-ride -- keeps carrying it.
	if _bear != null and _bear_pivot == pivot:
		_bear_follow_seesaw()

## Puts Keepy on a seesaw. He stays there.
##
## ⚠️ THE SETTLE NO LONGER LETS HIM OFF, and that is the whole of lot E.
## The rock used to carry a ONE_SHOT connection to a handler that computed
## an exit point and dismounted him the instant the tween finished, so a
## ride was 2.4 s long whatever the player wanted. Now nothing is connected
## to `finished` at all: the plank settles level (`_apply_tilt` damps to
## exactly 0 at t = 1), both riders keep their seats, and `_seesaw_ride`
## SURVIVES -- which is what lets `_repump_seesaw` find a ride to re-arm
## while the plank is standing still.
##
## Leaving is now a tap off the prop, handled in `_on_tapped_ground` on the
## boat's terms: the seat withdraws from the tap for as long as it is held,
## so the tap falls through and BECOMES the eject. See
## `_leave_seesaw_towards`.
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
	# NOTHING is hung off `entry["tween"]`. A settled rock is just a plank
	# at rest with two riders on it; the only thing that ends a ride is a
	# tap somewhere else. A tween with no listener also cannot strand
	# anyone, which is why the old "nothing is rocking" fallback -- a direct
	# call to the settle handler, to avoid a rider with no signal to let him
	# off -- has no work left to do either.
	return true

## Steps Keepy off the plank and sends him on towards the point tapped.
##
## THE BOAT'S HALF-EJECT, and deliberately not a copy of the old settle
## handler with a walk bolted on. `KeepyHopper.leave_ride` states the rule
## it implements: the destination survives the leap, so ONE tap buys the
## dismount AND the walk to where it pointed. The seesaw has no tap signal
## of its own to withdraw -- it is landing-triggered -- so its half of that
## pattern lives here, in the state branch a tap off the prop falls into.
##
## The order is load-bearing. `leave_seesaw` leaves the body in HOPPING
## (or, on the degenerate seat-is-the-landing case, IDLE), and `hop_to`
## accepts both: from HOPPING it only records the target, and the arc's own
## `_on_hop_finished` picks it up after emitting `hop_landed`; from IDLE it
## advances straight away. Neither path needs a line of `KeepyHopper.gd`,
## which is why that file is untouched by this batch.
##
## `_dismount_pending` is still armed for the same reason it always was:
## the dismount landing is a landing like any other, and without it
## `_on_hop_landed` would step off the plank and immediately climb back on.
func _leave_seesaw_towards(point: Vector3) -> void:
	if _seesaw_ride.is_empty() or not _keepy.is_on_seesaw():
		_seesaw_ride = {}
		return
	var landing: Vector3 = _ride_exit_point(_seesaw_ride)
	# Killed rather than left to settle on an empty plank: kill() emits no
	# `finished`, so nothing observes it, and a tween still writing a tilt
	# through `_apply_tilt` after both riders have gone would tip scenery
	# nobody is sitting on.
	var rock: Tween = _seesaw_ride.get("tween")
	if rock != null and rock.is_valid():
		rock.kill()
	_seesaw_ride = {}
	_dismount_pending = true
	_keepy.leave_seesaw(landing)
	_keepy.hop_to(point)

## Builds the onlooker and stands it at its rest point.
##
## The rig, its scale and its clip are handed to `HubActorWalker` as data;
## nothing about a bear lives in that script, which is why the same script
## would carry a second animal without an edit.
func _setup_bear() -> void:
	_bear = HubActorWalker.new()
	_bear.model_scene = BEAR_SCENE
	_bear.model_scale = BEAR_SCALE
	# Ground speed and clip playback at once -- see BEAR_WALK_RATE.
	_bear.walk_rate = BEAR_WALK_RATE
	# BEFORE add_child, because the walker builds its rig in _ready() and a
	# scale written afterwards would be a rig drawn once at the wrong size.
	_bear.position = BEAR_REST
	_world.add_child(_bear)
	# ⚠️ THE SNAP ON SPAWN, EVEN THOUGH IDENTITY ROTATION ALREADY HAPPENS TO
	# BE RIGHT. `HubActorWalker._ready()` reads `_yaw` off `rotation.y`,
	# which defaults to 0 on a freshly-built node -- and 0 IS the correct
	# heading here, because BEAR_REST sits behind the seesaw on its own
	# local Z (see BEAR_REST's own note), so "face the seesaw" and "face
	# the camera" are the same direction by construction. Left implicit,
	# that correctness is a coincidence of the default rather than a fact
	# this file asserts -- so it is computed and set explicitly instead of
	# trusted.
	if not _seesaws.is_empty():
		var fulcrum: Vector3 = _seesaws[0]["position"] as Vector3
		var to_fulcrum: Vector3 = fulcrum - BEAR_REST
		if Vector2(to_fulcrum.x, to_fulcrum.z).length_squared() > 1.0e-8:
			_bear_rest_facing = to_fulcrum
	_bear.face(_bear_rest_facing)
	# ONCE, here. Connecting on each mount instead is how an actor ends up
	# with N handlers and mounts N times on the Nth ride.
	_bear.arrived.connect(_on_bear_arrived)

## Keepy has sat down: the bear walks to the FAR end of that plank.
##
## ⚠️ THE SEESAW IS FOUND HERE RATHER THAN READ OFF `_seesaw_ride`, and
## that is not a preference. `_mount_seesaw` calls `mount_seesaw()`, which
## emits `seesaw_mounted` synchronously, and only THEN assigns
## `_seesaw_ride` -- so at the instant this runs that field still holds the
## PREVIOUS ride, or nothing at all. Reading it would work by luck on the
## first mount and be wrong on every one after.
##
## Keepy's position is already his seat when the signal fires
## (`mount_seesaw` calls `follow_seesaw()` before emitting), so the search
## is the same proximity test `_rock_near` does, against the same table.
func _on_seesaw_mounted() -> void:
	if _bear == null:
		return
	# CH25 RECON 3: the campfire detour has NO tap channel of its own to
	# withdraw the way `ZiplineDoor.set_badger_at()` does for the badger --
	# the seesaw's mount is driven by a landing signal, not a tap, so there
	# is no channel here to answer false. BOAT PATTERN all the same: this
	# call site refuses directly rather than letting an unconditional
	# `_bear.walk_to()` hijack the bear mid-detour, which would leave
	# `_bear_campfire_leg` pointing at a leg nothing would ever resolve
	# (the walk it describes was just overwritten) and the shared
	# `_campfire_guests` arbitration permanently stuck on `&"transit"`.
	if _bear_campfire_leg != &"":
		return
	# Unreachable while a dismount always precedes the next mount, and kept
	# because the failure it prevents is silent: a bear still seated would
	# walk its approach AT seat height, through the air.
	if _bear_pivot != null:
		_bear.global_position = Vector3(_bear.global_position.x, 0.0, _bear.global_position.z)
		_bear_pivot = null
		_bear_seat = Vector3.ZERO
	var entry: Dictionary = _seesaw_under(_keepy.global_position)
	if entry.is_empty():
		return
	var pivot: Node3D = entry["pivot"]
	# THE ROOT, NOT THE PIVOT. The pivot's z-rotation is what the rock
	# animates, so a point transformed through it would land somewhere new
	# every frame of the tilt; the root carries the layout's placement and
	# nothing else.
	var root: Node3D = pivot.get_parent() as Node3D
	if root == null:
		return
	var side: float = 1.0 if root.to_local(_keepy.global_position).x >= 0.0 else -1.0
	# The FAR end: whichever side Keepy took, the bear takes the other.
	var seat_x: float = -side * float(entry["ride_x"])
	# The near side of the plank as seen from where the bear is STANDING,
	# so it walks up to the board rather than round it. Read off its own
	# position instead of assumed, because the seesaw carries the layout's
	# `rotation_y` and a hard +Z would approach from behind on a turned one.
	var near_z: float = 1.0 if root.to_local(_bear.global_position).z >= 0.0 else -1.0
	_bear_pending = {
		"pivot": pivot,
		"seat": Vector3(seat_x, float(entry["seat_y"]), 0.0),
	}
	_bear.walk_to(root.to_global(Vector3(seat_x, 0.0, near_z * BEAR_APPROACH_Z)))

## The bear finished a walk. If that walk was an approach and the ride is
## still going, it steps up onto the plank.
##
## ⚠️ IT SNAPS, and that is a decision rather than a shortcut: the rig ships
## a walk cycle and nothing else, so there is no climb to play. The snap is
## 0.8 u sideways and about 0.69 u up, taken in one frame at the moment the
## walk ends -- which is also the moment the actor stops being watched as a
## walker.
##
## The ride is re-checked HERE and not trusted from the mount, because the
## approach takes about a second and a re-pump or an early dismount can
## land inside it. Mounting a settled empty plank would strand the bear on
## scenery with no tilt to follow and no dismount coming.
##
## ⚠️ CH25: `_on_bear_campfire_arrived()` IS CHECKED FIRST, and this is no
## longer the only other caller of `walk_to()` on this actor -- the
## campfire round trip is. That function returns `true` only when
## `_bear_campfire_leg` was actually one of the four detour values, in
## which case it has already done everything this arrival means and there
## is nothing further to check here; `false` means this arrival is the
## seesaw's, exactly as before.
func _on_bear_arrived() -> void:
	if _on_bear_campfire_arrived():
		return
	if _bear_pending.is_empty():
		# Not an approach: this is the walk home finishing (BEAR_RETURNS_HOME
		# is the other caller of walk_to on this actor OUTSIDE the campfire
		# detour), and unlike the seesaw approach -- overwritten in the same
		# frame by _bear_follow_seesaw() -- nothing else re-orients it. Left
		# alone it keeps whichever heading the last step of the walk home
		# happened to face, which is AWAY from the seesaw whenever that walk
		# moved in -Z -- see _bear_rest_facing.
		_bear.face(_bear_rest_facing)
		return
	var pending: Dictionary = _bear_pending
	_bear_pending = {}
	var pivot: Node3D = pending["pivot"]
	if pivot == null or not is_instance_valid(pivot):
		return
	if _seesaw_ride.is_empty() or _seesaw_ride.get("pivot") != pivot or not _keepy.is_on_seesaw():
		return
	_bear_pivot = pivot
	_bear_seat = pending["seat"] as Vector3
	# Placed straight away rather than waiting for the next tilt step: the
	# tween may be a frame off, and one frame of a bear standing beside the
	# plank at seat height is exactly the pop this avoids.
	_bear_follow_seesaw()

## Writes the bear onto its seat on the tilting plank. Position AND facing,
## the same two things Keepy's own `follow_seesaw` writes, in the same
## frame the angle was written.
func _bear_follow_seesaw() -> void:
	if _bear == null or _bear_pivot == null or not is_instance_valid(_bear_pivot):
		return
	_bear.global_position = _bear_pivot.to_global(_bear_seat)
	# Facing INWARD, along the plank towards the other seat -- which is
	# Keepy's. Derived from the seat rather than from his position so it is
	# still right on the frame he leaves, and taken through the pivot's own
	# basis so the tilt carries the heading with it.
	_bear.face(_bear_pivot.global_transform.basis * Vector3(-_bear_seat.x, 0.0, 0.0))

## Frees the bear from whatever plank it is currently seated on OR still
## approaching, snapping it to flat ground beside the plank if it was
## seated. Factored out of `_on_seesaw_dismounted()` (CH25) so the exact
## same eviction can run from `_on_tapped_campfire()` too: a campfire tap
## can arrive while the bear is seated on a rocking plank, and nothing
## about that plank's own dismount signal (Keepy's own) fires in that
## case -- `_apply_tilt()` calls `_bear_follow_seesaw()` every tilt tick
## for as long as `_bear_pivot` stays non-null, which would otherwise fight
## the campfire walk's own per-frame position write on the same node, one
## snapping it back onto the seat every tick the other is trying to move
## it away. Leaves `_bear_pivot`/`_bear_seat` cleared and `_bear_pending`
## emptied either way; does NOT send the bear anywhere -- the caller
## decides that (home, for a real dismount; the campfire, for a tap).
## No-op when the bear does not exist or was never on/heading to a plank.
func _evict_bear_from_seesaw() -> void:
	if _bear == null:
		return
	_bear_pending = {}
	if _bear_pivot == null or not is_instance_valid(_bear_pivot):
		return
	var root: Node3D = _bear_pivot.get_parent() as Node3D
	var ground: Vector3 = _bear.global_position
	if root != null:
		# Back down beside the plank -- the point it walked up to, which
		# is already known clear of the swing. Through the ROOT and not
		# the pivot: the pivot is left tilted at whatever angle the rock
		# settled on, and a point taken through it would be off the floor.
		var local: Vector3 = root.to_local(_bear.global_position)
		var near_z: float = 1.0 if local.z >= 0.0 else -1.0
		ground = root.to_global(Vector3(_bear_seat.x, 0.0, near_z * BEAR_APPROACH_Z))
	_bear.global_position = Vector3(ground.x, 0.0, ground.z)
	_bear_pivot = null
	_bear_seat = Vector3.ZERO

## Keepy has stepped off, so the bear does too -- the same beat, off the
## same signal, rather than a second timer that could drift from it.
func _on_seesaw_dismounted() -> void:
	# Belt and braces on the ride record. `_leave_seesaw_towards` is the
	# only caller that dismounts today and it clears this itself, but a
	# stale entry here would be a plank the player could re-pump from
	# across the plateau -- so the ride is closed wherever a dismount is
	# observed, not only where one is issued.
	_seesaw_ride = {}
	_evict_bear_from_seesaw()
	if _bear != null and BEAR_RETURNS_HOME:
		_bear.walk_to(BEAR_REST)

## The seesaw `flat` is standing on, or {}. Same radius test `_rock_near`
## runs, factored out so the bear and the rock can never disagree about
## which plank a landing belongs to.
func _seesaw_under(where: Vector3) -> Dictionary:
	var flat := Vector3(where.x, 0.0, where.z)
	for entry in _seesaws:
		var pivot: Node3D = entry["pivot"]
		if pivot == null or not is_instance_valid(pivot):
			continue
		if flat.distance_to(entry["position"] as Vector3) <= float(entry["radius"]):
			return entry
	return {}

## Re-pumps the seesaw Keepy is already on, when the tap landed within the
## SAME prop's trigger radius. Reports whether it took the tap, so the
## caller can turn the ones it refuses into an eject.
##
## ⚠️ IT WORKS AT REST, which is the whole of requirement 2. Nothing here
## needs a tween to be running: the guards are a live ride, a valid pivot
## and a point inside the radius, and `old.is_valid()` already tolerated a
## tween that had finished. It was unreachable at rest only because the
## settle used to clear `_seesaw_ride` and dismount; now that the seat
## outlives the rock, a tap on a motionless plank re-arms it.
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
func _repump_seesaw(point: Vector3) -> bool:
	if _seesaw_ride.is_empty():
		return false
	var pivot: Node3D = _seesaw_ride.get("pivot")
	if pivot == null or not is_instance_valid(pivot):
		return false
	var flat := Vector3(point.x, 0.0, point.z)
	if flat.distance_to(_seesaw_ride["position"] as Vector3) > float(_seesaw_ride["radius"]):
		return false
	var old: Tween = _seesaw_ride.get("tween")
	if old != null and old.is_valid():
		old.kill()
	var tween: Tween = _build_seesaw_rock(_seesaw_ride)
	# The fresh rock is recorded so the NEXT re-tap kills this one rather
	# than layering a second tween on the same pivot.
	_seesaw_ride["tween"] = tween
	return true

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

# =====================================================================
# THE ZIPLINE -- TIER 2: THE BADGER, THE TAP DOOR AND THE TRIP
# (3 septembre 2026, docs/lots/CH21_TYROLIENNE.md)
#
# A two-way shortcut. The badger waits at one end; a tap on IT walks Keepy
# to the stair foot, both take the trolley, and the pair arrives at the
# other end -- where the badger stays, so the next tap sends them back.
#
# ⚠️ THE THREE DOORS, EACH ONE SEPARATELY (RECON 1)
#
#   1. APPROACH.  `tapped_zipline`, withdrawn by `ZiplineDoor` on the
#      boat's exact terms. During the walk Keepy is in ordinary HOPPING,
#      so any tap falls to `tapped_ground` and CANCELS `_zipping` -- the
#      same line that already cancels a boarding walk. Full exit, at any
#      moment.
#   2. THE TRIP.  The body is owned (`State.ON_ZIPLINE`) and a tap is
#      dropped in `_on_tapped_ground`'s state branch. That rejection is
#      legitimate ONLY because the trip is BOUNDED by a tween that always
#      ends at a known point -- the owl's licence, and RECON 1 is explicit
#      that this is what "a plank whose only other meaning is handled by
#      state" really means. It is NOT extended to any unbounded phase.
#   3. ARRIVAL.  The door is handed back with the end that was reached,
#      and `leave_zipline` follows `leave_ride`: the tapped destination
#      SURVIVES the drop, so one tap buys the trip AND the walk on.
#
# No state in this chain has no way out, which is the whole of the ladder
# pattern's ban.

## The badger. Restored asset (CH20 LOT K), and the FIRST scene reference
## it has ever had -- it was in the repo unreferenced, so this integration
## is what puts it in the .pck.
const BADGER_SCENE: PackedScene = preload("res://assets/models/keepy_badger_walker.glb")

## Keepy's drawn height, already on file (CabinProbe gates it, HubBuilder
## and the waterline both quote it). Restated here as a named constant
## because BADGER_SCALE is DERIVED from it below rather than from a number
## typed twice.
const KEEPY_DRAWN_HEIGHT: float = 1.3501

## The badger rig's rest-pose height at scale 1, measured this lot the way
## Lot B measured the bear's: `Skeleton3D.get_bone_global_pose()` over all
## 24 joints, in the RIG's own space (`rig.global_transform.affine_inverse()`
## -- measuring through `skel.global_transform` and then multiplying by the
## scale applies it TWICE, which is the bug Lot B made and published).
##
## ⚠️ THE BENCH WAS PROVED BEFORE THE NUMBER WAS BELIEVED. The same pass
## re-measured the BEAR and read 1.671344 against the 1.671335 on file --
## 9 micro-units apart, so the bench reproduces a figure already in the
## dossier and has standing to publish a new one. An AABB would have read
## a hundredfold low here: the glb authors a 1.7-unit mesh and puts a 0.01
## scale on its Armature.
const BADGER_REST_SPAN: float = 1.660387

## ⚠️ SUPERSEDED 3 SEPTEMBRE 2026 (first rescale) -- Mathieu's device
## feedback (screenshots attached) read the shipped badger as too small
## next to Keepy. The reasoning from that pass is kept here for the
## record: on the zipline the two riders hang from ONE bar side by side,
## and a badger the same height as Keepy reads as a matched pair rather
## than one of them dangling. That reasoning is real, but it optimised the
## one screen where the badger and Keepy are both in the air, at the cost
## of every OTHER screen where the badger stands or walks beside Keepy on
## the ground -- which is most of its screen time, and the one Mathieu's
## screenshots showed. Overridden by his explicit call at the time: the
## badger reads bigger than Keepy, full stop. That first pass placed the
## badger at the GEOMETRIC MEAN of Keepy and the bear (k = sqrt(1.890073 /
## 1.3501) = 1.183195), giving BADGER_DRAWN_HEIGHT = 1.597431 and
## BADGER_SCALE = 0.962085.
##
## ⚠️ SUPERSEDED AGAIN, SAME DAY -- Mathieu asked for an EXACT ratio
## instead: the badger's drawn height is 1.6x Keepy's, not the geometric
## mean of Keepy and the bear. The geometric-mean reasoning above is no
## longer what this constant computes; it is kept only as the record of
## what shipped first. The formula is now:
##
##     BADGER_DRAWN_HEIGHT = 1.6 * KEEPY_DRAWN_HEIGHT
##                         = 1.6 * 1.3501 = 2.16016
##     BADGER_SCALE        = BADGER_DRAWN_HEIGHT / BADGER_REST_SPAN
##                         = 2.16016 / 1.660387 = 1.300998
##
## Written as the formula rather than as its result, the same rule
## `KEEPY_DRAWN_HEIGHT`'s other users follow, so this cannot drift from
## `BADGER_REST_SPAN`.
##
## ⚠️ CONSEQUENCE, FLAGGED AND LEFT AS-IS -- at 2.16016 the badger is now
## TALLER than the bear (`BEAR_DRAWN_HEIGHT` 1.890073, +14.3%), reversing
## the Keepy < badger < bear size order the first rescale established.
## Mathieu was informed of this before the change was made and did not ask
## for `BEAR_SCALE` to move; it is untouched. The inversion is real and
## visible in game, not merely a comment -- see CH21_TYROLIENNE.md.
const BADGER_DRAWN_HEIGHT: float = 1.6 * KEEPY_DRAWN_HEIGHT
const BADGER_SCALE: float = BADGER_DRAWN_HEIGHT / BADGER_REST_SPAN

## How far to the side of the stair foot the badger waits, along the
## tower's own lateral axis.
##
## ⚠️ BESIDE THE STAIR AND NOT ON IT. The stringers span
## `ZIPLINE_STRINGER_HALF_SPAN` 0.42 either side of the flight. At the
## ORIGINAL (pre-3-September) `BADGER_SCALE` the badger was 0.6 across,
## and 0.95 put its near flank 0.23 clear of the near rail.
##
## RE-CHECKED AFTER EACH RESCALE, not left on the old number. The first
## 3 September rescale (geometric-mean anchor) widened the rig to 0.6 *
## 1.183195 = 0.710 u across; near flank at the same 0.95 offset:
## 0.95 - 0.710/2 = 0.595, 0.595 - 0.42 = +0.175 u clear of the rail --
## tighter than the 0.23 u it had, but not a conflict.
##
## RE-CHECKED AGAIN after the SAME-DAY 1.6x-exact rescale: the rig's own
## lateral extent at scale 1 (0.710 / 0.962085 = 0.738) times the new
## `BADGER_SCALE` (1.300998) gives 0.960 u across. Near flank at the same
## 0.95 offset: 0.95 - 0.960/2 = 0.470, 0.470 - 0.42 = +0.050 u clear of
## the rail -- STILL positive, i.e. still not a real conflict, but down
## from +0.175 u to a fifth of that margin. Flagged rather than silently
## carried: the next badger rescale, if any, may need this offset re-tuned
## rather than left at 0.95. Left as-is for now because +0.050 u is a
## real margin, not zero or negative, and nothing asked for a re-tune.
##
## =====================================================================
## ⚠️ 0.95 UNTIL 4 SEPTEMBRE 2026, AND EVERY NUMBER ABOVE THIS LINE WAS
## DERIVED RATHER THAN MEASURED. THE MEASUREMENT DOES NOT AGREE.
##
## The whole chain above -- 0.23, then +0.175, then +0.050 -- multiplies a
## lateral extent recorded at one rig scale by the ratio of two later ones
## and calls the product a clearance. Measured instead against the DRAWN
## stair, on the badger's SKINNED silhouette (10 047 vertices posed by the
## live rig) under `xvfb-run --rendering-driver opengl3`:
##
##     ZiplineStringer#1 (end 0)   0.0428 u      not +0.050
##     ZiplineStringer#3 (end 1)   0.0428 u
##     ZiplineStep#0               0.1260 u
##
## Two ways of getting this wrong were both paid for. The DERIVATION is one
## -- it is a copied half-fact, and a body 0.6 across at one scale is not
## 0.960 across at another once the rig faces its tower on the diagonal, so
## the extent that matters is not a width at all. `--headless` is the other:
## the stringers are BATCHED, the dummy driver returns the IDENTITY for
## MultiMesh instance transforms, and a first pass that way put all four
## rails at the world origin, filtered them out by proximity, and reported
## a comfortable clearance against nothing whatever.
##
## 1.10 IS AN ARGMAX AND NOT "FURTHER FROM THE STAIR". The free window at
## end 0 is bounded on BOTH sides: the stringer recedes as the offset grows
## and the layout's own bush at (29.869, 7.138) closes in from beyond it.
## Swept at 0.005 over [0.90, 1.40] on the drawn geometry:
##
##     offset   nearest drawn part            clearance
##      0.950   ZiplineStringer#1               0.0428
##      1.000   ZiplineStringer#1               0.0888
##      1.100   ZiplineStringer#1               0.1886   <- shipped
##      1.200   Bush#62                         0.0923
##      1.320   Bush#62                         0.0014   <- the indicative
##      1.350   Bush#62                         0.0000      value, measured
##
## ⚠️ SO THE ~1.32 THE PREVIOUS LOT OFFERED AS INDICATIVE IS A WORSE PLACE
## TO STAND THAN 0.95, and it was right to call it indicative: it was
## derived from the rail alone, and at 1.32 the badger is 0.0014 u off a
## bush it INTERSECTS by 1.35. Copying it would have traded a stringer the
## badger touches for a bush the badger stands in.
##
## At 1.100 the two constraints all but balance -- stringer 0.1886, bush
## 0.1916 -- which is the signature of a real argmax rather than of a value
## picked and then justified. Both ends read 0.1886: the two towers carry
## the same stair, and end 1 has no bush at all (its clearance keeps rising
## past 1.40), so the shared constant is capped by end 0 alone.
##
## 0.1886 u is 4.4x the margin it replaces and it is the MOST this constant
## can buy. Anything more needs that bush moved, which is a decor edit this
## lot was not asked for and did not make. Gated by `ZiplineStructureProbe`
## PHASE I at 0.15 u, which rejects the old 0.95 by a factor of 4.4 and was
## proved able to fail before it was believed on its pass.
const BADGER_SIDE_OFFSET: float = 1.10

## How long the trolley takes to cross.
##
## ⚠️ FLOORED BY `KeepyHopper.RIDE_SPEED_FLOOR`, NOT PICKED. That constant
## is this screen's measured "a carried body slower than this reads as
## drifting" -- the boat's own number. The span is 25.921 u, so anything
## above 4.446 s would be under the floor. 4.0 s puts the trolley at
## 6.480 u/s, 11.2 % clear of it, and is the shortest duration that still
## lets a player watch the pair leave one tower and reach the other rather
## than blink and find them moved.
const ZIPLINE_RIDE_S: float = 4.0

## The badger's hanging pose: a clip and a time in it.
##
## ⚠️ THE FRAME IS MEASURED, NOT GUESSED, and the clip is NOT the one RECON
## 3 expected. That recon proposed seeking `Walking` to the frame where the
## arms are highest. Measured over 129 samples of each clip, mid-hand
## height above the hips, in the rig's own space:
##
##     Walking   best at t = 0.718 s   lift = +0.036 u
##     Running   best at t = 0.351 s   lift = +0.289 u
##
## `Walking` swings the arms at the sides -- its best frame is barely above
## the hips, and on the BEAR the same measurement is NEGATIVE (-0.023),
## i.e. the hands never rise above the hips at all. `Running` at 0.351 s is
## the only pose either rig ships with the arms genuinely up, so that is
## the pose, and this is a case of a recon premise falling to its own
## measurement rather than of the recon being followed.
const BADGER_HANG_CLIP: StringName = &"Running"
const BADGER_HANG_TIME: float = 0.351302

## The badger's backward lean while hanging, in degrees. Positive is a lean
## AWAY from travel, the same reading as `KeepyHopper.ZIPLINE_HANG_PITCH_DEG`
## -- written as its own constant rather than shared because the two rigs
## have different pivots and a shared number would be a coincidence, not a
## fact.
##
## ⚠️ 12.0 UNTIL 4 SEPTEMBRE 2026, AND THE CHANGE IS ARITHMETIC RATHER THAN
## TASTE. `ZiplineRideProbe` measured the badger's feet at -0.4502 -- UNDER
## the ground -- for the whole 4 s crossing, and the cause survives any
## clearance you care to pick: the grab bar hangs at
## `ZIPLINE_CABLE_HEIGHT - ZIPLINE_TROLLEY_STEM` = 1.76 above the ground,
## and at a 12 deg lean this rig's DRAWN hanging extent measures 1.984. A
## body whose hanging extent EXCEEDS the bar's own height off the ground
## cannot have its crown under that bar and its feet off the ground at the
## same time; no `hang_clearance` closes that, because the deficit is
## between the body and the GROUND.
##
## The lean is the only lever that shortens a body's VERTICAL extent
## without moving the bar Keepy hangs from -- and it is FREE HERE, which
## was measured rather than assumed: the pose's mid-hand sits 0.932 u from
## the bar at 12 deg already, so this rig has never been holding the handle
## and a bigger lean breaks no hand-on-bar contract. (That gap is real and
## pre-existing; it is reported in CH21 and deliberately not chased here.)
##
## ⚠️ AND THE SWEEP THAT PICKED 40 DEG WAS RUN TWICE, BECAUSE THE FIRST ONE
## USED THE WRONG INSTRUMENT. Read on BONE JOINTS, 30 deg looked like the
## shallowest lean with a real margin (+0.184). Re-read on the SKINNED
## VERTICES -- the silhouette a player actually sees -- the same 30 deg
## leaves +0.019, two centimetres, because this rig's drawn sole hangs
## 0.164 u below its lowest JOINT. That is the repo's own wrong-metric
## trap, made and caught inside one lot. The sweep that decided, on drawn
## pixels, with the node placed so the bone crown lands on the shared 1.71:
##
##     lean    drawn sole   drawn crown   clearance to the grab bar
##     12 deg    -0.258        1.726        (soles under the ground)
##     30 deg    +0.019        1.774
##     35 deg    +0.128        1.795
##     40 deg    +0.246        1.817          0.358        <-- this
##     45 deg    +0.376        1.838
##
## 40 deg is the shallowest lean whose DRAWN soles clear the ground by a
## margin of the same order as Keepy's own 0.360, its drawn crown still
## sits under the 2.0 cable, and its closest vertex still clears the grab
## bar by 0.358 u -- so nothing of the badger passes through the handle it
## rides on. It still hangs 16 % longer than Keepy (1.571 drawn against his
## 1.350), so the 1.6x rescale still reads on the one screen where the two
## are side by side in the air.
const BADGER_HANG_PITCH_DEG: float = 40.0

## THE BADGER'S OWN SUSPENSION POSE, and the reason it needs three
## constants where Keepy needs none.
##
## ⚠️ A BODY'S STANDING HEIGHT IS NOT ITS HANGING EXTENT, and reading the
## second off the first is the wrong-metric failure CLAUDE.md names. Keepy
## hangs upright, so his crown is exactly `KEEPY_DRAWN_HEIGHT` above the
## node he is written to and his soles are exactly ON it -- the seat maths
## can use his standing height and be right by accident. The badger is
## frozen on `Running` and leaned 40 deg: its crown is 1.444291 above its
## node and its lowest JOINT is 0.138760 above it. Feeding
## `BADGER_DRAWN_HEIGHT` (2.160160, the REST span) into the seat was
## therefore wrong twice over -- it over-stated the extent by 0.72 u AND
## pretended the node was at the soles.
##
## ⚠️ THREE AND NOT TWO, BECAUSE JOINTS ARE NOT THE SILHOUETTE. On this rig
## the drawn surface hangs 0.158 u BELOW its lowest joint in this pose
## (fur, foot, the mesh past the ankle), so a contract written on
## `BADGER_HANG_SOLE` alone would gate a body 16 cm higher than the one on
## screen. `BADGER_HANG_DRAWN_SOLE` is that surface, and it is what the
## ground clearance is actually judged on; the joint reading is kept beside
## it because it is what a per-frame probe can afford to sample.
##
## MEASURED THE WAY `BADGER_REST_SPAN` WAS, and by a bench that proved
## itself first: the same pass re-measured the rest span at 2.160081
## against the 2.160160 on file, 79 micro-units apart, before publishing
## anything new. Joints from `Skeleton3D.get_bone_global_pose()` over all
## 24 bones; the surface from all 10 047 vertices SKINNED BY HAND against
## the live pose (`Skin.get_bind_pose()` composed with each bone's global
## pose), because a skinned mesh's `get_aabb()` is the rest box and this
## pipeline's 0.01 Armature scale makes it read a hundredfold low anyway --
## the trap Lot B published. Carried to world and back through the ACTOR's
## own transform exactly ONCE, never through `skel.global_transform` and
## then multiplied by the scale again, which is Lot B's other bug.
##
## RE-MEASURED AGAINST THE LIVE RIG BY `ZiplineRideProbe` ON EVERY RUN --
## joints on every sampled frame of the crossing, the skinned silhouette
## once mid-flight -- and a drift fails there rather than silently
## re-burying the badger.
const BADGER_HANG_CROWN: float = 1.444291
const BADGER_HANG_SOLE: float = 0.138760
const BADGER_HANG_DRAWN_SOLE: float = -0.019240

## The one zipline the layout ships, as BUILT -- towers, cable, carrier and
## the three ride facts. Empty when the layout carries none, and every
## branch below checks it rather than assuming.
var _zipline: Dictionary = {}

## The badger. Parented under `World/` beside Keepy and the bear rather
## than under `World/Props`, for the bear's reason: a prop, in this file's
## vocabulary, is something the builder places once from the layout, and
## this actor rides across the plateau. That parenting is also why its
## draw cost -- ONE MeshInstance3D, the rig's single skinned mesh -- is
## published in the report instead of riding the `World/Props` node budget
## the probe trio gates, which structurally cannot see it.
var _badger: HubActorWalker = null

## Set by a tap on the badger and cleared the moment the walk to the tower
## reaches it, is cancelled, or runs out. THE SAME SHAPE as `_boarding`,
## `_climbing`, `_flying` and `_entering`, and cleared in the same three
## places, so a zipline intent cannot outlive its walk any more than
## theirs can.
var _zipping: bool = false

## Set by a tap on the STRUCTURE (tier 3, 4 septembre 2026) and cleared on
## exactly the same three occasions as `_zipping` above, in the same sites
## -- a solo intent cannot outlive its walk any more than the badger's can.
## Kept as a SIBLING flag rather than folded into `_zipping` with a mode
## bit: the two can never both be true (every reset site clears both), so a
## single bool would work, but a shared flag would make `_on_hop_landed`'s
## dispatch order matter in a way it does not for any other prop here --
## see `_try_zip_badger` and `_try_zip_solo`, which decide the direction
## from where Keepy is actually standing rather than from a stored index.
var _zipping_solo: bool = false

## The trip in progress: the published zipline entry plus the end index it
## is travelling TO. Empty when nothing is crossing.
var _zip_trip: Dictionary = {}

## Builds the badger, parks it at the near tower and opens the door.
##
## END 0 AND NOT A CHOICE. `ziplines()` publishes its towers in layout
## order -- near end first -- and the layout's near end is P1 (27.7 / 9.2),
## the end RECON 5 measured as the one a player can actually see from. The
## far end P2 is invisible from P1 and Mathieu accepted that asymmetry; the
## side that is reachable first is therefore the side the badger starts on.
func _setup_zipline() -> void:
	var lines: Array[Dictionary] = _builder.ziplines()
	if lines.is_empty():
		return
	if lines.size() > 1:
		# One zipline is the layout this ships. A second would need a door
		# each and a badger each, which is a shape this file does not have
		# -- said out loud rather than silently carrying the first.
		push_error("HubWorld: %d ziplines in the layout; tier 2 wires exactly one." % lines.size())
	_zipline = lines[0]

	_badger = HubActorWalker.new()
	_badger.model_scene = BADGER_SCENE
	_badger.model_scale = BADGER_SCALE
	# BEFORE add_child, for the bear's reason: the walker builds its rig in
	# _ready(), and a scale written afterwards would be a rig drawn once at
	# the wrong size. Ground speed AND clip playback together -- see
	# CAMPFIRE_WALK_RATE.
	_badger.walk_rate = CAMPFIRE_WALK_RATE
	_badger.position = _badger_rest(0)
	_world.add_child(_badger)
	_badger.face(_badger_facing(0))

	_zipline_door.setup(_zipline_ends(), _badger, 0)
	# The tap node resolved its own path in _ready(); this only checks that
	# it found the same object, because a door nobody asks is a door that
	# never withdraws -- and that failure is silent.
	if _tap.zipline != _zipline_door:
		push_error("HubWorld: HubTapInput.zipline_path does not resolve to this ZiplineDoor; the tap channel is dead.")

## The two towers' ground points, in the order they were published.
func _zipline_ends() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if _zipline.is_empty():
		return out
	for tower in (_zipline["towers"] as Array):
		out.append(tower["position"] as Vector3)
	return out

## Where the badger waits at end `index`: beside the stair foot, on the
## tower's own lateral axis.
##
## READ OFF THE BUILT TOWER, never off the layout. `stair_foot` and
## `forward` are published by the pass that DREW the stair, so the actor
## stands next to the steps a player can see rather than next to where a
## recomputation thinks they are -- the doorstep-that-did-not-scale
## failure this repo has already paid for.
func _badger_rest(index: int) -> Vector3:
	if _zipline.is_empty():
		return Vector3.ZERO
	var tower: Dictionary = (_zipline["towers"] as Array)[index]
	var forward: Vector3 = tower["forward"]
	var side := Vector3(forward.z, 0.0, -forward.x)
	var foot: Vector3 = tower["stair_foot"]
	return Vector3(foot.x, 0.0, foot.z) + side * BADGER_SIDE_OFFSET

## Which way the badger looks while waiting: at the tower it is standing
## beside, so it reads as somebody waiting to go up rather than as scenery
## facing the void.
func _badger_facing(index: int) -> Vector3:
	if _zipline.is_empty():
		return Vector3.FORWARD
	var tower: Dictionary = (_zipline["towers"] as Array)[index]
	var to_tower: Vector3 = (tower["position"] as Vector3) - _badger_rest(index)
	to_tower.y = 0.0
	if to_tower.length_squared() < 1.0e-8:
		return Vector3.FORWARD
	return to_tower

## =====================================================================
## CH24 -- THE CAMPFIRE DETOUR. A tap on the fire sends the badger to sit by
## it; a second tap brings it home. Round trip, BOAT PATTERN (RECON 1 /
## docs/lots/CH21_TYROLIENNE.md): the LADDER pattern -- an unconditional
## emit whose listener drops it -- is banned, so the badger's OWN zipline
## channel actively withdraws for the whole detour (see ZiplineDoor.set_badger_at),
## exactly the way the boat's mooring and the badger's own boarding disc
## already withdraw for the whole of a ride.
##
## No new STATE on HubActorWalker for the round trip itself:
## IDLE/WALKING/ARRIVED plus `walk_to()` already say everything that needs.
## The only state kept here is WHICH LEG the badger is on, because `arrived`
## fires identically at the end of either leg and the two need different
## handling.
##
## LOT 4 adds one small capability to the actor, not a state: `turn_to()`,
## a turn-in-place for the moment `to_rest` lands home facing the travel
## bearing rather than the tower it is meant to wait beside.
## =====================================================================

## How close a tap has to land to the campfire to mean "send/recall the
## badger", in world units. 1.8, the boat/owl/badger-boarding number and for
## their exact reason: the prop is small and far from the camera, and the
## ground around it is not aimed at for any other purpose (the nearest other
## hotspot -- the zipline's near tower -- is ~20 u away, see the arrival
## point derivation below).
const CAMPFIRE_TAP_RADIUS: float = 1.8

## The stone ring's own WORST-CASE outer bound, in world units --
## `STONE_RING_RADIUS * SCALE` plus the largest stone's own drawn radius,
## measured by `CampfireStoneRecon` (CH23 lot 6) and published as prose in
## HubCampfire.gd's own STONE_RING_RADIUS comment ("bord exterieur 1,529 u
## au pire"). Quoted from THAT measurement, not re-derived: the per-stone
## RNG walk that produced it lives in HubCampfire._make_stone_ring and this
## file has no business re-running it.
const CAMPFIRE_STONE_RING_OUTER: float = 1.529

## Margin beyond the stone ring's outer bound the badger's arrival point
## keeps clear, before it stops walking. `KEEPY_CLEARANCE` and not a new
## number: the same "room to manoeuvre beside a prop, not a rim that just
## barely avoids it" reasoning HubRegion already applies to every other
## footprint on this plateau.
const CAMPFIRE_ARRIVE_MARGIN: float = KEEPY_CLEARANCE

## The badger's arrival point at the campfire, flat. Computed once, in
## `_setup_campfire()`, and cached here -- every other hotspot on this
## plateau reads a point that was built, never a literal, and this one is no
## exception the moment it has a tower to measure from.
var _campfire_point: Vector3 = Vector3.ZERO

## The proximity marker at `_campfire_point` -- the exact tap point/radius
## pair `_tap.campfire_points`/`campfire_radius` already use, on the cabin
## doorstep's own rule: a marker is drawn AT the point it marks, never beside
## it or at a second size, so the ring a player sees and the disc
## `HubTapInput` tests stay the same number. `HUB_GRASS`, the portals' amber
## ink, for the reason `_build_cabin_markers()` gives beside CABIN_TAP_RADIUS:
## this is the fourth thing on the plateau proper that a tap sends the
## badger somewhere, and the other three (Quizz/Battle/Chased) already look
## like this.
##
## Pulse only -- RECON 4 (CH24): the tap stays the direct one already wired
## in `_on_tapped_campfire`/`_tap.campfire_points`, unchanged by this marker.
## No label: the brief asked for a proximity cue, not a new piece of prose.
var _campfire_marker: CabinMarker = null

## Which leg of the detour the badger is on: &"" (at its zipline rest, the
## default), &"to_fire", &"at_fire", or &"to_rest". Read by
## `_on_tapped_campfire` to decide what a tap means and by `_on_badger_arrived`
## to decide what an arrival means -- `HubActorWalker.arrived` fires
## identically at the end of either leg, so this is the only thing that
## tells the two apart.
var _badger_campfire_leg: StringName = &""

## Which zipline end to walk the badger back to, captured the moment it
## leaves for the fire -- never assumed to be end 0: the badger may have
## ridden the cable since it last stood still, and `ZiplineDoor.waiting_end()`
## is the one live reading of where it actually was.
var _badger_campfire_return_end: int = -1

## The bear's own arrival point at the campfire, flat -- the badger's
## `_campfire_point` field, mirrored. Computed once in `_setup_campfire()`
## from `HubCampfire.SITE` and `BEAR_CAMPFIRE_AZIMUTH_DEG`, cached here for
## the same reason: every hotspot on this plateau reads a point that was
## built, never a literal re-typed at each use site.
var _bear_campfire_point: Vector3 = Vector3.ZERO

## Which leg of the detour the bear is on -- same four values, same job as
## `_badger_campfire_leg`, kept as its OWN field rather than shared with it
## because the two arrive and leave independently (CH25: synced by a
## dedicated `walk_rate`, not by lockstep) and each needs its own answer to
## "what does MY next arrival mean". Read by `_on_tapped_campfire` and by
## `_on_bear_arrived`; also the gate `_on_seesaw_mounted()` checks before
## detouring the bear onto the plank (RECON 3, CH25: no tap channel to
## withdraw the way `ZiplineDoor.set_badger_at()` does for the badger, so
## the seesaw's own call site is guarded directly instead -- BOAT pattern,
## an active refusal, never the banned LADDER shape).
var _bear_campfire_leg: StringName = &""

## THE SHARED STATE A TAP ON THE FIRE ACTUALLY READS -- &"" (both guests
## home, a tap sends both out), &"transit" (at least one of them is
## walking, either direction -- a tap means nothing new, the same no-op
## shape a mid-walk tap already had for the badger alone), or &"out" (BOTH
## guests have arrived and are sitting at the fire -- a tap calls both
## home).
##
## CH25's decision, written down rather than left to be reverse-engineered
## from the code: a re-tap is accepted ONLY once EVERY guest has actually
## arrived (`&"out"`, set by `_maybe_advance_campfire_guests()` the moment
## the SECOND of the two per-actor legs reaches `at_fire`), never mid-walk
## for either one. `_badger_campfire_leg`/`_bear_campfire_leg` keep tracking
## each actor's own leg -- `_on_badger_arrived()`/`_on_bear_arrived()` still
## need to know which of THEIRS just ended -- but the TAP HANDLER never
## reads either of those two fields directly, exactly so the two cannot
## silently disagree about what a tap means if one guest's own timing ever
## drifts from the other's (a future rate/point tweak on either actor,
## made without touching this file's own arbitration). The alternative --
## accepting a retap the instant either guest arrives, or interrupting
## whichever is still mid-walk -- was considered and rejected: the first
## reintroduces exactly the two-flags-can-disagree risk this field exists
## to close, and the second is the banned LADDER shape (a tap that cancels
## a trip already under way, with nothing to show the player for it).
var _campfire_guests: StringName = &""

## Builds the campfire's tap point and hands it to HubTapInput, on the
## cabin/owl pattern: a list of points plus a world-unit radius, wired
## exactly once. No-ops when there is no badger to send -- a layout without
## a zipline has nothing to detour, and the campfire stays purely decorative.
##
## ⚠️ THE ARRIVAL POINT IS DERIVED, NEVER A LITERAL COORDINATE, and NOT
## along the bearing to either tower -- that was the first version of this
## function and it was WRONG, caught by the segment check the brief asked
## for rather than assumed clean from the endpoint alone. Placed on the
## bearing straight from the fire to `_badger_rest(0)`, the walk HOME from
## the OTHER tower (end 1, `_badger_rest(1)`) cuts the corner: the segment's
## closest approach to `HubCampfire.SITE` measured 1.409 u -- inside the
## stone ring's own published 1.529 u outer bound, a real clip, and short of
## even that bound alone before `CAMPFIRE_ARRIVE_MARGIN` is added.
##
## The fix keeps the same two published numbers (`CAMPFIRE_STONE_RING_OUTER`,
## `CAMPFIRE_ARRIVE_MARGIN`) but changes the DIRECTION: the point sits along
## the near tower's own SIDE axis -- the identical `Vector3(forward.z, 0,
## -forward.x)` `_badger_rest()` already reads off the tower's "forward" to
## stand the badger beside its stair, not a fresh vector invented here.
## Swept numerically (a 3600-step scan over every bearing at this radius,
## scripted outside the engine since no Godot binary was available in this
## sandbox -- see CH24's report), that axis sits in the middle of a ~28
## degree band where BOTH approaches -- from end 0 and from end 1 -- clear
## the ring by the full published margin (2.189 u, both, to the millimetre);
## the direct bearing to either tower is the WORST choice, not a safe
## default, because it is exactly the angle at which the OTHER tower's
## approach cuts closest.
##
## Decorative batched props (rock/tree/bush/stump/flower) carry no entry in
## `HubBuilder.FOOTPRINT_RADIUS` at all -- this engine does not treat them as
## a walking obstacle for any existing actor, badger included -- so they
## were checked by hand against the layout (closest: a stump 0.84 u from the
## tower-0 leg) rather than by the engine's own logic, and their
## SILHOUETTE overlap (as opposed to a blocked walk) could not be confirmed
## by an `xvfb`/`opengl3` render in this sandbox. Left as a NEXT STEPS item
## for CI/device, not assumed clean -- see CH24's report.
func _setup_campfire() -> void:
	if _badger == null or _campfire == null:
		return
	if _zipline.is_empty():
		return
	var site := Vector3(HubCampfire.SITE.x, 0.0, HubCampfire.SITE.y)
	var near_tower: Dictionary = (_zipline["towers"] as Array)[0]
	var forward: Vector3 = near_tower["forward"]
	var side := Vector3(forward.z, 0.0, -forward.x)
	_campfire_point = site + side * (CAMPFIRE_STONE_RING_OUTER + CAMPFIRE_ARRIVE_MARGIN)

	# ⚠️ TWO DISCS, AND THE HEARTH IS THE ONE THAT WAS MISSING.
	#
	# Until this lot this array held `_campfire_point` ALONE -- the badger's
	# ARRIVAL point, which sits `CAMPFIRE_STONE_RING_OUTER +
	# CAMPFIRE_ARRIVE_MARGIN` = 2.189 u out from the hearth. MEASURED
	# (CampfireFacingProbe PHASE C): with CAMPFIRE_TAP_RADIUS at 1.8 that
	# left the centre of the fire 2.189 u from the only disc that answered,
	# i.e. OUTSIDE it -- so a tap ON the campfire did nothing at all, and
	# the detour could only be started by tapping a patch of lawn beside it.
	#
	# The hearth is ADDED and not substituted: the disc around the arrival
	# point is also the disc over the badger once it is sitting there, so
	# dropping it would take away "tap the badger to send it home".
	# `HubTapInput` already loops over this array -- it was an Array from
	# its first commit, on this repo's own rule that a table is a list
	# before it has two entries -- so the union costs nothing.
	var points: Array[Vector3] = [site, _campfire_point]

	# CH25: the bear's OWN arrival point and disc, on the same "the disc
	# is also the seat" rule the badger's own point already lives by. Built
	# straight off `site` and `BEAR_CAMPFIRE_AZIMUTH_DEG` -- see that
	# constant's own note for why THIS azimuth and not the direct bearing
	# from `BEAR_REST` (rejected: 0.21 u from a tree, under
	# `KEEPY_CLEARANCE`). Guarded on `_bear` rather than assumed present --
	# a layout with a zipline but no seesaw would have a badger and no
	# bear, and this file already treats "no bear" as a legal plateau
	# everywhere else (`_on_seesaw_mounted()`, `_setup_bear()`'s own callers).
	if _bear != null:
		var bear_az: float = deg_to_rad(BEAR_CAMPFIRE_AZIMUTH_DEG)
		var bear_axis := Vector3(cos(bear_az), 0.0, sin(bear_az))
		_bear_campfire_point = site + bear_axis * (CAMPFIRE_STONE_RING_OUTER + CAMPFIRE_ARRIVE_MARGIN)
		points.append(_bear_campfire_point)

		# ⚠️ RED-BEFORE-GREEN'S OWN COUSIN: an assertion that the sync this
		# lot was asked for actually holds, checked once at setup rather than
		# trusted from the arithmetic in BEAR_CAMPFIRE_WALK_RATE's comment.
		# Both distances are read off the SAME points `_on_tapped_campfire`
		# will actually walk to, not re-derived; `_badger.ground_speed()` is
		# already `walk_speed * CAMPFIRE_WALK_RATE` because `_setup_zipline()`
		# (which runs before this) already set that rate on it. The bear's
		# own `walk_rate` is still `BEAR_WALK_RATE` at this point in _ready()
		# (the campfire rate is only written immediately before each
		# campfire `walk_to()`, see `_on_tapped_campfire`), so the bear's
		# side of this check reads `BEAR_CAMPFIRE_WALK_RATE` directly rather
		# than `_bear.ground_speed()`, which would answer the seesaw's
		# question instead of this one.
		var badger_dist: float = _badger.global_position.distance_to(_campfire_point)
		var badger_time: float = badger_dist / _badger.ground_speed()
		var bear_dist: float = _bear.global_position.distance_to(_bear_campfire_point)
		var bear_time: float = bear_dist / (_bear.walk_speed * BEAR_CAMPFIRE_WALK_RATE)
		var drift: float = absf(bear_time - badger_time)
		var drift_msg: String = ("HubWorld: BEAR_CAMPFIRE_WALK_RATE no longer syncs the " +
			"bear's campfire arrival with the badger's own (%.2f s apart).") % drift
		assert(drift < 1.0, drift_msg)

	_tap.campfire_points = points
	_tap.campfire_radius = CAMPFIRE_TAP_RADIUS
	_badger.arrived.connect(_on_badger_arrived)

	_campfire_marker = CabinMarker.new()
	_campfire_marker.setup(CAMPFIRE_TAP_RADIUS, "", CabinMarker.Surface.HUB_GRASS)
	# ⚠️ ON THE HEARTH, NOT ON `_campfire_point`, AND THE TWO STAY DISTINCT.
	#
	# LOT 2 drew this ring at the badger's arrival point and argued it was
	# "AT the point it marks". That was true of the DISC and false of the
	# FIRE: the device screenshot showed an amber ring 2.189 u off the
	# hearth, overlapping the stone ring's edge, marking lawn. What a player
	# is being invited to tap is the CAMPFIRE, so the ring is drawn on the
	# campfire; `_campfire_point` keeps its own separate job -- where the
	# badger STANDS -- and is never re-read for anything visual.
	_campfire_marker.position = site
	_builder.add_child(_campfire_marker)

## A tap on the campfire. Toggles BOTH guests' detour at once (CH25: the
## bear rides along with the badger on the same tap) -- a tap that lands
## mid-transit (either guest still WALKING, either direction) is not lost,
## it simply means nothing new until BOTH legs already under way resolve,
## same "a re-tap re-states the same destination" shape `hop_to()` already
## has, generalised from one traveller to two. See `_campfire_guests`'s own
## note for why the arbitration reads THAT shared field and neither
## per-actor leg directly.
func _on_tapped_campfire(_point: Vector3) -> void:
	if _badger == null:
		return
	if not _zip_trip.is_empty():
		# A cable trip is driving the badger's position every frame
		# (`_badger_follow_zipline`); redirecting it here would fight that
		# write on the same node. No-op, the same refusal
		# `_on_tapped_zipline_badger` already gives a tap mid-ride.
		return
	match _campfire_guests:
		&"":
			# AT REST -- the outbound leg, both guests at once.
			# `waiting_end()` before the withdrawal, never after:
			# `set_badger_at(-1)` is what makes it stop answering.
			_badger_campfire_return_end = _zipline_door.waiting_end()
			_zipline_door.set_badger_at(-1)
			_badger_campfire_leg = &"to_fire"
			_badger.walk_to(_campfire_point)

			# CH25: the bear's own rate is set HERE, immediately before ITS
			# walk_to() -- never earlier -- so `HubActorWalker.walk_to()`'s
			# own `speed_scale` re-sync (see `BEAR_CAMPFIRE_WALK_RATE`'s
			# note) picks it up for this specific walk rather than for
			# whatever `_bear.walk_rate` happened to be left at. Guarded on
			# `_bear` for the same reason `_setup_campfire()` is: a layout
			# without a seesaw is legal and has no bear to send.
			if _bear != null:
				# EVICTED FIRST, even though the seesaw gate (`_on_seesaw_
				# mounted()`) already refuses the OTHER direction: the bear
				# can still be sitting on a plank right now (nothing about
				# the campfire tap depends on the seesaw being idle). Left
				# seated, `_apply_tilt()` would keep calling
				# `_bear_follow_seesaw()` every tilt tick and fight this
				# walk's own position write on the same node, one snapping
				# the bear back onto the seat every tick the other tries to
				# move it toward the fire.
				_evict_bear_from_seesaw()
				_bear.walk_rate = BEAR_CAMPFIRE_WALK_RATE
				_bear_campfire_leg = &"to_fire"
				_bear.walk_to(_bear_campfire_point)

			_campfire_guests = &"transit"
		&"out":
			# THE ROUND TRIP, both guests at once. The badger's zipline
			# channel stays withdrawn for the whole return leg too --
			# reopened only on arrival, in `_on_badger_arrived` -- so a tap
			# on its empty tower mid-walk-back still falls through to the
			# ground.
			var badger_home: Vector3 = _badger_rest(_badger_campfire_return_end)
			# RECON 4 (CH24): faced explicitly BEFORE walk_to(), rather than
			# left to `_process()`'s own `lerp_angle`. The badger's heading
			# is still whatever the outbound leg left it at (the walk there
			# is near-straight, so it converges fast and stays there) --
			# returning to the SAME tower is then a 180 degree turn, the
			# worst case a finite-speed ease can hit, while `move_toward`
			# already has the body moving at full ground speed from frame
			# one: measured -20.93 degrees facing the fire against 159.07
			# degrees required home, a dead-on reversal that reads as
			# walking backwards for the ~0.5-1 s the ease needs to catch up.
			# Facing the ACTUAL home direction here (not a guessed bearing)
			# is exact for both legs -- the return to the OTHER tower
			# (measured 30.6 degrees, already near-imperceptible) gets the
			# same instant, correct heading, not a new one.
			_badger.face(badger_home - _badger.global_position)
			_badger_campfire_leg = &"to_rest"
			_badger.walk_to(badger_home)

			# CH25 RECON 5: the bear's own return leg reverses a near-
			# straight outbound walk the same way the badger's worst case
			# does (measured: outbound travel bearing ~114.79 degrees,
			# required return ~-65.21 degrees -- a ~180 degree difference,
			# the same "reads as walking backwards" shape), so it gets the
			# identical fix, on the SAME pattern and for the SAME reason.
			if _bear != null:
				_bear.walk_rate = BEAR_CAMPFIRE_WALK_RATE
				_bear.face(BEAR_REST - _bear.global_position)
				_bear_campfire_leg = &"to_rest"
				_bear.walk_to(BEAR_REST)

			_campfire_guests = &"transit"
		_:
			# &"transit" -- at least one guest is still walking either leg.
			# No-op: the same "a tap mid-transit means nothing new until the
			# leg already under way resolves" shape the badger alone had.
			pass

## `HubActorWalker.arrived` fires identically whichever leg just ended;
## `_badger_campfire_leg` is the only thing that says which one it was.
func _on_badger_arrived() -> void:
	match _badger_campfire_leg:
		&"to_fire":
			_badger_campfire_leg = &"at_fire"
			_maybe_advance_campfire_guests()
		&"to_rest":
			_badger_campfire_leg = &""
			_zipline_door.set_badger_at(_badger_campfire_return_end)
			# LOT 4: face the CH21 canonical rest heading, not whatever the
			# travel bearing home left the yaw at. `_badger_facing()` is the
			# same accessor `_ready()` and `_on_zip_trip_finished()`
			# already read for this -- a published fact, not a new literal
			# (CLAUDE.md's own "chiffre fantome" warning) -- so it is asked
			# for here rather than a degree constant guessed from LOT 3's
			# travel-heading numbers, which describe a different thing (the
			# BEARING to the fire, not the tower-facing rest pose) and are
			# not assumed identical to it.
			#
			# Turned AFTER arrival, on the spot -- `walk_to()`'s own facing
			# (the LOT 2/3 fix) still owns the return leg itself, untouched.
			_badger.turn_to(_badger_facing(_badger_campfire_return_end))
			_badger_campfire_return_end = -1
			_maybe_advance_campfire_guests()
		_:
			# An arrival unrelated to the detour. Nothing else ever calls
			# `_badger.walk_to()`, so this should not happen -- left as a
			# no-op rather than an error, on the same terms `_arrive()`
			# already tolerates a caller who asked for a walk it was
			# already standing at the end of.
			pass

## The bear's own half of the same arrival, CH25's mirror of
## `_on_badger_arrived()` above -- same match on the same four leg values,
## same reason (`arrived` fires identically for either leg, the field is
## the only thing that tells them apart).
func _on_bear_campfire_arrived() -> bool:
	match _bear_campfire_leg:
		&"to_fire":
			_bear_campfire_leg = &"at_fire"
			_maybe_advance_campfire_guests()
			return true
		&"to_rest":
			_bear_campfire_leg = &""
			# RECON 5 (CH25): turned AFTER arrival, on the spot, to the
			# canonical rest heading the bear was built with -- exactly
			# `_badger.turn_to(_badger_facing(...))`'s own reasoning, and
			# the SAME field `_setup_bear()` already computed for the
			# seesaw's own "walk home" arrival, so this is not a second
			# fact: it is the one this file already had, read a second time.
			_bear.turn_to(_bear_rest_facing)
			# Restore the seesaw's own timing budget now that the detour is
			# over -- see `BEAR_CAMPFIRE_WALK_RATE`'s own note on why this
			# reset has to happen before any later seesaw `walk_to()`, and
			# why the `_bear_campfire_leg` gate on `_on_seesaw_mounted()`
			# already rules out the two ever racing on the same frame.
			_bear.walk_rate = BEAR_WALK_RATE
			_maybe_advance_campfire_guests()
			return true
		_:
			return false

## Once BOTH guests have reported the same half of the round trip, the
## shared arbitration `_on_tapped_campfire` reads is advanced -- never
## before, which is the whole of CH25's answer to "what if one arrives
## before the other": a retap is accepted only once EVERY guest is
## actually `at_fire`, and the detour is considered fully closed only once
## every guest is back `home` (&""). See `_campfire_guests`'s own note for
## the alternatives this rejected.
##
## A null `_bear` (a layout with a zipline but no seesaw, see
## `_setup_campfire()`'s own guard) is treated as a guest who is always
## wherever the badger needs it to be -- `_bear_campfire_leg` never moves
## off `&""` for a bear that does not exist, so testing it literally would
## wedge this at `&"transit"` forever the first time the badger alone
## finished a leg.
func _maybe_advance_campfire_guests() -> void:
	if _campfire_guests != &"transit":
		return
	var bear_at_fire: bool = _bear == null or _bear_campfire_leg == &"at_fire"
	var bear_home: bool = _bear == null or _bear_campfire_leg == &""
	if _badger_campfire_leg == &"at_fire" and bear_at_fire:
		_campfire_guests = &"out"
	elif _badger_campfire_leg == &"" and bear_home:
		_campfire_guests = &""

## Where a body whose crown sits `crown_above_origin` over its own node
## origin hangs on the trolley, in the TROLLEY's own frame:
## `(lateral, height, abscissa)`, which is the shape RECON 4 asked for and
## the shape `RIDE_SEAT_Y` -- a bare float with no notion of an occupant --
## could not take.
##
## ⚠️ THE ARGUMENT IS A CROWN OFFSET AND NOT A BODY HEIGHT, and the two
## stopped being the same thing on 4 septembre 2026. What this function
## returns is where a rider's NODE goes; what the bar fixes is where his
## CROWN goes; the step between them is the crown's height above that node
## IN THE POSE HE IS HELD IN. For Keepy those coincide -- he hangs upright,
## so `KEEPY_DRAWN_HEIGHT` is both -- and passing his height here is
## unchanged and stays correct. For the badger they do NOT: it is frozen on
## a running frame and leaned, so its crown is `BADGER_HANG_CROWN` over its
## node and its drawn soles are `BADGER_HANG_DRAWN_SOLE` from it rather
## than on it. Passing `BADGER_DRAWN_HEIGHT` here put its feet 0.45 u UNDER
## the ground
## for the whole crossing -- measured by `ZiplineRideProbe`, not reasoned
## about.
##
## ⚠️ THE HEIGHT IS MEASURED DOWN FROM THE GRAB BAR, NOT FROM THE CABLE,
## and that is arithmetic rather than taste. A rider hangs BY THE HANDS, so
## his crown sits just under the bar; measuring from the cable instead put
## Keepy's head 0.19 u ABOVE the bar he is supposed to be holding. The bar
## is `bar_drop` below the cable and the crown `hang_clearance` below the
## bar, so the FEET land at
##
##     cable_height - bar_drop - hang_clearance - height
##
## which for Keepy is 2.0 - 0.24 - 0.05 - 1.3501 = 0.3599 in world terms.
## The deck is at 0.90, so boarding is a step off the platform and a
## 0.54 u drop onto the handle -- which is what a zipline is.
##
## ⚠️ THE BAR IS SHARED AND THE POSE IS NOT, which is the whole shape of
## the 4 septembre 2026 fix. `bar_drop` and `hang_clearance` describe ONE
## PHYSICAL OBJECT -- the crown line 1.71 u up that the trolley hands both
## riders -- so they stay shared and stay exactly where Keepy's device-
## validated trip left them. What is now per-body is the POSE hung off that
## line: the crown offset passed in here, and the sole offset its owner
## publishes beside it. `crown_above_origin` still cancels out of the CROWN
## position -- `crown = (cable_height - bar_drop - hang_clearance -
## crown_above_origin) + crown_above_origin` -- so BOTH crowns still land
## on the same 1.71 regardless of who is hanging, and only the node, and
## with it the soles, moves per rider.
##
## The two riders that ship, in world terms:
##
##     rider    crown offset   node y     drawn sole   soles land at
##     Keepy      1.350100     0.359900     0.000000       0.359900
##     badger     1.444291     0.265709    -0.019240       0.246469
##
## Both soles off the ground, both under the 0.90 deck, both crowns on
## 1.71: the badger's boarding drop is simply a longer one.
##
## `sign` is -1 for the near-side seat and +1 for the far one; nothing here
## decides WHICH rider takes which, that is the caller's.
func _zip_seat(sign: float, crown_above_origin: float) -> Vector3:
	if _zipline.is_empty():
		return Vector3.ZERO
	var lateral: float = sign * float(_zipline["rider_lateral"])
	var drop: float = float(_zipline["bar_drop"]) + float(_zipline["hang_clearance"]) \
		+ crown_above_origin
	return Vector3(lateral, -drop, 0.0)

## A tap on the waiting badger. ONE tap buys the whole thing -- the hop
## chain walks to the tower and `_on_hop_landed` boards on arrival --
## because that is exactly how a tap on the boat, the ladder and the perch
## already behave.
##
## ⚠️ RENAMED FROM `_on_tapped_zipline` (tier 3), alongside the signal --
## see HubTapInput.gd. Behaviour unchanged: this is still the ACCOMPANIED
## ride, the only one that moves the badger.
func _on_tapped_zipline_badger(point: Vector3) -> void:
	if _fallback_menu.visible or _confirm.is_open():
		return
	if _keepy.is_riding() or _keepy.is_on_board() or _keepy.is_on_zipline() or _keepy.is_on_carrier():
		return
	_boarding = false
	_climbing = false
	_flying = false
	_entering = false
	_zipping = true
	_zipping_solo = false
	_keepy.hop_to(point)
	# Already standing at the tower: nothing to walk, so board on the spot
	# rather than waiting for a landing that will never come. THE
	# ZERO-LENGTH WALK, which this repo shipped a bug on once: `_advance()`
	# ends a walk shorter than ARRIVE_EPSILON with `became_idle` and NEVER
	# with `hop_landed`, so a hotspot wired only to the landing does
	# nothing at all when the player is already there.
	if not _keepy.is_hopping():
		_try_zip_badger(_keepy.global_position)

## A tap on the STRUCTURE of a tower -- deck, mast or stair, at EITHER end
## -- for a SOLO ride: Keepy crosses alone and the badger is never touched.
##
## THE DOCTRINE CHANGE, IN CODE. RECON 1 read as "the stair carries
## nothing"; Mathieu has since asked for exactly this second target, and
## `ZiplineDoor.accepts_structure_tap` withdraws on the boat's own terms
## and cannot agree with the badger channel on the same tap -- see that
## file's header for the reasoning in full and docs/lots/CH21_TYROLIENNE.md
## for the doctrine note.
func _on_tapped_zipline_solo(point: Vector3) -> void:
	if _fallback_menu.visible or _confirm.is_open():
		return
	if _keepy.is_riding() or _keepy.is_on_board() or _keepy.is_on_zipline() or _keepy.is_on_carrier():
		return
	_boarding = false
	_climbing = false
	_flying = false
	_entering = false
	_zipping = false
	_zipping_solo = true
	_keepy.hop_to(point)
	# THE SAME ZERO-LENGTH-WALK GUARD the badger channel carries, for the
	# same reason: a hotspot wired only to `hop_landed` does nothing when
	# the player is already standing on the structure.
	if not _keepy.is_hopping():
		_try_zip_solo(_keepy.global_position)

## Boards the ACCOMPANIED ride if the landing is close enough to the
## waiting badger. Returns true when the step onto the handle started, so
## the caller can stop looking at that landing.
##
## ⚠️ RENAMED FROM `_try_zip` (tier 3), body otherwise unchanged except for
## the `_zip_trip` entry, which now says explicitly who is aboard -- see
## `_apply_zip` and `_on_zip_trip_finished`, which both read it.
##
## The proximity test is the SAME radius the tap used, for the reason the
## boat's and the ladder's are: a player who tapped the badger and walked
## to it cannot arrive and be told they are not there yet.
##
## ⚠️ AND THE INTENT SURVIVES A LANDING THAT HAS NOT ARRIVED YET. That was
## the boarding walk's own measured defect, green for a whole batch because
## the arrival happened to fall inside the radius on hop one. The walk from
## anywhere on the plateau to x ~ +26 is many hops.
func _try_zip_badger(position: Vector3) -> bool:
	if _zipline.is_empty() or not _zipline_door.is_available():
		_zipping = false
		return false
	var flat := Vector3(position.x, 0.0, position.z)
	if flat.distance_to(_zipline_door.rider_position()) > ZiplineDoor.BOARD_TAP_RADIUS:
		return false
	var carrier: Node3D = _zipline.get("carrier")
	if carrier == null or not is_instance_valid(carrier):
		_zipping = false
		return false
	var from_end: int = _zipline_door.waiting_end()
	var to_end: int = _zipline_door.far_end()
	if from_end < 0 or to_end < 0:
		_zipping = false
		return false
	# The trolley is parked at whichever end the badger is CURRENTLY waiting
	# -- which may be either tower now that it no longer walks itself home
	# after a trip (4 septembre 2026, tier 3 revision -- see the doctrine
	# note above `_on_zip_trip_finished`) -- but re-parked explicitly rather
	# than trusted, for the reason `_try_zip_solo` re-parks: a silent
	# mismatch between "where the badger stands" and "where the handle
	# actually is" would put Keepy's boarding arc at the wrong tower.
	_park_carrier_at(from_end)
	if not _keepy.board_zipline(carrier, _zip_seat(-1.0, KEEPY_DRAWN_HEIGHT)):
		return false
	_zipping = false
	# BOTH ENDS CLOSE HERE, before a single frame of travel. The withdrawal
	# starts at the step onto the handle and not at the arrival, so the
	# window in which a second tap could start a second trip is empty.
	_zipline_door.set_riding(true)
	_zip_trip = {"from": from_end, "to": to_end, "keepy": true, "badger": true}
	# The badger takes its seat at the same instant, and SNAPS: the rig
	# ships a walk and a run and no climb, so there is nothing to play
	# between standing and hanging. It is the bear's own documented snap,
	# and it happens on the frame Keepy leaves the ground rather than on
	# arrival, so the pair is never seen half-boarded.
	_badger_take_seat()
	return true

## Boards a SOLO ride if the landing is close enough to either tower's own
## structure point. Returns true when the step onto the handle started, so
## the caller can stop looking at that landing.
##
## WHICH END, DECIDED HERE AND NOT AT THE TAP -- the same rule the badger's
## own boarding follows. The badger is one body with one door-tracked
## position, so `_try_zip_badger` reads `waiting_end()`; the structure is
## two FIXED points, so the direction here is simply whichever tower Keepy
## is actually standing beside on arrival, read off his live position the
## way `rider_position()` is read off the badger's.
func _try_zip_solo(position: Vector3) -> bool:
	if _zipline.is_empty() or not _zipline_door.is_available():
		_zipping_solo = false
		return false
	var towers: Array = _zipline["towers"]
	var flat := Vector3(position.x, 0.0, position.z)
	var from_end: int = -1
	for i in towers.size():
		if flat.distance_to((towers[i]["position"] as Vector3)) <= ZiplineDoor.STRUCTURE_TAP_RADIUS:
			from_end = i
			break
	if from_end < 0:
		# NOT YET, and the intent SURVIVES -- the boarding walk's own
		# measured defect, on the terms `_try_zip_badger`'s own comment
		# describes: a walk from anywhere on the plateau to either tower is
		# many hops.
		return false
	var to_end: int = 1 - from_end
	var carrier: Node3D = _zipline.get("carrier")
	if carrier == null or not is_instance_valid(carrier):
		_zipping_solo = false
		return false
	# THE TROLLEY MUST BE AT THIS END BEFORE BOARDING STARTS, and it cannot
	# be trusted to already be there: unlike the badger, which only ever
	# taps from wherever it is standing, a solo tap can be the FIRST thing
	# that happens at an end the carrier was last left at by a DIFFERENT
	# kind of trip. `board_zipline` reads the carrier's position once, at
	# the moment it is called, to aim Keepy's boarding arc -- a stale
	# carrier would arc him towards empty air at the wrong tower.
	_park_carrier_at(from_end)
	# Read BEFORE `set_riding(true)` clears it: a solo trip never touches the
	# badger, so the door has to reopen at whichever end it was ALREADY
	# waiting at, not at either end this trip actually visits. See the
	# "badger_at" read in `_on_zip_trip_finished`.
	var badger_at: int = _zipline_door.waiting_end()
	if not _keepy.board_zipline(carrier, _zip_seat(0.0, KEEPY_DRAWN_HEIGHT)):
		return false
	_zipping_solo = false
	_zipline_door.set_riding(true)
	_zip_trip = {"from": from_end, "to": to_end, "keepy": true, "badger": false, "badger_at": badger_at}
	return true

## Puts the trolley on the anchor for `end_index`, regardless of where it
## was last left. Used at the start of EVERY trip (both `_try_zip_*`
## functions) and at the end of one (`_on_zip_trip_finished`), so the
## carrier's position is never assumed to have carried over correctly from
## whatever kind of trip ran before it.
func _park_carrier_at(end_index: int) -> void:
	if _zipline.is_empty():
		return
	var carrier: Node3D = _zipline.get("carrier")
	if carrier == null or not is_instance_valid(carrier):
		return
	var cable: Dictionary = _zipline["cable"]
	carrier.global_position = cable["to"] if end_index == 1 else cable["from"]

## Puts the badger on its side of the handle and holds the measured hang
## pose. The pose is taken BEFORE the first placement so the rig is never
## drawn one frame mid-stride at handle height.
func _badger_take_seat() -> void:
	if _badger == null or _zipline.is_empty():
		return
	_badger.freeze_at(BADGER_HANG_CLIP, BADGER_HANG_TIME)
	_badger.set_model_pitch(BADGER_HANG_PITCH_DEG)
	_badger_follow_zipline()

## Writes the badger onto its seat on the trolley. Position AND facing, the
## same two things `follow_zipline` writes for Keepy, in the same frame the
## carrier was written.
func _badger_follow_zipline() -> void:
	if _badger == null or _zipline.is_empty():
		return
	var carrier: Node3D = _zipline.get("carrier")
	if carrier == null or not is_instance_valid(carrier):
		return
	# ITS OWN CROWN OFFSET, NOT ITS STANDING HEIGHT. `BADGER_DRAWN_HEIGHT`
	# here is what put this body under the ground for a whole crossing --
	# see `_zip_seat` and `BADGER_HANG_CROWN`.
	_badger.global_position = carrier.to_global(_zip_seat(1.0, BADGER_HANG_CROWN))
	# Facing the way the trolley travels, read off the carrier's own basis
	# -- the same one fact Keepy's `follow_zipline` reads, so the two riders
	# cannot end up looking different ways along one wire.
	_badger.face(carrier.global_transform.basis * Vector3.BACK)

## Keepy has taken the handle: the trolley starts moving.
##
## Hung off the MOUNT signal and not off either `_try_zip_*`, because
## boarding is an arc: starting the trip when the tap resolved would have
## run the cable out from under a body still in the air over the deck.
##
## ⚠️ FIRES FOR A SOLO BOARDING TOO. `board_zipline` is the one function
## both `_try_zip_badger` and `_try_zip_solo` call, and `zipline_mounted`
## does not know which of them just fired -- it only starts the trip
## `_zip_trip` already describes, badger or not.
func _on_zipline_mounted() -> void:
	if _zip_trip.is_empty() or _zipline.is_empty():
		return
	# WRITTEN AT t = 0 STRAIGHT AWAY, before the tween exists. A Tween's
	# first step lands on the NEXT frame, and on a RETURN trip the trolley
	# still carries the heading of the outbound run until that step -- so
	# without this, one frame of every return would draw two riders facing
	# backwards up their own wire. Caught by the probe rather than reasoned
	# about, and it is the same "placed straight away rather than waiting
	# for the next step" the bear's mount already does for its own frame.
	_apply_zip(0.0)
	var trip: Tween = _build_zip_trip()
	if trip == null:
		return
	trip.finished.connect(_on_zip_trip_finished, CONNECT_ONE_SHOT)

## Builds and starts the trolley's tween, and returns it.
##
## `tween_method` on a NORMALISED t, for the turnstile's measured reason:
## both riders are written in the same call as the carrier, so neither can
## be a frame behind the handle they are holding -- see `_apply_zip`.
##
## LINEAR, deliberately. A zipline is a body released onto a level wire; it
## has no reason to ease in or out, and the two ends are the two towers'
## own anchors, so the trip starts and finishes exactly where the cable is
## drawn rather than near it. An ease here would also be a second speed
## curve laid over `ZIPLINE_RIDE_S`, which is already floored against
## `RIDE_SPEED_FLOOR`.
func _build_zip_trip() -> Tween:
	var carrier: Node3D = _zipline.get("carrier")
	if carrier == null or not is_instance_valid(carrier):
		return null
	var tween := carrier.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(_apply_zip, 0.0, 1.0, ZIPLINE_RIDE_S)
	return tween

## Moves the trolley to its place on the cable at `t`, and -- in the SAME
## call, immediately after -- moves whichever riders THIS trip carries.
##
## ⚠️ THE RIDERS ARE WRITTEN HERE AND NOWHERE ELSE. Not in the badger's own
## `_process`, not on a signal: a rider that reads its carrier on its own
## callback was MEASURED a full frame behind on the turnstile (12.0 deg at
## the peak of the shove), and `process_priority` did not move it, because
## Tween steps land after every node's `_process`. That was 12 degrees on a
## prop turning in place; this carrier crosses 25.9 u in 4 s, so one frame
## is 10.8 cm of visible slip between a body and the handle it is holding.
##
## ⚠️ GATED ON `_zip_trip`'s OWN "keepy"/"badger" FLAGS (tier 3), not on
## `is_on_zipline()` alone for the badger's half: the badger's own state
## has no "is riding" query, so without this flag its own UNACCOMPANIED
## return leg (see `_on_zip_trip_finished`) would fall through to the
## `if _keepy.is_on_zipline()` guard below and move Keepy too, off whatever
## he is doing on the ground he was just dropped on.
##
## The interpolation is between the two ANCHORS the builder published, not
## between the two tower positions: the anchor is where the cable is
## actually strung, and re-deriving it here would be a second answer to
## "where does the wire run".
func _apply_zip(t: float) -> void:
	if _zipline.is_empty() or _zip_trip.is_empty():
		return
	var carrier: Node3D = _zipline.get("carrier")
	if carrier == null or not is_instance_valid(carrier):
		return
	var cable: Dictionary = _zipline["cable"]
	var from_anchor: Vector3 = cable["from"] if int(_zip_trip["from"]) == 0 else cable["to"]
	var to_anchor: Vector3 = cable["to"] if int(_zip_trip["from"]) == 0 else cable["from"]
	carrier.global_position = from_anchor.lerp(to_anchor, t)
	# The trolley's basis is the builder's -- +Z along the span -- so a
	# return trip has to turn it round. Written every step for the reason
	# the position is: one call owns the carrier's whole transform.
	var travel: Vector3 = to_anchor - from_anchor
	travel.y = 0.0
	if travel.length_squared() > 0.000001:
		carrier.global_rotation_degrees.y = rad_to_deg(atan2(travel.x, travel.z))
	# Only the riders of THIS trip, and only while they are aboard.
	if bool(_zip_trip.get("keepy", false)) and _keepy.is_on_zipline():
		_keepy.follow_zipline()
	if bool(_zip_trip.get("badger", false)):
		_badger_follow_zipline()

## The trolley has arrived. Whoever it carried comes off, and the door opens
## again at the end it just arrived at.
##
## ⚠️ REVERSAL, 4 SEPTEMBRE 2026 (tier 3, later the same day it shipped) --
## Mathieu's explicit call, made after testing the automatic-return build on
## device. The PREVIOUS lot ("solo zipline ride on the structure + badger's
## automatic return home", commit 2b3c3b9 / merge 7938317) had the badger
## walk itself back to a fixed `BADGER_HOME_END` (south) at the end of every
## accompanied trip, by chaining an unaccompanied return leg onto the trip
## that had just landed elsewhere. That chain is REMOVED here: the badger no
## longer has a home end at all. It simply stays, mounted and idle, at
## whichever end an accompanied trip actually delivered it to, until the
## NEXT accompanied trip -- launched from THAT end -- moves it again.
##
## Nothing else about the shape changes: `ZiplineDoor` was already built to
## read the badger's position live rather than off a remembered constant
## (see its header, "WHY THE TAP TARGET IS THE BADGER AND NOT THE STAIR",
## and `rider_position()`), and `_try_zip_badger` already reads
## `waiting_end()` rather than a hand-typed end index -- so dropping the
## chain is the whole of the change; no other function needed to become
## end-aware, because none of them assumed a fixed end to begin with.
##
## A SOLO trip (`"badger": false`) never touched the badger and never did --
## the door simply reopens on the same frame the trip ends, at the end it
## arrived at, exactly as it always has.
func _on_zip_trip_finished() -> void:
	if _zip_trip.is_empty() or _zipline.is_empty():
		return
	var arrived: int = int(_zip_trip["to"])
	var had_keepy: bool = bool(_zip_trip.get("keepy", false))
	var had_badger: bool = bool(_zip_trip.get("badger", false))
	# Only meaningful for a solo trip -- the end the badger was ALREADY
	# waiting at before this trip, which never touched it, and which
	# `set_riding(true)` overwrote to -1 the moment boarding started.
	var badger_at: int = int(_zip_trip.get("badger_at", -1))
	_zip_trip = {}
	var towers: Array = _zipline["towers"]
	# Parked EXPLICITLY on the anchor rather than left wherever the last
	# tween step wrote it. The lerp closes exactly, so this is a no-op to
	# the float -- which is precisely why it is cheap, and why a trip cut
	# short (a tween killed, a scene torn down mid-cable) still leaves the
	# trolley on a tower rather than stranded over the plateau.
	_park_carrier_at(arrived)

	# KEEPY COMES OFF ON THIS LEG, REGARDLESS OF WHAT THE BADGER DOES NEXT.
	# He was carried by THIS leg only if `had_keepy` says so -- the badger's
	# own chained return leg carries nobody else, and must not re-drop a
	# Keepy who already left on the leg before it.
	if had_keepy and _keepy.is_on_zipline():
		# The same ring every other prop drops him clear on, and the same
		# function: it reads "position" and "radius" and knows nothing about
		# what kind of prop it is looking at.
		var landing: Vector3 = _ride_exit_point({
			"position": towers[arrived]["position"],
			"radius": float(_zipline["clear_radius"]),
		})
		_keepy.leave_zipline(landing)

	if had_badger:
		_badger.set_model_pitch(0.0)
		_badger.global_position = _badger_rest(arrived)
		_badger.face(_badger_facing(arrived))
		_badger.freeze_at(&"Walking", 0.0)

	# The door re-opens at wherever the badger ACTUALLY is: this trip's own
	# arrival when it rode along, or the end it was already waiting at
	# (read before boarding, above) when this was a solo trip that never
	# touched it -- never `arrived`, which for a solo trip names where
	# KEEPY went, not the badger.
	_zipline_door.set_riding(false, arrived if had_badger else badger_at)

func _apply_swamp_palette() -> void:
	var env: Environment = _world_env.environment
	if env == null:
		return
	# Carte-blanche (voie A): the hub has its own light palette. The sky
	# comes from CozyPalette, and the engine fog is switched OFF -- it is
	# not functional on WebGL2 (Godot #97875 / #92019) and the decor and
	# ground shaders write their own haze toward the same colour, so a
	# device that DID fog would otherwise haze twice.
	env.background_color = CozyPalette.SKY
	env.ambient_light_color = _PALETTE.ambient_light_color
	env.ambient_light_energy = _PALETTE.ambient_light_energy
	env.fog_enabled = false
	env.fog_light_color = CozyPalette.HAZE
	env.fog_density = 0.0

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
	_pulse_campfire_marker(here)
	_mooring.update(here)
	_transport.update(here)

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

## The campfire's own approach cue, `_pulse_cabin_markers()`'s twin and NOT
## folded into that function or `_cabin_markers` -- CAMPFIRE_TAP_RADIUS
## (1.8) is not CABIN_TAP_RADIUS (1.30), and `_pulse_cabin_markers()` reads
## the cabin's constant for every entry in its array by construction. Mixing
## the campfire in there would breathe it at the wrong distance. Same
## hysteresis, same HubPortal thresholds -- one rule about what "near" means
## on this plateau, restated at this marker's own radius rather than a
## shared one that does not apply to it.
func _pulse_campfire_marker(here: Vector3) -> void:
	if _campfire_marker == null:
		return
	var flat := Vector2(_campfire_marker.position.x - here.x,
			_campfire_marker.position.z - here.z)
	var d: float = flat.length()
	if d <= CAMPFIRE_TAP_RADIUS * HubPortal.NEAR_FACTOR:
		_campfire_marker.set_near(true)
	elif d >= CAMPFIRE_TAP_RADIUS * HubPortal.NEAR_RELEASE:
		_campfire_marker.set_near(false)

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
	# The seesaw is intercepted by state like the rest -- but since 2
	# SEPTEMBRE 2026 the tap it refuses is NOT dropped. A tap on the same
	# prop re-pumps it; a tap anywhere else ends the ride and sends him
	# there, because the seat now outlives the rock and a held seat needs a
	# way out. That is the boat's rule, not the turnstile's: a roundabout
	# ends on its own, so dropping the tap costs nothing; a plank you can
	# sit on forever would otherwise trap the body with no exit at all.
	if _keepy.is_on_seesaw():
		if _repump_seesaw(point):
			return
		_leave_seesaw_towards(point)
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
	# A tap while the TROLLEY owns the body is intercepted by state like
	# every carried state above, for the identical reason: the point
	# arrived resolved on the y = 0 plane, so it must never become
	# somewhere to walk to while he is hanging off a wire two metres up.
	#
	# ⚠️ DROPPED, AND THE LICENCE FOR DROPPING IT IS NARROW. RECON 1: this
	# is legitimate ONLY because the trip is BOUNDED -- a linear tween of
	# ZIPLINE_RIDE_S that always ends on the far tower's own anchor, after
	# which `_on_zip_trip_finished` hands the body back and reopens the
	# door. It is the owl's licence and it is NOT to be extended to any
	# phase that could last indefinitely. The seesaw re-pumps and the
	# turnstile re-shoves because a plank and a roundabout are things you
	# push again; a wire between two fixed towers is not, and a trip that
	# could be extended would stop being bounded, which is the only reason
	# this branch is allowed to exist.
	#
	# The tap is not LOST either: the withdrawal is what let it reach the
	# ground path at all, and the arrival's `leave_zipline` carries the
	# player's next destination across the drop the way `leave_ride` does.
	if _keepy.is_on_zipline():
		return
	# v3: a tap while the BALLOON carries him is dropped on the zipline's
	# exact licence -- the trip is a bounded tween that always ends on a
	# dock, after which `_on_balloon_trip_finished` hands the body back --
	# and it reaches this branch at all only because both docks withdrew.
	if _keepy.is_on_carrier():
		return
	# Any ordinary tap cancels a boarding walk in progress: the player
	# aimed somewhere else, and arriving at the boat anyway would be the
	# screen overruling them.
	_boarding = false
	_climbing = false
	_flying = false
	_entering = false
	_zipping = false
	_zipping_solo = false
	_ballooning = -1
	_balloon_wait = -1
	_mounting_ball = false
	# v3: a tap on HIMSELF while standing still on the ball is "get off".
	if _keepy.is_on_vehicle() and not _keepy.is_hopping():
		var me := Vector3(_keepy.global_position.x, 0.0, _keepy.global_position.z)
		if me.distance_to(Vector3(point.x, 0.0, point.z)) < 0.9:
			_keepy.dismount_vehicle()
			return
	_hop_via_corridor(point)

## Carte-blanche v2 -- the autumn hollow hangs off the plateau by a
## corridor, so the walkable region is no longer convex: a straight hop
## from the plateau into the hollow cuts through the hedge (measured: a
## walk (-25,-30) -> (-6,-56) passed (-19.3, -37.8), outside the region).
## KeepyHopper hops in straight lines and clamps only its DESTINATION, so
## the detour lives here: a tap that changes zone first walks to the
## corridor gate, then on to the target. Nothing about same-zone taps or
## the plateau's own navigation changes.
const CORRIDOR_GATE: Vector3 = Vector3(-28.0, 0.0, -38.5)
var _via_target: Vector3 = Vector3.INF

func _hop_via_corridor(point: Vector3) -> void:
	var here: Vector3 = _keepy.global_position
	var target: Vector3 = HubRegion.clamp_to(point)
	if HubRegion.in_autumn(here) != HubRegion.in_autumn(target) and Vector2(here.x - CORRIDOR_GATE.x, here.z - CORRIDOR_GATE.z).length() > 1.5:
		_via_target = target
		_keepy.hop_to(CORRIDOR_GATE)
		return
	_via_target = Vector3.INF
	_keepy.hop_to(point)

## A tap on the moored boat. ONE tap buys the whole thing -- the hop chain
## walks to the water and _on_hop_landed boards on arrival -- because that
## is already how a tap across the plateau behaves, and a boat that needed
## a second tap would be the one object on this screen that did not.
func _on_tapped_boat(point: Vector3) -> void:
	if _fallback_menu.visible or _confirm.is_open():
		return
	if _keepy.is_riding() or _route == null or _keepy.is_on_zipline() or _keepy.is_on_carrier():
		return
	_boarding = true
	_climbing = false
	_flying = false
	_zipping = false
	_zipping_solo = false
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
	if _keepy.is_riding() or _keepy.is_on_board() or _keepy.is_on_zipline() or _keepy.is_on_carrier():
		return
	_boarding = false
	_climbing = true
	_flying = false
	_zipping = false
	_zipping_solo = false
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
	# NOR WHILE THE TROLLEY HAS HIM. A trip emits no landings either, so
	# this branch should be as unreachable as the four above -- and it is
	# written for their reason: "no landing is emitted" is a property of
	# KeepyHopper that could change, and the failure it would cause is
	# being carried into a sub-game on a wire the player was crossing the
	# plateau on.
	if _keepy.is_on_zipline():
		return

	# WHERE KEEPY IS, decided before anything about what this landing goes
	# on to TRIGGER. A landing in a portal still updates the tint on its way
	# to opening the dialog; a landing that starts a ride still reports the
	# ground it left from. Both of the branches below return early, so a
	# tint placed after them would simply stop updating on the landings that
	# do something -- silently, and only sometimes.
	var in_water: bool = _water != null and _water.contains(position)
	_set_keepy_wet(in_water and not _keepy.is_on_vehicle())

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
	# And the one that finishes a walk to the waiting badger takes the
	# handle. Sits with the other four -- after the tint and the impact,
	# before the portals -- for the reason they do: a landing that goes on
	# to ride still reports the ground it left from, and every branch past
	# this point returns.
	if _zipping and _try_zip_badger(position):
		return
	# And the one that finishes a walk to the STRUCTURE (tier 3) takes the
	# handle alone. Sits right after the badger's own branch, on the same
	# terms: a landing that goes on to ride solo still reports the ground
	# it left from, and every branch past this point returns.
	if _zipping_solo and _try_zip_solo(position):
		return
	if _ballooning >= 0 and _try_balloon(position):
		return
	if _mounting_ball and _try_mount_ball(position):
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
	if _via_target != Vector3.INF:
		var onward: Vector3 = _via_target
		_via_target = Vector3.INF
		var here: Vector3 = _keepy.global_position
		if Vector2(here.x - CORRIDOR_GATE.x, here.z - CORRIDOR_GATE.z).length() < 1.5:
			_keepy.hop_to(onward)
			return
	_boarding = false
	_climbing = false
	_flying = false
	_entering = false
	_zipping = false
	_zipping_solo = false
	_ballooning = -1
	_mounting_ball = false

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

## ---- v2 weather --------------------------------------------------------
## Where the bear shelters from rain: under the layout tree at
## (6.643, 32.682) beside its rest, 1.5 u from the trunk on the rest side.
const BEAR_SHELTER: Vector3 = Vector3(5.3, 0.0, 33.7)
const BEAR_SHELTER_NEAR: float = 1.2

func _setup_weather() -> void:
	_weather.set_overlay(_weather_overlay)
	_weather.weather_changed.connect(_on_weather_changed)
	# The forcing row is for device validation on the throwaway preview;
	# the same hostname test that gates the guest bypass hides it on
	# staging / prod. Also shown off-web (editor / sandbox captures).
	var show: bool = Auth.is_untrusted_preview_domain() or not OS.has_feature("web")
	_weather_label.visible = show
	_weather_row.visible = show
	_weather_row.get_node("SunButton").pressed.connect(func(): _weather.force(CozyWeather.Kind.SUN))
	_weather_row.get_node("RainButton").pressed.connect(func(): _weather.force(CozyWeather.Kind.RAIN))
	_weather_row.get_node("StormButton").pressed.connect(func(): _weather.force(CozyWeather.Kind.STORM))
	_weather_row.get_node("SnowButton").pressed.connect(func(): _weather.force(CozyWeather.Kind.SNOW))
	_weather_row.get_node("AutoButton").pressed.connect(func(): _weather.force_auto())

## The bear takes shelter under the tree beside its rest when the sky
## turns, and comes back out in the sun -- only when it is IDLE at one of
## the two spots, so a seesaw or campfire trip is never interrupted (those
## walk it from wherever it stands, and it goes home to BEAR_REST after,
## where the next weather change picks it up again).
func _on_weather_changed(kind: int) -> void:
	if _bear == null or _bear.is_walking() or _bear_pivot != null or not _bear_pending.is_empty() or _bear_campfire_leg != &"":
		return
	var here: Vector3 = _bear.global_position
	var bad: bool = kind != CozyWeather.Kind.SUN
	if bad and Vector2(here.x - BEAR_REST.x, here.z - BEAR_REST.z).length() < BEAR_SHELTER_NEAR:
		_bear.walk_to(BEAR_SHELTER)
	elif not bad and Vector2(here.x - BEAR_SHELTER.x, here.z - BEAR_SHELTER.z).length() < BEAR_SHELTER_NEAR:
		_bear.walk_to(BEAR_REST)

func _on_fallback_toggled() -> void:
	_fallback_menu.visible = not _fallback_menu.visible

## ---- v3 P1: transport -- balloon lines and the hoppity ball ------------
## Intents on the boat's model: set by the tap, tried on every landing AND
## immediately (a zero-length walk emits no landing), cleared by any other
## tap and when the chain runs out.
var _ballooning: int = -1
## The line whose balloon has been CALLED (or is in flight) while Keepy
## waits at a dock. Survives `became_idle`: the wait IS standing still.
var _balloon_wait: int = -1
var _mounting_ball: bool = false

func _setup_transport() -> void:
	_transport.setup(_keepy, _camera, _weather)
	_tap.tapped_balloon.connect(_on_tapped_balloon)
	_tap.tapped_vehicle.connect(_on_tapped_vehicle)
	_transport.trip_finished.connect(_on_balloon_trip_finished)

## A tap on a dock. ONE tap buys the whole thing: walk there, board if the
## balloon waits here, call it if it waits at the twin dock, wait for it if
## it is in the air.
func _on_tapped_balloon(point: Vector3) -> void:
	if _fallback_menu.visible or _confirm.is_open():
		return
	if _keepy.is_riding() or _keepy.is_on_board() or _keepy.is_on_zipline() or _keepy.is_on_carrier() or _keepy.is_on_owl_flight():
		return
	var line: int = _transport.accepts_balloon_tap(point)
	if line < 0:
		_hop_via_corridor(point)
		return
	_boarding = false
	_climbing = false
	_flying = false
	_entering = false
	_zipping = false
	_zipping_solo = false
	_mounting_ball = false
	_balloon_wait = -1
	_ballooning = line
	_keepy.hop_to(point)
	if not _keepy.is_hopping():
		_try_balloon(_keepy.global_position)

## Boards / calls if the landing is on the dock. The intent SURVIVES a
## landing that is not there yet (the boat's measured defect).
func _try_balloon(position: Vector3) -> bool:
	if _ballooning < 0:
		return false
	var line: int = _ballooning
	var dock: int = _transport.nearest_dock(line, position)
	var here := Vector3(position.x, 0.0, position.z)
	if here.distance_to(_transport.dock_position(line, dock)) > HubTransport.DOCK_TAP_RADIUS:
		return false
	_ballooning = -1
	if not _transport.is_line_idle(line):
		_balloon_wait = line
		return true
	if _transport.balloon_at(line) == dock:
		_board_balloon(line, dock)
		return true
	# It waits at the twin dock: call it over, empty, and wait here.
	_transport.depart(line, _transport.balloon_at(line), false)
	_balloon_wait = line
	return true

func _board_balloon(line: int, dock: int) -> bool:
	if not _keepy.mount_carrier(_transport.balloon(line), HubTransport.SEAT):
		return false
	return _transport.depart(line, dock, true)

## A trip ended at `dock`. The rider steps off onto the ring round the
## dock (the turnstile's exit search, unchanged); a waiting Keepy boards.
func _on_balloon_trip_finished(line: int, dock: int, empty: bool) -> void:
	var at: Vector3 = _transport.dock_position(line, dock)
	if not empty and _keepy.is_on_carrier():
		_keepy.leave_carrier(_ride_exit_point({"position": at, "radius": HubTransport.DOCK_TAP_RADIUS}))
		return
	if _balloon_wait != line:
		return
	_balloon_wait = -1
	if _keepy.is_hopping() or _keepy.is_on_carrier() or _keepy.is_riding() or _keepy.is_on_board():
		return
	var here := Vector3(_keepy.global_position.x, 0.0, _keepy.global_position.z)
	if here.distance_to(at) <= HubTransport.DOCK_TAP_RADIUS:
		_board_balloon(line, dock)
	elif here.distance_to(_transport.dock_position(line, 1 - dock)) <= HubTransport.DOCK_TAP_RADIUS:
		# It landed at the wrong end for him (called from the other dock
		# while it was already flying there): call it once more.
		_transport.depart(line, dock, false)
		_balloon_wait = line

## A tap on the parked ball: walk to it and climb on.
func _on_tapped_vehicle(point: Vector3) -> void:
	if _fallback_menu.visible or _confirm.is_open():
		return
	if _keepy.is_riding() or _keepy.is_on_board() or _keepy.is_on_zipline() or _keepy.is_on_carrier() or _keepy.is_on_owl_flight():
		return
	_boarding = false
	_climbing = false
	_flying = false
	_entering = false
	_zipping = false
	_zipping_solo = false
	_ballooning = -1
	_balloon_wait = -1
	_mounting_ball = true
	_keepy.hop_to(point)
	if not _keepy.is_hopping():
		_try_mount_ball(_keepy.global_position)

func _try_mount_ball(position: Vector3) -> bool:
	if not _mounting_ball:
		return false
	var here := Vector3(position.x, 0.0, position.z)
	if here.distance_to(_transport.ball_position()) > HubTransport.BALL_TAP_RADIUS:
		return false
	_mounting_ball = false
	return _keepy.mount_vehicle(_transport.ball_node(), HubTransport.BALL_LIFT)

## ---- v3 P0: performance overlay ---------------------------------------
## Same gate as the weather row and the guest bypass: an untrusted preview
## hostname, or off-web (sandbox captures). Shown by default there -- the
## whole point is that the device reports its numbers without being asked
## -- and the menu button hides it.
func _setup_perf() -> void:
	var show: bool = Auth.is_untrusted_preview_domain() or not OS.has_feature("web")
	_perf.visible = show
	_perf_button.visible = show
	_perf_button.text = "Perf (preview) : ON" if show else "Perf (preview) : OFF"
	_perf_button.pressed.connect(_on_perf_toggled)

func _on_perf_toggled() -> void:
	_perf.visible = not _perf.visible
	_perf_button.text = "Perf (preview) : ON" if _perf.visible else "Perf (preview) : OFF"

## For probes: the overlay's current readings.
func perf_snapshot() -> Dictionary:
	return _perf.snapshot()

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
