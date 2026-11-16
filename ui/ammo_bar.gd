class_name AmmoBar
extends Control
## Row of bullet ticks showing the magazine; while reloading it fills up as a progress bar.

@export var full_color := Color(0.1, 0.88, 1.0)
@export var empty_color := Color(0.1, 0.88, 1.0, 0.15)
@export var low_color := Color(1.0, 0.2, 0.3)

var capacity := 30:
	set(value):
		capacity = value
		queue_redraw()
var count := 30:
	set(value):
		count = value
		queue_redraw()
## -1 when not reloading, otherwise 0..1.
var reload_progress := -1.0:
	set(value):
		reload_progress = value
		queue_redraw()


func _draw() -> void:
	if capacity <= 0:
		return
	var tick_width := size.x / capacity
	var low := count <= capacity / 5.0
	for i in capacity:
		var filled := i < count
		var tick_color := (low_color if low else full_color) if filled else empty_color
		if reload_progress >= 0.0:
			tick_color = full_color if float(i) / capacity < reload_progress else empty_color
		draw_rect(Rect2(Vector2(i * tick_width + 1.0, 0.0), Vector2(tick_width - 2.0, size.y)), tick_color)
