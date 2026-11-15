class_name NpcCrowd
extends Node3D
## Bakes a navigation mesh over the sidewalks and crosswalks reported by the CityBuilder and
## fills it with wandering pedestrians.

@export var city: NodePath
@export var npc_scene: PackedScene
@export var count := 44
@export_range(0.0, 1.0) var loiter_ratio := 0.25
@export var crowd_seed := 99

@onready var region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
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
	var rng := RandomNumberGenerator.new()
	rng.seed = crowd_seed
	var map := get_world_3d().navigation_map
	for i in count:
		var npc := npc_scene.instantiate() as Npc
		npc.name = "Npc%d" % i
		npc.loiter = rng.randf() < loiter_ratio
		npc.walk_speed = rng.randf_range(1.15, 1.7)
		npc.get_node("Model").look_seed = rng.randi()
		npc.position = NavigationServer3D.map_get_random_point(map, 1, true) + Vector3.UP * 0.05
		npc.rotation.y = rng.randf() * TAU
		add_child(npc)
