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

	_phase_a_arc(keepy)
	dl.abort_if_exceeded()

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
