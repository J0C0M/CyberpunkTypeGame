class_name Pickup
extends Node3D
## Loot lying on the ground: a credit chip or an item (shown as its ItemModels model). Look at it
## and press E to pick it up; whatever doesn't fit in the inventory stays on the ground.
## Dropped loot disappears on its own after a few minutes; placed items (ItemScatter) stay.

signal taken

const SOUND := preload("res://assets/audio/pickup.wav")
const LIFETIME := 150.0
const JUNK: Array[StringName] = [&"scrap", &"burnt_chip", &"data_shard", &"synth_soda", &"onigiri"]
const VALUABLES: Array[StringName] = [&"lucky_cat", &"gold_lighter", &"vinyl", &"deck_board", &"med_patch"]

## Empty for a credit chip.
var item_id := &""
var amount := 1
## Seconds before it vanishes; 0 = stays until taken (or the night is over).
var lifetime := LIFETIME

var _age := 0.0
var _visual: Node3D


static func spawn(parent: Node, position: Vector3, item: StringName, count: int, seconds := LIFETIME) -> Pickup:
	var pickup := Pickup.new()
	pickup.item_id = item
	pickup.amount = count
	pickup.lifetime = seconds
	parent.add_child(pickup)
	pickup.global_position = position
	return pickup


## What a pedestrian leaves behind: usually some credits, sometimes junk, rarely a valuable.
static func drop_loot(parent: Node, position: Vector3) -> void:
	var roll := randf()
	if roll < 0.6:
		spawn(parent, position, &"", randi_range(8, 45))
	elif roll < 0.92:
		spawn(parent, position, JUNK.pick_random(), 1)
	else:
		spawn(parent, position, VALUABLES.pick_random(), 1)


func _ready() -> void:
	add_to_group("night_cleanup")
	var color := Palette.AMBER if item_id == &"" else ItemDB.color(item_id)
	_visual = Node3D.new()
	add_child(_visual)
	if item_id == &"":
		var geo := GeoBatch.new()
		geo.add_box_at(Vector3(0.16, 0.02, 0.1), Vector3.ZERO, MatLib.neon(color, 3.0))
		geo.add_box_at(Vector3(0.1, 0.025, 0.04), Vector3.ZERO, MatLib.surface(Color(0.05, 0.04, 0.02), 0.3, 0.8))
		geo.build_into(_visual, "Mesh", false)
	else:
		var model := ItemModels.build(item_id, 0.24)
		# Centre the model on the spin axis.
		var box := model.mesh.get_aabb()
		model.position = -box.get_center() * model.scale
		_visual.add_child(model)
	_visual.position.y = 0.25
	BuildKit.omni(_visual, Vector3.ZERO, color, 0.6, 1.6)
	var area := Interactable.create(self, Vector3(0.7, 0.7, 0.7), Vector3(0, 0.3, 0), "")
	area.prompt_source = _prompt
	area.interacted.connect(_take)


func _process(delta: float) -> void:
	_age += delta
	_visual.rotation.y += delta * 1.5
	_visual.position.y = 0.25 + sin(_age * 2.5) * 0.04
	if lifetime > 0.0 and _age > lifetime:
		queue_free()


## Loot doesn't last the night.
func clear_for_new_night() -> void:
	queue_free()


func _prompt() -> String:
	if item_id == &"":
		return "Pick up %d ¢" % amount
	return "Pick up " + _describe(amount)


## "Synth-Soda", "3 x Onigiri", "30 KS-47 Rounds".
func _describe(count: int) -> String:
	if count == 1:
		return ItemDB.display_name(item_id)
	if ItemDB.category(item_id) == &"ammo":
		return "%d %s" % [count, ItemDB.display_name(item_id)]
	return "%d x %s" % [count, ItemDB.display_name(item_id)]


func _take(_player: Player) -> void:
	if item_id == &"":
		GameState.add_credits(amount)
		get_tree().call_group("hud", "notify_item", "+ %d ¢" % amount, Palette.AMBER)
		amount = 0
	else:
		var added := GameState.inventory.add(item_id, amount)
		if added == 0:
			get_tree().call_group("hud", "show_message", "Inventory full.", 1.5)
			return
		get_tree().call_group("hud", "notify_item", "+ " + _describe(added), ItemDB.color(item_id))
		amount -= added
		if amount > 0:
			get_tree().call_group("hud", "show_message", "No room for the rest.", 1.5)
	SfxPool.play_at(self, SOUND, global_position, -6.0, 0.05, 3.0)
	if amount <= 0:
		taken.emit()
		queue_free()
