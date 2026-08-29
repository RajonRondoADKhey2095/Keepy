extends Node
## Gates the multi-level navigation core against the SHIPPED test scene.
##
## GATED, not reported, because every failure mode of this system is
## SILENT. A link whose withdrawal never engages re-triggers a crossing
## already running; a level whose plane is not the one taps resolve
## against walks a body through the floor; an aim read off a clamped
## destination turns a whole half-plane of non-existent ground into "go
## upstairs". None of them raises, none of them breaks a build, and every
## one of them looks like the screen simply misbehaving.
##
## ⚠️ IT DRIVES scenes/dev/LevelNavTest.tscn, NEVER A FIXTURE OF ITS OWN.
## A stand-in built to resemble the shipped world is free to diverge from
## it on exactly the axis under test -- the trap this repository paid for
## with SubstituteModel.tscn.
##
## ⚠️ RUN IT UNDER xvfb, NOT --headless. PHASE AIM projects world points to
## screen and feeds them back through the real dispatch path; under the
## DUMMY driver the container's rect is 0x0, resolve() returns a miss, and
## every one of those checks would pass by never running. The rect is
## ASSERTED non-degenerate so the probe fails loudly instead.
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --path . \
##       res://scripts/dev/LevelNavProbe.tscn

const TEST_SCENE: String = "res://scenes/dev/LevelNavTest.tscn"

var _failures: int = 0
var _checks: int = 0
var _world: LevelNavTestWorld = null
var _controller: LevelController = null
var _walker: LevelWalker = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "LEVEL NAV PROBE")
	# DEFERRED, and measured rather than styled: adding the world during
	# this _ready() gets "Parent node is busy setting up children" from the
	# root, the world's own _ready() never runs, and every level table is
	# empty -- which reads exactly like a broken world rather than a probe
	# calling too early.
	_run.call_deferred()

func _ok(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  OK   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)

func _run() -> void:
	print("=== LEVEL NAV PROBE ===")
	var packed: PackedScene = load(TEST_SCENE)
	if packed == null:
		print("  FAIL the test scene does not load")
		_finish(1)
		return
	_world = packed.instantiate() as LevelNavTestWorld
	get_tree().root.add_child(_world)
	await get_tree().process_frame
	await get_tree().process_frame
	_controller = _world.get_node("LevelController") as LevelController
	_walker = _world.get_node("WorldViewport/SubViewport/World/Walker") as LevelWalker
	_ok(_controller != null, "the controller resolves")
	_ok(_walker != null, "the walker resolves")
	if _controller == null or _walker == null:
		_finish(1)
		return

	_phase_levels()
	await _phase_walk()
	await _phase_cross()
	await _phase_gate()
	await _phase_aim()

	print("--- %d checks, %d failure(s) ---" % [_checks, _failures])
	_finish(1 if _failures > 0 else 0)

func _finish(code: int) -> void:
	if _world != null:
		_world.queue_free()
	await get_tree().process_frame
	get_tree().quit(code)

## =====================================================================
## PHASE LEVELS -- a level is a plane with its OWN bounds
func _phase_levels() -> void:
	print("--- PHASE LEVELS ---")
	var lower := _controller.level_at(0)
	var upper := _controller.level_at(1)
	_ok(lower != null and upper != null, "the world has two levels")
	if lower == null or upper == null:
		return
	_ok(not is_equal_approx(lower.plane_y, upper.plane_y),
		"the two floors are at different heights (%.3f vs %.3f)" % [lower.plane_y, upper.plane_y])
	_ok(not is_equal_approx(lower.half_extent, upper.half_extent),
		"bounds are PER LEVEL, not one global scalar (%.1f vs %.1f)"
			% [lower.half_extent, upper.half_extent])
	# flat() REPLACES Y rather than discarding it -- the one real
	# difference from HubRegion._flat(), and the thing that lets two
	# levels answer differently about the same XZ.
	var probe_point := Vector3(1.0, 123.0, 2.0)
	_ok(is_equal_approx(lower.flat(probe_point).y, lower.plane_y),
		"lower.flat() states the point at ITS floor, not at zero")
	_ok(is_equal_approx(upper.flat(probe_point).y, upper.plane_y),
		"upper.flat() states the point at ITS floor (%.3f)" % upper.flat(probe_point).y)
	_ok(not is_equal_approx(lower.flat(probe_point).y, upper.flat(probe_point).y),
		"the same XZ reads at two different heights on the two levels")
	# The plane a tap resolves against is the level's, not a hard-coded
	# Plane(UP, 0) -- the single line that makes the hub single-storey.
	_ok(is_equal_approx(upper.plane().d, upper.plane_y),
		"upper.plane() is at the upper floor, not at zero")
	# Bounds, clamped on each level independently.
	var far := Vector3(1000.0, 0.0, 1000.0)
	var clamped_lower := lower.clamp_to(far)
	var clamped_upper := upper.clamp_to(far)
	_ok(lower.contains(clamped_lower), "a far tap clamps INTO the lower level")
	_ok(upper.contains(clamped_upper), "a far tap clamps INTO the upper level")
	_ok(is_equal_approx(clamped_lower.y, lower.plane_y)
			and is_equal_approx(clamped_upper.y, upper.plane_y),
		"each clamp lands on its OWN floor")
	_ok(not lower.contains(far), "a far point is outside the lower level")
	# A point inside the upper square is NOT inside the lower one here,
	# because the two squares are offset -- so "which level" is a real
	# question the controller answers, not something contains() guesses.
	_ok(is_equal_approx(_controller.ground_y(), lower.plane_y),
		"ground_y() reports the CURRENT level's floor")

## =====================================================================
## PHASE WALK -- ordinary navigation ON each level, at its own height
func _phase_walk() -> void:
	print("--- PHASE WALK ---")
	var lower := _controller.level_at(0)
	_walker.global_position = Vector3(0.0, lower.plane_y, 4.0)
	var destination := lower.clamp_to(Vector3(3.0, 0.0, 1.0))
	_walker.hop_to(destination)
	var heights: Array[float] = []
	var frames := await _settle(heights)
	_ok(frames > 0 and frames < 600, "he walked on the lower level (%d frames)" % frames)
	_ok(_walker.global_position.distance_to(destination) <= LevelWalker.ARRIVE_EPSILON,
		"he arrived (%.3f u from the destination)" % _walker.global_position.distance_to(destination))
	_ok(is_equal_approx(_walker.global_position.y, lower.plane_y),
		"he came to rest ON the lower floor (y = %.4f)" % _walker.global_position.y)
	# The arc leaves the floor and comes back to it -- a walk that never
	# left the ground would satisfy every height check above trivially.
	var peak: float = -INF
	for h in heights:
		peak = maxf(peak, h)
	_ok(peak > lower.plane_y + 0.2,
		"the hop actually arced (peak %.3f above a floor at %.3f)" % [peak, lower.plane_y])
	var lowest: float = INF
	for h in heights:
		lowest = minf(lowest, h)
	_ok(lowest >= lower.plane_y - 0.001,
		"and never dipped below the floor (lowest %.4f)" % lowest)

## =====================================================================
## PHASE CROSS -- both directions, and the height that proves it
func _phase_cross() -> void:
	print("--- PHASE CROSS ---")
	var link := _controller.links[0]
	var lower := _controller.level_at(0)
	var upper := _controller.level_at(1)

	# UP.
	_controller.set_current(0)
	_walker.global_position = Vector3(0.0, lower.plane_y, 3.0)
	_walker.request_transition(link)
	var heights: Array[float] = []
	var frames := await _settle(heights)
	_ok(frames > 0 and frames < 900, "he walked to the foot and crossed up (%d frames)" % frames)
	_ok(_controller.current_index() == 1,
		"the CURRENT LEVEL is now the upper one (index %d)" % _controller.current_index())
	_ok(is_equal_approx(_walker.global_position.y, upper.plane_y),
		"and his feet are on the upper floor (y = %.4f)" % _walker.global_position.y)
	_ok(is_equal_approx(_controller.ground_y(), upper.plane_y),
		"ground_y() followed the level up")
	_ok(link.is_available(), "the link is available again once the crossing ended")

	# He can WALK up there -- which is the whole difference between a level
	# and the turnstile/seesaw/owl seats this pattern was NOT copied from.
	var destination := upper.clamp_to(Vector3(2.0, 0.0, upper.centre_z + 2.0))
	_walker.hop_to(destination)
	var up_heights: Array[float] = []
	var up_frames := await _settle(up_heights)
	_ok(up_frames > 0, "he walks on the upper level too (%d frames)" % up_frames)
	_ok(is_equal_approx(_walker.global_position.y, upper.plane_y),
		"and stays on the upper floor while doing it (y = %.4f)" % _walker.global_position.y)
	var up_lowest: float = INF
	for h in up_heights:
		up_lowest = minf(up_lowest, h)
	_ok(up_lowest >= upper.plane_y - 0.001,
		"a hop up there never dips to the lower floor (lowest %.4f)" % up_lowest)

	# A tap aimed far away up here clamps against the UPPER half-extent.
	#
	# ⚠️ NOT stated as "and the lower level does not contain it": contains()
	# is XZ-only BY CONTRACT (which level Keepy is on is the controller's
	# question, not a level's), and the upper square sits entirely inside
	# the lower one's footprint, so the lower level contains that XZ and is
	# right to. Asserting otherwise was a probe defect, and it is the
	# BOUND that carries the meaning here.
	var far := Vector3(500.0, 0.0, 500.0)
	var far_up := upper.clamp_to(far)
	var far_down := lower.clamp_to(far)
	_ok(upper.contains(far_up), "a far tap up here clamps INTO the upper level")
	_ok(is_equal_approx(far_up.x, upper.centre_x + upper.half_extent),
		"and it stopped at the UPPER half-extent (%.3f)" % far_up.x)
	_ok(not is_equal_approx(far_up.x, far_down.x),
		"which is NOT where the lower level would have stopped it (%.3f vs %.3f)"
			% [far_up.x, far_down.x])

	# DOWN.
	_walker.request_transition(link)
	var down_heights: Array[float] = []
	var down_frames := await _settle(down_heights)
	_ok(down_frames > 0 and down_frames < 900, "he crossed back down (%d frames)" % down_frames)
	_ok(_controller.current_index() == 0,
		"the current level is the lower one again (index %d)" % _controller.current_index())
	_ok(is_equal_approx(_walker.global_position.y, lower.plane_y),
		"and his feet are back on the lower floor (y = %.4f)" % _walker.global_position.y)

## =====================================================================
## PHASE GATE -- the BOAT's withdrawal, and the LADDER's absence of one
func _phase_gate() -> void:
	print("--- PHASE GATE ---")
	var link := _controller.links[0]
	var lower := _controller.level_at(0)
	_controller.set_current(0)
	_walker.global_position = link.entry_for(0)
	await get_tree().process_frame

	# BLIND CHECK first: prove a crossing CAN be started from here, so
	# "it refused" below is a refusal and not a crossing that was never
	# possible in the first place.
	_ok(link.is_available(), "before: the link is available")
	_ok(link.accepts_tap(link.entry_for(0), 0),
		"before: an aim on the entry is accepted")
	_walker.begin_crossing(link)
	_ok(_walker.is_crossing(), "BLIND CHECK: a crossing did start")

	# DURING the crossing: the boat's active withdrawal.
	_ok(not link.is_available(),
		"DURING: the link has WITHDRAWN (the boat's pattern, not the ladder's)")
	_ok(not link.accepts_tap(link.entry_for(0), 0),
		"DURING: an aim on the entry is REFUSED, so the tap falls through")
	var level_mid := _controller.current_index()
	_walker.request_transition(link)
	_ok(_walker.is_crossing(),
		"DURING: a second request did NOT re-trigger -- still one crossing")
	_ok(_controller.current_index() == level_mid,
		"DURING: and did not move the level under it")
	# ⚠️ AND IT WAS REFUSED, NOT QUEUED. Found by the red-before-green
	# pass: with both re-trigger guards removed, the check above stayed
	# green -- request_transition only calls _advance() from IDLE, so a
	# second request during a crossing could not start one immediately
	# either way. What it COULD do is latch a pending link that fires on
	# the next landing, which is a re-trigger one frame later. This is the
	# assertion that tells the two apart.
	_ok(not _walker.has_pending_transition(),
		"DURING: the second request was REFUSED outright, not latched for later")
	# A ground tap during a crossing reaches the ground path and is simply
	# refused there. It is never SWALLOWED -- that is the difference the
	# ladder pattern gets wrong, and the reason a player inside a prop
	# still has a way to say something.
	var before_target := _walker.global_position
	_walker.hop_to(lower.clamp_to(Vector3(6.0, 0.0, 6.0)))
	_ok(_walker.is_crossing(),
		"DURING: a ground tap did not start a walk out of the crossing")
	_ok(_walker.global_position.distance_to(before_target) < 0.6,
		"DURING: and did not teleport him")

	var heights: Array[float] = []
	var frames := await _settle(heights)
	_ok(frames > 0, "the crossing finished on its own (%d frames)" % frames)
	_ok(link.is_available(), "AFTER: the withdrawal is released")
	_ok(_controller.current_index() == 1, "AFTER: exactly one crossing happened")

## =====================================================================
## PHASE AIM -- the lot-1 rule, on N levels
##
## The link's lower foot stands ON the lower level's own edge (z = -9), so
## the whole half-plane of non-existent ground behind it clamps onto it.
## That is the exact geometry that made the hub's cabin swallow taps aimed
## from 49.8 u off the map. If aim and destination were one variable here,
## these checks are what would catch it.
func _phase_aim() -> void:
	print("--- PHASE AIM ---")
	var link := _controller.links[0]
	var lower := _controller.level_at(0)
	_controller.set_current(0)
	_walker.global_position = Vector3(0.0, lower.plane_y, -7.0)
	await get_tree().process_frame

	# The funnel, stated directly: a point well past the edge clamps to a
	# destination that IS inside the link's radius.
	var beyond := Vector3(0.0, 0.0, -40.0)
	var clamped := lower.clamp_to(beyond)
	var flat_clamped := Vector3(clamped.x, 0.0, clamped.z)
	var flat_entry := Vector3(link.point_a.x, 0.0, link.point_a.z)
	_ok(flat_clamped.distance_to(flat_entry) <= link.tap_radius,
		"the clamped destination of an off-map tap IS inside the link (%.3f <= %.3f)"
			% [flat_clamped.distance_to(flat_entry), link.tap_radius])
	# ...and the AIM is not, so the meaning is not the transition.
	_ok(not link.accepts_tap(lower.flat(beyond), 0),
		"but the AIM is not, so the tap does NOT mean 'cross' -- the lot-1 rule")
	# SWEPT, and the measurement is the point: how far off the map can an
	# aim be and still mean "cross"?
	#
	# ⚠️ THE ANSWER IS NOT "not at all", and a first version of this check
	# asserted that it was and failed on correct code. An aim 1 u past the
	# edge is 1 u from a foot with a 1.6 u radius: it is a player tapping
	# AT the door from just outside it, and refusing that would be a
	# different bug. What the lot-1 rule buys is that the accepted set is
	# bounded by the RADIUS instead of being unbounded by the clamp.
	var deepest: float = link.point_a.z
	var accepted_far := 0
	for step in 800:
		var z: float = -9.0 - float(step) * 0.1
		var aim := lower.flat(Vector3(0.0, 0.0, z))
		if link.accepts_tap(aim, 0):
			deepest = minf(deepest, z)
		elif z > -11.0:
			pass
		if z <= -11.0 and link.accepts_tap(aim, 0):
			accepted_far += 1
	var expected_edge: float = link.point_a.z - link.tap_radius
	_ok(absf(deepest - expected_edge) <= 0.11,
		"the deepest off-map aim that means 'cross' is %.2f -- the RADIUS bound (%.2f), not the map"
			% [deepest, expected_edge])
	_ok(accepted_far == 0,
		"0 of 690 aims swept from 11 u to 88 u out read as a crossing")
	# The positive half: an aim actually ON the foot still means cross.
	_ok(link.accepts_tap(lower.flat(Vector3(0.0, 0.0, -8.8)), 0),
		"an aim ON the foot still means cross (the check is not vacuous)")
	# A link is asked only about the level Keepy is standing on.
	_ok(not link.accepts_tap(lower.flat(Vector3(0.0, 0.0, -9.0)), 7),
		"a link refuses a level it does not serve")

	# THE REAL DISPATCH PATH, through screen projection. This is what
	# proves the wiring rather than the arithmetic.
	var container := _world.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	_ok(rect.size.x > 1.0 and rect.size.y > 1.0,
		"the viewport rect is real (%.0fx%.0f) -- under --headless it is 0x0 and every check below would pass by never running"
			% [rect.size.x, rect.size.y])
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	await get_tree().process_frame

	var camera := _world.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	var viewport := _world.get_node("WorldViewport/SubViewport") as SubViewport
	# BLIND CHECK: a screen point aimed at the foot must dispatch as a
	# transition, or the two refusals after it mean nothing.
	var on_foot := _screen_for(camera, container, viewport, link.point_a)
	var got: Array = _dispatch_once(on_foot)
	_ok(got.size() == 1 and got[0] == "transition",
		"BLIND CHECK: a real tap on the foot dispatches as a TRANSITION (got %s)" % str(got))
	# And a real tap aimed past the edge dispatches as GROUND, even though
	# its clamped destination lands on the foot.
	var past_edge := _screen_for(camera, container, viewport, Vector3(0.0, lower.plane_y, -22.0))
	var got_far: Array = _dispatch_once(past_edge)
	_ok(got_far.size() == 1 and got_far[0] == "ground",
		"a real tap aimed 22 u out -- past a 9 u edge -- dispatches as GROUND (got %s)" % str(got_far))
	# Exactly one signal per tap, either way.
	_ok(got.size() == 1 and got_far.size() == 1,
		"exactly ONE signal fired per tap in both cases")

## Projects a world point to a screen point in the OUTER window's space,
## inverting the same rect scaling dispatch() applies.
func _screen_for(camera: Camera3D, container: SubViewportContainer,
		viewport: SubViewport, world: Vector3) -> Vector2:
	var inside := camera.unproject_position(world)
	var rect := container.get_global_rect()
	var outer := Vector2(
		inside.x * rect.size.x / float(viewport.size.x),
		inside.y * rect.size.y / float(viewport.size.y))
	return outer + rect.position

## Dispatches one tap and returns which signals fired, in order.
func _dispatch_once(screen_point: Vector2) -> Array:
	var fired: Array = []
	var on_ground := func(_d: Vector3) -> void: fired.append("ground")
	var on_link := func(_l: LevelTransition, _d: Vector3) -> void: fired.append("transition")
	_controller.tapped_ground.connect(on_ground)
	_controller.tapped_transition.connect(on_link)
	_controller.dispatch(screen_point)
	_controller.tapped_ground.disconnect(on_ground)
	_controller.tapped_transition.disconnect(on_link)
	return fired

## Runs frames until the walker is idle, collecting his height each frame.
## Returns the frame count, or 0 if he never moved.
func _settle(heights: Array[float]) -> int:
	var frames := 0
	while frames < 1200:
		await get_tree().process_frame
		frames += 1
		heights.append(_walker.global_position.y)
		if _walker.state() == LevelWalker.State.IDLE \
				and not _walker.is_crossing() \
				and not _walker.has_pending_transition():
			# One settle frame, so a state that flips back to HOPPING in
			# _advance() is not read as arrival.
			await get_tree().process_frame
			frames += 1
			if _walker.state() == LevelWalker.State.IDLE:
				return frames
	return frames
