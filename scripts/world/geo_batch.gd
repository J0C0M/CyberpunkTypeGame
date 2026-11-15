@tool
class_name GeoBatch
extends RefCounted
## Collects low-poly primitives (boxes, cylinders, spheres, neon lines) and merges them into a
## single mesh with one surface per material. The procedural builders use it so a whole room or
## building ends up as one MeshInstance3D instead of hundreds of nodes.
##
## Godot treats clockwise triangles (seen from outside) as front faces; `_tri` enforces that.

const _BOX_FACES := [
	# outward normal, u axis, v axis (u x v = normal)
	[Vector3.RIGHT, Vector3(0, 0, -1), Vector3.UP],
	[Vector3.LEFT, Vector3(0, 0, 1), Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3(0, 0, -1)],
	[Vector3.DOWN, Vector3.RIGHT, Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3.RIGHT, Vector3.UP],
	[Vector3(0, 0, -1), Vector3.LEFT, Vector3.UP],
]

var _tools := {}
var _materials: Array[Material] = []


func is_empty() -> bool:
	return _materials.is_empty()


## Box of `size` centred on `xform.origin` and rotated by `xform.basis` (keep the basis unscaled).
func add_box(size: Vector3, xform: Transform3D, material: Material) -> void:
	var st := _tool(material)
	var h := size * 0.5
	for face in _BOX_FACES:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var hu := absf(u.dot(h))
		var hv := absf(v.dot(h))
		var c := n * absf(n.dot(h))
		var p0 := c - u * hu - v * hv
		var p1 := c + u * hu - v * hv
		var p2 := c + u * hu + v * hv
		var p3 := c - u * hu + v * hv
		var su := hu * 2.0
		var sv := hv * 2.0
		var wn := (xform.basis * n).normalized()
		_vertex(st, wn, Vector2(0, sv), xform * p0)
		_vertex(st, wn, Vector2(su, 0), xform * p2)
		_vertex(st, wn, Vector2(su, sv), xform * p1)
		_vertex(st, wn, Vector2(0, sv), xform * p0)
		_vertex(st, wn, Vector2(0, 0), xform * p3)
		_vertex(st, wn, Vector2(su, 0), xform * p2)


## Convenience: axis-aligned box given its centre.
func add_box_at(size: Vector3, center: Vector3, material: Material) -> void:
	add_box(size, Transform3D(Basis.IDENTITY, center), material)


## Flat-shaded prism/cylinder/cone along local Y, centred on `xform.origin`.
func add_cylinder(radius_bottom: float, radius_top: float, height: float, sides: int, xform: Transform3D, material: Material, caps := true) -> void:
	var st := _tool(material)
	var hh := height * 0.5
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var b0 := Vector3(cos(a0) * radius_bottom, -hh, sin(a0) * radius_bottom)
		var b1 := Vector3(cos(a1) * radius_bottom, -hh, sin(a1) * radius_bottom)
		var t0 := Vector3(cos(a0) * radius_top, hh, sin(a0) * radius_top)
		var t1 := Vector3(cos(a1) * radius_top, hh, sin(a1) * radius_top)
		var mid := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		if radius_bottom > 0.0:
			_tri(st, xform, b0, b1, t1, mid)
		if radius_top > 0.0:
			_tri(st, xform, b0, t1, t0, mid)
		if caps:
			if radius_top > 0.0:
				_tri(st, xform, Vector3(0, hh, 0), t0, t1, Vector3.UP)
			if radius_bottom > 0.0:
				_tri(st, xform, Vector3(0, -hh, 0), b0, b1, Vector3.DOWN)


## Low-poly UV sphere (scale the basis for ellipsoids).
func add_sphere(radius: float, xform: Transform3D, material: Material, segments := 8, rings := 5) -> void:
	var st := _tool(material)
	for r in rings:
		var p0 := PI * r / rings
		var p1 := PI * (r + 1) / rings
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var v00 := _sphere_point(radius, p0, a0)
			var v01 := _sphere_point(radius, p0, a1)
			var v10 := _sphere_point(radius, p1, a0)
			var v11 := _sphere_point(radius, p1, a1)
			var out := (v00 + v01 + v10 + v11) * 0.25
			if r > 0:
				_tri(st, xform, v00, v01, v11, out)
			if r < rings - 1:
				_tri(st, xform, v00, v11, v10, out)


## Thin square-section bar from `a` to `b` (neon tubes, cables, frames, poles).
func add_bar(a: Vector3, b: Vector3, thickness: float, material: Material) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.0001:
		return
	var x := dir / length
	var up := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var z := x.cross(up).normalized()
	var y := z.cross(x).normalized()
	add_box(Vector3(length + thickness, thickness, thickness), Transform3D(Basis(x, y, z), (a + b) * 0.5), material)


## Connected bars through `points` (neon art). Set `closed` to join the last point to the first.
func add_polyline(points: PackedVector3Array, thickness: float, material: Material, closed := false) -> void:
	for i in points.size() - 1:
		add_bar(points[i], points[i + 1], thickness, material)
	if closed and points.size() > 2:
		add_bar(points[points.size() - 1], points[0], thickness, material)


## Builds the merged mesh, one surface per material.
func build_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for material in _materials:
		(_tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


## Builds a MeshInstance3D holding the merged mesh. Returns null when nothing was added.
func build(node_name: String, cast_shadows := true) -> MeshInstance3D:
	if is_empty():
		return null
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = build_mesh()
	if not cast_shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Builds and parents the mesh in one go.
func build_into(parent: Node, node_name: String, cast_shadows := true) -> MeshInstance3D:
	var instance := build(node_name, cast_shadows)
	if instance:
		parent.add_child(instance)
	return instance


func _tool(material: Material) -> SurfaceTool:
	if not _tools.has(material):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[material] = st
		_materials.append(material)
	return _tools[material]


func _vertex(st: SurfaceTool, normal: Vector3, uv: Vector2, position: Vector3) -> void:
	st.set_normal(normal)
	st.set_uv(uv)
	st.add_vertex(position)


## Adds a flat-shaded triangle, flipping it if needed so it faces `outward` (local space).
func _tri(st: SurfaceTool, xform: Transform3D, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var cross := (b - a).cross(c - a)
	if cross.length_squared() < 1e-12:
		return
	if cross.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
		cross = -cross
	var normal := (xform.basis * -cross).normalized()
	_vertex(st, normal, Vector2(a.x + a.z, a.y), xform * a)
	_vertex(st, normal, Vector2(b.x + b.z, b.y), xform * b)
	_vertex(st, normal, Vector2(c.x + c.z, c.y), xform * c)


func _sphere_point(radius: float, polar: float, azimuth: float) -> Vector3:
	return Vector3(sin(polar) * cos(azimuth), cos(polar), sin(polar) * sin(azimuth)) * radius
