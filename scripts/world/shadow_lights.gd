class_name ShadowLights
extends Node
## Gives the few strongest lights near the player shadows, so the player's body (and everything
## around them) casts real shadows without paying for shadows on all 140-odd lights in the city.
## Every half second the nearest bright omni and spot lights within reach get shadows; the rest
## don't. Lights that only light the first-person gun (cull mask 2) are left alone.

@export var count := 3
@export var reach := 16.0
@export var min_energy := 0.8

var _lit: Array[Light3D] = []
var _timer := 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var from := player.global_position + Vector3.UP
	var candidates: Array = []
	for light: Light3D in get_tree().root.find_children("*", "Light3D", true, false):
		if light is DirectionalLight3D or not light.is_visible_in_tree() or light.light_energy < min_energy:
			continue
		if light.light_cull_mask == RifleModel.VIEW_MODEL_LAYER or light.name == "FlashLight":
			continue
		var distance := light.global_position.distance_to(from)
		var light_range: float = light.get("omni_range") if light is OmniLight3D else light.get("spot_range")
		if distance < minf(reach, light_range):
			candidates.append([distance / light.light_energy, light])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var chosen: Array[Light3D] = []
	for entry in candidates.slice(0, count):
		chosen.append(entry[1])
	for light in _lit:
		if is_instance_valid(light) and not chosen.has(light):
			light.shadow_enabled = false
	for light in chosen:
		if not light.shadow_enabled:
			light.shadow_enabled = true
			light.shadow_bias = 0.06
			light.shadow_normal_bias = 1.5
	_lit = chosen
