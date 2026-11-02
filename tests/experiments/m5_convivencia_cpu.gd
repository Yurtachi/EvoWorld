extends SceneTree
const World = preload("res://scripts/world/sim_world.gd")

func _init() -> void:
	var rows: Array = []
	for population in [12, 30, 60, 100]:
		for mind_active in [false, true]:
			var w = World.new(151301, {
				"creature_count": population,
				"personality_enabled": true,
				"mind_all": mind_active,
				"reproduction_voluntary": true,
				"mind_offspring": mind_active,
				"food_count": 80,
				"obstacle_count": 0,
				"reproduction_enabled": true,
				"water_enabled": true
			})
			for i in range(40):
				w.step()
			var samples: Array = []
			for i in range(200):
				var begin := Time.get_ticks_usec()
				w.step()
				samples.append(float(Time.get_ticks_usec() - begin) / 1000.0)

			var sorted := samples.duplicate()
			sorted.sort()
			var total := 0.0
			for val in samples:
				total += float(val)
			var mean_ms: float = total / float(samples.size())
			var median_ms: float = float(sorted[int(sorted.size() * 0.5)])
			var p95_ms: float = float(sorted[int(ceil(sorted.size() * 0.95)) - 1])
			var ticks_per_sec: float = 1000.0 / mean_ms if mean_ms > 0.0001 else 99999.0

			rows.append({
				"population": population,
				"mind_active": mind_active,
				"mean_ms": mean_ms,
				"median_ms": median_ms,
				"p95_ms": p95_ms,
				"ticks_per_sec": ticks_per_sec,
				"alive": w.creatures.size()
			})
			print("M5 CPU pop=", population, " mind=", mind_active, " mean_ms=", snappedf(mean_ms, 0.001), " tps=", snappedf(ticks_per_sec, 0.1))

	DirAccess.make_dir_recursive_absolute("reports")
	DirAccess.make_dir_recursive_absolute("builds")
	var result_data := {
		"seed": 151301,
		"warmup": 40,
		"ticks": 200,
		"rows": rows
	}
	var content := JSON.stringify(result_data, "\t", true, true) + "\n"
	var file := FileAccess.open("reports/M5_convivencia_cpu.json", FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.flush()
		file.close()

	var file2 := FileAccess.open("builds/m5_cpu.json", FileAccess.WRITE)
	if file2 != null:
		file2.store_string(content)
		file2.flush()
		file2.close()

	quit(0)
