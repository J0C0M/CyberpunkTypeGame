class_name StreetSurface
extends RefCounted
## The street shader's puddle pattern, reproduced on the CPU so footsteps splash exactly in the
## puddles you can see. Keep in sync with shaders/street_ground.gdshader.

const PUDDLE_SCALE := 0.12


## True when world position `p` is in a puddle on a street surface with `amount` puddles.
static func is_wet(p: Vector3, amount: float) -> bool:
	if amount <= 0.0:
		return false
	var flat := Vector2(p.x, p.z)
	var n := _value_noise(flat * PUDDLE_SCALE) * 0.65 + _value_noise(flat * PUDDLE_SCALE * 3.1 + Vector2(17.0, 17.0)) * 0.35
	return smoothstep(1.0 - amount, 1.0 - amount + 0.08, n) > 0.5


static func _fract(x: float) -> float:
	return x - floorf(x)


## Same as ps1_hash() in shaders/include/ps1.gdshaderinc.
static func _hash(p: Vector2) -> float:
	p = Vector2(_fract(p.x * 123.34), _fract(p.y * 456.21))
	var d := p.dot(p + Vector2(45.32, 45.32))
	p += Vector2(d, d)
	return _fract(p.x * p.y)


static func _value_noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	var u := f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := lerpf(_hash(i), _hash(i + Vector2(1, 0)), u.x)
	var b := lerpf(_hash(i + Vector2(0, 1)), _hash(i + Vector2(1, 1)), u.x)
	return lerpf(a, b, u.y)
