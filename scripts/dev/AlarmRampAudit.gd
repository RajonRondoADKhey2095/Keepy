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
## THE TWO TYPES ARE NOW ASSERTED DIFFERENTLY -- READ THIS BEFORE EDITING
##
## Until 2026-08-13 both types lerped toward ONE shared constant and this
## file asserted one contract twice. They no longer do: ENEMY's alarm
## albedo is deliberately EQUAL to the rat's resting colour, so its colour
## telegraph is intentionally silent (Mathieu's explicit call -- see
## Obstacle.ENEMY_ALARM_ALBEDO). AIR_ENEMY still ramps, now to its own
## light green.
##
## That broke this file in a way worth naming, because it is the exact
## trap this repo keeps re-learning: _assert_ramp opened with a guard that
## FAILED when base == the alarm colour ("this phase could not tell a
## working ramp from a dead one"). That guard was right for the old
## contract and became a guaranteed red under the new one. It was rewritten
## BEFORE the constant moved, the same way ChargerShapeProbe was rewritten
## before the boar landed -- not chased afterwards.
##
## ⚠️ AND THE GUARD'S POINT STILL STANDS. On ENEMY, a DEAD ramp (the
## slot_material() null this file exists to catch) and a DELIBERATELY
## SILENT one are now indistinguishable by colour -- which is precisely
## why colour is no longer the only thing checked on that type. The
## silent-ENEMY assertion pairs a colour check with a WIRING check: the
## material handle Obstacle._ready() obtained must be non-null. That is
## the original defect, restated in the one form that survives the type
## having no colour left to move. Delete that half and this file stops
## covering the bug it was written for.
##
## =====================================================================
## WHAT IT ASSERTS
##
##   PHASE A -- placeholder meshes.
##              AIR_ENEMY: the ramp moves every drawn surface's albedo to
##              AIR_ENEMY_ALARM_ALBEDO at t=1, and back to the variant's own
##              base colour at t=0 (a pooled Obstacle is re-configured,
##              never re-created, so the reset is as load-bearing as the
##              ramp).
##              ENEMY: the handle exists, the constant still matches the
##              shipped resting colour, and the drawn albedo does not move
##              between t=0 and t=1.
##   PHASE B -- the SAME assertions with a .glb-shaped model installed on
##              the slot. This is the phase that was red before the accessor
##              was fixed, and it is the reason this file exists. BOTH types
##              take the live-ramp contract here: the stand-in's base is its
##              own debug magenta, not the rat's colour, so ENEMY's ramp
##              does move against it -- which is what makes this phase still
##              able to prove the binding resolved for a type that is silent
##              in production.
##   PHASE C -- per-instance isolation. Alarming one obstacle must not
##              tint another. This matters MORE with a model than without:
##              a placeholder's material is a sub-resource of one scene,
##              but an imported .glb's material is a shared imported
##              RESOURCE, so every pooled instance would otherwise animate
##              the same object.
##   PHASE D -- AS SHIPPED. The same two assertions again, on Obstacle.tscn
##              exactly as authored, with no fixture of any kind.
##
## =====================================================================
## WHY PHASE D EXISTS ON TOP OF PHASE B, WHICH ALREADY "COVERS THE .glb CASE"
##
## Because PHASE B does not measure a .glb. It measures
## SubstituteModel.tscn, a stand-in built to LOOK like one -- and this
## whole file exists because a fixture that matched reality on every axis
## but one hid a real defect for as long as it was the only thing looked
## at. Repeating that shape at one remove ("the stand-in binds like a real
## asset, so a real asset must behave like the stand-in") would be the same
## mistake wearing the fix's clothes.
##
## What PHASE D adds that no fixture can: the real asset's real material,
## produced by Godot's own glTF importer from the real bytes on disk. Every
## step between the .glb and the drawn albedo is exercised -- import
## settings, the importer's choice of material class (the cast in
## Obstacle._ready() is only true while that class stays StandardMaterial3D),
## the binding route, and the duplicate-per-instance. The first hazard to
## land on one of these two slots was the rat, and PHASE D is what makes
## "the telegraph still works on it" a measurement instead of an inference.
##
## PHASE A had to change with it. It used to get the placeholder for free,
## because no enemy slot carried a model; the moment one did, "placeholder
## meshes (no model installed)" would have quietly become a second reading
## of the shipped asset under a label saying otherwise. It now CLEARS
## model_scene explicitly, so the fallback path is still covered and the
## label is true by construction rather than by luck.
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

## Which of the three states an Obstacle is built in. Named rather than a
## bool: "with_model true/false" could not express the difference between
## "a fixture standing in for an asset" and "whatever actually ships", and
## that difference is the entire point of PHASE D.
const FIXTURE_NONE: int = 0        # model_scene cleared -- the fallback path
const FIXTURE_SUBSTITUTE: int = 1  # SubstituteModel.tscn -- .glb-shaped stand-in
const FIXTURE_SHIPPED: int = 2     # Obstacle.tscn untouched -- the real thing

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
	_phase_d_as_shipped()
	_report()

# =====================================================================
# PHASES
# =====================================================================

func _phase_a_placeholder() -> void:
	print("--- PHASE A: placeholder meshes (model_scene cleared on every slot) ---")
	_assert_ramp(FIXTURE_NONE, Obstacle.Type.ENEMY, "EnemyMesh")
	_assert_ramp(FIXTURE_NONE, Obstacle.Type.AIR_ENEMY, "AirEnemyMesh")
	print("")

func _phase_b_installed_model() -> void:
	print("--- PHASE B: SubstituteModel.tscn installed (binds like a real .glb) ---")
	_assert_ramp(FIXTURE_SUBSTITUTE, Obstacle.Type.ENEMY, "EnemyMesh")
	_assert_ramp(FIXTURE_SUBSTITUTE, Obstacle.Type.AIR_ENEMY, "AirEnemyMesh")
	print("")

## The only phase whose result says anything about what a player will see:
## no stand-in, no cleared slot, just Obstacle.tscn as it ships.
##
## It prints [glb] / [-- ] per slot rather than asserting that either one is
## installed. Which slots carry an asset is an art-pipeline fact that changes
## batch to batch; that the telegraph reaches whatever IS there is the
## contract, and it has to hold in both states. The marker is what stops this
## phase from silently degrading into a second copy of PHASE A on the day a
## slot's model_scene is cleared.
func _phase_d_as_shipped() -> void:
	print("--- PHASE D: Obstacle.tscn AS SHIPPED (real assets, no fixture) ---")
	_assert_ramp(FIXTURE_SHIPPED, Obstacle.Type.ENEMY, "EnemyMesh")
	_assert_ramp(FIXTURE_SHIPPED, Obstacle.Type.AIR_ENEMY, "AirEnemyMesh")
	print("")

## The alarm colour each type ramps toward. One constant per type since
## 2026-08-13 -- reading the wrong one here would let a type pass against
## its neighbour's target, which is exactly the coupling that was removed.
func _alarm_target(type: int) -> Color:
	return Obstacle.AIR_ENEMY_ALARM_ALBEDO if type == Obstacle.Type.AIR_ENEMY \
		else Obstacle.ENEMY_ALARM_ALBEDO

## Routes each type to the contract it actually has. Kept as one entry point
## so every phase covers both types without each phase having to know which
## of them currently telegraphs in colour -- that is a product decision, and
## it has already flipped once.
##
## ⚠️ ENEMY IS SILENT ONLY WHERE THE BASE COLOUR IS THE RAT'S. On
## FIXTURE_SUBSTITUTE the base is the stand-in's debug magenta, which has
## nothing to do with the shipped asset -- so the ramp there DOES move, and
## asserting silence would be asserting a property of the fixture instead of
## a property of the game. It takes the LIVE contract there, and that is a
## gain rather than a concession: PHASE B is the wiring test, and a type
## whose colour cannot move in production has nowhere else left to prove
## through COLOUR MOVEMENT that a .glb-shaped binding resolved at all.
## PHASE A and PHASE D, where the base really is the rat's colour (the
## placeholder is authored to it and the .glb decodes to it exactly), assert
## the silence that ships.
func _assert_ramp(fixture: int, type: int, slot_name: String) -> void:
	if type == Obstacle.Type.ENEMY and fixture != FIXTURE_SUBSTITUTE:
		_assert_silent_ramp(fixture, type, slot_name)
	else:
		_assert_live_ramp(fixture, type, slot_name)

## A type that DOES telegraph in colour: base -> full alarm -> back to base,
## checked on EVERY surface the slot draws rather than on the first one.
## "Every" is the real contract: a .glb body split across several mesh
## instances must tint as one object (see ModelSlot.apply_material), and
## checking only surface 0 would pass a model that lit its torso and left
## its tail behind.
func _assert_live_ramp(fixture: int, type: int, slot_name: String) -> void:
	var obstacle := _make_obstacle(fixture)
	var slot := obstacle.get_node(slot_name) as ModelSlot
	obstacle.configure(type, 0.0, 0.0)

	var label := "%s %s" % [_type_name(type), _fixture_label(fixture, slot)]
	var surfaces := _drawn_materials(slot)
	if surfaces.is_empty():
		_fail("%s: the slot draws NO readable material at all" % label)
		obstacle.queue_free()
		return

	var target := _alarm_target(type)
	var base: Color = surfaces[0].albedo_color
	if _same(base, target):
		_fail("%s: base colour already IS the alarm colour -- this phase could not"
			% label + " tell a working ramp from a dead one")
		obstacle.queue_free()
		return

	_apply(obstacle, type, 1.0)
	var alarmed := _drawn_materials(slot)
	var all_alarmed := true
	for material in alarmed:
		if not _same(material.albedo_color, target):
			all_alarmed = false
	_check(all_alarmed, "%s: all %d drawn surface(s) reach the alarm colour %s"
		% [label, alarmed.size(), _rgb(target)],
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

## A type whose colour telegraph is DELIBERATELY silent (ENEMY, since
## 2026-08-13). Three checks, and each one covers something the other two
## cannot:
##
##   1. THE HANDLE EXISTS. This is the original defect of this whole file
##      (slot_material() returning null once a .glb landed), and on a type
##      with no colour left to move it is the ONLY way that defect is still
##      visible. Without it, silencing ENEMY would have silently deleted
##      this probe's coverage of its own reason for existing.
##   2. THE CONSTANT STILL MATCHES THE SHIPPED RESTING COLOUR. The silence
##      is not a property of the code -- it is the coincidence that
##      ENEMY_ALARM_ALBEDO equals whatever the slot ships with. Recolour the
##      rat without moving the constant and the ramp quietly comes back to
##      life, aimed at a stale colour. That is the one failure mode this
##      arrangement can produce, and this is the check that catches it.
##   3. THE DRAWN ALBEDO DOES NOT MOVE between t=0 and t=1, on every drawn
##      surface -- the decision itself, asserted on what the renderer uses
##      rather than inferred from (2).
func _assert_silent_ramp(fixture: int, type: int, slot_name: String) -> void:
	var obstacle := _make_obstacle(fixture)
	var slot := obstacle.get_node(slot_name) as ModelSlot
	obstacle.configure(type, 0.0, 0.0)

	var label := "%s %s" % [_type_name(type), _fixture_label(fixture, slot)]
	var surfaces := _drawn_materials(slot)
	if surfaces.is_empty():
		_fail("%s: the slot draws NO readable material at all" % label)
		obstacle.queue_free()
		return

	_check(obstacle.get("_enemy_material") != null,
		"%s: the applier's material handle was obtained (wiring intact)" % label,
		"_enemy_material is null -- slot_material() failed to resolve the binding,"
			+ " which a silent type can no longer show through its colour")

	var base: Color = surfaces[0].albedo_color
	_check(_same(base, Obstacle.ENEMY_ALARM_ALBEDO),
		"%s: alarm constant still equals the shipped resting colour %s" % [label, _rgb(base)],
		"base is %s but ENEMY_ALARM_ALBEDO is %s -- the rat was recoloured without"
			% [_rgb(base), _rgb(Obstacle.ENEMY_ALARM_ALBEDO)]
			+ " moving the constant, so the telegraph is live again toward a stale colour")

	_apply(obstacle, type, 1.0)
	var alarmed := _drawn_materials(slot)
	var all_still := true
	for material in alarmed:
		if not _same(material.albedo_color, base):
			all_still = false
	_check(all_still,
		"%s: all %d drawn surface(s) stay at %s at full alarm (silent by design)"
			% [label, alarmed.size(), _rgb(base)],
		"moved to %s" % _rgb(alarmed[0].albedo_color))

	obstacle.queue_free()

## ⚠️ THIS PHASE RUNS ON AIR_ENEMY, AND SWITCHING IT THERE WAS NOT
## COSMETIC. It used to use ENEMY. The moment ENEMY's ramp became a
## deliberate identity, "alarming one instance left the other unchanged"
## became true for free on that type -- the first instance does not change
## either, so nothing could bleed and the check could never fail whatever
## the material sharing did. A green phase measuring nothing is worse than
## no phase, because it reads as coverage. AIR_ENEMY still moves its
## albedo, so the assertion still has something to detect.
func _phase_c_instance_isolation() -> void:
	print("--- PHASE C: one alarmed instance must not tint another (AIR_ENEMY: the type that still moves) ---")
	var first := _make_obstacle(FIXTURE_SUBSTITUTE)
	var second := _make_obstacle(FIXTURE_SUBSTITUTE)
	first.configure(Obstacle.Type.AIR_ENEMY, 0.0, 0.0)
	second.configure(Obstacle.Type.AIR_ENEMY, 0.0, 0.0)

	var second_slot := second.get_node("AirEnemyMesh") as ModelSlot
	var before: Color = _drawn_materials(second_slot)[0].albedo_color

	_apply(first, Obstacle.Type.AIR_ENEMY, 1.0)

	# Guards the guard: if the driven instance did not move either, this
	# phase proved nothing and must say so rather than print a pass.
	var first_slot := first.get_node("AirEnemyMesh") as ModelSlot
	var driven: Color = _drawn_materials(first_slot)[0].albedo_color
	_check(not _same(driven, before),
		"the driven instance actually moved to %s (so this phase can detect a bleed)" % _rgb(driven),
		"the driven instance stayed at %s -- nothing was exercised, this phase is vacuous"
			% _rgb(driven))

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

## A ready Obstacle in one of the three fixture states.
##
## `model_scene` is written BEFORE add_child on purpose: ModelSlot installs in
## its own _ready(), and a child's _ready() runs before its parent's, so this
## is the only ordering under which Obstacle._ready() sees the state this
## function asked for -- the same ordering AssetContractAudit relies on, and
## the same one the shipped scenes get for free by carrying model_scene in the
## .tscn.
##
## FIXTURE_NONE writes null rather than doing nothing. Doing nothing was
## correct only while no enemy slot shipped an asset; it would now hand back
## the shipped rat under a label that says "placeholder".
func _make_obstacle(fixture: int) -> Obstacle:
	var obstacle: Obstacle = OBSTACLE.instantiate()
	if fixture != FIXTURE_SHIPPED:
		for slot in _find_slots(obstacle):
			slot.model_scene = SUBSTITUTE if fixture == FIXTURE_SUBSTITUTE else null
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

## What state this measurement was taken in, said in the output rather than
## left to the phase header -- a line copied out of a log has to carry its own
## meaning. In the shipped state the marker is READ OFF THE SLOT
## (`has_model()`), never assumed from the phase, so the day an asset is added
## to or removed from a slot the log says so on its own.
func _fixture_label(fixture: int, slot: ModelSlot) -> String:
	match fixture:
		FIXTURE_NONE: return "placeholder"
		FIXTURE_SUBSTITUTE: return "with stand-in"
		_: return "as shipped [glb]" if slot.has_model() else "as shipped [-- ]"

func _type_name(type: int) -> String:
	match type:
		Obstacle.Type.ENEMY: return "ENEMY"
		Obstacle.Type.AIR_ENEMY: return "AIR_ENEMY"
		_: return "TYPE_%d" % type
