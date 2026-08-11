shader_type canvas_item;
render_mode unshaded;

// Full-screen "swamp night" grade for dark mode (see
// scripts/world/DarkModeEffect.gd). REPLACES the per-channel colour
// inversion this project shipped until the swamp refonte, and the
// six-hue tint pass that used to blend on top of it.
//
// =====================================================================
// THE ONE PROPERTY THIS FILE EXISTS TO GUARANTEE
//
// THE COLOURS WRITTEN ARE THE COLOURS SEEN. A pixel whose luminance sits
// at a ramp stop comes out EXACTLY that stop's colour, at full intensity.
// Nothing downstream re-tints it, nothing upstream has to be written as a
// pre-image of anything.
//
// That is the whole reason the invert had to go, and it is worth stating
// as a property rather than as a preference, because the previous design
// violated it in a way that cost two failed attempts:
//
//   old: COLOR = mix(1.0 - src, tint, tint_amount * intensity)
//
// To land a chosen colour on screen you had to write `1.0 - colour` at
// the source and then hope the tint pass -- which contributed a fixed
// 55% of a saturated hue picked at random from six -- did not carry it
// somewhere else. It always did. scripts/world/NightSky.gd (deleted by
// this refonte) computed the pre-image correctly, said so in its own
// header, and STILL could not hit its target, because 55% of the final
// pixel was never its to control. Two of the six hues carried the whole
// frame back to blue, which is exactly what the swamp was meant to stop
// being.
//
// =====================================================================
// HOW IT WORKS: A LUMINANCE-KEYED RAMP, NOT A TINT
//
// Each pixel's luminance picks a colour out of an ordered four-stop
// swamp ramp (deepest shadow -> dirty olive -> pale sickly highlight);
// `intensity` blends the source toward that colour. Hue and saturation
// of the source are DISCARDED, which is the point: a swamp night is a
// narrow, unified palette, and anything that survives with its daytime
// hue intact reads as "the filter missed a spot".
//
// WHY LUMINANCE-KEYED RATHER THAN A BLEND TOWARD ONE COLOUR: a single
// mix() toward one swamp colour compresses everything toward that
// colour, so the darkest and brightest things on screen converge -- the
// flat, unreadable wash the old shader's own header worried about. A
// ramp keyed on luminance does the opposite: it is MONOTONE, so brighter
// stays brighter and the ordering the eye reads shapes by is preserved
// end to end.
//
// WHY THAT MONOTONICITY MATTERS MORE THAN IT SOUNDS: the invert did not
// merely recolour, it REVERSED the order. The pursuer's near-black
// silhouette (albedo 0.02) came out near-WHITE and was then read against
// a ground that had gone light blue -- which is the whole mechanism
// behind the 2.5:1 silhouette floor this project could never clear
// (measured 1.86:1 worst case across all six hues). Under this ramp the
// darkest thing on screen stays the darkest thing on screen, so the
// pursuer sits at the shadow stop and the ground it is read against sits
// well above it, by construction rather than by luck.
//
// LEGIBILITY GUARANTEE, stated as precisely as the old shader stated
// its own: this map is NOT injective -- two colours of equal luminance
// and different hue DO collapse to the same output. That is a real,
// deliberate trade, not an oversight: it is what buys the unified
// palette. What is preserved instead is the luminance ORDER, which is
// what carries shape reading at a glance for large fast-moving objects.
// Anything whose legibility rested on hue alone has to earn it back in
// value -- which is the same rule docs/MESHY_SPEC.md section 8 already
// imposes on every dark-mode-visible decor surface in this project
// ("hue does not survive, luminance does"), now enforced by the grade
// itself rather than left to each asset to remember.
//
// RENDERER NOTE: hint_screen_texture on a canvas_item shader is
// supported by the Compatibility renderer, which is what this project
// pins (project.godot renderer/rendering_method = "gl_compatibility").
// Unchanged from the shader this replaces, and re-verified by actually
// rendering it, not assumed from documentation.
//
// The ColorRect carrying this shader sits on a CanvasLayer with
// layer = 0, i.e. BELOW the HUD's layer 1. The screen texture it samples
// therefore holds the rendered 3D world only, and the HUD draws on top
// afterwards, ungraded: the world sinks into the swamp, the score stays
// readable.
//
// COLOUR SPACE, and why these are plain vec3 and NOT `source_color`:
// a `source_color` hint asks the engine to convert the value into
// whatever space the renderer works in. `screen_tex` here hands back
// framebuffer values, and COLOR is written straight back to that same
// framebuffer, so a converted uniform would be compared against
// unconverted pixels and the stop colours would NOT be the colours that
// land -- breaking the one property at the top of this file for a
// cosmetic editor colour-picker. DarkModeEffect.gd passes each stop as
// an explicit Vector3 of the Color's rgb for the same reason.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

// The four ramp stops, darkest to brightest. Set every frame from
// GameState.SWAMP_RAMP -- that array is the single place these colours
// are authored.
uniform vec3 stop_shadow = vec3(0.078, 0.106, 0.071);
uniform vec3 stop_low = vec3(0.227, 0.290, 0.188);
uniform vec3 stop_mid = vec3(0.361, 0.416, 0.267);
uniform vec3 stop_high = vec3(0.725, 0.745, 0.529);

// Source-luminance positions of stop_low and stop_mid. stop_shadow sits
// at 0.0 and stop_high at 1.0 by definition, so only the two interior
// knees are adjustable. Driven from GameState.SWAMP_KNEE_LOW / _MID,
// which is where the measured reasoning for their values lives.
uniform float knee_low : hint_range(0.01, 0.98) = 0.34;
uniform float knee_mid : hint_range(0.02, 0.99) = 0.72;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;

	// Rec.709 luma on the framebuffer values as they are, deliberately
	// NOT linearised first. This number is only ever used to POSITION a
	// pixel along the ramp -- it is not reported as a contrast figure and
	// nothing downstream reads it -- so what matters is that it is
	// monotone in brightness and cheap, both of which hold here. The
	// probes that DO report contrast (PursuerContrastAudit and its
	// siblings) compute proper WCAG relative luminance on the real
	// rendered pixels this shader outputs, which is the only place that
	// distinction would change an answer.
	float luma = dot(src, vec3(0.2126, 0.7152, 0.0722));

	// Piecewise-linear walk up the ramp. Ordered stops plus a monotone
	// key means the whole map is monotone, which is the property the
	// header leans on.
	vec3 graded;
	if (luma < knee_low) {
		graded = mix(stop_shadow, stop_low, luma / max(knee_low, 0.0001));
	} else if (luma < knee_mid) {
		graded = mix(stop_low, stop_mid, (luma - knee_low) / max(knee_mid - knee_low, 0.0001));
	} else {
		graded = mix(stop_mid, stop_high, (luma - knee_mid) / max(1.0 - knee_mid, 0.0001));
	}

	// intensity is GameState.dark_intensity, so the fade in and out is a
	// lerp of HOW GRADED the frame is (0 = untouched daytime, 1 = fully
	// in the swamp). Same shape as the value the old shader faded, so the
	// cycle timing in GameState is untouched by this refonte -- only what
	// the end state looks like changed.
	COLOR = vec4(mix(src, graded, intensity), 1.0);
}
