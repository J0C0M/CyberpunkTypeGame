// Four invented TV channels drawn procedurally; TvSet overlays the text with labels.
// 0 = NEO-7 news studio, 1 = advert for a made-up corporation, 2 = abstract anime-style action,
// 3 = static. `switching` (1 -> 0) adds a burst of noise when the channel changes.
shader_type canvas_item;

uniform int channel = 0;
uniform float switching = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 news(vec2 uv, float t) {
	vec3 col = mix(vec3(0.03, 0.06, 0.2), vec3(0.1, 0.22, 0.5), uv.y);
	col += 0.06 * step(0.92, fract(uv.x * 7.0 - t * 0.15));
	// The anchor: a round head and shoulders behind a desk.
	vec2 head = (uv - vec2(0.66, 0.36)) * vec2(1.0, 0.56);
	vec2 body = uv - vec2(0.66, 0.66);
	float anchor = step(length(head), 0.06) + step(abs(body.x), 0.13 - body.y * 0.25) * step(0.0, body.y);
	col = mix(col, vec3(0.08, 0.06, 0.12), clamp(anchor, 0.0, 1.0));
	col = mix(col, vec3(0.75, 0.75, 0.8), step(0.72, uv.y) * step(uv.y, 0.74));
	// Lower third: red band with the ticker strip below it.
	col = mix(col, vec3(0.75, 0.05, 0.12), step(0.76, uv.y) * step(uv.y, 0.86));
	col = mix(col, vec3(0.92, 0.92, 0.95), step(0.86, uv.y));
	// A small map inset with a blinking dot.
	vec2 inset = uv - vec2(0.2, 0.38);
	if (abs(inset.x) < 0.13 && abs(inset.y) < 0.18) {
		col = vec3(0.05, 0.15, 0.1) + 0.15 * step(0.9, fract(inset.x * 20.0)) + 0.15 * step(0.9, fract(inset.y * 20.0));
		col += vec3(1.0, 0.2, 0.2) * step(length(inset - vec2(0.03, -0.02)), 0.02) * step(0.5, fract(t * 1.5));
	}
	return col;
}

vec3 advert(vec2 uv, float t) {
	vec2 c = uv - vec2(0.5, 0.42);
	float angle = atan(c.y, c.x) + t * 0.5;
	vec3 col = mix(vec3(0.35, 0.02, 0.3), vec3(0.95, 0.4, 0.1), step(0.5, fract(angle * 12.0 / 6.2831)) * 0.5 + uv.y * 0.5);
	// Spinning hexagon logo.
	float hex = max(abs(c.x) * 0.866 + abs(c.y * 1.8) * 0.5, abs(c.y * 1.8));
	float ring = step(abs(hex - 0.16), 0.025);
	col = mix(col, vec3(1.0), ring);
	col = mix(col, vec3(0.1, 0.9, 1.0), step(hex, 0.09) * (0.6 + 0.4 * sin(t * 4.0)));
	return col;
}

vec3 anime(vec2 uv, float t) {
	vec2 c = (uv - 0.5) * vec2(1.78, 1.0);
	float angle = atan(c.y, c.x);
	float lines = step(0.7, fract(angle * 9.0 + hash(vec2(floor(angle * 9.0), floor(t * 12.0))) * 2.0));
	vec3 col = mix(vec3(0.05, 0.0, 0.12), vec3(1.0, 0.95, 0.8), lines * smoothstep(0.1, 0.8, length(c)));
	// A pulsing star burst and a swooping dragon-ish ribbon.
	float star = abs(c.x * c.y) * 30.0 + length(c) * 3.0;
	col = mix(col, vec3(1.0, 0.25, 0.6), step(star, 0.4 + 0.2 * sin(t * 6.0)));
	float ribbon = abs(c.y - 0.25 * sin(c.x * 4.0 + t * 3.0));
	col = mix(col, vec3(0.1, 0.9, 1.0), step(ribbon, 0.03));
	col *= 0.85 + 0.3 * step(0.97, hash(vec2(floor(t * 8.0), 1.0)));
	return col;
}

vec3 static_noise(vec2 uv, float t) {
	float n = hash(floor(uv * vec2(160.0, 90.0)) + floor(t * 30.0) * 7.0);
	float roll = step(0.94, fract(uv.y * 1.5 - t * 0.4));
	return vec3(n) * 0.75 + roll * 0.2;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	vec3 col;
	if (channel == 0) {
		col = news(uv, t);
	} else if (channel == 1) {
		col = advert(uv, t);
	} else if (channel == 2) {
		col = anime(uv, t);
	} else {
		col = static_noise(uv, t);
	}
	col = mix(col, static_noise(uv, t), switching);
	col *= 0.88 + 0.12 * step(0.5, fract(uv.y * 72.0));
	col *= 1.0 - 0.35 * pow(length(uv - 0.5) * 1.3, 2.0);
	COLOR = vec4(col, 1.0);
}
