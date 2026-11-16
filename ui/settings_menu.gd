class_name SettingsMenu
extends PanelContainer
## The settings panel, shared by the main menu and the pause menu: graphics, audio, controls (with
## rebindable keys) and gameplay. Changes apply and save immediately (Settings autoload). Emits
## `closed` when the player backs out (BACK button, Esc or the controller's B).

signal closed

const TABS := ["GRAPHICS", "AUDIO", "CONTROLS", "GAMEPLAY"]

var _pages: Array[Control] = []
var _tab_buttons: Array[Button] = []
var _refreshers: Array[Callable] = []
## The action waiting for a new key, and its button.
var _rebinding := ""
var _rebind_button: Button
var _first_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UiStyle.panel(Palette.PURPLE))
	custom_minimum_size = Vector2(660, 560)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	column.add_child(UiStyle.label("SETTINGS", 28, Color.WHITE, Palette.PURPLE))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	for i in TABS.size():
		var button := Button.new()
		button.text = TABS[i]
		button.toggle_mode = true
		UiStyle.style_button(button, Palette.CYAN, 15)
		button.pressed.connect(_select.bind(i))
		tabs.add_child(button)
		_tab_buttons.append(button)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 8)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(page)
		_pages.append(page)
	_first_focus = _tab_buttons[0]
	_build_graphics(_pages[0])
	_build_audio(_pages[1])
	_build_controls(_pages[2])
	_build_gameplay(_pages[3])
	var back := Button.new()
	back.text = "BACK  [ESC]"
	UiStyle.style_button(back, Palette.PINK, 17)
	back.pressed.connect(_close)
	column.add_child(back)
	_select(0)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		_refresh()
		_first_focus.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _rebinding != "":
		_capture_binding(event)
		return
	if event.is_action_pressed("toggle_mouse_capture") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	_cancel_rebind()
	closed.emit()


func _select(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].button_pressed = i == index


func _refresh() -> void:
	for refresher in _refreshers:
		refresher.call()


# --- Rows -----------------------------------------------------------------------------------------

func _caption(row: Control, text: String) -> void:
	var label := UiStyle.label(text, 15, Color(0.85, 0.9, 1.0), Color.BLACK)
	label.custom_minimum_size = Vector2(250, 0)
	row.add_child(label)


func _row(page: Control, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	page.add_child(row)
	_caption(row, text)
	return row


## "< value >" through `labels`; `getter`/`setter` read and write the index.
func _choice(page: Control, text: String, labels: Array, getter: Callable, setter: Callable) -> void:
	var row := _row(page, text)
	var previous := Button.new()
	previous.text = "<"
	UiStyle.style_button(previous, Palette.CYAN, 15)
	row.add_child(previous)
	var value := UiStyle.label("", 15, Color.WHITE, Palette.CYAN.darkened(0.6))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var next := Button.new()
	next.text = ">"
	UiStyle.style_button(next, Palette.CYAN, 15)
	row.add_child(next)
	previous.pressed.connect(func() -> void:
		setter.call(posmod(int(getter.call()) - 1, labels.size()))
		_refresh())
	next.pressed.connect(func() -> void:
		setter.call(posmod(int(getter.call()) + 1, labels.size()))
		_refresh())
	_refreshers.append(func() -> void: value.text = str(labels[clampi(int(getter.call()), 0, labels.size() - 1)]))


func _slider(page: Control, text: String, low: float, high: float, step: float, getter: Callable, setter: Callable, format := "%d %%", scale := 100.0) -> void:
	var row := _row(page, text)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	row.add_child(slider)
	var value := UiStyle.label("", 14, Palette.AMBER, Palette.AMBER.darkened(0.7))
	value.custom_minimum_size = Vector2(70, 0)
	row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		value.text = format % (v * scale))
	_refreshers.append(func() -> void:
		slider.set_value_no_signal(float(getter.call()))
		value.text = format % (float(getter.call()) * scale))


func _toggle(page: Control, text: String, getter: Callable, setter: Callable) -> void:
	var row := _row(page, text)
	var toggle := CheckButton.new()
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.toggled.connect(func(on: bool) -> void: setter.call(on))
	row.add_child(toggle)
	_refreshers.append(func() -> void: toggle.set_pressed_no_signal(bool(getter.call())))


# --- Pages ----------------------------------------------------------------------------------------

func _build_graphics(page: VBoxContainer) -> void:
	var resolutions := Settings.RESOLUTIONS.map(func(r: Vector2i) -> String: return "%d x %d" % [r.x, r.y])
	_choice(page, "Resolution", resolutions, func() -> int: return maxi(0, Settings.RESOLUTIONS.find(Settings.resolution)), func(i: int) -> void: Settings.set_value("resolution", Settings.RESOLUTIONS[i]))
	_choice(page, "Window mode", Settings.WINDOW_MODES, func() -> int: return Settings.window_mode, func(i: int) -> void: Settings.set_value("window_mode", i))
	_slider(page, "Retro filter strength", 0.0, 1.0, 0.05, func() -> float: return Settings.retro_strength, func(v: float) -> void: Settings.set_value("retro_strength", v))
	_toggle(page, "VSync", func() -> bool: return Settings.vsync, func(on: bool) -> void: Settings.set_value("vsync", on))
	var caps := Settings.FPS_CAPS.map(func(cap: int) -> String: return "Unlimited" if cap == 0 else "%d FPS" % cap)
	_choice(page, "FPS cap", caps, func() -> int: return maxi(0, Settings.FPS_CAPS.find(Settings.fps_cap)), func(i: int) -> void: Settings.set_value("fps_cap", Settings.FPS_CAPS[i]))
	var note := UiStyle.label("0 % turns the retro filter off; F3 toggles it in game.", 13, Color(0.6, 0.6, 0.7), Color.BLACK)
	page.add_child(note)


func _build_audio(page: VBoxContainer) -> void:
	for bus in Settings.BUSES:
		_slider(page, bus.capitalize() + " volume", 0.0, 1.0, 0.01, func() -> float: return Settings.volumes[bus], func(v: float) -> void: Settings.set_volume(bus, v))


func _build_controls(page: VBoxContainer) -> void:
	_slider(page, "Mouse sensitivity", 0.0005, 0.006, 0.0001, func() -> float: return Settings.mouse_sensitivity, func(v: float) -> void: Settings.set_mouse_sensitivity(v), "%.1f", 1000.0)
	_toggle(page, "Invert Y", func() -> bool: return Settings.invert_y, func(on: bool) -> void: Settings.set_value("invert_y", on))
	page.add_child(UiStyle.label("KEYS  (click, then press a key, mouse button or pad button; ESC cancels)", 13, Palette.AMBER, Palette.AMBER.darkened(0.7)))
	for entry in Settings.REBINDABLE:
		var action: String = entry[0]
		var row := _row(page, entry[1])
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiStyle.style_button(button, Palette.CYAN, 15)
		button.pressed.connect(_start_rebind.bind(action, button))
		row.add_child(button)
		_refreshers.append(func() -> void:
			if _rebinding != action:
				button.text = Settings.binding_text(action))
	var reset := Button.new()
	reset.text = "RESET KEYS TO DEFAULTS"
	UiStyle.style_button(reset, Palette.AMBER, 14)
	reset.pressed.connect(func() -> void:
		Settings.reset_bindings()
		_refresh())
	page.add_child(reset)


func _build_gameplay(page: VBoxContainer) -> void:
	_slider(page, "Field of view", 60.0, 100.0, 1.0, func() -> float: return Settings.fov, func(v: float) -> void: Settings.set_value("fov", v), "%d", 1.0)
	_toggle(page, "Head bob", func() -> bool: return Settings.head_bob, func(on: bool) -> void: Settings.set_value("head_bob", on))


# --- Rebinding ------------------------------------------------------------------------------------

func _start_rebind(action: String, button: Button) -> void:
	_cancel_rebind()
	_rebinding = action
	_rebind_button = button
	button.text = "PRESS A KEY..."


func _cancel_rebind() -> void:
	_rebinding = ""
	_rebind_button = null
	_refresh()


func _capture_binding(event: InputEvent) -> void:
	var accepted: InputEvent
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_cancel_rebind()
			return
		var key := InputEventKey.new()
		key.physical_keycode = (event as InputEventKey).physical_keycode
		accepted = key
	elif event is InputEventMouseButton and event.pressed:
		var button := InputEventMouseButton.new()
		button.button_index = (event as InputEventMouseButton).button_index
		accepted = button
	elif event is InputEventJoypadButton and event.pressed:
		var pad := InputEventJoypadButton.new()
		pad.button_index = (event as InputEventJoypadButton).button_index
		accepted = pad
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
		var motion := InputEventJoypadMotion.new()
		motion.axis = (event as InputEventJoypadMotion).axis
		motion.axis_value = signf((event as InputEventJoypadMotion).axis_value)
		accepted = motion
	if accepted == null:
		return
	get_viewport().set_input_as_handled()
	Settings.rebind(_rebinding, accepted)
	_cancel_rebind()
