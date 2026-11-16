@tool
class_name CharacterModel
extends Node3D
## The player character as a rigged low-poly model, built from a CharacterData (see CharacterRig
## for the skeleton and body layout). Structure:
##
##   CharacterModel
##     Rig (scaled by the height)
##       Skeleton (Skeleton3D, 18 bones)
##         Skin_<region>      the body, one part per region (painted skin, face, underwear, tattoos)
##         Wear_<region>      clothing over that region (all layers merged; inflated per layer)
##         Hair
##         Slot_<slot>        BoneAttachment3D attachment points (weapon in hand_r, helmets...)
##
## Muscle is a blend shape on every part (set_muscle); build and height rebuild the skeleton.
## Skin regions fully covered by clothing are hidden (body masks); the head, neck, hair and arms
## sit on render layer 3 so the first-person camera can leave them out while they still cast
## shadows and show up in mirrors. pose() drives the bones procedurally (walk, idle, aim, crouch).

signal rebuilt

const SHADER := preload("res://shaders/character.gdshader")
const HAIR_LIFT := 0.004

@export var data: CharacterData:
	set(value):
		data = value
		if is_inside_tree():
			rebuild()
## False shows the character in underwear only (the creator's preview toggle).
@export var show_outfit := true:
	set(value):
		show_outfit = value
		if is_inside_tree():
			rebuild()

var skeleton: Skeleton3D
## Wearable item ids being worn (the outfit preset's pieces).
var worn: Array = []

var _rig: Node3D
var _material: ShaderMaterial
var _parts: Array[MeshInstance3D] = []
var _bones := {}
var _slots := {}


func _ready() -> void:
	if data == null:
		data = CharacterData.new()
	else:
		rebuild()


func rebuild() -> void:
	BuildKit.clear_generated(self)
	_parts.clear()
	_slots.clear()
	_rig = BuildKit.generated_root(self, "Rig")
	_rig.scale = Vector3.ONE * CharacterRig.height_scale(data.height)
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	_rig.add_child(skeleton)
	CharacterRig.build_skeleton(skeleton, data.frame)
	_bones.clear()
	for i in CharacterRig.BONES.size():
		_bones[CharacterRig.BONES[i][0]] = i
	var textures := CharacterTexture.paint(data)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("albedo_atlas", textures[0])
	_material.set_shader_parameter("emission_atlas", textures[1])
	var skin := Skin.new()
	for i in CharacterRig.BONES.size():
		skin.add_named_bind(String(CharacterRig.BONES[i][0]), skeleton.get_bone_global_rest(i).affine_inverse())
	worn = Outfits.items(data.outfit) if show_outfit else []
	var covered := Wearables.covered_regions(worn)
	for region: StringName in CharacterRig.REGIONS:
		var body := CharacterMeshBuilder.new()
		_add_region_box(body, region, 0.0, 1.0, region)
		if region == &"head":
			_add_head_details(body)
		var part := _add_part(body, "Skin_" + String(region), skin, region)
		part.visible = not covered.has(region)
		var clothes := CharacterMeshBuilder.new()
		for id in worn:
			_add_wearable(clothes, Wearables.piece(id), region)
		if not clothes.is_empty():
			_add_part(clothes, "Wear_" + String(region), skin, region)
	var hair := CharacterMeshBuilder.new()
	_add_hair(hair)
	if not hair.is_empty():
		_add_part(hair, "Hair", skin, &"head")
	for slot: StringName in CharacterRig.SLOTS:
		var attachment := BoneAttachment3D.new()
		attachment.name = "Slot_" + String(slot)
		attachment.bone_name = String(CharacterRig.SLOTS[slot][0])
		skeleton.add_child(attachment)
		var mount := Node3D.new()
		mount.name = "Mount"
		mount.position = CharacterRig.SLOTS[slot][1]
		attachment.add_child(mount)
		_slots[slot] = mount
	set_muscle(data.muscle)
	pose(0.0, 0.0)
	rebuilt.emit()


## 0 = slim, 1 = very muscular (live, no rebuild).
func set_muscle(amount: float) -> void:
	for part in _parts:
		part.set_blend_shape_value(0, amount)


## Node to hang equipment on (CharacterRig.SLOTS: &"hand_r", &"helmet", &"back"...).
func slot(name: StringName) -> Node3D:
	return _slots.get(name)


## The skin part of a region (for body masks).
func region_part(region: StringName) -> MeshInstance3D:
	return skeleton.get_node_or_null("Skin_" + String(region)) as MeshInstance3D if skeleton else null


## Eye level above the feet, in metres (the first-person camera height).
func eye_height() -> float:
	var head := CharacterRig.bone_rest_position(CharacterRig.bone_index(&"Head"), data.frame)
	var size: Vector3 = CharacterOptions.HEAD_SHAPES[data.head_shape][1]
	return (head.y + 0.125 + size.y * 0.08) * CharacterRig.height_scale(data.height)


## Sets the bones for this frame. `phase` advances with distance walked; walk and run (0-1) scale
## the stride; aim (0-1) raises the right arm with a weapon; crouch (0-1) bends the knees; `time`
## drives breathing.
func pose(phase: float, walk: float, run := 0.0, aim := 0.0, crouch := 0.0, time := 0.0) -> void:
	if skeleton == null:
		return
	var swing := sin(phase) * walk
	var leg := swing * (0.55 + 0.3 * run)
	var arm := swing * (0.45 + 0.5 * run)
	var breath := sin(time * 1.8) * 0.02
	_rotate(&"Hips", Vector3(0, swing * 0.06, 0))
	_rotate(&"Spine", Vector3(-0.05 * run - crouch * 0.15, 0, 0))
	_rotate(&"Chest", Vector3(breath - 0.06 * run, -swing * 0.08, 0))
	_rotate(&"Neck", Vector3(-breath * 0.5, 0, 0))
	# Positive X rotation swings a limb forward; a bent knee swings the shin back.
	_rotate(&"UpperLeg.L", Vector3(leg + crouch * 1.2, 0, 0))
	_rotate(&"UpperLeg.R", Vector3(-leg + crouch * 1.2, 0, 0))
	_rotate(&"LowerLeg.L", Vector3(-maxf(0.0, -leg) * 1.1 - crouch * 2.0, 0, 0))
	_rotate(&"LowerLeg.R", Vector3(-maxf(0.0, leg) * 1.1 - crouch * 2.0, 0, 0))
	_rotate(&"Foot.L", Vector3(crouch * 0.8, 0, 0))
	_rotate(&"Foot.R", Vector3(crouch * 0.8, 0, 0))
	var hips := skeleton.get_bone_rest(_bones[&"Hips"]).origin
	skeleton.set_bone_pose_position(_bones[&"Hips"], hips + Vector3(0, absf(swing) * 0.02 - crouch * 0.42, 0))
	# Arms hang slightly away from the body; aiming swings them forward to hold a gun.
	_rotate(&"UpperArm.L", Vector3(-arm * (1.0 - aim) + aim * 1.25, -aim * 0.5, -0.08 - aim * 0.1))
	_rotate(&"UpperArm.R", Vector3(arm * (1.0 - aim) + aim * 1.45, aim * 0.1, 0.08))
	_rotate(&"ForeArm.L", Vector3(0.15 + run * 0.6 + aim * 0.25, 0, 0))
	_rotate(&"ForeArm.R", Vector3(0.15 + run * 0.6 + aim * 0.05, 0, 0))


func _rotate(bone: StringName, euler: Vector3) -> void:
	skeleton.set_bone_pose_rotation(_bones[bone], Basis.from_euler(euler).get_rotation_quaternion())


# --- Building ---------------------------------------------------------------------------------

## Rest-pose centre and size (slim and muscular) of a region's box, inflated by `inflate`.
## `share` covers only part of it: 0.4 = the top 40 %, -0.4 = the bottom 40 %.
func _region_box(region: StringName, inflate: float, share: float) -> Array:
	var info: Dictionary = CharacterRig.REGIONS[region]
	var bone := CharacterRig.bone_index(info["bone"])
	var center: Vector3 = CharacterRig.bone_rest_position(bone, data.frame) + info["center"]
	var size: Vector3 = CharacterRig.region_size(region, data.frame, data.head_shape) + Vector3.ONE * inflate * 2.0
	var muscle_size: Vector3 = size + info["muscle"]
	var muscle_center: Vector3 = center + info["shift"]
	if share < 1.0:
		var top := share > 0.0
		var amount := absf(share)
		var slim := _cut(center, size, amount, top)
		var bulky := _cut(muscle_center, muscle_size, amount, top)
		return [slim[0], slim[1], bulky[0], bulky[1], bone]
	return [center, size, muscle_center, muscle_size, bone]


func _cut(center: Vector3, size: Vector3, amount: float, top: bool) -> Array:
	var height := size.y * amount
	var edge := center.y + size.y * 0.5 if top else center.y - size.y * 0.5
	var cut_center := Vector3(center.x, edge - height * 0.5 if top else edge + height * 0.5, center.z)
	return [cut_center, Vector3(size.x, height, size.z)]


func _add_region_box(builder: CharacterMeshBuilder, region: StringName, inflate: float, share: float, atlas_key: StringName, color := Color.WHITE) -> Array:
	var box := _region_box(region, inflate, share)
	builder.add_box(box[0], box[1], box[2], box[3], box[4], atlas_key, color)
	return box


func _add_part(builder: CharacterMeshBuilder, part_name: String, skin: Skin, region: StringName) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = builder.build(true)
	part.skin = skin
	part.material_override = _material
	if CharacterRig.HIDDEN_IN_FIRST_PERSON.has(region):
		part.layers = CharacterRig.FIRST_PERSON_HIDDEN
	skeleton.add_child(part)
	part.skeleton = NodePath("..")
	_parts.append(part)
	return part


## Jaw, nose, ears and face cyberware, all on the head bone.
func _add_head_details(builder: CharacterMeshBuilder) -> void:
	var head := _region_box(&"head", 0.0, 1.0)
	var center: Vector3 = head[0]
	var half: Vector3 = head[1] * 0.5
	var bone: int = head[4]
	var eye_y := center.y + half.y * 0.16
	var front := center.z - half.z
	var jaw: Vector3 = CharacterOptions.HEAD_SHAPES[data.head_shape][2]
	if jaw != Vector3.ZERO:
		var at := Vector3(center.x, center.y - half.y - jaw.y * 0.5 + 0.012, front + jaw.z * 0.5)
		builder.add_rigid_box(at, at, jaw, bone, &"jaw")
	var nose: Array = CharacterOptions.NOSES[data.nose]
	var nose_size: Vector3 = nose[1]
	var nose_at := Vector3(center.x, eye_y - float(nose[2]) - nose_size.y * 0.2, front - nose_size.z * 0.5)
	builder.add_rigid_box(nose_at, nose_at, nose_size, bone, &"nose")
	for side: float in [-1.0, 1.0]:
		var ear := Vector3(center.x + side * (half.x + 0.012), eye_y - 0.02, center.z + 0.01)
		builder.add_rigid_box(ear, ear, Vector3(0.025, 0.06, 0.05), bone, &"ear_l" if side < 0.0 else &"ear_r")
	var metal := Color(0.55, 0.57, 0.62)
	if data.cyberware.has(&"jaw_plate"):
		var plate := Vector3(center.x, center.y - half.y + 0.03, front - 0.008)
		builder.add_rigid_box(plate, plate, Vector3(half.x * 1.5, 0.05, 0.02), bone, &"", metal)
		builder.add_rigid_box(plate + Vector3(0, 0.0, -0.011), plate + Vector3(0, 0.0, -0.011), Vector3(half.x * 1.2, 0.008, 0.004), bone, &"", Color(Palette.CYAN, 0.0))
	if data.cyberware.has(&"temple_chrome"):
		for side: float in [-1.0, 1.0]:
			var temple := Vector3(center.x + side * (half.x + 0.005), eye_y + 0.035, front + 0.05)
			builder.add_rigid_box(temple, temple, Vector3(0.012, 0.06, 0.07), bone, &"", metal)
	if data.cyberware.has(&"optic_eye"):
		var optic := Vector3(center.x + half.x * 0.4, eye_y, front - 0.006)
		builder.add_rigid_box(optic, optic, Vector3(0.04, 0.035, 0.012), bone, &"", Color(0.3, 0.3, 0.33))
		builder.add_rigid_box(optic + Vector3(0, 0, -0.007), optic + Vector3(0, 0, -0.007), Vector3(0.014, 0.014, 0.004), bone, &"", Color(Palette.RED, 0.0))
	if data.facial_hair == 4:
		var beard := Vector3(center.x, center.y - half.y + 0.02, front + 0.01)
		builder.add_rigid_box(beard, beard, Vector3(half.x * 1.8, 0.07, 0.05), bone, &"", _hair_color())


func _hair_color() -> Color:
	var entry: Array = CharacterOptions.HAIR_COLORS[data.hair_color]
	var color: Color = entry[1]
	return Color(color, 0.8 if entry[2] else 1.0)


func _add_hair(builder: CharacterMeshBuilder) -> void:
	if data.hair_style == 0:
		return
	var head := _region_box(&"head", 0.0, 1.0)
	var c: Vector3 = head[0]
	var h: Vector3 = head[1] * 0.5
	var bone: int = head[4]
	var color := _hair_color()
	var top := c.y + h.y
	var back := c.z + h.z
	var w := h.x * 2.0
	var d := h.z * 2.0
	var boxes := []
	match data.hair_style:
		1:
			boxes = [[Vector3(c.x, top + 0.008, c.z), Vector3(w + 0.012, 0.02, d + 0.012)], [Vector3(c.x, c.y + h.y * 0.3, back + 0.006), Vector3(w + 0.012, h.y * 1.3, 0.012)]]
		2:
			boxes = [[Vector3(c.x, top + 0.018, c.z), Vector3(w + 0.03, 0.045, d + 0.03)], [Vector3(c.x, c.y + h.y * 0.25, back + 0.014), Vector3(w + 0.03, h.y * 1.5, 0.03)]]
			for side: float in [-1.0, 1.0]:
				boxes.append([Vector3(c.x + side * (h.x + 0.01), c.y + h.y * 0.55, c.z + 0.03), Vector3(0.02, h.y * 0.8, d * 0.7)])
		3:
			boxes = [[Vector3(c.x, top + 0.055, c.z + 0.01), Vector3(0.05, 0.12, d + 0.04)], [Vector3(c.x, top + 0.004, c.z), Vector3(w + 0.008, 0.012, d + 0.008)]]
		4:
			boxes = [[Vector3(c.x, top + 0.018, c.z), Vector3(w + 0.03, 0.045, d + 0.03)], [Vector3(c.x, top - 0.2, back + 0.02), Vector3(w + 0.04, 0.44, 0.04)]]
			for side: float in [-1.0, 1.0]:
				boxes.append([Vector3(c.x + side * (h.x + 0.013), top - 0.15, c.z + 0.04), Vector3(0.026, 0.32, d * 0.75)])
		5:
			boxes = [[Vector3(c.x, top + 0.02, c.z), Vector3(w + 0.04, 0.05, d + 0.04)], [Vector3(c.x, c.y - h.y * 0.05, back + 0.016), Vector3(w + 0.04, h.y * 1.9, 0.032)], [Vector3(c.x, top - 0.035, c.z - h.z - 0.01), Vector3(w + 0.02, 0.06, 0.022)]]
			for side: float in [-1.0, 1.0]:
				boxes.append([Vector3(c.x + side * (h.x + 0.014), c.y - h.y * 0.05, c.z + 0.01), Vector3(0.028, h.y * 1.9, d * 0.92)])
		6:
			boxes = [[Vector3(c.x, top + 0.015, c.z), Vector3(w + 0.02, 0.04, d + 0.02)]]
			for i in 7:
				var x := (i % 4 - 1.5) * w * 0.28
				var z := (-0.25 if i < 4 else 0.25) * d
				boxes.append([Vector3(c.x + x, top + 0.07, c.z + z), Vector3(0.035, 0.11, 0.035), Basis.from_euler(Vector3(z * 3.0, 0.0, -x * 4.0))])
		7:
			boxes = [[Vector3(c.x, top + 0.015, c.z), Vector3(w + 0.025, 0.04, d + 0.025)], [Vector3(c.x, c.y + h.y * 0.3, back + 0.012), Vector3(w + 0.025, h.y * 1.4, 0.025)]]
			boxes.append([Vector3(c.x, c.y - h.y * 0.2, back + 0.08), Vector3(0.055, 0.28, 0.055), Basis(Vector3.RIGHT, 0.45)])
		8:
			boxes = [[Vector3(c.x, top + 0.03, c.z - 0.015), Vector3(w * 0.75, 0.07, d + 0.03)], [Vector3(c.x, top - 0.02, c.z - h.z - 0.012), Vector3(w * 0.7, 0.07, 0.024)]]
	for box in boxes:
		var basis: Basis = box[2] if box.size() > 2 else Basis.IDENTITY
		builder.add_rigid_box(box[0], box[0], box[1], bone, &"", color, basis)


## The part of a wearable that covers `region`: an inflated box per covered region plus extras.
func _add_wearable(builder: CharacterMeshBuilder, info: Dictionary, region: StringName) -> void:
	if info.is_empty():
		return
	var inflate: float = CharacterRig.INFLATE[info["layer"]]
	var regions: Dictionary = info["regions"]
	if regions.has(region):
		var box := _add_region_box(builder, region, inflate, float(regions[region]), &"", info["color"])
		for extra in info["extras"]:
			if extra[0] != region:
				continue
			var rel: Vector3 = extra[1]
			var size: Vector3 = extra[2]
			var color: Color = extra[3]
			if extra[4]:
				color.a = 0.0
			var slim: Vector3 = box[0] + rel * (box[1] * 0.5 + size * 0.5 * _outward(rel))
			var bulky: Vector3 = box[2] + rel * (box[3] * 0.5 + size * 0.5 * _outward(rel))
			builder.add_rigid_box(slim, bulky, size, box[4], &"", color)


## Extras on a face sit on top of it: push them out by half their own size on the axes at +-1.
func _outward(rel: Vector3) -> Vector3:
	return Vector3(1.0 if absf(rel.x) >= 1.0 else 0.0, 1.0 if absf(rel.y) >= 1.0 else 0.0, 1.0 if absf(rel.z) >= 1.0 else 0.0)
