extends Node
## Dev-only: the ENEMY / AIR_ENEMY alarm telegraph must actually reach the
## material that is DRAWN -- including once a Meshy .glb has replaced the
## placeholder on the ModelSlot.
##
## =====================================================================
## THE DEFECT THIS EXISTS TO CATCH, AND WHY NOTHING ELSE CAUGHT IT
##
## Obstacle._ready() takes its handle on the enemy material through
## ModelSlot.slot_material(). That accessor used to return ONLY
## `get_surface_override_material(0)` -- and a surface override is a thing
## the SCENE author writes, not a thing an imported model has. Godot's
## glTF importer binds a .glb's material to the MESH SURFACE instead
## (measured, not assumed: on assets/models/keepy_stump_prop.glb,
## get_surface_override_material(0) is null while
## mesh.surface_get_material(0) is a real StandardMaterial3D).
##
## So the moment a .glb landed on EnemyMesh, slot_material() returned null,
## _enemy_material stayed null, and _apply_enemy_alarm's null-guard turned
## the whole approach telegraph into a no-op. No error, no crash, no red
## probe: the enemy simply stopped going red as it closed in, which is a
## thing only a human watching a phone would ever notice.
##
## AssetContractAudit already installs a stand-in on every slot -- but its
## stand-in used to carry a surface OVERRIDE, i.e. it was shaped like an
## imported model in its NODE STRUCTURE and not in its MATERIAL BINDING,
## which is precisely the axis the defect lives on. That is now fixed at
## the fixture (SubstituteModel.tscn binds on the mesh, like a real .glb),
## so the two probes cover different halves of the same contract: that one
## checks slot_material() returns SOMETHING, this one checks the alarm
## ramp actually moves the colour a player would see.
##
## =====================================================================
## WHAT IT ASSERTS
##
##   PHASE A -- placeholder meshes. The ramp moves every drawn surface's
##              albedo to ENEMY_ALARM_ALBEDO at t=1, and back to the
##              variant's own base colour at t=0 (a pooled Obstacle is
##              re-configured, never re-created, so the reset is as
##              load-bearing as the ramp).
##   PHASE B -- the SAME two assertions with a .glb-shaped model installed
##              on the slot. This is the phase that was red before the
##              accessor was fixed, and it is the reason this file exists.
##   PHASE C -- per-instance isolation. Alarming one obstacle must not
##              tint another. This matters MORE with a model than without:
##              a placeholder's material is a sub-resource of one scene,
##              but an imported .glb's material is a shared imported
##              RESOURCE, so every pooled instance would otherwise animate
##              the same object.
##
## =====================================================================
## WHY IT CALLS THE APPLIER RATHER THAN DRIVING AN APPROACH
##
## The defect is a WIRING fact settled in _ready(): whether the handle the
## applier needs was ever obtained. Driving a real approach would need a
## track, a player, a running clock and a lane lock in the path, none of
## which decide anything the applier does not already decide -- it would
## test more machinery and less contract. Setup still goes through the
## real public door (configure()), which is what establishes the base
## colour and the pooled-reuse reset in the first place.
##
## LIMITATION, stated rather than implied: this asserts the alarm reaches
## the drawn ALBEDO. It does not assert the emission half reaches
## anything, because on an unlit imported material it cannot -- see the
## note in Obstacle._ready().

const SUBSTITUTE: PackedScene = preload("res://scripts/dev/SubstituteModel.tscn")
const OBSTACLE: PackedScene = preload("res://scenes/Obstacle.tscn")

## Colour comparison tolerance. The ramp is a plain Color.lerp with t
## exactly 0.0 or 1.0, so the values should land dead on; this is here to
## absorb float formatting, not to soften a real drift.
const EPSILON: float = 0.001

var _failures: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "ALARM RAMP AUDIT")
	print("=== ALARM RAMP AUDIT ===")
	print("The ENEMY/AIR_ENEMY approach telegraph must reach the DRAWN material,")
	print("with a placeholder mesh AND with an imported .glb on the ModelSlot.")
	print("")
	_phase_a_placeholder()
	_phase_b_installed_model()
	_phase_c_instance_isolation()
	_report()

# =====================================================================
# PHASES
# =====================================================================

func _phase_a_placeholder() -> void:
	print("--- PHASE A: placeholder meshes (no model installed) ---")
	_assert_ramp(false, Obstacle.Type.ENEMY, "EnemyMesh")
	_assert_ramp(false, Obstacle.Type.AIR_ENEMY, "AirEnemyMesh")
	print("")

func _phase_b_installed_model() -> void:
	print("--- PHASE B: SubstituteModel.tscn installed (binds like a real .glb) ---")
	_assert_ramp(true, Obstacle.Type.ENEMY, "EnemyMesh")
	_assert_ramp(true, Obstacle.Type.AIR_ENEMY, "AirEnemyMesh")
	print("")

## One variant, one binding: base -> full alarm -> back to base, checked on
## EVERY surface the slot draws rather than on the first one. "Every" is
## the real contract: a .glb body split across several mesh instances must
## tint as one object (see ModelSlot.apply_material), and checking only
## surface 0 would pass a model that lit its torso and left its tail behind.
func _assert_ramp(with_model: bool, type: int, slot_name: String) -> void:
	var obstacle := _make_obstacle(with_model)
	var slot := obstacle.get_node(slot_name) as ModelSlot
	obstacle.configure(type, 0.0, 0.0)

	var label := "%s %s" % [_type_name(type), "with .glb" if with_model else "placeholder"]
	var surfaces := _drawn_materials(slot)
	if surfaces.is_empty():
		_fail("%s: the slot draws NO readable material at all" % label)
		obstacle.queue_free()
		return

	var base: Color = surfaces[0].albedo_color
	if _same(base, Obstacle.ENEMY_ALARM_ALBEDO):
		_fail("%s: base colour already IS the alarm colour -- this phase could not"
			% label + " tell a working ramp from a dead one")
		obstacle.queue_free()
		return

	_apply(obstacle, type, 1.0)
	var alarmed := _drawn_materials(slot)
	var all_alarmed := true
	for material in alarmed:
		if not _same(material.albedo_color, Obstacle.ENEMY_ALARM_ALBEDO):
			all_alarmed = false
	_check(all_alarmed, "%s: all %d drawn surface(s) reach the alarm colour %s"
		% [label, alarmed.size(), _rgb(Obstacle.ENEMY_ALARM_ALBEDO)],
		"got %s" % _rgb(alarmed[0].albedo_color))

	_apply(obstacle, type, 0.0)
	var reset := _drawn_materials(slot)
	var all_reset := true
	for material in reset:
		if not _same(material.albedo_color, base):
			all_reset = false
	_check(all_reset, "%s: resets to its own base %s for the next pooled spawn"
		% [label, _rgb(base)], "got %s" % _rgb(reset[0].albedo_color))

	obstacle.queue_free()

func _phase_c_instance_isolation() -> void:
	print("--- PHASE C: one alarmed instance must not tint another ---")
	var first := _make_obstacle(true)
	var second := _make_obstacle(true)
	first.configure(Obstacle.Type.ENEMY, 0.0, 0.0)
	second.configure(Obstacle.Type.ENEMY, 0.0, 0.0)

	var second_slot := second.get_node("EnemyMesh") as ModelSlot
	var before: Color = _drawn_materials(second_slot)[0].albedo_color

	_apply(first, Obstacle.Type.ENEMY, 1.0)

	var after: Color = _drawn_materials(second_slot)[0].albedo_color
	_check(_same(before, after),
		"alarming one instance left the other at %s" % _rgb(before),
		"the second instance bled to %s -- the imported material is SHARED and"
			% _rgb(after) + " was not duplicated per instance")

	first.queue_free()
	second.queue_free()
	print("")

# =====================================================================
# HELPERS
# =====================================================================

## A ready Obstacle, with the stand-in model installed on every slot when
## asked. `model_scene` is authored BEFORE add_child on purpose: ModelSlot
## installs in its own _ready(), and a child's _ready() runs before its
## parent's, so this is the only ordering under which Obstacle._ready()
## sees the model rather than the placeholder -- the same ordering
## AssetContractAudit relies on, and the same one the shipped scenes get
## for free by carrying model_scene in the .tscn.
func _make_obstacle(with_model: bool) -> Obstacle:
	var obstacle: Obstacle = OBSTACLE.instantiate()
	if with_model:
		for slot in _find_slots(obstacle):
			slot.model_scene = SUBSTITUTE
	add_child(obstacle)
	# Nothing here drives a run, but an Obstacle left processing would
	# still tick its own passage check against a world that does not exist.
	obstacle.process_mode = Node.PROCESS_MODE_DISABLED
	return obstacle

func _find_slots(node: Node) -> Array[ModelSlot]:
	var found: Array[ModelSlot] = []
	var slot := node as ModelSlot
	if slot:
		found.append(slot)
	for child in node.get_children():
		found.append_array(_find_slots(child))
	return found

## What the RENDERER will use for every surface this slot draws.
##
## Deliberately does NOT call ModelSlot.slot_material(): that accessor is
## the thing under test here, and a probe that measured the code it is
## checking would pass by construction. get_active_material() is the
## engine's own answer to "what gets drawn", so it stays true whichever way
## the material happens to be bound.
func _drawn_materials(slot: ModelSlot) -> Array[BaseMaterial3D]:
	var found: Array[BaseMaterial3D] = []
	_collect_materials(slot, found)
	return found

func _collect_materials(node: Node, into: Array[BaseMaterial3D]) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		var material := mesh_instance.get_active_material(0) as BaseMaterial3D
		if material:
			into.append(material)
	for child in node.get_children():
		_collect_materials(child, into)

## Drives the variant's own applier. Two appliers, not one, because ENEMY
## and AIR_ENEMY hold separate materials and a fix that reconnected only
## one of them must not be able to pass this probe.
func _apply(obstacle: Obstacle, type: int, t: float) -> void:
	if type == Obstacle.Type.AIR_ENEMY:
		obstacle._apply_air_enemy_tint(t)
	else:
		obstacle._apply_enemy_alarm(t)

func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < EPSILON and absf(a.g - b.g) < EPSILON and absf(a.b - b.b) < EPSILON

func _rgb(c: Color) -> String:
	return "rgb(%.2f, %.2f, %.2f)" % [c.r, c.g, c.b]

func _check(ok: bool, ok_text: String, fail_text: String) -> void:
	if ok:
		print("  OK   %s" % ok_text)
	else:
		_fail("%s -- %s" % [ok_text, fail_text])

func _fail(text: String) -> void:
	_failures += 1
	print("  FAIL %s" % text)

func _report() -> void:
	if _failures > 0:
		push_error("ALARM RAMP AUDIT FAILED: %d check(s) did not hold." % _failures)
		get_tree().quit(1)
		return
	print("PASSED: the alarm telegraph reaches every drawn surface with a placeholder")
	print("        AND with an imported model, resets for the next pooled spawn, and")
	print("        stays per-instance.")
	get_tree().quit(0)

func _type_name(type: int) -> String:
	match type:
		Obstacle.Type.ENEMY: return "ENEMY"
		Obstacle.Type.AIR_ENEMY: return "AIR_ENEMY"
		_: return "TYPE_%d" % type
