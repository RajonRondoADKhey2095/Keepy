shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Carte-blanche v2 -- rain streaks and snowflakes. One MultiMesh of small
// quads in a box that follows Keepy; everything is in the vertex shader
// (same family as the butterflies): INSTANCE_CUSTOM = (phase, x-jitter,
// z-jitter, size). Position wraps with fract() so the box is always full.
// `rain` and `snow` are 0..1 weights: a drop is a thin vertical streak
// falling fast, a flake a small square drifting slowly; the quad is
// collapsed when neither is on.

uniform float rain = 0.0;
uniform float snow = 0.0;
uniform vec3 weather_tint = vec3(1.0, 1.0, 1.0);
uniform float box_height = 9.0;
uniform float box_half = 7.0;
uniform vec4 rain_color : source_color = vec4(0.80, 0.88, 1.0, 0.55);
uniform vec4 snow_color : source_color = vec4(0.98, 0.99, 1.0, 0.95);

varying float kind;

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float jx = INSTANCE_CUSTOM.y;
	float jz = INSTANCE_CUSTOM.z;
	float size = INSTANCE_CUSTOM.w;
	float active = clamp(rain + snow, 0.0, 1.0);
	kind = snow / max(rain + snow, 0.001);
	float fall_speed = mix(1.1, 9.0, 1.0 - kind);
	float t = fract(phase + TIME * fall_speed / box_height);
	float y = box_height * (1.0 - t);
	float drift = kind * (sin(TIME * 0.9 + phase * 40.0) * 0.6 + sin(TIME * 1.7 + phase * 13.0) * 0.25);
	vec3 centre = vec3((jx * 2.0 - 1.0) * box_half + drift, y, (jz * 2.0 - 1.0) * box_half);
	// Quad in model space is a unit square in xy centred at the origin;
	// stretch it into a streak (rain) or keep it small (snow), and face the
	// camera around y.
	vec2 sz = mix(vec2(0.018, 0.55) * size, vec2(0.07, 0.07) * size, kind);
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 pos = centre + right * VERTEX.x * sz.x + vec3(0.0, VERTEX.y * sz.y, 0.0);
	VERTEX = pos * active;
}

void fragment() {
	vec4 c = mix(rain_color, snow_color, kind);
	float edge = 1.0 - smoothstep(0.35, 0.5, abs(UV.x - 0.5));
	ALBEDO = c.rgb * weather_tint;
	ALPHA = c.a * mix(edge, 1.0, kind);
}
