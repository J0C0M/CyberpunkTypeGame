@tool
class_name FlightPath
extends Path3D
## Smooth closed loop for the ambient dragons, generated from a few numbers so it is easy to
## tweak: an ellipse (`lobes` adds petals so it weaves in and out between the towers), or a
## smooth loop through `waypoints` on the ground plane. Wherever the buildings listed in
## `obstacle_sources` are too tall, the loop climbs over them.
## Turn off `auto_generate` to keep a curve drawn by hand in the editor instead.

@export var auto_generate := true
@export var center := Vector2.ZERO
@export var radius := Vector2(160.0, 130.0)
## When set, the loop runs through these XZ points instead of the ellipse.
@export var waypoints := PackedVector2Array()
@export var lobes := 0
@export_range(0.0, 0.8) var lobe_depth := 0.3
@export var altitude := 120.0
@export var altitude_variation := 25.0
## Minimum distance kept above roofs and masts.
@export var clearance := 35.0
## Half-size of the area checked for buildings around each sample. Keep it small for paths
## that should dive between the buildings along a street.
@export var obstacle_radius := 30.0
@export var samples := 56
@export var phase := 0.0
## Nodes with a `max_height_in(Rect2) -> float` method (CityBuilder, Skyline).
@export var obstacle_sources: Array[NodePath] = []
@export_tool_button("Regenerate path") var regenerate_action := generate


func _ready() -> void:
	if auto_generate:
		generate()


func generate() -> void:
	var heights := PackedFloat32Array()
	var floors := PackedFloat32Array()
	var flat := PackedVector2Array()
	for i in samples:
		var angle := TAU * i / samples
		var p := _waypoint_point(float(i) / samples) if waypoints.size() >= 3 else _ellipse_point(angle)
		flat.append(p)
		heights.append(altitude + sin(angle * 2.0 + phase) * altitude_variation)
		floors.append(_obstacle_height(p) + clearance)
	# Spread each obstacle floor to its neighbours so the climb starts early, then smooth.
	for i in samples:
		var floor_height := 0.0
		for k in range(-2, 3):
			floor_height = maxf(floor_height, floors[(i + k + samples) % samples])
		heights[i] = maxf(heights[i], floor_height)
	for _pass in 2:
		var smoothed := heights.duplicate()
		for i in samples:
			var avg := (heights[(i - 1 + samples) % samples] + heights[i] * 2.0 + heights[(i + 1) % samples]) * 0.25
			smoothed[i] = maxf(avg, floors[i])
		heights = smoothed

	var points := PackedVector3Array()
	for i in samples:
		points.append(Vector3(flat[i].x, heights[i], flat[i].y))
	var loop := Curve3D.new()
	loop.bake_interval = 2.0
	for i in samples + 1:
		var p := points[i % samples]
		# Catmull-Rom tangents expressed as Bezier handles.
		var tangent := (points[(i + 1) % samples] - points[(i - 1 + samples) % samples]) / 6.0
		loop.add_point(p, -tangent, tangent)
	curve = loop


func _ellipse_point(angle: float) -> Vector2:
	var scale := 1.0 + (lobe_depth * sin(angle * lobes + phase) if lobes > 0 else 0.0)
	return center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * scale


## Point on the closed Catmull-Rom spline through `waypoints`, t in [0, 1).
func _waypoint_point(t: float) -> Vector2:
	var count := waypoints.size()
	var u := t * count
	var k := int(u)
	return center + waypoints[k % count].cubic_interpolate(
			waypoints[(k + 1) % count], waypoints[(k - 1 + count) % count], waypoints[(k + 2) % count], u - k)


func _obstacle_height(p: Vector2) -> float:
	var area := Rect2(p - Vector2.ONE * obstacle_radius, Vector2.ONE * obstacle_radius * 2.0)
	var top := 0.0
	for path in obstacle_sources:
		var source := get_node_or_null(path)
		if source and source.has_method("max_height_in"):
			top = maxf(top, source.max_height_in(area))
	return top
