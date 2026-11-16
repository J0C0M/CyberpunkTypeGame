class_name Player
extends CharacterBody3D
## First-person controller: walk, sprint, jump, mouse look, head bob, weapon recoil, explosion
## shake and knockback, and the interaction ray that finds what the player is looking at.

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

@export_group("Interaction")
@export var reach := 2.6

@export_group("Head bob")
@export var bob_amount := 0.035

@onready var head: Node3D = $Head
@onready var recoil_pivot: Node3D = $Head/RecoilPivot
@onready var camera: Camera3D = $Head/RecoilPivot/Camera3D
@onready var weapon_holder: WeaponHolder = $Head/RecoilPivot/Camera3D/WeaponHolder
@onready var footsteps: Footsteps = $Footsteps

## The gun in hand (null when the player owns no weapon).
var weapon: Firearm:
	get:
		return weapon_holder.current if weapon_holder else null

var is_sprinting := false
## The Interactable under the crosshair within reach, or null. The HUD shows its prompt.
var focused_interactable: Interactable

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _camera_rest := Vector3.ZERO
var _bob_strength := 0.0
## Visual recoil offset (x = pitch, y = yaw) that springs back to zero.
var _recoil := Vector2.ZERO
## Camera shake strength (explosions); decays over time.
var _shake := 0.0
## Push from explosions, added on top of walking and decaying quickly.
var _knockback := Vector3.ZERO


func _ready() -> void:
	add_to_group("player")
	camera.fov = base_fov
	_camera_rest = camera.position


## Mouse look; called by Main for every captured mouse motion event.
func look(relative: Vector2) -> void:
	var sensitivity := Settings.mouse_sensitivity
	rotate_y(-relative.x * sensitivity)
	head.rotation.x = clampf(head.rotation.x - relative.y * sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))


## Mouse wheel: next or previous weapon on the hotbar.
func cycle_weapon(direction: int) -> void:
	weapon_holder.cycle(direction)


## Called by the weapon on every shot. Part of the kick stays (the view climbs), the rest springs back.
func apply_recoil(pitch_degrees: float, yaw_degrees: float) -> void:
	head.rotation.x = clampf(head.rotation.x + deg_to_rad(pitch_degrees) * 0.4, deg_to_rad(-88.0), deg_to_rad(88.0))
	rotate_y(deg_to_rad(yaw_degrees) * 0.3)
	_recoil += Vector2(deg_to_rad(pitch_degrees), deg_to_rad(yaw_degrees))


## Shakes the camera (0 = none, 1 = a car exploding next to you).
func apply_shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


## Shoves the player (explosions). The upward part lifts them off the ground.
func apply_knockback(impulse: Vector3) -> void:
	_knockback += Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump") and GameState.is_free_roaming():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not GameState.is_free_roaming():
		input_dir = Vector2.ZERO
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	is_sprinting = Input.is_action_pressed("sprint") and input_dir.y < -0.1 and is_on_floor()

	# Sodas and energy drinks put a little extra into the sprint.
	var target_speed := sprint_speed * (1.0 + GameState.effect(&"sprint")) if is_sprinting else walk_speed
	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var horizontal := Vector2(velocity.x, velocity.z)
	horizontal = horizontal.lerp(Vector2(direction.x, direction.z) * target_speed, 1.0 - exp(-accel * delta))
	velocity.x = horizontal.x + _knockback.x
	velocity.z = horizontal.y + _knockback.z
	_knockback = _knockback.lerp(Vector3.ZERO, 1.0 - exp(-4.0 * delta))

	var before := global_position
	move_and_slide()
	velocity.x -= _knockback.x
	velocity.z -= _knockback.z
	footsteps.update(self, delta, Vector2(global_position.x - before.x, global_position.z - before.z).length())
	_update_interaction()
	_update_camera_effects(delta)


func save_data() -> Dictionary:
	return {
		"position": SaveGame.vec_to_array(global_position),
		"yaw": rotation.y,
		"pitch": head.rotation.x,
		"weapons": weapon_holder.save_data(),
	}


func load_data(data: Dictionary) -> void:
	global_position = SaveGame.array_to_vec(data.get("position"), global_position)
	rotation = Vector3(0.0, float(data.get("yaw", rotation.y)), 0.0)
	head.rotation.x = float(data.get("pitch", 0.0))
	velocity = Vector3.ZERO
	weapon_holder.load_data(data.get("weapons", {}))


## Looks for an Interactable in front of the camera; walls and props block the ray.
func _update_interaction() -> void:
	focused_interactable = null
	if not GameState.is_free_roaming():
		return
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * reach, 1 | 8 | 32)
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target := hit.get("collider") as Interactable
	if target and target.enabled:
		focused_interactable = target
		if Input.is_action_just_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			target.interact(self)


func _update_camera_effects(delta: float) -> void:
	# A seat (couch) has taken the camera over.
	if camera.top_level:
		return
	# The bob follows the footstep phase (one dip per step), so steps and bob line up.
	var speed := Vector2(velocity.x, velocity.z).length() if is_on_floor() else 0.0
	_bob_strength = lerpf(_bob_strength, clampf(speed / walk_speed, 0.0, 1.5) * bob_amount, 1.0 - exp(-8.0 * delta))
	var phase := footsteps.phase
	camera.position = _camera_rest + Vector3(cos(phase) * _bob_strength * 0.5, absf(sin(phase)) * _bob_strength, 0.0)

	var target_fov := base_fov + (sprint_fov_boost if is_sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-6.0 * delta))

	_recoil = _recoil.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))
	_shake = move_toward(_shake, 0.0, delta * 1.4)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * _shake
	recoil_pivot.rotation = Vector3(_recoil.x + jitter.x * 0.05, _recoil.y + jitter.y * 0.05, jitter.z * 0.03)
	camera.position += jitter * 0.08
