@tool
class_name RifleModel
extends Node3D
## Low-poly AK-style rifle with a few cyberpunk mods (neon strips, red-dot sight), built from
## primitives. The grip is at the origin and the barrel points along -Z. The magazine is a
## separate node so the reload animation can drop it. `right_hand` and `left_hand` mark where the
## player's hands hold it (ViewArms puts the character's own arms there).

## Render layer for the first-person model, lit by an extra fill light that only affects it.
const VIEW_MODEL_LAYER := 2

var magazine: Node3D
var right_hand: Node3D
var left_hand: Node3D


func _ready() -> void:
	BuildKit.clear_generated(self)
	var root := BuildKit.generated_root(self, "Generated")
	var steel := MatLib.surface(Color(0.07, 0.07, 0.08), 0.35, 0.85, 0.05)
	var steel_light := MatLib.surface(Color(0.16, 0.16, 0.18), 0.3, 0.85, 0.05)
	var wood := MatLib.surface(Color(0.36, 0.17, 0.08), 0.45, 0.0, 0.1)
	var polymer := MatLib.surface(Color(0.04, 0.04, 0.045), 0.6, 0.0, 0.05)
	var neon := MatLib.neon(Palette.CYAN, 3.0)

	var geo := GeoBatch.new()
	# Receiver and dust cover.
	geo.add_box_at(Vector3(0.05, 0.075, 0.32), Vector3(0, 0, -0.08), steel)
	geo.add_box_at(Vector3(0.046, 0.026, 0.3), Vector3(0, 0.048, -0.07), steel_light)
	geo.add_box_at(Vector3(0.052, 0.012, 0.05), Vector3(0, 0.03, -0.02), steel_light)
	# Barrel, gas tube, front sight and muzzle brake.
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)
	geo.add_cylinder(0.011, 0.011, 0.44, 8, Transform3D(along_z, Vector3(0, 0.012, -0.46)), steel)
	geo.add_cylinder(0.009, 0.009, 0.2, 6, Transform3D(along_z, Vector3(0, 0.046, -0.36)), steel)
	geo.add_box_at(Vector3(0.022, 0.03, 0.03), Vector3(0, 0.03, -0.6), steel)
	geo.add_box_at(Vector3(0.008, 0.035, 0.012), Vector3(0, 0.06, -0.6), steel)
	geo.add_cylinder(0.016, 0.016, 0.06, 8, Transform3D(along_z, Vector3(0, 0.012, -0.69)), steel_light)
	# Wooden handguard with a neon strip on each side.
	geo.add_box_at(Vector3(0.056, 0.05, 0.2), Vector3(0, -0.004, -0.33), wood)
	geo.add_box_at(Vector3(0.046, 0.026, 0.17), Vector3(0, 0.044, -0.33), wood)
	for side: float in [-1.0, 1.0]:
		geo.add_box_at(Vector3(0.004, 0.008, 0.16), Vector3(side * 0.029, 0.0, -0.33), neon)
	# Red-dot sight on a rail.
	geo.add_box_at(Vector3(0.03, 0.012, 0.1), Vector3(0, 0.067, -0.1), steel)
	geo.add_box_at(Vector3(0.036, 0.034, 0.05), Vector3(0, 0.09, -0.1), polymer)
	geo.add_box_at(Vector3(0.026, 0.024, 0.004), Vector3(0, 0.092, -0.074), MatLib.glass(Color(1.0, 0.3, 0.5, 0.35)))
	geo.add_box_at(Vector3(0.004, 0.004, 0.002), Vector3(0, 0.092, -0.075), MatLib.neon(Palette.RED, 6.0))
	# Pistol grip, trigger and guard.
	geo.add_box(Vector3(0.034, 0.11, 0.045), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-18.0)), Vector3(0, -0.075, 0.045)), polymer)
	geo.add_box_at(Vector3(0.006, 0.03, 0.008), Vector3(0, -0.05, -0.01), steel)
	geo.add_bar(Vector3(0, -0.07, -0.05), Vector3(0, -0.07, 0.02), 0.006, steel)
	# Wooden stock with a small drop.
	geo.add_box(Vector3(0.04, 0.06, 0.26), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(6.0)), Vector3(0, -0.025, 0.2)), wood)
	geo.add_box(Vector3(0.042, 0.09, 0.02), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(6.0)), Vector3(0, -0.04, 0.33)), polymer)
	_add_view_mesh(root, geo, "Body")
	right_hand = _hand(root, "RightHand", Vector3(0.012, -0.075, 0.045))
	left_hand = _hand(root, "LeftHand", Vector3(-0.006, -0.04, -0.27))

	magazine = Node3D.new()
	magazine.name = "Magazine"
	root.add_child(magazine)
	var mag := GeoBatch.new()
	var curve := [[Vector3(0, -0.075, -0.13), 0.0], [Vector3(0, -0.145, -0.145), 12.0], [Vector3(0, -0.21, -0.172), 25.0]]
	for piece in curve:
		mag.add_box(Vector3(0.03, 0.075, 0.06), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(piece[1])), piece[0]), steel)
	mag.add_box(Vector3(0.032, 0.012, 0.01), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(18.0)), Vector3(0, -0.17, -0.128)), MatLib.neon(Palette.PINK, 3.0))
	_add_view_mesh(magazine, mag, "MagazineMesh")


func _hand(parent: Node3D, node_name: String, at: Vector3) -> Node3D:
	var marker := Node3D.new()
	marker.name = node_name
	marker.position = at
	parent.add_child(marker)
	return marker


func _add_view_mesh(parent: Node3D, geo: GeoBatch, node_name: String) -> void:
	var mesh := geo.build(node_name, false)
	mesh.layers = VIEW_MODEL_LAYER
	parent.add_child(mesh)
