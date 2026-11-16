class_name PoliceDrone
extends CharacterBody3D
## A police drone sent by PoliceDispatch: a quad-rotor with red and blue lights and a searchlight.
## It flies in high, drops into the street canyons and circles the player at a distance, firing
## short bursts of taser rounds (weak, blue tracers) when it has a clear line of sight. Lost the
## player? It flies to where they were last seen and sweeps the searchlight around. Its glowing
## core takes extra damage; badly hurt, it climbs away. Shot down, it tumbles and explodes.
## Stays over the streets (never over the blocks) and inside the play area.

const ZAP_SOUND := preload("res://assets/audio/drone_zap.wav")
const HUM_SOUND := preload("res://assets/audio/drone_hum.wav")
const SHOOT_MASK := 1 | 2 | 4 | 8
const SIGHT_MASK := 1 | 8
## Keep this far from the street centre lines (building fronts are at 9 m).
const STREET_HALF := 6.0
const PLAY_LIMIT := 64.0

@export var max_health := 90.0
@export var damage := 3.0
@export var spread := 4.0
@export var burst_size := 4
@export var burst_pause := Vector2(2.4, 3.6)
@export var reaction_time := 1.0
@export var speed := 9.0
@export var orbit_radius := Vector2(11.0, 16.0)
@export var hover_height := Vector2(6.0, 8.5)

var dispatch: PoliceDispatch
var health: Damageable
var is_dead := false
## Flying off (heat gone or badly hurt); freed once out of sight.
var leaving := false

var _player: Player
var _target := Vector3.ZERO
var _orbit_angle := 0.0
var _orbit_distance := 13.0
var _height := 7.0
var _sees_player := false
var _seen_for := 0.0
var _last_seen := Vector3.ZERO
var _think := 0.0
var _burst_left := 0
var _shot_timer := 0.0
var _pause := 1.0
var _time := 0.0
var _leave_time := 0.0
var _fall_spin := 0.0
var _visual: Node3D
var _rotors: Array[Node3D] = []
var _red: OmniLight3D
var _blue: OmniLight3D
var _searchlight: SpotLight3D
var _core: Area3D
var _hum: AudioStreamPlayer3D
var _zap: AudioStreamPlayer3D
var _tracer: MeshInstance3D
var _tracer_time := 0.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("police_drones")
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.7, 0.55, 1.7)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	health = Damageable.new()
	health.max_health = max_health
	health.explosion_multiplier = 1.5
	add_child(health)
	Damageable.register(self, health, &"body")
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_build_model()
	_orbit_angle = randf() * TAU
	_orbit_distance = randf_range(orbit_radius.x, orbit_radius.y)
	_height = randf_range(hover_height.x, hover_height.y)


func _physics_process(delta: float) -> void:
	_time += delta
	if is_dead:
		_crash(delta)
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_think -= delta
	if _think <= 0.0:
		_think = 0.15
		_perceive()
	_seen_for = _seen_for + delta if _sees_player else 0.0
	if leaving:
		_leave_time += delta
		_fly_towards(global_position + Vector3(0.0, 12.0, 0.0) + (global_position - _last_seen).normalized() * 6.0, delta, 1.2)
		if _leave_time > 6.0:
			queue_free()
	else:
		_hunt(delta)
	_animate(delta)


func leave() -> void:
	leaving = true
	_searchlight.visible = false


# --- Behaviour ---------------------------------------------------------------------------------

func _perceive() -> void:
	_sees_player = false
	if _player == null or _player.is_dead:
		return
	var target := _player.camera.global_position
	if global_position.distance_to(target) > 55.0:
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.DOWN * 0.4, target, SIGHT_MASK)
	query.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	_sees_player = true
	_last_seen = _player.global_position
	if dispatch:
		dispatch.report_sighting(_last_seen)


func _hunt(delta: float) -> void:
	var focus := _last_seen
	if not _sees_player and dispatch and dispatch.since_seen < 30.0:
		focus = dispatch.last_seen
	if focus == Vector3.ZERO and _player:
		focus = _player.global_position
	if _sees_player:
		# Circle the player slowly, keeping a distance.
		_orbit_angle += delta * 0.25
		_target = focus + Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * _orbit_distance
	else:
		# Search: hover over the last known spot.
		_target = focus + Vector3(cos(_time * 0.4), 0.0, sin(_time * 0.4)) * 3.0
	_target = _keep_over_street(_target)
	_target.y = _height
	_fly_towards(_target, delta, 1.0)
	_shoot(delta)
	if health.health_ratio() < 0.3:
		leave()


func _shoot(delta: float) -> void:
	_shot_timer -= delta
	if _pause > 0.0:
		_pause -= delta
		return
	if not _sees_player:
		return
	if _burst_left <= 0 and _seen_for >= reaction_time:
		_burst_left = burst_size
	if _burst_left > 0 and _shot_timer <= 0.0:
		_fire()
		_burst_left -= 1
		_shot_timer = 0.13
		if _burst_left == 0:
			_pause = randf_range(burst_pause.x, burst_pause.y)


func _fire() -> void:
	var origin := global_position + Vector3.DOWN * 0.45
	var chest := _player.global_position + Vector3.UP * 1.1
	var direction := Hitscan.spread_direction((chest - origin).normalized(), deg_to_rad(spread))
	var shot := Hitscan.shoot(self, origin, direction, 80.0, damage, self, SHOOT_MASK, [get_rid()])
	_show_tracer(origin, shot["end"])
	_zap.pitch_scale = randf_range(0.95, 1.08)
	_zap.play()
	EventBus.emit_danger(origin, 25.0, EventBus.SEVERITY_SHOT, self)


## Moves towards `point`, sliding along walls, and tilts into the motion.
func _fly_towards(point: Vector3, delta: float, speed_scale: float) -> void:
	var to := point - global_position
	var wanted := to.limit_length(speed * speed_scale) if to.length() > 0.3 else Vector3.ZERO
	velocity = velocity.lerp(wanted, 1.0 - exp(-2.5 * delta))
	move_and_slide()


## Pulls a point onto the nearest street (out of the blocks) and inside the play area.
func _keep_over_street(point: Vector3) -> Vector3:
	point.x = clampf(point.x, -PLAY_LIMIT, PLAY_LIMIT)
	point.z = clampf(point.z, -PLAY_LIMIT, PLAY_LIMIT)
	if absf(point.x) > STREET_HALF and absf(point.z) > STREET_HALF:
		if absf(point.z) < absf(point.x):
			point.z = clampf(point.z, -STREET_HALF, STREET_HALF)
		else:
			point.x = clampf(point.x, -STREET_HALF, STREET_HALF)
	return point


func _on_damaged(hit: HitInfo) -> void:
	ImpactEffects.spawn_sparks_at(self, hit.position, hit.normal)
	if hit.source is Player and dispatch:
		dispatch.add_heat(PoliceDispatch.DRONE_HIT_HEAT)
		_last_seen = (hit.source as Node3D).global_position
		dispatch.report_sighting(_last_seen)


func _on_died(hit: HitInfo) -> void:
	is_dead = true
	_searchlight.visible = false
	_red.visible = false
	_blue.visible = false
	_hum.stop()
	collision_layer = 0
	_core.set_deferred("collision_layer", 0)
	velocity = hit.direction * 4.0 + Vector3.DOWN * 2.0
	_fall_spin = randf_range(4.0, 8.0) * (1.0 if randf() < 0.5 else -1.0)


## Tumbles down and blows up where it lands.
func _crash(delta: float) -> void:
	velocity.y -= 14.0 * delta
	rotation.y += _fall_spin * delta
	rotation.x += _fall_spin * 0.3 * delta
	var collision := move_and_collide(velocity * delta)
	if collision or global_position.y < 0.4:
		# Nobody's explosion: the player already earned the heat for shooting it down.
		Explosions.explode(self, global_position, 3.5, 30.0, null, [get_rid()])
		_drop_salvage()
		queue_free()


func _drop_salvage() -> void:
	var ground := Vector3(global_position.x, 0.15, global_position.z)
	Pickup.spawn(get_parent(), ground, [&"scrap", &"burnt_chip", &"data_shard"].pick_random(), 1)


# --- Model and effects -------------------------------------------------------------------------

func _build_model() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.scale = Vector3.ONE * 1.35
	add_child(_visual)
	var shell := MatLib.surface(Color(0.12, 0.14, 0.22), 0.35, 0.6, 0.05)
	var white := MatLib.surface(Color(0.8, 0.82, 0.85), 0.4, 0.3, 0.05)
	var dark := MatLib.surface(Color(0.04, 0.04, 0.05), 0.5, 0.5, 0.0)
	var geo := GeoBatch.new()
	geo.add_box_at(Vector3(0.7, 0.28, 0.9), Vector3.ZERO, shell)
	geo.add_box_at(Vector3(0.72, 0.06, 0.92), Vector3(0, 0.05, 0), white)
	geo.add_box_at(Vector3(0.3, 0.2, 0.3), Vector3(0, -0.22, -0.15), dark)
	geo.add_cylinder(0.03, 0.03, 0.3, 6, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.25, -0.38)), dark)
	geo.add_box_at(Vector3(0.12, 0.06, 0.02), Vector3(-0.2, 0.0, -0.46), MatLib.neon(Palette.RED, 5.0))
	geo.add_box_at(Vector3(0.12, 0.06, 0.02), Vector3(0.2, 0.0, -0.46), MatLib.neon(Color(0.15, 0.35, 1.0), 5.0))
	# A light belt and side bars, so the drone reads as a shape against the night sky.
	geo.add_box_at(Vector3(0.72, 0.03, 0.92), Vector3(0, -0.1, 0), MatLib.neon(Palette.COOL_WHITE, 1.6))
	geo.add_box_at(Vector3(0.03, 0.08, 0.6), Vector3(-0.37, 0.0, 0), MatLib.neon(Palette.RED, 4.0))
	geo.add_box_at(Vector3(0.03, 0.08, 0.6), Vector3(0.37, 0.0, 0), MatLib.neon(Color(0.15, 0.35, 1.0), 4.0))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip := Vector3(corner.x * 0.62, 0.05, corner.y * 0.62)
		geo.add_bar(Vector3(corner.x * 0.25, 0.0, corner.y * 0.3), tip, 0.06, dark)
		geo.add_cylinder(0.08, 0.08, 0.12, 8, Transform3D(Basis.IDENTITY, tip), shell)
	geo.build_into(_visual, "Body")
	BuildKit.neon_text(_visual, "POLICE", Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.15, 0.1)), Palette.COOL_WHITE, 0.14, true)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var rotor := Node3D.new()
		rotor.position = Vector3(corner.x * 0.62, 0.14, corner.y * 0.62)
		_visual.add_child(rotor)
		var blades := GeoBatch.new()
		blades.add_box_at(Vector3(0.62, 0.012, 0.06), Vector3.ZERO, MatLib.surface(Color(0.3, 0.32, 0.36), 0.4, 0.5, 0.0))
		blades.add_cylinder(0.31, 0.31, 0.006, 12, Transform3D.IDENTITY, MatLib.glass(Color(0.6, 0.7, 1.0, 0.12)), false)
		blades.build_into(rotor, "Blades", false)
		_rotors.append(rotor)
	# The core: a glowing weak spot under the body.
	var core_geo := GeoBatch.new()
	core_geo.add_sphere(0.1, Transform3D(Basis.IDENTITY, Vector3(0, -0.2, 0.18)), MatLib.neon(Palette.RED, 4.0), 8, 5)
	core_geo.build_into(_visual, "Core", false)
	_core = Area3D.new()
	_core.collision_layer = 16
	_core.collision_mask = 0
	_core.monitoring = false
	var core_shape := SphereShape3D.new()
	core_shape.radius = 0.16
	var core_collider := CollisionShape3D.new()
	core_collider.shape = core_shape
	core_collider.position = Vector3(0, -0.2, 0.18)
	_core.add_child(core_collider)
	add_child(_core)
	Damageable.register(_core, health, &"core", 2.5)
	_red = BuildKit.omni(_visual, Vector3(-0.3, 0.1, 0), Palette.RED, 2.5, 7.0)
	_blue = BuildKit.omni(_visual, Vector3(0.3, 0.1, 0), Color(0.15, 0.35, 1.0), 2.5, 7.0)
	_searchlight = SpotLight3D.new()
	_searchlight.light_color = Color(0.85, 0.92, 1.0)
	_searchlight.light_energy = 6.0
	_searchlight.spot_range = 22.0
	_searchlight.spot_angle = 16.0
	_searchlight.position = Vector3(0, -0.3, -0.35)
	add_child(_searchlight)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = HUM_SOUND
	_hum.bus = &"SFX"
	_hum.unit_size = 6.0
	_hum.max_distance = 70.0
	_hum.volume_db = -8.0
	add_child(_hum)
	_hum.play()
	_zap = AudioStreamPlayer3D.new()
	_zap.stream = ZAP_SOUND
	_zap.bus = &"SFX"
	_zap.unit_size = 8.0
	_zap.max_distance = 100.0
	add_child(_zap)
	var tracer_geo := GeoBatch.new()
	tracer_geo.add_box_at(Vector3.ONE, Vector3.ZERO, MatLib.neon(Color(0.3, 0.6, 1.0), 5.0))
	_tracer = tracer_geo.build("Tracer", false)
	_tracer.top_level = true
	_tracer.visible = false
	add_child(_tracer)


func _animate(delta: float) -> void:
	for i in _rotors.size():
		_rotors[i].rotation.y += delta * (38.0 if i % 2 == 0 else -38.0)
	# Bob, and lean into the direction of travel.
	_visual.position.y = sin(_time * 2.3) * 0.06
	var local := global_basis.inverse() * velocity
	_visual.rotation = Vector3(clampf(-local.z * 0.04, -0.3, 0.3), 0.0, clampf(local.x * 0.04, -0.3, 0.3))
	# Face the player (or where it is going).
	var look := (_player.global_position if _player and _sees_player else _target) - global_position
	look.y = 0.0
	if look.length_squared() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), 1.0 - exp(-3.0 * delta))
	var flash := fmod(_time * 3.0, 1.0) < 0.5
	_red.light_energy = 3.0 if flash else 0.3
	_blue.light_energy = 0.3 if flash else 3.0
	# The searchlight points at the player, or sweeps when it has lost them.
	if _searchlight.visible:
		var aim := (_player.global_position + Vector3.UP if _player and _sees_player else _target + Vector3(sin(_time) * 4.0, -_height, cos(_time * 0.7) * 4.0))
		if aim.distance_to(_searchlight.global_position) > 0.5:
			_searchlight.look_at(aim, Vector3.UP)
	if _tracer_time > 0.0:
		_tracer_time -= delta
		_tracer.visible = _tracer_time > 0.0


func _show_tracer(from: Vector3, to: Vector3) -> void:
	var direction := to - from
	var length := direction.length()
	if length < 1.0:
		return
	var segment := minf(length, 12.0)
	var mid := from + direction / length * segment * 0.5
	_tracer.global_transform = Transform3D(Basis.looking_at(direction / length).scaled(Vector3(0.03, 0.03, segment)), mid)
	_tracer.visible = true
	_tracer_time = 0.06
