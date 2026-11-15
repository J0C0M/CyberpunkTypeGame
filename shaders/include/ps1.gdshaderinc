// Shared PS1-style vertex snapping.
// Strength comes from the `ps1_wobble` shader global (0 = off, 1 = full); see project settings.
global uniform float ps1_wobble;

// Snap grid in NDC cells. 160x90 snaps to 2x2 pixel blocks of the 640x360 game viewport.
const vec2 PS1_SNAP_GRID = vec2(160.0, 90.0);
// Snapping fades out with distance. A snapped far vertex moves by metres, and on a big triangle
// that also reaches behind the camera that offset gets magnified near the camera and warps the
// whole surface across the screen. Up close (where the wobble is visible anyway) it is safe.
const float PS1_SNAP_FADE_START = 45.0;
const float PS1_SNAP_FADE_END = 90.0;

vec4 ps1_snap(vec4 clip_position) {
	float strength = ps1_wobble * (1.0 - smoothstep(PS1_SNAP_FADE_START, PS1_SNAP_FADE_END, clip_position.w));
	if (strength <= 0.001 || clip_position.w <= 0.0) {
		return clip_position;
	}
	vec2 grid = PS1_SNAP_GRID / strength;
	vec2 ndc = clip_position.xy / clip_position.w;
	ndc = round(ndc * grid) / grid;
	return vec4(ndc * clip_position.w, clip_position.zw);
}

float ps1_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
