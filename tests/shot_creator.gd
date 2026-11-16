extends Node
## Screenshots of the character creator: each tab, a face close-up, the underwear preview and a
## randomized character. Run windowed: godot --path . res://tests/shot_creator.tscn -- --out=/tmp/creator

var _out := "/tmp/creator"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	var creator: Node = load("res://scenes/character_creator.tscn").instantiate()
	add_child(creator)
	await _wait(30)
	await _shot("identity")
	creator.call("_select_tab", 1)
	await _wait(40)
	await _shot("face")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	creator.set("_rng", rng)
	creator.call("_on_randomize")
	creator.data.tattoos.append({"design": &"dragon", "zone": &"chest", "color": 4, "glow": true})
	creator.data.tattoos.append({"design": &"circuit", "zone": &"forearm_r", "color": 5, "glow": true})
	creator.call("_changed")
	creator.call("_select_tab", 4)
	await _wait(40)
	await _shot("tattoos")
	creator.get("_underwear").button_pressed = true
	await _wait(30)
	await _shot("underwear")
	creator.get("_underwear").button_pressed = false
	creator.call("_select_tab", 5)
	creator.data.muscle = 1.0
	creator.call("_changed")
	await _wait(30)
	await _shot("outfit")
	get_tree().quit()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])
