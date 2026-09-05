shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

// Carte-blanche water. Two tones mixed by a scrolling seamless noise
// (the same NoiseTexture2D the ground uses), thin bright bands where the
// noise crests (reads as light on ripples), a foam rim at the disc's edge
// when `radius` is set (model-space radius of the CylinderMesh disc; the
// stream ribbon passes 0 and gets no rim), and the hand-written haze.
// Alpha is kept so the bank disc under it shows through, exactly as the
// StandardMaterial3D it replaces did.

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 shallow : source_color = vec4(0.56, 0.86, 0.90, 0.80);
uniform vec4 deep : source_color = vec4(0.34, 0.72, 0.84, 0.86);
uniform vec3 foam : source_color = vec3(0.96, 0.99, 1.0);
uniform float radius = 0.0;
// 1.0 for the stream ribbon: the foam rim reads the lateral UV.x (0 = left
// bank, 1 = right bank) instead of a disc radius.
uniform float ribbon = 0.0;
uniform float ripple_scale = 11.0;
uniform float speed = 0.025;
uniform vec3 haze_color : source_color = vec3(0.78, 0.88, 0.94);
uniform float haze_density = 0.018;
uniform float haze_start = 6.0;
// v2 weather: global light and rain (faster, tighter ripples, greyer and
// more opaque water -- reads as risen -- with drop rings).
uniform vec3 weather_tint = vec3(1.0, 1.0, 1.0);
uniform float rain = 0.0;

varying vec3 world_pos;
varying vec3 model_pos;
varying vec3 view_pos;
varying float lateral;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	model_pos = VERTEX;
	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lateral = UV.x;
}

void fragment() {
	float spd = speed * (1.0 + rain * 3.0);
	vec2 p = world_pos.xz / (ripple_scale / (1.0 + rain * 0.7));
	float n1 = texture(noise_tex, p + vec2(TIME * spd, TIME * spd * 0.7)).r;
	float n2 = texture(noise_tex, p * 1.9 - vec2(TIME * spd * 0.8, -TIME * spd * 0.5)).r;
	float n = (n1 + n2) * 0.5;
	vec4 col = mix(deep, shallow, smoothstep(0.36, 0.66, n));
	if (rain > 0.0) {
		vec4 grey = vec4(0.46, 0.55, 0.62, 0.95);
		col = mix(col, grey, rain * 0.65);
		// Drop rings: thin bands of a fast third octave.
		float n3 = texture(noise_tex, world_pos.xz / 2.2 + vec2(TIME * 0.35, -TIME * 0.27)).r;
		float ring = smoothstep(0.50, 0.52, n3) * (1.0 - smoothstep(0.54, 0.58, n3));
		col.rgb = mix(col.rgb, foam, ring * rain * 0.55);
	}
	// Thin crest lines, kept faint: a busy caustic pattern reads as noise
	// from this camera height (measured on the first capture).
	float spark = smoothstep(0.600, 0.615, n) * (1.0 - smoothstep(0.635, 0.655, n));
	col.rgb = mix(col.rgb, foam, spark * 0.22);
	if (radius > 0.0) {
		float r = length(model_pos.xz) / radius + (n - 0.5) * 0.05;
		float rim = smoothstep(0.90 - rain * 0.10, 0.985, r);
		col.rgb = mix(col.rgb, foam, rim * 0.75);
		col.a = mix(col.a, 0.92, rim);
	} else if (ribbon > 0.5) {
		float e = abs(lateral * 2.0 - 1.0) + (n - 0.5) * 0.10;
		float rim = smoothstep(0.72 - rain * 0.16, 0.96, e);
		col.rgb = mix(col.rgb, foam, rim * 0.70);
		col.a = mix(col.a, 0.92, rim);
	}
	float dist = max(length(view_pos) - haze_start, 0.0);
	float haze = 1.0 - exp(-dist * haze_density);
	ALBEDO = mix(col.rgb * weather_tint, haze_color, haze);
	ALPHA = col.a;
}
