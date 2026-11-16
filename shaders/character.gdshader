// The player character: one pixel-art atlas (skin, face, underwear, tattoos) times the vertex
// colour (clothes and hair sample a white texel and take their colour from the vertices), plus a
// glow atlas (neon tattoos, LEDs) and vertex-alpha neon (alpha < 1 glows: trims, neon hair).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/ps1.gdshaderinc"

uniform sampler2D albedo_atlas : source_color, filter_nearest, hint_default_white;
uniform sampler2D emission_atlas : source_color, filter_nearest, hint_default_black;
uniform float emission_energy = 3.0;
uniform float roughness = 0.72;

void vertex() {
	POSITION = ps1_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	ALBEDO = texture(albedo_atlas, UV).rgb * COLOR.rgb;
	ROUGHNESS = roughness;
	EMISSION = texture(emission_atlas, UV).rgb * emission_energy + COLOR.rgb * (1.0 - COLOR.a) * 4.0;
}
