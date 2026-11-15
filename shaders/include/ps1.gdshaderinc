// Shared PS1-style vertex snapping.
// Strength comes from the `ps1_wobble` shader global (0 = off, 1 = full); see project settings.
global uniform float ps1_wobble;

// Snap grid in NDC cells. 160x90 snaps to 2x2 pixel blocks of the 640x360 game viewport.
const vec2 PS1_SNAP_GRID = vec2(160.0, 90.0);

vec4 ps1_snap(vec4 clip_position) {
	if (ps1_wobble <= 0.001 || clip_position.w <= 0.0) {
		return clip_position;
	}
	vec2 grid = PS1_SNAP_GRID / ps1_wobble;
	vec2 ndc = clip_position.xy / clip_position.w;
	ndc = round(ndc * grid) / grid;
	return vec4(ndc * clip_position.w, clip_position.zw);
}

float ps1_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
