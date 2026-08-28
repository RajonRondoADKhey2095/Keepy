shader_type spatial;
render_mode unshaded, cull_disabled;

// Keepy's waterline: the part of him BELOW a fixed world height takes the
// water's hue, the part above keeps his own. Driven by
// scripts/hub/HubWorld.gd, which owns both uniforms.
//
// WHY A SHADER AT ALL, and why the obvious cheaper routes were measured
// and dropped (docs/WATERLINE_RECON.md Q1/Q2, docs/WATER_TINT_RECON.md):
//
//   sink him and let the water draw over him -- MEASURED, does nothing.
//     An opaque mesh in front of a flat transparent plane wins the depth
//     test everywhere its silhouette draws, so 0/30/60% submerged came
//     back pixel-identical to dry.
//   tint the head and body separately -- there is nothing to address.
//     The .glb is ONE mesh, ONE primitive, ONE material; the slot's two
//     MeshInstance3D nodes are the ModelSlot itself (mesh cleared on
//     install) and the model's single draw node.
//
// So the split has to happen per FRAGMENT, and this is the whole of it.
//
// WHY unshaded: it matches the material this replaces exactly
// (shading_mode 0, i.e. UNSHADED), and it is the same argument
// lane_barrier.gdshader already makes -- an unshaded surface outputs
// ALBEDO directly, so the colour this file computes is the colour that
// reaches the player, with no lighting term and nothing post-processing
// the frame.
//
// WHY cull_disabled: also a match, not a choice. The shipped material
// reports cull_mode = 2 (DISABLED). The recon's first shader asserted the
// opposite and the assertion was the thing that was wrong -- see its
// premise 2.
//
// ⚠️ WHY THIS FILE DOES NOT WRITE ALPHA, and it is not a tidy-up.
//
// It used to, and that one line was the whole of the defect Mathieu saw on
// a device: the waterline read correctly from the front and fell apart
// from every other angle, and Keepy came out washed-out cream on dry grass
// where the tint is gated to zero and should be doing nothing at all.
//
// Assigning ALPHA is what moves a spatial material into the TRANSPARENT
// pass, and a transparent material does not write depth. With back faces
// also drawn (cull_disabled, above), the far side of a closed body then
// paints over the near side in whatever order the index buffer happens to
// be in. That order is fixed; which side is far is not -- so the picture
// is wrong at some yaws and right at others, which is exactly the shape of
// the report.
//
// MEASURED, at eight azimuths, as pixels differing from the same shader
// with its depth write restored (scripts/dev/WaterlineOrientationProbe):
//
//   yaw                    0     45     90    135    180    225    270    315
//   writes ALPHA          85    177  13191  24470  18599  17545  12558    255
//   no ALPHA               0      0      0      0      0      0      0      0
//   ALPHA + depth_draw     0      0      0      0      0      0      0      0
//
// The last two rows are two DIFFERENT shaders agreeing to the pixel at
// every angle, which is what pins the cause on the depth write and not on
// the colour: nothing else about them is the same.
//
// depth_draw_always would flatten those numbers too, and is NOT what is
// done here. It would leave the material in the alpha queue, sorted as a
// whole object against the five water discs, which are themselves
// transparent -- trading a bug that is visible for one that is latent.
// Dropping the write restores exactly the state of the material this
// replaced: that one reports transparency = 0, so the screen never used
// this texture's alpha to begin with.
//
// The proof that nothing was lost is that a dry Keepy is now pixel-
// identical to that material at all eight azimuths, gated by
// WaterTintProbe PHASE G.

// ============================ THE WATERLINE ============================
//
// THE TEST IS IN WORLD SPACE, AND THAT IS THE WHOLE DESIGN.
//
// The model-space version compiles, renders, and looks entirely plausible
// in a still frame -- which is exactly what makes it dangerous. Measured
// side by side at the same line height, on the same poses:
//
//   Keepy world y   WORLD wet frac   MODEL wet frac
//   0.00            0.187            0.906
//   0.60            0.000            0.911
//   0.90            0.000            0.914
//
// Model space keeps him soaked at every altitude and marches its line UP
// the screen with him (row 943 -> 855) -- because VERTEX is measured from
// his own origin, which travels with him. World space dries him the
// instant his feet clear the line, and its line stays on the row the
// camera puts world y on (1059.9).
//
// The offset between the two systems is not small either: the slot sits
// at y = 0.9 with model_offset -0.2246 and model_scale 1.07368, so a
// water_y of 0.55 means 40.7% of him in world and 93.8% of him in model.
//
// MODEL_MATRIX in vertex() is the cheap half of that: computed once per
// vertex and interpolated, rather than reconstructing world space per
// fragment from INV_VIEW_MATRIX. Both were compiled and rendered in
// gl_compatibility and produced the same picture; this is the one that
// does less work.
varying vec3 v_world;

// The world height the surface sits at. One value for all five bodies --
// their real surfaces span 0.0270 to 0.0950, a spread of 5.04% of Keepy's
// height, and whether that shows is an open question this batch measures
// rather than assumes.
uniform float water_y = 0.45;

// How far the submerged part is carried toward the water. 0 is a no-op,
// so a null/idle state costs nothing and looks like nothing. HubWorld
// tweens this exactly as it used to tween albedo_color.
uniform float tint_fraction : hint_range(0.0, 1.0) = 0.0;

// The water's own hue, handed in rather than hard-coded, so this file can
// never disagree with HubBuilder.POND_WATER_COLOR.
uniform vec4 water_color : source_color = vec4(0.251, 0.878, 0.816, 1.0);

// Keepy's own texture. The tint MULTIPLIES it rather than replacing it --
// he keeps his markings, his badge and his eyes and takes the water's hue
// over the top. Replacing the colour outright flattened him to a
// turquoise blob, which is why the shipped uniform tint lerped too.
uniform sampler2D albedo_texture : source_color;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);

	// 1.0 below the line, 0.0 above it. step() rather than smoothstep():
	// a real waterline is a hard edge, and the recon measured this edge as
	// CLEAN -- 0.96 wet/dry flips per screen column crossing the body,
	// i.e. one crossing, not the many a depth fight would give. What had
	// looked like speckle in an early render was the fur texture's own
	// markings on a profile pose.
	float submerged = step(v_world.y, water_y);

	ALBEDO = mix(tex.rgb, mix(tex.rgb, water_color.rgb, tint_fraction), submerged);
	// ALPHA is deliberately left alone -- see the block above. Writing it
	// at all costs the depth write, and this asset has no alpha to carry.
}
