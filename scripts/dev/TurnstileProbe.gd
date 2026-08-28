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
## ⚠️ WHAT THIS PROBE CANNOT DECIDE. It measures ANGLES and NODES, never
## how a spin READS. Whether 1.5 turns over 2.2 seconds looks like a shove
## that coasts down or like a prop glitching is a device judgement, and so
## are the proportions -- see docs/color-sheets/turnstile_proportions_sheet.png,
## on which nothing is validated.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")

## Measured on the shipped tree, before and after, in one session on an idle
## machine -- never carried over from a previous batch's note. 120 -> 124
## excluding portals, 126 -> 130 including them: the footing, the deck, the
## post, and ONE MultiMesh node for however many grip bars there are.
const _EXPECTED_DRAW_NODES_EXCL_PORTALS: int = 124

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

	# The latch must be spent by that landing rather than left primed.
	await _land_at(here + Vector3(999.0, 0.0, 0.0))
	await _land_at(here)
	await get_tree().create_timer(0.05).timeout
	_check(absf(_angle(entry) - before) > 0.01,
		"the next ordinary landing shoves it again (the latch was spent)")

	# NOTHING ABOUT KEEPY CHANGES. No new state, no lift onto the deck --
	# the deck is not walkable and this is what says so.
	print("  Keepy: y = %.4f, idle = %s" % [_keepy.global_position.y, str(not _keepy.is_hopping())])
	_check(absf(_keepy.global_position.y) < 0.0001, "Keepy stays at ground level")
	_check(not _keepy.is_riding() and not _keepy.is_on_board(),
		"Keepy is in no board or ride state")

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

func _count_draw(n: Node) -> int:
	var k: int = 1 if (n is MeshInstance3D or n is MultiMeshInstance3D) else 0
	for c in n.get_children():
		k += _count_draw(c)
	return k
