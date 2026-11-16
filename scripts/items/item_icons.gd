class_name ItemIcons
extends Node
## Item icons: a small low-poly render of every item. On start, every model (ItemModels) is laid
## out in a grid in an offscreen SubViewport with an orthographic camera, rendered once, and the
## picture is cut into one texture per item. Until then (and on the headless renderer) icon()
## returns a flat placeholder in the category colour. Add one ItemIcons node to the scene.

## Pixels per icon. Shown scaled up with nearest filtering, so they look like pixel art.
const CELL := 48
const COLUMNS := 8

static var _icons := {}
static var _fallbacks := {}

var _viewport: SubViewport
var _ids: Array[StringName] = []


static func icon(id: StringName) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	if not _fallbacks.has(id):
		_fallbacks[id] = _placeholder(ItemDB.color(id))
	return _fallbacks[id]


func _ready() -> void:
	if not _icons.is_empty() or DisplayServer.get_name() == "headless":
		return
	_ids = ItemDB.all_ids()
	_ids.sort_custom(func(a: StringName, b: StringName) -> bool: return ItemDB.sorts_before(a, b))
	var rows := ceili(_ids.size() / float(COLUMNS))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(COLUMNS * CELL, rows * CELL)
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	_build_stage(rows)
	await RenderingServer.frame_post_draw
	_cut(_viewport.get_texture().get_image())
	_viewport.queue_free()


func _build_stage(rows: int) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.7)
	env.ambient_light_energy = 1.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-35.0), 0.0)
	key.light_energy = 2.2
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-10.0), deg_to_rad(150.0), 0.0)
	rim.light_color = Palette.CYAN
	rim.light_energy = 0.8
	_viewport.add_child(rim)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = rows
	camera.position = Vector3(COLUMNS * 0.5, -rows * 0.5, 10.0)
	_viewport.add_child(camera)
	for i in _ids.size():
		var model := ItemModels.build(_ids[i])
		# Seen from slightly above and to the side; long things (guns) from the side, tilted
		# across the square so they fill it.
		var size := model.mesh.get_aabb().size
		var view := Basis.from_euler(Vector3(0.5, -0.65, 0.0))
		if size.x > 3.0 * maxf(size.y, size.z):
			view = Basis(Vector3.FORWARD, 0.6) * Basis.from_euler(Vector3(0.25, -0.15, 0.0))
		var box := Transform3D(view, Vector3.ZERO) * model.mesh.get_aabb()
		var fit := 0.82 / maxf(box.size.x, box.size.y)
		var cell_center := Vector3(i % COLUMNS + 0.5, -(i / COLUMNS) - 0.5, 0.0)
		model.transform = Transform3D(view.scaled(Vector3.ONE * fit), cell_center - box.get_center() * fit)
		_viewport.add_child(model)


func _cut(image: Image) -> void:
	if image == null or image.is_empty():
		return
	for i in _ids.size():
		var region := Rect2i((i % COLUMNS) * CELL, (i / COLUMNS) * CELL, CELL, CELL)
		_icons[_ids[i]] = ImageTexture.create_from_image(image.get_region(region))


## A rounded square in the category colour, for when no render exists.
static func _placeholder(color: Color) -> Texture2D:
	var image := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	var inner := Rect2i(12, 12, CELL - 24, CELL - 24)
	for y in CELL:
		for x in CELL:
			if inner.has_point(Vector2i(x, y)):
				var edge := x == inner.position.x or y == inner.position.y or x == inner.end.x - 1 or y == inner.end.y - 1
				image.set_pixel(x, y, color if edge else Color(color.r, color.g, color.b, 0.25))
	return ImageTexture.create_from_image(image)
