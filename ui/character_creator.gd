extends Node
## New Game: the character creator. The Body Shop (a BodyShop scene, seen through the retro
## filter) shows the character on a turntable; the sharp UI on the left edits a CharacterData:
## name, face, hair, body, tattoos and the starting outfit. Drag to turn the platform, wheel to
## zoom from body to face, U to preview the underwear. Confirm creates a new save slot and starts
## the game at Ren's noodle bar; Back returns to the main menu. Works with mouse, keyboard and a
## controller (every control takes focus; shoulder buttons switch tabs).

const CLICK := preload("res://assets/audio/ui_click.wav")
const TABS := ["IDENTITY", "FACE", "HAIR", "BODY", "TATTOOS", "OUTFIT"]

@onready var _shop: BodyShop = $RetroScreen/SubViewport/BodyShop

var data := CharacterData.new()

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _refreshers: Array[Callable] = []
var _name_edit: LineEdit
var _tattoo_list: VBoxContainer
var _tattoo_editor: VBoxContainer
var _selected_tattoo := -1
var _underwear: CheckButton
var _status: Label
var _audio: AudioStreamPlayer
var _dragging := false
var _dirty := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	GameState.claim_ui(&"menu")
	Music.play_menu(true)
	data.character_name = CharacterOptions.FIRST_NAMES.pick_random()
	_audio = AudioStreamPlayer.new()
	_audio.stream = CLICK
	_audio.bus = &"UI"
	add_child(_audio)
	_build_ui()
	_shop.model.data = data
	_select_tab(0)
	_refresh()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_shop.model.rebuild()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button:
		if button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = button.pressed
			_shop.auto_rotate = not button.pressed and _shop.auto_rotate
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_shop.zoom = minf(1.0, _shop.zoom + 0.15)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_shop.zoom = maxf(0.0, _shop.zoom - 0.15)
	elif event is InputEventMouseMotion and _dragging:
		_shop.auto_rotate = false
		_shop.spin((event as InputEventMouseMotion).relative.x * 0.01)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_U:
				_underwear.button_pressed = not _underwear.button_pressed
			KEY_F:
				_shop.zoom = 1.0
			KEY_B:
				_shop.zoom = 0.0
			KEY_Q:
				_shop.spin(-0.4)
			KEY_E:
				_shop.spin(0.4)
	elif event is InputEventJoypadButton and event.pressed:
		var pad := event as InputEventJoypadButton
		if pad.button_index == JOY_BUTTON_LEFT_SHOULDER:
			_select_tab(posmod(_current_tab() - 1, TABS.size()))
		elif pad.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_select_tab(posmod(_current_tab() + 1, TABS.size()))
	elif event is InputEventJoypadMotion:
		var axis := event as InputEventJoypadMotion
		if axis.axis == JOY_AXIS_RIGHT_X and absf(axis.axis_value) > 0.3:
			_shop.auto_rotate = false
			_shop.spin(axis.axis_value * 0.08)
		elif axis.axis == JOY_AXIS_RIGHT_Y and absf(axis.axis_value) > 0.3:
			_shop.zoom = clampf(_shop.zoom - axis.axis_value * 0.05, 0.0, 1.0)


# --- Actions -----------------------------------------------------------------------------------

func _changed() -> void:
	_dirty = true
	_refresh()


func _refresh() -> void:
	for refresher in _refreshers:
		refresher.call()
	_rebuild_tattoo_list()
	_status.text = "%s  //  %s" % [data.character_name.to_upper(), Outfits.label(data.outfit).to_upper()]


func _on_randomize() -> void:
	var keep_name := data.character_name
	data.randomize_look(_rng)
	data.character_name = keep_name
	_selected_tattoo = -1
	_play()
	_changed()


func _on_reset() -> void:
	var keep_name := data.character_name
	data = CharacterData.new()
	data.character_name = keep_name
	_shop.model.data = data
	_selected_tattoo = -1
	_play()
	_changed()


func _on_back() -> void:
	_play()
	get_tree().change_scene_to_file(SaveGame.MENU_SCENE)


func _on_confirm() -> void:
	data.character_name = _name_edit.text.strip_edges()
	if data.character_name == "":
		data.character_name = CharacterOptions.FIRST_NAMES.pick_random()
	_play()
	SaveGame.start_new_character(data)


func _play() -> void:
	_audio.play()


func _current_tab() -> int:
	for i in _pages.size():
		if _pages[i].visible:
			return i
	return 0


func _select_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		_tab_buttons[i].button_pressed = i == index
	_shop.zoom = 1.0 if TABS[index] in ["FACE", "HAIR"] else 0.0


# --- Layout ------------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel(Palette.PINK, Color(0.03, 0.01, 0.06, 0.88)))
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 20
	panel.offset_top = 20
	panel.offset_bottom = -20
	panel.offset_right = 480
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UiStyle.label("BODY SHOP  //  NEW CITIZEN", 22, Color.WHITE, Palette.PINK))
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
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
		UiStyle.style_button(button, Palette.CYAN, 14)
		button.pressed.connect(_select_tab.bind(i))
		tabs.add_child(button)
		_tab_buttons.append(button)
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 8)
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(page)
		_pages.append(page)
	_build_identity(_pages[0])
	_build_face(_pages[1])
	_build_hair(_pages[2])
	_build_body(_pages[3])
	_build_tattoos(_pages[4])
	_build_outfit(_pages[5])
	column.add_child(UiStyle.label("DRAG / Q E turn   WHEEL zoom   F face   B body   U underwear   LB RB tabs", 12, Color(0.6, 0.6, 0.7), Color.BLACK))

	# Bottom right: what you're making and the big buttons.
	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	layer.add_child(actions)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.offset_left = -440
	actions.offset_top = -170
	actions.offset_right = -24
	actions.offset_bottom = -24
	_status = UiStyle.label("", 20, Color.WHITE, Palette.CYAN.darkened(0.5))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	actions.add_child(_status)
	_underwear = CheckButton.new()
	_underwear.text = "UNDERWEAR PREVIEW  [U]"
	_underwear.add_theme_font_override("font", UiStyle.font())
	_underwear.add_theme_font_size_override("font_size", 14)
	_underwear.toggled.connect(func(on: bool) -> void: _shop.model.show_outfit = not on)
	_underwear.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	actions.add_child(_underwear)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	actions.add_child(row)
	_big_button(row, "BACK", Palette.PINK, _on_back)
	_big_button(row, "RANDOMIZE", Palette.AMBER, _on_randomize)
	_big_button(row, "RESET", Palette.PURPLE, _on_reset)
	var confirm := _big_button(row, "CONFIRM", Palette.LIME, _on_confirm)
	confirm.grab_focus.call_deferred()


func _big_button(parent: Control, text: String, color: Color, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	UiStyle.style_button(button, color, 17)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _section(parent: Control, title: String) -> void:
	parent.add_child(UiStyle.label(title, 15, Palette.AMBER, Palette.AMBER.darkened(0.7)))


## "Label  < value >": cycles through `labels`; get/set read and write the index.
func _selector(parent: Control, title: String, labels: Array, getter: Callable, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var caption := UiStyle.label(title, 14, Color(0.85, 0.9, 1.0), Color.BLACK)
	caption.custom_minimum_size = Vector2(120, 0)
	row.add_child(caption)
	var previous := Button.new()
	previous.text = "<"
	UiStyle.style_button(previous, Palette.CYAN, 14)
	row.add_child(previous)
	var value := UiStyle.label("", 14, Color.WHITE, Palette.CYAN.darkened(0.6))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var next := Button.new()
	next.text = ">"
	UiStyle.style_button(next, Palette.CYAN, 14)
	row.add_child(next)
	var step := func(direction: int) -> void:
		setter.call(posmod(int(getter.call()) + direction, labels.size()))
		_play()
		_changed()
	previous.pressed.connect(step.bind(-1))
	next.pressed.connect(step.bind(1))
	_refreshers.append(func() -> void: value.text = str(labels[int(getter.call())]))


## A row of colour swatches; the chosen one gets a white frame.
func _swatches(parent: Control, title: String, colors: Array, getter: Callable, setter: Callable) -> void:
	parent.add_child(UiStyle.label(title, 14, Color(0.85, 0.9, 1.0), Color.BLACK))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 5)
	row.add_theme_constant_override("v_separation", 5)
	parent.add_child(row)
	var buttons: Array[Button] = []
	for i in colors.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(30, 26)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(func() -> void:
			setter.call(i)
			_play()
			_changed())
		row.add_child(button)
		buttons.append(button)
	_refreshers.append(func() -> void:
		for i in buttons.size():
			var chosen := int(getter.call()) == i
			for state in ["normal", "hover", "pressed", "focus"]:
				var box := StyleBoxFlat.new()
				box.bg_color = colors[i]
				box.border_color = Color.WHITE if chosen else (Palette.CYAN if state == "focus" else Color(0, 0, 0, 0.6))
				box.set_border_width_all(3 if chosen or state == "focus" else 1)
				buttons[i].add_theme_stylebox_override(state, box))


func _slider(parent: Control, title: String, getter: Callable, setter: Callable, live: Callable) -> void:
	parent.add_child(UiStyle.label(title, 14, Color(0.85, 0.9, 1.0), Color.BLACK))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(0, 22)
	slider.focus_mode = Control.FOCUS_ALL
	parent.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		if is_equal_approx(value, float(getter.call())):
			return
		setter.call(value)
		if live.is_valid():
			live.call(value)
		else:
			_dirty = true)
	_refreshers.append(func() -> void: slider.set_value_no_signal(float(getter.call())))


func _build_identity(page: VBoxContainer) -> void:
	_section(page, "NAME")
	var row := HBoxContainer.new()
	page.add_child(row)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_override("font", UiStyle.font())
	_name_edit.add_theme_font_size_override("font_size", 18)
	_name_edit.text_changed.connect(func(text: String) -> void:
		data.character_name = text
		_status.text = "%s  //  %s" % [text.to_upper(), Outfits.label(data.outfit).to_upper()])
	row.add_child(_name_edit)
	var dice := Button.new()
	dice.text = "RANDOM NAME"
	UiStyle.style_button(dice, Palette.AMBER, 13)
	dice.pressed.connect(func() -> void:
		data.character_name = CharacterOptions.FIRST_NAMES.pick_random()
		_name_edit.text = data.character_name
		_refresh())
	row.add_child(dice)
	_refreshers.append(func() -> void:
		if _name_edit.text != data.character_name:
			_name_edit.text = data.character_name)
	_section(page, "SKIN")
	_swatches(page, "Skin tone", CharacterOptions.SKIN_TONES, func() -> int: return data.skin_tone, func(i: int) -> void: data.skin_tone = i)
	var note := UiStyle.label("Every citizen gets complimentary white underpants with hearts. They are not optional.", 13, Color(0.7, 0.7, 0.8), Color.BLACK)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)


func _build_face(page: VBoxContainer) -> void:
	_section(page, "FACE")
	_selector(page, "Head shape", CharacterOptions.HEAD_SHAPES.map(func(e: Array) -> String: return e[0]), func() -> int: return data.head_shape, func(i: int) -> void: data.head_shape = i)
	_selector(page, "Eyes", CharacterOptions.EYE_SHAPES, func() -> int: return data.eye_shape, func(i: int) -> void: data.eye_shape = i)
	_swatches(page, "Eye colour", CharacterOptions.EYE_COLORS, func() -> int: return data.eye_color, func(i: int) -> void: data.eye_color = i)
	_selector(page, "Eyebrows", CharacterOptions.BROWS, func() -> int: return data.brows, func(i: int) -> void: data.brows = i)
	_selector(page, "Nose", CharacterOptions.NOSES.map(func(e: Array) -> String: return e[0]), func() -> int: return data.nose, func(i: int) -> void: data.nose = i)
	_selector(page, "Mouth", CharacterOptions.MOUTHS, func() -> int: return data.mouth, func(i: int) -> void: data.mouth = i)
	_selector(page, "Facial hair", CharacterOptions.FACIAL_HAIR, func() -> int: return data.facial_hair, func(i: int) -> void: data.facial_hair = i)
	_section(page, "FACE CYBERWARE")
	for part: StringName in CharacterOptions.CYBERWARE:
		var toggle := CheckButton.new()
		toggle.text = CharacterOptions.CYBERWARE[part]
		toggle.add_theme_font_override("font", UiStyle.font())
		toggle.add_theme_font_size_override("font_size", 14)
		toggle.toggled.connect(func(on: bool) -> void:
			if on and not data.cyberware.has(part):
				data.cyberware.append(part)
			elif not on:
				data.cyberware.erase(part)
			_play()
			_changed())
		page.add_child(toggle)
		_refreshers.append(func() -> void: toggle.set_pressed_no_signal(data.cyberware.has(part)))


func _build_hair(page: VBoxContainer) -> void:
	_section(page, "HAIR")
	_selector(page, "Style", CharacterOptions.HAIR_STYLES, func() -> int: return data.hair_style, func(i: int) -> void: data.hair_style = i)
	_swatches(page, "Colour (the last five glow)", CharacterOptions.HAIR_COLORS.map(func(e: Array) -> Color: return e[1]), func() -> int: return data.hair_color, func(i: int) -> void: data.hair_color = i)


func _build_body(page: VBoxContainer) -> void:
	_section(page, "BODY")
	_slider(page, "Muscularity (slim - very muscular)", func() -> float: return data.muscle, func(v: float) -> void: data.muscle = v, func(v: float) -> void: _shop.model.set_muscle(v))
	_slider(page, "Build (narrow - broad)", func() -> float: return data.frame, func(v: float) -> void: data.frame = v, Callable())
	_slider(page, "Height (short - tall)", func() -> float: return data.height, func(v: float) -> void: data.height = v, Callable())


func _build_outfit(page: VBoxContainer) -> void:
	_section(page, "STARTING OUTFIT")
	var ids := Outfits.ids()
	_selector(page, "Outfit", ids.map(func(id: StringName) -> String: return Outfits.label(id)), func() -> int: return ids.find(data.outfit), func(i: int) -> void: data.outfit = ids[i])
	var pieces := UiStyle.label("", 13, Color(0.8, 0.85, 1.0), Color.BLACK)
	pieces.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(pieces)
	_refreshers.append(func() -> void:
		pieces.text = "Includes: " + ", ".join(Outfits.items(data.outfit).map(func(id: StringName) -> String: return ItemDB.display_name(id))))


func _build_tattoos(page: VBoxContainer) -> void:
	_section(page, "TATTOOS  (UP TO %d)" % CharacterOptions.MAX_TATTOOS)
	_tattoo_list = VBoxContainer.new()
	_tattoo_list.add_theme_constant_override("separation", 4)
	page.add_child(_tattoo_list)
	var add := Button.new()
	add.text = "+ ADD TATTOO"
	UiStyle.style_button(add, Palette.LIME, 14)
	add.pressed.connect(func() -> void:
		if data.tattoos.size() >= CharacterOptions.MAX_TATTOOS:
			return
		data.tattoos.append({"design": &"koi", "zone": &"forearm_r", "color": 5, "glow": false})
		_selected_tattoo = data.tattoos.size() - 1
		_play()
		_changed())
	page.add_child(add)
	_tattoo_editor = VBoxContainer.new()
	_tattoo_editor.add_theme_constant_override("separation", 8)
	page.add_child(_tattoo_editor)
	var designs := CharacterOptions.TATTOO_DESIGNS.keys()
	var zones := CharacterOptions.TATTOO_ZONES.keys()
	_selector(_tattoo_editor, "Design", designs.map(func(id: StringName) -> String: return CharacterOptions.TATTOO_DESIGNS[id]), func() -> int: return designs.find(_tattoo().get("design", &"koi")), func(i: int) -> void: _tattoo()["design"] = designs[i])
	_selector(_tattoo_editor, "Placement", zones.map(func(id: StringName) -> String: return CharacterOptions.TATTOO_ZONES[id]), func() -> int: return zones.find(_tattoo().get("zone", &"forearm_r")), func(i: int) -> void: _tattoo()["zone"] = zones[i])
	_swatches(_tattoo_editor, "Ink colour", CharacterOptions.TATTOO_COLORS.map(func(e: Array) -> Color: return e[1]), func() -> int: return int(_tattoo().get("color", 0)), func(i: int) -> void: _tattoo()["color"] = i)
	var glow := CheckButton.new()
	glow.text = "Glowing neon ink"
	glow.add_theme_font_override("font", UiStyle.font())
	glow.add_theme_font_size_override("font_size", 14)
	glow.toggled.connect(func(on: bool) -> void:
		_tattoo()["glow"] = on
		_play()
		_changed())
	_tattoo_editor.add_child(glow)
	_refreshers.append(func() -> void: glow.set_pressed_no_signal(bool(_tattoo().get("glow", false))))
	var remove := Button.new()
	remove.text = "REMOVE THIS TATTOO"
	UiStyle.style_button(remove, Palette.PINK, 14)
	remove.pressed.connect(func() -> void:
		if _selected_tattoo >= 0 and _selected_tattoo < data.tattoos.size():
			data.tattoos.remove_at(_selected_tattoo)
			_selected_tattoo = mini(_selected_tattoo, data.tattoos.size() - 1)
			_play()
			_changed())
	_tattoo_editor.add_child(remove)


## The tattoo being edited (an empty dictionary when none is selected).
func _tattoo() -> Dictionary:
	return data.tattoos[_selected_tattoo] if _selected_tattoo >= 0 and _selected_tattoo < data.tattoos.size() else {}


func _rebuild_tattoo_list() -> void:
	if _tattoo_list == null:
		return
	for child in _tattoo_list.get_children():
		child.queue_free()
	if _selected_tattoo >= data.tattoos.size():
		_selected_tattoo = data.tattoos.size() - 1
	for i in data.tattoos.size():
		var tattoo: Dictionary = data.tattoos[i]
		var button := Button.new()
		var ink: String = CharacterOptions.TATTOO_COLORS[int(tattoo["color"])][0]
		button.text = "%d. %s  //  %s  //  %s%s" % [i + 1, CharacterOptions.TATTOO_DESIGNS[tattoo["design"]], CharacterOptions.TATTOO_ZONES[tattoo["zone"]], ink, ", neon" if tattoo["glow"] else ""]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_pressed = i == _selected_tattoo
		UiStyle.style_button(button, Palette.PURPLE, 13)
		button.pressed.connect(func() -> void:
			_selected_tattoo = i
			_play()
			_refresh())
		_tattoo_list.add_child(button)
	_tattoo_editor.visible = _selected_tattoo >= 0
	if data.tattoos.is_empty():
		_tattoo_list.add_child(UiStyle.label("No ink yet.", 13, Color(0.6, 0.6, 0.7), Color.BLACK))
