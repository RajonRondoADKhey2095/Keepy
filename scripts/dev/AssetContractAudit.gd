extends Node
## Dev-only geometry probe for the GRAPHICS-PREP contract: the split
## between what a Meshy .glb is allowed to change (the visual) and what it
## must never touch (the hitbox).
##
## =====================================================================
## WHY THIS EXISTS
##
## Every fairness number in this game is written against a COLLIDER
## dimension. Keepy.JUMPABLE_OBSTACLE_TOP_HEIGHT's ~0.51s clearance window
## is a consequence of the JUMP box being 0.7m tall. DODGE being
## unjumpable is a consequence of its box standing above
## Keepy.JUMP_PEAK_HEIGHT. Obstacle.RISK_MIN_SURVIVABLE_LATERAL_M is
## literally derived in its own doc from "the widest hazard hitbox is
## 1.2m, i.e. half-width 0.6, plus Keepy's capsule radius 0.5", and
## RISK_PROXIMITY_Z from "every hazard hitbox is 1.0m deep".
##
## None of those would survive a stray half-metre on a collider -- and
## crucially, NO OTHER PROBE IN THIS FOLDER WOULD REPORT IT. They would
## all keep passing, on a game that had quietly been rebalanced. The
## frustration and pursuer audits measure whether the game is fair; they
## have no opinion about whether it is the same game it was yesterday.
##
## So this probe measures the geometry itself, and does it three ways:
##
##   PHASE 1, THE TABLE -- every collider and every visual in the game,
##     measured off the real instantiated scenes rather than transcribed
##     from the .tscn files. This is the dimensional specification the
##     Meshy assets have to be authored against; docs/MESHY_SPEC.md is
##     written from this output, not from reading the scenes by eye.
##
##   PHASE 2, THE CONTRACT -- every collider checked against Hitboxes.gd.
##     Catches a scene edited to disagree with the constants, which is the
##     exact failure mode the constants exist to make impossible.
##
##   PHASE 3, THE SWAP -- the one that matters. Every ModelSlot in the
##     game gets a substitute model installed (SubstituteModel.tscn, a
##     stand-in shaped like an imported .glb), and then EVERY collider is
##     measured again. The visual AABBs must all have changed; not one
##     collider may have moved by a single float. That is the guarantee
##     this whole batch is for, asserted rather than asserted-in-a-comment.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --path . res://scripts/dev/AssetContractAudit.tscn

const SUBSTITUTE := preload("res://scripts/dev/SubstituteModel.tscn")

const KEEPY_SCENE := preload("res://scenes/Keepy.tscn")
const OBSTACLE_SCENE := preload("res://scenes/Obstacle.tscn")
const NOISETTE_SCENE := preload("res://scenes/Noisette.tscn")
const GLAND_SCENE := preload("res://scenes/Gland.tscn")
const TRACK_SEGMENT_SCENE := preload("res://scenes/TrackSegment.tscn")
const PURSUER_SCENE := preload("res://scenes/Pursuer.tscn")

## Float tolerance for "did this collider move". Deliberately far tighter
## than any dimension in the game (the smallest is ENEMY's 0.3m radius):
## this is asking whether a number is the SAME number, not whether it is
## close, so anything a swap could plausibly do lands far outside it.
const EPSILON: float = 0.00001

var _failures: int = 0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "AssetContractAudit")
	print("=== ASSET CONTRACT AUDIT ===")
	print("purpose : a Meshy .glb may change every visual and no hitbox.")
	print("")

	var before := _measure_all(false)
	_print_table(before)
	_check_against_hitboxes(before)

	var after := _measure_all(true)
	_check_swap(before, after)

	print("")
	if _failures == 0:
		print("PASSED: swapping every mesh changed every visual and moved no collider.")
		get_tree().quit(0)
	else:
		push_error("ASSET CONTRACT AUDIT FAILED: %d check(s)." % _failures)
		get_tree().quit(1)

# =====================================================================
# MEASUREMENT
# =====================================================================

## Instantiates every gameplay scene and reports what it really contains.
##
## `substitute` installs SubstituteModel.tscn into every ModelSlot found,
## BEFORE the scene enters the tree -- so the install happens inside the
## slot's own _ready(), on exactly the code path a shipped asset would
## take, rather than through some probe-only back door.
##
## Returns { "<object>/<node>": { ... } } so the two passes can be compared
## key by key, and a node that DISAPPEARED between them is as visible as one
## whose numbers moved.
func _measure_all(substitute: bool) -> Dictionary:
	var result := {}
	# The six obstacle variants share one Obstacle scene: configure() only
	# toggles which mesh/shape pair is active, so a single instance carries
	# every hitbox in the game simultaneously and all of them can be read
	# off it at once.
	for entry in [
		["keepy", KEEPY_SCENE],
		["obstacle", OBSTACLE_SCENE],
		["noisette", NOISETTE_SCENE],
		["gland", GLAND_SCENE],
		["track", TRACK_SEGMENT_SCENE],
		["pursuer", PURSUER_SCENE],
	]:
		var label: String = entry[0]
		var scene: PackedScene = entry[1]
		var node: Node = scene.instantiate()
		if substitute:
			for slot in _find_slots(node):
				slot.model_scene = SUBSTITUTE
		add_child(node)
		_collect(node, label, node, result)
		remove_child(node)
		node.queue_free()
	return result

## Every ModelSlot at or under `node`. Recursive rather than a fixed list
## of node paths: an imported .glb can nest, and a future scene may add a
## slot this probe was never told about -- which it should still cover.
func _find_slots(node: Node) -> Array[ModelSlot]:
	var found: Array[ModelSlot] = []
	var slot := node as ModelSlot
	if slot:
		found.append(slot)
	for child in node.get_children():
		found.append_array(_find_slots(child))
	return found

func _collect(node: Node, label: String, root: Node, into: Dictionary) -> void:
	var path := "%s/%s" % [label, root.get_path_to(node)]

	var slot := node as ModelSlot
	if slot:
		var aabb := slot.visual_aabb()
		into[path] = {
			"kind": "visual",
			"size": aabb.size,
			"origin": aabb.position,
			"node_y": (slot as Node3D).position.y,
			"has_model": slot.has_model(),
			"material": _describe_material(slot.slot_material()),
		}

	var collision := node as CollisionShape3D
	if collision:
		into[path] = {
			"kind": "collider",
			"shape": _describe_shape(collision.shape),
			"offset": collision.position,
		}

	for child in node.get_children():
		# Do NOT descend into a TrackSegment's pooled children. They are
		# instances of Obstacle.tscn / Noisette.tscn / Gland.tscn, which are
		# each measured standalone above, so recursing here would re-measure
		# the same contract a second time -- under auto-generated node names
		# (@Area3D@6, @Area3D@7) whose counter advances between the two
		# passes, making the keys unstable and every comparison spurious.
		#
		# It would also be measuring the wrong thing: TrackSegment builds
		# these inside its own _ready(), i.e. AFTER this probe has authored
		# `model_scene` onto the slots that existed at instantiation time, so
		# they legitimately carry no substitute. Their swap behaviour is a
		# property of their own scenes, and that is where it is checked.
		if child is Obstacle or child is CollectibleBase:
			continue
		_collect(child, label, root, into)

## A shape's real dimensions as text, so two passes can be compared with a
## plain string equality and the table can print them unchanged. Covers
## only the three shape classes this project actually uses; anything else
## is reported loudly rather than silently formatted as "unknown", because
## a shape type this probe cannot read is a shape type it is not checking.
func _describe_shape(shape: Shape3D) -> String:
	var box := shape as BoxShape3D
	if box:
		return "Box(%.5f, %.5f, %.5f)" % [box.size.x, box.size.y, box.size.z]
	var capsule := shape as CapsuleShape3D
	if capsule:
		return "Capsule(r=%.5f, h=%.5f)" % [capsule.radius, capsule.height]
	var sphere := shape as SphereShape3D
	if sphere:
		return "Sphere(r=%.5f)" % sphere.radius
	return "UNSUPPORTED(%s)" % ("null" if shape == null else shape.get_class())

## Whether a material is UNSHADED matters for the Meshy spec, not just as
## trivia: an unshaded surface renders as exactly its albedo regardless of
## light angle, which is the only reason its post-inversion colour in dark
## mode is a value that can be verified ahead of time (see Pursuer.gd's
## BODY IS UNSHADED note and Obstacle.gd's TELEGRAPH sections).
func _describe_material(material: Material) -> String:
	var standard := material as StandardMaterial3D
	if standard == null:
		return "-"
	var shading := "unshaded" if standard.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else "lit"
	var albedo := standard.albedo_color
	var emissive := " +emissive" if standard.emission_enabled else ""
	return "%s rgb(%.2f, %.2f, %.2f)%s" % [shading, albedo.r, albedo.g, albedo.b, emissive]

# =====================================================================
# PHASE 1 -- THE TABLE
# =====================================================================

func _print_table(data: Dictionary) -> void:
	print("--- PHASE 1: measured geometry (as shipped) ---")
	print("VISUALS -- what a .glb replaces. size = mesh AABB in slot space,")
	print("           node_y = the slot's own height above its object's origin.")
	print("           [glb] = a real asset is installed here; [-- ] = still the placeholder.")
	print("           A [glb] row's material is the one bound to the imported MESH, which")
	print("           is where Godot's glTF importer puts it -- see ModelSlot.slot_material().")
	var keys := data.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = data[key]
		if row["kind"] != "visual":
			continue
		# Printed rather than merely collected: this header used to say
		# "placeholder meshes", which stopped being true for every row the
		# moment the first hazard asset was installed. A table that cannot
		# distinguish an installed .glb from the primitive it replaced is
		# exactly the kind of quietly-wrong output this folder exists to
		# prevent.
		var marker := "[glb]" if row["has_model"] else "[-- ]"
		print("  %-34s %s size %6.3f x %6.3f x %6.3f  node_y %+.3f  %s" % [
			key, marker, row["size"].x, row["size"].y, row["size"].z, row["node_y"], row["material"]])
	print("")
	print("COLLIDERS -- what a .glb must NEVER change. Sizes are FULL extents.")
	for key in keys:
		var row: Dictionary = data[key]
		if row["kind"] != "collider":
			continue
		print("  %-34s %-30s offset_y %+.3f" % [key, row["shape"], row["offset"].y])
	print("")

# =====================================================================
# PHASE 2 -- THE CONTRACT
# =====================================================================

## Asserts each collider against Hitboxes.gd, i.e. that the scenes and the
## constants still agree. AIR_ENEMY's offset is exempt on purpose: it is
## TrackSegment.GLAND_Y, a derived value applied at runtime, and it is the
## one hitbox offset Hitboxes.gd deliberately does not own (see its LEAF BY
## CONSTRUCTION note for why importing TrackSegment there is not an option).
func _check_against_hitboxes(data: Dictionary) -> void:
	print("--- PHASE 2: colliders vs Hitboxes.gd ---")
	_expect(data, "keepy/CollisionShape3D",
		"Capsule(r=%.5f, h=%.5f)" % [Hitboxes.KEEPY_RADIUS, Hitboxes.KEEPY_HEIGHT], Hitboxes.KEEPY_Y)
	_expect(data, "obstacle/DodgeShape", _box_text(Hitboxes.DODGE_SIZE), Hitboxes.DODGE_Y)
	_expect(data, "obstacle/JumpShape", _box_text(Hitboxes.JUMP_SIZE), Hitboxes.JUMP_Y)
	_expect(data, "obstacle/StomperShape", _box_text(Hitboxes.STOMPER_SIZE), Hitboxes.STOMPER_Y)
	_expect(data, "obstacle/ChargerShape", _box_text(Hitboxes.CHARGER_SIZE), Hitboxes.CHARGER_Y)
	_expect(data, "obstacle/EnemyShape",
		"Capsule(r=%.5f, h=%.5f)" % [Hitboxes.ENEMY_RADIUS, Hitboxes.ENEMY_HEIGHT], Hitboxes.ENEMY_Y)
	_expect(data, "obstacle/AirEnemyShape", _box_text(Hitboxes.AIR_ENEMY_SIZE), INF)
	_expect(data, "noisette/CollisionShape3D", "Sphere(r=%.5f)" % Hitboxes.COLLECTIBLE_RADIUS, 0.0)
	_expect(data, "gland/CollisionShape3D", "Sphere(r=%.5f)" % Hitboxes.COLLECTIBLE_RADIUS, 0.0)
	_expect(data, "track/CollisionShape3D", _box_text(Hitboxes.GROUND_SIZE), Hitboxes.GROUND_Y)

	# The pursuer's total absence of a collider is a design guarantee, not
	# an omission -- being caught is a GameState event on the run clock, and
	# a hitbox here would create a second, competing way to die that reports
	# the wrong death cause (see Pursuer.gd's class doc). Worth asserting
	# precisely because a Meshy .glb that happened to ship with a collision
	# node would introduce one silently.
	var pursuer_colliders := 0
	for key in data.keys():
		if key.begins_with("pursuer/") and data[key]["kind"] == "collider":
			pursuer_colliders += 1
	if pursuer_colliders == 0:
		print("  OK   pursuer has no collider at all (by design)")
	else:
		print("  FAIL pursuer grew %d collider(s) -- it must never be able to catch anyone" % pursuer_colliders)
		_failures += 1
	print("")

func _box_text(size: Vector3) -> String:
	return "Box(%.5f, %.5f, %.5f)" % [size.x, size.y, size.z]

## `expected_y` of INF means "this offset is runtime-derived, do not check".
func _expect(data: Dictionary, key: String, expected_shape: String, expected_y: float) -> void:
	if not data.has(key):
		print("  FAIL %s is missing entirely" % key)
		_failures += 1
		return
	var row: Dictionary = data[key]
	var actual_shape: String = row["shape"]
	var actual_y: float = row["offset"].y
	var shape_ok := actual_shape == expected_shape
	var y_ok := is_inf(expected_y) or absf(actual_y - expected_y) < EPSILON
	if shape_ok and y_ok:
		print("  OK   %-30s %s" % [key, actual_shape])
		return
	if not shape_ok:
		print("  FAIL %s shape is %s, Hitboxes.gd says %s" % [key, actual_shape, expected_shape])
		_failures += 1
	if not y_ok:
		print("  FAIL %s offset_y is %+.5f, Hitboxes.gd says %+.5f" % [key, actual_y, expected_y])
		_failures += 1

# =====================================================================
# PHASE 3 -- THE SWAP
# =====================================================================

func _check_swap(before: Dictionary, after: Dictionary) -> void:
	print("--- PHASE 3: every ModelSlot swapped to SubstituteModel.tscn ---")

	var keys := before.keys()
	keys.sort()

	var visuals_changed := 0
	var visuals_total := 0
	var colliders_checked := 0

	for key in keys:
		if not after.has(key):
			print("  FAIL %s vanished when the model was swapped" % key)
			_failures += 1
			continue
		var was: Dictionary = before[key]
		var now: Dictionary = after[key]

		if was["kind"] == "collider":
			colliders_checked += 1
			var shape_changed: bool = was["shape"] != now["shape"]
			var offset_moved: bool = (was["offset"] as Vector3).distance_to(now["offset"] as Vector3) > EPSILON
			if shape_changed or offset_moved:
				print("  FAIL %s MOVED: %s @ %+.5f -> %s @ %+.5f" % [
					key, was["shape"], was["offset"].y, now["shape"], now["offset"].y])
				_failures += 1
			continue

		visuals_total += 1
		# The slot must actually have taken the model. A slot that silently
		# kept its placeholder would produce an unchanged AABB below and
		# could be mistaken for "the swap is harmless" when it simply never
		# happened.
		if not now["has_model"]:
			print("  FAIL %s did not install the substitute model" % key)
			_failures += 1
			continue
		# The node's OWN transform must survive: the slot is what the
		# gameplay code positions, and a model install that flattened it
		# would move the visual even though no collider changed.
		if absf((was["node_y"] as float) - (now["node_y"] as float)) > EPSILON:
			print("  FAIL %s slot moved: node_y %+.5f -> %+.5f" % [key, was["node_y"], now["node_y"]])
			_failures += 1
		if (was["size"] as Vector3).distance_to(now["size"] as Vector3) > EPSILON:
			visuals_changed += 1
		else:
			print("  FAIL %s visual did not change (%s) -- the swap had no effect" % [key, was["size"]])
			_failures += 1

	print("  %d/%d visuals swapped to the substitute's own geometry" % [visuals_changed, visuals_total])
	print("  %d colliders re-measured after the swap" % colliders_checked)
	if _failures == 0:
		print("  OK   not one collider moved")
