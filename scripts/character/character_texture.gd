@tool
class_name CharacterTexture
extends RefCounted
## Paints a character's pixel-art textures (see CharacterAtlas for the layout): skin with a little
## shading, the face (eyes, brows, mouth, facial hair, face cyberware), the white underpants with
## hearts that every character wears under everything, and the tattoos. A second texture holds
## what glows: neon tattoos, LED cyberware and cyber eyes.

const UNDERWEAR := Color(0.96, 0.96, 0.94)
const HEART := Color(0.92, 0.16, 0.32)
const HEART_MASK := [".#.#.", "#####", ".###.", "..#.."]
## Eye patterns ("w" white, "i" iris, "p" pupil, "l" lid), the character's right eye; mirrored for the left.
const EYES := [
	[".ll.", "wipw", ".ww."],
	["llll", "wipw"],
	[".lll", "wipw", "..w."],
	["lllll", "wiipw", ".www."],
	["llll", "lipl"],
]


## Returns [albedo, emission] ImageTextures for `data`.
static func paint(data: CharacterData) -> Array[ImageTexture]:
	var albedo := Image.create(CharacterAtlas.SIZE, CharacterAtlas.SIZE, false, Image.FORMAT_RGBA8)
	var glow := Image.create(CharacterAtlas.SIZE, CharacterAtlas.SIZE, false, Image.FORMAT_RGBA8)
	albedo.fill(Color(0.5, 0.5, 0.5))
	glow.fill(Color.BLACK)
	albedo.fill_rect(CharacterAtlas.WHITE, Color.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(data.character_name) ^ data.skin_tone
	var skin := CharacterOptions.SKIN_TONES[data.skin_tone]
	var keys: Array = CharacterRig.REGIONS.keys() + CharacterAtlas.EXTRA_BOXES.keys()
	for key: StringName in keys:
		for face in 6:
			_skin_face(albedo, CharacterAtlas.face_rect(key, face), skin, face, rng)
	_paint_details(albedo, skin)
	_paint_underwear(albedo)
	_paint_face(albedo, glow, data, skin, rng)
	for tattoo in data.tattoos:
		_paint_tattoo(albedo, glow, tattoo)
	var result: Array[ImageTexture] = [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(glow)]
	return result


static func _skin_face(image: Image, rect: Rect2i, skin: Color, face: int, rng: RandomNumberGenerator) -> void:
	var shade: float = [0.97, 0.97, 1.06, 0.8, 0.93, 1.0][face]
	var base := Color(skin.r * shade, skin.g * shade, skin.b * shade)
	image.fill_rect(rect, base)
	# A few darker pixels so big faces don't look like plastic.
	for i in rect.get_area() / 14:
		var p := rect.position + Vector2i(rng.randi() % maxi(1, rect.size.x), rng.randi() % maxi(1, rect.size.y))
		image.set_pixelv(p, base.darkened(0.06))


## Knuckles, toes, a navel.
static func _paint_details(image: Image, skin: Color) -> void:
	var line := skin.darkened(0.25)
	for hand: StringName in [&"hand_l", &"hand_r"]:
		var back := CharacterAtlas.face_rect(hand, 0 if hand == &"hand_r" else 1)
		for i in range(1, 4):
			var x := back.position.x + back.size.x * i / 4
			for y in range(back.position.y + back.size.y / 2, back.end.y):
				image.set_pixel(x, y, line)
	for foot: StringName in [&"foot_l", &"foot_r"]:
		var top := CharacterAtlas.face_rect(foot, 2)
		for x in range(top.position.x, top.end.x, 2):
			image.set_pixel(x, top.position.y + 1, line)
	var belly := CharacterAtlas.face_rect(&"abdomen", 5)
	image.set_pixel(belly.position.x + belly.size.x / 2, belly.position.y + belly.size.y * 2 / 3, line)


## White briefs with little red hearts: the whole pelvis and the top of the thighs.
static func _paint_underwear(image: Image) -> void:
	for face in 6:
		_briefs(image, CharacterAtlas.face_rect(&"pelvis", face), 1.0, face != 2)
	for thigh: StringName in [&"thigh_l", &"thigh_r"]:
		for face: int in [0, 1, 4, 5]:
			_briefs(image, CharacterAtlas.face_rect(thigh, face), 0.22, false)


static func _briefs(image: Image, rect: Rect2i, top_share: float, waistband: bool) -> void:
	var area := Rect2i(rect.position, Vector2i(rect.size.x, maxi(1, int(rect.size.y * top_share))))
	image.fill_rect(area, UNDERWEAR)
	if waistband:
		image.fill_rect(Rect2i(rect.position, Vector2i(rect.size.x, 2)), Color(0.78, 0.78, 0.82))
	var row := 0
	for y in range(area.position.y + 3, area.end.y - 3, 6):
		var start := area.position.x + 1 + (3 if row % 2 == 1 else 0)
		for x in range(start, area.end.x - 4, 7):
			_stamp(image, HEART_MASK, Vector2i(x, y), HEART)
		row += 1


static func _stamp(image: Image, mask: Array, at: Vector2i, color: Color) -> void:
	for y in mask.size():
		var line: String = mask[y]
		for x in line.length():
			if line[x] == "#":
				image.set_pixel(at.x + x, at.y + y, color)


static func _paint_face(image: Image, glow: Image, data: CharacterData, skin: Color, rng: RandomNumberGenerator) -> void:
	var face := CharacterAtlas.face_rect(&"head", 5)
	var hair: Color = CharacterOptions.HAIR_COLORS[data.hair_color][1]
	var brow_color := hair.darkened(0.2) if data.hair_style != 0 else skin.darkened(0.45)
	var eye_y := face.position.y + int(face.size.y * 0.42)
	var right_x := face.position.x + int(face.size.x * 0.3)
	var left_x := face.position.x + int(face.size.x * 0.7)
	var iris := CharacterOptions.EYE_COLORS[data.eye_color]
	var cyber_eyes := data.eye_color == 5 or data.eye_color == 7
	var optic := data.cyberware.has(&"optic_eye")
	for side in 2:
		var center := right_x if side == 0 else left_x
		var pattern: Array = EYES[data.eye_shape]
		var width: int = (pattern[0] as String).length()
		for y in pattern.size():
			var line: String = pattern[y]
			for x in width:
				var ch := line[x] if side == 0 else line[width - 1 - x]
				var p := Vector2i(center - width / 2 + x, eye_y - 1 + y)
				match ch:
					"w":
						image.set_pixelv(p, Color(0.95, 0.95, 0.92))
					"i":
						image.set_pixelv(p, iris)
						if cyber_eyes:
							glow.set_pixelv(p, iris * 0.6)
					"p":
						image.set_pixelv(p, Color(0.04, 0.03, 0.04))
					"l":
						image.set_pixelv(p, skin.darkened(0.35))
		if optic and side == 0:
			# The optic implant replaces the right eye: a red ring that glows.
			for offset: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
				image.set_pixelv(Vector2i(center, eye_y) + offset, Color(0.35, 0.35, 0.38))
			image.set_pixel(center, eye_y, Palette.RED)
			glow.set_pixel(center, eye_y, Palette.RED)
		_paint_brow(image, data.brows, center, eye_y - 3, side, brow_color)
	_paint_mouth(image, data.mouth, face.position.x + face.size.x / 2, face.position.y + int(face.size.y * 0.78), skin)
	_paint_facial_hair(image, data.facial_hair, face, hair.darkened(0.1), rng)
	if data.cyberware.has(&"led_line"):
		for x in range(right_x - 3, right_x + 3):
			image.set_pixel(x, eye_y + 3, Palette.CYAN)
			glow.set_pixel(x, eye_y + 3, Palette.CYAN)
	if data.cyberware.has(&"cheek_ports"):
		for i in 3:
			var p := Vector2i(left_x - 1 + i * 2, eye_y + 5 + (i % 2))
			image.set_pixelv(p, Color(0.08, 0.08, 0.1))
			image.set_pixelv(p + Vector2i(0, 1), Color(0.55, 0.55, 0.6))


static func _paint_brow(image: Image, style: int, center: int, y: int, side: int, color: Color) -> void:
	var outward := -1 if side == 0 else 1
	match style:
		1:
			for x in range(-2, 2):
				image.set_pixel(center + x, y, color)
		2:
			for x in range(-2, 3):
				image.set_pixel(center + x, y, color)
				image.set_pixel(center + x, y - 1, color)
		3:
			# Angry: low at the nose, high at the outside.
			for i in 5:
				image.set_pixel(center - outward * 2 + outward * i, y + (1 if i < 2 else 0) - (1 if i > 3 else 0), color)
		4:
			for i in 5:
				image.set_pixel(center - 2 + i, y - (1 if i > 0 and i < 4 else 0), color)


static func _paint_mouth(image: Image, style: int, center: int, y: int, skin: Color) -> void:
	var lip := skin.darkened(0.4).lerp(Color(0.55, 0.15, 0.2), 0.35)
	for x in range(-3, 3):
		image.set_pixel(center + x, y, lip)
	match style:
		1:
			image.set_pixel(center - 4, y - 1, lip)
			image.set_pixel(center + 3, y - 1, lip)
		2:
			image.set_pixel(center - 4, y + 1, lip)
			image.set_pixel(center + 3, y + 1, lip)
		3:
			for x in range(-2, 2):
				image.set_pixel(center + x, y + 1, lip.lightened(0.15))
		4:
			image.set_pixel(center + 3, y - 1, lip)


static func _paint_facial_hair(image: Image, style: int, face: Rect2i, color: Color, rng: RandomNumberGenerator) -> void:
	if style == 0:
		return
	var mouth_y := face.position.y + int(face.size.y * 0.78)
	var cx := face.position.x + face.size.x / 2
	match style:
		1:
			for i in face.size.x * 3:
				var p := Vector2i(face.position.x + rng.randi() % face.size.x, mouth_y - 3 + rng.randi() % maxi(1, face.end.y - mouth_y + 3))
				image.set_pixelv(p, color.lerp(image.get_pixelv(p), 0.4))
		2:
			image.fill_rect(Rect2i(cx - 4, mouth_y - 2, 8, 1), color)
		3:
			image.fill_rect(Rect2i(cx - 4, mouth_y - 2, 8, 1), color)
			image.fill_rect(Rect2i(cx - 2, mouth_y + 1, 4, face.end.y - mouth_y - 1), color)
		4:
			for y in range(mouth_y - 3, face.end.y):
				for x in range(face.position.x + 2, face.end.x - 2):
					if y != mouth_y or absi(x - cx) > 3:
						image.set_pixel(x, y, color)
			for jaw_face: int in [0, 1, 3, 5]:
				image.fill_rect(CharacterAtlas.face_rect(&"jaw", jaw_face), color)
		5:
			for y in range(mouth_y - 1, face.end.y):
				image.set_pixel(face.position.x + 2, y, color)
				image.set_pixel(face.end.x - 3, y, color)
			image.fill_rect(Rect2i(face.position.x + 2, face.end.y - 2, face.size.x - 4, 2), color)


## A tattoo zone -> the faces it is painted on, and the part of each face it may use (fractions).
static func _targets(zone: StringName) -> Array:
	var full := Rect2(0.1, 0.12, 0.8, 0.76)
	match zone:
		&"forearm_r":
			return [[&"forearm_r", 0, full], [&"forearm_r", 5, full]]
		&"forearm_l":
			return [[&"forearm_l", 1, full], [&"forearm_l", 5, full]]
		&"upper_arm_r":
			return [[&"upper_arm_r", 0, full], [&"upper_arm_r", 5, full]]
		&"upper_arm_l":
			return [[&"upper_arm_l", 1, full], [&"upper_arm_l", 5, full]]
		&"chest":
			return [[&"chest", 5, Rect2(0.15, 0.1, 0.7, 0.62)]]
		&"back":
			return [[&"chest", 4, Rect2(0.1, 0.08, 0.8, 0.84)], [&"abdomen", 4, Rect2(0.2, 0.05, 0.6, 0.6)]]
		&"neck":
			return [[&"neck", 5, full], [&"neck", 0, full], [&"neck", 1, full]]
		&"hand_r":
			return [[&"hand_r", 0, Rect2(0.05, 0.05, 0.9, 0.5)]]
		&"hand_l":
			return [[&"hand_l", 1, Rect2(0.05, 0.05, 0.9, 0.5)]]
		&"face":
			return [[&"head", 5, Rect2(0.06, 0.52, 0.3, 0.26)]]
	return []


static func _paint_tattoo(image: Image, glow: Image, tattoo: Dictionary) -> void:
	var color: Color = CharacterOptions.TATTOO_COLORS[int(tattoo["color"])][1]
	var glows := bool(tattoo["glow"])
	var mask := TattooDesigns.mask(tattoo["design"])
	var mask_h := mask.size()
	var mask_w: int = (mask[0] as Array).size()
	for target in _targets(tattoo["zone"]):
		var rect := CharacterAtlas.face_rect(target[0], target[1])
		var part: Rect2 = target[2]
		var area := Rect2i(rect.position + Vector2i((Vector2(rect.size) * part.position).floor()), Vector2i((Vector2(rect.size) * part.size).floor()))
		var scale := minf(float(area.size.x) / mask_w, float(area.size.y) / mask_h)
		var draw := Vector2i(maxi(2, int(mask_w * scale)), maxi(2, int(mask_h * scale)))
		var origin := area.position + (area.size - draw) / 2
		for y in draw.y:
			for x in draw.x:
				if mask[y * mask_h / draw.y][x * mask_w / draw.x]:
					image.set_pixel(origin.x + x, origin.y + y, color.lightened(0.35) if glows else color)
					if glows:
						glow.set_pixel(origin.x + x, origin.y + y, color)
