extends Node
## Screenshots of the first-person character: bare tattooed arms (punk vest) on each gun, sleeves
## (techwear), and looking down at the body and its shadow. Run windowed:
## godot --path . res://tests/shot_firstperson.tscn -- --out=/tmp/fp

var _out := "/tmp/fp"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	get_tree().set_meta("screenshot_mode", true)
	var data := CharacterData.new()
	data.skin_tone = 3
	data.muscle = 0.8
	data.outfit = &"outfit_punk"
	data.tattoos.append({"design": &"circuit", "zone": &"forearm_r", "color": 5, "glow": true})
	data.tattoos.append({"design": &"koi", "zone": &"forearm_l", "color": 2, "glow": false})
	data.tattoos.append({"design": &"barcode", "zone": &"hand_r", "color": 0, "glow": false})
	GameState.character = data
	add_child(load("res://scenes/main.tscn").instantiate())
	for id: StringName in [&"weapon_pistol", &"weapon_shotgun", &"ammo_9mm", &"ammo_shells"]:
		GameState.inventory.add(id, 1 if id.begins_with("weapon") else 48)
	await _wait(30)
	var player := get_tree().get_first_node_in_group("player") as Player
	player.apply_character(data)
	player.set_physics_process(false)
	player.global_position = Vector3(2.5, 0.15, 6.4)
	player.rotation.y = deg_to_rad(-90.0)
	for slot in 3:
		player.weapon_holder.select_slot(slot)
		await get_tree().create_timer(0.7).timeout
		await _shot("gun_%d" % slot)
	player.head.rotation.x = deg_to_rad(-70.0)
	player.set_physics_process(true)
	await get_tree().create_timer(1.0).timeout
	await _shot("look_down")
	# From outside: the body walking with the gun up, and its shadow.
	player.global_position = Vector3(16.0, 0.15, -6.4)
	player.head.rotation.x = 0.0
	var outside := Camera3D.new()
	player.get_parent().add_child(outside)
	outside.global_position = player.global_position + Vector3(-2.2, 1.6, 2.4)
	outside.look_at(player.global_position + Vector3(0, 0.9, 0))
	outside.current = true
	await get_tree().create_timer(1.2).timeout
	await _shot("outside")
	player.camera.current = true
	outside.queue_free()
	data.outfit = &"outfit_techwear"
	player.apply_character(data)
	player.head.rotation.x = 0.0
	player.weapon_holder.select_slot(0)
	await get_tree().create_timer(0.8).timeout
	await _shot("sleeves")
	get_tree().quit()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])
