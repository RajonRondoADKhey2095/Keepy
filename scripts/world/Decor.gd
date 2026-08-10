extends Node3D
class_name Decor
## Purely visual background layer -- distant hill/mountain silhouettes that
## scroll past slower than the track, giving the run a sense of depth.
##
## ZERO GAMEPLAY COUPLING, BY CONSTRUCTION. This node has no collider, is
## never read by Hitboxes.gd/ModelSlot.gd, and nothing here ever touches
## GameState beyond READING scroll_speed()/run state -- the same one-way
## read DarkModeEffect.gd and LaneBarrier.gd already do. A probe that
## deletes this whole node would not change one line of measured gameplay
## behaviour.
##
## POOLING, same contract as TrackManager/LaneBarrier: every instance is
## built once in _ready() and only ever repositioned -- never freed and
## re-instantiated while a run is live. THREE layers (mountain/far/near),
## each its own small fixed-size pool, driven by one shared per-layer
## config (_LAYERS below) rather than duplicated per-layer code -- the
## "reusable system, not hardcoded placement" the brief asked for: adding a
## fourth layer, or retuning an existing one, is a data change in _LAYERS,
## never a new code path.
##
## WHY STATIC HILLS ALONE WOULD NOT WORK: TrackManager's own doc explains
## the world moves TOWARD the player, never the other way round, so it
## scrolls forever in one direction. A hill parented here and never moved
## would eventually reach and pass the camera exactly like an un-recycled
## TrackSegment would. So each instance scrolls by the same per-frame world
## delta as the track, scaled down by its layer's PARALLAX factor
## (< 1 == reads as farther away, the standard parallax depth cue), and
## recycles to the back of its spawn range once it scrolls past its own
## layer's near edge (spawn_z_max) -- same recycle-not-destroy shape as
## TrackManager._recycle_segment, but recycling against the layer's own
## band rather than a camera-proximate threshold, so an instance never
## travels through the readable foreground and always reads at the same
## distance.
##
## RECYCLE FADE (10 August 2026, decor stability fix -- see
## scripts/dev/DecorStabilityAudit.gd, which found and closes this):
## `spawn_z_max` keeps an instance out of the readable FOREGROUND, but it is
## still 200-550 world units in front of the camera for all three layers --
## comfortably inside the camera's own ~107-degree horizontal FOV at those
## distances, which dwarfs any layer's x_range. So the teleport back to
## `spawn_z_min` was happening in full view: an instance growing toward its
## largest apparent size, then snapping to its smallest at the far edge, in
## a single frame, at a fixed screen position, once per recycle, for all 13
## instances at staggered phases -- which is what a whole run of that reads
## as continuous shape/size instability, on top of (and unaddressed by) the
## x_range spawn-spread fix from the previous lot (acf060c). Fixed by fading
## `modulate.a` to 0 over the last `_FADE_FRACTION` of the band before the
## recycle edge, and back to 1 over the first `_FADE_FRACTION` after
## respawning at the far edge (`_fade_alpha`, applied every physics tick
## after the recycle check) -- the teleport itself still happens on the same
## frame it always did, it now simply happens while alpha is already 0.
##
## ASSET SWAP (docs/MESHY_SPEC.md section 8.1, "no asset yet" at the time it
## was written): the two hill layers, plus a new farther-back mountain
## layer, were originally plain Godot primitives (unshaded CylinderMesh
## cones). They now render Meshy-sourced 2D billboard cutouts
## (assets_source/decor/{mountain,hill_near,hill_far}.png, processed and
## installed at assets/textures/decor/) via Sprite3D instead. This is a
## DELIBERATE DEVIATION from the doc's own suggested hook ("swap the
## CylinderMesh for a ModelSlot-style install point") -- ModelSlot exists
## for real 3D low-poly meshes on gameplay-addressed nodes (Obstacle.gd's
## $DodgeMesh and friends), which these are not: there is no fixed scene
## node here for gameplay code to address by path, only a pool of
## interchangeable background instances, and the source art is a flat
## cutout, not a mesh. A Sprite3D built directly in `_build_hill` is the
## smaller, more direct fit for "pooled flat billboard, no collider, no
## gameplay reference."
##
## `billboard = BILLBOARD_FIXED_Y` (yaw only, stays upright) rather than no
## billboarding at all: CameraFollow.gd lerps its position toward the
## player and then look_at()s a point ahead of them, so the camera's yaw is
## not perfectly static -- it drifts slightly during lane changes before
## the lerp catches up. A Y-billboard keeps every instance correctly faced
## no matter what that transient yaw is doing, at zero extra cost over a
## static quad. It does not correct for the camera's fixed -20 degree
## pitch (a Y-billboard only ever rotates around Y), but a static quad
## would show the exact same foreshortening from that pitch, so nothing is
## given up by picking the version that is also yaw-safe.
##
## DARK-MODE CONTRAST (docs/MESHY_SPEC.md section 8): hue does not survive
## the invert+tint, luminance does, which is why every dark-mode-visible
## surface in this project is `shaded = false` (Sprite3D's `shaded`
## property, same idea as the old CylinderMesh's
## `SHADING_MODE_UNSHADED`) -- an unshaded surface renders as exactly its
## texture colour regardless of light angle, the only way its post-invert
## colour is a *known* value. Background decor has no gameplay-legibility
## requirement (section 8.1: "it competes with nothing the player must
## read"), so no further per-pixel tint pass was applied on top of the
## source renders here; that stays an open call for Mathieu if a future
## pass wants it.
##
## FOG, MEASURED, NOT A BUG: WorldEnvironment's fog (fog_density = 0.0035,
## an existing setting, untouched here) is strong enough at these layers'
## own z-bands that it dominates their rendered colour almost entirely --
## an in-engine pixel sample at each layer's own screen position, taken
## during this swap, read (106-121, 167-197, 184) for ALL THREE layers
## (mountain, hill_far, hill_near) despite three quite different source
## textures, against a clearly different sky sample nearby. This looked,
## at a glance in an early offscreen capture, like the hill layers were
## missing entirely (their real per-instance positions were confirmed
## on-screen and in-frustum first, before that read); it is really every
## unshaded layer converging toward fog_light_color the same way distant
## opaque geometry already does elsewhere in this scene, at exactly the
## z-bands the original CylinderMesh cones already lived at. The surviving
## channel spread (near hill slightly less fog-crushed than far hill,
## both less than the farther-back mountain) still preserves the intended
## near/far/mountain depth ordering by VALUE, just faintly -- consistent
## with this file's own dark-mode reasoning above, that value survives
## where hue does not. Left as measured, not "fixed": disabling fog on
## just these layers would make them read as flat cutouts against
## everything else correctly fading into haze, which is a worse trade.

## One entry per background layer. Kept as plain data (not exported) since
## nothing outside this file, and no probe, needs to reach into it -- unlike
## TrackManager's tuning constants, none of this changes run difficulty or
## fairness, so there is nothing here a probe would ever need to assert on.
##
## `height_range` is the WORLD-SPACE height (in metres) an instance is
## scaled to; width follows automatically from the source texture's own
## aspect ratio (Sprite3D.pixel_size scales both axes uniformly) rather
## than being independently randomised the way the old cone's
## radius_range/height was -- a real image would visibly distort if X and Y
## were stretched independently, unlike an abstract cone silhouette.
const _MOUNTAIN_TEXTURE: Texture2D = preload("res://assets/textures/decor/mountain.png")
const _HILL_FAR_TEXTURE: Texture2D = preload("res://assets/textures/decor/hill_far.png")
const _HILL_NEAR_TEXTURE: Texture2D = preload("res://assets/textures/decor/hill_near.png")

## Fraction of a layer's own band (spawn_z_max - spawn_z_min) spent fading
## in/out at each edge -- see the class doc's "RECYCLE FADE" section. A
## FRACTION of the band, not a fixed world distance: the three layers' bands
## are different widths (130m near, 160m far/mountain), and a fixed margin
## would eat a wildly different share of each one's own journey. 0.12 was
## chosen to comfortably clear a single frame's worth of motion at every
## speed this game reaches (STAGE_SPEEDS tops out at 26 m/s; even the near
## layer's own parallax x max speed only covers a few centimetres per
## frame, so 12% of a 130m band is hundreds of frames of headroom) while
## still leaving the large majority of each band at full opacity.
const _FADE_FRACTION: float = 0.12

const _LAYERS: Array[Dictionary] = [
	{
		# Mountain layer: the farthest-back band, behind both hill layers.
		# Low count, modest height_range (deliberately close to the far
		# hill layer's own 14-22, not far above it) over a wide x_range so
		# peaks read as an occasional landmark with real sky gaps between
		# them, rather than a continuous wall -- "reasonable frequency", per
		# the brief. MEASURED, not assumed: a first pass at height_range
		# (30,45) produced individual instances ~50m wide (mountain.png's
		# own ~1.37:1 aspect ratio scales width with height) -- wider than
		# this x_range's whole spread, so all 3 instances fused into one
		# unbroken ridge with no sky showing through. Caught by an offscreen
		# capture probe (same method as MESHY_SPEC.md section 11), not by
		# inspection.
		"texture": _MOUNTAIN_TEXTURE,
		"count": 3,
		"parallax": 0.08,
		"spawn_z_min": -700.0,
		"spawn_z_max": -540.0,
		"x_range": 55.0,
		"height_range": Vector2(16.0, 24.0),
		"render_priority": -2,
	},
	{
		# Far hill layer: same band/parallax/count the procedural cones used
		# (docs/MESHY_SPEC.md section 8.1 called this "darker than the
		# ground... sitting IN SHADOW"), now the desaturated hill cutout.
		#
		# x_range WIDENED 34 -> 62 (10 August 2026, decor stability fix):
		# `x_range: 34.0` was carried over unchanged from the old
		# CylinderMesh cones, whose radius scaled independently of height.
		# hill_far.png is a WIDE, low-profile cutout (512x166px, ~3.08:1
		# aspect) -- Sprite3D.pixel_size scales both axes uniformly (see
		# _place_hill), so a single instance at this layer's own max height
		# (22) renders ~68m wide, WIDER than the old x_range's whole 68m
		# spread. That is exactly the "individual instances wider than the
		# whole spawn range" defect the mountain layer's own comment above
		# describes catching and fixing on ITS first pass -- it was never
		# re-checked here after the billboard swap replaced independently-
		# scaled cones with an aspect-locked cutout. MEASURED (offscreen
		# capture + per-instance pixel sampling, throwaway probe, not
		# committed): with the old x_range, hill_far's 5 instances plus
		# hill_near's 5 overlapped into one indistinguishable mass covering
		# nearly the same screen region as the mountain layer -- the
		# "single green blob, unstable shape" reported on staging. 62 brings
		# the max-width/spread ratio to ~0.55, the same "occasional
		# landmark, real gaps" territory the mountain layer already targets,
		# without touching height_range (art-directed scale, left alone).
		"texture": _HILL_FAR_TEXTURE,
		"count": 5,
		"parallax": 0.15,
		"spawn_z_min": -520.0,
		"spawn_z_max": -360.0,
		"x_range": 62.0,
		"height_range": Vector2(14.0, 22.0),
		"render_priority": -1,
	},
	{
		# Near hill layer: same band/parallax/count the procedural cones
		# used, now the vivid hill cutout -- vivid-vs-desaturated is the
		# atmospheric-perspective cue for this pair of layers in daylight;
		# `shaded = false` on both (see class doc) is what keeps the pair
		# still legible against each other after the dark-mode invert.
		#
		# x_range WIDENED 26 -> 74 (10 August 2026, decor stability fix):
		# same defect as hill_far above, worse here -- hill_near.png is
		# 512x203px (~2.52:1 aspect) at a TALLER height_range (up to 34), so
		# a single instance could render ~86m wide against the old
		# x_range's 52m spread: one instance alone was wider than its
		# entire band. 74 brings max-width/spread to ~0.58. Left this
		# layer's height_range untouched for the same reason as above --
		# this is a spawn-spread fix, not a rescale of how big a near hill
		# is allowed to look.
		"texture": _HILL_NEAR_TEXTURE,
		"count": 5,
		"parallax": 0.35,
		"spawn_z_min": -340.0,
		"spawn_z_max": -210.0,
		"x_range": 74.0,
		"height_range": Vector2(22.0, 34.0),
		"render_priority": 0,
	},
]

## One inner array per layer in _LAYERS, same index -- the pool itself.
var _pools: Array[Array] = []

## OWN RandomNumberGenerator instance, never the global randf()/randi()/randf_range()
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
		var pool: Array[Sprite3D] = []
		for i in int(layer["count"]):
			var hill := _build_hill(layer)
			add_child(hill)
			_place_hill(hill, layer, true)
			# Set immediately, not left at Sprite3D's default (opaque) until
			# the first PLAYING physics tick -- the initial spread is uniform
			# across the WHOLE band (see _place_hill), so some instances can
			# land inside a fade zone from the very first frame.
			hill.modulate.a = _fade_alpha(hill.position.z, layer)
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
		# An instance that recycles only once it nears the camera would spend
		# its whole lifecycle crossing the readable foreground first, growing
		# closer and larger the entire way; recycling at the band's own near
		# edge keeps every instance inside [spawn_z_min, spawn_z_max] forever,
		# so its apparent distance never changes no matter how many times it
		# has recycled or how far the run has gone.
		var recycle_z: float = layer["spawn_z_max"]
		for hill in _pools[layer_index]:
			hill.position.z += move_amount
			if hill.position.z > recycle_z:
				_place_hill(hill, layer, false)
			# AFTER the recycle check, using whichever z is current -- on the
			# frame a hill teleports back to spawn_z_min this evaluates the
			# NEW position, giving alpha 0 immediately, not a one-frame flash
			# of the fade-out value computed against the old one. See the
			# class doc "RECYCLE FADE".
			hill.modulate.a = _fade_alpha(hill.position.z, layer)

## Alpha for an instance at world-Z `z` within `layer`'s own band -- 0 at
## and beyond both edges, 1 across the whole middle majority, ramping
## linearly over `_FADE_FRACTION` of the band at each end. See the class
## doc "RECYCLE FADE": this is what keeps the hard teleport at spawn_z_max
## invisible instead of a mid-frustum pop, and gives a symmetrical fade-in
## after a respawn at spawn_z_min so an instance does not simply blink into
## existence there either.
func _fade_alpha(z: float, layer: Dictionary) -> float:
	var lo: float = layer["spawn_z_min"]
	var hi: float = layer["spawn_z_max"]
	var margin: float = (hi - lo) * _FADE_FRACTION
	if margin <= 0.0:
		return 1.0
	var fade_in: float = clampf((z - lo) / margin, 0.0, 1.0)
	var fade_out: float = clampf((hi - z) / margin, 0.0, 1.0)
	return minf(fade_in, fade_out)

## Builds one instance's Sprite3D once. Billboard cutout, not a mesh -- see
## the class doc for why this replaced the cone/ModelSlot approach.
## `cast_shadow` is switched off: these are background-only and sit far
## outside the readable play area, so they should not add to the one
## DirectionalLight3D's shadow pass (same reasoning the cones already
## applied).
##
## `render_priority` is set EXPLICITLY per layer (mountain furthest back,
## far hill next, near hill frontmost -- see _LAYERS) rather than left to
## Godot's automatic per-instance distance sort. Not fixing an observed
## bug (see the fog note in the class doc for what an early offscreen
## capture actually turned out to measure) -- this is a deliberate
## robustness choice: these three bands are a fixed visual stack by
## design, and leaving their draw order to a per-frame distance
## comparison invites flicker as instances scroll and recycle across
## layers' z-bands, where automatic sorting has no such stack to respect.
func _build_hill(layer: Dictionary) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = layer["texture"]
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.render_priority = int(layer["render_priority"])
	return sprite

## (Re)randomises one instance's size and position within its layer's
## ranges. `initial` spreads the very first fill evenly across the whole
## spawn range (so the layer looks populated from the first frame instead
## of clumped at the far edge); a recycle always returns to the far edge,
## exactly like TrackManager._recycle_segment placing a segment behind the
## furthest existing one.
func _place_hill(hill: Sprite3D, layer: Dictionary, initial: bool) -> void:
	var height_range: Vector2 = layer["height_range"]
	var target_height := _rng.randf_range(height_range.x, height_range.y)
	# pixel_size is world-metres-per-texture-pixel: scaling by target world
	# height over the texture's own pixel height scales both axes uniformly,
	# so the source image's aspect ratio (and therefore its width) is
	# preserved rather than independently randomised.
	var texture: Texture2D = hill.texture
	hill.pixel_size = target_height / float(texture.get_height())
	var x := _rng.randf_range(-float(layer["x_range"]), float(layer["x_range"]))
	var z: float
	if initial:
		z = _rng.randf_range(layer["spawn_z_min"], layer["spawn_z_max"])
	else:
		z = layer["spawn_z_min"]
	# Half the height, so the sprite -- centred on its own origin, same as
	# every other Sprite3D -- reads as standing on the ground plane (y = 0)
	# rather than straddling it. Same convention the cones used, kept for
	# continuity: the cropped source art has only a small, uniform margin of
	# transparent padding around its silhouette, so this is close enough for
	# background scenery that is never inspected up close.
	hill.position = Vector3(x, target_height * 0.5, z)
