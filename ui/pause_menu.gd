extends CanvasLayer
## Pause menu (Esc): resume, volume per audio bus, mouse sensitivity and quit. Settings are saved
## to user://settings.cfg by the Settings autoload.

var _panel: PanelContainer


func _ready() -> void:
	add_to_group("pause_menu")
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	if is_open() or not GameState.is_free_roaming():
		return
	GameState.claim_ui(&"paused")
	get_tree().paused = true
	_panel.visible = true


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	get_tree().paused = false
	GameState.release_ui()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("toggle_mouse_capture"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel(Palette.PURPLE))
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -260
	_panel.offset_right = 260
	_panel.offset_top = -250
	_panel.offset_bottom = 250
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	column.add_child(UiStyle.label("PAUSED", 30, Color.WHITE, Palette.PURPLE))
	for bus in Settings.BUSES:
		_slider(column, bus.to_upper() + " VOLUME", 0.0, 1.0, Settings.volumes[bus], func(value: float) -> void: Settings.set_volume(bus, value))
	_slider(column, "MOUSE SENSITIVITY", 0.0005, 0.006, Settings.mouse_sensitivity, Settings.set_mouse_sensitivity)
	var resume := Button.new()
	resume.text = "RESUME  [ESC]"
	UiStyle.style_button(resume, Palette.LIME, 18)
	resume.pressed.connect(close)
	column.add_child(resume)
	var quit := Button.new()
	quit.text = "QUIT TO DESKTOP"
	UiStyle.style_button(quit, Palette.PINK, 18)
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)


func _slider(parent: Control, title: String, low: float, high: float, value: float, on_change: Callable) -> void:
	parent.add_child(UiStyle.label(title, 14, Palette.CYAN, Palette.CYAN.darkened(0.7)))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = (high - low) / 100.0
	slider.value = value
	slider.custom_minimum_size = Vector2(440, 20)
	slider.value_changed.connect(on_change)
	parent.add_child(slider)
