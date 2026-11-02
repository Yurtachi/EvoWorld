extends RefCounted
## Deterministic A* planner operating strictly on the creature's own local map.
## Hypotheses: unknown space is treated optimistically as free; reinforced routes
## receive cost discounts; past collisions (bloqueios) receive cost penalties.
## NEVER reads world state directly.
const Data = preload("res://scripts/core/sim_data.gd")

const SQRT2 := 1.41421356

static func plan_path(start_pos: Vector2, goal_pos: Vector2, spatial: Dictionary, world_size: Vector2) -> Array[Vector2]:
	var cell_size: float = float(spatial.get("cell_size", 40.0))
	if cell_size <= 0.0: cell_size = 40.0
	var max_cols := maxi(1, ceili(world_size.x / cell_size))
	var max_rows := maxi(1, ceili(world_size.y / cell_size))
	var start_cell := pos_to_cell(start_pos, cell_size)
	var goal_cell := pos_to_cell(goal_pos, cell_size)
	start_cell.x = clampi(start_cell.x, 0, max_cols - 1)
	start_cell.y = clampi(start_cell.y, 0, max_rows - 1)
	goal_cell.x = clampi(goal_cell.x, 0, max_cols - 1)
	goal_cell.y = clampi(goal_cell.y, 0, max_rows - 1)
	
	if start_cell == goal_cell:
		var result: Array[Vector2] = [goal_pos]
		return result
	
	var cells := path_cells(start_cell, goal_cell, spatial, world_size)
	var waypoints: Array[Vector2] = []
	for i in range(cells.size()):
		var c := cells[i]
		if i == cells.size() - 1:
			waypoints.append(goal_pos)
		else:
			waypoints.append(cell_center(c, cell_size))
	return waypoints

static func path_cells(start_cell: Vector2i, goal_cell: Vector2i, spatial: Dictionary, world_size: Vector2) -> Array[Vector2i]:
	var cell_size: float = float(spatial.get("cell_size", 40.0))
	if cell_size <= 0.0: cell_size = 40.0
	var max_cols := maxi(1, ceili(world_size.x / cell_size))
	var max_rows := maxi(1, ceili(world_size.y / cell_size))
	
	# Pre-compute route discounts (prefer working routes)
	var route_discounts: Dictionary = {}
	for route in spatial.get("rotas", []):
		if not route is Dictionary: continue
		var sucessos: int = int(route.get("sucessos", 0))
		if sucessos <= 0: continue
		var peso: float = float(route.get("peso", 1.0))
		var discount: float = clampf(1.0 - 0.25 * minf(3.0, peso), 0.2, 0.8)
		for cell_arr in route.get("celulas", []):
			if cell_arr is Array and cell_arr.size() >= 2:
				var rc := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
				route_discounts[rc] = minf(float(route_discounts.get(rc, 1.0)), discount)
	
	# Pre-compute block penalties
	var block_penalties: Dictionary = {}
	for b in spatial.get("bloqueios", []):
		if not b is Dictionary: continue
		var pos = b.get("pos", [])
		if pos is Array and pos.size() >= 2:
			var bc := Vector2i(int(pos[0]), int(pos[1]))
			var tentativas: int = int(b.get("tentativas", 1))
			block_penalties[bc] = float(tentativas) * 4.0
	
	var mapa: Dictionary = spatial.get("mapa", {})
	
	# A* Data structures
	var open_set: Array[Dictionary] = []
	var g_score: Dictionary = {start_cell: 0.0}
	var f_score: Dictionary = {start_cell: heuristic(start_cell, goal_cell)}
	var came_from: Dictionary = {}
	var closed_set: Dictionary = {}
	
	open_set.append({
		"cell": start_cell,
		"f": float(f_score[start_cell]),
		"h": float(f_score[start_cell]),
		"tie": start_cell.y * 10000 + start_cell.x
	})
	
	var best_partial_cell: Vector2i = start_cell
	var best_partial_h: float = float(f_score[start_cell])
	
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	
	while not open_set.is_empty():
		# Pop lowest f
		var current_item: Dictionary = open_set.pop_front()
		var current: Vector2i = current_item.cell
		
		if current == goal_cell:
			return _reconstruct_path(came_from, current)
		
		closed_set[current] = true
		
		for dir in directions:
			var neighbor := current + dir
			if neighbor.x < 0 or neighbor.x >= max_cols or neighbor.y < 0 or neighbor.y >= max_rows:
				continue
			if closed_set.has(neighbor):
				continue
			
			# Check if neighbor cell is blocked
			var key := "%d:%d" % [neighbor.x, neighbor.y]
			var cell_info: Dictionary = mapa.get(key, {})
			var state: String = str(cell_info.get("estado", "desconhecida"))
			if state == "bloqueada":
				continue
			
			# Corner cutting prevention for diagonal moves
			if dir.x != 0 and dir.y != 0:
				var adj1 := Vector2i(current.x + dir.x, current.y)
				var adj2 := Vector2i(current.x, current.y + dir.y)
				var k1 := "%d:%d" % [adj1.x, adj1.y]
				var k2 := "%d:%d" % [adj2.x, adj2.y]
				if mapa.get(k1, {}).get("estado", "") == "bloqueada" or mapa.get(k2, {}).get("estado", "") == "bloqueada":
					continue
			
			var base_step := SQRT2 if (dir.x != 0 and dir.y != 0) else 1.0
			var route_mult: float = float(route_discounts.get(neighbor, 1.0))
			var penalty: float = float(block_penalties.get(neighbor, 0.0))
			var tentative_g: float = float(g_score[current]) + base_step * route_mult + penalty
			
			if not g_score.has(neighbor) or tentative_g < float(g_score[neighbor]):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var h := heuristic(neighbor, goal_cell)
				var f := tentative_g + h
				f_score[neighbor] = f
				
				if h < best_partial_h:
					best_partial_h = h
					best_partial_cell = neighbor
				
				# Insert deterministically sorted
				var item := {
					"cell": neighbor,
					"f": f,
					"h": h,
					"tie": neighbor.y * 10000 + neighbor.x
				}
				_insert_sorted(open_set, item)
	
	# If no complete path to goal found, fall back to best cell toward goal
	if best_partial_cell != start_cell:
		return _reconstruct_path(came_from, best_partial_cell)
	
	var fallback: Array[Vector2i] = [start_cell]
	return fallback

static func _insert_sorted(list: Array[Dictionary], item: Dictionary) -> void:
	# Binary search insert to keep list sorted by (f, h, tie)
	var low := 0
	var high := list.size()
	while low < high:
		var mid := (low + high) / 2
		var other := list[mid]
		var less := false
		if not is_equal_approx(item.f, other.f):
			less = item.f < other.f
		elif not is_equal_approx(item.h, other.h):
			less = item.h < other.h
		else:
			less = item.tie < other.tie
		if less:
			high = mid
		else:
			low = mid + 1
	list.insert(low, item)

static func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path

static func heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return float(maxi(dx, dy)) + (SQRT2 - 1.0) * float(mini(dx, dy))

static func pos_to_cell(pos: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori(pos.x / cell_size), floori(pos.y / cell_size))

static func cell_center(cell: Vector2i, cell_size: float) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * cell_size, (float(cell.y) + 0.5) * cell_size)
