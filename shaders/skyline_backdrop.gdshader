// Distant skyline painted on a ring around the world: two layers of building silhouettes with
// tiny lit windows, coloured to melt into the sky's horizon glow. Beyond the fog on purpose.
// UV.x runs around the ring (0..1), UV.y from the bottom (0) to the top (1) of the ring.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec3 far_color : source_color = vec3(0.12, 0.05, 0.16);
uniform vec3 near_color : source_color = vec3(0.06, 0.025, 0.09);
uniform vec3 glow_color : source_color = vec3(0.75, 0.18, 0.5);
// Ring height in metres, used to turn UV.y into heights.
uniform float ring_height = 900.0;
uniform float window_amount = 0.12;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Height (in metres) of the skyline at horizontal position x, with buildings `width` wide.
float skyline(float x, float width, float base, float range, float salt) {
	float id = floor(x / width);
	float h = hash(vec2(id, salt));
	return base + range * h * h + step(0.93, hash(vec2(id, salt + 3.0))) * range * 1.2;
}

void fragment() {
	float x = UV.x * 6000.0;
	float y = (1.0 - UV.y) * ring_height;
	float far_h = skyline(x, 26.0, 60.0, 260.0, 1.0);
	float near_h = skyline(x + 13.0, 38.0, 30.0, 180.0, 7.0);

	if (y > far_h && y > near_h) {
		discard;
	}
	bool is_near = y <= near_h;
	vec3 col = is_near ? near_color : far_color;
	// Windows: a sparse grid of tiny lit cells.
	vec2 cell = floor(vec2(x / (is_near ? 3.0 : 2.0), y / (is_near ? 4.0 : 3.0)));
	float lit = step(1.0 - window_amount, hash(cell + (is_near ? 11.0 : 29.0)));
	col += vec3(1.0, 0.7, 0.5) * lit * (is_near ? 0.5 : 0.25);
	// Haze: silhouettes fade into the horizon glow towards the ground.
	col = mix(col, glow_color * 0.35, exp(-y * 0.012) * 0.8);
	ALBEDO = col;
}
