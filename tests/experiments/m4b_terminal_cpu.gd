extends SceneTree
const World = preload("res://scripts/world/sim_world.gd")

func _init() -> void:
	var rows: Array = []
	for population in [12, 30, 60, 100]:
		for enabled in [false, true]:
			var w = World.new(154301, {"creature_count": population, "personality_enabled": true, "mind_all": true,
				"food_count": 100, "obstacle_count": 0, "reproduction_enabled": false, "water_enabled": true})
			if enabled:
				# Bounded 16 terminals; shared by nearby creatures.
				for c in w.creatures.values().slice(0, 16): w.place_terminal(c.pos)
			for i in range(40): w.step()
			var samples: Array = []
			var maximum_actions := 0
			for i in range(200):
				var begin := Time.get_ticks_usec()
				w.step()
				samples.append(float(Time.get_ticks_usec() - begin) / 1000.0)
				var actions := 0
				for c in w.creatures.values():
					if c.mind != null and not c.mind.terminal.is_empty() and int(c.mind.terminal.last_tick) == w.tick: actions += 1
				maximum_actions = maxi(maximum_actions, actions)
			var sorted := samples.duplicate()
			sorted.sort()
			var total := 0.0
			for value in samples: total += float(value)
			rows.append({"population": population, "terminal": enabled, "mean_ms": total / samples.size(), "p95_ms": sorted[int(ceil(sorted.size() * 0.95)) - 1],
				"samples_ms": samples, "alive": w.creatures.size(), "terminals": w.terminals.size(), "max_terminal_actions_per_tick": maximum_actions})
			print("M4b CPU ", population, " terminal=", enabled, " mean_ms=", total / samples.size())
	DirAccess.make_dir_recursive_absolute("builds")
	var path := "builds/m4b_cpu.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"seed": 154301, "warmup": 40, "ticks": 200, "rows": rows}, "\t", true, true) + "\n")
	file.flush()
	quit(0)
