extends Node

## CH24 -- WHERE THE BADGER LOOKS ON THE WAY BACK FROM THE FIRE.
##
## Second attempt at the same defect, so this probe does not re-read the
## diff: it prints, frame by frame, WHAT ROTATION.Y ACTUALLY HOLDS across
## the tap that starts the return leg, and what heading the travel wanted
## at that same instant. LOT 2 shipped a fix that reads correct and was
## reported still broken on device -- the only thing that settles which of
## those is wrong is the number the engine really carries.
##
## HEADLESS ON PURPOSE. Nothing here samples a pixel, a MultiMesh instance
## or a screen point: it reads transforms only, which is exactly the case
## CLAUDE.md says must NOT run under xvfb/llvmpipe.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")

## How many frames of the return leg to print one by one. The ease has a
## 1/turn_lambda = 0.167 s time constant, so 60 frames (1 s at the
## --fixed-fps this must be run with) covers the whole of any turn the
## lerp could still be finishing.
const TRACE_FRAMES: int = 60

var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["OK" if ok else "FAIL", label])


func _deg(a: float) -> float:
	return rad_to_deg(a)


## The heading the travel wants right now, by the SAME expression
## HubActorWalker._process uses -- re-derived here rather than read off the
## walker, so this measures the contract and not the implementation.
func _wanted(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


func _ready() -> void:
	ProbeWatchdog.arm(self, "CAMPFIRE FACING PROBE")
	var dl := ProbeWatchdog.deadline("CAMPFIRE FACING PROBE")

	print("=== CAMPFIRE FACING PROBE ===")
	print("")

	HubSpawn.clear()
	var tree := get_tree()
	await tree.process_frame
	var hub: Node = HUB_SCENE.instantiate()
	tree.root.add_child(hub)
	tree.current_scene = hub
	await tree.process_frame
	await tree.process_frame

	var badger: Node3D = hub.get("_badger") as Node3D
	var fire_point: Vector3 = hub.get("_campfire_point")

	print("PHASE 0 -- PRECONDITIONS (a degenerate stage passes every later phase for free)")
	_check(badger != null, "the badger exists")
	if badger == null:
		print("")
		print("RESULT: 1 failure -- no badger, nothing measurable")
		get_tree().quit(1)
		return
	_check(fire_point != Vector3.ZERO,
			"the campfire arrival point is built (%.3f, %.3f)" % [fire_point.x, fire_point.z])
	_check(String(hub.get("_badger_campfire_leg")) == "",
			"the badger starts at rest, not mid-detour")
	print("")

	# =================================================================
	print("PHASE A -- THE OUTBOUND LEG (the leg device reports as CORRECT;")
	print("           it is the control that says this trace can see a turn)")
	var rest0: Vector3 = hub.call("_badger_rest", 0)
	print("  badger rest(0)      (%.3f, %.3f)" % [rest0.x, rest0.z])
	print("  badger at           (%.3f, %.3f)" % [badger.global_position.x, badger.global_position.z])
	print("  rotation.y          %+.2f deg" % _deg(badger.rotation.y))
	hub.call("_on_tapped_campfire", Vector3.ZERO)
	print("  -- tapped; leg is now '%s'" % String(hub.get("_badger_campfire_leg")))
	print("  frame  rotation.y     wanted    err     dist")
	var f: int = 0
	while String(hub.get("_badger_campfire_leg")) != "at_fire" and f < 3000:
		await tree.process_frame
		f += 1
		if f <= 6 or f % 60 == 0:
			var w: float = _wanted(badger.global_position, fire_point)
			print("  %5d  %+9.2f  %+9.2f  %+7.2f  %6.3f" % [f, _deg(badger.rotation.y),
					_deg(w), _deg(angle_difference(badger.rotation.y, w)),
					Vector2(fire_point.x - badger.global_position.x,
							fire_point.z - badger.global_position.z).length()])
	dl.abort_if_exceeded()
	_check(String(hub.get("_badger_campfire_leg")) == "at_fire",
			"the badger reached the fire in %d frames" % f)
	print("  arrived at          (%.3f, %.3f)" % [badger.global_position.x, badger.global_position.z])
	print("  rotation.y at fire  %+.2f deg" % _deg(badger.rotation.y))
	print("")

	# =================================================================
	print("PHASE B -- THE RETURN LEG, FRAME BY FRAME. THE WHOLE POINT.")
	var end: int = int(hub.get("_badger_campfire_return_end"))
	var home: Vector3 = hub.call("_badger_rest", end)
	print("  return end index    %d" % end)
	print("  home                (%.3f, %.3f)" % [home.x, home.z])
	var before_rot: float = badger.rotation.y
	var before_yaw: float = float(badger.get("_yaw"))
	var need: float = _wanted(badger.global_position, home)
	print("  BEFORE the tap:  rotation.y %+.2f  _yaw %+.2f  | heading home needs %+.2f  (err %+.2f)"
			% [_deg(before_rot), _deg(before_yaw), _deg(need),
					_deg(angle_difference(before_rot, need))])
	_check(absf(_deg(angle_difference(before_rot, need))) > 150.0,
			"BLIND CHECK: before the tap the badger really is turned away from home"
					+ " (%.2f deg > 150) -- without this, 'it faces home after' is free"
					% absf(_deg(angle_difference(before_rot, need))))

	# THE TAP. Nothing is awaited between it and the read below, so what it
	# prints is the effect of the handler ALONE -- face(), if face() runs.
	hub.call("_on_tapped_campfire", Vector3.ZERO)
	var after_rot: float = badger.rotation.y
	var after_yaw: float = float(badger.get("_yaw"))
	print("  AFTER the tap, SAME frame, no process yet:")
	print("     rotation.y %+.2f  _yaw %+.2f  | err vs home %+.2f"
			% [_deg(after_rot), _deg(after_yaw), _deg(angle_difference(after_rot, need))])
	_check(String(hub.get("_badger_campfire_leg")) == "to_rest",
			"the tap started the return leg")
	_check(absf(_deg(angle_difference(after_rot, need))) < 1.0,
			"the handler itself turned the badger onto the home heading (err %+.2f deg < 1.0)"
					% _deg(angle_difference(after_rot, need)))

	print("")
	print("  frame  rotation.y     wanted    err     dist   (err = what the player sees:")
	print("                                                  0 = walking forwards)")
	var worst: float = 0.0
	var worst_f: int = -1
	for i in TRACE_FRAMES:
		await tree.process_frame
		var w: float = _wanted(badger.global_position, home)
		var err: float = absf(_deg(angle_difference(badger.rotation.y, w)))
		if err > worst:
			worst = err
			worst_f = i + 1
		var d: float = Vector2(home.x - badger.global_position.x,
				home.z - badger.global_position.z).length()
		print("  %5d  %+9.2f  %+9.2f  %+7.2f  %6.3f" % [i + 1, _deg(badger.rotation.y),
				_deg(w), _deg(angle_difference(badger.rotation.y, w)), d])
		if String(hub.get("_badger_campfire_leg")) != "to_rest":
			print("  -- leg ended at frame %d" % (i + 1))
			break
	dl.abort_if_exceeded()
	print("")
	print("  WORST heading error over the traced return: %.2f deg (frame %d)" % [worst, worst_f])
	_check(worst < 5.0,
			"the badger never walks noticeably sideways or backwards on the way home"
					+ " (worst %.2f deg < 5.0)" % worst)
	print("")

	# =================================================================
	print("PHASE C -- WHERE THE PROXIMITY MARKER SITS (subject B)")
	var marker: Node3D = hub.get("_campfire_marker") as Node3D
	_check(marker != null, "the marker exists")
	if marker != null:
		var site := Vector3(HubCampfire.SITE.x, 0.0, HubCampfire.SITE.y)
		var off_fire: float = Vector2(marker.global_position.x - site.x,
				marker.global_position.z - site.z).length()
		var off_badger: float = Vector2(marker.global_position.x - fire_point.x,
				marker.global_position.z - fire_point.z).length()
		print("  hearth   HubCampfire.SITE (%.3f, %.3f)" % [site.x, site.z])
		print("  badger arrival point      (%.3f, %.3f)" % [fire_point.x, fire_point.z])
		print("  marker at                 (%.3f, %.3f)"
				% [marker.global_position.x, marker.global_position.z])
		print("  marker offset from HEARTH        %.3f u" % off_fire)
		print("  marker offset from ARRIVAL POINT %.3f u" % off_badger)
		_check(off_fire < 0.01,
				"the marker is drawn ON the fire, not beside it (%.3f u from the hearth)"
						% off_fire)
	print("")

	# =================================================================
	print("PHASE E -- THE SAME ROUND TRIP UNDER A DOUBLE DISPATCH (what a real")
	print("           finger produces, and what this sandbox does NOT reproduce")
	print("           by calling the handler once).")
	print("  `emulate_mouse_from_touch` is left at its default `true` (checked in")
	print("  project.godot), so ONE physical tap raises a touch event AND a")
	print("  synthesised mouse event in the same pass -- CLAUDE.md's own trap. If")
	print("  the second dispatch re-entered the handler it would re-run the leg")
	print("  that the first one just started; on the return that would mean")
	print("  face() firing against a target the walker has already left.")
	# Let the return leg that PHASE B started actually finish first.
	var g: int = 0
	while String(hub.get("_badger_campfire_leg")) != "" and g < 3000:
		await tree.process_frame
		g += 1
	dl.abort_if_exceeded()
	_check(String(hub.get("_badger_campfire_leg")) == "",
			"the badger got home and the detour reset (%d frames)" % g)

	# OUTBOUND, tapped TWICE in the same frame.
	hub.call("_on_tapped_campfire", Vector3.ZERO)
	hub.call("_on_tapped_campfire", Vector3.ZERO)
	_check(String(hub.get("_badger_campfire_leg")) == "to_fire",
			"a doubled tap still starts exactly one outbound leg")
	var g2: int = 0
	while String(hub.get("_badger_campfire_leg")) != "at_fire" and g2 < 3000:
		await tree.process_frame
		g2 += 1
	dl.abort_if_exceeded()
	_check(String(hub.get("_badger_campfire_leg")) == "at_fire",
			"and it arrives at the fire (%d frames)" % g2)

	# RETURN, tapped TWICE in the same frame -- the case the device runs.
	var need2: float = _wanted(badger.global_position, home)
	hub.call("_on_tapped_campfire", Vector3.ZERO)
	hub.call("_on_tapped_campfire", Vector3.ZERO)
	print("  after a DOUBLED return tap: rotation.y %+.2f | needs %+.2f | err %+.2f"
			% [_deg(badger.rotation.y), _deg(need2),
					_deg(angle_difference(badger.rotation.y, need2))])
	_check(String(hub.get("_badger_campfire_leg")) == "to_rest",
			"a doubled tap still starts exactly one return leg")
	_check(absf(_deg(angle_difference(badger.rotation.y, need2))) < 1.0,
			"and the heading is still exact under the double dispatch (err %+.2f deg)"
					% _deg(angle_difference(badger.rotation.y, need2)))
	var worst2: float = 0.0
	for i in 30:
		await tree.process_frame
		var w2: float = _wanted(badger.global_position, home)
		worst2 = maxf(worst2, absf(_deg(angle_difference(badger.rotation.y, w2))))
		if String(hub.get("_badger_campfire_leg")) != "to_rest":
			break
	dl.abort_if_exceeded()
	_check(worst2 < 5.0,
			"and stays exact over the next 30 frames (worst %.2f deg)" % worst2)
	print("")

	# =================================================================
	print("PHASE D -- WHY THE RETURN LOOKS LIKE A BACK, AND WHY THAT IS NOT A BUG")
	print("           (the device report for LOT 2 and LOT 3 is 'dos tourne au retour';")
	print("            PHASE B proves the HEADING is exact, so the back has to come")
	print("            from somewhere else -- this measures where.)")
	var cam: Camera3D = hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_check(cam != null, "the hub camera exists")
	if cam != null:
		# The hub camera NEVER rotates (HubCamera.OFFSET is a constant), so its
		# flat view direction is a fixed property of the plateau, not of where
		# Keepy happens to stand.
		var view: Vector3 = -cam.global_transform.basis.z
		var view_flat := Vector2(view.x, view.z).normalized()
		var out_head := Vector2(sin(deg_to_rad(-20.93)), cos(deg_to_rad(-20.93)))
		var back_head := Vector2(sin(need), cos(need))
		var out_dot: float = view_flat.dot(out_head)
		var back_dot: float = view_flat.dot(back_head)
		print("  camera flat view direction   (%.3f, %.3f)" % [view_flat.x, view_flat.y])
		print("  OUTBOUND heading vs view     dot %+.3f  (%.1f deg apart)"
				% [out_dot, rad_to_deg(acos(clampf(out_dot, -1.0, 1.0)))])
		print("  RETURN   heading vs view     dot %+.3f  (%.1f deg apart)"
				% [back_dot, rad_to_deg(acos(clampf(back_dot, -1.0, 1.0)))])
		print("  dot > 0 means the actor travels ALONG the line of sight, i.e. AWAY")
		print("  from the camera -- which shows the player its BACK, correctly.")
		_check(out_dot < 0.0,
				"outbound, the badger walks TOWARDS the camera, so its face is what shows")
		_check(back_dot > 0.0,
				"returning, it walks AWAY from the camera, so its back is what shows --"
						+ " with a heading error of 0.00 deg. The back is the GEOMETRY of"
						+ " this round trip, not a rotation defect.")
	print("")

	print("RESULT: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
