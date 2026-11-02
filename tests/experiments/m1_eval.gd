extends SceneTree
## M1 X1/X2. Original deterministic physical fixtures; no external code.
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Motivation = preload("res://scripts/mind/motivation.gd")
const PROTOCOL := "res://tests/experiments/m1_preregistro.md"
const RESULT := "res://reports/M1_mind_eval.json"
const ARMS := ["full", "no_affect", "no_memory", "random", "fixed"]

func _init() -> void:
	var holdout: bool = "--holdout" in OS.get_cmdline_user_args()
	if holdout and FileAccess.file_exists(RESULT):
		printerr("M1: HOLDOUT ja aberto; recusando segunda abertura")
		quit(2)
		return
	var protocol_hash := FileAccess.get_file_as_string(PROTOCOL).replace("\r\n", "\n").sha256_text()
	if holdout:
		# Durable marker before any holdout trial; even a failed process stays opened.
		write_json(RESULT, {"status": "opened", "preregister_sha256": protocol_hash})
	var start := 82401 if holdout else 81001
	var count := 20 if holdout else 6
	var x1: Array = []
	var x2: Array = []
	for world_seed in range(start, start + count):
		for arm in ARMS:
			for profile in ["A", "B"]:
				x1.append(social_trial(world_seed, arm, profile))
		for arm in ["full", "no_affect"]:
			x2.append(frustration_trial(world_seed, arm))
		print("M1 seed ", world_seed, " concluida")
	var result := {"status": "completed", "partition": "HOLDOUT" if holdout else "DEV", "preregister_sha256": protocol_hash,
		"seed_start": start, "seeds": count, "x1": x1, "x2": x2, "summary": summarize(x1, x2, count),
		"limitations": ["Perfis diferem em temperamento e experiencia: divergencia nao isola aprendizagem", "X2 intervem no objetivo por ensino durante o bloqueio; scores mentais sao observados mas nao controlam essas tentativas", "Probabilidades X2 sao softmax dos scores, nao probabilidades empiricas da politica com compromisso"]}
	write_json(RESULT if holdout else "res://builds/m1_dev.json", result)
	print(JSON.stringify(result.summary, "\t", true, true))
	quit(0)

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("M1: falha escrevendo ", path)
		quit(3)
		return
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")

func garden(world_seed: int):
	return World.new(world_seed, {"creature_count": 0, "food_count": 0, "obstacle_count": 0, "water_count": 0,
		"food_regrow": false, "reproduction_enabled": false, "personality_enabled": true, "water_enabled": true})

func genes(sociability: float, caution: float, neighbor: bool = false):
	var g := Genes.new()
	g.size = 8.0
	g.speed = 30.0
	g.metabolism = 1.0
	g.vision_range = 180.0
	g.vision_fov = snappedf(TAU, 0.000001)
	g.temperament = {"curiosity": 0.0 if neighbor else 0.5, "caution": caution,
		"sociability": sociability, "impulsivity": 0.0 if neighbor else 0.5}
	return g

func configure(mind, arm: String) -> void:
	mind.affect_enabled = arm not in ["no_affect", "fixed", "random"]
	mind.memory_enabled = arm not in ["no_memory", "fixed", "random"]
	mind.policy_mode = arm if arm in ["fixed", "random"] else "full"

func in_contact(w, a, b) -> bool:
	return a.pos.distance_to(b.pos) <= a.genome.size + b.genome.size + 8.0 and not w._occluded(a.pos, b.pos)

func social_trial(world_seed: int, arm: String, profile: String) -> Dictionary:
	var w = garden(world_seed)
	var pet_id: int = w.spawn_creature(Vector2(200, 200), "M1", genes(0.9 if profile == "A" else 0.2, 0.2 if profile == "A" else 0.9))
	w.pet_id = pet_id
	var peer_id: int = w.spawn_creature(Vector2(220, 200), "Vizinho", genes(0.0, 0.0, true))
	var pet = w.creatures[pet_id]
	var peer = w.creatures[peer_id]
	pet.heading = 0.0
	peer.heading = PI
	w.enable_mind(pet_id)
	configure(pet.mind, arm)
	# Acquisition is 30 physically verified encounter observations, no locomotion.
	# B experiences resource contention; A observes the same contact without it.
	pet.energy = pet.max_energy * 0.6
	peer.energy = peer.max_energy * 0.6
	if profile == "B": w.place_food(Vector2(210, 200), "fruta")
	for i in 30:
		w.tick += 1
		w._rebuild_spatial()
		var sensors: Dictionary = w.sense(pet)
		w._personality_encounters(pet, sensors)
		pet.mind.observe(w, pet, sensors, false)
	var acquired: Dictionary = pet.mind.to_dict()
	w.foods.clear()
	# Same physical resources and threats throughout evaluation, all arms.
	pet.energy = pet.max_energy * 0.9
	pet.hydration = 100.0
	peer.energy = peer.max_energy
	peer.hydration = 100.0
	pet.personality.fatigue = 0.0
	peer.personality.fatigue = 0.0
	var contacts := 0
	var first_half := 0
	var second_half := 0
	var copy_contacts := 0
	var restored = null
	var persistence_ok := true
	var actions: Dictionary = {}
	var objectives: Dictionary = {}
	for i in 240:
		w.step()
		pet = w.creatures[pet_id]
		peer = w.creatures[peer_id]
		var contact := in_contact(w, pet, peer)
		contacts += int(contact)
		if i < 120: first_half += int(contact)
		else: second_half += int(contact)
		actions[pet.last_action] = int(actions.get(pet.last_action, 0)) + 1
		objectives[pet.mind.objetivo_atual] = int(objectives.get(pet.mind.objetivo_atual, 0)) + 1
		if i == 119:
			restored = World.from_dict(JSON.parse_string(JSON.stringify(w.to_dict(), "", true, true)))
			persistence_ok = restored != null
		elif i > 119 and restored != null:
			restored.step()
			copy_contacts += int(in_contact(restored, restored.creatures[pet_id], restored.creatures[peer_id]))
	if restored != null:
		persistence_ok = persistence_ok and JSON.stringify(w.to_dict(), "", true, true) == JSON.stringify(restored.to_dict(), "", true, true) and second_half == copy_contacts
	return {"seed": world_seed, "arm": arm, "profile": profile, "contact_fraction": contacts / 240.0,
		"first_half": first_half / 120.0, "second_half": second_half / 120.0, "persistence_exact": persistence_ok,
		"acquired_memories": acquired.experiences.size(), "acquired_affect": acquired.affect.values,
		"final_affect": pet.mind.affect.values.duplicate(), "actions": actions, "objectives": objectives,
		"peer_displacement": peer.pos.distance_to(Vector2(220, 200)), "final_distance": pet.pos.distance_to(peer.pos)}

func probability(scores: Dictionary, goal: String) -> float:
	var total := 0.0
	for key in scores: total += exp(float(scores[key]))
	return exp(float(scores[goal])) / total

func measurements(pet) -> Dictionary:
	var base: Dictionary = pet.personality.expression(pet)
	var expression: Dictionary = pet.expression_state()
	var probs: Dictionary = {}
	for goal in ["explorar", "brincar", "descansar"]:
		probs[goal] = probability(pet.mind.pontuacoes, goal)
	return {"frustracao": float(pet.mind.affect.values.frustracao), "expressao": expression,
		"affective_valence": float(expression.valence) - float(base.valence), "probabilidades": probs,
		"objetivo": pet.mind.objetivo_atual}

func frustration_trial(world_seed: int, arm: String) -> Dictionary:
	var w = garden(world_seed)
	var pet_id: int = w.spawn_creature(Vector2(206, 200), "M1", genes(0.5, 0.5))
	w.pet_id = pet_id
	var pet = w.creatures[pet_id]
	pet.heading = 0.0
	pet.energy = pet.max_energy * 0.9
	w.enable_mind(pet_id)
	configure(pet.mind, arm)
	w.place_obstacle(Vector2(235, 200), 20.0)
	w._rebuild_spatial()
	pet.mind.decide(pet, w.tick, w.sense(pet))
	var before := measurements(pet)
	var attempt: Dictionary = w.ensino_iniciar(pet_id, "ir_ate_local", Vector2(300, 200), false, 60, "heuristica")
	var peak := 0.0
	var blocked := 0
	for i in 24:
		w.step()
		peak = maxf(peak, float(pet.mind.affect.values.frustracao))
		blocked += int(pet.last_reason == "brain.blocked")
	var after_block := measurements(pet)
	w.obstacles.clear()
	w.ensino_cancelar(pet_id)
	var actions: Dictionary = {}
	for i in 96:
		w.step()
		actions[pet.last_action] = int(actions.get(pet.last_action, 0)) + 1
	var released := measurements(pet)
	var probability_change := 0.0
	for goal in before.probabilidades:
		probability_change = maxf(probability_change, absf(float(after_block.probabilidades[goal]) - float(before.probabilidades[goal])))
	return {"seed": world_seed, "arm": arm, "teaching_started": attempt.ok, "blocked_attempts": blocked,
		"before": before, "blocked": after_block, "released": released, "peak": peak,
		"max_probability_change": probability_change, "release_actions": actions,
		"increase_pass": peak - float(before.frustracao) >= 0.1,
		"decay_pass": float(released.frustracao) <= peak * 0.5,
		"expression_or_probability_pass": absf(float(after_block.affective_valence)) >= 0.05 or probability_change >= 0.05,
		"ablation_zero": peak == 0.0 and float(after_block.affective_valence) == 0.0}

func summarize(x1: Array, x2: Array, seeds: int) -> Dictionary:
	var result: Dictionary = {"x1": {}, "x2": {}, "persistence_all": true, "stationary_peer_all": true}
	for arm in ARMS:
		var a := 0.0
		var b := 0.0
		var positive := 0
		for row in x1:
			if row.arm != arm: continue
			result.persistence_all = result.persistence_all and row.persistence_exact
			result.stationary_peer_all = result.stationary_peer_all and row.peer_displacement == 0.0
			if row.profile == "A": a += float(row.contact_fraction)
			else: b += float(row.contact_fraction)
		for row in x1:
			if row.arm != arm or row.profile != "A": continue
			for other in x1:
				if other.arm == arm and other.profile == "B" and other.seed == row.seed and float(row.contact_fraction) > float(other.contact_fraction): positive += 1
		result.x1[arm] = {"A_mean": a / seeds, "B_mean": b / seeds, "difference": (a - b) / seeds, "positive_seeds": positive}
	var full: float = result.x1.full.difference
	result.x1["divergence_pass"] = full >= 0.15 and int(result.x1.full.positive_seeds) >= int(ceil(seeds * 0.75))
	for arm in ["no_affect", "no_memory"]:
		result.x1[arm]["removal_pass"] = absf(float(result.x1[arm].difference)) <= absf(full) * 0.5
	for arm in ["full", "no_affect"]:
		var counts := {"increase": 0, "decay": 0, "expression_or_probability": 0, "ablation_zero": 0, "blocked_attempts_min": 24}
		for row in x2:
			if row.arm != arm: continue
			counts.increase += int(row.increase_pass)
			counts.decay += int(row.decay_pass)
			counts.expression_or_probability += int(row.expression_or_probability_pass)
			counts.ablation_zero += int(row.ablation_zero)
			counts.blocked_attempts_min = mini(counts.blocked_attempts_min, int(row.blocked_attempts))
		result.x2[arm] = counts
	result.x2["pass"] = int(result.x2.full.increase) >= int(ceil(seeds * 0.9)) and int(result.x2.full.decay) >= int(ceil(seeds * 0.9)) and int(result.x2.full.expression_or_probability) >= int(ceil(seeds * 0.9)) and int(result.x2.no_affect.ablation_zero) == seeds
	return result
