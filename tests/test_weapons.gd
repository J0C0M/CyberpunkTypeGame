extends Node
## Headless checks for the weapon hotbar with all three guns: buying, switching, firing, pellets,
## shell-by-shell reloading, and losing a gun (its magazine goes back to the reserve).
## Run: godot --headless --path . res://tests/test_weapons.tscn

var _failures := 0


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	var holder := player.weapon_holder

	var kaz: Merchant
	for merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.catalog == &"guns":
			kaz = merchant
	GameState.add_credits(2000)
	_check(kaz.sell_to_player(&"weapon_pistol", kaz.sell_price(&"weapon_pistol")) == "", "Kaz sells a pistol")
	_check(kaz.sell_to_player(&"weapon_shotgun", kaz.sell_price(&"weapon_shotgun")) == "", "Kaz sells a shotgun")
	kaz.sell_to_player(&"ammo_9mm", kaz.sell_price(&"ammo_9mm"))
	kaz.sell_to_player(&"ammo_shells", kaz.sell_price(&"ammo_shells"))
	await get_tree().process_frame
	_check(holder.slots == [&"weapon_ks47", &"weapon_pistol", &"weapon_shotgun"], "new guns fill hotbar slots 2 and 3")

	holder.select_slot(1)
	await get_tree().create_timer(0.6).timeout
	var pistol := player.weapon
	_check(pistol.item_id == &"weapon_pistol" and pistol.visible, "switching to slot 2 draws the pistol")
	_check(pistol.ammo_in_magazine == 0, "a new gun comes with an empty magazine")
	pistol.start_reload()
	await get_tree().create_timer(pistol.reload_time + 0.2).timeout
	_check(pistol.ammo_in_magazine == 12 and GameState.inventory.count(&"ammo_9mm") == 12, "reloading the pistol takes 12 rounds from the box")
	pistol.fire()
	_check(pistol.ammo_in_magazine == 11, "a pistol shot uses one round")

	holder.select_slot(2)
	await get_tree().create_timer(0.6).timeout
	var shotgun := player.weapon
	_check(shotgun.item_id == &"weapon_shotgun" and not pistol.visible, "slot 3 swaps to the shotgun")
	shotgun.start_reload()
	await get_tree().create_timer(shotgun.reload_time * 2.0 + 0.1).timeout
	_check(shotgun.ammo_in_magazine == 2 and shotgun.is_reloading, "the shotgun loads shell by shell (%d)" % shotgun.ammo_in_magazine)
	await get_tree().create_timer(shotgun.reload_time * 5.0).timeout
	_check(shotgun.ammo_in_magazine == 6 and not shotgun.is_reloading, "and stops when full")
	var impacts := [0]
	var count_impacts := func(_at: Vector3, _radius: float, severity: float, _source: Node) -> void:
		if severity == EventBus.SEVERITY_IMPACT:
			impacts[0] += 1
	EventBus.danger.connect(count_impacts)
	shotgun.fire()
	EventBus.danger.disconnect(count_impacts)
	_check(impacts[0] == shotgun.pellets, "one shell fires a spread of pellets (%d impacts)" % impacts[0])

	var reserve := GameState.inventory.count(&"ammo_shells")
	GameState.inventory.remove(&"weapon_shotgun", 1)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(holder.slots[2] == &"" and player.weapon != shotgun, "losing the shotgun empties its slot")
	_check(GameState.inventory.count(&"ammo_shells") == reserve + 5, "its loaded shells go back to the reserve")
	_check(player.weapon != null, "another gun is drawn")

	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
