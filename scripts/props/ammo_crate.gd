@tool
class_name AmmoCrate
extends Node3D
## Military ammo crate. Walking up to it tops up the player's reserve ammo.

@export var cooldown := 2.0

var _cooldown_left := 0.0


func _ready() -> void:
	BuildKit.clear_generated(self)
	var root := BuildKit.generated_root(self, "Generated")
	var olive := MatLib.surface(Color(0.2, 0.24, 0.12), 0.7)
	var metal := MatLib.surface(Palette.METAL, 0.4, 0.8)
	var geo := GeoBatch.new()
	geo.add_box_at(Vector3(0.9, 0.5, 0.55), Vector3(0, 0.25, 0), olive)
	geo.add_box_at(Vector3(0.94, 0.08, 0.59), Vector3(0, 0.52, 0), MatLib.surface(Color(0.15, 0.18, 0.09), 0.7))
	for side: float in [-1.0, 1.0]:
		geo.add_box_at(Vector3(0.06, 0.52, 0.58), Vector3(side * 0.42, 0.26, 0), metal)
		geo.add_box_at(Vector3(0.14, 0.04, 0.04), Vector3(side * 0.3, 0.4, 0.29), metal)
	geo.add_box_at(Vector3(0.9, 0.06, 0.005), Vector3(0, 0.12, 0.278), MatLib.surface(Color(0.85, 0.7, 0.1), 0.6))
	geo.add_box_at(Vector3(0.7, 0.025, 0.02), Vector3(0, 0.57, 0), MatLib.neon(Palette.LIME, 3.0, 0.0, 0.0, 0.0, 0.6))
	geo.build_into(root, "CrateMesh")
	BuildKit.flat_text(root, "AMMO", Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0.281)), Color(0.85, 0.75, 0.2), 0.14)
	var body := BuildKit.static_body(root)
	BuildKit.box_collider_at(body, Vector3(0.94, 0.56, 0.6), Vector3(0, 0.28, 0))
	if Engine.is_editor_hint():
		return
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.0, 2.2)
	var trigger := CollisionShape3D.new()
	trigger.shape = shape
	trigger.position = Vector3(0, 1.0, 0)
	area.add_child(trigger)
	root.add_child(area)
	area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or player.weapon == null or _cooldown_left > 0.0:
		return
	if player.weapon.reserve_ammo >= player.weapon.max_reserve_ammo:
		return
	player.weapon.refill()
	_cooldown_left = cooldown
	get_tree().call_group("hud", "show_message", "AMMO REFILLED")
