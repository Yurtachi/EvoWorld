extends SceneTree
const Fixture = preload("res://tests/unit/test_sim_m2.gd")
const World = preload("res://scripts/world/sim_world.gd")
const Objects = preload("res://scripts/mind/object_memory.gd")
const Affect = preload("res://scripts/mind/affect.gd")
const PROTOCOL := "res://tests/experiments/m2_curiosity_preregistro.md"
const OUTPUT := "res://reports/M2_curiosidade_eval.json"
const ARMS := ["full", "no_memory", "no_affect", "no_curiosity", "random", "always", "never"]
const CONDITIONS := ["novel", "habituated", "neutral_history", "adverse_history", "enthusiasm", "fear"]
const FROZEN := ["scripts/world/sim_world.gd", "scripts/mind/creature_mind.gd", "scripts/mind/motivation.gd", "scripts/mind/object_memory.gd", "scripts/mind/affect.gd", "scripts/environment/object_catalog.gd", "scripts/behavior/personality.gd", "tests/unit/test_sim_m2.gd", "tests/experiments/m2_curiosity_eval.gd"]
var fixture = Fixture.new()

func checksum(path: String) -> String:
	return FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()

func write_result(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
	file.flush()
	file.close()

func acquire(seed_value: int, tipo: String):
	var w = fixture.garden(seed_value)
	var c = w.creatures[w.pet_id]
	var id: int = w.place_object(c.pos, tipo)
	for i in 8:
		w.tick += 181
		# Controlled acquisition: real contact, no metabolism between presentations.
		c.energy = c.max_energy * 0.9
		c.hydration = 90.0
		assert(w.interact_object(c, id))
	return w

func trial(seed_value: int, arm: String, condition: String, donors: Dictionary) -> Dictionary:
	var w = fixture.garden(seed_value)
	var c = w.creatures[w.pet_id]
	# Reserve the acquired instance ID; the test object always has a fresh ID.
	w.place_object(Vector2(1000, 600), "capsula_neutra")
	var target: int = w.place_object(c.pos + Vector2(24, 0), "capsula_neutra")
	w.tick = 2048
	if condition in ["habituated", "neutral_history", "adverse_history"]:
		var donor = donors.adverse if condition == "adverse_history" else donors.neutral
		c.mind.objects = donor.creatures[donor.pet_id].mind.objects.duplicate(true)
		if condition == "habituated": w.tick = donor.tick
	if condition in ["enthusiasm", "fear"]:
		var donor = donors.reward if condition == "enthusiasm" else donors.adverse
		c.mind.affect = Affect.from_dict(donor.creatures[donor.pet_id].mind.affect.to_dict(), w.tick)
	c.mind.memory_enabled = arm != "no_memory"
	c.mind.affect_enabled = arm != "no_affect"
	if arm == "random": c.mind.policy_mode = "random"
	Objects.state(c.mind).curiosity_enabled = arm != "no_curiosity"
	var actions: Dictionary = {}
	var goals: Dictionary = {}
	var first := 36
	var interactions := 0
	var initiative := false
	var roundtrip := true
	var initial_body := {"energy": c.energy, "hydration": c.hydration, "pos": [c.pos.x, c.pos.y], "affect": c.mind.affect.values.duplicate(true), "rng": c.mind.rng.to_dict()}
	for i in 36:
		if arm in ["always", "never"]:
			c.mind.objetivo_atual = "investigar_objeto" if arm == "always" else "descansar"
			c.mind.goal_started = w.tick + 1
			Objects.state(c.mind).target = target
		w.step()
		actions[c.last_action] = int(actions.get(c.last_action, 0)) + 1
		goals[c.mind.objetivo_atual] = int(goals.get(c.mind.objetivo_atual, 0)) + 1
		if c.last_action == "investigate_object":
			interactions += 1
			first = mini(first, i + 1)
			initiative = arm not in ["always", "never", "random"] and c.mind.mind_log.any(func(row): return row.motivo.begins_with("mind.iniciativa"))
		if i == 17:
			var before: String = fixture.snapshot(w)
			var loaded = World.from_dict(JSON.parse_string(before))
			roundtrip = loaded != null and fixture.snapshot(loaded) == before
			if loaded != null:
				w = loaded
				c = w.creatures[w.pet_id]
	return {"seed": seed_value, "arm": arm, "condition": condition, "interacted": interactions > 0, "initiative": initiative, "latency_censored": first, "interactions": interactions, "actions": actions, "goals": goals, "roundtrip": roundtrip, "initial_body": initial_body}

func summarize(rows: Array) -> Dictionary:
	var groups: Dictionary = {}
	for arm in ARMS:
		groups[arm] = {}
		for condition in CONDITIONS:
			var subset: Array = rows.filter(func(r): return r.arm == arm and r.condition == condition)
			var proportion := 0.0
			var latency := 0.0
			var initiative := 0.0
			for row in subset:
				proportion += (1.0 if row.interacted else 0.0) / subset.size()
				initiative += (1.0 if row.initiative else 0.0) / subset.size()
				latency += float(row.latency_censored) / subset.size()
			groups[arm][condition] = {"proportion": proportion, "initiative": initiative, "mean_latency_censored": latency}
	var full: Dictionary = groups.full
	var history := float(full.neutral_history.proportion) - float(full.adverse_history.proportion)
	var ablated_history := float(groups.no_memory.neutral_history.proportion) - float(groups.no_memory.adverse_history.proportion)
	var affect := float(full.enthusiasm.proportion) - float(full.fear.proportion)
	var ablated_affect := float(groups.no_affect.enthusiasm.proportion) - float(groups.no_affect.fear.proportion)
	var checks := {"H1_initiative": float(full.novel.initiative) >= 0.7,
		"H2_habituation": float(full.novel.proportion) - float(full.habituated.proportion) >= 0.25,
		"H3_memory_history": history >= 0.25,
		"H4_memory_ablation": history >= 0.25 and absf(ablated_history) <= absf(history) * 0.2,
		"H5_curiosity_ablation": float(full.novel.proportion) - float(groups.no_curiosity.novel.proportion) >= 0.25,
		"H6_affect_ablation": affect - ablated_affect >= 0.1,
		"roundtrips": rows.all(func(r): return r.roundtrip),
		"controls": float(groups.always.novel.proportion) > 0.999 and float(groups.never.novel.proportion) < 0.001}
	return {"groups": groups, "history_contrast": history, "history_without_memory": ablated_history, "affect_contrast": affect, "affect_without_affect": ablated_affect, "checks": checks, "scientific_status": "PASS" if checks.values().all(func(v): return v) else "PARTIAL"}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var holdout := "--holdout" in args
	var training := "--train" in args
	var path := OUTPUT if holdout else "res://reports/M2_curiosidade_train.json" if training else "res://reports/M2_curiosidade_dev.json"
	var seeds: Array = range(107301, 107325) if holdout else range(106101, 106105) if training else range(106201, 106207)
	if holdout and FileAccess.file_exists(path):
		printerr("Holdout ja aberto; resultado preservado")
		quit(2)
		return
	var frozen: Dictionary = {}
	for file in FROZEN: frozen[file] = checksum("res://" + file)
	var result := {"status": "opened", "split": "holdout" if holdout else "train" if training else "dev", "seeds": seeds, "preregister_sha256": checksum(PROTOCOL), "frozen_sha256": frozen, "godot": Engine.get_version_info(), "recovery_ticks_history": 600, "window": 36}
	write_result(path, result)
	var rows: Array = []
	for seed_value in seeds:
		var donors := {"neutral": acquire(seed_value, "capsula_neutra"), "adverse": acquire(seed_value, "capsula_aversiva"), "reward": acquire(seed_value, "capsula_agradavel")}
		for arm in ARMS:
			for condition in CONDITIONS:
				rows.append(trial(seed_value, arm, condition, donors))
	result["status"] = "complete"
	result["rows"] = rows
	result["summary"] = summarize(rows)
	write_result(path, result)
	print(JSON.stringify(result.summary))
	quit(0 if result.summary.checks.roundtrips else 1)
