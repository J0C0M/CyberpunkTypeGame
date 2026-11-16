// Wet street surfaces: asphalt or paving tiles with puddles that mirror the neon (via SSR).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/ps1.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.045, 0.045, 0.06);
uniform float base_roughness : hint_range(0.0, 1.0) = 0.5;
// Size of paving tiles in metres; 0 disables the grout lines.
uniform float tile_size = 0.0;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.55;
uniform float puddle_scale = 0.12;

varying vec3 world_pos;

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(ps1_hash(i), ps1_hash(i + vec2(1.0, 0.0)), u.x),
			mix(ps1_hash(i + vec2(0.0, 1.0)), ps1_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = ps1_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = value_noise(p * puddle_scale) * 0.65 + value_noise(p * puddle_scale * 3.1 + 17.0) * 0.35;
	float puddle = smoothstep(1.0 - puddle_amount, 1.0 - puddle_amount + 0.08, n);
	float grit = ps1_hash(floor(p * 4.0));

	vec3 albedo = base_color * (0.85 + 0.3 * grit);
	if (tile_size > 0.0) {
		vec2 t = abs(fract(p / tile_size) - 0.5);
		float grout = step(0.46, max(t.x, t.y));
		albedo *= 1.0 - 0.45 * grout;
	}
	ALBEDO = mix(albedo, albedo * 0.45, puddle);
	ROUGHNESS = mix(base_roughness, 0.02, puddle);
	METALLIC = mix(0.0, 0.2, puddle);
	SPECULAR = 0.6;
}
