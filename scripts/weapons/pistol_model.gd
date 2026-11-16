@tool
class_name PistolModel
extends Node3D
## Low-poly "Kitsune P9" pistol with a pink-lit slide, built from primitives; `right_hand` and
## `left_hand` mark the two-handed grip for the character's first-person arms (ViewArms).
## The grip is at the origin and the barrel points along -Z. The slide kicks back on every shot
## (it listens to the parent Firearm's `fired`) and the magazine is a separate node for reloads.

var magazine: Node3D
var right_hand: Node3D
var left_hand: Node3D
var _slide: Node3D
var _kick := 0.0


func _ready() -> void:
	BuildKit.clear_generated(self)
	var root := BuildKit.generated_root(self, "Generated")
	# Two-tone: a light frame and a gunmetal slide, so the small gun still reads at night.
	var steel := MatLib.surface(Color(0.22, 0.22, 0.25), 0.3, 0.8, 0.05)
	var polymer := MatLib.surface(Color(0.62, 0.6, 0.64), 0.5, 0.0, 0.05)
	var neon := MatLib.neon(Palette.PINK, 3.0)

	var body := GeoBatch.new()
	# Frame with the trigger guard and a rail light, grip angled back.
	body.add_box_at(Vector3(0.032, 0.03, 0.17), Vector3(0, 0.005, -0.075), polymer)
	body.add_box(Vector3(0.034, 0.11, 0.05), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-14.0)), Vector3(0, -0.055, 0.0)), polymer)
	body.add_bar(Vector3(0, -0.02, -0.06), Vector3(0, -0.03, 0.0), 0.006, steel)
	body.add_box_at(Vector3(0.006, 0.02, 0.008), Vector3(0, -0.012, -0.03), steel)
	body.add_box_at(Vector3(0.028, 0.02, 0.04), Vector3(0, -0.012, -0.135), steel)
	body.add_box_at(Vector3(0.02, 0.012, 0.004), Vector3(0, -0.012, -0.156), MatLib.neon(Palette.COOL_WHITE, 5.0))
	_add_view_mesh(root, body, "Body")
	# The shooting hand round the grip, the support hand cupped under it.
	right_hand = _hand(root, "RightHand", Vector3(0.006, -0.06, 0.012))
	left_hand = _hand(root, "LeftHand", Vector3(-0.028, -0.08, 0.0))

	_slide = Node3D.new()
	_slide.name = "Slide"
	root.add_child(_slide)
	var slide := GeoBatch.new()
	slide.add_box_at(Vector3(0.034, 0.034, 0.19), Vector3(0, 0.035, -0.08), steel)
	slide.add_box_at(Vector3(0.036, 0.006, 0.12), Vector3(0, 0.035, -0.09), neon)
	slide.add_box_at(Vector3(0.008, 0.012, 0.008), Vector3(0, 0.057, -0.165), steel)
	slide.add_box_at(Vector3(0.022, 0.012, 0.008), Vector3(0, 0.057, 0.008), steel)
	slide.add_cylinder(0.008, 0.008, 0.02, 6, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.03, -0.18)), MatLib.surface(Color(0.02, 0.02, 0.02), 0.6))
	_add_view_mesh(_slide, slide, "SlideMesh")

	magazine = Node3D.new()
	magazine.name = "Magazine"
	root.add_child(magazine)
	var mag := GeoBatch.new()
	mag.add_box(Vector3(0.026, 0.05, 0.036), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-14.0)), Vector3(0, -0.125, 0.018)), steel)
	_add_view_mesh(magazine, mag, "MagazineMesh")

	if not Engine.is_editor_hint() and get_parent() is Firearm:
		(get_parent() as Firearm).fired.connect(func() -> void: _kick = 1.0)


func _process(delta: float) -> void:
	if _slide == null:
		return
	_kick = move_toward(_kick, 0.0, delta * 9.0)
	_slide.position.z = _kick * 0.045


func _hand(parent: Node3D, node_name: String, at: Vector3) -> Node3D:
	var marker := Node3D.new()
	marker.name = node_name
	marker.position = at
	parent.add_child(marker)
	return marker


func _add_view_mesh(parent: Node3D, geo: GeoBatch, node_name: String) -> void:
	var mesh := geo.build(node_name, false)
	mesh.layers = RifleModel.VIEW_MODEL_LAYER
	parent.add_child(mesh)
