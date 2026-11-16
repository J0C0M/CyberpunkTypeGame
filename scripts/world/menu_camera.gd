extends Camera3D
## The title screen's camera: drifts slowly up and down Kabuki Ave in the rain, looking along the
## street and up at the towers so the robot dragons fly through the shot.

const RAIN_AMOUNT := 700

var _time := 0.0


func _ready() -> void:
	current = true
	fov = 62.0
	_time = randf() * 200.0
	add_child(_make_rain())


func _process(delta: float) -> void:
	_time += delta
	var x := sin(_time * 0.018) * 38.0
	position = Vector3(x, 3.4 + sin(_time * 0.13) * 0.4, 1.8 + sin(_time * 0.07) * 1.6)
	var heading := -1.0 if cos(_time * 0.018) > 0.0 else 1.0
	look_at(position + Vector3(heading * 40.0, 7.5 + sin(_time * 0.05) * 3.0, sin(_time * 0.04) * 8.0), Vector3.UP)


## Pale streaks falling around the camera.
func _make_rain() -> GPUParticles3D:
	var rain := GPUParticles3D.new()
	rain.amount = RAIN_AMOUNT
	rain.lifetime = 1.1
	rain.preprocess = 1.0
	rain.position = Vector3(0, 9.0, 0)
	rain.visibility_aabb = AABB(Vector3(-20, -25, -20), Vector3(40, 30, 40))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(16, 0.5, 16)
	process.direction = Vector3(0.08, -1, 0)
	process.spread = 2.0
	process.initial_velocity_min = 18.0
	process.initial_velocity_max = 24.0
	process.gravity = Vector3(0, -6, 0)
	rain.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.7)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.7, 0.8, 1.0, 0.35)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	quad.material = material
	rain.draw_pass_1 = quad
	return rain
