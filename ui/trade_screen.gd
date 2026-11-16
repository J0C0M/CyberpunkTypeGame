extends CanvasLayer
## Buy/sell screen: the player's inventory and the merchant's stock side by side with prices and
## both sides' credits. The game pauses and the mouse is freed while it is open; Esc leaves.
## Opened through the "trade_screen" group: call_group("trade_screen", "open_for", merchant).

const CASH_SOUND := preload("res://assets/audio/trade_cash.wav")
const CLICK_SOUND := preload("res://assets/audio/ui_click.wav")
const DENY_SOUND := preload("res://assets/audio/ui_deny.wav")

var _merchant: Merchant
var _panel: PanelContainer
var _title: Label
var _mood: Label
var _player_header: Label
var _merchant_header: Label
var _player_list: ItemList
var _merchant_list: ItemList
var _detail: Label
var _speech: Label
var _deal_button: Button
var _player_ids: Array[StringName] = []
var _merchant_ids: Array[StringName] = []
## The item being looked at and whether the player would be buying it.
var _selected := &""
var _buying := true
var _audio: AudioStreamPlayer


func _ready() -> void:
	add_to_group("trade_screen")
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open_for(merchant: Merchant) -> void:
	if is_open() or merchant == null:
		return
	_merchant = merchant
	GameState.claim_ui(&"trade")
	get_tree().paused = true
	_panel.visible = true
	_selected = &""
	_title.text = "%s  //  %s" % [merchant.shop_name.to_upper(), merchant.display_name.to_upper()]
	_say(merchant.greeting)
	_refresh()


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	get_tree().paused = false
	GameState.release_ui()
	_merchant = null


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("toggle_mouse_capture"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_mood.text = "MOOD: %s   REP: %+.2f" % [_merchant.mood_text().to_upper(), _merchant.reputation()]
	_player_header.text = "YOUR STUFF        ¢ %d" % GameState.credits
	_merchant_header.text = "%s'S STOCK        ¢ %d" % [_merchant.display_name.to_upper(), _merchant.cash]
	_player_ids = GameState.inventory.ids()
	_merchant_ids = _merchant.stock.ids()
	_fill(_player_list, _player_ids, GameState.inventory, false)
	_fill(_merchant_list, _merchant_ids, _merchant.stock, true)
	_update_detail()


func _fill(list: ItemList, ids: Array[StringName], bag: Inventory, buying: bool) -> void:
	list.clear()
	for id in ids:
		var pack := ItemDB.pack_size(id)
		var price := _merchant.sell_price(id) if buying else _merchant.buy_price(id)
		var title := ItemDB.display_name(id) + (" (%d)" % pack if pack > 1 else "")
		var index := list.add_item("%-24s x%-4d %5d ¢" % [title, bag.count(id), price])
		list.set_item_custom_fg_color(index, ItemDB.color(id).lerp(Color.WHITE, 0.35))
		if id == _selected and buying == _buying:
			list.select(index)


func _on_player_item(index: int) -> void:
	_merchant_list.deselect_all()
	_select(_player_ids[index], false)


func _on_merchant_item(index: int) -> void:
	_player_list.deselect_all()
	_select(_merchant_ids[index], true)


func _select(id: StringName, buying: bool) -> void:
	_selected = id
	_buying = buying
	_play(CLICK_SOUND)
	_update_detail()


func _update_detail() -> void:
	if _selected == &"":
		_detail.text = "Pick something on either side."
		_deal_button.disabled = true
		_deal_button.text = "DEAL"
		return
	var pack := ItemDB.pack_size(_selected)
	var unit := " for a box of %d" % pack if pack > 1 else ""
	var price := current_price()
	_detail.text = "%s — %s\n%s %d ¢%s" % [ItemDB.display_name(_selected), ItemDB.description(_selected), "Asking" if _buying else "Offers you", price, unit]
	_deal_button.disabled = false
	_deal_button.text = ("BUY FOR %d ¢" if _buying else "SELL FOR %d ¢") % price


## The merchant's current price for the selected item.
func current_price() -> int:
	return _merchant.sell_price(_selected) if _buying else _merchant.buy_price(_selected)


func _on_deal() -> void:
	_complete(current_price())


func _complete(price: int) -> void:
	var problem := _merchant.sell_to_player(_selected, price) if _buying else _merchant.buy_from_player(_selected, price)
	if problem != "":
		_say(problem)
		_play(DENY_SOUND)
	else:
		_say(["Pleasure.", "Done.", "Good doing business.", "Come back soon."].pick_random())
		_play(CASH_SOUND)
	_refresh()


func _say(line: String) -> void:
	_speech.text = "%s: \"%s\"" % [_merchant.display_name, line]


func _play(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.play()


# --- Layout -----------------------------------------------------------------------------------

func _build() -> void:
	var accent := Palette.CYAN
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel(accent))
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(1060, 600)
	_panel.offset_left = -530
	_panel.offset_top = -300
	_panel.offset_right = 530
	_panel.offset_bottom = 300
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_title = UiStyle.label("", 22, Color.WHITE, Palette.PINK)
	header.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_mood = UiStyle.label("", 15, Palette.AMBER, Palette.AMBER.darkened(0.7))
	header.add_child(_mood)

	var lists := HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists.add_theme_constant_override("separation", 16)
	column.add_child(lists)
	var left := _list_column(lists, Palette.LIME)
	_player_header = left[0]
	_player_list = left[1]
	_player_list.item_selected.connect(_on_player_item)
	var right := _list_column(lists, Palette.AMBER)
	_merchant_header = right[0]
	_merchant_list = right[1]
	_merchant_list.item_selected.connect(_on_merchant_item)

	_detail = UiStyle.label("", 16, Color(0.85, 0.9, 1.0), Color(0.05, 0.02, 0.12))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 48)
	column.add_child(_detail)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	_build_actions(actions)

	_speech = UiStyle.label("", 17, Palette.CYAN.lerp(Color.WHITE, 0.4), Palette.CYAN.darkened(0.6))
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.custom_minimum_size = Vector2(0, 26)
	column.add_child(_speech)

	var footer := HBoxContainer.new()
	column.add_child(footer)
	var hint := UiStyle.label("Click an item on either side.", 13, Color(0.6, 0.6, 0.7), Color.BLACK)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	var leave := Button.new()
	leave.text = "[ESC] LEAVE"
	UiStyle.style_button(leave, Palette.PINK)
	leave.pressed.connect(close)
	footer.add_child(leave)


## The row of deal controls under the lists.
func _build_actions(row: HBoxContainer) -> void:
	_deal_button = Button.new()
	_deal_button.text = "DEAL"
	UiStyle.style_button(_deal_button, Palette.LIME, 17)
	_deal_button.pressed.connect(_on_deal)
	row.add_child(_deal_button)


func _list_column(parent: Control, color: Color) -> Array:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var header := UiStyle.label("", 17, color, color.darkened(0.7))
	column.add_child(header)
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(0, 250)
	UiStyle.style_list(list, color)
	column.add_child(list)
	return [header, list]
