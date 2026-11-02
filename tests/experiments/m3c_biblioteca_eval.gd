extends SceneTree
## X6 only; no earlier evaluator is executed.
const World = preload("res://scripts/world/sim_world.gd")
const Fixture = preload("res://tests/unit/test_sim_m3.gd")
const K = preload("res://scripts/library/knowledge.gd")
const Rng = preload("res://scripts/core/sim_rng.gd")
const PROTOCOL := "res://tests/experiments/m3c_biblioteca_preregistro.md"
const OUTPUT := "res://reports/M3c_biblioteca_eval.json"
const ARMS := ["verdadeiro", "sem_livro", "enganoso", "sem_memoria"]
const FROZEN := [
	"scripts/library/book_catalog.gd", "scripts/library/knowledge.gd", "scripts/library/reading.gd",
	"scripts/world/sim_world.gd", "scripts/creature/sim_creature.gd", "scripts/persistence/save_store.gd",
	"scripts/mind/creature_mind.gd", "scripts/mind/motivation.gd", "scripts/mind/object_memory.gd", "scripts/mind/affect.gd",
	"scripts/core/sim_data.gd", "scripts/core/sim_rng.gd", "scripts/core/sim_ids.gd", "scripts/core/spatial_grid.gd",
	"scripts/creature/genome.gd", "scripts/behavior/personality.gd", "scripts/behavior/observation.gd", "scripts/behavior/actions.gd",
	"scripts/environment/object_catalog.gd", "scripts/environment/food_catalog.gd", "scripts/environment/water_rules.gd",
	"scripts/social/social_dynamics.gd", "scripts/evolution/inheritance.gd", "scripts/evolution/genealogy.gd",
	"scripts/interaction/ensino.gd", "scripts/communication/comandos.gd", "scripts/communication/signal_channel.gd",
	"scripts/behavior/q_brain.gd", "scripts/behavior/brains.gd", "scripts/behavior/random_brain.gd",
	"tests/experiments/m3c_biblioteca_cpu.gd", "tests/experiments/verify_prereg.sh", "tests/unit/test_sim_m3.gd", "tests/unit/test_sim_m3c.gd",
	"tests/experiments/m3c_biblioteca_eval.gd", "tests/experiments/m3c_biblioteca_verify.py"]

func checksum(path: String) -> String:
	# Hash bytes, retaining UTF-8 BOM; normalize only CRLF like the Git auditor.
	var raw := FileAccess.get_file_as_bytes(path)
	var normalized := PackedByteArray()
	for i in range(raw.size()):
		if raw[i] == 13 and i + 1 < raw.size() and raw[i + 1] == 10: continue
		normalized.append(raw[i])
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(normalized)
	return digest.finish().hex_encode()

func write_result(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	file.flush()
	file.close()

func setup(seed_value: int):
	var w = World.new(seed_value, {"creature_count": 0, "food_count": 0, "water_count": 0, "obstacle_count": 0, "food_regrow": false, "reproduction_enabled": false, "personality_enabled": true, "water_enabled": true})
	var g = World.Genes.new()
	g.size = 8.0
	g.speed = 32.0
	g.vision_range = 220.0
	g.vision_fov = snappedf(TAU, 0.000001)
	g.temperament = {"curiosity": 0.78 + float(seed_value % 9) * 0.02, "caution": 0.25 + float(seed_value % 7) * 0.04, "sociability": 0.2 + float(seed_value % 5) * 0.1, "impulsivity": 0.4}
	var cid: int = w.spawn_creature(Vector2(300,300), "", g)
	w.pet_id = cid
	w.enable_mind(cid)
	var c = w.creatures[cid]
	c.energy = snappedf(c.max_energy * 0.95, 0.000001)
	c.hydration = 95.0
	c.heading = 0.0
	return w

func probe(w) -> Dictionary:
	var c = w.creatures[w.pet_id]
	var obj: int = w.place_object(c.pos + Vector2.from_angle(c.heading) * (8 + int(w.seed) % 5), "capsula_aversiva")
	var body_before: Array = [c.energy, c.hydration]
	var contacts := 0
	var actions: Array = []
	for i in range(48):
		w.step()
		if c.last_action == "investigate_object": contacts += 1
		actions.append(c.last_action)
	return {"contacts": contacts, "avoided": contacts == 0, "object_id": obj, "actions": actions, "body_before": body_before, "body_after": [c.energy, c.hydration]}

func arm_trial(seed_value: int, arm: String) -> Dictionary:
	var w = setup(seed_value)
	var c = w.creatures[w.pet_id]
	if arm == "sem_memoria": c.mind.memory_enabled = false
	if arm != "sem_livro": w.place_book(c.pos + Vector2(35 + seed_value % 11, 0), "guia_enganoso" if arm == "enganoso" else "guia_capsulas")
	var read_ticks := 0
	var approach_ticks := 0
	for i in range(40):
		w.step()
		if c.last_action == "read_book": read_ticks += 1
		if c.last_action == "seek_book": approach_ticks += 1
	var sources_before: Dictionary = c.knowledge_snapshot().sources.duplicate(true)
	var facts_before: Array = c.knowledge_snapshot().facts.duplicate(true)
	var reading: Dictionary = c.knowledge_snapshot().reading.duplicate(true)
	var first := probe(w)
	var sources_after: Dictionary = c.knowledge_snapshot().sources.duplicate(true)
	var facts_after: Array = c.knowledge_snapshot().facts.duplicate(true)
	var second := probe(w)
	return {"seed": seed_value, "arm": arm, "read_ticks": read_ticks, "approach_ticks": approach_ticks, "reading": reading, "sources_before": sources_before, "sources_after": sources_after, "facts_before": facts_before, "facts_after": facts_after, "first": first, "second": second}

func question_trial(seed_value: int, condition: String) -> Dictionary:
	var w = setup(seed_value)
	var c = w.creatures[w.pet_id]
	if condition != "sem_lacuna": w.place_object(c.pos + Vector2(8,0), "capsula_aversiva")
	if condition == "conhecido": K.add(c.mind, {"capsula": 0.0}, "inferido", 0.5, w.tick)
	var ids: Dictionary = {}
	var first_context: Dictionary = {}
	for i in range(48):
		w.step()
		for q in w.pending_questions:
			ids[q.id] = true
			if first_context.is_empty(): first_context = q.duplicate(true)
	return {"condition": condition, "count": ids.size(), "ticks": 48, "context": first_context}

func caregiver_trial(seed_value: int) -> Dictionary:
	var w = setup(seed_value)
	var c = w.creatures[w.pet_id]
	w.place_object(c.pos + Vector2(8,0), "capsula_aversiva")
	c.mind.decide(c, w.tick, w.sense(c))
	if w.pending_questions.is_empty(): return {"accepted": false, "asked": false, "retained": false}
	var accepted: bool = w.responder_pergunta(w.pending_questions[0].id, "evitar")
	var loaded = World.from_dict(w.to_dict())
	var facts: Array = c.knowledge_snapshot().facts
	var retained: bool = loaded != null and loaded.creatures[loaded.pet_id].knowledge_snapshot().facts == facts
	return {"accepted": accepted, "asked": true, "retained": retained, "facts": facts}

func symbols_trial(seed_value: int) -> Dictionary:
	var w = setup(seed_value)
	var c = w.creatures[w.pet_id]
	var a: int = w.place_object(c.pos + Vector2(8,0), "capsula_neutra")
	var b: int = w.place_object(c.pos + Vector2(10,0), "pedra")
	var glyphs: Array = ["anel", "barra", "onda"]
	var shift: int = seed_value % 3
	var ga: String = glyphs[shift]
	var gb: String = glyphs[(shift + 1) % 3]
	var unknown: String = glyphs[(shift + 2) % 3]
	for i in range(3):
		w.demonstrar_simbolo(c.id, ga, a, true)
		w.demonstrar_simbolo(c.id, gb, b, true)
	# Evaluate on the held-out contexts/instances, never demonstrate these.
	w.place_object(c.pos + Vector2(0,9), "capsula_aversiva")
	w.place_object(c.pos + Vector2(0,11), "pedra")
	var predictions: Array = [K.association(c.mind, ga, w.tick), K.association(c.mind, gb, w.tick), K.association(c.mind, unknown, w.tick)]
	return {"glyphs": [ga,gb,unknown], "predictions": predictions, "correct": int(predictions[0] == "capsula") + int(predictions[1] == "pedra"), "unknown_rejected": predictions[2] == "", "demonstrations": 6}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["--train", "--dev", "--holdout"]:
		printerr("X6 requires --train | --dev | --holdout")
		quit(2)
		return
	var split_name: String = args[0].trim_prefix("--")
	var seeds: Array = range(140401,140425) if split_name == "holdout" else (range(140101,140105) if split_name == "train" else range(140201,140207))
	var path: String = OUTPUT if split_name == "holdout" else "res://builds/M3c_biblioteca_" + split_name + ".json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds"))
	var head: Array = []
	var status: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], head)
	OS.execute("git", ["status", "--porcelain", "--untracked-files=normal"], status)
	if split_name == "holdout" and (FileAccess.file_exists(path) or status.is_empty() or not str(status[0]).strip_edges().is_empty()):
		printerr("X6 requires a clean freeze and no prior opening marker")
		quit(2)
		return
	var hashes: Dictionary = {}
	for p in FROZEN: hashes[p] = checksum("res://" + p)
	var output := {"experiment": "X6", "split": split_name, "status": "opened", "freeze_commit": str(head[0]).strip_edges(), "preregister_sha256": checksum(PROTOCOL), "frozen_sha256": hashes, "seeds": seeds, "arms": ARMS, "rows": []}
	write_result(path, output)
	for seed_value in seeds:
		var row: Dictionary = {"seed": seed_value, "arms": [], "questions": [], "caregiver": caregiver_trial(seed_value), "symbols": symbols_trial(seed_value)}
		for arm in ARMS: row.arms.append(arm_trial(seed_value, arm))
		for condition in ["lacuna", "conhecido", "sem_lacuna"]: row.questions.append(question_trial(seed_value, condition))
		var r = Rng.new(seed_value ^ 617)
		var random_count := 0
		for i in range(48):
			if r.between(0.0,1.0) < 1.0/180.0: random_count += 1
		row["random_questions"] = {"count": random_count, "ticks": 48, "condition": "sem_lacuna"}
		output.rows.append(row)
		write_result(path, output)
		print("X6 ", split_name, " seed=", seed_value, " complete")
	output.status = "complete"
	write_result(path, output)
	print("X6 artifact ", path)
	quit()
