@tool
class_name BreakableProp
extends StaticBody3D
## Street furniture that can be shot apart: vending machines, bins, signs, barriers, crates,
## planters, lamp posts. It takes a few hits, shows damage in stages (sparks, flickering neon and
## lights, leaning and denting) and then breaks into pooled debris. Lamp posts keep a wreck
## instead: they lean over and go dark. Built with BreakableProp.create(); buildings never use it.

enum Kind { METAL, WOOD, CONCRETE }

const HIT_SOUNDS := {
	Kind.METAL: preload("res://assets/audio/prop_hit_metal.wav"),
	Kind.WOOD: preload("res://assets/audio/prop_hit_wood.wav"),
	Kind.CONCRETE: preload("res://assets/audio/prop_hit_wood.wav"),
}
const BREAK_SOUNDS := {
	Kind.METAL: preload("res://assets/audio/prop_break_metal.wav"),
	Kind.WOOD: preload("res://assets/audio/prop_break_wood.wav"),
	Kind.CONCRETE: preload("res://assets/audio/prop_break_concrete.wav"),
}
const SPARK_SOUND := preload("res://assets/audio/spark_zap.wav")

@export var max_health := 100.0
@export var kind := Kind.METAL
## Rough extent of the prop (for debris and electrical sparks), centred on `center`.
@export var size := Vector3.ONE
@export var center := Vector3(0, 0.5, 0)
@export var debris_colors := PackedColorArray([Color(0.3, 0.3, 0.33)])
@export var debris_count := 10
## Lean over and go dark when destroyed instead of breaking apart (lamp posts).
@export var keep_wreck := false
## Electrical props spark now and then once damaged.
@export var electrical := false

var visual: Node3D
var _health: Damageable
var _stage := 0
var _lean_axis := Vector3.RIGHT
var _lights: Array[Light3D] = []
var _light_energy := PackedFloat32Array()
var _neon_overrides: Array[ShaderMaterial] = []
var _spark_timer := 0.0


## Creates a prop from merged geometry `geo` with box colliders [[size, local transform], ...].
static func create(parent: Node, xform: Transform3D, geo: GeoBatch, colliders: Array, health: float, kind: Kind, extent: Vector3, colors: PackedColorArray) -> BreakableProp:
	var prop := BreakableProp.new()
	prop.transform = xform
	prop.max_health = health
	prop.kind = kind
	prop.size = extent
	prop.center = Vector3(0, extent.y * 0.5, 0)
	prop.debris_colors = colors
	prop.visual = Node3D.new()
	prop.visual.name = "Visual"
	prop.add_child(prop.visual)
	geo.build_into(prop.visual, "Mesh")
	for entry in colliders:
		var shape := BoxShape3D.new()
		shape.size = entry[0]
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.transform = entry[1]
		prop.add_child(collider)
	parent.add_child(prop)
	return prop


## Adds a light that dims, flickers and dies along with the prop (parents it to the visual if needed).
func add_light(light: Light3D) -> void:
	if light.get_parent() == null:
		visual.add_child(light)
	_lights.append(light)
	_light_energy.append(light.light_energy)


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	if visual == null:
		visual = get_node_or_null("Visual")
	if Engine.is_editor_hint() or visual == null:
		return
	add_to_group("resettable")
	# Anything waist-high or taller is something to hide behind.
	if size.y >= 0.8:
		add_to_group("cover")
	_health = Damageable.new()
	_health.max_health = max_health
	add_child(_health)
	Damageable.register(self, _health, &"prop")
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_broken)
	_lean_axis = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	# Private copies of the neon surfaces so this prop can flicker on its own.
	for mesh_instance in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mesh_instance as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface) as ShaderMaterial
			if mat and mat.shader == MatLib.NEON_SHADER:
				var copy := mat.duplicate() as ShaderMaterial
				(mesh_instance as MeshInstance3D).set_surface_override_material(surface, copy)
				_neon_overrides.append(copy)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _stage == 0 or _health.is_dead:
		return
	for i in _lights.size():
		if randf() < 0.08 * _stage:
			_lights[i].light_energy = _light_energy[i] * randf_range(0.1, 1.0)
	if electrical:
		_spark_timer -= delta
		if _spark_timer <= 0.0:
			_spark_timer = randf_range(0.6, 2.5) / _stage
			var point := global_transform * (center + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.5), randf_range(-0.5, 0.5)) * size)
			ImpactEffects.spawn_sparks_at(self, point, Vector3.UP)
			SfxPool.play_at(self, SPARK_SOUND, point, -14.0, 0.2, 3.0)


func is_broken() -> bool:
	return _health != null and _health.is_dead


## Back to new (when the city resets while the player sleeps).
func reset() -> void:
	if _health == null:
		return
	_health.restore()
	_stage = 0
	visual.visible = true
	visual.transform = Transform3D.IDENTITY
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", false)
	for i in _lights.size():
		_lights[i].light_energy = _light_energy[i]
		_lights[i].visible = true
	for mat in _neon_overrides:
		mat.set_shader_parameter("flicker", 0.0)
		mat.set_shader_parameter("energy", float(mat.get_meta(&"energy", mat.get_shader_parameter("energy"))))


func _on_damaged(hit: HitInfo) -> void:
	if _health.is_dead:
		return
	if hit.kind == HitInfo.Kind.BULLET:
		ImpactEffects.spawn_sparks_at(self, hit.position, hit.normal)
		SfxPool.play_at(self, HIT_SOUNDS[kind], hit.position, -8.0, 0.15, 4.0)
	var stage := 0
	if _health.health_ratio() <= 0.34:
		stage = 2
	elif _health.health_ratio() <= 0.67:
		stage = 1
	if stage != _stage:
		_stage = stage
		_show_stage()


## Visible damage: the prop leans and dents a little more each stage, neon starts to flicker.
func _show_stage() -> void:
	var lean := deg_to_rad(4.0) * _stage
	visual.transform = Transform3D(Basis(_lean_axis, lean).scaled(Vector3(1.0, 1.0 - 0.03 * _stage, 1.0)), Vector3.ZERO)
	for mat in _neon_overrides:
		mat.set_shader_parameter("flicker", 0.3 * _stage)


func _on_broken(hit: HitInfo) -> void:
	SfxPool.play_at(self, BREAK_SOUNDS[kind], global_transform * center, -3.0, 0.1, 6.0)
	EventBus.emit_danger(global_position, 10.0, EventBus.SEVERITY_SHOT, hit.source)
	for light in _lights:
		light.visible = false
	for mat in _neon_overrides:
		if not mat.has_meta(&"energy"):
			mat.set_meta(&"energy", mat.get_shader_parameter("energy"))
		mat.set_shader_parameter("energy", 0.0)
	if keep_wreck:
		# Snap over at the base and stay there, dark.
		visual.transform = Transform3D(Basis(_lean_axis, deg_to_rad(randf_range(28.0, 40.0))), Vector3.ZERO)
		ImpactEffects.spawn_sparks_at(self, global_transform * Vector3(0, size.y * 0.9, 0), Vector3.UP)
		_spawn_debris(hit, 4, Vector2(0.06, 0.18))
		return
	visual.visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	_spawn_debris(hit, debris_count, Vector2(0.12, 0.38))


func _spawn_debris(hit: HitInfo, count: int, piece_size: Vector2) -> void:
	var pool := DebrisPool.get_pool(self)
	if pool == null:
		return
	var push := hit.direction * (3.0 if hit.kind == HitInfo.Kind.BULLET else 8.0)
	var box := global_transform.translated_local(center)
	var per_color := maxi(1, count / maxi(1, debris_colors.size()))
	for color in debris_colors:
		pool.burst(DebrisPool.Shape.CHUNK, box, size * 0.4, per_color, piece_size, MatLib.surface(color, 0.6, 0.3), push, 3.0)


## Ground outline (world space) for the enemies' navmesh and their cover search.
func cover_outline() -> PackedVector3Array:
	var outline := PackedVector3Array()
	var half := Vector2(size.x, size.z) * 0.5
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		outline.append(global_transform * Vector3(corner.x, 0.0, corner.y))
	return outline


func cover_height() -> float:
	return size.y
