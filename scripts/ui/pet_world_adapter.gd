extends RefCounted
## Thin product boundary; all feeding, stock and physiology belong to SimWorld.
const World = preload("res://scripts/world/sim_world.gd")

func create(seed_value: int, pet_name: String, ecosystem: bool = false, population: int = 12):
	if ecosystem:
		return World.new_ecosystem_world(seed_value, {"creature_count": population})
	return World.new_pet_world(seed_value, pet_name)

func set_mode(world, value: String) -> bool:
	return world.set_feeding_mode(value)

func feeders(world) -> Array:
	return world.feeders

func current_mode(world) -> String:
	return world.feeding_mode
