extends Node
## Carte-blanche v4 -- the world's persistent state, LOCAL ONLY.
##
## One JSON document under user:// (IndexedDB in the Web export), one
## writer (this autoload), one schema version stamped on every write. It
## carries what the player has gathered and what they have changed in the
## world -- never anything that belongs to the leaderboard, to Firestore or
## to an account. The two are deliberately independent: this file works
## the same whether or not anyone is signed in, and it never reads Auth.
##
## =====================================================================
## SCHEMA v1
##
##   {
##     "schema": 1,
##     "saved_at": <unix seconds, int>,
##     "resources": {"acorn": int, "hazelnut": int},
##     "trees": {"<tree id>": {"stock": int, "at": <unix seconds>}},
##     "ground": [[x, z, "acorn"|"hazelnut"], ...],
##     "stats": {"climbs": int, "shakes": int, "picked": int}
##   }
##
## Tree stock RECHARGES ON THE WALL CLOCK, lazily: a tree entry stores the
## stock it had the last time it changed and WHEN, and `tree_stock()` adds
## one nut per TREE_RECHARGE_S elapsed since, capped at TREE_CAPACITY. A
## tree that is never touched has no entry and reads as full. So the world
## refills while the page is closed, nothing runs a timer, and the save
## only grows by the trees the player actually shook.
##
## ROBUSTNESS, the one rule that matters: a missing, corrupt, foreign or
## future save NEVER blocks the boot. Every read goes through a typed
## sanitiser with a default; a schema newer than this file's is discarded
## (we cannot read what we do not know); an older one is migrated in
## `_migrate` (nothing to migrate yet -- v1 is the first). Unreadable means
## "start from zero, silently", never a crash and never a dialog.
##
## WRITES are debounced (mark dirty, flush 0.4 s later from _process) and
## forced on the close request / focus loss / pause notifications, so a
## burst of pickups costs one file write and a tab closed mid-burst still
## keeps what it had. On Web, closing the file is what triggers the IDBFS
## sync, which is why the flush opens and closes the file every time
## instead of keeping a handle.

const SAVE_PATH: String = "user://keepy_world.json"
## A probe points an instance at a throw-away file; empty means SAVE_PATH.
var SAVE_PATH_OVERRIDE: String = ""

func _path() -> String:
	return SAVE_PATH if SAVE_PATH_OVERRIDE.is_empty() else SAVE_PATH_OVERRIDE
const SCHEMA_VERSION: int = 1

## How many nuts a climbable tree holds when full, and the wall-clock
## seconds it takes to grow ONE back. Two minutes: long enough that a tree
## reads as "spent" after a shake, short enough that a player who walks to
## the next map and back finds it refilled -- tuned for the rhythm of one
## session, not for retention.
const TREE_CAPACITY: int = 3
const TREE_RECHARGE_S: float = 120.0

## v5: the ladybug (falls, scurries, flees -- caught or gone) and the golden
## acorn (the rare one, paced by the shake count).
## V6: the truffle (dug up by the boar) and the flower (given by the fawn).
## Additive: an older save simply reads 0 for them (_sanitise defaults
## every kind), no schema bump.
const KINDS: Array[StringName] = [&"acorn", &"hazelnut", &"ladybug", &"golden", &"truffle", &"flower"]
const FLUSH_DELAY_S: float = 0.4
const GROUND_CAP: int = 40

## `total` is the new count of `kind`; `delta` what just changed it.
signal resources_changed(kind: StringName, total: int, delta: int)
## After reset(): every consumer that caches a value re-reads.
signal reset_done

var _data: Dictionary = {}
var _dirty: bool = false
var _flush_in: float = -1.0
## Where the state came from at boot, for the journal and the probes:
## "fresh", "loaded", "corrupt", "future", "migrated".
var boot_status: String = "fresh"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_data = _defaults()
	_load()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _dirty:
			save_now()

func _process(delta: float) -> void:
	if not _dirty:
		return
	_flush_in -= delta
	if _flush_in <= 0.0:
		save_now()

## ---- resources ---------------------------------------------------------

func resource(kind: StringName) -> int:
	return int(_data["resources"].get(String(kind), 0))

func resources() -> Dictionary:
	return _data["resources"].duplicate()

func add_resource(kind: StringName, amount: int = 1) -> int:
	var key := String(kind)
	var total: int = maxi(int(_data["resources"].get(key, 0)) + amount, 0)
	_data["resources"][key] = total
	_data["stats"]["picked"] = int(_data["stats"].get("picked", 0)) + maxi(amount, 0)
	_mark()
	resources_changed.emit(kind, total, amount)
	return total

## ---- trees --------------------------------------------------------------

func _now() -> int:
	return int(Time.get_unix_time_from_system())

## Nuts the tree holds RIGHT NOW: the stored stock plus what grew back
## since, capped. A clock that went backwards counts as no time elapsed.
func tree_stock(id: String) -> int:
	var trees: Dictionary = _data["trees"]
	if not trees.has(id):
		return TREE_CAPACITY
	var entry: Dictionary = trees[id]
	var stock: int = int(entry.get("stock", TREE_CAPACITY))
	var at: int = int(entry.get("at", 0))
	var elapsed: int = maxi(_now() - at, 0)
	var grown: int = int(floor(float(elapsed) / TREE_RECHARGE_S))
	return clampi(stock + grown, 0, TREE_CAPACITY)

## Seconds until the tree grows its next nut (0 when full). For a probe
## and for a "spent" reading the HUD may want one day; not gated on.
func tree_recharge_left(id: String) -> float:
	if tree_stock(id) >= TREE_CAPACITY:
		return 0.0
	var entry: Dictionary = _data["trees"][id]
	var elapsed: float = float(maxi(_now() - int(entry.get("at", 0)), 0))
	return TREE_RECHARGE_S - fmod(elapsed, TREE_RECHARGE_S)

## Takes ONE nut off the tree. Returns false when it is empty. The
## recharge progress already banked is kept: the timestamp only advances
## by whole recharge periods, so a shake 90 s into a 120 s period does not
## throw those 90 s away -- unless the tree was full, in which case the
## clock starts now.
func tree_take(id: String) -> bool:
	var stock: int = tree_stock(id)
	if stock <= 0:
		return false
	var trees: Dictionary = _data["trees"]
	var now: int = _now()
	var at: int = now
	if trees.has(id) and stock < TREE_CAPACITY:
		var old_at: int = int(trees[id].get("at", now))
		var elapsed: int = maxi(now - old_at, 0)
		var periods: int = int(floor(float(elapsed) / TREE_RECHARGE_S))
		at = old_at + int(periods * TREE_RECHARGE_S)
	trees[id] = {"stock": stock - 1, "at": at}
	_data["stats"]["shakes"] = int(_data["stats"].get("shakes", 0)) + 1
	_mark()
	return true

## V6: one more of a named stat (the inhabitants' counters). Keys are
## listed in STAT_KEYS so _sanitise keeps them; an unknown key is refused
## rather than invented.
const STAT_KEYS: Array[String] = ["climbs", "shakes", "picked", "cat_found", "boar_digs", "fawn_nuzzles", "beaver_trades", "kart_laps", "kart_races", "kart_wins"]

## ---- v7: karting ---------------------------------------------------------
## Best lap per TRACK ID, in milliseconds (an int survives JSON exactly; a
## float would not). Keyed by track so a second circuit is a second key,
## not a second field. Additive to schema v1 like the v5 reserved fields:
## no existing field changes meaning, an older build ignores the key.
signal kart_best_changed(track_id: String, best_ms: int)

func kart_best_ms(track_id: String) -> int:
	var kart: Dictionary = _data.get("kart", {})
	var best: Dictionary = kart.get("best_ms", {})
	return _as_int(best.get(track_id, 0), 0)

## Records `lap_ms` if it beats the stored best (or there is none). Returns
## true when it did -- the HUD's "nouveau record" reads this, never
## re-compares.
func kart_offer_lap(track_id: String, lap_ms: int) -> bool:
	if lap_ms <= 0:
		return false
	var current: int = kart_best_ms(track_id)
	if current > 0 and lap_ms >= current:
		return false
	_data["kart"]["best_ms"][track_id] = lap_ms
	_mark()
	kart_best_changed.emit(track_id, lap_ms)
	return true

## ---- V8 (karting lot 2): the last race result ----------------------------
## Additive to schema v1 like best_ms: `kart.last` is one dictionary
## {track_id, rank, racers, total_ms, best_lap_ms}, replaced on every
## finished race; the counts live in stats (kart_races, kart_wins). An
## older build ignores the key, a newer one reads what _sanitise kept.
signal kart_result_changed(result: Dictionary)

func kart_last_result() -> Dictionary:
	var kart: Dictionary = _data.get("kart", {})
	var last: Variant = kart.get("last", {})
	return (last as Dictionary).duplicate() if last is Dictionary else {}

func kart_record_result(track_id: String, rank: int, racers: int, total_ms: int, best_lap_ms: int) -> void:
	if not _data.has("kart"):
		_data["kart"] = {"best_ms": {}}
	_data["kart"]["last"] = {"track_id": track_id, "rank": rank, "racers": racers, "total_ms": total_ms, "best_lap_ms": best_lap_ms}
	_data["stats"]["kart_races"] = int(_data["stats"].get("kart_races", 0)) + 1
	if rank == 1:
		_data["stats"]["kart_wins"] = int(_data["stats"].get("kart_wins", 0)) + 1
	_mark()
	kart_result_changed.emit(kart_last_result())

func note(key: String) -> void:
	if not STAT_KEYS.has(key):
		push_error("WorldSave.note: unknown stat %s" % key)
		return
	_data["stats"][key] = int(_data["stats"].get(key, 0)) + 1
	_mark()

func note_climb() -> void:
	_data["stats"]["climbs"] = int(_data["stats"].get("climbs", 0)) + 1
	_mark()

## v5: the reserved fields, read-only until the placing session.
func next_id() -> int:
	return int(_data.get("next_id", 1))

func placed() -> Array:
	return _data.get("placed", []).duplicate()

func stats() -> Dictionary:
	return _data["stats"].duplicate()

## ---- nuts lying on the ground -------------------------------------------

## Each entry is [x, z, kind]. Replaced wholesale by the node that owns the
## nuts: it is the one thing that knows where they rolled to.
func ground_nuts() -> Array:
	return _data["ground"].duplicate(true)

func set_ground_nuts(list: Array) -> void:
	var out: Array = []
	for item in list:
		if item is Array and item.size() >= 3:
			out.append([snappedf(float(item[0]), 0.01), snappedf(float(item[1]), 0.01), String(item[2])])
		if out.size() >= GROUND_CAP:
			break
	_data["ground"] = out
	_mark()

## ---- persistence --------------------------------------------------------

func _defaults() -> Dictionary:
	var res := {}
	for kind in KINDS:
		res[String(kind)] = 0
	return {
		"schema": SCHEMA_VERSION,
		"saved_at": 0,
		"resources": res,
		"trees": {},
		"ground": [],
		"stats": {"climbs": 0, "shakes": 0, "picked": 0, "cat_found": 0, "boar_digs": 0, "fawn_nuzzles": 0, "beaver_trades": 0},
		# v5: RESERVED for the objects a player will one day PLACE (plants,
		# craft): a stable id for each, generated from this counter, and
		# the list itself. Nothing reads or writes them tonight; they exist
		# so the first placed object ever saved already has an id -- the
		# one thing the v4 harvest said could not be added after the fact.
		# No schema bump: the meaning of no existing field changes.
		"next_id": 1,
		"placed": [],
		# v7: karting. best_ms is {track_id: int ms}.
		"kart": {"best_ms": {}},
	}

func _mark() -> void:
	_dirty = true
	if _flush_in < 0.0:
		_flush_in = FLUSH_DELAY_S

func save_now() -> void:
	_dirty = false
	_flush_in = -1.0
	_data["schema"] = SCHEMA_VERSION
	_data["saved_at"] = _now()
	var file := FileAccess.open(_path(), FileAccess.WRITE)
	if file == null:
		push_warning("WorldSave: cannot open %s for writing (%d)" % [_path(), FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(_data))
	file.close()

## Wipes the save and the in-memory state. Behind DevTools.enabled() in
## the menu ("Sauvegarde (dev) : zéro"), and unreachable for a player: a
## first launch, reproducible, for whoever is validating one.
func reset() -> void:
	_data = _defaults()
	_dirty = false
	_flush_in = -1.0
	if FileAccess.file_exists(_path()):
		var err := DirAccess.remove_absolute(_path())
		if err != OK:
			# Cannot delete: overwrite with the defaults instead, which
			# reads back as a fresh state too.
			save_now()
	boot_status = "fresh"
	reset_done.emit()
	for kind in KINDS:
		resources_changed.emit(kind, 0, 0)

func _load() -> void:
	boot_status = "fresh"
	if not FileAccess.file_exists(_path()):
		return
	var file := FileAccess.open(_path(), FileAccess.READ)
	if file == null:
		boot_status = "corrupt"
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		boot_status = "corrupt"
		return
	var raw: Dictionary = parsed
	var schema: int = _as_int(raw.get("schema", 0), 0)
	if schema > SCHEMA_VERSION:
		# Written by a newer build: we cannot know what it means. Start
		# over rather than half-read it.
		boot_status = "future"
		return
	if schema < SCHEMA_VERSION:
		raw = _migrate(raw, schema)
		boot_status = "migrated"
	else:
		boot_status = "loaded"
	_data = _sanitise(raw)

## Older schemas are lifted to the current one here, one step per version.
## v1 is the first, so there is nothing to do yet -- but the hook exists
## from the first write, so the day v2 lands it is a case, not a redesign.
func _migrate(raw: Dictionary, from_schema: int) -> Dictionary:
	var out: Dictionary = raw.duplicate(true)
	if from_schema < 1:
		# Pre-versioned (no "schema" key at all): nothing this file ever
		# wrote, so treat as empty.
		out = {}
	return out

## Every field typed and defaulted. A malformed piece is dropped, never the
## whole save -- a corrupt tree entry costs that tree's memory, not the
## player's counts.
func _sanitise(raw: Dictionary) -> Dictionary:
	var out: Dictionary = _defaults()
	var res: Variant = raw.get("resources", {})
	if res is Dictionary:
		for kind in KINDS:
			out["resources"][String(kind)] = maxi(_as_int(res.get(String(kind), 0), 0), 0)
	var trees: Variant = raw.get("trees", {})
	if trees is Dictionary:
		for id in trees.keys():
			var entry: Variant = trees[id]
			if entry is Dictionary:
				out["trees"][String(id)] = {
					"stock": clampi(_as_int(entry.get("stock", TREE_CAPACITY), TREE_CAPACITY), 0, TREE_CAPACITY),
					"at": maxi(_as_int(entry.get("at", 0), 0), 0),
				}
	var ground: Variant = raw.get("ground", [])
	if ground is Array:
		for item in ground:
			if item is Array and item.size() >= 3 and (item[0] is float or item[0] is int) \
					and (item[1] is float or item[1] is int) and item[2] is String \
					and KINDS.has(StringName(item[2])):
				out["ground"].append([float(item[0]), float(item[1]), String(item[2])])
			if out["ground"].size() >= GROUND_CAP:
				break
	var stats: Variant = raw.get("stats", {})
	if stats is Dictionary:
		for key in STAT_KEYS:
			out["stats"][key] = maxi(_as_int(stats.get(key, 0), 0), 0)
	out["saved_at"] = maxi(_as_int(raw.get("saved_at", 0), 0), 0)
	# v5 reserved fields: a counter that never goes below 1, a list that
	# keeps only dictionaries (the future reader decides their shape).
	out["next_id"] = maxi(_as_int(raw.get("next_id", 1), 1), 1)
	var placed: Variant = raw.get("placed", [])
	if placed is Array:
		for item in placed:
			if item is Dictionary:
				out["placed"].append(item)
	# v7: a best lap is a positive int keyed by a non-empty track id;
	# anything else is dropped, never the whole table.
	var kart: Variant = raw.get("kart", {})
	if kart is Dictionary:
		var best: Variant = kart.get("best_ms", {})
		if best is Dictionary:
			for id in best.keys():
				var ms: int = _as_int(best[id], 0)
				if String(id) != "" and ms > 0:
					out["kart"]["best_ms"][String(id)] = ms
		# V8: the last race result -- ints, positive rank, or nothing.
		var last: Variant = kart.get("last", {})
		if last is Dictionary and String(last.get("track_id", "")) != "":
			var rank: int = _as_int(last.get("rank", 0), 0)
			if rank > 0:
				out["kart"]["last"] = {
					"track_id": String(last.get("track_id", "")),
					"rank": rank,
					"racers": maxi(_as_int(last.get("racers", 0), 0), rank),
					"total_ms": maxi(_as_int(last.get("total_ms", 0), 0), 0),
					"best_lap_ms": maxi(_as_int(last.get("best_lap_ms", 0), 0), 0),
				}
	return out

static func _as_int(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float:
		if is_nan(value) or is_inf(value):
			return fallback
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	return fallback
