extends Node
## CH58 -- THE TAP THAT NEVER ARRIVED.
##
## =====================================================================
## WHAT THIS PROBE EXISTS TO GATE
##
## CH57 shipped a board Mathieu could climb onto and then never leave: on
## device, every tap made while riding did nothing at all -- no steer, no
## dismount, no error. The engine was running (the menu opened, the FPS
## line moved), so it was never a freeze; it was an input path that ended
## in a bare `return`.
##
## The defect is BRANCH ORDER in HubWorld._on_tapped_ground, and nothing
## about it is visible in either file read on its own:
##
##   * `mount_board()` puts the hopper in State.ON_CARRIER -- the same
##     state the BALLOON uses, because the board is the fifth user of the
##     carrier contract.
##   * `_on_tapped_ground` drops a tap outright while `is_on_carrier()`,
##     and that is CORRECT for the balloon: CLAUDE.md licences dropping a
##     tap only for a BOUNDED trip, "un tween qui se termine toujours a un
##     point connu", which a dock-to-dock flight is.
##   * CH57's own board branch sits FORTY-SEVEN LINES BELOW that return.
##     While riding, it is unreachable.
##
## So a board ride -- UNBOUNDED, and therefore holding no such licence --
## inherited the bounded trip's drop. That is CLAUDE.md's PATRON ECHELLE
## exactly: a player sealed inside a prop that eats every one of his taps,
## with no way out. The banned pattern was reached through a STATE the
## board shares with something that is allowed to use it, which is why no
## amount of reading either file alone would have shown it.
##
## =====================================================================
## ⚠️ WHY CH57's OWN 43 ASSERTIONS WERE ALL GREEN OVER THIS
##
## SkatePhysicsProbe drives the board by calling `mount_board()` and
## `set_board_target()` DIRECTLY. It is never once routed through
## `_on_tapped_ground`, so the whole of the shipped tap path -- the only
## path a player has -- lies outside everything it measures.
##
## That is CLAUDE.md's "un fixture qui diverge du reel sur un axe ne
## protege pas de cet axe", and the axis is the ROUTING. This probe exists
## to hold that axis, so it never calls `set_board_target` at all: every
## tap below is delivered through the real signal on the real HubTapInput
## node, into the real HubWorld listener, and what is asserted is what the
## WORLD did about it.
##
## =====================================================================
## AND IT RUNS HEADLESS -- except PHASE X, which cannot
##
## Everything here is state, transforms and signals: not one line reads a
## pixel, and under llvmpipe the hub costs 120 ms a frame (CH56 PHASE Z)
## for nothing at all. PHASE X is the exception and says so: it drives a
## real SCREEN POINT through HubTapInput._handle_point, and CLAUDE.md
## records that the dummy driver reports the viewport 0x0, so
## `_handle_point` returns before projecting and every check inside it
## would pass BY NEVER RUNNING. It asserts the rect rather than hoping.

const BUDGET_S: float = 900.0
const FPS: float = 60.0

## CLAUDE.md's published control. A bench that cannot restate a number
## already on file has no standing to publish one of its own.
const PUBLISHED_DIAGONAL_HOPS: int = 66
const PUBLISHED_DIAGONAL_S: float = 18.700
## The ceiling the hub holds itself to (CH38).
const TRAVERSE_CEILING_S: float = 22.0

## Where the board is parked for every ride below, and where a steer aims
## it: due EAST of the whole skatepark, so "nowhere near a module" is the
## DEFAULT case and the module cases are reached deliberately.
##
## ⚠️ BOTH POINTS WERE MEASURED, NOT CHOSEN. The first version of this
## probe used the park's own centre line, walked Keepy to (0, 0, 40) --
## and landed him ON THE SEESAW, because `_mount_seesaw` fires from ANY
## landing over a plank, no intent required. From ON_SEESAW `mount_carrier`
## refuses, so `mount_board()` returned false and every "he is not aboard"
## assertion downstream passed for free. These two are east of the rail
## (x <= 4.4) and of the far quarterpipe (x <= 8.0), inside the skate lobe,
## and `HubRegion.clamp_to` is the identity on both -- checked, and PHASE I
## re-checks the walk between them ends IDLE at every run.
const OPEN_GROUND: Vector3 = Vector3(12.0, 0.0, 52.0)
## A destination well clear of the board, used to prove a tap STEERS.
const AIM_AWAY: Vector3 = Vector3(12.0, 0.0, 44.0)

## How near a tap has to land to Keepy to mean "get off" -- HubWorld's own
## number, restated here so a change to it reddens this probe instead of
## silently moving what the gesture is.
const SELF_TAP_RADIUS: float = 0.9

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _transport: HubTransport = null
var _park: HubSkatepark = null
var _tap: HubTapInput = null
var _camera: Camera3D = null
var _hops: int = 0
var _idle: bool = false
## The flat-ground parallax, read once in PHASE A(1) and used as the
## control the deck case is compared against -- so "the deck aims further"
## is a measured difference and not an assertion about one number.
var _flat_parallax: float = 0.0

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE DISMOUNT PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_dismount_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _run() -> void:
	print("=== SKATE DISMOUNT PROBE -- CH58 ===")
	print("driver: %s" % DisplayServer.get_name())
	DevTools.set_physics_override(true)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	for _i in 24:
		await get_tree().process_frame
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	_park = _hub.find_child("Skatepark", true, false) as HubSkatepark
	_tap = _hub.find_child("TapInput", true, false) as HubTapInput
	_camera = _hub.find_child("Camera3D", true, false) as Camera3D
	if _keepy == null or _transport == null or _park == null or _tap == null:
		push_error("SkateDismountProbe: hub is missing Keepy / Transport / Skatepark / TapInput.")
		get_tree().quit(1)
		return
	await _phase_instrument()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every result below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_state()
	await _phase_steer()
	await _phase_dismount()
	await _phase_anywhere()
	await _phase_screen()
	await _phase_modules()
	await _phase_traversal()
	await _phase_off()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE I -- THE INSTRUMENT, POSITIVE FIRST
#
# CLAUDE.md's blind check, and it is not optional here. Every assertion
# below is of the form "the tap DID something", whose negation -- nothing
# happened -- is exactly what a bench wired to nothing also reports. So
# the bench is first shown answering YES on foot, where the shipped game
# has always worked.

func _phase_instrument() -> void:
	print("-- PHASE I: the bench can SEE a tap take effect (on foot, where it always worked) --")
	_keepy.dismount_vehicle()
	await _settle(10)
	_keepy.global_position = HubSurface.ground(OPEN_GROUND)
	await _settle(4)
	_check(not _transport.is_riding_board(), "INSTRUMENT: he starts on foot, not on the board")
	_check(not _keepy.is_hopping(), "INSTRUMENT: and standing still")
	_tap.tapped_ground.emit(HubRegion.clamp_to(AIM_AWAY))
	await _settle(4)
	_check(_keepy.is_hopping(),
		"a ground tap through the REAL signal starts a walk (so the channel is genuinely wired)")
	# And it is let FINISH -- leaving the walk running was one of this
	# probe's own two defects: `mount_carrier` refuses from any state but
	# IDLE. The other was WHERE it walked to, and this is where that is
	# caught: the destinations are asserted to be plain ground, because a
	# walk that ends on a prop leaves a state no mount can start from and
	# every case below then scores a rider who never got on.
	_keepy.dismount_vehicle()
	await _idle_hopper()
	_check(not _keepy.is_on_carrier() and not _keepy.is_on_seesaw()
			and not _keepy.is_on_vehicle() and not _keepy.is_on_tree(),
		"INSTRUMENT: the walk ended on plain ground, in no prop (else every mount below is refused)")

# =====================================================================
# PHASE S -- THE STATE THAT CAUSED IT
#
# Not a test of the fix: a test of the PREMISE. The diagnosis rests
# entirely on "riding the board leaves the hopper ON_CARRIER", which is
# what makes the balloon's drop fire on a board tap. If that ever stops
# being true the fix below stops being the fix, and this is where it
# would be noticed rather than rediscovered on a device.

func _phase_state() -> void:
	print("-- PHASE S: the premise -- a board ride IS an ON_CARRIER ride --")
	await _park_board(OPEN_GROUND)
	var mounted: bool = _transport.mount_board()
	await _settle(6)
	_check(mounted, "mount_board() took him aboard")
	_check(_transport.is_riding_board(), "the transport says he is riding the board")
	_check(_keepy.is_on_carrier(),
		"and the HOPPER is in ON_CARRIER -- the same state the balloon drops taps from")

# =====================================================================
# PHASE R -- A TAP AWAY FROM HIM MUST STEER
#
# The first of the two meanings a tap has while riding. Measured on the
# board's own PUBLISHED observable (`has_target`, `flat_position`), never
# on a position this probe also wrote.

func _phase_steer() -> void:
	print("-- PHASE R: a tap away from him STEERS the board --")
	await _remount(OPEN_GROUND)
	var body := _transport.board_body()
	_check(body != null, "INSTRUMENT: the board is a physics body (the switch is up)")
	_check(not _transport.board_has_destination(),
		"INSTRUMENT: it starts with no destination (else the check below is free)")
	_tap.tapped_ground.emit(HubRegion.clamp_to(AIM_AWAY))
	await _settle(4)
	_check(_transport.board_has_destination(),
		"the tap reached the board: the adapter now holds a destination")
	_check(_transport.is_riding_board(), "and it steered rather than ejecting him at speed")
	var before: Vector3 = body.flat_position()
	await _settle(30)
	var moved: float = body.flat_position().distance_to(before)
	print("     rolled %.3f u in 30 ticks" % moved)
	_check(moved > 0.05, "and the board actually rolled (%.3f u) -- not just a flag set on a body nothing steps" % moved)

# =====================================================================
# PHASE D -- A TAP ON HIMSELF, AT REST, MUST PUT HIM DOWN
#
# The second meaning, and the one Mathieu could not reach at all. Every
# number is read off the WORLD after the signal, never off the call that
# would have produced it.

func _phase_dismount() -> void:
	print("-- PHASE D: a tap on himself, at rest, PUTS HIM DOWN --")
	await _remount(OPEN_GROUND)
	var body := _transport.board_body()
	_check(body.at_rest(), "INSTRUMENT: the board is at rest under him")
	var here: Vector3 = _flat(_keepy.global_position)
	var off: bool = await _tap_self()
	_check(off, "a tap on himself dismounted him")
	_check(not _transport.is_riding_board(), "the transport no longer holds him")
	_check(not _keepy.is_on_carrier(), "and the hopper is out of ON_CARRIER")
	print("     stepped off %.3f u from where the board stands" % _flat(_keepy.global_position).distance_to(here))
	# The routing is HANDED BACK -- the half of the bug that is not the
	# dismount itself. A dismount that left the world thinking he was
	# aboard would swallow the very next tap in the same way.
	_tap.tapped_ground.emit(HubRegion.clamp_to(AIM_AWAY))
	await _settle(4)
	_check(_keepy.is_hopping(), "and the NEXT tap is an ordinary walk again")

# =====================================================================
# PHASE A -- WHEREVER THE BOARD IS
#
# Mathieu's own requirement, and it is four separate places rather than
# one: the brief names "immobile", "en train de toucher un collider
# (funbox)", and "nulle part pres d'un module". A dismount that only works
# on open flat ground is the shipped bug again with a smaller footprint.
#
# The DECK case carries the real risk and it is MEASURED rather than
# assumed -- see `_deck_parallax`.

func _phase_anywhere() -> void:
	print("-- PHASE A: the dismount works WHEREVER the board stands --")
	# (1) parked, untouched, nowhere near a module
	await _remount(OPEN_GROUND)
	_flat_parallax = _deck_parallax()
	print("     (1) flat ground: a finger on his drawn feet resolves %.3f u from his flat position (radius %.2f)"
		% [_flat_parallax, SELF_TAP_RADIUS])
	_check(await _tap_self(), "(1) open ground, standing still -- he gets off")
	# (2) rolling. A tap on himself mid-roll STEERS by design (CH57's own
	# rule, so a tap at speed does not eject him); the guarantee is that a
	# rider is never more than one further tap from the ground.
	await _remount(OPEN_GROUND)
	var body := _transport.board_body()
	_tap.tapped_ground.emit(HubRegion.clamp_to(AIM_AWAY))
	await _settle(10)
	_check(_transport.board_has_destination(), "(2) INSTRUMENT: it is genuinely rolling")
	var ejected: bool = await _tap_self()
	_check(not ejected, "(2) a tap on himself MID-ROLL steers instead of ejecting him at speed")
	_check(_transport.is_riding_board(), "(2) and he is still aboard")
	var freed: bool = false
	for _i in 20:
		await _settle(12)
		if _transport.board_at_rest():
			freed = await _tap_self()
			break
	_check(freed, "(2) and once it has come to rest the next tap puts him down")
	# (3) pressed into the funbox's vertical east face. A body that cannot
	# move is CH42's stall, and it is the case the brief names.
	await _remount(_side_of_funbox())
	_tap.tapped_ground.emit(HubRegion.clamp_to(_flat(_park.module_centre(0))))
	await _settle(150)
	print("     (3) after 150 ticks into the east face: at_rest=%s supported=%s"
		% [_transport.board_at_rest(), _transport.board_body().supported()])
	_check(_transport.board_at_rest(),
		"(3) INSTRUMENT: the stall guard dropped the target, so a self-tap is readable as one")
	_check(await _tap_self(), "(3) jammed against the funbox -- he still gets off")
	# (4) standing ON the funbox deck, where the tap's parallax is largest.
	var deck: Dictionary = await _ride_onto_deck()
	print("     (4) deck ride: y %.3f (deck top %.3f)  supported=%s  on_deck=%s"
		% [float(deck["y"]), float(deck["deck_h"]), deck["supported"], deck["on_deck"]])
	if not bool(deck["on_deck"]):
		_check(false, "(4) INSTRUMENT: the deck ride should have put the board on the module")
		return
	var parallax: float = _deck_parallax()
	print("     (4) on the deck: a finger on his drawn feet resolves %.3f u from his flat position (radius %.2f)"
		% [parallax, SELF_TAP_RADIUS])
	_check(parallax >= 0.0, "(4) INSTRUMENT: the parallax is measurable at all")
	_check(parallax > _flat_parallax + 0.05,
		"(4) INSTRUMENT: the deck really does move the aim further than flat ground does (%.3f vs %.3f)"
			% [parallax, _flat_parallax])
	_check(await _tap_self(), "(4) up on the funbox deck -- he still gets off")

# =====================================================================
# PHASE X -- THE WHOLE CHAIN, FROM A SCREEN POINT
#
# Everything above enters at `tapped_ground`, one link short of what a
# finger does. This phase starts where the finger does, and proves the
# ROUTING half of the fix: while riding, HubTapInput must send the tap to
# the ground channel, or the board branch is never reached whatever order
# it sits in.
#
# ⚠️ It needs a real driver, and says so rather than passing quietly.

func _phase_screen() -> void:
	print("-- PHASE X: from a real SCREEN POINT, through the real router --")
	if _tap.container == null or _tap.viewport == null:
		_check(false, "INSTRUMENT: the tap input resolved no container / viewport")
		return
	var rect: Rect2 = _tap.container.get_global_rect()
	print("     driver %s   container rect %s   viewport %s"
		% [DisplayServer.get_name(), str(rect.size), str(_tap.viewport.size)])
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or _tap.viewport.size.x <= 0:
		print("     SKIPPED: a degenerate rect makes _handle_point return before projecting, so")
		print("     every check here would pass BY NEVER RUNNING (CLAUDE.md, the dummy driver).")
		print("     Run under xvfb-run --rendering-driver opengl3 to sign this phase.")
		return
	await _remount(OPEN_GROUND)
	var body := _transport.board_body()
	body.stop()
	await _settle(2)
	var got: Array[Vector3] = []
	var sink := func(p: Vector3) -> void: got.append(p)
	_tap.tapped_ground.connect(sink)
	_tap._handle_point(rect.position + rect.size * 0.5)
	_tap.tapped_ground.disconnect(sink)
	await _settle(4)
	_check(got.size() > 0, "a screen point in the middle of the container produced a ground tap")
	_check(_transport.board_has_destination() or not _transport.is_riding_board(),
		"and the WORLD acted on it -- the tap was not swallowed")
	print("     -> %s ; riding=%s destination=%s"
		% ["nothing" if got.is_empty() else str(got[0]),
			_transport.is_riding_board(), _transport.board_has_destination()])

# =====================================================================
# PHASE M -- CH60: THE DESCENT FROM THE HIGH POINT OF EVERY SOLID MODULE
#
# CH58's lesson, and the brief's first garde-fou: A BODY THAT LEAVES THE
# GROUND IS NOT WHERE YOU TAP IT. HubCamera never rises, every tap
# resolves on HubSurface, so a raised body is DRAWN where the ground
# under it is not. Measured by PHASE A: 0.133 u on the lawn, 1.501 u on
# the funbox deck, against a 0.90 u self-tap radius -- which is why the
# gesture worked on grass and failed on the one module the chantier
# exists to climb.
#
# CH60 makes three more modules solid, and two of them are TALLER than
# the funbox. So the question is asked again, per module, and it is asked
# with the numbers rather than about them.
#
# ⚠️ AND IT IS ASKED THROUGH THE SCREEN, NOT THROUGH THE SIGNAL. The
# brief is explicit and CH58 is the reason: CH57 shipped a branch that
# was unreachable in the delivered game and had 43 green assertions over
# it, because its bench called the API directly and never once went
# through the router. `_tap_self` (used everywhere above) enters at
# `tapped_ground`, one link short of a finger. This phase enters where
# the finger does -- a CONTAINER PIXEL, through `HubTapInput._handle_point`
# -- so the projection, the ground ray, the clamp and the branch order
# are all under test rather than assumed.
#
# It therefore needs a real driver, and it SAYS SO instead of passing
# quietly: under the dummy driver the container rect is degenerate,
# `_handle_point` returns before projecting anything, and every check
# here would pass BY NEVER RUNNING (CLAUDE.md's four false greens).

func _phase_modules() -> void:
	print("-- PHASE M: the descent from the high point of EVERY solid module --")
	var live: bool = _screen_is_real()
	if not live:
		print("     driver %s: the container rect is degenerate, so the SCREEN half of this")
		print("     phase would pass by never running. Run under xvfb-run --rendering-driver")
		print("     opengl3 to sign it. The parallax half below is pure transform arithmetic")
		print("     and is gated either way.")
	for index in _park.collider_indices():
		var kind: String = String(_park.module_kind(index))
		var top: Dictionary = await _ride_to_high_point(index)
		var reached: float = float(top["peak"])
		print("     [%d] %-12s PEAK y %.3f  (drawn lip %.3f)  came to rest at y %.3f  supported=%s"
			% [index, kind, reached, float(top["lip"]), float(top["y"]), top["supported"]])
		print("     [%d] AT THE PEAK: parallax %.3f u (flat ground %.3f)   clamp shift %.3f u   radius %.2f"
			% [index, float(top["peak_parallax"]), _flat_parallax, float(top["peak_shift"]),
				SELF_TAP_RADIUS])
		if bool(top["climbed"]):
			# ⚠️ THE BRIEF'S QUESTION, ASKED AT THE HIGHEST POINT THE BOARD
			# CAN NOW REACH -- which is what CH61 moved. The parallax is
			# PUBLISHED and the clamp shift is GATED, for CH58's reason:
			# the shipped branch already compares against the DRAWN ground
			# point, so a big parallax is how wrong a naive flat
			# comparison would be, not how wrong the game is. What can
			# still break the gesture on a raised body is the clamp.
			_check(float(top["peak_parallax"]) > 0.0,
				"M[%d] INSTRUMENT: the parallax at the peak is measurable at all" % index)
			_check(float(top["peak_parallax"]) > _flat_parallax + 0.02,
				"M[%d] INSTRUMENT: being up there really does move the aim (%.3f vs %.3f flat)"
					% [index, float(top["peak_parallax"]), _flat_parallax])
			_check(float(top["peak_shift"]) < SELF_TAP_RADIUS,
				"M[%d] at the PEAK the clamp still does not push the destination off his body (%.3f < %.2f)"
					% [index, float(top["peak_shift"]), SELF_TAP_RADIUS])
		if not bool(top["climbed"]):
			# The RAIL. Its beam is 0.12 across and sits at 0.56 with the
			# board topping out at 0.26: there is no "on top of the rail"
			# for this body to reach, and saying so is the honest result.
			# A gate demanding a climb here would be a gate demanding a
			# defect.
			print("     [%d] the board never leaves the ground on this module -- see PHASE J:" % index)
			print("         it passes UNDER the beam and is stopped by a LEG. Its high point is")
			print("         the lawn, so its parallax is the flat case already gated in PHASE A.")
			_check(reached < 0.05,
				"M[%d] %s: the board stays on the ground here (y %.3f), as the geometry requires"
					% [index, kind, reached])
			continue
		# ⚠️ CH61 -- AND HERE THE TWO KINDS OF MODULE PART COMPANY.
		#
		# A DECK is a place to stand: the board stops on it and stays
		# there, so "tap yourself to get off, up on the module" is a
		# gesture that can be made at leisure and is gated below exactly
		# as CH58 and CH60 gate it.
		#
		# A TRANSITION is not. With inertia a quarterpipe does what a
		# quarterpipe does -- the board runs out of speed and comes back
		# down -- so there is no raised REST from which to tap. Demanding
		# a dismount from a resting point that physics forbids would be
		# demanding a defect, exactly as CH60 said of a gate written at
		# the rail's beam. What is owed there instead is the brief's
		# actual requirement: the channel must never be SWALLOWED at any
		# point the board can reach, and the rider must always be at most
		# one further tap from the ground. That is `_peak_gesture` below.
		if not bool(top["rests_raised"]):
			print("     [%d] a transition offers no raised REST -- the board comes back down, which is" % index)
			print("         what a quarterpipe does. The gesture is therefore tested AT THE PEAK,")
			print("         where CH58's rule makes it a STEER, and then on the ground it returns to.")
			await _peak_gesture(index, live)
			continue
		var parallax: float = _deck_parallax()
		var shift: float = _clamp_shift()
		print("     [%d] at its RESTING point: parallax %.3f u (flat ground %.3f)   clamp shift %.3f u"
			% [index, parallax, _flat_parallax, shift])
		_check(parallax > 0.0, "M[%d] INSTRUMENT: the parallax is measurable at all" % index)
		_check(parallax > _flat_parallax + 0.02,
			"M[%d] INSTRUMENT: being up on the module really does move the aim (%.3f vs %.3f flat)"
				% [index, parallax, _flat_parallax])
		# ⚠️ THE PARALLAX IS PUBLISHED, NOT GATED. It is how far a NAIVE
		# flat comparison would be wrong, and CH58 already stopped the
		# shipped code from making that comparison. Gating it would be
		# gating a number nothing reads. What CAN still break the gesture
		# on a raised body is the clamp, so that is what is gated -- and
		# what a finger really produces is gated below, by a finger.
		_check(shift < SELF_TAP_RADIUS,
			"M[%d] the clamp does not push the destination off his body (%.3f u < %.2f)"
				% [index, shift, SELF_TAP_RADIUS])
		if not live:
			continue
		# ⚠️ READ IT BEFORE THE TAP. The first version of this phase took
		# `here` AFTER `_tap_self_screen`, which awaits eight frames -- by
		# then he has stepped off and the camera has moved with him, so the
		# comparison was against a DIFFERENT frame's geometry and reported
		# 0.97 u where the truth is far smaller. CLAUDE.md, CH43: an
		# assertion on state that something else has since written is
		# re-reading the previous assertion's leftovers.
		var here: Vector3 = _flat(_drawn_ground_of(_keepy.global_position))
		var seen: Array[Vector3] = []
		var sink := func(p: Vector3) -> void: seen.append(p)
		_tap.tapped_ground.connect(sink)
		var off: bool = await _tap_self_screen()
		_tap.tapped_ground.disconnect(sink)
		# ⚠️ THE END-TO-END RESIDUAL, OBSERVED. Everything from the pixel
		# to the world point is now in the measurement: unproject, the
		# container-to-viewport scale, the pixel grid, the ground ray and
		# the clamp. It is the only number here that a computation could
		# not have produced, which is exactly why it is the one worth
		# taking.
		_check(seen.size() > 0, "M[%d] INSTRUMENT: the screen tap produced a ground point at all" % index)
		if seen.size() > 0:
			var end_to_end: float = here.distance_to(_flat(seen[0]))
			print("     [%d] END-TO-END: the finger resolved %s, HubWorld compares against %s -> %.4f u"
				% [index, str(seen[0].snappedf(0.001)), str(here.snappedf(0.001)), end_to_end])
			_check(end_to_end < SELF_TAP_RADIUS,
				"M[%d] a real finger on his drawn body lands %.4f u from what HubWorld compares it to (< %.2f)"
					% [index, end_to_end, SELF_TAP_RADIUS])
		_check(off, "M[%d] and a real SCREEN TAP on his drawn body, up on the %s, puts him down"
			% [index, kind])
		# The routing is handed back, exactly as PHASE D demands it after a
		# dismount on flat ground.
		_tap.tapped_ground.emit(HubRegion.clamp_to(AIM_AWAY))
		await _settle(4)
		_check(_keepy.is_hopping(), "M[%d] and the NEXT tap is an ordinary walk again" % index)
	# ⚠️ HAND THE WORLD BACK AT REST. PHASE T teleports the hopper and
	# calls `hop_to`; a hopper still IN FLIGHT when that happens finishes
	# somebody else's walk and reports it as the diagonal -- measured, 25
	# hops in 421 frames against the published 66 in 1122. A phase that
	# leaves state behind makes the next phase measure the wrong thing,
	# and the next phase cannot tell.
	if _transport.is_riding_board():
		_transport.leave_board()
		await _settle(20)
	_keepy.dismount_vehicle()
	await _idle_hopper()
	await _settle(6)
	_check(not _keepy.is_hopping(),
		"M the phase hands the world back AT REST (so PHASE T measures its own walk)")

## True when the container and viewport are real enough for
## `_handle_point` to project anything at all.
func _screen_is_real() -> bool:
	if _tap.container == null or _tap.viewport == null or _camera == null:
		return false
	var rect: Rect2 = _tap.container.get_global_rect()
	return rect.size.x > 0.0 and rect.size.y > 0.0 and _tap.viewport.size.x > 0

## ⚠️ THE CLAMP'S CONTRIBUTION, AND IT IS NAMED THAT RATHER THAN CALLED
## "the residual", because calling it the residual would be a metric that
## cannot fail. HubWorld compares the tap's DESTINATION -- which is
## clamped -- against `_drawn_ground_point`, which is NOT. Both are built
## from the same camera ray, so everything else cancels and what is left
## is exactly what `HubRegion.clamp_to` moved. It is zero wherever the
## drawn ground point is inside the region, and it is the ONE way the
## gesture can still break on a raised body: a module near a border would
## push the destination off the body it was aimed at.
##
## The END-TO-END residual -- what a real finger actually produces
## against what HubWorld actually compares it to -- cannot be computed;
## it has to be OBSERVED, and `_tap_self_screen` observes it.
func _clamp_shift() -> float:
	if _camera == null:
		return 1e9
	var eye: Vector3 = _camera.global_position
	var hit: Variant = HubSurface.intersect_ray(eye, (_keepy.global_position - eye).normalized())
	if hit == null:
		return 1e9
	return _flat(HubRegion.clamp_to(hit)).distance_to(_flat(hit))

## A tap on the PIXEL his body is drawn on, delivered where a finger
## delivers it. Returns whether the world put him down.
##
## The container-pixel maths is `HubTapInput._handle_point`'s own, run
## backwards: it maps a container point into viewport space by
## `(p - rect.position) * viewport.size / rect.size`, so a viewport point
## comes back out as `rect.position + p * rect.size / viewport.size`.
func _tap_self_screen() -> bool:
	_check(_transport.is_riding_board(), "INSTRUMENT: he IS aboard before the screen tap")
	var rect: Rect2 = _tap.container.get_global_rect()
	var vp: Vector2 = _camera.unproject_position(_keepy.global_position)
	var scale := Vector2(rect.size.x / float(_tap.viewport.size.x),
		rect.size.y / float(_tap.viewport.size.y))
	var screen: Vector2 = rect.position + vp * scale
	print("     screen tap at %s (container rect %s, viewport %s)"
		% [str(screen.round()), str(rect.size), str(_tap.viewport.size)])
	if not rect.has_point(screen):
		_check(false, "INSTRUMENT: his drawn body is OFF the container -- nothing to tap")
		return false
	_tap._handle_point(screen)
	await _settle(8)
	return not _transport.is_riding_board()

## HubWorld's `_drawn_ground_point`, recomputed here by the same rule, so
## the end-to-end residual above is measured against what the shipped
## branch actually compares a tap to.
func _drawn_ground_of(at: Vector3) -> Vector3:
	if _camera == null:
		return _flat(at)
	var eye: Vector3 = _camera.global_position
	var away: Vector3 = at - eye
	if away.length() < 0.0001:
		return _flat(at)
	var hit: Variant = HubSurface.intersect_ray(eye, away.normalized())
	return _flat(at) if hit == null else _flat(hit)

## Rides the board up a module until it can go no further, and reports the
## highest point it reached. The approach is the module's OWN local -Z for
## a quarterpipe (it arrives at the foot of the transition) and the funbox
## ride CH57 published; both are read off the node's transform so a yawed
## module needs no second spelling.
## ⚠️ CH61 -- ONE SPELLING OF THE STATIONS, READ BY BOTH RIDES.
##
## `_peak_gesture` first invented its own approach -- the module's own
## local -Z at 8 u out -- and for the funbox that is (0, 37.5), which
## sits inside the SEESAW's landing disc. `leave_board` steps the rider
## off with a hop, a hop that LANDS is offered to every hotspot HubWorld
## holds, the seesaw took him, and `mount_carrier` refused every mount
## afterwards because its one precondition is `_state == IDLE`. Two reds,
## on a bench, from a station typed twice.
##
## CLAUDE.md's rule about a fact having one spelling is usually about
## numbers in shipped code. It is about benches too.
func _high_point_ends(index: int) -> Array:
	var node := _park.module_node(index)
	var centre: Vector3 = _park.module_centre(index)
	var d: Vector3 = node.global_transform.basis * Vector3(0.0, 0.0, 1.0)
	var dir := Vector3(d.x, 0.0, d.z).normalized()
	var kind: StringName = _park.module_kind(index)
	var out_u: float = 6.5 if kind == HubSkatepark.KIND_FUNBOX else -8.0
	var to_u: float = -5.5 if kind == HubSkatepark.KIND_FUNBOX else 4.0
	return [centre + dir * out_u, centre + dir * to_u]

func _ride_to_high_point(index: int) -> Dictionary:
	var ends: Array = _high_point_ends(index)
	await _remount(ends[0])
	_tap.tapped_ground.emit(HubRegion.clamp_to(ends[1]))
	var body := _transport.board_body()
	var best: float = -1e9
	# ⚠️ CH61 -- THE PARALLAX IS READ AT THE PEAK, ON THE TICK OF THE PEAK.
	#
	# Before this lot the board STALLED on a transition and stayed there,
	# so where it came to rest and how high it got were the same place and
	# one reading served both. With inertia a quarterpipe behaves like a
	# quarterpipe: the board goes up, runs out of speed and comes back
	# down, and its RESTING height on a transition is zero. A phase that
	# went on reading the resting point would report `climbed = false` and
	# take the RAIL branch -- passing, on a module that had just been
	# ridden higher than anything in this park has ever been ridden. A
	# true reading of the wrong moment, which is CLAUDE.md's "la metrique
	# peut etre la mauvaise, et le chiffre vert avec".
	#
	# Both readings are transform arithmetic on the LIVE camera, so
	# nothing is reconstructed and nothing is teleported into place: they
	# are simply taken on the frame where the board is highest.
	var peak_parallax: float = -1.0
	var peak_shift: float = 1e9
	# ⚠️ AND "AT REST" IS HELD FOR A WHILE BEFORE IT IS BELIEVED.
	#
	# `at_rest()` is "no target and slower than the guard's own idea of
	# motionless", and a board at the APEX OF A CLIMB satisfies both for
	# an instant: it has turned round, so its speed passes through zero,
	# and the stall guard may already have let the target go. Measured on
	# this very bench -- the 2.10 u quarterpipe reported "came to rest at
	# y 0.987", which is a point on a 58 deg facet that nothing could
	# stand on. It was the apex, caught on the tick it turned.
	#
	# CH42's rule, again and in a third shape: a run is never scored on
	# an instant. A rest that is real survives twenty ticks of gravity.
	var still: int = 0
	for _i in 480:
		await get_tree().physics_frame
		if body.global_position.y > best:
			best = body.global_position.y
			peak_parallax = _deck_parallax()
			peak_shift = _clamp_shift()
		still = still + 1 if body.at_rest() else 0
		if still >= 20:
			break
	var lip: float = float(HubSkatepark.MODULES[index]["size"].y)
	return {"y": body.global_position.y, "peak": best, "lip": lip,
		"supported": body.supported(),
		"peak_parallax": peak_parallax, "peak_shift": peak_shift,
		# Did the module offer a place to STAND, or only a place to pass
		# through? A deck does; a transition does not, and the difference
		# is what decides which gesture is even askable up there.
		"rests_raised": body.global_position.y > 0.05,
		"climbed": best > 0.05}

## =====================================================================
## ⚠️ CH61 -- THE GESTURE AT A POINT THE RIDER CANNOT STAND ON
##
## The brief's garde-fou 3: "la descente doit rester possible A TOUTE
## VITESSE et depuis tout point atteint -- c'est le bug CH58, ne le
## rouvre pas." CH58's bug was a DEAD CHANNEL: a rider sealed inside a
## prop that ate every tap, CLAUDE.md's PATRON ECHELLE. The rule that
## fixed it is not "a self-tap always ejects" -- CH57 deliberately makes
## a self-tap mid-roll a STEER so a rider is not thrown off a moving
## board -- it is that every tap PRODUCES something and the rider is
## never more than one further tap from the ground.
##
## So that is what is asked here, at the highest point of a transition,
## through the real screen where the driver allows it:
##
##   1. the tap resolves to a ground point at all (the channel is alive
##      at speed, above the ground, mid-climb);
##   2. he is still aboard afterwards -- it STEERED, which is CH58's own
##      rule and not a regression of it;
##   3. the board comes to rest, and the NEXT self-tap puts him down.
##
## Three assertions, and the third is the one that would have caught the
## shipped CH57 bug: a swallowed tap never reaches it.
func _peak_gesture(index: int, live: bool) -> void:
	var ends: Array = _high_point_ends(index)
	await _remount(ends[0])
	var body := _transport.board_body()
	_tap.tapped_ground.emit(HubRegion.clamp_to(ends[1]))
	# Ride until the board has topped out: it has climbed past a real
	# height AND started coming down. Waiting for a fixed tick count
	# would tap wherever the clock happened to fall.
	var best: float = -1e9
	var topped: bool = false
	for _i in 480:
		await get_tree().physics_frame
		var y: float = body.global_position.y
		best = maxf(best, y)
		if best > 0.30 and y < best - 0.02:
			topped = true
			break
	print("     [%d] topped out at y %.3f, tapping his drawn body THERE (%s)"
		% [index, best, "screen" if live else "signal"])
	_check(topped, "M[%d] INSTRUMENT: the run really topped out on the transition (peak %.3f u)"
		% [index, best])
	if not topped:
		return
	var seen: Array[Vector3] = []
	var sink := func(p: Vector3) -> void: seen.append(p)
	_tap.tapped_ground.connect(sink)
	if live:
		await _tap_self_screen()
	else:
		_tap.tapped_ground.emit(HubRegion.clamp_to(_finger_at_keepy()))
		await _settle(8)
	_tap.tapped_ground.disconnect(sink)
	_check(seen.size() > 0,
		"M[%d] the channel is ALIVE at the peak: the tap produced a ground point" % index)
	_check(_transport.is_riding_board(),
		"M[%d] and it STEERED rather than ejecting him off a moving board (CH58's rule)" % index)
	# ...and the ground he comes back to is one tap from a dismount.
	var settled: bool = false
	for _i in 40:
		await _settle(12)
		if _transport.board_at_rest():
			settled = true
			break
	_check(settled, "M[%d] INSTRUMENT: the board came to rest after the steer" % index)
	if not settled:
		return
	_check(await _tap_self(),
		"M[%d] and the NEXT tap on himself puts him down -- never more than one tap from the ground"
			% index)

# =====================================================================
# PHASE T -- THE CEILING, RE-WALKED
#
# Garde-fou of the brief. The patch touches input and not movement, so the
# traversal cannot have moved -- and CLAUDE.md answers that a structural
# argument is still an argument until something measures it. The published
# diagonal is restated to the frame, with the physics world live, and
# priced against the 22.0 s ceiling.

func _phase_traversal() -> void:
	print("-- PHASE T: the published diagonal, re-walked with the physics world live --")
	if _transport.is_riding_board():
		_transport.leave_board()
		await _settle(30)
	_keepy.dismount_vehicle()
	await _settle(10)
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	_keepy.global_position = HubSurface.ground(Vector3(-h, 0.0, -h))
	_hops = 0
	_idle = false
	_keepy.hop_landed.connect(_on_landed)
	_keepy.became_idle.connect(_on_idle)
	_keepy.hop_to(Vector3(h, 0.0, h))
	var frames: int = 0
	while not _idle and frames < 6000:
		await get_tree().process_frame
		frames += 1
	_keepy.hop_landed.disconnect(_on_landed)
	_keepy.became_idle.disconnect(_on_idle)
	var seconds: float = float(frames) / FPS
	print("     diagonal: hops=%d frames=%d  %.3f s   (published %d / %.3f s, ceiling %.1f s)"
		% [_hops, frames, seconds, PUBLISHED_DIAGONAL_HOPS, PUBLISHED_DIAGONAL_S, TRAVERSE_CEILING_S])
	_check(_hops == PUBLISHED_DIAGONAL_HOPS, "the hop count is the published one")
	_check(absf(seconds - PUBLISHED_DIAGONAL_S) < 1.0 / FPS,
		"the crossing time is the published one, to the frame")
	_check(seconds < TRAVERSE_CEILING_S, "and it is under the 22.0 s ceiling")

func _on_landed(_p: Vector3) -> void:
	_hops += 1

func _on_idle() -> void:
	_idle = true

# =====================================================================
# PHASE O -- NO REGRESSION WITH THE SWITCH DOWN
#
# CH54's board is a hop modifier handed to KeepyHopper, and it is what
# every player has. The fix must not have touched it. A SECOND WORLD is
# built with the switch down rather than reasoned about, because a world
# half-believing in colliders is exactly what DevTools caches against --
# and the first world is freed first, so no two hubs are ever alive at
# once (SkatePhysicsProbe's own discipline).

func _phase_off() -> void:
	print("-- PHASE O: the shipped game (PHYS off) is untouched --")
	if _hub != null:
		_hub.queue_free()
		_hub = null
	for _i in 12:
		await get_tree().process_frame
	DevTools.set_physics_override(false)
	var off: Node = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(off)
	for _i in 24:
		await get_tree().process_frame
	var keepy := off.find_child("Keepy", true, false) as KeepyHopper
	var transport := off.find_child("Transport", true, false) as HubTransport
	var tap := off.find_child("TapInput", true, false) as HubTapInput
	if keepy == null or transport == null or tap == null:
		_check(false, "INSTRUMENT: the switch-down hub built")
		DevTools.set_physics_override(true)
		return
	_check(transport.board_body() == null, "with the switch down the board is NOT a physics body")
	_check(not transport.is_riding_board(), "and nothing reports a physics ride")
	keepy.dismount_vehicle()
	keepy.global_position = HubSurface.ground(transport.board_position())
	for _i in 8:
		await get_tree().process_frame
	var mounted: bool = keepy.mount_vehicle(transport.board_node(), HubTransport.SKATE_LIFT,
		HubTransport.SKATE_GLIDE_STEP, HubTransport.SKATE_GLIDE_S,
		HubTransport.SKATE_ACCEL_U, HubTransport.SKATE_BRAKE_U)
	for _i in 8:
		await get_tree().process_frame
	_check(mounted, "CH54's mount still takes him aboard (the hopper's own vehicle path)")
	_check(keepy.is_on_vehicle(), "and he is ON_VEHICLE, not ON_CARRIER -- a different door entirely")
	_check(not keepy.is_on_carrier(), "so the branch this lot reordered is not even reached")
	# The shipped dismount: a tap on himself standing still, through the
	# same real signal. This is the path every player has today.
	tap.tapped_ground.emit(HubRegion.clamp_to(_flat(keepy.global_position)))
	for _i in 8:
		await get_tree().process_frame
	_check(not keepy.is_on_vehicle(), "and the CH54 tap-to-dismount still works, unchanged")
	off.queue_free()
	for _i in 10:
		await get_tree().process_frame
	DevTools.set_physics_override(true)

# =====================================================================
# HELPERS

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)

func _settle(ticks: int) -> void:
	for _i in ticks:
		await get_tree().physics_frame

## Puts the board down flat at `flat`, nobody on it and no target -- and
## waits until the hopper is genuinely IDLE.
##
## ⚠️ THE WAIT IS NOT TIDINESS. `mount_carrier` refuses from any state but
## IDLE, so a walk still running from the phase above makes `mount_board()`
## return false, and every "he is not aboard" assertion downstream then
## passes for free. Measured on the first red pass: three phases were
## scored against a rider who had never got on.
## ⚠️ CH61 -- AND THE DISMOUNT HAPPENS ON OPEN LAWN, NOT WHERE THE RIDE
## ENDED.
##
## `leave_board` steps the rider off BESIDE the board with a hop, and a
## hop that LANDS is offered to every hotspot HubWorld holds. Before this
## lot the board stopped short of a module and every ride ended in the
## same few metres; with inertia it rides OVER the funbox and stops at
## (0, 40), which is inside the SEESAW's landing disc. Measured: the
## seesaw took the rider, `mount_carrier` refused every mount afterwards
## (its one precondition is `_state == IDLE`), and the phase scored a
## board nobody was riding -- `topped out at y 0.000`.
##
## Nothing is wrong with the game: a walk that lands beside the seesaw is
## SUPPOSED to be offered it. What was wrong is a bench that put its
## rider down inside another prop's hotspot. `OPEN_GROUND` is this
## probe's own published empty station, so the fix reads what is already
## there rather than inventing a second one.
func _park_board(flat: Vector3) -> void:
	if _transport.is_riding_board():
		var carrier := _transport.board_body()
		if carrier != null:
			carrier.stop()
			carrier.velocity = Vector3.ZERO
			carrier.global_position = HubSurface.ground(_flat(OPEN_GROUND))
			_keepy.call("follow_carrier")
			await _settle(1)
		_transport.leave_board()
		await _settle(20)
	_keepy.dismount_vehicle()
	await _idle_hopper()
	var body := _transport.board_body()
	if body != null:
		body.stop()
		body.velocity = Vector3.ZERO
		body.global_position = HubSurface.ground(_flat(flat))
	_keepy.global_position = HubSurface.ground(_flat(flat))
	await _settle(8)

## Parks the board at `flat` and puts him on it, GATING that the mount
## actually took -- for the reason written on `_tap_self` above.
func _remount(flat: Vector3) -> void:
	await _park_board(flat)
	var took: bool = _transport.mount_board()
	await _settle(6)
	_check(took and _transport.is_riding_board(),
		"INSTRUMENT: the mount took (else every check in this case is free)")

## Waits, bounded, until the hopper is standing still. Bounded because an
## unbounded wait on a flag is how a probe turns a defect into a timeout.
func _idle_hopper() -> void:
	for _i in 900:
		if not _keepy.is_hopping():
			return
		await get_tree().physics_frame
	push_error("SkateDismountProbe: the hopper never came to rest.")

## A tap on Keepy himself, delivered through the real signal exactly as a
## finger on his own feet would arrive. Returns whether he ended up OFF
## the board -- the world's answer, never the call's.
##
## ⚠️ IT GATES ITS OWN PRECONDITION, and the first version of this probe
## did not. "not is_riding_board()" is an assertion of ABSENCE, and
## CLAUDE.md is explicit that those pass for free: a run where the mount
## silently FAILED reported "a tap on himself dismounted him" three times
## over, green, against a rider who had never been aboard. The red pass
## found it in the probe rather than in the game, which is what a red pass
## is for. The state is HELD, so it is re-asserted here rather than
## assumed from the phase above.
func _tap_self() -> bool:
	_check(_transport.is_riding_board(), "INSTRUMENT: he IS aboard before the self-tap")
	_tap.tapped_ground.emit(HubRegion.clamp_to(_finger_at_keepy()))
	await _settle(6)
	return not _transport.is_riding_board()

## ⚠️ WHERE A FINGER AIMED AT HIS DRAWN BODY ACTUALLY LANDS -- and this is
## NOT his flat position.
##
## The first green pass of this probe tapped `_flat(global_position)`, and
## it went green on the funbox deck while PRINTING, two lines above, that
## the parallax there is 1.501 u against a 0.90 u radius. That is
## CLAUDE.md's "la metrique peut etre la mauvaise, et le chiffre vert
## avec", in the same shape as the bed hotspot: the bench was asking a
## question no finger can ask.
##
## A player taps what he SEES. HubCamera never rises, every tap resolves
## on HubSurface, so a body standing above the ground plane is DRAWN where
## the ground under it is not, and the gap grows with height. This is the
## point the router would hand HubWorld for a finger on his feet, and it
## is what every self-tap below is now made of.
func _finger_at_keepy() -> Vector3:
	var d: float = _deck_parallax()
	if d < 0.0:
		return _flat(_keepy.global_position)
	var eye: Vector3 = _camera.global_position
	var hit: Variant = HubSurface.intersect_ray(eye, (_keepy.global_position - eye).normalized())
	return _flat(hit)

## A station due east of the funbox, on its own z, so a westward roll meets
## the deck box's vertical face and no ramp at all -- SkatePhysicsProbe's
## own lateral leg, restated from the module rather than retyped.
func _side_of_funbox() -> Vector3:
	var centre: Vector3 = _park.module_centre(0)
	var half_x: float = float(HubSkatepark.MODULES[0]["size"].x) * 0.5
	return Vector3(centre.x + half_x + 2.5, 0.0, centre.z)

## Rides the board up onto the funbox deck. The approach is
## SkatePhysicsProbe's -- due south down the module's own centre line -- so
## the two benches agree on what "onto the module" means.
func _ride_onto_deck() -> Dictionary:
	var centre: Vector3 = _park.module_centre(0)
	await _remount(Vector3(centre.x, 0.0, centre.z + 12.0))
	var body := _transport.board_body()
	_tap.tapped_ground.emit(HubRegion.clamp_to(_flat(centre)))
	for _i in 420:
		await get_tree().physics_frame
		if body.at_rest() and body.supported():
			break
	var deck_h: float = float(HubSkatepark.MODULES[0]["size"].y)
	return {
		"on_deck": body.supported() and body.global_position.y > deck_h - 0.10,
		"y": body.global_position.y,
		"deck_h": deck_h,
		"supported": body.supported(),
	}

## ⚠️ WHAT A TAP AIMED AT HIS DRAWN FEET ACTUALLY RESOLVES TO, when he is
## standing above the ground plane.
##
## HubCamera never rises (OFFSET is a constant and it tracks his GROUND
## point), and every tap resolves on HubSurface. So a body lifted by h is
## DRAWN somewhere the ground under it is not: the camera ray through his
## real position meets the surface further away, and the gap grows with h.
## It is pure transform arithmetic -- no pixel, no viewport -- so it holds
## under any driver, which is the only reason this number can be gated
## from a headless run.
##
## Returns -1.0 when there is no camera to read, so a missing camera is a
## visible skip rather than a zero that reads like a good result.
func _deck_parallax() -> float:
	if _camera == null:
		return -1.0
	var eye: Vector3 = _camera.global_position
	var at: Vector3 = _keepy.global_position
	var dir: Vector3 = (at - eye)
	if dir.length() < 0.0001:
		return -1.0
	var hit: Variant = HubSurface.intersect_ray(eye, dir.normalized())
	if hit == null:
		return -1.0
	return _flat(hit).distance_to(_flat(at))
