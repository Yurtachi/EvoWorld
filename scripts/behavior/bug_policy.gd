extends RefCounted
## Competent classic wall-following ("Bug") heuristic baseline without memory.
## Uses only immediate sensory perception and goal target; never retains maps
## or learned routes across trials.
const Data = preload("res://scripts/core/sim_data.gd")

static func empty_state() -> Dictionary:
	return {
		"mode": "direct", # "direct" or "wall"
		"hit_pos": [0.0, 0.0],
		"min_dist": INF,
		"wall_dir": 1.0, # 1.0 = right-hand rule, -1.0 = left-hand
		"follow_ticks": 0
	}

static func heading(creature, target: Vector2, sensors: Dictionary, state: Dictionary) -> float:
	var obstacles: Array = sensors.get("obstacles", [])
	var direct_heading: float = (target - creature.pos).angle()
	var dist_to_target: float = creature.pos.distance_to(target)
	var speed_dt: float = float(creature.genome.speed) * 0.1 # 1 tick distance
	var margin: float = float(creature.genome.size) + 8.0
	
	var mode: String = str(state.get("mode", "direct"))
	
	if mode == "direct":
		# Check if obstacle directly obstructs movement
		var blocked: bool = false
		var hit_obs: Dictionary = {}
		for obs in obstacles:
			var center: Vector2 = obs.pos
			var radius: float = float(obs.radius)
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, creature.pos, creature.pos + Vector2.from_angle(direct_heading) * (speed_dt + margin))
			if closest.distance_to(center) < radius + creature.genome.size:
				blocked = true
				hit_obs = obs
				break
		
		if blocked:
			state.mode = "wall"
			state.hit_pos = [creature.pos.x, creature.pos.y]
			state.min_dist = dist_to_target
			state.follow_ticks = 0
			# Choose wall following direction toward goal side
			var obs_angle: float = (hit_obs.pos - creature.pos).angle()
			var diff: float = wrapf(direct_heading - obs_angle, -PI, PI)
			state.wall_dir = 1.0 if diff >= 0.0 else -1.0
			return obs_angle + PI * 0.5 * float(state.wall_dir)
		
		return direct_heading
	else: # "wall" following mode
		state.follow_ticks = int(state.get("follow_ticks", 0)) + 1
		
		# Test departure condition: is line-of-sight to target clear of all perceived obstacles?
		var los_clear: bool = true
		for obs in obstacles:
			var center: Vector2 = obs.pos
			var radius: float = float(obs.radius)
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, creature.pos, target)
			if closest.distance_to(center) < radius + creature.genome.size + 2.0:
				los_clear = false
				break
		
		var hit_pos := Vector2(float(state.hit_pos[0]), float(state.hit_pos[1]))
		var reached_progress: bool = dist_to_target < float(state.min_dist) - 4.0 or creature.pos.distance_to(hit_pos) > 40.0
		
		if los_clear and reached_progress and int(state.follow_ticks) > 5:
			state.mode = "direct"
			state.follow_ticks = 0
			return direct_heading
		
		# Trace along closest obstacle
		var nearest_obs: Dictionary = {}
		var nearest_dist: float = INF
		for obs in obstacles:
			var d: float = creature.pos.distance_to(obs.pos)
			if d < nearest_dist:
				nearest_dist = d
				nearest_obs = obs
		
		if not nearest_obs.is_empty():
			var center: Vector2 = nearest_obs.pos
			var obs_angle: float = (center - creature.pos).angle()
			var tangent: float = obs_angle + PI * 0.5 * float(state.wall_dir)
			
			var desired_dist: float = float(nearest_obs.radius) + creature.genome.size + 4.0
			var dist_diff: float = nearest_dist - desired_dist
			# Steer slightly toward/away from wall to maintain boundary distance
			var steer_correction: float = clampf(dist_diff * 0.05, -0.4, 0.4) * float(state.wall_dir)
			return tangent + steer_correction
		
		# If no obstacle near, try heading to goal
		state.mode = "direct"
		return direct_heading
