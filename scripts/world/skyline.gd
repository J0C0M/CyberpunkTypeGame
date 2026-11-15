@tool
class_name Skyline
extends Node3D
## The city beyond the playable streets: about a thousand instanced towers in rings around the
## block, a few kilometre-tall arcologies, holo billboards, blinking aviation lights, flying-car
## traffic, sweeping searchlights and a painted silhouette ring at the horizon. Fog does the rest.
## Nothing here has collision; it only exists to make the city feel endless.

## The street corridors (road + frontage buildings from CityBuilder) are kept clear of towers.
const CORRIDOR_HALF_WIDTH := 31.0
const CORRIDOR_LENGTH := 470.0
## Past the end of the built streets the corridor stays open a bit longer so the vista recedes.
const VISTA_HALF_WIDTH := 36.0
const VISTA_LENGTH := 760.0

## [min radius, max radius, grid cell, min footprint, max footprint, min height, max height, chance]
const ZONES := [
	[40.0, 520.0, 55.0, 16.0, 38.0, 55.0, 230.0, 0.85],
	[520.0, 1300.0, 90.0, 24.0, 60.0, 60.0, 330.0, 0.75],
	[1300.0, 2550.0, 170.0, 40.0, 120.0, 100.0, 600.0, 0.6],
]

@export var skyline_seed := 451
@export var backdrop_radius := 2900.0
@export var traffic_lanes := 14
@export var searchlights := 4
@export_tool_button("Rebuild skyline") var rebuild_action := build

var _rng := RandomNumberGenerator.new()
var _beams: Array[Node3D] = []
var _beam_speeds: PackedFloat32Array = []


func _ready() -> void:
	build()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for i in _beams.size():
		_beams[i].rotate_y(_beam_speeds[i] * delta)


func build() -> void:
	BuildKit.clear_generated(self)
	_beams.clear()
	_beam_speeds.clear()
	_rng.seed = skyline_seed
	var root := BuildKit.generated_root(self, "Generated")
	var towers := _place_towers()
	_build_tower_instances(root, towers)
	_build_tower_details(root, towers)
	_build_billboards(root, towers)
	_build_arcologies(root)
	_build_traffic(root)
	_build_searchlights(root, towers)
	_build_backdrop(root)


# --- Towers ----------------------------------------------------------------------------------

## Returns one dictionary per tower: center (Vector2 on the ground plane), size, height, shape.
func _place_towers() -> Array[Dictionary]:
	var towers: Array[Dictionary] = []
	for zone in ZONES:
		var cell: float = zone[2]
		var extent := ceili(zone[1] / cell)
		for gx in range(-extent, extent):
			for gz in range(-extent, extent):
				var center := Vector2((gx + _rng.randf_range(0.2, 0.8)) * cell, (gz + _rng.randf_range(0.2, 0.8)) * cell)
				var radius := center.length()
				if radius < zone[0] or radius >= zone[1] or _rng.randf() > zone[7]:
					continue
				var max_size := cell * 0.85
				var size := Vector2(minf(_rng.randf_range(zone[3], zone[4]), max_size), minf(_rng.randf_range(zone[3], zone[4]), max_size))
				if _blocks_street(center, size * 0.5):
					continue
				var height := lerpf(zone[5], zone[6], pow(_rng.randf(), 1.8))
				towers.append({
					"center": center,
					"size": size,
					"height": height,
					"shape": _rng.randi() % 4,
					"custom": Color(_rng.randf() * 100.0, _rng.randf_range(0.2, 0.6), _rng.randf_range(0.0, 0.4), 0.0),
				})
	return towers


func _blocks_street(center: Vector2, half: Vector2) -> bool:
	var near_x := maxf(0.0, absf(center.x) - half.x)
	var near_z := maxf(0.0, absf(center.y) - half.y)
	if near_z < CORRIDOR_HALF_WIDTH and near_x < CORRIDOR_LENGTH:
		return true
	if near_x < CORRIDOR_HALF_WIDTH and near_z < CORRIDOR_LENGTH:
		return true
	if near_z < VISTA_HALF_WIDTH and near_x < VISTA_LENGTH:
		return true
	return near_x < VISTA_HALF_WIDTH and near_z < VISTA_LENGTH


## Unit-sized tower meshes (1x1 footprint, base at y = 0, top at y = 1), scaled per instance.
func _tower_meshes() -> Array[Mesh]:
	var facade := MatLib.facade(2, 4.0)
	var meshes: Array[Mesh] = []
	var box := GeoBatch.new()
	box.add_box_at(Vector3(1, 1, 1), Vector3(0, 0.5, 0), facade)
	meshes.append(box.build_mesh())
	var stepped := GeoBatch.new()
	stepped.add_box_at(Vector3(1, 0.62, 1), Vector3(0, 0.31, 0), facade)
	stepped.add_box_at(Vector3(0.72, 0.24, 0.72), Vector3(0, 0.74, 0), facade)
	stepped.add_box_at(Vector3(0.45, 0.14, 0.45), Vector3(0, 0.93, 0), facade)
	meshes.append(stepped.build_mesh())
	var octagon := GeoBatch.new()
	octagon.add_cylinder(0.5, 0.5, 1.0, 8, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), facade)
	meshes.append(octagon.build_mesh())
	var twin := GeoBatch.new()
	twin.add_box_at(Vector3(0.42, 1, 1), Vector3(-0.29, 0.5, 0), facade)
	twin.add_box_at(Vector3(0.42, 0.8, 1), Vector3(0.29, 0.4, 0), facade)
	meshes.append(twin.build_mesh())
	return meshes


func _build_tower_instances(root: Node3D, towers: Array[Dictionary]) -> void:
	var meshes := _tower_meshes()
	for shape in meshes.size():
		var picked := towers.filter(func(t: Dictionary) -> bool: return t["shape"] == shape)
		var multimesh := _new_multimesh(meshes[shape], picked.size(), true)
		for i in picked.size():
			var tower: Dictionary = picked[i]
			var size: Vector2 = tower["size"]
			var center: Vector2 = tower["center"]
			var basis := Basis.from_scale(Vector3(size.x, tower["height"], size.y))
			multimesh.set_instance_transform(i, Transform3D(basis, Vector3(center.x, 0, center.y)))
			multimesh.set_instance_custom_data(i, tower["custom"])
		_add_multimesh(root, "Towers%d" % shape, multimesh)


## Aviation lights, neon crowns and antenna masts on top of the towers.
func _build_tower_details(root: Node3D, towers: Array[Dictionary]) -> void:
	var lights: Array[Transform3D] = []
	var light_data: Array[Color] = []
	var crowns: Array[Transform3D] = []
	var crown_data: Array[Color] = []
	var masts: Array[Transform3D] = []
	for tower in towers:
		var center: Vector2 = tower["center"]
		var size: Vector2 = tower["size"]
		var height: float = tower["height"]
		var distance := center.length()
		var light_scale := maxf(1.5, distance / 280.0)
		var top := height
		if height > 100.0 and _rng.randf() < 0.3:
			var mast_height := _rng.randf_range(15.0, 60.0)
			masts.append(Transform3D(Basis.from_scale(Vector3(1.2, mast_height, 1.2)), Vector3(center.x, height, center.y)))
			top += mast_height
		if height > 110.0 or top > height:
			lights.append(Transform3D(Basis.from_scale(Vector3.ONE * light_scale), Vector3(center.x, top + light_scale * 0.5, center.y)))
			light_data.append(Color(1.0, 0.08, 0.12, _rng.randf()))
		if _rng.randf() < 0.3 and tower["shape"] != 1:
			var band := clampf(distance / 250.0, 1.2, 8.0)
			var crown_y := height - _rng.randf_range(2.0, 12.0)
			var basis := Basis.from_scale(Vector3(size.x + 0.6, band, size.y + 0.6))
			if tower["shape"] == 2:
				basis = Basis.from_scale(Vector3(minf(size.x, size.y) * 0.75, band, minf(size.x, size.y) * 0.75))
			crowns.append(Transform3D(basis, Vector3(center.x, crown_y, center.y)))
			var color := Palette.random_neon(_rng)
			crown_data.append(Color(color.r, color.g, color.b, _rng.randf()))

	var light_box := GeoBatch.new()
	var light_mat := MatLib.neon(Palette.RED, 6.0, 0.0, 0.55).duplicate() as ShaderMaterial
	light_mat.set_shader_parameter("use_instance_custom", true)
	light_box.add_box_at(Vector3.ONE, Vector3.ZERO, light_mat)
	var light_mm := _new_multimesh(light_box.build_mesh(), lights.size(), true)
	for i in lights.size():
		light_mm.set_instance_transform(i, lights[i])
		light_mm.set_instance_custom_data(i, light_data[i])
	_add_multimesh(root, "AviationLights", light_mm)

	var crown_box := GeoBatch.new()
	var crown_mat := MatLib.neon(Color.WHITE, 3.5).duplicate() as ShaderMaterial
	crown_mat.set_shader_parameter("use_instance_custom", true)
	crown_box.add_box_at(Vector3.ONE, Vector3.ZERO, crown_mat)
	var crown_mm := _new_multimesh(crown_box.build_mesh(), crowns.size(), true)
	for i in crowns.size():
		crown_mm.set_instance_transform(i, crowns[i])
		crown_mm.set_instance_custom_data(i, crown_data[i])
	_add_multimesh(root, "NeonCrowns", crown_mm)

	var mast_box := GeoBatch.new()
	mast_box.add_box_at(Vector3.ONE, Vector3(0, 0.5, 0), MatLib.surface(Palette.METAL_DARK, 0.5, 0.5))
	var mast_mm := _new_multimesh(mast_box.build_mesh(), masts.size(), false)
	for i in masts.size():
		mast_mm.set_instance_transform(i, masts[i])
	_add_multimesh(root, "Masts", mast_mm)


## Huge animated adverts on the faces of towers that look back towards the player's block.
func _build_billboards(root: Node3D, towers: Array[Dictionary]) -> void:
	var geo := GeoBatch.new()
	var placed := 0
	for tower in towers:
		if placed >= 18:
			break
		var center: Vector2 = tower["center"]
		var distance := center.length()
		if tower["height"] < 90.0 or distance < 120.0 or distance > 1200.0 or tower["shape"] == 2 or _rng.randf() > 0.35:
			continue
		var size: Vector2 = tower["size"]
		# Pick the face whose normal points most towards the origin.
		var to_origin := -center.normalized()
		var normal := Vector3(signf(to_origin.x), 0, 0) if absf(to_origin.x) > absf(to_origin.y) else Vector3(0, 0, signf(to_origin.y))
		var face_width := size.y if absf(normal.x) > 0.5 else size.x
		if tower["shape"] == 3:
			face_width *= 0.42
		var half_depth := (size.x if absf(normal.x) > 0.5 else size.y) * 0.5
		var width := face_width * 0.8
		var height := width * _rng.randf_range(0.6, 1.5)
		var y: float = tower["height"] * _rng.randf_range(0.5, 0.75)
		var pos := Vector3(center.x, y, center.y) + normal * (half_depth + 0.6)
		var basis := Basis.looking_at(-normal)
		var ad := MatLib.holo_ad(Palette.random_neon(_rng), Palette.random_neon(_rng), _rng.randi() % 4, _rng.randf() * 10.0, 3.2)
		geo.add_quad(Vector2(width, height), Transform3D(basis, pos), ad)
		placed += 1
	geo.build_into(root, "Billboards", false)


## A handful of kilometre-scale arcologies far out, stacked like ziggurats with neon bands.
func _build_arcologies(root: Node3D) -> void:
	var geo := GeoBatch.new()
	var neon_colors := [Palette.PINK, Palette.CYAN, Palette.PURPLE, Palette.AMBER]
	for i in 4:
		var angle := deg_to_rad(28.0 + i * 90.0 + _rng.randf_range(-18.0, 18.0))
		var distance := _rng.randf_range(1800.0, 2400.0)
		var base := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var width := _rng.randf_range(260.0, 420.0)
		var y := 0.0
		var tiers := _rng.randi_range(3, 5)
		geo.color = Color(0.55, 0.5, 0.6, _rng.randf_range(0.35, 0.55))
		var band: Color = neon_colors[i % neon_colors.size()]
		for tier in tiers:
			var tier_height := _rng.randf_range(120.0, 220.0)
			var tier_width := width * (1.0 - tier * 0.18)
			geo.add_box_at(Vector3(tier_width, tier_height, tier_width), base + Vector3(0, y + tier_height * 0.5, 0), MatLib.facade(1, 0.0, 1.2))
			geo.add_box_at(Vector3(tier_width + 4.0, 6.0, tier_width + 4.0), base + Vector3(0, y + tier_height - 3.0, 0), MatLib.neon(band, 3.0))
			y += tier_height
		geo.color = Color.WHITE
		var spire := _rng.randf_range(120.0, 260.0)
		geo.add_box_at(Vector3(12, spire, 12), base + Vector3(0, y + spire * 0.5, 0), MatLib.surface(Palette.METAL_DARK, 0.5, 0.5))
		geo.add_box_at(Vector3(10, 10, 10), base + Vector3(0, y + spire, 0), MatLib.neon(Palette.RED, 6.0, 0.0, 0.4, float(i) * 0.25))
	geo.build_into(root, "Arcologies", false)


# --- Traffic, searchlights, backdrop ---------------------------------------------------------

func _build_traffic(root: Node3D) -> void:
	var car := GeoBatch.new()
	var traffic_material := ShaderMaterial.new()
	traffic_material.shader = preload("res://shaders/sky_traffic.gdshader")
	car.add_box_at(Vector3(6.0, 1.6, 3.0), Vector3.ZERO, traffic_material)
	var lane_length := 3400.0
	var transforms: Array[Transform3D] = []
	var customs: Array[Color] = []
	for lane in traffic_lanes:
		var angle := _rng.randf() * TAU
		var direction := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-direction.z, 0, direction.x)
		# Some lanes pass right over the block so the player sees cars cross the street canyons.
		var offset := _rng.randf_range(-120.0, 120.0) if lane % 3 == 0 else _rng.randf_range(-1100.0, 1100.0)
		var altitude := _rng.randf_range(55.0, 110.0) if lane % 3 == 0 else _rng.randf_range(80.0, 280.0)
		var speed := _rng.randf_range(28.0, 60.0)
		var basis := Basis(direction, Vector3.UP, direction.cross(Vector3.UP))
		var cars := _rng.randi_range(26, 42)
		for i in cars:
			var heading := 1.0 if i % 2 == 0 else -1.0
			var origin := side * (offset + heading * 8.0) + Vector3.UP * (altitude + heading * 3.0)
			transforms.append(Transform3D(basis, origin))
			customs.append(Color(speed * heading * _rng.randf_range(0.9, 1.1), _rng.randf(), lane_length, 0.0))
	var multimesh := _new_multimesh(car.build_mesh(), transforms.size(), true)
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_custom_data(i, customs[i])
	var instance := _add_multimesh(root, "SkyTraffic", multimesh)
	# Cars are moved in the shader, so culling must use the whole lane area.
	instance.custom_aabb = AABB(Vector3(-2500, 0, -2500), Vector3(5000, 400, 5000))


func _build_searchlights(root: Node3D, towers: Array[Dictionary]) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 28.0
	cone.height = 650.0
	cone.radial_segments = 12
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var beam_material := ShaderMaterial.new()
	beam_material.shader = preload("res://shaders/light_beam.gdshader")
	cone.material = beam_material
	var candidates := towers.filter(_is_searchlight_tower)
	for i in mini(searchlights, candidates.size()):
		var tower: Dictionary = candidates[_rng.randi() % candidates.size()]
		var center: Vector2 = tower["center"]
		var pivot := Node3D.new()
		pivot.name = "Searchlight%d" % i
		pivot.position = Vector3(center.x, tower["height"], center.y)
		pivot.rotation.y = _rng.randf() * TAU
		root.add_child(pivot)
		var tilt := Node3D.new()
		tilt.rotation.x = deg_to_rad(_rng.randf_range(18.0, 35.0))
		pivot.add_child(tilt)
		var beam := MeshInstance3D.new()
		beam.mesh = cone
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Flip the cone so its tip sits on the tower and it widens upwards.
		beam.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, cone.height * 0.5, 0))
		tilt.add_child(beam)
		_beams.append(pivot)
		_beam_speeds.append(_rng.randf_range(0.08, 0.2) * (1.0 if _rng.randf() < 0.5 else -1.0))


func _is_searchlight_tower(tower: Dictionary) -> bool:
	var distance := (tower["center"] as Vector2).length()
	return tower["height"] > 150.0 and distance > 250.0 and distance < 1000.0


## A ring of painted silhouettes at the horizon, seen in the gaps between the real towers.
func _build_backdrop(root: Node3D) -> void:
	var segments := 160
	var bottom := -20.0
	var top := 880.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var p0 := Vector3(cos(a0), 0, sin(a0)) * backdrop_radius
		var p1 := Vector3(cos(a1), 0, sin(a1)) * backdrop_radius
		var u0 := float(i) / segments
		var u1 := float(i + 1) / segments
		for v in [[p0, u0, bottom, 1.0], [p1, u1, top, 0.0], [p1, u1, bottom, 1.0], [p0, u0, bottom, 1.0], [p0, u0, top, 0.0], [p1, u1, top, 0.0]]:
			st.set_uv(Vector2(v[1], v[3]))
			st.add_vertex((v[0] as Vector3) + Vector3.UP * float(v[2]))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/skyline_backdrop.gdshader")
	material.set_shader_parameter("ring_height", top - bottom)
	var mesh := st.commit()
	mesh.surface_set_material(0, material)
	var ring := MeshInstance3D.new()
	ring.name = "Backdrop"
	ring.mesh = mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)


func _new_multimesh(mesh: Mesh, count: int, custom_data: bool) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = custom_data
	multimesh.mesh = mesh
	multimesh.instance_count = count
	return multimesh


func _add_multimesh(root: Node3D, node_name: String, multimesh: MultiMesh) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)
	return instance
