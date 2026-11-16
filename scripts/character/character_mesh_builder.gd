@tool
class_name CharacterMeshBuilder
extends RefCounted
## Collects boxes for one character part and turns them into a mesh. Every box has a slim shape
## and a muscular shape (the "muscle" blend shape), is skinned rigidly to one bone, and is either
## textured from the character atlas (per-face UV rectangles) or coloured through its vertex colour.

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()
var _bones := PackedInt32Array()
var _weights := PackedFloat32Array()
var _muscle_verts := PackedVector3Array()
var _muscle_normals := PackedVector3Array()


func is_empty() -> bool:
	return _verts.is_empty()


## A box at `center` with `size` (slim) that becomes `muscle_center`/`muscle_size` at full muscle,
## turned by `basis`, skinned to `bone`. `atlas_key` picks the box's six face rectangles in the
## character atlas; &"" uses the white texel and `color` (alpha below 1 glows).
func add_box(center: Vector3, size: Vector3, muscle_center: Vector3, muscle_size: Vector3, bone: int, atlas_key := &"", color := Color.WHITE, basis := Basis.IDENTITY) -> void:
	var half := size * 0.5
	var muscle_half := muscle_size * 0.5
	for face in 6:
		var n: Vector3 = CharacterAtlas.FACES[face][0]
		var u: Vector3 = CharacterAtlas.FACES[face][1]
		var v: Vector3 = CharacterAtlas.FACES[face][2]
		var rect := CharacterAtlas.face_uv(atlas_key, face) if atlas_key != &"" else CharacterAtlas.white_uv()
		var normal := (basis * n).normalized()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var local := n * absf(n.dot(half)) + u * corner.x * absf(u.dot(half)) + v * corner.y * absf(v.dot(half))
			var muscle_local := n * absf(n.dot(muscle_half)) + u * corner.x * absf(u.dot(muscle_half)) + v * corner.y * absf(v.dot(muscle_half))
			_verts.append(center + basis * local)
			_muscle_verts.append(muscle_center + basis * muscle_local)
			_normals.append(normal)
			_muscle_normals.append(normal)
			_uvs.append(rect.position + rect.size * Vector2((corner.x + 1.0) * 0.5, (1.0 - corner.y) * 0.5))
			_colors.append(color)
			_bones.append_array(PackedInt32Array([bone, 0, 0, 0]))
			_weights.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))


## A box that keeps its shape (details that don't bulge with muscle, but move with the surface).
func add_rigid_box(center: Vector3, muscle_center: Vector3, size: Vector3, bone: int, atlas_key := &"", color := Color.WHITE, basis := Basis.IDENTITY) -> void:
	add_box(center, size, muscle_center, size, bone, atlas_key, color, basis)


## The mesh, with bone weights when `skinned` (for a Skeleton3D) and a "muscle" blend shape.
func build(skinned := true) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_COLOR] = _colors
	if skinned:
		arrays[Mesh.ARRAY_BONES] = _bones
		arrays[Mesh.ARRAY_WEIGHTS] = _weights
	var shape := []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = _muscle_verts
	shape[Mesh.ARRAY_NORMAL] = _muscle_normals
	# The shape holds absolute positions (ArrayMesh defaults to relative ones).
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_NORMALIZED
	mesh.add_blend_shape("muscle")
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape])
	return mesh
