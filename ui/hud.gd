extends CanvasLayer
## Minimal neon HUD: crosshair, ammo counter with a bullet bar and reload progress, a controls
## hint that fades out, short messages (call_group("hud", "show_message", text)) and a
## "click to play" overlay while the mouse is free.

const HINT_TEXT := "WASD move   SHIFT sprint   SPACE jump   LMB fire   R reload   E interact\nESC free mouse   F2 vertex wobble   F3 retro filter"
const HINT_DURATION := 12.0

var _rifle: Rifle
var _font: Font
var _crosshair: Crosshair
var _ammo_label: Label
var _reserve_label: Label
var _ammo_bar: AmmoBar
var _reload_label: Label
var _hint: Label
var _message: Label
var _message_time := 0.0
var _overlay: Control
var _prompt: Label
var _credits: Label
var _waypoint: WaypointMarker
var _fade: ColorRect
var _player: Player
var _elapsed := 0.0


func _ready() -> void:
	add_to_group("hud")
	# Keep updating while menus pause the game, so prompts and the crosshair hide properly.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = _make_font()
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_crosshair(root)
	_build_ammo_panel(root)
	_build_texts(root)
	_waypoint = WaypointMarker.new()
	_waypoint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_waypoint)
	_waypoint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_overlay(root)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var player := get_tree().get_first_node_in_group("player") as Player
	_player = player
	if player:
		_waypoint.camera = player.camera
	if player and player.weapon:
		_rifle = player.weapon
		_rifle.ammo_changed.connect(_on_ammo_changed)
		_rifle.reload_started.connect(_on_reload_started)
		_rifle.reload_finished.connect(_on_reload_finished)
		_ammo_bar.capacity = _rifle.magazine_size
		_on_ammo_changed(_rifle.ammo_in_magazine, _rifle.reserve_ammo)


func _process(delta: float) -> void:
	_elapsed += delta
	var screen := get_parent().get_node_or_null("RetroScreen") as SubViewportContainer
	if screen:
		var viewport := screen.get_child(0) as SubViewport
		_waypoint.viewport_scale = screen.size / Vector2(viewport.size)
	if _rifle:
		_crosshair.spread = _rifle.get_spread()
		if _rifle.is_reloading:
			_ammo_bar.reload_progress = _rifle.get_reload_progress()
			_reload_label.modulate.a = 0.55 + 0.45 * sin(_elapsed * 10.0)
	_hint.modulate.a = clampf((HINT_DURATION - _elapsed) / 2.0, 0.0, 1.0)
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time / 0.6, 0.0, 1.0)
	var free_mouse := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().has_meta("screenshot_mode")
	_overlay.visible = free_mouse and GameState.is_free_roaming()
	_crosshair.visible = not free_mouse and GameState.is_free_roaming()
	var focus := _player.focused_interactable if _player else null
	_prompt.visible = focus != null and _crosshair.visible
	if _prompt.visible:
		_prompt.text = "[E] " + focus.get_prompt()


## Fades the whole screen to black (alpha 1) or back (alpha 0). Await the returned tween.
func fade_to(alpha: float, seconds: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	return tween


func show_message(text: String, duration := 2.0) -> void:
	_message.text = text
	_message_time = duration
	_message.modulate.a = 1.0


func _on_ammo_changed(in_magazine: int, reserve: int) -> void:
	_ammo_label.text = "%02d" % in_magazine
	_reserve_label.text = "/ %03d" % reserve
	_ammo_bar.count = in_magazine
	var low := in_magazine <= _ammo_bar.capacity / 5.0
	_ammo_label.label_settings.font_color = Palette.RED if low else Color.WHITE


func _on_reload_started(_duration: float) -> void:
	_reload_label.visible = true


func _on_reload_finished() -> void:
	_reload_label.visible = false
	_ammo_bar.reload_progress = -1.0


func _build_crosshair(root: Control) -> void:
	_crosshair = Crosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crosshair)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -40
	_crosshair.offset_top = -40
	_crosshair.offset_right = 40
	_crosshair.offset_bottom = 40


func _build_ammo_panel(root: Control) -> void:
	var panel := Control.new()
	panel.name = "AmmoPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -300
	panel.offset_top = -132
	panel.offset_right = -36
	panel.offset_bottom = -30

	var weapon_name := _label("KS-47  //  AUTO", 15, Palette.CYAN, Palette.CYAN.darkened(0.6))
	panel.add_child(weapon_name)
	weapon_name.position = Vector2(0, 0)
	weapon_name.size = Vector2(264, 20)
	weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_ammo_label = _label("30", 52, Color.WHITE, Palette.PINK)
	panel.add_child(_ammo_label)
	_ammo_label.position = Vector2(60, 14)
	_ammo_label.size = Vector2(110, 60)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_reserve_label = _label("/ 210", 22, Color(0.75, 0.85, 1.0), Color(0.1, 0.1, 0.3))
	panel.add_child(_reserve_label)
	_reserve_label.position = Vector2(176, 40)
	_reserve_label.size = Vector2(88, 30)

	_ammo_bar = AmmoBar.new()
	_ammo_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_ammo_bar)
	_ammo_bar.position = Vector2(24, 84)
	_ammo_bar.size = Vector2(240, 10)

	_reload_label = _label("RELOADING", 16, Palette.AMBER, Palette.AMBER.darkened(0.7))
	panel.add_child(_reload_label)
	_reload_label.position = Vector2(24, -26)
	_reload_label.size = Vector2(240, 22)
	_reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reload_label.visible = false


func _build_texts(root: Control) -> void:
	_hint = _label(HINT_TEXT, 15, Color(0.85, 0.9, 1.0), Color(0.05, 0.02, 0.12))
	root.add_child(_hint)
	_hint.position = Vector2(28, 22)

	var location := _label("NEO-KABUKICHO  //  BLOCK 7  //  23:47", 14, Palette.PINK, Palette.PINK.darkened(0.7))
	root.add_child(location)
	location.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	location.offset_left = -420
	location.offset_right = -28
	location.offset_top = 22
	location.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_credits = _label("¢ 0", 22, Palette.AMBER, Palette.AMBER.darkened(0.7))
	root.add_child(_credits)
	_credits.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_credits.offset_left = -300
	_credits.offset_right = -28
	_credits.offset_top = 44
	_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GameState.credits_changed.connect(func(amount: int) -> void: _credits.text = "¢ %d" % amount)
	_credits.text = "¢ %d" % GameState.credits

	_prompt = _label("", 20, Color.WHITE, Palette.CYAN.darkened(0.4))
	root.add_child(_prompt)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = 34
	_prompt.offset_bottom = 64
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false

	_message = _label("", 24, Palette.LIME, Palette.LIME.darkened(0.7))
	root.add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message.offset_left = -300
	_message.offset_right = 300
	_message.offset_top = -210
	_message.offset_bottom = -170
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0


func _build_overlay(root: Control) -> void:
	_overlay = ColorRect.new()
	(_overlay as ColorRect).color = Color(0.02, 0.0, 0.05, 0.55)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := _label("CLICK TO PLAY", 46, Color.WHITE, Palette.PINK)
	_overlay.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.offset_left = -400
	title.offset_right = 400
	title.offset_top = -70
	title.offset_bottom = -10
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := _label(HINT_TEXT, 16, Color(0.8, 0.9, 1.0), Color(0.05, 0.02, 0.12))
	_overlay.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	controls.offset_left = -400
	controls.offset_right = 400
	controls.offset_top = 10
	controls.offset_bottom = 70
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.visible = false


func _label(text: String, font_size: int, color: Color, glow: Color) -> Label:
	var settings := LabelSettings.new()
	settings.font = _font
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = maxi(3, font_size / 8)
	settings.outline_color = glow
	settings.shadow_size = 6
	settings.shadow_color = Color(glow.r, glow.g, glow.b, 0.35)
	settings.shadow_offset = Vector2.ZERO
	var label := Label.new()
	label.text = text
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["JetBrains Mono", "DejaVu Sans Mono", "Liberation Mono", "Noto Sans Mono", "monospace"])
	font.font_weight = 700
	return font
