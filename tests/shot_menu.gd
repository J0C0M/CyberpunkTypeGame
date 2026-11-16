extends Node
## Screenshots of the title screen, Load Game, Settings, Credits and the in-game pause menu.
## Only reads saves. Run windowed: godot --path . res://tests/shot_menu.tscn -- --out=/tmp/menu

var _out := "/tmp/menu"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await _wait(120)
	await _shot("title")
	menu.call("_on_load")
	await _wait(10)
	await _shot("load")
	menu.call("_show_main")
	menu.call("_on_settings")
	await _wait(5)
	await _shot("settings_graphics")
	var settings: SettingsMenu = menu.get("_settings")
	settings.call("_select", 2)
	await _wait(5)
	await _shot("settings_controls")
	menu.call("_show_main")
	menu.call("_on_credits")
	await _wait(5)
	await _shot("credits")
	menu.queue_free()
	await _wait(2)
	get_tree().set_meta("screenshot_mode", true)
	add_child(load("res://scenes/main.tscn").instantiate())
	await _wait(30)
	get_tree().get_first_node_in_group("pause_menu").open()
	await _wait(5)
	await _shot("pause")
	get_tree().quit()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])
