@tool
class_name Door
extends Node3D
## Sliding apartment door with a frame and a number plate. Locked doors just rattle ("[E] Locked");
## unlocked ones slide into the wall and back when used. A door with a `key_item` only opens from
## the hallway for someone carrying that item (always from inside). The door faces local +Z (the
## hallway, where its number plate is) and slides along local X.

const LOCKED_SOUND := preload("res://assets/audio/ui_deny.wav")
const SLIDE_SOUND := preload("res://assets/audio/door_slide.wav")
const SIZE := Vector3(1.05, 2.15, 0.08)

@export var number := "1101"
@export var locked := true
## Inventory item needed to open the door from the hallway side (&"" = none).
@export var key_item := &""
@export var accent := Color(0.62, 0.28, 1.0)

var is_open := false

var _panel: Node3D
var _collider: CollisionShape3D
var _tween: Tween


func _ready() -> void:
	BuildKit.clear_generated(self)
	var root := BuildKit.generated_root(self, "Generated")
	var frame := MatLib.surface(Palette.METAL_DARK, 0.4, 0.6)
	var geo := GeoBatch.new()
	geo.add_box_at(Vector3(SIZE.x + 0.24, 0.12, 0.16), Vector3(0, SIZE.y + 0.06, 0), frame)
	for side: float in [-1.0, 1.0]:
		geo.add_box_at(Vector3(0.12, SIZE.y, 0.16), Vector3(side * (SIZE.x * 0.5 + 0.06), SIZE.y * 0.5, 0), frame)
	geo.add_box_at(Vector3(0.34, 0.14, 0.02), Vector3(0, SIZE.y + 0.3, 0.06), MatLib.surface(Color(0.05, 0.05, 0.07), 0.4))
	geo.build_into(root, "Frame")
	BuildKit.neon_text(root, number, Transform3D(Basis.IDENTITY, Vector3(0, SIZE.y + 0.3, 0.075)), accent, 0.1)
	_panel = Node3D.new()
	_panel.name = "Panel"
	root.add_child(_panel)
	var panel := GeoBatch.new()
	panel.add_box_at(SIZE, Vector3(0, SIZE.y * 0.5, 0), MatLib.surface(Color(0.16, 0.15, 0.2), 0.45, 0.5))
	panel.add_box_at(Vector3(0.04, 0.3, 0.02), Vector3(SIZE.x * 0.5 - 0.14, 1.05, 0.05), MatLib.neon(Palette.RED if locked else Palette.LIME, 2.5))
	panel.add_bar(Vector3(-SIZE.x * 0.5 + 0.1, 1.9, 0.05), Vector3(SIZE.x * 0.5 - 0.1, 1.9, 0.05), 0.02, MatLib.neon(accent, 2.0))
	panel.build_into(_panel, "Mesh")
	var body := BuildKit.static_body(_panel)
	_collider = BuildKit.box_collider_at(body, SIZE, Vector3(0, SIZE.y * 0.5, 0))
	if Engine.is_editor_hint():
		return
	# Deeper than the panel on both sides, so the ray finds it before the panel from either side.
	var area := Interactable.create(root, Vector3(SIZE.x, 1.2, 0.5), Vector3(0, 1.3, 0.0), "")
	area.prompt_source = _prompt
	area.interacted.connect(_on_used)


func _prompt() -> String:
	if locked:
		return "Locked"
	if is_open:
		return "Close"
	if key_item != &"" and _from_hallway():
		return "Open (%s)" % ItemDB.display_name(key_item) if _has_key() else "Locked (needs %s)" % ItemDB.display_name(key_item)
	return "Open"


func _on_used(_player: Player) -> void:
	if locked or (not is_open and key_item != &"" and _from_hallway() and not _has_key()):
		SfxPool.play_at(self, LOCKED_SOUND, global_position + Vector3.UP, -4.0, 0.05, 3.0)
		var line := "It's locked." if locked else "Locked. You need your %s. Ren might know where it is." % ItemDB.display_name(key_item)
		get_tree().call_group("hud", "show_message", line, 2.5)
		return
	set_open(not is_open)


func _has_key() -> bool:
	return GameState.inventory.count(key_item) > 0


## Whether the player stands on the hallway side (local +Z).
func _from_hallway() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player == null or to_local(player.global_position).z > 0.0


func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	SfxPool.play_at(self, SLIDE_SOUND, global_position + Vector3.UP, -8.0, 0.05, 3.0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "position:x", -SIZE.x * 0.95 if open else 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	_collider.set_deferred("disabled", open)
