@tool
class_name NpcModel
extends Node3D
## Low-poly pedestrian built from boxes, facing -Z. `look_seed` picks the outfit (coat, hair,
## neon visor, glowing umbrella...); `outfit` = &"gang" dresses a Rust Jackal (dark red and black,
## amber mask, no umbrella) and `armed` puts a pistol in the right hand. `animate()` swings the legs
## and arms for the walk cycle. To use a real character later, replace this node with a model that
## has the same methods.

const SKIN := [Color(0.95, 0.78, 0.65), Color(0.82, 0.6, 0.45), Color(0.62, 0.42, 0.3), Color(0.42, 0.28, 0.2), Color(0.88, 0.72, 0.58)]
const COATS := [
	Color(0.08, 0.08, 0.1), Color(0.18, 0.05, 0.08), Color(0.05, 0.08, 0.18), Color(0.22, 0.22, 0.24),
	Color(0.32, 0.26, 0.18), Color(0.14, 0.05, 0.2), Color(0.55, 0.5, 0.45), Color(0.05, 0.14, 0.12),
]
const PANTS := [Color(0.05, 0.05, 0.06), Color(0.1, 0.1, 0.14), Color(0.2, 0.18, 0.15), Color(0.06, 0.08, 0.14)]
const HAIR := [Color(0.05, 0.04, 0.03), Color(0.25, 0.15, 0.08), Color(0.85, 0.82, 0.78), Palette.PINK, Palette.CYAN, Palette.PURPLE]
const GANG_COATS := [Color(0.25, 0.04, 0.05), Color(0.06, 0.05, 0.05), Color(0.35, 0.12, 0.05), Color(0.12, 0.03, 0.03)]
const GANG_HAIR := [Color(0.05, 0.04, 0.03), Palette.AMBER, Palette.RED, Color(0.85, 0.82, 0.78)]

@export var look_seed := 0:
	set(value):
		look_seed = value
		if is_inside_tree():
			_build()

var _body: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
## &"" for a pedestrian, &"gang" for a Rust Jackal.
@export var outfit := &""
## Gives the right hand a pistol.
@export var armed := false

var _holds_umbrella := false


func _ready() -> void:
	_build()


## Simple walk cycle: phase advances with distance walked; amount (0..1) scales the swing.
func animate(phase: float, amount: float) -> void:
	pose(phase, amount)


## Full pose for this frame. walk (0..1) swings the limbs, run (0..1) exaggerates the swing and
## leans forward, cower (0..1) kneels with the arms over the head, limp (0..1) splays the limbs,
## aim (0..1) raises both arms to point the gun forward, crouch (0..1) bends the knees low.
func pose(phase: float, walk: float, run := 0.0, cower := 0.0, limp := 0.0, aim := 0.0, crouch := 0.0) -> void:
	if _body == null:
		return
	var swing := sin(phase) * walk
	var leg_swing := swing * (0.55 + 0.35 * run)
	var arm_swing := swing * (0.45 + 0.6 * run) * (1.0 - aim)
	var bend := cower * 1.1 + crouch * 1.25
	_left_leg.rotation = Vector3(leg_swing - bend, 0.0, -limp * 0.25)
	_right_leg.rotation = Vector3(-leg_swing - bend, 0.0, limp * 0.25)
	# Aiming: right arm straight out, left arm across to support it.
	_left_arm.rotation = Vector3(-arm_swing - cower * 2.5 - run * 0.3 * (1.0 - aim) + aim * 1.35, aim * -0.45, -cower * 0.4 - limp * 1.3)
	if _holds_umbrella and cower == 0.0 and limp == 0.0:
		_right_arm.rotation = Vector3(1.05, 0.0, 0.25)
	else:
		_right_arm.rotation = Vector3(arm_swing - cower * 2.5 - run * 0.3 * (1.0 - aim) + aim * 1.5, aim * 0.12, cower * 0.4 + limp * 1.3)
	_body.position.y = absf(sin(phase)) * 0.035 * walk * (1.0 + run) - cower * 0.42 - crouch * 0.48
	_body.rotation.x = -run * 0.18 - cower * 0.35 - crouch * 0.12
	_left_leg.position.z = crouch * 0.12
	_right_leg.position.z = crouch * 0.12


func _build() -> void:
	BuildKit.clear_generated(self)
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var gang := outfit == &"gang"
	var skin := MatLib.surface(SKIN[rng.randi() % SKIN.size()], 0.7)
	var coat_color: Color = GANG_COATS[rng.randi() % GANG_COATS.size()] if gang else COATS[rng.randi() % COATS.size()]
	var coat := MatLib.surface(coat_color, 0.6, 0.1)
	var pants := MatLib.surface(PANTS[rng.randi() % PANTS.size()], 0.8)
	var shoes := MatLib.surface(Color(0.03, 0.03, 0.03), 0.4)
	var hair := MatLib.surface((GANG_HAIR[rng.randi() % GANG_HAIR.size()] if gang else HAIR[rng.randi() % HAIR.size()]) as Color, 0.7)
	var neon := MatLib.neon(Palette.AMBER if gang else Palette.random_neon(rng), 3.5)
	var long_coat := rng.randf() < 0.45
	var hooded := rng.randf() < (0.4 if gang else 0.2)
	_holds_umbrella = rng.randf() < 0.3 and not gang and not armed
	var scale_factor := rng.randf_range(0.92, 1.08)

	var root := BuildKit.generated_root(self, "Generated")
	root.scale = Vector3.ONE * scale_factor
	_body = Node3D.new()
	_body.name = "Body"
	root.add_child(_body)

	var torso := GeoBatch.new()
	torso.add_box_at(Vector3(0.36, 0.14, 0.22), Vector3(0, 0.98, 0), pants)
	if long_coat:
		torso.add_box_at(Vector3(0.44, 0.92, 0.27), Vector3(0, 1.1, 0), coat)
		if rng.randf() < 0.5:
			torso.add_bar(Vector3(-0.1, 0.66, -0.14), Vector3(-0.1, 1.5, -0.14), 0.025, neon)
			torso.add_bar(Vector3(0.1, 0.66, -0.14), Vector3(0.1, 1.5, -0.14), 0.025, neon)
	else:
		torso.add_box_at(Vector3(0.42, 0.6, 0.25), Vector3(0, 1.26, 0), coat)
		if rng.randf() < 0.4:
			torso.add_box_at(Vector3(0.43, 0.04, 0.26), Vector3(0, 1.2, 0), neon)
	torso.add_box_at(Vector3(0.1, 0.08, 0.1), Vector3(0, 1.6, 0), skin)
	torso.add_box_at(Vector3(0.21, 0.25, 0.23), Vector3(0, 1.75, -0.01), skin)
	if hooded:
		torso.add_box_at(Vector3(0.27, 0.3, 0.28), Vector3(0, 1.78, 0.03), coat)
	else:
		torso.add_box_at(Vector3(0.23, 0.08, 0.25), Vector3(0, 1.9, 0.01), hair)
		torso.add_box_at(Vector3(0.23, 0.18, 0.06), Vector3(0, 1.8, 0.11), hair)
	if gang:
		# The Jackals' mask: an amber visor and a jaw guard with teeth marks.
		torso.add_box_at(Vector3(0.22, 0.05, 0.03), Vector3(0, 1.78, -0.13), MatLib.neon(Palette.AMBER, 5.0))
		torso.add_box_at(Vector3(0.2, 0.08, 0.03), Vector3(0, 1.68, -0.125), MatLib.surface(Color(0.08, 0.07, 0.07), 0.4, 0.5))
		for i in 4:
			torso.add_box_at(Vector3(0.015, 0.03, 0.01), Vector3(-0.06 + i * 0.04, 1.69, -0.142), MatLib.neon(Palette.RED, 3.0))
		torso.add_box_at(Vector3(0.43, 0.05, 0.26), Vector3(0, 1.38, 0), neon)
	elif rng.randf() < 0.3:
		torso.add_box_at(Vector3(0.22, 0.05, 0.03), Vector3(0, 1.78, -0.13), MatLib.neon(Palette.CYAN if rng.randf() < 0.5 else Palette.PINK, 5.0))
	else:
		for side: float in [-1.0, 1.0]:
			torso.add_box_at(Vector3(0.04, 0.03, 0.02), Vector3(side * 0.05, 1.78, -0.125), shoes)
	if rng.randf() < 0.2:
		torso.add_box_at(Vector3(0.3, 0.38, 0.16), Vector3(0, 1.3, 0.2), MatLib.surface(Palette.METAL_DARK, 0.5, 0.3))
		torso.add_box_at(Vector3(0.18, 0.04, 0.02), Vector3(0, 1.4, 0.29), neon)
	if _holds_umbrella:
		var canopy_color := Palette.random_neon(rng)
		var pole_top := Vector3(0.12, 2.15, -0.12)
		torso.add_bar(Vector3(0.14, 1.25, -0.3), pole_top, 0.025, MatLib.neon(canopy_color, 4.0))
		torso.add_cylinder(0.62, 0.04, 0.28, 8, Transform3D(Basis.IDENTITY, pole_top + Vector3(0, -0.08, 0)), MatLib.glass(Color(canopy_color.r, canopy_color.g, canopy_color.b, 0.35)))
		torso.add_cylinder(0.63, 0.63, 0.025, 8, Transform3D(Basis.IDENTITY, pole_top + Vector3(0, -0.22, 0)), MatLib.neon(canopy_color, 3.0))
	torso.build_into(_body, "Torso")

	_left_leg = _limb(_body, "LeftLeg", Vector3(-0.1, 0.95, 0), Vector3(0.14, 0.88, 0.16), pants, shoes, true)
	_right_leg = _limb(_body, "RightLeg", Vector3(0.1, 0.95, 0), Vector3(0.14, 0.88, 0.16), pants, shoes, true)
	_left_arm = _limb(_body, "LeftArm", Vector3(-0.27, 1.52, 0), Vector3(0.1, 0.6, 0.12), coat, skin, false)
	_right_arm = _limb(_body, "RightArm", Vector3(0.27, 1.52, 0), Vector3(0.1, 0.6, 0.12), coat, skin, false)
	if _holds_umbrella:
		_right_arm.rotation = Vector3(1.05, 0, 0.25)
	if armed:
		# A pistol in the right hand, barrel along the arm (so raising the arm aims it).
		var gun := GeoBatch.new()
		var metal := MatLib.surface(Color(0.12, 0.12, 0.14), 0.35, 0.8)
		gun.add_box_at(Vector3(0.04, 0.2, 0.05), Vector3(0, -0.74, -0.04), metal)
		gun.add_box_at(Vector3(0.035, 0.05, 0.1), Vector3(0, -0.66, 0.0), metal)
		gun.add_box_at(Vector3(0.042, 0.1, 0.008), Vector3(0, -0.74, -0.066), MatLib.neon(Palette.AMBER, 3.0))
		gun.build_into(_right_arm, "Gun")


## A limb hanging down from `pivot`: a box plus a foot or hand at the end.
func _limb(parent: Node3D, limb_name: String, pivot: Vector3, size: Vector3, material: Material, end_material: Material, is_leg: bool) -> Node3D:
	var joint := Node3D.new()
	joint.name = limb_name
	joint.position = pivot
	parent.add_child(joint)
	var geo := GeoBatch.new()
	geo.add_box_at(size, Vector3(0, -size.y * 0.5, 0), material)
	if is_leg:
		geo.add_box_at(Vector3(0.15, 0.08, 0.26), Vector3(0, -size.y - 0.03, -0.04), end_material)
	else:
		geo.add_box_at(Vector3(0.08, 0.1, 0.09), Vector3(0, -size.y - 0.04, 0), end_material)
	geo.build_into(joint, "Mesh")
	return joint
