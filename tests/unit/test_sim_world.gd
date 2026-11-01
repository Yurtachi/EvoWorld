extends RefCounted

const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")

func run() -> Array:
	var failures: Array = []
	_determinism(failures)
	_starvation(failures)
	_energy_bounds(failures)
	_round_trip(failures)
	_empty_population(failures)
	_sensors_and_obstacles(failures)
	_food_and_rest(failures)
	_invalid_saves(failures)
	_genome(failures)
	return failures

func _empty_config() -> Dictionary:
	return {"creature_count": 0, "food_count": 0, "obstacle_count": 0, "food_regrow": false}

func _check(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append(message)

func _snapshot(world) -> String:
	return JSON.stringify(world.to_dict(), "", true, true)

func _determinism(failures: Array) -> void:
	var first := World.new(17431)
	var second := World.new(17431)
	for index in range(500):
		first.step()
		second.step()
	_check(_snapshot(first) == _snapshot(second), "Same seed diverged after 500 ticks", failures)
	_check(_snapshot(first) != _snapshot(World.new(17432)), "Different seed must change initial state", failures)

func _starvation(failures: Array) -> void:
	var config := _empty_config()
	config["creature_count"] = 4
	var world := World.new(15, config)
	var original_creatures := world.creatures.values()
	for index in range(4000):
		world.step()
	_check(world.creatures.is_empty(), "No-food world did not starve", failures)
	_check(world.pet_id == -1, "Dead pet ID was not cleared", failures)
	for creature in original_creatures:
		_check(not creature.alive and creature.energy == 0.0, "Starvation must set alive=false and energy=0", failures)
	var deaths := 0
	for event in world.events:
		if event["type"] == "death" and event["reason"] == "starvation":
			deaths += 1
	_check(deaths == 4, "Starvation death events missing", failures)

func _energy_bounds(failures: Array) -> void:
	var world := World.new(9821)
	var references := world.creatures.values()
	for index in range(2000):
		for creature in world.creatures.values():
			if index % 20 == 0:
				world.place_food(creature.pos)
		world.step()
		for creature in references:
			if creature.energy < 0.0 or creature.energy > creature.max_energy or creature.hunger < 0.0 or creature.hunger > 1.0:
				failures.append("Energy/hunger outside biological bounds")
				return

func _round_trip(failures: Array) -> void:
	# Negative 64-bit seed also verifies that JSON cannot truncate the seed/RNG state.
	var world := World.new(-9223372036854775000)
	world.creatures[world.pet_id].name = "Pet with identity"
	for index in range(187):
		world.step()
	var encoded := _snapshot(world)
	var restored := World.from_dict(JSON.parse_string(encoded))
	_check(restored != null, "Valid JSON save rejected", failures)
	if restored == null:
		return
	_check(_snapshot(restored) == encoded, "JSON round trip changed state", failures)
	var default_json := World.from_dict(JSON.parse_string(JSON.stringify(world.to_dict())))
	_check(default_json != null and _snapshot(default_json) == encoded, "Default JSON precision changed state", failures)
	for index in range(500):
		world.step()
		restored.step()
	_check(_snapshot(world) == _snapshot(restored), "Save continuation diverged after 500 further ticks", failures)
	_check(world.spawn_creature(Vector2(20, 20)) == restored.spawn_creature(Vector2(20, 20)), "Restored ID sequence diverged", failures)
	_check(_snapshot(world) == _snapshot(restored), "Spawn after restore changed random sequence", failures)

func _empty_population(failures: Array) -> void:
	var config := _empty_config()
	config.merge({"food_regrow": true, "food_capacity": 3, "food_regrow_interval": 2}, true)
	var world := World.new(9, config)
	for index in range(500):
		world.step()
	_check(world.tick == 500 and world.creatures.is_empty(), "Empty population cannot advance", failures)
	_check(world.foods.size() == 3, "Food regrowth must respect capacity with empty population", failures)
	var restored := World.from_dict(JSON.parse_string(_snapshot(world)))
	_check(restored != null and _snapshot(world) == _snapshot(restored), "Empty population save failed", failures)

func _sensors_and_obstacles(failures: Array) -> void:
	var world := World.new(81, _empty_config())
	var genes := Genes.new()
	genes.vision_range = 100.0
	genes.vision_fov = PI / 2.0
	var creature_id := world.spawn_creature(Vector2(200, 200), "Observer", genes)
	var creature = world.creatures[creature_id]
	creature.heading = 0.0
	var front := world.place_food(Vector2(250, 200))
	world.place_food(Vector2(150, 200))
	world.place_food(Vector2(350, 200))
	var perceived: Array = world.sense(creature)["foods"]
	_check(perceived.size() == 1 and perceived[0]["id"] == front, "Sensors ignored range or field of view", failures)
	world.place_obstacle(Vector2(225, 200), 10.0)
	_check(world.sense(creature)["foods"].is_empty(), "Obstacle did not occlude food", failures)
	_check(world.place_food(Vector2(225, 200)) == -1, "Food placed inside obstacle", failures)
	creature.energy = 70.0
	creature.age = 30
	world.step()
	_check(creature.last_action == "avoid_obstacle", "Baseline did not avoid perceived obstacle", failures)
	for index in range(300):
		world.step()
		_check(creature.pos.distance_to(Vector2(225, 200)) >= 10.0 + creature.genome.size - 0.001, "Creature penetrated obstacle", failures)
		_check(creature.pos.x >= creature.genome.size and creature.pos.y >= creature.genome.size and creature.pos.x <= world.size.x - creature.genome.size and creature.pos.y <= world.size.y - creature.genome.size, "Creature left world bounds", failures)

func _food_and_rest(failures: Array) -> void:
	var world := World.new(6, _empty_config())
	var creature_id := world.spawn_creature(Vector2(100, 100), "Hungry", Genes.new())
	var creature = world.creatures[creature_id]
	creature.energy = 20.0
	creature.heading = 0.0
	world.place_food(Vector2(135, 100))
	world.step()
	_check(creature.last_action == "seek_food", "Visible food did not cause seeking", failures)
	for index in range(10):
		world.step()
	_check(world.foods.is_empty() and creature.energy > 40.0 and not creature.memory.is_empty(), "Eating did not consume food, restore energy and record memory", failures)
	creature.energy = creature.max_energy
	var before: Vector2 = creature.pos
	world.step()
	_check(creature.last_action == "rest" and creature.pos == before and creature.energy < creature.max_energy, "Rest must conserve position and still pay metabolism", failures)
	for index in range(300):
		world.spawn_creature(Vector2(400, 400))
	_check(world.events.size() <= World.EVENT_LIMIT, "Event history exceeded ring buffer", failures)

func _invalid_saves(failures: Array) -> void:
	var world := World.new(3)
	_check(World.from_dict({}) == null, "Empty save accepted", failures)
	var bad := world.to_dict()
	bad["save_version"] = 999
	_check(World.from_dict(bad) == null, "Unknown save version accepted", failures)
	bad = world.to_dict()
	bad["creatures"][0]["energy"] = -1.0
	_check(World.from_dict(bad) == null, "Negative saved energy accepted", failures)
	bad = world.to_dict()
	bad["foods"][0]["id"] = bad["creatures"][0]["id"]
	_check(World.from_dict(bad) == null, "Duplicate entity ID accepted", failures)
	bad = world.to_dict()
	bad["rng_state"]["state"] = 1.1
	_check(World.from_dict(bad) == null, "Malformed RNG state accepted", failures)
	bad = world.to_dict()
	bad["rng_state"]["state"] = "99999999999999999999999999999"
	_check(World.from_dict(bad) == null, "Overflowing RNG state accepted", failures)
	bad = world.to_dict()
	bad["events"] = [Vector2.ZERO]
	_check(World.from_dict(bad) == null, "Non-JSON event accepted", failures)

func _genome(failures: Array) -> void:
	var genome := Genes.new()
	var default_copy := Genes.from_dict(JSON.parse_string(JSON.stringify(genome.to_dict())))
	_check(default_copy != null and default_copy.to_dict() == genome.to_dict(), "Default genome did not round trip", failures)
	genome.size = -20.0
	genome.speed = 1e6
	genome.bound_genes()
	_check(genome.size == Genes.BOUNDS["size"][0] and genome.speed == Genes.BOUNDS["speed"][1], "Gene bounds were not applied", failures)
	genome.parents = [23, 40]
	genome.generation = 2
	var restored := Genes.from_dict(JSON.parse_string(JSON.stringify(genome.to_dict(), "", true, true)))
	_check(restored != null and restored.to_dict() == genome.to_dict(), "Genome lineage did not round trip", failures)
