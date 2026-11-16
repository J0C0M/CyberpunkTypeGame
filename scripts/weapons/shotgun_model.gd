@tool
class_name ShotgunModel
extends Node3D
## Low-poly "Oni-12" pump shotgun with an amber-lit tube magazine, built from primitives. The grip
## is at the origin and the barrel points along -Z. After every shot the pump racks back and
## forward (it listens to the Firearm's `fired`); `left_hand` rides on the pump, so the
## character's support hand (ViewArms) racks with it.

var right_hand: Node3D
var left_hand: Node3D
var _pump: Node3D
var _rack := -1.0


func _ready() -> void:
	BuildKit.clear_generated(self)
	var root := BuildKit.generated_root(self, "Generated")
	var steel := MatLib.surface(Color(0.18, 0.18, 0.2), 0.35, 0.85, 0.05)
	var polymer := MatLib.surface(Color(0.08, 0.075, 0.08), 0.6, 0.0, 0.05)
	var wood := MatLib.surface(Color(0.45, 0.22, 0.1), 0.5, 0.0, 0.1)
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)

	var body := GeoBatch.new()
	# Receiver, barrel over the tube magazine, bead sight.
	body.add_box_at(Vector3(0.05, 0.07, 0.22), Vector3(0, 0.01, -0.07), steel)
	body.add_cylinder(0.016, 0.016, 0.56, 8, Transform3D(along_z, Vector3(0, 0.03, -0.45)), steel)
	body.add_cylinder(0.014, 0.014, 0.44, 8, Transform3D(along_z, Vector3(0, -0.005, -0.39)), steel)
	body.add_cylinder(0.0145, 0.0145, 0.3, 8, Transform3D(along_z, Vector3(0, -0.005, -0.42)), MatLib.neon(Palette.AMBER, 2.2), false)
	body.add_box_at(Vector3(0.008, 0.01, 0.008), Vector3(0, 0.05, -0.72), MatLib.neon(Palette.AMBER, 5.0))
	# Pistol grip, trigger guard and a wooden stock.
	body.add_box(Vector3(0.036, 0.11, 0.045), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-18.0)), Vector3(0, -0.075, 0.05)), polymer)
	body.add_bar(Vector3(0, -0.035, -0.04), Vector3(0, -0.045, 0.02), 0.006, steel)
	body.add_box(Vector3(0.042, 0.065, 0.25), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(5.0)), Vector3(0, -0.02, 0.17)), wood)
	_add_view_mesh(root, body, "Body")
	right_hand = Node3D.new()
	right_hand.name = "RightHand"
	right_hand.position = Vector3(0.012, -0.075, 0.05)
	root.add_child(right_hand)

	_pump = Node3D.new()
	_pump.name = "Pump"
	root.add_child(_pump)
	var pump := GeoBatch.new()
	pump.add_box_at(Vector3(0.05, 0.045, 0.16), Vector3(0, -0.01, -0.36), wood)
	for i in 4:
		pump.add_box_at(Vector3(0.052, 0.006, 0.01), Vector3(0, -0.01, -0.42 + i * 0.04), steel)
	_add_view_mesh(_pump, pump, "PumpMesh")
	left_hand = Node3D.new()
	left_hand.name = "LeftHand"
	left_hand.position = Vector3(-0.006, -0.035, -0.36)
	_pump.add_child(left_hand)

	if not Engine.is_editor_hint() and get_parent() is Firearm:
		(get_parent() as Firearm).fired.connect(func() -> void: _rack = 0.0)


func _process(delta: float) -> void:
	if _pump == null or _rack < 0.0:
		return
	# Hold a beat after the shot, slide back, then forward again.
	_rack += delta
	var t := clampf((_rack - 0.2) / 0.45, 0.0, 1.0)
	_pump.position.z = sin(t * PI) * 0.09
	if t >= 1.0:
		_rack = -1.0


func _add_view_mesh(parent: Node3D, geo: GeoBatch, node_name: String) -> void:
	var mesh := geo.build(node_name, false)
	mesh.layers = RifleModel.VIEW_MODEL_LAYER
	parent.add_child(mesh)
