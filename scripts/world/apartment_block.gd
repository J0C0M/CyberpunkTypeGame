@tool
class_name ApartmentBlock
extends Node3D
## Neo-Heights, the residential tower where the player lives. The CityBuilder places it on a corner
## lot and leaves two floors hollow for it: the ground-floor lobby (mailboxes, a buzzing light, the
## doorman robot, the elevator) and the 11th floor (hallway, locked neighbours' doors, the player's
## apartment 1107). The elevator runs between them: walk in, use the panel, ride up.
## Local space: the street front is z = 0 facing +Z; the east side (x = +width/2) faces the cross street.

const FLOOR_Y := 0.15
const LOBBY_HEIGHT := 4.4
const SHELL_TOP := 4.8
## Floor surface of the 11th floor and its ceiling height.
const UPPER_Y := 36.0
const UPPER_HEIGHT := 3.2
## The hallway runs along X between these two walls; the elevator opens onto it (and the lobby).
const HALL_FRONT_Z := -8.0
const HALL_BACK_Z := -10.2
const SHAFT_X := -5.25
const CAB_HALF := 1.2
const CAB_DEPTH := 2.4
## The player's apartment: the street-side corner unit.
const APARTMENT_X := 1.6
const ACCENT := Color(0.62, 0.28, 1.0)

const DING := preload("res://assets/audio/elevator_ding.wav")
const HUM := preload("res://assets/audio/elevator_hum.wav")
const BUZZ := preload("res://assets/audio/neon_buzz.wav")

## Lot width, set by the CityBuilder.
@export var width := 17.0

var _root: Node3D
var _geo: GeoBatch
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()
## Elevator doors per floor: [left panel, right panel, collider].
var _cab_doors := {}
var _door_open := {0: 0.0, 1: 0.0}
var _riding := false
var _hum: AudioStreamPlayer3D
var _buzz_light: OmniLight3D


func _ready() -> void:
	BuildKit.clear_generated(self)
	_rng.seed = 1107
	_root = BuildKit.generated_root(self, "Generated")
	_geo = GeoBatch.new()
	_body = BuildKit.static_body(_root)
	_build_lobby()
	_build_signs()
	for level in 2:
		_build_cab(level)
	_build_upper_shell()
	_build_hallway()
	_geo.build_into(_root, "BlockGeometry")
	if not Engine.is_editor_hint():
		GameState.register_place(&"apartment", "Neo-Heights 1107", global_transform * Vector3(0, 0, 2.0))


func _half() -> float:
	return width * 0.5


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var local := to_local(player.global_position)
	for level in 2:
		var floor_y := FLOOR_Y if level == 0 else UPPER_Y
		var near := absf(local.y - floor_y) < 2.0 and absf(local.x - SHAFT_X) < 2.2 and local.z > HALL_BACK_Z - CAB_DEPTH and local.z < HALL_BACK_Z + 2.4
		var target := 1.0 if near and not _riding else 0.0
		_door_open[level] = move_toward(_door_open[level], target, delta * 1.8)
		var doors: Array = _cab_doors[level]
		(doors[0] as Node3D).position.x = -_door_open[level] * 0.7
		(doors[1] as Node3D).position.x = _door_open[level] * 0.7
		(doors[2] as CollisionShape3D).disabled = _door_open[level] > 0.6
	if _buzz_light and randf() < 0.06:
		_buzz_light.light_energy = randf_range(0.2, 1.6)


# --- Lobby -------------------------------------------------------------------------------------

func _build_lobby() -> void:
	var half := _half()
	var depth := -HALL_BACK_Z
	var wall := MatLib.surface(Color(0.2, 0.18, 0.24), 0.7)
	var tile := MatLib.surface(Color(0.16, 0.15, 0.18), 0.25, 0.1, 0.15)
	_geo.add_box_at(Vector3(width, FLOOR_Y, depth), Vector3(0, FLOOR_Y * 0.5, -depth * 0.5), tile)
	BuildKit.box_collider_at(_body, Vector3(width, 1.0, depth), Vector3(0, FLOOR_Y - 0.5, -depth * 0.5)).set_meta(&"surface", &"tile")
	_geo.add_box_at(Vector3(width, 0.3, depth), Vector3(0, LOBBY_HEIGHT + 0.15, -depth * 0.5), MatLib.surface(Palette.METAL_DARK, 0.6))
	for side: float in [-1.0, 1.0]:
		_geo.add_box_at(Vector3(0.3, LOBBY_HEIGHT, depth), Vector3(side * (half - 0.15), LOBBY_HEIGHT * 0.5, -depth * 0.5), wall)
		BuildKit.box_collider_at(_body, Vector3(0.3, LOBBY_HEIGHT, depth), Vector3(side * (half - 0.15), LOBBY_HEIGHT * 0.5, -depth * 0.5))
	_back_wall(FLOOR_Y, LOBBY_HEIGHT, wall)

	# Front: glass either side of the entrance, a band with the building's name above.
	var frame := MatLib.surface(Palette.METAL_DARK, 0.35, 0.6)
	var pane_width := half - 1.1 - 0.4
	for side: float in [-1.0, 1.0]:
		var cx := side * (1.1 + 0.1 + pane_width * 0.5)
		_geo.add_box_at(Vector3(pane_width + 0.2, 0.4, 0.3), Vector3(cx, 0.2, -0.15), frame)
		BuildKit.box_collider_at(_body, Vector3(pane_width + 0.2, 0.4, 0.3), Vector3(cx, 0.2, -0.15))
		BuildKit.glass_pane(_root, Transform3D(Basis.IDENTITY, Vector3(cx, 1.8, -0.15)), Vector3(pane_width, 2.8, 0.04), Color(0.6, 0.4, 1.0, 0.1))
		_geo.add_box_at(Vector3(0.16, 3.2, 0.34), Vector3(side * 1.1, 1.6, -0.15), frame)
		_geo.add_box_at(Vector3(0.3, SHELL_TOP, 0.4), Vector3(side * (half - 0.15), SHELL_TOP * 0.5, -0.1), frame)
	_geo.add_box_at(Vector3(width, SHELL_TOP - 3.2, 0.4), Vector3(0, (SHELL_TOP + 3.2) * 0.5, -0.2), MatLib.surface(Color(0.05, 0.04, 0.07), 0.4, 0.3))
	BuildKit.box_collider_at(_body, Vector3(width, SHELL_TOP - 3.2, 0.4), Vector3(0, (SHELL_TOP + 3.2) * 0.5, -0.2))
	_geo.add_box_at(Vector3(2.2, 0.06, 1.6), Vector3(0, 3.1, 0.7), MatLib.surface(Palette.METAL_DARK, 0.4, 0.6))
	_geo.add_bar(Vector3(-1.1, 3.06, 1.5), Vector3(1.1, 3.06, 1.5), 0.04, MatLib.neon(ACCENT, 4.0))

	# Mailboxes along the west wall, a few with a waiting-mail light.
	var steel := MatLib.surface(Palette.METAL, 0.35, 0.8)
	for row in 5:
		for column in 8:
			var pos := Vector3(-half + 0.34, 0.9 + row * 0.32, -2.0 - column * 0.42)
			_geo.add_box_at(Vector3(0.06, 0.28, 0.38), pos, steel)
			if _rng.randf() < 0.2:
				_geo.add_box_at(Vector3(0.02, 0.04, 0.04), pos + Vector3(0.04, 0.08, 0.12), MatLib.neon(Palette.AMBER, 3.0))
	# The buzzing, flickering light that every lobby has.
	_geo.add_box_at(Vector3(0.12, 0.06, 2.2), Vector3(-2.0, LOBBY_HEIGHT - 0.05, -4.5), MatLib.neon(Palette.COOL_WHITE, 4.0, 0.6, 0.0, 0.3))
	_buzz_light = BuildKit.omni(_root, Vector3(-2.0, LOBBY_HEIGHT - 0.4, -4.5), Palette.COOL_WHITE, 1.0, 9.0)
	BuildKit.omni(_root, Vector3(3.0, LOBBY_HEIGHT - 0.5, -3.0), ACCENT, 1.2, 8.0)
	if not Engine.is_editor_hint():
		var buzz := AudioStreamPlayer3D.new()
		buzz.stream = BUZZ
		buzz.position = Vector3(-2.0, LOBBY_HEIGHT - 0.2, -4.5)
		buzz.unit_size = 2.0
		buzz.max_distance = 14.0
		buzz.volume_db = -10.0
		buzz.autoplay = true
		_root.add_child(buzz)
	# Benches, a plant and the doorman's desk.
	var bench := Vector3(-half + 2.2, FLOOR_Y, -8.6)
	_geo.add_box_at(Vector3(2.0, 0.45, 0.6), bench + Vector3.UP * 0.225, MatLib.surface(Color(0.1, 0.08, 0.12), 0.5))
	BuildKit.box_collider_at(_body, Vector3(2.0, 0.45, 0.6), bench + Vector3.UP * 0.225)
	var pot := Vector3(-half + 0.8, FLOOR_Y, -0.9)
	_geo.add_cylinder(0.35, 0.28, 0.6, 8, Transform3D(Basis.IDENTITY, pot + Vector3.UP * 0.3), MatLib.surface(Color(0.3, 0.3, 0.32), 0.8))
	for i in 7:
		var stem := pot + Vector3(_rng.randf_range(-0.2, 0.2), 0.6, _rng.randf_range(-0.2, 0.2))
		_geo.add_bar(stem, stem + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(0.6, 1.2), _rng.randf_range(-0.3, 0.3)), 0.04, MatLib.neon(Palette.LIME, 2.0))
	var desk := Vector3(half - 2.6, FLOOR_Y, -4.0)
	_geo.add_box_at(Vector3(0.8, 1.05, 2.4), desk + Vector3.UP * 0.525, MatLib.surface(Color(0.08, 0.07, 0.1), 0.4, 0.4))
	_geo.add_box_at(Vector3(0.82, 0.04, 2.42), desk + Vector3.UP * 1.07, MatLib.neon(ACCENT, 2.5))
	BuildKit.box_collider_at(_body, Vector3(0.8, 1.1, 2.4), desk + Vector3.UP * 0.55)
	_build_doorbot(desk + Vector3(0.9, 0, 0))


## The back wall of a level, with the elevator opening cut out of it.
func _back_wall(floor_y: float, height: float, wall: Material) -> void:
	var half := _half()
	var left := SHAFT_X - CAB_HALF
	var right := SHAFT_X + CAB_HALF
	var segments := [Vector2(-half, left), Vector2(right, half)]
	for segment in segments:
		var w: float = segment.y - segment.x
		var center := Vector3((segment.x + segment.y) * 0.5, floor_y + height * 0.5, HALL_BACK_Z - 0.15)
		_geo.add_box_at(Vector3(w, height, 0.3), center, wall)
		BuildKit.box_collider_at(_body, Vector3(w, height, 0.3), center)
	_geo.add_box_at(Vector3(CAB_HALF * 2.0, height - 2.4, 0.3), Vector3(SHAFT_X, floor_y + 2.4 + (height - 2.4) * 0.5, HALL_BACK_Z - 0.15), wall)


func _build_doorbot(pos: Vector3) -> void:
	var shell := MatLib.surface(Color(0.75, 0.75, 0.8), 0.3, 0.7)
	var geo := GeoBatch.new()
	geo.add_cylinder(0.35, 0.4, 0.3, 10, Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0)), MatLib.surface(Palette.METAL_DARK, 0.5, 0.6))
	geo.add_box_at(Vector3(0.6, 0.9, 0.45), Vector3(0, 0.8, 0), shell)
	geo.add_box_at(Vector3(0.45, 0.32, 0.4), Vector3(0, 1.45, 0), shell)
	geo.add_box_at(Vector3(0.38, 0.08, 0.02), Vector3(0, 1.48, -0.21), MatLib.neon(Palette.CYAN, 5.0))
	geo.add_bar(Vector3(0.15, 1.6, 0), Vector3(0.2, 1.9, 0), 0.02, MatLib.surface(Palette.METAL_DARK, 0.5))
	geo.add_box_at(Vector3(0.06, 0.06, 0.06), Vector3(0.2, 1.92, 0), MatLib.neon(Palette.RED, 5.0, 0.0, 0.8))
	var bot := Node3D.new()
	bot.name = "Doorbot"
	bot.position = pos
	bot.rotation.y = -PI * 0.5
	_root.add_child(bot)
	geo.build_into(bot, "Mesh")
	if Engine.is_editor_hint():
		return
	var talk := Interactable.create(bot, Vector3(1.0, 1.2, 1.4), Vector3(0, 1.3, 0), "Talk to the doorbot")
	talk.interacted.connect(_on_doorbot_talk)


func _on_doorbot_talk(_player: Player) -> void:
	var lines := [
		"Welcome home, resident 1107. The elevator is operational. Mostly.",
		"Mail delivery is delayed by eleven to fourteen business days.",
		"Please do not discharge firearms in the lobby. It upsets the plant.",
		"Your rent is paid. I do not know by whom. I was told not to ask.",
		"The neon tube above is scheduled for repair in 2091.",
	]
	get_tree().call_group("hud", "show_message", "DOORBOT: " + lines[_rng.randi() % lines.size()], 3.5)


func _build_signs() -> void:
	var half := _half()
	BuildKit.neon_text(_root, "NEO-HEIGHTS", Transform3D(Basis.IDENTITY, Vector3(0, 4.0, 0.08)), ACCENT, 0.75)
	BuildKit.neon_text(_root, "ネオハイツ", Transform3D(Basis.IDENTITY, Vector3(-half + 2.2, 4.0, 0.08)), Palette.PINK, 0.45)
	BuildKit.omni(_root, Vector3(0, 4.2, 1.6), ACCENT, 3.0, 9.0)
	# Vertical sign running up the corner, readable from both streets.
	var blade := MatLib.surface(Color(0.03, 0.02, 0.05), 0.4, 0.4)
	var corner := Vector3(half + 0.6, 0.0, 0.6)
	_geo.add_box_at(Vector3(1.2, 22.0, 1.2), corner + Vector3.UP * 17.0, blade)
	var tube := MatLib.neon(ACCENT, 4.5, 0.03, 0.0, 0.7)
	for face in 2:
		var basis := Basis.IDENTITY if face == 0 else Basis(Vector3.UP, PI * 0.5)
		var normal := basis * Vector3(0, 0, 0.61)
		var across := basis * Vector3(0.5, 0, 0)
		_geo.add_polyline(PackedVector3Array([corner + normal - across + Vector3.UP * 6.3, corner + normal + across + Vector3.UP * 6.3, corner + normal + across + Vector3.UP * 27.7, corner + normal - across + Vector3.UP * 27.7]), 0.06, tube, true)
		var label := BuildKit.neon_text(_root, "N\nE\nO\n\nH\nE\nI\nG\nH\nT\nS", Transform3D(basis, corner + normal * 1.02 + Vector3.UP * 17.0), ACCENT, 1.5)
		label.line_spacing = -18.0


# --- Elevator ----------------------------------------------------------------------------------

func _build_cab(level: int) -> void:
	var floor_y := FLOOR_Y if level == 0 else UPPER_Y
	var metal := MatLib.surface(Color(0.3, 0.3, 0.34), 0.25, 0.85)
	var back_z := HALL_BACK_Z - CAB_DEPTH
	var center := Vector3(SHAFT_X, floor_y, HALL_BACK_Z - CAB_DEPTH * 0.5)
	_geo.add_box_at(Vector3(CAB_HALF * 2.0, 0.15, CAB_DEPTH), center - Vector3.UP * 0.075, MatLib.surface(Color(0.1, 0.1, 0.12), 0.3, 0.6))
	BuildKit.box_collider_at(_body, Vector3(CAB_HALF * 2.0, 1.0, CAB_DEPTH), center - Vector3.UP * 0.5).set_meta(&"surface", &"metal")
	_geo.add_box_at(Vector3(CAB_HALF * 2.0, 0.1, CAB_DEPTH), center + Vector3.UP * 2.45, metal)
	_geo.add_box_at(Vector3(CAB_HALF * 1.6, 0.04, CAB_DEPTH * 0.6), center + Vector3.UP * 2.39, MatLib.neon(Palette.WARM_WHITE, 2.0))
	_geo.add_box_at(Vector3(CAB_HALF * 2.0, 2.5, 0.1), Vector3(SHAFT_X, floor_y + 1.25, back_z), metal)
	BuildKit.box_collider_at(_body, Vector3(CAB_HALF * 2.0, 2.5, 0.1), Vector3(SHAFT_X, floor_y + 1.25, back_z))
	for side: float in [-1.0, 1.0]:
		var wall_center := Vector3(SHAFT_X + side * CAB_HALF, floor_y + 1.25, center.z)
		_geo.add_box_at(Vector3(0.1, 2.5, CAB_DEPTH), wall_center, metal)
		BuildKit.box_collider_at(_body, Vector3(0.1, 2.5, CAB_DEPTH), wall_center)
	# Control panel with the ride button.
	var panel_pos := Vector3(SHAFT_X + CAB_HALF - 0.07, floor_y + 1.25, HALL_BACK_Z - 0.6)
	_geo.add_box_at(Vector3(0.04, 0.5, 0.25), panel_pos, MatLib.surface(Palette.METAL_DARK, 0.4, 0.5))
	for i in 4:
		_geo.add_box_at(Vector3(0.02, 0.05, 0.05), panel_pos + Vector3(-0.025, 0.15 - i * 0.1, 0), MatLib.neon(ACCENT if i == (0 if level == 0 else 3) else Palette.COOL_WHITE, 2.0))
	# Sliding doors.
	var doors := []
	var door_mat := MatLib.surface(Color(0.38, 0.38, 0.42), 0.2, 0.9)
	for side: float in [-1.0, 1.0]:
		var panel := Node3D.new()
		panel.name = "CabDoor%d_%s" % [level, "L" if side < 0 else "R"]
		var holder := Node3D.new()
		holder.position = Vector3(SHAFT_X + side * 0.35, floor_y, HALL_BACK_Z - 0.06)
		_root.add_child(holder)
		holder.add_child(panel)
		var geo := GeoBatch.new()
		geo.add_box_at(Vector3(0.7, 2.35, 0.06), Vector3(0, 1.175, 0), door_mat)
		geo.add_box_at(Vector3(0.02, 2.0, 0.02), Vector3(-side * 0.34, 1.175, 0.035), MatLib.neon(ACCENT, 2.0))
		geo.build_into(panel, "Mesh")
		doors.append(panel)
	var door_body := BuildKit.static_body(_root, "CabDoorCollision%d" % level)
	doors.append(BuildKit.box_collider_at(door_body, Vector3(1.4, 2.35, 0.1), Vector3(SHAFT_X, floor_y + 1.175, HALL_BACK_Z - 0.06)))
	_cab_doors[level] = doors
	BuildKit.neon_text(_root, "1F" if level == 0 else "11F", Transform3D(Basis.IDENTITY, Vector3(SHAFT_X, floor_y + 2.65, HALL_BACK_Z + 0.02)), ACCENT, 0.18)
	if Engine.is_editor_hint():
		return
	var button := Interactable.create(_root, Vector3(0.3, 0.7, 0.5), panel_pos, "Ride up to floor 11" if level == 0 else "Ride down to the lobby")
	button.interacted.connect(_ride.bind(level))
	if level == 0:
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = HUM
		_hum.unit_size = 3.0
		_root.add_child(_hum)


## Doors close, the screen fades, the player arrives on the other floor and the doors open there.
func _ride(player: Player, from_level: int) -> void:
	if _riding:
		return
	_riding = true
	GameState.claim_ui(&"elevator", false)
	_hum.global_position = player.global_position
	_hum.play()
	await get_tree().create_timer(0.7).timeout
	var hud := get_tree().get_first_node_in_group("hud")
	await hud.fade_to(1.0, 0.5).finished
	var rise := (UPPER_Y - FLOOR_Y) * (1.0 if from_level == 0 else -1.0)
	player.global_position += global_basis.y * rise
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.9).timeout
	_hum.stop()
	SfxPool.play_at(self, DING, player.global_position + Vector3.UP, -6.0, 0.0, 3.0)
	await hud.fade_to(0.0, 0.5).finished
	_riding = false
	GameState.release_ui()


# --- 11th floor --------------------------------------------------------------------------------

## Outer walls, floor and ceiling of the 11th floor. Outside they use the building's window
## facade so the floor blends into the tower; inside they're lined with plain walls.
func _build_upper_shell() -> void:
	var half := _half()
	var depth := 20.0
	var bottom := UPPER_Y - 0.3
	var top := UPPER_Y + UPPER_HEIGHT + 0.4
	var tall := top - bottom
	_geo.color = Color(0.6, 0.57, 0.66, 0.45)
	var facade := MatLib.facade(1, 5.0)
	_geo.add_box_at(Vector3(width, 0.3, depth), Vector3(0, bottom + 0.15, -depth * 0.5), facade)
	BuildKit.box_collider_at(_body, Vector3(width, 1.0, depth), Vector3(0, UPPER_Y - 0.5, -depth * 0.5)).set_meta(&"surface", &"wood")
	_geo.add_box_at(Vector3(width, 0.4, depth), Vector3(0, top - 0.2, -depth * 0.5), facade)
	_geo.add_box_at(Vector3(width, tall, 0.3), Vector3(0, bottom + tall * 0.5, -depth + 0.15), facade)
	_geo.add_box_at(Vector3(0.3, tall, depth), Vector3(-half + 0.15, bottom + tall * 0.5, -depth * 0.5), facade)
	# Street side and cross-street side, each with the apartment's picture window cut out.
	var sill := UPPER_Y + 0.75
	var lintel := UPPER_Y + 2.85
	_wall_with_window(Vector3(-half, bottom, -0.3), Vector3(half, top, 0.0), APARTMENT_X + 0.6, half - 0.6, sill, lintel, facade, true)
	_wall_with_window(Vector3(half - 0.3, bottom, -depth), Vector3(half, top, 0.0), -7.2, -0.9, sill, lintel, facade, false)
	_geo.color = Color.WHITE
	for wall in [[Vector3(width, UPPER_HEIGHT, 0.3), Vector3(0, UPPER_Y + UPPER_HEIGHT * 0.5, -0.15)], [Vector3(0.3, UPPER_HEIGHT, depth), Vector3(half - 0.15, UPPER_Y + UPPER_HEIGHT * 0.5, -depth * 0.5)], [Vector3(0.3, UPPER_HEIGHT, depth), Vector3(-half + 0.15, UPPER_Y + UPPER_HEIGHT * 0.5, -depth * 0.5)]]:
		BuildKit.box_collider_at(_body, wall[0], wall[1])
	# The hallway's end window looks down the cross street.
	_window_glass(Vector3(half - 0.15, UPPER_Y + 1.6, (HALL_FRONT_Z + HALL_BACK_Z) * 0.5), Vector3(0.04, 1.6, 1.4))


## A wall slab between `low` and `high` (corners) with a window from `from` to `to` along it.
func _wall_with_window(low: Vector3, high: Vector3, from: float, to: float, sill: float, lintel: float, material: Material, along_x: bool) -> void:
	var a := low.x if along_x else low.z
	var b := high.x if along_x else high.z
	for span in [Vector2(a, from), Vector2(to, b)]:
		_slab(low, high, span, Vector2(low.y, high.y), material, along_x)
	_slab(low, high, Vector2(from, to), Vector2(low.y, sill), material, along_x)
	_slab(low, high, Vector2(from, to), Vector2(lintel, high.y), material, along_x)
	var glass_center := Vector3((from + to) * 0.5, (sill + lintel) * 0.5, (low.z + high.z) * 0.5) if along_x else Vector3((low.x + high.x) * 0.5, (sill + lintel) * 0.5, (from + to) * 0.5)
	var glass_size := Vector3(to - from, lintel - sill, 0.04) if along_x else Vector3(0.04, lintel - sill, to - from)
	_window_glass(glass_center, glass_size)
	_geo.color = Color.WHITE
	_geo.add_box_at(Vector3(glass_size.x + 0.1, 0.08, 0.4) if along_x else Vector3(0.4, 0.08, glass_size.z + 0.1), glass_center - Vector3.UP * (glass_size.y * 0.5 + 0.04), MatLib.surface(Palette.METAL_DARK, 0.4, 0.5))
	_geo.color = Color(0.6, 0.57, 0.66, 0.45)


func _slab(low: Vector3, high: Vector3, span: Vector2, vertical: Vector2, material: Material, along_x: bool) -> void:
	if span.y - span.x < 0.01 or vertical.y - vertical.x < 0.01:
		return
	var size := Vector3(span.y - span.x, vertical.y - vertical.x, high.z - low.z) if along_x else Vector3(high.x - low.x, vertical.y - vertical.x, span.y - span.x)
	var center := Vector3((span.x + span.y) * 0.5, (vertical.x + vertical.y) * 0.5, (low.z + high.z) * 0.5) if along_x else Vector3((low.x + high.x) * 0.5, (vertical.x + vertical.y) * 0.5, (span.x + span.y) * 0.5)
	_geo.add_box_at(size, center, material)


## Unbreakable window glass (eleven floors up, nobody should fall out of it).
func _window_glass(center: Vector3, size: Vector3) -> void:
	_geo.add_box_at(size, center, MatLib.glass(Color(0.5, 0.6, 1.0, 0.08)))
	BuildKit.box_collider_at(_body, size + Vector3(0.1, 0.0, 0.1) * Vector3(1.0 if size.x < 0.1 else 0.0, 0.0, 1.0 if size.z < 0.1 else 0.0), center)


func _build_hallway() -> void:
	var half := _half()
	var lining := MatLib.surface(Color(0.24, 0.2, 0.26), 0.7)
	var carpet := MatLib.surface(Color(0.2, 0.05, 0.1), 0.9, 0.0, 0.1)
	var hall_center_z := (HALL_FRONT_Z + HALL_BACK_Z) * 0.5
	var hall_width := HALL_FRONT_Z - HALL_BACK_Z
	_geo.add_box_at(Vector3(width - 0.6, 0.02, hall_width), Vector3(0, UPPER_Y + 0.01, hall_center_z), carpet)
	_geo.add_box_at(Vector3(width - 0.6, 0.05, hall_width), Vector3(0, UPPER_Y + UPPER_HEIGHT - 0.025, hall_center_z), MatLib.surface(Color(0.1, 0.1, 0.12), 0.7))
	# Hallway walls: the back one has the elevator, the front one the apartment doors.
	_back_wall(UPPER_Y, UPPER_HEIGHT, lining)
	var door_x := 4.9
	for span in [Vector2(-half, door_x - 0.6), Vector2(door_x + 0.6, half)]:
		var w: float = span.y - span.x
		var center := Vector3((span.x + span.y) * 0.5, UPPER_Y + UPPER_HEIGHT * 0.5, HALL_FRONT_Z + 0.15)
		_geo.add_box_at(Vector3(w, UPPER_HEIGHT, 0.3), center, lining)
		BuildKit.box_collider_at(_body, Vector3(w, UPPER_HEIGHT, 0.3), center)
	_geo.add_box_at(Vector3(1.2, UPPER_HEIGHT - 2.3, 0.3), Vector3(door_x, UPPER_Y + 2.3 + (UPPER_HEIGHT - 2.3) * 0.5, HALL_FRONT_Z + 0.15), lining)
	_geo.add_box_at(Vector3(0.3, UPPER_HEIGHT, -HALL_FRONT_Z), Vector3(APARTMENT_X - 0.15, UPPER_Y + UPPER_HEIGHT * 0.5, HALL_FRONT_Z * 0.5), lining)
	BuildKit.box_collider_at(_body, Vector3(0.3, UPPER_HEIGHT, -HALL_FRONT_Z), Vector3(APARTMENT_X - 0.15, UPPER_Y + UPPER_HEIGHT * 0.5, HALL_FRONT_Z * 0.5))
	# Hallway end walls (the east one has the window built into the shell).
	_geo.add_box_at(Vector3(0.05, UPPER_HEIGHT, hall_width), Vector3(-half + 0.33, UPPER_Y + UPPER_HEIGHT * 0.5, hall_center_z), lining)
	# Doors: the player's apartment and the neighbours' (locked).
	var doors := [[door_x, HALL_FRONT_Z, 0.0, "1107", false], [-1.2, HALL_FRONT_Z, 0.0, "1106", true], [-6.4, HALL_FRONT_Z, 0.0, "1105", true],
		[-1.2, HALL_BACK_Z, PI, "1101", true], [1.9, HALL_BACK_Z, PI, "1102", true], [5.0, HALL_BACK_Z, PI, "1103", true]]
	for entry in doors:
		var door := Door.new()
		door.number = entry[3]
		door.locked = entry[4]
		door.accent = ACCENT
		door.name = "Door" + entry[3]
		door.position = Vector3(entry[0], UPPER_Y, entry[1] + (0.04 if entry[2] == PI else -0.04) * -1.0)
		door.rotation.y = entry[2]
		_root.add_child(door)
	# Flickering strip lights and a little life on the walls.
	for i in 4:
		var x := -half + 2.5 + i * 4.0
		_geo.add_box_at(Vector3(1.2, 0.04, 0.12), Vector3(x, UPPER_Y + UPPER_HEIGHT - 0.06, hall_center_z), MatLib.neon(Palette.COOL_WHITE, 3.0, 0.15 if i == 2 else 0.0, 0.0, float(i)))
	BuildKit.omni(_root, Vector3(-3.0, UPPER_Y + UPPER_HEIGHT - 0.4, hall_center_z), Palette.COOL_WHITE, 1.0, 8.0)
	BuildKit.omni(_root, Vector3(4.0, UPPER_Y + UPPER_HEIGHT - 0.4, hall_center_z), ACCENT, 0.9, 7.0)
	BuildKit.neon_text(_root, "NO SMOKING  //  NO DRONES", Transform3D(Basis(Vector3.UP, PI), Vector3(-2.8, UPPER_Y + 2.4, HALL_FRONT_Z - 0.01)), Palette.RED, 0.12)
