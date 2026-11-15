// Building facade with procedural lit windows, computed from world position so any box
// (or a scaled MultiMesh instance) gets a believable grid of offices and apartments.
// Per-building variation comes from `variation_source`:
//   0 = the uniforms below, 1 = vertex colour (rgb = wall tint, a = lit ratio),
//   2 = MultiMesh custom data (x = seed, y = lit ratio, z = wall tint).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/include/ps1.gdshaderinc"

uniform vec3 wall_color : source_color = vec3(0.1, 0.095, 0.13);
uniform vec2 window_cell = vec2(3.0, 3.4);
uniform vec2 window_fill = vec2(0.6, 0.48);
uniform float lit_ratio : hint_range(0.0, 1.0) = 0.35;
uniform float window_energy = 1.4;
// No windows below this height (storefronts live there).
uniform float ground_floor_height = 5.0;
uniform float seed = 0.0;
uniform int variation_source = 0;
// Beyond this distance the window grid blends into its average glow to avoid shimmer.
uniform float far_fade_start = 1400.0;
uniform float far_fade_end = 2600.0;

varying vec3 world_pos;
varying vec3 world_normal;
// Flat: interpolating identical values still jitters by an ULP, which the hashes would amplify.
varying flat vec4 instance_data;
varying flat vec4 vertex_data;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	instance_data = INSTANCE_CUSTOM;
	vertex_data = COLOR;
	POSITION = ps1_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

vec3 interior_light(float pick) {
	if (pick < 0.42) return vec3(1.0, 0.7, 0.4);
	if (pick < 0.68) return vec3(0.55, 0.75, 1.0);
	if (pick < 0.8) return vec3(1.0, 0.3, 0.7);
	if (pick < 0.9) return vec3(0.3, 1.0, 0.9);
	return vec3(0.75, 0.45, 1.0);
}

void fragment() {
	float building_seed = seed;
	float lit = lit_ratio;
	vec3 albedo = wall_color;
	if (variation_source == 1) {
		lit = vertex_data.a;
		albedo *= vertex_data.rgb * 1.6;
	} else if (variation_source == 2) {
		building_seed = floor(instance_data.x);
		lit = instance_data.y;
		albedo *= 0.6 + instance_data.z;
	}
	vec3 emission = vec3(0.0);
	float rough = 0.85;

	if (abs(world_normal.y) < 0.5) {
		vec3 tangent = normalize(cross(vec3(0.0, 1.0, 0.0), world_normal));
		vec2 facade = vec2(dot(world_pos, tangent), world_pos.y);
		vec2 cell = floor(facade / window_cell);
		vec2 local = fract(facade / window_cell);
		float in_window = step(abs(local.x - 0.5), window_fill.x * 0.5) * step(abs(local.y - 0.5), window_fill.y * 0.5);
		float window = in_window * step(ground_floor_height, world_pos.y);

		vec2 id = cell + vec2(building_seed * 37.1, building_seed * 11.7) + round(world_normal.xz * 2.0) * 57.0;
		float on = step(1.0 - lit, ps1_hash(id));
		vec3 light = interior_light(ps1_hash(id * 1.37 + 3.1)) * (0.45 + 0.9 * ps1_hash(id + 7.7));
		// Some windows have blinds: a horizontal stripe pattern dims them.
		float blinds = ps1_hash(id + 2.3) < 0.18 ? 0.55 + 0.45 * step(0.5, fract(local.y * 6.0)) : 1.0;

		albedo = mix(albedo, vec3(0.02, 0.025, 0.04), window);
		rough = mix(rough, 0.12, window);
		emission = light * window_energy * on * window * blinds;

		float dist = length(world_pos - CAMERA_POSITION_WORLD);
		float fade = smoothstep(far_fade_start, far_fade_end, dist);
		vec3 average = vec3(0.85, 0.65, 0.6) * window_energy * lit * window_fill.x * window_fill.y * 0.7;
		emission = mix(emission, average * step(ground_floor_height, world_pos.y), fade);

		// Darker floor slabs between storeys.
		albedo *= 1.0 - 0.4 * step(0.93, fract(facade.y / window_cell.y));
	} else {
		albedo *= 0.6;
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	EMISSION = emission;
}
