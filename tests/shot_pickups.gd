extends Node
## Screenshots of every item placed by ItemScatter, from a short distance on the street side.
## Run windowed: godot --path . res://tests/shot_pickups.tscn -- --out=/tmp/pickups

var _out := "/tmp/pickups"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 30:
		await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	var scatter: ItemScatter
	for node in get_tree().get_nodes_in_group("saveable"):
		if node is ItemScatter:
			scatter = node
	var index := 0
	for pickup in scatter.get_children():
		if not pickup is Pickup:
			continue
		var at: Vector3 = pickup.global_position
		# Step back towards the middle of the nearest street (or out of the lobby).
		var back := Vector3(0, 0, -signf(at.z)) if absf(at.z) < absf(at.x) else Vector3(-signf(at.x), 0, 0)
		if at.z < -9.5:
			back = Vector3(0, 0, 1)
		var eye := at + back * 1.4 + Vector3.UP * 1.25
		player.global_position = eye - Vector3.UP * player.head.position.y
		var look := (at + Vector3.UP * 0.25 - eye).normalized()
		player.rotation = Vector3(0.0, atan2(-look.x, -look.z), 0.0)
		player.head.rotation = Vector3(asin(look.y), 0.0, 0.0)
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s_%d_%s.png" % [_out, index, pickup.item_id]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path, "  ", at)
		index += 1
	get_tree().quit()
