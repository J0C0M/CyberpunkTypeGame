extends Node
## Developer helper that renders screenshots from fixed viewpoints and quits.
##
## Usage (everything after `--` is passed to the game):
##   godot --path . -- --shots=/tmp/city --views="0,1.7,0,0,0;20,30,40,45,-20" --frames=60
## Each view is "x,y,z,yaw_degrees,pitch_degrees"; images are saved as <shots>_<index>.png.
## --fire-frames=N fires the player's rifle during the last N frames of each view.

var shot_prefix := ""
var views: Array[PackedFloat64Array] = []
var frames_per_view := 60
var fire_frames := 0

var _view_index := 0
var _frame := 0


static func from_cmdline() -> Node:
	var runner := new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			runner.shot_prefix = arg.trim_prefix("--shots=")
		elif arg.begins_with("--frames="):
			runner.frames_per_view = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--fire-frames="):
			runner.fire_frames = int(arg.trim_prefix("--fire-frames="))
		elif arg.begins_with("--views="):
			for view in arg.trim_prefix("--views=").split(";", false):
				runner.views.append(view.split_floats(","))
	if runner.shot_prefix.is_empty():
		runner.free()
		return null
	return runner


func _ready() -> void:
	if views.is_empty():
		views.append(PackedFloat64Array())
	_apply_view()


func _process(_delta: float) -> void:
	_frame += 1
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and _frame > frames_per_view - fire_frames and player.weapon.ammo_in_magazine > 0:
		player.weapon.call("_fire")
	if _frame < frames_per_view:
		return
	var path := "%s_%d.png" % [shot_prefix, _view_index]
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved screenshot ", path)
	_frame = 0
	_view_index += 1
	if _view_index >= views.size():
		get_tree().quit()
	else:
		_apply_view()


func _apply_view() -> void:
	var view := views[_view_index]
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or view.size() < 5:
		return
	player.set_physics_process(false)
	player.global_position = Vector3(view[0], view[1] - player.head.position.y, view[2])
	player.rotation = Vector3(0.0, deg_to_rad(view[3]), 0.0)
	player.head.rotation = Vector3(deg_to_rad(view[4]), 0.0, 0.0)
