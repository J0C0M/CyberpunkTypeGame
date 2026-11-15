// Animated holographic billboard. Procedural patterns stand in for adverts; set `ad_texture`
// to show real artwork instead. Unshaded and bright so it glows through the fog.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/include/ps1.gdshaderinc"

uniform vec4 color_a : source_color = vec4(1.0, 0.16, 0.62, 1.0);
uniform vec4 color_b : source_color = vec4(0.1, 0.88, 1.0, 1.0);
uniform float energy = 2.5;
// 0 = rings, 1 = equalizer bars, 2 = diagonal sweep, 3 = blocky glyph grid.
uniform int pattern = 0;
uniform float seed = 0.0;
uniform sampler2D ad_texture : source_color, filter_nearest, hint_default_black;
uniform bool use_texture = false;

void vertex() {
	POSITION = ps1_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	vec2 uv = UV;
	float t = TIME + seed * 10.0;
	float v = 0.0;
	if (use_texture) {
		ALBEDO = texture(ad_texture, uv).rgb * energy;
	} else {
		if (pattern == 0) {
			float d = length((uv - 0.5) * vec2(1.6, 1.0));
			v = step(0.5, fract(d * 6.0 - t * 0.8)) * step(d, 0.55);
		} else if (pattern == 1) {
			float bar = floor(uv.x * 12.0);
			float h = 0.2 + 0.7 * abs(sin(t * (1.0 + ps1_hash(vec2(bar, seed)) * 3.0) + bar));
			v = step(1.0 - uv.y, h) * step(0.15, fract(uv.x * 12.0));
		} else if (pattern == 2) {
			v = step(0.55, fract((uv.x + uv.y) * 4.0 - t * 0.6));
		} else {
			vec2 cell = floor(uv * vec2(6.0, 4.0));
			float flip = floor(t * 1.5);
			v = step(0.45, ps1_hash(cell + flip + seed));
		}
		vec3 col = mix(color_b.rgb * 0.25, color_a.rgb, v);
		// Border and scanlines.
		vec2 edge = min(uv, 1.0 - uv);
		col = mix(col, color_b.rgb, step(min(edge.x, edge.y), 0.03));
		col *= 0.8 + 0.2 * step(0.5, fract(uv.y * 40.0 + t * 2.0));
		ALBEDO = col * energy;
	}
}
