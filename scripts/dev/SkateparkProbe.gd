extends Node
## CH53 -- THE SKATEPARK'S RENDERING GATE.
##
## =====================================================================
## WHAT RUNS HERE AND WHAT RUNS NEXT DOOR
##
## This probe reads PIXELS, SCREEN POINTS and the RENDERER'S COUNTERS. It
## therefore runs under `xvfb-run --rendering-driver opengl3` and never
## under `--headless` alone: the dummy driver returns a blank surface, an
## identity transform for every MultiMesh instance, a 0x0 viewport and
## compiles no shader -- four independent false-green machines, none of
## which announces itself (CLAUDE.md, and CH50 shipped one in this exact
## family).
##
## Everything that is pure arithmetic -- the module table, the chain, the
## ledger's guard, the traversal walk -- lives in SkateTraverseProbe and
## runs HEADLESS, for the opposite reason: under llvmpipe a probe that
## walks the real hopper for hundreds of simulated seconds does not
## finish inside any budget (CH32, measured twice).
##
## =====================================================================
## WHY A VISUAL OBJECT CANNOT BE GATED ON GEOMETRY ALONE
##
## CH39 is the whole reason PHASE P exists. Seven phases -- containment,
## C0 joins, summits, triangulation, slopes, sight lines, budget, a
## walked traversal -- came back ALL GREEN on a hillside the engine threw
## away in its entirety, because the ones that raycast read the GRID and
## the ones that count read what was SUBMITTED. A back-face-culled object
## pays full price on the primitive counter and draws nothing.
##
## So: PHASE P reads at least one PIXEL of each module, through a masked
## identification pass (the target painted in a colour nothing else
## carries, haze off, membership iff the colour comes back exactly). And
## PHASE W renders `cull_back` against `cull_disabled` on the same frame,
## which is the only orientation test in this repo with no threshold to
## tune and the one that caught CH39.
##
## =====================================================================
## THE BUDGET, AND THE TWO HALVES OF ONE COMMIT
##
## CH52 section 8.5: the north lobe has ZERO headroom, so the park has to
## be BOUGHT out of the same frame in the SAME commit. PHASE B gates the
## park's own cost, and it gates it the way CH40 and CH41 say a cost has
## to be gated:
##
##   * against the NOISE FLOOR OF ITS OWN STATION, measured by repeating
##     the read with nothing touched -- this hub drifts by hundreds of
##     primitives between untouched frames (the bear walks, the
##     butterflies fly, it rains);
##   * with an assertion that there IS something to switch off
##     (`nodes.size() > 0`), because CH40 measured a "hide it and reread"
##     delta come back +64 from a list that was EMPTY.
##
## The NET -- park cost against what the grass guard gives back -- is a
## CROSS-TREE measurement and is deliberately not faked here: the guard
## removes instances at generation time and no probe can put them back.
## PHASE D publishes this tree's north-carpet census so the same phase on
## a reference tree subtracts to an exact recovery.

const VP_SIZE: Vector2i = Vector2i(1080, 1920)
const BUDGET_S: float = 1500.0
## CH52's worst frame of the lobe, and the station the device reading is
## asked for. Not re-derived: quoted from the lot that measured it.
const WORST: Vector2 = Vector2(-10.0, 51.0)
const STATIONS: Array[Vector2] = [
	Vector2(0.0, 42.0), Vector2(-10.0, 51.0), Vector2(0.0, 51.0), Vector2(0.0, 63.0)]
## Reads with NOTHING touched, per station: the floor.
const REPEATS: int = 6
const SETTLE: int = 3

var _fails: int = 0
var _hub: Node = null
var _world: Node3D = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _sub: SubViewport = null
var _park: HubSkatepark = null
var _scatter: Node = null
var _hud: SkateHud = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATEPARK PROBE", BUDGET_S)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	_world = _hub.get_node("WorldViewport/SubViewport/World") as Node3D
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy") as Node3D
	_camera = _hub.get_node("WorldViewport/SubViewport/World/Camera3D") as Camera3D
	_sub = _hub.get_node("WorldViewport/SubViewport") as SubViewport
	_park = _hub.get_node("WorldViewport/SubViewport/World/Skatepark") as HubSkatepark
	_scatter = _hub.get_node("WorldViewport/SubViewport/World/CozyScatter")
	_hud = _hub.get_node("SkateHud") as SkateHud

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _process(_delta: float) -> void:
	set_process(false)
	# stretch = false FIRST: a stretching container IGNORES an explicit
	# size and only warns (CLAUDE.md).
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	box.stretch = false
	_sub.size = VP_SIZE
	_run()

func _run() -> void:
	print("=== SKATEPARK PROBE -- CH53 ===")
	print("  park centre (%.1f, %.1f)   modules %d   lobe r %.1f to z %.1f"
		% [HubSkatepark.PARK_CENTRE.x, HubSkatepark.PARK_CENTRE.y,
			_park.module_count(), HubRegion.SKATE_LOBE_RADIUS,
			HubRegion.PLATEAU_HALF_EXTENT + HubRegion.SKATE_LOBE_RADIUS])
	print("  grass guard: keep %.0f %% north of z = %.1f, families %s"
		% [CozyScatter.NORTH_COVER_KEEP * 100.0, CozyScatter.NORTH_KEEP_FROM_Z,
			str(CozyScatter.NORTH_KEEP_FAMILIES)])
	print("")
	await _phase_instrument()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every number below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_geometry()
	await _phase_winding()
	await _phase_pixels()
	await _phase_budget()
	await _phase_carpet()
	await _phase_framing()
	await _phase_hud()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# READING

func _prims() -> int:
	return RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)

func _calls() -> int:
	return RenderingServer.viewport_get_render_info(_sub.get_viewport_rid(),
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)

func _station(flat: Vector2) -> void:
	_keepy.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.y))
	if _camera.has_method("snap_to_target"):
		_camera.call("snap_to_target")
	for _i in SETTLE:
		await get_tree().process_frame

## Station, then FREEZE -- NorthBudgetProbe's reason, restated because it
## is not obvious: two things FOLLOW Keepy in _process (the precipitation
## column and his ground shadow), so freezing before the walk would leave
## the rain box parked at the previous station.
func _station_frozen(flat: Vector2) -> void:
	get_tree().paused = false
	await _station(flat)
	get_tree().paused = true
	for _i in SETTLE:
		await get_tree().process_frame

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return _sub.get_texture().get_image()

# =====================================================================
# PHASE I -- THE INSTRUMENT. Nothing below is readable until this passes.

func _phase_instrument() -> void:
	print("-- PHASE I: instrument control (the dummy driver's four false greens) --")
	await _station(Vector2(0.0, 51.0))
	var img := await _image()
	_check(img != null and img.get_width() == VP_SIZE.x and img.get_height() == VP_SIZE.y,
		"I1 viewport really is %dx%d (got %dx%d)"
			% [VP_SIZE.x, VP_SIZE.y, img.get_width() if img else -1, img.get_height() if img else -1])
	var tones := {}
	for y in range(0, img.get_height(), 37):
		for x in range(0, img.get_width(), 37):
			tones[img.get_pixel(x, y).to_rgba32()] = true
	_check(tones.size() > 8,
		"I2 the frame is RASTERISED -- %d distinct sampled colours (the dummy driver gives 1)" % tones.size())
	var prims := _prims()
	_check(prims > 0, "I3 the engine's primitive counter is FILLED: %d (a 0 is published as a 0)" % prims)
	# The counter has to MOVE. Two different stations, and hiding the
	# ground: an instrument that cannot move cannot measure a delta.
	await _station(Vector2(0.0, 0.0))
	var at_spawn := _prims()
	_check(at_spawn != prims,
		"I4 two stations do not read the same number (%d at z=51, %d at spawn)" % [prims, at_spawn])
	# And the park's own nodes exist and are drawable -- the CH40 guard,
	# stated here once so every later phase can lean on it.
	var nodes := _park.module_nodes()
	_check(nodes.size() == _park.module_count(),
		"I5 the park published %d drawn nodes for %d modules" % [nodes.size(), _park.module_count()])
	var meshed: int = 0
	for n in nodes:
		if n.mesh != null and n.mesh.get_surface_count() > 0:
			meshed += 1
	_check(meshed == nodes.size(), "I6 all %d module nodes carry a surface" % nodes.size())
	print("")

# =====================================================================
# PHASE G -- the geometry contract, and the ceiling CH52 set.

func _phase_geometry() -> void:
	print("-- PHASE G: triangles, the ceiling, and where the modules stand --")
	var total: int = 0
	for i in _park.module_count():
		var node := _park.module_node(i)
		var tris: int = node.mesh.get_faces().size() / 3
		total += tris
		var centre := _park.module_centre(i)
		var spec: Dictionary = HubSkatepark.MODULES[i]
		print("     %-12s at (%6.1f, %6.1f)  %4d tri  footprint %.1f"
			% [String(spec["kind"]), centre.x, centre.z, tris, float(spec["footprint"])])
	_check(total == _park.triangle_total(),
		"G1 the park's published total (%d) is what the meshes actually carry (%d)"
			% [_park.triangle_total(), total])
	_check(total <= SkateparkMesh.BUDGET_TRIS,
		"G2 park %d tri <= CH52 ceiling %d" % [total, SkateparkMesh.BUDGET_TRIS])
	# CH64: the slab is the park's too, and the ceiling is the park's.
	print("     CH64: the slab adds %d triangles (published by decor_triangles)" % _park.decor_triangles())
	_check(_park.decor_triangles() > 0 and _park.slab_node() != null,
		"G3 the slab exists and publishes its own count (%d)" % _park.decor_triangles())
	_check(total + _park.decor_triangles() <= SkateparkMesh.BUDGET_TRIS,
		"G4 park + slab %d tri <= CH52 ceiling %d" % [total + _park.decor_triangles(), SkateparkMesh.BUDGET_TRIS])
	# Containment: every module, plus its footprint, inside the lobe. The
	# zipline's north tower overhung the world by 1.682 u because nobody
	# asked this (CLAUDE.md).
	var inside: int = 0
	var margin_worst: float = 1e9
	for i in _park.module_count():
		var c := _park.module_centre(i)
		var fp: float = float(HubSkatepark.MODULES[i]["footprint"])
		# Sample the footprint's rim rather than its centre: a centre
		# inside a region says nothing about the piece around it.
		var all_in: bool = true
		var worst: float = 1e9
		for k in 24:
			var t: float = float(k) / 24.0 * TAU
			var p := c + Vector3(cos(t), 0.0, sin(t)) * fp
			if not HubRegion.contains(p):
				all_in = false
			worst = minf(worst, HubRegion.SKATE_LOBE_RADIUS
				- Vector2(p.x, p.z).distance_to(Vector2(0.0, HubRegion.PLATEAU_HALF_EXTENT)))
		if all_in:
			inside += 1
		margin_worst = minf(margin_worst, worst)
	_check(inside == _park.module_count(),
		"G3 all %d module footprints are entirely inside the region (%d)" % [_park.module_count(), inside])
	print("     tightest lobe margin over any footprint rim: %.2f u" % margin_worst)
	# And nothing sits on anything that was already there.
	var clash: int = 0
	var existing: Array = []
	existing.append_array(HubTransport.footprints())
	existing.append_array(HubTrees.footprints())
	existing.append_array(HubCove.footprints())
	for i in _park.module_count():
		var c := _park.module_centre(i)
		var fp: float = float(HubSkatepark.MODULES[i]["footprint"])
		for other in existing:
			var o: Vector3 = other["position"]
			if Vector2(c.x - o.x, c.z - o.z).length() < fp + float(other["radius"]):
				clash += 1
				print("     ** clash: module %d against a footprint at (%.1f, %.1f)" % [i, o.x, o.z])
	_check(clash == 0, "G4 no module overlaps a footprint that was already published (%d clashes)" % clash)
	# The modules against EACH OTHER: two overlapping discs would make
	# `landed_within` ambiguous, and the chain rule leans on which module
	# a landing was on.
	var pair_clash: int = 0
	var tightest: float = 1e9
	for i in _park.module_count():
		for j in range(i + 1, _park.module_count()):
			var a := _park.module_centre(i)
			var b := _park.module_centre(j)
			var d: float = Vector2(a.x - b.x, a.z - b.z).length()
			var need: float = float(HubSkatepark.MODULES[i]["tap_radius"]) \
				+ float(HubSkatepark.MODULES[j]["tap_radius"])
			tightest = minf(tightest, d - need)
			if d < need:
				pair_clash += 1
	_check(pair_clash == 0,
		"G5 no two scoring discs overlap (tightest gap %.2f u)" % tightest)
	print("")

# =====================================================================
# PHASE W -- WINDING, BY RENDER.
#
# CH39's judge, and the reason it is a render and not an assertion: a
# probe that re-reads a cross product against a convention written in a
# comment was green 1 680 times out of 1 680 on a mesh the engine
# discarded whole. `cull_back` against `cull_disabled` on the same frame
# has no threshold and works at any station on any shape.
#
# ⚠️ THE DECOR SHADER IS `cull_disabled`, so an inside-out park would look
# PERFECT today. This phase is what stops the trap from being armed for
# the first lot that gives these modules a culling material.

## =====================================================================
## ⚠️ CH60 -- A TEST THAT IS SOUND ON ONE CLASS OF SHAPE IS A COIN TOSS ON
## ANOTHER, AND IT DOES NOT ANNOUNCE THE CHANGE
##
## The depth-sign sub-check below says of itself that "it works on a
## closed convex body". That is true, and it is also the whole of its
## validity: it assumes no surface can FACE AWAY from the camera while
## being NEARER than a front-facing one. A concave body breaks exactly
## that assumption.
##
## CH60 corrected the quarterpipe's profile (it had been built as its own
## transpose since CH53 -- a convex hump instead of a concave transition)
## and this sub-check reddened on module 2 at 0.2836 against 0.2831: a
## 0.18 % tie reported as an inside-out mesh.
##
## ⚠️ IT WAS NOT SILENCED, IT WAS MEASURED (CLAUDE.md forbids the first
## and this is what the second gave). The module was rebuilt INSIDE OUT
## and both tests re-read at five stations:
##
##   | module 2      | kept ratio      | depth sign, by station        |
##   |---------------|-----------------|-------------------------------|
##   | correct       | 1.0000 x5       | ok, ok, ok, INVERTED, INVERTED|
##   | inside out    | 0.575 -- 0.729  | ok, ok, INVERTED x3           |
##
## The two verdict sets OVERLAP: this sub-check cannot tell a correctly
## wound quarterpipe from an inverted one, and its answer follows the
## STATION. The kept-ratio judge separates them completely, because a
## CONCAVE body does not keep its silhouette under inversion -- which is
## the very blindness the sub-check was added to cover, and it does not
## apply here.
##
## ⚠️ AND IT IS NOT THIS LOT'S GEOMETRY THAT IS SPECIAL. The same sweep
## caught the BOWL -- untouched by CH60, a concave dish -- reporting
## INVERTED at 0.2503 against 0.2490 from (5.0, 60.0). The unsoundness
## was already in the delivered park; the corrected quarterpipe merely
## stood at a station where it fires.
##
## So the sub-check now publishes its own floor and RETURNS NO VERDICT
## where it cannot resolve, and every module it declines is handed to the
## judge -- with the hand-off PROVED by a red pass in the same run.

## The floor a gap must clear even when two repeats happen to land on the
## same value. 0.002 is under a tenth of the smallest gap any convex
## module here produces (the rail's 0.0025) and forty times the ties the
## concave modules produce (0.0005), so it separates the two populations
## without being tuned to either.
const DEPTH_FLOOR_MIN: float = 0.002

func _phase_winding() -> void:
	print("-- PHASE W: winding, rendered (cull_back vs cull_disabled) --")
	# One material per test, both built from the SAME source so the only
	# difference is the cull mode -- CH23's rule for a control that is
	# built from the delivered shader and not from an approximation.
	var shader_src := """
shader_type spatial;
render_mode unshaded, %s, depth_draw_opaque, shadows_disabled;
void fragment() { ALBEDO = vec3(1.0, 0.0, 1.0); }
"""
	# ⚠️ AND A SECOND TEST, BECAUSE THE FIRST ONE MISSED ONE.
	#
	# The red pass of this lot inverted `SkateparkMesh._tri`'s convention
	# and got FOUR reds where five were expected. The survivor was the
	# RAIL, at 0.9977 of its pixels -- and it is not a flaw in the rail,
	# it is arithmetic: a CLOSED CONVEX solid rendered inside out covers
	# EXACTLY THE SAME SILHOUETTE. What you see is the inside of its far
	# wall instead of the outside of its near one, and a flat unshaded
	# colour cannot tell those apart. A pixel COUNT is a silhouette test,
	# and a silhouette does not change under inversion.
	#
	# CLAUDE.md's rule about a count of expected failures being part of
	# the assertion is what turned that into a finding instead of a
	# shrug -- and the answer is not to lower the first test, it is to
	# add one that discriminates.
	#
	# WHICH SURFACE IS IN FRONT. The shader below encodes VIEW-SPACE
	# DEPTH as a grey. Rendered `cull_back`, a correctly wound body shows
	# its NEAR surface; `cull_front` shows its FAR one. Inverted, the two
	# swap. So the mean encoded depth under cull_back must be SMALLER
	# than under cull_front -- a SIGN, with no threshold to tune, and it
	# works on a closed convex body where the silhouette test cannot.
	var depth_src := """
shader_type spatial;
render_mode unshaded, %s, depth_draw_opaque, shadows_disabled;
varying float vd;
void vertex() { vd = clamp(-(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z / 60.0, 0.02, 0.98); }
void fragment() { ALBEDO = vec3(0.0, vd, 0.0); }
"""
	var back := ShaderMaterial.new()
	back.shader = Shader.new()
	back.shader.code = shader_src % "cull_back"
	var both := ShaderMaterial.new()
	both.shader = Shader.new()
	both.shader.code = shader_src % "cull_disabled"
	var depth_back := ShaderMaterial.new()
	depth_back.shader = Shader.new()
	depth_back.shader.code = depth_src % "cull_back"
	var depth_front := ShaderMaterial.new()
	depth_front.shader = Shader.new()
	depth_front.shader.code = depth_src % "cull_front"
	var nodes := _park.module_nodes()
	var unresolved: Array = []
	var resolved: int = 0
	_check(not nodes.is_empty(), "W0 there ARE module nodes to test (CH40's empty-list guard)")
	# Stand where a RIDER stands: at the board's park, north of the
	# modules, looking south down the line. South of the park the camera
	# has the whole thing behind it -- see HubSkatepark's frame
	# arithmetic; a winding test taken from there would measure zero
	# pixels for four modules and say nothing about their winding.
	await _station(Vector2(HubTransport.SKATE_PARK.x, HubTransport.SKATE_PARK.z))
	var worst_ratio: float = 1.0
	for i in nodes.size():
		var node: MeshInstance3D = nodes[i]
		node.material_override = both
		var open := await _count_magenta()
		node.material_override = back
		var culled := await _count_magenta()
		node.material_override = null
		var ratio: float = 0.0 if open <= 0 else float(culled) / float(open)
		worst_ratio = minf(worst_ratio, ratio)
		print("     module %d  cull_disabled %6d px   cull_back %6d px   kept %.4f"
			% [i, open, culled, ratio])
		_check(open > 0, "W%d-a module %d paints pixels at all with culling off" % [i + 1, i])
		# 0.98 and not 1.000: a closed body seen from one side legitimately
		# loses a handful of edge fragments to rasterisation, and demanding
		# an exact match would be a threshold tuned on an artefact. An
		# INSIDE-OUT mesh does not lose a few per cent -- CH39 measured 14
		# pixels against 317 646.
		_check(ratio > 0.98,
			"W%d-b module %d keeps %.4f of its pixels under cull_back (inside out reads ~0)"
				% [i + 1, i, ratio])
		# The depth sign -- the test that sees a closed convex body.
		node.material_override = depth_back
		var near := await _mean_depth()
		# ⚠️ THE SUB-CHECK'S OWN NOISE FLOOR, READ ON THE SAME MODULE WITH
		# NOTHING TOUCHED. CH60 added it, and CLAUDE.md demanded it long
		# before: "un delta sans son plancher de bruit ne vaut rien", and
		# its other half, "une sonde dont le plancher depasse sa grandeur
		# doit rendre une ABSENCE DE VERDICT". Two renders of one state.
		var near_again := await _mean_depth()
		node.material_override = depth_front
		var far := await _mean_depth()
		node.material_override = null
		var floor_d: float = absf(near - near_again)
		var gap: float = far - near
		print("       depth: cull_back mean %.4f (repeat %.4f)  cull_front mean %.4f   gap %+.4f  floor %.4f"
			% [near, near_again, far, gap, floor_d])
		_check(near > 0.0 and far > 0.0,
			"W%d-c module %d paints under BOTH cull modes (else the sign below is free)" % [i + 1, i])
		if near <= 0.0 or far <= 0.0:
			continue
		if absf(gap) <= maxf(floor_d, DEPTH_FLOOR_MIN):
			# ⚠️ NO VERDICT, AND THE REASON IS MEASURED RATHER THAN
			# ASSUMED. See the block above `DEPTH_FLOOR_MIN`: on a CONCAVE
			# body this sub-check's sign follows the STATION and not the
			# winding, so a verdict taken here would be a coin toss
			# published as a measurement. The module is not thereby
			# excused -- it is handed to the test that CAN see it, and
			# that hand-off is PROVED below rather than asserted.
			print("       -> UNRESOLVED (|gap| %.4f <= floor %.4f): this sub-check cannot see"
				% [absf(gap), maxf(floor_d, DEPTH_FLOOR_MIN)])
			print("          this shape. Handed to the kept-ratio judge, red pass below.")
			unresolved.append(i)
			continue
		resolved += 1
		_check(gap > 0.0,
			"W%d-d module %d: its front-facing surface is the NEAR one (%.4f < %.4f, gap %+.4f > floor %.4f)"
				% [i + 1, i, near, far, gap, maxf(floor_d, DEPTH_FLOOR_MIN)])
	print("     worst kept ratio over the park: %.4f" % worst_ratio)
	# ⚠️ INSTRUMENT: the sub-check is not dead everywhere. If NOTHING
	# resolved, "unresolved" would have become a way for every module to
	# escape it, which is the silencing CLAUDE.md forbids.
	_check(resolved > 0,
		"W6 the depth sub-check still RESOLVES on at least one module (%d of %d)"
			% [resolved, nodes.size()])
	await _phase_winding_red(unresolved, both, back)
	print("")

## ⚠️ THE HAND-OFF IS PROVED, NOT ASSERTED.
##
## A module the depth sub-check cannot resolve is covered by the
## kept-ratio judge instead -- and CH39's own lesson is that the judge is
## BLIND on a closed convex body, which is exactly why the sub-check was
## added in the first place. So "the judge covers it" is a claim that has
## to be measured on THIS shape, not argued from its class.
##
## The measurement is the red pass, run here: the module's mesh is rebuilt
## with every triangle reversed, the judge is asked again, and it must now
## FAIL. Then the original mesh goes back and the judge must pass again.
## Green / red / green on one tree, with nothing restored by hand.
##
## Measured at CH60 on the two corrected quarterpipes: correct 1.0000,
## inside out 0.575 to 0.729 across five stations -- a concave body does
## NOT keep its silhouette under inversion, which is precisely why the
## judge sees it and why the sub-check does not have to.
func _phase_winding_red(unresolved: Array, both: ShaderMaterial, back: ShaderMaterial) -> void:
	if unresolved.is_empty():
		print("     (every module resolved on the depth sub-check; no hand-off to prove)")
		return
	print("     RED PASS on the %d module(s) the depth sub-check could not resolve:" % unresolved.size())
	for i in unresolved:
		var node: MeshInstance3D = _park.module_node(i)
		var original: Mesh = node.mesh
		node.mesh = _inverted(original)
		node.material_override = both
		var open := await _count_magenta()
		node.material_override = back
		var culled := await _count_magenta()
		node.material_override = null
		node.mesh = original
		var ratio: float = 0.0 if open <= 0 else float(culled) / float(open)
		print("       module %d rebuilt INSIDE OUT: cull_disabled %6d px  cull_back %6d px  kept %.4f"
			% [i, open, culled, ratio])
		_check(open > 0, "W7-%d INSTRUMENT: the inverted mesh still paints with culling off" % i)
		_check(open > 0 and ratio < 0.90,
			"W7-%d module %d INSIDE OUT is CAUGHT by the kept-ratio judge (%.4f < 0.90)"
				% [i, i, ratio])
		# ...and the module is handed back intact, so nothing after this
		# phase measures a mesh this phase broke.
		node.material_override = both
		var open2 := await _count_magenta()
		node.material_override = back
		var culled2 := await _count_magenta()
		node.material_override = null
		var back_ratio: float = 0.0 if open2 <= 0 else float(culled2) / float(open2)
		_check(back_ratio > 0.98,
			"W8-%d and the module is RESTORED: kept %.4f again" % [i, back_ratio])

## The same mesh with every triangle's winding reversed.
func _inverted(mesh: Mesh) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var flipped := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		flipped.append(idx[t])
		flipped.append(idx[t + 2])
		flipped.append(idx[t + 1])
	arrays[Mesh.ARRAY_INDEX] = flipped
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

## Pixels of the identification colour. Exact equality, never a distance:
## the pass is unshaded and fog-free, so the colour comes back or it does
## not (CLAUDE.md's masked identification pass).
## Mean of the encoded view depth over the pixels the target painted.
## 0.0 when it painted none -- which the caller asserts against, so a body
## that vanished cannot pass the sign test by having no samples at all.
func _mean_depth() -> float:
	for _i in SETTLE:
		await get_tree().process_frame
	var img := await _image()
	var total: float = 0.0
	var n: int = 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			# The identification is the CHANNEL PATTERN, not a distance:
			# the pass writes green only, and nothing else in this scene
			# renders with r and b at exactly zero.
			if c.r < 0.004 and c.b < 0.004 and c.g > 0.015:
				total += c.g
				n += 1
	return 0.0 if n == 0 else total / float(n)

func _count_magenta() -> int:
	for _i in SETTLE:
		await get_tree().process_frame
	var img := await _image()
	var n: int = 0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			if c.r > 0.90 and c.g < 0.10 and c.b > 0.90:
				n += 1
	return n

# =====================================================================
# PHASE P -- IS IT VISIBLE? Not "is it submitted".

func _phase_pixels() -> void:
	print("-- PHASE P: the park paints PIXELS from where a player stands --")
	var mask := ShaderMaterial.new()
	mask.shader = Shader.new()
	mask.shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;
void fragment() { ALBEDO = vec3(1.0, 0.0, 1.0); }
"""
	var nodes := _park.module_nodes()
	# Two stations a player really occupies: the walk-in (where the board
	# is parked) and the middle of the park.
	# The two the rider actually occupies, both looking SOUTH down the
	# line: the board's park at the north end, and mid-park.
	var posts: Array[Vector2] = [
		Vector2(HubTransport.SKATE_PARK.x, HubTransport.SKATE_PARK.z),
		Vector2(HubSkatepark.PARK_CENTRE.x, HubSkatepark.PARK_CENTRE.y + 2.0)]
	for post in posts:
		await _station(post)
		var seen: int = 0
		var line: String = ""
		for i in nodes.size():
			for n in nodes:
				n.material_override = null
			nodes[i].material_override = mask
			var px := await _count_magenta()
			line += "  m%d:%d" % [i, px]
			if px > 0:
				seen += 1
		for n in nodes:
			n.material_override = null
		print("     from (%.1f, %.1f):%s" % [post.x, post.y, line])
		_check(seen > 0,
			"P from (%.1f, %.1f): %d of %d modules paint at least one pixel"
				% [post.x, post.y, seen, nodes.size()])
	# ⚠️ AND IT HAS TO READ AS A PARK, WHICH IS A DIFFERENT ASSERTION
	# FROM "a module is visible". A single ramp in a field is not a
	# skatepark. The station is the one a rider starts from -- NOT the
	# walk-in from the plateau, where this camera can only ever show one
	# module and where CH51 got Mathieu's explicit agreement to live with
	# it. Measuring readability from a station the camera cannot serve
	# would be gating the lot on something no layout can pass.
	await _station(Vector2(HubTransport.SKATE_PARK.x, HubTransport.SKATE_PARK.z))
	var visible_here: int = 0
	for i in nodes.size():
		for n in nodes:
			n.material_override = null
		nodes[i].material_override = mask
		if await _count_magenta() > 0:
			visible_here += 1
	for n in nodes:
		n.material_override = null
	_check(visible_here >= 3,
		"P2 from the board's park (the riding vantage), %d of %d modules paint pixels at once -- a park, not a ramp in a field"
			% [visible_here, nodes.size()])
	print("")

# =====================================================================
# PHASE B -- WHAT THE PARK COSTS, per station, against that station's
# own noise floor.

func _phase_budget() -> void:
	print("-- PHASE B: the park's cost, gated per station against its own floor --")
	var nodes := _park.module_nodes()
	_check(not nodes.is_empty(),
		"B0 there IS something to hide -- CH40 read +64 primitives from an EMPTY list")
	print("     station        floor    with park   without    delta   verdict")
	for flat in STATIONS:
		await _station_frozen(flat)
		# The floor: repeat the read with NOTHING touched.
		var lo: int = 1 << 30
		var hi: int = 0
		for _r in REPEATS:
			for _i in SETTLE:
				await get_tree().process_frame
			var v := _prims()
			lo = mini(lo, v)
			hi = maxi(hi, v)
		var floor_px: int = hi - lo
		var with_park: int = _prims()
		var calls_with: int = _calls()
		for n in nodes:
			n.visible = false
		for _i in SETTLE:
			await get_tree().process_frame
		var without: int = _prims()
		var calls_without: int = _calls()
		for n in nodes:
			n.visible = true
		for _i in SETTLE:
			await get_tree().process_frame
		var delta: int = with_park - without
		var verdict: String = "measured" if delta > floor_px else "UNDER FLOOR (not a measurement)"
		print("     (%5.1f,%5.1f)  %6d   %8d   %7d  %+7d   calls %d/%d (%+d)   %s"
			% [flat.x, flat.y, floor_px, with_park, without, delta,
				calls_with, calls_without, calls_with - calls_without, verdict])
		# The gate is the CEILING, station by station: what the park adds
		# to a frame may never exceed what CH52 allowed for the whole park.
		_check(delta <= SkateparkMesh.BUDGET_TRIS,
			"B (%5.1f,%5.1f) park adds %d primitives <= ceiling %d"
				% [flat.x, flat.y, delta, SkateparkMesh.BUDGET_TRIS])
		# And the blind check for a PRESENCE claim (CH40): if hiding the
		# park changed nothing beyond the noise, this station is not
		# weighing the park at all and must say so rather than pass.
		if flat == WORST:
			_check(delta > floor_px,
				"B-blind at the worst frame the delta (%d) clears the station's own floor (%d)"
					% [delta, floor_px])
	print("     draw calls with park: %d" % _calls())
	print("")

# =====================================================================
# PHASE D -- THE NORTH CARPET CENSUS.
#
# ⚠️ THIS PHASE GATES NOTHING, AND THAT IS DELIBERATE. The grass guard
# removes instances at GENERATION time; no probe can put them back, so no
# single tree can measure what the thinning recovered. What this phase
# does is publish the exact census -- per batch, north instances and the
# triangles they carry -- so the SAME phase run on a reference tree
## subtracts to a recovery that is measured on both sides rather than
## estimated on one.
##
## CH52's 7 239 is NOT this number and must not be quoted as it: that
## figure halved every grass batch in the hub, including the carpet at
## the spawn.

func _phase_carpet() -> void:
	print("-- PHASE D: the north grass census (publishes; gates nothing) --")
	var published: Array = []
	if _scatter.has_method("batch_nodes"):
		published = _scatter.call("batch_nodes")
	_check(not published.is_empty(), "D0 CozyScatter published its batch list")
	var batches: int = 0
	var total_inst: int = 0
	var north_inst: int = 0
	var north_tris: int = 0
	for nm in published:
		if not String(nm).begins_with("grass"):
			continue
		var node := _scatter.get_node_or_null(String(nm)) as MultiMeshInstance3D
		if node == null or node.multimesh == null or node.multimesh.mesh == null:
			continue
		batches += 1
		var mm := node.multimesh
		var per: int = mm.mesh.get_faces().size() / 3
		total_inst += mm.instance_count
		for k in mm.instance_count:
			# ⚠️ READ THE TRANSFORM, do not trust the batch's name. Under
			# the dummy driver every one of these comes back as the
			# IDENTITY (CH50's false green) -- PHASE I is what makes this
			# loop worth running at all.
			var origin := node.global_transform * mm.get_instance_transform(k).origin
			if origin.z >= CozyScatter.NORTH_KEEP_FROM_Z:
				north_inst += 1
				north_tris += per
	print("     %d grass batches, %d instances total" % [batches, total_inst])
	print("     NORTH of z = %.1f: %d instances, %d triangles"
		% [CozyScatter.NORTH_KEEP_FROM_Z, north_inst, north_tris])
	print("     park costs %d triangles; the reference tree's north census minus" % _park.triangle_total())
	print("     this one is what the guard gave back -- see the lot's cross-tree table.")
	# The one thing a single tree CAN assert: the guard is not a no-op in
	# the sense of never being reached. If no grass exists north of the
	# line at all, the guard is defending nothing and the whole financing
	# argument is empty.
	_check(north_inst > 0,
		"D1 there IS a north carpet for the guard to thin (%d instances)" % north_inst)
	print("")

# =====================================================================
# PHASE F -- FRAMING, by unproject on the delivered camera.
#
# CLAUDE.md: the hub camera is KEEP_WIDTH with fov 45 (a HORIZONTAL 45,
# half-angle 22.5) on a 1080x1920 surface, it never yaws and never
# approaches. A prop more than ~3 u to the side of Keepy at his own z is
# NOT on screen. A site chosen on ground clearance alone came out at
# x = 1316 on a 1080-wide canvas and nothing said so.

func _phase_framing() -> void:
	print("-- PHASE F: is the park IN THE PICTURE from where a player stands --")
	# Four stations down the riding line, north to south, plus the
	# plateau-side walk-in kept in the PRINT (not in the gate) so the
	# accepted compromise is a published number rather than a claim.
	var posts: Array[Vector2] = [
		Vector2(HubTransport.SKATE_PARK.x, HubTransport.SKATE_PARK.z),
		Vector2(HubSkatepark.PARK_CENTRE.x, HubSkatepark.PARK_CENTRE.y + 8.0),
		Vector2(HubSkatepark.PARK_CENTRE.x, HubSkatepark.PARK_CENTRE.y + 2.0),
		Vector2(0.0, 42.0)]
	# The band, and it is the 1080 one and not the canvas: in headless the
	# canvas is wider and everything "fits" (the kart panel shipped
	# clipped for exactly that reason).
	var band_lo: float = float(VP_SIZE.x) * 0.0
	var band_hi: float = float(VP_SIZE.x)
	for post in posts:
		await _station(post)
		var on_screen: int = 0
		var line: String = ""
		for i in _park.module_count():
			var c := _park.module_centre(i)
			var top := c + Vector3(0.0, float(HubSkatepark.MODULES[i]["size"].y), 0.0)
			if _camera.is_position_behind(top):
				line += "  m%d:behind" % i
				continue
			var s := _camera.unproject_position(top)
			var inside: bool = s.x >= band_lo and s.x <= band_hi and s.y >= 0.0 and s.y <= float(VP_SIZE.y)
			if inside:
				on_screen += 1
			line += "  m%d:(%.0f,%.0f)%s" % [i, s.x, s.y, "" if inside else "*OUT*"]
		print("     from (%.1f, %.1f): %d in frame%s" % [post.x, post.y, on_screen, line])
		if post.y <= 42.5:
			print("        (plateau-side walk-in: PUBLISHED, not gated -- CH51's accepted compromise)")
			continue
		_check(on_screen >= 3,
			"F from (%.1f, %.1f) %d of %d modules are inside the 1080 band"
				% [post.x, post.y, on_screen, _park.module_count()])
	# The height question CH51 left open, answered by the frame rather
	# than by argument: the tallest module's crown from the closest post.
	await _station(Vector2(HubSkatepark.PARK_CENTRE.x, HubSkatepark.PARK_CENTRE.y + 2.0))
	var tallest: int = 0
	for i in _park.module_count():
		if float(HubSkatepark.MODULES[i]["size"].y) > float(HubSkatepark.MODULES[tallest]["size"].y):
			tallest = i
	var crown := _park.module_centre(tallest) + Vector3(0.0, float(HubSkatepark.MODULES[tallest]["size"].y), 0.0)
	var sp := _camera.unproject_position(crown)
	print("     tallest module (%d, %.2f u) crowns at y = %.0f px of %d"
		% [tallest, float(HubSkatepark.MODULES[tallest]["size"].y), sp.y, VP_SIZE.y])
	_check(sp.y > 0.0,
		"F2 the tallest module's crown is BELOW the top of the frame (%.0f px)" % sp.y)
	print("")

# =====================================================================
# PHASE H -- THE HUD's two gates.

func _phase_hud() -> void:
	print("-- PHASE H: the HUD's rect and its mouse_filter --")
	_check(_hud != null, "H0 the SkateHud node exists in the scene")
	if _hud == null:
		return
	# Make it show something: the rect only exists once the panel has been
	# laid out, and a probe that measured a hidden panel would measure a
	# zero.
	_hud.visible = true
	_hud._on_trick_scored(0, &"air", 60, 1)
	for _i in 4:
		await get_tree().process_frame
	var rect := _hud.panel_rect()
	var canvas: float = _hud.size.x
	var band_lo: float = canvas * 0.5 - 540.0
	var band_hi: float = canvas * 0.5 + 540.0
	print("     canvas %.0f px wide; band [%.0f, %.0f]; panel x %.0f -> %.0f, w %.0f"
		% [canvas, band_lo, band_hi, rect.position.x, rect.end.x, rect.size.x])
	_check(rect.size.x > 0.0 and rect.size.y > 0.0, "H1 the panel has a real size")
	_check(rect.position.x >= band_lo and rect.end.x <= band_hi,
		"H2 the panel is inside the 1080-wide band centred on the canvas middle")
	_check(_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"H3 the HUD root passes taps through (default is STOP, and STOP eats every tap)")
	var stoppers: int = 0
	for child in _hud.find_children("*", "Control", true, false):
		if (child as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			stoppers += 1
			print("     ** %s is at MOUSE_FILTER_STOP" % child.name)
	_check(stoppers == 0, "H4 no child of the HUD stops a tap (%d do)" % stoppers)
	print("")
