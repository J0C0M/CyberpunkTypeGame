class_name WaypointMarker
extends Control
## Diamond marker with a label and distance over the current GameState waypoint. It follows the
## place on screen and sticks to the screen edge when the place is off-screen or behind you.
## Arriving within ARRIVE_DISTANCE clears the waypoint.

const ARRIVE_DISTANCE := 4.0
const EDGE := 40.0

var camera: Camera3D
## Converts SubViewport pixels into HUD coordinates (the game renders at a lower resolution).
var viewport_scale := Vector2.ONE

var _screen_position := Vector2.ZERO
var _distance := 0.0
var _label := ""
var _pulse := 0.0


func _process(delta: float) -> void:
	_pulse += delta
	visible = not GameState.waypoint.is_empty() and camera != null and GameState.is_free_roaming()
	if not visible:
		return
	var target: Vector3 = GameState.waypoint["position"] + Vector3.UP * 2.2
	_distance = camera.global_position.distance_to(target)
	if _distance < ARRIVE_DISTANCE + 2.2:
		get_tree().call_group("hud", "show_message", "Arrived: " + GameState.waypoint["label"])
		GameState.clear_waypoint()
		return
	var point := camera.unproject_position(target) * viewport_scale
	if camera.is_position_behind(target):
		point = Vector2(size.x - point.x, size.y - EDGE)
	_screen_position = point.clamp(Vector2(EDGE, EDGE), size - Vector2(EDGE, EDGE))
	_label = "%s  %d m" % [String(GameState.waypoint["label"]).to_upper(), int(_distance)]
	queue_redraw()


func _draw() -> void:
	var color := Palette.AMBER
	var r := 9.0 + sin(_pulse * 4.0) * 1.5
	var p := _screen_position
	var diamond := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)])
	draw_polyline(diamond, Color(0, 0, 0, 0.6), 5.0)
	draw_polyline(diamond, color, 2.5)
	draw_circle(p, 2.5, color)
	var font := UiStyle.font()
	var text_size := font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var at := p + Vector2(-text_size.x * 0.5, r + 18.0)
	at.x = clampf(at.x, 6.0, size.x - text_size.x - 6.0)
	draw_string_outline(font, at, _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, _label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color.lerp(Color.WHITE, 0.3))
