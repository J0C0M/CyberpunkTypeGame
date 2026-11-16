class_name DamageIndicator
extends Control
## Red arcs around the crosshair pointing at whoever just hurt the player (straight up = in front).

const LIFETIME := 1.4
const RADIUS := 96.0

## [angle in radians (0 = ahead, positive = right), seconds left]
var _hits: Array = []


func add_hit(angle: float) -> void:
	_hits.append([angle, LIFETIME])
	if _hits.size() > 6:
		_hits.pop_front()
	queue_redraw()


func clear() -> void:
	_hits.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _hits.is_empty():
		return
	for hit in _hits:
		hit[1] -= delta
	_hits = _hits.filter(func(hit: Array) -> bool: return hit[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	for hit in _hits:
		var alpha: float = clampf(hit[1] / LIFETIME, 0.0, 1.0)
		# Screen angles run clockwise from +X; "ahead" is up.
		var mid: float = hit[0] - PI * 0.5
		draw_arc(center, RADIUS, mid - 0.35, mid + 0.35, 16, Color(0.0, 0.0, 0.0, 0.5 * alpha), 9.0)
		draw_arc(center, RADIUS, mid - 0.32, mid + 0.32, 16, Color(1.0, 0.12, 0.2, 0.9 * alpha), 5.0)
