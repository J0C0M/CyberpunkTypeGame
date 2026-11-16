// A mirror's glass: shows its SubViewport (the reflected view), flipped left-right, with a slight
// tint and darker edges. Pixels stay crisp (low-resolution reflection, like the rest of the game).
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://shaders/include/ps1.gdshaderinc"

uniform sampler2D reflection : source_color, filter_nearest, hint_default_black;
uniform vec4 tint : source_color = vec4(0.92, 0.95, 1.0, 1.0);

void vertex() {
	POSITION = ps1_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
}

void fragment() {
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	vec3 c = texture(reflection, uv).rgb * tint.rgb;
	vec2 edge = abs(UV - 0.5) * 2.0;
	c *= 1.0 - 0.25 * smoothstep(0.75, 1.0, max(edge.x, edge.y));
	ALBEDO = c;
}
