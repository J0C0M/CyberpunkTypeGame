@tool
class_name CharacterAtlas
extends RefCounted
## Layout of the character's 512x512 pixel-art texture: every face of every skin-textured box gets
## its own rectangle at about 160 pixels per metre. The layout is fixed (worked out once from the
## default body), so a tattoo zone always lands in the same place whatever the character looks
## like. A white block in the corner serves clothes and hair, which take their colour from the
## vertex colour instead.
##
## Faces are numbered like GeoBatch's boxes: 0 +X, 1 -X, 2 +Y (top), 3 -Y (bottom), 4 +Z (back),
## 5 -Z (front, the face). Each face's texture runs along its u axis (left to right) and v axis
## (bottom to top), as seen from outside the box.

const SIZE := 512
const PIXELS_PER_METRE := 160.0
## Per face: outward normal, u axis, v axis.
const FACES := [
	[Vector3.RIGHT, Vector3(0, 0, -1), Vector3.UP],
	[Vector3.LEFT, Vector3(0, 0, 1), Vector3.UP],
	[Vector3.UP, Vector3.RIGHT, Vector3(0, 0, -1)],
	[Vector3.DOWN, Vector3.RIGHT, Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3.RIGHT, Vector3.UP],
	[Vector3(0, 0, -1), Vector3.LEFT, Vector3.UP],
]
const WHITE := Rect2i(SIZE - 8, SIZE - 8, 8, 8)
## Skin-textured boxes besides the body regions (the head's details).
const EXTRA_BOXES := {
	&"jaw": Vector3(0.2, 0.06, 0.2),
	&"nose": Vector3(0.03, 0.055, 0.025),
	&"ear_l": Vector3(0.03, 0.06, 0.05),
	&"ear_r": Vector3(0.03, 0.06, 0.05),
}

static var _rects := {}


## The pixel rectangle of `face` (0-5) of box `key` (a region name or an EXTRA_BOXES key).
static func face_rect(key: StringName, face: int) -> Rect2i:
	_layout()
	return _rects.get(key, [WHITE, WHITE, WHITE, WHITE, WHITE, WHITE])[face]


## The same rectangle in UV coordinates (0-1).
static func face_uv(key: StringName, face: int) -> Rect2:
	var rect := face_rect(key, face)
	return Rect2(Vector2(rect.position) / SIZE, Vector2(rect.size) / SIZE)


static func white_uv() -> Rect2:
	return Rect2(Vector2(WHITE.position + Vector2i(3, 3)) / SIZE, Vector2(2, 2) / SIZE)


## Width and height of a face of a box of `size`.
static func face_size(size: Vector3, face: int) -> Vector2:
	var u: Vector3 = FACES[face][1]
	var v: Vector3 = FACES[face][2]
	return Vector2(absf(u.dot(size)), absf(v.dot(size)))


static func _layout() -> void:
	if not _rects.is_empty():
		return
	var boxes := {}
	for region in CharacterRig.REGIONS:
		var info: Dictionary = CharacterRig.REGIONS[region]
		boxes[region] = info["size"] + info["frame"] * 0.5 + info["muscle"] * 0.35
	for key in EXTRA_BOXES:
		boxes[key] = EXTRA_BOXES[key]
	# Every face as [key, face, width, height] in pixels, tallest first (shelf packing).
	var pieces := []
	for key in boxes:
		for face in 6:
			var px := (face_size(boxes[key], face) * PIXELS_PER_METRE).round()
			pieces.append([key, face, maxi(2, int(px.x)), maxi(2, int(px.y))])
	pieces.sort_custom(func(a: Array, b: Array) -> bool: return a[3] > b[3])
	var x := 1
	var y := 1
	var shelf := 0
	for piece in pieces:
		var w: int = piece[2]
		var h: int = piece[3]
		if x + w + 1 > SIZE:
			x = 1
			y += shelf + 1
			shelf = 0
		if not _rects.has(piece[0]):
			_rects[piece[0]] = [WHITE, WHITE, WHITE, WHITE, WHITE, WHITE]
		_rects[piece[0]][piece[1]] = Rect2i(x, y, w, h)
		x += w + 1
		shelf = maxi(shelf, h)
	assert(y + shelf < WHITE.position.y, "Character atlas overflow")
