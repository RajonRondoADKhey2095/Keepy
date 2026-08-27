extends Node

## Gates the water tint: the five-body membership test, the two float32 rim
## margins, and the fact that the tint actually reaches the material Keepy
## is DRAWN with.
##
## =====================================================================
## WHY THIS IS GATED AND NOT REPORTED
##
## Every way this feature can break is SILENT. HubWorld resolves Keepy's
## material lazily through ModelSlot and no-ops when the slot hands back
## something that is not a StandardMaterial3D; the five-body test answers
## false for a body whose centre accessor went missing; a landing hook
## placed after an early return simply stops firing on the landings that
## matter. None of those raise, none of them fail a build, and all of them
## look exactly like "the tint was never turned on" on a device.
##
## The one assertion that carries the most here is PHASE C: it reads the
## albedo off the MeshInstance3D nodes the slot actually draws, not off the
## variable HubWorld wrote. Checking the variable would pass on the day
## ModelSlot stops binding the override -- the precise defect that made
## AlarmRampAudit necessary, one screen over.
##
## =====================================================================
## RUN IT UNDER xvfb, NOT --headless
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
##       --path . res://scripts/dev/WaterTintProbe.tscn
##
## --headless forces the DUMMY driver, which fabricates viewport sizes and
## keeps no material state worth reading -- a probe that passes for free.
## Same trap this screen has already paid for twice.

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

## Draw nodes excluding the three portals, from docs/HUB_PERF_BASELINE.md's
## own latest row. This batch writes a property on an existing surface and
## must not move it.
const _EXPECTED_DRAW_NODES_EXCL_PORTALS: int = 98

var _failures: int = 0
var _ride_landings: int = 0

## Keepy's untinted albedo, captured in PHASE C from the live slot. Shared
## with PHASE F rather than restated there: a second literal would agree with
## the first right up until the asset changes, and then agree with nothing.
var _base_albedo := Color.WHITE
var _base_captured: bool = false

func _ready() -> void:
	ProbeWatchdog.arm(self, "WATER TINT PROBE")
	var dl := ProbeWatchdog.deadline("WATER TINT PROBE")

	print("=== WATER TINT PROBE ===")
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var world: Node3D = hub.get_node("WorldViewport/SubViewport/World") as Node3D
	var props: HubBuilder = world.get_node("Props") as HubBuilder
	var keepy: KeepyHopper = world.get_node("Keepy") as KeepyHopper

	var route: HubStreamRoute = HubStreamRoute.new(props.stream_spine())
	var water := HubWater.new(props, route)

	_phase_a_membership(water, props, route)
	dl.abort_if_exceeded()
	_phase_b_rim(water, props, route)
	dl.abort_if_exceeded()
	await _phase_c_tint(hub, keepy, water, props)
	await _phase_d_ride(keepy)
	await _phase_f_portals(hub, keepy, props)
	_phase_e_cost(props, world)

	print("")
	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		print("  OK    %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s" % label)

## PHASE A -- the test names the right body, and only inside it.
##
## Every centre and radius comes back out of the same accessors HubWater
## reads, so this phase cannot pass by agreeing with a number it invented.
func _phase_a_membership(water: HubWater, props: HubBuilder, route: HubStreamRoute) -> void:
	print("--- PHASE A: five-body membership ---")
	_check(water.has_stream(), "the stream was found and is being tested")
	_check(water.discs().size() == 4, "four discs: pond, small lake, both great-lake lobes")

	for disc in water.discs():
		var name: StringName = disc["name"]
		var centre: Vector3 = disc["centre"]
		var radius: float = disc["radius"]
		# Dead centre is unambiguously inside; one radius further out along
		# +X is unambiguously outside THIS disc (it may sit in another, and
		# the assertion says only that it stopped being this one).
		_check(water.body_at(centre) == name, "%s: its own centre reads as itself" % name)
		var out := centre + Vector3(radius * 2.0, 0.0, 0.0)
		_check(water.body_at(out) != name, "%s: a point one diameter out is not it" % name)

	# The ribbon, from a point ON the spine and one well off it.
	var mid := route.point_at(route.length() * 0.5)
	_check(water.body_at(mid) == &"stream", "stream: a point on the spine reads as stream")
	var side := mid + Vector3(0.0, 0.0, 0.0)
	var tangent := route.tangent_at(route.length() * 0.5)
	var normal := Vector3(-tangent.z, 0.0, tangent.x).normalized()
	side = mid + normal * (props.stream_half_width() * 4.0)
	_check(water.body_at(side) != &"stream", "stream: a point four half-widths off is not it")
	print("")

## PHASE B -- the float32 rim, and the two margins that are NOT the same.
##
## This is the phase that exists because the recon found the disc
## convention does not carry to the ribbon. It sweeps both, reports the
## residual at the disc margin, and GATES that each body clears at its own.
func _phase_b_rim(water: HubWater, props: HubBuilder, route: HubStreamRoute) -> void:
	print("--- PHASE B: float32 rim margins ---")
	const AZIMUTHS: int = 360
	for disc in water.discs():
		var name: StringName = disc["name"]
		var centre: Vector3 = disc["centre"]
		var radius: float = disc["radius"]
		var at_edge := 0
		var at_margin := 0
		for i in AZIMUTHS:
			var a := TAU * float(i) / float(AZIMUTHS)
			var dir := Vector3(cos(a), 0.0, sin(a))
			if water.body_at(centre + dir * radius) == name:
				at_edge += 1
			if water.body_at(centre + dir * (radius + HubWater.DISC_RIM_MARGIN)) == name:
				at_margin += 1
		print("  %-14s exact rim %3d/%d read as water | +%.3f -> %d/%d"
			% [name, at_edge, AZIMUTHS, HubWater.DISC_RIM_MARGIN, at_margin, AZIMUTHS])
		_check(at_margin == 0, "%s clears at DISC_RIM_MARGIN" % name)

	# The ribbon.
	#
	# ⚠️ SAMPLE COUNT IS LOAD-BEARING HERE, and it is the reason this batch
	# shipped a wrong constant for an hour. The residual does not live
	# everywhere along the stream -- it lives on the TIGHT BENDS, which are a
	# few segments out of 88. A sweep of 40 abscissas can miss every one of
	# them and report a clean zero at a margin that is nowhere near enough;
	# that is exactly what happened, and what the recon's own 40 samples did
	# in the other direction by finding only 1. Dense enough to land on a
	# bend is the whole requirement.
	const SPANS: int = 2000
	var half := props.stream_half_width()
	var at_edge := 0
	var at_disc_margin := 0
	var at_stream_margin := 0
	for i in SPANS:
		var s := route.length() * (float(i) + 0.5) / float(SPANS)
		var p := route.point_at(s)
		var t := route.tangent_at(s)
		var n := Vector3(-t.z, 0.0, t.x).normalized()
		for side in [1.0, -1.0]:
			if water.body_at(p + n * (half * side)) == &"stream":
				at_edge += 1
			if water.body_at(p + n * ((half + HubWater.DISC_RIM_MARGIN) * side)) == &"stream":
				at_disc_margin += 1
			if water.body_at(p + n * ((half + HubWater.STREAM_RIM_MARGIN) * side)) == &"stream":
				at_stream_margin += 1
	var samples := SPANS * 2
	print("  %-14s exact rim %3d/%-3d read as water | +%.3f -> %d/%d | +%.3f -> %d/%d"
		% [&"stream", at_edge, samples,
			HubWater.DISC_RIM_MARGIN, at_disc_margin, samples,
			HubWater.STREAM_RIM_MARGIN, at_stream_margin, samples])
	# The residual at the DISC margin is reported, never gated: it is the
	# measurement that justifies the stream having a margin of its own, and
	# a green here would mean the two constants could be merged.
	print("  (the +%.3f residual above is WHY the stream carries its own margin)"
		% HubWater.DISC_RIM_MARGIN)
	_check(at_stream_margin == 0, "stream clears at STREAM_RIM_MARGIN")

	# WHERE THE CONSTANT CAME FROM. Swept rather than chosen: the smallest
	# step that takes the ribbon to zero is the one shipped, and printing
	# the whole ladder is what stops a future edit from nudging it down to
	# a value that merely looks tidy.
	print("  stream margin sweep (residual samples still reading as water):")
	for step in [0.001, 0.002, 0.005, 0.010, 0.015, 0.020]:
		var still := 0
		var worst_over := 0.0
		for i in SPANS:
			var s2 := route.length() * (float(i) + 0.5) / float(SPANS)
			var p2 := route.point_at(s2)
			var t2 := route.tangent_at(s2)
			var n2 := Vector3(-t2.z, 0.0, t2.x).normalized()
			for side2 in [1.0, -1.0]:
				var q: Vector3 = p2 + n2 * ((half + step) * side2)
				if water.body_at(q) == &"stream":
					still += 1
					worst_over = maxf(worst_over, half - route.distance_to(q))
		var mark := "  <- shipped" if is_equal_approx(step, HubWater.STREAM_RIM_MARGIN) else ""
		print("    +%.3f -> %5d/%-5d worst overshoot %.6f%s" % [step, still, samples, worst_over, mark])
	print("")

## PHASE C -- the tint reaches the surfaces Keepy is DRAWN with.
##
## Drives the real hop_landed signal on the real HubWorld, then reads the
## albedo back off every MeshInstance3D the slot draws. Nothing here trusts
## HubWorld's own variable.
func _phase_c_tint(hub: Node, keepy: KeepyHopper, water: HubWater, props: HubBuilder) -> void:
	print("--- PHASE C: the tint reaches the drawn material ---")
	var slot: ModelSlot = keepy.body_slot()
	_check(slot != null, "KeepyHopper publishes its ModelSlot")
	if slot == null:
		print("")
		return

	var base: Color = (slot.slot_material() as StandardMaterial3D).albedo_color
	_base_albedo = base
	_base_captured = true
	var pond := props.pond_centre()
	var dry := Vector3(0.0, 0.0, 0.0)
	_check(not water.contains(dry), "the spawn is dry (control for the assertions below)")
	_check(water.contains(pond), "the pond centre is wet (control)")

	# WET. The signal is emitted exactly as KeepyHopper emits it.
	keepy.hop_landed.emit(pond)
	await _settle()
	var wet_albedo := _drawn_albedo(slot)
	var expected := base.lerp(HubWater.hue(), HubWorld.KEEPY_WATER_TINT_FRACTION)
	print("  base %s -> wet %s (expected %s)" % [_fmt(base), _fmt(wet_albedo), _fmt(expected)])
	_check(_near(wet_albedo, expected), "a landing in water tints the DRAWN surfaces to 75%")
	_check(not _near(wet_albedo, base), "the wet albedo is not just the base colour")

	# DRY again.
	keepy.hop_landed.emit(dry)
	await _settle()
	var dry_albedo := _drawn_albedo(slot)
	print("  back on land -> %s" % _fmt(dry_albedo))
	_check(_near(dry_albedo, base), "a landing on land removes the tint completely")
	print("")

## PHASE D -- a ride cannot tint, and cannot carry a tint aboard.
func _phase_d_ride(keepy: KeepyHopper) -> void:
	print("--- PHASE D: riding is not being in the water ---")
	keepy.hop_landed.connect(_count_ride_landing)
	var spine: Array = [
		Vector3(0.0, 0.0, 0.0), Vector3(4.0, 0.0, 0.0),
		Vector3(8.0, 0.0, 0.0), Vector3(12.0, 0.0, 0.0)]
	var route := HubStreamRoute.new(spine)
	_ride_landings = 0
	keepy.board(route, 0.6, Vector3(1.0, 0.0, 0.0))
	_check(keepy.is_riding(), "board() puts Keepy in RIDING")
	var frames := 0
	while keepy.is_riding() and frames < 400:
		await get_tree().physics_frame
		frames += 1
	_check(not keepy.is_riding(), "the ride ended on its own in %d frames" % frames)
	_check(_ride_landings == 0, "hop_landed fired %d times across the whole ride" % _ride_landings)
	keepy.hop_landed.disconnect(_count_ride_landing)
	print("")

func _count_ride_landing(_p: Vector3) -> void:
	_ride_landings += 1

## PHASE E -- no draw node was added. A tint is a property write.
func _phase_e_cost(props: HubBuilder, world: Node3D) -> void:
	print("--- PHASE E: draw-node cost ---")
	var total := _count_draw(props)
	var portal_nodes := 0
	for portal in props.portals():
		portal_nodes += _count_draw(portal)
	var excl := total - portal_nodes
	print("  draw nodes: %d total in Props, %d inside portals, %d excluding portals"
		% [total, portal_nodes, excl])
	_check(excl == _EXPECTED_DRAW_NODES_EXCL_PORTALS,
		"still %d draw nodes excluding portals" % _EXPECTED_DRAW_NODES_EXCL_PORTALS)
	print("")

## PHASE F -- the portal loop still runs, with the tint hook ahead of it.
##
## This batch inserted code into _on_hop_landed ABOVE the portal loop. That
## loop is what gets a player into a sub-game, and the whole screen exists to
## reach one -- so "does a landing in a portal still open its dialog" is the
## assertion the insertion point owes, and it is worth more than any number
## about colour. It also gates the ordering the hook was placed for: a landing
## that opens a dialog must ALSO have updated the tint on its way past.
func _phase_f_portals(hub: Node, keepy: KeepyHopper, props: HubBuilder) -> void:
	print("--- PHASE F: portals still fire, and the tint ran first ---")
	var dialog: HubConfirmDialog = hub.get_node("ConfirmDialog") as HubConfirmDialog
	var slot: ModelSlot = keepy.body_slot()
	var portals := props.portals()
	_check(portals.size() == 3, "three portals on the plateau")
	var opened: Array[StringName] = []
	dialog.confirmed.connect(func(id: StringName) -> void: opened.append(id))
	for portal in portals:
		dialog.close()
		await get_tree().process_frame
		var centre := portal.global_position
		keepy.hop_landed.emit(centre)
		await _settle()
		_check(dialog.is_open(), "a landing on '%s' opened its dialog" % portal.display_label())
		# The hook runs before the portal branch returns, so a dry portal
		# landing must have left the tint OFF rather than skipped it.
		_check(_base_captured and _near(_drawn_albedo(slot), _base_albedo),
			"'%s': the tint was updated (dry) on the way past" % portal.display_label())
	dialog.close()
	await get_tree().process_frame
	print("")

func _count_draw(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		n += 1
	for child in node.get_children():
		n += _count_draw(child)
	return n

## The albedo actually bound on the surfaces the slot draws. Returns the
## first one found; PHASE C's whole point is that this is not the variable
## HubWorld wrote.
func _drawn_albedo(slot: ModelSlot) -> Color:
	var mat := slot.slot_material() as StandardMaterial3D
	return Color.MAGENTA if mat == null else mat.albedo_color

## Long enough for a KEEPY_TINT_FADE_S tween to finish, in real frames.
func _settle() -> void:
	for i in 40:
		await get_tree().process_frame

func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.002 and absf(a.g - b.g) < 0.002 and absf(a.b - b.b) < 0.002

func _fmt(c: Color) -> String:
	return "rgb(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b]
