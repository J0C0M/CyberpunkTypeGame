extends CanvasLayer
## Inventory (Tab or I): a grid of stacked items with category tabs, a detail panel (icon, name,
## description, value, stack count) and actions: use (eat, drink, apply...), drop, inspect (a
## rotating 3D view) and putting weapons on the hotbar. The game pauses and the mouse is freed
## while it is open; Tab, I or Esc close it. Also owns the ItemIcons renderer.

const CLICK_SOUND := preload("res://assets/audio/ui_click.wav")
const DENY_SOUND := preload("res://assets/audio/ui_deny.wav")
const DROP_SOUND := preload("res://assets/audio/item_drop.wav")
const COLUMNS := 6

## Tab title -> categories it shows (empty = everything).
const TABS := [
	["ALL", []],
	["WEAPONS", [&"weapon"]],
	["AMMO", [&"ammo"]],
	["FOOD & DRINK", [&"food", &"drink"]],
	["MEDICAL", [&"medical"]],
	["CLOTHING", [&"clothing"]],
	["JUNK", [&"junk"]],
	["VALUABLES", [&"valuable", &"cyberware"]],
	["KEY ITEMS", [&"key"]],
]

var _backdrop: ColorRect
var _panel: PanelContainer
var _header: Label
var _tab_buttons: Array[Button] = []
var _grid: GridContainer
var _slots: Array[ItemSlot] = []
var _icon: TextureRect
var _inspect: SubViewportContainer
var _inspect_pivot: Node3D
var _name: Label
var _meta: Label
var _description: Label
var _use_button: Button
var _drop_button: Button
var _drop_stack_button: Button
var _inspect_button: Button
var _hotbar_row: HBoxContainer
var _hotbar_buttons: Array[Button] = []
var _audio: AudioStreamPlayer

var _tab := 0
## The selected stack: its item and its index among that item's stacks.
var _selected := &""
var _selected_stack := 0
var _inspecting := false


func _ready() -> void:
	add_to_group("inventory_screen")
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio = AudioStreamPlayer.new()
	_audio.bus = &"UI"
	add_child(_audio)
	add_child(ItemIcons.new())
	_build()
	_panel.visible = false
	_backdrop.visible = false
	GameState.inventory.changed.connect(_on_inventory_changed)


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	if is_open() or not GameState.is_free_roaming():
		return
	GameState.claim_ui(&"inventory")
	get_tree().paused = true
	_panel.visible = true
	_backdrop.visible = true
	_set_inspecting(false)
	_refresh()


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	_backdrop.visible = false
	_set_inspecting(false)
	get_tree().paused = false
	GameState.release_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if is_open():
			close()
			get_viewport().set_input_as_handled()
		elif GameState.is_free_roaming():
			open()
			get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("toggle_mouse_capture"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _inspecting and _inspect_pivot:
		_inspect_pivot.rotation.y += delta * 0.9


func _on_inventory_changed() -> void:
	if is_open():
		_refresh()


# --- Contents ----------------------------------------------------------------------------------

func _refresh() -> void:
	var bag := GameState.inventory
	_header.text = "INVENTORY  //  %d / %d SLOTS        ¢ %d" % [bag.used_slots(), bag.capacity, GameState.credits]
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == _tab
	var shown := _visible_stacks()
	if _selected != &"" and bag.count(_selected) == 0:
		_selected = &""
		_set_inspecting(false)
	var holder := _holder()
	var seen := {}
	for i in _slots.size():
		var slot := _slots[i]
		if i < shown.size():
			var id: StringName = shown[i]["id"]
			var index: int = seen.get(id, 0)
			seen[id] = index + 1
			slot.set_item(id, shown[i]["count"])
			slot.set_meta(&"stack", index)
			slot.selected = id == _selected and index == _selected_stack
			var hotbar := holder.slots.find(id) if holder else -1
			slot.tag = str(hotbar + 1) if hotbar >= 0 else ""
		else:
			slot.set_item(&"", 0)
			slot.selected = false
			slot.tag = ""
	_update_detail()


## The stacks in the current tab, in grid order.
func _visible_stacks() -> Array[Dictionary]:
	var filter: Array = TABS[_tab][1]
	var result: Array[Dictionary] = []
	for stack in GameState.inventory.stacks():
		if filter.is_empty() or filter.has(ItemDB.category(stack["id"])):
			result.append(stack)
	return result


func _update_detail() -> void:
	var id := _selected
	var data := ItemDB.item(id)
	if data == null:
		_icon.texture = null
		_name.text = "Nothing selected"
		_meta.text = ""
		_description.text = "Click an item to see what it is. Double-click to use or equip it."
		for button: Button in [_use_button, _drop_button, _drop_stack_button, _inspect_button]:
			button.visible = false
		_hotbar_row.visible = false
		return
	var bag := GameState.inventory
	var color := ItemDB.color(id)
	_icon.texture = ItemIcons.icon(id)
	_name.text = data.display_name.to_upper()
	_name.label_settings.font_color = color.lerp(Color.WHITE, 0.45)
	var lines: Array[String] = []
	lines.append(ItemDB.category_name(id).to_upper())
	if data.sellable and data.price > 0:
		var unit := "%d ¢ each" % data.price
		lines.append("VALUE  %s  //  %d ¢ total" % [unit, data.price * bag.count(id)])
	else:
		lines.append("NOT FOR SALE")
	lines.append("CARRYING  %d   //   STACKS OF %d" % [bag.count(id), data.stack_size])
	if data.heal > 0.0:
		lines.append("HEALS  %d" % int(data.heal))
	if data.effect_label != "":
		lines.append("EFFECT  %s  (%d s)" % [data.effect_label, int(data.effect_duration)])
	if data.ammo != &"":
		lines.append("AMMO  %s  //  %d in reserve" % [ItemDB.display_name(data.ammo), bag.count(data.ammo)])
	_meta.text = "\n".join(lines)
	_description.text = data.inspect_text if _inspecting else data.description
	_use_button.visible = data.is_usable()
	_use_button.text = data.use_verb.to_upper() + "  [DOUBLE-CLICK]"
	var drop_amount := _drop_amount(id)
	_drop_button.visible = data.droppable
	_drop_button.text = "DROP %d" % drop_amount if drop_amount > 1 else "DROP"
	_drop_stack_button.visible = data.droppable and _stack_count() > drop_amount
	_drop_stack_button.text = "DROP STACK (%d)" % _stack_count()
	_inspect_button.visible = true
	_inspect_button.text = "BACK" if _inspecting else "INSPECT"
	_hotbar_row.visible = data.weapon_scene != null
	var holder := _holder()
	for i in _hotbar_buttons.size():
		var in_slot := holder != null and holder.slots[i] == id
		_hotbar_buttons[i].text = ("SLOT %d  ✓" if in_slot else "SLOT %d") % (i + 1)
		_hotbar_buttons[i].disabled = in_slot


## Units in the selected stack.
func _stack_count() -> int:
	var count := GameState.inventory.count(_selected)
	var stack := ItemDB.stack_size(_selected)
	var full_stacks := count / stack
	return stack if _selected_stack < full_stacks else count - full_stacks * stack


## One unit, or one box for ammo.
func _drop_amount(id: StringName) -> int:
	return mini(ItemDB.pack_size(id), GameState.inventory.count(id))


# --- Actions -----------------------------------------------------------------------------------

func _on_slot_clicked(slot: ItemSlot) -> void:
	_selected = slot.item_id
	_selected_stack = slot.get_meta(&"stack", 0)
	_set_inspecting(false)
	_play(CLICK_SOUND)
	_refresh()


func _on_slot_double_clicked(slot: ItemSlot) -> void:
	_on_slot_clicked(slot)
	var data := ItemDB.item(slot.item_id)
	if data and data.is_usable():
		_on_use()
	elif data and data.weapon_scene:
		var holder := _holder()
		if holder:
			var slot_index := holder.slots.find(data.id)
			if slot_index < 0:
				holder.assign(data.id, 0)
				slot_index = 0
			holder.select_slot(slot_index)
			get_tree().call_group("hud", "notify_item", "Equipped " + data.display_name, Palette.CYAN)
			_refresh()


func _on_use() -> void:
	var id := _selected
	var line := GameState.use_item(id)
	if line == "":
		_play(DENY_SOUND)
		return
	_play(GameState.use_sound(id))
	get_tree().call_group("hud", "notify_item", line, ItemDB.color(id))


func _on_drop(whole_stack: bool) -> void:
	var id := _selected
	var amount := _stack_count() if whole_stack else _drop_amount(id)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or amount <= 0 or not GameState.inventory.remove(id, amount):
		_play(DENY_SOUND)
		return
	var spot := _drop_spot(player)
	Pickup.spawn(player.get_parent(), spot, id, amount, 600.0)
	_play(DROP_SOUND)
	get_tree().call_group("hud", "notify_item", "- %d x %s" % [amount, ItemDB.display_name(id)] if amount > 1 else "- " + ItemDB.display_name(id), Color(0.7, 0.7, 0.8))


## A spot on the floor about a metre in front of the player (closer if a wall is in the way).
func _drop_spot(player: Player) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var forward := -player.global_basis.z
	var eye := player.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(eye, eye + forward * 1.1, 1 | 8)
	query.exclude = [player.get_rid()]
	var hit := space.intersect_ray(query)
	var ahead: Vector3 = hit["position"] - forward * 0.3 if not hit.is_empty() else eye + forward * 1.1
	var down := PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 3.0, 1 | 8)
	var floor_hit := space.intersect_ray(down)
	return floor_hit["position"] if not floor_hit.is_empty() else player.global_position


func _on_inspect() -> void:
	_set_inspecting(not _inspecting)
	_play(CLICK_SOUND)
	_update_detail()


func _on_assign(slot: int) -> void:
	var holder := _holder()
	if holder and _selected != &"":
		holder.assign(_selected, slot)
		_play(CLICK_SOUND)
		_refresh()


func _set_inspecting(on: bool) -> void:
	_inspecting = on and _selected != &""
	_inspect.visible = _inspecting
	_icon.visible = not _inspecting
	for child in _inspect_pivot.get_children():
		child.queue_free()
	if _inspecting:
		var model := ItemModels.build(_selected)
		var box := model.mesh.get_aabb()
		var fit := 0.62 / maxf(box.get_longest_axis_size(), 0.01)
		model.scale = Vector3.ONE * fit
		model.position = -box.get_center() * fit
		_inspect_pivot.add_child(model)
		_inspect_pivot.rotation = Vector3(0.35, 0.0, 0.0)


func _on_tab(index: int) -> void:
	_tab = index
	_play(CLICK_SOUND)
	_refresh()


func _holder() -> WeaponHolder:
	var player := get_tree().get_first_node_in_group("player") as Player
	return player.weapon_holder if player else null


func _play(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.play()


# --- Layout ------------------------------------------------------------------------------------

func _build() -> void:
	var accent := Palette.LIME
	# Dims the game and the HUD behind the menu.
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.01, 0.0, 0.03, 0.6)
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel(accent))
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -560
	_panel.offset_top = -320
	_panel.offset_right = 560
	_panel.offset_bottom = 320
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_header = UiStyle.label("", 22, Color.WHITE, Palette.LIME.darkened(0.3))
	column.add_child(_header)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	for i in TABS.size():
		var button := Button.new()
		button.text = TABS[i][0]
		button.toggle_mode = true
		UiStyle.style_button(button, Palette.CYAN, 14)
		button.pressed.connect(_on_tab.bind(i))
		tabs.add_child(button)
		_tab_buttons.append(button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	body.add_child(_grid)
	for i in GameState.INVENTORY_SLOTS:
		var slot := ItemSlot.new()
		slot.clicked.connect(_on_slot_clicked)
		slot.double_clicked.connect(_on_slot_double_clicked)
		_grid.add_child(slot)
		_slots.append(slot)

	body.add_child(_build_detail())

	var footer := HBoxContainer.new()
	column.add_child(footer)
	var hint := UiStyle.label("Click an item for details. Double-click to eat, drink, use or equip.   TAB / I / ESC close", 13, Color(0.6, 0.6, 0.7), Color.BLACK)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	var leave := Button.new()
	leave.text = "[TAB] CLOSE"
	UiStyle.style_button(leave, Palette.PINK)
	leave.pressed.connect(close)
	footer.add_child(leave)


func _build_detail() -> Control:
	var detail := PanelContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_stylebox_override("panel", UiStyle.panel(Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.4), Color(0, 0, 0, 0.35)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	detail.add_child(column)

	var picture := Control.new()
	picture.custom_minimum_size = Vector2(0, 170)
	column.add_child(picture)
	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.add_child(_icon)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inspect = _build_inspect_view()
	picture.add_child(_inspect)
	_inspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_name = UiStyle.label("", 22, Color.WHITE, Palette.PINK.darkened(0.5))
	column.add_child(_name)
	_meta = UiStyle.label("", 14, Palette.AMBER, Palette.AMBER.darkened(0.75))
	column.add_child(_meta)
	_description = UiStyle.label("", 16, Color(0.85, 0.9, 1.0), Color(0.05, 0.02, 0.12))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(0, 44)
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_description)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	_use_button = _action_button(actions, Palette.LIME, _on_use)
	_drop_button = _action_button(actions, Palette.AMBER, _on_drop.bind(false))
	_drop_stack_button = _action_button(actions, Palette.AMBER, _on_drop.bind(true))
	_inspect_button = _action_button(actions, Palette.CYAN, _on_inspect)

	_hotbar_row = HBoxContainer.new()
	_hotbar_row.add_theme_constant_override("separation", 8)
	column.add_child(_hotbar_row)
	_hotbar_row.add_child(UiStyle.label("HOTBAR", 14, Palette.CYAN, Palette.CYAN.darkened(0.7)))
	for i in WeaponHolder.SLOT_COUNT:
		_hotbar_buttons.append(_action_button(_hotbar_row, Palette.CYAN, _on_assign.bind(i)))
	return detail


func _action_button(parent: Control, color: Color, action: Callable) -> Button:
	var button := Button.new()
	UiStyle.style_button(button, color, 15)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## A little 3D stage for inspecting an item: the model turns slowly under two lights.
func _build_inspect_view() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = 2
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.visible = false
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	container.add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.45, 0.65)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(-30.0), 0.0)
	key.light_energy = 1.5
	viewport.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.8, 0.4, -0.6)
	rim.light_color = Palette.PINK
	rim.light_energy = 2.0
	viewport.add_child(rim)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.05, 1.35)
	camera.fov = 32.0
	viewport.add_child(camera)
	_inspect_pivot = Node3D.new()
	viewport.add_child(_inspect_pivot)
	return container
