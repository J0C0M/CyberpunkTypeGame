extends Node
## Developer helper: flies the camera along fixed viewpoints all over the block (the noodle bar
## spawn, the streets, every shop, the sushi cafe, the Neo-Heights lobby, elevator, hallway and
## apartment, the gang corner, the skyline) and saves a screenshot of each, then quits.
##
## Usage:  godot --path . -- --tour=/tmp/tour [--only=lobby,hallway] [--frames=40]
## Images are saved as <prefix>_<nn>_<name>.png. Viewpoints are found from the scene (shop and
## building nodes), so they follow the buildings if the city layout changes.

var prefix := ""
var only: PackedStringArray = []
var frames := 40

## [name, eye position, point looked at]
var _views: Array = []


static func from_cmdline() -> Node:
	var tour := new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tour="):
			tour.prefix = arg.trim_prefix("--tour=")
		elif arg.begins_with("--only="):
			tour.only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--frames="):
			tour.frames = int(arg.trim_prefix("--frames="))
	if tour.prefix.is_empty():
		tour.free()
		return null
	return tour


func _ready() -> void:
	# Let the city, the crowd and the icons settle first.
	for i in 30:
		await get_tree().physics_frame
	_collect_views()
	var player := get_tree().get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	player.health.invulnerable = true
	var index := 0
	for view in _views:
		var view_name: String = view[0]
		if not only.is_empty() and not only.has(view_name):
			continue
		_aim(player, view[1], view[2])
		for i in frames:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s_%02d_%s.png" % [prefix, index, view_name]
		get_viewport().get_texture().get_image().save_png(path)
		print("Saved ", path)
		index += 1
	get_tree().quit()


func _aim(player: Player, eye: Vector3, target: Vector3) -> void:
	player.global_position = eye - Vector3.UP * player.head.position.y
	var to := (target - eye).normalized()
	player.rotation = Vector3(0.0, atan2(-to.x, -to.z), 0.0)
	player.head.rotation = Vector3(asin(clampf(to.y, -1.0, 1.0)), 0.0, 0.0)


func _add(view_name: String, eye: Vector3, target: Vector3) -> void:
	_views.append([view_name, eye, target])


func _collect_views() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	_add("spawn_noodle_bar", player.global_position + Vector3.UP * 1.62, player.global_position + Vector3(0, 1.3, -4.0))
	_add("main_street_east", Vector3(-28, 1.7, 1.5), Vector3(20, 2.5, 0))
	_add("main_street_west", Vector3(28, 1.7, -1.5), Vector3(-20, 2.5, 0))
	_add("cross_street", Vector3(1.5, 1.7, 30), Vector3(0, 2.5, -20))
	_add("crossing_sidewalk", Vector3(7.0, 1.7, 7.0), Vector3(20, 2.0, 7.5))
	var world := get_tree().current_scene if get_tree().current_scene else get_tree().root
	for node in world.find_children("*", "Node3D", true, false):
		if node is ShopInterior:
			var shop := node as ShopInterior
			var label := String(shop.place_id)
			_add("shop_%s_inside" % label, shop.to_global(Vector3(0.0, 1.75, -1.0)), shop.to_global(Vector3(0.0, 1.35, -7.0)))
			_add("shop_%s_front" % label, shop.to_global(Vector3(0.0, 1.7, 6.5)), shop.to_global(Vector3(0.0, 2.6, 0.0)))
		elif node is SushiCafe:
			var cafe := node as Node3D
			_add("sushi_cafe_inside", cafe.to_global(Vector3(0.0, 1.75, -1.5)), cafe.to_global(Vector3(0.0, 1.3, -9.0)))
		elif node is ApartmentBlock:
			var block := node as ApartmentBlock
			var up := ApartmentBlock.UPPER_Y
			_add("lobby", block.to_global(Vector3(2.5, 1.75, -1.0)), block.to_global(Vector3(ApartmentBlock.SHAFT_X, 1.4, ApartmentBlock.HALL_BACK_Z)))
			_add("elevator_cab", block.to_global(Vector3(ApartmentBlock.SHAFT_X, 1.75, ApartmentBlock.HALL_BACK_Z - 1.6)), block.to_global(Vector3(ApartmentBlock.SHAFT_X, 1.4, 0.0)))
			_add("hallway", block.to_global(Vector3(-6.5, up + 1.75, -9.1)), block.to_global(Vector3(6.0, up + 1.4, -9.1)))
			_add("hallway_doors", block.to_global(Vector3(2.8, up + 1.75, -9.8)), block.to_global(Vector3(4.9, up + 2.0, -8.0)))
			_add("apartment", block.to_global(Vector3(2.2, up + 1.75, -7.0)), block.to_global(Vector3(7.0, up + 1.0, -1.5)))
			_add("apartment_bed_side", block.to_global(Vector3(7.5, up + 1.75, -6.5)), block.to_global(Vector3(2.5, up + 0.8, -2.0)))
			_add("apartment_window_skyline", block.to_global(Vector3(6.5, up + 1.75, -1.2)), block.to_global(Vector3(12.0, up + 2.0, 12.0)))
		elif node is GangTurf:
			var turf := node as Node3D
			_add("jackal_turf", turf.global_position + Vector3(16.0, 1.7, 2.5), turf.global_position + Vector3(-6.0, 1.0, -1.0))
	_add("skyline_up", Vector3(0, 1.7, 0), Vector3(-40, 70, -160))
