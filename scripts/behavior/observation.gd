extends RefCounted
## Discretizes the limited sensor dictionary from SimWorld.sense() into a small state index.
## Only perceived food/obstacles are used (range, field of view and occlusion already applied
## by the world), plus the creature's own energy and the visible world boundary ahead.

# Food bucket: 0 none visible, 1 within reach (direction irrelevant),
# 2..4 near (left/ahead/right), 5..7 far (left/ahead/right).
const FOOD_BUCKETS := 8
const ENERGY_BUCKETS := 3
const OBSTACLE_BUCKETS := 2
const STATE_COUNT := FOOD_BUCKETS * ENERGY_BUCKETS * OBSTACLE_BUCKETS
const AHEAD_ANGLE := 0.25
const NEAR_DISTANCE := 60.0
const LOW_ENERGY := 0.35
const HIGH_ENERGY := 0.7
const FOOD_NAMES := ["none", "reach", "near_left", "near_ahead", "near_right", "far_left", "far_ahead", "far_right"]
const ENERGY_NAMES := ["low", "mid", "high"]
const TICK_DT := 0.1

static func reach(creature) -> float:
	return creature.genome.size + 5.0

static func state_index(food_bucket: int, energy_bucket: int, obstacle_ahead: bool) -> int:
	return (food_bucket * ENERGY_BUCKETS + energy_bucket) * OBSTACLE_BUCKETS + (1 if obstacle_ahead else 0)

static func describe_state(state: int) -> String:
	var obstacle := state % OBSTACLE_BUCKETS
	var energy := (state / OBSTACLE_BUCKETS) % ENERGY_BUCKETS
	var food := state / (OBSTACLE_BUCKETS * ENERGY_BUCKETS)
	return "food=%s energy=%s obstacle_ahead=%s" % [FOOD_NAMES[food], ENERGY_NAMES[energy], "yes" if obstacle == 1 else "no"]

static func features(creature, sensors: Dictionary, world_size: Vector2) -> Dictionary:
	var closest_id := -1
	var closest_distance := INF
	var closest_pos := Vector2.ZERO
	for food in sensors.get("foods", []):
		var distance: float = creature.pos.distance_to(food["pos"])
		if distance < closest_distance:
			closest_distance = distance
			closest_id = int(food["id"])
			closest_pos = food["pos"]
	var food_bucket := 0
	if closest_id != -1:
		if closest_distance <= reach(creature):
			food_bucket = 1
		else:
			var relative := wrapf((closest_pos - creature.pos).angle() - creature.heading, -PI, PI)
			var direction := 0 if relative < -AHEAD_ANGLE else (2 if relative > AHEAD_ANGLE else 1)
			food_bucket = (2 if closest_distance <= NEAR_DISTANCE else 5) + direction
	var ratio: float = creature.energy / creature.max_energy
	var energy_bucket := 0 if ratio < LOW_ENERGY else (1 if ratio < HIGH_ENERGY else 2)
	var obstacle_ahead := _obstacle_ahead(creature, sensors.get("obstacles", []), world_size)
	return {
		"state": state_index(food_bucket, energy_bucket, obstacle_ahead),
		"food_bucket": food_bucket, "energy_bucket": energy_bucket, "obstacle_ahead": obstacle_ahead,
		"food_id": closest_id, "food_distance": closest_distance
	}

static func _obstacle_ahead(creature, visible_obstacles: Array, world_size: Vector2) -> bool:
	var size: float = creature.genome.size
	var look: float = creature.genome.speed * TICK_DT + size + 8.0
	var ahead: Vector2 = creature.pos + Vector2.from_angle(creature.heading) * look
	if ahead.x < size or ahead.y < size or ahead.x > world_size.x - size or ahead.y > world_size.y - size:
		return true
	for obstacle in visible_obstacles:
		if _segment_hits(creature.pos, ahead, obstacle["pos"], float(obstacle["radius"]) + size):
			return true
	return false

static func _segment_hits(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> bool:
	var delta := finish - start
	var fraction := 0.0 if delta.is_zero_approx() else clampf((center - start).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return (start + delta * fraction).distance_squared_to(center) < radius * radius
