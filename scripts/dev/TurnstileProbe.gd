extends Node

## Gates the turnstile: the plateau's first prop with a MOVING part, and the
## first that answers a landing at all.
##
## WHY IT IS GATED AND NOT MERELY REPORTED. Every way this feature can fail
## is SILENT. A registry that comes back empty, a pivot resolved to null, a
## MultiMesh left at Godot's default TRANSFORM_2D (which discards every
## transform written to it and draws the whole batch at the origin), a
## trigger hooked below one of the early returns in _on_hop_landed, a
## debounce that lets two tweens fight over one angle -- not one of those
## raises, breaks a build, or looks like anything other than "the turnstile
## was never switched on". Which is exactly what a device tester would
## report, and exactly what nobody could then attribute.
##
## PHASE G covers the RIDER, added when Keepy stopped walking through the
## prop and started turning with it. Its silences are different ones and
## just as quiet: a seat height that leaves him shin-deep in the deck, a
## rider a frame behind the thing carrying him, a dismount that comes down
## inside the trigger radius and remounts him for ever.
##
## ⚠️ WHAT THIS PROBE CANNOT DECIDE. It measures ANGLES and NODES, never
## how a spin READS, and never how the RIDE reads either -- whether a body
## swung round a knee-high roundabout with his nose over the rim looks like
## a passenger or like a prop that has fallen over is a device judgement. Whether 1.5 turns over 2.2 seconds looks like a shove
## that coasts down or like a prop glitching is a device judgement, and so
## are the proportions -- see docs/color-sheets/turnstile_proportions_sheet.png,
## on which nothing is validated.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")

## Measured on the shipped tree, before and after, in one session on an idle
## machine -- never carried over from a previous batch's note. 120 -> 124
## excluding portals, 126 -> 130 including them: the footing, the deck, the
## post, and ONE MultiMesh node for however many grip bars there are.
## 124 -> 127 on 28 aout 2026, ITEMISED rather than nudged: the seesaw adds
## a fulcrum, a plank, and ONE MultiMeshInstance3D for however many grips it
## has. Raised here rather than left to fail, and written down rather than
## absorbed -- a draw-node constant that drifts quietly is a budget nobody
## is watching.
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
const _EXPECTED_DRAW_NODES_EXCL_PORTALS: int = 141

var _failures: int = 0
var _hub: Node = null
var _world: Node3D = null
var _props: HubBuilder = null
var _keepy: KeepyHopper = null
var _consts: Dictionary = {}

## ⚠️ CONSTANTS ARE NOT PROPERTIES. Object.get("SOME_CONST") returns null
## for a GDScript const, silently. The constant map is the accessor that
## actually works -- the lesson WaterImpactProbe paid for, reused here
## rather than rediscovered.
func _const(source: Object, name: String, fallback: float = 0.0) -> float:
	var map: Dictionary = source.get_script().get_script_constant_map()
	return float(map.get(name, fallback))

func _ready() -> void:
	ProbeWatchdog.arm(self, "TurnstileProbe")
	_hub = HUB_SCENE.instantiate()
	add_child(_hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_world = _hub.get_node("WorldViewport/SubViewport/World")
	_props = _hub.get_node("WorldViewport/SubViewport/World/Props")
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
	_consts = _hub.get_script().get_script_constant_map()

	await _phase_a()
	await _phase_b()
	await _phase_c()
	await _phase_d()
	await _phase_e()
	await _phase_f()
	await _phase_g()
	await _phase_h()

	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	print("  %s  %s" % ["OK  " if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _registry() -> Array[Dictionary]:
	return _props.spinning_props()

func _angle(entry: Dictionary) -> float:
	var pivot: Node3D = entry["spinner"]
	return pivot.rotation_degrees.y

## Drops Keepy at a point and emits the landing HubWorld listens for, which
## is the SAME signal an ordinary hop's arrival emits. Nothing here reaches
## into HubWorld's own handler: the wiring is part of what is under test.
func _land_at(point: Vector3) -> void:
	_keepy.global_position = Vector3(point.x, 0.0, point.z)
	_keepy.hop_landed.emit(_keepy.global_position)
	await get_tree().process_frame

## ---------------------------------------------------------------------
## PHASE A -- the registry, and what is and is not under the pivot.
func _phase_a() -> void:
	print("--- PHASE A: registry and node contract ---")
	var reg := _registry()
	print("  spinning props built : %d" % reg.size())
	_check(reg.size() >= 1, "the layout yields at least one spinning prop")
	if reg.is_empty():
		return

	# A LIST from the first commit, not a singleton -- the lesson the
	# diving board charged for. Asserted on the TYPE, so a future edit that
	# quietly narrows it back to one is a failure here and not a surprise
	# two batches later.
	_check(reg is Array, "the registry is a LIST, not a single prop")

	for i in reg.size():
		var entry: Dictionary = reg[i]
		_check(entry.has("position") and entry.has("radius") and entry.has("spinner"),
			"entry %d carries position / radius / spinner" % i)
		var pivot: Node3D = entry.get("spinner")
		_check(pivot != null and is_instance_valid(pivot),
			"entry %d resolves to a live pivot node" % i)
		if pivot == null:
			continue
		_check(float(entry["radius"]) > 0.0, "entry %d has a positive trigger radius" % i)

		var root: Node3D = pivot.get_parent()
		print("    entry %d: %v r=%.2f  pivot '%s' under '%s'"
			% [i, entry["position"], entry["radius"], pivot.name, root.name])

		# THE FOOTING MUST NOT TURN. This is the assertion the whole visual
		# reading of the prop rests on: a spin is only legible against
		# something that stays put.
		var footing: Node = root.get_node_or_null("Footing")
		_check(footing != null, "entry %d has a static footing" % i)
		_check(footing != null and footing.get_parent() == root,
			"entry %d's footing is OUTSIDE the pivot" % i)

		var names: Array[String] = []
		for c in pivot.get_children():
			names.append(String(c.name))
		print("      under the pivot: %s" % ", ".join(names))
		_check(names.has("Deck") and names.has("Post") and names.has("Bars"),
			"entry %d turns its deck, post and bars together" % i)

## ---------------------------------------------------------------------
## PHASE B -- the bars, and the MultiMesh trap.
func _phase_b() -> void:
	print("--- PHASE B: the batched grip bars ---")
	var reg := _registry()
	if reg.is_empty():
		return
	var expected_bars: int = int(_const(_props, "TURNSTILE_BARS", -1))
	print("  TURNSTILE_BARS = %d" % expected_bars)
	for i in reg.size():
		var pivot: Node3D = reg[i]["spinner"]
		var bars := pivot.get_node_or_null("Bars") as MultiMeshInstance3D
		_check(bars != null, "entry %d's bars are ONE MultiMesh node" % i)
		if bars == null:
			continue
		var mm: MultiMesh = bars.multimesh
		_check(mm != null, "entry %d's bar node carries a MultiMesh" % i)
		if mm == null:
			continue
		# TRANSFORM_2D is the DEFAULT. A batch left at it draws every
		# instance at the origin -- a whole prop collapsed into its own
		# centre, with no error attached.
		_check(mm.transform_format == MultiMesh.TRANSFORM_3D,
			"entry %d's MultiMesh is TRANSFORM_3D, not the 2D default" % i)
		_check(mm.instance_count == expected_bars,
			"entry %d draws %d bars" % [i, expected_bars])

		# The AABB is written rather than trusted: a wrong one makes the
		# batch vanish when the camera turns, silently.
		var box: AABB = mm.custom_aabb
		_check(box.size.length() > 0.0, "entry %d's custom_aabb is set" % i)
		var local: AABB = mm.mesh.get_aabb()
		var all_in := true
		var radii: Array[float] = []
		for k in mm.instance_count:
			var xform: Transform3D = mm.get_instance_transform(k)
			if not box.encloses((xform * local).abs()):
				all_in = false
			radii.append(Vector2(xform.origin.x, xform.origin.z).length())
		_check(all_in, "entry %d's custom_aabb encloses every bar" % i)

		# Every bar the same distance out: this is what makes it read as a
		# wheel rather than as a bundle of sticks.
		var spread: float = 0.0
		for r in radii:
			spread = maxf(spread, absf(r - radii[0]))
		print("    bar hub radius %.4f, worst spread %.6f" % [radii[0], spread])
		_check(spread < 0.0001, "entry %d's bars sit on one circle" % i)

		# And the tips stay inside the deck they are bolted to.
		var bar_len: float = _const(_props, "TURNSTILE_BAR_LENGTH")
		var deck_r: float = _const(_props, "TURNSTILE_DECK_RADIUS")
		var base_r: float = _const(_props, "TURNSTILE_BASE_RADIUS")
		print("    bar length %.4f, deck radius %.4f, footing radius %.4f"
			% [bar_len, deck_r, base_r])
		_check(bar_len <= deck_r, "entry %d's bars stop inside the deck rim" % i)
		_check(base_r > deck_r, "entry %d's footing is wider than its deck" % i)

## ---------------------------------------------------------------------
## PHASE C -- a landing at it turns it, a landing away from it does not.
func _phase_c() -> void:
	print("--- PHASE C: a landing sets it going ---")
	var reg := _registry()
	if reg.is_empty():
		return
	var entry: Dictionary = reg[0]
	var here: Vector3 = entry["position"]
	var radius: float = entry["radius"]

	# THE BLIND CHECK FIRST, and the order is deliberate. "Nothing turned"
	# passes for free against a trigger that was never wired at all, so the
	# right to assert a refusal has to be bought by proving a spin CAN
	# happen. WaterImpactProbe orders its two the same way, for the same
	# reason.
	var before: float = _angle(entry)
	await _land_at(here)
	await get_tree().create_timer(0.05).timeout
	var moved: float = absf(_angle(entry) - before)
	print("  blind check: landing AT it moved the pivot by %.4f deg" % moved)
	_check(moved > 0.01, "a landing at the prop turns it (blind check)")

	# Let it come to rest before the refusal, so what is measured next is a
	# spin that did not start rather than one still finishing.
	var spin_s: float = _const(_hub, "TURNSTILE_SPIN_S", 2.2)
	await get_tree().create_timer(spin_s + 0.35).timeout
	var settled: float = _angle(entry)

	var far_point: Vector3 = here + Vector3(radius * 3.0, 0.0, 0.0)
	await _land_at(far_point)
	await get_tree().create_timer(0.20).timeout
	var drift: float = absf(_angle(entry) - settled)
	print("  landing %.2f u away moved the pivot by %.4f deg" % [here.distance_to(far_point), drift])
	_check(drift < 0.0001, "a landing out of reach leaves it alone")

	# And the total is the stated number of turns, not some fraction of it.
	var turns: float = _const(_hub, "TURNSTILE_SPIN_TURNS", 0.0)
	var travelled: float = settled - before
	print("  one shove travelled %.2f deg (%.2f turns stated)" % [travelled, turns])
	_check(absf(travelled - 360.0 * turns) < 0.5,
		"one shove completes the stated %.2f turns" % turns)

## ---------------------------------------------------------------------
## PHASE D -- the debounce.
func _phase_d() -> void:
	print("--- PHASE D: a second landing mid-spin does not stack ---")
	var reg := _registry()
	if reg.is_empty():
		return
	var entry: Dictionary = reg[0]
	var here: Vector3 = entry["position"]
	var spin_s: float = _const(_hub, "TURNSTILE_SPIN_S", 2.2)

	var turns: float = _const(_hub, "TURNSTILE_SPIN_TURNS", 0.0)
	# Where this shove will start FROM, worked out BEFORE the landing.
	#
	# ⚠️ NOT read back after _land_at(): a landing costs two frames and the
	# tween is already running by then, so the angle sampled there is
	# already tens of degrees into the spin -- measured, 214.11 against a
	# true origin of 180.0, which made the travel assertion below fail on
	# correct code. The wrap is the one rule mirrored from _spin_near(),
	# because the point of the check is that the shove lands exactly where
	# that function says it should.
	var shove_from: float = fposmod(_angle(entry), 360.0)
	var target: float = shove_from + 360.0 * turns
	await _land_at(here)

	await get_tree().create_timer(spin_s * 0.4).timeout
	var mid: float = _angle(entry)
	var tween_a: Tween = _spin_tween(entry)

	# Land on it again while it is still coasting.
	#
	# ⚠️ THIS DOES NOT ASSERT "THE ANGLE DID NOT MOVE", and the first
	# version of this phase did -- it failed, on correct code, by 12.4
	# degrees. A coasting spin ADVANCES across the two frames a landing
	# takes, so "the angle is unchanged" was measuring the tween still
	# doing its job. What a stacked or restarted tween would actually do is
	# visible instead: a restart wraps the pivot back into [0, 360), which
	# is a large BACKWARD jump, and a second tween laid over the first
	# would overshoot the one target in flight. Both are gated here; normal
	# coasting is not.
	await _land_at(here)
	var after_touch: float = _angle(entry)
	var tween_b: Tween = _spin_tween(entry)
	print("  angle %.3f -> %.3f across the re-landing (target %.3f)"
		% [mid, after_touch, target])
	_check(after_touch >= mid - 0.0001, "the re-landing does not throw the angle backwards")
	_check(after_touch <= target + 0.0001, "the re-landing does not overshoot the shove in flight")
	_check(tween_a == tween_b, "the re-landing did not start a second tween")

	# And it still finishes where ONE shove would have finished -- which is
	# the assertion that says the second landing bought nothing at all.
	await get_tree().create_timer(spin_s + 0.35).timeout
	var end: float = _angle(entry)
	print("  settled at %.3f deg, one shove from %.3f is %.3f" % [end, shove_from, target])
	_check(absf(end - target) < 0.5, "two landings during one spin travel exactly one shove")
	_check(_spin_tween(entry) == null or not _spin_tween(entry).is_running(),
		"the spin comes to rest rather than running on")

func _spin_tween(entry: Dictionary) -> Tween:
	for held in _hub.get("_spinners"):
		if held["spinner"] == entry["spinner"]:
			return held["tween"]
	return null

## ---------------------------------------------------------------------
## PHASE E -- a dive's landing is not a walk's landing, and Keepy is
## untouched either way.
func _phase_e() -> void:
	print("--- PHASE E: a dive does not shove it, and Keepy never changes ---")
	var reg := _registry()
	if reg.is_empty():
		return
	var entry: Dictionary = reg[0]
	var here: Vector3 = entry["position"]
	await get_tree().create_timer(_const(_hub, "TURNSTILE_SPIN_S", 2.2) + 0.35).timeout
	var before: float = _angle(entry)

	# Arm the dive latch the way a real dive does -- through the signal,
	# not by writing HubWorld's field -- then land on the prop.
	_keepy.board_dived.emit()
	await _land_at(here)
	await get_tree().create_timer(0.20).timeout
	var moved: float = absf(_angle(entry) - before)
	print("  a DIVE landing at it moved the pivot by %.4f deg" % moved)
	_check(moved < 0.0001, "a dive's landing does not shove it")

	# ⚠️ REWRITTEN, NOT DROPPED. Until Keepy could ride the thing, this
	# phase closed by asserting that NOTHING about him ever changed -- no
	# lift, no new state -- because that was the contract. It is not any
	# more, so the assertion is re-aimed at the half of it that still holds
	# and is still worth guarding: a DIVE's landing must leave him on the
	# ground. Measured HERE, right after the dive landing, rather than at
	# the end of the phase, because the ordinary landing below is now
	# supposed to pick him up and asserting this after it would be
	# asserting the feature does not work.
	print("  after the DIVE landing: y = %.4f, on turnstile = %s"
		% [_keepy.global_position.y, str(_keepy.is_on_turnstile())])
	_check(absf(_keepy.global_position.y) < 0.0001,
		"a dive's landing leaves Keepy on the ground")
	_check(not _keepy.is_on_turnstile(),
		"a dive's landing does not put Keepy on the prop")
	_check(not _keepy.is_riding() and not _keepy.is_on_board(),
		"a dive's landing leaves him in no board or ride state")

	# The latch must be spent by that landing rather than left primed.
	await _land_at(here + Vector3(999.0, 0.0, 0.0))
	await _land_at(here)
	await get_tree().create_timer(0.05).timeout
	_check(absf(_angle(entry) - before) > 0.01,
		"the next ordinary landing shoves it again (the latch was spent)")

	# And that ordinary landing DID pick him up, which is the other half of
	# the same gate: a dive-vs-walk test that refused both would pass this
	# phase for free.
	print("  the ordinary landing put him on the prop: %s" % str(_keepy.is_on_turnstile()))
	_check(_keepy.is_on_turnstile(),
		"an ordinary landing at the prop DOES put Keepy on it (gate blind check)")
	await _settle_off_turnstile()

## ---------------------------------------------------------------------
## PHASE F -- the budget, and no collision with the ladders.
func _phase_f() -> void:
	print("--- PHASE F: draw-node cost and ladder separation ---")
	var individual := 0
	var multi := 0
	var portal := 0
	for c in _props.get_children():
		if c is HubPortal:
			portal += _count_draw(c)
		elif c is MultiMeshInstance3D:
			multi += 1
		else:
			individual += _count_draw(c)
	var excl: int = individual + multi
	print("  draw nodes: %d excluding portals, %d including" % [excl, excl + portal])
	_check(excl == _EXPECTED_DRAW_NODES_EXCL_PORTALS,
		"draw nodes excluding portals == %d" % _EXPECTED_DRAW_NODES_EXCL_PORTALS)

	# HubTapInput is SHARED. A turnstile inside a ladder's tap radius would
	# put a prop under the one gesture that has to keep meaning "climb".
	var ladder_radius: float = _const(_hub, "LADDER_TAP_RADIUS", 2.5)
	var worst: float = INF
	for entry in _registry():
		for board in _props.diving_boards():
			worst = minf(worst, (entry["position"] as Vector3).distance_to(board["ladder"] as Vector3))
	print("  nearest ladder foot to any spinning prop: %.3f u (tap radius %.2f)" % [worst, ladder_radius])
	_check(worst > ladder_radius, "no spinning prop sits inside a ladder's tap radius")

	# And its footing is registered, so the ride's disembark search knows
	# not to put Keepy inside it.
	var known: bool = _props.FOOTPRINT_RADIUS.has(&"turnstile")
	_check(known, "the turnstile has a ground footprint the disembark search can see")

## Waits until the turnstile has put him down again and he is standing
## still. Every phase that lands him on the prop has to leave the next one
## a body that is idle rather than one still being swung.
func _settle_off_turnstile() -> void:
	for i in 900:
		await get_tree().process_frame
		if not _keepy.is_on_turnstile() and not _keepy.is_hopping():
			return

## Keepy's feet, in world units, off the drawn model rather than off his
## origin -- the same visual_aabb() the waterline work measures with.
func _feet_y() -> float:
	var slot: Node3D = _keepy.get_node("Yaw/Body")
	var box: AABB = slot.global_transform * slot.visual_aabb()
	return box.position.y

## Keepy's seat expressed in the pivot's OWN frame. Constant for as long as
## he is turning with it -- and constant WHATEVER sign convention a yaw
## uses, which is why the check is written this way rather than by
## comparing two angles.
##
## ⚠️ THE FIRST VERSION OF THIS COMPARED ANGLES and reported a 179.6-degree
## drift on correct code: a +Y rotation in Godot makes the bearing
## atan2(z, x) DECREASE, so the metric was measuring its own sign mistake.
## De-rotating through the pivot cannot make that error.
func _seat_local(entry: Dictionary) -> Vector3:
	return (entry["spinner"] as Node3D).to_local(_keepy.global_position)

## ---------------------------------------------------------------------
## PHASE G -- Keepy rides it.
##
## WHY GATED. Every way this can fail is silent, and they are not the same
## silences the rest of this file already covers: a seat height that leaves
## him shin-deep in the deck, a rider a frame behind the thing carrying him,
## a dismount that lands back inside the trigger radius and remounts him
## forever, a tap that walks him off mid-spin. None of those raise, none
## break a build, and all of them look on a device like "the roundabout is
## broken" rather than like any one of these causes.
func _phase_g() -> void:
	print("--- PHASE G: Keepy mounts, turns with it, and steps off ---")
	var reg := _registry()
	if reg.is_empty():
		return
	var entry: Dictionary = reg[0]
	var pivot: Node3D = entry["spinner"]
	var here: Vector3 = entry["position"]
	var trigger: float = float(entry["radius"])
	var deck_y: float = float(entry["deck_y"])
	var ride_r: float = float(entry["ride_radius"])
	var bars: int = int(entry["bars"])
	var spin_s: float = _const(_hub, "TURNSTILE_SPIN_S", 2.2)

	await _settle_off_turnstile()
	await get_tree().create_timer(spin_s + 0.35).timeout

	# ---- mount
	var approach: Vector3 = here + Vector3(trigger * 0.7, 0.0, trigger * 0.4)
	await _land_at(approach)
	await get_tree().process_frame
	print("  after a landing %.2f u from the pivot: on turnstile = %s"
		% [Vector3(approach.x, 0.0, approach.z).distance_to(here), str(_keepy.is_on_turnstile())])
	_check(_keepy.is_on_turnstile(), "a landing in reach puts Keepy on the prop")
	if not _keepy.is_on_turnstile():
		return

	# ---- seat: on the deck, at the published radius, in a GAP
	var seat: Vector3 = _seat_local(entry)
	var seat_r: float = Vector2(seat.x, seat.z).length()
	var feet: float = _feet_y()
	print("  feet y = %.5f (deck top %.5f)   orbit radius = %.5f (published %.5f)"
		% [feet, deck_y, seat_r, ride_r])
	_check(absf(feet - deck_y) < 0.01, "his feet stand ON the deck top, not in it")
	_check(absf(seat_r - ride_r) < 0.001, "he sits at the published ride radius")

	# The bars are at k*step exactly; a rider must be between two of them.
	var step: float = TAU / float(maxi(bars, 1))
	var ang: float = atan2(seat.z, seat.x)
	var off: float = absf(fposmod(ang + step * 0.5, step) - step * 0.5)
	# His own angular half-width at this radius: 0.6599 of model across
	# 1.15 of orbit. The bar he has to miss is a spoke, so the clearance
	# that matters is angular.
	var half_w: float = rad_to_deg(atan2(0.6599, seat_r))
	print("  seated %.2f deg from the nearest bar; half a gap is %.2f deg, his own half-width is %.2f deg"
		% [rad_to_deg(off), rad_to_deg(step * 0.5), half_w])
	# ⚠️ THIS ASSERTED THE WRONG QUANTITY FIRST TIME and failed on correct
	# code. `off` is the distance to the nearest BAR and wants to be LARGE;
	# the first version tested (half a gap - off), which is the distance to
	# the gap's CENTRE and is correctly ZERO for a rider seated dead in the
	# middle of one. The print said so -- "45.00 from the nearest bar, half
	# a gap is 45.00" -- which is what a perfect seat looks like.
	_check(absf(rad_to_deg(off) - rad_to_deg(step * 0.5)) < 1.0,
		"he is seated at the CENTRE of a gap between two bars")
	_check(rad_to_deg(off) > half_w,
		"his body clears the grip bars either side of him")

	# ---- synchrony, and a blind check that the metric can SEE a break
	var base: Vector3 = _seat_local(entry)
	var worst: float = 0.0
	var landings: int = 0
	var counter := func(_p: Vector3) -> void: landings += 1
	_keepy.hop_landed.connect(counter)
	for i in 200:
		await get_tree().process_frame
		if not _keepy.is_on_turnstile():
			break
		worst = maxf(worst, _seat_local(entry).distance_to(base))
	_keepy.hop_landed.disconnect(counter)
	print("  worst de-rotated seat drift over the shove = %.9f u" % worst)
	_check(worst < 0.01, "he turns WITH the deck rather than beside it")

	# ---- portal detection is silent for the whole ride
	print("  landings emitted while aboard: %d" % landings)
	_check(landings == 0, "no landing is emitted while the prop carries him")

	await _settle_off_turnstile()

	# ---- dismount: on the ground, out of reach, in the region, clear
	var end_pos: Vector3 = _keepy.global_position
	var out_d: float = Vector3(end_pos.x, 0.0, end_pos.z).distance_to(here)
	print("  stepped off at (%.3f, %.3f, %.3f), %.3f u from the pivot (trigger %.2f)"
		% [end_pos.x, end_pos.y, end_pos.z, out_d, trigger])
	_check(absf(end_pos.y) < 0.0001, "he steps off onto the ground, not into the air")
	_check(out_d > trigger, "he lands OUTSIDE the trigger radius, so stepping off cannot re-shove it")
	_check(HubRegion.contains(end_pos), "he lands inside the walkable region")
	var worst_fp: float = INF
	for spot in _props.ground_footprints():
		worst_fp = minf(worst_fp, Vector3(end_pos.x, 0.0, end_pos.z)
			.distance_to(spot["position"] as Vector3) - float(spot["radius"]))
	print("  nearest prop edge: %.3f u" % worst_fp)
	_check(worst_fp > 0.0, "he does not land inside a prop")
	_check(not _keepy.is_on_turnstile() and not _keepy.is_hopping(),
		"he is standing still when it is over -- the dismount did not remount him")

	# ---- a tap while aboard is dropped, not walked
	await get_tree().create_timer(spin_s + 0.35).timeout
	await _land_at(approach)
	await get_tree().process_frame
	if not _keepy.is_on_turnstile():
		_check(false, "re-mount for the tap test")
		return
	var seat_before: Vector3 = _seat_local(entry)
	_hub._on_tapped_ground(here + Vector3(12.0, 0.0, 12.0))
	await get_tree().process_frame
	var seat_after: Vector3 = _seat_local(entry)
	print("  tap while aboard: still on = %s, seat moved %.6f u"
		% [str(_keepy.is_on_turnstile()), seat_after.distance_to(seat_before)])
	_check(_keepy.is_on_turnstile(), "a tap while aboard does not take him off")
	_check(seat_after.distance_to(seat_before) < 0.01, "a tap while aboard does not move him on the deck")

	# ---- BLIND CHECK for the synchrony metric, on a stopped prop.
	# Turning the pivot WITHOUT telling him must show up, or the drift
	# figure above passes for free against a rider who never moved at all.
	await _settle_off_turnstile()
	await get_tree().create_timer(spin_s + 0.35).timeout
	await _land_at(approach)
	await get_tree().process_frame
	if not _keepy.is_on_turnstile():
		_check(false, "re-mount for the blind check")
		return
	var spin: Tween = _spin_tween(entry)
	if spin != null and spin.is_valid():
		spin.kill()
	await get_tree().process_frame
	var held: Vector3 = _seat_local(entry)
	pivot.rotation_degrees.y += 25.0
	await get_tree().process_frame
	var broken: float = _seat_local(entry).distance_to(held)
	print("  BLIND CHECK: turning the pivot without telling him drifts the seat %.6f u" % broken)
	_check(broken > 0.05, "the drift metric can see a rider left behind (blind check)")
	_keepy.follow_turnstile()
	await get_tree().process_frame
	var healed: float = _seat_local(entry).distance_to(held)
	print("  and telling him puts it back: %.9f u" % healed)
	_check(healed < 0.001, "one call to follow_turnstile restores the seat exactly")

	# leave the world tidy for anything after this phase
	_keepy.leave_turnstile(_turnstile_exit_probe(entry))
	await _settle_off_turnstile()

## The same place HubWorld would put him, asked of HubWorld rather than
## recomputed here: a probe that worked out its own exit point would be
## grading the implementation against a second opinion instead of against
## itself.
##
## RENAMED _turnstile_exit_point -> _ride_exit_point on 28 aout 2026, when
## the seesaw started calling the same entry-driven function and the old
## name stopped being true. ⚠️ This call site was MISSED by that rename and
## found by diffing this probe's stdout against main: the failure printed
## "Nonexistent function" on STDOUT and the probe still EXITED 0, so a run
## that was only checked for its exit code would have reported it green.
func _turnstile_exit_probe(entry: Dictionary) -> Vector3:
	return _hub._ride_exit_point(entry)

## ---------------------------------------------------------------------
## PHASE H -- a tap ON the prop, mid-spin, re-arms the ride instead of
## letting it coast to a stop. Added 28 aout 2026 -- the request was
## "unlimited turns while he keeps tapping", so this gates the extension
## itself, that it does not stack a second tween on the first, and that
## letting go still lets the ride end on its own.
##
## THE BLIND CHECK ORDER PHASE C and WaterImpactProbe already use: "he is
## still aboard" passes for free against a tap that was never wired to
## anything, so the right to assert an extension has to be bought by
## proving the re-tap SWAPS the tween rather than merely coinciding with
## one that was going to keep running anyway.
func _phase_h() -> void:
	print("--- PHASE H: a tap on the prop mid-spin re-arms the ride ---")
	var reg := _registry()
	if reg.is_empty():
		return
	var entry: Dictionary = reg[0]
	var here: Vector3 = entry["position"]
	var radius: float = entry["radius"]
	var spin_s: float = _const(_hub, "TURNSTILE_SPIN_S", 2.2)
	var approach: Vector3 = here + Vector3(radius * 0.7, 0.0, radius * 0.4)

	await _settle_off_turnstile()
	await get_tree().create_timer(spin_s + 0.35).timeout

	await _land_at(approach)
	await get_tree().process_frame
	if not _keepy.is_on_turnstile():
		_check(false, "mount for the re-arm test")
		return
	var first_tween: Tween = _spin_tween(entry)

	# RE-TAP MID-SPIN, ON the prop -- well inside its own trigger radius,
	# unlike PHASE G's far tap.
	await get_tree().create_timer(spin_s * 0.6).timeout
	_hub._on_tapped_ground(here)
	await get_tree().process_frame
	var second_tween: Tween = _spin_tween(entry)
	print("  re-tap swapped the tween: %s (first=%s second=%s)"
		% [str(first_tween != second_tween), first_tween, second_tween])
	_check(second_tween != null and second_tween != first_tween,
		"a tap on the prop starts a NEW tween rather than letting the old one run out")
	_check(first_tween == null or not first_tween.is_valid() or not first_tween.is_running(),
		"the old tween is killed, not left running alongside the new one")

	# Past where the FIRST shove alone would have put him down -- still
	# aboard, because the re-tap replaced it with a fresh one.
	await get_tree().create_timer(spin_s * 0.4 + 0.35).timeout
	print("  past the original single-shove end: on turnstile = %s" % str(_keepy.is_on_turnstile()))
	_check(_keepy.is_on_turnstile(),
		"the re-tap keeps him aboard past where one shove alone would have ended")

	# And with no FURTHER tap, the extended ride still ends on its own --
	# this is an extension, not an escape from ever dismounting.
	await get_tree().create_timer(spin_s * 0.6 + 0.35).timeout
	print("  after the second shove's own duration: on turnstile = %s" % str(_keepy.is_on_turnstile()))
	_check(not _keepy.is_on_turnstile(),
		"with no further tap, the extended ride still ends on its own")
	_check(HubRegion.contains(_keepy.global_position), "he lands inside the walkable region")

	# THREE re-taps in a row, proving "unlimited while he keeps tapping" and
	# not merely "twice".
	await _settle_off_turnstile()
	await get_tree().create_timer(spin_s + 0.35).timeout
	await _land_at(approach)
	await get_tree().process_frame
	if not _keepy.is_on_turnstile():
		_check(false, "re-mount for the repeated-tap test")
		return
	for i in 3:
		await get_tree().create_timer(spin_s * 0.5).timeout
		_hub._on_tapped_ground(here)
		await get_tree().process_frame
		if not _keepy.is_on_turnstile():
			_check(false, "stayed aboard through re-tap %d of 3" % (i + 1))
			return
	print("  stayed aboard through 3 consecutive re-taps")
	_check(_keepy.is_on_turnstile(), "three consecutive re-taps keep him aboard the whole time")
	await _settle_off_turnstile()
	_check(not _keepy.is_on_turnstile(), "letting go after the third re-tap still lets him off")

func _count_draw(n: Node) -> int:
	var k: int = 1 if (n is MeshInstance3D or n is MultiMeshInstance3D) else 0
	for c in n.get_children():
		k += _count_draw(c)
	return k
