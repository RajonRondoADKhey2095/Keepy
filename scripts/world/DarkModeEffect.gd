extends CanvasLayer
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
## THE EFFECT: a straight per-channel colour inversion (1.0 - rgb) of the
## rendered frame -- see assets/shaders/screen_invert.gdshader. Sharp and
## high-contrast, no blur, no desaturation. This replaces an earlier
## desaturate+darken pass driven through the WorldEnvironment's
## Adjustments, which read as murky rather than as an event.
##
## WHY A CanvasLayer + ColorRect + hint_screen_texture RATHER THAN THE
## WorldEnvironment Adjustments IT REPLACES: Adjustments only exposes
## brightness / contrast / saturation / a colour-correction LUT. It has
## no per-pixel invert at all, so the effect asked for here is simply not
## expressible through it. Sampling the screen texture is the only way to
## get a true negative.
##
## COST: the ColorRect is hidden outright whenever the intensity is at
## the floor (see _apply), which is most of a run. A hidden canvas item
## is not drawn, so no screen-texture copy is issued either -- the
## "pay nothing while the effect is off" property of the previous
## implementation is preserved rather than traded away.
##
## LEGIBILITY UNDER FULL INVERSION: a per-channel negative is a bijection
## that preserves the absolute per-channel difference between any two
## colours (|(1-a) - (1-b)| == |a - b|), so no two things that were
## distinguishable become less so -- the palette shifts wholesale, it
## does not flatten. Checked against the actual gameplay albedos rather
## than assumed; see the commit message for the measured pairs.

## Below this intensity the effect is switched off entirely rather than
## drawn at a near-identity value.
const INTENSITY_EPSILON: float = 0.001

@onready var _rect: ColorRect = $Invert

func _process(_delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		# A run that ends mid-dark-phase must not leave the effect
		# burned into the title / game over screens.
		_apply(0.0)
		return
	_apply(GameState.dark_intensity)

func _apply(intensity: float) -> void:
	if not _rect:
		return
	var active := intensity > INTENSITY_EPSILON
	_rect.visible = active
	if not active:
		return
	var mat: ShaderMaterial = _rect.material
	if mat:
		mat.set_shader_parameter("intensity", intensity)
		# Palette variety (difficulty+variety batch): which of
		# GameState.DARK_VARIANTS the CURRENT dark phase picked, at a
		# fixed strength (DARK_TINT_AMOUNT) -- the shader itself
		# multiplies this by `intensity` every frame, so it fades in/out
		# in lockstep with the invert rather than needing a second fade
		# curve computed here. See the shader's own comment for why this
		# can never reduce legibility below a known, bounded floor.
		mat.set_shader_parameter("tint_color", GameState.DARK_VARIANTS[GameState.dark_variant_index])
		mat.set_shader_parameter("tint_amount", GameState.DARK_TINT_AMOUNT)
