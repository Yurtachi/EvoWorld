extends "res://scripts/world/sim_world.gd"
## Evaluation-only strategy: one remembered ingestion, without revision.
var last_food_place := Vector2.ZERO

static func from_state(state: Dictionary, last_ingestion: Vector2):
	var source = load("res://scripts/world/sim_world.gd").from_dict(state)
	if source == null: return null
	var result = load("res://tests/experiments/p1b_strategy_world.gd").new(1, {"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0})
	# Transfer the independently decoded world state to the subclass. There is
	# no insertion of synthetic evidence and no alteration of physical state.
	for property in source.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name not in ["feeding_mode", "pending_questions", "galeria", "quadros"]:
			result.set(property.name, source.get(property.name))
	assert(result.to_dict() == source.to_dict())
	result.last_food_place = last_ingestion
	result.creatures[result.pet_id].mind.spatial.enabled = false
	return result

func _spatial_seek(creature: Creature, sensors: Dictionary, resource: String) -> bool:
	if resource != "comida": return super._spatial_seek(creature, sensors, resource)
	# Visible food is handled by the parent's seek/eat before this fallback.
	if creature.pos.distance_to(last_food_place) <= creature.genome.size + 5.0:
		creature.last_action = "inspect_place"
		creature.heading += TAU / 16.0
		return false
	creature.heading = (last_food_place - creature.pos).angle()
	creature.last_action = "seek_place"
	return _move(creature, sensors.get("obstacles", []))
