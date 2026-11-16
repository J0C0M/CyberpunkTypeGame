extends CanvasLayer
## Minimal neon HUD: crosshair, ammo counter with a bullet bar and reload progress, the weapon
## hotbar, a controls hint that fades out, short messages (call_group("hud", "show_message",
## text)), an item feed ("+ Synth-Soda", call_group("hud", "notify_item", text, color)), running
## food/stim effects and a "click to play" overlay while the mouse is free.

const HINT_TEXT := "WASD move   SHIFT sprint   SPACE jump   LMB fire   R reload   E interact\nTAB/I inventory   1-3/wheel weapons   H heal   ESC pause/settings   F2 wobble   F3 retro filter"
const HINT_DURATION := 12.0
const FEED_LINES := 5
const FEED_TIME := 3.5

var _weapon: Firearm
var _holder: WeaponHolder
var _ammo_panel: Control
var _weapon_name: Label
var _hotbar: HBoxContainer
var _feed: VBoxContainer
var _effects: Label
var _health_bar: ProgressBar
var _health_label: Label
var _vignette: TextureRect
var _hurt_flash := 0.0
var _damage: DamageIndicator
var _flatline: Control
var _wanted: WantedStars
var _location: Label
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
	_build_damage_effects(root)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_flatline(root)

	_build_hotbar(root)
	_build_health(root)
	_wanted = WantedStars.new()
	_wanted.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_wanted)
	_wanted.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_wanted.offset_left = -170
	_wanted.offset_right = 170
	_wanted.offset_top = 64
	_wanted.offset_bottom = 92
	_wanted.stars = 0
	var police := get_tree().get_first_node_in_group("police") as PoliceDispatch
	if police:
		police.heat_changed.connect(func(_heat: float, count: int) -> void: _wanted.stars = count)
	_build_feed(root)
	GameState.effects_changed.connect(_update_effects)
	_update_effects()

	var player := get_tree().get_first_node_in_group("player") as Player
	_player = player
	if player:
		_waypoint.camera = player.camera
		_holder = player.weapon_holder
		_holder.weapon_changed.connect(_bind_weapon)
		_holder.slots_changed.connect(_refresh_hotbar)
		_bind_weapon(_holder.current)
		player.health_changed.connect(_on_health_changed)
		player.hurt.connect(_on_hurt)
		_on_health_changed(player.health.health, player.health.max_health)


## Follows the gun in hand: ammo, reload and name.
func _bind_weapon(weapon: Firearm) -> void:
	if _weapon:
		_weapon.ammo_changed.disconnect(_on_ammo_changed)
		_weapon.reload_started.disconnect(_on_reload_started)
		_weapon.reload_finished.disconnect(_on_reload_finished)
	_weapon = weapon
	_ammo_panel.visible = weapon != null
	_reload_label.visible = false
	_ammo_bar.reload_progress = -1.0
	if weapon:
		weapon.ammo_changed.connect(_on_ammo_changed)
		weapon.reload_started.connect(_on_reload_started)
		weapon.reload_finished.connect(_on_reload_finished)
		_weapon_name.text = "%s  //  %s" % [weapon.hud_name, weapon.fire_mode]
		_ammo_bar.capacity = weapon.magazine_size
		_on_ammo_changed(weapon.ammo_in_magazine, weapon.reserve_ammo)
		_reload_label.visible = weapon.is_reloading
	_refresh_hotbar()


func _process(delta: float) -> void:
	_elapsed += delta
	var screen := get_parent().get_node_or_null("RetroScreen") as SubViewportContainer
	if screen:
		var viewport := screen.get_child(0) as SubViewport
		_waypoint.viewport_scale = screen.size / Vector2(viewport.size)
	if _weapon:
		_crosshair.spread = _weapon.get_spread()
		if _weapon.is_reloading:
			_ammo_bar.reload_progress = _weapon.get_reload_progress()
			_reload_label.modulate.a = 0.55 + 0.45 * sin(_elapsed * 10.0)
	_hint.modulate.a = clampf((HINT_DURATION - _elapsed) / 2.0, 0.0, 1.0)
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time / 0.6, 0.0, 1.0)
	_update_vignette(delta)
	for line in _feed.get_children():
		var left: float = line.get_meta(&"time") - delta
		line.set_meta(&"time", left)
		line.modulate.a = clampf(left / 0.6, 0.0, 1.0)
		if left <= 0.0:
			line.queue_free()
	if not GameState.effects.is_empty() and Engine.get_process_frames() % 15 == 0:
		_update_effects()
	var free_mouse := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().has_meta("screenshot_mode")
	_overlay.visible = free_mouse and GameState.is_free_roaming()
	_crosshair.visible = not free_mouse and GameState.is_free_roaming()
	# A player whose physics is paused (screenshot tours, tests) doesn't update its focus.
	var focus := _player.focused_interactable if _player and _player.is_physics_processing() else null
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


## A line in the item feed (bottom left): pickups, drops, things used up.
func notify_item(text: String, color := Palette.LIME) -> void:
	var line := _label(text, 18, color.lerp(Color.WHITE, 0.3), color.darkened(0.6))
	line.set_meta(&"time", FEED_TIME)
	_feed.add_child(line)
	while _feed.get_child_count() > FEED_LINES:
		var oldest := _feed.get_child(0)
		_feed.remove_child(oldest)
		oldest.queue_free()


## The "FLATLINED" screen while the player is down.
func show_flatline(on: bool) -> void:
	_flatline.visible = on
	if on:
		_damage.clear()


func _on_health_changed(health: float, max_health: float) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_label.text = "%3d" % ceili(health)
	var low := health < max_health * 0.3
	_health_label.label_settings.font_color = Palette.RED if low else Color.WHITE


func _on_hurt(hit: HitInfo) -> void:
	_hurt_flash = minf(0.75, _hurt_flash + 0.25 + hit.damage / 40.0)
	var from := hit.position - hit.direction * 5.0
	if hit.source is Node3D and is_instance_valid(hit.source) and hit.source != _player:
		from = (hit.source as Node3D).global_position
	var local := _player.camera.global_basis.inverse() * (from - _player.global_position)
	_damage.add_hit(atan2(local.x, -local.z))


## Red edges after a hit, and a slow pulse while health is low.
func _update_vignette(delta: float) -> void:
	_hurt_flash = move_toward(_hurt_flash, 0.0, delta * 2.0)
	var low := 0.0
	if _player and not _player.is_dead and _player.health.health < _player.health.max_health * 0.3:
		low = 0.35 + 0.2 * sin(_elapsed * 5.0)
	_vignette.modulate.a = maxf(_hurt_flash, low)


func _update_effects() -> void:
	var parts: Array[String] = []
	for id in GameState.effects:
		var entry: Dictionary = GameState.effects[id]
		var left := int(ceilf(entry["time"]))
		parts.append("%s %d:%02d" % [entry["label"], left / 60, left % 60])
	_effects.text = "   ".join(parts)


func _refresh_hotbar() -> void:
	if _hotbar == null or _holder == null:
		return
	for child in _hotbar.get_children():
		child.queue_free()
	for i in WeaponHolder.SLOT_COUNT:
		var id := _holder.slots[i]
		var active := i == _holder.current_slot
		var color := Palette.CYAN if active else Color(0.55, 0.6, 0.75)
		var box := PanelContainer.new()
		var style := UiStyle.panel(Color(color.r, color.g, color.b, 0.9 if active else 0.35), Color(0.02, 0.0, 0.05, 0.55 if active else 0.3))
		style.set_content_margin_all(4)
		style.shadow_size = 6 if active else 0
		box.add_theme_stylebox_override("panel", style)
		box.custom_minimum_size = Vector2(118, 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var title := ItemDB.display_name(id).get_slice(" ", 0) if id != &"" else "-"
		var text := _label("%d  %s" % [i + 1, title], 14, Color.WHITE if active else color, color.darkened(0.6))
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(text)
		_hotbar.add_child(box)


func _on_clock_changed(text: String) -> void:
	_location.text = "NEO-KABUKICHO  //  BLOCK 7  //  " + text


func _on_credits_changed(amount: int) -> void:
	_credits.text = "¢ %d" % amount


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
	_ammo_panel = panel
	panel.name = "AmmoPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -300
	panel.offset_top = -132
	panel.offset_right = -36
	panel.offset_bottom = -30

	_weapon_name = _label("KS-47  //  AUTO", 15, Palette.CYAN, Palette.CYAN.darkened(0.6))
	panel.add_child(_weapon_name)
	_weapon_name.position = Vector2(0, 0)
	_weapon_name.size = Vector2(264, 20)
	_weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

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

	var location := _label("NEO-KABUKICHO  //  BLOCK 7  //  " + GameState.clock_text(), 14, Palette.PINK, Palette.PINK.darkened(0.7))
	_location = location
	# Methods, not lambdas: GameState outlives the HUD when the scene changes (menu <-> game), and
	# a method connection is dropped automatically when the HUD is freed.
	GameState.clock_changed.connect(_on_clock_changed)
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
	GameState.credits_changed.connect(_on_credits_changed)
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


func _build_hotbar(root: Control) -> void:
	_hotbar = HBoxContainer.new()
	_hotbar.name = "Hotbar"
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar.add_theme_constant_override("separation", 6)
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_hotbar)
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.offset_left = -200
	_hotbar.offset_right = 200
	_hotbar.offset_top = -62
	_hotbar.offset_bottom = -30


func _build_health(root: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "Health"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	row.offset_left = 28
	row.offset_right = 380
	row.offset_top = -62
	row.offset_bottom = -30
	row.add_child(_label("HP", 18, Palette.LIME, Palette.LIME.darkened(0.7)))
	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(220, 14)
	_health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.02, 0.0, 0.05, 0.6)
	back.border_color = Color(Palette.LIME.r, Palette.LIME.g, Palette.LIME.b, 0.5)
	back.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.LIME
	fill.shadow_color = Color(Palette.LIME.r, Palette.LIME.g, Palette.LIME.b, 0.4)
	fill.shadow_size = 4
	_health_bar.add_theme_stylebox_override("background", back)
	_health_bar.add_theme_stylebox_override("fill", fill)
	row.add_child(_health_bar)
	_health_label = _label("100", 20, Color.WHITE, Palette.LIME.darkened(0.6))
	row.add_child(_health_label)


func _build_damage_effects(root: Control) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.8, 0.0, 0.08, 0.0))
	gradient.set_color(1, Color(0.8, 0.0, 0.08, 0.6))
	gradient.add_point(0.68, Color(0.8, 0.0, 0.08, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.05, 0.5)
	texture.width = 256
	texture.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = texture
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	root.add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage = DamageIndicator.new()
	_damage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage)
	_damage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_flatline(root: Control) -> void:
	_flatline = VBoxContainer.new()
	_flatline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flatline.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_flatline)
	_flatline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := _label("FLATLINED", 64, Palette.RED, Palette.RED.darkened(0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flatline.add_child(title)
	var sub := _label("VITALS 0  //  PINGING CLINIC 24H ...", 18, Color(0.8, 0.85, 1.0), Color(0.1, 0.0, 0.1))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flatline.add_child(sub)
	_flatline.visible = false


func _build_feed(root: Control) -> void:
	_feed = VBoxContainer.new()
	_feed.name = "ItemFeed"
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(_feed)
	_feed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_feed.offset_left = 28
	_feed.offset_right = 520
	_feed.offset_top = -300
	_feed.offset_bottom = -94
	_effects = _label("", 15, Palette.AMBER, Palette.AMBER.darkened(0.7))
	root.add_child(_effects)
	_effects.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_effects.offset_left = 28
	_effects.offset_right = 700
	_effects.offset_top = -88
	_effects.offset_bottom = -64


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
