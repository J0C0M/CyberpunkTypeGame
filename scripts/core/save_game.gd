extends Node
## Saving, loading and the flow between the menu and the game (autoload "SaveGame").
##
## Saves live per character in user://saves/<character id>/<slot>.json. Every slot holds:
## - "version" (VERSION; older files are converted or refused),
## - "meta": what the Load Game list shows (name, playtime, location, date, in-game time, portrait),
## - "character": the CharacterData (look, name, outfit) as its own section,
## - "game": GameState (credits, inventory, reputation, Ren's flags, clock, waypoint),
## - "player": position, health, guns; "world": every node in the "saveable" group.
## Slot "autosave" is written when sleeping, quitting and going back to the menu; Save Game in the
## pause menu adds a manual slot (the oldest manual slots go beyond MAX_MANUAL_SLOTS).
## The single user://savegame.json from prototype 4 is converted on start (prototype 3 had no saves).

signal saved
signal loaded

const VERSION := 2
const MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const AUTOSAVE := "autosave"
const MAX_MANUAL_SLOTS := 10

var root_dir := "user://saves"
var legacy_path := "user://savegame.json"
## Main turns this off for screenshot tours and tests, so they never touch the player's saves.
var enabled := true
## The slot Main should load when the game scene starts, or "" (new character, or nothing).
var pending_path := ""
## Set by the creator: Main makes the first save for the new character.
var pending_new := false
## Unix time of the last save in this session (for the "unsaved progress" warning).
var last_save_unix := 0.0


func _ready() -> void:
	# Closing the window goes through quit_game() so the game saves and shuts down cleanly.
	get_tree().set_auto_accept_quit(false)
	migrate_legacy()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


# --- Flow ------------------------------------------------------------------------------------------

## New Game: the city as a freshly created character (from the creator).
func start_new_character(data: CharacterData) -> void:
	data.character_id = CharacterData.new_id(data.character_name)
	GameState.character = data
	GameState.portrait_png = PackedByteArray()
	GameState.start_new_game()
	pending_new = true
	pending_path = ""
	_enter_game()


## Loads a slot: switches to the game scene, which applies it (Main calls apply_pending()).
func load_slot(path: String) -> void:
	pending_path = path
	pending_new = false
	_enter_game()


func _enter_game() -> void:
	GameState.release_ui()
	get_tree().paused = false
	Music.play_menu(false)
	get_tree().change_scene_to_file(GAME_SCENE)


## Called by Main once the world is built: loads the pending slot or makes a new character's first
## save. Without either (running main.tscn directly) the newest save is loaded, if there is one.
func apply_pending() -> bool:
	if not enabled:
		return false
	if pending_new:
		pending_new = false
		save_game(AUTOSAVE, "New citizen")
		return false
	var path := pending_path if pending_path != "" else newest_save()
	pending_path = ""
	return path != "" and load_file(path)


## Back to the title screen (optionally saving first).
func return_to_menu(save_first: bool) -> void:
	if save_first:
		save_game(AUTOSAVE, "Autosave")
	get_tree().paused = false
	_stop_audio()
	GameState.claim_ui(&"menu")
	get_tree().change_scene_to_file(MENU_SCENE)


## Saves (when in the city), silences every sound and quits a few frames later. Streams still
## playing at the moment the engine shuts down would be reported as leaked.
func quit_game() -> void:
	if GameState.ui_mode != &"menu" and get_tree().get_first_node_in_group("player"):
		save_game(AUTOSAVE, "Autosave")
	_stop_audio()
	for i in 6:
		await get_tree().process_frame
	get_tree().quit()


func _stop_audio() -> void:
	for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(player as AudioStreamPlayer).stop()
	for player in get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		(player as AudioStreamPlayer3D).stop()


# --- Saving ---------------------------------------------------------------------------------------

func character_dir(id: String) -> String:
	return root_dir.path_join(id)


func slot_path(id: String, slot: String) -> String:
	return character_dir(id).path_join(slot + ".json")


## Writes the running game to `slot` of the current character. Returns false when saving is off
## or the file can't be written.
func save_game(slot := AUTOSAVE, label := "") -> bool:
	var character := GameState.character
	if not enabled or character.character_id == "":
		return false
	var data := {
		"version": VERSION,
		"meta": _meta(slot, label),
		"character": character.to_dict(),
		"game": GameState.save_data(),
		"world": {},
	}
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("save_data"):
		data["player"] = player.save_data()
	for node in get_tree().get_nodes_in_group("saveable"):
		data["world"][node.save_key()] = node.save_data()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(character_dir(character.character_id)))
	var file := FileAccess.open(slot_path(character.character_id, slot), FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save slot %s: %s" % [slot, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	last_save_unix = Time.get_unix_time_from_system()
	saved.emit()
	return true


## Save Game from the pause menu: a new manual slot (the oldest manual slots are pruned).
func save_manual() -> bool:
	var stamp := int(Time.get_unix_time_from_system())
	if not save_game("manual_%d" % stamp, "Saved by hand"):
		return false
	var manual := list_slots(GameState.character.character_id).filter(func(slot: Dictionary) -> bool: return str(slot["slot"]).begins_with("manual_"))
	for old in manual.slice(MAX_MANUAL_SLOTS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(old["path"]))
	return true


func _meta(slot: String, label: String) -> Dictionary:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return {
		"slot": slot,
		"label": label if label != "" else ("Autosave" if slot == AUTOSAVE else "Saved by hand"),
		"character": GameState.character.character_name,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"unix": Time.get_unix_time_from_system(),
		"playtime": GameState.play_seconds,
		"location": GameState.location_name(player.global_position) if player else "Block 7",
		"clock": GameState.clock_text(),
		"portrait": Marshalls.raw_to_base64(GameState.portrait_png) if not GameState.portrait_png.is_empty() else "",
	}


# --- Loading --------------------------------------------------------------------------------------

## A parsed save file, or {} if it's missing, unreadable or from an unknown version.
func read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int((data as Dictionary).get("version", 0)) != VERSION:
		return {}
	return data


## Restores a save file into the running game. Returns false if it can't be read.
func load_file(path: String) -> bool:
	var data := read_save(path)
	if data.is_empty():
		push_warning("Ignoring an unreadable or outdated save: " + path)
		return false
	GameState.character = CharacterData.from_dict(data.get("character", {}))
	GameState.load_data(data.get("game", {}))
	var meta: Dictionary = data.get("meta", {})
	GameState.play_seconds = float(meta.get("playtime", 0.0))
	var portrait := str(meta.get("portrait", ""))
	GameState.portrait_png = Marshalls.base64_to_raw(portrait) if portrait != "" else PackedByteArray()
	var world: Dictionary = data.get("world", {})
	for node in get_tree().get_nodes_in_group("saveable"):
		var key: String = node.save_key()
		if world.has(key):
			node.load_data(world[key])
	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("apply_character"):
			player.apply_character(GameState.character)
		if player.has_method("load_data") and data.has("player"):
			player.load_data(data["player"])
	last_save_unix = Time.get_unix_time_from_system()
	loaded.emit()
	return true


## The slots of a character, newest first: each is its meta plus "path".
func list_slots(character_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var dir := character_dir(character_id)
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".json"):
			continue
		var data := read_save(dir.path_join(file))
		if data.is_empty():
			continue
		var meta: Dictionary = (data["meta"] as Dictionary).duplicate()
		meta["path"] = dir.path_join(file)
		meta["character_data"] = data.get("character", {})
		result.append(meta)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["unix"]) > float(b["unix"]))
	return result


## Every character with saves, most recently played first: {"id", "name", "slots", "newest"}.
func list_characters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(root_dir):
		return result
	for id in DirAccess.get_directories_at(root_dir):
		var slots := list_slots(id)
		if slots.is_empty():
			continue
		result.append({"id": id, "name": slots[0]["character"], "slots": slots, "newest": float(slots[0]["unix"])})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["newest"] > b["newest"])
	return result


## The most recent save of any character (Continue), or "".
func newest_save() -> String:
	var characters := list_characters()
	return characters[0]["slots"][0]["path"] if not characters.is_empty() else ""


func has_save() -> bool:
	return newest_save() != ""


## Deletes one slot; a character without slots left disappears from the list.
func delete_slot(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var dir := path.get_base_dir()
	if DirAccess.get_files_at(dir).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


# --- Old saves ------------------------------------------------------------------------------------

## Prototype 4 kept one save in user://savegame.json (version 1, no character). It becomes the
## autosave of a character called "Tenant" with the default look, and the old file is kept
## (legacy_backup_path()). Prototype 3 had no save system, so there is nothing older to convert.
func migrate_legacy() -> bool:
	if not FileAccess.file_exists(legacy_path):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(legacy_path))
	if not data is Dictionary or int((data as Dictionary).get("version", 0)) != 1:
		return false
	var character := CharacterData.new()
	character.character_name = "Tenant"
	character.character_id = CharacterData.new_id("tenant")
	var game: Dictionary = data.get("game", {})
	var clock := int(game.get("clock", 0))
	var converted := {
		"version": VERSION,
		"meta": {
			"slot": AUTOSAVE, "label": "Converted from prototype 4", "character": character.character_name,
			"saved_at": str(data.get("saved_at", Time.get_datetime_string_from_system(false, true))).replace("T", " "),
			"unix": Time.get_unix_time_from_system(), "playtime": 0.0, "location": "Block 7",
			"clock": "%02d:%02d" % [clock / 60, clock % 60], "portrait": "",
		},
		"character": character.to_dict(),
		"game": game,
		"player": data.get("player", {}),
		"world": data.get("world", {}),
	}
	# Version 1 had no clothes: the converted tenant gets the default outfit in the bag.
	var inventory: Dictionary = game.get("inventory", {})
	for item in Outfits.items(character.outfit):
		inventory[String(item)] = 1
	game["inventory"] = inventory
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(character_dir(character.character_id)))
	var file := FileAccess.open(slot_path(character.character_id, AUTOSAVE), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(converted, "\t"))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(legacy_path), ProjectSettings.globalize_path(legacy_backup_path()))
	return true


## Where a converted old save is kept: user://savegame_v1_backup.json.
func legacy_backup_path() -> String:
	return legacy_path.get_basename() + "_v1_backup.json"


## Small helpers for storing vectors in JSON.
static func vec_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func array_to_vec(a: Variant, fallback := Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback
