shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

// Blob shadow under a prop (carte-blanche). A PlaneMesh quad lying just
// above the ground with a radial alpha falloff: the cheapest way to make
// a tree, a rock or a bush read as STANDING ON the ground rather than
// floating on a flat colour. No light, no shadow map, one alpha quad.

uniform vec4 colour : source_color = vec4(0.16, 0.30, 0.12, 0.34);
uniform float edge = 0.55;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	float a = 1.0 - smoothstep(edge, 1.0, r);
	ALBEDO = colour.rgb;
	ALPHA = colour.a * a;
}
