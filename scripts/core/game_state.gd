extends Node
## Player state that the whole game shares (autoload "GameState"): which UI currently owns the
## mouse and keyboard, and (see later sections) credits, inventory, reputation, clock, waypoints.

## Empty while the player walks around; otherwise the name of whatever has taken over input
## ("trade", "dialogue", "seated"...). Main stops toggling the mouse and the player stops
## interacting while it is set.
var ui_mode := &""


## Hands input to a UI (frees the mouse). Call release_ui() when it closes.
func claim_ui(mode: StringName, free_mouse := true) -> void:
	ui_mode = mode
	if free_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func release_ui() -> void:
	ui_mode = &""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_free_roaming() -> bool:
	return ui_mode == &""
