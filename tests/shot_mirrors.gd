extends Node
## Screenshots of the three mirrors (apartment bathroom, Lucky Pawn, Cyberware) with a tattooed,
## neon-haired character holding a gun. Run windowed:
## godot --path . res://tests/shot_mirrors.tscn -- --out=/tmp/mirrors

var _out := "/tmp/mirrors"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	get_tree().set_meta("screenshot_mode", true)
	var data := CharacterData.new()
	data.outfit = &"outfit_street_runner"
	data.hair_style = 3
	data.hair_color = 7
	data.cyberware.append(&"led_line")
	data.tattoos.append({"design": &"wave", "zone": &"neck", "color": 4, "glow": true})
	GameState.character = data
	add_child(load("res://scenes/main.tscn").instantiate())
	await get_tree().create_timer(1.0).timeout
	var player := get_tree().get_first_node_in_group("player") as Player
	player.apply_character(data)
	var index := 0
	for mirror in get_tree().get_nodes_in_group("mirrors"):
		var glass := mirror as Node3D
		var normal := glass.global_basis.z
		player.set_physics_process(false)
		player.global_position = glass.global_position + normal * 1.1 + glass.global_basis.x * 0.15
		player.global_position.y = glass.global_position.y - 1.55
		var to := glass.global_position - (player.global_position + Vector3.UP * player.head.position.y)
		player.rotation = Vector3(0, atan2(-to.x, -to.z), 0)
		player.head.rotation = Vector3(asin(to.normalized().y), 0, 0)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [_out, index])
		print("mirror ", index, " at ", GameState.location_name(glass.global_position))
		index += 1
	get_tree().quit()
