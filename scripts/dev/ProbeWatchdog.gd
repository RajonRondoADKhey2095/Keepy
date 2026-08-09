extends Node
class_name ProbeWatchdog
## Dev-only: the guarantee that NO probe in this folder can run forever.
##
## =====================================================================
## WHY THIS EXISTS
##
## Two probes here did not terminate -- ChargerAudit and
## AirEnemyLandingLaneAudit -- and the way that failure presents is the
## problem, not the failure itself. Both printed their header and then
## produced nothing, at full CPU, indefinitely. From the outside that is
## indistinguishable from "this probe is slow", which is exactly how it
## survived: docs/PROBE_AUDIT.md recorded it as "should be expected to
## take a very long time" and the README documented both as runnable.
## They were not slow. They were stopped, and had been since the pursuer
## landed on 08-06.
##
## The mechanism is worth stating, because anything with the same shape
## will do it again. A probe that neuters collision so one continuous run
## can cover its whole sample, and that advances its own simulated clock
## only while `GameState.state == PLAYING`, has a clock that STOPS the
## moment anything ends the run by a path collision does not control --
## the pursuer being the one that exists today. Its completion check is
## written against that clock, so the check becomes unreachable and the
## probe spins on a frozen number forever.
##
## The per-probe fix is GameState.pursuer_enabled (see its own doc). This
## file is the fix for the CLASS: a probe that cannot finish must say so
## and exit, rather than occupy a terminal until someone kills it. A probe
## that gives up and reports INCONCLUSIVE is strictly more useful than one
## that runs for fifty minutes and reports nothing -- the first is a
## result, the second is an absence of one.
##
## =====================================================================
## WHY IT MEASURES WALL-CLOCK, AND WHY IT RUNS IN _process
##
## Both choices are load-bearing against the failure above.
##
## WALL CLOCK, not the probe's simulated time: the defect being guarded
## against is precisely a simulated clock that has stopped. A budget
## denominated in the frozen quantity could never expire.
##
## _process, not _physics_process, and PROCESS_MODE_ALWAYS: the watchdog
## must keep running under conditions that have already silenced the probe
## it is watching. A probe's own `_physics_process` early-returns on
## `state != PLAYING`; a watchdog sharing that method would inherit the
## same blindness. PROCESS_MODE_ALWAYS additionally survives
## `get_tree().paused`, which no probe sets today but which would
## otherwise reintroduce the same hole silently.
##
## It deliberately reads NOTHING from the probe it guards. Any coupling --
## "has the probe made progress recently?" -- would be one more thing that
## can be wired up wrongly, in a file whose entire job is to work when
## other things are wired up wrongly.
##
## =====================================================================
## WHAT IT REPORTS
##
## On expiry it prints GameState's state and death cause before quitting,
## because that single line is what turns "it hung" into a diagnosis. For
## the two probes this file was written for it reads
## `state=GAME_OVER  death_cause=PURSUER`, which names the cause outright.
##
## =====================================================================
## THE ONE THING arm() CANNOT BOUND, AND WHAT COVERS IT
##
## `_process` is only called BETWEEN frames. A probe that does all its
## work inside a single call that never yields -- a `for` loop in
## `_ready()`, or an `_init()` on a `--script` SceneTree -- never gives
## the engine a frame to run this node in, so a watchdog armed on it is
## armed and mute. `arm()` bounds probes that iterate; it cannot bound
## probes that block.
##
## That is not hypothetical in this folder: DecorParallaxProbe runs 2000
## iterations inside `_ready()`, and PacingProbe is a `--script` SceneTree
## whose whole run happens in `_init()` before any frame exists at all.
## Arming those two and calling the folder covered would have been the
## exact failure this file was written about -- a guarantee that reports
## itself as present while being structurally unable to fire.
##
## `deadline()` covers that shape: a wall-clock budget the blocking loop
## checks itself, reporting the SAME verdict with the SAME exit code. The
## two entry points are one mechanism, and between them every probe in
## this folder is bounded whatever its shape. ProbeTimeoutAudit is what
## keeps that true for probes not written yet.

## Wall-clock seconds a probe may run before it is declared INCONCLUSIVE.
##
## DERIVED FROM MEASUREMENT, not picked. Every probe in this folder was
## timed at seed 20260806 on a 4-core headless CI-class machine; the
## slowest that genuinely finishes is StrikeAudit at 227s, followed by
## PursuerAudit at 166s and DarkPaletteAudit at 155s. 900s is therefore
## roughly 4x the slowest real runtime -- wide enough that ordinary
## machine-to-machine variance, a debug build or a loaded CI runner cannot
## trip it, narrow enough that a genuinely stuck probe is caught in
## minutes instead of never.
##
## The bar for raising this is a probe that legitimately needs longer, not
## a probe that is behaving like the two this file was written for. If a
## probe starts timing out, the first question is what stopped its clock.
const DEFAULT_BUDGET_S: float = 900.0

## Exit code for "ran out of wall clock". Deliberately NOT 1: the folder's
## convention is 0 = the contract holds, 1 = the contract is violated, and
## a timeout is neither. It is the absence of a verdict, and a caller that
## treats it as a failed assertion would be reporting a finding the probe
## never made -- the same confusion between "verified" and "never
## exercised" that ProbeCoverage.gd exists to prevent.
const EXIT_TIMEOUT: int = 2

## Seconds the run clock must sit unchanged before "frozen" is the honest
## word for it. Well above any single-frame hitch, well below the budget.
const CLOCK_STALL_S: float = 5.0

var _label: String = ""
var _budget_s: float = DEFAULT_BUDGET_S
var _started_ms: int = 0

## Last observed run clock, and when it last MOVED. Sampled every frame so
## a timeout can say whether the probe was frozen or merely slow -- the two
## need opposite next steps, and nothing else in the output separates them.
var _last_run_time: float = -1.0
var _last_progress_ms: int = 0

## The GameState autoload, resolved ONCE by path rather than referenced by
## name. Nothing in this file may name that identifier at compile time:
## PacingProbe is a `--script` SceneTree where the autoload does not
## exist, and GDScript resolves the name when the SCRIPT is compiled, not
## when the line runs. MEASURED -- an earlier revision of this file read
## `GameState.run_time_s` in _process and PacingProbe died with
## `Compile Error: Identifier not found: GameState`, cascading through
## ProbeDeadline into the probe itself. The timeout became the thing that
## broke the run it was supposed to bound.
var _gs: Node = null

## Arms a watchdog on `probe`, which is the probe's own root Node. Call it
## as the FIRST statement of _ready(), before anything that could itself
## hang -- a watchdog armed after the hang is no watchdog.
##
##   func _ready() -> void:
##       ProbeWatchdog.arm(self, "CHARGER AUDIT")
static func arm(probe: Node, label: String, budget_s: float = DEFAULT_BUDGET_S) -> ProbeWatchdog:
	var dog := ProbeWatchdog.new()
	dog.name = "ProbeWatchdog"
	dog._label = label
	dog._budget_s = budget_s
	dog.process_mode = Node.PROCESS_MODE_ALWAYS
	probe.add_child(dog)
	return dog

## The other entry point, for a probe whose work happens inside ONE call
## that never yields a frame -- see the header section on what arm()
## cannot bound. The loop asks the returned object whether it is out of
## time; there is no other way in, because there is no frame for anything
## else to run in.
##
##   func _ready() -> void:
##       ProbeWatchdog.arm(self, "DECOR PARALLAX PROBE")
##       var dl := ProbeWatchdog.deadline("DECOR PARALLAX PROBE")
##       for frame in 2000:
##           if dl.exceeded():
##               dl.abort()       # prints the same verdict, quits 2
##               return
##
## Both entry points are used together where a probe has both shapes: the
## cost of arm() is one inert node, and being wrong about which shape a
## probe will have after its next edit is not a risk worth taking.
static func deadline(label: String, budget_s: float = DEFAULT_BUDGET_S) -> ProbeDeadline:
	return ProbeDeadline.new(label, budget_s)

## The INCONCLUSIVE verdict, in ONE place because both entry points must
## produce the SAME one. A timeout reported two ways is a timeout a caller
## can learn to recognise in one form and miss in the other -- and the
## whole value of this file is that its output is unmistakable.
## `stalled_s` is how long the run clock has been FROZEN when the budget
## ran out, or -1.0 where that could not be observed (the ProbeDeadline
## path runs in a blocking loop with no frames to sample from).
##
## It exists because "it hung" and "it is slow" need OPPOSITE next steps,
## and the state line alone does not separate them -- which was measured,
## not guessed. See the two causes named below.
static func report_inconclusive(label: String, elapsed_s: float, budget_s: float,
		stalled_s: float = -1.0) -> void:
	print("")
	print("%s INCONCLUSIVE: ran %.0fs of wall clock (budget %.0fs) without reaching" % [
		label, elapsed_s, budget_s])
	print("  its own completion check, and was stopped rather than left running.")
	print("  This is NOT a verdict on what the probe measures -- nothing was verified,")
	print("  and nothing was refuted. Something stopped the probe from finishing.")
	print("")
	print("  GameState at the timeout: %s" % _gamestate_line())
	print("")
	_print_likely_cause(stalled_s)

## Names the likely cause instead of listing every cause. A timeout that
## always prints the same paragraph trains the reader to skip it, and the
## paragraph that was here pointed at the pursuer unconditionally -- which
## is wrong half the time, in a way that was measured:
##
##   ChargerAudit, run with `--fixed-fps 60` placed AFTER the bare `--`,
##   times out at 900s reporting `state=PLAYING run_time=899.88s`. It was
##   never stuck. It was 0.12 SIMULATED SECONDS from finishing, pacing at
##   ~1x real time because everything after `--` is handed to the app as
##   user args and the engine never saw the flag. The old text sent the
##   reader after a pursuer that had nothing to do with it.
static func _print_likely_cause(stalled_s: float) -> void:
	var state_ok := false
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var gs: Node = (loop as SceneTree).root.get_node_or_null("GameState")
		state_ok = gs != null and _state_name(int(gs.state)) == "PLAYING"
	if state_ok and stalled_s >= 0.0 and stalled_s < CLOCK_STALL_S:
		print("  LIKELY CAUSE -- NOT STUCK, JUST SLOW. The run clock was still advancing")
		print("  when the budget ran out (last moved %.1fs ago), and the state is PLAYING." % stalled_s)
		print("  A probe that is progressing normally and still runs out of wall clock is")
		print("  almost always pacing at ~1x REAL time, which means the engine never got")
		print("  `--fixed-fps 60`. Check the flag ORDER: engine flags go BEFORE the bare")
		print("  `--`, user args (like `--seed=`) after it. `--fixed-fps` placed after the")
		print("  `--` is silently handed to the app and ignored:")
		print("")
		print("    godot4 --headless --fixed-fps 60 --path . res://scripts/dev/X.tscn -- --seed=N")
		print("")
		print("  Re-run it that way before looking for a defect in the probe.")
		return
	print("  FIRST THING TO CHECK: a probe that advances its simulated clock only")
	print("  while state == PLAYING has a clock that stops for good as soon as the run")
	print("  ends by a path its neutered collision does not control -- the pursuer being")
	print("  the one that exists today. If the state above is not PLAYING, that is almost")
	print("  certainly what happened; see GameState.pursuer_enabled.")
	if stalled_s >= CLOCK_STALL_S:
		print("")
		print("  The run clock has been FROZEN for %.0fs, which is that symptom exactly." % stalled_s)

func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	_last_progress_ms = _started_ms
	_gs = get_node_or_null("/root/GameState")

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var run_time: float = _gs.run_time_s if _gs != null else -1.0
	if run_time != _last_run_time:
		_last_run_time = run_time
		_last_progress_ms = now
	var elapsed := float(now - _started_ms) / 1000.0
	if elapsed < _budget_s:
		return
	report_inconclusive(_label, elapsed, _budget_s,
		float(now - _last_progress_ms) / 1000.0)
	get_tree().quit(EXIT_TIMEOUT)

## GameState is looked up through the main loop rather than referenced as
## the autoload identifier, so this file also works where that autoload
## does not exist -- a `--script` SceneTree (PacingProbe) replaces the
## main loop before autoloads are registered, and a hard reference would
## make the timeout itself the thing that crashes. The state names are
## spelled out here rather than read off GameState.State for the same
## reason; they are asserted against the real enum by ProbeTimeoutAudit,
## so this copy cannot drift silently.
static func _gamestate_line() -> String:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var gs: Node = (loop as SceneTree).root.get_node_or_null("GameState")
		if gs != null:
			return "state=%s  death_cause=%s  run_time=%.2fs" % [
				_state_name(gs.state), _cause_name(gs.death_cause), gs.run_time_s]
	return "not available in this context (no GameState autoload -- --script main loop?)"

const STATE_NAMES: PackedStringArray = ["TITLE", "PLAYING", "CAPTURED", "GAME_OVER"]
const CAUSE_NAMES: PackedStringArray = ["COLLISION", "PURSUER"]

static func _state_name(s: int) -> String:
	return STATE_NAMES[s] if s >= 0 and s < STATE_NAMES.size() else "?(%d)" % s

static func _cause_name(c: int) -> String:
	return CAUSE_NAMES[c] if c >= 0 and c < CAUSE_NAMES.size() else "?(%d)" % c
