class_name CharacterPortrait
extends RefCounted
## Renders a small head-and-shoulders picture of a character in an offscreen viewport (neon rim
## lights on a dark background). Save slots use it until the player takes a photo booth picture.
## Returns null on the headless renderer.


static func render(host: Node, data: CharacterData, size := 64) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size, size)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.03, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.65)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(20.0), 0.0)
	key.light_energy = 1.1
	viewport.add_child(key)
	for side: float in [-1.0, 1.0]:
		var rim := OmniLight3D.new()
		rim.position = Vector3(side * 0.6, 1.7, -0.4)
		rim.light_color = Palette.PINK if side < 0.0 else Palette.CYAN
		rim.light_energy = 2.0
		viewport.add_child(rim)
	var model := CharacterModel.new()
	model.data = data
	model.rotation.y = PI
	viewport.add_child(model)
	var eye := model.eye_height()
	var camera := Camera3D.new()
	camera.fov = 28.0
	viewport.add_child(camera)
	camera.position = Vector3(0.0, eye - 0.02, 0.95)
	camera.look_at(Vector3(0.0, eye - 0.07, 0.0), Vector3.UP)
	host.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image
