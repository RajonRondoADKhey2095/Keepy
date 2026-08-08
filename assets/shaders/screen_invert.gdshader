shader_type canvas_item;
render_mode unshaded;

// Full-screen "x-ray" colour inversion for dark mode (see
// scripts/world/DarkModeEffect.gd). Straight per-channel negative --
// 1.0 - rgb -- with NO blur and NO added desaturation, so the result
// stays sharp and high-contrast rather than washed out.
//
// RENDERER NOTE: hint_screen_texture on a canvas_item shader is
// supported by the Compatibility renderer, which is what this project
// pins (project.godot renderer/rendering_method = "gl_compatibility").
// Verified by actually rendering it -- see the dark mode section of
// scripts/dev/PacingProbe.gd's sibling capture run in the commit
// message, not assumed from documentation.
//
// The ColorRect carrying this shader sits on a CanvasLayer with
// layer = 0, i.e. BELOW the HUD's layer 1. The screen texture it samples
// therefore holds the rendered 3D world only, and the HUD draws on top
// afterwards, un-inverted: the world flips, the score stays readable.
//
// PALETTE VARIANTS (difficulty+variety batch): a second, independent
// pass -- `tint_color`/`tint_amount`, driven from GameState's per-DARK-
// phase variant pick, see DarkModeEffect.gd -- blends the ALREADY
// inverted result toward a fixed tint colour. This keeps the same
// legibility guarantee the plain invert already had, for a different,
// stronger reason: `mix(inverted, tint, amount)` is, per pixel, the
// AFFINE map `inverted * (1 - amount) + tint * amount`. Since `tint` and
// `amount` are the SAME constant for every pixel on screen, this map is
// INJECTIVE for any `amount < 1` -- two different colours can never be
// mapped to the same output colour, so nothing that was distinguishable
// before this pass becomes indistinguishable after it, for ANY tint or
// amount short of 1.0 (a mathematical guarantee, not a spot check).
// `amount` is kept well under that ceiling (see DarkModeEffect.gd's
// TINT_AMOUNT) specifically so the SIZE of every difference only shrinks
// by a bounded, modest fraction, not just "stays nonzero" -- staying
// perceptually strong, not merely technically distinct.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint_color : source_color = vec3(1.0);
uniform float tint_amount : hint_range(0.0, 0.9) = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	// intensity is driven from GameState.dark_intensity, so the fade in
	// and out is a lerp of the INVERSION AMOUNT (0 = untouched, 1 = full
	// negative) rather than a fade to a fixed dark colour -- the
	// transition is smooth while the end state stays fully inverted and
	// sharp.
	vec3 inverted = mix(src, vec3(1.0) - src, intensity);
	// Multiplying the tint blend by `intensity` (not just gating
	// `tint_amount` on/off) makes the tint fade in/out in the SAME
	// lockstep curve as the invert itself, driven by the one shared
	// GameState.dark_intensity value -- DarkModeEffect only ever sets
	// `tint_amount` to a constant per-variant strength, this is what
	// turns that into a smooth fade instead of a pop.
	COLOR = vec4(mix(inverted, tint_color, tint_amount * intensity), 1.0);
}
