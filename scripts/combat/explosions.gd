class_name Explosions
extends Node3D
## Explosions: radial damage with falloff through the damage system (so they kill people, break
## glass and props and set off other cars), plus a flash, a fireball, smoke, debris, a sound, a big
## danger event and camera shake and knockback for the player. Lives once in the world
## (group "explosions"); call Explosions.explode() from anywhere.

const SOUND := preload("res://assets/audio/explosion.wav")
## The player, people, props and cars (physics layers 2, 3 and 4).
const DAMAGE_MASK := 2 | 4 | 8

@export var effect_slots := 4

var _fireballs: Array[GPUParticles3D] = []
var _smoke: Array[GPUParticles3D] = []
var _flashes: Array[OmniLight3D] = []
var _flash_time := PackedFloat32Array()
var _next := 0


static func explode(node: Node, position: Vector3, radius: float, damage: float, source: Node = null, exclude: Array[RID] = []) -> void:
	var explosions := node.get_tree().get_first_node_in_group("explosions") as Explosions
	if explosions:
		explosions._explode(position, radius, damage, source, exclude)


func _ready() -> void:
	add_to_group("explosions")
	for i in effect_slots:
		var fireball := _make_particles(42, 0.9, Color(1.0, 0.85, 0.4), Color(1.0, 0.25, 0.05), true)
		add_child(fireball)
		_fireballs.append(fireball)
		var smoke := _make_particles(24, 3.5, Color(0.12, 0.1, 0.12, 0.7), Color(0.05, 0.05, 0.06, 0.0), false)
		add_child(smoke)
		_smoke.append(smoke)
		var flash := OmniLight3D.new()
		flash.light_color = Color(1.0, 0.6, 0.25)
		flash.omni_range = 26.0
		flash.visible = false
		add_child(flash)
		_flashes.append(flash)
	_flash_time.resize(effect_slots)
	_flash_time.fill(0.0)


func _process(delta: float) -> void:
	for i in _flashes.size():
		if _flash_time[i] > 0.0:
			_flash_time[i] -= delta
			_flashes[i].light_energy = 14.0 * maxf(_flash_time[i], 0.0) / 0.45
			_flashes[i].visible = _flash_time[i] > 0.0


func _explode(position: Vector3, radius: float, damage: float, source: Node, exclude: Array[RID]) -> void:
	var slot := _next
	_next = (_next + 1) % effect_slots
	_fireballs[slot].global_position = position
	_fireballs[slot].restart()
	_smoke[slot].global_position = position + Vector3.UP * 0.5
	_smoke[slot].restart()
	_flashes[slot].global_position = position + Vector3.UP * 1.5
	_flashes[slot].visible = true
	_flash_time[slot] = 0.45
	SfxPool.play_at(self, SOUND, position, 6.0, 0.08, 18.0)
	EventBus.emit_danger(position, 60.0, EventBus.SEVERITY_EXPLOSION, source)
	_apply_damage(position, radius, damage, source, exclude)
	_shake_player(position, radius)


func _apply_damage(position: Vector3, radius: float, damage: float, source: Node, exclude: Array[RID]) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = DAMAGE_MASK
	query.exclude = exclude
	var reached := {}
	for result in get_world_3d().direct_space_state.intersect_shape(query, 96):
		var collider: Object = result["collider"]
		var target := Damageable.find(collider)
		if target == null or reached.has(target):
			continue
		reached[target] = true
		var center := (collider as Node3D).global_position + Vector3.UP * 0.6
		var offset := center - position
		var falloff := clampf(1.0 - offset.length() / radius, 0.2, 1.0)
		var direction := offset.normalized() if offset.length_squared() > 0.01 else Vector3.UP
		Damageable.deliver(collider, HitInfo.create(damage * falloff, center, -direction, direction, source, HitInfo.Kind.EXPLOSION, 12.0 * falloff))


func _shake_player(position: Vector3, radius: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var offset := player.global_position - position
	var distance := offset.length()
	player.apply_shake(clampf(1.0 - distance / (radius * 4.0), 0.0, 1.0) * 1.2)
	if distance < radius * 1.6:
		var push := clampf(1.0 - distance / (radius * 1.6), 0.0, 1.0)
		var away := Vector3(offset.x, 0.0, offset.z).normalized()
		player.apply_knockback(away * 11.0 * push + Vector3.UP * 4.0 * push)


func _make_particles(amount: int, lifetime: float, start: Color, end: Color, hot: bool) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.8
	process.direction = Vector3.UP
	process.spread = 180.0 if hot else 25.0
	process.initial_velocity_min = 4.0 if hot else 1.5
	process.initial_velocity_max = 10.0 if hot else 3.5
	process.gravity = Vector3(0, 1.5 if hot else 0.8, 0)
	process.damping_min = 4.0
	process.damping_max = 6.0
	process.scale_min = 1.0
	process.scale_max = 2.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.6))
	grow.add_point(Vector2(1, 2.4 if hot else 4.0))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var ramp := Gradient.new()
	ramp.set_color(0, start)
	ramp.set_color(1, end)
	if hot:
		ramp.add_point(0.5, Color(1.0, 0.4, 0.08, 0.9))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if hot:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.emission_enabled = true
		material.emission = Color(1.0, 0.5, 0.15)
		material.emission_energy_multiplier = 3.0
	var quad := QuadMesh.new()
	quad.size = Vector2(2.2, 2.2) if hot else Vector2(1.8, 1.8)
	quad.material = material
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.92 if hot else 0.6
	particles.emitting = false
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.visibility_aabb = AABB(Vector3(-12, -2, -12), Vector3(24, 24, 24))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles
