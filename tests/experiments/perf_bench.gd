extends SceneTree
## E5 product worlds. -- --sizes measures 20000 ticks/save sizes; default CPU 5000.
const World = preload("res://scripts/world/sim_world.gd")
const Store = preload("res://scripts/persistence/save_store.gd")

func _init() -> void:
	var sizes := "--sizes" in OS.get_cmdline_user_args()
	var rows: Array = []
	var failed := false
	for n in ([12, 60, 150] if sizes else [12, 30, 60, 100]):
		var w = World.new_world(7421, {"creature_count": n, "max_population": 150, "signal_enabled": true})
		var memory_start := OS.get_static_memory_usage()
		var memory_samples: Array = []
		var times: Array = []
		var population_min: int = w.creatures.size()
		var population_max := population_min
		var ticks := 20000 if sizes else 5000
		for i in ticks:
			var t0 := Time.get_ticks_usec()
			w.step()
			times.append((Time.get_ticks_usec() - t0) / 1000.0)
			population_min = mini(population_min, w.creatures.size())
			population_max = maxi(population_max, w.creatures.size())
			if (i + 1) % 1000 == 0:
				memory_samples.append({"tick": i + 1, "bytes": OS.get_static_memory_usage(), "alive": w.creatures.size()})
				print("progress n=%d tick=%d alive=%d" % [n, i + 1, w.creatures.size()])
		times.sort()
		var sum := 0.0
		for t in times:
			sum += t
		var mean: float = sum / times.size()
		var snapshot: Dictionary = w.to_dict()
		var restored = World.from_dict(JSON.parse_string(JSON.stringify(snapshot, "", true, true)))
		var valid: bool = restored != null and JSON.stringify(restored.to_dict(), "", true, true) == JSON.stringify(snapshot, "", true, true)
		if not valid:
			for label in ["original", "restored"]:
				var evidence := FileAccess.open("res://reports/E5_roundtrip_%d_%s.json" % [n, label], FileAccess.WRITE)
				evidence.store_string(JSON.stringify(snapshot if label == "original" else (restored.to_dict() if restored != null else {}), "", true, true))
				evidence.close()
		var save := Store.new("user://e5_bench").save_world(w, "population_%d" % n)
		var bytes := 0
		if save.ok:
			var file := FileAccess.open(save.path, FileAccess.READ)
			bytes = file.get_length()
			file.close()
		else: failed = true
		failed = failed or not valid
		var generation := 0
		for record in w.genealogy.records.values(): generation = maxi(generation, record.generation)
		var row := {"initial": n, "ticks": ticks, "seed": 7421, "mean_ms": mean,
			"p95_ms": times[ceili(times.size() * 0.95) - 1], "memory_start_bytes": memory_start,
			"memory_end_bytes": OS.get_static_memory_usage(), "memory_samples": memory_samples,
			"population_min": population_min, "population_max": population_max, "alive": w.creatures.size(),
			"genealogy": w.genealogy.records.size(), "generation": generation, "save_bytes": bytes,
			"roundtrip": valid, "save_ok": save.ok}
		rows.append(row)
		print(JSON.stringify(row))
	var result := {"engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(),
		"mode": "sizes" if sizes else "cpu", "rows": rows, "ok": not failed}
	var output := FileAccess.open("res://reports/E5_%s.json" % ("sizes" if sizes else "perf"), FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t", true, true))
	output.close()
	quit(1 if failed else 0)
