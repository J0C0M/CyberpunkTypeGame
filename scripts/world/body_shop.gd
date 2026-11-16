@tool
class_name BodyShop
extends Node3D
## The character creator's room: a small neon clinic ("Body Shop") with surgical lamps, cables,
## holo screens and a turntable platform the new character stands on. Owns the turntable, the
## character model and an orbiting camera that can frame the whole body or the face.

## Seconds to glide between camera framings.
const CAMERA_SPEED := 5.0

## Camera framing: 0 = whole body, 1 = face close-up (blends in between with the mouse wheel).
var zoom := 0.0
var turntable: Node3D
var model: CharacterModel
var camera: Camera3D
## Spins the platform slowly when nobody is dragging it.
var auto_rotate := true

var _zoom_shown := 0.0
var _time := 0.0
var _ring: MeshInstance3D


func _ready() -> void:
	BuildKit.clear_generated(self)
	var root := BuildKit.generated_root(self, "Generated")
	_build_room(root)
	turntable = Node3D.new()
	turntable.name = "Turntable"
	turntable.position = Vector3(0, 0.16, 0)
	root.add_child(turntable)
	model = CharacterModel.new()
	model.name = "Character"
	model.rotation.y = PI
	turntable.add_child(model)
	camera = Camera3D.new()
	camera.fov = 40.0
	camera.current = true
	root.add_child(camera)
	_place_camera(1.0)


func _process(delta: float) -> void:
	_time += delta
	if Engine.is_editor_hint():
		return
	if auto_rotate:
		turntable.rotation.y += delta * 0.25
	if _ring:
		_ring.rotation.y -= delta * 0.6
	model.pose(0.0, 0.0, 0.0, 0.0, 0.0, _time)
	_place_camera(delta)


## Turns the platform by `radians` (mouse drag) and pauses the slow spin for a moment.
func spin(radians: float) -> void:
	turntable.rotation.y += radians


func _place_camera(delta: float) -> void:
	_zoom_shown = lerpf(_zoom_shown, zoom, 1.0 - exp(-CAMERA_SPEED * delta))
	var eye := model.eye_height() + 0.16 if model and model.data else 1.78
	var target := Vector3(0, lerpf(0.95, eye - 0.04, _zoom_shown), 0)
	var distance := lerpf(3.3, 0.75, _zoom_shown)
	var from := target + Vector3(0.35 * (1.0 - _zoom_shown), lerpf(0.25, 0.04, _zoom_shown), distance)
	camera.global_position = from
	camera.look_at(target, Vector3.UP)
	# The creator's panel covers the left of the screen: frame the character to its right.
	camera.h_offset = lerpf(-0.75, -0.17, _zoom_shown)


func _build_room(root: Node3D) -> void:
	var geo := GeoBatch.new()
	var body := BuildKit.static_body(root)
	var floor := MatLib.surface(Color(0.1, 0.1, 0.13), 0.35, 0.3, 0.1)
	var wall := MatLib.surface(Color(0.16, 0.15, 0.2), 0.7)
	var metal := MatLib.surface(Palette.METAL, 0.35, 0.8)
	var dark := MatLib.surface(Palette.METAL_DARK, 0.5, 0.5)
	# Shell: floor, ceiling and four walls around a 9 x 9 m room.
	geo.add_box_at(Vector3(9, 0.1, 9), Vector3(0, -0.05, 0), floor)
	geo.add_box_at(Vector3(9, 0.1, 9), Vector3(0, 4.05, 0), dark)
	for side: float in [-1.0, 1.0]:
		geo.add_box_at(Vector3(9, 4, 0.2), Vector3(0, 2, side * 4.5), wall)
		geo.add_box_at(Vector3(0.2, 4, 9), Vector3(side * 4.5, 2, 0), wall)
	BuildKit.box_collider_at(body, Vector3(9, 0.1, 9), Vector3(0, -0.05, 0))
	# Floor grid in faint cyan.
	for i in range(-4, 5):
		geo.add_box_at(Vector3(9, 0.004, 0.02), Vector3(0, 0.002, i), MatLib.neon(Palette.CYAN, 0.6))
		geo.add_box_at(Vector3(0.02, 0.004, 9), Vector3(i, 0.002, 0), MatLib.neon(Palette.CYAN, 0.6))
	# The turntable: a metal disc with a glowing rim.
	geo.add_cylinder(1.0, 1.05, 0.16, 16, Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)), metal)
	geo.add_cylinder(1.06, 1.06, 0.03, 16, Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), MatLib.neon(Palette.PINK, 3.0), false)
	var ring := GeoBatch.new()
	for i in 8:
		var angle := i * TAU / 8.0
		ring.add_box_at(Vector3(0.12, 0.01, 0.04), Vector3(cos(angle) * 0.85, 0.165, sin(angle) * 0.85), MatLib.neon(Palette.CYAN, 3.0))
	_ring = ring.build_into(root, "Ring", false)
	# Surgical lamps on arms from the ceiling, and cables hanging down.
	for i in 3:
		var angle := -PI * 0.5 + (i - 1) * 1.1
		var base := Vector3(cos(angle) * 1.6, 4.0, sin(angle) * 1.6)
		var head := Vector3(cos(angle) * 1.2, 2.7, sin(angle) * 1.2)
		geo.add_bar(base, base + Vector3.DOWN * 0.6, 0.06, dark)
		geo.add_bar(base + Vector3.DOWN * 0.6, head, 0.05, metal)
		geo.add_cylinder(0.18, 0.1, 0.12, 8, Transform3D(Basis.IDENTITY, head), dark)
		geo.add_cylinder(0.15, 0.15, 0.02, 8, Transform3D(Basis.IDENTITY, head + Vector3.DOWN * 0.07), MatLib.neon(Palette.COOL_WHITE, 4.0), false)
	for i in 6:
		var x := -3.5 + i * 1.4
		var points := PackedVector3Array()
		for s in 9:
			var f := s / 8.0
			points.append(Vector3(x + f * 0.8, 4.0 - sin(f * PI) * (1.0 + i * 0.15), -4.3 + f * 1.2))
		geo.add_polyline(points, 0.025, MatLib.surface(Color(0.02, 0.02, 0.03), 0.6))
	# Back wall: holo screens with body diagrams, a cabinet of parts, neon strips.
	for x: float in [-2.6, 2.6]:
		geo.add_quad(Vector2(1.6, 2.0), Transform3D(Basis.IDENTITY, Vector3(x, 2.0, -4.38)), MatLib.holo_ad(Palette.CYAN, Palette.PURPLE, 1 if x < 0.0 else 3, 3.0 + x, 2.0))
	for x: float in [-4.38, 4.38]:
		geo.add_box_at(Vector3(0.04, 0.06, 8.6), Vector3(x, 3.6, 0), MatLib.neon(Palette.PURPLE, 3.0))
		geo.add_box_at(Vector3(0.04, 0.06, 8.6), Vector3(x, 0.3, 0), MatLib.neon(Palette.PINK, 2.5))
	geo.add_box_at(Vector3(8.6, 0.06, 0.04), Vector3(0, 3.6, -4.38), MatLib.neon(Palette.PURPLE, 3.0))
	for i in 4:
		var cabinet := Vector3(-4.1, 1.0 + (i % 2) * 0.9, -1.5 + floorf(i / 2.0) * 1.4)
		geo.add_box_at(Vector3(0.6, 0.8, 1.2), cabinet, dark)
		geo.add_box_at(Vector3(0.02, 0.6, 1.0), cabinet + Vector3(0.31, 0, 0), MatLib.glass(Color(0.4, 0.9, 1.0, 0.25)))
		geo.add_box_at(Vector3(0.1, 0.12, 0.1), cabinet + Vector3(0.1, -0.2, -0.3 + i * 0.1), MatLib.neon(Palette.RED, 2.0))
	geo.build_into(root, "Room")
	BuildKit.neon_text(root, "BODY SHOP", Transform3D(Basis.IDENTITY, Vector3(0, 3.15, -4.36)), Palette.PINK, 0.5)
	BuildKit.neon_text(root, "NEW CITIZEN // REGISTRATION", Transform3D(Basis.IDENTITY, Vector3(0, 2.65, -4.36)), Palette.CYAN, 0.16)
	BuildKit.neon_text(root, "新しい体", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-4.36, 2.6, 1.6)), Palette.AMBER, 0.4)
	# Lights: a key light from the front, coloured rims behind, a glow from the platform.
	var key := BuildKit.down_spot(root, Vector3(0.6, 3.6, 2.6), Palette.WARM_WHITE, 1.8, 9.0, 40.0, true)
	key.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	BuildKit.omni(root, Vector3(-2.4, 2.6, -2.0), Palette.PINK, 1.3, 6.0)
	BuildKit.omni(root, Vector3(2.4, 2.4, -1.8), Palette.CYAN, 1.3, 6.0)
	BuildKit.omni(root, Vector3(0, 0.4, 1.0), Palette.PURPLE, 0.6, 2.5)
	BuildKit.omni(root, Vector3(0, 3.0, 3.0), Palette.COOL_WHITE, 0.5, 8.0)
	if not Engine.is_editor_hint():
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.02, 0.01, 0.04)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.3, 0.24, 0.45)
		env.ambient_light_energy = 0.45
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.95
		env.glow_enabled = true
		env.glow_intensity = 0.45
		env.glow_hdr_threshold = 1.2
		env.fog_enabled = true
		env.fog_light_color = Color(0.12, 0.06, 0.18)
		env.fog_density = 0.02
		var world_env := WorldEnvironment.new()
		world_env.environment = env
		root.add_child(world_env)
