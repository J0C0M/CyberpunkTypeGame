extends Node
## Frame-time benchmark (run windowed, vsync off): the crossing at rest, a chain of exploding cars
## with the crowd panicking, and a firefight with the whole gang and three police drones while the
## player fires. Prints average, 99th percentile and worst frame per scene, plus draw calls.
## Run: godot --path . res://tests/perf_bench.tscn

var _frames: PackedFloat32Array = []
var _draw_calls := 0
var _recording := false
var _blasts := 0


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	add_child(load("res://scenes/main.tscn").instantiate())
	var nav := get_tree().root.find_child("EnemyNav", true, false) as EnemyNav
	if not nav.is_baked:
		await nav.baked
	await get_tree().create_timer(2.0).timeout
	var player := get_tree().get_first_node_in_group("player") as Player
	player.health.invulnerable = true

	_place(player, Vector3(3, 0.15, 3), Vector3(-30, 2, -5))
	await _measure("crossing at rest", 4.0)

	EventBus.danger.connect(_count_blast)
	_place(player, Vector3(-28, 0.15, -1), Vector3(-42, 1, 4))
	for car in get_tree().get_nodes_in_group("cover"):
		if car is Car and (car as Node3D).global_position.distance_to(Vector3(-41, 0, 3.7)) < 5.0:
			Damageable.deliver(car, HitInfo.create(5000.0, (car as Node3D).global_position, Vector3.UP, Vector3.FORWARD, null, HitInfo.Kind.EXPLOSION))
	await _measure("car explosions + panic", 5.0)
	print("  explosions during that scene: ", _blasts)

	var turf := get_tree().root.find_child("JackalTurf", true, false) as GangTurf
	_place(player, turf.global_position + Vector3(13, 0.15, 1), turf.global_position + Vector3(0, 1.2, 0))
	turf.go_hostile(player.global_position)
	var police := get_tree().get_first_node_in_group("police") as PoliceDispatch
	police.add_heat(3.5)
	await get_tree().create_timer(8.0).timeout
	_recording = true
	for i in 300:
		if player.weapon and player.weapon.ammo_in_magazine <= 0:
			player.weapon.ammo_in_magazine = player.weapon.magazine_size
		if i % 6 == 0 and player.weapon:
			player.weapon.fire()
		await get_tree().process_frame
	_report("gang + 3 drones firefight")
	get_tree().quit()


func _count_blast(_at: Vector3, _radius: float, severity: float, _source: Node) -> void:
	if severity >= EventBus.SEVERITY_EXPLOSION:
		_blasts += 1


func _process(delta: float) -> void:
	if _recording:
		_frames.append(delta * 1000.0)
		_draw_calls = maxi(_draw_calls, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


func _place(player: Player, at: Vector3, target: Vector3) -> void:
	player.global_position = at
	var to := target - (at + Vector3.UP * 1.62)
	player.rotation = Vector3(0.0, atan2(-to.x, -to.z), 0.0)
	player.head.rotation = Vector3(asin(to.normalized().y), 0.0, 0.0)


func _measure(label: String, seconds: float) -> void:
	_recording = true
	await get_tree().create_timer(seconds).timeout
	_report(label)


func _report(label: String) -> void:
	_recording = false
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in sorted:
		total += f
	var avg := total / maxf(1, sorted.size())
	var p99: float = sorted[int(sorted.size() * 0.99)] if sorted.size() > 0 else 0.0
	var worst: float = sorted[sorted.size() - 1] if sorted.size() > 0 else 0.0
	print("%-28s avg %5.2f ms (%3d fps)  p99 %6.2f ms  worst %6.2f ms  draw calls %d  frames %d" % [label, avg, int(1000.0 / maxf(avg, 0.01)), p99, worst, _draw_calls, sorted.size()])
	_frames.clear()
	_draw_calls = 0
