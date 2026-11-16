extends Node
## The title screen: a live, rainy shot of the city through the retro filter (MenuBackdrop) with
## the menu on top (sharp): Continue (the most recent save), New Game (the character creator),
## Load Game (characters and their save slots, with portraits; load or delete), Settings (the
## shared SettingsMenu), Credits and Quit. Mouse, keyboard and controller (focus) all work.

const CLICK := preload("res://assets/audio/ui_click.wav")
const CREATOR_SCENE := "res://scenes/character_creator.tscn"
const CREDITS := "NEO-KABUKICHO // BLOCK 7\nA low-poly cyberpunk prototype by J0C0M.\n\nMade with the Godot Engine 4.7 (MIT licence).\n\nEvery model, texture, icon, character, tattoo, sound and music track was generated in code for this project: the city and its people from primitives, the sounds by tools/generate_sfx.py and the music by tools/generate_music.py.\n\nThe Rust Jackals, Ren's noodle bar, the Kitsune P9, the Oni-12, Neo-Heights and every brand on the signs are invented.\n\nFonts: your system's monospace font. No asset packs are used; see CREDITS.md."

var _main: VBoxContainer
var _continue: Button
var _continue_info: Label
var _load_panel: PanelContainer
var _characters: VBoxContainer
var _slots: VBoxContainer
var _settings: SettingsMenu
var _credits: PanelContainer
var _confirm: PanelContainer
var _confirm_text: Label
var _confirm_yes: Button
var _pending_delete := ""
var _selected_character := ""
var _audio: AudioStreamPlayer


func _ready() -> void:
	get_tree().paused = false
	GameState.claim_ui(&"menu")
	Music.play_menu(true)
	_audio = AudioStreamPlayer.new()
	_audio.stream = CLICK
	_audio.bus = &"UI"
	add_child(_audio)
	_build()
	_show_main()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_mouse_capture"):
		if _confirm.visible:
			_confirm.visible = false
			_load_panel.visible = true
			_focus_first(_slots)
		elif _load_panel.visible or _credits.visible:
			_show_main()
		get_viewport().set_input_as_handled()


func _play() -> void:
	_audio.play()


func _show_main() -> void:
	for panel: Control in [_load_panel, _settings, _credits, _confirm]:
		panel.visible = false
	_main.visible = true
	var newest := SaveGame.newest_save()
	_continue.disabled = newest == ""
	_continue_info.text = ""
	if newest != "":
		var meta: Dictionary = SaveGame.read_save(newest).get("meta", {})
		_continue_info.text = "%s  //  %s  //  %s" % [meta.get("character", "?"), meta.get("location", "?"), _playtime(float(meta.get("playtime", 0.0)))]
	(_continue if not _continue.disabled else _main.get_node("NewGame") as Button).grab_focus.call_deferred()


func _on_continue() -> void:
	_play()
	var newest := SaveGame.newest_save()
	if newest != "":
		SaveGame.load_slot(newest)


func _on_new_game() -> void:
	_play()
	get_tree().change_scene_to_file(CREATOR_SCENE)


func _on_load() -> void:
	_play()
	_main.visible = false
	_load_panel.visible = true
	_fill_characters()


func _on_settings() -> void:
	_play()
	_main.visible = false
	_settings.visible = true


func _on_credits() -> void:
	_play()
	_main.visible = false
	_credits.visible = true
	_focus_first(_credits)


# --- Load Game -------------------------------------------------------------------------------------

func _fill_characters() -> void:
	for child in _characters.get_children():
		child.queue_free()
	var characters := SaveGame.list_characters()
	if characters.is_empty():
		_characters.add_child(UiStyle.label("No saves yet.\nStart a New Game.", 16, Color(0.7, 0.7, 0.8), Color.BLACK))
		_fill_slots([])
		return
	if not characters.any(func(c: Dictionary) -> bool: return c["id"] == _selected_character):
		_selected_character = characters[0]["id"]
	for character in characters:
		var button := Button.new()
		button.text = "%s\n%d save%s" % [str(character["name"]).to_upper(), character["slots"].size(), "" if character["slots"].size() == 1 else "s"]
		button.icon = _portrait(character["slots"][0])
		button.expand_icon = false
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = character["id"] == _selected_character
		button.custom_minimum_size = Vector2(0, 72)
		UiStyle.style_button(button, Palette.PINK, 15)
		button.pressed.connect(func() -> void:
			_selected_character = character["id"]
			_play()
			_fill_characters())
		_characters.add_child(button)
		if character["id"] == _selected_character:
			_fill_slots(character["slots"])
	_focus_first(_slots)


func _fill_slots(slots: Array) -> void:
	for child in _slots.get_children():
		child.queue_free()
	for slot in slots:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UiStyle.panel(Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.35), Color(0, 0, 0, 0.35)))
		_slots.add_child(row)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		row.add_child(line)
		var picture := TextureRect.new()
		picture.texture = _portrait(slot)
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.custom_minimum_size = Vector2(64, 64)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(picture)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		text.add_child(UiStyle.label("%s  //  %s" % [str(slot.get("label", "Save")).to_upper(), slot.get("location", "?")], 15, Color.WHITE, Palette.CYAN.darkened(0.6)))
		text.add_child(UiStyle.label("%s   //   played %s   //   in game %s" % [str(slot.get("saved_at", "")).replace("T", " "), _playtime(float(slot.get("playtime", 0.0))), slot.get("clock", "--:--")], 13, Color(0.75, 0.8, 0.95), Color.BLACK))
		var load := Button.new()
		load.text = "LOAD"
		UiStyle.style_button(load, Palette.LIME, 15)
		load.pressed.connect(func() -> void:
			_play()
			SaveGame.load_slot(slot["path"]))
		line.add_child(load)
		var delete := Button.new()
		delete.text = "DELETE"
		UiStyle.style_button(delete, Palette.PINK, 15)
		delete.pressed.connect(_ask_delete.bind(slot))
		line.add_child(delete)


func _ask_delete(slot: Dictionary) -> void:
	_play()
	_pending_delete = slot["path"]
	_confirm_text.text = "Delete \"%s\" of %s (%s)?\nThis can't be undone." % [slot.get("label", "Save"), slot.get("character", "?"), str(slot.get("saved_at", "")).replace("T", " ")]
	_load_panel.visible = false
	_confirm.visible = true
	_confirm_yes.grab_focus.call_deferred()


func _on_delete_confirmed() -> void:
	SaveGame.delete_slot(_pending_delete)
	_pending_delete = ""
	_play()
	_confirm.visible = false
	_load_panel.visible = true
	_fill_characters()


func _portrait(slot: Dictionary) -> Texture2D:
	var encoded := str(slot.get("portrait", ""))
	var raw := Marshalls.base64_to_raw(encoded) if encoded != "" else PackedByteArray()
	var image := Image.new()
	if raw.is_empty() or image.load_png_from_buffer(raw) != OK:
		image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.1, 0.05, 0.15))
		image.fill_rect(Rect2i(17, 10, 14, 16), Color(0.5, 0.45, 0.6))
		image.fill_rect(Rect2i(11, 28, 26, 20), Color(0.5, 0.45, 0.6))
	if image.get_width() != 64:
		image.resize(64, 64, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


static func _playtime(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	return "%dh %02dm" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d min" % minutes


func _focus_first(parent: Node) -> void:
	for child in parent.find_children("*", "Button", true, false):
		if (child as Button).visible and not (child as Button).disabled:
			(child as Button).grab_focus.call_deferred()
			return


# --- Layout ------------------------------------------------------------------------------------

func _build() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.05, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	layer.add_child(_main)
	_main.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_main.offset_left = 70
	_main.offset_top = 90
	_main.offset_right = 520
	_main.add_child(UiStyle.label("NEO-KABUKICHO", 54, Color.WHITE, Palette.PINK))
	_main.add_child(UiStyle.label("BLOCK 7  //  ALWAYS NIGHT", 20, Palette.CYAN, Palette.CYAN.darkened(0.6)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	_main.add_child(gap)
	_continue = _menu_button("CONTINUE", Palette.LIME, _on_continue)
	_continue_info = UiStyle.label("", 13, Color(0.75, 0.8, 0.95), Color.BLACK)
	_main.add_child(_continue_info)
	_menu_button("NEW GAME", Palette.PINK, _on_new_game).name = "NewGame"
	_menu_button("LOAD GAME", Palette.CYAN, _on_load)
	_menu_button("SETTINGS", Palette.PURPLE, _on_settings)
	_menu_button("CREDITS", Palette.AMBER, _on_credits)
	_menu_button("QUIT", Color(0.7, 0.7, 0.8), SaveGame.quit_game)
	var version := UiStyle.label("PROTOTYPE 5", 13, Color(0.6, 0.6, 0.7), Color.BLACK)
	layer.add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -200
	version.offset_top = -40
	version.offset_right = -24
	version.offset_bottom = -16
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_load(center)
	_settings = SettingsMenu.new()
	center.add_child(_settings)
	_settings.closed.connect(_show_main)
	_build_credits(center)
	_build_confirm(center)


func _menu_button(text: String, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(320, 0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiStyle.style_button(button, color, 22)
	button.pressed.connect(action)
	_main.add_child(button)
	return button


func _build_load(parent: Control) -> void:
	_load_panel = PanelContainer.new()
	_load_panel.add_theme_stylebox_override("panel", UiStyle.panel(Palette.CYAN))
	_load_panel.custom_minimum_size = Vector2(1080, 580)
	parent.add_child(_load_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_load_panel.add_child(column)
	column.add_child(UiStyle.label("LOAD GAME", 28, Color.WHITE, Palette.CYAN.darkened(0.3)))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left)
	_characters = VBoxContainer.new()
	_characters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_characters.add_theme_constant_override("separation", 6)
	left.add_child(_characters)
	var right := ScrollContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right)
	_slots = VBoxContainer.new()
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots.add_theme_constant_override("separation", 6)
	right.add_child(_slots)
	var back := Button.new()
	back.text = "BACK  [ESC]"
	UiStyle.style_button(back, Palette.PINK, 17)
	back.pressed.connect(_show_main)
	column.add_child(back)


func _build_credits(parent: Control) -> void:
	_credits = PanelContainer.new()
	_credits.add_theme_stylebox_override("panel", UiStyle.panel(Palette.AMBER))
	_credits.custom_minimum_size = Vector2(760, 0)
	parent.add_child(_credits)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_credits.add_child(column)
	column.add_child(UiStyle.label("CREDITS", 28, Color.WHITE, Palette.AMBER.darkened(0.4)))
	var text := UiStyle.label(CREDITS, 16, Color(0.85, 0.9, 1.0), Color.BLACK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)
	var back := Button.new()
	back.text = "BACK  [ESC]"
	UiStyle.style_button(back, Palette.PINK, 17)
	back.pressed.connect(_show_main)
	column.add_child(back)


func _build_confirm(parent: Control) -> void:
	_confirm = PanelContainer.new()
	_confirm.add_theme_stylebox_override("panel", UiStyle.panel(Palette.RED))
	_confirm.custom_minimum_size = Vector2(560, 0)
	parent.add_child(_confirm)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_confirm.add_child(column)
	_confirm_text = UiStyle.label("", 17, Color.WHITE, Palette.RED.darkened(0.5))
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_confirm_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	_confirm_yes = Button.new()
	_confirm_yes.text = "DELETE"
	UiStyle.style_button(_confirm_yes, Palette.RED, 16)
	_confirm_yes.pressed.connect(_on_delete_confirmed)
	row.add_child(_confirm_yes)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	UiStyle.style_button(cancel, Palette.CYAN, 16)
	cancel.pressed.connect(func() -> void:
		_confirm.visible = false
		_load_panel.visible = true
		_focus_first(_slots))
	row.add_child(cancel)
