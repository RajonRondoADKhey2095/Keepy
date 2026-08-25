extends Node
## Dev-only: MEASUREMENT ONLY, gates nothing, for the "lake zone beyond
## the plateau" recon (26 aout 2026). Companion to the reasoning written
## up in the recon report, not a substitute for it -- this file exists so
## the two headline numbers (crossing time past 35, landmark screen size
## past 35) are pulled from the REAL KeepyHopper/HubCamera in HubWorld.tscn
## rather than from a re-implementation that could quietly drift from
## them, the same trap StreamGeometryProbe already paid for once on this
## screen (SubstituteModel.tscn).
##
## Two phases, two different reasons to trust the number:
##   PHASE HOPS    drives the SHIPPED KeepyHopper.hop_to() with real
##                 --fixed-fps 60 frames, exactly the technique
##                 KeepyHopper.gd's own docblock used to derive the 35
##                 rows it already publishes. Runs fine under --headless:
##                 nothing here reads a pixel.
##   PHASE SCREEN  reads camera.unproject_position() from the SHIPPED
##                 HubCamera node for landmark heights at r=40 and r=45,
##                 the same pure-transform technique already used for the
##                 letterbox and framing recons on this exact camera --
##                 also --headless-safe.
##   PHASE CAPTURE builds ONE real spire (HubBuilder._make_landmark_spire(),
##                 not a stand-in) at r=40, renders it through the shipped
##                 fog/palette and saves a PNG. Needs a real GPU driver --
##                 --headless forces the DUMMY driver, which cannot render
##                 a pixel, the same trap already paid for on this screen's
##                 own StreamRideProbe/DecorStabilityAudit. Run under xvfb:
##
##   xvfb-run --rendering-driver opengl3 godot4 --fixed-fps 60 --path . \
##     res://scripts/dev/LakeZoneReconProbe.tscn
##
## KeepyHopper.hop_to() takes any Vector3 -- it has NO notion of
## PLATEAU_HALF_EXTENT, only HubTapInput enforces that clamp. So a
## hypothetical square wider than today's, or a peninsula tip beyond it,
## can be hopped to directly without touching a single game file: this
## probe never edits HubTapInput.PLATEAU_HALF_EXTENT, hub_layout.tres, or
## any scene.
##
##   godot4 --headless --path . res://scripts/dev/LakeZoneReconProbe.tscn

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"

func _ready() -> void:
	ProbeWatchdog.arm(self, "LAKE ZONE RECON PROBE")

	print("=== LAKE ZONE RECON PROBE (measurement only, gates nothing) ===")
	print("")

	var hub: Node = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var keepy: KeepyHopper = hub.get_node("WorldViewport/SubViewport/World/Keepy")
	var camera: Camera3D = hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	var viewport: SubViewport = hub.get_node("WorldViewport/SubViewport")
	var builder: HubBuilder = hub.get_node("WorldViewport/SubViewport/World/Props")

	# PHASE HOPS/SCREEN drive thousands of scene-tree frames each and read
	# no pixel, so they belong under --headless (the DUMMY driver races
	# through them). PHASE CAPTURE needs the opposite: a real renderer, so
	# it belongs under xvfb+opengl3, where thousands of software-rendered
	# frames would be minutes each rather than milliseconds. Splitting on
	# the actual driver in use, rather than running everything everywhere,
	# is what keeps either invocation from paying for the other's needs.
	var driver: String = DisplayServer.get_name()
	if driver == "headless":
		await _phase_hops(keepy)
		await _phase_screen(camera, viewport, keepy)
	else:
		await _phase_capture(hub, builder, keepy, camera, viewport)

	hub.queue_free()
	print("")
	print("=== END LAKE ZONE RECON PROBE ===")
	get_tree().quit(0)

## ---------------------------------------------------------------------
## PHASE HOPS -- crossing time for trips beyond the shipped 35 extent,
## driven on the real KeepyHopper. Every trip first resets Keepy to the
## start point directly (global_position, no travel cost for the reset
## itself) so each measurement starts clean.
func _phase_hops(keepy: KeepyHopper) -> void:
	print("--- PHASE HOPS: real KeepyHopper, --fixed-fps 60 ---")

	# Sanity row first: reproduce the published 35-extent diagonal
	# (66 hops, 1122 frames, 18.700s) before trusting anything new.
	await _measure_trip(keepy, "sanity: (-35,-35)->(35,35), published 66 hops/18.700s",
		Vector3(-35, 0, -35), Vector3(35, 0, 35))

	# Q2a: max square half-extent under 22s -- python model says H=40 is
	# the last one under, H=41 crosses it (21.533s vs 22.100s).
	await _measure_trip(keepy, "square H=40 diagonal", Vector3(-40, 0, -40), Vector3(40, 0, 40))
	await _measure_trip(keepy, "square H=41 diagonal", Vector3(-41, 0, -41), Vector3(41, 0, 41))

	# Q2b: peninsula at azimuth 282 deg (the lot F lake's own azimuth),
	# beyond the shipped 35 extent, worst trip = opposite corner (35,35)
	# to the peninsula tip.
	var az: float = deg_to_rad(282.0)
	var dir := Vector3(sin(az), 0.0, -cos(az))
	for l in [5.0, 10.0, 15.0]:
		var tip: Vector3 = dir * (35.0 + l)
		await _measure_trip(keepy, "peninsula L=%.0f: (35,35)->tip%s" % [l, tip],
			Vector3(35, 0, 35), tip)

func _measure_trip(keepy: KeepyHopper, label: String, start: Vector3, target: Vector3) -> void:
	keepy.global_position = start
	# Force IDLE so the trip is not silently swallowed by a stale target
	# from a previous measurement (hop_to() only auto-advances from IDLE).
	await get_tree().process_frame

	var hops: int = 0
	var frames: int = 0
	var done: bool = false
	# Members, not locals -- a GDScript lambda captures a local by VALUE,
	# already paid for once on this exact probe family (StreamRideProbe's
	# own header, re-learned the hard way there). Using a Callable that
	# writes to the OUTER local via closure-by-reference works for a
	# single-shot bool/int increment in Godot 4's lambdas (they close over
	# the variable, not a snapshot), but there is no reason to re-risk it:
	# route through the probe's own fields instead.
	_hop_count = 0
	_hop_done = false
	keepy.hop_landed.connect(_on_hop_landed)
	keepy.became_idle.connect(_on_hop_idle)

	keepy.hop_to(target)
	# 5000 frames is ~83s of simulated hopping at 60fps -- far beyond any
	# trip this probe asks for (the longest is ~70 hops) -- so this is a
	# safety cap against a logic error, not a real budget; the top-level
	# ProbeWatchdog.arm() call already covers "the whole probe never
	# finishes".
	while not _hop_done and frames < 5000:
		await get_tree().process_frame
		frames += 1

	keepy.hop_landed.disconnect(_on_hop_landed)
	keepy.became_idle.disconnect(_on_hop_idle)
	hops = _hop_count

	var dist: float = start.distance_to(target)
	var t: float = float(frames) / 60.0
	print("  %s" % label)
	print("    dist=%.4f  hops=%d  frames=%d  time=%.4fs%s" %
		[dist, hops, frames, t, "" if _hop_done else "  ** DID NOT FINISH (frame cap hit) **"])

var _hop_count: int = 0
var _hop_done: bool = false

func _on_hop_landed(_pos: Vector3) -> void:
	_hop_count += 1

func _on_hop_idle() -> void:
	_hop_done = true

## ---------------------------------------------------------------------
## PHASE SCREEN -- landmark screen height at r=40 and r=45, read from the
## SHIPPED HubCamera via unproject_position(). Pure transform math, no
## pixel read, so --headless is safe here (the opposite rule from a
## capture that reads colour).
##
## Heights are the three landmark variants' own published tops (measured
## on the shipped _make_landmark_* constructors: 8.45 / 8.40 / 8.06), and
## "seen from the centre" means Keepy at the origin with the landmark due
## north (azimuth 0) -- the exact convention the shipped ring recons
## (lot B/C/D) already used, reproduced here as a sanity check first.
func _phase_screen(camera: Camera3D, viewport: SubViewport, keepy: KeepyHopper) -> void:
	print("")
	print("--- PHASE SCREEN: real HubCamera.unproject_position() ---")
	# PHASE HOPS left Keepy wherever its last trip ended (near the L=15
	# peninsula tip), and HubCamera's own _process chases him with an
	# exponential lerp -- both of which would put the camera nowhere near
	# "seen from the centre" if left alone. Snap Keepy back to the origin
	# and write the camera's exact resting position directly (OFFSET is a
	# const, not a per-frame read) rather than waiting out the lerp: this
	# measurement wants the camera's converged position, not an
	# approximation of it.
	keepy.global_position = Vector3.ZERO
	camera.global_position = Vector3.ZERO + HubCamera.OFFSET
	# The SubViewportContainer forces its child SubViewport's size to match
	# its own rect while stretch=true (that's what makes the game resize
	# with the browser window) -- resizing the viewport directly is
	# rejected with a warning until stretch is turned off, the same fix
	# already used on this exact camera for the letterbox/framing recons.
	var container: SubViewportContainer = viewport.get_parent() as SubViewportContainer
	var had_stretch: bool = container.stretch
	container.stretch = false
	var heights: Dictionary = {"spire": 8.45, "cairn": 8.40, "slabs": 8.06}
	var sizes: Array = [Vector2i(1080, 1920), Vector2i(1170, 2532)]

	for r in [12.6, 21.4, 30.5, 40.0, 45.0]:
		print("  r=%.1f" % r)
		for size in sizes:
			viewport.size = size
			await get_tree().process_frame
			var base := Vector3(0.0, 0.0, -r)
			var base_px: Vector2 = camera.unproject_position(base)
			for variant in heights.keys():
				var h: float = heights[variant]
				var top := Vector3(0.0, h, -r)
				var top_px: Vector2 = camera.unproject_position(top)
				var px_height: float = base_px.y - top_px.y
				print("    %dx%d %s: base_px=%s top_px=%s height=%.1fpx" %
					[size.x, size.y, variant, base_px, top_px, px_height])
	container.stretch = had_stretch

## ---------------------------------------------------------------------
## PHASE CAPTURE -- one real spire built by the shipped
## HubBuilder._make_landmark_spire(), placed at r=40, rendered through
## the real fog/palette and saved as PNG for visual confirmation. Never
## a stand-in mesh: the whole point of measuring here instead of on paper
## is that the fog/perspective interaction already fooled a hand-derived
## formula once in this same recon (see the report) -- a stand-in could
## make the same mistake a second time and look fine doing it.
##
## No-ops safely under --headless (DUMMY driver: get_image() returns a
## black frame, saved anyway with that fact printed) rather than failing
## the whole probe -- the pixel measurements above do not need a real
## renderer and should not be held hostage to one being available.
func _phase_capture(hub: Node, builder: HubBuilder, keepy: KeepyHopper, camera: Camera3D, viewport: SubViewport) -> void:
	print("")
	print("--- PHASE CAPTURE: one real spire at r=40, rendered ---")
	var driver: String = DisplayServer.get_name()
	print("  DisplayServer driver: %s%s" % [driver,
		"  (DUMMY -- capture will be a black frame, expected under --headless)" if driver == "headless" else ""])

	keepy.global_position = Vector3.ZERO
	camera.global_position = Vector3.ZERO + HubCamera.OFFSET

	var world: Node3D = hub.get_node("WorldViewport/SubViewport/World")
	var spire: Node3D = builder._make_landmark_spire()
	spire.position = Vector3(0.0, 0.0, -40.0)
	world.add_child(spire)

	# Let the SubViewport actually render: render_target_update_mode=4
	# (ONCE) on this node means a frame only renders when explicitly asked
	# for one, plus a few settle frames for the fog/environment to apply.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 6:
		await RenderingServer.frame_post_draw

	var image: Image = viewport.get_texture().get_image()
	# user:// is always writable regardless of where the project root
	# lives or whether it is read-only in this invocation; save_png()
	# accepts it directly.
	var out_path: String = "user://lake_recon_r40_capture.png"
	var err: int = image.save_png(out_path)
	print("  save_png(%s) -> %d  (globalized: %s)" %
		[out_path, err, ProjectSettings.globalize_path(out_path)])

	spire.queue_free()
