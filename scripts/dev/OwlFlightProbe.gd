extends Node

## Gates the owl flight: the perch Keepy walks to, the closed loop the owl
## carries him round, and the step off it at the end.
##
## WHY GATED AND NOT MERELY REPORTED. Every way this feature fails is
## SILENT. An empty registry, a tap signal that never reaches HubWorld, a
## take-off hook wired below one of the early returns in _on_hop_landed, a
## rider sampled a frame behind the bird he is sitting on, a curve that
## does not quite close so the owl creeps off its perch a little further
## every flight, a dismount that comes down inside the tap radius -- not
## one of those raises, breaks a build, or looks like anything other than
## "the flight was never switched on".
##
## ⚠️ WHAT THIS PROBE CANNOT DECIDE. It measures POSITIONS, NODES and
## SIGNALS, never how a flight READS. Whether an owl looping out and back
## over 3.2 seconds looks like a bird taking a passenger for a turn, or
## like a prop sliding through the air, is a device judgement -- and so is
## whether a perch beside the spawn reads as something to tap at all.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")

## The layout entry this batch ships, read back rather than restated: LOT
## PROPS-1 put the owl at (0, 0, -3.4), squarely on the line from the spawn
## to the Quizz portal, where its tap disc both overlapped Quizz's and sat
## across every tap aimed at it.
const _EXPECTED_PERCH: Vector3 = Vector3(-2.7, 0.0, 0.8)

var _hub: Node = null
var _props: HubBuilder = null
var _keepy: KeepyHopper = null
var _tap: HubTapInput = null
var _failures: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "OwlFlightProbe")
	var dl := ProbeWatchdog.deadline("OwlFlightProbe")
	print("=== OWL FLIGHT PROBE ===")
	_hub = HUB_SCENE.instantiate()
	add_child(_hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_props = _hub.get_node("WorldViewport/SubViewport/World/Props")
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
	_tap = _hub.get_node("TapInput")

	_phase_registry()
	_phase_curve()
	await _phase_framing()
	await _phase_flight()
	await _phase_dismount()
	_phase_untouched()
	dl.abort_if_exceeded()

	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	print("  %s  %s" % ["OK  " if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _entry() -> Dictionary:
	var owls: Array[Dictionary] = _props.owls()
	return {} if owls.is_empty() else owls[0]

# ---------------------------------------------------------------- registry
## The published table, and the fact that it is a LIST. An empty registry is
## the single failure that makes every other assertion below pass for free,
## so it is asserted first and everything else is skipped without it.
func _phase_registry() -> void:
	print("")
	print("--- PHASE REGISTRY ---")
	var owls: Array[Dictionary] = _props.owls()
	_check(owls.size() == 1, "exactly one owl published, and from a LIST (size %d)" % owls.size())
	if owls.is_empty():
		return
	var e: Dictionary = owls[0]
	_check(e.has("position") and e.has("carrier") and e.has("seat_y"),
		"the entry carries position / carrier / seat_y")
	var perch: Vector3 = e["position"]
	_check(perch.distance_to(_EXPECTED_PERCH) < 0.001,
		"perched at the shipped position %s (measured %s)" % [_EXPECTED_PERCH, perch])
	var carrier: Node3D = e["carrier"]
	_check(carrier != null and is_instance_valid(carrier), "the carrier node exists")
	_check(carrier != null and carrier.name == "Owl", "the carrier is the Owl root, not the model child")
	_check(carrier != null and carrier.global_position.distance_to(perch) < 0.001,
		"the owl starts ON its perch")
	_check(float(e["seat_y"]) > 0.0, "the seat is above the owl's feet (%.3f)" % float(e["seat_y"]))

	# The tap must actually be able to pick it out. An unhanded perch list
	# is a signal that never fires, which looks exactly like a dead prop.
	_check(_tap.owl_radius > 0.0, "HubWorld handed the tap a reach (%.2f)" % _tap.owl_radius)
	_check(_tap.owl_perches.size() == 1 and _tap.owl_perches[0].distance_to(perch) < 0.001,
		"the tap was handed the BUILT perch, not a second copy of the layout")
	_check(_tap.owl_available, "the perch accepts taps while nothing is flying")

	# The defect this batch was asked to close: the tap disc used to reach
	# into the Quizz portal's trigger ring by 0.05 u, and sat across the
	# only line a player walks from the spawn to that portal.
	var quizz := Vector3(0.0, 0.0, -7.2)
	var gap: float = perch.distance_to(quizz) - _tap.owl_radius - 1.35
	_check(gap > 0.0, "the tap disc clears the Quizz trigger ring by %.3f u" % gap)
	var lateral: float = absf(perch.x)
	_check(lateral > 1.5, "and it is OFF the spawn->Quizz line by %.2f u, not merely narrower" % lateral)
	var spawn_gap: float = perch.length() - _tap.owl_radius
	_check(spawn_gap > 0.0, "the spawn itself is %.2f u OUTSIDE the tap disc" % spawn_gap)

# ------------------------------------------------------------------- curve
## The one property the curve was chosen for: it closes EXACTLY, by
## arithmetic rather than by a tuned duration. Sampled off the shipped
## _apply_flight through the real carrier, never off a copy of the formula
## -- a restated curve is free to drift from the one that flies.
func _phase_curve() -> void:
	print("")
	print("--- PHASE CURVE ---")
	var e: Dictionary = _entry()
	if e.is_empty():
		return
	var carrier: Node3D = e["carrier"]
	var perch: Vector3 = e["position"]
	var world = _hub

	world._apply_flight(0.0, e)
	var at_start: Vector3 = carrier.global_position
	world._apply_flight(1.0, e)
	var at_end: Vector3 = carrier.global_position
	_check(at_start.distance_to(perch) < 0.0001,
		"t=0 is the perch to %.6f u" % at_start.distance_to(perch))
	_check(at_end.distance_to(perch) < 0.0001,
		"t=1 is the perch AGAIN to %.6f u -- the loop closes" % at_end.distance_to(perch))

	# BLIND CHECK: "it comes back to where it started" is satisfied for
	# free by an owl that never moved. The loop has to be shown to go
	# somewhere before its closing means anything.
	world._apply_flight(0.5, e)
	var apex: Vector3 = carrier.global_position
	_check(apex.distance_to(perch) > 3.0,
		"BLIND CHECK: mid-loop it really is %.2f u from the perch, so the closure above means something"
			% apex.distance_to(perch))
	_check(apex.y > 1.0, "and %.2f u in the air at the top" % apex.y)

	# Height leaves and returns to the ground by the same arithmetic.
	world._apply_flight(0.0, e)
	var y0: float = carrier.global_position.y
	world._apply_flight(1.0, e)
	var y1: float = carrier.global_position.y
	_check(absf(y0) < 0.0001 and absf(y1) < 0.0001,
		"it starts and ends AT PERCH HEIGHT (%.6f, %.6f)" % [y0, y1])

	# Monotone climb then fall: a loop that jinked would be a sine that is
	# not the one this claims to be.
	var rising := true
	var falling := true
	for i in 10:
		var a: float = float(i) / 20.0
		var b: float = float(i + 1) / 20.0
		world._apply_flight(a, e)
		var ya: float = carrier.global_position.y
		world._apply_flight(b, e)
		if carrier.global_position.y <= ya:
			rising = false
		world._apply_flight(0.5 + a, e)
		ya = carrier.global_position.y
		world._apply_flight(0.5 + b, e)
		if carrier.global_position.y >= ya:
			falling = false
	_check(rising, "it climbs steadily over the first half")
	_check(falling, "and comes down steadily over the second")

	world._apply_flight(0.0, e)
	carrier.global_position = perch
	carrier.rotation_degrees.y = 0.0

# ----------------------------------------------------------------- framing
## THE WHOLE LOOP STAYS ON SCREEN, at both shipped ratios, measured with
## unproject_position on the REAL camera rather than worked out on paper.
##
## This is a gate and not a note because the first version of the loop
## failed it and nothing said so: at heading zero a quarter of the flight
## left the left edge -- the owl flew out, vanished, and came back -- and
## every other assertion in this file passed anyway. The lean that fixes it
## is a constant, so it can be tuned back out just as silently.
func _phase_framing() -> void:
	print("")
	print("--- PHASE FRAMING ---")
	var e: Dictionary = _entry()
	if e.is_empty():
		return
	var world: Node3D = _hub.get_node("WorldViewport/SubViewport/World")
	var cam: Camera3D = world.get_node("Camera3D")
	var container: SubViewportContainer = _hub.get_node("WorldViewport")
	var vp: SubViewport = _hub.get_node("WorldViewport/SubViewport")
	var carrier: Node3D = e["carrier"]
	# The container FORCES the viewport to its own size while stretch is on,
	# so a size written here is ignored with only a warning and the ratio
	# measured is the window's, not the one asked for. And the camera lerps
	# onto Keepy every frame, so its _process has to stop or the pose drifts
	# under the measurement -- both are traps this screen has already paid
	# for once.
	container.stretch = false
	cam.set_process(false)
	for size in [Vector2i(1080, 1920), Vector2i(1170, 2532)]:
		vp.size = size
		_keepy.global_position = Vector3.ZERO
		cam.global_position = Vector3(0.0, 7.6, 8.9)
		await get_tree().process_frame
		var inside: int = 0
		var margin: float = 1e9
		for i in 65:
			_hub._apply_flight(float(i) / 64.0, e)
			var sc: Vector2 = cam.unproject_position(carrier.global_position)
			if sc.x >= 0.0 and sc.x <= float(size.x) and sc.y >= 0.0 and sc.y <= float(size.y):
				inside += 1
			margin = minf(margin, minf(sc.x, float(size.x) - sc.x))
		_check(inside == 65,
			"%s: all 65 sampled points of the loop are on screen (%d)" % [size, inside])
		_check(margin > 40.0,
			"%s: and never closer than %.0f px to a side edge" % [size, margin])
	_hub._apply_flight(0.0, e)
	carrier.global_position = e["position"]
	carrier.rotation_degrees.y = 0.0
	container.stretch = true
	cam.set_process(true)

# ------------------------------------------------------------------ flight
## A real tap, a real walk, a real take-off -- through the shipped signal
## chain rather than by calling mount_owl() directly, because the failure
## this phase exists to catch is a hook wired below one of _on_hop_landed's
## early returns.
func _phase_flight() -> void:
	print("")
	print("--- PHASE FLIGHT ---")
	var e: Dictionary = _entry()
	if e.is_empty():
		return
	var perch: Vector3 = e["position"]
	var carrier: Node3D = e["carrier"]

	_keepy.global_position = Vector3.ZERO
	await get_tree().process_frame
	_hub._on_tapped_owl(perch)
	_check(_keepy.is_hopping() or _keepy.is_on_owl_flight(),
		"the tap started a walk to the perch")

	var guard: int = 0
	while not _keepy.is_on_owl_flight() and guard < 900:
		guard += 1
		await get_tree().process_frame
	_check(_keepy.is_on_owl_flight(),
		"he walked there and took off (%d frames)" % guard)
	if not _keepy.is_on_owl_flight():
		return
	_check(not _tap.owl_available,
		"the perch withdrew from the tap for the flight, so a tap now falls through to the ground path")

	# THE ONE-FRAME LAG, which is the measured defect this whole shape
	# exists to avoid: a rider who read his carrier on his own _process
	# callback was a full frame behind it. Sampled across real frames with
	# the tween genuinely stepping, not by calling the applier by hand.
	var worst: float = 0.0
	var travelled: float = 0.0
	var previous: Vector3 = carrier.global_position
	for i in 40:
		await get_tree().process_frame
		if not _keepy.is_on_owl_flight():
			break
		var seat: Vector3 = carrier.to_global(Vector3(0.0, float(e["seat_y"]), 0.0))
		worst = maxf(worst, _keepy.global_position.distance_to(seat))
		travelled += previous.distance_to(carrier.global_position)
		previous = carrier.global_position
	# BLIND CHECK again, and for the same reason: "he is exactly on the
	# seat" is satisfied for free by an owl that never moved under him.
	_check(travelled > 1.0,
		"BLIND CHECK: the owl really covered %.2f u under him, so the lag below means something" % travelled)
	_check(worst < 0.0005,
		"the rider is never a frame behind his carrier (worst %.6f u)" % worst)
	_check(_keepy.global_position.y > 0.2, "and he is genuinely off the ground")

	# No portal can fire while he is up there.
	var fired: int = 0
	for portal in _props.portals():
		if portal.landed_within(_keepy.global_position):
			fired += 1
	_hub._on_hop_landed(Vector3(-5.4, 0.0, -4.6))
	_check(not _hub._confirm.is_open() and fired == 0,
		"a landing at a portal centre mid-flight opens nothing")

func _phase_dismount() -> void:
	print("")
	print("--- PHASE DISMOUNT ---")
	var e: Dictionary = _entry()
	if e.is_empty():
		return
	var carrier: Node3D = e["carrier"]
	var perch: Vector3 = e["position"]
	var guard: int = 0
	while _keepy.is_on_owl_flight() and guard < 900:
		guard += 1
		await get_tree().process_frame
	_check(not _keepy.is_on_owl_flight(), "the loop ended and he was let off (%d frames)" % guard)
	_check(carrier.global_position.distance_to(perch) < 0.001,
		"the owl is back ON its perch, to %.6f u" % carrier.global_position.distance_to(perch))
	_check(_tap.owl_available, "and the perch takes taps again")

	guard = 0
	while _keepy.is_hopping() and guard < 900:
		guard += 1
		await get_tree().process_frame
	var landed := Vector3(_keepy.global_position.x, 0.0, _keepy.global_position.z)
	_check(absf(_keepy.global_position.y) < 0.001,
		"he came DOWN, not up: y = %.4f" % _keepy.global_position.y)
	_check(HubRegion.contains(landed), "and onto walkable ground %s" % landed)
	# The remount loop the turnstile had to learn about: a dismount that
	# lands inside the reach is a flight that never ends.
	_check(landed.distance_to(perch) > _tap.owl_radius,
		"clear of the perch's own reach (%.2f u vs %.2f)"
			% [landed.distance_to(perch), _tap.owl_radius])

## The props this batch shares files with, unchanged. HubTapInput,
## KeepyHopper and HubWorld are all touched here, so "the boat and the
## ladder still work" is not something to take on trust.
func _phase_untouched() -> void:
	print("")
	print("--- PHASE UNTOUCHED ---")
	_check(_tap.ladder_radius > 0.0 and _tap.ladder_feet.size() == 3,
		"the three ladder feet are still handed to the tap")
	_check(_props.diving_boards().size() == 3, "three diving boards still published")
	_check(_props.seesaws().size() == 1, "the seesaw still published")
	_check(_props.spinning_props().size() == 1, "the turnstile still published")
	_check(_props.portals().size() == 3, "the three portals still published")
	_check(_keepy.is_on_owl_flight() == false, "and Keepy is off the bird")
