extends Node
## SPAWN-LAKE RECON, Q5 -- what the SHIPPED camera actually shows at spawn.
##
## Measurement only. Nothing in scripts/hub or resources/hub is touched:
## the candidate disc is built HERE, inside this probe, and added to an
## instantiated copy of the hub scene. The layout on disk never sees it.
##
## =====================================================================
## WHY is_position_in_frustum() AND NOT A HAND ROLLED BEARING CHECK
##
## HubCamera never yaws (fixed rotation, see its own docblock), so "is
## this point on screen" is exactly what Camera3D.is_position_in_frustum()
## already answers using the camera's REAL fov/aspect/near/far planes --
## the same test the renderer itself uses to cull, rather than a second,
## hand-derived trigonometric approximation that could disagree with it
## at the frame edge.
##
## =====================================================================
## HOW TO RUN -- under xvfb, NOT --headless
##
##   xvfb-run -a godot4 --rendering-driver opengl3 \
##     --path . res://scripts/dev/SpawnLakeCaptureProbe.tscn
##
## This one reads pixels, so --headless would force the DUMMY driver and
## every capture would come back empty. Frames are driven by a counter in
## _process rather than by awaiting RenderingServer.frame_post_draw, which
## under llvmpipe has run past ten minutes without producing anything.

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"
const _OUT_DIR: String = "user://spawn_lake_capture"
const _LABEL: String = "SpawnLakeCaptureProbe"
const _SETTLE_FRAMES: int = 12

const _CANDIDATE_CENTRE: Vector3 = Vector3(-12.00, 0.0, -19.50)
const _CANDIDATE_RADIUS: float = 10.0

## Grid resolution for the "fraction of the disc inside the frame" sample
## -- a plain area-weighted grid over the disc's bounding square, filtered
## to the circle. 41x41 gives 1281 interior samples, comfortably more than
## enough to resolve a percentage to the nearest point without the cost of
## a much finer grid.
const _GRID_N: int = 41

var _hub: Node = null
var _keepy: Node3D = null
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _disc: MeshInstance3D = null
var _frames: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, _LABEL)
	print("=== SPAWN-LAKE CAPTURE (Q5) ===")
	DirAccess.make_dir_recursive_absolute(_OUT_DIR)

	_hub = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(_hub)
	await get_tree().process_frame

	_keepy = _hub.find_child("Keepy", true, false) as Node3D
	_viewport = _hub.find_child("SubViewport", true, false) as SubViewport
	_camera = _hub.find_child("Camera3D", true, false) as Camera3D
	if _keepy == null or _viewport == null or _camera == null:
		push_error("%s: hub scene did not give up Keepy / SubViewport / Camera3D." % _LABEL)
		get_tree().quit(1)
		return
	print("    viewport %dx%d, camera fov %.1f keep_aspect=%d (0=KEEP_WIDTH), pitch fixed, NO YAW"
		% [_viewport.size.x, _viewport.size.y, _camera.fov, _camera.keep_aspect])

	_keepy.global_position = Vector3.ZERO
	_frames = 0
	while _frames < _SETTLE_FRAMES:
		await get_tree().process_frame
		_frames += 1

	# Shot 1: the arbre LIVRE, as it ships today, from spawn -- for
	# comparison. No candidate drawn at all.
	print("--- BEFORE: shipped plateau, no new disc, Keepy at spawn ---")
	var image_before: Image = _viewport.get_texture().get_image()
	image_before.save_png("%s/before_shipped_from_spawn.png" % _OUT_DIR)
	print("    saved before_shipped_from_spawn.png")
	_report_existing_greatlake_visibility()

	# Build one reusable disc for the candidate, coloured like the shipped
	# great lake so a viewer judges placement and not palette -- Q6's own
	# colour question is explicitly out of scope for this recon.
	_disc = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = HubBuilder.GREATLAKE_WATER_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc.material_override = material
	var cyl := CylinderMesh.new()
	cyl.top_radius = _CANDIDATE_RADIUS
	cyl.bottom_radius = _CANDIDATE_RADIUS
	cyl.height = 0.02
	cyl.radial_segments = 64
	cyl.rings = 0
	_disc.mesh = cyl
	_disc.position = Vector3(_CANDIDATE_CENTRE.x, 0.03, _CANDIDATE_CENTRE.z)
	_hub.find_child("World", true, false).add_child(_disc)

	_frames = 0
	while _frames < _SETTLE_FRAMES:
		await get_tree().process_frame
		_frames += 1

	print("--- AFTER: candidate r=%.1f @ (%.2f,%.2f) drawn, Keepy at spawn ---" % [
		_CANDIDATE_RADIUS, _CANDIDATE_CENTRE.x, _CANDIDATE_CENTRE.z])
	var image_after: Image = _viewport.get_texture().get_image()
	image_after.save_png("%s/after_candidate_from_spawn.png" % _OUT_DIR)
	print("    saved after_candidate_from_spawn.png")
	_report_disc_visibility(_CANDIDATE_CENTRE, _CANDIDATE_RADIUS, "candidate")

	print("--- captures written under %s ---" % ProjectSettings.globalize_path(_OUT_DIR))
	get_tree().quit(0)

## Samples the EXISTING great lake's disc (already shipped by LAKE-MOVE-1)
## for comparison -- Mathieu's plaint that opened LAKE-MOVE-RECON was that
## nothing was visible from spawn/centre; LAKE-MOVE-1 fixed that for the
## FIRST lake, and this line establishes what "already visible" looks like
## before judging whether a SECOND lake can add to it.
func _report_existing_greatlake_visibility() -> void:
	_report_disc_visibility(HubRegion.lake_centre(), HubRegion.LAKE_WATER_RADIUS, "existing great lake")

func _report_disc_visibility(centre: Vector3, radius: float, label: String) -> void:
	var total: int = 0
	var inside: int = 0
	var half: float = radius
	var step: float = (2.0 * half) / float(_GRID_N - 1)
	var x: float = centre.x - half
	while x <= centre.x + half + 0.0001:
		var z: float = centre.z - half
		while z <= centre.z + half + 0.0001:
			var dx: float = x - centre.x
			var dz: float = z - centre.z
			if dx * dx + dz * dz <= radius * radius:
				total += 1
				var p := Vector3(x, 0.03, z)
				if _camera.is_position_in_frustum(p):
					inside += 1
			z += step
		x += step
	var cam: Vector3 = _camera.global_position
	var bearing := rad_to_deg(atan2(centre.x - cam.x, -(centre.z - cam.z)))
	var dist := Vector2(centre.x - cam.x, centre.z - cam.z).length()
	var pct: float = 100.0 * float(inside) / float(maxi(total, 1))
	print("    %-24s centre=(%.2f,%.2f) r=%.1f  bearing=%+.1f deg  dist=%.2f  samples=%d  IN FRUSTUM=%d (%.1f%%)"
		% [label, centre.x, centre.z, radius, bearing, dist, total, inside, pct])
	if pct > 0.0:
		print("        VERDICT: %s occupies the frame from spawn (>0%% visible)." % label)
	else:
		print("        VERDICT: %s is NOT in frame from spawn (0%% visible)." % label)
