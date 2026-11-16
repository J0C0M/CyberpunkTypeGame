@tool
class_name SushiCafe
extends Node3D
## Futuristic kaiten (conveyor-belt) sushi cafe built from primitives, with Chef Hiro behind the counter.
## Local space: the shop front is the plane z = 0 facing +Z (the street); the room runs to z = -DEPTH.
## Everything visual is generated in _ready (also in the editor), so it is easy to swap for a model.

const WIDTH := 12.0
const DEPTH := 12.0
const HEIGHT := 4.5
const FLOOR_Y := 0.15
## Height of the facade band; the city builds the rest of the building on top of this.
const SHELL_TOP := 4.8

const COUNTER_Z := -7.4
const COUNTER_TOP_Y := 1.21
const BELT_LENGTH := 8.0
const BELT_RADIUS := 0.25
const PLATE_COUNT := 18
@export var belt_speed := 0.35

var _plates: Array[Node3D] = []
var _belt_offset := 0.0


func _ready() -> void:
	BuildKit.clear_generated(self)
	var root := BuildKit.generated_root(self, "Generated")
	var geo := GeoBatch.new()
	var body := BuildKit.static_body(root)
	_build_shell(geo, body, root)
	_build_front(geo, root)
	_build_counter(geo, body)
	_build_back_wall(geo, root)
	_build_seating(geo, body)
	_build_ceiling_decor(geo)
	geo.build_into(root, "CafeGeometry")
	_build_plates(root)
	_build_lights(root)
	if not Engine.is_editor_hint():
		GameState.register_place(&"sushi", "Sushi Kaiten", global_transform * Vector3(0, 0, 2.0))
		MusicZone.create(self, Vector3(WIDTH - 0.4, HEIGHT, DEPTH - 0.3), Vector3(0, HEIGHT * 0.5, -DEPTH * 0.5 - 0.15), preload("res://assets/music/sushi.ogg"), Vector3(-5.0, HEIGHT - 0.4, -10.0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_belt_offset = fmod(_belt_offset + delta * belt_speed, _belt_loop_length())
	var spacing := _belt_loop_length() / PLATE_COUNT
	for i in _plates.size():
		_plates[i].position = _belt_point(_belt_offset + i * spacing)


func _build_shell(geo: GeoBatch, body: StaticBody3D, root: Node3D) -> void:
	var floor_mat := MatLib.surface(Color(0.24, 0.14, 0.1), 0.3, 0.0, 0.1)
	var wall_mat := MatLib.surface(Color(0.32, 0.2, 0.15), 0.7)
	var slat_mat := MatLib.surface(Palette.WOOD, 0.6)
	var dark_mat := MatLib.surface(Palette.METAL_DARK, 0.5, 0.4)

	# Floor, ceiling, back and side walls.
	geo.add_box_at(Vector3(WIDTH, FLOOR_Y, DEPTH), Vector3(0, FLOOR_Y * 0.5, -DEPTH * 0.5), floor_mat)
	BuildKit.box_collider_at(body, Vector3(WIDTH, 1.0, DEPTH), Vector3(0, FLOOR_Y - 0.5, -DEPTH * 0.5)).set_meta(&"surface", &"wood")
	geo.add_box_at(Vector3(WIDTH, 0.3, DEPTH), Vector3(0, HEIGHT + 0.15, -DEPTH * 0.5), dark_mat)
	geo.add_box_at(Vector3(WIDTH, HEIGHT, 0.3), Vector3(0, HEIGHT * 0.5, -DEPTH - 0.15), wall_mat)
	BuildKit.box_collider_at(body, Vector3(WIDTH, HEIGHT, 0.3), Vector3(0, HEIGHT * 0.5, -DEPTH - 0.15))
	for side: float in [-1.0, 1.0]:
		geo.add_box_at(Vector3(0.3, HEIGHT, DEPTH), Vector3(side * (WIDTH * 0.5 + 0.15), HEIGHT * 0.5, -DEPTH * 0.5), wall_mat)
		BuildKit.box_collider_at(body, Vector3(0.3, HEIGHT, DEPTH), Vector3(side * (WIDTH * 0.5 + 0.15), HEIGHT * 0.5, -DEPTH * 0.5))
		# Vertical wooden slats on the side walls.
		for i in 14:
			var z := -0.8 - i * 0.8
			geo.add_box_at(Vector3(0.06, HEIGHT - 0.6, 0.12), Vector3(side * (WIDTH * 0.5 - 0.03), HEIGHT * 0.5 + 0.1, z), slat_mat)

	# Front: sills, breakable glass, door frame and the sign band. Door gap is x in [-1.3, 1.3].
	var frame_mat := MatLib.surface(Palette.METAL_DARK, 0.35, 0.6)
	for side: float in [-1.0, 1.0]:
		var cx := side * 3.65
		geo.add_box_at(Vector3(4.7, 0.5, 0.3), Vector3(cx, 0.25, -0.15), frame_mat)
		BuildKit.box_collider_at(body, Vector3(4.7, 0.5, 0.3), Vector3(cx, 0.25, -0.15))
		for half: float in [-1.0, 1.0]:
			BuildKit.glass_pane(root, Transform3D(Basis.IDENTITY, Vector3(cx + half * 1.19, 1.85, -0.15)), Vector3(2.3, 2.7, 0.04), Color(0.45, 0.75, 1.0, 0.1))
		geo.add_box_at(Vector3(0.15, 3.2, 0.32), Vector3(side * 1.3, 1.6, -0.15), frame_mat)
		geo.add_box_at(Vector3(0.3, SHELL_TOP, 0.4), Vector3(side * 6.15, SHELL_TOP * 0.5, -0.1), frame_mat)
		geo.add_box_at(Vector3(0.08, 2.7, 0.1), Vector3(cx, 1.85, -0.15), frame_mat)
	geo.add_box_at(Vector3(2.6, 0.6, 0.3), Vector3(0, 2.9, -0.15), frame_mat)
	geo.add_box_at(Vector3(WIDTH + 0.6, SHELL_TOP - 3.2, 0.4), Vector3(0, (SHELL_TOP + 3.2) * 0.5, -0.2), MatLib.surface(Color(0.05, 0.04, 0.07), 0.4, 0.3))
	BuildKit.box_collider_at(body, Vector3(WIDTH + 0.6, SHELL_TOP - 2.6, 0.4), Vector3(0, (SHELL_TOP + 2.6) * 0.5, -0.2))


func _build_front(geo: GeoBatch, root: Node3D) -> void:
	# Awning with a neon edge.
	var awning_mat := MatLib.surface(Color(0.35, 0.03, 0.08), 0.6)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(14.0))
	geo.add_box(Vector3(WIDTH, 0.08, 1.5), Transform3D(tilt, Vector3(0, 3.05, 0.72)), awning_mat)
	geo.add_bar(Vector3(-WIDTH * 0.5, 2.86, 1.45), Vector3(WIDTH * 0.5, 2.86, 1.45), 0.05, MatLib.neon(Palette.CYAN, 5.0))

	# Noren curtain over the doorway (walk-through, no collider).
	var noren_mat := MatLib.surface(Color(0.05, 0.08, 0.3), 0.9)
	for i in 3:
		geo.add_box_at(Vector3(0.78, 0.6, 0.02), Vector3(-0.82 + i * 0.82, 2.3, -0.05), noren_mat)
	geo.add_bar(Vector3(-1.3, 2.62, -0.05), Vector3(1.3, 2.62, -0.05), 0.04, MatLib.surface(Palette.WOOD, 0.6))

	# Main sign on the facade band, framed with neon tubes.
	var front := Transform3D(Basis.IDENTITY, Vector3(0, 4.05, 0.08))
	BuildKit.neon_text(root, "SUSHI KAITEN", front, Palette.PINK, 0.75)
	BuildKit.neon_text(root, "回転寿司", Transform3D(Basis.IDENTITY, Vector3(4.6, 4.05, 0.08)), Palette.CYAN, 0.5)
	BuildKit.neon_text(root, "24H", Transform3D(Basis.IDENTITY, Vector3(-4.8, 4.05, 0.08)), Palette.AMBER, 0.5)
	var pink := MatLib.neon(Palette.PINK, 4.0)
	geo.add_polyline(PackedVector3Array([
		Vector3(-2.9, 3.55, 0.03), Vector3(2.9, 3.55, 0.03), Vector3(2.9, 4.55, 0.03), Vector3(-2.9, 4.55, 0.03),
	]), 0.04, pink, true)

	# Vertical blade sign sticking out over the sidewalk.
	var blade_mat := MatLib.surface(Color(0.04, 0.03, 0.06), 0.4, 0.5)
	geo.add_box_at(Vector3(0.18, 3.6, 1.1), Vector3(5.6, 6.6, 0.75), blade_mat)
	var blade_neon := MatLib.neon(Palette.AMBER, 4.5, 0.15, 0.0, 3.0)
	geo.add_polyline(PackedVector3Array([
		Vector3(5.7, 4.85, 0.25), Vector3(5.7, 8.35, 0.25), Vector3(5.7, 8.35, 1.25), Vector3(5.7, 4.85, 1.25),
	]), 0.04, blade_neon, true)
	geo.add_polyline(PackedVector3Array([
		Vector3(5.5, 4.85, 0.25), Vector3(5.5, 8.35, 0.25), Vector3(5.5, 8.35, 1.25), Vector3(5.5, 4.85, 1.25),
	]), 0.04, blade_neon, true)
	var side_x := Basis(Vector3.UP, PI * 0.5)
	BuildKit.neon_text(root, "寿\n司", Transform3D(side_x, Vector3(5.76, 6.6, 0.75)), Palette.AMBER, 1.1)
	BuildKit.neon_text(root, "寿\n司", Transform3D(side_x.rotated(Vector3.UP, PI), Vector3(5.44, 6.6, 0.75)), Palette.AMBER, 1.1)

	# "OPEN" sign hanging inside the left window.
	BuildKit.neon_text(root, "OPEN", Transform3D(Basis.IDENTITY, Vector3(-2.45, 2.4, -0.3)), Palette.RED, 0.45)
	geo.add_polyline(PackedVector3Array([
		Vector3(-3.2, 2.1, -0.32), Vector3(-1.7, 2.1, -0.32), Vector3(-1.7, 2.7, -0.32), Vector3(-3.2, 2.7, -0.32),
	]), 0.03, MatLib.neon(Palette.CYAN, 3.0), true)


func _build_counter(geo: GeoBatch, body: StaticBody3D) -> void:
	var base_mat := MatLib.surface(Color(0.12, 0.07, 0.05), 0.5)
	var top_mat := MatLib.surface(Palette.WOOD_LIGHT, 0.35)
	var belt_mat := MatLib.surface(Palette.METAL, 0.3, 0.8)
	var half := BELT_LENGTH * 0.5 + 0.5

	geo.add_box_at(Vector3(half * 2.0, 1.0, 1.0), Vector3(0, FLOOR_Y + 0.5, COUNTER_Z), base_mat)
	geo.add_box_at(Vector3(half * 2.0 + 0.2, 0.06, 1.3), Vector3(0, COUNTER_TOP_Y - 0.03, COUNTER_Z + 0.1), top_mat)
	BuildKit.box_collider_at(body, Vector3(half * 2.0 + 0.2, COUNTER_TOP_Y, 1.3), Vector3(0, COUNTER_TOP_Y * 0.5, COUNTER_Z + 0.1))
	geo.add_bar(Vector3(-half, FLOOR_Y + 0.08, COUNTER_Z + 0.52), Vector3(half, FLOOR_Y + 0.08, COUNTER_Z + 0.52), 0.04, MatLib.neon(Palette.CYAN, 3.5))

	# Conveyor: an oval steel track with a raised divider down the middle.
	geo.add_box_at(Vector3(BELT_LENGTH, 0.04, BELT_RADIUS * 2.0 + 0.3), Vector3(0, COUNTER_TOP_Y + 0.02, COUNTER_Z), belt_mat)
	for side: float in [-1.0, 1.0]:
		geo.add_cylinder(BELT_RADIUS + 0.15, BELT_RADIUS + 0.15, 0.04, 10, Transform3D(Basis.IDENTITY, Vector3(side * BELT_LENGTH * 0.5, COUNTER_TOP_Y + 0.02, COUNTER_Z)), belt_mat)
	geo.add_box_at(Vector3(BELT_LENGTH, 0.06, 0.04), Vector3(0, COUNTER_TOP_Y + 0.07, COUNTER_Z), MatLib.surface(Palette.METAL_DARK, 0.4, 0.6))

	# Chef's back counter with a glowing fish display.
	geo.add_box_at(Vector3(WIDTH - 0.6, 1.0, 0.8), Vector3(0, FLOOR_Y + 0.5, -DEPTH + 0.45), base_mat)
	geo.add_box_at(Vector3(WIDTH - 0.6, 0.05, 0.85), Vector3(0, FLOOR_Y + 1.02, -DEPTH + 0.45), top_mat)
	BuildKit.box_collider_at(body, Vector3(WIDTH - 0.6, 1.1, 0.8), Vector3(0, FLOOR_Y + 0.55, -DEPTH + 0.45))
	geo.add_box_at(Vector3(4.0, 0.45, 0.5), Vector3(1.2, FLOOR_Y + 1.27, -DEPTH + 0.5), MatLib.glass(Color(0.6, 0.9, 1.0, 0.18)))
	geo.add_box_at(Vector3(3.9, 0.02, 0.45), Vector3(1.2, FLOOR_Y + 1.06, -DEPTH + 0.5), MatLib.neon(Palette.COOL_WHITE, 1.6))
	var fish_colors := [Color(1.0, 0.45, 0.3), Color(0.75, 0.08, 0.12), Color(1.0, 0.85, 0.35), Color(0.95, 0.95, 0.9)]
	for i in 8:
		geo.add_box_at(Vector3(0.35, 0.08, 0.2), Vector3(-0.5 + i * 0.48, FLOOR_Y + 1.12, -DEPTH + 0.5), MatLib.surface(fish_colors[i % 4], 0.4))

	# Lucky cat on the back counter.
	var white := MatLib.surface(Color(0.92, 0.9, 0.85), 0.5)
	var cat := Transform3D(Basis(Vector3.UP, deg_to_rad(10.0)), Vector3(-4.4, FLOOR_Y + 1.05, -DEPTH + 0.5))
	geo.add_box(Vector3(0.3, 0.32, 0.24), cat.translated_local(Vector3(0, 0.16, 0)), white)
	geo.add_box(Vector3(0.34, 0.26, 0.26), cat.translated_local(Vector3(0, 0.45, 0)), white)
	geo.add_box(Vector3(0.08, 0.22, 0.08), cat.translated_local(Vector3(0.18, 0.5, 0.06)), white)
	geo.add_box(Vector3(0.07, 0.08, 0.04), cat.translated_local(Vector3(-0.11, 0.62, 0)), white)
	geo.add_box(Vector3(0.07, 0.08, 0.04), cat.translated_local(Vector3(0.11, 0.62, 0)), white)
	geo.add_box(Vector3(0.32, 0.04, 0.26), cat.translated_local(Vector3(0, 0.31, 0)), MatLib.surface(Palette.RED, 0.5))
	geo.add_box(Vector3(0.06, 0.06, 0.02), cat.translated_local(Vector3(0, 0.29, 0.13)), MatLib.neon(Palette.AMBER, 3.0))


func _build_back_wall(geo: GeoBatch, root: Node3D) -> void:
	var wall_z := -DEPTH + 0.02
	# Neon koi in the middle of the back wall.
	var koi := MatLib.neon(Palette.AMBER, 4.0)
	var body_points := PackedVector3Array()
	for i in 15:
		var a := deg_to_rad(25.0 + i * (310.0 / 14.0))
		body_points.append(Vector3(cos(a) * -0.95, 3.25 + sin(a) * 0.38, wall_z))
	geo.add_polyline(body_points, 0.045, koi)
	geo.add_polyline(PackedVector3Array([
		Vector3(0.85, 3.42, wall_z), Vector3(1.45, 3.8, wall_z), Vector3(1.25, 3.25, wall_z), Vector3(1.45, 2.7, wall_z), Vector3(0.85, 3.08, wall_z),
	]), 0.045, koi)
	geo.add_polyline(PackedVector3Array([
		Vector3(-0.1, 3.62, wall_z), Vector3(0.2, 3.95, wall_z), Vector3(0.35, 3.6, wall_z),
	]), 0.04, koi)
	geo.add_box_at(Vector3(0.09, 0.09, 0.05), Vector3(-0.6, 3.33, wall_z), MatLib.neon(Palette.CYAN, 5.0))
	BuildKit.neon_text(root, "寿司", Transform3D(Basis.IDENTITY, Vector3(0, 2.45, wall_z + 0.01)), Palette.PINK, 0.6)

	# Glowing menu boards left and right.
	var board_mat := MatLib.neon(Color(1.0, 0.92, 0.78), 1.15)
	var menu := [["MAGURO  ¥240", "SAKE    ¥180", "UNAGI   ¥320"], ["TAMAGO  ¥120", "EBI     ¥200", "IKURA   ¥380"]]
	for side in 2:
		var cx := -3.6 if side == 0 else 3.6
		geo.add_box_at(Vector3(2.6, 1.3, 0.05), Vector3(cx, 3.2, wall_z), board_mat)
		geo.add_polyline(PackedVector3Array([
			Vector3(cx - 1.33, 2.53, wall_z + 0.03), Vector3(cx + 1.33, 2.53, wall_z + 0.03),
			Vector3(cx + 1.33, 3.87, wall_z + 0.03), Vector3(cx - 1.33, 3.87, wall_z + 0.03),
		]), 0.035, MatLib.neon(Palette.PINK if side == 0 else Palette.CYAN, 3.5), true)
		for row in 3:
			BuildKit.flat_text(root, menu[side][row], Transform3D(Basis.IDENTITY, Vector3(cx, 3.6 - row * 0.38, wall_z + 0.04)), Color(0.08, 0.03, 0.06), 0.24)

	# Shelf of glowing bottles between the counter and the boards.
	var shelf_mat := MatLib.surface(Palette.WOOD, 0.6)
	for side: float in [-1.0, 1.0]:
		geo.add_box_at(Vector3(2.8, 0.05, 0.3), Vector3(side * 3.6, 2.15, -DEPTH + 0.15), shelf_mat)
		for i in 7:
			var color: Color = Palette.NEONS[(i * 3 + int(side + 1.0)) % Palette.NEONS.size()]
			var bottle := Transform3D(Basis.IDENTITY, Vector3(side * 3.6 - 1.2 + i * 0.4, 2.33, -DEPTH + 0.15))
			geo.add_cylinder(0.06, 0.06, 0.3, 6, bottle, MatLib.glowing_surface(color.darkened(0.6), color, 1.2))
			geo.add_cylinder(0.025, 0.025, 0.12, 5, bottle.translated(Vector3(0, 0.2, 0)), MatLib.surface(Palette.METAL_DARK, 0.4))


func _build_seating(geo: GeoBatch, body: StaticBody3D) -> void:
	var chrome := MatLib.surface(Palette.METAL, 0.25, 0.9)
	var vinyl := MatLib.surface(Color(0.5, 0.04, 0.1), 0.45)
	# Stools along the counter.
	for i in 7:
		var x := -3.9 + i * 1.3
		_stool(geo, Vector3(x, FLOOR_Y, COUNTER_Z + 1.05), chrome, vinyl, 0.75)
	# Two standing tables by the window, each with two tall stools.
	var table_top := MatLib.surface(Color(0.06, 0.05, 0.08), 0.15, 0.3)
	for side: float in [-1.0, 1.0]:
		var center := Vector3(side * 3.6, FLOOR_Y, -2.2)
		geo.add_cylinder(0.05, 0.05, 1.0, 6, Transform3D(Basis.IDENTITY, center + Vector3(0, 0.5, 0)), chrome)
		geo.add_cylinder(0.3, 0.3, 0.03, 8, Transform3D(Basis.IDENTITY, center + Vector3(0, 0.015, 0)), chrome)
		geo.add_cylinder(0.5, 0.5, 0.05, 10, Transform3D(Basis.IDENTITY, center + Vector3(0, 1.03, 0)), table_top)
		geo.add_cylinder(0.51, 0.51, 0.015, 10, Transform3D(Basis.IDENTITY, center + Vector3(0, 1.0, 0)), MatLib.neon(Palette.PINK if side < 0 else Palette.CYAN, 3.0))
		BuildKit.box_collider_at(body, Vector3(0.8, 1.05, 0.8), center + Vector3(0, 0.53, 0))
		for dx: float in [-0.75, 0.75]:
			_stool(geo, center + Vector3(dx, 0, 0), chrome, vinyl, 0.75)
		# A bowl of ramen and chopsticks on each table.
		geo.add_cylinder(0.1, 0.14, 0.08, 8, Transform3D(Basis.IDENTITY, center + Vector3(0.1, 1.1, 0.05)), MatLib.surface(Color(0.9, 0.88, 0.82), 0.3))
		geo.add_cylinder(0.12, 0.12, 0.01, 8, Transform3D(Basis.IDENTITY, center + Vector3(0.1, 1.13, 0.05)), MatLib.surface(Color(0.75, 0.45, 0.18), 0.2))
		geo.add_bar(center + Vector3(-0.15, 1.07, -0.12), center + Vector3(0.15, 1.07, -0.18), 0.012, MatLib.surface(Palette.WOOD_LIGHT, 0.5))


func _stool(geo: GeoBatch, base: Vector3, chrome: Material, vinyl: Material, seat_height: float) -> void:
	geo.add_cylinder(0.2, 0.2, 0.03, 8, Transform3D(Basis.IDENTITY, base + Vector3(0, 0.015, 0)), chrome)
	geo.add_cylinder(0.035, 0.035, seat_height, 6, Transform3D(Basis.IDENTITY, base + Vector3(0, seat_height * 0.5, 0)), chrome)
	geo.add_cylinder(0.2, 0.2, 0.08, 10, Transform3D(Basis.IDENTITY, base + Vector3(0, seat_height + 0.04, 0)), vinyl)


func _build_ceiling_decor(geo: GeoBatch) -> void:
	# Neon strips along the ceiling.
	geo.add_bar(Vector3(-5.5, HEIGHT - 0.05, -2.0), Vector3(5.5, HEIGHT - 0.05, -2.0), 0.05, MatLib.neon(Palette.PINK, 3.5))
	geo.add_bar(Vector3(-5.5, HEIGHT - 0.05, -5.0), Vector3(5.5, HEIGHT - 0.05, -5.0), 0.05, MatLib.neon(Palette.CYAN, 3.5))
	geo.add_bar(Vector3(-5.5, HEIGHT - 0.05, -10.0), Vector3(5.5, HEIGHT - 0.05, -10.0), 0.05, MatLib.neon(Palette.PURPLE, 3.5))
	# Red paper lanterns over the counter.
	var lantern := MatLib.neon(Color(1.0, 0.18, 0.12), 2.2)
	var cap := MatLib.surface(Color(0.03, 0.03, 0.03), 0.6)
	for i in 5:
		var pos := Vector3(-4.0 + i * 2.0, 3.2, COUNTER_Z)
		geo.add_sphere(0.28, Transform3D(Basis.from_scale(Vector3(1.0, 1.3, 1.0)), pos), lantern, 8, 6)
		geo.add_cylinder(0.16, 0.16, 0.06, 8, Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.37, 0)), cap)
		geo.add_cylinder(0.16, 0.16, 0.06, 8, Transform3D(Basis.IDENTITY, pos - Vector3(0, 0.37, 0)), cap)
		geo.add_bar(pos + Vector3(0, 0.4, 0), Vector3(pos.x, HEIGHT, pos.z), 0.015, cap)


func _build_plates(root: Node3D) -> void:
	var plate_colors := [Color(0.92, 0.92, 0.9), Color(0.75, 0.1, 0.12), Color(0.85, 0.65, 0.15), Color(0.15, 0.35, 0.85)]
	var toppings := [Color(1.0, 0.45, 0.3), Color(0.7, 0.06, 0.1), Color(1.0, 0.85, 0.35), Color(1.0, 0.6, 0.5)]
	var rice := MatLib.surface(Color(0.95, 0.94, 0.9), 0.6)
	var nori := MatLib.surface(Color(0.03, 0.05, 0.03), 0.6)
	var meshes: Array[Mesh] = []
	for variant in 4:
		var geo := GeoBatch.new()
		geo.add_cylinder(0.13, 0.13, 0.025, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.0125, 0)), MatLib.surface(plate_colors[variant], 0.3))
		if variant == 3:
			for i in 3:
				var p := Vector3(-0.06 + i * 0.06, 0.045, 0)
				geo.add_cylinder(0.026, 0.026, 0.04, 8, Transform3D(Basis.IDENTITY, p), nori)
				geo.add_cylinder(0.02, 0.02, 0.002, 8, Transform3D(Basis.IDENTITY, p + Vector3(0, 0.021, 0)), rice)
		else:
			for i in 2:
				var p := Vector3(-0.05 + i * 0.1, 0.0, 0)
				geo.add_box_at(Vector3(0.085, 0.035, 0.045), p + Vector3(0, 0.043, 0), rice)
				geo.add_box_at(Vector3(0.1, 0.014, 0.052), p + Vector3(0, 0.067, 0), MatLib.surface(toppings[variant], 0.35))
		meshes.append(geo.build_mesh())
	var plates := Node3D.new()
	plates.name = "BeltPlates"
	root.add_child(plates)
	_plates.clear()
	for i in PLATE_COUNT:
		var plate := MeshInstance3D.new()
		plate.mesh = meshes[(i * 7) % 4]
		plates.add_child(plate)
		_plates.append(plate)
	var spacing := _belt_loop_length() / PLATE_COUNT
	for i in _plates.size():
		_plates[i].position = _belt_point(i * spacing)


func _build_lights(root: Node3D) -> void:
	BuildKit.omni(root, Vector3(0, 3.9, -3.5), Color(1.0, 0.6, 0.5), 3.2, 11.0, true)
	BuildKit.omni(root, Vector3(0, 3.0, COUNTER_Z), Color(1.0, 0.75, 0.55), 1.6, 6.0)
	BuildKit.omni(root, Vector3(0, 3.2, -10.6), Palette.CYAN, 1.2, 7.0)
	BuildKit.omni(root, Vector3(-4.5, 2.5, -1.5), Palette.PINK, 0.9, 5.0)
	BuildKit.omni(root, Vector3(4.5, 2.5, -1.5), Palette.CYAN, 0.9, 5.0)
	# Sign spill onto the sidewalk.
	BuildKit.omni(root, Vector3(0, 4.0, 1.4), Palette.PINK, 3.0, 9.0)
	BuildKit.omni(root, Vector3(5.6, 6.5, 1.6), Palette.AMBER, 2.0, 8.0)


func _belt_loop_length() -> float:
	return BELT_LENGTH * 2.0 + TAU * BELT_RADIUS


## Point on the oval conveyor loop at arc length `s` (front lane, right bend, back lane, left bend).
func _belt_point(s: float) -> Vector3:
	s = fposmod(s, _belt_loop_length())
	var half := BELT_LENGTH * 0.5
	var bend := PI * BELT_RADIUS
	var y := COUNTER_TOP_Y + 0.04
	if s < BELT_LENGTH:
		return Vector3(-half + s, y, COUNTER_Z + BELT_RADIUS)
	s -= BELT_LENGTH
	if s < bend:
		var a := s / BELT_RADIUS
		return Vector3(half + sin(a) * BELT_RADIUS, y, COUNTER_Z + cos(a) * BELT_RADIUS)
	s -= bend
	if s < BELT_LENGTH:
		return Vector3(half - s, y, COUNTER_Z - BELT_RADIUS)
	s -= BELT_LENGTH
	var b := s / BELT_RADIUS
	return Vector3(-half - sin(b) * BELT_RADIUS, y, COUNTER_Z - cos(b) * BELT_RADIUS)
