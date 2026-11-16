extends Node
## Screenshots of police drones hunting the player and the wanted stars on the HUD.
## Run windowed: godot --path . res://tests/shot_police.tscn -- --out=/tmp/police

var _out := "/tmp/police"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().physics_frame
	var police := get_tree().get_first_node_in_group("police") as PoliceDispatch
	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = Vector3(25.0, 0.2, 0.0)
	player.health.invulnerable = true
	police.add_heat(2.6)
	await get_tree().create_timer(10.0).timeout
	var drones := get_tree().get_nodes_in_group("police_drones")
	for i in mini(2, drones.size()):
		var drone := drones[i] as Node3D
		player.set_physics_process(false)
		var eye := player.global_position + Vector3.UP * 1.62
		var to := drone.global_position - eye
		player.rotation = Vector3(0.0, atan2(-to.x, -to.z), 0.0)
		player.head.rotation = Vector3(asin(to.normalized().y), 0.0, 0.0)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_drone_%d.png" % [_out, i])
		print("drone %d at %s, %.1f m away" % [i, drone.global_position, to.length()])
	get_tree().quit()
