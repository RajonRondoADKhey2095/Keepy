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
## SCHEMA v2 (CH29, 6 septembre 2026) -- the first real bump. Adds ONE
## block, and changes the meaning of nothing that v1 carried:
##
##     "cove": {"castles": {"<spot>": stage}, "visited": bool}
##
## `_migrate(1 -> 2)` writes the block's defaults into a v1 document; every
## v1 field is kept as it was. A v1 save therefore boots as "migrated" with
## its counts intact and an empty cove -- CoveProbe writes a real v1 file
## and asserts exactly that (V4SaveProbe's fixtures name SCHEMA_VERSION
## rather than a literal, so they follow the bump).
##
## CH45 (7 septembre 2026): the cove block carried a "yacht" position too,
## between CH29 and here -- the sand yacht's resting place, written on
## every step-off. Removed WITHOUT a schema bump: the yacht now always
## respawns at HubTransport.YACHT_PARK, and a "yacht" key surviving in an
## existing save is simply never read -- _sanitise drops what it does not
## know, the same way it always has for a field this file stopped writing.
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
const SCHEMA_VERSION: int = 2

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
	return _stock(id, TREE_CAPACITY, TREE_RECHARGE_S)

## =====================================================================
## CH53 -- THE WALL-CLOCK STOCK, LIFTED OUT OF THE TREES
##
## The arithmetic below is the trees', unchanged and moved rather than
## rewritten: `tree_stock`/`tree_take` above and below now call it with
## TREE_CAPACITY / TREE_RECHARGE_S and read exactly what they always did.
##
## WHY IT MOVED. CH51 section 2.4 offered three anti-farm guards and
## Mathieu picked G3, "stock sur horloge murale, REUTILISANT le mecanisme
## tree_stock()/TREE_RECHARGE_S deja ecrit et sonde". Reusing it means
## calling it, not copying it: a second lazy-recharge implementation
## would be a second thing to get wrong about a clock that went backwards,
## about banked progress on a partial period, and about an entry that has
## never been touched reading as full.
##
## NO SCHEMA BUMP. The skatepark's stock is an entry in the SAME `trees`
## dictionary under a reserved id, so `_sanitise` already types it and
## `_defaults` already provides it. The clamp there is TREE_CAPACITY, so
## the park's capacity is NOT allowed to exceed it -- see SKATE_CAPACITY.
func _stock(id: String, capacity: int, recharge_s: float) -> int:
	var entries: Dictionary = _data["trees"]
	if not entries.has(id):
		return capacity
	var entry: Dictionary = entries[id]
	var stock: int = int(entry.get("stock", capacity))
	var at: int = int(entry.get("at", 0))
	var elapsed: int = maxi(_now() - at, 0)
	var grown: int = int(floor(float(elapsed) / recharge_s))
	return clampi(stock + grown, 0, capacity)

func _take(id: String, capacity: int, recharge_s: float) -> bool:
	var stock: int = _stock(id, capacity, recharge_s)
	if stock <= 0:
		return false
	var entries: Dictionary = _data["trees"]
	var now: int = _now()
	var at: int = now
	if entries.has(id) and stock < capacity:
		var old_at: int = int(entries[id].get("at", now))
		var elapsed: int = maxi(now - old_at, 0)
		var periods: int = int(floor(float(elapsed) / recharge_s))
		at = old_at + int(periods * recharge_s)
	entries[id] = {"stock": stock - 1, "at": at}
	_mark()
	return true

## Seconds until the tree grows its next nut (0 when full). For a probe
## and for a "spent" reading the HUD may want one day; not gated on.
func tree_recharge_left(id: String) -> float:
	if tree_stock(id) >= TREE_CAPACITY:
		return 0.0
	var entry: Dictionary = _data["trees"][id]
	var elapsed: float = float(maxi(_now() - int(entry.get("at", 0)), 0))
	return TREE_RECHARGE_S - fmod(elapsed, TREE_RECHARGE_S)

## CH53: the same reading for the skatepark's stock, for a HUD that wants
## to say when the park pays again. Not gated on.
func skate_recharge_left() -> float:
	if skate_stock() >= SKATE_CAPACITY:
		return 0.0
	var entry: Dictionary = _data["trees"].get(SKATE_STOCK_ID, {})
	var elapsed: float = float(maxi(_now() - int(entry.get("at", 0)), 0))
	return SKATE_RECHARGE_S - fmod(elapsed, SKATE_RECHARGE_S)

## Takes ONE nut off the tree. Returns false when it is empty. The
## recharge progress already banked is kept: the timestamp only advances
## by whole recharge periods, so a shake 90 s into a 120 s period does not
## throw those 90 s away -- unless the tree was full, in which case the
## clock starts now.
func tree_take(id: String) -> bool:
	if not _take(id, TREE_CAPACITY, TREE_RECHARGE_S):
		return false
	# The shake counter stays HERE and not in _take: a skatepark trick is
	# not a shake, and a shared helper that incremented it would make the
	# stat mean two things at once.
	_data["stats"]["shakes"] = int(_data["stats"].get("shakes", 0)) + 1
	_mark()
	return true

## =====================================================================
## CH53 -- THE LEDGER: award_from_activity, AND THE ONLY ANTI-FARM GUARD
##
## CH51 section 3.1 asked for exactly one function here, and for one
## reason: the guard is a DESIGN decision that will be re-tuned, and a
## rule spread over the callers is a rule that gets re-tuned in one of
## them. A second trick game (a pump track, a half-pipe in the cove) adds
## an ARGUMENT to this call, never a second cooldown.
##
## G3, AND WHY IT IS A STOCK AND NOT A COOLDOWN (Mathieu's call). CH51
## measured what an ungated park earns: 20 to 90 nuts a minute, against
## an exploration loop whose best burst is ~34/min and which runs out --
## the world holds 295 nuts and then rations. A cooldown (G1) caps the
## RATE, so the park still pays forever and the number of modules becomes
## the economy's dial. A stock caps the TOTAL, which is the only thing
## that survives a player who leaves the game running.
##
## WHAT THE GUARD DOES *NOT* STOP, and this is the variant Mathieu chose:
## the trick still scores, the combo still climbs, the HUD still shows
## it. Only the CONVERSION to nuts stops. A park that refused to score
## would read as broken; a park that scores and stops paying reads as a
## park you have already emptied today, which is what every tree in this
## hub already does.
##
## THE POINTS BANK IS RUNTIME-ONLY, deliberately. Points are a display
## quantity; the stock is the persisted one. Banking fractions of a nut
## across sessions would need a schema field to hold something no player
## can see, and losing at most POINTS_PER_NUT - 1 points at a reload is
## not a loss anybody can notice.
##
## Reserved id in the SAME `trees` dictionary the wall-clock stock already
## types and sanitises: no schema bump, no new field, no migration. It
## cannot collide with a tree -- HubTrees ids are "t%d"/"d%d".
const SKATE_STOCK_ID: String = "skatepark"
## =====================================================================
## THE ACTIVITY TABLE -- A TABLE FROM THE FIRST ENTRY
##
## CLAUDE.md: "une table est une liste dès le premier commit". The diving
## board shipped as a generic geometry with a singleton behind it and a
## second plank that was drawn and never climbable; undoing that cost a
## whole lot. `award_from_activity` takes a SOURCE precisely so a second
## trick game is one row here, and a row is what it reads -- never a
## constant reached for directly.
const ACTIVITY_STOCK: Dictionary = {
	&"skate": {"id": SKATE_STOCK_ID, "capacity": TREE_CAPACITY, "recharge": 180.0},
}
## ⚠️ CAPPED BY TREE_CAPACITY, and that is a REAL constraint and not a
## coincidence: `_sanitise` clamps every entry of `trees` to
## TREE_CAPACITY, so a capacity above it would be silently truncated the
## first time the save round-trips -- a park that held 12 before a reload
## and 3 after, with nothing to say why. Raising it means touching the
## sanitiser, which means a schema conversation; 3 does not.
##
## THREE NUTS AND ONE BACK EVERY THREE MINUTES is deliberately a SMALL
## faucet next to the world's: 59 trees hold 295 nuts at the start and
## regrow ~59/min between them. The park is a garnish on the economy, not
## a replacement for walking around it -- which is CH51 section 2.3's
## actual worry ("ce qu'il casse, c'est ce que le nombre VEUT DIRE").
const SKATE_CAPACITY: int = TREE_CAPACITY
const SKATE_RECHARGE_S: float = 180.0
## ⚠️ The two constants above are the SKATE ROW of ACTIVITY_STOCK, read
## back out for the HUD and the probe. They are not a second spelling:
## SkateparkProbe asserts they are what the table holds, so a row edited
## without them would fail loudly instead of leaving a HUD counting down
## to a recharge that is not the one the ledger uses.
## Points a trick has to be worth before the park owes a nut. A quarter-
## pipe is 60 and a bowl 80 (HubSkatepark.MODULES), so a plain run pays
## about every third trick and a chain rather faster -- fast enough that
## the first nut arrives inside the first session, slow enough that the
## stock lasts more than four hops.
const POINTS_PER_NUT: int = 150
## What a trick converts INTO. The common nut, the same one a tree drops:
## the park is another way to get the thing you already know, never a new
## currency (there is exactly one sink in this game, HubBeaver.PRICE).
const AWARD_KIND: StringName = &"hazelnut"

var _activity_bank: Dictionary = {}

## Nuts the park still has to give right now.
func skate_stock() -> int:
	return activity_stock(&"skate")

## What an activity still has to give. -1 for a source with no row, so a
## caller that mistypes gets a value it cannot mistake for "empty".
func activity_stock(source: StringName) -> int:
	var row: Dictionary = ACTIVITY_STOCK.get(source, {})
	if row.is_empty():
		return -1
	return _stock(String(row["id"]), int(row["capacity"]), float(row["recharge"]))

## THE ONE DOOR from a mini-game's score to the shared counters.
##
## Returns what was ACTUALLY credited -- 0 when the guard bit. CH51's
## reason for the return value: the caller has to be able to show the
## right thing without re-deriving the rule, and a caller that re-derives
## it is a second copy of the guard.
##
## `source` is the activity, not the module: the bank and the stock are
## per activity, so a future pump track brings its own of both by passing
## its own name.
func award_from_activity(source: StringName, points: int) -> int:
	if points <= 0:
		return 0
	var key := String(source)
	var bank: int = int(_activity_bank.get(key, 0)) + points
	var owed: int = bank / POINTS_PER_NUT
	if owed <= 0:
		_activity_bank[key] = bank
		return 0
	var row: Dictionary = ACTIVITY_STOCK.get(source, {})
	if row.is_empty():
		push_error("WorldSave.award_from_activity: no stock row for '%s'." % source)
		_activity_bank[key] = bank
		return 0
	var granted: int = 0
	for _n in owed:
		if not _take(String(row["id"]), int(row["capacity"]), float(row["recharge"])):
			break
		granted += 1
	# ⚠️ THE BANK IS SPENT WHETHER OR NOT THE STOCK PAID. Otherwise an
	# empty park would keep a full bank and dump every owed nut at once
	# the instant one grew back -- the guard would cap the total over a
	# session but not over any shorter window, which is exactly the burst
	# it exists to prevent.
	_activity_bank[key] = bank - owed * POINTS_PER_NUT
	if granted > 0:
		add_resource(AWARD_KIND, granted)
	return granted

## V6: one more of a named stat (the inhabitants' counters). Keys are
## listed in STAT_KEYS so _sanitise keeps them; an unknown key is refused
## rather than invented.
## CH53 adds "skate_tricks" and "skate_best_combo" -- ADDITIVE and with NO
## schema bump, which is the pattern kart_races/cove_visits established:
## _sanitise keeps what is listed here and drops what is not, and
## _defaults supplies the 0 for a save written before the key existed.
const STAT_KEYS: Array[String] = ["climbs", "shakes", "picked", "cat_found", "boar_digs", "fawn_nuzzles", "beaver_trades", "kart_laps", "kart_races", "kart_wins", "castles_built", "yacht_rides", "cove_visits", "skate_tricks", "skate_best_combo"]

## ---- CH29 (schema 2): the cove -------------------------------------------
## The castle stage per spot (0..3, 0 = empty, written as an int keyed by
## the spot index as a string -- JSON keys are strings), and whether the
## cove was ever entered. Melting progress is NOT stored: see HubCove.
##
## CH45: the yacht's resting place used to live here too. It never will
## again -- the yacht always respawns at HubTransport.YACHT_PARK.
signal cove_changed()

func cove_castles() -> Dictionary:
	var cove: Dictionary = _data.get("cove", {})
	return (cove.get("castles", {}) as Dictionary).duplicate()

func cove_castle_stage(spot: int) -> int:
	return int(cove_castles().get(str(spot), 0))

## Stage 0 removes the entry rather than storing a zero.
func cove_set_castle(spot: int, stage: int) -> void:
	var castles: Dictionary = _cove_block()["castles"]
	if stage <= 0:
		castles.erase(str(spot))
	else:
		castles[str(spot)] = clampi(stage, 1, 3)
	_mark()
	cove_changed.emit()

func cove_visited() -> bool:
	return bool(_data.get("cove", {}).get("visited", false))

func cove_note_visit() -> void:
	if not cove_visited():
		_cove_block()["visited"] = true
		_data["stats"]["cove_visits"] = int(_data["stats"].get("cove_visits", 0)) + 1
		_mark()
		cove_changed.emit()

func _cove_block() -> Dictionary:
	if not (_data.get("cove", null) is Dictionary):
		_data["cove"] = _cove_defaults()
	return _data["cove"]

static func _cove_defaults() -> Dictionary:
	return {"castles": {}, "visited": false}

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

## CH53: a stat that keeps the BEST value seen rather than a count.
## Same STAT_KEYS gate as note(), same refusal of an unknown key.
func note_max(key: String, value: int) -> void:
	if not STAT_KEYS.has(key):
		push_error("WorldSave.note_max: unknown stat %s" % key)
		return
	if value <= int(_data["stats"].get(key, 0)):
		return
	_data["stats"][key] = value
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
		"stats": {"climbs": 0, "shakes": 0, "picked": 0, "cat_found": 0, "boar_digs": 0, "fawn_nuzzles": 0, "beaver_trades": 0, "castles_built": 0, "yacht_rides": 0, "cove_visits": 0},
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
		# CH29 (schema 2): the cove.
		"cove": _cove_defaults(),
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
	# CH53: the activity bank is RUNTIME state, but it is state a reset is
	# supposed to clear -- points banked toward the next nut are part of
	# "what this save has earned", even though no field holds them. Found
	# by a red pass: with the park's on-foot refusal neutralised, a walk
	# through the modules during an earlier phase left the bank primed,
	# and the next call over the threshold granted a nut a fresh save
	# should not have had.
	_activity_bank.clear()
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
	if from_schema < 2:
		# v1 -> v2 (CH29): the cove block did not exist. Its defaults are
		# written in; nothing v1 carried is touched or reinterpreted.
		out["cove"] = _cove_defaults()
		out["schema"] = 2
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
	# CH29 (schema 2): the cove. A castle stage is 1..3 keyed by a spot
	# index, else dropped. CH45: an orphan "yacht" key from a save written
	# before this lot is simply never read here -- it is not an error.
	var cove: Variant = raw.get("cove", {})
	if cove is Dictionary:
		var castles: Variant = cove.get("castles", {})
		if castles is Dictionary:
			for spot in castles.keys():
				var stage: int = _as_int(castles[spot], 0)
				if String(spot).is_valid_int() and stage >= 1 and stage <= 3:
					out["cove"]["castles"][String(spot)] = stage
		out["cove"]["visited"] = bool(cove.get("visited", false)) if cove.get("visited", false) is bool else false
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
