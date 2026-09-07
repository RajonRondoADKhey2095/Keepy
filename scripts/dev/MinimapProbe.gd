extends Node
## CH46 -- THE MINIMAP'S CONTRACT, AND EVERY ASSERTION IN IT IS PIXEL-BACKED
## WHERE THE THING IT GUARDS IS VISUAL.
##
## =====================================================================
## WHY IT RENDERS INSTEAD OF COUNTING NODES
##
## CH39/CH40 doctrine: a counter counts what was SUBMITTED, not what was
## DRAWN. A minimap that exists in the tree, carries the right groups, has
## the right rect and draws nothing at all would pass every structural
## assertion anyone would think to write. So the widget is READ BACK OFF
## THE SCREEN: the marker phases compare rendered pixels against the tone
## the marker is supposed to be, the boundary phase finds the colour jump
## in a rendered column and converts it back to a world z, and the route
## phase samples the circuit's own ideal_line against the pixels under it.
##
## Runs under xvfb + opengl3. NOT under --headless: the dummy driver
## renders nothing, reports a 0x0 viewport, and every pixel assertion
## below would pass by never executing.
##
## =====================================================================
## THE BLIND CHECKS, AND WHY EACH ONE IS THERE
##
## Three of the phases assert an ABSENCE or an EQUALITY, which CLAUDE.md
## says passes gratis against a mechanism that was never wired:
##
##  * PHASE D pairs every "this marker is its kind's colour" with "a patch
##    of plan 20 px away is NOT that colour" -- so the tone test is known
##    to be capable of saying no.
##  * PHASE E pairs "a tap through the minimap reaches _unhandled_input"
##    with the SAME tap after the widget is flipped to MOUSE_FILTER_STOP,
##    which must NOT arrive. Without that pair, "the tap arrived" would
##    also pass on a build where the widget was never in front of it.
##  * PHASE F pairs "the circuit's line is under the circuit's samples"
##    with "5 px off the line it is not", because "the map is bright in
##    the circuit band" is true of the lawn as well.
const VP_SIZE: Vector2i = Vector2i(1080, 1920)
const SWEEP_STEP: float = 0.5
## How close a rendered pixel must be to the tone it should be. The marker
## core is opaque (alpha 1 in the atlas), so the answer is the tone itself
## and this is a tolerance on the renderer, not on a blend.
const TONE_EPS: float = 0.04
## A colour jump big enough to be a painted band boundary. The plan is
## drawn at alpha 0.92, so the 3D scene behind it can move a channel by at
## most 0.08; the smallest gap between two adjacent band tones is 0.16
## (moor mauve to circuit lawn, blue channel 0.76 -> 0.40 is far larger;
## the tightest is grass green 0.78 to autumn 0.54). Threshold sits above
## the first and below the second.
const JUMP_EPS: float = 0.10
## Where each painted hedge is CROSSED BY A CORRIDOR, which is the only x
## at which that boundary is inside the walkable region at all -- and so
## the only x at which the map can be asked to draw it.
const EDGE_COLUMNS: Array[float] = [-28.0, 12.0, -8.0]
## What the plan fills with on either side of each painted hedge, in the
## ground shader's own mixing order (grass, autumn, moor, circuit lawn).
const BAND_BEFORE: Array[Color] = [CozyPalette.GRASS_A, CozyPalette.AUTUMN_A, CozyPalette.MOOR_A]
const BAND_AFTER: Array[Color] = [CozyPalette.AUTUMN_A, CozyPalette.MOOR_A, CozyPalette.LAWN_A]

var _hub: Node = null
var _map: HubMinimap = null
var _checks: int = 0
var _red: int = 0
var _unhandled_seen: int = 0
var _fired: PackedStringArray = []

class TapSentinel extends Node:
	var probe: Node = null
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch or event is InputEventMouseButton:
			probe._unhandled_seen += 1

func _ready() -> void:
	ProbeWatchdog.arm(self, "MINIMAP PROBE")
	_hub = (preload("res://scenes/HubWorld.tscn") as PackedScene).instantiate()
	add_child(_hub)
	_run()

func _check(ok: bool, text: String) -> void:
	_checks += 1
	if not ok:
		_red += 1
	print("  [%s] %s" % ["OK " if ok else "RED", text])

func _run() -> void:
	await get_tree().process_frame
	var box := _hub.get_node("WorldViewport") as SubViewportContainer
	var vp := _hub.get_node("WorldViewport/SubViewport") as SubViewport
	box.stretch = false
	vp.size = VP_SIZE
	(_hub.get_node("WorldViewport/SubViewport/World/CozyWeather") as Node).call("force", 0)
	_map = _hub.get_node("Minimap") as HubMinimap
	for _i in 24:
		await get_tree().process_frame

	print("=== MINIMAP PROBE (CH46) ===")
	await _phase_viewport()
	_phase_frame()
	_phase_groups()
	_phase_layout()
	await _phase_markers()
	await _phase_clamp()
	await _phase_edges()
	await _phase_route()
	await _phase_tap()

	print("")
	print("=== %d checks, %d red ===" % [_checks, _red])
	print("ALL GREEN" if _red == 0 else "FAILED")
	get_tree().quit(0 if _red == 0 else 1)

## PHASE 0 -- the surface is real. Everything below is a lie without it.
func _phase_viewport() -> void:
	print("-- PHASE 0: the render surface --")
	var rect: Vector2 = get_viewport().get_visible_rect().size
	_check(rect.x > 0.0 and rect.y > 0.0, "root viewport is not degenerate: %s" % rect)
	var img: Image = await _shot()
	_check(img != null and img.get_width() > 0, "a frame reads back (%d x %d)"
		% [0 if img == null else img.get_width(), 0 if img == null else img.get_height()])
	var mid: Color = img.get_pixel(int(rect.x / 2.0), int(rect.y / 3.0))
	_check(mid.r + mid.g + mid.b > 0.05,
		"the 3D scene is actually shaded, not the dummy driver's black (%.3f, %.3f, %.3f)"
			% [mid.r, mid.g, mid.b])

## PHASE 1 -- the frame. HubRegion.walkable_bounds() is a SECOND SPELLING of
## contains(), so it is swept against contains() and required to be TIGHT --
## a box that merely contains the region passes gratis when a union term is
## forgotten, which is exactly the failure this accessor can have.
func _phase_frame() -> void:
	print("-- PHASE 1: the frame is the walkable world, tight on four sides --")
	var box: Rect2 = HubRegion.walkable_bounds()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var x: float = box.position.x - 4.0
	while x <= box.end.x + 4.0:
		var z: float = box.position.y - 4.0
		while z <= box.end.y + 4.0:
			if HubRegion.contains(Vector3(x, 0.0, z)):
				lo = Vector2(minf(lo.x, x), minf(lo.y, z))
				hi = Vector2(maxf(hi.x, x), maxf(hi.y, z))
			z += SWEEP_STEP
		x += SWEEP_STEP
	print("   swept  x[%.1f, %.1f]  z[%.1f, %.1f]   published x[%.1f, %.1f] z[%.1f, %.1f]"
		% [lo.x, hi.x, lo.y, hi.y, box.position.x, box.end.x, box.position.y, box.end.y])
	_check(lo.x >= box.position.x and hi.x <= box.end.x and lo.y >= box.position.y and hi.y <= box.end.y,
		"every point contains() admits is inside the published box")
	_check(absf(lo.x - box.position.x) <= SWEEP_STEP and absf(hi.x - box.end.x) <= SWEEP_STEP
			and absf(lo.y - box.position.y) <= SWEEP_STEP and absf(hi.y - box.end.y) <= SWEEP_STEP,
		"the box is TIGHT on all four sides (no slack beyond one sweep step)")
	_check(_map.frame() == box, "the widget frames exactly that box, not a restated one")
	_check(absf(box.size.x - 137.0) < 1.0e-4 and absf(box.size.y - 247.0) < 1.0e-4,
		"the frame is the walkable 137 x 247, not the 219 x 247 all-vehicle frame (%.1f x %.1f)"
			% [box.size.x, box.size.y])

## PHASE 2 -- the groups ARE the interface. No path is cited anywhere.
func _phase_groups() -> void:
	print("-- PHASE 2: the groups, enumerated --")
	var total: int = 0
	for group in MinimapMarkers.KINDS:
		var nodes: Array[Node3D] = _map.members(group)
		total += nodes.size()
		var names: PackedStringArray = []
		for n in nodes:
			names.append(n.get_class() if n.name.begins_with("@") else str(n.name))
		print("   %-17s %2d : %s" % [group, nodes.size(), ", ".join(names)])
		_check(not nodes.is_empty(), "group '%s' is not empty" % group)
	_check(total >= 30, "the map draws %d markers" % total)
	var route: Array = get_tree().get_nodes_in_group(MinimapMarkers.ROUTE)
	_check(route.size() == 1, "exactly one route joined the map (%d)" % route.size())
	_check(route.size() == 1 and route[0].has_method("ideal_line"),
		"the route publishes ideal_line(), which is how the map asks -- never by class")
	# CH44's own warning, gated: the bear and the badger have no stable name,
	# so the ONLY thing that can find them is the group they are in.
	var walkers: int = 0
	for n in _map.members(MinimapMarkers.NPC):
		if n is HubActorWalker:
			walkers += 1
	_check(walkers == 2, "both nameless HubActorWalkers (bear, badger) are on the map (%d)" % walkers)

## PHASE 3 -- where it sits, and the one property that makes it harmless.
func _phase_layout() -> void:
	print("-- PHASE 3: the rect and the filter --")
	_check(_map.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"mouse_filter is IGNORE (%d)" % _map.mouse_filter)
	var r := Rect2(_map.global_position, _map.size)
	print("   rect %s" % r)
	# CLAUDE.md: gate against the 1080-wide band, never the headless canvas.
	_check(r.position.x >= 0.0 and r.end.x <= 1080.0,
		"the widget is inside the 1080-wide band (%.0f .. %.0f)" % [r.position.x, r.end.x])
	var screen_h: float = get_viewport().get_visible_rect().size.y
	_check(r.position.y > screen_h * 0.5,
		"it sits in the free bottom half of the screen (top at %.0f of %.0f)" % [r.position.y, screen_h])
	# The notch band is 141 device px at the TOP and SafeArea exposes no
	# inset (CH44 axe 4). The only defence available is distance from that
	# edge, so it is asserted rather than assumed.
	_check(r.position.y > 200.0, "it is nowhere near the notch band (top at %.0f)" % r.position.y)
	_check(absf(r.size.x / r.size.y - _map.frame().size.x / _map.frame().size.y) < 0.01,
		"the widget's aspect is the world frame's -- the plan is not stretched")

## PHASE 4 -- THE PIXELS. A marker is its kind's colour, at its own place.
func _phase_markers() -> void:
	print("-- PHASE 4: markers, read off the screen --")
	var img: Image = await _shot()
	var origin: Vector2 = _map.global_position
	# ⚠️ THE WIDGET'S OWN DRAW ORDER, read from it rather than restated. The
	# first run of this phase restated it in a different order and reported
	# three balloon docks as unpainted: a balloon parks ON dock 0, so its
	# marker covers the dock's -- an occlusion, not a miss. A probe that
	# spells the order out a second time is a probe that can disagree with
	# the thing it measures.
	var pairs: Array = []
	for kind in HubMinimap.DRAW_ORDER:
		pairs.append([kind, HubMinimap.tone_of(kind), String(kind).replace("minimap_", "")])
	# Everything on the plan, so a marker sitting under a later-drawn one is
	# excluded rather than counted as a miss -- overlap is a fact of the map,
	# not a defect, and a test that ignored it would gate on luck.
	# ⚠️ OCCLUSION IS ORDERED, and reading it as "anything within an icon of
	# me" was wrong in both directions on the first run: it excluded the
	# PLAYER (three portals sit 6 px away) even though the player is drawn
	# LAST and can never be covered, leaving that group with nothing tested
	# at all -- 0/0 passing an "all of them" test is the emptiest kind of
	# green. Only a marker drawn AFTER this one can hide it.
	var order: Array = []
	var misses: PackedStringArray = []
	for k in pairs.size():
		var list: Array[Node3D] = _map.members(pairs[k][0] as StringName)
		for i in list.size():
			order.append({"k": k, "i": i, "at": (_map.project(list[i].global_position)["at"] as Vector2)})
	for k in pairs.size():
		var group: StringName = pairs[k][0]
		var tone: Color = pairs[k][1]
		var hit: int = 0
		var tried: int = 0
		var list: Array[Node3D] = _map.members(group)
		for i in list.size():
			var at: Vector2 = _map.project(list[i].global_position)["at"]
			var covered: bool = false
			for other in order:
				var later: bool = int(other["k"]) > k or (int(other["k"]) == k and int(other["i"]) > i)
				if later and (other["at"] as Vector2).distance_to(at) < float(HubMinimap.ICON_PX):
					covered = true
			if covered:
				continue
			tried += 1
			var got: Color = img.get_pixelv(Vector2i(origin + at))
			if _near(got, tone, TONE_EPS):
				hit += 1
			else:
				misses.append("%s at %s reads (%.3f, %.3f, %.3f)"
					% [list[i].name, at, got.r, got.g, got.b])
		print("   %-17s %d/%d unoccluded markers render in their own tone" % [pairs[k][2], hit, tried])
		for m in misses:
			print("      MISS %s" % m)
		misses.clear()
		_check(tried > 0, "at least one %s marker is drawn by nothing else (%d)" % [pairs[k][2], tried])
		_check(tried > 0 and hit == tried, "every unoccluded %s marker is drawn, in %s" % [pairs[k][2], tone])
	var all: Array[Vector2] = []
	for entry in order:
		all.append(entry["at"] as Vector2)
	# ⚠️ BLIND. "The pixel is the tone" passes gratis if the whole plan
	# happened to be that tone. Points 20 px from every marker must NOT be.
	var false_hits: int = 0
	var probed: int = 0
	for py in range(10, int(_map.size.y) - 10, 17):
		for px in range(10, int(_map.size.x) - 10, 13):
			var here := Vector2(float(px), float(py))
			var clear: bool = true
			for other in all:
				if other.distance_to(here) < 20.0:
					clear = false
			if not clear:
				continue
			probed += 1
			for pair in pairs:
				if _near(img.get_pixelv(Vector2i(origin + here)), pair[1] as Color, TONE_EPS):
					false_hits += 1
	print("   blind: %d empty plan samples, %d of them read as a marker tone" % [probed, false_hits])
	_check(probed > 40, "the blind sweep actually sampled the plan (%d points)" % probed)
	_check(false_hits == 0, "no empty patch of plan reads as a marker tone")

## PHASE 5 -- GTA CLAMPING. Nothing leaves the map silently, and a clamped
## marker SAYS it is clamped by changing shape.
func _phase_clamp() -> void:
	print("-- PHASE 5: the sailboat pushed out to sea --")
	var transport: Node = _hub.get_node("WorldViewport/SubViewport/World/Transport")
	var boat: SailBoat = transport.call("sailboat")
	var home: Vector3 = boat.global_position
	# In frame first: the flag must be capable of reading false, or "it is
	# clamped" below would be true of every point on the map.
	_check(not bool(_map.project(home)["clamped"]),
		"moored at %s the sailboat is NOT clamped -- the flag can read false" % home)
	boat.place(Vector3(150.0, 0.0, -110.0), PI / 2.0)
	for _i in 4:
		await get_tree().process_frame
	var shot: Dictionary = _map.project(boat.global_position)
	var at: Vector2 = shot["at"]
	_check(bool(shot["clamped"]), "82 u past the frame it IS clamped (x %.1f)" % boat.global_position.x)
	_check(at.x >= _map.size.x - float(HubMinimap.ICON_PX), "it is pinned to the east border (x %.1f px of %.0f)"
		% [at.x, _map.size.x])
	_check(at.x <= _map.size.x - float(HubMinimap.ICON_PX) * 0.5 + 0.01,
		"and fully inside the widget -- a clamped marker is drawn whole, not half-cut")
	var img: Image = await _shot()
	var origin: Vector2 = _map.global_position
	_check(_near(img.get_pixelv(Vector2i(origin + at)), HubMinimap.VEHICLE_TONE, TONE_EPS),
		"it still renders in the vehicle tone -- clamping changes the SHAPE, never the kind")
	# THE SHAPE, FROM PIXELS -- and by COVERAGE, not by an exact tone. The
	# first run read 1 corner of 4 and it was the test that was wrong: at
	# (+-3, +-3) the square's own antialiasing puts the nearest texel at
	# L-infinity 3.5, which is inside its 3.7 fill but only 70 % covered, so
	# "is this pixel exactly the tone" says no to a pixel that is plainly
	# filled. What separates the two icons is not the tone, it is how much
	# of it is there: a disc of radius 3.9 has NOTHING at that offset (its
	# distance is 4.95), so it reads as the black outline.
	var square_fill: float = _corner_fill(img, origin + at, HubMinimap.VEHICLE_TONE)
	print("   clamped icon: corner fill %.3f of the tone" % square_fill)
	_check(square_fill > 0.50, "its four diagonal corners are filled: this is the SQUARE icon (%.3f)" % square_fill)
	# ⚠️ BLIND, and it is the whole point of the corner test: the same four
	# offsets on an IN-FRAME vehicle must be EMPTY, or "the corners are
	# filled" would be true of every icon in the atlas.
	boat.place(home, PI / 2.0)
	for _i in 4:
		await get_tree().process_frame
	img = await _shot()
	var round_at: Vector2 = _map.project(boat.global_position)["at"]
	var round_fill: float = _corner_fill(img, origin + round_at, HubMinimap.VEHICLE_TONE)
	print("   in-frame icon: corner fill %.3f of the tone" % round_fill)
	_check(round_fill < 0.30, "back in frame the same four offsets are EMPTY (%.3f): a DOT" % round_fill)
	_check(square_fill - round_fill > 0.30,
		"the two shapes are separated by %.3f, well clear of the renderer's noise" % (square_fill - round_fill))

## PHASE 6 -- decision 4, gated: the boundaries drawn are the PAINTED ones.
func _phase_edges() -> void:
	print("-- PHASE 6: the boundaries are CozyPalette's, not HubRegion's --")
	# ⚠️ THE MARKERS ARE LIFTED OFF THE MAP FOR THIS READING, and it is not
	# a convenience. The first run read the circuit's hedge at z -134.28 --
	# the LOGICAL edge -- and it was neither the map nor the constant that
	# was wrong: the karting grid sits at x -9.9..-8.3, z -145..-138, and
	# the circuit's painted hedge is only reachable inside its own corridor
	# (x -14..-2, the only strip of region between z -134 and -126). Four
	# 14 px icons cover that entire strip, so there is no marker-free column
	# to read the boundary in at all. A marker is a colour jump too, and the
	# scan was finding a kart. What is under test here is the PLAN, so the
	# plan is what is rendered; the groups are put back below and the count
	# is asserted, so this phase cannot leave the world it borrowed.
	var lifted: Dictionary = {}
	for group in MinimapMarkers.KINDS:
		var list: Array[Node3D] = _map.members(group)
		lifted[group] = list
		for n in list:
			n.remove_from_group(group)
	for _i in 3:
		await get_tree().process_frame
	var img: Image = await _shot()
	var painted: Array[float] = [CozyPalette.AUTUMN_EDGE_Z, CozyPalette.MOOR_EDGE_Z, CozyPalette.CIRCUIT_EDGE_Z]
	var logical: Array[float] = [HubRegion.AUTUMN_MAX.y, HubRegion.MOOR_MAX.y, HubRegion.CIRCUIT_MAX.y]
	var names: Array[String] = ["autumn", "moor", "circuit"]
	var per_px: float = _map.frame().size.y / _map.size.y
	for i in painted.size():
		var world_x: float = EDGE_COLUMNS[i]
		var col_px: float = _map.project(Vector3(world_x, 0.0, painted[i]))["at"].x
		var row_px: float = _map.project(Vector3(world_x, 0.0, painted[i]))["at"].y
		# The lift above is only trustworthy if it actually emptied the plan
		# under the scan, so that is asserted rather than assumed.
		var clear: bool = true
		for group in MinimapMarkers.KINDS:
			for n in _map.members(group):
				var m: Vector2 = _map.project(n.global_position)["at"]
				if absf(m.x - col_px) < 10.0 and absf(m.y - row_px) < 14.0:
					clear = false
		_check(clear, "%s: the scan column at world x %.0f carries no marker" % [names[i], world_x])
		var best_row: int = -1
		var best: float = 0.0
		for dy in range(-6, 7):
			var y0: int = int(row_px) + dy
			var y1: int = y0 + 1
			var a: Color = img.get_pixelv(Vector2i(_map.global_position + Vector2(col_px, float(y0))))
			var b: Color = img.get_pixelv(Vector2i(_map.global_position + Vector2(col_px, float(y1))))
			var d: float = maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
			if d > best:
				best = d
				best_row = y0
		_check(best > JUMP_EPS, "%s: a colour jump of %.3f is in the column (> %.2f)" % [names[i], best, JUMP_EPS])
		if best_row < 0:
			continue
		# The jump lies between two pixel centres, so the boundary is their
		# midpoint -- half a pixel, not a whole one, of quantisation.
		var found_z: float = _row_to_z(float(best_row) + 0.5)
		var d_painted: float = absf(found_z - painted[i])
		var d_logical: float = absf(found_z - logical[i])
		print("   %-8s jump at z %.2f   painted %.1f (%.2f off)   logical %.1f (%.2f off)   %.3f u/px"
			% [names[i], found_z, painted[i], d_painted, logical[i], d_logical, per_px])
		_check(d_painted <= per_px * 1.5, "%s: the drawn boundary is the PAINTED z" % names[i])
		_check(d_painted < d_logical, "%s: and it is NOT the logical one" % names[i])
		# ⚠️ THE FILL, NOT ONLY THE STROKE -- AND THIS IS THE SEVENTEENTH
		# FALSE GREEN OF THIS REPO, FOUND BY THIS LOT'S OWN RED PASS.
		# Everything above reads the dark hedge LINE the bake strokes at
		# the painted z. Red pass R3 rewrote painted_tone() to mix its
		# BANDS on HubRegion's logical edges instead of CozyPalette's --
		# the very substitution decision 4 forbids -- and this phase came
		# back ALL GREEN, because the stroke was still where it always
		# was. A boundary is two things: a line, and the change of colour
		# it separates. Only the second one is what a player reads at a
		# glance, and it was ungated.
		var stroke_row: int = _map.project(Vector3(world_x, 0.0, painted[i]))["at"].y
		var below: Color = img.get_pixelv(_map.global_position + Vector2(col_px, float(stroke_row + 1)))
		var above: Color = img.get_pixelv(_map.global_position + Vector2(col_px, float(stroke_row - 1)))
		var new_tone: Color = BAND_AFTER[i]
		var old_tone: Color = BAND_BEFORE[i]
		_check(_closer(below, new_tone, old_tone),
			"%s: one row PAST the painted hedge the plan already fills with the new band" % names[i])
		# Its own blind: the row on the other side must still be the OLD
		# band, or "it is the new band" would be the answer everywhere.
		_check(_closer(above, old_tone, new_tone),
			"%s: and one row BEFORE it still fills with the old one" % names[i])
	for group in MinimapMarkers.KINDS:
		for n in (lifted[group] as Array[Node3D]):
			n.add_to_group(group)
	for _i in 2:
		await get_tree().process_frame
	var back: int = 0
	for group in MinimapMarkers.KINDS:
		back += _map.members(group).size()
		_check(_map.members(group).size() == (lifted[group] as Array[Node3D]).size(),
			"group '%s' is back to %d after the reading" % [group, (lifted[group] as Array[Node3D]).size()])
	print("   %d markers restored" % back)

## PHASE 7 -- the circuit is under its own ideal_line, and not beside it.
func _phase_route() -> void:
	print("-- PHASE 7: the karting circuit --")
	var route: Array = get_tree().get_nodes_in_group(MinimapMarkers.ROUTE)
	if route.is_empty():
		_check(false, "a route is in the group")
		return
	var track: Node3D = route[0]
	var line: Array = track.call("ideal_line")
	_check(line.size() > 100, "the spine has %d samples" % line.size())
	var origin: Vector2 = _map.global_position
	var img: Image = await _shot()
	var on: int = 0
	var off: int = 0
	var tested: int = 0
	for i in range(0, line.size(), 3):
		var here: Vector3 = track.global_transform * (line[i] as Vector3)
		var next: Vector3 = track.global_transform * (line[(i + 1) % line.size()] as Vector3)
		var a: Vector2 = _map.project(here)["at"]
		var b: Vector2 = _map.project(next)["at"]
		var tan: Vector2 = (b - a)
		if tan.length() < 0.001:
			continue
		var side: Vector2 = Vector2(-tan.y, tan.x).normalized() * 5.0
		tested += 1
		if _bright(img.get_pixelv(Vector2i(origin + a))):
			on += 1
		if _bright(img.get_pixelv(Vector2i(origin + a + side))):
			off += 1
	print("   %d samples: %d bright ON the line, %d bright 5 px BESIDE it" % [tested, on, off])
	_check(tested > 40, "the sweep ran (%d samples)" % tested)
	_check(float(on) / maxf(float(tested), 1.0) > 0.80, "the line is under its own samples (%.0f %%)"
		% (100.0 * float(on) / maxf(float(tested), 1.0)))
	# ⚠️ BLIND: the circuit's lawn is bright too. Without this, "the map is
	# pale where the track is" would be true of the whole zone.
	_check(float(off) / maxf(float(tested), 1.0) < 0.25, "and NOT 5 px beside it (%.0f %%)"
		% (100.0 * float(off) / maxf(float(tested), 1.0)))

## PHASE 8 -- the tap goes THROUGH. Proved with real events, both ways.
func _phase_tap() -> void:
	print("-- PHASE 8: the minimap never eats a tap --")
	var sentinel := TapSentinel.new()
	sentinel.probe = self
	# Last child of the hub, so it sees exactly what the two real consumers
	# (HubTapInput, KartTouchInput) see: whatever survives the GUI pick.
	_hub.add_child(sentinel)
	var tap: Node = _hub.get_node("TapInput")
	# ⚠️ EVERY TAP CHANNEL IS WATCHED, NOT tapped_ground ALONE. HubTapInput
	# obeys a one-tap-one-signal rule: a prop under the ray takes the event
	# INSTEAD of tapped_ground. The first run of this phase read 2 events
	# through the widget and 0 tapped_ground for nine different points, and
	# that pair of numbers says nothing at all about interception -- it says
	# the world under the bottom-left corner of this screen is not bare
	# ground. What the minimap must not do is stop the tap being a tap; the
	# channel it becomes is the world's business, not the map's.
	_fired.clear()
	var arms: Array[Dictionary] = []
	for sig in tap.get_signal_list():
		var sig_name: String = str(sig["name"])
		if not sig_name.begins_with("tapped_"):
			continue
		var n: int = (sig["args"] as Array).size()
		var call: Callable
		match n:
			1: call = func(_a) -> void: _fired.append(sig_name)
			2: call = func(_a, _b) -> void: _fired.append(sig_name)
			3: call = func(_a, _b, _c) -> void: _fired.append(sig_name)
			_: continue
		tap.connect(sig_name, call)
		arms.append({"name": sig_name, "call": call})
	_check(arms.size() >= 10, "every tap channel is armed (%d of them)" % arms.size())

	var spot: Vector2 = _map.global_position + _map.size * 0.5
	_unhandled_seen = 0
	await _touch(spot)
	var through: int = _unhandled_seen
	var channels: PackedStringArray = _fired.duplicate()
	print("   through the widget's centre: %d events, channels %s"
		% [through, "none" if channels.is_empty() else ", ".join(channels)])
	_check(through > 0, "a touch in the middle of the minimap reaches _unhandled_input (%d events)" % through)
	_check(not channels.is_empty(), "and HubTapInput turns it into a tap (%s)" % ", ".join(channels))

	# ⚠️ THE PAIR. Flip the widget to the Control DEFAULT and the same touch
	# must die on it. Without this, "the tap arrived" is also true of a
	# build where the minimap was never in front of the tap at all.
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_unhandled_seen = 0
	_fired.clear()
	await _touch(spot)
	_check(_unhandled_seen == 0 and _fired.is_empty(),
		"at MOUSE_FILTER_STOP the same touch is swallowed (%d events, %d channels) -- the test can see"
			% [_unhandled_seen, _fired.size()])
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# And once more, restored, so the phase does not leave the widget in the
	# state its own blind check needed.
	_unhandled_seen = 0
	_fired.clear()
	await _touch(spot)
	_check(_unhandled_seen > 0 and not _fired.is_empty(),
		"restored to IGNORE it passes again (%d events, %d channels)" % [_unhandled_seen, _fired.size()])
	for arm in arms:
		tap.disconnect(str(arm["name"]), arm["call"] as Callable)

## ---- helpers --------------------------------------------------------

func _touch(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = at
		ev.pressed = pressed
		get_viewport().push_input(ev)
		await get_tree().process_frame
	await get_tree().process_frame

func _shot() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

func _row_to_z(row: float) -> float:
	var f: Rect2 = _map.frame()
	return f.position.y + f.size.y - row / _map.size.y * f.size.y

## How much of the tone is present at the four diagonal offsets of a
## marker, as a fraction. The icon core is opaque over its own black
## outline, so a pixel reads back as coverage x tone and the ratio on the
## tone's strongest channel IS the coverage.
func _corner_fill(img: Image, centre: Vector2, tone: Color) -> float:
	var strongest: float = maxf(maxf(tone.r, tone.g), tone.b)
	var sum: float = 0.0
	for dx in [-3.0, 3.0]:
		for dy in [-3.0, 3.0]:
			var c: Color = img.get_pixelv(Vector2i(centre + Vector2(dx, dy)))
			var channel: float = c.r if strongest == tone.r else (c.g if strongest == tone.g else c.b)
			sum += clampf(channel / maxf(strongest, 0.001), 0.0, 1.0)
	return sum / 4.0

## Which of two palette tones a rendered pixel is: the plan is drawn at
## alpha 0.92, so the scene under it can move a channel by 0.08 while the
## nearest two band tones are 0.2 apart. Comparing DISTANCES rather than
## matching a tone absorbs that 0.08 on both sides at once.
func _closer(pixel: Color, want: Color, other: Color) -> bool:
	var d_want: float = Vector3(pixel.r - want.r, pixel.g - want.g, pixel.b - want.b).length()
	var d_other: float = Vector3(pixel.r - other.r, pixel.g - other.g, pixel.b - other.b).length()
	return d_want < d_other

func _near(a: Color, b: Color, eps: float) -> bool:
	return absf(a.r - b.r) <= eps and absf(a.g - b.g) <= eps and absf(a.b - b.b) <= eps

## Pale enough to be the circuit's line and not its lawn: the line renders
## at ~0.97 in every channel, the lawn's red channel at ~0.55.
func _bright(c: Color) -> bool:
	return minf(minf(c.r, c.g), c.b) > 0.75
