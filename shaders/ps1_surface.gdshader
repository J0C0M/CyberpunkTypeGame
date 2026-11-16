// General lit surface for props and architecture, with PS1 vertex wobble.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/ps1.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform vec2 uv_scale = vec2(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
// Subtle world-space grime so large flat faces don't look like plastic.
uniform float grime = 0.15;

varying vec3 world_pos;

void vertex() {
	UV *= uv_scale;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = ps1_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	vec3 tex = texture(albedo_texture, UV).rgb;
	float n = ps1_hash(floor(world_pos.xz * 2.0) + floor(world_pos.y * 2.0) * 17.0);
	ALBEDO = albedo.rgb * tex * (1.0 - grime * n);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission_color.rgb * emission_energy;
}
