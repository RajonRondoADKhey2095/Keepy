extends Node

## Gates the zipline's TIER 2: the badger that waits, the tap door that
## withdraws, and the trip that carries two bodies on one trolley.
##
## =====================================================================
## WHY GATED AND NOT MERELY REPORTED
##
## Every way this feature fails is SILENT. A door that never withdraws is
## the banned ladder pattern and looks exactly like a working one until a
## player taps mid-trip. A second rider written on its own callback is a
## frame behind its carrier -- 12.0 deg at the peak of the turnstile's
## shove, MEASURED, and here it would be 10.8 cm of a badger sliding off a
## handle. A trip that leaves the badger at the wrong end makes the return
## journey untappable. A hook wired below one of `_on_hop_landed`'s five
## early returns simply never fires. Not one of those raises, breaks a
## build, or looks like anything but "tier 2 was never switched on".
##
## =====================================================================
## HEADLESS IS THE RIGHT DRIVER HERE, AND THAT IS NOT AN OVERSIGHT
##
## CLAUDE.md's rule is that anything reading PIXELS, MultiMesh instance
## transforms, a screen point or a shader must run under
## `xvfb-run --rendering-driver opengl3`, because `--headless` forces the
## DUMMY driver and each of those reads back empty or wrong -- silently,
## and green.
##
## This file reads none of them. The trolley is an ordinary Node3D with
## MeshInstance3D children, so every position here comes from the SCENE
## graph; the seats are arithmetic; the corridor is a distance test. The
## sibling `ZiplineStructureProbe` DOES read MultiMesh transforms and says
## in its own header that it must have opengl3 -- that split is deliberate,
## and running this one under llvmpipe would cost minutes of walking
## simulation for nothing.
##
## ⚠️ `--fixed-fps 60` IS REQUIRED. The trip is a 4 s tween and the walk is
## a chain of 0.28 s arcs; without the flag the simulation runs at wall
## time and the frame guards below become a stopwatch on the machine.
##
## =====================================================================
## WHAT THIS PROBE CANNOT DECIDE
##
## Whether two small animals hanging off a wire READ as a pair riding a
## zipline on a six-inch screen, under a camera that never yaws, from an
## end that cannot see the other end. RECON 5 measured that asymmetry and
## Mathieu accepted it. No probe in this repo scores legibility inside a
## luminance band. That is the device gate, and it is the one that remains.

const HUB_SCENE: PackedScene = preload("res://scenes/HubWorld.tscn")

## The two points Mathieu froze, restated so a layout edit that moved them
## fails here rather than quietly relocating the ride.
const P1 := Vector3(27.7, 0.0, 9.2)
const P2 := Vector3(25.2, 0.0, 35.0)

var _hub: Node = null
var _props: HubBuilder = null
var _keepy: KeepyHopper = null
var _tap: HubTapInput = null
var _door: ZiplineDoor = null
var _failures: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "ZiplineRideProbe")
	var dl := ProbeWatchdog.deadline("ZiplineRideProbe")
	print("=== ZIPLINE RIDE PROBE (tier 2) ===")
	_hub = HUB_SCENE.instantiate()
	add_child(_hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_props = _hub.get_node("WorldViewport/SubViewport/World/Props")
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
	_tap = _hub.get_node("TapInput")
	_door = _hub.get_node("ZiplineDoor")

	_phase_registry()
	_phase_seats()
	_phase_corridor()
	await _phase_cancel()
	await _phase_trip()
	await _phase_arrival()
	await _phase_return()
	_phase_untouched()
	dl.abort_if_exceeded()

	print("")
	print("--- %d failure(s) ---" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _check(ok: bool, label: String) -> void:
	print("  %s  %s" % ["OK  " if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _zip() -> Dictionary:
	var all: Array[Dictionary] = _props.ziplines()
	return {} if all.size() != 1 else all[0]

func _badger() -> HubActorWalker:
	return _hub._badger as HubActorWalker

# ---------------------------------------------------------------- registry
## The published table and the two live objects it names. An unbuilt
## trolley or an unhanded door is the single failure that makes every other
## assertion below pass for free, so it is asserted first.
func _phase_registry() -> void:
	print("")
	print("--- PHASE REGISTRY ---")
	var all: Array[Dictionary] = _props.ziplines()
	_check(all.size() == 1, "exactly one zipline published (size %d)" % all.size())
	var zip: Dictionary = _zip()
	if zip.is_empty():
		return
	for key in ["towers", "cable", "cable_height", "rider_drop", "clear_radius",
			"carrier", "bar_drop", "rider_lateral", "hang_clearance"]:
		_check(zip.has(key), "ziplines() publishes \"%s\"" % key)

	var towers: Array = zip["towers"]
	_check((towers[0]["position"] as Vector3).distance_to(P1) < 0.001,
		"tower 0 is still on P1 %s" % P1)
	_check((towers[1]["position"] as Vector3).distance_to(P2) < 0.001,
		"tower 1 is still on P2 %s" % P2)

	var carrier: Node3D = zip.get("carrier")
	_check(carrier != null and is_instance_valid(carrier), "the trolley node exists")
	if carrier == null:
		return
	_check(carrier.name == "Trolley", "the carrier is the Trolley root, not one of its meshes")
	var cable: Dictionary = zip["cable"]
	_check(carrier.global_position.distance_to(cable["from"] as Vector3) < 0.001,
		"the trolley starts PARKED on the near anchor (%.6f u)"
			% carrier.global_position.distance_to(cable["from"] as Vector3))

	# The badger, and the fact that it is standing on the ground at the
	# near end rather than anywhere the layout happens to put an actor.
	var badger: HubActorWalker = _badger()
	_check(badger != null, "the badger actor was built")
	if badger == null:
		return
	_check(absf(badger.global_position.y) < 0.001,
		"it stands ON the ground (y = %.4f)" % badger.global_position.y)
	var rest0: Vector3 = _hub._badger_rest(0)
	_check(badger.global_position.distance_to(rest0) < 0.001,
		"at end 0's rest point %s" % rest0)
	_check(HubRegion.contains(rest0), "which is inside the walkable region")
	# BESIDE THE STAIR AND NOT ON IT. The flight is STRINGER_HALF_SPAN wide
	# either side of its centre line, so an actor standing inside that band
	# would be a body Keepy walks through on his way up.
	var tower0: Dictionary = towers[0]
	var fwd: Vector3 = tower0["forward"]
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	var off_axis: float = absf((rest0 - (tower0["stair_foot"] as Vector3)).dot(side))
	_check(off_axis > HubBuilder.ZIPLINE_STRINGER_HALF_SPAN,
		"it waits %.3f u off the stair's centre line, clear of the %.2f u rail"
			% [off_axis, HubBuilder.ZIPLINE_STRINGER_HALF_SPAN])
	# 3 septembre 2026: no longer "the badger is drawn at Keepy's own
	# height" -- Mathieu's device feedback overrode that, and the badger is
	# now DELIBERATELY taller (geometric-mean rescale, see HubWorld's own
	# BADGER_SCALE docblock). What still has to hold is the ORDERING: the
	# badger reads bigger than Keepy but still smaller than the bear, or the
	# three-actor cast collapses into two animals the same size.
	var scale_drawn: float = HubWorld.BADGER_REST_SPAN * HubWorld.BADGER_SCALE
	_check(absf(scale_drawn - HubWorld.BADGER_DRAWN_HEIGHT) < 0.0005,
		"the badger is drawn at its own published height, %.4f (derived, not typed)" % scale_drawn)
	_check(scale_drawn > HubWorld.KEEPY_DRAWN_HEIGHT,
		"and it is TALLER than Keepy (%.4f > %.4f) -- the device defect this rescale fixes"
			% [scale_drawn, HubWorld.KEEPY_DRAWN_HEIGHT])
	_check(scale_drawn < HubWorld.BEAR_DRAWN_HEIGHT,
		"while staying SHORTER than the bear (%.4f < %.4f), so the two animals stay apart on screen"
			% [scale_drawn, HubWorld.BEAR_DRAWN_HEIGHT])

	# THE DOOR. A door nobody asks never withdraws, and that failure is
	# silent -- it looks exactly like a working tap.
	_check(_tap.zipline == _door, "HubTapInput resolved THIS ZiplineDoor")
	_check(_door.is_available(), "the door is open with nothing riding")
	_check(_door.waiting_end() == 0, "the badger is registered as waiting at end 0")
	_check(_door.is_available_at(0), "end 0 accepts boarding")
	_check(not _door.is_available_at(1), "end 1 does NOT -- there is nobody there to tap")
	_check(_door.rider_position().distance_to(Vector3(rest0.x, 0.0, rest0.z)) < 0.001,
		"the tap disc is centred on the LIVE actor, not on a remembered point")

# ------------------------------------------------------------------- seats
## The arithmetic the two seats are built from, and the defect it exists to
## close: a rider measured down from the CABLE has his head above the bar
## he is holding.
func _phase_seats() -> void:
	print("")
	print("--- PHASE SEATS ---")
	var zip: Dictionary = _zip()
	if zip.is_empty():
		return
	var cable_h: float = float(zip["cable_height"])
	var bar_drop: float = float(zip["bar_drop"])
	var clearance: float = float(zip["hang_clearance"])
	var height: float = HubWorld.KEEPY_DRAWN_HEIGHT
	var badger_height: float = HubWorld.BADGER_DRAWN_HEIGHT

	var keepy_seat: Vector3 = _hub._zip_seat(-1.0, height)
	var badger_seat: Vector3 = _hub._zip_seat(1.0, badger_height)
	_check(absf(keepy_seat.x + badger_seat.x) < 1.0e-6,
		"the two seats are mirror images across the trolley (%.3f / %.3f)"
			% [keepy_seat.x, badger_seat.x])
	_check(absf(keepy_seat.x) > 0.0,
		"and they are genuinely APART -- a lateral of 0 would be two bodies in one place")
	# 3 septembre 2026: the badger is no longer scaled to Keepy's own
	# height (device feedback overrode that, see HubWorld's BADGER_SCALE),
	# so the two feet no longer hang level. What the shared bar STILL
	# guarantees is that both CROWNS do -- see `_zip_seat`'s own docblock
	# for why `height` cancels out of that half of the formula.
	_check(absf((keepy_seat.y - badger_seat.y) - (badger_height - height)) < 1.0e-6,
		"the feet differ by exactly the height gap (%.4f / %.4f), not by chance"
			% [keepy_seat.y, badger_seat.y])
	_check(absf(keepy_seat.x) < HubBuilder.ZIPLINE_TROLLEY_BAR_HALF_SPAN,
		"each rider hangs FROM the bar (%.2f) and not off its end (%.2f)"
			% [absf(keepy_seat.x), HubBuilder.ZIPLINE_TROLLEY_BAR_HALF_SPAN])

	# THE DEFECT, stated as an assertion rather than as a comment: the
	# crown must be UNDER the bar, and the feet clear of the ground. Checked
	# for BOTH riders now that they are different heights -- the crown
	# maths says they should land on the SAME crown_y, but "should" is
	# exactly the kind of claim this repo's doctrine measures instead of
	# trusting.
	var bar_y: float = cable_h - bar_drop
	for pair in [["Keepy", keepy_seat, height], ["the badger", badger_seat, badger_height]]:
		var who: String = pair[0]
		var seat: Vector3 = pair[1]
		var h: float = pair[2]
		var feet_y: float = cable_h + seat.y
		var crown_y: float = feet_y + h
		_check(crown_y <= bar_y + 1.0e-6,
			"%s's crown (%.4f) is UNDER the grab bar (%.4f) -- measuring from the cable put it %.3f u above"
				% [who, crown_y, bar_y, (cable_h - clearance) + 0.0 - bar_y])
		_check(crown_y < cable_h,
			"%s is therefore under the cable itself (%.4f < %.4f)" % [who, crown_y, cable_h])
		_check(feet_y > 0.0, "%s's feet are off the ground (%.4f)" % [who, feet_y])
		_check(feet_y < HubBuilder.ZIPLINE_DECK_HEIGHT,
			"and %s is BELOW the deck (%.4f < %.4f), so boarding is a step off it and a drop"
				% [who, feet_y, HubBuilder.ZIPLINE_DECK_HEIGHT])
	_check(absf((cable_h + keepy_seat.y + height) - (cable_h + badger_seat.y + badger_height)) < 1.0e-6,
		"and the two crowns land on the SAME height regardless of the badger's own, taller, height")

	# BLIND CHECK. "The crown is under the bar" is satisfied for free by a
	# seat function that ignores its height argument. Feed it a taller body
	# and the seat must move DOWN by exactly that much.
	var taller: Vector3 = _hub._zip_seat(-1.0, height + 0.5)
	_check(absf((keepy_seat.y - taller.y) - 0.5) < 1.0e-6,
		"BLIND CHECK: a body 0.5 u taller hangs 0.5 u lower (%.6f), so the height argument is read"
			% (keepy_seat.y - taller.y))

# ---------------------------------------------------------------- corridor
## What the two hanging bodies actually sweep, against everything else that
## is DRAWN on the plateau at their own height.
##
## ⚠️ THIS IS NOT RECON 5's SWEEP AND IT HAD TO BE REDONE TWICE.
##
## RECON 5 tested the corridor with a rider at `cable_height - rider_drop`
## = 0.90. A rider now hangs at 0.3599, because he holds a bar rather than
## floating at the deck's height, and he is offset laterally -- so the line
## RECON 5 cleared is not the line two bodies travel on.
##
## ⚠️ AND THE FIRST REWRITE USED THE WRONG QUANTITY, which is the failure
## CLAUDE.md names outright: a green number against a metric that is not
## the property. It measured `ground_footprints()`, which is the WALKABILITY
## disc -- "where a body may not STAND" -- and is both padded and infinitely
## tall. Against it every flower on the plateau was an obstacle to something
## flying past a metre above it, and the phase reported -0.438 u against
## props a rider clears by a metre of altitude.
##
## What a fly-past actually meets is DRAWN GEOMETRY WHOSE HEIGHT BAND
## OVERLAPS THE RIDERS'. So this walks the built tree, takes each mesh's
## real AABB (and each MultiMesh instance's), keeps only those whose
## vertical span reaches into [feet, crown], and measures flat clearance
## from the nearer rider's line against the rider's own measured half
## width. The zipline's own parts are excluded by ANCESTRY and not by name:
## `add_child` renames a second child called "Deck", so the far tower's own
## deck arrives as `@MeshInstance3D@161` and a name filter silently let it
## through as an obstacle.
func _phase_corridor() -> void:
	print("")
	print("--- PHASE CORRIDOR ---")
	var zip: Dictionary = _zip()
	if zip.is_empty():
		return
	var rows: Array = _corridor_rows(0.0)
	_check(not rows.is_empty(),
		"%d drawn parts reach into the riders' height band -- an empty list would pass this phase for free"
			% rows.size())
	var worst: float = INF
	var worst_at: String = ""
	for row in rows:
		if float(row[1]) < worst:
			worst = float(row[1])
			worst_at = String(row[0])
	_check(worst > 0.0,
		"both riders clear every drawn obstacle by %.3f u at their worst point (%s)"
			% [worst, worst_at])

	# BLIND CHECK: the test must be able to SEE a blocked corridor. Widen
	# the riders until something has to be in the way, and it must fail.
	var fattened: float = INF
	for row in _corridor_rows(worst + 0.5):
		fattened = minf(fattened, float(row[1]))
	_check(fattened < 0.0,
		"BLIND CHECK: with the riders %.3f u wider the same test reports %.3f u -- it can see a blocked corridor"
			% [worst + 0.5, fattened])

## Every drawn part whose height band overlaps the riders', with its flat
## clearance. `fatten` grows the riders, for the blind check.
func _corridor_rows(fatten: float) -> Array:
	var zip: Dictionary = _zip()
	var cable: Dictionary = zip["cable"]
	var a: Vector3 = cable["from"]
	var b: Vector3 = cable["to"]
	var flat_a := Vector3(a.x, 0.0, a.z)
	var flat_b := Vector3(b.x, 0.0, b.z)
	# The crown is the SAME height for both riders regardless of body height
	# (see `_zip_seat`'s own docblock -- it cancels out of the formula), so
	# Keepy's seat gives it for free. The FEET are not: the taller badger
	# (3 septembre 2026 rescale) hangs lower than Keepy, so the swept band
	# has to reach down to WHICHEVER foot is lowest, or a part that only
	# grazes the badger's dangling legs would be missed.
	var seat: Vector3 = _hub._zip_seat(-1.0, HubWorld.KEEPY_DRAWN_HEIGHT)
	var badger_seat: Vector3 = _hub._zip_seat(1.0, HubWorld.BADGER_DRAWN_HEIGHT)
	var crown: float = float(zip["cable_height"]) + seat.y + HubWorld.KEEPY_DRAWN_HEIGHT
	var feet: float = float(zip["cable_height"]) + minf(seat.y, badger_seat.y)
	var reach: float = float(zip["rider_lateral"]) + HubWorld.KEEPY_CLEARANCE + fatten
	var rows: Array = []
	_corridor_walk(_props, flat_a, flat_b, feet, crown, reach, rows)
	return rows

func _corridor_walk(n: Node, a: Vector3, b: Vector3, feet: float, crown: float,
		reach: float, rows: Array) -> void:
	# BY ANCESTRY, not by name: the zipline's own second deck is renamed by
	# add_child and a name filter lets it through as an obstacle.
	if String(n.name).begins_with("Zipline"):
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		_corridor_part(String(n.name), (n as MeshInstance3D).get_aabb(),
			(n as MeshInstance3D).global_transform, a, b, feet, crown, reach, rows)
	elif n is MultiMeshInstance3D:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if mm != null and mm.mesh != null:
			for i in mm.instance_count:
				_corridor_part("%s#%d" % [n.name, i], mm.mesh.get_aabb(),
					(n as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i),
					a, b, feet, crown, reach, rows)
	for c in n.get_children():
		_corridor_walk(c, a, b, feet, crown, reach, rows)

func _corridor_part(label: String, aabb: AABB, xform: Transform3D, a: Vector3, b: Vector3,
		feet: float, crown: float, reach: float, rows: Array) -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for c in 8:
		var p: Vector3 = xform * (aabb.position + Vector3(
			aabb.size.x * float(c & 1), aabb.size.y * float((c >> 1) & 1),
			aabb.size.z * float((c >> 2) & 1)))
		lo = lo.min(p)
		hi = hi.max(p)
	if hi.y < feet or lo.y > crown:
		return
	var centre := Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.z + hi.z) * 0.5)
	# The box's own flat half-diagonal: conservative on purpose, since the
	# drawn mesh is always inside the box it is measured by.
	var half: float = 0.5 * Vector2(hi.x - lo.x, hi.z - lo.z).length()
	rows.append([label, _seg_distance(centre, a, b) - reach - half])

func _seg_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# ------------------------------------------------------------------ cancel
## DOOR 1 (RECON 1): during the approach walk, an ordinary tap has to
## CANCEL the intent. A walk that arrived anyway would be the screen
## overruling the player, and it is the half of the pattern that keeps a
## multi-second approach from being a window where taps do nothing.
func _phase_cancel() -> void:
	print("")
	print("--- PHASE CANCEL (door 1: the approach) ---")
	var zip: Dictionary = _zip()
	if zip.is_empty():
		return
	_keepy.global_position = Vector3(18.0, 0.0, 9.0)
	await get_tree().process_frame
	_hub._on_tapped_zipline(_door.rider_position())
	_check(_hub._zipping, "the tap armed the ride intent")
	_check(_keepy.is_hopping(), "and started a walk (he is 9 u away, so this is many hops)")
	# One ordinary tap somewhere else.
	_hub._on_tapped_ground(Vector3(10.0, 0.0, 4.0))
	_check(not _hub._zipping, "an ordinary tap CANCELLED it -- no state with no way out")
	var guard: int = 0
	while _keepy.is_hopping() and guard < 1200:
		guard += 1
		await get_tree().process_frame
	_check(not _keepy.is_on_zipline(),
		"and the walk that followed did NOT board (%d frames)" % guard)
	_check(_door.is_available_at(0), "the door never closed, because no trip ever started")

# -------------------------------------------------------------------- trip
## DOOR 2: a real tap, a real walk, a real boarding and a real trip --
## through the shipped signal chain rather than by calling `board_zipline`
## directly, because the failure this phase exists to catch is a hook wired
## below one of `_on_hop_landed`'s five early returns.
func _phase_trip() -> void:
	print("")
	print("--- PHASE TRIP (door 2: the crossing) ---")
	var zip: Dictionary = _zip()
	if zip.is_empty():
		return
	var carrier: Node3D = zip["carrier"]
	var badger: HubActorWalker = _badger()

	_keepy.global_position = Vector3(23.0, 0.0, 9.0)
	await get_tree().process_frame
	_hub._on_tapped_zipline(_door.rider_position())
	var guard: int = 0
	while not _keepy.is_on_zipline() and guard < 2400:
		guard += 1
		await get_tree().process_frame
	_check(_keepy.is_on_zipline(), "he walked to the tower and took the handle (%d frames)" % guard)
	if not _keepy.is_on_zipline():
		return

	# THE WITHDRAWAL, and it is the brief's rule in full: BOTH ends, in
	# either direction, for the whole of the trip.
	_check(not _door.is_available(), "the door withdrew for the trip")
	_check(not _door.is_available_at(0) and not _door.is_available_at(1),
		"BOTH ends are closed, not just the one departed from")
	_check(not _door.accepts_boarding_tap(P1) and not _door.accepts_boarding_tap(P2),
		"and a tap at either tower is refused, so it falls through to the ground path")

	# THE ONE-FRAME LAG, which is the measured defect the whole
	# write-both-riders-in-one-call shape exists to avoid. Sampled across
	# real frames with the tween genuinely stepping.
	var worst_keepy: float = 0.0
	var worst_badger: float = 0.0
	var travelled: float = 0.0
	var previous: Vector3 = carrier.global_position
	var keepy_seat: Vector3 = _hub._zip_seat(-1.0, HubWorld.KEEPY_DRAWN_HEIGHT)
	var badger_seat: Vector3 = _hub._zip_seat(1.0, HubWorld.BADGER_DRAWN_HEIGHT)
	for i in 90:
		await get_tree().process_frame
		if not _keepy.is_on_zipline():
			break
		worst_keepy = maxf(worst_keepy,
			_keepy.global_position.distance_to(carrier.to_global(keepy_seat)))
		worst_badger = maxf(worst_badger,
			badger.global_position.distance_to(carrier.to_global(badger_seat)))
		travelled += previous.distance_to(carrier.global_position)
		previous = carrier.global_position
	# BLIND CHECK, and for the reason the owl's has one: "he is exactly on
	# the seat" is satisfied for free by a trolley that never moved.
	_check(travelled > 3.0,
		"BLIND CHECK: the trolley really covered %.2f u under them, so the two lags below mean something"
			% travelled)
	_check(worst_keepy < 0.0005,
		"Keepy is never a frame behind the handle (worst %.6f u)" % worst_keepy)
	_check(worst_badger < 0.0005,
		"and NEITHER IS THE BADGER (worst %.6f u) -- both written in the carrier's own call"
			% worst_badger)
	# NOT a shared magic floor: 0.2 was fine while both riders hung at the
	# same 0.3599, but the taller badger's own feet (3 septembre 2026
	# rescale) sit at a measured 0.112569, under that floor while still
	# genuinely airborne. Each body's OWN expected feet height (PHASE
	# SEATS' own formula) is the honest floor, at half of it -- comfortably
	# above a rider resting at y=0, comfortably below the real value.
	var keepy_floor: float = 0.5 * (float(zip["cable_height"]) + keepy_seat.y)
	var badger_floor: float = 0.5 * (float(zip["cable_height"]) + badger_seat.y)
	_check(_keepy.global_position.y > keepy_floor and badger.global_position.y > badger_floor,
		"both are genuinely off the ground (%.3f > %.3f / %.3f > %.3f)"
			% [_keepy.global_position.y, keepy_floor, badger.global_position.y, badger_floor])

	# A tap mid-trip reaches the ground path and is dropped there -- the
	# bounded-tween licence. What must NOT happen is a second trip or a
	# body walking off the wire.
	_hub._on_tapped_ground(Vector3(0.0, 0.0, 0.0))
	_check(_keepy.is_on_zipline(), "a tap mid-trip did not walk him off the wire")
	_check(_hub._zip_trip.size() == 2, "and did not start a second trip")

	# No portal can fire while the wire has him.
	var fired: int = 0
	for portal in _props.portals():
		if portal.landed_within(_keepy.global_position):
			fired += 1
	_hub._on_hop_landed(Vector3(-5.4, 0.0, -4.6))
	_check(not _hub._confirm.is_open() and fired == 0,
		"a landing at a portal centre mid-trip opens nothing")

# ----------------------------------------------------------------- arrival
## DOOR 3: the pair arrives, the badger becomes the far end's tap target,
## and Keepy is put down on ground he can stand on and OUTSIDE the disc he
## would otherwise re-board from.
func _phase_arrival() -> void:
	print("")
	print("--- PHASE ARRIVAL (door 3) ---")
	var zip: Dictionary = _zip()
	if zip.is_empty():
		return
	var carrier: Node3D = zip["carrier"]
	var badger: HubActorWalker = _badger()
	var guard: int = 0
	while _keepy.is_on_zipline() and guard < 2400:
		guard += 1
		await get_tree().process_frame
	_check(not _keepy.is_on_zipline(), "the trip ended and he let go (%d frames)" % guard)
	var cable: Dictionary = zip["cable"]
	_check(carrier.global_position.distance_to(cable["to"] as Vector3) < 0.001,
		"the trolley is parked on the FAR anchor, to %.6f u"
			% carrier.global_position.distance_to(cable["to"] as Vector3))

	var rest1: Vector3 = _hub._badger_rest(1)
	_check(badger.global_position.distance_to(rest1) < 0.001,
		"the badger is standing at end 1's rest point %s" % rest1)
	_check(absf(badger.global_position.y) < 0.001,
		"back on the ground (y = %.4f), not still at handle height" % badger.global_position.y)
	_check(_door.waiting_end() == 1, "the door now names end 1")
	_check(_door.is_available_at(1) and not _door.is_available_at(0),
		"end 1 accepts boarding and end 0 no longer does -- the target MOVED with the actor")

	guard = 0
	while _keepy.is_hopping() and guard < 1200:
		guard += 1
		await get_tree().process_frame
	var landed := Vector3(_keepy.global_position.x, 0.0, _keepy.global_position.z)
	_check(absf(_keepy.global_position.y) < 0.001,
		"he came DOWN, not up: y = %.4f" % _keepy.global_position.y)
	_check(HubRegion.contains(landed), "and onto walkable ground %s" % landed)
	_check(landed.distance_to(P2) > float(zip["clear_radius"]),
		"clear of the far tower's own footprint (%.2f u vs %.2f)"
			% [landed.distance_to(P2), float(zip["clear_radius"])])
	# NO STATE WITH NO WAY OUT: an ordinary tap has to work again.
	_hub._on_tapped_ground(Vector3(20.0, 0.0, 30.0))
	_check(_keepy.is_hopping() or _keepy.global_position.distance_to(Vector3(20.0, 0.0, 30.0)) < 1.0,
		"and an ordinary tap moves him again")
	guard = 0
	while _keepy.is_hopping() and guard < 1200:
		guard += 1
		await get_tree().process_frame

# ------------------------------------------------------------------ return
## THE OTHER DIRECTION, which is the whole reason the door carries an END
## rather than a bool: a shortcut you can only take one way is a one-way
## door, and Mathieu's decision was a bidirectional one.
func _phase_return() -> void:
	print("")
	print("--- PHASE RETURN (the other direction) ---")
	var zip: Dictionary = _zip()
	if zip.is_empty():
		return
	var carrier: Node3D = zip["carrier"]
	_keepy.global_position = Vector3(24.0, 0.0, 33.0)
	await get_tree().process_frame
	_hub._on_tapped_zipline(_door.rider_position())
	var guard: int = 0
	while not _keepy.is_on_zipline() and guard < 2400:
		guard += 1
		await get_tree().process_frame
	_check(_keepy.is_on_zipline(), "a tap at END 1 boarded him (%d frames)" % guard)
	if not _keepy.is_on_zipline():
		return
	_check(int(_hub._zip_trip["from"]) == 1 and int(_hub._zip_trip["to"]) == 0,
		"and the trip runs 1 -> 0, the other way down the same wire")
	# The trolley must face the way it is going on the way back too: a
	# carrier that kept its build basis would carry two riders backwards.
	var forward: Vector3 = carrier.global_transform.basis * Vector3.BACK
	var travel: Vector3 = (zip["cable"]["from"] as Vector3) - (zip["cable"]["to"] as Vector3)
	forward.y = 0.0
	travel.y = 0.0
	_check(forward.normalized().dot(travel.normalized()) > 0.999,
		"the trolley turned round: its +Z now points down the return run (dot %.4f)"
			% forward.normalized().dot(travel.normalized()))

	guard = 0
	while _keepy.is_on_zipline() and guard < 2400:
		guard += 1
		await get_tree().process_frame
	_check(_door.waiting_end() == 0, "the pair is back at end 0 and the door says so")
	_check(_badger().global_position.distance_to(_hub._badger_rest(0)) < 0.001,
		"with the badger on end 0's rest point again")
	_check(carrier.global_position.distance_to(zip["cable"]["from"] as Vector3) < 0.001,
		"and the trolley parked back on the near anchor")
	guard = 0
	while _keepy.is_hopping() and guard < 1200:
		guard += 1
		await get_tree().process_frame

# --------------------------------------------------------------- untouched
## The props this batch shares files with. HubTapInput, KeepyHopper,
## HubWorld and HubBuilder are all touched here, so "the boat and the
## ladder still work" is not something to take on trust.
func _phase_untouched() -> void:
	print("")
	print("--- PHASE UNTOUCHED ---")
	_check(_tap.ladder_radius > 0.0 and _tap.ladder_feet.size() == 3,
		"the three ladder feet are still handed to the tap")
	_check(_props.diving_boards().size() == 3, "three diving boards still published")
	_check(_props.seesaws().size() == 1, "the seesaw still published")
	_check(_props.spinning_props().size() == 1, "the turnstile still published")
	_check(_props.owls().size() == 1, "the owl still published")
	_check(_props.portals().size() == 3, "the three portals still published")
	_check(_tap.owl_available, "and the owl perch is still open")
	_check(_hub._bear != null, "the bear is still on the plateau")
	_check(not _keepy.is_on_zipline(), "and Keepy is off the wire")
