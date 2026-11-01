class_name SimWorld
extends RefCounted
## Fixed-step baseline ecology. Decisions use sensors; collision uses physical geometry.

const Rng = preload("res://scripts/core/sim_rng.gd")
const Ids = preload("res://scripts/core/sim_ids.gd")
const Data = preload("res://scripts/core/sim_data.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Creature = preload("res://scripts/creature/sim_creature.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const SAVE_VERSION := 1
const TICK_DT := 0.1
const EVENT_LIMIT := 256
const FOOD_ENERGY := 32.0

var tick: int = 0
var seed: int = 1
var size := Vector2(1200.0, 760.0)
var creatures: Dictionary = {}
var foods: Array = []
var obstacles: Array = []
var events: Array = []
var pet_id: int = -1
var food_regrow: bool = true
var food_capacity: int = 100
var food_regrow_interval: int = 10
var food_regrow_batch: int = 2
var rng: Rng
var ids := Ids.new()

func _init(world_seed: int = 1, config: Dictionary = {}) -> void:
	seed = world_seed
	rng = Rng.new(seed)
	if config.get("size") is Vector2:
		size = config["size"]
		if not size.is_finite():
			size = Vector2(1200.0, 760.0)
		size = size.clamp(Vector2(64.0, 64.0), Vector2(100000.0, 100000.0))
	food_regrow = bool(config.get("food_regrow", true))
	food_capacity = clampi(int(config.get("food_capacity", 100)), 0, 10000)
	food_regrow_interval = maxi(1, int(config.get("food_regrow_interval", 10)))
	food_regrow_batch = clampi(int(config.get("food_regrow_batch", 2)), 0, 1000)
	for index in range(clampi(int(config.get("obstacle_count", 8)), 0, 1000)):
		place_obstacle(_random_position(30.0), rng.between(16.0, 30.0))
	for index in range(clampi(int(config.get("food_count", 80)), 0, food_capacity)):
		place_food(_free_position(3.0))
	for index in range(clampi(int(config.get("creature_count", 16)), 0, 1000)):
		spawn_creature(_free_position(16.0))

func spawn_creature(pos: Vector2, creature_name: String = "", genome = null) -> int:
	if not pos.is_finite():
		return -1
	var genes: Genes
	if genome == null:
		genes = Genes.new()
		for gene in Genes.BOUNDS:
			genes.set(gene, snappedf(rng.between(Genes.BOUNDS[gene][0], Genes.BOUNDS[gene][1]), 0.000001))
	else:
		if not genome is Genes:
			return -1
		genes = Genes.from_dict(genome.to_dict())
		if genes == null:
			return -1
	genes.bound_genes()
	var location := _inside(pos, genes.size)
	if not _clear(location, genes.size):
		location = _free_position(genes.size)
	if not _clear(location, genes.size):
		return -1
	genes.id = ids.take()
	var creature := Creature.new()
	creature.id = ids.take()
	creature.genome = genes
	creature.name = creature_name if not creature_name.is_empty() else "Creature %d" % creature.id
	creature.pos = location
	creature.heading = snappedf(rng.between(-PI, PI), 0.000001)
	creature.max_energy = snappedf(80.0 + genes.size * 2.0, 0.000001)
	creature.energy = snappedf(creature.max_energy * 0.8, 0.000001)
	creatures[creature.id] = creature
	if pet_id == -1:
		pet_id = creature.id
	_record({"type": "spawn", "creature_id": creature.id, "name": creature.name})
	return creature.id

func place_food(pos: Vector2) -> int:
	if not pos.is_finite() or foods.size() >= food_capacity:
		return -1
	var location := _inside(pos, 3.0)
	if not _clear(location, 3.0):
		return -1
	var food_id := ids.take()
	foods.append({"id": food_id, "pos": location, "energy": FOOD_ENERGY})
	return food_id

func place_obstacle(pos: Vector2, radius: float) -> void:
	if not pos.is_finite() or not is_finite(radius) or radius <= 0.0:
		return
	var actual_radius := snappedf(clampf(radius, 1.0, minf(size.x, size.y) * 0.45), 0.000001)
	var location := _inside(pos, actual_radius)
	for creature in creatures.values():
		if creature.pos.distance_to(location) < actual_radius + creature.genome.size:
			return
	for food in foods:
		if food["pos"].distance_to(location) < actual_radius + 3.0:
			return
	obstacles.append({"pos": location, "radius": actual_radius})

func step() -> void:
	tick += 1
	# Stable ordering also preserves competition outcomes after save/load.
	var creature_ids := creatures.keys()
	creature_ids.sort()
	for creature_id in creature_ids:
		var creature: Creature = creatures[creature_id]
		_update_creature(creature)
		if not creature.alive:
			creatures.erase(creature_id)
			if pet_id == creature_id:
				pet_id = -1
	if food_regrow and tick % food_regrow_interval == 0:
		for index in range(mini(food_regrow_batch, food_capacity - foods.size())):
			place_food(_free_position(3.0))

func sense(creature: Creature) -> Dictionary:
	var result := {"foods": [], "creatures": [], "obstacles": [], "hunger": creature.hunger}
	for food in foods:
		if _visible(creature, food["pos"]) and not _occluded(creature.pos, food["pos"]):
			result["foods"].append(food.duplicate(true))
	for other in creatures.values():
		if other.id != creature.id and _visible(creature, other.pos) and not _occluded(creature.pos, other.pos):
			result["creatures"].append({"id": other.id, "pos": other.pos})
	for obstacle in obstacles:
		if _visible(creature, obstacle["pos"]):
			result["obstacles"].append(obstacle.duplicate(true))
	return result

func _update_creature(creature: Creature) -> void:
	creature.age += 1
	creature.energy = clampf(creature.energy, 0.0, creature.max_energy)
	var sensors := sense(creature)
	var closest: Dictionary = {}
	var closest_distance := INF
	for food in sensors["foods"]:
		var distance: float = creature.pos.distance_to(food["pos"])
		if distance < closest_distance:
			closest = food
			closest_distance = distance
	var moving := false
	if creature.brain != null:
		moving = _act_with_brain(creature, sensors)
	elif not closest.is_empty() and closest_distance <= creature.genome.size + 5.0 and creature.hunger > 0.05:
		_eat(creature, int(closest["id"]))
	elif creature.hunger < 0.12 or (creature.age % 120 < 12 and closest.is_empty()):
		creature.last_action = "rest"
		creature.last_reason = "Satiated; conserving energy" if creature.hunger < 0.12 else "Brief rest; no food perceived"
	else:
		if not closest.is_empty():
			creature.heading = (closest["pos"] - creature.pos).angle()
			creature.last_action = "seek_food"
			creature.last_reason = "Food %d visible at %.1f units" % [closest["id"], closest_distance]
		else:
			if creature.age % 15 == 0:
				creature.heading += rng.between(-0.9, 0.9)
			creature.last_action = "explore"
			creature.last_reason = "No food within vision; exploring"
		moving = _move(creature, sensors["obstacles"])
	# Rest reduces the activity cost, never creates nutritional energy.
	var cost: float = creature.genome.metabolism * (0.52 + creature.genome.size * 0.022) * TICK_DT
	if moving:
		cost += creature.genome.speed * creature.genome.size * 0.0005 * TICK_DT
	creature.energy = snappedf(clampf(creature.energy - cost, 0.0, creature.max_energy), 0.000001)
	creature.heading = snappedf(wrapf(creature.heading, -PI, PI), 0.000001)
	if creature.energy <= 0.0:
		creature.alive = false
		creature.last_action = "dead"
		creature.last_reason = "Starvation: energy exhausted"
		if creature.brain != null:
			creature.brain.on_death(creature)
		_record({"type": "death", "creature_id": creature.id, "reason": "starvation"})

## Pluggable-policy path: the brain chooses a discrete action from discretized limited
## observations; the world applies the same physics/costs as the heuristic. No reflexive
## obstacle avoidance here: blocked moves simply fail and the brain must learn to turn.
func _act_with_brain(creature: Creature, sensors: Dictionary) -> bool:
	var obs: Dictionary = Obs.features(creature, sensors, size)
	var action: int = creature.brain.decide(creature, obs, rng)
	creature.last_action = Actions.name_of(action)
	creature.last_reason = creature.brain.last_reason
	match action:
		Actions.EAT:
			if int(obs["food_id"]) != -1 and float(obs["food_distance"]) <= Obs.reach(creature):
				_eat(creature, int(obs["food_id"]))
			else:
				creature.last_reason += "; nothing within reach"
			return false
		Actions.REST:
			return false
		Actions.TURN_LEFT:
			creature.heading -= Actions.TURN_STEP
		Actions.TURN_RIGHT:
			creature.heading += Actions.TURN_STEP
		Actions.FORWARD:
			pass
		_:
			return false
	var target := creature.pos + Vector2.from_angle(creature.heading) * creature.genome.speed * TICK_DT
	if target != _inside(target, creature.genome.size) or _occluded(creature.pos, target, creature.genome.size):
		creature.last_reason += "; blocked by physical contact"
		return false
	creature.pos = target
	return true

func _eat(creature: Creature, food_id: int) -> void:
	for index in range(foods.size()):
		if int(foods[index]["id"]) != food_id:
			continue
		var gained := minf(float(foods[index]["energy"]), creature.max_energy - creature.energy)
		creature.energy += gained
		foods.remove_at(index)
		creature.last_action = "eat"
		creature.last_reason = "Ate visible food %d; gained %.1f energy" % [food_id, gained]
		var event := {"type": "eat", "creature_id": creature.id, "food_id": food_id, "energy": snappedf(gained, 0.000001)}
		_record(event)
		creature.remember(events.back())
		return

func _move(creature: Creature, visible_obstacles: Array) -> bool:
	var distance: float = creature.genome.speed * TICK_DT
	var direction := Vector2.from_angle(creature.heading)
	for obstacle in visible_obstacles:
		var ahead := creature.pos + direction * (distance + creature.genome.size + 8.0)
		if _segment_hits(creature.pos, ahead, obstacle["pos"], obstacle["radius"] + creature.genome.size):
			creature.heading += PI * 0.5
			creature.last_action = "avoid_obstacle"
			creature.last_reason = "Obstacle perceived ahead; turning"
			direction = Vector2.from_angle(creature.heading)
			break
	var target := creature.pos + direction * distance
	if target != _inside(target, creature.genome.size) or _occluded(creature.pos, target, creature.genome.size):
		creature.heading += rng.between(1.0, 2.2)
		creature.last_action = "avoid_obstacle"
		creature.last_reason = "Physical boundary contact; turning"
		return false
	creature.pos = target
	return true

func _visible(creature: Creature, target: Vector2) -> bool:
	var offset := target - creature.pos
	if offset.length_squared() > creature.genome.vision_range * creature.genome.vision_range:
		return false
	return offset.is_zero_approx() or absf(wrapf(offset.angle() - creature.heading, -PI, PI)) <= creature.genome.vision_fov * 0.5

func _occluded(start: Vector2, finish: Vector2, margin: float = 0.0) -> bool:
	for obstacle in obstacles:
		if _segment_hits(start, finish, obstacle["pos"], obstacle["radius"] + margin):
			return true
	return false

func _segment_hits(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> bool:
	var delta := finish - start
	var fraction := 0.0 if delta.is_zero_approx() else clampf((center - start).dot(delta) / delta.length_squared(), 0.0, 1.0)
	return (start + delta * fraction).distance_squared_to(center) < radius * radius

func _inside(pos: Vector2, margin: float) -> Vector2:
	return pos.clamp(Vector2.ONE * margin, size - Vector2.ONE * margin)

func _clear(pos: Vector2, radius: float) -> bool:
	return not _occluded(pos, pos, radius)

func _random_position(margin: float) -> Vector2:
	return Vector2(rng.between(margin, size.x - margin), rng.between(margin, size.y - margin))

func _free_position(radius: float) -> Vector2:
	var location := _random_position(radius)
	for attempt in range(64):
		if _clear(location, radius):
			return location
		location = _random_position(radius)
	return location

func _record(event: Dictionary) -> void:
	var entry := event.duplicate(true)
	entry["tick"] = tick
	events.append(entry)
	if events.size() > EVENT_LIMIT:
		events.pop_front()

func to_dict() -> Dictionary:
	var saved_creatures: Array = []
	var creature_ids := creatures.keys()
	creature_ids.sort()
	for creature_id in creature_ids:
		saved_creatures.append(creatures[creature_id].to_dict())
	var saved_foods: Array = []
	for food in foods:
		saved_foods.append({"id": food["id"], "pos": Data.pack_vector(food["pos"]), "energy": food["energy"]})
	var saved_obstacles: Array = []
	for obstacle in obstacles:
		saved_obstacles.append({"pos": Data.pack_vector(obstacle["pos"]), "radius": obstacle["radius"]})
	return {
		"save_version": SAVE_VERSION, "world_seed": str(seed), "tick": tick,
		"size": Data.pack_vector(size), "pet_id": pet_id, "next_id": ids.next_id,
		"rng_state": rng.to_dict(), "creatures": saved_creatures, "foods": saved_foods,
		"obstacles": saved_obstacles, "events": Data.restore_precision(events),
		"config": {"food_regrow": food_regrow, "food_capacity": food_capacity,
			"food_regrow_interval": food_regrow_interval, "food_regrow_batch": food_regrow_batch}
	}

static func from_dict(data: Dictionary) -> SimWorld:
	# Reject invalid input, returning null rather than creating a partial world.
	if data.get("save_version") != SAVE_VERSION or not Data.integer_text(data.get("world_seed")):
		return null
	if not Data.integer(data.get("tick")) or not Data.integer(data.get("next_id"), 1) or not Data.integer(data.get("pet_id"), -1):
		return null
	if not Data.vector(data.get("size")):
		return null
	var saved_size := Data.unpack_vector(data["size"])
	if not saved_size.is_finite() or saved_size.x < 64.0 or saved_size.y < 64.0 or saved_size.x > 100000.0 or saved_size.y > 100000.0:
		return null
	if not data.get("config") is Dictionary or not data.get("rng_state") is Dictionary:
		return null
	var config: Dictionary = data["config"].duplicate()
	if not config.get("food_regrow") is bool:
		return null
	if not Data.integer(config.get("food_capacity")) or int(config["food_capacity"]) > 10000:
		return null
	if not Data.integer(config.get("food_regrow_interval"), 1) or not Data.integer(config.get("food_regrow_batch")) or int(config["food_regrow_batch"]) > 1000:
		return null
	if not Data.integer_text(data["rng_state"].get("state")):
		return null
	for field in ["creatures", "foods", "obstacles", "events"]:
		if not data.get(field) is Array:
			return null
	if data["creatures"].size() > 10000 or data["foods"].size() > int(config["food_capacity"]) or data["obstacles"].size() > 1000:
		return null
	if data["events"].size() > EVENT_LIMIT or not Data.json_data(data["events"]):
		return null
	config.merge({"size": saved_size, "creature_count": 0, "food_count": 0, "obstacle_count": 0}, true)
	var result = load("res://scripts/world/sim_world.gd").new(int(data["world_seed"]), config)
	result.tick = int(data["tick"])
	result.pet_id = int(data["pet_id"])
	var used_ids: Dictionary = {}
	for obstacle in data["obstacles"]:
		if not obstacle is Dictionary or not Data.vector(obstacle.get("pos")) or not Data.number(obstacle.get("radius")):
			return null
		var radius := snappedf(float(obstacle["radius"]), 0.000001)
		var pos := Data.unpack_vector(obstacle["pos"])
		if radius <= 0.0 or radius > minf(saved_size.x, saved_size.y) * 0.45 or pos != result._inside(pos, radius):
			return null
		result.obstacles.append({"pos": pos, "radius": radius})
	for entry in data["creatures"]:
		if not entry is Dictionary:
			return null
		var creature := Creature.from_dict(entry)
		if creature == null or not creature.alive or used_ids.has(creature.id) or used_ids.has(creature.genome.id) or creature.id == creature.genome.id or creature.genome.id < 1:
			return null
		if creature.pos != result._inside(creature.pos, creature.genome.size) or not result._clear(creature.pos, creature.genome.size):
			return null
		used_ids[creature.id] = true
		used_ids[creature.genome.id] = true
		result.creatures[creature.id] = creature
	for food in data["foods"]:
		if not food is Dictionary or not Data.integer(food.get("id"), 1) or used_ids.has(int(food.get("id", -1))) or not Data.vector(food.get("pos")) or not Data.number(food.get("energy")):
			return null
		var pos := Data.unpack_vector(food["pos"])
		if float(food["energy"]) <= 0.0 or pos != result._inside(pos, 3.0) or not result._clear(pos, 3.0):
			return null
		used_ids[int(food["id"])] = true
		result.foods.append({"id": int(food["id"]), "pos": pos, "energy": float(food["energy"])})
	for used_id in used_ids:
		if used_id >= int(data["next_id"]):
			return null
	if result.pet_id != -1 and not result.creatures.has(result.pet_id):
		return null
	result.events = Data.restore_precision(data["events"])
	result.ids.next_id = int(data["next_id"])
	result.rng.restore(data["rng_state"])
	return result
