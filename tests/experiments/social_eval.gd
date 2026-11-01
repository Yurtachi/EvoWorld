extends SceneTree
const Fixture = preload("res://tests/experiments/social_fixture.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")

func _init() -> void:
	var q: Array = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
	var choice_rng := Rng.new(51000)
	var training: Array = []
	for epoch in range(12):
		for seed_value in range(51001, 51009):
			# Same paired geometry and reproducible channel noise across passes.
			var row := Fixture.episode(seed_value, "active", q, true, choice_rng)
			q[row.state][row.choice] += 0.3 * ((1.0 if row.drank else 0.0) - q[row.state][row.choice])
			training.append(row)
	print("TRAIN episodes=", training.size(), " checkpoint=", q)
	if "--dev" in OS.get_cmdline_user_args():
		quit(0)
		return
	var frozen := q.duplicate(true)
	var rows: Array = []
	var totals: Dictionary = {}
	for arm in ["active", "disabled", "shuffled"]:
		var summary := {"successes": 0, "arrivals": 0, "steps": 0.0, "receiver_energy_cost": 0.0, "sender_energy_cost": 0.0, "signal_cost": 0.0}
		for seed_value in range(91501, 91521):
			var row := Fixture.episode(seed_value, arm, frozen)
			rows.append(row)
			summary.successes += int(row.drank)
			summary.arrivals += int(row.arrived)
			for metric in ["steps", "receiver_energy_cost", "sender_energy_cost", "signal_cost"]:
				summary[metric] += float(row[metric]) / 20.0
		print(arm, ": ", summary)
		totals[arm] = summary
	var comparisons: Dictionary = {}
	var passed: bool = totals.active.successes >= 15
	for arm in ["disabled", "shuffled"]:
		var wins := 0
		var losses := 0
		for index in range(20):
			var active: Dictionary = rows[index]
			var control: Dictionary = rows[index + (20 if arm == "disabled" else 40)]
			wins += int(active.drank and not control.drank)
			losses += int(control.drank and not active.drank)
		var gain: float = float(totals.active.successes - totals[arm].successes) / 20.0
		comparisons[arm] = {"wins": wins, "losses": losses, "ties": 20 - wins - losses, "gain": gain}
		passed = passed and gain >= 0.25 and wins >= 7
	assert(q == frozen)
	var file := FileAccess.open("res://reports/E4_social_eval.json", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify({"status": "PASS" if passed else "PARTIAL", "preregister_sha256": FileAccess.get_sha256("res://tests/experiments/social_preregistro.md"), "checkpoint": frozen, "train": training, "holdout": rows, "summary": totals, "comparisons": comparisons}, "\t"))
	print("E4 gate: ", "PASS" if passed else "PARTIAL", " comparisons=", comparisons)
	quit(0)
