extends Node

## Gates the north lobe and the seesaw: the first time the walkable hub grew
## by SHAPE rather than by a bigger number, and the second prop on the
## plateau that answers a landing.
##
## WHY GATED AND NOT MERELY REPORTED. Every way either half fails is SILENT.
## A union term that never fires, a clamp that returns a point the region
## does not contain, a registry that comes back empty, a MultiMesh left at
## Godot's default TRANSFORM_2D (which discards every transform written to
## it and draws the batch at the origin), a trigger hooked below one of the
## early returns in _on_hop_landed, a dismount that comes down inside the
## trigger radius and remounts for ever -- not one of those raises, breaks a
## build, or looks like anything but "the lobe was never switched on".
##
## ⚠️ WHAT THIS PROBE CANNOT DECIDE. It measures ANGLES, HEIGHTS and NODES,
## never how a rock READS. Whether a plank tipping 15 degrees two and a half
## times over 2.4 seconds looks like a seesaw answering a weight, or like a
## prop glitching, is a device judgement -- and so is whether a lobe behind
## the spawn reads as somewhere to go at all.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")

## Measured on the shipped tree, before and after, in ONE session on an idle
## machine -- never carried over from another batch's note. 124 -> 127
## excluding portals: the fulcrum, the plank, and ONE MultiMesh node for
## however many grips there are. Itemised rather than stated, so a fourth
## node has to be explained rather than absorbed.
## 127 -> 128 on 28 aout 2026: the first Meshy model on this plateau, one
## static, decorative owl -- ONE MeshInstance3D (the .glb's own mesh) under
## a wrapping, non-drawing Node3D. Not batched: there is only one.
## 128 -> 129 on 28 aout 2026: the cabin, the second Meshy model on this
## plateau -- ONE MeshInstance3D (the .glb's own mesh) under a wrapping,
## non-drawing Node3D, on the owl's terms. Not batched: there is only one,
## and nothing about it is ever animated.
## 129 -> 131 on 29 aout 2026: the cabin's DOORSTEP MARK out on the lawn,
## the fourth ring on this plateau that means "a tap takes you elsewhere".
## +2 and not +3: a CabinMarker builds a pad, a ring and a Label3D, and a
## Label3D is not a MeshInstance3D nor a MultiMesh, so this counter -- by
## its own definition, see _count_draw -- never saw the sign. One mark per
## cabin, and the layout ships one cabin.
## 131 -> 132 on 31 aout 2026: THE MAGPIE, drawn inside the cabin's cutaway
## view so the plateau shows the same living room the interior does -- ONE
## MeshInstance3D (the .glb carries one node, one mesh, one primitive,
## measured off the file) under the cabin's own root. Not batched: there is
## only one, and it is pure scenery -- no hotspot, no tap radius, nothing
## registered.
## 132 -> 141 on 3 septembre 2026, ITEMISED on the same terms: the
## zipline's TIER 1 structure. FIVE MeshInstance3D of its own -- a deck and
## a head beam at each of the two towers, plus the ONE cable between them
## -- and FOUR shared MultiMeshInstance3D: legs, masts, treads and
## stringers, one node each for however many towers the layout ships. That
## batching is the whole difference between +9 and +25: eight legs, four
## masts, eight treads and four stringers cost four nodes between them.
## 141 -> 144 on 3 septembre 2026, ITEMISED on the same terms: the
## zipline's TIER 2 trolley. THREE MeshInstance3D -- a pulley on the wire,
## a stem, and the grab bar the two riders hang from. The badger that rides
## it is NOT in this count and cannot be: it lives under `World/` beside
## Keepy and the bear, not under `World/Props`, so this budget structurally
## cannot see it.
const _EXPECTED_DRAW_NODES_EXCL_PORTALS: int = 144

var _failures: int = 0
var _hub: Node = null
var _props: Node3D = null
var _keepy: KeepyHopper = null
var _hops: int = 0
var _trip_done: bool = false

func _ready() -> void:
	ProbeWatchdog.arm(self, "SeesawProbe")
	_hub = HUB_SCENE.instantiate()
	add_child(_hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_props = _hub.get_node("WorldViewport/SubViewport/World/Props")
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy")

	_phase_lobe()
	_phase_clamp()
	# BEFORE anything touches Keepy. The ride phases below leave him on a
	# plank with a live tween, and hop_to() is refused in that state -- a
	# crossing measured after them times a journey that never started. The
	# first draft did exactly that and reported the square diagonal as
	# 1 hop / 83.333 s, which is what a refused hop_to looks like.
	await _phase_crossing()
	_phase_geometry()
	await _phase_ride()
	await _phase_exit()
	await _phase_gate()
	_phase_budget()

	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	print("  %s  %s" % ["OK  " if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _registry() -> Array[Dictionary]:
	return _props.seesaws()

func _const(source: Object, name: String, fallback: float = 0.0) -> float:
	var map: Dictionary = source.get_script().get_script_constant_map()
	return float(map.get(name, fallback))

## Drops Keepy at a point and emits the landing HubWorld listens for -- the
## SAME signal an ordinary hop's arrival emits. Nothing here reaches into
## HubWorld's handler: the wiring is part of what is under test.
func _land_at(point: Vector3) -> void:
	_keepy.global_position = Vector3(point.x, 0.0, point.z)
	_keepy.hop_landed.emit(_keepy.global_position)
	await get_tree().process_frame

## =====================================================================
## PHASE LOBE -- the region really did grow, and only where it should have.
func _phase_lobe() -> void:
	print("--- PHASE LOBE: the shape ---")
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	var r: float = HubRegion.NORTH_LOBE_RADIUS
	var c: Vector3 = HubRegion.north_lobe_centre()

	# The centre is ON the north edge, DERIVED. A literal 35 here would be a
	# second spelling of the half-extent, free to drift from it.
	_check(absf(c.x) < 1e-6 and absf(c.z - h) < 1e-6,
		"the lobe centre is the middle of the +Z edge: %s (half-extent %.1f)" % [c, h])

	# POSITIVE FIRST. "nothing outside" passes for free against a term that
	# never fires, so the ground has to be proved to exist before its
	# boundary means anything.
	_check(HubRegion.contains(Vector3(0.0, 0.0, h + r - 0.05)),
		"the lobe's far tip IS walkable at z = %.2f, past the square edge" % (h + r - 0.05))
	_check(not HubRegion.contains(Vector3(0.0, 0.0, h + r + 0.05)),
		"and one step past the tip is not")

	# Every azimuth, so a lobe that only worked straight ahead is caught.
	var inside: int = 0
	var outside: int = 0
	for i in 721:
		var a: float = deg_to_rad(float(i) * 0.5)
		var d := Vector3(cos(a), 0.0, sin(a))
		if HubRegion.contains(c + d * (r - 0.05)):
			inside += 1
		if not HubRegion.contains(c + d * (r + 0.05)):
			outside += 1
	_check(inside == 721, "every azimuth is walkable just inside the rim (%d/721)" % inside)
	# The rim is only OUTSIDE where the square does not already cover it --
	# the inner half is square, and that is the point of unioning a whole
	# disc rather than half of one.
	var covered: int = 0
	for i in 721:
		var a: float = deg_to_rad(float(i) * 0.5)
		var p: Vector3 = c + Vector3(cos(a), 0.0, sin(a)) * (r + 0.05)
		if absf(p.x) <= h and absf(p.z) <= h:
			covered += 1
	_check(outside + covered >= 721,
		"and just outside the rim is unwalkable except where the square already covers it (%d + %d of 721)"
			% [outside, covered])

	# It must not have grown anywhere ELSE. Sampled where the previous batch
	# gated it, so a fat-fingered term shows up as the square leaking.
	_check(not HubRegion.contains(Vector3(40.0, 0.0, 40.0)), "past the square corner is still not walkable")
	_check(not HubRegion.contains(Vector3(0.0, 0.0, -(h + 0.5))), "the SOUTH edge did not move")
	_check(not HubRegion.contains(Vector3(h + 0.5, 0.0, 0.0)), "the EAST edge did not move")
	_check(not HubRegion.contains(Vector3(-(h + 0.5), 0.0, 0.0)), "the WEST edge did not move")

	# The area, measured on the shipped contains() rather than computed from
	# the radius: the number in the docs has to be the number the region
	# actually draws.
	var step: float = 0.1
	var new_cells: int = 0
	var x: float = -r
	while x <= r:
		var z: float = h
		while z <= h + r:
			if HubRegion.contains(Vector3(x, 0.0, z)) and z > h:
				new_cells += 1
			z += step
		x += step
	var area: float = float(new_cells) * step * step
	var square_area: float = (2.0 * h) * (2.0 * h)
	print("    new walkable ground = %.2f u2 = %.3f%% of the %.0f u2 square (analytic half-disc %.2f)"
		% [area, 100.0 * area / square_area, square_area, PI * r * r * 0.5])
	_check(absf(area - PI * r * r * 0.5) < 3.0,
		"and it measures as a half disc, within sampling error")
	print("")

## =====================================================================
## PHASE CLAMP -- the three call sites follow AUTOMATICALLY, which is the
## whole value proposition of unioning rather than adding a second zone.
## Confirmed rather than assumed, as the brief asked.
func _phase_clamp() -> void:
	print("--- PHASE CLAMP: clamp_to and the shipped call sites ---")
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	var r: float = HubRegion.NORTH_LOBE_RADIUS
	var c: Vector3 = HubRegion.north_lobe_centre()

	# A point already in the lobe must come back UNMOVED -- otherwise a tap
	# on the new ground would still be dragged to the old edge, which is
	# exactly the failure that would look like the lobe not existing.
	var held: int = 0
	for i in 361:
		var a: float = deg_to_rad(float(i))
		var p: Vector3 = c + Vector3(cos(a), 0.0, sin(a)) * (r * 0.8)
		if HubRegion.clamp_to(p).distance_to(p) < 1e-5:
			held += 1
	_check(held == 361, "a tap inside the lobe is left where it is (%d/361)" % held)

	# A point beyond it is pulled IN, to a point the region really contains,
	# and clamping the answer again is a no-op.
	var pulled: int = 0
	var idempotent: int = 0
	for i in 361:
		var a: float = deg_to_rad(float(i))
		var p: Vector3 = c + Vector3(cos(a), 0.0, sin(a)) * (r + 25.0)
		var q: Vector3 = HubRegion.clamp_to(p)
		if HubRegion.contains(q):
			pulled += 1
		if HubRegion.clamp_to(q).distance_to(q) < 1e-5:
			idempotent += 1
	_check(pulled == 361, "a tap past the lobe resolves onto walkable ground (%d/361)" % pulled)
	_check(idempotent == 361, "and clamping that answer again moves it nowhere (%d/361)" % idempotent)

	# THE NEAREST POINT, not merely A point. A union that appended the lobe
	# without comparing distances would answer the square's edge for a tap
	# just past the lobe's tip -- 12 u away instead of a few centimetres.
	var beyond_tip := Vector3(0.0, 0.0, h + r + 4.0)
	var answer: Vector3 = HubRegion.clamp_to(beyond_tip)
	_check(answer.distance_to(beyond_tip) < 4.05,
		"and it answers the NEAREST feature: %s -> %s (%.3f u, not the square edge %.3f u away)"
			% [beyond_tip, answer, answer.distance_to(beyond_tip), beyond_tip.distance_to(Vector3(0.0, 0.0, h))])

	# The builder's own reachability question is contains(), so the lobe's
	# props are walkable to by the same fact the tap path uses. Verified on
	# the layout as built rather than asserted about it: a boot that warned
	# would have printed, and a probe that only trusted the absence of a
	# warning would be trusting stderr.
	var lobe_props: int = 0
	for entry in _props.ground_footprints():
		var p: Vector3 = entry["position"]
		if p.z > h:
			lobe_props += 1
			if not HubRegion.contains(p):
				_check(false, "a prop in the new ground is unreachable: %s" % p)
	_check(lobe_props > 0, "the new ground carries %d props, and every one is walkable to" % lobe_props)
	print("")

## =====================================================================
## PHASE GEOMETRY -- the prop as BUILT, and the inequality that keeps the
## plank out of the ground.
func _phase_geometry() -> void:
	print("--- PHASE GEOMETRY: the seesaw as built ---")
	var reg := _registry()
	_check(reg.size() >= 1, "the registry publishes %d seesaw(s)" % reg.size())
	if reg.is_empty():
		print("")
		return

	for index in reg.size():
		var entry: Dictionary = reg[index]
		var pivot: Node3D = entry["pivot"]
		_check(pivot != null and is_instance_valid(pivot), "seesaw %d: the pivot resolves" % index)
		if pivot == null:
			continue
		var root: Node3D = pivot.get_parent()

		# THE FULCRUM IS OUTSIDE THE PIVOT. A tilt is only legible against
		# something that stays put, so this is a contract and not a detail.
		_check(root.has_node("Fulcrum") and root.get_node("Fulcrum").get_parent() == root,
			"seesaw %d: the fulcrum is a sibling of the pivot, not a child of it" % index)
		_check(pivot.has_node("Plank"), "seesaw %d: the plank is UNDER the pivot" % index)
		_check(pivot.has_node("Grips"), "seesaw %d: the grips are UNDER the pivot" % index)

		var grips: MultiMeshInstance3D = pivot.get_node("Grips")
		var mm: MultiMesh = grips.multimesh
		# The default is TRANSFORM_2D, and a batch left on it draws every
		# instance at the origin with no error attached.
		_check(mm.transform_format == MultiMesh.TRANSFORM_3D,
			"seesaw %d: the grip batch is TRANSFORM_3D" % index)
		_check(mm.instance_count == int(_const(_props, "SEESAW_GRIPS", 2)),
			"seesaw %d: %d grip instances in ONE node" % [index, mm.instance_count])
		_check(mm.custom_aabb.size.length() > 0.001,
			"seesaw %d: the batch carries a written AABB (%s)" % [index, mm.custom_aabb.size])

		var plank_len: float = _const(_props, "SEESAW_PLANK_LENGTH")
		var plank_th: float = _const(_props, "SEESAW_PLANK_THICKNESS")
		var fulcrum: float = _const(_props, "SEESAW_FULCRUM_HEIGHT")
		var tilt: float = _const(_hub, "SEESAW_TILT_DEG", 15.0)
		# ⚠️ THE ONE INEQUALITY THAT KEEPS THE PLANK ABOVE THE GROUND at full
		# tilt. Gated rather than argued, so a later batch that lengthens the
		# plank or deepens the rock is told instead of left to sink it.
		var lowest: float = fulcrum - (plank_len * 0.5) * sin(deg_to_rad(tilt)) \
			- (plank_th * 0.5) * cos(deg_to_rad(tilt))
		_check(lowest > 0.0,
			"seesaw %d: at %.1f deg the plank's low corner sits at y = %.4f, above the ground"
				% [index, tilt, lowest])

		_check(entry["seat_y"] > 0.0 and absf(float(entry["seat_y"]) - plank_th * 0.5) < 1e-5,
			"seesaw %d: the seat is the TOP of the plank (%.4f), not its centre" % [index, entry["seat_y"]])
		_check(float(entry["ride_x"]) < plank_len * 0.5,
			"seesaw %d: the rider sits ON the plank (%.2f of a %.2f half-length)"
				% [index, entry["ride_x"], plank_len * 0.5])
		_check(float(entry["radius"]) > float(entry["clear_radius"]),
			"seesaw %d: the trigger radius %.2f covers the plank's %.2f"
				% [index, entry["radius"], entry["clear_radius"]])

		# It is in the new ground -- which is what the lobe was added for.
		var pos: Vector3 = entry["position"]
		_check(pos.z > HubRegion.PLATEAU_HALF_EXTENT,
			"seesaw %d: it stands in the NEW ground at %s" % [index, pos])
		_check(HubRegion.contains(pos), "seesaw %d: and that ground is walkable" % index)
	print("")

## =====================================================================
## PHASE RIDE -- a landing rocks it, gets on it, and is carried BY it.
func _phase_ride() -> void:
	print("--- PHASE RIDE: landing, mount, carry ---")
	var reg := _registry()
	if reg.is_empty():
		print("")
		return
	var entry: Dictionary = reg[0]
	var pivot: Node3D = entry["pivot"]
	var pos: Vector3 = entry["position"]

	# Approach from the SOUTH, which is how a player reaches it.
	var arrive: Vector3 = pos + Vector3(-float(entry["ride_x"]), 0.0, -0.4)
	await _land_at(arrive)
	_check(_keepy.is_on_seesaw(), "a landing on the plank puts him ON it")
	_check(absf(pivot.rotation_degrees.z) > 0.5,
		"and the plank is tilting: %.2f deg" % pivot.rotation_degrees.z)

	# HIS END GOES DOWN. That is the whole reading of a seesaw, and the sign
	# is the one thing a mirrored basis would silently get backwards.
	var local: Vector3 = pivot.to_local(_keepy.global_position)
	_check(local.x < 0.0, "he sat on the end he arrived at (local x = %.3f)" % local.x)
	_check(_keepy.global_position.y < float(entry["seat_y"]) + _const(_props, "SEESAW_FULCRUM_HEIGHT"),
		"and HIS end is the one that went down: seat y = %.4f" % _keepy.global_position.y)

	# CARRIED, not merely near. The rider is written in the same call as the
	# angle, so his world position must equal the pivot's transform of the
	# FIXED seat offset at every sample -- a rider on his own clock was
	# measured a whole frame behind on the turnstile.
	#
	# ⚠️ AGAINST THE FIXED SEAT, never against a round trip of his own
	# position. The first draft compared him to
	# pivot.to_global(pivot.to_local(HIS POSITION)), which is the identity
	# and therefore zero however badly he had been left behind -- it stayed
	# green with the rider write deliberately removed. Only the blind check
	# caught that, which is the whole reason it is there.
	var seat := Vector3(signf(local.x) * float(entry["ride_x"]), float(entry["seat_y"]), 0.0)
	var worst: float = 0.0
	var moved: float = 0.0
	var first: Vector3 = _keepy.global_position
	for i in 40:
		await get_tree().process_frame
		if not _keepy.is_on_seesaw():
			break
		var want: Vector3 = pivot.to_global(seat)
		worst = maxf(worst, _keepy.global_position.distance_to(want))
		moved = maxf(moved, want.distance_to(first))
	# BLIND CHECK: "he tracks the plank" passes for free against a rider who
	# never moved at all, so the tracking number is only worth reading once
	# the seat is known to have travelled.
	_check(moved > 0.05, "BLIND CHECK: the seat really travelled (%.4f u), so the number below means something" % moved)
	_check(worst < 0.001, "he is carried by the plank, not alongside it (worst %.6f u)" % worst)
	print("")

## =====================================================================
## PHASE EXIT -- the seat is HELD through the settle, and a tap elsewhere is
## what ends the ride.
##
## ⚠️ REWRITTEN 2 SEPTEMBRE 2026 (lot E), NOT SILENCED. Until then the first
## assertion here was `not _keepy.is_on_seesaw()` -- "the rock settles and
## he is let off". It did not rot: it was DELIBERATELY made false, because
## the settle no longer dismounts anyone. What it used to guard is split in
## two and both halves are asserted below -- that he keeps the seat when the
## rock ends, and that the tap which does end it puts him down on legal
## ground outside the trigger radius, exactly as the old settle had to.
func _phase_exit() -> void:
	print("--- PHASE EXIT: the seat is held, the tap is the exit ---")
	var reg := _registry()
	if reg.is_empty():
		print("")
		return
	var entry: Dictionary = reg[0]
	var pivot: Node3D = entry["pivot"]
	var rock_s: float = _const(_hub, "SEESAW_ROCK_S", 2.4)

	if not _keepy.is_on_seesaw():
		await _land_at(entry["position"] as Vector3 + Vector3(-float(entry["ride_x"]), 0.0, -0.4))
	await get_tree().create_timer(rock_s + 0.6).timeout
	await get_tree().process_frame

	_check(_keepy.is_on_seesaw(), "the rock settles and he KEEPS the seat")
	_check(absf(pivot.rotation_degrees.z) < 0.01,
		"and the plank is left LEVEL, by arithmetic rather than by tuning (%.4f deg)" % pivot.rotation_degrees.z)
	var held: bool = _keepy.is_on_seesaw()
	await get_tree().create_timer(rock_s).timeout
	_check(held and _keepy.is_on_seesaw(),
		"and a whole further rock-length later he is STILL on it, so nothing times him out")

	if not _keepy.is_on_seesaw():
		_check(false, "could not hold a seat to test the exit from")
		print("")
		return

	# The dismount LANDING is what the radius check below is about, and the
	# walk carries him past it -- so it is captured as it happens rather
	# than inferred from where he ends up.
	var pos: Vector3 = entry["position"]
	var destination: Vector3 = pos + Vector3(0.0, 0.0, -(float(entry["radius"]) + 6.0))
	var landings: Array[Vector3] = []
	var on_land := func(p: Vector3) -> void: landings.append(p)
	var idle: Array[bool] = [false]
	var on_idle := func() -> void: idle[0] = true
	_keepy.hop_landed.connect(on_land)
	_keepy.became_idle.connect(on_idle)
	_hub.call("_on_tapped_ground", destination)
	var frames: int = 0
	while not idle[0] and frames < 1200:
		await get_tree().process_frame
		frames += 1
	_keepy.hop_landed.disconnect(on_land)
	_keepy.became_idle.disconnect(on_idle)

	_check(not _keepy.is_on_seesaw(), "a tap OFF the prop ends the ride")
	_check(absf(pivot.rotation_degrees.z) < 0.01,
		"and leaves the plank level behind him (%.4f deg)" % pivot.rotation_degrees.z)
	_check(absf(_keepy.global_position.y) < 0.01,
		"he is back on the ground (y = %.4f)" % _keepy.global_position.y)
	_check(HubRegion.contains(_keepy.global_position),
		"he ends inside the walkable region: %s" % _keepy.global_position)
	# ⚠️ THE LOOP THIS FEATURE WOULD OTHERWISE HAVE. A dismount ends in an
	# ordinary landing, and an ordinary landing near the prop is what mounts
	# him -- so the exit has to clear the TRIGGER radius, not the plank.
	_check(landings.size() > 0, "the dismount produced a landing to measure (%d)" % landings.size())
	if landings.size() > 0:
		var first: Vector3 = landings[0]
		var flat := Vector3(first.x, 0.0, first.z)
		_check(flat.distance_to(pos) > float(entry["radius"]),
			"and it lands OUTSIDE the trigger radius (%.3f u vs %.2f), so the dismount cannot remount him"
				% [flat.distance_to(pos), entry["radius"]])
	# THE BOAT'S RULE, and the half of it this phase exists to prove: one
	# tap bought the dismount AND the walk to where it pointed.
	var here := Vector3(_keepy.global_position.x, 0.0, _keepy.global_position.z)
	_check(here.distance_to(destination) < 1.0,
		"and the tap he left on is also where he WENT (%.3f u from it)" % here.distance_to(destination))
	await get_tree().process_frame
	_check(not _keepy.is_on_seesaw(), "and a frame later he is still off it")
	print("")

## =====================================================================
## PHASE GATE -- what must NOT rock it.
func _phase_gate() -> void:
	print("--- PHASE GATE: refusals ---")
	var reg := _registry()
	if reg.is_empty():
		print("")
		return
	var entry: Dictionary = reg[0]
	var pivot: Node3D = entry["pivot"]

	# Wait out anything still running, then park it level so the refusals
	# below are measured against a plank that is genuinely at rest.
	await get_tree().create_timer(_const(_hub, "SEESAW_ROCK_S", 2.4) + 0.6).timeout
	var away := Vector3(0.0, 0.0, 0.0)
	await _land_at(away)
	await get_tree().create_timer(0.2).timeout
	pivot.rotation_degrees.z = 0.0
	await get_tree().process_frame

	# BLIND CHECK FIRST, and this is the one that matters: "a far landing
	# does not rock it" passes for free against a trigger that was never
	# wired at all. Proving it CAN fire is what earns the right to assert
	# that it did not.
	var pos: Vector3 = entry["position"]
	await _land_at(pos + Vector3(0.0, 0.0, -0.5))
	_check(absf(pivot.rotation_degrees.z) > 0.5 or _keepy.is_on_seesaw(),
		"BLIND CHECK: a landing at the prop DOES set it going")

	# ⚠️ THE BLIND CHECK NOW LEAVES HIM SEATED, so getting him off again is a
	# step of its own. Before lot E the rock's own end handed him back and
	# `_land_at` could simply teleport him elsewhere; since the seat outlives
	# the rock, `hop_to` is refused while ON_SEESAW and a teleport would leave
	# the state behind -- so the way down is the shipped one, a tap off the
	# prop, waited out to idle. Asserting he actually got off is the thing
	# that stops the refusal below from passing for free against a Keepy who
	# was still aboard the whole time.
	await get_tree().create_timer(_const(_hub, "SEESAW_ROCK_S", 2.4) + 0.6).timeout
	_hub.call("_on_tapped_ground", away)
	var settle := 0
	while (_keepy.is_on_seesaw() or _keepy.is_hopping()) and settle < 1200:
		await get_tree().process_frame
		settle += 1
	_check(not _keepy.is_on_seesaw(), "and the shipped exit gets him back down again")
	await _land_at(away)
	await get_tree().create_timer(0.2).timeout
	pivot.rotation_degrees.z = 0.0
	await get_tree().process_frame

	var far: Vector3 = pos + Vector3(0.0, 0.0, -(float(entry["radius"]) + 6.0))
	await _land_at(far)
	_check(not _keepy.is_on_seesaw(), "a landing well outside the radius does not mount him")
	_check(absf(pivot.rotation_degrees.z) < 0.01,
		"and does not rock the plank (%.4f deg)" % pivot.rotation_degrees.z)

	# A tap while aboard is intercepted BY STATE. It is still never a
	# destination reached by walking THROUGH the prop -- but since lot E the
	# one that misses the prop is not dropped either, so the two cases are
	# asserted separately.
	await _land_at(pos + Vector3(0.0, 0.0, -0.5))
	if _keepy.is_on_seesaw():
		# A FRESH TWEEN, not "the angle is still a number". Comparing angles
		# would pass against a tap that was swallowed, which is the exact
		# defect the turnstile batch was written to fix -- so the thing
		# asserted is that the old tween was killed and a different object
		# replaced it.
		var ride: Dictionary = _hub.get("_seesaw_ride")
		var before: Tween = ride.get("tween")
		_hub.call("_on_tapped_ground", pos + Vector3(0.0, 0.0, -0.5))
		await get_tree().process_frame
		var after: Tween = (_hub.get("_seesaw_ride") as Dictionary).get("tween")
		_check(_keepy.is_on_seesaw(), "a tap on the SAME prop leaves him aboard")
		_check(after != null and after != before,
			"and re-pumps it with a FRESH tween instead of swallowing the tap")
		_check(before == null or not before.is_valid() or not before.is_running(),
			"killing the old tween, so no stray dismount can fire from it")
		# ⚠️ REWRITTEN 2 SEPTEMBRE 2026 (lot E). This used to assert "a tap
		# far away while aboard does not walk him off" -- true while the
		# rock owned the exit, and deliberately false now that the seat is
		# held: with no timer to let him go, a dropped tap would be a body
		# with no way out at all. It ORDERS AFTER the re-pump checks above
		# because it ends the ride they need.
		_hub.call("_on_tapped_ground", Vector3(0.0, 0.0, 20.0))
		await get_tree().process_frame
		_check(not _keepy.is_on_seesaw(),
			"and a tap far away while aboard now ENDS the ride instead of being dropped")
	else:
		_check(false, "could not re-mount for the tap-interception checks")
	print("")

## =====================================================================
## PHASE CROSSING -- the reason a LOBE is affordable where a wider square is
## not, measured on the real hopper rather than argued.
##
## A square that grew would spend the whole remaining crossing budget: the
## lot D recon measured half-extent 40 at 21.533 s and 41 at 22.100 s
## against the 22 s this project holds itself to. A lobe bolted onto an EDGE
## adds no length to a diagonal between CORNERS -- which is a claim about
## geometry, so it is walked rather than asserted.
func _phase_crossing() -> void:
	print("--- PHASE CROSSING: the shipped hopper at --fixed-fps 60 ---")
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	var r: float = HubRegion.NORTH_LOBE_RADIUS

	# Reproduce the published diagonal FIRST. A bench that cannot restate a
	# number already in the record has no standing to report a new one.
	var diagonal: float = await _trip("square diagonal (published 66 hops / 18.700 s)",
		Vector3(-h, 0.0, -h), Vector3(h, 0.0, h))
	# The farthest pair the LOBE creates: the far corner to the lobe's tip.
	var lobe: float = await _trip("far corner -> lobe tip",
		Vector3(-h, 0.0, -h), Vector3(0.0, 0.0, h + r))
	_check(diagonal <= 18.75 and diagonal >= 18.65,
		"the diagonal reproduces at %.3f s, so this bench can be believed" % diagonal)
	_check(lobe < diagonal,
		"and the lobe's worst trip is SHORTER (%.3f s < %.3f s): the diagonal is still the hub's worst walk"
			% [lobe, diagonal])
	_check(diagonal < 22.0, "which is inside the 22 s budget (%.3f s)" % diagonal)

	# ⚠️ THE DIAGONAL WALKS THROUGH A PORTAL, and a portal that is entered
	# opens the confirm dialog -- after which _on_tapped_ground returns at
	# its very first guard and every later tap in this file is swallowed.
	# Found by the phases below going red on a shipped build that was fine:
	# the re-pump checks reported a tap doing nothing, which is exactly what
	# a tap arriving under an open dialog does. Closed here rather than
	# routed around, because walking the REAL worst pair is the point of the
	# phase and any detour would measure a different trip.
	# Reached through HubWorld's own reference rather than by node path: the
	# path is scene layout, and this probe has no business knowing it.
	var dialog: Node = _hub.get("_confirm")
	if dialog.call("is_open"):
		dialog.call("close")
		await get_tree().process_frame
	_check(not dialog.call("is_open"),
		"and the confirm dialog the diagonal walked into is closed again, so later phases see live taps")
	print("")

func _trip(label: String, start: Vector3, target: Vector3) -> float:
	# Full idleness, not merely "not hopping": a body parked on a prop is
	# not hopping either, and hop_to() is refused for it just the same.
	var settle: int = 0
	while (_keepy.is_hopping() or _keepy.is_on_seesaw() or _keepy.is_on_turnstile()) and settle < 5000:
		await get_tree().process_frame
		settle += 1
	_keepy.global_position = Vector3(start.x, 0.0, start.z)
	await get_tree().process_frame
	_hops = 0
	_trip_done = false
	_keepy.hop_landed.connect(_on_trip_hop)
	_keepy.became_idle.connect(_on_trip_idle)
	_keepy.hop_to(target)
	var frames: int = 0
	while not _trip_done and frames < 5000:
		await get_tree().process_frame
		frames += 1
	_keepy.hop_landed.disconnect(_on_trip_hop)
	_keepy.became_idle.disconnect(_on_trip_idle)
	# WALL-CLOCK frames, never hops x HOP_DURATION: a 0.28 s hop occupies 17
	# frames (0.2833 s), so every trip costs ~1.2% more than the nominal
	# arithmetic predicts.
	var seconds: float = float(frames) / 60.0
	print("    %-46s %3d hops  %4d frames  %6.3f s" % [label, _hops, frames, seconds])
	return seconds

func _on_trip_hop(_p: Vector3) -> void:
	_hops += 1

func _on_trip_idle() -> void:
	_trip_done = true

## =====================================================================
## PHASE BUDGET -- itemised, so a fourth node has to be explained.
func _phase_budget() -> void:
	print("--- PHASE BUDGET ---")
	var total: int = _count_draw(_props)
	var portal_nodes: int = 0
	# props.portals() and not a name test: the established way every other
	# probe on this screen counts them, so all of them are counting the same
	# set.
	for portal in _props.portals():
		portal_nodes += _count_draw(portal)
	var excl: int = total - portal_nodes
	print("    draw nodes: %d total in Props, %d inside portals, %d excluding portals"
		% [total, portal_nodes, excl])
	_check(excl == _EXPECTED_DRAW_NODES_EXCL_PORTALS,
		"draw nodes excluding portals = %d, expected %d (turnstile batch 124, + fulcrum + plank + ONE grip batch)"
			% [excl, _EXPECTED_DRAW_NODES_EXCL_PORTALS])
	print("")

## Counts MultiMeshInstance3D too, not only MeshInstance3D: the seesaw's
## grips are a batch NESTED under a pivot, and a counter that only looked
## for plain mesh nodes at the top level would miss it -- which is exactly
## the undercount HubPerfBaseline was found carrying.
func _count_draw(node: Node) -> int:
	var n: int = 1 if (node is MeshInstance3D or node is MultiMeshInstance3D) else 0
	for child in node.get_children():
		n += _count_draw(child)
	return n
