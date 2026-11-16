class_name NpcCrowd
extends Node3D
## Bakes a navigation mesh over the sidewalks and crosswalks reported by the CityBuilder and
## fills it with wandering pedestrians. When a body despawns, a new pedestrian walks in from
## somewhere out of the player's sight so the street never empties.

@export var city: NodePath
@export var npc_scene: PackedScene
@export var count := 44
@export_range(0.0, 1.0) var loiter_ratio := 0.25
@export var crowd_seed := 99
## Replacements spawn at least this far from the player.
@export var respawn_distance := 35.0

var _rng := RandomNumberGenerator.new()
var _spawned := 0

@onready var region: NavigationRegion3D = $NavigationRegion3D


## After a night's sleep the bodies are gone (replaced by new pedestrians) and nobody is scared.
func clear_for_new_night() -> void:
	for child in get_children():
		var person := child as Npc
		if person == null:
			continue
		if person.is_dead:
			person._despawn()
		elif person.is_panicking():
			person.panic_time = 0.0
			person._on_calmed()


func _ready() -> void:
	add_to_group("night_cleanup")
	var builder := get_node(city) as CityBuilder
	var navmesh := NavigationMesh.new()
	navmesh.agent_radius = 0.5
	navmesh.agent_height = 1.75
	navmesh.agent_max_climb = 0.25
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25
	var source := NavigationMeshSourceGeometryData3D.new()
	source.add_faces(builder.walkable_faces, Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	region.navigation_mesh = navmesh
	# The navigation map only picks up the new region after a sync; wait until it can be queried.
	var map := get_world_3d().navigation_map
	for _attempt in 60:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_random_point(map, 1, false) != Vector3.ZERO:
			break
	_spawn()


func _spawn() -> void:
	_rng.seed = crowd_seed
	for i in count:
		_spawn_one(NavigationServer3D.map_get_random_point(get_world_3d().navigation_map, 1, true))


func _spawn_one(at: Vector3) -> Npc:
	var npc := npc_scene.instantiate() as Npc
	npc.name = "Npc%d" % _spawned
	_spawned += 1
	npc.loiter = _rng.randf() < loiter_ratio
	npc.walk_speed = _rng.randf_range(1.15, 1.7)
	npc.get_node("Model").look_seed = _rng.randi()
	npc.position = at + Vector3.UP * 0.05
	npc.rotation.y = _rng.randf() * TAU
	npc.despawned.connect(_replace_later)
	add_child(npc)
	return npc


func _replace_later() -> void:
	await get_tree().create_timer(_rng.randf_range(4.0, 12.0)).timeout
	var map := get_world_3d().navigation_map
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var at := NavigationServer3D.map_get_random_point(map, 1, true)
	for _attempt in 12:
		if player == null or at.distance_to(player.global_position) > respawn_distance:
			break
		at = NavigationServer3D.map_get_random_point(map, 1, true)
	_spawn_one(at)
