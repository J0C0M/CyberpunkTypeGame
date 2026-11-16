class_name TvSet
extends Node3D
## Flat-screen TV with four invented channels: NEO-7 News with a ticker, an advert for the made-up
## Vantalume corporation, an abstract anime-style action show and static. The picture is a
## SubViewport (shader + labels) shown on the screen mesh, with a looping soundtrack per channel.
## The screen faces local +Z.

signal channel_changed(index: int)

const CHANNELS := ["NEO-7 NEWS", "VANTALUME", "MECHA-KOI STRIKE!!", "NO SIGNAL"]
const SOUNDS := [
	preload("res://assets/audio/tv/news.wav"),
	preload("res://assets/audio/tv/advert.wav"),
	preload("res://assets/audio/tv/anime.wav"),
	preload("res://assets/audio/tv/static.wav"),
]
const TICKER := "DRAGON DRONES REROUTED OVER WARD 3  ///  RAIN EXPECTED TO REMAIN THEORETICAL  ///  NOODLE PRICES STABLE, SAYS LOCAL COOK  ///  BLOCK 7 ELEVATOR VOTED 'MOSTLY OPERATIONAL'  ///  "

@export var screen_size := Vector2(1.3, 0.74)

var is_on := false
var channel := 0

var _viewport: SubViewport
var _picture: ColorRect
var _labels: Array[Control] = []
var _ticker: Label
var _channel_tag: Label
var _screen: MeshInstance3D
var _on_material: StandardMaterial3D
var _off_material: StandardMaterial3D
var _audio: AudioStreamPlayer3D
var _glow: OmniLight3D
var _switching := 0.0
var _tag_time := 0.0


func _ready() -> void:
	_build_picture()
	var geo := GeoBatch.new()
	geo.add_box_at(Vector3(screen_size.x + 0.08, screen_size.y + 0.08, 0.06), Vector3(0, 0, -0.035), MatLib.surface(Color(0.03, 0.03, 0.04), 0.3, 0.4))
	geo.add_box_at(Vector3(0.06, 0.06, 0.02), Vector3(screen_size.x * 0.5 - 0.06, -screen_size.y * 0.5 - 0.02, 0.0), MatLib.neon(Palette.RED, 2.0))
	geo.build_into(self, "Frame")
	var quad := QuadMesh.new()
	quad.size = screen_size
	_screen = MeshInstance3D.new()
	_screen.mesh = quad
	_screen.position = Vector3(0, 0, 0.002)
	add_child(_screen)
	_on_material = StandardMaterial3D.new()
	_on_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_on_material.albedo_texture = _viewport.get_texture()
	_on_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_off_material = StandardMaterial3D.new()
	_off_material.albedo_color = Color(0.02, 0.02, 0.03)
	_off_material.roughness = 0.08
	_off_material.metallic = 0.4
	_screen.material_override = _off_material
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 3.0
	_audio.max_distance = 20.0
	_audio.volume_db = -8.0
	add_child(_audio)
	_glow = BuildKit.omni(self, Vector3(0, 0, 0.8), Palette.CYAN, 0.0, 5.0)
	_glow.visible = false


func _process(delta: float) -> void:
	if not is_on:
		return
	_switching = move_toward(_switching, 0.0, delta * 3.0)
	(_picture.material as ShaderMaterial).set_shader_parameter("switching", _switching)
	_ticker.position.x -= delta * 40.0
	if _ticker.position.x < -_ticker.size.x * 0.5:
		_ticker.position.x = 0.0
	_tag_time -= delta
	_channel_tag.visible = _tag_time > 0.0
	_glow.light_energy = 1.0 + 0.4 * sin(Time.get_ticks_msec() * 0.012) * (1.0 if channel == 2 else 0.2)


func turn_on() -> void:
	is_on = true
	_screen.material_override = _on_material
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_glow.visible = true
	set_channel(channel)


func turn_off() -> void:
	is_on = false
	_screen.material_override = _off_material
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_glow.visible = false
	_audio.stop()


func next_channel(step: int) -> void:
	set_channel(posmod(channel + step, CHANNELS.size()))


func set_channel(index: int) -> void:
	channel = index
	(_picture.material as ShaderMaterial).set_shader_parameter("channel", index)
	for i in _labels.size():
		_labels[i].visible = i == index
	_switching = 1.0
	_channel_tag.text = "CH %02d" % (index + 1)
	_tag_time = 1.5
	_glow.light_color = [Palette.CYAN, Palette.AMBER, Palette.PINK, Palette.COOL_WHITE][index]
	_audio.stream = SOUNDS[index]
	_audio.play()
	channel_changed.emit(index)


func _build_picture() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(256, 144)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_picture = ColorRect.new()
	_picture.size = Vector2(256, 144)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/tv_channels.gdshader")
	_picture.material = material
	_viewport.add_child(_picture)
	# Channel 1: news title and a ticker scrolling along the white strip.
	var news := Control.new()
	news.size = Vector2(256, 144)
	_viewport.add_child(news)
	news.add_child(_text("NEO-7 NEWS", Vector2(8, 6), 13, Color.WHITE))
	news.add_child(_text("LIVE  //  BLOCK 7", Vector2(8, 111), 9, Color.WHITE))
	_ticker = _text(TICKER + TICKER, Vector2(0, 124), 9, Color(0.1, 0.05, 0.15))
	news.add_child(_ticker)
	# Channel 2: the advert.
	var advert := Control.new()
	advert.size = Vector2(256, 144)
	_viewport.add_child(advert)
	advert.add_child(_text("VANTALUME", Vector2(72, 98), 20, Color.WHITE))
	advert.add_child(_text("LIGHT YOU CAN OWN.", Vector2(78, 124), 9, Color(1.0, 0.9, 0.6)))
	# Channel 3: the show's title card.
	var anime := Control.new()
	anime.size = Vector2(256, 144)
	_viewport.add_child(anime)
	anime.add_child(_text("MECHA-KOI STRIKE!!", Vector2(10, 8), 14, Color(1.0, 0.95, 0.3)))
	anime.add_child(_text("EP. 212  \"THE NEON TIDE\"", Vector2(10, 124), 9, Color.WHITE))
	var nothing := Control.new()
	_viewport.add_child(nothing)
	_labels = [news, advert, anime, nothing]
	_channel_tag = _text("CH 01", Vector2(206, 6), 11, Palette.LIME)
	_viewport.add_child(_channel_tag)


func _text(content: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.position = at
	label.add_theme_font_override("font", UiStyle.font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	return label
