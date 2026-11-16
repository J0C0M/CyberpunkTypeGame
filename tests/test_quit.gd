extends Node
## Quits the way the pause menu does (SaveGame.quit_game) after the world has been running a
## while, so the exit can be checked for leaked resources. Run windowed or headless:
## godot --path . res://tests/test_quit.tscn


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	add_child(load("res://scenes/main.tscn").instantiate())
	await get_tree().create_timer(4.0).timeout
	SaveGame.quit_game()
