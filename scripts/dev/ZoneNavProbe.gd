extends Node
class_name ZoneNavProbe
## CH77 -- the zones 1 and 2 navigability contract, gated.
##
## DRIVER: xvfb-run --rendering-driver opengl3. NOT headless. It reads
## MultiMesh instance transforms for its instrument control, and CH50
## measured that a headless read returns 2743/2743 of them as identity
## and lets an absence assertion pass in green.
##
## =====================================================================
## WHAT THIS GATES, AND WHY EACH HALF IS NEEDED
##
## CH77 widened HubRegion's zone 1 and zone 2 rectangles by 10 u per side
## on the six sides that stay inside this lot's perimeter. Three sides are
## PINNED because +10 there would annex a neighbouring zone's band, and a
## widening lot that does not gate its own pins is a lot whose next
## revision quietly unpins one.
##
## So this probe has two halves and BOTH are load-bearing:
##
##   the POSITIVE -- the new ground is reachable BY A TAP, walked by the
##   real hopper, from a real screen coordinate. CH58's lesson: a probe
##   that drives a prop through its API measures the function, not the
##   interaction, and the two never fail together. Everything here enters
##   through HubTapInput._handle_point.
##
##   the REFUSALS -- the three pinned edges and the two holes still refuse.
##   An assertion of ABSENCE passes gratis against a mechanism that was
##   never wired (CLAUDE.md's blind check), so the POSITIVE runs FIRST and
##   PHASE R asserts its refusals against ground the positive half has
##   already proved is reachable a few units away.
##
## THE NECK. The zone 1 <-> 2 crossing was 12 u of 120 painted; the two
## rectangles now overlap over z[-88,-76], so a walk between the hollow
## and the moor no longer has to find the road. PHASE N walks it OFF the
## road and asserts the hopper never visits the gate.

const BUDGET_S: float = 600.0
const VP_SIZE: Vector2i = Vector2i(540, 960)
## How far inside an edge a "this is reachable now" target sits. Bigger
## than KeepyHopper.ARRIVE_EPSILON (0.45) so an arrival that lands short
## is still unambiguously past the OLD limit, which is what is asserted.
const EDGE_INSET: float = 1.5
## The old limits CH77 moved. A literal here is deliberate: it is the
## number this lot claims to have changed, so it must NOT be read back out
## of the constant that changed -- that would be a tautology.
const OLD_AUTUMN_X: float = 33.0
const OLD_MOOR_X_WEST: float = -38.0
const OLD_AUTUMN_Z_SOUTH: float = -78.0
const OLD_MOOR_Z_NORTH: float = -86.0
const OLD_CORRIDOR_X_EAST: float = -23.0

var _hub: Node = null
var _world: Node3D = null
var _keepy: KeepyHopper = null
var _camera: Camera3D = null
var _sub: SubViewport = null
var _tap: HubTapInput = null
var _fails: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "ZONE NAV PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_world = _hub.get_node("WorldViewport/SubViewport/World") as Node3D
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as KeepyHopper
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport
	_tap = _hub.get_node("TapInput") as HubTapInput
	var overlay: Node = _hub.get_node_or_null("PerfOverlay")
	if overlay != null:
		overlay.set_process(false)

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	_sub.size = VP_SIZE
	box.size = Vector2(VP_SIZE)
	_run()

func _run() -> void:
	print("=== ZONE NAV PROBE -- CH77 ===")
	var weather := _world.get_node_or_null("CozyWeather") as CozyWeather
	if weather != null:
		weather.force(CozyWeather.Kind.SUN)
	await _frames(30)
	_phase_instrument()
	await _phase_reach()
	await _phase_neck()
	_phase_refusals()
	print("=== ZONE NAV PROBE: %d assertions red ===" % _fails)
	await _frames(2)
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _to_screen(world: Vector3) -> Vector2:
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	var rect := container.get_global_rect()
	var local: Vector2 = _camera.unproject_position(world)
	local.x *= rect.size.x / float(_sub.size.x)
	local.y *= rect.size.y / float(_sub.size.y)
	return local + rect.position

func _settle(cap: int = 1400) -> int:
	var frames: int = 0
	await get_tree().process_frame
	frames += 1
	while _keepy.is_hopping() and frames < cap:
		await get_tree().process_frame
		frames += 1
	return frames

func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z)

## Park Keepy and WAIT FOR THE CAMERA, which is not the same thing.
##
## HubCamera lerps toward the point it follows with a 0.2 s time constant,
## so six frames after a teleport it is still 61% of the way back at the
## PREVIOUS station -- and every unproject taken then is a projection
## through a camera that is not where the probe thinks it is. Measured:
## that alone made three rows of PHASE W report new ground as untappable.
## Waiting on the ARRIVAL rather than on a frame count means a later
## change to the smoothing cannot quietly reintroduce it.
func _park(at: Vector3) -> bool:
	_keepy.global_position = HubSurface.ground(at)
	var want := HubSurface.ground(at) + HubCamera.OFFSET
	for i in 180:
		await get_tree().process_frame
		if _camera.global_position.distance_to(want) < 0.05:
			return true
	return _camera.global_position.distance_to(want) < 0.05

## Is this world point inside the container, i.e. tappable at all.
## HubTapInput._handle_point drops a point outside its own rect, and a
## dropped tap reads EXACTLY like a refused destination.
func _tappable(world: Vector3) -> bool:
	if _camera.is_position_behind(world):
		return false
	var container := _hub.get_node("WorldViewport") as SubViewportContainer
	return container.get_global_rect().has_point(_to_screen(world))

## Walk toward `target` the way a player must, and the reason this is not
## one tap is MEASURED rather than assumed: HubCamera never yaws and
## HubWorld.tscn frames 45 deg HORIZONTAL on a KEEP_WIDTH viewport, so the
## frame is about 3.7 u wide at Keepy's own z. A point 15 u to his SIDE is
## off screen, its tap is dropped by _handle_point's rect guard, and he
## does not move. So each stage taps the furthest point of the segment
## that is still tappable, exactly as a thumb would.
##
## Returns the number of stages spent; 0 means not one tap was accepted.
func _walk_toward(target: Vector3, stages: int = 8) -> int:
	var used := 0
	for k in stages:
		var here := _flat(_keepy.global_position)
		if here.distance_to(_flat(target)) < 1.0:
			break
		# Furthest tappable point on the segment, by bisection.
		var lo := 0.0
		var hi := 1.0
		if _tappable(HubSurface.ground(_flat(target))):
			lo = 1.0
		else:
			for i in 18:
				var mid := 0.5 * (lo + hi)
				if _tappable(HubSurface.ground(here.lerp(_flat(target), mid))):
					lo = mid
				else:
					hi = mid
		if lo <= 0.001:
			break
		var aim := here.lerp(_flat(target), lo)
		_tap._handle_point(_to_screen(HubSurface.ground(aim)))
		var before := _flat(_keepy.global_position)
		await _settle()
		used += 1
		if _flat(_keepy.global_position).distance_to(before) < 0.05:
			break
	return used

# =====================================================================
## The instrument, before anything it measures. A rect of zero size makes
## every unproject-driven tap leave the container and be dropped by
## _handle_point's own guard, and every check below would then pass by
## never running.
func _phase_instrument() -> void:
	print("-- PHASE I: instrument --")
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	var rect := box.get_global_rect()
	_check(rect.size.x > 1.0 and rect.size.y > 1.0,
		"container rect is not degenerate (%.0f x %.0f)" % [rect.size.x, rect.size.y])
	var total: int = 0
	var moved: int = 0
	for node in _all(_world, "MultiMeshInstance3D"):
		var mmi := node as MultiMeshInstance3D
		if mmi.multimesh == null:
			continue
		for i in mmi.multimesh.instance_count:
			total += 1
			if not mmi.multimesh.get_instance_transform(i).is_equal_approx(Transform3D.IDENTITY):
				moved += 1
	# NOT "all of them": the Precipitation batch legitimately parks its 900
	# drops at identity until the weather drives them, measured. What a
	# dummy driver does is return identity for EVERY instance, which this
	# still catches.
	_check(total > 0 and float(moved) / float(maxi(total, 1)) > 0.5,
		"MultiMesh transforms are real: %d/%d non-identity" % [moved, total])

func _all(root: Node, cls: String) -> Array[Node]:
	var out: Array[Node] = []
	if root.is_class(cls):
		out.append(root)
	for child in root.get_children():
		out.append_array(_all(child, cls))
	return out

# =====================================================================
## THE POSITIVE HALF. Each row parks Keepy on ground that was walkable
## BEFORE CH77, taps a point on ground that was NOT, and requires that he
## actually gets there -- past the old limit, by the real channel.
func _phase_reach() -> void:
	print("-- PHASE W: the new ground is reachable BY A TAP --")
	# ⚠️ EVERY TARGET IS AHEAD OF ITS START (lower z), and that is not
	# cosmetic. HubCamera never yaws and HubWorld.tscn frames 45 deg
	# HORIZONTAL on a KEEP_WIDTH viewport, so the frame is ~3.7 u wide at
	# Keepy's own z and widens only with distance ahead. A target directly
	# BESIDE him is off screen, its tap is dropped by _handle_point's rect
	# guard, and he does not move -- measured, and it is the reason an
	# earlier spelling of this phase reported new ground as unreachable
	# when what it had actually measured was an untappable screen point.
	# A player reaches sideways ground by aiming forward-and-across, which
	# is what _walk_toward stages.
	var rows: Array[Dictionary] = [
		{
			"what": "zone 1 EAST past x %.0f" % OLD_AUTUMN_X,
			"from": Vector3(28.0, 0.0, -46.0),
			"to": Vector3(HubRegion.AUTUMN_MAX.x - EDGE_INSET, 0.0, -70.0),
			"axis": "x", "past": OLD_AUTUMN_X, "sign": 1.0,
		},
		{
			"what": "zone 1 WEST past x %.0f" % -OLD_AUTUMN_X,
			"from": Vector3(-28.0, 0.0, -46.0),
			"to": Vector3(HubRegion.AUTUMN_MIN.x + EDGE_INSET, 0.0, -70.0),
			"axis": "x", "past": -OLD_AUTUMN_X, "sign": -1.0,
		},
		{
			"what": "zone 1 SOUTH past z %.0f" % OLD_AUTUMN_Z_SOUTH,
			"from": Vector3(-30.0, 0.0, -70.0),
			"to": Vector3(-30.0, 0.0, HubRegion.AUTUMN_MIN.y + EDGE_INSET),
			"axis": "z", "past": OLD_AUTUMN_Z_SOUTH, "sign": -1.0,
		},
		{
			"what": "zone 2 NORTH past z %.0f" % OLD_MOOR_Z_NORTH,
			"from": Vector3(-30.0, 0.0, -72.0),
			"to": Vector3(-30.0, 0.0, HubRegion.MOOR_MAX.y - EDGE_INSET),
			"axis": "z", "past": OLD_MOOR_Z_NORTH, "sign": 1.0,
		},
		{
			"what": "zone 2 WEST past x %.0f" % OLD_MOOR_X_WEST,
			"from": Vector3(-33.0, 0.0, -90.0),
			"to": Vector3(HubRegion.MOOR_MIN.x + EDGE_INSET, 0.0, -112.0),
			"axis": "x", "past": OLD_MOOR_X_WEST, "sign": -1.0,
		},
		{
			"what": "zone 1 corridor mouth past x %.0f" % OLD_CORRIDOR_X_EAST,
			"from": Vector3(-30.0, 0.0, -28.0),
			"to": Vector3(HubRegion.CORRIDOR_MAX.x - EDGE_INSET, 0.0, -40.0),
			"axis": "x", "past": OLD_CORRIDOR_X_EAST, "sign": 1.0,
		},
	]
	for row in rows:
		var start: Vector3 = row["from"]
		var parked: bool = await _park(start)
		_check(parked, "%s: the camera settled over the start" % row["what"])
		var target: Vector3 = row["to"]
		# The point has to be ON SCREEN or the tap is dropped by
		# _handle_point's own rect guard, and a dropped tap looks exactly
		# like a refused destination. Gate it rather than hope.
		var stages: int = await _walk_toward(target)
		_check(stages > 0, "%s: at least one tap was accepted (%d stages)" % [row["what"], stages])
		var landed := _flat(_keepy.global_position)
		var reached: float = landed.x if String(row["axis"]) == "x" else landed.z
		var past: float = float(row["past"])
		var sign: float = float(row["sign"])
		var ok: bool = (reached - past) * sign > 0.0
		_check(ok, "%s: landed %s = %.3f, %.3f u past the old limit"
			% [row["what"], row["axis"], reached, (reached - past) * sign])
		_check(HubRegion.contains(landed), "%s: the landing is inside the region" % row["what"])

# =====================================================================
## THE NECK. Before CH77 a walk from the hollow to the moor anywhere but
## x in [6, 18] was routed to MOOR_GATE (12, -82). The rectangles now
## overlap, so a walk that starts and ends far from the road must cross
## where it is aimed and never touch the gate.
func _phase_neck() -> void:
	print("-- PHASE N: the zone 1 <-> 2 neck crosses off the road --")
	var start := Vector3(-30.0, 0.0, -74.0)
	var target := Vector3(-30.0, 0.0, -92.0)
	_check(HubRegion.contains(start) and HubRegion.zone_of(start) == 1,
		"the start (%.0f, %.0f) is walkable zone 1" % [start.x, start.z])
	_check(HubRegion.contains(target) and HubRegion.zone_of(target) == 2,
		"the target (%.0f, %.0f) is walkable zone 2" % [target.x, target.z])
	var parked: bool = await _park(start)
	_check(parked, "the camera settled over the start")
	# Every frame of the walk, not the endpoints: a detour through the
	# gate would return to the line and an endpoint test could not see it.
	var worst_gate := INF
	var worst_side := 0.0
	var frames := 0
	for k in 8:
		var at := _flat(_keepy.global_position)
		if at.distance_to(target) < 1.0:
			break
		var lo := 0.0
		var hi := 1.0
		if _tappable(HubSurface.ground(target)):
			lo = 1.0
		else:
			for i in 18:
				var mid := 0.5 * (lo + hi)
				if _tappable(HubSurface.ground(at.lerp(target, mid))):
					lo = mid
				else:
					hi = mid
		if lo <= 0.001:
			break
		_tap._handle_point(_to_screen(HubSurface.ground(at.lerp(target, lo))))
		await get_tree().process_frame
		frames += 1
		while _keepy.is_hopping() and frames < 1400:
			var here := _flat(_keepy.global_position)
			worst_gate = minf(worst_gate, here.distance_to(HubWorld.MOOR_GATE))
			worst_side = maxf(worst_side, absf(here.x - start.x))
			await get_tree().process_frame
			frames += 1
	var landed := _flat(_keepy.global_position)
	_check(landed.distance_to(target) < 1.0,
		"he arrived: %.3f u from the target (%d frames)" % [landed.distance_to(target), frames])
	_check(HubRegion.zone_of(landed) == 2, "he is in zone 2 (zone_of = %d)" % HubRegion.zone_of(landed))
	# The road is 42 u east of this line, so a routed walk could not be shy
	# of the gate by less than that.
	_check(worst_gate > 20.0,
		"he never went near MOOR_GATE: closest approach %.3f u" % worst_gate)
	_check(worst_side < 3.0,
		"he walked STRAIGHT: worst lateral excursion %.3f u" % worst_side)

# =====================================================================
## THE REFUSALS, after the positive half so "it refuses" cannot pass by
## the channel never working. Each row names ground that must STILL be
## outside, and the reason it is pinned.
func _phase_refusals() -> void:
	print("-- PHASE R: the pinned edges and the holes still refuse --")
	var rows: Array[Dictionary] = [
		# NOT z -100: COVE_CORRIDOR spans x[38,44] z[-100,-92], so a sample
		# there is refused by the moor and admitted by the cove -- it would
		# have tested the cove's own corridor and called it the moor's pin.
		{"p": Vector3(42.0, 0.0, -110.0), "why": "zone 2 EAST is pinned at x 38 (the cove corridor)"},
		{"p": Vector3(0.0, 0.0, -131.0), "why": "zone 2 SOUTH is pinned at z -126 (the circuit band)"},
		{"p": Vector3(40.0, 0.0, -38.0), "why": "zone 1 NORTH is pinned at z -42 (the zone 0 square)"},
		{"p": HubRegion.MOTHER_TREE_AT, "why": "the Mother Tree's trunk is a hole"},
		{"p": HubRegion.WINDMILL_AT, "why": "the windmill's base is a hole"},
	]
	for row in rows:
		var p: Vector3 = row["p"]
		_check(not HubRegion.contains(p), "%s: (%.1f, %.1f) refused" % [row["why"], p.x, p.z])
	# And the refusal is not a wall of nothing: walkable ground sits a few
	# units inside each pinned edge, which is what makes the pin a LIMIT
	# rather than a hole in the map.
	var inside: Array[Dictionary] = [
		{"p": Vector3(36.0, 0.0, -100.0), "why": "zone 2 just inside its east pin"},
		{"p": Vector3(0.0, 0.0, -124.0), "why": "zone 2 just inside its south pin"},
		{"p": Vector3(40.0, 0.0, -44.0), "why": "zone 1 just inside its north pin"},
	]
	for row in inside:
		var p: Vector3 = row["p"]
		_check(HubRegion.contains(p), "%s: (%.1f, %.1f) walkable" % [row["why"], p.x, p.z])
	# The moor corridor is INERT now, and that is a claim worth gating: if
	# a later lot shrinks AUTUMN, this row goes red instead of the corridor
	# silently becoming load-bearing again.
	var mid := Vector3(
		0.5 * (HubRegion.MOOR_CORRIDOR_MIN.x + HubRegion.MOOR_CORRIDOR_MAX.x), 0.0,
		0.5 * (HubRegion.MOOR_CORRIDOR_MIN.y + HubRegion.MOOR_CORRIDOR_MAX.y))
	_check(HubRegion._in_rect(mid, HubRegion.AUTUMN_MIN, HubRegion.AUTUMN_MAX),
		"MOOR_CORRIDOR is contained by AUTUMN, i.e. inert (%.1f, %.1f)" % [mid.x, mid.z])
