extends Node
## Player settings (autoload "Settings"): bus volumes and mouse sensitivity, saved to
## user://settings.cfg and applied on start. The Music bus volume is applied by the Music
## autoload, which adds its ducking on top.

const PATH := "user://settings.cfg"
const BUSES: Array[String] = ["Master", "Music", "SFX", "Ambience", "UI"]

var volumes := {"Master": 0.9, "Music": 0.7, "SFX": 0.9, "Ambience": 0.8, "UI": 0.8}
var mouse_sensitivity := 0.0022


func _ready() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		for bus in BUSES:
			volumes[bus] = float(file.get_value("audio", bus, volumes[bus]))
		mouse_sensitivity = float(file.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	apply()


func bus_db(bus: String) -> float:
	return linear_to_db(maxf(volumes[bus], 0.0001))


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	apply()
	save()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value
	save()


func apply() -> void:
	for bus in BUSES:
		if bus != "Music":
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), bus_db(bus))


func save() -> void:
	var file := ConfigFile.new()
	for bus in BUSES:
		file.set_value("audio", bus, volumes[bus])
	file.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	file.save(PATH)
