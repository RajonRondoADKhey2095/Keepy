extends Control
class_name LevelNavTestWorld
## Two flat levels, one link, primitives only -- the smallest world that
## exercises the whole navigation core.
##
## =====================================================================
## NOT UNDER scripts/dev, AND THAT IS LOAD-BEARING
##
## export_presets.cfg carries `scripts/dev/*` in its exclude_filter, so a
## PACKED scene that referenced a script there would resolve in the editor
## and in headless and then fail ONLY in the web build -- the one place
## nobody can check. The trap is already recorded for DevSeed. The scene is
## packed, so everything it names has to be packed too; the PROBE is what
## lives under scripts/dev.
##
## =====================================================================
## ⚠️ THE ROOT Control MUST STAY MOUSE_FILTER_IGNORE
##
## _unhandled_input runs AFTER GUI picking. Any Control under the finger at
## Control's DEFAULT MOUSE_FILTER_STOP consumes the event and calls
## set_input_as_handled(), and nothing downstream ever sees it -- no error,
## no warning, a world that ignores taps. HubWorld shipped exactly that bug
## and it cost a whole batch to find. Do not "tidy" that property away.
##
## =====================================================================
## WHAT THIS SCENE IS AND IS NOT
##
## It is a bench for the core: primitives, no Meshy asset, no game flow, no
## persistence. It does NOT solve drawing two storeys well -- the upper
## floor is a slab you can see the underside of, and transparency sorting
## and culling BETWEEN storeys are named out of scope in the design doc
## rather than attempted here.
##
## Camera occlusion is no longer among those: the device pass found the
## upper slab hiding the walker for the whole approach to the link, and
## LevelCamera now fades whatever stands in the way. What this file owns of
## that mechanism is one thing only -- saying which geometry may be faded.

const LOWER_HALF_EXTENT: float = 9.0
const UPPER_HALF_EXTENT: float = 4.0
const UPPER_PLANE_Y: float = 4.0
## Centre of the upper floor, offset in Z so both slabs are visible at once
## from a camera that never yaws.
const UPPER_CENTRE_Z: float = -6.0

## Where the link stands on each floor. The lower foot is deliberately
## placed ON THE LOWER LEVEL'S EDGE (z = -9, its own boundary) because that
## is the exact geometry the lot-1 funnel needed: a prop on an edge, with a
## whole half-plane of non-existent ground behind it clamping onto it. If
## the aim/destination split were wrong, this placement would find it.
const LINK_FOOT_X: float = 0.0
const LINK_FOOT_Z: float = -9.0
const LINK_TOP_X: float = 0.0
const LINK_TOP_Z: float = -8.0
const LINK_TAP_RADIUS: float = 1.6

@onready var _controller: LevelController = $LevelController
@onready var _walker: LevelWalker = $WorldViewport/SubViewport/World/Walker
## The way back out, and the reason it is KEPT rather than retired with the
## hub button that used to lead here.
##
## ⚠️ THIS SCENE IS NO LONGER REACHABLE FROM THE GAME. The production
## cleanup removed HubWorld's "Test nav (dev)" fallback-menu button, so
## nothing in any shipped code path opens this file any more -- it is a
## dev bench, reached by running the scene directly. The scene and the nav
## core it exercises are kept because the cabin uses that core; only the
## PLAYER-FACING door to this bench was closed.
##
## The button stays because a bench with no way out is a bench nobody runs
## twice: re-expose this scene one day and it is still whole.
@onready var _hub_button: Button = $HubButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hub_button.pressed.connect(_on_hub_pressed)
	_controller.levels = [
		LevelDefinition.make(&"ground", 0.0, LOWER_HALF_EXTENT, 0.0, 0.0),
		LevelDefinition.make(&"upper", UPPER_PLANE_Y, UPPER_HALF_EXTENT, 0.0, UPPER_CENTRE_Z),
	]
	# The two ends are built FROM the level definitions, so the height a
	# player arrives at and the height that level's floor is at are one
	# fact rather than two literals free to drift.
	var lower: LevelDefinition = _controller.levels[0]
	var upper: LevelDefinition = _controller.levels[1]
	_controller.links = [
		LevelTransition.make(0, 1,
			Vector3(LINK_FOOT_X, lower.plane_y, LINK_FOOT_Z),
			Vector3(LINK_TOP_X, upper.plane_y, LINK_TOP_Z),
			LINK_TAP_RADIUS),
	]
	_controller.tapped_ground.connect(_on_tapped_ground)
	_controller.tapped_transition.connect(_on_tapped_transition)
	_build_world()

func _on_tapped_ground(destination: Vector3) -> void:
	_walker.hop_to(destination)

func _on_tapped_transition(link: LevelTransition, _destination: Vector3) -> void:
	_walker.request_transition(link)

func _on_hub_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/HubWorld.tscn")

func _unhandled_input(event: InputEvent) -> void:
	# Release only, and both paths, for HubTapInput's measured reasons:
	# acting on the press would fire while a finger is still moving, and a
	# desktop click produces no touch event at all.
	var touch := event as InputEventScreenTouch
	if touch:
		if not touch.pressed:
			_controller.dispatch(touch.position)
			get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
		_controller.dispatch(click.position)
		get_viewport().set_input_as_handled()

## Primitives, built in code so the scene file carries structure and not
## coordinates -- the layout is the constants above, in one place.
func _build_world() -> void:
	var props: Node3D = $WorldViewport/SubViewport/World/Props
	var lower: LevelDefinition = _controller.levels[0]
	var upper: LevelDefinition = _controller.levels[1]
	var lower_slab := _slab(lower, Color(0.24, 0.42, 0.20))
	lower_slab.name = "LowerSlab"
	props.add_child(lower_slab)
	var upper_slab := _slab(upper, Color(0.44, 0.36, 0.26))
	upper_slab.name = "UpperSlab"
	props.add_child(upper_slab)
	var post := _post(_controller.links[0])
	post.name = "LinkPost"
	props.add_child(post)
	_mark_occluders(upper_slab, post)

## Opting the transition geometry into LevelCamera's fade.
##
## Which nodes, decided by MEASUREMENT and not by taste. Against this
## camera offset, on the segment from the lens to the walker's mass:
##
##   * the UPPER SLAB blocks him from z -7 all the way to the link foot at
##     -9, across the slab's whole width -- the entire approach to the one
##     transition this world has.
##   * the LINK POST blocks him at the foot itself, the last standing
##     point before a crossing.
##   * the LOWER SLAB never can. It is the ground the camera looks DOWN
##     at; nothing standing on it is ever behind it. Marking it would cost
##     a fade that could not fire and would say something untrue about
##     what the group means.
func _mark_occluders(upper_slab: MeshInstance3D, post: MeshInstance3D) -> void:
	upper_slab.add_to_group(LevelCamera.OCCLUDER_GROUP)
	post.add_to_group(LevelCamera.OCCLUDER_GROUP)

func _slab(level: LevelDefinition, colour: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(level.half_extent * 2.0, 0.2, level.half_extent * 2.0)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	# Top face exactly ON the plane: the slab is 0.2 thick and centred, so
	# its surface is the plane a tap resolves against. A floor you can see
	# that is not the floor you walk on is the first thing to mistrust when
	# a level looks wrong.
	node.position = Vector3(level.centre_x, level.plane_y - 0.1, level.centre_z)
	node.material_override = _unshaded(colour)
	return node

func _post(link: LevelTransition) -> MeshInstance3D:
	var span: float = absf(link.point_b.y - link.point_a.y)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.18
	mesh.bottom_radius = 0.18
	mesh.height = maxf(span, 0.2)
	# Stated, never left to default: a CylinderMesh at Godot's default
	# tessellation is the trap this repository has measured five times.
	mesh.radial_segments = 8
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(link.point_a.x, link.point_a.y + span * 0.5, link.point_a.z)
	node.material_override = _unshaded(Color(0.86, 0.72, 0.30))
	return node

## Unshaded, like every surface in this project: the scene carries no
## DirectionalLight3D, so a lit material would not render the colour that
## was written.
func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
