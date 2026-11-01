extends RefCounted
## Non-learning control: uniformly random discrete action each tick (world-owned RNG).

const Actions = preload("res://scripts/behavior/actions.gd")
const KIND := "random"
const VERSION := 1

var last_reason: String = ""

func decide(_creature, _obs: Dictionary, rng) -> int:
	var action := clampi(int(rng.between(0.0, float(Actions.COUNT))), 0, Actions.COUNT - 1)
	last_reason = "Random control policy"
	return action

func on_death(_creature) -> void:
	pass

func copy():
	return load("res://scripts/behavior/random_brain.gd").new()

func to_dict() -> Dictionary:
	return {"kind": KIND, "version": VERSION}

static func from_dict(data: Dictionary):
	if data.get("kind") != KIND or data.get("version") != VERSION:
		return null
	return load("res://scripts/behavior/random_brain.gd").new()
