extends Node
## Dev-only: asserts that EVERY probe in this folder is bounded by a
## wall-clock timeout -- including probes that do not exist yet.
##
## =====================================================================
## WHY THIS EXISTS
##
## ProbeWatchdog is opt-in. Every probe has to remember one line, and
## "everyone remembers" is not a guarantee -- it is the thing that keeps
## failing in this folder. It had already failed once before this file was
## written: DecorParallaxProbe, a real probe with its own scene, carried
## no timeout at all while docs/PROBE_AUDIT.md recorded the watchdog as
## "armed as the first statement of every probe's _ready()". That sentence
## was true of 26 files and false of the folder, and nothing could tell
## the difference.
##
## That is the same defect as every finding in PROBE_AUDIT.md, one level
## up again: not a probe that fails to test something, but a GUARANTEE
## that reports itself present without being checked. ProbeCoverage.gd
## makes "green on a mechanic that never ran" impossible; this file makes
## "a probe with no timeout" impossible, and for the same reason -- the
## check has to run on the thing it is checking, mechanically, every time.
##
## =====================================================================
## WHAT IT CHECKS, AND WHAT IT HONESTLY CANNOT
##
## CAN, mechanically:
##   1. every .tscn here names a script that arms a timeout;
##   2. a --script probe (extends SceneTree) uses a deadline, since a
##      watchdog node has no scene to live in there;
##   3. the timeout is armed BEFORE any other statement of _ready() -- a
##      watchdog armed after the hang is no watchdog;
##   4. ProbeWatchdog's local copy of GameState's state/cause names still
##      matches the real enums (it holds a copy so it can run where the
##      autoload does not exist; this is what stops that copy drifting);
##   5. the exemption list below has no stale entries.
##
## CANNOT: tell whether a probe picked the RIGHT shape. A probe that
## blocks inside _ready() and arms only the frame watchdog passes this
## audit and is still unbounded, because that distinction lives in control
## flow, not in text. Nothing here should be read as saying otherwise --
## the two mechanisms and when each applies are documented in
## ProbeWatchdog.gd's header, and choosing between them stays a judgement
## the author makes. What this file removes is the case where nobody
## chose at all.
##
## Deliberately does NOT instantiate anything: loading a probe scene would
## RUN that probe. Every check is against source text or against constants
## it can read without executing a probe.

const DEV_DIR := "res://scripts/dev"

## Files here are NOT probes and are exempt, each for a stated reason. A
## name that no longer exists is itself a failure: an exemption list that
## can rot silently is how a probe gets exempted by accident.
const NOT_PROBES := {
	"DevSeed.gd": "seeding helper, RefCounted -- no run of its own",
	"ProbeCoverage.gd": "coverage ledger helper, RefCounted -- no run of its own",
	"ProbeWatchdog.gd": "the timeout mechanism itself",
	"ProbeDeadline.gd": "the timeout mechanism itself",
	"SubstituteModel.tscn": "a dev ASSET (stand-in mesh for AssetContractAudit), not a probe",
	"HumanRefDriver.gd": "CH31 reference-player MODEL, RefCounted -- a driver a probe instantiates, no run of its own",
}

var _failures: Array[String] = []
var _checked_scenes := 0
var _checked_scripts := 0

func _ready() -> void:
	# Armed for the same reason as everything else here. This probe does
	# no simulation and cannot plausibly hang, which is exactly the
	# reasoning that left DecorParallaxProbe unbounded -- so it arms too.
	ProbeWatchdog.arm(self, "PROBE TIMEOUT AUDIT")
	print("=== PROBE TIMEOUT AUDIT ===")
	print("asserts every probe under %s is bounded by a wall-clock timeout" % DEV_DIR)
	print("budget: ProbeWatchdog.DEFAULT_BUDGET_S = %.0fs   timeout exit code = %d" % [
		ProbeWatchdog.DEFAULT_BUDGET_S, ProbeWatchdog.EXIT_TIMEOUT])
	print("")

	var files := _list_dev_files()
	if files.is_empty():
		_fail("could not enumerate %s -- the audit verified NOTHING" % DEV_DIR)
		_report()
		return

	_check_exemptions_are_live(files)
	_check_scenes(files)
	_check_script_probes(files)
	_check_state_name_tables()
	_report()

func _list_dev_files() -> PackedStringArray:
	var dir := DirAccess.open(DEV_DIR)
	if dir == null:
		return PackedStringArray()
	var out := PackedStringArray()
	for f in dir.get_files():
		# Running from source, .gd/.tscn are on disk as-is. Godot reports
		# imported resources with a trailing .remap in some contexts;
		# normalise so neither case is silently skipped.
		out.append(f.trim_suffix(".remap"))
	return out

## Every .tscn here is a probe entry point (someone can run it), so every
## one of them must name a script that arms a timeout.
func _check_scenes(files: PackedStringArray) -> void:
	print("-- probe scenes --")
	for f in files:
		if not f.ends_with(".tscn") or NOT_PROBES.has(f):
			continue
		_checked_scenes += 1
		var scene_path := "%s/%s" % [DEV_DIR, f]
		var script_path := _script_path_of_scene(scene_path)
		if script_path == "":
			_fail("%s names no script -- cannot be a probe, and is not exempt" % f)
			continue
		var src := FileAccess.get_file_as_string(script_path)
		if src == "":
			_fail("%s -> %s could not be read" % [f, script_path])
			continue
		var how := _timeout_mechanism(src)
		if how == "":
			_fail("%s -> %s arms NO timeout (neither ProbeWatchdog.arm nor .deadline)"
				% [f, script_path.get_file()])
			continue
		var first_err := _arm_is_first_in_ready(src)
		if first_err != "":
			_fail("%s -> %s: %s" % [f, script_path.get_file(), first_err])
			continue
		print("  ok  %-34s %s" % [f, how])

## A `--script` probe replaces the main loop: no scene, no autoloads, and
## no frame for a watchdog node to run in. Only a deadline can bound it,
## so arm() alone is not accepted here.
func _check_script_probes(files: PackedStringArray) -> void:
	print("")
	print("-- --script probes (SceneTree main loop) --")
	var found := false
	for f in files:
		if not f.ends_with(".gd") or NOT_PROBES.has(f):
			continue
		if files.has(f.trim_suffix(".gd") + ".tscn"):
			continue # covered by its scene above
		var path := "%s/%s" % [DEV_DIR, f]
		var src := FileAccess.get_file_as_string(path)
		if not _code_only(src).contains("extends SceneTree"):
			_fail("%s has no scene and is not a SceneTree probe -- classify it, or add it to NOT_PROBES" % f)
			continue
		found = true
		_checked_scripts += 1
		if not _code_only(src).contains("ProbeWatchdog.deadline("):
			_fail("%s is a --script probe with no ProbeDeadline. ProbeWatchdog.arm() cannot"
				% f + " bound it: there is no scene and no frame for the node to run in.")
			continue
		print("  ok  %-34s ProbeWatchdog.deadline()" % f)
	if not found:
		print("  (none)")

## An exemption naming a file that no longer exists is a silent hole in
## the making -- the next file to take that name inherits the exemption.
func _check_exemptions_are_live(files: PackedStringArray) -> void:
	for name in NOT_PROBES:
		if not files.has(name):
			_fail("NOT_PROBES lists '%s', which does not exist -- stale exemption" % name)

## ProbeWatchdog keeps its own copy of GameState's state/cause names so it
## can report a diagnosis where that autoload does not exist. A copy that
## drifts would print the wrong state at exactly the moment someone is
## reading it to find out why a probe hung, so it is asserted here rather
## than trusted.
func _check_state_name_tables() -> void:
	print("")
	print("-- ProbeWatchdog's GameState name tables --")
	var expected_states := ["TITLE", "PLAYING", "CAPTURED", "GAME_OVER"]
	var expected_causes := ["COLLISION", "PURSUER"]
	for i in expected_states.size():
		var want: String = expected_states[i]
		var got := ProbeWatchdog._state_name(GameState.State[want])
		if got != want:
			_fail("state %d: GameState.State.%s reads back as '%s'" % [i, want, got])
	for i in expected_causes.size():
		var want: String = expected_causes[i]
		var got := ProbeWatchdog._cause_name(GameState.DeathCause[want])
		if got != want:
			_fail("cause %d: GameState.DeathCause.%s reads back as '%s'" % [i, want, got])
	if ProbeWatchdog.STATE_NAMES.size() != GameState.State.size():
		_fail("GameState.State has %d values, ProbeWatchdog.STATE_NAMES has %d"
			% [GameState.State.size(), ProbeWatchdog.STATE_NAMES.size()])
	if ProbeWatchdog.CAUSE_NAMES.size() != GameState.DeathCause.size():
		_fail("GameState.DeathCause has %d values, ProbeWatchdog.CAUSE_NAMES has %d"
			% [GameState.DeathCause.size(), ProbeWatchdog.CAUSE_NAMES.size()])
	print("  ok  %d states, %d death causes agree with GameState"
		% [ProbeWatchdog.STATE_NAMES.size(), ProbeWatchdog.CAUSE_NAMES.size()])

## Reads the script path out of a .tscn as TEXT. Loading the scene would
## instantiate it, and instantiating a probe runs it.
func _script_path_of_scene(scene_path: String) -> String:
	var text := FileAccess.get_file_as_string(scene_path)
	for line in text.split("\n"):
		if not (line.begins_with("[ext_resource") and line.contains("type=\"Script\"")):
			continue
		var marker := "path=\""
		var i := line.find(marker)
		if i < 0:
			continue
		var rest := line.substr(i + marker.length())
		return rest.substr(0, rest.find("\""))
	return ""

## Reduces a source file to the text that can actually CALL something:
## comments removed, and the CONTENTS of string literals blanked while the
## surrounding code is kept.
##
## Both halves were paid for on this file's own first two runs. Comments
## first: it reported ITSELF as using `ProbeWatchdog.deadline()` because
## its header explains that mechanism. Then string literals: it still did,
## because the needle it searches for is a literal in its own source. A
## scanner that a file's prose -- or the scanner's own prose -- can talk
## into a false positive is not a guarantee, it is a second thing to be
## wrong.
##
## Blanking contents rather than dropping whole literals is what keeps a
## real call visible: `ProbeWatchdog.arm(self, "LABEL")` must survive as
## `ProbeWatchdog.arm(self, "")`, still matching, while the audit's own
## `contains("ProbeWatchdog.deadline(")` collapses to `contains("")`.
func _code_only(src: String) -> String:
	var out := ""
	for line in src.split("\n"):
		var kept := ""
		var quote := ""
		var escaped := false
		for i in line.length():
			var c := line[i]
			if quote != "":
				# Inside a literal: emit nothing but the closing quote.
				if escaped:
					escaped = false
				elif c == "\\":
					escaped = true
				elif c == quote:
					quote = ""
					kept += c
				continue
			if c == "#":
				break
			kept += c
			if c == "\"" or c == "'":
				quote = c
		out += kept + "\n"
	return out

func _timeout_mechanism(src_raw: String) -> String:
	var src := _code_only(src_raw)
	var armed := src.contains("ProbeWatchdog.arm(")
	var dl := src.contains("ProbeWatchdog.deadline(")
	if armed and dl:
		return "ProbeWatchdog.arm() + deadline()"
	if armed:
		return "ProbeWatchdog.arm()"
	if dl:
		return "ProbeWatchdog.deadline()"
	return ""

## "First statement of _ready()" checked against the source, because a
## watchdog armed after the thing that hangs is not a watchdog. Comments
## and blank lines do not count as statements.
##
## A probe that arms only via deadline() (no _ready() at all, or a
## SceneTree probe) is not subject to this and returns "".
func _arm_is_first_in_ready(src: String) -> String:
	if not _code_only(src).contains("ProbeWatchdog.arm("):
		return ""
	var lines := src.split("\n")
	var in_ready := false
	for line in lines:
		var t := line.strip_edges()
		if not in_ready:
			if t.begins_with("func _ready("):
				in_ready = true
			continue
		if t.is_empty() or t.begins_with("#"):
			continue
		if t.contains("ProbeWatchdog.arm("):
			return ""
		return "arms the watchdog, but not as the first statement of _ready() (found: `%s`)" % t
	return "has ProbeWatchdog.arm() but no _ready() to arm it in"

func _fail(msg: String) -> void:
	_failures.append(msg)

func _report() -> void:
	print("")
	print("checked: %d probe scenes, %d --script probes" % [_checked_scenes, _checked_scripts])
	if _failures.is_empty():
		print("")
		print("PASSED: every probe under %s is bounded by a wall-clock timeout." % DEV_DIR)
		get_tree().quit(0)
		return
	print("")
	for f in _failures:
		print("FAIL: %s" % f)
	print("")
	print("FAILED: %d probe(s) can run without a bound. See ProbeWatchdog.gd for the two" % _failures.size())
	print("        entry points and which shape of probe each one covers.")
	get_tree().quit(1)
