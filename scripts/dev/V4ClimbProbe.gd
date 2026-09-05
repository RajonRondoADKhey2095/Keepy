extends Node
## Carte-blanche v4 P1 -- the tree ride, traced and captured.
##
## Headless (--fixed-fps 60): taps a climbable tree from wherever Keepy
## stands, traces his position / state / phase every 10 frames, and
## asserts the contract: he reaches the seat (carried by the tree, at the
## seat's height), a tap during the ascent brings him down as soon as he
## is seated, a tap from the seat brings him down toward that point, he
## ends IDLE on the ground and the tree is released. Under xvfb +
## opengl3, --shots=f1,f2 also writes the 3D viewport at those frames.
##
##   --at=X,Z       where Keepy starts (default 0,0)
##   --tree=I       which tree to tap (default 0)
##   --exit=F       frame at which a ground tap is made (default 0 = none)
##   --exit_at=X,Z  where that tap lands (default: 3 u south of the foot);
##                  "nut" aims at the first nut resting on the ground
##   --shake=F      frame at which the seated tree is tapped (a shake)
##   --shots=a,b,c  frames to capture (needs a real driver)
##   --out=DIR      capture directory (default /tmp)
##   --frames=N     total frames (default 600)
##   --p2           v5: the shake is made the 12th of the save and the
##                  ladybug roll forced, so it drops a GOLDEN acorn and a
##                  LADYBUG with the nuts; asserts the leaves fall and go,
##                  the ladybug moves, and the walk of shake_extras' pacing.
##                  "--exit_at=bug" aims the exit tap at the ladybug, and
##                  "--chase" re-taps its live position every 20 frames
##                  after the exit, the way a player chases it.
##   --list         v5: print every climbable tree (perchoirs first, then
##                  the decor trees HubTrees adopted) and every exclusion,
##                  then quit 0 -- the recon of the general climb
##
## Exit 0 = every assertion held, 1 = at least one did not,
## ProbeWatchdog.EXIT_TIMEOUT = INCONCLUSIVE (ran out of wall clock).
##
## Touches NO real save: WorldSave is pointed at a throw-away path before
## anything is written, and the shake counter is advanced through the
## public tree_take() rather than by reaching into WorldSave._data.

var _hub: Node = null
var _keepy: Node = null
var _trees: Node = null
var _at: Vector3 = Vector3.ZERO
var _tree: int = 0
var _exit_frame: int = 0
var _exit_at: Vector3 = Vector3.INF
var _shots: Array[int] = []
var _out: String = "/tmp"
var _frames_total: int = 600
var _frames: int = 0
var _trace: Array = []
var _fails: Array[String] = []
var _seen_seated: bool = false
var _seated_frame: int = -1
var _max_y: float = 0.0
var _seat_samples: Array = []
var _phases_seen: Dictionary = {}
var _exit_phase: int = -1
var _shake_frame: int = 0
var _exit_nut: bool = false
var _stock_before: int = -1
var _acorns_before: int = 0
var _hazel_before: int = 0
var _list: bool = false
var _p2: bool = false
var _chase: bool = false
var _exit_bug: bool = false
var _bug_first: Vector3 = Vector3.INF
var _bug_moved: float = 0.0
var _leaves_peak: int = 0
var _ladybug_before: int = 0
var _golden_before: int = 0

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract: a watchdog armed after
	# the thing that hangs is not a watchdog. 240s, not the 900s default --
	# this probe simulates at most a few hundred fixed-fps frames, so ten
	# times its real runtime is already generous.
	ProbeWatchdog.arm(self, "V4 CLIMB PROBE", 240.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var p := arg.substr(5).split(",")
			_at = Vector3(float(p[0]), 0.0, float(p[1]))
		elif arg.begins_with("--tree="):
			_tree = int(arg.substr(7))
		elif arg.begins_with("--exit="):
			_exit_frame = int(arg.substr(7))
		elif arg == "--exit_at=nut":
			_exit_nut = true
		elif arg == "--exit_at=bug":
			_exit_bug = true
		elif arg.begins_with("--exit_at="):
			var p := arg.substr(10).split(",")
			_exit_at = Vector3(float(p[0]), 0.0, float(p[1]))
		elif arg.begins_with("--shake="):
			_shake_frame = int(arg.substr(8))
		elif arg.begins_with("--shots="):
			for f in arg.substr(8).split(","):
				_shots.append(int(f))
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--frames="):
			_frames_total = int(arg.substr(9))
		elif arg == "--list":
			_list = true
		elif arg == "--p2":
			_p2 = true
		elif arg == "--chase":
			_chase = true
	# A known save, on a throw-away path. The override goes on FIRST: with
	# it empty this would reset() and then write the player's real
	# user://keepy_world.json, which on a developer machine is a save
	# someone may care about.
	WorldSave.SAVE_PATH_OVERRIDE = "user://v4_climb_probe_world.json"
	WorldSave.reset()
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	if _p2:
		# The next shake must be the save's 12th (GOLDEN_FIRST) and its
		# ladybug draw must come in under LADYBUG_CHANCE.
		#
		# BOTH are set through the shipped path, not by writing into
		# WorldSave._data or forcing an outcome on HubWorld:
		#   * the counter is advanced by real tree_take() calls, one per
		#     throw-away tree id, which is the only thing that increments
		#     "shakes" for a player either;
		#   * the draw is fixed by SEEDING HubWorld's extras RNG, and the
		#     seed is FOUND rather than picked -- scanned until its first
		#     draw is one the shipped LADYBUG_CHANCE would accept. A seed
		#     cannot make the pacing say anything it would not say on its
		#     own, which a forced roll could.
		for i in _hub.GOLDEN_FIRST - 1:
			WorldSave.tree_take("v4probe_%d" % i)
		var got: int = int(WorldSave.stats().get("shakes", 0))
		if got != _hub.GOLDEN_FIRST - 1:
			_fails.append("p2.setup_shakes expected %d got %d" % [_hub.GOLDEN_FIRST - 1, got])
		var rng := RandomNumberGenerator.new()
		var seed_found: int = -1
		for candidate in range(1, 10000):
			rng.seed = candidate
			if rng.randf() < _hub.LADYBUG_CHANCE:
				seed_found = candidate
				break
		if seed_found < 0:
			_fails.append("p2.setup_seed no seed under LADYBUG_CHANCE in 10000")
		else:
			print("P2_SEED %d (first draw under LADYBUG_CHANCE=%.2f)" % [seed_found, _hub.LADYBUG_CHANCE])
			_hub.set_extras_seed(seed_found)
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
	_trees = _hub.get_node("WorldViewport/SubViewport/World/Trees")
	_keepy.global_position = _at
	var cam: Node = _hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	cam.call("snap_to_target")

func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails.append("%s %s" % [name, detail])
	print("  [%s] %s %s" % ["ok" if ok else "FAIL", name, detail])

func _process(_delta: float) -> void:
	_frames += 1
	if _list and _frames == 3:
		_print_list()
		get_tree().quit(0 if _fails.is_empty() else 1)
		return
	if _frames == 5:
		var at: Vector3 = _trees.call("position_of", _tree)
		print("TREE_TAP tree %d at %s foot %s spec %s" % [_tree, at, _trees.call("foot_point", _tree), _trees.call("climb_spec", _tree)])
		_hub.get_node("TapInput").emit_signal("tapped_tree", at, _tree)
	if _shake_frame > 0 and _frames == _shake_frame:
		_stock_before = WorldSave.tree_stock(_trees.call("tree_id", _tree))
		_acorns_before = WorldSave.resource(&"acorn")
		_hazel_before = WorldSave.resource(&"hazelnut")
		_ladybug_before = WorldSave.resource(&"ladybug")
		_golden_before = WorldSave.resource(&"golden")
		print("SHAKE_TAP at frame %d (phase %d, stock %d)" % [_frames, _keepy.call("tree_phase"), _stock_before])
		_hub.get_node("TapInput").emit_signal("tapped_ground", _trees.call("position_of", _tree))
	if _exit_frame > 0 and _frames == _exit_frame:
		var target: Vector3 = _exit_at
		if _exit_bug:
			var nuts: Node = _hub.call("nuts")
			var bug: Vector3 = nuts.call("ladybug_position")
			if bug != Vector3.INF:
				target = Vector3(bug.x, 0.0, bug.z)
			print("EXIT_AT_BUG %s" % target)
		if _exit_nut:
			var nuts: Node = _hub.call("nuts")
			for nut in nuts._nuts:
				if nut["resting"]:
					target = Vector3(nut["pos"].x, 0.0, nut["pos"].z)
					break
			print("EXIT_AT_NUT resting=%d airborne=%d target=%s" % [nuts.call("resting_count"), nuts.call("airborne_count"), target])
		if target == Vector3.INF:
			var foot: Vector3 = _trees.call("foot_point", _tree)
			target = foot + Vector3(0.0, 0.0, 3.0)
		_exit_at = target
		_exit_phase = _keepy.call("tree_phase")
		print("EXIT_TAP at frame %d -> %s (phase %d)" % [_frames, target, _exit_phase])
		_hub.get_node("TapInput").emit_signal("tapped_ground", target)
	var pos: Vector3 = _keepy.global_position
	var phase: int = _keepy.call("tree_phase")
	if _keepy.call("is_on_tree"):
		_phases_seen[phase] = true
		_max_y = maxf(_max_y, pos.y)
	if _keepy.call("is_seated_on_tree"):
		if not _seen_seated:
			_seen_seated = true
			_seated_frame = _frames
		_seat_samples.append(pos)
	if _p2:
		var nuts: Node = _hub.call("nuts")
		if _chase and _exit_frame > 0 and _frames > _exit_frame and _frames % 20 == 0 and not _keepy.call("is_on_tree"):
			var live: Vector3 = nuts.call("ladybug_position")
			if live != Vector3.INF:
				_hub.get_node("TapInput").emit_signal("tapped_ground", Vector3(live.x, 0.0, live.z))
		_leaves_peak = maxi(_leaves_peak, int(nuts.call("leaf_count")))
		var bug: Vector3 = nuts.call("ladybug_position")
		if bug != Vector3.INF:
			if _bug_first == Vector3.INF:
				_bug_first = bug
			else:
				_bug_moved = maxf(_bug_moved, Vector2(bug.x - _bug_first.x, bug.z - _bug_first.z).length())
	if _frames % 10 == 0:
		_trace.append([_frames, snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01), _keepy.call("is_on_tree"), phase, _trees.call("occupied")])
	if _shots.has(_frames):
		_shot(_frames)
	if _frames >= _frames_total:
		_finish()

func _shot(frame: int) -> void:
	var sub: SubViewport = _hub.get_node("WorldViewport/SubViewport")
	var image: Image = sub.get_texture().get_image()
	if image == null:
		push_error("V4ClimbProbe: no image at frame %d (headless?)" % frame)
		return
	var path := "%s/climb_%d.png" % [_out, frame]
	image.save_png(path)
	print("SHOT %s" % path)

func _finish() -> void:
	set_process(false)
	for row in _trace:
		print("  trace %s" % [row])
	var seat_y: float = _trees.call("seat_height", _tree)
	var tree_at: Vector3 = _trees.call("position_of", _tree)
	# A tap DURING the ascent starts the descent the instant he is seated,
	# so the seat lasts no sampled frame: that case asserts the descent
	# phases instead (below), not a seat.
	var pending_exit: bool = _exit_phase >= 1 and _exit_phase <= 3
	if pending_exit:
		_check("no_seat_when_exit_pending", not _seen_seated, "seated at %d" % _seated_frame)
	else:
		_check("seated_reached", _seen_seated, "frame %d" % _seated_frame)
	var seat_mean_y: float = 0.0
	var seat_xz_off: float = 0.0
	for p in _seat_samples:
		seat_mean_y += p.y
		seat_xz_off = maxf(seat_xz_off, Vector2(p.x - tree_at.x, p.z - tree_at.z).length())
	if not _seat_samples.is_empty():
		seat_mean_y /= _seat_samples.size()
	if not pending_exit:
		_check("seat_height", absf(seat_mean_y - seat_y) < 0.25, "mean %.3f vs %.3f" % [seat_mean_y, seat_y])
		_check("seat_on_axis", seat_xz_off < 0.35, "max xz off %.3f" % seat_xz_off)
	_check("phases_mount_ascend_top", _phases_seen.has(1) and _phases_seen.has(2) and _phases_seen.has(3), str(_phases_seen.keys()))
	if _exit_frame > 0:
		_check("phases_descent", _phases_seen.has(5) and _phases_seen.has(6) and _phases_seen.has(7), str(_phases_seen.keys()))
		var pos: Vector3 = _keepy.global_position
		_check("ended_on_ground", not _keepy.call("is_on_tree") and absf(pos.y) < 0.01, "y %.3f on_tree %s" % [pos.y, _keepy.call("is_on_tree")])
		_check("tree_released", int(_trees.call("occupied")) == -1)
		var d: float = Vector2(pos.x - _exit_at.x, pos.z - _exit_at.z).length()
		if not _chase:
			_check("reached_exit_tap", d < 0.6, "%.2f u from %s" % [d, _exit_at])
	else:
		_check("still_seated_at_end", _keepy.call("is_seated_on_tree"))
	if _shake_frame > 0:
		var nuts: Node = _hub.call("nuts")
		var id: String = _trees.call("tree_id", _tree)
		var expected_drop: int = 2 + (_hub.shake_extras(_hub.GOLDEN_FIRST, 0.0).size() if _p2 else 0)
		_check("shake_dropped_two", int(nuts.dropped_total) == expected_drop, str(nuts.dropped_total))
		_check("shake_took_stock", WorldSave.tree_stock(id) == _stock_before - 1, "%d -> %d" % [_stock_before, WorldSave.tree_stock(id)])
		_check("nuts_settled", int(nuts.call("airborne_count")) == 0, "airborne %d" % nuts.call("airborne_count"))
		if _exit_nut:
			_check("nut_picked", int(nuts.picked_total) >= 1, str(nuts.picked_total))
			var gained: int = WorldSave.resource(&"acorn") - _acorns_before + WorldSave.resource(&"hazelnut") - _hazel_before
			_check("counter_grew", gained >= 1, "gained %d" % gained)
			_check("ground_saved", WorldSave.ground_nuts().size() == int(nuts.call("resting_count")), "%d saved vs %d resting" % [WorldSave.ground_nuts().size(), nuts.call("resting_count")])
	if _p2:
		_finish_p2()
	print("V4ClimbProbe: %d failed" % _fails.size())
	for f in _fails:
		print("  FAILED: " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)

## v5 P2: what the paced 12th shake dropped, and what became of it.
func _finish_p2() -> void:
	var nuts: Node = _hub.call("nuts")
	# The pacing itself, walked: golden at 12, 31, 50, never between;
	# ladybug on the roll, never on shake 1.
	var goldens: Array = []
	for n in range(1, 60):
		if _hub.shake_extras(n, 0.99).has(&"golden"):
			goldens.append(n)
	_check("p2.golden_pacing", goldens == [12, 31, 50], str(goldens))
	_check("p2.ladybug_roll_in", _hub.shake_extras(5, 0.1).has(&"ladybug"))
	_check("p2.ladybug_roll_out", not _hub.shake_extras(5, 0.5).has(&"ladybug"))
	_check("p2.ladybug_never_first", not _hub.shake_extras(1, 0.0).has(&"ladybug"))
	# What this run dropped: 2 nuts + ladybug + golden.
	_check("p2.dropped_four", int(nuts.dropped_total) == 4, str(nuts.dropped_total))
	_check("p2.leaves_fell", int(nuts.leaves_dropped_total) >= _hub.LEAVES_PER_SHAKE_MIN, str(nuts.leaves_dropped_total))
	_check("p2.leaves_seen_alive", _leaves_peak >= _hub.LEAVES_PER_SHAKE_MIN, str(_leaves_peak))
	_check("p2.leaves_all_gone", int(nuts.call("leaf_count")) == 0, str(nuts.call("leaf_count")))
	_check("p2.ladybug_moved", _bug_moved > 0.5, "%.2f u" % _bug_moved)
	var caught: int = WorldSave.resource(&"ladybug") - _ladybug_before
	var escaped: int = nuts.ladybugs_escaped_total
	_check("p2.ladybug_caught_or_escaped", caught + escaped >= 1, "caught %d escaped %d" % [caught, escaped])
	if _chase:
		_check("p2.ladybug_caught", caught == 1, "caught %d escaped %d" % [caught, escaped])
	else:
		_check("p2.ladybug_escaped_uncaught", escaped == 1 and caught == 0, "caught %d escaped %d" % [caught, escaped])
	_check("p2.golden_saved_or_held", WorldSave.resource(&"golden") - _golden_before == 1 or _ground_has("golden"), "held %d ground %s" % [WorldSave.resource(&"golden") - _golden_before, WorldSave.ground_nuts()])
	_check("p2.ladybug_never_saved", not _ground_has("ladybug"), str(WorldSave.ground_nuts()))
	_check("p2.hud_shows_held", _hud_visible_matches())

func _ground_has(kind: String) -> bool:
	for item in WorldSave.ground_nuts():
		if item[2] == kind:
			return true
	return false

## The HUD shows a rare counter iff the player holds one.
func _hud_visible_matches() -> bool:
	var hud: Node = _hub.get_node_or_null("WorldHud")
	if hud == null:
		return false
	for kind in [&"ladybug", &"golden"]:
		var label: Control = hud._labels.get(kind, null)
		if label == null or label.visible != (WorldSave.resource(kind) > 0):
			return false
	return true

## v5: the registry as HubTrees built it from the live scene.
func _print_list() -> void:
	var n: int = _trees.call("count")
	var zones := {"plateau": 0, "vallon": 0, "lande": 0}
	for i in n:
		var at: Vector3 = _trees.call("position_of", i)
		var zone: String = "vallon" if HubRegion.in_autumn(at) else ("lande" if HubRegion.in_moor(at) else "plateau")
		zones[zone] += 1
		var spec: Dictionary = _trees.call("climb_spec", i)
		print("TREE %d %s %s at (%.1f, %.1f) seat %.2f trunk %.2f r %.2f/%.2f lean %s pulls %s foot %s" % [i, zone, "perch" if _trees.call("is_perch", i) else "decor", at.x, at.z, _trees.call("seat_height", i), spec["trunk_h"], spec["r_base"], spec["r_top"], spec.get("lean", Vector3.ZERO), spec.get("pulls", 5), _trees.call("foot_point", i)])
	for e in _trees.call("excluded"):
		print("EXCLUDED %s at (%.1f, %.1f): %s" % [e["glb"], e["at"].x, e["at"].z, e["why"]])
	print("LIST climbable %d (perchoirs %d, decor %d) plateau %d vallon %d lande %d excluded %d" % [n, n - int(_trees.call("decor_count")), _trees.call("decor_count"), zones["plateau"], zones["vallon"], zones["lande"], (_trees.call("excluded") as Array).size()])
	# v5: the ray test, pure maths (no viewport needed). POSITIVE FIRST:
	# a ray from the camera's offset through a decor tree's crown centre
	# must name that tree; then the refusals -- the same ray 3 u aside
	# names nothing, and the occupied tree withdraws.
	if n > 5:
		var i: int = 5
		var at: Vector3 = _trees.call("position_of", i)
		var spec: Dictionary = _trees.call("climb_spec", i)
		var crown: Vector3 = at + Vector3(0.0, (spec["trunk_h"] + spec["seat"].y) * 0.5, 0.0)
		var cam: Vector3 = at + Vector3(0.0, 7.6, 8.9)
		var hit: int = _trees.call("tree_hit", Vector3(at.x, 0.0, at.z + 4.0), cam, (crown - cam).normalized(), false)
		_check("ray_crown_hits_tree", hit == i, "hit %d" % hit)
		var aside: Vector3 = crown + Vector3(3.5, 0.0, 0.0)
		var miss: int = _trees.call("tree_hit", Vector3(at.x + 3.5, 0.0, at.z + 4.0), cam, (aside - cam).normalized(), false)
		_check("ray_aside_misses", miss != i, "hit %d" % miss)
		var trunk_pt: Vector3 = at + Vector3(0.0, spec["trunk_h"] * 0.5, 0.0)
		var thit: int = _trees.call("tree_hit", Vector3(at.x, 0.0, at.z + 1.0), cam, (trunk_pt - cam).normalized(), false)
		_check("ray_trunk_hits_tree", thit == i, "hit %d" % thit)
		_trees.call("set_occupied", i)
		var withdrawn: int = _trees.call("tree_hit", Vector3(at.x, 0.0, at.z + 4.0), cam, (crown - cam).normalized(), false)
		_check("occupied_withdraws", withdrawn != i, "hit %d" % withdrawn)
		var incl: int = _trees.call("tree_hit", Vector3(at.x, 0.0, at.z + 4.0), cam, (crown - cam).normalized(), true)
		_check("occupied_answers_when_included", incl == i, "hit %d" % incl)
		_trees.call("release")
		print("V4ClimbProbe --list: %d failed" % _fails.size())
