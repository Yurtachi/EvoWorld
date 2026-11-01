extends RefCounted
## Uniform grid over centers. Queries return stable insertion IDs; geometry remains
## the caller's responsibility. Derived data only: never serialized or randomized.

const CELL_SIZE := 128.0
var cells: Dictionary = {}
var locations: Dictionary = {}

func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.y / CELL_SIZE))

func insert(id: int, pos: Vector2) -> void:
	var cell := _cell(pos)
	if locations.has(id):
		if locations[id] == cell:
			return
		remove(id)
	if not cells.has(cell):
		cells[cell] = {}
	cells[cell][id] = true
	locations[id] = cell

func remove(id: int) -> void:
	if not locations.has(id):
		return
	var cell: Vector2i = locations[id]
	cells[cell].erase(id)
	if cells[cell].is_empty():
		cells.erase(cell)
	locations.erase(id)

func query(low: Vector2, high: Vector2) -> Array:
	var result: Array = []
	var first := _cell(low)
	var last := _cell(high)
	# Large obstacle radii and sparse worlds must not enumerate millions of empty
	# cells. In that case checking occupied cells is bounded by entity count.
	if (last.x - first.x + 1) * (last.y - first.y + 1) > cells.size():
		for cell in cells:
			if cell.x >= first.x and cell.x <= last.x and cell.y >= first.y and cell.y <= last.y:
				result.append_array(cells[cell].keys())
		result.sort()
		return result
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if cells.has(cell):
				result.append_array(cells[cell].keys())
	result.sort()
	return result
