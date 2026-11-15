class_name Player
extends CharacterBody3D
## First-person controller: walk, sprint, jump, mouse look, head bob and weapon recoil.

@export_group("Movement")
@export var walk_speed := 4.5
@export var sprint_speed := 7.5
@export var jump_velocity := 4.6
@export var ground_acceleration := 14.0
@export var air_acceleration := 3.0

@export_group("Look")
@export var mouse_sensitivity := 0.0022
@export var base_fov := 75.0
@export var sprint_fov_boost := 7.0

@export_group("Head bob")
@export var bob_frequency := 1.9
@export var bob_amount := 0.035

@onready var head: Node3D = $Head
@onready var recoil_pivot: Node3D = $Head/RecoilPivot
@onready var camera: Camera3D = $Head/RecoilPivot/Camera3D
@onready var weapon: Rifle = $Head/RecoilPivot/Camera3D/WeaponHolder/Rifle
@onready var footsteps: AudioStreamPlayer = $Footsteps

var is_sprinting := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bob_phase := 0.0
var _last_step := 0
var _camera_rest := Vector3.ZERO
## Visual recoil offset (x = pitch, y = yaw) that springs back to zero.
var _recoil := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	camera.fov = base_fov
	_camera_rest = camera.position


## Mouse look; called by Main for every captured mouse motion event.
func look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x - relative.y * mouse_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))


## Called by the weapon on every shot. Part of the kick stays (the view climbs), the rest springs back.
func apply_recoil(pitch_degrees: float, yaw_degrees: float) -> void:
	head.rotation.x = clampf(head.rotation.x + deg_to_rad(pitch_degrees) * 0.4, deg_to_rad(-88.0), deg_to_rad(88.0))
	rotate_y(deg_to_rad(yaw_degrees) * 0.3)
	_recoil += Vector2(deg_to_rad(pitch_degrees), deg_to_rad(yaw_degrees))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	is_sprinting = Input.is_action_pressed("sprint") and input_dir.y < -0.1 and is_on_floor()

	var target_speed := sprint_speed if is_sprinting else walk_speed
	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector2(velocity.x, velocity.z)
	horizontal = horizontal.lerp(Vector2(direction.x, direction.z) * target_speed, 1.0 - exp(-accel * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.y

	move_and_slide()
	_update_camera_effects(delta)


func _update_camera_effects(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and speed > 0.5:
		_bob_phase += delta * bob_frequency * TAU * (speed / walk_speed) * 0.5
	else:
		_bob_phase = lerpf(_bob_phase, roundf(_bob_phase / PI) * PI, 1.0 - exp(-8.0 * delta))
	# A footstep each time the bob passes the bottom of its cycle.
	var step := floori(_bob_phase / PI)
	if step != _last_step and is_on_floor() and speed > 0.5:
		footsteps.pitch_scale = randf_range(0.85, 1.15)
		footsteps.play()
	_last_step = step
	var bob_strength := clampf(speed / walk_speed, 0.0, 1.5) * bob_amount
	camera.position = _camera_rest + Vector3(cos(_bob_phase) * bob_strength * 0.5, absf(sin(_bob_phase)) * bob_strength, 0.0)

	var target_fov := base_fov + (sprint_fov_boost if is_sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-6.0 * delta))

	_recoil = _recoil.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))
	recoil_pivot.rotation = Vector3(_recoil.x, _recoil.y, 0.0)
