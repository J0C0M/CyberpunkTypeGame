class_name Interactable
extends Area3D
## Something the player can use: look at it within reach and press E. The HUD shows
## "[E] <prompt>". Listen to `interacted`, and set `prompt_source` for prompts that change
## (e.g. "Locked" or "Open"). Make the area a little bigger than any solid body it sits on so
## the player's interaction ray reaches it first.

signal interacted(player: Player)

@export var prompt := "Use"
@export var enabled := true
## Optional callable returning the prompt text each time it is shown.
var prompt_source: Callable


## Adds a box-shaped interactable to `parent`.
static func create(parent: Node, size: Vector3, offset: Vector3, prompt_text: String) -> Interactable:
	var area := Interactable.new()
	area.prompt = prompt_text
	area.position = offset
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	area.add_child(collider)
	parent.add_child(area)
	return area


func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	monitoring = false


func get_prompt() -> String:
	return prompt_source.call() if prompt_source.is_valid() else prompt


func interact(player: Player) -> void:
	if enabled:
		interacted.emit(player)
