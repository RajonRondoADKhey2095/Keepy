extends Node
## Dev-only contract check for HubActorWalker -- the generic ground actor
## the hub's bear is the first user of.
##
## =====================================================================
## WHY THIS IS GATED RATHER THAN REPORTED
##
## Every way this script can fail fails SILENTLY. A model_scene left
## unset draws nothing; an AnimationPlayer not found leaves a statue; an
## arrival that stops an epsilon short leaves the actor visibly off its
## mark; a frozen pose that keeps advancing reads as a walk in place. None
## of them raise, none of them break a build, and all of them look from
## the outside like "the actor was never wired up".
##
## Two of them are worse than silent, because they leak OUT of the actor:
##
##   - the glTF importer binds ONE shared material on the mesh, so
##     forcing UNSHADED through it would tint every instance of that glb
##     in the project. HubActorWalker duplicates first. If that
##     duplication is ever dropped, nothing here goes red -- the BEAR
##     still draws correctly, and the damage lands on whatever else uses
##     the same asset.
##
##   - `instantiate()` copies nodes, not the Animations they point at, so
##     making the shipped clip loop writes that on the SHARED resource.
##     Same shape, one resource type over.
##
## Both are therefore asserted from BOTH sides: the drawn surface must be
## unshaded AND the mesh's own material must still be lit; the played clip
## must loop AND the glb's own clip must still be authored not to.
##
## =====================================================================
## WHAT IS DELIBERATELY REPORTED AND NOT GATED
##
## `walk_speed`. Its value is derived from the shipped clip's stance
## phase -- the speed at which a PLANTED foot travels backwards, which is
## the only speed at which a foot does not skate -- and the full
## measurement table lives on the export in HubActorWalker.gd. Re-deriving
## it here would mean re-implementing the stance-window fit, and a gate
## whose threshold logic differs from the original's by a frame or two
## would fail on correct code. The number is printed instead, so a
## re-export that changes the cadence is at least visible next to it.

const WALKER := preload("res://scripts/hub/HubActorWalker.gd")
const BEAR: PackedScene = preload("res://assets/models/keepy_bear_walker.glb")
## Lot B's measured scale -- off Skeleton3D.get_bone_global_pose(), not an
## AABB. See BearAnimSpike.gd for why an AABB reads a hundredfold low.
const BEAR_SCALE: float = 1.130876
## Far enough that the walk is unmistakably a walk, short enough that the
## probe is not mostly waiting: ~2.8 s at the shipped speed.
##
## ⚠️ DELIBERATELY OFF-AXIS. Straight down +Z the wanted yaw is zero, so
## an actor that never turns at all satisfies the facing check for free.
const TARGET := Vector3(1.5, 0.0, 1.5)
## Wall clock, not a frame count: the actor moves in metres per second, so
## a frame budget would mean something different on every machine.
const WALK_BUDGET_S: float = 20.0
## Long enough that a clip left playing would have moved visibly.
const FREEZE_FRAMES: int = 12

var _failures: int = 0


func _ready() -> void:
	# FIRST statement. A watchdog armed after the hang is no watchdog.
	ProbeWatchdog.arm(self, "ActorWalkerProbe")
	print("=== ACTOR WALKER PROBE ===")
	print("")

	var walker: Node3D = _make_walker()
	add_child(walker)
	await get_tree().process_frame

	_phase_a(walker)
	print("")
	await _phase_b(walker)
	print("")
	# ⚠️ AWAITED, NOT CALLED BARE. `_phase_c` contains an await, which makes
	# it a coroutine: calling it without `await` runs it CONCURRENTLY with
	# what follows, and the tree quits before its assertions ever print --
	# a green run with a whole phase silently missing. This probe shipped
	# that way for exactly one run. Same trap CLAUDE.md already records for
	# DivingBoardProbe and the hub sondes.
	await _phase_c(walker)
	print("")
	await _phase_d()

	print("")
	if _failures == 0:
		print("PASSED: the actor draws unshaded, walks, arrives on its mark and holds still.")
		get_tree().quit(0)
	else:
		push_error("ACTOR WALKER PROBE FAILED: %d check(s)." % _failures)
		get_tree().quit(1)


func _make_walker() -> Node3D:
	var w: Node3D = WALKER.new()
	w.model_scene = BEAR
	w.model_scale = BEAR_SCALE
	return w


# =====================================================================
# PHASE A -- the rig is there, and it is UNSHADED without borrowing a
# light that the hub does not have. Measured, zero Light3D nodes in
# HubWorld.tscn; only an unshaded surface has a known colour there.
func _phase_a(walker: Node3D) -> void:
	print("--- PHASE A: the drawn rig ---")

	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(walker, meshes)
	_ok(meshes.size() == 1, "the rig draws exactly one MeshInstance3D (%d)" % meshes.size())
	if meshes.is_empty():
		return

	var player: AnimationPlayer = _find_player(walker)
	_ok(player != null, "an AnimationPlayer was found on the rig")

	for mi in meshes:
		for surf in mi.mesh.get_surface_count():
			var drawn: Material = mi.get_surface_override_material(surf)
			var own: Material = mi.mesh.surface_get_material(surf)
			# What the surface actually DRAWS -- never the constant the
			# walker was asked to write. The distinction is the whole
			# reason AlarmRampAudit exists.
			_ok(drawn is BaseMaterial3D
					and (drawn as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
				"%s surface %d DRAWS unshaded" % [mi.name, surf])
			# The blind half. Without it, "the drawn surface is unshaded"
			# passes just as well when the walker mutated the shared
			# resource instead of duplicating it.
			_ok(own is BaseMaterial3D
					and (own as BaseMaterial3D).shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED,
				"and the mesh's OWN shared material is untouched (still lit)")
			_ok(drawn != null and drawn != own,
				"-- the override is a duplicate, not the shared resource")

	print("    walk_speed on this actor: %.4f u/s (reported, not gated -- see header)."
		% (walker.get("walk_speed") as float))


# =====================================================================
# PHASE B -- it walks, it turns onto its heading, and it lands ON the
# mark rather than an epsilon short of it.
func _phase_b(walker: Node3D) -> void:
	print("--- PHASE B: the walk ---")

	var player: AnimationPlayer = _find_player(walker)
	var start: Vector3 = walker.global_position
	var yaw_before: float = walker.rotation.y

	var arrivals: Array[int] = [0]
	walker.arrived.connect(func() -> void: arrivals[0] += 1)

	walker.walk_to(TARGET)
	_ok(walker.is_walking(), "walk_to() put it in WALKING")

	# The clip has to be running for the frozen-pose check later to mean
	# anything: "it did not advance" passes for free against a player
	# that was never started.
	await get_tree().process_frame
	await get_tree().process_frame
	var mid_pos: float = player.current_animation_position if player != null else 0.0
	_ok(mid_pos > 0.0, "BLIND CHECK: the clip is genuinely advancing while walking (%.4f s)" % mid_pos)

	var t0: int = Time.get_ticks_msec()
	while walker.is_walking() and Time.get_ticks_msec() - t0 < int(WALK_BUDGET_S * 1000.0):
		await get_tree().process_frame
	var took: float = float(Time.get_ticks_msec() - t0) / 1000.0

	_ok(not walker.is_walking(), "it finished walking in %.2f s (budget %.0f s)" % [took, WALK_BUDGET_S])
	_ok(arrivals[0] == 1, "`arrived` fired exactly once (%d)" % arrivals[0])

	var here := Vector2(walker.global_position.x, walker.global_position.z)
	var want := Vector2(TARGET.x, TARGET.z)
	_ok(here.distance_to(want) < 1.0e-4,
		"it landed ON the mark, not near it (%.6f u off)" % here.distance_to(want))
	_ok(start.distance_to(walker.global_position) > 0.5,
		"BLIND CHECK: it actually travelled (%.3f u)" % start.distance_to(walker.global_position))
	var wanted: float = atan2(TARGET.x - start.x, TARGET.z - start.z)
	_ok(absf(walker.rotation.y - wanted) < 0.01,
		"it is facing its heading (yaw %.3f rad, wanted %.3f)" % [walker.rotation.y, wanted])
	_ok(absf(wanted - yaw_before) > 0.1 and absf(walker.rotation.y - yaw_before) > 0.1,
		"BLIND CHECK: that heading was NOT the yaw it started at (%.3f rad)" % yaw_before)


# =====================================================================
# PHASE C -- ARRIVED is a held pose, not a walk in place.
func _phase_c(walker: Node3D) -> void:
	print("--- PHASE C: the frozen pose ---")
	var player: AnimationPlayer = _find_player(walker)
	if player == null:
		_ok(false, "an AnimationPlayer was found")
		return

	var at_arrival: float = player.current_animation_position
	for _i in FREEZE_FRAMES:
		await get_tree().process_frame
	var later: float = player.current_animation_position
	_ok(absf(later - at_arrival) < 1.0e-4,
		"the pose does not advance over %d frames (%.4f -> %.4f s)" % [FREEZE_FRAMES, at_arrival, later])

	# The per-instance clip, from both sides. `actor/walk` is the walker's
	# own duplicate; `Walking` is the glb's, and it must still carry the
	# loop_mode it was authored with.
	_ok(player.has_animation(&"actor/walk"), "the actor plays its OWN duplicated clip")
	if player.has_animation(&"actor/walk"):
		_ok(player.get_animation(&"actor/walk").loop_mode == Animation.LOOP_LINEAR,
			"and that duplicate is the one made to loop")
	if player.has_animation(&"Walking"):
		_ok(player.get_animation(&"Walking").loop_mode == Animation.LOOP_NONE,
			"BLIND CHECK: the glb's own `Walking` clip is untouched (loop_mode NONE)")


# =====================================================================
# PHASE D -- a zero-length walk still arrives. The cabin's hotspots had
# to learn this one the hard way: a caller that asks for a walk it is
# already at must be told the walk is over, not left on a signal a
# zero-length trip would never emit.
func _phase_d() -> void:
	print("--- PHASE D: the zero-length walk ---")
	var w: Node3D = _make_walker()
	w.position = Vector3(5.0, 0.0, -3.0)
	add_child(w)
	await get_tree().process_frame

	var arrivals: Array[int] = [0]
	w.arrived.connect(func() -> void: arrivals[0] += 1)
	w.walk_to(w.global_position)
	_ok(arrivals[0] == 1, "asking for a walk it is already at arrives at once (%d)" % arrivals[0])
	_ok(not w.is_walking(), "and does not leave it stuck in WALKING")


# =====================================================================
func _ok(cond: bool, what: String) -> void:
	if cond:
		print("    OK  : %s." % what)
	else:
		print("    FAIL: %s." % what)
		_failures += 1


func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		_collect_meshes(c, out)


func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var found: AnimationPlayer = _find_player(c)
		if found != null:
			return found
	return null
