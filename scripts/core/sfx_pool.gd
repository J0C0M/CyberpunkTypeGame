class_name SfxPool
extends Node3D
## Pooled one-shot 3D sounds (shatters, explosions, impacts). Lives inside the game world so the
## camera's listener hears it (group "sfx_pool"). Use SfxPool.play_at(node, stream, position).

@export var voices := 16

var _players: Array[AudioStreamPlayer3D] = []
var _next := 0


static func play_at(node: Node, stream: AudioStream, position: Vector3, volume_db := 0.0, pitch_variation := 0.08, unit_size := 6.0) -> void:
	var pool := node.get_tree().get_first_node_in_group("sfx_pool") as SfxPool
	if pool and stream:
		pool._play(stream, position, volume_db, pitch_variation, unit_size)


func _ready() -> void:
	add_to_group("sfx_pool")
	for i in voices:
		var player := AudioStreamPlayer3D.new()
		player.max_distance = 140.0
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)


func _play(stream: AudioStream, position: Vector3, volume_db: float, pitch_variation: float, unit_size: float) -> void:
	var player := _players[_next]
	_next = (_next + 1) % voices
	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.unit_size = unit_size
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.play()
