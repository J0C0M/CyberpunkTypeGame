extends Node
## Headless checks for the item database, stacking, the weapon hotbar, using, dropping and
## picking up items. Run: godot --headless --path . res://tests/test_inventory.tscn

var _failures := 0


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	_check(ItemDB.all_ids().size() >= 23, "item database loads every item resource")
	_check(ItemDB.item(&"noodles").use_verb == "Eat", "item resource fields load")
	_check(ShopCatalog.profile(&"guns").stock.has(&"ammo_ks47"), "shop profiles load")

	var bag := Inventory.new(3)
	_check(bag.add(&"ammo_ks47", 400) == 400 and bag.used_slots() == 3, "ammo stacks 150 per slot")
	_check(bag.add(&"onigiri", 1) == 0, "full inventory refuses new items")
	_check(bag.add(&"ammo_ks47", 100) == 50, "a part-filled stack takes the rest")
	bag.load_dict(bag.to_dict())
	_check(bag.count(&"ammo_ks47") == 450, "inventory survives a save round trip")

	var player := get_tree().get_first_node_in_group("player") as Player
	_check(player.weapon != null and player.weapon.item_id == &"weapon_ks47", "the KS-47 is in hand")
	_check(player.weapon_holder.slots[0] == &"weapon_ks47", "the KS-47 sits in hotbar slot 1")

	GameState.inventory.add(&"synth_soda", 2)
	var line := GameState.use_item(&"synth_soda")
	_check(line != "" and GameState.effect(&"sprint") > 0.0, "drinking a soda starts the sprint effect")
	_check(GameState.inventory.count(&"synth_soda") == 1, "using an item takes one away")
	_check(GameState.use_item(&"scrap") == "", "junk can't be used")

	var screen := get_tree().get_first_node_in_group("inventory_screen")
	screen.open()
	_check(screen.is_open() and get_tree().paused and GameState.ui_mode == &"inventory", "inventory opens, pauses and owns input")
	screen.open()
	_check(GameState.ui_mode == &"inventory", "opening twice does nothing")
	screen.set("_selected", &"synth_soda")
	screen.call("_on_drop", false)
	_check(GameState.inventory.count(&"synth_soda") == 0, "dropping removes the item")
	screen.close()
	_check(not get_tree().paused and GameState.is_free_roaming(), "closing unpauses and frees input")
	await get_tree().process_frame
	var dropped: Pickup
	for node in get_tree().get_nodes_in_group("night_cleanup"):
		if node is Pickup and node.item_id == &"synth_soda":
			dropped = node
	_check(dropped != null, "a dropped item lies in the world")
	if dropped:
		dropped.call("_take", player)
		await get_tree().process_frame
		_check(GameState.inventory.count(&"synth_soda") == 1, "picking it up puts it back")

	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
