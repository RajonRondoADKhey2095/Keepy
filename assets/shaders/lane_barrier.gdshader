shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// The wall that closes a lane during a temporary track shrink -- see
// scripts/world/LaneBarrier.gd for what drives it and GameState's TRACK
// SHRINK section for the mechanic itself.
//
// WHY unshaded, and why that is the whole legibility argument: the one
// thing this telegraph must never do is become hard to read in some
// palette. An `unshaded` surface outputs ALBEDO directly, with no
// lighting term at all, so its colour is a value THIS FILE fixes rather
// than something the scene's DirectionalLight3D, the time of day or a
// hazard's own material happens to produce. That is exactly the reasoning
// Obstacle.gd's JumpMarkerMesh already uses for the "can I jump this"
// signal, reused here rather than a second approach invented for a second
// must-always-be-readable cue.
//
// The dark cycle still inverts and tints the frame on top of this (see
// screen_invert.gdshader). That pass is injective for any tint_amount
// below 1.0, so it cannot COLLAPSE the contrast -- but it does move it,
// and by an amount no hand calculation predicts reliably. Hence the two
// colours below are picked at the extremes of the luminance range (near
// white against near black) rather than anywhere in the middle: a pair
// that far apart survives both the plain frame and the inverted one,
// which is what scripts/dev/DarkPaletteAudit.gd measures per palette.
//
// Deliberately trivial maths -- one fract, one step, one mix, no loops,
// no derivatives, no texture reads -- to stay well inside
// gl_compatibility on mobile Safari, the renderer this project pins
// (project.godot rendering_method = "gl_compatibility"). Same discipline
// as pursuer_vignette.gdshader.

// The two stripe colours. Near-white and near-black rather than a hue
// pair on purpose: hue is what the dark cycle's tint pass moves most, and
// LUMINANCE distance is what a contrast ratio is actually made of.
uniform vec3 base_color : source_color = vec3(0.96, 0.96, 0.93);
uniform vec3 stripe_color : source_color = vec3(0.05, 0.05, 0.07);

// Scrolls the stripes along the barrier's local Z so the wall reads as
// moving WITH the world even though the node itself never moves on Z.
//
// The barrier spans the whole visible track at once, so it cannot be
// pooled and recycled the way a TrackSegment is -- it has no rows to
// recycle. Scrolling a pattern is what buys back the motion cue that
// recycling would otherwise have provided, for one uniform write a frame
// and zero allocation. Fed from GameState.distance_travelled, so the
// stripes travel at exactly the world's own speed at every palier
// instead of at a rate tuned for one of them.
uniform float scroll = 0.0;
// Metres per light/dark pair, and the fraction of that pair the dark
// stripe occupies.
uniform float stripe_period = 2.4;
uniform float stripe_duty : hint_range(0.0, 1.0) = 0.45;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	float t = fract((v_local.z + scroll) / stripe_period);
	ALBEDO = mix(base_color, stripe_color, step(stripe_duty, t));
}
