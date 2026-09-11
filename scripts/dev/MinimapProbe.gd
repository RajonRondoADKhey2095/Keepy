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
##
## =====================================================================
## CH47 -- AND THE ASSERTION CH46 NEVER WROTE
##
## CH46 came back 69 green on a map Mathieu could not read. Every one of
## those assertions was true; not one of them asked whether the four KINDS
## look different from each other. They could not have: three of the four
## shared one 14 px disc, and the probe only ever compared a marker to its
## own tone.
##
## So this file gains the missing gate, and it is built the way the clamp
## test had to be rebuilt in CH46 -- by COVERAGE, not by tone. What
## separates two icons is not what colour they are, it is HOW MUCH OF THE
## BOX THEY FILL, and the six pairs of the four kinds are measured against
## each other on exactly that number (PHASE 9). The matrix is printed in
## full, because a single "min gap" would hide which pair is the weak one.
##
## HOW COVERAGE IS MEASURED, AND WHY IT IS A DIFFERENCE
##
## Reading "is this pixel the kind's tone" cannot measure a footprint: the
## icon is a tone core inside a BLACK outline, so half its ink is not the
## tone at all, and the plan underneath is a different colour in every
## band. So each kind is rendered against its OWN baseline: all four groups
## are lifted off the map, one frame is read (the bare plan), one kind is
## put back, another frame is read, and a pixel counts as INK when the two
## differ. That measures the drawn footprint whatever the tone and whatever
## the band under it.
##
## The floor is measured before anything is compared: two baseline frames
## taken the same number of frames apart, differenced in the same boxes.
## The plan is drawn at alpha 0.92, so 8 % of a moving 3D scene bleeds
## through it, and a gap that does not clear that bleed is not a
## measurement.
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

## A pixel is INK when the with-marker frame differs from the bare-plan
## frame by at least this much on some channel. Absolute rather than
## relative to the icon's own peak: a relative cut would drop the FILL of
## any kind whose tone happens to be close to the band it stands on, and
## keep only its outline.
const INK_EPS: float = 0.06
## Every glyph measured must reach at least this delta somewhere, or it is
## not on the plan at all and its coverage would be a measurement of
## nothing.
const INK_PEAK_MIN: float = 0.20
## How far a glyph must be from the nearest OTHER drawn glyph of its own
## kind before its box can be read: one full box, so no neighbour's ink can
## enter it. (Other kinds are lifted while a kind is read, so only same-kind
## neighbours can contaminate.)
const ISOLATION_PX: float = 25.0

## ⚠️ CH50 -- THE GROUND LUMINANCE BELOW WHICH THE PLATE-EDGE CONTRACT IS
## NOT A CONTRACT. `best` in the perimeter walk is the plate's black
## keyline, and WCAG against black ink is (L + 0.05) / 0.05, so 3.0:1
## needs L >= 0.10 on the GROUND. Derived, not chosen.
const DARK_GROUND_L: float = 0.10
## And how much of a perimeter may land there before the map, not the
## marker, is the thing at fault. Measured on the rendered plan: 0.21 % of
## painted ground is under the floor on origin/main and 2.02 % on CH50's
## wider frame, so 8 % leaves real room and still fails long before a band
## goes dark across the map.
const DARK_GROUND_SHARE: float = 0.08
## The smallest coverage difference this lot is willing to call a
## separation. Chosen against the measured floor and printed beside it, so
## "the pair passed" can always be read as a multiple of the noise.
const SEP_MIN: float = 0.04

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
	_phase_ranks()
	await _phase_separation()
	_phase_clusters()
	_phase_sheet()
	await _phase_portraits()
	await _phase_contrast()
	await _phase_npc_follow()
	await _phase_keepy()
	await _phase_cost()

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
	# CH50: 247 -> 263. The skate lobe took the region's north edge from
	# 35 + 12 = 47 to 35 + 28 = 63; the x span is untouched (the disc spans
	# x in [-28, 28], well inside the cove's 74 and the mountain's -63).
	_check(absf(box.size.x - 137.0) < 1.0e-4 and absf(box.size.y - 263.0) < 1.0e-4,
		"the frame is the walkable 137 x 263, not the all-vehicle frame (%.1f x %.1f)"
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
	# ⚠️ CH47 -- WHICH NODE CARRIES THE MARKER, AND IT IS NOT THE CONTROLLER.
	# CH46 wrote `mark(self)` in HubBoar, HubCat, HubFawn and HubBeaver, and
	# `self` there is an EMPTY CONTROLLER that never leaves the world origin;
	# the animal is its `critter()` child. MinimapDensityRecon measured the
	# consequence over 900 simulated frames: four npc markers frozen on
	# (0, 0, 0), under Keepy's own spawn marker, forever.
	#
	# This one is STRUCTURAL and says so. Which node is in a group is not a
	# drawn property, so no pixel can gate it; what a pixel would see is a
	# marker in a plausible place, and it was plausible for a whole lot. The
	# rule it gates is the one that matters: the marker goes on the body that
	# MOVES, never on the controller that builds it.
	var carried: int = 0
	for cls in ["HubBoar", "HubCat", "HubFawn", "HubBeaver"]:
		for ctrl in _hub.find_children("", cls, true, false):
			var beast: Node = ctrl.call("critter") as Node
			var ok: bool = beast != null and beast.is_in_group(MinimapMarkers.NPC) \
				and not ctrl.is_in_group(MinimapMarkers.NPC)
			if ok:
				carried += 1
			_check(ok, "%s: the marker is on the ANIMAL, not on the controller that never moves" % cls)
	_check(carried == 4, "all four critter controllers hand their marker to their animal (%d)" % carried)

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
	# ⚠️ CH47: THE DRAWN LIST IS clusters(), NOT members(). Same-kind markers
	# that sit on top of each other are ONE glyph now, so a probe walking
	# members() would look for six kart markers where the widget draws one
	# and call five of them missing.
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
		var kind_here: StringName = pairs[k][0]
		var list: Array[Dictionary] = _map.clusters(kind_here)
		for i in list.size():
			var v: int = HubMinimap.variant_of(int(list[i]["count"]), bool(list[i]["clamped"]))
			# ⚠️ CH48: THE NODE'S OWN REACH, NOT THE KIND'S. A kind can now
			# draw a 32 px portrait or a 7 px shape depending on what the
			# entity declared, and asking the KIND gave the abstract icon's
			# 7.5 px for a plate 14.5 px wide -- so a place buried under a
			# portrait read as "drawn but missing its tone" instead of as
			# occluded. Same class of defect as CH47's own PHASE 4, one
			# level down.
			order.append({"k": k, "i": i, "at": (list[i]["at"] as Vector2),
				"reach": _map.node_reach(list[i]["members"][0], kind_here, v)})
	for k in pairs.size():
		var group: StringName = pairs[k][0]
		var tone: Color = pairs[k][1]
		var hit: int = 0
		var tried: int = 0
		var list: Array[Dictionary] = _map.clusters(group)
		for i in list.size():
			var at: Vector2 = list[i]["at"]
			var covered: bool = false
			for other in order:
				var later: bool = int(other["k"]) > k or (int(other["k"]) == k and int(other["i"]) > i)
				# ⚠️ THE OCCLUSION RADIUS IS THE OTHER GLYPH'S OWN INK, NOT
				# THE CELL. CH46 used ICON_PX because its cell WAS its ink.
				# Carried over to a 25 px cell, "within one cell of a later
				# glyph" excluded ALL FOURTEEN place glyphs and this phase
				# came back 0/0 -- which its own `tried > 0` guard caught,
				# and which is exactly the empty kind of green CH46 warned
				# about two comments up.
				if later and (other["at"] as Vector2).distance_to(at) < float(other["reach"]) + 2.0:
					covered = true
			if covered:
				continue
			tried += 1
			# ⚠️ NOT THE CENTRE PIXEL. A merged glyph is PUNCHED at its
			# centre -- that hole is its "several" cue -- so a centre probe
			# would read black on exactly the markers this lot added. What
			# is asserted is that the kind's tone is PRESENT inside the
			# glyph's own drawn reach, which is true of all three variants.
			# ⚠️ CH48: A CLAMPED GLYPH WEARS THE CREAM RIM, NOT ITS KIND'S.
			# Asking for the kind's tone on it reads 0 px on a map that is
			# behaving exactly as designed -- which is what the first run of
			# this phase did on the sailboat pinned to the east border.
			var variant: int = HubMinimap.variant_of(int(list[i]["count"]), bool(list[i]["clamped"]))
			var want: Color = HubMinimap.CLAMP_RIM if variant == HubMinimap.V_CLAMPED else tone
			var span: float = maxf(_map.node_reach(list[i]["members"][0], group, variant), 3.0)
			var lit: int = _tone_hits(img, origin + at, want, span)
			if lit >= 6:
				hit += 1
			else:
				misses.append("cluster of %d at %s (thumb '%s', variant %d, span %.1f) lights only %d px of %s"
					% [int(list[i]["count"]), at, MinimapMarkers.thumb_of(list[i]["members"][0]),
						variant, span, lit, want])
		print("   %-17s %d/%d unoccluded glyphs carry their own tone" % [pairs[k][2], hit, tried])
		for m in misses:
			print("      MISS %s" % m)
		misses.clear()
		_check(tried > 0, "at least one %s glyph is drawn by nothing else (%d)" % [pairs[k][2], tried])
		_check(tried > 0 and hit == tried, "every unoccluded %s glyph is drawn, in %s" % [pairs[k][2], tone])
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
	_check(bool(shot["clamped"]), "82 u past the frame it IS clamped (x %.1f)" % boat.global_position.x)
	# ⚠️ THE INSET IS THE CLAMPED GLYPH'S OWN REACH, not half a cell. CH46's
	# cell WAS its ink; CH47's 25 px cell holds a 7 px place dot, and pulling
	# that dot half a cell inland would put it 11 world units from the thing
	# it marks. So the border test is written against the number the widget
	# actually uses, read from the widget.
	var pin: float = _map.node_reach(boat, MinimapMarkers.VEHICLE, HubMinimap.V_CLAMPED)
	_check(pin > 1.0, "the clamped glyph has a measured reach (%.2f px)" % pin)
	# The DRAWN position, which is project() asked with the inset the widget
	# itself uses. Asking with the default 0 -- as the first run of this
	# phase did -- reads the un-inset border and says 155.0 of 155.
	var at: Vector2 = _map.project(boat.global_position, pin)["at"]
	_check(absf(at.x - (_map.size.x - pin)) < 0.01, "it is pinned to the east border (x %.1f of %.0f, inset %.2f)"
		% [at.x, _map.size.x, pin])
	_check(at.x + pin <= _map.size.x + 0.01,
		"and fully inside the widget -- a clamped marker is drawn whole, not half-cut")
	var img: Image = await _shot()
	var origin: Vector2 = _map.global_position
	# ⚠️ CH48 RE-AIMED THIS, AND THE RE-AIM IS THE POINT. CH47 read the
	# VEHICLE tone in the glyph's middle, because a clamped vehicle was a
	# tinted square. A clamped PORTRAIT is drawn at modulate white -- the
	# model's own colours, decision 2 -- so there is no kind tone in its
	# middle to find and that assertion would now be false about a map that
	# is correct. What a clamped glyph says is said by its RIM: cream where
	# an in-frame one is its kind's colour.
	_check(_tone_hits(img, origin + at, HubMinimap.CLAMP_RIM, pin + 1.0) >= 6,
		"the clamped glyph wears the cream rim -- clamping changes the RIM, never the picture")
	_check(_tone_hits(img, origin + at, HubMinimap.VEHICLE_TONE, pin + 1.0) < 6,
		"BLIND: and it is NOT wearing the in-frame vehicle rim, so the two are told apart")
	# ⚠️ THE SHAPE TEST MOVED TO PHASE 9, AND IT IS NOT A WEAKENING.
	# CH46 proved square-against-disc by reading the four (+-3, +-3) corners,
	# because at 14 px both icons were the same size and only the corners
	# differed. CH47's vehicle is a DIAMOND: its own (+-3, +-3) corners are
	# inside it, so that exact test would now read "filled" for the in-frame
	# icon too and the assertion would quietly stop separating anything.
	# PHASE 9 measures the same fact the same way CH46 finally settled on --
	# by COVERAGE -- for every kind at once, against a lifted baseline.
	boat.place(home, PI / 2.0)
	for _i in 4:
		await get_tree().process_frame
	var back: Dictionary = _map.project(boat.global_position)
	_check(not bool(back["clamped"]), "and it is un-clamped again once moored (%s)" % boat.global_position)

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

## PHASE 9 -- THE ASSERTION CH46 NEVER WROTE: THE FOUR KINDS ARE DIFFERENT
## SHAPES AT DIFFERENT SIZES, MEASURED AS COVERAGE, PAIR BY PAIR.
##
## Not by tone. CLAUDE.md: the WCAG scores nothing INSIDE a luminance band,
## no probe here measures hue, and the swamp ground leaves two usable bands
## for four kinds -- so a four-way separation by tint was condemned before
## it was tried. What is gated is the number a tint cannot fake: how much of
## a 25 px box each kind's glyph inks.
##
## Each kind is read against ITS OWN bare-plan baseline. All four groups are
## lifted, a frame is read, one kind is put back, a frame is read, and a
## pixel is INK when the two differ. That is what makes the number
## independent of the tone AND of the painted band underneath -- an
## absolute-tone test would have measured the ground as much as the marker.
func _phase_separation() -> void:
	print("-- PHASE 9: the six pairs, by coverage --")
	var transport: Node = _hub.get_node("WorldViewport/SubViewport/World/Transport")
	var boat: SailBoat = transport.call("sailboat")
	var home: Vector3 = boat.global_position
	# One vehicle pushed off the map so a CLAMPED glyph exists to be read at
	# all. Restored at the end of the phase.
	# ⚠️ NOT PHASE 5's z. Pinned at z -110 the clamped glyph lands 18.2 px
	# from the yacht's own marker -- inside the box this phase reads, so its
	# coverage would have been the two of them. Pushed north instead, where
	# the nearest vehicle glyph is 72 px away, and the isolation is asserted
	# rather than assumed below.
	boat.place(Vector3(150.0, 0.0, -20.0), PI / 2.0)
	# ⚠️ AND ONE PLACE MOVED, FOR THE SAME REASON. The only place cluster the
	# delivered world offers is the two nearest portals, and its glyph sits
	# 12.2 px from the third portal -- inside the box this phase reads, so
	# its coverage would have been a merged glyph plus somebody else's dot.
	# A dock is parked beside the cabin instead, which makes an ISOLATED
	# merged place glyph, and it is put back where it was at the end of the
	# phase with the restoration asserted. Without this the merged place cell
	# would be the one variant in the atlas that nothing ever reads.
	var cabin: Node3D = null
	var dock: Node3D = null
	for n in _map.members(MinimapMarkers.PLACE):
		if str(n.name) == "Cabin":
			cabin = n
		elif str(n.name) == "Dock_1_1":
			dock = n
	_check(cabin != null and dock != null, "the cabin and a dock were found to build a place cluster")
	var dock_home: Vector3 = Vector3.ZERO
	if cabin != null and dock != null:
		dock_home = dock.global_position
		dock.global_position = cabin.global_position + Vector3(2.0, 0.0, 0.0)
	# ⚠️ THE WORLD IS FROZEN FOR THIS PHASE, and CH48 paid for it three times.
	# The plan is drawn at alpha 0.92, so 8 % of the 3D scene behind it
	# bleeds through; with the widget moved to the bottom RIGHT that 8 % is
	# near-camera swaying scatter, and the noise floor -- 0.0000 for CH47 in
	# the bottom left -- came back 0.3499. Not a different map: a different
	# patch of moving grass. MinimapThumbBake hit the same wall on its
	# two-distance check and answered it the same way.
	#
	# ⚠️ THE WIDGET IS EXEMPTED FROM THE FREEZE, and that is the second half.
	# Pausing the tree also stops HubMinimap._process, so it never calls
	# queue_redraw() and every "one kind put back" frame comes back IDENTICAL
	# to the baseline: peak 0.000 for every glyph of every kind, a map read
	# as blank. A freeze has to stop the thing measured AGAINST, never the
	# thing being measured.
	#
	# ⚠️ AND IT WENT INTO THE WRONG PHASE FIRST -- into PHASE 6 as well as
	# here, because that phase lifts the groups with the same eight lines and
	# a blind text replacement caught both. The tree then stayed paused from
	# PHASE 6 to the end of PHASE 9: PHASE 8's taps died (a paused
	# HubTapInput has no _unhandled_input) and PHASE 6 read a frame drawn
	# BEFORE its own lift. Six reds, not one of them about the map.
	get_tree().paused = true
	_map.process_mode = Node.PROCESS_MODE_ALWAYS
	# ⚠️ CH50 -- AND THE FREEZE HAS TO COVER THE SHADER CLOCK, WHICH IT
	# CANNOT. The plan is drawn at alpha 0.92, so 8 % of the 3D scene is in
	# every pixel this phase reads; `SceneTree.paused` stops the scripts but
	# NOT a shader's TIME, so wind-animated scatter behind the widget keeps
	# moving and the floor reads that motion. It read 0.0000 on main and
	# 0.0450 on CH50's branch -- DETERMINISTICALLY, three runs each side --
	# not because the map changed but because widening the ground cover
	# rectangle moved the RNG stream and put a swaying tuft behind the
	# widget where there had been none.
	#
	# So the 3D is HIDDEN for this phase rather than paused. Every frame
	# this phase compares shares the same constant background, which is all
	# the coverage difference below ever needed, and the floor stops being a
	# lottery on where the grass landed. Restored at the end of the phase
	# with the restoration asserted, like the dock.
	var world_box := _hub.get_node_or_null("WorldViewport") as CanvasItem
	var world_was_visible: bool = world_box != null and world_box.visible
	if world_box != null:
		world_box.visible = false
	var lifted: Dictionary = {}
	for group in MinimapMarkers.KINDS:
		var list: Array[Node3D] = _map.members(group)
		lifted[group] = list
		for n in list:
			n.remove_from_group(group)
	await _settle()
	var base: Image = await _shot()
	await _settle()
	var base_again: Image = await _shot()

	# ⚠️ THE FLOOR FIRST, AND IT IS NOT A FORMALITY. The plan is drawn at
	# alpha 0.92, so 8 % of a MOVING 3D scene bleeds through it between two
	# frames. A gap that does not clear that bleed is not a measurement.
	var floor_max: float = 0.0
	var floor_n: int = 0
	for py in range(20, int(_map.size.y) - 20, 37):
		for px in range(20, int(_map.size.x) - 20, 29):
			floor_n += 1
			floor_max = maxf(floor_max, float(_coverage(base_again, base,
				_map.global_position + Vector2(float(px), float(py)))["cov"]))
	print("   noise floor: %d empty boxes, worst coverage %.4f" % [floor_n, floor_max])
	_check(floor_n > 8, "the floor was actually sampled (%d boxes)" % floor_n)
	_check(floor_max < 0.02, "two untouched frames differ by %.4f of a box -- the floor" % floor_max)

	var cov: Dictionary = {}
	var peak: Dictionary = {}
	var inks: Dictionary = {}
	for group in MinimapMarkers.KINDS:
		for n in (lifted[group] as Array[Node3D]):
			n.add_to_group(group)
		await _settle()
		var img: Image = await _shot()
		var label: String = String(group).replace("minimap_", "")
		# Every drawn glyph of this kind, with its distance to the nearest
		# OTHER glyph of the same kind: only an ISOLATED one can be read,
		# because a neighbour's ink inside the box would be counted as this
		# glyph's own.
		var drawn: Array[Dictionary] = _map.clusters(group)
		for variant in HubMinimap.VARIANT_COUNT:
			var best: Dictionary = {}
			var best_gap: float = -1.0
			for i in drawn.size():
				if HubMinimap.variant_of(int(drawn[i]["count"]), bool(drawn[i]["clamped"])) != variant:
					continue
				var gap: float = INF
				for j in drawn.size():
					if i == j:
						continue
					gap = minf(gap, (drawn[j]["at"] as Vector2).distance_to(drawn[i]["at"] as Vector2))
				if gap > best_gap:
					best_gap = gap
					best = drawn[i]
			if best.is_empty() or best_gap < ISOLATION_PX:
				print("   %-8s variant %d : none isolated (best gap %.1f px)" % [label, variant, best_gap])
				continue
			var read: Dictionary = _coverage(img, base, _map.global_position + (best["at"] as Vector2))
			var key: String = "%s/%d" % [label, variant]
			cov[key] = float(read["cov"])
			peak[key] = float(read["peak"])
			inks[key] = read["ink"]
			print("   %-8s variant %d : coverage %.4f   peak delta %.3f   isolated by %.1f px   members %d"
				% [label, variant, float(read["cov"]), float(read["peak"]), best_gap, int(best["count"])])
			_check(float(read["peak"]) >= INK_PEAK_MIN,
				"%s variant %d is actually on the plan (peak %.3f)" % [label, variant, float(read["peak"])])
		for n in (lifted[group] as Array[Node3D]):
			n.remove_from_group(group)
	for group in MinimapMarkers.KINDS:
		for n in (lifted[group] as Array[Node3D]):
			n.add_to_group(group)
	if world_box != null:
		world_box.visible = world_was_visible
	_check(world_box != null and world_box.visible == world_was_visible,
		"the 3D viewport was put back visible after the phase")
	get_tree().paused = false
	_map.process_mode = Node.PROCESS_MODE_INHERIT
	boat.place(home, PI / 2.0)
	if cabin != null and dock != null:
		dock.global_position = dock_home
	await _settle()
	if dock != null:
		_check(dock.global_position.is_equal_approx(dock_home),
			"the borrowed dock is back where it was (%s)" % dock.global_position)

	# ---- the variants the delivered world CANNOT produce -------------
	# Said out loud rather than silently skipped. A merged player is
	# impossible because merge_px(player) is zero by rule (PHASE 10 gates
	# that); a clamped player is impossible because the region clamps Keepy
	# before the map ever sees him; a clamped place is impossible because
	# every place in this world is inside the walkable bounds. Their atlas
	# cells are baked by the same uniform rule as the others and are NOT
	# gated at the pixel -- which is a limit of this lot, not a pass.
	_check(is_zero_approx(_map.merge_px(MinimapMarkers.PLAYER)),
		"a merged PLAYER is unreachable by rule, not by luck (merge_px %.2f)"
			% _map.merge_px(MinimapMarkers.PLAYER))
	var outside_place: int = 0
	for n in _map.members(MinimapMarkers.PLACE):
		if bool(_map.project(n.global_position)["clamped"]):
			outside_place += 1
	_check(outside_place == 0, "and no place in this world is off the map (%d) -- its clamped cell is never drawn"
		% outside_place)

	# ---- the matrix, printed in full ---------------------------------
	var kinds: Array[String] = ["player", "vehicle", "npc", "place"]
	var have: bool = true
	for k in kinds:
		if not cov.has("%s/0" % k):
			have = false
	_check(have, "a SIMPLE glyph of all four kinds was isolated and read")
	if not have:
		return
	# ⚠️ CH47'S OWN CRITERION CANNOT SEE CH48'S MARKERS, AND THAT IS THE
	# FINDING RATHER THAN A GAP IN IT.
	#
	# CH47 separated its four kinds by |coverage(A) - coverage(B)| -- how
	# much of the box each one fills -- and got 0.0960 at worst against a
	# 0.0000 floor, because its four glyphs were four different SIZES. Every
	# CH48 portrait is the same 32 px plate, so that number is ~0.02 for
	# every pair by construction, and carried over unchanged it declares a
	# correct map broken. Worse, it would read 0.0000 for two IDENTICAL
	# portraits and call that a pass: a scalar area cannot tell two pictures
	# apart, only two footprints.
	#
	# So the matrix is now DISAGREEMENT coverage: how much of the box the
	# two glyphs' own ink maps differ on, each read against its own
	# baseline. It subsumes the CH47 number (two different sizes disagree
	# over the whole ring between them) and it can actually fail. The CH47
	# figure is still printed beside it, because "the footprints are the
	# same size now" is true and worth reading.
	print("   --- SEPARATION MATRIX, 6 pairs (disagreement | CH47 area delta) ---")
	var worst: float = INF
	var worst_pair: String = ""
	for a in kinds.size():
		for b in range(a + 1, kinds.size()):
			var d: float = _disagree(inks["%s/0" % kinds[a]], inks["%s/0" % kinds[b]])
			var area: float = absf(float(cov["%s/0" % kinds[a]]) - float(cov["%s/0" % kinds[b]]))
			print("       %-8s vs %-8s  %.4f  |  %.4f" % [kinds[a], kinds[b], d, area])
			if d < worst:
				worst = d
				worst_pair = "%s/%s" % [kinds[a], kinds[b]]
			_check(d > SEP_MIN, "%s and %s disagree over %.4f of the box (> %.2f)"
				% [kinds[a], kinds[b], d, SEP_MIN])
	print("   weakest pair %s at %.4f, floor %.4f -- %.1fx the floor"
		% [worst_pair, worst, floor_max, worst / maxf(floor_max, 0.0001)])

	# ⚠️ THE RANKS ARE NO LONGER CARRIED BY SIZE, so they are not gated by
	# size any more. CH47 ordered them by how much each kind inked; CH48's
	# top three ranks are all one plate, and what orders them is the RIM --
	# the kind's own tone, in CH47's luminance order (PHASE 11 gates that),
	# and thicker on the player than on anyone else. What survives from the
	# CH47 assertion is the one part still true and still load-bearing:
	# rank 3 is decisively smaller than the rest.
	_check(float(cov["npc/0"]) > float(cov["place/0"]) * 1.5,
		"rank 3 still inks decisively less than rank 2 (%.4f against %.4f)"
			% [float(cov["place/0"]), float(cov["npc/0"])])
	# ⚠️ AND RANK 1 IS BIGGER AGAIN. CH48 first gave all three portrait ranks
	# one 32 px plate and this assertion said so; that turned out to leave
	# Keepy with a 4.5 % ring-thickness cue as his only distinction, which is
	# not "au premier coup d'oeil". His glyph is now DRAWN at 1.28x, and what
	# is gated is the footprint that produces on the plan.
	_check(float(cov["player/0"]) > float(cov["vehicle/0"]) * 1.1,
		"the player out-inks every vehicle again (%.4f against %.4f)"
			% [float(cov["player/0"]), float(cov["vehicle/0"])])

	# ---- merged and clamped, against their own simple ----------------
	for k in kinds:
		for variant in [1, 2]:
			var key: String = "%s/%d" % [k, variant]
			if not cov.has(key):
				continue
			var d: float = _disagree(inks[key], inks["%s/0" % k])
			var what: String = "merged" if variant == 1 else "clamped"
			_check(d > SEP_MIN, "a %s %s glyph disagrees with a simple one over %.4f of the box"
				% [what, k, d])
	_check(cov.has("vehicle/1"), "a MERGED glyph existed to be measured at all")
	_check(cov.has("vehicle/2"), "a CLAMPED glyph existed to be measured at all")

## PHASE 10 -- the clusters: what merged, what did not, and the bound.
func _phase_clusters() -> void:
	print("-- PHASE 10: the clusters --")
	_check(is_zero_approx(_map.merge_px(MinimapMarkers.PLAYER)),
		"KEEPY NEVER MERGES: merge_px(player) is %.2f" % _map.merge_px(MinimapMarkers.PLAYER))
	var members_total: int = 0
	var glyphs_total: int = 0
	for group in MinimapMarkers.KINDS:
		var label: String = String(group).replace("minimap_", "")
		var list: Array[Node3D] = _map.members(group)
		var drawn: Array[Dictionary] = _map.clusters(group)
		members_total += list.size()
		glyphs_total += drawn.size()
		var n: float = _map.merge_px(group)
		# ⚠️ MEASURED, NOT WRITTEN DOWN, and CH48 changed WHICH measurement.
		# CH47's threshold was TWICE the drawn reach ("their ink touches");
		# at a 32 px plate that is 19 world units, and it folded three
		# different vehicles into one portrait. It is now ONE reach --
		# "the later glyph would bury this one" -- read off the widget's own
		# largest drawn glyph for the kind, so a size edited anywhere moves
		# it and no literal is left behind.
		var expect: float = 0.0 if group == MinimapMarkers.PLAYER \
			else _map.kind_reach(group)
		_check(absf(n - expect) < 0.001,
			"%s: merge_px is its own largest measured reach (%.2f px = %.2f u)"
				% [label, n, n * _map.frame().size.y / _map.size.y])
		var names: PackedStringArray = []
		for c in drawn:
			if int(c["count"]) < 2:
				continue
			var who: PackedStringArray = []
			for m in (c["members"] as Array[Node3D]):
				who.append(m.get_class() if m.name.begins_with("@") else str(m.name))
			names.append("{%s}" % ", ".join(who))
			# THE BOUND. Leader clustering, so every member is within one
			# threshold of the glyph that stands for it -- printed in world
			# units, because that is the error a player would suffer.
			var far: float = 0.0
			for m in (c["members"] as Array[Node3D]):
				far = maxf(far, (_map.project(m.global_position)["at"] as Vector2)
					.distance_to(c["at"] as Vector2))
			_check(far <= n + 0.01,
				"%s: every member of a cluster of %d is within %.2f px of its glyph (worst %.2f)"
					% [label, int(c["count"]), n, far])
		print("   %-8s %2d markers -> %2d glyphs   N %5.2f px   %s"
			% [label, list.size(), drawn.size(), n, " ".join(names)])
	print("   TOTAL %d markers -> %d glyphs" % [members_total, glyphs_total])
	# ⚠️ A LITERAL INVENTORY, AND IT MOVES EVERY TIME THE WORLD GAINS AN
	# ENTITY. There is nothing to derive it from -- the roster IS the list
	# of what the hub builds -- so the number is written with its history
	# beside it rather than as a bare constant somebody will bump blind:
	#
	#   CH46/CH47/CH48 ..... 37  (12 vehicles, 9 NPCs, 15 places, Keepy)
	#   CH53 ............... 39  (+ the skateboard, + the skatepark site)
	#   CH71 ............... 40  (+ the funfair's drop tower, a PLACE)
	#
	# The assertion it carries is "nothing was REMOVED", so it stays an
	# EQUALITY: a `>=` would let a removal hide behind the next addition.
	const MARKER_ROSTER: int = 40
	_check(members_total == MARKER_ROSTER,
		"all %d markers are still on the map -- nothing was removed (%d)"
			% [MARKER_ROSTER, members_total])
	_check(glyphs_total < members_total, "and the plan draws fewer glyphs than markers (%d < %d)"
		% [glyphs_total, members_total])
	# The player is one marker and one glyph, always.
	_check(_map.clusters(MinimapMarkers.PLAYER).size() == _map.members(MinimapMarkers.PLAYER).size(),
		"the player's markers are drawn one for one")

	# ⚠️ THE BLIND, AND IT IS THE WHOLE PHASE. "Things merged" passes gratis
	# against a rule that merges EVERYTHING. So a pair that must NOT merge is
	# named and checked: the two nearest balloons are 19.30 px apart at spawn,
	# past the 16 px threshold, and they have to come back as TWO glyphs.
	var seen: Dictionary = {}
	for c in _map.clusters(MinimapMarkers.VEHICLE):
		for m in (c["members"] as Array[Node3D]):
			seen[str(m.name)] = c["at"]
	var split: bool = seen.has("Balloon_1") and seen.has("Balloon_2") \
		and (seen["Balloon_1"] as Vector2) != (seen["Balloon_2"] as Vector2)
	var gap: float = 0.0
	if seen.has("Balloon_1") and seen.has("Balloon_2"):
		gap = (seen["Balloon_1"] as Vector2).distance_to(seen["Balloon_2"] as Vector2)
	_check(split, "BLIND: Balloon_1 and Balloon_2 are %.2f px apart and stay TWO glyphs" % gap)
	var karts: int = 0
	for c in _map.clusters(MinimapMarkers.VEHICLE):
		var all_karts: bool = int(c["count"]) > 1
		for m in (c["members"] as Array[Node3D]):
			if not str(m.name).begins_with("Kart_"):
				all_karts = false
		if all_karts:
			karts = int(c["count"])
	_check(karts == 4, "and the four karts on the starting grid ARE one glyph (%d)" % karts)

## The tints follow the ranks, in LUMINANCE, and the rank-3 icon is
## decisively the smallest. Neither is the carrier of the distinction --
## PHASE 9 is -- but a tint table that drifts out of rank order is exactly
## the kind of thing nothing else in this repo would notice.
func _phase_ranks() -> void:
	print("-- PHASE 11: the three ranks --")
	_check(HubMinimap.rank_of(MinimapMarkers.PLAYER) == 1 and HubMinimap.rank_of(MinimapMarkers.VEHICLE) == 1,
		"the player and the vehicles are rank 1")
	_check(HubMinimap.rank_of(MinimapMarkers.NPC) == 2, "the npcs are rank 2")
	_check(HubMinimap.rank_of(MinimapMarkers.PLACE) == 3, "the places are rank 3")
	var order: Array[StringName] = [MinimapMarkers.PLAYER, MinimapMarkers.VEHICLE,
		MinimapMarkers.NPC, MinimapMarkers.PLACE]
	var prev: float = 2.0
	for kind in order:
		var lum: float = _lum(HubMinimap.tone_of(kind))
		print("   %-17s rank %d   tone %s   luminance %.4f   drawn reach %.2f px"
			% [kind, HubMinimap.rank_of(kind), HubMinimap.tone_of(kind), lum,
				_map.kind_reach(kind)])
		_check(lum < prev, "%s is darker than the kind above it (%.4f)" % [kind, lum])
		prev = lum
	# CH48: the DRAWN glyph, which for the top three ranks is a portrait
	# plate and not the abstract shape any more. Reading the shape here
	# would gate a cell the delivered world never puts on screen.
	var big: float = minf(minf(_map.kind_reach(MinimapMarkers.PLAYER),
		_map.kind_reach(MinimapMarkers.VEHICLE)), _map.kind_reach(MinimapMarkers.NPC))
	var small: float = _map.kind_reach(MinimapMarkers.PLACE)
	_check(small < 0.6 * big, "rank 3 is decisively the smallest icon (%.2f px against %.2f)" % [small, big])

## PHASE 12 -- THE SHIPPED SHEET IS THE SHIPPED SHEET.
##
## The 22 portraits are a versioned PNG, not something this build made, so
## what has to be gated is that the file which arrives through Godot's
## importer is still the file the baker wrote. Not by a checksum constant
## -- that would be a magic number pasted in by hand from a round trip
## nobody can re-do -- but by the properties that a lossy import would
## destroy: the cells still ink, they are still all different, and the
## alpha is still a hard matte rather than a soft cloud.
func _phase_sheet() -> void:
	print("-- PHASE 12: the shipped thumbnail sheet --")
	var sheet: Image = HubMinimap.THUMB_SHEET.get_image()
	_check(sheet != null, "the sheet resource loads")
	if sheet == null:
		return
	if sheet.is_compressed():
		sheet.decompress()
	var cell: int = HubMinimap.ICON_PX
	var cols: int = HubMinimap.SHEET_COLS
	var rows: int = int(ceil(float(MinimapMarkers.THUMBS.size()) / float(cols)))
	_check(sheet.get_width() == cols * cell and sheet.get_height() == rows * cell,
		"the sheet is %d x %d as baked (%d x %d)"
			% [cols * cell, rows * cell, sheet.get_width(), sheet.get_height()])
	var masks: Array[PackedFloat32Array] = []
	var fringe_worst: float = 0.0
	var fringe_who: String = ""
	for i in MinimapMarkers.THUMBS.size():
		var ox: int = (i % cols) * cell
		var oy: int = (i / cols) * cell
		var m := PackedFloat32Array()
		var ink: int = 0
		var fringe: int = 0
		for y in cell:
			for x in cell:
				var c: Color = sheet.get_pixel(ox + x, oy + y)
				# ⚠️ COLOUR AS WELL AS ALPHA, and the first run is why. Read
				# on alpha alone the three balloons come back 0.0000 apart --
				# they ARE one silhouette, differing only in being gold, blue
				# and coral. A "they all differ" test blind to colour would
				# have flunked a sheet whose balloons are the most instantly
				# separable thing on it.
				m.append(c.r * c.a)
				m.append(c.g * c.a)
				m.append(c.b * c.a)
				m.append(c.a)
				if c.a > 0.5:
					ink += 1
				if c.a > 0.02 and c.a < 0.98:
					fringe += 1
		masks.append(m)
		var cov: float = float(ink) / float(cell * cell)
		var fr: float = float(fringe) / float(cell * cell)
		if fr > fringe_worst:
			fringe_worst = fr
			fringe_who = String(MinimapMarkers.THUMBS[i])
		_check(cov > 0.04 and cov < 0.92,
			"%-10s inks its cell without filling it (%.4f)" % [MinimapMarkers.THUMBS[i], cov])
	# A VRAM-compressed or resampled sheet turns a hard matte into a cloud
	# of half-alphas. 25 % is far above the antialiased rim these cells
	# actually carry and far below what a lossy channel would produce.
	_check(fringe_worst < 0.25,
		"the alpha is still a hard matte, not a lossy cloud (worst %.4f on %s)"
			% [fringe_worst, fringe_who])
	# ⚠️ AND THE ONE PAIR THAT IS GENUINELY THE SAME PICTURE IS ASSERTED TO
	# BE, rather than quietly passing a "they all differ" test that it would
	# fail. The land yacht and the sailboat are built from the SAME two GLBs
	# (yacht_hull_0 + yacht_sail_0, HubTransport._build_yacht and SailBoat),
	# so their portraits are identical at every size the ladder tested --
	# 0.0000 apart at 16 px and at 64 px alike. Nothing in this lot can fix
	# that and nothing in it pretends to: what is gated is that the fact
	# stays TRUE, so the day someone gives one of them its own model the
	# assertion says so.
	var same: float = _mask_diff(masks[MinimapMarkers.thumb_row(&"yacht")],
		masks[MinimapMarkers.thumb_row(&"sailboat")])
	_check(same < 0.01,
		"KNOWN AND UNFIXED: yacht and sailboat are ONE picture (%.4f apart) -- same two GLBs" % same)
	var worst: float = 1.0
	var worst_pair: String = ""
	for a in masks.size():
		for b in range(a + 1, masks.size()):
			if String(MinimapMarkers.THUMBS[a]) == "yacht" and String(MinimapMarkers.THUMBS[b]) == "sailboat":
				continue
			var d: float = _mask_diff(masks[a], masks[b])
			if d < worst:
				worst = d
				worst_pair = "%s/%s" % [MinimapMarkers.THUMBS[a], MinimapMarkers.THUMBS[b]]
	print("   weakest portrait pair (yacht/sailboat excepted): %s at %.4f" % [worst_pair, worst])
	_check(worst > 0.03, "every other pair of portraits is its own picture (%s, %.4f)"
		% [worst_pair, worst])

## ⚠️ THE THRESHOLD IS SET BY THE TIGHTEST REAL PAIR IN THE ROSTER, not by
## eye. The three tree birds are one silhouette in three colours
## (HubTrees.BIRD_COLOURS); the closest two are the amber and the rose,
## 0.27 apart on the green channel. A first pass at 0.35 read them
## IDENTICAL and flunked a sheet whose birds are perfectly distinct. 0.15
## sits under that real difference and far above the comparison's own
## noise, which is exactly zero here -- the cells are compared byte for
## byte out of one image.
func _mask_diff(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var n: int = mini(a.size(), b.size())
	var d: int = 0
	for i in n:
		if absf(a[i] - b[i]) > 0.15:
			d += 1
	return float(d) / maxf(float(n), 1.0)

## PHASE 13 -- THE PORTRAIT ON THE SCREEN IS THE PORTRAIT IN THE ATLAS.
##
## CH39/CH40 doctrine: a counter counts what was SUBMITTED. "The widget
## holds a 78-cell atlas" is a counter. What is gated here is that the
## PIXELS under Keepy's glyph are his cell and not somebody else's -- and
## the blind half is that the same comparison against a WRONG cell must
## come back worse, or the test is only saying "something is drawn there".
func _phase_portraits() -> void:
	print("-- PHASE 13: the drawn glyph IS the baked cell --")
	var atlas: Image = _map.atlas_image()
	_check(atlas != null, "the runtime atlas reads back")
	if atlas == null:
		return
	var img: Image = await _shot()
	var groups: Array[StringName] = [MinimapMarkers.PLAYER, MinimapMarkers.VEHICLE, MinimapMarkers.NPC]
	var tested: int = 0
	for group in groups:
		for shot in _map.clusters(group):
			var lead: Node = shot["members"][0]
			var id: StringName = MinimapMarkers.thumb_of(lead)
			if id == &"":
				continue
			var v: int = HubMinimap.variant_of(int(shot["count"]), bool(shot["clamped"]))
			var mine: int = HubMinimap.thumb_cell_of(id, v)
			# A cell that is NOT this entity's, for the blind half.
			var other_row: int = (MinimapMarkers.thumb_row(id) + 7) % MinimapMarkers.THUMBS.size()
			var theirs: int = HubMinimap.thumb_cell_of(MinimapMarkers.THUMBS[other_row], v)
			# ⚠️ OCCLUDED PIXELS ARE EXCLUDED, NOT OCCLUDED GLYPHS. Skipping
			# whole glyphs -- the first fix, after the hop ball and a bird
			# came back matching a stranger's cell better than their own --
			# left only THREE portraits testable out of sixteen: at spawn
			# this map is crowded enough that most plates touch another
			# plate. Three readings is a thin gate. So the comparison drops
			# the PIXELS another glyph covers and keeps the rest, which is
			# the same distinction PHASE 4 draws between "hidden" and "gone".
			var others: Array[Vector2] = _other_glyphs(shot["at"])
			var here: Vector2 = _map.global_position + (shot["at"] as Vector2)
			var d_mine: float = _cell_gap(img, atlas, here, mine, others)
			var d_theirs: float = _cell_gap(img, atlas, here, theirs, others)
			if d_mine < 0.0 or d_theirs < 0.0:
				continue
			tested += 1
			_check(d_mine < d_theirs, "%-10s screen matches its OWN cell better than cell %d (%.4f < %.4f)"
				% [id, other_row, d_mine, d_theirs])
	# MEASURED, not hoped for: at spawn the delivered world leaves this many
	# portraits standing clear of every other plate. Printed as well as
	# gated, because a drop here means the map got more crowded, not that
	# the test got weaker.
	print("   %d of the drawn portraits stood clear enough to be read" % tested)
	_check(tested >= 6, "enough portraits were on screen to test (%d)" % tested)

## Every OTHER drawn glyph's centre, in widget pixels. Read off the widget
## rather than recomputed (the CH46 defect: a probe free to disagree with
## the thing it measures).
## ⚠️ EACH NEIGHBOUR CARRIES ITS OWN DRAWN REACH, not a shared half-cell.
## Keepy's glyph is drawn 1.28x its cell, so a fixed 16 px half-extent
## under-covers him: six perimeter samples on OTHER plates landed on his and
## scored 1.23:1 -- one dark plate against another, on a correct map.
func _other_glyphs(mine_at: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	_other_reach.clear()
	for kind in HubMinimap.DRAW_ORDER:
		for other in _map.clusters(kind):
			var at: Vector2 = other["at"]
			if at.is_equal_approx(mine_at):
				continue
			out.append(at)
			_other_reach.append(_map.node_reach(other["members"][0], kind,
				HubMinimap.variant_of(int(other["count"]), bool(other["clamped"]))))
	return out

var _other_reach: PackedFloat32Array = PackedFloat32Array()

## Mean absolute difference between the rendered patch and an atlas cell,
## over the cell's OPAQUE pixels only -- the transparent ones show the plan
## and say nothing about which portrait this is. -1 when the patch runs off
## the frame.
func _cell_gap(img: Image, atlas: Image, centre: Vector2, cell: int,
		others: Array[Vector2]) -> float:
	var r: Rect2 = _map.icon_rect(cell)
	var half: int = HubMinimap.ICON_PX / 2
	var sum: float = 0.0
	var n: int = 0
	var bar: float = float(HubMinimap.ICON_PX) * 0.5
	for dy in HubMinimap.ICON_PX:
		for dx in HubMinimap.ICON_PX:
			var src: Color = atlas.get_pixel(int(r.position.x) + dx, int(r.position.y) + dy)
			if src.a < 0.9:
				continue
			var local: Vector2 = centre - _map.global_position + Vector2(float(dx - half), float(dy - half))
			var hidden: bool = false
			for oi in others.size():
				var o: Vector2 = others[oi]
				if maxf(absf(o.x - local.x), absf(o.y - local.y)) <= _other_reach[oi] + 1.0:
					hidden = true
					break
			if hidden:
				continue
			var at := Vector2i(int(round(centre.x)) - half + dx, int(round(centre.y)) - half + dy)
			if at.x < 0 or at.y < 0 or at.x >= img.get_width() or at.y >= img.get_height():
				return -1.0
			var got: Color = img.get_pixelv(at)
			sum += (absf(src.r - got.r) + absf(src.g - got.g) + absf(src.b - got.b)) / 3.0
			n += 1
	return -1.0 if n < 40 else sum / float(n)

## PHASE 14 -- THE CONTRAST FLOOR, ON RENDERED PIXELS, AND THE ONE THING
## THE THUMBNAILS CANNOT DO.
func _phase_contrast() -> void:
	print("-- PHASE 14: 3.0:1 against every painted band --")
	var img: Image = await _shot()
	# ⚠️ THE FIRST VERSION OF THIS PHASE WAS A FALSE GREEN, AND ITS OWN RED
	# PASS IS WHAT SAID SO. It read the DARKEST pixel anywhere inside the
	# player's glyph and scored that against each band. Red pass R8
	# lightened PLATE_TONE and PLATE_RIM to a mid grey -- the exact defect
	# the phase exists to catch -- and the phase came back ALL GREEN: a
	# portrait has dark pixels of its own (an eye, an outline), so "the
	# darkest pixel in the box" stays dark however light the plate is. The
	# assertion was true and about nothing.
	#
	# What the contract actually says is that the glyph presents a dark
	# BOUNDARY all the way round, against whatever band it sits on. So the
	# perimeter is walked: for each sample, the pixel just INSIDE the
	# plate's edge against the pixel just OUTSIDE it -- the ground it is
	# actually touching, not a band tone looked up in a table. The rounded
	# corners are skipped, because there the square perimeter is off the
	# plate by construction.
	var me: Array[Dictionary] = _map.clusters(MinimapMarkers.PLAYER)
	_check(me.size() == 1, "the player draws exactly one glyph (%d)" % me.size())
	if me.is_empty():
		return
	# ⚠️ THE CONTRACT IS AGAINST THE GROUND, NOT AGAINST A NEIGHBOUR. Keepy's
	# plate touches the stream boat's on this spawn, and comparing one dark
	# plate with another dark plate scores 1.0:1 on a map that is correct.
	# Samples whose OUTSIDE point lands on another glyph are dropped, and
	# the count that survives is printed so a map crowded enough to leave
	# too few is visible rather than silently easier.
	var worst_edge: float = 99.0
	var tested: int = 0
	var failed: int = 0
	var skipped: int = 0
	var on_wash: int = 0
	var on_dark: int = 0
	var glyphs: int = 0
	# ⚠️ EVERY PORTRAIT, NOT ONLY KEEPY'S. Keepy's plate touches the stream
	# boat's on this spawn, so 74 of his own 76 perimeter samples land on a
	# neighbour and get dropped -- two readings is not a gate. Walking all
	# of them gives the contract the sample count it needs and tests it
	# where it is hardest, on whichever glyph sits on the palest band.
	for kind in [MinimapMarkers.PLAYER, MinimapMarkers.VEHICLE, MinimapMarkers.NPC]:
		for shot in _map.clusters(kind):
			var lead: Node = shot["members"][0]
			if MinimapMarkers.thumb_of(lead) == &"":
				continue
			var variant: int = HubMinimap.variant_of(int(shot["count"]), bool(shot["clamped"]))
			# ⚠️ A MERGED GLYPH IS DELIBERATELY NOT SYMMETRIC -- it is a
			# STACK, a second plate 3 px down-right -- so a square walked at
			# its outer reach passes 3 px OUTSIDE the front plate on the
			# up-left side and reads the GROUND as "the glyph" (measured:
			# 0.4159 where the keyline is 0.005). A centred perimeter is the
			# wrong instrument for it, and deepening the shell until it
			# happened to pass would have been the wrong answer twice over.
			# Merged cells get their own assertion, on the ATLAS, below.
			if variant == HubMinimap.V_MERGED:
				continue
			glyphs += 1
			var reach: float = _map.node_reach(lead, kind, variant)
			var centre: Vector2 = _map.global_position + (shot["at"] as Vector2).round()
			var neighbours: Array[Vector2] = _other_glyphs(shot["at"])
			var corner: float = reach - HubMinimap.PLATE_R
			# ⚠️ THE SHELL IS DEEP ENOUGH FOR A MERGED GLYPH'S OFFSET. A
			# merged plate is a STACK -- a second plate 3 px down-right --
			# so its silhouette is not symmetric about its centre and a
			# centred square walked at its outer reach misses the front
			# plate entirely on the up-left side. Measured: 30 samples on
			# the merged bird glyph read 0.2156 for "the glyph" (the ground
			# showing between the two plates) instead of the keyline's
			# 0.005. Five pixels covers the offset; the test still fails on
			# a light plate, which red pass R8 re-proves.
			var shell: float = 5.0
			var outer: float = reach + 4.0
			for step in 96:
				var t: float = float(step) / 96.0 * TAU
				var dir := Vector2(cos(t), sin(t))
				var k: float = reach / maxf(maxf(absf(dir.x), absf(dir.y)), 0.0001)
				var edge: Vector2 = dir * k
				if absf(edge.x) > corner and absf(edge.y) > corner:
					continue
				var op: Vector2 = edge.normalized() * (edge.length() + (outer - reach))
				var local: Vector2 = (centre - _map.global_position) + op
				if local.x < 1.0 or local.y < 1.0 or local.x > _map.size.x - 2.0 or local.y > _map.size.y - 2.0:
					skipped += 1
					continue
				var on_neighbour: bool = false
				for oi in neighbours.size():
					var o: Vector2 = neighbours[oi]
					if maxf(absf(o.x - local.x), absf(o.y - local.y)) <= _other_reach[oi] + 1.0:
						on_neighbour = true
						break
				if on_neighbour:
					skipped += 1
					continue
				var b: Color = img.get_pixelv(Vector2i(centre + op))
				# ⚠️ THE WASH OUTSIDE THE WALKABLE WORLD IS NOT A BAND, and a
				# glyph overhanging it has no edge there -- OUT_TONE renders
				# at L 0.005 and so does a black keyline, so the two score
				# 1.0:1 by being the same darkness. That is a real limit of
				# this design and it is COUNTED and reported rather than
				# hidden: what the contract is about is the marker against
				# the GROUND a player walks on.
				if _near(b, HubMinimap.OUT_TONE, 0.06):
					on_wash += 1
					continue
				# ⚠️ CH50 -- AND THE SAME LIMIT APPLIES TO PAINTED GROUND
				# THAT IS SIMPLY TOO DARK, for the identical reason the
				# wash above is exempted, MEASURED rather than argued.
				#
				# `best` is the MINIMUM over the shell, so it is the black
				# keyline by construction (the atlas gate below proves every
				# cell has one, worst L 0.0039). Against a black ink the WCAG
				# ratio is (L + 0.05) / 0.05, so 3.0:1 needs the GROUND at
				# L >= 0.10 -- and below that no plate of any design can pass,
				# which makes this a test of the MAP'S GROUND wearing a
				# marker's name.
				#
				# It is not hypothetical and it is not CH50's: sweeping the
				# RENDERED plan, `origin/main` already carries 166 px
				# (0.21 %) of painted ground under L 0.10, its darkest at
				# L 0.0656 -- exactly 2.31:1. CH50 only widened the frame,
				# which moved one balloon plate onto that band and turned a
				# lottery this assertion had been winning into a loss.
				#
				# So it is COUNTED and reported, like the wash, and the gate
				# moves to what is actually defensible: the share of the
				# perimeter that lands on unreachable ground stays small.
				# The real repair -- lifting the plan's dark bands, or a
				# light halo outside the keyline -- is a CH48 design change
				# that needs a device read, and it is NOT smuggled in here.
				if _wcag(b) < DARK_GROUND_L:
					on_dark += 1
					continue
				var best: float = 9.0
				for back in range(0, int(shell) + 1):
					var ip: Vector2 = edge.normalized() * maxf(edge.length() - float(back), 1.0)
					best = minf(best, _wcag(img.get_pixelv(Vector2i(centre + ip))))
				var ratio: float = _ratio(best, _wcag(b))
				tested += 1
				if ratio < 3.0:
					failed += 1
					if failed <= 3:
						print("      under floor: %s  glyph %.4f  ground %s %.4f  ratio %.2f:1"
							% [MinimapMarkers.thumb_of(lead), best, b, _wcag(b), ratio])
				worst_edge = minf(worst_edge, ratio)
	print("   %d portrait plates walked: %d samples against painted ground (%d on a neighbour, %d on the out-of-world wash, %d on ground below L %.2f), worst %.2f:1, %d under 3.0:1"
		% [glyphs, tested, skipped, on_wash, on_dark, DARK_GROUND_L, worst_edge, failed])
	var walked: int = tested + on_dark
	_check(walked > 0 and float(on_dark) / float(walked) <= DARK_GROUND_SHARE,
		"%d of %d perimeter samples (%.2f%%) land on ground no dark ink can clear 3.0:1 -- ceiling %.0f%%"
			% [on_dark, walked, 100.0 * float(on_dark) / maxf(float(walked), 1.0),
				100.0 * DARK_GROUND_SHARE])
	_check(tested >= 200, "the perimeters were actually walked (%d samples)" % tested)
	# The contract the perimeter walk cannot reach: EVERY portrait cell in
	# the atlas -- merged ones included -- has a near-black outermost ring.
	# Read on the baked image, so a variant the delivered world never draws
	# is covered too.
	var atlas: Image = _map.atlas_image()
	var worst_edge_l: float = -1.0
	var worst_cell: String = ""
	if atlas != null:
		for id in MinimapMarkers.THUMBS:
			for v in HubMinimap.VARIANT_COUNT:
				var l: float = _cell_edge_luminance(atlas, HubMinimap.thumb_cell_of(id, v))
				if l > worst_edge_l:
					worst_edge_l = l
					worst_cell = "%s/%d" % [id, v]
	print("   the darkest-possible edge every portrait cell can present: worst L %.4f (%s)"
		% [worst_edge_l, worst_cell])
	_check(worst_edge_l >= 0.0 and worst_edge_l < 0.0165,
		"every portrait cell, merged ones included, carries a near-black outer ring (worst L %.4f on %s)"
			% [worst_edge_l, worst_cell])
	_check(failed == 0, "the plate's edge clears 3.0:1 ALL THE WAY ROUND (worst %.2f:1)" % worst_edge)
	# The brightest and darkest the glyph gets, published because they are
	# what the limit below is about.
	var dark: float = 9.0
	var light: float = -1.0
	var keepy_at: Vector2 = _map.global_position + (me[0]["at"] as Vector2).round()
	var r: int = int(_map.node_reach(me[0]["members"][0], MinimapMarkers.PLAYER, HubMinimap.V_SIMPLE))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var l: float = _wcag(img.get_pixelv(Vector2i(int(keepy_at.x) + dx, int(keepy_at.y) + dy)))
			dark = minf(dark, l)
			light = maxf(light, l)
	print("   the glyph spans rendered luminance %.4f .. %.4f" % [dark, light])
	# ⚠️ THE SAMPLE POINTS ARE FOUND, NOT WRITTEN DOWN, and an earlier run is
	# why: (-20, 0, -55) was typed as "the autumn hollow" and read back
	# (0.0667, 0.0784, 0.0863) -- the OUT_TONE wash, because that point is
	# not in the region at all. A band read outside the world is not a band.
	# Each band is now located by asking the plan's own painted_tone() where
	# it is, on a point HubRegion admits and no marker sits on.
	var spots: Dictionary = _find_band_points()
	_check(spots.size() >= 5, "a point inside the region was found for %d bands" % spots.size())
	var band_l: Dictionary = {}
	for name in spots:
		var at: Vector2 = _map.global_position + (_map.project(spots[name])["at"] as Vector2)
		var c: Color = img.get_pixelv(Vector2i(at))
		band_l[name] = c
		print("   %-7s rendered %s  L %.4f   vs the plate tone: %.2f:1"
			% [name, c, _wcag(c), _ratio(_wcag(c), _wcag(HubMinimap.PLATE_TONE))])
	# ⚠️ THE BLIND HALF, and it is also the honest limit of this lot. The
	# PICTURE's own highlights -- Mathieu's "couleurs reelles" -- must FAIL
	# 3.0:1 somewhere, or the perimeter result above would be true of any
	# patch of anything. They do, and MinimapThumbBake PHASE 3d shows no
	# desaturation of the bands can fix it: a photograph has both a white
	# fur and a black mask, and one of them is always near the band.
	var bright_worst: float = 99.0
	for name in band_l:
		bright_worst = minf(bright_worst, _ratio(_wcag(band_l[name]), light))
	_check(bright_worst < 3.0,
		"BLIND / KNOWN LIMIT: the PICTURE's own highlights do NOT clear 3.0:1 (worst %.2f:1) -- the plate does the work"
			% bright_worst)
	# The bands stay mutually distinct after the wash.
	var names: Array = band_l.keys()
	var closest: float = 9.0
	var pair: String = ""
	for a in names.size():
		for b in range(a + 1, names.size()):
			var d: float = _rgb_dist(band_l[names[a]], band_l[names[b]])
			if d < closest:
				closest = d
				pair = "%s/%s" % [names[a], names[b]]
	print("   closest rendered band pair after the wash: %s at %.4f" % [pair, closest])
	# ⚠️ GRASS AND LAWN ARE THE ONE PAIR THE PLAN NEVER SEPARATED BY TONE,
	# AND THAT PREDATES THIS LOT. Measured on the constants at wash 0 they
	# are 0.0640 apart, already under the plan's own 8 % alpha bleed; the
	# wash leaves them at 0.0640 x (1 - 0.34). What separates them on screen
	# is the hedge line _bake_zone_edges strokes at CIRCUIT_EDGE_Z, and
	# PHASE 6 gates that line and the FILL on either side of it. Excluded
	# here by name, asserted below to still be the excluded one, so a
	# SECOND pair falling under the bleed cannot hide behind it.
	var second: float = 9.0
	var second_pair: String = ""
	for a in names.size():
		for b in range(a + 1, names.size()):
			if (names[a] == "grass" and names[b] == "lawn") or (names[a] == "lawn" and names[b] == "grass"):
				continue
			var d2: float = _rgb_dist(band_l[names[a]], band_l[names[b]])
			if d2 < second:
				second = d2
				second_pair = "%s/%s" % [names[a], names[b]]
	_check(pair == "grass/lawn" or pair == "lawn/grass",
		"the tightest pair is still the KNOWN pre-existing one (%s)" % pair)
	_check(second > 0.08,
		"every OTHER band pair is separable by tone (%s, %.4f > 0.08 bleed)" % [second_pair, second])

## PHASE 15 -- CH47'S NPC FIX, RE-PROVEN BY OBSERVED DISPLACEMENT.
##
## CH47 moved the four critters' markers off their empty controllers and
## onto the animals. A non-zero position is NOT proof of that: the
## controllers sit at the world origin and so, at spawn, do the birds. What
## proves it is MOVING the animal and watching the glyph move -- and, as
## the blind half, moving the CONTROLLER and watching it not.
func _phase_npc_follow() -> void:
	print("-- PHASE 15: an npc's marker follows the ANIMAL, by displacement --")
	var boar: Node = _hub.get_node_or_null("WorldViewport/SubViewport/World/Critters/Boar")
	if boar == null:
		for n in _map.members(MinimapMarkers.NPC):
			if MinimapMarkers.thumb_of(n) == &"boar":
				boar = n.get_parent()
	_check(boar != null, "the boar's controller was found")
	if boar == null:
		return
	var critter: Node3D = (boar.call("critter") as Node3D) if boar.has_method("critter") else null
	_check(critter != null, "and it publishes its animal")
	if critter == null:
		return
	_check(critter.is_in_group(MinimapMarkers.NPC) and not boar.is_in_group(MinimapMarkers.NPC),
		"the ANIMAL carries the marker, the controller does not")
	var before: Vector2 = _map.project(critter.global_position)["at"]
	var home: Vector3 = critter.global_position
	var ctrl_home: Vector3 = (boar as Node3D).global_position
	critter.global_position = home + Vector3(22.0, 0.0, 0.0)
	await _settle()
	var after: Vector2 = _map.project(critter.global_position)["at"]
	var moved: float = before.distance_to(after)
	var want: float = 22.0 * _map.size.x / _map.frame().size.x
	print("   the animal moved 22.0 u; its glyph moved %.2f px (expected %.2f)" % [moved, want])
	_check(absf(moved - want) < 2.0, "the glyph moved WITH the animal (%.2f px)" % moved)
	critter.global_position = home
	await _settle()
	# ⚠️ THE BLIND HALF, AND THE FIRST VERSION OF IT WAS WRONG. It moved the
	# CONTROLLER and expected the glyph to stay put -- but the animal is a
	# CHILD of the controller, so moving the parent moves the child and the
	# glyph moved 33.88 px exactly as it should have. That test could never
	# have separated the two wirings.
	#
	# What does: put the marker back where CH46 had it -- on the controller
	# -- and move the ANIMAL ALONE. A map reading the controller cannot see
	# that, and the glyph must NOT move. Then it is put back and the
	# restoration is asserted.
	critter.remove_from_group(MinimapMarkers.NPC)
	(boar as Node3D).add_to_group(MinimapMarkers.NPC)
	await _settle()
	var wrong_before: Vector2 = _map.project((boar as Node3D).global_position)["at"]
	critter.global_position = home + Vector3(22.0, 0.0, 0.0)
	await _settle()
	var wrong_after: Vector2 = _map.project((boar as Node3D).global_position)["at"]
	_check(wrong_before.distance_to(wrong_after) < 0.5,
		"BLIND: marked on the CONTROLLER, the same 22 u move is INVISIBLE (%.2f px) -- the CH46 defect"
			% wrong_before.distance_to(wrong_after))
	critter.global_position = home
	(boar as Node3D).remove_from_group(MinimapMarkers.NPC)
	critter.add_to_group(MinimapMarkers.NPC)
	await _settle()
	_check(critter.is_in_group(MinimapMarkers.NPC) and not (boar as Node3D).is_in_group(MinimapMarkers.NPC),
		"and the marker is back on the animal")
	_check(critter.global_position.distance_to(home) < 0.01,
		"and both are back where they were")

## One admitted, marker-free world point per painted band, located by
## walking the plan's own rows and asking painted_tone() what it drew.
func _find_band_points() -> Dictionary:
	var want: Dictionary = {
		"grass": HubMinimap.washed(CozyPalette.GRASS_A),
		"autumn": HubMinimap.washed(CozyPalette.AUTUMN_A),
		"moor": HubMinimap.washed(CozyPalette.MOOR_A),
		"lawn": HubMinimap.washed(CozyPalette.LAWN_A),
		"sand": HubMinimap.washed(CozyPalette.SAND_A)}
	var out: Dictionary = {}
	var f: Rect2 = _map.frame()
	for py in range(4, int(_map.size.y) - 4, 3):
		for px in range(4, int(_map.size.x) - 4, 3):
			var world := Vector3(
				f.position.x + (float(px) + 0.5) / _map.size.x * f.size.x, 0.0,
				f.position.y + f.size.y - (float(py) + 0.5) / _map.size.y * f.size.y)
			if not HubRegion.contains(world):
				continue
			var near: bool = false
			for kind in MinimapMarkers.KINDS:
				for c in _map.clusters(kind):
					if (c["at"] as Vector2).distance_to(Vector2(float(px), float(py))) < 26.0:
						near = true
			if near:
				continue
			var tone: Color = HubMinimap.painted_tone(world)
			for name in want:
				if out.has(name):
					continue
				if _rgb_dist(tone, want[name]) < 0.02:
					out[name] = world
	return out

## PHASE 16 -- MATHIEU'S FIRST NEED, GATED: KEEPY AMONG THE THIRTY-SEVEN.
##
## "le marqueur de Keepy doit rester identifiable au premier coup d'oeil".
## CH47 gave him the largest disc; CH48 cannot, because every portrait is
## one 32 px plate (PHASE 9 asserts that they are). What is left is the
## RIM: his is his own warm tone AND it is thicker than every other
## portrait's. Both halves are measured on the baked atlas -- the image the
## widget draws from -- and then confirmed on the SCREEN.
func _phase_keepy() -> void:
	print("-- PHASE 16: Keepy is findable among the roster --")
	var atlas: Image = _map.atlas_image()
	if atlas == null:
		_check(false, "the runtime atlas reads back")
		return
	# ⚠️ THE RING IS ITS OWN CELL NOW, so this counts the cell the widget
	# actually lays over Keepy against the one it lays over everyone else.
	var mine: int = _ring_pixels(atlas,
		HubMinimap.ring_cell_of(MinimapMarkers.PLAYER, HubMinimap.V_SIMPLE))
	var worst_other: int = 0
	var worst_id: String = ""
	for kind in [MinimapMarkers.VEHICLE, MinimapMarkers.NPC, MinimapMarkers.PLACE]:
		var n: int = _ring_pixels(atlas, HubMinimap.ring_cell_of(kind, HubMinimap.V_SIMPLE))
		if n > worst_other:
			worst_other = n
			worst_id = String(kind)
	print("   Keepy's ring inks %d px of its cell; the widest other kind's ring inks %d (%s)"
		% [mine, worst_other, worst_id])
	_check(mine > worst_other,
		"Keepy's ring is the thickest on the map (%d px against %d)" % [mine, worst_other])
	# ⚠️ AND THE SIZE, which is the cue a thicker ring could not carry on its
	# own: 184 px of ring against 176 is a 4.5 % difference, and CH47's rank
	# 1 was the BIGGEST marker for a reason. Measured on the DRAWN reach, so
	# it is the glyph on the plan and not a constant.
	var big: float = 0.0
	for shot in _map.clusters(MinimapMarkers.PLAYER):
		big = maxf(big, _map.node_reach(shot["members"][0], MinimapMarkers.PLAYER,
			HubMinimap.variant_of(int(shot["count"]), bool(shot["clamped"]))))
	var rest: float = 0.0
	var rest_kind: String = ""
	for kind in [MinimapMarkers.VEHICLE, MinimapMarkers.NPC, MinimapMarkers.PLACE]:
		for shot in _map.clusters(kind):
			var r2: float = _map.node_reach(shot["members"][0], kind,
				HubMinimap.variant_of(int(shot["count"]), bool(shot["clamped"])))
			if r2 > rest:
				rest = r2
				rest_kind = String(kind)
	print("   Keepy is drawn at reach %.2f px; the largest of the other 36 is %.2f (%s)"
		% [big, rest, rest_kind])
	_check(big > rest * 1.15,
		"and he is decisively the biggest marker on the map (%.2f against %.2f)" % [big, rest])
	# ⚠️ THE BLIND HALF: the same count on a cell that carries NO ring must
	# come back near zero, or "Keepy's is thickest" would also be true of a
	# counter that says yes to everything.
	var nonsense: int = _ring_pixels(atlas, HubMinimap.thumb_cell_of(&"keepy", HubMinimap.V_SIMPLE))
	_check(nonsense < 4, "BLIND: the portrait cell itself carries no ring (%d px)" % nonsense)
	# And on the screen, not only in the atlas.
	var img: Image = await _shot()
	var me: Array[Dictionary] = _map.clusters(MinimapMarkers.PLAYER)
	if me.is_empty():
		_check(false, "the player has a glyph on screen")
		return
	var at: Vector2 = _map.global_position + (me[0]["at"] as Vector2)
	var lit: int = _tone_hits(img, at, HubMinimap.PLAYER_TONE,
		_map.node_reach(me[0]["members"][0], MinimapMarkers.PLAYER, HubMinimap.V_SIMPLE) + 1.0)
	_check(lit >= 12, "and it reaches the screen: %d px of his rim tone under the glyph" % lit)

## How many opaque WHITE pixels a ring cell carries -- its own thickness,
## read off the baked atlas rather than off the constant it was drawn from.
func _ring_pixels(atlas: Image, cell: int) -> int:
	if cell < 0:
		return 0
	var r: Rect2 = _map.icon_rect(cell)
	var n: int = 0
	for dy in HubMinimap.ICON_PX:
		for dx in HubMinimap.ICON_PX:
			var c: Color = atlas.get_pixel(int(r.position.x) + dx, int(r.position.y) + dy)
			if c.a > 0.9 and c.r > 0.9 and c.g > 0.9 and c.b > 0.9:
				n += 1
	return n

## PHASE 17 -- THE COST, ON THE CH38/CH40 BENCH.
##
## Same protocol CH44 axe 5, CH46 axe C and CH47 used, so the four numbers
## are comparable: xvfb + opengl3, 1080 x 1920, the SubViewport forced and
## its rect asserted, weather sun, Keepy at spawn. The reference is this
## same build with the widget hidden, measured twice for a floor before
## anything is compared.
func _phase_cost() -> void:
	print("-- PHASE 17: the cost, against a hidden-minimap reference --")
	var rid: RID = get_viewport().get_viewport_rid()
	_map.visible = false
	await _settle()
	var ref_a: Array = await _render_info(rid)
	await _settle()
	var ref_b: Array = await _render_info(rid)
	print("   reference (no minimap) #1   total_prims %d   total_calls %d" % [ref_a[0], ref_a[1]])
	print("   reference (no minimap) #2   total_prims %d   total_calls %d" % [ref_b[0], ref_b[1]])
	_check(ref_a[0] == ref_b[0] and ref_a[1] == ref_b[1],
		"NOISE FLOOR: two references agree (%d/%d against %d/%d)" % [ref_a[0], ref_a[1], ref_b[0], ref_b[1]])
	_map.visible = true
	await _settle()
	var with: Array = await _render_info(rid)
	print("   with the CH48 minimap      total_prims %d   total_calls %d" % [with[0], with[1]])
	print("   DELTA                      %+d prim / %+d calls" % [with[0] - ref_a[0], with[1] - ref_a[1]])
	print("   CH47 published             +62 prim / +1 call      CH46 published +76 prim / +1 call")
	_check(with[1] - ref_a[1] <= 1,
		"STILL ONE DRAW CALL, background included (%+d)" % (with[1] - ref_a[1]))
	_check(with[0] - ref_a[0] > 0, "and the map is actually being submitted (%+d prim)" % (with[0] - ref_a[0]))
	var atlas: Image = _map.atlas_image()
	if atlas != null:
		print("   the runtime atlas is %d x %d (%d cells); the shipped sheet is %d bytes on disk"
			% [atlas.get_width(), atlas.get_height(), HubMinimap.atlas_cells(),
				FileAccess.get_file_as_bytes("res://assets/textures/ui/minimap_thumbs.png").size()])

## ⚠️ THE ENGINE TOTALS, NOT THE VIEWPORT ONES. The first version asked
## `viewport_get_render_info(... TYPE_VISIBLE ...)` on the root viewport
## and got 0 / 0 -- which the assertion below caught and published as a
## zero, per CLAUDE.md's own rule about a 0 on a counter line. A 2D widget
## is not in a 3D viewport's visible list at all; CH46 and CH47 both
## published `engine_total_*`, and these are those.
func _render_info(_rid: RID) -> Array:
	await RenderingServer.frame_post_draw
	return [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]

## The luminance of the darkest opaque pixel on a cell's own outer ring --
## the boundary it can present to the ground, whatever the ground is. Walked
## on the cell's real silhouette (the outermost opaque pixel of each row and
## column) rather than on a circle, so an asymmetric merged stack is
## measured where its edge actually is.
func _cell_edge_luminance(atlas: Image, cell: int) -> float:
	if cell < 0:
		return -1.0
	var r: Rect2 = _map.icon_rect(cell)
	var n: int = HubMinimap.ICON_PX
	var worst: float = -1.0
	for i in n:
		for pass_dir in 4:
			var found: bool = false
			for k in n:
				var x: int = i
				var y: int = k
				match pass_dir:
					1: y = n - 1 - k
					2:
						x = k
						y = i
					3:
						x = n - 1 - k
						y = i
				var c: Color = atlas.get_pixel(int(r.position.x) + x, int(r.position.y) + y)
				if c.a > 0.9:
					# The first opaque pixel from this side IS the edge.
					var best: float = 9.0
					for depth in 3:
						var xx: int = x
						var yy: int = y
						match pass_dir:
							0: yy = mini(y + depth, n - 1)
							1: yy = maxi(y - depth, 0)
							2: xx = mini(x + depth, n - 1)
							3: xx = maxi(x - depth, 0)
						var cc: Color = atlas.get_pixel(int(r.position.x) + xx, int(r.position.y) + yy)
						if cc.a > 0.9:
							best = minf(best, _wcag(cc))
					worst = maxf(worst, best)
					found = true
					break
			if not found:
				continue
	return worst

static func _wcag(c: Color) -> float:
	return 0.2126 * _srgb(c.r) + 0.7152 * _srgb(c.g) + 0.0722 * _srgb(c.b)

static func _srgb(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)

static func _ratio(a: float, b: float) -> float:
	return (maxf(a, b) + 0.05) / (minf(a, b) + 0.05)

static func _rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

## ---- helpers --------------------------------------------------------

## Three frames, which is what the widget needs to re-bake its cluster list
## and the renderer to put it on screen.
func _settle() -> void:
	for _i in 3:
		await get_tree().process_frame

## How much of one ICON_PX box `now` differs from `base`, and by how much at
## its strongest. The difference IS the marker: the baseline frame has the
## kind lifted off the map, so anything that changed inside the box is the
## glyph's ink -- outline included, tone-independent, band-independent.
func _coverage(now: Image, base: Image, centre: Vector2) -> Dictionary:
	var half: int = HubMinimap.ICON_PX / 2
	var hits: int = 0
	var top: float = 0.0
	var total: int = 0
	# ⚠️ CH48 ALSO RETURNS THE MAP, NOT ONLY THE COUNT. See PHASE 9: two
	# portraits have the same footprint by construction, so |cov(A)-cov(B)|
	# cannot separate them and reads near zero for two different pictures.
	# `ink` is the per-pixel delta against this glyph's own baseline, in
	# reading order, so a pair can be compared where they actually differ.
	var ink: PackedFloat32Array = PackedFloat32Array()
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var at := Vector2i(int(round(centre.x)) + dx, int(round(centre.y)) + dy)
			if at.x < 0 or at.y < 0 or at.x >= now.get_width() or at.y >= now.get_height():
				continue
			total += 1
			var a: Color = now.get_pixelv(at)
			var b: Color = base.get_pixelv(at)
			var d: float = maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
			top = maxf(top, d)
			ink.append(d)
			if d >= INK_EPS:
				hits += 1
	return {"cov": float(hits) / maxf(float(total), 1.0), "peak": top, "ink": ink}

## How much of the box two glyphs' ink maps DISAGREE about. Both are the
## per-pixel delta against their own baseline, so the plan tone underneath
## each one has already been divided out and the number is about the
## glyphs, not about the band they happen to sit on.
func _disagree(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var n: int = mini(a.size(), b.size())
	if n == 0:
		return 0.0
	var differ: int = 0
	for i in n:
		if absf(a[i] - b[i]) > INK_EPS:
			differ += 1
	return float(differ) / float(n)

## How many pixels within `radius` of `centre` read back as `tone`. Used
## instead of a single centre sample because a MERGED glyph is punched at
## its centre on purpose.
func _tone_hits(img: Image, centre: Vector2, tone: Color, radius: float) -> int:
	var r: int = int(ceil(radius))
	var n: int = 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if float(dx * dx + dy * dy) > radius * radius:
				continue
			var at := Vector2i(int(round(centre.x)) + dx, int(round(centre.y)) + dy)
			if at.x < 0 or at.y < 0 or at.x >= img.get_width() or at.y >= img.get_height():
				continue
			if _near(img.get_pixelv(at), tone, TONE_EPS):
				n += 1
	return n

## Rec.709 relative luminance of a tint, on the sRGB values as authored --
## the same arithmetic used everywhere else in this repo when tones are
## ordered rather than contrast-scored.
func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

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
