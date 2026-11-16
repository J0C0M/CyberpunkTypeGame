class_name WeaponHolder
extends Node3D
## The player's hands: a hotbar of weapon slots (keys 1-3, mouse wheel) filled from the weapons
## in the inventory. Owning a weapon item (ItemData with a weapon_scene) puts its gun in the first
## free slot; losing it (sold, dropped) empties the magazine back into the inventory and frees the
## slot. Switching lowers the current gun and raises the next one.
## To add a weapon: make a Firearm scene and point a weapon item's `weapon_scene` at it.

signal weapon_changed(weapon: Firearm)
signal slots_changed

const SLOT_COUNT := 3
const SWITCH_SOUND := preload("res://assets/audio/weapon_switch.wav")
const LOWER_TIME := 0.14
const RAISE_TIME := 0.22

## Weapon item id per hotbar slot (&"" = empty).
var slots: Array[StringName] = []
## The gun in hand, or null when no weapon is owned.
var current: Firearm
var current_slot := -1

var _guns := {}
var _switch_tween: Tween
var _audio: AudioStreamPlayer


func _ready() -> void:
	slots.resize(SLOT_COUNT)
	slots.fill(&"")
	_audio = AudioStreamPlayer.new()
	_audio.stream = SWITCH_SOUND
	_audio.bus = &"SFX"
	_audio.volume_db = -8.0
	add_child(_audio)
	# Guns placed in the scene by hand are adopted (the KS-47 in player.tscn).
	for child in get_children():
		if child is Firearm:
			_guns[(child as Firearm).item_id] = child
			_holster(child)
	GameState.inventory.changed.connect(_sync)
	_sync()


func _process(_delta: float) -> void:
	if not GameState.is_free_roaming() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	for i in SLOT_COUNT:
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			select_slot(i)
	if Input.is_action_just_pressed("weapon_next"):
		cycle(1)
	elif Input.is_action_just_pressed("weapon_prev"):
		cycle(-1)


## Next/previous owned weapon (mouse wheel).
func cycle(direction: int) -> void:
	for step in range(1, SLOT_COUNT):
		var slot := posmod(current_slot + direction * step, SLOT_COUNT)
		if slots[slot] != &"":
			select_slot(slot)
			return


func select_slot(slot: int) -> void:
	if slot < 0 or slot >= SLOT_COUNT or slots[slot] == &"" or slot == current_slot:
		return
	var next: Firearm = _guns.get(slots[slot])
	if next == null:
		return
	current_slot = slot
	_audio.play()
	var previous := current
	current = next
	if _switch_tween:
		_switch_tween.kill()
	_switch_tween = create_tween()
	if previous and previous != next:
		previous.cancel_reload()
		previous.ready_to_fire = false
		_switch_tween.tween_property(self, "position:y", -0.35, LOWER_TIME)
		_switch_tween.tween_callback(_holster.bind(previous))
	else:
		position.y = -0.35
	_switch_tween.tween_callback(_draw.bind(next))
	_switch_tween.tween_property(self, "position:y", 0.0, RAISE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_switch_tween.tween_callback(func() -> void: next.ready_to_fire = true)
	weapon_changed.emit(current)
	slots_changed.emit()


## Puts the weapon in `slot` (moving it out of any other slot).
func assign(item_id: StringName, slot: int) -> void:
	if not _guns.has(item_id) or slot < 0 or slot >= SLOT_COUNT:
		return
	var old := slots.find(item_id)
	if old == slot:
		return
	var displaced := slots[slot]
	slots[slot] = item_id
	if old >= 0:
		slots[old] = displaced
		if current_slot == old:
			current_slot = slot
		elif current_slot == slot:
			current_slot = old
	elif current_slot == slot:
		current_slot = -1
		current = null
		select_slot(slot)
	slots_changed.emit()


func _holster(gun: Firearm) -> void:
	gun.visible = false
	gun.process_mode = Node.PROCESS_MODE_DISABLED


func _draw(gun: Firearm) -> void:
	gun.visible = true
	gun.process_mode = Node.PROCESS_MODE_INHERIT
	gun.ready_to_fire = false


## Matches the hotbar to the weapons in the inventory.
func _sync() -> void:
	var changed := false
	for id in ItemDB.all_ids():
		var data := ItemDB.item(id)
		if data.weapon_scene == null:
			continue
		var owned := GameState.inventory.count(id) > 0
		if owned and not slots.has(id):
			_add_weapon(data)
			changed = true
		elif not owned and slots.has(id):
			_remove_weapon(id)
			changed = true
	if changed:
		slots_changed.emit()
	if current == null:
		for slot in SLOT_COUNT:
			if slots[slot] != &"":
				select_slot(slot)
				break


func _add_weapon(data: ItemData) -> void:
	var slot := slots.find(&"")
	if slot < 0:
		return
	if not _guns.has(data.id):
		var gun := data.weapon_scene.instantiate() as Firearm
		add_child(gun)
		# A new gun comes empty; its magazine fills from the reserve on the first reload.
		gun.ammo_in_magazine = 0
		_guns[data.id] = gun
		_holster(gun)
	slots[slot] = data.id


func _remove_weapon(id: StringName) -> void:
	var slot := slots.find(id)
	slots[slot] = &""
	var gun: Firearm = _guns.get(id)
	if gun == null:
		return
	gun.cancel_reload()
	if gun.ammo_in_magazine > 0:
		var rounds := gun.ammo_in_magazine
		gun.ammo_in_magazine = 0
		GameState.inventory.add.call_deferred(gun.ammo_id, rounds)
	_holster(gun)
	if gun == current:
		current = null
		current_slot = -1
		weapon_changed.emit(null)


# --- Saving --------------------------------------------------------------------------------

func save_data() -> Dictionary:
	var magazines := {}
	for id in _guns:
		magazines[String(id)] = (_guns[id] as Firearm).ammo_in_magazine
	var slot_ids: Array[String] = []
	for id in slots:
		slot_ids.append(String(id))
	return {"slots": slot_ids, "current": current_slot, "magazines": magazines}


func load_data(data: Dictionary) -> void:
	_sync()
	var saved_slots: Array = data.get("slots", [])
	for i in mini(saved_slots.size(), SLOT_COUNT):
		var id := StringName(saved_slots[i])
		if id != &"" and slots.has(id):
			assign(id, i)
	var magazines: Dictionary = data.get("magazines", {})
	for key in magazines:
		var gun: Firearm = _guns.get(StringName(key))
		if gun:
			gun.cancel_reload()
			gun.ammo_in_magazine = clampi(int(magazines[key]), 0, gun.magazine_size)
			gun.ammo_changed.emit(gun.ammo_in_magazine, gun.reserve_ammo)
	select_slot(int(data.get("current", current_slot)))
	if current:
		current.ammo_changed.emit(current.ammo_in_magazine, current.reserve_ammo)
