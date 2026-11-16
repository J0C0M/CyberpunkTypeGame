@tool
class_name Wearables
extends RefCounted
## Clothing pieces the character model can wear, keyed by item id (each is also an ItemData in
## assets/items/ with category "clothing"). A piece sits on a wear slot and a layer
## (CharacterRig.WearLayer) and covers regions: 1.0 = the whole region, 0.4 = its top 40 %,
## -0.4 = its bottom 40 %. Fully covered skin is hidden (body mask). Extras add collars, pockets,
## studs and neon trim: [region, position in half-sizes of the covered box (-1..1 per axis),
## size in metres, colour, glows].
##
## Prototype 6 equips these one by one; for now a character wears one preset from Outfits.

const PIECES := {
	# Street runner
	&"wear_runner_jacket": {
		"slot": &"jacket", "layer": CharacterRig.WearLayer.OUTER, "color": Color(0.12, 0.1, 0.1),
		"regions": {&"chest": 1.0, &"abdomen": 0.85, &"upper_arm_l": 1.0, &"upper_arm_r": 1.0, &"forearm_l": 1.0, &"forearm_r": 1.0},
		"extras": [
			[&"chest", Vector3(0, 1.0, 0.2), Vector3(0.3, 0.05, 0.16), Color(0.9, 0.5, 0.1), false],
			[&"chest", Vector3(0.0, 0.0, -1.0), Vector3(0.012, 0.24, 0.01), Palette.CYAN, true],
			[&"forearm_l", Vector3(0, -0.9, 0), Vector3(0.11, 0.025, 0.12), Palette.CYAN, true],
			[&"forearm_r", Vector3(0, -0.9, 0), Vector3(0.11, 0.025, 0.12), Palette.CYAN, true],
			[&"upper_arm_l", Vector3(-1.0, 0.3, 0), Vector3(0.01, 0.08, 0.06), Palette.AMBER, true],
		],
	},
	&"wear_cargo_pants": {
		"slot": &"pants", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.2, 0.22, 0.14),
		"regions": {&"pelvis": 1.0, &"thigh_l": 1.0, &"thigh_r": 1.0, &"shin_l": 1.0, &"shin_r": 1.0},
		"extras": [
			[&"thigh_l", Vector3(-1.0, 0.0, 0), Vector3(0.03, 0.12, 0.1), Color(0.16, 0.18, 0.11), false],
			[&"thigh_r", Vector3(1.0, 0.0, 0), Vector3(0.03, 0.12, 0.1), Color(0.16, 0.18, 0.11), false],
		],
	},
	&"wear_sneakers": {
		"slot": &"shoes", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.85, 0.85, 0.88),
		"regions": {&"foot_l": 1.0, &"foot_r": 1.0},
		"extras": [
			[&"foot_l", Vector3(0, -1.0, 0), Vector3(0.12, 0.02, 0.27), Palette.PINK, true],
			[&"foot_r", Vector3(0, -1.0, 0), Vector3(0.12, 0.02, 0.27), Palette.PINK, true],
		],
	},
	# Corporate
	&"wear_suit_jacket": {
		"slot": &"jacket", "layer": CharacterRig.WearLayer.OUTER, "color": Color(0.16, 0.16, 0.19),
		"regions": {&"chest": 1.0, &"abdomen": 1.0, &"pelvis": 0.45, &"upper_arm_l": 1.0, &"upper_arm_r": 1.0, &"forearm_l": 1.0, &"forearm_r": 1.0},
		"extras": [
			[&"chest", Vector3(0, 0.55, -1.0), Vector3(0.1, 0.12, 0.012), Color(0.92, 0.92, 0.95), false],
			[&"chest", Vector3(0, 0.0, -1.0), Vector3(0.028, 0.2, 0.014), Palette.PURPLE, true],
			[&"chest", Vector3(0, 1.0, 0.0), Vector3(0.14, 0.04, 0.2), Color(0.92, 0.92, 0.95), false],
			[&"forearm_l", Vector3(0, -0.95, 0), Vector3(0.105, 0.02, 0.115), Color(0.92, 0.92, 0.95), false],
			[&"forearm_r", Vector3(0, -0.95, 0), Vector3(0.105, 0.02, 0.115), Color(0.92, 0.92, 0.95), false],
		],
	},
	&"wear_suit_trousers": {
		"slot": &"pants", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.14, 0.14, 0.17),
		"regions": {&"pelvis": 1.0, &"thigh_l": 1.0, &"thigh_r": 1.0, &"shin_l": 1.0, &"shin_r": 1.0},
		"extras": [],
	},
	&"wear_oxfords": {
		"slot": &"shoes", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.05, 0.04, 0.04),
		"regions": {&"foot_l": 1.0, &"foot_r": 1.0},
		"extras": [],
	},
	# Mechanic
	&"wear_overalls": {
		"slot": &"shirt", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.85, 0.42, 0.1),
		"regions": {&"chest": 1.0, &"abdomen": 1.0, &"pelvis": 1.0, &"thigh_l": 1.0, &"thigh_r": 1.0, &"shin_l": 1.0, &"shin_r": 1.0, &"upper_arm_l": 0.45, &"upper_arm_r": 0.45},
		"extras": [
			[&"chest", Vector3(0.45, 0.3, -1.0), Vector3(0.09, 0.08, 0.012), Color(0.7, 0.33, 0.08), false],
			[&"chest", Vector3(-0.45, 0.4, -1.0), Vector3(0.08, 0.035, 0.012), Color(0.9, 0.9, 0.9), false],
			[&"thigh_r", Vector3(0.2, -0.3, -1.0), Vector3(0.07, 0.09, 0.01), Color(0.15, 0.1, 0.08), false],
			[&"abdomen", Vector3(-0.3, -0.2, -1.0), Vector3(0.06, 0.05, 0.01), Color(0.15, 0.1, 0.08), false],
			[&"chest", Vector3(0, 0.95, -1.0), Vector3(0.2, 0.02, 0.012), Palette.LIME, true],
		],
	},
	&"wear_work_boots": {
		"slot": &"shoes", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.22, 0.15, 0.09),
		"regions": {&"foot_l": 1.0, &"foot_r": 1.0, &"shin_l": -0.22, &"shin_r": -0.22},
		"extras": [],
	},
	# Techwear
	&"wear_tech_hoodie": {
		"slot": &"jacket", "layer": CharacterRig.WearLayer.OUTER, "color": Color(0.07, 0.07, 0.08),
		"regions": {&"chest": 1.0, &"abdomen": 1.0, &"neck": 0.5, &"upper_arm_l": 1.0, &"upper_arm_r": 1.0, &"forearm_l": 1.0, &"forearm_r": 1.0},
		"extras": [
			[&"chest", Vector3(0, 0.85, 1.25), Vector3(0.24, 0.14, 0.08), Color(0.07, 0.07, 0.08), false],
			[&"chest", Vector3(-0.45, 0.0, -1.0), Vector3(0.025, 0.26, 0.012), Palette.CYAN, true],
			[&"chest", Vector3(0.45, 0.0, -1.0), Vector3(0.025, 0.26, 0.012), Palette.CYAN, true],
			[&"abdomen", Vector3(0, 0.0, -1.0), Vector3(0.18, 0.08, 0.02), Color(0.12, 0.12, 0.14), false],
			[&"forearm_l", Vector3(-1.0, -0.5, 0), Vector3(0.01, 0.06, 0.05), Palette.CYAN, true],
			[&"forearm_r", Vector3(1.0, -0.5, 0), Vector3(0.01, 0.06, 0.05), Palette.CYAN, true],
		],
	},
	&"wear_tech_joggers": {
		"slot": &"pants", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.16, 0.16, 0.18),
		"regions": {&"pelvis": 1.0, &"thigh_l": 1.0, &"thigh_r": 1.0, &"shin_l": 1.0, &"shin_r": 1.0},
		"extras": [
			[&"thigh_l", Vector3(-1.0, 0.0, 0), Vector3(0.01, 0.4, 0.02), Palette.CYAN, true],
			[&"thigh_r", Vector3(1.0, 0.0, 0), Vector3(0.01, 0.4, 0.02), Palette.CYAN, true],
		],
	},
	&"wear_tech_gloves": {
		"slot": &"gloves", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.05, 0.05, 0.06),
		"regions": {&"hand_l": 1.0, &"hand_r": 1.0},
		"extras": [
			[&"hand_l", Vector3(0, -1.0, 0), Vector3(0.06, 0.012, 0.09), Palette.CYAN, true],
			[&"hand_r", Vector3(0, -1.0, 0), Vector3(0.06, 0.012, 0.09), Palette.CYAN, true],
		],
	},
	&"wear_black_sneakers": {
		"slot": &"shoes", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.06, 0.06, 0.07),
		"regions": {&"foot_l": 1.0, &"foot_r": 1.0},
		"extras": [
			[&"foot_l", Vector3(0, -1.0, 0), Vector3(0.12, 0.02, 0.27), Palette.CYAN, true],
			[&"foot_r", Vector3(0, -1.0, 0), Vector3(0.12, 0.02, 0.27), Palette.CYAN, true],
		],
	},
	# Punk
	&"wear_punk_vest": {
		"slot": &"jacket", "layer": CharacterRig.WearLayer.OUTER, "color": Color(0.05, 0.05, 0.05),
		"regions": {&"chest": 1.0, &"abdomen": 1.0},
		"extras": [
			[&"chest", Vector3(-0.7, 0.9, -1.0), Vector3(0.02, 0.02, 0.02), Color(0.8, 0.8, 0.85), false],
			[&"chest", Vector3(-0.35, 0.9, -1.0), Vector3(0.02, 0.02, 0.02), Color(0.8, 0.8, 0.85), false],
			[&"chest", Vector3(0.35, 0.9, -1.0), Vector3(0.02, 0.02, 0.02), Color(0.8, 0.8, 0.85), false],
			[&"chest", Vector3(0.7, 0.9, -1.0), Vector3(0.02, 0.02, 0.02), Color(0.8, 0.8, 0.85), false],
			[&"chest", Vector3(0, 0.2, 1.0), Vector3(0.18, 0.12, 0.012), Palette.PINK, true],
			[&"abdomen", Vector3(0, -1.0, 0), Vector3(0.36, 0.025, 0.22), Palette.PINK, true],
		],
	},
	&"wear_ripped_jeans": {
		"slot": &"pants", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.18, 0.24, 0.42),
		"regions": {&"pelvis": 1.0, &"thigh_l": 1.0, &"thigh_r": 1.0, &"shin_l": 1.0, &"shin_r": 1.0},
		"extras": [
			[&"thigh_l", Vector3(0.0, -0.6, -1.0), Vector3(0.07, 0.03, 0.01), Color(0.6, 0.65, 0.75), false],
			[&"shin_r", Vector3(0.0, 0.5, -1.0), Vector3(0.06, 0.03, 0.01), Color(0.6, 0.65, 0.75), false],
		],
	},
	&"wear_combat_boots": {
		"slot": &"shoes", "layer": CharacterRig.WearLayer.CLOTHING, "color": Color(0.04, 0.04, 0.04),
		"regions": {&"foot_l": 1.0, &"foot_r": 1.0, &"shin_l": -0.35, &"shin_r": -0.35},
		"extras": [
			[&"shin_l", Vector3(0, -0.4, -1.0), Vector3(0.05, 0.012, 0.01), Color(0.8, 0.8, 0.85), false],
			[&"shin_r", Vector3(0, -0.4, -1.0), Vector3(0.05, 0.012, 0.01), Color(0.8, 0.8, 0.85), false],
		],
	},
}


static func piece(id: StringName) -> Dictionary:
	return PIECES.get(id, {})


## Regions fully covered (and hidden) by the given worn pieces.
static func covered_regions(worn: Array) -> Dictionary:
	var covered := {}
	for id in worn:
		var info := piece(id)
		for region in info.get("regions", {}):
			if float(info["regions"][region]) >= 1.0:
				covered[region] = true
	return covered
