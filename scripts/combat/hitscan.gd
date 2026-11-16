class_name Hitscan
extends RefCounted
## One bullet, the same for every gun (the player's and the enemies'): a ray from `origin`, damage
## through Damageable.deliver, an impact effect where nothing with health was hit and a small
## danger event at the impact. Returns {"end": Vector3, "collider": Object or null,
## "target": Damageable or null}.


static func shoot(from: Node3D, origin: Vector3, direction: Vector3, max_range: float, damage: float, source: Node, mask: int, exclude: Array[RID] = []) -> Dictionary:
	var end := origin + direction * max_range
	var query := PhysicsRayQueryParameters3D.create(origin, end, mask)
	query.collide_with_areas = true
	query.exclude = exclude
	var hit := from.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"end": end, "collider": null, "target": null}
	end = hit["position"]
	var collider: Object = hit["collider"]
	var target := Damageable.deliver(collider, HitInfo.create(damage, end, hit["normal"], direction, source, HitInfo.Kind.BULLET, 3.0))
	var effects := from.get_tree().get_first_node_in_group("impact_effects") as ImpactEffects
	if effects and target == null:
		# Bullet holes only on the static world; anything with health shows its own reaction.
		effects.spawn_impact(end, hit["normal"], collider is StaticBody3D)
	EventBus.emit_danger(end, 9.0, EventBus.SEVERITY_IMPACT, source)
	return {"end": end, "collider": collider, "target": target}


## A direction inside a cone of `spread` radians around `forward` (denser towards the middle).
static func spread_direction(forward: Vector3, spread: float) -> Vector3:
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = forward.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(forward).normalized()
	var angle := spread * sqrt(randf())
	var around := randf() * TAU
	return (forward + (side * cos(around) + up * sin(around)) * tan(angle)).normalized()
