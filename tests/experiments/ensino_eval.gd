extends SceneTree
## Protocolo imutável: ensino_preregistro.md. --dev executa somente TRAIN.
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Q = preload("res://scripts/behavior/q_brain.gd")
const Random = preload("res://scripts/behavior/random_brain.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const SKILLS := ["ir_ate_local", "buscar_agua"]
const ARMS := ["aleatorio", "heuristica", "naive", "trained_frozen", "trained_online"]
const HORIZON := 140
const TRAIN_FIRST := 41001
const TRAIN_LAST := 41016
const HOLDOUT_FIRST := 93001
const HOLDOUT_LAST := 93020
const PASSES := 6

func _init() -> void:
	var dev := OS.get_cmdline_user_args().has("--dev")
	var shared := Q.new()
	var training: Array = []
	for pass_index in range(PASSES):
		for seed_value in range(TRAIN_FIRST, TRAIN_LAST + 1):
			for skill in SKILLS:
				training.append(episode(seed_value, skill, "train", shared, pass_index))
	var frozen_table: Array = shared.goal_q.duplicate()
	print("E3 TRAIN episodes=%d success=%.3f updates=%d" % [training.size(), mean(training, "success"), shared.goal_updates])
	if dev:
		quit(0)
		return
	var evaluation := {}
	var summary := {}
	for arm in ARMS:
		var policy := Q.new()
		policy.goal_q = frozen_table.duplicate() if arm.begins_with("trained") else policy.goal_q
		policy.learning = arm == "trained_online"
		var rows: Array = []
		for seed_value in range(HOLDOUT_FIRST, HOLDOUT_LAST + 1):
			for skill in SKILLS:
				rows.append(episode(seed_value, skill, arm, policy))
		evaluation[arm] = rows
		summary[arm] = {"success": mean(rows, "success"), "steps_censored": mean(rows, "steps"),
			"energy_final": mean(rows, "energy_final"), "energy_delta": mean(rows, "energy_delta"),
			"survival": mean(rows, "survival"), "assistance": mean(rows, "assistance"),
			"updates": mean(rows, "updates")}
		for skill in SKILLS:
			summary[arm][skill] = mean(rows.filter(func(row): return row.skill == skill), "success")
		summary[arm]["paired_vs_naive"] = {} # Filled after all arms have run.
	for arm in ARMS:
		summary[arm]["paired_vs_naive"] = paired(evaluation[arm], evaluation.naive)
		print("E3 %s %s" % [arm, JSON.stringify(summary[arm])])
	var primary: Dictionary = summary.trained_frozen
	var passed: bool = primary.ir_ate_local >= 0.7 and primary.buscar_agua >= 0.7 and primary.success - summary.naive.success >= 0.3 and primary.paired_vs_naive.p_value < 0.05 and primary.assistance == 0.0
	var result := {"protocol": "tests/experiments/ensino_preregistro.md", "engine": Engine.get_version_info().string,
		"preregistration_sha256": FileAccess.get_file_as_string("res://tests/experiments/ensino_preregistro.md").sha256_text(),
		"train_seeds": range(TRAIN_FIRST, TRAIN_LAST + 1), "holdout_seeds": range(HOLDOUT_FIRST, HOLDOUT_LAST + 1),
		"horizon": HORIZON, "training": training, "evaluation": evaluation, "summary": summary,
		"trained_goal_q": frozen_table, "efficacy_pass": passed}
	var file := FileAccess.open("res://reports/E3_ensino_eval.json", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(result, "\t", true, true))
	file.close()
	print("E3 efficacy_pass=%s" % passed)
	quit(0) # Scientific failure is reported in the artifact, not concealed as a crash.

func episode(seed_value: int, skill: String, arm: String, policy, pass_index: int = 0) -> Dictionary:
	var setup := Rng.new(seed_value + pass_index * 100000)
	var origin := Vector2(setup.between(220, 420), setup.between(160, 320))
	var heading: float = setup.between(-PI, PI)
	var target: Vector2 = origin + Vector2.from_angle(setup.between(-PI, PI)) * setup.between(90, 140)
	var world := World.new(seed_value, {"size": Vector2(640, 480), "creature_count": 0,
		"food_count": 0, "obstacle_count": 0, "water_count": 0, "water_enabled": true,
		"reproduction_enabled": false, "food_regrow": false})
	var genes := Genes.new()
	genes.size = 8.0
	genes.speed = 30.0
	genes.vision_range = 240.0
	genes.vision_fov = TAU
	genes.metabolism = 1.0
	var id: int = world.spawn_creature(origin, "E3", genes)
	var body = world.creatures[id]
	body.heading = heading
	body.hydration = 65.0
	if skill == "buscar_agua":
		world.place_water(target, 18.0)
	body.brain = Random.new() if arm == "aleatorio" else policy
	var initial_energy: float = body.energy
	var updates: int = policy.goal_updates
	var start: Dictionary = world.ensino_iniciar(id, skill, target, arm == "train", HORIZON, "heuristica" if arm == "heuristica" else "q")
	assert(start.ok)
	for tick_index in range(HORIZON):
		world.step()
		if not body.alive or body.ensino.active.status != "active":
			break
	var state: Dictionary = world.ensino_observar(id) if body.alive else body.ensino.snapshot()
	var attempt: Dictionary = state.active
	if attempt.status == "success":
		world.ensino_recompensar(id)
	return {"seed": seed_value, "pass": pass_index, "skill": skill, "arm": arm,
		"success": 1 if attempt.status == "success" else 0, "steps": int(attempt.steps),
		"energy_final": body.energy, "energy_delta": body.energy - initial_energy,
		"survival": 1 if body.alive else 0, "assistance": int(attempt.assistance),
		"updates": policy.goal_updates - updates, "final_distance": attempt.final_distance}

func mean(rows: Array, key: String) -> float:
	var sum := 0.0
	for row in rows:
		sum += float(row[key])
	return sum / maxf(1.0, rows.size())

func paired(rows: Array, baseline: Array) -> Dictionary:
	var wins := 0
	var losses := 0
	for index in range(rows.size()):
		assert(rows[index].seed == baseline[index].seed and rows[index].skill == baseline[index].skill)
		if rows[index].success > baseline[index].success:
			wins += 1
		elif rows[index].success < baseline[index].success:
			losses += 1
	var discordant := wins + losses
	var probability := pow(0.5, discordant)
	var tail := probability
	for k in range(1, mini(wins, losses) + 1):
		probability *= float(discordant - k + 1) / float(k)
		tail += probability
	return {"wins": wins, "losses": losses, "ties": rows.size() - discordant,
		"p_value": minf(1.0, 2.0 * tail) if discordant > 0 else 1.0}
