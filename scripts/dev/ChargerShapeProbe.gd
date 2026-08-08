extends Node
## Dev-only one-shot geometry check for the CHARGER's mesh transform
## (ChargerMesh in Obstacle.tscn).
##
## WHY THIS EXISTS AS A PROBE RATHER THAN A READ-THROUGH: the wedge is a
## PrismMesh rotated a quarter turn so its apex leads. Which world
## direction the apex ends up pointing depends on the sign convention of
## a hand-written Transform3D basis, and getting it backwards is both
## easy (it was, on the first attempt here) and completely invisible
## everywhere else -- the contrast audit samples an UNSHADED material, so
## it reports the exact same colour whether the nose faces the player or
## away from them, and no gameplay measurement touches orientation at
## all. The telegraph's strongest cue would have silently pointed the
## wrong way.
##
## So this asserts the three things that make the silhouette read
## correctly, straight off the built mesh AABB in world space:
##   - the apex is at POSITIVE Z (the direction of travel, i.e. aimed at
##     the player, who sits at Z=0 -- see TrackManager's class doc);
##   - the wedge sits ON the ground (min Y ~= 0), not buried or floating;
##   - the trail bars sit BEHIND it (negative Z), where nothing else in
##     the game has anything, which is the other half of the cue.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --path . res://scripts/dev/ChargerShapeProbe.tscn

func _ready() -> void:
	var obstacle: Obstacle = preload("res://scenes/Obstacle.tscn").instantiate()
	add_child(obstacle)
	obstacle.configure(Obstacle.Type.CHARGER)

	var mesh_instance: ModelSlot = obstacle.get_node("ChargerMesh")

	# This probe inspects the PLACEHOLDER prism's own vertices (see the
	# width-at-each-end test below), which only exist while the placeholder
	# is what is drawn. Once a Meshy wedge .glb is installed in this slot,
	# `mesh` is null and there is nothing here to read -- so say so plainly
	# instead of crashing on it, and treat it as a failure: the orientation
	# contract this file guards does not stop mattering when the art
	# arrives, it just needs re-expressing against the imported geometry.
	# See docs/MESHY_SPEC.md, which carries that follow-up.
	if mesh_instance.has_model():
		push_error("CHARGER SHAPE PROBE: ChargerMesh now carries an imported model. " +
			"This probe reads the placeholder prism's vertices and must be reworked " +
			"to assert the same +Z nose contract against the .glb (see docs/MESHY_SPEC.md).")
		get_tree().quit(1)
		return

	var aabb := mesh_instance.transform * mesh_instance.mesh.get_aabb()
	var apex_z := aabb.position.z + aabb.size.z
	var base_z := aabb.position.z
	var min_y := aabb.position.y
	var max_y := aabb.position.y + aabb.size.y
	var width := aabb.size.x

	print("=== CHARGER SHAPE PROBE ===")
	print("wedge AABB (obstacle-local, so directly comparable to lane/ground):")
	print("  X width          : %.3f m" % width)
	print("  Y span           : %.3f .. %.3f m" % [min_y, max_y])
	print("  Z span           : %.3f .. %.3f m (nose at the LARGER value)" % [base_z, apex_z])
	print("")

	var failures := 0

	# The apex is the narrow end. Sample the mesh's own vertices rather
	# than trusting the AABB alone: an AABB cannot tell a forward-pointing
	# wedge from a backward-pointing one, only where the extremes are.
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var width_at_max_z := 0.0
	var width_at_min_z := 0.0
	for v in vertices:
		var w: Vector3 = mesh_instance.transform * v
		if absf(w.z - apex_z) < 0.01:
			width_at_max_z = maxf(width_at_max_z, absf(w.x) * 2.0)
		if absf(w.z - base_z) < 0.01:
			width_at_min_z = maxf(width_at_min_z, absf(w.x) * 2.0)
	print("  width at the +Z end: %.3f m" % width_at_max_z)
	print("  width at the -Z end: %.3f m" % width_at_min_z)

	if width_at_max_z >= width_at_min_z:
		print("FAIL: the wedge does not narrow toward +Z -- its nose is not aimed at the player.")
		failures += 1
	else:
		print("OK  : the wedge narrows toward +Z -- the nose leads, aimed at the player.")

	if absf(min_y) > 0.05:
		print("FAIL: the wedge does not sit on the ground (min Y = %.3f, expected ~0)." % min_y)
		failures += 1
	else:
		print("OK  : the wedge sits on the ground (min Y = %.3f)." % min_y)

	if max_y <= Keepy.JUMP_PEAK_HEIGHT:
		print("FAIL: the wedge (%.3f m) is not visibly taller than a jump (%.3f m) -- it would read as jumpable."
			% [max_y, Keepy.JUMP_PEAK_HEIGHT])
		failures += 1
	else:
		print("OK  : the wedge (%.3f m) stands above the jump peak (%.3f m) -- reads unjumpable, matching its hitbox."
			% [max_y, Keepy.JUMP_PEAK_HEIGHT])

	var trail: Node3D = obstacle.get_node("ChargerTrail")
	var trail_ok := true
	for bar in trail.get_children():
		var z: float = (bar as Node3D).position.z
		if z >= 0.0:
			trail_ok = false
		print("  trail bar %-6s local Z = %+.2f" % [(bar as Node3D).name, z])
	if trail_ok:
		print("OK  : every trail bar sits behind the wedge (negative Z).")
	else:
		print("FAIL: at least one trail bar is not behind the wedge.")
		failures += 1

	print("")
	if failures == 0:
		print("PASSED: charger silhouette is oriented and grounded as designed.")
		get_tree().quit(0)
	else:
		push_error("CHARGER SHAPE PROBE FAILED: %d check(s)." % failures)
		get_tree().quit(1)
