extends Node

## Gates TIER 1 of the zipline: the two towers, the cable, and the ground
## they leave free. Nothing here touches an interaction -- there is none
## yet, and PHASE F gates that there is none.
##
## =====================================================================
## WHY EACH PHASE IS GATED AND NOT MERELY REPORTED
##
## Every way this prop can be wrong is SILENT on a device. A tower whose
## stair reaches further than the budget Mathieu set is a structure that
## overlaps its neighbours and looks, on a phone, like decor that was
## always crowded. A cable anchored a few centimetres off its head frame
## reads as a cable. A footprint that under-reports what the tower puts on
## the ground puts Keepy INSIDE the stair on his next landing, and nothing
## raises. None of those fail a build.
##
## =====================================================================
## ⚠️ THIS PROBE MUST RUN UNDER opengl3, NOT --headless
##
## PHASE C reads MultiMesh instance transforms, and CLAUDE.md records that
## the DUMMY driver --headless forces returns the IDENTITY for those --
## silently. A measurement of "where is the stair" taken through that
## driver would put every batched part at the world origin and report an
## emprise of zero, which passes every budget there is.
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
##     --path . res://scripts/dev/ZiplineStructureProbe.tscn
##
## PHASE 0 exists so that running it the wrong way FAILS LOUDLY instead of
## passing for free: it reads back one instance transform whose origin is
## known to be far from the origin, and asserts it came back moved.
##
## =====================================================================
## WHAT THIS PROBE CANNOT DECIDE
##
## Whether two towers and a thread between them READ as a zipline on a
## 6-inch screen, from a camera that never turns and shows P2 from P1 not
## at all. That is Mathieu's device call, and RECON 5 already measured the
## asymmetry he accepted. This file measures geometry, clearance and the
## absence of a tap channel -- never legibility.

const _HUB_WORLD_SCENE := "res://scenes/HubWorld.tscn"

## The two points Mathieu fixed, and the budget he set. Restated here
## deliberately: this probe's job is to fail when the shipped tree stops
## agreeing with them, so it cannot read them from the thing it is
## checking.
const P1 := Vector3(27.7, 0.0, 9.2)
const P2 := Vector3(25.2, 0.0, 35.0)
const STRUCTURE_RADIUS_BUDGET: float = 1.932
const CABLE_HEIGHT: float = 2.0

## Where the flower stood before this batch moved it clear of the P1
## stair. Used ONLY by the blind check: the corridor test is replayed with
## it back in place and is REQUIRED to fail, because an "is this ground
## free" assertion that has never seen blocked ground passes for free.
const FLOWER_BEFORE := Vector3(28.336, 0.0, 6.894)
const FLOWER_RADIUS_BEFORE: float = 0.22 * 1.253

## The rule HubWorld already applies when it looks for somewhere Keepy can
## stand: a candidate is free when it clears every footprint by this much.
## READ from HubWorld rather than retyped -- a second copy of a body's
## width is how the two drift apart.
var _keepy_clearance: float = 0.0

var _failures: int = 0
var _props: HubBuilder = null
var _consts: Dictionary = {}

func _ready() -> void:
	ProbeWatchdog.arm(self, "ZIPLINE STRUCTURE PROBE")
	var dl := ProbeWatchdog.deadline("ZIPLINE STRUCTURE PROBE")

	print("=== ZIPLINE STRUCTURE PROBE ===")
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = hub.get_node("WorldViewport/SubViewport/World") as Node3D
	_props = world.get_node("Props") as HubBuilder
	# ⚠️ Object.get("SOME_CONST") returns null for a GDScript const,
	# silently -- the constant map is the accessor that actually works.
	_consts = _props.get_script().get_script_constant_map()
	# From the ROOT, not from the "World" node: HubWorld.gd is attached to
	# the Control at the top of that scene, and get_script() on the wrong
	# node returns null and the clearance silently becomes 0.0 -- a
	# corridor test that then passes against every possible layout.
	_keepy_clearance = float((hub.get_script() as Script).get_script_constant_map().get("KEEPY_CLEARANCE", 0.0))

	_check(_keepy_clearance > 0.0, "read HubWorld.KEEPY_CLEARANCE (%.3f)" % _keepy_clearance)
	print("")

	_phase_0_driver()
	dl.abort_if_exceeded()
	_phase_a_blind_check()
	dl.abort_if_exceeded()
	_phase_b_points()
	dl.abort_if_exceeded()
	_phase_c_emprise()
	dl.abort_if_exceeded()
	_phase_d_cable()
	dl.abort_if_exceeded()
	_phase_e_clearance()
	dl.abort_if_exceeded()
	_phase_f_tap_channel()
	dl.abort_if_exceeded()
	_phase_g_draw_nodes(_props)

	print("")
	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("  OK    %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s" % label)

## PHASE 0 -- the driver can report a MultiMesh transform at all.
##
## Not a formality. Under --headless every get_instance_transform() comes
## back as the identity, which would put every batched part of both towers
## at the world origin: PHASE C would then measure an emprise of 0.0 and
## report the budget comfortably met on a prop it never saw.
func _phase_0_driver() -> void:
	print("PHASE 0 -- the renderer reports MultiMesh transforms")
	var moved: bool = false
	var seen: int = 0
	for batch in _zipline_batches():
		var multi: MultiMesh = batch.multimesh
		for i in multi.instance_count:
			seen += 1
			if multi.get_instance_transform(i).origin.length() > 1.0:
				moved = true
	_check(seen > 0, "the zipline files batched instances at all (%d seen)" % seen)
	_check(moved, "instance transforms read back MOVED, not the identity (driver is not DUMMY)")
	print("")

## PHASE A -- BLIND CHECK, then the assertion.
##
## The corridor test below asserts an ABSENCE ("nothing blocks the foot of
## either stair"), and this repo has already measured three such assertions
## passing green against a mechanic that was never wired. So the test is
## first shown FAILING, on the exact layout this batch changed: the flower
## put back where it stood. Only then is the shipped layout allowed to
## count as a pass.
func _phase_a_blind_check() -> void:
	print("PHASE A -- the corridor test can SEE blocked ground")
	var zip: Dictionary = _zipline()
	if zip.is_empty():
		_check(false, "a zipline was built at all")
		print("")
		return
	var tower: Dictionary = (zip["towers"] as Array)[0]
	var spoiled: Array = _footprints_excluding_zipline()
	spoiled.append({"position": FLOWER_BEFORE, "radius": FLOWER_RADIUS_BEFORE})
	var before: Dictionary = _stair_foot_margin(tower, spoiled)
	_check(float(before["margin"]) < 0.0,
		"with the flower back at its old spot the P1 stair foot is BLOCKED (margin %+.3f, by %s)"
			% [before["margin"], before["by"]])
	print("")

## PHASE B -- the towers stand on the two points Mathieu fixed, and the
## span between them is the one recon measured.
##
## Read off the PUBLISHED, as-built facts rather than off the layout file:
## the layout is what was asked for, the built tree is what happened, and
## the whole point of an as-built accessor is that the two can be compared.
func _phase_b_points() -> void:
	print("PHASE B -- the two fixed points, as built")
	var zip: Dictionary = _zipline()
	if zip.is_empty():
		_check(false, "a zipline was built at all")
		print("")
		return
	var towers: Array = zip["towers"]
	_check(towers.size() == 2, "one entry built TWO towers (%d)" % towers.size())
	if towers.size() != 2:
		print("")
		return
	var a: Vector3 = towers[0]["position"]
	var b: Vector3 = towers[1]["position"]
	_check(a.distance_to(P1) < 0.001, "near tower at P1 %s (built %s)" % [P1, a])
	_check(b.distance_to(P2) < 0.001, "far tower at P2 %s (built %s)" % [P2, b])
	_check(absf(a.y) < 0.001 and absf(b.y) < 0.001, "both towers stand at ground level")
	var span: float = a.distance_to(b)
	print("        span %.3f u, bearing %+.2f deg from +Z"
		% [span, rad_to_deg(atan2(b.x - a.x, b.z - a.z))])
	_check(absf(span - 25.921) < 0.002, "span is recon's 25.921 u (%.3f)" % span)
	# The two towers face EACH OTHER, which is what makes the cable
	# bidirectional rather than two props aimed the same way.
	var fa: Vector3 = towers[0]["forward"]
	var fb: Vector3 = towers[1]["forward"]
	_check(fa.dot(fb) < -0.9999, "the towers face each other (dot %.6f)" % fa.dot(fb))
	print("")

## PHASE C -- what each tower ACTUALLY occupies, measured off the drawn
## tree, against Mathieu's 1.932 u budget.
##
## The eight CORNERS of each part's local AABB, transformed -- not the
## world AABB of the part, which for a tilted stringer is the axis-aligned
## box AROUND the tilt and reports more than the box occupies. Measured
## this way the naive footprint expression was caught under-reporting by
## 3 cm, which is exactly the error a probe reading the constant back to
## itself would have missed.
func _phase_c_emprise() -> void:
	print("PHASE C -- emprise as built, against the %.3f u budget" % STRUCTURE_RADIUS_BUDGET)
	var zip: Dictionary = _zipline()
	if zip.is_empty():
		_check(false, "a zipline was built at all")
		print("")
		return
	var towers: Array = zip["towers"]
	var centres: Array = []
	for tower in towers:
		centres.append(tower["position"] as Vector3)
	var worst: Array = [0.0, 0.0]
	var parts: Array = [0, 0]

	for node in _zipline_drawn_nodes():
		if String(node.name).begins_with("Cable"):
			continue
		var index: int = _nearest_centre(node.global_transform.origin, centres)
		var reach: float = _corner_reach(node.mesh.get_aabb(), node.global_transform,
			centres[index] as Vector3)
		parts[index] += 1
		worst[index] = maxf(worst[index], reach)

	for batch in _zipline_batches():
		var multi: MultiMesh = batch.multimesh
		var local: AABB = multi.mesh.get_aabb()
		for i in multi.instance_count:
			var xform: Transform3D = batch.global_transform * multi.get_instance_transform(i)
			var index: int = _nearest_centre(xform.origin, centres)
			parts[index] += 1
			worst[index] = maxf(worst[index], _corner_reach(local, xform, centres[index] as Vector3))

	for i in 2:
		print("        tower %d: %d drawn parts, furthest corner %.4f u from centre"
			% [i, parts[i], worst[i]])
		_check(parts[i] > 0, "tower %d has parts to measure" % i)
		_check(worst[i] <= STRUCTURE_RADIUS_BUDGET,
			"tower %d emprise %.4f <= %.3f u budget" % [i, worst[i], STRUCTURE_RADIUS_BUDGET])
	# The two towers are the SAME structure -- a departure that had drifted
	# from an arrival is what building both from one function is for.
	_check(absf(worst[0] - worst[1]) < 0.0005,
		"both towers measure the same (%.4f vs %.4f)" % [worst[0], worst[1]])
	# And the published footprint must not UNDER-report what was drawn:
	# every landing check on this plateau reads that number, so a footprint
	# smaller than the prop is Keepy standing inside the stair.
	var declared: float = float(zip["clear_radius"])
	var drawn: float = maxf(worst[0], worst[1])
	print("        published clear_radius %.5f u" % declared)
	_check(declared >= drawn - 0.0005,
		"published footprint %.5f covers the drawn %.5f" % [declared, drawn])
	# And covers it TIGHTLY. A footprint padded "to be safe" is ground
	# nobody may land on for no reason a reader can see, and the 5 mm gap
	# this bound would have caught was a real error in the expression --
	# the second one, after the first was corrected -- not a safety margin
	# anybody chose.
	_check(declared - drawn < 0.01,
		"published footprint is within 1 cm of the drawn one (%+.5f)" % [declared - drawn])

	# ⚠️ THE STAIR RAILS RUN THE RIGHT WAY UP. The emprise number above is
	# BLIND to this: a stringer mirrored about the vertical circumscribes
	# the identical radius, measured. It shipped that way once -- rails
	# from the deck edge at ground level up to the stair foot at deck
	# height, crossing the treads instead of carrying them -- and only a
	# 5 mm disagreement between the drawn number and the formula gave it
	# away. So it is asserted directly: on every rail, the HIGH end is the
	# end NEAREST the tower.
	var rails: int = 0
	var right_way_up: int = 0
	for batch in _zipline_batches():
		if batch.name != "ZiplineStringer":
			continue
		var multi: MultiMesh = batch.multimesh
		var local: AABB = multi.mesh.get_aabb()
		for i in multi.instance_count:
			var xform: Transform3D = batch.global_transform * multi.get_instance_transform(i)
			var centre: Vector3 = centres[_nearest_centre(xform.origin, centres)]
			var high: Vector3 = Vector3.ZERO
			var low: Vector3 = Vector3.ZERO
			for c in 8:
				var corner: Vector3 = xform * local.get_endpoint(c)
				if c == 0 or corner.y > high.y:
					high = corner
				if c == 0 or corner.y < low.y:
					low = corner
			rails += 1
			if Vector3(high.x, 0.0, high.z).distance_to(centre) \
					< Vector3(low.x, 0.0, low.z).distance_to(centre):
				right_way_up += 1
	_check(rails == 4, "four stair rails were drawn (%d)" % rails)
	_check(rails > 0 and right_way_up == rails,
		"every stair rail rises TOWARDS its tower (%d of %d)" % [right_way_up, rails])
	print("")

## PHASE D -- the cable is LEVEL, at the height Mathieu fixed, and the
## mesh that was drawn is the one the published endpoints describe.
##
## The last of those is the one worth having: "the anchors are 2.0 up" is
## a statement about a dictionary, and a dictionary is not what a player
## sees. The drawn cylinder's own length and midpoint are compared against
## the published pair, so a cable that was strung somewhere else fails
## here rather than on a phone.
func _phase_d_cable() -> void:
	print("PHASE D -- the cable, as drawn")
	var zip: Dictionary = _zipline()
	if zip.is_empty():
		_check(false, "a zipline was built at all")
		print("")
		return
	var cable: Dictionary = zip["cable"]
	var from: Vector3 = cable["from"]
	var to: Vector3 = cable["to"]
	_check(absf(from.y - CABLE_HEIGHT) < 0.0001 and absf(to.y - CABLE_HEIGHT) < 0.0001,
		"both ends at the fixed %.1f u (%.4f / %.4f)" % [CABLE_HEIGHT, from.y, to.y])
	_check(absf(from.y - to.y) < 0.000001, "the cable is LEVEL, not sloped")
	var towers: Array = zip["towers"]
	_check(from.distance_to(towers[0]["anchor"] as Vector3) < 0.0001
		and to.distance_to(towers[1]["anchor"] as Vector3) < 0.0001,
		"the cable ends ARE the two head frames' anchors")
	# The deck is derived, never chosen: a rider hangs cable_height minus
	# the drop, and the platform is that same level.
	var deck_y: float = (towers[0]["deck"] as Vector3).y
	_check(absf(deck_y - (CABLE_HEIGHT - float(zip["rider_drop"]))) < 0.000001,
		"deck %.4f == cable %.1f - rider drop %.2f" % [deck_y, CABLE_HEIGHT, zip["rider_drop"]])

	var drawn: MeshInstance3D = null
	for node in _zipline_drawn_nodes():
		if String(node.name).begins_with("Cable"):
			drawn = node
	_check(drawn != null, "a cable node was actually drawn")
	if drawn == null:
		print("")
		return
	var length: float = (drawn.mesh as CylinderMesh).height
	print("        drawn length %.4f u, published span %.4f u" % [length, from.distance_to(to)])
	_check(absf(length - from.distance_to(to)) < 0.0001,
		"the drawn cable is exactly as long as the published span")
	_check(drawn.global_transform.origin.distance_to((from + to) * 0.5) < 0.0001,
		"the drawn cable is centred on the published span")
	print("")

## PHASE E -- nothing blocks either tower.
##
## Two separate questions, and they are not the same one:
##   1. no other prop's footprint OVERLAPS a tower's;
##   2. the FOOT OF THE STAIR, across the width of the flight, is ground
##      Keepy could be put on -- the rule HubWorld already applies when it
##      hunts for a free landing.
##
## The zipline's own two footprints are excluded from (2) for the obvious
## reason: the stair foot is exactly clear_radius from its own centre, so
## including it would make the test fail for every possible layout.
func _phase_e_clearance() -> void:
	print("PHASE E -- clearance, both ends")
	var zip: Dictionary = _zipline()
	if zip.is_empty():
		_check(false, "a zipline was built at all")
		print("")
		return
	var others: Array = _footprints_excluding_zipline()
	var radius: float = float(zip["clear_radius"])
	for tower in (zip["towers"] as Array):
		var centre: Vector3 = tower["position"]
		var worst: float = INF
		var by: String = "nothing"
		for foot in others:
			var gap: float = centre.distance_to(foot["position"] as Vector3) \
				- radius - float(foot["radius"])
			if gap < worst:
				worst = gap
				by = "%s" % foot["position"]
		print("        tower at %s: nearest footprint gap %+.4f (%s)" % [centre, worst, by])
		_check(worst > 0.0, "no prop overlaps the tower at %s" % centre)
		var reachable: Dictionary = _stair_foot_margin(tower, others)
		print("        tower at %s: stair-foot margin %+.4f (%s)" % [centre, reachable["margin"], reachable["by"]])
		_check(float(reachable["margin"]) >= 0.0,
			"the stair foot at %s is ground Keepy can be placed on" % centre)
		_check(HubRegion.contains(centre), "the tower at %s is inside the walkable region" % centre)
	print("")

## PHASE F -- THE TAP CHANNEL, AND THE ONE THING THAT MUST STILL BE ABSENT.
##
## ⚠️ THIS PHASE WAS INVERTED ON 3 SEPTEMBRE 2026 (tier 2). It used to
## assert that HubWorld, HubTapInput and KeepyHopper mention no zipline at
## all -- correct while tier 1 shipped structure only, and now false by
## design: tier 2 wires a `tapped_zipline` channel through all three.
##
## What survives the inversion is the half that was ever about doctrine.
## RECON 1 settled that the banned LADDER PATTERN is a hotspot on the
## STAIRS: a channel that emits whatever the body is doing, dropped by its
## listener, leaving a player on the steps with no way to say anything. So
## the assertion is now that the channel exists, that it goes through a
## WITHDRAWING door, and that the stair still carries nothing -- source
## text, because a hotspot that does not exist has no runtime symptom to
## measure.
func _phase_f_tap_channel() -> void:
	print("PHASE F -- the tier 2 channel is wired, through a door that withdraws")
	var world: String = FileAccess.get_file_as_string("res://scripts/hub/HubWorld.gd")
	var tap: String = FileAccess.get_file_as_string("res://scripts/hub/HubTapInput.gd")
	var hopper: String = FileAccess.get_file_as_string("res://scripts/hub/KeepyHopper.gd")
	var door: String = FileAccess.get_file_as_string("res://scripts/hub/ZiplineDoor.gd")
	for pair in [["HubWorld.gd", world], ["HubTapInput.gd", tap],
			["KeepyHopper.gd", hopper], ["ZiplineDoor.gd", door]]:
		_check(not String(pair[1]).is_empty(), "%s is readable" % pair[0])

	_check(tap.findn("signal tapped_zipline") >= 0,
		"HubTapInput declares the tapped_zipline channel")
	_check(tap.findn("zipline.accepts_boarding_tap") >= 0,
		"and it asks the DOOR before emitting -- the boat's withdrawal, not the ladder's unconditional emit")
	_check(door.findn("func is_available_at") >= 0 and door.findn("_riding") >= 0,
		"the door carries a per-end question AND a shared riding flag")
	_check(world.findn("_on_tapped_zipline") >= 0 and world.findn("set_riding(true)") >= 0,
		"HubWorld handles the channel and closes the door for the trip")
	_check(hopper.findn("func leave_zipline") >= 0,
		"KeepyHopper carries a leave_zipline on the leave_ride model, so a destination survives the drop")

	# THE ONE THING THAT MUST STAY ABSENT. No stair, tread or stringer may
	# ever become a tap target: that is the ladder pattern by another name,
	# and it is the failure RECON 1 was written to prevent.
	for needle in ["stair_feet", "stair_radius", "tapped_stair", "tapped_ladder_zipline"]:
		_check(tap.findn(needle) < 0 and world.findn(needle) < 0,
			"nothing anywhere makes the stair a tap target (\"%s\")" % needle)

	# The published facts tier 2 reads. Their absence would mean the ride
	# re-derives the cable from the layout, which is the failure this repo
	# has paid for on a doorstep and on two lake radii.
	var zip: Dictionary = _zipline()
	for key in ["towers", "cable", "cable_height", "rider_drop", "clear_radius",
			"carrier", "bar_drop", "rider_lateral", "hang_clearance"]:
		_check(zip.has(key), "ziplines() publishes \"%s\"" % key)
	print("")

## PHASE G -- the draw-node budget, itemised.
func _phase_g_draw_nodes(builder: HubBuilder) -> void:
	print("PHASE G -- draw nodes")
	var individual: int = 0
	var multimesh: int = 0
	for child in builder.get_children():
		if child is MultiMeshInstance3D:
			multimesh += 1
		elif child is HubPortal:
			continue
		else:
			individual += _count_mesh_instances(child)
	var excl: int = individual + multimesh
	print("        %d individual + %d batches = %d excluding portals" % [individual, multimesh, excl])
	_check(excl == _EXPECTED_DRAW_NODES_EXCL_PORTALS,
		"draw nodes excluding portals == %d" % _EXPECTED_DRAW_NODES_EXCL_PORTALS)
	print("")

## 141 -> 144 on 3 septembre 2026 (tier 2), ITEMISED rather than nudged:
## the trolley is THREE MeshInstance3D of its own -- a pulley on the wire,
## a stem, and the grab bar the two riders hang from. One mesh would have
## left two bodies dangling under a dot. The badger is NOT in this count
## and cannot be: it lives under `World/` beside Keepy and the bear, not
## under `World/Props`, so this phase structurally cannot see it -- its
## cost (ONE MeshInstance3D, the rig's single skinned mesh) is published in
## the lot report instead of riding an assertion that could not observe it.
##
## 132 -> 141 on 3 septembre 2026, ITEMISED rather than nudged, on the
## terms TurnstileProbe set: the zipline adds FIVE MeshInstance3D of its
## own (a deck and a head beam at each end, and the one cable between
## them) and FOUR shared MultiMeshInstance3D -- legs, masts, treads and
## stringers, one node each for however many towers there are. The batches
## are what keep this from being +25: eight legs, four masts, eight treads
## and four stringers cost four nodes between them.
const _EXPECTED_DRAW_NODES_EXCL_PORTALS: int = 144

func _count_mesh_instances(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		count += 1
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count

## The one zipline the layout ships, as it was BUILT. Plural accessor,
## singular reading -- and a loud failure rather than a silent empty
## dictionary if the layout ever carries two.
func _zipline() -> Dictionary:
	var all: Array = _props.ziplines()
	if all.size() != 1:
		return {}
	return all[0]

## Every drawn node under the zipline's own root, cable included -- the
## callers that must not see the cable filter it by name.
func _zipline_drawn_nodes() -> Array:
	var out: Array = []
	for child in _props.get_children():
		if child.name != "Zipline":
			continue
		for part in child.get_children():
			if part is MeshInstance3D:
				out.append(part)
	return out

## The four shared batches this prop files into. Found by NAME because a
## batch node is named after its key -- see _flush_batches.
func _zipline_batches() -> Array:
	var out: Array = []
	for child in _props.get_children():
		if child is MultiMeshInstance3D and String(child.name).begins_with("Zipline"):
			out.append(child)
	return out

## ground_footprints() minus the zipline's own two, for the tests that ask
## "what ELSE is on this ground".
func _footprints_excluding_zipline() -> Array:
	var zip: Dictionary = _zipline()
	var mine: Array = []
	if not zip.is_empty():
		for tower in (zip["towers"] as Array):
			mine.append(tower["position"] as Vector3)
	var out: Array = []
	for foot in _props.ground_footprints():
		var where: Vector3 = foot["position"]
		var skip: bool = false
		for centre in mine:
			if where.distance_to(centre as Vector3) < 0.001:
				skip = true
		if not skip:
			out.append(foot)
	return out

## How much room is left at the FOOT OF THE STAIR, across the width of the
## flight, by HubWorld's own rule for where a body may be put: a point is
## free when it clears every footprint by KEEPY_CLEARANCE.
##
## The samples run along the tower's own stair direction at exactly
## clear_radius -- the line a climber has to stand on to start up -- and
## across the flight's half width, so the test is the width of the stair
## and not one lucky point in the middle of it.
func _stair_foot_margin(tower: Dictionary, blocked: Array) -> Dictionary:
	var forward: Vector3 = tower["forward"]
	var centre: Vector3 = tower["position"]
	var side := Vector3(forward.z, 0.0, -forward.x)
	var radius: float = float(_consts.get("ZIPLINE_FOOTPRINT_RADIUS", 0.0))
	var half: float = float(_consts.get("ZIPLINE_STRINGER_HALF_SPAN", 0.0)) \
		+ float(_consts.get("ZIPLINE_STRINGER_THICKNESS", 0.0)) * 0.5
	var worst: float = INF
	var by: String = "nothing"
	for i in 41:
		var lateral: float = half * (float(i) / 20.0 - 1.0)
		var point: Vector3 = centre - forward * radius + side * lateral
		for foot in blocked:
			var gap: float = point.distance_to(foot["position"] as Vector3) \
				- float(foot["radius"]) - _keepy_clearance
			if gap < worst:
				worst = gap
				by = "%s r=%.3f" % [foot["position"], foot["radius"]]
	return {"margin": worst, "by": by}

## Index of the nearest tower centre, flat.
func _nearest_centre(point: Vector3, centres: Array) -> int:
	var best: int = 0
	var best_distance: float = INF
	for i in centres.size():
		var flat := Vector3(point.x, 0.0, point.z)
		var distance: float = flat.distance_to(centres[i] as Vector3)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best

## The furthest any of a box's EIGHT transformed corners lands from
## `centre`, horizontally. Corners rather than a transformed AABB: the
## latter is the axis-aligned box AROUND a tilted part and over-reports it,
## which on a stair whose stringers are tilted by design would turn a
## measurement into a guess.
func _corner_reach(local: AABB, xform: Transform3D, centre: Vector3) -> float:
	var worst: float = 0.0
	for i in 8:
		var corner: Vector3 = xform * local.get_endpoint(i)
		worst = maxf(worst, Vector3(corner.x, 0.0, corner.z).distance_to(centre))
	return worst
