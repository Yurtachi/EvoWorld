extends SceneTree
## Local headless benchmark; exhaustive reference reproduces pre-grid perception.
const World = preload("res://scripts/world/sim_world.gd")

class ExhaustiveWorld extends World:
	func _rebuild_spatial() -> void:
		pass
	func sense(creature: Creature, _include_creatures: bool = true) -> Dictionary:
		var result := {"foods": [], "creatures": [], "obstacles": [], "hunger": creature.hunger}
		for food in foods:
			if _visible(creature, food["pos"]) and not _occluded(creature.pos, food["pos"]):
				result["foods"].append(food.duplicate(true))
		for other in creatures.values():
			if other.id != creature.id and _visible(creature, other.pos) and not _occluded(creature.pos, other.pos):
				result["creatures"].append({"id": other.id, "pos": other.pos})
		for obstacle in obstacles:
			if _visible(creature, obstacle["pos"]):
				result["obstacles"].append(obstacle.duplicate(true))
		return result
	func _occluded(start: Vector2, finish: Vector2, margin: float = 0.0) -> bool:
		for obstacle in obstacles:
			if _segment_hits(start, finish, obstacle["pos"], obstacle["radius"] + margin):
				return true
		return false

func _init() -> void:
	for count in [30, 100, 300, 1000]:
		var config := {"creature_count": count, "max_population": count, "reproduction_enabled": false, "food_count": 80, "obstacle_count": 8}
		var indexed := World.new(17431, config)
		var reference := ExhaustiveWorld.new(17431, config)
		var started := Time.get_ticks_usec()
		for index in range(20): indexed.step()
		var indexed_ms := (Time.get_ticks_usec() - started) / 20000.0
		started = Time.get_ticks_usec()
		for index in range(20): reference.step()
		var exhaustive_ms := (Time.get_ticks_usec() - started) / 20000.0
		var equal := JSON.stringify(indexed.to_dict(), "", true, true) == JSON.stringify(reference.to_dict(), "", true, true)
		print("creatures=%d indexed_ms=%.3f exhaustive_ms=%.3f equal_snapshot=%s" % [count, indexed_ms, exhaustive_ms, equal])
		if not equal:
			quit(1)
			return
	quit(0)
