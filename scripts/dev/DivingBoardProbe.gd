extends Node

## Gates the diving board: the generalised hop arc, the board's geometry,
## and the three states a dive passes through.
##
## =====================================================================
## WHY EACH PHASE IS GATED AND NOT MERELY REPORTED
##
## PHASE A is the one this batch could not ship without. Generalising
## _apply_hop touches EVERY hop on the plateau -- the walk to a portal, the
## boarding walk, the eject off the boat -- and the failure mode of getting
## it slightly wrong is a trajectory that is a hair off everywhere and
## obviously wrong nowhere. So the shipped function is sampled against the
## formula it replaced, and the WORST divergence over the whole hop is
## printed whether it passes or not: a tolerance that is never shown is a
## tolerance nobody can tell has started to be used up.
##
## The state phases exist because every way the board can break is SILENT.
## A dive that never leaves ON_BOARD is a player stuck on a plank with no
## error anywhere; a climb that does not suppress portal detection carries
## someone into a sub-game they were standing above; a board whose ladder
## base is not walkable is a prop nobody can ever reach. None of those
## raise, none fail a build, and all of them look like "the board was never
## finished" on a device.

const _HUB_WORLD_SCENE := "res://scenes/HubWorld.tscn"

## Samples across one hop for the arc comparison. Well past the 200 the
## batch asked for: the two formulas are compared at no cost, and a denser
## sweep is the difference between "they agree" and "they agree where I
## happened to look".
const ARC_SAMPLES: int = 1000

## Worst per-sample divergence allowed between the generalised arc and the
## formula it replaced, in world units, at equal endpoints.
const ARC_TOLERANCE: float = 0.000001

var _failures: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "DIVING BOARD PROBE")
	var dl := ProbeWatchdog.deadline("DIVING BOARD PROBE")

	print("=== DIVING BOARD PROBE ===")
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = hub.get_node("WorldViewport/SubViewport/World") as Node3D
	var keepy: KeepyHopper = world.get_node("Keepy") as KeepyHopper

	var props: HubBuilder = world.get_node("Props") as HubBuilder

	_phase_a_arc(keepy)
	dl.abort_if_exceeded()
	_phase_b_geometry(props)
	dl.abort_if_exceeded()
	await _phase_c_states(keepy, props)
	dl.abort_if_exceeded()
	await _phase_d_portals(hub, keepy, props)
	dl.abort_if_exceeded()
	_phase_e_cost(world)

	print("")
	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("  OK    %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s" % label)

## PHASE A -- the generalised arc is EXACTLY the old one on a flat hop.
##
## The reference is computed here, in the shape the file carried before
## this batch: ground.lerp, then `_hop_height * 4t(1-t)` used AS the y
## rather than added to a base line. The shipped _apply_hop is then driven
## over the same t and its resulting global_position compared to it.
##
## Driving the real function matters more than it looks. A reimplementation
## of the new formula compared against a reimplementation of the old one
## would prove the two paragraphs agree, which was never in doubt -- what
## is in doubt is whether the file does what the paragraph says.
func _phase_a_arc(keepy: KeepyHopper) -> void:
	print("--- PHASE A: the generalised arc against the formula it replaced ---")

	# Three hops that between them cover every flat case the plateau can
	# produce: a full-length one, a short final one, and the taller eject.
	var cases: Array = [
		{"label": "full hop", "from": Vector3(2.0, 0.0, -3.0), "to": Vector3(3.5, 0.0, -3.0), "h": KeepyHopper.HOP_HEIGHT},
		{"label": "short final hop", "from": Vector3(-8.0, 0.0, 4.0), "to": Vector3(-7.5, 0.0, 4.4), "h": KeepyHopper.HOP_HEIGHT},
		{"label": "eject hop", "from": Vector3(0.0, 0.0, 0.0), "to": Vector3(1.2, 0.0, 0.9), "h": KeepyHopper.EJECT_HOP_HEIGHT},
	]

	var worst_overall: float = 0.0
	for case in cases:
		var from: Vector3 = case["from"]
		var to: Vector3 = case["to"]
		var height: float = case["h"]
		keepy.set("_hop_from", from)
		keepy.set("_hop_to", to)
		keepy.set("_hop_height", height)
		keepy.set("_hop_from_y", 0.0)
		keepy.set("_hop_to_y", 0.0)

		var worst: float = 0.0
		var worst_t: float = 0.0
		for i in ARC_SAMPLES + 1:
			var t: float = float(i) / float(ARC_SAMPLES)
			# The pre-change formula, verbatim.
			var ground: Vector3 = from.lerp(to, t)
			var old_y: float = height * 4.0 * t * (1.0 - t)
			var expected := Vector3(ground.x, old_y, ground.z)

			keepy.call("_apply_hop", t)
			var got: Vector3 = keepy.global_position
			var d: float = (got - expected).length()
			if d > worst:
				worst = d
				worst_t = t
		worst_overall = maxf(worst_overall, worst)
		print("    %-16s worst divergence %.12f u over %d samples (at t = %.3f)"
			% [case["label"], worst, ARC_SAMPLES + 1, worst_t])

	_check(worst_overall <= ARC_TOLERANCE,
		"a flat hop is IDENTICAL to the pre-change trajectory (worst %.12f u, tolerance %.6f)"
			% [worst_overall, ARC_TOLERANCE])

	# The endpoints are not merely close at t = 0 and t = 1 -- they are the
	# endpoints. A hop that ends a rounding error above the ground is the
	# defect the 4t(1-t) form was chosen to make impossible, and the
	# generalisation must not have quietly reintroduced it.
	keepy.set("_hop_from", Vector3(1.0, 0.0, 2.0))
	keepy.set("_hop_to", Vector3(2.5, 0.0, 2.0))
	keepy.set("_hop_height", KeepyHopper.HOP_HEIGHT)
	keepy.set("_hop_from_y", 0.0)
	keepy.set("_hop_to_y", 0.0)
	keepy.call("_apply_hop", 0.0)
	var start_y: float = keepy.global_position.y
	keepy.call("_apply_hop", 1.0)
	var end_y: float = keepy.global_position.y
	_check(start_y == 0.0 and end_y == 0.0,
		"a flat hop starts and ends at EXACTLY y = 0 (%.12f, %.12f)" % [start_y, end_y])

	# And the generalisation does what it was added for: unequal endpoints
	# put the two ends on their own heights, with the arc on top.
	keepy.set("_hop_from_y", 1.8)
	keepy.set("_hop_to_y", 0.0)
	keepy.call("_apply_hop", 0.0)
	var high_start: float = keepy.global_position.y
	keepy.call("_apply_hop", 1.0)
	var low_end: float = keepy.global_position.y
	keepy.call("_apply_hop", 0.5)
	var mid: float = keepy.global_position.y
	print("    sloped arc      start %.4f  mid %.4f  end %.4f" % [high_start, mid, low_end])
	_check(is_equal_approx(high_start, 1.8) and is_equal_approx(low_end, 0.0),
		"a sloped hop starts on the board and ends on the water surface")
	_check(mid > 1.8 * 0.5,
		"the sloped arc still ARCS -- its midpoint clears the straight line between the ends")
	print("")

## PHASE B -- the board exists, is authored where it says, and its two ends
## are on the right side of the waterline.
##
## Read off the BUILT board rather than off the layout: the whole point of
## publishing it from the build pass is that the plank drawn and the point
## a climber is planted on are the same fact, and a probe that re-read the
## resource would pass on the day those two diverge.
func _phase_b_geometry(props: HubBuilder) -> void:
	print("--- PHASE B: every board as it was BUILT ---")
	var boards: Array[Dictionary] = props.diving_boards()
	_check(boards.size() == 3, "the layout builds three diving boards (built %d)" % boards.size())
	for i in boards.size():
		_phase_b_one(props, boards[i], i)
	# Two planks sharing a ladder foot would each be reachable and only one
	# climbable, which is the singleton defect wearing a different hat.
	for i in boards.size():
		for j in range(i + 1, boards.size()):
			var gap: float = (boards[i]["ladder"] as Vector3).distance_to(boards[j]["ladder"] as Vector3)
			_check(gap > 2.0 * 2.5,
				"boards %d and %d are further apart than one tap radius could span (%.3f u)" % [i, j, gap])
	print("")

## One board, measured against WHICHEVER body of water it dives into --
## resolved from the target rather than pinned to the great lake's near
## lobe, which is all this phase could speak for while there was one board.
func _phase_b_one(props: HubBuilder, board: Dictionary, index: int) -> void:
	var ladder: Vector3 = board["ladder"]
	var anchor: Vector3 = board["anchor"]
	var forward: Vector3 = board["forward"]
	var water: Vector3 = board["water_target"]
	var land: Vector3 = board["land_target"]

	# WHICH water, asked of the water rather than assumed. Every body is
	# taken from the owner that publishes it -- HubRegion for the great
	# lake's two lobes, HubBuilder for the pond and the small lake --
	# because restating a centre and a radius here is how a board slowly
	# stops being on the water it was planted on.
	var bodies: Array[Dictionary] = []
	for lobe in HubRegion.lakes():
		bodies.append({"name": "great-lake lobe", "centre": lobe["centre"], "radius": lobe["radius"]})
	if props.small_lake_centre() != Vector3.INF:
		bodies.append({"name": "small lake", "centre": props.small_lake_centre(),
			"radius": HubBuilder.SMALL_LAKE_WATER_RADIUS})
	if props.pond_centre() != Vector3.INF:
		bodies.append({"name": "pond", "centre": props.pond_centre(),
			"radius": HubBuilder.POND_WATER_RADIUS})

	var flat_water := Vector3(water.x, 0.0, water.z)
	var body: Dictionary = {}
	for candidate in bodies:
		if flat_water.distance_to(candidate["centre"] as Vector3) < float(candidate["radius"]):
			body = candidate
			break
	print("  [board %d]" % index)
	_check(not body.is_empty(), "board %d dives into a body of water this hub actually has" % index)
	if body.is_empty():
		return
	var centre: Vector3 = body["centre"]
	var radius: float = body["radius"]
	print("    dives into the %s" % body["name"])
	var d_ladder: float = Vector3(ladder.x, 0.0, ladder.z).distance_to(centre)
	var d_anchor: float = Vector3(anchor.x, 0.0, anchor.z).distance_to(centre)
	var d_water: float = Vector3(water.x, 0.0, water.z).distance_to(centre)
	print("    lobe centre %s radius %.2f" % [centre, radius])
	print("    ladder %.3f from centre | anchor %.3f | water target %.3f" % [d_ladder, d_anchor, d_water])

	_check(d_ladder > radius, "board %d: the ladder foot stands on LAND (%.3f > %.3f)" % [index, d_ladder, radius])
	_check(HubRegion.contains(ladder), "board %d: the ladder foot is WALKABLE, so a tap can actually reach it" % index)
	_check(d_anchor < radius, "board %d: the deck anchor is out over WATER (%.3f < %.3f)" % [index, d_anchor, radius])
	_check(d_water < radius, "board %d: the dive lands in WATER (%.3f < %.3f)" % [index, d_water, radius])
	_check(land.is_equal_approx(ladder),
		"board %d: the landward dive lands on the ladder foot -- ground already stood on, so it cannot be inside a prop" % index)
	_check(anchor.y > 0.0, "board %d: the deck is above the ground (%.3f u)" % [index, anchor.y])
	_check(is_equal_approx(forward.length(), 1.0), "board %d: the facing is a unit vector" % index)

	# The facing is the ladder-to-anchor line and not some third direction.
	var implied: Vector3 = (Vector3(anchor.x, 0.0, anchor.z) - Vector3(ladder.x, 0.0, ladder.z)).normalized()
	_check(forward.dot(implied) > 0.999,
		"board %d: the facing agrees with its own two ends (dot %.6f)" % [index, forward.dot(implied)])

	# The board must not have been planted on top of something. Measured
	# against the same footprints a disembark clears.
	var worst: float = 1000.0
	for foot in props.ground_footprints():
		var where: Vector3 = foot["position"]
		var r: float = foot["radius"]
		if where.is_equal_approx(Vector3(ladder.x, 0.0, ladder.z)):
			continue
		worst = minf(worst, Vector3(ladder.x, 0.0, ladder.z).distance_to(where) - r)
	print("    nearest other prop footprint: %.3f u from the ladder foot" % worst)
	_check(worst > 0.0, "board %d: the ladder foot is clear of every other prop footprint" % index)

	# THE RUNG COUNT, gated per board rather than assumed shared. It is a
	# pure function of deck height, so three boards at 1.8 must agree --
	# but that height reaches the builder as float32, and the ratio it
	# feeds lands on round()'s .5 knife-edge at exactly this height. Which
	# way an unguarded round() fell used to be decided by float32 noise, so
	# "they are all 1.8, therefore they all match" is the assumption that
	# fix exists to stop anyone making. Measured per instance instead.
	var rung_heights: Array = board["rung_heights"]
	print("    %d rungs at %s" % [rung_heights.size(), rung_heights])
	_check(rung_heights.size() == 5,
		"board %d: the 1.8 u deck derives 5 rungs (got %d)" % [index, rung_heights.size()])

## PHASE C -- the three states, driven through a whole climb and dive on the
## shipped hopper.
##
## Every check here is on a transition that fails SILENTLY if it is wrong:
## a climb that never reaches ON_BOARD leaves a player stuck on a ladder, a
## dive that never leaves ON_BOARD leaves them stuck on a plank, and
## neither raises anything.
func _phase_c_states(keepy: KeepyHopper, props: HubBuilder) -> void:
	print("--- PHASE C: climb, stand, dive ---")
	var boards: Array[Dictionary] = props.diving_boards()
	if boards.is_empty():
		_check(false, "no board to climb")
		print("")
		return
	# EVERY board, not just the first. The states are shared code, so the
	# second and third can only fail on their own GEOMETRY -- which is
	# exactly the half this batch added, and exactly the half a single-board
	# run would never touch.
	for i in boards.size():
		print("  [board %d]" % i)
		# AWAITED. _phase_c_one contains awaits, so it is a coroutine, and
		# calling it bare would start all three at once on ONE body -- the
		# three climbs then interleave and two of them measure a Keepy the
		# third is driving. Seen, not guessed: the bare form failed 12
		# checks whose printed positions were board 0's.
		await _phase_c_one(keepy, boards[i])
	print("")

func _phase_c_one(keepy: KeepyHopper, board: Dictionary) -> void:
	var ladder: Vector3 = board["ladder"]
	var anchor: Vector3 = board["anchor"]

	keepy.global_position = ladder
	_check(not keepy.is_on_board(), "standing at the foot, the board does not own him yet")

	keepy.climb_board(board)
	_check(keepy.is_on_board(), "climb_board takes the body")
	_check(not keepy.is_standing_on_board(), "mid-climb is not standing on the deck")

	# A tap during a climb must be DROPPED, not queued: an interruptible
	# climb would walk Keepy out of a ladder halfway up it. THREE taps are
	# thrown at three DIFFERENT sub-phases of the 27 aout 2026 quantized
	# rise -- during an early push, during a later pause, and during the
	# final mount hop -- because a state cut into sub-steps is exactly how
	# a "tap does nothing while climbing" rule quietly grows an exception
	# for one of the steps and not the others. Sampled after the tween has
	# had frames to run -- the first version read it on the same frame
	# climb_board was called and reported 0.000, which looked like a climb
	# that never left the ground.
	keepy.hop_to(Vector3(20.0, 0.0, 20.0))
	await _wait(KeepyHopper.CLIMB_DURATION * 0.5)
	var mid_climb_y: float = keepy.global_position.y
	_check(mid_climb_y > 0.0 and mid_climb_y < anchor.y,
		"mid-climb he is genuinely PART WAY up the ladder (%.3f of %.3f)" % [mid_climb_y, anchor.y])
	_check(keepy.is_on_board() and not keepy.is_standing_on_board(),
		"a tap during the climb was DROPPED, not queued -- he is still climbing")
	# The LOW-LEVEL half of the same claim: not just "the state looks
	# unchanged" but "the tap left no trace at all" -- _has_target reading
	# false is what proves nothing was queued to fire later, once the body
	# is handed back to the ordinary chain by a dive. Read by the same
	# reflection PHASE A already uses on this file's private fields.
	_check(not bool(keepy.get("_has_target")),
		"and it left no target QUEUED either (_has_target reads false)")

	# SECOND tap, a different destination again, landing somewhere in a
	# later traction's push-or-pause than the first one did.
	keepy.hop_to(Vector3(-30.0, 0.0, 10.0))
	await _wait(0.25)
	_check(keepy.is_on_board() and not keepy.is_standing_on_board(),
		"a SECOND tap, at a different point in the quantized rise, is also dropped")
	_check(not bool(keepy.get("_has_target")), "no target queued from it either")

	# THIRD tap, timed to land inside the mount hop -- CLIMB_RISE_FRACTION
	# of CLIMB_DURATION is 0.612 s; the two waits above total 0.675 s, so
	# this one lands past that boundary, in the segment _apply_climb hands
	# to _apply_hop rather than the quantized-rung branch above it.
	keepy.hop_to(Vector3(40.0, 0.0, -5.0))
	_check(keepy.is_on_board() and not keepy.is_standing_on_board(),
		"a THIRD tap, during the mount hop itself, is dropped too")
	_check(not bool(keepy.get("_has_target")),
		"and STILL no target queued -- the mount hop is not a hole in the guard")

	await _wait(KeepyHopper.CLIMB_DURATION - 0.675 + 0.25)
	_check(keepy.is_standing_on_board(), "the climb finishes ON the deck")
	_check(keepy.global_position.is_equal_approx(anchor),
		"and lands exactly on the anchor despite three taps along the way (%s)" % keepy.global_position)
	print("    mid-climb height %.3f -> deck %.3f" % [mid_climb_y, keepy.global_position.y])

	# A dive AWAY from the water goes back down the ladder.
	var behind: Vector3 = Vector3(anchor.x, 0.0, anchor.z) - board["forward"] * 6.0
	keepy.dive(behind)
	_check(not keepy.is_standing_on_board(), "a landward tap leaves the deck")
	await _wait(KeepyHopper.DIVE_DURATION + 0.3)
	_check(not keepy.is_on_board(), "and the board hands the body back")
	_check(Vector3(keepy.global_position.x, 0.0, keepy.global_position.z)
			.distance_to(board["land_target"]) < 0.01,
		"the landward dive lands at the ladder foot (%s)" % keepy.global_position)
	_check(is_zero_approx(keepy.global_position.y),
		"and lands at ground level, not on a rounding error (%.6f)" % keepy.global_position.y)

	# And a dive TOWARDS the water goes in.
	keepy.global_position = ladder
	keepy.climb_board(board)
	await _wait(KeepyHopper.CLIMB_DURATION + 0.25)
	var ahead: Vector3 = Vector3(anchor.x, 0.0, anchor.z) + board["forward"] * 6.0
	var apex: float = -1.0
	keepy.dive(ahead)
	# Sampled mid-flight: the arc has to clear the deck it left, which is
	# the whole reason the dive gets its own height rather than the hop's.
	await _wait(KeepyHopper.DIVE_DURATION * 0.35)
	apex = keepy.global_position.y
	await _wait(KeepyHopper.DIVE_DURATION)
	_check(Vector3(keepy.global_position.x, 0.0, keepy.global_position.z)
			.distance_to(board["water_target"]) < 0.01,
		"the water dive lands on the water target (%s)" % keepy.global_position)
	_check(is_zero_approx(keepy.global_position.y), "and on the surface, at y = 0")
	print("    dive apex sampled at %.3f u against a deck at %.3f u" % [apex, anchor.y])
	_check(apex > anchor.y, "the dive ARCS above the deck it left rather than sliding off it")
	_check(not keepy.is_on_board() and not keepy.is_riding(),
		"the body is back on the plateau's own state machine")

## PHASE D -- no portal is reachable from the board.
##
## The board sits on the near lobe and the portal row is metres away, so
## this should never be close. It is gated anyway because the failure is
## the worst one this feature has: being carried into a sub-game from the
## top of a ladder, which no amount of looking at the screen would predict.
func _phase_d_portals(hub: Node, keepy: KeepyHopper, props: HubBuilder) -> void:
	print("--- PHASE D: nothing routes while the board owns the body ---")
	var boards: Array[Dictionary] = props.diving_boards()
	if boards.is_empty():
		_check(false, "no board")
		print("")
		return

	# get_node_or_null and a CHECK, not get_node: the first version of this
	# phase used the wrong path, crashed on a null, and the probe still
	# printed "0 failure(s)" and exited 0. A phase that cannot run has to
	# be a FAILURE, not a silence -- that green was worth less than no
	# phase at all.
	var confirm: Node = hub.get_node_or_null("ConfirmDialog")
	_check(confirm != null, "the confirm dialog is where this phase looks for it")
	if confirm == null:
		print("")
		return
	var portals: Array = props.portals()
	_check(portals.size() > 0, "there are portals to be wrongly triggered")

	# EVERY board. "No portal from up here" is a fact about WHERE a board
	# stands, and the two added this batch stand somewhere else -- the one
	# nearest the portal row is not necessarily the one that was measured.
	for i in boards.size():
		var board: Dictionary = boards[i]
		keepy.global_position = board["ladder"]
		keepy.climb_board(board)
		await _wait(0.05)

		# The landing hook, called by hand with a PORTAL CENTRE while the
		# board owns the body. If the guard is missing this opens the dialog.
		for portal in portals:
			hub.call("_on_hop_landed", portal.global_position)
		_check(not confirm.call("is_open"),
			"board %d: a landing on a portal CENTRE mid-climb opens nothing (%d portals tried)" % [i, portals.size()])

		await _wait(KeepyHopper.CLIMB_DURATION + 0.25)
		for portal in portals:
			hub.call("_on_hop_landed", portal.global_position)
		_check(not confirm.call("is_open"), "board %d: nor while standing on the deck" % i)

		# Off the plank and back onto the plateau's own state machine
		# before the next board is climbed.
		keepy.dive(Vector3(board["anchor"].x, 0.0, board["anchor"].z) - board["forward"] * 6.0)
		await _wait(KeepyHopper.DIVE_DURATION + 0.3)

	# The counter MOVES once he is back on the ground -- without this the
	# zeroes above would pass on a dialog that simply never opens. LAST,
	# and outside the loop: it leaves the dialog OPEN, which would poison
	# every "opens nothing" check that ran after it.
	hub.call("_on_hop_landed", portals[0].global_position)
	_check(confirm.call("is_open"),
		"BLIND CHECK: the same call DOES open the dialog once he is off the board")
	print("")

## PHASE E -- what the board costs in draw nodes.
func _phase_e_cost(world: Node3D) -> void:
	print("--- PHASE E: cost ---")
	var props: Node = world.get_node("Props")
	var meshes: int = 0
	var multis: int = 0
	for child in props.get_children():
		meshes += _count_meshes(child)
		multis += _count_multis(child)
	print("    MeshInstance3D under Props: %d" % meshes)
	print("    MultiMeshInstance3D:        %d" % multis)
	print("    draw nodes, total:          %d" % (meshes + multis))

	# What the BOARD costs of that, itemised. A total that moved by the
	# right amount for the wrong reason is the failure this itemisation
	# exists to catch.
	var board_meshes: int = 0
	var rungs: int = 0
	for child in props.get_children():
		if child.name == "DivingBoard":
			board_meshes = _count_meshes(child)
		elif child is MultiMeshInstance3D and String(child.name).begins_with("DivingBoard"):
			rungs = (child as MultiMeshInstance3D).multimesh.instance_count
	print("    of which the board: %d mesh nodes + 1 rung batch of %d instances"
		% [board_meshes, rungs])
	_check(board_meshes == 7,
		"the board is 7 mesh nodes (plank, 4 posts, 2 rails), not more (%d)" % board_meshes)
	_check(rungs >= 2, "the ladder has a rung run (%d rungs, ONE draw node)" % rungs)
	_check(meshes + multis < 260, "under the 260 draw-node ceiling")
	print("")

func _count_meshes(node: Node) -> int:
	var n: int = 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		n += _count_meshes(child)
	return n

func _count_multis(node: Node) -> int:
	var n: int = 1 if node is MultiMeshInstance3D else 0
	for child in node.get_children():
		n += _count_multis(child)
	return n

## Waits WALL-CLOCK, not frames: the tweens these phases drive run on
## engine time, and a frame count means a different duration under llvmpipe
## than it does anywhere else.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
