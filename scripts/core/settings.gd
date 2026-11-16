extends Node
## Player settings (autoload "Settings"), saved to user://settings.cfg and applied on start:
## - graphics: resolution, window mode, retro-filter strength, VSync and an FPS cap
## - audio: a volume per bus (the Music bus is applied by the Music autoload, which ducks on top)
## - controls: mouse sensitivity, invert Y and rebindable keys (keyboard, mouse or controller)
## - gameplay: field of view and head bob
## The settings menu (ui/settings_menu.gd) edits these from both the main menu and the pause menu.

signal changed

const PATH := "user://settings.cfg"
const BUSES: Array[String] = ["Master", "Music", "SFX", "Ambience", "UI"]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const WINDOW_MODES := ["Windowed", "Borderless window", "Fullscreen"]
const FPS_CAPS: Array[int] = [0, 30, 60, 120, 144, 240]
## Actions the player can rebind, with their labels, in menu order.
const REBINDABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"], ["move_right", "Move right"],
	["jump", "Jump"], ["sprint", "Sprint"], ["shoot", "Fire"], ["reload", "Reload"], ["interact", "Interact"],
	["inventory", "Inventory"], ["quick_heal", "Quick heal"],
	["weapon_1", "Weapon 1"], ["weapon_2", "Weapon 2"], ["weapon_3", "Weapon 3"],
]

var volumes := {"Master": 0.9, "Music": 0.7, "SFX": 0.9, "Ambience": 0.8, "UI": 0.8}
var mouse_sensitivity := 0.0022
var invert_y := false
var resolution := Vector2i(1280, 720)
var window_mode := 0
## 0 = off, 0.6 = the default look, 1 = very chunky pixels and heavy dithering.
var retro_strength := 0.6
var vsync := true
var fps_cap := 0
var fov := 75.0
var head_bob := true

## The project's own bindings, for "reset to defaults".
var _default_bindings := {}


func _ready() -> void:
	for entry in REBINDABLE:
		_default_bindings[entry[0]] = InputMap.action_get_events(entry[0]).duplicate()
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		for bus in BUSES:
			volumes[bus] = float(file.get_value("audio", bus, volumes[bus]))
		mouse_sensitivity = float(file.get_value("input", "mouse_sensitivity", mouse_sensitivity))
		invert_y = bool(file.get_value("input", "invert_y", invert_y))
		resolution = file.get_value("graphics", "resolution", resolution)
		window_mode = int(file.get_value("graphics", "window_mode", window_mode))
		retro_strength = float(file.get_value("graphics", "retro_strength", retro_strength))
		vsync = bool(file.get_value("graphics", "vsync", vsync))
		fps_cap = int(file.get_value("graphics", "fps_cap", fps_cap))
		fov = float(file.get_value("gameplay", "fov", fov))
		head_bob = bool(file.get_value("gameplay", "head_bob", head_bob))
		for entry in REBINDABLE:
			if not file.has_section_key("bindings", entry[0]):
				continue
			var saved: Variant = file.get_value("bindings", entry[0])
			if saved is Array:
				_set_events(entry[0], (saved as Array).map(decode_event).filter(func(e: Variant) -> bool: return e != null))
	apply()
	apply_display()


func bus_db(bus: String) -> float:
	return linear_to_db(maxf(volumes[bus], 0.0001))


func set_volume(bus: String, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	apply()
	save()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = value
	save()


## Sets any plain setting by name (graphics, gameplay, input) and applies it.
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	if key in ["resolution", "window_mode", "vsync", "fps_cap"]:
		apply_display()
	apply()
	save()


func apply() -> void:
	for bus in BUSES:
		if bus != "Music":
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), bus_db(bus))
	get_tree().call_group("retro_screen", "apply_settings")
	changed.emit()


func apply_display() -> void:
	Engine.max_fps = fps_cap
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	match window_mode:
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if DisplayServer.window_get_size() != resolution:
				DisplayServer.window_set_size(resolution)
				var screen := DisplayServer.screen_get_size()
				DisplayServer.window_set_position((screen - resolution) / 2)


# --- Key bindings ------------------------------------------------------------------------------

## The first binding of an action as text ("W", "Mouse 1", "Pad A"...).
func binding_text(action: String) -> String:
	var events := InputMap.action_get_events(action)
	return event_text(events[0]) if not events.is_empty() else "-"


## Replaces the action's binding of the same kind (keyboard/mouse vs controller) with `event`.
func rebind(action: String, event: InputEvent) -> void:
	var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	var kept: Array = InputMap.action_get_events(action).filter(func(e: InputEvent) -> bool: return (e is InputEventJoypadButton or e is InputEventJoypadMotion) != is_pad)
	_set_events(action, [event] + kept)
	save()


func reset_bindings() -> void:
	for action in _default_bindings:
		_set_events(action, _default_bindings[action])
	save()


func _set_events(action: String, events: Array) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


static func event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		# Show the key the current keyboard layout puts there (not possible on the headless server).
		if key.physical_keycode != 0 and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		return ["", "Mouse 1", "Mouse 2", "Mouse 3", "Wheel up", "Wheel down"][clampi((event as InputEventMouseButton).button_index, 0, 5)]
	if event is InputEventJoypadButton:
		return "Pad %d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return "Axis %d%s" % [motion.axis, "+" if motion.axis_value > 0 else "-"]
	return "?"


static func encode_event(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % (event as InputEventKey).physical_keycode
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "joy:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return "axis:%d:%d" % [motion.axis, 1 if motion.axis_value > 0 else -1]
	return ""


static func decode_event(text: Variant) -> InputEvent:
	var parts := str(text).split(":")
	match parts[0]:
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(parts[1]) as Key
			return key
		"mouse":
			var button := InputEventMouseButton.new()
			button.button_index = int(parts[1]) as MouseButton
			return button
		"joy":
			var pad := InputEventJoypadButton.new()
			pad.button_index = int(parts[1]) as JoyButton
			return pad
		"axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(parts[1]) as JoyAxis
			motion.axis_value = float(parts[2])
			return motion
	return null


func save() -> void:
	var file := ConfigFile.new()
	for bus in BUSES:
		file.set_value("audio", bus, volumes[bus])
	file.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	file.set_value("input", "invert_y", invert_y)
	file.set_value("graphics", "resolution", resolution)
	file.set_value("graphics", "window_mode", window_mode)
	file.set_value("graphics", "retro_strength", retro_strength)
	file.set_value("graphics", "vsync", vsync)
	file.set_value("graphics", "fps_cap", fps_cap)
	file.set_value("gameplay", "fov", fov)
	file.set_value("gameplay", "head_bob", head_bob)
	for entry in REBINDABLE:
		file.set_value("bindings", entry[0], InputMap.action_get_events(entry[0]).map(encode_event))
	file.save(PATH)
