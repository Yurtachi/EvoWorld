extends SceneTree
## M3 CPU benchmark with active drawing board at 12, 30, 60, and 100 creatures.
## Compares mind disabled (mind_off) vs mind enabled only on the pet (pet_only, default).
const World = preload("res://scripts/world/sim_world.gd")
const OUTPUT := "res://reports/M3_atelie_cpu.json"
const COUNTS := [12, 30, 60, 100]
const TICKS := 300

func measure(creature_count: int, pet_mind: bool) -> Dictionary:
	var config := {
		"creature_count": creature_count,
		"max_population": maxi(150, creature_count + 20),
		"reproduction_enabled": false,
		"mind_enabled_ids": []
	}
	var w := World.new_world(118900 + creature_count, config)
	if pet_mind and w.pet_id != -1:
		w.enable_mind(w.pet_id)
	var pet = w.creatures.get(w.pet_id)
	var board_id := -1
	if pet != null:
		board_id = w.place_board(pet.pos + Vector2(20, 0))
		if board_id != -1:
			w.demonstrar_forma(board_id, "circulo", {"center": Vector2(32, 32), "scale": 1.0, "dir_offset": 0})
	var samples_usec: Array = []
	for t in range(TICKS):
		if pet != null and pet.alive:
			pet.energy = pet.max_energy * 0.9
			pet.hydration = 90.0
		var t0 := Time.get_ticks_usec()
		w.step()
		var elapsed := Time.get_ticks_usec() - t0
		samples_usec.append(elapsed)
	samples_usec.sort()
	var sum_usec := 0
	for s in samples_usec:
		sum_usec += int(s)
	var mean_ms := snappedf((float(sum_usec) / float(TICKS)) / 1000.0, 0.0001)
	var p50_ms := snappedf(float(samples_usec[TICKS / 2]) / 1000.0, 0.0001)
	var p95_ms := snappedf(float(samples_usec[int(TICKS * 0.95)]) / 1000.0, 0.0001)
	return {
		"creature_count": creature_count,
		"mode": "pet_only_with_board" if pet_mind else "mind_off_with_board",
		"active_minds": w.mind_enabled_ids.size(),
		"boards": w.boards.size(),
		"gallery_artifacts": w.gallery.size(),
		"ticks": TICKS,
		"mean_ms_per_tick": mean_ms,
		"p50_ms_per_tick": p50_ms,
		"p95_ms_per_tick": p95_ms
	}

func _init() -> void:
	var rows: Array = []
	for n in COUNTS:
		var off := measure(n, false)
		var pet := measure(n, true)
		var delta_ms := snappedf(float(pet.mean_ms_per_tick) - float(off.mean_ms_per_tick), 0.0001)
		rows.append({
			"population": n,
			"mind_off": off,
			"pet_only": pet,
			"delta_mean_ms": delta_ms
		})
	var report := {
		"experiment": "M3_atelie_cpu",
		"ticks_per_run": TICKS,
		"populations": COUNTS,
		"godot": Engine.get_version_info(),
		"rows": rows
	}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	file.flush()
	file.close()
	print(JSON.stringify(report))
	quit(0)
