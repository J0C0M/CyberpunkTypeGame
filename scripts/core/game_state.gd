extends Node
## Player state that the whole game shares (autoload "GameState"): which UI currently owns the
## mouse and keyboard, credits and inventory, reputation with merchants, the clock and waypoints.

signal credits_changed(credits: int)
signal waypoint_changed
signal clock_changed(text: String)
## The player slept: time skipped ahead and the city was tidied up for a new night.
signal night_passed

## Game minutes per real second (one minute every four seconds). It is always night outside;
## the clock is just for flavour, sleeping and saving.
const CLOCK_RATE := 0.25

const STARTING_AMMO := 60

## Credits (¢), the city's currency.
var credits := 0
var inventory := Inventory.new()
## Standing with each merchant (merchant id -> -1..1). Good trades raise it, lowballing and
## violence lower it; merchants price and haggle with it.
var reputation := {}
## Named places the guide can mark: id -> {"label", "position"}. Registered by the buildings.
var places := {}
## Current HUD waypoint (an entry of `places`), or empty.
var waypoint := {}
## Story flags ("met_guide"...).
var flags := {}
## Minutes since midnight.
var clock_minutes := 23.0 * 60.0 + 47.0

## Empty while the player walks around; otherwise the name of whatever has taken over input
## ("trade", "dialogue", "seated"...). Main stops toggling the mouse and the player stops
## interacting while it is set.
var ui_mode := &""


func _ready() -> void:
	inventory.add(&"ammo_ks47", STARTING_AMMO)


func _process(delta: float) -> void:
	var before := int(clock_minutes)
	clock_minutes = fposmod(clock_minutes + delta * CLOCK_RATE, 1440.0)
	if int(clock_minutes) != before:
		clock_changed.emit(clock_text())


func clock_text() -> String:
	return "%02d:%02d" % [int(clock_minutes) / 60, int(clock_minutes) % 60]


## Sleeping: the clock jumps ahead and the city resets for a new night. Glass, props and cars are
## repaired ("resettable"), merchants come back and restock ("merchants"), bodies, loot, debris and
## bullet holes are cleared ("night_cleanup").
func pass_night(hours := 6.0) -> void:
	clock_minutes = fposmod(clock_minutes + hours * 60.0, 1440.0)
	clock_changed.emit(clock_text())
	get_tree().call_group("resettable", "reset")
	get_tree().call_group("merchants", "revive")
	get_tree().call_group("night_cleanup", "clear_for_new_night")
	night_passed.emit()


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


func reputation_with(merchant_id: StringName) -> float:
	return reputation.get(merchant_id, 0.0)


func change_reputation(merchant_id: StringName, amount: float) -> void:
	reputation[merchant_id] = clampf(reputation_with(merchant_id) + amount, -1.0, 1.0)


func register_place(id: StringName, label: String, position: Vector3) -> void:
	places[id] = {"label": label, "position": position}


## Shows a waypoint marker for a registered place on the HUD.
func set_waypoint(id: StringName) -> void:
	if places.has(id):
		waypoint = places[id]
		waypoint_changed.emit()


func clear_waypoint() -> void:
	waypoint = {}
	waypoint_changed.emit()


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
