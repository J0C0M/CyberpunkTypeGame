// Flying cars: each MultiMesh instance sits on a straight lane (its transform) and slides along
// local +X in the vertex shader, wrapping around, so thousands of moving lights cost no CPU.
// INSTANCE_CUSTOM: x = speed (m/s, negative drives backwards), y = phase (0..1), z = lane length.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 head_color : source_color = vec3(1.0, 0.92, 0.8);
uniform vec3 tail_color : source_color = vec3(1.0, 0.12, 0.2);
uniform float energy = 6.0;

varying float front;

void vertex() {
	float speed = INSTANCE_CUSTOM.x;
	float lane_length = INSTANCE_CUSTOM.z;
	float travel = fract(TIME * speed / lane_length + INSTANCE_CUSTOM.y) * lane_length - lane_length * 0.5;
	front = step(0.0, VERTEX.x * sign(speed));
	VERTEX.x += travel;
}

void fragment() {
	ALBEDO = mix(tail_color, head_color, front) * energy;
}
