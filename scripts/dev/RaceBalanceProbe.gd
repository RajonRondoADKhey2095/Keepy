extends Node
## CH30 -- WHAT THE RACE ACTUALLY COSTS THE PLAYER, measured on the LIVE
## HubWorld.tscn. Transforms only, headless, --fixed-fps 60.
##
## =====================================================================
## WHY THIS EXISTS
##
## Mathieu's retour is "je gagne a tous les coups, largement" and the
## brief's target is "environ x1,5 d'adversite". Neither sentence is a
## number, and CLAUDE.md forbids tuning a constant against a sentence
## ("MESURER, PAS SUPPOSER"). This probe turns both into numbers:
##
##   * every racer's lap times, over a full three-lap race on the real
##     track with the real bodies, the real collisions and the real
##     rubber band;
##   * the top speed each one actually reaches (not the one its profile
##     allows -- a driver that never reaches its cap is power-limited by
##     the circuit, and raising the cap would buy nothing);
##   * the share of an opponent's progress that comes from the RUBBER
##     BAND rather than from its profile, measured by racing the same
##     seed twice, once with the leash and once without;
##   * the gap at the flag against a REFERENCE PLAYER -- the `human_ref`
##     profile, a clean quick mistake-free drive that uses the boost
##     (KartAiDriver.PROFILES). A sandbox cannot hold a thumb; a ratio
##     needs a denominator; this is the denominator, and it is the same
##     one before and after so the ratio means something.
##
## =====================================================================
## WHAT IT ASSERTS (and so what makes it exit 1)
##
## It is a MEASUREMENT probe first, but a measurement nobody gates rots.
## Three contracts, all on the DEFAULT difficulty preset:
##
##   D1  the default preset closes the gap: the best opponent's best lap
##       is at least CLOSE_FACTOR closer to the reference's than it is at
##       x1. This is "x1.5" written as something that can fail.
##   D2  the three presets are ORDERED and SEPARATED: best-opponent lap
##       x1 > x1.5 > x2, each step at least STEP_MIN_S apart, so a thumb
##       can feel which one it is on.
##   D3  the personalities survive the scaling: at every preset the cat
##       is still quicker than the boar at the omega and the boar still
##       quicker than the cat on the straight (KartProbe's own contract,
##       re-asserted at each difficulty rather than at x1 only).
##
## BLIND CHECK (CLAUDE.md: an equality or an ordering passes for free
## against a mechanism that was never wired): before D1/D2 are believed,
## the probe proves the difficulty knob MOVES something -- the same seed
## at x1 and at x2.5 must produce DIFFERENT best-opponent laps by more than
## the run-to-run floor. If the knob were a no-op every ordering below
## would still "hold" at equality, which is exactly the failure mode.
##
## Args after `--`: --only=measure|gate|all  --laps=N  --quiet

const RACE_TIMEOUT_S: float = 400.0
## D1: "x1.5 of adversity", written as something that can fail. The best
## opponent's DEFICIT to the floor (see _gate) must fall to 1/1.5 = 0.667
## of what it is at x1, within a band: the opponents' faults are a Poisson
## process and one unlucky race must not turn the contract red, and a
## preset that overshot into "x2.5" would be just as wrong as one that
## did nothing.
const CLOSE_LO: float = 0.55
const CLOSE_HI: float = 0.80
## D2: seconds of best lap between two neighbouring presets.
const STEP_MIN_S: float = 0.35

var _hub: Node = null
var _karting: HubKarting = null
var _failures: int = 0
var _checks: int = 0
var _only: String = "all"
var _laps: int = 3
var _quiet: bool = false
## preset id -> the measured table of that race.
var _runs: Dictionary = {}

func _ready() -> void:
	ProbeWatchdog.arm(self, "RACEBAL", 900.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg.begins_with("--laps="):
			_laps = maxi(1, int(arg.substr(7)))
		elif arg == "--quiet":
			_quiet = true
	WorldSave.SAVE_PATH_OVERRIDE = "user://race_balance_probe.json"
	WorldSave.reset()
	var packed: PackedScene = load("res://scenes/HubWorld.tscn")
	_hub = packed.instantiate()
	add_child(_hub)
	_karting = _hub.get_node("WorldViewport/SubViewport/World/Karting")
	_run()

func _run() -> void:
	await _frames(3)
	print("RACE BALANCE -- track %s, %d laps, seed %d" % [KartTrack.TRACK_ID, _laps, _karting._seed])
	for id in ["x1", "x15", "x25"]:
		_runs[id] = await _race(id, true)
		_print_table(id + " (rubber band ON)", _runs[id])
	_runs["x1_norubber"] = await _race("x1", false)
	_print_table("x1 (rubber band OFF -- the raw profiles)", _runs["x1_norubber"])
	_runs["x15_norubber"] = await _race("x15", false)
	_print_table("x1.5 (rubber band OFF)", _runs["x15_norubber"])
	_runs["floor"] = await _race("x1", true, "limit_ref")
	_print_table("THE FLOOR -- limit_ref, the fastest lap this vehicle can turn here", _runs["floor"])
	_rubber_share()
	if _only == "all" or _only == "gate":
		_gate()
	print("")
	print("RACE BALANCE PROBE: %d checks, %d failures -> %s" % [_checks, _failures, "PASS" if _failures == 0 else "FAIL"])
	get_tree().quit(0 if _failures == 0 else 1)

## ---- one race ------------------------------------------------------------

## Races the four karts at difficulty `preset_id` from the grid, with no
## Keepy and no camera: the player's entry is driven by the `human_ref`
## reference profile, every opponent by its own. Returns one row per
## racer, in grid order.
func _race(preset_id: String, rubber: bool, ref_profile: String = "human_ref") -> Array:
	KartDifficulty.set_id(preset_id)
	_karting.rubber_band_enabled = rubber
	# The player's entry gets the reference driver. Installed BEFORE the
	# grid-up so _grid_all() seeds it exactly as it seeds the opponents.
	var pi: int = _karting.player_index()
	if _karting.racers[pi]["driver"] == null:
		var ref := KartAiDriver.new()
		_karting.racers[pi]["driver"] = ref
	(_karting.racers[pi]["driver"] as KartAiDriver).setup(_karting.track, ref_profile, _karting._seed + pi * 7919)
	# The touch writer must not fight the reference driver for the same
	# KartInput object (it holds throttle at 1 every frame while enabled).
	_karting.touch.enabled = false
	_karting._grid_all()
	for r in _karting.racers:
		r["active"] = true
	_karting._set_race_state(HubKarting.Race.RUNNING)
	_karting._go()
	var n: int = _karting.racers.size()
	var top: Array = []
	var off: Array = []
	var scale_sum: Array = []
	var frames: int = 0
	for i in n:
		top.append(0.0)
		off.append(0)
		scale_sum.append(0.0)
	var clock: float = 0.0
	while clock < RACE_TIMEOUT_S:
		await get_tree().physics_frame
		clock = _karting.race_clock_s
		frames += 1
		var done: bool = true
		for i in n:
			var r: Dictionary = _karting.racers[i]
			var kart: KartBody = r["kart"]
			top[i] = maxf(top[i], absf(kart.speed()))
			if not kart.is_on_track():
				off[i] += 1
			var d: KartAiDriver = r["driver"]
			scale_sum[i] += (d.speed_scale if d != null else 1.0)
			if int(r["finish_ms"]) < 0:
				done = false
			# A racer that has finished keeps driving (the V8 free drive);
			# nothing here stops it, so `done` is the only exit.
		if done:
			break
	var rows: Array = []
	for i in n:
		var r: Dictionary = _karting.racers[i]
		var d: KartAiDriver = r["driver"]
		rows.append({
			"name": (r["kart"] as KartBody).racer_name,
			"profile": d.profile_id if d != null else "",
			"laps_ms": (r["laps_ms"] as Array).duplicate(),
			"best_ms": (r["lap"] as KartLap).best_lap_ms,
			"finish_ms": int(r["finish_ms"]),
			"top": float(top[i]),
			"off_frames": int(off[i]),
			"faults": d.faults_total if d != null else 0,
			"mean_scale": float(scale_sum[i]) / maxf(float(frames), 1.0),
		})
	# Back to the grid so the next race starts from the same state.
	_karting._reset_race(true)
	return rows

## ---- the readout -----------------------------------------------------------

func _ms(v: int) -> String:
	return "--.---" if v <= 0 else "%.3f" % (float(v) / 1000.0)

func _is_ref(profile: String) -> bool:
	return profile == "human_ref" or profile == "limit_ref"

func _print_table(title: String, rows: Array) -> void:
	if _quiet:
		return
	print("")
	print("  %s" % title)
	print("  %-12s %-10s %-9s %-9s %-8s %-7s %-6s %-6s %s" % ["racer", "profile", "best", "finish", "gap", "top", "off", "faults", "laps"])
	var ref_finish: int = -1
	for r in rows:
		if _is_ref(String(r["profile"])):
			ref_finish = int(r["finish_ms"])
	for r in rows:
		var laps: Array = r["laps_ms"]
		var texts: Array = []
		for ms in laps:
			texts.append(_ms(int(ms)))
		var gap: String = "--"
		if ref_finish > 0 and int(r["finish_ms"]) > 0:
			gap = "%+.3f" % (float(int(r["finish_ms"]) - ref_finish) / 1000.0)
		print("  %-12s %-10s %-9s %-9s %-8s %-7.2f %-6d %-6d %s" % [
			r["name"], r["profile"], _ms(int(r["best_ms"])), _ms(int(r["finish_ms"])), gap,
			float(r["top"]), int(r["off_frames"]), int(r["faults"]), ", ".join(PackedStringArray(texts))])

func _best_opponent(rows: Array) -> int:
	var best: int = -1
	for r in rows:
		if _is_ref(String(r["profile"])):
			continue
		var b: int = int(r["best_ms"])
		if b > 0 and (best < 0 or b < best):
			best = b
	return best

func _reference(rows: Array) -> int:
	for r in rows:
		if _is_ref(String(r["profile"])):
			return int(r["best_ms"])
	return -1

func _rubber_share() -> void:
	print("")
	print("  RUBBER BAND SHARE -- same seed, leash on vs off")
	for pair in [["x1", "x1_norubber"], ["x15", "x15_norubber"]]:
		var on: Array = _runs[pair[0]]
		var offr: Array = _runs[pair[1]]
		for i in on.size():
			var a: Dictionary = on[i]
			var b: Dictionary = offr[i]
			if _is_ref(String(a["profile"])):
				continue
			var da: int = int(a["finish_ms"])
			var db: int = int(b["finish_ms"])
			var delta: String = "--" if (da <= 0 or db <= 0) else "%+.3f s" % (float(da - db) / 1000.0)
			print("    %-4s %-12s mean speed_scale %.4f  finish with leash vs without: %s" % [pair[0], a["name"], float(a["mean_scale"]), delta])

## ---- the gate ---------------------------------------------------------------

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s%s" % ["ok" if ok else "FAIL", label, ("  -- " + detail) if detail != "" else ""])

func _gate() -> void:
	print("")
	print("PHASE GATE")
	var b1: int = _best_opponent(_runs["x1"])
	var b15: int = _best_opponent(_runs["x15"])
	var b2: int = _best_opponent(_runs["x25"])
	# THE DENOMINATOR. Not the reference PLAYER -- a sandbox cannot hold
	# Mathieu's thumb, and a target stated as a ratio needs a denominator
	# that does not depend on a guess about his pace. `limit_ref` is the
	# fastest lap this vehicle can turn on this track (see its profile),
	# so an opponent's DEFICIT is its best lap minus that, and a
	# difficulty preset is judged on how much of the deficit it removes.
	var floor_ms: int = _reference(_runs["floor"])
	# BLIND: the difficulty knob moves something at all.
	_check("(blind) the difficulty knob changes the race: x1 and x2.5 best opponent laps differ by > 1 s",
		absf(float(b1 - b2)) > 1000.0, "%s vs %s" % [_ms(b1), _ms(b2)])
	# BLIND: the floor is a floor, i.e. no opponent at any preset beats it.
	_check("(blind) the floor is below every opponent lap measured", floor_ms > 0 and floor_ms <= b2,
		"floor %s, quickest opponent seen %s" % [_ms(floor_ms), _ms(b2)])
	# D2: ordered and separated.
	_check("D2 presets ordered x1 > x1.5 > x2.5", b1 > b15 and b15 > b2, "%s / %s / %s" % [_ms(b1), _ms(b15), _ms(b2)])
	_check("D2 x1 -> x1.5 separated by at least %.2f s" % STEP_MIN_S, float(b1 - b15) / 1000.0 >= STEP_MIN_S, "%.3f s" % (float(b1 - b15) / 1000.0))
	_check("D2 x1.5 -> x2.5 separated by at least %.2f s" % STEP_MIN_S, float(b15 - b2) / 1000.0 >= STEP_MIN_S, "%.3f s" % (float(b15 - b2) / 1000.0))
	# D1: the default preset removes ~1 - 1/1.5 of the x1 deficit.
	var d1: float = float(b1 - floor_ms) / 1000.0
	var d15: float = float(b15 - floor_ms) / 1000.0
	var ratio: float = (d15 / d1) if d1 > 0.0 else -1.0
	_check("D1 default preset cuts the deficit to the floor to within [%.2f, %.2f] of x1's" % [CLOSE_LO, CLOSE_HI],
		d1 > 0.0 and ratio >= CLOSE_LO and ratio <= CLOSE_HI,
		"deficit x1 %.3f s -> x1.5 %.3f s (ratio %.3f, target 1/1.5 = 0.667)" % [d1, d15, ratio])
	_check("the default preset is the median one", KartDifficulty.DEFAULT_INDEX == 1 and String(KartDifficulty.PRESETS[1]["id"]) == "x15")
	# D3: personalities survive every preset.
	#
	# ⚠️ NOT at the single tightest sample, which is where the FIRST
	# version of this check looked and where it was WRONG. Measured: at
	# the omega every profile above a_lat ~= 5.1 is pinned to the same
	# 4.17 u/s STEERING limit, so the cat and the boar read exactly equal
	# there the moment difficulty scales a_lat -- and the check went red
	# on personalities that were perfectly intact everywhere else on the
	# lap. The property wanted is "you can tell them apart by watching",
	# which lives over a WHOLE bend and a WHOLE straight, so it is read
	# over the curviest and the straightest quarter of the spine.
	var track: KartTrack = _karting.track
	var ks: Array = []
	for i in track.sample_count():
		ks.append(track.curvature(i))
	var sorted_k: Array = ks.duplicate()
	sorted_k.sort()
	var q_hi: float = float(sorted_k[int(sorted_k.size() * 0.75)])
	var q_lo: float = float(sorted_k[int(sorted_k.size() * 0.25)])
	for id in ["x1", "x15", "x25"]:
		KartDifficulty.set_id(id)
		var cat := KartAiDriver.new()
		cat.setup(track, "cat", 1)
		var boar := KartAiDriver.new()
		boar.setup(track, "boar", 2)
		var cat_curvy: float = _mean_vmax(cat, ks, q_hi, true)
		var boar_curvy: float = _mean_vmax(boar, ks, q_hi, true)
		var cat_flat: float = _mean_vmax(cat, ks, q_lo, false)
		var boar_flat: float = _mean_vmax(boar, ks, q_lo, false)
		_check("D3 %s: the cat is quicker than the boar over the curviest quarter" % id, cat_curvy > boar_curvy,
			"%.3f vs %.3f" % [cat_curvy, boar_curvy])
		_check("D3 %s: the boar is quicker than the cat over the straightest quarter" % id, boar_flat > cat_flat,
			"%.3f vs %.3f" % [boar_flat, cat_flat])
		_check("D3 %s: their lines still differ (corner bias opposite signs)" % id,
			cat.lane_goal_at(_tightest(ks)) * boar.lane_goal_at(_tightest(ks)) < 0.0,
			"%.2f vs %.2f" % [cat.lane_goal_at(_tightest(ks)), boar.lane_goal_at(_tightest(ks))])
	KartDifficulty.set_index(KartDifficulty.DEFAULT_INDEX)

func _tightest(ks: Array) -> int:
	var best: int = 0
	for i in ks.size():
		if float(ks[i]) > float(ks[best]):
			best = i
	return best

## Mean v_max over the samples whose curvature is above (`above`) or below
## the threshold `k`.
func _mean_vmax(d: KartAiDriver, ks: Array, k: float, above: bool) -> float:
	var sum: float = 0.0
	var n: int = 0
	for i in ks.size():
		var c: float = float(ks[i])
		if (c >= k) if above else (c <= k):
			sum += d.vmax_at(i)
			n += 1
	return sum / maxf(float(n), 1.0)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
