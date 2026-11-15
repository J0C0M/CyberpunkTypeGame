// Unshaded emissive surface for neon tubes, signs and lights. Values above 1 feed the glow.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/include/ps1.gdshaderinc"

uniform vec4 color : source_color = vec4(1.0, 0.2, 0.8, 1.0);
uniform float energy = 4.0;
// Chance per tick that the tube drops out, like a dying neon sign.
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
uniform float flicker_speed = 9.0;
// Hard on/off blinking (aviation lights, signs). 0 disables.
uniform float blink_rate = 0.0;
// Slow brightness breathing amount.
uniform float pulse = 0.0;
uniform float seed = 0.0;
// For MultiMesh use: INSTANCE_CUSTOM.rgb replaces `color` and .a replaces `seed`.
uniform bool use_instance_custom = false;

varying flat vec4 instance_data;

void vertex() {
	instance_data = INSTANCE_CUSTOM;
	POSITION = ps1_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	vec3 base_color = use_instance_custom ? instance_data.rgb : color.rgb;
	float tick_seed = use_instance_custom ? instance_data.a : seed;
	float f = 1.0;
	if (flicker > 0.0) {
		float tick = floor(TIME * flicker_speed + tick_seed * 31.0);
		f = ps1_hash(vec2(tick, tick_seed)) < flicker * 0.3 ? 0.12 : 1.0;
	}
	if (blink_rate > 0.0) {
		f *= step(0.45, fract(TIME * blink_rate + tick_seed));
	}
	f *= 1.0 - pulse * (0.5 + 0.5 * sin(TIME * 2.0 + tick_seed * 6.28));
	ALBEDO = base_color * energy * f;
}
