extends Node
## Screenshots of the Rust Jackals' turf: calm, warning, and a firefight (enemies in cover,
## tracers, the damage vignette and arcs). Run windowed:
## godot --path . res://tests/shot_gang.tscn -- --out=/tmp/gang

var _out := "/tmp/gang"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	get_tree().set_meta("screenshot_mode", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var nav := get_tree().root.find_child("EnemyNav", true, false) as EnemyNav
	if not nav.is_baked:
		await nav.baked
	var turf := get_tree().root.find_child("JackalTurf", true, false) as GangTurf
	var player := get_tree().get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	_place(player, turf.global_position + Vector3(20.0, 0.15, 3.0), turf.global_position + Vector3(-4.0, 1.0, -1.0))
	await get_tree().create_timer(3.0).timeout
	await _shot("calm")
	player.set_physics_process(true)
	_place(player, turf.global_position + Vector3(11.0, 0.15, 1.0), turf.global_position + Vector3(-2.0, 1.2, 0.0))
	await get_tree().create_timer(2.5).timeout
	await _shot("warning")
	player.health.invulnerable = true
	turf.go_hostile(player.global_position)
	await get_tree().create_timer(5.0).timeout
	for i in 12:
		await get_tree().create_timer(0.1).timeout
		if player.get_tree().get_first_node_in_group("hud").get("_hurt_flash") > 0.3:
			break
	await _shot("firefight")
	get_tree().quit()


func _place(player: Player, at: Vector3, look_at: Vector3) -> void:
	player.global_position = at
	var to := look_at - (at + Vector3.UP * 1.62)
	player.rotation = Vector3(0.0, atan2(-to.x, -to.z), 0.0)
	player.head.rotation = Vector3(asin(to.normalized().y), 0.0, 0.0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])
