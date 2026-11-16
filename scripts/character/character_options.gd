@tool
class_name CharacterOptions
extends RefCounted
## Every choice the character creator offers, as lists of [label, value...]. CharacterData stores
## indices into these lists (or ids for tattoos, cyberware and outfits), so saves stay small and
## options can be reworded without breaking old characters.

const SKIN_TONES: Array[Color] = [
	Color(0.97, 0.82, 0.7), Color(0.92, 0.72, 0.58), Color(0.8, 0.58, 0.42), Color(0.66, 0.45, 0.31),
	Color(0.52, 0.34, 0.22), Color(0.38, 0.24, 0.16), Color(0.27, 0.17, 0.12), Color(0.84, 0.76, 0.86),
]
## [label, head size, jaw size (0 = none)]
const HEAD_SHAPES := [
	["Round", Vector3(0.21, 0.24, 0.22), Vector3.ZERO],
	["Square", Vector3(0.22, 0.24, 0.22), Vector3(0.2, 0.06, 0.2)],
	["Long", Vector3(0.19, 0.28, 0.21), Vector3.ZERO],
	["Narrow", Vector3(0.18, 0.26, 0.21), Vector3(0.14, 0.04, 0.17)],
	["Heavy", Vector3(0.23, 0.25, 0.23), Vector3(0.22, 0.07, 0.21)],
]
const EYE_SHAPES := ["Round", "Narrow", "Almond", "Wide", "Sleepy"]
const EYE_COLORS: Array[Color] = [
	Color(0.32, 0.2, 0.1), Color(0.25, 0.5, 0.95), Color(0.25, 0.7, 0.35), Color(0.55, 0.6, 0.65),
	Color(0.95, 0.65, 0.15), Color(1.0, 0.15, 0.2), Color(0.65, 0.3, 1.0), Color(0.75, 0.95, 1.0),
]
const EYE_COLOR_NAMES := ["Brown", "Blue", "Green", "Grey", "Amber", "Red", "Violet", "Ice"]
const BROWS := ["None", "Thin", "Thick", "Angry", "Arched"]
## [label, nose box size, offset down from the eyes]
const NOSES := [
	["Button", Vector3(0.03, 0.035, 0.02), 0.035],
	["Straight", Vector3(0.03, 0.055, 0.025), 0.04],
	["Wide", Vector3(0.05, 0.04, 0.025), 0.045],
	["Long", Vector3(0.028, 0.07, 0.03), 0.045],
	["Flat", Vector3(0.045, 0.03, 0.012), 0.04],
]
const MOUTHS := ["Line", "Smile", "Frown", "Full", "Smirk"]
const HAIR_STYLES := ["Bald", "Buzz", "Short", "Mohawk", "Long", "Bob", "Spiky", "Ponytail", "Undercut"]
## [label, colour, glows]
const HAIR_COLORS := [
	["Black", Color(0.05, 0.04, 0.04), false], ["Brown", Color(0.28, 0.16, 0.08), false],
	["Blonde", Color(0.85, 0.72, 0.42), false], ["Red", Color(0.6, 0.16, 0.06), false],
	["Grey", Color(0.62, 0.62, 0.66), false], ["White", Color(0.92, 0.92, 0.95), false],
	["Neon Pink", Color(1.0, 0.16, 0.62), true], ["Neon Cyan", Color(0.1, 0.88, 1.0), true],
	["Neon Purple", Color(0.62, 0.28, 1.0), true], ["Neon Lime", Color(0.45, 1.0, 0.3), true],
	["Neon Amber", Color(1.0, 0.58, 0.12), true],
]
const FACIAL_HAIR := ["None", "Stubble", "Moustache", "Goatee", "Full beard", "Chin strap"]
## id -> label
const CYBERWARE := {
	&"led_line": "LED line under the eye",
	&"jaw_plate": "Metal jaw plate",
	&"optic_eye": "Optic eye implant",
	&"temple_chrome": "Chrome temple plate",
	&"cheek_ports": "Cheek data ports",
}
const TATTOO_DESIGNS := {
	&"koi": "Koi", &"dragon": "Dragon", &"circuit": "Circuit", &"barcode": "Barcode",
	&"geometric": "Geometric", &"tribal_cyber": "Tribal-cyber", &"lotus": "Lotus", &"wave": "Wave",
}
const TATTOO_ZONES := {
	&"forearm_r": "Right forearm", &"forearm_l": "Left forearm", &"upper_arm_r": "Right upper arm",
	&"upper_arm_l": "Left upper arm", &"chest": "Chest", &"back": "Back", &"neck": "Neck",
	&"hand_r": "Right hand", &"hand_l": "Left hand", &"face": "Face",
}
## [label, colour]; glowing tattoos use the same colours as neon.
const TATTOO_COLORS := [
	["Ink black", Color(0.06, 0.06, 0.1)], ["Indigo", Color(0.18, 0.18, 0.55)], ["Red", Color(0.7, 0.08, 0.1)],
	["Teal", Color(0.05, 0.5, 0.5)], ["Pink", Color(1.0, 0.16, 0.62)], ["Cyan", Color(0.1, 0.88, 1.0)],
	["Lime", Color(0.45, 1.0, 0.3)], ["Amber", Color(1.0, 0.58, 0.12)], ["Purple", Color(0.62, 0.28, 1.0)],
]
const MAX_TATTOOS := 8
const FIRST_NAMES := ["Kai", "Rin", "Juno", "Taro", "Mika", "Zed", "Nova", "Aki", "Vex", "Sora", "Kenji", "Lux", "Yuki", "Ryo", "Ash", "Nami"]
