extends Node3D
## Screenshots of the player model: a lineup of the five outfits on random characters, one in
## underwear, a close-up of a face and a walking pose. Run windowed:
## godot --path . res://tests/shot_character.tscn -- --out=/tmp/character

var _out := "/tmp/character"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.03, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.4, 0.6)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-25), 0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	add_child(key)
	var floor := CSGBox3D.new()
	floor.size = Vector3(20, 0.1, 10)
	floor.position = Vector3(0, -0.05, 0)
	add_child(floor)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ids := Outfits.ids()
	var models: Array[CharacterModel] = []
	for i in 6:
		var data := CharacterData.new()
		data.randomize_look(rng)
		data.outfit = ids[i] if i < ids.size() else &""
		var model := CharacterModel.new()
		model.data = data
		model.show_outfit = i < ids.size()
		model.position = Vector3(-2.75 + i * 1.1, 0, 0)
		model.rotation.y = PI + 0.35
		add_child(model)
		models.append(model)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 1.1, 4.6)
	camera.look_at(Vector3(0, 0.95, 0))
	camera.fov = 50
	await _shot("lineup")
	# Back view (tattoos on the back, hair from behind).
	for model in models:
		model.rotation.y = 0.0
	await _shot("lineup_back")
	# Face close-ups of three characters.
	for i in 3:
		var model := models[i]
		model.rotation.y = PI
		camera.position = model.position + Vector3(0, model.eye_height(), 0.65)
		camera.look_at(model.position + Vector3(0, model.eye_height() - 0.05, 0))
		await _shot("face_%d" % i)
	# Walking, running and aiming poses.
	camera.position = Vector3(0, 1.1, 4.6)
	camera.look_at(Vector3(0, 0.95, 0))
	for i in models.size():
		models[i].rotation.y = PI * 0.5
		models[i].pose(1.2 + i, 1.0, float(i % 2), 1.0 if i == 4 else 0.0, 0.6 if i == 5 else 0.0)
	await _shot("poses")
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])
