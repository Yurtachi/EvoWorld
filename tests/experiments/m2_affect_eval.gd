extends SceneTree
## M1b controlled factorial interventions, not an ecological generalization.
const World = preload("res://scripts/world/sim_world.gd")
const Fixture = preload("res://tests/unit/test_sim_m1.gd")
const Affect = preload("res://scripts/mind/affect.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Actions = preload("res://scripts/behavior/actions.gd")
const PROTOCOL := "res://tests/experiments/m2_affect_preregistro.md"
const RESULT := "res://reports/M1b_afeto_eval.json"
const ARMS := ["full", "no_affect", "no_memory", "neither", "random", "fixed"]
var fixture = Fixture.new()

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var holdout: bool = "--holdout" in args
	var train: bool = "--train" in args
	if holdout and FileAccess.file_exists(RESULT):
		printerr("M1b: HOLDOUT ja aberto; recusando nova abertura")
		quit(2)
		return
	var hash_protocol := FileAccess.get_file_as_string(PROTOCOL).replace("\r\n", "\n").sha256_text()
	if holdout: write_json(RESULT, {"status": "opened", "preregister_sha256": hash_protocol})
	var first := 94831 if holdout else (93601 if train else 93701)
	var count := 20 if holdout else (4 if train else 6)
	var x1: Array = []
	var x2: Array = []
	for seed_value in range(first, first + count):
		var donors := acquisition(seed_value)
		for arm in ARMS:
			for state in ["lonely", "saturated"]:
				for memory in ["positive", "negative"]:
					x1.append(social_trial(seed_value, arm, state, memory, donors))
		for arm in ["full", "no_affect", "no_memory", "neither"]:
			for state in ["blocked", "neutral"]:
				x2.append(block_trial(seed_value, arm, state))
		print("M1b seed ", seed_value, " concluida")
	var summary := summarize(x1, x2, count)
	var result := {"status": "completed", "partition": "HOLDOUT" if holdout else ("TRAIN" if train else "DEV"),
		"preregister_sha256": hash_protocol, "seed_start": first, "seeds": count,
		"x1": x1, "x2": x2, "summary": summary}
	result["frozen_files_sha256"] = {}
	for path in ["scripts/mind/motivation.gd", "scripts/mind/creature_mind.gd", "scripts/mind/affect.gd", "tests/experiments/m2_affect_eval.gd"]:
		result.frozen_files_sha256[path] = FileAccess.get_file_as_string("res://" + path).replace("\r\n", "\n").sha256_text()
	write_json(RESULT if holdout else ("res://builds/m2_affect_train.json" if train else "res://builds/m2_affect_dev.json"), result)
	print(JSON.stringify(summary, "\t", true, true))
	quit(0)

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Falha escrevendo ", path)
		quit(3)
		return
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
	file.flush()

func base(seed_value: int, with_peer: bool = true):
	var w = fixture.garden(seed_value)
	var pet = fixture.body(w, Vector2(200, 200))
	if with_peer:
		var genes = Genes.from_dict(pet.genome.to_dict())
		genes.temperament = {"curiosity": 0.0, "caution": 0.0, "sociability": 0.0, "impulsivity": 0.0}
		var peer = w.creatures[w.spawn_creature(Vector2(220, 200), "Vizinho", genes)]
		peer.energy = peer.max_energy
		peer.hydration = 100.0
	pet.energy = pet.max_energy * 0.9
	pet.hydration = 100.0
	w.enable_mind(pet.id)
	return w

func configure(mind, arm: String) -> void:
	mind.affect_enabled = arm not in ["no_affect", "neither", "fixed", "random"]
	mind.memory_enabled = arm not in ["no_memory", "neither", "fixed", "random"]
	mind.policy_mode = arm if arm in ["fixed", "random"] else "full"

func neighbor(w):
	for creature in w.creatures.values():
		if creature.id != w.pet_id: return creature
	return null

func acquisition(seed_value: int) -> Dictionary:
	var donors := {}
	for state in ["lonely", "saturated", "positive", "negative"]:
		var w = base(seed_value)
		var pet = w.creatures[w.pet_id]
		var peer = neighbor(w)
		if state == "lonely": peer.pos = Vector2(800, 600)
		if state in ["positive", "negative"]:
			w.tick = 39
			pet.energy = pet.max_energy * 0.6
			peer.energy = peer.max_energy * 0.6
			if state == "negative": w.place_food(Vector2(210, 200), "fruta")
		for i in (61 if state in ["positive", "negative"] else 100):
			w.tick += 1
			w._rebuild_spatial()
			pet.mind.observe(w, pet, w.sense(pet), false)
		donors[state] = pet.mind.to_dict().duplicate(true)
	return donors

func contact(w, pet, peer) -> bool:
	return pet.pos.distance_to(peer.pos) <= pet.genome.size + peer.genome.size + 8.0 and not w._occluded(pet.pos, peer.pos)

func social_trial(seed_value: int, arm: String, state: String, memory: String, donors: Dictionary) -> Dictionary:
	var w = base(seed_value)
	w.tick = 100
	var pet = w.creatures[w.pet_id]
	pet.mind.affect = Affect.from_dict(donors[state].affect, 100)
	pet.mind.experiences = donors[memory].experiences.duplicate(true)
	configure(pet.mind, arm)
	var contacts := 0
	var actions := {}
	var goals := {}
	var restored = null
	var exact := true
	for i in 36:
		w.step()
		contacts += int(contact(w, pet, neighbor(w)))
		actions[pet.last_action] = int(actions.get(pet.last_action, 0)) + 1
		goals[pet.mind.objetivo_atual] = int(goals.get(pet.mind.objetivo_atual, 0)) + 1
		if i == 17:
			restored = World.from_dict(JSON.parse_string(fixture.snapshot(w)))
			exact = restored != null
		elif i > 17 and restored != null: restored.step()
	if restored != null: exact = exact and fixture.snapshot(w) == fixture.snapshot(restored)
	return {"seed": seed_value, "arm": arm, "state": state, "memory": memory,
		"contact": contacts / 36.0, "actions": actions, "goals": goals, "persistence_exact": exact,
		"peer_displacement": neighbor(w).pos.distance_to(Vector2(220, 200)),
		"acquired_affect": donors[state].affect.values, "acquired_episodes": donors[memory].experiences}

func block_trial(seed_value: int, arm: String, state: String) -> Dictionary:
	var w = base(seed_value, false)
	var pet = w.creatures[w.pet_id]
	pet.pos = Vector2(206, 200)
	w.place_obstacle(Vector2(235, 200), 20.0)
	w._rebuild_spatial()
	var rejected := 0
	for i in 10:
		w.tick += 1
		if state == "blocked":
			pet.heading = 0.0
			rejected += int(not w._apply_action(pet, {}, Actions.FORWARD))
	# A memory-only path cannot explain this contrast; bodily acquisition is identical.
	pet.mind.experiences.clear()
	configure(pet.mind, arm)
	pet.mind.set_goal("explorar", w.tick, "mind.score")
	pet.heading = 0.0
	var peak := float(pet.mind.affect.values.frustracao)
	var first_switch := 12
	var retained := 0
	var actions := {}
	for i in 12:
		w.step()
		if pet.mind.objetivo_atual == "explorar": retained += 1
		elif first_switch == 12: first_switch = i
		peak = maxf(peak, float(pet.mind.affect.values.frustracao))
		actions[pet.last_action] = int(actions.get(pet.last_action, 0)) + 1
	w.obstacles.clear()
	for i in 96: w.step()
	return {"seed": seed_value, "arm": arm, "state": state, "rejected": rejected,
		"first_switch": first_switch, "switch_observed": first_switch < 12, "retained": retained, "actions": actions, "peak": peak,
		"recovered": float(pet.mind.affect.values.frustracao),
		"recovery_pass": float(pet.mind.affect.values.frustracao) <= peak * 0.5}

func summarize(x1: Array, x2: Array, count: int) -> Dictionary:
	var result := {"x1": {}, "x2": {}, "persistence_all": true, "stationary_peer_all": true}
	for arm in ARMS:
		var ae := 0.0
		var me := 0.0
		var ap := 0
		var mp := 0
		for seed_value in range(int(x1[0].seed), int(x1[0].seed) + count):
			var a := 0.0
			var m := 0.0
			for row in x1:
				if row.arm != arm or row.seed != seed_value: continue
				a += float(row.contact) * (0.5 if row.state == "lonely" else -0.5)
				m += float(row.contact) * (0.5 if row.memory == "positive" else -0.5)
				result.persistence_all = result.persistence_all and row.persistence_exact
				result.stationary_peer_all = result.stationary_peer_all and row.peer_displacement == 0.0
			ae += a / count
			me += m / count
			ap += int(a > 0.0)
			mp += int(m > 0.0)
		result.x1[arm] = {"affect_effect": ae, "memory_effect": me, "affect_positive": ap, "memory_positive": mp}
	var a: float = result.x1.full.affect_effect
	var m: float = result.x1.full.memory_effect
	result.x1["criteria"] = {
		"affect_magnitude": a >= 0.2 and result.x1.full.affect_positive >= ceili(count * 0.75),
		"memory_magnitude": m >= 0.1 and result.x1.full.memory_positive >= ceili(count * 0.75),
		"affect_ablation": a > 0.0 and absf(result.x1.no_affect.affect_effect) <= absf(a) * 0.2,
		"memory_ablation": m > 0.0 and absf(result.x1.no_memory.memory_effect) <= absf(m) * 0.2,
		"affect_specificity": a > 0.0 and result.x1.no_memory.affect_effect >= a * 0.5,
		"memory_specificity": m > 0.0 and result.x1.no_affect.memory_effect >= m * 0.5}
	for arm in ["neither", "random", "fixed"]:
		result.x1.criteria[arm + "_control"] = absf(result.x1[arm].affect_effect) <= 0.05 and absf(result.x1[arm].memory_effect) <= 0.05
	for arm in ["full", "no_affect", "no_memory", "neither"]:
		var effect := 0.0
		var positive := 0
		var recovery := 0
		for row in x2:
			if row.arm != arm or row.state != "blocked": continue
			for other in x2:
				if other.arm == arm and other.state == "neutral" and other.seed == row.seed:
					var delta := float(other.first_switch) - float(row.first_switch)
					effect += delta / count
					positive += int(delta >= 4.0)
			recovery += int(row.recovery_pass)
		result.x2[arm] = {"shortening_ticks": effect, "at_least_four": positive, "recovery": recovery}
	var f: float = result.x2.full.shortening_ticks
	result.x2["criteria"] = {"shortening": f >= 4.0 and result.x2.full.at_least_four >= ceili(count * 0.75),
		"affect_ablation": f > 0.0 and absf(result.x2.no_affect.shortening_ticks) <= absf(f) * 0.2,
		"memory_specificity": f > 0.0 and result.x2.no_memory.shortening_ticks >= f * 0.75,
		"recovery": result.x2.full.recovery >= ceili(count * 0.9)}
	var passed: bool = result.persistence_all and result.stationary_peer_all
	for group in [result.x1.criteria, result.x2.criteria]:
		for value in group.values(): passed = passed and value
	result["scientific_status"] = "PASS" if passed else "PARTIAL"
	return result
