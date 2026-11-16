class_name DebrisPool
extends Node3D
## Pooled physics debris: glass shards and chunks thrown out when things break.
## A fixed number of RigidBody3Ds is created up front and recycled oldest-first, so a big
## chain reaction can never flood the physics engine. Lives once in the world (group "debris_pool").

enum Shape { CHUNK, SHARD }

@export var pool_size := 90
@export var lifetime := 3.5
@export var fade_time := 0.6

var _pieces: Array[RigidBody3D] = []
var _meshes: Array[MeshInstance3D] = []
var _shapes: Array[BoxShape3D] = []
var _age := PackedFloat32Array()
var _size: Array[Vector3] = []
var _next := 0
var _unit_meshes: Array[Mesh] = []


static func get_pool(node: Node) -> DebrisPool:
	return node.get_tree().get_first_node_in_group("debris_pool") as DebrisPool


func _ready() -> void:
	add_to_group("debris_pool")
	add_to_group("night_cleanup")
	var chunk := GeoBatch.new()
	chunk.add_box_at(Vector3.ONE, Vector3.ZERO, MatLib.surface(Color.WHITE))
	var shard := GeoBatch.new()
	shard.add_cylinder(0.5, 0.5, 1.0, 3, Transform3D.IDENTITY, MatLib.surface(Color.WHITE))
	_unit_meshes = [chunk.build_mesh(), shard.build_mesh()]
	for i in pool_size:
		var body := RigidBody3D.new()
		body.collision_layer = 64
		body.collision_mask = 1 | 8
		body.mass = 0.4
		body.process_mode = Node.PROCESS_MODE_DISABLED
		body.visible = false
		var shape := BoxShape3D.new()
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		var mesh := MeshInstance3D.new()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mesh)
		add_child(body)
		_pieces.append(body)
		_meshes.append(mesh)
		_shapes.append(shape)
		_size.append(Vector3.ONE)
	_age.resize(pool_size)
	_age.fill(-1.0)


func clear_for_new_night() -> void:
	for i in pool_size:
		_age[i] = -1.0
		_pieces[i].process_mode = Node.PROCESS_MODE_DISABLED
		_pieces[i].visible = false


## Throws one piece. `size` is its extent in metres (for shards, y is the thickness).
func spawn(shape: Shape, xform: Transform3D, size: Vector3, material: Material, velocity: Vector3, spin := 6.0) -> void:
	var i := _next
	_next = (_next + 1) % pool_size
	var body := _pieces[i]
	_meshes[i].mesh = _unit_meshes[shape]
	_meshes[i].material_override = material
	_meshes[i].scale = size
	_shapes[i].size = Vector3(maxf(size.x * 0.8, 0.04), maxf(size.y, 0.03), maxf(size.z * 0.8, 0.04))
	_size[i] = size
	body.process_mode = Node.PROCESS_MODE_INHERIT
	body.visible = true
	body.global_transform = xform.orthonormalized()
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spin
	_age[i] = 0.0


## Throws `count` pieces from random points inside a box (centre + basis + half extents).
func burst(shape: Shape, box: Transform3D, half_extents: Vector3, count: int, piece_size: Vector2, material: Material, push: Vector3, scatter := 2.5) -> void:
	for n in count:
		var local := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * half_extents
		var size_x := randf_range(piece_size.x, piece_size.y)
		var size := Vector3(size_x, 0.02 if shape == Shape.SHARD else size_x * randf_range(0.5, 1.0), randf_range(piece_size.x, piece_size.y))
		var velocity := push + Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-1, 1)) * scatter
		var basis := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
		spawn(shape, Transform3D(basis, box * local), size, material, velocity)


func _physics_process(delta: float) -> void:
	for i in pool_size:
		if _age[i] < 0.0:
			continue
		_age[i] += delta
		var left := lifetime - _age[i]
		if left <= 0.0:
			_age[i] = -1.0
			_pieces[i].process_mode = Node.PROCESS_MODE_DISABLED
			_pieces[i].visible = false
		elif left < fade_time:
			_meshes[i].scale = _size[i] * (left / fade_time)
