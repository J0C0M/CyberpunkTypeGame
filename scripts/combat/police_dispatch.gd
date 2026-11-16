class_name PoliceDispatch
extends Node3D
## The police's view of the player: "heat" (0..5, the wanted stars) rises with the player's
## violence (gunfire, killing pedestrians or shopkeepers, explosions, shooting drones; gang
## business on Jackal turf hardly counts) and cools down once things are quiet and no drone can
## see the player. Each star sends a police drone (at most three) that flies in from above the
## street; at zero heat they fly off. Respawning and sleeping clear the heat.
## Lives once in the world (group "police"); GameState.wanted mirrors the stars for merchants.

signal heat_changed(heat: float, stars: int)

const MAX_HEAT := 5.0
const MAX_DRONES := 3
## Heat per incident caused by the player.
const SHOT_HEAT := 0.07
const SHOT_HEAT_ON_TURF := 0.015
const PEDESTRIAN_KILL_HEAT := 1.2
const MERCHANT_KILL_HEAT := 1.6
const GANG_KILL_HEAT := 0.3
const EXPLOSION_HEAT := 0.8
const DRONE_HIT_HEAT := 0.15
## Quiet seconds before the heat starts dropping, and how fast it drops while unseen.
const COOL_DELAY := 15.0
const COOL_RATE := 0.14

const SIREN := preload("res://assets/audio/siren_whoop.wav")

@export var drone_scene: PackedScene

var heat := 0.0
## Seconds since a drone last saw the player.
var since_seen := 999.0
var last_seen := Vector3.ZERO

var _since_incident := 999.0
var _drones: Array[PoliceDrone] = []
var _spawn_cooldown := 0.0
var _siren: AudioStreamPlayer


func _ready() -> void:
	add_to_group("police")
	add_to_group("night_cleanup")
	_siren = AudioStreamPlayer.new()
	_siren.stream = SIREN
	_siren.bus = &"SFX"
	_siren.volume_db = -10.0
	add_child(_siren)
	EventBus.danger.connect(_on_danger)
	EventBus.person_killed.connect(_on_person_killed)


func stars() -> int:
	return clampi(int(heat), 0, 5)


func add_heat(amount: float) -> void:
	var before := stars()
	heat = clampf(heat + amount, 0.0, MAX_HEAT)
	_since_incident = 0.0
	if stars() > before:
		_siren.play()
	_publish()


func clear_heat() -> void:
	heat = 0.0
	_since_incident = 999.0
	for drone in _living_drones():
		drone.leave()
	_publish()


func clear_for_new_night() -> void:
	clear_heat()
	for drone in _drones:
		if is_instance_valid(drone):
			drone.queue_free()
	_drones.clear()


## A drone saw the player at `at`.
func report_sighting(at: Vector3) -> void:
	since_seen = 0.0
	last_seen = at


func _process(delta: float) -> void:
	_since_incident += delta
	since_seen += delta
	_spawn_cooldown -= delta
	if heat > 0.0 and _since_incident > COOL_DELAY and since_seen > 4.0:
		var before := stars()
		heat = maxf(0.0, heat - COOL_RATE * delta)
		if stars() != before or heat == 0.0:
			_publish()
	var wanted := mini(stars(), MAX_DRONES)
	var living := _living_drones()
	if living.size() < wanted and _spawn_cooldown <= 0.0:
		_spawn_drone()
		_spawn_cooldown = 4.0
	elif wanted == 0:
		for drone in living:
			drone.leave()


func _publish() -> void:
	GameState.wanted = stars()
	heat_changed.emit(heat, stars())


func _living_drones() -> Array[PoliceDrone]:
	var result: Array[PoliceDrone] = []
	for drone in _drones:
		if is_instance_valid(drone) and not drone.is_dead and not drone.leaving:
			result.append(drone)
	return result


## A new drone comes in high over a street, some way from the player.
func _spawn_drone() -> void:
	if drone_scene == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var around := player.global_position if player else Vector3.ZERO
	var along_main := randf() < 0.5
	var side := 1.0 if randf() < 0.5 else -1.0
	var from := Vector3(clampf(around.x + side * 45.0, -60.0, 60.0), 30.0, 0.0) if along_main else Vector3(0.0, 30.0, clampf(around.z + side * 45.0, -60.0, 60.0))
	var drone := drone_scene.instantiate() as PoliceDrone
	drone.dispatch = self
	add_child(drone)
	drone.global_position = from
	_drones.append(drone)
	_siren.play()


func _on_danger(position: Vector3, _radius: float, severity: float, source: Node) -> void:
	if not source is Player:
		return
	if severity == EventBus.SEVERITY_SHOT:
		var on_turf := false
		for turf in get_tree().get_nodes_in_group("gang_turf"):
			on_turf = on_turf or (turf as GangTurf).contains(position)
		add_heat(SHOT_HEAT_ON_TURF if on_turf else SHOT_HEAT)
	elif severity >= EventBus.SEVERITY_EXPLOSION:
		add_heat(EXPLOSION_HEAT)


func _on_person_killed(person: Node, hit: HitInfo) -> void:
	if not hit.source is Player:
		return
	if person is GangMember:
		add_heat(GANG_KILL_HEAT)
	elif person is Merchant:
		add_heat(MERCHANT_KILL_HEAT)
	else:
		add_heat(PEDESTRIAN_KILL_HEAT)
