extends MeshInstance3D
class_name SkateShadow
## CH62 EFFECT 4 -- THE THING THAT SAYS "YOU ARE IN THE AIR".
##
## =====================================================================
## THE PROBLEM IT ANSWERS
##
## CH61 measured 1.106 u of climb at 8.97 u/s and 0.098 u at 2.98 u/s on
## the same quarterpipe -- an order of magnitude apart -- and Mathieu, on
## device, could not tell the two rides apart. On a camera 11.7 u away
## looking down at 34 deg (HubCamera.OFFSET, never moves, never rises), a
## metre of height moves the board a couple of dozen pixels UP THE FRAME
## and nothing else. That is indistinguishable from the board simply
## being further away.
##
## A separated shadow is the oldest answer in the book and it is the
## right one here, because it is the only cue that turns height into a
## DISTANCE ON SCREEN between two things the player can see at once. The
## board goes up; the dark patch stays on the ground; the gap between
## them IS the altitude, and it needs no HUD, no number and no learning.
##
## =====================================================================
## WHY IT IS A DRAWN BLOB AND NOT A REAL SHADOW
##
## Every asset in this hub is UNLIT (CLAUDE.md), the board's own
## MeshInstance3D ships with `SHADOW_CASTING_SETTING_OFF`, and turning
## real shadow casting on for one prop would light a shadow map for the
## whole north lobe -- at a station CH52 priced at ZERO available draw
## calls. This is ONE quad, ONE material, ONE draw call, and it exists
## only while somebody is riding.
##
## =====================================================================
## WHERE IT LANDS, AND WHY THAT IS A RAYCAST
##
## HubSurface owns the ground (D1) and `ground()` would be the obvious
## answer -- but the board spends most of an interesting ride ABOVE A
## MODULE, and a shadow put on the lawn under the funbox deck is a
## shadow drawn INSIDE the funbox, i.e. one the depth buffer eats. The
## cue would vanish at exactly the moment it is worth having.
##
## So the blob is dropped by a single downward ray against the park's
## own collision layer -- the solids CH60 built, nothing new -- and falls
## back to `HubSurface.ground()` when the ray hits nothing, which is the
## whole of the open lawn. D1 is untouched: this reads the surface, it
## never writes it, and no second ground is authored anywhere.
##
## ⚠️ TRANSPARENCY IS SET EXPLICITLY, and CLAUDE.md says why: the alpha
## channel of `albedo_color` is IGNORED while `transparency` stays
## DISABLED, with no error to say so -- a shadow that rendered as an
## opaque black lozenge would be a worse bug than no shadow at all. And
## the shipped look must be checked ON DEVICE: this repo has already had
## transparency come back green under llvmpipe and broken under WebGL2.

## Base radius of the blob on the ground, world units. The board's deck is
## 0.92 x 0.26, and a shadow the size of the board reads as a plank
## rather than as a shadow -- this is a little wider than the wheelbase,
## which is what a soft-edged contact patch looks like.
const RADIUS: float = 0.62
## How far above the surface the quad sits. Enough to clear z-fighting
## with the lawn and with a module's top face, small enough that it is
## never seen as a floating card.
const LIFT_EPSILON: float = 0.014
## How far down the ray looks for something to land on.
const RAY_DEPTH: float = 40.0
const TEX_SIZE: int = 48
## Near black with the hub's warmth in it, never pure black: the palette
## has no pure black in it anywhere and one would read as a hole.
const INK: Color = Color(0.07, 0.09, 0.06)

var _body: SkateBoardBody = null
var _material: StandardMaterial3D = null
var _riding: bool = false
## Published for the bench: the last height the blob was drawn for, and
## where it landed.
var _drawn_lift: float = 0.0
var _drawn_y: float = 0.0

func setup(body: SkateBoardBody) -> void:
	_body = body
	name = "SkateShadow"
	var quad := QuadMesh.new()
	quad.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	mesh = quad
	# QuadMesh faces +Z; -90 deg about X sends +Z to +Y, so the face the
	# engine calls FRONT is the one pointing at the sky. Written as a
	# measurement of the rotation rather than trusted: CLAUDE.md, the
	# outward side of a surface is taken from the ENGINE and never from
	# the maths -- and `CULL_DISABLED` below makes the question moot for
	# a single flat quad, which has no inside to get wrong.
	rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material.albedo_color = Color(INK.r, INK.g, INK.b, 0.0)
	_material.albedo_texture = _blob_texture()
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	visible = false

## A radial falloff, opaque in the middle and zero at the rim, with the
## edge softened well inside the quad so the blob never shows a circle's
## outline. Generated rather than shipped: 48 x 48 of alpha is not a
## payload anybody should download.
func _blob_texture() -> ImageTexture:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var half: float = float(TEX_SIZE - 1) * 0.5
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var dx: float = (float(x) - half) / half
			var dy: float = (float(y) - half) / half
			var r: float = sqrt(dx * dx + dy * dy)
			var a: float = clampf(1.0 - r, 0.0, 1.0)
			# Squared twice: a soft core and a very soft rim, which is
			# what a contact shadow under an overcast sky looks like.
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

func set_riding(riding: bool) -> void:
	_riding = riding
	visible = riding

func drawn_lift() -> float:
	return _drawn_lift

func drawn_y() -> float:
	return _drawn_y

func blob_alpha() -> float:
	return _material.albedo_color.a if _material != null else 0.0

## On the PHYSICS tick because it casts a ray, and a ray wants the space
## state of the step it belongs to.
func _physics_process(_delta: float) -> void:
	if not _riding or _body == null or not is_instance_valid(_body):
		return
	var at: Vector3 = _body.global_position
	var flat := Vector3(at.x, 0.0, at.z)
	var floor_y: float = HubSurface.height_at(flat)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3(0.0, 0.05, 0.0), at + Vector3(0.0, -RAY_DEPTH, 0.0))
	query.collision_mask = 1 << (SkateBoardBody.LAYER_PARK - 1)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		floor_y = maxf(float(hit["position"].y), floor_y)
	_drawn_y = floor_y + LIFT_EPSILON
	# The lift the blob DRAWS is the gap to what is under the board right
	# now, which on a module is the module and not the lawn -- otherwise
	# a board standing on the funbox deck would be given a 0.85 u shadow
	# gap while it is sitting perfectly still on a solid surface.
	_drawn_lift = maxf(at.y - floor_y, 0.0)
	global_position = Vector3(at.x, _drawn_y, at.z)
	var s: float = SkateFeel.shadow_scale(_drawn_lift)
	scale = Vector3(s, s, 1.0)
	var c: Color = _material.albedo_color
	c.a = SkateFeel.shadow_alpha(_drawn_lift)
	_material.albedo_color = c
