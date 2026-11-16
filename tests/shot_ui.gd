extends Node
## Renders screenshots of the menus (inventory, inspect view, trade) for visual checks.
## Run windowed: godot --path . res://tests/shot_ui.tscn -- --out=/tmp/ui

var _out := "/tmp/ui"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for id: StringName in [&"noodles", &"sushi", &"synth_soda", &"volt_can", &"sake", &"med_patch", &"focus_stim", &"scrap", &"data_shard", &"lucky_cat", &"jade_koi", &"optic_lens", &"keycard_1107", &"ren_coupon", &"vinyl", &"onigiri", &"burnt_chip", &"deck_board", &"gold_lighter", &"neural_implant", &"reflex_wire"]:
		GameState.inventory.add(id, 3 if ItemDB.stack_size(id) > 3 else 1)
	GameState.inventory.add(&"ammo_ks47", 200)
	GameState.apply_effect(&"sprint", 0.2, 40.0, "SUGAR RUSH")
	for i in 30:
		await get_tree().process_frame
	var screen := get_tree().get_first_node_in_group("inventory_screen")
	screen.open()
	screen.set("_selected", &"noodles")
	screen.call("_refresh")
	await _shot("inventory")
	screen.set("_selected", &"jade_koi")
	screen.call("_on_inspect")
	for i in 20:
		await get_tree().process_frame
	await _shot("inspect")
	screen.call("_on_tab", 3)
	screen.set("_selected", &"weapon_ks47")
	screen.call("_on_tab", 1)
	await _shot("weapons_tab")
	screen.close()
	get_tree().call_group("hud", "notify_item", "+ Synth-Soda", Palette.CYAN)
	get_tree().call_group("hud", "notify_item", "+ 30 KS-47 Rounds", Palette.AMBER)
	for i in 10:
		await get_tree().process_frame
	await _shot("hud")
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])
	print("saved ", name)
