extends Node
## Dev-only: does the background hill/mountain billboard layer (Decor.gd)
## hold a STABLE silhouette across a continuous window of real play, or does
## an individual instance change shape/size/position in a way that is not
## plain parallax translation?
##
## =====================================================================
## WHY THIS IS A DIFFERENT QUESTION FROM THE PREVIOUS FIX (acf060c)
##
## The x_range widening (10 August 2026) measured and fixed a SPAWN-TIME
## defect: individual instances wider than their own layer's spread, fusing
## into one blob. That fix touched nothing about what happens to a SINGLE
## instance once it is already on screen and scrolling. This probe measures
## exactly that -- per-instance continuity across consecutive simulated
## frames of a real run, not instance-vs-instance overlap at a snapshot.
##
## =====================================================================
## WHAT WAS FOUND (and is asserted here, not just described)
##
## Every instance recycles at `spawn_z_max`, its OWN layer's near edge --
## chosen (Decor.gd's own class doc) so it "never travels through the
## readable foreground". That is true of the FOREGROUND. It says nothing
## about the CAMERA FRUSTUM: `spawn_z_max` is still 200-550 world units in
## front of the camera for all three layers, and the camera's horizontal
## FOV at those distances (~107 degrees) is wide enough to cover several
## HUNDRED metres of width, dwarfing any layer's x_range (55-74m half). So
## every recycle -- a hard teleport from `spawn_z_max` (near edge, largest
## apparent size the instance ever reaches) back to `spawn_z_min` (far edge,
## its smallest) -- happens while the instance is still squarely inside the
## visible frustum. That is a real, continuous "pop": the same instance
## abruptly shrinking and jumping backward, once per recycle, spread across
## 13 instances at staggered phases, which is exactly what reads as
## "unstable" over a real play session -- not a one-off snapshot defect.
## Decor.gd's fix (this same lot) fades `modulate.a` to 0 before the
## teleport and back to 1 after it, so the same recycle still happens on
## the same frame, now invisibly.
##
## =====================================================================
## METHOD -- TWO PHASES, NEITHER ONE ALONE PROVES IT
##
## PHASE A drives a real, continuous, organically-timed window (seeded, 900
## simulated frames = 15s @ 60fps) and watches every instance of every layer
## every frame: is it inside the camera frustum, and did its Z jump backward
## between two consecutive frames (the only way `position.z` can decrease --
## see Decor._physics_process, which only ever adds a positive
## `move_amount`; any drop is a recycle, not motion). This is the "does
## normal play show it" half.
##
## PHASE B removes the dependency on luck: for each layer it forces its
## first pool instance to `spawn_z_max - PHASE_B_LEAD_IN` (a few world units
## before its own recycle threshold) at a pinned, fast scroll speed, then
## steps forward frame by frame through the crossing, logging screen
## position and on-screen state on BOTH sides of it. Same code path
## (Decor._physics_process is untouched by this probe -- it is driven by
## writing the exact fields the shipped game writes: `GameState.state`,
## `current_speed`, and the instance's own `position.z`), just a controlled
## instant instead of an organic one -- the same "pin the state, drive the
## real path" discipline PursuerContrastAudit/StrikeFatalContrastAudit use.
##
## =====================================================================
## WHY THIS IS A BLOCKING PROBE (both ProbeWatchdog entry points, per its
## own header on "where both are used together")
##
## An earlier version of this probe drove time by awaiting
## `RenderingServer.frame_post_draw` each simulated frame, matching the
## contrast-audit probes' own convention. MEASURED, not assumed, to be the
## wrong choice here: under this sandbox's software (llvmpipe/Mesa)
## rendering, that version had not printed past its own header after the
## full 900s ProbeWatchdog budget -- confirmed genuinely still running (not
## deadlocked: CPU pinned at 100% throughout) by process inspection, then
## killed by the wrapping shell timeout. The contrast probes pay that same
## cost deliberately, because they are measuring REAL RENDERED PIXELS
## (`get_viewport().get_texture().get_image()`); this probe never reads a
## pixel -- `Camera3D.unproject_position()` is pure transform maths and
## needs no frame to have actually been drawn. So Decor._physics_process and
## CameraFollow._process are called DIRECTLY here, the same "drive the real
## per-frame method without waiting on the engine's own clock" pattern
## DecorParallaxProbe.gd already uses and documents, and `advance_time()` is
## called directly for the same reason it exists (GameState's own doc: "a
## headless test can drive a whole run deterministically at a fixed step
## instead of waiting on the real frame clock"). Nothing here ever yields a
## frame, so `ProbeWatchdog.arm()` alone would be armed and MUTE -- see its
## own header on exactly that failure mode -- hence the `deadline()` +
## `abort_if_exceeded()` checks threaded through every loop below.
##
## HERMETIC BY CONSTRUCTION, same reasoning as DeathModelAudit: no
## Game.tscn, no TrackManager, no obstacles, no Keepy, no HUD. Only a bare
## Camera3D (running the real CameraFollow.gd against a stationary target)
## and a real Decor node. Nothing else in the tree can end the run or move
## anything this probe is not explicitly attributing.
##
## Run it with:
##   xvfb-run -a godot4 --headless --path . res://scripts/dev/DecorStabilityAudit.tscn

## Seed for the decor streams -- same one every other decor-reading probe
## pins (F10, see DecorRng.gd): an unseeded background makes a per-instance
## continuity check a coin flip on which instances even overlap the sample
## window.
const DECOR_SEED: int = 20260806

const DT: float = 1.0 / 60.0

## 15s at 60fps, the task's own stated minimum -- long enough to observe
## several staggered recycle cycles on the fastest (near) layer, not just
## one.
const PHASE_A_FRAMES: int = 900

## Steps to let CameraFollow's lerp converge on the stationary target before
## anything is measured.
const WARMUP_STEPS: int = 90

## World units before `spawn_z_max` Phase B starts an instance at. Small
## relative to any layer's band (130-160m), so the crossing happens inside
## a short, fully-logged window rather than being buried in an otherwise
## uneventful multi-second wait.
const PHASE_B_LEAD_IN: float = 3.0

## How many frames to keep watching after the crossing, to confirm the
## instance settles back into ordinary, continuous motion on the far side.
const PHASE_B_TAIL_FRAMES: int = 40

## Fixed scroll speed for Phase B -- GameState.STAGE_SPEEDS' own max, picked
## purely to make the lead-in crossing happen sooner (real code path, real
## field, just not left to whatever stage Phase A happened to leave the run
## in -- see GameState._update_stage's own doc on when current_speed is and
## is not overwritten by stage advancement).
const PHASE_B_SPEED: float = 26.0

## Below this, an instance reads as invisible for this probe's purposes --
## matches the fix's own fully-transparent floor; pre-fix this is simply
## never below 1.0, so the floor is inert until the fix exists.
const VISIBLE_ALPHA_FLOOR: float = 0.02

## A same-frame BACKWARD jump in world Z bigger than this can only be a
## recycle: Decor._physics_process only ever ADDS a non-negative
## `move_amount` to `position.z`, so ordinary scrolling never decreases it,
## and at the speeds this probe drives (12-26 m/s times a parallax factor
## <= 0.35) a single frame's forward step never exceeds a couple of
## centimetres.
const RECYCLE_JUMP_THRESHOLD: float = 2.0

var _target: Node3D
var _camera: CameraFollow
var _decor: Decor
var _deadline: ProbeDeadline

## Per layer, per pool index -- Phase A's own continuity trace.
var _prev_z: Array = []
var _prev_visible: Array = []
var _prev_alpha: Array = []

## Per layer: Array of visible-instance-counts, one entry per Phase A frame.
var _count_log: Array = []

## Every recycle observed, either phase, with what the instance looked like
## on both sides of it.
var _recycle_events: Array = []

var _aborted: bool = false

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a watchdog
	# armed after the hang is no watchdog. See ProbeWatchdog.gd. Both entry
	# points, since this probe never yields a frame -- see class doc.
	ProbeWatchdog.arm(self, "DECOR STABILITY AUDIT")
	_deadline = ProbeWatchdog.deadline("DECOR STABILITY AUDIT")
	print("=== DECOR STABILITY AUDIT ===")
	print("question: does an individual hill/mountain instance ever change")
	print("apparent shape/size/position while inside the camera frustum,")
	print("other than plain parallax translation?")
	print("")
	# BEFORE Decor.new(), not after -- Decor's own RNG stream is created at
	# construction time (`var _rng := DecorRng.make()`), same constraint
	# DecorRng.force_seed()'s own doc states for Game.tscn's TrackSegments.
	DecorRng.force_seed(DECOR_SEED)
	print("decor seeded %d (reproducible hill placement)" % DECOR_SEED)
	_build_world()
	_run()

## Bare Camera3D + stationary target + one real Decor node -- no Game.tscn,
## no TrackManager, no obstacles, no Keepy. See class doc "HERMETIC BY
## CONSTRUCTION".
func _build_world() -> void:
	_target = Node3D.new()
	_target.position = Vector3(0.0, 1.0, 0.0)
	add_child(_target)
	_camera = CameraFollow.new()
	_camera.target = _target
	_camera.current = true
	add_child(_camera)
	_decor = Decor.new()
	add_child(_decor)

func _run() -> void:
	GameState.start_run()
	# Dev probe hook, same contract as every contrast/pushback probe that
	# drives GameState directly: nothing here needs the pursuer, and a
	# neutered one cannot end the run out from under a measurement window
	# this probe does not control the length of otherwise.
	GameState.pursuer_enabled = false

	for layer_index in Decor._LAYERS.size():
		var pool: Array = _decor._pools[layer_index]
		var z_row: Array = []
		var vis_row: Array = []
		var alpha_row: Array = []
		for hill in pool:
			z_row.append(hill.position.z)
			vis_row.append(_is_visible(hill))
			alpha_row.append(hill.modulate.a)
		_prev_z.append(z_row)
		_prev_visible.append(vis_row)
		_prev_alpha.append(alpha_row)
		_count_log.append([])

	# Let the camera's follow-lerp converge on the (stationary) target
	# before recording anything.
	for i in WARMUP_STEPS:
		if _deadline.abort_if_exceeded():
			return
		_camera._process(DT)

	_phase_a()
	if _aborted:
		return
	for layer_index in Decor._LAYERS.size():
		_phase_b(layer_index)
		if _aborted:
			return
	_report()

func _phase_a() -> void:
	print("--- PHASE A: continuous window, %d frames (%.1fs @ 60fps), organic timing ---" % [
		PHASE_A_FRAMES, PHASE_A_FRAMES / 60.0])
	for frame in PHASE_A_FRAMES:
		if _deadline.abort_if_exceeded():
			_aborted = true
			return
		_camera._process(DT)
		GameState.advance_time(DT)
		_decor._physics_process(DT)
		for layer_index in Decor._LAYERS.size():
			var pool: Array = _decor._pools[layer_index]
			var visible_count := 0
			for i in pool.size():
				var hill: Sprite3D = pool[i]
				var z: float = hill.position.z
				var vis: bool = _is_visible(hill)
				var alpha: float = hill.modulate.a
				if vis:
					visible_count += 1
				var pz: float = _prev_z[layer_index][i]
				if z < pz - RECYCLE_JUMP_THRESHOLD:
					_log_recycle("A", frame, layer_index, i, pz, z,
						_prev_visible[layer_index][i], _prev_alpha[layer_index][i], vis, alpha)
				_prev_z[layer_index][i] = z
				_prev_visible[layer_index][i] = vis
				_prev_alpha[layer_index][i] = alpha
			_count_log[layer_index].append(visible_count)
	print("phase A done: run_time=%.2fs current_speed=%.1f" % [
		GameState.run_time_s, GameState.current_speed])
	print("")

## Forces layer `layer_index`'s first pool instance to just short of its own
## recycle threshold, at a pinned fast speed, and steps through the
## crossing frame by frame -- see class doc "PHASE B".
func _phase_b(layer_index: int) -> void:
	var layer: Dictionary = Decor._LAYERS[layer_index]
	var label := _layer_label(layer_index)
	var recycle_z: float = layer["spawn_z_max"]
	print("--- PHASE B: targeted crossing, layer=%s (recycle_z=%.1f) ---" % [label, recycle_z])

	# Fresh run clock so the pinned speed cannot be overwritten mid-window
	# by a stage boundary Phase A already walked past -- see
	# GameState._update_stage's own doc for when current_speed changes.
	GameState.start_run()
	GameState.pursuer_enabled = false
	GameState.current_speed = PHASE_B_SPEED

	# Reads `hill.modulate.a` as whatever the CURRENT code path already left
	# it at (pre-fix: Sprite3D's untouched default, 1.0, opaque forever;
	## post-fix: whatever Decor._fade_alpha last computed) -- this probe
	# does not assume the fix exists, so it can run unmodified against
	# either version and report what it actually finds.
	var hill: Sprite3D = _decor._pools[layer_index][0]
	hill.position.z = recycle_z - PHASE_B_LEAD_IN
	var prev_z: float = hill.position.z
	var prev_visible: bool = _is_visible(hill)
	var prev_alpha: float = hill.modulate.a
	print("  start z=%.2f visible=%s alpha=%.3f" % [prev_z, prev_visible, prev_alpha])

	var crossed := false
	var tail := 0
	var frame := 0
	while tail < PHASE_B_TAIL_FRAMES:
		if _deadline.abort_if_exceeded():
			_aborted = true
			return
		# Every layer's physics runs on every step, same as the shipped
		# game -- only the instance under test has been forced; its four
		# siblings and the other two layers keep moving normally.
		_decor._physics_process(DT)
		var z: float = hill.position.z
		var vis: bool = _is_visible(hill)
		var alpha: float = hill.modulate.a
		if not crossed and z < prev_z - RECYCLE_JUMP_THRESHOLD:
			crossed = true
			_log_recycle("B:" + label, frame, layer_index, 0, prev_z, z, prev_visible, prev_alpha, vis, alpha)
		elif frame < 6 or (crossed and tail < 4):
			# A handful of ordinary frames on each side, printed for a
			# reader who wants the raw trace rather than the summary.
			print("  frame=%-3d z=%-8.2f visible=%-5s alpha=%.3f" % [frame, z, vis, alpha])
		prev_z = z
		prev_visible = vis
		prev_alpha = alpha
		if crossed:
			tail += 1
		frame += 1
	print("")

func _log_recycle(phase: String, frame: int, layer_index: int, instance: int,
		z_before: float, z_after: float, visible_before: bool, alpha_before: float,
		visible_after: bool, alpha_after: float) -> void:
	_recycle_events.append({
		"phase": phase, "frame": frame, "layer": layer_index, "instance": instance,
		"z_before": z_before, "z_after": z_after,
		"visible_before": visible_before, "alpha_before": alpha_before,
		"visible_after": visible_after, "alpha_after": alpha_after,
	})
	print("  RECYCLE phase=%-8s frame=%-4d instance=%d  z %.2f -> %.2f" % [
		phase, frame, instance, z_before, z_after])
	print("    BEFORE: visible=%-5s alpha=%.3f      AFTER: visible=%-5s alpha=%.3f" % [
		visible_before, alpha_before, visible_after, alpha_after])

## Screen-space visibility test: alpha above the floor, in front of the
## camera, and its projected centre inside the viewport rect. Centre-point
## rather than full quad corners -- a hill's half-width is small next to the
## camera's horizontal FOV at these distances (class doc's own maths), so
## the two tests agree except right at the screen edge, which is not the
## question this probe asks.
func _is_visible(hill: Sprite3D) -> bool:
	if hill.modulate.a <= VISIBLE_ALPHA_FLOOR:
		return false
	var to_hill: Vector3 = hill.global_position - _camera.global_position
	var forward: Vector3 = -_camera.global_transform.basis.z
	if to_hill.dot(forward) <= 0.0:
		return false
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var p: Vector2 = _camera.unproject_position(hill.global_position)
	return p.x >= 0.0 and p.x <= vp.x and p.y >= 0.0 and p.y <= vp.y

func _layer_label(layer_index: int) -> String:
	match layer_index:
		0: return "mountain"
		1: return "far"
		2: return "near"
	return "?%d" % layer_index

func _report() -> void:
	print("=== SUMMARY ===")
	var pop_events := 0
	for e in _recycle_events:
		# A "pop" is a recycle where the instance was clearly on screen the
		# frame before it teleported -- alpha comfortably above the floor,
		# not just crossing it.
		if e["visible_before"] and e["alpha_before"] > 0.5:
			pop_events += 1
	print("recycle events observed (phase A + phase B): %d" % _recycle_events.size())
	print("of those, recycles that happened while CLEARLY VISIBLE (pop): %d" % pop_events)
	print("")
	for layer_index in Decor._LAYERS.size():
		var counts: Array = _count_log[layer_index]
		if counts.is_empty():
			continue
		var lo = counts.min()
		var hi = counts.max()
		var distinct := {}
		for c in counts:
			distinct[c] = true
		var keys := distinct.keys()
		keys.sort()
		print("layer %-8s phase-A visible-instance-count: min=%d max=%d distinct=%s (pool size=%d)" % [
			_layer_label(layer_index), lo, hi, keys, _decor._pools[layer_index].size()])
	print("")
	if pop_events > 0:
		push_error("DECOR STABILITY AUDIT FAILED: %d recycle(s) happened while the instance was clearly visible (pop)." % pop_events)
		get_tree().quit(1)
		return
	print("PASSED: no recycle happened while an instance was clearly visible.")
	get_tree().quit(0)
