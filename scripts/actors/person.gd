class_name Person
extends CharacterBody3D
## Shared base for the people in the city (pedestrians, merchants): health with a body and a
## head hit zone, hit reactions, a stylised collapse when killed, bodies that despawn, and a
## panic timer fed by EventBus danger events (bigger, closer danger = longer panic).
## Subclasses decide how a person moves and panics; check `is_dead` before doing anything.

signal killed(hit: HitInfo)
## The body is gone (sunk away after its time was up, or replaced by a newer body).
signal despawned

const HIT_SOUND := preload("res://assets/audio/body_hit.wav")
const FALL_SOUND := preload("res://assets/audio/body_fall.wav")
## Bodies are capped; when another person dies the oldest body sinks away.
const MAX_BODIES := 10
const BODY_LIFETIME := 60.0
const HEAD_HEIGHT := 1.74
const FALL_TIME := 0.55

static var _bodies: Array[Person] = []

@export var max_health := 100.0
## People who can't die still get hit effects and react, they just never lose health.
@export var killable := true
@export var headshot_multiplier := 3.0

@onready var model: NpcModel = $Model

var health: Damageable
var is_dead := false
## Seconds of panic left; 0 when calm.
var panic_time := 0.0
## Where the most recent danger came from.
var panic_origin := Vector3.ZERO
## 0..1, how far the model is crouched with its arms over its head this frame.
var cower_amount := 0.0

var _head: Area3D
var _head_shape: CollisionShape3D
var _death_time := 0.0
var _fall_axis := Vector3.RIGHT
var _flinch := 0.0
var _sinking := -1.0
var _body_alarm := 0.0


func _ready() -> void:
	health = Damageable.new()
	health.max_health = max_health
	health.invulnerable = not killable
	add_child(health)
	Damageable.register(self, health, &"body")
	_head = Area3D.new()
	_head.name = "HeadHitbox"
	_head.collision_layer = 16
	_head.collision_mask = 0
	_head.monitoring = false
	var sphere := SphereShape3D.new()
	sphere.radius = 0.17
	_head_shape = CollisionShape3D.new()
	_head_shape.shape = sphere
	_head_shape.position = Vector3(0, HEAD_HEIGHT, -0.02)
	_head.add_child(_head_shape)
	add_child(_head)
	Damageable.register(_head, health, &"head", headshot_multiplier)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	EventBus.danger.connect(_on_danger)
	tree_exiting.connect(func() -> void: _bodies.erase(self))


func _process(delta: float) -> void:
	if is_dead:
		_update_body(delta)
		return
	if panic_time > 0.0:
		panic_time -= delta
		if panic_time <= 0.0:
			_on_calmed()
	_flinch = move_toward(_flinch, 0.0, delta * 5.0)
	model.rotation.x = -_flinch * 0.3
	_head_shape.position.y = HEAD_HEIGHT - cower_amount * 0.42


func _on_damaged(hit: HitInfo) -> void:
	if hit.kind == HitInfo.Kind.BULLET and killable:
		ImpactEffects.spawn_blood_at(self, hit.position, -hit.direction)
		SfxPool.play_at(self, HIT_SOUND, hit.position, -6.0, 0.15, 4.0)
	elif hit.kind == HitInfo.Kind.BULLET:
		# People who can't die (the guide) just have a very lucky streak.
		ImpactEffects.spawn_sparks_at(self, hit.position, hit.normal)
	_flinch = 1.0
	_on_hurt(hit)


## Called on every hit while alive (after effects). Being shot is as alarming as a death.
func _on_hurt(hit: HitInfo) -> void:
	var origin := (hit.source as Node3D).global_position if hit.source is Node3D else hit.position
	_alarm(origin, EventBus.SEVERITY_DEATH, 1.0)


func is_panicking() -> bool:
	return panic_time > 0.0


func _on_danger(position: Vector3, radius: float, severity: float, _source: Node) -> void:
	if is_dead:
		return
	var distance := global_position.distance_to(position)
	if distance <= radius:
		_alarm(position, severity, 1.0 - distance / radius)


func _alarm(origin: Vector3, severity: float, closeness: float) -> void:
	var was_calm := panic_time <= 0.0
	panic_time = maxf(panic_time, (3.0 + 6.0 * severity) * (0.7 + 0.6 * closeness))
	panic_origin = origin
	_on_danger_noticed(origin, severity, was_calm)


## A danger event reached this person (they are now panicking). Subclasses pick a reaction.
func _on_danger_noticed(_origin: Vector3, _severity: float, _was_calm: bool) -> void:
	pass


## Panic ran out without new danger.
func _on_calmed() -> void:
	pass


func _on_died(hit: HitInfo) -> void:
	is_dead = true
	velocity = Vector3.ZERO
	collision_layer = 0
	_head.set_deferred("collision_layer", 0)
	var fall := Vector3(hit.direction.x, 0.0, hit.direction.z)
	if fall.length_squared() < 0.01:
		fall = -global_basis.z
	# Topple along the hit: rotating "up" about up x fall tips the head towards `fall`.
	var local_fall := (global_basis.inverse() * fall).normalized()
	_fall_axis = Vector3.UP.cross(local_fall).normalized()
	_death_time = 0.0
	_bodies.append(self)
	if _bodies.size() > MAX_BODIES:
		_bodies[0]._begin_sinking()
		_bodies.remove_at(0)
	EventBus.emit_danger(global_position, 28.0, EventBus.SEVERITY_DEATH, hit.source)
	EventBus.person_killed.emit(self, hit)
	killed.emit(hit)


func _update_body(delta: float) -> void:
	_death_time += delta
	var t := clampf(_death_time / FALL_TIME, 0.0, 1.0)
	# Falls like it has weight (ease in), then bounces once on the ground.
	var angle := t * t * PI * 0.5
	if t >= 1.0:
		var after := _death_time - FALL_TIME
		angle -= sin(minf(after / 0.25, 1.0) * PI) * 0.12 * exp(-after * 3.0)
	model.transform = Transform3D(Basis(_fall_axis, angle), Vector3(0.0, 0.14 * t, 0.0))
	model.pose(0.0, 0.0, 0.0, 0.0, t)
	# A body keeps scaring anyone who walks past it.
	_body_alarm -= delta
	if _body_alarm <= 0.0 and _sinking < 0.0:
		_body_alarm = 2.5
		EventBus.emit_danger(global_position, 7.0, EventBus.SEVERITY_SHOT)
	if t >= 1.0 and _death_time - delta < FALL_TIME:
		SfxPool.play_at(self, FALL_SOUND, global_position, -4.0, 0.1, 5.0)
		ImpactEffects.spawn_stain_at(self, global_position + model.global_basis.y * 0.6 + Vector3.UP * 0.05)
	if _sinking < 0.0 and _death_time > BODY_LIFETIME:
		_bodies.erase(self)
		_begin_sinking()
	if _sinking >= 0.0:
		_sinking += delta
		model.position.y = 0.14 - _sinking * 0.4
		if _sinking > 1.5:
			_despawn()


func _begin_sinking() -> void:
	if _sinking < 0.0:
		_sinking = 0.0


## Removes the body. Subclasses that respawn (merchants) override this.
func _despawn() -> void:
	despawned.emit()
	queue_free()
