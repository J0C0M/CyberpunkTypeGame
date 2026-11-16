class_name EnemyNav
extends NavigationRegion3D
## Navigation mesh for enemies: everything walkable in the playable area, roads included, baked
## from the city's colliders so cars, props, lamp posts and walls are holes in it. It sits on
## navigation layer 2 (`LAYER`); pedestrians keep to their own sidewalk mesh on layer 1.
## Baked once on start (in the background); `baked` fires when agents can use it.

signal baked

const LAYER := 2

## Everything under this node is parsed for colliders (the World: city, gang hangout, props).
@export var geometry_root: NodePath
## Half the size of the baked square around the crossing, in metres.
@export var extent := 70.0

var is_baked := false


func _ready() -> void:
	navigation_layers = LAYER
	# The city's colliders exist after the first physics frame.
	await get_tree().physics_frame
	var navmesh := NavigationMesh.new()
	navmesh.agent_radius = 0.5
	navmesh.agent_height = 1.75
	navmesh.agent_max_climb = 0.25
	navmesh.cell_size = 0.25
	navmesh.cell_height = 0.25
	navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navmesh.geometry_collision_mask = 1 | 8
	# Street level only: building tops and the upper floors stay out.
	navmesh.filter_baking_aabb = AABB(Vector3(-extent, -1.0, -extent), Vector3(extent * 2.0, 5.0, extent * 2.0))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navmesh, source, get_node(geometry_root))
	NavigationServer3D.bake_from_source_geometry_data_async(navmesh, source, _on_baked.bind(navmesh))


func _on_baked(navmesh: NavigationMesh) -> void:
	navigation_mesh = navmesh
	# The map picks the new mesh up on its next sync.
	for _attempt in 60:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_random_point(get_world_3d().navigation_map, LAYER, false) != Vector3.ZERO:
			break
	is_baked = true
	baked.emit()
