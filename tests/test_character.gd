extends Node3D
## Headless checks for the player model: skeleton, body regions, body masks under clothing,
## first-person layers, attachment slots, muscle blend shape, eye height, every option builds,
## and CharacterData survives a save round trip.
## Run: godot --headless --path . res://tests/test_character.tscn

var _failures := 0


func _ready() -> void:
	var data := CharacterData.new()
	var model := CharacterModel.new()
	model.data = data
	add_child(model)
	_check(model.skeleton.get_bone_count() == CharacterRig.BONES.size(), "the skeleton has %d bones" % CharacterRig.BONES.size())
	_check(model.region_part(&"chest") != null and model.region_part(&"foot_r") != null, "every body region has a part")
	_check(not model.region_part(&"pelvis").visible and not model.region_part(&"chest").visible, "skin under the outfit is hidden (body masks)")
	_check(model.region_part(&"head").visible and model.region_part(&"head").layers == CharacterRig.FIRST_PERSON_HIDDEN, "the head is on the first-person-hidden layer")
	_check(model.slot(&"hand_r") != null and model.slot(&"helmet") != null, "attachment slots exist")
	_check(absf(model.eye_height() - 1.62) < 0.03, "eye level at 1.62 m for the default build (%.3f)" % model.eye_height())
	model.set_muscle(1.0)
	_check(model.region_part(&"chest").get_blend_shape_value(0) == 1.0, "muscle drives the blend shape")
	model.show_outfit = false
	_check(model.region_part(&"pelvis").visible and model.skeleton.get_node_or_null("Wear_chest") == null, "underwear preview shows the body without clothes")
	model.show_outfit = true

	# Every option builds.
	var errors_before := 0
	for i in CharacterOptions.HEAD_SHAPES.size():
		data.head_shape = i
		model.rebuild()
	for i in CharacterOptions.HAIR_STYLES.size():
		data.hair_style = i
		model.rebuild()
	for i in CharacterOptions.FACIAL_HAIR.size():
		data.facial_hair = i
		model.rebuild()
	for id in Outfits.ids():
		data.outfit = id
		model.rebuild()
	data.cyberware.assign(CharacterOptions.CYBERWARE.keys())
	for design: StringName in CharacterOptions.TATTOO_DESIGNS:
		data.tattoos.clear()
		for zone: StringName in CharacterOptions.TATTOO_ZONES:
			data.tattoos.append({"design": design, "zone": zone, "color": 5, "glow": true})
		model.rebuild()
	_check(model.skeleton.get_bone_count() == CharacterRig.BONES.size(), "every head, hair, beard, outfit, cyberware and tattoo option builds")
	for item in Outfits.ids():
		for piece in Outfits.items(item):
			_check(ItemDB.has(piece) and ItemDB.category(piece) == &"clothing", "outfit piece %s is a clothing item" % piece)

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	data.randomize_look(rng)
	data.character_name = "Rin"
	var copy := CharacterData.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	var a := copy.to_dict()
	var b := data.to_dict()
	for key in b:
		if str(a[key]) != str(b[key]):
			print("  differs: ", key, " ", a[key], " vs ", b[key])
	_check(str(a) == str(b), "character data survives a JSON round trip")
	print("TESTS DONE: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures += 1
