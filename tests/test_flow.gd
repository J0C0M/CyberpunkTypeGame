extends Node
## Headless check of the whole flow: title screen -> New Game -> creator -> Confirm -> the city
## (with a first save) -> back to the menu (saving) -> Continue -> the same character again.
## Uses user://test_flow_saves/. Run: godot --headless --path . res://tests/test_flow.tscn


func _ready() -> void:
	# The scenes below replace this one, so the checks run from a node outside the current scene.
	var runner := Runner.new()
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	var failures := 0

	func _ready() -> void:
		SaveGame.root_dir = "user://test_flow_saves"
		SaveGame.enabled = true
		get_tree().change_scene_to_file(SaveGame.MENU_SCENE)
		await _frames(20)
		_check(get_tree().current_scene.name == "MainMenu" and GameState.ui_mode == &"menu", "the game starts on the title screen")
		get_tree().current_scene.call("_on_new_game")
		await _frames(20)
		var creator := get_tree().current_scene
		_check(creator.name == "CharacterCreator", "New Game opens the character creator")
		creator.data.character_name = "Flow"
		creator.data.outfit = &"outfit_punk"
		creator.get("_name_edit").text = "Flow"
		creator.call("_on_confirm")
		await _frames(60)
		var player := get_tree().get_first_node_in_group("player") as Player
		_check(player != null and GameState.is_free_roaming(), "Confirm starts the game in the city")
		_check(GameState.character.character_name == "Flow" and GameState.inventory.count(&"wear_punk_vest") == 1, "as the new character, wearing the chosen outfit")
		var slots := SaveGame.list_slots(GameState.character.character_id)
		_check(slots.size() == 1, "a new save slot is created right away")
		player.global_position = Vector3(20, 0.2, 2)
		GameState.add_credits(55)
		SaveGame.return_to_menu(true)
		await _frames(20)
		_check(get_tree().current_scene.name == "MainMenu", "Back to Main Menu returns to the title screen")
		GameState.credits = 0
		get_tree().current_scene.call("_on_continue")
		await _frames(60)
		player = get_tree().get_first_node_in_group("player") as Player
		_check(GameState.character.character_name == "Flow" and GameState.credits >= 55, "Continue loads the newest save")
		_check(player.global_position.distance_to(Vector3(20, 0.2, 2)) < 0.5, "back where the player was")
		for slot in SaveGame.list_slots(GameState.character.character_id):
			SaveGame.delete_slot(slot["path"])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.root_dir))
		print("TESTS DONE: %d failure(s)" % failures)
		get_tree().quit(1 if failures > 0 else 0)

	func _frames(count: int) -> void:
		for i in count:
			await get_tree().process_frame

	func _check(ok: bool, what: String) -> void:
		print(("PASS  " if ok else "FAIL  ") + what)
		if not ok:
			failures += 1
