extends Node
## Dev-only geometry check for the CHARGER's silhouette contract
## (ChargerMesh in Obstacle.tscn), asserted against WHATEVER that slot
## draws -- the placeholder prism and the shipped .glb alike.
##
## WHY THIS EXISTS AS A PROBE RATHER THAN A READ-THROUGH: the charger's
## strongest telegraph is its SHAPE (see Obstacle.gd's TELEGRAPH block) --
## a body that narrows toward the player, with speed-line bars trailing
## behind it. Nothing else in the project measures orientation. The
## contrast audit samples an UNSHADED material, so it reports the exact
## same colour whether the nose faces the player or away from them, and
## no gameplay measurement touches facing at all. Installed backwards,
## the one cue that survives every palette by construction would point
## the wrong way, in silence.
##
## =====================================================================
## WHY IT NOW READS VERTICES INSTEAD OF THE PLACEHOLDER'S OWN MESH
##
## The previous version read `mesh_instance.mesh` directly and asserted
## that a PrismMesh narrows toward +Z. That is not a contract about the
## CHARGER, it is a contract about a PrismMesh: the moment a .glb landed
## on this slot `mesh` became null, and the file said so and failed on
## purpose, deferring the rework to whoever installed the art.
##
## This is that rework. The contract is re-expressed as a property of the
## drawn SILHOUETTE rather than of a primitive's parameters, so the same
## assertions run against both:
##
##   - the FRONT of the body is narrower than its REAR (the nose leads);
##   - and it is genuinely tapered, not marginally so;
##   - the body sits ON the ground, not buried or floating;
##   - it stands above the jump peak, so it reads unjumpable, matching a
##     hitbox that is;
##   - the trail bars sit BEHIND it -- and, new here, are not swallowed
##     by it. A 1.9m-long boar scaled to the placeholder's lateral
##     presence is 3.5m deep where the prism was 2.4m, which is easily
##     enough to bury the first bar inside the rump and turn a MOTION cue
##     into three flat plates poking out of an animal.
##
## Both paths are measured, in two phases, for the reason AlarmRampAudit
## already had to learn: once an asset is installed, a phase that says
## "placeholder" gets the .glb for free unless it takes the placeholder
## path deliberately, and then reports it under a label saying the
## opposite.
##
## HOW PHASE A GETS THE PLACEHOLDER, AND WHY NOT THE OBVIOUS WAY:
## AlarmRampAudit clears `model_scene` on the live slot. That works there
## and does NOT work here, which is worth stating because the difference
## is not obvious and this probe found it by failing:
## ModelSlot._install_model() sets `mesh = null` when it installs a
## model, and the null-model branch never puts it back -- it only appends
## `self` to `_drawn`. So a slot whose model is cleared after the fact
## keeps its material override (which is why AlarmRampAudit is fine, it
## reads materials) and draws NO GEOMETRY AT ALL (which is fatal to a
## probe that reads vertices; measured, not reasoned -- the first version
## of this file reported "placeholder draws no geometry at all").
##
## So PHASE A builds its own Obstacle and clears model_scene BEFORE
## adding it to the tree, so ModelSlot._ready() takes the placeholder
## branch on its first and only run. That is also the more honest test:
## it exercises the code path that would actually ship if the asset were
## ever removed, rather than a state reachable only at runtime.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --path . res://scripts/dev/ChargerShapeProbe.tscn

## Fraction of the Z span at each end counted as "the nose" and "the
## tail". A fifth is wide enough that a coarse LOD still puts real
## surface in each band, and narrow enough that the bands cannot overlap
## the body's widest point.
const END_BAND: float = 0.2

## How much narrower the nose band has to be than the widest part of the
## body before the taper counts as readable rather than incidental. The
## shipped boar measures ~0.73 and the placeholder prism ~0.1, so both
## clear this comfortably; a model installed back-to-front measures ~1.0
## and does not. It is a discriminator, not a tuning knob.
const TAPER_CEILING: float = 0.85

## Local Z of the front face of the nearest trail bar (Bar0 sits at
## -1.6 in Obstacle.tscn and its BoxMesh is 0.6 deep). The body's tail
## must stop short of this or the first speed line is drawn inside it.
##
## The authored Z is also the WORST case, which is why a static constant
## is enough: _animate_charger_trail sets position.z = base_z - phase
## with phase in [0, CHARGER_TRAIL_SPACING), so the slide only ever moves
## a bar further BEHIND its authored position, never in front of it.
const NEAREST_BAR_FRONT_Z: float = -1.3

var _failures: int = 0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "ChargerShapeProbe")
	print("=== CHARGER SHAPE PROBE ===")
	print("")

	# PHASE A -- the fallback path, taken deliberately: model_scene is
	# cleared BEFORE the node enters the tree, so the slot's one and only
	# _install_model() run keeps the placeholder's own mesh (see the note
	# on this in the file header).
	print("--- PHASE A: placeholder, model_scene cleared before _ready() ---")
	var bare: Obstacle = preload("res://scenes/Obstacle.tscn").instantiate()
	(bare.get_node("ChargerMesh") as ModelSlot).model_scene = null
	add_child(bare)
	bare.configure(Obstacle.Type.CHARGER)
	_check(bare.get_node("ChargerMesh"), bare.get_node("ChargerTrail"), "placeholder")

	print("")
	print("--- PHASE B: Obstacle.tscn AS SHIPPED ---")
	var obstacle: Obstacle = preload("res://scenes/Obstacle.tscn").instantiate()
	add_child(obstacle)
	obstacle.configure(Obstacle.Type.CHARGER)
	var slot: ModelSlot = obstacle.get_node("ChargerMesh")
	# Read off the slot, never inferred from the phase: the day an asset
	# is added or removed the log says so, instead of quietly degenerating
	# into a second copy of PHASE A.
	_check(slot, obstacle.get_node("ChargerTrail"), "as shipped [%s]" % ("glb" if slot.has_model() else "-- "))

	print("")
	if _failures == 0:
		print("PASSED: charger silhouette is oriented, grounded and clear of its trail.")
		get_tree().quit(0)
	else:
		push_error("CHARGER SHAPE PROBE FAILED: %d check(s)." % _failures)
		get_tree().quit(1)

## Every vertex the slot currently draws, expressed in OBSTACLE-local
## space so the numbers are directly comparable to the lane, the ground
## and the trail bars' own positions.
##
## Walks the slot's descendants rather than reading `slot.mesh`, which is
## null once a model is installed, and routes both cases through
## ModelSlot.get_transform_to_slot() so the placeholder path returns
## exactly what reading the mesh directly used to return: for the slot
## itself that transform is the identity by construction.
func _drawn_points(slot: ModelSlot) -> PackedVector3Array:
	var out := PackedVector3Array()
	var instances: Array[MeshInstance3D] = []
	if slot.has_model():
		_collect(slot, instances)
	else:
		instances.append(slot)
	for mesh_instance in instances:
		if mesh_instance.mesh == null:
			continue
		var to_obstacle := slot.transform * slot.get_transform_to_slot(mesh_instance)
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			for v in arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				out.append(to_obstacle * v)
	return out

func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance:
			out.append(mesh_instance)
		_collect(child, out)

func _check(slot: ModelSlot, trail: Node3D, label: String) -> void:
	var points := _drawn_points(slot)
	if points.is_empty():
		print("FAIL: %s draws no geometry at all." % label)
		_failures += 1
		return

	var min_v := points[0]
	var max_v := points[0]
	for p in points:
		min_v = min_v.min(p)
		max_v = max_v.max(p)
	var z_span := max_v.z - min_v.z
	var nose_from := max_v.z - z_span * END_BAND
	var tail_to := min_v.z + z_span * END_BAND

	var nose_half := 0.0
	var tail_half := 0.0
	var body_half := 0.0
	for p in points:
		var half := absf(p.x)
		body_half = maxf(body_half, half)
		if p.z >= nose_from:
			nose_half = maxf(nose_half, half)
		if p.z <= tail_to:
			tail_half = maxf(tail_half, half)

	print("  %s: X %.3f wide, Y %.3f .. %.3f, Z %.3f .. %.3f (nose at the LARGER Z)"
		% [label, max_v.x - min_v.x, min_v.y, max_v.y, min_v.z, max_v.z])
	print("    nose band half-width %.3f | tail band %.3f | widest %.3f"
		% [nose_half, tail_half, body_half])

	# The nose leads. Asserted against the TAIL rather than against a
	# constant, because that is the failure this guards: a model turned
	# back-to-front swaps these two and nothing else in the project would
	# notice.
	if nose_half < tail_half:
		print("    OK  : the body is narrower at +Z than at -Z -- the nose leads, aimed at the player.")
	else:
		print("    FAIL: the body is not narrower at +Z (%.3f) than at -Z (%.3f) -- its nose is not aimed at the player."
			% [nose_half, tail_half])
		_failures += 1

	var taper := nose_half / body_half if body_half > 0.0 else 1.0
	if taper <= TAPER_CEILING:
		print("    OK  : it tapers toward the player (nose is %.0f%% of its widest, ceiling %.0f%%)."
			% [taper * 100.0, TAPER_CEILING * 100.0])
	else:
		print("    FAIL: it barely tapers (nose is %.0f%% of its widest, ceiling %.0f%%) -- reads as a slab, not a point."
			% [taper * 100.0, TAPER_CEILING * 100.0])
		_failures += 1

	if absf(min_v.y) <= 0.05:
		print("    OK  : it sits on the ground (min Y = %.3f)." % min_v.y)
	else:
		print("    FAIL: it does not sit on the ground (min Y = %.3f, expected ~0)." % min_v.y)
		_failures += 1

	if max_v.y > Keepy.JUMP_PEAK_HEIGHT:
		print("    OK  : it stands %.3f m above the jump peak (%.3f m) -- reads unjumpable, matching its hitbox."
			% [max_v.y - Keepy.JUMP_PEAK_HEIGHT, Keepy.JUMP_PEAK_HEIGHT])
	else:
		print("    FAIL: %.3f m is not visibly taller than a jump (%.3f m) -- it would read as jumpable."
			% [max_v.y, Keepy.JUMP_PEAK_HEIGHT])
		_failures += 1

	# The MOTION half of the telegraph. Being behind the body is not
	# enough on its own: a bar drawn inside the rump reads as a plate
	# stuck through an animal rather than as a speed line it leaves
	# behind, and the placeholder never had to answer this because it was
	# a metre shallower than the art that replaced it.
	var trail_ok := true
	for bar in trail.get_children():
		var z: float = (bar as Node3D).position.z
		if z >= 0.0:
			trail_ok = false
		print("    trail bar %-6s local Z = %+.2f" % [(bar as Node3D).name, z])
	if trail_ok:
		print("    OK  : every trail bar sits behind the body (negative Z).")
	else:
		print("    FAIL: at least one trail bar is not behind the body.")
		_failures += 1

	if min_v.z > NEAREST_BAR_FRONT_Z:
		print("    OK  : the body stops %.3f m short of the nearest bar (tail %.3f, bar front %.2f)."
			% [min_v.z - NEAREST_BAR_FRONT_Z, min_v.z, NEAREST_BAR_FRONT_Z])
	else:
		print("    FAIL: the body reaches %.3f m INTO the nearest trail bar (tail %.3f, bar front %.2f) -- the speed lines are buried in it."
			% [NEAREST_BAR_FRONT_Z - min_v.z, min_v.z, NEAREST_BAR_FRONT_Z])
		_failures += 1
