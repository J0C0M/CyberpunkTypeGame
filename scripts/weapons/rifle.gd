class_name Rifle
extends Node3D
## Hitscan assault rifle: full-auto fire with spread that blooms while firing, recoil, muzzle
## flash, tracers, impact effects, a magazine plus reserve ammo and a timed reload.
## Input is polled each frame, so it works from inside the game's SubViewport.

signal ammo_changed(in_magazine: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished

@export var rounds_per_minute := 600.0
@export var magazine_size := 30
@export var reserve_ammo := 210
@export var max_reserve_ammo := 300
@export var reload_time := 2.0
@export var max_range := 400.0
## Damage per bullet before hit-zone multipliers (headshots, engine blocks...).
@export var damage := 34.0
## Spread in degrees: the base value plus bloom that builds up while holding the trigger.
@export var base_spread := 0.3
@export var spread_per_shot := 0.22
@export var max_spread := 2.8
@export var recoil_pitch := 1.1
@export var recoil_yaw := 0.5

## World, NPCs, props and hit zones (physics layers 1, 3, 4 and 5).
const HIT_MASK := 1 | 4 | 8 | 16
## How far the bang of a shot alarms people, in metres.
const SHOT_ALARM_RADIUS := 35.0

@onready var model: RifleModel = $Model
@onready var muzzle: Marker3D = $Muzzle
@onready var flash_light: OmniLight3D = $Muzzle/FlashLight
@onready var shot_sound: AudioStreamPlayer = $ShotSound
@onready var reload_sound: AudioStreamPlayer = $ReloadSound
@onready var dry_fire_sound: AudioStreamPlayer = $DryFireSound

var ammo_in_magazine := 0
var is_reloading := false

var _player: Player
var _rest := Transform3D.IDENTITY
var _cooldown := 0.0
var _bloom := 0.0
## Set while the mouse is free, and until the trigger is released after capturing it,
## so the click that captures the mouse doesn't also fire a shot.
var _trigger_locked := true
var _reload_elapsed := 0.0
var _kick := 0.0
var _flash_time := 0.0
var _tracer_time := 0.0
var _sway := Vector2.ZERO
var _last_look := Vector2.ZERO
var _sprint_blend := 0.0
var _bob := 0.0
var _flash: MeshInstance3D
var _tracer: MeshInstance3D


func _ready() -> void:
	ammo_in_magazine = magazine_size
	_rest = transform
	var node := get_parent()
	while node and not node is Player:
		node = node.get_parent()
	_player = node as Player
	_build_flash()
	_build_tracer()
	flash_light.visible = false
	# Deferred so listeners that connect in their own _ready still get the starting values.
	ammo_changed.emit.call_deferred(ammo_in_magazine, reserve_ammo)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_bloom = move_toward(_bloom, 0.0, delta * 3.5)
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not captured:
		_trigger_locked = true
	elif not Input.is_action_pressed("shoot"):
		_trigger_locked = false

	if is_reloading:
		_reload_elapsed += delta
		if _reload_elapsed >= reload_time:
			_finish_reload()
	elif captured and Input.is_action_just_pressed("reload"):
		start_reload()
	elif captured and not _trigger_locked and Input.is_action_pressed("shoot") and _cooldown <= 0.0:
		if ammo_in_magazine > 0:
			_fire()
		elif Input.is_action_just_pressed("shoot"):
			dry_fire_sound.play()
			start_reload()

	_update_effects(delta)
	_animate(delta)


func start_reload() -> void:
	if is_reloading or ammo_in_magazine >= magazine_size or reserve_ammo <= 0:
		return
	is_reloading = true
	_reload_elapsed = 0.0
	reload_sound.play()
	reload_started.emit(reload_time)


## Current spread in degrees (base + bloom); the HUD crosshair opens up with it.
func get_spread() -> float:
	return base_spread + _bloom


## 0..1 while reloading.
func get_reload_progress() -> float:
	return clampf(_reload_elapsed / reload_time, 0.0, 1.0) if is_reloading else 0.0


## Tops the reserve up to the maximum (used by ammo crates).
func refill() -> void:
	reserve_ammo = max_reserve_ammo
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)


func _finish_reload() -> void:
	var taken := mini(magazine_size - ammo_in_magazine, reserve_ammo)
	ammo_in_magazine += taken
	reserve_ammo -= taken
	is_reloading = false
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)
	reload_finished.emit()


func _fire() -> void:
	ammo_in_magazine -= 1
	_cooldown = 60.0 / rounds_per_minute
	var camera := get_viewport().get_camera_3d()
	var origin := camera.global_position
	var direction := _spread_direction(camera.global_basis, deg_to_rad(base_spread + _bloom))
	var end := origin + direction * max_range
	var query := PhysicsRayQueryParameters3D.create(origin, end, HIT_MASK)
	query.collide_with_areas = true
	if _player:
		query.exclude = [_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit["position"]
		var collider: Object = hit["collider"]
		var target := Damageable.deliver(collider, HitInfo.create(damage, end, hit["normal"], direction, _player, HitInfo.Kind.BULLET, 3.0))
		var effects := get_tree().get_first_node_in_group("impact_effects") as ImpactEffects
		if effects and target == null:
			# Bullet holes only on the static world; anything with health shows its own reaction.
			effects.spawn_impact(end, hit["normal"], collider is StaticBody3D)
		EventBus.emit_danger(end, 9.0, EventBus.SEVERITY_IMPACT, _player)
	EventBus.emit_danger(origin, SHOT_ALARM_RADIUS, EventBus.SEVERITY_SHOT, _player)

	_show_tracer(muzzle.global_position, end)
	_flash_time = 0.045
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
	flash_light.visible = true
	_kick = 1.0
	_bloom = minf(_bloom + spread_per_shot, max_spread)
	if _player:
		_player.apply_recoil(recoil_pitch * randf_range(0.8, 1.15), recoil_yaw * randf_range(-1.0, 1.0))
	shot_sound.pitch_scale = randf_range(0.94, 1.06)
	shot_sound.play()
	ammo_changed.emit(ammo_in_magazine, reserve_ammo)


func _spread_direction(basis: Basis, spread: float) -> Vector3:
	var angle := spread * sqrt(randf())
	var around := randf() * TAU
	var offset := (basis.x * cos(around) + basis.y * sin(around)) * tan(angle)
	return (-basis.z + offset).normalized()


func _update_effects(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.visible = false
			flash_light.visible = false
	if _tracer_time > 0.0:
		_tracer_time -= delta
		if _tracer_time <= 0.0:
			_tracer.visible = false


## View-model motion: recoil kick, mouse sway, walk bob, sprint pose and the reload dip.
func _animate(delta: float) -> void:
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-16.0 * delta))
	var reload_pose := sin(clampf(_reload_elapsed / reload_time, 0.0, 1.0) * PI) if is_reloading else 0.0
	var speed := 0.0
	var sprinting := false
	if _player:
		var look := Vector2(_player.rotation.y, _player.head.rotation.x)
		var look_delta := look - _last_look
		_last_look = look
		var target_sway := Vector2(clampf(look_delta.x * 0.6, -0.025, 0.025), clampf(-look_delta.y * 0.6, -0.025, 0.025))
		_sway = _sway.lerp(target_sway, 1.0 - exp(-10.0 * delta))
		if _player.is_on_floor():
			speed = Vector2(_player.velocity.x, _player.velocity.z).length()
		sprinting = _player.is_sprinting and not Input.is_action_pressed("shoot") and not is_reloading
	_sprint_blend = lerpf(_sprint_blend, 1.0 if sprinting else 0.0, 1.0 - exp(-8.0 * delta))
	_bob += delta * speed * 1.7
	var bob_amount := clampf(speed / 4.5, 0.0, 1.6)
	var bob := Vector3(sin(_bob) * 0.008, -absf(cos(_bob)) * 0.01, 0.0) * bob_amount

	var offset := Vector3(_sway.x, _sway.y, _kick * 0.055) + bob
	offset += Vector3(-0.05, -0.05, 0.03) * _sprint_blend + Vector3(0.0, -0.06, 0.02) * reload_pose
	var tilt := Vector3(
		_kick * 0.06 - reload_pose * 0.45 - _sprint_blend * 0.3,
		_sprint_blend * 0.75,
		reload_pose * 0.65 + _sprint_blend * 0.2)
	transform = Transform3D(Basis.from_euler(tilt), _rest.origin + offset)

	var drop := 0.0
	if is_reloading:
		var p := _reload_elapsed / reload_time
		drop = smoothstep(0.08, 0.3, p) * (1.0 - smoothstep(0.5, 0.72, p)) * 0.32
	model.magazine.position = Vector3(0.0, -drop, drop * 0.25)


func _build_flash() -> void:
	var geo := GeoBatch.new()
	var hot := MatLib.neon(Color(1.0, 0.75, 0.35), 9.0)
	for i in 3:
		var basis := Basis(Vector3.FORWARD, i * PI / 3.0)
		geo.add_quad(Vector2(0.03, 0.2), Transform3D(basis, Vector3.ZERO), hot)
	geo.add_quad(Vector2(0.06, 0.06), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.06)), hot)
	geo.add_sphere(0.03, Transform3D(Basis.from_scale(Vector3(1, 1, 2.5)), Vector3(0, 0, -0.05)), MatLib.neon(Color(1.0, 0.9, 0.6), 12.0), 6, 4)
	_flash = geo.build("Flash", false)
	_flash.layers = RifleModel.VIEW_MODEL_LAYER
	_flash.visible = false
	muzzle.add_child(_flash)


func _build_tracer() -> void:
	var geo := GeoBatch.new()
	geo.add_box_at(Vector3(1, 1, 1), Vector3.ZERO, MatLib.neon(Color(1.0, 0.7, 0.3), 4.0))
	_tracer = geo.build("Tracer", false)
	_tracer.top_level = true
	_tracer.visible = false
	add_child(_tracer)


func _show_tracer(from: Vector3, to: Vector3) -> void:
	# Start a little ahead of the muzzle so the tracer doesn't fill the screen.
	var direction := to - from
	var length := direction.length()
	if length < 2.0:
		return
	var start := from + direction / length * 1.0
	var segment := minf(length - 1.0, 18.0)
	var mid := start + direction / length * segment * 0.5
	var basis := Basis.looking_at(direction / length).scaled(Vector3(0.012, 0.012, segment))
	_tracer.global_transform = Transform3D(basis, mid)
	_tracer.visible = true
	_tracer_time = 0.03
