@tool
class_name CityBuilder
extends Node3D
## Builds the playable crossroads and the streets that run on far beyond it: wet roads and
## sidewalks, buildings with storefronts and neon signs, street furniture, barricades at the edge
## of the playable area and overpasses in the distance. Lots near the crossing get full detail
## (lights, signs, colliders); far lots are cheap boxes that only exist to sell the scale.
##
## Layout: the main street runs along X, the cross street along Z, and they meet at the origin.
## Roads are 10 m wide, sidewalks 4 m, and building fronts stand 9 m from each street's centre.

const ROAD_HALF := 5.0
const SIDEWALK_OUTER := 9.0
const CURB_HEIGHT := 0.15
const BLOCK_DEPTH := 20.0
## Barricades close the streets this far from the crossing.
const PLAY_LIMIT := 68.0

const SHOP_NAMES := [
	"RAMEN", "NOODLE BAR", "PACHINKO", "KARAOKE", "CYBERWARE", "PHARMACY", "ARCADE", "HOTEL",
	"IMPLANTS", "TATTOO", "DATA CAFE", "CLINIC 24H", "PAWN", "BENTO", "ROBO REPAIR", "MEDS",
	"KOI BAR", "VOID CLUB", "NOVA", "ラーメン", "カラオケ", "パチンコ", "電脳", "居酒屋",
]
const BLADE_NAMES := ["BAR", "HOTEL", "CLUB", "ZEN", "KOI", "LOVE", "DOJO", "ラーメン", "ホテル", "酒", "薬", "夜", "電気"]

@export var city_seed := 2077
## How far the street corridors continue past the barricades.
@export var street_length := 460.0
## Lots closer than this to the crossing get storefronts, lights and colliders.
@export var detail_distance := 78.0
## World-X stretch of the north side of the main street that the sushi cafe occupies.
@export var cafe_lot := Vector2(18.0, 30.0)
@export_tool_button("Rebuild city") var rebuild_action := build

## Walkable sidewalk and crosswalk triangles for the NPC navmesh (filled by build()).
var walkable_faces := PackedVector3Array()
## [Rect2 footprint on the XZ plane, top height] for every building (see max_height_in).
var _footprints: Array = []
## Sidewalk areas (XZ) that street clutter must leave free, like shop entrances and bus stops.
var _keep_clear: Array[Rect2] = []

var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _body: StaticBody3D
var _lights: Node3D
var _signs: Node3D
## Separate nodes for everything that can be shot apart (glass, props, cars).
var _breakables: Node3D
var _ground: GeoBatch
var _props: GeoBatch


func _ready() -> void:
	build()


func build() -> void:
	BuildKit.clear_generated(self)
	walkable_faces = PackedVector3Array()
	_footprints.clear()
	_keep_clear = [Rect2(cafe_lot.x - 1.0, -SIDEWALK_OUTER, cafe_lot.y - cafe_lot.x + 2.0, SIDEWALK_OUTER - ROAD_HALF)]
	_rng.seed = city_seed
	_root = BuildKit.generated_root(self, "Generated")
	_body = BuildKit.static_body(_root, "Collision")
	_lights = Node3D.new()
	_lights.name = "Lights"
	_root.add_child(_lights)
	_signs = Node3D.new()
	_signs.name = "Signs"
	_root.add_child(_signs)
	_breakables = Node3D.new()
	_breakables.name = "Breakables"
	_root.add_child(_breakables)
	_ground = GeoBatch.new()
	_props = GeoBatch.new()

	_build_streets()
	var index := 0
	for frontage in _frontages():
		_build_frontage(frontage, index)
		index += 1
	_build_street_lamps()
	_build_corner_props()
	_build_bus_stops()
	_build_street_signs()
	_build_roadworks()
	_build_sidewalk_clutter()
	_build_parked_cars()
	_build_cables()
	_build_barricades()
	_build_overpasses()
	_build_steam_vents()

	_ground.build_into(_root, "Streets", false)
	_props.build_into(_root, "StreetProps")


## Tallest building top inside `area` (XZ plane); used to keep flight paths above the roofs.
func max_height_in(area: Rect2) -> float:
	var top := 0.0
	for footprint in _footprints:
		if (footprint[0] as Rect2).intersects(area):
			top = maxf(top, footprint[1])
	return top


# --- Layout helpers -------------------------------------------------------------------------

## Each frontage is a row of lots along one side of a street. `facing` points at the street,
## lots run along up x facing over [from, to] measured from `line`.
func _frontages() -> Array[Dictionary]:
	var far := street_length
	var corner := SIDEWALK_OUTER + BLOCK_DEPTH
	return [
		{"facing": Vector3.BACK, "line": Vector3(0, 0, -SIDEWALK_OUTER), "from": SIDEWALK_OUTER, "to": far, "reserved": cafe_lot},
		{"facing": Vector3.BACK, "line": Vector3(0, 0, -SIDEWALK_OUTER), "from": -far, "to": -SIDEWALK_OUTER},
		{"facing": Vector3.FORWARD, "line": Vector3(0, 0, SIDEWALK_OUTER), "from": -far, "to": -SIDEWALK_OUTER},
		{"facing": Vector3.FORWARD, "line": Vector3(0, 0, SIDEWALK_OUTER), "from": SIDEWALK_OUTER, "to": far},
		{"facing": Vector3.LEFT, "line": Vector3(SIDEWALK_OUTER, 0, 0), "from": -far, "to": -corner},
		{"facing": Vector3.LEFT, "line": Vector3(SIDEWALK_OUTER, 0, 0), "from": corner, "to": far},
		{"facing": Vector3.RIGHT, "line": Vector3(-SIDEWALK_OUTER, 0, 0), "from": corner, "to": far},
		{"facing": Vector3.RIGHT, "line": Vector3(-SIDEWALK_OUTER, 0, 0), "from": -far, "to": -corner},
	]


func _split_lots(from: float, to: float, reserved: Vector2) -> Array[Vector2]:
	var lots: Array[Vector2] = []
	if reserved != Vector2.ZERO and reserved.x >= from and reserved.y <= to:
		_subdivide(from, reserved.x, lots)
		lots.append(reserved)
		_subdivide(reserved.y, to, lots)
	else:
		_subdivide(from, to, lots)
	return lots


func _subdivide(from: float, to: float, lots: Array[Vector2]) -> void:
	var t := from
	while to - t > 0.01:
		var width := _rng.randf_range(9.0, 22.0)
		if to - (t + width) < 7.0:
			width = to - t
		lots.append(Vector2(t, t + width))
		t += width


## Transform of a point given in a lot's local space (x along the street, z towards it).
func _at(xf: Transform3D, x: float, y: float, z: float) -> Transform3D:
	return xf.translated_local(Vector3(x, y, z))


func _walk_quad(x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var a := Vector3(minf(x0, x1), y, minf(z0, z1))
	var c := Vector3(maxf(x0, x1), y, maxf(z0, z1))
	var b := Vector3(c.x, y, a.z)
	var d := Vector3(a.x, y, c.z)
	walkable_faces.append_array(PackedVector3Array([a, b, c, a, c, d]))


# --- Streets ---------------------------------------------------------------------------------

func _build_streets() -> void:
	var far := street_length
	var asphalt := MatLib.street(Palette.ASPHALT, 0.5, 0.0, 0.55)
	var paving := MatLib.street(Color(0.12, 0.12, 0.145), 0.6, 1.0, 0.3)
	var curb := MatLib.surface(Color(0.22, 0.22, 0.25), 0.6)
	var sidewalk_width := SIDEWALK_OUTER - ROAD_HALF

	# Roads, plus a dark plane under everything for distant gaps.
	_ground.add_box_at(Vector3(far * 2.0, 0.2, ROAD_HALF * 2.0), Vector3(0, -0.1, 0), asphalt)
	for side: float in [-1.0, 1.0]:
		_ground.add_box_at(Vector3(ROAD_HALF * 2.0, 0.2, far - ROAD_HALF), Vector3(0, -0.1, side * (far + ROAD_HALF) * 0.5), asphalt)
	_ground.add_box_at(Vector3(2400, 0.2, 2400), Vector3(0, -0.4, 0), MatLib.surface(Color(0.02, 0.02, 0.03), 0.9, 0.0, 0.0))

	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			# Main-street sidewalk (includes the corner square) and the cross-street sidewalk.
			var main_len := far - ROAD_HALF
			_ground.add_box_at(Vector3(main_len, CURB_HEIGHT, sidewalk_width), Vector3(sx * (ROAD_HALF + main_len * 0.5), CURB_HEIGHT * 0.5, sz * (ROAD_HALF + sidewalk_width * 0.5)), paving)
			_ground.add_box_at(Vector3(main_len, CURB_HEIGHT + 0.01, 0.25), Vector3(sx * (ROAD_HALF + main_len * 0.5), (CURB_HEIGHT + 0.01) * 0.5, sz * (ROAD_HALF + 0.125)), curb)
			var cross_len := far - SIDEWALK_OUTER
			_ground.add_box_at(Vector3(sidewalk_width, CURB_HEIGHT, cross_len), Vector3(sx * (ROAD_HALF + sidewalk_width * 0.5), CURB_HEIGHT * 0.5, sz * (SIDEWALK_OUTER + cross_len * 0.5)), paving)
			_ground.add_box_at(Vector3(0.25, CURB_HEIGHT + 0.01, cross_len + sidewalk_width), Vector3(sx * (ROAD_HALF + 0.125), (CURB_HEIGHT + 0.01) * 0.5, sz * (ROAD_HALF + (cross_len + sidewalk_width) * 0.5)), curb)

	_build_street_markings()
	_build_street_collision()
	_build_walkable_faces()


func _build_street_markings() -> void:
	var paint := MatLib.surface(Color(0.75, 0.75, 0.7), 0.45, 0.0, 0.3)
	var lane_glow := MatLib.neon(Palette.CYAN, 1.3)
	# Crosswalks on all four sides of the crossing.
	for side: float in [-1.0, 1.0]:
		for i in 10:
			var offset := -4.5 + i
			_ground.add_box_at(Vector3(3.0, 0.02, 0.5), Vector3(side * 7.0, 0.01, offset), paint)
			_ground.add_box_at(Vector3(0.5, 0.02, 3.0), Vector3(offset, 0.01, side * 7.0), paint)
		# Stop lines.
		_ground.add_box_at(Vector3(0.4, 0.02, ROAD_HALF), Vector3(side * 9.2, 0.01, -side * ROAD_HALF * 0.5), paint)
		_ground.add_box_at(Vector3(ROAD_HALF, 0.02, 0.4), Vector3(side * ROAD_HALF * 0.5, 0.01, side * 9.2), paint)
	# Glowing dashed centre lines.
	var t := 11.0
	while t < street_length:
		for side: float in [-1.0, 1.0]:
			_ground.add_box_at(Vector3(3.0, 0.02, 0.12), Vector3(side * (t + 1.5), 0.012, 0), lane_glow)
			_ground.add_box_at(Vector3(0.12, 0.02, 3.0), Vector3(0, 0.012, side * (t + 1.5)), lane_glow)
		t += 7.0


func _build_street_collision() -> void:
	var extent := PLAY_LIMIT + 12.0
	var sidewalk_width := SIDEWALK_OUTER - ROAD_HALF
	BuildKit.box_collider_at(_body, Vector3(extent * 2.0, 1.0, extent * 2.0), Vector3(0, -0.5, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var main_len := extent - ROAD_HALF
			BuildKit.box_collider_at(_body, Vector3(main_len, 1.0, sidewalk_width), Vector3(sx * (ROAD_HALF + main_len * 0.5), CURB_HEIGHT - 0.5, sz * (ROAD_HALF + sidewalk_width * 0.5)))
			var cross_len := extent - SIDEWALK_OUTER
			BuildKit.box_collider_at(_body, Vector3(sidewalk_width, 1.0, cross_len), Vector3(sx * (ROAD_HALF + sidewalk_width * 0.5), CURB_HEIGHT - 0.5, sz * (SIDEWALK_OUTER + cross_len * 0.5)))
			# Shallow ramps along the curbs so the player glides up instead of snagging on them.
			_curb_ramp(Vector3(sx * (ROAD_HALF + main_len * 0.5), 0, sz * (ROAD_HALF - 0.6)), Vector3(sx * (ROAD_HALF + main_len * 0.5), CURB_HEIGHT, sz * ROAD_HALF), Vector3.RIGHT, main_len)
			_curb_ramp(Vector3(sx * (ROAD_HALF - 0.6), 0, sz * (ROAD_HALF + main_len * 0.5)), Vector3(sx * ROAD_HALF, CURB_HEIGHT, sz * (ROAD_HALF + main_len * 0.5)), Vector3.BACK, main_len)


## Thin tilted box whose top surface runs from `low` (road side) to `high` (curb top).
func _curb_ramp(low: Vector3, high: Vector3, along: Vector3, length: float) -> void:
	var across := (high - low).normalized()
	var normal := across.cross(along)
	if normal.y < 0.0:
		along = -along
		normal = -normal
	var thickness := 0.1
	var center := (low + high) * 0.5 - normal * thickness * 0.5
	BuildKit.box_collider(_body, Vector3(length, thickness, (high - low).length()), Transform3D(Basis(along, normal, across), center))


## Middle band of each sidewalk plus the crosswalks; NPCs walk here and keep clear of lamps and shop fronts.
func _build_walkable_faces() -> void:
	var inner := ROAD_HALF + 0.9
	var outer := SIDEWALK_OUTER - 0.9
	var y := CURB_HEIGHT
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_walk_quad(sx * inner, sx * PLAY_LIMIT, sz * inner, sz * outer, y)
			_walk_quad(sx * inner, sx * outer, sz * inner, sz * PLAY_LIMIT, y)
	for side: float in [-1.0, 1.0]:
		_walk_quad(side * 5.5, side * 8.5, -ROAD_HALF, ROAD_HALF, 0.0)
		_walk_quad(side * 5.5, side * 8.5, ROAD_HALF, inner, y)
		_walk_quad(side * 5.5, side * 8.5, -inner, -ROAD_HALF, y)
		_walk_quad(-ROAD_HALF, ROAD_HALF, side * 5.5, side * 8.5, 0.0)
		_walk_quad(ROAD_HALF, inner, side * 5.5, side * 8.5, y)
		_walk_quad(-inner, -ROAD_HALF, side * 5.5, side * 8.5, y)


# --- Buildings -------------------------------------------------------------------------------

func _build_frontage(frontage: Dictionary, index: int) -> void:
	var facing: Vector3 = frontage["facing"]
	var x_axis := Vector3.UP.cross(facing)
	var lot_basis := Basis(x_axis, Vector3.UP, facing)
	var line: Vector3 = frontage["line"]
	var reserved: Vector2 = frontage.get("reserved", Vector2.ZERO)
	var near := GeoBatch.new()
	var far := GeoBatch.new()
	for lot in _split_lots(frontage["from"], frontage["to"], reserved):
		var xf := Transform3D(lot_basis, line + x_axis * lot.x)
		var is_near := minf(absf(lot.x), absf(lot.y)) < detail_distance
		var is_cafe := reserved != Vector2.ZERO and lot == reserved
		_build_building(near if is_near else far, xf, lot.y - lot.x, is_near, is_cafe)
	near.build_into(_root, "Frontage%dNear" % index)
	far.build_into(_root, "Frontage%dFar" % index, false)


func _build_building(geo: GeoBatch, xf: Transform3D, width: float, near: bool, is_cafe: bool) -> void:
	var depth := BLOCK_DEPTH
	var height := _rng.randf_range(14.0, 48.0) if near else _rng.randf_range(18.0, 75.0)
	if _rng.randf() < (0.2 if near else 0.28):
		height = _rng.randf_range(65.0, 130.0) if near else _rng.randf_range(80.0, 190.0)
	if is_cafe:
		height = 42.0
	var tint := _rng.randf_range(0.45, 0.8)
	geo.color = Color(tint, tint * _rng.randf_range(0.9, 1.0), tint * _rng.randf_range(0.95, 1.15), _rng.randf_range(0.28, 0.65))
	var facade := MatLib.facade(1, 5.0)
	var base_y := SushiCafe.SHELL_TOP if is_cafe else 0.0
	geo.add_box(Vector3(width, height - base_y, depth), _at(xf, width * 0.5, base_y + (height - base_y) * 0.5, -depth * 0.5), facade)
	var top := height
	if height > 25.0 and _rng.randf() < 0.45:
		var setback_width := width * _rng.randf_range(0.5, 0.85)
		var setback_depth := depth * _rng.randf_range(0.5, 0.8)
		var setback_height := _rng.randf_range(8.0, 40.0)
		geo.add_box(Vector3(setback_width, setback_height, setback_depth), _at(xf, width * 0.5, height + setback_height * 0.5, -depth * 0.5 - 1.5), facade)
		top = height + setback_height
	geo.color = Color.WHITE
	var a := xf * Vector3(0, 0, 0)
	var b := xf * Vector3(width, 0, -depth)
	_footprints.append([Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(b.x - a.x), absf(b.z - a.z))), top + 16.0])

	if near:
		_decorate_near_building(geo, xf, width, height, top, is_cafe)
		if not is_cafe:
			BuildKit.box_collider(_body, Vector3(width, 12.0, depth), _at(xf, width * 0.5, 6.0, -depth * 0.5))
	else:
		_decorate_far_building(geo, xf, width, height)


func _decorate_near_building(geo: GeoBatch, xf: Transform3D, width: float, height: float, top: float, is_cafe: bool) -> void:
	var metal := MatLib.surface(Palette.METAL, 0.5, 0.6)
	var metal_dark := MatLib.surface(Palette.METAL_DARK, 0.5, 0.5)
	if not is_cafe:
		_storefront(geo, xf, width)

	# Vertical blade sign with stacked letters on both faces.
	if height > 14.0 and not is_cafe and _rng.randf() < 0.5:
		var word: String = BLADE_NAMES[_rng.randi() % BLADE_NAMES.size()]
		var color := Palette.random_neon(_rng)
		var sign_height := clampf(word.length() * 1.0 + 0.8, 2.5, 6.5)
		var bx := 0.9 if _rng.randf() < 0.5 else width - 0.9
		var center_y := 5.4 + sign_height * 0.5
		geo.add_box(Vector3(0.2, sign_height, 1.2), _at(xf, bx, center_y, 0.85), MatLib.surface(Color(0.03, 0.025, 0.04), 0.4, 0.4))
		var neon := MatLib.neon(color, 4.0, 0.08 if _rng.randf() < 0.3 else 0.0, 0.0, _rng.randf())
		for face: float in [-1.0, 1.0]:
			var corners := PackedVector3Array()
			for corner in [Vector2(0.3, -0.5), Vector2(1.4, -0.5), Vector2(1.4, 0.5), Vector2(0.3, 0.5)]:
				corners.append(xf * Vector3(bx + face * 0.12, center_y + corner.y * (sign_height - 0.2), corner.x))
			geo.add_polyline(corners, 0.04, neon, true)
			var letters := PackedStringArray()
			for ch in word:
				letters.append(ch)
			var letter_height := minf(0.85, (sign_height - 0.4) / maxf(1.0, word.length()))
			var label_basis := xf.basis * Basis(Vector3.UP, face * PI * 0.5)
			var label := BuildKit.neon_text(_signs, "\n".join(letters), Transform3D(label_basis, xf * Vector3(bx + face * 0.17, center_y, 0.85)), color, letter_height)
			label.line_spacing = -14.0

	# Big holographic advert on taller facades.
	if height > 24.0 and _rng.randf() < 0.4:
		var ad_width := minf(width * 0.7, 9.0)
		var ad_height := _rng.randf_range(4.0, 7.0)
		var ad_y := _rng.randf_range(10.0, minf(height - ad_height * 0.5 - 2.0, 24.0))
		var ad := MatLib.holo_ad(Palette.random_neon(_rng), Palette.random_neon(_rng), _rng.randi() % 4, _rng.randf() * 10.0)
		geo.add_quad(Vector2(ad_width, ad_height), _at(xf, width * 0.5, ad_y, 0.25), ad)
		geo.add_box(Vector3(ad_width + 0.3, ad_height + 0.3, 0.2), _at(xf, width * 0.5, ad_y, 0.1), metal_dark)

	# Neon corner strips and roofline bands.
	if _rng.randf() < 0.35:
		var strip := MatLib.neon(Palette.random_neon(_rng), 3.5)
		geo.add_bar(xf * Vector3(0.12, 5.0, 0.12), xf * Vector3(0.12, height - 0.5, 0.12), 0.12, strip)
		geo.add_bar(xf * Vector3(width - 0.12, 5.0, 0.12), xf * Vector3(width - 0.12, height - 0.5, 0.12), 0.12, strip)
	if _rng.randf() < 0.4:
		geo.add_bar(xf * Vector3(0.2, height - 0.4, 0.1), xf * Vector3(width - 0.2, height - 0.4, 0.1), 0.15, MatLib.neon(Palette.random_neon(_rng), 3.0))

	# Air-conditioning units hanging off the facade.
	for i in _rng.randi_range(2, 7):
		var ac_x := _rng.randf_range(1.0, width - 1.0)
		var ac_y := 6.2 + floorf(_rng.randf_range(0.0, minf(height - 8.0, 30.0)) / 3.4) * 3.4
		geo.add_box(Vector3(0.9, 0.6, 0.5), _at(xf, ac_x, ac_y, 0.25), metal)
		geo.add_box(Vector3(0.5, 0.42, 0.02), _at(xf, ac_x, ac_y, 0.51), metal_dark)

	# Rooftop: water tanks on low buildings, antennas with aviation lights on tall ones.
	if top < 40.0 and _rng.randf() < 0.5:
		var tank := _at(xf, width * _rng.randf_range(0.3, 0.7), top + 2.4, -BLOCK_DEPTH * 0.6)
		geo.add_cylinder(1.4, 1.4, 2.4, 8, tank, metal)
		geo.add_cylinder(1.5, 0.2, 0.6, 8, tank.translated_local(Vector3(0, 1.5, 0)), metal_dark)
		for leg in 4:
			var a := TAU * leg / 4.0 + 0.6
			geo.add_bar(tank * Vector3(cos(a) * 1.1, -1.2, sin(a) * 1.1), tank * Vector3(cos(a) * 1.1, -2.4, sin(a) * 1.1), 0.12, metal_dark)
	elif top >= 40.0:
		var base := xf * Vector3(width * 0.5, top, -BLOCK_DEPTH * 0.5)
		var mast_height := _rng.randf_range(6.0, 16.0)
		geo.add_bar(base, base + Vector3.UP * mast_height, 0.25, metal_dark)
		geo.add_box_at(Vector3(0.5, 0.5, 0.5), base + Vector3.UP * mast_height, MatLib.neon(Palette.RED, 6.0, 0.0, 0.5, _rng.randf()))


func _decorate_far_building(geo: GeoBatch, xf: Transform3D, width: float, height: float) -> void:
	# Lit shop strip and a sign block: enough to read as a storefront from a distance.
	var color := Palette.random_neon(_rng)
	geo.add_box(Vector3(width - 1.2, 2.6, 0.1), _at(xf, width * 0.5, 1.9, 0.05), MatLib.neon(_shop_light_color(), 0.8))
	geo.add_box(Vector3(width * 0.6, 0.8, 0.2), _at(xf, width * 0.5, 4.0, 0.12), MatLib.neon(color, 3.0))
	if _rng.randf() < 0.45:
		var sign_height := _rng.randf_range(3.0, 7.0)
		geo.add_box(Vector3(0.25, sign_height, 1.0), _at(xf, width - 1.0, 6.0 + sign_height * 0.5, 0.7), MatLib.neon(Palette.random_neon(_rng), 3.5))
	if _rng.randf() < 0.3:
		var ad_height := _rng.randf_range(5.0, 9.0)
		var ad := MatLib.holo_ad(Palette.random_neon(_rng), Palette.random_neon(_rng), _rng.randi() % 4, _rng.randf() * 10.0, 3.0)
		geo.add_quad(Vector2(minf(width * 0.75, 12.0), ad_height), _at(xf, width * 0.5, minf(height - ad_height, _rng.randf_range(10.0, 30.0)), 0.2), ad)
	if _rng.randf() < 0.35:
		geo.add_bar(xf * Vector3(0.2, height - 0.4, 0.1), xf * Vector3(width - 0.2, height - 0.4, 0.1), 0.3, MatLib.neon(Palette.random_neon(_rng), 3.0))
	if height > 60.0:
		geo.add_box(Vector3(0.6, 0.6, 0.6), _at(xf, width * 0.5, height + 0.3, -BLOCK_DEPTH * 0.5), MatLib.neon(Palette.RED, 6.0, 0.0, 0.5, _rng.randf()))


func _storefront(geo: GeoBatch, xf: Transform3D, width: float) -> void:
	var color := Palette.random_neon(_rng)
	var frame := MatLib.surface(Palette.METAL_DARK, 0.4, 0.5)
	if _rng.randf() < 0.22:
		# Closed shop: roll-down shutter with a neon graffiti tag.
		var shutter := MatLib.surface(Color(0.2, 0.21, 0.24), 0.45, 0.7)
		geo.add_box(Vector3(width - 1.0, 3.3, 0.12), _at(xf, width * 0.5, 1.8, 0.06), shutter)
		for i in 13:
			geo.add_box(Vector3(width - 1.0, 0.04, 0.03), _at(xf, width * 0.5, 0.3 + i * 0.25, 0.13), frame)
		geo.add_box(Vector3(width - 0.8, 0.45, 0.4), _at(xf, width * 0.5, 3.65, 0.2), frame)
		var tag := PackedVector3Array()
		var start := _rng.randf_range(1.0, maxf(1.2, width - 4.0))
		for i in 7:
			tag.append(xf * Vector3(start + i * 0.4, 1.6 + _rng.randf_range(-0.4, 0.5), 0.15))
		geo.add_polyline(tag, 0.05, MatLib.neon(color, 3.0, 0.2, 0.0, _rng.randf()))
		return

	var window_width := width - 3.4
	var glow := MatLib.neon(_shop_light_color(), 0.45)
	var silhouette := MatLib.surface(Color(0.02, 0.02, 0.03), 0.8, 0.0, 0.0)
	geo.add_box(Vector3(window_width, 2.8, 0.02), _at(xf, 0.6 + window_width * 0.5, 1.9, 0.02), glow)
	for i in 3:
		geo.add_box(Vector3(window_width - 0.2, 0.06, 0.08), _at(xf, 0.6 + window_width * 0.5, 0.95 + i * 0.75, 0.06), silhouette)
		for j in int(window_width / 0.7):
			if _rng.randf() < 0.6:
				var item := Vector3(_rng.randf_range(0.15, 0.4), _rng.randf_range(0.15, 0.5), 0.06)
				geo.add_box(item, _at(xf, 0.9 + j * 0.7, 0.98 + i * 0.75 + item.y * 0.5, 0.07), silhouette)
	BuildKit.glass_pane(_breakables, _at(xf, 0.6 + window_width * 0.5, 1.9, 0.18), Vector3(window_width, 2.8, 0.03), Color(0.4, 0.7, 1.0, 0.08))
	geo.add_box(Vector3(window_width + 0.3, 0.5, 0.3), _at(xf, 0.6 + window_width * 0.5, 0.25, 0.15), frame)
	geo.add_box(Vector3(window_width + 0.3, 0.12, 0.3), _at(xf, 0.6 + window_width * 0.5, 3.36, 0.15), frame)
	geo.add_box(Vector3(0.12, 3.4, 0.3), _at(xf, 0.55, 1.7, 0.15), frame)
	geo.add_box(Vector3(0.12, 3.4, 0.3), _at(xf, window_width + 0.65, 1.7, 0.15), frame)

	# Door with a lit panel behind dark glass.
	var door_x := width - 1.6
	geo.add_box(Vector3(1.2, 2.45, 0.02), _at(xf, door_x, 1.38, 0.02), glow)
	BuildKit.glass_pane(_breakables, _at(xf, door_x, 1.38, 0.1), Vector3(1.2, 2.45, 0.04), Color(0.15, 0.2, 0.3, 0.55))
	geo.add_box(Vector3(1.5, 0.15, 0.25), _at(xf, door_x, 2.68, 0.12), frame)
	geo.add_box(Vector3(0.6, 0.06, 0.05), _at(xf, door_x, 2.85, 0.2), MatLib.neon(Palette.WARM_WHITE, 2.5))

	# Sign board with neon lettering.
	var board_width := width - 1.0
	geo.add_box(Vector3(board_width, 1.0, 0.3), _at(xf, width * 0.5, 4.05, 0.15), MatLib.surface(Color(0.03, 0.025, 0.04), 0.4, 0.4))
	var neon := MatLib.neon(color, 3.5, 0.1 if _rng.randf() < 0.25 else 0.0, 0.0, _rng.randf())
	geo.add_polyline(PackedVector3Array([
		xf * Vector3(0.6, 3.6, 0.31), xf * Vector3(width - 0.6, 3.6, 0.31),
		xf * Vector3(width - 0.6, 4.5, 0.31), xf * Vector3(0.6, 4.5, 0.31),
	]), 0.035, neon, true)
	var shop_name: String = SHOP_NAMES[_rng.randi() % SHOP_NAMES.size()]
	var text_height := minf(0.62, board_width * 0.85 / (shop_name.length() * 0.62))
	BuildKit.neon_text(_signs, shop_name, _at(xf, width * 0.5, 4.05, 0.4), color, text_height)

	# Awning.
	if _rng.randf() < 0.5:
		var awning_color := Color(_rng.randf_range(0.05, 0.3), _rng.randf_range(0.02, 0.1), _rng.randf_range(0.08, 0.3))
		var tilt := xf.basis * Basis(Vector3.RIGHT, deg_to_rad(15.0))
		geo.add_box(Vector3(window_width + 0.4, 0.08, 1.3), Transform3D(tilt, xf * Vector3(0.6 + window_width * 0.5, 3.25, 0.62)), MatLib.surface(awning_color, 0.7))
		geo.add_bar(xf * Vector3(0.4, 3.08, 1.25), xf * Vector3(window_width + 0.8, 3.08, 1.25), 0.04, MatLib.neon(color, 4.0))

	BuildKit.omni(_lights, xf * Vector3(width * 0.5, 3.0, 1.8), color, _rng.randf_range(1.4, 2.4), 7.5)


func _shop_light_color() -> Color:
	var roll := _rng.randf()
	if roll < 0.35:
		return Palette.WARM_WHITE.darkened(0.15)
	if roll < 0.55:
		return Palette.COOL_WHITE.darkened(0.15)
	return Palette.random_neon(_rng).lerp(Color.WHITE, 0.2)


# --- Street furniture ------------------------------------------------------------------------

## Staggered lamps on both sides of both streets. Only those in the playable area cast light;
## the rest just glow so the rows of lamps keep going into the fog.
func _build_street_lamps() -> void:
	var metal := MatLib.surface(Palette.METAL_DARK, 0.4, 0.7)
	var light_color := Color(0.65, 0.85, 1.0)
	var t := 16.0
	while t < 230.0:
		for direction: float in [-1.0, 1.0]:
			for side: float in [-1.0, 1.0]:
				var along := direction * (t + (9.0 if side > 0.0 else 0.0))
				var lit := absf(along) < PLAY_LIMIT + 10.0
				_street_lamp(Vector3(along, CURB_HEIGHT, side * (ROAD_HALF + 0.6)), Vector3(0, 0, -side), metal, light_color, lit)
				_street_lamp(Vector3(side * (ROAD_HALF + 0.6), CURB_HEIGHT, along), Vector3(-side, 0, 0), metal, light_color, lit)
		t += 18.0


## Lamps in the playable area light the street and can be shot until they snap over and go dark.
func _street_lamp(pos: Vector3, toward_road: Vector3, metal: Material, light_color: Color, lit: bool) -> void:
	var geo := GeoBatch.new() if lit else _props
	var origin := Vector3.ZERO if lit else pos
	geo.add_cylinder(0.1, 0.07, 6.6, 6, Transform3D(Basis.IDENTITY, origin + Vector3.UP * 3.3), metal)
	var arm_end := origin + Vector3.UP * 6.5 + toward_road * 1.9
	geo.add_bar(origin + Vector3.UP * 6.5, arm_end, 0.1, metal)
	var head_size := Vector3(0.9, 0.16, 0.4) if absf(toward_road.x) > 0.5 else Vector3(0.4, 0.16, 0.9)
	geo.add_box_at(head_size, arm_end, metal)
	var flicker := 0.25 if _rng.randf() < 0.12 else 0.0
	geo.add_box_at(head_size * Vector3(0.85, 0.3, 0.75), arm_end - Vector3.UP * 0.09, MatLib.neon(light_color, 5.0, flicker, 0.0, _rng.randf()))
	if lit:
		var lamp := _prop(Transform3D(Basis.IDENTITY, pos), geo, [[Vector3(0.25, 6.6, 0.25), Transform3D(Basis.IDENTITY, Vector3.UP * 3.3)]], 90.0, BreakableProp.Kind.METAL, Vector3(0.4, 6.6, 0.4), PackedColorArray([Palette.METAL_DARK, light_color]))
		lamp.keep_wreck = true
		lamp.electrical = true
		lamp.add_light(BuildKit.down_spot(lamp.visual, arm_end - Vector3.UP * 0.2, light_color, 3.5, 13.0, 55.0))


func _build_corner_props() -> void:
	var metal := MatLib.surface(Palette.METAL_DARK, 0.4, 0.7)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner := Vector3(sx * (ROAD_HALF + 0.5), CURB_HEIGHT, sz * (ROAD_HALF + 0.5))
			# Traffic light: red for the main street on one diagonal, green on the other.
			_props.add_cylinder(0.09, 0.09, 4.6, 6, Transform3D(Basis.IDENTITY, corner + Vector3.UP * 2.3), metal)
			BuildKit.box_collider_at(_body, Vector3(0.22, 4.6, 0.22), corner + Vector3.UP * 2.3)
			var red_main := sx * sz > 0.0
			for axis in 2:
				var facing := Vector3(-sx, 0, 0) if axis == 0 else Vector3(0, 0, -sz)
				var box_pos := corner + Vector3.UP * 4.0 + facing * 0.25
				var box_size := Vector3(0.3, 1.0, 0.35) if axis == 0 else Vector3(0.35, 1.0, 0.3)
				_props.add_box_at(box_size, box_pos, metal)
				var stop := red_main if axis == 0 else not red_main
				var lamp_y := 0.3 if stop else -0.3
				var lamp_color := Palette.RED if stop else Palette.LIME
				_props.add_box_at(Vector3(0.18, 0.18, 0.18), box_pos + Vector3.UP * lamp_y + facing * 0.12, MatLib.neon(lamp_color, 6.0))
			# Bollards with glowing caps.
			for i in 3:
				var along_x := corner + Vector3(sx * (1.2 + i * 1.0), 0, -sz * 0.05)
				_props.add_cylinder(0.12, 0.12, 0.8, 6, Transform3D(Basis.IDENTITY, along_x + Vector3.UP * 0.4), metal)
				_props.add_cylinder(0.13, 0.13, 0.06, 6, Transform3D(Basis.IDENTITY, along_x + Vector3.UP * 0.82), MatLib.neon(Palette.AMBER, 4.0))
				BuildKit.box_collider_at(_body, Vector3(0.24, 0.85, 0.24), along_x + Vector3.UP * 0.42)
	# Holographic advert column on the north-west corner.
	var column := Vector3(-SIDEWALK_OUTER + 0.6, CURB_HEIGHT, -SIDEWALK_OUTER + 0.6)
	_props.add_box_at(Vector3(1.0, 3.6, 1.0), column + Vector3.UP * 1.8, metal)
	var ad := MatLib.holo_ad(Palette.PINK, Palette.CYAN, 2, 4.2, 2.8)
	for i in 4:
		var face_basis := Basis(Vector3.UP, i * PI * 0.5)
		_props.add_quad(Vector2(0.9, 3.0), Transform3D(face_basis, column + Vector3.UP * 1.9 + face_basis * Vector3(0, 0, 0.51)), ad)
	BuildKit.box_collider_at(_body, Vector3(1.0, 3.6, 1.0), column + Vector3.UP * 1.8)


## Random street clutter along the building side of the sidewalks, clear of shop entrances.
func _build_sidewalk_clutter() -> void:
	var bag := MatLib.surface(Color(0.03, 0.03, 0.035), 0.3)
	var placed: Array[Vector3] = []
	var attempts := 0
	while placed.size() < 30 and attempts < 500:
		attempts += 1
		var along := _rng.randf_range(12.0, PLAY_LIMIT - 4.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var on_main := _rng.randf() < 0.6
		var pos := Vector3(along, CURB_HEIGHT, side * (SIDEWALK_OUTER - 0.55)) if on_main else Vector3(side * (SIDEWALK_OUTER - 0.55), CURB_HEIGHT, along)
		var facing := Vector3(0, 0, -side) if on_main else Vector3(-side, 0, 0)
		if _is_blocked(pos, placed, 2.4):
			continue
		placed.append(pos)
		var roll := _rng.randf()
		if roll < 0.17:
			_vending_machine(pos, facing)
		elif roll < 0.36:
			_trash_bin(pos)
		elif roll < 0.48:
			for i in _rng.randi_range(2, 4):
				var offset := Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.3, 0.3))
				_props.add_sphere(0.32, Transform3D(Basis.from_scale(Vector3(1.0, 0.75, 1.0)), pos + offset + Vector3.UP * 0.22), bag, 6, 4)
		elif roll < 0.64:
			_crate_stack(pos, facing)
		elif roll < 0.8:
			_planter(pos, facing)
		else:
			_sidewalk_sign(pos + facing * 0.6, facing)


func _is_blocked(pos: Vector3, placed: Array[Vector3], spacing: float) -> bool:
	for area in _keep_clear:
		if area.grow(0.6).has_point(Vector2(pos.x, pos.z)):
			return true
	for other in placed:
		if other.distance_to(pos) < spacing:
			return true
	return false


func _prop(xf: Transform3D, geo: GeoBatch, colliders: Array, health: float, kind: BreakableProp.Kind, extent: Vector3, colors: PackedColorArray) -> BreakableProp:
	return BreakableProp.create(_breakables, xf, geo, colliders, health, kind, extent, colors)


func _trash_bin(pos: Vector3) -> void:
	var color := Color(0.1, 0.18, 0.14)
	var geo := GeoBatch.new()
	geo.add_cylinder(0.32, 0.3, 0.95, 8, Transform3D(Basis.IDENTITY, Vector3.UP * 0.475), MatLib.surface(color, 0.6, 0.3))
	geo.add_cylinder(0.34, 0.34, 0.06, 8, Transform3D(Basis.IDENTITY, Vector3.UP * 0.97), MatLib.surface(Palette.METAL_DARK, 0.5, 0.5))
	_prop(Transform3D(Basis.IDENTITY, pos), geo, [[Vector3(0.6, 0.95, 0.6), Transform3D(Basis.IDENTITY, Vector3.UP * 0.475)]], 50.0, BreakableProp.Kind.METAL, Vector3(0.6, 0.95, 0.6), PackedColorArray([color, Color(0.05, 0.05, 0.05)]))


## A stack of plastic crates, the kind street stalls leave out overnight.
func _crate_stack(pos: Vector3, facing: Vector3) -> void:
	var color := [Color(0.1, 0.2, 0.45), Color(0.45, 0.08, 0.08), Color(0.5, 0.4, 0.05), Color(0.12, 0.3, 0.15)][_rng.randi() % 4] as Color
	var crate := MatLib.surface(color, 0.6)
	var slats := MatLib.surface(color.darkened(0.5), 0.6)
	var geo := GeoBatch.new()
	var levels := _rng.randi_range(1, 3)
	for level in levels:
		var y := 0.2 + level * 0.4
		var twist := Basis(Vector3.UP, _rng.randf_range(-0.15, 0.15))
		geo.add_box(Vector3(0.6, 0.38, 0.45), Transform3D(twist, Vector3(0, y, 0)), crate)
		for i in 3:
			geo.add_box(Vector3(0.62, 0.04, 0.47), Transform3D(twist, Vector3(0, y - 0.1 + i * 0.1, 0)), slats)
	var height := levels * 0.4
	_prop(Transform3D(Basis.looking_at(-facing), pos), geo, [[Vector3(0.62, height, 0.47), Transform3D(Basis.IDENTITY, Vector3.UP * height * 0.5)]], 40.0, BreakableProp.Kind.WOOD, Vector3(0.6, height, 0.45), PackedColorArray([color, color.darkened(0.5)]))


## Concrete planter with glowing synthetic plants.
func _planter(pos: Vector3, facing: Vector3) -> void:
	var concrete := Color(0.3, 0.3, 0.32)
	var leaf := [Palette.CYAN, Palette.LIME, Palette.PINK][_rng.randi() % 3] as Color
	var geo := GeoBatch.new()
	geo.add_box_at(Vector3(1.6, 0.6, 0.6), Vector3(0, 0.3, 0), MatLib.surface(concrete, 0.8))
	geo.add_box_at(Vector3(1.45, 0.05, 0.45), Vector3(0, 0.6, 0), MatLib.surface(Color(0.08, 0.05, 0.03), 0.9))
	var glow := MatLib.neon(leaf, 2.5)
	for i in 9:
		var root := Vector3(_rng.randf_range(-0.6, 0.6), 0.6, _rng.randf_range(-0.15, 0.15))
		var tip := root + Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(0.35, 0.8), _rng.randf_range(-0.15, 0.15))
		geo.add_bar(root, tip, 0.03, glow)
	_prop(Transform3D(Basis.looking_at(-facing), pos), geo, [[Vector3(1.6, 0.6, 0.6), Transform3D(Basis.IDENTITY, Vector3.UP * 0.3)]], 150.0, BreakableProp.Kind.CONCRETE, Vector3(1.6, 0.9, 0.6), PackedColorArray([concrete, leaf]))


## Folding sidewalk sign with a neon arrow pointing at the shop behind it.
func _sidewalk_sign(pos: Vector3, facing: Vector3) -> void:
	var color := Palette.random_neon(_rng)
	var board := MatLib.surface(Color(0.05, 0.04, 0.06), 0.5)
	var neon := MatLib.neon(color, 4.0)
	var geo := GeoBatch.new()
	for side: float in [-1.0, 1.0]:
		var tilt := Basis(Vector3.RIGHT, side * deg_to_rad(12.0))
		geo.add_box(Vector3(0.6, 1.0, 0.03), Transform3D(tilt, Vector3(0, 0.5, side * 0.11)), board)
		var face := Transform3D(tilt, Vector3(0, 0.5, side * 0.11)).translated_local(Vector3(0, 0, side * 0.02))
		geo.add_polyline(PackedVector3Array([face * Vector3(-0.2, -0.1, 0), face * Vector3(0.15, -0.1, 0), face * Vector3(0.15, -0.25, 0), face * Vector3(0.25, 0.0, 0), face * Vector3(0.15, 0.25, 0), face * Vector3(0.15, 0.1, 0), face * Vector3(-0.2, 0.1, 0)]), 0.025, neon, true)
		geo.add_polyline(PackedVector3Array([face * Vector3(-0.26, -0.44, 0), face * Vector3(0.26, -0.44, 0), face * Vector3(0.26, 0.44, 0), face * Vector3(-0.26, 0.44, 0)]), 0.015, neon, true)
	var sign := _prop(Transform3D(Basis.looking_at(-facing.cross(Vector3.UP)), pos), geo, [[Vector3(0.6, 1.0, 0.3), Transform3D(Basis.IDENTITY, Vector3.UP * 0.5)]], 35.0, BreakableProp.Kind.WOOD, Vector3(0.6, 1.0, 0.3), PackedColorArray([Color(0.05, 0.04, 0.06), color]))
	sign.electrical = true


## Street name signs at the four corners of the crossing.
func _build_street_signs() -> void:
	var metal := MatLib.surface(Palette.METAL_DARK, 0.4, 0.7)
	var plate := MatLib.surface(Color(0.03, 0.1, 0.25), 0.4, 0.3)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pos := Vector3(sx * (SIDEWALK_OUTER - 0.45), CURB_HEIGHT, sz * (SIDEWALK_OUTER - 0.45))
			var geo := GeoBatch.new()
			geo.add_cylinder(0.05, 0.05, 3.0, 6, Transform3D(Basis.IDENTITY, Vector3.UP * 1.5), metal)
			geo.add_box_at(Vector3(1.0, 0.3, 0.04), Vector3(0, 2.7, 0), plate)
			geo.add_box_at(Vector3(0.04, 0.3, 1.0), Vector3(0, 2.35, 0), plate)
			geo.add_polyline(PackedVector3Array([Vector3(-0.5, 2.55, 0.03), Vector3(0.5, 2.55, 0.03), Vector3(0.5, 2.85, 0.03), Vector3(-0.5, 2.85, 0.03)]), 0.015, MatLib.neon(Palette.CYAN, 3.0), true)
			var sign := _prop(Transform3D(Basis(Vector3.UP, 0.0 if sz < 0.0 else PI), pos), geo, [[Vector3(0.15, 3.0, 0.15), Transform3D(Basis.IDENTITY, Vector3.UP * 1.5)]], 60.0, BreakableProp.Kind.METAL, Vector3(1.0, 3.0, 1.0), PackedColorArray([Palette.METAL_DARK, Color(0.03, 0.1, 0.25)]))
			BuildKit.neon_text(sign.visual, "KABUKI AVE", Transform3D(Basis.IDENTITY, Vector3(0, 2.7, 0.03)), Palette.CYAN, 0.16)
			BuildKit.neon_text(sign.visual, "CROW ST", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.03, 2.35, 0)), Palette.CYAN, 0.16)
			_keep_clear.append(Rect2(pos.x - 1.0, pos.z - 1.0, 2.0, 2.0))


## Striped barriers fencing off the steam vents in the road.
func _build_roadworks() -> void:
	var stripe_a := MatLib.surface(Color(0.9, 0.45, 0.05), 0.5)
	var stripe_b := MatLib.surface(Color(0.9, 0.9, 0.85), 0.5)
	var legs := MatLib.surface(Palette.METAL_DARK, 0.5, 0.5)
	for vent in [Vector3(14, 0, 2.0), Vector3(-20, 0, -1.5)]:
		for i in 3:
			var angle := TAU * i / 3.0 + _rng.randf_range(-0.3, 0.3)
			var pos: Vector3 = vent + Vector3(cos(angle), 0, sin(angle)) * 1.6
			var geo := GeoBatch.new()
			for s in 4:
				geo.add_box_at(Vector3(0.3, 0.22, 0.04), Vector3(-0.45 + s * 0.3, 0.85, 0), stripe_a if s % 2 == 0 else stripe_b)
			for side: float in [-1.0, 1.0]:
				geo.add_bar(Vector3(side * 0.5, 0.95, 0), Vector3(side * 0.55, 0.0, 0.25), 0.05, legs)
				geo.add_bar(Vector3(side * 0.5, 0.95, 0), Vector3(side * 0.55, 0.0, -0.25), 0.05, legs)
			geo.add_box_at(Vector3(0.12, 0.12, 0.12), Vector3(0.5, 1.05, 0), MatLib.neon(Palette.AMBER, 6.0, 0.0, 1.5, _rng.randf()))
			var barrier := _prop(Transform3D(Basis(Vector3.UP, -angle + PI * 0.5), pos), geo, [[Vector3(1.2, 1.0, 0.5), Transform3D(Basis.IDENTITY, Vector3.UP * 0.5)]], 60.0, BreakableProp.Kind.WOOD, Vector3(1.2, 1.0, 0.5), PackedColorArray([Color(0.9, 0.45, 0.05), Color(0.9, 0.9, 0.85)]))
			barrier.electrical = true


## Bus shelters with glass side and back panels and a lit advert.
func _build_bus_stops() -> void:
	var frame := MatLib.surface(Palette.METAL, 0.35, 0.8)
	for stop in [[Vector3(-48, CURB_HEIGHT, SIDEWALK_OUTER - 0.75), 0.0], [Vector3(SIDEWALK_OUTER - 0.75, CURB_HEIGHT, 46), -PI * 0.5]]:
		var xf := Transform3D(Basis(Vector3.UP, stop[1]), stop[0])
		var geo := GeoBatch.new()
		geo.add_box(Vector3(3.8, 0.12, 1.5), xf.translated_local(Vector3(0, 2.6, -0.1)), frame)
		geo.add_box(Vector3(3.8, 0.05, 0.05), xf.translated_local(Vector3(0, 2.52, 0.62)), MatLib.neon(Palette.CYAN, 4.0))
		for x: float in [-1.8, 1.8]:
			for z: float in [-0.65, 0.6]:
				geo.add_box(Vector3(0.08, 2.6, 0.08), xf.translated_local(Vector3(x, 1.3, z)), frame)
				BuildKit.box_collider(_body, Vector3(0.1, 2.6, 0.1), xf.translated_local(Vector3(x, 1.3, z)))
		geo.add_box(Vector3(2.6, 0.08, 0.45), xf.translated_local(Vector3(0, 0.48, -0.35)), MatLib.surface(Palette.WOOD, 0.5))
		BuildKit.box_collider(_body, Vector3(2.6, 0.5, 0.45), xf.translated_local(Vector3(0, 0.25, -0.35)))
		var ad := MatLib.holo_ad(Palette.random_neon(_rng), Palette.random_neon(_rng), _rng.randi() % 4, _rng.randf() * 10.0, 2.2)
		geo.add_quad(Vector2(1.2, 1.8), xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.82, 1.3, -0.02)), ad)
		geo.build_into(_root, "BusStop")
		BuildKit.glass_pane(_breakables, xf.translated_local(Vector3(0, 1.4, -0.68)), Vector3(3.5, 2.0, 0.03))
		BuildKit.glass_pane(_breakables, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-1.8, 1.4, -0.03)), Vector3(1.2, 2.0, 0.03))
		BuildKit.neon_text(_signs, "BUS 07", xf * Transform3D(Basis.IDENTITY, Vector3(0, 2.75, 0.66)), Palette.CYAN, 0.2)
		var origin: Vector3 = stop[0]
		_keep_clear.append(Rect2(origin.x - 2.6, origin.z - 2.6, 5.2, 5.2))


func _vending_machine(pos: Vector3, facing: Vector3) -> void:
	var color := Palette.random_neon(_rng)
	var body_color := [Color(0.5, 0.05, 0.08), Color(0.08, 0.15, 0.45), Color(0.75, 0.75, 0.78)][_rng.randi() % 3] as Color
	var geo := GeoBatch.new()
	geo.add_box_at(Vector3(1.0, 1.95, 0.75), Vector3(0, 0.975, 0), MatLib.surface(body_color, 0.4, 0.3))
	geo.add_box_at(Vector3(0.62, 1.2, 0.02), Vector3(-0.12, 1.15, 0.38), MatLib.neon(color.lerp(Color.WHITE, 0.5), 1.6))
	for row in 4:
		geo.add_box_at(Vector3(0.58, 0.04, 0.03), Vector3(-0.12, 0.7 + row * 0.3, 0.39), MatLib.surface(Palette.METAL_DARK, 0.5))
	geo.add_box_at(Vector3(0.18, 0.5, 0.03), Vector3(0.33, 1.3, 0.38), MatLib.surface(Palette.METAL_DARK, 0.4))
	geo.add_box_at(Vector3(1.02, 0.08, 0.77), Vector3(0, 1.95, 0), MatLib.neon(color, 4.0))
	var machine := _prop(Transform3D(Basis.looking_at(-facing), pos), geo, [[Vector3(1.0, 1.95, 0.75), Transform3D(Basis.IDENTITY, Vector3(0, 0.975, 0))]], 160.0, BreakableProp.Kind.METAL, Vector3(1.0, 1.95, 0.75), PackedColorArray([body_color, Color(0.3, 0.3, 0.33), color]))
	machine.electrical = true
	machine.add_light(BuildKit.omni(machine.visual, Vector3(0, 1.3, 0.9), color, 0.8, 3.5))


func _build_parked_cars() -> void:
	var spots := [
		[Vector3(-44, 0, 3.7), 0.0], [Vector3(-27, 0, 3.7), 0.0], [Vector3(41, 0, 3.7), 0.0],
		[Vector3(-15, 0, -3.7), PI], [Vector3(52, 0, -3.7), PI], [Vector3(3.7, 0, 34), PI * 0.5],
		[Vector3(-3.7, 0, -46), -PI * 0.5], [Vector3(3.7, 0, -24), PI * 0.5],
	]
	for spot in spots:
		_car(Transform3D(Basis(Vector3.UP, spot[1]), spot[0]))


## Low-poly hover-era sedan: body, cabin, wheels, lights and an underglow strip. Faces local +X.
func _car(xf: Transform3D) -> void:
	var paint := MatLib.surface([Color(0.08, 0.08, 0.1), Color(0.35, 0.03, 0.06), Color(0.05, 0.12, 0.3), Color(0.5, 0.5, 0.55), Color(0.3, 0.22, 0.05)][_rng.randi() % 5] as Color, 0.25, 0.7)
	var glass := MatLib.surface(Color(0.02, 0.03, 0.05), 0.08, 0.6)
	var tyre := MatLib.surface(Color(0.02, 0.02, 0.02), 0.8)
	_props.add_box(Vector3(4.4, 0.7, 1.9), xf.translated_local(Vector3(0, 0.65, 0)), paint)
	_props.add_box(Vector3(2.3, 0.6, 1.7), xf.translated_local(Vector3(-0.25, 1.28, 0)), glass)
	_props.add_box(Vector3(2.1, 0.08, 1.74), xf.translated_local(Vector3(-0.25, 1.6, 0)), paint)
	for wx: float in [-1.4, 1.4]:
		for wz: float in [-0.9, 0.9]:
			_props.add_cylinder(0.36, 0.36, 0.28, 8, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(wx, 0.36, wz)), tyre)
	_props.add_box(Vector3(0.05, 0.12, 1.6), xf.translated_local(Vector3(2.21, 0.75, 0)), MatLib.neon(Palette.WARM_WHITE, 4.0))
	_props.add_box(Vector3(0.05, 0.1, 1.7), xf.translated_local(Vector3(-2.21, 0.8, 0)), MatLib.neon(Palette.RED, 4.0))
	var glow_color := Palette.random_neon(_rng)
	_props.add_box(Vector3(3.6, 0.04, 1.5), xf.translated_local(Vector3(0, 0.27, 0)), MatLib.neon(glow_color, 3.0))
	BuildKit.omni(_lights, xf * Vector3(0, 0.15, 0), glow_color, 1.2, 3.5)
	BuildKit.box_collider(_body, Vector3(4.4, 1.6, 1.9), xf.translated_local(Vector3(0, 0.8, 0)))


func _build_cables() -> void:
	var cable := MatLib.surface(Color(0.02, 0.02, 0.025), 0.6)
	for i in 14:
		var on_main := i < 9
		var along := _rng.randf_range(-street_length * 0.4, street_length * 0.4)
		if absf(along) < 12.0:
			along += 24.0
		var drift := _rng.randf_range(-4.0, 4.0)
		var h0 := _rng.randf_range(8.0, 17.0)
		var h1 := h0 + _rng.randf_range(-2.0, 2.0)
		var a := Vector3(along, h0, -SIDEWALK_OUTER) if on_main else Vector3(-SIDEWALK_OUTER, h0, along)
		var b := Vector3(along + drift, h1, SIDEWALK_OUTER) if on_main else Vector3(SIDEWALK_OUTER, h1, along + drift)
		var sag := _rng.randf_range(0.8, 2.2)
		var points := PackedVector3Array()
		for s in 13:
			var f := s / 12.0
			points.append(a.lerp(b, f) + Vector3.DOWN * sag * 4.0 * f * (1.0 - f))
		_props.add_polyline(points, 0.05, cable)
		# Some cables carry strings of coloured festival lights.
		if _rng.randf() < 0.45:
			var c0 := Palette.random_neon(_rng)
			var c1 := Palette.random_neon(_rng)
			for s in range(1, 24):
				var f := s / 24.0
				var p := a.lerp(b, f) + Vector3.DOWN * (sag * 4.0 * f * (1.0 - f) + 0.12)
				_props.add_box_at(Vector3(0.14, 0.14, 0.14), p, MatLib.neon(c0 if s % 2 == 0 else c1, 4.0))


func _build_barricades() -> void:
	for side: float in [-1.0, 1.0]:
		_barricade(Vector3(side * PLAY_LIMIT, 0, 0), Vector3.BACK, Vector3(-side, 0, 0))
		_barricade(Vector3(0, 0, side * PLAY_LIMIT), Vector3.RIGHT, Vector3(0, 0, -side))


## Police barricade across a street at `center`; `along` runs across the street, `toward` faces the player.
func _barricade(center: Vector3, along: Vector3, toward: Vector3) -> void:
	var concrete := MatLib.surface(Color(0.32, 0.32, 0.34), 0.7)
	var stripe_a := MatLib.surface(Color(0.85, 0.75, 0.1), 0.5)
	var stripe_b := MatLib.surface(Color(0.03, 0.03, 0.03), 0.5)
	var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var span := SIDEWALK_OUTER * 2.0
	var count := int(span / 2.2)
	for i in count:
		var t := -span * 0.5 + 1.1 + i * 2.2
		var pos := center + along * t
		_props.add_box(Vector3(2.0, 0.35, 0.65), Transform3D(basis, pos + Vector3.UP * 0.175), concrete)
		_props.add_box(Vector3(2.0, 0.55, 0.3), Transform3D(basis, pos + Vector3.UP * 0.62), concrete)
		# Striped board on top.
		for s in 5:
			_props.add_box(Vector3(0.4, 0.3, 0.06), Transform3D(basis, pos + along * (-0.8 + s * 0.4) + Vector3.UP * 1.15 + toward * 0.05), stripe_a if s % 2 == 0 else stripe_b)
		var blink_color := Palette.RED if i % 2 == 0 else Color(0.15, 0.3, 1.0)
		_props.add_box_at(Vector3(0.2, 0.2, 0.2), pos + Vector3.UP * 1.45, MatLib.neon(blink_color, 6.0, 0.0, 1.2, 0.5 if i % 2 == 0 else 0.0))
	BuildKit.omni(_lights, center + Vector3.UP * 2.0 + toward * 1.5, Palette.RED, 2.0, 9.0)
	BuildKit.omni(_lights, center + Vector3.UP * 2.0 + toward * 1.5 + along * 5.0, Color(0.15, 0.3, 1.0), 2.0, 9.0)
	var label_basis := Basis.looking_at(-toward)
	BuildKit.neon_text(_signs, "ROAD CLOSED", Transform3D(label_basis, center + Vector3.UP * 2.6 + toward * 0.3), Palette.RED, 0.7, true)
	BuildKit.neon_text(_signs, "封鎖", Transform3D(label_basis, center + Vector3.UP * 3.4 + toward * 0.3), Palette.AMBER, 0.55, true)
	# Invisible wall: the edge of the playable area.
	BuildKit.box_collider(_body, Vector3(span + 2.0, 12.0, 0.6), Transform3D(basis, center + Vector3.UP * 6.0))


func _build_overpasses() -> void:
	var concrete := MatLib.surface(Color(0.16, 0.16, 0.19), 0.8)
	var geo := GeoBatch.new()
	for side: float in [-1.0, 1.0]:
		_overpass(geo, Vector3(side * 150.0, 0, 0), Vector3.BACK, concrete, 15.0)
		_overpass(geo, Vector3(0, 0, side * 175.0), Vector3.RIGHT, concrete, 19.0)
	geo.build_into(_root, "Overpasses")


## Elevated road crossing a street. `along` is the direction the overpass itself runs.
func _overpass(geo: GeoBatch, center: Vector3, along: Vector3, concrete: Material, height: float) -> void:
	var basis := Basis(Vector3.UP.cross(along), Vector3.UP, along)
	var length := 70.0
	geo.add_box(Vector3(12.0, 1.6, length), Transform3D(basis, center + Vector3.UP * height), concrete)
	for s: float in [-1.0, 1.0]:
		var edge := basis * Vector3(s * 6.05, 0, 0)
		geo.add_box(Vector3(0.3, 1.1, length), Transform3D(basis, center + edge + Vector3.UP * (height + 1.3)), concrete)
		geo.add_bar(center + edge + Vector3.UP * (height - 0.5) - along * length * 0.5, center + edge + Vector3.UP * (height - 0.5) + along * length * 0.5, 0.15, MatLib.neon(Palette.PINK if s < 0.0 else Palette.CYAN, 4.0))
		for p: float in [-1.0, 1.0]:
			var pillar := center + along * p * (SIDEWALK_OUTER - 2.0) + basis * Vector3(s * 3.5, 0, 0)
			geo.add_box(Vector3(1.4, height, 1.4), Transform3D(basis, pillar + Vector3.UP * height * 0.5), concrete)
	for i in 8:
		var p := center + along * (-length * 0.5 + 4.0 + i * (length - 8.0) / 7.0) + Vector3.UP * (height - 0.85)
		geo.add_box(Vector3(5.0, 0.1, 0.4), Transform3D(basis, p), MatLib.neon(Palette.COOL_WHITE, 3.0))


func _build_steam_vents() -> void:
	var cover := MatLib.surface(Color(0.08, 0.08, 0.09), 0.3, 0.8)
	for pos in [Vector3(-20, 0, -1.5), Vector3(14, 0, 2.0), Vector3(-1.5, 0, 26), Vector3(2.0, 0, -42), Vector3(46, 0, -1.0)]:
		_props.add_cylinder(0.55, 0.55, 0.03, 10, Transform3D(Basis.IDENTITY, pos + Vector3.UP * 0.015), cover)
		_root.add_child(_steam(pos))


func _steam(pos: Vector3) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 1.2
	process.gravity = Vector3(0.15, 0.25, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.5))
	var grow_texture := CurveTexture.new()
	grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.2, Color(1, 1, 1, 0.18))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	process.color_ramp = fade_texture
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.4

	var puff_material := StandardMaterial3D.new()
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.vertex_color_use_as_albedo = true
	puff_material.albedo_color = Color(0.75, 0.75, 0.85)
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_material.albedo_texture = _soft_puff_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	quad.material = puff_material

	var particles := GPUParticles3D.new()
	particles.name = "Steam"
	particles.position = pos
	particles.amount = 28
	particles.lifetime = 4.0
	particles.preprocess = 4.0
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.visibility_aabb = AABB(Vector3(-3, 0, -3), Vector3(6, 8, 6))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


func _soft_puff_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 32
	texture.height = 32
	return texture
