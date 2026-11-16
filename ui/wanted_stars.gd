class_name WantedStars
extends Control
## "WANTED" and five stars at the top of the screen; lit stars flash red and blue while the
## police are after the player. Hidden at zero stars.

var stars := 0:
	set(value):
		stars = value
		visible = value > 0
		queue_redraw()

var _time := 0.0


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var font := UiStyle.font()
	var flash := fmod(_time * 2.5, 1.0) < 0.5
	var lit := Palette.RED if flash else Color(0.25, 0.45, 1.0)
	var title := "WANTED"
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var start := (size.x - (width + 12.0 + 5 * 26.0)) * 0.5
	draw_string_outline(font, Vector2(start, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(start, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.85))
	for i in 5:
		var center := Vector2(start + width + 24.0 + i * 26.0, 16.0)
		var points := PackedVector2Array()
		for p in 10:
			var radius := 10.0 if p % 2 == 0 else 4.2
			var angle := -PI * 0.5 + p * PI / 5.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		if i < stars:
			draw_colored_polygon(points, lit)
		points.append(points[0])
		draw_polyline(points, Color(1, 1, 1, 0.7) if i < stars else Color(1, 1, 1, 0.25), 1.5)
