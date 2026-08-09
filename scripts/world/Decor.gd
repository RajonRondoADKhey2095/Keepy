extends Node3D
class_name Decor
## Purely visual background layer -- distant hill silhouettes that scroll
## past slower than the track, giving the run a sense of depth.
##
## ZERO GAMEPLAY COUPLING, BY CONSTRUCTION. This node has no collider, is
## never read by Hitboxes.gd/ModelSlot.gd, and nothing here ever touches
## GameState beyond READING scroll_speed()/run state -- the same one-way
## read DarkModeEffect.gd and LaneBarrier.gd already do. A probe that
## deletes this whole node would not change one line of measured gameplay
## behaviour.
##
## POOLING, same contract as TrackManager/LaneBarrier: every hill instance
## is built once in _ready() and only ever repositioned -- never freed and
## re-instantiated while a run is live. Two LAYERS (near/far), each its own
## small fixed-size pool, driven by one shared per-layer config
## (_LAYERS below) rather than duplicated per-layer code -- the
## "reusable system, not hardcoded placement" the brief asked for: adding a
## third layer, or retuning an existing one, is a data change in _LAYERS,
## never a new code path.
##
## WHY STATIC HILLS ALONE WOULD NOT WORK: TrackManager's own doc explains
## the world moves TOWARD the player, never the other way round, so it
## scrolls forever in one direction. A hill parented here and never moved
## would eventually reach and pass the camera exactly like an un-recycled
## TrackSegment would. So each hill scrolls by the same per-frame world
## delta as the track, scaled down by its layer's PARALLAX factor
## (< 1 == reads as farther away, the standard parallax depth cue), and
## recycles to the back of its spawn range once it scrolls past its own
## layer's near edge (spawn_z_max) -- same recycle-not-destroy shape as
## TrackManager._recycle_segment, but recycling against the layer's own
## band rather than a camera-proximate threshold, so a hill never travels
## through the readable foreground and always reads at the same distance.
##
## DARK-MODE CONTRAST (docs/MESHY_SPEC.md section 8): hue does not survive
## the invert+tint, luminance does. The two layers are NOT distinguished by
## hue at all (both are desaturated, near-grey stone tones) -- they are
## distinguished by VALUE, spaced clearly apart from each other, from the
## ground albedo and from the sky, so the layering still reads after a full
## invert regardless of which of the six tint variants is active. Both
## surfaces are `unshaded` for the same reason CHARGER/STOMPER/the pursuer
## body already are: an unshaded albedo is the one thing whose post-invert
## colour is actually predictable (see that section's own reasoning).

## One entry per background layer. Kept as plain data (not exported) since
## nothing outside this file, and no probe, needs to reach into it -- unlike
## TrackManager's tuning constants, none of this changes run difficulty or
## fairness, so there is nothing here a probe would ever need to assert on.
const _LAYERS: Array[Dictionary] = [
	{
		# Far layer: low, wide, flat-topped ridges. Darker than the ground
		# (see the section header) so it reads as sitting IN SHADOW behind
		# everything else, the usual atmospheric-perspective cue.
		"count": 5,
		"color": Color(0.28, 0.32, 0.30),
		"parallax": 0.15,
		"spawn_z_min": -520.0,
		"spawn_z_max": -360.0,
		"x_range": 34.0,
		"radius_range": Vector2(22.0, 34.0),
		"height_range": Vector2(14.0, 22.0),
		"sides": 5,
	},
	{
		# Near layer: taller, pointed peaks, clearly lighter than the ground
		# and the far layer -- but still short of the sky's own brightness,
		# so the horizon line stays legible (see the class doc for the
		# measured ordering).
		"count": 5,
		"color": Color(0.66, 0.60, 0.52),
		"parallax": 0.35,
		"spawn_z_min": -340.0,
		"spawn_z_max": -210.0,
		"x_range": 26.0,
		"radius_range": Vector2(10.0, 16.0),
		"height_range": Vector2(22.0, 34.0),
		"sides": 6,
	},
]

## One inner array per layer in _LAYERS, same index -- the pool itself.
var _pools: Array[Array] = []

## OWN RandomNumberGenerator instance, never the global randf()/randf_range()
## free functions. Those draw from Godot's single global RNG stream, which
## is exactly the stream dev probes call the global seed() against for
## reproducible runs (see e.g. scripts/dev/StrikeAudit.gd,
## DevSeed.seed_value()) and the one TrackManager's own spawn rolls draw
## from. A decor draw on the global stream would shift every gameplay roll
## that comes after it by one step -- silent, and exactly the kind of
## "decor influencing spawn" the brief rules out, even though no
## probability anywhere would have changed.
##
## Handed out by DecorRng rather than constructed here (F10): unforced it is
## still an OS-entropy stream, byte-identical to what this line did before,
## and a probe that needs a fixed background can pin it without any of this
## file knowing. Read DecorRng.gd for why that separation is the property
## that must survive, and why seeding must not cost it.
var _rng := DecorRng.make()

func _ready() -> void:
	for layer in _LAYERS:
		var pool: Array[MeshInstance3D] = []
		for i in int(layer["count"]):
			var hill := _build_hill(layer)
			add_child(hill)
			_place_hill(hill, layer, true)
			pool.append(hill)
		_pools.append(pool)

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return
	# Same base delta TrackManager scrolls the track by; each layer only
	# scales it down by its own parallax factor. Reading scroll_speed()
	# directly here (rather than being handed a value) matches how every
	# other purely-visual world node in this project already stays in sync
	# with the track -- see DarkModeEffect.gd / LaneBarrier.gd.
	var world_delta := GameState.scroll_speed() * delta
	for layer_index in _LAYERS.size():
		var layer: Dictionary = _LAYERS[layer_index]
		var move_amount: float = world_delta * float(layer["parallax"])
		# Recycle against THIS layer's own spawn_z_max -- the near edge of its
		# designated background band -- never a camera-proximate threshold.
		# A hill that recycles only once it nears the camera would spend its
		# whole lifecycle crossing the readable foreground first, growing
		# closer and larger the entire way; recycling at the band's own near
		# edge keeps every hill inside [spawn_z_min, spawn_z_max] forever, so
		# its apparent distance never changes no matter how many times it
		# has recycled or how far the run has gone.
		var recycle_z: float = layer["spawn_z_max"]
		for hill in _pools[layer_index]:
			hill.position.z += move_amount
			if hill.position.z > recycle_z:
				_place_hill(hill, layer, false)

## Builds one hill's mesh+material once. A low-poly cone (radial_segments =
## layer["sides"], top_radius = 0) is the cheapest primitive Godot ships
## that still reads as a mountain silhouette -- a handful of triangles per
## instance, negligible against the 50k frame budget (docs/MESHY_SPEC.md
## section 7). `cast_shadow` is switched off: these are background-only and
## sit far outside the readable play area, so they should not add to the
## one DirectionalLight3D's shadow pass.
func _build_hill(layer: Dictionary) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.radial_segments = int(layer["sides"])
	cone.rings = 0
	mesh_instance.mesh = cone
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = layer["color"]
	mesh_instance.set_surface_override_material(0, material)
	return mesh_instance

## (Re)randomises one hill's size and position within its layer's ranges.
## `initial` spreads the very first fill evenly across the whole spawn
## range (so the layer looks populated from the first frame instead of
## clumped at the far edge); a recycle always returns to the far edge,
## exactly like TrackManager._recycle_segment placing a segment behind the
## furthest existing one.
func _place_hill(hill: MeshInstance3D, layer: Dictionary, initial: bool) -> void:
	var radius := _rng.randf_range(layer["radius_range"].x, layer["radius_range"].y)
	var height := _rng.randf_range(layer["height_range"].x, layer["height_range"].y)
	var cone := hill.mesh as CylinderMesh
	cone.bottom_radius = radius
	cone.height = height
	var x := _rng.randf_range(-float(layer["x_range"]), float(layer["x_range"]))
	var z: float
	if initial:
		z = _rng.randf_range(layer["spawn_z_min"], layer["spawn_z_max"])
	else:
		z = layer["spawn_z_min"]
	# Half the height, so the cone's flat base sits on the ground plane
	# (y = 0) rather than straddling it.
	hill.position = Vector3(x, height * 0.5, z)
