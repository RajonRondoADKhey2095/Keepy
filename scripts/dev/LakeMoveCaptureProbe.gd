extends Node
## LAKE-MOVE RECON, Q5 -- what the SHIPPED camera actually shows.
##
## Measurement only. Nothing in scripts/hub or resources/hub is touched:
## the candidate discs below are built HERE, inside this probe, and added
## to an instantiated copy of the hub scene. The layout on disk never sees
## them.
##
## =====================================================================
## THE FACT THAT DECIDES Q5, AND WHY "ORIENTED TOWARD THE LAKE" CANNOT BE
## HONOURED LITERALLY
##
## HubCamera has FIXED rotation -- no yaw, ever, by design (a look_at
## re-aimed each frame would pitch the horizon with every hop). It always
## looks along -Z at -34 degrees, fov 45 KEEP_WIDTH. So a body is in frame
## only if its bearing off -Z is within +-22.5 degrees, and there is no
## camera move that can "turn toward" anything.
##
## The honest capture is therefore: put Keepy somewhere, render what the
## real camera renders. Two positions are shot for each candidate --
## the plateau CENTRE (the brief's ask), and the best position on the
## plateau from which that candidate is in frame (so a lake that is
## invisible from the middle can still be seen for what it looks like).
##
## =====================================================================
## HOW TO RUN -- under xvfb, NOT --headless
##
##   xvfb-run -a godot4 --rendering-driver opengl3 \
##     --path . res://scripts/dev/LakeMoveCaptureProbe.tscn
##
## This one DOES read pixels, so --headless would force the DUMMY driver
## and every capture would come back empty -- the false green this repo
## has already paid for once. Frames are driven by a COUNTER in _process
## rather than by awaiting RenderingServer.frame_post_draw, which under
## llvmpipe has run past ten minutes without producing anything.

const _HUB_WORLD_SCENE: String = "res://scenes/HubWorld.tscn"
const _OUT_DIR: String = "user://lake_move_capture"
const _LABEL: String = "LakeMoveCaptureProbe"
const _SETTLE_FRAMES: int = 12

## Candidate placements, as (name, centre, radius). Only geometry: the
## colour is the shipped great lake's own, so a capture compares placement
## and not palette.
const _CANDIDATES: Array = [
	["current", Vector3(-52.82, 0.0, -11.23), 20.0],
	["p1_35_-35_r20", Vector3(35.0, 0.0, -35.0), 20.0],
	["p2_15_15_r20", Vector3(15.0, 0.0, 15.0), 20.0],
	["p3b_24.5_-25_r10", Vector3(24.5, 0.0, -25.0), 10.0],
	["p2f_15.5_-19_r16", Vector3(15.5, 0.0, -19.0), 16.0],
]

var _hub: Node = null
var _keepy: Node3D = null
var _viewport: SubViewport = null
var _disc: MeshInstance3D = null
var _frames: int = 0

func _ready() -> void:
	ProbeWatchdog.arm(self, _LABEL)
	print("=== LAKE-MOVE CAPTURE (Q5) ===")
	DirAccess.make_dir_recursive_absolute(_OUT_DIR)

	_hub = (load(_HUB_WORLD_SCENE) as PackedScene).instantiate()
	add_child(_hub)
	await get_tree().process_frame

	_keepy = _hub.find_child("Keepy", true, false) as Node3D
	_viewport = _hub.find_child("SubViewport", true, false) as SubViewport
	if _keepy == null or _viewport == null:
		push_error("%s: hub scene did not give up Keepy / SubViewport." % _LABEL)
		get_tree().quit(1)
		return
	print("    viewport %dx%d, camera fov 45 KEEP_WIDTH, pitch -34, NO YAW"
		% [_viewport.size.x, _viewport.size.y])

	# A single reusable disc. Built here, never added to the layout.
	_disc = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = HubBuilder.GREATLAKE_WATER_COLOR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc.material_override = material
	_hub.find_child("World", true, false).add_child(_disc)

	for candidate in _CANDIDATES:
		await _shoot(candidate[0], candidate[1], candidate[2])

	print("--- captures written under %s ---" % ProjectSettings.globalize_path(_OUT_DIR))
	get_tree().quit(0)

func _shoot(name: String, centre: Vector3, radius: float) -> void:
	# Draw the candidate.
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 96
	cyl.rings = 0
	_disc.mesh = cyl
	_disc.position = Vector3(centre.x, 0.03, centre.z)
	_disc.visible = (name != "current_none")

	# Shot 1: Keepy at the plateau centre -- the brief's ask.
	await _capture(name + "__from_centre", Vector3.ZERO, centre, radius)

	# Shot 2: the best plateau position from which this candidate is in
	# frame. SCANNED, not picked by hand: the camera cannot turn, so the
	# only way to see a thing is to stand where it is already north of you.
	var best := _best_view(centre, radius)
	if best.y < 0.0:
		print("    %-20s NO plateau position puts it in frame at all" % name)
		return
	await _capture(name + "__best_view", Vector3(best.x, 0.0, best.z), centre, radius)

## The walkable point whose camera has the candidate closest to frame
## centre. y is set to -1 when nothing on the plateau sees it.
func _best_view(centre: Vector3, radius: float) -> Vector3:
	var best := Vector3(0.0, -1.0, 0.0)
	var best_bearing: float = 999.0
	var h: float = HubRegion.PLATEAU_HALF_EXTENT
	var x: float = -h
	while x <= h:
		var z: float = -h
		while z <= h:
			var here := Vector3(x, 0.0, z)
			if HubRegion.contains(here):
				var cam := here + HubCamera.OFFSET
				var to := Vector2(centre.x - cam.x, centre.z - cam.z)
				var bearing: float = absf(rad_to_deg(atan2(to.x, -to.y)))
				var span: float = 0.0
				if to.length() > radius:
					span = rad_to_deg(asin(radius / to.length()))
				var off: float = maxf(0.0, bearing - span)
				# Prefer in-frame AND reasonably close.
				var score: float = off + to.length() * 0.01
				if off <= 22.5 and score < best_bearing:
					best_bearing = score
					best = here
			z += 2.0
		x += 2.0
	return best

func _capture(tag: String, keepy_at: Vector3, centre: Vector3, radius: float) -> void:
	_keepy.global_position = keepy_at
	# Let the follow camera settle: it lerps exponentially, so one frame
	# would photograph it mid-travel.
	_frames = 0
	while _frames < _SETTLE_FRAMES:
		await get_tree().process_frame
		_frames += 1
	var image: Image = _viewport.get_texture().get_image()
	var path: String = "%s/%s.png" % [_OUT_DIR, tag]
	image.save_png(path)

	var cam := keepy_at + HubCamera.OFFSET
	var to := Vector2(centre.x - cam.x, centre.z - cam.z)
	var bearing: float = rad_to_deg(atan2(to.x, -to.y))
	# A camera INSIDE the disc has water on every side, so the half-angle
	# is not asin(r/d) -- it is the whole hemisphere. Reporting 0 there
	# printed "off screen" for a shot that is nothing but water, which is
	# the sort of label that outlives the run it was written in.
	var inside: bool = to.length() <= radius
	var span: float = 90.0 if inside else rad_to_deg(asin(radius / to.length()))
	var visible: bool = inside or absf(bearing) - span <= 22.5
	print("    %-34s keepy=(%6.1f,%6.1f) bearing=%+7.1f half=%5.1f dist=%6.2f -> %s"
		% [tag, keepy_at.x, keepy_at.z, bearing, span, to.length(),
		   "CAMERA IN THE WATER" if inside else ("IN FRAME" if visible else "off screen")])
