extends Node
## Dev-only: does pushing the pursuer back ever actually READ as pushing it
## back? Written for a specific playtest report -- "il ne recule jamais,
## meme quand j'enchaine les combos" -- and deliberately split into the two
## independent questions that report could mean, because they have different
## answers and a single number would hide that.
##
## =====================================================================
## PHASE VISUAL -- does the silhouette RECEDE, or only vanish?
##
## Pursuer.gd derives its pose from the live lead every frame
## (position.z = lerpf(FAR_Z, CAUGHT_Z, t), scale = lerpf(FAR_SCALE,
## NEAR_SCALE, t)), so "the visual does not track the lead" is a claim that
## can be checked rather than argued. This phase checks it the only way that
## settles it: sample the REAL node's screen occupancy -- the same AABB
## unprojection PursuerFramingAudit.gd already uses as its budget metric --
## at leads swept across the whole visible band, and report the curve.
##
## The metric is SCREEN OCCUPANCY and not position.z on purpose. Z is what
## the code writes; occupancy is what the player sees. They are not the same
## question, and this probe exists because the second one is the one that was
## reported.
##
## Sway and bob are held at zero (the animation phase is reset before each
## sample), so the only thing moving between samples is the lead. A curve
## measured with a live sine wave running through it would confound the cue
## under test with an oscillation that is present at every lead.
##
## =====================================================================
## PHASE CADENCE -- does pursuer_lost_sight ever fire in real play?
##
## The lead is pushed back by GameState.register_risk_event
## (+PURSUER_RISK_REWARD_S, capped at PURSUER_MAX_LEAD_S) and drains at
## PURSUER_CLOSE_RATE once past PURSUER_GRACE_S. Whether those two ever net
## out to a CROSSING back above PURSUER_VISIBLE_LEAD_S -- the moment the
## pursuer is actually driven off -- is arithmetic nobody has measured.
##
## Driven through the REAL GameState (start_run, advance_time,
## register_strike, register_risk_event), never a re-derivation of its
## arithmetic here: a probe that recomputes the formula it is checking can
## only ever confirm its own copy of it.
##
## NO BOT AND NO TRACK, and that is the point rather than a shortcut. A bot
## meets a risk event by chance, so its event RATE is an outcome of the seed
## and the track rather than a thing this probe can state and vary. The
## question here is explicitly "at a human-plausible cadence, does the
## pushback land" -- so the cadence has to be the INPUT. StrikeAudit's bot
## profiles are the right instrument for "what kills a player of skill X";
## they are the wrong one for "hold the event rate fixed and watch the lead",
## because they cannot hold it fixed.
##
## The rates swept are anchored on rates this project has already MEASURED
## rather than invented here -- see CADENCES.
##
## Excluded from the web export (export_presets.cfg excludes scripts/dev/*),
## never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/PursuerPushbackAudit.tscn -- --seed=20260806

## Leads to sample the silhouette at, in seconds, from the visibility
## threshold down to the capture floor. Includes both endpoints of the band
## Pursuer.gd's own lerp is defined over, so the reported spread IS the full
## dynamic range of the cue -- not a subset of it that could understate it.
const SAMPLE_LEADS: Array[float] = [10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0, 0.0]

## Risk events per minute, each with the source it is taken from. These are
## MEASURED rates from this repo, not guesses:
##   1.6  -- ComboAudit's SAFE bot (quoted in GameState.PURSUER_RISK_REWARD_S)
##   13.5 -- PursuerAudit's INTERMEDIATE bot (quoted in PURSUER_CLOSE_RATE)
##   16.7 -- ComboAudit's RISKY bot (quoted in PURSUER_RISK_REWARD_S)
##   24.0 -- above anything measured here: the "stringing combos on purpose"
##           ceiling the playtest report describes, included so a negative
##           result cannot be dismissed as "he was just playing better than
##           the bots".
const CADENCES: Array[float] = [1.6, 13.5, 16.7, 24.0]

## How long each cadence is simulated for, in seconds of run time. Long
## enough that a slow crossing has room to happen (the worst case below is
## ~60s of sustained play per crossing) without any single phase dominating
## the probe's wall clock.
const CADENCE_RUN_S: float = 300.0

## Simulation step. 1/60 to match --fixed-fps 60, so the drain is integrated
## at the same granularity the shipped game integrates it at.
const STEP_S: float = 1.0 / 60.0

## The lead a stumble clamps to -- read from GameState rather than restated,
## since the whole scenario below is "you got hit, now push it back".
var _cap_lead: float = GameState.STRIKE_PURSUER_LEAD_CAP_S

var _game: Node = null
var _pursuer: Node3D = null
var _pursuer_mesh: MeshInstance3D = null
var _camera: Camera3D = null
var _keepy: Node3D = null

var _lost_sight_count: int = 0
var _became_visible_count: int = 0

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a
	# watchdog armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "PursuerPushbackAudit")
	var seeded := DevSeed.apply()
	print("=== PURSUER PUSHBACK AUDIT ===")
	print("rng                : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("visible below      : lead <= %.1fs (GameState.PURSUER_VISIBLE_LEAD_S)" % GameState.PURSUER_VISIBLE_LEAD_S)
	print("strike caps lead to: %.1fs (STRIKE_PURSUER_LEAD_CAP_S)" % GameState.STRIKE_PURSUER_LEAD_CAP_S)
	print("reward / drain     : +%.2fs per risk event / -%.2fs per second" % [
		GameState.PURSUER_RISK_REWARD_S, GameState.PURSUER_CLOSE_RATE])
	print("")

	_phase_visual()
	_phase_cadence()
	print("")
	print("This probe reports; it does not gate. Both phases are descriptions of")
	print("current behaviour, not contracts -- see the class doc.")
	get_tree().quit(0)

# =====================================================================
# PHASE VISUAL
# =====================================================================

func _phase_visual() -> void:
	print("--- PHASE VISUAL: what the silhouette does as the lead moves ---")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_camera = _game.get_node("World/CameraFollow")
	_pursuer = _game.get_node("World/Pursuer")
	_pursuer_mesh = _pursuer.get_node("Silhouette")

	# Park the camera at its steady-state pose rather than wherever one
	# lerped frame left it: CameraFollow converges exponentially, so an
	# early frame's camera is a transient the player never actually plays
	# with, and every occupancy below would be measured through it.
	_camera.position = _keepy.position + _camera.offset
	_camera.look_at(_keepy.position + _camera.look_ahead, Vector3.UP)

	GameState.start_run()
	# The opening sighting owns the node's pose outright for its first
	# INTRO_DURATION_S (see Pursuer._process's guard order), and it holds a
	# FIXED pose that ignores the lead -- exactly the thing this phase is
	# measuring the variation of. Retiring it is what lets the ordinary,
	# lead-driven branch run at t=0.
	_pursuer._intro_active = false
	GameState.pursuer_visible = true

	print("  camera at %s, looking at %s" % [_camera.position, _keepy.position + _camera.look_ahead])
	print("  lead     t      pos.z   scale   dist-to-cam   screen occupancy")
	var first_frac := -1.0
	var last_frac := -1.0
	var min_frac := INF
	var max_frac := -INF
	for lead in SAMPLE_LEADS:
		GameState.pursuer_lead_s = lead
		# Zero the animation phase every sample so sway/bob contribute
		# exactly 0 -- see the class doc.
		_pursuer._anim_t = 0.0
		_pursuer._process(0.0)
		var t := clampf(1.0 - lead / GameState.PURSUER_VISIBLE_LEAD_S, 0.0, 1.0)
		var frac := _occupancy_fraction()
		var dist := _camera.position.distance_to(_pursuer.position)
		print("  %5.1fs  %.2f   %5.2f   %5.3f   %8.2f      %.2f%%" % [
			lead, t, _pursuer.position.z, _pursuer.scale.x, dist, frac * 100.0])
		if first_frac < 0.0:
			first_frac = frac
		last_frac = frac
		min_frac = minf(min_frac, frac)
		max_frac = maxf(max_frac, frac)

	print("")
	print("  at the visibility threshold : %.2f%% of screen height" % (first_frac * 100.0))
	print("  at zero lead (capture)      : %.2f%% of screen height" % (last_frac * 100.0))
	var growth := (last_frac / first_frac - 1.0) * 100.0 if first_frac > 0.0 else 0.0
	print("  total change across the band: %+.1f%% relative (min %.2f%%, max %.2f%%)" % [
		growth, min_frac * 100.0, max_frac * 100.0])
	print("  the cut at threshold        : %.2f%% -> 0.00%% in ONE frame (visible = false)" % (first_frac * 100.0))
	print("")
	_game.process_mode = Node.PROCESS_MODE_DISABLED
	# free(), not queue_free(): this phase is the LAST thing that touches the
	# scene and the probe quits before the next idle frame, so a deferred free
	# would never be serviced and the run would end on a leaked-instances
	# warning -- noise on stderr that a future reader would have to rule out.
	remove_child(_game)
	_game.free()
	_game = null

## Lifted from PursuerFramingAudit._occupancy_fraction -- the same metric,
## deliberately, so the two probes' numbers are comparable rather than two
## nearby notions of "how big is it". Duplicated rather than shared for the
## reason this folder duplicates bots: each probe reads standalone, and a
## shared-helper edit can never quietly change what the other one measures.
func _occupancy_fraction() -> float:
	var aabb: AABB = _pursuer_mesh.visual_aabb()
	var gt: Transform3D = _pursuer_mesh.global_transform
	var vp_h: float = get_viewport().get_visible_rect().size.y
	var min_y := INF
	var max_y := -INF
	for i in 8:
		var corner: Vector3 = aabb.position + Vector3(
			aabb.size.x * float(i & 1),
			aabb.size.y * float((i >> 1) & 1),
			aabb.size.z * float((i >> 2) & 1))
		var screen := _camera.unproject_position(gt * corner)
		min_y = minf(min_y, screen.y)
		max_y = maxf(max_y, screen.y)
	var top := clampf(min_y, 0.0, vp_h)
	var bottom := clampf(max_y, 0.0, vp_h)
	return (bottom - top) / vp_h

# =====================================================================
# PHASE CADENCE
# =====================================================================

func _phase_cadence() -> void:
	print("--- PHASE CADENCE: does the lead ever climb back out of sight? ---")
	print("  scenario: one stumble at t=%.0fs (lead clamped to %.1fs, pursuer on screen)," % [
		GameState.PURSUER_GRACE_S + 1.0, _cap_lead])
	print("            then a steady risk-event cadence for %.0fs of clean play." % CADENCE_RUN_S)
	print("            No further contacts -- the most favourable case for a pushback.")
	print("")
	print("  events/min   net lead/event   time to 1st push-off   crossings   visible %   final lead")
	for rate in CADENCES:
		var result := _run_cadence(rate)
		var first: float = result["first_lost_sight_s"]
		var first_str := ("%.1fs" % first) if first >= 0.0 else "never"
		print("  %8.1f   %+13.3fs   %20s   %9d   %8.1f%%   %8.2fs" % [
			rate, result["net_per_event"], first_str, result["lost_sight"],
			result["visible_frac"] * 100.0, result["final_lead"]])
	print("")
	print("  'net lead/event' is the measured average change in lead between one")
	print("  credited event and the next -- reward minus the drain paid waiting for it.")
	print("  A negative value means the cadence cannot push the pursuer back at all.")
	print("  'time to 1st push-off' is the seconds of SUSTAINED CLEAN PLAY after the")
	print("  stumble before the pursuer leaves the screen -- the thing the player is")
	print("  actually waiting through, and the number the playtest report is about.")

func _run_cadence(events_per_min: float) -> Dictionary:
	GameState.start_run()
	_lost_sight_count = 0
	_became_visible_count = 0
	if not GameState.pursuer_lost_sight.is_connected(_on_lost_sight):
		GameState.pursuer_lost_sight.connect(_on_lost_sight)
	if not GameState.pursuer_became_visible.is_connected(_on_became_visible):
		GameState.pursuer_became_visible.connect(_on_became_visible)

	# Clear the grace window, then take ONE contact through the real entry
	# point so the lead is clamped exactly as a stumble clamps it.
	var t := 0.0
	while t < GameState.PURSUER_GRACE_S + 1.0:
		GameState.advance_time(STEP_S)
		t += STEP_S
	GameState.register_strike(Obstacle.Type.DODGE)

	var interval := 60.0 / events_per_min
	var next_event_at := GameState.run_time_s + interval
	var visible_time := 0.0
	var elapsed := 0.0
	var events := 0
	var lead_at_last_event := GameState.pursuer_lead_s
	var net_sum := 0.0
	var first_lost_sight_s := -1.0
	var seen_before := _lost_sight_count
	while elapsed < CADENCE_RUN_S and GameState.state == GameState.State.PLAYING:
		GameState.advance_time(STEP_S)
		elapsed += STEP_S
		if _lost_sight_count > seen_before and first_lost_sight_s < 0.0:
			first_lost_sight_s = elapsed
		if GameState.pursuer_visible:
			visible_time += STEP_S
		if GameState.run_time_s >= next_event_at:
			GameState.register_risk_event(GameState.RiskEvent.NEAR_MISS)
			events += 1
			net_sum += GameState.pursuer_lead_s - lead_at_last_event
			lead_at_last_event = GameState.pursuer_lead_s
			next_event_at += interval

	return {
		"lost_sight": _lost_sight_count,
		"visible_frac": visible_time / maxf(elapsed, STEP_S),
		"final_lead": GameState.pursuer_lead_s,
		"net_per_event": net_sum / maxf(float(events), 1.0),
		"first_lost_sight_s": first_lost_sight_s,
	}

func _on_lost_sight() -> void:
	_lost_sight_count += 1

func _on_became_visible() -> void:
	_became_visible_count += 1
