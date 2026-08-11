shader_type canvas_item;
// Screen-edge vignette whose strength tracks how close the pursuer is.
//
// WHY A VIGNETTE AND NOT ONLY A GAUGE: the brief for this cue is that the
// player must always know roughly how close the thing behind them is
// WITHOUT looking away from the track ahead. A gauge answers the question
// precisely but only once you look at it; darkening the screen edges is
// read peripherally, which is the half of the job a gauge cannot do. Both
// ship -- see HUD.gd.
//
// Deliberately trivial maths (one length, one smoothstep, no loops, no
// derivatives, no texture reads beyond the implicit one) to stay well
// inside gl_compatibility on mobile Safari, which is the renderer this
// project targets.
//
// This draws in the HUD's CanvasLayer, the only canvas layer in the scene,
// so it is never itself inverted or tinted by the dark cycle -- its colour
// is the same known value in every palette. That is why the tint can be a
// fixed hostile red rather than something derived per palette.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.62, 0.03, 0.12, 1.0);
// Fraction of the way to the corner at which the darkening starts. Well
// under 1.0 so the effect is a soft gradient rather than a hard ring.
uniform float inner_radius : hint_range(0.0, 1.0) = 0.30;
// Y is squashed because the viewport is portrait (1080x1920, see
// project.godot): without it the vignette would be a tall ellipse that
// barely touches the left and right edges, which are the edges peripheral
// vision actually uses.
uniform float y_squash : hint_range(0.1, 1.0) = 0.55;

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * vec2(1.0, y_squash);
	float d = clamp(length(centered) * 2.0, 0.0, 1.0);
	float falloff = smoothstep(inner_radius, 1.0, d);
	COLOR = vec4(tint.rgb, falloff * intensity);
}
