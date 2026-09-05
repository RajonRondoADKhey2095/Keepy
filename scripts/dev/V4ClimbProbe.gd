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
##
## Exit 0 = every assertion held.

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

func _ready() -> void:
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
	# A known save: this runs in the sandbox's own user://, never a device.
	WorldSave.reset()
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
	_trees = _hub.get_node("WorldViewport/SubViewport/World/Trees")
	_keepy.global_position = _at
	var cam: Node = _hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	cam.call("snap_to_target")
	get_tree().create_timer(240.0).timeout.connect(func(): print("V4ClimbProbe: TIMEOUT"); get_tree().quit(9))

func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_fails.append("%s %s" % [name, detail])
	print("  [%s] %s %s" % ["ok" if ok else "FAIL", name, detail])

func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 5:
		var at: Vector3 = _trees.call("position_of", _tree)
		print("TREE_TAP tree %d at %s foot %s" % [_tree, at, _trees.call("foot_point", _tree)])
		_hub.get_node("TapInput").emit_signal("tapped_tree", at)
	if _shake_frame > 0 and _frames == _shake_frame:
		_stock_before = WorldSave.tree_stock(_trees.call("tree_id", _tree))
		_acorns_before = WorldSave.resource(&"acorn")
		_hazel_before = WorldSave.resource(&"hazelnut")
		print("SHAKE_TAP at frame %d (phase %d, stock %d)" % [_frames, _keepy.call("tree_phase"), _stock_before])
		_hub.get_node("TapInput").emit_signal("tapped_ground", _trees.call("position_of", _tree))
	if _exit_frame > 0 and _frames == _exit_frame:
		var target: Vector3 = _exit_at
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
	var seat_y: float = _trees.SEAT_Y
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
		_check("reached_exit_tap", d < 0.6, "%.2f u from %s" % [d, _exit_at])
	else:
		_check("still_seated_at_end", _keepy.call("is_seated_on_tree"))
	if _shake_frame > 0:
		var nuts: Node = _hub.call("nuts")
		var id: String = _trees.call("tree_id", _tree)
		_check("shake_dropped_two", int(nuts.dropped_total) == 2, str(nuts.dropped_total))
		_check("shake_took_stock", WorldSave.tree_stock(id) == _stock_before - 1, "%d -> %d" % [_stock_before, WorldSave.tree_stock(id)])
		_check("nuts_settled", int(nuts.call("airborne_count")) == 0, "airborne %d" % nuts.call("airborne_count"))
		if _exit_nut:
			_check("nut_picked", int(nuts.picked_total) >= 1, str(nuts.picked_total))
			var gained: int = WorldSave.resource(&"acorn") - _acorns_before + WorldSave.resource(&"hazelnut") - _hazel_before
			_check("counter_grew", gained >= 1, "gained %d" % gained)
			_check("ground_saved", WorldSave.ground_nuts().size() == int(nuts.call("resting_count")), "%d saved vs %d resting" % [WorldSave.ground_nuts().size(), nuts.call("resting_count")])
	print("V4ClimbProbe: %d failed" % _fails.size())
	for f in _fails:
		print("  FAILED: " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)
