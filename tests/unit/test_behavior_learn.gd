extends RefCounted
## Behavior/learning tests: observation discretization, Q-update math, brain persistence,
## backward-compatible snapshots and a controlled learning check.

const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const QBrain = preload("res://scripts/behavior/q_brain.gd")
const RandomBrain = preload("res://scripts/behavior/random_brain.gd")
const Brains = preload("res://scripts/behavior/brains.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Actions = preload("res://scripts/behavior/actions.gd")

func run() -> Array:
	var failures: Array = []
	_observation(failures)
	_q_update(failures)
	_persistence(failures)
	_backward_compatible(failures)
	_invalid_brains(failures)
	_learns_to_eat(failures)
	_reward_and_ablation(failures)
	return failures

func _empty_config() -> Dictionary:
	return {"creature_count": 0, "food_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false}

func _check(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append(message)

func _snapshot(world) -> String:
	return JSON.stringify(world.to_dict(), "", true, true)

func _observation(failures: Array) -> void:
	var world := World.new(5, _empty_config())
	var genes := Genes.new()
	genes.vision_range = 100.0
	genes.vision_fov = PI / 2.0
	var creature = world.creatures[world.spawn_creature(Vector2(300, 300), "Obs", genes)]
	creature.heading = 0.0
	creature.energy = creature.max_energy * 0.5
	var obs := Obs.features(creature, world.sense(creature), world.size)
	_check(obs["food_bucket"] == 0 and obs["energy_bucket"] == 1 and not obs["obstacle_ahead"], "Empty view must be food=none, energy=mid, clear", failures)
	world.place_food(Vector2(380, 300))
	obs = Obs.features(creature, world.sense(creature), world.size)
	_check(obs["food_bucket"] == 6, "Food far ahead bucket wrong: %s" % obs["food_bucket"], failures)
	world.place_food(Vector2(330, 325))
	obs = Obs.features(creature, world.sense(creature), world.size)
	_check(obs["food_bucket"] == 4, "Near food to the right must be near_right: %s" % obs["food_bucket"], failures)
	world.place_food(Vector2(310, 300))
	obs = Obs.features(creature, world.sense(creature), world.size)
	_check(obs["food_bucket"] == 1, "Food within reach bucket wrong", failures)
	world.place_food(Vector2(250, 300)) # behind: outside FOV, must not be seen
	world.foods = world.foods.filter(func(f): return f["pos"] == Vector2(250, 300))
	obs = Obs.features(creature, world.sense(creature), world.size)
	_check(obs["food_bucket"] == 0, "Observation used food outside the field of view", failures)
	creature.pos = Vector2(world.size.x - genes.size - 2.0, 300)
	obs = Obs.features(creature, world.sense(creature), world.size)
	_check(obs["obstacle_ahead"], "Wall ahead not detected", failures)
	creature.pos = Vector2(300, 300)
	world.place_obstacle(Vector2(325, 300), 8.0)
	obs = Obs.features(creature, world.sense(creature), world.size)
	_check(obs["obstacle_ahead"], "Perceived obstacle ahead not detected", failures)
	creature.energy = creature.max_energy * 0.1
	obs = Obs.features(creature, world.sense(creature), world.size)
	_check(obs["energy_bucket"] == 0 and obs["state"] >= 0 and obs["state"] < Obs.STATE_COUNT, "Energy bucket/state range wrong", failures)

func _q_update(failures: Array) -> void:
	var brain := QBrain.new()
	brain.alpha = 0.5
	brain.gamma = 0.9
	brain.q[3 * Actions.COUNT + Actions.EAT] = 2.0
	brain.update(0, Actions.FORWARD, 1.0, 3, false)
	_check(is_equal_approx(brain.value(0, Actions.FORWARD), 0.5 * (1.0 + 0.9 * 2.0)), "Q update math wrong", failures)
	brain.update(1, Actions.REST, -4.0, -1, true)
	_check(is_equal_approx(brain.value(1, Actions.REST), -2.0), "Terminal Q update must not bootstrap", failures)
	_check(brain.greedy(3) == Actions.EAT and brain.greedy(0) == Actions.FORWARD, "Greedy selection wrong", failures)

func _learner_world(seed: int):
	var world := World.new(seed, {"creature_count": 6, "food_count": 30, "obstacle_count": 6, "reproduction_enabled": false})
	var ids := world.creatures.keys()
	ids.sort()
	for index in range(ids.size()):
		world.creatures[ids[index]].brain = RandomBrain.new() if index == 0 else QBrain.new()
	return world

func _persistence(failures: Array) -> void:
	var world = _learner_world(424242)
	for index in range(300):
		world.step()
	var learned := false
	for creature in world.creatures.values():
		if creature.brain is QBrain and creature.brain.steps > 0 and creature.brain.q.any(func(v): return v != 0.0):
			learned = true
	_check(learned, "Q-learners did not update any value in 300 ticks", failures)
	var encoded := _snapshot(world)
	var restored = World.from_dict(JSON.parse_string(encoded))
	_check(restored != null, "World with brains failed to load", failures)
	if restored == null:
		return
	_check(_snapshot(restored) == encoded, "Brain state changed in JSON round trip", failures)
	var default_json = World.from_dict(JSON.parse_string(JSON.stringify(world.to_dict())))
	_check(default_json != null and _snapshot(default_json) == encoded, "Brain state changed with default JSON precision", failures)
	for index in range(400):
		world.step()
		restored.step()
	_check(_snapshot(world) == _snapshot(restored), "Learning continuation diverged after load", failures)
	var a = _learner_world(99)
	var b = _learner_world(99)
	for index in range(300):
		a.step()
		b.step()
	_check(_snapshot(a) == _snapshot(b), "Learning run is not deterministic for a fixed seed", failures)

func _backward_compatible(failures: Array) -> void:
	var world := World.new(17)
	for creature in world.to_dict()["creatures"]:
		_check(not creature.has("brain"), "Heuristic creatures must not gain a brain key", failures)

func _invalid_brains(failures: Array) -> void:
	var world = _learner_world(7)
	world.step()
	var good: Dictionary = world.to_dict()
	var bad: Dictionary = good.duplicate(true)
	bad["creatures"][1]["brain"]["q"].pop_back()
	_check(World.from_dict(bad) == null, "Wrong Q-table size accepted", failures)
	bad = good.duplicate(true)
	bad["creatures"][1]["brain"]["kind"] = "res://evil.gd"
	_check(World.from_dict(bad) == null, "Unknown brain kind accepted", failures)
	bad = good.duplicate(true)
	bad["creatures"][1]["brain"]["gamma"] = 1.5
	_check(World.from_dict(bad) == null, "Invalid gamma accepted", failures)
	bad = good.duplicate(true)
	bad["creatures"][1]["brain"]["q"][0] = "1"
	_check(World.from_dict(bad) == null, "Non-numeric Q value accepted", failures)
	bad = good.duplicate(true)
	bad["creatures"][1]["brain"] = []
	_check(World.from_dict(bad) == null, "Non-dictionary brain accepted", failures)
	_check(Brains.make("q_learning") is QBrain and Brains.make("nope") == null, "Brain factory wrong", failures)

## Controlled check: food is always within reach; the only way to gain energy is "eat".
func _learns_to_eat(failures: Array) -> void:
	var world := World.new(31, _empty_config())
	var creature = world.creatures[world.spawn_creature(Vector2(300, 300), "Learner", Genes.new())]
	var brain := QBrain.new()
	creature.brain = brain
	creature.energy = creature.max_energy * 0.5
	for index in range(3000):
		# Replenish directly in view each tick, including after turns. This isolates
		# learning to eat from the separate problem of finding food again.
		world.foods.clear()
		world.place_food(creature.pos + Vector2.from_angle(creature.heading) * 4.0)
		world.step()
		if not creature.alive:
			break
	_check(creature.alive, "Learner starved with food always within reach", failures)
	var reach_states := 0
	var eat_preferred := 0
	for energy in range(Obs.ENERGY_BUCKETS):
		for obstacle in [false, true]:
			var state := Obs.state_index(1, energy, obstacle)
			if brain.q.slice(state * Actions.COUNT, (state + 1) * Actions.COUNT).any(func(v): return v != 0.0):
				reach_states += 1
				if brain.greedy(state) == Actions.EAT:
					eat_preferred += 1
	_check(reach_states > 0 and eat_preferred == reach_states, "Learner did not come to prefer eat when food is in reach (%d/%d)" % [eat_preferred, reach_states], failures)

## Energy accounting and ablation: no bonus for eat attempts, terminal penalty,
## and frozen Q values cannot change even when the body gains/loses energy.
func _reward_and_ablation(failures: Array) -> void:
	var world := World.new(32, _empty_config())
	var creature = world.creatures[world.spawn_creature(Vector2(300, 300), "Reward", Genes.new())]
	var brain := QBrain.new()
	brain.epsilon_start = 0.0
	brain.epsilon_min = 0.0
	creature.brain = brain
	var state := Obs.state_index(0, 2, false)
	brain.q[state * Actions.COUNT + Actions.EAT] = 10.0
	var before: float = creature.energy
	world.step()
	var cost: float = before - creature.energy
	_check(creature.last_action == "eat" and cost > 0.0 and creature.last_reason == "brain.eat_empty", "Empty eat attempt must spend energy without a bonus", failures)
	world.step()
	_check(is_equal_approx(brain.total_reward, -cost), "Reward differs from actual physiological energy change", failures)
	var q_before: Array = brain.q.duplicate()
	brain.learning = false
	for index in range(20): world.step()
	_check(brain.q == q_before, "Frozen ablation modified Q values", failures)
	brain.learning = true
	var previous_energy: float = brain.prev_energy
	var previous_reward: float = brain.total_reward
	var previous_state: int = brain.prev_state
	var previous_action: int = brain.prev_action
	var previous_q: float = brain.value(previous_state, previous_action)
	creature.energy = 0.0
	world.step()
	var terminal_reward: float = -previous_energy - brain.death_penalty
	# The final decide first credits the external energy loss and then death
	# applies its terminal penalty to the just-selected transition.
	_check(not creature.alive and brain.prev_state == -1 and brain.prev_action == -1, "Death did not clear the terminal transition", failures)
	_check(is_equal_approx(brain.total_reward - previous_reward, terminal_reward), "Death reward does not match energy loss plus terminal penalty", failures)
	_check(brain.value(previous_state, previous_action) != previous_q, "Terminal learning did not update Q", failures)
