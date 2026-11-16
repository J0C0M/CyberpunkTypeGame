class_name Pickup
extends Node3D
## Loot lying on the ground: a credit chip or an item. Look at it and press E to take it.
## Disappears on its own after a few minutes.

const SOUND := preload("res://assets/audio/pickup.wav")
const LIFETIME := 150.0
const JUNK: Array[StringName] = [&"scrap", &"burnt_chip", &"data_shard", &"synth_soda", &"onigiri"]
const VALUABLES: Array[StringName] = [&"lucky_cat", &"gold_lighter", &"vinyl", &"deck_board"]

## Empty for a credit chip.
var item_id := &""
var amount := 1

var _age := 0.0
var _visual: Node3D


static func spawn(parent: Node, position: Vector3, item: StringName, count: int) -> Pickup:
	var pickup := Pickup.new()
	pickup.item_id = item
	pickup.amount = count
	pickup.position = position
	parent.add_child(pickup)
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
	var color := Palette.AMBER if item_id == &"" else ItemDB.color(item_id)
	_visual = Node3D.new()
	add_child(_visual)
	var geo := GeoBatch.new()
	if item_id == &"":
		geo.add_box_at(Vector3(0.16, 0.02, 0.1), Vector3.ZERO, MatLib.neon(color, 3.0))
		geo.add_box_at(Vector3(0.1, 0.025, 0.04), Vector3.ZERO, MatLib.surface(Color(0.05, 0.04, 0.02), 0.3, 0.8))
	else:
		geo.add_box_at(Vector3(0.18, 0.12, 0.14), Vector3.ZERO, MatLib.surface(color.darkened(0.6), 0.4, 0.3))
		geo.add_box_at(Vector3(0.19, 0.03, 0.15), Vector3(0, 0.03, 0), MatLib.neon(color, 3.0))
	geo.build_into(_visual, "Mesh", false)
	_visual.position.y = 0.25
	BuildKit.omni(_visual, Vector3.ZERO, color, 0.6, 1.6)
	var area := Interactable.create(self, Vector3(0.7, 0.7, 0.7), Vector3(0, 0.3, 0), "")
	area.prompt_source = _prompt
	area.interacted.connect(_take)


func _process(delta: float) -> void:
	_age += delta
	_visual.rotation.y += delta * 1.5
	_visual.position.y = 0.25 + sin(_age * 2.5) * 0.04
	if _age > LIFETIME:
		queue_free()


func _prompt() -> String:
	return "Take %d ¢" % amount if item_id == &"" else "Take " + ItemDB.display_name(item_id)


func _take(_player: Player) -> void:
	if item_id == &"":
		GameState.add_credits(amount)
		get_tree().call_group("hud", "show_message", "+%d ¢" % amount)
	else:
		GameState.inventory.add(item_id, amount)
		get_tree().call_group("hud", "show_message", "Picked up " + ItemDB.display_name(item_id))
	SfxPool.play_at(self, SOUND, global_position, -6.0, 0.05, 3.0)
	queue_free()
