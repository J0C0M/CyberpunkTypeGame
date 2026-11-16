@tool
class_name RobotDragon
extends Node3D
## Ambient flying robot dragon: a low-poly mechanical serpent made of armoured segments with
## neon accents and glowing eyes. It glides along a looping FlightPath; each segment follows the
## one in front with a travelling wave, so the body snakes through the air. No gameplay yet.

@export var flight_path: NodePath
@export var speed := 24.0
@export var segment_count := 30
## Distance between segments along the path, in metres (before body_scale).
@export var segment_spacing := 3.6
@export var body_scale := 1.0
@export var accent_color := Color(0.1, 0.88, 1.0)
@export var eye_color := Color(1.0, 0.15, 0.1)
@export var wave_amplitude := 3.0
@export var wave_speed := 1.6
## Starting position along the loop, 0..1.
@export_range(0.0, 1.0) var start_offset := 0.0
## Adds a coloured light to the head; worth it for dragons that fly low between the buildings.
@export var head_light := false
## Looping engine sound played from the head (optional).
@export var hum: AudioStream

const BODY_RADIUS := 2.4

var _path: Path3D
var _head: Node3D
var _jaw: Node3D
var _segments: Array[Node3D] = []
## Distance of each segment behind the head along the path (segments shrink, so do the gaps).
var _offsets := PackedFloat32Array()
var _positions := PackedVector3Array()
var _travel := 0.0
var _time := 0.0


func _ready() -> void:
	BuildKit.clear_generated(self)
	var root := BuildKit.generated_root(self, "Generated")
	_segments.clear()
	_build_body(root)
	_offsets.resize(_segments.size())
	var distance := 0.0
	for i in _segments.size():
		_offsets[i] = distance
		distance += segment_spacing * (_segment_scale(i) + _segment_scale(i + 1)) * 0.5
	_path = get_node_or_null(flight_path) as Path3D
	if _path and _path.curve and _path.curve.get_baked_length() > 0.0:
		_travel = start_offset * _path.curve.get_baked_length()
		_update_pose()
	else:
		_lay_out_straight()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _path == null or _path.curve == null:
		return
	_time += delta
	_travel += speed * delta
	_update_pose()
	_jaw.rotation.x = 0.12 + sin(_time * 1.3) * 0.12


func _update_pose() -> void:
	var curve := _path.curve
	var length := curve.get_baked_length()
	var to_world := _path.global_transform
	_positions.resize(_segments.size())
	for i in _segments.size():
		var d := fposmod(_travel - _offsets[i], length)
		var p := to_world * curve.sample_baked(d, true)
		var ahead := to_world * curve.sample_baked(fposmod(d + 2.0, length), true)
		var forward := (ahead - p).normalized()
		var side := forward.cross(Vector3.UP).normalized()
		var wave := _time * wave_speed - i * 0.35
		var amount := wave_amplitude * body_scale * minf(1.0, i / 4.0 + 0.3)
		_positions[i] = p + side * sin(wave) * amount + Vector3.UP * cos(wave * 0.8) * amount * 0.5
	for i in _segments.size():
		var direction: Vector3
		if i == 0:
			direction = _positions[0] - _positions[1]
		else:
			direction = _positions[i - 1] - _positions[i]
		if direction.length_squared() < 0.0001:
			continue
		var basis := Basis.looking_at(direction.normalized(), Vector3.UP)
		_segments[i].global_transform = Transform3D(basis.scaled(Vector3.ONE * _segment_scale(i)), _positions[i])


func _lay_out_straight() -> void:
	for i in _segments.size():
		_segments[i].transform = Transform3D(Basis.from_scale(Vector3.ONE * _segment_scale(i)), Vector3(0, 0, _offsets[i]))


## Head and front segments are full size; the body tapers towards the tail.
func _segment_scale(index: int) -> float:
	var t := float(index) / maxf(1.0, segment_count - 1)
	return body_scale * lerpf(1.0, 0.3, pow(t, 1.3))


func _build_body(root: Node3D) -> void:
	var metal := MatLib.surface(Color(0.22, 0.22, 0.28), 0.25, 0.9, 0.05)
	var plate := MatLib.surface(Color(0.32, 0.3, 0.38), 0.3, 0.85, 0.05)
	var accent := MatLib.neon(accent_color, 4.5)
	var eyes := MatLib.neon(eye_color, 9.0)

	_head = Node3D.new()
	_head.name = "Head"
	root.add_child(_head)
	var head_geo := GeoBatch.new()
	_build_head(head_geo, metal, plate, accent, eyes)
	head_geo.build_into(_head, "HeadMesh")
	if head_light:
		BuildKit.omni(_head, Vector3(0, -1.0, -3.0), accent_color, 6.0, 28.0)
	if hum and not Engine.is_editor_hint():
		var engine := AudioStreamPlayer3D.new()
		engine.stream = hum
		engine.unit_size = 22.0 * body_scale
		engine.max_distance = 320.0
		engine.volume_db = -4.0
		engine.autoplay = true
		engine.bus = &"Ambience"
		_head.add_child(engine)
	_jaw = Node3D.new()
	_jaw.name = "Jaw"
	_jaw.position = Vector3(0, -0.9, -1.0)
	_head.add_child(_jaw)
	var jaw_geo := GeoBatch.new()
	jaw_geo.add_box_at(Vector3(2.2, 0.6, 4.6), Vector3(0, -0.3, -2.4), metal)
	for side: float in [-1.0, 1.0]:
		jaw_geo.add_bar(Vector3(side * 0.95, 0.05, -0.6), Vector3(side * 0.8, 0.05, -4.6), 0.18, accent)
	jaw_geo.build_into(_jaw, "JawMesh")
	_segments.append(_head)

	var segment_geo := GeoBatch.new()
	_build_segment(segment_geo, metal, plate, accent)
	var segment_mesh := segment_geo.build_mesh()
	var leg_geo := GeoBatch.new()
	_build_segment(leg_geo, metal, plate, accent)
	_build_legs(leg_geo, metal, accent)
	var leg_mesh := leg_geo.build_mesh()
	var tail_geo := GeoBatch.new()
	_build_segment(tail_geo, metal, plate, accent)
	_build_tail_fin(tail_geo, plate, accent)
	var tail_mesh := tail_geo.build_mesh()

	for i in range(1, segment_count):
		var segment := MeshInstance3D.new()
		segment.name = "Segment%d" % i
		if i == segment_count - 1:
			segment.mesh = tail_mesh
		elif i == 3 or i == int(segment_count * 0.45):
			segment.mesh = leg_mesh
		else:
			segment.mesh = segment_mesh
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(segment)
		_segments.append(segment)


## Head faces local -Z. Skull, snout, horns, glowing eyes and whisker feelers.
func _build_head(geo: GeoBatch, metal: Material, plate: Material, accent: Material, eyes: Material) -> void:
	geo.add_box_at(Vector3(3.6, 2.4, 4.0), Vector3(0, 0.3, -0.8), metal)
	geo.add_box_at(Vector3(2.6, 1.5, 4.2), Vector3(0, 0.0, -4.4), metal)
	geo.add_box_at(Vector3(2.0, 0.5, 3.6), Vector3(0, 0.95, -4.0), plate)
	geo.add_box(Vector3(3.2, 0.5, 3.0), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-12.0)), Vector3(0, 1.6, -0.4)), plate)
	# Eyes and brow lights.
	for side: float in [-1.0, 1.0]:
		geo.add_box_at(Vector3(0.6, 0.4, 0.9), Vector3(side * 1.5, 0.8, -2.6), eyes)
		geo.add_bar(Vector3(side * 1.6, 1.25, -3.2), Vector3(side * 1.2, 1.9, -0.4), 0.16, accent)
		# Horns sweeping back.
		geo.add_bar(Vector3(side * 1.1, 1.6, -0.4), Vector3(side * 2.0, 3.0, 2.6), 0.35, plate)
		geo.add_bar(Vector3(side * 2.0, 3.0, 2.6), Vector3(side * 2.4, 3.4, 4.2), 0.2, accent)
		# Whisker feelers from the snout.
		geo.add_polyline(PackedVector3Array([
			Vector3(side * 1.2, -0.3, -6.2), Vector3(side * 2.6, -0.8, -5.4), Vector3(side * 3.8, -1.6, -3.4), Vector3(side * 4.4, -2.6, -1.0),
		]), 0.12, accent)
		# Nostril vents.
		geo.add_box_at(Vector3(0.4, 0.25, 0.2), Vector3(side * 0.7, 0.3, -6.5), accent)
	# Neck plates bridging to the first segment.
	geo.add_cylinder(BODY_RADIUS, BODY_RADIUS * 0.9, 2.4, 6, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 1.6)), metal)


## One body segment around local Z (forward is -Z), BODY_RADIUS wide.
func _build_segment(geo: GeoBatch, metal: Material, plate: Material, accent: Material) -> void:
	var r := BODY_RADIUS
	var length := segment_spacing * 1.15
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)
	geo.add_cylinder(r, r * 0.92, length, 6, Transform3D(along_z, Vector3.ZERO), metal)
	geo.add_box_at(Vector3(r * 1.3, r * 0.35, length * 0.85), Vector3(0, r * 0.95, -0.1), plate)
	geo.add_box(Vector3(0.16, r * 1.1, length * 0.55), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-28.0)), Vector3(0, r * 1.45, 0.3)), plate)
	geo.add_cylinder(r * 1.06, r * 1.06, 0.22, 6, Transform3D(along_z, Vector3(0, 0, length * 0.45)), accent)
	for side: float in [-1.0, 1.0]:
		geo.add_bar(Vector3(side * r * 0.97, -r * 0.1, -length * 0.4), Vector3(side * r * 0.97, -r * 0.1, length * 0.3), 0.14, accent)
	geo.add_box_at(Vector3(r * 1.0, r * 0.25, length * 0.8), Vector3(0, -r * 0.88, 0), plate)


func _build_legs(geo: GeoBatch, metal: Material, accent: Material) -> void:
	var r := BODY_RADIUS
	for side: float in [-1.0, 1.0]:
		var hip := Vector3(side * r * 0.9, -r * 0.5, 0)
		var knee := Vector3(side * r * 1.7, -r * 1.4, -0.6)
		var foot := Vector3(side * r * 1.5, -r * 2.2, 0.8)
		geo.add_bar(hip, knee, 0.5, metal)
		geo.add_bar(knee, foot, 0.4, metal)
		for claw in 3:
			var spread := (claw - 1) * 0.45
			geo.add_bar(foot, foot + Vector3(spread, -0.5, -0.9), 0.14, accent)


func _build_tail_fin(geo: GeoBatch, plate: Material, accent: Material) -> void:
	var r := BODY_RADIUS
	geo.add_box_at(Vector3(0.2, r * 2.8, r * 2.2), Vector3(0, 0, r * 1.6), plate)
	geo.add_polyline(PackedVector3Array([
		Vector3(0, r * 1.4, r * 0.6), Vector3(0, r * 1.4, r * 2.7), Vector3(0, -r * 1.4, r * 2.7), Vector3(0, -r * 1.4, r * 0.6),
	]), 0.16, accent)
