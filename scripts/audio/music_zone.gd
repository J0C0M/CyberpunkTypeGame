class_name MusicZone
extends Area3D
## A place with its own music (a shop, the lobby, the apartment radio). The track plays from a
## speaker inside (AudioStreamPlayer3D on the Music bus): from outside it sounds muffled and quieter,
## inside it is clear and the street music fades out. A zone without a stream is just quiet.
## Overlapping zones: the most recently entered one wins (see the Music autoload).

@export var stream: AudioStream
@export var volume_db := -7.0

var speaker: AudioStreamPlayer3D
var _inside := false


## Adds a box zone at `center` (local to `parent`) with the speaker at `speaker_position`.
static func create(parent: Node3D, size: Vector3, center: Vector3, music: AudioStream, speaker_position: Vector3, volume := -7.0) -> MusicZone:
	var zone := MusicZone.new()
	zone.stream = music
	zone.volume_db = volume
	zone.position = center
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	zone.add_child(collider)
	parent.add_child(zone)
	if music:
		zone.speaker.position = speaker_position - center
	return zone


func _init() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false


func _ready() -> void:
	add_to_group("music_zones")
	body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			Music.enter_zone(self))
	body_exited.connect(func(body: Node3D) -> void:
		if body is Player:
			Music.exit_zone(self))
	if stream and speaker == null:
		_make_speaker()


func _enter_tree() -> void:
	if stream and speaker == null:
		_make_speaker()


func _make_speaker() -> void:
	speaker = AudioStreamPlayer3D.new()
	speaker.stream = stream
	speaker.bus = &"Music"
	speaker.unit_size = 5.0
	speaker.max_distance = 45.0
	speaker.attenuation_filter_db = -24.0
	speaker.attenuation_filter_cutoff_hz = 900.0
	speaker.volume_db = volume_db - 10.0
	speaker.autoplay = true
	add_child(speaker)


## Inside: clear and full volume. Outside: muffled through the walls.
func set_inside(inside: bool) -> void:
	_inside = inside
	if speaker == null:
		return
	var delta := get_process_delta_time()
	speaker.attenuation_filter_cutoff_hz = move_toward(speaker.attenuation_filter_cutoff_hz, 20000.0 if inside else 900.0, delta * 30000.0)
	speaker.volume_db = move_toward(speaker.volume_db, volume_db if inside else volume_db - 10.0, delta * 20.0)
