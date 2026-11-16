class_name Footsteps
extends Node
## The player's footsteps. Steps are timed by distance walked (a longer stride when sprinting) and
## the head bob follows the same `phase`, so they line up. Each surface (concrete, wet puddles,
## metal grates, wood, tile) has several soft variations picked at random, never the same one twice
## in a row, with a little pitch and volume jitter. Jumps and falls end in a landing thud.

## Emitted for every step (and the landing step) with the surface it was on.
signal stepped(surface: StringName)

const SURFACES: Array[StringName] = [&"concrete", &"wet", &"metal", &"wood", &"tile"]
const VARIATIONS := 4
## Mixed well under the gunshots (-6 dB) and the city ambience (-12 dB).
const VOLUME_DB := {&"concrete": -19.0, &"wet": -17.0, &"metal": -18.0, &"wood": -17.0, &"tile": -18.0}

@export var walk_stride := 1.9
@export var sprint_stride := 2.5

## Advances by PI per step; the camera bob uses it.
var phase := 0.0
## Surface under the player at the last step (for debugging and tests).
var last_surface := &"concrete"

var _streams := {}
var _last_index := {}
var _landings: Array[AudioStream] = []
var _audio: AudioStreamPlayer
var _air_time := 0.0
var _fall_speed := 0.0


func _ready() -> void:
	for surface in SURFACES:
		var list: Array[AudioStream] = []
		for i in VARIATIONS:
			list.append(load("res://assets/audio/footsteps/%s_%d.wav" % [surface, i + 1]))
		_streams[surface] = list
		_last_index[surface] = -1
	_landings = [load("res://assets/audio/footsteps/land_1.wav"), load("res://assets/audio/footsteps/land_2.wav")]
	_audio = AudioStreamPlayer.new()
	_audio.max_polyphony = 3
	add_child(_audio)


## Called by the player every physics frame with the horizontal distance it just moved.
func update(player: Player, delta: float, distance: float) -> void:
	if not player.is_on_floor():
		_air_time += delta
		_fall_speed = maxf(_fall_speed, -player.velocity.y)
		return
	if _air_time > 0.25:
		_land(player, clampf(_fall_speed / 7.0, 0.25, 1.0))
	_air_time = 0.0
	_fall_speed = 0.0
	var stride := sprint_stride if player.is_sprinting else walk_stride
	var before := floori(phase / PI)
	phase += distance / stride * PI
	if floori(phase / PI) != before:
		_step(_surface_under(player))


func _step(surface: StringName) -> void:
	last_surface = surface
	var list: Array = _streams[surface]
	var index := randi() % list.size()
	if index == _last_index[surface]:
		index = (index + 1 + randi() % (list.size() - 1)) % list.size()
	_last_index[surface] = index
	stepped.emit(surface)
	_play(list[index], VOLUME_DB[surface] + randf_range(-1.5, 1.5), randf_range(0.92, 1.08))


func _land(player: Player, strength: float) -> void:
	_play(_landings.pick_random(), -20.0 + 8.0 * strength, randf_range(0.9, 1.05))
	_step.call_deferred(_surface_under(player))


func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	_audio.stream = stream
	_audio.volume_db = volume_db
	_audio.pitch_scale = pitch
	_audio.play()


## Reads the "surface" tag of the collision shape underfoot. Streets and sidewalks are concrete,
## or wet where the street shader draws a puddle, or metal on grates and manhole covers.
func _surface_under(player: Player) -> StringName:
	var from := player.global_position + Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.8, 1 | 8)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return &"concrete"
	var collider := hit["collider"] as CollisionObject3D
	var shape := collider.shape_owner_get_owner(collider.shape_find_owner(hit["shape"])) as Node
	var tag: StringName = shape.get_meta(&"surface", collider.get_meta(&"surface", &"concrete"))
	if tag == &"street" or tag == &"sidewalk":
		var city := player.get_tree().get_first_node_in_group("city")
		if city and city.surface_at(hit["position"]) == &"metal":
			return &"metal"
		return &"wet" if StreetSurface.is_wet(hit["position"], shape.get_meta(&"puddles", 0.0)) else &"concrete"
	return tag if SURFACES.has(tag) else &"concrete"
