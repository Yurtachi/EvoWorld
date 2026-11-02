extends SceneTree
## X5: only this new protocol may be opened; older evaluators are never invoked.
const World = preload("res://scripts/world/sim_world.gd")
const Atelier = preload("res://scripts/atelier/atelier.gd")
const Fixture = preload("res://tests/unit/test_sim_m3.gd")
const PROTOCOL := "res://tests/experiments/m3b_copia_preregistro.md"
const OUTPUT := "res://reports/M3b_copia_eval.json"
const ARMS := ["random", "naive", "servo_geometrico", "trained_frozen", "trained_online", "oraculo"]
const FROZEN := [
	"scripts/atelier/atelier.gd", "scripts/world/sim_world.gd",
	"scripts/creature/sim_creature.gd", "scripts/persistence/save_store.gd",
	"scripts/behavior/personality.gd", "scripts/core/textos.gd",
	"scripts/core/sim_data.gd", "scripts/core/sim_rng.gd",
	"scripts/creature/genome.gd", "scripts/behavior/actions.gd",
	"scripts/behavior/observation.gd", "scripts/ui/verify_ui.gd",
	"scripts/mind/creature_mind.gd", "scripts/mind/motivation.gd",
	"scripts/mind/object_memory.gd", "scripts/mind/affect.gd",
	"tests/unit/test_sim_m3b.gd", "tests/experiments/m3b_copia_eval.gd",
	"tests/experiments/m3b_copia_verify.py", "tests/experiments/m3b_copia_metrics.py"
]
var fixture = Fixture.new()

func checksum(path: String) -> String:
	return FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()

func write_result(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Cannot write X5 artifact")
	file.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	file.flush()
	file.close()

func attempt(w, c, bid: int, shape: String, params: Dictionary, demonstrate: bool = true, external_ref: Array = []) -> Dictionary:
	var board: Dictionary = w.boards[0]
	if demonstrate:
		w.demonstrar_forma(bid, shape, params)
	else:
		board.reference_shape = shape
		board.reference_params = {}
		board.reference_strokes = []
	var ref: Array = board.reference_strokes.duplicate(true) if demonstrate else external_ref
	var e: float = c.energy
	var h: float = c.hydration
	var p: Vector2 = c.pos
	var before_id: int = c.atelier.next_id
	var completed := false
	for i in range(4):
		w.draw_on_board(c, bid)
		if not c.atelier.active.is_empty() and c.atelier.active.status == "completed" and c.atelier.next_id > before_id:
			completed = true
			break
	var err := 1.0
	var replay := true
	if completed:
		var art: Dictionary = w.gallery.back()
		err = Atelier.chamfer_distance(art.strokes, ref)
		replay = Atelier.valid_artifact(art, w.tick, w.ids.next_id)
	var delta: float = maxf(absf(c.energy - e), absf(c.hydration - h))
	assert(c.pos == p, "Atelier moved creature")
	w.tick += 1
	return {"shape": shape, "error": err, "success": completed and err < 0.22, "reproduced": completed, "replay": replay, "metabolic_delta": delta}

func transforms(seed_value: int, shape_index: int, novel: bool) -> Array:
	var scales := [0.85, 1.05, 1.25] if novel else [0.80, 1.05, 1.30]
	var out: Array = []
	for j in range(3):
		out.append({"center": Vector2(24 + (seed_value + j * 7) % 17, 26 + j * 5), "scale": scales[j], "dir_offset": (seed_value + shape_index * 3 + j * 5 + 1) % 16})
	return out

func trial(seed_value: int, arm: String) -> Dictionary:
	var w = fixture.studio(seed_value, 0.85)
	var c = w.creatures[w.pet_id]
	c.atelier = Atelier.new()
	c.atelier.policy_mode = "trained" if arm.begins_with("trained") else arm
	c.atelier.learning = arm.begins_with("trained")
	var bid: int = w.place_board(c.pos + Vector2(10, 0))
	var acquisition: Array = []
	var early: Array = []
	var late: Array = []
	for shape in Atelier.TRAIN_SHAPES:
		for k in range(8):
			var r := attempt(w, c, bid, shape, {"center": Vector2(32, 32), "scale": 1.0, "dir_offset": (k * 3) % 16})
			acquisition.append(r)
			if k == 0: early.append(r.error)
			if k >= 6: late.append(r.error)
	var params_after_training: Array = c.atelier.to_dict().best_params
	if arm == "trained_frozen":
		c.atelier.policy_mode = "frozen"
		c.atelier.learning = false
	var train_eval: Array = []
	var novel_eval: Array = []
	var references: Dictionary = {}
	for shapes in [Atelier.TRAIN_SHAPES, Atelier.HOLDOUT_SHAPES]:
		for si in range(shapes.size()):
			var shape: String = shapes[si]
			for params in transforms(seed_value, si, shapes == Atelier.HOLDOUT_SHAPES):
				var r := attempt(w, c, bid, shape, params)
				if shapes == Atelier.TRAIN_SHAPES: train_eval.append(r)
				else: novel_eval.append(r)
			references[shape] = w.boards[0].reference_strokes.duplicate(true)
	# A genuinely unseen control: erase all perceptual slots, preserve decoder,
	# and present demonstrations with observation disabled. No synthetic scribble
	# is scored as a successful reproduction; refusal receives error 1.
	var control = Atelier.from_dict(c.atelier.to_dict(), w.tick, w.ids.next_id)
	control.clear_memory()
	control.observation_enabled = false
	control.learning = false
	var original = c.atelier
	c.atelier = control
	var unobserved: Array = []
	for shape in Atelier.HOLDOUT_SHAPES:
		var r := attempt(w, c, bid, shape, transforms(seed_value, 0, true)[0])
		r["has_observed"] = control.has_observed(shape)
		unobserved.append(r)
	c.atelier = original
	# All retention scores use references kept exclusively by this evaluator.
	# The learner receives neither coordinates nor scalar feedback in this phase.
	var retained_state: String = fixture.snapshot(w)
	var loaded = World.from_dict(JSON.parse_string(retained_state))
	var roundtrip: bool = loaded != null and fixture.snapshot(loaded) == retained_state
	assert(roundtrip, "X5 full world roundtrip failed")
	var immediate: Array = []
	var post_save: Array = []
	var post_idle: Array = []
	var lc = loaded.creatures[loaded.pet_id]
	for actor in [c, lc]:
		actor.atelier.learning = false
		actor.atelier.observation_enabled = false
		if arm.begins_with("trained"): actor.atelier.policy_mode = "frozen"
	for shape in Atelier.KNOWN_SHAPES:
		immediate.append(attempt(w, c, bid, shape, {}, false, references[shape]))
		post_save.append(attempt(loaded, lc, bid, shape, {}, false, references[shape]))
	# Remove boards and their gallery references during the idle interval.
	# This prevents autonomous practice while ordinary physical ticks still run.
	loaded.boards.clear()
	for i in range(2000):
		lc.energy = snappedf(lc.max_energy * 0.95, 0.000001)
		lc.hydration = 95.0
		loaded.step()
	var idle_bid: int = loaded.place_board(lc.pos + Vector2(10, 0))
	assert(idle_bid > 0, "Cannot place retention board")
	for shape in Atelier.KNOWN_SHAPES:
		post_idle.append(attempt(loaded, lc, idle_bid, shape, {}, false, references[shape]))
	var frozen_unchanged: bool = arm != "trained_frozen" or params_after_training == lc.atelier.to_dict().best_params
	return {
		"seed": seed_value, "arm": arm, "acquisition": acquisition,
		"early_train_error": mean(early), "late_train_error": mean(late),
		"train_shapes_eval": train_eval, "holdout_shapes_eval": novel_eval,
		"unobserved_control_eval": unobserved, "immediate_memory": immediate,
		"retention_save_load": post_save, "retention_2000_ticks": post_idle,
		"roundtrip": roundtrip, "save_version": World.SAVE_VERSION,
		"frozen_unchanged": frozen_unchanged, "decoder_after_training": params_after_training,
		"updates": original.updates
	}

func mean(values: Array) -> float:
	var total := 0.0
	for v in values: total += float(v)
	return snappedf(total / maxf(1, values.size()), 0.000001)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["--train", "--dev", "--holdout"]:
		printerr("Use exactly one X5 split: --train | --dev | --holdout")
		quit(2)
		return
	var split_name: String = args[0].trim_prefix("--")
	var seeds: Array = range(129401, 129425) if split_name == "holdout" else (range(129101, 129105) if split_name == "train" else range(129201, 129207))
	var path: String = OUTPUT if split_name == "holdout" else "res://builds/M3b_copia_" + split_name + ".json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds"))
	var head: Array = []
	var status: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], head)
	OS.execute("git", ["status", "--porcelain", "--untracked-files=normal"], status)
	if split_name == "holdout" and (FileAccess.file_exists(path) or not str(status[0]).strip_edges().is_empty()):
		printerr("X5 holdout requires a clean committed freeze and no prior opening marker")
		quit(2)
		return
	var hashes := {}
	for p in FROZEN: hashes[p] = checksum("res://" + p)
	var output := {"experiment": "X5", "split": split_name, "status": "opened", "freeze_commit": str(head[0]).strip_edges(), "preregister_sha256": checksum(PROTOCOL), "frozen_sha256": hashes, "seeds": seeds, "arms": ARMS, "rows": []}
	# Durable single-opening marker BEFORE any holdout trial; a crash consumes it.
	write_result(path, output)
	for seed_value in seeds:
		for arm in ARMS:
			var row := trial(seed_value, arm)
			var repeat_row := trial(seed_value, arm)
			row["deterministic"] = JSON.stringify(row, "", true, true) == JSON.stringify(repeat_row, "", true, true)
			output.rows.append(row)
		print("X5 %s seed=%d complete" % [split_name, seed_value])
		write_result(path, output)
	output.status = "complete"
	write_result(path, output)
	print("X5 artifact: ", path)
	quit()
