class_name ItemScatter
extends Node3D
## Items left lying around the city: on bus stop benches, by the corners, in the Neo-Heights
## lobby. Each spot gets its item back every night; the ones picked up tonight are remembered in
## the save. Spots are XZ positions; the item lands on whatever is below (floor, bench, crate).

## [spot id, position (y = where the downward ray starts), item id, count]
const SPOTS := [
	[&"bus_west_bench", Vector3(-47.4, 2.2, 7.9), &"onigiri", 1],
	[&"bus_south_bench", Vector3(7.9, 2.2, 46.6), &"synth_soda", 1],
	[&"holo_column", Vector3(-6.9, 2.2, -7.3), &"scrap", 2],
	[&"main_east_curb", Vector3(31.0, 2.2, 6.9), &"burnt_chip", 1],
	[&"cross_south", Vector3(-6.9, 2.2, 31.0), &"med_patch", 1],
	[&"cross_north", Vector3(6.9, 2.2, -41.0), &"volt_can", 1],
	[&"west_barricade", Vector3(-62.0, 2.2, -7.0), &"lucky_cat", 1],
	[&"east_barricade", Vector3(61.0, 2.2, 7.2), &"ammo_ks47", 30],
	[&"lobby_mailboxes", Vector3(-15.0, 2.2, -12.0), &"vinyl", 1],
	[&"gun_shop_door", Vector3(-25.0, 2.2, 7.4), &"data_shard", 1],
]

## Spot ids picked up since the last sleep.
var _taken := {}
var _pickups := {}
var _ready_to_spawn := false


func _ready() -> void:
	add_to_group("saveable")
	GameState.night_passed.connect(_on_night_passed)
	# The city's colliders exist after the first physics frame; items are dropped onto them.
	await get_tree().physics_frame
	_ready_to_spawn = true
	_spawn_all()


func _on_night_passed() -> void:
	# Last night's pickups were just cleared away with the other loot.
	_taken.clear()
	_pickups.clear()
	_spawn_all()


func _spawn_all() -> void:
	if not _ready_to_spawn:
		return
	for spot in SPOTS:
		var id: StringName = spot[0]
		if _taken.has(id) or is_instance_valid(_pickups.get(id)):
			continue
		var pickup := Pickup.spawn(self, _ground_below(spot[1]), spot[2], spot[3], 0.0)
		pickup.taken.connect(_on_taken.bind(id))
		_pickups[id] = pickup


func _on_taken(id: StringName) -> void:
	_taken[id] = true
	_pickups.erase(id)


func _ground_below(from: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, 1 | 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3(from.x, 0.15, from.z)


func save_key() -> String:
	return "item_scatter"


func save_data() -> Dictionary:
	var ids: Array[String] = []
	for id in _taken:
		ids.append(String(id))
	return {"taken": ids}


func load_data(data: Dictionary) -> void:
	_taken.clear()
	for id in data.get("taken", []):
		_taken[StringName(id)] = true
		var pickup: Pickup = _pickups.get(StringName(id))
		if is_instance_valid(pickup):
			pickup.queue_free()
		_pickups.erase(StringName(id))
