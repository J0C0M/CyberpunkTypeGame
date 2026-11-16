@tool
class_name ShopInterior
extends Node3D
## A small shop the player can walk into: glass front (breakable) around a doorway, a neon sign,
## a counter with the merchant behind it and themed shelves, decor and lights. The CityBuilder
## places it on a lot and sets `width`; the building above starts at SHELL_TOP.
## Local space: the shop front is the plane z = 0 facing +Z (the street), the room runs to -DEPTH.
## A child named "Merchant" is moved behind the counter automatically.

enum Style { NOODLE, BAR, CYBERWARE, CLINIC, GUNS, PAWN }

const DEPTH := 10.0
const HEIGHT := 4.3
const FLOOR_Y := 0.15
const SHELL_TOP := 4.8
const DOOR_HALF := 0.9
const COUNTER_Z := -6.0

@export var theme := Style.NOODLE
## Lot width, set by the CityBuilder.
@export var width := 12.0
@export var place_id := &"shop"
@export var place_label := "Shop"
@export var sign_text := "SHOP"
@export var sign_subtext := ""
@export var accent := Color(1.0, 0.16, 0.62)
## Footstep surface of the floor ("wood", "tile", "metal", "concrete").
@export var floor_surface := &"tile"

var _geo: GeoBatch
var _body: StaticBody3D
var _root: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	BuildKit.clear_generated(self)
	_rng.seed = hash(place_id)
	_root = BuildKit.generated_root(self, "Generated")
	_geo = GeoBatch.new()
	_body = BuildKit.static_body(_root)
	_build_shell()
	_build_front()
	_build_counter()
	match theme:
		Style.NOODLE:
			_decor_noodle()
		Style.BAR:
			_decor_bar()
		Style.CYBERWARE:
			_decor_cyberware()
		Style.CLINIC:
			_decor_clinic()
		Style.GUNS:
			_decor_guns()
		Style.PAWN:
			_decor_pawn()
	_geo.build_into(_root, "ShopGeometry")
	var merchant := get_node_or_null("Merchant") as Node3D
	if merchant:
		merchant.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, FLOOR_Y, COUNTER_Z - 1.1))
	if not Engine.is_editor_hint():
		GameState.register_place(place_id, place_label, global_transform * Vector3(0, 0, 2.0))
		var tracks := ["noodle", "bar", "cyberware", "clinic", "guns", "pawn"]
		var music := load("res://assets/music/%s.ogg" % tracks[theme]) as AudioStream
		MusicZone.create(self, Vector3(width - 0.6, HEIGHT, DEPTH - 0.3), Vector3(0, HEIGHT * 0.5, -DEPTH * 0.5 - 0.15), music, Vector3(_half() - 0.5, HEIGHT - 0.4, -DEPTH + 0.6))


func _half() -> float:
	return width * 0.5 - 0.3


# --- Shell ------------------------------------------------------------------------------------

func _floor_color() -> Color:
	match theme:
		Style.NOODLE:
			return Color(0.26, 0.15, 0.09)
		Style.CLINIC:
			return Color(0.6, 0.65, 0.68)
		Style.CYBERWARE:
			return Color(0.14, 0.15, 0.18)
		Style.GUNS:
			return Color(0.2, 0.19, 0.18)
	return Color(0.12, 0.1, 0.12)


func _wall_color() -> Color:
	match theme:
		Style.NOODLE:
			return Color(0.35, 0.2, 0.14)
		Style.CLINIC:
			return Color(0.55, 0.62, 0.66)
		Style.CYBERWARE:
			return Color(0.1, 0.11, 0.15)
		Style.GUNS:
			return Color(0.36, 0.33, 0.3)
		Style.BAR:
			return Color(0.12, 0.06, 0.12)
	return Color(0.24, 0.2, 0.16)


func _build_shell() -> void:
	var half := width * 0.5
	var wall := MatLib.surface(_wall_color(), 0.75)
	_geo.add_box_at(Vector3(width, FLOOR_Y, DEPTH), Vector3(0, FLOOR_Y * 0.5, -DEPTH * 0.5), MatLib.surface(_floor_color(), 0.35, 0.0, 0.12))
	BuildKit.box_collider_at(_body, Vector3(width, 1.0, DEPTH), Vector3(0, FLOOR_Y - 0.5, -DEPTH * 0.5)).set_meta(&"surface", floor_surface)
	_geo.add_box_at(Vector3(width, 0.3, DEPTH), Vector3(0, HEIGHT + 0.15, -DEPTH * 0.5), MatLib.surface(Palette.METAL_DARK, 0.6))
	_geo.add_box_at(Vector3(width, HEIGHT, 0.3), Vector3(0, HEIGHT * 0.5, -DEPTH - 0.15), wall)
	BuildKit.box_collider_at(_body, Vector3(width, HEIGHT, 0.3), Vector3(0, HEIGHT * 0.5, -DEPTH - 0.15))
	for side: float in [-1.0, 1.0]:
		_geo.add_box_at(Vector3(0.3, HEIGHT, DEPTH), Vector3(side * (half - 0.15), HEIGHT * 0.5, -DEPTH * 0.5), wall)
		BuildKit.box_collider_at(_body, Vector3(0.3, HEIGHT, DEPTH), Vector3(side * (half - 0.15), HEIGHT * 0.5, -DEPTH * 0.5))
	# Skirting light along the floor in the accent colour.
	for side: float in [-1.0, 1.0]:
		_geo.add_bar(Vector3(side * (half - 0.32), 0.25, -0.5), Vector3(side * (half - 0.32), 0.25, -DEPTH + 0.2), 0.04, MatLib.neon(accent, 2.5))


func _build_front() -> void:
	var half := width * 0.5
	var frame := MatLib.surface(Palette.METAL_DARK, 0.35, 0.6)
	var pane_width := half - DOOR_HALF - 0.35
	for side: float in [-1.0, 1.0]:
		var cx := side * (DOOR_HALF + 0.1 + pane_width * 0.5)
		_geo.add_box_at(Vector3(pane_width + 0.2, 0.5, 0.3), Vector3(cx, 0.25, -0.15), frame)
		BuildKit.box_collider_at(_body, Vector3(pane_width + 0.2, 0.5, 0.3), Vector3(cx, 0.25, -0.15))
		BuildKit.glass_pane(_root, Transform3D(Basis.IDENTITY, Vector3(cx, 1.85, -0.15)), Vector3(pane_width, 2.7, 0.04), Color(accent.r * 0.4 + 0.3, 0.7, 1.0, 0.1))
		_geo.add_box_at(Vector3(0.14, 3.2, 0.34), Vector3(side * DOOR_HALF, 1.6, -0.15), frame)
		_geo.add_box_at(Vector3(0.3, SHELL_TOP, 0.4), Vector3(side * (half - 0.15), SHELL_TOP * 0.5, -0.1), frame)
		BuildKit.box_collider_at(_body, Vector3(0.3, SHELL_TOP, 0.4), Vector3(side * (half - 0.15), SHELL_TOP * 0.5, -0.1))
	_geo.add_box_at(Vector3(DOOR_HALF * 2.0, 0.55, 0.3), Vector3(0, 2.95, -0.15), frame)
	# Sign band with the shop name in neon.
	_geo.add_box_at(Vector3(width, SHELL_TOP - 3.2, 0.4), Vector3(0, (SHELL_TOP + 3.2) * 0.5, -0.2), MatLib.surface(Color(0.04, 0.035, 0.05), 0.4, 0.3))
	BuildKit.box_collider_at(_body, Vector3(width, SHELL_TOP - 2.65, 0.4), Vector3(0, (SHELL_TOP + 2.65) * 0.5, -0.2))
	var text_height := minf(0.7, (width - 1.5) * 0.85 / maxf(1.0, sign_text.length() * 0.62))
	BuildKit.neon_text(_root, sign_text, Transform3D(Basis.IDENTITY, Vector3(0, 4.0, 0.08)), accent, text_height)
	if sign_subtext != "":
		BuildKit.neon_text(_root, sign_subtext, Transform3D(Basis.IDENTITY, Vector3(-half + 1.1, 4.0, 0.08)), Palette.WARM_WHITE, 0.4)
	_geo.add_polyline(PackedVector3Array([Vector3(-half + 0.3, 3.4, 0.02), Vector3(half - 0.3, 3.4, 0.02), Vector3(half - 0.3, 4.6, 0.02), Vector3(-half + 0.3, 4.6, 0.02)]), 0.035, MatLib.neon(accent, 3.5), true)
	BuildKit.omni(_root, Vector3(0, 3.8, 1.5), accent, 2.5, 8.0)
	# An "OPEN" sign over the door glows on the inside.
	BuildKit.neon_text(_root, "OPEN", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 3.0, -0.35)), Palette.LIME, 0.25)


func _build_counter() -> void:
	var half := _half()
	var counter_color := Color(0.1, 0.08, 0.08) if theme != Style.CLINIC else Color(0.7, 0.74, 0.76)
	_geo.add_box_at(Vector3(half * 2.0, 1.05, 0.8), Vector3(0, FLOOR_Y + 0.525, COUNTER_Z), MatLib.surface(counter_color, 0.5))
	_geo.add_box_at(Vector3(half * 2.0 + 0.1, 0.06, 1.0), Vector3(0, FLOOR_Y + 1.08, COUNTER_Z + 0.08), MatLib.surface(counter_color.lightened(0.25), 0.3, 0.2))
	_geo.add_bar(Vector3(-half, FLOOR_Y + 0.1, COUNTER_Z + 0.42), Vector3(half, FLOOR_Y + 0.1, COUNTER_Z + 0.42), 0.04, MatLib.neon(accent, 3.0))
	BuildKit.box_collider_at(_body, Vector3(half * 2.0 + 0.1, 1.2, 1.0), Vector3(0, FLOOR_Y + 0.6, COUNTER_Z + 0.08))
	# A till on the counter.
	_geo.add_box_at(Vector3(0.4, 0.22, 0.3), Vector3(half - 0.8, FLOOR_Y + 1.22, COUNTER_Z), MatLib.surface(Palette.METAL_DARK, 0.4, 0.5))
	_geo.add_box_at(Vector3(0.3, 0.12, 0.02), Vector3(half - 0.8, FLOOR_Y + 1.28, COUNTER_Z + 0.16), MatLib.neon(Palette.CYAN, 1.5))
	BuildKit.omni(_root, Vector3(0, HEIGHT - 0.6, COUNTER_Z + 1.5), Palette.WARM_WHITE.lerp(accent, 0.35), 2.2, 9.0)
	BuildKit.omni(_root, Vector3(0, HEIGHT - 0.8, -DEPTH + 1.5), accent, 1.4, 6.0)


## Shelves along the back wall with `count` rows of small items made by `item_maker`.
func _back_shelves(rows: int, item_maker: Callable) -> void:
	var half := _half()
	var shelf := MatLib.surface(Palette.METAL_DARK if theme != Style.NOODLE else Palette.WOOD, 0.5, 0.3)
	for row in rows:
		var y := 1.3 + row * 0.6
		_geo.add_box_at(Vector3(half * 2.0 - 0.6, 0.05, 0.4), Vector3(0, y, -DEPTH + 0.25), shelf)
		var x := -half + 0.5
		while x < half - 0.5:
			item_maker.call(Vector3(x, y + 0.03, -DEPTH + 0.25))
			x += _rng.randf_range(0.3, 0.55)


func _stools(count: int, seat: Color) -> void:
	var chrome := MatLib.surface(Palette.METAL, 0.25, 0.9)
	var vinyl := MatLib.surface(seat, 0.45)
	var spacing := (_half() * 2.0 - 1.0) / maxf(1.0, count - 1)
	for i in count:
		var base := Vector3(-_half() + 0.5 + i * spacing, FLOOR_Y, COUNTER_Z + 1.0)
		_geo.add_cylinder(0.035, 0.035, 0.75, 6, Transform3D(Basis.IDENTITY, base + Vector3.UP * 0.375), chrome)
		_geo.add_cylinder(0.2, 0.2, 0.03, 8, Transform3D(Basis.IDENTITY, base + Vector3.UP * 0.015), chrome)
		_geo.add_cylinder(0.2, 0.2, 0.08, 10, Transform3D(Basis.IDENTITY, base + Vector3.UP * 0.79), vinyl)


# --- Themes -----------------------------------------------------------------------------------

func _decor_noodle() -> void:
	_stools(maxi(3, int(width / 1.4)), Color(0.55, 0.06, 0.08))
	# Big steaming stock pots on the back counter.
	var steel := MatLib.surface(Palette.METAL, 0.3, 0.85)
	_geo.add_box_at(Vector3(_half() * 2.0 - 0.4, 0.95, 0.8), Vector3(0, FLOOR_Y + 0.475, -DEPTH + 0.6), MatLib.surface(Color(0.15, 0.13, 0.12), 0.5, 0.4))
	for x: float in [-1.4, 0.0, 1.4]:
		var pot := Vector3(x, FLOOR_Y + 1.25, -DEPTH + 0.6)
		_geo.add_cylinder(0.32, 0.3, 0.6, 10, Transform3D(Basis.IDENTITY, pot), steel)
		_geo.add_cylinder(0.3, 0.3, 0.02, 10, Transform3D(Basis.IDENTITY, pot + Vector3.UP * 0.25), MatLib.surface(Color(0.6, 0.4, 0.2), 0.2))
		_geo.add_cylinder(0.35, 0.35, 0.04, 10, Transform3D(Basis.IDENTITY, pot - Vector3.UP * 0.32), MatLib.neon(Palette.AMBER, 2.0))
		if not Engine.is_editor_hint():
			var steam := BuildKit.steam(pot + Vector3.UP * 0.35, 10, 0.7)
			_root.add_child(steam)
	# Hanging red lanterns and a glowing menu.
	var lantern := MatLib.neon(Color(1.0, 0.18, 0.12), 2.2)
	for i in 3:
		var pos := Vector3(-_half() * 0.6 + i * _half() * 0.6, 3.4, COUNTER_Z + 0.6)
		_geo.add_sphere(0.25, Transform3D(Basis.from_scale(Vector3(1, 1.3, 1)), pos), lantern, 8, 6)
		_geo.add_bar(pos + Vector3.UP * 0.32, Vector3(pos.x, HEIGHT, pos.z), 0.015, MatLib.surface(Color.BLACK))
	_geo.add_box_at(Vector3(2.4, 1.0, 0.05), Vector3(0, 3.1, -DEPTH + 0.05), MatLib.neon(Color(1.0, 0.92, 0.78), 1.1))
	BuildKit.flat_text(_root, "SHOYU   ¥18\nMISO    ¥18\nONIGIRI ¥7", Transform3D(Basis.IDENTITY, Vector3(0, 3.1, -DEPTH + 0.09)), Color(0.1, 0.03, 0.05), 0.2)
	# Noren curtain over the door.
	var noren := MatLib.surface(Color(0.05, 0.08, 0.3), 0.9)
	for i in 3:
		_geo.add_box_at(Vector3(0.56, 0.55, 0.02), Vector3(-0.6 + i * 0.6, 2.35, -0.05), noren)


func _decor_bar() -> void:
	_stools(maxi(3, int(width / 1.3)), Color(0.15, 0.05, 0.3))
	_back_shelves(3, _bottle)
	# Beer taps and a jukebox.
	for i in 4:
		var tap := Vector3(-0.6 + i * 0.4, FLOOR_Y + 1.35, COUNTER_Z - 0.2)
		_geo.add_bar(tap, tap + Vector3.UP * 0.35, 0.04, MatLib.surface(Palette.METAL, 0.2, 0.9))
		_geo.add_box_at(Vector3(0.06, 0.1, 0.06), tap + Vector3.UP * 0.4, MatLib.neon(Palette.NEONS[i], 3.0))
	var juke := Vector3(_half() - 0.6, FLOOR_Y, -1.2)
	_geo.add_box_at(Vector3(0.9, 1.6, 0.6), juke + Vector3.UP * 0.8, MatLib.surface(Color(0.2, 0.05, 0.15), 0.4))
	_geo.add_box_at(Vector3(0.7, 0.6, 0.02), juke + Vector3(0, 1.1, 0.31), MatLib.neon(Palette.PINK, 1.8))
	_geo.add_box_at(Vector3(0.75, 0.05, 0.62), juke + Vector3.UP * 0.5, MatLib.neon(Palette.CYAN, 3.0))
	BuildKit.box_collider_at(_body, Vector3(0.9, 1.6, 0.6), juke + Vector3.UP * 0.8)
	BuildKit.neon_text(_root, "BAR", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-width * 0.5 + 0.32, 2.8, -4.0)), Palette.CYAN, 0.8)


func _decor_cyberware() -> void:
	# Glass display cases with glowing implants.
	for side: float in [-1.0, 1.0]:
		var case_pos := Vector3(side * (_half() - 0.8), FLOOR_Y, -2.8)
		_geo.add_box_at(Vector3(1.2, 0.9, 2.4), case_pos + Vector3.UP * 0.45, MatLib.surface(Palette.METAL_DARK, 0.4, 0.6))
		_geo.add_box_at(Vector3(1.2, 0.5, 2.4), case_pos + Vector3.UP * 1.15, MatLib.glass(Color(0.5, 0.3, 1.0, 0.15)))
		BuildKit.box_collider_at(_body, Vector3(1.2, 1.4, 2.4), case_pos + Vector3.UP * 0.7)
		for i in 4:
			var item := case_pos + Vector3(_rng.randf_range(-0.3, 0.3), 1.0, -0.8 + i * 0.55)
			if i % 2 == 0:
				_geo.add_sphere(0.08, Transform3D(Basis.IDENTITY, item), MatLib.glowing_surface(Color(0.8, 0.8, 0.85), Palette.RED, 2.5), 8, 5)
			else:
				_geo.add_bar(item, item + Vector3(0.0, 0.0, 0.35), 0.05, MatLib.glowing_surface(Palette.METAL, Palette.PURPLE, 1.5))
		_geo.add_bar(case_pos + Vector3(-0.6, 0.92, -1.2), case_pos + Vector3(-0.6, 0.92, 1.2), 0.02, MatLib.neon(Palette.PURPLE, 3.0))
	# A robotic arm on the back wall and holographic adverts.
	var arm := MatLib.surface(Palette.METAL, 0.3, 0.9)
	var base := Vector3(-1.5, 2.2, -DEPTH + 0.3)
	_geo.add_bar(base, base + Vector3(0.5, 0.6, 0.2), 0.12, arm)
	_geo.add_bar(base + Vector3(0.5, 0.6, 0.2), base + Vector3(1.2, 0.4, 0.4), 0.09, arm)
	_geo.add_box_at(Vector3(0.12, 0.12, 0.12), base + Vector3(1.2, 0.4, 0.4), MatLib.neon(Palette.CYAN, 4.0))
	for x: float in [1.0, 2.4]:
		_geo.add_quad(Vector2(1.2, 1.6), Transform3D(Basis.IDENTITY, Vector3(x, 2.6, -DEPTH + 0.02)), MatLib.holo_ad(Palette.PURPLE, Palette.CYAN, _rng.randi() % 4, _rng.randf() * 10.0, 2.0))


func _decor_clinic() -> void:
	var white := MatLib.surface(Color(0.8, 0.84, 0.86), 0.4)
	_back_shelves(2, _vial)
	# Treatment bed and a green neon cross.
	var bed := Vector3(-_half() + 1.2, FLOOR_Y, -2.6)
	_geo.add_box_at(Vector3(0.9, 0.6, 2.0), bed + Vector3.UP * 0.3, white)
	_geo.add_box_at(Vector3(0.85, 0.12, 1.9), bed + Vector3.UP * 0.66, MatLib.surface(Color(0.3, 0.6, 0.6), 0.6))
	BuildKit.box_collider_at(_body, Vector3(0.9, 0.7, 2.0), bed + Vector3.UP * 0.35)
	var cross := MatLib.neon(Palette.LIME, 4.0)
	var center := Vector3(0, 3.2, -DEPTH + 0.05)
	_geo.add_box_at(Vector3(0.8, 0.25, 0.05), center, cross)
	_geo.add_box_at(Vector3(0.25, 0.8, 0.05), center, cross)
	# Bright cabinets on the side wall.
	for i in 3:
		var cabinet := Vector3(_half() - 0.3, 1.6, -1.5 - i * 1.0)
		_geo.add_box_at(Vector3(0.4, 1.6, 0.8), cabinet, white)
		_geo.add_box_at(Vector3(0.02, 1.2, 0.6), cabinet + Vector3(-0.21, 0.1, 0), MatLib.neon(Palette.COOL_WHITE, 0.9))
	BuildKit.omni(_root, Vector3(0, HEIGHT - 0.5, -3.0), Palette.COOL_WHITE, 2.0, 9.0)


func _decor_guns() -> void:
	# Rifles hanging on wall racks.
	var gun := MatLib.surface(Color(0.05, 0.05, 0.06), 0.4, 0.7)
	var wood := MatLib.surface(Palette.WOOD, 0.5)
	for row in 2:
		for i in int(_half() * 2.0 / 0.9):
			var pos := Vector3(-_half() + 0.6 + i * 0.9, 1.8 + row * 0.9, -DEPTH + 0.15)
			_geo.add_box_at(Vector3(0.75, 0.07, 0.05), pos, gun)
			_geo.add_box_at(Vector3(0.22, 0.09, 0.05), pos + Vector3(0.4, -0.02, 0), wood)
			_geo.add_box_at(Vector3(0.05, 0.16, 0.04), pos + Vector3(-0.05, -0.1, 0), gun)
	_geo.add_bar(Vector3(-_half() + 0.2, 3.5, -DEPTH + 0.1), Vector3(_half() - 0.2, 3.5, -DEPTH + 0.1), 0.05, MatLib.neon(Palette.RED, 3.5))
	_geo.add_bar(Vector3(-_half() + 0.2, HEIGHT - 0.1, -DEPTH + 0.8), Vector3(_half() - 0.2, HEIGHT - 0.1, -DEPTH + 0.8), 0.08, MatLib.neon(Palette.WARM_WHITE, 3.0))
	BuildKit.omni(_root, Vector3(0, HEIGHT - 0.6, -DEPTH + 1.2), Palette.WARM_WHITE, 1.8, 6.0)
	# Ammo crates stacked by the door.
	var olive := MatLib.surface(Color(0.2, 0.24, 0.12), 0.7)
	for i in 4:
		var crate := Vector3(_half() - 0.6, FLOOR_Y + 0.25 + (i % 2) * 0.5, -1.0 - floorf(i / 2.0) * 0.7)
		_geo.add_box_at(Vector3(0.9, 0.5, 0.6), crate, olive)
		_geo.add_box_at(Vector3(0.92, 0.06, 0.005), crate + Vector3(0, -0.12, 0.3), MatLib.surface(Color(0.85, 0.7, 0.1), 0.6))
	BuildKit.box_collider_at(_body, Vector3(0.9, 1.0, 1.4), Vector3(_half() - 0.6, FLOOR_Y + 0.5, -1.35))
	BuildKit.neon_text(_root, "NO REFUNDS", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-width * 0.5 + 0.32, 2.6, -3.5)), Palette.RED, 0.35)


func _decor_pawn() -> void:
	_back_shelves(3, _junk)
	# Security grille over the counter and a guitar on the wall.
	var grille := MatLib.surface(Palette.METAL, 0.4, 0.8)
	var x := -_half()
	while x <= _half():
		_geo.add_bar(Vector3(x, FLOOR_Y + 1.15, COUNTER_Z + 0.3), Vector3(x, HEIGHT, COUNTER_Z + 0.3), 0.02, grille)
		x += 0.6
	var guitar := Vector3(_half() - 0.35, 2.4, -3.0)
	_geo.add_box(Vector3(0.05, 0.5, 0.36), Transform3D(Basis(Vector3.RIGHT, 0.2), guitar), MatLib.surface(Color(0.5, 0.15, 0.05), 0.4))
	_geo.add_bar(guitar + Vector3(0, 0.25, 0.05), guitar + Vector3(0, 0.95, 0.2), 0.04, MatLib.surface(Palette.WOOD, 0.5))
	BuildKit.neon_text(_root, "WE BUY ANYTHING", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(width * 0.5 - 0.32, 3.2, -4.0)), Palette.AMBER, 0.3)


# --- Shelf items ------------------------------------------------------------------------------

func _bottle(pos: Vector3) -> void:
	var color: Color = Palette.NEONS[_rng.randi() % Palette.NEONS.size()]
	_geo.add_cylinder(0.06, 0.06, 0.32, 6, Transform3D(Basis.IDENTITY, pos + Vector3.UP * 0.16), MatLib.glowing_surface(color.darkened(0.6), color, 1.2))
	_geo.add_cylinder(0.025, 0.025, 0.12, 5, Transform3D(Basis.IDENTITY, pos + Vector3.UP * 0.38), MatLib.surface(Palette.METAL_DARK, 0.4))


func _vial(pos: Vector3) -> void:
	var color := Palette.LIME if _rng.randf() < 0.6 else Palette.CYAN
	_geo.add_cylinder(0.05, 0.05, 0.2, 6, Transform3D(Basis.IDENTITY, pos + Vector3.UP * 0.1), MatLib.glowing_surface(color.darkened(0.5), color, 1.4))


## Pawn-shop clutter: old TVs, white boxes, odds and ends.
func _junk(pos: Vector3) -> void:
	var roll := _rng.randf()
	if roll < 0.3:
		_geo.add_box_at(Vector3(0.32, 0.26, 0.26), pos + Vector3.UP * 0.13, MatLib.surface(Color(0.15, 0.14, 0.12), 0.5))
		_geo.add_box_at(Vector3(0.24, 0.18, 0.01), pos + Vector3(0, 0.14, 0.13), MatLib.neon(Palette.CYAN.lerp(Color.WHITE, 0.4), 1.0))
	elif roll < 0.55:
		_geo.add_box_at(Vector3(0.18, 0.22, 0.14), pos + Vector3.UP * 0.11, MatLib.surface(Color(0.92, 0.9, 0.85), 0.5))
	else:
		_geo.add_box_at(Vector3(0.2, _rng.randf_range(0.1, 0.35), 0.2), pos + Vector3.UP * 0.1, MatLib.surface(Palette.NEONS[_rng.randi() % 6].darkened(0.55), 0.6))
