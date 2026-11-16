class_name GangMember
extends Person
## A Rust Jackal: a street-gang member who hangs around the gang's turf (GangTurf).
## Calm, they stroll between spots on the turf. They see in a cone (range plus line of sight) and
## hear the player's gunshots. A player who hangs around on the turf is warned first; ignoring the
## warning, shooting near them or hurting one makes the whole crew hostile.
## Hostile, they run for cover (anything in the "cover" group: cars, vending machines, crates),
## pop up to fire short, inaccurate bursts and duck between them; they chase to where they last
## saw the player, search for a while and calm down when nothing turns up. Badly hurt, some run.
## Bullets go through Hitscan like the player's; movement uses the enemy navmesh (EnemyNav).

enum State { PATROL, WARN, INVESTIGATE, COVER, ATTACK, CHASE, SEARCH, FLEE }

const SHOT_SOUND := preload("res://assets/audio/pistol_shot.wav")
## World, player, people and props.
const SHOOT_MASK := 1 | 2 | 4 | 8
## What blocks their view: world and props.
const SIGHT_MASK := 1 | 8
const EYE_HEIGHT := 1.6
const CROUCH_DROP := 0.55

@export var walk_speed := 1.5
@export var run_speed := 4.3
@export var sight_range := 30.0
## Half-angle of the view cone in degrees (they notice anyone within 4 m regardless).
@export var sight_angle := 65.0
@export var damage := 4.0
## Bullet spread in degrees. Wide on purpose: street punks with cheap pistols, a forgiving game.
@export var spread := 6.5
@export var burst_size := 3
## Seconds between bursts (ducked when in cover).
@export var burst_pause := Vector2(2.0, 3.2)
## Seconds of seeing the player before the first shot of a burst.
@export var reaction_time := 1.0
## Below this share of health, some of them run.
@export var flee_health := 0.35

var state := State.PATROL
var hostile := false
var turf: GangTurf

var _agent: NavigationAgent3D
var _player: Player
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _phase := 0.0
var _state_time := 0.0
var _think := 0.0
var _moving := false
var _speed := 0.0
## Point to face instead of the walking direction (Vector3.INF = none).
var _face := Vector3.INF
var _sees_player := false
var _seen_for := 0.0
var _last_seen := Vector3.ZERO
var _since_seen := 999.0
var _cover := Vector3.INF
var _in_cover := false
var _pause := 0.0
var _burst_left := 0
var _shot_timer := 0.0
var _aim := 0.0
var _crouch := 0.0
var _crouch_target := 0.0
var _will_flee := false
var _shot_audio: AudioStreamPlayer3D
var _flash: OmniLight3D
var _flash_time := 0.0
var _tracer: MeshInstance3D
var _tracer_time := 0.0


func _ready() -> void:
	super()
	add_to_group("enemies")
	_will_flee = randf() < 0.5
	_agent = $NavigationAgent3D
	_agent.navigation_layers = EnemyNav.LAYER
	_agent.velocity_computed.connect(_on_velocity_computed)
	_shot_audio = AudioStreamPlayer3D.new()
	_shot_audio.stream = SHOT_SOUND
	_shot_audio.bus = &"SFX"
	_shot_audio.unit_size = 9.0
	_shot_audio.max_distance = 140.0
	_shot_audio.volume_db = -3.0
	_shot_audio.position = Vector3(0, 1.4, -0.6)
	add_child(_shot_audio)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.65, 0.3)
	_flash.light_energy = 3.0
	_flash.omni_range = 5.0
	_flash.visible = false
	add_child(_flash)
	var geo := GeoBatch.new()
	geo.add_box_at(Vector3.ONE, Vector3.ZERO, MatLib.neon(Color(1.0, 0.35, 0.2), 4.0))
	_tracer = geo.build("Tracer", false)
	_tracer.top_level = true
	_tracer.visible = false
	add_child(_tracer)
	_set_state(State.PATROL)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_state_time += delta
	_since_seen += delta
	_think -= delta
	if _think <= 0.0:
		_think = 0.15
		_perceive()
	_seen_for = _seen_for + delta if _sees_player else 0.0
	_update_state(delta)
	_steer()
	_update_effects(delta)


# --- Perception --------------------------------------------------------------------------------

func _perceive() -> void:
	_sees_player = false
	if _player == null or _player.is_dead:
		return
	var eye := global_position + Vector3.UP * (EYE_HEIGHT - _crouch * CROUCH_DROP)
	var target := _player.camera.global_position
	var to := target - eye
	var distance := to.length()
	if distance > sight_range * (1.3 if hostile else 1.0):
		return
	var flat := Vector3(to.x, 0.0, to.z).normalized()
	var cone := 110.0 if hostile else sight_angle
	if distance > 4.0 and rad_to_deg((-global_basis.z).angle_to(flat)) > cone:
		return
	var query := PhysicsRayQueryParameters3D.create(eye, target, SIGHT_MASK)
	query.exclude = [get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	_sees_player = true
	_last_seen = _player.global_position
	_since_seen = 0.0


## The player fired or was seen fighting: the crew joins in. `at` is where the trouble is.
func become_hostile(at: Vector3) -> void:
	if is_dead:
		return
	_last_seen = at
	_since_seen = minf(_since_seen, 1.0)
	if hostile and state in [State.COVER, State.ATTACK, State.CHASE, State.FLEE]:
		return
	hostile = true
	_engage()


## Back to calm (the player respawned or the night is over).
func calm_down() -> void:
	hostile = false
	_burst_left = 0
	_crouch_target = 0.0
	_set_state(State.PATROL)


func on_player_respawned() -> void:
	calm_down()


func _engage() -> void:
	_cover = _find_cover(_last_seen)
	if _cover != Vector3.INF:
		_set_state(State.COVER)
	elif _sees_player:
		_set_state(State.ATTACK)
	else:
		_set_state(State.CHASE)


# --- States ------------------------------------------------------------------------------------

func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0
	_face = Vector3.INF
	match next:
		State.PATROL:
			_in_cover = false
			_crouch_target = 0.0
			_pause = randf_range(1.0, 4.0)
			_stop()
		State.WARN, State.SEARCH:
			_stop()
		State.INVESTIGATE:
			_move_to(_last_seen, walk_speed * 1.8)
		State.COVER:
			_in_cover = false
			_crouch_target = 0.0
			_move_to(_cover, run_speed)
		State.ATTACK:
			_stop()
			_pause = 0.0
			_burst_left = 0
		State.CHASE:
			_in_cover = false
			_crouch_target = 0.0
			_move_to(_last_seen, run_speed)
		State.FLEE:
			_in_cover = false
			_crouch_target = 0.0
			_move_to(_flee_point(), run_speed * 1.1)


func _update_state(delta: float) -> void:
	match state:
		State.PATROL:
			if _sees_player and turf and turf.contains(_player.global_position):
				_set_state(State.WARN)
			elif not _moving:
				_pause -= delta
				if _pause <= 0.0 and turf:
					_move_to(turf.patrol_point(), walk_speed)
					_pause = randf_range(2.0, 6.0)
		State.WARN:
			if _player == null:
				_set_state(State.PATROL)
				return
			_face = _player.global_position
			_aim = move_toward(_aim, 0.5, delta * 2.0)
			if _state_time < 0.2 and turf:
				turf.say_warning()
			# Even up close they warn first; standing in their face just shortens the fuse.
			var close := _player.global_position.distance_to(global_position) < 4.0 and _state_time > 2.0
			if close or (turf and _state_time > turf.warn_time and turf.contains(_player.global_position)):
				turf.go_hostile(_player.global_position)
			elif _since_seen > 3.0 or (turf and not turf.contains(_player.global_position)):
				_set_state(State.PATROL)
		State.INVESTIGATE:
			if _sees_player and turf and turf.contains(_player.global_position):
				_set_state(State.WARN)
			elif not _moving or _state_time > 15.0:
				_set_state(State.SEARCH)
		State.COVER:
			_face = _last_seen if _sees_player else Vector3.INF
			if not _moving or _state_time > 6.0:
				_in_cover = global_position.distance_to(_cover) < 1.5
				_set_state(State.ATTACK)
		State.ATTACK:
			_attack(delta)
		State.CHASE:
			if _sees_player and _seen_for > 0.3:
				_engage()
			elif _state_time > 1.0 and fmod(_state_time, 1.0) < delta:
				_move_to(_last_seen, run_speed)
			if not _moving and not _sees_player:
				_set_state(State.SEARCH)
		State.SEARCH:
			rotation.y += delta * 1.2
			if _sees_player:
				_engage()
			elif _state_time > 6.0:
				_set_state(State.PATROL)
		State.FLEE:
			if not _moving:
				_move_to(_flee_point(), run_speed * 1.1)
			if _state_time > 10.0 and _player and _player.global_position.distance_to(global_position) > 30.0:
				queue_free()
	# Hostility fades if the player is long gone.
	if hostile and _since_seen > 35.0 and state in [State.PATROL, State.SEARCH]:
		hostile = false
	if hostile and state != State.FLEE and _will_flee and health.health_ratio() < flee_health:
		_set_state(State.FLEE)


## In position: pop up, fire a burst, duck (in cover) or pause, repeat. Lose sight too long: chase.
func _attack(delta: float) -> void:
	_face = _last_seen
	_shot_timer -= delta
	if _pause > 0.0:
		_pause -= delta
		_crouch_target = 1.0 if _in_cover else 0.0
		_aim = move_toward(_aim, 0.3, delta * 3.0)
		return
	_crouch_target = 0.0
	_aim = move_toward(_aim, 1.0, delta * 4.0)
	if _sees_player:
		# Back in sight soon after the last burst: quicker on the trigger.
		var reaction := reaction_time * (0.5 if _state_time > 2.0 else 1.0)
		if _burst_left <= 0 and _seen_for >= reaction:
			_burst_left = burst_size
		if _burst_left > 0 and _shot_timer <= 0.0 and _aim > 0.8:
			_fire()
			_burst_left -= 1
			_shot_timer = 0.18
			if _burst_left == 0:
				_pause = randf_range(burst_pause.x, burst_pause.y)
	elif _since_seen > 2.5:
		_set_state(State.CHASE)
	# Out in the open for a while: look for something to hide behind.
	if not _in_cover and _state_time > 7.0 and _pause > 0.0:
		_cover = _find_cover(_last_seen)
		if _cover != Vector3.INF:
			_set_state(State.COVER)


func _fire() -> void:
	if _player == null:
		return
	var origin := _muzzle()
	var chest := _player.global_position + Vector3.UP * 1.15
	var direction := (chest - origin).normalized()
	var cone := spread
	if Vector2(_player.velocity.x, _player.velocity.z).length() > 5.0:
		cone *= 1.4
	cone *= lerpf(1.3, 0.85, clampf(_seen_for / 4.0, 0.0, 1.0))
	direction = Hitscan.spread_direction(direction, deg_to_rad(cone))
	var exclude: Array[RID] = [get_rid()]
	if turf:
		exclude.append_array(turf.member_rids())
	var shot := Hitscan.shoot(self, origin, direction, 140.0, damage, self, SHOOT_MASK, exclude)
	_show_tracer(origin, shot["end"])
	_flash.global_position = origin
	_flash.visible = true
	_flash_time = 0.05
	_shot_audio.pitch_scale = randf_range(0.92, 1.08)
	_shot_audio.play()
	EventBus.emit_danger(origin, 32.0, EventBus.SEVERITY_SHOT, self)


# --- Hearing and getting hurt --------------------------------------------------------------------

func _on_danger_noticed(origin: Vector3, severity: float, _was_calm: bool, source: Node) -> void:
	# Gang members don't panic.
	panic_time = 0.0
	if source is Player:
		var close := origin.distance_to(global_position) < 18.0 or (turf and turf.contains(origin))
		if severity >= EventBus.SEVERITY_DEATH or close:
			if turf:
				turf.go_hostile((source as Node3D).global_position)
			else:
				become_hostile((source as Node3D).global_position)
		elif not hostile and state in [State.PATROL, State.WARN]:
			_last_seen = (source as Node3D).global_position
			_set_state(State.INVESTIGATE)
	elif source is GangMember and (source as GangMember).hostile and not hostile:
		become_hostile((source as GangMember)._last_seen)


func _on_hurt(hit: HitInfo) -> void:
	super(hit)
	if hit.source is Player:
		_last_seen = (hit.source as Node3D).global_position
		_since_seen = 0.0


func _on_calmed() -> void:
	pass


func _on_died(hit: HitInfo) -> void:
	super(hit)
	_agent.velocity = Vector3.ZERO
	_agent.avoidance_enabled = false
	_tracer.visible = false
	_flash.visible = false
	_drop_loot()
	if turf:
		turf.member_died(self, hit)


## Credits, often pistol rounds, sometimes a med patch, rarely their pistol.
func _drop_loot() -> void:
	var parent := get_parent()
	var spot := global_position + global_basis.z * 0.6
	Pickup.spawn(parent, spot, &"", randi_range(15, 55))
	if randf() < 0.6:
		Pickup.spawn(parent, spot + global_basis.x * 0.5, &"ammo_9mm", 12)
	if randf() < 0.25:
		Pickup.spawn(parent, spot - global_basis.x * 0.5, &"med_patch", 1)
	if randf() < 0.15 and GameState.inventory.count(&"weapon_pistol") == 0:
		Pickup.spawn(parent, spot + global_basis.z * 0.5, &"weapon_pistol", 1)


# --- Movement ----------------------------------------------------------------------------------

func _move_to(target: Vector3, speed: float) -> void:
	_agent.target_position = target
	_agent.max_speed = speed * 1.2
	_speed = speed
	_moving = true


func _stop() -> void:
	_moving = false
	_agent.velocity = Vector3.ZERO


func _steer() -> void:
	if _moving and _agent.is_navigation_finished():
		_moving = false
	if not _moving:
		_agent.velocity = Vector3.ZERO
		return
	var to_next := _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	_agent.velocity = to_next.normalized() * _speed if to_next.length() > 0.05 else Vector3.ZERO


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if is_dead:
		return
	var delta := get_physics_process_delta_time()
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	if _face != Vector3.INF:
		var to := _face - global_position
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))
	elif speed > 0.15:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 1.0 - exp(-8.0 * delta))
	_phase += delta * minf(speed, 4.0) * 4.4
	if speed > 0.5:
		_aim = move_toward(_aim, 0.0, delta * 3.0)
	_crouch = move_toward(_crouch, _crouch_target, delta * 4.0)
	# Person lowers the head hit zone with this.
	cower_amount = _crouch * 0.9
	var run := clampf((speed - walk_speed) / (run_speed - walk_speed), 0.0, 1.0)
	model.pose(_phase, clampf(speed / walk_speed, 0.0, 1.0), run, 0.0, 0.0, _aim, _crouch)


## A spot behind the nearest piece of cover (seen from `threat`) that really blocks the view.
## Returns Vector3.INF if there is none within reach.
func _find_cover(threat: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	var threat_eye := threat + Vector3.UP * 1.6
	var taken: Array = turf.cover_spots(self) if turf else []
	var best := Vector3.INF
	var best_score := INF
	for node in get_tree().get_nodes_in_group("cover"):
		var cover := node as Node3D
		var distance := cover.global_position.distance_to(global_position)
		if distance > 16.0 or cover.global_position.distance_to(threat) < 5.0:
			continue
		var away := cover.global_position - threat
		away.y = 0.0
		var outline: PackedVector3Array = cover.cover_outline()
		var reach := 0.0
		for corner in outline:
			reach = maxf(reach, Vector2(corner.x - cover.global_position.x, corner.z - cover.global_position.z).length())
		var spot := cover.global_position + away.normalized() * (reach * 0.6 + 0.8)
		spot = NavigationServer3D.map_get_closest_point(map, spot)
		var crowded := false
		for other: Vector3 in taken:
			if other.distance_to(spot) < 1.4:
				crowded = true
		if crowded:
			continue
		var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 0.95, threat_eye, SIGHT_MASK)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue
		var score := spot.distance_to(global_position) + absf(spot.distance_to(threat) - 13.0) * 0.5
		if score < best_score:
			best_score = score
			best = spot
	return best


func _flee_point() -> Vector3:
	var map := get_world_3d().navigation_map
	var from := _player.global_position if _player else global_position
	var best := global_position
	for i in 8:
		var candidate := NavigationServer3D.map_get_random_point(map, EnemyNav.LAYER, true)
		if candidate.distance_to(from) > best.distance_to(from):
			best = candidate
	return best


func cover_spot() -> Vector3:
	return _cover if state in [State.COVER, State.ATTACK] else Vector3.INF


# --- Effects -----------------------------------------------------------------------------------

func _muzzle() -> Vector3:
	return to_global(Vector3(0.24, 1.45 - _crouch * CROUCH_DROP, -0.9))


func _show_tracer(from: Vector3, to: Vector3) -> void:
	var direction := to - from
	var length := direction.length()
	if length < 1.5:
		return
	var segment := minf(length - 0.5, 14.0)
	var mid := from + direction / length * (0.5 + segment * 0.5)
	_tracer.global_transform = Transform3D(Basis.looking_at(direction / length).scaled(Vector3(0.025, 0.025, segment)), mid)
	_tracer.visible = true
	_tracer_time = 0.05


func _update_effects(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		_flash.visible = _flash_time > 0.0
	if _tracer_time > 0.0:
		_tracer_time -= delta
		_tracer.visible = _tracer_time > 0.0
