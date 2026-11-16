@tool
class_name CharacterData
extends Resource
## Everything that makes up the player character's look: name, face, hair, body, tattoos and the
## starting outfit. Indices point into CharacterOptions. Saved as its own "character" section in
## every save slot (to_dict/from_dict) and used by CharacterModel to build the body.

## Folder name of this character's saves (set when the character is created).
@export var character_id := ""
@export var character_name := "Kai"

@export_group("Face")
@export var head_shape := 0
@export var skin_tone := 2
@export var eye_shape := 2
@export var eye_color := 0
@export var brows := 1
@export var nose := 1
@export var mouth := 0
@export var hair_style := 2
@export var hair_color := 0
@export var facial_hair := 0
@export var cyberware: Array[StringName] = []

@export_group("Body")
## 0 = slim, 1 = very muscular (a blend shape on every body part).
@export_range(0.0, 1.0) var muscle := 0.35
## 0 = narrow, 1 = broad shoulders and hips.
@export_range(0.0, 1.0) var frame := 0.5
## 0 = short, 1 = tall.
@export_range(0.0, 1.0) var height := 0.5

@export_group("Tattoos and outfit")
## [{"design": StringName, "zone": StringName, "color": int, "glow": bool}]
@export var tattoos: Array[Dictionary] = []
## Item id of the starting outfit (an ItemData with category "clothing").
@export var outfit := &"outfit_street_runner"


func to_dict() -> Dictionary:
	var ink := []
	for tattoo in tattoos:
		ink.append({"design": String(tattoo["design"]), "zone": String(tattoo["zone"]), "color": int(tattoo["color"]), "glow": bool(tattoo["glow"])})
	var chrome := []
	for part in cyberware:
		chrome.append(String(part))
	return {
		"id": character_id, "name": character_name,
		"head_shape": head_shape, "skin_tone": skin_tone, "eye_shape": eye_shape, "eye_color": eye_color,
		"brows": brows, "nose": nose, "mouth": mouth, "hair_style": hair_style, "hair_color": hair_color,
		"facial_hair": facial_hair, "cyberware": chrome,
		"muscle": muscle, "frame": frame, "height": height,
		"tattoos": ink, "outfit": String(outfit),
	}


static func from_dict(data: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.character_id = str(data.get("id", ""))
	c.character_name = str(data.get("name", "Kai"))
	c.head_shape = _index(data, "head_shape", CharacterOptions.HEAD_SHAPES.size(), c.head_shape)
	c.skin_tone = _index(data, "skin_tone", CharacterOptions.SKIN_TONES.size(), c.skin_tone)
	c.eye_shape = _index(data, "eye_shape", CharacterOptions.EYE_SHAPES.size(), c.eye_shape)
	c.eye_color = _index(data, "eye_color", CharacterOptions.EYE_COLORS.size(), c.eye_color)
	c.brows = _index(data, "brows", CharacterOptions.BROWS.size(), c.brows)
	c.nose = _index(data, "nose", CharacterOptions.NOSES.size(), c.nose)
	c.mouth = _index(data, "mouth", CharacterOptions.MOUTHS.size(), c.mouth)
	c.hair_style = _index(data, "hair_style", CharacterOptions.HAIR_STYLES.size(), c.hair_style)
	c.hair_color = _index(data, "hair_color", CharacterOptions.HAIR_COLORS.size(), c.hair_color)
	c.facial_hair = _index(data, "facial_hair", CharacterOptions.FACIAL_HAIR.size(), c.facial_hair)
	for part in data.get("cyberware", []):
		if CharacterOptions.CYBERWARE.has(StringName(part)):
			c.cyberware.append(StringName(part))
	c.muscle = clampf(float(data.get("muscle", c.muscle)), 0.0, 1.0)
	c.frame = clampf(float(data.get("frame", c.frame)), 0.0, 1.0)
	c.height = clampf(float(data.get("height", c.height)), 0.0, 1.0)
	for tattoo in data.get("tattoos", []):
		var design := StringName(tattoo.get("design", ""))
		var zone := StringName(tattoo.get("zone", ""))
		if CharacterOptions.TATTOO_DESIGNS.has(design) and CharacterOptions.TATTOO_ZONES.has(zone):
			c.tattoos.append({"design": design, "zone": zone, "color": clampi(int(tattoo.get("color", 0)), 0, CharacterOptions.TATTOO_COLORS.size() - 1), "glow": bool(tattoo.get("glow", false))})
	c.outfit = StringName(data.get("outfit", c.outfit))
	return c


static func _index(data: Dictionary, key: String, count: int, fallback: int) -> int:
	return clampi(int(data.get(key, fallback)), 0, count - 1)


## A random but coherent look (the creator's Randomize button).
func randomize_look(rng: RandomNumberGenerator) -> void:
	head_shape = rng.randi() % CharacterOptions.HEAD_SHAPES.size()
	skin_tone = rng.randi() % CharacterOptions.SKIN_TONES.size()
	eye_shape = rng.randi() % CharacterOptions.EYE_SHAPES.size()
	eye_color = rng.randi() % CharacterOptions.EYE_COLORS.size()
	brows = rng.randi() % CharacterOptions.BROWS.size()
	nose = rng.randi() % CharacterOptions.NOSES.size()
	mouth = rng.randi() % CharacterOptions.MOUTHS.size()
	hair_style = rng.randi() % CharacterOptions.HAIR_STYLES.size()
	hair_color = rng.randi() % CharacterOptions.HAIR_COLORS.size()
	facial_hair = rng.randi() % CharacterOptions.FACIAL_HAIR.size() if rng.randf() < 0.5 else 0
	cyberware.clear()
	for part: StringName in CharacterOptions.CYBERWARE:
		if rng.randf() < 0.18:
			cyberware.append(part)
	muscle = rng.randf()
	frame = rng.randf()
	height = rng.randf()
	tattoos.clear()
	var designs := CharacterOptions.TATTOO_DESIGNS.keys()
	var zones := CharacterOptions.TATTOO_ZONES.keys()
	zones.shuffle()
	for i in rng.randi_range(0, 4):
		tattoos.append({"design": designs[rng.randi() % designs.size()], "zone": zones[i], "color": rng.randi() % CharacterOptions.TATTOO_COLORS.size(), "glow": rng.randf() < 0.3})
	var outfits := Outfits.ids()
	outfit = outfits[rng.randi() % outfits.size()]


## A fresh unique folder name for this character's saves.
static func new_id(name: String) -> String:
	var slug := ""
	for ch in name.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			slug += ch
	return "%s_%d" % [slug if slug != "" else "tenant", Time.get_unix_time_from_system()]
