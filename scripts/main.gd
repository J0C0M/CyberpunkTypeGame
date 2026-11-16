extends Node
## Game root. Owns mouse capture; the 3D world lives inside the low-res RetroScreen viewport.

const ScreenshotRunner := preload("res://scripts/debug/screenshot_runner.gd")
const ScreenshotTour := preload("res://scripts/debug/screenshot_tour.gd")


func _enter_tree() -> void:
	# The buildings register their areas again as they are built.
	GameState.areas.clear()


func _ready() -> void:
	var runner := ScreenshotRunner.from_cmdline()
	if runner == null:
		runner = ScreenshotTour.from_cmdline()
	if runner:
		get_tree().set_meta("screenshot_mode", true)
		add_child(runner)
	else:
		set_mouse_captured(true)
	if GameState.ui_mode == &"menu":
		GameState.release_ui()
	Music.play_menu(false)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_character"):
		player.apply_character(GameState.character)
	# Screenshot tours and tests start from a fresh game and never touch the player's saves.
	if get_tree().has_meta("screenshot_mode"):
		SaveGame.enabled = false
	elif SaveGame.apply_pending():
		get_tree().call_group("hud", "show_message", "Welcome back, %s." % GameState.character.character_name, 2.5)
	elif SaveGame.enabled and GameState.character.character_id != "":
		get_tree().call_group("hud", "show_message", "Welcome to Block 7, %s. Talk to Ren behind the counter." % GameState.character.character_name, 4.0)
	if GameState.portrait_png.is_empty() and not get_tree().has_meta("screenshot_mode"):
		_render_portrait()


## A headshot for the save slots until the player takes a photo booth picture.
func _render_portrait() -> void:
	var image := await CharacterPortrait.render(self, GameState.character)
	if image and GameState.portrait_png.is_empty():
		GameState.portrait_png = image.save_png_to_buffer()


func _input(event: InputEvent) -> void:
	# On the couch the mouse turns the head a little.
	if GameState.ui_mode == &"seated" and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		get_tree().call_group("seat", "look_around", (event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
		return
	# Menus, dialogue and seats own the mouse and Esc while they are open.
	if not GameState.is_free_roaming():
		return
	# Mouse motion does not reliably cross the SubViewportContainer while the mouse is captured,
	# so mouse look is routed to the player from here.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		get_tree().call_group("player", "look", (event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		# The wheel's press and release arrive in the same frame, too quick to poll; switch here.
		get_tree().call_group("player", "cycle_weapon", -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_mouse_capture"):
		get_tree().call_group("pause_menu", "open")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# The click that grabs the mouse must not also fire the gun.
		set_mouse_captured(true)
		get_viewport().set_input_as_handled()


func set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
