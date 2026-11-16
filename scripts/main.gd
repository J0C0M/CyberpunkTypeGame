extends Node
## Game root. Owns mouse capture; the 3D world lives inside the low-res RetroScreen viewport.

const ScreenshotRunner := preload("res://scripts/debug/screenshot_runner.gd")


func _ready() -> void:
	var runner := ScreenshotRunner.from_cmdline()
	if runner:
		get_tree().set_meta("screenshot_mode", true)
		add_child(runner)
	else:
		set_mouse_captured(true)
	# Screenshot tours and tests start from a fresh game and never touch the player's save.
	if get_tree().has_meta("screenshot_mode"):
		SaveGame.enabled = false
	elif SaveGame.load_game():
		get_tree().call_group("hud", "show_message", "Welcome back.", 2.5)


func _input(event: InputEvent) -> void:
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
