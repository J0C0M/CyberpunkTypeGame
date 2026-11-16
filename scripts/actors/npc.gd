class_name Npc
extends Person
## Pedestrian that wanders the sidewalks: picks a point on the navigation mesh, walks there with
## NavigationAgent3D (local avoidance keeps the crowd from bumping), idles, then picks the next.
## Loiterers stay near where they spawned and pause for longer, like people waiting outside shops.
## When danger is near they either run away from it or kneel and cower until things calm down.

enum Reaction { NONE, FLEE, COWER }

const RUN_SPEED := 4.4

@export var walk_speed := 1.4
@export var loiter := false

@onready var agent: NavigationAgent3D = $NavigationAgent3D

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _wait := 0.0
var _phase := 0.0
var _home := Vector3.ZERO
var _reaction := Reaction.NONE


func _ready() -> void:
	super()
	_home = global_position
	agent.max_speed = walk_speed * 1.4
	agent.velocity_computed.connect(_on_velocity_computed)
	_wait = randf_range(0.2, 3.0)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	cower_amount = move_toward(cower_amount, 1.0 if _reaction == Reaction.COWER else 0.0, delta * 4.0)
	if _reaction == Reaction.COWER:
		agent.velocity = Vector3.ZERO
		var away := global_position - panic_origin
		if away.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(-away.x, -away.z), 1.0 - exp(-5.0 * delta))
		return
	if _reaction == Reaction.FLEE:
		if agent.is_navigation_finished():
			_pick_flee_target()
		_steer(RUN_SPEED)
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
	_steer(walk_speed)


func _steer(speed: float) -> void:
	var to_next := agent.get_next_path_position() - global_position
	to_next.y = 0.0
	agent.velocity = to_next.normalized() * speed if to_next.length() > 0.05 else Vector3.ZERO


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
	_phase += delta * minf(speed, 3.0) * 4.4
	var run := clampf((speed - walk_speed) / (RUN_SPEED - walk_speed), 0.0, 1.0)
	model.pose(_phase, clampf(speed / walk_speed, 0.0, 1.0), run, cower_amount)


func _on_danger_noticed(_origin: Vector3, severity: float, was_calm: bool) -> void:
	if was_calm:
		var cower_chance := 0.5 if loiter else 0.3
		if severity >= EventBus.SEVERITY_EXPLOSION:
			cower_chance *= 0.5
		_reaction = Reaction.COWER if randf() < cower_chance else Reaction.FLEE
		agent.max_speed = RUN_SPEED * 1.2
	if _reaction == Reaction.FLEE:
		_pick_flee_target()


func _on_calmed() -> void:
	_reaction = Reaction.NONE
	agent.max_speed = walk_speed * 1.4
	_wait = randf_range(1.0, 3.0)
	_home = global_position


## Picks a reachable spot far from the danger whose route doesn't lead past it.
func _pick_flee_target() -> void:
	var map := agent.get_navigation_map()
	var here := Vector2(global_position.x - panic_origin.x, global_position.z - panic_origin.z).length()
	var best := global_position
	var best_score := -INF
	for i in 10:
		var candidate := NavigationServer3D.map_get_random_point(map, agent.navigation_layers, true)
		var path := NavigationServer3D.map_get_path(map, global_position, candidate, true, agent.navigation_layers)
		var closest := INF
		for point in path:
			closest = minf(closest, Vector2(point.x - panic_origin.x, point.z - panic_origin.z).length())
		# Routes that run back towards the danger only count if nothing better turns up.
		var score := candidate.distance_to(panic_origin) - (1000.0 if closest < here * 0.8 else 0.0)
		if score > best_score:
			best_score = score
			best = candidate
	agent.target_position = best


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
