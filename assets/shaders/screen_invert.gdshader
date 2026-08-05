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

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	// intensity is driven from GameState.dark_intensity, so the fade in
	// and out is a lerp of the INVERSION AMOUNT (0 = untouched, 1 = full
	// negative) rather than a fade to a fixed dark colour -- the
	// transition is smooth while the end state stays fully inverted and
	// sharp.
	COLOR = vec4(mix(src, vec3(1.0) - src, intensity), 1.0);
}
