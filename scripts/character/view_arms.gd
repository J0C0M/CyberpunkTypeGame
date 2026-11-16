class_name ViewArms
extends Node3D
## The first-person arms: the character's own hands, forearms and upper arms (same skin, tattoos,
## glowing ink, muscle and outfit sleeves as the body, from CharacterModel.part_mesh) holding the
## gun in hand. Every frame each hand goes to the gun model's hand marker (right_hand / left_hand)
## and a two-bone IK bends the elbow towards fixed shoulder points below the camera. Lives in the
## WeaponHolder (camera space) on the view-model render layer, so it sways and switches with the gun.

## Shoulder points in camera space (out of view, below and to the sides of the camera).
const SHOULDER_R := Vector3(0.32, -0.6, 0.1)
const SHOULDER_L := Vector3(-0.3, -0.62, 0.02)
## First-person arms are drawn a bit bigger and longer than the body's, as in most shooters, so
## they reach a rifle's handguard without stretching.
const VIEW_SCALE := 1.25
## Which way the elbows point (down and outwards).
const POLE_R := Vector3(0.7, -1.0, 0.2)
const POLE_L := Vector3(-0.7, -1.0, 0.2)

var holder: WeaponHolder

## side ("r"/"l") -> {"hand", "forearm", "upper_arm"} -> Node3D holding the skin and sleeve meshes
var _segments := {}
var _lengths := {}


## Builds the arms from `body` (the player's CharacterModel).
func build(body: CharacterModel) -> void:
	for child in get_children():
		child.queue_free()
	_segments.clear()
	var data := body.data
	for side: String in ["r", "l"]:
		_segments[side] = {}
		for part: String in ["hand", "forearm", "upper_arm"]:
			var region := StringName(part + "_" + side)
			var segment := Node3D.new()
			segment.name = String(region)
			add_child(segment)
			if not body.is_covered(region):
				_add_mesh(segment, body.part_mesh(region, false), body, data.muscle)
			var sleeve := body.part_mesh(region, true)
			if sleeve.get_surface_count() > 0:
				_add_mesh(segment, sleeve, body, data.muscle)
			_segments[side][part] = segment
			_lengths[part] = CharacterRig.region_size(region, data.frame).y * VIEW_SCALE


func _add_mesh(parent: Node3D, mesh: ArrayMesh, body: CharacterModel, muscle: float) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = body.material()
	instance.layers = RifleModel.VIEW_MODEL_LAYER
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	instance.set_blend_shape_value(0, muscle)


func _process(_delta: float) -> void:
	var gun := holder.current if holder else null
	var model: Node3D = gun.model if gun else null
	var right: Node3D = model.get("right_hand") if model else null
	var left: Node3D = model.get("left_hand") if model else null
	visible = right != null
	if not visible or _segments.is_empty():
		return
	var to_local := global_transform.affine_inverse()
	_place("r", to_local * right.global_position, SHOULDER_R, POLE_R)
	if left:
		_place("l", to_local * left.global_position, SHOULDER_L, POLE_L)
	for part in _segments["l"]:
		(_segments["l"][part] as Node3D).visible = left != null


## Puts one arm's hand on `grip` and bends it back to `shoulder`.
func _place(side: String, grip: Vector3, shoulder: Vector3, pole: Vector3) -> void:
	var hand_len: float = _lengths["hand"]
	var fore: float = _lengths["forearm"]
	var upper: float = _lengths["upper_arm"]
	var wrist := grip + (shoulder - grip).normalized() * hand_len * 0.5
	var reach := wrist.distance_to(shoulder)
	var direction := (wrist - shoulder) / maxf(reach, 0.001)
	var elbow: Vector3
	if reach >= (upper + fore) * 0.999:
		# Out of reach: a straight arm, stretched a little (the upper arm is off screen anyway).
		elbow = shoulder + direction * reach * upper / (upper + fore)
	else:
		var along := (upper * upper - fore * fore + reach * reach) / (2.0 * reach)
		var bend := sqrt(maxf(0.0, upper * upper - along * along))
		var side_dir := (pole - direction * pole.dot(direction)).normalized()
		elbow = shoulder + direction * along + side_dir * bend
	_segment(_segments[side]["hand"], grip, wrist, hand_len)
	_segment(_segments[side]["forearm"], (wrist + elbow) * 0.5, elbow, fore, wrist)
	_segment(_segments[side]["upper_arm"], (elbow + shoulder) * 0.5, shoulder, upper, elbow)


## Places a segment centred on `center`, its +Y towards `toward`; stretched to fit when it spans
## from `start` to `toward` (the hand keeps its size).
func _segment(segment: Node3D, center: Vector3, toward: Vector3, length: float, start := Vector3.INF) -> void:
	var y := (toward - center).normalized()
	# +X (the outside of the right arm, the inside of the left) faces right; the front face (-Z)
	# then faces up at the camera, where forearm tattoos show.
	var x := (Vector3.RIGHT - y * Vector3.RIGHT.dot(y)).normalized()
	var z := x.cross(y)
	var stretch := 1.0
	if start != Vector3.INF:
		stretch = start.distance_to(toward) / length
	segment.transform = Transform3D(Basis(x * VIEW_SCALE, y * stretch * VIEW_SCALE, z * VIEW_SCALE), center)
