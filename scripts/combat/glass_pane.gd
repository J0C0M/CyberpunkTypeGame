@tool
class_name GlassPane
extends StaticBody3D
## A pane of glass that shatters from a single bullet (or an explosion). The pane and its
## collision disappear, shards fly out along the hit and a shatter sound plays.
## Size is the full box (x = width, y = height, z = thickness), centred on this node.

const SHATTER_SOUNDS := [preload("res://assets/audio/glass_shatter_1.wav"), preload("res://assets/audio/glass_shatter_2.wav")]

@export var size := Vector3(2.0, 2.5, 0.04)
@export var tint := Color(0.4, 0.7, 1.0, 0.1)

var _mesh: MeshInstance3D
var _collider: CollisionShape3D
var _health: Damageable


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	add_to_group("resettable")
	for child in get_children():
		child.queue_free()
	var geo := GeoBatch.new()
	geo.add_box_at(size, Vector3.ZERO, MatLib.glass(tint))
	_mesh = geo.build("Glass", false)
	add_child(_mesh)
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, maxf(size.z, 0.06))
	_collider = CollisionShape3D.new()
	_collider.shape = shape
	add_child(_collider)
	if Engine.is_editor_hint():
		return
	_health = Damageable.new()
	_health.max_health = 1.0
	add_child(_health)
	Damageable.register(self, _health, &"glass")
	_health.died.connect(_shatter)


func is_broken() -> bool:
	return _health != null and _health.is_dead


## Puts the pane back (used when the city resets while the player sleeps).
func reset() -> void:
	if _health == null:
		return
	_health.restore()
	_mesh.visible = true
	_collider.set_deferred("disabled", false)


func _shatter(hit: HitInfo) -> void:
	_mesh.visible = false
	_collider.set_deferred("disabled", true)
	var pool := DebrisPool.get_pool(self)
	if pool:
		var area := size.x * size.y
		var push := hit.direction * (4.0 if hit.kind == HitInfo.Kind.BULLET else 9.0)
		var shard_material := MatLib.glass(Color(lerpf(tint.r, 0.85, 0.5), lerpf(tint.g, 0.95, 0.5), 1.0, 0.75))
		pool.burst(DebrisPool.Shape.SHARD, global_transform, size * 0.5, clampi(int(area * 3.0), 6, 16), Vector2(0.14, 0.42), shard_material, push, 1.8)
	SfxPool.play_at(self, SHATTER_SOUNDS[randi() % SHATTER_SOUNDS.size()], global_position, -2.0, 0.12, 5.0)
	EventBus.emit_danger(global_position, 14.0, EventBus.SEVERITY_SHOT, hit.source)
