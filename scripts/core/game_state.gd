extends Node
## Player state that the whole game shares (autoload "GameState"): which UI currently owns the
## mouse and keyboard, credits and inventory, reputation with merchants, the clock, waypoints and
## timed effects from food, drinks and stims. SaveGame writes and restores most of it.

signal credits_changed(credits: int)
signal waypoint_changed
signal clock_changed(text: String)
## The player slept: time skipped ahead and the city was tidied up for a new night.
signal night_passed
## A timed effect started, ran out or was refreshed.
signal effects_changed

## Game minutes per real second (one minute every four seconds). It is always night outside;
## the clock is just for flavour, sleeping and saving.
const CLOCK_RATE := 0.25

const STARTING_AMMO := 60
const INVENTORY_SLOTS := 30
const START_CLOCK := 23.0 * 60.0 + 47.0

const EAT_SOUND := preload("res://assets/audio/eat.wav")
const DRINK_SOUND := preload("res://assets/audio/drink.wav")
const PATCH_SOUND := preload("res://assets/audio/med_patch.wav")

## Credits (¢), the city's currency.
var credits := 0
var inventory := Inventory.new(INVENTORY_SLOTS)
## Standing with each merchant (merchant id -> -1..1). Good trades raise it, lowballing and
## violence lower it; merchants price and haggle with it.
var reputation := {}
## Named places the guide can mark: id -> {"label", "position"}. Registered by the buildings.
var places := {}
## Current HUD waypoint (an entry of `places`), or empty, and its place id.
var waypoint := {}
var waypoint_id := &""
## Story flags ("met_guide"...).
var flags := {}
## Minutes since midnight.
var clock_minutes := START_CLOCK
## Running effects: effect id -> {"time": seconds left, "strength": float, "label": HUD text}.
var effects := {}
## Police wanted stars (0-5), kept up to date by PoliceDispatch.
var wanted := 0
## Who the player is (look, name, outfit); set by the creator or loaded with a save slot.
var character := CharacterData.new()
## Seconds played with this character (shown on save slots).
var play_seconds := 0.0
## The character's portrait as PNG bytes (a photo booth shot, or a rendered headshot).
var portrait_png := PackedByteArray()
## Named areas for save-slot locations: [label, global transform, box size] (smallest first).
var areas: Array = []

## Empty while the player walks around; otherwise the name of whatever has taken over input
## ("trade", "dialogue", "seated"...). Main stops toggling the mouse and the player stops
## interacting while it is set.
var ui_mode := &""


func _ready() -> void:
	_give_starting_kit()


## Back to the very start (new game): no credits, the starting kit, nobody knows you.
func start_new_game() -> void:
	credits = 0
	credits_changed.emit(credits)
	inventory.clear()
	_give_starting_kit()
	reputation.clear()
	flags.clear()
	effects.clear()
	effects_changed.emit()
	clear_waypoint()
	clock_minutes = START_CLOCK
	clock_changed.emit(clock_text())
	play_seconds = 0.0
	wanted = 0


func _give_starting_kit() -> void:
	inventory.add(&"weapon_ks47", 1)
	inventory.add(&"ammo_ks47", STARTING_AMMO)
	for item in Outfits.items(character.outfit):
		inventory.add(item, 1)


func _process(delta: float) -> void:
	if ui_mode != &"menu":
		play_seconds += delta
	var before := int(clock_minutes)
	clock_minutes = fposmod(clock_minutes + delta * CLOCK_RATE, 1440.0)
	if int(clock_minutes) != before:
		clock_changed.emit(clock_text())
	_tick_effects(delta)


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


## Names an indoor area (a box around `xform`) for save-slot locations.
func register_area(label: String, xform: Transform3D, size: Vector3) -> void:
	areas.append([label, xform, size])
	areas.sort_custom(func(a: Array, b: Array) -> bool: return (a[2] as Vector3).length_squared() < (b[2] as Vector3).length_squared())


## Where `point` is, in words: an interior's name, a street, or the block.
func location_name(point: Vector3) -> String:
	for area in areas:
		var local: Vector3 = (area[1] as Transform3D).affine_inverse() * point
		var half: Vector3 = area[2] * 0.5
		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			return area[0]
	if absf(point.z) < 9.0:
		return "Kabuki Ave"
	if absf(point.x) < 9.0:
		return "Crow St"
	return "Block 7"


## Shows a waypoint marker for a registered place on the HUD.
func set_waypoint(id: StringName) -> void:
	if places.has(id):
		waypoint = places[id]
		waypoint_id = id
		waypoint_changed.emit()


func clear_waypoint() -> void:
	waypoint = {}
	waypoint_id = &""
	waypoint_changed.emit()


# --- Effects and using items ---------------------------------------------------------------

## Starts (or refreshes) a timed effect. Effects: sprint (faster sprinting, strength = bonus),
## steady (less spread, recoil and sway), tipsy (more sway), regen (health per second).
func apply_effect(id: StringName, strength: float, duration: float, label: String) -> void:
	var current: Dictionary = effects.get(id, {})
	effects[id] = {
		"time": maxf(duration, current.get("time", 0.0)),
		"strength": maxf(strength, current.get("strength", 0.0)),
		"label": label,
	}
	effects_changed.emit()


## Strength of a running effect, 0 when it isn't active.
func effect(id: StringName) -> float:
	return effects[id]["strength"] if effects.has(id) else 0.0


func _tick_effects(delta: float) -> void:
	if effects.is_empty():
		return
	var expired := false
	for id in effects.keys():
		effects[id]["time"] -= delta
		if effects[id]["time"] <= 0.0:
			effects.erase(id)
			expired = true
	if expired:
		effects_changed.emit()


## Uses one unit of `id` (eat, drink, apply...): takes it out of the inventory, heals and starts
## its effect. Returns a short line for the HUD, or "" if the item can't be used.
func use_item(id: StringName) -> String:
	var data := ItemDB.item(id)
	if data == null or not data.is_usable() or not inventory.remove(id, 1):
		return ""
	var player := get_tree().get_first_node_in_group("player")
	if data.heal > 0.0 and player and player.has_method("heal"):
		player.heal(data.heal)
	if data.effect != &"":
		apply_effect(data.effect, data.effect_strength, data.effect_duration, data.effect_label)
	var line := "%s: %s" % [data.use_verb, data.display_name]
	if data.effect_label != "":
		line += "  //  " + data.effect_label
	return line


## The sound for using an item (eating, drinking or a patch/injector).
func use_sound(id: StringName) -> AudioStream:
	var data := ItemDB.item(id)
	if data == null:
		return null
	match data.use_verb:
		"Eat":
			return EAT_SOUND
		"Drink":
			return DRINK_SOUND
	return PATCH_SOUND


# --- Saving --------------------------------------------------------------------------------

func save_data() -> Dictionary:
	var rep := {}
	for id in reputation:
		rep[String(id)] = reputation[id]
	return {
		"credits": credits,
		"inventory": inventory.to_dict(),
		"reputation": rep,
		"flags": flags.duplicate(),
		"clock": clock_minutes,
		"waypoint": String(waypoint_id),
	}


func load_data(data: Dictionary) -> void:
	credits = int(data.get("credits", 0))
	credits_changed.emit(credits)
	inventory.load_dict(data.get("inventory", {}))
	reputation.clear()
	var rep: Dictionary = data.get("reputation", {})
	for key in rep:
		reputation[StringName(key)] = float(rep[key])
	flags = (data.get("flags", {}) as Dictionary).duplicate()
	clock_minutes = float(data.get("clock", START_CLOCK))
	clock_changed.emit(clock_text())
	effects.clear()
	effects_changed.emit()
	var place := StringName(data.get("waypoint", ""))
	if places.has(place):
		set_waypoint(place)
	else:
		clear_waypoint()


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
