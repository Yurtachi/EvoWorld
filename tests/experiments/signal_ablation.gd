extends SceneTree
## Protocol committed in reports/sinais.md before any complete execution.
const World = preload("res://scripts/world/sim_world.gd")
const Q = preload("res://scripts/behavior/q_brain.gd")
const TRAIN := [2101, 2102, 2103, 2104, 2105, 2106]
const HOLDOUT := [8101, 8102, 8103, 8104, 8105, 8106, 8107, 8108, 8109, 8110]
const TICKS := 1500
const CONFIG := {"size": Vector2(600, 420), "creature_count": 8, "food_count": 40,
	"food_capacity": 60, "food_regrow_interval": 10, "food_regrow_batch": 1,
	"obstacle_count": 4, "reproduction_enabled": false,
	"signal_enabled": true, "signal_count": 4, "signal_range": 180.0,
	"signal_noise": 0.05, "signal_cost": 0.3, "signal_ttl": 10}

func _init() -> void:
	var shared := Q.new()
	var curve: Array = []
	for pass_index in range(2):
		for seed in TRAIN:
			var row := _episode(seed, "train", shared)
			row["pass"] = pass_index
			curve.append(row)
			print("Treino passagem=%d semente=%d alimento=%.3f sobrevivência=%.1f" % [pass_index, seed, row.food_mean, row.survival_mean])
	shared.reset_episode()
	var checkpoint := shared.to_dict()
	var evaluation := {}
	var summary := {}
	for group in ["train", "holdout"]:
		evaluation[group] = {}
		summary[group] = {}
		for condition in ["enabled", "disabled", "muted"]:
			var rows: Array = []
			for seed in (TRAIN if group == "train" else HOLDOUT):
				rows.append(_episode(seed, condition, null, checkpoint))
			evaluation[group][condition] = rows
			summary[group][condition] = {}
			for key in ["food_mean", "survival_mean", "synchronization", "emissions", "receptions", "action_change_fraction"]:
				summary[group][condition][key] = _mean(rows, key)
			print("Avaliação %s/%s: %s" % [group, condition, JSON.stringify(summary[group][condition])])
	var on: Array = evaluation.holdout.enabled
	var off: Array = evaluation.holdout.disabled
	var wins := 0
	for i in range(on.size()):
		if on[i].food_mean > off[i].food_mean:
			wins += 1
	var survival_ratio := _mean(on, "survival_mean") / maxf(0.000001, _mean(off, "survival_mean"))
	var sync_delta := _mean(on, "synchronization") - _mean(off, "synchronization")
	var observable := on.any(func(row): return row.receptions > 0 and row.action_changes > 0)
	var success := wins >= 9 and survival_ratio >= 1.05 and sync_delta >= 0.02 and observable
	var config := CONFIG.duplicate(true)
	config["size"] = [600, 420]
	var output := {"protocol_commit": "74fbbdd", "train_seeds": TRAIN, "holdout_seeds": HOLDOUT,
		"ticks": TICKS, "passes": 2, "config": config, "training_curve": curve,
		"evaluation": evaluation, "summary": summary, "food_wins_holdout": wins,
		"survival_ratio_holdout": survival_ratio, "sync_delta_holdout": sync_delta,
		"observable_reactions": observable, "success": success,
		"checkpoint_sha256": JSON.stringify(checkpoint, "", true, true).sha256_text(),
		"engine": Engine.get_version_info()["string"]}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/experiments/results"))
	var file := FileAccess.open("res://tests/experiments/results/signal_ablation_results.json", FileAccess.WRITE)
	if file == null:
		printerr("Falha ao gravar os resultados de sinais.")
		quit(1)
		return
	file.store_string(JSON.stringify(output, "\t", true, true))
	file.close()
	print("Critério pré-registrado: %s; vitórias=%d/10; razão sobrevivência=%.4f; diferença sincronização=%.4f" % [success, wins, survival_ratio, sync_delta])
	quit(0)

func _episode(seed: int, condition: String, shared = null, checkpoint: Dictionary = {}) -> Dictionary:
	var config := CONFIG.duplicate()
	config["signal_enabled"] = condition != "disabled"
	if condition == "muted":
		config["signal_noise"] = 1.0
	var world := World.new(seed, config)
	var bodies: Array = world.creatures.values()
	var start_steps: int = shared.steps if shared != null else 0
	for creature in bodies:
		var brain = Q.new() if condition == "train" else Q.from_dict(checkpoint)
		if condition == "train":
			brain.q = shared.q
			brain.steps = start_steps
		else:
			brain.learning = false
		creature.brain = brain
	var food := 0
	var emissions := 0
	var receptions := 0
	var reactions := 0
	var action_changes := 0
	var same_pairs := 0.0
	var total_pairs := 0.0
	for i in range(TICKS):
		if world.creatures.is_empty():
			break
		world.step()
		for event in world.events:
			if int(event.tick) == world.tick and event.type == "eat":
				food += 1
		for row in world.signal_log:
			if int(row.tick) == world.tick:
				emissions += 1
				receptions += row.receivers.size()
			for change in row.action_changes:
				if int(change.tick) == world.tick:
					reactions += 1
					if change.before != change.after:
						action_changes += 1
		var counts := {}
		for creature in world.creatures.values():
			counts[creature.last_action] = counts.get(creature.last_action, 0) + 1
		for count in counts.values():
			same_pairs += count * (count - 1) * 0.5
		var n := world.creatures.size()
		total_pairs += n * (n - 1) * 0.5
	var survival := 0.0
	for creature in bodies:
		survival += creature.age
		if shared != null:
			shared.steps += creature.brain.steps - start_steps
	return {"seed": seed, "condition": condition, "food_mean": float(food) / bodies.size(),
		"survival_mean": survival / bodies.size(), "synchronization": same_pairs / maxf(1.0, total_pairs),
		"emissions": emissions, "receptions": receptions, "reactions": reactions, "action_changes": action_changes,
		"action_change_fraction": float(action_changes) / maxi(1, reactions)}

func _mean(rows: Array, key: String) -> float:
	var total := 0.0
	for row in rows:
		total += float(row[key])
	return total / maxi(1, rows.size())
