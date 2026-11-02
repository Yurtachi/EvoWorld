extends RefCounted
## Receives body, sensors and learned state; never truth or a world handle.
const Memory = preload("res://scripts/spatial/spatial_memory.gd")
const Data = preload("res://scripts/core/sim_data.gd")

static func survey_mask(creature, s: Dictionary, sensors: Dictionary, target: Vector2) -> int:
	# Seventeen samples of the remembered area, seen through the same range/FOV
	# and currently perceived occluders; no world handle or resource truth.
	var mask: int = s.scan_mask
	var sensed: Dictionary = sensors.get("spatial_survey", {})
	if sensed.get("id", "") == s.objetivo_atual and sensed.has("mask"):
		return mask | int(sensed.mask)
	for sample in 17:
		var point := target
		if sample > 0:
			var radius := float(s.cell_size) * (0.5 if sample <= 8 else 1.0)
			point += Vector2.from_angle(TAU * ((sample - 1) % 8) / 8.0) * radius
		var delta: Vector2 = point - creature.pos
		if delta.length() > creature.genome.vision_range: continue
		if delta.length() > 0.001 and absf(angle_difference(creature.heading, delta.angle())) > creature.genome.vision_fov / 2.0: continue
		var clear := true
		for obstacle in sensors.get("obstacles", []):
			var closest := Geometry2D.get_closest_point_to_segment(obstacle.pos, creature.pos, point)
			if closest.distance_to(obstacle.pos) < float(obstacle.radius):
				clear = false
				break
		if clear: mask |= 1 << sample
	return mask

static func inspected_fraction(mask: int) -> float:
	var count := 0
	for sample in 17:
		if mask & (1 << sample): count += 1
	return count / 17.0

static func heading(creature, s: Dictionary, target: Vector2, tick: int) -> float:
	# Preserve physical collision avoidance long enough to pass an obstacle.
	# Re-aiming at the same target every tick would undo the world's safe turn.
	if creature.mind.blocked_ticks >= 2 and int(s.detour_until) <= tick:
		s.detour_until = tick + 30
	if tick < int(s.detour_until): return creature.heading
	return (target - creature.pos).angle()

static func sweep(s: Dictionary, pos: Vector2, vision: float, size: Vector2) -> Vector2:
	var spacing := vision * 0.95
	var cols := maxi(1, ceili((size.x - 32.0) / spacing))
	var rows := maxi(1, ceili((size.y - 32.0) / spacing))
	var count := cols * rows
	if int(s.busca_indice) < 0:
		var near := INF
		for i in count:
			var candidate := waypoint(i, cols, rows, size)
			if pos.distance_squared_to(candidate) < near:
				near = pos.distance_squared_to(candidate)
				s.busca_indice = i
	var point := waypoint(int(s.busca_indice) % count, cols, rows, size)
	if pos.distance_to(point) < 10.0:
		s.busca_indice = (int(s.busca_indice) + 1) % count
		point = waypoint(int(s.busca_indice), cols, rows, size)
	return point

static func waypoint(index: int, cols: int, rows: int, size: Vector2) -> Vector2:
	var y := index / cols
	var x := index % cols if y % 2 == 0 else cols - 1 - index % cols
	return Vector2(16.0 + (x + 0.5) * (size.x - 32.0) / cols, 16.0 + (y + 0.5) * (size.y - 32.0) / rows)

static func choose(creature, s: Dictionary, sensors: Dictionary, resource: String, tick: int, size: Vector2, retrieve: bool = true) -> Dictionary:
	var row := Memory.best(s, resource, creature.pos, tick) if retrieve else {}
	if not row.is_empty():
		if s.objetivo_atual != row.id:
			s.objetivo_atual = row.id
			s.arrival_tick = -1
			if Memory.revised(s): s.scan_mask = 0
			s.buscas = mini(2147483647, int(s.buscas) + 1)
		var pos := Data.unpack_vector(row.pos)
		if creature.pos.distance_to(pos) <= creature.genome.size + 5.0:
			if int(s.arrival_tick) < 0:
				s.arrival_tick = tick
				if Memory.revised(s): s.scan_mask = 0
			if Memory.revised(s): s.scan_mask = survey_mask(creature, s, sensors, pos)
			# Turn through a full circle before interpreting absence as evidence.
			if tick - int(s.arrival_tick) < 16:
				s.motivo = "spatial.inspect"
				return {"scan": true, "heading": creature.heading + TAU / 16.0}
			var visible := false
			for item in sensors.get("foods" if resource == "comida" else "waters", []):
				if pos.distance_to(item.pos) <= float(s.cell_size): visible = true
			if not visible:
				var coverage := inspected_fraction(int(s.scan_mask)) if Memory.revised(s) else 1.0
				Memory.evidence(s, resource, pos, tick, false, 0.0, "observado", coverage)
				s.explore_until = tick + (30 if Memory.revised(s) else 90)
				s.motivo = "spatial.failure"
				s.objetivo_atual = ""
				s.arrival_tick = -1
				return {"scan": true, "heading": creature.heading}
		else:
			s.motivo = "spatial.expected"
			return {"scan": false, "target": pos}
	s.objetivo_atual = ""
	s.arrival_tick = -1
	s.motivo = "spatial.explore"
	if Memory.revised(s) and s.enabled and retrieve:
		# Exploration should leave a recently inspected empty neighborhood,
		# rather than immediately wandering back through the same empty area.
		for avoided in s.lugares:
			if avoided.recurso != resource or int(avoided.retry_tick) <= tick: continue
			if int(avoided.consecutivas) == 0: continue
			var away: Vector2 = creature.pos - Data.unpack_vector(avoided.pos)
			if away.length() < creature.genome.vision_range + float(s.cell_size):
				if away.length() < 0.01: away = Vector2.from_angle(creature.heading)
				return {"scan": false, "target": creature.pos + away.normalized() * creature.genome.vision_range}
	if not s.systematic: return {"scan": false, "wander": true}
	return {"scan": false, "target": sweep(s, creature.pos, creature.genome.vision_range, size)}
