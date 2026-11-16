class_name ItemDB
extends RefCounted
## Every item in the game: one ItemData resource per item in res://assets/items/ (file name = item
## id). Loaded on first use. The static helpers below are what the inventory, shops, loot and UI use.

const FOLDER := "res://assets/items/"

const CATEGORY_COLORS := {
	&"weapon": Color(1.0, 0.16, 0.62),
	&"ammo": Color(1.0, 0.58, 0.12),
	&"food": Color(1.0, 0.35, 0.3),
	&"drink": Color(0.1, 0.88, 1.0),
	&"medical": Color(0.45, 1.0, 0.3),
	&"junk": Color(0.6, 0.6, 0.65),
	&"valuable": Color(1.0, 0.85, 0.2),
	&"cyberware": Color(0.62, 0.28, 1.0),
	&"clothing": Color(0.95, 0.55, 0.85),
	&"key": Color(0.75, 0.88, 1.0),
}
## Sort order in lists and the inventory grid.
const CATEGORY_ORDER: Array[StringName] = [&"weapon", &"ammo", &"medical", &"food", &"drink", &"clothing", &"junk", &"valuable", &"cyberware", &"key"]
const CATEGORY_NAMES := {
	&"weapon": "Weapon", &"ammo": "Ammo", &"food": "Food", &"drink": "Drink", &"medical": "Medical",
	&"junk": "Junk", &"valuable": "Valuable", &"cyberware": "Cyberware", &"clothing": "Clothing", &"key": "Key item",
}

static var _items := {}


## The ItemData for `id`, or null if there is no such item.
static func item(id: StringName) -> ItemData:
	_load_all()
	return _items.get(id)


static func all_ids() -> Array[StringName]:
	_load_all()
	var result: Array[StringName] = []
	result.assign(_items.keys())
	return result


static func has(id: StringName) -> bool:
	return item(id) != null


static func display_name(id: StringName) -> String:
	var data := item(id)
	return data.display_name if data else String(id)


static func category(id: StringName) -> StringName:
	var data := item(id)
	return data.category if data else &"junk"


static func category_name(id: StringName) -> String:
	return CATEGORY_NAMES.get(category(id), "Item")


static func base_price(id: StringName) -> int:
	var data := item(id)
	return data.price if data else 1


## How many units change hands per trade (30 rounds of ammo, otherwise 1).
static func pack_size(id: StringName) -> int:
	var data := item(id)
	return data.pack if data else 1


static func stack_size(id: StringName) -> int:
	var data := item(id)
	return maxi(1, data.stack_size) if data else 1


static func description(id: StringName) -> String:
	var data := item(id)
	return data.description if data else ""


## Category colour, used for list text, icon frames and pickup glow.
static func color(id: StringName) -> Color:
	return CATEGORY_COLORS.get(category(id), Color.WHITE)


## The item's own accent colour (falls back to the category colour).
static func tint(id: StringName) -> Color:
	var data := item(id)
	return data.tint if data and data.tint != Color.BLACK else color(id)


static func is_sellable(id: StringName) -> bool:
	var data := item(id)
	return data != null and data.sellable


## Sorts by category, then name.
static func sorts_before(a: StringName, b: StringName) -> bool:
	var ca := CATEGORY_ORDER.find(category(a))
	var cb := CATEGORY_ORDER.find(category(b))
	if ca != cb:
		return ca < cb
	return display_name(a) < display_name(b)


static func _load_all() -> void:
	if not _items.is_empty():
		return
	# list_directory also sees exported (remapped) resources.
	for file in ResourceLoader.list_directory(FOLDER):
		if not file.ends_with(".tres"):
			continue
		var data := load(FOLDER + file) as ItemData
		if data and data.id != &"":
			_items[data.id] = data
