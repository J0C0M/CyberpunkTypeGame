extends Node
## Measures how often pedestrians get stuck (trying to walk, barely moving) over 40 seconds,
## including a panic. Pass `-- --no-obstacles` to compare with props not cut out of the navmesh.
## Run: godot --headless --path . res://tests/test_crowd.tscn

var _failures := 0


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	if OS.get_cmdline_user_args().has("--no-obstacles"):
		NpcCrowd.cut_out_obstacles = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 120:
		await get_tree().physics_frame
	var crowd := get_tree().root.find_child("Crowd", true, false)
	var stuck_time := {}
	var spots := {}
	var samples := 0
	var stuck_samples := 0
	for step in 160:
		await get_tree().create_timer(0.25).timeout
		if step == 60:
			# A scare in the middle of the crossing: everyone nearby runs.
			EventBus.emit_danger(Vector3(0, 0, 0), 40.0, EventBus.SEVERITY_EXPLOSION, null)
		for node in crowd.get_children():
			var npc := node as Npc
			if npc == null or npc.is_dead or not is_instance_valid(npc):
				continue
			var wants := npc.agent.velocity.length() > 0.5
			var moves := Vector2(npc.velocity.x, npc.velocity.z).length() > 0.2
			samples += 1
			if wants and not moves:
				stuck_samples += 1
				stuck_time[npc.name] = stuck_time.get(npc.name, 0.0) + 0.25
				if OS.get_cmdline_user_args().has("--where"):
					var spot := Vector2i(roundi(npc.global_position.x), roundi(npc.global_position.z))
					spots[spot] = spots.get(spot, 0) + 1
	if not spots.is_empty():
		var keys := spots.keys()
		keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return spots[a] > spots[b])
		for key in keys.slice(0, 12):
			print("  stuck at ", key, ": ", spots[key])
	var long_stuck := stuck_time.values().filter(func(t: float) -> bool: return t >= 3.0).size()
	print("  stuck samples: %d of %d (%.1f %%), pedestrians stuck 3 s or more: %d" % [stuck_samples, samples, 100.0 * stuck_samples / maxf(1, samples), long_stuck])
	_check(stuck_samples < samples * 0.03, "fewer than 3 % of walking samples are stuck")
	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
