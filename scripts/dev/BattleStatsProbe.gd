extends Node
## Gates Keepy Battle's cumulative-stats path, END TO END, without a
## socket, a token or a Firestore project.
##
## Three things can go wrong here and only one of them is visible from
## the outside, which is why this file exists:
##
##   1. the COUNTING can be wrong (PHASE A-C) -- a ratio that is quietly
##      inflated looks exactly like a ratio that is right;
##   2. the WRITE SHAPE can be wrong (PHASE D) -- and the specific way it
##      goes wrong (a lost `updateMask`) is a full overwrite of a shared
##      cumulative document, i.e. the one failure that destroys data
##      rather than losing one fight;
##   3. the GATE can be wrong (PHASE E) -- a probe that reached the
##      network, or a fight that recorded twice.
##
## PHASE F is the one that earns the file: it drives the SHIPPED
## Battle.tscn -- the real arena, the real fighters, the real brain --
## and reads the tally that a real fight produced, rather than a copy of
## the wiring maintained next to it.
##
## PHASE F reaches into two of BattleArena's private members (`_tick` and
## `_running`), which no other probe in this directory does. It is a
## deliberate trade and the alternative was worse: driving the fight by
## awaiting real frames costs a minute of wall clock inside a watchdog
## budget, and re-implementing the loop here would rebuild the very
## fixture-vs-reality gap this phase exists to close. Only `fight_tally()`
## was added to the shipped class, because the tally is a RESULT the
## probe must read, while the loop is machinery it only has to turn.

const TICK_S := 1.0 / 60.0
const BattleScene := preload("res://scenes/Battle.tscn")

## Enough ticks for any fight the shipped profiles can produce (measured
## worst case is ~33 s; this is 60 s) -- a bound, not an expectation.
const MAX_FIGHT_TICKS := 3600

var _failures := 0
var _checks := 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "BattleStatsProbe")
	print("=== BATTLE STATS PROBE ===")
	_phase_a_counting()
	_phase_b_invariant()
	_phase_c_full_key_set()
	_phase_d_write_shape()
	await _phase_e_gate()
	await _phase_f_real_fight()
	print("--- %d check(s), %d failure(s) ---" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

# ---------------------------------------------------------------- PHASE A

## Every counting rule, one event at a time. Written as a table rather
## than as prose asserts so a future change to the mapping shows up as a
## changed line and not as a changed paragraph.
func _phase_a_counting() -> void:
	print("\n--- PHASE A: counting rules ---")
	var t := BattleTally.new()
	t.note_action_started(BattleTypes.Action.ATTACK)
	t.note_action_started(BattleTypes.Action.DODGE)
	t.note_action_started(BattleTypes.Action.NONE)
	var s := t.snapshot()
	_expect(s["attacks"]["attempted"] == 1, "ATTACK counts one attempt")
	_expect(s["dodges"]["attempted"] == 1, "DODGE counts one dodge attempt")
	_expect(
		s["attacks"]["attempted"] + s["dodges"]["attempted"] == 2,
		"NONE is counted nowhere")
	# The frozen group. Lot 7 deleted GUARD, and the deployed Firestore
	# rules still demand the key -- so the contract is now "always present,
	# always zero", and it is asserted rather than assumed. A future lot
	# that starts incrementing it again would fail here first.
	_expect(s["blocks"]["attempted"] == 0 and s["blocks"]["hit"] == 0 and s["blocks"]["missed"] == 0,
		"the blocks group survives the schema and stays at zero")

	# The player attacking.
	_expect(_attack_case(BattleTypes.Outcome.HIT) == [1, 0], "attack HIT -> attacks.hit")
	_expect(_attack_case(BattleTypes.Outcome.DODGED) == [0, 1], "attack DODGED -> attacks.missed")
	_expect(_attack_case(BattleTypes.Outcome.MISSED) == [0, 1], "attack MISSED -> attacks.missed")

	# The player defending. The pairing must be the one the HUD prints --
	# a counter that disagreed with the word on screen would be a second,
	# invisible truth.
	_expect(_defence_case(BattleTypes.Action.DODGE, BattleTypes.Outcome.DODGED) == ["dodges", "hit"], "dodge that evades -> dodges.hit")
	_expect(_defence_case(BattleTypes.Action.DODGE, BattleTypes.Outcome.HIT) == ["dodges", "missed"], "ESQUIVE RATEE -> dodges.missed")
	_expect(_defence_case(BattleTypes.Action.NONE, BattleTypes.Outcome.HIT) == ["", ""],
		"caught with no defence committed counts as no failed defence")
	_expect(_defence_case(BattleTypes.Action.ATTACK, BattleTypes.Outcome.HIT) == ["", ""],
		"caught mid-attack counts as no failed defence")

	var w := BattleTally.new()
	_expect(not w.is_finished(), "a fresh tally is not finished")
	_expect(w.finish(true), "finish() closes the fight")
	_expect(not w.finish(true), "finish() is idempotent -- one fight cannot count twice")
	var win := w.to_increments()
	_expect(win["gamesPlayed"] == 1 and win["wins"] == 1 and win["losses"] == 0, "a win is 1/1/0")
	var l := BattleTally.new()
	l.finish(false)
	var loss := l.to_increments()
	_expect(loss["gamesPlayed"] == 1 and loss["wins"] == 0 and loss["losses"] == 1, "a loss is 1/0/1")

	var r := BattleTally.new()
	r.note_action_started(BattleTypes.Action.ATTACK)
	r.finish(true)
	r.reset()
	var cleared := r.to_increments()
	_expect(cleared["gamesPlayed"] == 0 and cleared["attacks.attempted"] == 0 and not r.is_finished(),
		"reset() makes a rematch a NEW fight, inheriting nothing")

# ---------------------------------------------------------------- PHASE B

## The invariant, checked on numbers the combat FSM cannot currently
## produce -- which is exactly the point. The FSM being well behaved
## today is an argument about code this file does not own.
func _phase_b_invariant() -> void:
	print("\n--- PHASE B: hit + missed <= attempted ---")
	var clean := BattleTally.new()
	clean.note_action_started(BattleTypes.Action.DODGE)
	clean.note_action_started(BattleTypes.Action.DODGE)
	clean.note_defence_resolved(BattleTypes.Action.DODGE, BattleTypes.Outcome.DODGED)
	_expect(clean.repair().is_empty(), "a coherent tally is repaired in no way at all")

	# One commitment, two resolutions -- the shape a future lot could
	# introduce by letting two strikes land inside one defensive action.
	var broken := BattleTally.new()
	broken.note_action_started(BattleTypes.Action.DODGE)
	broken.note_defence_resolved(BattleTypes.Action.DODGE, BattleTypes.Outcome.DODGED)
	broken.note_defence_resolved(BattleTypes.Action.DODGE, BattleTypes.Outcome.HIT)
	var before: Dictionary = broken.snapshot()
	_expect(before["dodges"]["attempted"] == 1 and before["dodges"]["hit"] == 1
			and before["dodges"]["missed"] == 1,
		"the incoherent state is reached, so the repair is exercised for real")
	var repairs := broken.repair()
	_expect(repairs.size() == 1, "the repair is reported, not silent")
	var after: Dictionary = broken.snapshot()
	_expect(after["dodges"]["attempted"] == 2,
		"attempted is RAISED to hit + missed -- observed resolutions are never dropped")
	_expect(after["dodges"]["hit"] == 1 and after["dodges"]["missed"] == 1,
		"resolutions survive the repair untouched")
	for group in BattleTally.GROUPS:
		var g: Dictionary = after[group]
		_expect(g["hit"] + g["missed"] <= g["attempted"], "%s holds the invariant after repair" % group)

# ---------------------------------------------------------------- PHASE C

## Every key of the schema on every write, zero deltas included. This is
## what makes the FIRST write of the document's life produce the full
## shape the rules' hasAll() demands -- an `increment` on a missing field
## creates it from 0, so a `losses: 0` after a win is load-bearing.
func _phase_c_full_key_set() -> void:
	print("\n--- PHASE C: the full key set travels every time ---")
	var t := BattleTally.new()
	t.finish(true)
	var inc := t.to_increments()
	var expected := [
		"gamesPlayed", "wins", "losses",
		"attacks.attempted", "attacks.hit", "attacks.missed",
		"dodges.attempted", "dodges.hit", "dodges.missed",
		"blocks.attempted", "blocks.hit", "blocks.missed",
	]
	expected.sort()
	var got := inc.keys()
	got.sort()
	_expect(got == expected, "12 counter paths, exactly, on a fight with nothing but a win")
	var zeros := 0
	for key in inc:
		if int(inc[key]) == 0:
			zeros += 1
	_expect(zeros == 10, "the 10 untouched counters travel as explicit zeros")
	for key in inc:
		_expect(int(inc[key]) >= 0, "%s is never negative" % key)

# ---------------------------------------------------------------- PHASE D

## The REST body, read literally. The failure this phase exists to catch
## is a dropped or non-empty `updateMask`: Firestore overwrites the whole
## document when an update carries no mask, so losing that one key turns
## every fight into a reset of the shared totals.
func _phase_d_write_shape() -> void:
	print("\n--- PHASE D: the bytes that would go out ---")
	var t := BattleTally.new()
	t.note_action_started(BattleTypes.Action.ATTACK)
	t.note_attack_resolved(BattleTypes.Outcome.HIT)
	t.finish(true)
	var body: Dictionary = BattleStats.build_body(t.to_increments())

	_expect(body.has("writes") and body["writes"].size() == 1, "exactly one write")
	var write: Dictionary = body["writes"][0]

	_expect(write.has("updateMask"), "updateMask is PRESENT -- without it this is a full overwrite")
	_expect(write["updateMask"].has("fieldPaths") and write["updateMask"]["fieldPaths"].is_empty(),
		"updateMask is EMPTY -- a listed-but-absent path would DELETE that field")
	_expect(not write["update"].has("fields"),
		"update carries no `fields` -- every value here is a transform")
	_expect(str(write["update"]["name"]).ends_with("/battleStats/global"),
		"the one shared document is the target")
	_expect(str(write["update"]["name"]).begins_with("projects/%s/" % Leaderboard.PROJECT_ID),
		"project id is read from Leaderboard, not copied")
	_expect(not write.has("currentDocument"),
		"no existence precondition -- the same body must create AND update")

	var transforms: Array = write["updateTransforms"]
	_expect(transforms.size() == 13, "12 increments + updatedAt")
	var last: Dictionary = transforms[transforms.size() - 1]
	_expect(last["fieldPath"] == "updatedAt" and last["setToServerValue"] == "REQUEST_TIME",
		"updatedAt is set by the SERVER -- the rule demands == request.time")
	var seen := {}
	var ints_are_strings := true
	for i in transforms.size() - 1:
		var tr: Dictionary = transforms[i]
		seen[tr["fieldPath"]] = true
		_expect(tr.has("increment"), "%s is an increment, never a set" % tr["fieldPath"])
		if typeof(tr["increment"]["integerValue"]) != TYPE_STRING:
			ints_are_strings = false
	_expect(ints_are_strings, "int64 travels as a JSON string, per the REST mapping")
	_expect(seen.has("attacks.attempted") and seen.has("gamesPlayed"),
		"nested and top-level paths both present")
	_expect(seen.has("wins") and seen.has("losses"),
		"both outcomes travel, so neither key can be missing on the first ever write")

	var encoded := JSON.stringify(body)
	_expect(encoded.contains("\"fieldPaths\":[]"),
		"the empty mask survives JSON encoding as an empty list, not as an absent key")
	_expect(BattleStats.build_body(t.to_increments()) == body,
		"the body is deterministic for a given tally")

# ---------------------------------------------------------------- PHASE E

## The gate. A probe must never reach the network, and it must never even
## look at Auth -- the ORDER of the two checks is asserted, not just
## their result: reversing them would make a headless run answer
## "auth-required", which reads as a signed-out player rather than as a
## probe.
func _phase_e_gate() -> void:
	print("\n--- PHASE E: the headless gate ---")
	_expect(not BattleStats.network_enabled,
		"network is off under the headless DisplayServer")

	var t := BattleTally.new()
	t.finish(true)
	var results := await _record_and_collect(t)
	_expect(results.size() == 1, "record() emits exactly one signal")
	_expect(results[0]["success"] == false, "and it is a failure, not a silent success")
	_expect(results[0]["error"] == BattleStats.ERR_NETWORK_DISABLED,
		"network is checked BEFORE auth -- a probe never touches Auth at all")

	var unfinished := BattleTally.new()
	var refused := await _record_and_collect(unfinished)
	_expect(refused.size() == 1 and refused[0]["error"] == BattleStats.ERR_NOT_FINISHED,
		"a fight that never ended is refused, not recorded as a game played")

# ---------------------------------------------------------------- PHASE F

## The shipped arena, a real fight, and the tally it actually produced.
##
## The scene is driven by calling BattleArena._tick() directly rather
## than waiting on frames: _tick IS the function _process feeds, so this
## exercises the same code at the same fixed step without spending a
## minute of wall clock inside a watchdog budget.
func _phase_f_real_fight() -> void:
	print("\n--- PHASE F: a real fight through the shipped scene ---")
	var arena := BattleScene.instantiate() as BattleArena
	add_child(arena)
	await get_tree().process_frame

	var records: Array = []
	var on_record := func(success: bool, error: String) -> void:
		records.append({ "success": success, "error": error })
	BattleStats.record_finished.connect(on_record)

	var ticks := 0
	# A caricature player: alternate attack and dodge. Enough to generate
	# every counter without being a strategy under test.
	#
	# Alternates on each ACCEPTED action rather than on `ticks % 3`, which
	# is what this did until lot 8 and which was quietly fragile: the
	# player is only ever asked while free, so the choice depended on the
	# lockout length modulo 3. Lot 8's instant attack made that lockout
	# exactly 51 ticks, the caricature attacked and never dodged again,
	# and a probe that exists to see every counter move stopped seeing
	# half of them. A toggle cannot resonate with a timing.
	var want_attack := true
	while arena._running and ticks < MAX_FIGHT_TICKS:
		if arena.player.is_free():
			arena.player.request_action(
				BattleTypes.Action.ATTACK if want_attack else BattleTypes.Action.DODGE)
			want_attack = not want_attack
		arena._tick(TICK_S)
		ticks += 1

	BattleStats.record_finished.disconnect(on_record)
	_expect(ticks < MAX_FIGHT_TICKS, "the fight ended on its own (%d ticks)" % ticks)

	var tally := arena.fight_tally()
	var snap := tally.snapshot()
	print("  tally: %s" % snap)
	_expect(tally.is_finished(), "the tally was closed by _end_round")
	_expect(snap["gamesPlayed"] == 1, "exactly one game played")
	_expect(snap["wins"] + snap["losses"] == 1, "exactly one of win/loss")
	_expect(records.size() == 1, "exactly ONE write attempt per finished fight")
	_expect(records[0]["error"] == BattleStats.ERR_NETWORK_DISABLED,
		"and it degraded on the headless gate rather than reaching out")

	_expect(snap["attacks"]["attempted"] > 0, "the fight produced attack attempts")
	_expect(snap["dodges"]["attempted"] > 0, "the fight produced dodge attempts")
	_expect(snap["blocks"]["attempted"] == 0,
		"and produced no block attempts -- the group is frozen, not merely unused today")
	for group in BattleTally.GROUPS:
		var g: Dictionary = snap[group]
		_expect(g["hit"] + g["missed"] <= g["attempted"],
			"%s: %d + %d <= %d on a REAL fight" % [group, g["hit"], g["missed"], g["attempted"]])
	_expect(tally.repair().is_empty(),
		"the shipped FSM needed no repair -- measured, not assumed")

	arena.queue_free()
	await get_tree().process_frame

# ---------------------------------------------------------------- helpers

func _attack_case(outcome: BattleTypes.Outcome) -> Array:
	var t := BattleTally.new()
	t.note_attack_resolved(outcome)
	var s := t.snapshot()
	return [s["attacks"]["hit"], s["attacks"]["missed"]]

## Returns [group, sub] for the single counter the event moved, or
## ["", ""] when it moved none.
func _defence_case(attempted: BattleTypes.Action, outcome: BattleTypes.Outcome) -> Array:
	var t := BattleTally.new()
	t.note_defence_resolved(attempted, outcome)
	var s := t.snapshot()
	for group in BattleTally.GROUPS:
		for sub in ["hit", "missed"]:
			if s[group][sub] == 1:
				return [group, sub]
	return ["", ""]

func _record_and_collect(tally: BattleTally) -> Array:
	var results: Array = []
	var handler := func(success: bool, error: String) -> void:
		results.append({ "success": success, "error": error })
	BattleStats.record_finished.connect(handler)
	BattleStats.record(tally)
	await get_tree().process_frame
	BattleStats.record_finished.disconnect(handler)
	return results

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  OK   %s" % label)
		return
	_failures += 1
	printerr("  FAIL %s" % label)
	print("  FAIL %s" % label)
