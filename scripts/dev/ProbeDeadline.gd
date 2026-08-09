extends RefCounted
class_name ProbeDeadline
## Dev-only: the wall-clock half of the no-probe-runs-forever guarantee,
## for probes that block instead of iterating.
##
## =====================================================================
## WHY A SECOND SHAPE EXISTS AT ALL
##
## ProbeWatchdog.arm() is a Node running in `_process`, and `_process` is
## only called BETWEEN frames. That is the right mechanism for the failure
## it was written for -- a probe spinning on frames with a frozen
## simulated clock -- and it is structurally unable to fire for a probe
## that never yields a frame in the first place.
##
## Two probes in this folder are exactly that:
##
##   DecorParallaxProbe  2000 iterations inside _ready(), before the
##                       engine has run a single frame of the scene.
##   PacingProbe         `--script` SceneTree; the entire run is in
##                       _init(), so there is no scene and no autoload,
##                       let alone a frame.
##
## Arming a watchdog on those and calling the folder covered is the same
## error this whole family of files exists to prevent: a guarantee that
## reports itself present while being incapable of firing. So the loop
## has to ask, because nothing else is running to ask on its behalf.
##
## =====================================================================
## WHY WALL CLOCK, AND WHY NOT AN ITERATION CAP
##
## Wall clock for the same reason ProbeWatchdog uses it: the quantity a
## stuck probe stops advancing is its own progress counter, so a budget
## denominated in iterations expires only if the loop is still looping.
## `Time.get_ticks_msec()` is OS time and is unaffected by --fixed-fps,
## which is precisely the property needed -- under --fixed-fps 60 a frame
## count and a second are not related by any fixed ratio, and a budget
## written in frames would mean a different real duration on every
## machine and every build.
##
## exceeded() is a subtraction and a compare, cheap enough to call every
## iteration of any loop in this folder. Nothing here allocates.

var _label: String = ""
var _budget_s: float = 0.0
var _started_ms: int = 0

func _init(label: String, budget_s: float = ProbeWatchdog.DEFAULT_BUDGET_S) -> void:
	_label = label
	_budget_s = budget_s
	_started_ms = Time.get_ticks_msec()

## Wall-clock seconds since this deadline was created.
func elapsed_s() -> float:
	return float(Time.get_ticks_msec() - _started_ms) / 1000.0

## True once the budget is spent. Safe to call every iteration.
func exceeded() -> bool:
	return elapsed_s() >= _budget_s

## Prints the shared INCONCLUSIVE verdict and quits with EXIT_TIMEOUT.
##
## The verdict text comes from ProbeWatchdog.report_inconclusive so that a
## timeout reads identically whichever shape of probe produced it -- a
## caller must not be able to recognise one form and miss the other.
##
## `tree` MUST be passed by a `--script` probe, and can be omitted by a
## probe running inside a normal scene. MEASURED, not assumed: a SceneTree
## subclass calling this from its own `_init()` gets NULL back from
## `Engine.get_main_loop()`, because the main loop is still being
## constructed at that point. The first version of this file looked the
## tree up and fell back to killing the process, and the --script timeout
## exited **137** (SIGKILL) instead of 2 -- a timeout that a caller would
## read as a crash, which is precisely the confusion EXIT_TIMEOUT exists
## to prevent. A probe that is a SceneTree already has the answer; it just
## has to say so.
func abort(tree: SceneTree = null) -> void:
	ProbeWatchdog.report_inconclusive(_label, elapsed_s(), _budget_s)
	var t := tree
	if t == null:
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			t = loop as SceneTree
	if t != null:
		t.quit(ProbeWatchdog.EXIT_TIMEOUT)
		return
	# Nothing that can set an exit code. Say so loudly rather than exiting
	# with a number that means something else: an unexplained 137 is worse
	# than a stated inability to report one.
	push_error("ProbeDeadline: no SceneTree to quit through -- pass one to abort(). "
		+ "Exit code will NOT be %d." % ProbeWatchdog.EXIT_TIMEOUT)
	print("  (could not set exit code %d -- no SceneTree available)" % ProbeWatchdog.EXIT_TIMEOUT)

## exceeded() + abort() in one call, for the common loop-guard line:
##
##     for frame in 2000:
##         if dl.abort_if_exceeded():
##             return
##
## Returns true when it has aborted, so the caller stops touching state
## the quit is about to tear down. quit() is deferred by the engine to the
## end of the frame, so the loop MUST return rather than assume it was
## stopped for it -- that is the whole reason this returns a bool.
func abort_if_exceeded(tree: SceneTree = null) -> bool:
	if not exceeded():
		return false
	abort(tree)
	return true
