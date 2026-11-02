extends SceneTree
## X8 Evaluator: Convivencia, vinculo e reproducao voluntaria.
## Single holdout opening after preregistration and freeze.
const World = preload("res://scripts/world/sim_world.gd")
const Genes = preload("res://scripts/creature/genome.gd")
const Creature = preload("res://scripts/creature/sim_creature.gd")
const Genealogy = preload("res://scripts/evolution/genealogy.gd")
const Knowledge = preload("res://scripts/library/knowledge.gd")
const TerminalLearning = preload("res://scripts/mind/terminal_learning.gd")
const PROTOCOL := "tests/experiments/m5_convivencia_preregistro.md"
const OUTPUT := "reports/M5_convivencia_eval.json"
const FREEZE := "tests/experiments/m5_freeze.json"
const ARMS := ["completo", "sem_memoria", "sem_afeto", "aleatorio", "parametros_fixos"]

var failures: Array = []

func git(args: Array) -> String:
	var output: Array = []
	var status := OS.execute("git", args, output, true)
	if status != 0:
		failures.append("git failed: " + str(args))
		return ""
	return str(output[0]).strip_edges() if not output.is_empty() else ""

func write_result(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("cannot write " + path)
		return
	file.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	file.flush()
	file.close()

static func canonical_sha(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	var source := bytes.get_string_from_utf8()
	if bytes.size() >= 3 and bytes[0] == 239 and bytes[1] == 187 and bytes[2] == 191 and not source.begins_with("\ufeff"):
		source = "\ufeff" + source
	return source.replace("\r\n", "\n").sha256_text()

func _subtrial_f7(seed_value: int, arm: String, b_north: bool) -> float:
	var w = World.new(seed_value, {
		"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0,
		"food_regrow": false, "reproduction_enabled": false, "personality_enabled": true,
		"water_enabled": true, "mind_all": true
	})
	var ga := Genes.new()
	ga.size = 8.0
	ga.speed = 30.0
	ga.vision_range = 200.0
	ga.vision_fov = snappedf(TAU, 0.000001)
	ga.temperament = {"curiosity": 0.5, "caution": 0.3, "sociability": 0.6, "impulsivity": 0.4}
	var a_id: int = w.spawn_creature(Vector2(300, 300), "A", ga)
	w.enable_mind(a_id)
	var a: Creature = w.creatures[a_id]

	var b_pos := Vector2(300, 240) if b_north else Vector2(300, 360)
	var c_pos := Vector2(300, 360) if b_north else Vector2(300, 240)

	var gb := Genes.new()
	gb.size = 8.0
	gb.speed = 30.0
	gb.vision_range = 200.0
	gb.vision_fov = snappedf(TAU, 0.000001)
	gb.temperament = {"curiosity": 0.5, "caution": 0.3, "sociability": 0.6, "impulsivity": 0.4}

	var gc := Genes.new()
	gc.size = 8.0
	gc.speed = 30.0
	gc.vision_range = 200.0
	gc.vision_fov = snappedf(TAU, 0.000001)
	gc.temperament = {"curiosity": 0.5, "caution": 0.3, "sociability": 0.6, "impulsivity": 0.4}

	var b_id: int
	var c_id: int
	if b_north:
		b_id = w.spawn_creature(b_pos, "B", gb)
		c_id = w.spawn_creature(c_pos, "C", gc)
	else:
		c_id = w.spawn_creature(c_pos, "C", gc)
		b_id = w.spawn_creature(b_pos, "B", gb)
	w.enable_mind(b_id)
	w.enable_mind(c_id)
	var b: Creature = w.creatures[b_id]
	var c: Creature = w.creatures[c_id]

	for actor in [a, b, c]:
		actor.energy = actor.max_energy
		actor.hydration = 90.0

	match arm:
		"completo":
			a.personality.bonds[str(b.id)] = {"count": 10, "familiarity": 0.85, "valence": 0.85, "last_tick": w.tick}
			a.personality.bonds[str(c.id)] = {"count": 10, "familiarity": 0.85, "valence": -0.85, "last_tick": w.tick}
		"sem_memoria":
			a.personality.bonds.clear()
			a.personality.episodes.clear()
			a.mind.experiences.clear()
		"sem_afeto":
			a.personality.bonds[str(b.id)] = {"count": 10, "familiarity": 0.85, "valence": 0.85, "last_tick": w.tick}
			a.personality.bonds[str(c.id)] = {"count": 10, "familiarity": 0.85, "valence": -0.85, "last_tick": w.tick}
			a.mind.affect_enabled = false
		"aleatorio":
			a.personality.bonds[str(b.id)] = {"count": 10, "familiarity": 0.85, "valence": 0.85, "last_tick": w.tick}
			a.personality.bonds[str(c.id)] = {"count": 10, "familiarity": 0.85, "valence": -0.85, "last_tick": w.tick}
			a.mind.policy_mode = "random"
		"parametros_fixos":
			a.personality.bonds.clear()
			a.mind.policy_mode = "fixed"

	a.mind.set_goal("buscar_companhia", w.tick, "m5.convivencia")
	var init_dist_b: float = a.pos.distance_to(b.pos)
	var init_dist_c: float = a.pos.distance_to(c.pos)
	var b_orig_pos: Vector2 = b.pos
	var c_orig_pos: Vector2 = c.pos

	for tick_idx in range(40):
		b.pos = b_orig_pos
		c.pos = c_orig_pos
		a.energy = a.max_energy
		a.hydration = 90.0
		w.step()

	var final_dist_b: float = a.pos.distance_to(b_orig_pos)
	var final_dist_c: float = a.pos.distance_to(c_orig_pos)
	var delta_b: float = snappedf(init_dist_b - final_dist_b, 0.001)
	var delta_c: float = snappedf(init_dist_c - final_dist_c, 0.001)
	return delta_b - delta_c

func _trial_f7(seed_value: int, arm: String) -> Dictionary:
	var c1 := _subtrial_f7(seed_value, arm, true)
	var c2 := _subtrial_f7(seed_value, arm, false)
	var mean_contrast := snappedf((c1 + c2) / 2.0, 0.001)
	var preferred := "neutral"
	if mean_contrast > 5.0:
		preferred = "B"
	elif mean_contrast < -5.0:
		preferred = "C"
	return {
		"seed": seed_value,
		"arm": arm,
		"contrast_north": c1,
		"contrast_south": c2,
		"mean_contrast": mean_contrast,
		"preferred": preferred
	}

func _trial_reproduction(seed_value: int) -> Dictionary:
	var w = World.new(seed_value, {
		"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0,
		"food_regrow": false, "reproduction_enabled": true, "personality_enabled": true,
		"water_enabled": true, "reproduction_voluntary": true, "reproduction_min_familiarity": 0.12,
		"reproduction_compatibility_threshold": 0.5, "mind_offspring": true
	})

	var g1 := Genes.new()
	g1.size = 8.0
	g1.speed = 30.0
	g1.vision_range = 200.0
	g1.temperament = {"curiosity": 0.7, "caution": 0.3, "sociability": 0.8, "impulsivity": 0.4}
	var p1_id: int = w.spawn_creature(Vector2(300, 300), "P1", g1)
	w.enable_mind(p1_id)
	var p1: Creature = w.creatures[p1_id]
	p1.energy = p1.max_energy
	p1.hydration = 90.0
	p1.age = w.min_reproduction_age + 20

	var g2 := Genes.new()
	g2.size = 8.0
	g2.speed = 30.0
	g2.vision_range = 200.0
	g2.temperament = {"curiosity": 0.6, "caution": 0.4, "sociability": 0.7, "impulsivity": 0.5}
	var p2_id: int = w.spawn_creature(Vector2(310, 300), "P2", g2)
	w.enable_mind(p2_id)
	var p2: Creature = w.creatures[p2_id]
	p2.energy = p2.max_energy
	p2.hydration = 90.0
	p2.age = w.min_reproduction_age + 20

	# 1. Condition voluntario_favoravel
	p1.personality.bonds[str(p2_id)] = {"count": 10, "familiarity": 0.6, "valence": 0.5, "last_tick": w.tick}
	p2.personality.bonds[str(p1_id)] = {"count": 10, "familiarity": 0.6, "valence": 0.5, "last_tick": w.tick}

	# Populate parent with acquired data to test non-inheritance
	p1.personality.meet(str(p2_id), w.tick, 0.5)
	Knowledge.add(p1.mind, {"pedra": 0.0}, "observado", 0.8, w.tick)
	p1.mind.terminal = TerminalLearning.empty()
	p1.mind.terminal.state.conhecidos["MOVER"] = "manual"

	var check_fav: Dictionary = w.can_reproduce(p1_id, p2_id)
	var fav_birth_id: int = w.reproduce(p1_id, p2_id)
	var fav_birth_ok: bool = fav_birth_id > 0

	var temp_inherited: bool = false
	var non_inherited_clean: bool = false
	var child_ref: Creature = null
	if fav_birth_ok:
		child_ref = w.creatures[fav_birth_id]
		var c_temp: Dictionary = child_ref.genome.temperament
		var p_temp: Dictionary = p1.genome.temperament
		var max_delta: float = 0.0
		for t_key in ["curiosity", "caution", "sociability", "impulsivity"]:
			max_delta = maxf(max_delta, absf(float(c_temp[t_key]) - float(p_temp[t_key])))
		temp_inherited = max_delta <= 0.35 and child_ref.genome.parents == [p1_id, p2_id]

		var episodes_clean: bool = child_ref.personality.episodes.is_empty()
		var bonds_clean: bool = child_ref.personality.bonds.is_empty()
		var exp_clean: bool = child_ref.mind.experiences.is_empty()
		var know_clean: bool = child_ref.mind.knowledge.is_empty()
		var draw_clean: bool = child_ref.atelier == null or child_ref.atelier.drawings.is_empty()
		var term_clean: bool = child_ref.mind.terminal.is_empty()
		non_inherited_clean = episodes_clean and bonds_clean and exp_clean and know_clean and draw_clean and term_clean

	# 2. Condition voluntario_desfavoravel (aversion or high frustration)
	p1.reproduction_cooldown = 0
	p2.reproduction_cooldown = 0
	p1.energy = p1.max_energy
	p2.energy = p2.max_energy
	p1.personality.bonds[str(p2_id)].valence = -0.5 # Aversion
	var check_desfav: Dictionary = w.can_reproduce(p1_id, p2_id)
	var desfav_birth_id: int = w.reproduce(p1_id, p2_id)
	var desfav_refused: bool = (desfav_birth_id == -1 and not bool(check_desfav.get("allowed", false)))

	# 3. Control so_energia (legacy asexual)
	w.reproduction_voluntary = false
	p1.reproduction_cooldown = 0
	p1.energy = p1.max_energy
	var ctrl_birth_id: int = w.reproduce(p1_id)
	var ctrl_birth_ok: bool = ctrl_birth_id > 0

	# 4. Save v14 integrity
	var save_dict: Dictionary = w.to_dict()
	var raw: Variant = JSON.parse_string(JSON.stringify(save_dict))
	var restored = World.from_dict(raw)
	var roundtrip_ok: bool = (restored != null and int(save_dict.get("save_version", 0)) == 14)
	var no_dup_ids: bool = false
	if restored != null:
		var all_ids: Dictionary = {}
		no_dup_ids = true
		for c_entry in restored.creatures.values():
			if all_ids.has(c_entry.id) or all_ids.has(c_entry.genome.id):
				no_dup_ids = false
				break
			all_ids[c_entry.id] = true
			all_ids[c_entry.genome.id] = true
	if restored != null:
		var all_ids: Dictionary = {}
		no_dup_ids = true
		for c_entry in restored.creatures.values():
			if all_ids.has(c_entry.id) or all_ids.has(c_entry.genome.id):
				no_dup_ids = false
				break
			all_ids[c_entry.id] = true
			all_ids[c_entry.genome.id] = true

	return {
		"seed": seed_value,
		"fav_birth_ok": fav_birth_ok,
		"temp_inherited": temp_inherited,
		"non_inherited_clean": non_inherited_clean,
		"desfav_refused": desfav_refused,
		"ctrl_birth_ok": ctrl_birth_ok,
		"roundtrip_ok": roundtrip_ok,
		"no_dup_ids": no_dup_ids
	}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var holdout := "--holdout" in args
	var train := "--train" in args
	var path := OUTPUT if holdout else ("builds/m5_train.json" if train else "builds/m5_dev.json")
	DirAccess.make_dir_recursive_absolute("builds")
	DirAccess.make_dir_recursive_absolute("reports")

	var meta: Dictionary = {"status": "development", "rows_f7": [], "rows_repro": [], "checks": [], "failures": []}

	if holdout:
		if FileAccess.file_exists(path):
			printerr("X8 refuses existing holdout output file")
			quit(1)
			return
		var porcelain := git(["status", "--porcelain"])
		# Ignore builds folder if any
		var dirty := false
		for line in porcelain.split("\n"):
			var l := line.strip_edges()
			if not l.is_empty() and not l.ends_with("builds/") and not l.contains("builds/"):
				dirty = true
		if dirty:
			printerr("X8 refuses dirty worktree: " + porcelain)
			quit(1)
			return

		var frozen = JSON.parse_string(FileAccess.get_file_as_string(FREEZE))
		if not frozen is Dictionary:
			printerr("Cannot parse freeze file: " + FREEZE)
			quit(1)
			return

		for file in frozen.files:
			if canonical_sha(file) != frozen.files[file]:
				failures.append("freeze mismatch " + file)
		if not failures.is_empty():
			printerr(failures)
			quit(1)
			return

		meta.merge({
			"status": "opened",
			"preregister_sha256": canonical_sha(PROTOCOL),
			"frozen_commit": git(["rev-parse", "HEAD"]),
			"preregister_commit": frozen.preregister_commit
		})
		write_result(path, meta)
		if not failures.is_empty():
			quit(1)
			return

	var first_seed := 151401 if holdout else (151101 if train else 151201)
	var count := 24 if holdout else (4 if train else 6)

	for seed_val in range(first_seed, first_seed + count):
		for arm in ARMS:
			var res_f7: Dictionary = _trial_f7(seed_val, arm)
			meta.rows_f7.append(res_f7)
		var res_repro: Dictionary = _trial_reproduction(seed_val)
		meta.rows_repro.append(res_repro)
		meta.checks.append({"seed": seed_val, "ok": true})

	# Hypothesis evaluations
	var h_a_count := 0
	var h_b_count := 0
	var h_c_count := 0
	for row in meta.rows_f7:
		if row.arm == "completo" and row.mean_contrast > 0.05 and row.preferred == "B":
			h_a_count += 1
		elif row.arm == "sem_memoria" and absf(float(row.mean_contrast)) <= 0.10:
			h_b_count += 1
		elif row.arm == "parametros_fixos" and absf(float(row.mean_contrast)) <= 0.10:
			h_c_count += 1

	var h_d_count := 0
	var h_e_count := 0
	var h_f_count := 0
	var h_g_count := 0
	for row in meta.rows_repro:
		if row.fav_birth_ok and row.desfav_refused and row.ctrl_birth_ok:
			h_d_count += 1
		if row.temp_inherited:
			h_e_count += 1
		if row.non_inherited_clean:
			h_f_count += 1
		if row.roundtrip_ok and row.no_dup_ids:
			h_g_count += 1

	var target := 18 if holdout else (3 if train else 5)
	var h_a := h_a_count >= target
	var h_b := h_b_count >= target
	var h_c := h_c_count >= target
	var h_d := h_d_count >= target
	var h_e := h_e_count >= count
	var h_f := h_f_count >= count
	var h_g := h_g_count >= count

	var verdict := "FAIL"
	if h_a and h_b and h_c and h_d and h_e and h_f and h_g:
		verdict = "PASS"
	elif h_d and h_e and h_f and h_g:
		verdict = "PARTIAL"

	meta["summary"] = {
		"seeds_count": count,
		"h_a": {"passed": h_a, "count": h_a_count, "target": target},
		"h_b": {"passed": h_b, "count": h_b_count, "target": target},
		"h_c": {"passed": h_c, "count": h_c_count, "target": target},
		"h_d": {"passed": h_d, "count": h_d_count, "target": target},
		"h_e": {"passed": h_e, "count": h_e_count, "target": count},
		"h_f": {"passed": h_f, "count": h_f_count, "target": count},
		"h_g": {"passed": h_g, "count": h_g_count, "target": count},
		"verdict": verdict
	}
	meta["status"] = "complete"
	write_result(path, meta)
	print("X8 finished: ", verdict, " (holdout=", holdout, ")")
	quit(0 if failures.is_empty() else 1)
