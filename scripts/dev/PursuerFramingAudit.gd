extends Node
## Dev-only diagnostic for how much of the SCREEN the pursuer occupies --
## the question none of the other pursuer probes ask. PursuerAudit measures
## the abstract lead and capture outcomes; PursuerContrastAudit measures
## colour separation at two pinned poses. Neither one ever looks at how
## much of the frame the mesh actually covers, which is exactly how a
## framing bug (Pursuer.FAR_Z sitting one unit from the camera, see that
## constant's doc in scripts/gameplay/Pursuer.gd) shipped unnoticed: every
## existing check was passing while a real playtest saw the pursuer eat the
## screen.
##
## METHOD: project the pursuer's real mesh AABB into screen space every
## physics frame it is visible, on a REAL driven run (SAFE bot -- see
## PursuerAudit.gd's own reasoning for why SAFE is the bot that actually
## puts the pursuer on screen, ~85% of its time there) rather than pinned
## synthetic poses, so camera lag from lane switches, jump bob and strike
## shake all have a chance to make a moment worse than the bare Z/scale
## curve alone would. Bounding-box projection (Camera3D.unproject_position
## on the mesh's real global AABB corners) rather than a pixel capture:
## it is exact (same projection matrix the renderer itself would use), and
## it runs fully headless at --fixed-fps speed -- no xvfb, no rendering
## driver, no GPU -- which the other two pursuer probes need specifically
## because they read actual pixel colours. Occupancy here needs only
## geometry.
##
## Three populations are sampled and reported separately, because they are
## produced by three different code paths and only TWO of them owe the same
## cap:
##
##   INTRO   -- Pursuer._process_intro, the opening sighting every run
##              starts with (see Pursuer.gd's INTRO block). Bound by the cap.
##   VISIBLE -- Pursuer._process's ordinary lead-driven branch, whenever
##              GameState.pursuer_visible is true later in the run. Bound by
##              the cap.
##   CAPTURE -- Pursuer._process_capture, the forced lunge played during
##              GameState.State.CAPTURED (see that state's own doc). NOT
##              bound by the cap: the run is already over by the time this
##              plays, there is nothing left behind the pursuer to protect,
##              and the whole point of the lunge is to fill more of the
##              frame than the ordinary approach is ever allowed to. This
##              population is measured and reported like the other two --
##              exceeding the cap here is the EXPECTED, correct outcome, not
##              a regression, so it never fails the run.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/PursuerFramingAudit.tscn -- --seed=20260807

## Total simulated time to drive the SAFE bot for, summed across as many
## runs as it takes (a death restarts immediately, same pattern as
## PursuerAudit's phases). Generous enough to accumulate a real
## distribution of occupancy samples across the whole visible-lead range,
## not just a handful of frames.
const TOTAL_SIM_S: float = 180.0
## Ceiling on a single run's length, so one unusually long survival cannot
## swallow the whole budget and starve sample diversity across restarts.
const MAX_RUN_S: float = 200.0

## The occupancy cap this whole batch exists to enforce: never more than
## this fraction of the screen's HEIGHT, at the closest approach the
## pursuer's framing ever reaches. See the task brief's calibration target
## (~25-30%) and Pursuer.gd's FAR_Z/CAUGHT_Z/FAR_SCALE/NEAR_SCALE doc for
## the geometry this is checked against.
const MAX_OCCUPANCY_FRACTION: float = 0.30

# --- bot (lifted from PursuerAudit.gd's SAFE bot, see that file's class
# doc for why these probes duplicate rather than share bot logic) --------
const SAFE_ESCAPE_LEAD_S: float = 1.2
const HALF_AIR_TIME_S: float = Keepy.JUMP_VELOCITY / Keepy.GRAVITY

## Mechanics this run must actually have produced -- every hazard type,
## plus the pursuer itself, which unlike in PursuerAudit IS required
## here: a framing probe whose pursuer never appeared has measured
## nothing at all. See ProbeCoverage.gd.
const REQUIRED_COVERAGE: Array[int] = [
	ProbeCoverage.Mechanic.DODGE, ProbeCoverage.Mechanic.JUMP,
	ProbeCoverage.Mechanic.ENEMY, ProbeCoverage.Mechanic.AIR_ENEMY,
	ProbeCoverage.Mechanic.CHARGER, ProbeCoverage.Mechanic.STOMPER,
	ProbeCoverage.Mechanic.PURSUER_VISIBLE,
]

var _coverage := ProbeCoverage.new()
var _game: Node3D
var _keepy: Keepy
var _track: Node3D
var _camera: Camera3D
var _pursuer: Pursuer
var _pursuer_mesh: ModelSlot

var _run_t: float = 0.0
var _phase_t: float = 0.0
var _runs: int = 0

## Occupancy samples, kept separately so INTRO and VISIBLE can each be
## checked against the same cap and reported on their own terms. CAPTURE is
## reported the same way but never checked against it -- see the class doc.
var _intro_samples: Array[Dictionary] = []
var _visible_samples: Array[Dictionary] = []
var _capture_samples: Array[Dictionary] = []

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "PursuerFramingAudit")
	var seeded := DevSeed.apply()
	print("=== PURSUER FRAMING AUDIT ===")
	print("rng                : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("metric             : pursuer mesh bounding box, projected to screen space")
	print("cap                : %.0f%% of screen height, max, both INTRO and VISIBLE" % (MAX_OCCUPANCY_FRACTION * 100.0))
	print("viewport           : %s (project default -- portrait mobile is the only real target)" % get_viewport().get_visible_rect().size)
	print("")
	_coverage.begin_phase("SAFE bot")
	_start_run()

func _start_run() -> void:
	if _game:
		_game.process_mode = Node.PROCESS_MODE_DISABLED
		_game.queue_free()
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	_coverage.run_restarted()
	_camera = _game.get_node("World/CameraFollow")
	_pursuer = _game.get_node("World/Pursuer")
	_pursuer_mesh = _pursuer.get_node("Silhouette")
	_run_t = 0.0

func _physics_process(delta: float) -> void:
	# CAPTURED kept alive here alongside PLAYING -- and that is new for this
	# batch -- specifically so the run is not torn down before the capture
	# lunge (Pursuer._process_capture) has actually played out. Ending the
	# run the instant PLAYING stops, as this used to, would have sampled
	# nothing at all from CAPTURE: this probe would have started a fresh run
	# in the same physics frame the sequence began.
	var active := GameState.state == GameState.State.PLAYING \
		or GameState.state == GameState.State.CAPTURED
	if active and _run_t < MAX_RUN_S:
		_run_t += delta
		_phase_t += delta
		# Only while actually PLAYING -- there is nothing left to react to
		# once capture has begun (the world is frozen, see State.CAPTURED's
		# doc), and driving the bot's lane logic against frozen obstacles
		# would just be wasted work every frame of every capture.
		if GameState.state == GameState.State.PLAYING:
			_drive_safe_bot()
			_coverage.observe(_track, _keepy)
		_sample()
		return
	_end_run()

## All three populations are read off the SAME node every frame -- Pursuer.gd
## guarantees at most one of _intro_active / the ordinary branch / the
## capture lunge is live at once (see its _process guard), so there is no
## risk of double-counting a single frame into more than one bucket. CAPTURE
## is checked first: it is driven off GameState.state rather than a Pursuer
## flag because the lunge does not expose one of its own (Pursuer.gd has no
## reason to duplicate GameState.state on its own node just so a probe can
## read it).
func _sample() -> void:
	if not _pursuer.visible:
		return
	var frac := _occupancy_fraction()
	if GameState.state == GameState.State.CAPTURED:
		_capture_samples.append({"t": _run_t, "frac": frac})
	elif _pursuer._intro_active:
		_intro_samples.append({"t": _run_t, "frac": frac})
	elif GameState.pursuer_visible:
		_visible_samples.append({"lead": GameState.pursuer_lead_s, "frac": frac})

## Projects the pursuer's real mesh AABB (its actual current transform --
## position, the run's sway/bob, and scale, whichever branch of Pursuer.gd
## is driving it this frame) into screen space, and returns how much of the
## screen's height its vertical extent covers. Clamped to the visible
## rect: a mesh that has scrolled fully off screen cannot occupy more than
## 0% of it, and one that overflowed both edges is capped at 100%, not
## whatever a naive off-screen projection would compute.
func _occupancy_fraction() -> float:
	# visual_aabb() rather than get_aabb(): the silhouette is a ModelSlot
	# (scripts/world/ModelSlot.gd), so once a Meshy .glb is installed the
	# node's OWN mesh is null and get_aabb() would report an empty box --
	# i.e. this probe would silently start reporting 0% occupancy for the
	# very asset it exists to budget. visual_aabb() measures whatever is
	# actually drawn, and returns exactly get_aabb() while the placeholder
	# is still in place, which is why this batch's numbers are unchanged.
	var aabb := _pursuer_mesh.visual_aabb()
	var gt := _pursuer_mesh.global_transform
	var vp_h: float = get_viewport().get_visible_rect().size.y
	var min_y := INF
	var max_y := -INF
	for i in 8:
		var corner := aabb.position + Vector3(
			aabb.size.x * float(i & 1),
			aabb.size.y * float((i >> 1) & 1),
			aabb.size.z * float((i >> 2) & 1))
		var screen := _camera.unproject_position(gt * corner)
		min_y = minf(min_y, screen.y)
		max_y = maxf(max_y, screen.y)
	var top := clampf(min_y, 0.0, vp_h)
	var bottom := clampf(max_y, 0.0, vp_h)
	return (bottom - top) / vp_h

func _end_run() -> void:
	_runs += 1
	if _phase_t < TOTAL_SIM_S:
		_start_run()
		return
	_report()

func _report() -> void:
	print("runs                : %d, %.1fs simulated total" % [_runs, _phase_t])
	_coverage.report(REQUIRED_COVERAGE)
	print("")
	_report_population("INTRO", _intro_samples)
	print("")
	_report_population("VISIBLE", _visible_samples)
	print("")
	# CAPTURE is reported exactly like the other two, but on its own,
	# UNCAPPED terms -- see the class doc: exceeding MAX_OCCUPANCY_FRACTION
	# here is the expected, correct outcome of the lunge doing its job, not
	# a regression, so this population never enters the pass/fail decision
	# below.
	_report_population("CAPTURE (uncapped by design -- see class doc)", _capture_samples)
	print("")

	var intro_max := _max_frac(_intro_samples)
	var visible_max := _max_frac(_visible_samples)
	var worst := maxf(intro_max, visible_max)
	# COVERAGE FIRST -- see ProbeCoverage.gd. A framing cap "respected" over
	# a run whose bot never met a CHARGER says nothing about the frames a
	# charger would have been in.
	var gaps := _coverage.verify(REQUIRED_COVERAGE)
	if not gaps.is_empty():
		for gap in gaps:
			push_error("PURSUER FRAMING AUDIT INCONCLUSIVE: %s." % gap)
		get_tree().quit(1)
		return
	if worst > MAX_OCCUPANCY_FRACTION:
		push_error("PURSUER FRAMING AUDIT FAILED: max occupancy %.1f%% exceeds the %.0f%% cap." % [
			worst * 100.0, MAX_OCCUPANCY_FRACTION * 100.0])
		get_tree().quit(1)
		return
	if _intro_samples.is_empty():
		push_error("PURSUER FRAMING AUDIT FAILED: zero INTRO samples -- the opening sighting was never observed, this run proves nothing about it.")
		get_tree().quit(1)
		return
	if _visible_samples.is_empty():
		push_error("PURSUER FRAMING AUDIT FAILED: zero VISIBLE samples -- the pursuer was never seen outside its intro, this run proves nothing about the real approach.")
		get_tree().quit(1)
		return
	if _capture_samples.is_empty():
		# Informational only -- see the loop above's own comment: with the
		# SAFE bot dying repeatedly, an empty CAPTURE population across a
		# whole run would be surprising, but it is not what this audit
		# exists to guarantee, so it is reported rather than failed.
		print("NOTE: zero CAPTURE samples -- the lunge was never observed this run.")
	print("PASSED: INTRO and VISIBLE stay at or under %.0f%% of screen height (CAPTURE is exempt by design)." % (MAX_OCCUPANCY_FRACTION * 100.0))
	get_tree().quit(0)

func _report_population(label: String, samples: Array[Dictionary]) -> void:
	if samples.is_empty():
		print("%s: 0 samples" % label)
		return
	var fracs: Array[float] = []
	for s in samples:
		fracs.append(s["frac"])
	fracs.sort()
	var n := fracs.size()
	var p95_idx := clampi(int(ceil(0.95 * n)) - 1, 0, n - 1)
	var max_frac: float = fracs[n - 1]
	var p95: float = fracs[p95_idx]
	var mean := 0.0
	for f in fracs:
		mean += f
	mean /= float(n)
	# Which sample produced the max, and at what lead (VISIBLE) or run time
	# (INTRO) -- the number alone does not say WHEN the worst framing
	# happens, and that is the thing worth knowing to sanity-check the fix.
	var worst_sample: Dictionary = {}
	for s in samples:
		if s["frac"] == max_frac:
			worst_sample = s
			break
	print("%s: %d samples" % [label, n])
	print("  mean occupancy   : %.1f%%" % (mean * 100.0))
	print("  p95 occupancy    : %.1f%%" % (p95 * 100.0))
	print("  max occupancy    : %.1f%%" % (max_frac * 100.0))
	if worst_sample.has("lead"):
		print("  max occurred at  : lead=%.2fs" % worst_sample["lead"])
	elif worst_sample.has("t"):
		# "run_t" alone, no "(intro)" suffix -- this {"t", "frac"} shape is
		# now shared with the CAPTURE bucket too (see _sample), and a
		# hardcoded "(intro)" here would mislabel a CAPTURE population's own
		# worst sample.
		print("  max occurred at  : run_t=%.2fs" % worst_sample["t"])

func _max_frac(samples: Array[Dictionary]) -> float:
	var m := 0.0
	for s in samples:
		m = maxf(m, s["frac"])
	return m

# ---------------------------------------------------------------------
# BOT -- lifted from PursuerAudit.gd's SAFE bot, see that file's class doc
# for why these probes duplicate this rather than share it.
# ---------------------------------------------------------------------

func _drive_safe_bot() -> void:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var own: float = lane_ttc[_keepy.lane_index]
	if own < 0.0 or own > SAFE_ESCAPE_LEAD_S:
		return
	var own_obstacle := _nearest_obstacle_on_lane(_keepy.lane_index)
	if own_obstacle != null and Obstacle.blocks_lane_switch(own_obstacle.obstacle_type):
		if own <= HALF_AIR_TIME_S and _keepy.is_on_floor():
			_keepy.velocity.y = Keepy.JUMP_VELOCITY
		return
	var best_step := 0
	var best_ttc := own
	for step in [-1, 1]:
		var lane: int = _keepy.lane_index + step
		if lane < 0 or lane > 2:
			continue
		# A lane shut by a track-shrink window is not a destination. A
		# no-op without the mechanic (lane_blocked is always false then),
		# so it leaves every pre-shrink measurement byte-identical -- but
		# without it the bot keeps CHOOSING that lane, because it is empty
		# and therefore looks like the safest option on the board, has the
		# move refused by Keepy.move_lane, and stands still in front of
		# the hazard it meant to escape. That measures the bot's blindness
		# to a wall it cannot see, not the difficulty of the game.
		if GameState.lane_blocked(lane):
			continue
		var ttc: float = lane_ttc[lane] if lane_ttc[lane] >= 0.0 else INF
		if ttc > best_ttc:
			best_ttc = ttc
			best_step = step
	if best_step != 0:
		_keepy.move_lane(best_step)

var _lane_ttc_scratch: Array[float] = [-1.0, -1.0, -1.0]

func _nearest_hazard_ttc_per_lane() -> Array[float]:
	for lane in 3:
		_lane_ttc_scratch[lane] = -1.0
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		var ttc: float = obstacle.time_to_contact_s()
		if ttc <= 0.0:
			continue
		var lane := _lane_index_for_x(obstacle.position.x)
		if lane == -1:
			continue
		if _lane_ttc_scratch[lane] < 0.0 or ttc < _lane_ttc_scratch[lane]:
			_lane_ttc_scratch[lane] = ttc
	return _lane_ttc_scratch

func _nearest_obstacle_on_lane(lane: int) -> Obstacle:
	var best: Obstacle = null
	var best_ttc := INF
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		if _lane_index_for_x(obstacle.position.x) != lane:
			continue
		var ttc: float = obstacle.time_to_contact_s()
		if ttc <= 0.0 or ttc >= best_ttc:
			continue
		best_ttc = ttc
		best = obstacle
	return best

func _active_obstacle_in(segment: TrackSegment) -> Obstacle:
	for child in segment.get_children():
		if child is Obstacle and child.visible:
			return child
	return null

func _lane_index_for_x(x: float) -> int:
	for lane in TrackSegment.LANE_X.size():
		if absf(x - TrackSegment.LANE_X[lane]) < 0.01:
			return lane
	return -1
