extends Node
## Headless checks for player health: damage through the damage system, regeneration, healing
## items, the flatline and the respawn with its credit penalty.
## Run: godot --headless --path . res://tests/test_health.tscn

var _failures := 0


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 10:
		await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	_check(player.health.health == 100.0, "the player starts at full health")

	var hit := HitInfo.create(30.0, player.global_position, Vector3.UP, Vector3.FORWARD, null)
	_check(Damageable.deliver(player, hit) == player.health and player.health.health == 70.0, "bullets reach the player through the damage system")
	var blast := HitInfo.create(40.0, player.global_position, Vector3.UP, Vector3.FORWARD, null, HitInfo.Kind.EXPLOSION)
	Damageable.deliver(player, blast)
	_check(player.health.health == 50.0, "explosions hurt the player half as much")
	await get_tree().create_timer(1.0).timeout
	_check(player.health.health == 50.0, "no regeneration right after a hit")
	await get_tree().create_timer(5.0).timeout
	_check(player.health.health > 55.0, "health comes back after a few quiet seconds (%d)" % player.health.health)

	Damageable.deliver(player, HitInfo.create(40.0, player.global_position, Vector3.UP, Vector3.FORWARD, null))
	var before := player.health.health
	GameState.inventory.add(&"med_patch", 1)
	player.call("_quick_heal")
	_check(player.health.health >= before + 44.0 and GameState.inventory.count(&"med_patch") == 0, "H uses a med patch")
	GameState.inventory.add(&"onigiri", 1)
	Damageable.deliver(player, HitInfo.create(20.0, player.global_position, Vector3.UP, Vector3.FORWARD, null))
	before = player.health.health
	GameState.use_item(&"onigiri")
	_check(is_equal_approx(player.health.health, before + 10.0), "food heals a little")

	GameState.credits = 500
	var start := player.global_position
	player.global_position = Vector3(0.0, 0.2, 0.0)
	Damageable.deliver(player, HitInfo.create(500.0, player.global_position, Vector3.UP, Vector3.FORWARD, null))
	_check(player.is_dead and GameState.ui_mode == &"dead", "enough damage flatlines the player")
	await get_tree().create_timer(7.0).timeout
	_check(not player.is_dead and player.health.health == 100.0, "the player respawns at full health")
	_check(GameState.credits == 450, "the clinic bills 10%% (%d left)" % GameState.credits)
	_check(player.global_position.distance_to(start) < 1.0, "without a key card you wake up at Ren's")
	_check(GameState.is_free_roaming(), "control comes back after the respawn")

	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
