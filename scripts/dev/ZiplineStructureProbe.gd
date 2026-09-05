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
## The two membership tests PHASE H compares, held as members rather than
## built inline: a lambda in GDScript captures a LOCAL by VALUE, and this
## repo has paid three times for a flag a loop then never saw change.
@onready var funcref_legacy: Callable = _legacy_contains
@onready var funcref_shipped: Callable = _shipped_contains
var _props: HubBuilder = null
var _consts: Dictionary = {}
var _hub_consts: Dictionary = {}
## The Hub scene root, kept because PHASE I needs the live badger off it.
var _hub_root: Node = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "ZIPLINE STRUCTURE PROBE")
	var dl := ProbeWatchdog.deadline("ZIPLINE STRUCTURE PROBE")

	print("=== ZIPLINE STRUCTURE PROBE ===")
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	_hub_root = hub
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
	_hub_consts = (hub.get_script() as Script).get_script_constant_map()
	_keepy_clearance = float(_hub_consts.get("KEEPY_CLEARANCE", 0.0))

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
	_phase_f2_channel_exclusion()
	dl.abort_if_exceeded()
	_phase_g_draw_nodes(_props)
	dl.abort_if_exceeded()
	_phase_h_p2_lobe()
	dl.abort_if_exceeded()
	_phase_i_badger_stand()

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

## PHASE F -- THE TAP CHANNELS, AND WHY THE STAIR IS NO LONGER THE THING
## THAT MUST STAY ABSENT.
##
## ⚠️ THIS PHASE WAS INVERTED ON 3 SEPTEMBRE 2026 (tier 2), AND ITS DOCTRINE
## CHANGED AGAIN ON 4 SEPTEMBRE 2026 (tier 3) -- BY EXPLICIT REQUEST, NOT A
## REGRESSION SLIPPING PAST THIS PROBE.
##
## Tier 1 shipped structure only, and this phase asserted no zipline tap
## channel existed anywhere. Tier 2 wired `tapped_zipline` for the badger
## and this phase inverted to assert THAT channel exists while the STAIR
## still carried nothing. Tier 3 is Mathieu asking, in so many words, for a
## second channel ON the structure itself -- see ZiplineDoor.gd's own
## header and docs/lots/CH21_TYROLIENNE.md for the doctrine note in full.
##
## What survives every rewrite is the half that was ever about doctrine:
## RECON 1's LADDER PATTERN is a channel that emits whatever the body is
## doing and is dropped by its listener, leaving a player with no way to
## say anything -- NOT "a tap target on the stair" by itself. So this phase
## now asserts that BOTH channels exist, that BOTH withdraw on the boat's
## own terms, and that the two can never agree on the same tap.
func _phase_f_tap_channel() -> void:
	print("PHASE F -- both tap channels are wired, each through a door that withdraws")
	var world: String = FileAccess.get_file_as_string("res://scripts/hub/HubWorld.gd")
	var tap: String = FileAccess.get_file_as_string("res://scripts/hub/HubTapInput.gd")
	var hopper: String = FileAccess.get_file_as_string("res://scripts/hub/KeepyHopper.gd")
	var door: String = FileAccess.get_file_as_string("res://scripts/hub/ZiplineDoor.gd")
	for pair in [["HubWorld.gd", world], ["HubTapInput.gd", tap],
			["KeepyHopper.gd", hopper], ["ZiplineDoor.gd", door]]:
		_check(not String(pair[1]).is_empty(), "%s is readable" % pair[0])

	_check(tap.findn("signal tapped_zipline_badger") >= 0,
		"HubTapInput declares the badger channel")
	_check(tap.findn("zipline.accepts_boarding_tap") >= 0,
		"and it asks the DOOR before emitting -- the boat's withdrawal, not the ladder's unconditional emit")
	_check(tap.findn("signal tapped_zipline_solo") >= 0,
		"HubTapInput ALSO declares the structure channel (tier 3)")
	_check(tap.findn("zipline.accepts_structure_tap") >= 0,
		"and it asks the DOOR before emitting THAT one too")
	_check(door.findn("func is_available_at") >= 0 and door.findn("_riding") >= 0,
		"the door carries a per-end question for the badger AND a shared riding flag")
	_check(door.findn("func accepts_structure_tap") >= 0,
		"and a SECOND question for the structure, sharing that same flag")
	_check(world.findn("_on_tapped_zipline_badger") >= 0 and world.findn("set_riding(true)") >= 0,
		"HubWorld handles the badger channel and closes the door for the trip")
	_check(world.findn("_on_tapped_zipline_solo") >= 0,
		"and handles the structure channel too")
	_check(hopper.findn("func leave_zipline") >= 0,
		"KeepyHopper carries a leave_zipline on the leave_ride model, so a destination survives the drop")

	# THE ONE THING THAT MUST STILL STAY ABSENT: a channel with no
	# withdrawal at all -- the LADDER PATTERN, unconditionally emitting
	# whatever the body is doing. It is not "a tap target on the stair"
	# that must be absent any more; it is a stair tap that DROPS instead of
	# routing through the door. Both channels route through
	# `ZiplineDoor.accepts_*`, checked above, so this searches for the
	# specific failure shape rather than for the stair's mere existence as
	# a target.
	for needle in ["tapped_ladder_zipline", "tapped_stair_unconditional"]:
		_check(tap.findn(needle) < 0 and world.findn(needle) < 0,
			"no channel emits unconditionally, ladder-pattern style (\"%s\")" % needle)

	# The published facts both channels read. Their absence would mean the
	# ride re-derives the cable from the layout, which is the failure this
	# repo has paid for on a doorstep and on two lake radii.
	var zip: Dictionary = _zipline()
	for key in ["towers", "cable", "cable_height", "rider_drop", "clear_radius",
			"carrier", "bar_drop", "rider_lateral", "hang_clearance"]:
		_check(zip.has(key), "ziplines() publishes \"%s\"" % key)
	print("")

## PHASE F2 -- THE TWO DISCS AT END 0 CANNOT AGREE ON THE SAME TAP.
##
## Geometry alone cannot separate them (see ZiplineDoor.gd's header: the
## badger's disc is centred under 2.02 u from the tower, and its own
## radius is 1.8), so `accepts_structure_tap` EXCLUDES the badger's disc in
## code. This phase proves it does, with a BLIND CHECK first: an exclusion
## that had never been exercised would pass "the two disagree" for free.
func _phase_f2_channel_exclusion() -> void:
	print("PHASE F2 -- the badger and structure discs never agree")
	var zip: Dictionary = _zipline()
	if zip.is_empty():
		_check(false, "a zipline was built at all")
		print("")
		return
	var towers: Array = zip["towers"]
	var door := ZiplineDoor.new()
	var ends: Array[Vector3] = []
	for tower in towers:
		ends.append(tower["position"] as Vector3)
	# THE RIDER STANDS AT ITS OWN OFFSET POINT, not on the tower centre --
	# `_hub_root._badger_rest(0)` is the SAME as-built stand point HubWorld
	# actually parks the badger on (stair foot plus BADGER_SIDE_OFFSET), so
	# this reuses the real geometry rather than retyping a wrong stand-in
	# that would make "genuinely outside the badger's disc" true by
	# construction instead of by measurement.
	var rider := Node3D.new()
	add_child(rider)
	rider.global_position = _hub_root._badger_rest(0)
	door.setup(ends, rider, 0)

	# BLIND CHECK: the badger's OWN waiting point must itself register on
	# the badger channel, or the exclusion below would be excluding nothing.
	var badger_point: Vector3 = rider.global_position
	_check(door.accepts_boarding_tap(badger_point),
		"BLIND CHECK: the badger channel actually accepts a tap on the badger's own point")

	# ⚠️ THE BADGER'S OWN POINT IS THE WRONG POINT TO TEST THE EXCLUSION ON.
	# Measured: it sits 2.0165 u from the tower centre, just OUTSIDE
	# STRUCTURE_TAP_RADIUS (2.0) -- so `accepts_structure_tap` refuses it by
	# the plain radius test alone, before the exclusion line is ever
	# reached. Removing that line entirely was tried and changed NOTHING
	# here, which is exactly the free pass CLAUDE.md's blind-check doctrine
	# warns about. The two discs DO overlap -- the badger's own disc
	# reaches back to 2.0165 - 1.8 = 0.2165 u from the tower, well inside
	# the structure radius -- so the point that actually exercises the
	# exclusion is one INSIDE THAT LENS, not the badger's own centre.
	var overlap_point: Vector3 = badger_point + (ends[0] - badger_point).normalized() * 1.0
	_check(overlap_point.distance_to(ends[0] as Vector3) <= ZiplineDoor.STRUCTURE_TAP_RADIUS,
		"BLIND CHECK SETUP: the lens point is genuinely inside the structure's own radius (%.4f u from the tower)"
			% overlap_point.distance_to(ends[0] as Vector3))
	_check(overlap_point.distance_to(badger_point) <= ZiplineDoor.BOARD_TAP_RADIUS,
		"BLIND CHECK SETUP: and genuinely inside the badger's own disc too (%.4f u from it)"
			% overlap_point.distance_to(badger_point))
	_check(door.accepts_boarding_tap(overlap_point),
		"BLIND CHECK: the badger channel accepts this lens point")
	_check(door.accepts_structure_tap(overlap_point) < 0,
		"THE EXCLUSION: the SAME lens point is refused by the structure channel (badger wins) -- this is the line the removed guard actually protects")

	# A point on the tower but genuinely outside the badger's disc must
	# still open the structure channel -- the exclusion must not have
	# swallowed the whole end.
	var tower_only: Vector3 = ends[0]
	_check(tower_only.distance_to(badger_point) > ZiplineDoor.BOARD_TAP_RADIUS,
		"the tower centre itself is genuinely outside the badger's own disc (%.4f u away)"
			% tower_only.distance_to(badger_point))
	_check(door.accepts_structure_tap(tower_only) == 0,
		"and the tower centre DOES open the structure channel, at end 0")

	# End 1 carries no badger at all, so the exclusion has nothing to do
	# there and the whole disc is the solo target.
	_check(door.accepts_structure_tap(ends[1]) == 1,
		"end 1's tower centre opens the structure channel too, at end 1 -- no badger to exclude there")

	# BOTH CLOSE TOGETHER, the shared `_riding` flag: a trip in progress
	# refuses every channel at every end, badger or structure.
	door.set_riding(true)
	_check(not door.accepts_boarding_tap(badger_point) and door.accepts_structure_tap(badger_point) < 0
			and door.accepts_structure_tap(ends[1]) < 0,
		"mid-trip, every channel at every end is refused")
	door.set_riding(false, 0)
	rider.queue_free()
	door.queue_free()
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

## =====================================================================
## PHASE H -- THE P2 STRUCTURE LOBE, and the blind check that gives its
## coverage assertion the right to be believed.
##
## WHY THIS PHASE EXISTS. P2 sits EXACTLY on PLATEAU_HALF_EXTENT, and
## `_build_zipline_tower` runs each stair BEHIND its tower relative to that
## tower's own facing -- which at P2 points further north. So the stair and
## even the REAR LEGS stood on ground HubRegion did not contain, and the
## way that presents on a phone is not an error: it is a tower Keepy walks
## up to and then cannot move around, because every tap behind it is
## clamped back to z = 35. Nothing raises, nothing fails a build.
##
## ⚠️ BLIND CHECK FIRST, AND IT IS NOT OPTIONAL HERE. "every point around
## the tower is walkable" is a COVERAGE assertion, and this repo has
## measured three coverage/absence assertions passing green against a
## mechanism that was never wired. So the region is first replayed WITHOUT
## the structure-lobe term -- the exact state that shipped before this
## batch -- and the same coverage test is REQUIRED to fail on it. Only then
## is the shipped region allowed to pass it.
##
## The legacy region is spelled out here rather than reached by toggling a
## flag in HubRegion: a probe that could switch the shipped region off
## would be a probe that could leave it off.
func _phase_h_p2_lobe() -> void:
	print("PHASE H -- the P2 structure lobe")

	var lobes: Array[Dictionary] = HubRegion.structure_lobes()
	_check(lobes.size() >= 1, "HubRegion publishes %d structure lobe(s)" % lobes.size())
	if lobes.is_empty():
		print("")
		return

	# THE SECOND SPELLING IS GATED, not trusted. HubRegion cannot read the
	# layout (HubBuilder asks contains() while it builds), so the centre is
	# a literal there -- and a literal that agrees with nothing is exactly
	# how a bank slab ends up slicing a prop. Compared against the tower the
	# builder ACTUALLY stood, read off the published entry.
	var towers: Array = []
	var lines: Array[Dictionary] = _props.ziplines()
	if not lines.is_empty():
		towers = lines[0]["towers"]
	var built: Dictionary = {}
	for tower in towers:
		var pos: Vector3 = tower["position"]
		if pos.distance_to(P2) < 0.001:
			built = tower
	_check(not built.is_empty(), "the builder stood a tower at P2 %s" % P2)
	if built.is_empty():
		print("")
		return
	var centre: Vector3 = lobes[0]["centre"]
	var radius: float = float(lobes[0]["radius"])
	_check(centre.distance_to(built["position"] as Vector3) < 0.001,
		"and the lobe row %s is the SAME point the builder used %s" % [centre, built["position"]])

	# The five as-built ground extremities, rebuilt from the SAME basis the
	# builder uses. These are the points the old region did not contain.
	var foot: Vector3 = built["stair_foot"]
	var forward: Vector3 = (P1 - P2).normalized()
	var side := Vector3(forward.z, 0.0, -forward.x)
	var stringer: float = _c("ZIPLINE_STRINGER_HALF_SPAN")
	var leg_span: float = _c("ZIPLINE_LEG_HALF_SPAN")
	var leg_fwd: float = _c("ZIPLINE_LEG_FORWARD")
	var parts: Array[Dictionary] = [{"what": "stair_foot", "p": foot}]
	for lateral in [-stringer, stringer]:
		parts.append({"what": "stringer foot", "p": foot + side * lateral})
	for lateral in [-leg_span, leg_span]:
		parts.append({"what": "rear leg", "p": P2 - forward * leg_fwd + side * lateral})

	# ---- BLIND CHECK. The region as it shipped BEFORE this batch: square,
	# north lobe, shore pad, and no structure lobe.
	var missed_before: int = 0
	for part in parts:
		if not _legacy_contains(part["p"] as Vector3):
			missed_before += 1
	_check(missed_before == parts.size(),
		"BLIND CHECK: without the structure-lobe term, ALL %d ground parts of the P2 tower are outside the region (%d)"
			% [parts.size(), missed_before])
	var legacy_ring: int = _ring_covered(P2, 2.0, funcref_legacy)
	_check(legacy_ring < 360,
		"BLIND CHECK: and the manoeuvring ring at r=2.0 is only %d/360 walkable without it" % legacy_ring)

	# ---- THE POSITIVE, and only now. Every part the tower puts on the
	# ground is somewhere Keepy is allowed to stand.
	var covered: int = 0
	for part in parts:
		var p: Vector3 = part["p"]
		var ok: bool = HubRegion.contains(p)
		if ok:
			covered += 1
		else:
			_check(false, "%s %s is STILL outside the region" % [part["what"], p])
	_check(covered == parts.size(),
		"all %d ground parts of the P2 tower are inside the region" % parts.size())

	# ---- ROOM TO MANOEUVRE, not merely a rim that admits the stair. The
	# diagnosis measured 52.8%% walkable on a ring around P2 and 0%% around
	# the stair foot; both are gated at 100%% here.
	for r in [0.5, 1.0, 1.5, 2.0, 2.5]:
		var n: int = _ring_covered(P2, r, funcref_shipped)
		_check(n == 360, "the full ring around P2 at r=%.1f is walkable (%d/360)" % [r, n])
	for r in [0.5, 1.0]:
		var n: int = _ring_covered(foot, r, funcref_shipped)
		_check(n == 360, "the full ring around the stair foot at r=%.1f is walkable (%d/360)" % [r, n])
	# At r=1.5 the ring reaches past the lobe rim by construction (the foot
	# is 1.690 u from P2, so 1.690 + 1.5 > 3.0). Gated exactly rather than
	# loosely: every point NOT covered has to be one the rim genuinely
	# excludes, so a hole anywhere else is still caught.
	var outside_is_beyond_rim: bool = true
	var wide: int = 0
	for i in 360:
		var a: float = deg_to_rad(float(i))
		var p: Vector3 = foot + Vector3(cos(a), 0.0, sin(a)) * 1.5
		if HubRegion.contains(p):
			wide += 1
		elif p.distance_to(centre) <= radius + 1e-6:
			outside_is_beyond_rim = false
	_check(wide > 0 and outside_is_beyond_rim,
		"at r=1.5 the stair-foot ring is %d/360 walkable, and every gap is genuinely past the lobe rim" % wide)

	# ---- THE MARGIN, stated as a number rather than implied by the rings.
	var furthest: float = 0.0
	for part in parts:
		furthest = maxf(furthest, (part["p"] as Vector3).distance_to(P2))
	print("    furthest ground part %.4f u from P2; lobe radius %.2f; margin %.4f u (KEEPY_CLEARANCE %.2f)"
		% [furthest, radius, radius - furthest, _keepy_clearance])
	_check(radius - furthest >= _keepy_clearance,
		"the lobe leaves at least one KEEPY_CLEARANCE of room beyond the widest part of the tower")

	# ---- THE ARRIVAL RING. `HubWorld._ride_exit_point` drops a rider on a
	# ring of clear_radius + TURNSTILE_EXIT_MARGIN around the tower and
	# SKIPS every candidate the region does not contain. At P2 that used to
	# discard the whole northern arc, so a rider arriving from P1 could only
	# ever be put down on the plateau side. Gated here because it is a real
	# consequence of the lobe and not a coincidence of its radius: the ring
	# has to fit INSIDE the lobe for the search to have its full sweep.
	var exit_reach: float = _c("ZIPLINE_FOOTPRINT_RADIUS") \
		+ float(_hub_consts.get("TURNSTILE_EXIT_MARGIN", 0.0))
	_check(exit_reach > 0.0, "read the arrival ring radius (%.4f u)" % exit_reach)
	var ring_in: int = _ring_covered(P2, exit_reach, funcref_shipped)
	_check(ring_in == 360,
		"the whole arrival ring at r=%.4f is inside the region (%d/360), so a rider can be put down on ANY side"
			% [exit_reach, ring_in])
	_check(exit_reach + _keepy_clearance <= radius + 1e-6 or exit_reach <= radius,
		"and it fits inside the lobe with %.4f u to spare" % (radius - exit_reach))

	# ---- IT MUST NOT HAVE GROWN ANYWHERE ELSE. Sampled where the north
	# lobe's own phase gates it, so a fat-fingered term shows as a leak.
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	_check(not HubRegion.contains(Vector3(40.0, 0.0, 40.0)), "past the square corner is still not walkable")
	_check(not HubRegion.contains(Vector3(0.0, 0.0, -(h + 0.5))), "the SOUTH edge did not move")
	_check(not HubRegion.contains(Vector3(h + 0.5, 0.0, 0.0)), "the EAST edge did not move")
	_check(not HubRegion.contains(Vector3(-(h + 0.5), 0.0, 0.0)), "the WEST edge did not move")
	# And the new ground stops where the disc does, at every azimuth.
	var just_out: int = 0
	for i in 360:
		var a: float = deg_to_rad(float(i))
		var p: Vector3 = centre + Vector3(cos(a), 0.0, sin(a)) * (radius + 0.05)
		if not HubRegion.contains(p) or absf(p.x) <= h and absf(p.z) <= h:
			just_out += 1
	_check(just_out == 360,
		"just outside the lobe rim is unwalkable except where the square already covers it (%d/360)" % just_out)

	# ---- CLAMP. A tap just past the tower has to resolve BESIDE it, not be
	# dragged back to the square edge -- which is the failure that would
	# look exactly like the lobe not existing.
	var beyond: Vector3 = centre + Vector3(0.0, 0.0, radius + 2.0)
	var answer: Vector3 = HubRegion.clamp_to(beyond)
	_check(HubRegion.contains(answer), "a tap past the lobe resolves onto walkable ground %s" % answer)
	_check(answer.distance_to(beyond) < 2.05,
		"and it answers the NEAREST feature (%.3f u), not the square edge %.3f u away"
			% [answer.distance_to(beyond), beyond.distance_to(Vector3(beyond.x, 0.0, h))])
	var held: int = 0
	for i in 360:
		var a: float = deg_to_rad(float(i))
		var p: Vector3 = centre + Vector3(cos(a), 0.0, sin(a)) * (radius * 0.8)
		if HubRegion.clamp_to(p).distance_to(p) < 1e-5:
			held += 1
	_check(held == 360, "a tap inside the lobe is left where it is (%d/360)" % held)

	# ---- THE TWO LOBES DO NOT TOUCH, so neither can be shadowing the
	# other's coverage. Reported with the number, because "they are far
	# apart" is exactly the kind of claim that stops being true silently.
	var north_gap: float = HubRegion.north_lobe_centre().distance_to(centre) \
		- HubRegion.NORTH_LOBE_RADIUS - radius
	_check(north_gap > 0.0,
		"the P2 lobe and the existing north lobe are disjoint (rim gap %.3f u)" % north_gap)
	print("")


## PHASE I -- THE WAITING BADGER STANDS BESIDE THE STAIR, NOT INSIDE IT.
##
## ⚠️ THIS PHASE EXISTS BECAUSE A DERIVED NUMBER SHIPPED AND WAS WRONG.
## `BADGER_SIDE_OFFSET` carried a comment claiming "+0.050 u clear of the
## rail", arrived at by multiplying a lateral extent recorded at one rig
## scale by the ratio of two later ones. Measured instead against the
## DRAWN stair on 4 septembre 2026, the true clearance at that offset was
## 0.0428 u -- a body all but touching a stringer -- and an earlier pass,
## run under `--headless`, had reported "comfortable" against four
## stringers all reading at the world origin. Both failures are of the
## same kind: a clearance nobody measured on the geometry a player sees.
##
## SO THIS PHASE MEASURES, and it measures the two things the derivation
## could not:
##
##   * the badger's SKINNED SILHOUETTE, ~10 000 vertices posed by the live
##     rig, not a width copied from a previous lot;
##   * against every DRAWN part near either stair foot -- the batched
##     stringers and treads (whence opengl3, per this file's header) AND
##     the layout's own decor, which is what actually caps the offset:
##     a bush at (29.869, 7.138) closes in from the far side, so the free
##     window at end 0 is bounded on BOTH sides and the best offset is an
##     argmax rather than "as far from the stair as you like".
##
## The gate is 0.15 u. Measured argmax is 0.1886 u at the shipped 1.10, so
## the threshold is a real 21 % cushion under the as-built figure and not a
## line drawn under it; and it rejects the old 0.95 by a factor of 4.4,
## which is what the blind pass below proves it can actually see.
const BADGER_STAND_CLEARANCE_MIN: float = 0.15

func _phase_i_badger_stand() -> void:
	print("PHASE I -- the waiting badger clears the drawn stair and its decor")
	var badger: Node3D = _hub_root._badger as Node3D
	_check(badger != null, "the badger is in the scene")
	if badger == null:
		print("")
		return
	var cloud: PackedVector3Array = _skinned_cloud(badger)
	# BLIND CHECK FIRST: an unread silhouette makes every distance below
	# infinite, and the phase would pass for free at any offset whatever.
	_check(cloud.size() > 1000,
		"BLIND CHECK: %d skinned vertices actually read off the live rig" % cloud.size())
	if cloud.is_empty():
		print("")
		return

	var offset: float = float(_hub_consts.get("BADGER_SIDE_OFFSET", 0.0))
	_check(offset > 0.0, "read HubWorld.BADGER_SIDE_OFFSET (%.3f)" % offset)
	var worst: float = INF
	var worst_where: String = ""
	for index in 2:
		var xf: Transform3D = _badger_stand_xform(badger, index, offset)
		var parts: Array = _parts_near(_props, badger, xf.origin, 8.0)
		_check(parts.size() > 4,
			"end %d: %d drawn parts stand within 8 u of the badger -- an empty list would pass this for free"
				% [index, parts.size()])
		var row: Array = _nearest_part(cloud, xf, parts, 0.0)
		print("      end %d: nearest drawn part %s at %.4f u" % [index, row[0], row[1]])
		if float(row[1]) < worst:
			worst = float(row[1])
			worst_where = "end %d, %s" % [index, row[0]]
	_check(worst >= BADGER_STAND_CLEARANCE_MIN,
		"the waiting badger clears every drawn part by %.4f u (worst: %s), gate %.2f"
			% [worst, worst_where, BADGER_STAND_CLEARANCE_MIN])

	# BLIND CHECK: the test must be able to SEE a body inside the stair.
	# Fatten the silhouette past the measured margin and the same test has
	# to report an intersection -- an assertion that has never failed
	# proves nothing, and this is the equality-shaped assertion CLAUDE.md
	# names as the one that passes for free.
	var fat: float = worst + 0.20
	var blind: float = INF
	for index in 2:
		var xf: Transform3D = _badger_stand_xform(badger, index, offset)
		blind = minf(blind, float(_nearest_part(cloud, xf,
			_parts_near(_props, badger, xf.origin, 8.0), fat)[1]))
	_check(blind <= 0.0,
		"BLIND CHECK: with the silhouette %.3f u fatter the same test reports %.4f u -- it can see a body inside the stair"
			% [fat, blind])

	# ---- THE TAP DISC AGAINST THE REGION CLAMP, at both ends.
	#
	# ⚠️ THIS IS THE HALF OF "MOVE THE BADGER" THAT IS SILENT. The disc is
	# asked on `aim`, UNCLAMPED, exactly as the funnel rule requires -- but
	# what HubTapInput then EMITS is the CLAMPED destination, and _try_zip
	# re-tests that landing against the same radius. So a tap the disc
	# ACCEPTS can still walk Keepy to a clamped point too far from the
	# badger to board: yes from the disc, no boarding, and no error
	# anywhere.
	#
	# ⚠️ AND IT ALREADY HAPPENS, AT END 1, AND IT IS NOT THIS LOT'S DOING.
	# End 1 stands 1.68 u past the plateau edge on a structure lobe of
	# radius 3.0, so part of its disc hangs over ground the clamp has to
	# drag back. Measured across the whole offset range on 4 septembre
	# 2026, with the shipped 1.80 radius:
	#
	#     offset   end 0 worst / lost      end 1 worst / lost
	#      0.95     1.8000 / ~0 %           2.4020 / 3.56 %   <- was shipped
	#      1.10     1.8000 / ~0 %           2.3925 / 3.88 %   <- ships now
	#      1.32     1.8000 / ~0 %           2.3785 / 4.75 %
	#
	# The defect is nearly flat in the offset and predates every value in
	# that table; end 0 is clean (its "lost" count is float noise at
	# exactly the radius). Fixing it means widening the P2 structure lobe
	# or narrowing the disc, which is a region change nobody asked this lot
	# for -- so it is REPORTED here rather than quietly gated green, and
	# what IS gated is that moving the badger does not make it worse.
	var worst_pull: float = 0.0
	var worst_pull_at: String = ""
	var base_pull: float = 0.0
	for index in 2:
		var towers: Array = _zipline()["towers"] as Array
		var pull: float = _clamped_disc_reach(
			_stand_point(towers[index], offset), ZiplineDoor.BOARD_TAP_RADIUS)
		# The same reading at the offset this constant carried before
		# 4 septembre 2026, recomputed live rather than typed in as a
		# remembered number.
		var was: float = _clamped_disc_reach(
			_stand_point(towers[index], 0.95), ZiplineDoor.BOARD_TAP_RADIUS)
		print("      end %d: furthest post-clamp landing %.4f u (was %.4f at offset 0.95), radius %.2f"
			% [index, pull, was, ZiplineDoor.BOARD_TAP_RADIUS])
		if pull > worst_pull:
			worst_pull = pull
			worst_pull_at = "end %d" % index
		base_pull = maxf(base_pull, was)
	_check(worst_pull <= base_pull + 0.001,
		"moving the badger does not widen the pre-existing end-1 clamp gap (%.4f u now, %.4f u at the old 0.95; worst end %s)"
			% [worst_pull, base_pull, worst_pull_at])

	# BLIND CHECK: an inequality that has never failed proves nothing.
	# Stand the same disc far out over the void, where the clamp HAS to
	# drag taps back, and the same helper must report a pull well past the
	# radius.
	var void_stand := Vector3(HubRegion.PLATEAU_HALF_EXTENT + 40.0, 0.0,
		-HubRegion.PLATEAU_HALF_EXTENT - 40.0)
	var void_pull: float = _clamped_disc_reach(void_stand, ZiplineDoor.BOARD_TAP_RADIUS)
	_check(void_pull > ZiplineDoor.BOARD_TAP_RADIUS,
		"BLIND CHECK: the same test reports %.3f u for a disc out over the void -- it can see a clamp that breaks boarding"
			% void_pull)
	print("")

## The furthest a point inside the boarding disc ends up from `centre`
## AFTER HubRegion.clamp_to. Equal to the radius when the whole disc is on
## walkable ground; larger when the clamp drags part of it away, which is
## the case that breaks boarding silently.
func _clamped_disc_reach(centre: Vector3, radius: float) -> float:
	var worst: float = 0.0
	for a in 72:
		var ang: float = TAU * float(a) / 72.0
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		for r in 12:
			var aim: Vector3 = centre + dir * (radius * float(r + 1) / 12.0)
			worst = maxf(worst, centre.distance_to(HubRegion.clamp_to(aim)))
	return worst

## The badger's stand transform at `index` for an arbitrary offset, built
## as a DELTA off the live body rather than restated from scratch: the rig
## scale and whatever facing convention HubActorWalker.face() uses come
## along untouched, and at the shipped offset and end 0 this IS the live
## transform. Restating them here would be the "a fact is published once,
## never retyped" failure in a probe.
func _badger_stand_xform(badger: Node3D, index: int, offset: float) -> Transform3D:
	var towers: Array = _zipline()["towers"] as Array
	var live_to: Vector3 = (towers[0]["position"] as Vector3) - badger.global_position
	live_to.y = 0.0
	var pos: Vector3 = _stand_point(towers[index] as Dictionary, offset)
	var to_tower: Vector3 = (towers[index]["position"] as Vector3) - pos
	to_tower.y = 0.0
	var delta: float = atan2(to_tower.x, to_tower.z) - atan2(live_to.x, live_to.z)
	return Transform3D(Basis(Vector3.UP, delta) * badger.global_transform.basis, pos)

## HubWorld._badger_rest with the constant lifted out, so the sweep and the
## gate move the SAME body the game places.
func _stand_point(tower: Dictionary, offset: float) -> Vector3:
	var forward: Vector3 = tower["forward"]
	var side := Vector3(forward.z, 0.0, -forward.x)
	var foot: Vector3 = tower["stair_foot"]
	return Vector3(foot.x, 0.0, foot.z) + side * offset

## Every drawn part within `reach` of `centre`, flat: individual meshes and
## each MultiMesh INSTANCE separately. The badger itself and the ground
## plane are excluded; nothing else is, because the cap on this offset
## turned out to be decor rather than the prop's own stair.
func _parts_near(n: Node, badger: Node3D, centre: Vector3, reach: float) -> Array:
	var out: Array = []
	_walk_near(n, badger, Vector3(centre.x, 0.0, centre.z), reach, out)
	return out

func _walk_near(n: Node, badger: Node3D, centre: Vector3, reach: float, out: Array) -> void:
	if n == badger or String(n.name).begins_with("Ground") \
			or String(n.name).begins_with("Water") or String(n.name).begins_with("Plateau"):
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null \
			and (n as MeshInstance3D).skin == null:
		_keep_near(String(n.name), (n as MeshInstance3D).global_transform,
			(n as MeshInstance3D).mesh.get_aabb(), centre, reach, out)
	elif n is MultiMeshInstance3D:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if mm != null and mm.mesh != null:
			for i in mm.instance_count:
				_keep_near("%s#%d" % [n.name, i],
					(n as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i),
					mm.mesh.get_aabb(), centre, reach, out)
	for c in n.get_children():
		_walk_near(c, badger, centre, reach, out)

func _keep_near(label: String, xform: Transform3D, aabb: AABB, centre: Vector3,
		reach: float, out: Array) -> void:
	var flat: Vector3 = xform * aabb.get_center()
	flat.y = 0.0
	if centre.distance_to(flat) - (xform.basis * aabb.size).length() * 0.5 > reach:
		return
	out.append([label, xform, aabb])

## Nearest drawn part to the silhouette placed at `xf`, as [label, distance].
## `fatten` grows the body, for the blind check.
##
## ⚠️ VERTEX AGAINST BOX, and a second channel was tried and dropped. Box
## CORNERS tested against the badger's own AABB reported 0.0000 for every
## part at every offset out to 2.05 u: an animated body's bounding box is
## mostly empty air, so a corner inside it is no evidence of a corner
## inside the body. It could not reproduce the 0.1198 u already on file for
## ZiplineStep#0 either, which is what exposed it.
func _nearest_part(cloud: PackedVector3Array, xf: Transform3D, parts: Array,
		fatten: float) -> Array:
	var best: float = INF
	var label: String = "-"
	for part in parts:
		var px: Transform3D = part[1]
		var aabb: AABB = part[2]
		var into: Transform3D = px.affine_inverse() * xf
		var bmin: Vector3 = aabb.position
		var bmax: Vector3 = aabb.position + aabb.size
		var here: float = INF
		for v in cloud:
			var p: Vector3 = into * v
			var d := Vector3(
				maxf(maxf(bmin.x - p.x, p.x - bmax.x), 0.0),
				maxf(maxf(bmin.y - p.y, p.y - bmax.y), 0.0),
				maxf(maxf(bmin.z - p.z, p.z - bmax.z), 0.0))
			here = minf(here, d.length())
			if here <= fatten:
				break
		here = maxf(here - fatten, 0.0) if here > fatten else 0.0
		if here < best:
			best = here
			label = String(part[0])
	return [label, best]

## The badger's drawn silhouette in its OWN NODE frame, skinned off the
## live rig.
##
## ⚠️ IN THE NODE'S FRAME, NOT THE SKELETON'S. CLAUDE.md's rig-scale trap
## is that a scale carried on the node gets counted TWICE when a
## measurement goes through skel.global_transform and is then re-multiplied
## by that scale; composing straight into the node frame cannot make that
## mistake.
func _skinned_cloud(badger: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var to_node: Transform3D = badger.global_transform.affine_inverse()
	for mi in _skinned_meshes(badger):
		var skel: Skeleton3D = mi.get_node_or_null(mi.skeleton) as Skeleton3D
		if skel == null:
			continue
		var binds: Array[Transform3D] = []
		for b in mi.skin.get_bind_count():
			var idx: int = mi.skin.get_bind_bone(b)
			var nm: StringName = mi.skin.get_bind_name(b)
			if nm != &"":
				idx = skel.find_bone(nm)
			binds.append(Transform3D.IDENTITY if idx < 0
				else skel.get_bone_global_pose(idx) * mi.skin.get_bind_pose(b))
		var into: Transform3D = to_node * skel.global_transform
		for surf in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(surf)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or bones.is_empty():
				continue
			var per: int = bones.size() / verts.size()
			for v in verts.size():
				var acc := Vector3.ZERO
				var total: float = 0.0
				for k in per:
					var w: float = weights[v * per + k]
					if w <= 0.0:
						continue
					var bi: int = bones[v * per + k]
					if bi < 0 or bi >= binds.size():
						continue
					acc += binds[bi] * verts[v] * w
					total += w
				if total > 0.0:
					out.append(into * (acc / total))
	return out

func _skinned_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null \
			and (n as MeshInstance3D).skin != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_skinned_meshes(c))
	return out

## The region AS IT SHIPPED BEFORE the structure lobes: square, north lobe,
## shore pad. Spelled out rather than reached through a switch in
## HubRegion, because a probe able to turn the shipped region off is a
## probe able to leave it off.
func _legacy_contains(point: Vector3) -> bool:
	var flat := Vector3(point.x, 0.0, point.z)
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	if absf(flat.x) <= h and absf(flat.z) <= h:
		return true
	if flat.distance_to(HubRegion.north_lobe_centre()) <= HubRegion.NORTH_LOBE_RADIUS:
		return true
	return flat.distance_to(HubRegion.near_bank()) <= HubRegion.SHORE_PAD_RADIUS

func _shipped_contains(point: Vector3) -> bool:
	return HubRegion.contains(point)

## How many of 360 azimuths at `radius` around `centre` the given membership
## test admits. One helper for both the blind check and the positive, so the
## two cannot be measuring subtly different rings.
func _ring_covered(centre: Vector3, radius: float, test: Callable) -> int:
	var n: int = 0
	for i in 360:
		var a: float = deg_to_rad(float(i))
		if test.call(centre + Vector3(cos(a), 0.0, sin(a)) * radius):
			n += 1
	return n

## HubBuilder constant, through the constant map: Object.get("SOME_CONST")
## returns null for a GDScript const, silently.
func _c(name: String) -> float:
	return float(_consts.get(name, 0.0))
