class_name Inventory
extends RefCounted
## A bag of item counts (item id -> amount). Used for the player and for merchant stock.

signal changed

var items := {}


func count(id: StringName) -> int:
	return items.get(id, 0)


func add(id: StringName, amount := 1) -> void:
	if amount <= 0:
		return
	items[id] = count(id) + amount
	changed.emit()


## Takes `amount` away; returns false (and changes nothing) if there isn't enough.
func remove(id: StringName, amount := 1) -> bool:
	if count(id) < amount:
		return false
	items[id] = count(id) - amount
	if items[id] == 0:
		items.erase(id)
	changed.emit()
	return true


## Item ids with a non-zero count, in a stable order (by category, then name).
func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in items:
		if items[id] > 0:
			result.append(id)
	result.sort_custom(_sorts_before)
	return result


static func _sorts_before(a: StringName, b: StringName) -> bool:
	if ItemDB.category(a) != ItemDB.category(b):
		return String(ItemDB.category(a)) < String(ItemDB.category(b))
	return ItemDB.display_name(a) < ItemDB.display_name(b)


func clear() -> void:
	items.clear()
	changed.emit()
