extends Node
## Saving and loading (autoload "SaveGame"). One save file in user:// (JSON) holds GameState
## (credits, inventory, reputation, story flags such as meeting Ren, the clock and the waypoint),
## the player (where they stand, which guns are loaded) and every node in the "saveable" group
## (merchants' cash, stock and mood, the fridge, items lying around the city). Those nodes provide
## save_key() -> String, save_data() -> Dictionary and load_data(data: Dictionary).
## Sleeping in the bed saves; quitting saves; starting the game loads (Main calls load_game()).

signal saved
signal loaded

const VERSION := 1

var path := "user://savegame.json"
## Main turns this off for screenshot tours, so they never touch the player's save.
var enabled := true


func has_save() -> bool:
	return FileAccess.file_exists(path)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Writes the current game to disk. Returns false if saving is off or the file can't be written.
func save_game() -> bool:
	if not enabled:
		return false
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game": GameState.save_data(),
		"world": {},
	}
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("save_data"):
		data["player"] = player.save_data()
	for node in get_tree().get_nodes_in_group("saveable"):
		data["world"][node.save_key()] = node.save_data()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the save file %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	saved.emit()
	return true


## Restores the save on disk into the running game. Returns false when there is nothing to load.
func load_game() -> bool:
	if not enabled or not has_save():
		return false
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or int((data as Dictionary).get("version", 0)) != VERSION:
		push_warning("Ignoring an unreadable or outdated save file: " + path)
		return false
	GameState.load_data(data.get("game", {}))
	var world: Dictionary = data.get("world", {})
	for node in get_tree().get_nodes_in_group("saveable"):
		var key: String = node.save_key()
		if world.has(key):
			node.load_data(world[key])
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("load_data") and data.has("player"):
		player.load_data(data["player"])
	loaded.emit()
	return true


func _notification(what: int) -> void:
	# Closing the window: keep the night's progress.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


## Small helpers for storing vectors in JSON.
static func vec_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func array_to_vec(a: Variant, fallback := Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback
