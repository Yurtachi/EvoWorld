extends RefCounted
## New M0-B protocol; legacy E4 runner/preregistration remain separate.
const Fixture = preload("res://tests/experiments/social_fixture.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const ARMS := ["active", "disabled", "shuffled", "uniform", "prior"]
const TRAIN_START := 263101
const DEV_START := 263201
const HOLDOUT_START := 263901
const METRICS := ["steps", "receiver_energy_cost", "sender_energy_cost", "signal_cost"]

static func train() -> Dictionary:
	var q: Array = [[0.0, 0.0], [0.0, 0.0], [0.0, 0.0]]
	var counts: Array = [0, 0]
	var rows: Array = []
	var exploration := Rng.new(263100)
	for epoch in range(12):
		for seed_value in range(TRAIN_START, TRAIN_START + 8):
			for side in range(2):
				var row := Fixture.episode(seed_value, "active", q, true, exploration, side)
				q[row.state][row.choice] += 0.3 * (float(row.drank) - q[row.state][row.choice])
				counts[row.side] += 1 # Privileged labels only in TRAIN.
				row.epoch = epoch
				rows.append(row)
	return {"q": q, "prior_counts": counts,
		"prior": [float(counts[0]) / rows.size(), float(counts[1]) / rows.size()], "train": rows}

static func baseline_choice(seed_value: int, arm: String, prior: Array) -> int:
	# No side, sender observation, water or evaluation labels enter this interface.
	if arm == "prior" and float(prior[0]) != float(prior[1]):
		return 1 if float(prior[1]) > float(prior[0]) else 0
	var independent := Rng.new(seed_value + (900001 if arm == "prior" else 800001))
	return int(independent.between(0.0, 1.999999))

static func evaluate(start: int, count: int, checkpoint: Dictionary) -> Dictionary:
	var q: Array = checkpoint.q.duplicate(true)
	var rows: Array = []
	for arm in ARMS:
		for seed_value in range(start, start + count):
			var choice := baseline_choice(seed_value, arm, checkpoint.prior) if arm in ["uniform", "prior"] else -1
			for side in range(2):
				rows.append(Fixture.episode(seed_value, arm, q, false, null, side, -1, 0.1, choice))
	assert(q == checkpoint.q)
	return analyze(rows, count)

static func summarize(rows: Array) -> Dictionary:
	var out := {"episodes": rows.size(), "successes": 0, "arrivals": 0, "delivered": 0,
		"choices": [0, 0], "steps": 0.0, "receiver_energy_cost": 0.0,
		"sender_energy_cost": 0.0, "signal_cost": 0.0, "success_rate": 0.0}
	for row in rows:
		out.successes += int(row.drank)
		out.arrivals += int(row.arrived)
		out.delivered += int(int(row.received) >= 0)
		out.choices[int(row.choice)] += 1
		for metric in METRICS:
			out[metric] += float(row[metric]) / rows.size()
	if not rows.is_empty():
		out.success_rate = float(out.successes) / rows.size()
	return out

static func analyze(rows: Array, seed_count: int) -> Dictionary:
	var totals: Dictionary = {}
	var lookup: Dictionary = {}
	for arm in ARMS:
		var arm_rows: Array = []
		var sides: Array = [[], []]
		for row in rows:
			if row.arm != arm:
				continue
			arm_rows.append(row)
			sides[int(row.side)].append(row)
			lookup["%s:%d:%d" % [arm, int(row.seed), int(row.side)]] = row
		assert(arm_rows.size() == seed_count * 2)
		assert(sides[0].size() == seed_count and sides[1].size() == seed_count)
		totals[arm] = summarize(arm_rows)
		totals[arm].by_side = [summarize(sides[0]), summarize(sides[1])]
	var passed: bool = totals.active.success_rate >= 0.75
	for side in range(2):
		passed = passed and totals.active.by_side[side].success_rate >= 0.75
	var comparisons: Dictionary = {}
	for arm in ARMS.slice(1):
		var wins := 0
		var losses := 0
		var seed_deltas: Dictionary = {}
		for row in rows:
			if row.arm != "active":
				continue
			var other: Dictionary = lookup["%s:%d:%d" % [arm, int(row.seed), int(row.side)]]
			var delta := int(row.drank) - int(other.drank)
			wins += int(delta > 0)
			losses += int(delta < 0)
			var seed_key := str(int(row.seed))
			seed_deltas[seed_key] = int(seed_deltas.get(seed_key, 0)) + delta
		var seed_wins := 0
		var seed_losses := 0
		for delta in seed_deltas.values():
			seed_wins += int(delta > 0)
			seed_losses += int(delta < 0)
		var gain: float = totals.active.success_rate - totals[arm].success_rate
		comparisons[arm] = {"gain": gain, "wins": wins, "losses": losses,
			"ties": seed_count * 2 - wins - losses, "seed_wins": seed_wins,
			"seed_losses": seed_losses, "seed_ties": seed_count - seed_wins - seed_losses,
			"seed_deltas": seed_deltas, "gain_by_side": [
				totals.active.by_side[0].success_rate - totals[arm].by_side[0].success_rate,
				totals.active.by_side[1].success_rate - totals[arm].by_side[1].success_rate]}
		passed = passed and gain >= 0.25 and seed_wins >= 7
	return {"status": "PASS" if passed else "PARTIAL", "rows": rows,
		"summary": totals, "comparisons": comparisons, "independent_seed_count": seed_count}
