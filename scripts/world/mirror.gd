class_name Mirror
extends Node3D
## A working mirror: a camera mirrored across the glass renders the room (and the player, head
## and all) into a small SubViewport that the glass shows flipped. The mirrored camera uses an
## off-centre frustum whose near plane is the glass, so nothing behind the wall leaks in. It skips
## the first-person gun (render layer 2) and sees the player's head and arms (layer 3). It only
## renders while the player is close and on the front side; otherwise it keeps its last picture.
## The glass faces local +Z; `size` is its width and height in metres.

const SHADER := preload("res://shaders/mirror.gdshader")

@export var size := Vector2(0.8, 1.0)
## Height of the reflection in pixels (kept low on purpose).
@export var pixels := 160
@export var active_distance := 7.0
@export var frame_color := Color(0.12, 0.12, 0.14)
@export var trim := Palette.CYAN

var _viewport: SubViewport
var _camera: Camera3D
var _glass: MeshInstance3D


static func create(parent: Node, xform: Transform3D, glass_size: Vector2, trim_color := Palette.CYAN) -> Mirror:
	var mirror := Mirror.new()
	mirror.transform = xform
	mirror.size = glass_size
	mirror.trim = trim_color
	parent.add_child(mirror)
	return mirror


func _ready() -> void:
	add_to_group("mirrors")
	var frame := GeoBatch.new()
	var border := 0.05
	frame.add_box_at(Vector3(size.x + border * 2.0, size.y + border * 2.0, 0.03), Vector3(0, 0, -0.016), MatLib.surface(frame_color, 0.4, 0.6))
	frame.add_box_at(Vector3(size.x + border * 2.0 + 0.01, 0.012, 0.036), Vector3(0, size.y * 0.5 + border, -0.01), MatLib.neon(trim, 2.0))
	frame.add_box_at(Vector3(size.x + border * 2.0 + 0.01, 0.012, 0.036), Vector3(0, -size.y * 0.5 - border, -0.01), MatLib.neon(trim, 2.0))
	frame.add_box_at(Vector3(size.x * 0.7, 0.04, 0.08), Vector3(0, size.y * 0.5 + border + 0.04, 0.03), MatLib.neon(Palette.WARM_WHITE, 3.0))
	frame.build_into(self, "Frame", false)
	# A vanity light over the glass, so whoever looks in sees their face, not a silhouette.
	BuildKit.omni(self, Vector3(0, size.y * 0.5 + 0.15, 0.45), Palette.WARM_WHITE, 1.2, 3.2)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(maxi(8, roundi(pixels * size.x / size.y)), pixels)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_camera.cull_mask = 0xFFFFF & ~RifleModel.VIEW_MODEL_LAYER
	_camera.current = true
	_viewport.add_child(_camera)
	var quad := QuadMesh.new()
	quad.size = size
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("reflection", _viewport.get_texture())
	_glass = MeshInstance3D.new()
	_glass.name = "Glass"
	_glass.mesh = quad
	_glass.material_override = material
	_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glass)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var eye: Camera3D = get_viewport().get_camera_3d()
	var active := player != null and eye != null and is_visible_in_tree()
	if active:
		var normal := global_basis.z.normalized()
		var to_eye := eye.global_position - global_position
		active = to_eye.length() < active_distance and to_eye.dot(normal) > 0.05
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if active:
		_follow(eye.global_position)


## Puts the mirrored camera behind the glass, looking out through it at the room.
func _follow(eye: Vector3) -> void:
	var normal := global_basis.z.normalized()
	var up := global_basis.y.normalized()
	var distance := (eye - global_position).dot(normal)
	var mirrored := eye - normal * distance * 2.0
	var basis := Basis(up.cross(-normal), up, -normal)
	_camera.global_transform = Transform3D(basis, mirrored)
	var center := basis.inverse() * (global_position - mirrored)
	_camera.set_frustum(size.y, Vector2(center.x, center.y), maxf(0.02, distance - 0.01), 80.0)
