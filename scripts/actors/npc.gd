class_name Npc
extends Person
## Pedestrian that wanders the sidewalks: picks a point on the navigation mesh, walks there with
## NavigationAgent3D (local avoidance keeps the crowd from bumping), idles, then picks the next.
## Loiterers stay near where they spawned and pause for longer, like people waiting outside shops.

@export var walk_speed := 1.4
@export var loiter := false

@onready var agent: NavigationAgent3D = $NavigationAgent3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _wait := 0.0
var _phase := 0.0
var _home := Vector3.ZERO


func _ready() -> void:
	super()
	_home = global_position
	agent.max_speed = walk_speed * 1.4
	agent.velocity_computed.connect(_on_velocity_computed)
	_wait = randf_range(0.2, 3.0)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _wait > 0.0:
		_wait -= delta
		agent.velocity = Vector3.ZERO
		if _wait <= 0.0:
			_pick_target()
		return
	if agent.is_navigation_finished():
		_wait = randf_range(4.0, 12.0) if loiter else randf_range(0.5, 3.5)
		agent.velocity = Vector3.ZERO
		return
	var to_next := agent.get_next_path_position() - global_position
	to_next.y = 0.0
	agent.velocity = to_next.normalized() * walk_speed if to_next.length() > 0.05 else Vector3.ZERO


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if is_dead:
		return
	var delta := get_physics_process_delta_time()
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.15:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 1.0 - exp(-8.0 * delta))
	_phase += delta * speed * 4.4
	model.pose(_phase, clampf(speed / walk_speed, 0.0, 1.0))


func _on_died(hit: HitInfo) -> void:
	super(hit)
	agent.velocity = Vector3.ZERO
	agent.avoidance_enabled = false


func _pick_target() -> void:
	var map := agent.get_navigation_map()
	if loiter:
		var offset := Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
		agent.target_position = NavigationServer3D.map_get_closest_point(map, _home + offset)
	else:
		agent.target_position = NavigationServer3D.map_get_random_point(map, agent.navigation_layers, true)
