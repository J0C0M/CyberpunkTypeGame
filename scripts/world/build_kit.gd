@tool
class_name BuildKit
extends RefCounted
## Helpers for the procedural builders: lights, neon text and static colliders.

const LAYER_WORLD := 1


static func omni(parent: Node, pos: Vector3, color: Color, energy := 2.0, light_range := 8.0, shadow := false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = shadow
	parent.add_child(light)
	return light


## Spotlight at `pos` pointing straight down.
static func down_spot(parent: Node, pos: Vector3, color: Color, energy := 3.0, light_range := 12.0, angle := 45.0, shadow := false) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), pos)
	light.light_color = color
	light.light_energy = energy
	light.spot_range = light_range
	light.spot_angle = angle
	light.spot_attenuation = 0.8
	light.shadow_enabled = shadow
	parent.add_child(light)
	return light


## Neon text: a hot near-white core with a coloured outline, unshaded so it glows at night.
## The label faces local +Z of `xform`.
static func neon_text(parent: Node, text: String, xform: Transform3D, color: Color, height := 0.5, double_sided := false) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.transform = xform
	label.font_size = 64
	label.outline_size = 14
	label.pixel_size = height / 64.0
	label.modulate = color.lerp(Color.WHITE, 0.55)
	label.outline_modulate = color
	label.shaded = false
	label.double_sided = double_sided
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	parent.add_child(label)
	return label


## Plain (non-glowing) text, e.g. dark lettering on a lit menu board.
static func flat_text(parent: Node, text: String, xform: Transform3D, color: Color, height := 0.2) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.transform = xform
	label.font_size = 48
	label.outline_size = 0
	label.pixel_size = height / 48.0
	label.modulate = color
	label.shaded = false
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	parent.add_child(label)
	return label


## Breakable glass pane centred on `xform` (see GlassPane).
static func glass_pane(parent: Node, xform: Transform3D, size: Vector3, tint := Color(0.4, 0.7, 1.0, 0.1)) -> GlassPane:
	var pane := GlassPane.new()
	pane.size = size
	pane.tint = tint
	pane.transform = xform
	parent.add_child(pane)
	return pane


static func static_body(parent: Node, node_name := "Collision") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	parent.add_child(body)
	return body


static func box_collider(body: StaticBody3D, size: Vector3, xform: Transform3D) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = xform
	body.add_child(collider)
	return collider


static func box_collider_at(body: StaticBody3D, size: Vector3, center: Vector3) -> CollisionShape3D:
	return box_collider(body, size, Transform3D(Basis.IDENTITY, center))


## Removes previously generated children so @tool builders can rebuild in the editor.
static func clear_generated(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta("generated"):
			node.remove_child(child)
			child.queue_free()


## Root container for generated content; marked so `clear_generated` can find it again.
static func generated_root(parent: Node, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.set_meta("generated", true)
	parent.add_child(root)
	return root
