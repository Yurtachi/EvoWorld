extends RefCounted
## Non-learning control: uniformly random discrete action each tick (world-owned RNG).

const Actions = preload("res://scripts/behavior/actions.gd")
const Data = preload("res://scripts/core/sim_data.gd")
const KIND := "random"
const VERSION := 1

var last_reason: String = ""

func decide(_creature, obs: Dictionary, rng) -> int:
	var count: int = obs.get("action_count", Actions.COUNT)
	var allowed: Array = obs.get("allowed_actions", [])
	var action: int
	if allowed.is_empty():
		action = clampi(int(rng.between(0.0, float(count))), 0, count - 1)
	else:
		action = int(allowed[clampi(int(rng.between(0.0, float(allowed.size()))), 0, allowed.size() - 1)])
	last_reason = "brain.random"
	return action

func on_death(_creature) -> void:
	pass

func copy():
	return load("res://scripts/behavior/random_brain.gd").new()

func to_dict() -> Dictionary:
	return {"kind": KIND, "version": VERSION}

static func from_dict(data: Dictionary):
	if not data.get("kind") is String or data["kind"] != KIND or not Data.integer(data.get("version")) or int(data["version"]) != VERSION:
		return null
	return load("res://scripts/behavior/random_brain.gd").new()
