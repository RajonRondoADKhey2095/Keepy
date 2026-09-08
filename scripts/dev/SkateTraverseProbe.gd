extends Node
## CH53 -- THE SKATEPARK'S ARITHMETIC GATE: the ride, the chain, the
## ledger's guard, and the crossings the park must not have lengthened.
##
## =====================================================================
## THIS ONE RUNS HEADLESS, AND THAT IS NOT A SHORTCUT
##
## CLAUDE.md cuts both ways on the driver. A probe that reads a pixel, a
## MultiMesh transform or a screen point MUST run under
## `xvfb-run --rendering-driver opengl3` (SkateparkProbe does). A probe
## that reads only TRANSFORMS must run HEADLESS -- under llvmpipe it
## exceeds ten minutes without finishing where it renders its verdict in
## seconds, and CH32 measured two probes doing exactly that at their own
## budget, with real CPU and a growing log, for no defect at all.
##
## Everything below is transforms and integers.
##
## =====================================================================
## THE CONTROL COMES FIRST, AND IT IS A PUBLISHED NUMBER
##
## CLAUDE.md: "un banc incapable de restituer la diagonale à 66 hops /
## 18,700 s n'a pas qualité à publier un chiffre neuf". PHASE C walks the
## square's diagonal on the REAL KeepyHopper and demands the published
## figure to the frame. It is also, by itself, the answer to the brief's
## traversal question -- if the park had changed how a hop chain crosses
## the hub, this is the number that would move.
##
## =====================================================================
## RED BEFORE GREEN, AND WHAT IT MEANS FOR THE CHAIN
##
## Every assertion about the chain and the guard below is written so that
## it can FAIL, and the lot's red pass neutralises the rule it tests one
## at a time. The two that matter most are the two a proxy score cannot
## do without:
##
##   * a landing ON FOOT inside a module's disc must score NOTHING. Blind
##     check first: the same landing ON THE BOARD must score, or "it did
##     not score" is passing for free against a park that never scores.
##   * the ledger's guard must actually bite. Same shape: the first award
##     must be granted BEFORE the assertion that a later one is refused,
##     or "the stock ran out" is indistinguishable from "the ledger was
##     never wired up" (CH40's whole subject).

const BUDGET_S: float = 900.0
const FPS: float = 60.0
## CLAUDE.md's published worst crossing and the control this bench has to
## restate before any number of its own is worth reading.
const PUBLISHED_DIAGONAL_HOPS: int = 66
const PUBLISHED_DIAGONAL_S: float = 18.700
## CH38's ceiling for a hub crossing, and CH50 re-walked its own worst
## pair against it.
const CROSSING_BUDGET_S: float = 22.0

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _park: HubSkatepark = null
var _transport: HubTransport = null
var _hops: int = 0
var _done: bool = false
var _scores: Array = []

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE TRAVERSE PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	await get_tree().process_frame
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	_park = _hub.find_child("Skatepark", true, false) as HubSkatepark
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	# A throw-away save file: this probe SPENDS the park's stock, and a
	# probe that spent the developer's own save would be a probe nobody
	# can run twice. WorldSave publishes the override for this.
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _run() -> void:
	print("=== SKATE TRAVERSE PROBE -- CH53 (headless: transforms only) ===")
	if _keepy == null or _park == null or _transport == null:
		push_error("SkateTraverseProbe: hub scene is missing Keepy / Skatepark / Transport.")
		get_tree().quit(1)
		return
	await _phase_control()
	await _phase_crossings()
	await _phase_ledger()
	await _phase_ride()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# WALKING

func _trip(label: String, from: Vector3, to: Vector3) -> float:
	_keepy.dismount_vehicle()
	_keepy.global_position = HubSurface.ground(Vector3(from.x, 0.0, from.z))
	_hops = 0
	_done = false
	_keepy.hop_landed.connect(_on_landed)
	_keepy.became_idle.connect(_on_idle)
	_keepy.hop_to(to)
	var frames: int = 0
	while not _done and frames < 6000:
		await get_tree().process_frame
		frames += 1
	_keepy.hop_landed.disconnect(_on_landed)
	_keepy.became_idle.disconnect(_on_idle)
	var seconds: float = float(frames) / FPS
	print("     %-52s hops=%3d frames=%5d  %.3f s%s"
		% [label, _hops, frames, seconds, "" if _done else "  ** FRAME CAP **"])
	return seconds

func _on_landed(_p: Vector3) -> void:
	_hops += 1

func _on_idle() -> void:
	_done = true

# =====================================================================
# PHASE C -- the control.

func _phase_control() -> void:
	print("-- PHASE C: restate the published diagonal before publishing anything --")
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	var s := await _trip("square diagonal (published 66 hops / 18.700 s)",
		Vector3(-h, 0.0, -h), Vector3(h, 0.0, h))
	_check(_hops == PUBLISHED_DIAGONAL_HOPS,
		"C1 diagonal hops %d == published %d" % [_hops, PUBLISHED_DIAGONAL_HOPS])
	_check(absf(s - PUBLISHED_DIAGONAL_S) < 0.002,
		"C2 diagonal %.3f s == published %.3f s" % [s, PUBLISHED_DIAGONAL_S])
	print("")

# =====================================================================
# PHASE X -- the crossings the park must not have lengthened.
#
# CH51 section 4.1 read the code and concluded traversal is unchanged BY
# CONSTRUCTION: `KeepyHopper._is_clear(point, blocked)` is passed a
# `blocked` list in exactly ONE place in the whole repo (the boat's bank
# point), and HubRegion._holes act on a DESTINATION, never on a path. So
# a hop chain goes straight through anything.
##
## ⚠️ THAT IS A READING, AND A READING IS NOT A MEASUREMENT. This lot adds
## five solid-looking objects across the middle of the lobe; if any of
## them HAD started blocking, these are the three numbers that would move.
## The pairs are the ones CH38 and CH50 published as their worst, plus a
## pair that runs straight THROUGH the park -- which is the only new
## crossing this lot could possibly have created.

func _phase_crossings() -> void:
	print("-- PHASE X: the worst published crossings, re-walked with the park in place --")
	var trips: Array = [
		["CH38 worst  (35,-35) -> (-63,18)", Vector3(35.0, 0.0, -35.0), Vector3(-63.0, 0.0, 18.0), 20.967],
		["CH50 worst  (-63,-12) -> (22.43,51.74)", Vector3(-63.0, 0.0, -12.0), Vector3(22.43, 0.0, 51.74), 20.117],
	]
	for t in trips:
		var s := await _trip(String(t[0]), t[1], t[2])
		_check(s <= CROSSING_BUDGET_S,
			"X %s stays under the %.0f s budget (%.3f s)" % [t[0], CROSSING_BUDGET_S, s])
		_check(absf(s - float(t[3])) < 0.002,
			"X %s is UNCHANGED at %.3f s (published %.3f)" % [t[0], s, float(t[3])])
	# Straight through the park, south rim to north rim: the crossing this
	# lot invented, and the one a blocking module would break.
	var through := await _trip("THROUGH the park  (0,40) -> (0,61)",
		Vector3(0.0, 0.0, 40.0), Vector3(0.0, 0.0, 61.0))
	_check(_done, "X3 a chain straight through the park COMPLETES (nothing blocks it)")
	var straight: float = 21.0 / KeepyHopper.HOP_DISTANCE * (KeepyHopper.HOP_DURATION)
	print("     straight-line prediction for 21 u on foot: %.3f s" % straight)
	# A path that had to go round something would take measurably longer
	# than the straight chain. 1.25x is generous on purpose: the point is
	# to catch DETOURING, not to gate the hop tween's exact arithmetic.
	_check(through < straight * 1.25,
		"X4 the through-park crossing (%.3f s) is a STRAIGHT chain, not a detour (< %.3f s)"
			% [through, straight * 1.25])
	print("")

# =====================================================================
# PHASE L -- THE LEDGER, and its guard.

func _phase_ledger() -> void:
	print("-- PHASE L: award_from_activity and the G3 stock --")
	# The table is the source; the republished constants must agree with
	# it, or a HUD counting down to a recharge counts down to the wrong one.
	var row: Dictionary = WorldSave.ACTIVITY_STOCK.get(&"skate", {})
	_check(not row.is_empty(), "L0 there is a stock row for the skate activity")
	_check(int(row.get("capacity", -1)) == WorldSave.SKATE_CAPACITY,
		"L1 SKATE_CAPACITY (%d) is the table's capacity (%d)"
			% [WorldSave.SKATE_CAPACITY, int(row.get("capacity", -1))])
	_check(absf(float(row.get("recharge", -1.0)) - WorldSave.SKATE_RECHARGE_S) < 0.001,
		"L2 SKATE_RECHARGE_S (%.1f) is the table's recharge (%.1f)"
			% [WorldSave.SKATE_RECHARGE_S, float(row.get("recharge", -1.0))])
	WorldSave.reset()
	var stock0: int = WorldSave.skate_stock()
	_check(stock0 == WorldSave.SKATE_CAPACITY,
		"L3 a fresh save reads the park FULL (%d of %d)" % [stock0, WorldSave.SKATE_CAPACITY])
	# ⚠️ THE BLIND CHECK COMES FIRST. "the guard refused" is worth nothing
	# against a ledger that never grants anything, so the POSITIVE is
	# asserted before the refusal (CLAUDE.md: order the phases so the
	# positive runs first).
	var nuts0: int = WorldSave.resource(WorldSave.AWARD_KIND)
	var granted: int = WorldSave.award_from_activity(&"skate", WorldSave.POINTS_PER_NUT)
	_check(granted == 1, "L4 POSITIVE: one nut's worth of points grants exactly 1 (got %d)" % granted)
	_check(WorldSave.resource(WorldSave.AWARD_KIND) == nuts0 + 1,
		"L5 and the shared counter actually moved")
	# Under the threshold: banked, not granted.
	var small: int = WorldSave.award_from_activity(&"skate", WorldSave.POINTS_PER_NUT - 1)
	_check(small == 0, "L6 points under the threshold grant nothing yet (got %d)" % small)
	# Drain it. The stock is the only thing between the park and a farm.
	var drained: int = 0
	for _i in 40:
		drained += WorldSave.award_from_activity(&"skate", WorldSave.POINTS_PER_NUT)
	_check(WorldSave.skate_stock() == 0,
		"L7 the stock DRAINS (%d left after 40 tricks' worth)" % WorldSave.skate_stock())
	var after_empty: int = WorldSave.award_from_activity(&"skate", WorldSave.POINTS_PER_NUT * 4)
	_check(after_empty == 0,
		"L8 REFUSAL: an empty park grants nothing however many points arrive (got %d)" % after_empty)
	print("     granted before the guard bit: %d (capacity %d, +1 from L4)"
		% [drained + 1, WorldSave.SKATE_CAPACITY])
	_check(drained + 1 <= WorldSave.SKATE_CAPACITY,
		"L9 the TOTAL granted never exceeds the capacity -- a stock caps the total, not the rate")
	# An unknown activity is refused loudly rather than silently credited.
	_check(WorldSave.activity_stock(&"nothing_like_this") == -1,
		"L10 an activity with no row reads -1, never 0 (0 would read as 'empty')")
	print("")

# =====================================================================
# PHASE R -- THE RIDE and the proxy's two defences.

func _phase_ride() -> void:
	print("-- PHASE R: the board, the landing proxy, and the chain --")
	WorldSave.reset()
	var board := _transport.board_node()
	_check(board != null, "R0 the board exists")
	_check(_transport.vehicle_at(_transport.board_position()) == HubTransport.VEHICLE_SKATE,
		"R1 a tap on the board reads as VEHICLE_SKATE through the existing vehicle door")
	# Module centres, taken from the built nodes.
	var m0 := _park.module_centre(0)
	var m1 := _park.module_centre(1)
	_check(m0 != Vector3.INF and m1 != Vector3.INF, "R2 two module centres are published")
	_check(_park.landed_within(m0) == 0, "R3 landed_within finds module 0 at its own centre")
	_check(_park.landed_within(Vector3(0.0, 0.0, 5.0)) < 0,
		"R4 and finds nothing in the middle of the plateau")

	_park.trick_scored.connect(_on_scored)

	# ⚠️ BLIND CHECK FIRST: prove the thing CAN score before asserting it
	# does not. On the board, on a module: this must score.
	_keepy.dismount_vehicle()
	_keepy.global_position = HubSurface.ground(m0)
	var mounted: bool = _keepy.mount_vehicle(board, HubTransport.SKATE_LIFT)
	_check(mounted, "R5 he climbs onto the board (mount_vehicle, the Sautillon's path)")
	_scores.clear()
	var scored_on_board: bool = _park.note_landing(m0)
	_check(scored_on_board, "R6 POSITIVE: a landing on a module ON THE BOARD scores")
	_check(_scores.size() == 1, "R7 and it emitted exactly one trick_scored (%d)" % _scores.size())

	# NOW the refusal is worth something.
	_keepy.dismount_vehicle()
	_scores.clear()
	var scored_on_foot: bool = _park.note_landing(m0)
	_check(not scored_on_foot, "R8 REFUSAL: the SAME landing on foot scores nothing")
	_check(_scores.is_empty(), "R9 and emitted nothing (%d)" % _scores.size())

	# Off a module, on the board: nothing, and the chain breaks.
	_keepy.mount_vehicle(board, HubTransport.SKATE_LIFT)
	_scores.clear()
	_check(not _park.note_landing(Vector3(0.0, 0.0, 5.0)),
		"R10 a landing on the grass scores nothing even on the board")

	# The chain: different modules in a row climb it, the same one twice
	# does not.
	_scores.clear()
	_park.cancel_intent()
	_park.note_landing(m0)
	var c1: int = _park.combo()
	_park.note_landing(m1)
	var c2: int = _park.combo()
	_park.note_landing(_park.module_centre(2))
	var c3: int = _park.combo()
	_check(c1 == 0 and c2 == 1 and c3 == 2,
		"R11 the chain climbs on DIFFERENT modules: %d, %d, %d" % [c1, c2, c3])
	_park.note_landing(_park.module_centre(2))
	_check(_park.combo() == 0,
		"R12 the SAME module twice restarts the chain (%d)" % _park.combo())
	_park.note_landing(m0)
	_park.note_landing(Vector3(0.0, 0.0, 5.0))
	_check(_park.combo() == 0, "R13 a landing off the park BREAKS the chain (%d)" % _park.combo())
	# The chain multiplies what the module is worth, and the emitted
	# points are the ones a HUD shows.
	_park.cancel_intent()
	_scores.clear()
	_park.note_landing(m0)
	_park.note_landing(m1)
	var base1: int = int(HubSkatepark.MODULES[1]["points"])
	var want: int = int(round(float(base1) * (1.0 + HubSkatepark.CHAIN_STEP)))
	_check(_scores.size() == 2 and int(_scores[1]["points"]) == want,
		"R14 a chain of 1 pays %d for a %d-point module (got %d)"
			% [want, base1, int(_scores[1]["points"]) if _scores.size() > 1 else -1])
	# The stat exists and moved.
	_check(WorldSave.stats().get("skate_tricks", 0) > 0,
		"R15 skate_tricks is a live stat (%d)" % int(WorldSave.stats().get("skate_tricks", 0)))
	_check(int(WorldSave.stats().get("skate_best_combo", 0)) >= 2,
		"R16 skate_best_combo keeps the BEST, not the last (%d)"
			% int(WorldSave.stats().get("skate_best_combo", 0)))
	_park.trick_scored.disconnect(_on_scored)
	print("")

func _on_scored(module: int, trick: StringName, points: int, chain: int) -> void:
	_scores.append({"module": module, "trick": trick, "points": points, "chain": chain})
