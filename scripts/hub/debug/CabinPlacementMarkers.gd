extends Node3D

## TEMPORARY, THROWAWAY. Not a feature -- a visual ruler for a decision
## Mathieu makes by walking the plateau on staging and looking at what four
## candidate spots for the future cabin `.glb` actually feel like. Once he
## names the winner, this whole file and its one call site in HubWorld.gd
## are deleted; the winning coordinate goes into `hub_layout.tres` as a real
## `&"cabin"` entry in its own lot. NOTHING here is meant to survive to
## `main` -- this branch is scoped to `staging` only, per the session brief.
##
## PARENTED TO `_world`, NEVER TO `Props` -- same rule `_spawn_impact_ring()`
## documents in HubWorld.gd: the sondes that gate the hub's draw-node budget
## (`WaterTintProbe`, `TurnstileProbe`, `SeesawProbe`, ...) all walk the
## `Props` subtree specifically. Four markers counted as props would move
## every one of those budget assertions for a tool that isn't decor.
##
## FOUR CANDIDATES, MEASURED, NOT GUESSED. `resources/hub/hub_layout.tres`
## was parsed for every existing entry's position/radius (props via
## `HubBuilder.FOOTPRINT_RADIUS`, water via the bank radii the pond/lake/
## greatlake bodies are actually drawn at -- `POND_BANK_RADIUS` 3.62,
## `LAKE_BANK_RADIUS` 9.05, `GREATLAKE_WATER_RADIUS + GREATLAKE_BANK_MARGIN`
## 17.30 for the east lobe (15.5,-19) and 11.30 for the west lobe
## (-12,-19.5)), and every candidate below is the measured clearance to the
## single nearest of those, not an assumption.
##
## ⚠️ WHAT THE RECON FOUND, AND IT IS NOT WHAT THE BRIEF ASSUMED: the two
## great-lake lobes are 27.5 u apart centre to centre and their banks sum to
## 28.6 u -- they touch. Between the three portals (z -4.6 to -7.2) and that
## merged lake, there is NO point left on the plateau with the requested
## >=3.0 u clearance from every existing entry; the best achievable inside
## z in [-1, -19] is 2.36 u, at candidate #1. Candidates #1-#3 are therefore
## published with their REAL measured clearance (2.36 / 1.92 / 1.62), all
## under the 3 u ask, rather than silently relaxed or hidden -- Mathieu is
## the one who judges whether that reads as "open enough" on the actual
## screen. Candidate #4 is the one spot that DOES clear 3 u (7.82 u, the
## least crowded of the two candidates the recon found near the plateau's
## far south-west corner) in case the zone from his screenshots is in fact
## the area past the lobes rather than the gap before them.
const MARKERS: Array[Dictionary] = [
	{
		"number": "1",
		"position": Vector3(-0.25, 0.0, -3.50),
		"colour": Color(1.0, 0.15, 0.10),  # red -- closest to spawn
		"clearance": 2.36,
	},
	{
		"number": "2",
		"position": Vector3(-3.75, 0.0, -7.50),
		"colour": Color(0.15, 0.85, 0.20),  # green -- west corridor, near Chased
		"clearance": 1.92,
	},
	{
		"number": "3",
		"position": Vector3(-11.50, 0.0, -6.50),
		"colour": Color(0.20, 0.55, 1.0),  # blue -- further west, near the small lake's north shore
		"clearance": 1.62,
	},
	{
		"number": "4",
		"position": Vector3(-23.25, 0.0, -35.00),
		"colour": Color(1.0, 0.85, 0.10),  # yellow -- far south-west, past both lobes, genuinely 3u+ clear
		"clearance": 7.82,
	},
]

const MARKER_RADIUS: float = 0.35
const MARKER_HEIGHT: float = 1.6
const LABEL_Y: float = 2.1


func _ready() -> void:
	for entry in MARKERS:
		_spawn_marker(entry)


func _spawn_marker(entry: Dictionary) -> void:
	var pos: Vector3 = entry["position"]
	var colour: Color = entry["colour"]

	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = MARKER_RADIUS
	cyl.bottom_radius = MARKER_RADIUS
	cyl.height = MARKER_HEIGHT
	# Low tessellation on purpose -- this is a debug ruler, not an asset;
	# the project's own decimation discipline (see MESHY_SPEC.md) applies
	# just as much to a shape that will never ship.
	cyl.radial_segments = 12
	post.mesh = cyl

	var material := StandardMaterial3D.new()
	# UNSHADED like every surface on this screen -- there is no
	# DirectionalLight3D in HubWorld.tscn, so a lit material would not
	# return the colour written here.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	post.set_surface_override_material(0, material)

	post.position = Vector3(pos.x, MARKER_HEIGHT * 0.5, pos.z)
	add_child(post)

	var label := Label3D.new()
	label.text = entry["number"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.double_sided = true
	label.no_depth_test = true
	label.pixel_size = 0.02
	label.modulate = colour
	label.outline_size = 12
	label.font_size = 96
	label.position = Vector3(pos.x, LABEL_Y, pos.z)
	add_child(label)
