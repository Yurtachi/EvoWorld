extends RefCounted
## In-lifetime tabular Q-learning over discretized limited observations.
## Reward is the creature's real physiological energy change between decisions:
##   reward = energy gained by eating - metabolic/movement cost - damage
## plus 0.25 * actual hydration change when water physiology is enabled.
## Food toxicity and dehydration costs are captured as real energy loss.
## A death penalty makes terminal states
## worse than any continued life, so ending the life early can never look attractive.
## No reward is given for actions themselves (e.g. pressing "eat" or approaching food),
## which removes the obvious reward-hacking loops.

const Obs = preload("res://scripts/behavior/observation.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const Data = preload("res://scripts/core/sim_data.gd")
const KIND := "q_learning"
const VERSION := 3
const TABLE_SIZE := Obs.STATE_COUNT * Actions.COUNT

var alpha: float = snappedf(0.1, 0.000001)
var gamma: float = 0.97
var epsilon_start: float = 0.3
var epsilon_min: float = 0.02
var epsilon_decay: float = 3000.0 # decisions after which epsilon has halved
var death_penalty: float = 25.0
var learning: bool = true
var q: Array = []
var steps: int = 0
var prev_state: int = -1
var prev_action: int = -1
var prev_energy: float = 0.0
var prev_hydration: float = 100.0
var prev_water_enabled := false
var _allowed_actions: Array = []
var total_reward: float = 0.0
var last_reason: String = ""

func _init() -> void:
	q.resize(TABLE_SIZE)
	q.fill(0.0)

func epsilon() -> float:
	return maxf(epsilon_min, epsilon_start * epsilon_decay / (epsilon_decay + float(steps)))

func greedy(state: int, action_count: int = Actions.COUNT) -> int:
	var best := 0
	var best_value: float = q[state * Actions.COUNT]
	for action in range(1, action_count):
		if not _allowed_actions.is_empty() and action not in _allowed_actions:
			continue
		var value: float = q[state * Actions.COUNT + action]
		if value > best_value:
			best_value = value
			best = action
	return best

func max_q(state: int, action_count: int = Actions.COUNT) -> float:
	return q[state * Actions.COUNT + greedy(state, action_count)]

func value(state: int, action: int) -> float:
	return q[state * Actions.COUNT + action]

func decide(creature, obs: Dictionary, rng) -> int:
	_allowed_actions = obs.get("allowed_actions", [])
	var state: int = obs["state"]
	var action_count: int = obs.get("action_count", Actions.COUNT)
	if prev_state >= 0:
		var reward: float = creature.energy - prev_energy
		if prev_water_enabled:
			reward += 0.25 * (creature.hydration - prev_hydration)
		total_reward = snappedf(total_reward + reward, 0.000001)
		if learning:
			update(prev_state, prev_action, reward, state, false, action_count)
	var action := greedy(state, action_count)
	var explored := false
	if learning:
		var eps := epsilon()
		if rng.between(0.0, 1.0) < eps:
			if _allowed_actions.is_empty():
				action = clampi(int(rng.between(0.0, float(action_count))), 0, action_count - 1)
			else:
				action = int(_allowed_actions[clampi(int(rng.between(0.0, float(_allowed_actions.size()))), 0, _allowed_actions.size() - 1)])
			explored = true
	steps += 1
	prev_state = state
	prev_action = action
	prev_energy = creature.energy
	prev_hydration = creature.hydration
	prev_water_enabled = obs.get("water_enabled", false)
	last_reason = "brain.q_frozen" if not learning else ("brain.q_explore" if explored else "brain.q_greedy")
	return action

func on_death(creature) -> void:
	if prev_state < 0:
		return
	var reward: float = creature.energy - prev_energy - death_penalty
	if prev_water_enabled:
		reward += 0.25 * (creature.hydration - prev_hydration)
	total_reward = snappedf(total_reward + reward, 0.000001)
	if learning:
		update(prev_state, prev_action, reward, -1, true)
	prev_state = -1
	prev_action = -1

func update(state: int, action: int, reward: float, next_state: int, terminal: bool, action_count: int = Actions.COUNT) -> void:
	var index := state * Actions.COUNT + action
	var target := reward if terminal else reward + gamma * max_q(next_state, action_count)
	q[index] = snappedf(float(q[index]) + alpha * (target - float(q[index])), 0.000001)

## Forget the in-flight transition (e.g. when a checkpoint is copied into a new body).
func reset_episode() -> void:
	suspend_transition()
	total_reward = 0.0

## Player control cancels the pending transition without erasing reward history.
func suspend_transition() -> void:
	prev_state = -1
	prev_action = -1
	prev_energy = 0.0
	prev_hydration = 100.0
	prev_water_enabled = false

func copy():
	return from_dict(to_dict())

func to_dict() -> Dictionary:
	return {
		"kind": KIND, "version": VERSION, "alpha": alpha, "gamma": gamma,
		"epsilon_start": epsilon_start, "epsilon_min": epsilon_min, "epsilon_decay": epsilon_decay,
		"death_penalty": death_penalty, "learning": learning, "q": q.duplicate(), "steps": steps,
		"prev_state": prev_state, "prev_action": prev_action, "prev_energy": prev_energy, "prev_hydration": prev_hydration, "prev_water_enabled": prev_water_enabled,
		"total_reward": total_reward
	}

static func from_dict(data: Dictionary):
	if Data.integer(data.get("version")) and int(data["version"]) == 1:
		data = _migrate_v1(data)
	if Data.integer(data.get("version")) and int(data["version"]) == 2:
		data = _migrate_v2(data)
	if not Data.number(data.get("prev_hydration")) or float(data["prev_hydration"]) < 0.0 or float(data["prev_hydration"]) > 100.0 or not data.get("prev_water_enabled") is bool:
		return null
	if not data.get("kind") is String or data["kind"] != KIND or not Data.integer(data.get("version")) or int(data["version"]) != VERSION:
		return null
	for field in ["alpha", "gamma", "epsilon_start", "epsilon_min", "epsilon_decay", "death_penalty", "prev_energy", "total_reward"]:
		if not Data.number(data.get(field)):
			return null
	if float(data["alpha"]) < 0.000001 or float(data["alpha"]) > 1.0 or float(data["gamma"]) < 0.0 or float(data["gamma"]) > 0.999999:
		return null
	if float(data["epsilon_start"]) < 0.0 or float(data["epsilon_start"]) > 1.0 or float(data["epsilon_min"]) < 0.0 or float(data["epsilon_min"]) > 1.0:
		return null
	if float(data["epsilon_decay"]) < 0.000001 or float(data["death_penalty"]) < 0.0:
		return null
	if not data.get("learning") is bool or not Data.integer(data.get("steps")):
		return null
	if not Data.integer(data.get("prev_state"), -1) or int(data["prev_state"]) >= Obs.STATE_COUNT:
		return null
	if not Data.integer(data.get("prev_action"), -1) or int(data["prev_action"]) >= Actions.COUNT:
		return null
	if (int(data["prev_state"]) == -1) != (int(data["prev_action"]) == -1):
		return null
	if not data.get("q") is Array or data["q"].size() != TABLE_SIZE:
		return null
	for entry in data["q"]:
		if not Data.number(entry) or absf(float(entry)) > 1000000.0:
			return null
	var result = load("res://scripts/behavior/q_brain.gd").new()
	result.alpha = snappedf(float(data["alpha"]), 0.000001)
	result.gamma = snappedf(float(data["gamma"]), 0.000001)
	result.epsilon_start = snappedf(float(data["epsilon_start"]), 0.000001)
	result.epsilon_min = snappedf(float(data["epsilon_min"]), 0.000001)
	result.epsilon_decay = snappedf(float(data["epsilon_decay"]), 0.000001)
	result.death_penalty = snappedf(float(data["death_penalty"]), 0.000001)
	result.learning = data["learning"]
	for index in range(TABLE_SIZE):
		result.q[index] = snappedf(float(data["q"][index]), 0.000001)
	result.steps = int(data["steps"])
	result.prev_state = int(data["prev_state"])
	result.prev_action = int(data["prev_action"])
	result.prev_hydration = snappedf(float(data["prev_hydration"]), 0.000001)
	result.prev_water_enabled = data["prev_water_enabled"]
	result.prev_energy = snappedf(float(data["prev_energy"]), 0.000001)
	result.total_reward = snappedf(float(data["total_reward"]), 0.000001)
	return result

static func _migrate_v1(data: Dictionary) -> Dictionary:
	if not data.get("q") is Array or data["q"].size() != 48 * 5:
		return {}
	if not Data.integer(data.get("prev_state"), -1) or int(data["prev_state"]) >= 48 or not Data.integer(data.get("prev_action"), -1) or int(data["prev_action"]) >= 5:
		return {}
	var migrated := data.duplicate(true)
	var table: Array = []
	table.resize(TABLE_SIZE)
	table.fill(0.0)
	for state in range(48):
		for action in range(5):
			table[state * Actions.COUNT + action] = data["q"][state * 5 + action]
	migrated["q"] = table
	migrated["version"] = VERSION
	migrated["prev_hydration"] = 100.0
	migrated["prev_water_enabled"] = false
	return migrated

## v2 used 2352 states and thirteen actions. Keep every learned cell and transition.
static func _migrate_v2(data: Dictionary) -> Dictionary:
	const OLD_ACTIONS := 13
	if not data.get("q") is Array or data["q"].size() != Obs.LEGACY_STATE_COUNT * OLD_ACTIONS:
		return {}
	if not Data.integer(data.get("prev_state"), -1) or int(data["prev_state"]) >= Obs.LEGACY_STATE_COUNT or not Data.integer(data.get("prev_action"), -1) or int(data["prev_action"]) >= OLD_ACTIONS:
		return {}
	var migrated := data.duplicate(true)
	var table: Array = []
	table.resize(TABLE_SIZE)
	table.fill(0.0)
	for state in range(Obs.LEGACY_STATE_COUNT):
		for action in range(OLD_ACTIONS):
			table[state * Actions.COUNT + action] = data["q"][state * OLD_ACTIONS + action]
	migrated["q"] = table
	migrated["prev_hydration"] = 100.0
	migrated["prev_water_enabled"] = false
	migrated["version"] = VERSION
	return migrated
