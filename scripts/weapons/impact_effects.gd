class_name ImpactEffects
extends Node3D
## Bullet impacts: pooled bullet-hole decals, spark bursts and a brief flash of light, plus the
## stylised hit bursts and stains for people. Lives once in the world (group "impact_effects").

@export var max_decals := 96
@export var spark_pool_size := 8

var _decals: Array[Decal] = []
var _next_decal := 0
var _sparks: Array[GPUParticles3D] = []
var _next_spark := 0
var _blood: Array[GPUParticles3D] = []
var _next_blood := 0
var _stains: Array[Decal] = []
var _next_stain := 0
var _light: OmniLight3D
var _light_time := 0.0


func _ready() -> void:
	add_to_group("impact_effects")
	add_to_group("night_cleanup")
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
		var sparks := _make_burst(Color(1.0, 0.65, 0.25), 7.0, 14, Vector2(2.5, 6.5))
		add_child(sparks)
		_sparks.append(sparks)
		var blood := _make_burst(Color(0.55, 0.02, 0.06), 1.2, 12, Vector2(1.0, 3.2))
		add_child(blood)
		_blood.append(blood)
	var stain_texture := _stain_texture()
	for i in 12:
		var stain := Decal.new()
		stain.texture_albedo = stain_texture
		stain.size = Vector3(1.6, 0.6, 1.6)
		stain.visible = false
		add_child(stain)
		_stains.append(stain)
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


## Bullet holes and stains are gone by the next night.
func clear_for_new_night() -> void:
	for decal in _decals + _stains:
		decal.visible = false


## Small burst of dark red cubes where a person is hit.
static func spawn_blood_at(node: Node, point: Vector3, normal: Vector3) -> void:
	var effects := node.get_tree().get_first_node_in_group("impact_effects") as ImpactEffects
	if effects:
		var burst := effects._blood[effects._next_blood]
		effects._next_blood = (effects._next_blood + 1) % effects._blood.size()
		burst.global_transform = Transform3D(effects._basis_from_normal(normal), point)
		burst.restart()


## Dark stain on the ground under a body.
static func spawn_stain_at(node: Node, point: Vector3) -> void:
	var effects := node.get_tree().get_first_node_in_group("impact_effects") as ImpactEffects
	if effects:
		var stain := effects._stains[effects._next_stain]
		effects._next_stain = (effects._next_stain + 1) % effects._stains.size()
		stain.global_transform = Transform3D(Basis(Vector3.UP, randf() * TAU), point)
		stain.visible = true


## Sparks and a flash without a bullet hole (for props that have their own damage states).
static func spawn_sparks_at(node: Node, point: Vector3, normal: Vector3) -> void:
	var effects := node.get_tree().get_first_node_in_group("impact_effects") as ImpactEffects
	if effects:
		effects.spawn_impact(point, normal, false)


## Basis whose +Y axis is the surface normal (decals project along -Y).
func _basis_from_normal(normal: Vector3) -> Basis:
	var up := normal.normalized()
	var reference := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var x := reference.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)


func _make_burst(color: Color, energy: float, amount: int, speed: Vector2) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 40.0
	process.initial_velocity_min = speed.x
	process.initial_velocity_max = speed.y
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
	spark_mesh.material = MatLib.neon(color, energy)
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 0.45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.process_material = process
	particles.draw_pass_1 = spark_mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


## Irregular dark red blot, generated once at startup.
func _stain_texture() -> ImageTexture:
	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var offset := Vector2(x + 0.5, y + 0.5) - center
			var wobble := 0.75 + 0.12 * sin(offset.angle() * 5.0) + 0.08 * sin(offset.angle() * 11.0 + 1.3)
			var d := offset.length() / (size * 0.5 * wobble)
			var alpha := (1.0 - smoothstep(0.7, 0.95, d)) * 0.85
			image.set_pixel(x, y, Color(0.22, 0.01, 0.03, alpha))
	return ImageTexture.create_from_image(image)


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
