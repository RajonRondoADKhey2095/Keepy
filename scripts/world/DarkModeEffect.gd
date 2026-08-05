extends WorldEnvironment
class_name DarkModeEffect
## Renders the screen-wide "dark mode" at the intensity GameState
## currently reports (GameState.dark_intensity, 0..1) -- a repeating
## dark/light cycle that starts once the run reaches its "fast" palier.
##
## This node owns NO timing of its own: when the cycle starts, how long
## each phase lasts and how fast the fade moves all live in GameState
## (see its DARK_CYCLE_PERIOD_S / DARK_FADE_DURATION_S). Splitting the
## fade across both files is how the previous iteration ended up with a
## visual state nobody could point at a single source for.
##
## WHY THE EXISTING WorldEnvironment's Adjustments INSTEAD OF A NEW
## CanvasLayer/ColorRect + hint_screen_texture SHADER (this is the
## project's first full-screen visual effect, so the choice is
## documented rather than assumed):
##
## - `environment.adjustment_enabled` (brightness/contrast/saturation/
##   color_correction) runs as part of Godot's tonemap pass, which EVERY
##   renderer backend already executes once per frame regardless of scene
##   content -- including gl_compatibility (project.godot pins
##   renderer/rendering_method = "gl_compatibility"). This is NOT one of
##   the Forward+/Mobile-exclusive screen effects (Glow pre-4.3, SSAO,
##   SSR, SDFGI, volumetric fog); Adjustments has no such restriction.
##   Piggybacking on a pass that already runs costs zero *additional*
##   draw calls or texture copies.
## - A ColorRect + shader with `hint_screen_texture` would instead need
##   an EXTRA full-screen SCREEN_TEXTURE read every frame on top of that
##   existing pass -- meaningfully heavier for mobile Safari/WebGL, for
##   no visual benefit here (see the "reste simple" perf constraint).
## - Game.tscn already has a WorldEnvironment node wired up (for the sky
##   color / ambient light) -- reusing it needs no new scene node.
##
## Adjustments has no true per-pixel color invert (only brightness/
## contrast/saturation/a color-correction LUT), so "inversion" was
## deliberately NOT used even though it was floated as an option: an
## inverted obstacle/collectible palette risks becoming *harder* to read
## right when reflexes matter most (see the enemy tension redesign in
## Obstacle.gd), which would turn an ambience effect into a legibility
## handicap. Desaturate + darken + a contrast bump for edge definition
## reads as "ominous" while keeping color relationships (mostly) intact.

const NORMAL_BRIGHTNESS: float = 1.0
const NORMAL_CONTRAST: float = 1.0
const NORMAL_SATURATION: float = 1.0
# Chosen conservatively for legibility: darkened and desaturated, not
# black-and-inverted -- obstacles/collectibles must stay distinguishable
# at full intensity (see class doc above).
const DARK_BRIGHTNESS: float = 0.55
const DARK_CONTRAST: float = 1.25
const DARK_SATURATION: float = 0.2

func _process(_delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		# A run that ends mid-dark-phase must not leave the effect
		# burned into the title/game-over screens.
		_apply(0.0)
		return
	_apply(GameState.dark_intensity)

func _apply(intensity: float) -> void:
	if not environment:
		return
	# Cheap early-out: skip the Adjustments pass entirely while its
	# effect would be imperceptible, instead of always running it at
	# identity values -- keeps the common case (speed below threshold,
	# most of a run given DARK_MODE_SPEED_THRESHOLD's placement) at zero
	# extra cost rather than paying for an always-on neutral pass.
	environment.adjustment_enabled = intensity > 0.001
	if not environment.adjustment_enabled:
		return
	environment.adjustment_brightness = lerpf(NORMAL_BRIGHTNESS, DARK_BRIGHTNESS, intensity)
	environment.adjustment_contrast = lerpf(NORMAL_CONTRAST, DARK_CONTRAST, intensity)
	environment.adjustment_saturation = lerpf(NORMAL_SATURATION, DARK_SATURATION, intensity)
