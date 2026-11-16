extends Node
## Checks that the player can't walk out of the playable area: flood-fills the ground floor from
## the spawn point on a 0.5 m grid (a player-sized capsule must fit in every cell) and fails for
## every patch it reaches that is neither street nor a walk-in interior (holes in buildings,
## gaps between lots, open barricades).
## Run: godot --headless --path . res://tests/test_bounds.tscn

const STEP := 0.5
const EXTENT := 84.0
## Streets and sidewalks reach this far from the street centre lines.
const STREET_HALF := CityBuilder.SIDEWALK_OUTER + 0.3
## Location names that aren't interiors.
const OUTDOORS := ["Kabuki Ave", "Crow St", "Block 7", "Rust Jackal corner"]

var _failures := 0


func _ready() -> void:
	get_tree().set_meta("screenshot_mode", true)
	add_child(load("res://scenes/main.tscn").instantiate())
	for i in 30:
		await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as Player
	player.set_physics_process(false)
	var space := player.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.2
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]

	var cells := int(EXTENT / STEP)
	var start := Vector2i(roundi(player.global_position.x / STEP), roundi(player.global_position.z / STEP))
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var leaks: Array[Vector2i] = []
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		var point := Vector3(cell.x * STEP, 1.0, cell.y * STEP)
		if not _allowed(point):
			leaks.append(cell)
		if absi(cell.x) >= cells or absi(cell.y) >= cells:
			continue
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + offset
			if seen.has(next):
				continue
			seen[next] = true
			query.transform = Transform3D(Basis.IDENTITY, Vector3(next.x * STEP, 1.0, next.y * STEP))
			if space.intersect_shape(query, 1).is_empty():
				queue.append(next)
	_check(seen.size() > 15000, "the streets are walkable (%d cells reached)" % seen.size())
	for patch in _patches(leaks):
		_check(false, "the player can reach %s (x %.1f..%.1f, z %.1f..%.1f, %d cells)" % [patch[0], patch[1].position.x, patch[1].end.x, patch[1].position.y, patch[1].end.y, patch[2]])
	_check(leaks.is_empty(), "the player can't leave the streets and interiors")
	print("FAILURES: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## On a street inside the barricades, or inside a registered interior.
func _allowed(point: Vector3) -> bool:
	if absf(point.x) > CityBuilder.PLAY_LIMIT or absf(point.z) > CityBuilder.PLAY_LIMIT:
		return false
	if absf(point.x) <= STREET_HALF or absf(point.z) <= STREET_HALF:
		return true
	return not GameState.location_name(point) in OUTDOORS


## Groups leaked cells into connected patches: [location name, XZ bounds, cell count].
func _patches(leaks: Array[Vector2i]) -> Array:
	var left := {}
	for cell in leaks:
		left[cell] = true
	var result := []
	for cell: Vector2i in leaks:
		if not left.has(cell):
			continue
		left.erase(cell)
		var stack: Array[Vector2i] = [cell]
		var bounds := Rect2(Vector2(cell) * STEP, Vector2.ZERO)
		var count := 0
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			count += 1
			bounds = bounds.expand(Vector2(c) * STEP)
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if left.has(c + offset):
					left.erase(c + offset)
					stack.append(c + offset)
		var center := bounds.get_center()
		result.append([GameState.location_name(Vector3(center.x, 1.0, center.y)), bounds, count])
	return result


func _check(ok: bool, what: String) -> void:
	if ok:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
