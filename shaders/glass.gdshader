// Tinted, glossy glass for shop windows and visors.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

#include "res://shaders/include/ps1.gdshaderinc"

uniform vec4 tint : source_color = vec4(0.35, 0.75, 1.0, 0.12);
uniform float rim_strength = 0.35;

void vertex() {
	POSITION = ps1_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(tint.a + rim * rim_strength, 0.0, 1.0);
	ROUGHNESS = 0.05;
	METALLIC = 0.4;
	SPECULAR = 0.8;
	EMISSION = tint.rgb * 0.05;
}
