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
	print("--- PHASE B: the board as it was BUILT ---")
	var board: Dictionary = props.diving_board()
	_check(not board.is_empty(), "the layout builds exactly one diving board")
	if board.is_empty():
		print("")
		return

	var ladder: Vector3 = board["ladder"]
	var anchor: Vector3 = board["anchor"]
	var forward: Vector3 = board["forward"]
	var water: Vector3 = board["water_target"]
	var land: Vector3 = board["land_target"]

	# The great lake's near lobe, from the region that OWNS it. Restating
	# a centre and a radius here is how a board slowly stops being on the
	# water it was planted on.
	var lobe: Dictionary = HubRegion.lakes()[0]
	var centre: Vector3 = lobe["centre"]
	var radius: float = lobe["radius"]
	var d_ladder: float = Vector3(ladder.x, 0.0, ladder.z).distance_to(centre)
	var d_anchor: float = Vector3(anchor.x, 0.0, anchor.z).distance_to(centre)
	var d_water: float = Vector3(water.x, 0.0, water.z).distance_to(centre)
	print("    lobe centre %s radius %.2f" % [centre, radius])
	print("    ladder %.3f from centre | anchor %.3f | water target %.3f" % [d_ladder, d_anchor, d_water])

	_check(d_ladder > radius, "the ladder foot stands on LAND (%.3f > %.3f)" % [d_ladder, radius])
	_check(HubRegion.contains(ladder), "the ladder foot is WALKABLE, so a tap can actually reach it")
	_check(d_anchor < radius, "the deck anchor is out over WATER (%.3f < %.3f)" % [d_anchor, radius])
	_check(d_water < radius, "the dive lands in WATER (%.3f < %.3f)" % [d_water, radius])
	_check(land.is_equal_approx(ladder),
		"the landward dive lands on the ladder foot -- ground already stood on, so it cannot be inside a prop")
	_check(anchor.y > 0.0, "the deck is above the ground (%.3f u)" % anchor.y)
	_check(is_equal_approx(forward.length(), 1.0), "the facing is a unit vector")

	# The facing is the ladder-to-anchor line and not some third direction.
	var implied: Vector3 = (Vector3(anchor.x, 0.0, anchor.z) - Vector3(ladder.x, 0.0, ladder.z)).normalized()
	_check(forward.dot(implied) > 0.999,
		"the facing agrees with the board's own two ends (dot %.6f)" % forward.dot(implied))

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
	_check(worst > 0.0, "the ladder foot is clear of every other prop footprint")
	print("")

## PHASE C -- the three states, driven through a whole climb and dive on the
## shipped hopper.
##
## Every check here is on a transition that fails SILENTLY if it is wrong:
## a climb that never reaches ON_BOARD leaves a player stuck on a ladder, a
## dive that never leaves ON_BOARD leaves them stuck on a plank, and
## neither raises anything.
func _phase_c_states(keepy: KeepyHopper, props: HubBuilder) -> void:
	print("--- PHASE C: climb, stand, dive ---")
	var board: Dictionary = props.diving_board()
	if board.is_empty():
		_check(false, "no board to climb")
		print("")
		return

	var ladder: Vector3 = board["ladder"]
	var anchor: Vector3 = board["anchor"]

	keepy.global_position = ladder
	_check(not keepy.is_on_board(), "standing at the foot, the board does not own him yet")

	keepy.climb_board(board)
	_check(keepy.is_on_board(), "climb_board takes the body")
	_check(not keepy.is_standing_on_board(), "mid-climb is not standing on the deck")

	# A tap during a climb must be DROPPED, not queued: an interruptible
	# climb would walk Keepy out of a ladder halfway up it.
	# Sampled after the tween has had frames to run -- the first version
	# read it on the same frame climb_board was called and reported 0.000,
	# which looked like a climb that never left the ground.
	keepy.hop_to(Vector3(20.0, 0.0, 20.0))
	await _wait(KeepyHopper.CLIMB_DURATION * 0.5)
	var mid_climb_y: float = keepy.global_position.y
	_check(mid_climb_y > 0.0 and mid_climb_y < anchor.y,
		"mid-climb he is genuinely PART WAY up the ladder (%.3f of %.3f)" % [mid_climb_y, anchor.y])
	_check(keepy.is_on_board() and not keepy.is_standing_on_board(),
		"a tap during the climb was DROPPED, not queued -- he is still climbing")
	await _wait(KeepyHopper.CLIMB_DURATION * 0.5 + 0.25)
	_check(keepy.is_standing_on_board(), "the climb finishes ON the deck")
	_check(keepy.global_position.is_equal_approx(anchor),
		"and lands exactly on the anchor (%s)" % keepy.global_position)
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
	print("")

## PHASE D -- no portal is reachable from the board.
##
## The board sits on the near lobe and the portal row is metres away, so
## this should never be close. It is gated anyway because the failure is
## the worst one this feature has: being carried into a sub-game from the
## top of a ladder, which no amount of looking at the screen would predict.
func _phase_d_portals(hub: Node, keepy: KeepyHopper, props: HubBuilder) -> void:
	print("--- PHASE D: nothing routes while the board owns the body ---")
	var board: Dictionary = props.diving_board()
	if board.is_empty():
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
	keepy.global_position = board["ladder"]
	keepy.climb_board(board)
	await _wait(0.05)

	# The landing hook, called by hand with a PORTAL CENTRE while the board
	# owns the body. If the guard is missing this opens the dialog.
	var portals: Array = props.portals()
	_check(portals.size() > 0, "there are portals to be wrongly triggered")
	for portal in portals:
		hub.call("_on_hop_landed", portal.global_position)
	_check(not confirm.call("is_open"),
		"a landing on a portal CENTRE mid-climb opens nothing (%d portals tried)" % portals.size())

	await _wait(KeepyHopper.CLIMB_DURATION + 0.25)
	for portal in portals:
		hub.call("_on_hop_landed", portal.global_position)
	_check(not confirm.call("is_open"), "nor while standing on the deck")

	# The counter MOVES once he is back on the ground -- without this the
	# two zeroes above would pass on a dialog that simply never opens.
	keepy.dive(Vector3(board["anchor"].x, 0.0, board["anchor"].z) - board["forward"] * 6.0)
	await _wait(KeepyHopper.DIVE_DURATION + 0.3)
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
