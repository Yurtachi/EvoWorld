extends SceneTree
const World = preload("res://scripts/world/sim_world.gd")
func _init() -> void:
	var rows: Array = []
	for count in [12, 30, 60]:
		for scope in ["off", "pet", "all"]:
			var config := {"creature_count": count, "max_population": count, "reproduction_enabled": false}
			if scope == "off": config["mind_enabled_ids"] = []
			if scope == "all": config["mind_all"] = true
			var w = World.new_world(81006, config)
			for i in 100: w.step()
			var samples: Array = []
			for i in 400:
				var start := Time.get_ticks_usec()
				w.step()
				samples.append((Time.get_ticks_usec() - start) / 1000.0)
			var mean := 0.0
			for sample in samples: mean += float(sample) / samples.size()
			samples.sort()
			var row := {"population_initial": count, "scope": scope, "mean_ms_tick": mean, "p95_ms_tick": samples[int(samples.size() * 0.95)], "population_final": w.creatures.size(), "minds_final": w.mind_enabled_ids.size()}
			rows.append(row)
			print(JSON.stringify(row))
	var file := FileAccess.open("res://reports/M1_mind_cpu.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": 81006, "warmup": 100, "measured_ticks": 400, "godot": Engine.get_version_info(), "rows": rows}, "\t", true, true) + "\n")
	quit(0)
