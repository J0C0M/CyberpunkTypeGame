class_name RetroScreen
extends SubViewportContainer
## Renders the game world at a low internal resolution and upscales it with nearest-neighbour
## filtering; the attached retro_post shader adds the colour grade, dithering and quantization.
## F3 toggles the retro filter, F2 toggles the PS1 vertex wobble.

## Vertical resolution the game renders at (the window is divided by a whole number to get close).
@export var target_height := 360
@export var retro_enabled := true:
	set(value):
		retro_enabled = value
		if is_inside_tree():
			_apply()


func _ready() -> void:
	get_viewport().size_changed.connect(_apply)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_retro_filter"):
		retro_enabled = not retro_enabled
	elif event.is_action_pressed("toggle_vertex_wobble"):
		var wobble: Variant = RenderingServer.global_shader_parameter_get("ps1_wobble")
		RenderingServer.global_shader_parameter_set("ps1_wobble", 0.0 if wobble and wobble > 0.0 else 1.0)


func _apply() -> void:
	var window_height := get_viewport().get_visible_rect().size.y
	stretch_shrink = maxi(1, roundi(window_height / target_height)) if retro_enabled else 1
	var post := material as ShaderMaterial
	if post:
		post.set_shader_parameter("enabled", retro_enabled)
