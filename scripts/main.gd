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


func _input(event: InputEvent) -> void:
	# Mouse motion does not reliably cross the SubViewportContainer while the mouse is captured,
	# so mouse look is routed to the player from here.
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		get_tree().call_group("player", "look", (event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_mouse_capture"):
		set_mouse_captured(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# The click that grabs the mouse must not also fire the gun.
		set_mouse_captured(true)
		get_viewport().set_input_as_handled()


func set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
