class_name Player
extends CharacterBody3D
## First-person controller: walk, sprint, jump, mouse look, head bob, weapon recoil, explosion
## shake and knockback, and the interaction ray that finds what the player is looking at.
## Also the player's health: hits arrive through the damage system like everyone else's (the body
## collider is registered with a Damageable); health comes back on its own after a few quiet
## seconds, med patches and food heal, and at zero the player flatlines (see Respawn).

signal health_changed(health: float, max_health: float)
signal hurt(hit: HitInfo)
signal died(hit: HitInfo)

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

@export_group("Health")
@export var max_health := 100.0
## Seconds without damage before health starts coming back, and how fast.
@export var regen_delay := 5.0
@export var regen_rate := 12.0
## Explosions hurt the player less than bullets do (the game is meant to be forgiving).
@export var explosion_damage_scale := 0.5

## Share of the player's credits the clinic bills after a flatline, and the most it takes.
@export var death_penalty := 0.1
@export var death_penalty_cap := 150

const HURT_SOUND := preload("res://assets/audio/player_hurt.wav")
## How far behind the camera the body stands.
const BODY_SETBACK := 0.13
const FLATLINE_SOUND := preload("res://assets/audio/flatline.wav")
## Healing items H uses, best first.
const QUICK_HEAL: Array[StringName] = [&"med_patch", &"sushi", &"noodles", &"onigiri"]

@onready var head: Node3D = $Head
@onready var recoil_pivot: Node3D = $Head/RecoilPivot
@onready var camera: Camera3D = $Head/RecoilPivot/Camera3D
@onready var weapon_holder: WeaponHolder = $Head/RecoilPivot/Camera3D/WeaponHolder
@onready var footsteps: Footsteps = $Footsteps

## The gun in hand (null when the player owns no weapon).
var weapon: Firearm:
	get:
		return weapon_holder.current if weapon_holder else null

var health: Damageable
var is_dead := false
## Who the player is (look, outfit); see apply_character().
var character: CharacterData
## The character's body (CharacterModel) and first-person arms (ViewArms).
var body: CharacterModel
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
var _since_hurt := 0.0
var _hurt_audio: AudioStreamPlayer
## Where the player started (Ren's noodle bar): the respawn point without a key card.
var _start := Transform3D.IDENTITY
var _arms: ViewArms
var _body_time := 0.0
var _body_aim := 0.0


func _ready() -> void:
	add_to_group("player")
	camera.fov = base_fov
	_camera_rest = camera.position
	_start = global_transform
	health = Damageable.new()
	health.name = "Health"
	health.max_health = max_health
	health.explosion_multiplier = explosion_damage_scale
	add_child(health)
	Damageable.register(self, health, &"body")
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	weapon_holder.weapon_changed.connect(_show_weapon_on_body)
	_hurt_audio = AudioStreamPlayer.new()
	_hurt_audio.stream = HURT_SOUND
	_hurt_audio.bus = &"SFX"
	_hurt_audio.volume_db = -6.0
	add_child(_hurt_audio)


## Adds health (food, med patches). Returns how much was actually healed.
func heal(amount: float) -> float:
	if is_dead:
		return 0.0
	var before := health.health
	health.health = minf(health.max_health, health.health + amount)
	health_changed.emit(health.health, health.max_health)
	return health.health - before


## Full health and back on their feet (respawning, sleeping, loading).
func restore_health(amount := -1.0) -> void:
	is_dead = false
	health.restore()
	if amount > 0.0:
		health.health = minf(amount, health.max_health)
	_since_hurt = regen_delay
	health_changed.emit(health.health, health.max_health)


func _on_damaged(hit: HitInfo) -> void:
	_since_hurt = 0.0
	_shake = maxf(_shake, 0.25)
	_hurt_audio.pitch_scale = randf_range(0.9, 1.1)
	_hurt_audio.play()
	health_changed.emit(health.health, health.max_health)
	hurt.emit(hit)


func _on_died(hit: HitInfo) -> void:
	is_dead = true
	velocity = Vector3.ZERO
	health_changed.emit(0.0, health.max_health)
	died.emit(hit)
	_flatline()


## Death: the view drops, the screen goes black, the clinic takes its cut and the player wakes up
## at home (with the key card) or back at Ren's. Wanted level and angry gangs are reset.
func _flatline() -> void:
	# Close whatever menu or seat was open; the death screen owns input now.
	get_tree().call_group("dialogue_screen", "close")
	GameState.claim_ui(&"dead", false)
	_hurt_audio.stream = FLATLINE_SOUND
	_hurt_audio.pitch_scale = 1.0
	_hurt_audio.play()
	weapon_holder.visible = false
	var fall := create_tween().set_parallel()
	fall.tween_property(head, "rotation:z", 1.2, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(head, "position:y", 0.35, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var hud := get_tree().get_first_node_in_group("hud")
	await get_tree().create_timer(0.8).timeout
	hud.show_flatline(true)
	await hud.fade_to(1.0, 1.6).finished
	await get_tree().create_timer(1.2).timeout

	var bill := mini(int(GameState.credits * death_penalty), death_penalty_cap)
	GameState.spend_credits(bill)
	GameState.clock_minutes = fposmod(GameState.clock_minutes + 120.0, 1440.0)
	get_tree().call_group("police", "clear_heat")
	get_tree().call_group("enemies", "on_player_respawned")
	var home: Dictionary = GameState.places.get(&"respawn_home", {})
	var at_home := GameState.inventory.count(&"keycard_1107") > 0 and not home.is_empty()
	global_transform = Transform3D(Basis(Vector3.UP, home.get("yaw", 0.0)), home["position"]) if at_home else _start
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	head.rotation = Vector3.ZERO
	head.position.y = body.eye_height() if body else 1.62
	weapon_holder.visible = true
	restore_health()
	hud.show_flatline(false)
	var where := "You come to in your apartment." if at_home else "You come to on a stool at Ren's."
	var cost := " Clinic 24H billed you %d ¢ for the patch-up." % bill if bill > 0 else " The clinic patched you up for free. Lucky."
	hud.show_message(where + cost, 5.0)
	await hud.fade_to(0.0, 1.4).finished
	GameState.release_ui()


## H: uses the best healing item in the inventory.
func _quick_heal() -> void:
	if health.health >= health.max_health:
		get_tree().call_group("hud", "show_message", "Already at full health.", 1.2)
		return
	for id in QUICK_HEAL:
		if GameState.inventory.count(id) > 0:
			var line := GameState.use_item(id)
			get_tree().call_group("hud", "notify_item", line, ItemDB.color(id))
			_hurt_audio.stream = GameState.use_sound(id)
			_hurt_audio.pitch_scale = 1.0
			_hurt_audio.play()
			_hurt_audio.stream = HURT_SOUND
			return
	get_tree().call_group("hud", "show_message", "Nothing to patch yourself up with. The Clinic sells med patches.", 2.0)


## Mouse look; called by Main for every captured mouse motion event.
func look(relative: Vector2) -> void:
	var sensitivity := Settings.mouse_sensitivity
	var vertical := relative.y * (-1.0 if Settings.invert_y else 1.0)
	rotate_y(-relative.x * sensitivity)
	head.rotation.x = clampf(head.rotation.x - vertical * sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))


## Right stick look (controller), scaled like a fast mouse.
func _stick_look(delta: float) -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.15 and GameState.is_free_roaming():
		look(stick * stick.length() * delta * 1400.0)


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
	_stick_look(delta)
	_update_health(delta)
	_animate_body(delta)
	if is_dead:
		_update_camera_effects(delta)
		return
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


## Takes on a character's look: the body (seen when looking down, in mirrors and in shadows),
## the first-person arms, and the camera at the character's eye height.
func apply_character(data: CharacterData) -> void:
	character = data
	if body:
		body.queue_free()
	body = CharacterModel.new()
	body.name = "Body"
	body.data = data
	# A little behind the camera, so looking down shows the chest and legs, not the inside of the head.
	body.position = Vector3(0, 0, BODY_SETBACK)
	add_child(body)
	head.position.y = body.eye_height()
	camera.cull_mask &= ~CharacterRig.FIRST_PERSON_HIDDEN
	if _arms == null:
		_arms = ViewArms.new()
		_arms.name = "ViewArms"
		_arms.holder = weapon_holder
		weapon_holder.add_child(_arms)
	_arms.build(body)
	_show_weapon_on_body(weapon)


## The gun in hand also hangs in the body's right hand (for mirrors, shadows, third person).
func _show_weapon_on_body(gun: Firearm) -> void:
	if body == null:
		return
	var mount := body.slot(&"hand_r")
	for child in mount.get_children():
		child.queue_free()
	if gun:
		var model := ItemModels.build(gun.item_id)
		# Barrel (+X) along the hand (bone -Y), top of the gun up when the arm points forward.
		model.transform = Transform3D(Basis(Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)), Vector3(0, -0.02, 0.0))
		# Like the arm holding it: seen in mirrors and third person, not by the first-person camera.
		model.layers = CharacterRig.FIRST_PERSON_HIDDEN
		mount.add_child(model)


## Walks the body with the footsteps; the right arm holds the gun up.
func _animate_body(delta: float) -> void:
	if body == null:
		return
	_body_time += delta
	var speed := Vector2(velocity.x, velocity.z).length() if is_on_floor() else 0.0
	var walk := clampf(speed / walk_speed, 0.0, 1.2)
	var run := clampf((speed - walk_speed) / (sprint_speed - walk_speed), 0.0, 1.0)
	var aim := 1.0 if weapon and not is_sprinting else 0.0
	_body_aim = move_toward(_body_aim, aim, delta * 4.0)
	body.pose(footsteps.phase, walk, run, _body_aim, 0.0, _body_time)


func save_data() -> Dictionary:
	return {
		"position": SaveGame.vec_to_array(global_position),
		"yaw": rotation.y,
		"pitch": head.rotation.x,
		"weapons": weapon_holder.save_data(),
		"health": health.health,
	}


func load_data(data: Dictionary) -> void:
	global_position = SaveGame.array_to_vec(data.get("position"), global_position)
	rotation = Vector3(0.0, float(data.get("yaw", rotation.y)), 0.0)
	head.rotation.x = float(data.get("pitch", 0.0))
	velocity = Vector3.ZERO
	restore_health(float(data.get("health", max_health)))
	weapon_holder.load_data(data.get("weapons", {}))


func _update_health(delta: float) -> void:
	if is_dead:
		return
	if Input.is_action_just_pressed("quick_heal") and GameState.is_free_roaming():
		_quick_heal()
	_since_hurt += delta
	var regen := regen_rate if _since_hurt >= regen_delay else 0.0
	regen += GameState.effect(&"regen")
	if regen > 0.0 and health.health < health.max_health:
		heal(regen * delta)


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
	var bob := bob_amount if Settings.head_bob else 0.0
	_bob_strength = lerpf(_bob_strength, clampf(speed / walk_speed, 0.0, 1.5) * bob, 1.0 - exp(-8.0 * delta))
	var phase := footsteps.phase
	camera.position = _camera_rest + Vector3(cos(phase) * _bob_strength * 0.5, absf(sin(phase)) * _bob_strength, 0.0)

	var target_fov := Settings.fov + (sprint_fov_boost if is_sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-6.0 * delta))

	_recoil = _recoil.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))
	_shake = move_toward(_shake, 0.0, delta * 1.4)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * _shake
	recoil_pivot.rotation = Vector3(_recoil.x + jitter.x * 0.05, _recoil.y + jitter.y * 0.05, jitter.z * 0.03)
	camera.position += jitter * 0.08
