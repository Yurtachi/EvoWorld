extends SceneTree
## This evaluator is the only component that knows randomized hidden L/L2.
const Unit = preload("res://tests/unit/test_sim_p1b.gd")
const World = preload("res://scripts/world/sim_world.gd")
const Memory = preload("res://scripts/spatial/spatial_memory.gd")
const Policy = preload("res://scripts/spatial/spatial_policy.gd")
const Data = preload("res://scripts/core/sim_data.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const Strategy = preload("res://tests/experiments/p1b_strategy_world.gd")
const ARMS := ["treinado", "sem_memoria", "nao_treinado", "sistematico", "estrategia", "oraculo"]
const HORIZON := 180
var errors: Array = []

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var holdout := "--holdout" in args
	var output := "res://tests/experiments/p1b_holdout.json" if holdout else "res://tests/experiments/p1b_dev.json"
	if holdout:
		if not FileAccess.file_exists("res://tests/experiments/p1b_opened.json") or not FileAccess.file_exists("res://tests/experiments/p1b_freeze.json") or FileAccess.file_exists(output) or FileAccess.file_exists("res://tests/experiments/p1b_started.json"):
			printerr("P1b opening refused: use p1b_run.py after a committed freeze")
			quit(1)
			return
		var started := FileAccess.open("res://tests/experiments/p1b_started.json", FileAccess.WRITE)
		if started == null:
			quit(1)
			return
		started.store_string(FileAccess.get_file_as_string("res://tests/experiments/p1b_opened.json"))
		started.close()
	var first := 382401 if holdout else 382101
	var count := 24 if holdout else 6
	var result := {"mode": "holdout" if holdout else "dev", "rows": [], "checks": [], "errors": errors,
		"preregister_sha256": FileAccess.get_file_as_string("res://tests/experiments/p1b_preregistro.md").replace("\r\n", "\n").sha256_text(),
		"coverage": coverage(), "cpu": cpu(), "integrity_failures": Unit.new().run()}
	if not result.integrity_failures.is_empty(): errors.append("unit integrity failed")
	if holdout: result.freeze = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experiments/p1b_freeze.json"))
	for seed_value in range(first, first + count):
		var scenario := Rng.new(seed_value * 17)
		var location := Vector2(scenario.between(100, 800), scenario.between(100, 500))
		var richer := Vector2(scenario.between(100, 800), scenario.between(100, 500))
		while richer.distance_to(location) < 250:
			richer = Vector2(scenario.between(100, 800), scenario.between(100, 500))
		var starts: Array = []
		for i in 3:
			var start := Vector2(scenario.between(30, 870), scenario.between(30, 570))
			while start.distance_to(location) < 180:
				start = Vector2(scenario.between(30, 870), scenario.between(30, 570))
			starts.append(start)
		var trained = Unit.new().garden(seed_value)
		var acquisition := train(trained, location, "fruta", scenario)
		var pre: Dictionary = trained.to_dict()
		var last_place: Vector2 = Data.unpack_vector(acquisition.back().place)
		var loaded = World.from_dict(JSON.parse_string(JSON.stringify(pre, "", true, true)))
		if loaded == null:
			errors.append("save rejected seed " + str(seed_value))
			continue
		for arm in ARMS:
			for episode in 3:
				var w = Strategy.from_state(pre, last_place) if arm == "estrategia" else World.from_dict(pre)
				var c = w.creatures[w.pet_id]
				if arm in ["sem_memoria", "sistematico"]:
					c.mind.spatial.enabled = false
				if arm == "sistematico": c.mind.spatial.systematic = true
				if arm == "nao_treinado":
					c.mind = c.Mind.new(seed_value ^ (c.id * 104729))
					c.personality = c.Personality.new()
					c.enable_spatial_memory()
					Memory.enable_revision(c.mind.spatial)
				if arm == "oraculo":
					# Deliberate truth access confined to the reported ceiling arm.
					c.mind.spatial = Memory.empty(35.0)
					Memory.enable_revision(c.mind.spatial)
					Memory.evidence(c.mind.spatial, "comida", location, w.tick, true, 10000.0, "interagido")
					Memory.evidence(c.mind.spatial, "comida", location, w.tick, true, 10000.0, "interagido")
					Memory.evidence(c.mind.spatial, "comida", location, w.tick, true, 10000.0, "interagido")
				var row := episode_run(w, starts[episode], location, arm == "estrategia", last_place)
				row.merge({"seed": seed_value, "arm": arm, "phase": "A", "episode": episode, "L": Data.pack_vector(location), "training": acquisition}, false)
				result.rows.append(row)
		for episode in 3:
			var w = World.from_dict(loaded.to_dict())
			var row := episode_run(w, starts[episode], location)
			row.merge({"seed": seed_value, "arm": "treinado", "phase": "C", "episode": episode, "L": Data.pack_vector(location)}, false)
			result.rows.append(row)
		result.checks.append(revision_and_richer(pre, seed_value, location, richer, starts[0], scenario, last_place))
		print("P1b ", result.mode, " seed=", seed_value, " rows=", result.rows.size())
	result.errors = errors
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t", true, true))
	file.close()
	print("P1b written ", output, " errors=", errors.size())
	quit(0 if errors.is_empty() else 1)

func train(w, location: Vector2, food_type: String, scenario) -> Array:
	var trajectories: Array = []
	var c = w.creatures[w.pet_id]
	for episode in 8:
		w.foods.clear()
		var angle: float = scenario.between(-PI, PI)
		c.pos = location + Vector2.from_angle(angle) * scenario.between(25, 60)
		c.heading = (location - c.pos).angle()
		c.energy = 35.0 # Episode initial condition, never a cognitive consequence.
		c.mind.spatial.objetivo_atual = ""
		c.mind.spatial.arrival_tick = -1
		w.place_food(location, food_type)
		var trajectory: Array = [Data.pack_vector(c.pos)]
		var success := false
		for i in 40:
			w.step()
			trajectory.append(Data.pack_vector(c.pos))
			if c.last_action == "eat":
				success = true
				break
		if not success: errors.append("training ingestion failed seed=" + str(w.seed))
		trajectories.append({"success": success, "path": trajectory, "place": Data.pack_vector(location)})
	return trajectories

func reset_episode(w, start: Vector2, location: Vector2, food: bool = true) -> void:
	var c = w.creatures[w.pet_id]
	w.foods.clear()
	c.pos = start
	c.energy = 35.0
	c.heading = 0.0
	c.mind.spatial.objetivo_atual = ""
	c.mind.spatial.arrival_tick = -1
	c.mind.spatial.busca_indice = -1
	if food: w.place_food(location, "fruta")

func episode_run(w, start: Vector2, location: Vector2, strategy: bool = false, last_place: Vector2 = Vector2.ZERO) -> Dictionary:
	reset_episode(w, start, location)
	var c = w.creatures[w.pet_id]
	if not w.sense(c).foods.is_empty(): errors.append("visible start seed=" + str(w.seed))
	var path: Array = [Data.pack_vector(c.pos)]
	var length := 0.0
	var latency := HORIZON + 1
	var searches: int = c.mind.spatial.buscas
	var failures := total_failures(c.mind.spatial)
	for i in HORIZON:
		var previous: Vector2 = c.pos
		w.step()
		length += previous.distance_to(c.pos)
		path.append(Data.pack_vector(c.pos))
		if c.last_action == "eat":
			latency = i + 1
			break
	return {"success": latency <= HORIZON, "latency": latency, "path_length": length,
		"path_ratio": length / start.distance_to(location), "trajectory": path,
		"searches": int(c.mind.spatial.buscas) - searches, "failures": total_failures(c.mind.spatial) - failures,
		"memory": c.spatial_snapshot(), "alive": c.alive}

func total_failures(s: Dictionary) -> int:
	var total := 0
	for row in s.lugares: total += int(row.falhas)
	return total

func revision_trial(pre: Dictionary, location: Vector2, start: Vector2, strategy: bool, last_place: Vector2) -> Dictionary:
	var w = Strategy.from_state(pre, last_place) if strategy else World.from_dict(pre)
	var c = w.creatures[w.pet_id]
	var key := Memory.key_for("comida", location, 35.0)
	var visits: Array = []
	var entries := 0
	var completed := 0
	for attempt in 5:
		reset_episode(w, start, location, false)
		var before := total_failures(c.mind.spatial)
		var trajectory: Array = []
		var previous_inside := false
		var arrival := -1
		for i in HORIZON:
			w.step()
			trajectory.append(Data.pack_vector(c.pos))
			var inside: bool = c.pos.distance_to(location) < 25.0
			if inside and not previous_inside: entries += 1
			previous_inside = inside
			if c.pos.distance_to(location) <= c.genome.size + 5.0 and arrival < 0: arrival = i
			if (strategy and arrival >= 0 and i - arrival >= 16) or (not strategy and total_failures(c.mind.spatial) > before):
				completed += 1
				break
		visits.append({"attempt": attempt, "failures": completed, "expectation": 1.0 if strategy else Memory.find(c.mind.spatial, key).expectativa, "trajectory": trajectory})
	var after := total_failures(c.mind.spatial)
	var expectation_before_post: float = 1.0 if strategy else Memory.find(c.mind.spatial, key).expectativa
	var returns := 0
	var occupancy := 0
	var previous_inside: bool = c.pos.distance_to(location) < 25.0
	var post: Array = []
	c.energy = 35.0
	for i in HORIZON:
		w.step()
		var inside: bool = c.pos.distance_to(location) < 25.0
		if inside and not previous_inside: returns += 1
		if inside: occupancy += 1
		previous_inside = inside
		post.append(Data.pack_vector(c.pos))
	return {"B_visits": visits, "B_failures": completed, "B_entries": entries,
		"B_expectation": expectation_before_post, "B_post_expectation": 1.0 if strategy else Memory.find(c.mind.spatial, key).expectativa,
		"B_post_failures": total_failures(c.mind.spatial) - after, "B_returns": returns,
		"B_post_occupancy": occupancy, "B_post_trajectory": post}

func revision_and_richer(pre: Dictionary, seed_value: int, location: Vector2, richer: Vector2, start: Vector2, scenario, last_place: Vector2) -> Dictionary:
	var revised := revision_trial(pre, location, start, false, last_place)
	var strategy := revision_trial(pre, location, start, true, last_place)
	var rich_world = World.from_dict(pre)
	var rich_c = rich_world.creatures[rich_world.pet_id]
	var rich_training := train(rich_world, richer, "legacy", scenario)
	var midpoint := (location + richer) / 2.0
	var preference := Memory.best(rich_c.mind.spatial, "comida", midpoint, rich_world.tick)
	revised.merge({"seed": seed_value, "B_strategy": strategy,
		"D_preferred_L2": not preference.is_empty() and preference.id == Memory.key_for("comida", richer, 35.0),
		"L2": Data.pack_vector(richer), "D_training": rich_training, "D_memory": rich_c.spatial_snapshot()})
	return revised

func coverage() -> Dictionary:
	# The same sweep controller as all memory-free arms; finite body and real FOV.
	var w = Unit.new().garden(382090)
	var c = w.creatures[w.pet_id]
	var covered: Dictionary = {}
	var s := Memory.empty(35.0)
	var path: Array = []
	for i in 2000:
		var target := Policy.sweep(s, c.pos, 70.0, w.size)
		c.heading = (target - c.pos).angle()
		w._move(c, [])
		for y in 20:
			for x in 30:
				var point := Vector2((x + 0.5) * 30, (y + 0.5) * 30)
				if w._visible(c, point) and not w._occluded(c.pos, point): covered[str(x) + ":" + str(y)] = true
		path.append(Data.pack_vector(c.pos))
	return {"fraction": covered.size() / 600.0, "ticks": 2000, "trajectory": path,
		"note": "Geometric coverage diagnostic uses physical movement/FOV; no resource, no between-episode memory; metabolic survival evaluated separately in A."}

func cpu() -> Dictionary:
	var w = World.new_pet_world(382091, "P1b CPU")
	var c = w.creatures[w.pet_id]
	# Measure a full bounded table too, using actual local observations on a clone.
	for i in 64:
		Memory.evidence(c.mind.spatial, "comida", Vector2(20 + (i % 10) * 110, 20 + (i / 10) * 100), w.tick, true)
	var before := Time.get_ticks_usec()
	for i in 500: w.step()
	return {"ms_per_tick": (Time.get_ticks_usec() - before) / 500000.0, "ticks": 500,
		"places_initial": 64, "alive": w.creatures.has(w.pet_id)}
