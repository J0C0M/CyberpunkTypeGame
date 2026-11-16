class_name ItemSlot
extends Control
## One square in the inventory grid: the item's icon, a frame in its category colour and the
## stack count. Empty slots are drawn dimmed. Click to select, double-click to use.

signal clicked(slot: ItemSlot)
signal double_clicked(slot: ItemSlot)

var item_id := &""
var count := 0
var selected := false:
	set(value):
		selected = value
		queue_redraw()
## Small tag in the top-left corner (the hotbar number of an equipped weapon).
var tag := ""

var _hover := false


func _ready() -> void:
	custom_minimum_size = Vector2(76, 76)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _set_hover(hover: bool) -> void:
	_hover = hover
	queue_redraw()


func set_item(id: StringName, amount: int) -> void:
	item_id = id
	count = amount
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and item_id != &"":
		if click.double_click:
			double_clicked.emit(self)
		else:
			clicked.emit(self)
		accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var color := ItemDB.color(item_id) if item_id != &"" else Color(0.4, 0.4, 0.5)
	var fill := Color(color.r, color.g, color.b, 0.16 if selected else (0.1 if _hover else 0.05))
	draw_rect(rect, Color(0.02, 0.0, 0.05, 0.7))
	draw_rect(rect, fill)
	var border := color if selected else Color(color.r, color.g, color.b, 0.55 if _hover else 0.3)
	draw_rect(rect.grow(-1.0), border, false, 2.0 if selected else 1.0)
	if item_id == &"":
		return
	var icon := ItemIcons.icon(item_id)
	var side := minf(size.x, size.y) - 8.0
	draw_texture_rect(icon, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)), false)
	var font := UiStyle.font()
	if count > 1:
		var text := str(count)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var at := Vector2(size.x - width - 6.0, size.y - 6.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.9))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	if tag != "":
		draw_string_outline(font, Vector2(5, 16), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(5, 16), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.CYAN)
