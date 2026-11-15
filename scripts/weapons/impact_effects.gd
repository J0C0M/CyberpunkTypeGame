class_name ImpactEffects
extends Node3D
## Bullet impacts: pooled bullet-hole decals, spark bursts and a brief flash of light.
## Lives once in the world (group "impact_effects"); weapons call spawn_impact().

@export var max_decals := 96
@export var spark_pool_size := 8

var _decals: Array[Decal] = []
var _next_decal := 0
var _sparks: Array[GPUParticles3D] = []
var _next_spark := 0
var _light: OmniLight3D
var _light_time := 0.0


func _ready() -> void:
	add_to_group("impact_effects")
	var hole := _bullet_hole_texture()
	for i in max_decals:
		var decal := Decal.new()
		decal.texture_albedo = hole
		decal.size = Vector3(0.14, 0.3, 0.14)
		decal.upper_fade = 0.1
		decal.lower_fade = 0.1
		decal.visible = false
		add_child(decal)
		_decals.append(decal)
	for i in spark_pool_size:
		var sparks := _make_sparks()
		add_child(sparks)
		_sparks.append(sparks)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.65, 0.3)
	_light.omni_range = 3.0
	_light.light_energy = 2.5
	_light.visible = false
	add_child(_light)


func _process(delta: float) -> void:
	if _light_time > 0.0:
		_light_time -= delta
		_light.visible = _light_time > 0.0


func spawn_impact(point: Vector3, normal: Vector3, leave_decal: bool) -> void:
	var basis := _basis_from_normal(normal)
	if leave_decal:
		var decal := _decals[_next_decal]
		_next_decal = (_next_decal + 1) % _decals.size()
		decal.global_transform = Transform3D(basis.rotated(normal, randf() * TAU), point)
		decal.visible = true
	var sparks := _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % _sparks.size()
	sparks.global_transform = Transform3D(basis, point + normal * 0.02)
	sparks.restart()
	_light.global_position = point + normal * 0.3
	_light.visible = true
	_light_time = 0.05


## Basis whose +Y axis is the surface normal (decals project along -Y).
func _basis_from_normal(normal: Vector3) -> Basis:
	var up := normal.normalized()
	var reference := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var x := reference.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)


func _make_sparks() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 40.0
	process.initial_velocity_min = 2.5
	process.initial_velocity_max = 6.5
	process.gravity = Vector3(0, -9.8, 0)
	process.scale_min = 0.6
	process.scale_max = 1.4
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	var shrink_texture := CurveTexture.new()
	shrink_texture.curve = shrink
	process.scale_curve = shrink_texture
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.025, 0.025, 0.025)
	spark_mesh.material = MatLib.neon(Color(1.0, 0.65, 0.25), 7.0)
	var particles := GPUParticles3D.new()
	particles.amount = 14
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.process_material = process
	particles.draw_pass_1 = spark_mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


## Dark round hole with a scorched rim, generated once at startup.
func _bullet_hole_texture() -> ImageTexture:
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / (size * 0.5)
			var jag := 0.08 * sin(atan2(y - center.y, x - center.x) * 7.0)
			var hole := 1.0 - smoothstep(0.22 + jag, 0.3 + jag, d)
			var scorch := (1.0 - smoothstep(0.3, 0.95, d)) * 0.7
			var alpha := clampf(maxf(hole, scorch), 0.0, 1.0)
			var shade := lerpf(0.08, 0.01, hole)
			image.set_pixel(x, y, Color(shade, shade * 0.95, shade * 0.9, alpha))
	return ImageTexture.create_from_image(image)
