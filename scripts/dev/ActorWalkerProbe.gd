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
const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")
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
	# ⚠️ THE HUB IS HANDED ON RATHER THAN REBUILT. PHASE F picks up exactly
	# where E leaves off -- both riders seated on a settled plank -- because
	# the whole claim of lot E is that THAT state persists. Standing a
	# second hub up and re-mounting into it would test a fresh mount and
	# call it persistence.
	var ctx: Dictionary = await _phase_e()
	print("")
	await _phase_f(ctx)

	print("")
	if _failures == 0:
		print("PASSED: the actor draws unshaded, walks, arrives, holds still, rides the plank and holds the seat.")
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
# PHASE E -- THE SECOND RIDER. The hub's bear walks to the far end of the
# plank Keepy sat on, is carried BY the plank while it rocks, and steps off
# on the same beat he does.
#
# Everything here fails silently. A bear that never mounts is a bear
# standing beside a seesaw, which is exactly what it looked like BEFORE the
# feature existed; a bear written on its own callback is a bear a frame
# behind, which reads as a wobble; a bear left seated after the dismount is
# a bear floating over a settled plank. None raise.
#
# ⚠️ DRIVEN THROUGH THE SHIPPED HUB, never a fixture. The whole claim is
# about WHERE the write happens, and a stand-in with its own tilt loop
# would answer a question nobody asked.
func _phase_e() -> Dictionary:
	print("--- PHASE E: the second rider ---")
	var hub: Node = HUB_SCENE.instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var props: Node3D = hub.get_node("WorldViewport/SubViewport/World/Props")
	var keepy: Node3D = hub.get_node("WorldViewport/SubViewport/World/Keepy")
	var world: Node3D = hub.get_node("WorldViewport/SubViewport/World")
	var bear: Node3D = null
	for c in world.get_children():
		if c.get_script() == WALKER:
			bear = c as Node3D
			break
	_ok(bear != null, "the hub built an actor walker beside Keepy (the bear)")
	if bear == null:
		hub.queue_free()
		return {}

	var reg: Array = props.seesaws()
	_ok(not reg.is_empty(), "the layout carries a seesaw to ride")
	if reg.is_empty():
		hub.queue_free()
		return {}
	var entry: Dictionary = reg[0]
	var pivot: Node3D = entry["pivot"]
	var ride_x: float = float(entry["ride_x"])
	var seat_y: float = float(entry["seat_y"])
	var rock_s: float = float(hub.get_script().get_script_constant_map().get("SEESAW_ROCK_S", 2.4))

	var bear_start: Vector3 = bear.global_position
	_ok(bear.global_position.y < 0.01, "and it starts on the ground (y = %.4f)" % bear.global_position.y)

	# A landing on one end -- the same signal an ordinary hop emits.
	var arrive: Vector3 = (entry["position"] as Vector3) + Vector3(-ride_x, 0.0, -0.4)
	keepy.global_position = Vector3(arrive.x, 0.0, arrive.z)
	keepy.hop_landed.emit(keepy.global_position)
	await get_tree().process_frame
	_ok(keepy.is_on_seesaw(), "a landing put Keepy on the plank")
	_ok(bear.is_walking(), "and the mount sent the bear walking (it did not just stand there)")

	# It has to get there WHILE the rock is still going -- the whole point
	# of lot D's timing fix. Budgeted against the rock, not against a
	# comfortable constant, so a slower walk fails here rather than on eyes.
	# ⚠️ BUDGETED IN FRAMES AND NOT IN WALL CLOCK. Everything under test
	# here advances on `delta`, and under `--fixed-fps 60` that delta is
	# 1/60 however long the software rasteriser actually takes -- so a wall
	# clock measures the sandbox, not the walk. The first draft did, and
	# reported 2.41 s for a trip that had simulated 0.77 s of one.
	var frames: int = 0
	var budget: int = int(rock_s * 60.0)
	while bear.is_walking() and frames < budget:
		await get_tree().process_frame
		frames += 1
	var walked: float = float(frames) / 60.0
	_ok(not bear.is_walking(), "it arrived in %.2f s of game time, inside the %.1f s rock"
		% [walked, rock_s])
	_ok(bear.global_position.distance_to(bear_start) > 0.5,
		"BLIND CHECK: it really travelled (%.3f u)" % bear.global_position.distance_to(bear_start))

	# ON the plank, at the OTHER end.
	var seat_local: Vector3 = pivot.to_local(bear.global_position)
	var keepy_local: Vector3 = pivot.to_local(keepy.global_position)
	_ok(bear.global_position.y > 0.2,
		"it is UP on the plank, not beside it (y = %.4f)" % bear.global_position.y)
	_ok(signf(seat_local.x) == -signf(keepy_local.x) and absf(seat_local.x) > 0.1,
		"and on the OPPOSITE end from Keepy (bear x = %.3f, Keepy x = %.3f)"
			% [seat_local.x, keepy_local.x])

	# ⚠️ THE PROOF THAT IT IS WRITTEN IN `_apply_tilt` AND NOWHERE ELSE.
	# HubActorWalker calls set_process(false) when it arrives, so while it
	# is seated it has no callback of its own at all: the only thing that
	# can be moving it is the tilt call. A rider with its own _process is
	# the measured turnstile defect, and this is the one observable that
	# separates the two without reaching into private state.
	_ok(not bear.is_processing(),
		"the bear runs NO _process while seated -- only _apply_tilt can move it")

	# CARRIED, against the FIXED seat and never against a round trip of its
	# own position (that is the identity, and stays green with the rider
	# write removed -- SeesawProbe records paying for exactly that).
	var seat := Vector3(signf(seat_local.x) * ride_x, seat_y, 0.0)
	var worst: float = 0.0
	var angles: Array[float] = []
	var faced: float = 0.0
	for _i in 20:
		await get_tree().process_frame
		if not is_instance_valid(pivot):
			break
		angles.append(pivot.rotation_degrees.z)
		worst = maxf(worst, bear.global_position.distance_to(pivot.to_global(seat)))
		var to_keepy: Vector3 = keepy.global_position - bear.global_position
		faced = maxf(faced, absf(angle_difference(bear.rotation.y, atan2(to_keepy.x, to_keepy.z))))
	var swing: float = (angles.max() - angles.min()) if not angles.is_empty() else 0.0
	_ok(swing > 1.0,
		"BLIND CHECK: the plank really moved under it while sampling (%.2f deg swing)" % swing)
	_ok(worst < 1.0e-4, "it stays exactly on its seat through the tilt (%.7f u worst)" % worst)
	_ok(faced < 0.05, "and keeps facing Keepy across the plank (%.4f rad worst)" % faced)

	# A RE-TAP MID-RIDE. _repump_seesaw kills the tween and builds a fresh
	# one; Tween.kill() emits no `finished`, so no stray dismount fires --
	# and the bear must still be aboard and still tracking afterwards.
	keepy.hop_landed.emit(keepy.global_position)
	await get_tree().process_frame
	await get_tree().process_frame
	var after_repump: float = bear.global_position.distance_to(pivot.to_global(seat))
	_ok(bear.global_position.y > 0.2 and after_repump < 1.0e-4,
		"a re-tap mid-ride leaves it aboard and still tracking (%.7f u)" % after_repump)

	# ⚠️ REWRITTEN 2 SEPTEMBRE 2026 (lot E), NOT DROPPED. This block used to
	# wait the rock out and assert "the rock settled and Keepy stepped off",
	# then that the bear was back on the ground beside the plank. Neither
	# went stale: the settle was DELIBERATELY stripped of the dismount, so
	# both are now false here and both are asserted in PHASE F instead, off
	# the tap that does end the ride.
	#
	# What the settle owes is the opposite claim, and it is asserted here:
	# nothing lets either rider go on its own.
	var off: int = 0
	var off_budget: int = int((rock_s * 2.0 + 2.0) * 60.0)
	while off < off_budget:
		await get_tree().process_frame
		off += 1
	_ok(keepy.is_on_seesaw(), "two rock-lengths later Keepy is STILL on the plank")
	_ok(bear.global_position.y > 0.2,
		"and so is the bear (y = %.4f), so the settle lets nobody go" % bear.global_position.y)
	_ok(absf(pivot.rotation_degrees.z) < 0.01,
		"with the plank left LEVEL under them (%.4f deg)" % pivot.rotation_degrees.z)

	return {
		"hub": hub,
		"keepy": keepy,
		"bear": bear,
		"entry": entry,
		"pivot": pivot,
		"seat": seat,
		"rock_s": rock_s,
	}


# =====================================================================
# PHASE F -- THE HELD SEAT. Lot E's three claims, on the hub PHASE E left
# seated: the seat survives the rock, a tap on the prop re-arms it without
# re-mounting anyone, and a tap anywhere else is the exit -- with the bear
# walking home behind it.
#
# Gated for the same reason as everything else here: each failure is
# silent. A seat that quietly times out looks like the old behaviour; a
# re-tap that re-mounts looks like a re-tap that worked, right up to the
# bear re-walking its approach; an exit that drops the tap leaves a body
# with no way off a plank and nothing in the log to say so.
func _phase_f(ctx: Dictionary) -> void:
	print("--- PHASE F: the seat is held, the tap is the exit ---")
	if ctx.is_empty():
		_ok(false, "PHASE E left no hub to continue from")
		return
	var hub: Node = ctx["hub"]
	var keepy: Node3D = ctx["keepy"]
	var bear: Node3D = ctx["bear"]
	var entry: Dictionary = ctx["entry"]
	var pivot: Node3D = ctx["pivot"]
	var seat: Vector3 = ctx["seat"]
	var rock_s: float = float(ctx["rock_s"])
	var pos: Vector3 = entry["position"]
	var radius: float = float(entry["radius"])

	if not keepy.is_on_seesaw():
		_ok(false, "PHASE E did not leave him aboard, so there is no held seat to test")
		hub.queue_free()
		await get_tree().process_frame
		return

	# --- 1. RE-TAP RE-ARMS IT, AT REST ---------------------------------
	# The heart of requirement 2, and the reason it could not work before:
	# the settle used to clear the ride record, so there was nothing left
	# for `_repump_seesaw` to find. Asserted on the plank MOVING again from
	# a standstill, not on a tween object -- SeesawProbe already gates the
	# tween identity, and this phase's question is whether a motionless
	# plank answers a tap at all.
	var bear_seated: Vector3 = bear.global_position
	var settled: float = pivot.rotation_degrees.z
	hub.call("_on_tapped_ground", pos)
	var swing: float = 0.0
	var carried: float = 0.0
	for _i in 20:
		await get_tree().process_frame
		if not is_instance_valid(pivot):
			break
		swing = maxf(swing, absf(pivot.rotation_degrees.z - settled))
		carried = maxf(carried, bear.global_position.distance_to(pivot.to_global(seat)))
	_ok(swing > 1.0, "a tap on the prop re-arms a STANDING-STILL plank (%.2f deg of new swing)" % swing)
	_ok(keepy.is_on_seesaw(), "and leaves Keepy aboard rather than re-seating him")
	_ok(not bear.is_walking(),
		"and the bear does NOT re-walk its approach -- it was already sitting there")
	_ok(carried < 1.0e-4,
		"and is carried by the fresh rock on the same seat (%.7f u worst)" % carried)
	_ok(bear.global_position.distance_to(bear_seated) > 0.001,
		"BLIND CHECK: the bear really moved with the plank, so the number above means something")

	# --- 2. A TAP ELSEWHERE IS THE EXIT --------------------------------
	# ⚠️ ORDERED AFTER the re-tap on purpose: it ends the ride the re-tap
	# needs. Taken while the fresh rock is still running, which is also the
	# harder case -- the tween has to be killed without its `finished`
	# firing a second dismount.
	var destination: Vector3 = pos + Vector3(0.0, 0.0, -(radius + 6.0))
	hub.call("_on_tapped_ground", destination)
	var off: int = 0
	var off_budget: int = int((rock_s * 3.0 + 8.0) * 60.0)
	# `is_hopping()` is in the wait deliberately: the bear's trip home is
	# SHORTER than Keepy's walk to the tapped point, so a loop that only
	# watched the bear would read Keepy mid-flight and call the destination
	# check a miss.
	while (keepy.is_on_seesaw() or keepy.is_hopping()
			or bear.global_position.y > 0.01 or bear.is_walking()) \
			and off < off_budget:
		await get_tree().process_frame
		off += 1
	_ok(not keepy.is_on_seesaw(), "a tap off the prop takes Keepy off the plank")
	_ok(bear.global_position.y < 0.01,
		"and the bear comes down on the same beat (y = %.4f)" % bear.global_position.y)
	var here := Vector3(keepy.global_position.x, 0.0, keepy.global_position.z)
	_ok(here.distance_to(destination) < 1.0,
		"and ONE tap bought the dismount AND the walk to where it pointed (%.3f u off)"
			% here.distance_to(destination))

	# --- 3. THE BEAR GOES HOME -----------------------------------------
	# BEAR_RETURNS_HOME is now true, and this is the assertion that keeps it
	# honest: the constant alone would read green off its own value.
	var rest: Vector3 = hub.get_script().get_script_constant_map().get("BEAR_REST", Vector3.ZERO)
	var home := Vector3(bear.global_position.x, 0.0, bear.global_position.z)
	_ok(home.distance_to(Vector3(rest.x, 0.0, rest.z)) < 0.5,
		"and the bear walked back to its post (%.3f u from %s)"
			% [home.distance_to(Vector3(rest.x, 0.0, rest.z)), rest])
	_ok(not bear.is_walking(), "where it stopped rather than overshooting")

	hub.queue_free()
	await get_tree().process_frame


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
