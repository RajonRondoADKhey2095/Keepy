extends WorldEnvironment
class_name NightSky
## Fades the scene's flat sky colour (Environment.background_color) and
## fog haze colour (Environment.fog_light_color) toward a "swamp at
## night" palette as GameState.dark_intensity rises. This is the ONLY
## thing this file owns.
##
## SCOPE, DELIBERATELY NARROW: this does NOT touch DarkModeEffect.gd,
## assets/shaders/screen_invert.gdshader, or GameState.DARK_VARIANTS /
## DARK_TINT_AMOUNT. All three stay exactly as they were -- a full-screen
## per-channel colour inversion, then one of six saturated tints blended
## on top (see DarkModeEffect.gd's own header for that system). This
## file changes an UPSTREAM input to that unmodified pipeline, the same
## way recolouring any other mesh in the scene would.
##
## WHY THE CONSTANTS BELOW LOOK LIKE THE INVERSE OF A SWAMP COLOUR, NOT A
## SWAMP COLOUR: DarkModeEffect's invert samples the WHOLE rendered frame
## every frame it is active -- sky pixels included, it owns no exception
## for "the sky" (see that file's header: it captures whatever was
## drawn). Since inversion is `1.0 - channel`, writing a swamp colour
## directly into background_color would come out the far end of that
## pipeline LIGHT and washed-out -- the opposite of what was asked for.
## NIGHT_SKY / NIGHT_FOG below are therefore the PRE-IMAGE: 1.0 minus the
## actual on-screen swamp target (see the target comments next to each),
## chosen so the colour that reaches the player's eye, once the
## (unmodified) invert step has run, approximates that target. Same
## technique GameState.DARK_VARIANTS already uses for its own tints (see
## that array's comment) -- applied here to a second, independent value.
##
## THIS ONLY LANDS EXACTLY ON TARGET WHEN THE TINT CONTRIBUTION IS ZERO.
## The real on-screen formula (screen_invert.gdshader) is
## `mix(invert(src), tint_color, tint_amount * intensity)` -- at full
## dark intensity the swamp base computed here only carries the
## remaining `1 - tint_amount` (45%) of the final blend; the other 55%
## is whichever of the six DARK_VARIANTS hues is active that phase (see
## GameState.gd). That is unavoidable without touching the tint system,
## which is explicitly out of scope here -- the practical effect is a
## consistent boggy/murky UNDERTONE under every phase's own colour,
## instead of the current inverted-blue undertone, not a guarantee that
## the sky is EXACTLY these hex values regardless of which phase is
## showing. First pass, to be judged on a real capture, not assumed
## correct from the numbers alone.
##
## SKY vs FOG, why two different colours: background_color is the flat
## fill behind everything (background_mode = 1, no procedural sky) --
## reserved for the darkest, most desaturated end of the palette. Distant
## geometry (hills, track) fades toward fog_light_color as it recedes
## (see Decor.gd's own comment on that convergence), which is what most
## of a frame actually reads as -- so it carries the warmer, muddier
## "dominant" tone instead of the flat colour, giving the haze a boggy
## cast rather than a flat wash.
##
## DAY VALUES ARE READ FROM THE SCENE AT _ready(), NEVER HARDCODED HERE:
## at dark_intensity == 0 this script must reproduce EXACTLY what
## Game.tscn already ships (Environment_1.background_color /
## .fog_light_color) so the very first frame of a run -- before dark
## mode has ever fired -- is pixel-identical to before this file
## existed. Copying the two colours out of the live Environment once
## (rather than re-typing them a second time) is what guarantees that:
## the .tscn stays the single source of truth for the day sky.

## On-screen target once the invert step has run: base swamp colour,
## very dark, desaturated green-grey approaching black. ~#141B12,
## midpoint of the requested #0F140D..#1A2216 zone.
const NIGHT_SKY_ONSCREEN_HEX: String = "#141B12"
## Pre-image fed to Environment.background_color: 1.0 - the target above.
const NIGHT_SKY := Color(0.9196, 0.8941, 0.9314)

## On-screen target once the invert step has run: dominant dirty
## olive-green haze, warmed toward the requested muddy-brown accent
## (#4A4535) rather than a fresh/saturated green. ~#444F35, inside the
## requested #3A4A30..#4A5D3A zone.
const NIGHT_FOG_ONSCREEN_HEX: String = "#444F35"
## Pre-image fed to Environment.fog_light_color: 1.0 - the target above.
const NIGHT_FOG := Color(0.7318, 0.6896, 0.7922)

var _day_sky: Color
var _day_fog: Color

func _ready() -> void:
	_day_sky = environment.background_color
	_day_fog = environment.fog_light_color

func _process(_delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		# Mirror DarkModeEffect.gd's own rule: a run that ends mid-dark-
		# phase must not leave the swamp sky burned into the title /
		# game over screens.
		environment.background_color = _day_sky
		environment.fog_light_color = _day_fog
		return
	# dark_intensity already owns the fade curve and cycle timing
	# (GameState.DARK_FADE_DURATION_S / DARK_CYCLE_PERIOD_S) -- this
	# file adds no timing of its own, it only re-targets the colour that
	# curve fades toward, same as DarkModeEffect.gd reads the same value
	# to drive the invert/tint shader.
	var t := GameState.dark_intensity
	environment.background_color = _day_sky.lerp(NIGHT_SKY, t)
	environment.fog_light_color = _day_fog.lerp(NIGHT_FOG, t)
