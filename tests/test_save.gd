extends Node
## Headless checks for saving/loading (slots per character, listing, deleting, converting a
## prototype-4 save), the 1107 key card door, Ren's key card and coupon, and the items scattered
## around the city. Writes to user://test_saves/, never the player's saves.
## Run: godot --headless --path . res://tests/test_save.tscn

var _failures := 0


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().physics_frame
	SaveGame.enabled = true
	SaveGame.root_dir = "user://test_saves"
	_wipe(SaveGame.root_dir)
	GameState.character = CharacterData.new()
	GameState.character.character_name = "Testy"
	GameState.character.character_id = "testy_1"
	var player := get_tree().get_first_node_in_group("player") as Player

	# Ren: first meeting hands over the key card and the coupon.
	var ren: Merchant
	for merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.is_guide:
			ren = merchant
	var dialogue := get_tree().get_first_node_in_group("dialogue_screen")
	ren.call("_on_interacted", player)
	_check(dialogue.is_open() and GameState.flags.get("met_guide", false), "talking to Ren starts the first meeting")
	dialogue.call("_pick", 0)
	_check(GameState.inventory.count(&"keycard_1107") == 1 and GameState.inventory.count(&"ren_coupon") == 1, "Ren gives the key card and a coupon")
	dialogue.call("_pick", 0)
	dialogue.call("_pick", 0)
	var labels: Array[String] = []
	for choice in dialogue.call("_visible_choices"):
		labels.append(choice["text"])
	_check(labels.has("I've got your coupon."), "the coupon choice shows while you have it")
	dialogue.call("_pick", labels.find("I've got your coupon."))
	_check(GameState.inventory.count(&"ren_coupon") == 0 and GameState.inventory.count(&"noodles") == 1, "the coupon buys a bowl of noodles")
	dialogue.close()

	# The 1107 door: key card from the hallway, always from inside.
	var door: Door
	for node in get_tree().get_nodes_in_group("saveable"):
		if node is ApartmentBlock:
			door = node.find_child("Door1107", true, false)
	_check(door != null, "found door 1107")
	if door:
		var hallway := door.global_transform * Vector3(0, 0.1, 1.0)
		var inside := door.global_transform * Vector3(0, 0.1, -1.0)
		player.global_position = inside
		var inside_says_hallway: bool = door.call("_from_hallway")
		player.global_position = hallway
		var hallway_says_hallway: bool = door.call("_from_hallway")
		_check(hallway_says_hallway and not inside_says_hallway, "the door knows the hallway side")
		GameState.inventory.remove(&"keycard_1107", 1)
		var prompt_without: String = door.call("_prompt")
		door.call("_on_used", player)
		_check(prompt_without.begins_with("Locked") and not door.is_open, "no key card, no entry from the hallway")
		player.global_position = inside
		door.call("_on_used", player)
		_check(door.is_open, "the door opens from inside without the card")
		door.set_open(false)
		player.global_position = hallway
		GameState.inventory.add(&"keycard_1107", 1)
		var prompt_with: String = door.call("_prompt")
		door.call("_on_used", player)
		_check(prompt_with.begins_with("Open") and door.is_open, "the key card opens it")

	# Scattered items.
	var scatter := get_tree().get_first_node_in_group("saveable")
	for node in get_tree().get_nodes_in_group("saveable"):
		if node is ItemScatter:
			scatter = node
	var pickups := scatter.get_children().filter(func(n: Node) -> bool: return n is Pickup)
	_check(pickups.size() == ItemScatter.SPOTS.size(), "every scatter spot has its item (%d)" % pickups.size())
	for pickup: Pickup in pickups:
		if pickup.global_position.y < 0.1 or pickup.global_position.y > 2.0:
			print("  odd height: ", pickup.item_id, " at ", pickup.global_position)
	var first: Pickup = pickups[0]
	first.call("_take", player)
	await get_tree().process_frame

	# Save, change everything, load.
	GameState.credits = 321
	GameState.change_reputation(&"noodles", 0.3)
	GameState.clock_minutes = 125.0
	GameState.set_waypoint(&"apartment")
	player.global_position = Vector3(3.0, 0.2, 4.0)
	player.weapon.ammo_in_magazine = 7
	var kaz: Merchant
	for merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.catalog == &"guns":
			kaz = merchant
	kaz.cash = 77
	kaz.anger_time = 50.0
	_check(SaveGame.save_game(SaveGame.AUTOSAVE, "Test"), "the game saves")
	GameState.credits = 0
	GameState.inventory.remove(&"noodles", 1)
	GameState.clear_waypoint()
	GameState.clock_minutes = 0.0
	player.global_position = Vector3(13.5, 0.2, -11.6)
	player.weapon.ammo_in_magazine = 30
	kaz.cash = 1000
	kaz.anger_time = 0.0
	GameState.character = CharacterData.new()
	_check(SaveGame.load_file(SaveGame.slot_path("testy_1", SaveGame.AUTOSAVE)), "the game loads")
	_check(GameState.character.character_name == "Testy", "the character comes back with the save")
	_check(GameState.credits == 321, "credits restored")
	_check(GameState.inventory.count(&"noodles") == 1 and GameState.inventory.count(&"keycard_1107") == 1, "inventory restored")
	_check(is_equal_approx(GameState.reputation_with(&"noodles"), 0.3), "reputation restored")
	_check(int(GameState.clock_minutes) == 125, "clock restored")
	_check(GameState.waypoint_id == &"apartment", "waypoint restored")
	_check(GameState.flags.get("met_guide", false), "Ren remembers you")
	_check(player.global_position.distance_to(Vector3(3.0, 0.2, 4.0)) < 0.01, "player position restored")
	_check(player.weapon.ammo_in_magazine == 7, "magazine restored")
	_check(kaz.cash == 77 and kaz.anger_time > 49.0, "merchant cash and mood restored")
	var remaining := scatter.get_children().filter(func(n: Node) -> bool: return n is Pickup and not n.is_queued_for_deletion())
	_check(remaining.size() == ItemScatter.SPOTS.size() - 1, "picked-up scatter items stay gone")
	GameState.pass_night(6.0)
	await get_tree().process_frame
	var refilled := scatter.get_children().filter(func(n: Node) -> bool: return n is Pickup and not n.is_queued_for_deletion())
	_check(refilled.size() == ItemScatter.SPOTS.size(), "scatter items come back after a night")

	# Slots and characters.
	await get_tree().create_timer(1.1).timeout
	_check(SaveGame.save_manual(), "a manual save adds a slot")
	var slots := SaveGame.list_slots("testy_1")
	_check(slots.size() == 2 and slots[0]["label"] == "Saved by hand", "slots are listed newest first (%d)" % slots.size())
	_check(slots[0].has("location") and slots[0].has("playtime") and slots[0].has("clock") and slots[0].has("saved_at"), "slots carry location, playtime, date and in-game time")
	var second := CharacterData.new()
	second.character_name = "Other"
	second.character_id = "other_2"
	GameState.character = second
	await get_tree().create_timer(1.1).timeout
	SaveGame.save_game(SaveGame.AUTOSAVE, "Other autosave")
	var characters := SaveGame.list_characters()
	_check(characters.size() == 2 and characters[0]["id"] == "other_2", "characters are listed, most recent first")
	_check(SaveGame.newest_save().contains("other_2"), "Continue picks the newest save")
	SaveGame.delete_slot(SaveGame.slot_path("other_2", SaveGame.AUTOSAVE))
	_check(SaveGame.list_characters().size() == 1, "deleting a character's last slot removes the character")

	# A prototype-4 save (version 1, one file) becomes a character "Tenant".
	SaveGame.legacy_path = "user://test_saves_legacy.json"
	var legacy := FileAccess.open(SaveGame.legacy_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 1, "saved_at": "2026-11-14T00:04:00", "game": {"credits": 77, "clock": 120.0, "inventory": {"ammo_ks47": 30}}, "player": {}, "world": {}}))
	legacy.close()
	_check(SaveGame.migrate_legacy(), "an old version-1 save is converted")
	var tenant := SaveGame.list_characters().filter(func(c: Dictionary) -> bool: return c["name"] == "Tenant")
	_check(tenant.size() == 1 and int(SaveGame.read_save(tenant[0]["slots"][0]["path"])["game"]["credits"]) == 77, "it keeps its credits as the character Tenant")
	_check(not FileAccess.file_exists(SaveGame.legacy_path) and FileAccess.file_exists(SaveGame.legacy_backup_path()), "the old file is kept as a backup")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.legacy_backup_path()))
	_wipe(SaveGame.root_dir)
	_check(SaveGame.list_characters().is_empty(), "test saves deleted")

	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for character in DirAccess.get_directories_at(dir):
		for file in DirAccess.get_files_at(dir.path_join(character)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(character).path_join(file)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(character)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
