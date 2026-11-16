extends CanvasLayer
## Conversation box at the bottom of the screen: speaker, text that types itself out and
## numbered choices (click or press 1-8). Driven by a dialogue tree (see GuideDialogue);
## node and choice actions are passed to the speaker's handle_dialogue(action).
## Opened through the "dialogue_screen" group: call_group("dialogue_screen", "open_dialogue", ...).

const CLICK_SOUND := preload("res://assets/audio/ui_click.wav")
const CHARACTERS_PER_SECOND := 55.0

var _tree: Dictionary
var _speaker: Object
var _node: Dictionary
var _panel: PanelContainer
var _name: Label
var _text: Label
var _choices: VBoxContainer
var _typing := 0.0
var _audio: AudioStreamPlayer


func _ready() -> void:
	add_to_group("dialogue_screen")
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio = AudioStreamPlayer.new()
	_audio.stream = CLICK_SOUND
	_audio.bus = &"UI"
	add_child(_audio)
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


## Starts a conversation with `speaker` (who handles actions) at node `start` of `tree`.
func open_dialogue(speaker_name: String, tree: Dictionary, start: StringName, speaker: Object) -> void:
	_tree = tree
	_speaker = speaker
	_name.text = speaker_name.to_upper()
	_panel.visible = true
	GameState.claim_ui(&"dialogue")
	_show_node(start)


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	if GameState.ui_mode == &"dialogue":
		GameState.release_ui()


func _process(delta: float) -> void:
	if is_open() and _text.visible_ratio < 1.0:
		_typing += delta * CHARACTERS_PER_SECOND
		_text.visible_characters = int(_typing)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("toggle_mouse_capture"):
		close()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key <= KEY_8:
			_pick(key - KEY_1)
		elif key == KEY_SPACE:
			_text.visible_characters = -1
	else:
		return
	get_viewport().set_input_as_handled()


func _show_node(id: StringName) -> void:
	if id == &"" or not _tree.has(id):
		close()
		return
	_node = _tree[id]
	if _node.has("action"):
		_run(_node["action"])
		if not is_open():
			return
	var text: Variant = _node["text"]
	_text.text = text.pick_random() if text is Array else text
	_text.visible_characters = 0
	_typing = 0.0
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
	var index := 0
	for choice in _visible_choices():
		var button := Button.new()
		button.text = "%d. %s" % [index + 1, choice["text"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiStyle.style_button(button, Palette.CYAN, 16)
		button.pressed.connect(_pick.bind(index))
		_choices.add_child(button)
		index += 1


## The current node's choices whose "if" condition (if any) holds.
func _visible_choices() -> Array:
	var result := []
	for choice in _node.get("choices", []):
		if not choice.has("if") or (_speaker and _speaker.has_method("dialogue_condition") and _speaker.dialogue_condition(choice["if"])):
			result.append(choice)
	return result


func _pick(index: int) -> void:
	var choices := _visible_choices()
	if index >= choices.size():
		return
	_audio.play()
	var choice: Dictionary = choices[index]
	var next: StringName = choice.get("next", &"")
	if choice.has("action"):
		_run(choice["action"])
	if is_open():
		_show_node(next)


func _run(action: String) -> void:
	if _speaker and _speaker.has_method("handle_dialogue"):
		_speaker.handle_dialogue(action)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.panel(Palette.PINK))
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -500
	_panel.offset_right = 500
	_panel.offset_top = -330
	_panel.offset_bottom = -30
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	_name = UiStyle.label("", 20, Palette.PINK.lerp(Color.WHITE, 0.3), Palette.PINK.darkened(0.5))
	column.add_child(_name)
	_text = UiStyle.label("", 18, Color(0.92, 0.94, 1.0), Color(0.08, 0.02, 0.12))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(0, 80)
	column.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 4)
	column.add_child(_choices)
	var hint := UiStyle.label("1-8 or click to answer   SPACE skip   ESC leave", 12, Color(0.55, 0.55, 0.65), Color.BLACK)
	column.add_child(hint)
