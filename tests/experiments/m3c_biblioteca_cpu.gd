extends SceneTree
const World = preload("res://scripts/world/sim_world.gd")
func _init():
	var rows: Array = []
	for population in [12,30,60,100]:
		var w = World.new(140050, {"creature_count": population, "mind_all": true, "personality_enabled": true, "food_count": 80, "water_count": 3, "water_enabled": true, "reproduction_enabled": false})
		for c in w.creatures.values():
			if w.library.books.size() < 32: w.place_book(c.pos + Vector2(15,0), "guia_capsulas")
			w.place_object(c.pos + Vector2(25,0), "capsula_aversiva")
		for i in range(30): w.step()
		var samples: Array = []
		for i in range(240):
			var start: int = Time.get_ticks_usec()
			w.step()
			samples.append(float(Time.get_ticks_usec()-start)/1000.0)
		samples.sort()
		rows.append({"population": population, "ticks": 240, "median_ms": samples[120], "p95_ms": samples[228], "max_ms": samples[-1]})
		print(rows[-1])
	var f := FileAccess.open("res://reports/M3c_biblioteca_cpu.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"seed": 140050, "rows": rows},"\t") + "\n")
	f.close()
	quit()
