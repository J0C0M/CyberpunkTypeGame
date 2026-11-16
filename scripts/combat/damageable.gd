class_name Damageable
extends Node
## Health component. Add it to anything that can be hurt and register that thing's colliders
## with Damageable.register(); weapons and explosions reach it through Damageable.deliver().
## Each collider can carry a hit zone ("head", "engine"...) with its own damage multiplier.

signal damaged(hit: HitInfo)
signal died(hit: HitInfo)

## Setting this also fills health up, so it is ready before the node even enters the tree.
@export var max_health := 100.0:
	set(value):
		max_health = value
		health = value
## Still reports hits (so the owner can react) but never loses health.
@export var invulnerable := false
## Scales explosion damage (the player takes less, armoured drones more...).
@export var explosion_multiplier := 1.0

var health := 100.0
var is_dead := false


func apply_damage(hit: HitInfo) -> void:
	if is_dead:
		return
	if hit.kind == HitInfo.Kind.EXPLOSION:
		hit.damage *= explosion_multiplier
	if not invulnerable:
		health = maxf(0.0, health - hit.damage)
	damaged.emit(hit)
	if health <= 0.0 and not invulnerable:
		is_dead = true
		died.emit(hit)


func health_ratio() -> float:
	return health / max_health if max_health > 0.0 else 0.0


## Back to full health (e.g. when something respawns).
func restore() -> void:
	health = max_health
	is_dead = false


## Marks `collider` as part of `target`. Hits on it are scaled by `multiplier` and tagged `zone`.
static func register(collider: Object, target: Damageable, zone := &"body", multiplier := 1.0) -> void:
	collider.set_meta(&"damageable", target)
	collider.set_meta(&"hit_zone", zone)
	collider.set_meta(&"damage_multiplier", multiplier)


static func find(collider: Object) -> Damageable:
	if collider == null or not is_instance_valid(collider) or not collider.has_meta(&"damageable"):
		return null
	var target: Object = collider.get_meta(&"damageable")
	return target as Damageable if is_instance_valid(target) else null


## Sends `hit` to whatever owns `collider`. Returns the Damageable that took it, or null.
static func deliver(collider: Object, hit: HitInfo) -> Damageable:
	var target := find(collider)
	if target == null:
		return null
	hit.collider = collider
	hit.zone = collider.get_meta(&"hit_zone", &"body")
	hit.damage *= float(collider.get_meta(&"damage_multiplier", 1.0))
	target.apply_damage(hit)
	return target
