extends Node
## Headless walk-through checks: walking out of the noodle bar, into the Neo-Heights lobby, riding
## the elevator, going through the 1107 door (no snagging on thresholds, no falling through
## floors), explosions stopping at walls, and menus refusing to open over each other.
## Run: godot --headless --path . res://tests/test_world.tscn

var _failures := 0
var _player: Player


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	add_child(load("res://scenes/main.tscn").instantiate())
	for i in 30:
		await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group("player") as Player
	_player.health.invulnerable = true
	var block: ApartmentBlock
	for node in get_tree().get_nodes_in_group("saveable"):
		if node is ApartmentBlock:
			block = node

	# The player's own body in first person.
	_check(_player.body != null and _player.body.visible, "the player has a body")
	_check(_player.camera.cull_mask & CharacterRig.FIRST_PERSON_HIDDEN == 0, "the first-person camera leaves out the head and arms")
	_check(absf(_player.head.position.y - _player.body.eye_height()) < 0.001, "the camera sits at the character's eye height")
	var arms := _player.weapon_holder.get_node_or_null("ViewArms") as ViewArms
	await get_tree().process_frame
	_check(arms != null and arms.visible and arms.get_child_count() == 6, "first-person arms hold the gun")
	var gun_in_hand := _player.body.slot(&"hand_r").get_child(0) as MeshInstance3D
	_check(gun_in_hand != null and gun_in_hand.layers == CharacterRig.FIRST_PERSON_HIDDEN, "the body holds the gun too, hidden from first person")
	var shadows := get_tree().root.find_children("*", "Light3D", true, false).filter(func(l: Light3D) -> bool: return l.shadow_enabled)
	_check(shadows.size() >= 1, "lights near the player cast shadows (%d)" % shadows.size())

	# Out of the noodle bar onto the street (the shop front faces +Z).
	var start := _player.global_position
	await _walk(Vector3(0, 0, 1), 3.0)
	_check(_player.global_position.z > -8.0 and _player.is_on_floor(), "walks out of the noodle bar onto the sidewalk (z %.1f)" % _player.global_position.z)

	# From the sidewalk into the lobby.
	_player.global_position = block.to_global(Vector3(1.0, 0.2, 2.0))
	await get_tree().physics_frame
	await _walk(-block.global_basis.z, 3.0)
	var local := block.to_local(_player.global_position)
	_check(local.z < -1.5 and absf(local.y - ApartmentBlock.FLOOR_Y) < 0.3, "walks in through the lobby doors (local z %.1f)" % local.z)

	# The elevator up to the 11th floor.
	_player.global_position = block.to_global(Vector3(ApartmentBlock.SHAFT_X, ApartmentBlock.FLOOR_Y + 0.05, ApartmentBlock.HALL_BACK_Z - 1.2))
	await get_tree().create_timer(0.3).timeout
	block.call("_ride", _player, 0)
	_check(GameState.ui_mode == &"elevator", "riding the elevator takes over input")
	var screen := get_tree().get_first_node_in_group("inventory_screen")
	screen.open()
	_check(not screen.is_open(), "the inventory can't be opened during the ride")
	await get_tree().create_timer(3.5).timeout
	local = block.to_local(_player.global_position)
	_check(absf(local.y - ApartmentBlock.UPPER_Y) < 0.3 and _player.is_on_floor(), "arrives on the 11th floor standing (local y %.2f)" % local.y)
	_check(GameState.is_free_roaming(), "control comes back after the ride")

	# Through the 1107 door into the apartment.
	var door := block.find_child("Door1107", true, false) as Door
	GameState.inventory.add(&"keycard_1107", 1)
	_player.global_position = door.to_global(Vector3(0, 0.1, 1.2))
	door.set_open(true)
	await get_tree().create_timer(0.6).timeout
	await _walk(-door.global_basis.z, 2.5)
	var through := door.to_local(_player.global_position).z
	_check(through < -1.0, "walks through the open door into 1107 (door-local z %.1f)" % through)
	await _walk(door.global_basis.z, 2.5)
	_check(door.to_local(_player.global_position).z > 0.8, "and back out to the hallway")

	# Explosions stop at walls: a blast on the sidewalk outside Iron Lotus doesn't reach Kaz.
	var kaz: Merchant
	for merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.catalog == &"guns":
			kaz = merchant
	var shop := kaz.get_parent() as Node3D
	var outside := shop.to_global(Vector3(3.5, 0.5, 2.5))
	var before := kaz.health.health
	Explosions.explode(self, outside, 9.0, 120.0, null)
	await get_tree().physics_frame
	_check(kaz.health.health == before, "a blast outside the shop doesn't hurt the shopkeeper behind the wall")
	var npc: Npc
	for node in get_tree().root.find_child("Crowd", true, false).get_children():
		if node is Npc and not node.is_dead:
			npc = node
			break
	var hp := npc.health.health
	Explosions.explode(self, npc.global_position + Vector3(2.0, 0.5, 0.0), 6.0, 20.0, null)
	await get_tree().physics_frame
	_check(npc.health.health < hp, "a blast in the open still hurts people nearby")

	# Menus don't stack.
	get_tree().get_first_node_in_group("dialogue_screen").open_dialogue("Ren", GuideDialogue.build(), &"hub", null)
	screen.open()
	_check(not screen.is_open(), "the inventory doesn't open over a dialogue")
	get_tree().get_first_node_in_group("dialogue_screen").close()
	print("  after closing: ui_mode '%s', mouse mode %d (headless can't capture the mouse)" % [GameState.ui_mode, Input.mouse_mode])
	var headless := DisplayServer.get_name() == "headless"
	_check(GameState.is_free_roaming() and (headless or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED), "closing the dialogue hands control (and the mouse) back")

	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Holds "forward" for `seconds` with the player turned to face `direction`.
func _walk(direction: Vector3, seconds: float) -> void:
	_player.rotation = Vector3(0.0, atan2(-direction.x, -direction.z), 0.0)
	Input.action_press("move_forward")
	await get_tree().create_timer(seconds).timeout
	Input.action_release("move_forward")
	for i in 10:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
