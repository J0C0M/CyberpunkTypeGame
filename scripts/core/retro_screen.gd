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


var _wobble_enabled := true


func _ready() -> void:
	add_to_group("retro_screen")
	get_viewport().size_changed.connect(_apply)
	apply_settings()


## Reads the retro-filter strength from Settings: 0 turns the filter off; higher values mean
## bigger pixels, fewer colours and stronger dithering (0.6 is the original look).
func apply_settings() -> void:
	var strength := Settings.retro_strength
	retro_enabled = strength > 0.01
	target_height = roundi(360.0 * pow(2.0, (0.6 - strength) * 1.25))
	var post := material as ShaderMaterial
	if post:
		post.set_shader_parameter("dither_strength", 1.4 * strength)
		post.set_shader_parameter("color_levels", lerpf(64.0, 18.0, strength))
		post.set_shader_parameter("vignette", minf(0.6, 0.63 * strength))
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_retro_filter"):
		retro_enabled = not retro_enabled
		get_tree().call_group("hud", "show_message", "RETRO FILTER " + ("ON" if retro_enabled else "OFF"))
	elif event.is_action_pressed("toggle_vertex_wobble"):
		_wobble_enabled = not _wobble_enabled
		RenderingServer.global_shader_parameter_set("ps1_wobble", 1.0 if _wobble_enabled else 0.0)
		get_tree().call_group("hud", "show_message", "VERTEX WOBBLE " + ("ON" if _wobble_enabled else "OFF"))


func _apply() -> void:
	var window_height := get_viewport().get_visible_rect().size.y
	stretch_shrink = maxi(1, roundi(window_height / target_height)) if retro_enabled else 1
	var post := material as ShaderMaterial
	if post:
		post.set_shader_parameter("enabled", retro_enabled)
