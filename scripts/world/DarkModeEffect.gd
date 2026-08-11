extends CanvasLayer
class_name DarkModeEffect
## Renders the "swamp night" dark mode at the intensity GameState
## currently reports (GameState.dark_intensity, 0..1) -- a repeating
## dark/light cycle that starts once the run reaches its "fast" palier.
##
## This node owns NO timing of its own: when the cycle starts, how long
## each phase lasts and how fast the fade moves all live in GameState
## (see its DARK_CYCLE_PERIOD_S / DARK_FADE_DURATION_S), untouched by the
## swamp refonte. Splitting the fade across both files is how an earlier
## iteration ended up with a visual state nobody could point at a single
## source for.
##
## =====================================================================
## WHAT THE EFFECT IS NOW, AND WHAT IT REPLACED
##
## A full-screen luminance-keyed GRADE into a fixed swamp palette --
## see assets/shaders/swamp_grade.gdshader. Every pixel is placed on a
## four-stop ramp by its brightness and comes out the corresponding
## swamp colour.
##
## It replaces a per-channel INVERSION (1.0 - rgb) with one of six
## saturated hues blended over it at 55%. That system is gone entirely,
## along with GameState.DARK_VARIANTS and DARK_TINT_AMOUNT. The reason
## is worth keeping close to the code, because it cost two failed
## attempts to establish: under the old pipeline THE COLOUR YOU WROTE
## WAS NEVER THE COLOUR THAT LANDED. A surface had to be authored as the
## pre-image of its target (1.0 - target) so the invert would undo it,
## and then a randomly-picked hue moved it again by 55% anyway. Two of
## the six hues carried the whole frame back to blue, which is what a
## device playtest kept reporting even after two rounds of fixes aimed
## at the sky specifically. There was no value anyone could have written
## into those files that would have worked.
##
## =====================================================================
## THIS FILE OWNS THE WHOLE NIGHT LOOK, ON PURPOSE
##
## Two things move when a dark phase comes in, and they are both driven
## from here rather than from separate scripts:
##
##   THE SCREEN GRADE -- the shader above, covering every rendered pixel.
##   THE ATMOSPHERE   -- Environment.background_color / fog_light_color,
##                       written DIRECTLY to GameState.SWAMP_SKY/_HAZE.
##
## WHY BOTH ARE NEEDED, rather than picking one: neither covers the
## other's ground.
##
##   The screen grade alone cannot give a near-black sky. It is keyed on
##   luminance, and the daytime sky is one of the BRIGHTEST things in
##   frame, so it grades to a pale midtone olive -- a washed-out swamp
##   sky, not the near-black one the look calls for. Darkening the sky at
##   its source is what drops it to the bottom of the ramp.
##
##   Driving the environment alone cannot darken the gameplay objects.
##   This project's imported assets are deliberately UNLIT
##   (KHR_materials_unlit -- the pursuer, Keepy, the trackside props;
##   Decor.gd's three billboard layers are shaded = false for the same
##   reason). An unlit surface ignores lighting and ambient entirely, so
##   dimming or tinting the world's lights would leave every one of them
##   at full daytime brightness against a black sky. Only a screen-space
##   pass reaches them.
##
## WHY ONE FILE AND NOT THREE: the deleted NightSky.gd and DepthFog.gd
## split this across three scripts with three disjoint property sets, on
## the argument that one node carries one script. The argument was sound
## and the result still failed, because "what does the night look like"
## had no single owner -- each file could be individually correct while
## the composite was wrong, which is exactly what happened. A CanvasLayer
## can hold a NodePath to the WorldEnvironment just as easily as a script
## can sit on it, so the split bought nothing that a reference does not.
##
## COST: the ColorRect is hidden outright whenever the intensity is at
## the floor (see _apply), which is most of a run. A hidden canvas item
## is not drawn, so no screen-texture copy is issued either -- the "pay
## nothing while the effect is off" property is preserved.
##
## LEGIBILITY: the grade is MONOTONE in luminance -- brighter stays
## brighter -- which is a stronger guarantee for shape reading than the
## invert offered. The invert preserved per-channel DIFFERENCES but
## REVERSED the order, which is what put the pursuer's near-black
## silhouette on screen as near-white against a light-blue ground and
## kept it permanently under its 2.5:1 floor. See the shader's header for
## the full argument and for what the grade trades away in exchange
## (hue: equal-luminance colours do collapse together).

## Below this intensity the effect is switched off entirely rather than
## drawn at a near-identity value.
const INTENSITY_EPSILON: float = 0.001

## The WorldEnvironment whose sky and haze colours follow the dark cycle.
## A NodePath rather than a hard $"../World/WorldEnvironment" so a probe
## can host this node in a scene of its own shape without having to
## reproduce Game.tscn's tree.
@export var world_environment_path: NodePath = NodePath("../World/WorldEnvironment")

@onready var _rect: ColorRect = $Grade

var _env: Environment = null
## Day values, READ FROM THE SCENE at _ready() and never hardcoded here:
## at dark_intensity == 0 this file must reproduce EXACTLY what Game.tscn
## ships, so the .tscn stays the single source of truth for the daytime
## look and the very first frame of a run is untouched by this script
## existing. Same rule the deleted NightSky.gd got right and is worth
## keeping.
var _day_sky: Color = Color.BLACK
var _day_haze: Color = Color.BLACK

func _ready() -> void:
	var node := get_node_or_null(world_environment_path)
	var world_env := node as WorldEnvironment
	if world_env and world_env.environment:
		_env = world_env.environment
		_day_sky = _env.background_color
		_day_haze = _env.fog_light_color

## Hands the environment back the way it was found.
##
## NOT belt-and-braces: Game.tscn's Environment is a SUB-RESOURCE, and a
## sub-resource is shared between instantiations of the same PackedScene
## unless it is marked local-to-scene. So the sky colour this file writes
## can outlive the scene instance that wrote it. If a run were ever freed
## while a dark phase was in flight, the NEXT Game.tscn would read a
## swamp-tinted sky as its "day" baseline in _ready() and never be able to
## get back to daylight -- a fault that compounds run over run and would
## look like the dark mode slowly eating the game.
##
## In the shipped flow this cannot fire (state leaves PLAYING before the
## scene goes away, and _process restores the day values on that frame),
## which is exactly why it is worth pinning: an invariant that currently
## holds by luck of ordering is one refactor away from not holding.
func _exit_tree() -> void:
	if _env:
		_env.background_color = _day_sky
		_env.fog_light_color = _day_haze

func _process(_delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		# A run that ends mid-dark-phase must not leave the swamp burned
		# into the title / game over screens.
		_apply(0.0)
		return
	_apply(GameState.dark_intensity)

func _apply(intensity: float) -> void:
	_apply_atmosphere(intensity)
	if not _rect:
		return
	var active := intensity > INTENSITY_EPSILON
	_rect.visible = active
	if not active:
		return
	var mat: ShaderMaterial = _rect.material
	if not mat:
		return
	mat.set_shader_parameter("intensity", intensity)
	# The ramp is pushed every frame rather than baked into the .tscn's
	# ShaderMaterial so GameState stays the ONE place these colours are
	# authored -- editing the night means editing four constants there and
	# nothing else, which is the property this refonte exists to create.
	#
	# Passed as explicit Vector3 of the Color's rgb, NOT as a Color: the
	# uniforms are plain vec3 (not `source_color`) precisely so no colour
	# space conversion sits between the value written and the value
	# blended against framebuffer pixels. See the shader's header.
	mat.set_shader_parameter("stop_shadow", _rgb(GameState.SWAMP_SHADOW))
	mat.set_shader_parameter("stop_low", _rgb(GameState.SWAMP_LOW))
	mat.set_shader_parameter("stop_mid", _rgb(GameState.SWAMP_MID))
	mat.set_shader_parameter("stop_high", _rgb(GameState.SWAMP_HIGH))
	mat.set_shader_parameter("knee_low", GameState.SWAMP_KNEE_LOW)
	mat.set_shader_parameter("knee_mid", GameState.SWAMP_KNEE_MID)

## Sky and distance haze, written DIRECTLY -- no pre-image, no second
## pass between this value and the screen. This is the single line of
## difference from the deleted NightSky.gd that makes the swamp reachable
## at all.
func _apply_atmosphere(intensity: float) -> void:
	if not _env:
		return
	_env.background_color = _day_sky.lerp(GameState.SWAMP_SKY, intensity)
	_env.fog_light_color = _day_haze.lerp(GameState.SWAMP_HAZE, intensity)

func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
