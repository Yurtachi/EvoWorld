extends SceneTree

const World = preload("res://scripts/world/sim_world.gd")
const Atelier = preload("res://scripts/atelier/atelier.gd")
const Fixture = preload("res://tests/unit/test_sim_m3.gd")

const PROTOCOL := "res://tests/experiments/m3_atelier_preregistro.md"
const OUTPUT := "res://reports/M3_atelie_eval.json"
const ARMS := ["random", "naive", "trained_frozen", "trained_online"]
const SHAPES := ["linha", "circulo", "quadrado"]
const FROZEN := [
	"scripts/atelier/atelier.gd",
	"scripts/mind/object_memory.gd",
	"scripts/mind/affect.gd",
	"scripts/mind/creature_mind.gd",
	"scripts/mind/motivation.gd",
	"scripts/creature/sim_creature.gd",
	"scripts/world/sim_world.gd",
	"scripts/persistence/save_store.gd",
	"tests/experiments/m3_atelier_eval.gd"
]

var fixture = Fixture.new()

func checksum(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path).get_string_from_utf8().replace("\r\n", "\n").to_utf8_buffer()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()

func write_result(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()

func median_of(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return snappedf(float(sorted[mid]), 0.000001)
	return snappedf(0.5 * (float(sorted[mid - 1]) + float(sorted[mid])), 0.000001)

func run_single_attempt(w, c, board_id: int, shape: String, params: Dictionary) -> Dictionary:
	w.demonstrar_forma(board_id, shape, params)
	var before_attempts: int = c.atelier.attempts.size()
	var replay_ok := true
	var no_energy_gain := true
	for step_i in range(12):
		c.energy = snappedf(c.max_energy * 0.95, 0.000001)
		c.hydration = 95.0
		var e_before: float = c.energy
		w.tick += 1
		w.draw_on_board(c, board_id)
		if c.energy > e_before + 0.00001:
			no_energy_gain = false
		if c.atelier.attempts.size() == before_attempts + 1:
			var art: Dictionary = w.gallery.back()
			var replayed: Array = Atelier.execute_actions(art.get("actions", [])).strokes
			if JSON.stringify(replayed) != JSON.stringify(art.get("strokes", [])) or not Atelier.valid_artifact(art, w.tick, 2147483647):
				replay_ok = false
			break
	assert(c.atelier.attempts.size() == before_attempts + 1, "attempt must complete")
	var last_attempt: Dictionary = c.atelier.attempts.back()
	return {
		"error": float(last_attempt.error),
		"success": bool(last_attempt.success),
		"replay_ok": replay_ok,
		"no_energy_gain": no_energy_gain
	}

func trial(seed_value: int, arm: String, shape: String, split_name: String) -> Dictionary:
	var w = fixture.studio(seed_value, 0.85)
	var c = w.creatures[w.pet_id]
	c.atelier = Atelier.new()
	var train_board: int = w.place_board(c.pos + Vector2(10, 0))
	if arm == "random":
		c.atelier.policy_mode = "random"
		c.atelier.learning = false
	elif arm == "naive":
		c.atelier.policy_mode = "naive"
		c.atelier.learning = false
	else:
		c.atelier.policy_mode = "trained"
		c.atelier.learning = true

	# 12 training attempts in standard training configuration (32,32, scale 1.0, rot 0).
	var attempt_errors: Array = []
	var replay_all := true
	var no_energy_gain_all := true
	var train_params := {
		"center": Vector2(32.0, 32.0),
		"scale": 1.0,
		"dir_offset": 0
	}
	for k in range(12):
		var out := run_single_attempt(w, c, train_board, shape, train_params)
		attempt_errors.append(out.error)
		replay_all = replay_all and bool(out.replay_ok)
		no_energy_gain_all = no_energy_gain_all and bool(out.no_energy_gain)

	var early_error := snappedf((float(attempt_errors[0]) + float(attempt_errors[1]) + float(attempt_errors[2])) / 3.0, 0.000001)
	var late_error := snappedf((float(attempt_errors[9]) + float(attempt_errors[10]) + float(attempt_errors[11])) / 3.0, 0.000001)
	var improvement := snappedf(early_error - late_error, 0.000001)

	if arm == "trained_frozen":
		c.atelier.learning = false
		c.atelier.policy_mode = "frozen"

	# Unseen holdout board position and unseen (center, scale in 0.65..1.42, dir_offset) transforms.
	var eval_board: int = w.place_board(c.pos + Vector2(0, 12))
	var split_shift := 0 if split_name == "train" else (3 if split_name == "dev" else 7)
	var unseen_transforms := [
		{"center": Vector2(22.0 + float(split_shift), 38.0), "scale": 0.68 + 0.02 * float(split_shift), "dir_offset": (seed_value + 1 + split_shift) % 16},
		{"center": Vector2(40.0, 24.0 + float(split_shift)), "scale": 1.16 + 0.01 * float(split_shift), "dir_offset": (seed_value + 5 + split_shift) % 16},
		{"center": Vector2(36.0 - float(split_shift), 40.0), "scale": 1.34 + 0.01 * float(split_shift), "dir_offset": (seed_value + 11 + split_shift) % 16}
	]
	var holdout_errors: Array = []
	for t_params in unseen_transforms:
		var eval_out := run_single_attempt(w, c, eval_board, shape, t_params)
		holdout_errors.append(eval_out.error)
		replay_all = replay_all and bool(eval_out.replay_ok)
		no_energy_gain_all = no_energy_gain_all and bool(eval_out.no_energy_gain)

	var eval_error := snappedf((float(holdout_errors[0]) + float(holdout_errors[1]) + float(holdout_errors[2])) / 3.0, 0.000001)
	var eval_success := eval_error < Atelier.SUCCESS_THRESHOLD

	# Save/load retention test (v10 roundtrip).
	var snap_before: String = fixture.snapshot(w)
	var loaded = World.from_dict(JSON.parse_string(snap_before))
	var roundtrip: bool = loaded != null and fixture.snapshot(loaded) == snap_before
	var post_saveload_error := 1.0
	var post_idle_2000_error := 1.0
	if loaded != null:
		var lc = loaded.creatures[loaded.pet_id]
		var prev_learning: bool = lc.atelier.learning
		var prev_mode: String = lc.atelier.policy_mode
		lc.atelier.learning = false
		var sl_out := run_single_attempt(loaded, lc, eval_board, shape, unseen_transforms[1])
		post_saveload_error = snappedf(float(sl_out.error), 0.000001)
		replay_all = replay_all and bool(sl_out.replay_ok)

		# 2000 idle ticks without boards, then re-evaluate competence.
		loaded.boards.clear()
		for idle_step in range(2000):
			lc.energy = snappedf(lc.max_energy * 0.9, 0.000001)
			lc.hydration = 90.0
			loaded.step()
		var idle_board: int = loaded.place_board(lc.pos + Vector2(11, 0))
		var idle_out := run_single_attempt(loaded, lc, idle_board, shape, unseen_transforms[1])
		post_idle_2000_error = snappedf(float(idle_out.error), 0.000001)
		replay_all = replay_all and bool(idle_out.replay_ok)
		lc.atelier.learning = prev_learning
		lc.atelier.policy_mode = prev_mode

	return {
		"seed": seed_value,
		"arm": arm,
		"shape": shape,
		"early_error": early_error,
		"late_error": late_error,
		"improvement": improvement,
		"eval_error": eval_error,
		"success": eval_success,
		"post_saveload_error": post_saveload_error,
		"post_saveload_success": post_saveload_error < Atelier.SUCCESS_THRESHOLD,
		"post_idle_2000_error": post_idle_2000_error,
		"post_idle_2000_success": post_idle_2000_error < Atelier.SUCCESS_THRESHOLD,
		"updates": int(c.atelier.updates),
		"roundtrip": roundtrip,
		"actions_replay_ok": replay_all,
		"no_energy_gain_on_reward": no_energy_gain_all
	}

func summarize_subset(subset: Array) -> Dictionary:
	var eval_errors: Array = []
	var sl_errors: Array = []
	var idle_errors: Array = []
	var early_errors: Array = []
	var late_errors: Array = []
	var successes := 0
	var sl_successes := 0
	var idle_successes := 0
	var sum_improvement := 0.0
	var sum_early := 0.0
	var sum_late := 0.0
	for row in subset:
		eval_errors.append(float(row.eval_error))
		sl_errors.append(float(row.post_saveload_error))
		idle_errors.append(float(row.post_idle_2000_error))
		early_errors.append(float(row.early_error))
		late_errors.append(float(row.late_error))
		if bool(row.success):
			successes += 1
		if bool(row.post_saveload_success):
			sl_successes += 1
		if bool(row.post_idle_2000_success):
			idle_successes += 1
		sum_improvement += float(row.improvement)
		sum_early += float(row.early_error)
		sum_late += float(row.late_error)
	var n := float(maxi(1, subset.size()))
	var med_early := median_of(early_errors)
	var med_late := median_of(late_errors)
	return {
		"count": subset.size(),
		"median_error": median_of(eval_errors),
		"success_rate": snappedf(float(successes) / n, 0.000001),
		"median_early_error": med_early,
		"median_late_error": med_late,
		"median_improvement": snappedf(med_early - med_late, 0.000001),
		"mean_early_error": snappedf(sum_early / n, 0.000001),
		"mean_late_error": snappedf(sum_late / n, 0.000001),
		"mean_improvement": snappedf(sum_improvement / n, 0.000001),
		"saveload_median_error": median_of(sl_errors),
		"saveload_success_rate": snappedf(float(sl_successes) / n, 0.000001),
		"idle_2000_median_error": median_of(idle_errors),
		"idle_2000_success_rate": snappedf(float(idle_successes) / n, 0.000001)
	}

func summarize(rows: Array) -> Dictionary:
	var by_arm: Dictionary = {}
	var by_arm_shape: Dictionary = {}
	for arm in ARMS:
		var arm_rows: Array = rows.filter(func(r): return r.arm == arm)
		by_arm[arm] = summarize_subset(arm_rows)
		by_arm_shape[arm] = {}
		for shape in SHAPES:
			var sub: Array = arm_rows.filter(func(r): return r.shape == shape)
			by_arm_shape[arm][shape] = summarize_subset(sub)

	var shape_status: Dictionary = {}
	for shape in SHAPES:
		var tf: Dictionary = by_arm_shape["trained_frozen"][shape]
		var to: Dictionary = by_arm_shape["trained_online"][shape]
		var shape_ok: bool = (
			float(tf.success_rate) >= 0.70 and float(tf.median_error) < 0.20
			and float(to.success_rate) >= 0.70 and float(to.median_error) < 0.20
		)
		shape_status[shape] = "PASS" if shape_ok else "PARTIAL"

	var tf_all: Dictionary = by_arm["trained_frozen"]
	var to_all: Dictionary = by_arm["trained_online"]
	var rnd_all: Dictionary = by_arm["random"]
	var nv_all: Dictionary = by_arm["naive"]
	var roundtrip_all: bool = rows.all(func(r): return bool(r.roundtrip) and bool(r.actions_replay_ok) and bool(r.no_energy_gain_on_reward))

	var checks := {
		"H1_global_vs_controls": (
			float(tf_all.median_error) < 0.18 and float(to_all.median_error) < 0.18
			and float(tf_all.success_rate) >= 0.75 and float(to_all.success_rate) >= 0.75
			and float(rnd_all.median_error) - float(tf_all.median_error) >= 0.20
			and float(nv_all.median_error) - float(tf_all.median_error) >= 0.20
			and float(rnd_all.median_error) - float(to_all.median_error) >= 0.20
			and float(nv_all.median_error) - float(to_all.median_error) >= 0.20
		),
		"H2_honest_per_shape": shape_status.values().all(func(s): return s == "PASS"),
		"H3_naive_distinguishable": (
			float(nv_all.median_error) > 0.30
			and float(nv_all.success_rate) < 0.25
			and float(tf_all.success_rate) - float(nv_all.success_rate) >= 0.50
		),
		"H4_improvement_vs_attempts": (
			float(tf_all.median_improvement) >= 0.20
			and float(to_all.median_improvement) >= 0.20
		),
		"H5_retention_saveload": (
			roundtrip_all
			and float(tf_all.saveload_success_rate) >= 0.75 and float(tf_all.saveload_median_error) < 0.18
			and float(to_all.saveload_success_rate) >= 0.75 and float(to_all.saveload_median_error) < 0.18
		),
		"H6_retention_idle_2000": (
			float(tf_all.idle_2000_success_rate) >= 0.75 and float(tf_all.idle_2000_median_error) < 0.18
			and float(to_all.idle_2000_success_rate) >= 0.75 and float(to_all.idle_2000_median_error) < 0.18
		)
	}
	return {
		"by_arm": by_arm,
		"by_arm_shape": by_arm_shape,
		"shape_status": shape_status,
		"checks": checks,
		"scientific_status": "PASS" if checks.values().all(func(v): return v) else "PARTIAL"
	}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var holdout := "--holdout" in args
	var training := "--train" in args
	var split_name := "holdout" if holdout else ("train" if training else "dev")
	var path := OUTPUT if holdout else ("res://reports/M3_atelie_train.json" if training else "res://reports/M3_atelie_dev.json")
	var seeds: Array = range(118401, 118425) if holdout else (range(118101, 118105) if training else range(118201, 118207))
	if holdout and FileAccess.file_exists(path):
		printerr("Holdout ja aberto; resultado preservado")
		quit(2)
		return
	var frozen: Dictionary = {}
	for file in FROZEN:
		frozen[file] = checksum("res://" + file)
	var result := {
		"status": "opened",
		"split": split_name,
		"seeds": seeds,
		"arms": ARMS,
		"shapes": SHAPES,
		"success_threshold": Atelier.SUCCESS_THRESHOLD,
		"idle_retention_ticks": 2000,
		"preregister_sha256": checksum(PROTOCOL),
		"frozen_sha256": frozen,
		"godot": Engine.get_version_info()
	}
	write_result(path, result)
	var rows: Array = []
	for seed_value in seeds:
		for arm in ARMS:
			for shape in SHAPES:
				rows.append(trial(seed_value, arm, shape, split_name))
	result["status"] = "complete"
	result["rows"] = rows
	result["summary"] = summarize(rows)
	write_result(path, result)
	print(JSON.stringify(result.summary))
	quit(0 if bool(result.summary.checks.H5_retention_saveload) else 1)
