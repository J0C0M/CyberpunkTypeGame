extends Node
## Screenshot of Ren's main dialogue menu (the longest choice list).
## Run windowed: godot --path . res://tests/shot_dialogue.tscn -- --out=/tmp/dialogue

var _out := "/tmp/dialogue"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	get_tree().set_meta("screenshot_mode", true)
	add_child(load("res://scenes/main.tscn").instantiate())
	GameState.inventory.add(&"ren_coupon", 1)
	for i in 20:
		await get_tree().process_frame
	get_tree().get_first_node_in_group("dialogue_screen").open_dialogue("Ren", GuideDialogue.build(), &"hub", null)
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + ".png")
	get_tree().quit()
