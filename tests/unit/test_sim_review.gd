extends RefCounted
## Regression coverage for independent review F1-F5.
const World = preload("res://scripts/world/sim_world.gd")
const Creature = preload("res://scripts/creature/sim_creature.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Q = preload("res://scripts/behavior/q_brain.gd")
const RandomBrain = preload("res://scripts/behavior/random_brain.gd")
const Text = preload("res://scripts/core/textos.gd")

func run() -> Array:
	var failures: Array = []
	_versions(failures)
	_energy(failures)
	_schema(failures)
	_pet(failures)
	_grid(failures)
	for code in ["brain.q_explore", "brain.q_greedy", "brain.q_frozen", "brain.random", "brain.eat_empty", "brain.blocked"]:
		_check(Text.razao(code) != Text.texto("reason_unknown"), "Missing policy translation: " + code, failures)
	for action in ["forward", "turn_left", "turn_right"]:
		_check(Text.acao(action) != Text.texto("action_unknown"), "Missing action translation: " + action, failures)
	return failures

func _check(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append(message)

func _versions(failures: Array) -> void:
	var world := World.new(3)
	for value in [null, "1", [1], {}, true]:
		var data := world.to_dict()
		data["save_version"] = value
		_check(World.from_dict(data) == null, "Wrong-typed world version accepted", failures)
		data = world.creatures[world.pet_id].to_dict()
		data["version"] = value
		_check(Creature.from_dict(data) == null, "Wrong-typed creature version accepted", failures)
		data = Genes.new().to_dict()
		data["version"] = value
		_check(Genes.from_dict(data) == null, "Wrong-typed genome version accepted", failures)
		for brain in [Q.new(), RandomBrain.new()]:
			data = brain.to_dict()
			data["version"] = value
			_check(brain.from_dict(data) == null, "Wrong-typed brain version accepted", failures)

func _energy(failures: Array) -> void:
	var world := World.new(3)
	for value in [1e308, INF, NAN, 0.000000001]:
		var data := world.to_dict()
		data["creatures"][0]["energy"] = value
		data["creatures"][0]["max_energy"] = value
		_check(World.from_dict(data) == null, "Unsafe creature energy accepted", failures)
		data = world.to_dict()
		data["foods"][0]["energy"] = value
		_check(World.from_dict(data) == null, "Unsafe food energy accepted", failures)
	var data := world.to_dict()
	data["creatures"][0]["energy"] = 10000.0
	data["creatures"][0]["max_energy"] = 10000.0
	var restored := World.from_dict(data)
	_check(restored != null, "Safe energy upper boundary rejected", failures)
	if restored != null:
		restored.step()
		for creature in restored.creatures.values():
			_check(is_finite(creature.energy) and is_finite(creature.hunger), "Nonfinite loaded physiology", failures)

func _schema(failures: Array) -> void:
	var world := World.new(3)
	for entry in [1, null, "a", {}, {"type": "unknown", "tick": 0, "creature_id": world.pet_id},
		{"type": "spawn", "tick": 1, "creature_id": world.pet_id, "name": "future"},
		{"type": "eat", "tick": 0, "creature_id": world.pet_id, "food_id": 1, "energy": "32"},
		{"type": "death", "tick": 0, "creature_id": world.pet_id, "reason": []}]:
		var data := world.to_dict()
		data["events"] = [entry]
		_check(World.from_dict(data) == null, "Malformed event accepted: " + str(entry), failures)
		data = world.to_dict()
		data["creatures"][0]["memory"] = [entry]
		_check(World.from_dict(data) == null, "Malformed memory accepted", failures)
	for field in ["name", "last_reason", "last_action"]:
		var data := world.to_dict()
		data["creatures"][0][field] = "a".repeat(1024)
		_check(World.from_dict(data) == null, "Unbounded creature text accepted", failures)
	var data := world.to_dict()
	data["events"][0]["extra"] = "a".repeat(100000)
	_check(World.from_dict(data) == null, "Unexpected oversized event payload accepted", failures)

func _pet(failures: Array) -> void:
	var world := World.new(1, {"creature_count": 1, "food_count": 0, "obstacle_count": 0, "food_regrow": false})
	_check(world.pet_id != -1, "Initial setup did not adopt its first creature", failures)
	world.creatures[world.pet_id].energy = 0.0
	world.step()
	world.spawn_creature(Vector2(100, 100), "Newcomer")
	_check(world.pet_id == -1, "Dead pet identity transferred to newcomer", failures)
	var restored := World.from_dict(JSON.parse_string(JSON.stringify(world.to_dict())))
	_check(restored != null and restored.pet_id == -1, "Absent pet identity did not persist", failures)

## Compare indexed perception against the original exhaustive geometric definition,
## including creatures crossing cells and food removal/regrowth within a tick.
func _grid(failures: Array) -> void:
	var world := World.new(71, {"creature_count": 30, "food_count": 80, "obstacle_count": 20})
	for index in range(15):
		world.step()
		for creature in world.creatures.values():
			var expected := {"foods": [], "creatures": [], "obstacles": [], "hunger": creature.hunger, "signal": {}, "action_count": 5}
			for food in world.foods:
				if world._visible(creature, food["pos"]) and not world._occluded(creature.pos, food["pos"]):
					expected["foods"].append(food)
			for other in world.creatures.values():
				if other.id != creature.id and world._visible(creature, other.pos) and not world._occluded(creature.pos, other.pos):
					expected["creatures"].append({"id": other.id, "pos": other.pos})
			for obstacle in world.obstacles:
				if world._visible(creature, obstacle["pos"]):
					expected["obstacles"].append(obstacle)
			_check(world.sense(creature) == expected, "Grid changed perception", failures)
			world._in_step = true
			_check(world.sense(creature) == expected, "Indexed occlusion changed perception", failures)
			world._in_step = false
	# Sensor results must not let a caller mutate the world's food entries.
	var observer = world.creatures.values()[0]
	observer.genome.vision_range = 240.0
	observer.genome.vision_fov = TAU
	world.place_food(observer.pos)
	var perceived: Dictionary = world.sense(observer)
	if not perceived["foods"].is_empty():
		perceived["foods"][0]["energy"] = -99.0
		_check(world.foods.all(func(food): return food["energy"] > 0.0), "Sensor result aliases world data", failures)
