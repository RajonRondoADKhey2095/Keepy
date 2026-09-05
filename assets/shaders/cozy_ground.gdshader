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
uniform sampler2D cell_tex : filter_linear_mipmap, repeat_enable;
uniform float cell_scale = 2.6;
uniform float cell_amount = 0.05;
uniform vec3 grass_a : source_color = vec3(0.56, 0.78, 0.36);
uniform vec3 grass_b : source_color = vec3(0.44, 0.70, 0.32);
uniform vec3 grass_c : source_color = vec3(0.66, 0.82, 0.40);
uniform vec3 dirt : source_color = vec3(0.70, 0.60, 0.40);
// World-space repeat lengths of the two noise octaves, in units.
uniform float patch_scale = 26.0;
uniform float detail_scale = 5.5;
uniform float detail_amount = 0.10;
uniform float dirt_amount = 0.0;
// Carte-blanche v2: the autumn hollow. World z where the leaf litter takes
// over (going toward -z), the width of the blend, and its three tones.
uniform float autumn_edge_z = -39.0;
uniform float autumn_edge_w = 7.0;
uniform vec3 autumn_a : source_color = vec3(0.80, 0.54, 0.28);
uniform vec3 autumn_b : source_color = vec3(0.66, 0.40, 0.20);
uniform vec3 autumn_c : source_color = vec3(0.90, 0.68, 0.32);
// Carte-blanche v3: the moor beyond the hollow. Heather in three mauves,
// and lavender ROWS painted straight into the ground inside the field
// rectangles (xmin, zmin, xmax, zmax) -- rows are what a lavender field
// is from this camera, and painting them costs nothing.
uniform float moor_edge_z = -84.0;
uniform float moor_edge_w = 6.0;
uniform vec3 moor_a : source_color = vec3(0.66, 0.58, 0.76);
uniform vec3 moor_b : source_color = vec3(0.54, 0.46, 0.66);
uniform vec3 moor_c : source_color = vec3(0.82, 0.76, 0.60);
uniform vec3 row_violet : source_color = vec3(0.50, 0.32, 0.72);
uniform vec3 row_soil : source_color = vec3(0.78, 0.70, 0.54);
uniform vec4 field_0 = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 field_1 = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec4 field_2 = vec4(0.0, 0.0, 0.0, 0.0);
uniform float row_pitch = 2.4;
// Carte-blanche v7: the circuit beyond the moor. A mown lawn in two
// greens, with MOWING STRIPES (alternating bands along x) that say
// "kept ground" the way the lavender rows said "planted ground" --
// and read the direction of the straight from 40 u away. Painted
// straight into the ground for the same reason: rows cost nothing.
uniform float circuit_edge_z = -132.0;
uniform float circuit_edge_w = 3.0;
uniform vec3 lawn_a : source_color = vec3(0.58, 0.82, 0.40);
uniform vec3 lawn_b : source_color = vec3(0.50, 0.75, 0.35);
uniform float lawn_stripe = 6.0;
uniform vec3 haze_color : source_color = vec3(0.78, 0.88, 0.94);
uniform float haze_density = 0.018;
uniform float haze_start = 6.0;
// v2 weather: global light, wetness (darker, more saturated, for a while
// after rain) and snow cover.
uniform vec3 weather_tint = vec3(1.0, 1.0, 1.0);
uniform float wet = 0.0;
uniform float snow = 0.0;

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
	// Autumn mask: a z threshold wobbled by the big noise so the edge is a
	// ragged line under the hedge, never a ruler.
	float autumn = smoothstep(autumn_edge_z, autumn_edge_z - autumn_edge_w, world_pos.z + (big - 0.5) * 9.0);
	vec3 leaf = mix(autumn_b, autumn_a, smoothstep(0.35, 0.52, big));
	leaf = mix(leaf, autumn_c, smoothstep(0.56, 0.72, big));
	col = mix(col, leaf, autumn);
	// A tighter wobble than the autumn edge's: the hedge band is 5 u and
	// the first capture showed leaf litter blotches 8 u INTO the moor.
	float moor = smoothstep(moor_edge_z, moor_edge_z - moor_edge_w, world_pos.z + (big - 0.5) * 5.0);
	vec3 heath = mix(moor_b, moor_a, smoothstep(0.35, 0.52, big));
	heath = mix(heath, moor_c, smoothstep(0.58, 0.74, big));
	// Lavender rows inside the fields: a soft stripe along x, every
	// row_pitch in z, feathered at the field edges by the big noise.
	float rows = 0.0;
	for (int i = 0; i < 3; i++) {
		vec4 f = (i == 0) ? field_0 : ((i == 1) ? field_1 : field_2);
		if (f.z > f.x) {
			float inside = step(f.x, p.x) * step(p.x, f.z) * step(f.y, p.y) * step(p.y, f.w);
			float edge = smoothstep(0.0, 1.5, min(min(p.x - f.x, f.z - p.x), min(p.y - f.y, f.w - p.y)) + (small - 0.5) * 2.0);
			rows = max(rows, inside * edge);
		}
	}
	float stripe = smoothstep(0.30, 0.42, abs(fract(p.y / row_pitch) - 0.5));
	vec3 rowcol = mix(row_violet * (0.92 + 0.16 * small), row_soil, stripe);
	heath = mix(heath, rowcol, rows);
	col = mix(col, heath, moor);
	// v7: the circuit's lawn takes over past the moor's far hedge. A
	// tight wobble like the moor's (the hedge band is 8 u wide).
	float circuit = smoothstep(circuit_edge_z, circuit_edge_z - circuit_edge_w, world_pos.z + (big - 0.5) * 4.0);
	float mow = smoothstep(0.42, 0.58, abs(fract(p.x / lawn_stripe) - 0.5) * 2.0);
	vec3 lawn = mix(lawn_a, lawn_b, mow);
	lawn *= 1.0 + (big - 0.5) * 0.10;
	col = mix(col, lawn, circuit);
	col *= 1.0 + (small - 0.5) * 2.0 * detail_amount;
	// Fine mottle (grass clumps) close to the camera; mipmapped away far.
	float fine = texture(noise_tex, p / 1.7 + vec2(0.13, 0.91)).r;
	col *= 1.0 + (fine - 0.5) * 0.12;
	// Clover carpet: cellular cells, a few percent, gone with distance.
	float cells = texture(cell_tex, p / cell_scale).r;
	col *= 1.0 + (cells - 0.5) * 2.0 * cell_amount;
	if (dirt_amount > 0.0) {
		float d = smoothstep(0.62, 0.72, texture(noise_tex, p / (patch_scale * 0.7) + vec2(0.8, 0.2)).r);
		col = mix(col, dirt, d * dirt_amount);
	}
	if (wet > 0.0) {
		float lum = dot(col, vec3(0.3, 0.55, 0.15));
		vec3 sat = mix(vec3(lum), col, 1.35);
		col = mix(col, sat * 0.74, wet);
	}
	if (snow > 0.0) {
		float cover = snow * smoothstep(0.2, 0.6, small * 0.5 + fine * 0.5 + snow * 0.4);
		col = mix(col, vec3(0.93, 0.95, 0.98), cover);
	}
	float dist = max(length(view_pos) - haze_start, 0.0);
	float haze = 1.0 - exp(-dist * haze_density);
	ALBEDO = mix(col * weather_tint, haze_color, haze);
}
