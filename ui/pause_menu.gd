extends CanvasLayer
## Pause menu (Esc or Start): resume, save the game to a new slot, settings (the shared
## SettingsMenu), back to the main menu (warns about progress since the last save) and quit (saves).

var _backdrop: ColorRect
var _panel: PanelContainer
var _buttons: VBoxContainer
var _status: Label
var _settings: SettingsMenu
var _confirm: PanelContainer
var _confirm_text: Label
var _first: Button


func _ready() -> void:
	add_to_group("pause_menu")
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_set_open(false)


func is_open() -> bool:
	return _backdrop.visible


func open() -> void:
	if is_open() or not GameState.is_free_roaming():
		return
	GameState.claim_ui(&"paused")
	get_tree().paused = true
	_set_open(true)
	_show(_panel)
	_status.text = _last_save_text()
	_first.grab_focus.call_deferred()


func close() -> void:
	if not is_open():
		return
	_set_open(false)
	get_tree().paused = false
	GameState.release_ui()


func _set_open(open: bool) -> void:
	_backdrop.visible = open
	if not open:
		_panel.visible = false
		_settings.visible = false
		_confirm.visible = false


## Shows one of the three panels (main, settings, confirm).
func _show(panel: Control) -> void:
	for each: Control in [_panel, _settings, _confirm]:
		each.visible = each == panel


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("toggle_mouse_capture") or event.is_action_pressed("ui_cancel"):
		if _confirm.visible:
			_show(_panel)
			_first.grab_focus()
		elif _panel.visible:
			close()
		get_viewport().set_input_as_handled()


func _on_save() -> void:
	if SaveGame.save_manual():
		_status.text = "Saved. " + _last_save_text()
	else:
		_status.text = "Saving is off in this run (tests and screenshot tours)."


func _on_menu() -> void:
	var minutes := int((Time.get_unix_time_from_system() - SaveGame.last_save_unix) / 60.0)
	_confirm_text.text = "Back to the main menu?\n\nAnything since your last save (%s) will be lost unless you save now." % ("%d min ago" % minutes if SaveGame.last_save_unix > 0.0 else "none this session")
	_show(_confirm)
	_confirm.get_node("Column/Row/Save").grab_focus.call_deferred()


func _last_save_text() -> String:
	if SaveGame.last_save_unix <= 0.0:
		return "Not saved yet this session."
	var minutes := int((Time.get_unix_time_from_system() - SaveGame.last_save_unix) / 60.0)
	return "Last saved %d min ago." % minutes if minutes > 0 else "Last saved just now."


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.01, 0.0, 0.03, 0.6)
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_backdrop.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel(Palette.PURPLE))
	_panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(_panel)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	_panel.add_child(_buttons)
	_buttons.add_child(UiStyle.label("PAUSED", 30, Color.WHITE, Palette.PURPLE))
	_first = _button("RESUME  [ESC]", Palette.LIME, close)
	_button("SAVE GAME", Palette.CYAN, _on_save)
	_button("SETTINGS", Palette.PURPLE, func() -> void: _show(_settings))
	_button("BACK TO MAIN MENU", Palette.AMBER, _on_menu)
	_button("SAVE & QUIT TO DESKTOP", Palette.PINK, SaveGame.quit_game)
	_status = UiStyle.label("", 13, Color(0.65, 0.65, 0.75), Color.BLACK)
	_buttons.add_child(_status)

	_settings = SettingsMenu.new()
	center.add_child(_settings)
	_settings.closed.connect(func() -> void:
		_show(_panel)
		_first.grab_focus())

	_confirm = PanelContainer.new()
	_confirm.add_theme_stylebox_override("panel", UiStyle.panel(Palette.AMBER))
	_confirm.custom_minimum_size = Vector2(560, 0)
	center.add_child(_confirm)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 14)
	_confirm.add_child(column)
	_confirm_text = UiStyle.label("", 17, Color.WHITE, Palette.AMBER.darkened(0.6))
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_confirm_text)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var save_quit := _small_button(row, "SAVE AND GO", Palette.LIME, func() -> void: SaveGame.return_to_menu(true))
	save_quit.name = "Save"
	_small_button(row, "GO WITHOUT SAVING", Palette.PINK, func() -> void: SaveGame.return_to_menu(false))
	_small_button(row, "CANCEL", Palette.CYAN, func() -> void:
		_show(_panel)
		_first.grab_focus())


func _button(text: String, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	UiStyle.style_button(button, color, 18)
	button.pressed.connect(action)
	_buttons.add_child(button)
	return button


func _small_button(parent: Control, text: String, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	UiStyle.style_button(button, color, 15)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
