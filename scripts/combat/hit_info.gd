class_name HitInfo
extends RefCounted
## Everything a damaged object needs to know about one hit.

enum Kind { BULLET, EXPLOSION }

var damage := 0.0
var position := Vector3.ZERO
var normal := Vector3.UP
## Direction the damage travelled in (bullet direction, or away from an explosion).
var direction := Vector3.FORWARD
## The collider that was hit; Damageable.deliver() fills in the zone from it.
var collider: Object
var zone := &"body"
var kind := Kind.BULLET
## Who caused the damage (usually the player). May be null.
var source: Node
## Push strength for physics reactions and knockback.
var force := 0.0


static func create(damage: float, position: Vector3, normal: Vector3, direction: Vector3, source: Node, kind := Kind.BULLET, force := 0.0) -> HitInfo:
	var hit := HitInfo.new()
	hit.damage = damage
	hit.position = position
	hit.normal = normal
	hit.direction = direction.normalized()
	hit.source = source
	hit.kind = kind
	hit.force = force
	return hit
