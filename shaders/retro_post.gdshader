// Screen-space retro filter applied to the low-res game viewport:
// night colour grade, vignette, then ordered (Bayer) dithering and colour quantization.
shader_type canvas_item;

uniform bool enabled = true;
uniform float color_levels = 28.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 0.85;
uniform float contrast = 1.1;
uniform float saturation = 1.18;
uniform vec3 shadow_tint : source_color = vec3(0.09, 0.05, 0.2);
uniform float shadow_lift = 0.35;
uniform vec3 highlight_tint = vec3(1.0, 0.94, 1.04);
uniform float vignette = 0.38;

const float BAYER_4X4[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

vec3 night_grade(vec3 c) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	// Push the shadows towards blue/purple and keep highlights slightly cool-magenta.
	float shadow_mask = 1.0 - smoothstep(0.0, 0.4, luma);
	c = mix(c, c + shadow_tint, shadow_mask * shadow_lift);
	c *= mix(vec3(1.0), highlight_tint, smoothstep(0.35, 1.0, luma));
	return clamp(c, 0.0, 1.0);
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	if (enabled) {
		c = night_grade(c);
		vec2 centered = UV - 0.5;
		c *= 1.0 - vignette * smoothstep(0.25, 0.75, length(centered * vec2(1.25, 1.0)));

		ivec2 px = ivec2(floor(UV * vec2(textureSize(TEXTURE, 0))));
		float threshold = BAYER_4X4[(px.x % 4) + (px.y % 4) * 4] / 16.0 - 0.5;
		c += threshold * dither_strength / color_levels;
		c = floor(c * color_levels + 0.5) / color_levels;
	}
	COLOR = vec4(c, 1.0);
}
