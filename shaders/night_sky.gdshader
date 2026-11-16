// Smoggy night sky: a dark zenith, a magenta light-pollution band on the horizon
// and slow clouds lit from below by the city.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.006, 0.006, 0.02);
uniform vec3 horizon_color : source_color = vec3(0.13, 0.05, 0.17);
uniform vec3 city_glow_color : source_color = vec3(0.75, 0.18, 0.5);
uniform float city_glow_strength = 0.35;
uniform float city_glow_falloff = 9.0;
uniform vec3 cloud_color : source_color = vec3(0.22, 0.09, 0.27);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.6;
uniform float cloud_speed = 0.006;
uniform float star_amount : hint_range(0.0, 1.0) = 0.2;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		total += value_noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.7);
		amp *= 0.5;
	}
	return total;
}

void sky() {
	vec3 dir = EYEDIR;
	float y = dir.y;
	float up = clamp(y, 0.0, 1.0);

	vec3 col = mix(horizon_color, zenith_color, pow(up, 0.4));
	col += city_glow_color * exp(-abs(y) * city_glow_falloff) * city_glow_strength;

	if (y > 0.0) {
		vec2 uv = dir.xz / (y + 0.12);
		float n = fbm(uv * 0.9 + TIME * cloud_speed * vec2(1.0, 0.35));
		float cloud = smoothstep(1.0 - cloud_coverage, 1.05 - cloud_coverage * 0.5, n);
		vec3 lit_cloud = cloud_color * (0.35 + 1.4 * exp(-y * 3.5));
		col = mix(col, lit_cloud, cloud * smoothstep(0.0, 0.1, y));

		if (!AT_CUBEMAP_PASS) {
			vec2 star_cell = floor(dir.xz / (y + 0.4) * 220.0);
			float star = step(1.0 - star_amount * 0.004, hash(star_cell));
			col += vec3(0.7, 0.75, 1.0) * star * (1.0 - cloud) * smoothstep(0.15, 0.6, y);
		}
	}
	COLOR = col;
}
