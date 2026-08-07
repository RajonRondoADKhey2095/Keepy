extends Node
## Dev-only performance probe. Boots the real Game.tscn (real GameState,
## real TrackManager, real pooled Obstacle instances) and MEASURES --
## rather than guesses at -- the per-frame engine cost of a standard run.
##
## MEASUREMENT TECHNIQUE, AND WHY IT IS NOT Performance.get_monitor() --
## the obvious first choice (Performance.TIME_PROCESS / TIME_PHYSICS_PROCESS)
## was tried first and rejected: measured empirically (not assumed), those
## two monitors turn out to refresh on their OWN internal cadence, not
## once per frame -- sampling them once per physics tick under
## `--headless --fixed-fps 60` (which runs the loop AS FAST AS THE CPU
## ALLOWS, not paced to real 60Hz -- a 65s simulated run completed in
## ~1.6s of real wall time, checked directly) returned exactly 0.0 for
## the overwhelming majority of ticks and the SAME single repeated
## nonzero value for the top ~5%, which is the signature of a value that
## updates roughly once per real second rather than once per frame -- not
## a usable source of per-FRAME percentiles.
##
## Instead this probe times itself: `Time.get_ticks_usec()` sampled once
## per `_physics_process` call, delta against the previous sample. Since
## this probe's own physics_process runs once per physics tick alongside
## every other node in the tree, the wall-clock gap between two
## consecutive samples IS the real, unthrottled cost of everything the
## engine did in between -- physics step, every node's _physics_process
## (including every pooled Obstacle's), GameState's idle _process, and
## engine bookkeeping. A raw OS clock query has no refresh-cadence
## surprise the way a profiler monitor object can.
##
## WHY THIS EXISTS -- player feedback said the lane-switch feel regressed
## "plus ou moins tout le temps", not just around the STOMPER. That rules
## out a one-off spike from a single dramatic obstacle and points at
## CUMULATIVE per-frame cost from everything the last four batches added
## (pursuer, STOMPER, combo, risk detection) that now runs every frame
## regardless of whether anything from it is currently on screen. This
## probe exists to prove or disprove that with numbers, not opinion.
##
## Collision is neutered (same technique as PacingAudit.gd/ChargerAudit.gd)
## so the run survives the whole measurement window uninterrupted.
##
## WARM-UP: the first WARMUP_SECONDS are run but NOT recorded -- shader
## compilation, pool pre-fill and the first few TrackSegment recycles are
## one-off engine/scene costs that have nothing to do with per-frame
## script cost and would only pollute the tail percentiles the whole
## point of this probe is to read cleanly.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/PerfProbe.tscn -- --seed=<int> --label=<text>
##
## `--seed` is optional (see DevSeed.gd) but STRONGLY recommended when
## comparing two states of the code/repo against each other -- otherwise
## a difference in the numbers could just as well be a difference in
## which random obstacles happened to spawn.

const WARMUP_SECONDS: float = 5.0
## Not the full 60s asked for at the call site's face value -- this probe
## never dodges anything (see the collision-neutering note below), so it
## registers zero risk events, and MEASURED (not assumed): with the
## pursuer active and default GameState constants (PURSUER_GRACE_S=5,
## PURSUER_START_LEAD_S=12, PURSUER_CLOSE_RATE=0.20), a run that never
## banks a single risk event gets caught at t=65.02s on the nose, ending
## the run (GameState.state -> GAME_OVER) and, with it, every per-frame
## system this probe exists to measure (GameState._process stops calling
## advance_time; Obstacle._physics_process's very first line is `if
## GameState.state != PLAYING: return`). Recording past that point would
## silently mix real gameplay cost with idle-game-over-screen cost.
## WARMUP_SECONDS + SIM_SECONDS is kept comfortably under 65.02s so the
## same catch never lands mid-recording in any of the three states this
## probe is used to compare (see the run report for how each was found
## to behave here).
const SIM_SECONDS: float = 50.0

var _game: Node3D
var _keepy: Keepy

var _t: float = 0.0
var _recording: bool = false
var _last_usec: int = -1

## Per-frame wall-clock cost of everything the engine did since the
## previous physics tick -- see the class doc for why this is measured
## directly rather than read from Performance.get_monitor().
var _frame_ms: PackedFloat64Array = PackedFloat64Array()

func _ready() -> void:
	# Must run BEFORE Game.tscn is instantiated below -- see DevSeed.gd.
	var seeded := DevSeed.apply()
	var label := _label_arg()
	var no_pursuer := _no_pursuer_arg()
	if no_pursuer:
		# The ONE runtime-togglable half of "isolate the background cost
		# with nothing ever visible" -- see GameState.pursuer_enabled's
		# own doc, same toggle AntiFrustrationAudit.gd/StomperConflictAudit.gd
		# already use to take the pursuer out of a probe run. STOMPER's
		# and CHARGER's own spawn chances are `const`, not runtime
		# togglable from here -- excluding them for the same comparison
		# takes a temporary, NEVER-COMMITTED edit to
		# TrackManager.STOMPER_CHANCE_PER_ROW / CHARGER_CHANCE_PER_ROW
		# instead (see the run report for exactly how that scenario was
		# produced and reverted).
		GameState.pursuer_enabled = false
	print("=== PERF PROBE ===")
	print("label  : %s" % label)
	print("rng    : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("pursuer: %s" % ("disabled (--no-pursuer)" if no_pursuer else "enabled (default)"))
	print("warmup : %.1fs (unrecorded)" % WARMUP_SECONDS)
	print("window : %.1fs (recorded)" % SIM_SECONDS)
	print("")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	# See the header note: this is what keeps the probe alive for the
	# whole window regardless of what it runs into. Touches no gameplay
	# source file (same technique as every other probe in this folder).
	_keepy.collision_layer = 0

func _label_arg() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="):
			return arg.substr("--label=".length())
	return "(unlabeled)"

func _no_pursuer_arg() -> bool:
	return OS.get_cmdline_user_args().has("--no-pursuer")

func _physics_process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	_t += delta
	if _last_usec >= 0:
		var frame_ms := float(now - _last_usec) / 1000.0
		if not _recording and _t >= WARMUP_SECONDS:
			_recording = true
		if _recording:
			_frame_ms.append(frame_ms)
	_last_usec = now
	# Safety net, not the expected path (see SIM_SECONDS's own doc on why
	# it is sized to stay clear of the pursuer's catch time): if the run
	# ends anyway, stop and report on whatever was actually recorded
	# rather than silently measuring an idle game-over screen.
	if GameState.state != GameState.State.PLAYING:
		push_warning("run ended early at t=%.2fs (state=%s) -- results below cover only what was actually recorded" % [_t, GameState.state])
		_summary()
		get_tree().quit()
		return
	if _t >= WARMUP_SECONDS + SIM_SECONDS:
		_summary()
		get_tree().quit()

func _summary() -> void:
	print("--- results (%d samples) ---" % _frame_ms.size())
	_print_stats("frame wall time (full iteration: physics step, every node's", _frame_ms)
	print("  _physics_process, idle _process, engine bookkeeping)")

func _print_stats(title: String, samples: PackedFloat64Array) -> void:
	var sorted := samples.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n == 0:
		print("%s: no samples" % title)
		return
	var sum := 0.0
	for v in sorted:
		sum += v
	var mean := sum / n
	var p50 := sorted[int(n * 0.50)]
	var p95 := sorted[mini(int(n * 0.95), n - 1)]
	var p99 := sorted[mini(int(n * 0.99), n - 1)]
	var worst := sorted[n - 1]
	print("%s" % title)
	print("    mean=%.4fms  p50=%.4fms  p95=%.4fms  p99=%.4fms  max=%.4fms"
		% [mean, p50, p95, p99, worst])
