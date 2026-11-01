extends RefCounted
## E4 uses E2's bounded bonds and episodes. No inherited or UI-owned social state.
const P = preload("res://scripts/behavior/personality.gd")

static func relation(personality, other_id: int) -> Dictionary:
	var bond: Dictionary = personality.bonds.get(str(other_id), {})
	return {"id": other_id, "encounters": int(bond.get("count", 0)),
		"familiarity": float(bond.get("familiarity", 0.0)),
		"affinity": maxf(0.0, float(bond.get("valence", 0.0))),
		"aversion": maxf(0.0, -float(bond.get("valence", 0.0))),
		"last_tick": int(bond.get("last_tick", -1))}

static func contested(creature, other, sensors: Dictionary) -> Dictionary:
	for food in sensors.get("foods", []):
		if creature.pos.distance_to(food.pos) <= 48.0 and other.pos.distance_to(food.pos) <= 48.0:
			return food
	return {}

static func decide(world, creature, sensors: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var highest := 0.32
	for row in sensors.get("creatures", []):
		var other = world.creatures.get(int(row.id))
		if other == null or not other.alive:
			continue
		var bond := relation(creature.personality, other.id)
		var distance: float = creature.pos.distance_to(other.pos)
		var food := contested(creature, other, sensors)
		var choices: Array = []
		choices.append({"action": "social_avoid", "drive": bond.aversion * (0.5 + float(creature.temperament.caution)), "target": creature.pos + (creature.pos - other.pos).normalized() * 40.0})
		var contact: float = creature.personality.loneliness * (0.2 + 1.1 * float(creature.temperament.sociability)) * (1.0 - bond.aversion)
		choices.append({"action": "social_follow" if bond.familiarity >= 0.12 else "social_approach", "drive": contact, "target": other.pos})
		if not food.is_empty():
			# Sharing means yielding access. The peer must still reach and eat it.
			choices.append({"action": "social_share", "drive": bond.affinity * other.hunger * (1.0 - creature.hunger) * 2.0, "target": creature.pos + (creature.pos - food.pos).normalized() * 24.0})
			choices.append({"action": "social_compete", "drive": creature.hunger * (0.5 + float(creature.temperament.impulsivity)) * (1.0 - bond.affinity * 0.5), "target": food.pos, "food_id": food.id})
		for choice in choices:
			if float(choice.drive) > highest:
				highest = choice.drive
				best = choice.duplicate(true)
				best["other_id"] = other.id
				best["distance"] = distance
	return best

static func encounter(world, creature, other, sensors: Dictionary) -> void:
	var food := contested(creature, other, sensors)
	var competing: bool = not food.is_empty() and creature.hunger > 0.2 and other.hunger > 0.2
	var valence := -0.5 if competing else 0.25
	if creature.personality.meet(str(other.id), world.tick, valence):
		creature.personality.record(world.tick, P.context(creature), "social_contact", 0.0, 0.0, 0.0,
			"resource_contention" if competing else "contact", "encounter")
