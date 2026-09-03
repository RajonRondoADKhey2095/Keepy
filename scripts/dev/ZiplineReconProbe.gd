extends Node

## RECON ONLY. Measures the hub for a badger/Keepy ZIPLINE and writes
## comparative offscreen renders of the candidate cable runs. It asserts
## NOTHING, gates NOTHING and changes NOTHING in the shipped tree -- every
## piece of geometry it draws is built here, parented under a node this
## probe adds, and never enters the layout.
##
## =====================================================================
## WHY THE SILHOUETTES ARE MEASURED AND NOT READ OFF ground_footprints()
##
## `HubBuilder.ground_footprints()` answers "may a body LAND here". A cable
## strung four metres up asks a different question -- "does anything reach
## UP into this line" -- and the two answers differ by exactly the amount
## this repo already paid for once: a trunk footprints 0.24 while its crown
## spans 0.95 and floats two metres off the ground (see the boat's eject
## note). So PHASE A walks the BUILT tree and takes real world-space AABBs,
## including the ones hiding inside a MultiMesh, and PHASE C tests the
## cable against those rather than against the ground table.
##
## ⚠️ MUST RUN UNDER xvfb WITH --rendering-driver opengl3, NEVER --headless.
## PHASE B projects world points to screen through the real HubCamera and
## PHASE D reads pixels; under the DUMMY driver the viewport reports 0x0,
## `unproject_position` is meaningless and `get_image()` returns an empty
## surface -- a green run that measured nothing. The viewport rect is
## ASSERTED non-degenerate below so that failure is loud instead of free.

const _LABEL: String = "ZiplineReconProbe"
const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"
const _OUT_DIR: String = "user://zipline_recon"

## Frames to let the exponential follow camera settle before a capture.
## Same number and the same reason as LakeMoveCaptureProbe's.
const _SETTLE_FRAMES: int = 12

## The constraint set the tower site is SCANNED against. Thresholds, not
## positions: nothing here names a place, so re-running after the layout
## moves gives the answer for the layout as it then is.
const _TOWER_GROUND_MIN: float = 1.30
const _TOWER_HOTSPOT_MIN: float = 1.00
const _TOWER_STREAM_MIN: float = 2.00
## How far inside the rendered frame a thing has to project to count as
## "the player sees it", in pixels.
const _FRAME_MARGIN_PX: float = 40.0

## The constraint set an ARRIVAL is scanned against.
const _ARRIVAL_GROUND_MIN: float = 1.20
const _ARRIVAL_HOTSPOT_MIN: float = 1.00
const _ARRIVAL_CORRIDOR_MIN: float = 0.80
const _ARRIVAL_MIN_RUN: float = 12.0
## The band a run has to fall in to READ as a zipline rather than as a wire
## on the horizon. Not a taste: see the FRAMING note in PHASE C.
const _READABLE_MIN_RUN: float = 14.0
const _READABLE_MAX_RUN: float = 22.0
const _ARRIVAL_MAX_RUN: float = 42.0

## Provisional structure heights, for the corridor test and the renders
## ONLY. Nothing downstream reads them; a shipped tower would publish its
## own deck height the way every other prop on this plateau publishes its.
const _DECK_Y: float = 5.50
const _ARRIVAL_Y: float = 0.90
## How much room a body hanging under the cable needs below the line.
const _RIDER_DROP: float = 1.10

## ⚠️ A VOLUME THINNER THAN THIS IS A SURFACE, NOT AN OBSTACLE, and this
## line is a DEFECT OF THIS PROBE THAT THE MEASUREMENT FOUND -- published
## rather than quietly patched.
##
## The first water-allowed pass reported the south run BLOCKED at -10.530 u.
## The blocker was `@MeshInstance3D@111 @ (15.50, -19.00)`, top 0.01 -- the
## GREAT LAKE'S OWN WATER SLAB, a 20-unit disc one centimetre thick lying
## flat on the ground. The rider passes over it at y = 0.00 at the very end
## of the descent, so the height band test said "inside" and the horizontal
## gap said "10 metres deep inside a 10-metre disc". Both were right; the
## question was wrong. A cable cannot be obstructed by a floor.
##
## The quick screen did NOT catch it (it reported +10.901 for the same run),
## which is the useful half: the two tests disagreeing by 21 units is what
## made the defect visible at all instead of it silently rejecting every
## arrival over water.
const _OBSTACLE_MIN_HEIGHT: float = 0.20

var _hub: Node = null
var _world: Node3D = null
var _props: HubBuilder = null
var _keepy: Node3D = null
var _camera: Camera3D = null
var _viewport: SubViewport = null
var _rig: Node3D = null
## name -> [world AABB, ...] for every drawn thing, measured in PHASE A.
## Chosen by PHASE B and PHASE C respectively, from the scans -- never
## written down here.
var _tower: Vector3 = Vector3.ZERO
var _routes: Array = []
var _silhouettes: Array = []
var _frames: int = 0


func _ready() -> void:
	ProbeWatchdog.arm(self, _LABEL)
	print("=== ZIPLINE RECON (badger + Keepy) ===")
	DirAccess.make_dir_recursive_absolute(_OUT_DIR)

	_hub = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(_hub)
	await get_tree().process_frame
	await get_tree().process_frame

	_world = _hub.find_child("World", true, false) as Node3D
	_props = _hub.find_child("Props", true, false) as HubBuilder
	_keepy = _hub.find_child("Keepy", true, false) as Node3D
	_camera = _hub.find_child("Camera3D", true, false) as Camera3D
	_viewport = _hub.find_child("SubViewport", true, false) as SubViewport
	if _world == null or _props == null or _keepy == null or _camera == null or _viewport == null:
		push_error("%s: hub scene did not give up World / Props / Keepy / Camera3D / SubViewport." % _LABEL)
		get_tree().quit(1)
		return
	# ⚠️ THE NON-DEGENERATE ASSERTION. Under the DUMMY driver this is 0x0
	# and every screen measurement below would pass by never running.
	if _viewport.size.x <= 0 or _viewport.size.y <= 0:
		push_error("%s: viewport is %dx%d -- running under the DUMMY driver. Use xvfb-run --rendering-driver opengl3."
			% [_LABEL, _viewport.size.x, _viewport.size.y])
		get_tree().quit(1)
		return
	print("    viewport %dx%d, camera fov %.1f KEEP_WIDTH, offset %s"
		% [_viewport.size.x, _viewport.size.y, _camera.fov, str(HubCamera.OFFSET)])

	# ⚠️ THE CONTAINER'S stretch IGNORES the SubViewport's authored size,
	# and this screen ships 1080x1920 while the stretched surface measures
	# 1920x1920. Every capture and every unproject_position below would be
	# taken at an aspect no phone ever renders. Turned off for the length of
	# the probe -- the same move LakeZoneReconProbe had to make to get a
	# landmark's real pixel height.
	var container := _hub.find_child("WorldViewport", true, false) as SubViewportContainer
	if container != null:
		container.stretch = false
		_viewport.size = Vector2i(1080, 1920)
		await get_tree().process_frame
		await get_tree().process_frame
	print("    captures taken at %dx%d (container stretch disabled for the probe)"
		% [_viewport.size.x, _viewport.size.y])

	_rig = Node3D.new()
	_rig.name = "ZiplineReconRig"
	_world.add_child(_rig)

	_phase_a_silhouettes()
	_phase_b_towers()
	_phase_c_routes()
	await _phase_d_captures()

	print("--- recon only: 0 assertion, 0 gate, nothing shipped ---")
	print("--- captures under %s ---" % ProjectSettings.globalize_path(_OUT_DIR))
	get_tree().quit(0)


# =====================================================================
# PHASE A -- what actually stands up off this plateau
# =====================================================================

func _phase_a_silhouettes() -> void:
	print("\n[PHASE A] SILHOUETTES -- measured world AABBs off the BUILT tree")
	_collect(_props)
	# Sorted tallest first: the corridor test only ever cares about the top
	# of the list, and a reader wants to see what it is up against.
	_silhouettes.sort_custom(func(a, b): return a["top"] > b["top"])
	print("    %d drawn volumes measured (MultiMesh batches included)" % _silhouettes.size())
	var families: Dictionary = {}
	for s in _silhouettes:
		var key: String = s["family"]
		if not families.has(key):
			families[key] = {"n": 0, "top": 0.0, "radius": 0.0}
		families[key]["n"] += 1
		families[key]["top"] = maxf(families[key]["top"], s["top"])
		families[key]["radius"] = maxf(families[key]["radius"], s["radius"])
	var keys: Array = families.keys()
	keys.sort_custom(func(a, b): return families[a]["top"] > families[b]["top"])
	print("    %-28s %5s %9s %9s" % ["family (node name prefix)", "n", "max top", "max r"])
	for k in keys:
		print("    %-28s %5d %9.3f %9.3f" % [k, families[k]["n"], families[k]["top"], families[k]["radius"]])


## Depth-first over the built props, taking the world-space AABB of every
## MeshInstance3D AND every MultiMeshInstance3D.
##
## ⚠️ MultiMeshInstance3D IS NOT a MeshInstance3D, and the whole decor of
## this plateau is batched. A walk that only looked for MeshInstance3D
## would report a plateau with no trees on it at all -- the same blind spot
## that once made two node counters disagree, 124 against 123.
func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			_record(_family_of(mi), mi.get_aabb(), mi.global_transform)
	elif node is MultiMeshInstance3D:
		var mm: MultiMeshInstance3D = node
		if mm.multimesh != null and mm.multimesh.mesh != null:
			var local: AABB = mm.multimesh.mesh.get_aabb()
			# ⚠️ PER INSTANCE, not the batch's custom_aabb. The batch AABB is
			# one box around the whole plateau: testing a cable against it
			# would report every route blocked by everything.
			for i in mm.multimesh.instance_count:
				var xf: Transform3D = mm.global_transform * mm.multimesh.get_instance_transform(i)
				_record(mm.name, local, xf)
	for child in node.get_children():
		_collect(child)


## A readable name for whatever this volume belongs to.
##
## ⚠️ THE NODE'S OWN NAME IS USELESS FOR HALF THE PLATEAU. HubBuilder names
## its batches after the (mesh, colour) key and its models ("Owl", "Cabin",
## "Turnstile"), but every landmark and portal sub-mesh is built with no
## name at all and comes back as `@MeshInstance3D@60`. So the label is
## taken from the highest ancestor that is still under Props and still has
## an authored name, and the volume's own centre is reported alongside it
## -- a coordinate identifies a prop against the layout when a name cannot.
func _family_of(node: Node) -> String:
	var here: Node = node
	var best: String = node.name
	while here != null and here != _props:
		if not String(here.name).begins_with("@"):
			best = String(here.name)
		here = here.get_parent()
	return best


func _record(who: String, local: AABB, xf: Transform3D) -> void:
	var world: AABB = xf * local
	var centre: Vector3 = world.get_center()
	_silhouettes.append({
		"family": who,
		"centre": Vector3(centre.x, 0.0, centre.z),
		"radius": maxf(world.size.x, world.size.z) * 0.5,
		"bottom": world.position.y,
		"top": world.position.y + world.size.y,
	})


# =====================================================================
# PHASE B -- where the badger can stand, and whether he is on screen
# =====================================================================

func _phase_b_towers() -> void:
	print("\n[PHASE B] TOWER SITE -- SCANNED, not picked")
	print("    constraint set: in the region, in FRAME at spawn (base AND deck top),")
	print("    >= %.2f u clear of every ground footprint, >= %.2f u clear of every existing" % [_TOWER_GROUND_MIN, _TOWER_HOTSPOT_MIN])
	print("    tap/trigger disc, >= %.2f u off the stream ribbon." % _TOWER_STREAM_MIN)
	# Keepy AT SPAWN and the camera AT its rest pose: the frame test is
	# about the first thing the player sees, so it is taken from the pose
	# the screen actually opens in rather than from wherever the last
	# capture left the follow camera.
	_keepy.global_position = Vector3.ZERO
	_camera.global_position = HubCamera.OFFSET
	var found: Array = []
	var x: float = -14.0
	while x <= 14.0:
		var z: float = -6.0
		while z <= 12.0:
			var here := Vector3(x, 0.0, z)
			z += 0.25
			if not HubRegion.contains(here):
				continue
			if not _in_frame(here, 0.0) or not _in_frame(here, _DECK_Y):
				continue
			var ground: Array = _nearest_footprint(here)
			if ground[0] < _TOWER_GROUND_MIN:
				continue
			var hot: Array = _nearest_hotspot(here)
			if hot[0] < _TOWER_HOTSPOT_MIN:
				continue
			var stream: float = _stream_distance(here)
			if stream < _TOWER_STREAM_MIN:
				continue
			found.append([minf(ground[0], hot[0]), here, ground, hot, stream])
		x += 0.25
	found.sort_custom(func(a, b): return a[0] > b[0])
	print("    %d sites satisfy all five constraints" % found.size())
	if found.is_empty():
		push_error("%s: no tower site at all -- the frame at spawn is narrower than the lawn is crowded." % _LABEL)
		return
	for i in mini(found.size(), 6):
		var row: Array = found[i]
		var at: Vector3 = row[1]
		print("      %d. (%6.2f, %6.2f)  ground %+6.3f (%s)  hotspot %+6.3f (%s)  stream %+6.3f"
			% [i + 1, at.x, at.z, row[2][0], row[2][1], row[3][0], row[3][1], row[4]])
	_tower = found[0][1]
	var base: Vector2 = _camera.unproject_position(_tower)
	var deck: Vector2 = _camera.unproject_position(_tower + Vector3.UP * _DECK_Y)
	print("    CHOSEN: (%.2f, %.2f)  -- at spawn its base sits at screen (%.0f, %.0f) and its deck at (%.0f, %.0f) of %dx%d"
		% [_tower.x, _tower.z, base.x, base.y, deck.x, deck.y, _viewport.size.x, _viewport.size.y])


## True when `where` + `lift` projects inside the rendered frame.
##
## ⚠️ THE FRAME IS NARROW, and that is the constraint that decides this
## whole placement rather than a detail of it. fov 45 is KEEP_WIDTH on a
## 1080x1920 surface, so the HORIZONTAL half-angle is 22.5 degrees and the
## visible half-width at the spawn's own camera distance is a few units --
## measured here rather than reasoned about, because reasoning about it is
## how a badger ends up standing just off the edge of the opening shot.
func _in_frame(where: Vector3, lift: float) -> bool:
	var at: Vector3 = where + Vector3.UP * lift
	if not _camera.is_position_in_frustum(at):
		return false
	var p: Vector2 = _camera.unproject_position(at)
	return p.x >= _FRAME_MARGIN_PX and p.x <= float(_viewport.size.x) - _FRAME_MARGIN_PX \
		and p.y >= _FRAME_MARGIN_PX and p.y <= float(_viewport.size.y) - _FRAME_MARGIN_PX


## Distance from `where` to the stream ribbon the boat rides, measured on
## the spine HubBuilder actually built -- never on the layout's 12 control
## points, which the drawn curve bulges outside of.
func _stream_distance(where: Vector3) -> float:
	var spine: Array = _props.stream_spine()
	if spine.size() < 2:
		return INF
	var best: float = INF
	for i in spine.size() - 1:
		var a: Vector3 = spine[i]
		var b: Vector3 = spine[i + 1]
		var span := Vector2(b.x - a.x, b.z - a.z)
		var len2: float = span.length_squared()
		var t: float = 0.0
		if len2 > 0.000001:
			t = clampf(Vector2(where.x - a.x, where.z - a.z).dot(span) / len2, 0.0, 1.0)
		var on := Vector2(a.x, a.z) + span * t
		best = minf(best, Vector2(where.x - on.x, where.z - on.y).length())
	return best


# =====================================================================
# PHASE C -- the three runs
# =====================================================================

func _phase_c_routes() -> void:
	print("\n[PHASE C] ARRIVAL -- SCANNED from the chosen tower")
	print("    constraint set: in the region, >= %.2f u clear of every footprint," % _ARRIVAL_GROUND_MIN)
	print("    >= %.2f u clear of every tap/trigger disc, run %.0f..%.0f u, and a cable corridor" % [_ARRIVAL_HOTSPOT_MIN, _ARRIVAL_MIN_RUN, _ARRIVAL_MAX_RUN])
	print("    of at least %.2f u measured against the PHASE A silhouettes." % _ARRIVAL_CORRIDOR_MIN)
	var hits: Array = []
	var x: float = -HubRegion.PLATEAU_HALF_EXTENT
	while x <= HubRegion.PLATEAU_HALF_EXTENT:
		var z: float = -HubRegion.PLATEAU_HALF_EXTENT
		while z <= HubRegion.PLATEAU_HALF_EXTENT:
			var here := Vector3(x, 0.0, z)
			z += 0.5
			var run: float = Vector2(here.x - _tower.x, here.z - _tower.z).length()
			if run < _ARRIVAL_MIN_RUN or run > _ARRIVAL_MAX_RUN:
				continue
			if not HubRegion.contains(here):
				continue
			# ⚠️ WATER IS NOT A REJECTION ON THIS PLATEAU, and that is
			# Mathieu's own standing decision -- HubRegion no longer
			# subtracts a single water body and the boat already floats on
			# two of them. It is TAGGED instead, because a zipline that
			# ends on a pontoon over the great lake and one that ends on
			# open lawn are different products, not one with a bug.
			var wet: Array = _water_at(here)
			var ground: Array = _nearest_footprint(here)
			if ground[0] < _ARRIVAL_GROUND_MIN:
				continue
			var hot: Array = _nearest_hotspot(here)
			if hot[0] < _ARRIVAL_HOTSPOT_MIN:
				continue
			# CHEAP corridor first -- one closest-approach per silhouette
			# instead of a hundred samples. It is a SCREEN, not the answer:
			# the three that survive are re-measured with the sampled test
			# below, which is the number reported.
			var quick: float = _corridor_quick(_tower, here)
			if quick < _ARRIVAL_CORRIDOR_MIN:
				continue
			hits.append([here, run, ground, hot, quick, wet])
		x += 0.5
	print("    %d arrivals satisfy all six constraints" % hits.size())
	if hits.is_empty():
		push_error("%s: no arrival at all under this constraint set." % _LABEL)
		return
	# Best per 20-degree bearing, so the report is a FAN and not twenty
	# neighbours of one point.
	var buckets: Dictionary = {}
	for hit in hits:
		var here: Vector3 = hit[0]
		var bearing: float = rad_to_deg(atan2(here.x - _tower.x, here.z - _tower.z))
		var key: int = int(floor(bearing / 20.0))
		if not buckets.has(key) or hit[1] > buckets[key][1]:
			buckets[key] = hit
	var keys: Array = buckets.keys()
	keys.sort()
	print("    %-9s %-18s %8s %9s %9s %9s  %s" % ["bearing", "arrival", "run", "ground", "hotspot", "corridor", "surface"])
	for key in keys:
		var hit: Array = buckets[key]
		var here: Vector3 = hit[0]
		print("    %5d deg (%6.2f, %6.2f) %8.2f %9.3f %9.3f %9.3f  %s"
			% [key * 20, here.x, here.z, hit[1], hit[2][0], hit[3][0], hit[4], hit[5][1]])
	# ⚠️ THE FAN ABOVE IS NOT THE ANSWER, AND THE RENDERS ARE WHY.
	#
	# The first pass of this probe took the three LONGEST clean runs (33 to
	# 42 u) and photographed them. Every one came back as a near-horizontal
	# wire lying across the top of the frame: at 3.6 u of drop over 38 u the
	# slope is 5.37 degrees, the far end is past 45% fog occlusion
	# (1 - exp(-38 * 0.016), the density this scene ships), and the camera --
	# which NEVER yaws and shows about 22.5 degrees of half-width -- cannot
	# hold both ends at once anyway. A run that cannot be SEEN descending is
	# not a zipline, whatever the geometry says.
	#
	# So the finalists are drawn from a READABLE band instead, and the band
	# is stated as a constant rather than left in a comment. Best corridor
	# per bearing third, over runs heading into the visible field (-Z).
	var readable: Array = []
	for hit in hits:
		var here: Vector3 = hit[0]
		if hit[1] < _READABLE_MIN_RUN or hit[1] > _READABLE_MAX_RUN:
			continue
		var bearing: float = rad_to_deg(atan2(here.x - _tower.x, here.z - _tower.z))
		if absf(bearing) < 90.0:
			# +Z: behind the camera for the whole ride.
			continue
		readable.append([hit, bearing])
	print("\n    %d of those fall in the READABLE band (run %.0f..%.0f u, heading -Z)"
		% [readable.size(), _READABLE_MIN_RUN, _READABLE_MAX_RUN])
	var thirds: Dictionary = {}
	for row in readable:
		var bearing: float = row[1]
		# -180..-90 west, 90..135 east-near, 135..180 south
		var key: String = "W"
		if bearing >= 90.0 and bearing < 135.0:
			key = "E"
		elif bearing >= 135.0 or bearing <= -160.0:
			key = "S"
		if not thirds.has(key) or row[0][4] > thirds[key][0][4]:
			thirds[key] = row
	var names: Dictionary = {"E": "A_east", "S": "B_south", "W": "C_west"}
	print("\n    === THE THREE FINALISTS, best corridor per bearing third, SAMPLED test ===")
	for key in ["E", "S", "W"]:
		if not thirds.has(key):
			print("    %s -- no readable arrival in this third at all" % key)
			continue
		var hit: Array = thirds[key][0]
		_routes.append([names[key], _tower, hit[0]])
		_report_route(names[key], _tower, hit[0], hit)


func _report_route(name: String, from: Vector3, to: Vector3, hit: Array) -> void:
	var run: float = Vector2(to.x - from.x, to.z - from.z).length()
	var drop: float = _DECK_Y - _ARRIVAL_Y
	var slope: float = rad_to_deg(atan2(drop, run))
	var corridor: Dictionary = _cable_clearance(from, to)
	# The shortcut floor, the boat's own rule: a ride that loses to a hop
	# chain is a slower way to travel that merely looks nicer. Quantized,
	# because a hop chain is -- a part hop still costs a whole one.
	var hops: int = int(ceil(run / KeepyHopper.HOP_DISTANCE))
	var hop_s: float = float(hops) * KeepyHopper.HOP_DURATION
	print("\n    --- %s ---" % name)
	print("      (%.2f, %.2f) -> (%.2f, %.2f)" % [from.x, from.z, to.x, to.z])
	print("      run %.3f u   drop %.3f u (deck %.2f -> arrival %.2f)   slope %.2f deg"
		% [run, drop, _DECK_Y, _ARRIVAL_Y, slope])
	print("      arrival: region=%s  %s  ground %+7.3f (%s)  hotspot %+7.3f (%s)"
		% [str(HubRegion.contains(to)), hit[5][1], hit[2][0], hit[2][1], hit[3][0], hit[3][1]])
	print("      corridor: quick %.3f  |  SAMPLED worst %+7.3f u at s=%.2f against %s @ (%.2f, %.2f) (top %.2f, rider y %.2f)"
		% [hit[4], corridor["gap"], corridor["s"], corridor["who"], corridor["at"].x,
			corridor["at"].z, corridor["top"], corridor["cable_y"]])
	print("      hop chain %d hops = %.4f s  |  ride 8 u/s = %.4f s   12 u/s = %.4f s   14 u/s = %.4f s"
		% [hops, hop_s, run / 8.0, run / 12.0, run / 14.0])
	print("      -> ride-speed FLOOR to beat the hop chain: %.4f u/s" % (run / hop_s))


## One closest-approach per silhouette instead of a sampled sweep. Used to
## SCREEN thousands of candidates; every candidate that survives is then
## re-measured by _cable_clearance(), and it is that number the report
## carries. Stated rather than hidden because the two can disagree: this
## one tests each volume only at the point on the run nearest its centre.
func _corridor_quick(from: Vector3, to: Vector3) -> float:
	var span := Vector2(to.x - from.x, to.z - from.z)
	var len2: float = span.length_squared()
	if len2 < 0.000001:
		return -INF
	var worst: float = INF
	for s in _silhouettes:
		if s["top"] - s["bottom"] < _OBSTACLE_MIN_HEIGHT:
			continue
		var centre: Vector3 = s["centre"]
		var t: float = clampf(Vector2(centre.x - from.x, centre.z - from.z).dot(span) / len2, 0.0, 1.0)
		var y: float = lerpf(_DECK_Y, _ARRIVAL_Y, t) - _RIDER_DROP
		if s["bottom"] > y or s["top"] < y:
			continue
		var on := Vector2(from.x, from.z) + span * t
		var gap: float = Vector2(centre.x - on.x, centre.z - on.y).length() - float(s["radius"])
		if gap < worst:
			worst = gap
	return worst


## Worst horizontal gap between the cable (plus the room a hanging body
## needs under it) and anything that reaches up into it.
##
## Sampled every 0.25 u of run: the narrowest thing on this plateau is a
## flower stem, and a step coarser than its own diameter can walk straight
## through one.
func _cable_clearance(from: Vector3, to: Vector3) -> Dictionary:
	var run: float = Vector2(to.x - from.x, to.z - from.z).length()
	var steps: int = maxi(int(run / 0.25), 8)
	var worst: float = INF
	var out: Dictionary = {"gap": INF, "s": 0.0, "who": "-", "top": 0.0, "cable_y": 0.0,
		"at": Vector3.ZERO}
	for k in steps + 1:
		var t: float = float(k) / float(steps)
		var here: Vector3 = from.lerp(to, t)
		# The lowest part of the moving pair, not the cable itself: what
		# has to clear the scenery is the rider, and he hangs below it.
		var y: float = lerpf(_DECK_Y, _ARRIVAL_Y, t) - _RIDER_DROP
		for s in _silhouettes:
			if s["top"] - s["bottom"] < _OBSTACLE_MIN_HEIGHT:
				continue
			if s["bottom"] > y:
				continue
			if s["top"] < y:
				continue
			var gap: float = Vector2(here.x - s["centre"].x, here.z - s["centre"].z).length() - s["radius"]
			if gap < worst:
				worst = gap
				out = {"gap": gap, "s": t * run, "who": s["family"], "top": s["top"],
					"cable_y": y, "at": s["centre"]}
	return out


func _nearest_footprint(where: Vector3) -> Array:
	var best: float = INF
	var who: String = "-"
	for foot in _props.ground_footprints():
		var d: float = Vector2(where.x - foot["position"].x, where.z - foot["position"].z).length() \
			- float(foot["radius"])
		if d < best:
			best = d
			who = "r=%.2f @ (%.2f, %.2f)" % [foot["radius"], foot["position"].x, foot["position"].z]
	return [best, who]


## Every disc on this plateau that already MEANS something when a body is
## inside it. A zipline that put a rider down inside one would hand the
## next tap to a prop the player was not aiming at.
func _nearest_hotspot(where: Vector3) -> Array:
	var discs: Array = []
	for owl in _props.owls():
		discs.append([owl["position"], HubWorld.OWL_TAP_RADIUS, "owl tap"])
	for cabin in _props.cabins():
		discs.append([cabin["door"], HubWorld.CABIN_TAP_RADIUS, "cabin doorstep"])
	for spin in _props.spinning_props():
		discs.append([spin["position"], float(spin["radius"]), "turnstile trigger"])
	for saw in _props.seesaws():
		discs.append([saw["position"], float(saw["radius"]), "seesaw trigger"])
	for board in _props.diving_boards():
		# "ladder", NOT "position": this registry publishes the FOOT ON LAND,
		# which is the point the tap radius is measured from. The layout's
		# own "position" is a different fact and is not in this table.
		discs.append([board["ladder"], HubWorld.LADDER_TAP_RADIUS, "ladder tap"])
	for portal in _props.portals():
		discs.append([portal.global_position, 1.35, "portal"])
	var spine: Array = _props.stream_spine()
	if spine.size() >= 2:
		discs.append([spine[0], BoatMooring.BOARD_TAP_RADIUS, "boat tap (head)"])
		discs.append([spine[spine.size() - 1], BoatMooring.BOARD_TAP_RADIUS, "boat tap (tail)"])
	var best: float = INF
	var who: String = "-"
	for disc in discs:
		var at: Vector3 = disc[0]
		var d: float = Vector2(where.x - at.x, where.z - at.z).length() - float(disc[1])
		if d < best:
			best = d
			who = disc[2]
	return [best, who]


## Which water body, if any, `where` is standing in. Water is walkable on
## this plateau, so this is a description and never a refusal.
func _water_at(where: Vector3) -> Array:
	var flat := Vector3(where.x, 0.0, where.z)
	# ⚠️ in_lake_water(), NOT lake_index_at(). The second matches a lake
	# CENTRE to within a millimetre -- it answers "which row of the table
	# is this", not "is this point wet" -- and reading containment off it
	# would report every candidate dry. Two homonymous-looking queries, one
	# of them the wrong one, is exactly the LAKE_WATER_RADIUS trap this
	# repo already has written down.
	if HubRegion.in_lake_water(flat):
		return [true, "IN a great lake"]
	var pond: Vector3 = _props.pond_centre()
	if flat.distance_to(Vector3(pond.x, 0.0, pond.z)) <= HubBuilder.POND_BANK_RADIUS:
		return [true, "IN the pond"]
	var lake: Vector3 = _props.small_lake_centre()
	if flat.distance_to(Vector3(lake.x, 0.0, lake.z)) <= HubBuilder.LAKE_BANK_RADIUS:
		return [true, "IN the small lake"]
	for islet in _props.islets():
		# "centre", NOT "position": this registry is published as-BUILT and
		# names its key differently from the layout's own entries.
		var at: Vector3 = islet["centre"]
		if flat.distance_to(Vector3(at.x, 0.0, at.z)) <= float(islet["radius"]):
			return [true, "ON an islet"]
	return [false, "dry ground"]


# =====================================================================
# PHASE D -- the renders the choice is actually made on
# =====================================================================

func _phase_d_captures() -> void:
	print("\n[PHASE D] CAPTURES")
	for entry in _routes:
		await _shoot(entry[0], entry[1], entry[2])
	# One frame with all three cables up at once, from the one plateau
	# position that has the whole fan in front of it.
	_clear_rig()
	for entry in _routes:
		_draw_run(entry[1], entry[2], Color(1.0, 0.62, 0.12))
	var fan_view: Vector3 = HubRegion.clamp_to(Vector3(_tower.x, 0.0, _tower.z + 6.0))
	await _capture("ALL_three_runs", fan_view)
	print("    ALL_three_runs        from (%.2f, %.2f)" % [fan_view.x, fan_view.z])


func _shoot(name: String, from: Vector3, to: Vector3) -> void:
	_clear_rig()
	_draw_run(from, to, Color(1.0, 0.62, 0.12))
	# Stand far enough back along +Z that both ends are north of the
	# camera: it never yaws, so the only way to frame a run is to be
	# behind all of it.
	var view := Vector3(from.x * 0.5 + to.x * 0.5, 0.0, maxf(from.z, to.z) + 4.0)
	view = HubRegion.clamp_to(view)
	await _capture(name + "__run", view)
	await _capture(name + "__arrival", Vector3(to.x, 0.0, to.z + 8.0))
	print("    %-18s  run shot from (%.2f, %.2f), arrival shot from (%.2f, %.2f)"
		% [name, view.x, view.z, to.x, to.z + 8.0])


func _clear_rig() -> void:
	for child in _rig.get_children():
		child.queue_free()
		_rig.remove_child(child)


## Tower, cable and arrival post, as the simplest honest stand-in: this is
## a corridor being photographed, not a prop being designed.
func _draw_run(from: Vector3, to: Vector3, tint: Color) -> void:
	_post(Vector3(from.x, _DECK_Y * 0.5, from.z), _DECK_Y, 0.16, Color(0.42, 0.29, 0.17))
	_post(Vector3(to.x, _ARRIVAL_Y * 0.5, to.z), _ARRIVAL_Y, 0.14, Color(0.42, 0.29, 0.17))
	var a := Vector3(from.x, _DECK_Y, from.z)
	var b := Vector3(to.x, _ARRIVAL_Y, to.z)
	var span: Vector3 = b - a
	var cable := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.05
	mesh.height = span.length()
	mesh.radial_segments = 6
	mesh.rings = 0
	cable.mesh = mesh
	cable.material_override = _unshaded(tint)
	_rig.add_child(cable)
	cable.global_position = a + span * 0.5
	# A cylinder's own axis is +Y, so the cable is turned onto the span
	# rather than the span being assumed horizontal.
	var up: Vector3 = span.normalized()
	var side: Vector3 = up.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	cable.global_transform.basis = Basis(side, up, side.cross(up).normalized())


func _post(centre: Vector3, height: float, radius: float, tint: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 0
	node.mesh = mesh
	node.material_override = _unshaded(tint)
	_rig.add_child(node)
	node.global_position = centre


## Unshaded, because this plateau has no lights at all: only an unshaded
## surface has a known colour here, and a lit stand-in would photograph
## black.
func _unshaded(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	return mat


func _capture(tag: String, keepy_at: Vector3) -> void:
	_keepy.global_position = keepy_at
	_frames = 0
	while _frames < _SETTLE_FRAMES:
		await get_tree().process_frame
		_frames += 1
	var image: Image = _viewport.get_texture().get_image()
	image.save_png("%s/%s.png" % [_OUT_DIR, tag])
