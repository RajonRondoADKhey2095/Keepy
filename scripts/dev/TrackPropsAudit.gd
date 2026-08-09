extends Node
## Dev-only probe for the TRACKSIDE PROPS batch, and for the frame
## triangle budget those props are spent against.
##
## =====================================================================
## WHY BOTH THINGS LIVE IN ONE PROBE
##
## docs/MESHY_SPEC.md section 7 states a 50,000-triangle frame target and
## backs it with a table of per-asset costs. That table was written before
## the hibou and the squirrel were installed and before the decor batch
## (hills, curbs, ground tint) existed, so by the time trackside props
## were proposed its "~32,200 total" was a number nobody could still
## stand behind -- it described a game that no longer shipped.
##
## The fix for a stale number is not a fresher guess, it is a measurement
## that can be re-run. PHASE 1 below counts what the real game actually
## draws, off the real instantiated scenes, and is meant to be re-run by
## the next batch that adds geometry rather than read as another table to
## trust. That is why the budget census sits in the props probe: the
## props are what made the stale figure a problem, and re-measuring is
## half of what "did the props fit" even means.
##
## =====================================================================
## WHAT IT CHECKS
##
##   PHASE 1, THE BUDGET -- every MeshInstance3D in a LIVE run, counted
##     per frame for its triangles, and tracked at its worst frame rather
##     than sampled once. A single sample would catch whatever the pooled
##     objects happened to be showing at that instant, which is not the
##     number a budget is about. Reported as a per-family breakdown plus
##     the peak, against section 7's 50,000 target.
##
##     It ASSERTS the props' own share (PROPS_TRIANGLE_BUDGET) and only
##     REPORTS the frame total, which is a deliberate split rather than a
##     softened check. The re-measurement found the frame already over
##     target on code this batch does not touch -- collectibles drawing
##     ~4,000 triangles each where section 7 budgeted 300, and a pursuer
##     .glb at nearly twice its cap. Failing this probe on that would
##     attach a pre-existing defect to whichever branch happened to
##     measure it first, and the usual outcome of a probe that is red for
##     reasons unrelated to the change under review is that it stops being
##     read. So the props are held to a number they can actually breach,
##     the frame total is printed as a named finding with its own
##     contributors, and the final verdict line repeats the finding so
##     that "PASSED" can never be mistaken for "the budget is fine".
##
##   PHASE 2, THE KEEP-OUT -- the one visual invariant that IS load
##     bearing. The ground slab is Hitboxes.GROUND_SIZE.x wide and
##     everything inside it is the readable play area; a prop overlapping
##     it would put scenery on top of the lane a player is reading a
##     hazard in. Rolled over many populate() calls (each one re-rolls
##     presence, kind, size and position) and measured off the real mesh
##     AABBs via TrackSegment.nearest_prop_edge_x().
##
##   PHASE 3, NO COLLIDER -- props are MeshInstance3D children of a
##     StaticBody3D, i.e. they live INSIDE a physics body. Asserted
##     rather than reasoned about: the segment's shape count and the
##     slab's own dimensions must be identical with props built, and no
##     CollisionShape3D may exist anywhere under the segment beyond the
##     one the slab has always had.
##
## Phases 2 and 3 are what this probe verifies about the props. That they
## do not change the GAME is a separate question, and this probe is the
## wrong instrument for it -- it is answered by the six gated bot probes
## returning byte-identical output at seed 20260806, which is a stronger
## statement than anything assertable from here.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/TrackPropsAudit.tscn

const TRACK_SEGMENT_SCENE := preload("res://scenes/TrackSegment.tscn")

## Section 7's frame target, restated here so the probe reports a verdict
## rather than a number the reader has to go and compare by hand.
const TRIANGLE_TARGET: int = 50000

## Ceiling on what the trackside props alone may contribute to the worst
## frame. This is the budget number this probe ENFORCES, because it is the
## one this batch controls -- see the class doc's note on why the
## whole-frame total is reported as a finding rather than asserted.
##
## Sized about 3x the measured peak: loose enough that raising
## _PROP_SLOTS_PER_SIDE or _PROP_PRESENCE_CHANCE is a tuning decision
## rather than a probe failure, tight enough to catch the mistake that
## actually happens here -- a primitive left at Godot's default
## tessellation, which is ~4,000 triangles for a single boulder and would
## breach this on the first rock drawn.
const PROPS_TRIANGLE_BUDGET: int = 1500

## Simulated seconds of real play to sample the budget over. Long enough
## to cross several difficulty stages (GameState.STAGE_START_S runs to
## 45s), so hazard density reaches its late-game shape rather than the
## deliberately sparse opening.
const BUDGET_SAMPLE_S: float = 60.0

## populate() calls to roll the keep-out against. Each one re-rolls every
## prop slot on both sides, so this is roughly 4x that many placements.
const KEEPOUT_ROLLS: int = 4000

var _game: Node3D = null
var _sampled_s: float = 0.0
var _peak_triangles: int = 0
var _peak_instances: int = 0
var _peak_families: Dictionary = {}
var _frames: int = 0
var _failures: int = 0
## Triangles the worst frame ran over section 7's target, or 0 when it did
## not. Reported, never counted as a failure -- see the class doc.
var _over_budget: int = 0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "TrackPropsAudit")
	print("=== TRACKSIDE PROPS AUDIT ===")
	print("purpose : re-measure the frame triangle budget, and prove the")
	print("          props stay outside the play area and carry no collider.")
	print("")
	_run_keepout()
	_run_no_collider()
	print("--- PHASE 1: frame triangle budget, measured on a live run ---")
	print("sampling %.0fs of real play, keeping the WORST frame" % BUDGET_SAMPLE_S)
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)

func _physics_process(delta: float) -> void:
	if _game == null:
		return
	# The run ending is not a reason to stop measuring -- a dead run draws
	# the same track. Restart it so the sample keeps reaching the later,
	# denser stages instead of stalling on whatever killed it.
	if GameState.state != GameState.State.PLAYING:
		GameState.start_run()
		return
	_sample_frame()
	_sampled_s += delta
	_frames += 1
	if _sampled_s >= BUDGET_SAMPLE_S:
		_report_budget()
		_finish()

## Adds up every triangle actually being drawn this frame, per family.
## `is_visible_in_tree` is the filter, not `visible`: a pooled hazard
## hidden by its own flag and one hidden because an ancestor is hidden
## both cost nothing, and only the tree-wide answer says so.
func _sample_frame() -> void:
	var families: Dictionary = {}
	var total := 0
	var instances := 0
	for node in _all_mesh_instances(_game):
		if not node.is_visible_in_tree():
			continue
		var triangles := _triangles(node.mesh)
		if triangles == 0:
			continue
		var family := _family_of(node)
		families[family] = int(families.get(family, 0)) + triangles
		total += triangles
		instances += 1
	if total > _peak_triangles:
		_peak_triangles = total
		_peak_instances = instances
		_peak_families = families

func _report_budget() -> void:
	print("  frames sampled  : %d" % _frames)
	print("")
	print("  WORST FRAME -- what the renderer was actually handed:")
	var keys := _peak_families.keys()
	keys.sort()
	for family in keys:
		print("    %-22s %7d tri" % [family, int(_peak_families[family])])
	print("    %-22s %7s" % ["", "-------"])
	print("    %-22s %7d tri  across %d visible mesh instances" % [
		"TOTAL", _peak_triangles, _peak_instances])
	print("")

	# What this probe ENFORCES: the props' own share.
	var props: int = int(_peak_families.get("trackside props", 0))
	if props <= PROPS_TRIANGLE_BUDGET:
		print("  OK   trackside props cost %d tri at the worst frame, within their %d budget" % [
			props, PROPS_TRIANGLE_BUDGET])
		print("       (%.1f%% of the %d frame target)." % [
			100.0 * float(props) / float(TRIANGLE_TARGET), TRIANGLE_TARGET])
	else:
		print("  FAIL trackside props cost %d tri, over their %d budget." % [
			props, PROPS_TRIANGLE_BUDGET])
		_failures += 1
	print("")

	# What this probe REPORTS: the whole frame, against section 7.
	if _peak_triangles <= TRIANGLE_TARGET:
		print("  OK   frame total %d tri against the %d target -- %.1f%% headroom." % [
			_peak_triangles, TRIANGLE_TARGET,
			100.0 * (1.0 - float(_peak_triangles) / float(TRIANGLE_TARGET))])
	else:
		_over_budget = _peak_triangles - TRIANGLE_TARGET
		print("  BUDGET FINDING -- NOT a verdict on this batch, and NOT caused by it:")
		print("    the frame peaks at %d tri, %d OVER section 7's %d target." % [
			_peak_triangles, _over_budget, TRIANGLE_TARGET])
		print("    The props account for %d of that (%.1f%%); removing them entirely" % [
			props, 100.0 * float(props) / float(_peak_triangles)])
		print("    would still leave the frame ~%d tri over." % (_over_budget - props))
		print("    Largest contributors, against what section 7 budgeted for them:")
		_print_overrun("collectibles", 4200)
		_print_overrun("pursuer", 8000)
		_print_overrun("hazards", 8400)
		_print_overrun("keepy", 6000)
		print("    This needs its own batch; see docs/MESHY_SPEC.md section 7.")
	print("")

func _print_overrun(family: String, budgeted: int) -> void:
	var actual: int = int(_peak_families.get(family, 0))
	var verdict := "OVER by %d" % (actual - budgeted) if actual > budgeted else "within budget"
	print("      %-14s measured %6d tri  vs %5d budgeted  -- %s" % [
		family, actual, budgeted, verdict])

## Rolls a real TrackSegment's props many times and measures how close any
## of them ever came to the track centre.
##
## Uses the segment's own populate(), not a private placement call: the
## invariant has to survive the path the game actually takes, including
## the fact that populate() rolls the hazard and the props from two
## different generators in one call.
func _run_keepout() -> void:
	print("--- PHASE 2: props never overlap the readable play area ---")
	var slab_half_width: float = Hitboxes.GROUND_SIZE.x * 0.5
	var segment: TrackSegment = TRACK_SEGMENT_SCENE.instantiate()
	add_child(segment)

	var nearest := INF
	var populated := 0
	for i in KEEPOUT_ROLLS:
		segment.populate(false, Obstacle.Type.DODGE, 1, -1, -1)
		var edge := segment.nearest_prop_edge_x()
		if edge == INF:
			continue
		populated += 1
		nearest = minf(nearest, edge)

	print("  populate() calls        : %d" % KEEPOUT_ROLLS)
	print("  of which showed a prop  : %d" % populated)
	print("  ground slab half-width  : %.3f m (Hitboxes.GROUND_SIZE.x * 0.5)" % slab_half_width)
	if populated == 0:
		print("  FAIL not one roll produced a prop -- nothing was measured.")
		_failures += 1
	else:
		print("  nearest prop edge ever  : %.3f m from the centre line" % nearest)
		if nearest > slab_half_width:
			print("  OK   every prop stayed clear of the slab, by %.3f m at the worst roll." % (
				nearest - slab_half_width))
		else:
			print("  FAIL a prop reached %.3f m, inside the %.3f m slab." % [nearest, slab_half_width])
			_failures += 1
	print("")

	remove_child(segment)
	segment.queue_free()

## The props live inside a StaticBody3D, so "they have no collider" is a
## claim about a physics body, not about a Node3D. Checked both ways: the
## body's own shape set, and a tree walk for any CollisionShape3D that is
## not the slab's.
func _run_no_collider() -> void:
	print("--- PHASE 3: props add no collider to the segment body ---")
	var segment: TrackSegment = TRACK_SEGMENT_SCENE.instantiate()
	add_child(segment)
	# Populate first: a prop that only appears once a segment is filled
	# would otherwise be checked in its hidden, never-placed state.
	segment.populate(false, Obstacle.Type.DODGE, 1, -1, -1)

	var owners := segment.get_shape_owners()
	var shapes := 0
	for owner_id in owners:
		shapes += segment.shape_owner_get_shape_count(owner_id)
	print("  shape owners on the segment body : %d" % owners.size())
	print("  shapes on the segment body       : %d" % shapes)
	if shapes == 1:
		print("  OK   exactly one shape -- the ground slab, unchanged.")
	else:
		print("  FAIL expected exactly 1 shape (the ground slab), found %d." % shapes)
		_failures += 1

	# The pooled Obstacle/Noisette/Gland children carry their own colliders
	# and are not this probe's subject -- AssetContractAudit measures those
	# standalone. Only the segment's OWN direct children are walked here,
	# which is exactly where a prop would land.
	var direct_shapes: Array[String] = []
	for child in segment.get_children():
		if child is Obstacle or child is CollectibleBase:
			continue
		_collect_shapes(child, segment, direct_shapes)
	print("  CollisionShape3D nodes outside the pooled hazards/collectibles : %d" % direct_shapes.size())
	for path in direct_shapes:
		print("    %s" % path)
	if direct_shapes.size() == 1 and direct_shapes[0] == "CollisionShape3D":
		print("  OK   the only one is the slab's, exactly as before this batch.")
	else:
		print("  FAIL a CollisionShape3D appeared that is not the ground slab's.")
		_failures += 1
	print("")

	remove_child(segment)
	segment.queue_free()

func _collect_shapes(node: Node, root: Node, into: Array[String]) -> void:
	if node is CollisionShape3D:
		into.append(str(root.get_path_to(node)))
	for child in node.get_children():
		_collect_shapes(child, root, into)

## Every MeshInstance3D at or under `node`. Walks the tree rather than
## naming paths: the whole point is to catch geometry a future batch adds
## without telling this probe about it.
func _all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var instance := node as MeshInstance3D
	if instance:
		found.append(instance)
	for child in node.get_children():
		found.append_array(_all_mesh_instances(child))
	return found

## Triangle count of a mesh as the renderer would rasterise it.
## get_faces() returns three vertices per triangle across every surface,
## which is the one measure that reads a procedural primitive and an
## imported .glb the same way -- and this project now has both.
func _triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	return mesh.get_faces().size() / 3

## Groups a mesh instance under the thing a reader would budget for.
##
## Resolved by walking UP the parent chain and matching node TYPES, not by
## matching substrings of a node path. The first version of this function
## did the latter and got it badly wrong: a Noisette's mesh child is
## simply named "MeshInstance3D", exactly like a TrackSegment's ground
## slab, so ~34,000 triangles of collectibles were reported as trackside
## props -- a misattribution that pointed at the new code for a cost the
## new code was not paying. Types cannot collide that way, and a family
## stays correct when a future batch renames or reparents something.
func _family_of(node: MeshInstance3D) -> String:
	# Props first: they are MeshInstance3D children of a TrackSegment, so
	# the segment branch below would otherwise swallow them.
	if node.name.begins_with("Prop"):
		return "trackside props"
	var walker: Node = node
	while walker != null and walker != _game:
		if walker is Obstacle:
			return "hazards"
		if walker is CollectibleBase:
			return "collectibles"
		if walker is TrackSegment:
			return "track slab + curbs"
		if walker is Keepy:
			return "keepy"
		if walker is Pursuer:
			return "pursuer"
		if walker is Decor:
			return "decor hills"
		if walker.name == "LaneBarrier":
			return "lane barrier"
		walker = walker.get_parent()
	return "other"

func _finish() -> void:
	print("")
	if _failures > 0:
		print("FAILED: %d check(s) did not hold." % _failures)
		get_tree().quit(1)
		return
	print("PASSED: props stay outside the play area, add no collider, and cost")
	print("        %d tri of the %d frame target." % [
		int(_peak_families.get("trackside props", 0)), TRIANGLE_TARGET])
	if _over_budget > 0:
		# Said again, last, on purpose. A reader who takes only the final
		# line away must not take away "the budget is fine" -- that is the
		# exact false-green shape docs/PROBE_AUDIT.md was written about.
		print("        OPEN FINDING, pre-existing and unrelated: the frame itself is")
		print("        %d tri over the %d target. See the phase 1 table." % [
			_over_budget, TRIANGLE_TARGET])
	get_tree().quit(0)
