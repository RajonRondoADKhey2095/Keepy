extends Node
## Dev-only: a reference measurement of the hub plateau (scenes/HubWorld.tscn)
## taken BEFORE any Meshy asset is installed on it, so a future asset install
## has something to be compared against instead of a guess.
##
## =====================================================================
## WHAT THIS FILE IS NOT
##
## It asserts nothing and never fails on purpose (see the exit code note at
## the bottom). Every other file in this folder is a CONTRACT -- a fixed
## number a future change must not cross. This one is a MEASUREMENT: there
## is no "right" frame time or node count for a hub that has not shipped a
## single .glb yet, only a number worth writing down so the NEXT one can be
## read against it. docs/HUB_PERF_BASELINE.md is where that comparison
## lives; this probe is only how the numbers in it are produced.
##
## PERMANENT, not throwaway, and that is the point: a reference measurement
## that cannot be re-run identically later is not a reference, it is a
## anecdote from one session. It lives here for the same reason every other
## probe does -- excluded from the exported build by export_presets.cfg's
## exclude_filter on scripts/dev/*, so being permanent costs the shipped
## game nothing.
##
## =====================================================================
## WHY WALL-CLOCK, NOT --fixed-fps's REPORTED DELTA
##
## `--fixed-fps 60` (used elsewhere in this folder to make simulated time
## run predictably) overrides the delta the engine REPORTS to a fixed
## 1/60s -- it does not slow the engine down to match real time, and it
## does not reflect how long a frame actually took to build and draw. A
## probe that measured "FPS" from that reported delta would always read
## exactly 60, on any machine, doing any amount of work: a number that
## looks like a measurement and is actually a constant.
##
## This file times frames on Time.get_ticks_usec() instead -- real elapsed
## wall-clock between two `await get_tree().process_frame` yields -- with
## --fixed-fps 60 still passed on the command line only so a future run
## uses the exact same engine flags this one did, for a comparison that
## is not confounded by an unstated difference in how the process loop is
## driven.
##
## =====================================================================
## THE LIMIT THIS FILE CANNOT MEASURE AROUND
##
## This sandbox has no GPU: it renders through llvmpipe (software) under
## xvfb. That is not a rounding error against a phone, it is a different
## renderer -- absolute FPS here says nothing about a device. What DOES
## carry across renderers is DIRECTION: if a future asset add makes this
## probe's frame time worse on the exact same software renderer, that is
## real signal a device test would only confirm, not discover. Read
## docs/HUB_PERF_BASELINE.md's own warning before trusting any number
## printed here as an absolute.
const _WARMUP_FRAMES: int = 30
const _SAMPLE_FRAMES: int = 180

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

func _ready() -> void:
	# Armed first, before anything that could itself hang -- see
	# ProbeWatchdog.gd. This probe iterates across frames rather than
	# blocking inside one call, so arm() (not deadline()) is the right
	# mechanism.
	ProbeWatchdog.arm(self, "HUB PERF BASELINE")
	print("=== HUB PERF BASELINE ===")
	print("reference measurement, not a contract -- see docs/HUB_PERF_BASELINE.md")
	print("")

	var t_before := Time.get_ticks_usec()
	var hub := (preload(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	var t_after := Time.get_ticks_usec()
	var construction_ms: float = (t_after - t_before) / 1000.0

	# One frame so every @onready var and every _ready() cascade in the
	# subtree (HubBuilder's MultiMesh flush included) has actually run
	# before anything below reads the tree it built.
	await get_tree().process_frame

	var builder: Node = hub.get_node_or_null("WorldViewport/SubViewport/World/Props")
	var counts := _count_draw_nodes(builder)
	print("-- construction --")
	print("  instantiate() + full _ready() cascade: %.2f ms" % construction_ms)
	print("")
	print("-- draw nodes (Props subtree, live tree, not the layout file) --")
	print("  individual MeshInstance3D built by HubBuilder : %d" % counts["individual"])
	print("  MultiMeshInstance3D batches                   : %d" % counts["multimesh"])
	print("  MeshInstance3D owned by the 3 HubPortal scenes : %d" % counts["portal_owned"])
	print("  draw nodes, HubBuilder only (excl. portals)    : %d" % counts["draw_nodes_excl_portal"])
	print("  draw nodes, total (HubBuilder + portals)       : %d" % counts["draw_nodes_total"])
	print("")

	# The camera's own follow lerp is cut before sampling: it is a
	# deterministic, cheap recompute every frame regardless of what is on
	# screen, and freezing it is the same precaution earlier hub batches
	# took for spatial measurements -- here it keeps frame-time noise from
	# a moving target out of a number meant to isolate SCENE cost.
	var camera: Node = hub.get_node_or_null("WorldViewport/SubViewport/World/Camera3D")
	if camera != null:
		camera.set_process(false)

	print("-- simulated FPS, %d frames after a %d-frame warm-up --" % [_SAMPLE_FRAMES, _WARMUP_FRAMES])
	print("  method: real wall-clock between process_frame yields, NOT --fixed-fps's")
	print("  reported delta (see this file's header) -- run under xvfb + opengl3,")
	print("  --fixed-fps 60 on the command line for flag parity with future runs only.")

	for _i in _WARMUP_FRAMES:
		await get_tree().process_frame

	var deltas_us: Array[int] = []
	var last_us := Time.get_ticks_usec()
	for _i in _SAMPLE_FRAMES:
		await get_tree().process_frame
		var now_us := Time.get_ticks_usec()
		deltas_us.append(now_us - last_us)
		last_us = now_us

	var sum_us: int = 0
	var worst_us: int = 0
	for d in deltas_us:
		sum_us += d
		worst_us = maxi(worst_us, d)
	var mean_us: float = float(sum_us) / deltas_us.size()
	var mean_fps: float = 1_000_000.0 / mean_us
	# The frame with the LARGEST wall-clock delta is the frame the engine
	# spent longest on -- that is the MINIMUM instantaneous FPS across the
	# sample, not the mean's floor.
	var min_fps: float = 1_000_000.0 / worst_us

	print("  mean: %.1f fps (%.3f ms/frame)" % [mean_fps, mean_us / 1000.0])
	print("  min : %.1f fps (%.3f ms/frame, worst single frame in the sample)" % [min_fps, worst_us / 1000.0])
	print("")
	print("HUB_PERF_BASELINE_DONE=yes")
	# Not a contract, so there is nothing to fail on: exit 0 always. A
	# probe that could go red here would be asserting a threshold this
	# file explicitly says it does not have an opinion on.
	get_tree().quit(0)

## Recursively counts MeshInstance3D under `node`, INCLUDING `node` itself.
## ⚠️ COUNTS MultiMeshInstance3D TOO, and that is a fix rather than a
## flourish. This used to count MeshInstance3D only, which was complete for
## as long as every batch in the hub was a DIRECT child of HubBuilder --
## the caller below handles those in its own branch, so nothing was being
## missed. The turnstile broke that: its grip bars are a MultiMesh of its
## OWN, parented under its pivot, because a shared batch cannot rotate.
## A nested batch was therefore invisible here, and this probe reported 123
## against TurnstileProbe's and WaterTintProbe's 124 -- one draw node the
## budget could not see, which is precisely the kind of undercount a budget
## exists to prevent.
##
## No historical number moves: before that prop there was no nested batch
## anywhere on the plateau, so every earlier tree counts the same either way
## -- measured on the pre-turnstile tree with this version, 120 / 126,
## exactly what the old one reported.
##
## Direct-child batches still cannot be double-counted: the caller reaches
## them through its own `elif` and never hands one to this function.
func _count_mesh_instances(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		count += 1
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count

## Splits Props' direct children into HubBuilder's own scatter/landmark/
## stump/pond nodes, its MultiMeshInstance3D batches, and the mesh nodes
## that live inside the three HubPortal instances -- mirroring the exact
## split CLAUDE.md's hub lots have measured this budget by ("draw nodes,
## HubBuilder only" vs. "total, HubBuilder + portals"), so this probe's
## numbers land in the same columns a human reading that history expects.
func _count_draw_nodes(builder: Node) -> Dictionary:
	var individual := 0
	var multimesh := 0
	var portal_owned := 0
	if builder != null:
		for child in builder.get_children():
			if child is MultiMeshInstance3D:
				multimesh += 1
			elif child is HubPortal:
				portal_owned += _count_mesh_instances(child)
			else:
				individual += _count_mesh_instances(child)
	return {
		"individual": individual,
		"multimesh": multimesh,
		"portal_owned": portal_owned,
		"draw_nodes_excl_portal": individual + multimesh,
		"draw_nodes_total": individual + multimesh + portal_owned,
	}
