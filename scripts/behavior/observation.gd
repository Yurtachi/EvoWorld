extends RefCounted
## Discretizes the limited sensor dictionary from SimWorld.sense() into a small state index.
## Only perceived food/obstacles are used (range, field of view and occlusion already applied
## by the world), plus the creature's own energy and the visible world boundary ahead.

# Food bucket: 0 none visible, 1 within reach (direction irrelevant),
# 2..4 near (left/ahead/right), 5..7 far (left/ahead/right).
const FoodCatalog = preload("res://scripts/environment/food_catalog.gd")
const Water = preload("res://scripts/environment/water_rules.gd")
const FOOD_BUCKETS := 8
const ENERGY_BUCKETS := 3
const OBSTACLE_BUCKETS := 2
const BASE_STATE_COUNT := FOOD_BUCKETS * ENERGY_BUCKETS * OBSTACLE_BUCKETS
# No signal, or one of eight neutral symbols × three directions × two distances.
const SIGNAL_BUCKETS := 1 + 8 * 3 * 2
const LEGACY_STATE_COUNT := BASE_STATE_COUNT * SIGNAL_BUCKETS
const STATE_COUNT := LEGACY_STATE_COUNT + FOOD_BUCKETS * OBSTACLE_BUCKETS * SIGNAL_BUCKETS
const AHEAD_ANGLE := 0.25
const NEAR_DISTANCE := 60.0
const LOW_ENERGY := 0.35
const HIGH_ENERGY := 0.7
const FOOD_NAMES := ["none", "reach", "near_left", "near_ahead", "near_right", "far_left", "far_ahead", "far_right"]
const ENERGY_NAMES := ["low", "mid", "high"]
const TICK_DT := 0.1
const GOAL_SKILLS := ["ir_ate_local", "buscar_agua"]
const GOAL_STATE_COUNT := 2 * 13 * 3 * 2
const GOAL_ANGLE_STEP := 0.5

## Body-relative goal features generalize across absolute positions/headings.
## Marked locations are explicit player information; water comes from sensors.
static func goal_features(creature, skill: String, target: Vector2, sensors: Dictionary, world_size: Vector2, visible: bool = true) -> Dictionary:
	var offset: Vector2 = target - creature.pos
	var distance := offset.length()
	var relative := wrapf(offset.angle() - creature.heading, -PI, PI)
	var direction := clampi(roundi(relative / GOAL_ANGLE_STEP), -6, 6) + 6
	var bucket := 0 if distance <= reach(creature) else (1 if distance <= NEAR_DISTANCE else 2)
	if bucket == 0:
		direction = 6
	var obstacle := _obstacle_ahead(creature, sensors.get("obstacles", []), world_size)
	return {"skill": skill, "state": ((GOAL_SKILLS.find(skill) * 13 + direction) * 3 + bucket) * 2 + (1 if obstacle else 0),
		"direction_bucket": direction, "distance_bucket": bucket, "distance": snappedf(distance, 0.000001),
		"visible": visible, "obstacle_ahead": obstacle}

static func reach(creature) -> float:
	return creature.genome.size + 5.0

static func state_index(food_bucket: int, energy_bucket: int, obstacle_ahead: bool) -> int:
	return (food_bucket * ENERGY_BUCKETS + energy_bucket) * OBSTACLE_BUCKETS + (1 if obstacle_ahead else 0)

static func describe_state(state: int) -> String:
	if state >= LEGACY_STATE_COUNT:
		return "ecology.thirst"
	state = state % BASE_STATE_COUNT
	var obstacle := state % OBSTACLE_BUCKETS
	var energy := (state / OBSTACLE_BUCKETS) % ENERGY_BUCKETS
	var food := state / (OBSTACLE_BUCKETS * ENERGY_BUCKETS)
	return "food=%s energy=%s obstacle_ahead=%s" % [FOOD_NAMES[food], ENERGY_NAMES[energy], "yes" if obstacle == 1 else "no"]

static func features(creature, sensors: Dictionary, world_size: Vector2) -> Dictionary:
	var closest_id := -1
	var closest_distance := INF
	var closest_pos := Vector2.ZERO
	var best_score := INF
	for food in sensors.get("foods", []):
		var distance: float = creature.pos.distance_to(food["pos"])
		var score: float = food_score(creature, food, distance)
		if score < best_score:
			best_score = score
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
	var heard: Dictionary = sensors.get("signal", {})
	var signal_bucket := 0
	if not heard.is_empty():
		signal_bucket = 1 + (int(heard["symbol"]) * 3 + int(heard["direction_bucket"])) * 2 + int(heard["distance_bucket"])
	var water_id := -1
	var water_distance := INF
	var water_pos := Vector2.ZERO
	for water in sensors.get("waters", []):
		var distance: float = creature.pos.distance_to(water["pos"])
		if distance < water_distance:
			water_distance = distance
			water_id = int(water["id"])
			water_pos = water["pos"]
	var water_bucket := 0
	if water_id != -1:
		if water_distance <= reach(creature):
			water_bucket = 1
		else:
			var relative := wrapf((water_pos - creature.pos).angle() - creature.heading, -PI, PI)
			var direction := 0 if relative < -AHEAD_ANGLE else (2 if relative > AHEAD_ANGLE else 1)
			water_bucket = (2 if water_distance <= NEAR_DISTANCE else 5) + direction
	var state := state_index(food_bucket, energy_bucket, obstacle_ahead) + BASE_STATE_COUNT * signal_bucket
	if sensors.get("water_enabled", false) and creature.thirst > Water.THIRST_THRESHOLD:
		state = LEGACY_STATE_COUNT + (water_bucket * OBSTACLE_BUCKETS + (1 if obstacle_ahead else 0)) * SIGNAL_BUCKETS + signal_bucket
	return {
		"state": state, "water_id": water_id, "water_distance": water_distance,
		"water_bucket": water_bucket, "thirst": creature.thirst,
		"water_enabled": sensors.get("water_enabled", false), "allowed_actions": sensors.get("allowed_actions", []),
		"signal": heard.duplicate(true), "signal_bucket": signal_bucket,
		"action_count": sensors.get("action_count", 5),
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

## Shared appraisal keeps the heuristic and pluggable brain on the same physical target.
static func food_score(creature, food: Dictionary, distance: float) -> float:
	var food_type: String = food.get("food_type", "legacy")
	var weight := 1.0
	if creature.personality != null:
		weight = creature.personality.food_weight(creature, food_type)
	return (distance + 1.0) / (float(FoodCatalog.PARAMETERS[food_type]["palatability"]) * weight)
