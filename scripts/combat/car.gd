@tool
class_name Car
extends StaticBody3D
## Parked low-poly sedan that can be shot up. The engine block under the hood is a hit zone that
## takes far more damage. Below half health it smokes, below a quarter it burns, and soon after
## it explodes (Explosions.explode, so it can chain into other cars) and stays a burnt-out wreck.
## Faces local +X. Use Car.create() or set the colours before adding it to the tree.

const HIT_SOUND := preload("res://assets/audio/prop_hit_metal.wav")
const FIRE_SOUND := preload("res://assets/audio/fire_loop.wav")
const ENGINE_MULTIPLIER := 4.0

@export var paint := Color(0.35, 0.03, 0.06)
@export var glow := Color(0.1, 0.88, 1.0)
@export var max_health := 300.0
@export var explosion_radius := 9.0
@export var explosion_damage := 700.0
## Seconds a burning car takes to blow up on its own.
@export var burn_time := 4.0

var _health: Damageable
var _intact: Node3D
var _wreck: Node3D
var _engine: Area3D
var _smoke: GPUParticles3D
var _fire: GPUParticles3D
var _fire_light: OmniLight3D
var _fire_sound: AudioStreamPlayer3D
var _underglow: OmniLight3D
var _burning := -1.0
var _exploded := false
var _wreck_fire := 0.0


static func create(parent: Node, xform: Transform3D, paint_color: Color, glow_color: Color) -> Car:
	var car := Car.new()
	car.transform = xform
	car.paint = paint_color
	car.glow = glow_color
	parent.add_child(car)
	return car


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	for child in get_children():
		child.queue_free()
	_intact = Node3D.new()
	_intact.name = "Intact"
	add_child(_intact)
	_wreck = Node3D.new()
	_wreck.name = "Wreck"
	_wreck.visible = false
	add_child(_wreck)
	_build_body(_intact, MatLib.surface(paint, 0.25, 0.7), MatLib.surface(Color(0.02, 0.03, 0.05), 0.08, 0.6), true)
	_build_body(_wreck, MatLib.surface(Color(0.05, 0.045, 0.04), 0.95, 0.2), MatLib.surface(Color(0.01, 0.01, 0.01), 0.9), false)
	_wreck.transform = Transform3D(Basis(Vector3.RIGHT, 0.06) * Basis(Vector3.FORWARD, -0.04), Vector3(0, -0.28, 0))
	_underglow = BuildKit.omni(_intact, Vector3(0, 0.15, 0), glow, 1.2, 3.5)
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.4, 1.6, 1.9)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0, 0.8, 0)
	add_child(collider)
	if Engine.is_editor_hint():
		return
	add_to_group("resettable")
	_health = Damageable.new()
	_health.max_health = max_health
	add_child(_health)
	Damageable.register(self, _health, &"body")
	# Engine hit zone: slightly larger than the hood so shots at the front land on it first.
	_engine = Area3D.new()
	_engine.collision_layer = 16
	_engine.collision_mask = 0
	_engine.monitoring = false
	var engine_shape := BoxShape3D.new()
	engine_shape.size = Vector3(1.3, 0.82, 2.0)
	var engine_collider := CollisionShape3D.new()
	engine_collider.shape = engine_shape
	engine_collider.position = Vector3(1.62, 0.66, 0)
	_engine.add_child(engine_collider)
	add_child(_engine)
	Damageable.register(_engine, _health, &"engine", ENGINE_MULTIPLIER)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_destroyed)
	_smoke = _make_plume(false)
	add_child(_smoke)
	_fire = _make_plume(true)
	add_child(_fire)
	_fire_light = BuildKit.omni(self, Vector3(1.4, 1.4, 0), Color(1.0, 0.45, 0.12), 0.0, 9.0)
	_fire_light.visible = false
	_fire_sound = AudioStreamPlayer3D.new()
	_fire_sound.stream = FIRE_SOUND
	_fire_sound.unit_size = 5.0
	_fire_sound.max_distance = 40.0
	_fire_sound.volume_db = -6.0
	_fire_sound.position = Vector3(1.4, 1.0, 0)
	add_child(_fire_sound)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _health == null:
		return
	if _burning >= 0.0 and not _exploded:
		_burning += delta
		_fire_light.light_energy = randf_range(2.0, 4.0)
		if _burning >= burn_time:
			_explode(null)
	elif _exploded and _wreck_fire > 0.0:
		_wreck_fire -= delta
		_fire_light.light_energy = randf_range(0.8, 1.8) * clampf(_wreck_fire / 5.0, 0.0, 1.0)
		if _wreck_fire <= 0.0:
			_fire.emitting = false
			_fire_light.visible = false
			_fire_sound.stop()


func is_wrecked() -> bool:
	return _exploded


## Back to a fresh car (when the city resets while the player sleeps).
func reset() -> void:
	if _health == null:
		return
	_health.restore()
	_exploded = false
	_burning = -1.0
	_wreck_fire = 0.0
	_intact.visible = true
	_wreck.visible = false
	_smoke.emitting = false
	_fire.emitting = false
	_fire_light.visible = false
	_fire_sound.stop()
	_engine.collision_layer = 16


func _on_damaged(hit: HitInfo) -> void:
	if hit.kind == HitInfo.Kind.BULLET:
		ImpactEffects.spawn_sparks_at(self, hit.position, hit.normal)
		SfxPool.play_at(self, HIT_SOUND, hit.position, -6.0 if hit.zone == &"engine" else -9.0, 0.2, 4.0)
	var ratio := _health.health_ratio()
	if ratio <= 0.5 and not _smoke.emitting:
		_smoke.emitting = true
	if ratio <= 0.25 and _burning < 0.0:
		_burning = 0.0
		_fire.emitting = true
		_fire_light.visible = true
		_fire_sound.play()


func _on_destroyed(hit: HitInfo) -> void:
	# A car caught in another explosion goes up a moment later, so chains ripple outwards.
	if hit.kind == HitInfo.Kind.EXPLOSION:
		await get_tree().create_timer(randf_range(0.2, 0.55)).timeout
	_explode(hit.source)


func _explode(source: Node) -> void:
	if _exploded:
		return
	_exploded = true
	_health.health = 0.0
	_health.is_dead = true
	_intact.visible = false
	_wreck.visible = true
	_engine.collision_layer = 0
	_smoke.emitting = true
	_fire.emitting = true
	_fire_light.visible = true
	_wreck_fire = 18.0
	if not _fire_sound.playing:
		_fire_sound.play()
	var pool := DebrisPool.get_pool(self)
	if pool:
		var box := global_transform.translated_local(Vector3(0, 1.0, 0))
		pool.burst(DebrisPool.Shape.CHUNK, box, Vector3(2.0, 0.5, 0.9), 8, Vector2(0.2, 0.5), MatLib.surface(paint, 0.4, 0.6), Vector3.UP * 6.0, 6.0)
		pool.burst(DebrisPool.Shape.CHUNK, box, Vector3(2.0, 0.5, 0.9), 6, Vector2(0.15, 0.4), MatLib.surface(Color(0.04, 0.04, 0.04), 0.9), Vector3.UP * 5.0, 6.0)
	Explosions.explode(self, global_transform * Vector3(0.8, 0.8, 0), explosion_radius, explosion_damage, source, [get_rid()])


func _build_body(parent: Node3D, paint_material: Material, glass: Material, lit: bool) -> void:
	var tyre := MatLib.surface(Color(0.02, 0.02, 0.02), 0.8)
	var geo := GeoBatch.new()
	geo.add_box_at(Vector3(4.4, 0.7, 1.9), Vector3(0, 0.65, 0), paint_material)
	geo.add_box_at(Vector3(2.3, 0.6, 1.7), Vector3(-0.25, 1.28, 0), glass)
	geo.add_box_at(Vector3(2.1, 0.08, 1.74), Vector3(-0.25, 1.6, 0), paint_material)
	if lit:
		for wx: float in [-1.4, 1.4]:
			for wz: float in [-0.9, 0.9]:
				geo.add_cylinder(0.36, 0.36, 0.28, 8, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(wx, 0.36, wz)), tyre)
		geo.add_box_at(Vector3(0.05, 0.12, 1.6), Vector3(2.21, 0.75, 0), MatLib.neon(Palette.WARM_WHITE, 4.0))
		geo.add_box_at(Vector3(0.05, 0.1, 1.7), Vector3(-2.21, 0.8, 0), MatLib.neon(Palette.RED, 4.0))
		geo.add_box_at(Vector3(3.6, 0.04, 1.5), Vector3(0, 0.27, 0), MatLib.neon(glow, 3.0))
	else:
		# Bare rims and a buckled hood.
		for wx: float in [-1.4, 1.4]:
			for wz: float in [-0.9, 0.9]:
				geo.add_cylinder(0.26, 0.26, 0.16, 6, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(wx, 0.3, wz)), MatLib.surface(Color(0.12, 0.1, 0.09), 0.7, 0.6))
		geo.add_box(Vector3(1.3, 0.12, 1.8), Transform3D(Basis(Vector3.FORWARD, 0.35), Vector3(1.5, 1.08, 0)), paint_material)
	geo.build_into(parent, "Body")


## Smoke (dark, slow) or flames (bright, fast) rising from the engine bay.
func _make_plume(fire: bool) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 12.0 if fire else 18.0
	process.initial_velocity_min = 1.5 if fire else 1.0
	process.initial_velocity_max = 3.0 if fire else 2.0
	process.gravity = Vector3(0.3, 1.0 if fire else 0.4, 0)
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.5, 0.1, 0.7)
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5 if fire else 0.6))
	grow.add_point(Vector2(1, 0.2 if fire else 3.0))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var ramp := Gradient.new()
	if fire:
		ramp.set_color(0, Color(1.0, 0.85, 0.35, 1.0))
		ramp.set_color(1, Color(0.9, 0.15, 0.05, 0.0))
	else:
		ramp.set_color(0, Color(0.2, 0.18, 0.2, 0.0))
		ramp.set_color(1, Color(0.06, 0.06, 0.07, 0.0))
		ramp.add_point(0.15, Color(0.16, 0.15, 0.17, 0.55))
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if fire:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9) if fire else Vector2(1.3, 1.3)
	quad.material = material
	var particles := GPUParticles3D.new()
	particles.amount = 20 if fire else 26
	particles.lifetime = 0.8 if fire else 4.0
	particles.emitting = false
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.position = Vector3(1.4, 1.0, 0)
	particles.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 16, 8))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles
