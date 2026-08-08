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

var _label: String = ""
var _budget_s: float = DEFAULT_BUDGET_S
var _started_ms: int = 0

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

func _ready() -> void:
	_started_ms = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	var elapsed := float(Time.get_ticks_msec() - _started_ms) / 1000.0
	if elapsed < _budget_s:
		return
	print("")
	print("%s INCONCLUSIVE: ran %.0fs of wall clock without reaching its own" % [_label, elapsed])
	print("  completion check, and was stopped by ProbeWatchdog rather than left running.")
	print("  This is NOT a verdict on what the probe measures -- nothing was verified,")
	print("  and nothing was refuted. Something stopped the probe from finishing.")
	print("")
	print("  GameState at the timeout: state=%s  death_cause=%s  run_time=%.2fs" % [
		_state_name(GameState.state), _cause_name(GameState.death_cause), GameState.run_time_s])
	print("")
	print("  FIRST THING TO CHECK: a probe that advances its simulated clock only")
	print("  while state == PLAYING has a clock that stops for good as soon as the run")
	print("  ends by a path its neutered collision does not control -- the pursuer being")
	print("  the one that exists today. If the state above is not PLAYING, that is almost")
	print("  certainly what happened; see GameState.pursuer_enabled.")
	get_tree().quit(EXIT_TIMEOUT)

func _state_name(s: int) -> String:
	match s:
		GameState.State.TITLE: return "TITLE"
		GameState.State.PLAYING: return "PLAYING"
		GameState.State.CAPTURED: return "CAPTURED"
		GameState.State.GAME_OVER: return "GAME_OVER"
		_: return "?(%d)" % s

func _cause_name(c: int) -> String:
	match c:
		GameState.DeathCause.COLLISION: return "COLLISION"
		GameState.DeathCause.PURSUER: return "PURSUER"
		_: return "?(%d)" % c
