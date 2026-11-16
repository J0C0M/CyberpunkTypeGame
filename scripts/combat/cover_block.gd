class_name CoverBlock
extends StaticBody3D
## A solid box something can hide behind (crate stacks, concrete blocks): a mesh and a collider in
## the "cover" group, with the same outline/height methods as cars and props.

var size := Vector3.ONE


static func create(parent: Node, xform: Transform3D, box_size: Vector3, material: Material, trim: Material = null) -> CoverBlock:
	var block := CoverBlock.new()
	block.size = box_size
	block.transform = xform
	var geo := GeoBatch.new()
	geo.add_box_at(box_size, Vector3(0, box_size.y * 0.5, 0), material)
	if trim:
		geo.add_box_at(Vector3(box_size.x + 0.02, 0.05, box_size.z + 0.02), Vector3(0, box_size.y * 0.8, 0), trim)
	geo.build_into(block, "Mesh")
	var shape := BoxShape3D.new()
	shape.size = box_size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0, box_size.y * 0.5, 0)
	block.add_child(collider)
	parent.add_child(block)
	return block


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("cover")


func cover_outline() -> PackedVector3Array:
	var outline := PackedVector3Array()
	var half := Vector2(size.x, size.z) * 0.5
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		outline.append(global_transform * Vector3(corner.x, 0.0, corner.y))
	return outline


func cover_height() -> float:
	return size.y
