extends Node
## CH52 -- WHAT THE NORTH CORRIDOR ACTUALLY COSTS, z = 35 to z = 63.
##
## =====================================================================
## WHAT THIS FILE IS
##
## A MEASUREMENT, in HubPerfBaseline's sense and not MountainProbe's: it
## asserts that its own INSTRUMENT works, and it publishes numbers. It
## does not gate a triangle ceiling, because CH52 was asked to FIND the
## ceiling, not to enforce one that nobody has measured yet. The only
## red lines it can produce are instrument failures -- a probe that
## cannot prove it sees what it counts has no business publishing a
## budget the next five lots would build on.
##
## It is PERMANENT for the reason HubPerfBaseline states: a reference
## measurement that cannot be re-run identically later is not a
## reference, it is an anecdote from one session. scripts/dev/* is
## excluded from the exported build, so permanence costs the game
## nothing.
##
## =====================================================================
## WHY z 35 -> 63, AND WHY x NEAR 0
##
## CH50 unioned a radius-28 disc onto the middle of the +Z edge, on the
## SAME centre as the old radius-12 north lobe: HubRegion.SKATE_LOBE_RADIUS
## on HubRegion._north_lobe = (0, 0, PLATEAU_HALF_EXTENT). Walkable ground
## therefore now runs from the square's north edge (z = 35) to the lobe rim
## (z = 63) along x = 0, and CozyScatter.COVER_MAX.y was carried to the
## same 63. Every station below is on that axis, which is both the deepest
## reach of the new ground and the line the skatepark's modules would sit
## on.
##
## CH22's worst frame stands at (-5, 35) -- the doorstep of that lobe --
## and is measured here as station 0 so the new readings have the old
## worst case beside them rather than a number quoted from a lot whose
## world no longer exists.
##
## =====================================================================
## THE INSTRUMENT CONTROL, AND WHY IT IS THE FIRST PHASE
##
## CH50 shipped a false green in this exact family: a probe run under
## --headless read 2 743 MultiMesh transforms and got the IDENTITY back
## from every one of them, concluded "0 instances", and printed that in
## GREEN. The dummy rendering driver breaks at least four things
## independently (pixels, MultiMesh transforms, viewport size, shader
## compilation) and announces none of them.
##
## So PHASE I runs first and proves, before any number below it is worth
## reading:
##   I1  the SubViewport really is VP_SIZE and really rasterised -- an
##       image with more than one distinct colour in it, which the dummy
##       driver cannot produce
##   I2  the engine's own counters are FILLED (a 0 is published as a 0)
##   I3  the probe can READ a MultiMesh transform -- the CH50 failure
##       named directly: instances counted, identity count, and the
##       spread of the origins against the node's own AABB
##   I4  the counter RESPONDS -- hiding the ground drops it, and two
##       different stations do not read the same number. An instrument
##       that cannot move cannot measure a delta.
##
## =====================================================================
## THE THREE TRIANGLE LINES, AND WHICH ONE IS THE BUDGET
##
## Per CLAUDE.md: `gpu` (engine_prims) is the OPAQUE list at the LOD the
## engine chose -- the line a device pays and the only one a ceiling may
## be gated on. `lod0 cadre` (tris_frame) is HubPerfOverlay's frustum
## replay at full detail, an upper bound. `scene` is everything, cadre or
## not, and is information only. All three are published at every station
## because "the shader is expensive", "the prop is expensive" and "the
## scene is big" are not the same sentence.
##
## AND THE COUNTER COUNTS WHAT IS SUBMITTED, NOT WHAT IS DRAWN (CH39):
## a fully back-face-culled object pays full price on this line. A delta
## proves an object is SUBMITTED; it never proves it is visible.
##
## =====================================================================
## THE NOISE FLOOR IS NOT OPTIONAL (CH40, CH41)
##
## The hub contains actors that move: the bear walks to the fire, the
## butterflies fly, the weather precipitates. Two reads of the same
## untouched station differ. Every station therefore gets REPEATS reads
## with nothing touched, and the spread of those reads is that station's
## noise floor; a group delta smaller than its own station's floor is
## printed and explicitly NOT counted as a measurement.
##
## =====================================================================
## WHAT THIS FILE CANNOT SAY
##
## This sandbox has no GPU -- llvmpipe under xvfb, not WebGL2 under
## Safari. Absolute frame times here are not device FPS and PHASE T says
## so in its own output. What carries across renderers is DIRECTION and
## GEOMETRY: the primitive and draw-call counts are the renderer's own
## bookkeeping of what was submitted, and that submission is the same on
## a phone.

const VP_SIZE: Vector2i = Vector2i(1080, 1920)
const BUDGET_S: float = 1500.0

## Stations on the lobe axis. 35 is the square's north edge (CH22's worst
## frame stands 5 u west of it); 63 is the lobe rim, the furthest north
## walkable ground exists.
const STATION_Z: Array[float] = [35.0, 39.0, 43.0, 47.0, 51.0, 55.0, 59.0, 63.0]
const STATION_X: float = 0.0
## CH22's worst frame, measured here rather than quoted.
const CH22_WORST: Vector2 = Vector2(-5.0, 35.0)
## The reference every other reading is read against: the spawn, where
## CH38/CH40/CH44 took theirs.
const SPAWN: Vector2 = Vector2(0.0, 0.0)

## Reads per station with NOTHING touched -- the noise floor.
##
## SPACED, not back to back. The first version took REPEATS reads on
## consecutive frames and got a spread of 0 at every one of ten stations,
## which reads like a perfectly stable instrument and is not: the things
## that move in this hub (the bear walking to the fire, the butterflies,
## the precipitation column) move over SECONDS, and a burst of five
## frames is blind to all of them. GAP_FRAMES puts REPEATS reads across
## roughly REPEATS * GAP_FRAMES / 60 seconds of simulated time instead.
const REPEATS: int = 8
const GAP_FRAMES: int = 12
## Frames to settle after moving the camera before the first read. Two is
## what MountainProbe PHASE E uses; a third is cheap and closes the case
## where a visibility change needs one more frame to take.
const SETTLE_FRAMES: int = 3

## PHASE T's sampling, on the model of HubPerfBaseline.
const T_WARMUP: int = 20
const T_SAMPLE: int = 60

var _fails: int = 0
var _hub: Node = null
var _world: Node3D = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _sub: SubViewport = null
var _scatter: Node = null
var _overlay: Node = null

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract: a parse error above
	# this line means no watchdog at all and a process that idles to the
	# outer timeout with no output.
	ProbeWatchdog.arm(self, "NORTH BUDGET PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_world = _hub.get_node("WorldViewport/SubViewport/World") as Node3D
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as Node3D
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport
	_scatter = _hub.get_node("WorldViewport/SubViewport/World/CozyScatter")
	_overlay = _hub.get_node_or_null("PerfOverlay")
	# The shipped overlay re-runs its whole-tree frustum replay every few
	# frames. That is CPU this probe would then be measuring in PHASE T
	# without meaning to, so its own _process is cut and snapshot() is
	# called by hand at the moments a reading is actually wanted.
	if _overlay != null:
		_overlay.set_process(false)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	# stretch = false FIRST: a stretching container IGNORES an explicit
	# size and only warns.
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	_sub.size = VP_SIZE
	_run()

func _run() -> void:
	print("=== NORTH BUDGET PROBE -- CH52, z 35 -> 63 ===")
	print("  lobe centre (%.1f, %.1f)  radius %.1f  walkable to z = %.1f"
		% [0.0, HubRegion.PLATEAU_HALF_EXTENT, HubRegion.SKATE_LOBE_RADIUS,
			HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS])
	print("  scatter cover z max %.1f   forest wall near z %.1f   scatter CELL %.1f"
		% [CozyScatter.COVER_MAX.y, CozyScatter.WALL_NEAR_Z, CozyScatter.CELL])
	print("")
	await _phase_instrument()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every number below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_stations()
	await _phase_visrange()
	await _phase_weather()
	await _phase_xsweep()
	await _phase_groups()
	await _phase_leash()
	await _phase_density()
	await _phase_frametime()
	print("=== %s -- %d red (instrument only; this probe gates no budget) ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# READING THE INSTRUMENT

func _prims() -> int:
	return RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)

func _calls() -> int:
	return RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)

func _objects() -> int:
	return RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)

## The overlay's own frustum replay -- lod0 cadre, scene, instances. Read
## from the shipped HubPerfOverlay rather than re-implemented: a second
## spelling of a frustum test is a second thing to be wrong.
func _replay() -> Dictionary:
	if _overlay != null and _overlay.has_method("snapshot"):
		return _overlay.call("snapshot")
	return {}

## Stations, then FREEZES. Moving while paused is not enough: two things
## in this hub FOLLOW Keepy in _process -- the precipitation column and
## his ground shadow (CozyScatter._process) -- so a station taken with
## the tree already paused would leave the rain box parked at the
## previous station and quietly change the frame between stations. The
## tree is therefore released to walk, given the frames to catch up, and
## only then frozen for the A/B sweep.
func _station_frozen(flat: Vector2) -> void:
	get_tree().paused = false
	await _station(flat)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	get_tree().paused = true
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame

## Parks Keepy and the camera at a ground station and lets the frame settle.
func _station(flat: Vector2) -> void:
	var p := HubSurface.ground(Vector3(flat.x, 0.0, flat.y))
	_keepy.global_position = p
	if _camera.has_method("snap_to_target"):
		_camera.call("snap_to_target")
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame

func _read() -> Dictionary:
	await get_tree().process_frame
	var rep := _replay()
	return {
		"gpu": _prims(), "calls": _calls(), "obj": _objects(),
		"lod0": int(rep.get("tris_frame", -1)),
		"scene": int(rep.get("tris_scene", -1)),
		"inst": int(rep.get("instances_frame", -1)),
		"nodes": int(rep.get("nodes_frame", -1)),
		"weather": String(rep.get("weather", "?")),
	}

# =====================================================================
# PHASE I -- THE INSTRUMENT CONTROL. Nothing below it is readable until
# this passes; _run() stops the probe if it does not.

func _phase_instrument() -> void:
	print("-- PHASE I: instrument control (CH50's false green, named) --")
	await _station(SPAWN)

	# I1 -- the viewport is real and RASTERISED. The dummy driver renders
	# a uniform surface; a real one cannot, with this hub in front of it.
	var img: Image = _sub.get_texture().get_image()
	var size := img.get_size()
	_check(size == VP_SIZE, "I1a viewport rendered %dx%d, asked %dx%d"
		% [size.x, size.y, VP_SIZE.x, VP_SIZE.y])
	var seen := {}
	for y in range(0, size.y, 37):
		for x in range(0, size.x, 37):
			seen[img.get_pixel(x, y).to_rgba32()] = true
			if seen.size() > 64:
				break
	_check(seen.size() > 1,
		"I1b the frame carries %d distinct colours on a 37px lattice (dummy driver renders 1)" % seen.size())

	# I2 -- the counters are FILLED. A zero is published as a zero.
	var r := await _read()
	_check(int(r["gpu"]) > 0, "I2a engine_prims filled: %d" % int(r["gpu"]))
	_check(int(r["calls"]) > 0, "I2b engine_calls filled: %d" % int(r["calls"]))
	_check(int(r["lod0"]) > 0, "I2c the overlay's frustum replay answers: lod0 %d, scene %d"
		% [int(r["lod0"]), int(r["scene"])])

	# I3 -- THE CH50 FAILURE, NAMED, and the wrong subject it is easy to
	# pick. The FIRST version of this check took "the biggest MultiMesh in
	# the world" and got 900 of 900 identities back -- correctly, because
	# the biggest batch is `Precipitation`, whose instances all sit at the
	# node's origin BY DESIGN and are placed by cozy_precip.gdshader from
	# INSTANCE_CUSTOM and TIME. An all-identity batch is not proof of a
	# broken driver; it is proof of nothing at all until you know whether
	# that batch was supposed to carry transforms.
	#
	# So the subject is read off the list CozyScatter PUBLISHES of the
	# ground-decor batches _flush actually built (batch_nodes()), never
	# off a guess and never off a list of what is NOT one. Those batches
	# bake their transforms in WORLD space: if they read back as identity,
	# the probe is blind, which is exactly what CH50 shipped.
	var published: Array = []
	if _scatter.has_method("batch_nodes"):
		published = _scatter.call("batch_nodes")
	_check(not published.is_empty(),
		"I3z CozyScatter publishes %d ground-decor batch names (an empty list makes I3 vacuous)" % published.size())
	var big: MultiMeshInstance3D = null
	var big_n: int = 0
	for nm in published:
		var node := _scatter.get_node_or_null(String(nm)) as MultiMeshInstance3D
		if node == null:
			continue
		var mmx: MultiMesh = node.multimesh
		if mmx != null and mmx.instance_count > big_n:
			big_n = mmx.instance_count
			big = node
	if big == null:
		_check(false, "I3 no published scatter batch resolved -- the world did not build")
		return
	var mm2: MultiMesh = big.multimesh
	_check(mm2.transform_format == MultiMesh.TRANSFORM_3D,
		"I3a '%s' transform_format is TRANSFORM_3D (0 = TRANSFORM_2D silently discards writes)" % big.name)
	var identities: int = 0
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in mm2.instance_count:
		var t: Transform3D = mm2.get_instance_transform(i)
		if t.is_equal_approx(Transform3D.IDENTITY):
			identities += 1
		lo = lo.min(t.origin)
		hi = hi.max(t.origin)
	var spread: Vector3 = hi - lo
	print("     biggest batch '%s': %d instances, %d read back as IDENTITY" % [big.name, mm2.instance_count, identities])
	print("     origins span x %.2f  y %.2f  z %.2f   node AABB size %s"
		% [spread.x, spread.y, spread.z, str((big.global_transform * big.get_aabb()).size)])
	_check(identities < mm2.instance_count,
		"I3b transforms read back as REAL: %d of %d are identity (CH50 read %d of %d)"
		% [identities, mm2.instance_count, mm2.instance_count, mm2.instance_count])
	_check(maxf(spread.x, spread.z) > 1.0,
		"I3c and they are SPREAD (widest horizontal span %.2f u, an identity batch spans 0)"
		% maxf(spread.x, spread.z))
	# Published, not asserted: the one batch in this world for which an
	# all-identity read is CORRECT. It is here so the next reader of this
	# output does not repeat the first version's mistake.
	var precip := _scatter.get_node_or_null("Precipitation") as MultiMeshInstance3D
	if precip != null and precip.multimesh != null:
		var ident: int = 0
		for i in precip.multimesh.instance_count:
			if precip.multimesh.get_instance_transform(i).is_equal_approx(Transform3D.IDENTITY):
				ident += 1
		print("     (for contrast) 'Precipitation': %d of %d identity -- CORRECT, it is placed"
			% [ident, precip.multimesh.instance_count])
		print("      by cozy_precip.gdshader from INSTANCE_CUSTOM and TIME, not by a transform.")

	# I4 -- THE COUNTER RESPONDS. Two independent proofs, because an
	# instrument that cannot move cannot measure a delta and would report
	# every group as free.
	# The subject is the WHOLE scatter and not the Ground plane: the first
	# version hid Ground and got a delta of 2, because the hub's ground is
	# a two-triangle PlaneMesh. A response of 2 is indistinguishable from
	# drift and would have let a nearly-dead counter pass.
	var on: int = (await _read())["gpu"]
	(_scatter as Node3D).visible = false
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	var off: int = (await _read())["gpu"]
	(_scatter as Node3D).visible = true
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	_check(on - off > 1000,
		"I4a hiding CozyScatter drops the counter hard: %d -> %d (delta %d, needs > 1000)" % [on, off, on - off])
	await _station(Vector2(STATION_X, STATION_Z[STATION_Z.size() - 1]))
	var north: int = (await _read())["gpu"]
	_check(north != on,
		"I4b two stations do not read the same number: spawn %d, z=63 %d" % [on, north])
	print("")

## Every VisualInstance3D under the world, once.
func _visuals() -> Array:
	var out: Array = []
	var stack: Array[Node] = [_world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is VisualInstance3D:
			out.append(n)
	return out

# =====================================================================
# PHASE S -- the stations, and each one's own noise floor.

func _phase_stations() -> void:
	print("-- PHASE S: %d reads per station, nothing touched (the noise floor) --" % REPEATS)
	print("     station        gpu min    med    max  spread |  calls  |   lod0 cadre |    scene |   inst | in region")
	var order: Array[Vector2] = [SPAWN, CH22_WORST]
	for z in STATION_Z:
		order.append(Vector2(STATION_X, z))
	for flat in order:
		var s := await _sample(flat)
		var inside := HubRegion.contains(Vector3(flat.x, 0.0, flat.y))
		print("     (%6.1f,%6.1f) %7d %6d %6d %7d | %6d  | %12d | %8d | %6d | %s"
			% [flat.x, flat.y, s["gpu_min"], s["gpu_med"], s["gpu_max"], s["gpu_spread"],
				s["calls_med"], s["lod0"], s["scene"], s["inst"], "yes" if inside else "NO"])
		_floor_by_station[_key(flat)] = int(s["gpu_spread"])
		_gpu_by_station[_key(flat)] = int(s["gpu_med"])
		_calls_by_station[_key(flat)] = int(s["calls_med"])
	print("     (spread = max - min over %d untouched reads: a delta below it is not a measurement)" % REPEATS)
	var w := await _read()
	print("     weather during this phase: %s" % String(w["weather"]))
	print("")

var _floor_by_station: Dictionary = {}
var _gpu_by_station: Dictionary = {}
var _calls_by_station: Dictionary = {}

static func _key(flat: Vector2) -> String:
	return "%.1f_%.1f" % [flat.x, flat.y]

func _sample(flat: Vector2) -> Dictionary:
	await _station(flat)
	var gpu: Array[int] = []
	var calls: Array[int] = []
	var last := {}
	for _i in REPEATS:
		last = await _read()
		gpu.append(int(last["gpu"]))
		calls.append(int(last["calls"]))
		for _k in GAP_FRAMES:
			await get_tree().process_frame
	gpu.sort()
	calls.sort()
	return {
		"gpu_min": gpu[0], "gpu_max": gpu[gpu.size() - 1], "gpu_med": gpu[gpu.size() / 2],
		"gpu_spread": gpu[gpu.size() - 1] - gpu[0],
		"calls_med": calls[calls.size() / 2],
		"lod0": int(last["lod0"]), "scene": int(last["scene"]), "inst": int(last["inst"]),
	}

# =====================================================================
# PHASE V -- WHAT visibility_range_end ACTUALLY SAVES FROM THE NORTH.
#
# CH51 SUPPOSED the 82 u leash attenuates the north stations and marked
# the point unverified. It is verified here by turning the leash OFF and
# re-reading the same frame. Two blind checks, because "turning it off
# changed nothing" and "I turned nothing off" are the same output:
#   V0a the list of leashed nodes is NOT empty
#   V0b turning them off moves the counter SOMEWHERE (if it never does,
#       the finding is that the leash is inert, not that it is free)

func _phase_visrange() -> void:
	print("-- PHASE V: what visibility_range_end saves, measured by removing it --")
	var leashed: Array[GeometryInstance3D] = []
	var saved: Array[float] = []
	for n in _visuals():
		var gi := n as GeometryInstance3D
		if gi != null and gi.visibility_range_end > 0.0:
			leashed.append(gi)
			saved.append(gi.visibility_range_end)
	_check(not leashed.is_empty(),
		"V0a %d nodes carry a visibility_range_end (an empty list would make every delta below free)" % leashed.size())
	if leashed.is_empty():
		print("")
		return
	var ranges := {}
	for gi in leashed:
		var k := "%.0f" % gi.visibility_range_end
		ranges[k] = int(ranges.get(k, 0)) + 1
	for k in ranges:
		print("     leash %5s u : %d nodes" % [k, int(ranges[k])])
	print("     station         gpu with    gpu without    saved |  floor | verdict")
	# Paused for PHASE G's reason: this is a hide-and-re-read too, six
	# frames wide, and an unpaused hub drifts inside it.
	var was_paused_v: bool = get_tree().paused
	get_tree().paused = true
	var moved: bool = false
	var order: Array[Vector2] = [SPAWN]
	for z in STATION_Z:
		order.append(Vector2(STATION_X, z))
	for flat in order:
		await _station_frozen(flat)
		var with_leash: int = (await _read())["gpu"]
		for gi in leashed:
			gi.visibility_range_end = 0.0
		for _i in SETTLE_FRAMES:
			await get_tree().process_frame
		var without: int = (await _read())["gpu"]
		for i in leashed.size():
			leashed[i].visibility_range_end = saved[i]
		for _i in SETTLE_FRAMES:
			await get_tree().process_frame
		var saved_prims: int = without - with_leash
		var fl: int = int(_floor_by_station.get(_key(flat), 0))
		if absi(saved_prims) > fl:
			moved = true
		print("     (%6.1f,%6.1f) %11d %14d %8d | %6d | %s"
			% [flat.x, flat.y, with_leash, without, saved_prims, fl,
				"real" if absi(saved_prims) > fl else "under its own noise floor"])
	get_tree().paused = was_paused_v
	_check(moved,
		"V0b removing the leash moves the counter at at least one station (if not: the leash is INERT here)")
	print("")

# =====================================================================
# PHASE G -- WHAT COSTS WHAT, by hiding and re-reading the same frame.
#
# Every group delta is gated against ITS OWN station's noise floor
# (CH41): a global gate is either free or wrong. And every group asserts
# it had something to hide (CH40): an empty group hides nothing and the
# counter drifts anyway.

func _phase_groups() -> void:
	print("-- PHASE G: what costs what, hidden and re-read, per station --")
	# ⚠️ THE WORLD IS PAUSED FOR THIS PHASE, and the first version was not.
	# Unpaused, this phase reported +1 920 for `world/Ground` -- a
	# two-triangle PlaneMesh -- and the same ~1 918 for Mountain, Critters,
	# rock, bush and mushroom at the same station, while the SAME groups
	# read 0 or 2 at the station before. That is not what those groups
	# cost; it is the hub moving underneath a hide-and-re-read that takes
	# six frames per group. CH37 wrote this down for captures ("a capture
	# gate gates nothing in a world that contains a walking actor") and it
	# is the same defect one layer up.
	#
	# Pausing freezes the walkers and the weather. It does NOT freeze a
	# shader's TIME (CH48), which is fine here: TIME moves pixels, not
	# primitive counts.
	var was_paused: bool = get_tree().paused
	get_tree().paused = true
	var groups := _groups()
	var empty: Array[String] = []
	for g in groups.keys():
		if (groups[g] as Array).is_empty():
			empty.append(g)
	_check(empty.is_empty(),
		"G0 every group has something to hide (empty: %s)" % ("none" if empty.is_empty() else ", ".join(empty)))
	var order: Array[Vector2] = [SPAWN, Vector2(STATION_X, 35.0), Vector2(STATION_X, 51.0), Vector2(STATION_X, 63.0)]
	var control_ever_moved: bool = false
	for flat in order:
		await _station_frozen(flat)
		var base := await _read()
		# THE CONTROL. Same protocol, nothing hidden, run three times and
		# interleaved with the real groups. Its worst |delta| is this
		# station's floor for THIS protocol -- not PHASE S's floor, which
		# was measured under a different temporal profile. Without it,
		# "the group costs something" passes for free (CH40).
		var keys: Array = groups.keys()
		var slots := {0: true, keys.size() / 2: true, keys.size(): true}
		var control_worst: int = 0
		var rows: Array = []
		for i in range(keys.size() + 1):
			if slots.has(i):
				var c := await _ab([], base)
				control_worst = maxi(control_worst, absi(int(c["d"])))
			if i >= keys.size():
				break
			var g: String = keys[i]
			var r := await _ab(groups[g], base)
			r["g"] = g
			r["n"] = (groups[g] as Array).size()
			rows.append(r)
		if control_worst > 0:
			control_ever_moved = true
		print("     -- station (%.1f, %.1f)  base gpu %d  calls %d  CONTROL worst |delta| %d --"
			% [flat.x, flat.y, int(base["gpu"]), int(base["calls"]), control_worst])
		rows.sort_custom(func(a, b): return int(a["d"]) > int(b["d"]))
		for r in rows:
			print("        %-22s %4d nodes  gpu %+7d  calls %+5d  %s"
				% [r["g"], r["n"], r["d"], r["c"],
					"" if absi(int(r["d"])) > control_worst else "(<= control: not a measurement)"])
	# Published, not asserted: a control that never moves is what a frozen
	# world SHOULD give. It is stated so a future reader can tell "the
	# protocol is clean" from "the control was never wired".
	print("     (control moved at least once: %s -- pause was %s before this phase)"
		% ["yes" if control_ever_moved else "no, the paused world is fully still",
			"on" if was_paused else "off"])
	get_tree().paused = was_paused
	print("")

## One A/B: read on, hide `nodes`, read off, restore. An EMPTY `nodes` is
## the control -- the identical protocol with nothing turned off.
func _ab(nodes: Array, _base: Dictionary) -> Dictionary:
	var on := await _read()
	var restore: Array[bool] = []
	for n in nodes:
		restore.append((n as VisualInstance3D).visible)
		(n as VisualInstance3D).visible = false
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	var off := await _read()
	for i in nodes.size():
		(nodes[i] as VisualInstance3D).visible = restore[i]
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	return {"d": int(on["gpu"]) - int(off["gpu"]), "c": int(on["calls"]) - int(off["calls"])}

## The world's visuals, bucketed. CozyScatter is split by FAMILY, read off
## the batch node names the scatter itself publishes -- never off a list
## of what is NOT the subject, which is wrong at the first forgotten name.
func _groups() -> Dictionary:
	var out := {}
	for n in _visuals():
		var vi := n as VisualInstance3D
		if vi == null:
			continue
		var g := _bucket(vi)
		if not out.has(g):
			out[g] = []
		(out[g] as Array).append(vi)
	return out

func _bucket(vi: VisualInstance3D) -> String:
	var under_scatter: bool = false
	var top := ""
	var n: Node = vi
	while n != null and n != _world:
		var p: Node = n.get_parent()
		if p == _world:
			top = n.name
		if p == _scatter or n == _scatter:
			under_scatter = true
		n = p
	if not under_scatter:
		return "world/" + (top if top != "" else "?")
	# A scatter batch is named family_mesh_cell (CozyScatter._flush names
	# the node after the batch key with | replaced by _). The family is
	# the leading token, and it is what the scatter itself keyed on.
	var nm := String(vi.name)
	if nm.begins_with("wall_near"):
		return "scatter/wall_near"
	if nm.begins_with("wall_far"):
		return "scatter/wall_far"
	for fam in ["hedge", "grass", "flower", "leaf", "pebble", "bush", "rock", "mushroom",
			"autumn_tree", "olive", "cypress", "palm", "fern", "leafpile", "bigshroom",
			"log", "pumpkin", "lantern", "palerock", "bed"]:
		if nm.begins_with(fam):
			return "scatter/" + fam
	return "scatter/other"

# =====================================================================
# PHASE W -- DOES THE WEATHER MOVE THIS LINE AT ALL?
#
# CH51 asked for four weathers. Before spending four full sweeps on it,
# the cheap question is whether the `gpu` line can move with weather at
# all, and the answer is in how the hub is built rather than in a guess:
# `Precipitation` is 900 quads that are ALWAYS submitted -- nothing sets
# its `visible` from the weather; cozy_precip.gdshader gates the LOOK
# from `rain` and `snow` uniforms. Weather in this hub is a shader
# parameter, not a geometry switch.
#
# ⚠️ WHAT THIS PHASE CANNOT SAY: the four critters DO listen to
# weather_changed and take shelter, which is a MOVE, and a move can
# carry a body in or out of the frustum. Thirty frames is nowhere near
# long enough for that walk. This phase therefore answers "the submitted
# geometry is weather-independent", never "a critter can never re-enter
# the frame".

const W_SETTLE: int = 30

func _phase_weather() -> void:
	print("-- PHASE W: does the weather move the gpu line? --")
	var weather: Node = _world.get_node_or_null("CozyWeather")
	if weather == null or not weather.has_method("force"):
		_check(false, "W0 no CozyWeather to force -- this phase measured nothing")
		print("")
		return
	var precip := _scatter.get_node_or_null("Precipitation") as MultiMeshInstance3D
	print("     'Precipitation' visible = %s, %d instances -- submitted whatever the sky does"
		% ["?" if precip == null else str(precip.visible),
			0 if precip == null or precip.multimesh == null else precip.multimesh.instance_count])
	var moved: bool = false
	for flat in [Vector2(0.0, 0.0), Vector2(-10.0, 51.0), Vector2(STATION_X, 63.0)]:
		await _station(flat)
		var line := "     (%6.1f,%6.1f) :" % [flat.x, flat.y]
		var lo: int = 1 << 30
		var hi: int = 0
		for k in [0, 1, 2, 3]:
			weather.call("force", k)
			for _i in W_SETTLE:
				await get_tree().process_frame
			var r := await _read()
			lo = mini(lo, int(r["gpu"]))
			hi = maxi(hi, int(r["gpu"]))
			line += "  %-5s %6d" % [String(r["weather"]), int(r["gpu"])]
		# The SPREAD, not a boolean. The first version flagged "it moves"
		# on a FOUR-primitive difference out of 94 710 -- true, and
		# meaningless. What the next lot needs to know is the size.
		line += "   spread %d" % (hi - lo)
		if hi - lo > 500:
			moved = true
		print(line)
	if weather.has_method("force_auto"):
		weather.call("force_auto")
	for _i in W_SETTLE:
		await get_tree().process_frame
	# Published either way, and NOT asserted in one direction: "it never
	# moves" is the expected answer here and would be the finding, while
	# "it moves" would mean the other three weathers need their own sweep.
	print("     verdict: the gpu line %s with the weather (threshold: 500 primitives)"
		% ["MOVES -- the other weathers need their own sweep" if moved else "does NOT meaningfully move"])
	_check(true, "W1 four weathers forced and read at three stations (result above, not gated)")
	print("")

# =====================================================================
# PHASE X -- THE AXIS IS NOT THE WORST CASE, AND PHASE S CANNOT SEE THAT.
#
# PHASE S sweeps z along x = 0 because that is the lobe's axis and the
# line a skatepark would sit on. It then measures (-5, 35) -- CH22's
# worst frame -- at 94 601 against 87 477 for (0, 35): SEVEN THOUSAND
# primitives of difference at the same z, purely from x. A budget set
# against a sweep that only ever looked down the axis would be set
# against a frame that is not the worst one, which is the same defect
# as gating a ceiling on the wrong one of the three triangle lines.
#
# So x is swept too, at the three z where the lobe is wide enough for x
# to have anywhere to go. Points outside HubRegion are skipped and said
# to be skipped: a station a player cannot stand on is not a frame.

const X_SWEEP_Z: Array[float] = [35.0, 43.0, 51.0]
const X_SWEEP: Array[float] = [-25.0, -20.0, -15.0, -10.0, -5.0, 0.0, 5.0, 10.0, 15.0, 20.0, 25.0]

## Every VisualInstance3D that MOVED over `frames`, found by measuring
## rather than by naming. CH44 already established that half the hub's
## node paths do not exist (the bear and the badger are `@Node3D@228` and
## `@Node3D@230`, names derived from an instantiation counter), so a list
## of movers written by hand is wrong at the first rename.
func _movers(frames: int) -> Array:
	var subjects: Array = _visuals()
	var before: Array[Vector3] = []
	for n in subjects:
		before.append((n as Node3D).global_position)
	for _i in frames:
		await get_tree().process_frame
	var out: Array = []
	for i in subjects.size():
		if (subjects[i] as Node3D).global_position.distance_to(before[i]) > 0.01:
			out.append(subjects[i])
	return out

func _phase_xsweep() -> void:
	print("-- PHASE X: the same z, swept in x (the axis is not the worst frame) --")
	# ⚠️ THE WALKING ACTORS ARE HIDDEN FOR THIS SWEEP, and the first two
	# versions of this phase did not do that -- so they DISAGREED with
	# each other. Run 5 named (-10, 51) the worst frame at 101 394; run 6
	# named (-5, 51) at 99 030 and read (-10, 51) at 95 548. Nothing about
	# the hub changed between them: the bear had simply walked, and it is
	# 5 846 primitives that enter and leave the frustum on ITS clock, not
	# on the station's.
	#
	# A sweep that asks "which x is the worst" must vary only x. The
	# actors' cost is a real cost and it is not dropped -- it is measured
	# SEPARATELY (PHASE G reads the bear at +5 846 from every north
	# station) and stated here as a term to add back. Mixing the two into
	# one number gives a ranking that does not survive a re-run, which is
	# exactly what happened.
	var movers: Array = await _movers(45)
	_check(not movers.is_empty(),
		"X0a %d visual nodes MOVED over 45 frames (found by measuring, not by naming)" % movers.size())
	var mover_names: PackedStringArray = []
	var restore_m: Array[bool] = []
	for n in movers:
		mover_names.append("%s(%s)" % [String((n as Node).name), String((n as Node).get_parent().name)])
		restore_m.append((n as VisualInstance3D).visible)
		(n as VisualInstance3D).visible = false
	print("     hidden for this sweep: %s" % ", ".join(mover_names))
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	var worst_gpu: int = 0
	var worst_at := Vector2.ZERO
	var worst_calls: int = 0
	var worst_calls_at := Vector2.ZERO
	for z in X_SWEEP_Z:
		var line := "     z %5.1f :" % z
		for x in X_SWEEP:
			var flat := Vector2(x, z)
			if not HubRegion.contains(Vector3(x, 0.0, z)):
				line += "   x%+5.0f    --  " % x
				continue
			await _station(flat)
			var r := await _read()
			if int(r["gpu"]) > worst_gpu:
				worst_gpu = int(r["gpu"])
				worst_at = flat
			if int(r["calls"]) > worst_calls:
				worst_calls = int(r["calls"])
				worst_calls_at = flat
			line += "   x%+5.0f %6d" % [x, int(r["gpu"])]
		print(line)
	for i in movers.size():
		(movers[i] as VisualInstance3D).visible = restore_m[i]
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	print("     worst gpu   in this sweep : %d at (%.1f, %.1f)  -- WITHOUT the movers above"
		% [worst_gpu, worst_at.x, worst_at.y])
	print("     worst calls in this sweep : %d at (%.1f, %.1f)" % [worst_calls, worst_calls_at.x, worst_calls_at.y])
	print("     add back PHASE G's mover terms for a station where they are in frame.")
	_check(worst_gpu > 0, "X0b the sweep read something at all (a 0 would mean every point was skipped)")
	print("")

# =====================================================================
# PHASE L -- THE RECLAIM CURVE OF THE LEASH.
#
# PHASE V answers "is the leash doing anything" (yes, ~97 000 primitives
# at z = 63). It does NOT answer the question a lot that is over budget
# actually asks, which is "what would a SHORTER leash buy". That is a
# curve, not a yes/no, and it is swept here rather than reasoned about
# from the fog equation -- CLAUDE.md's own rule for the 82 u figure is
# that the right cut is the one the haze has already eaten, and where
# that lands is a measurement.
#
# The subject is the 82 u cohort only. The 95 u families (autumn, and
# the cove's palms) are deliberately longer-leashed because their band
# is part of a frame BY DESIGN; shortening those is a look decision, not
# a budget one, and this phase does not pretend otherwise.

const LEASH_SWEEP: Array[float] = [82.0, 72.0, 62.0, 52.0, 45.0, 40.0, 35.0, 30.0]

func _phase_leash() -> void:
	print("-- PHASE L: what a SHORTER leash would buy (82 u cohort only) --")
	var cohort: Array[GeometryInstance3D] = []
	for n in _visuals():
		var gi := n as GeometryInstance3D
		if gi != null and is_equal_approx(gi.visibility_range_end, 82.0):
			cohort.append(gi)
	_check(not cohort.is_empty(), "L0 the 82 u cohort has %d nodes" % cohort.size())
	if cohort.is_empty():
		print("")
		return
	var moved: bool = false
	for flat in [Vector2(STATION_X, 51.0), Vector2(STATION_X, 63.0)]:
		await _station_frozen(flat)
		print("     station (%.1f, %.1f):" % [flat.x, flat.y])
		var at_82: int = 0
		for leash in LEASH_SWEEP:
			for gi in cohort:
				gi.visibility_range_end = leash
			for _i in SETTLE_FRAMES:
				await get_tree().process_frame
			var r := await _read()
			if leash == 82.0:
				at_82 = int(r["gpu"])
			if int(r["gpu"]) != at_82:
				moved = true
			print("        leash %5.1f u : gpu %6d  calls %4d   reclaimed vs 82 u : %+7d"
				% [leash, int(r["gpu"]), int(r["calls"]), at_82 - int(r["gpu"])])
		for gi in cohort:
			gi.visibility_range_end = 82.0
		for _i in SETTLE_FRAMES:
			await get_tree().process_frame
	get_tree().paused = false
	_check(moved, "L1 the sweep MOVES the counter (a flat curve would mean the leash is not the lever)")
	print("")

# =====================================================================
# PHASE D -- THE RECLAIM CURVE OF CARPET DENSITY.
#
# The other lever, and the one CH50 pulled without measuring: the north
# lobe was seeded at the plateau's own GRASS_PER_U2. Density cannot be
# changed at runtime, but `visible_instance_count` on a MultiMesh is
# exactly a thinner carpet as far as the renderer is concerned, so the
# curve can be swept on the shipped batches without rebuilding anything.
#
# ⚠️ AND IT CROSS-CHECKS PHASE G BY A DIFFERENT MECHANISM: keep = 0.0
# must reclaim what hiding the same batches reclaimed in PHASE G. Two
# independent mechanisms agreeing is worth more than either alone; if
# they disagree, one of them is not measuring what it says.

const KEEP_SWEEP: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]

func _phase_density() -> void:
	print("-- PHASE D: what a THINNER grass carpet would buy --")
	var grass: Array[MultiMeshInstance3D] = []
	var published: Array = []
	if _scatter.has_method("batch_nodes"):
		published = _scatter.call("batch_nodes")
	for nm in published:
		if not String(nm).begins_with("grass"):
			continue
		var node := _scatter.get_node_or_null(String(nm)) as MultiMeshInstance3D
		if node != null and node.multimesh != null:
			grass.append(node)
	_check(not grass.is_empty(), "D0 %d grass batches found in CozyScatter's published list" % grass.size())
	if grass.is_empty():
		print("")
		return
	var total: int = 0
	for g in grass:
		total += g.multimesh.instance_count
	print("     %d grass batches, %d instances in total" % [grass.size(), total])
	var zero_delta: int = 0
	for flat in [Vector2(STATION_X, 51.0), Vector2(STATION_X, 63.0)]:
		await _station_frozen(flat)
		print("     station (%.1f, %.1f):" % [flat.x, flat.y])
		var at_full: int = 0
		for keep in KEEP_SWEEP:
			for g in grass:
				g.multimesh.visible_instance_count = -1 if keep >= 1.0 \
					else int(floor(float(g.multimesh.instance_count) * keep))
			for _i in SETTLE_FRAMES:
				await get_tree().process_frame
			var r := await _read()
			if keep >= 1.0:
				at_full = int(r["gpu"])
			if keep <= 0.0 and flat.y == 63.0:
				zero_delta = at_full - int(r["gpu"])
			print("        keep %4.0f %% : gpu %6d  calls %4d   reclaimed vs full : %+7d"
				% [keep * 100.0, int(r["gpu"]), int(r["calls"]), at_full - int(r["gpu"])])
		for g in grass:
			g.multimesh.visible_instance_count = -1
		for _i in SETTLE_FRAMES:
			await get_tree().process_frame
	get_tree().paused = false
	# The cross-check. PHASE G hid the same batches through `visible`;
	# this phase emptied them through `visible_instance_count`. Two
	# mechanisms, one number -- and a disagreement would say one of the
	# two is not measuring the carpet.
	_check(zero_delta > 0,
		"D1 keep = 0 %% reclaims %d at z = 63 -- compare PHASE G's scatter/grass line (same batches, other mechanism)"
		% zero_delta)
	print("")

# =====================================================================
# PHASE T -- FRAME TIME, and the warning that goes with it.
#
# Real wall-clock between process_frame yields, HubPerfBaseline's method
# and for its reasons: --fixed-fps's reported delta is a constant, not a
# measurement. llvmpipe is not WebGL2 and these milliseconds are NOT
# device FPS. What carries is the RATIO between stations on one renderer.

func _phase_frametime() -> void:
	print("-- PHASE T: wall-clock frame time (llvmpipe, NOT device FPS -- direction only) --")
	print("     station          mean ms   worst ms   vs spawn")
	var spawn_mean: float = 0.0
	var order: Array[Vector2] = [SPAWN, CH22_WORST, Vector2(STATION_X, 35.0),
		Vector2(STATION_X, 51.0), Vector2(STATION_X, 63.0)]
	for flat in order:
		await _station(flat)
		for _i in T_WARMUP:
			await get_tree().process_frame
		var sum_us: int = 0
		var worst_us: int = 0
		var last := Time.get_ticks_usec()
		for _i in T_SAMPLE:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			var d: int = now - last
			last = now
			sum_us += d
			worst_us = maxi(worst_us, d)
		var mean_ms: float = float(sum_us) / float(T_SAMPLE) / 1000.0
		if flat == SPAWN:
			spawn_mean = mean_ms
		print("     (%6.1f,%6.1f) %11.2f %10.2f   %+6.1f %%"
			% [flat.x, flat.y, mean_ms, worst_us / 1000.0,
				0.0 if spawn_mean <= 0.0 else (mean_ms / spawn_mean - 1.0) * 100.0])
	print("")
