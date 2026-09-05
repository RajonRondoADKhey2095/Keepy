shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

// Carte-blanche butterflies: the whole animation lives in the vertex
// shader, so a MultiMesh of N butterflies costs one draw call and no
// per-frame script. Each instance's transform is the CENTRE of its little
// circuit; INSTANCE_CUSTOM carries (phase, circuit radius, direction,
// flap speed) so no two fly alike.
//
// Wings are the vertices with |x| > body half-width in the GLB: they are
// folded up around the body axis (Z) by a sine, which is the flap. The
// body then rides a circle at bobbing height, turned to face its tangent.

uniform float speed = 0.35;
uniform float bob = 0.18;
uniform float flap_hz = 7.0;
uniform vec3 haze_color : source_color = vec3(0.78, 0.88, 0.94);
uniform float haze_density = 0.018;
uniform float haze_start = 6.0;

varying vec3 view_pos;

void vertex() {
	float phase = INSTANCE_CUSTOM.x * 6.2831;
	float radius = max(INSTANCE_CUSTOM.y, 0.2);
	float dir = INSTANCE_CUSTOM.z < 0.5 ? -1.0 : 1.0;
	float flap = flap_hz * (0.8 + INSTANCE_CUSTOM.w * 0.6);

	// Flap: wings fold up around Z. Body vertices (|x| tiny) stay put.
	float a = sin(TIME * flap * 6.2831 + phase) * 0.95 + 0.25;
	if (abs(VERTEX.x) > 0.02) {
		float side = sign(VERTEX.x);
		float wx = abs(VERTEX.x);
		VERTEX.x = side * wx * cos(a);
		VERTEX.y += wx * sin(a);
	}

	// Circuit: position on a circle, facing the tangent.
	float t = TIME * speed * dir / radius + phase;
	vec3 offset = vec3(cos(t) * radius, bob * sin(t * 2.3 + phase), sin(t) * radius);
	vec3 tangent = normalize(vec3(-sin(t), 0.0, cos(t)) * dir);
	vec3 right = vec3(tangent.z, 0.0, -tangent.x);
	mat3 face = mat3(right, vec3(0.0, 1.0, 0.0), tangent);
	VERTEX = face * VERTEX + offset;
	NORMAL = face * NORMAL;

	view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = max(length(view_pos) - haze_start, 0.0);
	float haze = 1.0 - exp(-d * haze_density);
	// Wings lit from above: the underside a touch darker.
	float under = FRONT_FACING ? 1.0 : 0.85;
	ALBEDO = mix(COLOR.rgb * under, haze_color, haze);
}
