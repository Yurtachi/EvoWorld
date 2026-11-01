extends SceneTree
# Benchmark de tempo de simulacao por tick. Uso:
# godot --headless --path . -s tests/experiments/perf_bench.gd
const World = preload("res://scripts/world/sim_world.gd")

func _init() -> void:
	print("criaturas | ms/tick medio | ms/tick p95 | TPS | vivos final")
	for n in [10, 30, 60, 100]:
		var w = World.new(7421, {"creature_count": n, "max_population": maxi(n, 100)})
		var times: Array = []
		for i in 600:
			var t0 := Time.get_ticks_usec()
			w.step()
			times.append((Time.get_ticks_usec() - t0) / 1000.0)
		times.sort()
		var sum := 0.0
		for t in times:
			sum += t
		var mean: float = sum / times.size()
		var p95: float = times[int(times.size() * 0.95)]
		print("%9d | %13.3f | %12.3f | %5.0f | %d" % [n, mean, p95, 1000.0 / mean, w.creatures.size()])
	quit(0)
