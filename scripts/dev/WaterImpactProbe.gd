extends Node

## Gates the water-impact cue: the waterline pulse and the surface ring a
## dive gets when it ends IN WATER.
##
## WHY IT IS GATED AND NOT MERELY REPORTED. Every way this cue can fail is
## SILENT. A uniform that turns out not to be tweenable leaves the pulse
## flat; a pulse interrupted at the top leaves Keepy soaked to the
## shoulders on dry grass for the rest of the session; a ring parented one
## node higher lands in a permanent draw-node budget; a ring whose tween
## never reaches its free leaks one node per dive. Not one of those raises,
## breaks a build, or looks like anything other than "the effect was never
## switched on" -- which is precisely what a device tester would report,
## and precisely what nobody could then attribute.
##
## ⚠️ WHAT THIS PROBE CANNOT DECIDE, and the reason a device pass stays
## mandatory before anything reaches main: it runs on llvmpipe through the
## DESKTOP opengl3 backend, and the game runs WebGL2 under Safari. Those
## are two different GLSL compilers and, more to the point here, two
## different transparent-sort implementations. An alpha ring drawn beside
## an alpha water disc is the same neighbourhood as the waterline shader's
## own device failure, which was green in this sandbox right up until it
## was looked at on a phone from a second angle.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")

var _failures: int = 0
var _hub: Node = null
var _world: Node3D = null
var _consts: Dictionary = {}

## ⚠️ CONSTANTS ARE NOT PROPERTIES. Object.get("SOME_CONST") returns null
## for a GDScript const, silently -- it does not warn and it does not
## error. This probe's first run read every threshold it uses as null,
## which arithmetic then treated as zero: the pulse was sampled at t=0
## instead of at its peak, reported "0.4500 -> 0.4500", and accused a
## uniform that turns out to tween perfectly well. The constant map is the
## accessor that actually works, and it is used for all of them.
func _const(name: String) -> float:
	return _consts.get(name, 0.0)

func _ready() -> void:
	ProbeWatchdog.arm(self, "WaterImpactProbe")
	_hub = HUB_SCENE.instantiate()
	add_child(_hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_world = _hub.get_node("WorldViewport/SubViewport/World")
	_consts = _hub.get_script().get_script_constant_map()

	await _phase_a()
	await _phase_b()
	await _phase_c()
	await _phase_d()
	await _phase_e()

	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	print("  %s  %s" % ["OK  " if ok else "FAIL", label])
	if not ok:
		_failures += 1

## Rings currently alive, counted where they are actually parented.
func _rings() -> int:
	var n := 0
	for c in _world.get_children():
		if c is MeshInstance3D and c.mesh is TorusMesh:
			n += 1
	return n

func _props_meshes() -> int:
	var props: Node = _world.get_node("Props")
	return _count_meshes(props)

func _count_meshes(node: Node) -> int:
	var n := 1 if node is MeshInstance3D else 0
	for c in node.get_children():
		n += _count_meshes(c)
	return n

func _water_y() -> float:
	var mat: ShaderMaterial = _hub.get("_keepy_material")
	if mat == null:
		return -1.0
	return mat.get_shader_parameter("water_y")

## A point that is definitely inside water, taken from the water test the
## screen itself uses rather than from a coordinate typed in here.
func _wet_point() -> Vector3:
	var builder = _hub.get("_builder")
	var c: Vector3 = builder.pond_centre()
	return Vector3(c.x, 0.0, c.z)

# ---------------------------------------------------------------- PHASE A
## The uniform is tweenable, and the pulse comes back down.
##
## The first half is PHASE 0's own question asked of the shipped code
## instead of assumed: shader_parameter/water_y is driven by exactly the
## mechanism shader_parameter/tint_fraction already is, and a uniform that
## silently refused to tween would leave the cue flat with nothing to say
## so.
func _phase_a() -> void:
	print("--- PHASE A: the waterline pulse rises and returns ---")
	_hub.call("_ensure_keepy_material")
	var rest: float = _water_y()
	_check(is_equal_approx(rest, _const("KEEPY_WATERLINE_Y")),
		"at rest the waterline sits on the shipped constant (%.4f)" % rest)

	# ⚠️ SAMPLED EVERY FRAME ACROSS THE WHOLE PULSE, not once at a
	# wall-clock instant. The first version of this phase awaited a timer
	# set to 95% of the rise and read one value -- and under llvmpipe the
	# hub renders at about 14 fps, so a 0.0855s timer and the tween's first
	# process step land on the SAME frame and the order between them is not
	# defined. It read 0.4500, reported the uniform as untweenable, and was
	# wrong: an isolated ShaderMaterial drives this exact property path
	# from 0.88 down to 0.48 without complaint. A curve is what is being
	# asserted, so a curve is what is watched.
	var peak: float = rest
	var trough: float = rest
	_hub.call("_pulse_keepy_waterline")
	var span: float = _const("KEEPY_SPLASH_RISE_S") + _const("KEEPY_SPLASH_FALL_S")
	var elapsed: float = 0.0
	while elapsed < span + 0.25:
		elapsed += get_process_delta_time()
		var v: float = _water_y()
		peak = maxf(peak, v)
		trough = minf(trough, v)
		await get_tree().process_frame
	_check(peak > rest + 0.2,
		"the line rides UP him during the pulse: rest %.4f, peak %.4f" % [rest, peak])
	_check(peak <= _const("KEEPY_SPLASH_WATERLINE_Y") + 0.001,
		"and never overshoots the constant it aims at (%.4f)" % peak)
	_check(trough >= rest - 0.001,
		"it never dips BELOW the resting line on the way back (%.4f)" % trough)
	_check(is_equal_approx(_water_y(), rest),
		"and it settles back exactly onto the constant (%.4f)" % _water_y())

	# INTERRUPTED, which is the case that would strand him soaked to the
	# shoulders on dry grass for the rest of the session.
	_hub.call("_pulse_keepy_waterline")
	await get_tree().process_frame
	await get_tree().process_frame
	_hub.call("_pulse_keepy_waterline")
	var e2: float = 0.0
	while e2 < span + 0.3:
		e2 += get_process_delta_time()
		await get_tree().process_frame
	_check(is_equal_approx(_water_y(), rest),
		"a pulse interrupted by a second one still ends on the constant")

# ---------------------------------------------------------------- PHASE B
## A dive into water produces a ring; a dive onto land produces nothing.
##
## ⚠️ THE ORDER HERE IS THE POINT. The water case is asserted FIRST, and
## the land case only afterwards, because "no ring appeared" is an
## assertion that passes for free against a cue that was never wired up at
## all. Proving the cue CAN fire is what earns the right to assert that it
## did not.
func _phase_b() -> void:
	print("--- PHASE B: water splashes, land does not ---")
	var before := _rings()
	_hub.call("_on_board_dived")
	_hub.call("_on_hop_landed", _wet_point())
	var after_wet := _rings()
	_check(after_wet == before + 1,
		"a dive landing IN WATER spawns exactly one ring (%d -> %d)" % [before, after_wet])

	# The blind control's other half: the land case, now that the line
	# above has shown the counter moves.
	var dry := Vector3(0.0, 0.0, 0.0)
	var water = _hub.get("_water")
	_check(not water.contains(dry), "the control point is genuinely dry land")
	var before_dry := _rings()
	_hub.call("_on_board_dived")
	_hub.call("_on_hop_landed", dry)
	_check(_rings() == before_dry,
		"a dive landing ON LAND spawns none (%d -> %d)" % [before_dry, _rings()])
	_check(not _hub.get("_dive_pending"),
		"and the dry landing DISARMED the latch instead of leaving it primed")

	# An ordinary hop into the same water, with no dive behind it, is not
	# an impact -- otherwise every step through a shallow would splash.
	var before_hop := _rings()
	_hub.call("_on_hop_landed", _wet_point())
	_check(_rings() == before_hop,
		"an ordinary hop into water does NOT splash (%d -> %d)" % [before_hop, _rings()])

	await get_tree().create_timer(_const("SPLASH_LIFE_S") + 0.3).timeout

# ---------------------------------------------------------------- PHASE C
## The ring is above every water surface there is, and draws its near face
## only.
func _phase_c() -> void:
	print("--- PHASE C: the ring's height and its cull mode ---")
	var tops: Array[float] = []
	_collect_water_tops(_world.get_node("Props"), tops)
	_check(tops.size() >= 4, "found %d alpha water surfaces on the built tree" % tops.size())
	var highest: float = -INF
	for t in tops:
		highest = maxf(highest, t)
	var ring_y: float = _const("SPLASH_RING_Y")
	_check(ring_y > highest,
		"the ring clears the HIGHEST water top: %.4f > %.4f" % [ring_y, highest])
	var lowest: float = INF
	for t in tops:
		lowest = minf(lowest, t)
	# Reported, not gated: this is the cost of one constant for five
	# bodies, and it is Mathieu's to judge, not this probe's to fail.
	print("    float above the LOWEST surface (%.4f): %.4f" % [lowest, ring_y - lowest])

	_hub.call("_on_board_dived")
	_hub.call("_on_hop_landed", _wet_point())
	var ring: MeshInstance3D = null
	for c in _world.get_children():
		if c is MeshInstance3D and c.mesh is TorusMesh:
			ring = c
	_check(ring != null, "the ring is parented to the 3D world root")
	if ring != null:
		var m := ring.get_surface_override_material(0) as StandardMaterial3D
		_check(m != null and m.cull_mode == BaseMaterial3D.CULL_BACK,
			"it draws its NEAR face only -- the waterline shader's scar")
		_check(m != null and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
			"alpha blending is asked for, so the fade is not a no-op")
		_check(m != null and m.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"unshaded, like every other surface on this screen")
		var t := ring.mesh as TorusMesh
		var tris: int = t.rings * t.ring_segments * 2
		_check(t.rings <= 32 and t.ring_segments <= 8,
			"tessellation is stated, not defaulted: %d x %d = %d tris (a default TorusMesh is 4096)"
				% [t.rings, t.ring_segments, tris])
	await get_tree().create_timer(_const("SPLASH_LIFE_S") + 0.3).timeout

func _collect_water_tops(node: Node, out: Array[float]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := mi.get_surface_override_material(0) as StandardMaterial3D
		if mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			var aabb := mi.get_aabb()
			out.append(mi.global_transform.origin.y + aabb.position.y + aabb.size.y)
	for c in node.get_children():
		_collect_water_tops(c, out)

# ---------------------------------------------------------------- PHASE D
## It does not leak. Twenty dives, counted back to where it started.
##
## The count is taken at the NODE level rather than by trusting that
## nothing crashed: a cue that leaks one node per dive runs perfectly well
## and only shows up after a long session, which is the hardest kind of
## fault to attribute afterwards.
func _phase_d() -> void:
	print("--- PHASE D: twenty dives, nothing left behind ---")
	var baseline := _world.get_child_count()
	var peak := 0
	for i in range(20):
		_hub.call("_on_board_dived")
		_hub.call("_on_hop_landed", _wet_point())
		peak = maxi(peak, _rings())
		await get_tree().create_timer(0.02).timeout
	_check(peak > 0, "the dives really did spawn rings (peak %d alive at once)" % peak)
	await get_tree().create_timer(_const("SPLASH_LIFE_S") + 0.6).timeout
	var after := _world.get_child_count()
	_check(after == baseline,
		"the world root is back to its starting child count (%d -> %d)" % [baseline, after])
	_check(_rings() == 0, "no ring survives its own tween")

# ---------------------------------------------------------------- PHASE E
## The permanent budget is untouched, measured before AND after rather
## than only while the effect is up.
func _phase_e() -> void:
	print("--- PHASE E: the static budget is not moved ---")
	var before := _props_meshes()
	_hub.call("_on_board_dived")
	_hub.call("_on_hop_landed", _wet_point())
	var during := _props_meshes()
	_check(during == before,
		"a live ring is NOT inside Props (%d -> %d)" % [before, during])
	await get_tree().create_timer(_const("SPLASH_LIFE_S") + 0.4).timeout
	var after := _props_meshes()
	_check(after == before,
		"and the count is unchanged once it is gone (%d)" % after)
	print("    Props MeshInstance3D total: %d" % after)
