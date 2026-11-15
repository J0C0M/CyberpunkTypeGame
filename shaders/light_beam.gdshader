// Fake volumetric searchlight: additive cone that fades along its length and at the edges.
// The mesh is a cone along local -Z with UV.y running from the source (0) to the tip (1).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 beam_color : source_color = vec3(0.6, 0.8, 1.0);
uniform float intensity = 0.25;

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	ALBEDO = beam_color * intensity * (1.0 - along) * (1.0 - along) * edge;
}
