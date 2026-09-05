shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled;

// Carte-blanche ground shader (branch claude/carte-blanche-cozy).
//
// The plateau ground is ONE 600x600 quad. Everything below is computed per
// fragment from the WORLD position, so the single quad is enough: two
// scales of noise (a seamless NoiseTexture2D sampled twice, never a
// procedural noise in the fragment -- a texture fetch is what a mobile GPU
// is fast at) mix three greens into soft patches, a faint clover/dirt
// speckle keeps the near ground from reading as flat, and a hand-written
// exponential haze pulls the far ground toward the sky colour so the
// horizon closes without depending on the engine fog (not functional on
// WebGL2, Godot #97875 / #92019).

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 grass_a : source_color = vec3(0.56, 0.78, 0.36);
uniform vec3 grass_b : source_color = vec3(0.44, 0.70, 0.32);
uniform vec3 grass_c : source_color = vec3(0.66, 0.82, 0.40);
uniform vec3 dirt : source_color = vec3(0.70, 0.60, 0.40);
// World-space repeat lengths of the two noise octaves, in units.
uniform float patch_scale = 26.0;
uniform float detail_scale = 5.5;
uniform float detail_amount = 0.10;
uniform float dirt_amount = 0.0;
uniform vec3 haze_color : source_color = vec3(0.78, 0.88, 0.94);
uniform float haze_density = 0.018;
uniform float haze_start = 6.0;

varying vec3 world_pos;
varying vec3 view_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// View-space POSITION, not distance: a distance interpolated across a
	// 600 u quad reads ~300 u at every fragment. Length is taken per fragment.
	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float big = texture(noise_tex, p / patch_scale).r;
	float small = texture(noise_tex, p / detail_scale + vec2(0.37, 0.61)).r;
	// big in [0,1]: below 0.45 -> grass_b, around 0.5 -> grass_a, above 0.6 -> grass_c
	vec3 col = mix(grass_b, grass_a, smoothstep(0.35, 0.52, big));
	col = mix(col, grass_c, smoothstep(0.56, 0.72, big));
	col *= 1.0 + (small - 0.5) * 2.0 * detail_amount;
	if (dirt_amount > 0.0) {
		float d = smoothstep(0.62, 0.72, texture(noise_tex, p / (patch_scale * 0.7) + vec2(0.8, 0.2)).r);
		col = mix(col, dirt, d * dirt_amount);
	}
	float dist = max(length(view_pos) - haze_start, 0.0);
	float haze = 1.0 - exp(-dist * haze_density);
	ALBEDO = mix(col, haze_color, haze);
}
