extends RefCounted
## Neutral symbols. Noise is independent packet loss per in-range receiver.
const Data = preload("res://scripts/core/sim_data.gd")
const DEFAULTS := {"signal_enabled": false, "signal_count": 4, "signal_range": 180.0,
	"signal_noise": 0.05, "signal_cost": 0.3, "signal_ttl": 10}
const LOG_LIMIT := 256

static func valid_config(config: Dictionary) -> bool:
	if not config.get("signal_enabled") is bool:
		return false
	if not Data.integer(config.get("signal_count"), 4) or int(config["signal_count"]) > 8:
		return false
	if not Data.integer(config.get("signal_ttl"), 1) or int(config["signal_ttl"]) > 1000:
		return false
	for key in ["signal_range", "signal_noise", "signal_cost"]:
		if not Data.number(config.get(key)) or float(config[key]) < 0.0:
			return false
	return float(config["signal_range"]) <= 100000.0 and float(config["signal_noise"]) <= 1.0 and float(config["signal_cost"]) <= 10000.0

static func valid_received(value: Variant, max_tick: int = 2147483647, next_id: int = 2147483647, count: int = 8) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	return value.size() == 7 and Data.integer(value.get("tick")) and int(value["tick"]) <= max_tick and Data.integer(value.get("emitter"), 1) and int(value["emitter"]) < next_id and Data.integer(value.get("symbol")) and int(value["symbol"]) < count and Data.integer(value.get("direction_bucket")) and int(value["direction_bucket"]) < 3 and Data.integer(value.get("distance_bucket")) and int(value["distance_bucket"]) < 2 and value.get("reacted") is bool and value.get("before") is String and value["before"].length() <= 256

static func valid_log(logs: Variant, max_tick: int, next_id: int, count: int) -> bool:
	if not logs is Array or logs.size() > LOG_LIMIT:
		return false
	for row in logs:
		if not row is Dictionary or row.size() != 6 or not Data.integer(row.get("tick")) or int(row["tick"]) > max_tick or not Data.integer(row.get("emitter"), 1) or int(row["emitter"]) >= next_id or not Data.integer(row.get("symbol")) or int(row["symbol"]) >= count:
			return false
		var context = row.get("context")
		if not context is Dictionary or context.size() != 2 or not context.get("saw_food") is bool or not context.get("low_energy") is bool:
			return false
		if not row.get("receivers") is Array or row["receivers"].size() > 10000 or not row.get("action_changes") is Array or row["action_changes"].size() > row["receivers"].size():
			return false
		var heard := {}
		for receiver in row["receivers"]:
			if not Data.integer(receiver, 1) or int(receiver) >= next_id or int(receiver) == int(row["emitter"]) or heard.has(int(receiver)):
				return false
			heard[int(receiver)] = true
		var reacted := {}
		for change in row["action_changes"]:
			if not change is Dictionary or change.size() != 4 or not Data.integer(change.get("receiver"), 1) or not heard.has(int(change["receiver"])) or reacted.has(int(change["receiver"])) or not Data.integer(change.get("tick"), int(row["tick"])) or int(change["tick"]) > max_tick:
				return false
			for key in ["before", "after"]:
				if not change.get(key) is String or change[key].length() > 256:
					return false
			reacted[int(change["receiver"])] = true
	return true

static func emit(world, emitter_id: int, symbol: int) -> bool:
	if not world.signal_enabled or symbol < 0 or symbol >= world.signal_count or not world.creatures.has(emitter_id):
		return false
	var emitter = world.creatures[emitter_id]
	if not emitter.alive or emitter.energy < world.signal_cost:
		return false
	var sensors: Dictionary = world.sense(emitter, false)
	var low_energy: bool = emitter.energy / emitter.max_energy < 0.35
	emitter.energy = snappedf(emitter.energy - world.signal_cost, 0.000001)
	var row := {"tick": world.tick, "emitter": emitter_id, "symbol": symbol,
		"context": {"saw_food": not sensors["foods"].is_empty(), "low_energy": low_energy},
		"receivers": [], "action_changes": []}
	var extent := Vector2.ONE * float(world.signal_range)
	var ids: Array = world._creature_grid.query(emitter.pos - extent, emitter.pos + extent)
	for receiver_id in ids:
		var receiver = world.creatures[receiver_id]
		var offset: Vector2 = emitter.pos - receiver.pos
		if receiver_id == emitter_id or not receiver.alive or offset.length() > world.signal_range:
			continue
		if world.signal_noise >= 1.0 or (world.signal_noise > 0.0 and world.rng.between(0.0, 1.0) < world.signal_noise):
			continue
		var angle := wrapf(offset.angle() - receiver.heading, -PI, PI)
		receiver.last_signal = {"tick": world.tick, "emitter": emitter_id, "symbol": symbol,
			"direction_bucket": 0 if angle < -0.25 else (2 if angle > 0.25 else 1),
			"distance_bucket": 0 if offset.length() <= world.signal_range * 0.5 else 1,
			"reacted": false, "before": receiver.last_action}
		row["receivers"].append(receiver_id)
	world.signal_log.append(row)
	if world.signal_log.size() > LOG_LIMIT:
		world.signal_log.pop_front()
	return true

## A change after reception is an observation, not a counterfactual causal claim.
static func record_reaction(world, creature) -> void:
	var heard: Dictionary = creature.last_signal
	if heard.is_empty() or heard["reacted"] or not world.signal_enabled or world.tick - int(heard["tick"]) > world.signal_ttl:
		return
	heard["reacted"] = true
	for index in range(world.signal_log.size() - 1, -1, -1):
		var row: Dictionary = world.signal_log[index]
		if int(row["tick"]) == int(heard["tick"]) and int(row["emitter"]) == int(heard["emitter"]) and creature.id in row["receivers"]:
			row["action_changes"].append({"receiver": creature.id, "tick": world.tick,
				"before": heard["before"], "after": creature.last_action})
			return
