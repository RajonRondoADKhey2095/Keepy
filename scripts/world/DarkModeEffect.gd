extends WorldEnvironment
class_name DarkModeEffect
## Fades a desaturated/darkened screen-wide "dark mode" over the run's
## existing WorldEnvironment as GameState.current_speed climbs past
## GameState.DARK_MODE_SPEED_THRESHOLD -- a visual palier communicating
## "you are now running at a genuinely dangerous speed", as a multi-second
## fade rather than a hard on/off flash.
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

# Fraction of GameState.MAX_SPEED at which DARK_MODE_SPEED_THRESHOLD sits
# lives in GameState.gd (single source of truth for anything speed-
# related) -- this script only reads GameState.current_speed/MAX_SPEED/
# DARK_MODE_SPEED_THRESHOLD at runtime, never redeclares them.

# Exponential fade time constant (same pattern as Keepy.gd's lane lerp):
# ~1/FADE_RATE seconds to close 63% of the gap to the target intensity.
# Deliberately slow -- a multi-second creep, never a flash, and
# reversible (see _process): if current_speed ever drops back below the
# threshold, the same lerp fades the effect back out just as smoothly.
const FADE_RATE: float = 1.0

const NORMAL_BRIGHTNESS: float = 1.0
const NORMAL_CONTRAST: float = 1.0
const NORMAL_SATURATION: float = 1.0
# Chosen conservatively for legibility: darkened and desaturated, not
# black-and-inverted -- obstacles/collectibles must stay distinguishable
# at full intensity (see class doc above).
const DARK_BRIGHTNESS: float = 0.55
const DARK_CONTRAST: float = 1.25
const DARK_SATURATION: float = 0.2

var _intensity: float = 0.0

func _process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return

	var target := clampf(
		(GameState.current_speed - GameState.DARK_MODE_SPEED_THRESHOLD)
			/ (GameState.MAX_SPEED - GameState.DARK_MODE_SPEED_THRESHOLD),
		0.0, 1.0
	)
	_intensity = lerpf(_intensity, target, 1.0 - exp(-FADE_RATE * delta))
	_apply(_intensity)

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
