extends Node
## Headless checks for the wanted level and police drones: heat from gunfire and kills, drones
## per star that find and shoot the player, merchants refusing to trade, drones going down with
## a bang, and heat clearing and cooling off.
## Run: godot --headless --path . res://tests/test_police.tscn

var _failures := 0


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 30:
		await get_tree().physics_frame
	var police := get_tree().get_first_node_in_group("police") as PoliceDispatch
	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = Vector3(20.0, 0.2, 0.0)
	_check(police.stars() == 0 and get_tree().get_nodes_in_group("police_drones").is_empty(), "no heat, no drones at the start")

	for i in 15:
		EventBus.emit_danger(player.global_position, 35.0, EventBus.SEVERITY_SHOT, player)
	_check(police.stars() == 1 and GameState.wanted == 1, "gunfire in the street earns a star (heat %.2f)" % police.heat)
	await get_tree().create_timer(0.5).timeout
	_check(get_tree().get_nodes_in_group("police_drones").size() == 1, "one star sends one drone")

	var victim: Npc
	for node in get_tree().root.find_child("Crowd", true, false).get_children():
		if node is Npc and not node.is_dead:
			victim = node
			break
	Damageable.deliver(victim, HitInfo.create(500.0, victim.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD, player))
	_check(police.stars() == 2, "killing a pedestrian adds more heat (%.2f)" % police.heat)
	var kaz: Merchant
	for merchant in get_tree().get_nodes_in_group("merchants"):
		if merchant.catalog == &"guns":
			kaz = merchant
	_check(not kaz.can_trade(), "shopkeepers won't trade with two stars")
	await get_tree().create_timer(4.5).timeout
	_check(get_tree().get_nodes_in_group("police_drones").size() == 2, "two stars, two drones")

	player.health.invulnerable = true
	var taken := [0.0, 0]
	var count_hits := func(hit: HitInfo) -> void:
		if hit.source is PoliceDrone:
			taken[0] += hit.damage
			taken[1] += 1
	player.hurt.connect(count_hits)
	var closest := INF
	for i in 60:
		await get_tree().create_timer(0.25).timeout
		for drone in get_tree().get_nodes_in_group("police_drones"):
			closest = minf(closest, drone.global_position.distance_to(player.global_position))
	player.hurt.disconnect(count_hits)
	player.health.invulnerable = false
	print("  closest drone: %.1f m, hits: %d, damage per second: %.1f" % [closest, taken[1], taken[0] / 15.0])
	_check(closest < 25.0, "the drones fly in to the player")
	_check(taken[1] > 0, "the drones shoot the player")
	_check(taken[0] / 15.0 < 5.0, "two drones deal under 5 HP/s (forgiving)")

	var drone := get_tree().get_nodes_in_group("police_drones")[0] as PoliceDrone
	var core := drone.get("_core") as Area3D
	Damageable.deliver(core, HitInfo.create(40.0, drone.global_position, Vector3.UP, Vector3.FORWARD, player))
	_check(drone.health.health <= drone.max_health - 99.0 or drone.is_dead, "the core takes extra damage")
	var heat_before := police.heat
	for i in 180:
		await get_tree().physics_frame
		if not is_instance_valid(drone):
			break
	_check(not is_instance_valid(drone), "a downed drone crashes and is gone")
	_check(police.heat >= heat_before, "shooting drones doesn't cool things down")

	police.clear_heat()
	_check(police.stars() == 0 and GameState.wanted == 0, "clearing heat (respawn, sleep) resets the stars")
	kaz.refuse_time = 0.0
	kaz.panic_time = 0.0
	_check(kaz.can_trade(), "and shopkeepers trade again once they've calmed down")
	await get_tree().create_timer(7.0).timeout
	_check(get_tree().get_nodes_in_group("police_drones").is_empty(), "the drones fly off when the heat is gone")

	# No more drones: nobody is watching the player now.
	police.drone_scene = null
	police.add_heat(1.5)
	police.set("_since_incident", 100.0)
	police.since_seen = 100.0
	await get_tree().create_timer(4.0).timeout
	_check(police.heat < 1.0, "heat cools off when nobody sees the player (%.2f)" % police.heat)

	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
