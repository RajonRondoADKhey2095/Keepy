shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

// CH64 -- THE SKATEPARK'S CONCRETE.
//
// The decor shader (cozy_decor.gdshader) is a toon: two bands and a rim,
// which is the whole hub's look and the reason the park's five modules
// read as paving slabs (CH53 wrote as much). Mathieu wants the park
// closer to True Skate -- real concrete -- and accepts that it cuts
// against the cartoon hub around it. So this is the decor shader with
// three things changed and nothing else:
//
//   1. a SMOOTH diffuse instead of two bands, so a quarterpipe's
//      transition reads as a curve and not as a fold;
//   2. a concrete GRAIN: two fetches of the ONE noise texture the ground
//      and the water already share (CozyPalette.noise_texture -- a
//      texture fetch is what a mobile GPU is fast at, a procedural noise
//      in the fragment is not), projected in world space by the dominant
//      axis of the normal so a wall and a deck take the same grain and a
//      module's grain does not stretch with its transition;
//   3. a `wet` term the ground already receives, so rain darkens the
//      slab the way it darkens the lawn.
//
// It keeps the haze (every distance cue in this hub is that haze), the
// weather tint, the snow on upward faces, and UNSHADED: nothing in this
// project is lit and nothing post-processes the frame (CLAUDE.md).
//
// Per fragment: two texture fetches and arithmetic, only on the park's
// own pixels. The shading itself is baked into the VERTEX COLOUR by
// SkateparkMesh (darker at the foot of a transition, at the bottom of a
// wall, in the bowl), which is where the realism actually comes from --
// bake-once, exactly as the brief asks.

uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform vec3 sun_dir = vec3(0.35, 0.80, 0.45);
uniform float lit = 1.04;
uniform float shade = 0.80;
uniform vec3 shade_tint : source_color = vec3(0.96, 0.96, 0.98);
// Amplitude of the coarse mottle and the fine speckle, and their scales
// (world units to texture repeats).
uniform float grain = 0.13;
uniform float speckle = 0.06;
uniform float grain_scale = 0.11;
uniform float speckle_scale = 0.85;
uniform vec3 haze_color : source_color = vec3(0.78, 0.88, 0.94);
uniform float haze_density = 0.018;
uniform float haze_start = 6.0;
uniform vec3 weather_tint = vec3(1.0, 1.0, 1.0);
uniform float snow = 0.0;
uniform float wet = 0.0;

varying vec3 view_pos;
varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 an = abs(n);
	vec2 uv = world_pos.xz;
	if (an.x > an.y && an.x > an.z) {
		uv = world_pos.zy;
	} else if (an.z > an.y) {
		uv = world_pos.xy;
	}
	float m = texture(noise_tex, uv * grain_scale).r;
	float sp = texture(noise_tex, uv * speckle_scale + vec2(0.37, 0.61)).r;
	float tex = 1.0 + grain * (m - 0.5) * 2.0 + speckle * (sp - 0.5) * 2.0;
	vec3 base = COLOR.rgb * tex;
	float d = clamp(dot(n, normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 shaded = base * mix(shade * shade_tint, vec3(lit), d);
	shaded *= mix(1.0, 0.76, wet);
	if (snow > 0.0) {
		shaded = mix(shaded, vec3(0.94, 0.96, 1.0), snow * smoothstep(0.25, 0.75, n.y));
	}
	float dist = max(length(view_pos) - haze_start, 0.0);
	float haze = 1.0 - exp(-dist * haze_density);
	ALBEDO = mix(shaded * weather_tint, haze_color, haze);
}
