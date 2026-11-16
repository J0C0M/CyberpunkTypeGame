extends Node
## Screenshots of the three guns in hand on the street and the weapons tab of the inventory.
## Run windowed: godot --path . res://tests/shot_weapons.tscn -- --out=/tmp/weapons

var _out := "/tmp/weapons"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for id: StringName in [&"weapon_pistol", &"weapon_shotgun", &"ammo_9mm", &"ammo_shells"]:
		GameState.inventory.add(id, 1 if id.begins_with("weapon") else 48)
	for i in 20:
		await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	player.global_position = Vector3(2.0, 0.15, 2.0)
	player.rotation.y = deg_to_rad(20.0)
	for slot in 3:
		player.weapon_holder.select_slot(slot)
		await get_tree().create_timer(0.7).timeout
		player.weapon.ammo_in_magazine = player.weapon.magazine_size
		await _shot("gun_%d" % slot)
		player.weapon.fire()
		await get_tree().process_frame
		await _shot("gun_%d_fire" % slot)
	var screen := get_tree().get_first_node_in_group("inventory_screen")
	screen.open()
	screen.call("_on_tab", 1)
	await _shot("weapons_tab")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])
