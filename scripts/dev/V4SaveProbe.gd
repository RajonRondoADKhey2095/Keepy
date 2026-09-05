extends Node
## Carte-blanche v4 P0 -- WorldSave contract, headless.
##
## Positive first (blind check): a value written is a value read back from
## a FRESH instance of the script -- only then do the refusals mean
## anything. Then: a corrupt file, a future schema, a malformed field, the
## lazy recharge with a clock the probe controls, and reset().
##
## Runs against a throw-away path so it never touches the player's save.
## Exit 0 = every assertion held; 1 = at least one failed (listed);
## ProbeWatchdog.EXIT_TIMEOUT = INCONCLUSIVE (ran out of wall clock).

const SaveScript := preload("res://scripts/autoload/WorldSave.gd")
var _fails: Array[String] = []
var _checks: int = 0

class FakeClock extends "res://scripts/autoload/WorldSave.gd":
	var now: int = 1_000_000
	func _now() -> int:
		return now

func _check(name: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_fails.append("%s %s" % [name, detail])
	print("  [%s] %s %s" % ["ok" if ok else "FAIL", name, detail])

func _fresh() -> FakeClock:
	# Not added to the tree: _ready() would run _load() against the
	# autoload's path. Loaded by hand instead.
	var s := FakeClock.new()
	s._data = s._defaults()
	return s

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract. 60s, not the 900s
	# default: this probe does no simulation at all -- it is file I/O and
	# arithmetic, and it finishes in under a second. Anything approaching
	# a minute here is a hang, not a slow machine.
	ProbeWatchdog.arm(self, "V4 SAVE PROBE", 60.0)
	var path := "user://v4_probe_world.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	# ---- PHASE A (positive): write, then read back from a new instance.
	var a := _fresh()
	a.SAVE_PATH_OVERRIDE = path
	a.add_resource(&"acorn", 3)
	a.add_resource(&"hazelnut", 1)
	a.add_resource(&"acorn", 2)
	_check("A.count", a.resource(&"acorn") == 5, str(a.resource(&"acorn")))
	a.tree_take("t1")
	a.set_ground_nuts([[1.234, -5.678, "acorn"], [0.0, 0.0, "hazelnut"]])
	a.save_now()
	_check("A.file_exists", FileAccess.file_exists(path))
	var b := _fresh()
	b.SAVE_PATH_OVERRIDE = path
	b.now = a.now
	b._load()
	_check("A.reload_status", b.boot_status == "loaded", b.boot_status)
	_check("A.reload_acorn", b.resource(&"acorn") == 5, str(b.resource(&"acorn")))
	_check("A.reload_hazelnut", b.resource(&"hazelnut") == 1, str(b.resource(&"hazelnut")))
	_check("A.reload_tree", b.tree_stock("t1") == SaveScript.TREE_CAPACITY - 1, str(b.tree_stock("t1")))
	_check("A.reload_ground", b.ground_nuts().size() == 2 and b.ground_nuts()[0][2] == "acorn", str(b.ground_nuts()))
	_check("A.untouched_tree_full", b.tree_stock("never") == SaveScript.TREE_CAPACITY)
	# v5: the reserved fields round-trip with their defaults.
	_check("A.reserved_next_id", b.next_id() == 1, str(b.next_id()))
	_check("A.reserved_placed_empty", b.placed().is_empty(), str(b.placed()))

	# ---- PHASE B: recharge on the wall clock, lazily.
	var c := _fresh()
	c.now = 5000
	for i in SaveScript.TREE_CAPACITY:
		_check("B.take_%d" % i, c.tree_take("oak"))
	_check("B.empty_refuses", not c.tree_take("oak"))
	_check("B.stock_0", c.tree_stock("oak") == 0)
	c.now = 5000 + int(SaveScript.TREE_RECHARGE_S) - 1
	_check("B.not_yet", c.tree_stock("oak") == 0, str(c.tree_stock("oak")))
	c.now = 5000 + int(SaveScript.TREE_RECHARGE_S)
	_check("B.one_back", c.tree_stock("oak") == 1, str(c.tree_stock("oak")))
	# Take that one 30 s later: the banked partial progress survives.
	c.now = 5000 + int(SaveScript.TREE_RECHARGE_S) + 30
	_check("B.take_regrown", c.tree_take("oak"))
	c.now = 5000 + int(SaveScript.TREE_RECHARGE_S) * 2
	_check("B.progress_kept", c.tree_stock("oak") == 1, str(c.tree_stock("oak")))
	c.now = 5000 + int(SaveScript.TREE_RECHARGE_S) * 40
	_check("B.capped", c.tree_stock("oak") == SaveScript.TREE_CAPACITY, str(c.tree_stock("oak")))
	_check("B.left_zero_when_full", c.tree_recharge_left("oak") == 0.0)
	# Take one at the capped time, then wind the clock BACK: no time has
	# elapsed as far as the tree is concerned, so it stays where it was
	# (the documented conservative answer -- never a negative, never a crash).
	_check("B.take_at_cap", c.tree_take("oak"))
	c.now = 100
	_check("B.clock_backwards", c.tree_stock("oak") == SaveScript.TREE_CAPACITY - 1, str(c.tree_stock("oak")))
	_check("B.left_positive", c.tree_recharge_left("oak") > 0.0 and c.tree_recharge_left("oak") <= SaveScript.TREE_RECHARGE_S)

	# ---- PHASE C: refusals. Each one must read as FRESH, never crash.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{this is not json")
	f.close()
	var d := _fresh(); d.SAVE_PATH_OVERRIDE = path; d._load()
	_check("C.corrupt_status", d.boot_status == "corrupt", d.boot_status)
	_check("C.corrupt_zero", d.resource(&"acorn") == 0)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[1,2,3]")
	f.close()
	var d2 := _fresh(); d2.SAVE_PATH_OVERRIDE = path; d2._load()
	_check("C.array_status", d2.boot_status == "corrupt", d2.boot_status)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 99, "resources": {"acorn": 42}}))
	f.close()
	var e := _fresh(); e.SAVE_PATH_OVERRIDE = path; e._load()
	_check("C.future_status", e.boot_status == "future", e.boot_status)
	_check("C.future_zero", e.resource(&"acorn") == 0, str(e.resource(&"acorn")))
	# Malformed fields inside a valid v1: the bad piece is dropped, the
	# rest is kept.
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 1, "resources": {"acorn": "7", "hazelnut": -4},
		"trees": {"ok": {"stock": 1, "at": 10}, "bad": "x", "big": {"stock": 99, "at": "nope"}},
		"ground": [[1, 2, "acorn"], "junk", [1, 2, "gold"], [1]], "stats": 12}))
	f.close()
	var g := _fresh(); g.SAVE_PATH_OVERRIDE = path; g.now = 10; g._load()
	_check("C.partial_status", g.boot_status == "loaded", g.boot_status)
	_check("C.partial_acorn_str", g.resource(&"acorn") == 7, str(g.resource(&"acorn")))
	_check("C.partial_neg_clamped", g.resource(&"hazelnut") == 0, str(g.resource(&"hazelnut")))
	_check("C.partial_tree_ok", g.tree_stock("ok") == 1, str(g.tree_stock("ok")))
	_check("C.partial_tree_bad_dropped", g.tree_stock("bad") == SaveScript.TREE_CAPACITY)
	_check("C.partial_tree_big_clamped", g.tree_stock("big") == SaveScript.TREE_CAPACITY, str(g.tree_stock("big")))
	_check("C.partial_ground_one", g.ground_nuts().size() == 1, str(g.ground_nuts()))
	# v5: reserved fields sanitised -- a bad counter floors at 1, a list
	# keeps its dictionaries only.
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 1, "next_id": -3, "placed": [{"id": 1}, "junk", 4, {"id": 2}]}))
	f.close()
	var g2 := _fresh(); g2.SAVE_PATH_OVERRIDE = path; g2._load()
	_check("C.reserved_next_id_floor", g2.next_id() == 1, str(g2.next_id()))
	_check("C.reserved_placed_dicts", g2.placed().size() == 2, str(g2.placed()))
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 1, "next_id": 42, "placed": "nope"}))
	f.close()
	var g3 := _fresh(); g3.SAVE_PATH_OVERRIDE = path; g3._load()
	_check("C.reserved_next_id_kept", g3.next_id() == 42, str(g3.next_id()))
	_check("C.reserved_placed_not_array", g3.placed().is_empty(), str(g3.placed()))
	# Pre-versioned (no schema key): migrated to empty.
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"resources": {"acorn": 3}}))
	f.close()
	var h := _fresh(); h.SAVE_PATH_OVERRIDE = path; h._load()
	_check("C.unversioned_migrated", h.boot_status == "migrated", h.boot_status)
	_check("C.unversioned_zero", h.resource(&"acorn") == 0, str(h.resource(&"acorn")))

	# ---- PHASE D: reset wipes the file and the memory.
	var k := _fresh(); k.SAVE_PATH_OVERRIDE = path
	k.add_resource(&"acorn", 9)
	k.save_now()
	k.reset()
	_check("D.reset_memory", k.resource(&"acorn") == 0)
	_check("D.reset_file", not FileAccess.file_exists(path))
	var m := _fresh(); m.SAVE_PATH_OVERRIDE = path; m._load()
	_check("D.reset_reload_fresh", m.boot_status == "fresh", m.boot_status)

	print("V4SaveProbe: %d checks, %d failed" % [_checks, _fails.size()])
	for line in _fails:
		print("  FAILED: " + line)
	get_tree().quit(0 if _fails.is_empty() else 1)
