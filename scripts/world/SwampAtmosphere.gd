extends Node
class_name SwampAtmosphere
## Drives the swamp's ATMOSPHERE -- the sky colour, the haze colour and the
## fog density -- between the two ends of the mist breath GameState reports
## (GameState.mist_intensity, 0..1).
##
## =====================================================================
## WHAT THIS REPLACES: DarkModeEffect.gd, AND THE WHOLE IDEA OF A PHASE
##
## Until the permanent-swamp batch this node was a CanvasLayer carrying a
## full-screen ColorRect, and the "dark mode" it rendered was a luminance-
## keyed grade (assets/shaders/swamp_grade.gdshader) faded in over a scene
## authored in daylight blue and pastel. Both the shader and the ColorRect
## are deleted. The swamp is not a phase any more: it is what the game
## looks like, authored directly into the materials, the environment and
## the decor, on the first frame of the first run.
##
## The full argument for deleting the grade -- it destroyed hue, so all six
## hazards rendered as the same olive, and it cost a framebuffer copy plus
## a full-screen pass for as long as it was on -- lives next to the palette
## it used to consume, in GameState's SWAMP ATMOSPHERE block, with the
## measured numbers. It is not repeated here.
##
## =====================================================================
## WHY THIS NODE STILL EXISTS AT ALL
##
## Because a still swamp is a flat one. The cycle GameState already owned
## (its timing constants are untouched by this batch) now moves the marsh's
## breath instead of switching identities: the mist thickens and the sky
## deepens, then eases back. Both ends are the same place -- see
## GameState.SWAMP_SKY / _DEEP, which are deliberately close.
##
## KEEPING the cycle rather than deleting it was the cheaper of the two
## options the brief allowed. Deleting it would have meant tearing the
## phase state machine out of GameState and rewriting every contrast probe
## that measures its two ends; keeping it and changing what it DRIVES is a
## smaller change that also leaves those probes measuring something better
## than they did before -- with one identity, they now check that the
## gameplay floors hold at BOTH ends of the breath rather than in two
## different-looking worlds.
##
## =====================================================================
## WHY IT IS SAFE TO ANIMATE THIS, AND ONLY THIS
##
## Everything this node writes is BACKDROP. fog_sky_affect is 0.0, so the
## sky colour is never fogged; and the gameplay zone sits within a few
## metres of the camera, where fog at these densities contributes almost
## nothing (measured when depth fog landed, and the reason it was allowed
## to ship at all). So no hazard, collectible, curb or silhouette changes
## colour as the breath moves, and every contrast figure in
## docs/MESHY_SPEC.md section 8 holds at both ends by construction rather
## than by luck. That is what makes a permanently-running cycle acceptable
## where a permanently-running screen grade was not.
##
## It is a plain Node, not a CanvasLayer: with the ColorRect gone there is
## nothing to draw, and this script issues no draw call, no screen copy and
## no allocation. Its whole per-frame cost is three property writes.

## The WorldEnvironment whose sky, haze and fog density follow the breath.
## A NodePath rather than a hard $"../World/WorldEnvironment" so a probe can
## host this node in a scene of its own shape without having to reproduce
## Game.tscn's tree.
@export var world_environment_path: NodePath = NodePath("../World/WorldEnvironment")

var _env: Environment = null

## Shallow-end values, READ FROM THE SCENE at _ready() and never hardcoded
## here: at mist_intensity == 0 this file must reproduce EXACTLY what
## Game.tscn ships, so the .tscn stays the single source of truth for the
## base look and the very first frame of a run is untouched by this script
## existing. GameState's SWAMP_SKY / SWAMP_HAZE / SWAMP_FOG_DENSITY name
## the same values so a probe can assert the baseline without parsing a
## scene file, but they are NOT what renders -- these are.
var _base_sky: Color = Color.BLACK
var _base_haze: Color = Color.BLACK
var _base_fog_density: float = 0.0

func _ready() -> void:
	var node := get_node_or_null(world_environment_path)
	var world_env := node as WorldEnvironment
	if world_env and world_env.environment:
		_env = world_env.environment
		_base_sky = _env.background_color
		_base_haze = _env.fog_light_color
		_base_fog_density = _env.fog_density

## Hands the environment back the way it was found.
##
## NOT belt-and-braces: Game.tscn's Environment is a SUB-RESOURCE, and a
## sub-resource is shared between instantiations of the same PackedScene
## unless it is marked local-to-scene. So the values this file writes can
## outlive the scene instance that wrote it. If a run were ever freed while
## the breath was at its deep end, the NEXT Game.tscn would read the deep
## values as its "shallow" baseline in _ready() and drift a little further
## every run -- a fault that compounds and would look like the swamp slowly
## closing in.
##
## In the shipped flow this cannot fire (state leaves PLAYING before the
## scene goes away, and _process restores the shallow values on that
## frame), which is exactly why it is worth pinning: an invariant that
## currently holds by luck of ordering is one refactor away from not
## holding.
func _exit_tree() -> void:
	if _env:
		_env.background_color = _base_sky
		_env.fog_light_color = _base_haze
		_env.fog_density = _base_fog_density

func _process(_delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		# The title and game-over screens sit at the shallow end. They are
		# still the swamp -- that is the whole point of this batch -- they
		# just do not breathe.
		_apply(0.0)
		return
	_apply(GameState.mist_intensity)

## Written DIRECTLY -- no pre-image, no second pass between this value and
## the screen. Nothing post-processes the frame any more, so the colour set
## here is the colour that reaches the player.
func _apply(intensity: float) -> void:
	if not _env:
		return
	_env.background_color = _base_sky.lerp(GameState.SWAMP_SKY_DEEP, intensity)
	_env.fog_light_color = _base_haze.lerp(GameState.SWAMP_HAZE_DEEP, intensity)
	_env.fog_density = lerpf(
		_base_fog_density, GameState.SWAMP_FOG_DENSITY_DEEP, intensity)
