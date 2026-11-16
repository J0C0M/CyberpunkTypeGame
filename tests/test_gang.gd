extends Node
## Headless checks for the Rust Jackals: the crew spawns on the enemy navmesh and patrols, warns a
## player on their turf, turns hostile, takes cover and shoots (through the damage system), dies
## with loot, calms down after a respawn and is replaced overnight.
## Run: godot --headless --path . res://tests/test_gang.tscn

var _failures := 0


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var nav := get_tree().root.find_child("EnemyNav", true, false) as EnemyNav
	var started := Time.get_ticks_msec()
	if not nav.is_baked:
		await nav.baked
	print("  enemy navmesh baked in %d ms" % (Time.get_ticks_msec() - started))
	await get_tree().physics_frame
	var turf := get_tree().root.find_child("JackalTurf", true, false) as GangTurf
	var crew := turf.call("_living") as Array[GangMember]
	_check(crew.size() == 4, "a crew of four spawns (%d)" % crew.size())
	var starts: Array[Vector3] = []
	for member in crew:
		starts.append(member.global_position)
	await get_tree().create_timer(8.0).timeout
	var moved := 0
	for i in crew.size():
		if crew[i].global_position.distance_to(starts[i]) > 1.0:
			moved += 1
	_check(moved >= 2, "they stroll around the turf (%d moved)" % moved)

	var player := get_tree().get_first_node_in_group("player") as Player
	player.global_position = turf.global_position + Vector3(12.0, 0.2, 0.0)
	player.rotation.y = deg_to_rad(90.0)
	for member in crew:
		member.look_at(player.global_position, Vector3.UP)
	# Whoever is looking the player's way notices within a few seconds.
	var warned := false
	for i in 12:
		await get_tree().create_timer(0.25).timeout
		warned = warned or crew.any(func(m: GangMember) -> bool: return m.state == GangMember.State.WARN)
	_check(warned, "a player on their turf gets warned")
	await get_tree().create_timer(turf.warn_time + 1.0).timeout
	var hostile := crew.filter(func(m: GangMember) -> bool: return m.hostile).size()
	_check(hostile == 4, "ignoring the warning makes the whole crew hostile (%d)" % hostile)

	var shots := [0]
	var count_shots := func(_at: Vector3, _radius: float, severity: float, source: Node) -> void:
		if source is GangMember and severity == EventBus.SEVERITY_SHOT:
			shots[0] += 1
	EventBus.danger.connect(count_shots)
	# Measure the damage per second they deal to someone standing still in the open.
	player.health.invulnerable = true
	var taken := [0.0, 0]
	var count_hits := func(hit: HitInfo) -> void:
		taken[0] += hit.damage
		taken[1] += 1
	player.hurt.connect(count_hits)
	for i in 40:
		await get_tree().create_timer(0.25).timeout
	player.hurt.disconnect(count_hits)
	player.health.invulnerable = false
	EventBus.danger.disconnect(count_shots)
	var lowest: float = 100.0 - taken[0]
	var dps: float = taken[0] / 10.0
	var states := {}
	for member in crew:
		states[GangMember.State.keys()[member.state]] = states.get(GangMember.State.keys()[member.state], 0) + 1
	print("  states after 10 s of fighting: ", states, "  shots: ", shots[0], "  hits: ", taken[1], "  damage per second: ", dps)
	_check(shots[0] >= 6, "they shoot at the player")
	_check(lowest < 100.0, "some of their bullets land")
	# Depends on how close the crew happens to stand: typically 2.5-7.5 HP/s.
	_check(dps <= 8.0, "standing still in the open against four costs under 8 HP/s (forgiving)")
	var covered := crew.filter(func(m: GangMember) -> bool: return m.cover_spot() != Vector3.INF).size()
	_check(covered >= 1, "some of them use cover (%d)" % covered)

	var target := crew[0]
	var loot_before := get_tree().get_nodes_in_group("night_cleanup").filter(func(n: Node) -> bool: return n is Pickup).size()
	Damageable.deliver(target, HitInfo.create(200.0, target.global_position + Vector3.UP, Vector3.UP, Vector3.FORWARD, player))
	await get_tree().process_frame
	var loot_after := get_tree().get_nodes_in_group("night_cleanup").filter(func(n: Node) -> bool: return n is Pickup).size()
	_check(target.is_dead and loot_after > loot_before, "a shot Jackal dies and drops loot")

	get_tree().call_group("enemies", "on_player_respawned")
	var calm: int = turf.call("_living").filter(func(m: GangMember) -> bool: return not m.hostile).size()
	_check(calm == 3, "after a respawn the crew calms down")
	GameState.pass_night(6.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check((turf.call("_living") as Array).size() == 4, "a fresh crew is out the next night")

	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
