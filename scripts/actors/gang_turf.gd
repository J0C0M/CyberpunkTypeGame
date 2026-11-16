class_name GangTurf
extends Node3D
## The Rust Jackals' corner at the west end of the main street, by the barricade: a burning barrel,
## crates to hide behind, their tag in neon, and a crew of GangMembers strolling around it.
## The turf decides when the crew turns on the player (go_hostile), throttles their shouting and
## puts a fresh crew out every night. Members wait for the enemy navmesh before they spawn.

const WARNINGS := ["Wrong street, choom. Walk away.", "Jackal turf. You lost?", "Keep walking, tourist.", "This block's taken. Move it."]
const THREATS := ["Light 'em up!", "You asked for it!", "Jackals, on me!", "Bad night to be you."]
const SAY_RANGE := 28.0

@export var member_scene: PackedScene
@export var nav: NodePath
@export var radius := 14.0
@export var crew_size := 4
## Seconds a warned player has to leave before the crew opens fire.
@export var warn_time := 6.0

var _members: Array[GangMember] = []
var _say_cooldown := 0.0
var _fire_light: OmniLight3D
var _flames: Array[Node3D] = []
var _spawned := 0
var _time := 0.0


func _ready() -> void:
	add_to_group("night_cleanup")
	add_to_group("gang_turf")
	_build_hangout()
	var region := get_node_or_null(nav) as EnemyNav
	if region and not region.is_baked:
		await region.baked
	_spawn_crew()


func _process(delta: float) -> void:
	_time += delta
	_say_cooldown -= delta
	if _fire_light:
		_fire_light.light_energy = 2.2 + sin(_time * 13.0) * 0.4 + randf_range(-0.3, 0.3)
		for i in _flames.size():
			_flames[i].scale.y = 0.8 + 0.35 * sin(_time * (9.0 + i * 2.3) + i)


func contains(point: Vector3) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() < radius


## A random walkable spot on the turf.
func patrol_point() -> Vector3:
	var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * radius * 0.7
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, global_position + offset)


## The whole crew turns on the player, who was last seen at `at`.
func go_hostile(at: Vector3) -> void:
	var was_calm := true
	for member in _living():
		was_calm = was_calm and not member.hostile
		member.become_hostile(at)
	if was_calm:
		_say(THREATS.pick_random(), true)


func say_warning() -> void:
	_say(WARNINGS.pick_random(), false)


func member_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for member in _living():
		rids.append(member.get_rid())
	return rids


## Cover spots the rest of the crew already uses (so they spread out).
func cover_spots(asking: GangMember) -> Array:
	var spots := []
	for member in _living():
		if member != asking and member.cover_spot() != Vector3.INF:
			spots.append(member.cover_spot())
	return spots


func member_died(_member: GangMember, _hit: HitInfo) -> void:
	pass


## A fresh, calm crew every night.
func clear_for_new_night() -> void:
	for member in _members:
		if is_instance_valid(member):
			member.queue_free()
	_members.clear()
	_spawn_crew.call_deferred()


func _living() -> Array[GangMember]:
	var result: Array[GangMember] = []
	for member in _members:
		if is_instance_valid(member) and not member.is_dead:
			result.append(member)
	return result


func _spawn_crew() -> void:
	if member_scene == null:
		return
	for i in crew_size:
		var member := member_scene.instantiate() as GangMember
		member.name = "Jackal%d" % _spawned
		_spawned += 1
		member.turf = self
		member.get_node("Model").look_seed = 7000 + _spawned * 31
		member.position = patrol_point() - global_position + Vector3.UP * 0.05
		member.rotation.y = randf() * TAU
		add_child(member)
		_members.append(member)


func _say(line: String, urgent: bool) -> void:
	if _say_cooldown > 0.0 and not urgent:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or player.global_position.distance_to(global_position) > SAY_RANGE + radius:
		return
	_say_cooldown = 5.0
	get_tree().call_group("hud", "show_message", "JACKAL: " + line, 2.5)


## Their corner: a burning barrel, a crate barricade and the gang's tag.
func _build_hangout() -> void:
	var rust := MatLib.surface(Color(0.35, 0.16, 0.08), 0.9, 0.4, 0.3)
	var crate := MatLib.surface(Palette.WOOD, 0.85, 0.0, 0.25)
	var trim := MatLib.neon(Palette.AMBER, 2.0)
	var barrel := Vector3(-3.5, 0.0, -2.5)
	var geo := GeoBatch.new()
	geo.add_cylinder(0.32, 0.3, 0.9, 10, Transform3D(Basis.IDENTITY, barrel + Vector3.UP * 0.45), rust)
	geo.add_cylinder(0.33, 0.33, 0.05, 10, Transform3D(Basis.IDENTITY, barrel + Vector3.UP * 0.3), MatLib.surface(Color(0.2, 0.1, 0.05), 0.8, 0.5))
	geo.build_into(self, "Barrel")
	var body := BuildKit.static_body(self, "BarrelCollision")
	BuildKit.box_collider_at(body, Vector3(0.62, 0.9, 0.62), barrel + Vector3.UP * 0.45)
	for i in 4:
		var flame := Node3D.new()
		flame.position = barrel + Vector3(randf_range(-0.12, 0.12), 0.88, randf_range(-0.12, 0.12))
		add_child(flame)
		var tongue := GeoBatch.new()
		var color := Palette.AMBER if i % 2 == 0 else Color(1.0, 0.85, 0.3)
		tongue.add_box(Vector3(0.14, 0.4, 0.14), Transform3D(Basis(Vector3.UP, i * 0.7), Vector3(0, 0.2, 0)), MatLib.neon(color, 4.0))
		tongue.build_into(flame, "Flame", false)
		_flames.append(flame)
	_fire_light = BuildKit.omni(self, barrel + Vector3.UP * 1.4, Color(1.0, 0.5, 0.15), 2.2, 9.0)
	var smoke := BuildKit.steam(barrel + Vector3.UP * 1.2, 16, 0.9)
	add_child(smoke)
	# Crates across the road: cover for the crew (and for the player).
	CoverBlock.create(self, Transform3D(Basis(Vector3.UP, 0.15), Vector3(2.0, 0.0, -1.5)), Vector3(1.4, 1.2, 1.0), crate, trim)
	CoverBlock.create(self, Transform3D(Basis(Vector3.UP, -0.3), Vector3(1.2, 0.0, 2.6)), Vector3(1.2, 1.0, 1.2), crate, trim)
	CoverBlock.create(self, Transform3D(Basis(Vector3.UP, 0.5), Vector3(-6.5, 0.0, 1.5)), Vector3(1.6, 1.15, 0.9), MatLib.surface(Palette.CONCRETE, 0.8), MatLib.neon(Palette.RED, 2.0))
	# Their tag on the barricade at the end of the street.
	var tag_basis := Basis(Vector3.UP, PI * 0.5)
	BuildKit.neon_text(self, "RUST JACKALS", Transform3D(tag_basis, Vector3(-11.3, 1.9, -5.5)), Palette.AMBER, 0.45, true)
	BuildKit.neon_text(self, "NO TOURISTS", Transform3D(tag_basis, Vector3(-11.3, 1.35, 5.0)), Palette.RED, 0.3, true)
