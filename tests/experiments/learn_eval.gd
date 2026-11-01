extends SceneTree
## Reproducible headless learning experiment (gate G2).
##   godot --headless --path . -s tests/experiments/learn_eval.gd
##   godot --headless --path . -s tests/experiments/learn_eval.gd -- --dev   (TRAIN seeds only, short; for debugging)
## Pre-registered protocol and success criteria: reports/learn.md (committed before the first full run).
## Writes tests/experiments/results/learn_eval_results.json and trained_brain.json.

const World = preload("res://scripts/world/sim_world.gd")
const QBrain = preload("res://scripts/behavior/q_brain.gd")
const RandomBrain = preload("res://scripts/behavior/random_brain.gd")
const Obs = preload("res://scripts/behavior/observation.gd")
const Actions = preload("res://scripts/behavior/actions.gd")

const TRAIN_SEEDS := [1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010]
const HOLDOUT_SEEDS := [7001, 7002, 7003, 7004, 7005, 7006, 7007, 7008, 7009, 7010]
const CONFIG := {
	"creature_count": 8, "food_count": 30, "food_capacity": 40, "food_regrow": true,
	"food_regrow_interval": 10, "food_regrow_batch": 1, "obstacle_count": 10
}
const MAX_TICKS := 3000
const TRAIN_PASSES := 4
const CONDITIONS := ["random", "heuristic", "learner_naive", "learner_trained", "learner_frozen"]
const RESULTS_DIR := "res://tests/experiments/results"

func _init() -> void:
	var dev := OS.get_cmdline_user_args().has("--dev")
	var started := Time.get_ticks_msec()
	var train_seeds: Array = TRAIN_SEEDS.slice(0, 3) if dev else TRAIN_SEEDS
	var passes := 1 if dev else TRAIN_PASSES
	print("EvoWorld learn_eval  dev=%s  max_ticks=%d  creatures=%d" % [dev, MAX_TICKS, CONFIG["creature_count"]])

	# Phase 1: training on TRAIN seeds. Creatures in a training world pool experience
	# into one shared Q-table; the table starts at zero.
	var shared := QBrain.new()
	var curve: Array = []
	for pass_index in range(passes):
		for world_seed in train_seeds:
			var episode := _run_episode(world_seed, "train", shared)
			episode["pass"] = pass_index
			curve.append(episode)
			print("train pass=%d seed=%d food/creature=%.2f survival=%.0f eps=%.3f (%d ms)" % [
				pass_index, world_seed, episode["food_mean"], episode["survival_mean"], shared.epsilon(),
				Time.get_ticks_msec() - started])
	var checkpoint := shared.to_dict()
	checkpoint["prev_state"] = -1
	checkpoint["prev_action"] = -1
	checkpoint["prev_energy"] = 0.0
	checkpoint["total_reward"] = 0.0

	# Phase 2: evaluation. Every condition sees identical initial worlds per seed.
	var evaluation := {}
	var sets := {"train": train_seeds}
	if not dev:
		sets["holdout"] = HOLDOUT_SEEDS
	for set_name in sets:
		evaluation[set_name] = {}
		for condition in CONDITIONS:
			var rows: Array = []
			for world_seed in sets[set_name]:
				rows.append(_run_episode(world_seed, condition, null, checkpoint))
			evaluation[set_name][condition] = rows
			print("eval %-7s %-16s food/creature=%.2f survival=%.0f (%d ms)" % [
				set_name, condition, _mean(rows, "food_mean"), _mean(rows, "survival_mean"), Time.get_ticks_msec() - started])

	var summary := _summarize(evaluation, curve, passes, train_seeds.size())
	_print_summary(summary, checkpoint)
	var output := {
		"protocol": {"train_seeds": train_seeds, "holdout_seeds": [] if dev else HOLDOUT_SEEDS, "config": CONFIG,
			"max_ticks": MAX_TICKS, "train_passes": passes, "dev": dev,
			"engine": Engine.get_version_info()["string"]},
		"training_curve": curve, "evaluation": evaluation, "summary": summary,
		"elapsed_ms": Time.get_ticks_msec() - started
	}
	if not dev:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RESULTS_DIR))
		var brain_json := JSON.stringify(checkpoint, "\t", true, true)
		_write(RESULTS_DIR + "/trained_brain.json", brain_json)
		output["trained_brain_sha256"] = brain_json.sha256_text()
		_write(RESULTS_DIR + "/learn_eval_results.json", JSON.stringify(output, "\t", true, true))
		print("trained_brain.json sha256=%s" % output["trained_brain_sha256"])
	print("elapsed_ms=%d" % output["elapsed_ms"])
	quit(0)

func _run_episode(world_seed: int, condition: String, shared = null, checkpoint: Dictionary = {}) -> Dictionary:
	var world := World.new(world_seed, CONFIG)
	var bodies: Array = []
	var start_steps := 0
	var ids := world.creatures.keys()
	ids.sort()
	for creature_id in ids:
		var creature = world.creatures[creature_id]
		match condition:
			"random":
				creature.brain = RandomBrain.new()
			"heuristic":
				creature.brain = null
			"learner_naive":
				creature.brain = QBrain.new()
			"learner_trained", "learner_frozen":
				creature.brain = QBrain.from_dict(checkpoint)
				creature.brain.learning = condition == "learner_trained"
			"train":
				var brain := QBrain.new()
				brain.q = shared.q # shared reference: pooled experience
				brain.steps = shared.steps
				start_steps = shared.steps
				creature.brain = brain
		bodies.append(creature)
	var food := {}
	var actions: Array = []
	actions.resize(Actions.COUNT)
	actions.fill(0)
	for creature in bodies:
		food[creature.id] = 0
	for index in range(MAX_TICKS):
		if world.creatures.is_empty():
			break
		world.step()
		for creature in world.creatures.values():
			var action := Actions.NAMES.find(creature.last_action)
			if action >= 0:
				actions[action] += 1
		var cursor := world.events.size() - 1
		while cursor >= 0 and int(world.events[cursor]["tick"]) == world.tick:
			var event: Dictionary = world.events[cursor]
			if event["type"] == "eat" and food.has(int(event["creature_id"])):
				food[int(event["creature_id"])] += 1
			cursor -= 1
	if condition == "train":
		var used := 0
		for creature in bodies:
			used += creature.brain.steps - start_steps
		shared.steps = start_steps + used
	var survival_total := 0.0
	var food_total := 0.0
	var survivors := 0
	for creature in bodies:
		survival_total += float(creature.age)
		food_total += float(food[creature.id])
		if creature.alive:
			survivors += 1
	return {
		"seed": world_seed, "condition": condition, "ticks": world.tick,
		"survival_mean": survival_total / bodies.size(), "food_mean": food_total / bodies.size(),
		"survivors": survivors, "creatures": bodies.size(), "action_counts": actions
	}

func _mean(rows: Array, key: String) -> float:
	var total := 0.0
	for row in rows:
		total += float(row[key])
	return total / maxf(1.0, rows.size())

func _stdev(rows: Array, key: String) -> float:
	var mean := _mean(rows, key)
	var total := 0.0
	for row in rows:
		total += pow(float(row[key]) - mean, 2.0)
	return sqrt(total / maxf(1.0, rows.size() - 1))

## Paired per-seed wins (ties count as non-wins) and one-sided exact sign-test p-value.
func _paired(a: Array, b: Array, key: String) -> Dictionary:
	var wins := 0
	var diffs := 0.0
	for index in range(a.size()):
		if float(a[index][key]) > float(b[index][key]):
			wins += 1
		diffs += float(a[index][key]) - float(b[index][key])
	var n := a.size()
	var p := 0.0
	for k in range(wins, n + 1):
		p += _choose(n, k) / pow(2.0, n)
	return {"wins": wins, "n": n, "p_one_sided": p, "mean_diff": diffs / maxf(1.0, n)}

func _choose(n: int, k: int) -> float:
	var result := 1.0
	for i in range(k):
		result = result * float(n - i) / float(i + 1)
	return result

func _summarize(evaluation: Dictionary, curve: Array, passes: int, per_pass: int) -> Dictionary:
	var summary := {"sets": {}}
	for set_name in evaluation:
		var table := {}
		for condition in evaluation[set_name]:
			var rows: Array = evaluation[set_name][condition]
			table[condition] = {
				"food_mean": _mean(rows, "food_mean"), "food_sd": _stdev(rows, "food_mean"),
				"survival_mean": _mean(rows, "survival_mean"), "survival_sd": _stdev(rows, "survival_mean"),
				"survivors_mean": _mean(rows, "survivors")
			}
		var e: Dictionary = evaluation[set_name]
		table["trained_vs_random_food"] = _paired(e["learner_trained"], e["random"], "food_mean")
		table["trained_vs_random_survival"] = _paired(e["learner_trained"], e["random"], "survival_mean")
		table["trained_vs_naive_food"] = _paired(e["learner_trained"], e["learner_naive"], "food_mean")
		table["naive_vs_random_food"] = _paired(e["learner_naive"], e["random"], "food_mean")
		table["frozen_vs_random_food"] = _paired(e["learner_frozen"], e["random"], "food_mean")
		table["trained_vs_heuristic_food"] = _paired(e["learner_trained"], e["heuristic"], "food_mean")
		table["trained_vs_heuristic_survival"] = _paired(e["learner_trained"], e["heuristic"], "survival_mean")
		var survival_ratio: float = table["learner_trained"]["survival_mean"] / maxf(0.001, table["random"]["survival_mean"])
		table["trained_over_random_survival_ratio"] = survival_ratio
		table["H1_pass"] = table["trained_vs_random_food"]["wins"] >= 9 and survival_ratio >= 1.2
		table["H2_pass"] = table["trained_vs_naive_food"]["wins"] >= 9
		table["H3_naive_vs_random_pass"] = table["naive_vs_random_food"]["wins"] >= 8
		summary["sets"][set_name] = table
	var first := curve.slice(0, per_pass)
	var last := curve.slice((passes - 1) * per_pass, passes * per_pass)
	summary["training_first_pass_food"] = _mean(first, "food_mean")
	summary["training_last_pass_food"] = _mean(last, "food_mean")
	summary["training_first_pass_survival"] = _mean(first, "survival_mean")
	summary["training_last_pass_survival"] = _mean(last, "survival_mean")
	if summary["sets"].has("holdout"):
		var holdout: Dictionary = summary["sets"]["holdout"]
		summary["SUCCESS"] = holdout["H1_pass"] and holdout["H2_pass"]
	return summary

func _print_summary(summary: Dictionary, checkpoint: Dictionary) -> void:
	print("")
	print("training curve: first pass food/creature=%.2f survival=%.0f | last pass food/creature=%.2f survival=%.0f" % [
		summary["training_first_pass_food"], summary["training_first_pass_survival"],
		summary["training_last_pass_food"], summary["training_last_pass_survival"]])
	for set_name in summary["sets"]:
		var table: Dictionary = summary["sets"][set_name]
		print("")
		print("[%s] condition | food/creature mean (sd) | survival ticks mean (sd) | survivors/8" % set_name)
		for condition in CONDITIONS:
			var row: Dictionary = table[condition]
			print("  %-16s | %6.2f (%5.2f) | %7.1f (%6.1f) | %.2f" % [condition, row["food_mean"], row["food_sd"],
				row["survival_mean"], row["survival_sd"], row["survivors_mean"]])
		for key in ["trained_vs_random_food", "trained_vs_random_survival", "trained_vs_naive_food", "naive_vs_random_food",
				"frozen_vs_random_food", "trained_vs_heuristic_food", "trained_vs_heuristic_survival"]:
			var c: Dictionary = table[key]
			print("  %-30s wins %d/%d  p=%.4f  mean_diff=%.2f" % [key, c["wins"], c["n"], c["p_one_sided"], c["mean_diff"]])
		print("  survival ratio trained/random=%.2f  H1=%s  H2=%s  H3(naive>random)=%s" % [
			table["trained_over_random_survival_ratio"], table["H1_pass"], table["H2_pass"], table["H3_naive_vs_random_pass"]])
	if summary.has("SUCCESS"):
		print("")
		print("PRE-REGISTERED SUCCESS (holdout H1 and H2): %s" % summary["SUCCESS"])
	# Greedy policy of the trained table for mid energy, no obstacle ahead, plus obstacle-ahead case.
	var brain = QBrain.from_dict(checkpoint)
	print("")
	print("trained greedy policy (energy=mid):")
	for food_bucket in range(Obs.FOOD_BUCKETS):
		var clear_state := Obs.state_index(food_bucket, 1, false)
		var blocked_state := Obs.state_index(food_bucket, 1, true)
		print("  food=%-10s clear->%-10s obstacle->%s" % [Obs.FOOD_NAMES[food_bucket],
			Actions.name_of(brain.greedy(clear_state)), Actions.name_of(brain.greedy(blocked_state))])

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("cannot write ", path)
		return
	file.store_string(text)
	file.close()
