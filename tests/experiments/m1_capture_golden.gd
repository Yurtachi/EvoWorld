extends SceneTree
const World = preload("res://scripts/world/sim_world.gd")
func _init() -> void:
	var cases: Array = []
	for profile in [false, true]:
		var w = World.new(7823, {"creature_count": 4, "food_count": 12, "obstacle_count": 3, "personality_enabled": profile, "water_enabled": profile, "water_count": 2 if profile else 0, "reproduction_enabled": false})
		var initial: Dictionary = w.to_dict()
		for i in range(100):
			w.step()
		cases.append({"initial": initial, "after100": w.to_dict()})
	var file = FileAccess.open("res://tests/experiments/m1_golden.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(cases, "\t", true, true) + "\n")
	quit(0)
