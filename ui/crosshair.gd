class_name Crosshair
extends Control
## Four short lines around a dot; the gap opens up with the weapon's current spread.

@export var color := Color(1, 1, 1, 0.9)
@export var outline := Color(0, 0, 0, 0.6)
@export var line_length := 7.0
@export var base_gap := 4.0
## Extra gap in pixels per degree of spread.
@export var gap_per_degree := 7.0

var spread := 0.0:
	set(value):
		if not is_equal_approx(value, spread):
			spread = value
			queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var gap := base_gap + spread * gap_per_degree
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var from := center + direction * gap
		var to := center + direction * (gap + line_length)
		draw_line(from, to, outline, 4.0)
		draw_line(from, to, color, 2.0)
	draw_rect(Rect2(center - Vector2(1.5, 1.5), Vector2(3, 3)), outline)
	draw_rect(Rect2(center - Vector2(1, 1), Vector2(2, 2)), color)
