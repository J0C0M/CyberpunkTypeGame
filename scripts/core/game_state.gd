extends Node
## Player state that the whole game shares (autoload "GameState"): which UI currently owns the
## mouse and keyboard, credits and inventory, reputation with merchants, the clock and waypoints.

signal credits_changed(credits: int)

const STARTING_AMMO := 60

## Credits (¢), the city's currency.
var credits := 0
var inventory := Inventory.new()

## Empty while the player walks around; otherwise the name of whatever has taken over input
## ("trade", "dialogue", "seated"...). Main stops toggling the mouse and the player stops
## interacting while it is set.
var ui_mode := &""


func _ready() -> void:
	inventory.add(&"ammo_ks47", STARTING_AMMO)


func add_credits(amount: int) -> void:
	credits += amount
	credits_changed.emit(credits)


## Pays `amount` if the player has it; returns false otherwise.
func spend_credits(amount: int) -> bool:
	if amount > credits:
		return false
	credits -= amount
	credits_changed.emit(credits)
	return true


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
