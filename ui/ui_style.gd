class_name UiStyle
extends RefCounted
## Shared look for the menus (trade, dialogue): monospace text with a neon glow, dark translucent
## panels with a coloured border, matching the HUD.

static var _font: Font


static func font() -> Font:
	if _font == null:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["JetBrains Mono", "DejaVu Sans Mono", "Liberation Mono", "Noto Sans Mono", "monospace"])
		system.font_weight = 700
		_font = system
	return _font


static func label(text: String, size: int, color: Color, glow: Color) -> Label:
	var settings := LabelSettings.new()
	settings.font = font()
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = maxi(2, size / 9)
	settings.outline_color = glow
	settings.shadow_size = 5
	settings.shadow_color = Color(glow.r, glow.g, glow.b, 0.3)
	settings.shadow_offset = Vector2.ZERO
	var result := Label.new()
	result.text = text
	result.label_settings = settings
	return result


static func panel(border: Color, fill := Color(0.03, 0.01, 0.06, 0.92)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_content_margin_all(14)
	box.shadow_color = Color(border.r, border.g, border.b, 0.25)
	box.shadow_size = 10
	return box


static func style_button(button: Button, color: Color, font_size := 16) -> void:
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.4))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(color.r, color.g, color.b, 0.08 if state == "normal" else (0.28 if state == "hover" else 0.18))
		box.border_color = color if state != "disabled" else Color(0.3, 0.3, 0.35)
		box.set_border_width_all(1 if state != "focus" else 2)
		box.set_content_margin_all(6)
		box.content_margin_left = 14
		box.content_margin_right = 14
		button.add_theme_stylebox_override(state, box)


static func style_list(list: ItemList, color: Color) -> void:
	list.add_theme_font_override("font", font())
	list.add_theme_font_size_override("font_size", 15)
	list.add_theme_stylebox_override("panel", panel(Color(color.r, color.g, color.b, 0.5), Color(0.0, 0.0, 0.0, 0.35)))
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color(color.r, color.g, color.b, 0.25)
	list.add_theme_stylebox_override("selected", selected)
	list.add_theme_stylebox_override("selected_focus", selected)
	list.add_theme_color_override("font_selected_color", Color.WHITE)
