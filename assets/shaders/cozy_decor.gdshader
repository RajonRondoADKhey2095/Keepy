shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

// Carte-blanche decor shader (branch claude/carte-blanche-cozy).
//
// UNSHADED, deliberately: the scene has no light and every surface in this
// project is unlit (docs/MESHY_SPEC.md 8). The toon look is therefore
// computed HERE from a fixed direction, so it renders identically under
// llvmpipe, desktop GL and WebGL2 -- nothing depends on the engine's light
// loop or on the Compatibility renderer's fog, which is not functional on
// WebGL2 (Godot #97875, #92019). Depth haze is written by hand below for
// the same reason.
//
// COLOUR comes from the mesh's vertex colours (COLOR_0 baked by the
// Blender family scripts, one flat material per GLB) multiplied by the
// MultiMesh instance colour when the batch declares use_colors -- Godot
// hands the product in COLOR. A batch without instance colours reads
// COLOR = vertex colour, so the same shader serves both.

// Multiplied into the vertex colour. White for the GLB families (their
// colour is baked per vertex); the albedo itself for a plain primitive.
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
// Sun direction in WORLD space (pointing FROM the surface TOWARD the sun).
uniform vec3 sun_dir = vec3(0.35, 0.80, 0.45);
// Lit / shade multipliers of the two toon bands, and the width of the
// blend between them (0 = hard edge).
uniform float lit = 1.06;
uniform float shade = 0.80;
uniform float band_softness = 0.28;
// Ambient sky tint for the shadow side (a touch of cool in the shade is
// what makes a flat colour read as a lit form).
uniform vec3 shade_tint : source_color = vec3(0.86, 0.92, 1.0);
// Rim light: strength and exponent, colour.
uniform float rim_strength = 0.22;
uniform float rim_power = 3.0;
uniform vec3 rim_color : source_color = vec3(1.0, 0.97, 0.85);
// Depth haze: colour the far ground and canopy fade toward, and the
// exponential density (per world unit of view distance).
uniform vec3 haze_color : source_color = vec3(0.78, 0.88, 0.94);
uniform float haze_density = 0.018;
uniform float haze_start = 6.0;
// Wind: amplitude in world units at the top of a prop, frequency in Hz.
// Weight is the vertex's LOCAL height over wind_height, squared, so bases
// stay planted. 0 disables.
uniform float wind_amount = 0.0;
uniform float wind_height = 1.0;
uniform float wind_speed = 1.1;
// v2 weather (written by CozyPalette.apply_weather every frame): a global
// albedo multiplier (light), a wind multiplier, a constant lean in world
// xz for storm-flattened grass, and snow settling on upward faces.
uniform vec3 weather_tint = vec3(1.0, 1.0, 1.0);
uniform float wind_scale = 1.0;
uniform vec2 lean = vec2(0.0, 0.0);
uniform float snow = 0.0;

varying vec3 view_pos;
varying vec3 world_normal;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (wind_amount > 0.0) {
		float w = clamp(VERTEX.y / wind_height, 0.0, 1.0);
		w *= w;
		float phase = world_pos.x * 0.35 + world_pos.z * 0.27;
		float sway = sin(TIME * wind_speed * 6.2831 * 0.5 + phase) * 0.7
			+ sin(TIME * wind_speed * 6.2831 * 1.3 + phase * 2.1) * 0.3;
		// Sway in MODEL space, amplitude divided by the instance scale so
		// it stays in world units; the phase is world-based so neighbours
		// do not move in lockstep. No inverse(): a mat4 inverse per vertex
		// is exactly what a mobile GPU should not be asked for.
		float model_scale = max(length(MODEL_MATRIX[0].xyz), 0.001);
		VERTEX.xz += vec2(sway, sway * 0.6) * (wind_amount * wind_scale * w / model_scale);
		VERTEX.xz += lean * (w * min(wind_amount * 6.0, 1.0) / model_scale);
	}
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// View-space POSITION, not distance: a distance interpolated across a
	// 600 u quad reads ~300 u at every fragment. Length is taken per fragment.
	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	// Two-sided: grass blades and leaves are single quads.
	if (!FRONT_FACING) {
		n = -n;
	}
	vec3 base = COLOR.rgb * tint;
	if (snow > 0.0) {
		base = mix(base, vec3(0.94, 0.96, 1.0), snow * smoothstep(0.25, 0.75, n.y));
	}

	float ndl = dot(n, normalize(sun_dir));
	float band = smoothstep(-band_softness, band_softness, ndl - 0.1);
	vec3 shaded = base * mix(shade * shade_tint, vec3(lit), band);

	// Rim: view vector in world space from the camera position to the
	// fragment. VIEW is view-space; rebuild in world with INV_VIEW_MATRIX.
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float rim = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), rim_power) * rim_strength;
	shaded += rim_color * rim * band;

	float d = max(length(view_pos) - haze_start, 0.0);
	float haze = 1.0 - exp(-d * haze_density);
	ALBEDO = mix(shaded * weather_tint, haze_color, haze);
}
