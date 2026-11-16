class_name Inventory
extends RefCounted
## A bag of item counts (item id -> amount). Used for the player and for merchant stock.
## Items stack up to their ItemData.stack_size per slot; with a `capacity` (number of slots) set,
## add() only takes what still fits. Merchant stock has no capacity.

signal changed

## Number of slots, 0 = unlimited.
var capacity := 0
var items := {}


func _init(slots := 0) -> void:
	capacity = slots


func count(id: StringName) -> int:
	return items.get(id, 0)


## Adds up to `amount` units and returns how many actually fit.
func add(id: StringName, amount := 1) -> int:
	amount = mini(amount, room_for(id))
	if amount <= 0:
		return 0
	items[id] = count(id) + amount
	changed.emit()
	return amount


## Takes `amount` away; returns false (and changes nothing) if there isn't enough.
func remove(id: StringName, amount := 1) -> bool:
	if count(id) < amount:
		return false
	items[id] = count(id) - amount
	if items[id] == 0:
		items.erase(id)
	changed.emit()
	return true


## Slots the item takes up right now.
func stacks_of(id: StringName) -> int:
	return ceili(count(id) / float(ItemDB.stack_size(id)))


func used_slots() -> int:
	var total := 0
	for id in items:
		total += stacks_of(id)
	return total


## How many more units of `id` fit: the rest of its last stack plus any free slots.
func room_for(id: StringName) -> int:
	if capacity <= 0:
		return 1 << 30
	var stack := ItemDB.stack_size(id)
	var top_up := stacks_of(id) * stack - count(id)
	return top_up + maxi(0, capacity - used_slots()) * stack


## Item ids with a non-zero count, in a stable order (by category, then name).
func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in items:
		if items[id] > 0:
			result.append(id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return ItemDB.sorts_before(a, b))
	return result


## Every slot in display order: [{"id", "count"}], full stacks first, the remainder last.
func stacks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ids():
		var left := count(id)
		var stack := ItemDB.stack_size(id)
		while left > 0:
			result.append({"id": id, "count": mini(left, stack)})
			left -= stack
	return result


func clear() -> void:
	items.clear()
	changed.emit()


## Plain dictionary for the save file.
func to_dict() -> Dictionary:
	var result := {}
	for id in items:
		result[String(id)] = items[id]
	return result


## Replaces the contents with a saved dictionary (unknown items are skipped).
func load_dict(data: Dictionary) -> void:
	items.clear()
	for key in data:
		var id := StringName(key)
		if ItemDB.has(id) and int(data[key]) > 0:
			items[id] = int(data[key])
	changed.emit()
