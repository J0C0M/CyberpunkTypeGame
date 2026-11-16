extends Node
## Music (autoload "Music"): plays the street soundtrack and hands over to diegetic MusicZones
## (shops, lobby, apartment radio) with smooth crossfades. Ducks the Music bus during dialogue,
## trading and TV, and muffles it (low-pass) for a moment after nearby gunfire or explosions.

const STREET := preload("res://assets/music/street.ogg")
const STREET_DB := -9.0
## Extra Music-bus attenuation per UI mode.
const DUCK := {&"dialogue": -9.0, &"trade": -6.0, &"inventory": -6.0, &"seated": -40.0, &"paused": -10.0}

var _street: AudioStreamPlayer
var _zones: Array[MusicZone] = []
var _duck := 0.0
var _muffle := 0.0
var _bus := 0
var _lowpass: AudioEffectLowPassFilter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus = AudioServer.get_bus_index("Music")
	_lowpass = AudioServer.get_bus_effect(_bus, 0) as AudioEffectLowPassFilter
	_street = AudioStreamPlayer.new()
	_street.stream = STREET
	_street.bus = &"Music"
	_street.volume_db = STREET_DB
	add_child(_street)
	_street.play()
	EventBus.danger.connect(_on_danger)


func enter_zone(zone: MusicZone) -> void:
	_zones.erase(zone)
	_zones.append(zone)


func exit_zone(zone: MusicZone) -> void:
	_zones.erase(zone)


## The zone the player is in (the most recently entered one wins), or null on the street.
func current_zone() -> MusicZone:
	while not _zones.is_empty() and not is_instance_valid(_zones.back()):
		_zones.pop_back()
	return _zones.back() if not _zones.is_empty() else null


func _process(delta: float) -> void:
	var zone := current_zone()
	_street.volume_db = move_toward(_street.volume_db, -60.0 if zone else STREET_DB, delta * (30.0 if zone else 15.0))
	for node in get_tree().get_nodes_in_group("music_zones"):
		(node as MusicZone).set_inside(node == zone)
	_duck = move_toward(_duck, DUCK.get(GameState.ui_mode, 0.0), delta * 25.0)
	AudioServer.set_bus_volume_db(_bus, Settings.bus_db("Music") + _duck)
	_muffle = move_toward(_muffle, 0.0, delta * 0.6)
	if _lowpass:
		_lowpass.cutoff_hz = lerpf(20000.0, 600.0, sqrt(_muffle))


## Gunfire and explosions near the player muffle the music for a moment.
func _on_danger(position: Vector3, radius: float, severity: float, _source: Node) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(position) < radius:
		_muffle = maxf(_muffle, clampf(severity / 3.0, 0.3, 1.0))
