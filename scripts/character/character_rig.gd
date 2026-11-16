@tool
class_name CharacterRig
extends RefCounted
## The player character's skeleton and body layout, shared by the model, the first-person arms,
## the creator and (in prototype 6) clothing and armour.
##
## - BONES: an 18-bone humanoid skeleton facing -Z (like the NPCs), feet on the origin.
## - REGIONS: the body is built from one box-shaped part per region, each skinned rigidly to one
##   bone. Every region is its own MeshInstance3D per wear layer, so clothing can hide the skin
##   under it (body masks) and first person can hide the head and arms.
## - SLOTS: attachment points on the skeleton (BoneAttachment3D) for weapons, helmets, packs...
## - WEAR_SLOTS and WearLayer: which regions each piece of clothing or armour covers, and in which
##   order layers stack (underwear, clothing, outer wear, armour).

## Draw order of what the character wears, from the skin outwards. Each layer sits a little further
## out (INFLATE) so layers never clip into each other.
enum WearLayer { UNDERWEAR, CLOTHING, OUTER, ARMOR }
const INFLATE := [0.0, 0.012, 0.026, 0.045]
const LAYER_NAMES := ["Underwear", "Clothing", "Outer wear", "Armour"]

## Render layer 3: parts the first-person camera doesn't draw (head, neck, hair, arms). They are
## still seen by mirrors, cameras and third person, and still cast shadows.
const FIRST_PERSON_HIDDEN := 4
const HIDDEN_IN_FIRST_PERSON: Array[StringName] = [&"head", &"neck", &"upper_arm_l", &"upper_arm_r", &"forearm_l", &"forearm_r", &"hand_l", &"hand_r"]

## [name, parent, offset from the parent at rest (x is mirrored for .L/.R)]
const BONES := [
	[&"Root", &"", Vector3.ZERO],
	[&"Hips", &"Root", Vector3(0, 0.95, 0)],
	[&"Spine", &"Hips", Vector3(0, 0.1, 0)],
	[&"Chest", &"Spine", Vector3(0, 0.18, 0)],
	[&"Neck", &"Chest", Vector3(0, 0.25, 0)],
	[&"Head", &"Neck", Vector3(0, 0.09, 0)],
	[&"UpperArm.L", &"Chest", Vector3(-0.21, 0.22, 0)],
	[&"ForeArm.L", &"UpperArm.L", Vector3(0, -0.28, 0)],
	[&"Hand.L", &"ForeArm.L", Vector3(0, -0.26, 0)],
	[&"UpperArm.R", &"Chest", Vector3(0.21, 0.22, 0)],
	[&"ForeArm.R", &"UpperArm.R", Vector3(0, -0.28, 0)],
	[&"Hand.R", &"ForeArm.R", Vector3(0, -0.26, 0)],
	[&"UpperLeg.L", &"Hips", Vector3(-0.095, -0.04, 0)],
	[&"LowerLeg.L", &"UpperLeg.L", Vector3(0, -0.43, 0)],
	[&"Foot.L", &"LowerLeg.L", Vector3(0, -0.4, 0)],
	[&"UpperLeg.R", &"Hips", Vector3(0.095, -0.04, 0)],
	[&"LowerLeg.R", &"UpperLeg.R", Vector3(0, -0.43, 0)],
	[&"Foot.R", &"LowerLeg.R", Vector3(0, -0.4, 0)],
]

## region -> {bone, center (box centre relative to the bone), size (slim), muscle (extra size at
## full muscle), shift (box moves this far at full muscle), frame (extra size at the broadest frame)}
const REGIONS := {
	&"head": {"bone": &"Head", "center": Vector3(0, 0.125, -0.005), "size": Vector3(0.21, 0.24, 0.22), "muscle": Vector3.ZERO, "shift": Vector3.ZERO, "frame": Vector3.ZERO},
	&"neck": {"bone": &"Neck", "center": Vector3(0, 0.04, 0), "size": Vector3(0.1, 0.12, 0.1), "muscle": Vector3(0.05, 0, 0.04), "shift": Vector3.ZERO, "frame": Vector3(0.01, 0, 0)},
	&"chest": {"bone": &"Chest", "center": Vector3(0, 0.12, 0), "size": Vector3(0.34, 0.26, 0.2), "muscle": Vector3(0.12, 0.02, 0.07), "shift": Vector3(0, 0, -0.01), "frame": Vector3(0.1, 0, 0.02)},
	&"abdomen": {"bone": &"Spine", "center": Vector3(0, 0.09, 0), "size": Vector3(0.28, 0.19, 0.17), "muscle": Vector3(0.05, 0, 0.04), "shift": Vector3.ZERO, "frame": Vector3(0.05, 0, 0.01)},
	&"pelvis": {"bone": &"Hips", "center": Vector3(0, 0.0, 0), "size": Vector3(0.3, 0.18, 0.19), "muscle": Vector3(0.03, 0, 0.02), "shift": Vector3.ZERO, "frame": Vector3(0.06, 0, 0.01)},
	&"upper_arm_l": {"bone": &"UpperArm.L", "center": Vector3(0, -0.14, 0), "size": Vector3(0.085, 0.3, 0.095), "muscle": Vector3(0.06, 0, 0.06), "shift": Vector3(-0.05, 0, 0), "frame": Vector3(0.01, 0, 0.01)},
	&"forearm_l": {"bone": &"ForeArm.L", "center": Vector3(0, -0.13, 0), "size": Vector3(0.075, 0.27, 0.085), "muscle": Vector3(0.035, 0, 0.035), "shift": Vector3(-0.05, 0, 0), "frame": Vector3.ZERO},
	&"hand_l": {"bone": &"Hand.L", "center": Vector3(0, -0.07, 0), "size": Vector3(0.05, 0.14, 0.08), "muscle": Vector3(0.012, 0, 0.012), "shift": Vector3(-0.05, 0, 0), "frame": Vector3.ZERO},
	&"upper_arm_r": {"bone": &"UpperArm.R", "center": Vector3(0, -0.14, 0), "size": Vector3(0.085, 0.3, 0.095), "muscle": Vector3(0.06, 0, 0.06), "shift": Vector3(0.05, 0, 0), "frame": Vector3(0.01, 0, 0.01)},
	&"forearm_r": {"bone": &"ForeArm.R", "center": Vector3(0, -0.13, 0), "size": Vector3(0.075, 0.27, 0.085), "muscle": Vector3(0.035, 0, 0.035), "shift": Vector3(0.05, 0, 0), "frame": Vector3.ZERO},
	&"hand_r": {"bone": &"Hand.R", "center": Vector3(0, -0.07, 0), "size": Vector3(0.05, 0.14, 0.08), "muscle": Vector3(0.012, 0, 0.012), "shift": Vector3(0.05, 0, 0), "frame": Vector3.ZERO},
	&"thigh_l": {"bone": &"UpperLeg.L", "center": Vector3(0, -0.215, 0), "size": Vector3(0.14, 0.45, 0.15), "muscle": Vector3(0.05, 0, 0.05), "shift": Vector3(-0.01, 0, 0), "frame": Vector3(0.015, 0, 0.01)},
	&"shin_l": {"bone": &"LowerLeg.L", "center": Vector3(0, -0.2, 0), "size": Vector3(0.11, 0.42, 0.12), "muscle": Vector3(0.035, 0, 0.035), "shift": Vector3(-0.01, 0, 0), "frame": Vector3.ZERO},
	&"foot_l": {"bone": &"Foot.L", "center": Vector3(0, -0.035, -0.05), "size": Vector3(0.1, 0.08, 0.25), "muscle": Vector3(0.01, 0, 0.0), "shift": Vector3(-0.01, 0, 0), "frame": Vector3.ZERO},
	&"thigh_r": {"bone": &"UpperLeg.R", "center": Vector3(0, -0.215, 0), "size": Vector3(0.14, 0.45, 0.15), "muscle": Vector3(0.05, 0, 0.05), "shift": Vector3(0.01, 0, 0), "frame": Vector3(0.015, 0, 0.01)},
	&"shin_r": {"bone": &"LowerLeg.R", "center": Vector3(0, -0.2, 0), "size": Vector3(0.11, 0.42, 0.12), "muscle": Vector3(0.035, 0, 0.035), "shift": Vector3(0.01, 0, 0), "frame": Vector3.ZERO},
	&"foot_r": {"bone": &"Foot.R", "center": Vector3(0, -0.035, -0.05), "size": Vector3(0.1, 0.08, 0.25), "muscle": Vector3(0.01, 0, 0.0), "shift": Vector3(0.01, 0, 0), "frame": Vector3.ZERO},
}

## Attachment points: slot -> [bone, offset]. Each becomes a BoneAttachment3D named "Slot_<slot>".
const SLOTS := {
	&"helmet": [&"Head", Vector3(0, 0.25, 0)],
	&"face": [&"Head", Vector3(0, 0.13, -0.12)],
	&"neck": [&"Neck", Vector3(0, 0.05, 0)],
	&"chest": [&"Chest", Vector3(0, 0.12, -0.12)],
	&"back": [&"Chest", Vector3(0, 0.12, 0.12)],
	&"shoulder_l": [&"UpperArm.L", Vector3(0, 0.0, 0)],
	&"shoulder_r": [&"UpperArm.R", Vector3(0, 0.0, 0)],
	&"forearm_l": [&"ForeArm.L", Vector3(0, -0.13, 0)],
	&"forearm_r": [&"ForeArm.R", Vector3(0, -0.13, 0)],
	&"hand_l": [&"Hand.L", Vector3(0, -0.09, 0)],
	&"hand_r": [&"Hand.R", Vector3(0, -0.09, 0)],
	&"waist": [&"Hips", Vector3(0, 0.07, 0)],
	&"hip_r": [&"Hips", Vector3(0.18, 0.0, 0)],
	&"thigh_l": [&"UpperLeg.L", Vector3(0, -0.2, 0)],
	&"thigh_r": [&"UpperLeg.R", Vector3(0, -0.2, 0)],
	&"shin_l": [&"LowerLeg.L", Vector3(0, -0.2, 0)],
	&"shin_r": [&"LowerLeg.R", Vector3(0, -0.2, 0)],
	&"foot_l": [&"Foot.L", Vector3(0, 0, -0.05)],
	&"foot_r": [&"Foot.R", Vector3(0, 0, -0.05)],
}

## What can be worn where (prototype 6 equips items into these): slot -> [layer, regions covered].
const WEAR_SLOTS := {
	&"shirt": [WearLayer.CLOTHING, [&"chest", &"abdomen", &"upper_arm_l", &"upper_arm_r", &"forearm_l", &"forearm_r"]],
	&"pants": [WearLayer.CLOTHING, [&"pelvis", &"thigh_l", &"thigh_r", &"shin_l", &"shin_r"]],
	&"shoes": [WearLayer.CLOTHING, [&"foot_l", &"foot_r"]],
	&"gloves": [WearLayer.CLOTHING, [&"hand_l", &"hand_r"]],
	&"jacket": [WearLayer.OUTER, [&"chest", &"abdomen", &"upper_arm_l", &"upper_arm_r", &"forearm_l", &"forearm_r"]],
	&"helmet": [WearLayer.ARMOR, [&"head"]],
	&"chest_armor": [WearLayer.ARMOR, [&"chest", &"abdomen"]],
	&"shoulders": [WearLayer.ARMOR, [&"upper_arm_l", &"upper_arm_r"]],
	&"gauntlets": [WearLayer.ARMOR, [&"forearm_l", &"forearm_r", &"hand_l", &"hand_r"]],
	&"greaves": [WearLayer.ARMOR, [&"shin_l", &"shin_r"]],
	&"boots": [WearLayer.ARMOR, [&"foot_l", &"foot_r"]],
}


static func bone_index(name: StringName) -> int:
	for i in BONES.size():
		if BONES[i][0] == name:
			return i
	return -1


## Rest offset of a bone for a given build (frame widens shoulders and hips).
static func bone_offset(index: int, frame: float) -> Vector3:
	var name: StringName = BONES[index][0]
	var offset: Vector3 = BONES[index][2]
	if String(name).begins_with("UpperArm"):
		offset.x = signf(offset.x) * (0.19 + 0.05 * frame)
	elif String(name).begins_with("UpperLeg"):
		offset.x = signf(offset.x) * (0.085 + 0.025 * frame)
	return offset


## Fills `skeleton` with the bones for this build.
static func build_skeleton(skeleton: Skeleton3D, frame: float) -> void:
	skeleton.clear_bones()
	for i in BONES.size():
		skeleton.add_bone(String(BONES[i][0]))
	for i in BONES.size():
		var parent: StringName = BONES[i][1]
		if parent != &"":
			skeleton.set_bone_parent(i, bone_index(parent))
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, bone_offset(i, frame)))
	skeleton.reset_bone_poses()


## Global rest position of a bone (model space, before the height scale).
static func bone_rest_position(index: int, frame: float) -> Vector3:
	var position := Vector3.ZERO
	var i := index
	while i >= 0:
		position += bone_offset(i, frame)
		var parent: StringName = BONES[i][1]
		i = bone_index(parent) if parent != &"" else -1
	return position


## Size of a region's box for a build (slim; the muscle blend shape adds `muscle` on top).
static func region_size(region: StringName, frame: float, head_shape := 0) -> Vector3:
	var info: Dictionary = REGIONS[region]
	if region == &"head":
		return CharacterOptions.HEAD_SHAPES[head_shape][1]
	return info["size"] + info["frame"] * frame


## Overall scale for the height slider (eye level at 1.62 m for the middle setting).
static func height_scale(height: float) -> float:
	return 0.955 * lerpf(0.93, 1.07, height)
